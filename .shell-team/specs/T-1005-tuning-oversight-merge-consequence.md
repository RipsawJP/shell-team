# T-1005 — the residual merge gate fires on consequence, not on the word "merge"

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1005
**Source**: GitHub issue #26. No new issue was opened: #26 already carries the fix criterion and the reason, and is the tracker.
**Branch**: `feature/tuning-oversight-merge-gate` (from `develop`).

## Problem

`docs/tuning-oversight.md` ships two worked examples of a personal override. The
"fewer interruptions" example's residual gate (en `:66-67`, ja `:52-53`) reads:

```markdown
- Do stop before merging, before force-pushing, and before anything that
  destroys work git cannot restore.
```

Two of those three items are about irreversibility. "Merging" is not in that
category, so the gate fires on a **word** rather than on a **consequence**.
Merging a retro, a board close-out or a provenance record changes nothing that
runs and is revertible in one command; merging a change to `bin/`, `agents/`,
`skills/`, `templates/prompt-blocks/`, `CLAUDE.md` or the workflow changes what
executes on the next run. The page teaches the reader to spend an interruption on
the first case and gives them no way to tell it from the second.

The same word-based framing appears three more times in the same two files — the
Fixed section's unconditional claim (en `:15`, ja `:9`), the section's own intro
line (en `:52`, ja `:38`) and the "worth keeping in either direction" bullet
(en `:88`, ja `:74`). Fixing one of four leaves the page contradicting itself.

## Goal

<!-- BEGIN intent-block: T-1005 -->

**The residual gate in the "fewer interruptions" example gates on whether the
merge changes what runs** — not on the base branch, and not on the word "merge".
The example's third bullet is split into the two things it was conflating: a
merge that changes what executes (stop), and an irreversible operation (stop).
A records-only merge is named explicitly as needing no stop, so the reader does
not have to infer the exemption from the absence of a rule.

**The page states the reason, in both languages.** The human is the guarantor at
the point where something takes effect. A records-only merge has no such point,
so a gate there costs an interruption and buys nothing. The second-order reason
is stated too: the gate is a discipline the operator imposes on themselves so
that accountability cannot drift, and keeping it exactly at the point of real
effect is what keeps responsibility where the operator decided it belongs.

**The trap is named, grounded in this repository's own mechanism.** In a
repository whose product is prompt content, "it's only docs" is not a safe test.
`templates/prompt-blocks/playbook-*.md` are `.md` files, they are generated
artefacts, they read like documentation — and they are spliced into `agents/*.md`,
which ship. `bin/check-prompt-sync.sh` enforces that splice, so this is a
mechanism the reader can verify rather than a warning they have to take on faith.
The criterion the page gives is **whether the content executes**, not what the
file is called.

**All four sites in the same class are fixed in one pass, in both languages.**
The Fixed section's claim is reconciled rather than left to contradict the
example (DP-1): it is restated as a statement about *authority* — the loop never
merges on its own — and explicitly distinguished from *interruption*, which is
the tunable layer. The section's intro line and the "worth keeping" bullet drop
the word-based framing for the consequence framing.

**The two documents stay in step.** "In step" has a precise meaning here (DP-5):
every fenced sample block is byte-identical between `docs/tuning-oversight.md`
and `docs/tuning-oversight.ja.md` — those blocks are English in both files today
because they are content the reader pastes into their own configuration — while
the surrounding prose is Japanese in the `.ja.md` file and semantically
equivalent.

**The "more checkpoints" example stays a genuine opposite** (DP-4). The page
ships a mechanism for choosing, not a policy: an operator who wants to be
consulted earlier must still find their position on the page intact, including
its unconditional "Get agreement before pushing, opening or merging a pull
request, or filing an issue". No what-runs qualifier leaks into it.

## Non-goals

- **No hook, no CI check, and no other enforcement of the residual gate.** The
  page's own Limits paragraph already says a `CLAUDE.md` changes the odds, not the
  mechanism; this task changes what the page teaches, not what any machine
  enforces. Nothing is added under `bin/`, `.github/`, or any hook load path.
- **No `templates/CLAUDE-routing-snippet.md` edit.** Its "pauses for a human
  before merge/push" line is a *routing* instruction describing the loop's own
  gate to a main session — the fixed layer, not a personal residual gate — and
  the issue scopes this task away from it. Inventoried, declared out of scope, and
  pinned byte-unchanged by a criterion so the declaration is verifiable rather
  than merely stated.
- **No `agents/*.md` or `skills/*` edit.** `agents/drift-evaluator.md` carries
  three sentences about Phase A keeping every merge on human GO; that is the
  drift-evaluator's advisory contract, a different subject, and editing an agent
  contract is not a prose fix to a documentation page.
- **No change to the loop's completion gate.** Both green gates, carried by the
  board's status flags, are untouched — and the Fixed section's substance must
  survive the DP-1 edit intact rather than being softened by it.
- **No edit to `## Limits`, to the "ships no hooks" posture paragraph, or to the
  sample-hook section.** T-1004 froze those bytes last merge; this task does not
  reopen them.
- **No new section, and no section renamed, reordered or removed** in either
  file. Every change lands inside a section that already exists.
- **No `README.md` / `README.ja.md` / `docs/distribution*.md` edit.** No claim in
  those files is falsified by this change, and a fourth and fifth copy of the
  criterion would be two more drift sites.
