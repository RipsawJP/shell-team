#!/usr/bin/env bash
# run.sh — drive bin/derive-populations.sh against committed fixtures and
# assert its grammar, arithmetic, exit-code taxonomy and refusal surface
# (T-1071; .shell-team/specs/T-1071-record-set-derivation.md AC9). Fixtures
# are committed rather than generated at run time (unlike
# tests/check-pii-shapes/run.sh, whose runtime-generation exists solely
# because no PII-shaped byte may enter this tree — no such constraint
# applies to population listings here).
#
# Case ids (named here verbatim so AC9's own check can confirm the refusal
# surface was not quietly narrowed to the happy path): refusal-status,
# accepted-status, empty-set, single-set, duplicate-name, newline-command,
# control-char, three-sets, locale-pin, dedupe-blank, verbatim-item.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/derive-populations.sh"
FIX="$HERE/fixtures"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# Explicit ${TMPDIR:-/tmp} template (repo convention, T-038/T-112 — a bare
# mktemp resolves against the OS default temp dir regardless of $TMPDIR on
# macOS and fails closed in a sandbox).
T="$(mktemp -d "${TMPDIR:-/tmp}/derive-populations-suite.XXXXXX")"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$T" 2>/dev/null || true; }
trap cleanup EXIT

# =============================================================================
# case: single-set — fewer than two --set values is a usage error (exit 2,
# empty stdout).
# =============================================================================
out="$T/single-set.out"
if bash "$SCRIPT" --label single-set --set "A=echo x" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "2" ] && [ ! -s "$out" ]; then
  pass "single-set: fewer than two --set values is a usage error (exit 2, empty stdout)"
else
  fail "single-set: expected exit 2 + empty stdout, got rc=$rc size=$(wc -c <"$out" 2>/dev/null || echo '?')"
fi

# =============================================================================
# case: duplicate-name — two --set values sharing a name is a usage error.
# =============================================================================
out="$T/duplicate-name.out"
if bash "$SCRIPT" --label duplicate-name --set "A=echo p" --set "A=echo q" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "2" ] && [ ! -s "$out" ]; then
  pass "duplicate-name: two --set values sharing a name is a usage error (exit 2, empty stdout)"
else
  fail "duplicate-name: expected exit 2 + empty stdout, got rc=$rc"
fi

# =============================================================================
# case: newline-command — a --set command whose text contains a newline is
# a usage error.
# =============================================================================
out="$T/newline-command.out"
newline_val="$(printf 'A=echo p\necho q')"
if bash "$SCRIPT" --label newline-command --set "$newline_val" --set "B=echo r" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "2" ] && [ ! -s "$out" ]; then
  pass "newline-command: a --set command carrying an embedded newline is a usage error (exit 2, empty stdout)"
else
  fail "newline-command: expected exit 2 + empty stdout, got rc=$rc"
fi

# =============================================================================
# case: refusal-status — a set command exiting with an unaccepted status
# refuses the whole derivation (exit 1, empty stdout, non-empty stderr).
# =============================================================================
out="$T/refusal-status.out"
err="$T/refusal-status.err"
if bash "$SCRIPT" --label refusal-status --set "A=echo ok" --set "B=exit 3" >"$out" 2>"$err"; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "1" ] && [ ! -s "$out" ] && [ -s "$err" ]; then
  pass "refusal-status: an unaccepted non-zero set exit status refuses the whole derivation (exit 1, empty stdout, non-empty stderr)"
else
  fail "refusal-status: expected exit 1 + empty stdout + non-empty stderr, got rc=$rc"
fi

