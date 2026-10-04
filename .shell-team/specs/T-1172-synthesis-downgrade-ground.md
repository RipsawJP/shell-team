# A review synthesis never lowers a finding's severity on the reviewed text's own frozen or ratified status, and the orchestrator checks each downgrade's ground before transcribing (issue #681)

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1172

**Branch**: `feature/681-synthesis-downgrade-ground`, cut from `develop` at `921d0c42` (`.git/refs/heads/develop` reads `921d0c42f98497622424dd0dadd7547787fa6982`; the branch ref reads `f3eba7e9…`, one commit on top: the T-1172 interventions record; read by this role). Not stacked: no open predecessor. The pull request targets `develop`.

## Problem

In T-1168's review round 3, the reviewer's synthesis lowered two findings, which both passes had raised at P1/blocker/major, to minor. Part of each reason was that the reviewed sentence was frozen or ratified. The defects were in that frozen sentence, so the frozen status was being used to excuse its own defect. The coordinating session overrode the synthesis on the merits that time. But nothing in `agents/code-reviewer.md` or in the run skill's transcription step tests whether a downgrade's ground is independent of the reviewed text's status. The nearest lesson does not reach the reviewer or the orchestrator.

**Issue canon (verbatim, relayed by the coordinating session on 2026-10-04 after its own correction of the body).** The body follows as a quoted block, with its own `## ` headings demoted to bold labels so that this spec's section structure is unchanged.

> **Observed**
>
> In one cycle (T-1168, review round 3), the reviewer's synthesis lowered two findings that both passes had raised at P1/blocker/major to minor. In the `#### Synthesis audit ledger`, the frozen or ratified status of the reviewed sentence was one of the grounds for each of those two downgrades, followed by merits arguments (`.shell-team/reviews/T-1168.md` round 3, rows 1 and 2). The defects the findings named were in that frozen sentence itself, so part of each downgrade used the frozen text to excuse its own defect. One finding was about a refusal-rule carve-out that could let a recursive delete through.
>
> That round was not transcribed: the coordinating session overrode the synthesis on the merits and escalated to the operator (`.shell-team/todo.md`, the T-1168 entry). But nothing on record checks a downgrade's ground for independence from the reviewed text's status, and the rule, as the ledger stands, would let such a downgrade through.
>
> (Corrected 2026-10-04: an earlier version of this text said the orchestrator transcribed the round without checking, and that the downgrade had a single ground. Both were wrong; see the board line and the review record above.)
>
> The lessons corpus has a near entry: "A precedent cited as grounds is a claim, not an observation… treat a prior operator-approved derivation as no independent evidence for the next one" (2026-09-02). It covers the writer of a briefing, spec or derivation. It does not reach this case, for two reasons:
> - the corpus is injected into `tech-lead`, `pm-spec`, `engineer` and `qa-verifier` only. `code-reviewer` deliberately receives no playbook injection (evaluator independence, `agents/code-reviewer.md`), and the orchestrator reads the run skill, not the corpus;
> - the entry speaks of citations and derivations, not of a severity change in a review synthesis.
>
> **Expected**
>
> - `agents/code-reviewer.md`: a Synthesis audit ledger row that lowers a pass's severity carries a ground independent of the reviewed text's own frozen or ratified status. A downgrade whose ground no longer carries it once the reviewed text's frozen or ratified status is struck from it is not a downgrade, and the finding keeps the pass's severity.
> - `skills/run/SKILL.md` step 6: before transcribing a verdict, the orchestrator reads each downgraded ledger row's ground. A row that fails that test is treated as not downgraded, and the finding is routed accordingly.
> - The 2026-09-02 corpus entry is superseded by an integrated entry that also covers this case, so the lesson record matches what ships.
>
> **Prior art**
>
> Searched issues for `synthesis severity downgrade frozen ratified`: no match. The corpus entry above is the nearest prior art.

Expected-to-criteria trace: Expected 1, `agents/code-reviewer.md`: **AC1**, **AC2** and **AC3**. Expected 2, run skill step 6: **AC4** and **AC5**, plus **AC6**, a reference from the goal loop. Expected 3, corpus supersede: **AC7**, **AC8** and **AC9**. The issue's own premise (rows 1 and 2) is anchored by **AC10**. No Expected line is narrowed. One reading is widened, on the issue's own wording: "a pass's severity" becomes "the highest severity any pass assigned" when the passes disagree, and a rejection counts as a lowering (decision 3).

## Summarized sources

- GitHub issue #681. Its body is relayed verbatim in `## Problem`. Distinctions carried over: the frozen or ratified status was **one** of the grounds, beside merits arguments, in **two** rows (not a single ground). The round was **overridden and escalated, not transcribed**. The test is "strike the status and see whether the ground still carries". The corpus does **not** reach `code-reviewer` or the orchestrator.
- `.shell-team/reviews/T-1168.md` round 3, `#### Synthesis audit ledger` (`:247`–`:252`, read). Distinctions:
  - Row 1 is `primary P1 / adversarial blocker` → `minor`. Its reason opens with "the added sentence is the operator-ratified wording", then gives merits clauses: the round-2 conflict was removed, "permission is not an order", "the run skill directs the request separately", "AC12 measures".
  - Row 2 is `primary P1 / adversarial major` → `minor`. Its reason opens with "the genericity is frozen in decision 8, Non-goals and Input space class 7 and ratified by the operator", then gives merits clauses: only the identical command, every ban clause verbatim, "a deny rule that offers no prompt gives no approval path".
  - Row 3 is `adversarial (within finding 1)` → `minor`. Its reason ("not embedded in any agent, optional under decision 6, uneven in the corpus only") states no frozen or ratified status of the text it names as defective, a How to apply line the task did not freeze.
  - The `#### Recommendation` (`:255`) itself flags the two lowered ratings for the coordinating session.
- `.shell-team/todo.md` T-1168 entry, `codex-reviewer (T-1168, round 3)` and `operator-gate (after Codex round 3)` sub-bullets (`:38`–`:39`, read). Distinctions: `APPROVE` was "as synthesized, not transcribed to `READY_FOR_MERGE`"; the coordinating session rated finding (2) a contradiction of the operator's intent and finding (1) a never-dropped hit, overrode the synthesis and escalated to the operator.
- `agents/code-reviewer.md` (read in full). Distinctions:
  - Step 4's normalization map (`:93`–`:102`): P0/P1 → blocker, and an unknown label "rounds up one severity level".
  - Step 6 (`:105`): the synthesis ledger records every upgrade, downgrade or rejection with a one-sentence reason, and is never omitted.
  - `## Output` ledger placeholder (`:134`–`:137`).
  - The `out-of-input-space` downgrade-validity rule (`:238`): default fresh-review mode only; "a downgrade with no cited spec line is not valid, so fall back to the finding's original severity"; the tag is orthogonal and not a severity level.
  - The verbatim-English list (`:237`).
  - Evaluator independence: no playbook injection (`:240`).
  - Spec-review and review-response modes produce no synthesis ledger.
