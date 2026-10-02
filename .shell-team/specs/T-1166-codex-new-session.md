# On the Codex CLI host, setup says that generated or changed agents take effect in a new Codex session

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1166

**Branch**: `feature/654-codex-new-session`, cut from `develop` at `9d3e4ced` (the v2.8.0 merge; `.git/refs/heads/develop` and the branch ref both read `9d3e4ced1915d33803481ba8a1ea68a5d8ae1dd0`). Not stacked: no open predecessor. The pull request targets `develop`.

## Problem

A setup run on the Codex CLI host can create or change `.codex/agents/` partway through a Codex session. Those agents cannot be spawned until a new session starts, and nothing tells the operator so. The operator follows the report, types the run request in the same session, and gets a Plan `BLOCKED` that does not name the remedy. The canon is issue #654. Its Problem and Expected sections were relayed verbatim by the coordinating session (this role cannot read the tracker) and are quoted here:

> ## Problem
> A clean-install run on the Codex CLI host (codex-cli 0.159.3, shell-team 2.8.0) typed `set up shell-team` in a session started in a fresh repository. Setup generated `.codex/agents/` (five `shell-team-*.toml`) through two per-command approvals and ended with exit 0 on re-run. In the **same session**, the run request then stopped at Plan `BLOCKED`: the orchestrator reported that its `spawn_agent` could not select the generated `shell-team-tech-lead`, and it did not substitute another agent.
> A **new session** in the same repository, given the same request, spawned `shell-team-tech-lead` and `shell-team-engineer` (recorded as `agent_role` on the subagent threads). The earlier clean-install baseline, where `.codex/agents/` was generated before the session started, also spawned the roles. The model, multi-agent mode and collaboration mode were identical across these sessions.
> So project agents generated during a session are not selectable until the next session. The setup report says nothing about this, and the "Using shell-team from Codex CLI" section of `docs/adopting.md` does not say it either. An operator following the report types the run request in the same session and gets a `BLOCKED` that does not name the remedy.
>
> ## Expected
> - When setup **creates or changes** `.codex/agents/` on the Codex CLI host, its report says that the roles take effect in a new Codex session started in this repository, and to start the loop there. When `.codex/agents/` was already in place and unchanged, it says nothing extra.
> - `docs/adopting.md` (and `.ja.md`) state the same fact next to the short path, with the evidence it rests on.
> - The setup skill's closing step points at a new session on the Codex CLI host when the report says so.

**The refusal path (orchestrator decision, recorded here as relayed).** In the observed run, the first setup run exited `3` and printed two `- run yourself:` lines. The session approved and ran each one per command, so the agents were generated *inside* the session. Setup was then re-run and printed `.codex/agents is in sync …`. The session relayed only that final report. A note keyed only on "this run generated or regenerated" would therefore never have reached the operator in the measured run. So the note is also printed when the report carries a `- run yourself:` line for the `.codex/agents` generator, and the setup skill's closing step carries it forward across re-runs (decision 4).

## Summarized sources

- GitHub issue #654 (Problem and Expected). **Relayed verbatim by the coordinating session; this role did not read it.** It is quoted above. Distinctions carried over:
  - The trigger is setup **creating or changing** `.codex/agents/` on the Codex CLI host. An unchanged `.codex/agents/` gets **nothing extra**.
  - The report says two things: the roles take effect **in a new Codex session started in this repository**, and the loop should be started **there**.
  - Docs state the fact **next to the short path** and **with the evidence it rests on**.
  - The skill's closing step points at a new session **when the report says so**.
  - The evidence: codex-cli 0.159.3 with shell-team 2.8.0. In that run the same-session spawn failed. A new session spawned the roles, and so did the pre-generated baseline. Both were recorded as `agent_role` on the subagent threads. Model, multi-agent mode and collaboration mode were identical across the sessions.
- `bin/team-setup.sh` (read in full). Distinctions:
  - §5 (`:336`–`:422`) is Codex-host only. It has five outcomes for `.codex/agents`:
    - in sync → `add_inplace ".codex/agents is in sync with the installed plugin's agents"` (`:375`);
    - drift regenerated → `add_done "regenerated .codex/agents (it had drifted …)"` (`:383`);
    - drift whose regeneration is refused because the directory is not writable → `refused "$regen_cmd"` (`:388`–`:389`);
    - absent and generated → `add_done "generated .codex/agents from the installed plugin's agents"` (`:407`);
    - absent and `mkdir -p` refused → `refused "$regen_cmd"` (`:418`–`:419`).
  - Every other §5 failure path sets `EC2` (exit `2`).
  - `refused` adds `- run yourself: <command>` under `Remains the operator's decision:` and sets exit `3` (`:301`–`:304`). The exclude-line refusal (`:363`, `:365`) uses the same helper, but with a `printf … >> <exclude>` command rather than the generator command.
  - Report: one header line, then three sections, each item a `- ` line (`:498`–`:509`).
  - Claude Code host: §5 is skipped (`:336`), and no plugin-root path is printed on that host's report (the `PATH` line `:477` and `regen_cmd` are Codex-only).
