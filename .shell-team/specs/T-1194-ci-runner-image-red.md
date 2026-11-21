# CI is green on today's runner image: discover-work resolves its own directory without `dirname`, and log-run's append lock never hands two writers the same `seq`

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1194

## Problem

CI is red on `develop`'s tip with the current `ubuntu-latest` image (issue #762). Two shipped scripts are at fault.

- **`bin/discover-work.sh` depends on `dirname`, and on bash tolerating `cd ""`.** Its self-resolution runs `cd "$(dirname "$script_path")"`. The discover-work suite's AC4a runs the script with a `PATH` that holds only `bash awk grep sed tr`. With `dirname` missing, the substitution is empty. Under bash 5.2 `cd ""` succeeded silently, and the script fell back to the caller's working directory as its own. Under bash 5.3.9 `cd ""` fails, and the script exits `1`. Either way, a script whose header declares "bash + `gh`" as its only external dependencies calls `dirname`. The fallback also picks the wrong directory for its sibling `team-paths.sh`.
- **`bin/log-run.sh --seq auto` can hand two concurrent writers the same `seq`.** In one CI job, the suite's 8-writer × 20-row contention arm was repeated ten times. Nine runs were clean. One wrote 160 rows, every writer exited `0`, and `seq` 151 appeared twice while 160 was missing. The header promises that "no second writer can take the same number in between". On this runner that promise did not hold, and an adopter on a slow or busy host can get duplicate `seq` values in its telemetry. The root cause is not yet known.

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
- verification-class: mechanism — the diff changes two shipped `bin/` scripts, one of them a concurrency lock, and their fixture suites.
- verification-ceiling: unit-and-static — **AC1**–**AC10** are settled in a plain checkout under whatever bash the checkout has. They run HEAD's and the base commit's scripts on fixtures under `$TMPDIR`, run the two suites on HEAD and on a `git archive` copy of HEAD with one script reverted to the base blob, run the other suites that execute the two scripts, and read the exit codes of shellcheck, `check-adopter-docs.sh` and `check-handoff.sh`. **AC11** (CI on the pull request, bash 5.3.9) sits above the ceiling.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1

**Goal (one sentence).** On every invocation shape in Input space 1, including a `PATH` without `dirname`, `discover-work.sh` resolves its own directory with no external command other than `readlink` on the symlink path, and prints no `command not found`. `log-run.sh --seq auto` never gives two concurrent writers the same `seq` for one `run_id`. A deterministic fixture fails on every run against the base script and passes against the fixed one. The lock's documented contract is otherwise unchanged: same path, bounded wait, exit `3` on timeout, never stolen, `rmdir`-only release. And both suites' existing cases still pass.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — discover-work self-resolution.** The fix is in the shipped script, not in the test. The script resolves the directory of the file it runs from without calling `dirname` (or any external command), for every reachable invocation shape. `readlink` stays permitted on the symlink path only. A resolution that falls back to the caller's working directory is a defect, whatever the bash version. (**AC1**, **AC2**)
- **D2 — log-run exclusivity, root cause first.** The engineer settles the root cause by measurement before fixing it, and records it in the provenance record. The fix is in the shipped `bin/log-run.sh`. The evidence is a fixture in `tests/log-run/run.sh`, labelled `T-1194 log-run-exclusive`, that forces the race window deterministically. Its exclusivity assertion fails with `FAIL: T-1194 log-run-exclusive: …` on every run against the base script, and its setup failures use the distinct label `FAIL: T-1194 log-run-exclusive-setup: …`. "Ran N times without failure" is not evidence. (**AC3**, **AC4**)
- **D3 — the lock's contract stays.** These all stay as they are:
  - the lock path;
  - `TEAM_LOG_LOCK_TIMEOUT` and its 10 s default;
  - exit `3` with nothing written on timeout;
  - never stealing a lock;
  - `rmdir`-only release;
  - the INT/TERM handling;
  - the set of `TEAM_*` variables the script reads (no test-only hook in the shipped script);
  - every existing T-1076 case.

  The `--help` header keeps stating that the lock is never stolen and naming the lock path. (**AC3**)
- **D4 — the T-1076 seq-set message says which.** The `T-1076 contention-auto-seq-set` failure message names the duplicated `seq` values and the missing ones, instead of "(duplicate or gap)". (**AC5**, droppable 1)

