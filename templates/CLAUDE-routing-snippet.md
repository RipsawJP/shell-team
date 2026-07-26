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
