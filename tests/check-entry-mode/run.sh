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

# --- T-1096 rework round 1, Blocker 2: a doubled space after the bullet
# --- dash on EITHER stem (a reachable ## Input space class) must be
# --- COLLECTED and then REFUSED as malformed — never silently invisible,
# --- which would let a genuinely flagged, genuinely unresolved gap read
# --- as the conformant zero-gaps case (the dangerous direction). --------
mk "-  flagged-gap (g1): x — y"
chk "doubled-space-after-bullet on the GAP stem: a genuinely unresolved gap in this shape refuses, never silently reads as zero-gaps" 1

mk "- flagged-gap (g1): x — y" "-  flagged-gap-resolution (g1): decided"
chk "doubled-space-after-bullet on the RESOLUTION stem: collected then refused as malformed, never silently invisible" 1

mk "-  flagged-gap (g1): x — y" "-  flagged-gap-resolution (g1): decided"
chk "doubled-space-after-bullet on BOTH stems at once: still refuses (never a false pass via mutual invisibility)" 1

# --- T-1096 rework round 1, Major 2: whitespace variants on the
# --- `- entry-mode:` / `- dispatch: specify` stems must be diagnosed as
# --- malformed (found, wrong shape) rather than misreported as absent or
# --- as an out-of-vocabulary value — still fail closed either way. -------
mk_pair() {
  # a two-line board entry with exactly the given entry-mode and
  # dispatch:specify sub-bullets (no gap markers).
  local em="$1" d="$2"
  { printf '## Active\n\n- [ ] **T-900** fixture entry\n  %s\n  %s\n\n' "$em" "$d"; } > "$T/board.md"
}

mk_pair "-  entry-mode: pm-authored" "$D1"
chk "doubled-space-after-bullet on entry-mode's OWN stem still refuses" 1
run >/dev/null || true
grep -qF -- 'malformed' "$T/err" || fail "entry-mode doubled-space variant: stderr must say malformed, not absent"
grep -qF -- 'source 1 absent' "$T/err" && fail "entry-mode doubled-space variant: stderr must NOT claim absence when a variant stem was actually found"
pass "entry-mode doubled-space variant: stderr names it malformed rather than absent"

mk_pair "- entry-mode: pm-authored" "-  dispatch: specify — pm-authored — unconditional — recommendation: r"
chk "doubled-space-after-bullet on dispatch:specify's OWN stem still refuses" 1
run >/dev/null || true
grep -qF -- 'malformed' "$T/err" || fail "dispatch doubled-space variant: stderr must say malformed, not absent"
grep -qF -- 'source 2 absent' "$T/err" && fail "dispatch doubled-space variant: stderr must NOT claim absence when a variant stem was actually found"
pass "dispatch:specify doubled-space-after-bullet variant: stderr names it malformed rather than absent"

mk_pair "- entry-mode: pm-authored" "- dispatch: specify —  pm-authored — unconditional — recommendation: r"
chk "doubled-space INSIDE the dispatch record's own em-dash separator (before the value) still refuses" 1
run >/dev/null || true
grep -qF -- 'could not be parsed' "$T/err" || fail "dispatch separator-doubling: stderr must say the value field could not be parsed"
grep -qF -- 'outside the closed pair' "$T/err" && fail "dispatch separator-doubling: stderr must NOT claim the value is out-of-vocabulary (it never parsed at all)"
pass "dispatch:specify separator-doubling variant: stderr names an unparseable value field rather than an out-of-vocabulary one"

# --- T-1096 rework round 1, Major 3: a CRLF-terminated board must not be
# --- refused for an otherwise-conformant entry. --------------------------
{
  printf '## Active\r\n\r\n- [ ] **T-900** fixture entry\r\n  %s\r\n  %s\r\n\r\n' "- entry-mode: operator-authored" "$D2"
} > "$T/board.md"
chk "a CRLF-terminated board with an otherwise-conformant entry (no gaps) passes" 0

{
  printf '## Active\r\n\r\n- [ ] **T-900** fixture entry\r\n  %s\r\n  %s\r\n  %s\r\n  %s\r\n\r\n' \
    "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y" "- flagged-gap-resolution (g1): decided"
} > "$T/board.md"
chk "a CRLF-terminated board with a resolved flagged gap passes" 0

{
  printf '## Active\r\n\r\n- [ ] **T-900** fixture entry\r\n  %s\r\n  %s\r\n  %s\r\n\r\n' \
    "- entry-mode: operator-authored" "$D2" "- flagged-gap (g1): x — y"
} > "$T/board.md"
chk "a CRLF-terminated board with a genuinely unresolved flagged gap still refuses (CRLF tolerance is not a new false-pass surface)" 1