- **No edit to this repository's own `CLAUDE.local.md`.** It is git-ignored, so no
  pull request can reach it and no criterion can assert anything about it. The
  page's example is a template the operator copies from, not a mirror of it.
- **No exhaustive taxonomy of what "changes what runs" means in an arbitrary
  repository.** The page states the criterion plus this repository's
  instantiation of it, and tells the reader to substitute their own executing
  surfaces.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh`.

Four standing rules apply to every criterion below:

- **No negated `grep` without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` cannot be read, because `grep` exits 2 and the negation
  swallows it. Every criterion that asserts a string is *gone* asserts a string
  that must be *present* in the same file.
- **A count is pinned in both directions** wherever a count is the property.
- **Five criteria pass on the pre-implementation tree** — AC10, AC11, AC12, AC13
  and AC14, plus AC7's negated half — because they are two-sided invariant locks,
  not change detectors: they exist to catch the change breaking something that is
  already true. AC13 passes as soon as this spec and the board entry are on the
  branch, since both are inside its allow-list. AC1–AC9, AC15 and AC16 fail
  before the change and are the ones that prove it happened — AC9 by design: its
  extraction-equality half already holds today, but its `- A merge of records only`
  positive control is what proves the new bullets reached the ja file's fenced
  block, so it is a change detector. Measured live by the executing side on the
  pre-implementation tree before the intent-hash freeze; disclosed so no reviewer
  mistakes a lock for a vacuous criterion.
- **A criterion states the boundary of what it proves.** Semantic equivalence
  between the English and Japanese prose is a reviewer's read; what the criteria
  prove mechanically is fenced-block byte-identity plus the presence of each
  declared anchor in each language.

**The example block's new bytes are this spec's bytes.** The block below is the
canonical form of the "fewer interruptions" sample, byte-identical in both files
(DP-5). It replaces the current block in full; the first two bullets are
unchanged from today, the third is split into three, and the preamble's
`merge waits for me` becomes the authority form:

````markdown
```markdown
# Local overrides

The loop's own gate is sufficient oversight here: a task is done only when QA
and the cross-provider review are both green, and the loop never merges on its
own.

Do not add conversational gates on top of it:

- Do not ask before creating a branch or filing an issue for work I have already
  asked for. Follow the repo's convention and tell me what you chose.
- Do not stop to have a multi-file change set approved before starting. State
  what you are about to touch, then proceed.
- Do stop before a merge that changes what runs — in this repository that means
  anything under `bin/`, `agents/`, `skills/`, `templates/prompt-blocks/`,
  `.shell-team/loops/`, `CLAUDE.md`, or the workflow.
- A merge of records only — a retro, a board close-out, a provenance record —
  needs no stop: nothing takes effect and one command reverts it.
- Do stop before force-pushing, and before anything that destroys work git
  cannot restore.
```
````

**The prose anchors each criterion pins** are listed with the criterion that
pins them. They are the load-bearing phrases; the sentences around them are the
engineer's to write, in English in `docs/tuning-oversight.md` and in Japanese in
`docs/tuning-oversight.ja.md`.

**pm-spec has no shell in this role, so no `check:` line below was executed.**
The executing side runs all sixteen live against the pre-implementation tree
before the intent-hash is recorded, corrects any line that is broken as a command
or would pass vacuously (meaning preserved), and only then freezes.

- [ ] **AC1** **The example's residual gate is consequence-based, in both
  languages.** The old conflated bullet's first line is gone from both files
  (count 0), and the canonical block's five bullet lines quoted above are present
  verbatim in both. The two unchanged bullets are the same-file positive controls
  for the negated half.
  - check: for f in docs/tuning-oversight.md docs/tuning-oversight.ja.md; do test "$(grep -cF -- '- Do stop before merging, before force-pushing, and before anything that' "$f")" -eq 0 || exit 1; grep -qF -- '- Do not ask before creating a branch or filing an issue for work I have already' "$f" || exit 1; grep -qF -- '- Do stop before a merge that changes what runs — in this repository that means' "$f" || exit 1; grep -qF -- '  anything under `bin/`, `agents/`, `skills/`, `templates/prompt-blocks/`,' "$f" || exit 1; grep -qF -- '  `.shell-team/loops/`, `CLAUDE.md`, or the workflow.' "$f" || exit 1; grep -qF -- '- A merge of records only — a retro, a board close-out, a provenance record —' "$f" || exit 1; grep -qF -- '  needs no stop: nothing takes effect and one command reverts it.' "$f" || exit 1; grep -qF -- '- Do stop before force-pushing, and before anything that destroys work git' "$f" || exit 1; done

- [ ] **AC2** **No unconditional merge framing survives anywhere in the
  "fewer interruptions" section** — not in the block's preamble, and not in the
  prose line that introduces it. The block preamble's `and merge waits for me.`
  is gone from both files and replaced by the authority form; the intro line
  `For someone who wants the loop to run and only wants the merge decision:`
  (ja: `ループを回して、マージの判断だけしたい場合:`) is gone and replaced. This is
  the canonical-pair half of AC1: the discipline's prose and the code block it
  applies to are both sites, inside one file.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && for f in "$E" "$J"; do test "$(grep -cF -- 'and the cross-provider review are both green, and merge waits for me.' "$f")" -eq 0 || exit 1; grep -qF -- 'and the cross-provider review are both green, and the loop never merges on its' "$f" || exit 1; done && test "$(grep -cF -- 'For someone who wants the loop to run and only wants the merge decision:' "$E")" -eq 0 && grep -qxF -- 'For someone who wants the loop to run, and to be asked only where a stop earns its cost:' "$E" && test "$(grep -cF -- 'ループを回して、マージの判断だけしたい場合:' "$J")" -eq 0 && grep -qxF -- 'ループを回して、コストに見合う場面でだけ確認してほしい場合:' "$J"

