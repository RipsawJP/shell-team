# Distribution & install

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](distribution.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](distribution.ja.md)

`shell-team` is distributed as a plugin for two hosts: **Claude Code** (v0.1.0+) and **Codex CLI**. Installing the plugin is a one-time step per machine, and it makes `bin/` helpers reachable from either host. On a Codex CLI host, the roles Codex can dispatch are the five `bin/gen-codex-agents.sh` generates by default (`tech-lead`, `pm-spec`, `engineer`, `qa-verifier`, `code-reviewer`); the roles it does not generate stay Claude Code roles. The `/shell-team:<skill>` slash-command surface is a Claude Code mechanism. What is **not** per machine: on a Codex CLI host, the custom agents for those five roles are generated **per adopted repository**, from that repository's own root — see [Using shell-team from Codex CLI](adopting.md#using-shell-team-from-codex-cli).

> Versioning: `v0.0.1` is the pre-plugin baseline (5-agent single-pass pipeline, `bin/install` snapshot copy). From `v0.1.0` the project is a plugin and Loop Engineering framework; breaking changes are allowed across the `v0.0.x → v0.1.x` boundary.

## Install

This repo is **both the plugin and its own marketplace** (manifests in `.claude-plugin/`). The marketplace name is `ripsawjp`. Installing the plugin is a one-time step per machine on whichever host you use — **Claude Code** or **Codex CLI**.

**Claude Code:**

```text
# 1) add the marketplace
/plugin marketplace add RipsawJP/shell-team

# 2) install the plugin
/plugin install shell-team@ripsawjp
```

CLI equivalents:

```bash
claude plugin marketplace add RipsawJP/shell-team
claude plugin install shell-team@ripsawjp --scope user
```

**Codex CLI:**

```
codex plugin marketplace add RipsawJP/shell-team
codex plugin add shell-team@ripsawjp
```

Then, from that repository's own root, generate the custom agents Codex dispatches — **per adopted repository**, not once per machine:

```
bash "<plugin root>/bin/gen-codex-agents.sh" --out-dir .codex/agents
```

