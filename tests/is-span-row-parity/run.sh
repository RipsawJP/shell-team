#!/usr/bin/env bash
# run.sh — one shared fixture set proving bin/rollup-runs.sh's and
# bin/cluster-failures.sh's independently-maintained `is_span_row()` copies
# (T-1011 hazard H4: deliberately duplicated, no shared helper) still agree
# (T-1019, GitHub issue #80, the regression half of that hazard).
#
# Black-box only (D3): both real scripts are invoked by path, over one row per
# fixture, and their stdout is read — never a `sed`-extracted function body,
# never any dynamic command construction. D1's frozen oracle, over a one-row
# fixture:
#   counted ⇔ rollup-runs.sh's stdout contains "spans: 1" AND
#              cluster-failures.sh's stdout contains "count=1"
#   skipped ⇔ rollup-runs.sh's stdout is exactly "(no runs found)" AND
#              cluster-failures.sh's stdout is exactly "(no failure clusters found)"
# Every probe row is a FAILING span ("status":"error") so the cluster
# consumer's own "only a failing span is surfaced" behavior cannot make a
# skipped-vs-counted difference invisible (D1).
#
# Each of D4's six classes is asserted three times: the frozen expected answer
# against bin/rollup-runs.sh, the frozen expected answer against
# bin/cluster-failures.sh, and a parity comparison between the two. A
# divergence names the drifted script and the fixture's basename (D5); an
# observation that is neither "counted" nor "skipped" (unexpected stdout, or a
# non-zero exit) is a failure of that consumer, never a skip.
#
# This task changes no `bin/` file (Non-goals) — proving the two existing
# copies still agree is the whole point, not making them agree via a shared
# helper (H4's rationale stands).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ROLLUP="$REPO_ROOT/bin/rollup-runs.sh"
CLUSTER="$REPO_ROOT/bin/cluster-failures.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# classify_rollup <file> — prints "counted" | "skipped" | "other", measured
# against the real bin/rollup-runs.sh (D1's frozen oracle, rollup half).
classify_rollup() {
  local file="$1" out rc
  set +e
  out="$(bash "$ROLLUP" "$file" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    printf 'other'
    return 0
  fi
  if printf '%s\n' "$out" | grep -qF -- 'spans: 1'; then
    printf 'counted'
  elif [ "$out" = '(no runs found)' ]; then
    printf 'skipped'
  else
    printf 'other'
  fi
}

# classify_cluster <file> — same, against the real bin/cluster-failures.sh
# (D1's frozen oracle, cluster half).
classify_cluster() {
  local file="$1" out rc
  set +e
  out="$(bash "$CLUSTER" "$file" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    printf 'other'
    return 0
  fi
  if printf '%s\n' "$out" | grep -qF -- 'count=1'; then
    printf 'counted'
  elif [ "$out" = '(no failure clusters found)' ]; then
    printf 'skipped'
  else
    printf 'other'
  fi
}

# assert_parity <id> <fixture-basename> <expected: counted|skipped>
#
# Three checks per D4/D5: the frozen expected answer against each consumer
# independently, then a parity comparison between the two. A divergence names
# the drifted script and the fixture; disagreement between the two consumers
# names both.
assert_parity() {
  local id="$1" fixture="$2" expected="$3"
  local file="$FIX/$fixture" rc_class cc_class
  rc_class="$(classify_rollup "$file")"
  cc_class="$(classify_cluster "$file")"
  [ "$rc_class" = "$expected" ] || fail "$id: bin/rollup-runs.sh $fixture: expected $expected, got $rc_class"
  [ "$cc_class" = "$expected" ] || fail "$id: bin/cluster-failures.sh $fixture: expected $expected, got $cc_class"
  [ "$rc_class" = "$cc_class" ] || fail "$id: parity divergence on $fixture: bin/rollup-runs.sh=$rc_class bin/cluster-failures.sh=$cc_class"
  pass "$id ($expected, bin/rollup-runs.sh and bin/cluster-failures.sh agree)"
}

# --- D4's six classes, one row per file, in table order ---
assert_parity "parity-valid-span"     "valid-span.jsonl"     "counted"
assert_parity "parity-kind-absent"    "kind-absent.jsonl"    "counted"
assert_parity "parity-kind-span"      "kind-span.jsonl"      "counted"
assert_parity "parity-kind-event"     "kind-event.jsonl"     "skipped"
assert_parity "parity-kind-unknown"   "kind-unknown.jsonl"   "skipped"
assert_parity "parity-kind-malformed" "kind-malformed.jsonl" "skipped"

printf '\nAll is-span-row-parity assertions passed.\n'
