# Per-cycle artifacts stop being tied to the project's language

**Status**: READY_FOR_MERGE
**Owner**: pm-spec
**Task ID**: T-1010
**Source**: GitHub issue #20 — "Operator language and project language are the same setting today, and they should not be"
**Base**: `develop` @ `4022158`
**Branch**: `feature/t-1010-operator-language`

## Problem

`bin/check-retro.sh` enforces the retro's *structure* by grepping five decorated **Japanese** H2 headings with full-line exact match, and `docs/templates/retro-template.md` — the skeleton the scrum-master agent copies — exists only in Japanese. The contract worth enforcing is "five sections, in this order, with these roles"; what is enforced is one rendering of it. An adopter who has never written a line of Japanese must still emit Japanese headings or the check fails, and the maintainer's working language is shipped into strangers' repositories through the agent prompt that instructs it. The three rules that produced this (`agents/scrum-master.md` mirrors the conversation language, `bin/check-retro.sh` hardcodes one language, `CLAUDE.md` says this repository's files are English) are each correct and collide on a file class none of them names: the artifacts the loop generates as it runs.

## Goal

<!-- BEGIN intent-block: T-1010 -->

`bin/check-retro.sh` validates a retro's structure without matching a single word of any natural language: the five sections are anchored on language-neutral markers, the visible heading text is free, and a retro whose prose is Japanese, English, or anything else passes or fails on structure alone. The shipped surface (`docs/templates/retro-template.md`, the retro contract strings in `agents/scrum-master.md`) is English, so an adopter never has to write or read Japanese to satisfy the checker. No new configuration is introduced anywhere: the operator's language is not declared, it is simply not constrained. The enumerated machine-token list is asserted by a test rather than trusted to prose.

### Settled decisions

- **D1 — structure/surface separation: option (iii), language-neutral section markers.** Each of the five sections is anchored on an HTML-comment marker; the heading beside it is free text. Option (i) (derive the headings from the template) is rejected on two measured grounds: `bin/team-init.sh` scaffolds only `<base>/retros/.gitkeep` and never distributes `docs/templates/retro-template.md` to an adopter repository, so (i) would require inventing a template-resolution order (plugin default → repo override) *and* teaching the checker to parse instructional prose in which the same headings appear both as documentation and as skeleton. Option (ii) (English canonical + per-repo override) is rejected because it keeps the fusion (it just changes which language is imposed) and needs the configuration surface D2 rules out. Option (iii) is the only one that makes the surface genuinely free for *any* language rather than for two.
- **D2 — the operator language is NOT declared.** No environment variable, no loop-contract field, no config file, no `bin/team-paths.sh` key. Under D1 the checker no longer needs to know the language, so a declaration would be a setting with no reader — and `docs/workflow.md` §Language's "zero-config — no language config file and no environment variable" statement stays true rather than needing to be walked back. The rule that replaces the setting is written into `CLAUDE.md` §Language: per-cycle artifacts are in the operator's language, and the language boundary sits at promotion into the shipped corpus (a lesson is *authored* in English at promotion time, never produced by translating an artifact).
- **D3 — the one existing retro is migrated by pure insertion.** `.shell-team/retros/2026-07-28.md` gains its five marker lines and nothing else; its Japanese headings and its prose stay byte-identical. That file is dogfooded by CI, and keeping its Japanese surface while it passes the new checker is the proof that the surface is free. The checker does **not** dual-accept the legacy marker-less shape: a pre-migration retro fails closed with a reason naming the missing marker, and the migration recipe is documented in the template for adopters.
- **D4 — the machine-token list becomes a test, extending the existing partial mechanism rather than replacing it.** `templates/prompt-blocks/registry.txt` already pins `flag-enum.md` and `verdict-labels.md` into their consumers, and `tests/check-prompt-sync/run.sh` already re-asserts a few tokens; neither covers the intent-block tokens, the prompt-block marker pair, the lesson labels, or the new marker vocabulary. A dedicated suite `tests/machine-tokens/run.sh` enumerates the full list from issue #20 plus the new vocabulary, asserts each token against the file that actually greps it, and proves it bites by a mutation self-check against a scratch copy.
- **D5 — scope is frozen to axis B's retro surface.** Everything named under Non-goals below is out, including work that is genuinely the same defect one directory over.

## Non-goals

