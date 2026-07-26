#!/usr/bin/env bash
# run.sh — drive bin/check-acs.sh against fixture specs and assert the documented
# behavior (T-019 acceptance criteria):
#   - scriptable AC with a passing check: => PASS; runtime AC (no check:) => SKIP
#   - any failing check => exit 1, the AC reported FAIL
#   - a spec of only runtime ACs => exit 0 (all SKIP), never "unimplemented"
#   - an unreadable / AC-less spec => exit 2
#   - --dry-run lists commands WITHOUT executing them (the arbitrary-exec safety)
#
# Writes under $HERE/tmp (no mktemp) so it runs in restricted sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ACS="$REPO_ROOT/bin/check-acs.sh"
FIX="$HERE/fixtures"
TMP="$HERE/tmp"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

# assert_rc <desc> <expected_rc> <spec> [stdout_grep]
assert_rc() {
  local desc="$1" exp="$2" spec="$3" pat="${4:-}" out rc
  set +e
  out="$( bash "$ACS" "$spec" 2>&1 )"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (out: $out)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$out" || fail "$desc: stdout missing /$pat/ (out: $out)"
  pass "$desc (exit $rc)"
}

assert_rc "pass.md -> 0, AC1 PASS"          0 "$FIX/pass.md"          'AC1: PASS'
assert_rc "pass.md runtime AC -> SKIP"      0 "$FIX/pass.md"          'AC2: SKIP'
assert_rc "fail.md -> 1, AC2 FAIL"          1 "$FIX/fail.md"          'AC2: FAIL'
assert_rc "runtime-only.md -> 0 (all SKIP)" 0 "$FIX/runtime-only.md"  'AC2: SKIP'
assert_rc "no-ac.md -> 2"                   2 "$FIX/no-ac.md"
assert_rc "missing spec -> 2"               2 "$TMP/does-not-exist.md"

# --- T-088 (#286): hyphenated **AC-N** numbering is recognized --------------
assert_rc "hyphen-ac.md -> 0, AC1 PASS"     0 "$FIX/hyphen-ac.md"     'AC1: PASS'
assert_rc "hyphen-ac.md -> 0, AC2 SKIP"     0 "$FIX/hyphen-ac.md"     'AC2: SKIP'
out="$( bash "$ACS" "$FIX/hyphen-ac.md" 2>&1 )"
if grep -qF 'no acceptance criteria' <<< "$out"; then
  fail "hyphen-ac.md: must NOT print 'no acceptance criteria' — hyphenated **AC-N** must be recognized, got: $out"
fi
pass "hyphen-ac.md: hyphenated **AC-N** ACs are recognized, not treated as 'no acceptance criteria'"

# --- T-088 (#286) Codex round1 Major: a digit run glued to more alphanumerics
# (e.g. `**AC12abc**`) must NOT be recognized as an AC — the delimiter group in
# AC_RE rejects it. This fixture's only `**AC…**`-looking line is exactly that
# glued token (with a `check:` sub-bullet, so IF it were wrongly recognized it
# would try to run — proving the negative, not just an absence of any AC line).
rc=0
out="$( bash "$ACS" "$FIX/ac-alnum-suffix.md" 2>&1 )" || rc=$?
[ "$rc" -eq 2 ] || fail "ac-alnum-suffix.md: expected exit 2 (no acceptance criteria), got $rc (out: $out)"
grep -qF 'no acceptance criteria' <<< "$out" \
  || fail "ac-alnum-suffix.md: expected 'no acceptance criteria', got: $out"
pass "ac-alnum-suffix.md: a digit run glued to letters (**AC12abc**) is correctly NOT recognized as an AC"

