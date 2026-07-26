#!/usr/bin/env bash
# run.sh — assert bin/close-out.sh + bin/gen-project-status.sh honor the T-038
# behavior contract (docs/specs/T-038-close-out-automation.md):
#   AC1/AC2  Active -> Done move keeps the hand-off grammar; check-handoff green
#   AC3      issue-close procedure on stdout; gh is NEVER invoked
#   AC4      telemetry via log-run.sh is best-effort (failure never fails close-out)
#   AC5      paths resolve via team-paths.sh in BOTH layouts (no tasks/ hardcode)
#   AC6      malformed task id / note is rejected fail-closed (board untouched)
#   AC7      already-Done / missing task fails without duplicating entries
#   AC8      generator rewrites ONLY between markers (outside byte-identical)
#   AC9      generator is idempotent (2nd run diff-zero)
#   AC11     new scripts are shellcheck clean (soft-skip when unavailable)
#   AC12     CI workflow wires shellcheck + the fixture suite
#
# Temp roots live under $TMPDIR when set (sandboxed runs deny writes to any
# nested .git/ inside the repo tree, and these fixtures need `git init`),
# falling back to $HERE/tmp-roots on plain CI runners. Cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLOSEOUT="$REPO_ROOT/bin/close-out.sh"
GENSTATUS="$REPO_ROOT/bin/gen-project-status.sh"
if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/close-out-test-roots"
else
  TMP="$HERE/tmp-roots"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

# Build a legacy-layout root (tasks/ + docs/specs) with a board, markers'd
# project_status, the sibling-resolvable bin scripts, and a tiny git history.
# git init uses an empty template dir: sandboxed runs may not be allowed to
# copy sample hooks into a nested .git/hooks, and the fixtures need none.
EMPTY_GIT_TPL="$TMP/empty-git-template"
mkdir -p "$EMPTY_GIT_TPL"
make_legacy_root() {
  local R="$1"
  mkdir -p "$R/tasks/loops" "$R/docs/specs"
  : > "$R/tasks/loops/shell-team.contract.yaml"
  cp "$HERE/fixtures/todo-legacy.md" "$R/tasks/todo.md"
  cp "$HERE/fixtures/project_status.md" "$R/tasks/project_status.md"
  git -C "$R" init -q -b main --template="$EMPTY_GIT_TPL"
  git -C "$R" -c user.email=t@example.invalid -c user.name=t add -A
  git -C "$R" -c user.email=t@example.invalid -c user.name=t commit -qm "fixture: initial state"
}

# --- AC1/AC2/AC3: happy path in a legacy layout ------------------------------
L="$TMP/legacy"
make_legacy_root "$L"

# AC3's "gh is never invoked": put a canary gh first in PATH.
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/usr/bin/env bash\ntouch "%s/gh-was-called"\nexit 0\n' "$TMP" > "$FAKEBIN/gh"
chmod +x "$FAKEBIN/gh"

out="$(cd "$L" && PATH="$FAKEBIN:$PATH" bash "$CLOSEOUT" \
  --task T-100 --issue 5 --pr 6 --date 2026-07-06 --note "merged clean")" \
  || fail "close-out happy path should exit 0"

grep -q '^- \[ \] \*\*T-100\*\*' "$L/tasks/todo.md" \
  && fail "AC1: T-100 must leave ## Active"
# shellcheck disable=SC2016  # backticks are literal board grammar, not expansion
grep -q '^- \[x\] \*\*T-100\*\* .* — `READY_FOR_MERGE` — spec: docs/specs/t-100.md$' "$L/tasks/todo.md" \
  || fail "AC1: Done line must keep the hand-off grammar with READY_FOR_MERGE (flag directly followed by — spec:)"
grep -q '^  - closed: 2026-07-06, PR #6 → develop, closes #5 — merged clean$' "$L/tasks/todo.md" \
  || fail "AC1: closure sub-bullet with date/PR/issue/note expected"
grep -q '^  - existing engineering note$' "$L/tasks/todo.md" \
  || fail "AC1: the entry's existing sub-bullet must move along with it"
awk '/^## Done/{d=1} d && /^- \[x\]/{print; exit}' "$L/tasks/todo.md" | grep -q 'T-100' \
  || fail "AC1: the new Done entry must be inserted at the TOP of ## Done"
pass "AC1: Active entry (with sub-bullets) moves to top of Done in hand-off grammar"

bash "$REPO_ROOT/bin/check-handoff.sh" "$L/tasks/todo.md" \
  || fail "AC2: check-handoff must stay green after close-out"
pass "AC2: check-handoff green after close-out"

printf '%s' "$out" | grep -q 'gh issue close 5' \
  || fail "AC3: stdout must contain the gh issue-close procedure"
