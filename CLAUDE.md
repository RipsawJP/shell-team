# shell-team — working on this repo

shell-team is a Claude Code plugin that runs a spec-driven agent team: Tech Lead
plans, PM writes the spec, Engineer implements, QA verifies against acceptance
criteria, and a Codex-backed reviewer gives a cross-provider second opinion.

This file is the operating contract for working *on* the plugin. Adopter-facing
documentation lives in `README.md` and `docs/`; this file points at it rather
than restating it.

## Truth sources

Read the file — do not reconstruct these from conversation:

| What | Where |
|---|---|
| Role list, responsibilities, tool permissions | `agents/*.md` frontmatter (`name` / `description` / `tools`) |
| Phase flow, layout, versioning, dogfood setup | `README.md` |
| Contribution rules and review expectations | `CONTRIBUTING.md` |
| Vulnerability reporting | `SECURITY.md` |
| The task board and its status flags | `.shell-team/todo.md` — this repo runs on the shipped default layout, so resolve paths with `bin/team-paths.sh --get todo\|specs\|reviews` rather than assuming either layout |
| How to run this repo's tests | `.shell-team/test-recipe.md` — read it before running suites, and append procedures you establish |

The role table is deliberately **not** duplicated here. A second copy drifts
from the frontmatter that actually configures the agents, and the copy is the
one people read.

## Routing

The block below is `templates/CLAUDE-routing-snippet.md`, verbatim. That file is
what this project tells an adopting repo to paste into its own `CLAUDE.md`, so
this repo runs on the same text it ships rather than on a paraphrase of it.

<!-- shell-team:routing:begin -->
## AI dev team — conversational routing (shell-team)

This repo uses the **shell-team** plugin. When you (the main Claude session)
work here, route work to the team instead of doing everything inline — the user
should be able to ask in plain language without typing slash commands.

- **Non-trivial code change** — a feature, a multi-file change, anything that
  warrants a spec or acceptance criteria → run the full loop via the `run`
  skill (equivalent to `/shell-team:run <the request>`). Do **not**
  implement it directly in the main session.
- **"Review this" / a second opinion on a diff / PR** → delegate to the
  `codex-reviewer` agent (cross-provider review on a different model family).
- **"Write the spec" / "clarify the requirements" only** → delegate to `pm-spec`.
- **"What should we pick up next?" / triage failing CI, open PRs, labelled issues**
  → run the `loop-triage` skill (read-only — it *proposes* candidates, never edits
  the board).
- **"Run a retro" / "summarize what we learned this cycle" / a request to reflect
  on a development cycle's learnings** → delegate to the `scrum-master` agent.
  This trigger is **manual only** — the loop never invokes it automatically.
- **Trivial fix** (typo, one-liner, obvious bugfix) → just do it; no loop needed.

The loop advances a status flag in the board (`.shell-team/todo.md` by default; the
resolver `team-paths.sh` decides the base dir) at each phase gate, and pauses for a
human before merge/push. A task is done only when the Codex reviewer sets
`READY_FOR_MERGE` — which requires QA to have passed first (`READY_FOR_REVIEW`);
both the QA pass and the cross-provider review must clear.
<!-- shell-team:routing:end -->

## When to stop and ask

The routing block above pauses before merge. These are the other points where
work stops and waits, so that the gates are a property of this repository rather
than of one maintainer's personal configuration.

- **Before a change that spans more than one file**, state the change set first —
  which files, which base branch, whether it is additive or destructive, and the
  issue it serves — and wait for agreement. Do not begin editing while that
  proposal is unanswered.
- **Before implementing a feature**, agree the issue and the branch name. Do not
  create a branch and start work off the back of a conversation alone.
- **Outward-facing actions need agreement first** — pushing, opening or merging a
  pull request, filing an issue, deleting a remote branch. This repository is
  public: those actions are visible immediately and are not cleanly reversible.
- **A destructive or irreversible step must verify its own safety net.** When the
  step is only safe because something was preserved first (a copy, a commit, a
  stash), check mechanically that the preservation actually succeeded before
  destroying anything. If it did not, stop and ask rather than proceeding on the
  assumption that a copy exists somewhere.
