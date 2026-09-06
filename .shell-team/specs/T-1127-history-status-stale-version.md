# `docs/history.md`'s `## Status` stops pinning a release-line version that goes stale

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1127

## Problem

`docs/history.md:26` and its mirror `docs/history.ja.md:26` open the `## Status`
paragraph by asserting that `v0.3.0` is the current release line. The shipped
version is `2.5.1` (`.claude-plugin/plugin.json:4`), so an adopter reading the
narrative page is told a release line that ended several majors ago is current.
The sentence is version-pinned by construction: every release makes it wrong
again, and nothing in the loop re-reads it.

## Summarized sources

- GitHub issue #445 (body relayed verbatim in this task's dispatch) — the located sentence, the deliverable ("replace the version-pinned sentence with wording that does not go stale … or update it and note where the current version is read from"), the instruction to move both language versions together, and the PATCH tier with "no other change". Every line restated below was re-read first-hand against this checkout.
- `docs/history.md:24-26` — read first-hand: `## Status` heading, then one paragraph whose first sentence is the version-pinned claim and whose second sentence states that board, specs and reviews are kept under version control. The second sentence is not version-dependent and is what this task preserves.
- `docs/history.ja.md:24-26` — read first-hand: `## ステータス` heading and the exact mirror, 「v0.3.0 が現行のリリースラインである。プロジェクトは board・spec・review をバージョン管理下に置き……」. Same two-sentence structure.
- `.claude-plugin/plugin.json:4` — read first-hand: `"version": "2.5.1"`. This is the file the replacement wording points at as the place the current version is read from.
- `docs/history.md:6` and `docs/history.ja.md:6` — read first-hand: each page already links its own language's changelog (`CHANGELOG.md` / `CHANGELOG.ja.md`), both of which exist in the checkout. This is why the replacement does not need to introduce a changelog link, and why `.claude-plugin/plugin.json` — absent from both files today — is the non-vacuous anchor the criteria grep for.
- `.shell-team/specs/T-1013-loop-replay-docs-wiring.md:85-86` (**AC11**) — read first-hand: the one merged criterion whose read set names `docs/history.md` and `docs/history.ja.md` outright, asserting an empty diff for them against a pinned base ref. See `## Assumptions`.

## Goal

<!-- BEGIN intent-block: T-1127 -->

- user-visible: yes — the whole deliverable is a sentence in adopter-facing documentation (`docs/history.md` and its Japanese mirror), so the change lands directly on the adopter's reading surface even though it adds no capability.
- verification-class: no-mechanism — declared by the checklist's own enumeration rather than by feel: this task's diff touches only `docs/`, reaching no path under `bin/`, `tests/`, `templates/`, no CI workflow and no checker's semantics. Every criterion below is a fixed-string presence-or-absence grep or a byte-scoped diff read.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/444-method-neutral-gates; then base=$(git merge-base refs/heads/feature/444-method-neutral-gates HEAD); elif git show-ref --verify --quiet refs/remotes/origin/feature/444-method-neutral-gates; then base=$(git merge-base refs/remotes/origin/feature/444-method-neutral-gates HEAD); else base=$(git merge-base develop HEAD); fi — this branch is stacked behind the still-open PR #446 (`feature/444-method-neutral-gates`, tip `8cfe1ea73b8a123a942aad4d640f18a3dc71463b`, read first-hand from `.git/refs/heads/`); **AC5** is the one criterion reading a base-side range and spells this expression byte-identically.
- verification-ceiling: unit-and-static — every criterion is a fixed-string grep or a byte-scoped diff over this checkout; none needs a real adopter environment, and none is marked above the ceiling.

Neither language version of `docs/history.md` states a pinned version as "the
current release line" any more. Each instead points the reader at where the
current version is actually read from, so the sentence stops going stale at every
release, while the `## Status` / `## ステータス` heading and the paragraph's
second sentence about board, specs and reviews under version control survive
unchanged. No file outside these two documents changes.

