# Method-neutral human-gate wording across shipped docs, skills and prompt blocks

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1126

## Problem

Several shipped surfaces assert, as a fixed fact about the loop, that there are
"three standing human gates — the batch GO before a merge, sprint planning
approval, and any destructive or irreversible operation". Sprints, a batch GO and
a planning-approval gate are this repository's own operating convention, recorded
in the maintainer's gitignored `CLAUDE.local.md`; they are not something an
adopter has configured. `CONTRIBUTING.md`'s `## What does not belong in this
file` already rules that how often a session stops to ask is a working preference
kept there and documented by `docs/tuning-oversight.md`. An adopter running
waterfall, XP, or no sprints at all therefore reads a shipped claim about gates
they never set up.

## Summarized sources

- GitHub issue #444 (body relayed verbatim in this task's dispatch) — the occurrence list, the deliverable statement ("reword each occurrence so the shipped text states what the loop actually guarantees"), the "not in scope" carve-out, the acceptance grep, and the PATCH tier. Every measured line below was re-read first-hand against the checkout before being restated here.
- `CONTRIBUTING.md:135-142` (`## What does not belong in this file`) — the distinction that personal oversight preference is kept in the gitignored `CLAUDE.local.md` and that `CONTRIBUTING.md` does not restate it; this is the ground for treating a shipped three-gate assertion as misplaced.
- `docs/tuning-oversight.md:10-16` (`## What is fixed, and what is yours`) — the distinction this spec must preserve rather than flatten: what is fixed is **authority** ("The loop never merges on its own — merging is a human action") plus the completion gate; **whether a given merge earns a conversational stop is the tunable layer**. The issue's own phrasing ("the loop interrupts the operator at the merge GO") reads as if the interruption itself were fixed; the reworded text must carry the authority claim, not an interruption guarantee. See `## Assumptions`.
- `templates/prompt-blocks/registry.txt:52,54` — `fanout-orchestration.md` is registered `contain` against `skills/run/SKILL.md`; `means-ends-reflection.md` is registered `contain` against `skills/run/SKILL.md` and `skills/goal/SKILL.md`. This is why the block and its consumers must move in one edit.
- `bin/check-prompt-sync.sh:125-134` (`check_contain`) — `contain` mode requires every non-empty canonical line to appear verbatim as a fixed-string substring in each registered consumer; it never rewrites a consumer.
- The eight files this spec makes behavioral claims about, each read first-hand at the lines cited in `## Notes for engineer`: `docs/workflow.md`, `docs/workflow.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md`, `templates/prompt-blocks/means-ends-reflection.md`, `templates/prompt-blocks/fanout-orchestration.md`.
- `agents/scrum-master.md:119` — read first-hand and confirmed already conditional ("While a repository operates under a stacked batch-GO cycle…"); grounds the Non-goal that leaves it untouched.
- `docs/loop-engineering/agent-concurrency.md:142`, `phase-multiplexing.md:348`, `means-ends-reflection.md:62`, `default-path-firing.md:655`, `:688`, `plugin-role-agent-concurrency.md:254` — the matched lines were read first-hand; they are per-task design records of what a task decided at its own time, which grounds the Non-goal excluding `docs/loop-engineering/` from the acceptance scope.

## Goal

<!-- BEGIN intent-block: T-1126 -->

- user-visible: yes — the whole deliverable is text an adopter reads (`docs/workflow.md`, `docs/adopting.md` and their `*.ja.md` mirrors) or that an adopter's own loop executes as instructions (`skills/run/SKILL.md`, `skills/goal/SKILL.md`), so the change is visible at the adopter's surface even though it adds no capability.
- verification-class: mechanism — declared by the checklist's own enumeration rather than by feel: the diff touches `templates/prompt-blocks/`, whose bytes are compared by `bin/check-prompt-sync.sh`, so this is not a prose-only surface. The sprint's operator-approved lightweight mode replaces the per-task full-population sweep with one sprint-level sweep before release; that reduction is an operator ruling recorded in `## Assumptions`, not a reclassification of this task.
- base-ref-discriminator: not-applicable — this branch (`feature/444-method-neutral-gates`) has no open predecessor PR; its base ref is `develop` = `c585f17`, and the one criterion reading a base-side blob (**AC6**) resolves it with `git merge-base develop HEAD`.
- verification-ceiling: unit-and-static — every criterion below is a fixed-string or regex presence/absence read, a byte-scoped diff read, or a checker's exit code; no criterion needs a real adopter environment, and none is marked above the ceiling.

