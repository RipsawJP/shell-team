#!/usr/bin/env bash
# run.sh — assert bin/check-spec-review.sh (T-1096, issue #344) against the
# real script: the close-out backstop refusing an elected spec review whose
# record's last anchored verdict line is not an approval.
#
# Requirement floor (verbatim from the spec's §2, immune-or-refused):
#   1. Unanchored verdict match (a prefix-matching near-miss)
#   2. Unscoped scan (an earlier APPROVE beside a later REQUEST_CHANGES)
#   3. Heading-match asymmetry (trailing/internal whitespace heading variant)
#   4. Boundary defeat, dangerous direction (leading-whitespace heading leak)
#   5. CRLF fallback bypass
#   6. Missing/non-ASCII separator (heading AND the verdict line's own)
#   7. EOF safety (a final line with no trailing newline)
#
# Exit: 0 = every assertion passed; non-zero = a FAIL line was printed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-spec-review.sh"

if [ -n "${TMPDIR:-}" ]; then
  T="$(mktemp -d "${TMPDIR%/}/check-spec-review-test.XXXXXX")"
else
  T="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

mkdir -p "$T/rev"

# bd VALUE — a fixture board with one T-900 entry. VALUE="" omits the
# `- dispatch: spec-review — ...` sub-bullet entirely.
bd() {
  {
    printf '## Active\n\n- [ ] **T-900** fixture entry\n'
    [ -n "$1" ] && printf '  - dispatch: spec-review — %s — unconditional — recommendation: r\n' "$1"
    printf '\n'
  } > "$T/board.md"
}