- [ ] **AC3** **DP-1: the Fixed section is reconciled, and its substance is not
  softened.** The unconditional sentence `Merging waits for a human by the same design.`
  (ja: `マージが人間を待つのも同じ設計によります。`) is gone from both files. In its
  place each file states that the loop never merges on its own (en anchor:
  `never merges on its own`; ja: `ループが自分でマージすることもありません`) **and**
  distinguishes that from interruption explicitly (en: `not about interruption`;
  ja: `権限の話であって、確認の話ではありません`). The positive controls are the
  section's surviving substance, asserted in the same criterion so the edit cannot
  weaken the fixed layer while passing: both flag tokens, the both-green sentence,
  and `no personal setting relaxes it` / `個人設定で緩むことはありません`.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && test "$(grep -cF -- 'Merging waits for a human by the same design.' "$E")" -eq 0 && grep -qF -- 'A task is done only when QA reaches' "$E" && grep -qF -- 'READY_FOR_REVIEW' "$E" && grep -qF -- 'READY_FOR_MERGE' "$E" && grep -qF -- 'no personal setting relaxes it' "$E" && grep -qF -- 'never merges on its own' "$E" && grep -qF -- 'not about interruption' "$E" && test "$(grep -cF -- 'マージが人間を待つのも同じ設計によります。' "$J")" -eq 0 && grep -qF -- 'READY_FOR_REVIEW' "$J" && grep -qF -- 'READY_FOR_MERGE' "$J" && grep -qF -- '個人設定で緩むことはありません' "$J" && grep -qF -- 'ループが自分でマージすることもありません' "$J" && grep -qF -- '権限の話であって、確認の話ではありません' "$J"

- [ ] **AC4** **DP-2: the "worth keeping in either direction" bullet uses the
  consequence framing.** `- **Merging**, because it is the point the loop is built around.`
  (ja: `- **マージ** — ループがそこを中心に設計されているため`) is gone from both files,
  and each file's first bullet now names a merge that changes what runs (en:
  `A merge that changes what runs`; ja: `実行されるものを変えるマージ`) together with
  the records-only counter-case (en: `A merge of records only`; ja:
  `記録だけのマージ`). The section's surviving second bullet — the irreversibility
  one — is the same-file positive control, and it must not be narrowed: it still
  carries `Anything git cannot undo` / `git が取り消せないもの`.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && test "$(grep -cF -- '- **Merging**, because it is the point the loop is built around.' "$E")" -eq 0 && grep -qF -- '- **Anything git cannot undo**' "$E" && grep -qF -- 'A merge that changes what runs' "$E" && grep -qF -- 'A merge of records only' "$E" && test "$(grep -cF -- '- **マージ** — ループがそこを中心に設計されているため' "$J")" -eq 0 && grep -qF -- '- **git が取り消せないもの**' "$J" && grep -qF -- '実行されるものを変えるマージ' "$J" && grep -qF -- '記録だけのマージ' "$J"

- [ ] **AC5** **The primary reason is stated in the page, in both languages**: the
  human is the guarantor at the point where something takes effect, a records-only
  merge has no such point, and a gate there costs an interruption and buys
  nothing. en anchors: `the human is the guarantor`, `costs an interruption`. ja
  anchors: `保証人は人間`, `確認のコストだけを払って何も買えません`. Boundary: this
  proves the reason is present, not that it is well argued — that is the
  reviewer's read.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && grep -qF -- 'the human is the guarantor' "$E" && grep -qF -- 'costs an interruption' "$E" && grep -qF -- '保証人は人間' "$J" && grep -qF -- '確認のコストだけを払って何も買えません' "$J"

- [ ] **AC6** **The second-order reason is stated in the page, in both
  languages**: the gate is a discipline the operator imposes on themselves so that
  accountability cannot drift, and keeping it exactly at the point of real effect
  keeps responsibility where the operator decided it belongs. en anchors:
  `a discipline the operator imposes on themselves`,
  `where the operator decided it belongs`. ja anchors: `自分に課している規律`,
  `責任を運用者が置くと決めた場所`.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && grep -qF -- 'a discipline the operator imposes on themselves' "$E" && grep -qF -- 'where the operator decided it belongs' "$E" && grep -qF -- '自分に課している規律' "$J" && grep -qF -- '責任を運用者が置くと決めた場所' "$J"

- [ ] **AC7** **The gate is not keyed on the base branch, and the page says so.**
  Each file carries the explicit clause (en: `not on which branch you are merging into`;
  ja: `どのブランチへ入れるかでもありません`), and neither file names a branch anywhere
  — `develop` appears zero times in both, which is true today and must stay true,
  so a later edit cannot reintroduce a branch-based criterion. The clause itself is
  the same-file positive control for the negated half.
  - check: for f in docs/tuning-oversight.md docs/tuning-oversight.ja.md; do test "$(grep -cF -- 'develop' "$f")" -eq 0 || exit 1; done && grep -qF -- 'not on which branch you are merging into' docs/tuning-oversight.md && grep -qF -- 'どのブランチへ入れるかでもありません' docs/tuning-oversight.ja.md

