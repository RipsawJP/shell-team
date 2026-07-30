#!/usr/bin/env bash
# run.sh — assert bin/playbook-promote.sh honors the T-045 behavior contract
# (docs/specs/T-045-ace-playbook.md):
#   AC4  candidate -> human approval -> playbook-promote.sh -> gen-playbook-
#        blocks.sh path is documented; playbook-promote.sh validates a
#        candidate fail-closed (schema violation => nothing appended) before
#        appending it to tasks/lessons.md
#   AC8  shellcheck clean (soft-skip when unavailable)
#
# The human-gate documentation itself (docs/loop-engineering/
# playbook-update-path.md) is checked here for existence + the expected
# "human-run" framing; full prose review is a runtime (QA) reading task, not
# scriptable — see the spec's AC4 runtime sub-bullet.
#
# Temp files live under $TMPDIR when set (restricted sandboxes), falling back
# to $HERE/tmp-roots on plain CI runners. Cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PROMOTE="$REPO_ROOT/bin/playbook-promote.sh"
CHECKER="$REPO_ROOT/bin/check-playbook.sh"
BASE="$HERE/fixtures/lessons-base.md"
if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/playbook-promote-test-roots"
else
  TMP="$HERE/tmp-roots"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

fresh_lessons() {  # $1 = destination path
  cp "$BASE" "$1"
}

# --- happy path: a valid candidate is appended and re-validates green -------
L="$TMP/happy.md"
fresh_lessons "$L"
rc=0
out="$(bash "$PROMOTE" \
  --lessons "$L" --date 2099-06-01 --title "test candidate" \
  --category process --applies-to "engineer, qa-verifier" --status active \
  --source "T-045 test" --rule "Test rule." --why "Test why." \
  --how-to-apply "Test how-to-apply." 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || fail "happy path must exit 0, got $rc (output: $out)"
grep -qF '## 2099-06-01 — test candidate' "$L" || fail "happy path: heading not appended"
grep -qF -- '- **Rule**: Test rule.' "$L"        || fail "happy path: Rule bullet not appended"
grep -qF 'Pre-existing rule.' "$L"               || fail "happy path: pre-existing entry must survive (append-only)"
bash "$CHECKER" "$L" >/dev/null 2>&1              || fail "happy path: resulting lessons file must pass bin/check-playbook.sh"
pass "AC4: a valid candidate is appended and the resulting file re-validates green"

# --- append-only: a second call appends a SECOND distinct entry -------------
rc=0
bash "$PROMOTE" \
  --lessons "$L" --date 2099-06-02 --title "second candidate" \
  --category tooling-ci --applies-to all --status active \
  --source "T-045 test 2" --rule "Second rule." --why "Second why." \
  --how-to-apply "Second how-to-apply." >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "second promote call must exit 0"
grep -qF '## 2099-06-01 — test candidate'   "$L" || fail "append-only: first entry must survive a second call"
grep -qF '## 2099-06-02 — second candidate' "$L" || fail "append-only: second entry must be appended, not replace the first"
bash "$CHECKER" "$L" >/dev/null 2>&1 || fail "append-only: file must still pass bin/check-playbook.sh after two promotions"
pass "AC4: repeated calls append distinct entries (append-only, never overwrite)"

# --- T-1006 AC9/AC21: the resolver-derived default is used when --lessons ---
# is omitted, on both layouts, resolved against the CURRENT WORKING DIRECTORY
# (no --root flag on this script).
DEF_ROOT="$TMP/t1006-default-layout"
mkdir -p "$DEF_ROOT/.shell-team"
fresh_lessons "$DEF_ROOT/.shell-team/lessons.md"
rc=0
(cd "$DEF_ROOT" && env -u TEAM_RUN_BASE bash "$PROMOTE" \
  --date 2099-06-11 --title "t1006 default layout" --category process \
  --applies-to all --status active --source "T-1006 test" \
  --rule "R." --why "W." --how-to-apply "H." >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 0 ] || fail "T-1006: default-layout resolver-derived promote must exit 0"
