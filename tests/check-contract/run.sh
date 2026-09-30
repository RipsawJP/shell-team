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

# T-1160: optional budget.max_spec_review_rounds — validated when present,
# never required. The fixtures are built inline from valid.yaml (the suite
# avoids mktemp, so the derived files live under $FIX and are removed).
mk_cap() {
  # mk_cap <value-line-or-empty> <outfile>
  awk -v x="$1" '{ print } /^  max_iterations:/ { if (x != "") print x }' "$FIX/valid.yaml" > "$2"
}
CAPF="$FIX/.t1160-cap.yaml"
trap 'rm -f "$CAPF"' EXIT
grep -c '^  max_iterations:' "$FIX/valid.yaml" | grep -qx 1 || fail "T-1160 precondition: valid.yaml carries one max_iterations line"
for ok in 3 0 08 999999999 "2   # tuned"; do
  mk_cap "  max_spec_review_rounds: $ok" "$CAPF"
  assert "T-1160 max_spec_review_rounds: $ok lints clean" 0 "$CAPF"
done
for bad in abc -1 1234567890 3.5 '"3"' "3 4" ""; do
  mk_cap "  max_spec_review_rounds: $bad" "$CAPF"
  assert "T-1160 max_spec_review_rounds: '$bad' -> exit 1" 1 "$CAPF" "max_spec_review_rounds"
done
# an absent key is never a violation, and a misplaced key (under stop:) is not read
assert "T-1160 absent max_spec_review_rounds lints clean" 0 "$FIX/valid.yaml"
awk '{ print } /^  no_progress:/ { print "  max_spec_review_rounds: abc" }' "$FIX/valid.yaml" > "$CAPF"
assert "T-1160 a junk value under stop: (not budget:) is not read" 0 "$CAPF"
mk_cap "  # max_spec_review_rounds: abc" "$CAPF"
assert "T-1160 a commented-out key is not read" 0 "$CAPF"
# the shipped run-loop template and this repo's own contract carry the key and lint clean
assert "T-1160 this repo's own contract lints clean" 0 "$REPO_ROOT/.shell-team/loops/shell-team.contract.yaml"
rm -f "$CAPF"

printf 'OK\n'
exit 0
