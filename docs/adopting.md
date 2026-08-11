# Adopting shell-team in your repository

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](adopting.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](adopting.ja.md)

This repo can run the **shell-team** plugin — a PM → Engineer → QA →
Codex-Reviewer pipeline driven by spec-first, file-based hand-offs. The plugin
lives centrally (installed once); each adopting repo only holds the per-repo
*instances* scaffolded by `team-init`.

## Where the operating files live

`team-init` scaffolds everything under a **single base directory**, so the
plugin's footprint never scatters across your mainline tree. By default that base
is `.shell-team/`; override it with the `TEAM_RUN_BASE` environment variable. A repo
that already uses the legacy `tasks/` + `docs/specs/` layout is detected and reused
(the resolver `bin/team-paths.sh` decides which layout is in effect).

```
<base>/                          # .shell-team/ by default
├── todo.md                      # the task board / hand-off contract (status flags)
├── loops/
│   └── shell-team.contract.yaml   # the loop's TRIGGER/SCOPE/ACTION/BUDGET/STOP contract
├── specs/                       # the spec + acceptance criteria for each task
├── runs/                        # per-run telemetry (git-ignored via <base>/.gitignore)
├── retros/                      # retrospectives
├── reviews/                     # cross-provider review artifacts
├── AGENTS.md                    # cross-tool pointer doc (see below) — not a source of truth
├── test-recipe.md               # per-repo test-run recipe (engineer/QA read first, append
│                                #   established procedures; never overwritten, even with --force)
├── binding.conf.example         # inert executor-binding specimen; rename to binding.conf to opt in
└── .gitignore                   # self-contained; ignores runs/ telemetry
```

**Your host root is left untouched.** `team-init` does not edit your `CLAUDE.md`
and does not append to your root `.gitignore`. Telemetry is ignored via the
self-contained `<base>/.gitignore`. Whether to also git-ignore the whole base
dir — and whether to copy the operating rules below into your own `CLAUDE.md` —
is your call; the plugin will not make those edits for you.

If you keep the base dir out of git, the two ways of doing that differ in scope.
A `.shell-team/` line in the repo's own `.gitignore` applies to that repo and is
trivially reversed. Putting it in your global excludes (`git config --global
core.excludesFile`) hides the base dir in *every* repo on the machine —
including one where you later decide the board should be tracked, and there the
symptom is indirect: the board simply never appears in `git status`. To
re-include it in a single repo, add `!.shell-team/` to that repo's root
`.gitignore`; repo-level patterns outrank the global file. This repository
carries that line for exactly that reason, so its own base dir stays tracked
even for an operator who ignores `.shell-team/` globally.

That global file has a second consequence. Anything that asks git whether a
path is ignored — `git check-ignore`, and checks built on it — reads it too, so
such a check can fail on your machine while passing in CI, where no global
excludes exist. Pin it explicitly (`git -c core.excludesFile=/dev/null …`) in
any assertion about ignore behavior rather than inheriting whatever the operator
has configured.

How often the session stops to check with you is your call too, and it is set
per-checkout rather than shipped: see
[tuning-oversight.md](tuning-oversight.md).

## `AGENTS.md` — a cross-tool pointer doc

`team-init` also scaffolds **`<base>/AGENTS.md`**: a portable doc that tells any
tool or agent (Claude, the Codex reviewer, or another assistant) *where this
repo keeps its working state* — the task board and status-flag chain, the specs,
the `project_status` snapshot, the per-device MEMORY.md index caveat, and the
fact that review is cross-provider (Codex).

It is a **pointer/mirror, not a source of truth**. It carries no progress log,
completion history, or dated entries; the actual state stays in `<base>/todo.md`,
the specs, and `project_status`. Read those for current truth — `AGENTS.md` only
tells you which files to read.

**Placement and trade-off.** It lives under the base dir (`<base>/AGENTS.md`),
**not** at your repo root — because `team-init` never touches the host root.
The consequence: tools that auto-detect a *root* `AGENTS.md` convention will
**not** auto-pick-up this one. That is a deliberate trade-off — we keep the
host-root-untouched guarantee and treat `AGENTS.md` purely as a portable pointer
doc rather than an auto-loaded root convention file. If you want a tool to read
it, point that tool at `<base>/AGENTS.md` explicitly.