# =============================================================================
# case: accepted-status — --accept-status declares an additional acceptable
# status for one named set; the block records that status, never as a
# refusal (the "git grep exits 1 for no match" case, exercised here with a
# committed fixture).
# =============================================================================
out="$T/accepted-status.out"
if bash "$SCRIPT" --label accepted-status --set "A=echo present" --set "B=grep -q zzz-not-there $FIX/dedupe-blank.txt" --accept-status B=1 >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "0" ] && grep -qF -- '- set: B — status: 1 — lines: 0 — items: 0 — command: ' "$out"; then
  pass "accepted-status: --accept-status B=1 makes grep -q's no-match exit 1 an accepted, recorded status (not a refusal)"
else
  fail "accepted-status: expected exit 0 with the accepted status recorded on B's set line, got rc=$rc"
fi

# =============================================================================
# case: empty-set — a command exiting 0 with no output is a legitimately
# empty set (status 0, lines 0, items 0), never a refusal.
# =============================================================================
out="$T/empty-set.out"
if bash "$SCRIPT" --label empty-set --set "A=cat $FIX/three-a.txt" --set "B=true" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "0" ] && grep -qF -- '- set: B — status: 0 — lines: 0 — items: 0 — command: ' "$out"; then
  pass "empty-set: a command exiting 0 with no output is recorded as status 0 / lines 0 / items 0, not a refusal"
else
  fail "empty-set: expected exit 0 with B recorded as an empty set, got rc=$rc"
fi

# =============================================================================
# case: control-char — an item containing a carriage return (or any other
# control character) refuses the whole derivation (exit 1, empty stdout).
# Uses the committed fixtures/control-char.txt fixture (a literal embedded
# CR byte, not a shell-escape stand-in).
# =============================================================================
out="$T/control-char.out"
if bash "$SCRIPT" --label control-char --set "A=cat $FIX/control-char.txt" --set "B=echo r" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "1" ] && [ ! -s "$out" ]; then
  pass "control-char: an item carrying an embedded control character (fixtures/control-char.txt) refuses the derivation (exit 1, empty stdout)"
else
  fail "control-char: expected exit 1 + empty stdout, got rc=$rc"
fi

# =============================================================================
# case: three-sets — beyond two sets, the partition stays gap-free and
# overlap-free (mixed pairwise/triple overlaps, committed fixtures).
# =============================================================================
out="$T/three-sets.out"
if bash "$SCRIPT" --label three-sets \
  --set "A=cat $FIX/three-a.txt" \
  --set "B=cat $FIX/three-b.txt" \
  --set "C=cat $FIX/three-c.txt" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
union_from_block="$T/three-sets-union-from-block"
grep '^  - ' "$out" | sed 's/^  - //' | LC_ALL=C sort >"$union_from_block"
union_from_fixtures="$T/three-sets-union-from-fixtures"
cat "$FIX/three-a.txt" "$FIX/three-b.txt" "$FIX/three-c.txt" | grep -v '^$' | LC_ALL=C sort -u >"$union_from_fixtures"
if [ "$rc" = "0" ] && cmp -s "$union_from_block" "$union_from_fixtures"; then
  pass "three-sets: three overlapping sets partition gap-free and overlap-free (bucketed items == sort -u of the three fixtures)"
else
  fail "three-sets: expected exit 0 with the bucketed union matching the sort -u oracle, got rc=$rc"
fi

# =============================================================================
# case: locale-pin — the same derivation under LC_ALL=C and under an
# available UTF-8 locale (when one exists) produces byte-identical output,
# over an item set the two collations genuinely disagree on.
# =============================================================================
loc="$(locale -a 2>/dev/null | grep -iE '^(C|en_US|ja_JP)\.utf-?8$' | head -n 1 || true)"
out_c="$T/locale-pin-c.out"
LC_ALL=C bash "$SCRIPT" --label locale-pin --set "A=cat $FIX/locale-pin.txt" --set "B=echo a" >"$out_c" 2>/dev/null
rc_c=$?
if [ -n "$loc" ]; then
  out_u="$T/locale-pin-u.out"
  LC_ALL="$loc" bash "$SCRIPT" --label locale-pin --set "A=cat $FIX/locale-pin.txt" --set "B=echo a" >"$out_u" 2>/dev/null
  rc_u=$?
  if [ "$rc_c" = "0" ] && [ "$rc_u" = "0" ] && cmp -s "$out_c" "$out_u"; then
    pass "locale-pin: LC_ALL=C run and an available UTF-8 locale run ($loc) of the same derivation are byte-identical"
  else
    fail "locale-pin: expected byte-identical output under LC_ALL=C and $loc, got rc_c=$rc_c rc_u=$rc_u"
  fi
