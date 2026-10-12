# Test follow-ups: the team-commit suite survives an override with no sibling, and the setup suite covers four more local-mode classes

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1190

## Problem

Two open follow-up issues name gaps in two fixture suites. Both are test-only gaps; no shipped script is wrong.

- **#712.** `tests/team-commit/run.sh` copies `team-mode.sh` beside each scratch copy of the script under test, taking it from the directory of `$TEAM_COMMIT_SCRIPT`. When the override points at a standalone copy with no `team-mode.sh` beside it, the top-level `cp` fails under `set -e` and the whole suite aborts instead of reporting the case. Nothing in the suite states that the override is a "copy plus sibling" contract.
- **#718.** `tests/setup/run.sh` covers `local` record mode for a base dir ignored through `info/exclude`, a base dir that is not ignored, and a base dir committed in HEAD. It does not cover four classes the T-1183 spec's Input space names: a `TEAM_RUN_BASE` override, an ignore rule from a parent-directory pattern, an ignore rule from the root `.gitignore` or a global excludes file, and a `git check-ignore` error.

## Summarized sources

- Issue #712 (body supplied by the coordinating session; read in full) — either document the "copy plus sibling" contract at the override, or guard the `cp` and report a `FAIL` naming the missing sibling; in either case the normal run's output stays byte-identical. This task does both (the tech-lead's Routing Map elects both).
- Issue #718 (read in full) — one `local`-mode fixture per class, built like the existing local-mode fixtures (scratch repository under `$TMPDIR`, `GIT_CONFIG_GLOBAL=/dev/null`, no recursive deletion), each asserting the printed item, no `git add` and no removal command, and the exit status. "No shipped behaviour changes."
- `tests/team-commit/run.sh` (read at `8b917f80`):
  - `:19-20` is the override comment ("TEAM_COMMIT_SCRIPT overrides the script under test …"); it does not mention `team-mode.sh`.
  - `:22` `set -euo pipefail`; `:27` `SCRIPT="${TEAM_COMMIT_SCRIPT:-$REPO_ROOT/bin/team-commit.sh}"`; `:25-26` `HERE`/`REPO_ROOT` are used only to build that default.
  - `:29-31` the `fails` counter and the `pass` (stdout) / `fail` (stderr) helpers.
  - `:33-40` the existing recursive-deletion gate over `$SCRIPT` and the suite itself.
  - `:495-518` case `pre-invariant-extra-staged`, with the top-level copy at `:499`.
  - `:524-535` `disable_marker()`, with the copy at `:527`; it is called through command substitution at `:537` and `:552`.
  - `:803-804` the trailer `cases done; failures: %s` on stdout and the final `[ "$fails" -eq 0 ]`.
  - Every `pass` message is a fixed string, except `:300` (`$id $f`, where `$f` is a flag literal) and `:646` (`$id $4`, a fixed description). No `pass` message carries a path.
- `bin/team-commit.sh:255-256` — `MODE_READER="$SCRIPT_DIR/team-mode.sh"`; when it is missing the script refuses with class `mode` ("team-mode.sh is missing or unreadable next to team-commit.sh").
- `tests/setup/run.sh` (read at `8b917f80`):
  - `:22` `set -euo pipefail`; `:26` `S="$REPO_ROOT/bin/team-setup.sh"` (no override).
  - `:37-38` the scratch root from `mktemp -d`; `:43-44` `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1` and `unset TEAM_RUN_BASE CODEX_THREAD_ID`.
  - `:60` `st`, `:62` `sec`, `:361` `gcf`, `:362` `stg`.
  - `:481-485` a PATH stub `$T/gs/git` that exits 128 on `check-ignore`, used today by one `tracked`-mode fixture.
  - `:944-1046` the `local`-mode fixtures, with `LMP`, `lmrepo()` and `nogit()` at `:950-958`.
  - `:1048-1054` the trailer `setup suite: all assertions passed`; no PASS count is printed.
  - The token `T-1190` occurs 0 times under `tests/` (Grep tool).
