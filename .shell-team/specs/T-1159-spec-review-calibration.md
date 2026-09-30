# The Specify-seam spec review states its verdict scope and severity calibration at every round

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1159

**Branch**: `feature/631-spec-review-calibration`, cut from `develop` at `db8c2797` (relayed; see `## Assumptions`). Not stacked: T-1158 is already merged into `develop`, so there is no open predecessor and the base-side reads in **AC1**–**AC4**, **AC6**–**AC8** resolve `develop`'s merge-base directly.

## Problem

`skills/run/SKILL.md` step 6 tells the orchestrator to state, in every review briefing, what gates the verdict and that process or records findings are notes or fast-follows rather than `Blocker`/`Major`. The Specify-seam spec-review gate and `agents/code-reviewer.md`'s spec-review mode have no counterpart, so a spec review applies full adversarial depth to every surface by default. One surface this matters for is the adversarial completeness of an enumerative inline `- check:` line: a static list of rejected shapes always admits one more mutation it does not reject. The project has already judged that class unattainable and not verdict-gating, but that judgment never shipped. Relayed motivation only, not a premise any criterion rests on: an adopter run is reported to have spent many consecutive `REQUEST_CHANGES` rounds on exactly that class.

## Summarized sources

- GitHub issue #631. **Relayed verbatim by the coordinating session, not read by this role.** Distinctions carried over: the verdict is gated by (1) the spec's domain premises, (2) whether each criterion's check measures what its prose claims, and (3) material instrument defects; the adversarial completeness of an enumerative check line (one more mutation it does not reject) is reported as a note or fast-follow, not as a Blocker/Major, **unless the gap makes the criterion vacuous**; the reviewer's independence over findings is untouched, exactly as at step 6; the pricing goes in shipped prose (the run skill's spec-review gate and the code-reviewer's spec-review mode), not in adopter configuration; stopping churn that happens anyway belongs to #630 and is out of scope here.
- `skills/run/SKILL.md` (read first-hand at `:56`, `:57`, `:106`). Distinctions: `:106` is the step-6 bullet beginning `**Verdict scope and severity calibration in the review briefing**`. It scopes the verdict, states severity calibration up front, and keeps findings independence ("never ask it to withhold a finding, to lower a severity it judges, or to leave a surface unexamined"; out-of-scope findings are "recorded and dispositioned rather than discarded"). This is the shape S1 mirrors, and the bullet stays byte-unchanged. `:56` is the single line holding the `**Specify-seam spec-review gate (T-1092)**` bullet. It carries no `enumerative`, `fast-follow`, `vacuous`, `Blocker` or `Major` today. `:57` begins the next sibling bullet, `**Verification-ceiling declaration gate (T-1093)**`. Each of these three anchors occurs exactly once in the file.
- `agents/code-reviewer.md` (read first-hand at `:160`–`:219`). Distinctions: `## Spec-review mode (specify seam, T-1092)` (`:168`) runs up to `## Rules` (`:212`). The mandate (`:176`) is domain premises plus "test the right thing rather than merely testable things", and nothing in it calibrates severity. The spec-review `codex exec` prompt is at `:185`–`:189`. Its output contract is `Return findings as a JSON array of {severity, criterion, issue, suggestion}.` The bold-led paragraphs `**Conditional entry**`, `**Input, and why it is not a branch diff**`, `**Verdict and record shape**`, `**Route-back**` and `**Capability and boundary, unchanged**` each occur exactly once. None of `enumerative`, `fast-follow`, `vacuous`, `independence` occurs inside the section; the file's `fast-follow` occurrences (`:143`–`:146`) sit in the default mode's output block, outside it.
- `tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt` (read first-hand, 6 lines). Distinction: this is the frozen copy of the spec-review codex block, with the marker on line 1, the `codex exec … -o "<RAW_OUT>" \` invocation on line 2 and the prompt on lines 3–6. The prompt lines are stored de-indented relative to the agent file.
- `tests/codex-skeleton-hygiene/run.sh` (grepped at `:838`–`:879`, `:1424`–`:1445`, `:1470`–`:1499`). Distinctions: `verify_block_verbatim` diffs the extracted third `# T-107-step: codex` block of `agents/code-reviewer.md` against the fixture and fails on any difference ("update the fixture in the SAME commit"). `:847` pins the count of bare `codex exec ` lines in `agents/code-reviewer.md` at exactly 3.
- `tests/codex-agents/run.sh` (grepped at `:286`–`:311`). Distinction: the generated Codex agent's `developer_instructions` body must be byte-identical to `agents/code-reviewer.md`'s body. The generator reads the agent file, so no generator change is needed.
- `templates/prompt-blocks/registry.txt` (grepped). Distinctions: `skills/run/SKILL.md` and `agents/code-reviewer.md` are both `contain`/`marker` consumers of registered blocks, so an edit inside a registered block's bytes fails `bin/check-prompt-sync.sh`. Neither S1 nor S2 is generated from a prompt block.
- `docs/adopting.md` (read first-hand at `:605`–`:618`, `:1083`–`:1128`) and `docs/adopting.ja.md` (read first-hand at `:1055`–`:1088`). Distinctions: `## Electing a spec review at the Specify seam (T-1092)` / `## Specify seam で spec review を elect する（T-1092）` is the adopter-facing section on the spec-review axis, and today it says nothing about severity calibration. `README.md:225` and `docs/workflow.md:53` link to these headings by anchor. `:605`–`:618` already documents that generated Codex agent TOMLs go stale when a role file changes, and how to detect and re-run that. The ja section's final sentence still says the axis "has never fired end to end", which the en section contradicts. That is a pre-existing parity gap outside this task (see `## Notes for engineer`).
- `README.md:225`, `README.ja.md:225`, `docs/workflow.md:53`, `docs/workflow.ja.md:53` (read first-hand). Distinction: each summarizes the axis (its values, when to elect it, and that it is never one of the two gates) and says nothing about calibration. Each stays true after this task.
- `bin/check-adopter-docs.sh` (behaviour as stated in the pm-spec contract, not re-read here). Distinction: a `- shipped-docs:` disposition is exactly `this-task` or `issue #<N>`. Each `this-task` path must occur as a literal substring in a `- check:` or `- adopter-surface:` line of the same spec.