run() {
  TEAM_REVIEWS_DIR="$T/rev" bash "$SCRIPT" --board "$T/board.md" --task T-900 >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

# invoke_rc CMD... — runs a command whose non-zero exit is expected (so a
# bare `set -e` script never aborts on it): captures stdout/stderr into
# $T/out and $T/err and echoes the exit code as this function's own (always
# zero-exit, via `printf`) return value.
invoke_rc() {
  "$@" >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

R="$T/rev/T-900.md"

# --- election (validate-if-present) --------------------------------------
bd cross-provider
printf '### Codex Spec-Review verdict: APPROVE\n' > "$R"
[ "$(run)" = "0" ] || fail "elected + APPROVE record passes"
pass "elected + APPROVE record passes (positive control: the whole matrix below depends on this passing case existing)"

rm -f "$R"
[ "$(run)" = "1" ] || fail "elected + no record refuses"
grep -qF -- 'no readable review record' "$T/err" || fail "elected + no record: stderr must name the readability reason"
pass "elected + no record refuses, naming the readability reason"

printf '### Codex Spec-Review verdict: APPROVE\n' > "$R"
bd none
[ "$(run)" = "0" ] || fail "none + a stale APPROVE record still passes"
pass "election=none is a silent pass-through regardless of the record's own content"

bd ""
[ "$(run)" = "0" ] || fail "no spec-review dispatch record at all still passes"
pass "no spec-review dispatch record at all (every in-flight three-axis task) passes"

bd serial
[ "$(run)" = "0" ] || fail "an out-of-vocabulary election value is treated as not-elected (pass-through), never guessed"
pass "an out-of-vocabulary spec-review value is a pass-through, not a crash"

# --- bad invocation --------------------------------------------------------
bd cross-provider

[ "$(TEAM_REVIEWS_DIR="$T/rev" invoke_rc bash "$SCRIPT" --board "$T/board.md")" = "2" ] \
  || fail "missing --task must exit 2"
pass "missing --task exits 2, distinct from every content refusal"

[ "$(TEAM_REVIEWS_DIR="$T/rev" invoke_rc bash "$SCRIPT" --task T-900)" = "2" ] \
  || fail "missing --board must exit 2"
pass "missing --board exits 2"

printf 'not a directory\n' > "$T/notdir"
[ "$(TEAM_REVIEWS_DIR="$T/notdir" invoke_rc bash "$SCRIPT" --board "$T/board.md" --task T-900)" = "2" ] \
  || fail "TEAM_REVIEWS_DIR pointing at a non-directory must exit 2"
pass "TEAM_REVIEWS_DIR pointing at a path that cannot be a directory exits 2, not 1"

[ "$(TEAM_REVIEWS_DIR="$T/rev" invoke_rc bash "$SCRIPT" --board "$T/does-not-exist.md" --task T-900)" = "2" ] \
  || fail "an unreadable board must exit 2"
pass "an unreadable --board value exits 2"

[ "$(TEAM_REVIEWS_DIR="$T/rev" invoke_rc bash "$SCRIPT" --board "$T/board.md" --task T-999)" = "2" ] \
  || fail "a task not present in ## Active must exit 2"
pass "a --task value not found as one top-level ## Active entry exits 2"

# --- the six verbatim defeat classes, plus EOF safety (7) -----------------
chk() {
  local desc="$1" expect="$2"
  [ "$(run)" = "$expect" ] || fail "$desc (expected $expect, got $(run); stderr: $(cat "$T/err"))"
  pass "$desc"
}

bd cross-provider

printf '### Codex Spec-Review verdict: APPROVE_WITH_CAVEATS\n' > "$R"
chk "class 1: an unanchored prefix-matching near-miss (APPROVE_WITH_CAVEATS) refuses" 1

printf '### Codex Spec-Review verdict: APPROVE | REQUEST_CHANGES\n' > "$R"
chk "class 1: the unfilled output template literal refuses" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
chk "class 2: an earlier APPROVE beside a later REQUEST_CHANGES refuses on the latest round" 1

printf '## Spec review \n### Codex Spec-Review verdict: APPROVE\n## Spec review \n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
chk "class 3: a trailing-whitespace heading variant does not hide the later REQUEST_CHANGES (no heading consulted)" 1

printf '##  Spec review\n### Codex Spec-Review verdict: APPROVE\n##  Spec review\n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
chk "class 3: an internal-double-space heading variant is likewise immune" 1

printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n ### Codex Spec-Review verdict: APPROVE\n' > "$R"
chk "class 4: a later line indented with leading whitespace is not a verdict line at all (boundary, dangerous direction)" 1

printf '## Spec review\r\n### Codex Spec-Review verdict: APPROVE (round 3)\r\n' > "$R"
chk "class 5: a CRLF-terminated record whose latest round is APPROVE passes" 0

printf '### Codex Spec-Review verdict: APPROVE\r\n### Codex Spec-Review verdict: REQUEST_CHANGES\r\n' > "$R"
chk "class 5: a CRLF-terminated record's stale APPROVE never resurrects (no whole-file fallback)" 1

printf '##Spec review\n### Codex Spec-Review verdict: APPROVE\n##Spec review\n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
chk "class 6 (heading): a zero-space heading separator is likewise immune" 1

printf '##\302\240Spec review\n### Codex Spec-Review verdict: APPROVE\n##\302\240Spec review\n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
chk "class 6 (heading): a U+00A0 heading separator is likewise immune" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict:\302\240REQUEST_CHANGES\n' > "$R"
chk "class 6 (6b, verdict line's own separator): U+00A0 after the colon refuses rather than falling through to the stale APPROVE" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict:\tREQUEST_CHANGES\n' > "$R"
chk "class 6 (6b): a tab after the colon refuses rather than falling through" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict:REQUEST_CHANGES\n' > "$R"
chk "class 6 (6b): a missing separator entirely refuses rather than falling through" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict: REQUEST_CHANGES' > "$R"
chk "class 7 (EOF safety): an unterminated final REQUEST_CHANGES line still refuses (not silently dropped)" 1

printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict: APPROVE (round 2)' > "$R"
chk "class 7 (EOF safety): an unterminated final APPROVE (round 2) line still passes" 0

printf 'no verdict here at all\n## Spec review\nprose only\n' > "$R"
chk "zero collected: a record with no line matching the anchored prefix at all refuses (never a whole-file fallback, never a pass)" 1

# --- append-only / distinct-literal property (issue #344's producer premise) -
printf '## Spec review\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\n## Delivered-change review\n### Codex Review verdict: APPROVE\n' > "$R"
chk "the default-mode literal 'Codex Review verdict' (no 'Spec-Review') is never read as a spec-review verdict, direction A" 1

printf '## Spec review\n### Codex Spec-Review verdict: APPROVE (round 2)\n## Delivered-change review\n### Codex Review verdict: REQUEST_CHANGES\n' > "$R"
chk "the default-mode literal is never read as a spec-review verdict, direction B" 0

printf '## Spec review\n### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
printf '## Spec review\n### Codex Spec-Review verdict: APPROVE\n' > "$T/rewritten-in-place.md"
mv "$T/rewritten-in-place.md" "$R"
chk "an in-place-rewritten record (a stale APPROVE left as the only verdict) passes — the disclosed limit, not a defect: indistinguishable from a genuine single-round approval by construction" 0

# --- the closed four-form grammar, exhaustively ----------------------------
put() { printf '### Codex Spec-Review verdict: %s\n' "$1" > "$R"; }

put "APPROVE"; chk "grammar: bare APPROVE" 0
put "APPROVE (round 7)"; chk "grammar: APPROVE (round 7)" 0
put "REQUEST_CHANGES"; chk "grammar: bare REQUEST_CHANGES (in-grammar refusal)" 1
put "REQUEST_CHANGES (round 4)"; chk "grammar: REQUEST_CHANGES (round 4) (in-grammar refusal)" 1
put "approve"; chk "grammar: lowercase is not in the closed vocabulary" 1
put "APPROVE "; chk "grammar: a trailing space is not in the closed vocabulary" 1
put "APPROVE (round)"; chk "grammar: (round) with no digits is not in the closed vocabulary" 1
put "APPROVE (round 2"; chk "grammar: an unclosed paren is not in the closed vocabulary" 1
put "APPROVE  (round 2)"; chk "grammar: a doubled internal space before the round suffix refuses" 1
put "APPROVE extra words"; chk "grammar: trailing extra words refuse" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict: APPROVE_WITH_CAVEATS\n' > "$R"
chk "skip-vs-refuse (tail axis): the last stem-matching line is judged, not rescued by an earlier in-grammar APPROVE" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict:  APPROVE\n' > "$R"
chk "skip-vs-refuse (separator axis): a doubled-space separator on the LAST line refuses even though its tail (APPROVE) would otherwise be in-grammar" 1

printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict:\302\240APPROVE\n' > "$R"
chk "skip-vs-refuse (separator axis): a U+00A0 separator on the LAST line refuses the same way" 1

# =========================================================================
# T-1160 (issue #630): the --rounds round-guard mode. Every fixture is built
# inline; the guard reads no board, so most runs pass none.
# =========================================================================
RC="$T/rounds-contract.yaml"
printf 'budget:\n  max_iterations: 6\n' > "$RC"
RR="$T/rev"

# rr [CONTRACT] — run the guard; echoes rc; stdout in $T/rout, stderr in $T/rerr.
rr() {
  TEAM_REVIEWS_DIR="$RR" bash "$SCRIPT" --rounds --task T-900 --contract "${1:-$RC}" >"$T/rout" 2>"$T/rerr"
  printf '%s' "$?"
}
# rr_is LABEL RC STDOUT [CONTRACT] — assert rc, and that stdout is exactly the one line (or, for "", nothing).
rr_is() {
  local label="$1" want_rc="$2" want_out="$3" got
  got="$(rr "${4:-$RC}")"
  [ "$got" = "$want_rc" ] || fail "$label: expected rc $want_rc, got $got (stderr: $(cat "$T/rerr"))"
  if [ -z "$want_out" ]; then
    [ ! -s "$T/rout" ] || fail "$label: stdout must be empty, got: $(cat "$T/rout")"
  else
    [ "$(cat "$T/rout")" = "$want_out" ] || fail "$label: expected stdout '$want_out', got: $(cat "$T/rout")"
  fi
  pass "rounds: $label"
}
# rr_refused LABEL [CONTRACT] — anything but 0/3, and nothing on stdout.
rr_refused() {
  local label="$1" got
  got="$(rr "${2:-$RC}")"
  { [ "$got" != "0" ] && [ "$got" != "3" ]; } || fail "$label: expected a refusal, got rc $got (stdout: $(cat "$T/rout"))"
  [ ! -s "$T/rout" ] || fail "$label: a refusal must leave stdout empty, got: $(cat "$T/rout")"
  pass "rounds: $label"
}
# vs TOKEN... — one verdict line per argument.
vs() { printf '### Codex Spec-Review verdict: %s\n' "$@" > "$R"; }
# vn N — N REQUEST_CHANGES lines, bare then (round 2)..(round N).
vn() {
  { printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n'; local i=2
    while [ "$i" -le "$1" ]; do printf '### Codex Spec-Review verdict: REQUEST_CHANGES (round %s)\n' "$i"; i=$((i+1)); done; } > "$R"
}
STOP_LINE='STOP:spec_review_rounds_reached'

rm -f "$R"
rr_is "an absent record is zero lines: CONTINUE" 0 CONTINUE
( mkdir -p "$T/noboard" && cd "$T/noboard" && [ "$(rr "$RC")" = 0 ] ) || fail "rounds: an absent record from a board-less cwd must still be CONTINUE"
pass "rounds: the mode reads no board (absent record, cwd with no board)"

# positive controls first, then the cap
vn 1; rr_is "one round continues" 0 CONTINUE
vn 2; rr_is "two rounds continue (positive control below the default cap)" 0 CONTINUE
vn 3; rr_is "three rounds stop at the default cap" 3 "$STOP_LINE"
vn 12; rr_is "twelve rounds stop" 3 "$STOP_LINE"
[ "$(grep -c max_spec_review_rounds "$RC" || true)" = 0 ] || fail "rounds: the fixture contract must carry no key"
printf '# Review record\n\n## Spec review\n\n### Codex Spec-Review verdict: REQUEST_CHANGES\n\n#### Major\n- finding prose\n\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\n\n#### Major\n- more prose\n\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 3)\n' > "$R"
rr_is "verdict lines interleaved with headings and finding prose are counted" 3 "$STOP_LINE"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\n## Delivered-change review\n### Codex Review verdict: REQUEST_CHANGES\n' > "$R"
rr_is "a default-mode verdict heading is not counted" 0 CONTINUE
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n  ### Codex Spec-Review verdict: REQUEST_CHANGES\n' > "$R"
rr_is "an indented verdict line is not collected (as in the close-out mode)" 0 CONTINUE
printf '# no verdict here\n' > "$R"; rr_is "a record with no verdict line is CONTINUE" 0 CONTINUE

# approvals
vs APPROVE; rr_is "a lone APPROVE is APPROVED" 0 APPROVED
vs REQUEST_CHANGES 'APPROVE (round 2)'; rr_is "REQUEST_CHANGES then APPROVE (round 2) is APPROVED" 0 APPROVED
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 2)' 'APPROVE (round 3)'; rr_is "an approval at the cap is APPROVED, never STOP" 0 APPROVED
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 2)' 'REQUEST_CHANGES (round 3)' 'APPROVE (round 4)'; rr_is "an approval past the cap is APPROVED" 0 APPROVED
vs APPROVE 'REQUEST_CHANGES (round 2)'; rr_is "an approval that a later round overtook is not APPROVED (last line wins)" 0 CONTINUE

