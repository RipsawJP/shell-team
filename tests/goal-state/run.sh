#!/usr/bin/env bash
# run.sh — drive bin/goal-state.sh and assert the /goal loop state behavior
# (T-034 acceptance criteria):
#   - init/iteration/bump persist the iteration counter across invocations
#   - elapsed-min derives floor((now - start)/60) (now via $GOAL_NOW for determinism)
#   - set-sig/prev-sig round-trip the previous failure signature
#   - signature normalizes to the SAME value for different prose with the same
#     failure shape (the no-progress property), and yields NO_VERDICT when no labels match
#   - corrupt/missing state -> exit 1; bad usage -> exit 2

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GS="$REPO_ROOT/bin/goal-state.sh"
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/goal-state-test.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$TMP"' EXIT

ST="$TMP/state"

# --- init / iteration / bump persistence ----------------------------------
GOAL_NOW=1000000000 bash "$GS" init "$ST"
[ "$(bash "$GS" iteration "$ST")" = "0" ] || fail "init: iteration should be 0"
[ "$(bash "$GS" bump "$ST")" = "1" ] || fail "bump: should return 1"
[ "$(bash "$GS" bump "$ST")" = "2" ] || fail "bump: should return 2"
[ "$(bash "$GS" iteration "$ST")" = "2" ] || fail "iteration: should persist as 2"
pass "init/iteration/bump persist the counter"

# --- elapsed-min ----------------------------------------------------------
[ "$(GOAL_NOW=1000000600 bash "$GS" elapsed-min "$ST")" = "10" ] || fail "elapsed-min: 600s should be 10 min"
[ "$(GOAL_NOW=1000000000 bash "$GS" elapsed-min "$ST")" = "0" ] || fail "elapsed-min: 0s should be 0 min"
[ "$(GOAL_NOW=1000000059 bash "$GS" elapsed-min "$ST")" = "0" ] || fail "elapsed-min: 59s should floor to 0"
# Clock skew (now < start) floors to 0, not a negative (which loop-guard would guard_error on).
[ "$(GOAL_NOW=999999000 bash "$GS" elapsed-min "$ST")" = "0" ] || fail "elapsed-min: negative skew should floor to 0"
# A non-integer GOAL_NOW is a state/usage error, not silent bad arithmetic.
set +e
GOAL_NOW=notanumber bash "$GS" elapsed-min "$ST" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 1 ] || fail "elapsed-min: non-integer GOAL_NOW should exit 1, got $rc"
pass "elapsed-min derives floor, clamps skew to 0, rejects non-int now"

# --- set-sig / prev-sig round-trip ----------------------------------------
[ -z "$(bash "$GS" prev-sig "$ST")" ] || fail "prev-sig: should start empty"
bash "$GS" set-sig "$ST" "FAIL;AC3"
[ "$(bash "$GS" prev-sig "$ST")" = "FAIL;AC3" ] || fail "set-sig/prev-sig round-trip"
# set-sig must not disturb the iteration counter.
[ "$(bash "$GS" iteration "$ST")" = "2" ] || fail "set-sig: iteration must be preserved"
pass "set-sig/prev-sig round-trip (iteration preserved)"

# --- signature normalization (the no-progress property) -------------------
s1="$(printf 'AC3: FAIL\nAC1: PASS\n30308 tokens at 2026-06-17T10:00:01Z\n' | bash "$GS" signature)"
s2="$(printf 'totally different prose — ac1 pass, AC3 fail, 9999 tokens, line 42\n' | bash "$GS" signature)"
[ "$s1" = "AC1;AC3;FAIL;PASS" ] || fail "signature: expected AC1;AC3;FAIL;PASS, got $s1"
[ "$s1" = "$s2" ] || fail "signature: same failure shape must normalize equal ($s1 vs $s2)"
pass "signature normalizes different prose with same shape to the same value"

# Verdict labels are captured and de-duped/sorted.
s3="$(printf 'REQUEST_CHANGES then APPROVE? no, REQUEST_CHANGES again\n' | bash "$GS" signature)"
[ "$s3" = "APPROVE;REQUEST_CHANGES" ] || fail "signature: expected APPROVE;REQUEST_CHANGES, got $s3"
pass "signature de-dupes and sorts verdict labels"

# No labels -> NO_VERDICT sentinel (must NOT be empty: an empty hash would
# silently bypass loop-guard's no_progress, which only compares non-empty hashes).
[ "$(printf 'no verdict labels in this text at all\n' | bash "$GS" signature)" = "NO_VERDICT" ] \
  || fail "signature: no labels should yield NO_VERDICT sentinel"
pass "signature yields NO_VERDICT sentinel when nothing matches"

# Word-boundary: incidental prose tokens must NOT be extracted (M-1). None of
# bypass/failure/approved/mac10 are whole-word verdict labels -> NO_VERDICT.
[ "$(printf 'this bypass did not cause a failure; the change was approved on mac10\n' | bash "$GS" signature)" = "NO_VERDICT" ] \
  || fail "signature: prose substrings (bypass/failure/approved/mac10) must not match"
