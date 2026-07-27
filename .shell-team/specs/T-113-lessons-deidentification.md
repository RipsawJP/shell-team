# T-113 — a de-identification rule for lessons

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-113
**Intent version**: v2 — re-frozen 2026-07-27 under a human-ratified v1→v2. The
only change was inserting `--` after the option cluster of every `grep` whose
fixed-string pattern begins with a literal `-` (15 sites across the three
specs), because getopt made grep parse the pattern as an option and exit 2. The
asserted semantics (whole-line fixed-string match) are identical to v1. This
line lives OUTSIDE the intent block: the version of record is the board's
`intent-hash (vN)` ledger, and the marker lines themselves are matched by exact
full-line compare, so neither may carry a version token.
**Source**: GitHub issue #6 (RipsawJP/shell-team) — Layer 1 item 3.
**Branch**: `feature/pii-controls` (from `develop`). Third of three tasks on this
one branch; depends on T-112 (and through it on T-111, whose checkers this
task's own diff is measured by).

## Problem

The lessons corpus is where the improvement flywheel and PII intersect: entries
are distilled from real incidents, and `Source` is the field that carries
identifying detail into a file that is then injected into agent prompts and
published. The rule the project actually operates by — record the recurring
pattern, not the incident's identifying details — exists today only as habit.
Prevention at authoring time beats detection afterwards, so the rule belongs in
the places that tell an author what to write: the lessons format definition and
the agent that drafts lesson candidates.

## Goal

<!-- BEGIN intent-block: T-113 -->

Every surface that tells someone how to write a lesson states the same
de-identification rule in the same words: a lesson records the pattern and the
reason it recurs, never the identifying details of the incident, and `Source`
points at an artifact in this repository or is `n/a`. The rule is stated as an
authoring-time discipline and never as a detector, so no reader can mistake it
for a guarantee. The playbook validator's behavior is unchanged — this task adds
no schema.

## Non-goals

- **Changing `bin/check-playbook.sh`'s schema or validation logic.** The
  existing `Source` field already accepts `n/a`, so nothing needs to be added
  for the rule to be expressible. Only comment text changes (DP-1, AC3).
- **A new sentinel value.** `Source: n/a` is the spelling for "omitted"; no
  `Source: none`, `Source: -`, or empty-value form is introduced (DP-1).
- **Machine-validating that a `Source` value truly points at an in-repo
  artifact.** That requires semantic judgment of free text, which every checker
  in this repository deliberately refuses (DP-2).
- **Detecting PII inside an already-written lesson entry.** That is the
  detection half, and it already exists: T-111's diff-scoped shape checker sees
  a lessons file the moment it is added or edited. This task does not build a
  second detector.
- **Editing this repository's lessons corpus itself.** There is no lessons file
  in this repository's tracked tree; the rule governs the format definition and
  the authoring agent, which is what ships to adopters.
- **Rewriting existing history, named-entity patterns, semantic sensitivity,
  image content, and making `--all` a required CI check** — the same out-of-scope
  list as T-111 and T-112, not weakened here.
- **Editing `docs/pii-controls.md`.** The lessons rule is authoring-time
  prevention and lives at the authoring surfaces; cross-linking it into the
  controls document is a separate, optional follow-up.

## Acceptance criteria

Every `check:` runs from the repository root. `<base>` is `develop`. The exact
canonical lines are fixed under "Canonical lines" below.

- [ ] **AC1** The canonical rule appears verbatim, as one physical line, in the
  three English-language surfaces: the lessons format definition
  (`bin/check-playbook.sh`), the CLI that authors an entry
  (`bin/playbook-promote.sh`), and the drafting agent
  (`agents/scrum-master.md`).
  - check: grep -qxF '#   A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.' bin/check-playbook.sh && grep -qxF '#   A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.' bin/playbook-promote.sh && grep -qxF -- '- **De-identify lessons.** A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.' agents/scrum-master.md
- [ ] **AC2** Surface completeness: exactly three files under `bin/`, `agents/`
  and `docs/` carry the English canonical rule — no surface is missing, and no
  unreviewed fourth copy has appeared.
  - check: test "$(grep -rlF 'A lesson records the pattern and the reason it recurs' bin agents docs | wc -l | tr -d ' ')" = "3"
- [ ] **AC3** No schema change: every added or removed line in
  `bin/check-playbook.sh` and `bin/playbook-promote.sh` is a comment line, and
  both fixture suites still pass. A positive control proves the diff is not
  empty.
  - check: test "$(git diff develop -- bin/check-playbook.sh bin/playbook-promote.sh | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vcE '^[+-][[:space:]]*#')" -eq 0 && git diff develop -- bin/check-playbook.sh | grep -qE '^\+[[:space:]]*#' && git diff develop -- bin/playbook-promote.sh | grep -qE '^\+[[:space:]]*#' && bash tests/check-playbook/run.sh && bash tests/playbook-promote/run.sh
- [ ] **AC4** The `n/a` spelling stays the single documented way to omit a
  source, and it is still the value the existing schema accepts: the field
  description in the format definition names `n/a`, the CLI usage names it, and
  no other omission spelling is introduced.
  - check: grep -qF 'or is n/a.' bin/check-playbook.sh && grep -qF 'or is n/a.' bin/playbook-promote.sh && grep -qF 'or is n/a.' agents/scrum-master.md && ! grep -qE 'Source: (none|omitted)' bin/check-playbook.sh bin/playbook-promote.sh agents/scrum-master.md
- [ ] **AC5** The rule is stated as authoring-time discipline, never as a
  detector: the canonical limitation line is present in `agents/scrum-master.md`.
  - check: grep -qxF -- '- **The de-identification rule is an authoring-time discipline, not a detector.** It prevents identifying detail from being written down; it does not find identifying detail that is already there.' agents/scrum-master.md
- [ ] **AC6** The Japanese-language drafting surface carries the same rule and
  the same limitation, each as one physical line, inside the lesson-candidate
  guidance of `docs/templates/retro-template.md`.
  - check: grep -qxF '> **匿名化**: lesson には再発するパターンとその理由だけを書き、インシデント固有の識別情報は書かない。Source はこのリポジトリ内の成果物を指すか、n/a とする。' docs/templates/retro-template.md && grep -qxF '> この匿名化ルールは書く時点の規律であり、検出器ではない。すでに書かれてしまった識別情報を見つける機能はない。' docs/templates/retro-template.md
- [ ] **AC7** No wording that implies complete coverage: none of the
  badge-shaped claim compounds `PII-gated`, `PII-free`, `PII-clean`, `PII-safe`
  appears in the surfaces this task touches or in either README, each proved
  readable first.
  - check: grep -qF 'lesson' agents/scrum-master.md && grep -qF 'lesson' docs/templates/retro-template.md && grep -qF 'Source' bin/check-playbook.sh && grep -qF 'Source' bin/playbook-promote.sh && grep -qF 'shell-team' README.md && grep -qF 'shell-team' README.ja.md && ! grep -F -e 'PII-gated' -e 'PII-free' -e 'PII-clean' -e 'PII-safe' agents/scrum-master.md docs/templates/retro-template.md bin/check-playbook.sh bin/playbook-promote.sh README.md README.ja.md
- [ ] **AC8** The agent-facing edit does not disturb the generated prompt-block
  machinery or the retro validator: prompt blocks are still in sync and the
  playbook / prompt-sync / retro suites pass.
  - check: bash bin/check-prompt-sync.sh && bash tests/check-retro/run.sh && bash tests/gen-playbook-blocks/run.sh && bash tests/check-prompt-sync/run.sh
- [ ] **AC9** `agents/scrum-master.md` stays English-only (no translated
  counterpart is added) and its frontmatter is untouched, per this repository's
  language policy for agent-facing files.
  - check: test ! -e agents/scrum-master.ja.md && test ! -L agents/scrum-master.ja.md && git diff develop -- agents/scrum-master.md | grep -qE '^\+' && test "$(git diff develop -- agents/scrum-master.md | grep -cE '^[+-](name|description|tools|model):')" -eq 0
- [ ] **AC10** Self-application: both gates added earlier on this branch are
  green on the final branch state — the shape checker on the whole branch diff,
  and the identity checker on the branch commits.
  - check: bash bin/check-pii-shapes.sh --base develop && bash bin/check-commit-identity.sh --base develop
- [ ] **AC11** A decision provenance file for this task exists and is
  schema-conformant.
  - check: bash bin/check-provenance.sh .shell-team/provenance/T-113.md
- [ ] **AC12** The earlier tasks' suites still pass at the end of the branch, so
  the three-task sequence lands as one coherent change.
  - check: bash tests/check-pii-shapes/run.sh && bash tests/check-commit-identity/run.sh && bash tests/gitignore-raw-dumps/run.sh

## Input space

This task changes prose, not behavior, so its runtime input surface is the
lessons-entry values that the *unchanged* validator already consumes.

**Reachable input classes** — what a real lesson entry can carry:

1. A `Source` value naming an in-repo artifact: a spec path under the resolved
   specs dir, a review path under the resolved reviews dir, a `T-NNN` task id, a
   `bin/…` or `tests/…` path.
2. A `Source` value of exactly `n/a` — the documented omission spelling.
3. A `Source` value that is an external citation (a URL, a book reference). Still
   accepted by the unchanged schema; the rule discourages it only insofar as it
   would carry identifying detail.
4. Entry prose in Japanese or English, with full-width punctuation, that is
   spliced into generated prompt blocks by `bin/gen-playbook-blocks.sh`.
5. A lesson candidate drafted in a retro under the `## Lesson 候補（…）` heading,
   labelled `[common]` or `[target-specific]`.

**Out-of-scope synthetic extremes** — declined deliberately:

1. Verifying that a `Source` string *resolves* to a file that exists, or that a
   URL is reachable. Structure only (DP-2).
2. Judging whether a lesson's prose is "sufficiently de-identified". That is a
   human reading, not a machine one; the shape half is T-111's checker.
3. Multi-line, control-character-bearing, or marker-forging `Source` values —
   already rejected by the existing structural checks in
   `bin/check-playbook.sh`, and untouched by this task.
4. An author who writes identifying detail into a field other than `Source`. The
   rule covers the whole entry in words; mechanically, only T-111's shape
   checker sees it, and only for shapes.
5. Adversarially large lessons corpora as a performance concern.

<!-- END intent-block: T-113 -->

## Resolved design decisions

### DP-1 — `Source: n/a`, and no schema change

The omission spelling is `n/a`, and `bin/check-playbook.sh`'s schema is **not**
changed. Reasons, in order of weight:

1. **`n/a` is already an accepted value.** The existing field definition reads
   "non-empty free text — task/issue/PR ref, external citation, or n/a". The rule
   is expressible today; adding a schema token would be inventing a second way to
   say something the format already says.
2. **The detection half already exists as of T-111.** A lessons file is a tracked
   file, so any PII shape written into a `Source` value is caught by the
   diff-scoped shape checker when the entry lands. A duplicate rule inside
   `check-playbook.sh` would add a mechanism without adding coverage — and a
   second mechanism to keep in sync.
3. **Prevention beats detection at this seam**, which is the issue's own
   reasoning for putting the rule in the format definition and the drafting
   agent rather than in a validator.

Consequence: this task's edits to `bin/check-playbook.sh` and
`bin/playbook-promote.sh` are comment-only, and AC3 locks that mechanically
(every added or removed line in those two files is a comment line).

### DP-2 — why the rule is not machine-validated

Enforcing "`Source` points at an artifact in this repository" would require the
validator to decide whether a free-text string is an in-repo path, a task id, an
external URL, or prose. Every checker in this repository holds a structure-only
boundary for exactly this reason — `bin/check-playbook.sh`'s own header says it
is "NOT a semantic or security review", and `bin/check-provenance.sh` says it
"judges STRUCTURE ONLY … never the truth of its content". A guesser at this seam
would either reject legitimate citations or wave through an external reference,
and the real defense is the human-approval gate in `bin/playbook-promote.sh`
plus normal pull-request review. So the rule is stated where the author reads it
and left unenforced by the validator, deliberately and on the record.

### Canonical-surface inventory

Same-class norms drift when one canonical file is updated and its pair is not, so
all four surfaces are fixed here and covered by AC1, AC2 and AC6 in one round.

| # | Surface | Why it is a canonical surface | Line form |
|---|---|---|---|
| 1 | `bin/check-playbook.sh` header, the `Source` field description block | the lessons format definition | comment line |
| 2 | `bin/playbook-promote.sh` usage block, at `--source` | the CLI that writes an entry — the format definition's operative pair | comment line |
| 3 | `agents/scrum-master.md` Rules | the agent that drafts candidates (agent-facing, English-only) | markdown bullet |
| 4 | `docs/templates/retro-template.md`, the `## Lesson 候補（…）` guidance | where a candidate is actually drafted (human-facing, Japanese) | blockquote line |

### Canonical lines

Each is exactly one physical line; the checks are full-line exact matches.

Surfaces 1 and 2 (`#` + three spaces, matching the surrounding comment blocks):

```text
#   A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.
```

Surface 3:

```text
- **De-identify lessons.** A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.
- **The de-identification rule is an authoring-time discipline, not a detector.** It prevents identifying detail from being written down; it does not find identifying detail that is already there.
```

Surface 4:

```text
> **匿名化**: lesson には再発するパターンとその理由だけを書き、インシデント固有の識別情報は書かない。Source はこのリポジトリ内の成果物を指すか、n/a とする。
> この匿名化ルールは書く時点の規律であり、検出器ではない。すでに書かれてしまった識別情報を見つける機能はない。
```

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| A lesson records the pattern and the reason it recurs, never the incident's identifying details | AC1 (English surfaces), AC6 (Japanese surface) |
| `Source` points at an in-repo artifact, or is omitted | AC1, AC6 (same canonical sentence) |
| "Omitted" is spelled `Source: n/a` (DP-1) | AC4 |
| No schema change to `bin/check-playbook.sh` (DP-1) | AC3 |
| No new omission spelling is introduced | AC4 |
| The rule lives in the format definition **and** in `agents/scrum-master.md` | AC1, plus AC2's completeness anchor |
| All four canonical surfaces updated in one round | AC2 (exactly three English surfaces) + AC6 (the Japanese one) |
| Stated as authoring-time prevention, never as a guarantee | AC5, AC6 |
| No wording implying complete coverage | AC7 |
| Agent-facing files stay English-only; `docs/` may carry a Japanese counterpart | AC9 |
| Self-application: this task's own diff passes both new gates | AC10 |
| Provenance file required | AC11 |
| Earlier tasks' suites still pass | AC12 |
| Prompt-block machinery and retro validator undisturbed | AC8 |
| The rule is not machine-validated (DP-2) | info-only (not promoted to AC) — an explicit decision *not* to build a mechanism; AC3 is its observable consequence (the validator is byte-unchanged in logic) |
| The detection half already exists via T-111's checker | info-only (not promoted to AC) — a rationale for DP-1, already covered by T-111's own ACs |
| This repository has no tracked lessons file, so the corpus itself is not edited | info-only (not promoted to AC) — a statement about current repository state, verified by reading the tree; asserting the absence of a file the task never creates would lock an unrelated invariant |
| `docs/pii-controls.md` is not edited by this task | info-only (not promoted to AC) — a scoping choice; T-112's AC22 already pins that document's canonical lines, so a change here would be caught there |

## Assumptions

- `agents/scrum-master.md` carries no generated prompt-block marker region, so a
  Rules-section addition cannot desynchronise a generated block. Verified by
  reading the file; AC8 re-checks it mechanically anyway.
- `docs/templates/retro-template.md` is a template, not a validated artifact —
  `bin/check-retro.sh` validates retro *outputs* against required headings, and
  no CI step lints the template itself. Adding a blockquote line inside an
  existing section therefore cannot red an existing check. AC8 runs the retro
  suite to confirm.
- T-111 and T-112 have landed on this branch before this task starts, so both
  checkers exist for AC10 and both suites exist for AC12.
- The comment blocks in `bin/check-playbook.sh` and `bin/playbook-promote.sh`
  use `#` followed by three spaces for continuation lines, so the canonical
  comment line fits their existing style. Verified by reading both files.

## Open questions

None blocking. DP-1 answers the two questions the hand-off brief left open
(the `n/a` spelling, and whether the schema changes).

## Notes for engineer

- Place the canonical comment line inside the `Source` field description block in
  `bin/check-playbook.sh` (immediately after the existing `- **Source**:` field
  description), and inside the `--source` entry of `bin/playbook-promote.sh`'s
  usage block. Do not reflow the surrounding comment: AC1 is a full-line exact
  match, so the line must be its own physical line at the documented indentation.
- In `agents/scrum-master.md`, both canonical bullets belong in `## Rules`,
  alongside `- **Cite or remove.**` and the read-only rule — that is the section
  the agent is most likely to actually apply. Do not touch the frontmatter
  (AC9).
- In `docs/templates/retro-template.md`, both canonical blockquote lines belong
  in the guidance blockquote directly under the `## Lesson 候補（…）` heading of
  that template, so an author sees them at the moment of drafting.
- Write the provenance file with the same shape as the two earlier tasks; the
  two decisions worth recording here are DP-1 (no schema change, and why) and
  DP-2 (why the rule is not machine-validated), each with a grounding citation to
  a durable anchor — the field-description text in `bin/check-playbook.sh` and
  the structure-only sentences in the two checker headers — not to a line number.
- Files expected to change: `bin/check-playbook.sh` (comment only),
  `bin/playbook-promote.sh` (comment only), `agents/scrum-master.md`,
  `docs/templates/retro-template.md`, `.shell-team/provenance/T-113.md` (new),
  `.shell-team/todo.md` (status flag). No new CI wiring: this task adds no
  script and no suite.