- [ ] **AC8** **DP-3: the trap is named and mechanically grounded.** Each file
  states that the file extension is not the signal and that the criterion is
  whether the content executes (en anchors: `whether the content executes`,
  `templates/prompt-blocks/playbook-`, `bin/check-prompt-sync.sh`, `agents/*.md`;
  ja anchors: `拡張子は signal ではありません`, `内容が実行されるか`,
  `templates/prompt-blocks/playbook-`, `bin/check-prompt-sync.sh`). The claim's
  **grounding** is asserted in the same criterion rather than taken on faith: the
  registry really does carry a `marker`-mode rule splicing a `playbook-*.md` block
  into an `agents/*.md` consumer, the marker really is present in that agent file,
  and `bin/check-prompt-sync.sh` is green — so if that mechanism ever stops being
  real, this criterion fails instead of the page quietly becoming false.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && grep -qF -- 'whether the content executes' "$E" && grep -qF -- 'templates/prompt-blocks/playbook-' "$E" && grep -qF -- 'bin/check-prompt-sync.sh' "$E" && grep -qF -- 'agents/*.md' "$E" && grep -qF -- '拡張子は signal ではありません' "$J" && grep -qF -- '内容が実行されるか' "$J" && grep -qF -- 'templates/prompt-blocks/playbook-' "$J" && grep -qF -- 'bin/check-prompt-sync.sh' "$J" && test -f templates/prompt-blocks/playbook-pm-spec.md && test "$(awk '$1=="marker" && $2=="playbook-pm-spec.md" {print $3" "NF-2}' templates/prompt-blocks/registry.txt)" = 'agents/pm-spec.md 1' && grep -qF -- '<!-- BEGIN prompt-block: playbook-pm-spec -->' agents/pm-spec.md && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC9** **DP-5: "kept in step" means the fenced blocks are byte-identical.**
  Extracting every fenced-block body from `docs/tuning-oversight.md` and from
  `docs/tuning-oversight.ja.md` yields byte-identical output, and each file has
  exactly six fence lines (three blocks) in both directions — so an unbalanced
  fence cannot silently truncate the extraction into a false match. Positive
  controls: the extraction is non-empty and contains both an unchanged line
  (`# Local overrides`) and a new one (`- A merge of records only`), which is what
  makes this criterion also prove the new bullets reached the ja file's block.
  - check: A="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && B="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && awk '/^```/{f=!f; next} f' docs/tuning-oversight.md > "$A" && awk '/^```/{f=!f; next} f' docs/tuning-oversight.ja.md > "$B" && test -s "$A" && grep -qxF -- '# Local overrides' "$A" && grep -qF -- '- A merge of records only' "$A" && cmp -s "$A" "$B" && test "$(grep -c '^```' docs/tuning-oversight.md)" -eq 6 && test "$(grep -c '^```' docs/tuning-oversight.ja.md)" -eq 6 && rm -f "$A" "$B"

- [ ] **AC10** **DP-4: the "more checkpoints" example is a genuine opposite,
  untouched.** In both files, the whole section from its heading to the next `##`
  heading is byte-identical to the base ref — which is the strongest available form
  of "no what-runs qualifier leaked in", since it admits no change at all,
  including its unconditional
  `- Get agreement before pushing, opening or merging a pull request, or filing an`
  bullet. Positive controls: the extracted region is non-empty and contains that
  bullet. **Merge-point-scoped**: this criterion resolves `develop` and is tied to
  the merge point it was authored at; it is expected to go stale once this task
  lands there. Do not merge-range it, widen its base-ref resolution, or re-derive
  it per rework round.
  - check: A="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && B="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.md | awk '/^## Example — more checkpoints$/{f=1;print;next} /^## /{f=0} f' > "$A" && awk '/^## Example — more checkpoints$/{f=1;print;next} /^## /{f=0} f' docs/tuning-oversight.md > "$B" && test -s "$A" && grep -qF -- '- Get agreement before pushing, opening or merging a pull request, or filing an' "$A" && cmp -s "$A" "$B" && C="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && D="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.ja.md | awk '/^## 例 — 確認を増やす$/{f=1;print;next} /^## /{f=0} f' > "$C" && awk '/^## 例 — 確認を増やす$/{f=1;print;next} /^## /{f=0} f' docs/tuning-oversight.ja.md > "$D" && test -s "$C" && grep -qF -- '- Get agreement before pushing, opening or merging a pull request, or filing an' "$C" && cmp -s "$C" "$D" && rm -f "$A" "$B" "$C" "$D"

- [ ] **AC11** **DP-6: T-1004's frozen bytes are intact.** In both files the
  region from the Limits heading to end of file — the Limits prose, the
  "ships no hooks" posture paragraph and the whole sample-hook section — is
  byte-identical to the base ref. Positive controls: the extracted region is
  non-empty and carries the posture sentence. **Merge-point-scoped**, on the same
  terms as AC10.
  - check: A="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && B="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.md | awk '/^## Limits$/{f=1} f' > "$A" && awk '/^## Limits$/{f=1} f' docs/tuning-oversight.md > "$B" && test -s "$A" && grep -qF -- '**This project ships no hooks.**' "$A" && cmp -s "$A" "$B" && C="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && D="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.ja.md | awk '/^## 限界$/{f=1} f' > "$C" && awk '/^## 限界$/{f=1} f' docs/tuning-oversight.ja.md > "$D" && test -s "$C" && grep -qF -- '**このプロジェクトは hook を出荷しません。**' "$C" && cmp -s "$C" "$D" && rm -f "$A" "$B" "$C" "$D"