- `skills/run/SKILL.md` step 6 (`:102`–`:116`, read). Distinctions: `REQUEST_CHANGES` routes back to `engineer`. The `Evidence-ledger gate (T-1153)` bullet (`:103`) is the existing pre-transcription gate and already carries rejected or downgraded ledger rows into the next round's S-R perspective. Step 6 is not inside any prompt block (the file's only `prompt-block` mention is at `:34`).
- `skills/goal/SKILL.md` `:80`–`:92` (read). Distinction: the goal loop's review bullet references the run skill's Review-step briefing discipline "rather than restating it", and its gate counts `Codex APPROVE` as green.
- `templates/prompt-blocks/host-dispatch.md` `:26` (read). Distinction: on the Codex CLI host, the Claude-side review pass is told to produce its verdict "in exactly the shape agents/code-reviewer.md's own '## Output' section fixes". It reads `## Output`, so a pointer in the Output ledger placeholder reaches that pass without editing this block (decision 2).
- `.shell-team/lessons.md`:
  - The 2026-09-02 entry at `:1439`–`:1447` (read). Distinctions: `Applies-to: all`, `Status: active`. The Rule covers a writer's citation of a prior artifact (re-read it for the exact property) and a prior operator-approved derivation (not independent evidence for the next one).
  - Supersede precedent `:1180`–`:1185` → `:1418` (read). The old entry gets `- **Status**: superseded` plus `- **Superseded-by**: <date — title>`, and the new title ends `(supersedes the … entry)`.
- `.shell-team/retros/2026-10-03-sprint-b-close.md` `:73` (read). The retro's lesson candidate 2 states this rule and says "supersede しない" (do not supersede). The issue's Expected, operator-approved, says supersede with an integrated entry. The issue governs, and the discrepancy is recorded in `## Assumptions`.
- `bin/gen-codex-agents.sh` `:342`–`:349` (read). Distinction: an agent body containing the three-apostrophe run is refused.
- `bin/playbook-promote.sh` header (read `:1`–`:61`, `:169`–`:183`, `:244`–`:256`). Distinctions: it appends one schema-valid entry and validates it with `bin/check-playbook.sh` before writing. `--date` defaults to today.
- `bin/check-playbook.sh` (read `:149`–`:188`, `:725`–`:751`). Distinctions: a `superseded` entry must carry a non-empty `Superseded-by` that resolves to an existing entry. An `active` entry must carry none.
- `bin/gen-playbook-blocks.sh` (read `:449`, `:466`). Distinction: only `active` entries are emitted.
- `.github/workflows/check-handoff.yml` `:176`–`:215`, `:372`–`:385` (read). Distinction: the check-playbook dogfood, the gen-playbook-blocks scratch-regeneration dogfood, check-prompt-sync, and the gen/check-codex-agents dogfood. The CI steps' own `rm -rf` cleanup runs only on the runner. **AC9** reproduces the steps without it.
- `docs/workflow.md` `:177` and `docs/workflow.ja.md` `:174` (read). Distinction: "curated verdict + severity ledger" stays accurate under this change (see `## Shipped-docs inventory`).

## Goal

<!-- BEGIN intent-block: T-1172 -->

- user-visible: no — the change governs how `code-reviewer` justifies lowering a finding's severity and how the orchestrator reads that justification before transcribing a verdict. No command, configuration or adopter-invoked behaviour is added. The one shipped document describing the ledger (`docs/workflow.md` `:177`, "curated verdict + severity ledger") stays accurate.
- verification-class: mechanism — the diff reaches `agents/`, `skills/` and `templates/prompt-blocks/` (four regenerated playbook blocks), and the corpus those blocks are generated from.
- verification-ceiling: unit-and-static — every criterion, **AC1**–**AC13**, is settled in a plain checkout. Each one reads shipped files, compares them with their base blobs, regenerates generated files into `$TMPDIR` or runs checkers and suites. **AC10**'s classification half is a reading of a committed record against the shipped rule text, also unit level. No criterion claims that a live reviewer or orchestrator applies the rule in a real round, and none sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor; it was cut from `develop` at `921d0c42`, and the base-side reads in **AC3**, **AC5**, **AC6**, **AC7**, **AC8** and **AC11** use `git merge-base develop HEAD` (or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves), each arm selected by `git show-ref --verify --quiet`.

**Goal (one sentence).** In the default fresh-review mode, `agents/code-reviewer.md` requires that a Synthesis-audit-ledger row which lowers a finding below the highest severity any pass assigned it carries a ground that still holds once every clause resting on the reviewed text's own frozen or ratified status is struck. The rule sits in step 6, with a pointer in the `## Output` ledger placeholder, and a row that fails is not a downgrade, so the finding keeps that highest severity. `skills/run/SKILL.md` step 6 makes the orchestrator apply the same test to each such row before transcribing any verdict, and routes a finding whose downgrade fails at its restored severity. The goal loop references that check. The 2026-09-02 lesson is superseded by one integrated entry covering both the writer's case and this one, regenerated into every playbook block and consumer. Nothing else in the repository changes.

**Decisions frozen here** (each is promoted to a criterion):

1. **The test (Expected 1).** Rows in scope:
   - every ledger row whose final judgment is lower than the highest normalized severity any pass assigned that finding;
   - every rejection, which counts as the largest lowering.
   
   For each such row, strike from its reason every clause resting on the frozen or ratified status of the text the finding names as defective. Such a clause says that text is frozen, ratified or approved, or that the defect is what the frozen or ratified intent prescribes. If what remains does not by itself show that the named defect is absent or less severe than that highest severity, the row is not a downgrade, and the finding keeps the highest severity any pass assigned. The status may appear in a reason as context, but it cannot be the part that carries the downgrade. (**AC1**)
2. **Where the rule lives (Expected 1).**
   - Step 6 of `agents/code-reviewer.md` carries the rule. The synthesizing role reads step 6 on both hosts.
   - The `## Output` ledger placeholder carries a one-line pointer to it, because on the Codex CLI host the Claude-side pass is told to read `## Output` for the verdict shape. `templates/prompt-blocks/host-dispatch.md` is not edited.
   - The file changes only by lines added inside those two regions. (**AC1**, **AC2**, **AC3**)
3. **More than one pass (Expected 1, the plural case).** When passes disagree on a finding (T-1168 round 3: primary P1, adversarial blocker or major), the reference severity is the highest normalized severity any pass assigned. Codex-native labels are normalized first through the existing map, and an unknown label still rounds up. This matches the existing round-up rule at `:102`. (**AC1**, **AC4**)
4. **Unchanged neighbours (Expected 1).**
   - An `out-of-input-space` row whose ground is a cited Out-of-scope line of the spec's `## Input space` is unaffected. That line states which inputs are in scope, not the reviewed text's status, and the step-6 rule says so.
   - No new machine tag or severity level is added.
   - The verbatim-English list, the normalization map and the `out-of-input-space` rule stay byte-identical.
   
   (**AC1**, **AC3**)
5. **The orchestrator's check (Expected 2).** Step 6 of `skills/run/SKILL.md` gains one bullet, `Downgrade-ground check`, which fires before any verdict is transcribed. It applies decision 1's test to each in-scope row. A row that fails is treated as not downgraded. When that leaves a blocker or major standing, no `APPROVE` is transcribed to `READY_FOR_MERGE`. The round is instead handled as a `REQUEST_CHANGES` carrying that finding at its restored severity:
   - routed to `engineer`;
   - or, when the defect sits in frozen intent text, escalated to the human because a class-B re-freeze needs one.
   
   The board line that records the round names each failed row and why its ground failed. Nothing else in `skills/run/SKILL.md` changes. (**AC4**, **AC5**)