## How to run

```
/shell-team:run <what you want built>
```

The loop runs Plan → Specify → Implement → Validate → Review, advancing a status
flag in the board (`<base>/todo.md`) at each phase gate, and pauses for a human
before merge/push.

## Binding roles to executors

`team-init` scaffolds an inert `<base>/binding.conf.example`
(`<base>` resolves via `bin/team-paths.sh --get base`) — a copy of
`templates/binding-template.conf`. Author a `<base>/binding.conf` when you
want to assign a specific executor to one or more of the six inner-loop
roles (`tech-lead`, `pm-spec`, `engineer`, `qa-verifier`, `codex-reviewer`,
`ui-designer`):

1. `mv <base>/binding.conf.example <base>/binding.conf` — or, if
   `team-init` has not run yet, copy `templates/binding-template.conf` to
   `<base>/binding.conf` by hand.
2. Edit its `bind <role> <provider> <model> <effort|-> <adapter>` rows —
   one per role.
3. `bash bin/check-binding.sh --config <base>/binding.conf`
4. `bash bin/resolve-executor.sh --print-resolved`

A config the real validator accepts:

```
schema 1

bind tech-lead      claude opus   high claude-cli
bind pm-spec        claude opus   high claude-cli
bind engineer       claude sonnet -    claude-cli
bind qa-verifier    claude sonnet -    claude-cli
bind ui-designer    claude sonnet -    claude-cli
bind codex-reviewer codex  gpt-5  -    codex-cli
```

With no host `<base>/binding.conf` at all — the ordinary, unconfigured
case — `resolve-executor.sh` falls back to the plugin-shipped default,
`templates/binding-default.conf`; its `model` column carries
`provider-configured` only for `codex-reviewer`, naming the boundary that
the shipped Codex invocation passes no model flag at all, while every
other role's column carries its own `agents/<role>.md` pin.

An adopter edit can reach four fail-closed refusals from
`resolve-executor.sh`:

- `binding-unresolved` (exit code `2`) — an occupant at
  `<base>/binding.conf` that is not a regular file (a directory, a FIFO, a
  dangling symlink); never silently substituted with the shipped default,
  which is reserved for true absence.
- `capability-unsupported` (exit code `1`) — a role requests an effort
  value its bound adapter does not declare.
- `contract-violation` (exit code `1`) — a role with write or propose
  board authority is bound to an adapter that does not carry a
  board-transition channel.
- `executor-unavailable` (exit code `1`) — the bound executor is not
  reachable — for example, the `Codex` CLI is missing from `PATH` or fails
  its read-only probe.

Each adapter declares its own effort vocabulary; there is no shared list:
`claude-cli` accepts `low`, `medium`, `high`, `xhigh`, `max`; `codex-cli`
accepts `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`.

**The honest boundary**: rebinding a role changes which executor
`resolve-executor.sh` **resolves** and which value **telemetry** records
for it. It does **not** wire an alternate-executor **invocation path** — a
role's actual invocation still routes through that role's own pinned model
value. The retirement that would change that is issue **#236**.

## Conversational usage (no slash commands)

You can also just describe what you want in plain language and let the main Claude
session delegate to the team (the way you already get a Codex review without
typing a slash command). See [usage-conversational.md](usage-conversational.md) for
the model and example conversations. To make the full loop fire reliably from
chat, copy the opt-in routing block from
[`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
into your repo's `CLAUDE.md` — `team-init` does not add it for you (it never
touches your `CLAUDE.md`); whether to adopt the routing policy is your call.

## Operating rules

- Do not advance a phase until the previous phase's status flag is set in the board.
- A task is done only when the Codex reviewer sets `READY_FOR_MERGE` — which requires QA to have passed first (`READY_FOR_REVIEW`); both the QA pass and the cross-provider review must clear.
- The reviewer runs on a different model provider (Codex) on purpose — keep it in the loop.
- Files are the only shared state between agents (they do not share memory): the
  board (`<base>/todo.md`), the specs (`<base>/specs/`), and the loop contract are
  the single source of truth.
