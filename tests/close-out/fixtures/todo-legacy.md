# Tasks

This is the team's shared task board. The PM creates entries, every agent updates the status flag for tasks they touch.

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`
(or `BLOCKED` / `REWORK`)

## Active

- [ ] **T-100** クローズ対象のサンプルタスク（fixture） — `READY_FOR_REVIEW` — spec: docs/specs/t-100.md
  - existing engineering note
- [ ] **T-101** 残留するサンプルタスク（fixture） — `READY_FOR_ARCH` — spec: docs/specs/t-101.md

## Done

- [x] T-099 既存の完了済タスク（fixture） — `READY_FOR_MERGE` (2026-06-01, #1 → develop) — spec: docs/specs/t-099.md

## Format

```markdown
- [ ] **T-XXX** <one-line title> — `<STATUS_FLAG>` — spec: docs/specs/<slug>.md
```
