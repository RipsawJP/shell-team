# Tasks

This is the team's shared task board. The PM creates entries; every agent updates the
status flag for the tasks it touches. This file is the single source of truth for work
state — the `/shell-team:run` loop advances the flag at each phase gate.

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`
(or `BLOCKED` / `REWORK` at any stage)

## Active

- [ ] **T-111** Diff-scoped PII shape checker with a vacuity-guarded fixture suite — `BLOCKED` — spec: .shell-team/specs/T-111-pii-shape-checker.md
  - source: GitHub issue #6, Layer 2 items 4 and 5 plus the user instruction that the out-of-scope declarations be stated in docs/. First of three sequential tasks on `feature/pii-controls`.
  - resolved for the engineer: the self-reference problem is solved by runtime-generated fixtures (option (a)); a path allowlist (b) and inline allow markers (c) are rejected and locked out behaviorally by AC13. Diff unit, base resolution and the split shape of the no-completeness-wording check are also fixed in the spec.
  - 24 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec. pm-spec has no shell, so the side with execution capability must run every `check:` (dry-run, then live) and record the intent-hash (v1) sub-bullet here before implementation starts.
  - intent-hash (v1): f8ba9057669062a0e1aca2e63e4589b6243e0ac4
  - engineer (T-111): implementation complete (bin/check-pii-shapes.sh, tests/check-pii-shapes/run.sh, docs/pii-controls.md + .ja.md, CI wiring, provenance). `check-acs.sh` reports 21 passed, 3 failed (AC18/AC19/AC20) — a shell-quoting defect in those three frozen `check:` lines (`grep -qxF` missing `--` before a pattern that starts with `-`), reproduced on BSD grep and expected on GNU grep too; the docs content itself is verified byte-exact correct (see spec's `## Notes from engineer`). Needs a pm-spec rework + human re-ratification of the intent-hash to add `--` to the four affected `grep -qxF` invocations in AC18-20; not fixed here since it is inside the frozen intent block. `check-intent.sh` confirms the block is otherwise untouched (v1 hash still matches).
- [ ] **T-112** Commit-identity assertion plus a lock on the raw-dump ignore coverage — `READY_FOR_ARCH` — spec: .shell-team/specs/T-112-commit-identity-and-ignore-lock.md
  - source: GitHub issue #6, Layer 1 items 1 and 2. Second of three; depends on T-111 (same shellcheck argument line, and its own diff is measured by T-111's checker).
  - resolved for the engineer: the range is the non-merge commits from the merge-base to HEAD; merge commits are excluded, and the plain web-flow noreply identity is allowed on the committer side only, refused on the author side. Both halves are fixture-covered. Item 2 is lock-by-test only, with both ignore files byte-unchanged.
  - 25 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec; the intent-hash (v1) sub-bullet is to be recorded here by the executing side after it verifies the `check:` lines.
  - intent-hash (v1): 1bf6ac1f22aff6770b6ba358a5826bdeb0d2ff19
- [ ] **T-113** De-identification rule for lessons at every authoring surface — `READY_FOR_ARCH` — spec: .shell-team/specs/T-113-lessons-deidentification.md
  - source: GitHub issue #6, Layer 1 item 3. Third of three; depends on T-112.
  - resolved for the engineer: omission is spelled `Source: n/a`, already accepted by the existing schema, so `bin/check-playbook.sh` gets no schema change (comment-only edits, locked by AC3); the rule is deliberately not machine-validated, and the four canonical authoring surfaces are inventoried in the spec.
  - 12 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec; the intent-hash (v1) sub-bullet is to be recorded here by the executing side after it verifies the `check:` lines.
  - intent-hash (v1): 36dad027cfe3d6afad14ab8ab03d0d453a20a093

## Done

_(none)_

## Format

```markdown
- [ ] **T-XXX** <one-line title> — `<STATUS_FLAG>` — spec: <specs-dir>/<slug>.md
  - <optional latest note from whichever agent touched it last>
```

`<specs-dir>` is `.shell-team/specs/` by default (or `docs/specs/` in a legacy
`tasks/` layout). The hand-off linter accepts any spec path ending in `.md`.
