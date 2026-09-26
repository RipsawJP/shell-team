#!/usr/bin/env bash
# run.sh — lock suite proving every tracked bin/ entry answers `--help` and
# `-h` as its first argument with exit 0 and non-empty stdout, without
# reading stdin or writing into its own (empty) working directory (T-1157,
# GitHub issue #592: 14 of 55 bin/*.sh scripts used to answer `--help` with a
# usage error instead of usage).
#
# Population source (the precedent is tests/bin-exec-bit/run.sh's DP2/DP3):
# `git ls-files -- bin/`, NEVER a `bin/*.sh` glob — a glob would silently miss
# the extension-less, already-armed `bin/install`. Empty or unavailable `git`
# output fails closed, never read as a clean zero-violation result.
#
# Each case runs the member with the flag as its ONLY argument, stdin
# redirected from /dev/null, from a fresh EMPTY scratch directory under
# $TMPDIR, and asserts the directory is still empty afterwards
# (`find … -mindepth 1`) — a member that writes into its own cwd before
# reaching a --help arm (or before printing usage at all) is caught here.
#
# This lock has no adopter-facing surface: it is this repository's own
# suite, reached by one CI step and one shellcheck line, never a new bin/
# script.
#
# Whether removing one member's --help/-h arm turns this suite red (the
# suite's own mutation self-check) is exercised by whoever changes it, in a
# scratch copy — never against this tracked tree.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# =============================================================================
# The population, re-derived here (never inherited from a caller):
# `git -C "$REPO_ROOT" ls-files -- bin/`. Empty/unavailable output fails
# closed rather than reading as a clean zero-member population.
# =============================================================================
git_rc=0
POP="$(git -C "$REPO_ROOT" ls-files -- bin/ 2>/dev/null)" || git_rc=$?
if [ "$git_rc" -ne 0 ] || [ -z "$POP" ]; then
  fail "population source: git -C \"\$REPO_ROOT\" ls-files -- bin/ produced empty/unavailable output or exited non-zero (rc=$git_rc) — fails closed, never read as a clean zero-violation result"
  printf '\nbin-help suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi

n_total="$(printf '%s\n' "$POP" | grep -c . || true)"
pass "population $n_total tracked entries under bin/ (population source: git ls-files -- bin/), non-empty"

SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/t1157-bin-help.XXXXXX")"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$SCRATCH_ROOT"; }
trap cleanup EXIT

while IFS= read -r member; do
  [ -n "$member" ] || continue
  for flag in --help -h; do
    dir="$(mktemp -d "$SCRATCH_ROOT/case.XXXXXX")"
    out="$SCRATCH_ROOT/out.$$"
    err="$SCRATCH_ROOT/err.$$"
    rc=0
    (
      cd "$dir" && bash "$REPO_ROOT/$member" "$flag" </dev/null >"$out" 2>"$err"
    ) || rc=$?
    remaining="$(find "$dir" -mindepth 1 2>/dev/null || true)"
    if [ "$rc" -eq 0 ] && [ -s "$out" ] && [ -z "$remaining" ]; then
      pass "$member $flag exits 0 with non-empty stdout, and its empty scratch cwd is still empty afterwards"
    else
      out_size="$(wc -c <"$out" 2>/dev/null || printf '?')"
      fail "$member $flag: rc=$rc stdout_bytes=$out_size leftover_in_cwd=${remaining:-none} stderr=$(cat "$err" 2>/dev/null || true)"
    fi
    rm -rf "$dir" "$out" "$err"
  done
done <<<"$POP"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'bin-help suite: all assertions passed\n'
  exit 0
else
  printf 'bin-help suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
