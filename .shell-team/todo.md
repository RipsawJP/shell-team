# Tasks

This is the team's shared task board. The PM creates entries; every agent updates the
status flag for the tasks it touches. This file is the single source of truth for work
state — the `/shell-team:run` loop advances the flag at each phase gate.

## Status flags

`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`
(or `BLOCKED` / `REWORK` at any stage)

## Active

- [ ] **T-111** Diff-scoped PII shape checker with a vacuity-guarded fixture suite — `REWORK` — spec: .shell-team/specs/T-111-pii-shape-checker.md
  - source: GitHub issue #6, Layer 2 items 4 and 5 plus the user instruction that the out-of-scope declarations be stated in docs/. First of three sequential tasks on `feature/pii-controls`.
  - resolved for the engineer: the self-reference problem is solved by runtime-generated fixtures (option (a)); a path allowlist (b) and inline allow markers (c) are rejected and locked out behaviorally by AC13. Diff unit, base resolution and the split shape of the no-completeness-wording check are also fixed in the spec.
  - 24 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec. pm-spec has no shell, so the side with execution capability must run every `check:` (dry-run, then live) and record the intent-hash (v1) sub-bullet here before implementation starts.
  - intent-hash (v2): 02a52c11a8381023be78f10b53528d93f35cea9c
  - intent-ratified (2026-07-27): v1→v2 — human GO given in-session on the orchestrator's ratification request (bulk option, all three specs at once) — the frozen `check:` lines passed a fixed-string pattern beginning with a literal `-` to `grep` without `--`, so getopt made grep parse the pattern as an option and exit 2; `--` was inserted at all 15 sites across T-111/T-112/T-113 with the asserted semantics (whole-line fixed-string match) unchanged
  - engineer (T-111): the v1→v2 re-freeze (763fae7) resolved the blocker — `check-acs.sh` now reports 24 passed, 0 failed. Also fixed a docs/pii-controls.md rendering defect (bullet-list/paragraph ordering + missing blank line under "## What this gate does not cover"; AC18/AC20's matched lines stayed byte-identical). Self-application, check-intent (v2 aligned) and check-provenance all re-verified green.
  - qa-verifier (T-111): PASS. 24/24 ACs green, check-intent aligned (v2), check-provenance conformant (7 honest, non-trivial decisions). Fixture suite green; vacuity guard independently re-verified in scratch copies (all 5 patterns load-bearing, suite FAILs when a positive fixture is neutralised). Exit-code contract, no-leak, `--all`/CI wiring, docs (en/ja substance + rendering), and PII hygiene of the change itself all independently confirmed. Regression suites green. Full record: .shell-team/reviews/T-111.md.
  - codex-reviewer (T-111): `REQUEST_CHANGES` — 3 blockers where the REQUIRED diff-scoped check returns exit 0 clean, all reproduced in throwaway repos: (1) a line holding both an allowed noreply address and a real mailbox shape sees only the leftmost match, (2) an added line whose content starts with `++ ` is consumed as a false file header and the `++ /dev/null` form silently blanks every later added line of that file, (3) a `-diff` gitattribute set in ANY earlier commit makes git render later text files as binary. Plus 8 major (unpinned git rendering, is_binary misjudging UTF-8, home-path charset/case gaps, working-tree vs HEAD, an AC6 negative fixture that never reaches the pattern, --all silently skipping symlinks) and 6 minor. Full record: .shell-team/reviews/T-111.md
- [ ] **T-112** Commit-identity assertion plus a lock on the raw-dump ignore coverage — `BLOCKED` — spec: .shell-team/specs/T-112-commit-identity-and-ignore-lock.md
  - source: GitHub issue #6, Layer 1 items 1 and 2. Second of three; depends on T-111 (same shellcheck argument line, and its own diff is measured by T-111's checker).
  - resolved for the engineer: the range is the non-merge commits from the merge-base to HEAD; merge commits are excluded, and the plain web-flow noreply identity is allowed on the committer side only, refused on the author side. Both halves are fixture-covered. Item 2 is lock-by-test only, with both ignore files byte-unchanged.
  - 25 acceptance criteria, all with `check:` lines runnable from the repo root.
  - intent-freeze: the intent-block markers are placed in the spec; the intent-hash (v1) sub-bullet is to be recorded here by the executing side after it verifies the `check:` lines.
  - intent-hash (v2): 900861c5081bd23899ab68e21b830d7c0d43005b
  - intent-ratified (2026-07-27): v1→v2 — human GO given in-session on the orchestrator's ratification request (bulk option, all three specs at once) — same defect class as T-111: four `grep -qxF` invocations in AC21 passed a pattern beginning with a literal `-` without `--`; fixed pre-emptively before implementation, asserted semantics unchanged
  - engineer (T-112): implementation complete — `bin/check-commit-identity.sh`, `tests/check-commit-identity/run.sh`, `tests/gitignore-raw-dumps/run.sh`, docs (en/ja) canonical lines, CI wiring, provenance file. `bash bin/check-acs.sh` reports **23/25 passed**; the 2 failures are both external to this task's own diff, isolated and reproduced with `git stash -u`:
    - AC17 (self-application, T-111's checker) fails because `bin/check-pii-shapes.sh --base develop` finds `email-nonnoreply`/`home-path` shapes inside the ALREADY-COMMITTED `.shell-team/reviews/T-111.md` (T-111's own codex-review record, which quotes adversarial example shapes by design when describing bugs). T-111 is at `REWORK` and its checker/spec are being actively reworked in this same working tree (uncommitted pm-spec WIP on `.shell-team/specs/T-111-pii-shape-checker.md`, left untouched by this task). This is a cross-task dependency, not a T-112 defect — reproduced with T-112's own changes fully stashed out.
    - AC25 (neighbour suites still pass) fails only on `tests/check-handoff/run.sh`, which uses bare `mktemp` calls that this interactive sandbox blocks (`Operation not permitted`) regardless of `$TMPDIR`; reproduced identically running `develop` HEAD's own copy of that file, so it is a sandbox-only artifact, not a regression. `check-prompt-sync`, `rollup-track`, and `team-paths` (the other three AC25 suites) all pass independently. Real CI (GitHub Actions) has a normal writable `/tmp` and is expected to be unaffected.
    - check-intent: aligned (v2). check-provenance: conformant (4 decisions, `.shell-team/provenance/T-112.md`). Recommend re-running `bash bin/check-acs.sh .shell-team/specs/T-112-commit-identity-and-ignore-lock.md` once T-111's rework lands (for AC17) and/or from CI (for AC25) before flipping to `READY_FOR_QA`.
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
