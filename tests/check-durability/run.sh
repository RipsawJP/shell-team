#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-durability.sh (T-1048; issue #167;
# .shell-team/specs/T-1048-handoff-durability-barrier.md).
#
# Every scratch repository is built under ${TMPDIR:-/tmp} (never a nested
# .git/ inside this checkout — sandboxed runs deny that) and ignore
# behavior is pinned with a PERSISTED `git config core.excludesFile` on the
# fixture repo itself, never a `-c` flag on this suite's own invocations —
# a `-c` on the outer call never reaches the `git` the script under test
# runs internally. `git init` uses an empty template dir so a sandboxed run
# is never asked to copy sample hooks.
#
# Every expected-non-zero invocation below is captured with the
# `cmd && rc=0 || rc=$?` idiom (never a bare `cmd; rc=$?`), because a plain
# command that fails, followed by `;`, aborts this suite under
# `set -euo pipefail` before its own exit code is ever read.
#
# Covers: the durable case and its own inline mutation control (a checker
# that always returns 0 must fail this); the #167 false-all-clear case
# (`git status --short` is empty yet the checker still catches it); the
# opt-out in all three directions (tracked declaration honored, untracked
# declaration refused, no environment/git-config route exists); the record
# set's independence from `git status`/`git ls-files`/`git check-ignore`
# (a static grep, paired with a positive control against a synthetic probe);
# the four pre-freeze boundary measurements (B1 unborn repo, B2 detached
# HEAD, B3 linked worktree, B4 missing-working-file vs. uncommitted-change,
# both distinct from not-in-recorded-commit); the `--path=` eol-correctness
# behavior; the ambiguous/prefix task-id glob resolution; and the
# `--records` testing affordance rejecting a malformed registry.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-durability.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-durability-test.XXXXXX")"
EMPTY_GIT_TPL="$TMP/empty-git-template"
mkdir -p "$EMPTY_GIT_TPL"
trap 'rm -rf "$TMP"' EXIT

# build_repo <root> — a default-layout scratch repo, empty-template git init
# pinned to /dev/null excludes.
build_repo() {
  local root="$1"
  mkdir -p "$root/.shell-team/specs" "$root/.shell-team/provenance" "$root/.shell-team/interventions"
  git -C "$root" init -q -b main --template="$EMPTY_GIT_TPL"
  git -C "$root" config core.excludesFile /dev/null
}

commit_all() {
  local root="$1" msg="$2"
  git -C "$root" -c user.email=t@example.invalid -c user.name=t add -A >/dev/null 2>&1
  git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -q -m "$msg" --allow-empty >/dev/null 2>&1
}

write_task_records() {
  # $1 = root, $2 = task id
  local root="$1" task="$2"
  printf 'x\n' > "$root/.shell-team/todo.md"
  printf 'x\n' > "$root/.shell-team/specs/${task}-demo.md"
  printf 'x\n' > "$root/.shell-team/provenance/${task}.md"
  printf 'x\n' > "$root/.shell-team/interventions/${task}.md"
}

# =============================================================================
# durable-happy-path / durable-names-ref / durable-mutation-control (AC2 shape)
# =============================================================================
R1="$TMP/r1"
build_repo "$R1"
write_task_records "$R1" T-900
commit_all "$R1" "initial"

out="$(cd "$R1" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "durable-happy-path: expected exit 0, got $rc"
printf '%s\n' "$out" | grep -qF 'check-durability: durable:' || fail "durable-happy-path: expected a durable: line"
pass "durable-happy-path — four committed records all resolve as durable"

printf '%s\n' "$out" | grep -qF 'refs/heads/main' || fail "durable-names-ref: the printed line must name the observed ref"
pass "durable-names-ref — the success line names the ref it was measured at"

rm -f "$R1/.shell-team/provenance/T-900.md"
( cd "$R1" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) && mrc=0 || mrc=$?
[ "$mrc" -ne 0 ] || fail "durable-mutation-control: deleting a committed record must flip the verdict non-zero (a checker that always returns 0 would pass this suite while measuring nothing)"
pass "durable-mutation-control — deleting one committed record from the working tree flips the identical invocation non-zero"

