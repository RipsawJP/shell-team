# Tasks

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`

## Planned

- some prose describing planned work, not a `## Active` section at all.
  - an indented continuation line that must never be reported: there is no
    `## Active` heading anywhere in this file, so the whole-file awk pass
    must still traverse every line to EOF (T-1070's early-exit invariant:
    "a file with no `## Active` heading must still be traversed to the end
    and still emit nothing") and this fixture must lint clean.

## Done

<!-- - [x] T-098 archived task -->