- **If you asked a question, wait for the answer.** Do not ask and then act in the
  same turn, and do not treat an unrelated message as consent.

These are instructions, not enforcement: Claude Code treats a `CLAUDE.md` as
context rather than as configuration it must obey. Anything that has to hold
regardless belongs in CI — as `bin/check-pii-shapes.sh` and
`bin/check-commit-identity.sh` do — or in a hook, which this repository
deliberately does not ship (a hook is executable configuration, and a public
repository is the wrong place to make one arrive by default).

## Working rules

- **Git-tracked files are the only shared state.** Sub-agents do not share a
  context window; everything that has to survive a hand-off passes between them
  through files in the repo.
- **Keep `tools:` minimal** in every agent's frontmatter. Widening a role's tool
  access needs a stated reason in the pull request.
- **The reviewer stays cross-provider.** `codex-reviewer` shells out to the
  Codex CLI on purpose: a model reviewing output from its own family shares its
  blind spots. Do not substitute a Claude reviewer, and do not make the review
  step optional — if the Codex CLI is unavailable, that is a blocker, not a
  degraded mode.
- **Done means both gates are green** — QA reaching `READY_FOR_REVIEW` *and* the
  cross-provider review reaching `READY_FOR_MERGE`. One green gate is not done.
- **`bin/` stays pure bash, zero-dependency, and shellcheck-clean.** CI lints
  every script. A new runtime dependency breaks portability for adopters, who
  run these scripts in repos we know nothing about.
- **Resolve operating paths through `bin/team-paths.sh`; never hardcode them.**
  The base directory is configurable and two layouts are supported, so a
  hardcoded path is correct in at most one of them.
- **Checkers must fail closed.** A check that cannot evaluate its input reports
  an error; it never silently passes. Suppressing a non-zero exit status to keep
  output tidy converts a real failure into a false pass.

## Dogfood

Load the plugin from a checkout:

```bash
claude --plugin-dir ./     # then /reload-plugins after editing agents, skills or bin
```

With the plugin loaded, `bin/` is on `PATH`. Call scripts by bare name
(`check-handoff.sh …`) rather than `bash bin/…`, so what you exercise matches
what adopters run.

## Branches and pull requests

- Branch from `develop`. `main` is the release line.
- Both branches require the `check-handoff lint` check and reject force pushes
  and deletion.
- Run the relevant `tests/*/run.sh` suites locally before pushing. CI runs all of
  them and is the merge gate.

## Security invariant

A `CLAUDE.md` is a trusted instruction channel: whatever it says is treated as
operator configuration rather than as untrusted input. Two consequences here.

- **No AI runs in this repo's CI.** The only workflow is
  `.github/workflows/check-handoff.yml`, and its only action is
  `actions/checkout`. Re-derive this invariant before adding any AI-driven
  workflow: `anthropics/claude-code-action` restores config paths — including
  this file — from the base branch before the model runs, whereas
  `claude-code-base-action` does not.
- **Read changes to this file yourself before checking a contributor's branch
  out locally.** The interactive CLI trusts its working directory and does not
  re-verify trust when you switch branches, so a modified `CLAUDE.md` on a
  fetched branch takes effect the moment you start a session in it.

Keep every `@`-prefixed token inside backticks or a fenced block. Outside them,
`@path` is import syntax and pulls the file into context. An import that
resolves outside the repository additionally prompts every contributor for
approval, so this file uses in-repo references only.

## Language

Files that only an agent reads — this one, `agents/*.md`, `skills/*`, and the
generated prompt blocks — are written in English with no translated counterpart.
Human-facing documentation (`README.md`, `docs/`) may additionally carry a
`*.ja.md` version. The test is who reads the file rather than personal
preference: a second copy of an agent-facing file doubles the maintenance
surface without adding a reader, and the stale copy is the one that misleads.

Some agent definitions still carry Japanese prose inherited from the lessons
corpus their prompt blocks are generated from. That is a known inconsistency,
not a precedent for new files.

## Hygiene

This is a public repository. Do not add private context: internal task or issue
references, employer-specific names or addresses, session transcripts, or audit
output carrying real values. Machine tokens (`READY_FOR_QA`, `PASS`, `APPROVE`)
stay in English verbatim wherever they appear.
