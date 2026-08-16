# Tasks

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`

## Active

- [ ] **T-200** last-section task one — `READY_FOR_ENG` — spec: docs/specs/last-one.md
  - engineer: `## Active` is the LAST section in this file — nothing follows it,
    so the section never closes via a later `## ` heading and the extraction
    must read all the way to EOF to see this line at all.
- [ ] **T-201** last-section task two — `READY_FOR_QA` — spec: docs/specs/last-two.md