[ ! -e "$TMP/gh-was-called" ] \
  || fail "AC3: close-out must NEVER invoke gh itself"
pass "AC3: issue-close procedure printed; gh never invoked"

# --- AC4: telemetry happy path + best-effort on failure ----------------------
[ -f "$L/tasks/runs/close-out.jsonl" ] \
  || fail "AC4: telemetry span should land in tasks/runs/close-out.jsonl (legacy layout)"
[ "$(wc -l < "$L/tasks/runs/close-out.jsonl")" -eq 1 ] \
  || fail "AC4: exactly one span row expected"
pass "AC4: telemetry span recorded via log-run.sh (legacy layout)"

L2="$TMP/legacy-telemetry-broken"
make_legacy_root "$L2"
rm -rf "$L2/tasks/runs"
: > "$L2/tasks/runs"   # a FILE where the runs dir must go => log-run mkdir fails
( cd "$L2" && bash "$CLOSEOUT" --task T-100 --date 2026-07-06 ) >/dev/null \
  || fail "AC4: close-out must still exit 0 when telemetry cannot be written"
grep -q '^- \[x\] \*\*T-100\*\*' "$L2/tasks/todo.md" \
  || fail "AC4: board move must survive a telemetry failure (no rollback)"
pass "AC4: telemetry failure is best-effort (close-out succeeds, board updated)"

# --- AC5: default (.shell-team/) layout, no tasks/ leak -------------------------
D="$TMP/default"
mkdir -p "$D/.shell-team"
cp "$HERE/fixtures/todo-default.md" "$D/.shell-team/todo.md"
( cd "$D" && bash "$CLOSEOUT" --task T-200 --date 2026-07-06 ) >/dev/null \
  || fail "AC5: close-out should succeed in a default-layout root"
grep -q '^- \[x\] \*\*T-200\*\*' "$D/.shell-team/todo.md" \
  || fail "AC5: default layout board must be updated in .shell-team/"
[ ! -e "$D/tasks" ] \
  || fail "AC5: close-out must NOT create a tasks/ dir in a default-layout host"
[ -f "$D/.shell-team/runs/close-out.jsonl" ] \
  || fail "AC5: telemetry must land under .shell-team/runs/ in the default layout"
pass "AC5: team-paths delegation works in both layouts (no tasks/ hardcode)"

# --- AC6: malformed inputs are rejected fail-closed ---------------------------
L3="$TMP/legacy-validate"
make_legacy_root "$L3"
before="$L3/board-before"
cp "$L3/tasks/todo.md" "$before"

set +e
( cd "$L3" && bash "$CLOSEOUT" --task 'T-1;rm -rf /' --date 2026-07-06 ) >/dev/null 2>&1
rc_task=$?
( cd "$L3" && bash "$CLOSEOUT" --task T-100 --date 2026-07-06 --note "$(printf 'line1\nline2')" ) >/dev/null 2>&1
rc_note=$?
( cd "$L3" && bash "$CLOSEOUT" --task T-100 --date 'today' ) >/dev/null 2>&1
rc_date=$?
( cd "$L3" && bash "$CLOSEOUT" --task T-100 --date 2026-07-06 --note 'evil `tick` and $(sub)' ) >/dev/null 2>&1
rc_meta=$?
( cd "$L3" && bash "$CLOSEOUT" --task T-100 --issue 0 --date 2026-07-06 ) >/dev/null 2>&1
rc_zero=$?
set -e
[ "$rc_task" -eq 2 ] || fail "AC6: shell-meta task id should exit 2, got $rc_task"
[ "$rc_note" -eq 2 ] || fail "AC6: multi-line note should exit 2, got $rc_note"
[ "$rc_date" -eq 2 ] || fail "AC6: malformed date should exit 2, got $rc_date"
[ "$rc_meta" -eq 2 ] || fail "AC6: shell-metacharacter note should exit 2, got $rc_meta"
[ "$rc_zero" -eq 2 ] || fail "AC6: --issue 0 should exit 2 (positive integers only), got $rc_zero"
cmp -s "$before" "$L3/tasks/todo.md" \
  || fail "AC6: rejected input must leave the board byte-identical"
pass "AC6: malformed task id / note / date / meta-note / zero issue rejected, board untouched"

# --- AC7: already-Done and missing tasks fail without duplicates --------------
set +e
( cd "$L" && bash "$CLOSEOUT" --task T-100 --date 2026-07-06 ) >/dev/null 2>"$TMP/ac7-err"
rc_dup=$?
( cd "$L" && bash "$CLOSEOUT" --task T-999 --date 2026-07-06 ) >/dev/null 2>&1
rc_missing=$?
set -e
[ "$rc_dup" -eq 1 ] || fail "AC7: already-Done task should exit 1, got $rc_dup"
grep -q 'already in ## Done' "$TMP/ac7-err" \
  || fail "AC7: already-Done error message should say so"