# =============================================================================
# issue-167-false-all-clear (AC3 shape): a partial `.shell-team/*.md` rule
# hides the board while every deeper record commits normally; git status is
# empty yet the checker still catches it.
# =============================================================================
R2="$TMP/r2"
build_repo "$R2"
printf '.shell-team/*.md\n' > "$R2/.gitignore"
write_task_records "$R2" T-900
commit_all "$R2" "initial"

st="$(git -C "$R2" status --short)"
[ -z "$st" ] || fail "issue-167-false-all-clear: fixture control failed — git status --short is not empty ($st)"
if git -C "$R2" cat-file -e refs/heads/main:.shell-team/todo.md >/dev/null 2>&1; then
  fail "issue-167-false-all-clear: fixture control failed — the board is unexpectedly present in the recorded commit"
fi

out2="$(cd "$R2" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rc2=0 || rc2=$?
[ "$rc2" -eq 1 ] || fail "issue-167-false-all-clear: expected exit 1, got $rc2"
printf '%s\n' "$out2" | grep -qF 'check-durability: not-durable: not-in-recorded-commit:' || fail "issue-167-false-all-clear: expected the not-in-recorded-commit reason"
printf '%s\n' "$out2" | grep -qF '.shell-team/todo.md' || fail "issue-167-false-all-clear: expected the board path to be named"
printf '%s\n' "$out2" | grep -qF 'this hand-off is not durable.' || fail "issue-167-false-all-clear: expected the plain-language tail"
pass "issue-167-false-all-clear — a partial gitignore rule that git status --short cannot see is caught by the checker (the #167 case)"

# =============================================================================
# opt-out, three directions (AC4 shape)
# =============================================================================
# (a) tracked mode file declaring working-tree-only => skip, exit 0
R3A="$TMP/r3a"
build_repo "$R3A"
printf '.shell-team/*.md\n' > "$R3A/.gitignore"
write_task_records "$R3A" T-900
printf 'working-tree-only\n' > "$R3A/.shell-team/durability-mode"
commit_all "$R3A" "initial"
outa="$(cd "$R3A" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rca=0 || rca=$?
[ "$rca" -eq 0 ] || fail "opt-out-tracked-skips: expected exit 0, got $rca"
printf '%s\n' "$outa" | grep -qF 'check-durability: skipped:' || fail "opt-out-tracked-skips: expected a skipped: line"
printf '%s\n' "$outa" | grep -qF 'working-tree-only' || fail "opt-out-tracked-skips: expected the mode value named"
printf '%s\n' "$outa" | grep -qF '.shell-team/durability-mode' || fail "opt-out-tracked-skips: expected the mode file path named"
pass "opt-out-tracked-skips — a tracked working-tree-only declaration honors the skip and says so"

# (b) untracked (ignored) mode file declaring working-tree-only => refused
R3B="$TMP/r3b"
build_repo "$R3B"
printf '.shell-team/*.md\n.shell-team/durability-mode\n' > "$R3B/.gitignore"
write_task_records "$R3B" T-900
printf 'working-tree-only\n' > "$R3B/.shell-team/durability-mode"
commit_all "$R3B" "initial"
outb="$(cd "$R3B" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rcb=0 || rcb=$?
[ "$rcb" -eq 1 ] || fail "opt-out-untracked-refused: expected exit 1, got $rcb"
printf '%s\n' "$outb" | grep -qF 'check-durability: not-durable: untracked-opt-out:' || fail "opt-out-untracked-refused: expected the untracked-opt-out reason"
pass "opt-out-untracked-refused — an untracked (ignored) mode file is refused rather than silently honored"

# (c) no mode file, no git-config route, no environment-variable route
R3C="$TMP/r3c"
build_repo "$R3C"
printf '.shell-team/*.md\n' > "$R3C/.gitignore"
write_task_records "$R3C" T-900
commit_all "$R3C" "initial"
( cd "$R3C" && DURABILITY_MODE=working-tree-only TEAM_DURABILITY_MODE=working-tree-only \
    TEAM_DURABILITY=working-tree-only SHELL_TEAM_DURABILITY_MODE=working-tree-only \
    bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) && rcc=0 || rcc=$?
[ "$rcc" -ne 0 ] || fail "opt-out-no-env-route: four plausible environment-variable names must NOT opt the check out"
pass "opt-out-no-env-route — no environment variable can opt the observation out"

