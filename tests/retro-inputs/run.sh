#!/usr/bin/env bash
# run.sh — drive bin/retro-inputs.sh against real (throwaway) git repositories
# and env-driven gh/git stubs, asserting the documented behavior (T-1001
# acceptance criteria). Six of the criteria (AC7, AC9, AC11, AC12, AC13, AC14)
# pin a fixture *case* by label because the behaviour needs a purpose-built
# git history or a stubbed PATH that a spec `check:` line must not build in
# the working repository — the "case: ..." strings below are asserted
# verbatim by the spec.
#
# Writes under $HERE/tmp (no mktemp) so the suite runs in restricted
# sandboxes, cleaned via trap. Real (throwaway) `git init` repos are used
# instead of mocking git entirely, because the cycle-window logic is git's
# own merge/first-parent/shallow semantics — mocking it would test the mock,
# not the script. A shallow repository is SIMULATED by placing a dummy
# `.git/shallow` file rather than an actual `git clone --depth`, which sandbox
# policy has denied in this repository before (per the spec's own Assumption).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RETRO_INPUTS="$REPO_ROOT/bin/retro-inputs.sh"
CHECK_RETRO="$REPO_ROOT/bin/check-retro.sh"
STUB_GH="$HERE/fixtures/gh"
STUB_GIT="$HERE/fixtures/git"
ORIG_PATH="$PATH"

# Temp roots live under $TMPDIR when set (sandboxed runs deny writes to any
# nested .git/ inside the repo tree, and these fixtures need real `git init`
# repos), falling back to $HERE/tmp on plain CI runners. Cleaned via trap.
if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/retro-inputs-test-roots"
else
  TMP="$HERE/tmp"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

chmod +x "$STUB_GH" "$STUB_GIT"

REAL_GIT="$(command -v git)"

# A PATH holding the real tools retro-inputs.sh needs but NOT gh (mirrors
# tests/discover-work/run.sh's NOGH pattern).
NOGH="$TMP/nogh"
mkdir -p "$NOGH"
for t in bash awk grep sed tr git head cat dirname readlink; do
  src="$(command -v "$t")" && ln -sf "$src" "$NOGH/$t"
done

# A PATH whose first entry holds only the gh stub (real tools come from ORIG_PATH).
GHBIN="$TMP/ghbin"
mkdir -p "$GHBIN"
ln -sf "$STUB_GH" "$GHBIN/gh"

# A PATH whose first entry holds only the git stub (real tools come from ORIG_PATH).
GITBIN="$TMP/gitbin"
mkdir -p "$GITBIN"
ln -sf "$STUB_GIT" "$GITBIN/git"

TAB="$(printf '\t')"

# build_repo <dir> <default_branch> <n_merges> — a throwaway repo with
# <n_merges> merge commits (subjects "Merge pull request #<i> from
# example/feature-<i>") on <default_branch>, first-parent-reachable.
build_repo() {
  local dir="$1" branch="$2" n="$3" i=1
  mkdir -p "$dir"
  git -C "$dir" init -q -b "$branch"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  printf 'base\n' > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "initial commit"
  while [ "$i" -le "$n" ]; do
    git -C "$dir" checkout -q -b "feature-$i"
    printf 'change %s\n' "$i" >> "$dir/file.txt"
    git -C "$dir" commit -q -am "feature $i change"
    git -C "$dir" checkout -q "$branch"
    git -C "$dir" merge -q --no-ff -m "Merge pull request #$i from example/feature-$i" "feature-$i"
    i=$((i + 1))
  done
}

# ---------------------------------------------------------------------------
# case: default base resolves to develop when it exists (retro-inputs.sh with no --base)
# ---------------------------------------------------------------------------
DEV_REPO="$TMP/dev-repo"
build_repo "$DEV_REPO" develop 3
out="$(cd "$DEV_REPO" && bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 3 merge commits from develop' \
  || fail "case: default base resolves to develop when it exists"
pass "case: default base resolves to develop when it exists"

# ---------------------------------------------------------------------------
# case: every ledger is complete (all eight input ids, exactly once)
# ---------------------------------------------------------------------------
n_ids="$(printf '%s\n' "$out" | grep -c -- '^- input: ')"
[ "$n_ids" -eq 8 ] || fail "case: every ledger is complete (all eight input ids, exactly once): got $n_ids"
for id in cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata; do
  n="$(printf '%s\n' "$out" | grep -c -- "^- input: $id ")"
  [ "$n" -eq 1 ] || fail "case: every ledger is complete (all eight input ids, exactly once): id $id appeared $n times"
