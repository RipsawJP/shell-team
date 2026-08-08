#!/usr/bin/env bash
# run.sh — drive bin/check-refreeze-class.sh (T-1028's M1 classifier) against
# synthetic intent-block-pair fixtures and assert its exit contract (D2/D3):
# 0 = mechanics, 1 = class-b, 2 = usage|structural. Every case runs through
# ONE shared helper, `assert_case`, which asserts the exit code AND the
# classification token TOGETHER (this repository's fixture-synthesis
# discipline: a wrong-but-nonzero result must not look like success — the
# same discipline tests/check-intent/run.sh and tests/check-provenance/run.sh
# already follow).
#
# 35 frozen case ids (T-1028 AC7 — present-in-file-and-in-output shape, the
# same T-1019/T-1025 convention: every id below must appear both in this
# file's source AND in a normal run's own stdout, so a deleted/renamed/
# silently-skipped case fails the acceptance criterion, not just this file):
#
#   crc-mechanics-one-line          — one `- check:` line differs   -> mechanics
#   crc-mechanics-two-lines         — two `- check:` lines differ   -> mechanics
#   crc-mechanics-crlf              — CRLF endings tolerated         -> mechanics
#   crc-mechanics-with-hashes       — correct --old-hash/--new-hash  -> mechanics
#   crc-mechanics-revert-newhash    — --new-hash anchors a restore   -> mechanics
#   crc-blindspot-swapped-checks    — PINNED blind spot (D3): a pure
#                                      swap of two check lines        -> mechanics
#   crc-classb-goal                 — Goal sentence differs          -> class-b
#   crc-classb-nongoals             — Non-goals line differs         -> class-b
#   crc-classb-inputspace           — Input space line differs       -> class-b
#   crc-classb-ac-prose             — an AC's own prose differs      -> class-b
#   crc-classb-ac-added             — a criterion+check line added   -> class-b
#   crc-classb-check-deleted        — a check line deleted           -> class-b
#   crc-classb-mixed                — one check + one Non-goals line
#                                      change together (no passenger) -> class-b
#   crc-classb-check-to-prose       — a check line replaced by prose
#                                      at the same index              -> class-b
#   crc-structural-identical        — byte-identical after normalize -> structural
#   crc-structural-missing-markers  — no marker pair at all          -> structural
#   crc-structural-duplicate-markers— a duplicated BEGIN marker      -> structural
#   crc-structural-reversed-markers — END precedes BEGIN             -> structural
#   crc-structural-taskid-mismatch  — old/new derive different ids   -> structural
#   crc-structural-no-taskid        — no **Task ID** line            -> structural
#   crc-structural-oldhash-mismatch — wrong --old-hash               -> structural
#   crc-structural-newhash-mismatch — wrong --new-hash               -> structural
#   crc-usage-no-args               — zero arguments                 -> usage
#   crc-usage-one-arg               — one positional argument        -> usage
#   crc-usage-extra-arg             — a third positional argument    -> usage
#   crc-usage-unknown-flag          — an unrecognized flag           -> usage
#   crc-usage-directory-arg         — a directory in place of a spec -> usage
#   crc-usage-unreadable            — a missing/unreadable path      -> usage
#   crc-usage-bad-hash-arg          — a malformed hash value          -> usage
#   crc-parity-hash-vs-check-intent — bin/check-intent.sh's own
#                                      computed+recorded hash is
#                                      accepted by this classifier as
#                                      --old-hash (T-1028 AC5's "one
#                                      number, two consumers" parity)  -> mechanics
#
# Five ids added by T-1034 (#139), pinning what T-1028's 30 covered only
# implicitly — normalize_stdin strips TRAILING whitespace only, so a leading-
# indent or internal-whitespace change on a `- check:` line is a real
# differing line whose both-sides check-line match still holds (mechanics),
# while dropping the indent entirely makes that line no longer match
# CHECK_LINE_RE on the new side (class-b); a tail addition (after the last
# content line, before the END marker) shifts no earlier index, so only the
# line-count clause can reject it — and it must be NON-EMPTY, since a blank
# appended line is normalized away and would report structural instead:
#
#   crc-mechanics-indent-widened    — one check line's indent 2->4 spaces -> mechanics
#   crc-mechanics-internal-whitespace — a second space after the colon    -> mechanics
#   crc-classb-indent-dropped       — that line's indent removed entirely -> class-b
#   crc-classb-tail-check-added     — a non-empty check line appended
#                                      at the block's tail               -> class-b
#   crc-classb-tail-prose-added     — a non-empty plain bullet appended
#                                      at the block's tail               -> class-b
#
# Fixtures use synthetic task id T-900 (not a real board task), built fresh
# in a temp dir per case — no static fixtures/ directory needed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLASSIFIER="$REPO_ROOT/bin/check-refreeze-class.sh"
CHECK_INTENT="$REPO_ROOT/bin/check-intent.sh"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-refreeze-class-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_case <case-id> <want-exit-code> <want-token> -- <classifier args...>
# Asserts the exit code AND the classification token TOGETHER (T-1028 AC7's
# single-shared-helper discipline). Routing every case through this ONE
# function is what AC7's `grep -c 'assert_case '` count protects — a case
# that called the classifier directly would both break that count and drop
# the both-assert discipline.
assert_case() {
  local id="$1" want_rc="$2" want_token="$3" out rc
  shift 3
  set +e
  out="$(bash "$CLASSIFIER" "$@" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne "$want_rc" ]; then
    fail "$id: expected exit $want_rc, got $rc — output: $out"
  fi
  if ! printf '%s\n' "$out" | grep -qF -- "$want_token"; then
    fail "$id: expected token '$want_token' in output, got: $out"
  fi
  pass "$id"
}

