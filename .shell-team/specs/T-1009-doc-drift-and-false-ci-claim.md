# T-1009 — the two documents agents and contributors are pointed at stop contradicting the tree

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1009
**Source**: GitHub issue #30, filed as a fast-follow from #25 and deferred by the cross-provider review in all six of that task's rounds because both sites were outside its scope. No new issue was opened: #30 carries both drifts and stays the tracker. Sequenced immediately after T-1008 on purpose — fixing the shipped wording before the corpus import would have been re-churned by that import's regeneration.
**Branch**: `chore/doc-drift-t-1009` (from `develop` at `0906862`).

## Problem

Two documents that something else points at kept their wording while the thing
they described changed. They are filed together because that is the one cause
they share.

**`docs/workflow.md`'s `## Conventions` section states a branch form this
repository has never used** (`feat/T-XXX-<slug>`) and spells the spec and review
paths as the legacy `docs/specs/` and `tasks/reviews/` literals, on a repository
that runs the shipped default layout. `CONTRIBUTING.md:102` now sends
contributors to this file, and `README.md:164` sends adopters to it. #25
corrected the branch form in `CONTRIBUTING.md` itself and deliberately left this
file alone. Its `.ja.md` twin carries the identical three drifts, and — measured
2026-07-31 — one bullet fewer than the English section, so a Japanese reader gets
a different contract from the same section.

**The `2026-06-17` board-format entry in the lessons corpus asserts that a CI
step lints the board.** Its `Rule` says a malformed active-section line "fails
the board-lint CI step"; its `How to apply` says to run the linter locally
"(the same check CI runs)". No CI step lints this repository's live board — the
one real step, `Lint the shipped board template (hand-off linter)`, targets
`templates/todo-template.md`, and `CONTRIBUTING.md:40` already says so in as many
words. Worse, the `Rule` sentence is a **shipping surface**: it is injected into
`templates/prompt-blocks/playbook-pm-spec.md` and `playbook-engineer.md` and from
there into `agents/pm-spec.md` and `agents/engineer.md`, so every adopter's
pm-spec and engineer are told a fact about their repository's CI that the plugin
ships no workflow to make true. A role definition is acted on rather than read,
which makes this the sharper of the two drifts.

**The issue's own inventory is stale, and this spec re-pins it.** #30 and its
2026-07-29 comment name a literal step name `Lint tasks/todo.md` in four files.
T-1008 removed that literal — zero hits across `agents/ templates/ skills/ bin/`
and the corpus, measured on `0906862`. What survives is the softer wording above:
the false *implication* in translated form, in the same four shipped files plus
the corpus entry itself. The `Why` field is different in kind: it narrates a real
incident in a repository whose CI genuinely did lint its live board. That
narration is historically true; the present-tense generalisation is what is
false here.

## Goal

<!-- BEGIN intent-block: T-1009 -->

**Neither document contains a claim about this repository that the repository
contradicts, and the corrected wording is true in *any* repository running this
loop.** Not "true here after the fix" — true in an adopter's repository too,
because both surfaces ship: `docs/workflow.md` is linked from `README.md` and the
corpus entry's `Rule` is spliced into two shipped role definitions.

**The corpus entry is corrected in place, and only its three prose fields
change.** The entry's heading — its key — stays byte-identical to `develop`, so
the disposition ledger's destination for that row stays valid and no new corpus
key enters. `Category`, `Applies-to`, `Scope`, `Status` and `Source` stay
byte-identical too; `Rule`, `Why` and `How to apply` are the whole edit, three
lines changed and three lines added, nothing else in the corpus touched. The
corpus stays schema-green at the resolved lessons path.

**No field claims a CI step, and no field names a step from this repository's
workflow.** The linter is named by its distributed bare command,
`check-handoff.sh`, which is on `PATH` in every repository with the plugin loaded
and is therefore true everywhere. The historical incident survives in `Why`,
narrated in the past tense and attributed to "the repository where the incident
happened" — never to a named repository, organisation or person. Naming *this*
repository's real step inside a shipped block would be the identical defect one
level up, so no shipped surface carries that step's name at all.

**The correction reaches the shipped surfaces through the generator, never by
hand.** `bin/gen-playbook-blocks.sh` regenerates from the corrected corpus,
`bin/check-prompt-sync.sh` stays green, and regeneration is a fixed point.
Because the entry's `Applies-to` is unchanged, the blast radius is exactly four
files — `templates/prompt-blocks/playbook-{pm-spec,engineer}.md` and
`agents/{pm-spec,engineer}.md`. `playbook-qa-verifier.md`, `playbook-tech-lead.md`,
`agents/qa-verifier.md` and `agents/tech-lead.md` come out **byte-identical** to
`develop`.

