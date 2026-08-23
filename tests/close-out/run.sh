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
  TMP="$(mktemp -d "${TMPDIR%/}/close-out-test-roots.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$TMP"' EXIT

# Build a legacy-layout root (tasks/ + docs/specs) with a board, markers'd
# project_status, the sibling-resolvable bin scripts, and a tiny git history.
# git init uses an empty template dir: sandboxed runs may not be allowed to
# copy sample hooks into a nested .git/hooks, and the fixtures need none.
EMPTY_GIT_TPL="$TMP/empty-git-template"
mkdir -p "$EMPTY_GIT_TPL"
# T-1017: a conformant interventions record for a given task id, at the path
# the resolver derives for it (legacy layout: tasks/interventions/<id>.md;
# default layout: .shell-team/interventions/<id>.md). Written where the root
# / task is built, not case by case (per the spec's Notes for engineer).
write_conformant_interventions_record() {
  local path="$1" task="$2"
  mkdir -p "$(dirname "$path")"
  printf '<!-- BEGIN interventions: %s -->\nno interventions occurred\n<!-- END interventions: %s -->\n' \
    "$task" "$task" > "$path"
}

make_legacy_root() {
  local R="$1"
  mkdir -p "$R/tasks/loops" "$R/docs/specs" "$R/tasks/interventions"
  : > "$R/tasks/loops/shell-team.contract.yaml"
  cp "$HERE/fixtures/todo-legacy.md" "$R/tasks/todo.md"
  cp "$HERE/fixtures/project_status.md" "$R/tasks/project_status.md"
  write_conformant_interventions_record "$R/tasks/interventions/T-100.md" T-100
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
write_conformant_interventions_record "$D/.shell-team/interventions/T-200.md" T-200
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
  write_conformant_interventions_record "$root/tasks/interventions/T-150.md" T-150
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
  write_conformant_interventions_record "$root/tasks/interventions/T-151.md" T-151
}

PQ="$TMP/pending-prose-quote"
make_legacy_root "$PQ"
inject_prose_quote_task "$PQ"

( cd "$PQ" && bash "$CLOSEOUT" --task T-151 --date 2026-07-16 ) >/dev/null \
  || fail "T-068: prose merely quoting the anchor + pending: on one line must NOT block close-out (round3 regression)"
grep -q '^- \[x\] \*\*T-151\*\*' "$PQ/tasks/todo.md" \
  || fail "T-068: T-151 must complete Active -> Done despite the prose quoting the anchor"
pass "T-068: prose quoting the anchor + pending: on one line does not false-positive-block close-out (round3 regression lock)"

# ============================================================================
# T-1016: board-entry continuation canon at bin/close-out.sh's pass-1 awk
# (entry extent, trailing-blank trim) + the pre-write interlock (D3/D6).
# Runs with cwd inside the scratch root so best-effort telemetry/
# project_status regeneration cannot write into this repository.
# ============================================================================
MOVE_ROOT="$TMP/move-fixtures"
mkdir -p "$MOVE_ROOT"

# move-carries-internal-blank / move-carries-table-row / move-trims-trailing-blanks:
# an entry carrying an internal blank line, indented table rows and a
# trailing blank run is moved to the TOP of ## Done in one piece; ## Active
# is left with zero non-blank lines (no strand); the entry extent is
# trimmed, proved by counting exactly one blank line between the moved
# entry's last content line and the next ## Done entry (an untrimmed
# implementation leaves three).
M1="$MOVE_ROOT/m1"
mkdir -p "$M1"
write_conformant_interventions_record "$M1/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - first note\n\n  | a | b |\n  |---|---|\n\n  - last note\n\n\n## Done\n\n- [x] **T-800** old — `READY_FOR_MERGE` — spec: y.md\n' > "$M1/todo.md"
( cd "$M1" && TEAM_TODO="$M1/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M1/out" 2>"$M1/err" \
  || fail "move-carries-internal-blank: close-out should exit 0 (stderr: $(cat "$M1/err"))"
m1_a_count="$(awk '/^## Active/{f=1;next} f&&/^## /{f=0} f' "$M1/todo.md" | grep -c '[^[:space:]]' || true)"
[ "$m1_a_count" -eq 0 ] || fail "move-carries-internal-blank: expected zero non-blank lines left in ## Active, got $m1_a_count"
grep -qF -- '  | a | b |' "$M1/todo.md" || fail "move-carries-table-row: table row must survive the move"
grep -qF -- '  - last note' "$M1/todo.md" || fail "move-carries-internal-blank: post-blank sub-bullet must survive the move"
pass "move-carries-internal-blank — an internal blank line inside the moved entry does not truncate the move"
pass "move-carries-table-row — an indented table row (non-dash first character) inside the moved entry survives the move verbatim"

m1_blanks="$(awk '/^  - last note$/{f=1;next} f&&/^- \[x\]/{print n+0; exit} f&&/^[[:space:]]*$/{n++}' "$M1/todo.md")"
[ "$m1_blanks" = "1" ] || fail "move-trims-trailing-blanks: expected exactly one blank line between the moved entry and the next ## Done entry, got $m1_blanks"
pass "move-trims-trailing-blanks — the entry extent ends at the last continuation line; an untrimmed implementation would leave three blank lines here, not one"

m1_first="$(awk '/^## Done/{f=1;next} f&&/^- \[x\]/{print; exit}' "$M1/todo.md")"
case "$m1_first" in *'**T-901**'*) ;; *) fail "move-done-insertion-position: expected T-901 at the top of ## Done, got: $m1_first" ;; esac
bash "$REPO_ROOT/bin/check-handoff.sh" "$M1/todo.md" >/dev/null 2>&1 || fail "move-done-insertion-position: rewritten board must lint clean"
pass "move-done-insertion-position — the moved entry (with its table rows and post-blank sub-bullet) lands at the TOP of ## Done"