- **Axis D (runtime strings).** `bin/gen-project-status.sh` prints Japanese (`- Active: %d 件`, the do-not-edit marker line). A zero-dependency bash localisation seam is its own design question — file it, do not smuggle it in here.
- **Axis C (shipped prompt blocks).** Already resolved by T-1007/T-1008; `templates/prompt-blocks/` carries zero CJK. Do not re-scope it.
- **The `intent-block` mechanism's Japanese vocabulary** — issue #8's range, four files, untouched here.
- **The remaining Japanese in the other checkers.** Confirmed by measurement, recorded here rather than acted on: `bin/check-provenance.sh`, `bin/check-playbook.sh`, `bin/check-acs.sh`, `bin/playbook-promote.sh` and `bin/gen-playbook-blocks.sh` carry Japanese only in comments and spec citations, never as a matched contract string. No code change.
- **`agents/ui-designer.md`'s one Japanese parenthetical**, and `agents/scrum-master.md`'s `§再評価トリガ` cross-references (they cite a section heading in `docs/loop-engineering/model-tiering.md`, which this task does not open). Both are explicitly exempted from the CJK sweep below.
- **`CHANGELOG.md` / `CHANGELOG.ja.md` and any version bump.** Release entries land through this project's release process, not per task.
- **Translating `.shell-team/retros/2026-07-28.md`'s prose, or any other existing artifact.** Translating artifacts is the recurring cost this design exists to remove.
- **Any change to `bin/team-paths.sh`, the loop-contract templates, or `bin/team-init.sh`.** D2 and D1 are what make these unnecessary; touching them is the signal that a rejected option crept back in.

## Acceptance criteria

The five section ids are `keep`, `problem`, `try`, `traps`, `lessons`, in that canonical order. The marker's frozen form is a line whose entire content, after stripping a trailing CR and trailing whitespace, is exactly `<!-- retro-section: <id> -->` — no leading whitespace, no blockquote prefix, no other text on the line. Every marker-class violation's reason line contains the literal `retro-section: <id>`. Exit codes are unchanged: 0 clean, 1 violation(s), 2 usage / unreadable.

- [ ] **AC1** `bin/check-retro.sh` no longer contains any of the five legacy decorated headings or the Japanese placeholder, and still contains the tokens it must keep (positive control).
  - check: for s in '## Keep（' '## Problem（' '## Try（' '罠の点検' 'Lesson 候補' '該当なし'; do if grep -qF -- "$s" bin/check-retro.sh; then exit 1; fi; done; grep -qF -- '## Retro inputs' bin/check-retro.sh && grep -qF -- '# Retro' bin/check-retro.sh
- [ ] **AC2** Class-level completeness: `bin/check-retro.sh` and `docs/templates/retro-template.md` contain zero CJK/kana/fullwidth bytes, while the detector is proved to fire on a file that does contain them (positive control: the migrated retro, whose prose stays Japanese by design). The em dash `—` used by the ledger grammar is outside the detected byte class and is unaffected.
  - check: test "$(LC_ALL=C tr -cd '\343-\357' < bin/check-retro.sh | wc -c | tr -d ' ')" = 0 && test "$(LC_ALL=C tr -cd '\343-\357' < docs/templates/retro-template.md | wc -c | tr -d ' ')" = 0 && test "$(LC_ALL=C tr -cd '\343-\357' < .shell-team/retros/2026-07-28.md | wc -c | tr -d ' ')" -gt 0
- [ ] **AC3** The marker vocabulary has one canonical source, `templates/prompt-blocks/retro-sections.md`, registered `contain` against the checker, the agent prompt and the template; the repository is in sync.
  - check: bash bin/check-prompt-sync.sh && awk '$1 == "contain" && $2 == "retro-sections.md" { print }' templates/prompt-blocks/registry.txt | grep -q 'bin/check-retro.sh' && awk '$1 == "contain" && $2 == "retro-sections.md" { print }' templates/prompt-blocks/registry.txt | grep -q 'agents/scrum-master.md' && awk '$1 == "contain" && $2 == "retro-sections.md" { print }' templates/prompt-blocks/registry.txt | grep -q 'docs/templates/retro-template.md'
- [ ] **AC4** That canonical block states the five marker lines verbatim, each on its own bare line, plus the empty-section placeholder token.
  - check: for id in keep problem try traps lessons; do grep -qxF -- "<!-- retro-section: $id -->" templates/prompt-blocks/retro-sections.md || exit 1; done; grep -qF -- '- (none)' templates/prompt-blocks/retro-sections.md