# cap key: override, disable, 10# handling, inline comment, section scoping, junk
CK="$T/cap.yaml"
cap() { printf 'budget:\n  max_iterations: 6\n  max_spec_review_rounds: %s\n' "$1" > "$CK"; }
cap 5; vn 3; rr_is "cap 5: three rounds continue" 0 CONTINUE "$CK"
vn 5; rr_is "cap 5: five rounds stop" 3 "$STOP_LINE" "$CK"
cap 1; vn 1; rr_is "cap 1: one round stops" 3 "$STOP_LINE" "$CK"
cap 0; vn 12; rr_is "cap 0 disables the cap: twelve rounds continue" 0 CONTINUE "$CK"
cap 08; vn 3; rr_is "cap 08 is read decimal: three rounds continue" 0 CONTINUE "$CK"
vn 8; rr_is "cap 08 is read decimal: eight rounds stop" 3 "$STOP_LINE" "$CK"
cap 09; vn 9; rr_is "cap 09 (invalid octal) is read decimal: nine rounds stop" 3 "$STOP_LINE" "$CK"
cap '2   # tuned for this repository'; vn 2; rr_is "an inline comment is stripped" 3 "$STOP_LINE" "$CK"
printf 'budget:\n  max_iterations: 6\nstop:\n  max_spec_review_rounds: 1\n' > "$CK"; vn 1
rr_is "the key under stop: is not read: the default applies" 0 CONTINUE "$CK"
printf 'budget:\n  max_iterations: 6\n  # max_spec_review_rounds: 1\n' > "$CK"; vn 1
rr_is "a commented-out key is not read" 0 CONTINUE "$CK"
printf 'budget:\n  max_iterations: 6\n  max_spec_review_rounds: 1\n  max_spec_review_rounds: 9\n' > "$CK"; vn 1
rr_is "the first key in budget: wins" 3 "$STOP_LINE" "$CK"
printf 'budget:\r\n  max_spec_review_rounds: 2\r\n' > "$CK"; vn 2
rr_is "a CRLF contract still reads the key (CR is trailing whitespace)" 3 "$STOP_LINE" "$CK"
for junk in abc -1 1234567890 3.5 '"3"' "3 4" "0x3" "+3"; do
  cap "$junk"; vn 3; rr_refused "cap value '$junk' is refused" "$CK"