# --- T-089 (#295) Codex T-088 round2 Minor: a digit run glued to more text by
# an ASCII word-continuation punctuation (`_` `:` `.` `-`) must NOT be
# recognized as an AC either — a narrower variant of the alnum-glued class
# above. This fixture's only `**AC…**`-looking lines are exactly those four
# glued forms (each with a `check: true` sub-bullet, so IF any were wrongly
# recognized it would try to run — proving the negative, not just an absence
# of any AC line).
rc=0
out="$( bash "$ACS" "$FIX/ac-punct-suffix.md" 2>&1 )" || rc=$?
[ "$rc" -eq 2 ] || fail "ac-punct-suffix.md: expected exit 2 (no acceptance criteria), got $rc (out: $out)"
grep -qF 'no acceptance criteria' <<< "$out" \
  || fail "ac-punct-suffix.md: expected 'no acceptance criteria', got: $out"
pass "ac-punct-suffix.md: digit runs glued by ASCII word-continuation punctuation (_:.-) are correctly NOT recognized as an AC"

# fail.md must name the failing AC in the summary line.
out="$( bash "$ACS" "$FIX/fail.md" 2>&1 || true )"
grep -qE 'FAILED:.*AC2' <<< "$out" || fail "fail.md: summary should list AC2 (out: $out)"
pass "fail.md summary lists the failing AC"

# --- --dry-run must NOT execute checks (arbitrary-exec safety, AC6) ----------
export ACS_SENTINEL="$TMP/sentinel"
rm -f "$ACS_SENTINEL"
bash "$ACS" --dry-run "$FIX/dryrun.md" >/dev/null 2>&1 || fail "dry-run: exited non-zero"
[ ! -e "$ACS_SENTINEL" ] || fail "dry-run: executed the check (sentinel created) — NOT a safe preview"
pass "--dry-run previews without executing any check"

# A real run DOES execute it (sentinel appears).
bash "$ACS" "$FIX/dryrun.md" >/dev/null 2>&1 || fail "run: exited non-zero on dryrun.md"
[ -e "$ACS_SENTINEL" ] || fail "run: check was not executed (sentinel missing)"
pass "a normal run executes the check (sentinel created)"

# --- parser edge cases ------------------------------------------------------
# Multiple check: under one AC — the FIRST wins (true), so the second (false)
# must be ignored => exit 0.
assert_rc "multi-check: first check: wins" 0 "$FIX/multi-check.md" 'AC1: PASS'
# An already-checked [x] AC is still parsed and run.
assert_rc "checked [x] AC is parsed"       0 "$FIX/checked.md"     'AC1: PASS'
# Stray check: lines (before any AC / after a heading) must not attach to an AC;
# the lone runtime AC stays SKIP and nothing fails => exit 0.
assert_rc "stray check: ignored, AC SKIP"  0 "$FIX/stray-check.md" 'AC1: SKIP'

# CRLF line endings parse the same (generate a \r\n copy of pass.md).
crlf="$TMP/pass-crlf.md"
sed 's/$/\r/' "$FIX/pass.md" > "$crlf"
assert_rc "CRLF spec parses (AC1 PASS)"    0 "$crlf"               'AC1: PASS'

# --- arg handling -----------------------------------------------------------
set +e
bash "$ACS" --bogus "$FIX/pass.md" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "unknown flag should exit 2, got $rc"
pass "unknown flag exits 2"

# --- check: runs from the CALLER cwd, not this script's repo (T-036 / #76) ---
# A spec whose check: tests a cwd-relative file proves where check: executes.
mkdir -p "$TMP/proj" "$TMP/empty"
PROBE="$TMP/proj/cwd-probe.md"
cat > "$PROBE" <<'SPEC'
# cwd probe spec
- [ ] **AC1** a cwd-relative file is visible to the check. *(scriptable)*
  - check: test -f target.txt
SPEC
: > "$TMP/proj/target.txt"   # exists only under proj/

run_in() { ( cd "$1" && shift && bash "$ACS" "$@" ); }   # run with a chosen cwd

set +e
run_in "$TMP/proj"  "$PROBE" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "cwd=proj (target.txt present) should PASS, got $rc"
pass "check: evaluates against the caller cwd (proj -> PASS)"