- [ ] **AC5** A retro with English headings and the five markers passes, and the canonical pass fixture itself is free of CJK — an adopter never has to write Japanese to satisfy the checker.
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-canonical.md && test "$(LC_ALL=C tr -cd '\343-\357' < tests/check-retro/fixtures/pass-canonical.md | wc -c | tr -d ' ')" = 0
- [ ] **AC6** Surface freedom, proved in the other direction: a retro whose five headings are Japanese and which carries the markers passes, and that fixture does contain CJK (so "passes" is not "was never examined").
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-operator-language.md && test "$(LC_ALL=C tr -cd '\343-\357' < tests/check-retro/fixtures/pass-operator-language.md | wc -c | tr -d ' ')" -gt 0
- [ ] **AC7** Bare headings are legal: a retro whose headings are `## Keep` / `## Problem` / `## Try` / … with no parenthetical passes, because the parenthetical was never the contract.
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-bare-heading.md && grep -qxF -- '## Keep' tests/check-retro/fixtures/pass-bare-heading.md
- [ ] **AC8** Fail-closed, no dual acceptance: a pre-migration retro (legacy decorated Japanese headings, no markers) exits 1 with a reason naming the marker, and the fixture is confirmed to carry no marker (positive control).
  - check: if grep -q 'retro-section' tests/check-retro/fixtures/fail-legacy-no-markers.md; then exit 1; fi; out=$(bash bin/check-retro.sh tests/check-retro/fixtures/fail-legacy-no-markers.md 2>&1 >/dev/null); rc=$?; test "$rc" -eq 1 && printf '%s' "$out" | grep -q 'retro-section:'
- [ ] **AC9** Each of the five markers is individually load-bearing: removing any one from a copy of the canonical fixture yields exit 1 with a reason naming that id, and each mutation is confirmed to have landed before the assertion is made.
  - check: for id in keep problem try traps lessons; do d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); cp tests/check-retro/fixtures/pass-canonical.md "$d/f.md"; sed -i.bak "/retro-section: $id /d" "$d/f.md"; if grep -q "retro-section: $id " "$d/f.md"; then rm -rf "$d"; exit 1; fi; out=$(bash bin/check-retro.sh "$d/f.md" 2>&1 >/dev/null); rc=$?; rm -rf "$d"; if [ "$rc" -ne 1 ]; then exit 1; fi; case "$out" in *"retro-section: $id"*) ;; *) exit 1 ;; esac; done
- [ ] **AC10** A duplicated marker id and an out-of-canonical-order marker sequence are each violations (exit 1); the ordering reason says so in words.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); awk '{ print } /retro-section: try -->/ { print }' tests/check-retro/fixtures/pass-canonical.md > "$d/dup.md"; sed -e 's|<!-- retro-section: keep -->|<!-- retro-section: ZZZ -->|' -e 's|<!-- retro-section: problem -->|<!-- retro-section: keep -->|' -e 's|<!-- retro-section: ZZZ -->|<!-- retro-section: problem -->|' tests/check-retro/fixtures/pass-canonical.md > "$d/ord.md"; bash bin/check-retro.sh "$d/dup.md" >/dev/null 2>&1; a=$?; out=$(bash bin/check-retro.sh "$d/ord.md" 2>&1 >/dev/null); b=$?; rm -rf "$d"; test "$a" -eq 1 && test "$b" -eq 1 && printf '%s' "$out" | grep -q 'out of order'
- [ ] **AC11** Near-miss marker spellings do not satisfy a section: a blockquoted marker, an indented marker, and the space-less `<!--retro-section:try-->` form each leave `try` missing (exit 1).
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); sed 's|^<!-- retro-section: try -->|> <!-- retro-section: try -->|' tests/check-retro/fixtures/pass-canonical.md > "$d/q.md"; sed 's|^<!-- retro-section: try -->|  <!-- retro-section: try -->|' tests/check-retro/fixtures/pass-canonical.md > "$d/i.md"; sed 's|<!-- retro-section: try -->|<!--retro-section:try-->|' tests/check-retro/fixtures/pass-canonical.md > "$d/n.md"; rc=0; for f in q i n; do bash bin/check-retro.sh "$d/$f.md" >/dev/null 2>&1 || rc=$((rc + 1)); done; rm -rf "$d"; test "$rc" -eq 3
- [ ] **AC12** A marker whose next non-blank line is not an H2 heading with a non-empty title is a violation (a marker floating in prose anchors nothing).
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); awk '{ print } /retro-section: try -->/ { print "not a heading" }' tests/check-retro/fixtures/pass-canonical.md > "$d/f.md"; out=$(bash bin/check-retro.sh "$d/f.md" 2>&1 >/dev/null); rc=$?; rm -rf "$d"; test "$rc" -eq 1 && printf '%s' "$out" | grep -q 'retro-section: try'
- [ ] **AC13** CRLF tolerance is proved by a malformed input, never a well-formed one (the T-1001 v2 discipline): a copy with the `traps` marker removed and converted to CRLF is still reported.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); sed '/retro-section: traps /d' tests/check-retro/fixtures/pass-canonical.md | sed 's/$/\r/' > "$d/f.md"; if grep -q 'retro-section: traps ' "$d/f.md"; then rm -rf "$d"; exit 1; fi; bash bin/check-retro.sh "$d/f.md" >/dev/null 2>&1; rc=$?; rm -rf "$d"; test "$rc" -eq 1
- [ ] **AC14** The lesson-label rule keys off the `lessons` marker, and its empty-section placeholder is the English machine token: an unlabelled bullet fails, a lone `- (none)` passes, and a lone `- (該当なし)` is no longer a placeholder (it is an unlabelled bullet and fails).
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/fail-bare-lesson.md >/dev/null 2>&1; a=$?; bash bin/check-retro.sh tests/check-retro/fixtures/pass-lessons-none.md >/dev/null 2>&1; b=$?; bash bin/check-retro.sh tests/check-retro/fixtures/fail-legacy-placeholder.md >/dev/null 2>&1; c=$?; grep -qxF -- '- (none)' tests/check-retro/fixtures/pass-lessons-none.md && test "$a" -eq 1 && test "$b" -eq 0 && test "$c" -eq 1
- [ ] **AC15** Rules 1 and 4 are untouched in behavior: the H1 reason and the ledger's violation reasons are still emitted verbatim by the checker.
  - check: for s in "first non-empty line is not '# Retro" 'ledger-shaped line outside the ## Retro inputs section' 'duplicated ## Retro inputs section heading' 'unknown Retro inputs status' 'whitespace-only Retro inputs detail'; do grep -qF -- "$s" bin/check-retro.sh || exit 1; done