[ "$(grep -c '\*\*T-100\*\*' "$L/tasks/todo.md")" -eq 1 ] \
  || fail "AC7: no duplicate Done entry may be created"
[ "$rc_missing" -eq 1 ] || fail "AC7: missing task should exit 1, got $rc_missing"
pass "AC7: already-Done / missing task fail cleanly (exit 1, no duplicates)"

# --- AC8: generator touches only the marker block -----------------------------
G="$L/tasks/project_status.md"
( cd "$L" && bash "$GENSTATUS" ) >/dev/null || fail "AC8: generator should exit 0"
# outside-the-markers regions must be byte-identical to the fixture
sed -n '1,/^<!-- BEGIN generated -->$/p' "$HERE/fixtures/project_status.md" > "$TMP/want-head"
sed -n '1,/^<!-- BEGIN generated -->$/p' "$G" > "$TMP/got-head"
cmp -s "$TMP/want-head" "$TMP/got-head" || fail "AC8: content before BEGIN marker must be untouched"
sed -n '/^<!-- END generated -->$/,$p' "$HERE/fixtures/project_status.md" > "$TMP/want-tail"
sed -n '/^<!-- END generated -->$/,$p' "$G" > "$TMP/got-tail"
cmp -s "$TMP/want-tail" "$TMP/got-tail" || fail "AC8: content after END marker must be untouched"
grep -q -- '- Active:' "$G" || fail "AC8: generated block should contain the board summary"
grep -q -- '- branch:' "$G" || fail "AC8: generated block should contain the git state"
pass "AC8: generator rewrites only the marker block (hand-written parts byte-identical)"

# --- AC9: generator is idempotent ---------------------------------------------
cp "$G" "$TMP/gen-first"
( cd "$L" && bash "$GENSTATUS" ) >/dev/null || fail "AC9: second generator run should exit 0"
cmp -s "$TMP/gen-first" "$G" || fail "AC9: second run must be diff-zero (idempotent)"
pass "AC9: generator idempotent (2nd run diff-zero)"

# --- markers absent => exit 1, file untouched ---------------------------------
NOMARK="$TMP/nomark"
make_legacy_root "$NOMARK"
printf '# handwritten only\n' > "$NOMARK/tasks/project_status.md"
set +e
( cd "$NOMARK" && bash "$GENSTATUS" ) >/dev/null 2>&1
rc_nomark=$?
set -e
[ "$rc_nomark" -eq 1 ] || fail "markers absent should exit 1, got $rc_nomark"
[ "$(cat "$NOMARK/tasks/project_status.md")" = "# handwritten only" ] \
  || fail "markers absent must leave the file untouched"
pass "generator fails closed when markers are absent"

# --- AC11: shellcheck clean (soft-skip when unavailable) -----------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CLOSEOUT" "$GENSTATUS" "$HERE/run.sh" \
    || fail "AC11: new scripts must be shellcheck clean"
  pass "AC11: shellcheck clean (close-out, gen-project-status, test runner)"
else
  printf 'SKIP: AC11 shellcheck not installed locally (CI enforces it)\n'
fi

# --- AC12: CI wiring -----------------------------------------------------------
CI_YML="$REPO_ROOT/.github/workflows/check-handoff.yml"
grep -q 'bin/close-out.sh' "$CI_YML"           || fail "AC12: CI shellcheck list must include bin/close-out.sh"
grep -q 'bin/gen-project-status.sh' "$CI_YML"  || fail "AC12: CI shellcheck list must include bin/gen-project-status.sh"
grep -q 'tests/close-out/run.sh' "$CI_YML"     || fail "AC12: CI must run the close-out fixture suite"
pass "AC12: CI wires shellcheck + the close-out fixture suite"

# --- T-068: pending fast-follow disposition fail-closed guard ----------------
# `bin/close-out.sh` must refuse to close out a task whose Active entry still
# carries an unresolved `pending:` fast-follow disposition sub-bullet, and
# must succeed once that sub-bullet is resolved (`filed as issue #N` /
# `waived: <reason>`). Uses a fresh task ID (T-150, distinct from T-100/T-200)
# injected into its own dedicated legacy root so the existing happy-path
# fixture (and its T-100/T-101 assertions above) stay untouched.
inject_pending_task() {
  # $1 = root, $2 = disposition sub-bullet body (appended verbatim after the
  # literal "- fast-follow disposition (2026-07-16): " prefix)
  local root="$1" disposition="$2"
  awk -v disp="$disposition" '
    { print }
    /^- \[ \] \*\*T-101\*\*/ {
      print "- [ ] **T-150** pending fast-follow disposition fixture (T-068) — `READY_FOR_REVIEW` — spec: docs/specs/t-150.md"
      print "  - fast-follow disposition (2026-07-16): " disp
    }
  ' "$root/tasks/todo.md" > "$root/tasks/todo.md.new"
  mv "$root/tasks/todo.md.new" "$root/tasks/todo.md"
}