# --- mutation discipline: deletion + inversion probes against the REAL
# --- script, run in a scratch copy, restored/discarded immediately after.
# --- Each probe reproduces the exact fixture shape above and confirms the
# --- MUTATED copy gets the WRONG answer where the real script gets the
# --- right one, so this suite's own dependency on the fix is demonstrated
# --- rather than assumed. -------------------------------------------------
MUT="$T/mutated-check-entry-mode.sh"

# Deletion probe: revert the widened gap/resolution stem net back to its
# pre-fix, exactly-one-space form and confirm the doubled-space-gap fixture
# (a genuinely unresolved gap) WRONGLY exits 0 under the reverted copy.
sed -E "s/gap_stem_re='\\^\\[\\[:space:\\]\\]\\*-\\[\\[:space:\\]\\]\\+flagged-gap'/gap_stem_re='^[[:space:]]*- flagged-gap'/" "$SCRIPT" \
  | sed -E "s/res_stem_re='\\^\\[\\[:space:\\]\\]\\*-\\[\\[:space:\\]\\]\\+flagged-gap-resolution'/res_stem_re='^[[:space:]]*- flagged-gap-resolution'/" \
  > "$MUT"
grep -qxF "gap_stem_re='^[[:space:]]*- flagged-gap'" "$MUT" || fail "deletion probe: mutation did not apply — the sed pattern no longer matches the real script's current text"
mk "-  flagged-gap (g1): x — y"
mut_rc="$(bash "$MUT" --board "$T/board.md" --task T-900 >/dev/null 2>&1; printf '%s' "$?")"
[ "$mut_rc" = "0" ] || fail "deletion probe: expected the reverted (pre-fix) script to WRONGLY pass the doubled-space-unresolved-gap fixture (got $mut_rc, real script gets 1) — the probe itself may be broken"
pass "mutation (deletion): reverting the stem widening makes the doubled-space-unresolved-gap fixture wrongly pass — confirms this suite depends on the fix"

# Inversion probe: swap the gap-before-resolution testing PRIORITY — the
# `if`/`elif` block order in the real script, bodies untouched — the
# opposite of Notes for engineer's "resolution stem tested first" rule, and
# confirm the stem-ordering-trap fixture (a resolution line immediately
# followed by its matching gap line) no longer passes. Done as a precise
# block swap (python3, only ever used here to shuffle two already-known
# text blocks byte-for-byte — never to re-derive script logic) rather than
# a line-based sed, since a naive line substitution cannot safely relocate
# a multi-line if/elif block without risking a mutation that silently
# tests nothing.
python3 - "$SCRIPT" "$MUT" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
if_block = '''  if [[ "$line" =~ $res_stem_re ]]; then
    if [[ "$line" =~ $res_full_re ]]; then
      rid="${BASH_REMATCH[1]}"
      rtext="${BASH_REMATCH[2]}"
      trimmed="$(printf '%s' "$rtext" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$trimmed" ] || fail "$TASK has a \\`- flagged-gap-resolution ($rid):\\` sub-bullet with empty resolution text: $line"
      case "$RES_IDS" in
        *" $rid "*) fail "$TASK has a duplicated \\`- flagged-gap-resolution\\` id '$rid'" ;;
      esac
      RES_IDS="${RES_IDS}${rid} "
    else
      fail "$TASK has a malformed \\`- flagged-gap-resolution\\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  elif [[ "$line" =~ $gap_stem_re ]]; then
    if [[ "$line" =~ $gap_full_re ]]; then
      gid="${BASH_REMATCH[1]}"
      case "$GAP_IDS" in
        *" $gid "*) fail "$TASK has a duplicated \\`- flagged-gap\\` id '$gid'" ;;
      esac
      GAP_IDS="${GAP_IDS}${gid} "
    else
      fail "$TASK has a malformed \\`- flagged-gap\\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  fi'''