- [ ] **AC16** Every suite that consumes the retro contract stays green, including the two that build a retro inline and the one that runs the retro suite as its own invariant.
  - check: bash tests/check-retro/run.sh >/dev/null && bash tests/retro-inputs/run.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null
- [ ] **AC17** The template is a validated artifact rather than prose about one: `docs/templates/retro-template.md` carries the five markers in canonical order and passes the checker, and CI dogfoods that.
  - check: bash bin/check-retro.sh docs/templates/retro-template.md && test "$(grep -o 'retro-section: [a-z]*' docs/templates/retro-template.md | head -5 | tr '\n' ' ')" = "retro-section: keep retro-section: problem retro-section: try retro-section: traps retro-section: lessons " && grep -q 'check-retro.sh docs/templates/retro-template.md' .github/workflows/check-handoff.yml
- [ ] **AC18** The template documents how to migrate a retro written before the marker contract, so an adopter is not left to infer it from a failing check.
  - check: grep -qiF -- 'migrating an older retro' docs/templates/retro-template.md
- [ ] **AC19** The existing retro is migrated by pure insertion: zero deleted lines, its five Japanese headings byte-identical, and it still passes.
  - check: test "$(git diff --numstat 4022158 -- .shell-team/retros/2026-07-28.md | awk '{ print $2 }')" = "0" && for s in '## Keep（続けたい良い動き）' '## Problem（直面した課題 / 痛み）' '## Try（次サイクルで試すこと）' '## 罠の点検（Comprehension Debt / Cognitive Surrender）'; do grep -qxF -- "$s" .shell-team/retros/2026-07-28.md || exit 1; done && bash bin/check-retro.sh .shell-team/retros/*.md
- [ ] **AC20** `agents/scrum-master.md` instructs the marker vocabulary instead of the Japanese headings: the five markers and `- (none)` are present, the retro contract strings that made Japanese mandatory are gone, and the only CJK left is the declared `再評価トリガ` cross-reference exemption.
  - check: for id in keep problem try traps lessons; do grep -qF -- "<!-- retro-section: $id -->" agents/scrum-master.md || exit 1; done; grep -qF -- '- (none)' agents/scrum-master.md || exit 1; for s in '## Keep（' '罠の点検' 'Lesson 候補' '該当なし' 'サマリ' 'five decorated H2 headings'; do if grep -qF -- "$s" agents/scrum-master.md; then exit 1; fi; done; test "$(grep -vF -- '再評価トリガ' agents/scrum-master.md | LC_ALL=C tr -cd '\343-\357' | wc -c | tr -d ' ')" = "0"
- [ ] **AC21** The enumerated machine-token list from issue #20 is asserted by a test rather than trusted to prose: `tests/machine-tokens/run.sh` exists, passes at the repository root, and accepts `--root DIR` so it can be pointed at a scratch tree.
  - check: bash tests/machine-tokens/run.sh >/dev/null && d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX") && cp -R bin agents templates "$d/" && bash tests/machine-tokens/run.sh --root "$d" >/dev/null; rc=$?; rm -rf "$d"; test "$rc" -eq 0
- [ ] **AC22** That suite is proved to bite rather than to be vacuous: mutating one token in each of three distinct groups — a status flag, an intent-block token, and a retro section marker — in a scratch copy makes it fail each time, and each mutation is confirmed to have landed first.
  - check: rc=0; for pair in "bin/check-handoff.sh|READY_FOR_MERGE|MERGE_JUNBI_KANRYO" "bin/check-intent.sh|intent-hash|intent-hasshu" "bin/check-retro.sh|retro-section: traps|retro-section: wana"; do f=${pair%%|*}; rest=${pair#*|}; old=${rest%%|*}; new=${rest#*|}; d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); cp -R bin agents templates "$d/"; sed -i.bak "s|$old|$new|g" "$d/$f"; if grep -qF -- "$old" "$d/$f"; then rm -rf "$d"; exit 1; fi; bash tests/machine-tokens/run.sh --root "$d" >/dev/null 2>&1; m=$?; if [ "$m" -ne 1 ]; then rc=$((rc + 1)); fi; rm -rf "$d"; done; test "$rc" -eq 0
- [ ] **AC23** CI runs what this task added, in the workflow that is the authoritative suite list: the new suite is in the shellcheck argument list and has its own step, and every touched script is shellcheck-clean.
  - check: grep -q 'tests/machine-tokens/run.sh' .github/workflows/check-handoff.yml && grep -q 'bash tests/machine-tokens/run.sh' .github/workflows/check-handoff.yml && shellcheck bin/check-retro.sh tests/check-retro/run.sh tests/retro-inputs/run.sh tests/machine-tokens/run.sh
- [ ] **AC24** `CLAUDE.md` §Language names the third file class and states where the language boundary sits, so the gap that produced this issue is closed in the file whose test ("who reads the file") had no answer for it.
  - check: grep -qF -- "the operator's language" CLAUDE.md && grep -qF -- 'promotion into the shipped corpus' CLAUDE.md
- [ ] **AC25** Both language versions of the adopter-facing workflow doc say the same thing about generated artifacts, and each keeps its zero-config claim — which D2 leaves true.
  - check: grep -qF -- 'retro-section:' docs/workflow.md && grep -qF -- 'retro-section:' docs/workflow.ja.md && grep -qF -- 'zero-config' docs/workflow.md && grep -qF -- '設定ファイルも環境変数も無く' docs/workflow.ja.md
- [ ] **AC26** D2 is locked negatively: no configuration surface was added anywhere — the resolver and the contract templates are untouched, and no language environment variable exists in the shipped tree (positive control: the same sweep finds a token that is genuinely there).
  - check: test -z "$(git diff --name-only 4022158 -- bin/team-paths.sh bin/team-init.sh templates/shell-team.contract.yaml templates/loop-contract-template.yaml templates/goal.contract.yaml)" && test "$(grep -rIlE 'SHELL_TEAM_(LANG|LANGUAGE|LOCALE)|OPERATOR_LANG' bin agents skills templates | wc -l | tr -d ' ')" = "0" && test "$(grep -rIl 'READY_FOR_MERGE' bin agents skills templates | wc -l | tr -d ' ')" != "0"
- [ ] **AC27** Scope lock: the branch's changed-file set is exactly the allow-list below. **This criterion is merge-point-scoped and is expected to go stale after merge** — once later work lands on `develop`, `git diff 4022158` no longer describes this task; do not re-base or widen it to keep it evergreen.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1010.XXXXXX"); git diff --name-only 4022158 | sort > "$d/actual.txt"; printf '%s\n' .github/workflows/check-handoff.yml .shell-team/retros/2026-07-28.md .shell-team/specs/T-1010-operator-language-boundary.md .shell-team/todo.md CLAUDE.md agents/scrum-master.md bin/check-retro.sh docs/templates/retro-template.md docs/workflow.ja.md docs/workflow.md templates/prompt-blocks/registry.txt templates/prompt-blocks/retro-sections.md tests/machine-tokens/run.sh tests/retro-inputs/run.sh | sort > "$d/required.txt"; miss=$(comm -13 "$d/actual.txt" "$d/required.txt" | grep -c .); extra=$(comm -23 "$d/actual.txt" "$d/required.txt" | grep -vE '^(tests/check-retro/|\.shell-team/(provenance|reviews)/T-1010\.md|\.shell-team/test-recipe\.md)' | grep -c .); rm -rf "$d"; test "$miss" = "0" && test "$extra" = "0"
- [ ] **AC28** The task's records exist and the board entry lints.
  - check: test -r .shell-team/provenance/T-1010.md && test -r .shell-team/reviews/T-1010.md && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" && bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop
- [ ] **AC29** Every suite and dogfood step in `.github/workflows/check-handoff.yml` was run locally, in the order the workflow runs them, and the result is recorded in the hand-off. No `check:` — this is the "the whole list was actually run" property, and no command can prove that a command was run. `SKIP` is its expected `check-acs.sh` result.

## Input space

**Reachable input classes** — what real usage produces, and the implementation must handle correctly:

- Retro markdown written by the scrum-master agent from the template, in any natural language, with LF line endings; and the same files edited on Windows or by a CRLF-normalising editor (CRLF).
- Structurally incomplete retros: one or more markers missing, a marker id duplicated, markers present but out of canonical order, a marker with no heading after it, a marker inside a blockquote or indented under a list item (a markdown editor's reflow does this), and the space-less `<!--retro-section:keep-->` spelling a human types from memory. All are rejected fail-closed.
- Pre-migration retros: the legacy decorated-heading shape with no markers at all — this repository's own history and every adopter's existing retros.
- Retro bodies containing the ledger grammar quoted inside prose, section headings quoted inside blockquotes, and fenced code blocks — the existing "a decorated heading in prose does not satisfy the check" property generalises to markers.
- Empty files, files with no `## ` heading at all, and unreadable / non-existent paths (exit 2).
- The template itself, and the eleven ledger fixtures, run through the checker as first-class inputs.

**Out-of-scope synthetic extremes** — declined deliberately, and not grounds for a finding:

- Non-UTF-8 encodings (UTF-16, Shift_JIS, Latin-1 byte soup). The checker reads bytes and will report a structural violation; producing a *correct* diagnosis for a mis-encoded file is not protected.
- Marker lines using Unicode whitespace lookalikes (NBSP, ideographic space, zero-width joiner) inside or around the marker, and bidi / RTL control characters embedded in headings. The marker form is byte-exact; anything else is "missing marker", full stop.
- Retro files at pathological scale (tens of MB, thousands of sections, deeply nested markdown) and adversarially generated markdown that exercises HTML-block parsing rules no markdown a person or this agent writes would contain.
- Nested or overlapping section regions (a marker inside another section's fenced block claiming to open a section). One flat pass over `## ` boundaries is the model; a markdown parser is not being written here.
- Language detection of any kind. Nothing in this task inspects, guesses, or validates which language the prose is in — that is the whole point.

<!-- END intent-block: T-1010 -->

## Body-to-AC correspondence

Every normative directive stated in the body above, mapped to the criterion that enforces it or to an explicit exemption.

| Body directive | Where | AC / disposition |
|---|---|---|
| Structure anchored on language-neutral markers, heading free text (D1 option iii) | Goal, D1 | AC5, AC6, AC7, AC9 |
| Option (i) rejected — no template-resolution order, no template distribution | D1 | AC26 (`bin/team-init.sh` untouched) |
| Option (ii) rejected — no per-repo override | D1 | AC26 (no config surface) |
| Marker form frozen: exact line, no leading whitespace, no blockquote prefix | AC preamble | AC11 |
| Five ids, canonical order enforced | AC preamble | AC9, AC10 |
| Violation reason contains `retro-section: <id>` | AC preamble | AC8, AC9, AC12 |
| Exit codes unchanged (0/1/2) | AC preamble | AC16 (`tests/errexit-safe` pins the exit-2 case; the suites stay green) |
| No language declaration anywhere (D2) | D2 | AC26 |
| `docs/workflow.md`'s zero-config claim stays true | D2 | AC25 |
| Rule written into `CLAUDE.md` §Language | D2 | AC24 |
| Language boundary sits at promotion, not at the artifact | D2 | AC24 |
| Existing retro migrated by pure insertion, prose untouched | D3 | AC19 |
| No dual acceptance of the legacy shape | D3 | AC8 |
| Migration recipe documented for adopters | D3 | AC18 |
| Machine-token list asserted by a test, not prose (D4) | D4 | AC21, AC22 |
| Single canonical source for the marker vocabulary | D4, Goal | AC3, AC4 |
| Shipped surface is English (template, agent prompt) | Goal | AC2, AC5, AC20 |
| Checker carries no natural-language contract string | Goal | AC1, AC2 |
| Axis D / axis C / issue #8 / `ui-designer.md` out of scope | Non-goals | AC27 (scope lock) |
| Other checkers' Japanese is comment-only — recorded, not acted on | Non-goals | info-only (not promoted to AC) — a measurement carried forward from the tech-lead's routing map; the corresponding *action* is "no code change", which AC27's scope lock already enforces by excluding those files |
| `agents/scrum-master.md`'s `§再評価トリガ` cross-references exempted from the CJK sweep | Non-goals | AC20 (the exemption is written into the check itself) |
| `CHANGELOG` / version bump excluded | Non-goals | AC27 |
| `bin/` stays pure bash, zero-dependency, shellcheck-clean | repo contract | AC23 |
| Checkers fail closed | repo contract | AC8, AC9, AC11, AC12, AC13 |
| All CI suites run in CI order | Notes for engineer | AC29 (runtime, SKIP by design) |

## Assumptions

- **All 28 live `check:` lines were executed against the pre-implementation tree (base `4022158` plus this spec and the board entry) before the intent-hash was recorded** (`pm-spec` has no shell in this role; the orchestrator ran them, 2026-07-31). Three corrections were made at that step, meaning preserved: (1) the `LC_ALL=C grep -c $'[\xe3-\xef]'` byte-class detector matched nothing on this host — its PATH `grep` is ugrep 7.5.0, which is UTF-8-native — so AC2/AC5/AC6/AC20 were rewritten to the byte-oriented `LC_ALL=C tr -cd '\343-\357' | wc -c` sweep (measured: 5664 bytes on the migrated retro, 0 on ASCII, 0 on `—`/`✓`/curly quotes, 124 on the pre-change `bin/check-retro.sh`; AC20's exemption became a `grep -vF` line filter ahead of the sweep); (2) AC19's final `; bash bin/check-retro.sh` discarded the numstat and heading clauses' failures — joined with `&&`; (3) AC22 counted a missing suite (exit 127) as "the mutation was caught" — it now requires the mutated run to exit exactly `1` (violation), so a vacuous pass on an absent or crashing suite is impossible. The other flagged shapes measured fine: `sed -i.bak`, AC17's `grep -o … | head -5 | tr`, `comm` in AC27, and AC16's three suites complete in ~18s, well inside `check-acs.sh`'s 120s cap.
- Measured pre-implementation results on that tree: **AC15, AC16 and AC26 pass** (AC15 quotes strings the current checker already carries; AC16 is an invariant — the consuming suites are green before and must stay green after; AC26 is a negative lock — nothing it forbids exists yet, and the change must keep it that way). AC28's two linters pass with the new board entry, but AC28 as a whole fails on the missing provenance/review records. Every other criterion is a change detector and fails pre-implementation.
- The marker vocabulary `<!-- retro-section: … -->` does not collide with `<!-- BEGIN prompt-block: … -->`; `bin/check-prompt-sync.sh` keys on `prompt-block:` and has been read to confirm it.
- `bin/check-prompt-sync.sh` supports `--root`, so registering a new block needs no new mechanism (verified in its usage block).
- No CI step or test asserts the number of rules in `templates/prompt-blocks/registry.txt`, so adding one is additive (unverified by execution; the engineer confirms with the `check-prompt-sync` suite).

## Open questions

None blocking. One deferred judgment is recorded for the record: whether the five marker ids should later be reused to anchor other generated artifacts (review records, provenance) is a real question and is deliberately not answered here — this task ships the mechanism for retros only, and generalising it without a second consumer would be speculative.

## Notes for engineer

**Run every suite in `.github/workflows/check-handoff.yml`, in the order the workflow lists them — not just the ones you touched.** That file is the authoritative list (`CONTRIBUTING.md` §"Run the suites locally before pushing"); `.shell-team/test-recipe.md` records how to run one, and you may append a procedure you establish there.

Scope-lock allow-list (the files you may change; `tests/check-retro/**`, `.shell-team/provenance/T-1010.md`, `.shell-team/reviews/T-1010.md` and `.shell-team/test-recipe.md` are permitted in addition, the last one not required):

```
bin/check-retro.sh
tests/check-retro/run.sh
tests/check-retro/fixtures/**            (all 17 existing, plus the new ones named in the ACs)
tests/retro-inputs/run.sh                (builds a retro inline at its "adversarial" case — needs markers)
tests/machine-tokens/run.sh              (new)
templates/prompt-blocks/retro-sections.md (new)
templates/prompt-blocks/registry.txt
docs/templates/retro-template.md
agents/scrum-master.md
CLAUDE.md
docs/workflow.md
docs/workflow.ja.md
.github/workflows/check-handoff.yml
.shell-team/retros/2026-07-28.md
.shell-team/todo.md
.shell-team/specs/T-1010-operator-language-boundary.md
```

Mechanically-coupled companions, listed up front so none of them forces a re-freeze later:

- **H1 — `.github/workflows/check-handoff.yml` has two coupled lists.** The `shellcheck` step's argument list must gain `tests/machine-tokens/run.sh`, *and* the suite needs its own `run:` step; the template dogfood of AC17 is a third addition. Missing any of them is a green local run and a red CI.
- **H2 — `tests/retro-inputs/run.sh` builds a retro inline** (its "the emitted ledger embedded in a retro passes check-retro.sh" case, around line 348) using the five legacy headings. It will fail the moment markers become mandatory. `tests/retro-inputs/invariants.sh` does *not* build one (measured).
- **H3 — `tests/check-prompt-sync/run.sh` runs `tests/check-retro/run.sh` as its own AC8** and greps `# Retro` out of `bin/check-retro.sh`. Both survive this change, but a break in the retro suite surfaces there too — do not chase it as a second defect.
- **H4 — `tests/errexit-safe/run.sh` pins `check-retro.sh … 2 /nonexistent/xyz-errexit.md`.** The unreadable-file exit-2 path must not change shape.
- **H5 — `docs/templates/retro-template.md` is a `contain` consumer of `retro-inputs.md`** (registry line 39). Translating it must leave every non-empty line of that canonical block byte-intact, including the sentence "empty means the input was consulted and held nothing…". The same applies to `bin/check-retro.sh`'s comment block and to `agents/scrum-master.md`.
- **H6 — `agents/scrum-master.md` is a `contain` consumer of `language.md`.** Its §Language *tail* is role-specific and yours to rewrite; the shared core lines above it must stay verbatim or `check-prompt-sync` fails.
- **H7 — the eleven ledger fixtures also need markers.** They exercise rule 4 but must still satisfy rules 2 and 3, or every one of them starts failing for the wrong reason.
- **H8 — three existing fixtures invert meaning.** `fail-bare-heading.md` becomes legal (that is AC7's `pass-bare-heading.md`); `fail-missing-section.md` / `fail-missing-traps.md` become missing-*marker* cases; `fail-heading-in-prose.md`'s point survives as a marker-in-prose case. Rename rather than silently repurpose — a fixture whose name says `fail` and which passes is how a suite goes quietly vacuous.
- **H9 — `## Active` is empty on `develop`.** The board entry must be a pure insertion that leaves the `## Done` heading and every existing id untouched; `bin/check-board-headings.sh --base develop` is the only check that notices an overwritten id.
- **H10 — self-hosting.** This spec quotes the strings it forbids. Every negative grep in the ACs is scoped to a named file or to `bin agents skills templates` — never repository-wide — and each carries a positive control. Keep it that way in any check you add.

On the new suite's shape: `tests/machine-tokens/run.sh` asserts, per group, that each token appears verbatim in the file that actually greps it — status flags in `bin/check-handoff.sh` and `templates/prompt-blocks/flag-enum.md`; verdict labels in `bin/goal-state.sh` and `templates/prompt-blocks/verdict-labels.md`; every non-empty line of `templates/prompt-blocks/board-line-format.md` in `bin/check-handoff.sh`; `intent-block` / `intent-hash` / `intent-ratified` / `<!-- BEGIN intent-block:` / `<!-- END intent-block:` in `bin/check-intent.sh`; `<!-- BEGIN prompt-block:` / `<!-- END prompt-block:` in `bin/check-prompt-sync.sh`; the lesson labels `[common]` / `[target-specific]` in `bin/check-retro.sh` and `agents/scrum-master.md`; and the retro contract tokens (`# Retro`, `## Retro inputs`, `- input: `, the five markers, `- (none)`) in `bin/check-retro.sh`. Note that `bin/check-playbook.sh` does **not** carry the lesson labels — the shipped corpus uses the `Category` / `Scope` schema, so do not assert them there (measured, not assumed). Fail closed: a consumer that cannot be read is exit 2, never a silent pass.

**Mutation self-check before hand-off.** You are writing a lock. Before submitting for review, break it deliberately in at least the three ways AC22 names, observe the FAIL, restore, observe the PASS, and report that you did — a lock nobody has watched fail is a lock nobody has tested.

**Prior art**: `bin/check-prompt-sync.sh` for the `--root` argument shape and the `contain` registry pattern; `tests/check-retro/run.sh` lines 109–179 for the mutate-a-copy-and-prove-the-mutation-landed idiom; `templates/prompt-blocks/retro-inputs.md` for a vocabulary block that is a single source across four consumers.