grep -qF '## 2099-06-11 — t1006 default layout' "$DEF_ROOT/.shell-team/lessons.md" \
  || fail "T-1006: default-layout entry must land in .shell-team/lessons.md"

LEG_ROOT="$TMP/t1006-legacy-layout"
mkdir -p "$LEG_ROOT/tasks/loops"
: > "$LEG_ROOT/tasks/loops/shell-team.contract.yaml"
fresh_lessons "$LEG_ROOT/tasks/lessons.md"
rc=0
(cd "$LEG_ROOT" && env -u TEAM_RUN_BASE bash "$PROMOTE" \
  --date 2099-06-12 --title "t1006 legacy layout" --category process \
  --applies-to all --status active --source "T-1006 test" \
  --rule "R." --why "W." --how-to-apply "H." >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 0 ] || fail "T-1006: legacy-layout resolver-derived promote must exit 0"
grep -qF '## 2099-06-12 — t1006 legacy layout' "$LEG_ROOT/tasks/lessons.md" \
  || fail "T-1006: legacy-layout entry must land in tasks/lessons.md"
pass "T-1006: the resolver-derived default is used when --lessons is omitted"

# --- T-1006 AC10/AC21: a resolver failure is fail-closed (nothing appended) -
# Positive control: an explicit --lessons still appends under the same
# invalid environment. Then two failure probes: invalid $TEAM_RUN_BASE with
# no --lessons, and a sibling team-paths.sh stubbed to exit 0 printing
# nothing (the empty-path hole) — both must exit 2, leave the resolved
# default byte-untouched, and share the message.
FC_ROOT="$TMP/t1006-fail-closed"
mkdir -p "$FC_ROOT/.shell-team"
fresh_lessons "$FC_ROOT/.shell-team/lessons.md"
cp "$FC_ROOT/.shell-team/lessons.md" "$TMP/t1006-fail-closed-orig.md"
cp "$FC_ROOT/.shell-team/lessons.md" "$TMP/t1006-fail-closed-custom.md"
rc=0
(cd "$FC_ROOT" && TEAM_RUN_BASE=.. bash "$PROMOTE" \
  --lessons "$TMP/t1006-fail-closed-custom.md" --date 2099-06-13 \
  --title "t1006 override under broken env" --category process \
  --applies-to all --status active --source "T-1006 test" \
  --rule "R." --why "W." --how-to-apply "H." >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 0 ] || fail "T-1006: an explicit --lessons must still append under an invalid \$TEAM_RUN_BASE"
grep -qF '## 2099-06-13 — t1006 override under broken env' "$TMP/t1006-fail-closed-custom.md" \
  || fail "T-1006: the explicit --lessons override must have appended"
cmp -s "$FC_ROOT/.shell-team/lessons.md" "$TMP/t1006-fail-closed-orig.md" \
  || fail "T-1006: the resolved default must stay byte-untouched while --lessons overrides"

rca=0
erra="$(cd "$FC_ROOT" && TEAM_RUN_BASE=.. bash "$PROMOTE" \
  --date 2099-06-14 --title "t1006 broken env" --category process \
  --applies-to all --status active --source "T-1006 test" \
  --rule "R." --why "W." --how-to-apply "H." 2>&1)" || rca=$?
[ "$rca" -eq 2 ] || fail "T-1006: an invalid \$TEAM_RUN_BASE with no --lessons must exit 2, got $rca"
case "$erra" in
  *"could not resolve the lessons path"*) : ;;
  *) fail "T-1006: invalid \$TEAM_RUN_BASE: expected 'could not resolve the lessons path', got: $erra" ;;
esac
cmp -s "$FC_ROOT/.shell-team/lessons.md" "$TMP/t1006-fail-closed-orig.md" \
  || fail "T-1006: an invalid \$TEAM_RUN_BASE must leave the resolved default byte-untouched"

STUB_BIN="$TMP/t1006-stub-bin"
rm -rf "$STUB_BIN"
cp -R "$REPO_ROOT/bin" "$STUB_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB_BIN/team-paths.sh"
chmod 755 "$STUB_BIN/team-paths.sh"
rcb=0
errb="$(cd "$FC_ROOT" && env -u TEAM_RUN_BASE bash "$STUB_BIN/playbook-promote.sh" \
  --date 2099-06-15 --title "t1006 empty resolver" --category process \
  --applies-to all --status active --source "T-1006 test" \
  --rule "R." --why "W." --how-to-apply "H." 2>&1)" || rcb=$?
