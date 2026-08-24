#!/usr/bin/env bash
# run.sh — assert bin/check-entry-mode.sh (T-1096, issue #341) against the
# real script: the pre-freeze conformance-read gate over two independently
# written committed board sub-bullets.
#
# Exit: 0 = every assertion passed; non-zero = a FAIL line was printed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-entry-mode.sh"

if [ -n "${TMPDIR:-}" ]; then
  T="$(mktemp -d "${TMPDIR%/}/check-entry-mode-test.XXXXXX")"
else
  T="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

D1="- dispatch: specify — pm-authored — unconditional — recommendation: r"
D2="- dispatch: specify — operator-authored — conditional — cost-input: c"

# bd LINE... — a fixture board with one T-900 entry carrying each LINE as an
# indented sub-bullet, in the given order.
bd() {
  {
    printf '## Active\n\n- [ ] **T-900** fixture entry\n'
    for l in "$@"; do printf '  %s\n' "$l"; done
    printf '\n'
  } > "$T/board.md"
}

run() {
  bash "$SCRIPT" --board "$T/board.md" --task T-900 >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

invoke_rc() {
  "$@" >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

chk() {
  local desc="$1" expect="$2"
  [ "$(run)" = "$expect" ] || fail "$desc (expected $expect, got $(run); stderr: $(cat "$T/err"))"
  pass "$desc"
}

# --- baseline agreement ----------------------------------------------------
bd "- entry-mode: pm-authored" "$D1"
chk "both sources present and agreeing on pm-authored passes (positive control: the whole matrix below depends on this passing case existing)" 0

bd "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): decided z"
chk "both agreeing on operator-authored with every flagged gap resolved passes" 0

# --- source 1 (entry-mode) failure shapes ----------------------------------
bd "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y"
chk "an unresolved flagged gap refuses" 1

bd "$D1"
chk "source 1 (entry-mode) absent refuses — never a silent pass" 1

bd "$D1"
run >/dev/null || true
grep -qF -- 'entry-mode' "$T/err" || fail "source 1 absent: stderr must name the missing sub-bullet"
[ -s "$T/err" ] || fail "source 1 absent: stderr must be non-empty (the remedy)"
grep -qF -- 'remedy' "$T/err" || fail "source 1 absent: stderr must carry a remedy line"
pass "source 1 absent prints a one-line remedy naming the missing sub-bullet on stderr"

bd "- entry-mode: pm-authored" "- entry-mode: pm-authored" "$D1"
chk "a duplicated entry-mode sub-bullet refuses" 1

bd "- entry-mode: hybrid" "$D1"
chk "an entry-mode value outside the closed pair refuses" 1

# --- source 2 (dispatch: specify) failure shapes ---------------------------
bd "- entry-mode: pm-authored"
chk "source 2 (dispatch: specify) absent refuses" 1

bd "- entry-mode: pm-authored" "$D1" "- dispatch: specify — operator-authored — conditional — cost-input: c"
chk "a duplicated dispatch: specify sub-bullet refuses" 1

# --- mismatch, both directions ----------------------------------------------
bd "- entry-mode: pm-authored" "$D2"
chk "mismatch direction A (entry-mode pm-authored vs dispatch operator-authored) refuses (silent-skip direction)" 1

bd "- entry-mode: operator-authored" "$D1"
chk "mismatch direction B (entry-mode operator-authored vs dispatch pm-authored) refuses (wrong-branch direction)" 1

# --- order-independence, asserted as an equality between two orderings -----
run_pair() {
  local a_first="$1" a_second="$2"; shift 2
  bd "$a_first" "$a_second" "$@"; local a; a=$(run)
  bd "$a_second" "$a_first" "$@"; local b; b=$(run)
  [ "$a" = "$b" ] || fail "order-dependence detected: '$a_first' then '$a_second' gave $a, reversed gave $b"
  printf '%s' "$a"
}
[ "$(run_pair "- entry-mode: pm-authored" "$D1")" = "0" ] || fail "order-independence baseline should be 0"
run_pair "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): z" >/dev/null
run_pair "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y" >/dev/null
run_pair "- entry-mode: pm-authored" "$D2" >/dev/null
run_pair "- entry-mode: operator-authored" "$D1" >/dev/null
pass "the verdict is identical whichever order entry-mode/dispatch:specify were written in, across five board shapes"

# --- flagged-gap / flagged-gap-resolution id pairing -----------------------
E="- entry-mode: operator-authored"
mk() {
  {
    printf '## Active\n\n- [ ] **T-900** fixture entry\n  %s\n  %s\n' "$E" "$D2"
    for l in "$@"; do printf '  %s\n' "$l"; done
    printf '\n'
  } > "$T/board.md"
}

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): decided" "- flagged-gap (g2): p — q" "- flagged-gap-resolution (g2): decided"
chk "two gaps, both resolved, passes" 0

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): decided"
chk "one gap with a matching non-empty resolution passes" 0