# Negative: pending disposition present => close-out refuses, board untouched.
PN="$TMP/pending-negative"
make_legacy_root "$PN"
inject_pending_task "$PN" 'pending: issue filing pending user approval — resolve by close-out'
before_pn="$TMP/pending-negative-board-before"
cp "$PN/tasks/todo.md" "$before_pn"

set +e
( cd "$PN" && bash "$CLOSEOUT" --task T-150 --date 2026-07-16 ) >/dev/null 2>"$TMP/pending-negative-err"
rc_pending=$?
set -e
[ "$rc_pending" -eq 1 ] || fail "T-068: unresolved pending disposition should refuse close-out with exit 1, got $rc_pending"
cmp -s "$before_pn" "$PN/tasks/todo.md" \
  || fail "T-068: rejected pending close-out must leave the board byte-identical"
grep -q 'resolve it to a filed issue number or a waived reason before close-out' "$TMP/pending-negative-err" \
  || fail "T-068: rejection message must point to the filed/waived resolution"
pass "T-068: unresolved pending fast-follow disposition refuses close-out (board untouched)"

# Positive: disposition resolved (filed as issue #N) => close-out succeeds.
PP="$TMP/pending-positive"
make_legacy_root "$PP"
inject_pending_task "$PP" 'filed as issue #999 (rationale: cosmetic follow-up, tracked separately)'

( cd "$PP" && bash "$CLOSEOUT" --task T-150 --date 2026-07-16 ) >/dev/null \
  || fail "T-068: resolved (filed as issue #N) disposition should let close-out succeed"
grep -q '^- \[ \] \*\*T-150\*\*' "$PP/tasks/todo.md" \
  && fail "T-068: T-150 must leave ## Active once resolved and closed out"
# shellcheck disable=SC2016  # backticks are literal board grammar, not expansion
grep -q '^- \[x\] \*\*T-150\*\* .* — `READY_FOR_MERGE` — spec: docs/specs/t-150.md$' "$PP/tasks/todo.md" \
  || fail "T-068: T-150 Done line must keep the hand-off grammar with READY_FOR_MERGE"
grep -q 'filed as issue #999' "$PP/tasks/todo.md" \
  || fail "T-068: the resolved disposition sub-bullet must move to ## Done along with the entry"
pass "T-068: resolved (filed as issue #N) fast-follow disposition lets close-out succeed (Active -> Done)"

# Positive (round3 regression lock): hand-off PROSE quotes the anchor string
# and `pending:` on the same line (backticked, e.g. a rework note describing
# the guard itself — the exact shape T-068's own board entry took) but there
# is NO real disposition sub-bullet. The first-stage grep must be anchored to
# a disposition sub-bullet's line-start shape so this prose is never mistaken
# for an unresolved disposition — close-out must succeed.
inject_prose_quote_task() {
  # $1 = root — injects T-151 whose only Active sub-bullet quotes the anchor
  # string and `pending:` in prose on one line, starting with "- note:" (NOT
  # "- fast-follow disposition (") so it is not itself a disposition line.
  local root="$1"
  awk '
    { print }
    /^- \[ \] \*\*T-101\*\*/ {
      print "- [ ] **T-151** prose-quote false-positive regression fixture (T-068) — `READY_FOR_REVIEW` — spec: docs/specs/t-151.md"
      print "  - note: rework 注記の例 — `- fast-follow disposition (` と `pending:` を同一行で引用（disposition 実体なし）"
    }
  ' "$root/tasks/todo.md" > "$root/tasks/todo.md.new"
  mv "$root/tasks/todo.md.new" "$root/tasks/todo.md"
}

PQ="$TMP/pending-prose-quote"
make_legacy_root "$PQ"
inject_prose_quote_task "$PQ"

( cd "$PQ" && bash "$CLOSEOUT" --task T-151 --date 2026-07-16 ) >/dev/null \
  || fail "T-068: prose merely quoting the anchor + pending: on one line must NOT block close-out (round3 regression)"
grep -q '^- \[x\] \*\*T-151\*\*' "$PQ/tasks/todo.md" \
  || fail "T-068: T-151 must complete Active -> Done despite the prose quoting the anchor"
pass "T-068: prose quoting the anchor + pending: on one line does not false-positive-block close-out (round3 regression lock)"

printf '\nAll close-out assertions passed.\n'
