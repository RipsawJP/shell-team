#!/usr/bin/env bash
# run.sh — drive bin/check-design-note.sh against fixtures and assert the
# documented behavior (T-033 acceptance criteria):
#   - a canonical note passes (exit 0); a degraded note that still carries the
#     required sections passes
#   - empty / whitespace-only / banner-only / missing-required-section / a
#     required heading appearing only in prose each fail (exit 1)
#   - --task: matching id passes, stale (wrong-id) note fails, missing Task line
#     fails; without --task the id check is skipped
#   - a missing note is exit 1 (gate failure, not usage); bad args are exit 2

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="$REPO_ROOT/bin/check-design-note.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <stderr_grep|""> <args...>
assert_rc() {
  local desc="$1" exp="$2" pat="$3"; shift 3
  local err rc
  set +e
  err="$(bash "$CHECK" "$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  pass "$desc (exit $rc)"
}

# --- valid notes ----------------------------------------------------------
assert_rc "pass-canonical -> 0"              0 "" "$FIX/pass-canonical.md"
assert_rc "pass-canonical --task match -> 0" 0 "" "$FIX/pass-canonical.md" --task T-033
assert_rc "pass-degraded (banner+sections) -> 0" 0 "" "$FIX/pass-degraded.md" --task T-033

# --- hollow / structureless notes ----------------------------------------
assert_rc "fail-empty -> 1"            1 "empty or whitespace-only"        "$FIX/fail-empty.md"
assert_rc "fail-whitespace -> 1"       1 "empty or whitespace-only"        "$FIX/fail-whitespace.md"
assert_rc "fail-banner-only -> 1"      1 "missing required section"        "$FIX/fail-banner-only.md"
assert_rc "fail-missing-acceptance->1" 1 "Acceptance hooks"                "$FIX/fail-missing-acceptance.md"
# A required heading appearing only in prose (not line-anchored) must not count.
assert_rc "prose-not-heading -> 1"     1 "missing required section"        "$FIX/prose-not-heading.md"

# --- stale-note guard via --task -----------------------------------------
assert_rc "fail-stale-task --task -> 1" 1 "does not match --task T-033"     "$FIX/fail-stale-task.md" --task T-033
assert_rc "fail-no-task --task -> 1"    1 "no 'Task: T-NNN'"               "$FIX/fail-no-task.md" --task T-033
# M-1 guard: a stale note (header T-031) that merely *mentions* the target id in
# prose must NOT pass --task T-033 — only the first line-anchored Task: line counts.
assert_rc "stale + prose-mention --task -> 1" 1 "does not match --task T-033" "$FIX/fail-stale-with-prose-mention.md" --task T-033
# Without --task, a structurally-valid note passes even if its id is "stale".
assert_rc "stale note, no --task -> 0"  0 ""                               "$FIX/fail-stale-task.md"

# --- missing note is a gate failure (exit 1), not usage ------------------
assert_rc "missing note -> 1"          1 "not found"                       "$FIX/does-not-exist.md"

# --- argument errors are exit 2 ------------------------------------------
assert_rc "no args -> 2"               2 "usage"
assert_rc "unknown flag -> 2"          2 "unknown flag"                    "$FIX/pass-canonical.md" --bogus
assert_rc "--task without value -> 2"  2 "usage"                           "$FIX/pass-canonical.md" --task
assert_rc "--task bad format -> 2"     2 "T-NNN"                           "$FIX/pass-canonical.md" --task nope

printf '\nAll check-design-note assertions passed.\n'