done
printf 'budget:\n  max_iterations: 6\n  max_spec_review_rounds:\n' > "$CK"; vn 3
rr_is "an empty value takes the default and never disables the cap" 3 "$STOP_LINE" "$CK"
vn 2; rr_is "an empty value: two rounds still continue" 0 CONTINUE "$CK"
printf 'stop:\n  x: 1\n' > "$CK"; vn 3; rr_is "a contract with no budget: section takes the default" 3 "$STOP_LINE" "$CK"

# grammar: every collected line is judged (a refusal, never a skip)
vs REQUEST_CHANGES; rr_is "positive control for the refusal matrix" 0 CONTINUE
vs REQUEST_CHANGES APPROVE_WITH_CAVEATS 'REQUEST_CHANGES (round 3)'; rr_refused "an out-of-grammar MIDDLE line is refused"
vs approve; rr_refused "a lone lowercase approve is refused"
vs 'REQUEST_CHANGES ' ; rr_refused "a trailing space is refused"
vs 'REQUEST_CHANGES  (round 2)' ; rr_refused "a doubled space before the suffix is refused"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict:\tREQUEST_CHANGES (round 2)\n' > "$R"; rr_refused "a tab separator on the last line is refused"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict:REQUEST_CHANGES (round 2)\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 3)\n' > "$R"; rr_refused "a missing separator on a MIDDLE line is refused"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict:\302\240REQUEST_CHANGES (round 2)\n' > "$R"; rr_refused "a U+00A0 separator is refused"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\r\r\n' > "$R"; rr_refused "a doubled CR strips only one and is refused"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES (round)\n' > "$R"; rr_refused "(round) with no digits is refused"
printf '### Codex Spec-Review verdict: APPROVE\n### Codex Spec-Review verdict: APPROVE_WITH_CAVEATS\n' > "$R"; rr_refused "an earlier APPROVE never rescues a malformed last line"

