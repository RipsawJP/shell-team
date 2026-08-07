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

`team-init` does not check this for you. Whether the base dir is ignored is a
question about your repository rather than about the plugin, so what the plugin
ships is the question rather than an answer to it. Run it yourself, once, from
the repo root after adopting:

    git check-ignore -v -- "./$(team-paths.sh --get base)/"

If `team-paths.sh` is not on your `PATH`, write the base dir's own name in
place of the substitution: `.shell-team` by default, `tasks` on the legacy
layout, or whatever you set `TEAM_RUN_BASE` to. Three answers are possible.
It prints a line naming a file, a line number and the pattern that matched —
the base dir is ignored, and that line is the rule to change. It prints
nothing at all — the base dir is not ignored, and there is nothing to do; note
that this is also what a re-include looks like, because for a directory query
git reports no matching pattern once a negated rule such as `!.shell-team/`
has won, rather than printing that rule. Or it fails with a `fatal:` message —
git could not answer the question at all, because there is no repository here,
or it is a bare repository, or git cannot read it, and in that case nothing was
determined either way.

If the base dir turns out to be ignored and that was not deliberate, re-include
it before the loop writes its first record. A record the loop newly creates
under an ignored dir is an untracked ignored file, so an ordinary `git add`
will not stage it, and the loop's commit steps can then report success having
committed nothing. A file already tracked under that dir is unaffected,
because a gitignore rule does not apply to tracked paths. If it was
deliberate, this is not an error: an ignored base dir is a supported
configuration, per the above.

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