- `bin/team-setup.sh` (read at `8b917f80`):
  - `:762-767` `np()` normalizes the resolved base; `:767` `N_BASE`.
  - `:784-826` the `local` arm. In order, per directory: committed in HEAD → `Remains` (`:796-798`); `git check-ignore -v -z --stdin` (`:801`); exit 0 with a pattern not beginning `!` → `Already in place:` item `base directory in local mode: $rd/ is ignored by git` (`:815`); exit above 1 → stderr `team-setup: git check-ignore could not evaluate $rd/ (exit $lm_rc)` (`:810`), `EC2=1`, no item for that directory; not ignored with a safe path → `Required:` item naming `` `/$rd/` `` and `$LM_EXCL` (`:823`).
  - The `local` arm reads only the pattern field (line 3 of the parsed `check-ignore` output, `:804`), never the source field. So whichever file the matching rule lives in (`info/exclude`, root `.gitignore`, a global excludes file), the same branch runs. **The root-`.gitignore` and global-excludes fixtures therefore assert outcome equivalence across sources; they do not exercise a distinct code path.**
  - `:1068-1076` the report is printed, then `EC2=1` exits 2.
  - `:425-437` the only other `check-ignore` call before the `local` arm is on the Codex CLI host; on `--host claude-code` it does not run.
- `bin/team-paths.sh:110-136` — `TEAM_RUN_BASE` must be repo-relative with no whitespace and no `.`/`..`/empty components; a nested path such as `ops/st` passes (the setup suite already uses `work/st` at `:436`).
- `.github/workflows/check-handoff.yml` — `:38` and `:44` run shellcheck on each suite with its script; `:406` and `:412` run each suite.
- `.shell-team/specs/T-1189-local-mode-followups-prose.md` — the predecessor task; its scope lock leaves `tests/` untouched, so both suites are unchanged from `develop` at this branch's base.

## Goal

<!-- BEGIN intent-block: T-1190 -->

- user-visible: no — the diff is confined to two fixture suites under `tests/` and this task's records; no adopter runs, reads or is shipped anything that changes.
- verification-class: mechanism — the diff reaches `tests/`, which the checklist classes as an executing surface; the full-population downstream inventory is replaced by CI plus this task's own check lines, as disclosed in `## Blast radius`.
- verification-ceiling: unit-and-static — every criterion is settled in a plain checkout by suite exit codes and output lines, shellcheck, string presence and absence, and diffs against the base; no criterion is above the ceiling.
- base-ref-discriminator: P=feature/local-mode-followups-prose; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; else B=$(git merge-base develop HEAD) || exit 1; fi; git cat-file -e "$B^{commit}" || exit 1;

**Goal (one sentence).** `tests/team-commit/run.sh` states the "copy plus sibling" contract at its override and reports a missing `team-mode.sh` sibling as a `FAIL` that names it and runs to the end, with its normal-run stdout byte-identical to the base; and `tests/setup/run.sh` gains one `local`-mode fixture each for a `TEAM_RUN_BASE` override, a parent-directory ignore pattern, a root-`.gitignore` source (plus a global-excludes variant) and a `check-ignore` error — with no shipped file changed.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — #712.** Both copy sites go through one guard. A missing sibling yields a `FAIL:` line naming `team-mode.sh` and the override directory, the affected cases are reported rather than aborting the suite, and the run reaches its trailer with exit 1. A one-line comment at the override states the contract (**AC1**). The normal run's stdout is byte-identical to the base's (**AC2**).
- **D2 — #718.** One fixture per class, each asserting its printed item, `nogit` on both streams, and the exit status (**AC3**–**AC6**). The existing setup-suite lines are not changed (**AC11**).
- **D3 — hygiene.** No recursive deletion in either suite or in this spec (**AC7**); shellcheck clean (**AC8**); diff confined to the two suites and this task's records (**AC9**); both full suites exit 0 (**AC10**).

**Pre-commitment (frozen before round 1; AI self-discipline, never operator-ratified).**

