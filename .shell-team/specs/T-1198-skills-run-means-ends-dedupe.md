# skills/run carries the means-ends reflection paragraph once: step 6's copy becomes a pointer to step 5

**Task ID**: T-1198

## Problem

`skills/run/SKILL.md` carries the T-1095 means-ends reflection and disposition paragraph twice, measured at develop `b5927c58`: whole at line 108 (step 5, Validate) and again at line 131 (step 6, Review), where it repeats line 108 verbatim and then adds one step-6-only sentence ("Naming the executed disposition's authorship class here — … and that asymmetry stays as it is."). Every orchestrator run reads the paragraph twice for no added instruction (issue #781). The duplication is invisible to the existing guard: `templates/prompt-blocks/registry.txt` registers the block at line 54 as a `contain` row naming `skills/run/SKILL.md` and `skills/goal/SKILL.md` as consumers, and `bin/check-prompt-sync.sh`'s `check_contain` only asserts that each non-empty canonical line occurs somewhere in the consumer file (`grep -qF`), so it cannot tell two copies from one. `docs/loop-engineering/means-ends-reflection.md:5` states the block is mirrored into `skills/run/SKILL.md` "step 5, step 6", which becomes false once the step-6 copy goes.

Pinned shape (settled by tech-lead): line 108 stays whole; line 131 is replaced **in place, as one line**, by a step-6 pointer bullet in the form lines 124, 129 and 130 already use ("the same instruction as step 5 applies here"), followed byte-for-byte by the unchanged authorship sentence. The in-place, line-count-preserving shape keeps the existing line citations into this skill (in `docs/loop-engineering/machinery-inventory.md` and `docs/loop-engineering/telemetry-instance-verification.md`) valid. Rejected alternative: keep line 131 and delete line 108 — it shifts every later line citation and leaves step 5's STOP branch (line 102, which refers to the reflection's executed disposition) pointing forward to a later step. Rewording the authorship sentence is out of bounds: it is position-bound ("here", "this branch", "step 6 carries no pre-existing authorship-declaration bullet") and stays as it is.

## Acceptance criteria

Change detectors are AC1, AC3, AC6 and AC7's positive control (each fails at base `b5927c58`). AC2, AC4 and AC5 pass at base by construction: they are invariants guarding against collateral damage, not change detectors.

- [ ] **AC1** The first canonical line of `templates/prompt-blocks/means-ends-reflection.md` occurs on exactly one line of `skills/run/SKILL.md` (two at base: lines 108 and 131).
  - check: n=$(grep -cF -- "$(head -n 1 templates/prompt-blocks/means-ends-reflection.md | tr -d '\r')" skills/run/SKILL.md); [ "$n" = 1 ]
- [ ] **AC2** (invariant) The prompt-block sync checker still passes: every canonical line of the block remains present in each registered consumer.
  - check: bash bin/check-prompt-sync.sh
- [ ] **AC3** The full step-6 authorship sentence occurs exactly once in `skills/run/SKILL.md`, byte-for-byte unchanged, on a line that lies between the `6. **Review**` and `7. **Done**` step headings and that also carries the pointer phrase "the same instruction as step 5 applies here" (the pointer half fails at base, where line 131 carries the duplicated paragraph instead).
  - check: f=skills/run/SKILL.md; p="Naming the executed disposition's authorship class here — AI self-discipline (self-imposed, never operator-ratified) or an operator-ratified ruling — satisfies the same duty step 5's authorship-declaration bullet states, now that this branch can execute a disposition on its own authority too; step 6 carries no pre-existing authorship-declaration bullet of its own to sit beside, and that asymmetry stays as it is."; [ "$(grep -cF -- "$p" "$f")" = 1 ] || exit 1; l=$(grep -nF -- "$p" "$f" | cut -d: -f1); s=$(grep -n '^6\. \*\*Review\*\*' "$f" | cut -d: -f1); e=$(grep -n '^7\. \*\*Done\*\*' "$f" | cut -d: -f1); [ -n "$l" ] && [ -n "$s" ] && [ -n "$e" ] && [ "$l" -gt "$s" ] && [ "$l" -lt "$e" ] && sed -n "${l}p" "$f" | grep -qF 'the same instruction as step 5 applies here'
- [ ] **AC4** (invariant) `skills/run/SKILL.md` has the same line count as at base, so line citations into it stay valid.
  - check: a=$(wc -l < skills/run/SKILL.md); b=$(git show b5927c58:skills/run/SKILL.md | wc -l); [ "$b" -gt 0 ] && [ "$a" -eq "$b" ]
- [ ] **AC5** (invariant) `skills/goal/SKILL.md` and everything under `templates/prompt-blocks/` are unchanged from base — committed, staged and unstaged.
  - check: git diff --quiet --no-renames b5927c58...HEAD -- skills/goal/SKILL.md templates/prompt-blocks/ && git diff --quiet --no-renames --cached -- skills/goal/SKILL.md templates/prompt-blocks/ && git diff --quiet --no-renames -- skills/goal/SKILL.md templates/prompt-blocks/
- [ ] **AC6** `docs/loop-engineering/means-ends-reflection.md` no longer claims the block is mirrored into step 6: it still names `skills/run/SKILL.md` (positive control) and contains no `step 6` (at base it occurs once, on line 5).
  - check: f=docs/loop-engineering/means-ends-reflection.md; grep -qF 'skills/run/SKILL.md' "$f" || exit 1; grep -qF 'step 6' "$f"; [ $? -eq 1 ]
- [ ] **AC7** The changed-file set against base — the union of the committed range, the staged delta, the unstaged delta and untracked strays — contains both `skills/run/SKILL.md` and `docs/loop-engineering/means-ends-reflection.md` (positive control, fails at base) and nothing else outside `.shell-team/`. This criterion is merge-point-scoped and expected to go stale once later work lands on the base ref; it is not to be widened to stay evergreen.
  - check: s=$( { git diff --no-renames --name-only b5927c58...HEAD && git diff --no-renames --cached --name-only && git diff --no-renames --name-only && git ls-files --others --exclude-standard; } ) || exit 1; printf '%s\n' "$s" | grep -qx 'skills/run/SKILL.md' || exit 1; printf '%s\n' "$s" | grep -qx 'docs/loop-engineering/means-ends-reflection.md' || exit 1; printf '%s\n' "$s" | grep -v '^$' | grep -vx -e 'skills/run/SKILL.md' -e 'docs/loop-engineering/means-ends-reflection.md' | grep -q -v '^\.shell-team/'; [ $? -eq 1 ]

## Notes for engineer

- Edit line 131 only; do not touch line 108. The step-6 line must carry the phrase `the same instruction as step 5 applies here` verbatim (AC3 checks it); the rest of the pointer wording is yours, in the idiom of lines 124/129/130. The line ends with the authorship sentence: the "Worked example: …" pointer stays on line 108 only (pinned here, not checked).
- Rewrap of `docs/loop-engineering/means-ends-reflection.md` lines 4–6 is free, but the doc must not contain the string `step 6` at all afterwards (AC6), so do not write e.g. "step 6 points back to step 5".
- Measured at b5927c58 by pm-spec: the paragraph's distinctive phrase occurs on 2 lines of `skills/run/SKILL.md`; `docs/loop-engineering/machinery-inventory.md` carries 4 and `telemetry-instance-verification.md` 2 `skills/run/SKILL.md:<n>` citations.
- Measured-at-ref command check: not applicable — the deliverable prints no command beside a ref label.
- Stacking: T-1199 (#782) stacks on this branch (relayed).