See [Using shell-team from Codex CLI](adopting.md#using-shell-team-from-codex-cli) for repository trust, the sandbox's writable roots, the network grant and the rest of the setup this page points at rather than restates.

On **Claude Code**, the plugin's agents resolve as `/shell-team:<agent>` and skills as `/shell-team:<skill>` (e.g. `/shell-team:run`). On **Codex CLI**, a role's generated custom agent is dispatched with Codex's own `spawn_agent` tool instead — see [Using shell-team from Codex CLI](adopting.md#using-shell-team-from-codex-cli). On either host, `bin/` scripts are invoked as `bash "<plugin root>/bin/<script>"` — never assumed to be on `PATH`, even while the plugin is enabled; read `<plugin root>` from what your host reports, see [adopting.md](adopting.md)'s "Locate the installed plugin root" step for how.

## Adopt in a target repo

After install, initialize a repo's per-project data once. Everything lands under a single base dir (`.shell-team/` by default; override with `TEAM_RUN_BASE`; an existing legacy `tasks/`+`docs/specs/` layout is detected and reused): `.shell-team/{todo.md, loops/shell-team.contract.yaml, runs/, retros/, reviews/, specs/}` plus a self-contained `.shell-team/.gitignore`. The host root is left untouched — **no** `CLAUDE.md` edit and **no** root `.gitignore` change (see [adopting.md](adopting.md)):

```text
/shell-team:team-init
```

On a Codex CLI host, run the same host-neutral scaffolder directly, from the adopted repository's own root:

```text
bash "<plugin root>/bin/team-init.sh" .
```

`team-init` is idempotent — re-running skips existing files and never modifies host-root files. Only project **data** lives in the target repo, confined to the base dir (todo/specs/loops/runs/retros/reviews). The framework itself (agents/skills/scripts/templates) updates once per machine when you install a new plugin version; on a Codex CLI host, the generated custom agents in each adopted repository still need their own regeneration and drift check after that update — see `## Update` below.

## Develop / dogfood this repo

When working **inside this plugin's own repo**, load it from the working directory without installing:

```bash
claude --plugin-dir ./
```

Edit `agents/*`, `skills/*`, `bin/*`, then `/reload-plugins` to pick up changes (skill body edits are live). The repo no longer keeps a `.claude/agents/` copy — `--plugin-dir ./` is the dogfood path.

## Sandbox-enabled permission settings

When a Claude Code session runs with **sandbox enabled**, the Codex cross-provider review path (`code-reviewer`) only works if the session's settings put the Codex invocation **outside** the sandbox. Two distinct settings layers are involved and must not be conflated — see the official Claude Code permissions / sandboxing documentation:

- **`sandbox.excludedCommands`** (primary layer) — a command matching one of these patterns runs **outside** the sandbox. This is the layer that actually fixes the `sandbox_apply: Operation not permitted` failure below.
- **`permissions.allow`** (secondary, optional layer) — only suppresses the permission *prompt* for a matching Bash call. It does **not** exclude anything from the sandbox on its own, so adding `permissions.allow` rules alone does **not** fix the sandbox failure.

**The matching rule changed in Claude Code 2.1.278.** Before that release, a `sandbox.excludedCommands` pattern matched on a command line's leading token alone, so a `codex exec …` line still counted as excluded even if it ended in a shell redirection. Claude Code 2.1.278 changed this: a command is exempted only when **every part** of it matches, not just its first token (measured, dated 2026-09-24: Claude Code **2.1.281**, codex-cli **0.156.1**). Every shipped `codex exec` block in this plugin used to end in `> "<a raw jsonl path>" 2>&1`; under 2.1.278+ that redirection is a second, non-matching part, and the whole call ran **inside** the sandbox — either loudly (`workspace routing discovery failed` → `turn.failed`, exit 1, no final-message file written) or silently (exit 0, an inability sentence such as `Unable to determine.`, with `sandbox_apply` errors in the event stream). The bare form with no redirection runs outside the sandbox and completes normally, on 2.1.278+ and on every earlier version alike. Every shipped `codex exec` block is now a single bare command writing only its own `-o` capture file — no redirection, no stdin redirect, no command substitution, no connector — so the `"codex *"` exclusion matches the whole call again.

Add the `sandbox.excludedCommands` form to your `.claude/settings.local.json` so the direct-`codex` path is covered; the corresponding `permissions.allow` entry is an optional convenience that only silences the approval prompt:

```json
{
  "sandbox": {
    "excludedCommands": [
      "codex *"
    ]
  },
  "permissions": {
    "allow": [
      "Bash(codex *)"
    ]
  }
}
```

**Where the review's captured `.jsonl` now comes from.** Because the shipped `codex exec` blocks no longer redirect their own output, the `.jsonl` half of a captured pair is no longer produced by a shell redirect. `codex exec` writes its own event-stream record — a `rollout-<timestamp>-<thread_id>.jsonl` file — to its own state directory, `${CODEX_HOME:-$HOME/.codex}/sessions/<YYYY>/<MM>/<DD>/`, for every `exec` run, independently of anything this plugin does. `bin/codex-capture.sh --publish` takes one optional flag, `--thread-id <id>`, which imports that run's own rollout record into the published `.jsonl` byte-for-byte, and refuses to publish a rollout whose record does not show a completed run (no successful command, no terminal event, a null final message, or a non-null error) rather than publishing it as a verdict. `CODEX_HOME` is the Codex CLI's own home-directory override; when it is unset the search falls back to `$HOME/.codex`.

**What is verifiable here, and how.** The **form** of the fix — that every shipped `codex exec` line is a single bare command with no other part after its arguments, matching the `"codex *"` exclusion pattern by construction — is a structural fact checked mechanically by this repo's CI (`tests/codex-skeleton-hygiene/run.sh`'s `agentmd-bare-codex-present`, `agentmd-no-trailing-operator` and their mutation counterfactuals). Whether an invocation of that shape **actually runs outside the sandbox at runtime**, on Claude Code 2.1.278 and later, was confirmed by a live, sandbox-enabled probe on this host, dated 2026-09-24 (Claude Code **2.1.281**, codex-cli **0.156.1**): Codex executed its own commands, its `-o` capture was written, and none of `<sandbox_violations>`, `sandbox_apply` or `workspace routing discovery failed` appeared. The same probe, run with the pre-fix shipped tail attached, reproduced the loud failure. That probe and its rollout evidence are recorded in this repository's own provenance record for the task that made this change.

On a Codex CLI host, the mirror-image case applies to the cross-provider review's `claude -p` line (`templates/prompt-blocks/host-dispatch.md`): run it on the host side, outside the Codex sandbox, because a run inside that sandbox does not have the host's Claude session available to it, even when the host's own Claude Code CLI is logged in. `Not logged in` from that line is the signature of a sandboxed run, not of a logged-out host — but a host that is in fact logged out fails the same way outside the sandbox, so the re-run is also what tells the two apart; re-run it outside the sandbox, or, with no unsandboxed path available, report `BLOCKED` with the exact error — never substitute another executor for this review.

