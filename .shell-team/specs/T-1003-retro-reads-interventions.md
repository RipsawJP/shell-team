# T-1003 — the retro reads the interventions directory as its ninth declared input

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1003
**Source**: GitHub issue #37 — its requirement that the retro must actually read the channel. Advances issue #28's third direction to completion on the read side. No new issue was opened: #37 already carries the design brief and is the tracker.
**Branch**: `feature/retro-reads-interventions` (from `develop` at `874718d`).

## Problem

T-1002 shipped the intervention-capture channel: `<base>/interventions/`, one
append-only file per task plus a reserved `no-task.md`, a closed seven-class
enum, a fail-closed `bin/check-interventions.sh`, and an unconditional gate at
the Implement-to-Validate seam. The channel works — this repository's own
`.shell-team/interventions/T-1002.md` already holds five real entries captured
while T-1002 was being built.

Nothing reads it. The retro's declared-inputs ledger (T-1001) has exactly eight
input ids, none of them the interventions directory, so a retro composed today
still cannot see the moments a human intervened, corrected, or stopped the work.
That is the material issue #28 calls its most important, and the reason the
sprint exception was granted in the first place: a log preserves what happened,
it does not preserve what mattered. Until the ledger declares the directory, the
capture channel writes into a room nobody enters.

## Goal

<!-- BEGIN intent-block: T-1003 -->

`interventions` is the **ninth declared input** of the retro's ledger. Running
`retro-inputs.sh` against this repository reports it as `read` with a count and
the resolved directory; against a repository with no such directory it reports
`unavailable`; against a scaffolded but empty one it reports `empty`. The
scrum-master role is told what the material **is** — the salience index issue #28
asked for — and its Loop reads it. `bin/check-retro.sh` enforces the ledger
against a closed enum of **nine** ids, so a retro that omits the line is a
violation rather than a silent gap.

**The ninth input costs zero new promotion sites.** T-1002 shaped the channel as
a directory precisely so the existing `report_dir_input` machinery counts it
exactly like `reviews/`, `specs/`, `provenance/`, `runs/` and `retros/`: suffix
`.md`, statuses `read` / `empty` / `unavailable`, and T-1001's inverted default,
where `unavailable` stands unless an affirmative determination promotes it. One
new call to a shared function adds no textual `promote_read` / `promote_empty`
site, so T-1001's pin of exactly eight promotion sites in both directions
survives this task untouched, and no decision site, ledger status, or bounded
invariant state is added. **The ledger counts files, never entries**: it never
parses an interventions file's contents, because the grammar of an entry is
`bin/check-interventions.sh`'s knowledge and a second copy of it would be a
second thing to drift.

**Every place that enumerates the input set is updated together, and the two
different eights are not confused.** Nineteen files carry the enumeration —
the canonical prompt block, its four registered consumers, the two `retro-inputs`
suites, the `check-retro` suite and its ten ledger-bearing fixtures, and this
repository's one committed retro. The mentions of "eight" that mean *the number
of inputs* become nine; the mentions that mean *the number of promotion sites*
stay eight. The committed retro is backfilled honestly — `unavailable`, because
the channel did not exist during that cycle — which is also the only thing that
breaks the circularity of a self-checked enum: without it CI's dogfood of
`check-retro.sh` over this repository's retros goes red the moment the enum
grows, and with it every other assertion is proved against real material.

**Two silent-failure paths in the existing suites are closed, because this task
is the one that walks into them.** The ten `check-retro` fixtures are asserted
only by exit code and one stderr pattern, so a fixture edited incompletely still
exits 1 and still passes; each fixture now asserts its **declared number of
violations**, with the measured caveat that `fail-inputs-duplicate-section.md`
legitimately emits two, so "exactly one" is the wrong universal pin. And
`check-prompt-sync.sh`'s `contain` mode is a substring search, so a full example
ledger line in the template would mask a missing bare legend line; the legend
region and the two load-bearing enum variables (`IDS`, `RETRO_INPUTS_IDS`) are
therefore each asserted independently, each with a positive control.

**T-1001's frozen spec is not edited.** Seven of its criteria assert the number
eight and go stale against the post-T-1003 tree. A closed task's recorded intent
is not reopened to keep its criteria evergreen; the staleness is recorded as a
note on T-1001's board entry naming exactly which criteria go stale and why,
following that entry's own precedent for merge-point-scoped criteria.

## Non-goals

- **Any change to `bin/check-interventions.sh`, `templates/prompt-blocks/interventions-classes.md`,
  or the seven-class enum.** T-1002 shipped the channel's grammar and it is not
  this task's to touch. The ledger's relationship to an interventions file is
  "there is a file, with a `.md` suffix" and nothing finer.
- **Parsing entries, counting them, or reporting a per-class tally in the
  ledger's detail.** That needs the entry grammar in a second place. The count in
  the detail is a count of **files**, and the noun says so.
- **The opt-in sample hook and the qualification of `docs/tuning-oversight.md`'s
  "this project ships no hooks".** That is T-1004. Nothing here ships a hook or
  edits that document.
- **A new promotion site, a new decision site (`DS-n`) row, a new ledger status,
  or a tenth state in `tests/retro-inputs/invariants.sh`.** All four are pinned in
  both directions by T-1001's live criteria and re-asserted here. The
  directory-input class is already exercised by DS-3 and DS-4 through a shared
  code path; adding an `interventions`-specific non-traversable fixture would test
  the same lines twice and would widen a boundary T-1001 closed deliberately.
- **Editing `.shell-team/specs/T-1001-retro-input-acquisition.md`.** It is a
  closed task's frozen intent. Its criteria going stale is recorded, not repaired.