mk "- flagged-gap (g1): x — y"
chk "a gap with no resolution refuses" 1

mk "- flagged-gap-resolution (g9): orphan"
chk "a resolution whose id matches no gap refuses (the drifted-id direction)" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1):"
chk "a resolution with nothing after the colon refuses" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1):   "
chk "a whitespace-only resolution text refuses (the suite's own exclusive case, not the inline check line)" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap (g2): p — q" "- flagged-gap-resolution (g1): decided"
chk "two gaps with only one resolved refuses" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap (g1): x2 — y2" "- flagged-gap-resolution (g1): decided"
chk "a duplicated gap id refuses" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): a" "- flagged-gap-resolution (g1): b"
chk "a duplicated resolution id refuses" 1

mk
chk "zero gaps and zero resolutions passes (the conformant nothing-to-answer case)" 0

mk "- flagged-gap (g1) : x — y"
chk "malformed marker near-miss: a stray space before the colon on the gap line refuses (not silently 'zero gaps')" 1

mk "- flagged-gap [g1]: x — y"
chk "malformed marker near-miss: a non-parenthesis delimiter on the gap line refuses" 1

mk "- flagged-gap: x — y"
chk "malformed marker near-miss: no id at all on the gap line refuses" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1) : z"
chk "malformed marker near-miss: a stray space before the colon on the RESOLUTION line refuses" 1

mk "- flagged-gap (g1): x — y" "- flagged-gap-resolution [g1]: z"
chk "malformed marker near-miss: a non-parenthesis delimiter on the RESOLUTION line refuses" 1

# --- the stem-ordering trap: `- flagged-gap` is a prefix of
# `- flagged-gap-resolution`, so the resolution stem must be tested first --
mk "- flagged-gap-resolution (g1): decided" "- flagged-gap (g1): x — y"
chk "stem-ordering trap: a well-formed resolution line followed by its matching gap line passes only if the longer resolution stem is tested first" 0

# --- bad invocation ----------------------------------------------------------
[ "$(invoke_rc bash "$SCRIPT" --board "$T/board.md")" = "2" ] || fail "missing --task must exit 2"
pass "missing --task exits 2"

[ "$(invoke_rc bash "$SCRIPT" --task T-900)" = "2" ] || fail "missing --board must exit 2"
pass "missing --board exits 2"

[ "$(invoke_rc bash "$SCRIPT" --board "$T/does-not-exist.md" --task T-900)" = "2" ] || fail "an unreadable board must exit 2"
pass "an unreadable --board value exits 2"

mk
[ "$(invoke_rc bash "$SCRIPT" --board "$T/board.md" --task T-999)" = "2" ] || fail "a task not present in ## Active must exit 2"
pass "a --task value not found as one top-level ## Active entry exits 2"

# --- comment-stripped flattened form carries the two shipped limits --------
fc() { sed 's/^[[:space:]]*#[[:space:]]*//' "$1" | tr '\n' ' ' | tr -s ' '; }
fc "$SCRIPT" > "$T/flat"
[ -s "$T/flat" ] || fail "the comment-stripped flattened form must be non-empty"
grep -qF -- 'never that the resolution is adequate' "$T/flat" || fail "the script must carry the 'never that the resolution is adequate' limit"
grep -qF -- 'the never-flagged case is undetectable' "$T/flat" || fail "the script must carry the 'the never-flagged case is undetectable' limit"
pass "the script's own bytes carry both disclosed limits verbatim"

printf '\nAll check-entry-mode assertions passed.\n'
