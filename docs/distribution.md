# Distribution & install

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](distribution.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](distribution.ja.md)

`shell-team` is distributed as a **Claude Code plugin** (v0.1.0+). One install per machine makes the team's sub-agents, skills, and `bin/` helpers available in **every** repo — no per-repo copying.

> Versioning: `v0.0.1` is the pre-plugin baseline (5-agent single-pass pipeline, `bin/install` snapshot copy). From `v0.1.0` the project is a plugin and Loop Engineering framework; breaking changes are allowed across the `v0.0.x → v0.1.x` boundary.

## Install

This repo is **both the plugin and its own marketplace** (manifests in `.claude-plugin/`). The marketplace name is `ripsawjp`.

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

The plugin's agents resolve as `/shell-team:<agent>`, skills as `/shell-team:<skill>` (e.g. `/shell-team:run`), and `bin/` scripts are added to `PATH` while the plugin is enabled.

## Adopt in a target repo

After install, initialize a repo's per-project data once. Everything lands under a single base dir (`.shell-team/` by default; override with `TEAM_RUN_BASE`; an existing legacy `tasks/`+`docs/specs/` layout is detected and reused): `.shell-team/{todo.md, loops/shell-team.contract.yaml, runs/, retros/, reviews/, specs/}` plus a self-contained `.shell-team/.gitignore`. The host root is left untouched — **no** `CLAUDE.md` edit and **no** root `.gitignore` change (see [adopting.md](adopting.md)):

```text
/shell-team:team-init
```

`team-init` is idempotent — re-running skips existing files and never modifies host-root files. Only project **data** lives in the target repo, confined to the base dir (todo/specs/loops/runs/retros/reviews). The framework itself (agents/skills/scripts/templates) stays in the plugin — update once, every repo benefits.

## Develop / dogfood this repo

When working **inside this plugin's own repo**, load it from the working directory without installing:

```bash
claude --plugin-dir ./
```

Edit `agents/*`, `skills/*`, `bin/*`, then `/reload-plugins` to pick up changes (skill body edits are live). The repo no longer keeps a `.claude/agents/` copy — `--plugin-dir ./` is the dogfood path.

## Sandbox-enabled permission settings

When a Claude Code session runs with **sandbox enabled**, the Codex cross-provider review path (`codex-reviewer`) only works if the session's settings put the Codex invocation **outside** the sandbox. Two distinct settings layers are involved and must not be conflated — see the official Claude Code permissions / sandboxing documentation:

- **`sandbox.excludedCommands`** (primary layer) — a command matching one of these patterns runs **outside** the sandbox. This is the layer that actually fixes the `sandbox_apply: Operation not permitted` failure below.
- **`permissions.allow`** (secondary, optional layer) — only suppresses the permission *prompt* for a matching Bash call. It does **not** exclude anything from the sandbox on its own, so adding `permissions.allow` rules alone does **not** fix the sandbox failure.

A direct `codex exec …` invocation has been observed working in this environment (main 3/3, sub-agent 5/5), but that success is attributable to the operator's **pre-existing global `sandbox.excludedCommands` `codex` patterns** already present in their `~/.claude/settings.json` — it is not a fresh test of the rules documented here. In earlier versions, `bin/codex-capture.sh` invoked codex itself, wrapped inside a `bash bin/…` invocation that matched **none** of those exclusion patterns — it ran **inside** the sandbox, could not nest a seatbelt, and Codex's tool execution died with `sandbox_apply: Operation not permitted` (exit 71 — `BLOCKED-TOOLING`). **The wrapper no longer invokes codex at all** — it only allocates, validates, and atomically publishes the two raw capture files (`--alloc` / `--publish`); the caller (`codex-reviewer` / `drift-evaluator`) now runs `codex exec …` itself, directly, as a bare first-token command line. Because a sandbox exclusion pattern matches on a command line's first token, this is a structural fix, not a configuration workaround: the invocation that needs to run outside the sandbox is the same `codex exec …` line an exclusion already matches, with no wrapper token in front of it to defeat the match.

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

