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
TMP="$HERE/tmp"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"; mkdir -p "$TMP"
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

printf '\nAll goal-state assertions passed.\n'
