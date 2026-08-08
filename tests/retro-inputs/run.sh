#!/usr/bin/env bash
# run.sh — drive bin/retro-inputs.sh against real (throwaway) git repositories,
# permission-restricted directories, a linked worktree, and env-driven gh/git
# stubs, asserting the documented behavior (T-1001 v2 acceptance criteria).
# Several criteria (AC4, AC5, AC7, AC9, AC11, AC12, AC13, AC14) pin a fixture
# *case* by label because the behaviour needs a purpose-built git history, a
# permission-restricted directory, a linked worktree, or a stubbed PATH that a
# spec `check:` line must not build in the working repository — the
# "case: ..." strings below are asserted verbatim by the spec.
#
# Temp roots live under $TMPDIR when set (sandboxed runs deny writes to a
# nested .git/ inside this repo's own tree, and these fixtures need real
# `git init` repos), falling back to $HERE/tmp on plain CI runners. Real
# (throwaway) git repos are used instead of mocking git entirely, because the
# cycle-window logic is git's own merge/first-parent/shallow semantics —
# mocking it would test the mock, not the script. A shallow repository is
# SIMULATED by placing a dummy `.git/shallow` file rather than an actual
# `git clone --depth`, which sandbox policy has denied in this repository
# before (per the spec's own Assumption). A linked worktree is real
# (`git worktree add`), since nothing prevents that in a sandbox.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RETRO_INPUTS="$REPO_ROOT/bin/retro-inputs.sh"
CHECK_RETRO="$REPO_ROOT/bin/check-retro.sh"
STUB_GH="$HERE/fixtures/gh"
STUB_GIT="$HERE/fixtures/git"
ORIG_PATH="$PATH"

if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/retro-inputs-test-roots"
else
  TMP="$HERE/tmp"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# Any 0600-permission directories built below are chmod'd back to 0700 before
# this runs, so `rm -rf` (which needs traverse permission on every ancestor)
# can actually clean up the whole tree.
rm -rf "$TMP" 2>/dev/null || true
trap 'chmod -R u+rwx "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
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
# case: every ledger is complete (all nine input ids, exactly once)
# ---------------------------------------------------------------------------
n_ids="$(printf '%s\n' "$out" | grep -c -- '^- input: ')"
[ "$n_ids" -eq 9 ] || fail "case: every ledger is complete (all nine input ids, exactly once): got $n_ids"
for id in cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions; do
  n="$(printf '%s\n' "$out" | grep -c -- "^- input: $id ")"
  [ "$n" -eq 1 ] || fail "case: every ledger is complete (all nine input ids, exactly once): id $id appeared $n times"
done
pass "case: every ledger is complete (all nine input ids, exactly once)"

# ---------------------------------------------------------------------------
# case: no develop branch falls back to HEAD and declares the fallback in
# every status branch — exercised on all three: read (merges present), empty
# (confirmed-zero merges), and unavailable (an unanswerable shallow probe).
# ---------------------------------------------------------------------------
MAIN_REPO="$TMP/main-repo"
build_repo "$MAIN_REPO" main 2
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: .*HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback in every status branch (read)"
printf '%s\n' "$out" | grep -qF -- 'fell back to HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback in every status branch (read, not declared)"

ZERO_NO_DEV="$TMP/zero-no-dev"
build_repo "$ZERO_NO_DEV" main 0
out="$(cd "$ZERO_NO_DEV" && bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: empty — detail: .*HEAD.*fell back to HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback in every status branch (empty)"

out="$(cd "$MAIN_REPO" && GIT_STUB_REAL="$REAL_GIT" GIT_STUB_FAIL_SHALLOW_PROBE=1 PATH="$GITBIN:$ORIG_PATH" bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: .*fell back to HEAD' \
  || fail "case: no develop branch falls back to HEAD and declares the fallback in every status branch (unavailable)"
pass "case: no develop branch falls back to HEAD and declares the fallback in every status branch"

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
# case: a shallow repository with a cap states both qualifiers — a cap and a
# shallow truncation are different facts and can both be true; the detail
# must mention both, not just the first one an if/elif would have picked.
# ---------------------------------------------------------------------------
SHALLOW_CAP="$TMP/shallow-cap"
build_repo "$SHALLOW_CAP" main 3
: > "$SHALLOW_CAP/.git/shallow"
out="$(cd "$SHALLOW_CAP" && bash "$RETRO_INPUTS" --base main --last-n 1)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 1 merge commits from main' \
  || fail "case: a shallow repository with a cap states both qualifiers (status/count)"