**`docs/workflow.md` asserts no branch naming form, and names operating
directories by resolver rather than by layout literal.** The branch bullet keeps
the loop-relevant content it is the only home for (the engineer works directly on
the task's feature branch; worktrees only when the orchestrator opts in) and
points at `CONTRIBUTING.md` for the naming convention instead of restating one —
restating it would create the second copy `CLAUDE.md` forbids, and asserting
*any* naming form is wrong in an adopter-facing document. The spec and review
paths are written in resolver form (`bin/team-paths.sh --get specs`, `--get
reviews`), which is correct in both supported layouts rather than in at most one.
The bullets measured accurate — PR-body diff stats, never editing
`.claude/agents/*` — survive unchanged, and so do the `## Phase boundaries` and
`## Hand-off contract` sections `CONTRIBUTING.md` promises a reader will find
here.

**`docs/workflow.ja.md` is corrected in the same change, including the bullet it
was already missing.** The two language variants' `## Conventions` / `## 規約`
sections carry the same five bullets and the same contract. A stale translation
is exactly the miss `CLAUDE.md` §Language warns about.

**The numbers are measured at fix time, not copied from the issue.** The branch
form is re-measured against this repository's own merge history at the fix
commit, and the pointer sweep — everything that points at either changed file —
is re-run at fix time with its command strings and hit counts recorded, rather
than asserted in prose.

## Non-goals

- **Adding a CI step that lints this repository's live board**, to make the old
  claim true. It would not fix the shipped block (an adopter's CI is still not
  ours), the plugin ships no workflow file at all, and the local-lint duty is
  already documented at `CONTRIBUTING.md:86`. Filed as a fast-follow candidate at
  the recording step, not built here.
- **The ~30-hit hardcoded-legacy-path surface** in shipped role prompts
  (`agents/drift-evaluator.md`, `agents/codex-reviewer.md`,
  `agents/scrum-master.md`, `agents/pm-spec.md`'s non-generated prose),
  `skills/run/SKILL.md`, `templates/*.yaml`, `bin/` header comments and
  `docs/templates/retro-template.md`. It is a genuine same-class defect against
  `CLAUDE.md`'s "never hardcode them", and a substantially larger surface than
  #30's two named sites — seven role definitions and four checkers. Sprint scope
  discipline: **file it, do not touch it.**
- **Any change to the disposition ledger**
  (`docs/loop-engineering/lessons-import-disposition.md`), in either direction.
  Its stated contract is the per-row disposition of the *import* — source date,
  sequence, outcome, reason, destination — and nothing that column asserts
  becomes false: the outcome is still `loop` and the destination is still that
  key. The ledger is not an edit log; a sixth column would change a documented
  five-column contract to record a fact it does not claim to record.
- **Supersession of the corpus entry.** The entry's *ground* is unchanged; what
  was wrong is a supporting factual claim. See DP-1.
- **Any `bin/` change.** None is needed, and `tests/errexit-safe/run.sh` pins
  `bin/gen-playbook-blocks.sh` by `file:line:content`. If the engineer concludes
  a `bin/` change is required, that is a STOP-and-escalate, not a quiet fix.
- **Repairing frozen records of merged tasks.**
  `.shell-team/specs/T-1000-operating-conventions.md`'s AC23 `check:` requires
  both drifts to still be present and is already false since T-1008 removed the
  literal it greps; it is stale by design, run by no CI step, and stays as
  written. Same for every `.shell-team/reviews/T-1000.md` round record and every
  T-1008 frozen criterion.
- **Rewriting the parts of `docs/workflow.md` measured accurate** — the
  `<specs dir>/design-note-T-NNN.md` pointer, the `/review` and
  `/review-response` rows, the canonical `codex exec … review --base … --json`
  form, the PR-body-diff-stats bullet and the `.claude/agents/*` bullet.
- **Creating `CONTRIBUTING.ja.md`** — deliberately absent per T-1000.
- **Any `CHANGELOG.md` entry or `plugin.json` version bump** — that belongs to
  the release task.
- **Fixture and record occurrences of the old strings.**
  `tests/check-handoff/fixtures/valid.md`'s `branch feat/T-100` is a fixture in
  the reserved id range and follows its own rules; the spec, review and board
  records that quote the old claim are history.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh` or `bash tests/<suite>/run.sh`.

Standing rules, all inherited from what this repository has already paid for:

- **No negated or zero-count `grep` without a same-target positive control and an
  existence guard.** A `! grep -q … FILE` and a `test "$(grep -c … FILE)" -eq 0`
  both "pass" when `FILE` cannot be read. Unlike T-1008, every target here
  **already exists** — which makes the discipline cheaper, not optional: a
  mistyped path or a directory renamed by a later task would otherwise turn a
  broken command into a green criterion. Every absence assertion below pairs with
  `test -s` (or `test -d`) on the same target and with something that must be
  present.
- **Anchored extraction, then equality.** Where a criterion protects an exact
  string, it extracts the line or block and compares it for **equality** against
  the same extraction from the base ref, rather than testing containment
  (playbook lesson 2026-07-22). Containment conflates "the text is present" with
  "the meaning is being asserted".
- **No literal em dash in any pattern.** The corpus's entry keys use U+2014;
  every extraction anchors on `2026-06-17 .*The board` so the em dash is matched
  by `.*` rather than typed into a check line.
- **Every temporary fixture uses an explicit `mktemp` template**
  (`"${TMPDIR:-/tmp}/t1009.XXXXXX"`). A bare `mktemp` ignores an inherited
  `TMPDIR` on macOS. Every criterion that builds one removes it and preserves its
  own verdict across the cleanup.
- **No process substitution.** `/dev/fd` is blocked in some sandboxes this
  repository must still run in; every criterion that needs a list writes it to a
  temp file first.
- **A criterion never mutates the working tree.** The regeneration probe writes
  into a scratch root; the corpus, the blocks and both documents are read only.
- **Which criteria pass before the change** (to be measured live by the executing
  side before the freeze, and this disclosure corrected to the measured result):
  **AC4, AC5, AC6, AC11, AC12, AC15, AC16 and AC19** — the eight two-sided
  invariant locks. They are true on `develop` and required to still be true
  after, which is what makes them regression detectors rather than change
  detectors (AC19 becomes true as soon as this spec and the board entry are on
  the branch, since both are inside its allow-list). **AC20 carries no `check:`
  by design** and is reported `SKIP` by `bin/check-acs.sh`. The other eleven fail
  before the change and are what prove it happened. **pm-spec has no shell in
  this role, so no `check:` line below was executed** — the executing side runs
  all nineteen live against the pre-implementation tree, corrects any line that
  is broken as a command or would pass vacuously (meaning preserved), corrects
  this disclosure, and only then freezes the intent hash.
- **A criterion states the boundary of what it proves.** These criteria prove
  that no forbidden token survives on a shipped surface, that the protected bytes
  are unchanged, that regeneration produced the shipped files, and that the diff
  is confined. They prove **nothing** about whether an English sentence reads
  well, and only partially about whether it is true in an arbitrary adopter
  repository — the residual judgment there belongs to the cross-provider review
  (scope (a) of its brief).

### The three fields' replacement text, frozen

The `Rule` is the only shipping surface (`Why` and `How to apply` are never
injected — `.shell-team/lessons.md:25`), but all three must be true for a human
reading the corpus. Hard constraints on all three: **no CI claim in the present
tense about this or any repository, no step name from any workflow file, the
linter named by its bare command, and the incident attributed rather than
named.**

The replacements are frozen **as clause-level substitutions**, not as whole-field
rewrites: for each field, the quoted old text is replaced by the quoted new text
and **every other byte of that field's line stays exactly as it is on
`develop`**. Stated this way on purpose — a whole-field restatement inside this
spec would have to re-escape the field's own nested backticks, and a transcription
slip there would silently rewrite text this task has no business changing.

| Field | Replace this exact text | With this exact text |
|---|---|---|
| `Rule` | `is a format mismatch that fails the board-lint CI step.` | ``is a format mismatch the hand-off linter (`check-handoff.sh`) rejects.`` |
| `Why` | `and CI's board-lint step failed on the very next push and pull-request trigger for the same commit — both fired the same lint rule.` | `and the hand-off linter rejected the board on the very next push and pull-request trigger for the same commit — both triggers fired the same rule. That linter ran over the live board automatically in the repository where the incident happened; whether any given repository automates it that way is its own workflow's decision.` |
| `How to apply` | `run the board linter locally before committing (the same check CI runs).` | ``run the hand-off linter locally before committing — `check-handoff.sh <board path>` — whether or not your own automation runs it too.`` |

Every em dash above is U+2014, matching the ones already in those fields.

Three mechanical consequences the criteria below rely on. **After the
substitutions, none of the three field lines contains the two-character sequence
`CI`** — which is what lets one simple rule (zero `CI` in the entry block, zero
on the shipped `Rule` line) cover all of them with no special cases. **`board-lint`
disappears from all three.** **The attribution phrase `the repository where the
incident happened` lands lower-case mid-sentence**, so AC8 can require it with a
case-sensitive `grep -F`. Each field remains a single physical line, which is why
AC9 pins the corpus diff at three added and three deleted lines.

### Group A — `docs/workflow.md` and `docs/workflow.ja.md`

- [ ] **AC1** **Neither language variant asserts a branch naming form, and both
  keep the content the section is the only home for.** In each file's conventions
  section: zero occurrences of `feat/T-`; the worktree opt-in content still
  present; a pointer to `CONTRIBUTING.md` present (the naming convention lives
  there, once). The section extraction is asserted non-empty in both files, so a
  renamed heading cannot make this pass by finding nothing.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=1; sect() { awk -v h="$2" 'index($0, h) == 1 { f = 1; next } f && /^## / { exit } f { print }' "$1"; }; sect docs/workflow.md '## Conventions' > "$F/en"; sect docs/workflow.ja.md '## 規約' > "$F/ja"; for s in "$F/en" "$F/ja"; do test "$(grep -c . "$s")" -ge 5 || ok=0; test "$(grep -cF 'feat/T-' "$s")" -eq 0 || ok=0; grep -qF 'worktree' "$s" || ok=0; grep -qF 'CONTRIBUTING.md' "$s" || ok=0; done; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC2** **Both variants name the spec and review directories through the
  resolver, not through one layout's literals.** In each conventions section:
  zero occurrences of `docs/specs/` and zero of `tasks/reviews/`; both resolver
  invocations `team-paths.sh --get specs` and `team-paths.sh --get reviews`
  present; the `T-XXX` filename placeholder still present as the positive control
  that the bullets still say what a spec and a review artefact are called.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=1; sect() { awk -v h="$2" 'index($0, h) == 1 { f = 1; next } f && /^## / { exit } f { print }' "$1"; }; sect docs/workflow.md '## Conventions' > "$F/en"; sect docs/workflow.ja.md '## 規約' > "$F/ja"; for s in "$F/en" "$F/ja"; do test "$(grep -c . "$s")" -ge 5 || ok=0; grep -qF 'T-XXX' "$s" || ok=0; grep -qF 'team-paths.sh --get specs' "$s" || ok=0; grep -qF 'team-paths.sh --get reviews' "$s" || ok=0; test "$(grep -cF 'docs/specs/' "$s")" -eq 0 || ok=0; test "$(grep -cF 'tasks/reviews/' "$s")" -eq 0 || ok=0; done; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC3** **The two language variants' conventions sections carry the same
  five bullets.** The Japanese section has four today and is missing the PR-body
  diff-stats bullet — a pre-existing divergence inside a section this task is
  rewriting anyway, disposed of explicitly (DP-3) rather than shipped knowingly.
  Both counts are pinned to five and to each other, so adding a sixth bullet to
  one file fails as loudly as omitting one.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; sect() { awk -v h="$2" 'index($0, h) == 1 { f = 1; next } f && /^## / { exit } f { print }' "$1"; }; { sect docs/workflow.md '## Conventions' > "$F/en" && sect docs/workflow.ja.md '## 規約' > "$F/ja" && e="$(grep -cE '^- \*\*' "$F/en")" && j="$(grep -cE '^- \*\*' "$F/ja")" && test "$e" -eq 5 && test "$j" -eq 5 && test "$e" = "$j"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC4** **What was measured accurate survives, in both variants.**
  Two-sided invariant lock. `docs/workflow.md` still carries the
  `## Phase boundaries` and `## Hand-off contract` sections — the two things
  `CONTRIBUTING.md:102` promises a reader will find here, and the exact shape of
  miss #30's fourth acceptance bullet names; its conventions section still
  carries the PR-body-diff-stats bullet (`git diff --stat`) and the
  `.claude/agents/*` bullet; and both files still have the same number of
  top-level sections (seven each), so a rewrite cannot silently drop or merge one.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; sect() { awk -v h="$2" 'index($0, h) == 1 { f = 1; next } f && /^## / { exit } f { print }' "$1"; }; { test -s docs/workflow.md && test -s docs/workflow.ja.md && grep -qE '^## Phase boundaries' docs/workflow.md && grep -qE '^## Hand-off contract' docs/workflow.md && sect docs/workflow.md '## Conventions' > "$F/en" && grep -qF 'git diff --stat' "$F/en" && grep -qF '.claude/agents/*' "$F/en" && e="$(grep -cE '^## ' docs/workflow.md)" && j="$(grep -cE '^## ' docs/workflow.ja.md)" && test "$e" -eq 7 && test "$j" -eq 7; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC5** **The branch form is measured against this repository's own history
  at the fix commit, and zero merged branches use the `feat/` type.** Measured
  from merge-commit subjects, git only (no `gh`, so it runs in a sandbox): strip
  `from <owner>/` off each `Merge pull request … from <owner>/<branch>` subject
  and take the segment before the first `/`. **Stated limitation: this sees only
  pull requests merged with a merge commit** — a squash or rebase merge leaves no
  subject to parse, so the histogram is a lower bound on the branch population and
  is honest about being one. Positive controls: at least five subjects parse, and
  at least one resolves to the `feature` type, so an extraction that collapsed to
  nothing cannot report zero `feat/`. The engineer records the full measured
  histogram in the hand-off; the numbers are **not** copied from the issue's
  2026-07-29 measurement.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; { git log --merges --format=%s develop > "$F/subj" && test -s "$F/subj" && grep -oE 'from [^/]+/[^ ]+' "$F/subj" | sed -e 's|^from [^/]*/||' > "$F/br" && sed -e 's|/.*||' "$F/br" | sort > "$F/types" && test "$(grep -c . "$F/types")" -ge 5 && test "$(grep -cx 'feature' "$F/types")" -ge 1 && test "$(grep -cx 'feat' "$F/types")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

### Group B — the corpus entry and the shipped surfaces it generates

- [ ] **AC6** **The entry's key is byte-locked.** Two-sided invariant lock,
  compared for **equality** against the same anchored extraction from the base
  ref rather than by containment: the `2026-06-17` board-format heading in
  `.shell-team/lessons.md` is byte-identical to `git show 0906862:` of the same
  file, and exactly one line matches the anchor on each side. This is what keeps
  the disposition ledger's destination for that row valid with no ledger edit,
  and what makes an in-place correction distinguishable from a supersession.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; L=.shell-team/lessons.md; { test -s "$L" && git show 0906862:"$L" > "$F/base.md" && test -s "$F/base.md" && grep -E '^## 2026-06-17 .*The board' "$L" > "$F/now" && grep -E '^## 2026-06-17 .*The board' "$F/base.md" > "$F/was" && test "$(grep -c . "$F/now")" -eq 1 && test "$(grep -c . "$F/was")" -eq 1 && cmp -s "$F/now" "$F/was"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC7** **Only the three prose fields changed inside the entry.** The
  entry block is extracted from the working tree and from the base ref; with the
  `Rule`, `Why` and `How to apply` bullets filtered out, the two are
  byte-identical — so the heading, `Category`, `Applies-to`, `Scope`, `Status`
  and `Source` are all provably untouched, and `Applies-to: pm-spec, engineer`
  in particular has not widened. Each of the three prose bullets is asserted
  present on both sides **and** different, so a criterion that found nothing
  cannot pass and neither can a no-op edit. Both blocks are asserted to hold at
  least nine non-empty lines (heading plus eight field bullets).
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; L=.shell-team/lessons.md; blk() { awk 'f && /^## / { exit } /^## 2026-06-17 .*The board/ { f = 1 } f { print }' "$1"; }; { test -s "$L" && git show 0906862:"$L" > "$F/base.md" && test -s "$F/base.md" && blk "$L" > "$F/now" && blk "$F/base.md" > "$F/was" && test "$(grep -c . "$F/now")" -ge 9 && test "$(grep -c . "$F/was")" -ge 9 && grep -vE '^- \*\*(Rule|Why|How to apply)\*\*: ' "$F/now" > "$F/now.meta" && grep -vE '^- \*\*(Rule|Why|How to apply)\*\*: ' "$F/was" > "$F/was.meta" && test "$(grep -c . "$F/now.meta")" -ge 6 && cmp -s "$F/now.meta" "$F/was.meta" && bad=0; for k in Rule Why "How to apply"; do a="$(grep -F -- "- **$k**: " "$F/now")"; b="$(grep -F -- "- **$k**: " "$F/was")"; test -n "$a" || bad=1; test -n "$b" || bad=1; test "$a" != "$b" || bad=1; done; test "$bad" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC8** **The entry makes no CI claim, names the linter by its bare
  command, and attributes the incident instead of naming a repository.** Across
  the whole entry block: zero occurrences of the two-character sequence `CI` and
  zero of `board-lint`; `check-handoff.sh` present; the attribution phrase
  `the repository where the incident happened` present. The block is asserted to
  hold at least nine non-empty lines and a `Rule` bullet, which is the positive
  control that the extraction is looking at the real entry. **Boundary of what
  this proves**: the absence of the `CI` token is mechanical; that the `Why`'s
  narration reads as past tense, and that no *other* wording smuggles in a
  maintainer-environment assumption, is the cross-provider review's judgment
  (scope (a) of its brief) and qa-verifier's reading, not this exit code's.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; L=.shell-team/lessons.md; { test -s "$L" && awk 'f && /^## / { exit } /^## 2026-06-17 .*The board/ { f = 1 } f { print }' "$L" > "$F/blk" && test "$(grep -c . "$F/blk")" -ge 9 && grep -qF -- '- **Rule**: ' "$F/blk" && grep -qF 'check-handoff.sh' "$F/blk" && grep -qF 'the repository where the incident happened' "$F/blk" && test "$(grep -cF 'CI' "$F/blk")" -eq 0 && test "$(grep -cF 'board-lint' "$F/blk")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC9** **The corpus edit is three lines and nothing else, and the corpus
  is still schema-green.** `git diff --numstat` against the base ref reports
  exactly `3` added and `3` deleted for `.shell-team/lessons.md` — which pins in
  one comparison that no entry was added (a supersession would add a heading and
  its fields), none removed, and no other entry touched. `bin/check-playbook.sh`
  exits 0 at the resolver-derived path, which is both the schema gate and the
  positive control that the file is real and parseable.
  - check: test "$(git diff --numstat 0906862 -- .shell-team/lessons.md | awk '{ print $1 "/" $2 }')" = "3/3" && L="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)" && test -s "$L" && bash bin/check-playbook.sh "$L" >/dev/null

- [ ] **AC10** **All four shipped surfaces carry the corrected `Rule`, and none
  of them carries a CI claim.** In each of `templates/prompt-blocks/playbook-pm-spec.md`,
  `templates/prompt-blocks/playbook-engineer.md`, `agents/pm-spec.md` and
  `agents/engineer.md`: exactly **one** line matches the entry's anchor (the
  extraction's own positive control — the generated bullet carries the entry key
  as its attribution), that line contains `check-handoff.sh`, and it contains
  neither `CI` nor `board-lint`. Scoped to the anchored line rather than the whole
  file on purpose: other rules in the same blocks legitimately discuss CI.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=1; for f in templates/prompt-blocks/playbook-pm-spec.md templates/prompt-blocks/playbook-engineer.md agents/pm-spec.md agents/engineer.md; do test -s "$f" || { ok=0; continue; }; grep -E '2026-06-17 .*The board' "$f" > "$F/line"; test "$(grep -c . "$F/line")" -eq 1 || ok=0; grep -qF 'check-handoff.sh' "$F/line" || ok=0; test "$(grep -cF 'CI' "$F/line")" -eq 0 || ok=0; test "$(grep -cF 'board-lint' "$F/line")" -eq 0 || ok=0; done; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC11** **The claim is checked against the workflow as it stands,
  including what CI does not lint.** Two-sided invariant lock, four assertions:
  no shipped surface (`agents/`, `templates/`, `skills/`, `bin/`, and the corpus)
  carries this repository's real step name `Lint the shipped board template` —
  naming it in a shipped block would be the same defect one level up; that string
  **is** present in `.github/workflows/check-handoff.yml`, which is the positive
  control proving the pattern is real rather than a typo that matches nothing; no
  workflow step invokes `check-handoff.sh` against the live board (neither the
  resolver key nor the default-layout literal), so "no CI step lints this
  repository's board" is measured rather than remembered; and
  `CONTRIBUTING.md` still says so in prose. All four directories and both files
  are asserted present first.
  - check: test -d agents && test -d templates && test -d skills && test -d bin && test -s .shell-team/lessons.md && test -s .github/workflows/check-handoff.yml && test -s CONTRIBUTING.md && test "$(grep -rlF 'Lint the shipped board template' agents templates skills bin .shell-team/lessons.md | wc -l | tr -d ' ')" -eq 0 && grep -qF 'Lint the shipped board template' .github/workflows/check-handoff.yml && grep -qF 'bash bin/check-handoff.sh templates/todo-template.md' .github/workflows/check-handoff.yml && test "$(grep -cE 'check-handoff\.sh .*(--get todo|\.shell-team/todo\.md)' .github/workflows/check-handoff.yml)" -eq 0 && grep -qF 'nothing lints the board this repository runs on' CONTRIBUTING.md

- [ ] **AC12** **The shipped surfaces were regenerated, not hand-edited.**
  Two-sided invariant lock. Regenerating into a scratch root from the resolved
  corpus reproduces all four canonical blocks and all four consumers
  byte-identically, and `bin/check-prompt-sync.sh` exits 0. The file set is
  **derived from `templates/prompt-blocks/registry.txt`**, not written down, and
  pinned at eight entries so a derivation that collapsed to nothing cannot pass;
  the real tree is only read. A hand edit inside any marker region breaks the
  fixed point, which is exactly what the `Dogfood gen-playbook-blocks` CI step
  will also catch.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; { L="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)" && test -r "$L" && files="$(awk '$1 == "marker" && $2 ~ /^playbook-/ { for (i = 3; i <= NF; i++) print $i; print "templates/prompt-blocks/" $2 }' templates/prompt-blocks/registry.txt | sort -u)" && test "$(printf '%s\n' "$files" | wc -l | tr -d ' ')" -eq 8 && cpok=1; for f in $files; do mkdir -p "$F/repo/$(dirname "$f")" || cpok=0; cp "$f" "$F/repo/$f" || cpok=0; done; mkdir -p "$F/repo/templates/prompt-blocks" && cp templates/prompt-blocks/registry.txt "$F/repo/templates/prompt-blocks/registry.txt" && test "$cpok" -eq 1 && env -u TEAM_RUN_BASE bash bin/gen-playbook-blocks.sh --root "$F/repo" --lessons "$L" >/dev/null 2>&1 && bad=0; for f in $files; do cmp -s "$f" "$F/repo/$f" || bad=1; done; test "$bad" -eq 0 && bash bin/check-prompt-sync.sh >/dev/null; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC13** **The blast radius is exactly four files, and the other two roles'
  surfaces are byte-identical to the base ref.** The diff under
  `templates/prompt-blocks/` and `agents/` is exactly
  `agents/engineer.md`, `agents/pm-spec.md`,
  `templates/prompt-blocks/playbook-engineer.md`,
  `templates/prompt-blocks/playbook-pm-spec.md` — compared as a sorted set, so a
  fifth file fails as loudly as a missing one — and `playbook-qa-verifier.md`,
  `playbook-tech-lead.md`, `agents/qa-verifier.md` and `agents/tech-lead.md` each
  compare byte-identical against `git show 0906862:`. Regeneration rewrites all
  four blocks from the whole corpus, so this is the invariant to assert rather
  than assume; it is also what keeps `tests/codex-skeleton-hygiene/run.sh`'s
  live-file lock on `agents/qa-verifier.md` untouched. **Merge-point-scoped
  against `0906862` and expected to go stale after merge** — a later task's files
  will land on the same base ref; do not widen its base-ref resolution and do not
  re-derive it per rework round.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1009.XXXXXX")"; ok=0; { git diff --name-only 0906862 -- templates/prompt-blocks/ agents/ | sort > "$F/got" && printf '%s\n' agents/engineer.md agents/pm-spec.md templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-pm-spec.md | sort > "$F/want" && cmp -s "$F/got" "$F/want" && bad=0; for f in templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md agents/qa-verifier.md agents/tech-lead.md; do git show 0906862:"$f" > "$F/b" || bad=1; test -s "$F/b" || bad=1; cmp -s "$F/b" "$f" || bad=1; done; test "$bad" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

### Shared — hygiene, scope and the sweep

- [ ] **AC14** **The false-claim vocabulary is gone from every operational file,
  and the grep that says so is proven to be reading them.** Zero occurrences of
  `board-lint`, of `Lint tasks/todo.md`, and of `the same check CI runs` across
  `agents/ templates/ skills/ bin/`. **Deliberately scoped to those four
  directories, never repository-wide**: a repository-wide grep would false-positive
  on this spec's own body, on `.shell-team/specs/T-1000-operating-conventions.md`
  and on six rounds of carry-forward in `.shell-team/reviews/T-1000.md` — a spec,
  a review and a board are allowed to discuss the defect they exist to remove.
  Positive control: at least two files under those directories are found to
  contain `check-handoff.sh`, so the same recursive grep demonstrably reads the
  tree it is asserting emptiness over.
  - check: test -d agents && test -d templates && test -d skills && test -d bin && test "$(grep -rlF 'check-handoff.sh' agents templates skills bin | wc -l | tr -d ' ')" -ge 2 && test "$(grep -rlF 'board-lint' agents templates skills bin | wc -l | tr -d ' ')" -eq 0 && test "$(grep -rlF 'Lint tasks/todo.md' agents templates skills bin | wc -l | tr -d ' ')" -eq 0 && test "$(grep -rlF 'the same check CI runs' agents templates skills bin | wc -l | tr -d ' ')" -eq 0

- [ ] **AC15** **Everything that points at either changed file still tells the
  truth.** Two-sided invariant lock covering #30's fourth acceptance bullet
  ("#25 removed a section and left a pointer in another file naming it"):
  `CONTRIBUTING.md` still names `docs/workflow.md` as where phase boundaries and
  the hand-off contract are documented and both sections still exist there (AC4
  pins the sections; this pins the pointer); `README.md` and `README.ja.md` both
  still point at `docs/workflow.md` for the hand-off contract, and the target
  exists.
  - check: test -s CONTRIBUTING.md && test -s README.md && test -s README.ja.md && test -s docs/workflow.md && grep -qF '[`docs/workflow.md`](docs/workflow.md)' CONTRIBUTING.md && grep -qF 'phase boundaries and the hand-off' CONTRIBUTING.md && grep -qF '[docs/workflow.md](docs/workflow.md)' README.md && grep -qF '[docs/workflow.md](docs/workflow.md)' README.ja.md && grep -qE '^## Hand-off contract' docs/workflow.md

- [ ] **AC16** **Nothing under `bin/` changed, and the two suites that lock
  generated content stay green.** Two-sided invariant lock: the diff under `bin/`
  against the base ref is empty (H2 — `tests/errexit-safe/run.sh` pins
  `bin/gen-playbook-blocks.sh` by `file:line:content`, and no `bin/` edit is
  needed for this task); `tests/errexit-safe/run.sh` is itself unchanged and
  exits 0; and `tests/codex-skeleton-hygiene/run.sh`, which live-file-locks
  `agents/qa-verifier.md`, exits 0 after regeneration.
  - check: test -z "$(git diff --name-only 0906862 -- bin/)" && test -z "$(git diff --name-only 0906862 -- tests/errexit-safe/run.sh)" && bash tests/errexit-safe/run.sh >/dev/null && bash tests/codex-skeleton-hygiene/run.sh >/dev/null

- [ ] **AC17** **The task's mandatory records exist and conform, and the board is
  clean.** `.shell-team/provenance/T-1009.md` and
  `.shell-team/interventions/T-1009.md` both pass their checkers (every prior task
  ships both); the board passes the hand-off linter at the resolved path; and
  `bin/check-board-headings.sh --base develop` passes, which is the only check
  that notices a `T-NNN` id deleted, overwritten or duplicated by this task's
  insertion (H9).
  - check: bash bin/check-provenance.sh .shell-team/provenance/T-1009.md >/dev/null && bash bin/check-interventions.sh .shell-team/interventions/T-1009.md >/dev/null && T="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get todo)" && test -s "$T" && bash bin/check-handoff.sh "$T" >/dev/null && bash bin/check-board-headings.sh "$T" --base develop >/dev/null

- [ ] **AC18** **The shape-level PII and commit-identity gates are green over a
  change set that actually contains this task's files.** Both CI gates run on the
  PR diff, and the corpus rewording plus two document rewrites must introduce no
  personal-name, hostname or employer-name shape (H7). Without the second half
  this would be the vacuous "green before the work started" assertion: the change
  set is required to contain `.shell-team/lessons.md`, `docs/workflow.md` and
  `docs/workflow.ja.md`.
  - check: bash bin/check-pii-shapes.sh --base develop >/dev/null && bash bin/check-commit-identity.sh --base develop >/dev/null && test "$(git diff --name-only develop -- .shell-team/lessons.md docs/workflow.md docs/workflow.ja.md | wc -l | tr -d ' ')" -eq 3

- [ ] **AC19** **The diff is confined to this task's allow-list.** Every changed
  path is on the list below and the diff is non-empty. The list carries the
  task's certain deliverables **from the start** (playbook lesson 2026-07-22) —
  this spec, the board, the provenance record, the review record and the
  interventions file — plus `.shell-team/test-recipe.md` as *permitted, not
  required*, because `CLAUDE.md` standing instruction is to append a procedure
  the task establishes. **No `bin/` path is on the list** (H2), and neither is
  the ledger, the workflow file, `docs/templates/retro-template.md`, any frozen
  T-1000/T-1008 record, `CHANGELOG.md` or `CONTRIBUTING.ja.md` — so each of this
  task's non-goals fails the lock rather than relying on restraint.
  **Merge-point-scoped against `0906862` and expected to go stale after merge**;
  do not widen or re-derive it.
  - check: L="$(git diff --name-only 0906862)"; test -n "$L" && test "$(printf '%s\n' "$L" | grep -vcE '^(\.shell-team/lessons\.md|templates/prompt-blocks/playbook-(pm-spec|engineer)\.md|agents/(pm-spec|engineer)\.md|docs/workflow\.md|docs/workflow\.ja\.md|\.shell-team/todo\.md|\.shell-team/test-recipe\.md|\.shell-team/specs/T-1009-doc-drift-and-false-ci-claim\.md|\.shell-team/provenance/T-1009\.md|\.shell-team/reviews/T-1009\.md|\.shell-team/interventions/T-1009\.md)$')" -eq 0

- [ ] **AC20** **The pointer sweep is re-run at fix time and recorded as
  commands and counts, not as a prose claim.** **Process, deliberately not an
  exit code**: the property is that a *fresh* sweep was performed on the tree as
  it stands, and no command can prove that a command was run. Required, in the
  board hand-off and in `.shell-team/provenance/T-1009.md`: the literal grep
  command strings used and their hit counts, covering at minimum the tokens
  `feat/T-`, `docs/specs/`, `tasks/reviews/`, `board-lint`,
  `Lint tasks/todo.md`, `the same check CI runs` and `docs/workflow.md`; and for
  every hit **outside** this task's allow-list, the classification from the table
  in "Pointer sweep" below, re-verified rather than copied. qa-verifier
  independently re-runs the same greps and audits the classification instead of
  trusting the reported counts (playbook lesson 2026-07-19).

## Input space

**Reachable input classes** — what real usage produces, and what this change must
therefore be correct about.

1. **The corpus entry exactly as it stands on `0906862`**: one `## <date> — <title>`
   heading whose separator is U+2014, followed by eight single-line field bullets
   in the order `Category`, `Applies-to`, `Scope`, `Status`, `Source`, `Rule`,
   `Why`, `How to apply`. No `Bound-in`, no `Superseded-by`, no `Extended by`.
   Nothing else in the 74-entry corpus is read or written by this task.
2. **Prose field values containing the punctuation this repository's own corpus
   already uses**: backticked code fragments, a nested backticked example line
   (`` - [ ] **T-NNN** … — `<FLAG>` — spec: … ``), em dashes, double-quoted
   phrases, and parentheses. The generator splices a `Rule` verbatim into a
   markdown bullet, so the corrected text must survive that splice unchanged —
   which is the property AC10 and AC12 measure together.
3. **A regeneration pass over the whole corpus, not just the edited entry.**
   `bin/gen-playbook-blocks.sh` rewrites all four blocks and all four consumers
   from every `Scope: loop` + `Status: active` entry. The two roles this entry
   does not apply to are therefore in the input space of the run even though they
   are outside the intended change, which is why their byte-identity is an
   assertion (AC13) rather than an assumption.
4. **Both layouts and both hosts.** The corpus is reached through
   `bin/team-paths.sh --get lessons`; the regeneration probe additionally passes
   `--lessons <resolved path>`, which short-circuits the resolver so the probe
   behaves identically on a legacy-layout host. Local macOS/BSD userland (where
   `mktemp` needs an explicit template and `grep -P` does not exist) and CI's
   ubuntu/GNU userland must both hold.
5. **Two human-facing markdown variants of one document**, one English and one
   Japanese, whose conventions sections are the last section in the file (so a
   section extraction runs to EOF) and which today disagree in bullet count.
6. **This repository's merge history as reachable from `develop` at the fix
   commit**: `Merge pull request #N from <owner>/<type>/<slug>` subjects, where
   the slug itself may contain further `/` characters and the type set is open
   (`docs`, `chore`, `feature` observed). Both the "at least five parse" and the
   "at least one is `feature`" controls are grounded in that history.

**Out-of-scope synthetic extremes** — named and declined.

1. **A corpus entry whose field value spans multiple physical lines, whose
   bullets are reordered, or whose heading separator is not U+2014.**
   `bin/check-playbook.sh`'s declared surface, covered by its own suite. The
   edited entry keeps one line per field, and AC7 proves the non-prose lines never
   moved.
2. **Adversarial corpus content designed to escape the prompt-block marker
   region** — a forged `<!-- BEGIN prompt-block: … -->` string, NUL bytes, CRLF
   endings, non-UTF-8 bytes, or a reserved marker string inside a field value.
   That threat model belongs to the generator's own task history; this task adds
   no parsing.
3. **Ever-longer replacement wordings, or an entry count large enough to change
   prompt-size behaviour.** `bin/gen-playbook-blocks.sh`'s
   `LINE_WARN_THRESHOLD=40` warning **already fires on `develop`** (H4) and an
   in-place edit changes the block's line count by zero. Tuning the threshold, or
   pinning its stderr text, is explicitly not this task's business.
4. **A merge history with no merge commits at all, or branch slugs crafted to
   break the histogram parser.** AC5's method is declared as merge-commit-only
   and as a lower bound; it is measured against this repository's real history at
   the fix commit and makes no claim about a repository that squash-merges
   everything.
5. **An adopter repository whose CI does, or does not, lint its own board.** The
   corrected wording makes no claim in either direction by design, and no
   criterion here can observe an adopter's workflow. This is the boundary the
   whole task exists to establish, so it is declined deliberately rather than for
   convenience.
6. **Non-Latin or full-width content in the replacement text.** The corpus is
   English-only by T-1008's byte rule; `docs/workflow.ja.md` is a human-facing
   translation and is the one file where Japanese prose is correct.
7. **Other translated variants.** No `.ja.md` of any other file in this task's
   scope exists, and `CONTRIBUTING.ja.md` is deliberately absent — creating one
   fails AC19.
8. **The ~30 hardcoded legacy-path hits in other shipped role prompts and
   checker comments.** Real, same-class, and a different task's input space; AC19
   makes touching any of them a failure here.

<!-- END intent-block: T-1009 -->

## Resolved design decisions

### DP-1 — in-place edit, not supersession; the key stays byte-identical; the ledger is not touched

The entry is corrected **in place**, its heading left byte-unchanged (AC6), and
`docs/loop-engineering/lessons-import-disposition.md` is not edited in either
direction.

**Recorded measurement, not an assumption: nothing on the merged tree enforces
ledger⇄corpus key equality.** No `bin/` script names the ledger; no CI step reads
it — the two corpus-facing dogfood steps are `Dogfood check-playbook` (schema
only) and `Dogfood gen-playbook-blocks` (regeneration equality only), and neither
sees it. Its only references are non-executable: T-1008's frozen spec, that
task's provenance and review records, and the corpus's own prose paragraph at
`.shell-team/lessons.md:27`.

So supersession would break no machine check — which is precisely why it is the
wrong choice. It would silently invalidate the ledger's only human-readable
mapping with nothing to catch it, leaving the retained row's destination pointing
at a key whose entry is now `superseded`.

**Independent grounding in the corpus's own semantics** (`.shell-team/lessons.md:29`):
`Superseded-by` names "the `active` entry that now covers its ground". Here the
ground is unchanged — "don't wedge a note between the flag and `— spec:`" is
still the rule. What is wrong is a supporting factual claim about *where the
check runs*. Using the retirement pointer for an erratum would misuse the
pointer, leave the false sentence in the tree forever inside a `superseded` entry
a human still reads, add a corpus key that is no import row's destination, and
duplicate the rule.

**No ledger annotation either.** The ledger's stated contract is per-row
disposition of the *import* (`…:37` "Columns: source date, per-date sequence,
outcome, one-line reason, destination"; `:29` "A retained row's destination is the
corpus entry key it became"). Nothing that column asserts becomes false. The
ledger is not an edit log, and adding a sixth column would change a documented
five-column contract to record a fact it does not claim to record. The
edit-history channel this repository already has is
`.shell-team/provenance/T-1009.md`, and that is where the decision and its
grounding go.

**Premise correction to issue #30 §2, recorded so the engineer does not reach for
the wrong tool.** The issue says the fix "changes through `bin/playbook-promote.sh`
and a regeneration". It does not: `playbook-promote.sh` **appends** a
human-approved candidate; it is not the tool for correcting an existing entry.
The path is hand-edit `.shell-team/lessons.md` → `bash bin/gen-playbook-blocks.sh`
→ `bash bin/check-prompt-sync.sh`.

Also stale in the same section: the four-file inventory naming the literal
`Lint tasks/todo.md`. T-1008 removed that literal (zero hits, measured
2026-07-31). The four files are still the four shipped surfaces, but the string
to remove is the softer translated wording, which is why every criterion here
anchors on the entry key rather than on the old literal.

### DP-2 — the corrected claim names the linter by its distributed command and makes no CI claim at all

The CI claim is dropped from all three prose fields. The checker is named by its
**bare command**, `check-handoff.sh`.

**Grounding.** Naming *this* repository's real step
(`Lint the shipped board template (hand-off linter)`) inside a shipped block
would be the identical defect one level up — a shipped rule asserting a fact
about the maintainer's CI inside an adopter's agent prompt. The plugin ships no
workflow file, so **no CI claim about an adopter's repository can ever be true by
construction**, and the North Star lesson *don't coerce the adopter's
environment* forbids making one. Bare-name reference is already the shipped
precedent — `templates/prompt-blocks/language.md` says "grepped by
`check-handoff.sh` / `goal-state.sh` / `check-acs.sh`", with no `bin/` prefix and
no CI — and `CLAUDE.md` §Dogfood states why ("`bin/` is on `PATH`. Call scripts
by bare name"). The environment-neutral phrasing to model is already in the tree
at `CONTRIBUTING.md:86`.

The historical fact is preserved rather than deleted: `Why` narrates a real
incident in a repository whose CI *did* lint its live board. Past-tense,
attributed narration is true; the present-tense generalisation is not. Only the
`Rule` is a shipping surface (`Why` and `How to apply` are never injected), but
all three must be true for a human reading the corpus, which is why AC8 covers
the whole entry block.

**Rejected option, named explicitly**: adding a CI step that lints this
repository's own board to make the old claim true. It would not fix the shipped
block, it is scope creep against the sprint goal, and the local-lint duty is
already documented. → out of scope; filed as a fast-follow candidate at the
recording step.

### DP-3 — the whole `## Conventions` section is re-measured, fixed by pointer rather than by literal, and both language variants change together

Measured on `0906862`, whole file read; the drift is confined to lines 98–104.

| Site | Current | Verdict | Fix direction |
|---|---|---|---|
| `docs/workflow.md:100` | `feat/T-XXX-<slug>` | drifted — zero occurrences of `feat/T-` anywhere outside this file, its `.ja` twin, one fixture and frozen T-1000 records | keep the loop-relevant content (feature branch, worktrees on opt-in); assert **no** naming form; point at `CONTRIBUTING.md` for this repository's `<type>/<slug>` convention |
| `docs/workflow.md:101` | `docs/specs/T-XXX-<slug>.md` | drifted — hardcodes the legacy layout | `<specs dir>/T-XXX-<slug>.md`, resolved with `team-paths.sh --get specs` |
| `docs/workflow.md:102` | `tasks/reviews/T-XXX.md` ×2 | drifted, same class | `<reviews dir>/T-XXX.md` plus traces, resolved with `team-paths.sh --get reviews` |
| `docs/workflow.md:103` (PR body diff stats) | — | accurate | keep |
| `docs/workflow.md:104` (never edit `.claude/agents/*`) | — | accurate | keep |
| `docs/workflow.md:19`, `:40`, `:43`, `:89` | — | accurate (`<specs dir>` placeholder; both skills exist; canonical Codex form matches `agents/codex-reviewer.md`) | no change |

Both resolver keys are verified present in `bin/team-paths.sh`. Asserting *any*
branch naming form in an adopter-facing document is wrong — `README.md:164` links
this file — and restating this repository's own form here would create the second
copy `CLAUDE.md` forbids.

**`docs/workflow.ja.md` is fixed in the same change** (`:98`–`:100` carry the
identical three drifts). A stale translation is exactly the miss `CLAUDE.md`
§Language warns about.

**The measured divergence, disposed of rather than left unmeasured**: `## 規約`
has **4** bullets while `## Conventions` has **5** — the Japanese file is missing
the PR-body-diff-stats bullet. **Decision: include it** (AC3). It is one bullet
inside a section already being rewritten, it is the same defect class as the
drift itself (a reader of one variant gets a different contract), and excluding
it would mean knowingly shipping the divergence. The bullet count is pinned at
five on both sides so the parity cannot silently break again in either
direction.

### DP-4 — one task, two independent AC groups

One task, one spec, one branch, one intent freeze — with the criteria organised
into **Group A** (`docs/workflow.md` + `.ja.md`), **Group B** (the corpus entry
and the surfaces it generates) and **Shared**, so a rework round can be scoped to
one half.

**Grounding**: a shared tracker (#30), a shared sprint slot, and the one shared
cause the issue itself states. The two halves touch **disjoint files** and have
**no ordering dependency**. #30's fourth acceptance bullet — the pointer sweep —
spans both and cannot be split without doing it twice. Splitting would duplicate
the entire fixed cost (two specs, two freezes, two provenance records, two review
records, two Codex cycles) for roughly ten changed lines.

**Task classification, stated so spec-review rigour is calibrated rather than
guessed** (playbook lesson 2026-07-12): neither half writes or extends a
verification mechanism. Both are content edits following the pattern T-1007 and
T-1008 established, and every checker involved already exists and stays
untouched. The long-running class does not apply, so ordinary spec-review rigour
is right — the one place this task is genuinely exposed is the self-hosting
negative grep (H6), which the standing rules above address directly.

## Pointer sweep — measured on `0906862`, classified

The engineer re-runs this at fix time and records the command strings and hit
counts (AC20); the table is this spec's own restatement of the classification, to
be re-verified rather than copied.

| Site | Hits | In/Out | Reason |
|---|---|---|---|
| `docs/workflow.md:100–102` | 3 | **IN** | the drift itself |
| `docs/workflow.ja.md:98–100` | 3 | **IN** | stale translation of the same drift |
| `.shell-team/lessons.md:121,122,123` | 3 | **IN** | the false claim's source of truth |
| `templates/prompt-blocks/playbook-pm-spec.md:4`, `playbook-engineer.md:8` | 2 | **IN** (generated) | rewritten by regeneration, never by hand |
| `agents/pm-spec.md:88`, `agents/engineer.md:72` | 2 | **IN** (generated) | same |
| `CONTRIBUTING.md:102` | 1 | **OUT — verified still true** | promises `docs/workflow.md` documents "phase boundaries and the hand-off contract"; both sections survive the rewrite (AC4 + AC15). This is the exact shape of miss #30's fourth bullet names, so the check is required even though the answer is "no change" |
| `README.md:164`, `README.ja.md:164` | 2 | **OUT — verified still true** | "See `docs/workflow.md` for the hand-off contract and shortcuts"; both survive (AC15) |
| `docs/adopting.md`, `docs/adopting.ja.md`, `docs/distribution.md`, `docs/distribution.ja.md` | 4 | **OUT** | legitimately describe the legacy layout as *detected and reused*, not as the convention |
| `.shell-team/reviews/T-1000.md` (×7), `.shell-team/specs/T-1000-operating-conventions.md` (×9), `.shell-team/todo.md` (×2) | ~18 | **OUT — frozen records** | merged records of *why* both sites were deliberately left. `T-1000-…md:298`'s `check:` requires both drifts to still be present and is **already false** since T-1008 removed the literal it greps — stale by design, re-run by no CI step; do **not** repair it |
| `docs/templates/retro-template.md` | 1 | **OUT** | illustrative example inside a template, not a convention statement |
| `tests/check-handoff/fixtures/valid.md:10` (`branch feat/T-100`) | 1 | **OUT** | fixture in the reserved id range; fixtures follow their own rules (`CLAUDE.md` §Task IDs) |
| `agents/drift-evaluator.md`, `agents/codex-reviewer.md`, `agents/scrum-master.md`, `agents/pm-spec.md` (non-generated prose), `skills/run/SKILL.md`, `templates/*.yaml`, `bin/check-acs.sh`, `bin/check-intent.sh`, `bin/check-provenance.sh` | ~30 | **OUT — file a fast-follow** | genuine same-class defect (hardcoded legacy paths in shipped prompts and checker comments) but a far larger surface than #30's two sites — seven role definitions and four checkers. Candidate title: *"Shipped role prompts and checker comments hardcode the legacy `tasks/` layout instead of resolving through `team-paths.sh`"* |
| `bin/*.sh` header comments naming `tasks/lessons.md` | ~15 | **OUT** | comment-level provenance markers; folded into the same fast-follow |
| `bin/team-paths.sh:108` ("the board linter") | 1 | **OUT** | accurate — describes resolver/linter grammar agreement, makes no CI claim, and does not contain the token `board-lint` |
| `CHANGELOG.md`, `CHANGELOG.ja.md` | — | **OUT** | per-release, not per-task; belongs to the release work |

## Body-to-AC correspondence

| Body directive | Promoted to |
|---|---|
| The corpus entry is corrected in place; the heading stays byte-identical | AC6 |
| No supersession; no new corpus key enters | AC9 (a supersession adds a heading and its fields, so `3/3` fails), AC19 |
| The disposition ledger is not edited in either direction | AC19 (the ledger is not on the allow-list) |
| Only `Rule`, `Why` and `How to apply` change inside the entry | AC7, AC9 |
| `Applies-to`, `Scope`, `Status`, `Category`, `Source` are untouched | AC7 |
| Nothing else in the corpus changes | AC9 |
| The corpus stays schema-green at the resolved path | AC9 |
| No field claims a CI step in the present tense about this or any repository | AC8 (entry block), AC10 (shipped `Rule` line) |
| The linter is named by its bare distributed command | AC8, AC10 |
| No step name from any workflow appears on a shipped surface | AC11, AC14 |
| The incident stays attributed to "the repository where the incident happened", never named | AC8 (phrase required present), AC18 (a name shape reds the PII gate) |
| The `Why`'s narration is past tense | AC8 (stated boundary: the token-level half is mechanical; the tense reading is qa-verifier's and the review's) |
| The corrected wording is true in an arbitrary adopter repository | AC8, AC10, AC11 as far as it is mechanically observable (no CI token, no step name, bare command). The residual semantic judgment is **info-only (not promoted to AC)** — no command can decide whether a sentence smuggles in an environment assumption; it is scope (a) of the cross-provider review's brief, which is a gate rather than a criterion |
| The correction reaches the blocks through the generator, never by hand | AC12 |
| `bin/check-prompt-sync.sh` stays green | AC12 |
| Exactly four files change under `templates/prompt-blocks/` and `agents/` | AC13 |
| The qa-verifier and tech-lead blocks and consumers are byte-identical | AC13 |
| `docs/workflow.md` asserts no branch naming form | AC1 |
| The worktree opt-in content is kept | AC1 |
| Branch naming points at `CONTRIBUTING.md` instead of being restated | AC1 |
| Spec and review paths are written in resolver form | AC2 |
| The `.ja.md` twin is corrected too | AC1, AC2 (both operate on both files), AC19 (both are on the allow-list) |
| Both variants are corrected in the **same commit** | **info-only (not promoted to AC)** — a criterion evaluates a tree, not a commit boundary; AC1/AC2/AC3 make an uncorrected twin fail at every gate regardless of how the commits are cut |
| The Japanese section gains the missing fifth bullet | AC3 |
| The parts measured accurate survive | AC4 |
| `CONTRIBUTING.md`'s and both READMEs' promises stay true | AC4, AC15 |
| The branch form is measured at fix time, not copied from the issue | AC5, AC20 |
| Zero merged branches use the `feat/` type | AC5 |
| The measurement's merge-commit-only limitation is stated | AC5 (stated in the criterion's own body) |
| The pointer sweep is re-run at fix time with commands and counts recorded | AC20 |
| Every out-of-scope sweep hit is classified with a reason | AC20 (the table above is the classification to re-verify) |
| No `bin/` change; the `errexit-safe` pin does not move | AC16, AC19 |
| The `codex-skeleton-hygiene` live-file lock survives regeneration | AC16, AC13 |
| No CI step is added to lint this repository's board | AC11, AC19 (the workflow file is not on the allow-list) |
| Frozen T-1000 / T-1008 records are not repaired | AC19 |
| The ~30-hit legacy-path surface is not touched | AC19 |
| `CONTRIBUTING.ja.md` is not created; no `CHANGELOG` entry; no version bump | AC19 |
| The provenance and interventions records exist and conform | AC17 |
| The board line format and heading integrity hold | AC17 |
| The PII and commit-identity gates are green non-vacuously | AC18 |
| The two fast-follow candidates are filed at the recording step, not fixed here | **info-only (not promoted to AC)** — filing happens after the merge decision and produces no artefact in this task's tree, so no criterion here can observe it; AC19 is what makes *fixing* either one fail |
| The generator's pre-existing line-count warning is expected, not a regression | **info-only (not promoted to AC)** — asserting a warning's stderr text would pin output whose owner may legitimately change it, and the warning already fires on `develop`; AC12's fixed point is indifferent to it |
| An in-place edit keeps the rule at its date position in every block | **info-only (not promoted to AC)** — a consequence of AC6 + AC9 rather than a separate property; nothing in the corpus enforces chronological order, which is itself part of DP-1's grounding |

## Assumptions

- **Base ref `0906862`.** Every line number and count above was read there. AC13
  and AC19 pin against it and are expected to go stale after merge; AC6, AC7 and
  AC16 read it through `git show` / `git diff` against a commit object that
  persists, so they do not.
- **The corpus entry is unchanged since the 2026-07-31 measurement** — one
  heading, eight single-line field bullets, `Applies-to: pm-spec, engineer`,
  `Scope: loop`, `Status: active`, `Source: n/a`. If a re-measurement disagrees,
  AC7's "at least nine non-empty lines" and its field filter are the first things
  to re-pin, and re-pinning them is an intent change needing a ratified
  re-freeze.
- **The heading's separator is U+2014**, as written by
  `bin/playbook-promote.sh` and parsed by `bin/check-playbook.sh`. Every
  extraction here matches it with `.*` rather than typing it, so the assumption
  is load-bearing only for the corpus staying internally consistent.
  **Unverified by pm-spec (no shell in this role) — flagged for the executing
  side.**
- **`awk -v h=…` with `index($0, h) == 1` matches a multibyte heading by bytes**
  on both hosts, which is what makes the `## 規約` extraction work without a
  locale assumption. Flagged for live verification at the freeze.
- **`grep -rlF … <dir> <dir> <file> | wc -l` behaves identically on BSD and GNU
  grep** for the zero-match case (exit 1, empty output). AC11 and AC14 depend on
  it and each pairs it with a positive control over the same directories.
- **`git show <commit>:<path>` and `cmp -s` are available**, and `develop`
  resolves locally for AC18's `--base develop`, as it did for T-1006, T-1007 and
  T-1008.
- **`check-acs.sh`'s 120s per-check cap applies.** AC16 runs two whole suites,
  one of which (`codex-skeleton-hygiene`) is the largest in the repository;
  T-1008 measured it comfortably inside the cap on this host. If a slow host
  exceeds it, raise `CHECK_ACS_TIMEOUT` for the run rather than splitting the
  criterion.
- **The nine-plus merged pull requests reachable from `develop` all carry
  GitHub's default merge-commit subject.** AC5's parse depends on the
  `Merge pull request #N from <owner>/<branch>` shape, and its stated limitation
  is exactly this.
- **This task establishes no new test procedure**, so no
  `.shell-team/test-recipe.md` entry is required — the file is on AC19's
  allow-list as permitted-not-required only because `CLAUDE.md` standing
  instruction is to append a procedure if one is established.

## Open questions

None blocking. Two departures from the tech-lead routing map are recorded rather
than left implicit (the T-1007 DP-b precedent):

- **`.shell-team/test-recipe.md` is added to the scope-lock allow-list** as
  permitted-not-required. The routing map's list omits it. Grounding: `CLAUDE.md`
  §Truth sources instructs whoever runs the suites to "append procedures you
  establish", and a standing instruction that collides with a scope lock would
  otherwise force a ratified re-freeze mid-task for a one-line append. Nothing
  requires the file to change, and AC19 stays a lock rather than a mandate.
- **The exact replacement wordings are frozen in the spec body**, not left to the
  engineer. The routing map offered candidates and assigned the final text to
  pm-spec; freezing them verbatim in a table is how the "no CI claim" and
  "attributed, not named" constraints become checkable at all (AC8/AC10 depend on
  specific tokens being present and absent). Meaning is preserved from the
  routing map's candidates; the changes are the removal of every `CI` token from
  all three fields, so one mechanical rule covers them, and the lower-casing of
  the attribution phrase so a case-sensitive `grep -F` can require it.

## Notes for engineer

**Do the corpus first, then regenerate. Never the other way round.** Hazard H1:
`.github/workflows/check-handoff.yml`'s `Dogfood gen-playbook-blocks` step
regenerates into a scratch copy and `cmp -s`'s every registered block **and**
consumer. A hand edit to `templates/prompt-blocks/playbook-*.md` or to an
`agents/*.md` marker region is a hard CI failure, and AC12 fails the same way
locally.

**The nine hazards, measured, in the order they will cost you.**

1. **H1 — the regen-diff gate.** Above. Corpus first, then
   `bash bin/gen-playbook-blocks.sh`, then `bash bin/check-prompt-sync.sh`.
2. **H2 — `tests/errexit-safe/run.sh` pins `bin/gen-playbook-blocks.sh` by
   `file:line:content`.** No `bin/` edit is expected or needed here, and AC16
   asserts the diff under `bin/` is empty. If you conclude a `bin/` change *is*
   required, **STOP and escalate** — do not fix it quietly, because moving that
   file's line count moves a pin that is not on this task's allow-list.
3. **H3 — `tests/codex-skeleton-hygiene/run.sh` live-file-locks
   `agents/qa-verifier.md`.** Regeneration rewrites all four blocks from the
   whole corpus. Because the edited entry's `Applies-to` is `pm-spec, engineer`
   and is **not** changing, that file will come out byte-identical — but that is
   the invariant to assert (AC13 + AC16), not to assume.
4. **H4 — a pre-existing generator warning that is not a regression.**
   `LINE_WARN_THRESHOLD=40` and `playbook-pm-spec.md` is already past it, so the
   "consider superseding stale entries" warning **already fires on `develop`**
   and the dogfood step still passes (it gates on exit status and `cmp`, not
   stderr). An in-place edit changes the line count by zero. Do not read that
   warning as caused by this task, and do not touch the threshold.
5. **H5 — nothing in the corpus enforces chronological order.** An in-place edit
   keeps the rule at its date position in every generated block; an appended
   supersession would move it to the end of two blocks with no checker noticing.
   This is part of why DP-1 chose in place.
6. **H6 — the negative-footprint criteria are at risk of self-hosting false
   positives.** `.shell-team/specs/T-1000-operating-conventions.md` and
   `.shell-team/reviews/T-1000.md` quote the old claim, and so does this spec.
   Every negative grep here is scoped to `agents/ templates/ skills/ bin/` and
   carries a positive control over the same directories. Keep that scoping in any
   probe you write yourself — a repository-wide grep will "find" the defect in
   the document describing its removal.
7. **H7 — `check-pii-shapes` and `check-commit-identity` run on the PR diff.**
   The reworded `Why` must introduce no personal-name, hostname or employer-name
   shape. It says "the repository where the incident happened" for exactly this
   reason; keep it that way (AC8 requires the phrase, AC18 the gates).
8. **H8 — no retro artefact is in scope.** The `Dogfood check-retro` step re-runs
   only over existing, untouched `.shell-team/retros/*.md` and is unaffected.
9. **H9 — board heading integrity.** `## Active` is empty on `develop`; adding
   this task's line must be a **pure insertion** that leaves the `## Done`
   heading and every existing entry untouched. `bin/check-board-headings.sh …
   --base develop` is the only check that notices a deleted or overwritten id
   (AC17), and a cross-provider structural diff against
   `git show develop:.shell-team/todo.md` is the backstop (playbook lesson
   2026-07-13).

**Mutation self-check before hand-off** (playbook lesson 2026-07-25) — run each,
watch the named criterion go red, restore from a **pre-mutation file copy** (never
`git checkout`), verify byte-identical with `diff`, and watch it go green again:

1. Revert one of the three corpus prose fields to its `develop` wording → AC8
   red (and AC7 on the `Why` or `How to apply`, AC9 on the line count).
2. Hand-edit one word inside a generated block's marker region instead of
   regenerating → AC12 red (and `bin/check-prompt-sync.sh` red if you edit the
   consumer rather than the block).
3. Restore `feat/T-XXX-<slug>` in `docs/workflow.md` → AC1 red. Do the same in
   `docs/workflow.ja.md` and confirm AC1 reds for the twin too — one criterion
   covers both files, so prove it actually reads both.
4. Retitle the entry (break the heading byte-lock) → AC6 red.
5. Delete the newly added Japanese bullet → AC3 red.
6. Leave `docs/specs/` in the Japanese section only → AC2 red (the same
   both-files proof as 3).
7. Widen the entry's `Applies-to` to `all` and regenerate → AC7 red and AC13 red
   (four extra files change). This is the H3 invariant under attack.
8. Touch any comment line under `bin/` → AC16 red, AC19 red.

Beyond the list: your own blind spots are the second layer. Ask what these
criteria cannot see — a replacement wording that avoids the token `CI` while
still implying an automated gate the adopter does not have; a Japanese bullet
that is present and counted but says something different from its English
counterpart; a sweep re-run against the wrong directory set — and write at least
one mutation of your own that attacks the answer. Then check the tail of every
file you wrote for tool-wrapper residue (`grep -c '</content>\|</invoke>'` = 0
plus a `tail` read) before you commit; this repository has paid for that one.

**Recording duties.** `.shell-team/provenance/T-1009.md` records DP-1 and DP-2
with grounding quotes, cited by **durable anchor** (a heading, an AC label, a
`check:` snippet) rather than by line number (playbook lesson 2026-07-22).
`.shell-team/interventions/T-1009.md` is required whether or not anything was
intervened on — every prior task ships one, and `bin/check-interventions.sh`
accepts a sentinel-only file. The pointer sweep's command strings and hit counts
go in the board hand-off (AC20).

**Local gates before hand-off**: `bash bin/check-prompt-sync.sh`,
`bash bin/check-playbook.sh "$(bash bin/team-paths.sh --get lessons)"`,
`bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)"`,
`bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop`,
`bash bin/check-acs.sh .shell-team/specs/T-1009-doc-drift-and-false-ci-claim.md`,
`bash bin/check-intent.sh`, and the workflow's `Dogfood gen-playbook-blocks`
block run by hand. `.shell-team/test-recipe.md` documents how this repository
runs its suites — read it before running them.

**Prior art.** T-1008's spec for the corpus/ledger contract this entry lives
under and for the regeneration criterion shapes reused here (its AC17 is AC12's
ancestor); T-1008's board entry for what a merge-point-scoped criterion is and
why it is expected to go stale; `.shell-team/lessons.md:25,27,29` for what is
injected, what `Scope` decides and what `Superseded-by` means;
`CONTRIBUTING.md:40,66,86` for the already-correct, environment-neutral
statements about what CI does and does not lint, which are the model for the
corrected wording.