## Update

Bump `version` in `.claude-plugin/plugin.json`, commit, then on each machine:

**Claude Code:**

```text
/plugin marketplace update ripsawjp
```

Omitting `version` makes the plugin track the latest commit SHA instead of pinned releases.

**Codex CLI:**

```
codex plugin marketplace upgrade ripsawjp
```

Presence in `codex plugin list` is not currency: compare its `VERSION` column against the release you intend to run before treating an existing install as current. If it is older, run `codex plugin add shell-team@ripsawjp` again. Either way, re-run the generator and confirm it — per adopted repository, from that repository's own root, because the checker reads `--out-dir` and nothing else:

```
bash "<plugin root>/bin/gen-codex-agents.sh" --out-dir .codex/agents
bash "<plugin root>/bin/check-codex-agents.sh"
```

See [Using shell-team from Codex CLI](adopting.md#using-shell-team-from-codex-cli) for the full procedure and its own checks.

## Version line

**shell-team ships as a single released line.** `main` carries releases and `develop` is its integration branch; `plugin.json` advances on the ordinary `0.x.y` release schedule.

On **Claude Code**, a default `plugin marketplace add RipsawJP/shell-team` (no `#ref`) resolves the marketplace manifest from `main` HEAD, so a fresh install always gets the latest release, and `/plugin marketplace update` re-fetches that ref and compares versions.

On a **Codex CLI** host, `codex plugin list` is the equivalent read: its `VERSION` column is what to compare against the release you intend to run, and the STATUS value that actually means installed is the exact string `installed, enabled` — not mere presence in the list.

The earlier parallel-distribution arrangement — a frozen v0.2 line pinned by ref alongside v0.3 — has been retired: there is no separate maintenance line to pin to, switch between, or backport to. The `claude --plugin-dir ./` dogfood path from a checkout is unchanged.

## Host-only scheduling

The inner loop (`/shell-team:run`) and the `/goal` runtime loop are **manually triggered** by default — an operator invokes them. The Loop contract surface can also express a **time-driven** cadence via `trigger.type: schedule` (a first-class enum value alongside `manual` and `event`), but the framework ships **no scheduler** and enables nothing automatically. Scheduling is the least portable piece of the outer loop, so it is **host-only and opt-in**: you wire the clock on your host, the framework stays unchanged.

Two ways a host operator can drive a `schedule` trigger:

- **The environment's `/loop` + `ScheduleWakeup`** (preferred when your agent runtime provides them). These are **environment primitives, not repo scripts** — there is no `skills/loop/` in this plugin, so the framework cannot self-invoke them. Drive the cadence in your environment (e.g. `/loop 30m /shell-team:run …`) and set the loop's contract `trigger.type: schedule` to document the intent.
- **An OS scheduler (cron / `launchctl` / systemd timer)** calling a small host-side wrapper **you own** (not shipped here). See the illustrative, non-enabled sample at [`loop-engineering/loop-cron.crontab.example`](loop-engineering/loop-cron.crontab.example).

**`manual` is always the fallback.** The host scheduling is a thin, removable layer: delete the crontab line / LaunchAgent (or stop using `/loop`) and the loop can be run by hand exactly as before — **no behavior change inside the repo**. (Removing the host clock does not rewrite any contract file: a contract left at `trigger.type: schedule` stays valid and runnable by hand; the operator can optionally edit it back to `manual` to reflect the new intent.) Because hosts differ (cron vs launchd vs systemd vs a CI scheduler vs an agent runtime's `/loop`), this wiring is **non-portable** and is therefore documented but never bundled or auto-enabled. Whether a scheduled trigger actually fires is host-runtime behavior — it is verified by dogfooding on a real host, not by this repo's CI.

## Air-gapped / locked CI fallback (vendoring)

Where `/plugin install` is unavailable (no marketplace access on a CI runner), `bin/install` snapshot-copies the agent files into a target repo as a fallback.

This is a legacy escape hatch — prefer the plugin path.

A checkout of this repository also works as `<plugin root>` on either host — Claude Code or Codex CLI — needing no install or upgrade at all. See [Using shell-team from Codex CLI](adopting.md#using-shell-team-from-codex-cli).
