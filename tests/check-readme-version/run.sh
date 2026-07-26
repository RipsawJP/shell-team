#!/usr/bin/env bash
# run.sh — drive bin/check-readme-version.sh against fixtures and assert the
# documented behavior (T-023 acceptance criteria, manifest-sync edition):
#   - a README whose version badge == manifest version passes (exit 0)     [AC1]
#   - a README whose badge != manifest version fails (exit 1)              [AC2]
#   - a README with no version badge fails (exit 1)                        [AC3]
#   - a language badge (badge/lang-...) does NOT satisfy the version check
#   - the repo's own README.md / README.ja.md match plugin.json (dogfood)  [AC5]
#   - an unreadable manifest / README / no args are usage errors (exit 2)
#
# The fixture manifest pins version 1.2.3; the suite points the guard at it via
# VERSION_MANIFEST so the comparison logic is exercised independently of the
# real plugin.json.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GUARD="$REPO_ROOT/bin/check-readme-version.sh"
FIX="$HERE/fixtures"
MANIFEST="$FIX/manifest.json"   # pins version 1.2.3

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <stderr_grep|""> -- <env-prefixed guard args...>
# Runs:  VERSION_MANIFEST=$MANIFEST bash $GUARD <args>
assert_rc() {
  local desc="$1" exp="$2" pat="$3"; shift 3
  local err rc
  set +e
  err="$(VERSION_MANIFEST="$MANIFEST" bash "$GUARD" "$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  pass "$desc (exit $rc)"
}

assert_rc "match -> 0"               0 ""                              "$FIX/match.md"
assert_rc "mismatch -> 1"            1 "version badge is 9.9.9 but plugin.json is 1.2.3" "$FIX/mismatch.md"
assert_rc "missing badge -> 1"       1 "no static version badge found" "$FIX/missing.md"
assert_rc "unreadable README -> 2"   2 "cannot read file"              "$FIX/does-not-exist.md"
assert_rc "no args -> 2"             2 "usage"

# Multiple files: a matching one + a mismatched one => exit 1 (failure wins).
assert_rc "multi: match + mismatch -> 1" 1 "mismatch.md" "$FIX/match.md" "$FIX/mismatch.md"

# Unreadable manifest -> usage error (exit 2), independent of READMEs.
set +e
err="$(VERSION_MANIFEST="$FIX/no-such-manifest.json" bash "$GUARD" "$FIX/match.md" 2>&1 >/dev/null)"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "unreadable manifest: expected exit 2, got $rc (stderr: $err)"
grep -qE "cannot read plugin manifest" <<< "$err" || fail "unreadable manifest: wrong message ($err)"
pass "unreadable manifest -> 2"

# Pre-release (beta) versions: shields.io escapes the literal '-' in the badge
# message as '--', so a 0.2.0-beta manifest is written `version-0.2.0--beta`.
BETA_MANIFEST="$FIX/manifest-beta.json"   # pins 0.2.0-beta
VERSION_MANIFEST="$BETA_MANIFEST" bash "$GUARD" "$FIX/beta-match.md" >/dev/null 2>&1 \
  || fail "beta: escaped 0.2.0--beta badge must match the 0.2.0-beta manifest"
pass "beta: escaped 0.2.0--beta badge matches 0.2.0-beta manifest"

set +e
err="$(VERSION_MANIFEST="$BETA_MANIFEST" bash "$GUARD" "$FIX/beta-mismatch.md" 2>&1 >/dev/null)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "beta: 0.2.0--alpha badge vs 0.2.0-beta manifest should fail (exit 1), got $rc"
grep -qE "0\.2\.0-alpha" <<< "$err" || fail "beta: mismatch message should show the decoded badge version (got: $err)"
pass "beta: mismatched pre-release badge fails (exit 1) with decoded version in message"

# Dogfood (AC5): the repo's real READMEs match the real plugin.json (no env override).
bash "$GUARD" "$REPO_ROOT/README.md" "$REPO_ROOT/README.ja.md" >/dev/null 2>&1 \
  || fail "dogfood: README.md / README.ja.md must match .claude-plugin/plugin.json version"
pass "dogfood: real READMEs match plugin.json version"

printf '\nAll check-readme-version assertions passed.\n'
