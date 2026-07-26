# Conversational usage — let the team work, no slash commands

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](usage-conversational.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](usage-conversational.ja.md)

You don't have to drive shell-team by typing `/shell-team:run …`
every time. The intended day-to-day model is the same one you already use for
cross-provider review with Codex: **you describe what you want in plain language,
and the main Claude session delegates to the team** — `pm-spec`, `engineer`,
`qa-verifier`, and the `codex-reviewer` — invoking the loop for you.

This guide shows that conversational model, how the delegation works, and the
one opt-in step that makes it reliable.

## The model

- **You chat. Claude routes.** "Add a `--json` flag to the export command" →
  Claude recognizes a non-trivial change and runs the shell-team loop (Plan →
  Specify → Implement → Validate → Review), pausing for you before merge.
- This mirrors the Codex reviewer: you don't type a slash command to get a
  cross-provider review — you ask for a review and it's delegated to the
  `codex-reviewer` agent. The dev-team agents work the same way (their
  `description` fields tell the main session when to route to them).
- Slash commands still work and are great when you want to be explicit
  (`/shell-team:run …`, `/shell-team:review`) — conversational
  routing is an addition, not a replacement.

## Setup (opt-in, one time per repo)

Conversational routing to individual agents works out of the box (it's
`description`-driven). To make the **full loop** fire reliably from plain chat —
and to encode your team's "route X to the loop" policy — copy the routing block
from [`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
into your repo's `CLAUDE.md`.

`team-init` deliberately does **not** write this for you (it never touches your
`CLAUDE.md`) — adding the routing policy to your project instructions is your
call. Without it, the main session may still delegate to individual agents, but
running the *whole* gated loop is more reliable when CLAUDE.md says to.

## Example conversations

**1. A feature → the full shell-team loop**

> **You:** Add pagination to the `/users` API endpoint — page size 50, stable
> ordering, and update the OpenAPI doc.
>
> **Claude:** This needs a spec and several files, so I'll run the team. Routing
> through tech-lead → pm-spec (acceptance criteria) → engineer → qa-verifier →
> codex-reviewer. I'll pause before any merge.
> *(runs the loop; advances the board's status flag at each gate; reports
> READY_FOR_MERGE and waits for your go.)*

**2. "Just review this" → codex-reviewer only**

> **You:** Can you get a second opinion on the diff I just pushed?
>
> **Claude:** Delegating to the cross-provider reviewer (Codex). *(invokes
> `codex-reviewer`; returns APPROVE / REQUEST_CHANGES with findings.)*

**3. Spec only → pm-spec**

> **You:** Don't build it yet — just write up the spec and acceptance criteria
> for the new billing webhook.
>
> **Claude:** Routing to pm-spec. *(writes the spec under the resolved specs dir;
> sets the task to READY_FOR_ARCH; no code.)*

**4. "What's next?" → loop-triage (read-only)**

> **You:** What should we pick up next?
>
> **Claude:** Running triage. *(invokes the `loop-triage` skill →
> `discover-work.sh`: scans failing CI, open PRs, and labelled issues, and
> *proposes* candidate board lines. It writes a proposal file and never edits the
> board — promotion is your call.)*

## How the delegation works

- **Agents** (all eight: `tech-lead`, `pm-spec`, `engineer`, `qa-verifier`,
  `codex-reviewer`, `scrum-master`, plus the conditional `ui-designer` for UI work
  and `triage-orchestrator` for outer-loop triage) are invoked by the main session based on their
  `description` frontmatter — the same proactive mechanism Codex's reviewer uses.
- **The full loop lives in the `run` skill**, not in any single agent. The
  skill is what enforces the phase gates, the loop-guard BUDGET/STOP, and the
  per-phase telemetry. So "delegate to an agent" (e.g. a one-off review) and "run
  the whole gated loop" are different: the routing snippet tells the main session
  to use the *loop* for non-trivial work, not just ad-hoc agent calls.
- **Files are the only shared state.** Agents don't share memory; the board
  (`.shell-team/todo.md`), the specs (`.shell-team/specs/`), and the loop contract are
  the source of truth. Paths are resolved by `team-paths.sh` and injected into the
  Bash-less agents by the orchestrator.

> Note for the orchestrator: environment variables do **not** persist across
> separate Bash tool calls. When a step needs a resolved path, get it in that same
> call with `$(team-paths.sh --get KEY)` — don't rely on a previously exported
> `$TEAM_*`. (The bin scripts self-resolve, so this is mostly handled for you.)

## When to still use slash commands

- You want to be explicit / scripted: `/shell-team:run <request>`.
- A quick review without the full pipeline: `/shell-team:review`.
- Adopting the loop in a new repo: `/shell-team:team-init`.

Conversational routing and explicit slash commands compose freely — use whichever
fits the moment.
