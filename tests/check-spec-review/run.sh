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

printf '\nAll check-spec-review assertions passed.\n'
