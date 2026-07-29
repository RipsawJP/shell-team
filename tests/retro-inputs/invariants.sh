#!/usr/bin/env bash
# invariants.sh — ONE bounded regression lock for the
# abort-before-emission class (T-1001 v3 AC10), and nothing more.
#
# In every state below, retro-inputs.sh prints "## Retro inputs" and eight complete ledger lines and exits 0 or 2; any other exit status (including 1 and 141) and any output with fewer than eight ledger lines is a violation.
#
# The nine states are a CLOSED list — the ones this task's own review rounds
# actually produced — pinned at exactly nine in both directions so the list
# cannot grow by accretion round after round. A tenth state is a deliberate
# change to this file and the spec criterion it satisfies, never something a
# rework round appends on its own.
#
# state: a directory whose name ends in .md
# state: a broken symlink whose name ends in .md
# state: a merge log larger than the pipe buffer with --last-n
# state: an empty operating directory
# state: a readable but not traversable directory
# state: a shallow repository
# state: a linked worktree
# state: a --base ref that does not resolve
# state: --last-n 0
#
# WHAT THIS DOES NOT CLAIM: it does not assert that no further plumbing
# defect exists anywhere in the script. That is not provable, and treating
# it as the goal is what cost this task three review rounds past the point
# of usefulness. This lock asserts the single output invariant above for
# exactly these nine enumerated states and nothing beyond them. No fuzz
# harness, no adversarial mutation of the plumbing layer — that is a
# declined Non-goal, filed as its own issue.
#
# Temp roots live under $TMPDIR when set (sandboxed runs deny writes to a
# nested .git/ inside this repo's own tree), falling back to $HERE/tmp on
# plain CI runners — the same pattern tests/retro-inputs/run.sh uses.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RETRO_INPUTS="$REPO_ROOT/bin/retro-inputs.sh"

if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/retro-inputs-invariants-roots"
else
  TMP="$HERE/tmp-invariants"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP" 2>/dev/null || true
trap 'chmod -R u+rwx "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

# assert_invariant <description> -- <cmd...>
# Runs the given command (typically `bash "$RETRO_INPUTS" ...` in a subshell
# with a cwd already set via `cd dir &&`), and asserts the single output
# invariant: exit 0 or 2, "## Retro inputs" heading present, exactly 8
# top-level `- input: ` lines.
assert_invariant() {
  local desc="$1" out rc
  shift
  set +e
  out="$(eval "$1" 2>&1)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || fail "$desc: exit status $rc is neither 0 nor 2"
  printf '%s\n' "$out" | grep -qxF -- '## Retro inputs' \
    || fail "$desc: missing the '## Retro inputs' heading (got: $out)"
  local n
  n="$(printf '%s\n' "$out" | grep -c -- '^- input: ')"
  [ "$n" -eq 8 ] || fail "$desc: expected 8 complete ledger lines, got $n (out: $out)"
  pass "$desc"
}

# build_repo <dir> <default_branch> <n_merges> [<branch_pad_len>] — a
# throwaway repo with <n_merges> merge commits; when <branch_pad_len> is
# given, each merge's branch name is padded to that many bytes so a small
# number of merges can still exceed the ~64KB pipe-buffer threshold.
build_repo() {
  local dir="$1" branch="$2" n="$3" pad="${4:-0}" i=1 padstr=""
  mkdir -p "$dir"
  git -C "$dir" init -q -b "$branch"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  printf 'base\n' > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "initial commit"
  if [ "$pad" -gt 0 ]; then
    padstr="$(printf 'x%.0s' $(seq 1 "$pad"))"
  fi
  while [ "$i" -le "$n" ]; do
    git -C "$dir" checkout -q -b "feature-$i"
    printf 'change %s\n' "$i" >> "$dir/file.txt"
    git -C "$dir" commit -q -am "feature $i change"
    git -C "$dir" checkout -q "$branch"
    git -C "$dir" merge -q --no-ff -m "Merge pull request #$i from example/${padstr}${i}" "feature-$i"
    i=$((i + 1))
  done
}