- **Trigger.** Two consecutive rounds, QA or code review, each with a recorded verdict and each with a new finding against the same fixture or the same guard. A round interrupted before a verdict is not counted.
- **Never-dropped.**
  - (N1) No `bin/` file changes (**AC9**).
  - (N2) The team-commit suite's normal-run stdout stays byte-identical to the base (**AC2**).
  - (N3) No recursive deletion anywhere this task writes (**AC7**).

  A defeat of N1–N3 stops the task and returns it to planning. Any finding whose fix needs a `bin/team-setup.sh` (or any other `bin/`) edit also returns to planning and is filed as a new issue; it is never fixed in this task.
- **Droppable, in order.**
  1. The global-excludes variant of **AC5** (the root-`.gitignore` variant stays).

  Dropping removes criterion text, so it is a class-B re-freeze under the Frozen intent freeze rules, never taken on this role's own authority. The firing round's findings travel to a reopened #718 as its requirement list.

## Non-goals

- **Any `bin/` change**, including `bin/team-setup.sh`, `bin/team-commit.sh` and `bin/team-mode.sh` (**AC9**).
- **A distinct code path per ignore source.** The root-`.gitignore` and global-excludes fixtures assert the same outcome as the `info/exclude` fixture; they are not claimed to exercise different branches of `bin/team-setup.sh` (info-only; stated in **AC5**'s body).
- **Changes to existing setup-suite fixtures or helpers** (**AC11**).
- **Any doc, README, skill, agent, template or workflow edit** (**AC9**).
- **No full-population sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** Operator rulings: A2 light operation and the 2026-10-01 ruling. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`.
- **Base.** **AC2**, **AC9** and **AC11** resolve `B` with the `base-ref-discriminator` expression above, spelled byte-identically in each. On this branch today it resolves to `8b917f80`.
- **What lines never contain.** No line reads a gitignored path, splices a per-checkout or per-run value into a compared stream, or contains a recursive deletion. A suite is scanned for the recursive-deletion pattern before it runs and is not run if the pattern matches. Each suite run sits under `ulimit -f` with its captured output capped by `head -c`.
- **Staleness.** **AC9** and **AC11** are **merge-point-scoped and expected to go stale** once later work lands on the same base; do not widen their base to keep them evergreen. **AC2** compares against the base blob of the suite and goes stale on the same event.

- [ ] **AC1** (#712; D1.) The team-commit suite reports a missing `team-mode.sh` sibling instead of aborting.
  - **Contract comment.** A comment line of `tests/team-commit/run.sh` names both `TEAM_COMMIT_SCRIPT` and `team-mode.sh`.
  - **Fixture.** A standalone copy of `bin/team-commit.sh` in a fresh `$TMPDIR` directory with no `team-mode.sh` beside it is passed as `TEAM_COMMIT_SCRIPT`. The suite exits 1; stderr carries at least one line beginning `FAIL: ` that names `team-mode.sh` and that directory; the last stdout line is `cases done; failures: N` with N at least 1 (the run reached its end).
  - check: rc=0; R=tests/team-commit/run.sh; test -r "$R" || exit 1; test -r bin/team-commit.sh || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; grep -E '^[[:space:]]*#' "$R" | grep -F -- 'TEAM_COMMIT_SCRIPT' | grep -qF -- 'team-mode.sh' || rc=1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; mkdir "$T/solo" || exit 1; cp bin/team-commit.sh "$T/solo/team-commit.sh" || exit 1; test ! -e "$T/solo/team-mode.sh" || exit 1; ulimit -f 400000 2>/dev/null; TEAM_COMMIT_SCRIPT="$T/solo/team-commit.sh" bash "$R" < /dev/null 2> "$T/err" | head -c 20000000 > "$T/out"; s=("${PIPESTATUS[@]}"); test "${s[0]}" = 1 || rc=1; test "${s[1]}" = 0 || rc=1; grep '^FAIL: ' "$T/err" | grep -F -- 'team-mode.sh' | grep -qF -- "$T/solo" || rc=1; tail -n 1 "$T/out" | grep -qE '^cases done; failures: [1-9][0-9]*$' || rc=1; test "$rc" -eq 0

- [ ] **AC2** (#712; D1; N2.) The normal team-commit run's stdout is byte-identical to the base's.
  - **Stability first.** The base blob of `tests/team-commit/run.sh` at `B`, run twice against the checkout's `bin/team-commit.sh`, exits 0 both times with identical, non-empty stdout; otherwise the instrument is broken and the line exits 1.
  - **Comparison.** `bash tests/team-commit/run.sh` with `TEAM_COMMIT_SCRIPT` unset exits 0, and its stdout equals the base run's byte for byte. Stdout carries only `PASS:` lines and the trailer, none of which prints a path (see `## Summarized sources`), so no per-checkout value enters the compared stream.
  - check: rc=0; P=feature/local-mode-followups-prose; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; else B=$(git merge-base develop HEAD) || exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; R=tests/team-commit/run.sh; test -r "$R" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; git show "$B:$R" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; for f in "$R" "$T/base.sh"; do grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$f"; r=$?; test "$r" = 1 || exit 1; done; C="$(pwd -P)/bin/team-commit.sh"; test -s "$C" || exit 1; ulimit -f 400000 2>/dev/null; for n in 1 2; do TEAM_COMMIT_SCRIPT="$C" bash "$T/base.sh" < /dev/null 2> "$T/be$n" | head -c 20000000 > "$T/b$n"; s=("${PIPESTATUS[@]}"); test "${s[0]}" = 0 && test "${s[1]}" = 0 || exit 1; done; test -s "$T/b1" || exit 1; cmp -s "$T/b1" "$T/b2" || exit 1; (unset TEAM_COMMIT_SCRIPT; bash "$R" < /dev/null 2> "$T/he" | head -c 20000000 > "$T/h"; s=("${PIPESTATUS[@]}"); test "${s[0]}" = 0 && test "${s[1]}" = 0) || rc=1; cmp -s "$T/b1" "$T/h" || rc=1; test "$rc" -eq 0

- [ ] **AC3** (#718 class 1; D2.) A `local`-mode fixture with a `TEAM_RUN_BASE` override (for example `.custom`) that is not ignored. It asserts exit 0, exactly one `base directory in local mode:` item under `Required:` naming `` `/<override>/` `` and the clone's exclude file, no item naming `.shell-team/`, and `nogit` on stdout and stderr. Its suite line begins `PASS: T-1190 AC3 ` (and `FAIL: T-1190 AC3 ` when it fails).
  - check: rc=0; R=tests/setup/run.sh; test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac3.XXXXXX") || exit 1; ulimit -f 400000 2>/dev/null; bash "$R" < /dev/null 2>&1 | head -c 20000000 > "$T/o"; s=("${PIPESTATUS[@]}"); test "${s[1]}" = 0 || rc=1; test "$(grep -c '^PASS: T-1190 AC3 ' "$T/o")" = 1 || rc=1; grep -q '^FAIL: T-1190 AC3 ' "$T/o"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (#718 class 2; D2.) A `local`-mode fixture with `TEAM_RUN_BASE=ops/st` and the pattern `/ops/` in the clone's `info/exclude`. It asserts exit 0, exactly one `base directory in local mode:` item under `Already in place:` naming `ops/st/`, no such item under `Required:`, and `nogit` on stdout and stderr. Its suite line begins `PASS: T-1190 AC4 `.
  - check: rc=0; R=tests/setup/run.sh; test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac4.XXXXXX") || exit 1; ulimit -f 400000 2>/dev/null; bash "$R" < /dev/null 2>&1 | head -c 20000000 > "$T/o"; s=("${PIPESTATUS[@]}"); test "${s[1]}" = 0 || rc=1; test "$(grep -c '^PASS: T-1190 AC4 ' "$T/o")" = 1 || rc=1; grep -q '^FAIL: T-1190 AC4 ' "$T/o"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** (#718 class 3; D2.) Two `local`-mode fixtures whose ignore rule for `/.shell-team/` lives outside `info/exclude`: one in the root `.gitignore`, one in a global excludes file supplied through `gcf`/`stg`. Each asserts exit 0, exactly one `base directory in local mode:` item under `Already in place:` naming `.shell-team/`, no such item under `Required:`, and `nogit` on stdout and stderr; the root-`.gitignore` fixture also asserts that setup left the root `.gitignore` bytes unchanged. These assert outcome equivalence with the `info/exclude` source; `bin/team-setup.sh` reads only the matched pattern, so they do not exercise a distinct code path. Suite lines begin `PASS: T-1190 AC5 root-gitignore ` and `PASS: T-1190 AC5 global-excludes `.
  - check: rc=0; R=tests/setup/run.sh; test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac5.XXXXXX") || exit 1; ulimit -f 400000 2>/dev/null; bash "$R" < /dev/null 2>&1 | head -c 20000000 > "$T/o"; s=("${PIPESTATUS[@]}"); test "${s[1]}" = 0 || rc=1; for k in root-gitignore global-excludes; do test "$(grep -c "^PASS: T-1190 AC5 $k " "$T/o")" = 1 || rc=1; done; grep -q '^FAIL: T-1190 AC5 ' "$T/o"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC6** (#718 class 4; D2.) A `local`-mode fixture on `--host claude-code` with the existing `check-ignore` exit-128 PATH stub first on PATH. It asserts exit 2, stderr containing `could not evaluate` and `.shell-team/`, no line beginning `- base directory in local mode: ` on stdout, and `nogit` on stdout and stderr. Its suite line begins `PASS: T-1190 AC6 `.
  - check: rc=0; R=tests/setup/run.sh; test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac6.XXXXXX") || exit 1; ulimit -f 400000 2>/dev/null; bash "$R" < /dev/null 2>&1 | head -c 20000000 > "$T/o"; s=("${PIPESTATUS[@]}"); test "${s[1]}" = 0 || rc=1; test "$(grep -c '^PASS: T-1190 AC6 ' "$T/o")" = 1 || rc=1; grep -q '^FAIL: T-1190 AC6 ' "$T/o"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC7** (D3; N3.) No recursive deletion. Neither suite matches the pattern `rm -[a-zA-Z]*[rR]|find .*-delete`. In this spec, once every literal occurrence of that pattern string is removed from each line, no line matches it; the pattern string itself occurs in this spec (positive control that the read happened).
  - check: rc=0; K='rm -[a-zA-Z]*[rR]|find .*-delete'; S=.shell-team/specs/T-1190-local-mode-followups-tests.md; for f in tests/team-commit/run.sh tests/setup/run.sh "$S"; do test -r "$f" || exit 1; done; for f in tests/team-commit/run.sh tests/setup/run.sh; do grep -qE -- "$K" "$f"; r=$?; test "$r" = 1 || rc=1; done; test "$(grep -cF -- "$K" "$S")" -ge 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac7.XXXXXX") || exit 1; awk -v k="$K" '{ s = $0; o = ""; while ((i = index(s, k)) > 0) { o = o substr(s, 1, i - 1); s = substr(s, i + length(k)) } print o s }' "$S" > "$T/x" || exit 1; test "$(grep -c '' "$T/x")" = "$(grep -c '' "$S")" || exit 1; grep -qE -- "$K" "$T/x"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC8** (D3.) `shellcheck` exits 0 on `tests/team-commit/run.sh` and `tests/setup/run.sh`.
  - check: rc=0; for f in tests/team-commit/run.sh tests/setup/run.sh; do test -r "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac8.XXXXXX") || exit 1; shellcheck tests/team-commit/run.sh tests/setup/run.sh > "$T/sc" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC9** (D3; N1.) Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed: the committed range `git diff --no-renames --name-only B...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only`, and the untracked strays `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains both `tests/team-commit/run.sh` and `tests/setup/run.sh`.
  - **Allowed members.** `tests/team-commit/run.sh`, `tests/setup/run.sh`, `.shell-team/specs/T-1190-<slug>.md`, `.shell-team/provenance/T-1190.md`, `.shell-team/interventions/T-1190.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1190.md`, a raw capture `.shell-team/reviews/T-1190-codex-<stem>.{txt,jsonl,json}`, `.shell-team/todo.md`, `.shell-team/test-recipe.md`.
  - check: rc=0; P=feature/local-mode-followups-prose; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; else B=$(git merge-base develop HEAD) || exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac9.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF tests/team-commit/run.sh "$T/s" || rc=1; grep -qxF tests/setup/run.sh "$T/s" || rc=1; grep -vxE 'tests/(team-commit|setup)/run\.sh|\.shell-team/(specs/T-1190-[a-z0-9-]+\.md|provenance/T-1190\.md|interventions/(T-1190|no-task)\.md|reviews/T-1190\.md|reviews/T-1190-codex-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** (D3.) Both full suites exit 0: `tests/team-commit/run.sh` (with `TEAM_COMMIT_SCRIPT` unset) prints the line `cases done; failures: 0`, `tests/setup/run.sh` prints the line `setup suite: all assertions passed`, and neither output has a line beginning `FAIL`.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac10.XXXXXX") || exit 1; for R in tests/team-commit/run.sh tests/setup/run.sh; do test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; done; ulimit -f 400000 2>/dev/null; (unset TEAM_COMMIT_SCRIPT; bash tests/team-commit/run.sh < /dev/null 2>&1 | head -c 20000000 > "$T/tc"; s=("${PIPESTATUS[@]}"); test "${s[0]}" = 0 && test "${s[1]}" = 0) || rc=1; grep -qxF 'cases done; failures: 0' "$T/tc" || rc=1; bash tests/setup/run.sh < /dev/null 2>&1 | head -c 20000000 > "$T/su"; s=("${PIPESTATUS[@]}"); test "${s[0]}" = 0 && test "${s[1]}" = 0 || rc=1; grep -qxF 'setup suite: all assertions passed' "$T/su" || rc=1; grep -q '^FAIL' "$T/tc" "$T/su"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** (D2.) The setup suite's change is additions only: `git diff --no-renames --numstat B...HEAD -- tests/setup/run.sh` reports one row with at least one added line and zero deleted lines. This criterion is **merge-point-scoped and expected to go stale** after merge.
  - check: rc=0; P=feature/local-mode-followups-prose; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; else B=$(git merge-base develop HEAD) || exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; R=tests/setup/run.sh; test -r "$R" || exit 1; git cat-file -e "$B:$R" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1190-ac11.XXXXXX") || exit 1; git diff --no-renames --numstat "$B"...HEAD -- "$R" > "$T/ns" || exit 1; awk -F '\t' 'END { exit !(NR == 1 && $1 + 0 > 0 && $2 == "0") }' "$T/ns" || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes**:

1. **A maintainer or mutation self-check running `tests/team-commit/run.sh`**:
   - with `TEAM_COMMIT_SCRIPT` unset (the normal run, CI);
   - with it pointing at a copy whose directory also holds `team-mode.sh`;
   - with it pointing at a standalone copy whose directory holds no `team-mode.sh`.
2. **`bin/team-setup.sh` in `local` record mode on `--host claude-code`**, run by the setup suite in a scratch repository under `$TMPDIR` with `GIT_CONFIG_GLOBAL` pinned, where the base dir is:
   - named by a `TEAM_RUN_BASE` override, single-component (`.custom`) or nested (`ops/st`);
   - ignored by a parent-directory pattern (`/ops/` covering `ops/st/`);
   - ignored by a rule in the root `.gitignore`, or in a global excludes file named by `core.excludesFile`;
   - unreadable to `git check-ignore`, which exits above 1.
3. **CI** running both suites and shellcheck on both (`.github/workflows/check-handoff.yml`).
4. **These check lines** run from a fresh clone, where no gitignored path exists.

**Out-of-scope synthetic extremes**, declined explicitly:

1. A `TEAM_RUN_BASE` that `bin/team-paths.sh` refuses (absolute, `..`, whitespace); the existing suite already covers refusal.
2. A base path with a character outside `A-Za-z0-9._/-` in combination with these four classes.
3. A `check-ignore` failure on the Codex CLI host (a different call site, `bin/team-setup.sh:425-437`).
4. A re-include (`!`) rule from a non-`info/exclude` source.
5. A `TEAM_COMMIT_SCRIPT` copy whose sibling exists but is broken (covered by `bin/team-commit.sh`'s own refusal tests, not by this guard).
6. Hosts or shells other than bash on the CI runner and the maintainer's workstation.

<!-- END intent-block: T-1190 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | One guard for both copy sites; `FAIL` naming `team-mode.sh` and the override dir; runs to the end, exit 1 (D1) | **AC1** |
| 2 | One-line contract comment at the override (D1) | **AC1** |
| 3 | Normal run stdout byte-identical to base; stability checked first (D1; N2) | **AC2** |
| 4 | Fixture per class: override, parent pattern, root `.gitignore` + global excludes, `check-ignore` error (D2) | **AC3**–**AC6** |
| 5 | Each fixture asserts its item, `nogit` on both streams and the exit status (D2) | **AC3**–**AC6** (labels); the assertion content is a reading item for QA plus the engineer's mutation probes — a check line cannot see what a passing fixture asserted |
| 6 | Root `.gitignore` bytes unchanged by setup (D2) | **AC5** (asserted inside the fixture) |
| 7 | Source-field fixtures are outcome equivalence, not a distinct path (Non-goals) | info-only (not promoted to AC): a statement about what the fixtures claim, recorded in **AC5**'s body; no command distinguishes it |
| 8 | Existing setup-suite lines unchanged (D2; Non-goals) | **AC11** |
| 9 | No recursive deletion (D3; N3) | **AC7** |
| 10 | shellcheck clean (D3) | **AC8** |
| 11 | No `bin/` edit; diff confined to suites and records (D3; N1; Non-goals) | **AC9** |
| 12 | Both full suites exit 0 (D3) | **AC10** |
| 13 | A finding needing a `bin/` edit returns to planning (pre-commitment) | info-only (not promoted to AC): a disposition, not a deliverable property; **AC9** makes such an edit red anyway |
| 14 | Drop order and trigger (pre-commitment) | info-only (not promoted to AC): a disposition |
| 15 | No sweep, no whole CI re-run, no past specs' check lines (Non-goals) | info-only (not promoted to AC): process exclusions leaving no trace beyond **AC9** |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. The operator's 2026-10-01 ruling forbids running past specs' check lines locally, and the A2 ruling drops per-task sweeps. CI and this task's own check lines decide the impact, as in T-1185 and T-1189.
- **Known readers of the edited paths** (Grep tool over `.shell-team/specs` for `tests/(setup|team-commit)/run\.sh`; a lower bound — a criterion reaching these paths through indirection stays unmeasured, and that is disclosed): T-1163, T-1164, T-1166, T-1169, T-1171, T-1173, T-1174, T-1176, T-1177, T-1180, T-1183, T-1184. The ones read in this session (T-1180, T-1183, T-1184) run the suites and require exit 0 with no `FAIL` line, read helper line ranges as sources, or compare against their own bases (merge-point-scoped). **AC10** keeps both suites green; **AC11** keeps every existing setup-suite line in place, so existing labels survive; the team-commit suite's stdout is unchanged (**AC2**).
- **Adopter-side artifacts.** None; nothing under `tests/` is shipped into an adopter's environment.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| #712 team-commit suite guard | not met | not met (tests only) | PATCH | test-harness robustness |
| #718 setup fixtures | not met | not met (tests only) | PATCH | added test coverage |

The derived tier is PATCH, the maximum of the column.

## Assumptions

- **Measured by this role** (Read and Grep tools at `8b917f80`): every line anchor in `## Summarized sources`; `refs/heads/feature/local-mode-followups-prose` and `HEAD` both at `8b917f80d11b0deb40a00a1ef18c4a8a15cba0a8` (read from `.git/refs/heads/`), so `B` resolves to `8b917f80` today; the recursive-deletion pattern matches neither suite, nor `bin/team-setup.sh`, `bin/team-commit.sh`, `bin/team-mode.sh`, `bin/team-paths.sh`; `T-1190` occurs 0 times under `tests/`.
- **Relayed (owner: the coordinating session).**
  - The parent-directory premise for **AC4**: in a scratch repository with `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`, `mkdir -p ops/st`, `/ops/` in `.git/info/exclude`, `printf '%s\0' ops/st/ | git check-ignore -v -z --stdin` printed `.git/info/exclude`, `1`, `/ops/`, `ops/st/` (NUL-separated). Measured by the coordinating session on 2026-10-12; this role has no shell.
  - Whether `errexit` fires inside `disable_marker`'s command substitution (`:537`, `:552`): reasoned, not executed. In bash outside POSIX mode, a command-substitution subshell does not inherit `-e` unless `inherit_errexit` is set (it is not), so the `:527` failure likely does not abort and the case then fails on the copy's own `mode` refusal; the `:499` copy is at top level and aborts. The engineer probes this before writing the guard.
  - The issue bodies, as supplied in the scratchpad file.
- **Runtime, unmeasured.** The setup suite's wall time is not measured here; **AC3**–**AC6** and **AC10** each run it. The freeze run measures one run and sets `CHECK_ACS_TIMEOUT` accordingly.
- **Fresh-clone limit of the discriminator.** While PR #743 is open, a fresh clone resolves `B` through the `refs/remotes/origin/` arm. After the predecessor is merged and deleted, the fallback names a local `develop`; a clone carrying only `origin/develop` makes the line exit 1 (fail closed), which is acceptable for merge-point-scoped criteria.
- **Own-coinage count premises** (expected 0 at `B`; the freeze run measures with `git show "$B:tests/setup/run.sh" | grep -c 'T-1190'`): the label prefixes `PASS: T-1190 AC3 ` … `PASS: T-1190 AC6 `.
- **Borrowed tokens** (the freeze run measures each at `B`): `cases done; failures: ` in `tests/team-commit/run.sh` (expected 1 printf site); `setup suite: all assertions passed` in `tests/setup/run.sh` (expected 1); `team-mode.sh` on a comment line that also names `TEAM_COMMIT_SCRIPT` (expected 0); the recursive-deletion pattern in both suites (expected 0).
- **Pre-implementation expectation (for the freeze read).** **AC1** red (the suite aborts at `:499`, no trailer; no contract comment). **AC2** green (an invariant). **AC3**–**AC6** red (no `T-1190` labels). **AC7** and **AC8** green. **AC9** red on its positive control. **AC10** green. **AC11** red (no numstat row).

## Open questions

- None blocking.

## Notes for engineer

- **Files.** `tests/team-commit/run.sh`, `tests/setup/run.sh`, provenance, `.shell-team/test-recipe.md` as usual. No `bin/` file; a finding that needs one returns to planning.
- **Label prefixes the checks read.** `PASS: T-1190 AC3 `, `PASS: T-1190 AC4 `, `PASS: T-1190 AC5 root-gitignore `, `PASS: T-1190 AC5 global-excludes `, `PASS: T-1190 AC6 ` — each printed exactly once, through the suite's existing `pass`/`fail` helpers so the failing form begins `FAIL: T-1190 ACn `. The rest of each description is your call.
- **#712.** Probe the `errexit`-in-command-substitution question first. Then route both copy sites through one guard. Keep every existing `pass` string byte-identical (**AC2**). The guard's `FAIL` names `team-mode.sh` and `$(dirname "$SCRIPT")`.
- **#718.** Add fixtures after the existing `local`-mode block and before the trailer; change no existing line (**AC11**). Reuse `LMP`, `lmrepo`, `nogit`, `sec`, `st`, `stg`, `gcf` and the `$T/gs/git` stub. Pass `TEAM_RUN_BASE` per call (the suite unsets it at `:44`). For **AC6**, run on `--host claude-code` so the Codex-host `check-ignore` call at `bin/team-setup.sh:428` does not run.
- **Mutation probes.** Before hand-off, in a scratch copy under `$TMPDIR`, break each new fixture's subject once and confirm it goes red, then restore. Suggested: make the **AC4** fixture expect the item under `Required:`; make the **AC6** fixture expect exit 0; remove the guard and confirm **AC1** fails; change one existing `pass` string and confirm **AC2** fails.
- **Runtime.** Run long suites in their own process group with a timeout that kills the group, under `ulimit -f`, with output capped by `head -c`.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** Dev-scaffold (operator ruling 2026-08-22): the inline check lines are reviewed for computed value, conclusion direction and real instrument defects, not adversarial completeness.