assert if_block in text, "inversion probe: the known if/elif block text no longer matches the real script verbatim — update the probe's copy"
swapped = '''  if [[ "$line" =~ $gap_stem_re ]]; then
    if [[ "$line" =~ $gap_full_re ]]; then
      gid="${BASH_REMATCH[1]}"
      case "$GAP_IDS" in
        *" $gid "*) fail "$TASK has a duplicated \\`- flagged-gap\\` id '$gid'" ;;
      esac
      GAP_IDS="${GAP_IDS}${gid} "
    else
      fail "$TASK has a malformed \\`- flagged-gap\\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  elif [[ "$line" =~ $res_stem_re ]]; then
    if [[ "$line" =~ $res_full_re ]]; then
      rid="${BASH_REMATCH[1]}"
      rtext="${BASH_REMATCH[2]}"
      trimmed="$(printf '%s' "$rtext" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$trimmed" ] || fail "$TASK has a \\`- flagged-gap-resolution ($rid):\\` sub-bullet with empty resolution text: $line"
      case "$RES_IDS" in
        *" $rid "*) fail "$TASK has a duplicated \\`- flagged-gap-resolution\\` id '$rid'" ;;
      esac
      RES_IDS="${RES_IDS}${rid} "
    else
      fail "$TASK has a malformed \\`- flagged-gap-resolution\\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  fi'''
open(dst, 'w').write(text.replace(if_block, swapped, 1))
PYEOF
[ -s "$MUT" ] || fail "inversion probe: mutated copy was not written"
mk "- flagged-gap-resolution (g1): decided" "- flagged-gap (g1): x — y"
mut_rc="$(bash "$MUT" --board "$T/board.md" --task T-900 >/dev/null 2>&1; printf '%s' "$?")"
[ "$mut_rc" != "0" ] || fail "inversion probe: expected the stem-priority-inverted script to WRONGLY fail the stem-ordering-trap fixture (got 0, same as the real script) — the probe itself may be broken"
pass "mutation (inversion): testing the gap stem before the resolution stem breaks the stem-ordering-trap fixture — confirms this suite depends on resolution-tested-first"

rm -f "$MUT"

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

# --- dispatch-reflection duty A/B (T-1109, issue #365) ---------------------
# T-901 is the entry under test; T-900 is its predecessor, placed in
# whichever section the case needs — this directly exercises ## Assumptions
# row A-8 ("a SECOND scan, never a widening of the --task entry's own
# ## Active-only resolution above").
run901() {
  bash "$SCRIPT" --board "$T/refl.md" --task T-901 >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}
chk901() {
  local desc="$1" expect="$2"
  [ "$(run901)" = "$expect" ] || fail "$desc (expected $expect, got $(run901); stderr: $(cat "$T/err"))"
  pass "$desc"
}

# refl_board PRED_SECTION MAIN_LINE... -- PRED_LINE...
# PRED_SECTION is "active" (T-900 stays open, alongside T-901) or "done"
# (T-900 already closed) or "none" (no T-900 entry at all).
refl_board() {
  local pred_section="$1"; shift
  local -a main_lines=() pred_lines=()
  local cur=main a
  for a in "$@"; do
    if [ "$a" = "--" ]; then cur=pred; continue; fi
    if [ "$cur" = "main" ]; then main_lines+=("$a"); else pred_lines+=("$a"); fi
  done
  {
    printf '## Active\n\n- [ ] **T-901** fixture entry\n'
    for a in "${main_lines[@]}"; do printf '  %s\n' "$a"; done
    printf '\n'
    if [ "$pred_section" = "active" ]; then
      printf -- '- [ ] **T-900** predecessor entry\n'
      for a in "${pred_lines[@]}"; do printf '  %s\n' "$a"; done
      printf '\n'
    fi
    printf '## Done\n\n'
    if [ "$pred_section" = "closed" ]; then
      printf -- '- [x] **T-900** predecessor entry\n'
      for a in "${pred_lines[@]}"; do printf '  %s\n' "$a"; done
      printf '\n'
    fi
  } > "$T/refl.md"
}

D_SPECIFY="- dispatch: specify — pm-authored — unconditional — recommendation: r"
D_VERIFY_SELF="- dispatch: verify — serial — unconditional — recommendation: r"
D_VERIFY_PRED="- dispatch: verify — tier1-fanout — unconditional — recommendation: r"

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" "$D_VERIFY_SELF" \
  "- dispatch-reflection: specify — T-900 — repeat — ground" \
  "- dispatch-reflection: verify — T-900 — differs — ground" \
  -- "$D_SPECIFY" "$D_VERIFY_PRED"
chk901 "conformant dispatch-reflection family (predecessor in ## Done, one repeat + one differs) passes" 0

refl_board active "- entry-mode: pm-authored" "$D_SPECIFY" "$D_VERIFY_SELF" \
  "- dispatch-reflection: specify — T-900 — repeat — ground" \
  "- dispatch-reflection: verify — T-900 — differs — ground" \
  -- "$D_SPECIFY" "$D_VERIFY_PRED"
chk901 "conformant dispatch-reflection family with predecessor still open in ## Active passes (A-8: not a widening of the --task entry's own ## Active-only scan)" 0

