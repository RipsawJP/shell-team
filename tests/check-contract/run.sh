#!/usr/bin/env bash
# run.sh — drive bin/check-contract.sh against the fixtures and assert the
# documented contract-lint behavior (T-012 acceptance criteria):
#   - a valid contract exits 0
#   - a contract missing budget: exits 1
#   - a contract missing stop: exits 1
#   - a contract with an out-of-enum trigger type exits 1
#   - a contract missing owner: / evidence: exits 1 (T-028)
#   - a contract with an empty owner value / no evidence items exits 1 (T-028)
#   - an unreadable file exits 2
# Plus a dogfood of the real tasks/loops/*.contract.yaml.
#
# Deliberately avoids mktemp: behavior is asserted from exit code + captured
# stderr via command substitution, so the suite runs in restricted sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-contract.sh"
FIX="$HERE/fixtures"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# assert <desc> <expected_rc> <target> [stderr_grep_pattern]
assert() {
  local desc="$1" expected="$2" target="$3" pat="${4:-}"
  local err rc
  set +e
  err="$(bash "$SCRIPT" "$target" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [[ "$rc" -eq "$expected" ]] \
    || fail "$desc: expected exit $expected, got $rc (stderr: $err)"
  if [[ -n "$pat" ]]; then
    grep -qE "$pat" <<< "$err" \
      || fail "$desc: stderr missing /$pat/ (got: $err)"
  fi
  printf 'PASS: %s (exit %s)\n' "$desc" "$rc"
}

assert "valid contract lints clean" 0 "$FIX/valid.yaml"
assert "missing budget -> exit 1" 1 "$FIX/missing-budget.yaml" \
  "missing required contract element: budget"
assert "missing stop -> exit 1" 1 "$FIX/missing-stop.yaml" \
  "missing required contract element: stop"
assert "bad trigger type -> exit 1" 1 "$FIX/bad-trigger.yaml" \
  "invalid trigger type 'cron'"
# T-022: `schedule` is an intentionally-valid time-trigger value (host-only
# scheduling adapter). This positive lock fails CI if the enum ever drops it.
assert "schedule trigger lints clean" 0 "$FIX/schedule-trigger.yaml"

# T-028: owner / evidence are mandatory (accountability / "unverified done").
assert "missing owner -> exit 1" 1 "$FIX/missing-owner.yaml" \
  "missing required contract element: owner"
assert "missing evidence -> exit 1" 1 "$FIX/missing-evidence.yaml" \
  "missing required contract element: evidence"
assert "empty owner value -> exit 1" 1 "$FIX/empty-owner.yaml" \
  "owner has no value"
assert "evidence with no items -> exit 1" 1 "$FIX/empty-evidence.yaml" \
  "evidence must list at least one"
# Regression (Codex review): a nested list under evidence (no direct flat item)
# must NOT satisfy the >=1-item rule.
assert "nested evidence list -> exit 1" 1 "$FIX/nested-evidence.yaml" \
  "evidence must list at least one"

assert "unreadable file -> exit 2" 2 "$FIX/does-not-exist.yaml"

# Regression (Codex review): a column-0 comment inside budget:/stop: must not
# truncate the section and hide its required keys -> must still lint clean.
assert "column-0 comment in section -> exit 0" 0 "$FIX/comment-in-section.yaml"

# The shipped shell-team contract must describe a valid, fully-guarded loop.
assert "shell-team.contract.yaml lints clean" 0 \
  "$REPO_ROOT/templates/shell-team.contract.yaml"

# The shipped template must itself be a valid contract.
assert "loop-contract-template.yaml lints clean" 0 \
  "$REPO_ROOT/templates/loop-contract-template.yaml"


# The shipped goal contract (self-paced runtime loop).
assert "goal.contract.yaml lints clean" 0 \
  "$REPO_ROOT/templates/goal.contract.yaml"

printf 'OK\n'
exit 0