- **Retro CONTENT judgments.** What a retro concludes from intervention material —
  which class matters, whether `unclassified` has grown too far, what to propose
  as a lesson — is the scrum-master's runtime job. This task tells the role what
  the material is and where it lives; it prescribes no threshold, no metric and no
  numeric rule.
- **Issues #23 / #24 (the lessons corpus import and a `lessons` resolver key).**
  Both still open, so `lessons` stays `unavailable` and gains nothing here.
- **The six layout-enumeration documents.** Standing decision: they do not
  enumerate `provenance/` or `interventions/` either (T-1001 and T-1002
  precedent).
- **`bin/team-paths.sh` and `.github/workflows/check-handoff.yml`.** The
  `interventions` resolver key already exists (T-1002) and is consumed as-is; no
  new script and no new suite means no CI edit. The existing dogfood steps
  (`bash bin/retro-inputs.sh --base HEAD`, `bash bin/check-retro.sh .shell-team/retros/*.md`)
  exercise this change without modification.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh` — the spec's invocation convention,
distinct from the agent-instruction convention (bare name on `PATH`) that
T-1001's AC30 governs and that this task must not break.

Three standing rules apply to every criterion, each learned from a defect this
repository produced:

- **No negated `grep` without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` cannot be read, because `grep` exits 2 and the negation
  swallows it.
- **A count is pinned in both directions** wherever a count is the property —
  adding one and deleting one both fail.
- **A criterion states the boundary of what it proves.** Where a criterion pins a
  fixture *case* by label, the label proves the case exists, not that its
  assertion tests what its name says; reading that attachment is QA's and the
  reviewer's job.

**pm-spec has no shell in this role, so no `check:` line below was executed.**
The executing side runs all 22 live against the pre-implementation tree before
the intent-hash is recorded, corrects any line that is broken as a command or
would pass vacuously (meaning preserved), and only then freezes.

- [ ] **AC1** The canonical single source gains exactly one line, as the **last**
  id, and its shape is pinned in both directions: `templates/prompt-blocks/retro-inputs.md`
  carries exactly nine `- input: ` lines, exactly three `- status: ` lines,
  thirteen non-empty lines in total, and the ninth (last) `- input: ` line is
  `- input: interventions`. A tenth id fails; deleting one fails. This is also
  the criterion that catches the direction `check-prompt-sync.sh` cannot see — a
  canonical file that shrank while every consumer still carries the line.
  - check: F=templates/prompt-blocks/retro-inputs.md && test "$(grep -c -- '^- input: ' "$F")" -eq 9 && test "$(grep -c -- '^- status: ' "$F")" -eq 3 && test "$(grep -c -- '.' "$F")" -eq 13 && grep -qxF -- '- input: interventions' "$F" && test "$(grep -n -- '^- input: ' "$F" | tail -n 1 | cut -d: -f1)" -eq 9

- [ ] **AC2** All four registered consumers carry the new canonical line and
  `bin/check-prompt-sync.sh` is green. The pre-existing `- input: pr-metadata`
  line is grepped in each of the same four files as the positive control, so a
  file that cannot be read fails the criterion instead of passing it.
  - check: bash bin/check-prompt-sync.sh >/dev/null && for f in bin/retro-inputs.sh bin/check-retro.sh agents/scrum-master.md docs/templates/retro-template.md; do grep -qF -- '- input: interventions' "$f" || exit 1; grep -qF -- '- input: pr-metadata' "$f" || exit 1; done

- [ ] **AC3** **The template's legend and its example ledger are asserted
  independently**, because `contain` mode is a substring search and a full example
  ledger line would otherwise mask a missing bare legend line. In
  `docs/templates/retro-template.md` the blockquote legend carries nine
  `> …- input: ` lines including a bare `- input: interventions`, and the example
  ledger separately carries nine top-level `- input: ` lines including an
  `interventions` line with a status; the prose count reads nine, not eight. Each
  count is the other's positive control.
  - check: F=docs/templates/retro-template.md && test "$(grep -c -- '^>[[:space:]]*- input: ' "$F")" -eq 9 && grep -qE -- '^>[[:space:]]*- input: interventions[[:space:]]*$' "$F" && test "$(grep -c -- '^- input: ' "$F")" -eq 9 && grep -qE -- '^- input: interventions — status: ' "$F" && grep -qF -- 'all nine' "$F" && ! grep -qF -- 'eight' "$F"

- [ ] **AC4** **The two load-bearing enum variables are asserted directly**, each
  as a whole line, so the id cannot reach the emitted ledger without also reaching
  the checker's enum (or vice versa) while every other assertion stays green.
  - check: grep -qxF -- 'IDS="cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions"' bin/retro-inputs.sh && grep -qxF -- 'RETRO_INPUTS_IDS="cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions"' bin/check-retro.sh

- [ ] **AC5** The emitted ledger names the nine ids exactly once each, in the
  canonical order of `templates/prompt-blocks/retro-inputs.md`, with
  `interventions` last — so a probe that returns early cannot remove a line or
  reorder the ledger.
  - check: out="$(bash bin/retro-inputs.sh --base HEAD)" && test "$(printf '%s\n' "$out" | grep -oE -- '^- input: [a-z-]+' | sed 's/^- input: //' | tr '\n' ' ')" = "cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions "

- [ ] **AC6** **Zero new promotion sites, zero new decision sites, and no entry
  parsing.** The two promotion functions and their **eight** textual call sites are
  unchanged (T-1001's pin, re-asserted here because this task is what could break
  it); the `report_dir_input` call sites go from five to **six**, the new one
  naming `interventions`, `TEAM_INTERVENTIONS_DIR`, the `.md` suffix and the noun
  `intervention records`; the `DS-n` inventory still has exactly eight rows with
  DS-3's id list extended to name `interventions`; and no non-comment line of
  `bin/retro-inputs.sh` mentions the entry token `intervention:` — the ledger
  counts files, never entries.
  - check: nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && test "$(printf '%s\n' "$nc" | grep -cE -- '^(promote_read|promote_empty)\(\)')" -eq 2 && test "$(printf '%s\n' "$nc" | grep -oE -- '(^|[^a-z_])(promote_read|promote_empty)[[:space:]]' | wc -l | tr -d ' ')" -eq 8 && test "$(printf '%s\n' "$nc" | grep -cE -- '^report_dir_input ')" -eq 6 && printf '%s\n' "$nc" | grep -qE -- '^report_dir_input interventions[[:space:]].*TEAM_INTERVENTIONS_DIR.*"\.md".*"intervention records"' && test "$(grep -cE -- '^# +DS-[1-8] ' bin/retro-inputs.sh)" -eq 8 && grep -qF -- 'previous-retro, interventions): determination' bin/retro-inputs.sh && ! printf '%s\n' "$nc" | grep -qF -- 'intervention:'

- [ ] **AC7** The directory is located through the resolver, never synthesised.
  `bin/team-paths.sh --get interventions` resolves it (the T-1002 key, dogfooded
  here), the script still calls the resolver, and no non-comment line of
  `bin/retro-inputs.sh` contains a literal `.shell-team/` or `tasks/` path. Both
  positive controls are present: the non-comment extraction is non-empty and it
  names the resolver.
  - check: test "$(bash bin/team-paths.sh --get interventions)" = ".shell-team/interventions" && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && printf '%s\n' "$nc" | grep -qF -- 'team-paths.sh' && ! printf '%s\n' "$nc" | grep -qE -- '\.shell-team/|(^|[^A-Za-z0-9_./-])tasks/'

- [ ] **AC8** Against **this** repository the input is `read`, and the detail says
  how much was found and where, in the units it actually counted: `<N> intervention
  records in <resolved dir>`, with `N` at least 1. "Records" rather than
  "interventions" is load-bearing — one file carries many entries, so a count of
  files reported as a count of interventions would be a false number.
  - check: bash bin/retro-inputs.sh | grep -qE -- '^- input: interventions — status: read — detail: [1-9][0-9]* intervention records in .*interventions$'

- [ ] **AC9** `empty` and `unavailable` stay distinguishable for the new input:
  a base directory that does not exist yields `unavailable` with a reason and a
  **complete nine-line ledger**, exercised directly here; a scaffolded directory
  holding no `.md` file (the `.gitkeep` a fresh `team-init` leaves) yields `empty`,
  and an absent one yields `unavailable`, both pinned as fixture cases by label.
  - check: out="$(TEAM_RUN_BASE=no-such-base-t1003 bash bin/retro-inputs.sh)" && printf '%s\n' "$out" | grep -qE -- '^- input: interventions — status: unavailable — detail: .+' && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 9 && grep -qF -- 'case: an interventions directory holding no .md files -> empty, never unavailable' tests/retro-inputs/run.sh && grep -qF -- 'case: an absent interventions directory -> unavailable, never empty' tests/retro-inputs/run.sh

- [ ] **AC10** `tests/retro-inputs/run.sh` is re-pinned at nine in both
  directions: every ledger-completeness assertion counts nine, no `-eq 8`
  survives, the per-id loop enumerates all nine ids by name, the completeness
  case's label reads nine, and the suite passes. The nine-counting assertions are
  the positive control for the negated `-eq 8` grep.
  - check: T=tests/retro-inputs/run.sh && test "$(grep -cF -- '-eq 9' "$T")" -ge 5 && ! grep -qF -- '-eq 8' "$T" && grep -qF -- 'case: every ledger is complete (all nine input ids, exactly once)' "$T" && grep -qF -- 'for id in cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions; do' "$T" && bash "$T" >/dev/null

- [ ] **AC11** The bounded invariants lock counts nine ledger lines and **does not
  grow a state**: its single invariant sentence, its assertion and its message all
  read nine, no `-eq 8` or `8 complete ledger lines` survives, the closed state
  list is still exactly nine, and the lock passes. T-1001 pinned that list at nine
  in both directions precisely so it cannot grow by accretion; this task adds no
  state and says so here.
  - check: T=tests/retro-inputs/invariants.sh && grep -qF -- 'In every state below, retro-inputs.sh prints "## Retro inputs" and nine complete ledger lines and exits 0 or 2; any other exit status (including 1 and 141) and any output with fewer than nine ledger lines is a violation.' "$T" && test "$(grep -ohE -- 'state: [a-z0-9 .-]+' "$T" | sort -u | wc -l | tr -d ' ')" -eq 9 && ! grep -qF -- '-eq 8' "$T" && ! grep -qF -- '8 complete ledger lines' "$T" && ! grep -qF -- 'eight' "$T" && bash "$T" >/dev/null

- [ ] **AC12** `bin/check-retro.sh`'s closed enum grows to nine in **every** place
  it is written — the header canonical list (AC2), the `RETRO_INPUTS_IDS`
  variable (AC4) and rule 4's own prose enumeration — while the rest of its
  contract is untouched: the status enum is byte-identical, all five decorated
  Japanese heading constants are byte-identical, and this repository's own retro
  passes.
  - check: F=bin/check-retro.sh && grep -qF -- 'pr-metadata, interventions)' "$F" && grep -qxF -- 'RETRO_INPUTS_STATUSES="read empty unavailable"' "$F" && for l in "KEEP='## Keep（続けたい良い動き）'" "PROBLEM='## Problem（直面した課題 / 痛み）'" "TRY='## Try（次サイクルで試すこと）'" "TRAPS='## 罠の点検（Comprehension Debt / Cognitive Surrender）'" "LESSON_PREFIX='## Lesson 候補（'"; do grep -qxF -- "$l" "$F" || exit 1; done && bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null

