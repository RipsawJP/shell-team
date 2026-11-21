# CI is green on today's runner image: discover-work resolves its own directory without `dirname`, and log-run's append lock never hands two writers the same `seq`

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1194

## Problem

CI is red on `develop`'s tip with the current `ubuntu-latest` image (issue #762). Two shipped scripts are at fault.

- **`bin/discover-work.sh` depends on `dirname`, and on bash tolerating `cd ""`.** Its self-resolution runs `cd "$(dirname "$script_path")"`. The discover-work suite's AC4a runs the script with a `PATH` that holds only `bash awk grep sed tr`. With `dirname` missing, the substitution is empty. Under bash 5.2 `cd ""` succeeded silently, and the script fell back to the caller's working directory as its own. Under bash 5.3.9 `cd ""` fails, and the script exits `1`. Either way, a script whose header declares "bash + `gh`" as its only external dependencies calls `dirname`. The fallback also picks the wrong directory for its sibling `team-paths.sh`.
- **`bin/log-run.sh --seq auto` can hand two concurrent writers the same `seq`.** In one CI job, the suite's 8-writer × 20-row contention arm was repeated ten times. Nine runs were clean. One wrote 160 rows, every writer exited `0`, and `seq` 151 appeared twice while 160 was missing. The header promises that "no second writer can take the same number in between". On this runner that promise did not hold, and an adopter on a slow or busy host can get duplicate `seq` values in its telemetry. The v2 diagnosis found the cause. The runner's `mkdir` is uutils coreutils, and under concurrency it reports success to more than one caller, so `mkdir` alone no longer makes the lock exclusive. A third red step, the check-intent suite's AC8 counterfactual, depends on bash tolerating `cd ""` in the same way discover-work did.

This task is a prerequisite of sprint codex-model-pin, not its goal: CI must be green for the batch merge.

## Summarized sources

- **Issue #762, title only**: "CI is red on develop's tip with today's runner image". Its body was not relayed to this role and is not quoted. Restated by the Problem section only.
- **The coordinating session's CI measurements** (diagnostic draft PR #764, test-only, 2026-11-21). These are relayed, not measured by this role; see Assumptions. Distinctions carried over:
  - The runner: image `20261116.202.1`, Ubuntu 26.04.1 LTS, bash 5.3.9, `nproc=4`. The last green `develop` run was 2026-10-15.
  - discover-work AC4a is **deterministic**. Its output is `line 47: dirname: command not found` followed by `line 47: cd: null directory`, with exit `1`.
  - The log-run contention failure is **intermittent**: 9 runs OK and 1 MISMATCH in ten repetitions. All 160 rows were present, every writer exited `0`, `seq` 151 was duplicated and 160 was missing. The second-appended duplicate carries the earlier `ts` (about 3 s earlier). Locally (bash 5.2, 24 cores) the arm passed 5 of 5.

  Restated by the Problem section, the Goal sentence, D1–D4, Input space and Assumptions.
- **`bin/discover-work.sh` at `2c4d05bb`**:
  - `:22-25`: external dependencies are "bash + `gh`". With `gh` absent the script still exits `0`.
  - `:37-47`: self-resolution. `:44` (relative symlink target) and `:47` both run `$(cd "$(dirname "$script_path")" && pwd)`. `:41` uses `readlink`, only for a symlinked invocation.
  - `:99-100`: `bash "$SCRIPT_DIR/team-paths.sh"`. `:100` runs whenever `TEAM_SPECS_DIR` is unset, even with `--todo`.
  - `:192-195`: with `gh` absent, it prints `# note: gh CLI not found — …` and exits `0`.

  Restated by D1, **AC1**, **AC2** and Input space.
- **`tests/discover-work/run.sh` at `2c4d05bb`**: `:78-93` is AC4a. It builds a `PATH` of `bash awk grep sed tr` only, runs `--todo /nonexistent`, and asserts exit `0` and `grep -qi 'not found'`. That grep is also satisfied by the line `dirname: command not found`. `:28-29`: `fail` prints `FAIL: <msg>` on stderr and exits `1`; `pass` prints `PASS: <msg>`. Restated by **AC2**.
- **`bin/log-run.sh` at `2c4d05bb`**:
  - `:123-182`: the T-1076 header, printed by `--help` (`:186-189`). Every append is serialized behind a `mkdir` lock at `<runs>/.<loop_id>.jsonl.lock`, with a bounded wait (`TEAM_LOG_LOCK_TIMEOUT`, default 10 s). On timeout the script writes nothing and exits `3`. "The lock is NEVER stolen". Release is `rmdir` only, and only for a lock this process acquired. "The scan and the append happen under ONE acquisition of the lock, so no second writer can take the same number in between."
  - `:195-203`: the same combined `dirname` self-resolution as discover-work.
  - `:417-436`: `compute_auto_seq`.
  - `:438`: `TS` is taken before the lock is acquired.
  - `:602-652`: `release_lock`, guarded by `LOCK_ACQUIRED`, the EXIT/INT/TERM traps, and the acquisition loop. That loop does `mkdir`, then on failure checks the timeout and does `sleep 1`. It has no age heuristic and no path that removes another writer's lock.
  - `:654-669`: the critical section. `FINAL_SEQ="$(compute_auto_seq …)"`, the row assembled through `$(jnum …)`, `printf … >> "$FILE"`, then `release_lock`.

  Restated by D2, D3, Non-goals, **AC3**, **AC4** and Assumptions.
- **`tests/log-run/run.sh` at `2c4d05bb`**:
  - `:345-443`: the T-1076 contention arm. `CONT_N=8`, `CONT_M=20`, `TEAM_LOG_LOCK_TIMEOUT=30`, every writer's exit status checked.
  - `:442`: the seq-set failure message ends `(duplicate or gap)`.
  - `:578` and `:716-743`: the precedent for widening a race window. A `sed` or range replacement injects a `sleep` into a **scratch copy** of the writer, anchored on exact source lines such as `while :; do` and `# --- critical section: …`.

  Restated by D2, D4, **AC3**–**AC5** and Notes for engineer.
- **`bin/` occurrences of `dirname` at `2c4d05bb`.** Read file by file; the inventory is frozen in **AC8**, and `## Class sweep` carries the derivation. No `bin/` script sources another, so no helper is reached by sourcing. Restated by **AC8** and `## Class sweep`.
- **Shipped prose naming the lock guarantee.** All of them state that the lock makes concurrent `--seq auto` appends safe, and the fix makes that true again:
  - `README.md:246` and `README.ja.md:246`;
  - `skills/run/SKILL.md:305` and `:325`;
  - `templates/prompt-blocks/fanout-orchestration.md:22`.

  Restated by Blast radius.
- **`CLAUDE.md` `## Working rules`** and `## Security invariant`: `bin/` stays pure bash, zero-dependency and shellcheck-clean, and the workflow's only action is `actions/checkout`. Restated by D1 and Non-goals.
- **`.github/workflows/check-handoff.yml`**:
  - `:12`: `runs-on: ubuntu-latest`;
  - `:29`: the `shellcheck` step, which lists all four files this task edits;
  - `:86-87`: `Run log-run resolution suite`;
  - `:95-96`: `Run discover-work fixture suite`.

  Restated by **AC11**.
- **The coordinating session's v2 diagnostic measurements** (PR #764, 2026-11-21), recorded in Assumptions as measured on that side. The distinctions carried over: uutils `mkdir` 0.10.0 reports success to more than one concurrent caller (29 of 300 rounds, at most 3 winners) and GNU 9.4 does not (0 of 300); the EXIT-trap-in-`$(…)` lead is refuted; and the complete red set is exactly three steps. Restated by D2, D5, Input space 5 and **AC9**.
- **`tests/check-intent/run.sh:728-806` at `2c4d05bb`.** The AC8 case asserts exit `2` and the `usage` token only (`:750-751`). The counterfactual's inline OLD bootstrap (`:777-797`) is asserted to exit `0` (`:805`). Restated by D5 and **AC13**.
- **`bin/check-intent.sh:189-192` at `2c4d05bb`.** The split guard: `|| fail_usage "dirname failed to resolve this script's own directory for: $script_path"` at `:190`, then the `cd`/`pwd` guard at `:191-192`. Restated by D5 and **AC13**.
- **`tests/log-run/run.sh:445-458` at `2c4d05bb`.** The T-1076 `lock-timeout-refusal` case pre-holds a token-less lock directory with a plain `mkdir` (`:448`) and expects exit `3`. Restated by D2's "existing directory" rule and **AC12**.
- **`tests/retro-inputs/run.sh:52`**: its restricted `PATH` holds `bash awk grep sed tr git head cat dirname readlink`, so `dirname` stays available there. Restated by **AC8**.
- **`tests/bin-help/run.sh:2-9`**: every tracked `bin/` entry, enumerated with `git ls-files -- bin/` rather than by a glob, must answer `--help`. Restated by **AC7**.
- **`bin/derive-populations.sh:79`**: the zero-dependency floor `bin/` inherits is bash 3.2. Restated by Input space 2.
- **`CONTRIBUTING.md` `## What a version number encodes`**: PATCH covers bug fixes. Restated by `## Version`.
- **`bin/check-interventions.sh:8`**: `<base>/interventions/<task-id>.md`, or `no-task.md`. Restated by **AC9**'s allow-list.

## Goal

<!-- BEGIN intent-block: T-1194 -->

