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
# LOAD-BEARING STATUS OF EACH STATE (so a later reader does not mistake a
# guardrail for a proven lock, or vice versa):
#   - State 1 (.md directory): PROVEN. Reverting AC8's fix (both the
#     case-arm `if` and the trailing `return 0`) reproduces exit 1 on this
#     exact fixture.
#   - State 2 (broken symlink): the SAME AC8 defect as state 1 applies here
#     too, but this suite's fail-fast design means a single full run never
#     reaches state 2 once state 1 already failed under a reverted fix —
#     proving it requires an isolated run (skip/reorder state 1, or run
#     state 2 alone against a mutated copy). Not re-provable by reading this
#     file's own output alone; see the task's provenance record for the
#     isolated reproduction.
#   - State 3 (oversized merge log): PROVEN, conditionally — see the
#     mechanical precondition assertion at that state below. The pipe-buffer
#     threshold that makes this state fire is kernel-dependent, so the
#     fixture is built with a wide margin above every measured abort point
#     rather than just over some observed minimum, and the state asserts its
#     own precondition (the log genuinely exceeds a declared lower bound)
#     before ever checking the ledger invariant — a future accretion that
#     shrinks this fixture below the threshold fails LOUDLY here rather than
#     silently ceasing to be load-bearing.
#   - States 4-8 (empty directory, non-traversable directory, shallow
#     repository, linked worktree, unresolvable --base): GUARDRAILS. No
#     defect specific to any of these was ever found in this script; they
#     are enumerated because this task's review rounds actually produced
#     them as repository states worth checking the invariant against, not
#     because reverting some named fix is known to turn them red. Treat them
#     as coverage, not as proof of anything.
#   - State 9 (--last-n 0): PROVEN. This is the branch AC9's fix removed
#     (the old special case for a zero cap); reverting AC9's fix reproduces
#     exit 1 on this fixture.
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
#
# The measured trigger is BYTES, not merge count, and the exact boundary is
# kernel-dependent -- measured directly on this machine: a 41KB / 108-line
# log SURVIVED, a 72KB / 189-line log SURVIVED, a 90KB log ABORTED (exit
# 141), and so did 110KB and 150KB. The real boundary sits somewhere between
# ~72KB and ~90KB. A fixture built just over the LOWEST observed abort point
# is not load-bearing on a machine with a larger pipe buffer, and this is
# exactly the mistake an earlier round of this task made (pad=300 for 200
# merges landed at ~77KB -- inside that ambiguous band, so it happened to
# survive on this machine and the state passed for the wrong reason). This
# fixture is therefore built with a wide margin ABOVE every measured abort
# point (pad=1300 for 200 merges, ~271KB) rather than a value just over some
# observed minimum, and the precondition itself -- that this fixture's merge
# log genuinely clears a safely-above-the-boundary lower bound -- is
# asserted MECHANICALLY below, before the ledger invariant is ever checked.
# If a future edit narrows this margin (fewer merges, shorter padding), this
# state fails LOUDLY instead of silently reverting to non-load-bearing.
# ---------------------------------------------------------------------------
D3="$TMP/state-big-log-repo"
build_repo "$D3" main 200 1300
D3_LOG_BYTES="$(git -C "$D3" log --merges --first-parent --pretty=format:'%H%x09%s' main | wc -c | tr -d ' ')"
D3_MIN_BYTES=200000
[ "$D3_LOG_BYTES" -gt "$D3_MIN_BYTES" ] \
  || fail "state 3 precondition failed: merge log is only $D3_LOG_BYTES bytes (need > $D3_MIN_BYTES, safely above the measured ~72-90KB abort boundary) -- this state would not be load-bearing"
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