**Pre-commitment (frozen before round 1).** The trigger, the route-back rules and the drop order below are AI self-discipline proposed by this role, never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning:
  - (N1) D2, the lock's exclusivity (**AC3**, **AC4**);
  - (N2) D1, the discover-work self-resolution fix (**AC1**, **AC2**).
- **Route-back, not a weaker criterion.** Either of these returns the task to planning with the measurements attached:
  - diagnosis shows the race cannot be forced deterministically, so no fixture meets **AC4**;
  - the duplicate turns out not to come from `bin/log-run.sh`, for example from the test harness.
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same droppable component. A round interrupted before a verdict does not count.
- **Droppable, in order.** A drop removes criterion text, so it is a class-B re-freeze. The dropped part goes to one follow-up issue that carries the rounds' findings as its requirement list.
  1. **The T-1076 message wording (D4, **AC5**).** It is first because it is a diagnostic improvement and not part of the CI-red fix.

## Non-goals

- **No runner-image pin as the fix.** A pin may be decided separately as a mitigation, never in place of fixing the scripts. **AC9** keeps `.github/` out of the diff.
- **No workflow change, no new GitHub Action, no AI in CI.** (**AC9**)
- **The other `bin/` scripts that use `dirname` are not changed.** Each has a frozen disposition in **AC8**. (**AC9**)
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
- **Base reads.** Lines that read a base blob resolve `B` with the declaration region's discriminator expression, spelled byte-identically in **AC1**–**AC5**, **AC8** and **AC9**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Suite runs.** Suites run through `tms`: own process group, 1200 s, killed on timeout (status `99`).
  - Before a suite runs, it is scanned for a recursive-deletion pattern with backslash-continued lines joined. The joined text is written to a file first and grepped there, so no pipeline status is read after `grep -q`.
  - In **AC2**–**AC4**, a match is a broken instrument and exits `1`. **AC7** instead excludes a matching suite and names it as CI-covered.

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