# --- base fixture builder (T-900, two `- check:` lines) ---------------------
mk_base() {  # $1 = outfile
  cat > "$1" <<'BASEEOF'
# Fixture

**Task ID**: T-900

<!-- BEGIN intent-block: T-900 -->
## Goal
GOALSENT

## Non-goals
- NGONE

## Acceptance criteria
- [ ] **AC1** alpha
  - check: true
- [ ] **AC2** beta
  - check: test 1 = 1

## Input space
- Reachable: r
- Out-of-scope: o

<!-- END intent-block: T-900 -->
BASEEOF
}

# oracle_hash <spec> <task-id> — independently computed (never via the
# classifier under test): extract the marker region, normalize identically to
# bin/check-intent.sh's documented normalization, hash with git hash-object.
oracle_hash() {
  local path="$1" tid="$2" b e
  b="$(awk -v m="<!-- BEGIN intent-block: ${tid} -->" '$0==m{print NR; exit}' "$path")"
  e="$(awk -v m="<!-- END intent-block: ${tid} -->" '$0==m{print NR; exit}' "$path")"
  awk -v b="$b" -v e="$e" 'NR > b && NR < e' "$path" \
    | sed -e 's/\r$//' -e 's/[[:space:]]*$//' \
    | awk '{ lines[NR] = $0; if ($0 != "") { if (first == 0) first = NR; last = NR } } END { for (i = first; i <= last && first > 0; i++) print lines[i] }' \
    | git hash-object --stdin
}

BASE="$TMP/base.md"
mk_base "$BASE"

# =============================================================================
# mechanics cases
# =============================================================================

ONE_LINE="$TMP/one-line.md"
awk '{ if ($0 == "  - check: true") print "  - check: test 5 = 5"; else print }' "$BASE" > "$ONE_LINE"
assert_case "crc-mechanics-one-line" 0 "check-refreeze-class: mechanics:" "$BASE" "$ONE_LINE"