## Non-goals

- No new mechanism, checker, gate, status flag, record family or CI step. This task changes wording in two documentation files only.
- Because the deliverable changes no executing surface, this task explicitly runs **no full-population downstream sweep, no whole CI-equivalent re-run, and no behaviour verification of any mechanism it does not touch**. The read-set-scoped analysis in `## Assumptions` is what replaces them.
- The historical chapter headings and narrative naming `v0.3.0` (`docs/history.md:20,22` and the Japanese mirror) are untouched. They describe what the v0.3.0 line *was*, which is correct and is the point of a history page; only the claim that it *is current* is wrong.
- `README.md` / `README.ja.md`, `CHANGELOG.md` / `CHANGELOG.ja.md`, `.claude-plugin/plugin.json` and every other file in the repository are untouched. The version is corrected by ceasing to restate it, not by adding a second place that must be updated at release time.
- `.shell-team/**` records (board, spec, provenance, interventions, reviews) are this task's own required deliverables and are outside **AC5**'s measured set by construction; they are not part of the two-file deliverable.

## Acceptance criteria

- [ ] **AC1** (negative) Neither file still carries the version-pinned claim, in either language: the literals `v0.3.0 is the current release line` and `v0.3.0 が現行のリリースラインである` are absent from `docs/history.md` and `docs/history.ja.md`. The read's exit contract distinguishes a clean absence (exit 1) from a failed read (exit > 1), which is why a single `git grep` supplies the verdict.
  - check: cd "$(git rev-parse --show-toplevel)" || exit 3; git grep -n -F -e 'v0.3.0 is the current release line' -e 'v0.3.0 が現行のリリースラインである' -- docs/history.md docs/history.ja.md; rc=$?; test "$rc" -eq 1

- [ ] **AC2** Both files name where the current version is actually read from, anchored on the fixed literal `.claude-plugin/plugin.json` — a machine token identical in both languages. Neither file references it at authoring time (both were read end to end), so this presence check is not vacuous and cannot be satisfied by inherited text.
  - check: cd "$(git rev-parse --show-toplevel)" || exit 3; miss=0; for f in docs/history.md docs/history.ja.md; do git grep -q -F -e '.claude-plugin/plugin.json' -- "$f"; rc=$?; if [ "$rc" -ne 0 ]; then echo "missing or unreadable ($rc): $f"; miss=1; fi; done; test "$miss" -eq 0
  - adopter-surface: `docs/history.md` and `docs/history.ja.md` themselves — the adopter-facing documentation lands in this same task because it *is* this task's deliverable, not a follow-up.