The `"codex *"` exclusion is observed-working as described above, via the operator's pre-existing global config — not a fresh test of this exact snippet. Earlier revisions of this doc also listed the two wrapper exclusion entries (and their `permissions.allow` counterparts) as a prediction/unconfirmed workaround for the wrapper matching no exclusion pattern. **These entries are not harmless if left in place**: `sandbox.excludedCommands` matches on a command line's first token regardless of what that command does internally (see the "primary layer" bullet above), so if you already added the two wrapper entries from an earlier revision of this doc, they still grant `bin/codex-capture.sh` an unconditional standing exemption from the sandbox — a live, repo-internal-script sandbox exclusion, the exact posture this task's Non-goals rejected as an unsuitable design (broadening sandbox exemptions to repo scripts). Now that the wrapper never executes codex, that exemption serves no purpose, and removing the two wrapper entries is recommended.

**What is and is not verifiable here.** The **form** of the fix — that the caller's codex invocation is a bare, first-token `codex exec …` line, matching the `"codex *"` exclusion pattern by construction — is a structural fact checked mechanically by this repo's CI (`tests/codex-skeleton-hygiene/run.sh`'s `agentmd-bare-codex-present` case and its mutation counterfactual). Whether that invocation **actually runs outside the sandbox at runtime** is not verifiable in CI, nor by this repo's QA subagent pass — a test runner without an active seatbelt shows no observable difference either way. Treat that runtime effect as `environmentally-unverified`: something only the operator's own in-session, sandbox-enabled Claude Code run can confirm, the same way the main-3/3/sub-agent-5/5 observation above was obtained.

## Update

Bump `version` in `.claude-plugin/plugin.json`, commit, then on each machine:

```text
/plugin marketplace update ripsawjp
```

Omitting `version` makes the plugin track the latest commit SHA instead of pinned releases.

## Version line

**shell-team ships as a single released line.** `main` carries releases and `develop` is its integration branch; `plugin.json` advances on the ordinary `0.x.y` release schedule. A default `plugin marketplace add RipsawJP/shell-team` (no `#ref`) resolves the marketplace manifest from `main` HEAD, so a fresh install always gets the latest release, and `/plugin marketplace update` re-fetches that ref and compares versions. The earlier parallel-distribution arrangement — a frozen v0.2 line pinned by ref alongside v0.3 — has been retired: there is no separate maintenance line to pin to, switch between, or backport to. The `claude --plugin-dir ./` dogfood path from a checkout is unchanged.

## Host-only scheduling

The inner loop (`/shell-team:run`) and the `/goal` runtime loop are **manually triggered** by default — an operator invokes them. The Loop contract surface can also express a **time-driven** cadence via `trigger.type: schedule` (a first-class enum value alongside `manual` and `event`), but the framework ships **no scheduler** and enables nothing automatically. Scheduling is the least portable piece of the outer loop, so it is **host-only and opt-in**: you wire the clock on your host, the framework stays unchanged.

Two ways a host operator can drive a `schedule` trigger:

- **The environment's `/loop` + `ScheduleWakeup`** (preferred when your agent runtime provides them). These are **environment primitives, not repo scripts** — there is no `skills/loop/` in this plugin, so the framework cannot self-invoke them. Drive the cadence in your environment (e.g. `/loop 30m /shell-team:run …`) and set the loop's contract `trigger.type: schedule` to document the intent.
- **An OS scheduler (cron / `launchctl` / systemd timer)** calling a small host-side wrapper **you own** (not shipped here). See the illustrative, non-enabled sample at [`loop-engineering/loop-cron.crontab.example`](loop-engineering/loop-cron.crontab.example).

**`manual` is always the fallback.** The host scheduling is a thin, removable layer: delete the crontab line / LaunchAgent (or stop using `/loop`) and the loop can be run by hand exactly as before — **no behavior change inside the repo**. (Removing the host clock does not rewrite any contract file: a contract left at `trigger.type: schedule` stays valid and runnable by hand; the operator can optionally edit it back to `manual` to reflect the new intent.) Because hosts differ (cron vs launchd vs systemd vs a CI scheduler vs an agent runtime's `/loop`), this wiring is **non-portable** and is therefore documented but never bundled or auto-enabled. Whether a scheduled trigger actually fires is host-runtime behavior — it is verified by dogfooding on a real host, not by this repo's CI.

## Air-gapped / locked CI fallback (vendoring)

Where `/plugin install` is unavailable (no marketplace access on a CI runner), `bin/install` snapshot-copies the agent files into a target repo as a fallback. This is a legacy escape hatch — prefer the plugin path.