## Goal

<!-- BEGIN intent-block: T-1159 -->

- user-visible: yes — every adopter that elects `spec-review — cross-provider` now gets a spec review whose verdict is gated by domain premises, whether each criterion's check measures what its prose claims, and material instrument defects. An enumerative check line's adversarial completeness is reported as a note or fast-follow unless the gap makes the criterion vacuous. Nothing new becomes possible; the change calibrates an existing elective round on the shipped path, so the tier is PATCH.
- verification-class: mechanism — the diff reaches executing surfaces: a fixture under `tests/`, the prompt text a `codex exec` invocation sends, and orchestrator instructions in `skills/run/SKILL.md` that `bin/check-prompt-sync.sh` enforces.
- verification-ceiling: unit-and-static — every criterion is settled in a plain checkout by string presence or absence in a named region of a shipped file or of its base blob read with `git show`, by a byte comparison against that base blob, by a shipped suite's or checker's exit code, or by a `git diff` / `git ls-files` read. No criterion needs a live Codex call, a real adopter repository or a live spec-review round.
- base-ref-discriminator: not-applicable — no open predecessor: the branch is cut directly from `develop` (T-1158 is merged). Base-side reads resolve `git merge-base develop HEAD` (local branch) or `git merge-base refs/remotes/origin/develop HEAD` where only the remote-tracking ref exists, selected by `git show-ref --verify --quiet`.
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: agents/code-reviewer.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task

**Goal (one sentence).** At every spec-review round, the Specify-seam spec-review gate in `skills/run/SKILL.md` (S1), `agents/code-reviewer.md`'s spec-review mode prose (S2) and that mode's `codex exec` prompt (S3) each state four things. (a) What gates the verdict: the spec's domain premises, whether each criterion's `- check:` line measures what its prose claims, and material instrument defects. (b) That the adversarial completeness of an enumerative check line, meaning one more mutation it does not reject, is reported as a note or fast-follow rather than as a `Blocker` or `Major`. (c) The exception: a gap that makes that line's own criterion vacuous. (d) That the reviewer's independence over findings is untouched, with nothing withheld, no severity lowered and no surface left unexamined. The adopter-facing section of `docs/adopting.md` and `docs/adopting.ja.md` says the same, and step 6's calibration bullet stays byte-unchanged.

## Non-goals