set +e
run_in "$TMP/empty" "$PROBE" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 1 ] || fail "cwd=empty (no target.txt) should FAIL, got $rc (old REPO_ROOT bug would not depend on cwd)"
pass "check: evaluates against the caller cwd (empty -> FAIL)"

# --root <dir> overrides the cwd.
set +e
run_in "$TMP/empty" --root "$TMP/proj" "$PROBE" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "--root proj from cwd=empty should PASS, got $rc"
pass "--root overrides the check cwd (empty + --root proj -> PASS)"

set +e
bash "$ACS" --root "$TMP/does-not-exist" "$PROBE" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "--root nonexistent dir should exit 2, got $rc"
pass "--root nonexistent dir -> exit 2"

set +e
bash "$ACS" --root >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "--root without value should exit 2, got $rc"
pass "--root without value -> exit 2"

set +e
bash "$ACS" --root "" "$PROBE" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "--root empty string should exit 2 (not silently fall back to cwd), got $rc"
pass "--root empty string -> exit 2"

# --- T-048 (#126): backtick-wrapped check: values are rejected fail-closed --
# Reproduces T-046 spec's rework1-before format (tasks/reviews/T-046.md
# round1 Major finding): an AC's check: value fully wrapped in a single
# outer backtick pair used to be run as bash command substitution, producing
# a false FAIL for a check whose successful branch prints to stdout. This
# fixture's underlying command genuinely PASSES when run raw (it echoes a
# confirmation message, matching bin/check-playbook.sh's real success
# output) — proving the rejection happens for the backtick-wrap itself, not
# because the underlying command is broken.
rc=0
out="$( bash "$ACS" "$FIX/backtick-wrapped.md" 2>&1 )" || rc=$?
[ "$rc" -eq 1 ] || fail "AC1 (T-048): a backtick-wrapped check: value must exit 1 (fail-closed), got $rc"
grep -qE 'AC1: FAIL.*backtick' <<< "$out" || fail "AC1 (T-048): expected a FAIL naming the backtick-wrap cause, got: $out"
if grep -qF 'command not found' <<< "$out"; then
  fail "AC1 (T-048): must never actually run the wrapped command as substitution (would produce 'command not found')"
fi
pass "T-048 AC1: a backtick-wrapped check: value is rejected fail-closed BEFORE ever being executed"

# --- T-048 rework1 (#126, tasks/reviews/T-048.md round1 Major): TRAILING ----
# whitespace (space or tab) after the closing backtick used to bypass the
# detection above — CHECK_RE's own `(.+)$` capture keeps trailing whitespace
# on $cmd verbatim, so `${cmd: -1}` used to land on the whitespace rather
# than the backtick, letting the value fall through to `bash -c` and
# reproduce the exact false-FAIL bug (exit 127, "command not found") this
# task exists to close. Fixtures are built dynamically here (not as static
# committed .md files) so the literal trailing space/tab byte survives
# untouched — a static fixture risks silent stripping by a future editor
# save / pre-commit hook. Each fixture's check: touches an env-var-named
# sentinel file — asserting the sentinel is NEVER created proves the inner
# command was truly never executed, not merely that it happened to also
# fail some other way.
export ACS_TRAILING_SENTINEL="$TMP/trailing-sentinel"