TWO_LINES="$TMP/two-lines.md"
awk '{
  if ($0 == "  - check: true") print "  - check: test 5 = 5";
  else if ($0 == "  - check: test 1 = 1") print "  - check: test 6 = 6";
  else print
}' "$BASE" > "$TWO_LINES"
assert_case "crc-mechanics-two-lines" 0 "check-refreeze-class: mechanics:" "$BASE" "$TWO_LINES"
# Strengthened assertion (T-1028 rework): a two-line mechanics repair must
# report `differing=2` on its own mechanics line — the count D4's board
# record shape reads as `lines=<n>` to know how many `old[i]:`/`new[i]:`
# pairs to write, never counted by hand. Not counted toward assert_case's
# tally (it re-derives an independent check on the same fixture, it does not
# add a new case id).
TWO_LINES_OUT="$(bash "$CLASSIFIER" "$BASE" "$TWO_LINES" 2>&1)"
printf '%s\n' "$TWO_LINES_OUT" | grep -qF -- 'differing=2' \
  || fail "crc-mechanics-two-lines: expected 'differing=2' in output, got: $TWO_LINES_OUT"

BASE_CRLF="$TMP/base-crlf.md"
ONE_LINE_CRLF="$TMP/one-line-crlf.md"
awk '{ printf "%s\r\n", $0 }' "$BASE" > "$BASE_CRLF"
awk '{ printf "%s\r\n", $0 }' "$ONE_LINE" > "$ONE_LINE_CRLF"
assert_case "crc-mechanics-crlf" 0 "check-refreeze-class: mechanics:" "$BASE_CRLF" "$ONE_LINE_CRLF"

HO="$(oracle_hash "$BASE" T-900)"
HN="$(oracle_hash "$ONE_LINE" T-900)"
assert_case "crc-mechanics-with-hashes" 0 "check-refreeze-class: mechanics:" \
  --old-hash "$HO" --new-hash "$HN" "$BASE" "$ONE_LINE"

# revert direction: "old" is the mechanics-edited version, "new" is the
# restored (pristine) base — --new-hash anchors that the restored content is
# byte-identical to what the board's superseded hash names (D5's revert use).
HN_RESTORE="$(oracle_hash "$BASE" T-900)"
assert_case "crc-mechanics-revert-newhash" 0 "check-refreeze-class: mechanics:" \
  --new-hash "$HN_RESTORE" "$ONE_LINE" "$BASE"

SWAP="$TMP/swap.md"
awk '{
  if ($0 == "  - check: true") print "  - check: test 1 = 1";
  else if ($0 == "  - check: test 1 = 1") print "  - check: true";
  else print
}' "$BASE" > "$SWAP"
assert_case "crc-blindspot-swapped-checks" 0 "check-refreeze-class: mechanics:" "$BASE" "$SWAP"

# =============================================================================
# class-b cases
# =============================================================================

CB_GOAL="$TMP/cb-goal.md"
awk '{ if ($0 == "GOALSENT") print "OTHERGOAL"; else print }' "$BASE" > "$CB_GOAL"
assert_case "crc-classb-goal" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_GOAL"

CB_NONGOALS="$TMP/cb-nongoals.md"
awk '{ if ($0 == "- NGONE") print "- NGTWO"; else print }' "$BASE" > "$CB_NONGOALS"
assert_case "crc-classb-nongoals" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_NONGOALS"

CB_INPUTSPACE="$TMP/cb-inputspace.md"
awk '{ if ($0 == "- Reachable: r") print "- Reachable: rX"; else print }' "$BASE" > "$CB_INPUTSPACE"
assert_case "crc-classb-inputspace" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_INPUTSPACE"

CB_AC_PROSE="$TMP/cb-ac-prose.md"
awk '{ if ($0 == "- [ ] **AC2** beta") print "- [ ] **AC2** betaX"; else print }' "$BASE" > "$CB_AC_PROSE"
assert_case "crc-classb-ac-prose" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_AC_PROSE"

CB_AC_ADDED="$TMP/cb-ac-added.md"
awk '/^## Input space$/ { print "- [ ] **AC3** gamma"; print "  - check: true"; print "" } { print }' "$BASE" > "$CB_AC_ADDED"
assert_case "crc-classb-ac-added" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_AC_ADDED"

CB_CHECK_DELETED="$TMP/cb-check-deleted.md"
awk '$0 != "  - check: test 1 = 1"' "$BASE" > "$CB_CHECK_DELETED"
assert_case "crc-classb-check-deleted" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_CHECK_DELETED"