6. **The goal loop (Expected 2, droppable).** `skills/goal/SKILL.md`'s review bullet group gains one line. It references the run skill's `Downgrade-ground check` by path rather than restating it, so the goal loop's count of a Codex `APPROVE` is subject to the same check. (**AC6**)
7. **The corpus (Expected 3).**
   - `bin/playbook-promote.sh` appends one active entry, `Applies-to: all`, `Source: .shell-team/retros/2026-10-03-sprint-b-close.md`. Its title ends `(supersedes the precedent-as-grounds entry)`, and its Rule keeps both halves of the 2026-09-02 Rule (a cited source is re-read for the exact property; a ratified derivation is not independent evidence) and adds the synthesis case in decision 1's terms.
   - The 2026-09-02 entry's `Status` becomes `superseded`, with a `Superseded-by` naming the new entry's exact `date — title`. Nothing else in the corpus changes.
   - `bin/gen-playbook-blocks.sh` regenerates the four playbook blocks and their four consumer agents, which change only inside their playbook marker regions.
   
   (**AC7**, **AC8**, **AC9**)
8. **The worked instance.** Under decision 1, T-1168 round-3 rows 1, 2 and 3 are all lowered, so all three are in scope. Rows 1 and 2 carry a status clause, so the test strikes it and judges what remains. Row 3 carries no status clause about the text it names, so striking removes nothing, its merits ground stands as written, and the rule does not change row 3. (**AC10**)

**Pre-commitment (AI self-discipline, not an operator ruling).**
- **Never-dropped:** the code-reviewer rule (decisions 1–4: **AC1**–**AC3**) and the orchestrator's transcription check (decision 5: **AC4**, **AC5**). A review or QA finding of either of these kinds is not patched in place: the task stops and returns to planning.
  - The test cannot be stated so that a reader can tell a status ground from a merits ground.
  - The test invalidates an `out-of-input-space` downgrade.
- **Droppable, in this order:** first decision 6 (**AC6**); second, any S-R (carried-forward round) clause the engineer adds beyond what decision 5 requires. No such clause is frozen here.
- **Trigger:** the same reviewer class of finding against a droppable item in two consecutive rounds.
- **Disposition:** restore that file's lines to their base bytes, remove the item's criterion (if any) in a class-B re-freeze recorded as executing this pre-commitment, and carry the rounds' findings to a follow-up issue as its requirement list. No further wording round on it.

## Non-goals