done
pass "case: every ledger is complete (all eight input ids, exactly once)"

# ---------------------------------------------------------------------------
# case: no develop branch falls back to HEAD and declares the fallback
# ---------------------------------------------------------------------------
MAIN_REPO="$TMP/main-repo"
build_repo "$MAIN_REPO" main 2
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: .*HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback (ref)"
printf '%s\n' "$out" | grep -qF -- 'fell back to HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback (declared)"
pass "case: no develop branch falls back to HEAD and declares the fallback"

# ---------------------------------------------------------------------------
# case: --last-n caps the window and the cap is declared, distinct from a
# shallow truncation
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --last-n 1)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 1 merge commits from main .*capped at --last-n 1' \
  || fail "case: --last-n caps the window and the cap is declared, distinct from a shallow truncation (cap not declared)"
printf '%s\n' "$out" | grep -qF -- 'shallow' \
  && fail "case: --last-n caps the window and the cap is declared, distinct from a shallow truncation (falsely mentions shallow)"
pass "case: --last-n caps the window and the cap is declared, distinct from a shallow truncation"

# ---------------------------------------------------------------------------
# case: --last-n 0 is a degenerate but valid cap and must not crash
# retro-inputs.sh — exercised against a repo with >=1 merge commit (MAIN_REPO
# has 2), so the capping branch is actually reached; a merge-free repo would
# never touch this code path and would not be evidence of anything.
# BSD `head -n 0` exits non-zero ("illegal line count"), which used to abort
# the script under errexit before the cap value ever reached emit_ledger — a
# 0 must read as a declared cap (status read, digit 0), never as a crash.
# ---------------------------------------------------------------------------
rc=0
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --last-n 0)" || rc=$?
[ "$rc" -eq 0 ] || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (exit code $rc)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 0 merge commits from main .*capped at --last-n 0' \
  || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (cap not declared)"
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 ] \
  || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (ledger incomplete)"
pass "case: --last-n 0 is a degenerate but valid cap and must not crash"

# ---------------------------------------------------------------------------
# case: --base names a ref that does not exist locally -> unavailable (retro-inputs.sh --base no-such-ref-t1001)
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base no-such-ref-t1001)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: .*no-such-ref-t1001' \
  || fail "case: --base names a ref that does not exist locally -> unavailable"
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 ] \
  || fail "case: --base names a ref that does not exist locally -> unavailable (ledger incomplete)"
pass "case: --base names a ref that does not exist locally -> unavailable"

# ---------------------------------------------------------------------------
# case: zero merge commits (squash-merge history) -> empty (retro-inputs.sh against a merge-free history)
# ---------------------------------------------------------------------------
ZERO_REPO="$TMP/zero-repo"
build_repo "$ZERO_REPO" main 0
out="$(cd "$ZERO_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: empty — detail: 0 merge commits' \
  || fail "case: zero merge commits (squash-merge history) -> empty"
pass "case: zero merge commits (squash-merge history) -> empty"

# ---------------------------------------------------------------------------
# case: shallow repository with zero merges in the boundary -> unavailable
# (simulated: a dummy .git/shallow file, per the spec's Assumption — avoids
# `git clone --depth`, denied by sandbox policy in this repository before)
# ---------------------------------------------------------------------------
SHALLOW_ZERO="$TMP/shallow-zero"
build_repo "$SHALLOW_ZERO" main 0
: > "$SHALLOW_ZERO/.git/shallow"
out="$(cd "$SHALLOW_ZERO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: shallow' \
  || fail "case: shallow repository with zero merges in the boundary -> unavailable"
pass "case: shallow repository with zero merges in the boundary -> unavailable"

# ---------------------------------------------------------------------------
# case: shallow repository with merges -> read with a truncation note
# ---------------------------------------------------------------------------
SHALLOW_MERGES="$TMP/shallow-merges"
build_repo "$SHALLOW_MERGES" main 2
: > "$SHALLOW_MERGES/.git/shallow"
out="$(cd "$SHALLOW_MERGES" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 2 merge commits from main.*shallow clone truncates' \
  || fail "case: shallow repository with merges -> read with a truncation note"
