#!/usr/bin/env bash
# loop-guard.sh — runtime BUDGET/STOP enforcement for a loop contract.
#
# Reads a loop contract's budget/stop sections plus the loop's current runtime
# state (passed as flags — telemetry T-015 will later feed the same flags) and
# prints ONE decision to stdout:
#
#     CONTINUE          the loop may run another iteration
#     STOP:<reason>     the loop must halt; <reason> is one of
#                       max_iterations_reached | budget_exhausted |
#                       no_progress | guard_error
#
# This is the runaway / billing kill-switch, so it is FAIL-CLOSED: if the
# contract cannot be read, or a required numeric budget cannot be parsed, it
# prints STOP:guard_error rather than letting an unbounded loop continue.
#
# Usage:
#   loop-guard.sh <contract.yaml> --iteration N [--elapsed-min M] [--usd U] \
#                 [--verdict-hash H] [--prev-verdict-hash P]
#
#   --iteration N          iterations COMPLETED so far (non-negative int, required)
#   --elapsed-min M        wall-clock minutes since loop start (non-negative int, default 0)
#   --usd U                cost so far in USD (best-effort; omit when untracked)
#   --verdict-hash H       hash/text of the latest iteration's verdict
#   --prev-verdict-hash P  hash/text of the previous iteration's verdict
#
# Enforcement model:
#   - Numeric budget caps are enforced whenever the contract value is > 0:
#       budget.max_iterations     -> STOP:max_iterations_reached  (ITERATION >= cap)
#       budget.max_wallclock_min  -> STOP:budget_exhausted        (ELAPSED_MIN >= cap)
#       budget.max_usd            -> STOP:budget_exhausted        (USD >= cap, best-effort)
#     A cap of 0 (or absent for usd) means UNTRACKED for that lever — it raises
#     no STOP. This matches the repo convention that `max_usd: 0` = untracked,
#     so iteration/wall-clock STOP still works when usd/token are null.
#   - no_progress is heuristic and OPT-IN: it fires only when the contract sets
#     `stop.no_progress: true` AND the current and previous verdict hashes are
#     both present and identical (a stuck loop).
#
# Exit: 0 = CONTINUE, 3 = STOP (terminal condition), 2 = STOP:guard_error
#       (could not evaluate — fail-closed). stdout always carries the decision.

set -euo pipefail

emit_stop() { printf 'STOP:%s\n' "$1"; exit 3; }

guard_error() {
  if [[ -n "${1:-}" ]]; then
    printf 'loop-guard: %s\n' "$1" >&2 || true
  fi
  printf 'STOP:guard_error\n'
  exit 2
}

# --- contract positional ---
CONTRACT="${1:-}"
if [[ -z "$CONTRACT" || "$CONTRACT" == --* ]]; then
  guard_error "missing <contract.yaml> as first argument"
fi
shift

# --- flags ---
ITERATION=""
ELAPSED_MIN="0"
USD=""
VERDICT=""
PREV_VERDICT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iteration|--elapsed-min|--usd|--verdict-hash|--prev-verdict-hash)
      [[ $# -ge 2 ]] || guard_error "missing value for $1"
      case "$1" in
        --iteration)         ITERATION="$2" ;;
        --elapsed-min)       ELAPSED_MIN="$2" ;;
        --usd)               USD="$2" ;;
        --verdict-hash)      VERDICT="$2" ;;
        --prev-verdict-hash) PREV_VERDICT="$2" ;;
      esac
      shift 2
      ;;
    *) guard_error "unknown argument: $1" ;;
  esac
done

