#!/usr/bin/env bash
# goal-state.sh — per-run state helper for the /goal self-verification loop.
#
# A self-paced /goal loop spans multiple ticks (separate Bash invocations), and
# env vars do NOT persist across them (T-026). So the loop's cross-tick state —
# the loop start time, the iteration counter, and the previous tick's failure
# signature — lives in a small state file under the runs dir (gitignored). This
# helper reads/writes that file and derives the values loop-guard.sh needs
# (`--elapsed-min`, `--iteration`, `--prev-verdict-hash`), plus the normalized
# failure signature used for no-progress detection.
#
# The state file is plain `key=value` lines: start_epoch, iteration, prev_sig.
#
# Subcommands:
#   init <statefile>            create/reset: start_epoch=now, iteration=0, prev_sig=
#   elapsed-min <statefile>     print floor((now - start_epoch) / 60)
#   iteration <statefile>       print the current iteration counter
#   bump <statefile>            iteration += 1; persist; print the new value
#   prev-sig <statefile>        print the stored previous failure signature (may be empty)
#   set-sig <statefile> <sig>   store <sig> as the previous failure signature
#   signature                   read verdict text on stdin; print a NORMALIZED
#                               failure signature (verdict labels + AC ids only,
#                               upper-cased, de-duped, sorted, ';'-joined) so
#                               volatile prose (timestamps, token counts, line
#                               numbers) does not change it. This is what gets
#                               hashed for no_progress — two ticks with the same
#                               failure shape produce the same signature.
#
# `now` is `date +%s`, overridable with $GOAL_NOW for deterministic tests.
# Pure bash + coreutils (grep/sed/sort/tr) — no jq/yq/python.
#
# Usage:  goal-state.sh <subcommand> [args...]
# Exit:   0 = ok, 1 = state error (missing/garbled state file), 2 = usage error.

set -euo pipefail

now() { printf '%s\n' "${GOAL_NOW:-$(date +%s)}"; }

usage() {
  printf 'usage: goal-state.sh <init|elapsed-min|iteration|bump|prev-sig|set-sig|signature> [args]\n' >&2 || true
  exit 2
}

# read_key <statefile> <key> — print the value of key=… (empty string if absent).
# Single-pass awk (first match wins, then exit) avoids a `| head` SIGPIPE under
# `set -o pipefail`.
read_key() {
  local f="$1" k="$2"
  [[ -r "$f" ]] || { printf '%s: cannot read goal state file\n' "$f" >&2 || true; exit 1; }
  awk -F= -v k="$k" '$1==k { sub(/^[^=]*=/, ""); print; exit }' "$f"
}

# write_state <statefile> <start_epoch> <iteration> <prev_sig>
write_state() {
  local f="$1"
  printf 'start_epoch=%s\niteration=%s\nprev_sig=%s\n' "$2" "$3" "$4" > "$f"
}

require_int() {
  local re="${3:-^[0-9]+$}"
  [[ "$1" =~ $re ]] || { printf 'goal-state.sh: corrupt state (%s is not an integer: %q)\n' "$2" "$1" >&2 || true; exit 1; }
}

# T-1021 (D4): width bounds for the two quantities this script feeds into
# arithmetic. ITER_RE mirrors bin/loop-guard.sh:88's bound on the same
# quantity arriving as --iteration, so the two ends of one pipe agree.
# EPOCH_RE is {1,11} rather than {1,9}: a Unix epoch is already 10 digits
# and will be 11 from the year 2286, so a {1,9} bound would reject a real
# start_epoch/now value this script itself writes.
ITER_RE='^[0-9]{1,9}$'
EPOCH_RE='^[0-9]{1,11}$'

[[ "$#" -ge 1 ]] || usage
cmd="$1"; shift

case "$cmd" in
  init)
    [[ "$#" -eq 1 ]] || usage
    write_state "$1" "$(now)" 0 ""
    ;;
  elapsed-min)
    [[ "$#" -eq 1 ]] || usage
    start="$(read_key "$1" start_epoch)"; require_int "$start" start_epoch "$EPOCH_RE"
    n="$(now)"; require_int "$n" now "$EPOCH_RE"
    # T-1021: normalize once, immediately after the width bound proves the
    # value is a bounded digit string, so a leading-zero epoch (`01000000000`)
    # is read as decimal rather than re-based as octal by the subtraction.
    start=$((10#$start)); n=$((10#$n))
    delta=$(( n - start ))
    (( delta < 0 )) && delta=0   # floor clock-skew to 0 rather than emit a negative (loop-guard would guard_error)
    printf '%s\n' "$(( delta / 60 ))"
    ;;
  iteration)
    [[ "$#" -eq 1 ]] || usage
    it="$(read_key "$1" iteration)"; require_int "$it" iteration
    printf '%s\n' "$it"
    ;;
  bump)
    [[ "$#" -eq 1 ]] || usage
    start="$(read_key "$1" start_epoch)"; require_int "$start" start_epoch "$EPOCH_RE"
    it="$(read_key "$1" iteration)"; require_int "$it" iteration "$ITER_RE"
    sig="$(read_key "$1" prev_sig)"
    # T-1021: normalize once, immediately after the width bound, then use the
    # normalized local for the increment (10#$it, not $it) — the leading-zero
    # hole this closes: `iteration=010` incrementing to `9` instead of `11`.
    start=$((10#$start)); it=$((10#$it))
    it=$(( it + 1 ))
    write_state "$1" "$start" "$it" "$sig"
    printf '%s\n' "$it"
    ;;
  prev-sig)
    [[ "$#" -eq 1 ]] || usage
    read_key "$1" prev_sig
    ;;
  set-sig)
    [[ "$#" -eq 2 ]] || usage
    start="$(read_key "$1" start_epoch)"; require_int "$start" start_epoch
    it="$(read_key "$1" iteration)"; require_int "$it" iteration
    write_state "$1" "$start" "$it" "$2"
    ;;
  signature)
    [[ "$#" -eq 0 ]] || usage
    # Keep only the stable failure shape: verdict labels + AC ids. `-w` (whole
    # word) is essential — without it "bypass"->PASS, "failure"->FAIL,
    # "approved"->APPROVE, "mac10"->AC10 would poison the signature. Upper-case,
    # de-dupe, sort, join with ';'. Volatile prose contributes nothing. `|| true`
    # so "no tokens matched" is not a pipefail error.
    sig="$(LC_ALL=C grep -owiE 'REQUEST_CHANGES|APPROVE|PASS|FAIL|AC[0-9]+' \
      | tr '[:lower:]' '[:upper:]' \
      | LC_ALL=C sort -u \
      | tr '\n' ';' \
      | sed 's/;$//' || true)"
    # An empty signature (no recognizable verdict tokens) must NOT silently bypass
    # no_progress: loop-guard only compares non-empty verdict hashes. Emit a
    # sentinel so two content-less ticks compare equal and trip STOP:no_progress.
    printf '%s\n' "${sig:-NO_VERDICT}"
    ;;
  *)
    usage
    ;;
esac