[ "$rcb" -eq 2 ] || fail "T-1006: an empty-printing resolver stub must exit 2, got $rcb"
case "$errb" in
  *"could not resolve the lessons path"*) : ;;
  *) fail "T-1006: empty resolver stub: expected 'could not resolve the lessons path', got: $errb" ;;
esac
cmp -s "$FC_ROOT/.shell-team/lessons.md" "$TMP/t1006-fail-closed-orig.md" \
  || fail "T-1006: an empty-printing resolver stub must leave the resolved default byte-untouched"
pass "T-1006: a resolver failure is fail-closed (nothing appended)"

# --- default --date is today when omitted (the SOLE date coverage path) -----
# T-054 (#135) fast-follow: this is now the only test exercising the
# omitted-`--date` default — the earlier test-only env-var override hook in
# bin/playbook-promote.sh has been removed as redundant now that this
# fixed-output-fake-`date`-on-PATH approach exercises the REAL production
# `$(date +%F)` fallback directly (tasks/reviews/T-050.md round2 Minor).
# Putting a FIXED-OUTPUT fake `date` executable at the front of PATH
# makes the real `$(date +%F)` line in bin/playbook-promote.sh actually run —
# against the fake `date`, which always returns the same fixed, valid
# Gregorian calendar date regardless of when it's invoked (2020-01-01 — a
# real date, not a placeholder shape, so T-047's calendar validation accepts
# it), closing the theoretical midnight-boundary race (tasks/reviews/
# T-048.md round3 Minor) with genuine production-line coverage instead of a
# test-only override. Any OTHER argument shape falls through to the real
# `date` binary (captured once, before PATH is modified, so the fallback
# itself never re-enters this fake script), so nothing else invoked under
# this PATH prefix (there is nothing else here) could break.
REAL_DATE="$(command -v date)"
FAKE_DATE_DIR="$TMP/fakebin"
mkdir -p "$FAKE_DATE_DIR"
FAKE_DATE_VALUE="2020-01-01"
cat > "$FAKE_DATE_DIR/date" <<EOF
#!/usr/bin/env bash
# Fixed-output fake date (T-050 rework1, #132) — intercepts only the exact
# "date +%F" shape bin/playbook-promote.sh's fallback calls; any other
# invocation falls through to the real date binary captured at generation
# time (before PATH was modified), so it can never recurse into itself.
if [ "\$#" -eq 1 ] && [ "\$1" = "+%F" ]; then
  printf '%s\n' "$FAKE_DATE_VALUE"
  exit 0
fi
exec "$REAL_DATE" "\$@"
EOF
chmod +x "$FAKE_DATE_DIR/date"

L="$TMP/default-date-real-fallback.md"
fresh_lessons "$L"
PATH="$FAKE_DATE_DIR:$PATH" bash "$PROMOTE" --lessons "$L" --title "no explicit date, real fallback" \
  --category process --applies-to engineer --status active --source n/a \
  --rule "r" --why "w" --how-to-apply "h" >/dev/null 2>&1
grep -qF "## ${FAKE_DATE_VALUE} — no explicit date, real fallback" "$L" \
  || fail "omitted --date must use the real \$(date +%F) fallback (expected $FAKE_DATE_VALUE)"
pass "omitted --date exercises the REAL production \$(date +%F) fallback (fixed fake date on PATH)"

# --- usage errors => exit 2 ---------------------------------------------------
run_promote_rc() {  # remaining args are passed through; prints exit code
  local rc=0
  bash "$PROMOTE" "$@" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}

L="$TMP/usage.md"
fresh_lessons "$L"

# Missing each required flag, one at a time.
declare -a full_flags=(--lessons "$L" --date 2099-06-03 --title t --category process \
  --applies-to engineer --status active --source n/a --rule r --why w --how-to-apply h)