- user-visible: yes — an adopter running concurrent `log-run.sh --seq auto` writers on one runs file no longer gets two rows with the same `seq`, which corrupted the per-run counter their telemetry relies on; `discover-work.sh` no longer needs `dirname` and resolves its own directory correctly on bash 5.3.
- shipped-docs: bin/log-run.sh — this-task
- shipped-docs: bin/discover-work.sh — this-task
- verification-class: mechanism — the diff changes two shipped `bin/` scripts, one of them a concurrency lock, their fixture suites, and one counterfactual in the check-intent suite.
- verification-ceiling: unit-and-static — **AC1**–**AC10**, **AC12** and **AC13** are settled in a plain checkout under whatever bash and `mkdir` the checkout has. They do the following:
  - run HEAD's and the base commit's scripts on fixtures under `$TMPDIR`, including a `mkdir` stub that models the measured uutils behaviour;
  - run the suites on HEAD, and on a `git archive` copy of HEAD with one script reverted or mutated;
  - run the other suites that execute the two scripts;
  - read the exit codes of shellcheck, `check-adopter-docs.sh` and `check-handoff.sh`.

  **AC11** (CI on the pull request, bash 5.3.9, uutils `mkdir`) sits above the ceiling.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1

**Goal (one sentence).** On every invocation shape in Input space 1, including a `PATH` without `dirname`, `discover-work.sh` resolves its own directory with no external command other than `readlink` on the symlink path, and prints no `command not found`. `log-run.sh --seq auto` never gives two concurrent writers the same `seq` for one `run_id`, even where `mkdir` reports success on a directory that already exists. A deterministic fixture fails on every run against the base script and passes against the fixed one, on any local bash. The lock's documented contract is otherwise unchanged: same path, bounded wait, exit `3` with nothing written on timeout, never stolen, and a release that removes only this writer's own owner token and then the directory, never recursively. The check-intent suite's AC8 counterfactual holds on bash 5.2 and 5.3 without becoming vacuous. And every suite's existing cases still pass.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — discover-work self-resolution.** The fix is in the shipped script, not in the test. The script resolves the directory of the file it runs from without calling `dirname` (or any external command), for every reachable invocation shape. `readlink` stays permitted on the symlink path only. A resolution that falls back to the caller's working directory is a defect, whatever the bash version. (**AC1**, **AC2**)
- **D2 — log-run exclusivity does not trust `mkdir`'s reported success (v2, coordinating-session decision).** The measured cause: on the CI runner, `mkdir` is uutils coreutils 0.10.0. Under concurrent calls on one path, more than one call reports success (Assumptions). The fix is in the shipped `bin/log-run.sh`. The lock keeps its directory at the same path, and ownership becomes exclusive by a means that does not depend on `mkdir`'s exit status:
  - **Owner token.** A writer holds the lock only when it has itself created the file `owner` inside the lock directory, by an exclusive create that fails if the file exists. bash's own `noclobber` redirection gives this, with no external command.
  - **Failed claim.** A writer whose `mkdir` reported success but whose token creation failed does not hold the lock. It treats the lock as held by another writer and keeps waiting within the bounded wait.
  - **Existing directory.** A lock directory that already exists is held, whether or not it carries an owner token. This is a pm-spec refinement of the coordinating session's design; see the hand-off. Without it, a token-less directory (one left by an older `log-run.sh`, by a holder killed between creating the directory and the token, or by the T-1076 refusal case's pre-held lock) would count as held under GNU `mkdir` but be taken under uutils `mkdir`. That is a host-dependent steal.

  The evidence is deterministic and host-independent. A `mkdir` stub on `PATH` that always exits `0`, creating the directory when it is missing, models the measured uutils behaviour. Under it:
  - a pre-held lock makes the fixed script wait and exit `3` with nothing written, where the base script writes;
  - concurrent writers get exactly `1..N`.

  The suite fixture is labelled `T-1194 log-run-exclusive`. Its exclusivity failures read `FAIL: T-1194 log-run-exclusive: …` and its setup failures `FAIL: T-1194 log-run-exclusive-setup: …`. "Ran N times without failure" is not evidence. (**AC3**, **AC4**, **AC12**)
- **D3 — the lock's contract, otherwise unchanged.** These stay as they are:
  - the lock path;
  - `TEAM_LOG_LOCK_TIMEOUT` and its 10 s default;
  - exit `3` with nothing written on timeout;
  - never stealing a lock;
  - the INT/TERM handling;
  - the set of `TEAM_*` variables the script reads (no test-only hook in the shipped script);
  - every existing T-1076 case.

  Release (v2) removes this writer's own owner token and then `rmdir`s the directory. It never removes recursively, and it never touches a token this writer did not create. The timeout refusal names the lock path and tells the operator how to remove a lock by hand: remove `owner` if present, then `rmdir` the directory. The `--help` header keeps stating that the lock is never stolen and naming the lock path. (**AC3**, **AC12**)
- **D5 — the check-intent AC8 pair holds on every bash (v2).** In `tests/check-intent/run.sh`, the AC8 case and its counterfactual are restated so they hold on bash 5.2 and 5.3:
  - **AC8 (NEW split guard).** With `dirname` failing, the shipped checker exits `2`, and its stderr carries the dirname-specific refusal `dirname failed to resolve`, not merely the `usage` token. On bash 5.3 the OLD form also exits `2`, by its `cd`/`pwd` refusal, so exit status alone no longer discriminates.
  - **The counterfactual (OLD unsplit bootstrap).** It never produces that dirname-specific refusal. It exits `0`, failing open into the working directory, where `cd ""` succeeds (bash 5.2 and earlier). It exits `2` through its `cd`/`pwd` refusal where `cd ""` fails (bash 5.3). Any other status fails the fixture.

  The pair is non-vacuous: mutating the shipped checker's split guard into a non-refusing one makes the suite fail on an AC8 line on either bash. (**AC13**)
- **D4 — the T-1076 seq-set message says which.** The `T-1076 contention-auto-seq-set` failure message names the duplicated `seq` values and the missing ones, instead of "(duplicate or gap)". (**AC5**, droppable 1)

**Pre-commitment (frozen before round 1).** The trigger, the route-back rules and the drop order below are AI self-discipline proposed by this role, never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning:
  - (N1) D2, the lock's exclusivity (**AC3**, **AC4**, **AC12**);
  - (N2) D1, the discover-work self-resolution fix (**AC1**, **AC2**).
- **Route-back, not a weaker criterion.** Either of these returns the task to planning with the measurements attached:
  - the `mkdir`-stub fixture does not fail against the base script on every run, so no fixture meets **AC4**;
  - the owner-token design cannot meet **AC12** and the existing T-1076 cases together.
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same droppable component. A round interrupted before a verdict does not count.
- **Droppable, in order.** A drop removes criterion text, so it is a class-B re-freeze. The dropped part goes to one follow-up issue that carries the rounds' findings as its requirement list.
  1. **The T-1076 message wording (D4, **AC5**).** It is first because it is a diagnostic improvement and not part of the CI-red fix.

## Non-goals

- **No runner-image pin as the fix.** A pin may be decided separately as a mitigation, never in place of fixing the scripts. **AC9** keeps `.github/` out of the diff.
- **No workflow change, no new GitHub Action, no AI in CI.** (**AC9**)
- **The other `bin/` scripts that use `dirname` are not changed.** Each has a frozen disposition in **AC8**. The remaining `dirname` idiom sites are tracked in issue #765, which is filed and not in this task's scope. (**AC9**)
- **No change to `bin/check-intent.sh`.** Only its suite's AC8 pair is restated (D5). (**AC9**)
- **No change to when `ts` is taken.** `ts` stays the time the writer started, taken before the lock is acquired, so `ts` order need not match `seq` order. (info-only)
- **No repair of runs files already written with a duplicate `seq`.** (info-only; Blast radius)
- **No change to `bin/check-run.sh`, including its performance on long rows.** (**AC9**)
- **Nothing from the diagnostic branch of PR #764 is carried into this task.** (**AC9**)
- **No adopter-doc edit.** The shipped prose that states the lock guarantee becomes accurate again with the fix. (**AC9**; Blast radius)
- **No full-population two-arm sweep and no local run of past specs' check lines.** This follows T-1191 to T-1193 and the operator rulings relayed there. (info-only; disclosed in Blast radius)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`. They export a temp `HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and unset `TEAM_RUN_BASE`, `TEAM_TODO`, `TEAM_SPECS_DIR`, `TEAM_RUNS_DIR` and `RUNS_DIR`.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion. No line compares a stream that carries a per-checkout path.
- **Base reads.** Lines that read a base blob resolve `B` with the declaration region's discriminator expression, spelled byte-identically in **AC1**–**AC5**, **AC8**, **AC9** and **AC12**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Suite runs.** Suites run through `tms`: own process group, 1200 s, killed on timeout (status `99`).
  - Before a suite runs, it is scanned for a recursive-deletion pattern with backslash-continued lines joined. The joined text is written to a file first and grepped there, so no pipeline status is read after `grep -q`.
  - In **AC2**–**AC4** and **AC13**, a match is a broken instrument and exits `1`. **AC7** instead excludes a matching suite and names it as CI-covered.

