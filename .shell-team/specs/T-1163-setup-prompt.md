# One prompt sets up or updates shell-team in the current repository, on both hosts

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1163

**Branch**: `feature/640-setup-prompt`, stacked on the local branches `feature/628-codex-setup-launch` (tip `0c8c52d3`) and `feature/639-rework-qa-scope`. Neither has an open pull request, and the pull request for this branch targets `develop` (`8a6cc48c`). So every base-side read resolves `git merge-base develop HEAD`, or its `refs/remotes/origin/develop` arm when only that ref resolves. The expression is spelled the same way in **AC12** and **AC13**.

## Problem

Setting up shell-team in a repository is a manual runbook today. On the Codex CLI host, an adopter run needed 12 out-of-session operator commands (relayed, see Assumptions). The runbook also tells the operator to grant trust, writable roots and network access, which are host settings that belong to the operator. Issue #640 asks for one in-session prompt that does the plugin's own part on both hosts and leaves every host-side condition with the operator. The canon text, relayed verbatim by the coordinating session:

> **Expected.** With the plugin already installed on the host, the operator types a short prompt inside the session — "set up shell-team" or "update shell-team" — and the session performs the plugin's own setup work for the current repository. The same prompt, the same flow and the same boundary apply on **both hosts** (Claude Code and Codex CLI); only the host-specific artifacts differ.
>
> - generate or refresh what the host needs from the plugin (the `team-init` scaffold when it is missing, on both hosts; the `.codex/agents/` roles on the Codex CLI host);
> - ensure generated, non-committed artifacts are ignored without editing a tracked file;
> - check drift against the installed plugin version and fix it;
> - check the prerequisites the loop needs from the host and **report** each unmet one with what it is needed for — never change the host's own configuration to meet it. Examples on the Codex CLI host: the repository is trusted so that project agents are discovered; commits are possible; the Claude Code CLI is present and answers. Examples on the Claude Code host: the Codex CLI is present and answers; the session can run the reviewer's `codex exec`; commits are possible;
> - end with a short report of what was done, what was already in place, and what remains the operator's decision.
>
> "Update" is the same flow re-run after a plugin upgrade; it is idempotent.
>
> **Security boundary (non-negotiable, both hosts).** A confirmation prompt shown to the operator during setup is acceptable. A confirmation that amounts to a critical security violation is never acceptable. Concretely, every confirmation setup asks for:
>
> - names one concrete command whose write set is bounded to the plugin's own artifacts (for example the shell-team base directory, `.codex/agents/`, `.git/info/exclude`);
> - never widens the session's sandbox, trust or permission policy — no trust grant, no writable root or allowed path beyond that artifact set, no network grant, no sandbox exclusion, no `danger-full-access`, no bypass of approvals or permission modes;
> - never writes the host's own configuration (Claude Code settings files, the Codex `config.toml`) and never adds a persistent approval or allow rule broader than that one command.
>
> Where the host refuses a write or command setup needs (for example the Codex sandbox refuses `.codex/` by default; a Claude Code sandbox or classifier may refuse a write), setup relies on the host's own per-command approval for that single bounded command, or stops and tells the operator the exact command to run themselves — it never asks for a wider grant to get past the refusal.
>
> **Out of scope.**
> - Choosing, composing, defaulting or writing any sandbox, trust, permission or network setting for the operator, on either host.
> - Changing Codex's or Claude Code's own discovery, trust, permission or sandbox model.

Host ruling (2026-10-01, relayed by the coordinating session, operator-ratified): the sandbox, trust, permission and network settings on both hosts always belong to the operator, and shell-team never touches them. This spec records it as never-dropped item N0.

## Summarized sources

- GitHub issue #640 (Expected, Security boundary, Out of scope). **Relayed verbatim by the coordinating session, not read by this role**, and quoted above. Distinctions carried over:
  - Setup is one in-session prompt, the same flow on both hosts, and only the artifacts differ by host. "Update" is the same flow re-run.
  - Prerequisites are **reported**, never met by changing the host's configuration.
  - The report has three parts: done, already in place, and what remains the operator's decision.
  - Every confirmation names one concrete command, bounded to the plugin's artifacts. It never widens policy and never writes host configuration.
  - When the host refuses a write, setup relies on the host's own per-command approval for that one command, or tells the operator the exact command.
  - Out of scope: composing any host setting, or changing either host's own model.
- `skills/team-init/SKILL.md` (read in full). Distinctions:
  - It runs `team-init.sh .` and never passes `--force` unless the user asks.
  - Invocation is `bash "<plugin root>/bin/team-init.sh"`, never assumed on `PATH` (`:19`–`:22`).
  - Frontmatter is a single `description:` line (`:1`–`:3`), the same shape as every other shipped skill (grepped).
- `bin/team-init.sh` (read `:1`–`:120`, `:276`–`:399`). Distinctions:
  - It creates missing scaffold files and skips existing ones with a `WARN: skipped existing file:` line on stderr. It never edits a host-root file.
  - `--force` overwrites every scaffold file, including `todo.md` (`copy_template`, `:348`). Only `test-recipe.md` is protected (`:361`).
  - Its created lines are `created: <path>` on stdout.
  - The base `.gitignore` comes from `templates/shell-team.gitignore` (`GITIGNORE_TPL`, `:362`). An older copy stays as it is on upgrade (`docs/adopting.md:42`–`:52`).
  - Exit `0` success, `2` usage.
- `bin/gen-codex-agents.sh` (read `:113`–`:124`). Distinctions:
  - Exit `0` generated, `1` a role file it cannot carry, `2` a usage or binding error. In both refusal cases nothing is written to `--out-dir`.
  - `--out-dir` defaults to `$PWD/.codex/agents`.
- `bin/check-codex-agents.sh` (read `:1`–`:65`, grepped `:132`–`:214`). Distinctions:
  - Exit `0` in sync, `1` drift, a missing expected file or an extra `shell-team-*.toml`, `2` a configuration error, including the source failing to regenerate.
  - It never writes `--out-dir`. Only `shell-team-*.toml` names count as "extra".
- `bin/check-count-claims.sh` (read `:1`–`:60`, grepped `:155`–`:186`). Distinctions:
  - A `- count:` row is collected by a wide stem anchored at the start of the line (`- count`, any case, then `:` or `：`).
  - Outside `--no-exec`, its `command:` field is run with `bash -c`, and empty or non-numeric output is refused.
- `bin/check-adopter-docs.sh` (read `:1`–`:160`). Distinctions:
  - The declaration region runs from the intent block's `BEGIN` to the first `## ` heading after it.
  - Each `this-task` `- shipped-docs:` path must be a literal substring of some `- check:` or `- adopter-surface:` line in the spec.
  - The deferral form is `issue #<N>`.
- `docs/adopting.md` `## Using shell-team from Codex CLI` (read `:376`–`:699`) and `docs/adopting.ja.md` `## Codex CLI から shell-team を使う` (read `:495`–`:575`, headings grepped). Distinctions:
  - Steps 5, 6 and 8 are headed as grants: `**Grant the repository Codex trust`, `**Grant the sandbox write access`, `**Grant the sandbox network access`; in ja `trust を付与する`, `書き込みを許可する`, and `許可する（T-1135）` on the line after step 8's head.
  - Each step composes `-c` flags or `config.toml` keys and offers `danger-full-access` as an alternative.
  - Step 9 is the `PATH` export.
  - Step 3 is the generator, run "from your own shell".
  - Steps 6 and 8 rest on codex-cli 0.154.0 measurements.
  - `:683` says whether a spawned agent sets `CODEX_THREAD_ID` is unmeasured.
- `README.md` (read `:37`–`:110`, `:158`–`:197`) and `README.ja.md` (grepped). Distinctions:
  - The Prerequisites paragraph `**Sandbox-enabled sessions need extra settings on both hosts.**` (`:49`, ja `:49`) points at the CC-host `sandbox.excludedCommands` settings and at the Codex-host writable-root and network grants.
  - `## Install` (`:51`) prints `/shell-team:team-init` for Claude Code, and the generator plus `team-init.sh` for Codex.
  - `## Update` (`:93`) asks for a generator re-run and a drift check.
  - `## Layout` lists `skills/` and `bin/` entries (`:174`–`:189`).
- `docs/distribution.md` (read `:1`–`:140`) and `docs/distribution.ja.md` (grepped). Distinctions:
  - `## Install`, `## Adopt in a target repo` and `## Update` print the generator, `team-init` and the drift check.
  - `## Sandbox-enabled permission settings` tells the operator to "Add the `sandbox.excludedCommands` form to your `.claude/settings.local.json`" (`:83`, ja `:83`: `の形を追加すると`).
  - `:104` says the Codex-host review's `claude -p` line runs outside the Codex sandbox.