# line endings never change the count
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\r\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\r\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 3)\r\n' > "$R"
rr_is "a CRLF three-round record stops" 3 "$STOP_LINE"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 3)' > "$R"
rr_is "a final line with no trailing newline is still counted" 3 "$STOP_LINE"
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict: APPROVE (round 2)' > "$R"
rr_is "a final APPROVE with no trailing newline is APPROVED" 0 APPROVED
printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)\nno newline and not a verdict' > "$R"
rr_is "a non-verdict unterminated tail does not disturb the count" 0 CONTINUE

# position vs (round N) suffix (D2)
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 2)'; rr_is "suffix equals position" 0 CONTINUE
vs 'REQUEST_CHANGES (round 1)'; rr_is "a lone (round 1)" 0 CONTINUE
vs REQUEST_CHANGES REQUEST_CHANGES; rr_is "bare tokens are accepted at any position" 0 CONTINUE
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 02)'; rr_is "(round 02) is read decimal" 0 CONTINUE
printf 'budget:\n  max_spec_review_rounds: 9\n' > "$CK"
{ printf '### Codex Spec-Review verdict: REQUEST_CHANGES\n'; for i in 2 3 4 5 6 7; do printf '### Codex Spec-Review verdict: REQUEST_CHANGES (round %s)\n' "$i"; done; printf '### Codex Spec-Review verdict: REQUEST_CHANGES (round 08)\n'; } > "$R"
rr_is "(round 08) at position 8 is read decimal, never octal" 0 CONTINUE "$CK"
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 3)'; rr_refused "a suffix ahead of its position is refused"
vs 'REQUEST_CHANGES (round 2)'; rr_refused "a first line carrying (round 2) is refused"
vs REQUEST_CHANGES 'APPROVE (round 3)'; rr_refused "an approval with a wrong suffix is refused even though it is last"
vs 'REQUEST_CHANGES (round 0)'; rr_refused "(round 0) is refused"
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 002)' 'REQUEST_CHANGES (round 3)'; rr_is "leading zeros in a longer run are still decimal" 3 "$STOP_LINE" 
vs 'REQUEST_CHANGES (round 99999999999999999999)'; rr_refused "a suffix wider than any integer is refused, never wrapped into a match"
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 4294967298)'; rr_refused "a suffix that would wrap a 32-bit counter to the position is refused"