pass "signature ignores prose substrings (whole-word only)"

# But real whole-word labels in the same line ARE captured (prose around them ignored).
[ "$(printf 'AC3: FAIL — the bypass attempt failed\n' | bash "$GS" signature)" = "AC3;FAIL" ] \
  || fail "signature: real labels captured, surrounding prose ignored"
pass "signature captures whole-word labels, ignores surrounding prose"

# --- corrupt / missing state -> exit 1 ------------------------------------
printf 'start_epoch=notanumber\niteration=0\nprev_sig=\n' > "$TMP/corrupt"
set +e
GOAL_NOW=1000000600 bash "$GS" elapsed-min "$TMP/corrupt" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 1 ] || fail "corrupt state: expected exit 1, got $rc"
set +e
bash "$GS" iteration "$TMP/does-not-exist" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 1 ] || fail "missing state: expected exit 1, got $rc"
pass "corrupt/missing state -> exit 1"

# --- usage errors -> exit 2 -----------------------------------------------
set +e
bash "$GS" >/dev/null 2>&1; rc=$?; [ "$rc" -eq 2 ] || fail "no subcommand: expected 2, got $rc"
bash "$GS" bogus >/dev/null 2>&1; rc=$?; [ "$rc" -eq 2 ] || fail "unknown subcommand: expected 2, got $rc"
bash "$GS" init >/dev/null 2>&1; rc=$?; [ "$rc" -eq 2 ] || fail "init w/o file: expected 2, got $rc"
bash "$GS" set-sig "$ST" >/dev/null 2>&1; rc=$?; [ "$rc" -eq 2 ] || fail "set-sig w/o value: expected 2, got $rc"
set -e
pass "usage errors -> exit 2"

# --- T-1021: leading-zero digit strings must not silently re-base ---------
# A leading-zero `iteration` value must be read as decimal, never as octal.
# `010` (valid octal, different value) proves re-basing; `07` would not
# (7 either way), which is why D7 forbids it as the fixture.
printf 'start_epoch=1000000000\niteration=010\nprev_sig=\n' > "$TMP/zero1"
[ "$(bash "$GS" bump "$TMP/zero1")" = "11" ] \
  || fail "T-1021-goal-state-bump: zero-fixture=010 iteration must bump to 11, not 9 (octal re-basing)"
pass "T-1021-goal-state-bump: leading-zero iteration bumps to 11 (zero-fixture=010)"

# `08` is invalid as an octal literal — bash's raw arithmetic error must
# never leak, and 10# normalization means it just bumps to 9 like any other
# valid decimal digit string (this is the crash-vs-refusal boundary D6 names).
printf 'start_epoch=1000000000\niteration=08\nprev_sig=\n' > "$TMP/zero2"
set +e
out2="$(bash "$GS" bump "$TMP/zero2" 2>"$TMP/zero2.err")"
rc2=$?
set -e
[ "$rc2" -eq 0 ] && [ "$out2" = "9" ] \
  || fail "T-1021-goal-state-bump-08: zero-fixture=08 iteration must bump to 9, got '$out2' (rc=$rc2)"
grep -q 'value too great for base' "$TMP/zero2.err" && fail "T-1021-goal-state-bump-08: zero-fixture=08 leaked bash's raw arithmetic error"
pass "T-1021-goal-state-bump-08: leading-zero iteration (zero-fixture=08) bumps to 9 with no raw arithmetic error"

# A leading-zero start_epoch must resolve elapsed-min to the real value, not
# an octal-derived one.
printf 'start_epoch=01000000000\niteration=0\nprev_sig=\n' > "$TMP/zero3"
[ "$(GOAL_NOW=1000000600 bash "$GS" elapsed-min "$TMP/zero3")" = "10" ] \
  || fail "T-1021-goal-state-elapsed-min: zero-fixture=010 start_epoch must yield 10, not an octal-derived value"
pass "T-1021-goal-state-elapsed-min: leading-zero start_epoch resolves to the real elapsed minutes (zero-fixture=010)"

# A 20-digit grammar-conformant iteration must refuse rather than silently
# wrap through INTMAX_MAX and print a negative value at exit 0 (D4 overflow
# decision, AC12).
printf 'start_epoch=1000000000\niteration=99999999999999999999\nprev_sig=\n' > "$TMP/huge"
set +e
bash "$GS" bump "$TMP/huge" >/dev/null 2>"$TMP/huge.err"
rc3=$?
set -e
[ "$rc3" -ne 0 ] \
  || fail "T-1021-goal-state-bump-overflow: a 20-digit iteration must refuse, not wrap and exit 0"
grep -q 'value too great for base' "$TMP/huge.err" && fail "T-1021-goal-state-bump-overflow: leaked bash's raw arithmetic error"
pass "T-1021-goal-state-bump-overflow: a 20-digit iteration refuses cleanly instead of wrapping"

printf '\nAll goal-state assertions passed.\n'