printf '%s\n' "$out" | grep -qF -- 'shallow clone truncates history at the boundary' \
  || fail "case: a shallow repository with a cap states both qualifiers (shallow qualifier missing)"
printf '%s\n' "$out" | grep -qF -- 'capped at --last-n 1' \
  || fail "case: a shallow repository with a cap states both qualifiers (cap qualifier missing)"
pass "case: a shallow repository with a cap states both qualifiers"

# ---------------------------------------------------------------------------
# case: --last-n 0 is a degenerate but valid cap and must not crash (regression
# lock, not spec-required by name, but a real defect fixed in an earlier
# round: BSD `head -n 0` exits non-zero, which used to abort the script under
# errexit before the cap value ever reached emission).
# ---------------------------------------------------------------------------
rc=0
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --last-n 0)" || rc=$?
[ "$rc" -eq 0 ] || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (exit code $rc)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: read — detail: 0 merge commits from main .*capped at --last-n 0' \
  || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (cap not declared)"
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 9 ] \
  || fail "case: --last-n 0 is a degenerate but valid cap and must not crash (ledger incomplete)"
pass "case: --last-n 0 is a degenerate but valid cap and must not crash"

# ---------------------------------------------------------------------------
# case: --base names a ref that does not exist locally -> unavailable (retro-inputs.sh --base no-such-ref-t1001)
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base no-such-ref-t1001)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: .*no-such-ref-t1001' \
  || fail "case: --base names a ref that does not exist locally -> unavailable"
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 9 ] \
  || fail "case: --base names a ref that does not exist locally -> unavailable (ledger incomplete)"
pass "case: --base names a ref that does not exist locally -> unavailable"

# ---------------------------------------------------------------------------
# case: the default-ref probe cannot answer -> unavailable with a reason
# distinct from ref-absent (AC5) — a git stub makes `rev-parse --verify
# --quiet develop^{commit}` fail with a non-1 exit code (real git's --quiet
# contract exits 1 for a genuine absence; anything else is git failing to
# answer), so this must NOT read the same as a plain missing ref.
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && GIT_STUB_REAL="$REAL_GIT" GIT_STUB_FAIL_DEVELOP_PROBE=1 PATH="$GITBIN:$ORIG_PATH" bash "$RETRO_INPUTS")"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: git could not answer whether develop exists' \
  || fail "case: the default-ref probe cannot answer -> unavailable with a reason distinct from ref-absent"
printf '%s\n' "$out" | grep -qF -- 'does not resolve locally' \
  && fail "case: the default-ref probe cannot answer -> unavailable with a reason distinct from ref-absent (misreported as ref-absent)"