# unreadable input fails closed
rm -f "$R"; mkdir "$R"; rr_refused "a record path that is a directory is refused"; rmdir "$R"
ln -s "$T/nowhere" "$R"; rr_refused "a dangling symlink at the record path is refused"; rm -f "$R"
vs REQUEST_CHANGES
rr_refused "an absent contract is refused" "$T/absent.yaml"
mkdir "$T/cdir"; rr_refused "a contract path that is a directory is refused" "$T/cdir"
rm -f "$R"; rr_refused "an absent record with an absent contract is still refused (contract read first)" "$T/absent.yaml"
vs REQUEST_CHANGES
got="$(TEAM_REVIEWS_DIR="$T/notdir" invoke_rc bash "$SCRIPT" --rounds --task T-900 --contract "$RC")"
{ [ "$got" != "0" ] && [ "$got" != "3" ] && [ ! -s "$T/out" ]; } || fail "rounds: a reviews dir that is a regular file must be refused with empty stdout (rc $got)"
pass "rounds: a TEAM_REVIEWS_DIR that is a regular file is refused"

# invocation errors are exit 2 with nothing on stdout
inv2() {
  local label="$1"; shift
  local got
  got="$(TEAM_REVIEWS_DIR="$RR" invoke_rc bash "$SCRIPT" "$@")"
  [ "$got" = "2" ] || fail "rounds: $label: expected exit 2, got $got"
  [ ! -s "$T/out" ] || fail "rounds: $label: stdout must be empty"
  pass "rounds: $label exits 2"
}
inv2 "missing --contract" --rounds --task T-900
inv2 "malformed --task" --rounds --task T-abc --contract "$RC"
inv2 "missing --task" --rounds --contract "$RC"
inv2 "--contract with no value" --rounds --task T-900 --contract
inv2 "--rounds combined with --board" --rounds --task T-900 --contract "$RC" --board "$T/board.md"
inv2 "--contract without --rounds" --board "$T/board.md" --task T-900 --contract "$RC"

# the close-out mode ignores nothing new: a board electing none does not silence the guard
bd none; vn 3; rr_is "the board's election is never consulted (none does not silence the guard)" 3 "$STOP_LINE"
bd cross-provider; vs APPROVE
[ "$(run)" = "0" ] || fail "the close-out mode is unchanged after the round-guard mode was added"
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 2)' 'REQUEST_CHANGES (round 3)' 'APPROVE (round 4)'
[ "$(run)" = "0" ] || fail "close-out: three rounds then APPROVE (round 4) still exits 0"
[ ! -s "$T/out" ] || fail "close-out: stdout must stay empty"
vs REQUEST_CHANGES 'REQUEST_CHANGES (round 3)'
[ "$(run)" = "1" ] || fail "close-out: a REQUEST_CHANGES last verdict exits 1 (the round cap and the suffix check never leak into it)"
pass "close-out mode unchanged: the cap and the suffix check never reach it"