assert_trailing_bypass_fixed() {  # $1 = description, $2 = literal trailing whitespace char(s)
  local desc="$1" trailing="$2" spec out rc
  spec="$TMP/trailing-$(printf '%s' "$desc" | tr -c 'a-zA-Z0-9' '-').md"
  rm -f "$ACS_TRAILING_SENTINEL"
  {
    printf '# Fixture spec — trailing whitespace after a backtick-wrapped check:\n\n'
    printf '## Acceptance criteria\n\n'
    printf -- '- [ ] **AC1** %s *(scriptable)*\n' "$desc"
    # shellcheck disable=SC2016  # literal $ACS_TRAILING_SENTINEL text for the fixture file, not an expansion here
    printf '  - check: `touch "$ACS_TRAILING_SENTINEL"`%s\n' "$trailing"
  } > "$spec"
  rc=0
  out="$( bash "$ACS" "$spec" 2>&1 )" || rc=$?
  [ "$rc" -eq 1 ] || fail "$desc: expected exit 1 (fail-closed), got $rc (out: $out)"
  grep -qE 'AC1: FAIL.*backtick' <<< "$out" || fail "$desc: expected a FAIL naming the backtick-wrap cause, got: $out"
  if grep -qF 'command not found' <<< "$out"; then
    fail "$desc: bypassed — the wrapped command was run as substitution (would produce 'command not found')"
  fi
  [ ! -e "$ACS_TRAILING_SENTINEL" ] \
    || fail "$desc: the inner check: command's sentinel WAS created — it was executed, not rejected"
  pass "T-048 rework1: $desc"
}
assert_trailing_bypass_fixed "a trailing SPACE after the closing backtick is rejected, not executed" ' '
assert_trailing_bypass_fixed "a trailing TAB after the closing backtick is rejected, not executed" "$(printf '\t')"

# --- T-048 rework1 (Minor reconciliation): the reject message goes to -------
# STDERR specifically (AC1's literal spec wording), not merely combined
# 2>&1 output — verified with separated stdout/stderr streams.
STDOUT_ONLY="$TMP/backtick-stdout.txt"
STDERR_ONLY="$TMP/backtick-stderr.txt"
rc=0
bash "$ACS" "$FIX/backtick-wrapped.md" >"$STDOUT_ONLY" 2>"$STDERR_ONLY" || rc=$?
[ "$rc" -eq 1 ] || fail "backtick-wrapped.md: expected exit 1, got $rc"
grep -qE 'AC1: FAIL.*backtick' "$STDERR_ONLY" \
  || fail "the backtick-wrap FAIL message must be written to stderr (AC1's literal wording), got stderr: $(cat "$STDERR_ONLY")"
if grep -qE 'AC1: FAIL.*backtick' "$STDOUT_ONLY"; then
  fail "the backtick-wrap FAIL message must NOT also appear on stdout"
fi
pass "T-048 rework1: the backtick-wrap reject message is written to stderr, matching AC1's literal wording"

# --- T-048 (#126) AC4 regression: a check: value with a LEGITIMATE backtick -
# in the MIDDLE of an otherwise-unwrapped command (matching
# docs/specs/T-037-review-response.md's real shape) must NOT be rejected.
assert_rc "AC4 (T-048): a mid-command backtick is not rejected" 0 \
  "$FIX/backtick-middle.md" 'AC1: PASS'

# --- T-048 (#126) AC4: the real T-037-review-response.md spec (which has a --
# legitimate mid-command backtick in its own AC9 check:) must evaluate
# exactly as before this task — no false positive from the AC1 detection.
#
# T-048 rework2 (#126, CI failure on PR #129): this used to assert the
# WHOLE spec's overall exit code is 0. That baked in an environment-
# dependent condition unrelated to this task: T-037's AC11 check:
# (`git diff origin/main...HEAD -- .claude-plugin/plugin.json | grep -q
# '^+.*"version"'`) is a RELEASE-TIME gate requiring a version bump to show
# up in the diff against `origin/main`. On the engineer's local checkout
# `origin/main` happened to be stale (pointing at an old pre-v0.2.9 commit),
# so a later version bump coincidentally showed up in the diff and AC11
# PASSed by accident; on a CI fresh checkout `origin/main` is current and
# this branch never touches plugin.json, so AC11 correctly FAILs and the
# spec's overall exit code becomes 1 — a false regression report that has
# nothing to do with this task's backtick-wrap detection. The exit code of
# the WHOLE spec run must never be asserted here; only the two things this
# task's AC1 detection can actually break are checked directly:
#   (a) no backtick-wrap rejection message appears anywhere in the output
#       (the detection did not misfire on ANY of this spec's checks);
#   (b) AC9 (the check: line with a legitimate mid-command backtick) was
#       actually RUN, not rejected — "AC9: running:" appears in the output.