# ---------------------------------------------------------------------------
# state: a directory whose name ends in .md
# ---------------------------------------------------------------------------
D1="$TMP/state-dir-md-repo"
build_repo "$D1" main 1
mkdir -p "$D1/.shell-team/reviews/T-looks-like-a-file.md"
assert_invariant "invariant holds: a directory whose name ends in .md" \
  "cd '$D1' && bash '$RETRO_INPUTS' --base main"

# ---------------------------------------------------------------------------
# state: a broken symlink whose name ends in .md
# ---------------------------------------------------------------------------
D2="$TMP/state-symlink-md-repo"
build_repo "$D2" main 1
mkdir -p "$D2/.shell-team/reviews"
ln -sf "/nonexistent-target-t1001-invariants" "$D2/.shell-team/reviews/T-dangling.md"
assert_invariant "invariant holds: a broken symlink whose name ends in .md" \
  "cd '$D2' && bash '$RETRO_INPUTS' --base main"

# ---------------------------------------------------------------------------
# state: a merge log larger than the pipe buffer with --last-n
# (measured trigger is bytes, ~64KB, not merge count -- long padded branch
# names reach it with far fewer merges than a count-based estimate suggests)
# ---------------------------------------------------------------------------
D3="$TMP/state-big-log-repo"
build_repo "$D3" main 200 300
assert_invariant "invariant holds: a merge log larger than the pipe buffer with --last-n" \
  "cd '$D3' && bash '$RETRO_INPUTS' --base main --last-n 5"

# ---------------------------------------------------------------------------
# state: an empty operating directory
# ---------------------------------------------------------------------------
D4="$TMP/state-empty-dir-repo"
build_repo "$D4" main 1
mkdir -p "$D4/.shell-team/reviews" "$D4/.shell-team/provenance" "$D4/.shell-team/specs" \
         "$D4/.shell-team/runs" "$D4/.shell-team/retros"
assert_invariant "invariant holds: an empty operating directory" \
  "cd '$D4' && bash '$RETRO_INPUTS' --base main"

# ---------------------------------------------------------------------------
# state: a readable but not traversable directory
# ---------------------------------------------------------------------------
D5="$TMP/state-non-traversable-repo"
build_repo "$D5" main 1
mkdir -p "$D5/.shell-team/reviews"
printf 'x' > "$D5/.shell-team/reviews/T-1.md"
chmod 0600 "$D5/.shell-team/reviews"
assert_invariant "invariant holds: a readable but not traversable directory" \
  "cd '$D5' && bash '$RETRO_INPUTS' --base main"
chmod 0700 "$D5/.shell-team/reviews"

# ---------------------------------------------------------------------------
# state: a shallow repository
# (simulated: a dummy .git/shallow file, per the spec's Assumption -- avoids
# `git clone --depth`, denied by sandbox policy in this repository before)
# ---------------------------------------------------------------------------
D6="$TMP/state-shallow-repo"
build_repo "$D6" main 1
: > "$D6/.git/shallow"
assert_invariant "invariant holds: a shallow repository" \
  "cd '$D6' && bash '$RETRO_INPUTS' --base main"

# ---------------------------------------------------------------------------
# state: a linked worktree
# ---------------------------------------------------------------------------
D7_MAIN="$TMP/state-worktree-main"
build_repo "$D7_MAIN" main 1
git -C "$D7_MAIN" worktree add -q "$TMP/state-worktree-linked" -b wt-branch
assert_invariant "invariant holds: a linked worktree" \
  "cd '$TMP/state-worktree-linked' && bash '$RETRO_INPUTS' --base wt-branch"
git -C "$D7_MAIN" worktree remove "$TMP/state-worktree-linked" --force >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# state: a --base ref that does not resolve
# ---------------------------------------------------------------------------
D8="$TMP/state-bad-ref-repo"
build_repo "$D8" main 1
assert_invariant "invariant holds: a --base ref that does not resolve" \
  "cd '$D8' && bash '$RETRO_INPUTS' --base no-such-ref-t1001-invariants"

# ---------------------------------------------------------------------------
# state: --last-n 0
# ---------------------------------------------------------------------------
D9="$TMP/state-last-n-zero-repo"
build_repo "$D9" main 2
assert_invariant "invariant holds: --last-n 0" \
  "cd '$D9' && bash '$RETRO_INPUTS' --base main --last-n 0"

printf '\nAll retro-inputs invariants assertions passed (9/9 states).\n'
