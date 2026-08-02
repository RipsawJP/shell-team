#!/usr/bin/env bash
# run.sh — drive bin/rollup-runs.sh against fixtures and assert the documented
# behavior (T-020 acceptance criteria):
#   - a clean multi-span run summarizes with the ✓ flag, correct counts/sums   [AC1]
#   - an error/FAIL run gets the ⚠ flag                                         [AC1]
#   - nullable tokens/duration mark the total "(partial)"                       [AC3]
#   - multiple run_ids in one file produce one block each                       [AC2]
#   - empty input prints "(no runs found)" and exits 0
#   - no args / unreadable file are usage errors (exit 2)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ROLLUP="$REPO_ROOT/bin/rollup-runs.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <file...>
assert_rc() {
  local desc="$1" exp="$2"; shift 2
  local rc
  set +e
  bash "$ROLLUP" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc"
  pass "$desc (exit $rc)"
}

# assert_out <desc> <pattern> <file...>  — guard exits 0 and stdout matches /pattern/
assert_out() {
  local desc="$1" pat="$2"; shift 2
  local out rc
  set +e
  out="$(bash "$ROLLUP" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "$desc: expected exit 0, got $rc"
  grep -qE "$pat" <<< "$out" || fail "$desc: stdout missing /$pat/ (got: $out)"
  pass "$desc"
}

# --- clean run (AC1): ✓ flag, counts, sums, window ---
assert_out "clean: ✓ flag"            'run RUN-CLEAN .*✓'           "$FIX/clean.jsonl"
assert_out "clean: 4 spans"           'spans: 4'                    "$FIX/clean.jsonl"
assert_out "clean: phases in order"   'phases: plan implement validate review' "$FIX/clean.jsonl"
assert_out "clean: status success=4" 'status: success=4'           "$FIX/clean.jsonl"
assert_out "clean: verdicts"          'verdict: PASS=1 APPROVE=1'   "$FIX/clean.jsonl"
assert_out "clean: token sum 1000"    'tokens: 1000   duration: 10000ms' "$FIX/clean.jsonl"
assert_out "clean: window"            'window: 2026-06-13T00:00:01Z → 2026-06-13T00:00:04Z' "$FIX/clean.jsonl"

# --- error/FAIL run (AC1): ⚠ flag ---
assert_out "mixed: ⚠ flag"            'run RUN-BAD .*⚠'             "$FIX/mixed.jsonl"
assert_out "mixed: status breakdown"  'status: success=1 error=1'   "$FIX/mixed.jsonl"
assert_out "mixed: FAIL verdict"      'verdict: FAIL=1'             "$FIX/mixed.jsonl"

# --- null fields (AC3): partial markers ---
assert_out "nulls: token partial"     'tokens: 200 \(partial\)'     "$FIX/nulls.jsonl"
assert_out "nulls: duration partial"  'duration: 2000ms \(partial\)' "$FIX/nulls.jsonl"

# --- multiple run_ids (AC2): one block each ---
multi_out="$(bash "$ROLLUP" "$FIX/multi-run.jsonl" 2>/dev/null)"
blocks="$(grep -c '^run ' <<< "$multi_out")"
[ "$blocks" -eq 2 ] || fail "multi-run: expected 2 run blocks, got $blocks"
pass "multi-run: 2 run blocks (RUN-A, RUN-B)"

# --- cross-file grouping (AC2): same run_id split across two files folds into one block ---
cross="$(bash "$ROLLUP" "$FIX/clean.jsonl" "$FIX/clean.jsonl" 2>/dev/null)"
cross_blocks="$(grep -c '^run ' <<< "$cross")"
[ "$cross_blocks" -eq 1 ] || fail "cross-file: same run_id across files should yield 1 block, got $cross_blocks"
grep -qE 'spans: 8' <<< "$cross" || fail "cross-file: expected 8 spans (4+4), got: $cross"
pass "cross-file: same run_id across two files folds to 1 block, spans summed"

# --- empty input -> "(no runs found)", exit 0 ---
assert_out "empty: no runs found"     '\(no runs found\)'           "$FIX/empty.jsonl"

# --- T-1011 AC30: an event-row-bearing input rolls up byte-identical to the
# same run with the event rows removed — the invariance property, defended
# here by this repo's own CI, not only by T-1011's spec `check:` lines. ---
events_out="$(bash "$ROLLUP" "$FIX/with-events.jsonl" 2>/dev/null)"
clean_out="$(bash "$ROLLUP" "$FIX/clean.jsonl" 2>/dev/null)"
[ "$events_out" = "$clean_out" ] || fail "with-events: rollup output changed by event rows (T-1011 regression)"
pass "with-events: event rows (T-1011) are skipped, output identical to the span-only run"

# --- usage errors ---
assert_rc "no args -> 2"          2
assert_rc "unreadable file -> 2"  2 "$FIX/does-not-exist.jsonl"

printf '\nAll rollup-runs assertions passed.\n'