# --- T-050 (#132) AC1: an empty / whitespace-only check: value is rejected ---
# fail-closed, distinct from a genuinely-omitted check: (still SKIP).
rc=0
out="$( bash "$ACS" "$FIX/empty-check.md" 2>&1 )" || rc=$?
[ "$rc" -eq 1 ] || fail "empty-check.md: expected exit 1, got $rc (out: $out)"
grep -qE 'AC1: FAIL.*(empty|whitespace)' <<< "$out" \
  || fail "empty-check.md: AC1 (check: with nothing after it) should FAIL naming empty/whitespace, got: $out"
grep -qE 'AC2: SKIP' <<< "$out" \
  || fail "empty-check.md: AC2 (no check: sub-bullet at all) should stay SKIP, unaffected, got: $out"
pass "T-050 AC1: a check: line with nothing after it is rejected fail-closed; an omitted check: stays SKIP"

# Whitespace-only check: value (trailing spaces after `check:`). Built
# dynamically (not a static committed .md file) for the same reason the
# T-048 rework1 trailing-whitespace fixtures above are dynamic: a static
# fixture risks silent stripping of the literal trailing whitespace bytes by
# a future editor save / pre-commit hook.
ws_spec="$TMP/whitespace-check.md"
{
  printf '# Fixture spec — T-050 (#132): a whitespace-only check: value\n\n'
  printf '## Acceptance criteria\n\n'
  printf -- '- [ ] **AC1** a check: line present but with only whitespace after the colon *(scriptable)*\n'
  printf '  - check:    \n'
} > "$ws_spec"
rc=0
out="$( bash "$ACS" "$ws_spec" 2>&1 )" || rc=$?
[ "$rc" -eq 1 ] || fail "whitespace-check.md: expected exit 1, got $rc (out: $out)"
grep -qE 'AC1: FAIL.*(empty|whitespace)' <<< "$out" \
  || fail "whitespace-check.md: AC1 (check: with only whitespace after it) should FAIL naming empty/whitespace, got: $out"
pass "T-050 AC1: a check: line with only whitespace after it is rejected fail-closed (not silently exit-0 as cmd=\" \")"

# --- T-054 (#135) AC1: --dry-run must reflect the fail counter for ---------
# malformed check: values (empty/whitespace-only, backtick-wrapped). The
# detection for these already runs BEFORE the DRY_RUN branch in the main
# loop (it increments `fail` regardless of --dry-run); the summary used to
# ignore `fail` and exit 0 unconditionally under --dry-run, hiding a
# malformed spec behind a "safe preview" exit code. A well-formed spec and a
# runtime-only (all-SKIP) spec must still exit 0 — --dry-run stays a safe,
# non-executing preview for those (this task's Non-goal: no new detection
# logic, only the summary's exit reflecting the pre-existing fail counter).
rc=0
out="$( bash "$ACS" --dry-run "$FIX/empty-check.md" 2>&1 )" || rc=$?
[ "$rc" -ne 0 ] || fail "T-054 AC1: --dry-run on empty-check.md (malformed check:) must exit non-zero, got 0 (out: $out)"
grep -qE 'AC1: FAIL.*(empty|whitespace)' <<< "$out" \
  || fail "T-054 AC1: --dry-run on empty-check.md must still print the FAIL reason, got: $out"
grep -qE 'AC2: SKIP' <<< "$out" \
  || fail "T-054 AC4a: --dry-run on empty-check.md's omitted AC2 must stay SKIP (not malformed), got: $out"
pass "T-054 AC1: --dry-run on empty-check.md exits non-zero; AC4a: its omitted AC2 stays SKIP"

rc=0
out="$( bash "$ACS" --dry-run "$ws_spec" 2>&1 )" || rc=$?
[ "$rc" -ne 0 ] || fail "T-054 AC1: --dry-run on a whitespace-only check: value must exit non-zero, got 0 (out: $out)"
pass "T-054 AC1: --dry-run on a whitespace-only check: value exits non-zero"