if grep -v '^[[:space:]]*#' "$CHECKER" | grep -qE 'git[[:space:]]+config'; then
  fail "opt-out-no-git-config-route: check-durability.sh must never invoke git config"
else
  pass "opt-out-no-git-config-route — the script never invokes git config outside a comment"
fi

# =============================================================================
# opt-out durability (DP7 rework round 1, 2026-08-08 codex review Blocker 1):
# the opt-out must ITSELF be durable — presence of some blob at the mode
# file's path is not enough, since MODE is parsed from the working tree.
# =============================================================================
# (d) committed as `tracked`, then edited (uncommitted) to `working-tree-only`
# — the exact reproduction from the review. Must NOT skip: fail closed with
# untracked-opt-out (the opt-out DECLARATION was never durably committed,
# even though a mode file with different content is tracked at that path).
R3D="$TMP/r3d"
build_repo "$R3D"
write_task_records "$R3D" T-900
printf 'tracked\n' > "$R3D/.shell-team/durability-mode"
commit_all "$R3D" "initial"
rm -f "$R3D/.shell-team/provenance/T-900.md"
printf 'working-tree-only\n' > "$R3D/.shell-team/durability-mode"
std="$(git -C "$R3D" status --short)"
[ -n "$std" ] || fail "opt-out-uncommitted-edit-not-honored: fixture control failed — git status --short unexpectedly empty"
outd="$(cd "$R3D" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rcd=0 || rcd=$?
[ "$rcd" -eq 1 ] || fail "opt-out-uncommitted-edit-not-honored: expected exit 1, got $rcd"
printf '%s\n' "$outd" | grep -qF 'check-durability: not-durable: untracked-opt-out:' || fail "opt-out-uncommitted-edit-not-honored: expected the untracked-opt-out reason"
if printf '%s\n' "$outd" | grep -qF 'check-durability: skipped:'; then
  fail "opt-out-uncommitted-edit-not-honored: must NOT skip — the opt-out was never durably committed"
fi
pass "opt-out-uncommitted-edit-not-honored — a mode file committed as tracked and edited (uncommitted) to working-tree-only does not silently disable the observation (the round-1 review's reproduction)"

# (e) committed as `working-tree-only`, then edited (uncommitted) to `tracked`
# — MODE parses as tracked from the working copy, so the check simply runs
# (the fail-closed direction; DP7's opt-out honor logic is not even reached).
R3E="$TMP/r3e"
build_repo "$R3E"
write_task_records "$R3E" T-900
printf 'working-tree-only\n' > "$R3E/.shell-team/durability-mode"
commit_all "$R3E" "initial"
printf 'tracked\n' > "$R3E/.shell-team/durability-mode"
oute="$(cd "$R3E" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rce=0 || rce=$?
[ "$rce" -eq 0 ] || fail "opt-out-edited-to-tracked-runs-check: expected exit 0 (all four records are durable), got $rce"
printf '%s\n' "$oute" | grep -qF 'check-durability: durable:' || fail "opt-out-edited-to-tracked-runs-check: expected a durable: line, not a skip"
pass "opt-out-edited-to-tracked-runs-check — editing a committed working-tree-only mode file to tracked (uncommitted) makes the check run normally, never a skip"

# (f) committed as `working-tree-only`, then the mode file is deleted from
# the working tree — absent file means the default mode `tracked` (DP7), so
# the check runs; never a silent skip of a mode value that no longer applies.
R3F="$TMP/r3f"
build_repo "$R3F"
write_task_records "$R3F" T-900
printf 'working-tree-only\n' > "$R3F/.shell-team/durability-mode"
commit_all "$R3F" "initial"
rm -f "$R3F/.shell-team/durability-mode"
outf="$(cd "$R3F" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rcf=0 || rcf=$?
[ "$rcf" -eq 0 ] || fail "opt-out-mode-file-deleted-runs-check: expected exit 0 (all four records are durable), got $rcf"
printf '%s\n' "$outf" | grep -qF 'check-durability: durable:' || fail "opt-out-mode-file-deleted-runs-check: expected a durable: line, not a skip"
pass "opt-out-mode-file-deleted-runs-check — deleting a committed working-tree-only mode file from the working tree falls back to the default tracked mode and the check runs"