- [ ] **AC1** (D1; N2.) discover-work without `dirname`. The fixture `PATH` is a directory holding only `bash`, `awk`, `grep`, `sed`, `tr` and `readlink`, and `dirname` is first shown not to resolve on it. Each run passes `--todo /nonexistent`. Each working directory used holds a decoy `team-paths.sh` that records that it ran.
  - **Positive control at the base.** The base script, copied beside a real `team-paths.sh` and run by absolute path, prints `command not found`. This holds on bash 5.2 as well as 5.3.
  - **At HEAD**, each invocation shape exits `0`, prints the `gh CLI not found` note, prints no `command not found` on either stream, and never runs the decoy. The shapes:
    - the checkout's own script by absolute path;
    - a copy by absolute path;
    - a relative path with a slash, from the copy's parent directory;
    - a bare name, from the copy's own directory;
    - a symlink with a relative target;
    - a symlink with an absolute target.
  - check: rc=0; export LC_ALL=C; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR DECOY_LOG; mkdir -p "$HOME" "$T/nb" "$T/k/bin" "$T/kb/bin" "$T/cw" "$T/ln" || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/discover-work.sh"; P="$R/bin/team-paths.sh"; test -s "$X" || exit 1; test -s "$P" || exit 1; git show "$B:bin/discover-work.sh" > "$T/kb/bin/discover-work.sh" || exit 1; test -s "$T/kb/bin/discover-work.sh" || exit 1; cp "$X" "$P" "$T/k/bin/" || exit 1; cp "$P" "$T/kb/bin/" || exit 1; cmp -s "$X" "$T/k/bin/discover-work.sh" || exit 1; for t in bash awk grep sed tr readlink; do s=$(command -v "$t") || exit 1; ln -s "$s" "$T/nb/$t" || exit 1; done; env PATH="$T/nb" "$T/nb/bash" -c 'command -v dirname' > /dev/null 2>&1; test "$?" = 1 || exit 1; for d in "$T/cw" "$T/k"; do printf '%s\n' 'printf x >> "$DECOY_LOG"' 'exit 1' > "$d/team-paths.sh" || exit 1; done; ln -s ../k/bin/discover-work.sh "$T/ln/dr" || exit 1; ln -s "$T/k/bin/discover-work.sh" "$T/ln/da" || exit 1; n=0; dw(){ n=$((n + 1)); local c="$1"; shift; ( cd "$c" || exit 97; export DECOY_LOG="$T/decoy-$n"; exec env PATH="$T/nb" "$T/nb/bash" "$@" --todo /nonexistent ) < /dev/null > "$T/out-$n" 2>&1; }; ok(){ test "$1" = 0 && grep -qF 'gh CLI not found' "$T/out-$n" && { grep -qF 'command not found' "$T/out-$n"; test "$?" = 1; } && test ! -e "$T/decoy-$n"; }; dw "$T/cw" "$T/kb/bin/discover-work.sh"; grep -qF 'command not found' "$T/out-$n" || exit 1; for c in "$T/cw|$X" "$T/cw|$T/k/bin/discover-work.sh" "$T/k|bin/discover-work.sh" "$T/k/bin|discover-work.sh" "$T/cw|$T/ln/dr" "$T/cw|$T/ln/da"; do dw "${c%%|*}" "${c#*|}"; s=$?; ok "$s" || { rc=1; printf 'miss %s\n' "${c#*|}"; }; done; test "$rc" -eq 0

- [ ] **AC2** (D1; N2.) The discover-work suite.
  - **At HEAD**, the suite exits `0` under `tms` with no line beginning `FAIL`. Every column-0 literal `pass "…"` label in the base blob of `tests/discover-work/run.sh` (labels without `$`, `"` or a backslash) still prints as `PASS: <label>`; that label set is derived at run time and must be non-empty. At least one line begins `PASS: T-1194 `.
  - **Revert detection.** HEAD's committed tree is extracted with `git archive HEAD`, and only `bin/discover-work.sh` there is replaced with the base blob. The copy's suite exits non-zero, not by timeout, and its log has a line beginning `FAIL: T-1194 discover-work`. This holds on bash 5.2, where the base's `cd ""` still succeeds.
  - Positive control: the replaced script differs from the checkout's.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac2.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR; mkdir -p "$HOME" "$T/h" || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; S=tests/discover-work/run.sh; test -s "$S" || exit 1; git show "$B:$S" > "$T/bs" || exit 1; sed -n 's/^pass "\([^"$\\]*\)"$/\1/p' "$T/bs" > "$T/lab" || exit 1; test -s "$T/lab" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; git archive HEAD > "$T/h.tar" || exit 1; tar -xf "$T/h.tar" -C "$T/h" || exit 1; M="$T/h/$S"; test -s "$M" || exit 1; for f in "$S" "$M"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; done; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; while IFS= read -r l; do grep -qxF "PASS: $l" "$T/log" || { rc=1; printf 'missing: %s\n' "$l"; }; done < "$T/lab"; grep -q '^PASS: T-1194 ' "$T/log" || rc=1; git show "$B:bin/discover-work.sh" > "$T/h/bin/discover-work.sh" || exit 1; test -s "$T/h/bin/discover-work.sh" || exit 1; cmp -s "$T/h/bin/discover-work.sh" bin/discover-work.sh; test "$?" = 1 || rc=1; tms "$M" "$T/rlog"; s=$?; test "$s" -ne 0 || rc=1; test "$s" -ne 99 || rc=1; grep -q '^FAIL: T-1194 discover-work' "$T/rlog" || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D2, D3; N1.) The log-run suite at HEAD, and the lock's contract.
  - **Suite.** `tests/log-run/run.sh` exits `0` under `tms` on each of two consecutive runs, with no line beginning `FAIL`. Every column-0 literal `pass "T-1076 …"` label in the base blob (labels without `$`, `"` or a backslash) prints as `PASS: <label>` in both logs; that set is derived at run time and must be non-empty. Each log has a line beginning `PASS: T-1194 log-run-exclusive`.
  - **No new hook.** The sorted set of `TEAM_*` tokens in `bin/log-run.sh` equals the base blob's set.
  - **Contract text.** `--help` exits `0`, contains `never stolen` (case-insensitive), and contains `<runs>/.<loop_id>.jsonl.lock`. Positive control: the base blob's `--help` contains both.
  - That the `T-1194 log-run-exclusive` fixture exercises the shipped writer is a QA reading item: it runs `bin/log-run.sh` itself, or a scratch copy that differs from it only by inserted delay lines. So is the provenance record stating the measured root cause.
  - adopter-surface: the `--help` header of bin/log-run.sh (its T-1076 paragraph). It keeps stating that the scan and the append happen under one acquisition so no second writer can take the same number, which this task makes hold. Any change to how the lock achieves that is described there.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac3.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; L=bin/log-run.sh; S=tests/log-run/run.sh; test -s "$L" || exit 1; test -s "$S" || exit 1; git show "$B:$S" > "$T/bs" || exit 1; git show "$B:$L" > "$T/bl" || exit 1; test -s "$T/bl" || exit 1; sed -n 's/^pass "\(T-1076 [^"$\\]*\)"$/\1/p' "$T/bs" > "$T/lab" || exit 1; test -s "$T/lab" || exit 1; grep -oE 'TEAM_[A-Z0-9_]+' "$T/bl" > "$T/eb0" || exit 1; sort -u "$T/eb0" > "$T/eb" || exit 1; grep -oE 'TEAM_[A-Z0-9_]+' "$L" > "$T/eh0"; test "$?" = 0 || rc=1; sort -u "$T/eh0" > "$T/eh" || exit 1; cmp -s "$T/eb" "$T/eh" || rc=1; bash "$T/bl" --help > "$T/hb" 2>&1 || exit 1; grep -qi 'never stolen' "$T/hb" || exit 1; grep -qF '<runs>/.<loop_id>.jsonl.lock' "$T/hb" || exit 1; bash "$L" --help > "$T/hh" 2>&1; test "$?" = 0 || rc=1; grep -qi 'never stolen' "$T/hh" || rc=1; grep -qF '<runs>/.<loop_id>.jsonl.lock' "$T/hh" || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; for k in 1 2; do tms "$S" "$T/log$k"; test "$?" -eq 0 || { rc=1; printf 'suite run %s failed\n' "$k"; }; grep -q '^FAIL' "$T/log$k"; test "$?" = 1 || rc=1; while IFS= read -r l; do grep -qxF "PASS: $l" "$T/log$k" || { rc=1; printf 'missing in run %s: %s\n' "$k" "$l"; }; done < "$T/lab"; grep -q '^PASS: T-1194 log-run-exclusive' "$T/log$k" || rc=1; done; test "$rc" -eq 0