- [ ] **AC3** (negative) The section survives the edit: the `## Status` heading in `docs/history.md`, the `## ステータス` heading in `docs/history.ja.md`, and each language's second sentence — `board, specs, and reviews under version control` / `board・spec・review をバージョン管理下に置き` — are each still present verbatim. This is what confines the change to the first sentence.
  - check: cd "$(git rev-parse --show-toplevel)" || exit 3; miss=0; for p in 'docs/history.md:## Status' 'docs/history.md:board, specs, and reviews under version control' 'docs/history.ja.md:## ステータス' 'docs/history.ja.md:board・spec・review をバージョン管理下に置き'; do f=${p%%:*}; s=${p#*:}; git grep -q -F -e "$s" -- "$f"; rc=$?; if [ "$rc" -ne 0 ]; then echo "missing or unreadable ($rc): $f :: $s"; miss=1; fi; done; test "$miss" -eq 0

- [ ] **AC4** (negative) The historical narrative is not collaterally scrubbed: the chapter headings `## The Oversight-model evolution (v0.3.0)` and `## Oversight モデル進化（v0.3.0）` are still present. A blanket removal of the string `v0.3.0` would be the wrong repair, and this criterion is what rejects it.
  - check: cd "$(git rev-parse --show-toplevel)" || exit 3; miss=0; for p in 'docs/history.md:## The Oversight-model evolution (v0.3.0)' 'docs/history.ja.md:## Oversight モデル進化（v0.3.0）'; do f=${p%%:*}; s=${p#*:}; git grep -q -F -e "$s" -- "$f"; rc=$?; if [ "$rc" -ne 0 ]; then echo "missing or unreadable ($rc): $f :: $s"; miss=1; fi; done; test "$miss" -eq 0

- [ ] **AC5** (negative, scope lock) Outside `.shell-team/` — this task's own required records — the changed-and-added file set is exactly `docs/history.ja.md` and `docs/history.md`. The measured set is the union of four reads spanning base→HEAD→index→worktree, each `git diff` spelled `--no-renames` so a rename's source path cannot hide, plus untracked strays a range cannot see. The base ref is resolved by the two-arm `- base-ref-discriminator:` expression declared above, spelled byte-identically. **This criterion is merge-point-scoped and is expected to go stale after merge** — once later work lands on the predecessor branch or `develop`, the resolved base no longer describes this task. Do not widen its base resolution, re-derive it per rework round, or otherwise try to keep it evergreen; merge-ranging it trades away the confinement it exists to provide.
  - check: cd "$(git rev-parse --show-toplevel)" || exit 3; if git show-ref --verify --quiet refs/heads/feature/444-method-neutral-gates; then base=$(git merge-base refs/heads/feature/444-method-neutral-gates HEAD); elif git show-ref --verify --quiet refs/remotes/origin/feature/444-method-neutral-gates; then base=$(git merge-base refs/remotes/origin/feature/444-method-neutral-gates HEAD); else base=$(git merge-base develop HEAD); fi; test -n "$base" || exit 3; got=$( { git diff --no-renames --name-only "$base"...HEAD -- . ':!.shell-team'; git diff --no-renames --cached --name-only -- . ':!.shell-team'; git diff --no-renames --name-only -- . ':!.shell-team'; git ls-files --others --exclude-standard -- . ':!.shell-team'; } | LC_ALL=C sort -u | tr '\n' ' ' ) && test "$got" = 'docs/history.ja.md docs/history.md '

## Input space

**Reachable input classes.** (1) `docs/history.md` and `docs/history.ja.md` as they stand at the branch point: UTF-8 markdown, ASCII prose plus Japanese prose, `##` headings, backtick-quoted machine tokens and bracketed relative links — the exact shapes read first-hand and quoted in `## Summarized sources`. (2) A checkout in which the predecessor branch `feature/444-method-neutral-gates` resolves as a local branch or a remote-tracking ref, or in which `develop` resolves — which is what **AC5** needs to read the branch point.

**Out-of-scope synthetic extremes.** Adversarially constructed markdown (nested fences hiding a heading, zero-width or homoglyph substitutes for the literals these criteria grep, CRLF-only variants); non-UTF-8 re-encodings of either file; a checkout that fetched neither the predecessor branch nor `develop` (a shallow or `--single-branch` clone), which is a route-back rather than a case **AC5** is redesigned to survive; any file other than the two named here; and an adopter's own local edits to these documents.

<!-- END intent-block: T-1127 -->

## Assumptions

- **Read-set-scoped downstream-impact analysis (the `no-mechanism` form).** A literal-path derivation over the merged spec corpus found exactly one criterion whose read set names these two files outright: `.shell-team/specs/T-1013-loop-replay-docs-wiring.md` **AC11**, which asserts an empty `git diff` against a pinned base for a path list including `docs/history.md docs/history.ja.md`. Editing either file drives that criterion red at HEAD if it was green at the base. **AC11 already declares itself merge-point-scoped and expected to go stale**, so this is the anticipated staleness rather than a new defect — but whether it was already red at the branch point is a measurement, not an inference. **Indirection class disclosed, not engineered around**: a merged criterion reaching these files through a directory-level pathspec (`-- docs`, `'docs'`) or a glob rather than by literal path is invisible to a literal-path search in principle. This role holds no shell, so both the AC11 base-arm verdict and the directory-pathspec candidate set are owed to the execution-capable side at the freeze run; whatever it does not run stays disclosed as unmeasured rather than claimed as covered.
- **Relayed premise — operator-approved lightweight mode** (sprint "method-neutral", approved 2026-09-06T15:04Z): pm-authored spec, one freeze, no cross-provider spec-review round, no per-task sweep. This reached this role through the dispatch and is confirmed by the coordinating session; it is not readable from this checkout.
- **Borrowed-vocabulary count-premise sweep (T-1081).** One literal count premise is asserted: `.claude-plugin/plugin.json` occurs **zero** times in `docs/history.md` and `docs/history.ja.md` at the branch point (**AC2**'s non-vacuity ground). Classification: **borrowed** — the path is pre-existing vocabulary coined by the plugin manifest, not this task's coinage. Measured by reading both files end to end on 2026-09-07; the execution-capable side re-runs it against the branch point's committed blobs before the freeze and records the value here: `git grep -c -F -e '.claude-plugin/plugin.json' "$base" -- docs/history.md docs/history.ja.md; echo rc=$?` (rc=1 with no output is the expected zero). No other count premise is asserted.
- **Line numbers move.** The `:26` locations were measured 2026-09-07. Locate each site by its quoted sentence, not by its line number.

## Open questions

None blocking.

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| The version-pinned "current release line" sentence is gone from both files | **AC1** |
| The replacement names where the current version is read from | **AC2** |
| Both language versions move together | **AC1** and **AC2** each cover both files explicitly; **AC3** covers both headings |
| The `## Status` / `## ステータス` heading and the second sentence are preserved | **AC3** |
| Historical `v0.3.0` narrative stays (only the currency claim is wrong) | **AC4** |
| No file outside the two documents changes | **AC5** |
| No new mechanism, checker, gate or CI step | **AC5** (an empty diff outside `docs/history.*` is the observable form of it) |
| No full-population sweep / CI-equivalent re-run / untouched-mechanism behaviour verification | info-only (not promoted to AC) — a declared *absence* of verification work has no artifact for a check line to read; it is the `no-mechanism` class's own pricing, recorded in `## Non-goals` and discharged by the read-set analysis in `## Assumptions` |
| Tier PATCH, "no other change" | info-only (not promoted to AC) — the release tier is a property of the sprint's release derivation, not of any file this task edits, so no check over this checkout can observe it; the "no other change" half *is* promoted, as **AC5** |

## Notes for engineer

- Two sites, one sentence each: `docs/history.md:26` (first sentence of the `## Status` paragraph) and `docs/history.ja.md:26` (first sentence under `## ステータス`). Replace the first sentence; leave the second alone.
- The non-staling form the issue prefers: drop the pinned version entirely and say where the current one is read from. `.claude-plugin/plugin.json` is the fixed anchor **AC2** greps for and must appear in both files; each page already links its own changelog at line 6 (`CHANGELOG.md` / `CHANGELOG.ja.md`, both present in the checkout), so adding a second changelog link is unnecessary — mentioning it as well is allowed but not required.
- The Japanese file is a mirror, not a translation artifact: write natural Japanese around the same machine token, exactly as line 6 already embeds a bracketed English filename.
- Do not scrub `v0.3.0` globally. `docs/history.md:20,22` and the Japanese mirror name it correctly as a past chapter; **AC4** fails if the headings go.
- **Measured-at-ref commands**: not applicable — none of this task's deliverables prints a command beside a `measured at <ref>` label.
- Prior art for the stacked two-arm base resolution and the four-read scope-lock union: `.shell-team/specs/T-1126-method-neutral-human-gates.md` **AC7**.