# (g) committed as `working-tree-only`, working copy byte-identical (AC4(a)'s
# own happy path, re-asserted here as the round-1 regression's control):
# the DP3-style content check must still compare equal and honor the skip.
R3G="$TMP/r3g"
build_repo "$R3G"
write_task_records "$R3G" T-900
printf 'working-tree-only\n' > "$R3G/.shell-team/durability-mode"
commit_all "$R3G" "initial"
outg="$(cd "$R3G" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rcg=0 || rcg=$?
[ "$rcg" -eq 0 ] || fail "opt-out-byte-identical-still-skips: expected exit 0, got $rcg"
printf '%s\n' "$outg" | grep -qF 'check-durability: skipped:' || fail "opt-out-byte-identical-still-skips: expected a skipped: line"
pass "opt-out-byte-identical-still-skips — a committed working-tree-only mode file whose working copy is byte-identical still honors the skip under the new content check"

# (h) eol-only difference under a `text` gitattribute (DP4 applied to the
# mode file): the mode file's committed blob is LF-normalized, the working
# copy is CRLF — `git hash-object --path=` must still compare them equal.
R3H="$TMP/r3h"
build_repo "$R3H"
printf '*.md text\ndurability-mode text\n' > "$R3H/.gitattributes"
write_task_records "$R3H" T-900
printf 'working-tree-only\r\n' > "$R3H/.shell-team/durability-mode"
commit_all "$R3H" "initial"
printf 'working-tree-only\r\n' > "$R3H/.shell-team/durability-mode"
mode_blob="$(git -C "$R3H" rev-parse refs/heads/main:.shell-team/durability-mode)"
[ -n "$mode_blob" ] || fail "opt-out-eol-only-difference-still-skips: fixture control failed — could not resolve the committed mode-file blob"
mode_raw_stdin="$(cd "$R3H" && git hash-object --stdin < .shell-team/durability-mode)"
mode_norm_stdin="$(cd "$R3H" && git hash-object --stdin --path=.shell-team/durability-mode < .shell-team/durability-mode)"
[ "$mode_raw_stdin" != "$mode_norm_stdin" ] || fail "opt-out-eol-only-difference-still-skips: fixture control failed — this environment performs no eol normalization at all; the criterion would measure nothing"
[ "$mode_norm_stdin" = "$mode_blob" ] || fail "opt-out-eol-only-difference-still-skips: fixture control failed — --path did not normalize to the committed mode-file blob via --stdin"
outh="$(cd "$R3H" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rch=0 || rch=$?
[ "$rch" -eq 0 ] || fail "opt-out-eol-only-difference-still-skips: expected exit 0, got $rch"
printf '%s\n' "$outh" | grep -qF 'check-durability: skipped:' || fail "opt-out-eol-only-difference-still-skips: expected a skipped: line, not uncommitted-change/untracked-opt-out"
pass "opt-out-eol-only-difference-still-skips — a CRLF working mode file under a text gitattribute still compares equal to its LF-normalized committed blob (DP4 applied to the opt-out itself)"

# =============================================================================
# record-set-independence (AC5 shape): no git status / ls-files / check-ignore
# outside comments; at least one of ls-tree / rev-parse / cat-file IS used;
# names both the registry file and team-paths.sh; a positive control proves
# the forbidden-pattern grep can actually match something.
# =============================================================================
CODE_ONLY="$TMP/code-only"
grep -v '^[[:space:]]*#' "$CHECKER" > "$CODE_ONLY"
[ -s "$CODE_ONLY" ] || fail "record-set-independence: stripping comments left nothing to scan"

if grep -qE 'git[[:space:]]+status' "$CODE_ONLY"; then
  fail "record-set-independence: check-durability.sh must never invoke git status outside a comment"
else
  pass "record-set-independence — no git status call outside a comment"
fi
if grep -qE 'git[[:space:]]+ls-files' "$CODE_ONLY"; then
  fail "record-set-independence: check-durability.sh must never invoke git ls-files outside a comment"
else
  pass "record-set-independence — no git ls-files call outside a comment"
fi
if grep -qE 'git[[:space:]]+check-ignore' "$CODE_ONLY"; then
  fail "record-set-independence: check-durability.sh must never invoke git check-ignore outside a comment"
else
  pass "record-set-independence — no git check-ignore call outside a comment"
