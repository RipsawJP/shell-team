#!/usr/bin/env bash
# run.sh — drive bin/review-gate.sh and assert the deterministic-floor contract
# (T-037 AC5): each floor rule (Codex objection / high severity / any risk-area
# category / low confidence) MUST force `escalate`; a finding clear of every
# floor rule prints `clear` (grey zone -> SKILL LLM); enum typos / missing args
# are hard usage errors (exit 2), never a silent mis-classification.
#
# Pure invocation-based (the helper reads no files), so it needs no fixtures and
# runs in restricted sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GATE="$REPO_ROOT/bin/review-gate.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_out <desc> <expected_exit> <expected_stdout_regex> -- <args...>
assert_out() {
  local desc="$1" exp="$2" pat="$3"; shift 3
  [ "${1:-}" = "--" ] && shift
  local out rc
  set +e
  out="$( bash "$GATE" "$@" 2>&1 )"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (out: $out)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$out" || fail "$desc: stdout missing /$pat/ (out: $out)"
  pass "$desc"
}

# --- the clear (grey-zone) baseline ----------------------------------------
# A benign finding: Codex agrees, minor severity, no risk area, high confidence.
assert_out "benign finding -> clear" 0 '^clear$' -- \
  --objection no --severity minor --risk-area none --confidence high
assert_out "nit + medium confidence -> clear" 0 '^clear$' -- \
  --objection no --severity nit --risk-area none --confidence medium

# --- floor rule 1: Codex objection forces escalate -------------------------
assert_out "objection=yes -> escalate(objection)" 0 '^escalate .*objection' -- \
  --objection yes --severity minor --risk-area none --confidence high

# --- floor rule 2: high severity forces escalate ---------------------------
assert_out "severity=blocker -> escalate(high-severity)" 0 '^escalate .*high-severity' -- \
  --objection no --severity blocker --risk-area none --confidence high
assert_out "severity=major -> escalate(high-severity)" 0 '^escalate .*high-severity' -- \
  --objection no --severity major --risk-area none --confidence high

# --- floor rule 3: EVERY risk-area category forces escalate ----------------
# One assertion per frozen category — this is the "each floor rule escalates"
# guarantee AC5 names.
for cat in architecture security prod db-migration irreversible numeric-accuracy external-docs rca; do
  assert_out "risk-area=$cat -> escalate(risk-area:$cat)" 0 "^escalate .*risk-area:$cat" -- \
    --objection no --severity minor --risk-area "$cat" --confidence high
done

# --- floor rule 4: low confidence forces escalate --------------------------
assert_out "confidence=low -> escalate(low-confidence)" 0 '^escalate .*low-confidence' -- \
  --objection no --severity minor --risk-area none --confidence low

# --- multiple rules fire together: all are named ---------------------------
out="$( bash "$GATE" --objection yes --severity blocker --risk-area security --confidence low 2>&1 )"
for want in objection high-severity 'risk-area:security' low-confidence; do
  grep -qE "$want" <<< "$out" || fail "multi-rule: expected /$want/ in output (out: $out)"
done
pass "multiple floor rules all appear in the escalate reason list"

# --- enum validation: typos are hard errors (exit 2), never a silent clear --
assert_out "bad --objection -> exit 2" 2 '' -- \
  --objection maybe --severity minor --risk-area none --confidence high
assert_out "bad --severity -> exit 2" 2 '' -- \
  --objection no --severity huge --risk-area none --confidence high
assert_out "unknown --risk-area category -> exit 2" 2 '' -- \
  --objection no --severity minor --risk-area frontend --confidence high
assert_out "bad --confidence -> exit 2" 2 '' -- \
  --objection no --severity minor --risk-area none --confidence unsure

# --- missing required attributes are usage errors --------------------------
assert_out "missing --confidence -> exit 2" 2 '' -- \
  --objection no --severity minor --risk-area none
assert_out "no args -> exit 2" 2 ''

# --- arg handling ----------------------------------------------------------
assert_out "unknown flag -> exit 2" 2 '' -- --bogus
assert_out "--objection without value -> exit 2" 2 '' -- --objection
assert_out "--help -> exit 0" 0 'Usage:' -- --help

printf '\nAll review-gate assertions passed.\n'