Every shipped surface that today asserts a three-gate set (batch GO, sprint
planning approval, destructive or irreversible operation) as a fact of the loop
instead states what the loop actually guarantees — it never merges on its own,
merging is a human action, and it stops before a destructive or irreversible
operation — and names any further stop as whatever **the operator's own
oversight configuration** adds, pointing at `docs/tuning-oversight.md`. Both
language versions of each affected document move together, and
`bin/check-prompt-sync.sh` stays green because two of the edited files are
canonical prompt-block sources.

## Non-goals

- No new mechanism, checker, gate, status flag, record family or CI step. This task changes wording only.
- The invariant **id** `human-gate-set` is not renamed, retired or removed — only the descriptive parenthetical beside it changes. Other documents and frozen specs anchor on that id.
- `agents/scrum-master.md:119` and the promoted lessons in `agents/pm-spec.md` / `agents/tech-lead.md` ("a plan, sprint, or train") are untouched: they are already conditional or generic.
- `docs/loop-engineering/**` is out of scope. Those are per-task design records of what a task decided at its own time, not statements of the shipped default; the repository's own norm is to disclose such staleness and batch it into a separate editorial pass rather than re-open frozen records.
- `.shell-team/**` (board, retros, reviews, interventions, specs, lessons), `CHANGELOG.md` and `CLAUDE.local.md` are untouched — historical records and the operator's own gitignored preferences.
- This task does not change what the loop actually does. No behaviour, authority or completion gate moves; the `both-gates-green` invariant and the rule that merging is a human action stay exactly as they are.

## Acceptance criteria

- [ ] **AC1** Each of the eight in-scope files carries the fixed clause `the operator's own oversight configuration` at its reworded locus: `docs/workflow.md`, `docs/workflow.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md`, `templates/prompt-blocks/means-ends-reflection.md`, `templates/prompt-blocks/fanout-orchestration.md`. The clause is this task's own coinage (measured zero repository-wide at authoring time; see `## Assumptions`), so its presence is not inherited from the base.
  - check: cd "$(git rev-parse --show-toplevel)" && miss=0; for f in docs/workflow.md docs/workflow.ja.md docs/adopting.md docs/adopting.ja.md skills/run/SKILL.md skills/goal/SKILL.md templates/prompt-blocks/means-ends-reflection.md templates/prompt-blocks/fanout-orchestration.md; do git grep -q -F -e "the operator's own oversight configuration" -- "$f"; rc=$?; if [ "$rc" -ne 0 ]; then echo "missing or unreadable ($rc): $f"; miss=1; fi; done; test "$miss" -eq 0
  - adopter-surface: `docs/workflow.md` and `docs/workflow.ja.md` (the phase-flow document an adopter reads) and `docs/adopting.md` / `docs/adopting.ja.md` (the adoption guide) — the adopter-facing documentation lands in this same task because it *is* this task's deliverable, not a follow-up.

- [ ] **AC2** `bin/check-prompt-sync.sh` exits 0 after the edit, so both edited prompt blocks and every consumer registered against them in `templates/prompt-blocks/registry.txt` carry the identical reworded sentences.
  - check: cd "$(git rev-parse --show-toplevel)" && bash bin/check-prompt-sync.sh

- [ ] **AC3** The Japanese mirrors moved with their English counterparts: neither `docs/workflow.ja.md` nor `docs/adopting.ja.md` still asserts the three-gate set, in either the Japanese or the borrowed-English spelling it uses today (`スプリントプランニング`, `3 つの standing human gate`, `3 つの human gate`, `planning approval`, `planning-approval`, `planning premise`). The read's exit contract distinguishes a clean absence (exit 1) from a failed read (exit > 1).
  - check: cd "$(git rev-parse --show-toplevel)" && git grep -n -F -e 'スプリントプランニング' -e '3 つの standing human gate' -e '3 つの human gate' -e 'planning approval' -e 'planning-approval' -e 'planning premise' -- docs/workflow.ja.md docs/adopting.ja.md; rc=$?; test "$rc" -eq 1