- **No change to `bin/`, `tests/`, `.github/`, `docs/`, `README.md` / `README.ja.md`, `CHANGELOG.md` or `.claude-plugin/plugin.json`, and no hand edit under `templates/`.** Under `templates/`, only the four playbook blocks change, and only by regeneration. `templates/prompt-blocks/host-dispatch.md` is not edited. (**AC11**, **AC8**, **AC9**)
- **No new machine tag, severity level or checker.** The verbatim-English list (`:237`), the normalization map and the `out-of-input-space` rule (`:238`) are unchanged, and no script parses a ledger reason cell. (**AC3**, **AC11**)
- **No change to spec-review mode or review-response mode.** Neither produces a synthesis ledger, and review-response keeps its own risk gate. (**AC3**: lines are added only inside step 6 and the Output ledger placeholder)
- **No change to any other part of `skills/run/SKILL.md` or `skills/goal/SKILL.md`.** (**AC5**, **AC6**)
- **No re-adjudication of T-1168, and no edit to its records or to the retro.** (**AC11**)
- **No change to any lessons entry other than the 2026-09-02 entry's `Status` and its added `Superseded-by` line, and the one appended entry.** (**AC7**)
- **No claim that a live reviewer or orchestrator obeys the rule.** Only the shipped text, its regeneration and the suites are verified. (info-only, see the ceiling declaration)
- **No version bump, changelog, push, merge or release.** (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree (worktree, except where a base or `HEAD` blob is named), writes only under `$TMPDIR` (temporary directories are left in place, never removed), and contains no recursive delete.

Region names used below:
- **CR step 6**: the region of `agents/code-reviewer.md` from the line beginning `6. Synthesize a verdict.` up to the line beginning `## Output`.
- **CR ledger placeholder**: from the line beginning `#### Synthesis audit ledger` up to the line beginning `#### Recommendation`.
- **Run step 6**: the region of `skills/run/SKILL.md` from the line beginning `6. **Review**` up to the line beginning `7. **Done**`.
- **Joined**: leading spaces stripped and lines joined by one space.
- **Base**: `git merge-base develop HEAD`, or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves.

- [ ] **AC1** The code-reviewer rule is stated in step 6 (decisions 1, 3, 4). Each start line occurs exactly once. Joined CR step 6 still names `synthesis audit ledger` (positive control) and names `frozen or ratified status`, `struck`, `highest severity` and `out-of-input-space`.

  Review-judged, against decisions 1, 3 and 4, plural read:
  - the rule covers each lowered row and each rejection;
  - the reference severity is the highest any pass assigned, after normalization;
  - a status clause may be context but cannot carry the downgrade;
  - a failed row leaves the finding at that highest severity;
  - an `out-of-input-space` row grounded on its cited Out-of-scope line is explicitly unaffected;
  - no singular phrasing ("the pass", "the row") reads as if only one pass or one downgraded row could exist.
  - check: rc=0; export LC_ALL=C; F=agents/code-reviewer.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac1.XXXXXX") || exit 1; test "$(awk 'index($0,"6. Synthesize a verdict.")==1' "$F" | grep -c . || true)" = 1 || exit 1; test "$(awk 'index($0,"## Output")==1' "$F" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"6. Synthesize a verdict.")==1{f=1} index($0,"## Output")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$F" > "$T/r"; test -s "$T/r" || exit 1; grep -qF 'synthesis audit ledger' "$T/r" || exit 1; for w in 'frozen or ratified status' struck 'highest severity' out-of-input-space; do grep -qF -- "$w" "$T/r" || rc=1; done; test "$rc" -eq 0

- [ ] **AC2** The `## Output` ledger placeholder points at the rule (decision 2). Each start line occurs exactly once. The joined CR ledger placeholder still names `no severity changes` (positive control) and names `frozen or ratified status`.
  - check: rc=0; export LC_ALL=C; F=agents/code-reviewer.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac2.XXXXXX") || exit 1; test "$(awk 'index($0,"#### Synthesis audit ledger")==1' "$F" | grep -c . || true)" = 1 || exit 1; test "$(awk 'index($0,"#### Recommendation")==1' "$F" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"#### Synthesis audit ledger")==1{f=1} index($0,"#### Recommendation")==1{f=0} f{printf "%s ", $0}' "$F" > "$T/r"; test -s "$T/r" || exit 1; grep -qF 'no severity changes' "$T/r" || exit 1; grep -qF 'frozen or ratified status' "$T/r" || rc=1; test "$rc" -eq 0

- [ ] **AC3** `agents/code-reviewer.md` changes only by added lines inside the two regions (decisions 2, 4; Non-goals). Against its base blob, which names `out-of-input-space` (positive control):
  - the normal-format `diff` removes no line and contains no change separator;
  - every non-empty added line occurs verbatim as a line of CR step 6 or of the CR ledger placeholder in the head file.
  
  This keeps the verbatim-English list, the normalization map, the `out-of-input-space` rule, spec-review mode and review-response mode byte-identical. Green at base by construction (no added line); its subject is a protected invariant that pairs with **AC1**/**AC2**, and an edit anywhere else reddens it.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=agents/code-reviewer.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac3.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; grep -qF 'out-of-input-space' "$T/b" || exit 1; diff "$T/b" "$F" > "$T/d"; d=$?; test "$d" -le 1 || exit 1; test "$(grep -c '^< ' "$T/d" || true)" = 0 || rc=1; test "$(grep -c '^---$' "$T/d" || true)" = 0 || rc=1; sed -n 's/^> //p' "$T/d" > "$T/a"; awk 'index($0,"6. Synthesize a verdict.")==1{f=1} index($0,"## Output")==1{f=0} f' "$F" > "$T/rr"; awk 'index($0,"#### Synthesis audit ledger")==1{f=1} index($0,"#### Recommendation")==1{f=0} f' "$F" >> "$T/rr"; while IFS= read -r x; do test -z "$x" && continue; grep -qxF -- "$x" "$T/rr" || rc=1; done < "$T/a"; test "$rc" -eq 0

- [ ] **AC4** The orchestrator's check is one step-6 bullet (decisions 3, 5). Each start line occurs exactly once. Run step 6 still names `Evidence-ledger gate (T-1153)` (positive control). Exactly one line of `skills/run/SKILL.md` contains `Downgrade-ground check`, and it lies in run step 6. That line names `frozen or ratified status`, `struck`, `not downgraded`, `highest severity`, `REQUEST_CHANGES`, `class-B` and `board`.

  Review-judged, against decision 5, plural read:
  - the check fires before any verdict is transcribed, not only an `APPROVE`;
  - it reads each in-scope row, a rejection included;
  - a failed row's finding takes the highest severity any pass assigned;
  - a restored blocker or major blocks `READY_FOR_MERGE` and is handled as a `REQUEST_CHANGES` routed to `engineer`, or escalated to the human when the defect sits in frozen intent text;
  - the board line names each failed row and why.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac4.XXXXXX") || exit 1; test "$(awk 'index($0,"6. **Review**")==1' "$F" | grep -c . || true)" = 1 || exit 1; test "$(awk 'index($0,"7. **Done**")==1' "$F" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"6. **Review**")==1{f=1} index($0,"7. **Done**")==1{f=0} f' "$F" > "$T/r"; test -s "$T/r" || exit 1; grep -qF 'Evidence-ledger gate (T-1153)' "$T/r" || exit 1; grep -F 'Downgrade-ground check' "$T/r" > "$T/l"; test "$(grep -c '' "$T/l" || true)" = 1 || rc=1; test "$(grep -c 'Downgrade-ground check' "$F" || true)" = 1 || rc=1; for w in 'frozen or ratified status' struck 'not downgraded' 'highest severity' REQUEST_CHANGES class-B board; do grep -qF -- "$w" "$T/l" || rc=1; done; test "$rc" -eq 0

- [ ] **AC5** Nothing else in `skills/run/SKILL.md` changes (decision 5; Non-goals). The base blob names `Evidence-ledger gate (T-1153)` and does not contain `Downgrade-ground check` (grep exit `1`). The head file, with every line containing `Downgrade-ground check` removed, is byte-identical to the base blob. Green at base by construction; it is a protected invariant that pairs with **AC4**.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac5.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; grep -qF 'Evidence-ledger gate (T-1153)' "$T/b" || exit 1; grep -qF 'Downgrade-ground check' "$T/b"; g=$?; test "$g" -eq 1 || exit 1; grep -vF 'Downgrade-ground check' "$F" > "$T/h"; cmp -s "$T/b" "$T/h" || rc=1; test "$rc" -eq 0

- [ ] **AC6** The goal loop references the check (decision 6; droppable first per the pre-commitment). Exactly one line of `skills/goal/SKILL.md` contains `Downgrade-ground check`.
  - That line also names `skills/run/SKILL.md`.
  - It sits after the line containing `severity calibration in the review briefing (referenced` and before the line containing `The gate is **green**`.
  - The head file, with that line removed, is byte-identical to the base blob, which does not contain `Downgrade-ground check`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=skills/goal/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac6.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; grep -qF 'Downgrade-ground check' "$T/b"; g=$?; test "$g" -eq 1 || exit 1; test "$(grep -c 'Downgrade-ground check' "$F" || true)" = 1 || rc=1; grep -F 'Downgrade-ground check' "$F" | grep -qF 'skills/run/SKILL.md' || rc=1; n=$(awk 'index($0,"severity calibration in the review briefing (referenced")>0{a=NR} index($0,"The gate is **green**")>0{g=NR} index($0,"Downgrade-ground check")>0{d=NR} END{print ((a>0 && g>0 && d>a && d<g) ? 1 : 0)}' "$F"); test "$n" = 1 || rc=1; grep -vF 'Downgrade-ground check' "$F" > "$T/h"; cmp -s "$T/b" "$T/h" || rc=1; test "$rc" -eq 0

- [ ] **AC7** The 2026-09-02 entry is superseded by one integrated entry (decision 7). In the lessons file resolved through `bin/team-paths.sh --get lessons`:
  - The heading `## 2026-09-02 — A precedent cited as grounds is a claim, not an observation: re-read the source for the exact property asserted, and treat a prior operator-approved derivation as no independent evidence for the next one` occurs exactly once. Its entry carries exactly one `- **Status**: superseded`, no `- **Status**: active`, and exactly one `- **Superseded-by**: <V>`.
  - `<V>` differs from the old key, ends with `(supersedes the precedent-as-grounds entry)`, and `## <V>` occurs exactly once.
  - That new entry carries `- **Status**: active`, `- **Applies-to**: all` and `- **Source**: .shell-team/retros/2026-10-03-sprint-b-close.md`.
  - It has exactly one `- **Rule**:` line, which names `re-read`, `ratified`, `synthesis`, `severity` and `frozen or ratified status`.
  - Against the base blob, which carries the old heading (positive control), the normal-format `diff` removes exactly one line, and that line is `- **Status**: active`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; L=$(bash bin/team-paths.sh --get lessons) || exit 1; test -s "$L" || exit 1; R=$(git ls-files --full-name -- "$L"); test -n "$R" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac7.XXXXXX") || exit 1; O='2026-09-02 — A precedent cited as grounds is a claim, not an observation: re-read the source for the exact property asserted, and treat a prior operator-approved derivation as no independent evidence for the next one'; test "$(grep -cxF -- "## $O" "$L" || true)" = 1 || exit 1; awk -v h="## $O" '$0==h{f=1; print; next} f && index($0,"## ")==1{f=0} f' "$L" > "$T/old"; test -s "$T/old" || exit 1; test "$(grep -cxF -- '- **Status**: superseded' "$T/old" || true)" = 1 || rc=1; grep -qxF -- '- **Status**: active' "$T/old"; g=$?; test "$g" -eq 1 || rc=1; test "$(grep -c '^- \*\*Superseded-by\*\*: ' "$T/old" || true)" = 1 || rc=1; V=$(sed -n 's/^- \*\*Superseded-by\*\*: //p' "$T/old"); test -n "$V" || exit 1; test "$V" != "$O" || rc=1; case "$V" in *'(supersedes the precedent-as-grounds entry)') ;; *) rc=1 ;; esac; test "$(grep -cxF -- "## $V" "$L" || true)" = 1 || exit 1; awk -v h="## $V" '$0==h{f=1; print; next} f && index($0,"## ")==1{f=0} f' "$L" > "$T/new"; for x in '- **Status**: active' '- **Applies-to**: all' '- **Source**: .shell-team/retros/2026-10-03-sprint-b-close.md'; do grep -qxF -- "$x" "$T/new" || rc=1; done; grep '^- \*\*Rule\*\*: ' "$T/new" > "$T/rule"; test "$(grep -c '' "$T/rule" || true)" = 1 || rc=1; for w in re-read ratified synthesis severity 'frozen or ratified status'; do grep -qF -- "$w" "$T/rule" || rc=1; done; git show "$B:$R" > "$T/b" 2>/dev/null || exit 1; grep -qxF -- "## $O" "$T/b" || exit 1; diff "$T/b" "$L" > "$T/d"; d=$?; test "$d" -le 1 || exit 1; grep '^< ' "$T/d" > "$T/rm"; test "$(grep -c '' "$T/rm" || true)" = 1 || rc=1; grep -qxF -- '< - **Status**: active' "$T/rm" || rc=1; test "$rc" -eq 0

- [ ] **AC8** The regenerated blocks carry the new entry, and not the old one (decision 7). The file set is derived at the base ref: every file under `templates/prompt-blocks` and `agents` whose base blob contains `A precedent cited as grounds is a claim, not an observation`. That set includes `templates/prompt-blocks/playbook-pm-spec.md` and `agents/pm-spec.md` (positive control).
  - In the head tree, `git grep` finds that phrase nowhere under `templates/prompt-blocks` or `agents` (exit `1`).
  - Every file of the set contains exactly one line carrying `(.shell-team/lessons.md, <V>)`, with `<V>` read from the old entry's `Superseded-by`.
  - Every `agents/` member of the set, with its `playbook-` prompt-block region (BEGIN to END marker, inclusive) removed, is byte-identical to its base blob with the same region removed.
  
  The set is read from the base ref's committed blobs, so it does not drift as the repository grows.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac8.XXXXXX") || exit 1; OT='A precedent cited as grounds is a claim, not an observation'; git grep -l -F -e "$OT" "$B" -- templates/prompt-blocks agents > "$T/l0" || exit 1; sed "s/^$B://" "$T/l0" | sort -u > "$T/files"; grep -qxF templates/prompt-blocks/playbook-pm-spec.md "$T/files" || exit 1; grep -qxF agents/pm-spec.md "$T/files" || exit 1; git grep -n -F -e "$OT" -- templates/prompt-blocks agents > "$T/left"; g=$?; test "$g" -eq 1 || rc=1; L=$(bash bin/team-paths.sh --get lessons) || exit 1; test -s "$L" || exit 1; V=$(awk -v p="## 2026-09-02 — $OT" 'index($0,p)==1{f=1; next} f && index($0,"## ")==1{f=0} f' "$L" | sed -n 's/^- \*\*Superseded-by\*\*: //p'); test -n "$V" || exit 1; A="(.shell-team/lessons.md, $V)"; while IFS= read -r f; do test "$(grep -cF -- "$A" "$f" || true)" = 1 || rc=1; done < "$T/files"; grep '^agents/' "$T/files" > "$T/ag" || exit 1; while IFS= read -r f; do git show "$B:$f" 2>/dev/null | awk 'index($0,"<!-- BEGIN prompt-block: playbook-")==1{s=1} !s{print} index($0,"<!-- END prompt-block: playbook-")==1{s=0}' > "$T/x1"; awk 'index($0,"<!-- BEGIN prompt-block: playbook-")==1{s=1} !s{print} index($0,"<!-- END prompt-block: playbook-")==1{s=0}' "$f" > "$T/x2"; test -s "$T/x1" || rc=1; cmp -s "$T/x1" "$T/x2" || rc=1; done < "$T/ag"; test "$rc" -eq 0

- [ ] **AC9** The corpus and every generated file are consistent (decision 7; the CI dogfood steps, reproduced without cleanup).
  - `bin/check-playbook.sh` on the lessons file exits `0`.
  - Every file named on a `playbook-` marker row of `templates/prompt-blocks/registry.txt`, plus each block file itself, is copied into a scratch root. `bin/gen-playbook-blocks.sh --root <scratch> --lessons <lessons>` exits `0`, and every such file is byte-identical to its scratch copy afterwards.
  - `bin/check-prompt-sync.sh` exits `0`.
  - `bin/gen-codex-agents.sh --root . --out-dir <scratch>/out` exits `0` and writes a non-empty `shell-team-<role>.toml` for `tech-lead`, `pm-spec`, `engineer`, `qa-verifier` and `code-reviewer`, and `bin/check-codex-agents.sh --root . --out-dir <scratch>/out` exits `0`.
  - `agents/code-reviewer.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md` and the lessons file contain no three-apostrophe run (each grep exit `1`).
  
  Green at base (every generated file is in sync today). Its subject is consistency after the regeneration this task performs: a corpus edit without regeneration, or a hand edit inside a block, reddens it.
  - check: rc=0; export LC_ALL=C; L=$(bash bin/team-paths.sh --get lessons) || exit 1; test -s "$L" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac9.XXXXXX") || exit 1; bash bin/check-playbook.sh "$L" > "$T/cp" 2>&1 || rc=1; awk '$1 == "marker" && $2 ~ /^playbook-/ { for (i = 3; i <= NF; i++) print $i; print "templates/prompt-blocks/" $2 }' templates/prompt-blocks/registry.txt | sort -u > "$T/files"; test -s "$T/files" || exit 1; S="$T/scratch"; while IFS= read -r f; do mkdir -p "$S/$(dirname "$f")" && cp "$f" "$S/$f" || rc=1; done < "$T/files"; mkdir -p "$S/templates/prompt-blocks" || exit 1; cp templates/prompt-blocks/registry.txt "$S/templates/prompt-blocks/registry.txt" || exit 1; bash bin/gen-playbook-blocks.sh --root "$S" --lessons "$L" > "$T/gp" 2>&1 || rc=1; while IFS= read -r f; do cmp -s "$f" "$S/$f" || rc=1; done < "$T/files"; bash bin/check-prompt-sync.sh > "$T/ps" 2>&1 || rc=1; bash bin/gen-codex-agents.sh --root . --out-dir "$T/out" > "$T/gc" 2>&1 || rc=1; for r in tech-lead pm-spec engineer qa-verifier code-reviewer; do test -s "$T/out/shell-team-$r.toml" || rc=1; done; bash bin/check-codex-agents.sh --root . --out-dir "$T/out" > "$T/cc" 2>&1 || rc=1; for f in agents/code-reviewer.md skills/run/SKILL.md skills/goal/SKILL.md "$L"; do grep -qF "'''" "$f"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC10** The worked instance (decision 8). In the committed `HEAD` blob of `.shell-team/reviews/T-1168.md`, the line `## Codex Review round 3` occurs exactly once. In that round's `#### Synthesis audit ledger`, rows `| 1 |`, `| 2 |` and `| 3 |` each occur exactly once.
  - Row 1's reason names `ratified`.
  - Row 2's reason names `frozen` and `ratified`.
  - Row 3 names neither (grep exit `1`).
  - Rows 1 and 2 each have `P1` in the primary/adversarial cell and `minor` in the final cell.
  
  Green at base: this is a premise anchor on the record the rule's worked instance rests on, and a red means that source moved.

  Review-judged (QA reports it per row; the reviewer re-reads it): applying the shipped step-6 text and the run-skill bullet to rows 1–3 yields the following.
  - Rows 1, 2 and 3 are all in scope, because each one is lowered below the highest pass severity. Rows 1 and 2 are lowered from blocker (the highest after P1 normalization), and row 3 from finding 1's adversarial blocker.
  - Rows 1 and 2 each carry a status clause, which the test strikes before judging the remainder.
  - Row 3 carries no status clause about the text it names. Striking removes nothing, its merits ground stands as written, and the rule does not change row 3.
  - With row 2's status clause struck, what remains does not show that a sandbox-refused recursive delete for which the host does offer a prompt cannot reach approval, which is the case the finding names. Row 2 fails, and the finding keeps blocker.
  - With row 1's status clause struck, the remainder concedes the defect ("permission is not an order"), defers to a measurement not yet made ("AC12 measures"), and leaves one independent ground ("the run skill directs the request separately"). Whether that ground suffices is a merits judgment the rule leaves to the reader. The rule's effect on row 1 is that the status clause can no longer carry it.
  - check: rc=0; export LC_ALL=C; R=.shell-team/reviews/T-1168.md; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac10.XXXXXX") || exit 1; git show "HEAD:$R" > "$T/f" 2>/dev/null || exit 1; test -s "$T/f" || exit 1; test "$(grep -cxF '## Codex Review round 3' "$T/f" || true)" = 1 || exit 1; awk 'index($0,"## Codex Review round 3")==1{f=1} index($0,"## Codex Review round 4")==1{f=0} f' "$T/f" > "$T/r3"; awk 'index($0,"#### Synthesis audit ledger")==1{f=1; next} f && index($0,"#### ")==1{f=0} f' "$T/r3" > "$T/led"; test -s "$T/led" || exit 1; for n in 1 2 3; do grep "^| $n |" "$T/led" > "$T/row$n"; test "$(grep -c '' "$T/row$n" || true)" = 1 || rc=1; done; grep -qF ratified "$T/row1" || rc=1; grep -qF frozen "$T/row2" || rc=1; grep -qF ratified "$T/row2" || rc=1; grep -qE 'frozen|ratified' "$T/row3"; g=$?; test "$g" -eq 1 || rc=1; for n in 1 2; do awk -F'|' '{print $4}' "$T/row$n" | grep -qF P1 || rc=1; awk -F'|' '{print $5}' "$T/row$n" | grep -qF minor || rc=1; done; test "$rc" -eq 0

- [ ] **AC11** Nothing else changes (Non-goals). Each of the following, as tracked at the base, exists and is byte-identical to its base blob (a symlink is compared by its target text):
  - every file under `agents/`, `bin/`, `templates/`, `skills/`, `tests/`, `docs/` and `.github/`, except `agents/code-reviewer.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md` and the **AC8** file set;
  - `README.md`, `README.ja.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json` and `.shell-team/retros/2026-10-03-sprint-b-close.md`;
  - every file under `.shell-team/` whose name begins `T-1168` followed by `-` or `.`.
  
  The set of files the index tracks under those seven directories equals the base set, and no untracked, non-ignored file exists under them. Positive controls: the base set names `agents/code-reviewer.md`, and the T-1168 set names `.shell-team/reviews/T-1168.md`. This is merge-point-scoped and expected to go stale once a later task's edits to these files land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac11.XXXXXX") || exit 1; OT='A precedent cited as grounds is a claim, not an observation'; git ls-tree -r --name-only "$B" -- agents bin templates skills tests docs .github > "$T/l" || exit 1; grep -qxF agents/code-reviewer.md "$T/l" || exit 1; git grep -l -F -e "$OT" "$B" -- templates/prompt-blocks agents > "$T/g0" || exit 1; sed "s/^$B://" "$T/g0" > "$T/gen"; test -s "$T/gen" || exit 1; printf '%s\n' agents/code-reviewer.md skills/run/SKILL.md skills/goal/SKILL.md >> "$T/gen"; grep -vxF -f "$T/gen" "$T/l" > "$T/k"; git ls-tree -r --name-only "$B" -- .shell-team > "$T/st" || exit 1; grep -E '/T-1168[-.]' "$T/st" > "$T/t68"; grep -qxF .shell-team/reviews/T-1168.md "$T/t68" || exit 1; cat "$T/t68" >> "$T/k"; printf '%s\n' README.md README.ja.md CHANGELOG.md .claude-plugin/plugin.json .shell-team/retros/2026-10-03-sprint-b-close.md >> "$T/k"; while IFS= read -r f; do git show "$B:$f" > "$T/x" 2>/dev/null || { rc=1; continue; }; if [ -L "$f" ]; then test "$(readlink "$f")" = "$(cat "$T/x")" || rc=1; elif [ -f "$f" ]; then cmp -s "$T/x" "$f" || rc=1; else rc=1; fi; done < "$T/k"; sort "$T/l" > "$T/o"; git ls-files -- agents bin templates skills tests docs .github | sort > "$T/n"; cmp -s "$T/o" "$T/n" || rc=1; git ls-files --others --exclude-standard -- agents bin templates skills tests docs .github > "$T/u" || rc=1; test ! -s "$T/u" || rc=1; test "$rc" -eq 0

- [ ] **AC12** Every suite the edited paths reach stays green, and no suite with a recursive delete is run. The suite set is derived at run time: every `tests/*/run.sh` that `git grep -lE` finds naming `code-reviewer`, `skills/run/SKILL.md`, `skills/goal/SKILL.md`, `lessons.md`, `playbook-` or one of the four playbook-carrying agent files, plus nine named suites:
  - `tests/check-prompt-sync`
  - `tests/check-playbook`
  - `tests/gen-playbook-blocks`
  - `tests/playbook-promote`
  - `tests/codex-agents`
  - `tests/codex-skeleton-hygiene`
  - `tests/check-invocation-path`
  - `tests/check-refreeze-grant`
  - `tests/check-oversight`
  
  The set must include `tests/check-playbook/run.sh`. Each suite is first grepped for a recursive delete, and a match is a failure: that suite is not run. Otherwise the suite runs with a file-size limit and capped output, exits `0` and prints no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac12.XXXXXX") || exit 1; git grep -lE 'code-reviewer|skills/(run|goal)/SKILL\.md|lessons\.md|playbook-|agents/(tech-lead|pm-spec|engineer|qa-verifier)\.md' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; printf '%s\n' tests/check-prompt-sync/run.sh tests/check-playbook/run.sh tests/gen-playbook-blocks/run.sh tests/playbook-promote/run.sh tests/codex-agents/run.sh tests/codex-skeleton-hygiene/run.sh tests/check-invocation-path/run.sh tests/check-refreeze-grant/run.sh tests/check-oversight/run.sh >> "$T/d"; sort -u "$T/d" > "$T/suites"; grep -qxF tests/check-playbook/run.sh "$T/suites" || rc=1; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; ( ulimit -f 200000; set -o pipefail; bash "$s" < /dev/null 2>&1 | head -c 20000000 > "$T/log" ) || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` naming one of the edited paths, or a playbook-carrying agent, at which point the derived suite set this criterion runs changes.

- [ ] **AC13** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1172-synthesis-downgrade-ground.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1172-ac13.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes:**

1. **Ledger rows a synthesis writes.** A row can be:
   - a downgrade whose reason rests only on the reviewed text's frozen or ratified status;
   - one whose reason gives that status plus merits arguments (T-1168 round 3, rows 1 and 2);
   - one whose reason gives merits only (row 3);
   - an `out-of-input-space` row citing an Out-of-scope line;
   - a rejection;
   - an upgrade (not governed);
   - the `no severity changes` sentinel.
2. **Pass severities.** A finding raised by one pass. A finding raised by both passes at different severities (primary P1, adversarial blocker or major). Codex-native labels normalized through the existing map, with an unknown label rounding up.
3. **Hosts.** On the Claude Code host, `code-reviewer` runs its own `codex exec` passes and synthesizes in step 6. On the Codex CLI host, the Claude-side pass reads `## Output` for the verdict shape, and the spawned `code-reviewer` synthesizes.
4. **Verdicts to transcribe.** `APPROVE` with lowered rows. `REQUEST_CHANGES` with lowered rows. `BLOCKED — review not established`, which has no verdict to transcribe and is handled unchanged by the Evidence-ledger gate.
5. **Where a restored finding's defect sits.** In the delivered change, which `engineer` can fix. In frozen intent text, which needs a class-B re-freeze and the human's GO.
6. **The corpus.** One entry appended by `bin/playbook-promote.sh` and one entry superseded. Regeneration into the four playbook blocks and their consumer agents. Codex custom agents regenerated from `agents/*.md`.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Machine detection of a status ground. No checker parses a reason cell, and no tag marks one. The test is a reading by the reviewer and the orchestrator.
2. A reason written adversarially to hide a status ground behind merits-shaped wording beyond what decision 1 already names ("approved", "what the frozen or ratified intent prescribes"). Such a reason is left to the reader's judgment, with no further enumeration.
3. Retroactive application to merged review records, T-1168's included.
4. Spec-review mode and review-response mode. Neither writes a synthesis ledger.
5. A lowering between two minor-class labels that changes no verdict (minor to nit). The rule still applies, but no routing follows from it.

<!-- END intent-block: T-1172 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Strike-the-status test; failed row keeps the highest pass severity (decision 1) | **AC1** (tokens + review-judged) |
| 2 | Rejection counts as a lowering (decision 1) | **AC1** (review-judged), **AC4** (review-judged) |
| 3 | Rule in step 6; pointer in `## Output` ledger placeholder; host-dispatch block not edited (decision 2) | **AC1**, **AC2**, **AC11** |
| 4 | code-reviewer changes only by added lines in those two regions (decision 2) | **AC3** |
| 5 | Highest severity any pass assigned, after normalization (decision 3) | **AC1**, **AC4** (tokens + review-judged) |
| 6 | `out-of-input-space` rows unaffected; no new tag; verbatim list, normalization map, `:238` rule unchanged (decision 4) | **AC1** (token), **AC3** (additive-only) |
| 7 | Run-skill `Downgrade-ground check` bullet: before any verdict, each row, routing, class-B escalation, board line (decision 5) | **AC4** |
| 8 | Nothing else in the run skill changes (decision 5) | **AC5** |
| 9 | Goal loop references the check by path (decision 6, droppable) | **AC6** |
| 10 | One integrated active entry supersedes 2026-09-02; only Status changes in the old entry (decision 7) | **AC7** |
| 11 | Regenerated blocks and consumers carry the new entry and not the old; consumers change only in the playbook region (decision 7) | **AC8** |
| 12 | Corpus and generated files consistent; no three-apostrophe run (decision 7, `bin/gen-codex-agents.sh:348`) | **AC9** |
| 13 | Worked instance: rows 1–3 in scope; rows 1 and 2 carry a status clause, row 3 does not and is unchanged (decision 8) | **AC10** |
| 14 | No change outside the allowed files; T-1168 records and the retro unchanged (Non-goals) | **AC11** |
| 15 | No spec-review / review-response change (Non-goals) | **AC3** |
| 16 | Suites the edited paths reach stay green; none with a recursive delete run | **AC12** |
| 17 | Spec declarations and board conformant | **AC13** |
| 18 | No claim of live obedience (Non-goals) | info-only (not promoted to AC) — a disclosure of the ceiling, not a property of the diff |
| 19 | No version bump, changelog, push, merge or release (Non-goals) | info-only (not promoted to AC) — loop and release actions, not a property of the diff |
| 20 | Pre-commitment drop order (Goal) | info-only (not promoted to AC) — a disposition for the loop to execute, not a property of the diff |

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `docs/workflow.md` | `:177` "curated verdict + severity ledger" | unchanged, still accurate: the ledger keeps its shape, and this task changes which lowered rows stand |
| `docs/workflow.ja.md` | `:174` "curated verdict + severity ledger" (read) | unchanged, same reason |
| `README.md` / `README.ja.md` | none | no sentence describes the synthesis ledger |
| `docs/adopting.md` `:720`–`:733` (read) | Codex-host step 11, agent regeneration | unchanged: it already tells an adopter to re-run step 3 "after a plugin upgrade", which covers the changed `code-reviewer` body |

`.codex/agents/` is gitignored, so no tracked copy changes. **AC9** confirms that regeneration succeeds.

## Version derivation note

Premise (relayed from the Routing Map, operator-approved): PATCH v2.8.5.
- **Headline test: not met.** Nothing new becomes possible for an adopter. A reviewer's lowered rating, and the orchestrator's reading of it, is judged by a stricter ground.
- **Default-reachability test: met.** The review step runs on every default run.

Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed:** the issue #681 body in `## Problem` is the coordinating session's corrected text, and this role did not fetch it from the tracker. Its factual claims about T-1168 were re-measured here against `.shell-team/reviews/T-1168.md` `:247`–`:255` and `.shell-team/todo.md` `:38`–`:39`, and they match.
- **Relayed:** "the orchestrator reads the run skill, not the corpus." Not measurable from a file; consistent with `agents/code-reviewer.md` `:240` for the reviewer half.
- **Discrepancy noted, not a defect:** the retro's lesson candidate (`.shell-team/retros/2026-10-03-sprint-b-close.md` `:73`) says the new lesson should not supersede the 2026-09-02 entry. The issue's Expected, approved by the operator, says supersede with an integrated entry. This spec follows the issue, and the retro is not edited (**AC11**).
- **Measured here (read):**
  - The Routing Map's anchors: `agents/code-reviewer.md` `:102`, `:105`, `:134`–`:137`, `:237`, `:238`, `:240`; `skills/run/SKILL.md` `:102`, `:103`, `:117`; `skills/goal/SKILL.md` `:87`, `:88`; `.shell-team/lessons.md` `:1185`, `:1418`, `:1439`; `bin/gen-codex-agents.sh` `:346`–`:348`; `.github/workflows/check-handoff.yml` `:179`–`:215`, `:376`–`:385`. All match what this role opened.
  - The phrase `A precedent cited as grounds is a claim` occurs in exactly nine files: `.shell-team/lessons.md`, the four `templates/prompt-blocks/playbook-{tech-lead,pm-spec,engineer,qa-verifier}.md` and the four `agents/{tech-lead,pm-spec,engineer,qa-verifier}.md` (this role's search).
  - No file under `tests/` or `bin/` matches `rm -[a-zA-Z]*[rR]` or `find .*-delete` (this role's search).
  - No `'''` occurs in `agents/*.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md` or the lessons file.
- **Count premises at the base, own coinage (this role's reading; the freeze run measures each live at `921d0c42`):**
  - Each of `frozen or ratified status`, `struck`, `highest severity`, `not downgraded` and `Downgrade-ground check` occurs 0 times in `agents/code-reviewer.md`, `skills/run/SKILL.md` and `skills/goal/SKILL.md`. `precedent-as-grounds` occurs 0 times in the lessons file. `out-of-input-space` occurs in `agents/code-reviewer.md` outside CR step 6 only.
  - So **AC1**, **AC2**, **AC4**, **AC6**, **AC7** and **AC8** are red at base.
  - **AC3**, **AC5**, **AC9**, **AC10**, **AC11**, **AC12** and **AC13** are green at base. Each is an invariant, a premise anchor or a consistency/conformance check, and the reason is stated in its criterion.
  - **AC13** is green once this board entry exists.
- **Borrowed-vocabulary sweep:** the following are another document's tokens. Each is asserted present, not `= 0`, and each line start occurs once by this role's reading. The freeze run measures them.
  - `6. Synthesize a verdict.`, `## Output`, `#### Synthesis audit ledger`, `#### Recommendation`, `synthesis audit ledger`, `no severity changes` and `out-of-input-space` (`agents/code-reviewer.md`);
  - `6. **Review**`, `7. **Done**` and `Evidence-ledger gate (T-1153)` (`skills/run/SKILL.md`);
  - `severity calibration in the review briefing (referenced` and `The gate is **green**` (`skills/goal/SKILL.md`);
  - `## Codex Review round 3` / `round 4` and the round-3 ledger rows (`.shell-team/reviews/T-1168.md`);
  - the lessons heading of the 2026-09-02 entry.
- **AC12**'s derived suite set: by this role's search, the regex matches 20 suites, including the nine named ones. None contains a recursive delete. `tests/install/run.sh` writes its scratch under `/tmp/claude/`, outside `$TMPDIR`, as it does in CI.
- Process-group termination on timeout for **AC12** relies on `bin/check-acs.sh`'s own `CHECK_ACS_TIMEOUT` handling, the same shape T-1171's **AC11** used. The freeze run states whether that kills the whole group, or runs the suites under its own group-kill wrapper.
- Downstream impact on merged specs is judged by CI and this task's own check lines, not by re-running past specs' check lines (operator ruling). Merged criteria that assert the bytes of `agents/code-reviewer.md`, `skills/run/SKILL.md`, the playbook blocks or the lessons file go stale or flip under this change as a matter of course. CI's dogfood steps and **AC9**/**AC12** are this task's measurement.
- The next task id is T-1172. The board's highest is T-1171, and the only `T-1172` file under `.shell-team/` is the interventions record.

## Open questions

- none blocking.

## Notes for engineer

- **Files touched:**
  - `agents/code-reviewer.md`: step 6 and the `## Output` ledger placeholder, added lines only.
  - `skills/run/SKILL.md`: one new bullet in step 6.
  - `skills/goal/SKILL.md`: one new line after `:87`.
  - `.shell-team/lessons.md`, through `bin/playbook-promote.sh` plus a two-line hand edit of the 2026-09-02 entry.
  - The four playbook blocks and four consumer agents, only through `bin/gen-playbook-blocks.sh`.
- **code-reviewer step 6 (AC1, AC3).** Add one or more new lines after `:105`, indented like a continuation of item 6. Do not modify `:105` itself, because **AC3** allows added lines only. Suggested text:
  - "**A downgrade's ground must stand without the reviewed text's own frozen or ratified status (T-1172).** For each ledger row that lowers a finding below the highest severity any pass assigned it (after the normalization map; a rejection is the largest lowering), strike from its reason every clause resting on the frozen or ratified status of the text the finding names as defective — that the text is frozen, ratified or approved, or that the defect is what the frozen or ratified intent prescribes."
  - "If, with those clauses struck, what remains does not by itself show that the named defect is absent or less severe than that highest severity, the row is not a downgrade: the finding keeps the highest severity any pass assigned, and the verdict follows from it."
  - "The status may appear as context; it cannot be the part that carries the downgrade. An `out-of-input-space` row grounded on its cited Out-of-scope line is unaffected — that line states which inputs are in scope, not the reviewed text's status."
  
  Required literals: `frozen or ratified status`, `struck`, `highest severity`, `out-of-input-space`. Prefer "each row", "any pass": the plural instance is two lowered rows and two passes.
- **Output placeholder (AC2, AC3).** Add one new line inside the fenced block, between the `|---…|` line and `#### Recommendation`. Do not edit the existing `<one row per …>` line. For example: `<a row that lowers a severity keeps only a ground that still carries it with the reviewed text's frozen or ratified status struck — step 6>`.
- **Run skill (AC4, AC5).** Add one physical line, a bullet `   - **Downgrade-ground check (T-1172).** …`, inside step 6, for example right after the Evidence-ledger gate bullet at `:103`. Change no other line. It must name:
  - `frozen or ratified status`, `struck`, `not downgraded`, `highest severity`, `REQUEST_CHANGES`, `class-B` and `board`.
  
  Content (decision 5):
  - Before transcribing any verdict, read each ledger row lowered below the highest severity any pass assigned (a rejection included), and apply the test with status clauses struck.
  - A failed row is treated as not downgraded.
  - A restored blocker or major means no `APPROVE` is transcribed to `READY_FOR_MERGE`, and the round is handled as a `REQUEST_CHANGES` carrying that finding: route it to `engineer`, or, when the defect sits in frozen intent text, escalate to the human because a class-B re-freeze needs one.
  - Name each failed row and why its ground failed in the board line that records the round.
  
  The phrase `Downgrade-ground check` must occur on that one line only, in the whole file.
- **Goal skill (AC6).** Add one physical line between `:87` and `:88`, in the `:87` style. For example: `   - **Downgrade-ground check (referenced, not restated)**: before this loop counts a Codex verdict as green, apply the Downgrade-ground check that `skills/run/SKILL.md`'s Review step carries — read that bullet; the wording is not restated here.` The phrase `Downgrade-ground check` may appear only on that line, so do not repeat it in the label and the body. Change no other line.
- **Corpus (AC7–AC9).** Steps:
  1. Run `bash bin/playbook-promote.sh` with `--applies-to all`, `--scope loop`, `--status active`, `--category verification-discipline`, `--source .shell-team/retros/2026-10-03-sprint-b-close.md`, and a `--title` ending `(supersedes the precedent-as-grounds entry)`. `--date` defaults to today.
  2. Hand-edit the 2026-09-02 entry: change `- **Status**: active` to `- **Status**: superseded`, and insert `- **Superseded-by**: <exact "date — title" of the new entry>` right after it, following the precedent at `:1184`–`:1185`.
  3. Run `bash bin/gen-playbook-blocks.sh` (four blocks plus their consumer marker regions) and `bash bin/check-prompt-sync.sh`.
  
  The Rule must name `re-read`, `ratified`, `synthesis`, `severity` and `frozen or ratified status`, and keep both halves of the old Rule. Suggested Rule: "A ground is independent only if it stands without the standing of what it judges: a writer citing a prior task, version, decision or record as carrying a property re-reads that source for the exact property first; a prior tier or decision the operator approved is a derivation they ratified, not independent evidence for the next one; and a review synthesis that lowers a finding below the highest severity a pass assigned keeps that lowering only on a ground that still holds with the reviewed text's own frozen or ratified status struck, which whoever transcribes the verdict checks before transcribing."
  
  The new entry's title and Rule must not contain the exact phrase `A precedent cited as grounds is a claim, not an observation`. **AC8** requires that phrase to appear nowhere under `templates/prompt-blocks` or `agents` after regeneration, and every generated line carries the entry's key (`date — title`), so reusing it reddens **AC8**.

  The Why and How to apply lines record the pattern, not incident identifiers (no task ids, per the promotion script's header). Nothing may contain three consecutive apostrophes (`bin/gen-codex-agents.sh:348`).
- **Do not edit** `templates/prompt-blocks/host-dispatch.md`, any other block by hand, any `docs/` file, README, `bin/`, `tests/` or `.github/`.
- **Mutation self-check:** before handing off, confirm the following. Run each under `ulimit -f` with capped output, scratch in `$TMPDIR`, and restore every file afterwards.
  - Deleting `struck` from your step-6 text reddens **AC1**.
  - Removing the run-skill bullet reddens **AC4**.
  - Editing a word in the `:238` line reddens **AC3**.
  - Skipping regeneration reddens **AC8**/**AC9**.
- Measured-at-ref command check: not applicable. No deliverable prints a command beside a `measured at <ref>` label.
- Recursive deletion: none in any file you write or in any check line here. Leave temp files under `$TMPDIR`.