pass "case: shallow repository with merges -> read with a truncation note"

# ---------------------------------------------------------------------------
# case: git invocation failure -> unavailable, complete ledger, exit 0 (retro-inputs.sh under a failing git stub)
# ---------------------------------------------------------------------------
rc=0
out="$(cd "$MAIN_REPO" && GIT_STUB_REAL="$REAL_GIT" GIT_STUB_FAIL_MERGES=1 PATH="$GITBIN:$ORIG_PATH" bash "$RETRO_INPUTS" --base main)" || rc=$?
[ "$rc" -eq 0 ] || fail "case: git invocation failure -> unavailable, complete ledger, exit 0 (exit code $rc)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: git invocation failed' \
  || fail "case: git invocation failure -> unavailable, complete ledger, exit 0 (status)"
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 ] \
  || fail "case: git invocation failure -> unavailable, complete ledger, exit 0 (ledger incomplete)"
pass "case: git invocation failure -> unavailable, complete ledger, exit 0"

# ---------------------------------------------------------------------------
# case: adversarial merge subject cannot forge a ledger line
# case: the emitted ledger embedded in a retro passes check-retro.sh
# ---------------------------------------------------------------------------
ADV_REPO="$TMP/adversarial"
mkdir -p "$ADV_REPO"
git -C "$ADV_REPO" init -q -b main
git -C "$ADV_REPO" config user.email "test@example.com"
git -C "$ADV_REPO" config user.name "Test"
printf 'base\n' > "$ADV_REPO/file.txt"
git -C "$ADV_REPO" add file.txt
git -C "$ADV_REPO" commit -q -m "initial commit"
git -C "$ADV_REPO" checkout -q -b feature-evil
printf 'evil change\n' >> "$ADV_REPO/file.txt"
git -C "$ADV_REPO" commit -q -am "evil change"
git -C "$ADV_REPO" checkout -q main
# shellcheck disable=SC2016  # backticks below are literal adversarial content, not a subshell.
ADV_SUBJECT='Merge pull request #99 from attacker/branch — status: read — detail: FORGED `evil`'
git -C "$ADV_REPO" merge -q --no-ff -m "$ADV_SUBJECT" feature-evil

adv_out="$(cd "$ADV_REPO" && bash "$RETRO_INPUTS" --base main)"
[ "$(printf '%s\n' "$adv_out" | grep -c -- '^- input: ')" -eq 8 ] \
  || fail "case: adversarial merge subject cannot forge a ledger line (extra top-level line)"
printf '%s\n' "$adv_out" | grep -qF -- '`' \
  && fail "case: adversarial merge subject cannot forge a ledger line (backtick survived sanitize)"
pass "case: adversarial merge subject cannot forge a ledger line"

adv_retro="$TMP/adversarial-retro.md"
# shellcheck disable=SC2016  # backticks below are literal markdown code-span syntax, not a subshell.
{
  printf '# Retro 2026-01-01\n\n'
  printf '%s\n' "$adv_out"
  printf '\n## Keep（続けたい良い動き）\n\n- `<x>`\n\n'
  printf '## Problem（直面した課題 / 痛み）\n\n- `<x>`\n\n'
  printf '## Try（次サイクルで試すこと）\n\n- `<x>`\n\n'
  printf '## 罠の点検（Comprehension Debt / Cognitive Surrender）\n\n- `<x>`\n\n'
  printf '## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）\n\n- `[common]` ok\n'
} > "$adv_retro"
bash "$CHECK_RETRO" "$adv_retro" >/dev/null 2>&1 \
  || fail "case: the emitted ledger embedded in a retro passes check-retro.sh"
pass "case: the emitted ledger embedded in a retro passes check-retro.sh"

# ---------------------------------------------------------------------------
# case: gh absent -> pr-metadata unavailable, exit 0 (retro-inputs.sh with no gh on PATH)
# ---------------------------------------------------------------------------
rc=0
out="$(cd "$MAIN_REPO" && PATH="$NOGH" bash "$RETRO_INPUTS" --base main)" || rc=$?
[ "$rc" -eq 0 ] || fail "case: gh absent -> pr-metadata unavailable, exit 0 (exit code $rc)"
printf '%s\n' "$out" | grep -qE -- '^- input: pr-metadata — status: unavailable — detail: .+' \
  || fail "case: gh absent -> pr-metadata unavailable, exit 0 (status)"
