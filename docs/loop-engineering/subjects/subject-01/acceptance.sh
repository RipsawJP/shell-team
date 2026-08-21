#!/usr/bin/env bash
# acceptance.sh — subject-01's acceptance oracle.
#
# Usage: acceptance.sh <venue-dir>
#
# Builds its own CSV fixtures under a private scratch directory, runs the
# venue's candidate CLI (resolved from this file's own committed manifest,
# never from any copy sitting inside the venue) against each fixture, and
# reports one PASS/FAIL line per case plus a summary line. Exits 0 only when
# every case passed. This oracle is expected to run unmodified against a
# freshly regenerated, candidate-free venue and to fail there — every case
# fails when nothing has been implemented yet; that is the "genuinely
# unimplemented" property this subject's own brief names, by design, and it
# is never wired into a CI step for exactly that reason.
#
# Every case below compares BOTH stdout and stderr byte-exactly against a
# fixed expectation (via cmp, or an explicit empty-stream assertion) rather
# than a substring match — a candidate that prints one extra debug line on
# either stream, on top of otherwise-correct output, fails the case that
# covers it. This is the interface contract's own frozen rule
# (`interface.md`'s `interface-frozen` line: "must reproduce every declared
# stdout byte, stderr byte and exit code exactly"), enforced here rather
# than merely stated.
set -uo pipefail