- [ ] **AC12** **No section is added, removed, renamed or reordered.** In both
  files the sequence of heading lines (levels 1–3) is byte-identical to the base
  ref, so every change lands inside a section that already exists. Positive
  controls: the extracted sequence is non-empty and contains the page's
  fixed/tunable heading. **Merge-point-scoped**, on the same terms as AC10.
  - check: A="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && B="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.md | grep -E '^#{1,3} ' > "$A" && grep -E '^#{1,3} ' docs/tuning-oversight.md > "$B" && test -s "$A" && grep -qxF -- '## What is fixed, and what is yours' "$A" && cmp -s "$A" "$B" && C="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && D="$(mktemp "${TMPDIR:-/tmp}/t1005.XXXXXX")" && git show develop:docs/tuning-oversight.ja.md | grep -E '^#{1,3} ' > "$C" && grep -E '^#{1,3} ' docs/tuning-oversight.ja.md > "$D" && test -s "$C" && grep -qxF -- '## 固定されているもの、あなたの領分のもの' "$C" && cmp -s "$C" "$D" && rm -f "$A" "$B" "$C" "$D"

- [ ] **AC13** **The change stays inside its declared surface.** Every path in
  `git diff --name-only develop` matches the allow-list below, with the non-empty
  diff as the positive control. The allow-list carries this task's mandatory
  artefacts — spec, provenance, review record, the interventions file the gate
  requires, and the board — so a required artefact is never outside the scope
  lock. `.shell-team/test-recipe.md` is permitted, not required: this task adds no
  suite, and an entry there is only warranted if the engineer establishes a
  procedure worth recording. **Merge-point-scoped**, on the same terms as AC10.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.shell-team/(todo\.md|test-recipe\.md|specs/T-1005-tuning-oversight-merge-consequence\.md|provenance/T-1005\.md|reviews/T-1005[^/]*|interventions/T-1005\.md)|docs/tuning-oversight\.md|docs/tuning-oversight\.ja\.md)$')"

- [ ] **AC14** **The declared out-of-scope surfaces are byte-unchanged, and no
  enforcement artefact arrives.** `templates/` (including
  `templates/CLAUDE-routing-snippet.md`, whose merge/push line was inventoried and
  deliberately left alone), `bin/`, `agents/`, `skills/`, `.github/`, `README.md`,
  `README.ja.md`, `CLAUDE.md` and `docs/distribution.md` all show an empty diff
  against the base ref; and the only files the diff **adds** anywhere are this
  task's own records under `.shell-team/`. That second half is what closes "no hook
  or enforcement" mechanically: a hook, a checker or a workflow would have to
  arrive as a new file. Positive control: the overall diff is non-empty.
  **Merge-point-scoped**, on the same terms as AC10.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(git diff --name-only develop -- templates/ bin/ agents/ skills/ .github/ README.md README.ja.md CLAUDE.md docs/distribution.md docs/distribution.ja.md)" && test -z "$(git diff --name-only --diff-filter=A develop | grep -vE -- '^\.shell-team/(specs|provenance|reviews|interventions)/')"