fi
grep -qE 'git[[:space:]]+(ls-tree|rev-parse|cat-file)' "$CODE_ONLY" || fail "record-set-independence: expected at least one of git ls-tree/rev-parse/cat-file"
grep -qF 'durability-records.txt' "$CODE_ONLY" || fail "record-set-independence: expected the registry filename to be named"
grep -qF 'team-paths.sh' "$CODE_ONLY" || fail "record-set-independence: expected team-paths.sh to be named"
pass "record-set-independence — the checker reads the recorded commit, not the working-tree views git status/ls-files cannot see past an ignore rule"

PROBE="$TMP/probe"
printf 'git status --short\n' > "$PROBE"
grep -qE 'git[[:space:]]+status' "$PROBE" || fail "record-set-independence: positive control failed — the forbidden-pattern grep matched nothing at all"
pass "record-set-independence positive control — the same pattern DOES match a synthetic probe line, so the clean result above measured something"

# =============================================================================
# boundary conditions B1 (unborn repo), B2 (detached HEAD), B3 (linked worktree)
# =============================================================================
R4="$TMP/r4-unborn"
build_repo "$R4"
write_task_records "$R4" T-900
outu="$(cd "$R4" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && rcu=0 || rcu=$?
[ "$rcu" -eq 1 ] || fail "boundary-b1-unborn-repo: expected exit 1, got $rcu"
printf '%s\n' "$outu" | grep -qF 'check-durability: not-durable: no-recorded-commit:' || fail "boundary-b1-unborn-repo: expected the no-recorded-commit reason"
pass "boundary-b1-unborn-repo — a repository with zero commits is a defined fail-closed verdict, never a silent skip"

R5="$TMP/r5-detached"
build_repo "$R5"
write_task_records "$R5" T-900
commit_all "$R5" "initial"
git -C "$R5" checkout -q --detach >/dev/null 2>&1
cur="$(git -C "$R5" branch --show-current)"
[ -z "$cur" ] || fail "boundary-b2-detached-head: fixture control failed — branch --show-current is not empty under detached HEAD"
( cd "$R5" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) \
  || fail "boundary-b2-detached-head: expected exit 0 via the explicit --ref despite detached HEAD"
if grep -v '^[[:space:]]*#' "$CHECKER" | grep -qE 'branch --show-current|symbolic-ref'; then
  fail "boundary-b2-detached-head: check-durability.sh must never call branch --show-current or symbolic-ref outside a comment"
fi
pass "boundary-b2-detached-head — the checker never infers the branch; the explicit --ref resolves the normal verdict under a detached HEAD"

git -C "$R5" worktree add --detach "$TMP/r5-wt" refs/heads/main >/dev/null 2>&1
( cd "$TMP/r5-wt" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) \
  || fail "boundary-b3-linked-worktree: expected exit 0 from inside a linked worktree"
pass "boundary-b3-linked-worktree — the identical invocation from a linked worktree reaches the same normal verdict, with no special-casing"
git -C "$R5" worktree remove --force "$TMP/r5-wt" >/dev/null 2>&1 || true

# =============================================================================
# boundary B4: missing-working-file vs. uncommitted-change are each their own
# verdict, and neither is ever reported as not-in-recorded-commit.
# =============================================================================
R6M="$TMP/r6-miss"
build_repo "$R6M"
write_task_records "$R6M" T-900
commit_all "$R6M" "initial"
rm -f "$R6M/.shell-team/interventions/T-900.md"
o1="$(cd "$R6M" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && s1=0 || s1=$?
[ "$s1" -eq 1 ] || fail "boundary-b4-missing-working-file: expected exit 1, got $s1"
printf '%s\n' "$o1" | grep -qF 'check-durability: not-durable: missing-working-file:' || fail "boundary-b4-missing-working-file: expected the missing-working-file reason"
if printf '%s\n' "$o1" | grep -qF 'not-in-recorded-commit'; then
  fail "boundary-b4-missing-working-file: must never be reported as not-in-recorded-commit"
fi
pass "boundary-b4-missing-working-file — a record deleted from the working tree is its own verdict, never not-in-recorded-commit"