CB_MIXED="$TMP/cb-mixed.md"
awk '{
  if ($0 == "  - check: true") print "  - check: test 3 = 3";
  else if ($0 == "- NGONE") print "- NGTWO";
  else print
}' "$BASE" > "$CB_MIXED"
assert_case "crc-classb-mixed" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_MIXED"

CB_CHECK_TO_PROSE="$TMP/cb-check-to-prose.md"
awk '{ if ($0 == "  - check: true") print "  - note: true"; else print }' "$BASE" > "$CB_CHECK_TO_PROSE"
assert_case "crc-classb-check-to-prose" 1 "check-refreeze-class: class-b:" "$BASE" "$CB_CHECK_TO_PROSE"

# =============================================================================
# structural cases
# =============================================================================

SAME="$TMP/same.md"
cp "$BASE" "$SAME"
assert_case "crc-structural-identical" 2 "check-refreeze-class: structural:" "$BASE" "$SAME"

NO_MARKERS="$TMP/no-markers.md"
awk '$0 != "<!-- BEGIN intent-block: T-900 -->" && $0 != "<!-- END intent-block: T-900 -->"' "$BASE" > "$NO_MARKERS"
assert_case "crc-structural-missing-markers" 2 "check-refreeze-class: structural:" "$BASE" "$NO_MARKERS"

DUP_MARKERS="$TMP/dup-markers.md"
awk '{ print; if ($0 == "<!-- BEGIN intent-block: T-900 -->") print }' "$BASE" > "$DUP_MARKERS"
assert_case "crc-structural-duplicate-markers" 2 "check-refreeze-class: structural:" "$BASE" "$DUP_MARKERS"

REVERSED="$TMP/reversed.md"
awk '{
  if ($0 == "<!-- BEGIN intent-block: T-900 -->") print "<!-- END intent-block: T-900 -->";
  else if ($0 == "<!-- END intent-block: T-900 -->") print "<!-- BEGIN intent-block: T-900 -->";
  else print
}' "$BASE" > "$REVERSED"
assert_case "crc-structural-reversed-markers" 2 "check-refreeze-class: structural:" "$BASE" "$REVERSED"

OTHER_TASKID="$TMP/other-taskid.md"
awk '{ line = $0; gsub(/T-900/, "T-901", line); print line }' "$BASE" > "$OTHER_TASKID"
assert_case "crc-structural-taskid-mismatch" 2 "check-refreeze-class: structural:" "$BASE" "$OTHER_TASKID"

NO_TASKID="$TMP/no-taskid.md"
awk '$0 != "**Task ID**: T-900"' "$BASE" > "$NO_TASKID"
assert_case "crc-structural-no-taskid" 2 "check-refreeze-class: structural:" "$BASE" "$NO_TASKID"

BAD40='0000000000000000000000000000000000000000'
assert_case "crc-structural-oldhash-mismatch" 2 "check-refreeze-class: structural:" \
  --old-hash "$BAD40" "$BASE" "$ONE_LINE"
assert_case "crc-structural-newhash-mismatch" 2 "check-refreeze-class: structural:" \
  --new-hash "$BAD40" "$BASE" "$ONE_LINE"

# =============================================================================
# usage cases
# =============================================================================

assert_case "crc-usage-no-args" 2 "check-refreeze-class: usage:"
assert_case "crc-usage-one-arg" 2 "check-refreeze-class: usage:" "$BASE"
assert_case "crc-usage-extra-arg" 2 "check-refreeze-class: usage:" "$BASE" "$ONE_LINE" "$BASE"
assert_case "crc-usage-unknown-flag" 2 "check-refreeze-class: usage:" --nope "$BASE" "$ONE_LINE"

A_DIR="$TMP/a-directory"
mkdir -p "$A_DIR"
assert_case "crc-usage-directory-arg" 2 "check-refreeze-class: usage:" "$A_DIR" "$ONE_LINE"

assert_case "crc-usage-unreadable" 2 "check-refreeze-class: usage:" "$TMP/does-not-exist-xyz.md" "$ONE_LINE"
assert_case "crc-usage-bad-hash-arg" 2 "check-refreeze-class: usage:" --old-hash zz "$BASE" "$ONE_LINE"

