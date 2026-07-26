#!/usr/bin/env bash
# run.sh — drive bin/loop-guard.sh against fixtures and assert the documented
# decision contract (T-013 acceptance criteria):
#   - max_iterations exceeded            -> STOP:max_iterations_reached (exit 3)
#   - consecutive identical verdict      -> STOP:no_progress           (exit 3)
#   - wall-clock budget exceeded         -> STOP:budget_exhausted      (exit 3)
#   - usd budget exceeded (best-effort)  -> STOP:budget_exhausted      (exit 3)
#   - usd untracked but iteration over   -> STOP:max_iterations_reached (AC3)
#   - within all caps                    -> CONTINUE                   (exit 0)
#   - unreadable contract / bad input    -> STOP:guard_error           (exit 2, fail-closed)
#
# Asserts exact stdout AND exit code. Avoids mktemp so it runs in restricted
# sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/loop-guard.sh"
FIX="$HERE/fixtures"
GUARD="$FIX/guard-contract.yaml"
USDC="$FIX/usd-contract.yaml"
NOPROG_OFF="$FIX/noprog-off-contract.yaml"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# assert <desc> <expected_stdout> <expected_rc> -- <args to loop-guard.sh...>
assert() {
  local desc="$1" exp_out="$2" exp_rc="$3"
  shift 3
  [[ "${1:-}" == "--" ]] && shift
  local out rc
  set +e
  out="$(bash "$SCRIPT" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [[ "$out" == "$exp_out" ]] \
    || fail "$desc: stdout '$out' != expected '$exp_out'"
  [[ "$rc" -eq "$exp_rc" ]] \
    || fail "$desc: exit $rc != expected $exp_rc (stdout: $out)"
  printf 'PASS: %s (%s, exit %s)\n' "$desc" "$out" "$rc"
}

# CONTINUE under all caps
assert "within caps -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 1
assert "iteration just under cap -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 2

# AC1: iteration cap reached
assert "iteration == cap -> STOP:max_iterations_reached" "STOP:max_iterations_reached" 3 -- \
  "$GUARD" --iteration 3
assert "iteration over cap -> STOP:max_iterations_reached" "STOP:max_iterations_reached" 3 -- \
  "$GUARD" --iteration 9

# AC3: usd untracked (max_usd:0, no --usd) but iteration cap still fires
assert "usd untracked + iteration over -> STOP (AC3)" "STOP:max_iterations_reached" 3 -- \
  "$GUARD" --iteration 3

# AC2: no-progress (consecutive identical verdict), opt-in via stop.no_progress
assert "identical verdict -> STOP:no_progress" "STOP:no_progress" 3 -- \
  "$GUARD" --iteration 1 --verdict-hash abc123 --prev-verdict-hash abc123
assert "differing verdict -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 1 --verdict-hash abc123 --prev-verdict-hash zzz999
assert "first iteration (no prev verdict) -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 1 --verdict-hash abc123

# wall-clock budget
assert "wallclock at cap -> STOP:budget_exhausted" "STOP:budget_exhausted" 3 -- \
  "$GUARD" --iteration 1 --elapsed-min 30
assert "wallclock under cap -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 1 --elapsed-min 29

# usd budget (best-effort, floats)
assert "usd over cap -> STOP:budget_exhausted" "STOP:budget_exhausted" 3 -- \
  "$USDC" --iteration 1 --usd 6.50
assert "usd under cap -> CONTINUE" "CONTINUE" 0 -- \
  "$USDC" --iteration 1 --usd 1.25
assert "usd cap but usd untracked -> CONTINUE" "CONTINUE" 0 -- \
  "$USDC" --iteration 1

# fail-closed: unreadable contract / malformed input
assert "unreadable contract -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$FIX/does-not-exist.yaml" --iteration 1
assert "missing budget section -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$FIX/bad-contract.yaml" --iteration 1
assert "non-integer iteration -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$GUARD" --iteration not-a-number
assert "missing --iteration -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$GUARD" --elapsed-min 1
assert "missing contract arg -> STOP:guard_error" "STOP:guard_error" 2 -- \
  --iteration 1
assert "unknown flag -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$GUARD" --iteration 1 --bogus 5

# fail-closed: Codex review hardening (must STOP, never silently CONTINUE)
assert "oversized iteration (int overflow) -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$GUARD" --iteration 99999999999999999999
assert "malformed --usd -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$USDC" --iteration 1 --usd abc
assert "negative --usd -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$USDC" --iteration 1 --usd -1
assert "corrupt contract max_usd -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$FIX/badusd-contract.yaml" --iteration 1
assert "directory as contract -> STOP:guard_error" "STOP:guard_error" 2 -- \
  "$FIX"

# no_progress is opt-in: stop.no_progress:false must NOT stop on identical verdicts
assert "no_progress opt-out -> CONTINUE" "CONTINUE" 0 -- \
  "$NOPROG_OFF" --iteration 1 --verdict-hash dup --prev-verdict-hash dup
# iteration 0 (no cycles completed) is below any positive cap -> CONTINUE
assert "iteration 0 -> CONTINUE" "CONTINUE" 0 -- \
  "$GUARD" --iteration 0

printf 'OK\n'
exit 0