# move-final-entry-eof / move-section-end-boundary: the task is the last
# entry of the last section, its continuation lines run to the final line of
# the file, and ## Done precedes ## Active. The move still carries every
# continuation line, leaves no strand, and lints clean.
M2="$MOVE_ROOT/m2"
mkdir -p "$M2"
write_conformant_interventions_record "$M2/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Done\n\n- [x] **T-800** old — `READY_FOR_MERGE` — spec: y.md\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - note one\n\n  | a | b |\n' > "$M2/todo.md"
( cd "$M2" && TEAM_TODO="$M2/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M2/out" 2>"$M2/err" \
  || fail "move-final-entry-eof: close-out should exit 0 (stderr: $(cat "$M2/err"))"
m2_a_count="$(awk '/^## Active/{f=1;next} f&&/^## /{f=0} f' "$M2/todo.md" | grep -c '[^[:space:]]' || true)"
[ "$m2_a_count" -eq 0 ] || fail "move-final-entry-eof: expected zero non-blank lines left in ## Active, got $m2_a_count"
grep -qF -- '  | a | b |' "$M2/todo.md" || fail "move-final-entry-eof: the file's own last line (a table row) must survive the move"
grep -qF -- '  - note one' "$M2/todo.md" || fail "move-section-end-boundary: sub-bullet must survive the move"
bash "$REPO_ROOT/bin/check-handoff.sh" "$M2/todo.md" >/dev/null 2>&1 || fail "move-final-entry-eof: rewritten board must lint clean"
pass "move-final-entry-eof — the entry's continuation lines run all the way to EOF; the move still carries every one"
pass "move-section-end-boundary — a board where ## Done precedes ## Active still moves the Active entry correctly"

# move-crlf-board: the same shape as M1 (internal blank + table row),
# CRLF-terminated throughout (built with awk, not a sed `\r` replacement —
# that replacement is not portable). The move still carries every line and
# leaves no strand.
M3="$MOVE_ROOT/m3"
mkdir -p "$M3"
write_conformant_interventions_record "$M3/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - first note\n\n  | a | b |\n\n  - last note\n\n## Done\n\n- [x] **T-800** old — `READY_FOR_MERGE` — spec: y.md\n' > "$M3/plain.md"
awk '{ printf "%s\r\n", $0 }' "$M3/plain.md" > "$M3/todo.md"
( cd "$M3" && TEAM_TODO="$M3/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M3/out" 2>"$M3/err" \
  || fail "move-crlf-board: close-out should exit 0 on a CRLF board (stderr: $(cat "$M3/err"))"
m3_a_count="$(awk '/^## Active/{f=1;next} f&&/^## /{f=0} f' "$M3/todo.md" | tr -d '\r' | grep -c '[^[:space:]]' || true)"
[ "$m3_a_count" -eq 0 ] || fail "move-crlf-board: expected zero non-blank lines left in ## Active, got $m3_a_count"
grep -qF -- '**T-901**' "$M3/todo.md" || fail "move-crlf-board: T-901 must have moved to ## Done"
bash "$REPO_ROOT/bin/check-handoff.sh" "$M3/todo.md" >/dev/null 2>&1 || fail "move-crlf-board: rewritten board must lint clean"
pass "move-crlf-board — a CRLF-terminated board (awk-produced, not sed) moves the whole entry with no strand left behind"

# move-tab-indented-subbullets: a tab-indented sub-bullet is carried by the
# move (the same shape the T-1013 incident's stranded lines took).
M4="$MOVE_ROOT/m4"
mkdir -p "$M4"
write_conformant_interventions_record "$M4/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\t- tab note\n\n## Done\n\n- [x] **T-800** old — `READY_FOR_MERGE` — spec: y.md\n' > "$M4/todo.md"
( cd "$M4" && TEAM_TODO="$M4/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M4/out" 2>"$M4/err" \
  || fail "move-tab-indented-subbullets: close-out should exit 0 (stderr: $(cat "$M4/err"))"
grep -qF -- "$(printf '\t- tab note')" "$M4/todo.md" \
  || fail "move-tab-indented-subbullets: tab-indented sub-bullet must survive the move"
m4_a_count="$(awk '/^## Active/{f=1;next} f&&/^## /{f=0} f' "$M4/todo.md" | grep -c '[^[:space:]]' || true)"
[ "$m4_a_count" -eq 0 ] || fail "move-tab-indented-subbullets: expected zero non-blank lines left in ## Active, got $m4_a_count"
bash "$REPO_ROOT/bin/check-handoff.sh" "$M4/todo.md" >/dev/null 2>&1 || fail "move-tab-indented-subbullets: rewritten board must lint clean"
pass "move-tab-indented-subbullets — a tab-indented sub-bullet (leading whitespace, non-dash-neutral) is carried by the move"

# move-refuses-stranded-board / move-refusal-names-the-reason: the interlock
# (D3/D6). Against a board that already carries a strand, close-out exits 1,
# leaves the board byte-identical, and its stderr names the strand reason —
# paired with a positive control (same board, strand removed) exiting 0, so
# the refusal is attributable to the strand rather than the fixture being
# broken in general.
M5="$MOVE_ROOT/m5"
mkdir -p "$M5"
write_conformant_interventions_record "$M5/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n  - stranded line\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - note\n\n## Done\n' > "$M5/bad.md"
cp "$M5/bad.md" "$M5/bad.orig"
set +e
( cd "$M5" && TEAM_TODO="$M5/bad.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M5/out" 2>"$M5/err"
m5_rc=$?
set -e
[ "$m5_rc" -eq 1 ] || fail "move-refuses-stranded-board: expected exit 1, got $m5_rc (stderr: $(cat "$M5/err"))"
cmp -s "$M5/bad.md" "$M5/bad.orig" || fail "move-refuses-stranded-board: the board must stay byte-identical on refusal"
pass "move-refuses-stranded-board — close-out refuses (exit 1, board untouched) to write a rewritten board that already carries a strand (the interlock, D3)"

[ -s "$M5/err" ] || fail "move-refusal-names-the-reason: expected non-empty stderr"
grep -qF -- 'stranded continuation line' "$M5/err" \
  || fail "move-refusal-names-the-reason: stderr must name the strand reason (D6), not just a generic refusal"
pass "move-refusal-names-the-reason — the refusal's stderr names the strand reason instead of only \"would fail check-handoff.sh\" (D6)"

# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - note\n\n## Done\n' > "$M5/good.md"
( cd "$M5" && TEAM_TODO="$M5/good.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$M5/out2" 2>"$M5/err2" \
  || fail "move-refuses-stranded-board positive control: close-out should succeed once the strand is removed and nothing else changed"
pass "move-refuses-stranded-board positive control — the same board with the strand removed and nothing else changed exits 0"

# ============================================================================
# T-1017: close-out refuses a task whose interventions record is missing or
# non-conformant (docs: .shell-team/specs/T-1017-close-out-interventions-gate.md).
# Every fixture root below is self-contained (its own mktemp'd scratch
# directory); assertion ids match AC12's frozen 16-item list.
# ============================================================================
IV_ROOT="$TMP/interventions"
mkdir -p "$IV_ROOT"

# --- interventions-happy-path-unchanged (AC1 preservation lock) -------------
IH="$IV_ROOT/happy"
mkdir -p "$IH"
write_conformant_interventions_record "$IH/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - note\n\n## Done\n\n- [x] **T-800** old — `READY_FOR_MERGE` — spec: y.md\n' > "$IH/todo.md"
( cd "$IH" && TEAM_TODO="$IH/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$IH/out" 2>"$IH/err" \
  || fail "interventions-happy-path-unchanged: close-out should still exit 0 with a conformant record present (stderr: $(cat "$IH/err"))"
grep -q '^- \[x\] \*\*T-901\*\*' "$IH/todo.md" || fail "interventions-happy-path-unchanged: T-901 must move to Done"
ih_a_count="$(awk '/^## Active/{f=1;next} f&&/^## /{f=0} f' "$IH/todo.md" | grep -c '[^[:space:]]' || true)"
[ "$ih_a_count" -eq 0 ] || fail "interventions-happy-path-unchanged: expected zero non-blank lines left in ## Active, got $ih_a_count"
bash "$REPO_ROOT/bin/check-handoff.sh" "$IH/todo.md" >/dev/null 2>&1 || fail "interventions-happy-path-unchanged: rewritten board must lint clean"
pass "interventions-happy-path-unchanged — a conformant record leaves the happy path exactly as before (AC1 preservation lock)"

# --- interventions-missing-refuses / -remedy-names-path / -positive-control -
MB="$IV_ROOT/missing-bad"
MG="$IV_ROOT/missing-good"
mkdir -p "$MB" "$MG"
write_conformant_interventions_record "$MG/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$MB/todo.md"
cp "$MB/todo.md" "$MB/todo.orig"
cp "$MB/todo.md" "$MG/todo.md"
set +e
( cd "$MB" && TEAM_TODO="$MB/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$MB/out" 2>"$MB/err"
mb_rc=$?
set -e
[ "$mb_rc" -eq 1 ] || fail "interventions-missing-refuses: expected exit 1, got $mb_rc"
cmp -s "$MB/todo.md" "$MB/todo.orig" || fail "interventions-missing-refuses: board must stay byte-identical"
grep -qF -- 'has no readable interventions record' "$MB/err" || fail "interventions-missing-refuses: stderr must name reason A"
pass "interventions-missing-refuses — a task with no interventions record at all refuses with exit 1, board untouched"

grep -qF -- '.shell-team/interventions/T-901.md' "$MB/err" \
  || fail "interventions-missing-remedy-names-path: the resolved record path must be named"
grep -qF -- "$MB" "$MB/err" || fail "interventions-missing-remedy-names-path: the working directory must be named"
grep -qF -- '<!-- BEGIN interventions: T-901 -->' "$MB/err" || fail "interventions-missing-remedy-names-path: BEGIN marker must be printed verbatim"
grep -qF -- '<!-- END interventions: T-901 -->' "$MB/err" || fail "interventions-missing-remedy-names-path: END marker must be printed verbatim"
grep -qF -- 'no interventions occurred' "$MB/err" || fail "interventions-missing-remedy-names-path: sentinel line must be printed verbatim"
pass "interventions-missing-remedy-names-path — the one-step remedy names the resolved path, the cwd, and a conformant record's exact bytes"

( cd "$MG" && TEAM_TODO="$MG/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$MG/out" 2>"$MG/err" \
  || fail "interventions-missing-positive-control: the same board differing only by the record's presence must exit 0 (stderr: $(cat "$MG/err"))"
pass "interventions-missing-positive-control — the same board differing only by the record's presence exits 0"

# --- interventions-schema-refuses / -stderr-surfaced-before-reason ----------
SC="$IV_ROOT/schema"
mkdir -p "$SC/.shell-team/interventions"
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$SC/todo.md"
cp "$SC/todo.md" "$SC/todo.orig"
printf '<!-- BEGIN interventions: T-901 -->\n- intervention: bogus-class\n<!-- END interventions: T-901 -->\n' > "$SC/.shell-team/interventions/T-901.md"
set +e
( cd "$SC" && TEAM_TODO="$SC/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$SC/out" 2>"$SC/err"
sc_rc=$?
set -e
[ "$sc_rc" -eq 1 ] || fail "interventions-schema-refuses: expected exit 1, got $sc_rc"
cmp -s "$SC/todo.md" "$SC/todo.orig" || fail "interventions-schema-refuses: board must stay byte-identical"
grep -qF -- 'check-interventions: schema:' "$SC/err" || fail "interventions-schema-refuses: the checker's schema line must be surfaced"
grep -qF -- 'interventions record does not conform' "$SC/err" || fail "interventions-schema-refuses: reason B must be printed"
pass "interventions-schema-refuses — a schema-violating record (checker exit 1) refuses close-out with reason B"

sc_cs="$(grep -nF -- 'check-interventions: schema:' "$SC/err" | head -1 | cut -d: -f1)"
sc_co="$(grep -nF -- 'interventions record does not conform' "$SC/err" | head -1 | cut -d: -f1)"
if [ -z "$sc_cs" ] || [ -z "$sc_co" ] || [ "$sc_cs" -ge "$sc_co" ]; then
  fail "interventions-stderr-surfaced-before-reason: the checker's classified line must appear strictly before close-out's own reason (checker at line ${sc_cs:-?}, reason at line ${sc_co:-?})"
fi
pass "interventions-stderr-surfaced-before-reason — the checker's own stderr is printed before close-out's reason string (D5)"

# --- interventions-wrong-task-id-refuses / interventions-structural-refuses -
ST="$IV_ROOT/structural"
mkdir -p "$ST/.shell-team/interventions"
STR="$ST/.shell-team/interventions/T-901.md"
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$ST/todo.md"
cp "$ST/todo.md" "$ST/todo.orig"
printf '<!-- BEGIN interventions: T-902 -->\nno interventions occurred\n<!-- END interventions: T-902 -->\n' > "$STR"
set +e
( cd "$ST" && TEAM_TODO="$ST/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$ST/out" 2>"$ST/err"
st_rc=$?
set -e
[ "$st_rc" -eq 1 ] || fail "interventions-wrong-task-id-refuses: expected exit 1, got $st_rc"
cmp -s "$ST/todo.md" "$ST/todo.orig" || fail "interventions-wrong-task-id-refuses: board must stay byte-identical"
grep -qF -- 'check-interventions: structural:' "$ST/err" || fail "interventions-wrong-task-id-refuses: the checker's structural line must be surfaced"
grep -qF -- 'interventions record does not conform' "$ST/err" || fail "interventions-wrong-task-id-refuses: reason B must be printed"
pass "interventions-wrong-task-id-refuses — a record copied from another task (--task is actually passed through) normalizes to exit 1, reason B"

printf 'no interventions occurred\n' > "$STR"
set +e
( cd "$ST" && TEAM_TODO="$ST/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$ST/out2" 2>"$ST/err2"
st_rc2=$?
set -e
[ "$st_rc2" -eq 1 ] || fail "interventions-structural-refuses: expected exit 1 for a marker-less record, got $st_rc2"
grep -qF -- 'check-interventions: structural:' "$ST/err2" || fail "interventions-structural-refuses: the checker's structural line must be surfaced"
pass "interventions-structural-refuses — a record with no markers at all normalizes to exit 1, reason B"

write_conformant_interventions_record "$STR" T-901
( cd "$ST" && TEAM_TODO="$ST/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$ST/out3" 2>"$ST/err3" \
  || fail "interventions-structural-refuses positive control: correcting the id must let close-out succeed (stderr: $(cat "$ST/err3"))"
pass "interventions-structural-refuses positive control — correcting the record's id to match --task lets close-out succeed"

# --- interventions-checker-absent-exit2 -------------------------------------
CA_ROOT="$IV_ROOT/checker-absent"
mkdir -p "$CA_ROOT"
cp -R "$REPO_ROOT/bin" "$CA_ROOT/bin"
mkdir -p "$CA_ROOT/root"
write_conformant_interventions_record "$CA_ROOT/root/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$CA_ROOT/root/todo.md"
cp "$CA_ROOT/root/todo.md" "$CA_ROOT/root/todo.orig"
rm -f "$CA_ROOT/bin/check-interventions.sh"
set +e
( cd "$CA_ROOT/root" && TEAM_TODO="$CA_ROOT/root/todo.md" bash "$CA_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$CA_ROOT/out" 2>"$CA_ROOT/err"
ca_rc=$?
set -e
[ "$ca_rc" -eq 2 ] || fail "interventions-checker-absent-exit2: expected exit 2, got $ca_rc"
cmp -s "$CA_ROOT/root/todo.md" "$CA_ROOT/root/todo.orig" || fail "interventions-checker-absent-exit2: board must stay byte-identical"
grep -qF -- 'cannot verify the interventions record' "$CA_ROOT/err" || fail "interventions-checker-absent-exit2: reason C must be printed"
if grep -qF -- 'no interventions occurred' "$CA_ROOT/err"; then
  fail "interventions-checker-absent-exit2: the write-a-record remedy must NOT print on an exit-2 refusal"
fi
pass "interventions-checker-absent-exit2 — a missing sibling checker is exit 2, reason C, with no write-a-record remedy"

# --- interventions-usage-classification-exit2 / -unclassified-exit2 --------
STUB_ROOT="$IV_ROOT/stub"
mkdir -p "$STUB_ROOT"
cp -R "$REPO_ROOT/bin" "$STUB_ROOT/bin"
mkdir -p "$STUB_ROOT/root"
write_conformant_interventions_record "$STUB_ROOT/root/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$STUB_ROOT/root/todo.md"
cp "$STUB_ROOT/root/todo.md" "$STUB_ROOT/root/todo.orig"
STUB="$STUB_ROOT/bin/check-interventions.sh"

printf '#!/usr/bin/env bash\nprintf "check-interventions: usage: stub\\n" >&2\nexit 2\n' > "$STUB"
set +e
( cd "$STUB_ROOT/root" && TEAM_TODO="$STUB_ROOT/root/todo.md" bash "$STUB_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$STUB_ROOT/oA" 2>"$STUB_ROOT/eA"
usa_rc=$?
set -e
[ "$usa_rc" -eq 2 ] || fail "interventions-usage-classification-exit2: expected exit 2 for a usage-classified checker failure, got $usa_rc"
cmp -s "$STUB_ROOT/root/todo.md" "$STUB_ROOT/root/todo.orig" || fail "interventions-usage-classification-exit2: board must stay byte-identical"
pass "interventions-usage-classification-exit2 — a usage-classified checker exit 2 stays close-out exit 2 (not normalized to 1)"

printf '#!/usr/bin/env bash\nprintf "something broke\\n" >&2\nexit 2\n' > "$STUB"
set +e
( cd "$STUB_ROOT/root" && TEAM_TODO="$STUB_ROOT/root/todo.md" bash "$STUB_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$STUB_ROOT/oC" 2>"$STUB_ROOT/eC"
unc_rc=$?
set -e
[ "$unc_rc" -eq 2 ] || fail "interventions-unclassified-exit2: expected exit 2 for an unclassified checker exit 2, got $unc_rc"

printf '#!/usr/bin/env bash\nprintf "check-interventions: schema: stub\\n" >&2\nexit 3\n' > "$STUB"
set +e
( cd "$STUB_ROOT/root" && TEAM_TODO="$STUB_ROOT/root/todo.md" bash "$STUB_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$STUB_ROOT/oD" 2>"$STUB_ROOT/eD"
unc_rc2=$?
set -e
[ "$unc_rc2" -eq 2 ] || fail "interventions-unclassified-exit2: expected exit 2 for a recognized token with an unrecognized exit status (row vi keys on status first), got $unc_rc2"
cmp -s "$STUB_ROOT/root/todo.md" "$STUB_ROOT/root/todo.orig" || fail "interventions-unclassified-exit2: board must stay byte-identical"
pass "interventions-unclassified-exit2 — an unrecognized token, or a recognized token with a non-{0,1,2} exit status, is exit 2 (fail-closed floor)"

printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB"
( cd "$STUB_ROOT/root" && TEAM_TODO="$STUB_ROOT/root/todo.md" bash "$STUB_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$STUB_ROOT/oE" 2>"$STUB_ROOT/eE" \
  || fail "interventions-usage-classification-exit2 positive control: a stub checker exiting 0 must let close-out complete (stderr: $(cat "$STUB_ROOT/eE"))"
pass "interventions-usage-classification-exit2 positive control — a stub checker exiting 0 lets close-out complete (the scratch bin/ copy is otherwise functional)"

# --- interventions-resolver-failure-exit2 -----------------------------------
RF_ROOT="$IV_ROOT/resolver-failure"
mkdir -p "$RF_ROOT"
cp -R "$REPO_ROOT/bin" "$RF_ROOT/bin"
mkdir -p "$RF_ROOT/root"
write_conformant_interventions_record "$RF_ROOT/root/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$RF_ROOT/root/todo.md"
cp "$RF_ROOT/root/todo.md" "$RF_ROOT/root/todo.orig"
rm -f "$RF_ROOT/bin/team-paths.sh"
set +e
( cd "$RF_ROOT/root" && TEAM_TODO="$RF_ROOT/root/todo.md" bash "$RF_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$RF_ROOT/out" 2>"$RF_ROOT/err"
rf_rc=$?
set -e
[ "$rf_rc" -eq 2 ] || fail "interventions-resolver-failure-exit2: expected exit 2, got $rf_rc"
cmp -s "$RF_ROOT/root/todo.md" "$RF_ROOT/root/todo.orig" || fail "interventions-resolver-failure-exit2: board must stay byte-identical"
grep -qF -- 'cannot resolve the interventions directory' "$RF_ROOT/err" || fail "interventions-resolver-failure-exit2: reason D must be printed"
pass "interventions-resolver-failure-exit2 — with team-paths.sh removed and no override, resolution fails exit 2, reason D (no guessing fallback — a conformant record sits at the default location a fallback would use)"

( cd "$RF_ROOT/root" && TEAM_TODO="$RF_ROOT/root/todo.md" TEAM_INTERVENTIONS_DIR="$RF_ROOT/root/.shell-team/interventions" bash "$RF_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) >"$RF_ROOT/out2" 2>"$RF_ROOT/err2" \
  || fail "interventions-resolver-failure-exit2 positive control: the override needs no resolver (stderr: $(cat "$RF_ROOT/err2"))"
pass "interventions-resolver-failure-exit2 positive control — the same crippled bin/ copy succeeds once \$TEAM_INTERVENTIONS_DIR is set"

# --- interventions-env-override-precedence ----------------------------------
OV1="$IV_ROOT/override-only"
OV2="$IV_ROOT/override-empty-rescue"
mkdir -p "$OV1/elsewhere" "$OV2/.shell-team/interventions" "$OV2/empty"
write_conformant_interventions_record "$OV1/elsewhere/T-901.md" T-901
write_conformant_interventions_record "$OV2/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$OV1/todo.md"
cp "$OV1/todo.md" "$OV2/todo.md"
cp "$OV2/todo.md" "$OV2/todo.orig"
( cd "$OV1" && TEAM_TODO="$OV1/todo.md" TEAM_INTERVENTIONS_DIR="$OV1/elsewhere" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$OV1/out" 2>"$OV1/err" \
  || fail "interventions-env-override-precedence: a record present only in the override dir must let close-out succeed (stderr: $(cat "$OV1/err"))"
set +e
( cd "$OV2" && TEAM_TODO="$OV2/todo.md" TEAM_INTERVENTIONS_DIR="$OV2/empty" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$OV2/out2" 2>"$OV2/err2"
ov2_rc=$?
set -e
[ "$ov2_rc" -eq 1 ] || fail "interventions-env-override-precedence: an empty override dir must refuse even though the resolver location holds a valid record, got $ov2_rc"
cmp -s "$OV2/todo.md" "$OV2/todo.orig" || fail "interventions-env-override-precedence: board must stay byte-identical"
grep -qF -- 'has no readable interventions record' "$OV2/err2" || fail "interventions-env-override-precedence: reason A must be printed"
grep -qF -- "$OV2/empty" "$OV2/err2" || fail "interventions-env-override-precedence: the override path must be named, not the resolver's default location"
pass "interventions-env-override-precedence — \$TEAM_INTERVENTIONS_DIR wins over the resolver in both directions (override-only passes; override-empty refuses despite a valid record at the resolver location)"

# --- interventions-legacy-layout-resolution ---------------------------------
LL_ROOT="$IV_ROOT/legacy-resolution"
mkdir -p "$LL_ROOT/tasks/loops" "$LL_ROOT/tasks/interventions" "$LL_ROOT/docs/specs"
: > "$LL_ROOT/tasks/loops/shell-team.contract.yaml"
write_conformant_interventions_record "$LL_ROOT/tasks/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: docs/specs/x.md\n\n## Done\n' > "$LL_ROOT/todo-src.md"
cp "$LL_ROOT/todo-src.md" "$LL_ROOT/tasks/todo.md"
( cd "$LL_ROOT" && bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$LL_ROOT/out" 2>"$LL_ROOT/err" \
  || fail "interventions-legacy-layout-resolution: a record at tasks/interventions/T-901.md must close the task out (stderr: $(cat "$LL_ROOT/err"))"
grep -q '^- \[x\] \*\*T-901\*\*' "$LL_ROOT/tasks/todo.md" || fail "interventions-legacy-layout-resolution: T-901 must move to Done"
pass "interventions-legacy-layout-resolution — the legacy layout resolves to tasks/interventions/, no .shell-team hardcode"

cp "$LL_ROOT/todo-src.md" "$LL_ROOT/tasks/todo.md"
cp "$LL_ROOT/todo-src.md" "$LL_ROOT/todo.orig"
rm -f "$LL_ROOT/tasks/interventions/T-901.md"
set +e
( cd "$LL_ROOT" && bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$LL_ROOT/out2" 2>"$LL_ROOT/err2"
ll_rc=$?
set -e
[ "$ll_rc" -eq 1 ] || fail "interventions-legacy-layout-resolution: removing the legacy record must refuse, got $ll_rc"
cmp -s "$LL_ROOT/tasks/todo.md" "$LL_ROOT/todo.orig" || fail "interventions-legacy-layout-resolution: board must stay byte-identical"
grep -qF -- 'tasks/interventions/T-901.md' "$LL_ROOT/err2" || fail "interventions-legacy-layout-resolution: the legacy path must be named in the refusal"
pass "interventions-legacy-layout-resolution positive+negative — the legacy record path is named on refusal (positive control above; no .shell-team hardcode)"

# --- interventions-order-disposition-first ----------------------------------
OD_ROOT="$IV_ROOT/order-disposition"
mkdir -p "$OD_ROOT"
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - fast-follow disposition (2026-01-01): pending: issue filing pending approval\n\n## Done\n' > "$OD_ROOT/todo.md"
cp "$OD_ROOT/todo.md" "$OD_ROOT/todo.orig"
set +e
( cd "$OD_ROOT" && TEAM_TODO="$OD_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$OD_ROOT/out" 2>"$OD_ROOT/err"
od_rc=$?
set -e
[ "$od_rc" -eq 1 ] || fail "interventions-order-disposition-first: expected exit 1 (T-068 gate), got $od_rc"
cmp -s "$OD_ROOT/todo.md" "$OD_ROOT/todo.orig" || fail "interventions-order-disposition-first: board must stay byte-identical"
grep -qF -- 'resolve it to a filed issue number or a waived reason before close-out' "$OD_ROOT/err" \
  || fail "interventions-order-disposition-first: the disposition message must win"
if grep -qF -- 'has no readable interventions record' "$OD_ROOT/err"; then
  fail "interventions-order-disposition-first: the interventions reason must NOT appear when the disposition gate already refused"
fi
pass "interventions-order-disposition-first — an unresolved pending disposition wins over a missing interventions record (D4 ordering)"

# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n  - fast-follow disposition (2026-01-01): filed as issue #999\n\n## Done\n' > "$OD_ROOT/todo.md"
set +e
( cd "$OD_ROOT" && TEAM_TODO="$OD_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$OD_ROOT/out2" 2>"$OD_ROOT/err2"
od_rc2=$?
set -e
[ "$od_rc2" -eq 1 ] || fail "interventions-order-disposition-first positive control: expected exit 1 (now the interventions gate) once the disposition is resolved, got $od_rc2"
grep -qF -- 'has no readable interventions record' "$OD_ROOT/err2" \
  || fail "interventions-order-disposition-first positive control: the interventions reason must be reachable once the disposition is resolved"
pass "interventions-order-disposition-first positive control — once the disposition resolves, the interventions gate becomes reachable (proving only ordering was being measured)"

# --- interventions-board-untouched-on-refusal -------------------------------
BU_ROOT="$IV_ROOT/board-untouched"
mkdir -p "$BU_ROOT"
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$BU_ROOT/todo.md"
cp "$BU_ROOT/todo.md" "$BU_ROOT/todo.orig"
set +e
( cd "$BU_ROOT" && TEAM_TODO="$BU_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) >"$BU_ROOT/out" 2>"$BU_ROOT/err"
bu_rc=$?
set -e
[ "$bu_rc" -eq 1 ] || fail "interventions-board-untouched-on-refusal: expected exit 1, got $bu_rc"
cmp -s "$BU_ROOT/todo.md" "$BU_ROOT/todo.orig" \
  || fail "interventions-board-untouched-on-refusal: the board must be byte-identical after any interventions refusal"
pass "interventions-board-untouched-on-refusal — every interventions-gate refusal leaves the board byte-identical (checked directly, not only inferred from the other assertions above)"

# ============================================================================
# T-1022 (#101): the check-handoff.sh sibling screen, ahead of the FIRST
# check-handoff.sh invocation. Against a scratch bin/ copy whose
# check-handoff.sh is (a) absent, (b) a non-regular file (a directory of
# that name), (c) a dangling symlink, (d) unreadable (mode 000, skipped when
# running as root, which ignores the read bit) — close-out exits 2 with
# reason E and leaves the board byte-identical. Positive control, last
# because it writes: restoring the real checker into the same scratch copy
# lets close-out complete.
# ============================================================================
HS_ROOT="$TMP/handoff-sibling"
mkdir -p "$HS_ROOT/root"
cp -R "$REPO_ROOT/bin" "$HS_ROOT/bin"
write_conformant_interventions_record "$HS_ROOT/root/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$HS_ROOT/root/todo.md"
cp "$HS_ROOT/root/todo.md" "$HS_ROOT/root/todo.orig"
HS_SIBLING="$HS_ROOT/bin/check-handoff.sh"

run_hs() {
  # $1 = expected exit code
  local want="$1" got=0
  ( cd "$HS_ROOT/root" && TEAM_TODO="$HS_ROOT/root/todo.md" bash "$HS_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) \
    >"$HS_ROOT/out" 2>"$HS_ROOT/err" || got=$?
  [ "$got" -eq "$want" ]
}

rm -f "$HS_SIBLING"
run_hs 2 || fail "closeout-handoff-sibling-absent-exit2: expected exit 2 for an absent check-handoff.sh"
cmp -s "$HS_ROOT/root/todo.md" "$HS_ROOT/root/todo.orig" || fail "closeout-handoff-sibling-absent-exit2: board must stay byte-identical"
grep -qF -- 'cannot run the hand-off lint (check-handoff.sh missing or unreadable next to close-out.sh)' "$HS_ROOT/err" \
  || fail "closeout-handoff-sibling-absent-exit2: reason E must be printed"
pass "closeout-handoff-sibling-absent-exit2 — an absent check-handoff.sh sibling refuses with exit 2, reason E, board untouched"

mkdir -p "$HS_SIBLING"
run_hs 2 || fail "closeout-handoff-sibling-nonregular-exit2: expected exit 2 for a directory named check-handoff.sh"
cmp -s "$HS_ROOT/root/todo.md" "$HS_ROOT/root/todo.orig" || fail "closeout-handoff-sibling-nonregular-exit2: board must stay byte-identical"
pass "closeout-handoff-sibling-nonregular-exit2 — a non-regular (directory) check-handoff.sh refuses with exit 2, board untouched"
rmdir "$HS_SIBLING"

ln -s "$HS_ROOT/nowhere-at-all" "$HS_SIBLING"
run_hs 2 || fail "closeout-handoff-sibling-dangling-symlink-exit2: expected exit 2 for a dangling symlink"
cmp -s "$HS_ROOT/root/todo.md" "$HS_ROOT/root/todo.orig" || fail "closeout-handoff-sibling-dangling-symlink-exit2: board must stay byte-identical"
pass "closeout-handoff-sibling-dangling-symlink-exit2 — a dangling symlink named check-handoff.sh refuses with exit 2, board untouched"
rm -f "$HS_SIBLING"

cp "$REPO_ROOT/bin/check-handoff.sh" "$HS_SIBLING"
if [ "$(id -u)" != "0" ]; then
  chmod 000 "$HS_SIBLING"
  run_hs 2 || fail "closeout-handoff-sibling-unreadable-exit2: expected exit 2 for a mode-000 check-handoff.sh"
  cmp -s "$HS_ROOT/root/todo.md" "$HS_ROOT/root/todo.orig" || fail "closeout-handoff-sibling-unreadable-exit2: board must stay byte-identical"
  grep -qF -- 'cannot run the hand-off lint' "$HS_ROOT/err" || fail "closeout-handoff-sibling-unreadable-exit2: reason E must be printed"
  pass "closeout-handoff-sibling-unreadable-exit2 — an unreadable (mode 000) check-handoff.sh refuses with exit 2, board untouched"
  chmod 644 "$HS_SIBLING"
else
  printf 'SKIP: closeout-handoff-sibling-unreadable-exit2 running as root; the read bit is ignored\n'
fi

run_hs 0 || fail "closeout-handoff-sibling-positive-control: expected exit 0 once the real checker is restored"
grep -q '^- \[x\] \*\*T-901\*\*' "$HS_ROOT/root/todo.md" || fail "closeout-handoff-sibling-positive-control: T-901 must move to Done"
pass "closeout-handoff-sibling-positive-control — restoring the real check-handoff.sh into the same scratch copy lets close-out complete"

# ============================================================================
# T-1022 (#98/D1/D3/D4): the source-line gate. The task's Active source line
# is judged by feeding a synthesized single-entry board to the sibling
# check-handoff.sh — no local copy of LINE_RE or the flag vocabulary.
# ============================================================================
SL_ROOT="$TMP/sourceline"
mkdir -p "$SL_ROOT"

sl_case() {
  # $1 = dir name (under $SL_ROOT), $2 = the board's Active source line
  local dir="$SL_ROOT/$1" line="$2"
  mkdir -p "$dir"
  write_conformant_interventions_record "$dir/.shell-team/interventions/T-901.md" T-901
  printf -- '# Tasks\n\n## Active\n\n%s\n\n## Done\n' "$line" > "$dir/todo.md"
  cp "$dir/todo.md" "$dir/todo.orig"
  sl_rc=0
  ( cd "$dir" && TEAM_TODO="$dir/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) \
    >"$dir/out" 2>"$dir/err" </dev/null || sl_rc=$?
}

# --- closeout-sourceline-whitespace-title-refuses / -flag-vocabulary-positive-control ---
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
sl_case whitespace-title '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md'
[ "$sl_rc" -eq 1 ] || fail "closeout-sourceline-whitespace-title-refuses: expected exit 1, got $sl_rc"
cmp -s "$SL_ROOT/whitespace-title/todo.md" "$SL_ROOT/whitespace-title/todo.orig" \
  || fail "closeout-sourceline-whitespace-title-refuses: board must stay byte-identical"
grep -qF -- 'would be rejected by the hand-off lint — refusing to move a malformed line into ## Done' "$SL_ROOT/whitespace-title/err" \
  || fail "closeout-sourceline-whitespace-title-refuses: reason F must be printed"
pass "closeout-sourceline-whitespace-title-refuses — a whitespace-only title (accepted by the flag rewrite, rejected by LINE_RE) refuses with exit 1, reason F, board untouched"

# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
sl_case whitespace-title-good '- [ ] **T-901** real title — `READY_FOR_QA` — spec: x.md'
[ "$sl_rc" -eq 0 ] || fail "closeout-sourceline-flag-vocabulary-positive-control: expected exit 0 for a well-formed title, got $sl_rc"
grep -q '^- \[x\] \*\*T-901\*\*' "$SL_ROOT/whitespace-title-good/todo.md" \
  || fail "closeout-sourceline-flag-vocabulary-positive-control: T-901 must move to Done"

# --- closeout-sourceline-refusal-names-real-board-line ----------------------
grep -qF -- "$SL_ROOT/whitespace-title/todo.md:5:" "$SL_ROOT/whitespace-title/err" \
  || fail "closeout-sourceline-refusal-names-real-board-line: reason F must carry the REAL board path and source-line number, not the temp file's"
pass "closeout-sourceline-refusal-names-real-board-line — reason F names <board>:5:, not the synthesized temp file's path"

# --- closeout-sourceline-invalid-flag-refuses -------------------------------
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
sl_case invalid-flag '- [ ] **T-901** demo — `ready_for_qa` — spec: x.md'
[ "$sl_rc" -eq 1 ] || fail "closeout-sourceline-invalid-flag-refuses: expected exit 1, got $sl_rc"
cmp -s "$SL_ROOT/invalid-flag/todo.md" "$SL_ROOT/invalid-flag/todo.orig" \
  || fail "closeout-sourceline-invalid-flag-refuses: board must stay byte-identical"
grep -qF -- "unknown status flag 'ready_for_qa'" "$SL_ROOT/invalid-flag/err" \
  || fail "closeout-sourceline-invalid-flag-refuses: the checker's own unknown-status-flag line must be surfaced verbatim"
grep -qF -- 'would be rejected by the hand-off lint — refusing to move a malformed line into ## Done' "$SL_ROOT/invalid-flag/err" \
  || fail "closeout-sourceline-invalid-flag-refuses: reason F must be printed"
pass "closeout-sourceline-invalid-flag-refuses — D1's declared additional refusal class: a flag outside ALLOWED_FLAGS is refused instead of laundered into READY_FOR_MERGE"

for f in READY_FOR_ARCH READY_FOR_ENG READY_FOR_QA READY_FOR_REVIEW READY_FOR_MERGE BLOCKED REWORK; do
  sl_case "flag-ok-$f" "- [ ] **T-901** demo — \`$f\` — spec: x.md"
  [ "$sl_rc" -eq 0 ] || fail "closeout-sourceline-flag-vocabulary-positive-control: flag $f expected exit 0, got $sl_rc"
  grep -q '^- \[x\] \*\*T-901\*\*' "$SL_ROOT/flag-ok-$f/todo.md" \
    || fail "closeout-sourceline-flag-vocabulary-positive-control: flag $f must move to Done"
done
pass "closeout-sourceline-flag-vocabulary-positive-control — each of the seven allowed flags closes out with exit 0"

# --- closeout-sourceline-stderr-order-note-checker-reason -------------------
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
sl_case ordering '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md'
[ "$sl_rc" -eq 1 ] || fail "closeout-sourceline-stderr-order-note-checker-reason: expected exit 1, got $sl_rc"
[ -s "$SL_ROOT/ordering/err" ] || fail "closeout-sourceline-stderr-order-note-checker-reason: expected non-empty stderr"
grep -qF -- 'the file:line below refers to a synthesized single-entry board, not the real board' "$SL_ROOT/ordering/err" \
  || fail "closeout-sourceline-stderr-order-note-checker-reason: the note line must be present"
grep -qF -- 'format mismatch' "$SL_ROOT/ordering/err" \
  || fail "closeout-sourceline-stderr-order-note-checker-reason: the checker's own classified line must be present"
grep -qF -- 'would be rejected by the hand-off lint' "$SL_ROOT/ordering/err" \
  || fail "closeout-sourceline-stderr-order-note-checker-reason: reason F must be present"
sl_l1=$(grep -nF -- 'the file:line below refers to a synthesized single-entry board, not the real board' "$SL_ROOT/ordering/err" | head -1 | cut -d: -f1)
sl_l2=$(grep -nF -- 'format mismatch' "$SL_ROOT/ordering/err" | head -1 | cut -d: -f1)
sl_l3=$(grep -nF -- 'would be rejected by the hand-off lint' "$SL_ROOT/ordering/err" | head -1 | cut -d: -f1)
if [ "$sl_l1" -ge "$sl_l2" ] || [ "$sl_l2" -ge "$sl_l3" ]; then
  fail "closeout-sourceline-stderr-order-note-checker-reason: expected strictly increasing line order note < checker-line < reason F, got $sl_l1/$sl_l2/$sl_l3"
fi
pass "closeout-sourceline-stderr-order-note-checker-reason — D4's three-part order (note, then checker stderr verbatim, then reason F) holds by strictly increasing stderr line number"

# --- closeout-sourceline-checker-exit2-floor / -checker-exit3-floor / -stub-zero-positive-control ---
STUB_SL_ROOT="$TMP/sourceline-stub"
mkdir -p "$STUB_SL_ROOT/root"
cp -R "$REPO_ROOT/bin" "$STUB_SL_ROOT/bin"
write_conformant_interventions_record "$STUB_SL_ROOT/root/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n' > "$STUB_SL_ROOT/root/todo.md"
cp "$STUB_SL_ROOT/root/todo.md" "$STUB_SL_ROOT/root/todo.orig"
STUB_SL="$STUB_SL_ROOT/bin/check-handoff.sh"

run_stub_sl() {
  sl_rc=0
  ( cd "$STUB_SL_ROOT/root" && TEAM_TODO="$STUB_SL_ROOT/root/todo.md" bash "$STUB_SL_ROOT/bin/close-out.sh" --task T-901 --date 2026-01-01 ) \
    >"$STUB_SL_ROOT/root/out" 2>"$STUB_SL_ROOT/root/err" </dev/null || sl_rc=$?
}

printf '#!/usr/bin/env bash\nprintf "stub cannot read\\n" >&2\nexit 2\n' > "$STUB_SL"
run_stub_sl
[ "$sl_rc" -eq 2 ] || fail "closeout-sourceline-checker-exit2-floor: expected exit 2, got $sl_rc"
cmp -s "$STUB_SL_ROOT/root/todo.md" "$STUB_SL_ROOT/root/todo.orig" || fail "closeout-sourceline-checker-exit2-floor: board must stay byte-identical"
grep -qF -- 'cannot verify the Active line (check-handoff.sh exited' "$STUB_SL_ROOT/root/err" \
  || fail "closeout-sourceline-checker-exit2-floor: reason G must be printed"
pass "closeout-sourceline-checker-exit2-floor — a stub exiting 2 (cannot read the synthesized board) is close-out exit 2, reason G"

printf '#!/usr/bin/env bash\nprintf "stub odd status\\n" >&2\nexit 3\n' > "$STUB_SL"
run_stub_sl
[ "$sl_rc" -eq 2 ] || fail "closeout-sourceline-checker-exit3-floor: expected exit 2, got $sl_rc"
cmp -s "$STUB_SL_ROOT/root/todo.md" "$STUB_SL_ROOT/root/todo.orig" || fail "closeout-sourceline-checker-exit3-floor: board must stay byte-identical"
grep -qF -- 'cannot verify the Active line (check-handoff.sh exited' "$STUB_SL_ROOT/root/err" \
  || fail "closeout-sourceline-checker-exit3-floor: reason G must be printed"
pass "closeout-sourceline-checker-exit3-floor — an unexpected exit status (3) is keyed on the status first and is NEVER guessed into row (i)'s board-defect message; also close-out exit 2, reason G"

printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB_SL"
run_stub_sl
[ "$sl_rc" -eq 0 ] || fail "closeout-sourceline-stub-zero-positive-control: expected exit 0, got $sl_rc"
grep -q '^- \[x\] \*\*T-901\*\*' "$STUB_SL_ROOT/root/todo.md" \
  || fail "closeout-sourceline-stub-zero-positive-control: T-901 must move to Done"
pass "closeout-sourceline-stub-zero-positive-control — a stub checker exiting 0 lets close-out complete (the scratch bin/ copy is otherwise functional)"

# --- closeout-sourceline-board-untouched-on-refusal -------------------------
# Already asserted per-case above via cmp; this dedicated id checks it
# directly against a fresh fixture, not only inferred from the cases above.
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
sl_case board-untouched '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md'
[ "$sl_rc" -eq 1 ] || fail "closeout-sourceline-board-untouched-on-refusal: expected exit 1, got $sl_rc"
cmp -s "$SL_ROOT/board-untouched/todo.md" "$SL_ROOT/board-untouched/todo.orig" \
  || fail "closeout-sourceline-board-untouched-on-refusal: the board must be byte-identical after a source-line refusal"
pass "closeout-sourceline-board-untouched-on-refusal — every source-line-gate refusal leaves the board byte-identical (checked directly)"

# --- closeout-sourceline-no-temp-leftovers ----------------------------------
NTL_TMP="$TMP/sourceline-tmpdir"
mkdir -p "$NTL_TMP"
NTL_ROOT="$TMP/sourceline-notemp"
mkdir -p "$NTL_ROOT"
write_conformant_interventions_record "$NTL_ROOT/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
printf -- '# Tasks\n\n## Active\n\n%s\n\n## Done\n' '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md' > "$NTL_ROOT/todo.md"
cp "$NTL_ROOT/todo.md" "$NTL_ROOT/todo.orig"
ntl_rc=0
( cd "$NTL_ROOT" && TMPDIR="$NTL_TMP" TEAM_TODO="$NTL_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) \
  >"$NTL_ROOT/out" 2>"$NTL_ROOT/err" </dev/null || ntl_rc=$?
[ "$ntl_rc" -eq 1 ] || fail "closeout-sourceline-no-temp-leftovers: expected exit 1, got $ntl_rc"
cmp -s "$NTL_ROOT/todo.md" "$NTL_ROOT/todo.orig" || fail "closeout-sourceline-no-temp-leftovers: board must stay byte-identical"
[ -z "$(ls -A "$NTL_TMP")" ] || fail "closeout-sourceline-no-temp-leftovers: leftover file(s) in private \$TMPDIR: $(ls -A "$NTL_TMP")"
pass "closeout-sourceline-no-temp-leftovers — a private \$TMPDIR is left with zero files after a source-line refusal (the gate's temp file joins the existing single trap)"

# ============================================================================
# T-1022 (#98/D9/D10): the differential-testing harness that enumerates the
# escape surface mechanically rather than by inspection. Every corpus line
# begins `- [ ] **T-901** ` (so pass 1 locates it) except a small
# deliberately-not-located set (D10's checkbox/id-shape axis). For each
# line: build a full board carrying it as T-901's only Active entry, run
# the REAL close-out.sh, and classify the outcome as notlocated (pass 1
# never finds T-901), refused, or accepted. For every located line the
# independently-computed oracle (bin/check-handoff.sh run live against a
# synthesized single-entry board — never a hardcoded verdict) must agree:
# oracle-reject implies close-out exits non-zero with the board
# byte-identical; oracle-accept implies close-out exits 0 with the entry
# moved. A disagreement increments `mismatches`.
# ============================================================================
printf '\n--- T-1022 differential-testing harness for the line-shape escape surface ---\n'

LS_ROOT="$TMP/lineshape"
mkdir -p "$LS_ROOT"

# LF-terminated lines. Axes named per D10: title shape (normal / padded /
# whitespace-only spaces / whitespace-only tab / empty), flag token (allowed /
# lowercase / near-miss / a token with spaces), trailing whitespace after the
# path (none / space), title content (plain / backticked token / decoy
# separator), path shape (x.md / docs/specs/ / .shell-team/specs/ / no .md),
# separator shape (em-dash with spaces / hyphen-minus / missing surrounding
# space), checkbox/id shape (the deliberately-not-located set).
# shellcheck disable=SC2016  # every backtick below is literal board grammar, not expansion
LS_LINES=(
  '- [ ] **T-901** demo title — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-901**   padded title   — `READY_FOR_ENG` — spec: x.md'
  '- [ ] **T-901** has a `token` inside — `BLOCKED` — spec: z.md'
  '- [ ] **T-901** legacy path — `READY_FOR_MERGE` — spec: docs/specs/y.md'
  '- [ ] **T-901** default layout path — `REWORK` — spec: .shell-team/specs/y.md'
  '- [ ] **T-901** trailing space var — `READY_FOR_QA` — spec: x.md '
  '- [ ] **T-901** decoy separator — `x` — spec: y.md but continues — `READY_FOR_REVIEW` — spec: real.md'
  '- [ ] **T-901** arch flag — `READY_FOR_ARCH` — spec: x.md'
  '- [ ] **T-901** merge flag — `READY_FOR_MERGE` — spec: x.md'
  '- [ ] **T-901** review flag — `READY_FOR_REVIEW` — spec: x.md'
  '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-901**  — `READY_FOR_QA` — spec: x.md'
  $'- [ ] **T-901** \t — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-901** demo — `ready_for_qa` — spec: x.md'
  '- [ ] **T-901** demo — `READY_FOR_MERGED` — spec: x.md'
  '- [ ] **T-901** demo — `READY FOR QA` — spec: x.md'
  '- [ ] **T-901** demo — `READY_FOR_QA` — spec: x'
  '- [ ] **T-901** demo - `READY_FOR_QA` - spec: x.md'
  '- [ ] **T-901** demo—`READY_FOR_QA`— spec: x.md'
  '- [ ] **T-901** demo — `readyforqa` — spec: x.md'
  '- [ ] **T-901** demo — `REWORK ` — spec: x.md'
  '- [x] **T-901** demo — `READY_FOR_QA` — spec: x.md'
  '  - [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md'
  '- [ ]  **T-901** demo — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-902** demo — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-901** qa flag plain — `READY_FOR_QA` — spec: x.md'
  '- [ ] **T-901** default path variant — `READY_FOR_QA` — spec: .shell-team/specs/x.md'
)

ls_corpus=0 ls_refused=0 ls_accepted=0 ls_notlocated=0 ls_mismatches=0

lineshape_case() {
  # $1 = case dir name, $2 = the line, $3 = crlf (1) or lf (0)
  local dir="$LS_ROOT/$1" line="$2" crlf="$3" got=0
  mkdir -p "$dir"
  write_conformant_interventions_record "$dir/.shell-team/interventions/T-901.md" T-901
  if [ "$crlf" = "1" ]; then
    printf -- '# Tasks\n\n## Active\n\n%s\n\n## Done\n' "$line" > "$dir/plain.md"
    awk '{ printf "%s\r\n", $0 }' "$dir/plain.md" > "$dir/todo.md"
  else
    printf -- '# Tasks\n\n## Active\n\n%s\n\n## Done\n' "$line" > "$dir/todo.md"
  fi
  cp "$dir/todo.md" "$dir/todo.orig"

  ( cd "$dir" && TEAM_TODO="$dir/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) \
    >"$dir/out" 2>"$dir/err" </dev/null || got=$?

  ls_corpus=$((ls_corpus + 1))
  if grep -qF -- 'not found as a top-level entry' "$dir/err" 2>/dev/null; then
    ls_notlocated=$((ls_notlocated + 1))
    return 0
  fi

  # Oracle: bin/check-handoff.sh run live against an independently-built
  # single-entry synthesized board — never a hardcoded verdict.
  if [ "$crlf" = "1" ]; then
    printf -- '## Active\n\n%s\n' "$line" > "$dir/oracle-plain.md"
    awk '{ printf "%s\r\n", $0 }' "$dir/oracle-plain.md" > "$dir/oracle.md"
  else
    printf -- '## Active\n\n%s\n' "$line" > "$dir/oracle.md"
  fi
  local oracle_rc=0
  bash "$REPO_ROOT/bin/check-handoff.sh" "$dir/oracle.md" >/dev/null 2>&1 || oracle_rc=$?

  if [ "$oracle_rc" -ne 0 ]; then
    ls_refused=$((ls_refused + 1))
    if [ "$got" = "0" ] || ! cmp -s "$dir/todo.md" "$dir/todo.orig"; then
      ls_mismatches=$((ls_mismatches + 1))
      printf 'MISMATCH (oracle rejects, expected close-out to refuse): %s (got exit %s)\n' "$line" "$got" >&2
    fi
  else
    ls_accepted=$((ls_accepted + 1))
    if [ "$got" != "0" ] || ! grep -q '^- \[x\] \*\*T-901\*\*' "$dir/todo.md"; then
      ls_mismatches=$((ls_mismatches + 1))
      printf 'MISMATCH (oracle accepts, expected close-out to complete): %s (got exit %s)\n' "$line" "$got" >&2
    fi
  fi
}

ls_i=0
for l in "${LS_LINES[@]}"; do
  ls_i=$((ls_i + 1))
  lineshape_case "case$ls_i" "$l" 0
done
# Line-terminator axis: the same shapes, CRLF-terminated throughout.
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
lineshape_case "crlf-accepted" '- [ ] **T-901** crlf accepted — `READY_FOR_QA` — spec: x.md' 1
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
lineshape_case "crlf-refused"  '- [ ] **T-901**    — `READY_FOR_QA` — spec: x.md' 1

printf 'closeout-lineshape-differential corpus=%d refused=%d accepted=%d notlocated=%d mismatches=%d\n' \
  "$ls_corpus" "$ls_refused" "$ls_accepted" "$ls_notlocated" "$ls_mismatches"

[ "$ls_corpus" -ge 24 ]     || fail "closeout-lineshape-differential: corpus floor not met ($ls_corpus < 24)"
[ "$ls_refused" -ge 6 ]     || fail "closeout-lineshape-differential: refused floor not met ($ls_refused < 6)"
[ "$ls_accepted" -ge 8 ]    || fail "closeout-lineshape-differential: accepted floor not met ($ls_accepted < 8)"
[ "$ls_notlocated" -ge 3 ]  || fail "closeout-lineshape-differential: notlocated floor not met ($ls_notlocated < 3)"
[ "$ls_mismatches" -eq 0 ]  || fail "closeout-lineshape-differential: $ls_mismatches mismatch(es) between the live oracle and close-out's real behavior"
pass "closeout-lineshape-differential — the escape surface is enumerated mechanically (D9/D10), never transcribed: corpus=$ls_corpus refused=$ls_refused accepted=$ls_accepted notlocated=$ls_notlocated mismatches=$ls_mismatches"

# --- closeout-unrelated-active-line-interlock-unchanged / closeout-done-section-loose-entry-unaffected ---
# D2's correction and Non-goals' `## Done` boundary lock, given their own
# assertion ids per AC13, distinct from AC16/AC17's inline checks above (the
# M5-adjacent interlock section) — both preservation locks, expected green
# before AND after this task.
UAL_ROOT="$TMP/unrelated-active-line"
mkdir -p "$UAL_ROOT"
write_conformant_interventions_record "$UAL_ROOT/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n- [ ] **T-902** broken line with no separator at all\n\n## Done\n' > "$UAL_ROOT/todo.md"
cp "$UAL_ROOT/todo.md" "$UAL_ROOT/todo.orig"
ual_rc=0
( cd "$UAL_ROOT" && TEAM_TODO="$UAL_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) \
  >"$UAL_ROOT/out" 2>"$UAL_ROOT/err" </dev/null || ual_rc=$?
[ "$ual_rc" -eq 1 ] || fail "closeout-unrelated-active-line-interlock-unchanged: expected exit 1, got $ual_rc"
cmp -s "$UAL_ROOT/todo.md" "$UAL_ROOT/todo.orig" || fail "closeout-unrelated-active-line-interlock-unchanged: board must stay byte-identical"
grep -qF -- 'rewritten board would fail check-handoff.sh' "$UAL_ROOT/err" \
  || fail "closeout-unrelated-active-line-interlock-unchanged: the pre-write interlock's own reason must still fire"
pass "closeout-unrelated-active-line-interlock-unchanged — D2's correction: an unrelated malformed Active line still refuses via the UNCHANGED pre-write interlock, at the same exit 1, not the source-line gate"

DSL_ROOT="$TMP/done-loose-entry"
mkdir -p "$DSL_ROOT"
write_conformant_interventions_record "$DSL_ROOT/.shell-team/interventions/T-901.md" T-901
# shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
printf -- '# Tasks\n\n## Active\n\n- [ ] **T-901** demo — `READY_FOR_QA` — spec: x.md\n\n## Done\n\n- [x] T-800 an old loose entry with no spec path\n' > "$DSL_ROOT/todo.md"
dsl_rc=0
( cd "$DSL_ROOT" && TEAM_TODO="$DSL_ROOT/todo.md" bash "$CLOSEOUT" --task T-901 --date 2026-01-01 ) \
  >"$DSL_ROOT/out" 2>"$DSL_ROOT/err" </dev/null || dsl_rc=$?
[ "$dsl_rc" -eq 0 ] || fail "closeout-done-section-loose-entry-unaffected: expected exit 0, got $dsl_rc"
grep -q '^- \[x\] \*\*T-901\*\*' "$DSL_ROOT/todo.md" || fail "closeout-done-section-loose-entry-unaffected: T-901 must move to Done"
grep -qxF -- '- [x] T-800 an old loose entry with no spec path' "$DSL_ROOT/todo.md" \
  || fail "closeout-done-section-loose-entry-unaffected: the pre-existing loose Done entry must survive byte-identically"
pass "closeout-done-section-loose-entry-unaffected — no check is widened to ## Done and no existing ## Done entry is repaired"

# ============================================================================
# T-1084: situational dispatch routing record — a validate-if-present content
# gate over `- dispatch:` sub-bullets, in the exact shape of the T-068
# `pending:` gate's own fixture pattern above. Nine cases: four the gate must
# say NOTHING about (an absent, partial, conformant or merely-quoted record —
# adopter back-compat) and five it must refuse with exit 1 and the literal
# "malformed dispatch record" on stderr.
# ============================================================================
DISPATCH_ROOT="$TMP/dispatch-fixtures"
mkdir -p "$DISPATCH_ROOT"

# $1 = task id (unique per case, so no fixture collides with another),
# $2 = the Active entry's sub-bullet body (printf %b — \n is a real newline,
# so a two-line body is passed as one string), $3 = expected exit code,
# $4 = "silent" (the gate must say nothing) or a substring the refusal's
# stderr must carry beyond the shared "malformed dispatch record" literal,
# $5 = the assertion name, $6 = optional label (defaults to "T-1084" — T-1091
# fixtures below pass "T-1091" so `grep -c '^PASS: T-1091'` counts them
# separately from T-1084's own floor, per that task's own frozen AC8's
# hard-coded label — a sibling helper was rejected in favor of one parameter
# with a back-compat default so every pre-existing call site is untouched).
dispatch_case() {
  local task="$1" body="$2" expect_rc="$3" mode="$4" name="$5" label="${6:-T-1084}"
  local root="$DISPATCH_ROOT/$task"
  # T-1092: every call site is redirected to a scratch reviews directory too
  # (harmless for every pre-existing case, none of which elects
  # `spec-review — cross-provider`), so no fixture here can ever read or
  # write this repository's own `.shell-team/reviews/`.
  mkdir -p "$root/.shell-team/reviews"
  write_conformant_interventions_record "$root/.shell-team/interventions/$task.md" "$task"
  # shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
  printf -- '# Tasks\n\n## Active\n\n- [ ] **%s** dispatch fixture — `READY_FOR_MERGE` — spec: docs/specs/fixture.md\n%b\n\n## Done\n' \
    "$task" "$body" > "$root/todo.md"
  cp "$root/todo.md" "$root/todo.orig"
  local rc=0
  ( cd "$root" && TEAM_TODO="$root/todo.md" TEAM_INTERVENTIONS_DIR="$root/.shell-team/interventions" TEAM_REVIEWS_DIR="$root/.shell-team/reviews" \
      bash "$CLOSEOUT" --task "$task" --date 2026-08-19 ) >"$root/out" 2>"$root/err" </dev/null || rc=$?
  [ "$rc" -eq "$expect_rc" ] || fail "$label $name: expected exit $expect_rc, got $rc (stderr: $(cat "$root/err"))"
  if [ "$mode" = silent ]; then
    grep -qF -- 'malformed dispatch record' "$root/err" \
      && fail "$label $name: the gate must say NOTHING here — found the refusal literal in stderr"
    grep -qxF -- "- [x] **$task** dispatch fixture — \`READY_FOR_MERGE\` — spec: docs/specs/fixture.md" "$root/todo.md" \
      || fail "$label $name: close-out should have moved the entry to Done"
  else
    cmp -s "$root/todo.orig" "$root/todo.md" \
      || fail "$label $name: a refused close-out must leave the board byte-untouched"
    grep -qF -- 'malformed dispatch record' "$root/err" \
      || fail "$label $name: refusal stderr must carry the literal 'malformed dispatch record'"
    grep -qF -- "$mode" "$root/err" \
      || fail "$label $name: refusal stderr must carry the offending detail '$mode' (stderr: $(cat "$root/err"))"
  fi
  pass "$label $name"
}

OKI='  - dispatch: implement — serial — unconditional — recommendation: tier2-parallel-implementations-judge'
OKV='  - dispatch: verify — serial — unconditional — recommendation: tier1-verification-fanout'

dispatch_case T-970 "$OKI\n$OKV" 0 silent "conformant two-axis record passes the gate"
dispatch_case T-971 '  - source: fixture' 0 silent "absent record passes (adopter back-compat)"
dispatch_case T-972 "$OKI" 0 silent "single-axis (partial) record passes — completeness is norm text, not the gate's business"
# shellcheck disable=SC2016  # backtick-quoted example is literal fixture text, not a substitution
dispatch_case T-973 '  - note: quoting `- dispatch: verify — tier2 — unconditional — x` inline' 0 silent "mid-line prose quote is not mistaken for a record"
dispatch_case T-974 "$OKI\n  - dispatch: verify — tier2 — unconditional — recommendation: tier1-verification-fanout" 1 "'tier2' is not in axis 'verify'" "cross-axis value refuses"
dispatch_case T-975 "$OKI\n$OKI" 1 "'implement' appears more than once" "duplicate axis refuses"
dispatch_case T-976 "$OKI\n  - dispatch: depth — serial — unconditional — recommendation: tier1-verification-fanout" 1 "axis 'depth' is not one" "unknown axis refuses"
dispatch_case T-977 "$OKI\n  - dispatch: verify — serial — maybe — recommendation: tier1-verification-fanout" 1 "modality 'maybe'" "bad modality refuses"
dispatch_case T-978 "$OKI\n  - dispatch: verify — serial — unconditional — because I said so" 1 'ground does not open with' "groundless ground refuses"

# ============================================================================
# T-1084 round-1 rework (Codex review, commit d69cb16): the two Major findings
# were one class — "the gate validates a narrower line shape than the set of
# lines it must judge" — not two isolated spots. Each fixture below is one
# enumerated shape variant from that class, each proven SEEN and REFUSED
# (never silently invisible), plus one positive control proving the widened
# candidate-scan anchor still recognizes the reachable tab-indentation case
# correctly. `TAB` holds one real tab byte (not the two-character escape
# `\t`, which `printf %b` would otherwise need to interpret) so it can be
# spliced into a fixture body unescaped.
# ============================================================================
TAB="$(printf '\t')"

# --- whitespace-after-"dispatch:" variants (Major 2's own class) -----------
# Before this round: the candidate scan required a literal ASCII space right
# after the colon, so any of these three lines was never even inspected —
# an exit-0, silent bypass. After: the scan anchor drops the trailing-space
# requirement (every variant is SEEN), and the strict per-field grammar
# below — unchanged, still exactly one canonical space — refuses each one
# via the existing empty-field check.
dispatch_case T-979 "$OKI\n  - dispatch:${TAB}verify — serial — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "tab-after-dispatch-colon refuses (Major 2's exact reproduction — seen and refused, not silently invisible)"
dispatch_case T-980 "$OKI\n  - dispatch:  verify — serial — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "double-space-after-dispatch-colon refuses"
dispatch_case T-981 "$OKI\n  - dispatch:verify — serial — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "no-space-after-dispatch-colon refuses"

# --- ground-prefix-id emptiness (Major 1's own class) -----------------------
# Before this round: `recommendation: ` (prefix, space, nothing) passed the
# ground check, because it verified the prefix and the following space only
# and never that a non-empty id token follows.
dispatch_case T-982 "$OKI\n  - dispatch: verify — serial — unconditional — recommendation: " 1 "does not open with a non-empty id" "empty-priced-line-id refuses (Major 1's exact reproduction)"

# --- emptiness on the other three fields, so the fixture matrix does not ---
# --- lean on the ground fix alone to prove the class is closed -------------
dispatch_case T-983 "$OKI\n  - dispatch:  — serial — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "empty-axis-field refuses"
dispatch_case T-984 "$OKI\n  - dispatch: verify —  — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "empty-value-field refuses"
dispatch_case T-985 "$OKI\n  - dispatch: verify — serial —  — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "empty-modality-field refuses"

# --- the ` — ` separator itself: a spacing variant (missing space before the
# --- em dash) must be seen-and-refused, matching the already-correct
# --- behavior for a wrong separator character entirely (T-974's sibling) ---
dispatch_case T-986 "$OKI\n  - dispatch: verify—serial — unconditional — recommendation: tier1-verification-fanout" 1 "does not match the grammar" "missing-space-before-em-dash-separator refuses"

# --- positive control: the reachable tab-indented sub-bullet class (this
# --- spec's own ## Input space) still recognizes and validates a CONFORMANT
# --- record correctly once the candidate anchor is widened — the widening
# --- must not turn a real record invisible or falsely reject it -----------
dispatch_case T-987 "${TAB}- dispatch: implement — serial — unconditional — recommendation: tier2-parallel-implementations-judge\n${TAB}- dispatch: verify — serial — unconditional — recommendation: tier1-verification-fanout" 0 silent "tab-indented conformant record still passes (positive control on the widened anchor)"

# ============================================================================
# T-1091: the `specify` axis — one data row on the same DISPATCH_AXIS_TABLE,
# no logic change. Seven cases labelled "T-1091" (see dispatch_case's own
# label parameter above): the axis's own conformant/back-compat/refusal
# shapes, exercised against the real script exactly as T-1084's own cases
# above are.
# ============================================================================
OKS='  - dispatch: specify — pm-authored — unconditional — cost-input: spec-authorship-judgment-density'

dispatch_case T-988 "$OKI\n$OKV\n$OKS" 0 silent "conformant three-axis record (implement/verify/specify) passes the gate" T-1091
dispatch_case T-989 "$OKI\n$OKV" 0 silent "two-axis record with no specify sub-bullet still passes (every in-flight task under the two-axis dispatcher, never refused retroactively)" T-1091
dispatch_case T-990 "$OKI\n  - dispatch: specify — serial — unconditional — cost-input: spec-authorship-judgment-density" 1 "'serial' is not in axis 'specify'" "cross-axis value 'specify — serial' refuses (all three axes share one editing surface)" T-1091
dispatch_case T-991 "$OKV\n  - dispatch: implement — pm-authored — unconditional — recommendation: tier2-parallel-implementations-judge" 1 "'pm-authored' is not in axis 'implement'" "cross-axis value 'implement — pm-authored' refuses (the transposition in the other direction)" T-1091
dispatch_case T-992 "$OKI\n$OKS\n$OKS" 1 "'specify' appears more than once" "duplicated specify axis refuses" T-1091
dispatch_case T-993 "$OKI\n  - dispatch:${TAB}specify — pm-authored — unconditional — cost-input: spec-authorship-judgment-density" 1 "does not match the grammar" "tab-after-dispatch-colon on specify refuses (seen and refused, not silently invisible)" T-1091
dispatch_case T-994 "${TAB}- dispatch: implement — serial — unconditional — recommendation: tier2-parallel-implementations-judge\n${TAB}- dispatch: specify — pm-authored — unconditional — cost-input: spec-authorship-judgment-density" 0 silent "tab-indented conformant specify record still passes (positive control on the widened anchor)" T-1091

# ============================================================================
# T-1092: the `spec-review` axis — one more data row on the same
# DISPATCH_AXIS_TABLE (grammar cases, exercised via dispatch_case exactly as
# T-1091's own cases above are) plus a second, independent fail-closed
# refusal class — the teeth gate, which reads a redirected reviews directory
# rather than the dispatch grammar (exercised via the dedicated
# spec_review_case helper below, because its own refusal sentinel differs
# from 'malformed dispatch record').
# ============================================================================
OKR='  - dispatch: spec-review — none — unconditional — recommendation: spec-review-none-default'
ELECT='  - dispatch: spec-review — cross-provider — conditional — cost-input: t1092-domain-premise-count'

dispatch_case T-99510 "$OKI\n$OKV\n$OKS\n$OKR" 0 silent "conformant four-axis record (implement/verify/specify/spec-review) passes the gate" T-1092
dispatch_case T-99511 "$OKI\n$OKV\n$OKS" 0 silent "three-axis record with no spec-review sub-bullet still passes (every in-flight task under the three-axis dispatcher, never refused retroactively)" T-1092
dispatch_case T-99512 "$OKI\n  - dispatch: spec-review — serial — unconditional — recommendation: spec-review-none-default" 1 "'serial' is not in axis 'spec-review'" "cross-axis value 'spec-review — serial' refuses (all four axes share one editing surface)" T-1092
dispatch_case T-99513 "$OKV\n  - dispatch: implement — cross-provider — unconditional — recommendation: tier2-parallel-implementations-judge" 1 "'cross-provider' is not in axis 'implement'" "cross-axis value 'implement — cross-provider' refuses (the transposition in the other direction)" T-1092
dispatch_case T-99514 "$OKI\n$OKR\n$OKR" 1 "'spec-review' appears more than once" "duplicated spec-review axis refuses" T-1092
dispatch_case T-99515 "$OKI\n  - dispatch:${TAB}spec-review — none — unconditional — recommendation: spec-review-none-default" 1 "does not match the grammar" "tab-after-dispatch-colon on spec-review refuses (seen and refused, not silently invisible)" T-1092
dispatch_case T-99516 "${TAB}- dispatch: implement — serial — unconditional — recommendation: tier2-parallel-implementations-judge\n${TAB}- dispatch: spec-review — none — unconditional — recommendation: spec-review-none-default" 0 silent "tab-indented conformant spec-review record still passes (positive control on the widened anchor)" T-1092

# --- the teeth gate (AC6): a redirected reviews directory, a different ------
# --- refusal sentinel, and no dependence on the dispatch grammar's own -----
# --- literal — a dedicated helper rather than overloading dispatch_case ----
SPEC_REVIEW_SENTINEL='elected spec review has no APPROVE verdict'
spec_review_case() {
  local task="$1" body="$2" review_body="$3" expect_rc="$4" mode="$5" name="$6"
  local root="$DISPATCH_ROOT/$task"
  mkdir -p "$root/.shell-team/reviews"
  write_conformant_interventions_record "$root/.shell-team/interventions/$task.md" "$task"
  if [ -n "$review_body" ]; then
    printf -- '%b\n' "$review_body" > "$root/.shell-team/reviews/$task.md"
    test -s "$root/.shell-team/reviews/$task.md" || fail "T-1092 $name: could not write the synthesized review record"
  fi
  # shellcheck disable=SC2016  # backtick-quoted flag is literal board grammar
  printf -- '# Tasks\n\n## Active\n\n- [ ] **%s** dispatch fixture — `READY_FOR_MERGE` — spec: docs/specs/fixture.md\n%b\n\n## Done\n' \
    "$task" "$body" > "$root/todo.md"
  cp "$root/todo.md" "$root/todo.orig"
  local rc=0
  ( cd "$root" && TEAM_TODO="$root/todo.md" TEAM_INTERVENTIONS_DIR="$root/.shell-team/interventions" TEAM_REVIEWS_DIR="$root/.shell-team/reviews" \
      bash "$CLOSEOUT" --task "$task" --date 2026-08-19 ) >"$root/out" 2>"$root/err" </dev/null || rc=$?
  [ "$rc" -eq "$expect_rc" ] || fail "T-1092 $name: expected exit $expect_rc, got $rc (stderr: $(cat "$root/err"))"
  if [ "$mode" = silent ]; then
    grep -qF -- "$SPEC_REVIEW_SENTINEL" "$root/err" \
      && fail "T-1092 $name: the gate must say NOTHING here — found the refusal sentinel in stderr"
    grep -qxF -- "- [x] **$task** dispatch fixture — \`READY_FOR_MERGE\` — spec: docs/specs/fixture.md" "$root/todo.md" \
      || fail "T-1092 $name: close-out should have moved the entry to Done"
  else
    cmp -s "$root/todo.orig" "$root/todo.md" \
      || fail "T-1092 $name: a refused close-out must leave the board byte-untouched"
    grep -qF -- "$SPEC_REVIEW_SENTINEL" "$root/err" \
      || fail "T-1092 $name: refusal stderr must carry the sentinel '$SPEC_REVIEW_SENTINEL'"
  fi
  pass "T-1092 $name"
}

spec_review_case T-99501 "$OKI\n$ELECT" '### Codex Spec-Review verdict: APPROVE' 0 silent "elected + APPROVE record passes (also the positive control on the \$TEAM_REVIEWS_DIR override itself: the record exists only inside the scratch directory)"
spec_review_case T-99502 "$OKI\n$ELECT" '' 1 refuse "elected + no record refuses"
spec_review_case T-99503 "$OKI\n$ELECT" '### Codex Spec-Review verdict: REQUEST_CHANGES' 1 refuse "elected + REQUEST_CHANGES-only record refuses"
spec_review_case T-99504 "$OKI\n$ELECT" '## Spec review\n\nnothing was recorded here' 1 refuse "elected + non-empty record with no spec-review verdict heading at all refuses"
spec_review_case T-99505 "$OKI\n$OKR" '' 0 silent "none + no record passes (every task that declines the extra round)"

# --- review round 1, Majors 2+3: the verdict match was (a) unanchored — any -
# --- heading with `APPROVE` as a literal PREFIX satisfied the gate — and (b) -
# --- unscoped — it read the WHOLE file rather than the record's LATEST
# --- `## Spec review` round. Fixtures below reproduce both defeat classes
# --- against the real, fixed script, plus a positive control confirming the
# --- section-scoping fix doesn't over-narrow the ordinary fixed-then-approved
# --- multi-round case.
spec_review_case T-99506 "$OKI\n$ELECT" '### Codex Spec-Review verdict: APPROVE_WITH_CAVEATS' 1 refuse "elected + a prefix-matching near-miss verdict value (APPROVE_WITH_CAVEATS) refuses (Major 2's exact reproduction)"
spec_review_case T-99507 "$OKI\n$ELECT" '### Codex Spec-Review verdict: APPROVE | REQUEST_CHANGES' 1 refuse "elected + the mode's own unfilled output template text (a literal 'APPROVE | REQUEST_CHANGES' copy) refuses (the adversarial pass's own reproduction)"
spec_review_case T-99508 "$OKI\n$ELECT" '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n\n## Spec review\n\n### Codex Spec-Review verdict: REQUEST_CHANGES' 1 refuse "elected + a stale earlier-round APPROVE surviving alongside a later REQUEST_CHANGES round refuses (Major 3's exact reproduction — the LATEST round is what gates, not any round)"
spec_review_case T-99509 "$OKI\n$ELECT" '## Spec review\n\n### Codex Spec-Review verdict: REQUEST_CHANGES\n\n## Spec review\n\n### Codex Spec-Review verdict: APPROVE' 0 silent "elected + an earlier REQUEST_CHANGES followed by a later, fixed APPROVE round passes (positive control: section-scoping to the latest round does not over-narrow the ordinary answered-then-approved flow)"

# --- review round 2, Blocker 1: the round-2 fix paired an EXACT heading ---
# --- search with a LOOSE boundary check, so a later `## Spec review`
# --- heading carrying a trailing-whitespace deviation was invisible to the
# --- search but visible to the boundary — the scan anchored to an EARLIER
# --- round and stopped right before the malformed LATER one, hiding its
# --- REQUEST_CHANGES entirely. Reproduces the reviewer's own repro exactly
# --- (round 2's heading carries one trailing space after "review").
spec_review_case T-99517 "$OKI\n$ELECT" '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n\n## Spec review \n\n### Codex Spec-Review verdict: REQUEST_CHANGES' 1 refuse "elected + a LATER round whose heading carries a trailing space still refuses on its own REQUEST_CHANGES (Blocker 1's exact reproduction — the heading-search and boundary checks must agree, not just the boundary check)"

# --- review round 2, Blocker 2: `printf | grep -q` is racy under pipefail
# --- for a large section — grep can match and still report a SIGPIPE'd
# --- printf's failure as the pipeline's own exit status, falsely refusing
# --- a genuinely valid APPROVE. Reproduces with a ~200KB section (well
# --- past any plausible pipe-buffer size), matching the reviewer's own
# --- repro; this is a POSITIVE case (a real refusal here would BE the bug).
LARGE_FILLER="$(head -c 100000 /dev/zero | tr '\0' 'x')"
LARGE_BODY="## Spec review\n\n${LARGE_FILLER}\n\n### Codex Spec-Review verdict: APPROVE\n\n${LARGE_FILLER}"
spec_review_case T-99518 "$OKI\n$ELECT" "$LARGE_BODY" 0 silent "elected + a ~200KB Spec review section with a genuinely valid, exactly-matching APPROVE still passes (Blocker 2's exact reproduction — the verdict match must not be racy under pipefail on a large section)"

# --- one-item scope extension (QA round 3's own probe, operator-approved) -
# --- round-3's first fix trimmed TRAILING whitespace only, so an INTERNAL
# --- whitespace variant of the later heading (a double space between `##`
# --- and `Spec`) was still invisible to the selector while the loose
# --- boundary still recognized it as a heading — the same defect shape as
# --- T-99517, one whitespace position over. QA's own exact repro.
spec_review_case T-99519 "$OKI\n$ELECT" '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n\n##  Spec review\n\n### Codex Spec-Review verdict: REQUEST_CHANGES' 1 refuse "elected + a LATER round whose heading carries an internal double space (## then two spaces then Spec review) still refuses on its own REQUEST_CHANGES (the one-item scope extension's exact reproduction)"

# --- design fix (QA round 4's own probe, operator-ruled option A, third --
# --- ruling on this component): the boundary check read the RAW line
# --- while the selector read a NORMALIZED line, so a later, genuinely
# --- unrelated heading indented with LEADING whitespace was invisible to
# --- the boundary's raw `/^## /` test — the extraction leaked past it,
# --- and a stray APPROVE line hiding in the leaked content produced a
# --- FALSE PASS on a record whose true latest round was REQUEST_CHANGES.
# --- QA's own exact repro; this is the dangerous direction (a false
# --- silent PASS, not merely an over-eager refusal).
spec_review_case T-99520 "$OKI\n$ELECT" '## Spec review\n\n### Codex Spec-Review verdict: REQUEST_CHANGES\n\n  ## Some Other Section\n\n### Codex Spec-Review verdict: APPROVE' 1 refuse "elected + a later, unrelated heading with LEADING whitespace does not let a stray APPROVE hiding after it leak into the latest round — the record's true latest round (REQUEST_CHANGES) still refuses (QA round 4's exact false-PASS reproduction)"

printf '\nAll close-out assertions passed.\n'