for missing in --title --category --applies-to --status --source --rule --why --how-to-apply; do
  args=()
  skip_next=0
  for tok in "${full_flags[@]}"; do
    if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
    if [ "$tok" = "$missing" ]; then skip_next=1; continue; fi
    args+=("$tok")
  done
  [ "$(run_promote_rc "${args[@]}")" -eq 2 ] || fail "missing $missing must exit 2"
done
pass "each missing required flag exits 2"

[ "$(run_promote_rc --lessons "$L" --date bogus --title t --category process \
  --applies-to engineer --status active --source n/a --rule r --why w --how-to-apply h)" -eq 2 ] \
  || fail "invalid --date shape must exit 2"
pass "invalid --date shape exits 2"

# --- T-047 fast-follow AC1: --date must be a REAL Gregorian calendar date, ---
# not merely a 4/2/2-digit shape — `9999-99-99`-style values used to pass.
assert_bad_date() {  # $1 = description, $2 = --date value, $3 = expected stderr substring
  local desc="$1" datev="$2" pat="$3" err rc
  rc=0
  err="$(bash "$PROMOTE" --lessons "$L" --date "$datev" --title t --category process \
    --applies-to engineer --status active --source n/a --rule r --why w --how-to-apply h 2>&1)" || rc=$?
  [ "$rc" -eq 2 ] || fail "$desc: expected exit 2, got $rc (output: $err)"
  case "$err" in
    *"$pat"*) : ;;
    *) fail "$desc: expected stderr to mention '$pat', got: $err" ;;
  esac
  pass "T-047 AC1: $desc"
}
assert_bad_date "an invalid month (2026-13-01) is rejected" "2026-13-01" \
  "is not a valid Gregorian calendar date"
assert_bad_date "an invalid day-of-month (2026-04-31, April has 30 days) is rejected" "2026-04-31" \
  "is not a valid Gregorian calendar date"
assert_bad_date "Feb 29 on a non-leap year (2023-02-29) is rejected" "2023-02-29" \
  "is not a valid Gregorian calendar date"

# A genuine leap day must still pass (exit 0, entry appended).
L_LEAP="$TMP/valid-leap-day.md"
fresh_lessons "$L_LEAP"
rc=0
bash "$PROMOTE" --lessons "$L_LEAP" --date 2024-02-29 --title "leap day candidate" \
  --category process --applies-to engineer --status active --source n/a \
  --rule r --why w --how-to-apply h >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "T-047 AC1: a genuine leap day (2024-02-29) must still be accepted, got exit $rc"
grep -qF '## 2024-02-29 — leap day candidate' "$L_LEAP" || fail "T-047 AC1: leap-day entry was not appended"
pass "T-047 AC1: a genuine leap day (2024-02-29) continues to pass"

[ "$(run_promote_rc --lessons "$TMP/does-not-exist.md" --date 2099-06-03 --title t \
  --category process --applies-to engineer --status active --source n/a \
  --rule r --why w --how-to-apply h)" -eq 2 ] \
  || fail "missing --lessons file must exit 2"
pass "missing --lessons file exits 2"

[ "$(run_promote_rc --lessons "$L" --bogus-flag)" -eq 2 ] || fail "unknown flag must exit 2"
pass "unknown flag exits 2"

# --- embedded newline in a value => exit 2, lessons file untouched ----------
L="$TMP/newline.md"
fresh_lessons "$L"
before="$(cat "$L")"
rc=0
bash "$PROMOTE" --lessons "$L" --date 2099-06-04 --title t --category process \
  --applies-to engineer --status active --source n/a \
  --rule "$(printf 'line one\nline two')" --why w --how-to-apply h >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "an embedded newline in --rule must exit 2, got $rc"
after="$(cat "$L")"
[ "$before" = "$after" ] || fail "an embedded-newline rejection must leave the lessons file untouched"
pass "embedded newline in a flag value exits 2 and leaves the lessons file untouched"