usage() {
  printf 'usage: %s <venue-dir>\n' "${0##*/}" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

venue="$1"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest="$here/manifest.txt"

if [ ! -r "$manifest" ]; then
  printf 'error: cannot read %s\n' "$manifest" >&2
  exit 2
fi

cli_rel="$(sed -nE 's/^candidate-path: (cli\/.+)$/\1/p' "$manifest" | head -n 1)"
if [ -z "$cli_rel" ]; then
  printf 'error: manifest names no cli/ candidate path\n' >&2
  exit 2
fi
cli="$venue/$cli_rel"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/subject01-acc.XXXXXX")" || {
  printf 'error: mktemp failed\n' >&2
  exit 1
}
trap 'rm -rf "$scratch"' EXIT

passed=0
failed=0

pass() {
  printf 'PASS: %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  failed=$((failed + 1))
}

run_cli() {
  # run_cli <fixture-file> <out-file> <err-file> — prints the exit status.
  bash "$cli" "$1" > "$2" 2> "$3"
  printf '%s' "$?"
}

empty_ok() {
  # empty_ok <file> — true iff the file is absent or zero-length.
  [ ! -s "$1" ]
}

# --- case1: a missing input path exits 2; stdout empty, stderr exactly one
# line naming the path. ---
missing="$scratch/does-not-exist.csv"
out="$scratch/c1.out"
err="$scratch/c1.err"
rc="$(run_cli "$missing" "$out" "$err")"
werr1="$scratch/c1.werr"
printf 'error: cannot read %s\n' "$missing" > "$werr1"
if [ "$rc" = "2" ] && empty_ok "$out" && cmp -s "$err" "$werr1"; then
  pass "case1-missing-file"
else
  fail "case1-missing-file"
fi

# --- case2: a well-formed all-numeric CSV produces the exact summary;
# stderr must be empty (no spurious diagnostics on a clean run). ---
f2="$scratch/c2.csv"
{
  printf 'age,score\n'
  printf '10,100\n'
  printf '20,50\n'
  printf '30,75\n'
} > "$f2"
out="$scratch/c2.out"
err="$scratch/c2.err"
rc="$(run_cli "$f2" "$out" "$err")"
want2="$scratch/c2.want"
{
  printf 'column=age count=3 sum=60 min=10 max=30 avg=20\n'
  printf 'column=score count=3 sum=225 min=50 max=100 avg=75\n'
} > "$want2"
if [ "$rc" = "0" ] && cmp -s "$out" "$want2" && empty_ok "$err"; then
  pass "case2-valid-numeric-columns"
else
  fail "case2-valid-numeric-columns"
fi

# --- case3: one field-count-mismatched row is skipped and excluded;
# stderr holds exactly the one skip line, nothing else. ---
f3="$scratch/c3.csv"
{
  printf 'age,score\n'
  printf '10,100\n'
  printf '20\n'
  printf '30,75\n'
} > "$f3"
out="$scratch/c3.out"
err="$scratch/c3.err"
rc="$(run_cli "$f3" "$out" "$err")"
want3="$scratch/c3.want"
{
  printf 'column=age count=2 sum=40 min=10 max=30 avg=20\n'
  printf 'column=score count=2 sum=175 min=75 max=100 avg=87\n'
} > "$want3"
werr3="$scratch/c3.werr"
printf 'skip: row 2 field-count-mismatch\n' > "$werr3"
if [ "$rc" = "0" ] && cmp -s "$out" "$want3" && cmp -s "$err" "$werr3"; then
  pass "case3-malformed-row-skipped"
else
  fail "case3-malformed-row-skipped"
fi

# --- case4: a header-only file has zero usable rows; stdout empty, stderr
# exactly the one error line. ---
f4="$scratch/c4.csv"
printf 'age,score\n' > "$f4"
out="$scratch/c4.out"
err="$scratch/c4.err"
rc="$(run_cli "$f4" "$out" "$err")"
werr4="$scratch/c4.werr"
printf 'error: no data rows\n' > "$werr4"
if [ "$rc" = "1" ] && empty_ok "$out" && cmp -s "$err" "$werr4"; then
  pass "case4-no-data-rows"
else
  fail "case4-no-data-rows"
fi

# --- case5: a non-numeric column is silently omitted, not reported;
# stderr empty (omission is not an error). ---
f5="$scratch/c5.csv"
{
  printf 'name,score\n'
  printf 'alice,10\n'
  printf 'bob,20\n'
} > "$f5"
out="$scratch/c5.out"
err="$scratch/c5.err"
rc="$(run_cli "$f5" "$out" "$err")"
want5="$scratch/c5.want"
printf 'column=score count=2 sum=30 min=10 max=20 avg=15\n' > "$want5"
if [ "$rc" = "0" ] && cmp -s "$out" "$want5" && empty_ok "$err"; then
  pass "case5-non-numeric-column-omitted"
else
  fail "case5-non-numeric-column-omitted"
fi

# --- case6: header order is preserved even when the numeric column comes
# first and the non-numeric one follows; stderr empty. ---
f6="$scratch/c6.csv"
{
  printf 'score,name\n'
  printf '5,alice\n'
  printf '7,bob\n'
} > "$f6"
out="$scratch/c6.out"
err="$scratch/c6.err"
rc="$(run_cli "$f6" "$out" "$err")"
want6="$scratch/c6.want"
printf 'column=score count=2 sum=12 min=5 max=7 avg=6\n' > "$want6"
if [ "$rc" = "0" ] && cmp -s "$out" "$want6" && empty_ok "$err"; then
  pass "case6-header-order-preserved"
else
  fail "case6-header-order-preserved"
fi

# --- case7: every usable column is non-numeric, but the exit is still 0;
# both streams empty. ---
f7="$scratch/c7.csv"
{
  printf 'name\n'
  printf 'alice\n'
  printf 'bob\n'
} > "$f7"
out="$scratch/c7.out"
err="$scratch/c7.err"
rc="$(run_cli "$f7" "$out" "$err")"
if [ "$rc" = "0" ] && empty_ok "$out" && empty_ok "$err"; then
  pass "case7-zero-numeric-columns-still-exits-zero"
else
  fail "case7-zero-numeric-columns-still-exits-zero"
fi

# --- case8: every data row is field-count-mismatched (not merely a
# header-only file) — subject-ac 4's general "zero usable rows remain"
# clause, exercised on its non-header-only instance. Every mismatched row
# still gets its own skip line, in order, before the final no-data-rows
# error. ---
f8="$scratch/c8.csv"
{
  printf 'age,score\n'
  printf '10\n'
  printf '20,30,40\n'
} > "$f8"
out="$scratch/c8.out"
err="$scratch/c8.err"
rc="$(run_cli "$f8" "$out" "$err")"
werr8="$scratch/c8.werr"
{
  printf 'skip: row 1 field-count-mismatch\n'
  printf 'skip: row 2 field-count-mismatch\n'
  printf 'error: no data rows\n'
} > "$werr8"
if [ "$rc" = "1" ] && empty_ok "$out" && cmp -s "$err" "$werr8"; then
  pass "case8-all-rows-mismatched"
else
  fail "case8-all-rows-mismatched"
fi

# --- case9: negative integers are numeric (the pattern's own leading
# minus), and avg truncates toward zero on a negative quotient where that
# differs from floor: sum=-7, count=2 -> -3.5 -> -3 (truncation), not -4
# (floor). ---
f9="$scratch/c9.csv"
{
  printf 'delta\n'
  printf -- '-3\n'
  printf -- '-4\n'
} > "$f9"
out="$scratch/c9.out"
err="$scratch/c9.err"
rc="$(run_cli "$f9" "$out" "$err")"
want9="$scratch/c9.want"
printf 'column=delta count=2 sum=-7 min=-4 max=-3 avg=-3\n' > "$want9"
if [ "$rc" = "0" ] && cmp -s "$out" "$want9" && empty_ok "$err"; then
  pass "case9-negative-integers-truncate-toward-zero"
else
  fail "case9-negative-integers-truncate-toward-zero"
fi

# --- case10: a value with LEADING whitespace fails the frozen pattern
# (`^-?[0-9]+$`, no leading/trailing whitespace) and makes its whole column
# non-numeric, silently omitted — while a sibling clean column is still
# reported, proving the rejection is per-column, not a whole-row wipeout. ---
f10="$scratch/c10.csv"
{
  printf 'id,val\n'
  printf ' 10,5\n'
  printf '20,6\n'
}> "$f10"
out="$scratch/c10.out"
err="$scratch/c10.err"
rc="$(run_cli "$f10" "$out" "$err")"
want10="$scratch/c10.want"
printf 'column=val count=2 sum=11 min=5 max=6 avg=5\n' > "$want10"
if [ "$rc" = "0" ] && cmp -s "$out" "$want10" && empty_ok "$err"; then
  pass "case10-leading-whitespace-rejected"
else
  fail "case10-leading-whitespace-rejected"
fi

# --- case11: a value with TRAILING whitespace likewise fails the frozen
# pattern; the sibling clean column is still reported. ---
f11="$scratch/c11.csv"
{
  printf 'id,val\n'
  printf '10,5 \n'
  printf '20,6\n'
} > "$f11"
out="$scratch/c11.out"
err="$scratch/c11.err"
rc="$(run_cli "$f11" "$out" "$err")"
want11="$scratch/c11.want"
printf 'column=id count=2 sum=30 min=10 max=20 avg=15\n' > "$want11"
if [ "$rc" = "0" ] && cmp -s "$out" "$want11" && empty_ok "$err"; then
  pass "case11-trailing-whitespace-rejected"
else
  fail "case11-trailing-whitespace-rejected"
fi

printf 'acceptance: %d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