else
  fail "locale-pin: no UTF-8 locale available on this host to compare against (fails closed rather than skipping, per AC6)"
fi

# =============================================================================
# case: dedupe-blank — duplicate and blank lines are visible as the gap
# between lines and items rather than silently collapsed.
# =============================================================================
out="$T/dedupe-blank.out"
if bash "$SCRIPT" --label dedupe-blank --set "A=cat $FIX/dedupe-blank.txt" --set "B=echo dup" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
lines_a="$(sed -nE 's/^- set: A — status: [0-9]+ — lines: ([0-9]+) — items: [0-9]+ — command: .*/\1/p' "$out" | head -n 1)"
items_a="$(sed -nE 's/^- set: A — status: [0-9]+ — lines: [0-9]+ — items: ([0-9]+) — command: .*/\1/p' "$out" | head -n 1)"
if [ "$rc" = "0" ] && [ -n "$lines_a" ] && [ -n "$items_a" ] && [ "$((10#$lines_a))" -gt "$((10#$items_a))" ]; then
  pass "dedupe-blank: set A's lines ($lines_a) strictly exceeds its items ($items_a) — duplicates/blanks visible, not silently collapsed"
else
  fail "dedupe-blank: expected lines strictly greater than items for set A, got rc=$rc lines=$lines_a items=$items_a"
fi

# =============================================================================
# case: verbatim-item — item shapes this repository's own populations
# produce (leading space, a line beginning with "- ", an em dash, Japanese
# text, apostrophes, parens, +, brackets, $, *) survive verbatim in the
# emitted block.
# =============================================================================
out="$T/verbatim-item.out"
if bash "$SCRIPT" --label verbatim-item --set "A=cat $FIX/verbatim-item.txt" --set "B=echo star*item" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
verbatim_ok=1
# shellcheck disable=SC2016 # single quotes are intentional here — these are
# literal expected item strings, not expressions meant to expand
for lit in ' leading-space' '- dash item' 'em — dash' '日本語の項目' "quote's-item" 'paren(item)' 'plus+item' 'bracket[item]' 'dollar$item' 'star*item'; do
  grep -qxF -- "  - $lit" "$out" || verbatim_ok=0
done
if [ "$rc" = "0" ] && [ "$verbatim_ok" = "1" ]; then
  pass "verbatim-item: every adversarial item shape (leading space, - -prefixed, em dash, Japanese, apostrophe, parens, +, brackets, \$, *) survives verbatim"
else
  fail "verbatim-item: expected every item shape to survive verbatim, got rc=$rc verbatim_ok=$verbatim_ok"
fi

# =============================================================================
# regression: control character other than CR (a bare bell / 0x07) is also
# refused — the refusal is "any control character", not "CR specifically".
# =============================================================================
out="$T/control-char-bell.out"
if bash "$SCRIPT" --label control-char-bell --set "A=printf 'p\aq\n'" --set "B=echo r" >"$out" 2>/dev/null; then
  rc=0
else
  rc=$?
fi
if [ "$rc" = "1" ] && [ ! -s "$out" ]; then
  pass "control-char: a non-CR control character (0x07) is refused too — the class is 'any control character', not just CR"
else
  fail "control-char: expected exit 1 + empty stdout for a bell character, got rc=$rc"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'derive-populations suite: all assertions passed\n'
  exit 0
else
  printf 'derive-populations suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