R6U="$TMP/r6-uncommitted"
build_repo "$R6U"
write_task_records "$R6U" T-900
commit_all "$R6U" "initial"
printf 'changed\n' > "$R6U/.shell-team/todo.md"
o2="$(cd "$R6U" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && s2=0 || s2=$?
[ "$s2" -eq 1 ] || fail "boundary-b4-uncommitted-change: expected exit 1, got $s2"
printf '%s\n' "$o2" | grep -qF 'check-durability: not-durable: uncommitted-change:' || fail "boundary-b4-uncommitted-change: expected the uncommitted-change reason"
if printf '%s\n' "$o2" | grep -qF 'not-in-recorded-commit'; then
  fail "boundary-b4-uncommitted-change: must never be reported as not-in-recorded-commit"
fi
pass "boundary-b4-uncommitted-change — a record modified in place is its own verdict, never not-in-recorded-commit (absence is read from ls-tree's OUTPUT, never its exit status)"

# =============================================================================
# eol-correctness (AC8 shape / DP4): --path= makes a CRLF working file
# compare equal to its LF-normalized committed blob under a `text`
# gitattribute — a benign correctness choice, not hardening.
# =============================================================================
R7="$TMP/r7-eol"
build_repo "$R7"
printf '*.md text\n' > "$R7/.gitattributes"
write_task_records "$R7" T-900
# write_task_records wrote LF; rewrite with CRLF before the first commit so
# every record's committed blob is LF-normalized by the text attribute.
for f in "$R7/.shell-team/todo.md" "$R7/.shell-team/specs/T-900-demo.md" "$R7/.shell-team/provenance/T-900.md" "$R7/.shell-team/interventions/T-900.md"; do
  printf 'x\r\n' > "$f"
done
commit_all "$R7" "initial"
printf 'x\r\n' > "$R7/.shell-team/todo.md"
blob="$(git -C "$R7" rev-parse refs/heads/main:.shell-team/todo.md)"
[ -n "$blob" ] || fail "eol-correctness: fixture control failed — could not resolve the committed blob"
# Non-vacuity control, via --stdin rather than a bare file argument:
# `git-hash-object(1)` documents that a --stdin read applies NO filters
# unless --path is ALSO given, whereas a bare `<file>` argument (the shape
# check-durability.sh itself uses) may already apply the text-attribute
# filter without --path in some git versions/environments — measured true
# in this one, which is exactly why this control uses --stdin instead: the
# bare-file form would silently pass this control while measuring nothing
# whenever an environment already normalizes without --path.
raw_stdin="$(cd "$R7" && git hash-object --stdin < .shell-team/todo.md)"
norm_stdin="$(cd "$R7" && git hash-object --stdin --path=.shell-team/todo.md < .shell-team/todo.md)"
[ "$raw_stdin" != "$norm_stdin" ] || fail "eol-correctness: fixture control failed — this environment performs no eol normalization at all; the criterion would measure nothing"
[ "$norm_stdin" = "$blob" ] || fail "eol-correctness: fixture control failed — --path did not normalize to the committed blob via --stdin"
( cd "$R7" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) \
  || fail "eol-correctness: expected durable (exit 0), not uncommitted-change, once --path= normalizes the working-file comparison"
pass "eol-correctness — a CRLF working file under a text gitattribute is reported durable (not uncommitted-change) by the checker's --path= comparison; the eol-normalization behavior is proven real via the --stdin form, which git-hash-object(1) documents as filter-free without --path"

# =============================================================================
# ambiguous / prefix task id (AC18 shape): the hyphen in <task-id>-*.md keeps
# a shorter id from matching a longer one's spec; two matches is structural.
# =============================================================================
R8="$TMP/r8-glob"
build_repo "$R8"
mkdir -p "$R8/.shell-team/specs" "$R8/.shell-team/provenance" "$R8/.shell-team/interventions"
printf 'x\n' > "$R8/.shell-team/todo.md"
printf 'x\n' > "$R8/.shell-team/specs/T-900-one.md"
printf 'x\n' > "$R8/.shell-team/provenance/T-900.md"
printf 'x\n' > "$R8/.shell-team/interventions/T-900.md"
commit_all "$R8" "initial"

( cd "$R8" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main >/dev/null 2>&1 ) \
  || fail "ambiguous-prefix-task-id: control failed — exact task id T-900 should resolve durable"