- [ ] **AC6** shellcheck exits `0` on `bin/log-run.sh`, `bin/discover-work.sh`, `tests/log-run/run.sh` and `tests/discover-work/run.sh`. None of the four matches the recursive-deletion pattern once backslash-continued lines are joined.
  - check: rc=0; export LC_ALL=C; L=(bin/log-run.sh bin/discover-work.sh tests/log-run/run.sh tests/discover-work/run.sh); for f in "${L[@]}"; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac6.XXXXXX") || exit 1; shellcheck "${L[@]}" > "$T/sc" 2>&1 || rc=1; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e'; for f in "${L[@]}"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || rc=1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

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
    - This task's records: `.shell-team/specs/T-1194-ci-runner-image-red.md`, `.shell-team/provenance/T-1194.md`, `.shell-team/interventions/T-1194.md`, `.shell-team/reviews/T-1194.md`, `.shell-team/reviews/T-1194-drift.md`, and raw captures `.shell-team/reviews/T-1194-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`, the reserved taskless interventions file (`bin/check-interventions.sh:8`).
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac9.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/heads/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/759-capture-extraction-fail-closed; then B=$(git merge-base refs/remotes/origin/feature/759-capture-extraction-fail-closed HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/log-run.sh "$T/s" || rc=1; grep -qxF bin/discover-work.sh "$T/s" || rc=1; grep -vxE 'bin/(log-run|discover-work)\.sh|tests/(log-run|discover-work)/run\.sh|\.shell-team/(specs/T-1194-ci-runner-image-red\.md|provenance/T-1194\.md|interventions/(T-1194|no-task)\.md|reviews/T-1194(-drift)?\.md|reviews/T-1194-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** Records conformant.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - Positive control: the spec, the checker and the board are each first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1194-ac10.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1194-ci-runner-image-red.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** CI on this branch's pull request is green on `ubuntu-latest`. That includes the `shellcheck` step, `Run log-run resolution suite` and `Run discover-work fixture suite`, plus any suite **AC7** named as CI-covered.
  - One green run is evidence for the discover-work fix on bash 5.3.9. It is not evidence for the lock fix, because the base failed only about one run in ten; **AC4** carries that evidence.
  - above-ceiling: the coordinating session, after the push and before the merge GO, recording the check run's result and the runner's bash version on the board. QA reports this criterion as `SKIP`.

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

   **AC3**'s T-1076 labels and **AC4** cover them.
4. **Invocations of the other `bin/` scripts that use `dirname`.** These run with `dirname` on `PATH`, as their contracts and suites assume. **AC7** and **AC8** cover them.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **discover-work installed at the filesystem root** (`/discover-work.sh`), a symlink loop, or a symlink chain whose `readlink` is missing.
2. **A `PATH` lacking `bash`, `awk`, `grep`, `sed` or `tr`.** The script needs those.
3. **Running any class-B, C or D script of **AC8** without `dirname` on `PATH`.** That is recorded as a latent defect, not fixed here.
4. **A runs directory on a filesystem where `mkdir` is not atomic** (for example some network filesystems).
5. **A holder killed with SIGKILL.** That is T-1076's disclosed residual: the lock stays until removed by hand.
6. **Wall-clock jumps, and more writers than the bounded wait can serve.** The latter exits `3` by design.

<!-- END intent-block: T-1194 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | discover-work resolves its directory without `dirname` or any external command, on every reachable shape (D1) | **AC1** |
| 2 | `readlink` stays allowed on the symlink path only (D1) | **AC1** (the restricted `PATH` holds `readlink`, never `dirname`) |
| 3 | No fallback to the caller's working directory (D1) | **AC1** (the decoy `team-paths.sh` never runs) |
| 4 | The fix is in the shipped script, not the test (D1, D2) | **AC2** and **AC4** (reverting only the script makes the suite fail) |
| 5 | The suite fails on a T-1194 case against the base discover-work, on bash 5.2 too (D1) | **AC2** |
| 6 | Root cause measured and recorded before fixing (D2) | QA reading item (**AC3**): the provenance record states it. info-only as a criterion, because no command can judge that a cause is the true one |
| 7 | Deterministic exclusivity fixture, distinct setup label, fails on every base run (D2) | **AC4** |
| 8 | The fixture exercises the shipped writer (D2) | **AC3** QA reading item |
| 9 | Lock contract unchanged: path, timeout, exit 3, never stolen, rmdir-only, INT/TERM (D3) | **AC3** (T-1076 labels and `--help` text) |
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
- **Adopter-side artifacts.** Runs files already written with a duplicate `seq` stay as they are, with no migration. A later `--seq auto` call continues from the maximum, so new rows are not affected by an old duplicate. Nothing generated into adopter repositories changes.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| discover-work self-resolution without `dirname` (D1) | not met | not met: reached only when `dirname` is missing from `PATH` (**AC8**) | PATCH | a portability bug fix |
| log-run `--seq auto` exclusivity under contention (D2, D3) | not met | met: every concurrent `--seq auto` writer | PATCH | a concurrency bug fix restoring the documented contract |
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
  - PRs #758 and #763 being open;
  - **that no other suite is red on the new image.** The workflow has no `continue-on-error` and no step-level `if:`, so on a red base run every step after `Run discover-work fixture suite` (`:95`) was skipped. Whether the diagnostic run of PR #764 ran the later suites to completion was not relayed. If a third suite is red, **AC11** and **AC9**'s four-file allow-list cannot both pass, and the task routes back to planning as a scope change.
- **Unmeasured, for the engineer to settle (D2).** The root cause of the duplicate `seq` is unknown.
  - Five clean local runs are weak evidence that the defect is runner-specific: at a one-in-ten rate, five clean runs happen about 59% of the time.
  - One lead to **verify, not assume**: while holding the lock, the critical section forks subshells (`FINAL_SEQ="$(compute_auto_seq …)"`, `$(jnum …)`), and each inherits `LOCK_ACQUIRED=1`. Bash documents that a subshell resets caught traps. Whether any child can still reach `release_lock` or an `rmdir` of the lock on bash 5.3.9 is a question to measure.
  - Other candidates are any path that leaves the lock directory absent while the holder is still between its scan and its append, and file-visibility ordering between the append and the release.
- **Predicted, unmeasured** (owner: the freeze run). A false prediction routes back here as a broken check line, never as a pass.
  - **No other suite runs a class-B script without `dirname`.** This role did not read how the restricted `PATH`s are built in `tests/setup/run.sh` and `tests/check-setup/run.sh` (`SP`, `NP`), nor the `PATH` at `tests/codex-skeleton-hygiene/run.sh:564` and `tests/interventions-reminder/run.sh:108`. **AC7** and **AC11** would show a failure. The freeze run may check by grepping those builders for `dirname`.
  - **`dirname ''` prints a non-empty string (`.`).** **AC8**'s "why only one site" ground rests on it. The freeze run measures `dirname ''` and records the output here.
  - **AC1's base control.** With `dirname` absent, the base discover-work prints `dirname: command not found` on any bash version (from `:47`). The decoy may or may not run, depending on the version. The control asserts only the `command not found` text.
  - **The `--help` texts.** At the base, `--help` prints `NEVER stolen` (`:142`) and `<runs>/.<loop_id>.jsonl.lock` (`:127`) on lines the printer keeps.
  - **The T-1076 label set.** The column-0 literal `pass "T-1076 …"` labels at the base are non-empty. Labels carrying `$` are excluded by the derivation.
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
- **Pre-implementation expectation (for the freeze read).** At freeze, HEAD equals the base for every script and suite.
  - **AC1**: the base control passes, then the line is red. HEAD's script is the base, and it prints `command not found`.
  - **AC2**: red on the missing `PASS: T-1194 ` line and on the revert control ("script differs").
  - **AC3**: red on the missing `PASS: T-1194 log-run-exclusive` line. The rest is green, unless the suite's own contention arm flakes.
  - **AC4**: red. The "script differs" control fails, and no `FAIL: T-1194 log-run-exclusive:` line appears.
  - **AC5**: red.
  - **AC6**: green. **AC7**: green, predicted.
  - **AC8**: green, if the inventory is complete; this is the freeze run's real test of the sweep.
  - **AC9**: red on its positive control.
  - **AC10**: green when the board entry is conformant.
  - **AC11**: `SKIP`.

## Open questions

- None blocking. One scope choice is surfaced in the hand-off rather than asked: this task fixes only the CI-red `dirname` site, and **AC8** gives every other site a disposition.

## Notes for engineer

- **Files.** The allow-list is in **AC9**: the two scripts, their two suites, and this task's records. Fixtures are synthesized inline; no new fixture files.
- **discover-work.**
  - Fix both `:44` and `:47`.
  - A suffix strip like `${p%/*}` needs a no-slash fallback (`.`). The root case (`/x`) is out of scope, but it must not silently become `cd ""` without that being a conscious choice.
  - Add a T-1194 case to `tests/discover-work/run.sh` that fails against the base on bash 5.2. AC4a's `grep -qi 'not found'` alone cannot do that: it matches `dirname: command not found`. Assert the `gh CLI not found` note and the absence of `command not found`. Name every such failure `FAIL: T-1194 discover-work…`.
  - Keep every existing `pass` label byte-identical (**AC2** derives them from the base).
  - Place the T-1194 case **before** AC4a (`:78`). On a bash 5.3 host the base script dies at AC4a with `FAIL: AC4a: …`, and **AC2**'s reverted run must fail on a T-1194 line first.
- **log-run.**
  - Measure the root cause first, and record the measurement and the cause in `.shell-team/provenance/T-1194.md`.
  - The window-widening precedent is a scratch copy with an injected delay, anchored on exact source lines (`tests/log-run/run.sh:578`, `:716-743`). A fixture built that way must anchor on text present in **both** the base and the fixed script, or **AC4**'s reverted run fails on setup instead of on exclusivity. Setup failures use `FAIL: T-1194 log-run-exclusive-setup: …`.
  - Place the T-1194 block **before** the T-1076 contention arm (`:345`). Then a reverted run fails on T-1194 first and never on the arm's own intermittent failure.
  - The suite already anchors on exact lines of `bin/log-run.sh`, for example `while :; do`, `  [ "$LOCK_ACQUIRED" = "1" ] && break`, the `# --- critical section: …` line and the `lock_mtime` start line. If the fix rewrites any of them, update those anchors so they still mutate the intended code, and keep every T-1076 `pass` label byte-identical (**AC3**).
  - Do not add a `TEAM_*` variable (**AC3**).
- **Run time.** **AC3** and **AC4** run the log-run suite five times in total. Set `CHECK_ACS_TIMEOUT` high enough (for example 6000) when running the acceptance criteria.
- **Mutation probes (mechanism class).** In a scratch copy, break each never-dropped rule once, confirm the matching criterion goes red, then restore it. For example:
  - restore discover-work's `$(dirname …)` (**AC1**, **AC2**);
  - make discover-work fall back to `$PWD` without `dirname` (**AC1**'s decoy);
  - undo the lock fix (**AC4**);
  - make the T-1194 fixture's anchor miss on the base (**AC4** must stay red only through the `-setup` label, not by passing).
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** The two `bin/` scripts are shipped and get full strength. The inline check lines get dev-scaffold depth (operator ruling 2026-08-22, relayed).