- `tests/setup/run.sh` (read `:1`–`:399`). Distinctions:
  - Its AC3 (`:159`–`:174`) compares **tree snapshots** (`snap`, `.git/objects` pruned) taken after the first and after the second run. It requires the second run's `Done:` to be `- none`, and on the Codex host that `Already in place:` names `.codex/agents`. It does not compare the two runs' stdout.
  - Its AC8 (`:301`–`:318`) requires exactly four non-`- ` lines in stdout.
  - Its AC10 (`:346`–`:364`) locks fifteen forbidden tokens out of the script, the skill and the run output.
  - Its AC6 (`:228`–`:261`) builds the refusal fixtures (read-only exclude, read-only `.codex`) and skips them as root.
- `skills/setup/SKILL.md` (read in full). Distinctions: step 2 relays the report as printed without dropping or rewording a line (`:31`–`:35`). Step 3 handles each `- run yourself:` line by per-command approval or by handing it to the operator (`:37`–`:45`). Step 5 `**Close with the operator's part.**` (`:53`–`:69`) tells a Codex CLI operator to "start a Codex session in the repository" and dispatch `shell-team-tech-lead`. It says nothing about a session that is *already* open. `Boundary —` follows at `:71`.
- `docs/adopting.md` `## Using shell-team from Codex CLI` (read `:395`–`:454`). Distinctions: the short-path paragraph runs from `**The short path: type \`set up shell-team\` in the session.**` (`:413`) to `:430`. The next paragraph, `What remains the operator's decision is only reported, never changed.` (`:432`), introduces the relayed-evidence style: "Runs on `codex-cli 0.159.3` on 2026-10-01 were relayed to this repository and not re-measured by it; each item below says which kind of evidence it rests on".
- `docs/adopting.ja.md` (read `:400`–`:459`). Distinctions: the short path is the `**近道:` paragraph (`:419`–`:435`). The relayed-evidence paragraph begins `operator の判断に残るもの` (`:437`), using the phrase "このリポジトリに伝達されたもので、ここで再測定したものではない".
- `README.md` `:75` and `README.ja.md` `:75` (read). Distinction: each is the Install paragraph, a single line. It begins `The prompt triggers the setup skill` / `このプロンプトで setup スキル` and says that on a Codex CLI host setup generates `.codex/agents/` and ends with a short report. Neither says when the generated agents take effect.
- `bin/check-adopter-docs.sh` (read `:1`–`:80`). Distinction: each `- shipped-docs: <path> — this-task` path must be named, as a literal substring, in one of this spec's own `- check:` or `- adopter-surface:` lines.
- `.shell-team/specs/T-1164-run-prereq-check.md` (read `:1`–`:205`). Distinctions: it shipped `bin/check-setup.sh` and the run skill's `**Step 0 setup check (T-1164)` line. Both are presence checks run before the first dispatch, and they cannot see whether a present `.codex/agents/` is selectable in the current session. Its fixture idioms (temp `HOME`/`CODEX_HOME`, `GIT_CONFIG_GLOBAL=/dev/null`, stub CLIs, `mk`/`st`/`sec`/`snap` helpers) are reused here.
- `CONTRIBUTING.md` `## What a version number encodes` (cited through T-1164's spec, `:45`). Distinction: bug fixes and internal mechanisms are PATCH.

## Goal

<!-- BEGIN intent-block: T-1166 -->

- user-visible: yes — on the Codex CLI host, a setup run that creates or changes `.codex/agents/` (or prints the command that does) now tells the operator that the roles take effect in a new Codex session started in this repository, and the setup skill carries that pointer into its closing step; the adopting guides and the README state the fact with its relayed evidence.
- verification-class: mechanism — the diff edits `bin/team-setup.sh` and `tests/setup/run.sh`, plus `skills/setup/SKILL.md` and shipped documentation.
- verification-ceiling: unit-and-static — **AC1**–**AC11** are settled in a plain checkout: they run the shipped `bin/team-setup.sh` (and its base-ref blob) against temp git repositories under `$TMPDIR` with a temp `HOME` and `CODEX_HOME` and stub CLIs, or read shipped files, compare base blobs, or take a suite's or checker's exit code. **AC12**, spawnability on a real Codex CLI host, sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor; it was cut from `develop` at `9d3e4ced`, and the base-side reads in **AC7** and **AC11** use `git merge-base develop HEAD` (or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves), each arm selected by `git show-ref --verify --quiet`.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- shipped-docs: skills/setup/SKILL.md — this-task

**Goal (one sentence).** On the Codex CLI host, every `bin/team-setup.sh` report whose §5 generated `.codex/agents`, regenerated it after drift, or printed a `- run yourself:` line for the `.codex/agents` generator carries exactly one line under `Remains the operator's decision:` beginning `- new Codex session: `, stating as a fact that the roles take effect in a new Codex session started in this repository and that the loop is started there. A report whose `.codex/agents` was in sync, and every Claude Code host report, carries no such line and is otherwise byte-identical to the base ref's report. `skills/setup/SKILL.md` step 5 tells a Codex CLI operator to start a new Codex session whenever this session's setup printed that line or ran a generator command itself, even when the final re-run reported `in sync`. `docs/adopting.md` / `.ja.md` beside the short path, and both READMEs' Install paragraph, state the fact, with the docs carrying its relayed evidence.

**Decisions frozen here** (each is promoted to a criterion):

1. **Condition.** The note is printed on the Codex CLI host when §5 takes any of these branches:
   - `generated .codex/agents …` (`:407`);
   - `regenerated .codex/agents …` (`:383`);
   - a `refused "$regen_cmd"` branch for the generator (`:389`, `:419`).

   It is not printed when §5 records `.codex/agents is in sync …` (`:375`), on any Claude Code host run, or when the only refusal is the exclude line. (**AC1**, **AC2**, **AC3**, **AC4**, **AC5**)
2. **Placement and wording.** One `- ` line under `Remains the operator's decision:`, beginning `- new Codex session: `, printed at most once per report. It names `.codex/agents` and `this repository`, and is phrased as a statement of fact: it does not contain the word `decision`, and it asks for no grant. Every other report line is unchanged. (**AC1**, **AC5**, **AC11**)
3. **Idempotence kept.** A second Codex-host run over an unchanged repository prints no note, leaves the repository tree byte-identical to the first run's result, and has `Done:` `- none`. A third run's stdout is byte-identical to the second's. `tests/setup/run.sh`'s existing AC3 stays green. (**AC3**, **AC9**)
4. **The skill carries the note forward.** `skills/setup/SKILL.md` step 5, on the Codex CLI host, tells the operator to start a new Codex session in this repository and start the loop there when either of these happened in this session, even if the final re-run's report says `.codex/agents` is in sync:
   - any setup report printed the `- new Codex session:` line, or
   - the session itself ran a `- run yourself:` command for `gen-codex-agents.sh`.

   On the Claude Code host step 5 is unchanged in effect. (**AC6**)
5. **Docs.** `docs/adopting.md` and `docs/adopting.ja.md` state the fact between the short-path paragraph's opening and the relayed-evidence paragraph. That statement carries the relayed evidence in the guide's existing "relayed to this repository and not re-measured by it" style: codex-cli 0.159.3 with shell-team 2.8.0; same-session spawn failed; a new session and a pre-generated baseline spawned the roles, recorded as `agent_role` on the subagent threads. It names no adopter, account, machine or path. The README Install paragraphs state the fact in one sentence each. No `## ` heading is added to either adopting guide. (**AC7**, **AC8**)

## Non-goals

- **The run skill's and `bin/check-setup.sh`'s `BLOCKED` wording for a same-session spawn failure** is not changed: `skills/run/SKILL.md` and `bin/check-setup.sh` stay byte-identical to their base blobs. (**AC11**)
- **No workaround that changes Codex's own agent discovery**: no reload trick, no host-configuration write, no change to `bin/gen-codex-agents.sh` or `bin/check-codex-agents.sh`, which stay byte-identical. (**AC11**)
- **No Claude Code host report change**: its report is byte-identical to the base ref's. (**AC4**, **AC11**)
- **No change to any `agents/*` or `templates/*` file, to `bin/team-init.sh`, `bin/team-paths.sh` or `.claude-plugin/plugin.json`** (the version bump is the release step's). (**AC11**)
- **The report on an exit-`2` path** (a generator failure, a post-regeneration mismatch, a checker that cannot evaluate) is not specified by this task. (info-only)
- **Real-host spawnability** is the sprint's step V re-measurement, not this task's verification. (**AC12**)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, writes only under `$TMPDIR` (temp directories are left in place, never removed), and contains no recursive delete. Fixtures export a temp `HOME`, `CODEX_HOME` and `XDG_CONFIG_HOME`, set `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, unset `TEAM_RUN_BASE` and `CODEX_THREAD_ID`, and put stub `claude` and `codex` executables that exit `0` first on `PATH`. `st <dir> <args>` runs the setup script and prints its exit status, `sec <heading> <file>` prints one report section, and `nn <file>` counts lines beginning `- new Codex session: `.

- [ ] **AC1** New generation prints the note. A fresh repository under `--host codex-cli` exits `0`, and its `Done:` names `generated .codex/agents`. Its stdout carries exactly one line beginning `- new Codex session: `, and it sits under `Remains the operator's decision:`. That line names `.codex/agents` and `this repository` and does not contain `decision`. A fresh repository with `CODEX_THREAD_ID` set and no `--host` also prints exactly one such line.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; RM="Remains the operator's decision:"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; nn(){ grep -c '^- new Codex session: ' "$1" || true; }; R="$T/g"; mk "$R" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; sec Done: "$T/o" | grep -qF 'generated .codex/agents' || rc=1; test "$(nn "$T/o")" = 1 || rc=1; sec "$RM" "$T/o" > "$T/m"; test "$(nn "$T/m")" = 1 || rc=1; grep '^- new Codex session: ' "$T/m" > "$T/n"; grep -qF .codex/agents "$T/n" || rc=1; grep -qF 'this repository' "$T/n" || rc=1; grep -qF decision "$T/n"; g=$?; test "$g" -eq 1 || rc=1; R="$T/g2"; mk "$R" || rc=1; x=$(export CODEX_THREAD_ID=t; st "$R"); test "$x" = 0 || rc=1; test "$(nn "$T/o")" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC2** Drift regeneration prints the note. After a Codex-host setup, appending a line to `shell-team-engineer.toml` and re-running exits `0`. `Done:` names `regenerated .codex/agents`, and stdout carries exactly one `- new Codex session: ` line, under `Remains the operator's decision:`. Deleting `shell-team-pm-spec.toml` and re-running exits `0`, restores the file, and prints exactly one such line under that section.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; RM="Remains the operator's decision:"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; nn(){ grep -c '^- new Codex session: ' "$1" || true; }; R="$T/d"; mk "$R" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; test -f "$R/.codex/agents/shell-team-engineer.toml" || rc=1; printf 'drift\n' >> "$R/.codex/agents/shell-team-engineer.toml" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; sec Done: "$T/o" | grep -qF 'regenerated .codex/agents' || rc=1; test "$(nn "$T/o")" = 1 || rc=1; sec "$RM" "$T/o" > "$T/m"; test "$(nn "$T/m")" = 1 || rc=1; F="$R/.codex/agents/shell-team-pm-spec.toml"; test -f "$F" || rc=1; rm -f "$F"; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; test -f "$F" || rc=1; test "$(nn "$T/o")" = 1 || rc=1; sec "$RM" "$T/o" > "$T/m"; test "$(nn "$T/m")" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC3** In sync prints nothing extra, and idempotence holds. A fresh Codex-host run exits `0` and prints the note once. A second run exits `0`, with the repository tree snapshot (`.git/objects` pruned) byte-identical to the first run's result. Its `Done:` is `- none`, its `Already in place:` names `.codex/agents is in sync`, and its stdout does not contain `new Codex session` (the read is asserted to complete: grep exit `1`). A third run's stdout is byte-identical to the second's.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; RM="Remains the operator's decision:"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; nn(){ grep -c '^- new Codex session: ' "$1" || true; }; snap(){ (cd "$1" && find . -path ./.git/objects -prune -o -print | sort | while IFS= read -r p; do if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi; done); }; R="$T/i"; mk "$R" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; test "$(nn "$T/o")" = 1 || rc=1; snap "$R" > "$T/r1"; test -s "$T/r1" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; cp "$T/o" "$T/o2" || rc=1; snap "$R" > "$T/r2"; cmp -s "$T/r1" "$T/r2" || rc=1; test "$(sec Done: "$T/o2")" = '- none' || rc=1; sec 'Already in place:' "$T/o2" | grep -qF '.codex/agents is in sync' || rc=1; grep -qF 'new Codex session' "$T/o2"; g=$?; test "$g" -eq 1 || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; cmp -s "$T/o2" "$T/o" || rc=1; test "$rc" -eq 0

- [ ] **AC4** The Claude Code host prints no note. A fresh repository under `--host claude-code`, run twice, exits `0` both times and creates no `.codex`. Neither run's stdout or stderr contains `new Codex session` (the read is asserted to complete: grep exit `1`). Positive control: the combined output names `Remains the operator's decision:`.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac4.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; R="$T/c"; mk "$R" || rc=1; : > "$T/all"; for i in 1 2; do x=$(st "$R" --host claude-code); test "$x" = 0 || rc=1; cat "$T/o" "$T/e" >> "$T/all"; done; test ! -e "$R/.codex" || rc=1; grep -qxF "Remains the operator's decision:" "$T/all" || rc=1; grep -qF 'new Codex session' "$T/all"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** A refused generator write prints the note; a refused exclude write alone does not. This fixture needs a non-root user: run as root it exits `1` (fail-closed, since a permission fixture is meaningless as root). The three cases:
  - (a) A fresh repository with a read-only (mode `555`) `.codex` exits `3`. Under `Remains the operator's decision:` it prints exactly one `- run yourself:` line, naming `gen-codex-agents.sh`, and exactly one `- new Codex session: ` line, which is the only one in stdout. Running the printed command through `bash -c` and then re-running setup exits `0`, and that report names `in sync` and carries no note.
  - (b) After a Codex-host setup, deleting `shell-team-pm-spec.toml` and making `.codex/agents` mode `555`, setup exits `3`. It prints exactly one `- run yourself:` line, naming `gen-codex-agents.sh`, and exactly one `- new Codex session: ` line under that section.
  - (c) After a Codex-host setup, the exclude file is rewritten to `# keep` and made read-only (file `444`, `.git/info` `555`). Setup exits `3`, prints exactly one `- run yourself:` line, which names `exclude` and not `gen-codex-agents.sh`, and prints no note.

  Modes are restored after each run.
  - check: rc=0; export LC_ALL=C; test "$(id -u)" != 0 || exit 1; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac5.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; RM="Remains the operator's decision:"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; nn(){ grep -c '^- new Codex session: ' "$1" || true; }; R="$T/ra"; mk "$R" || rc=1; mkdir -p "$R/.codex" || rc=1; chmod 555 "$R/.codex"; x=$(st "$R" --host codex-cli); chmod 755 "$R/.codex"; test "$x" = 3 || rc=1; sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c"; test "$(grep -c . "$T/c" || true)" = 1 || rc=1; grep -qF gen-codex-agents.sh "$T/c" || rc=1; test "$(nn "$T/m")" = 1 || rc=1; test "$(nn "$T/o")" = 1 || rc=1; C=$(sed 's/^- run yourself: //' "$T/c"); (cd "$R" && bash -c "$C") > /dev/null 2>&1 || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; grep -qF 'in sync' "$T/o" || rc=1; test "$(nn "$T/o")" = 0 || rc=1; R="$T/rb"; mk "$R" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; F="$R/.codex/agents/shell-team-pm-spec.toml"; test -f "$F" || rc=1; rm -f "$F"; chmod 555 "$R/.codex/agents"; x=$(st "$R" --host codex-cli); chmod 755 "$R/.codex/agents"; test "$x" = 3 || rc=1; sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c"; test "$(grep -c . "$T/c" || true)" = 1 || rc=1; grep -qF gen-codex-agents.sh "$T/c" || rc=1; test "$(nn "$T/m")" = 1 || rc=1; R="$T/rc"; mk "$R" || rc=1; x=$(st "$R" --host codex-cli); test "$x" = 0 || rc=1; X="$R/.git/info/exclude"; printf '# keep\n' > "$X" || rc=1; chmod 444 "$X"; chmod 555 "$R/.git/info"; x=$(st "$R" --host codex-cli); chmod 755 "$R/.git/info"; chmod 644 "$X"; test "$x" = 3 || rc=1; sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c"; test "$(grep -c . "$T/c" || true)" = 1 || rc=1; grep -qF exclude "$T/c" || rc=1; grep -qF gen-codex-agents.sh "$T/c"; g=$?; test "$g" -eq 1 || rc=1; test "$(nn "$T/o")" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC6** The setup skill's closing step points at a new session (decision 4). `skills/setup/SKILL.md` carries exactly one line beginning `5. **Close with the operator's part.**`. The region from that line up to the line beginning `Boundary —` names each of: `- new Codex session:`, `new Codex session`, `this session`, `run yourself`, `gen-codex-agents.sh`, `in sync`, `Codex CLI` and `/shell-team:run`.

  Review-judged, against decision 4: the region tells a Codex CLI operator to start a new Codex session in this repository and start the loop there when any setup report in this session printed the note line, or when the session ran a `- run yourself:` generator command, even if the final re-run reported `in sync`. It asks for no grant, and leaves the Claude Code instruction unchanged in effect.
  - check: rc=0; export LC_ALL=C; F=skills/setup/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac6.XXXXXX") || exit 1; test "$(awk 'index($0,"5. **Close with the operator'"'"'s part.**")==1' "$F" | grep -c .)" = 1 || rc=1; awk 'index($0,"5. **Close with the operator")==1{f=1} index($0,"Boundary —")==1{f=0} f' "$F" > "$T/p"; test -s "$T/p" || rc=1; for w in '- new Codex session:' 'new Codex session' 'this session' 'run yourself' gen-codex-agents.sh 'in sync' 'Codex CLI' /shell-team:run; do grep -qF -- "$w" "$T/p" || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** The adopting guides state the fact beside the short path, with relayed evidence (decision 5).
  - English: in `docs/adopting.md`, the region from the line beginning `**The short path` up to the line beginning `What remains the operator's decision` names `new Codex session`, `.codex/agents`, `0.159.3`, `2.8.0`, `agent_role` and `relayed`.
  - Japanese: in `docs/adopting.ja.md`, the region from the line beginning `**近道` up to the line beginning `operator の判断に残るもの` names `新しい Codex セッション`, `.codex/agents`, `0.159.3`, `2.8.0`, `agent_role` and `伝達`.
  - Each start line occurs exactly once.
  - Neither region contains `/Users/` or `/home/` (each read asserted to complete).
  - Each guide's `## ` heading count equals its base blob's.
  - adopter-surface: `docs/adopting.md` `## Using shell-team from Codex CLI` (beside the short path) and `docs/adopting.ja.md` `## Codex CLI から shell-team を使う` (beside `**近道`); plus the README Install paragraphs (**AC8**), the setup report's own `- new Codex session:` line (**AC1**) and the setup skill's step 5 (**AC6**).
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac7.XXXXXX") || exit 1; test "$(grep -c '^\*\*The short path' "$E" || true)" = 1 || rc=1; test "$(grep -c '^\*\*近道' "$J" || true)" = 1 || rc=1; awk 'index($0,"**The short path")==1{f=1} index($0,"What remains the operator")==1{f=0} f' "$E" > "$T/e"; awk 'index($0,"**近道")==1{f=1} index($0,"operator の判断に残るもの")==1{f=0} f' "$J" > "$T/j"; test -s "$T/e" || rc=1; test -s "$T/j" || rc=1; for w in 'new Codex session' .codex/agents 0.159.3 2.8.0 agent_role relayed; do grep -qF -- "$w" "$T/e" || rc=1; done; for w in '新しい Codex セッション' .codex/agents 0.159.3 2.8.0 agent_role 伝達; do grep -qF -- "$w" "$T/j" || rc=1; done; for f in "$T/e" "$T/j"; do grep -qE '/Users/|/home/' "$f"; g=$?; test "$g" -eq 1 || rc=1; done; for f in "$E" "$J"; do git show "$B:$f" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; test "$(grep -c '^## ' "$f" || true)" = "$(grep -c '^## ' "$T/b" || true)" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** The README Install paragraphs state the fact. `README.md` carries exactly one line beginning `The prompt triggers the setup skill`, and it names `new Codex session`. `README.ja.md` carries exactly one line beginning `このプロンプトで setup スキル`, and it names `新しい Codex セッション`. Neither line contains `/Users/` or `/home/`.
  - check: rc=0; export LC_ALL=C; for f in README.md README.ja.md; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac8.XXXXXX") || exit 1; awk 'index($0,"The prompt triggers the setup skill")==1' README.md > "$T/e"; awk 'index($0,"このプロンプトで setup スキル")==1' README.ja.md > "$T/j"; test "$(grep -c . "$T/e" || true)" = 1 || rc=1; test "$(grep -c . "$T/j" || true)" = 1 || rc=1; grep -qF 'new Codex session' "$T/e" || rc=1; grep -qF '新しい Codex セッション' "$T/j" || rc=1; for f in "$T/e" "$T/j"; do grep -qE '/Users/|/home/' "$f"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC9** The fixture suite covers the note and every suite the edited paths reach stays green; no suite with a recursive delete is run.
  - Before anything runs, `bin/team-setup.sh` and `tests/setup/run.sh` are grepped for a recursive delete. The grep must complete and match nothing.
  - `shellcheck` (its `--version` asserted first) exits `0` on both files.
  - `tests/setup/run.sh` exits `0` and prints no line beginning `FAIL`. For each case label `generated`, `regenerated`, `in-sync`, `claude-code` and `refused`, at least one line beginning `PASS` names both `T-1166` and that label.
  - Every `tests/*/run.sh` that `git grep` finds naming `team-setup`, `skills/setup`, `adopting.md`, `adopting.ja.md`, `README.md` or `README.ja.md` is derived at run time, and the derived set is asserted non-empty. Each such suite is first grepped for a recursive delete: a match is a failure and the suite is not run. Otherwise it exits `0` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; F=tests/setup/run.sh; test -s "$F" || exit 1; test -s bin/team-setup.sh || exit 1; grep -nE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$F" bin/team-setup.sh; g=$?; test "$g" -eq 1 || exit 1; command -v shellcheck > /dev/null 2>&1 || exit 1; shellcheck --version > /dev/null || exit 1; shellcheck bin/team-setup.sh "$F" > /dev/null 2>&1 || rc=1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac9.XXXXXX") || exit 1; bash "$F" < /dev/null > "$T/log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; grep '^PASS' "$T/log" | grep -F T-1166 > "$T/pass"; for c in generated regenerated in-sync claude-code refused; do grep -qF -- "$c" "$T/pass" || rc=1; done; git grep -lE 'team-setup|skills/setup|adopting(\.ja)?\.md|README(\.ja)?\.md' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; test -s "$T/d" || rc=1; sort -u "$T/d" > "$T/suites"; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; bash "$s" < /dev/null > "$T/log2" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log2" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that names one of the six patterns, at which point the derived suite set this criterion runs changes.

- [ ] **AC10** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1166-codex-new-session.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac10.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Nothing else changes. It has two parts.
  - (a) Base blobs. These are byte-identical to their base blob at `git merge-base develop HEAD`, and each exists there: `skills/run/SKILL.md`, `bin/check-setup.sh`, `bin/gen-codex-agents.sh`, `bin/check-codex-agents.sh`, `bin/team-init.sh`, `bin/team-paths.sh`, `.claude-plugin/plugin.json`, and every tracked file under `agents/` and `templates/`.
  - (b) Reports against the base plugin. The base ref's `bin`, `templates`, `agents` and `.claude-plugin` are extracted with `git archive` into a temp plugin root. Fresh repositories are set up once with the base plugin and once with this checkout, each run twice: under `--host claude-code` and under `--host codex-cli`. In every run, each repository path is replaced by `<R>` and each plugin root by `<P>`. After that replacement, every head stdout equals the matching base stdout once the head's `- new Codex session: ` lines are removed. The head's first Codex-host run had exactly one such line.

  This is merge-point-scoped and expected to go stale once a later task's edits to these files land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1166-ac11.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; git ls-files -- agents templates > "$T/l" || rc=1; grep -qxF agents/engineer.md "$T/l" || rc=1; printf '%s\n' skills/run/SKILL.md bin/check-setup.sh bin/gen-codex-agents.sh bin/check-codex-agents.sh bin/team-init.sh bin/team-paths.sh .claude-plugin/plugin.json >> "$T/l"; while IFS= read -r f; do test -e "$f" || rc=1; git cat-file -e "$B:$f" 2>/dev/null || { rc=1; continue; }; git show "$B:$f" > "$T/x" 2>/dev/null || rc=1; cmp -s "$T/x" "$f" || rc=1; done < "$T/l"; mkdir -p "$T/base" || exit 1; git archive -o "$T/b.tar" "$B" bin templates agents .claude-plugin || exit 1; tar -xf "$T/b.tar" -C "$T/base" || exit 1; S0="$T/base/bin/team-setup.sh"; test -s "$S0" || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; run(){ (cd "$2" && PATH="$SP" bash "$1" --host "$3" < /dev/null > "$4" 2> /dev/null); }; for h in claude-code codex-cli; do RB="$T/rb-$h"; RH="$T/rh-$h"; mk "$RB" || rc=1; mk "$RH" || rc=1; for i in 1 2; do run "$S0" "$RB" "$h" "$T/ob$i" || rc=1; run "$S" "$RH" "$h" "$T/oh$i" || rc=1; sed -e "s|$T/base|<P>|g" -e "s|$RB|<R>|g" "$T/ob$i" > "$T/nb$i"; sed -e "s|$PR|<P>|g" -e "s|$RH|<R>|g" "$T/oh$i" > "$T/nh$i"; grep -v '^- new Codex session: ' "$T/nh$i" > "$T/fh$i"; test -s "$T/nb$i" || rc=1; cmp -s "$T/nb$i" "$T/fh$i" || rc=1; done; n=$(grep -c '^- new Codex session: ' "$T/oh1" || true); if [ "$h" = codex-cli ]; then test "$n" = 1 || rc=1; else test "$n" = 0 || rc=1; fi; done; test "$rc" -eq 0

- [ ] **AC12** On a clean install of the real Codex CLI host, the setup report that generates `.codex/agents` (or prints its run-yourself generator command) carries the `- new Codex session:` line, and the setup skill's closing message points at a new session. A run request typed in a new Codex session in that repository spawns `shell-team-tech-lead`.
  - above-ceiling: step V, the coordinating session — it runs the clean-install re-measurement on both hosts after the engineer's hand-off, records the relayed report line and the new-session spawn outcome on this task's board entry, and files a follow-up issue for any outcome outside decisions 1 and 4. QA reports this criterion as `SKIP` and audits the recorded result.

## Input space

**Reachable input classes**:

1. **Host.** A Codex CLI session (`CODEX_THREAD_ID` set, or `--host codex-cli`); a Claude Code session (unset, empty, or `--host claude-code`).
2. **`.codex/agents` state on the Codex CLI host.**
   - Absent (fresh repository).
   - Present and in sync.
   - Present with drift: an appended byte, a deleted role file, an older plugin version's files.
   - Absent with a `.codex` the sandbox refuses to write into (the measured first run).
   - Drifted in a non-writable `.codex/agents`.
3. **Exclude state.** The exclude line present, absent and writable, or absent with a read-only exclude (refused alone, agents in sync).
4. **Session sequence.** One setup run; a refused run, then the run-yourself generator command run in the session, then a re-run that reports `in sync` (the measured shape decision 4 carries forward); a re-run in a later session over an unchanged repository.
5. **Shells.** bash 3.2 (macOS) and bash 5 (Linux CI).

**Out-of-scope synthetic extremes**, declined explicitly:

1. Repository or plugin-root paths carrying a single quote or a control character: setup already refuses them with exit `2`.
2. A symlinked `.codex` or `.codex/agents`: setup refuses them with exit `2` (T-1163).
3. Concurrent setup runs in the same repository.
4. Running as root, where permission fixtures cannot refuse a write (**AC5** fails closed there).
5. A Codex host whose agent discovery picks up mid-session changes. The note is still printed, and it is still true that a new session works.

<!-- END intent-block: T-1166 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Note on `generated .codex/agents` (decision 1) | **AC1** |
| 2 | Note on `regenerated .codex/agents` (decision 1) | **AC2** |
| 3 | No note when in sync (decision 1, canon "nothing extra") | **AC3** |
| 4 | No note on the Claude Code host (decision 1, Non-goals) | **AC4**, **AC11** |
| 5 | Note on a refused generator write; none on a refused exclude alone (decision 1, refusal-path paragraph) | **AC5** |
| 6 | Placement under `Remains the operator's decision:`, one line, `- new Codex session: ` prefix, fact phrasing without `decision` (decision 2) | **AC1**, **AC5** |
| 7 | Every other report line unchanged (decision 2) | **AC11** |
| 8 | Idempotence: tree byte-identical, `Done:` `- none`, stable stdout (decision 3) | **AC3**, **AC9** |
| 9 | Skill step 5 carries the note forward across re-runs (decision 4) | **AC6** |
| 10 | Adopting guides beside the short path, relayed evidence, no identifiers, no new heading (decision 5) | **AC7** |
| 11 | README Install paragraphs (decision 5) | **AC8** |
| 12 | Run skill and `bin/check-setup.sh` unchanged (Non-goals) | **AC11** |
| 13 | No discovery workaround; generator and checker unchanged (Non-goals) | **AC11** |
| 14 | No agents/templates/team-init/team-paths/plugin.json change (Non-goals) | **AC11** |
| 15 | Exit-`2` report unspecified (Non-goals) | info-only (not promoted to AC) — declares an unspecified surface, nothing to verify |
| 16 | No recursive delete in tests or check lines (AC preamble) | **AC9** (grep gate) |
| 17 | Real-host spawnability (Non-goals) | **AC12** (above the ceiling) |
| 18 | Spec declarations conformant | **AC10** |

## Shipped-docs inventory

Every shipped document that names the Codex-host setup flow and whether its agents take effect:

| Document | Where | Disposition |
|---|---|---|
| `docs/adopting.md` | `## Using shell-team from Codex CLI`, short path `:413` | this-task (**AC7**) |
| `docs/adopting.ja.md` | `## Codex CLI から shell-team を使う`, `**近道` `:419` | this-task (**AC7**) |
| `README.md` | Install paragraph `:75` | this-task (**AC8**) |
| `README.ja.md` | Install paragraph `:75` | this-task (**AC8**) |
| `skills/setup/SKILL.md` | step 5 `:53` | this-task (**AC6**) |

`README.md` `:121` and `:123` (the `update shell-team` paragraph and the manual path) describe refreshing `.codex/agents/` without saying when the refreshed agents take effect. They are left as they are: the report line and the Install-paragraph sentence carry the fact, and `:121` already says the update reports what remains your decision. The coordinating session may judge otherwise at review. If so, the disposition is `this-task` with one sentence, not a re-freeze, because the Install-paragraph criterion is unaffected.

## Version derivation note

Premise: PATCH v2.8.1, approved at the 2026-10-02 sprint re-plan (relayed). Headline test: not met. Nothing new becomes possible: the report and docs now state a host fact that unblocks an existing path. Default-reachability: met, since every Codex-host `set up shell-team` run reaches the new line. Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed, primary confirmation on the coordinating side:** the measured run's sequence (first run exit `3` with two `- run yourself:` lines → per-command approval → re-run `in sync` → only the re-run relayed) and the evidence quoted in the Problem. The freeze run does not re-measure them: they come from a real-host run outside this repository. **AC12** is where they are re-observed.
- **Relayed:** the sprint premise (PATCH v2.8.1, re-plan 2026-10-02) and the A2 operating conditions.
- The second `- run yourself:` line in the measured run is assumed to be the exclude-line command, which on its own triggers no note (decision 1). The generator line is the one that does. Under the measured `.codex/`-creation refusal the generator line comes from the `:419` branch. Measured from the source: `:355`–`:366` and `:403`/`:419` are the only two refusal sites a fresh repository reaches.
- **Borrowed-vocabulary sweep:** the count premises here are about `new Codex session`, `新しい Codex セッション` and `agent_role`. All three are own-coinage. This role measured them with a repository grep excluding `.shell-team/`: 0 matches before this task. No borrowed token is asserted at a count.
- `gen-codex-agents.sh` is assumed to fail with a non-zero exit when it must create a role file inside a mode-`555` `.codex/agents`, which reaches the `:388` branch (**AC5** (b)). If it instead succeeds in place for the remaining files and still fails on the missing one, the branch is the same.

## Open questions

- none blocking.

## Notes for engineer

- Files likely touched:
  - `bin/team-setup.sh` §5: one flag set in the three generator branches and the two `refused "$regen_cmd"` sites, and one `add_remains` emitted once. Where it lands among the `Remains` lines is your call, as long as **AC11**'s equality holds after removing the note line. Update the header comment and `--help` if they enumerate report contents.
  - `tests/setup/run.sh`: new cases whose `PASS` lines name `T-1166` and the labels `generated`, `regenerated`, `in-sync`, `claude-code` and `refused`. Refusal cases are skipped as root, following AC6's precedent in the suite.
  - `skills/setup/SKILL.md` step 5.
  - The four docs.
- Gotchas:
  - `tests/setup/run.sh` AC8 counts exactly four non-`- ` lines. The note must be a `- ` item.
  - The suite's AC10 forbids fifteen tokens in the script, skill and run output. Keep the note free of them.
  - **AC11** (b) replaces repository paths and plugin roots with `sed` before comparing. A note line naming the plugin root is removed before comparison anyway.
  - Do not bump `.claude-plugin/plugin.json` (**AC11** (a)).
- Wording guidance (not frozen beyond **AC1**/**AC6**/**AC7**/**AC8**'s tokens): state the fact without the word "decision". For example: `- new Codex session: the roles in .codex/agents take effect in a new Codex session started in this repository (Codex does not pick up agents generated during a session); start the loop there`.
- Docs: follow `docs/adopting.md` `:432`'s relayed-evidence voice. Name codex-cli 0.159.3 and shell-team 2.8.0, the same-session failure, and the new-session and pre-generated-baseline spawns recorded as `agent_role`. Name no adopter, user account, machine or path.
- Measured-at-ref command check: not applicable. No deliverable prints a command beside a `measured at <ref>` label.
- No pre-commitment is frozen. This is a pure addition following an existing pattern (one report line, one skill sentence, doc sentences), not a verification mechanism.
- Recursive deletion: none in any file you write or any check line here. Leave temp files under `$TMPDIR`.