- [ ] **AC4** The issue's acceptance grep, extended with the two spellings measured at authoring time that its literal pattern misses (`planning-approval`, `planning premise`) and with the assertion's own head phrase (`three standing human gate`, `three human gate`), returns no match across `README*.md`, `docs/`, `skills/` and `templates/`, with `docs/loop-engineering/` excluded per the Non-goals. Exit 1 (clean absence) passes; exit > 1 (failed read) fails.
  - check: cd "$(git rev-parse --show-toplevel)" && git grep -n -iE -e 'sprint planning' -e 'batch GO' -e 'planning[ -]approval' -e 'planning premise' -e 'three standing human gate' -e 'three human gate' -- 'README*.md' 'docs' 'skills' 'templates' ':!docs/loop-engineering'; rc=$?; test "$rc" -eq 1

- [ ] **AC5** `docs/adopting.md` and `docs/adopting.ja.md` contain no occurrence of `planning` at all, which is what closes the two line-wrapped occurrences a line-oriented grep cannot see (`docs/adopting.md:875-876`, "the ground the planning / approval was given on"). All nine occurrences measured at authoring time sit in the single version-derivation passage this task rewords, so zero is the correct target rather than an arbitrary floor. The measured set is two named files, not a population that grows with the repository, so no re-measurement trigger applies.
  - check: cd "$(git rev-parse --show-toplevel)" && git grep -n -i -e 'planning' -- docs/adopting.md docs/adopting.ja.md; rc=$?; test "$rc" -eq 1

- [ ] **AC6** (negative) The invariant id `invariant-lock: human-gate-set` survives the edit unchanged in count: for `skills/run/SKILL.md` and `templates/prompt-blocks/fanout-orchestration.md`, the number of lines carrying that literal at HEAD equals the number at the branch point. Both sides are re-derived at run time rather than compared against a typed-in number.
  - check: cd "$(git rev-parse --show-toplevel)" && base=$(git merge-base develop HEAD) && bad=0; for f in skills/run/SKILL.md templates/prompt-blocks/fanout-orchestration.md; do a=$(git show "$base:$f" | awk 'index($0,"invariant-lock: human-gate-set")>0{n++} END{print n+0}'); b=$(awk 'index($0,"invariant-lock: human-gate-set")>0{n++} END{print n+0}' "$f"); if [ "$a" -ne "$b" ] || [ "$a" -eq 0 ]; then echo "$f: base=$a head=$b"; bad=1; fi; done; test "$bad" -eq 0

- [ ] **AC7** (negative) No executable or CI surface changes: the union of the committed range, the staged delta, the unstaged delta and the untracked strays is empty under `bin/`, `tests/` and `.github/`. This confirms the Non-goal that no mechanism, checker or CI step is added. It is merge-point-scoped and expected to go stale once later work lands on `develop`; do not widen its base resolution to keep it evergreen.
  - check: cd "$(git rev-parse --show-toplevel)" && base=$(git merge-base develop HEAD) && n=$( { git diff --no-renames --name-only "$base"...HEAD -- bin tests .github; git diff --no-renames --cached --name-only -- bin tests .github; git diff --no-renames --name-only -- bin tests .github; git ls-files --others --exclude-standard -- bin tests .github; } | sort -u | wc -l ) && test "$n" -eq 0

- [ ] **AC8** `docs/workflow.md` and `docs/workflow.ja.md` each point the reader at `docs/tuning-oversight.md` as the place further stops are configured. Neither file references it at authoring time, so this check is not vacuous.
  - check: cd "$(git rev-parse --show-toplevel)" && miss=0; for f in docs/workflow.md docs/workflow.ja.md; do git grep -q -F -e 'tuning-oversight' -- "$f"; rc=$?; if [ "$rc" -ne 0 ]; then echo "missing or unreadable ($rc): $f"; miss=1; fi; done; test "$miss" -eq 0