# --- fail-closed re-validation: schema violations => exit 1, file untouched --
assert_rejected() {  # $1 = description, $2 = expected stderr substring, remaining = extra flags beyond the valid base
  local desc="$1" pat="$2"; shift 2
  local slug L2
  slug="$(printf '%s' "$desc" | tr -c 'a-zA-Z0-9' '-')"
  L2="$TMP/reject-$slug.md"
  fresh_lessons "$L2"
  local before after err rc
  before="$(cat "$L2")"
  rc=0
  err="$(bash "$PROMOTE" --lessons "$L2" --date 2099-06-05 --title "reject test" \
    --category process --applies-to engineer --status active --source n/a \
    --rule "Base rule." --why "Base why." --how-to-apply "Base how." "$@" 2>&1)" || rc=$?
  [ "$rc" -eq 1 ] || fail "$desc: expected exit 1, got $rc (output: $err)"
  case "$err" in
    *"$pat"*) : ;;
    *) fail "$desc: expected stderr to mention '$pat', got: $err" ;;
  esac
  after="$(cat "$L2")"
  [ "$before" = "$after" ] || fail "$desc: rejection must leave the lessons file byte-untouched"
  pass "AC4: $desc is rejected (exit 1) and the lessons file is left untouched"
}

assert_rejected "unknown Category value" "unknown Category value" --category not-a-real-category
assert_rejected "unknown Status value"   "unknown Status value"   --status not-a-real-status
assert_rejected "unknown Applies-to role token" "unknown Applies-to role token" --applies-to "engineer, scrum-master"
assert_rejected "control character in --why" "contains a control character" --why "$(printf 'bad\x0cchar')"
assert_rejected "marker-collision in --how-to-apply" "reserved marker string" \
  --how-to-apply "injected <!-- BEGIN prompt-block: evil --> text"

# --- T-108 AC14: `--status superseded` is rejected fail-closed -------------
# This script has no `--superseded-by` flag (Non-goals: automating retirement
# is out of scope for T-108), so a candidate appended with `--status
# superseded` can never carry the `Superseded-by` bullet bin/check-playbook.sh
# now REQUIRES on every superseded entry (AC1) — the fail-closed
# re-validation step below rejects it the same way any other schema
# violation is rejected: exit 1, tasks/lessons.md left byte-untouched.
assert_rejected "T-108 AC14: --status superseded (no Superseded-by flag exists to satisfy it)" \
  "Status is 'superseded' but Superseded-by is missing" --status superseded

# --- Fix 2 (T-045 rework, Major): --title gets the same control-char / -----
# marker-collision guard as every other field, checked directly by
# playbook-promote.sh itself (exit 2, before any temp file is even built) —
# not just indirectly via bin/check-playbook.sh's later re-validation.
L="$TMP/title-control-char.md"
fresh_lessons "$L"
before="$(cat "$L")"
rc=0
bash "$PROMOTE" --lessons "$L" --date 2099-06-06 --title "$(printf 'bad\x1ftitle')" \
  --category process --applies-to engineer --status active --source n/a \
  --rule r --why w --how-to-apply h >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "a control character (0x1F) in --title must exit 2, got $rc"
after="$(cat "$L")"
[ "$before" = "$after" ] || fail "a rejected --title must leave the lessons file untouched"
pass "Fix 2: a control character (0x1F) in --title exits 2 and leaves the lessons file untouched"

L="$TMP/title-marker-collision.md"
fresh_lessons "$L"
rc=0
bash "$PROMOTE" --lessons "$L" --date 2099-06-07 --title "injected <!-- BEGIN prompt-block: evil --> title" \
  --category process --applies-to engineer --status active --source n/a \
  --rule r --why w --how-to-apply h >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "a reserved marker string in --title must exit 2, got $rc"
pass "Fix 2: a reserved marker string in --title exits 2"

# --- Fix 1 (T-045 rework, Major): a --status with trailing/leading ----------
# whitespace is trimmed before it is ever written — never persisted verbatim.
L="$TMP/status-whitespace-write.md"
fresh_lessons "$L"
bash "$PROMOTE" --lessons "$L" --date 2099-06-08 --title "whitespace status" \
  --category process --applies-to engineer --status " active " --source n/a \
  --rule r --why w --how-to-apply h >/dev/null 2>&1