- [ ] **AC4** (D2; N1.) The exclusivity fixture is deterministic against the base. HEAD's committed tree is extracted with `git archive HEAD`, and only `bin/log-run.sh` there is replaced with the base blob. The copy's `tests/log-run/run.sh` then runs three times under `tms`. On **each** run:
  - it exits non-zero, and not by timeout;
  - its log has a line beginning `FAIL: T-1194 log-run-exclusive:` (the colon directly after the label, so a setup failure cannot satisfy it);
  - its log has no line beginning `FAIL: T-1194 log-run-exclusive-setup`.

  Positive control: the replaced script differs from the checkout's.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac4.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR; mkdir -p "$HOME" "$T/h" || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; git archive HEAD > "$T/h.tar" || exit 1; tar -xf "$T/h.tar" -C "$T/h" || exit 1; M="$T/h/tests/log-run/run.sh"; test -s "$M" || exit 1; git show "$B:bin/log-run.sh" > "$T/h/bin/log-run.sh" || exit 1; test -s "$T/h/bin/log-run.sh" || exit 1; cmp -s "$T/h/bin/log-run.sh" bin/log-run.sh; test "$?" = 1 || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$M" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; for k in 1 2 3; do tms "$M" "$T/rlog$k"; s=$?; test "$s" -ne 0 || rc=1; test "$s" -ne 99 || rc=1; grep -q '^FAIL: T-1194 log-run-exclusive:' "$T/rlog$k" || { rc=1; printf 'run %s: no exclusivity failure\n' "$k"; }; grep -q '^FAIL: T-1194 log-run-exclusive-setup' "$T/rlog$k"; test "$?" = 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC5** (D4, droppable 1.) The T-1076 seq-set message says which. In `tests/log-run/run.sh`, `(duplicate or gap)` no longer occurs. The lines carrying the label `contention-auto-seq-set` include the words `duplicated` and `missing`, and the message prints the duplicated and the missing `seq` values. That the values are printed is a QA reading item.
  - Positive control: the base blob contains `(duplicate or gap)`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac5.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; S=tests/log-run/run.sh; test -s "$S" || exit 1; git show "$B:$S" > "$T/bs" || exit 1; grep -qF '(duplicate or gap)' "$T/bs" || exit 1; grep -qF '(duplicate or gap)' "$S"; test "$?" = 1 || rc=1; grep -F 'contention-auto-seq-set' "$S" > "$T/l"; test "$?" = 0 || rc=1; grep -qF duplicated "$T/l" || rc=1; grep -qF missing "$T/l" || rc=1; test "$rc" -eq 0