- [ ] **AC13** Every one of the **ten** ledger-bearing fixtures gains exactly one
  `interventions` line, and the eleventh — `fail-inputs-missing-section.md`, whose
  defect is having no ledger at all — gains none. `pass-canonical.md` still passes,
  which is the positive control: it is the one fixture where a missing ninth line
  would already be a failure.
  - check: for f in pass-canonical fail-inputs-unknown-status fail-inputs-unknown-id fail-inputs-missing-id fail-inputs-duplicate-id fail-inputs-empty-detail fail-inputs-blank-detail fail-inputs-stray-line fail-inputs-duplicate-section fail-inputs-line-outside-section; do test "$(grep -c -- '^- input: interventions ' "tests/check-retro/fixtures/$f.md")" -eq 1 || exit 1; done && test "$(grep -c -- '^- input: ' tests/check-retro/fixtures/fail-inputs-missing-section.md)" -eq 0 && bash bin/check-retro.sh tests/check-retro/fixtures/pass-canonical.md >/dev/null

- [ ] **AC14** **The fixture suite can no longer pass on an incompletely edited
  fixture.** `tests/check-retro/run.sh` asserts, per fixture, the **exact number**
  of violation lines the checker emits, via a helper used at every one of the
  eleven fixture call sites — so an added `missing Retro inputs id: interventions`
  violation is a failure rather than an unnoticed extra. The superseded prose claim
  that each fixture "isolates exactly one violation" is gone, because it is false:
  `fail-inputs-duplicate-section.md` legitimately emits two (the duplicate heading
  and the second region's now-stranded ledger line), so "exactly one" is the wrong
  universal pin. A mutation case proves the new assertion bites: with the
  `interventions` line removed from a **copy** of `pass-canonical.md`, the count
  rises by exactly one and the case fails; the committed fixture is never modified.
  The inline CRLF fixture's prose is corrected to the new count in the same pass.
  - check: T=tests/check-retro/run.sh && grep -qF -- 'assert_violations' "$T" && test "$(grep -c -- 'assert_violations ' "$T")" -ge 11 && grep -qF -- 'case: each ledger fixture emits its declared number of violations (fail-inputs-duplicate-section legitimately emits two)' "$T" && grep -qF -- 'case: removing the interventions line from a COPY of pass-canonical.md adds exactly one violation' "$T" && grep -qF -- 'the other eight ids missing entirely' "$T" && ! grep -qF -- 'isolates exactly one violation' "$T" && bash "$T" >/dev/null

- [ ] **AC15** **The committed retro is backfilled, honestly.**
  `.shell-team/retros/2026-07-28.md` carries a ninth ledger line for
  `interventions` with status `unavailable` and a detail naming the reason — the
  channel did not exist until T-1002 — never `empty` (which would assert the
  directory was consulted and held nothing) and never `read`. The file passes, and
  so does the glob CI already runs. This is the assertion that makes the whole
  change non-circular: it is the one place where growing the enum has a consequence
  no other criterion could produce.
  - check: R=.shell-team/retros/2026-07-28.md && test "$(grep -c -- '^- input: ' "$R")" -eq 9 && grep -qE -- '^- input: interventions — status: unavailable — detail: .*the channel did not exist until T-1002' "$R" && bash bin/check-retro.sh "$R" >/dev/null && bash bin/check-retro.sh .shell-team/retros/*.md >/dev/null

- [ ] **AC16** **The role is told what the material is and its Loop reads it.**
  `agents/scrum-master.md` declares nine canonical inputs (not eight), gains one
  guidance item under `## Inputs you read` stating that the interventions line is
  the salience index issue #28 asked for, that entries cluster by class, and that
  growth in `unclassified` is the retro's own business, and gains one Loop step
  that reads the counted files. Both insertions are pinned by a single count of
  top-level numbered items — five plus eleven becomes six plus twelve, i.e.
  eighteen — so neither can be dropped and neither can be doubled. The Loop's two
  cross-references to the grounding steps are updated so they stay true after the
  insertion. No numeric threshold or metric for `unclassified` is introduced. And
  T-1001's AC30 invariant still holds: every relative-path occurrence of the script
  is preceded by `bash `.
  - check: F=agents/scrum-master.md && grep -qF -- '- input: interventions' "$F" && test "$(grep -c -- 'nine canonical inputs' "$F")" -eq 1 && ! grep -qF -- 'eight canonical inputs' "$F" && grep -qF -- 'the salience index issue #28 asked for' "$F" && grep -qF -- 'unclassified' "$F" && ! grep -qE -- 'unclassified[^.]*(threshold|exceeds|more than)' "$F" && test "$(grep -cE -- '^[0-9]+\. ' "$F")" -eq 18 && test "$(grep -c -- 'steps 2–5' "$F")" -eq 2 && ! grep -qF -- 'steps 2–4' "$F" && test "$(grep -o -- 'bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" -eq "$(grep -o -- 'bash bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')"

- [ ] **AC17** **The two different eights are not confused.** In
  `bin/retro-inputs.sh` exactly two mentions of "eight" remain and **both** are
  about promotion sites; its header's input-count sentence reads nine. No mention
  of "eight" remains in `agents/scrum-master.md`, `tests/retro-inputs/run.sh`,
  `tests/retro-inputs/invariants.sh` (AC11) or `docs/templates/retro-template.md`
  (AC3). Every negated grep here is paired with a positive control on the same
  file.
  - check: test "$(grep -c -- 'eight' bin/retro-inputs.sh)" -eq 2 && test "$(grep -- 'eight' bin/retro-inputs.sh | grep -c -- 'sites')" -eq 2 && test "$(grep -c -- 'nine canonical inputs' bin/retro-inputs.sh)" -eq 1 && test "$(grep -c -- 'nine' tests/retro-inputs/run.sh)" -ge 1 && ! grep -qF -- 'eight' tests/retro-inputs/run.sh && test "$(grep -c -- 'nine canonical inputs' agents/scrum-master.md)" -eq 1 && ! grep -qF -- 'eight' agents/scrum-master.md

- [ ] **AC18** Nothing that already worked stops working: prompt sync and its
  suite, the board linter on both the shipped template and this repository's board,
  the resolver suite, the interventions checker dogfooded against the record this
  retro will now count, and `shellcheck` on every script and suite this task
  edits. `shellcheck` is invoked unconditionally, so its absence fails the
  criterion loudly instead of passing it vacuously.
  - check: bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash tests/team-paths/run.sh >/dev/null && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1002.md" >/dev/null && shellcheck bin/retro-inputs.sh bin/check-retro.sh tests/retro-inputs/run.sh tests/retro-inputs/invariants.sh tests/check-retro/run.sh

- [ ] **AC19** **The protected invariants are still intact after the change.**
  Six files this task must not touch are byte-unchanged against the base ref:
  T-1002's checker and its canonical class block (the channel's grammar),
  T-1001's frozen spec (a closed task's recorded intent), T-1004's posture
  document, the CI workflow (no new script means no new step) and the path
  resolver (its `interventions` key already exists). And the `lessons` line is
  still `unavailable`, so issues #23 / #24 are untouched. The overall diff being
  non-empty is the positive control. **Merge-point-scoped**: this criterion
  resolves `develop` and is expected to go stale once this task lands there; do
  not widen its base-ref resolution or re-derive it per rework round.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(git diff --name-only develop -- bin/check-interventions.sh templates/prompt-blocks/interventions-classes.md .shell-team/specs/T-1001-retro-input-acquisition.md docs/tuning-oversight.md .github/workflows/check-handoff.yml bin/team-paths.sh)" && bash bin/retro-inputs.sh | grep -qE -- '^- input: lessons — status: unavailable — detail: .+'

- [ ] **AC20** The change stays inside its declared surface: every path in
  `git diff --name-only develop` matches the allow-list below, and the diff is
  non-empty as a positive control. The allow-list includes this task's mandatory
  records — spec, provenance, review record, the interventions file the gate
  requires, the board and the test recipe — so a required artefact is never
  outside the scope lock. **Merge-point-scoped**: tied to the merge point it was
  authored at and expected to go stale after merge, when later work moves
  `develop` forward. Do not merge-range it, re-derive it per rework round, or
  widen its base-ref resolution.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.shell-team/(todo\.md|test-recipe\.md|retros/2026-07-28\.md|specs/T-1003-retro-reads-interventions\.md|provenance/T-1003\.md|reviews/T-1003[^/]*|interventions/T-1003\.md)|agents/scrum-master\.md|bin/(check-retro|retro-inputs)\.sh|docs/templates/retro-template\.md|templates/prompt-blocks/retro-inputs\.md|tests/(check-retro|retro-inputs)/.+)$')"

- [ ] **AC21** The task's decision provenance file exists and is conformant,
  located through the resolver rather than a hardcoded path.
  - check: bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1003.md" >/dev/null

- [ ] **AC22** **The staleness of T-1001's criteria is recorded, not repaired.**
  T-1001's board entry carries a note naming exactly which of its criteria go
  stale against the post-T-1003 tree and why, in the phrasing pinned below, and
  T-1001's spec file itself is byte-unchanged (AC19). A criterion of a closed task
  going stale is expected; silently leaving no record of it is what this criterion
  forbids.
  - check: grep -qF -- 'T-1003 grows the ledger enum to nine, so AC2, AC3, AC6, AC10, AC13, AC14 and AC23 of this task go stale' "$(bash bin/team-paths.sh --get todo)"

## Input space

**Reachable input classes** — what real usage can produce, and what the
implementation must therefore be correct about:

1. The interventions directory in each of the five states `report_dir_input`
   distinguishes: **absent** (an adopter who has never run `team-init`, or a
   checkout predating T-1002); **present and holding no `.md` file** (a fresh
   scaffold, where `team-init` leaves only `.gitkeep`); **present with one or more
   `<task-id>.md` files** and possibly the reserved `no-task.md`; **present but
   not readable**; and **present, readable, but not traversable** — the state
   where names can be listed but not stat'ed, which must read `unavailable` and
   never `empty`.
2. Non-`.md` entries inside the directory — `.gitkeep` above all — which are
   enumerated and correctly counted as non-matches.
3. An entry whose name ends in `.md` but which is not a regular file: a directory
   so named, or a broken symlink. Inherited from T-1001's class 9 through the
   shared enumeration; nothing about it is specific to this directory.
4. Interventions files whose **contents** are any of the shapes T-1002's grammar
   allows: a marker region with one or many entries, the zero-entry sentinel, the
   reserved `no-task.md`, any of the seven class tokens including `unclassified`.
   None of it is parsed by the ledger, and no byte of a file's body reaches the
   emitted detail — the detail names the directory, not the content.
5. Retro files a checker must judge under the nine-id enum: a complete ledger; one
   missing `interventions`; one duplicating it; one giving it a status outside the
   enum; and the historical retro whose cycle predates the channel entirely.
6. Both supported layouts (the `.shell-team/` default and the legacy `tasks/`
   split-root layout) and a `$TEAM_RUN_BASE` override, in all of which the
   resolver's `interventions` key answers.
7. A cycle in which the directory holds several task files, so the count in the
   detail is greater than one and the scrum-master reads more than one file.

**Out-of-scope synthetic extremes** — named and declined:

1. **Parsing, counting or tallying entries inside an interventions file** —
   including a per-class breakdown in the ledger's detail. That duplicates
   `bin/check-interventions.sh`'s grammar knowledge in a second place, and the
   directory-input contract counts files by construction.
2. **Adversarial repository states beyond the nine `tests/retro-inputs/invariants.sh`
   enumerates.** T-1001 closed that list at nine in both directions and declared
   the boundary; this task adds no state and does not reopen it. Inside the nine
   the invariant is asserted; outside them nothing is claimed.
3. Adversarially large inputs: thousands of interventions files, a megabyte-scale
   `summary:` value, a retro with hundreds of ledger lines.
4. Non-UTF-8 bytes, NUL bytes, or Unicode line/bidi separators inside an
   interventions file. The ledger never reads a file's body, so no such byte can
   reach a ledger line; the display-level concern belongs to the
   repository-wide content guard, exactly as T-1001 recorded.
5. A hostile `git`, `gh` or resolver earlier on `PATH` returning well-formed but
   fabricated output. The ledger is a discipline aid for a committed, reviewed
   artefact, not a security boundary against an adversarial author.
6. **Whether every intervention was actually recorded.** A file carrying the
   sentinel while ten interventions happened is conformant to T-1002's gate, and
   counting files cannot detect it. The ledger reports what exists, never fidelity
   — the same trust boundary `bin/check-provenance.sh` declares.
7. Retro content quality: what the retro concludes from the material, and whether
   a class distribution warrants an action.
8. Concurrent retro runs, and local agent transcripts.

<!-- END intent-block: T-1003 -->

## Resolved design decisions

### DP-1 — `interventions` is appended as the ninth and last canonical id

The alternative was inserting it after `previous-retro`, grouping it with the
other directory-backed inputs. Appending wins on one measurable ground: the
canonical list behaves as an append-only registry, so every one of the nineteen
consumer sites takes a single added line and the existing eight ids keep their
relative order byte-identical. Grouping buys semantic tidiness and pays for it by
moving `lessons` and `pr-metadata` in every ordered assertion and every legend,
for no property a consumer can use — nothing keys off adjacency, because
`report_dir_input` is called by id, not by position.

### DP-2 — the status comes from `report_dir_input`, unchanged

The suffix is `.md`, so `.gitkeep` counts as enumerated-and-not-a-match and a
freshly scaffolded directory reports `empty` rather than `read`. This is the whole
reason T-1002 shaped the channel as a directory: T-1001's AC2 pins the promotion
sites at exactly eight in both directions, and a shared function called a sixth
time adds no textual site, so the pin survives without negotiation. Any design
that adds a promotion site is out of bounds — it would put this task in conflict
with a closed task's frozen criterion, which is a much larger decision than a
ninth input.

### DP-3 — the ledger counts files, not entries

Reading entries would mean re-implementing the quad grammar
(`- intervention: <class>` plus `date:` / `summary:` / `effect:`) in
`bin/retro-inputs.sh`. This project's most frequently recorded defect is a second
copy drifting from the first, and the checker already owns that grammar. The
retro reads entries — that is the scrum-master's Loop step, done by opening the
files — while the ledger's job is only to declare that the material was there and
enumerable.

### DP-4 — the detail's noun is `intervention records`

`report_dir_input`'s detail is `<count> <noun> in <dir>`, and the count is of
files. One file carries many entries, so `4 interventions in …` would be a false
number in the artefact whose entire purpose is honest declaration. `records`
names the unit actually counted.

### DP-5 — T-1001's frozen spec is not edited; a board note records the staleness

Drift is measured against frozen intent, so a closed task's spec is not rewritten
to keep its criteria evergreen — that would make the record follow the code,
which is the failure mode the freeze exists to prevent. The note goes on T-1001's
board entry, where that entry already carries the precedent line for criteria
that are merge-point-scoped and expected to go stale. AC22 pins the note; AC19
pins the spec file byte-unchanged.

### DP-6 — the historical retro is backfilled as `unavailable`, not `empty`

`empty` asserts the input was consulted and held nothing. On 2026-07-28 the
channel did not exist, so nothing was consulted; reporting `empty` would be
exactly the substitution T-1001's whole inversion exists to prevent. This follows
T-1001's own backfill discipline: transcribe what is recorded, never reconstruct
a number.

### DP-7 — the role is told what the material is, not what to conclude

The guidance item names the material's role (the salience index), its structure
(entries cluster by class) and one thing worth watching (growth in
`unclassified`, which T-1002 declared as a named degradation risk no count can
adjudicate). It sets no threshold. A number here would be invented, and inventing
a metric to look rigorous is a failure this repository has recorded before.

### DP-8 — no new fixture case for the shared failure modes

DS-3 and DS-4's non-traversable-directory cases already exercise the exact lines
the `interventions` call reaches, through `review-artifacts`. The two new fixture
cases AC9 pins are the two that are genuinely specific to this input: an empty
scaffold and an absent directory. Adding a third that re-tests shared code would
widen a boundary T-1001 deliberately closed.

### DP-9 — per-fixture violation counts, not "exactly one violation per fixture"

The obvious closure for the silent-fixture path is "each fixture emits exactly
one violation". It is wrong as measured: `fail-inputs-duplicate-section.md` emits
two — the duplicated heading, and the second region's ledger line, which becomes
a line-outside-the-section violation once the first region has closed. The suite
therefore declares an expected count per fixture. The suite's existing prose
claiming one violation per fixture was already inaccurate before this task and is
corrected in the same pass.

## Measured inventory (verified against the tree; re-verify line numbers before editing)

Nineteen operative files. The line numbers below were read at `874718d`; treat
them as a map, not as a substitute for reading the file.

| File | Sites | What changes |
|---|---|---|
| `templates/prompt-blocks/retro-inputs.md` | 1 | one appended `- input: interventions` line (registry row unchanged — `contain` mode, four consumers already listed) |
| `bin/retro-inputs.sh` | 5 | header canonical list; header input-count sentence (line 11); DS-3's id list (line 48); `IDS` (line 177); one `report_dir_input` call beside the existing five (after line 448) |
| `bin/check-retro.sh` | 3 | header canonical list; rule 4's prose id enumeration (lines 28–30); `RETRO_INPUTS_IDS` (line 81) |
| `agents/scrum-master.md` | 5 | the `contain` block region (lines 27–38); the "each of eight canonical inputs" sentence (line 25); one new guidance item under `## Inputs you read`; one new Loop step; the two `steps 2–4` cross-references (lines 68, 80) |
| `docs/templates/retro-template.md` | 3 | blockquote legend (lines 14–21); the "all eight canonical ids" sentence (line 62); the example ledger (lines 71–78) |
| `tests/retro-inputs/run.sh` | 9+ | five `-eq 8` (lines 108, 178, 188, 250, 342); the per-id loop (line 109); the "all eight input ids" label at four occurrences (lines 105, 108, 111, 113); two new fixture cases |
| `tests/retro-inputs/invariants.sh` | 4 | the invariant sentence (line 5); the helper comment (line 90); the assertion and its message (line 103) — **without adding a state** |
| `tests/check-retro/run.sh` | 3+ | the per-fixture violation-count helper and its eleven call sites; the "isolates exactly one violation" prose (line 64); the inline CRLF fixture's "other seven ids" prose (line 85) |
| `tests/check-retro/fixtures/*.md` | 10 | one ledger line each; `fail-inputs-missing-section.md` gains nothing |
| `.shell-team/retros/2026-07-28.md` | 1 | one backfilled `unavailable` line — **mandatory**, or CI's `check-retro.sh` dogfood goes red |

Two corrections to the inventory as it was handed over, both measured here:
**DS-4's row lists no ids** (only DS-3 does), so that is one site and not two; and
the `all eight input ids` label occurs **four** times in
`tests/retro-inputs/run.sh` (one comment, two `fail` messages, one `pass`), not
three.

## T-1001 criteria that go stale, and the note that records them

Seven, not three. Each was checked against the post-T-1003 tree:

| T-1001 criterion | Why it goes stale |
|---|---|
| **AC2** | its *behavioural* half counts the emitted ledger lines at `-eq 8`. The promotion-site pin (2 functions, 8 textual sites) **survives** and is re-asserted by this task's AC6 — but the criterion as a whole fails |
| **AC3** | pins the ordered eight-id string |
| **AC6** | counts `-eq 8` ledger lines and matches an eight-way id alternation |
| **AC10** | greps `tests/retro-inputs/invariants.sh`'s invariant sentence byte-exactly, and that sentence says "eight complete ledger lines". Its nine-state list is untouched |
| **AC13** | greps the label `case: every ledger is complete (all eight input ids, exactly once)` |
| **AC14** | counts `-eq 8` ledger lines on the unresolvable-ref run |
| **AC23** | counts `-eq 8` ledger lines in the committed retro |

AC5, AC25 and AC26 were already declared merge-point-scoped by T-1001 itself and
went stale when it merged; they are not in this list. Everything else in T-1001
survives, including AC4's `DS-n` count, AC7's no-hardcode property, AC20's
fixture rejections, AC21's heading constants and AC30's invocation convention —
all four of which this task's criteria re-assert precisely because it is the task
that could break them.

The note text AC22 pins, for the board's T-1001 entry (appended by the
orchestrator — this task does not otherwise edit that entry):

> - staleness note (2026-07-30, recorded by T-1003): T-1003 grows the ledger enum to nine, so AC2, AC3, AC6, AC10, AC13, AC14 and AC23 of this task go stale — each counts eight ledger lines, pins the ordered eight-id string, or byte-pins a label or sentence that says "eight". AC2's promotion-site pin (two functions, eight textual call sites) is unaffected and T-1003 re-asserts it. This spec is NOT re-frozen and its intent-hash stays aligned: the spec file is byte-unchanged, so the staleness is inert for `check-intent.sh` and for CI, which never runs a closed task's criteria.

## Body-to-AC correspondence

Every normative directive in this spec's body, mapped to the criterion that holds
it or to an explicit exemption with a reason.

| Body directive | Held by |
|---|---|
| Reuse `report_dir_input`; zero new promotion sites | AC6 |
| Suffix is `.md`, so a `.gitkeep`-only directory is `empty` | AC6 (the call's arguments), AC9 (the behaviour) |
| `interventions` is the ninth and **last** canonical id | AC1, AC5 |
| The detail's noun is `intervention records` — files, not entries | AC8 |
| The ledger never parses entry contents | AC6 (no `intervention:` token in non-comment lines) |
| The directory is resolved through `bin/team-paths.sh`, never synthesised | AC7 |
| `empty` and `unavailable` are never substituted for one another | AC9, AC15 |
| No new decision-site row; DS-3 names the new id | AC6 |
| No new ledger status | AC1 (three status lines), AC12 (`RETRO_INPUTS_STATUSES` byte-identical) |
| No tenth invariant state | AC11 |
| The enum grows in **every** place it is written | AC1, AC2, AC4, AC12, AC13, AC16 |
| The legend and the example ledger are asserted independently | AC3 |
| The two enum variables are asserted independently | AC4 |
| Mentions of "eight" that mean the input count change; those that mean promotion sites stay | AC17 |
| The committed retro is backfilled as `unavailable`, naming the reason | AC15 |
| Every ledger-bearing fixture gains exactly one line; the section-less one gains none | AC13 |
| Per-fixture violation counts, with `duplicate-section` legitimately at two | AC14 |
| The role is told what the material is; a Loop step reads it | AC16 |
| No numeric threshold or metric for `unclassified` | AC16 (negated grep with a positive control) |
| T-1001's AC30 invocation convention stays intact | AC16 |
| `bin/check-interventions.sh` and the class block are untouched | AC19 |
| `docs/tuning-oversight.md` is untouched (T-1004's posture) | AC19 |
| `bin/team-paths.sh` and the CI workflow are untouched | AC19 |
| T-1001's spec file is byte-unchanged | AC19 |
| `lessons` stays `unavailable` (issues #23 / #24 untouched) | AC19 |
| The five decorated Japanese headings are byte-identical | AC12 |
| The change stays inside its declared surface | AC20 |
| The staleness of T-1001's criteria is recorded on the board | AC22 |
| Provenance record exists and is conformant | AC21 |
| The six layout-enumeration documents are not updated | **info-only (not promoted to AC)** — a standing decision predating this task (T-1001 and T-1002 both recorded it); AC20's allow-list already excludes those paths, so the mechanical half is held there and a second criterion would assert the same absence twice |
| Line numbers in the measured inventory must be re-verified before editing | **info-only (not promoted to AC)** — an instruction to the engineer about how to work, not a property of the shipped artefact; the criteria assert content, never a line number, so nothing downstream depends on the map being fresh |
| No new issue was opened; #37 is the tracker | **info-only (not promoted to AC)** — a provenance statement about how this task was filed, with no artefact in the tree to assert against |

## Assumptions

- **`bin/check-intent.sh` and CI never evaluate a closed task's criteria.** The
  workflow runs `tests/check-intent/run.sh` (a fixture suite) and no dogfood pass
  over `.shell-team/specs/`, and `check-intent.sh` compares a spec's intent block
  against its recorded hash — which stays aligned because T-1001's spec bytes are
  untouched. The staleness AC22 records is therefore a documentation fact with no
  CI consequence. Verified by reading the workflow; re-confirm if a spec-wide
  dogfood step is ever added.
- The nine-id order and every canonical string this spec pins are **this spec's**
  bytes; there is no second copy of them elsewhere in the file to drift from.
- `TEAM_INTERVENTIONS_DIR` is the export name `bin/team-paths.sh` already emits
  for the `interventions` key (read at `874718d`), so `bin/retro-inputs.sh`
  consumes it the same way it consumes the other five directory keys.
- The scrum-master's Loop can read the counted files with the tools it already
  has (`Read`, `Grep`, `Glob`); no tool-permission change is needed and none is
  requested.

## Open questions

None blocking.

## Notes for engineer

**Build order that keeps the tree green at each step.** The enum is
self-referential — the checker validates the retro the repository commits — so
sequence matters more than usual:

1. `templates/prompt-blocks/retro-inputs.md` (the single source) and the four
   consumers' canonical regions together, so `check-prompt-sync.sh` never sees a
   half-propagated block.
2. `.shell-team/retros/2026-07-28.md` **early**, right after `RETRO_INPUTS_IDS`
   grows. This is the circularity breaker: until the backfill lands, every
   `check-retro.sh` run over this repository's retros — including CI's dogfood —
   reports a missing id.
3. `bin/retro-inputs.sh`'s `IDS`, its DS-3 row and the new `report_dir_input`
   call; then the two `retro-inputs` suites.
4. The ten fixtures, then `tests/check-retro/run.sh`'s counting helper. Doing the
   helper first gives you a suite that fails loudly on each unedited fixture,
   which is a useful worklist.
5. `agents/scrum-master.md` and `docs/templates/retro-template.md` prose last.

**Three traps measured in advance.**

- **`check-prompt-sync.sh` is directional.** `contain` mode verifies
  canonical-to-consumer containment only. A canonical file that *shrank* leaves
  every consumer harmlessly carrying an extra line and the checker stays green —
  which is why AC1 pins the canonical file's own counts. A consumer that is
  missing the line is what the checker catches.
- **`contain` mode is a substring search.** In `docs/templates/retro-template.md`
  the example ledger line `- input: interventions — status: …` contains
  `- input: interventions`, so the bare legend line could be omitted and prompt
  sync would still pass. AC3 asserts the legend region on its own for exactly this
  reason.
- **The `-eq 8` in `tests/retro-inputs/run.sh` is not one pattern.** Five sites
  count ledger lines and one nearby `-eq 1` counts per-id occurrences; do not
  rewrite the latter. AC10's negated `-eq 8` grep will catch a missed site, but
  only after the suite has already been made to pass, so grep first.

**Prior art to read before writing.** `bin/retro-inputs.sh`'s
`report_dir_input` / `count_dir_entries` pair and its DS inventory;
`bin/check-retro.sh` rule 4's three-outcome cross-check;
`.shell-team/interventions/T-1002.md` — the five real entries the retro will now
read, and the best available answer to what the guidance item should say;
`.shell-team/test-recipe.md` (append a procedure if you establish one).

**Mutation self-check before hand-off**, per the standing discipline: break each
new lock deliberately and observe it go red, then restore and observe green. At
minimum — remove the `interventions` line from a copy of one fixture (AC14's
counting assertion must fire), delete the new `report_dir_input` call (AC8 must
fire), and revert one of the five `-eq 9` sites (AC10 must fire). Report each
mutation with the observed failure.

**Records this task must produce**: `.shell-team/provenance/T-1003.md` (AC21),
`.shell-team/interventions/T-1003.md` (the T-1002 gate at the
Implement-to-Validate seam — the orchestrator is the producer, not you), and the
review record. All three are inside AC20's allow-list already.
