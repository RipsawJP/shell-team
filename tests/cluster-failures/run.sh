#!/usr/bin/env bash
# run.sh — drive bin/cluster-failures.sh against fixtures and assert the
# documented behavior (T-044 acceptance criteria):
#   - a signature repeated across 3+ separate run_ids clusters into one line,
#     ranked by descending count, with the first-seen run_id as representative [AC1]
#   - a count tie is broken by first-seen order (deterministic, no hidden sort) [AC1]
#   - verdict wins over status when a span carries both (Design decision (c))  [AC1]
#   - no failing spans -> "(no failure clusters found)" sentinel, exit 0
#   - null/missing phase / run_id fields degrade to "?" without crashing        [AC1]
#   - empty input -> the same sentinel, exit 0
#   - no args / unreadable file are usage errors (exit 2)
#   - propose-only: tasks/todo.md is byte-unchanged across a run, no `gh` call  [AC3]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CLUSTER="$REPO_ROOT/bin/cluster-failures.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <file...>
assert_rc() {
  local desc="$1" exp="$2"; shift 2
  local rc
  set +e
  bash "$CLUSTER" "$@" >/dev/null 2>&1
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
  out="$(bash "$CLUSTER" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "$desc: expected exit 0, got $rc"
  grep -qE "$pat" <<< "$out" || fail "$desc: stdout missing /$pat/ (got: $out)"
  pass "$desc"
}

# --- AC1: no failing spans -> sentinel, exit 0 ---
assert_out "clean: sentinel"                '\(no failure clusters found\)' "$FIX/clean.jsonl"

# --- AC1: signature repeated across 3+ separate run_ids clusters into one line ---
multi_out="$(bash "$CLUSTER" "$FIX/multi-run.jsonl" 2>/dev/null)"
lines="$(grep -c '^cluster ' <<< "$multi_out")"
[ "$lines" -eq 2 ] || fail "multi-run: expected 2 cluster lines, got $lines"
pass "multi-run: 2 distinct clusters (IMPLEMENT:ERROR, REVIEW:REQUEST_CHANGES)"

assert_out "multi-run: recurring signature count=3"     '^cluster IMPLEMENT:ERROR  count=3  run RUN-A$'          "$FIX/multi-run.jsonl"
assert_out "multi-run: singleton signature count=1"     '^cluster REVIEW:REQUEST_CHANGES  count=1  run RUN-B$'   "$FIX/multi-run.jsonl"

# ranked by descending count: the count=3 cluster must appear before the count=1 one
first_line="$(head -n1 <<< "$multi_out")"
grep -qE '^cluster IMPLEMENT:ERROR' <<< "$first_line" \
  || fail "multi-run: expected the higher-count cluster first, got: $first_line"
pass "multi-run: descending-count ranking (IMPLEMENT:ERROR before REVIEW:REQUEST_CHANGES)"

# --- cross-file grouping: same signature split across two files still clusters ---
cross="$(bash "$CLUSTER" "$FIX/multi-run.jsonl" "$FIX/multi-run.jsonl" 2>/dev/null)"
grep -qE '^cluster IMPLEMENT:ERROR  count=6  run RUN-A$' <<< "$cross" \
  || fail "cross-file: expected IMPLEMENT:ERROR count=6 (3+3) across two files, got: $cross"
pass "cross-file: same signature across two files sums counts, keeps first-seen run_id"

# --- AC1: count tie broken by first-seen order, not alphabetical / hidden sort ---
tie_out="$(bash "$CLUSTER" "$FIX/tie-break.jsonl" 2>/dev/null)"
tie_first="$(head -n1 <<< "$tie_out")"
tie_second="$(sed -n '2p' <<< "$tie_out")"
grep -qE '^cluster IMPLEMENT:TIMEOUT  count=2  run RUN-X1$' <<< "$tie_first" \
  || fail "tie-break: expected IMPLEMENT:TIMEOUT (first-seen) ranked first, got: $tie_first"
grep -qE '^cluster REVIEW:FAIL  count=2  run RUN-X2$' <<< "$tie_second" \
  || fail "tie-break: expected REVIEW:FAIL (second-seen) ranked second, got: $tie_second"
pass "tie-break: equal counts ranked by first-seen order (deterministic)"

# --- Design decision (c): verdict wins over status when a span carries both ---
assert_out "verdict-priority: signature uses verdict, not status" \
  '^cluster VALIDATE:FAIL  count=1  run RUN-VP$' "$FIX/verdict-priority.jsonl"
vp_out="$(bash "$CLUSTER" "$FIX/verdict-priority.jsonl" 2>/dev/null)"
grep -qE 'VALIDATE:ERROR' <<< "$vp_out" \
  && fail "verdict-priority: signature must not fall back to status when verdict wins"
pass "verdict-priority: status-based signature correctly suppressed"

# --- AC1: null/missing phase and run_id degrade to '?' without crashing ---
assert_out "nulls: missing phase -> '?' signature"   '^cluster \?:ERROR  count=1  run \?$'          "$FIX/nulls.jsonl"
assert_out "nulls: present phase still clusters"     '^cluster IMPLEMENT:STOPPED  count=1  run RUN-NULL2$' "$FIX/nulls.jsonl"

# --- empty input -> sentinel, exit 0 ---
assert_out "empty: no failure clusters found"  '\(no failure clusters found\)' "$FIX/empty.jsonl"

# --- T-1011 AC30: event rows whose `label` mimics failing verdict tokens
# (REQUEST_CHANGES, FAIL) must not create a cluster — `label` is not a
# verdict field, and the fail-safe skip rule keeps output identical to the
# span-only run (defended here by this repo's own CI, not only by T-1011's
# spec `check:` lines). ---
grep -qF -- '"label":"REQUEST_CHANGES"' "$FIX/with-events.jsonl" \
  || fail "with-events fixture: expected a REQUEST_CHANGES-shaped label"
assert_out "with-events: no failure clusters found (labels are not verdicts)" \
  '\(no failure clusters found\)' "$FIX/with-events.jsonl"
pass "with-events: event rows (T-1011) with failing-shaped labels create no cluster"

# --- usage errors ---
assert_rc "no args -> 2"          2
assert_rc "unreadable file -> 2"  2 "$FIX/does-not-exist.jsonl"

# --- AC3: propose-only — never writes the resolved board, never calls gh ---
# Hermetic form: a temp base holding a copy of the shipped board template (see
# the same guard in tests/consolidate-proposals/run.sh).
BOARD_BASE="$(mktemp -d "${TMPDIR:-/tmp}/cluster-board.XXXXXX")"
cp "$REPO_ROOT/templates/todo-template.md" "$BOARD_BASE/todo.md"
before="$(cksum "$BOARD_BASE/todo.md")"
TEAM_RUN_BASE="$BOARD_BASE" bash "$CLUSTER" "$FIX/multi-run.jsonl" "$FIX/tie-break.jsonl" "$FIX/nulls.jsonl" >/dev/null
after="$(cksum "$BOARD_BASE/todo.md")"
[ "$before" = "$after" ] || fail "AC3: the resolved board changed across a run"
rm -rf "$BOARD_BASE"
pass "AC3: resolved board byte-unchanged (propose-only)"

grep -vE '^[[:space:]]*#' "$CLUSTER" | grep -qE '\bgh\b' \
  && fail "AC3: bin/cluster-failures.sh must never invoke gh"
pass "AC3: no gh invocation in bin/cluster-failures.sh"

printf '\nAll cluster-failures assertions passed.\n'