- [ ] **AC6** shellcheck exits `0` on `bin/log-run.sh`, `bin/discover-work.sh`, `tests/log-run/run.sh`, `tests/discover-work/run.sh` and `tests/check-intent/run.sh`. None of the five matches the recursive-deletion pattern once backslash-continued lines are joined.
  - check: rc=0; export LC_ALL=C; L=(bin/log-run.sh bin/discover-work.sh tests/log-run/run.sh tests/discover-work/run.sh tests/check-intent/run.sh); for f in "${L[@]}"; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac6.XXXXXX") || exit 1; shellcheck "${L[@]}" > "$T/sc" 2>&1 || rc=1; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e'; for f in "${L[@]}"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || rc=1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** (D3; Blast radius.) The other suites that execute either script stay green.
  - **The set**, derived at run time: every `tests/*/run.sh` that names `log-run.sh` or `discover-work.sh`, except the two suites **AC2** and **AC3** run, plus `tests/bin-help/run.sh`. That last one reaches every `bin/` entry through `git ls-files -- bin/` rather than by name.
  - **Scan.** Each derived suite is scanned for the recursive-deletion pattern, with backslash-continued lines joined.
    - A suite that matches is never run locally. It is printed as CI-covered, and CI (**AC11**) runs it.
    - A scan that cannot read its suite fails the line.
  - **Run.** Every other suite exits `0` under `tms` with no line beginning `FAIL`.
  - Positive control: the run set contains `tests/check-fanout-instances/run.sh`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac7.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR; mkdir -p "$HOME" || exit 1; grep -lE -- 'log-run\.sh|discover-work\.sh' tests/*/run.sh > "$T/l"; test "$?" = 0 || exit 1; { grep -vxE 'tests/(log-run|discover-work)/run\.sh' "$T/l"; printf '%s\n' tests/bin-help/run.sh; } | sort -u > "$T/suites"; grep -qxF tests/check-fanout-instances/run.sh "$T/suites" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; : > "$T/run" || exit 1; : > "$T/ci" || exit 1; while IFS= read -r S; do test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; if [ "$g" -eq 0 ]; then printf '%s\n' "$S" >> "$T/ci"; elif [ "$g" -eq 1 ]; then printf '%s\n' "$S" >> "$T/run"; else exit 1; fi; done < "$T/suites"; grep -qxF tests/check-fanout-instances/run.sh "$T/run" || exit 1; while IFS= read -r S; do printf 'CI-covered, not run locally (recursive deletion): %s\n' "$S"; done < "$T/ci"; while IFS= read -r S; do tms "$S" "$T/log"; test "$?" -eq 0 || { rc=1; printf 'suite failed: %s\n' "$S"; }; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; done < "$T/run"; test "$rc" -eq 0

- [ ] **AC8** Class sweep: every `bin/` file that contains `dirname` at the base has a disposition below. The population is re-derived at run time from the base commit, and each member must appear in this criterion's text in backticks.
  - **Why only one site is fixed.** The bash-5.3 `cd ""` failure is reachable only when `dirname` is missing from `PATH`, because `dirname` prints a non-empty string for every operand.
    - discover-work's header declares a dependency set without `dirname`. Its suite's AC4a builds a `PATH` without `dirname`, and that is the step CI reported red.
    - The other restricted-`PATH` suite read for this sweep, `tests/retro-inputs/run.sh:52`, keeps `dirname` on its `PATH`.
    - The scripts below are treated as needing `dirname` on `PATH`. Without it, the `cd` in a class-B combined form fails on bash 5.3 and falls back to the working directory on bash 5.2.
    - Those combined forms are a latent defect recorded for a follow-up decision, not fixed here.
  - **A — fixed in this task:** `bin/discover-work.sh` (`:44`, `:47`).
  - **B — combined self-resolution `$(cd "$(dirname …)" && pwd)`, same latent defect, not changed (dirname required on PATH):**
    - `bin/check-codex-agents.sh`, `bin/check-review-input.sh`, `bin/check-setup.sh`, `bin/check-spec-review.sh`, `bin/close-out.sh`, `bin/codex-capture.sh` (`:567`, `:570`), `bin/consolidate-proposals.sh`;
    - `bin/gen-codex-agents.sh`, `bin/gen-loop-replay.sh` (`:126`, `:129`), `bin/gen-playbook-blocks.sh`, `bin/gen-project-status.sh`, `bin/install` (`:40`, `:43`);
    - `bin/log-run.sh` (`:200`, `:203`; this file is edited for D2, but its self-resolution is not required to change);
    - `bin/playbook-promote.sh`, `bin/retro-inputs.sh` (its suite keeps `dirname` on its restricted PATH), `bin/rework-digest.sh` (`:575`), `bin/rollup-track.sh`, `bin/team-commit.sh` (`:75`, `:78`), `bin/team-init.sh` (`:65`, `:68`), `bin/team-setup.sh` (`:104`, `:107`);
    - `bin/check-readme-version.sh` (`:48`). This variant resolves `$(dirname …)/..`, so a missing `dirname` gives `cd "/.."`, not `cd ""`.
  - **C — split and guarded (`…_raw="$(dirname …)" || <refusal>`), fails closed by design, not-apply:** `bin/check-adapter.sh`, `bin/check-adopter-docs.sh`, `bin/check-binding.sh`, `bin/check-commit-identity.sh`, `bin/check-durability.sh`, `bin/check-intent.sh`, `bin/check-interventions.sh`, `bin/check-invocation-path.sh`, `bin/check-liveness.sh` (`:65`, `:73`), `bin/check-model-pins.sh`, `bin/check-oversight.sh`, `bin/check-pii-shapes.sh`, `bin/check-provenance.sh`, `bin/check-refreeze-class.sh`, `bin/check-refreeze-grant.sh`, `bin/check-review-provider.sh`, `bin/codex-await.sh`, `bin/resolve-executor.sh`.
  - **D — `dirname` on a data path, not self-resolution, not-apply (a non-empty operand never yields an empty result):** `bin/check-board-headings.sh` (`:333`, `:378`), `bin/check-count-claims.sh` (`:235`; without `dirname` it falls back to an empty `board_dir`), `bin/check-liveness.sh` (`:426`, guarded), `bin/codex-capture.sh` (`:621-622`, guarded), `bin/gen-loop-replay.sh` (`:221`), `bin/install` (`:271`), `bin/team-commit.sh` (`:287`, guarded), `bin/team-init.sh` (`:285`, `:312`), `bin/team-setup.sh` (`:344`, `:443`).
  - Positive controls: the population is non-empty and contains `bin/discover-work.sh` and `bin/log-run.sh`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac8.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; SP=.shell-team/specs/T-1194-ci-runner-image-red.md; test -s "$SP" || exit 1; git grep -l -e dirname "$B" -- bin/ > "$T/raw"; test "$?" = 0 || exit 1; sed "s|^$B:||" "$T/raw" > "$T/p0" || exit 1; sort -u "$T/p0" > "$T/pop" || exit 1; test -s "$T/pop" || exit 1; grep -qxF bin/discover-work.sh "$T/pop" || exit 1; grep -qxF bin/log-run.sh "$T/pop" || exit 1; awk '/^- \[.\] [*][*]AC8[*][*]/ { f = 1 } /^- \[.\] [*][*]AC9[*][*]/ { f = 0 } f' "$SP" > "$T/reg" || exit 1; test -s "$T/reg" || exit 1; bt=$(printf '\140'); test "${#bt}" = 1 || exit 1; while IFS= read -r f; do grep -qF "$bt$f$bt" "$T/reg" || { rc=1; printf 'not inventoried: %s\n' "$f"; }; done < "$T/pop"; grep -qF "fixed in this task:** ${bt}bin/discover-work.sh${bt}" "$T/reg" || rc=1; test "$rc" -eq 0

- [ ] **AC9** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `bin/log-run.sh` and `bin/discover-work.sh`.
  - **Allowed members.**
    - `bin/log-run.sh` and `bin/discover-work.sh`.
    - `tests/log-run/run.sh` and `tests/discover-work/run.sh`.
    - `tests/check-intent/run.sh`, for the AC8 counterfactual (D5, v2).
    - This task's records: `.shell-team/specs/T-1194-ci-runner-image-red.md`, `.shell-team/provenance/T-1194.md`, `.shell-team/interventions/T-1194.md`, `.shell-team/reviews/T-1194.md`, `.shell-team/reviews/T-1194-drift.md`, and raw captures `.shell-team/reviews/T-1194-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`, the reserved taskless interventions file (`bin/check-interventions.sh:8`).
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac9.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/log-run.sh "$T/s" || rc=1; grep -qxF bin/discover-work.sh "$T/s" || rc=1; grep -vxE 'bin/(log-run|discover-work)\.sh|tests/(log-run|discover-work|check-intent)/run\.sh|\.shell-team/(specs/T-1194-ci-runner-image-red\.md|provenance/T-1194\.md|interventions/(T-1194|no-task)\.md|reviews/T-1194(-drift)?\.md|reviews/T-1194-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** Records conformant.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - Positive control: the spec, the checker and the board are each first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac10.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1194-ci-runner-image-red.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** CI on this branch's pull request is green on `ubuntu-latest`. That includes:
  - the `shellcheck` step;
  - `Run log-run resolution suite`, `Run discover-work fixture suite` and `Run check-intent fixture suite`;
  - any suite **AC7** named as CI-covered.

  One green run is evidence for the deterministic fixes, discover-work and the check-intent AC8 pair, on bash 5.3.9. It is not evidence for the lock fix, because the base failed only about one run in ten on the runner. The lock fix is proven by the `mkdir`-stub fixtures (**AC4**, **AC12**), not by CI luck.
  - above-ceiling: the coordinating session, after the push and before the merge GO, recording the check run's result and the runner's bash version on the board. QA reports this criterion as `SKIP`.

- [ ] **AC12** (D2, D3; N1, v2.) The lock is exclusive without trusting `mkdir`, and its contract holds. The stub is a `mkdir` placed ahead on `PATH`. It runs the real `mkdir` with the same arguments, discards its status and stderr, and always exits `0`; it is first shown to exit `0` twice on one path. Every writer below runs with a 2 s bounded wait unless stated otherwise.
  - **Positive control at the base.** With the stub, the base script, given a pre-held lock (directory plus `owner`), exits `0` and writes a row.
  - **Pre-held lock at HEAD.** Four arms: a directory with `owner`, and a token-less directory, each with the stub and with the real `mkdir` on `PATH`. On each arm the script:
    - exits `3`;
    - writes no runs file;
    - leaves the lock directory, and any `owner` in it, in place;
    - prints on stderr the full lock path, the word `owner` and the word `rmdir`.
  - **Concurrency at HEAD.** With the stub, 4 writers × 10 rows of `--seq auto` on one `run_id`, with a 120 s bounded wait. Every writer exits `0`. The file has 40 lines, and its sorted `seq` values equal `1..40` exactly. Afterwards no lock directory remains.
  - check: rc=0; export LC_ALL=C; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac12.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR TEAM_LOG_LOCK_TIMEOUT; mkdir -p "$HOME" "$T/sb" "$T/a0/.lk.jsonl.lock" "$T/a1/.lk.jsonl.lock" "$T/b1/.lk.jsonl.lock" "$T/a2/.lk.jsonl.lock" "$T/b2/.lk.jsonl.lock" "$T/c" || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; L="$R/bin/log-run.sh"; test -s "$L" || exit 1; git show "$B:bin/log-run.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; RM=$(command -v mkdir) || exit 1; printf '%s\n' '#!/bin/sh' "\"$RM\" \"\$@\" 2> /dev/null" 'exit 0' > "$T/sb/mkdir" || exit 1; chmod +x "$T/sb/mkdir" || exit 1; SP="$T/sb:$PATH"; env PATH="$SP" mkdir "$T/sx" || exit 1; env PATH="$SP" mkdir "$T/sx" || exit 1; test -d "$T/sx" || exit 1; for d in a0 a1 a2; do : > "$T/$d/.lk.jsonl.lock/owner" || exit 1; done; wr(){ env PATH="$3" TEAM_RUNS_DIR="$2" TEAM_LOG_LOCK_TIMEOUT="$4" bash "$1" lk --run-id X --seq auto --span s --phase p --iteration 0 --attempt 1 --status success --instance "$5" < /dev/null > /dev/null 2> "$6"; }; wr "$T/base.sh" "$T/a0" "$SP" 2 w0 "$T/e0"; test "$?" = 0 || exit 1; test -s "$T/a0/lk.jsonl" || exit 1; held(){ local d="$1" s; wr "$L" "$T/$d" "$2" 2 w0 "$T/e-$d"; s=$?; test "$s" = 3 && test ! -e "$T/$d/lk.jsonl" && test -d "$T/$d/.lk.jsonl.lock" && grep -qF "$T/$d/.lk.jsonl.lock" "$T/e-$d" && grep -qF owner "$T/e-$d" && grep -qF rmdir "$T/e-$d"; }; held a1 "$SP" || { rc=1; printf 'miss %s\n' a1; }; held b1 "$SP" || { rc=1; printf 'miss %s\n' b1; }; held a2 "$PATH" || { rc=1; printf 'miss %s\n' a2; }; held b2 "$PATH" || { rc=1; printf 'miss %s\n' b2; }; for d in a1 a2; do test -f "$T/$d/.lk.jsonl.lock/owner" || rc=1; done; pids=(); for i in 1 2 3 4; do ( f=0; for j in 1 2 3 4 5 6 7 8 9 10; do wr "$L" "$T/c" "$SP" 120 "w$i" /dev/null || f=1; done; exit "$f" ) & pids+=("$!"); done; for p in "${pids[@]}"; do wait "$p" || rc=1; done; test -s "$T/c/lk.jsonl" || exit 1; grep -c . "$T/c/lk.jsonl" > "$T/n"; test "$(cat "$T/n")" = 40 || rc=1; grep -oE '"run_id":"X","seq":[0-9]+' "$T/c/lk.jsonl" > "$T/s1"; grep -oE '[0-9]+$' "$T/s1" > "$T/s2"; sort -n "$T/s2" > "$T/got" || exit 1; seq 1 40 > "$T/exp" || exit 1; cmp -s "$T/got" "$T/exp" || rc=1; test ! -e "$T/c/.lk.jsonl.lock" || rc=1; test "$rc" -eq 0

- [ ] **AC13** (D5, v2.) The check-intent AC8 pair holds and is non-vacuous on any bash.
  - **At HEAD**, `tests/check-intent/run.sh` exits `0` under `tms` with no line beginning `FAIL`. Its log has a line beginning `PASS: AC8: ` and a line beginning `PASS: AC8 non-vacuous counterfactual`.
  - **Mutation.** HEAD's committed tree is extracted with `git archive HEAD`. In the copy's `bin/check-intent.sh`, the single line that is exactly `  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"` is replaced by `  || true`. The copy's suite then exits non-zero, not by timeout, and its log has a line beginning `FAIL: AC8`.
  - **Restatement present.** `tests/check-intent/run.sh` contains `dirname failed to resolve`, because the restated AC8 asserts that refusal text. On a bash 5.2 host the mutation run fails at AC8 either way, by exit `0`, so this presence check is what the local run adds. That the counterfactual accepts exactly exit `0` or `2`, without the dirname-specific text, is a QA reading item; CI on bash 5.3 (**AC11**) exercises its `2` branch.
  - Positive controls: the anchor line occurs exactly once, and the mutated file differs from the extracted one.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac13.XXXXXX") || exit 1; grep -qF 'dirname failed to resolve' tests/check-intent/run.sh || rc=1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_SPECS_DIR TEAM_RUNS_DIR RUNS_DIR; mkdir -p "$HOME" "$T/h" || exit 1; S=tests/check-intent/run.sh; X=bin/check-intent.sh; test -s "$S" || exit 1; test -s "$X" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; git archive HEAD > "$T/h.tar" || exit 1; tar -xf "$T/h.tar" -C "$T/h" || exit 1; M="$T/h/$S"; test -s "$M" || exit 1; for f in "$S" "$M"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; done; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; grep -q '^PASS: AC8: ' "$T/log" || rc=1; grep -q '^PASS: AC8 non-vacuous counterfactual' "$T/log" || rc=1; A=$(printf '  || fail_usage "dirname failed to resolve this script%ss own directory for: $script_path"' "'"); n=$(grep -cxF -- "$A" "$T/h/$X"); test "$n" = 1 || exit 1; awk -v a="$A" '$0 == a { print "  || true"; next } { print }' "$T/h/$X" > "$T/mut" || exit 1; cmp -s "$T/mut" "$T/h/$X"; test "$?" = 1 || exit 1; cat "$T/mut" > "$T/h/$X" || exit 1; tms "$M" "$T/rlog"; s=$?; test "$s" -ne 0 || rc=1; test "$s" -ne 99 || rc=1; grep -q '^FAIL: AC8' "$T/rlog" || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes**:

1. **discover-work invocation shapes.** The script is run:
   - by absolute path;
   - by a relative path containing a slash;
   - by bare name from its own directory (`bash discover-work.sh`);
   - through a symlink whose target is relative;
   - through a symlink whose target is absolute.

   It runs with a full `PATH`, and with the suite's restricted `PATH` of `bash awk grep sed tr`, plus `readlink` on the symlink path. **AC1** covers each shape.
2. **bash versions.** 5.3.9 on the CI runner; 5.2 on Linux workstations; 3.2 on macOS, the floor `bin/` keeps (`bin/derive-populations.sh:79`). The check lines run on whichever bash the checkout has. **AC1**, **AC2** and **AC4** are written to discriminate base from HEAD on 5.2 as well as on 5.3.
3. **Concurrent log-run writers.** Several processes append to one runs file under one `run_id`:
   - with `--seq auto` and with explicit integers;
   - in span and event modes;
   - on hosts with fewer cores than writers (the runner has `nproc=4` against 8 writers);
   - with the bounded wait reached (exit `3`), with a pre-held lock, and with INT/TERM delivered to a holder.

   **AC3**'s T-1076 labels, **AC4** and **AC12** cover them.
5. **`mkdir` implementations (v2).** GNU coreutils `mkdir`, where only one concurrent call on a path succeeds. And uutils coreutils `mkdir`, measured on Ubuntu 26.04.1 and shipped from Ubuntu 25.10 on (relayed), where several concurrent calls can report success. **AC12** models the latter with a stub that always reports success.
6. **Lock directories left behind.** One with an `owner` token (a holder killed with SIGKILL), and one without a token: left by an older `log-run.sh`, by a holder killed between creating the directory and the token, or pre-created by the T-1076 refusal case. **AC12** covers both on both `mkdir` kinds.
7. **The check-intent AC8 pair under bash 5.2 and 5.3** (**AC13**).
4. **Invocations of the other `bin/` scripts that use `dirname`.** These run with `dirname` on `PATH`, as their contracts and suites assume. **AC7** and **AC8** cover them.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **discover-work installed at the filesystem root** (`/discover-work.sh`), a symlink loop, or a symlink chain whose `readlink` is missing.
2. **A `PATH` lacking `bash`, `awk`, `grep`, `sed` or `tr`.** The script needs those.
3. **Running any class-B, C or D script of **AC8** without `dirname` on `PATH`.** That is recorded as a latent defect, not fixed here.
4. **A runs directory on a filesystem where `mkdir` is not atomic** (for example some network filesystems).
5. **A holder killed with SIGKILL.** That is T-1076's disclosed residual: the lock stays until removed by hand.
6. **Wall-clock jumps, and more writers than the bounded wait can serve.** The latter exits `3` by design.
7. **An `owner` path inside the lock directory that is not a regular file** (a directory, a FIFO), planted by hand. `noclobber` does not refuse to open a non-regular file.
8. **An older `log-run.sh` and the fixed one writing the same runs file concurrently on a uutils host.** The older one does not honour the token.

<!-- END intent-block: T-1194 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | discover-work resolves its directory without `dirname` or any external command, on every reachable shape (D1) | **AC1** |
| 2 | `readlink` stays allowed on the symlink path only (D1) | **AC1** (the restricted `PATH` holds `readlink`, never `dirname`) |
| 3 | No fallback to the caller's working directory (D1) | **AC1** (the decoy `team-paths.sh` never runs) |
| 4 | The fix is in the shipped script, not the test (D1, D2) | **AC2** and **AC4** (reverting only the script makes the suite fail) |
| 5 | The suite fails on a T-1194 case against the base discover-work, on bash 5.2 too (D1) | **AC2** |
| 6 | Root cause recorded (D2; measured by the coordinating session in v2) | QA reading item (**AC3**): the provenance record states it. info-only as a criterion, because no command can judge that a cause is the true one |
| 7 | Deterministic exclusivity fixture (`mkdir` stub), distinct setup label, fails on every base run (D2) | **AC4** (suite), **AC12** (direct: base control writes under a pre-held lock) |
| 8 | The fixture exercises the shipped writer (D2) | **AC3** QA reading item; **AC12** runs `bin/log-run.sh` itself |
| 9 | Lock contract unchanged: path, timeout, exit 3, never stolen, INT/TERM (D3) | **AC3** (T-1076 labels and `--help` text), **AC12** (pre-held arms) |
| 9a | Ownership only by exclusive creation of `owner`; a failed claim waits (D2, v2) | **AC12** (concurrency arm under the stub: exactly `1..40`) |
| 9b | An existing lock directory is held with or without a token, on both `mkdir` kinds (D2, v2) | **AC12** (arms `b1`, `b2`) |
| 9c | Release removes its own token then the directory, never recursively, never another's token (D3, v2) | **AC12** (no lock directory left after concurrency; `owner` left intact in held arms), **AC6** (no recursive deletion) |
| 9d | Timeout refusal names the lock path and the hand-removal steps, `owner` then `rmdir` (D3, v2) | **AC12** (stderr carries the path, `owner` and `rmdir`) |
| 9e | check-intent AC8 pair holds on bash 5.2 and 5.3, non-vacuous (D5, v2) | **AC13** |
| 9f | Remaining `dirname` sites tracked in issue #765, not in scope (Non-goals, v2) | **AC9** keeps them out of the diff |
| 9g | `bin/check-intent.sh` unchanged (Non-goals, v2) | **AC9** |
| 10 | No test-only hook in the shipped script (D3) | **AC3** (`TEAM_*` token set equal to the base) |
| 11 | T-1076 message names duplicates and gaps (D4) | **AC5** |
| 12 | Other suites executing either script stay green | **AC7** |
| 13 | Every `bin/` `dirname` site has a disposition (class sweep) | **AC8** |
| 14 | shellcheck clean, no recursive deletion | **AC6** |
| 15 | No pin, no workflow change, no other `bin/` change, no `check-run.sh` change, nothing from PR #764, no doc edit (Non-goals) | **AC9** |
| 16 | `ts` timing unchanged (Non-goals) | info-only (not promoted to AC): an exclusion of scope; the T-1076 labels in **AC3** cover existing behaviour |
| 17 | Existing duplicate rows not repaired (Non-goals) | info-only (not promoted to AC): an exclusion of scope, disclosed in Blast radius |
| 18 | No full-population sweep (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 19 | Records conformant | **AC10** |
| 20 | CI green on `ubuntu-latest` | **AC11** (above the ceiling) |
| 21 | Pre-commitment, route-back rules and drop order | info-only (not promoted to AC): dispositions, not deliverable properties |

## Class sweep

The inventory of record is frozen in **AC8**, and **AC8**'s check re-derives the population from the base commit on every run. The block below is the population derivation this record states. The freeze run embeds it verbatim. This role has no shell, so the block is not typed by hand here.

- reproduce: bash bin/derive-populations.sh --label t1194-dirname-sites --set base-dirname-users='git grep -l -e dirname 2c4d05bb6b8074e58d88fe634a4920200f06f730 -- bin/ | sed "s|^2c4d05bb6b8074e58d88fe634a4920200f06f730:||"' --set ac8-inventory='awk "/^- \\[.\\] [*][*]AC8[*][*]/ { f = 1 } /^- \\[.\\] [*][*]AC9[*][*]/ { f = 0 } f" .shell-team/specs/T-1194-ci-runner-image-red.md | grep -oE "bin/[A-Za-z0-9._-]+" | sort -u'

<!-- BEGIN derivation: t1194-dirname-sites -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: base-dirname-users — status: 0 — lines: 42 — items: 42 — command: git grep -l -e dirname 2c4d05bb6b8074e58d88fe634a4920200f06f730 -- bin/ | sed "s|^2c4d05bb6b8074e58d88fe634a4920200f06f730:||"
- set: ac8-inventory — status: 0 — lines: 42 — items: 42 — command: awk "/^- \\[.\\] [*][*]AC8[*][*]/ { f = 1 } /^- \\[.\\] [*][*]AC9[*][*]/ { f = 0 } f" .shell-team/specs/T-1194-ci-runner-image-red.md | grep -oE "bin/[A-Za-z0-9._-]+" | sort -u
- union: items: 42
- bucket: base-dirname-users+ac8-inventory — items: 42
  - bin/check-adapter.sh
  - bin/check-adopter-docs.sh
  - bin/check-binding.sh
  - bin/check-board-headings.sh
  - bin/check-codex-agents.sh
  - bin/check-commit-identity.sh
  - bin/check-count-claims.sh
  - bin/check-durability.sh
  - bin/check-intent.sh
  - bin/check-interventions.sh
  - bin/check-invocation-path.sh
  - bin/check-liveness.sh
  - bin/check-model-pins.sh
  - bin/check-oversight.sh
  - bin/check-pii-shapes.sh
  - bin/check-provenance.sh
  - bin/check-readme-version.sh
  - bin/check-refreeze-class.sh
  - bin/check-refreeze-grant.sh
  - bin/check-review-input.sh
  - bin/check-review-provider.sh
  - bin/check-setup.sh
  - bin/check-spec-review.sh
  - bin/close-out.sh
  - bin/codex-await.sh
  - bin/codex-capture.sh
  - bin/consolidate-proposals.sh
  - bin/discover-work.sh
  - bin/gen-codex-agents.sh
  - bin/gen-loop-replay.sh
  - bin/gen-playbook-blocks.sh
  - bin/gen-project-status.sh
  - bin/install
  - bin/log-run.sh
  - bin/playbook-promote.sh
  - bin/resolve-executor.sh
  - bin/retro-inputs.sh
  - bin/rework-digest.sh
  - bin/rollup-track.sh
  - bin/team-commit.sh
  - bin/team-init.sh
  - bin/team-setup.sh
<!-- END derivation: t1194-dirname-sites -->

Expected reading: every member falls in the `base-dirname-users+ac8-inventory` bucket, and no `base-dirname-users`-only bucket exists. A member only in the inventory bucket is harmless.

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. Following T-1191 to T-1193, and the operator rulings relayed there (labelled relayed; the primary confirmation is held by the coordinating session), CI and this task's own check lines decide the impact.
- **Known readers.** These suites name `log-run.sh` or `discover-work.sh`:
  - `tests/check-fanout-instances`, `tests/check-run`, `tests/close-out`, `tests/codex-agents`;
  - `tests/consolidate-proposals`, `tests/errexit-safe`, `tests/land-worktree`, `tests/machine-tokens`, `tests/rework-digest`;
  - the two edited suites.

  `tests/bin-help` reaches both scripts through `git ls-files -- bin/`. **AC7** runs all of them except any suite matching the recursive-deletion pattern. A single-line search shows `tests/land-worktree/run.sh` matches, so it is left to CI (**AC11**). The set is re-derived at run time.
- **Merged criteria** in `.shell-team/specs` that run either script were not re-run. That is a lower bound, disclosed per the deviation above.
- **Shipped prose stating the lock guarantee:**
  - `README.md:246` and `README.ja.md:246`;
  - `skills/run/SKILL.md:305` and `:325`;
  - `templates/prompt-blocks/fanout-orchestration.md:22`.

  Each says the lock makes concurrent `--seq auto` appends safe. The fix makes that accurate again, so none is edited and no follow-up is needed.
- **Analysis notes pinning line numbers.** `docs/loop-engineering/arith-base10-audit.md` cites `bin/discover-work.sh` line numbers (`:39`, `:262`, `:263`), and the fix will shift them. No test or checker reads that note; its only readers are other notes under `docs/loop-engineering/`. It is a point-in-time analysis record, so it is not edited.
- **Lock layout (v2).** A held lock directory now carries an `owner` file. An operator who removes a lock by hand follows the refusal message: remove `owner`, then `rmdir`. Bare `rmdir` on a held lock fails on the non-empty directory, so it cannot remove a lock held by a live writer. A token-less directory left by an older `log-run.sh` is still honoured as held (D2). An older and a newer `log-run.sh` writing the same file concurrently on a uutils host is out of scope (Input space out-of-scope 8).
- **Adopter-side artifacts.** Runs files already written with a duplicate `seq` stay as they are, with no migration. A later `--seq auto` call continues from the maximum, so new rows are not affected by an old duplicate. Nothing generated into adopter repositories changes.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| discover-work self-resolution without `dirname` (D1) | not met | not met: reached only when `dirname` is missing from `PATH` (**AC8**) | PATCH | a portability bug fix |
| log-run `--seq auto` exclusivity under contention (D2, D3) | not met | met: every concurrent `--seq auto` writer on a host whose `mkdir` is uutils (Ubuntu 25.10+) | PATCH | a concurrency bug fix restoring the documented contract; the lock directory gains an `owner` file, an internal detail |
| check-intent AC8 pair restated (D5) | not met | not met: test-only | PATCH | a test fix |
| T-1076 message names duplicates and gaps (D4) | not met | not met: test-only | PATCH | a diagnostic improvement in a test |

The derived tier is PATCH, the maximum of the column. Sprint release: PATCH, v2.9.5 (relayed from the coordinating session's host-approved planning).

## Assumptions

- **Measured by this role.**
  - The working tree was clean at `2c4d05bb6b8074e58d88fe634a4920200f06f730`.
  - `refs/heads/feature/762-ci-runner-image-red`, `refs/heads/feature/759-capture-extraction-fail-closed` and `refs/remotes/origin/feature/759-capture-extraction-fail-closed` all hold that commit. `packed-refs` maps `refs/remotes/origin/develop` to `75866424…`, and there is no local `refs/heads/develop`.
  - Every line anchor in `## Summarized sources` and in **AC8**.
  - No `bin/` script sources another.
  - `log-run.sh`'s acquisition loop (`:628-652`) has no stale-break or steal path, and its release is guarded by `LOCK_ACQUIRED` (`:603-611`). So two of the brief's hypotheses, a steal that removes a live holder's lock and a release that removes another writer's lock, are not visible in the source as written.
  - The seq scan runs inside the lock (`:656`). `TS` is taken before acquisition (`:438`). That explains the "later row, earlier `ts`" observation as a writer waiting in the `sleep 1` poll, and says nothing about where exclusivity breaks.
  - Neither edited suite contains a recursive-deletion pattern; `tests/land-worktree/run.sh` does. These were single-line searches; the check lines repeat the scan with lines joined.
- **Relayed, not measurable by this role** (owner: the coordinating session, whose freeze run confirms them):
  - every CI measurement in `## Summarized sources` (the runner image, bash 5.3.9, `nproc=4`, the AC4a output, the 9-of-10 contention result and its row details, the last green `develop` run);
  - the local 5-of-5 pass;
  - the issue #762 title;
  - the sprint name, that this task is a prerequisite and not its goal, and the release tier PATCH v2.9.5;
  - the operator rulings behind the no-sweep deviation;
  - PRs #758 and #763 being open.
- **Measured by the coordinating session (v2; diagnostic draft PR #764, 2026-11-21).** Recorded here as measured on that side; this role cannot re-run them.
  - **Root cause of the duplicate `seq`.** On the runner, `/usr/bin/mkdir` resolves to `/usr/lib/cargo/bin/coreutils/mkdir`, which reports itself as `mkdir (uutils coreutils) 0.10.0`; Ubuntu 26.04.1 ships the Rust uutils coreutils. A probe started 8 concurrent `mkdir "$d"` calls on one path, 300 rounds. In 29 of the 300 rounds more than one call reported success, and the most winners in one round was 3. The same probe with `mkdir (GNU coreutils) 9.4` locally had 0 of 300.
    - So the `mkdir "$LOCK_DIR"` acquire test in `bin/log-run.sh` (`:628-652`) is not exclusive wherever `mkdir` is uutils.
    - In the same CI run, the 10× contention repeat again showed one duplicate.
    - Adopters on Ubuntu 25.10 and later are affected (relayed).
  - **The v1 lead is refuted.** On bash 5.3.9 on the runner, `trap … EXIT; x="$(…)"` fires the trap once, in the parent at exit, never inside the command substitution. That held with a plain trap, with a function, and with a flag-guarded release function.
  - **The complete red set on the new runner is exactly three steps.** A diagnostic run with these three made non-fatal ran the whole workflow green:
    - `tests/log-run/run.sh`, the T-1076 contention arm (intermittent);
    - `tests/discover-work/run.sh`, AC4a (deterministic);
    - `tests/check-intent/run.sh`, the AC8 counterfactual (around `:805`, deterministic). It expects the OLD unsplit bootstrap to fail open (exit `0`) under a failing `dirname`. On bash 5.3 `cd ""` fails, so the OLD bootstrap now exits `2` with `check-intent-OLD.sh: line 12: cd: null directory`.

    This replaces v1's relayed "no other suite is red" premise. That premise was false, and v2 widens **AC9** by one file.
  - **D1 is implemented.** Commits `62b46e38` and `13ef53b1`; **AC1** and **AC2** pass (relayed).
- **v2 design review by this role (D2).** The coordinating session's owner-token design has one host-dependent hole, and D2's "existing directory" rule closes it.
  - **The hole.** As specified, a writer proceeds to create the token only when `mkdir` reports success. Under GNU `mkdir`, a pre-existing token-less directory therefore blocks, exiting `3`. Under uutils `mkdir`, the same directory is taken, because `mkdir` reports success and the token is free.
  - **Where that bites.** T-1076's `lock-timeout-refusal` case pre-holds exactly such a directory (`tests/log-run/run.sh:448`). It would fail on the CI runner, and an older writer's live lock would be stolen.
  - **Why the existence rule is safe.** Treating an existing directory as held makes both hosts agree. The remaining check-then-create window between two writers is settled by the exclusive token create. A writer that finds the directory gone at token time gets an error and retries.
  - **The residual.** A directory left without a token (an older writer, or a holder killed between the two steps) needs removal by hand, as T-1076 already disclosed for SIGKILL.
- **Predicted, unmeasured** (owner: the freeze run). A false prediction routes back here as a broken check line, never as a pass.
  - **No other suite runs a class-B script without `dirname`.** This role did not read how the restricted `PATH`s are built in `tests/setup/run.sh` and `tests/check-setup/run.sh` (`SP`, `NP`), nor the `PATH` at `tests/codex-skeleton-hygiene/run.sh:564` and `tests/interventions-reminder/run.sh:108`. **AC7** and **AC11** would show a failure. The freeze run may check by grepping those builders for `dirname`.
  - **`dirname ''` prints a non-empty string (`.`).** **AC8**'s "why only one site" ground rests on it. The freeze run measures `dirname ''` and records the output here.
  - **AC1's base control.** With `dirname` absent, the base discover-work prints `dirname: command not found` on any bash version (from `:47`). The decoy may or may not run, depending on the version. The control asserts only the `command not found` text.
  - **The `--help` texts.** At the base, `--help` prints `NEVER stolen` (`:142`) and `<runs>/.<loop_id>.jsonl.lock` (`:127`) on lines the printer keeps.
  - **The T-1076 label set.** The column-0 literal `pass "T-1076 …"` labels at the base are non-empty. Labels carrying `$` are excluded by the derivation.
  - **AC12's base control (v2).** Under the always-success stub, the base script given a pre-held lock (directory plus `owner`) acquires, writes a row and exits `0`. Its release `rmdir` fails silently on the non-empty directory. Traced from `:636`, `:607` and `:663`.
  - **AC13 (v2).** The check-intent suite runs from a `git archive` copy with no `.git`: its AC8 fixtures are inline (`tests/check-intent/run.sh:763-776`), but whether every other case in that suite runs without a `.git` was not read. The anchor line occurs exactly once in `bin/check-intent.sh` (`:190`; measured here). With the guard turned into `|| true` and `dirname` failing, the shipped checker exits `0` on bash 5.2 (`cd ""` succeeds), and on bash 5.3 exits `2` through the `cd`/`pwd` refusal at `:191-192`. Neither output carries `dirname failed to resolve`, so the restated AC8 fails on both.
- **Borrowed tokens.** `gh CLI not found` (discover-work's own note), the T-1076 `pass` labels, `NEVER stolen` and the lock-path text are vocabulary of the base scripts. Every criterion asserts them by presence only, or derives them from the base blob (**AC2**, **AC3**), so no literal count premise rests on them.
  - **One zero-at-base premise rests on borrowed text:** `(duplicate or gap)` occurs in the base suite (**AC5**'s positive control; measured here at `:442`).
  - The own-coinage tokens `PASS: T-1194 `, `FAIL: T-1194 discover-work`, `FAIL: T-1194 log-run-exclusive:` and `T-1194 log-run-exclusive-setup` are expected at 0 before implementation. The freeze run measures `git grep -c 'T-1194' "$B" -- tests/` and records the value here.
- **Stacked branch.** This branch is classified as stacked behind an open predecessor at authoring time: T-1193 on `feature/759-capture-extraction-fail-closed`, PR #763, base `develop`. T-1193 is itself stacked on T-1192 (`feature/755-codex-review-model-pin`, PR #758).
  - The arms are tried in order: the local predecessor branch, the remote-tracking predecessor, then `develop` (local, then remote-tracking) as the era-change fallback.
  - **Deviation from the briefing:** the briefing named the remote-tracking predecessor and `develop` only. A local arm is tried first, because this checkout carries the local predecessor branch and the house discriminator (T-1193) tries local refs first.
  - Route-back residuals, disclosed rather than engineered around:
    - the predecessor deleted without being merged;
    - the predecessor rebased, force-pushed or squash-merged after this branch was cut;
    - a checkout that never fetched the predecessor.
- **Pre-implementation expectation (v1 freeze read, kept for the record).** At the v1 freeze, HEAD equalled the base for every script and suite:
  - **AC1** and **AC2** red; **AC3**, **AC4** and **AC5** red;
  - **AC6**, **AC7** and **AC8** green;
  - **AC9** red on its positive control;
  - **AC10** green; **AC11** `SKIP`.
- **Expectation for the v2 freeze read.** D1 is committed and `bin/log-run.sh` is not yet changed.
  - **AC1**, **AC2**: green, as relayed.
  - **AC3**: red on the missing `PASS: T-1194 log-run-exclusive` line.
  - **AC4**: red on the "script differs" control.
  - **AC5**: red, unless already done.
  - **AC6**: green.
  - **AC7**: green, predicted.
  - **AC8**: green; its region is unchanged in v2.
  - **AC9**: green. Its positive control holds through `bin/discover-work.sh`, and the `bin/log-run.sh` half is red until D2 lands.
  - **AC10**: green when the board entry is conformant.
  - **AC11**: `SKIP`.
  - **AC12**: the base control passes, then the line is red. The HEAD script equals the base, so it writes under the pre-held lock with the stub.
  - **AC13**: red on the restatement-presence check. Under bash 5.3 it is also red on HEAD's counterfactual. Under bash 5.2 the suite and mutation parts are already green, because the mutated checker exits `0`.

## Open questions

- None blocking. One scope choice is surfaced in the hand-off rather than asked: this task fixes only the CI-red `dirname` site, and **AC8** gives every other site a disposition.

## Notes for engineer

- **Files.** The allow-list is in **AC9**: the two scripts, their two suites, `tests/check-intent/run.sh` (v2), and this task's records. Fixtures are synthesized inline; no new fixture files.
- **discover-work.**
  - Fix both `:44` and `:47`.
  - A suffix strip like `${p%/*}` needs a no-slash fallback (`.`). The root case (`/x`) is out of scope, but it must not silently become `cd ""` without that being a conscious choice.
  - Add a T-1194 case to `tests/discover-work/run.sh` that fails against the base on bash 5.2. AC4a's `grep -qi 'not found'` alone cannot do that: it matches `dirname: command not found`. Assert the `gh CLI not found` note and the absence of `command not found`. Name every such failure `FAIL: T-1194 discover-work…`.
  - Keep every existing `pass` label byte-identical (**AC2** derives them from the base).
  - Place the T-1194 case **before** AC4a (`:78`). On a bash 5.3 host the base script dies at AC4a with `FAIL: AC4a: …`, and **AC2**'s reverted run must fail on a T-1194 line first.
- **log-run (v2).**
  - Record the coordinating session's measured cause (uutils `mkdir`) and the probe numbers in `.shell-team/provenance/T-1194.md`.
  - **Acquisition.** Treat an existing lock directory as held. Otherwise `mkdir`, then claim `owner` with an exclusive create. Set `LOCK_ACQUIRED=1` only after the token create succeeds.
    - Keep the whole sequence (existence test, `mkdir`, token create, flag set) inside the existing `trap '' INT TERM` bracket.
    - Scope `noclobber` so it does not leak into later redirections, for example `( set -C; : > "$LOCK_DIR/owner" )`, or `set -C` … `set +C` inside the bracket.
    - A token create that fails, whether with `EEXIST` or because the directory vanished, is "held by another": wait and retry within the bounded wait.
  - **Release.** Under the same bracket, remove this writer's own `owner` (non-recursive `rm`, or an equivalent), then `rmdir` the directory, ignoring a non-empty failure. Never touch a token when `LOCK_ACQUIRED` is not `1`.
  - **Timeout message.** It names the full lock path and both hand-removal steps (`owner`, then `rmdir`). **AC12** greps for the path, `owner` and `rmdir`, and T-1076's `lock-timeout-refusal` greps for the path.
  - **The `mkdir` stub.** It runs the real `mkdir` (absolute path captured when the stub is written), discards its status and stderr, and always exits `0`, so `mkdir -p "$RUNS_DIR"` still works. Put it ahead on `PATH` for the writers only. A stub that does not create the directory would make every fixed writer time out, which is not the measured uutils behaviour.
  - **Suite fixture.** The pre-held-lock arm under the stub fails the base on every run with no concurrency at all. Add a concurrency arm under the stub for the fixed script. Setup failures use `FAIL: T-1194 log-run-exclusive-setup: …`.
  - Place the T-1194 block **before** the T-1076 contention arm (`:345`). Then a reverted run fails on T-1194 first and never on the arm's own intermittent failure.
  - Keep T-1076's `lock-timeout-refusal` case (`:445-458`) as is. Its token-less pre-held directory must still yield exit `3` on GNU and uutils alike, by D2's "existing directory" rule. Its own cleanup is `rmdir` on a token-less directory, which stays valid.
- **check-intent (v2, D5).** Restate only the AC8 pair in `tests/check-intent/run.sh` (`:728-806`).
  - AC8 additionally asserts `dirname failed to resolve` in stderr.
  - The counterfactual accepts exit `0` (fail-open into the working directory) or exit `2` (the `cd`/`pwd` refusal), requires the absence of `dirname failed to resolve`, and fails on any other status.
  - Keep the fail messages prefixed `AC8` (**AC13** greps `^FAIL: AC8`) and the pass lines beginning `AC8: ` and `AC8 non-vacuous counterfactual`. The counterfactual's pass label may change, because its current text claims exit `0`.
  - Do not touch `bin/check-intent.sh`.
  - The suite already anchors on exact lines of `bin/log-run.sh`, for example `while :; do`, `  [ "$LOCK_ACQUIRED" = "1" ] && break`, the `# --- critical section: …` line and the `lock_mtime` start line. If the fix rewrites any of them, update those anchors so they still mutate the intended code, and keep every T-1076 `pass` label byte-identical (**AC3**).
  - Do not add a `TEAM_*` variable (**AC3**).
- **Run time.** **AC3** and **AC4** run the log-run suite five times in total. Set `CHECK_ACS_TIMEOUT` high enough (for example 6000) when running the acceptance criteria.
- **Mutation probes (mechanism class).** In a scratch copy, break each never-dropped rule once, confirm the matching criterion goes red, then restore it. For example:
  - restore discover-work's `$(dirname …)` (**AC1**, **AC2**);
  - make discover-work fall back to `$PWD` without `dirname` (**AC1**'s decoy);
  - undo the lock fix (**AC4**, **AC12**);
  - trust `mkdir`'s status again instead of the token (**AC12**, concurrency arm);
  - drop the "existing directory is held" rule (**AC12**, arm `b1`);
  - remove the token on release without `LOCK_ACQUIRED` (**AC12**, `owner` kept in the held arms);
  - revert the AC8 restatement in `tests/check-intent/run.sh` (**AC13**'s presence check);
  - make the T-1194 fixture's anchor miss on the base (**AC4** must stay red only through the `-setup` label, not by passing).
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** The two `bin/` scripts are shipped and get full strength. The inline check lines get dev-scaffold depth (operator ruling 2026-08-22, relayed).