pass "case: the default-ref probe cannot answer -> unavailable with a reason distinct from ref-absent"

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
# case: DS-2 a shallow repository with zero merges blocks the empty promotion -> unavailable
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
pass "case: DS-2 a shallow repository with zero merges blocks the empty promotion -> unavailable"

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
[ "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 9 ] \
  || fail "case: git invocation failure -> unavailable, complete ledger, exit 0 (ledger incomplete)"
pass "case: git invocation failure -> unavailable, complete ledger, exit 0"

# ---------------------------------------------------------------------------
# case: DS-1 an unanswerable shallow probe blocks the read promotion -> unavailable
# A repo WITH real merges, but the shallow probe itself cannot answer (an old
# git or any other unanswerable git rev-parse --is-shallow-repository) — even
# though merges clearly exist, the read promotion must not be reached.
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && GIT_STUB_REAL="$REAL_GIT" GIT_STUB_FAIL_SHALLOW_PROBE=1 PATH="$GITBIN:$ORIG_PATH" bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: could not determine whether main is a shallow repository' \
  || fail "case: DS-1 an unanswerable shallow probe blocks the read promotion -> unavailable"
pass "case: DS-1 an unanswerable shallow probe blocks the read promotion -> unavailable"

# ---------------------------------------------------------------------------
# case: a directory containing files but not traversable -> unavailable, never empty
# case: DS-3 a directory containing files but not traversable blocks the read promotion -> unavailable
# A directory that IS readable (glob can list names) but not TRAVERSABLE
# (chmod removes execute/search) can list a matching filename via readdir
# without being able to stat it — the exact substitution this whole task
# exists to prevent. Must be unavailable, never empty (the naive
# "0 matches found" reading) nor read (a false confirmation).
# ---------------------------------------------------------------------------
DS3_REPO="$TMP/ds3-repo"
build_repo "$DS3_REPO" main 1
mkdir -p "$DS3_REPO/.shell-team/reviews"
printf 'x' > "$DS3_REPO/.shell-team/reviews/T-1.md"
chmod 0600 "$DS3_REPO/.shell-team/reviews"
out="$(cd "$DS3_REPO" && bash "$RETRO_INPUTS" --base main)"
chmod 0700 "$DS3_REPO/.shell-team/reviews"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: unavailable — detail: .*not traversable' \
  || fail "case: a directory containing files but not traversable -> unavailable, never empty"
pass "case: a directory containing files but not traversable -> unavailable, never empty"
pass "case: DS-3 a directory containing files but not traversable blocks the read promotion -> unavailable"

# ---------------------------------------------------------------------------
# case: DS-4 a directory with only non-matching files and not traversable
# blocks the empty promotion -> unavailable. Distinct from DS-3: here the
# directory would look EMPTY of matches if enumeration silently returned
# nothing, so this proves the guard also catches the "looks empty" shape,
# not only the "looks non-empty" shape.
# ---------------------------------------------------------------------------
DS4_REPO="$TMP/ds4-repo"
build_repo "$DS4_REPO" main 1
mkdir -p "$DS4_REPO/.shell-team/reviews"
printf 'not markdown' > "$DS4_REPO/.shell-team/reviews/notes.txt"
chmod 0600 "$DS4_REPO/.shell-team/reviews"
out="$(cd "$DS4_REPO" && bash "$RETRO_INPUTS" --base main)"
chmod 0700 "$DS4_REPO/.shell-team/reviews"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: unavailable — detail: .*not traversable' \
  || fail "case: DS-4 a directory with only non-matching files and not traversable blocks the empty promotion -> unavailable"
pass "case: DS-4 a directory with only non-matching files and not traversable blocks the empty promotion -> unavailable"

# ---------------------------------------------------------------------------
# case: a shallow linked worktree with zero merges -> unavailable, never empty
# The shallow marker lives in the COMMON git directory, not the worktree-
# specific one `git rev-parse --git-dir` returns from inside a linked
# worktree — this is exactly why AC5 names
# `git rev-parse --is-shallow-repository` (worktree-correct) instead.
# ---------------------------------------------------------------------------
WT_MAIN="$TMP/wt-main"
build_repo "$WT_MAIN" main 0
git -C "$WT_MAIN" worktree add -q "$TMP/wt-linked" -b wt-branch
: > "$WT_MAIN/.git/shallow"
out="$(cd "$TMP/wt-linked" && bash "$RETRO_INPUTS" --base wt-branch)"
printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: shallow' \
  || fail "case: a shallow linked worktree with zero merges -> unavailable, never empty"
pass "case: a shallow linked worktree with zero merges -> unavailable, never empty"
git -C "$WT_MAIN" worktree remove "$TMP/wt-linked" --force >/dev/null 2>&1 || true

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
[ "$(printf '%s\n' "$adv_out" | grep -c -- '^- input: ')" -eq 9 ] \
  || fail "case: adversarial merge subject cannot forge a ledger line (extra top-level line)"
printf '%s\n' "$adv_out" | grep -qF -- '`' \
  && fail "case: adversarial merge subject cannot forge a ledger line (backtick survived sanitize)"
pass "case: adversarial merge subject cannot forge a ledger line"

adv_retro="$TMP/adversarial-retro.md"
# shellcheck disable=SC2016  # backticks below are literal markdown code-span syntax, not a subshell.
{
  printf '# Retro 2026-01-01\n\n'
  printf '%s\n' "$adv_out"
  printf '\n<!-- retro-section: keep -->\n## Keep（続けたい良い動き）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: problem -->\n## Problem（直面した課題 / 痛み）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: try -->\n## Try（次サイクルで試すこと）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: traps -->\n## 罠の点検（Comprehension Debt / Cognitive Surrender）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: lessons -->\n## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）\n\n- `[common]` ok\n'
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
# case: DS-7 gh unauthenticated blocks the read promotion -> unavailable
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && GH_STUB_AUTH=fail PATH="$GHBIN:$ORIG_PATH" bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: pr-metadata — status: unavailable — detail: gh is not authenticated' \
  || fail "case: DS-7 gh unauthenticated blocks the read promotion -> unavailable"
pass "case: DS-7 gh unauthenticated blocks the read promotion -> unavailable"

# ---------------------------------------------------------------------------
# case: DS-8 a failing gh pr list blocks the empty promotion -> unavailable
# gh is authenticated (auth check succeeds) but the list command itself
# fails — must not be read as "confirmed zero" (empty).
# ---------------------------------------------------------------------------
out="$(cd "$MAIN_REPO" && GH_STUB_PR=FAIL PATH="$GHBIN:$ORIG_PATH" bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: pr-metadata — status: unavailable — detail: gh pr list failed' \
  || fail "case: DS-8 a failing gh pr list blocks the empty promotion -> unavailable"
pass "case: DS-8 a failing gh pr list blocks the empty promotion -> unavailable"

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
# case: DS-5 an unreadable lessons file blocks the read promotion -> unavailable
# ---------------------------------------------------------------------------
LESSONS_UNREADABLE="$TMP/lessons-unreadable.md"
printf 'a lesson line\n' > "$LESSONS_UNREADABLE"
chmod 000 "$LESSONS_UNREADABLE"
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --lessons "$LESSONS_UNREADABLE")"
chmod 600 "$LESSONS_UNREADABLE"
printf '%s\n' "$out" | grep -qE -- '^- input: lessons — status: unavailable — detail: path supplied but not readable' \
  || fail "case: DS-5 an unreadable lessons file blocks the read promotion -> unavailable"
pass "case: DS-5 an unreadable lessons file blocks the read promotion -> unavailable"

# ---------------------------------------------------------------------------
# case: DS-6 a directory passed as --lessons blocks the empty promotion -> unavailable
# ---------------------------------------------------------------------------
LESSONS_DIR="$TMP/lessons-dir"
mkdir -p "$LESSONS_DIR"
out="$(cd "$MAIN_REPO" && bash "$RETRO_INPUTS" --base main --lessons "$LESSONS_DIR")"
printf '%s\n' "$out" | grep -qE -- '^- input: lessons — status: unavailable — detail: path supplied but not a regular file' \
  || fail "case: DS-6 a directory passed as --lessons blocks the empty promotion -> unavailable"
pass "case: DS-6 a directory passed as --lessons blocks the empty promotion -> unavailable"

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
# case: an interventions directory holding no .md files -> empty, never unavailable
# The .gitkeep a fresh `team-init` leaves behind (DP-8: no third fixture for
# the shared non-traversable-directory failure mode, which DS-3/DS-4 already
# exercise through review-artifacts above).
# ---------------------------------------------------------------------------
INTERVENTIONS_EMPTY="$TMP/interventions-empty"
build_repo "$INTERVENTIONS_EMPTY" main 1
mkdir -p "$INTERVENTIONS_EMPTY/.shell-team/interventions"
: > "$INTERVENTIONS_EMPTY/.shell-team/interventions/.gitkeep"
out="$(cd "$INTERVENTIONS_EMPTY" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: interventions — status: empty — detail: 0 intervention records' \
  || fail "case: an interventions directory holding no .md files -> empty, never unavailable"
pass "case: an interventions directory holding no .md files -> empty, never unavailable"

# ---------------------------------------------------------------------------
# case: an absent interventions directory -> unavailable, never empty
# ---------------------------------------------------------------------------
INTERVENTIONS_ABSENT="$TMP/interventions-absent"
build_repo "$INTERVENTIONS_ABSENT" main 1
out="$(cd "$INTERVENTIONS_ABSENT" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: interventions — status: unavailable — detail: directory not found' \
  || fail "case: an absent interventions directory -> unavailable, never empty"
pass "case: an absent interventions directory -> unavailable, never empty"

# ---------------------------------------------------------------------------
# case: review-artifacts counts any regular file, so a reviews dir holding
# only non-.md artifacts reads (T-1042 D3) -- a .txt and a .jsonl mirror
# bin/codex-capture.sh's own published output; a .json dump, a file with an
# unfamiliar extension and an extensionless file are the boundary values an
# enumerated suffix set would have missed.
# ---------------------------------------------------------------------------
LB1_REPO="$TMP/lb1-any-file"
build_repo "$LB1_REPO" main 1
mkdir -p "$LB1_REPO/.shell-team/reviews"
printf 'x' > "$LB1_REPO/.shell-team/reviews/T-1.txt"
printf 'x' > "$LB1_REPO/.shell-team/reviews/T-1.jsonl"
printf 'x' > "$LB1_REPO/.shell-team/reviews/dump.json"
printf 'x' > "$LB1_REPO/.shell-team/reviews/notes.rtf"
printf 'x' > "$LB1_REPO/.shell-team/reviews/noext"
out="$(cd "$LB1_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: read — detail: 5 review artifacts in ' \
  || fail "case: review-artifacts counts any regular file, so a reviews dir holding only non-.md artifacts reads"
pass "case: review-artifacts counts any regular file, so a reviews dir holding only non-.md artifacts reads"

# ---------------------------------------------------------------------------
# case: review-artifacts reports empty for a reviews dir holding no regular file
# ---------------------------------------------------------------------------
LB2_REPO="$TMP/lb2-empty-reviews"
build_repo "$LB2_REPO" main 1
mkdir -p "$LB2_REPO/.shell-team/reviews"
out="$(cd "$LB2_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: empty — detail: 0 review artifacts in ' \
  || fail "case: review-artifacts reports empty for a reviews dir holding no regular file"
pass "case: review-artifacts reports empty for a reviews dir holding no regular file"

# ---------------------------------------------------------------------------
# case: review-artifacts counts neither a capture-temp dotfile nor a
# subdirectory -- the open-extension rule widens the suffix match, not the
# nullglob-without-dotglob enumeration or the -f regular-file test.
# ---------------------------------------------------------------------------
LB3_REPO="$TMP/lb3-dotfile-subdir"
build_repo "$LB3_REPO" main 1
mkdir -p "$LB3_REPO/.shell-team/reviews/nested"
printf 'x' > "$LB3_REPO/.shell-team/reviews/.codex-capture.T-1.tmp"
out="$(cd "$LB3_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: empty — detail: 0 review artifacts in ' \
  || fail "case: review-artifacts counts neither a capture-temp dotfile nor a subdirectory"
pass "case: review-artifacts counts neither a capture-temp dotfile nor a subdirectory"

# ---------------------------------------------------------------------------
# case: the .md and .jsonl suffix rules are unchanged for the other five
# directory inputs -- each one gets a single non-matching-suffix file, so the
# open-extension rule review-artifacts just gained must not have leaked into
# any of the other five.
# ---------------------------------------------------------------------------
LB4_REPO="$TMP/lb4-other-five-suffix"
build_repo "$LB4_REPO" main 1
mkdir -p "$LB4_REPO/.shell-team/provenance" "$LB4_REPO/.shell-team/specs" \
         "$LB4_REPO/.shell-team/runs" "$LB4_REPO/.shell-team/retros" \
         "$LB4_REPO/.shell-team/interventions"
printf 'x' > "$LB4_REPO/.shell-team/provenance/T-1.txt"
printf 'x' > "$LB4_REPO/.shell-team/specs/T-1.txt"
printf 'x' > "$LB4_REPO/.shell-team/runs/T-1.txt"
printf 'x' > "$LB4_REPO/.shell-team/retros/T-1.txt"
printf 'x' > "$LB4_REPO/.shell-team/interventions/T-1.txt"
out="$(cd "$LB4_REPO" && bash "$RETRO_INPUTS" --base main)"
for id in provenance specs run-telemetry previous-retro interventions; do
  printf '%s\n' "$out" | grep -qE -- "^- input: $id — status: empty — detail: 0 " \
    || fail "case: the .md and .jsonl suffix rules are unchanged for the other five directory inputs ($id)"
done
pass "case: the .md and .jsonl suffix rules are unchanged for the other five directory inputs"

# ---------------------------------------------------------------------------
# case: a directory-input detail names the resolved path and never an
# absolute one (D4) -- the whole detail field is anchored end-of-line against
# the exact repo-root-relative path, so an absolute-path leak would fail the
# match rather than merely appending after it.
# ---------------------------------------------------------------------------
LB5_REPO="$TMP/lb5-relative-detail"
build_repo "$LB5_REPO" main 1
mkdir -p "$LB5_REPO/.shell-team/reviews"
printf 'x' > "$LB5_REPO/.shell-team/reviews/T-1.md"
out="$(cd "$LB5_REPO" && bash "$RETRO_INPUTS" --base main)"
printf '%s\n' "$out" | grep -qE -- '^- input: review-artifacts — status: read — detail: 1 review artifacts in \.shell-team/reviews$' \
  || fail "case: a directory-input detail names the resolved path and never an absolute one"
pass "case: a directory-input detail names the resolved path and never an absolute one"

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