- **No round cap or same-class escalation at the Specify seam.** Stopping churn that happens anyway is #630. (**AC8**: no `bin/` path is in the allow-list)
- **No `bin/` checker, and no change to `bin/check-spec-review.sh`'s verdict grammar**, the `### Codex Spec-Review verdict:` heading, the capture stems, the route-back or the write boundary. (**AC7**, **AC8**)
- **No change to any dispatch axis or its values**, and no change to `docs/loop-engineering/specify-seam-review.md`. (**AC8**)
- **No change to step 6's review-briefing bullet.** S1 mirrors its shape and does not edit it. (**AC4**)
- **No change to the spec-review prompt's invocation line or output contract.** Only the prompt's instruction text grows, and it gains no `$`, no backtick and no command substitution. (**AC3**)
- **No adopter configuration knob.** The calibration is shipped prose, on by default. (**AC8**: no `templates/` path)
- **No Codex-host generator change.** Generated agents pick up the new prose from `agents/code-reviewer.md`, and their staleness path is already documented. (**AC5** via `tests/codex-agents/run.sh`, **AC8**)
- **No per-task full-population two-arm sweep.** It runs once at the release under the operator's standing A2 mode. (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`. Named regions:

- **S1 region**: the lines of `skills/run/SKILL.md` from the one containing `- **Specify-seam spec-review gate (T-1092)**:` up to, not including, the one containing `- **Verification-ceiling declaration gate (T-1093)**:`.
- **S2 region**: the lines of `agents/code-reviewer.md` after the line `## Spec-review mode (specify seam, T-1092)` up to, not including, the line `## Rules`, with every fenced-code line excluded.
- **S3**: prompt lines 3 onward of `tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt`. The live block in `agents/code-reviewer.md` is held equal to that fixture by **AC5**'s suite.