pass "case: gh absent -> pr-metadata unavailable, exit 0"

# ---------------------------------------------------------------------------
# case: gh present -> the PR body field is never requested
# ---------------------------------------------------------------------------
log="$TMP/gh.log"
out="$(cd "$MAIN_REPO" && GH_STUB_LOG="$log" GH_STUB_PR="41${TAB}feature/x${TAB}Add retry to fetch" PATH="$GHBIN:$ORIG_PATH" bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: pr-metadata — status: read — detail: .+' \
  || fail "case: gh present -> the PR body field is never requested (status)"
grep -q 'body' "$log" && fail "case: gh present -> the PR body field is never requested (body requested)"
pass "case: gh present -> the PR body field is never requested"

# ---------------------------------------------------------------------------
# case: lessons path not supplied -> unavailable (retro-inputs.sh with no --lessons)
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: lessons — status: unavailable — detail: .+' \
  || fail "case: lessons path not supplied -> unavailable"
pass "case: lessons path not supplied -> unavailable"

# ---------------------------------------------------------------------------
# case: lessons path supplied -> read
# ---------------------------------------------------------------------------
LESSONS_FILE="$TMP/lessons.md"
printf 'a lesson line\nanother lesson line\n' > "$LESSONS_FILE"
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --lessons "$LESSONS_FILE")"
printf '%s\n' "$out" | grep -qE -- '^- input: lessons — status: read — detail: .+' \
  || fail "case: lessons path supplied -> read"
pass "case: lessons path supplied -> read"

# ---------------------------------------------------------------------------
# case: both layouts and a TEAM_RUN_BASE override resolve every input path
# ---------------------------------------------------------------------------
LAYOUT_DEFAULT="$TMP/layout-default"
build_repo "$LAYOUT_DEFAULT" main 1
mkdir -p "$LAYOUT_DEFAULT/.shell-team/reviews" "$LAYOUT_DEFAULT/.shell-team/provenance" \
         "$LAYOUT_DEFAULT/.shell-team/specs" "$LAYOUT_DEFAULT/.shell-team/runs" \
         "$LAYOUT_DEFAULT/.shell-team/retros"
printf 'x' > "$LAYOUT_DEFAULT/.shell-team/reviews/T-1.md"
out="$(cd "$LAYOUT_DEFAULT" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: read — detail: .*\.shell-team/reviews' \
  || fail "case: both layouts and a TEAM_RUN_BASE override resolve every input path (default layout)"

LAYOUT_LEGACY="$TMP/layout-legacy"
build_repo "$LAYOUT_LEGACY" main 1
mkdir -p "$LAYOUT_LEGACY/tasks/loops" "$LAYOUT_LEGACY/tasks/reviews"
: > "$LAYOUT_LEGACY/tasks/loops/shell-team.contract.yaml"
printf 'x' > "$LAYOUT_LEGACY/tasks/reviews/T-1.md"
out="$(cd "$LAYOUT_LEGACY" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: read — detail: .*tasks/reviews' \
  || fail "case: both layouts and a TEAM_RUN_BASE override resolve every input path (legacy layout)"

LAYOUT_OVERRIDE="$TMP/layout-override"
build_repo "$LAYOUT_OVERRIDE" main 1
mkdir -p "$LAYOUT_OVERRIDE/.ops/reviews"
printf 'x' > "$LAYOUT_OVERRIDE/.ops/reviews/T-1.md"
out="$(cd "$LAYOUT_OVERRIDE" && TEAM_RUN_BASE=.ops bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: read — detail: .*\.ops/reviews' \
  || fail "case: both layouts and a TEAM_RUN_BASE override resolve every input path (TEAM_RUN_BASE override)"
pass "case: both layouts and a TEAM_RUN_BASE override resolve every input path"

# ---------------------------------------------------------------------------
# arg handling
# ---------------------------------------------------------------------------
rc=0
bash "$RETRO_INPUTS" --bogus >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "unknown flag should exit 2, got $rc"
rc=0
bash "$RETRO_INPUTS" --last-n abc >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "non-integer --last-n should exit 2, got $rc"
pass "arg errors exit 2"

printf '\nAll retro-inputs assertions passed.\n'