## Input space

**Reachable input classes.** (1) The eight in-scope files as they stand at the branch point, in UTF-8, containing ASCII prose, Japanese prose, backtick-quoted machine tokens and em-dash-separated clause lists — the exact shapes measured in `## Notes for engineer`. (2) The two `contain`-mode prompt blocks read line-by-line by `bin/check-prompt-sync.sh` and matched as fixed-string substrings against their registered consumers. (3) A checkout where `develop` resolves locally, which **AC6** and **AC7** need to read the branch point.

**Out-of-scope synthetic extremes.** Adversarially constructed markdown (nested fences that hide a marker, zero-width or homoglyph substitutes for the literals these criteria grep, CRLF-only variants beyond what `check-prompt-sync.sh` already normalizes); non-UTF-8 encodings of any edited file; a checkout with no `develop` ref at all (a shallow or single-branch clone), which is a route-back rather than a case these criteria are redesigned to survive; any file outside the eight named here plus the paths **AC7** guards; and an adopter's own local edits to these files.

<!-- END intent-block: T-1126 -->

## Assumptions

- **The issue's deliverable sentence is refined, not copied.** Issue #444 says the reworded text should state that "the loop interrupts the operator at the merge GO and before destructive or irreversible operations". `docs/tuning-oversight.md:12` draws a distinction the issue's phrasing flattens: what is fixed is that **the loop never merges on its own — merging is a human action**, while **whether a given merge earns a conversational stop is the tunable layer**. The Goal above carries the authority claim rather than an interruption guarantee, so the new text does not reintroduce a different unearned promise. Flagged for the engineer: keep this distinction in the replacement prose.
- **Borrowed-vocabulary count-premise sweep (T-1081).** One literal count premise is asserted: the clause `the operator's own oversight configuration` occurs **zero** times at the branch point. Classification: **own-coinage** — it is introduced by this task and appears in no merged document. Measured 2026-09-07 against the working tree (clean, equal to HEAD) as zero repository-wide. The execution-capable side re-runs it against the branch point's committed blobs before the freeze and records the value here: `git grep -c -F -e "the operator's own oversight configuration" "$(git merge-base develop HEAD)" -- . ; echo rc=$?` (rc=1 with no output is the expected zero). No borrowed token is asserted with a count premise.
- **Operator-approved lightweight mode (sprint "method-neutral", approved 2026-09-06T15:04Z).** This task's declared `verification-class: mechanism` would ordinarily oblige a per-task full-population downstream-impact diff. The operator's ruling replaces that with one sprint-level sweep before release and removes the cross-provider spec-review round. This is recorded as the ruling it is rather than folded into a `no-mechanism` declaration, so the classification stays honest and the reduction stays attributable. **Relayed**: the approval reached this role through the dispatch and is confirmed by the coordinating session, not readable from this checkout.
- **Line numbers move.** The occurrence table in `## Notes for engineer` was measured 2026-09-07; edits within a file shift the later lines in it. Locate each site by its quoted phrase, not by its line number.

## Open questions

None blocking.

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| Reword every in-scope occurrence to state what the loop actually guarantees | **AC1**, **AC4** |
| Point at `docs/tuning-oversight.md` for further stops | **AC8** |
| `check-prompt-sync` must stay green (prompt blocks are generated sources) | **AC2** |
| Both language versions of each doc move together | **AC3** (absence side), **AC1** (presence side) |
| The `premise=` wording must stop presuming a sprint | **AC5** |
| No new mechanism, checker or gate | **AC7** (negative, executable surfaces unchanged) |
| The invariant id `human-gate-set` is not renamed or removed | **AC6** (negative, base-relative count invariant) |
| `docs/loop-engineering/**`, `.shell-team/**`, `agents/scrum-master.md:119`, the promoted lessons are out of scope | **AC4**'s pathspec exclusion + `## Non-goals`; the `agents/` and `.shell-team/` trees are outside **AC4**'s pathspec by construction |
| Tier PATCH | info-only (not promoted to AC) — the release tier is a property of the sprint's release derivation, not of any file this task edits, so no check over the working tree can observe it |
| Behaviour, authority and the `both-gates-green` invariant do not move | info-only (not promoted to AC) — **AC7** already proves no executable surface changed, which is the observable consequence; a further AC asserting an unchanged runtime behaviour would have no diff to read |