grep -qxF -- '- **Status**: active' "$L" || fail "Fix 1: --status ' active ' must be written trimmed, as 'active'"
# End-of-line anchored (not a bare substring grep): the fixture's own
# ## Format example legitimately contains "active " as a substring
# ("active | superseded"), so only a line ENDING in "active " (trailing
# space immediately before the newline) would indicate the bug.
if grep -qE -- '- \*\*Status\*\*: active $' "$L"; then
  fail "Fix 1: --status must never be persisted with verbatim trailing whitespace"
fi
bash "$CHECKER" "$L" >/dev/null 2>&1 || fail "Fix 1: resulting lessons file must still pass bin/check-playbook.sh"
pass "Fix 1: --status is trimmed before being written (no verbatim whitespace persisted)"

# --- Round2 Minor/NUL: a NUL byte lurking in the PRE-EXISTING lessons file --
# is still caught, even though this script has no NUL scan of its own (argv
# cannot carry one — see the script's header NOTE) — the fail-closed
# re-validation step re-checks the whole candidate file, which is built from
# the existing file's content plus the new (valid) entry. Spliced with
# head/tail (byte-transparent), not sed/awk, which would truncate at the NUL
# and defeat the fixture itself.
L="$TMP/nul-in-existing-file.md"
fresh_lessons "$L"
rule_line_no="$(grep -n -- '- \*\*Rule\*\*: Pre-existing rule\.' "$L" | head -1 | cut -d: -f1)"
{
  head -n "$((rule_line_no - 1))" "$L"
  printf -- '- **Rule**: before\x00after the NUL byte.\n'
  tail -n "+$((rule_line_no + 1))" "$L"
} > "$L.new"
mv "$L.new" "$L"
rc=0
err=""
err="$(bash "$PROMOTE" --lessons "$L" --date 2099-06-09 --title "valid candidate" \
  --category process --applies-to engineer --status active --source n/a \
  --rule "A perfectly valid new rule." --why w --how-to-apply h 2>&1)" || rc=$?
[ "$rc" -eq 1 ] || fail "a NUL byte in the pre-existing lessons file must still reject the promote call (exit 1), got $rc"
case "$err" in
  *"contains a NUL byte"*) : ;;
  *) fail "NUL-in-existing-file: expected reason in stderr, got: $err" ;;
esac
if grep -qF 'valid candidate' "$L"; then
  fail "a rejected promote call must not append anything, even when its OWN candidate content is valid"
fi
pass "Round2: a NUL byte in the pre-existing lessons file is still caught via the re-validation step, even for an otherwise-valid new candidate"

# --- Round3: an unclosed fence lurking in the PRE-EXISTING lessons file is ---
# likewise still caught (this script has no fence parser of its own — the
# re-validation step re-checks the whole candidate file, which is built from
# the existing file's content plus the new entry).
L="$TMP/unclosed-fence-in-existing-file.md"
fresh_lessons "$L"
printf '\n```markdown\nnever closed\n' >> "$L"
rc=0
err=""
err="$(bash "$PROMOTE" --lessons "$L" --date 2099-06-10 --title "valid candidate 2" \
  --category process --applies-to engineer --status active --source n/a \
  --rule "Another perfectly valid new rule." --why w --how-to-apply h 2>&1)" || rc=$?
[ "$rc" -eq 1 ] || fail "an unclosed fence in the pre-existing lessons file must still reject the promote call (exit 1), got $rc"
case "$err" in
  *"never closed"*) : ;;
  *) fail "unclosed-fence-in-existing-file: expected 'never closed' reason in stderr, got: $err" ;;
esac
if grep -qF 'valid candidate 2' "$L"; then
  fail "a rejected promote call must not append anything, even when its OWN candidate content is valid"
fi
pass "Round3: an unclosed fence in the pre-existing lessons file is still caught via the re-validation step, even for an otherwise-valid new candidate"


# --- AC8: shellcheck (soft-skip when unavailable) -----------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$PROMOTE" "$HERE/run.sh" || fail "AC8: scripts must be shellcheck clean"
  pass "AC8: shellcheck clean (promote script + test runner)"
else
  printf 'SKIP: AC8 shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll playbook-promote assertions passed.\n'
