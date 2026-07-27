# AGENTS.md — cross-tool entry point to this repo's working state

This file is a **portable pointer/mirror** for any tool or agent (Claude, the
Codex reviewer, or another assistant) that needs to know *where this repo keeps
its working state*. It is scaffolded by the **shell-team** plugin's
`team-init` under the resolved base dir (`<base>/AGENTS.md`).

It is **not** a source of truth and **not** a changelog. It does not record task
progress, completion history, or dated notes. The actual state lives in the
files this doc points at; read those for current truth. This file only tells you
which files to read.

> Note on placement: this file sits under the team's base dir
> (`<base>/AGENTS.md`), **not** at the repo root. Root-convention auto-pickup by
> other tools therefore does **not** apply — treat this purely as a pointer doc,
> not an auto-detected convention file.

## Where to look (truth sources — agents do not share memory)

All operating paths are resolved by `bin/team-paths.sh` (the **shell-team**
plugin's resolver, not a repo-local script) against a single base dir
(`.shell-team/` by default; a legacy `tasks/` + `docs/specs/` layout is detected
and reused). Wherever this doc writes `<base>/`, substitute the base the
resolver reports for this repo.

- **Task board + hand-off contract** — `<base>/todo.md`. This is the single
  source of truth for work state. Each task carries a status flag that advances
  through the loop's phase gates:

  `READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`

  (or `BLOCKED` / `REWORK` at any stage). Do not advance a phase until the
  previous phase's flag is set in the board.

- **Specs + acceptance criteria** — `<base>/specs/` (or `docs/specs/` in a
  legacy layout). One spec per task; acceptance criteria are the contract.

- **Current position / session hand-off** — the `project_status` doc (a
  git-tracked "where we are now" snapshot kept for picking up across sessions
  and machines). Read this first to re-establish context; it is a mirror of
  current state, not a log.

- **Auto-memory index (`MEMORY.md`)** — a tool's local auto-memory index is
  **per-device and not synced** across machines. Do not treat it as portable
  truth. The portable source of truth is always the repo-tracked files above
  (board, specs, `project_status`); regenerate context from those.

## Review is cross-provider (Codex)

Review runs on a **different model provider (Codex) on purpose**, to catch
same-model bias. A task is done only when both the QA pass (`READY_FOR_REVIEW`)
and the cross-provider Codex review (`READY_FOR_MERGE`) clear. Keep the Codex
reviewer in the loop — it is not optional.

## What this file does NOT do

- It does not replace `<base>/todo.md`, the specs, or `project_status` — it
  points at them.
- It does not carry progress logs, completion history, or dated entries.
- It does not get auto-picked-up as a root convention file (see the placement
  note above).
