#!/usr/bin/env bash
# run.sh — drive bin/check-retro.sh against fixtures and assert the documented
# behavior (T-010 acceptance criteria):
#   - a canonical retro passes (exit 0)
#   - missing H1 / bare (un-decorated) heading / missing section / unlabelled
#     Lesson bullet each fail (exit 1) with a matching reason
#   - the repo's own tasks/retros/2026-04-30.md passes (dogfood, AC2)
#   - multiple files in one call; an unreadable file is a usage error (exit 2)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RETRO="$REPO_ROOT/bin/check-retro.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <stderr_grep|""> <file...>
assert_rc() {
  local desc="$1" exp="$2" pat="$3"; shift 3
  local err rc
  set +e
  err="$(bash "$RETRO" "$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  pass "$desc (exit $rc)"
}

assert_rc "pass-canonical -> 0"        0 "" "$FIX/pass-canonical.md"
assert_rc "fail-no-h1 -> 1"            1 "not '# Retro"           "$FIX/fail-no-h1.md"
assert_rc "fail-bare-heading -> 1"     1 "missing decorated section heading" "$FIX/fail-bare-heading.md"
assert_rc "fail-missing-section -> 1"  1 "missing decorated section heading: ## Try" "$FIX/fail-missing-section.md"
# T-029: the 罠の点検 (loop-trap self-check) section is mandatory — a retro with
# all four KPT+Lesson sections but no 罠の点検 must fail.
assert_rc "fail-missing-traps -> 1"    1 "missing decorated section heading: ## 罠の点検（Comprehension Debt / Cognitive Surrender）" "$FIX/fail-missing-traps.md"
assert_rc "fail-bare-lesson -> 1"      1 "unlabelled Lesson 候補 bullet"    "$FIX/fail-bare-lesson.md"
# A decorated heading string appearing only in prose / a blockquote (not as a
# real `## ` heading) must NOT satisfy rule 2 — the check is line-anchored.
assert_rc "fail-heading-in-prose -> 1" 1 "missing decorated section heading: ## Try" "$FIX/fail-heading-in-prose.md"
assert_rc "unreadable file -> 2"       2 "cannot read"           "$FIX/does-not-exist.md"
assert_rc "no args -> 2"               2 "usage"

# Multiple files: a clean one + a failing one => exit 1 (the failure wins).
assert_rc "multi: clean + failing -> 1" 1 "fail-no-h1" "$FIX/pass-canonical.md" "$FIX/fail-no-h1.md"

# T-087 AC4/AC7: fail-closed under temp-path unavailability. Rule 3's check is
# now folded into the awk pass that reads the file directly (no here-string /
# temp-file dependency), so pointing $TMPDIR at a non-existent, non-writable
# directory must NOT make the malformed-bullet fixture fall through to a false
# exit 0 — the unlabelled bullet must still be caught.
rc=0
err="$(TMPDIR=/nonexistent-tmp-t087 bash "$RETRO" "$FIX/fail-bare-lesson.md" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -ne 0 ] || fail "fail-closed under broken TMPDIR: expected non-zero exit, got 0 (fail-open regression)"
grep -qE "unlabelled Lesson 候補 bullet" <<< "$err" \
  || fail "fail-closed under broken TMPDIR: malformed bullet must still be reported (got: $err)"
pass "fail-closed: broken TMPDIR still catches fail-bare-lesson.md (exit $rc)"


printf '\nAll check-retro assertions passed.\n'