rc=0
out="$( bash "$ACS" --dry-run "$FIX/backtick-wrapped.md" 2>&1 )" || rc=$?
[ "$rc" -ne 0 ] || fail "T-054 AC1: --dry-run on backtick-wrapped.md must exit non-zero, got 0 (out: $out)"
grep -qE 'AC1: FAIL.*backtick' <<< "$out" \
  || fail "T-054 AC1: --dry-run on backtick-wrapped.md must still print the backtick FAIL reason, got: $out"
pass "T-054 AC1: --dry-run on backtick-wrapped.md exits non-zero"

rc=0
out="$( bash "$ACS" --dry-run "$FIX/pass.md" 2>&1 )" || rc=$?
[ "$rc" -eq 0 ] || fail "T-054 AC1: --dry-run on well-formed pass.md must stay exit 0, got $rc (out: $out)"
pass "T-054 AC1: --dry-run on well-formed pass.md stays exit 0"

rc=0
out="$( bash "$ACS" --dry-run "$FIX/runtime-only.md" 2>&1 )" || rc=$?
[ "$rc" -eq 0 ] || fail "T-054 AC1: --dry-run on runtime-only.md (all SKIP) must stay exit 0, got $rc (out: $out)"
pass "T-054 AC1: --dry-run on runtime-only.md (all SKIP) stays exit 0"

# T-054 AC4b: a mid-command (non-wrapping) backtick must not be rejected under
# --dry-run either (matches the already-existing normal-mode assertion above).
rc=0
out="$( bash "$ACS" --dry-run "$FIX/backtick-middle.md" 2>&1 )" || rc=$?
[ "$rc" -eq 0 ] || fail "T-054 AC4b: --dry-run on backtick-middle.md (mid-command backtick, not wrapped) must stay exit 0, got $rc (out: $out)"
pass "T-054 AC4b: --dry-run on backtick-middle.md (mid-command backtick, not wrapped) stays exit 0"


# --- T-110: unrecognized AC label lines are fail-closed, not silently -------
# dropped. See tests/check-acs/fixtures/ac-unrecognized-label.md: AC1 (well-
# formed, check: true) / AC2 (well-formed runtime, no check:) / AC19b (digit
# glued to letters) / AC1_foo (digit glued by punctuation), in that order —
# AC19b sits directly after AC2 so DP-6's misattribution regression (a
# check: under an unrecognized line being absorbed by the PRECEDING
# recognized AC) has something real to attach to.
UNREC="$FIX/ac-unrecognized-label.md"

rc=0
out="$( bash "$ACS" "$UNREC" 2>&1 )" || rc=$?
[ "$rc" -eq 2 ] || fail "T-110: ac-unrecognized-label.md expected exit 2, got $rc (out: $out)"
grep -qF 'unrecognized AC label at' <<< "$out" || fail "T-110: expected an 'unrecognized AC label at' diagnostic, got: $out"
pass "T-110: an unrecognized AC label line makes normal-mode exit 2 (not 1, not silently ignored)"

rc=0
out="$( bash "$ACS" --dry-run "$UNREC" 2>&1 )" || rc=$?
[ "$rc" -eq 2 ] || fail "T-110: --dry-run on ac-unrecognized-label.md expected exit 2, got $rc (out: $out)"
grep -qF 'unrecognized AC label at' <<< "$out" || fail "T-110: --dry-run expected an 'unrecognized AC label at' diagnostic, got: $out"
grep -qF '2 unrecognized' <<< "$out" || fail "T-110: --dry-run summary should report '2 unrecognized', got: $out"
pass "T-110: --dry-run also exits 2 and reports the unrecognized count (dry-run does not hide it)"

STDOUT_ONLY="$TMP/t110-stdout.txt"
STDERR_ONLY="$TMP/t110-stderr.txt"
rc=0
bash "$ACS" "$UNREC" >"$STDOUT_ONLY" 2>"$STDERR_ONLY" || rc=$?
grep -qF 'unrecognized AC label at' "$STDERR_ONLY" \
  || fail "T-110: the unrecognized-label diagnostic must be on stderr, got stderr: $(cat "$STDERR_ONLY")"