refl_board none "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: all — no-predecessor — no-predecessor-row — first task of the train"
chk901 "the no-predecessor form passes whatever axes the entry itself records" 0

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: all — no-predecessor — no-predecessor-row — g" \
  "- dispatch-reflection: specify — T-900 — repeat — g" \
  -- "$D_SPECIFY"
chk901 "mixing the no-predecessor form with a per-axis row refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" "$D_VERIFY_SELF" \
  "- dispatch-reflection: bogus — T-900 — repeat — ground" \
  "- dispatch-reflection: verify — T-900 — differs — ground" \
  -- "$D_SPECIFY" "$D_VERIFY_PRED"
chk901 "an axis outside the closed dispatch-axis keys (and not 'all') refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" "$D_VERIFY_SELF" \
  "- dispatch-reflection: specify — T-900 — repeat — ground" \
  "- dispatch-reflection: specify — T-900 — differs — ground" \
  -- "$D_SPECIFY" "$D_VERIFY_PRED"
chk901 "a duplicated dispatch-reflection axis refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: specify — T-900 —" \
  -- "$D_SPECIFY"
chk901 "a dispatch-reflection row not parsing into '<axis> — <predecessor> — <verdict> — <ground>' refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: specify — T-900 — repeat — " \
  -- "$D_SPECIFY"
chk901 "a dispatch-reflection row with an empty ground field refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" "$D_VERIFY_SELF" \
  "- dispatch-reflection: specify — T-900 — repeat — ground" \
  -- "$D_SPECIFY" "$D_VERIFY_PRED"
chk901 "the family missing coverage for an axis the entry's own dispatch rows record refuses (no cherry-picking)" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: specify — T-900 — differs — ground" \
  -- "$D_SPECIFY"
chk901 "a stated verdict ('differs') that disagrees with the predecessor's own recorded value ('repeat' is correct) refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_VERIFY_SELF" \
  "- dispatch-reflection: verify — T-900 — repeat — ground" \
  -- "$D_VERIFY_PRED"
chk901 "a stated verdict ('repeat') that disagrees with the predecessor's own recorded value ('differs' is correct) refuses" 1

refl_board closed "- entry-mode: pm-authored" "$D_VERIFY_SELF" \
  "- dispatch-reflection: verify — T-900 — no-predecessor-row — ground" \
  -- "$D_SPECIFY"
chk901 "a stated verdict of 'no-predecessor-row' refuses when the predecessor DOES record that axis" 1

refl_board closed "- entry-mode: pm-authored" "$D_VERIFY_SELF" \
  "- dispatch-reflection: verify — T-899 — repeat — ground" \
  -- "$D_VERIFY_PRED"
chk901 "a predecessor id resolving to zero top-level board entries refuses (unresolvable reference, never a false no-predecessor)" 1

refl_board active "- entry-mode: pm-authored" "$D_SPECIFY" \
  "- dispatch-reflection: specify — T-900 — repeat — ground" \
  -- "$D_SPECIFY"
# Duplicate T-900 into ## Done too, so the id is genuinely ambiguous.
{
  cat "$T/refl.md"
} > "$T/refl-base.md"
awk -v add="$D_SPECIFY" '
  { print }
  /^## Done/ { print ""; print "- [x] **T-900** predecessor entry"; print "  " add }
' "$T/refl-base.md" > "$T/refl.md"
chk901 "a predecessor id resolving to two top-level board entries (one in ## Active, one in ## Done) refuses (ambiguous reference)" 1

refl_board closed "- entry-mode: pm-authored" "$D_SPECIFY" \
  "-  dispatch-reflection: specify — T-900 — repeat — ground" \
  -- "$D_SPECIFY"
chk901 "doubled-space-after-bullet on the dispatch-reflection stem: collected then refused as malformed, never silently read as the zero-rows case" 1

# --- comment-stripped flattened form carries the two shipped limits --------
fc() { sed 's/^[[:space:]]*#[[:space:]]*//' "$1" | tr '\n' ' ' | tr -s ' '; }
fc "$SCRIPT" > "$T/flat"
[ -s "$T/flat" ] || fail "the comment-stripped flattened form must be non-empty"
grep -qF -- 'never that the resolution is adequate' "$T/flat" || fail "the script must carry the 'never that the resolution is adequate' limit"
grep -qF -- 'the never-flagged case is undetectable' "$T/flat" || fail "the script must carry the 'the never-flagged case is undetectable' limit"
pass "the script's own bytes carry both disclosed limits verbatim"

printf '\nAll check-entry-mode assertions passed.\n'
