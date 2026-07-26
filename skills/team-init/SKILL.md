---
description: Scaffold the current repository to adopt the shell-team loop (todo board, loop contract, runs/retros/reviews/specs dirs) under a single base dir — host root files (CLAUDE.md, .gitignore) are left untouched
---

You are initializing the **current repository** (the cwd) so it can run the
`shell-team` pipeline. The plugin lives centrally; this step drops
the per-repo *instances* the pipeline needs into this repo.

Do this:

1. **Run the scaffolder against the current repo.** It is idempotent — safe to
   re-run; it skips files that already exist and never overwrites unless asked.

   ```
   team-init.sh .
   ```

   (Add `--force` only if the user explicitly wants existing scaffold files
   overwritten.) The script is on PATH when the plugin is loaded; otherwise call
   it by its repo path `bin/team-init.sh`.

2. **Report what it did.** Echo the `created:` / `updated:` / `skipped` lines and
   the closing summary so the user sees exactly which files were scaffolded vs.
   left untouched. Everything lands under a **single base dir** (default
   `.shell-team/`; a legacy `tasks/` layout is detected and reused; `$TEAM_RUN_BASE`
   overrides). The scaffold produces, under `<base>/`:
   - `todo.md` — the task board (status-flag hand-off contract)
   - `loops/shell-team.contract.yaml` — the loop's BUDGET/STOP contract
   - `runs/.gitkeep`, `retros/.gitkeep`, `reviews/.gitkeep`, `specs/.gitkeep`
   - `AGENTS.md` — cross-tool pointer/mirror to the truth sources (board, specs, project_status, Codex review)
   - `test-recipe.md` — per-repo test-run recipe (engineer/QA read it first, append established procedures; protected — never overwritten, even with `--force`)
   - `.gitignore` — self-contained, ignores `runs/` telemetry

   In a **legacy** `tasks/` layout the specs dir is the one exception — it stays
   at `docs/specs/` (the historical split-root quirk), not under `<base>/`. The
   scaffolder's summary calls this out when it applies.

   The host root is deliberately left untouched: **no** CLAUDE.md edit and **no**
   host-root `.gitignore` change.

3. **Surface the adoption rules.** The operating rules are NOT injected into the
   host's CLAUDE.md. Point the user to `docs/adopting.md` (shipped with the
   plugin) for the shell-team operating contract, and tell them where their files
   landed (the base dir from the summary). If they want the shell-team rules in
   their own CLAUDE.md, they can copy from `docs/adopting.md` — that choice is
   theirs, not the scaffolder's.

4. **Point to the next step.** Tell the user they can now run:

   ```
   /shell-team:run <what you want built>
   ```

   Note: the telemetry dir (`<base>/runs/`) is git-ignored via `<base>/.gitignore`;
   whether to also `.gitignore` the whole base dir at the host root is the user's
   call.

5. **Idempotency note.** If the scaffolder reported skips, explain that those
   files already existed and were left untouched — re-running `team-init` is safe
   and never modifies host-root files.

Do not hand-create or edit the scaffold files yourself — the script is the single
deterministic source of the scaffold so its behavior stays covered by
`tests/team-init/` and CI.
