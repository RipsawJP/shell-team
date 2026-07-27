# Tasks

This is the team's shared task board. The PM creates entries; every agent updates the
status flag for the tasks it touches. This file is the single source of truth for work
state — the `/shell-team:run` loop advances the flag at each phase gate.

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`
(or `BLOCKED` / `REWORK` at any stage)

## Active

- [ ] **T-111** Diff-scoped PII shape checker with a vacuity-guarded fixture suite — `READY_FOR_QA` — spec: .shell-team/specs/T-111-pii-shape-checker.md
  - source: GitHub issue #6, Layer 2 items 4 and 5 plus the user instruction that the out-of-scope declarations be stated in docs/. First of three sequential tasks on `feature/pii-controls`.
  - resolved for the engineer: the self-reference problem is solved by runtime-generated fixtures (option (a)); a path allowlist (b) and inline allow markers (c) are rejected and locked out behaviorally by AC13. Diff unit, base resolution and the split shape of the no-completeness-wording check are also fixed in the spec.
  - 24 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec. pm-spec has no shell, so the side with execution capability must run every `check:` (dry-run, then live) and record the intent-hash (v1) sub-bullet here before implementation starts.
  - intent-hash (v2): 02a52c11a8381023be78f10b53528d93f35cea9c
  - intent-ratified (2026-07-27): v1→v2 — human GO given in-session on the orchestrator's ratification request (bulk option, all three specs at once) — the frozen `check:` lines passed a fixed-string pattern beginning with a literal `-` to `grep` without `--`, so getopt made grep parse the pattern as an option and exit 2; `--` was inserted at all 15 sites across T-111/T-112/T-113 with the asserted semantics (whole-line fixed-string match) unchanged
  - engineer (T-111): the v1→v2 re-freeze (763fae7) resolved the blocker — `check-acs.sh` now reports 24 passed, 0 failed. Also fixed a docs/pii-controls.md rendering defect (bullet-list/paragraph ordering + missing blank line under "## What this gate does not cover"; AC18/AC20's matched lines stayed byte-identical). Self-application, check-intent (v2 aligned) and check-provenance all re-verified green.
- [ ] **T-112** Commit-identity assertion plus a lock on the raw-dump ignore coverage — `READY_FOR_ARCH` — spec: .shell-team/specs/T-112-commit-identity-and-ignore-lock.md
  - source: GitHub issue #6, Layer 1 items 1 and 2. Second of three; depends on T-111 (same shellcheck argument line, and its own diff is measured by T-111's checker).
  - resolved for the engineer: the range is the non-merge commits from the merge-base to HEAD; merge commits are excluded, and the plain web-flow noreply identity is allowed on the committer side only, refused on the author side. Both halves are fixture-covered. Item 2 is lock-by-test only, with both ignore files byte-unchanged.
  - 25 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec; the intent-hash (v1) sub-bullet is to be recorded here by the executing side after it verifies the `check:` lines.
  - intent-hash (v2): 900861c5081bd23899ab68e21b830d7c0d43005b
  - intent-ratified (2026-07-27): v1→v2 — human GO given in-session on the orchestrator's ratification request (bulk option, all three specs at once) — same defect class as T-111: four `grep -qxF` invocations in AC21 passed a pattern beginning with a literal `-` without `--`; fixed pre-emptively before implementation, asserted semantics unchanged
- [ ] **T-113** De-identification rule for lessons at every authoring surface — `READY_FOR_ARCH` — spec: .shell-team/specs/T-113-lessons-deidentification.md
  - source: GitHub issue #6, Layer 1 item 3. Third of three; depends on T-112.
  - resolved for the engineer: omission is spelled `Source: n/a`, already accepted by the existing schema, so `bin/check-playbook.sh` gets no schema change (comment-only edits, locked by AC3); the rule is deliberately not machine-validated, and the four canonical authoring surfaces are inventoried in the spec.
  - 12 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec; the intent-hash (v1) sub-bullet is to be recorded here by the executing side after it verifies the `check:` lines.
  - intent-hash (v2): c33b85a0a3cc4430be00d73cb4374b96fb05d365
  - intent-ratified (2026-07-27): v1→v2 — human GO given in-session on the orchestrator's ratification request (bulk option, all three specs at once) — same defect class as T-111: two `grep -qxF` invocations in AC1 and AC5 passed a pattern beginning with a literal `-` without `--`; fixed pre-emptively before implementation, asserted semantics unchanged

## Done

_(none)_

## Format

```markdown
- [ ] **T-XXX** <one-line title> — `<STATUS_FLAG>` — spec: <specs-dir>/<slug>.md
  - <optional latest note from whichever agent touched it last>
```

`<specs-dir>` is `.shell-team/specs/` by default (or `docs/specs/` in a legacy
`tasks/` layout). The hand-off linter accepts any spec path ending in `.md`.