- [ ] **AC1** S1 carries the orchestrator's briefing duty with all four clauses. The S1 region states the duty applies at `every round`. It names `domain premise`, `prose claims`, `instrument defect` (clause a), `enumerative`, `fast-follow`, `Blocker` and `Major` (clause b), `vacuous` (clause c), and `independence` and `withhold` (clause d). Positive control on the delta: the base blob's S1 region is non-empty and contains neither `enumerative` nor `fast-follow`. Each anchor line occurs exactly once.
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac1.XXXXXX") || exit 1; A='- **Specify-seam spec-review gate (T-1092)**:'; Z='- **Verification-ceiling declaration gate (T-1093)**:'; test "$(grep -cF -- "$A" "$S" || true)" = 1 || rc=1; test "$(grep -cF -- "$Z" "$S" || true)" = 1 || rc=1; awk -v a="$A" -v z="$Z" 'index($0,a){f=1} index($0,z){f=0} f' "$S" > "$T/r"; test -s "$T/r" || rc=1; for w in 'every round' 'enumerative' 'fast-follow' 'vacuous' 'independence' 'withhold' 'prose claims' 'instrument defect'; do grep -qiF -- "$w" "$T/r" || rc=1; done; for w in 'Blocker' 'Major' 'domain premise'; do grep -qF -- "$w" "$T/r" || rc=1; done; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; awk -v a="$A" -v z="$Z" 'index($0,a){f=1} index($0,z){f=0} f' "$T/b" > "$T/br"; test -s "$T/br" || rc=1; test "$(grep -ciF -- 'enumerative' "$T/br" || true)" = 0 || rc=1; test "$(grep -ciF -- 'fast-follow' "$T/br" || true)" = 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** S2 carries the reviewer-side statement with all four clauses, in prose outside the code fences. The S2 region names `prose claims`, `instrument defect` (clause a), `enumerative`, `fast-follow`, `Blocker` and `Major` (clause b), `vacuous` (clause c), and `independence` and `withhold` (clause d). Positive controls: the region is non-empty and excludes the fenced blocks (the fenced-only `--alloc --stem T-XXX-codex-specreview` does not occur in it), and the base blob's S2 region is non-empty and contains neither `enumerative` nor `fast-follow`. Each boundary heading occurs exactly once.
  - check: rc=0; S=agents/code-reviewer.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac2.XXXXXX") || exit 1; H='## Spec-review mode (specify seam, T-1092)'; test "$(grep -cxF -- "$H" "$S" || true)" = 1 || rc=1; test "$(grep -cxF -- '## Rules' "$S" || true)" = 1 || rc=1; X='index($0,h)==1{f=1;next} f&&index($0,"## Rules")==1{f=0} f&&index($0,sprintf("%c%c%c",96,96,96))==1{c=!c;next} f&&!c'; awk -v h="$H" "$X" "$S" > "$T/r"; test -s "$T/r" || rc=1; test "$(grep -cF -- '--alloc --stem T-XXX-codex-specreview' "$T/r" || true)" = 0 || rc=1; for w in 'enumerative' 'fast-follow' 'vacuous' 'independence' 'withhold' 'prose claims' 'instrument defect'; do grep -qiF -- "$w" "$T/r" || rc=1; done; for w in 'Blocker' 'Major'; do grep -qF -- "$w" "$T/r" || rc=1; done; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; awk -v h="$H" "$X" "$T/b" > "$T/br"; test -s "$T/br" || rc=1; test "$(grep -ciF -- 'enumerative' "$T/br" || true)" = 0 || rc=1; test "$(grep -ciF -- 'fast-follow' "$T/br" || true)" = 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC3** S3, the prompt Codex actually receives, carries clauses a–c without changing its invocation or output contract. The fixture's prompt lines (3 onward) name `instrument` (clause a), `enumerative` and `fast-follow` (clause b), and `vacuous` (clause c). They contain no `$` and no backtick. The fixture's lines 1–2 (the marker and the `codex exec` invocation line) and its last line (the `Return findings as a JSON array …` output contract) are byte-equal to the base blob's. Positive control on the delta: the base fixture is non-empty and contains no `enumerative`.
  - check: rc=0; F=tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt; test -s "$F" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac3.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; tail -n +3 "$F" > "$T/p"; test -s "$T/p" || rc=1; for w in 'instrument' 'enumerative' 'fast-follow' 'vacuous'; do grep -qiF -- "$w" "$T/p" || rc=1; done; test "$(grep -ciF -- 'enumerative' "$T/b" || true)" = 0 || rc=1; test "$(LC_ALL=C tr -cd '$\140' < "$T/p" | wc -c | tr -d ' ')" = 0 || rc=1; test "$(sed -n 1,2p "$F")" = "$(sed -n 1,2p "$T/b")" || rc=1; test "$(tail -n 1 "$F")" = "$(tail -n 1 "$T/b")" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** Step 6's calibration bullet is byte-unchanged. `skills/run/SKILL.md` has exactly one line containing `**Verdict scope and severity calibration in the review briefing**`, the base blob has exactly one such line, and the two lines are byte-identical.
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac4.XXXXXX") || exit 1; K='**Verdict scope and severity calibration in the review briefing**'; grep -F -- "$K" "$S" > "$T/h"; test "$(grep -c . "$T/h" || true)" = 1 || rc=1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; grep -F -- "$K" "$T/b" > "$T/bl"; test "$(grep -c . "$T/bl" || true)" = 1 || rc=1; cmp -s "$T/h" "$T/bl" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** The prompt-block sync and every CI suite that reads an edited path stay green. The suites were reverse-mapped from the edited paths: `bash bin/check-prompt-sync.sh`, `tests/codex-skeleton-hygiene/run.sh` (fixture equality and the bare-`codex exec` count of 3), `tests/codex-agents/run.sh`, `tests/check-invocation-path/run.sh`, `tests/check-oversight/run.sh`, `tests/check-refreeze-grant/run.sh`, `tests/trial-recipe/run.sh` and `tests/install/run.sh`. Each exits `0` and prints no line beginning `FAIL` on either stream. Positive control: each file is asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac5.XXXXXX") || exit 1; for s in bin/check-prompt-sync.sh tests/codex-skeleton-hygiene/run.sh tests/codex-agents/run.sh tests/check-invocation-path/run.sh tests/check-oversight/run.sh tests/check-refreeze-grant/run.sh tests/trial-recipe/run.sh tests/install/run.sh; do test -s "$s" || rc=1; bash "$s" > "$T/o" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/o" || true)" = 0 || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** The adopter-facing section says the same in both languages, and its heading anchors survive. `docs/adopting.md` has exactly one line `## Electing a spec review at the Specify seam (T-1092)`, and its section (up to the next `## ` line) names `enumerat`, `fast-follow`, `vacuous` (case-insensitive), `Blocker` and `Major`. `docs/adopting.ja.md` has exactly one line `## Specify seam で spec review を elect する（T-1092）`, and its section names `Blocker`, `Major` and `fast-follow`. Positive control on the delta: the base blob's en section is non-empty and contains no `vacuous`.
  - adopter-surface: `docs/adopting.md` `## Electing a spec review at the Specify seam (T-1092)` and `docs/adopting.ja.md` `## Specify seam で spec review を elect する（T-1092）`. Together these tell an adopter what an elected spec review's verdict is gated by, and that enumerative-check completeness is a note or fast-follow unless it makes the criterion vacuous.
  - check: rc=0; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac6.XXXXXX") || exit 1; HE='## Electing a spec review at the Specify seam (T-1092)'; HJ='## Specify seam で spec review を elect する（T-1092）'; test "$(grep -cxF -- "$HE" "$E" || true)" = 1 || rc=1; test "$(grep -cxF -- "$HJ" "$J" || true)" = 1 || rc=1; X='index($0,h)==1{f=1;next} f&&index($0,"## ")==1{f=0} f'; awk -v h="$HE" "$X" "$E" > "$T/e"; awk -v h="$HJ" "$X" "$J" > "$T/j"; test -s "$T/e" || rc=1; test -s "$T/j" || rc=1; for w in 'enumerat' 'fast-follow' 'vacuous'; do grep -qiF -- "$w" "$T/e" || rc=1; done; for w in 'Blocker' 'Major'; do grep -qF -- "$w" "$T/e" || rc=1; grep -qF -- "$w" "$T/j" || rc=1; done; grep -qiF -- 'fast-follow' "$T/j" || rc=1; git show "$B:$E" > "$T/b" 2>/dev/null || rc=1; awk -v h="$HE" "$X" "$T/b" > "$T/be"; test -s "$T/be" || rc=1; test "$(grep -ciF -- 'vacuous' "$T/be" || true)" = 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC7** The spec-review mode's mechanics paragraphs are byte-unchanged. For each of `**Conditional entry**`, `**Input, and why it is not a branch diff**`, `**Verdict and record shape**`, `**Route-back**` and `**Capability and boundary, unchanged**`, the base blob of `agents/code-reviewer.md` has exactly one line containing it, and that exact line is still present, whole, in the post-implementation file.
  - check: rc=0; S=agents/code-reviewer.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac7.XXXXXX") || exit 1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; for k in '**Conditional entry**' '**Input, and why it is not a branch diff**' '**Verdict and record shape**' '**Route-back**' '**Capability and boundary, unchanged**'; do grep -F -- "$k" "$T/b" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1 || rc=1; grep -qxF -f "$T/l" "$S" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC8** This task's diff is confined to a fixed allow-list. The measured set is the union of four reads: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only` and the untracked strays `git ls-files --others --exclude-standard`. It must contain no path outside `skills/run/SKILL.md`, `agents/code-reviewer.md`, `tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt`, `docs/adopting.md`, `docs/adopting.ja.md`, `.shell-team/todo.md`, and this task's own spec, provenance, interventions and review records. **This criterion is merge-point-scoped and expected to go stale after merge**, once later tasks' files land on the same base. That is expected, and it is never repaired by widening the base resolution or re-deriving it per rework round. Positive control: the measured union is asserted non-empty.
  - check: rc=0; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac8.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; LC_ALL=C sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' skills/run/SKILL.md agents/code-reviewer.md tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt docs/adopting.md docs/adopting.ja.md .shell-team/todo.md .shell-team/specs/T-1159-spec-review-calibration.md .shell-team/provenance/T-1159.md .shell-team/interventions/T-1159.md .shell-team/reviews/T-1159.md | LC_ALL=C sort -u > "$T/allow"; LC_ALL=C comm -23 "$T/got" "$T/allow" > "$T/extra"; test ! -s "$T/extra" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC9** This spec is a conformant carrier of its own declarations. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. Positive control: the spec and the checker are asserted non-empty first.
  - check: C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1159-spec-review-calibration.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1159-ac9.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; rc=0; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; rm -rf "$T"; test "$rc" -eq 0