- [ ] **AC15** **Nothing that already worked stops working**, and this task's
  mandatory records exist and are conformant: the board linter on the shipped
  template and on this repository's board, prompt sync and its suite, the resolver
  suite, the PII-shape and commit-identity checks over this task's own diff, the
  retro checker over this repository's retros, and the interventions and provenance
  checkers over this task's records.
  - check: bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash tests/team-paths/run.sh >/dev/null && bash bin/check-pii-shapes.sh --base develop >/dev/null && bash bin/check-commit-identity.sh --base develop >/dev/null && bash bin/check-retro.sh "$(bash bin/team-paths.sh --get retros)"/*.md >/dev/null && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1005.md" >/dev/null && bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1005.md" >/dev/null

- [ ] **AC16** **The path list is presented as this repository's instantiation,
  not as the criterion.** Both files tell the reader, in prose outside the fenced
  block, to substitute the surfaces that execute in their own repository (en
  anchor: `substitute the surfaces that execute in your own repository`; ja:
  `自分のリポジトリで実行される面に置き換えてください`). Without this the pasted block
  reads as a universal list, which it is not.
  - check: grep -qF -- 'substitute the surfaces that execute in your own repository' docs/tuning-oversight.md && grep -qF -- '自分のリポジトリで実行される面に置き換えてください' docs/tuning-oversight.ja.md

## Input space

**Reachable input classes** — what real usage produces, and what the change must
therefore be correct about. This task ships prose, so its input classes are its
readers and the checkers that read the files; both are enumerated concretely.

1. **The two files as read by this repository's own checkers on the diff.**
   `bin/check-pii-shapes.sh --base develop` and
   `bin/check-commit-identity.sh --base develop` run over the changed lines in CI,
   so the new prose must carry no PII shape and no absolute home path.
   `bin/check-prompt-sync.sh` reads `templates/prompt-blocks/registry.txt`, which
   registers neither of these two files as a consumer of any block — so the new
   prose must not introduce a `<!-- BEGIN prompt-block:` marker, which would make
   the file look like a consumer it is not.
2. **Two reading orders of the same page.** A reader who lands on the Fixed
   section first, and a reader who lands on the "fewer interruptions" example
   first, must reach the same conclusion. This is the class the current page fails
   — and the reason DP-1 is resolved rather than deferred.
3. **The fenced block copied verbatim into an adopter's `CLAUDE.local.md`,** with
   none of the surrounding prose. That is how the block is actually used, so it
   must carry the criterion itself and not only a path list, and it must make sense
   with no page around it.
4. **Two adopter repository shapes.** A repository whose executing surfaces sit at
   different paths from this one's (the block's path list is an instantiation, not
   the criterion — AC16), and a records-only repository where no merge changes what
   runs (the exemption bullet is the whole rule there).
5. **An operator who wants *more* checkpoints, not fewer.** They must find their
   position on the page intact and unqualified (AC10). The page ships a mechanism
   for choosing; a page that only supports one direction is a policy.
6. **Markdown rendering of both files on GitHub**, including the `markdown` and
   `json` fence languages, em dashes and the Japanese text. No HTML, no new fence.

**Out-of-scope synthetic extremes** — named and declined:

1. **Mechanically classifying a merge as records-only versus what-runs** — a hook,
   a CI check, a path allow-list a script evaluates. Declined: the page's own
   Limits paragraph says a `CLAUDE.md` changes the odds, not the mechanism, and the
   issue scopes this task to prose. A classifier is a different task with a
   different risk profile.
2. **An exhaustive taxonomy of "changes what runs" for an arbitrary repository.**
   Unbounded by construction. The page states the criterion, this repository's
   instantiation, and the substitution instruction.
3. **Adversarial boundary cases of the criterion itself** — a merge that changes a
   test fixture a checker reads; a merge that edits a `check:` line in a frozen
   spec; a merge that adds a lesson that a later task splices into a prompt block.
   Named and declined as prose-unresolvable: the page's job is to make the operator
   ask "does this content execute?", and the trap paragraph exists precisely
   because the answer is sometimes surprising. Escalating ever-finer cases against
   this prose is out of scope for this task; a genuinely wrong answer in a named
   case is a new issue.
4. **Semantic-equivalence claims about the Japanese prose beyond the declared
   anchors.** The mechanical boundary is fenced-block byte-identity (AC9) plus each
   declared anchor present in each language; the quality of the surrounding
   Japanese is a reviewer's read, not a criterion, and refining it without bound is
   declined.
5. **Line-width, wrapping and other typographic uniformity** of the edited prose.
   House style is ~79 columns for English prose and unwrapped paragraphs for
   Japanese; asserting it mechanically is declined, with the reason in the
   correspondence table below.
6. **Other language versions.** There are two, `en` and `ja`, and no third is
   added.
7. **Non-UTF-8, CRLF or NUL-bearing variants of the two files.** They are UTF-8
   LF files in git and stay that way; a checker reading a mangled copy is not a
   state real usage produces here.

<!-- END intent-block: T-1005 -->

## Resolved design decisions

### DP-1 — the Fixed section is reconciled by separating authority from interruption

Three options were on the table: state that the two are different layers, add a
qualifier to the Fixed section, or leave it untouched with a reason. **Leaving it
untouched is rejected**: `Merging waits for a human by the same design.` is the
*same* word-based framing the issue attacks, sitting three sections above the
corrected example, and the page's entire job is to teach the fixed/tunable
boundary. A reader who takes that sentence at face value concludes the example's
new third bullet is a contradiction, or worse, that a personal setting just
relaxed the fixed layer.

**The chosen resolution does both remaining things, minimally, because they turn
out to be the same edit.** The Fixed sentence is restated as what it actually
guarantees — *the loop never merges on its own; the merge is a human action* —
and one short paragraph names the distinction that makes the example coherent:
that is a claim about **authority**, not about **interruption**. The loop cannot
merge for you; whether a given merge earns a conversational stop is the tunable
layer, and narrowing it there leaves the fixed layer exactly where it was.

This is not a softening, and AC3 is written so that it cannot become one: the same
criterion that requires the new sentences requires the both-green-gates claim, both
flag tokens and `no personal setting relaxes it` to survive in the same file. The
completion gate is untouched (Non-goal), and the page still says nothing personal
relaxes it.

### DP-2 — the "worth keeping" bullet is rewritten, not kept

Keeping it was considered and rejected for one reason: it is the page's
*general-principle* section, read by an operator moving in either direction, so a
word-based first bullet there outranks the example in influence. Two stops still
earn their cost regardless of preference; the first is now "a merge that changes
what runs" with the records-only case named as its counter-example, and the
second — irreversibility — is unchanged and must not be narrowed (AC4 pins its
surviving anchor as the positive control, so a fix that quietly conditionalises
irreversibility fails).

### DP-3 — the trap goes in the general-principle section, grounded in the splice

Placement: immediately after the two bullets in "What is worth keeping in either
direction", following the reason paragraph. Two grounds. **(a)** That section
states the criterion as a general principle, and the trap is the failure mode of
*applying* the criterion — it belongs next to the criterion, not next to one
example. **(b)** Prose inside the "fewer interruptions" section would be prose the
reader does not carry away: what they copy is the fenced block, and the block
already carries the criterion.

Grounding: `templates/prompt-blocks/playbook-*.md` → `agents/*.md`, enforced by
`bin/check-prompt-sync.sh` (registry rows 42–45, `marker` mode: the region between
the consumer's `<!-- BEGIN prompt-block: … -->` markers must match the canonical
file byte-for-byte). Those four files are `.md`, they are generated artefacts, and
they read like documentation — and merging a change to one changes what every
agent that consumes it does on the next run. The criterion the page states is
**whether the content executes**, never "docs are dangerous", which is an
unverifiable generality that would make the page's advice unusable. AC8 asserts
the grounding as well as the prose, so the claim cannot rot into a false statement
about a mechanism that has changed.

### DP-4 — the "more checkpoints" example is pinned byte-for-byte, not merely reviewed

The requirement is that no what-runs qualifier leaks into it. A criterion listing
forbidden tokens would be a guessing game; pinning the entire section
byte-identical to the base ref admits no leak of any wording, and it is cheaper to
read. Its third bullet ("Get agreement before pushing, opening or merging a pull
request, or filing an issue") therefore stays unconditional by construction. This
is the property that keeps the page a mechanism rather than a policy: the operator
who wants more checkpoints finds their position stated without qualification.

### DP-5 — "kept in step" is defined, and the definition is mechanical

The `.ja.md` file's fenced blocks are byte-identical English to the `.md` file's
today (verified: three blocks each, identical content), because their content is
what the reader pastes into their own configuration — translating it would produce
a block that no longer matches what the tooling and the rest of the page describe.
So: **fenced blocks byte-identical between the two files; surrounding prose in
Japanese and semantically equivalent.** AC9 makes the extraction diff a criterion
and pins the fence count in both directions, so an unbalanced fence cannot turn
the diff into a false pass. The boundary is stated in the criteria: byte-identity
and anchor presence are mechanical; the quality of the Japanese prose is the
reviewer's read.

### DP-6 — T-1004's frozen region is pinned, not just avoided

The "ships no hooks" posture paragraph and the whole sample-hook section were
frozen by T-1004 one merge ago. Rather than pin the two fragments separately, AC11
pins **the Limits heading to end of file** in both files: it covers both named
regions plus the Limits prose, which this task also has no business touching, and
it is one comparison instead of several fragile literal greps. Nothing in this
task's placement (DP-3) needs to enter that region.

### DP-7 — the fourth site: the section's own intro line

Inventoried while resolving DP-1/DP-2 and fixed in the same pass. en `:52`
("only wants the merge decision") and ja `:38` are the same word-based framing in
the prose that introduces the example, two lines above the block being corrected.
Its replacement borrows the "worth keeping" section's own language — *asked only
where a stop earns its cost* — so the two sections point at each other. Same-class
sites are fixed in one round, and the class is counted inside a file, not by file
boundary: the block preamble's `merge waits for me` (en `:58`, ja `:44`) is the
fifth site and is fixed by AC1/AC2 together.

## Measured inventory (verified against the tree at `1602889`; re-verify before editing)

| File | Site | Line (en / ja) | What changes |
|---|---|---|---|
| both | Fixed section's merge sentence | 15 / 9 | DP-1: authority restated, interruption distinguished (one added paragraph) |
| both | "fewer interruptions" intro line | 52 / 38 | DP-7: word-based framing → cost framing |
| both | example block preamble | 57–58 / 43–44 | `merge waits for me` → `the loop never merges on its own` |
| both | example block third bullet | 66–67 / 52–53 | split into three bullets (what-runs / records-only / irreversible) |
| both | prose after the example block | new / new | AC16's substitution note |
| both | "worth keeping" first bullet | 88 / 74 | DP-2: consequence framing + records-only counter-case |
| both | "worth keeping" section, after the bullets | new / new | the reason paragraph (AC5, AC6) and the trap paragraph (AC8) |

Sites inventoried and deliberately **not** changed, each with the reason recorded:
`templates/CLAUDE-routing-snippet.md:25` ("pauses for a human before merge/push")
— routing prose describing the loop's own gate to a main session, i.e. the fixed
layer, and out of scope per the issue; `agents/drift-evaluator.md:48,133,134`
(Phase A keeps every merge on human GO) — an agent's advisory contract, a
different subject, and `agents/` is out of scope; this repository's own
`CLAUDE.local.md` — git-ignored, unreachable from a pull request. The first two are
pinned byte-unchanged by AC14.

## Body-to-AC correspondence

Every normative directive in this spec's body, mapped to the criterion that holds
it or to an explicit exemption with a reason.

| Body directive | Held by |
|---|---|
| The residual gate fires on whether the merge changes what runs | AC1 |
| The old conflated bullet is gone | AC1 (count 0, both files) |
| A records-only merge is named as needing no stop | AC1, AC4 |
| Irreversible operations keep an unconditional stop | AC1 (the split bullet), AC4 (the surviving second bullet is the positive control) |
| No unconditional merge framing survives in the example's own prose or preamble | AC2 |
| DP-1: the Fixed section is reconciled (authority vs interruption) | AC3 |
| The Fixed layer's substance is not softened | AC3 (both flag tokens, the both-green sentence and `no personal setting relaxes it` are the positive controls) |
| DP-2: the "worth keeping" bullet uses consequence framing | AC4 |
| The reason is stated: the human is the guarantor at the point of effect | AC5 |
| A records-only merge has no such point, so a stop buys nothing | AC5 |
| The second-order reason: a self-imposed discipline, responsibility kept where the operator put it | AC6 |
| Not gated on the base branch, and the page says so | AC7 (clause present; `develop` count 0 in both files) |
| DP-3: the trap is named — "it's only docs" is not the test | AC8 |
| The criterion is whether the content executes, not the extension | AC8 |
| The trap is grounded in the real splice, not in a generality | AC8 (registry `marker` row + the marker in `agents/pm-spec.md` + `check-prompt-sync.sh` green) |
| DP-5: fenced blocks byte-identical between en and ja | AC9 |
| The new bullets reach the ja file's block too | AC9 (the extraction diff, with a new-line positive control) |
| DP-4: the "more checkpoints" example stays a genuine opposite | AC10 (whole section byte-unchanged) |
| Its third bullet stays unconditional | AC10 |
| DP-6: T-1004's frozen posture paragraph and sample-hook section are untouched | AC11 |
| No `## Limits` edit | AC11 (the pinned region starts at that heading) |
| No section added, removed, renamed or reordered | AC12 |
| Scope: `docs/tuning-oversight.md` and `docs/tuning-oversight.ja.md` only | AC13 |
| Mandatory artefacts are inside the scope lock | AC13 (allow-list) |
| No hook, no CI check, no other enforcement | AC14 (out-of-scope surfaces empty diff; the only added files are this task's records) |
| No `templates/CLAUDE-routing-snippet.md` edit | AC14 |
| No `agents/*.md` or `skills/*` edit | AC14 |
| No `README*` / `docs/distribution*` edit | AC14 |
| Nothing that already worked stops working | AC15 |
| The path list is this repository's instantiation, not the criterion | AC16 |
| Prose only (no code, no test, no config) | **info-only (not promoted to AC)** — mechanically the same statement as AC13's allow-list plus AC14's added-file check; a separate criterion asserting "these two markdown files contain prose" has nothing to compare against |
| No `CLAUDE.local.md` edit | **info-only (not promoted to AC)** — the file is git-ignored, so no criterion in this repository can observe it either way; recorded so the omission is a decision rather than a gap |
| Line width ~79 columns for English prose, unwrapped paragraphs for Japanese | **info-only (not promoted to AC)** — a whole-file or region width check is defeated by pre-existing long table rows (en `:27`) and by the protected region (en `:126`), so the criterion would either fail on lines this task must not touch or need an exception list that is itself the drift site; house style here is the reviewer's read |
| Semantic equivalence of the Japanese prose beyond the declared anchors | **info-only (not promoted to AC)** — declared out of scope in the Input space; the mechanical boundary is AC9 plus per-language anchors, and the rest is a reviewer's read |
| No new issue was opened; #26 is the tracker | **info-only (not promoted to AC)** — a provenance statement about how the task was filed |
| Re-verify the measured line numbers before editing | **info-only (not promoted to AC)** — an instruction about how to work; every criterion asserts content, never a line number |

## Assumptions

- The reference line numbers in the Measured inventory were read at `1602889`
  (`develop` head at task open). Every criterion asserts content rather than a
  line number, so a shifted line is not a failure — but re-read the sections
  before editing.
- `bin/check-prompt-sync.sh`'s `marker` mode splices `templates/prompt-blocks/playbook-*.md`
  into four `agents/*.md` consumers (registry rows 42–45, read at `1602889`). AC8
  asserts one of those rows rather than all four, because the page's claim is that
  the mechanism exists, not that it has a particular arity — and pinning the arity
  would make an unrelated fifth playbook block break this task's criterion.
- Neither `docs/tuning-oversight.md` nor `docs/tuning-oversight.ja.md` is a
  registered consumer of any prompt block (verified against
  `templates/prompt-blocks/registry.txt` at `1602889`), so no canonical region
  inside them constrains this edit.
- `develop` appears zero times in both files today (verified at `1602889`), which
  is what makes AC7's negated half a meaningful lock rather than a coincidence.
- Both files are UTF-8 with LF endings and three balanced fenced blocks each
  (six fence lines per file, verified at `1602889`) — the premise AC9's
  extraction rests on.
- The em dash used throughout both files is U+2014, and the pinned bullet literals
  in this spec carry it verbatim. A hyphen or an en dash substituted for it fails
  AC1 loudly rather than silently.

## Open questions

None blocking.

## Notes for engineer

**Build order.** Edit `docs/tuning-oversight.md` first, section by section in
page order (Fixed → the example's intro, block and substitution note → "worth
keeping" bullet, reason paragraph, trap paragraph), then mirror into
`docs/tuning-oversight.ja.md`. Copy the fenced block across as bytes — do not
retype it, and do not translate anything inside it (AC9 compares the two
extractions with `cmp`).

**The one non-obvious failure mode.** `bin/check-prompt-sync.sh` is green today and
must stay green; nothing in either file is a registered consumer, so the way to
break it is to paste a `<!-- BEGIN prompt-block: … -->` marker into a document as
illustration. Do not.

**Mutation self-check before hand-off.** These criteria are all greps and region
comparisons, so their blind spots are specific and worth probing directly: change
one character inside the ja file's fenced block (AC9 must fire); add one word to
the "more checkpoints" section (AC10 must fire); reflow one line of the Limits
paragraph (AC11 must fire); reintroduce the word `develop` in a sentence (AC7 must
fire); replace the em dash in one pinned bullet with a hyphen (AC1 must fire).
Restore each and verify byte-identity with `diff` afterwards.

**Prior art.** T-1004 edited the same two files and left the shape of a
two-language prose task in place: per-language anchors asserted independently so a
paragraph cannot be half-translated, and no en/ja parity checker exists in this
repository beyond what a criterion writes itself.