## Notes for engineer

**Measured occurrence table** (read first-hand 2026-09-07; the issue's own list said `skills/run/SKILL.md:261` — the measured line is **259** — and did not list `skills/run/SKILL.md:57`, which this measurement adds).

| # | File:line | The assertion to reword |
|---|---|---|
| 1 | `docs/workflow.md:78-81` | "The three standing human gates — the batch GO before a merge, sprint planning approval, and any destructive or irreversible operation — are unchanged" |
| 2 | `docs/workflow.ja.md:79-82` | "3 つの standing human gate——マージ前の batch GO、スプリントプランニングの承認、破壊的・不可逆な操作——は変わらない" |
| 3 | `templates/prompt-blocks/means-ends-reflection.md:4` | "the three standing human gates are unchanged: batch GO, sprint planning, and destructive or irreversible operations stay exactly as they are" — **canonical source** |
| 4 | `skills/run/SKILL.md:85` | consumer of #3 (`contain` mode) |
| 5 | `skills/run/SKILL.md:105` | consumer of #3 (`contain` mode) |
| 6 | `skills/goal/SKILL.md:245` | consumer of #3 (`contain` mode) |
| 7 | `templates/prompt-blocks/fanout-orchestration.md:19` | `invariant-lock: human-gate-set` — "the three human gates (the sprint's own batch GO, planning approval, and confirmation before a destructive or irreversible operation) are untouched" — **canonical source** |
| 8 | `skills/run/SKILL.md:239` | consumer of #7 (`contain` mode) |
| 9 | `skills/run/SKILL.md:259` | the reconcile-step variant of the same `invariant-lock` line ("this step changes only how N workers' work is composed"); inside the `<!-- BEGIN reconcile-step: T-1077 -->` region, which is **not** registry-governed — edit it by hand |
| 10 | `skills/run/SKILL.md:57` | not in the issue's list: "one of exactly three standing human gates this same skill already declares", "re-enters the existing planning-approval gate", "the repository's approved planning premise" |
| 11 | `docs/adopting.md:875-876, 878, 883, 887-888` | "the ground the planning / approval was given on"; "approved planning premise"; "one of the three standing human gates this loop already declares" |
| 12 | `docs/adopting.ja.md:841, 843, 848, 854-856` | the Japanese mirror of #11 |

**Gotchas.**

- Sites #3/#7 are canonical prompt blocks in `contain` mode: every non-empty line must appear **verbatim as a fixed-string substring** in each registered consumer (`bin/check-prompt-sync.sh:125-134`). Edit block and consumers in one pass, then run `bash bin/check-prompt-sync.sh`. Consumers: `means-ends-reflection.md` → `skills/run/SKILL.md`, `skills/goal/SKILL.md`; `fanout-orchestration.md` → `skills/run/SKILL.md` (`templates/prompt-blocks/registry.txt:52,54`).
- Sites #9 and #10 are hand-edited: neither is inside a registry-governed prompt block, so `check-prompt-sync.sh` will not catch a missed one. **AC4** is what catches them.
- Site #10 and sites #11/#12 must agree: `skills/run/SKILL.md:57` and the `docs/adopting.*` passages both describe the same T-1110 version-derivation record and its `premise=` field. Rename the concept consistently (for example "approved release-tier premise"), and keep the `- version-derivation (…): verdict=… premise=…` field grammar itself untouched — only its prose description changes.
- `README.md:182` matches "planning" ("planning vs. execution vs. cross-provider review", model routing) and is **not** in scope; no criterion here touches it.
- **Measured-at-ref commands**: not applicable — none of this task's deliverables prints a command beside a `measured at <ref>` label.
- Prior art for the wording target: `docs/tuning-oversight.md:10-16` and `CONTRIBUTING.md:141`.