# launch shapes: bash script, ./script, a bare name reached through a PATH symlink
vn 3
[ "$(cd "$REPO_ROOT" && TEAM_REVIEWS_DIR="$RR" invoke_rc ./bin/check-spec-review.sh --rounds --task T-900 --contract "$RC")" = "3" ] \
  || fail "rounds: ./script launch shape"
[ "$(cat "$T/out")" = "$STOP_LINE" ] || fail "rounds: ./script launch shape stdout"
mkdir -p "$T/pathdir"; ln -s "$SCRIPT" "$T/pathdir/check-spec-review.sh"
[ "$(PATH="$T/pathdir:$PATH" TEAM_REVIEWS_DIR="$RR" invoke_rc check-spec-review.sh --rounds --task T-900 --contract "$RC")" = "3" ] \
  || fail "rounds: bare name through a PATH symlink launch shape"
[ "$(cat "$T/out")" = "$STOP_LINE" ] || fail "rounds: PATH-symlink launch shape stdout"
pass "rounds: launch shapes (bash script, ./script, PATH symlink) agree"

# the shipped contracts stop at three rounds
for f in "$REPO_ROOT/templates/shell-team.contract.yaml" "$REPO_ROOT/.shell-team/loops/shell-team.contract.yaml"; do
  vn 2; rr_is "shipped contract $(basename "$(dirname "$f")")/$(basename "$f"): two rounds continue" 0 CONTINUE "$f"
  vn 3; rr_is "shipped contract $(basename "$(dirname "$f")")/$(basename "$f"): three rounds stop" 3 "$STOP_LINE" "$f"
done

# --- D1: - gating-criterion: same-class-2 detection -------------------------
gs() { printf '%s\n' "$1" | bash "$REPO_ROOT/bin/goal-state.sh" signature; }
V1='### Codex Spec-Review verdict: REQUEST_CHANGES'
V2='### Codex Spec-Review verdict: REQUEST_CHANGES (round 2)'
V3='### Codex Spec-Review verdict: REQUEST_CHANGES (round 3)'
g() { printf -- '- gating-criterion: %s\n' "$1"; }
sc_lines() { grep -c '^SAME_CLASS_2:' "$T/rout" || true; }

DASH=-   # the hyphenated spelling is assembled so this file carries no tracker-shaped literal
{ echo "$V1"; g AC1; echo "$V2"; g "AC${DASH}1"; g premise; } > "$R"
[ "$(rr)" = 0 ] || fail "D1: AC1 then hyphenated AC1 must continue"
[ "$(head -n 1 "$T/rout")" = CONTINUE ] || fail "D1: first line must be the decision"
[ "$(sc_lines)" = 1 ] || fail "D1: exactly one SAME_CLASS_2 line ($(cat "$T/rout"))"
K="$(sed -n 's/^SAME_CLASS_2://p' "$T/rout")"
[ -n "$K" ] || fail "D1: empty key"
[ "$(gs "$K")" = NO_VERDICT ] || fail "D1: the key '$K' must be NO_VERDICT-clean under goal-state signature"
bash "$REPO_ROOT/bin/rework-digest.sh" --round 1 --phase review --class "$K" --round 2 --phase review --class "$K" --trigger same-class-2 >/dev/null 2>&1 \
  || fail "D1: rework-digest must accept the key '$K' as a same-class-2 class"
pass "D1: AC1 vs its hyphenated spelling share one NO_VERDICT-clean key that rework-digest accepts"

for pair in "AC7:AC${DASH}7" "AC7:AC07" "AC0:AC${DASH}0" "AC12:AC${DASH}012"; do
  pa="${pair%%:*}" pb="${pair##*:}"
  { echo "$V1"; g "$pa"; echo "$V2"; g "$pb"; } > "$R"
  [ "$(rr)" = 0 ] && [ "$(sc_lines)" = 1 ] || fail "D1: $pa and $pb must be one key"