- `docs/workflow.md:29` and `docs/workflow.ja.md:29` (grepped). Distinction: both list "repository trust, the sandbox grants and the `PATH` export" (ja `sandbox の許可`) as setup items.
- `docs/usage-conversational.md:103` and `.ja.md:104` (grepped). Distinction: both name `/shell-team:team-init` as the way to adopt the loop in a new repository. Line `:36`, which says team-init does not touch `CLAUDE.md`, stays true.
- `templates/prompt-blocks/host-dispatch.md` (read in full). Distinctions:
  - `:5` tells the Codex-host orchestrator to "grant the parent session's sandbox write access to `.git`" before a committing role runs.
  - `:15` (issue #593) says the review's `claude -p` line runs outside the Codex sandbox.
  - The block is spliced into `skills/run/SKILL.md`.
- `templates/AGENTS.md:6`, `templates/test-recipe.md:3`/`:8`, `templates/shell-team.contract.yaml:8` (grepped). Distinction: each says it is scaffolded by `team-init`, which stays true because setup calls `team-init.sh`.
- `agents/code-reviewer.md:234` and `tests/check-review-input/run.sh:303` (grepped). Distinction: the existing self-detected-host signal is `CODEX_THREAD_ID` set (`codex-cli`) or not set (`claude-code`).
- `.github/workflows/check-handoff.yml` (grepped). Distinctions: one workflow; its only `uses:` is `actions/checkout@v4` (`:15`); shellcheck steps are `run: shellcheck …` lines (`:29`–`:35`); one `run: bash tests/<suite>/run.sh` step per suite.
- `.claude-plugin/plugin.json` (read). Distinction: the installed plugin's version is its `"version"` field (`2.7.7` at this branch).
- `.shell-team/specs/T-1162-codex-setup-launch.md` (read in full). Distinction: it is the superseded predecessor and is not implemented. Its fixture shapes (temp `HOME`/`CODEX_HOME`, `GIT_CONFIG_GLOBAL=/dev/null`, stub CLIs, a `/usr/bin:/bin` `PATH`) are reused here as test idioms. Its launch script's composition of host settings is the thing #640 rules out.

## Goal

<!-- BEGIN intent-block: T-1163 -->

- user-visible: yes — on either host, an operator with the plugin installed types "set up shell-team" or "update shell-team" in a session. The session scaffolds the repository, generates or refreshes the Codex agents on the Codex CLI host, ignores them through `.git/info/exclude`, and reports what is done, what was already in place, and what remains the operator's decision. It never touches a host setting. The runbook and README lead with this prompt.
- verification-class: mechanism — the diff adds `bin/team-setup.sh`, `skills/setup/SKILL.md`, a fixture suite `tests/setup/run.sh` and a CI workflow step, plus shipped documentation.
- verification-ceiling: unit-and-static — **AC1**–**AC16** are settled in a plain checkout. They run `bin/team-setup.sh` in temp git repositories under `$TMPDIR` with a temp `HOME` and `CODEX_HOME` and stub CLIs on `PATH`, or read shipped files, compare base blobs, or take a suite's or checker's exit code. **AC17**, real in-session prompt triggering and real host approval prompts on both hosts, sits above the ceiling.
- base-ref-discriminator: not-applicable — this branch has no open predecessor pull request. It is stacked on the local branches `feature/628-codex-setup-launch` and `feature/639-rework-qa-scope`, neither with an open PR, and its own PR targets `develop`. Every base-side read resolves `git merge-base develop HEAD`, or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves, selected by `git show-ref --verify --quiet`.
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: docs/distribution.md — this-task
- shipped-docs: docs/distribution.ja.md — this-task
- shipped-docs: docs/usage-conversational.md — this-task
- shipped-docs: docs/usage-conversational.ja.md — this-task
- shipped-docs: docs/workflow.md — this-task
- shipped-docs: docs/workflow.ja.md — this-task
- shipped-docs: templates/prompt-blocks/host-dispatch.md — issue #640
- shipped-docs: skills/run/SKILL.md — issue #640

**Goal (one sentence).** On either host, the prompt "set up shell-team" or "update shell-team" makes the session run `bash "<plugin root>/bin/team-setup.sh"` from the current repository. The script scaffolds missing base-dir files through `team-init.sh` without overwriting any. On the Codex CLI host it also generates or refreshes `.codex/agents/` and ignores it through the git common directory's `info/exclude`. It writes nothing else: no tracked file, nothing under `$HOME` or `$CODEX_HOME`, and no host configuration. It reports missing CLIs and every host-side condition without changing any of them. It turns each refused write into one exact, single-artifact command for the host's own per-command approval or for the operator. It prints a three-part report (done, already in place, remains the operator's decision). A second run changes nothing.

**Decisions frozen here** (each is promoted to a criterion):

1. **Entry points.** One skill, `skills/setup/SKILL.md`, is the same file on both hosts. One script, `bin/team-setup.sh [--host claude-code|codex-cli]`, does every deterministic step. `--help` and `-h` print usage and exit `0` before any git call. `skills/team-init/SKILL.md` and `bin/team-init.sh` are unchanged. (**AC2**, **AC11**, **AC12**, **AC15**)
2. **Host selection.** `--host` decides when given. Otherwise a non-empty `CODEX_THREAD_ID` means `codex-cli` and anything else means `claude-code`. This reuses the existing self-detected-host signal and adds no new heuristic. The report's first line names the host and its ground. (**AC2**)
3. **Refusals before any write.** Setup exits `2` and writes nothing in each of these cases: outside a git work tree; on an unknown argument or `--host` value; or when the repository root or the plugin root contains a single quote or a control character, because a printed command could not be quoted safely. The repository root is `git rev-parse --show-toplevel`, so a run from a subdirectory scaffolds the root. (**AC2**)
4. **Write set (exhaustive).**
   - (a) What `team-init.sh` writes for the repository root: the resolved base dir, and in a legacy layout its specs dir. `--force` is never passed.
   - (b) On the Codex CLI host only, `<repo>/.codex/agents/`, through `gen-codex-agents.sh` with an explicit `--out-dir`.
   - (c) On the Codex CLI host only, `<git common dir>/info/exclude`. One `.codex/agents` line is appended only when `.codex/agents` is not already ignored and the line is not already there. Every existing byte is preserved, and the appended line starts on a line of its own.
   - Nothing else in the repository changes, no tracked file is edited, and nothing under `$HOME` or `$CODEX_HOME` changes. On the Claude Code host no `.codex` is created and `info/exclude` is not written. (**AC1**, **AC4**)
5. **Drift.**
   - When `.codex/agents` exists, setup runs `check-codex-agents.sh` on it. Exit `0` is "already in place". Exit `1` regenerates, and the re-check must then be `0`. Exit `2` makes setup exit `2` with nothing under `.codex/agents` changed.
   - When `.codex/agents` is absent, setup generates it.
   - Existing scaffold files are never rewritten. (**AC5**, **AC9**)
6. **Refused writes.** When a write in decision 4 fails, setup still completes the other steps. It then lists, under `Remains the operator's decision:`, one line per refused write: `- run yourself: ` followed by the one exact command whose write set is that single artifact, with absolute paths in single quotes. It exits `3`. The `- run yourself: ` prefix is reserved for this. (**AC6**)
7. **Prerequisites (report only).**
   - On the Codex CLI host setup checks `command -v claude`. On the Claude Code host it checks `command -v codex`.
   - A missing CLI is listed under `Remains the operator's decision:` on a line naming `command -v <cli>` and saying it is needed for the review pass. Setup exits `1`.
   - A present CLI is listed under `Already in place:`.
   - Setup never installs anything and never runs `claude` or `codex`. It runs no authentication probe, because a `claude -p` or `codex exec` call is a network and model call, and inside a sandbox it gives a misleading `Not logged in` (#593). On the Codex CLI host it prints the operator's own check `claude -p "reply with the single word ok"` instead. (**AC7**)
8. **Host-side conditions (operator's decisions).**
   - `Remains the operator's decision:` always carries one line per host-side condition, each saying what it is needed for and never prescribing a setting.
   - On the Codex CLI host: repository trust (project agents in `.codex/agents` are discovered only in a trusted repository; in the relayed 0.159.3 runs the host's own first-launch trust prompt sufficed), commits (write access to the git common directory), network for the review pass (in the relayed 0.159.3 runs the review's `claude -p` ran outside the sandbox under the host's per-command approval, so no network setting was needed for it), and `<plugin root>/bin` on `PATH` (spawned roles' bare-name calls; necessity unmeasured).
   - On the Claude Code host: the sandbox (the reviewer's `codex exec` runs outside it or under the host's per-command approval) and commits.
   - On both hosts: whether to track the base dir in git, and the review-transfer line. The review pass sends repository content to the other provider (Claude on the Codex CLI host, Codex on the Claude Code host). Approving that transfer is the operator's decision, and setup does not authorize it.
   - These lines never change the exit status. (**AC8**)
9. **Report.**
   - Stdout carries one header line, then `Done:`, `Already in place:` and `Remains the operator's decision:`, each exactly once and in that order.
   - Every item is a `- ` line, and an empty section is `- none`.
   - Diagnostics go to stderr.
   - The header names the host, its ground, and the installed plugin version read from `<plugin root>/.claude-plugin/plugin.json` (`unknown` when unreadable).
   - A non-protected scaffold file whose bytes differ from the installed plugin's template is listed under `Remains the operator's decision:` and never rewritten. The board and `test-recipe.md` are never listed.
   - Exit precedence is `2` > `3` > `1` > `0`. (**AC3**, **AC8**, **AC9**)
10. **The skill.**
    - It is a thin driver. It locates `<plugin root>` as the host reports it and runs the script from the repository root.
    - It relays the three sections, and for every `- run yourself:` line it does exactly one of two things: request the host's own per-command approval for exactly that command, or stop and tell the operator that command.
    - Each confirmation it asks for names one concrete command.
    - It never asks for a trust, sandbox, writable-root, network or permission grant, and never for an approval or permission-mode bypass. It never writes host configuration, never pre-authorizes the review transfer, and never hand-creates an artifact.
    - "update shell-team" runs the same flow. (**AC10**, **AC11**)
11. **Docs.**
    - The runbook, README, distribution, workflow and conversational-usage pages lead with the prompt. The plugin's part is the prompt, and each host-side condition is the operator's decision.
    - The "Grant …" step headings and imperatives go.
    - The measured facts they carried stay as facts about the host (trust, network, `PATH`, `Not logged in`, the setting names), each labelled by its measurement status.
    - No `## ` heading is added to either adopting guide. (**AC13**, **AC14**)

**Pre-commitment (frozen before round 1).** The threshold is two consecutive rounds whose `REQUEST_CHANGES` or `FAIL` each carry a new `Blocker` or `Major` against the same component.

Never-dropped. A defeat of any of these stops the task and returns it to planning. There is no carve-out.

- N0, operator-ratified (host ruling, 2026-10-01): sandbox, trust, permission and network settings on both hosts are the operator's and are never touched by shell-team (**AC1**, **AC6**, **AC10**, **AC11**).
- N1 (AI self-discipline, Routing Map): the write-set bound and "never writes host configuration" (**AC1**, **AC6**).
- N2 (AI self-discipline, Routing Map): the forbidden-widening lock (**AC10**).

Droppable, in order. Each drop executes this disposition rather than reopening the design:

- D1, the upgrade-report layer (**AC9**: the installed-version field of the header line and the scaffold template-diff list). The fallback is byte drift for `.codex/agents` (**AC5**) and team-init's skip report under `Already in place:`. The coordinating session files the rounds' findings against D1 as a follow-up issue, and **AC9** leaves the frozen block through a re-freeze recorded against this disposition.
- D2, prerequisite-report breadth (**AC8**'s host-condition word checks). It narrows to the `command -v` presence report (**AC7**) plus the review-transfer line, which is never dropped. The disposition has the same shape as D1.

## Non-goals

- **The run-time prerequisite check in the run skill** (the #625 part of #640) is owned by T-1164. (info-only)
- **Making the review pass's own approval request name its payload and destination** is owned by T-1164. Setup only reports the transfer as the operator's decision (**AC8**).
- **The clean-install re-verification on both hosts** is owned by step V, the coordinating session (**AC17**).
- **No sandbox, trust, permission or network setting is chosen, composed, defaulted or written for the operator, on either host** (issue Out of scope; N0). (**AC1**, **AC10**)
- **No change to either host's own discovery, trust, permission or sandbox model.** (**AC10**)
- **No change to `skills/team-init/SKILL.md`, `bin/team-init.sh`, `bin/team-paths.sh`, `bin/gen-codex-agents.sh`, `bin/check-codex-agents.sh`, any `agents/*.md`, the scaffold templates, `templates/prompt-blocks/host-dispatch.md` or `skills/run/SKILL.md`.** (**AC12**)
- **No authentication probe and no network or model call by setup, and no CLI installation.** (**AC7**)
- **No persistent version-stamp file.** Drift is measured from bytes. (info-only: a design decision. It is recorded in Notes for engineer.)
- **No CHANGELOG entry.** It is written at release time. (info-only)
- **No per-task full-population two-arm sweep**, under the operator's A2 ruling (2026-09-30). (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`. Fixtures do the following:

- export a temp `HOME`, `CODEX_HOME` and `XDG_CONFIG_HOME`;
- set `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`;
- unset `TEAM_RUN_BASE` and `CODEX_THREAD_ID`;
- put stub `claude` and `codex` executables, which exit `0`, first on `PATH`.

`RM` is the heading `Remains the operator's decision:`, and `sec <heading> <file>` prints the lines of that report section.

- [ ] **AC1** (N0, N1, never-dropped.) The write set is bounded.
  - Codex CLI host: run in a fresh committed repository, setup exits `0`. Comparing a recursive listing with checksums of the repository (excluding `.git/objects`) before and after shows only paths under `.shell-team`, `.codex` / `.codex/agents`, `.git/info` and `.git/info/exclude`. The changes include `./.shell-team/todo.md`, `./.codex/agents` and `./.git/info/exclude`. `HOME` and `CODEX_HOME` are byte-identical, and the generated agents check clean.
  - Claude Code host: the same run changes only paths under `.shell-team`, creates no `.codex`, and leaves `HOME` and `CODEX_HOME` byte-identical.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; ck(){ (cd "$1" && bash "$PR/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"; }; snap(){ (cd "$1" && find . -path ./.git/objects -prune -o -print | sort | while IFS= read -r p; do if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi; done); }; chg(){ diff "$1" "$2" | sed -n 's/^[<>] //p' | cut -d' ' -f1 | sort -u; }; R="$T/rx"; mk "$R" || rc=1; snap "$R" > "$T/r0"; snap "$HOME" > "$T/h0"; snap "$CODEX_HOME" > "$T/c0"; test "$(st "$R" --host codex-cli)" = 0 || rc=1; snap "$R" > "$T/r1"; snap "$HOME" > "$T/h1"; snap "$CODEX_HOME" > "$T/c1"; cmp -s "$T/h0" "$T/h1" || rc=1; cmp -s "$T/c0" "$T/c1" || rc=1; chg "$T/r0" "$T/r1" > "$T/d"; test -s "$T/d" || rc=1; while IFS= read -r p; do case "$p" in ./.shell-team|./.shell-team/*|./.codex|./.codex/agents|./.codex/agents/*|./.git/info|./.git/info/exclude) ;; *) rc=1 ;; esac; done < "$T/d"; for p in ./.shell-team/todo.md ./.codex/agents ./.git/info/exclude; do grep -qxF -- "$p" "$T/d" || rc=1; done; test "$(ck "$R")" = 0 || rc=1; R="$T/rc"; mk "$R" || rc=1; snap "$R" > "$T/r0"; snap "$HOME" > "$T/h0"; snap "$CODEX_HOME" > "$T/c0"; test "$(st "$R" --host claude-code)" = 0 || rc=1; snap "$R" > "$T/r1"; snap "$HOME" > "$T/h1"; snap "$CODEX_HOME" > "$T/c1"; cmp -s "$T/h0" "$T/h1" || rc=1; cmp -s "$T/c0" "$T/c1" || rc=1; chg "$T/r0" "$T/r1" > "$T/d"; grep -qxF ./.shell-team/todo.md "$T/d" || rc=1; while IFS= read -r p; do case "$p" in ./.shell-team|./.shell-team/*) ;; *) rc=1 ;; esac; done < "$T/d"; test ! -e "$R/.codex" || rc=1; test "$rc" -eq 0

- [ ] **AC2** Host selection, arguments, and refusals before any write.
  - With `CODEX_THREAD_ID` set and no `--host`, setup runs the Codex CLI flow: `.codex/agents` exists, and the first stdout line names `codex-cli` and `CODEX_THREAD_ID`.
  - With it unset, setup runs the Claude Code flow: no `.codex`, a scaffolded board, and a first line naming `claude-code`.
  - A run from a nested subdirectory scaffolds the repository root and nothing under the subdirectory.
  - Each of `--host bogus` and `--bogus` exits `2` and writes no `.shell-team` or `.codex`.
  - Outside a git work tree, setup exits `2` and the directory stays empty.
  - In a repository whose path contains a single quote, setup exits `2` and writes no `.shell-team` or `.codex`.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; R="$T/r1"; mk "$R" || rc=1; x=$(export CODEX_THREAD_ID=t; st "$R"); test "$x" = 0 || rc=1; test -d "$R/.codex/agents" || rc=1; head -n 1 "$T/o" > "$T/h"; grep -qF codex-cli "$T/h" || rc=1; grep -qF CODEX_THREAD_ID "$T/h" || rc=1; R="$T/r2"; mk "$R" || rc=1; test "$(st "$R")" = 0 || rc=1; test ! -e "$R/.codex" || rc=1; test -s "$R/.shell-team/todo.md" || rc=1; head -n 1 "$T/o" | grep -qF claude-code || rc=1; R="$T/r3"; mk "$R" || rc=1; mkdir -p "$R/sub/dir" || rc=1; test "$(st "$R/sub/dir" --host claude-code)" = 0 || rc=1; test -s "$R/.shell-team/todo.md" || rc=1; test ! -e "$R/sub/.shell-team" || rc=1; test ! -e "$R/sub/dir/.shell-team" || rc=1; R="$T/r4"; mk "$R" || rc=1; for a in '--host bogus' '--bogus'; do x=$(st "$R" $a); test "$x" = 2 || rc=1; done; test ! -e "$R/.shell-team" || rc=1; test ! -e "$R/.codex" || rc=1; mkdir -p "$T/ng" || rc=1; test "$(st "$T/ng" --host codex-cli)" = 2 || rc=1; test -z "$(find "$T/ng" -mindepth 1 -print)" || rc=1; R="$T/q'x"; mk "$R" || rc=1; test -d "$R/.git" || rc=1; test "$(st "$R" --host codex-cli)" = 2 || rc=1; test ! -e "$R/.shell-team" || rc=1; test ! -e "$R/.codex" || rc=1; test "$rc" -eq 0

- [ ] **AC3** Idempotency. On the Codex CLI host, the first run's `Done:` section is non-empty. A second run exits `0`, leaves the repository listing byte-identical to after the first run, prints `Done:` as exactly `- none`, and names both `.codex/agents` and `.shell-team` under `Already in place:`, with exactly one `.codex/agents` exclude line. On the Claude Code host a second run is byte-identical too and prints `Done:` as exactly `- none`.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; snap(){ (cd "$1" && find . -path ./.git/objects -prune -o -print | sort | while IFS= read -r p; do if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi; done); }; R="$T/r"; mk "$R" || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; test "$(sec Done: "$T/o" | grep -c .)" -ge 1 || rc=1; test "$(sec Done: "$T/o")" != '- none' || rc=1; snap "$R" > "$T/r1"; test "$(st "$R" --host codex-cli)" = 0 || rc=1; snap "$R" > "$T/r2"; cmp -s "$T/r1" "$T/r2" || rc=1; test "$(sec Done: "$T/o")" = '- none' || rc=1; sec 'Already in place:' "$T/o" > "$T/a"; grep -qF .codex/agents "$T/a" || rc=1; grep -qF .shell-team "$T/a" || rc=1; test "$(grep -cxF .codex/agents "$R/.git/info/exclude" || true)" = 1 || rc=1; R="$T/rc"; mk "$R" || rc=1; test "$(st "$R" --host claude-code)" = 0 || rc=1; snap "$R" > "$T/r1"; test "$(st "$R" --host claude-code)" = 0 || rc=1; snap "$R" > "$T/r2"; cmp -s "$T/r1" "$T/r2" || rc=1; test "$(sec Done: "$T/o")" = '- none' || rc=1; test "$rc" -eq 0

- [ ] **AC4** The exclude file. All runs are on the Codex CLI host.
  - An existing exclude holding `# keep` and `*.log` with no trailing newline keeps both lines whole and in place, and gains exactly one `.codex/agents` line. `git status` then reports nothing under `.codex`.
  - A repository whose committed `.gitignore` already covers `.codex/agents`, or whose exclude already carries `.codex/`, keeps its exclude byte-identical and reports nothing under `.codex`.
  - In a linked worktree, whose `.git` is a regular file, the main repository's `.git/info/exclude` gains exactly one `.codex/agents` line, no `exclude` file appears under `.git/worktrees`, the worktree's agents check clean, and its status reports nothing under `.codex`.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac4.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; ck(){ (cd "$1" && bash "$PR/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"; }; R="$T/r"; mk "$R" || rc=1; X="$R/.git/info/exclude"; mkdir -p "$R/.git/info" && printf '# keep\n*.log' > "$X" || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; test "$(head -n 1 "$X")" = '# keep' || rc=1; test "$(grep -cxF '*.log' "$X" || true)" = 1 || rc=1; test "$(grep -cxF .codex/agents "$X" || true)" = 1 || rc=1; test -z "$(git -C "$R" status --short --untracked-files=all -- .codex)" || rc=1; G="$T/g"; mk "$G" || rc=1; printf '.codex/agents\n' > "$G/.gitignore"; { git -C "$G" add .gitignore && git -C "$G" -c user.email=t@example.com -c user.name=t commit -q -m g; } || rc=1; mkdir -p "$G/.git/info" && touch "$G/.git/info/exclude" || rc=1; cp "$G/.git/info/exclude" "$T/gx" || rc=1; test "$(st "$G" --host codex-cli)" = 0 || rc=1; cmp -s "$T/gx" "$G/.git/info/exclude" || rc=1; test "$(ck "$G")" = 0 || rc=1; test -z "$(git -C "$G" status --short --untracked-files=all -- .codex)" || rc=1; B="$T/b"; mk "$B" || rc=1; mkdir -p "$B/.git/info" && printf '.codex/\n' > "$B/.git/info/exclude" || rc=1; cp "$B/.git/info/exclude" "$T/bx" || rc=1; test "$(st "$B" --host codex-cli)" = 0 || rc=1; cmp -s "$T/bx" "$B/.git/info/exclude" || rc=1; test -z "$(git -C "$B" status --short --untracked-files=all -- .codex)" || rc=1; M="$T/m"; W="$T/wt"; mk "$M" || rc=1; git -C "$M" worktree add -q "$W" > /dev/null 2>&1 || rc=1; test -f "$W/.git" || rc=1; test "$(st "$W" --host codex-cli)" = 0 || rc=1; test "$(grep -cxF .codex/agents "$M/.git/info/exclude" || true)" = 1 || rc=1; test -z "$(find "$M/.git/worktrees" -name exclude -print)" || rc=1; test "$(ck "$W")" = 0 || rc=1; test -z "$(git -C "$W" status --short --untracked-files=all -- .codex)" || rc=1; test "$rc" -eq 0

- [ ] **AC5** Drift is detected and fixed. All runs are on the Codex CLI host.
  - After setup, an appended byte in `shell-team-engineer.toml` makes `check-codex-agents.sh` exit `1`. A setup run then exits `0`, the agents check clean, and `Done:` names `.codex/agents`.
  - A deleted `shell-team-pm-spec.toml` is restored the same way.
  - With a plugin root holding `bin/` and `templates/` but no `agents/`, which is first asserted to make the checker exit `2`, that root's `team-setup.sh` exits `2` and leaves `.codex/agents` byte-identical.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac5.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; ck(){ (cd "$1" && bash "$PR/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"; }; R="$T/r"; mk "$R" || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; test "$(ck "$R")" = 0 || rc=1; printf 'drift\n' >> "$R/.codex/agents/shell-team-engineer.toml"; test "$(ck "$R")" = 1 || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; test "$(ck "$R")" = 0 || rc=1; sec Done: "$T/o" | grep -qF .codex/agents || rc=1; rm -f "$R/.codex/agents/shell-team-pm-spec.toml"; test "$(ck "$R")" = 1 || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; test "$(ck "$R")" = 0 || rc=1; mkdir -p "$T/pr" && cp -R "$PR/bin" "$PR/templates" "$T/pr/" || rc=1; test ! -e "$T/pr/agents" || rc=1; x=$( (cd "$R" && bash "$T/pr/bin/check-codex-agents.sh" --out-dir "$R/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"); test "$x" = 2 || rc=1; cp -R "$R/.codex/agents" "$T/a0" || rc=1; x=$( (cd "$R" && PATH="$SP" bash "$T/pr/bin/team-setup.sh" --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"); test "$x" = 2 || rc=1; diff -r "$T/a0" "$R/.codex/agents" > /dev/null || rc=1; test "$rc" -eq 0

- [ ] **AC6** (N0, N1, never-dropped.) A refused write becomes one exact single-artifact command, and setup never asks for a wider grant. The check refuses to run as root, because a permission fixture is meaningless there.
  - In a repository whose path contains a space, with a read-only `.git/info/exclude` inside a read-only `.git/info`, setup on the Codex CLI host exits `3`. The exclude stays byte-identical, while the board and the agents still land. The `RM` section carries exactly one `- run yourself: ` line, and its command names the exclude path. Run with `bash -c` after the permissions are restored, that command appends exactly one `.codex/agents` line and keeps `# keep` first.
  - With a read-only `.codex`, setup exits `3`, the exclude line still lands, and exactly one `- run yourself: ` line names `gen-codex-agents.sh` and `<repo>/.codex/agents`. Running it afterwards makes the agents check clean.
  - check: rc=0; export LC_ALL=C; test "$(id -u)" != 0 || exit 1; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac6.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; ck(){ (cd "$1" && bash "$PR/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"; }; R="$T/r w"; mk "$R" || rc=1; X="$R/.git/info/exclude"; mkdir -p "$R/.git/info" && printf '# keep\n' > "$X" || rc=1; cp "$X" "$T/x0" || rc=1; chmod 444 "$X"; chmod 555 "$R/.git/info"; x=$(st "$R" --host codex-cli); chmod 755 "$R/.git/info"; chmod 644 "$X"; test "$x" = 3 || rc=1; cmp -s "$T/x0" "$X" || rc=1; test -s "$R/.shell-team/todo.md" || rc=1; test "$(ck "$R")" = 0 || rc=1; sec "$RM" "$T/o" | grep '^- run yourself: ' > "$T/c"; test "$(grep -c . "$T/c")" = 1 || rc=1; C=$(sed 's/^- run yourself: //' "$T/c"); printf '%s\n' "$C" | grep -qF -- "$X" || rc=1; (cd "$R" && bash -c "$C") > /dev/null 2>&1 || rc=1; test "$(grep -cxF .codex/agents "$X" || true)" = 1 || rc=1; test "$(head -n 1 "$X")" = '# keep' || rc=1; R="$T/r2"; mk "$R" || rc=1; mkdir -p "$R/.codex" && chmod 555 "$R/.codex" || rc=1; x=$(st "$R" --host codex-cli); chmod 755 "$R/.codex"; test "$x" = 3 || rc=1; test "$(grep -cxF .codex/agents "$R/.git/info/exclude" || true)" = 1 || rc=1; sec "$RM" "$T/o" | grep '^- run yourself: ' > "$T/c"; test "$(grep -c . "$T/c")" = 1 || rc=1; C=$(sed 's/^- run yourself: //' "$T/c"); printf '%s\n' "$C" | grep -qF gen-codex-agents.sh || rc=1; printf '%s\n' "$C" | grep -qF -- "$R/.codex/agents" || rc=1; (cd "$R" && bash -c "$C") > /dev/null 2>&1 || rc=1; test "$(ck "$R")" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC7** Prerequisites are reported and never met or probed.
  - The `PATH` used is an empty directory plus `/usr/bin:/bin`, first asserted to resolve `git` and neither `claude` nor `codex`.
  - On that `PATH`, setup on the Codex CLI host exits `1`. Its `RM` section has a line naming `command -v claude` and `review`, and it still completes: the agents check clean and the exclude line lands.
  - On the Claude Code host it exits `1`, with a line naming `command -v codex` and `review`, and the board lands.
  - Nothing is created in the empty directory, `HOME` or `CODEX_HOME`.
  - With stub CLIs that record any invocation: on the Codex CLI host setup exits `0`, names `claude` under `Already in place:`, and prints `claude -p "reply with the single word ok"` under `RM`. On the Claude Code host it exits `0` and names `codex` under `Already in place:`. Neither stub is ever invoked.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac7.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/e0" "$T/p" || exit 1; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; ck(){ (cd "$1" && bash "$PR/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1); printf '%s' "$?"; }; NP="$T/e0:/usr/bin:/bin"; (PATH="$NP"; command -v git > /dev/null 2>&1) || rc=1; (PATH="$NP"; command -v claude > /dev/null 2>&1 || command -v codex > /dev/null 2>&1) && rc=1; nr(){ d="$1"; shift; (cd "$d" && PATH="$NP" "$BASH" "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; R="$T/r1"; mk "$R" || rc=1; test "$(nr "$R" --host codex-cli)" = 1 || rc=1; sec "$RM" "$T/o" | grep -F 'command -v claude' | grep -qF review || rc=1; test "$(ck "$R")" = 0 || rc=1; test "$(grep -cxF .codex/agents "$R/.git/info/exclude" || true)" = 1 || rc=1; R="$T/r2"; mk "$R" || rc=1; test "$(nr "$R" --host claude-code)" = 1 || rc=1; sec "$RM" "$T/o" | grep -F 'command -v codex' | grep -qF review || rc=1; test -s "$R/.shell-team/todo.md" || rc=1; test -z "$(find "$T/e0" "$HOME" "$CODEX_HOME" -mindepth 1 -print)" || rc=1; export PROBE="$T/called"; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'touch "$PROBE"' 'exit 0' > "$T/p/$b" && chmod +x "$T/p/$b" || exit 1; done; SP="$T/p:$PATH"; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; R="$T/r3"; mk "$R" || rc=1; test "$(st "$R" --host codex-cli)" = 0 || rc=1; sec 'Already in place:' "$T/o" | grep -qF claude || rc=1; sec "$RM" "$T/o" | grep -qF 'claude -p "reply with the single word ok"' || rc=1; R="$T/r4"; mk "$R" || rc=1; test "$(st "$R" --host claude-code)" = 0 || rc=1; sec 'Already in place:' "$T/o" | grep -qF codex || rc=1; test ! -e "$PROBE" || rc=1; test "$rc" -eq 0

- [ ] **AC8** The report's shape and the host-side conditions. For each host, a run exits `0` and stdout meets these conditions:
  - It carries `Done:`, `Already in place:` and `RM` each exactly once, in that order, after line 1.
  - Exactly four of its non-empty lines do not begin with `- ` (the header and the three headings).
  - Its `RM` section names `sends repository content to`.
  - On the Codex CLI host the `RM` section also names `trust`, `network`, `PATH` and `commit`. On the Claude Code host it names `sandbox`, `codex exec` and `commit`. These word checks are D2.

  Review-judged: each host-side line says what the condition is needed for and prescribes no setting. The review-transfer line says that approving the transfer is the operator's decision and that setup does not authorize it.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac8.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; for h in codex-cli claude-code; do R="$T/r-$h"; mk "$R" || rc=1; test "$(st "$R" --host "$h")" = 0 || rc=1; for k in 'Done:' 'Already in place:' "$RM"; do test "$(grep -cxF -- "$k" "$T/o" || true)" = 1 || rc=1; done; a=$(grep -nxF 'Done:' "$T/o" | cut -d: -f1); b=$(grep -nxF 'Already in place:' "$T/o" | cut -d: -f1); c=$(grep -nxF -- "$RM" "$T/o" | cut -d: -f1); { test -n "$a" && test -n "$b" && test -n "$c" && test 1 -lt "$a" && test "$a" -lt "$b" && test "$b" -lt "$c"; } || rc=1; test "$(grep -v '^- ' "$T/o" | grep -c .)" = 4 || rc=1; sec "$RM" "$T/o" > "$T/m-$h"; grep -qF 'sends repository content to' "$T/m-$h" || rc=1; done; for w in trust network PATH commit; do grep -qF -- "$w" "$T/m-codex-cli" || rc=1; done; for w in sandbox 'codex exec' commit; do grep -qF -- "$w" "$T/m-claude-code" || rc=1; done; test "$rc" -eq 0

- [ ] **AC9** (D1, droppable first.) The upgrade-report layer.
  - The first stdout line names the version in `.claude-plugin/plugin.json`.
  - After the base `.gitignore`, the board and `test-recipe.md` are each edited locally, a second run exits `0` and its `Done:` is `- none`.
  - That run's `RM` section names `.shell-team/.gitignore` and names neither `todo.md` nor `test-recipe.md`.
  - All three files stay byte-identical to their edited state.
  - check: rc=0; export LC_ALL=C; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; test -s "$S" || exit 1; V=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$PR/.claude-plugin/plugin.json" | head -n 1); test -n "$V" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac9.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; RM="Remains the operator's decision:"; sec(){ awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }; R="$T/r"; mk "$R" || rc=1; test "$(st "$R" --host claude-code)" = 0 || rc=1; head -n 1 "$T/o" | grep -qF -- "$V" || rc=1; printf '# local edit\n' >> "$R/.shell-team/.gitignore"; printf '\nlocal note\n' >> "$R/.shell-team/todo.md"; printf '\nlocal note\n' >> "$R/.shell-team/test-recipe.md"; for f in .gitignore todo.md test-recipe.md; do cp "$R/.shell-team/$f" "$T/k-$f" || rc=1; done; test "$(st "$R" --host claude-code)" = 0 || rc=1; test "$(sec Done: "$T/o")" = '- none' || rc=1; sec "$RM" "$T/o" > "$T/m"; grep -qF .shell-team/.gitignore "$T/m" || rc=1; grep -qF todo.md "$T/m" && rc=1; grep -qF test-recipe.md "$T/m" && rc=1; for f in .gitignore todo.md test-recipe.md; do cmp -s "$T/k-$f" "$R/.shell-team/$f" || rc=1; done; test "$rc" -eq 0

- [ ] **AC10** (N0, N2, never-dropped.) The forbidden-widening lock. None of these tokens occurs in `bin/team-setup.sh`, in `skills/setup/SKILL.md`, or in the combined stdout and stderr of setup runs on both hosts plus a refused-write run: `trust_level`, `writable_roots`, `network_access`, `sandbox_workspace_write`, `danger-full-access`, `excludedCommands`, `dangerously`, `bypassPermissions`, `--full-auto`, `--yolo`, `approval_policy`, `permissions.allow`, `config.toml`, `settings.json`, `settings.local.json`. Each read is asserted to complete (grep exit `1`, never `2`). Positive controls: the script names `team-init.sh`, the skill names `one concrete command`, and the run output names `run yourself`.
  - check: rc=0; export LC_ALL=C; test "$(id -u)" != 0 || exit 1; PR=$(pwd -P); S="$PR/bin/team-setup.sh"; F2="$PR/skills/setup/SKILL.md"; test -s "$S" || exit 1; test -s "$F2" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac10.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; SP="$T/s:$PATH"; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; st(){ d="$1"; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; grep -qF team-init.sh "$S" || rc=1; grep -qF 'one concrete command' "$F2" || rc=1; : > "$T/all"; for h in codex-cli claude-code; do R="$T/r-$h"; mk "$R" || rc=1; st "$R" --host "$h" > /dev/null; cat "$T/o" "$T/e" >> "$T/all"; done; R="$T/rq"; mk "$R" || rc=1; mkdir -p "$R/.codex" && chmod 555 "$R/.codex" || rc=1; st "$R" --host codex-cli > /dev/null; chmod 755 "$R/.codex"; cat "$T/o" "$T/e" >> "$T/all"; grep -qF 'run yourself' "$T/all" || rc=1; for t in trust_level writable_roots network_access sandbox_workspace_write danger-full-access excludedCommands dangerously bypassPermissions --full-auto --yolo approval_policy permissions.allow config.toml settings.json settings.local.json; do for f in "$S" "$F2" "$T/all"; do grep -qF -- "$t" "$f"; g=$?; test "$g" -eq 1 || rc=1; done; done; test "$rc" -eq 0

- [ ] **AC11** (N0.) The skill is the same on both hosts and carries the boundary.
  - `skills/setup/SKILL.md` opens with a `---` frontmatter holding exactly one `description:` line, which names both `set up shell-team` and `update shell-team`.
  - The file names `bash "<plugin root>/bin/team-setup.sh"`, `one concrete command`, `run yourself`, `Remains the operator's decision`, `Already in place`, `Done` and `both hosts`.

  Review-judged, against decision 10: each `- run yourself:` command goes either to the host's own per-command approval for exactly that command or to the operator. No wider grant is ever requested, no host configuration is written, the review transfer is not pre-authorized, no artifact is hand-created, and "update" re-runs the same flow.
  - check: rc=0; export LC_ALL=C; F=skills/setup/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac11.XXXXXX") || exit 1; test "$(head -n 1 "$F")" = '---' || rc=1; awk 'NR==1{next} $0=="---"{exit} {print}' "$F" > "$T/fm"; test "$(grep -c '^description:' "$T/fm" || true)" = 1 || rc=1; grep '^description:' "$T/fm" > "$T/d"; for w in 'set up shell-team' 'update shell-team'; do grep -qF -- "$w" "$T/d" || rc=1; done; for w in 'bash "<plugin root>/bin/team-setup.sh"' 'one concrete command' 'run yourself' "Remains the operator's decision" 'Already in place' 'Done' 'both hosts'; do grep -qF -- "$w" "$F" || rc=1; done; test "$rc" -eq 0

- [ ] **AC12** The surfaces this task must not touch are byte-identical to their base blobs. They are every tracked `agents/*` file, plus `bin/team-init.sh`, `skills/team-init/SKILL.md`, `bin/team-paths.sh`, `bin/gen-codex-agents.sh`, `bin/check-codex-agents.sh`, `templates/AGENTS.md`, `templates/test-recipe.md`, `templates/shell-team.contract.yaml`, `templates/todo-template.md`, `templates/shell-team.gitignore`, `templates/prompt-blocks/host-dispatch.md` and `skills/run/SKILL.md`. Each base blob is asserted non-empty.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac12.XXXXXX") || exit 1; git ls-files -- agents > "$T/l" || rc=1; test -s "$T/l" || rc=1; printf '%s\n' bin/team-init.sh skills/team-init/SKILL.md bin/team-paths.sh bin/gen-codex-agents.sh bin/check-codex-agents.sh templates/AGENTS.md templates/test-recipe.md templates/shell-team.contract.yaml templates/todo-template.md templates/shell-team.gitignore templates/prompt-blocks/host-dispatch.md skills/run/SKILL.md >> "$T/l"; while IFS= read -r f; do test -s "$f" || rc=1; git show "$B:$f" > "$T/x" 2>/dev/null || rc=1; test -s "$T/x" || rc=1; cmp -s "$T/x" "$f" || rc=1; done < "$T/l"; test "$rc" -eq 0

- [ ] **AC13** The adopting guides lead with the prompt and drop the grant imperatives, in both languages.
  - Each Codex CLI section heading occurs exactly once. In each section, the first line naming `set up shell-team` comes before any line naming `gen-codex-agents.sh`, and the section names `update shell-team` and `0.159.3` (the relayed measurement version).
  - The en section names `operator's decision` and has no line containing `**Grant `.
  - The ja section names `判断` and has no line containing `trust を付与する` or `書き込みを許可する`, and no line beginning `許可する（T-1135）`.
  - The en section keeps the measured-fact anchors `stale`, `trust_level`, `network_access`, `sandbox_workspace_write`, `Not logged in`, `export PATH`, `check-codex-agents.sh` and `.gitignore`.
  - Each file's `## ` heading count equals its base blob's, and neither base blob names `set up shell-team`.
  - adopter-surface: `docs/adopting.md` `## Using shell-team from Codex CLI` and `docs/adopting.ja.md` `## Codex CLI から shell-team を使う` (the setup prompt first, then what setup does and what remains the operator's decision, and the manual steps as the fallback), plus the README, distribution, workflow and conversational-usage pages in **AC14**.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac13.XXXXXX") || exit 1; HE='## Using shell-team from Codex CLI'; HJ='## Codex CLI から shell-team を使う'; test "$(grep -cxF -- "$HE" "$E" || true)" = 1 || rc=1; test "$(grep -cxF -- "$HJ" "$J" || true)" = 1 || rc=1; X='$0==h{f=1;next} f&&index($0,"## ")==1{f=0} f'; awk -v h="$HE" "$X" "$E" > "$T/e"; awk -v h="$HJ" "$X" "$J" > "$T/j"; test -s "$T/e" || rc=1; test -s "$T/j" || rc=1; ord(){ a=$(grep -nF -- 'set up shell-team' "$1" | head -n 1 | cut -d: -f1); g=$(grep -nF -- 'gen-codex-agents.sh' "$1" | head -n 1 | cut -d: -f1); test -n "$a" || return 1; test -z "$g" || test "$a" -lt "$g"; }; no(){ grep -qF -- "$2" "$1"; g=$?; test "$g" -eq 1; }; ord "$T/e" || rc=1; ord "$T/j" || rc=1; for f in "$T/e" "$T/j"; do for w in 'update shell-team' '0.159.3'; do grep -qF -- "$w" "$f" || rc=1; done; done; grep -qF "operator's decision" "$T/e" || rc=1; grep -qF '判断' "$T/j" || rc=1; no "$T/e" '**Grant ' || rc=1; no "$T/j" 'trust を付与する' || rc=1; no "$T/j" '書き込みを許可する' || rc=1; grep -qE '^[[:space:]]*許可する（T-1135）' "$T/j"; g=$?; test "$g" -eq 1 || rc=1; for w in 'stale' 'trust_level' 'network_access' 'sandbox_workspace_write' 'Not logged in' 'export PATH' 'check-codex-agents.sh' '.gitignore'; do grep -qF -- "$w" "$T/e" || rc=1; done; for f in "$E" "$J"; do git show "$B:$f" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; test "$(grep -c '^## ' "$f" || true)" = "$(grep -c '^## ' "$T/b" || true)" || rc=1; no "$T/b" 'set up shell-team' || rc=1; done; test "$rc" -eq 0

- [ ] **AC14** The other shipped pages lead with the prompt, in both languages. Each of `README.md`, `README.ja.md`, `docs/distribution.md`, `docs/distribution.ja.md`, `docs/usage-conversational.md`, `docs/usage-conversational.ja.md`, `docs/workflow.md` and `docs/workflow.ja.md` names `set up shell-team`.
  - In each README, the install section (`## Install` / `## インストール`) names `set up shell-team` before any `gen-codex-agents.sh` line, and the update section (`## Update` / `## 更新`) names `update shell-team`.
  - `README.md`'s `## Prerequisites` section names `operator's decision`. Neither README has a line beginning with the old `Sandbox-enabled sessions need extra settings` / `サンドボックス有効なセッションでは` bold paragraph. Both READMEs name `skills/setup/SKILL.md` and `team-setup.sh` in their layout.
  - Both distribution pages name `update shell-team`. `docs/distribution.md` has no line beginning ``Add the `sandbox.excludedCommands` form to your``, and the ja page has no line containing `の形を追加すると`.
  - `docs/workflow.md` no longer contains `the sandbox grants`, and the ja page no longer contains `sandbox の許可`.

  Review-judged: every host-side condition on these pages is stated as the operator's decision, saying what it is needed for, with no instruction to grant or set it.
  - adopter-surface: `README.md` / `README.ja.md` (`## Install`, `## Update`, the Prerequisites paragraph, `## Layout`), `docs/distribution.md` / `docs/distribution.ja.md` (install, adopt, update and the sandbox-settings section), `docs/workflow.md` / `docs/workflow.ja.md` (the setup pointer), and `docs/usage-conversational.md` / `docs/usage-conversational.ja.md` (the adopt line).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac14.XXXXXX") || exit 1; X='$0==h{f=1;next} f&&index($0,"## ")==1{f=0} f'; sx(){ test "$(grep -cxF -- "$2" "$1" || true)" = 1 || return 1; awk -v h="$2" "$X" "$1" > "$3"; test -s "$3"; }; ord(){ a=$(grep -nF -- 'set up shell-team' "$1" | head -n 1 | cut -d: -f1); g=$(grep -nF -- 'gen-codex-agents.sh' "$1" | head -n 1 | cut -d: -f1); test -n "$a" || return 1; test -z "$g" || test "$a" -lt "$g"; }; no(){ grep -qF -- "$2" "$1"; g=$?; test "$g" -eq 1; }; for f in README.md README.ja.md docs/distribution.md docs/distribution.ja.md docs/usage-conversational.md docs/usage-conversational.ja.md docs/workflow.md docs/workflow.ja.md; do test -s "$f" || exit 1; grep -qF 'set up shell-team' "$f" || rc=1; done; sx README.md '## Install' "$T/ri" || rc=1; ord "$T/ri" || rc=1; sx README.md '## Update' "$T/ru" || rc=1; grep -qF 'update shell-team' "$T/ru" || rc=1; sx README.md '## Prerequisites' "$T/rp" || rc=1; grep -qF "operator's decision" "$T/rp" || rc=1; sx README.ja.md '## インストール' "$T/ji" || rc=1; ord "$T/ji" || rc=1; sx README.ja.md '## 更新' "$T/ju" || rc=1; grep -qF 'update shell-team' "$T/ju" || rc=1; grep -qE '^[*][*]Sandbox-enabled sessions need extra settings' README.md; g=$?; test "$g" -eq 1 || rc=1; grep -qE '^[*][*]サンドボックス有効なセッションでは' README.ja.md; g=$?; test "$g" -eq 1 || rc=1; for f in README.md README.ja.md; do grep -qF 'skills/setup/SKILL.md' "$f" || rc=1; grep -qF 'team-setup.sh' "$f" || rc=1; done; for f in docs/distribution.md docs/distribution.ja.md; do grep -qF 'update shell-team' "$f" || rc=1; done; grep -qE '^Add the .sandbox[.]excludedCommands. form to your' docs/distribution.md; g=$?; test "$g" -eq 1 || rc=1; no docs/distribution.ja.md 'の形を追加すると' || rc=1; no docs/workflow.md 'the sandbox grants' || rc=1; no docs/workflow.ja.md 'sandbox の許可' || rc=1; test "$rc" -eq 0

- [ ] **AC15** The new files are linted, executable, wired into CI and the test recipe, and every suite the edited paths reach stays green.
  - `shellcheck` (its `--version` asserted to run first) exits `0` on `bin/team-setup.sh` and `tests/setup/run.sh`, and each is named on a `run: shellcheck ` line of `.github/workflows/check-handoff.yml`.
  - The workflow carries `run: bash tests/setup/run.sh`. It is still the only tracked workflow, and every `uses:` in it is `actions/checkout@…`.
  - `bin/team-setup.sh` is tracked with mode `100755`.
  - The test recipe resolved through `bin/team-paths.sh --get base` names `tests/setup/run.sh`.
  - Each of these exits `0` with no line beginning `FAIL`: `tests/setup/run.sh` (which also prints at least one `PASS` line), `bin-help`, `bin-exec-bit`, `errexit-safe`, `team-init`, `codex-agents`, `check-invocation-path`, `check-prompt-sync`, `check-adopter-docs`, and every `tests/*/run.sh` that `git grep` finds naming an edited document (derived at run time and asserted non-empty).
  - `bin/check-handoff.sh` exits `0` on the resolved board.
  - check: rc=0; export LC_ALL=C; command -v shellcheck > /dev/null 2>&1 || exit 1; shellcheck --version > /dev/null || exit 1; W=.github/workflows/check-handoff.yml; test -s "$W" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac15.XXXXXX") || exit 1; for f in bin/team-setup.sh tests/setup/run.sh; do test -s "$f" || rc=1; shellcheck "$f" > /dev/null 2>&1 || rc=1; grep -E '^[[:space:]]*run: shellcheck ' "$W" | grep -qF -- "$f" || rc=1; done; grep -qxE '[[:space:]]*run: bash tests/setup/run.sh' "$W" || rc=1; test "$(git ls-files -- .github/workflows)" = .github/workflows/check-handoff.yml || rc=1; grep -E '^[[:space:]]*(-[[:space:]]+)?uses:' "$W" > "$T/u"; test -s "$T/u" || rc=1; grep -vF 'actions/checkout@' "$T/u" > "$T/ux"; test ! -s "$T/ux" || rc=1; test "$(git ls-files -s -- bin/team-setup.sh | cut -d' ' -f1)" = 100755 || rc=1; BS=$(bash bin/team-paths.sh --get base) || rc=1; grep -qF 'tests/setup/run.sh' "$BS/test-recipe.md" || rc=1; git grep -lE 'adopting|README|distribution\.md|workflow\.md|usage-conversational|test-recipe' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; test -s "$T/d" || rc=1; { printf '%s\n' tests/setup/run.sh tests/bin-help/run.sh tests/bin-exec-bit/run.sh tests/errexit-safe/run.sh tests/team-init/run.sh tests/codex-agents/run.sh tests/check-invocation-path/run.sh tests/check-prompt-sync/run.sh tests/check-adopter-docs/run.sh; cat "$T/d"; } | sort -u > "$T/suites"; while IFS= read -r s; do test -s "$s" || rc=1; bash "$s" < /dev/null > "$T/log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; if [ "$s" = tests/setup/run.sh ]; then test "$(grep -c '^PASS' "$T/log" || true)" -ge 1 || rc=1; fi; done < "$T/suites"; BD=$(bash bin/team-paths.sh --get todo) || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC16** This spec carries its own declarations conformantly. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. Positive control: the spec and the checker are asserted non-empty first.
  - check: C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1163-setup-prompt.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1163-ac16.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; rc=0; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; test "$rc" -eq 0

- [ ] **AC17** On a clean install of each real host, the setup prompt works in-session. The prompt "set up shell-team" triggers the setup skill. Every confirmation the host shows during it names one command whose write set is one of the plugin's artifacts, and none of them widens the sandbox, trust, permission or network policy. Each refused write is either approved per command by the host or handed to the operator as the printed command. The report's three sections match the repository's state. Re-typing "update shell-team" produces `Done:` as `- none`. The count of out-of-session operator commands for the plugin's part is 0.
  - above-ceiling: step V, the coordinating session — it runs the clean-install re-verification on both hosts after the engineer's hand-off, records each host's confirmations verbatim, the report and the out-of-session command count on this task's board entry, and files a follow-up issue for any confirmation that falls outside decision 10. QA reports this criterion as `SKIP` and audits the recorded result.

## Input space

**Reachable input classes**:

1. **Host.** A Claude Code session; a Codex CLI session, where `CODEX_THREAD_ID` is set; an explicit `--host` value; an invalid `--host` value.
2. **Invocation.** From the repository root, from a subdirectory, or from a linked worktree; outside any git work tree; with an unknown argument; with `--help` or `-h`.
3. **Repository state.**
   - Fresh: no base dir, no `.codex`.
   - Already set up by this version.
   - Set up by an older plugin version: drifted or missing `.codex/agents` files, an older base `.gitignore`.
   - Set up by hand through the runbook: `.codex/agents` in a committed `.gitignore` or in `info/exclude`, or a broader `.codex/` rule.
   - A board and test recipe already edited by the adopter.
   - A legacy `tasks/` layout or a `TEAM_RUN_BASE` override.
4. **The exclude file.** Absent; present with content; without a trailing newline; already carrying the line.
5. **Host refusals.** The Codex sandbox refusing `.codex/` or `.git/` writes (its default), or a Claude Code sandbox or classifier refusing a write. In fixtures these are modelled as unwritable paths.
6. **`PATH`.** `claude` or `codex` present or absent.
7. **Paths.** Repository paths with spaces and `.`. Rarely, a repository or plugin root containing a single quote or a control character, which is refused.
8. **Plugin root.** An installed plugin cache on either host, or a checkout. Also a plugin root whose source cannot regenerate the agents (checker exit `2`).
9. **Shells.** bash 3.2 (macOS) and bash 5 (Linux CI).

**Out-of-scope synthetic extremes**, declined explicitly:

1. Repository paths carrying non-UTF-8 byte sequences.
2. An adopter who has committed `.codex/agents` to git. Setup neither untracks it nor promises a clean status.
3. An `info/exclude` that is a symlink, or a repository on read-only media in a way other than a host refusal.
4. Concurrent setup runs in the same repository.
5. A tampered plugin root (hand-edited templates or scripts).
6. A first-time run (no `.codex/agents`) against a plugin root whose source cannot regenerate. Setup exits non-zero and writes no role file, but which of `2` or `3` it uses is not asserted.
7. A bare repository.

<!-- END intent-block: T-1163 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | One skill for both hosts, one script; team-init unchanged (decision 1) | **AC11**, **AC12**, **AC15** |
| 2 | Host from `--host` or `CODEX_THREAD_ID`, no new heuristic (decision 2) | **AC2** |
| 3 | Refusals before any write (decision 3) | **AC2** |
| 4 | Exhaustive write set; nothing under `HOME`/`CODEX_HOME`; no tracked file; no host configuration (decision 4, canon, N1) | **AC1**, **AC4** |
| 5 | Drift: check, regenerate, refuse on exit `2`; scaffold never rewritten (decision 5, canon) | **AC5**, **AC9** |
| 6 | Refused write → one exact single-artifact command; no wider grant (decision 6, canon Security boundary) | **AC6**, **AC10** |
| 7 | Prerequisites reported, never installed or probed (decision 7, canon) | **AC7** |
| 8 | Host-side conditions as operator's decisions; review-transfer line (decision 8, measured input 6) | **AC8** |
| 9 | Three-section report; exit precedence; version line; template diff (decision 9) | **AC3**, **AC8**, **AC9**. The exit precedence between `3` and `1` when both apply is review-judged. |
| 10 | Skill boundary (decision 10, canon) | **AC10**, **AC11** (tokens), review-judged meaning |
| 11 | Docs lead with the prompt, no grant imperatives, facts kept and labelled, no new heading (decision 11) | **AC13**, **AC14** |
| 12 | Idempotent "update" (canon) | **AC3** |
| 13 | Host ruling N0 | **AC1**, **AC6**, **AC10**, **AC11** |
| 14 | Real-host behaviour | **AC17** (above the ceiling) |
| 15 | Declarations conformant | **AC16** |
| 16 | T-1164 and step V own the split-off parts (Non-goals) | info-only (not promoted to AC). It records ownership, not a property of this diff. |
| 17 | No version-stamp file (Non-goals) | info-only (not promoted to AC). It is a design decision, and **AC1**'s write-set bound already forbids any extra file outside the three artifacts. |
| 18 | No CHANGELOG, no per-task sweep (Non-goals) | info-only (not promoted to AC). Both are process decisions. |
| 19 | Pre-commitment drop order (Goal) | info-only (not promoted to AC). It is an executable disposition, not a deliverable property. |

## Shipped-docs inventory

| Shipped document | Disposition | Ground |
|---|---|---|
| `README.md`, `README.ja.md` | this-task | **AC14**: `## Install` (`:51`), `## Update` (`:93`), the Prerequisites sandbox paragraph (`:49`) and `## Layout` |
| `docs/adopting.md`, `docs/adopting.ja.md` | this-task | **AC13**: the Codex CLI section, steps 3–9 and 11 |
| `docs/distribution.md`, `docs/distribution.ja.md` | this-task | **AC14**: install, adopt, update and the sandbox-settings imperative (`:83`) |
| `docs/usage-conversational.md`, `.ja.md` | this-task | **AC14**: the adopt line (`:103` / `:104`) |
| `docs/workflow.md`, `docs/workflow.ja.md` | this-task | **AC14**: `:29` lists trust, sandbox grants and `PATH` as setup items |
| `templates/prompt-blocks/host-dispatch.md` → `skills/run/SKILL.md` | issue #640 (the T-1164 remainder) | `:5` still tells the Codex-host orchestrator to grant `.git` write access. That is the run-time prerequisite surface T-1164 owns, and **AC12** keeps both files byte-identical here, so they change together there. |
| `templates/AGENTS.md`, `templates/test-recipe.md`, `templates/shell-team.contract.yaml` | not listed: they stay true | Each says it is scaffolded by `team-init`, which setup still calls. **AC12** locks them byte-identical. |

## Blast radius

`- verification-class: mechanism`. Merged criteria whose `check:` names an edited document, derived at run time:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*(docs/adopting|README|docs/distribution|docs/workflow|usage-conversational|check-handoff\.yml|test-recipe)' -- .shell-team/specs

Consequences, stated rather than discovered:

- **Kept green by construction.** **AC13** keeps the measured-fact literal set of T-1135's **AC9** (`.shell-team/specs/T-1135-codex-host-slice2.md`, `## Acceptance criteria`, **AC9**) and the `## ` heading counts of both adopting guides (T-1135 **AC8**). T-1149 asserts `sandbox_workspace_write` in `docs/adopting.md`, which **AC13** keeps.
- **Expected to flip.** Merged criteria that assert the grant-headed step text, the README Prerequisites paragraph, or the `distribution.md` `:83` imperative by literal (candidates by name: T-1148, T-1149, T-1150, T-1152, T-1156) can go red. Merged specs' `- check:` lines are not run locally (operator ruling, 2026-10-01: they clean up with recursive deletes, and they are frozen records that are not rewritten), so no role runs `check-acs` on the reproduce-derived set. The `reproduce:` line above is a `git grep` only; the candidates it lists are for the reviewer to read, and regressions are judged by CI and by this task's own criteria. A red caused by a dropped grant imperative is the intended effect of #640, not a regression.
- **Disclosed deviation.** No full-population two-arm inventory is run (the operator's A2 ruling). Criteria that reach these files through a suite are covered by **AC15**'s run-time-derived suite set at HEAD, not by a base arm.
- **Adopter-side artifacts.**
  - An adopter who set up by hand keeps everything. Setup adds no second exclude line (**AC4**), never rewrites scaffold files (**AC9**), and leaves any host configuration they wrote untouched (**AC1**).
  - Their generated `.codex/agents` is refreshed only when it drifts (**AC5**).
  - No adopter file is renamed or removed.

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #640 (T-1163 part): the setup prompt on both hosts | met: an operator can now set up or update a repository with one in-session prompt on either host, where before it took a runbook (12 out-of-session commands on the Codex CLI host, relayed) | met: shipped as a skill and a `bin/` script on every install, with no configuration | MINOR | A new adopter-perceivable capability on the default adoption path. The planning premise is relayed, so the coordinating session compares it at freeze. |

## Assumptions

- **Relayed (owner: the coordinating session; re-confirmation owner: step V).** The operator runs of 2026-10-01 (codex-cli 0.159.3, plugin 2.7.7):
  1. Codex CLI found the plugin's run skill from a plain-language prompt. Plugin skills are installed under `<home>/.codex/plugins/cache/<marketplace>/shell-team/<version>/`. So a prompt-triggered skill entry point exists on both hosts.
  2. The existing `skills/team-init` and `bin/team-init.sh` cover only the scaffold. This role confirmed it by reading them.
  3. The Codex baseline is 12 out-of-session operator commands for setup. No derivation command exists. The target is 0 for the plugin's part.
  4. Runbook staleness. The network-access step is stale: the review's `claude -p` ran through per-command escalation outside the sandbox, consistent with `templates/prompt-blocks/host-dispatch.md:15` (#593). The trust step is not required: the host's first-launch trust dialog sufficed, on both hosts. Whether the `PATH` export is necessary is undetermined: the operator ran it in both runs. The docs rewrite (**AC13**) states each with this status, labelled `0.159.3`.
  5. The Codex sandbox refuses creating `.codex/` and writing `.git/`, so in-session setup needs the host's per-command approval for each bounded command. **AC6** models this with unwritable paths.
  6. The review pass sends repository content to another provider, and an automatic approval reviewer denied it for lack of a specific payload and destination authorization. Here it becomes one line in `Remains the operator's decision:` (**AC8**), and setup never pre-authorizes it.
- **Relayed: the host ruling of 2026-10-01** (N0), via the coordinating session.
- **Relayed: the MINOR planning premise.** The coordinating session compares it against the derivation note at freeze.
- **Unmeasured, for the engineer to confirm:** whether `check-codex-agents.sh`'s scratch regeneration writes under `$TMPDIR`. The write set in decision 4 governs the repository and `HOME`. A scratch directory the unchanged checker creates and removes under `$TMPDIR` is outside it, and the engineer records what it actually does in provenance.
- **Measured by this role (file reads):**
  - the team-init, generator and checker contracts and the board-count grammar cited under Summarized sources;
  - the shipped skill frontmatter shape (every `skills/*/SKILL.md` carries a single `description:` line);
  - the CI workflow's single `uses:` (`:15`);
  - `.claude-plugin/plugin.json` version `2.7.7`.
- **Measurement requested at freeze (coordinating session).** The predecessor branches' code diff against `develop` leaves **AC12**'s files byte-identical: `git diff --stat "$(git merge-base develop HEAD)" HEAD -- agents bin/team-init.sh skills/team-init/SKILL.md bin/team-paths.sh bin/gen-codex-agents.sh bin/check-codex-agents.sh templates skills/run/SKILL.md` prints nothing. T-1161's implementation commit was reverted, and T-1162 was not implemented, but this role cannot run git. If it prints anything, the repair is to **AC12**'s base expression only (class-M).
- **Own-coinage count premises** (read by this role with the Grep tool in the working tree at `0c8c52d3`, clean): `team-setup`, `set up shell-team` and `update shell-team` occur **0** times repository-wide, and `tests/setup/`, `skills/setup/` and `bin/*setup*` do not exist.
- **Borrowed tokens the absence and presence criteria anchor on.** They were read by this role at `0c8c52d3`, where pre-implementation presence makes each absence check non-vacuous. The freeze run re-measures each at HEAD and records the value here.

| Token | File | Value read now |
|---|---|---|
| `## Using shell-team from Codex CLI` (whole line) | `docs/adopting.md` | **1** (`:376`) |
| `## Codex CLI から shell-team を使う` (whole line) | `docs/adopting.ja.md` | **1** (`:385`) |
| lines containing `**Grant ` in the en Codex section | `docs/adopting.md` | **3** (`:487`, `:497`, `:542`) |
| `trust を付与する` / `書き込みを許可する` / line start `許可する（T-1135）` | `docs/adopting.ja.md` | **1** / **1** / **1** (`:495`, `:505`, `:550`) |
| `## Install` / `## Update` / `## Prerequisites` (whole lines) | `README.md` | **1** / **1** / **1** (`:51`, `:93`, `:37`) |
| `## インストール` / `## 更新` (whole lines) | `README.ja.md` | **1** / **1** (`:51`, `:93`) |
| line start `**Sandbox-enabled sessions need extra settings` | `README.md` | **1** (`:49`) |
| line start `**サンドボックス有効なセッションでは` | `README.ja.md` | **1** (`:49`) |
| line start ``Add the `sandbox.excludedCommands` form to your`` / `の形を追加すると` | `docs/distribution.md` / `.ja.md` | **1** / **1** (`:83`, `:83`) |
| `the sandbox grants` / `sandbox の許可` | `docs/workflow.md` / `.ja.md` | **1** / **1** (`:29`, `:29`) |

- **Unverified environment premises**, which the freeze run confirms:
  - Under a `PATH` of `/usr/bin:/bin`, `git` resolves and neither `claude` nor `codex` does. **AC7** asserts this inline.
  - `git init` in this environment behaves as the fixtures assume.
  - The checks do not run as root. **AC6** and **AC10** refuse otherwise.

## Open questions

None blocking.

## Notes for engineer

- **Files:**
  - `bin/team-setup.sh` (mode 100755);
  - `skills/setup/SKILL.md`;
  - `tests/setup/run.sh`;
  - `.github/workflows/check-handoff.yml` (one `shellcheck` step and one suite step, following the `:31`–`:38` precedents);
  - the test recipe, resolved through `team-paths.sh`;
  - the ten shipped documents in the inventory;
  - this task's records.

  Nothing in **AC12**'s list.
- **Script shape:**
  - Resolve the plugin root symlink-safely with `pwd -P`, as `bin/team-init.sh:60`–`:70` does.
  - Call siblings as `bash "$SCRIPT_DIR/<sibling>"`, never by bare name.
  - Handle `--help` / `-h` before any git call (`tests/bin-help/run.sh`).
  - Use the die form `printf … >&2 || true; exit N` (`tests/errexit-safe/run.sh`).
  - It must run on bash 3.2.
- **Order:**
  1. Arguments.
  2. Repository root (`git rev-parse --show-toplevel`).
  3. Path-character refusal for the repository root and the plugin root.
  4. Scaffold: `team-init.sh <root>`, **never** `--force`, because `--force` overwrites the board.
  5. On the Codex CLI host only: the exclude line, appended before generation so generated files never show as untracked. Then `.codex/agents`: if present run the checker, if absent generate with `--out-dir "<root>/.codex/agents"`.
  6. Template diff (D1).
  7. Prerequisites.
  8. Report.

  Collect refused writes and print them under `RM` as `- run yourself: <command>` with single-quoted absolute paths. `bash -c` must be able to run each command as printed. Fold team-init's and the generator's output into report items or send it to stderr. Stdout is the header line plus the three sections (**AC8**'s four-line rule).
- **Do not run any git command that can write the index or other `.git` state** (`git status`, `git diff`, `git add`). `git rev-parse`, `git check-ignore` and `git ls-files` are fine. **AC1**'s listing includes `.git` minus `objects`, so an opportunistic index refresh fails it.
- **Exclude:** resolve the common directory with `git rev-parse --git-common-dir`, made absolute. Test coverage with `git check-ignore -q` on a path under `.codex/agents/`. If the file lacks a final newline, add one before the appended line.
- **Prerequisites:** use `command -v` only. Never execute `claude` or `codex` (**AC7**'s probe stubs).
- **Version:** read `"version"` from `<plugin root>/.claude-plugin/plugin.json` with `sed`, and print `unknown` when it is absent or unreadable. No stamp file is written: drift is measured from bytes, and a stamp would be one more write outside the three artifacts for no information bytes cannot give.
- **Template diff (D1):** compare `<base>/loops/shell-team.contract.yaml`, `<base>/AGENTS.md`, `<base>/.gitignore` and `<base>/binding.conf.example` against the templates `team-init.sh` copies them from (read its variables, and do not hard-code a second mapping that can drift). Never compare the board or `test-recipe.md`.
- **Forbidden tokens (AC10):** the skill and the script must describe the boundary without naming any of the fifteen tokens. For example, write "the host's own settings files" rather than a file name, and "an approval or permission-mode bypass" rather than a flag.
- **Skill:** keep it thin and mirror `skills/team-init/SKILL.md`'s shape: one `description:` frontmatter line naming both prompts, numbered steps, and "do not hand-create the artifacts". Locate `<plugin root>` as `docs/adopting.md`'s "Locate the installed plugin root" step says.
- **Docs:**
  - Lead each section with the prompt, then say what setup does on that host, then list what remains the operator's decision. Keep the manual steps as the fallback.
  - Rewrite the step 5, 6 and 8 headings so none is a grant. Keep the measured facts and setting names as descriptions of the host (**AC13**'s anchor set).
  - Label the 2026-10-01 observations `0.159.3` with their status (relayed, or undetermined for `PATH`).
  - Add no `## ` heading to either adopting guide. Keep machine tokens and the English prompts verbatim in the ja files.
- **Suite:** `tests/setup/run.sh` covers at least **AC1**–**AC9**'s cases with the `pass()` / `fail()` shape of `tests/bin-help/run.sh`, and skips the permission cases when run as root.
- **Measured-at-ref command check:** not applicable. No deliverable prints a command labelled as measured at a git ref.
- **Review depth:**
  - The script and the skill are shipped adopter code and get full depth on the write-set bound, refusal-before-write and quoting of the printed commands.
  - This spec's inline `- check:` lines are reviewed for computed values and material instrument defects, not for the adversarial completeness of their enumerations (the operator's 2026-08-22 ruling for scaffold checks, applied here to the inline lines only).