pass "ambiguous-prefix-task-id control — the exact task id resolves durable (makes the two cases below mean something)"

o3="$(cd "$R8" && bash "$CHECKER" --phase implement --task T-90 --ref refs/heads/main 2>&1)" && s3=0 || s3=$?
[ "$s3" -eq 1 ] || fail "ambiguous-prefix-task-id-prefix: expected exit 1 for the T-90 prefix, got $s3"
printf '%s\n' "$o3" | grep -qF 'missing-working-file' || fail "ambiguous-prefix-task-id-prefix: expected missing-working-file (the hyphen must keep T-90-*.md from matching T-900-one.md)"
pass "ambiguous-prefix-task-id-prefix — a shorter id that is a PREFIX of the real one does not silently match the longer id's spec file"

printf 'x\n' > "$R8/.shell-team/specs/T-900-two.md"
commit_all "$R8" "second spec file"
o4="$(cd "$R8" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main 2>&1)" && s4=0 || s4=$?
[ "$s4" -eq 2 ] || fail "ambiguous-prefix-task-id-two-matches: expected exit 2, got $s4"
printf '%s\n' "$o4" | grep -qF 'check-durability: structural:' || fail "ambiguous-prefix-task-id-two-matches: expected a structural classification"
pass "ambiguous-prefix-task-id-two-matches — two matching spec files for one task id is structural (ambiguous), never a silent pick"

# =============================================================================
# --records testing affordance: an override registry that is malformed is
# rejected structurally rather than silently accepted or crashing.
# =============================================================================
R9="$TMP/r9-badregistry"
build_repo "$R9"
write_task_records "$R9" T-900
commit_all "$R9" "initial"
BAD_REGISTRY="$TMP/bad-registry.txt"
printf 'implement todo -\nimplement specs onlytwo\n' > "$BAD_REGISTRY"
( cd "$R9" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main --records "$BAD_REGISTRY" >/dev/null 2>&1 ) && rc9=0 || rc9=$?
[ "$rc9" -eq 2 ] || fail "records-override-malformed-registry: expected exit 2 for a pattern that is neither '-' nor <task-id>-bearing, got $rc9"
pass "records-override-malformed-registry — the --records testing affordance lets this suite exercise a malformed-row rejection without touching the shipped registry"

MISSING_REGISTRY="$TMP/does-not-exist.txt"
( cd "$R9" && bash "$CHECKER" --phase implement --task T-900 --ref refs/heads/main --records "$MISSING_REGISTRY" >/dev/null 2>&1 ) && rc10=0 || rc10=$?
[ "$rc10" -eq 2 ] || fail "records-override-missing-file: expected exit 2 for a nonexistent --records path, got $rc10"
pass "records-override-missing-file — a --records override naming a nonexistent file fails structurally rather than silently using the shipped default"

# =============================================================================
# usage floor: bad --task shape, a missing --ref, and an outside-the-closed-set
# --phase are usage errors (exit 2), not silent no-ops.
# =============================================================================
( bash "$CHECKER" --phase implement --task 'not-a-task-id' --ref HEAD >/dev/null 2>&1 ) && rc_bt=0 || rc_bt=$?
[ "$rc_bt" -eq 2 ] || fail "usage-bad-task-shape: expected exit 2 for a --task not matching ^T-[0-9]+\$, got $rc_bt"
pass "usage-bad-task-shape — a malformed --task value is a usage error"

( bash "$CHECKER" --phase implement --task T-900 >/dev/null 2>&1 ) && rc_nr=0 || rc_nr=$?
[ "$rc_nr" -eq 2 ] || fail "usage-missing-ref: expected exit 2 when --ref is omitted, got $rc_nr"
pass "usage-missing-ref — --ref has no default; omitting it is a usage error"

( bash "$CHECKER" --phase not-a-real-phase --task T-900 --ref HEAD >/dev/null 2>&1 ) && rc_bp=0 || rc_bp=$?
[ "$rc_bp" -eq 2 ] || fail "usage-bad-phase: expected exit 2 for a phase outside the closed set, got $rc_bp"
pass "usage-bad-phase — a phase name outside implement|pre-merge|close-out is a usage error, not a silent no-op"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-durability suite: all assertions passed\n'
  exit 0
else
  printf 'check-durability suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