done
pass "D1: spelling variants of one criterion (ACn, AC-N, leading zeros) are one key"

{ echo "$V1"; g premise; echo "$V2"; g premise; } > "$R"
[ "$(rr)" = 0 ] && [ "$(sc_lines)" = 1 ] || fail "D1: premise twice"
Q="$(sed -n 's/^SAME_CLASS_2://p' "$T/rout")"
[ "$Q" != "$K" ] || fail "D1: premise key must differ from the AC key"
[ "$(gs "$Q")" = NO_VERDICT ] || fail "D1: premise key '$Q' must be NO_VERDICT-clean"
pass "D1: premise repeated is its own NO_VERDICT-clean key"

{ echo "$V1"; g AC2; g AC2; echo "$V2"; g AC3; } > "$R"; rr_is "D1: one key twice within one round prints nothing extra" 0 CONTINUE
{ echo "$V1"; g AC1; echo "$V2"; g AC10; } > "$R"; rr_is "D1: AC1 versus AC10 across rounds are different keys" 0 CONTINUE
{ echo "$V1"; g AC1; echo "$V2"; g AC11; } > "$R"; rr_is "D1: AC1 versus AC11 are different keys" 0 CONTINUE
{ echo "$V1"; g AC1; echo "$V2"; g AC2; echo "$V3"; g AC1; } > "$R"
[ "$(rr)" = 3 ] || fail "D1: third round re-gated must stop"
[ "$(head -n 1 "$T/rout")" = "$STOP_LINE" ] && [ "$(sc_lines)" = 1 ] || fail "D1: STOP first then one SAME_CLASS_2 ($(cat "$T/rout"))"
pass "D1: a third round re-gated by AC1 prints STOP first, then one SAME_CLASS_2 line"
{ echo "$V1"; g AC1; g premise; echo "$V2"; g AC1; g premise; } > "$R"
[ "$(rr)" = 0 ] && [ "$(sc_lines)" = 2 ] || fail "D1: two repeating keys give two lines ($(cat "$T/rout"))"
pass "D1: each repeating key gets its own SAME_CLASS_2 line"
{ echo "$V1"; g AC1; echo "$V2"; g AC1; echo '### Codex Spec-Review verdict: APPROVE (round 3)'; } > "$R"; rr_is "D1: nothing is printed after APPROVED" 0 APPROVED
{ echo "$V1"; echo "$V2"; } > "$R"; rr_is "D1: rounds with no gating lines print no SAME_CLASS_2" 0 CONTINUE
printf '%s\n  - gating-criterion: not even a value\n%s\n' "$V1" "$V2" > "$R"; rr_is "D1: an indented gating line is not collected" 0 CONTINUE
{ echo "$V1"; printf -- '- gating-criterion: AC1\r\n'; echo "$V2"; printf -- '- gating-criterion: AC1\r\n'; } > "$R"
[ "$(rr)" = 0 ] && [ "$(sc_lines)" = 1 ] || fail "D1: a CRLF gating line must count"
pass "D1: CRLF gating lines count like LF ones"
{ echo "$V1"; printf -- '- gating-criterion: AC1'; } > "$R"; rr_is "D1: an unterminated final gating line is still judged and counted once" 0 CONTINUE
for bad in AC1b AC '' 'AC1 AC2' ac1 'AC 1' ' AC1' 'AC1 ' 'AC-' 'AC--1' 'premise2' 'Premise' 'AC1,AC2'; do
  { echo "$V1"; printf -- '- gating-criterion: %s\n' "$bad"; } > "$R"; rr_refused "D1: gating value '$bad' is refused"
done
{ echo "$V1"; printf -- '- gating-criterion:\tAC1\n'; } > "$R"; rr_refused "D1: a tab separator is refused"
{ echo "$V1"; printf -- '- gating-criterion:AC1\n'; } > "$R"; rr_refused "D1: a missing separator is refused"
{ printf -- '- gating-criterion: AC1\n'; echo "$V1"; } > "$R"; rr_refused "D1: a gating line before any verdict line is refused"

printf '\nAll check-spec-review assertions passed.\n'
