# Tasks

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`

## Active

- [ ] **T-210** eof-section task — `READY_FOR_ENG` — spec: docs/specs/eof-one.md
  - engineer: a normal continuation line, still inside this entry.

A free top-level prose line — a boundary, not a task line — that closes the
entry above without opening one of its own.

  a stranded continuation line that is the very last content in the file,
  with no closing `## ` heading anywhere after it — EOF arrives mid-section
  and this violation must still be reported at its own line number.