# --- validate runtime state (fail-closed) ---
# Bound the integer width to <=9 digits so the value cannot overflow Bash's
# signed 64-bit arithmetic, wrap negative, and slip past a `>= cap` test.
[[ "$ITERATION"   =~ ^[0-9]{1,9}$ ]] || guard_error "missing or out-of-range --iteration: '${ITERATION}'"
[[ "$ELAPSED_MIN" =~ ^[0-9]{1,9}$ ]] || guard_error "missing or out-of-range --elapsed-min: '${ELAPSED_MIN}'"
# If --usd is supplied it MUST be a non-negative number; a malformed value must
# not silently disable billing enforcement.
if [[ -n "$USD" && ! "$USD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  guard_error "non-numeric --usd: '${USD}'"
fi
# The contract must be a regular, readable file — a directory passes -r but
# would crash awk under set -e without emitting a decision.
[[ -f "$CONTRACT" && -r "$CONTRACT" ]] || guard_error "cannot read contract file: $CONTRACT"

# Scalar value of `<section>.<key>` from the contract, or empty if absent.
# Single awk pass: a column-0 comment (`#...`) does NOT close the section, and
# inline `# comments` after the value are stripped. No `head`/early `exit`, so
# no SIGPIPE under `set -o pipefail`.
contract_value() {
  awk -v section="$1" -v k="$2" '
    $0 ~ "^" section ":" && !seen { seen=1; in_sec=1; next }
    in_sec && /^[^[:space:]#]/ { in_sec=0 }
    in_sec && !found && match($0, "^[[:space:]]*" k ":[[:space:]]*") {
      v = substr($0, RLENGTH + 1)
      sub(/[[:space:]]*#.*$/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v
      found = 1
    }
  ' "$CONTRACT"
}

# Read a contract value into <varname>, failing closed if the extraction itself
# errors (e.g. awk cannot read the file). A missing key yields an empty value,
# which the per-field validation below turns into the right STOP.
read_value() {
  local __v
  if ! __v="$(contract_value "$2" "$3")"; then
    guard_error "failed to parse contract section '$2'"
  fi
  printf -v "$1" '%s' "$__v"
}

read_value MAX_ITER    budget max_iterations
read_value MAX_WALL    budget max_wallclock_min
read_value MAX_USD     budget max_usd
read_value STOP_NOPROG stop   no_progress

# The two integer budget levers are required and must parse (fail-closed).
[[ "$MAX_ITER" =~ ^[0-9]{1,9}$ ]] || guard_error "budget.max_iterations missing/out-of-range: '${MAX_ITER}'"
[[ "$MAX_WALL" =~ ^[0-9]{1,9}$ ]] || guard_error "budget.max_wallclock_min missing/out-of-range: '${MAX_WALL}'"
# max_usd is best-effort: empty or 0 = untracked, a positive number enforces.
# A non-empty NON-numeric value is a corrupt contract — fail closed rather than
# silently disabling billing enforcement.
if [[ -n "$MAX_USD" && ! "$MAX_USD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  guard_error "budget.max_usd not numeric: '${MAX_USD}'"
fi

# 1. iteration cap (primary runaway guard)
if (( MAX_ITER > 0 )) && (( ITERATION >= MAX_ITER )); then
  emit_stop max_iterations_reached
fi

# 2. wall-clock budget
if (( MAX_WALL > 0 )) && (( ELAPSED_MIN >= MAX_WALL )); then
  emit_stop budget_exhausted
fi

# 3. usd budget (best-effort; floats compared via awk). Only when both the cap
#    and the observed usd are present and numeric — otherwise usd is untracked.
if [[ "$MAX_USD" =~ ^[0-9]+([.][0-9]+)?$ && -n "$USD" && "$USD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  if awk -v a="$USD" -v b="$MAX_USD" 'BEGIN { exit !(b > 0 && a >= b) }'; then
    emit_stop budget_exhausted
  fi
fi

# 4. no-progress (opt-in: contract stop.no_progress must be true)
if [[ "$STOP_NOPROG" == "true" && -n "$VERDICT" && "$VERDICT" == "$PREV_VERDICT" ]]; then
  emit_stop no_progress
fi

printf 'CONTINUE\n'
exit 0