## Input space

**Reachable input classes**: the spec documents a real elected spec review reads, and the rounds it runs over.

1. Specs with one `- check:` line per criterion, specs with several criteria each carrying one, and criteria with none. The calibration applies per check line and per criterion, never to the spec as a whole.
2. Enumerative inline check lines: a static list of rejected shapes, tokens or mutations built from `grep`/`awk` in the spec itself.
3. Check lines that call a shipped checker or suite (`bin/…`, `tests/…/run.sh`). Their adversarial completeness is the shipped checker's own concern and is not reclassified by this task.
4. A check line whose gap makes its criterion vacuous: it passes with the target artifact absent, or it cannot fail. This is clause (c), which stays verdict-gating.
5. `pm-authored` and `operator-authored` specs, and first and later spec-review rounds (`APPROVE`/`REQUEST_CHANGES`, with and without the `(round <N>)` suffix).
6. Findings about domain premises, about a check that measures something other than its prose claims, and about a real instrument defect (a broken command, a wrong computed value). These stay verdict-gating.

**Out-of-scope synthetic extremes**, declined explicitly:

1. A reviewer model that ignores the stated calibration. This task states the pricing and does not enforce it mechanically.
2. Spec text crafted to talk the reviewer out of the calibration (prompt injection inside the reviewed spec).
3. Unbounded round counts or repeated same-class findings across rounds (#630).
4. A shipped `bin/` checker's own adversarial completeness, which keeps full depth.

<!-- END intent-block: T-1159 -->

## Symmetry audit: norm clauses × surfaces

| Clause | S1 run skill spec-review gate | S2 code-reviewer spec-review mode prose | S3 spec-review `codex exec` prompt | D adopting.md / .ja.md |
|---|---|---|---|---|
| (a) verdict scope: domain premises, check measures what its prose claims, material instrument defects | mirrored-now (**AC1**) | mirrored-now (**AC2**; the mandate already has domain premises) | mirrored-now (**AC3**; the prompt already carries (1) and (2), and `instrument` is added) | mirrored-now (**AC6**, prose-judged beyond tokens) |
| (b) enumerative-check completeness = note or fast-follow, not Blocker or Major | mirrored-now (**AC1**) | mirrored-now (**AC2**) | mirrored-now (**AC3**) | mirrored-now (**AC6**) |
| (c) vacuity exception | mirrored-now (**AC1**) | mirrored-now (**AC2**) | mirrored-now (**AC3**) | mirrored-now (**AC6**, en token; ja judged by reading) |
| (d) findings independence untouched | mirrored-now (**AC1**) | mirrored-now (**AC2**) | not-applicable. The prompt is the reviewer's own instruction, and independence is a duty on whoever writes the briefing (S1) and on how the mode is read (S2). Clause (b) in S3 already tells the reviewer to *report* the gap, never to withhold it. | info-only. The adopter doc describes the verdict's pricing; it does not brief a reviewer. |
| "at every round" | mirrored-now (**AC1**) | not-applicable. S2 is read at every invocation by construction. | not-applicable. The prompt is sent at every invocation by construction. | not-applicable |

Step 6 (`skills/run/SKILL.md:106`) is the source shape and is locked byte-unchanged (**AC4**). `skills/goal/SKILL.md` is not-applicable: it carries no spec-review gate. Codex-host generated agents are not-applicable as a source surface: the generator reads `agents/code-reviewer.md`, **AC5** keeps the generated body byte-identical to it, and the staleness path for already-generated TOMLs is documented at `docs/adopting.md:605`–`:618`.

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | S1 states clauses a–d at every round (Goal) | **AC1** |
| 2 | S2 states clauses a–d (Goal) | **AC2** |
| 3 | S3 carries a–c; invocation and output contract unchanged; no `$`, backtick or substitution (Goal, Non-goals) | **AC3** |
| 4 | Fixture changes in lockstep; bare `codex exec` count stays 3 (Summarized sources, Non-goals) | **AC5** (`tests/codex-skeleton-hygiene/run.sh`) |
| 5 | Step 6 byte-unchanged (Goal, Non-goals) | **AC4** |
| 6 | Adopter docs in both languages; heading anchors survive (Goal) | **AC6** |
| 7 | No `check-spec-review.sh` grammar, heading, stem, route-back or write-boundary change (Non-goals) | **AC7**, **AC8** |
| 8 | No #630 mechanism, no `bin/`, no dispatch-axis change, no adopter knob, no generator change (Non-goals) | **AC8** |
| 9 | Generated Codex agents stay consistent (Non-goals) | **AC5** (`tests/codex-agents/run.sh`) |
| 10 | Declarations conformant | **AC9** |
| 11 | Calibration applies per check line and per criterion, not to the whole spec (Input space 1) | info-only (not promoted to AC). The scope of a sentence's quantifier is judged by reading; no token anchors it. See the singular-determiner read below. |
| 12 | Reviewer independence: nothing withheld, no severity lowered, no surface unexamined (Goal d) | **AC1**/**AC2** tokens; the meaning is review-judged |
| 13 | Sweep deferred to release (Non-goals) | info-only (not promoted to AC). A process deviation under the A2 mode. |

## Shipped-docs inventory

| Shipped document | Disposition | Ground |
|---|---|---|
| `skills/run/SKILL.md` | this-task | S1 (**AC1**, **AC4**) |
| `agents/code-reviewer.md` | this-task | S2 and S3 (**AC2**, **AC3**, **AC7**) |
| `docs/adopting.md` `## Electing a spec review…` | this-task | **AC6** |
| `docs/adopting.ja.md` `## Specify seam で spec review を elect する…` | this-task | **AC6** |
| `README.md:225`, `README.ja.md:225` | unchanged | They summarize the axis's values, when to elect it and that it is no gate, and they link the adopting.md heading that **AC6** keeps. All of that is still true. |
| `docs/workflow.md:53`, `docs/workflow.ja.md:53` | unchanged | Same as the README rows. |
| `docs/loop-engineering/specify-seam-review.md` | unchanged | It prices whether to elect the round, not how its verdict is calibrated. No mandate or severity text (grep 0). |

No `- shipped-docs:` line is written for the unchanged documents: the checker's vocabulary is `this-task` / `issue #<N>` only, and neither describes a document that stays true.

## Singular-determiner read (freeze-time duty)

Singular determiners in the norm text: "the spec's domain premises", "each criterion's `- check:` line", "an enumerative check line", "one more mutation", "the gap", "that line's own criterion", "the reviewer". Read against `.shell-team/specs/T-1158-raw-capture-existing-adopters.md`, which has seven criteria, each with its own `- check:` line and several of them enumerative:

- "each criterion's check" and "an enumerative check line" quantify per line, so several such lines in one spec are each priced independently. Nothing reads as "the spec's one check".
- The vacuity exception is bound to "that line's own criterion". A vacuous AC3 makes AC3's finding verdict-gating and does not promote AC1's completeness gaps. The engineer keeps this per-criterion binding in S1, S2 and S3 rather than writing "the criterion" with no antecedent.
- "the reviewer" is singular by construction (one `code-reviewer` invocation per round). Several rounds are covered by "every round".

## Blast radius

`- verification-class: mechanism`. Edited shipped paths: `skills/run/SKILL.md`, `agents/code-reviewer.md`, `tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt`, `docs/adopting.md`, `docs/adopting.ja.md`. Read-set of merged criteria naming them, derived at run time:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*(skills/run/SKILL\.md|agents/code-reviewer\.md|agentmd-block-code-reviewer-specreview|docs/adopting(\.ja)?\.md)' -- .shell-team/specs

**Indirection class:** merged criteria that reach these files through a suite (every suite in **AC5**) or a run-time path are disclosed here and not measured. **Disclosed deviation:** the full-population two-arm inventory is deferred to the release sweep under the operator's standing A2 mode. **Adopter-side artifacts:** Codex-host adopters' generated `.codex/agents/*.toml` go stale when `agents/code-reviewer.md` changes. The detection path (`bin/check-codex-agents.sh`) and the re-run step are already documented at `docs/adopting.md:605`–`:618`, and this task adds no mechanism for them.

## Review depth

- **The S1/S2/S3 prose and the doc paragraphs** get full depth. Do all four clauses read as the canon states them? Is the vacuity exception bound per criterion? Does independence stay untouched, exactly as at step 6? Is S3 still a well-formed `codex exec` argument free of `$`, backticks and command substitution?
- **This spec's own inline `- check:` lines** are reviewed for computed values, conclusion direction and material instrument defects. The adversarial completeness of their enumerations is a note or fast-follow unless a gap makes the criterion vacuous. That is the norm this task ships, applied to itself.

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #631: spec-review verdict scope and severity calibration | not met | met (on the elected `cross-provider` path, with no configuration) | PATCH | Nothing new becomes possible; an existing elective round is calibrated. |

## Assumptions

- **Relayed:** issue #631's body, via the coordinating session (primary: the coordinating session).
- **Relayed:** the branch is cut from `develop` at `db8c2797`, and T-1158 is merged, so no predecessor is open. Consistent with the git status snapshot this role received (`db8c2797 Merge pull request #626`). The freeze run reports `git rev-parse HEAD`, `git merge-base develop HEAD` and `git status --short`.
- **Relayed premise measured false:** the Routing Map proposed `verification-class: no-mechanism`. The pm-spec contract makes `mechanism` the default whenever the diff reaches "any path under `bin/`, `tests/`, `templates/`…", and this task must edit `tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt` in lockstep (per the Routing Map itself). It also changes a prompt a `codex exec` invocation sends. So the declaration is `mechanism`, with the sweep deferred to the release under A2. This is a hand-off finding for the coordinating session's interventions record.
- **Relayed motivation, not a premise:** the adopter-run round count in `## Problem`. No criterion reads it.
- **Borrowed count premises** (read by this role in the working tree at `db8c2797`, clean). The freeze run re-measures each at `$B` and records the value here:

| Token | Class | Value read now | Command at the base |
|---|---|---|---|
| `enumerative` / `fast-follow` in the S1 region of `skills/run/SKILL.md` | borrowed (issue #631 / step-6 vocabulary) | **0** / **0** | AC1's base-side awk extraction piped to `grep -ciF` |
| `enumerative` / `fast-follow` in the S2 region of `agents/code-reviewer.md` | borrowed | **0** / **0** | AC2's base-side awk extraction piped to `grep -ciF` |
| `enumerative` in the spec-review fixture | borrowed | **0** | `git show "$B:tests/codex-skeleton-hygiene/fixtures/agentmd-block-code-reviewer-specreview.txt" \| grep -ciF enumerative` |
| `vacuous` in the en adopting.md section | borrowed | **0** | AC6's base-side awk extraction piped to `grep -ciF` |
| line containing `**Verdict scope and severity calibration in the review briefing**` in `skills/run/SKILL.md` | borrowed | **1** (`:106`) | `git show "$B:skills/run/SKILL.md" \| grep -cF '**Verdict scope and severity calibration in the review briefing**'` |
| `- **Specify-seam spec-review gate (T-1092)**:` / `- **Verification-ceiling declaration gate (T-1093)**:` | borrowed | **1** / **1** (`:56` / `:57`) | `git show "$B:skills/run/SKILL.md" \| grep -cF '<anchor>'` |
| `## Spec-review mode (specify seam, T-1092)` / `## Rules` whole lines in `agents/code-reviewer.md` | borrowed | **1** / **1** (`:168` / `:212`) | `git show "$B:agents/code-reviewer.md" \| grep -cxF '<heading>'` |
| the five bold-led S2 paragraph keys in **AC7** | borrowed | **1** each (`:172`, `:174`, `:204`, `:206`, `:208`) | `git show "$B:agents/code-reviewer.md" \| grep -cF '<key>'` |
| bare `codex exec ` lines in `agents/code-reviewer.md` | borrowed (suite pin) | **3** (per `tests/codex-skeleton-hygiene/run.sh:847`; not counted by this role) | `git show "$B:agents/code-reviewer.md" \| grep -cE '^[[:space:]]*codex exec '` |

(`\|` is markdown escaping for `|`.)

**Measured at freeze (2026-09-30, `$B` = `db8c2797`, HEAD `55069752`, working tree carrying only this spec and the board edit):** every row above reproduces — 0/0, 0/0, 0, 0, 1, 1/1, 1/1, 1 each, and 3 bare `codex exec ` lines.

## Open questions

None blocking.

## Notes for engineer

- **Files touched:** `skills/run/SKILL.md` (S1), `agents/code-reviewer.md` (S2 and S3), the spec-review fixture (in the same commit as S3), `docs/adopting.md` and `docs/adopting.ja.md`, plus this task's records. Run `bash bin/check-prompt-sync.sh`, and do not edit inside any registered block's bytes.
- **S1 placement:** inside the S1 region, meaning on the `:56` bullet's line or as a nested bullet before the `:57` sibling. Mirror step 6's shape: it is the orchestrator's duty to state these in the spec-review invocation at every round. Write "the orchestrator states…" so the duty sits on whoever writes the briefing and is not a reviewer self-restraint.
- **S2 placement:** prose outside the code fences, between `## Spec-review mode…` and `## Rules`. A natural spot is right after the `**Mandate**` paragraph. Keep the five bold-led mechanics paragraphs byte-identical (**AC7**).
- **S3:** the prompt is a double-quoted `codex exec` argument continued with ` \`. Add no `$`, no backtick, no `"` and no command substitution. Keep line 2 and the final `Return findings…` line byte-identical. Update the fixture in the same commit. The fixture stores the prompt lines without the agent file's two-space indent; check `extract_marked_block` in `tests/codex-skeleton-hygiene/run.sh` for the exact normalization. The bare `codex exec` line count must stay 3.
- **Vacuity binding:** bind the exception to the check line's own criterion ("unless the gap makes that criterion vacuous"), per the singular-determiner read above.
- **ja section:** keep machine tokens (`Blocker`, `Major`, `fast-follow`) verbatim in English. **Pre-existing, out of scope:** the ja section's closing sentence still claims the axis "has never fired end to end", while the en section says three tasks reached APPROVE past round 1. Do not fix it here. It is flagged for the coordinating session to file or fold into a later task.
- **Measured-at-ref command check:** not applicable. No deliverable prints a command labelled as measured at a git ref.