if grep -qF 'unrecognized AC label at' "$STDOUT_ONLY"; then
  fail "T-110: the unrecognized-label diagnostic must NOT also appear on stdout"
fi
if ! grep -qF '**ACn**' "$STDERR_ONLY" || ! grep -qF '**AC-N**' "$STDERR_ONLY"; then
  fail "T-110: the diagnostic must name both canonical forms **ACn** and **AC-N**, got: $(cat "$STDERR_ONLY")"
fi
grep -qF '1 passed, 0 failed, 1 skipped, 2 unrecognized' "$STDOUT_ONLY" \
  || fail "T-110: normal-mode summary should report 'unrecognized' as a 4th counter, got: $(cat "$STDOUT_ONLY")"
pass "T-110: diagnostic is stderr-only, names both canonical label forms, and the summary carries a 4th 'unrecognized' counter"

grep -qE 'AC2: SKIP' "$STDOUT_ONLY" \
  || fail "T-110 (DP-6): AC2 (a runtime AC with no check:, immediately preceding the unrecognized AC19b line) must stay SKIP, not absorb AC19b's check:, got: $(cat "$STDOUT_ONLY")"
pass "T-110 (DP-6): the unrecognized AC19b line does not get its check: misattributed to the preceding AC2"

# T-110-unrecognized-not-executed: positive PROOF (not just an absence-of-
# error inference) that neither AC19b's nor AC1_foo's `- check: touch
# "$T110_UNRECOGNIZED_SENTINEL"` sub-bullet was ever actually run — both
# unrecognized lines in the fixture share the same sentinel var, so either
# one firing would create the file.
export T110_UNRECOGNIZED_SENTINEL="$TMP/t110-unrecognized-sentinel"
rm -f "$T110_UNRECOGNIZED_SENTINEL"
bash "$ACS" "$UNREC" >/dev/null 2>&1 || true
[ ! -e "$T110_UNRECOGNIZED_SENTINEL" ] \
  || fail "T-110-unrecognized-not-executed: the sentinel WAS created — an unrecognized label's check: was executed, not rejected"
pass "T-110-unrecognized-not-executed: neither AC19b's nor AC1_foo's check: sentinel was created — their check: commands were never run"

# T-110-recognized-executed-control: positive control proving the SAME
# sentinel-file mechanism used above genuinely discriminates "executed" from
# "not executed" — a well-formed AC's check: DOES fire, so the negative
# result above is non-vacuous (it is not merely that this touch-based
# sentinel technique never works in this harness).
export T110_RECOGNIZED_SENTINEL="$TMP/t110-recognized-sentinel"
rm -f "$T110_RECOGNIZED_SENTINEL"
control_spec="$TMP/t110-recognized-control.md"
{
  printf '# Fixture — positive control for T-110s sentinel-based non-execution proof\n\n'
  printf '## Acceptance criteria\n\n'
  printf -- '- [ ] **AC1** a well-formed scriptable AC whose check: touches a sentinel *(scriptable)*\n'
  # shellcheck disable=SC2016  # literal $T110_RECOGNIZED_SENTINEL text for the fixture file, not an expansion here.
  printf '  - check: touch "$T110_RECOGNIZED_SENTINEL"\n'
} > "$control_spec"
bash "$ACS" "$control_spec" >/dev/null 2>&1 || fail "T-110-recognized-executed-control: the control spec's normal run should exit 0"
[ -e "$T110_RECOGNIZED_SENTINEL" ] \
  || fail "T-110-recognized-executed-control: a well-formed AC's check: should have created its sentinel — the touch-based non-execution proof above would be vacuous otherwise"
pass "T-110-recognized-executed-control: a well-formed AC's check: does create its sentinel, proving the sentinel mechanism is non-vacuous"

printf '\nAll check-acs assertions passed.\n'
