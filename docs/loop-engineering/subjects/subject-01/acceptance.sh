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

# --- case1: a missing input path exits 2 and names the path on stderr. ---
missing="$scratch/does-not-exist.csv"
out="$scratch/c1.out"
err="$scratch/c1.err"
rc="$(run_cli "$missing" "$out" "$err")"
if [ "$rc" = "2" ] && grep -qF "error: cannot read $missing" "$err"; then
  pass "case1-missing-file"
else
  fail "case1-missing-file"
fi

# --- case2: a well-formed all-numeric CSV produces the exact summary. ---
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
if [ "$rc" = "0" ] && cmp -s "$out" "$want2"; then
  pass "case2-valid-numeric-columns"
else
  fail "case2-valid-numeric-columns"
fi

# --- case3: a field-count-mismatched row is skipped and excluded. ---
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
if [ "$rc" = "0" ] && cmp -s "$out" "$want3" && grep -qF 'skip: row 2 field-count-mismatch' "$err"; then
  pass "case3-malformed-row-skipped"
else
  fail "case3-malformed-row-skipped"
fi

# --- case4: a header-only file has zero usable rows. ---
f4="$scratch/c4.csv"
printf 'age,score\n' > "$f4"
out="$scratch/c4.out"
err="$scratch/c4.err"
rc="$(run_cli "$f4" "$out" "$err")"
if [ "$rc" = "1" ] && grep -qF 'error: no data rows' "$err" && [ ! -s "$out" ]; then
  pass "case4-no-data-rows"
else
  fail "case4-no-data-rows"
fi

# --- case5: a non-numeric column is silently omitted, not reported. ---
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
if [ "$rc" = "0" ] && cmp -s "$out" "$want5"; then
  pass "case5-non-numeric-column-omitted"
else
  fail "case5-non-numeric-column-omitted"
fi

# --- case6: header order is preserved even when the numeric column comes
# first and the non-numeric one follows. ---
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
if [ "$rc" = "0" ] && cmp -s "$out" "$want6"; then
  pass "case6-header-order-preserved"
else
  fail "case6-header-order-preserved"
fi

# --- case7: every usable column is non-numeric, but the exit is still 0. ---
f7="$scratch/c7.csv"
{
  printf 'name\n'
  printf 'alice\n'
  printf 'bob\n'
} > "$f7"
out="$scratch/c7.out"
err="$scratch/c7.err"
rc="$(run_cli "$f7" "$out" "$err")"
if [ "$rc" = "0" ] && [ ! -s "$out" ]; then
  pass "case7-zero-numeric-columns-still-exits-zero"
else
  fail "case7-zero-numeric-columns-still-exits-zero"
fi

printf 'acceptance: %d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