# =============================================================================
# T-1034 (#139): indent/internal-whitespace and tail-addition cases
# =============================================================================

INDENT_WIDENED="$TMP/indent-widened.md"
awk '{ if ($0 == "  - check: true") print "    - check: true"; else print }' "$BASE" > "$INDENT_WIDENED"
assert_case "crc-mechanics-indent-widened" 0 "check-refreeze-class: mechanics:" "$BASE" "$INDENT_WIDENED"

INTERNAL_WS="$TMP/internal-whitespace.md"
awk '{ if ($0 == "  - check: true") print "  - check:  true"; else print }' "$BASE" > "$INTERNAL_WS"
assert_case "crc-mechanics-internal-whitespace" 0 "check-refreeze-class: mechanics:" "$BASE" "$INTERNAL_WS"

INDENT_DROPPED="$TMP/indent-dropped.md"
awk '{ if ($0 == "  - check: true") print "- check: true"; else print }' "$BASE" > "$INDENT_DROPPED"
assert_case "crc-classb-indent-dropped" 1 "check-refreeze-class: class-b:" "$BASE" "$INDENT_DROPPED"

# Both tail additions are NON-EMPTY on purpose (D14): normalize_stdin drops
# leading/trailing BLANK lines, so a blank appended line would normalize
# away and yield structural (byte-identical), testing nothing.
TAIL_CHECK_ADDED="$TMP/tail-check-added.md"
awk '{ print; if ($0 == "- Out-of-scope: o") print "  - check: true" }' "$BASE" > "$TAIL_CHECK_ADDED"
assert_case "crc-classb-tail-check-added" 1 "check-refreeze-class: class-b:" "$BASE" "$TAIL_CHECK_ADDED"

TAIL_PROSE_ADDED="$TMP/tail-prose-added.md"
awk '{ print; if ($0 == "- Out-of-scope: o") print "- Extra: e" }' "$BASE" > "$TAIL_PROSE_ADDED"
assert_case "crc-classb-tail-prose-added" 1 "check-refreeze-class: class-b:" "$BASE" "$TAIL_PROSE_ADDED"

# =============================================================================
# parity case (T-1028 AC5's "one number, two consumers" — here as a suite case)
# =============================================================================

PARITY_SPEC="$TMP/parity-spec.md"
mk_base "$PARITY_SPEC"
PARITY_HASH="$(oracle_hash "$PARITY_SPEC" T-900)"
PARITY_BOARD="$TMP/parity-board.md"
cat > "$PARITY_BOARD" <<EOF
# Tasks

## Active

- [ ] **T-900** fixture entry
  - freeze-attestation (v1, 2026-01-01): lines=2/2 sweep=mutual-satisfiability verdict=2P/0F owner=fixture
  - intent-hash (v1): $PARITY_HASH

## Done
EOF

# Positive control (not counted toward assert_case's tally): confirm
# check-intent.sh itself reports `aligned` against this same hash BEFORE
# using it as this classifier's --old-hash — proving the parity is measured
# against the real oracle, not merely asserted.
set +e
CI_OUT="$(bash "$CHECK_INTENT" "$PARITY_SPEC" "$PARITY_BOARD" 2>&1)"
CI_RC=$?
set -e
[ "$CI_RC" -eq 0 ] || fail "crc-parity-hash-vs-check-intent: check-intent.sh oracle setup did not report aligned (rc=$CI_RC): $CI_OUT"
printf '%s\n' "$CI_OUT" | grep -qF -- 'aligned' || fail "crc-parity-hash-vs-check-intent: check-intent.sh oracle output did not carry 'aligned': $CI_OUT"

PARITY_NEW="$TMP/parity-new.md"
awk '{ if ($0 == "  - check: true") print "  - check: test 9 = 9"; else print }' "$PARITY_SPEC" > "$PARITY_NEW"
assert_case "crc-parity-hash-vs-check-intent" 0 "check-refreeze-class: mechanics:" \
  --old-hash "$PARITY_HASH" "$PARITY_SPEC" "$PARITY_NEW"

printf '\ncheck-refreeze-class fixture suite: all 35 cases passed\n'
