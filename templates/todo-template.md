# Tasks

This is the team's shared task board. The PM creates entries; every agent updates the
status flag for the tasks it touches. This file is the single source of truth for work
state — the `/shell-team:run` loop advances the flag at each phase gate.

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`
(or `BLOCKED` / `REWORK` at any stage)

## Active

_(none)_

## Done

_(none)_

## Format

```markdown
- [ ] **T-XXX** <one-line title> — `<STATUS_FLAG>` — spec: <specs-dir>/<slug>.md
  - <optional latest note from whichever agent touched it last>
```

`<specs-dir>` is `.shell-team/specs/` by default (or `docs/specs/` in a legacy
`tasks/` layout). The hand-off linter accepts any spec path ending in `.md`.

A task entry runs from its top-level line to the next non-indented non-blank line,
the next `##` heading, or the end of the file:
blank lines and indented lines of any shape belong to the entry.
Consequently, an indented line with no task entry above it in the section is an error,
and the hand-off linter reports it.
