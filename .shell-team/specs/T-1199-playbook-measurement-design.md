# Design how to measure what each playbook block's lessons still prevent

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1199

## Problem

The machinery inventory (`docs/loop-engineering/machinery-inventory.md`, issue #754) marks all four generated playbook blocks `unknown` (`:295`, `:302`, `:309`, `:316`). They are the largest per-run context the loop loads. Each one is injected in full into its role on every dispatch of engineer, qa-verifier, pm-spec and tech-lead, and nobody can say which of their bullets still change what a current model does. Removing bullets by impression or by age is ruled out, so a removal decision needs a measurement, and a measurement first needs a design. Issue #782 asks for that design only. It does not ask for the measurement or for any removal.

## Summarized sources

- **Issue #782 body.** The coordinating session relayed its essentials. This role cannot open the tracker, so the text is labelled relayed in Assumptions. The distinctions carried over:
  - The deliverable is a measurement **design**, not the measurement and not any removal.
  - The design document states five things:
    1. the unit measured (a bullet, a lesson or a category) and why;
    2. how a bullet's effect is observed, for example a with/without comparison on a fixed task set or the recorded failures the bullet was promoted for, and what counts as "still prevents" versus "no longer needed";
    3. the cost of one measurement (runs, wall-clock, tokens) and what the host would have to do, if anything;
    4. how a result feeds a removal decision (who approves, what record is kept), consistent with #754's rule that removals are approved before they are filed;
    5. what cannot be measured this way, stated as such.
  - Ruled out: removing bullets now, and judging bullets by age alone.

  Restated by the Goal sentence, D1–D5, Non-goals, **AC2**, **AC3**, **AC5** and **AC8**.
- **`docs/loop-engineering/machinery-inventory.md`**, read with the Read tool.
  - `:23` (`## Verdict scope`): verdicts are proposals, and "follow-up issues are filed only after review, one per approved removal or simplification". This is the approve-before-filing rule D4 carries over.
  - `:291-317`: the four playbook rows. Each is `verdict: unknown`, and each host-cost cell reads "loaded in full on every dispatch of its role". Lines / words: engineer 88 / 8997, pm-spec 108 / 10785, qa-verifier 76 / 7837, tech-lead 53 / 5395.
  - `:18`: word counts use a Unicode-aware split that runs about 2 percent above `LC_ALL=C wc -w`, so the two methods differ.
  - `:295`: the engineer row names `agents/engineer.md:136` as a bullet that states its own retirement condition.

  Restated by D3, D4, **AC5** and **AC8**.
- **`docs/loop-engineering/playbook-block-size-deferral.md`**, read in full.
  - claim-1 (`:45`): dilution is a real mechanism, but its harm was never measured, at either measurement.
  - claim-3 (`:47`): two sweeps found no retirement stock that would shrink a generated block.
  - claim-4 (`:50`): the line-count warning measures the wrong quantity.
  - claim-5 (`:51`): re-evaluation is driven by signals, not by a schedule.
  - signal-1 (`:60`): "Dilution is actually observed". signal-4 (`:63`): loop throughput lets dilution be measured for real.
  - "Not a third sweep" (`:85-87`): the record adds no new count over the corpus.

  Restated by D5 and **AC8**. This note measures the effect of each bullet. It measures neither block size nor retirement stock, and it does not contradict claims 1–5.
- **`.shell-team/lessons.md` header** (`:9-29`).
  - `Applies-to` takes a comma list from `{engineer, qa-verifier, tech-lead, pm-spec, all}`, and `all` means the four roles at once (`:14-15`).
  - `Scope` is `loop` or `maintainer`. A `maintainer` entry is never emitted into a shipped block (`:27`).
  - A `superseded` entry must carry `Superseded-by`, naming the `active` entry that now covers its ground (`:29`).

  Restated by D1, D4 and **AC8**.
- **`bin/check-playbook.sh:732-733`**: when a `superseded` entry has an empty or missing `Superseded-by`, the checker emits "a retired entry must name its replacement". So a lesson judged "no longer needed" that has no successor has no conforming retirement path today. Restated by D4 and **AC8**.
- **The self-stated retirement bullet.** It is one corpus entry, `.shell-team/lessons.md:1235` (`2026-08-17 — A quantitative conclusion's QA PASS is necessary, never sufficient…`), `Applies-to: all` (`:1237`).
  - Its digest line carries "This entry retires when script-generated record tables (issue #268) …".
  - That phrase occurs once in each of the four `templates/prompt-blocks/playbook-*.md` files, and once in each of `agents/engineer.md:136`, `agents/pm-spec.md:227`, `agents/qa-verifier.md:152` and `agents/tech-lead.md:157` (Grep count).

  This is why the unit question has to address entries that appear in several blocks. Restated by D1, D5 and **AC8**.
- **`bin/check-pii-shapes.sh:229-249`**: `--paths <path> [<path>...]` scans exactly the named files. Exit `0` means clean, `1` means findings, and `2` means a usage or structural error, including a `--paths` run that read no regular text file. Restated by **AC1**.
- **`bin/check-adopter-docs.sh:2-40`**: it exits `0` silently, `1` on a content refusal, and `2` when the input could not be evaluated, writing one token on stderr and nothing on stdout. A `no` declaration carries neither `adopter-surface` nor `shipped-docs`. Restated by **AC6**.
- **`bin/team-paths.sh:78`**: `--get todo` prints the board path. **`bin/check-handoff.sh`** lints the board line format (its use as a board linter is established on this board, for example T-1197's QA lines). Restated by **AC6**.
- **`bin/derive-populations.sh:13`, `:31`, `:451`**: it emits a `<!-- BEGIN derivation: <label> -->` block, and a record pairs each block with a `- reproduce:` line. Restated by D2.
- **`.github/workflows/check-handoff.yml:274`**: a step named `check-pii-shapes on the PR diff`. Restated by **AC9**.
- **Reuse candidates relayed by tech-lead's map**: `docs/loop-engineering/tier2-subject-harness.md`, `bin/gen-loop-replay.sh`, `bin/rollup-runs.sh`, `bin/rollup-track.sh`, `bin/derive-populations.sh` and `.shell-team/runs/shell-team.jsonl`. This role confirmed the tracked files exist (Glob) but did not read what they do. The frozen block claims only that the note evaluates each one (D7), never what a candidate does. Restated by D7.

## Goal

<!-- BEGIN intent-block: T-1199 -->

- user-visible: no — the deliverable is an internal design note under `docs/loop-engineering/`, read by the operator and by later planning. No command, configuration key, generated block or adopter-facing behaviour changes.
- verification-class: no-mechanism — the diff adds one Markdown document and this task's records. It touches no path under `bin/`, `tests/`, `templates/` or `.github/`, and no checker's semantics.
- verification-ceiling: unit-and-static — **AC1**–**AC8** and **AC10** are settled in a plain checkout. They read the new document, the commit range and the working tree, and read the exit codes of `check-pii-shapes.sh`, `check-adopter-docs.sh` and `check-handoff.sh`. **AC9** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/781-skills-run-dedupe; then B=$(git merge-base refs/heads/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/781-skills-run-dedupe; then B=$(git merge-base refs/remotes/origin/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi

**Goal (one sentence).** `docs/loop-engineering/playbook-bullet-measurement.md` exists and states, under nine fixed headings, how to measure what each playbook bullet still prevents:
- the unit measured and why;
- how an effect is observed;
- what counts as still-prevents versus no-longer-needed;
- the cost of one measurement, in cost lines that each carry a derivation command or a labelled estimate;
- how a result reaches a removal decision, including the retirement-schema gap;
- what the design cannot measure;
- its verdict scope;
- its relation to the block-size deferral;
- where bullets that state their own retirement condition sit.

Nothing in the corpus, the blocks, the agents or `bin/` changes.

**Decisions frozen here** (each is promoted to a criterion or exempted in the correspondence table):

- **D1 — the nine headings.** The document carries each of these lines exactly once (**AC2**):
  - `## Unit measured`
  - `## How an effect is observed`
  - `## Still prevents versus no longer needed`
  - `## Cost of one measurement`
  - `## From result to removal decision`
  - `## What this cannot measure`
  - `## Verdict scope`
  - `## Relation to the block-size deferral`
  - `## Bullets that state their own retirement condition`

  `## Unit measured` chooses between a bullet, a lesson entry and a category, gives the reason, and addresses entries with `Applies-to: all` that appear as one bullet in each of several blocks (**AC8**).
- **D2 — the cost-line grammar.** Every line beginning `- cost: ` has the form `- cost: <dimension> — <value> — derivation: <command>` or `- cost: <dimension> — <value> — estimate: <basis>`.
  - `<dimension>` is one of `runs`, `wall-clock`, `tokens` and `host`. Each dimension appears on at least one cost line.
  - `<value>` and the tail are non-empty.
  - Any other numeric population the document states goes through a `bin/derive-populations.sh` block preceded by its `- reproduce:` line, or is labelled as an estimate on the line where it appears.

  (**AC3**; the "other numeric population" clause is a QA reading item.)
- **D3 — age is not a criterion.** The document carries one line beginning `- not-a-criterion: age — ` followed by its reason. (**AC5**)
- **D4 — from result to removal decision.** `## From result to removal decision` states:
  - who approves a removal, and what record is kept;
  - that approval comes before filing, citing `docs/loop-engineering/machinery-inventory.md`;
  - the retirement-schema gap. A `superseded` lesson must name an active successor in `Superseded-by`, and `bin/check-playbook.sh` rejects a missing pointer, so a "no longer needed" lesson with no successor has no retirement path today;
  - `Scope: maintainer` as the other existing lever.

  It describes the schema and never changes it. (**AC8**; the lessons schema stays unchanged under **AC4**.)
- **D5 — relation to existing records.**
  - `## Relation to the block-size deferral` cites `docs/loop-engineering/playbook-block-size-deferral.md`, claim-1 and signal-1. It states that this note measures the effect of each bullet, not block size or retirement stock, and it does not contradict claims 1–5.
  - `## Bullets that state their own retirement condition` places bullets that already state a retirement condition, at least the issue #268 one, relative to the measurement.

  (**AC8**; non-contradiction of claims 1–5 is a QA and review reading item.)
- **D6 — no model is run, and verdicts are proposals.** `## Verdict scope` names the consumer, the operator and later planning. It states that the design runs no measurement and no model, and that any measurement result it describes is a proposal. (**AC8** for the word `proposal`; the rest is a reading item.)
- **D7 — reuse candidates are evaluated.** The note names each of these, and either says whether and how the design would reuse it or carries a one-line `not evaluated: <reason>`:
  - `docs/loop-engineering/tier2-subject-harness.md`
  - `bin/gen-loop-replay.sh`
  - `bin/rollup-runs.sh`
  - `bin/rollup-track.sh`
  - `bin/derive-populations.sh`
  - `.shell-team/runs/shell-team.jsonl`

  The depth of each evaluation is the droppable component. Naming the candidate is not droppable. (**AC10**; the evaluation's content is a reading item.)

**Pre-commitment (frozen before round 1).** The trigger and the disposition below are AI self-discipline, proposed by the coordinating session and never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning.
  - (N1) The issue's five sections, which map onto `## Unit measured`, `## How an effect is observed` together with `## Still prevents versus no longer needed`, `## Cost of one measurement`, `## From result to removal decision` and `## What this cannot measure`.
  - (N2) The cost-derivation grammar (D2, **AC3**).
- **Droppable, first.** The depth of the reuse-candidate evaluation. A candidate's evaluation that review finds unsupported shrinks to a one-line "not evaluated: <reason>". The finding travels into that line.
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same component. A round interrupted before a verdict does not count.

## Non-goals

- **No bullet, lesson, block, agent or `bin/` script is removed or edited.** (**AC4**)
- **No measurement and no model run is performed by this task.** The note designs the measurement and does not run it. (info-only; a reading item)
- **The lessons schema is not changed.** The `Superseded-by` gap is described, not closed. (**AC4**)
- **No bullet is judged by its age.** (**AC5**)
- **No third retirement-stock sweep and no block-size re-adjudication.** (info-only; a reading item against the deferral record)
- **No removal issue is filed by this task.** (info-only; not observable by a command)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no behaviour verification of a mechanism this task does not touch.** The deliverable class is `no-mechanism`. Every criterion is a string presence or absence read, a byte-scoped diff, a checker's exit code, or a records-line existence check. (info-only; disclosed in Blast radius)
- **No CHANGELOG entry and no release impact.** (**AC7**)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Temporary files go under `$TMPDIR` and are left there.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **File existence first.** Every line that reads a file first asserts that the file is non-empty.

- [ ] **AC1** The document exists, is non-empty, and carries no PII-shaped or host-local content. `bash bin/check-pii-shapes.sh --paths docs/loop-engineering/playbook-bullet-measurement.md` exits `0`.
  - check: D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; test -s bin/check-pii-shapes.sh || exit 1; bash bin/check-pii-shapes.sh --paths "$D"

- [ ] **AC2** (D1; N1.) Each of the nine fixed headings occurs exactly once as a whole line. Violations are printed per heading.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; for h in 'Unit measured' 'How an effect is observed' 'Still prevents versus no longer needed' 'Cost of one measurement' 'From result to removal decision' 'What this cannot measure' 'Verdict scope' 'Relation to the block-size deferral' 'Bullets that state their own retirement condition'; do n=$(grep -cxF -- "## $h" "$D"); test "$n" = 1 || { rc=1; printf 'heading %s occurs %s times\n' "$h" "$n"; }; done; test "$rc" -eq 0

- [ ] **AC3** (D2; N2.) Cost-line grammar.
  - At least one line begins `- cost: `.
  - Every such line matches `- cost: <runs|wall-clock|tokens|host> — <non-empty value> — derivation: <non-empty>` or the same with `estimate:`.
  - Each of the four dimensions appears on at least one conforming line.
  - Failing lines and missing dimensions are printed.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; awk 'BEGIN { n = split("runs wall-clock tokens host", K, " ") } /^- cost: / { c++; if ($0 !~ /^- cost: (runs|wall-clock|tokens|host) — [^ ].* — (derivation|estimate): [^ ]/) { printf "bad cost line %d: %s\n", NR, $0; bad = 1; next } d = $0; sub(/^- cost: /, "", d); sub(/ .*/, "", d); seen[d] = 1 } END { if (c == 0) { print "no cost lines"; bad = 1 } for (i = 1; i <= n; i++) if (!(K[i] in seen)) { printf "missing dimension %s\n", K[i]; bad = 1 } exit bad }' "$D" || rc=1; test "$rc" -eq 0

- [ ] **AC4** No removal and no schema change. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **The base.** `<base>` is the frozen `base-ref-discriminator` expression.
  - **Positive control.** `.shell-team/lessons.md` exists at `<base>`.
  - **What it asserts.** `.shell-team/lessons.md`, `templates/prompt-blocks/`, `agents/` and `bin/` show:
    - no committed change in `<base>...HEAD`;
    - no staged change;
    - no unstaged change;
    - no untracked stray.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1199-ac4.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/781-skills-run-dedupe; then B=$(git merge-base refs/heads/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/781-skills-run-dedupe; then B=$(git merge-base refs/remotes/origin/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; git cat-file -e "$B:.shell-team/lessons.md" || exit 1; git diff --quiet --no-renames "$B"...HEAD -- .shell-team/lessons.md templates/prompt-blocks/ agents/ bin/ || { rc=1; echo committed-change; }; git diff --quiet --no-renames --cached -- .shell-team/lessons.md templates/prompt-blocks/ agents/ bin/ || { rc=1; echo staged-change; }; git diff --quiet --no-renames -- .shell-team/lessons.md templates/prompt-blocks/ agents/ bin/ || { rc=1; echo unstaged-change; }; git ls-files --others --exclude-standard -- .shell-team/lessons.md templates/prompt-blocks/ agents/ bin/ > "$T/u" || exit 1; test ! -s "$T/u" || { rc=1; cat "$T/u"; }; test "$rc" -eq 0

- [ ] **AC5** (D3; D4; D5.) Fixed markers and cited records.
  - The document carries exactly one line beginning `- not-a-criterion: age — ` followed by non-blank text.
  - It contains `docs/loop-engineering/playbook-block-size-deferral.md`, `docs/loop-engineering/machinery-inventory.md` and `Superseded-by`.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; n=$(grep -c '^- not-a-criterion: age — [^ ]' "$D"); test "$n" = 1 || { rc=1; printf 'not-a-criterion line occurs %s times\n' "$n"; }; for s in docs/loop-engineering/playbook-block-size-deferral.md docs/loop-engineering/machinery-inventory.md Superseded-by; do grep -qF -- "$s" "$D" || { rc=1; printf 'missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC6** The records conform.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - **Positive control.** The spec, the checker and the board are each asserted non-empty first.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1199-ac6.XXXXXX") || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1199-playbook-measurement-design.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || { rc=1; cat "$T/h"; }; test "$rc" -eq 0

- [ ] **AC7** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **The base.** `<base>` is the frozen `base-ref-discriminator` expression, spelled byte-identically to the one the no-removal criterion uses.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains the document.
  - **Allowed members.**
    - `docs/loop-engineering/playbook-bullet-measurement.md`.
    - This task's records:
      - `.shell-team/specs/T-1199-playbook-measurement-design.md`;
      - `.shell-team/provenance/T-1199.md`;
      - `.shell-team/interventions/T-1199.md`;
      - `.shell-team/reviews/T-1199.md` and `.shell-team/reviews/T-1199-drift.md`;
      - raw captures `.shell-team/reviews/T-1199-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`.
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1199-ac7.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/781-skills-run-dedupe; then B=$(git merge-base refs/heads/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/781-skills-run-dedupe; then B=$(git merge-base refs/remotes/origin/feature/781-skills-run-dedupe HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF docs/loop-engineering/playbook-bullet-measurement.md "$T/s" || rc=1; grep -vxE 'docs/loop-engineering/playbook-bullet-measurement\.md|\.shell-team/(specs/T-1199-playbook-measurement-design\.md|provenance/T-1199\.md|interventions/(T-1199|no-task)\.md|reviews/T-1199(-drift)?\.md|reviews/T-1199-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || { rc=1; cat "$T/bad"; }; test "$rc" -eq 0

- [ ] **AC8** (D1; D4; D5; D6.) Section contents. Each named section, read from its heading to the next line beginning `## `, is non-empty and contains these literal strings:
  - `## Unit measured`: `Applies-to: all`.
  - `## From result to removal decision`: `Superseded-by`, `Scope: maintainer`, `bin/check-playbook.sh` and `docs/loop-engineering/machinery-inventory.md`.
  - `## Relation to the block-size deferral`: `docs/loop-engineering/playbook-block-size-deferral.md`, `claim-1` and `signal-1`.
  - `## Bullets that state their own retirement condition`: `#268`.
  - `## Verdict scope`: `proposal`.

  That each section's prose actually says what D1, D4, D5 and D6 require is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1199-ac8.XXXXXX") || exit 1; sec() { awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$D" > "$T/s" || exit 1; test -s "$T/s" || { rc=1; printf 'empty or missing section %s\n' "$1"; }; }; need() { grep -qF -- "$1" "$T/s" || { rc=1; printf 'missing %s\n' "$1"; }; }; sec 'Unit measured'; need 'Applies-to: all'; sec 'From result to removal decision'; need 'Superseded-by'; need 'Scope: maintainer'; need 'bin/check-playbook.sh'; need 'docs/loop-engineering/machinery-inventory.md'; sec 'Relation to the block-size deferral'; need 'docs/loop-engineering/playbook-block-size-deferral.md'; need 'claim-1'; need 'signal-1'; sec 'Bullets that state their own retirement condition'; need '#268'; sec 'Verdict scope'; need 'proposal'; test "$rc" -eq 0

- [ ] **AC9** CI on the pull request is green. CI's `check-pii-shapes on the PR diff` step scans the new document.
  - above-ceiling: the coordinating session, after the push and before the sprint batch GO, records the check run's result on the board. QA reports this criterion as `SKIP`.

- [ ] **AC10** (D7.) Each reuse candidate is named in the document.
  - The six candidates are `docs/loop-engineering/tier2-subject-harness.md`, `bin/gen-loop-replay.sh`, `bin/rollup-runs.sh`, `bin/rollup-track.sh`, `bin/derive-populations.sh` and `.shell-team/runs/shell-team.jsonl`.
  - Whether each one carries an evaluation or a `not evaluated: <reason>` line is a QA reading item.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/playbook-bullet-measurement.md; test -s "$D" || exit 1; for s in docs/loop-engineering/tier2-subject-harness.md bin/gen-loop-replay.sh bin/rollup-runs.sh bin/rollup-track.sh bin/derive-populations.sh .shell-team/runs/shell-team.jsonl; do grep -qF -- "$s" "$D" || { rc=1; printf 'missing candidate %s\n' "$s"; }; done; test "$rc" -eq 0

## Input space

**Reachable input classes**:

1. **The document's own lines.**
   - Headings as whole lines, with LF line endings.
   - Cost lines whose value or tail contains ` — `, backticks, `$`, quotes or a pipe.
   - Derivation tails that are multi-word shell commands, and estimate tails that are prose.
   - Prose that quotes field names in backticks, for example `` `Superseded-by` `` or `` `Applies-to: all` ``.
2. **The repository at the base and at HEAD.**
   - A stacked branch whose predecessor is present as a local branch, or only as a remote-tracking ref, or merged and gone (the develop fallback).
   - A tracked `.shell-team/lessons.md` at the base.
3. **Platforms.** bash under `LC_ALL=C` on the CI runner (Linux) and on maintainer workstations.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **A predecessor branch that resolves in neither namespace while still open**, for example in a shallow or `--single-branch` clone. The author fetches it first or routes back. A predecessor that is rebased, force-pushed, squash-merged or deleted unmerged is also a route-back.
2. **A document that starts a non-cost line with `- cost: `**, for example inside a grammar explainer. Such a line is read as data, and the engineer avoids it (Notes for engineer).
3. **Headings with trailing spaces, a CRLF checkout, or headings written in another style** (Setext or a different level). A whole-line match is the contract.
4. **A derivation command that has the right form but does not reproduce its value.** Form is checked by **AC3**. Re-running it is a QA reading item (Verdict scope), never a command.

<!-- END intent-block: T-1199 -->

## Verdict scope

- **Consumer.** The operator, and the later planning that decides whether to run a measurement and what to remove afterwards. It is an internal design note. No adopter executes it, and no gate reads it.
- **What a check line proves.** Presence and form only:
  - the headings exist once each;
  - cost lines carry a derivation or an estimate;
  - fixed markers and cited records are present;
  - nothing under the protected paths moved.

  It never proves that a design choice is sound, that a cost figure is right, or that a section avoids contradicting the deferral record.
- **What review does.**
  - It reads the design for internal consistency and checks each cost line's derivation or estimate basis.
  - It checks the relation section against the deferral record's claims 1–5, and the removal section against the inventory's approve-before-filing rule and the lessons header.
  - Findings about the inline check lines' own adversarial completeness are out of scope for a Major (operator ruling on dev-scaffold inline checks, relayed).
  - Every review briefing for this task names the consumer class above.
- **Depth.** Note depth, not shipped-code depth.

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Nine fixed headings, each once (D1) | **AC2** |
| 2 | Unit section addresses `Applies-to: all` entries (D1) | **AC8**; the reasoning is a reading item |
| 3 | Cost-line grammar, four dimensions (D2) | **AC3** |
| 4 | Other numeric populations derived or labelled estimate (D2) | info-only (not promoted to AC): a free-prose number cannot be found by a command without false positives. QA reads the document for unlabelled figures |
| 5 | `- not-a-criterion: age` marker (D3) | **AC5** |
| 6 | Removal section: approver, record, approve-before-filing, `Superseded-by` gap, `Scope: maintainer` (D4) | **AC8**, **AC5** for the cited strings; the substance is a reading item |
| 7 | Schema described, not changed (D4) | **AC4** |
| 8 | Deferral relation cites the record, claim-1 and signal-1 (D5) | **AC8** |
| 9 | No contradiction of deferral claims 1–5; not a third sweep (D5; Non-goals) | info-only (not promoted to AC): a meaning judgment, read by QA and review against the record |
| 10 | Self-stated retirement bullets placed, at least the #268 one (D5) | **AC8** |
| 11 | No model run; verdicts are proposals (D6) | **AC8** for `proposal`; the no-run statement is a reading item |
| 12 | No removal or edit of any bullet, lesson, block, agent or bin script (Non-goals) | **AC4** |
| 13 | No measurement run by this task (Non-goals) | info-only (not promoted to AC): an absence of activity, not observable in the diff beyond **AC7** |
| 14 | No removal issue filed (Non-goals) | info-only (not promoted to AC): filing happens outside the repository. The coordinating session reports it |
| 15 | No full sweep and no whole CI re-run (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 16 | No CHANGELOG, no release impact (Non-goals) | **AC7** (CHANGELOG is outside the allow-list) |
| 17 | No PII or host-local value in the document | **AC1** |
| 18 | The records conform | **AC6** |
| 19 | CI green | **AC9** (above ceiling) |
| 20 | Pre-commitment | info-only (not promoted to AC): a disposition, not a deliverable property |
| 21 | Verdict scope: review depth priced by consumer | info-only (not promoted to AC): it prices a gate's behaviour. The coordinating session carries it into each review briefing |
| 22 | Each reuse candidate is named, with an evaluation or a `not evaluated` line (D7) | **AC10** for naming; the evaluation is a reading item, and its depth is the droppable component |

## Blast radius

- **Class.** The class is `no-mechanism`, so the analysis is scoped to what this task reads and writes.
- **Read set.** No merged criterion can read `docs/loop-engineering/playbook-bullet-measurement.md` by its literal path, because the file does not exist at the base.
- **The indirection class.** This means criteria that reach `docs/` through a glob or a constructed path, mostly scope locks and `git ls-files -- docs`-style reads in merged specs.
  - They are not re-run locally, following the operator ruling relayed for T-1191 to T-1198 (no local run of past specs' check lines). This is a disclosed gap.
  - Every merged scope lock that reads `<base>...HEAD` is already merge-point-scoped.
  - CI (**AC9**) decides for the suites.
- **CI steps the diff reaches.** The diff adds no `bin/`, `tests/`, `templates/` or `.github/` path, so every fixture-suite step and every `shellcheck` step has unchanged inputs. The steps that do read this diff:
  - `check-pii-shapes on the PR diff` scans the new document and the records. **AC1** runs the same checker on the document.
  - `check-commit-identity on the PR commits` reads this branch's commits.
  - The board dogfood steps (`check-handoff`, `check-board-headings`) read the board this task edits. **AC6** runs `check-handoff.sh`.
  - The interventions dogfood step reads any interventions file this task adds.
- **Adopter-side artefacts.** None. No generated file, template or prompt block changes.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| Playbook bullet measurement design (D1–D6) | not met: no new capability for a user | not met: an internal note that no command reads | none | a design note. Nothing shipped changes behaviour |

This item's derived tier is none. The sprint tier, PATCH (v2.9.7), comes from T-1198 (relayed).

## Assumptions

- **Measured by this role** (Read, Grep and Glob tools on the working tree; branch `feature/782-playbook-measurement-design`, status clean at session start):
  - `.git/refs/heads/feature/781-skills-run-dedupe` exists, so the discriminator's first arm is the one exercised here. The relayed branch point is `59e16830`.
  - The four playbook rows in the inventory, at `:291-317`, carry the host-cost numbers quoted in Summarized sources.
  - The inventory's approve-before-filing sentence is at `:23`.
  - The lessons header's `Superseded-by` requirement is at `:29`, and `check-playbook.sh`'s missing-pointer refusal is at `:732-733`.
  - The issue #268 retirement phrase occurs once in each of the four playbook block files and once in each of the four agent files (`engineer.md:136`, `pm-spec.md:227`, `qa-verifier.md:152`, `tech-lead.md:157`). It comes from the single `Applies-to: all` entry at `.shell-team/lessons.md:1235`. The tech-lead map's "the tech-lead bullet that retires when issue #268 …" is therefore one of four renderings of one entry, not a separate bullet.
  - These files exist in the working tree: the reuse candidates `docs/loop-engineering/tier2-subject-harness.md`, `bin/gen-loop-replay.sh`, `bin/rollup-runs.sh`, `bin/rollup-track.sh` and `bin/derive-populations.sh`. Their contents were **not opened by this role**. What each does is relayed (Notes for engineer), and the engineer reads each before writing about it.
  - **Own-coinage tokens.** These are coined by this task, and the document does not exist before implementation, so every criterion that reads it is red:
    - the nine heading strings;
    - `- cost: ` with its four dimensions and the `derivation:` / `estimate:` tails;
    - `- not-a-criterion: age — `.
  - **Borrowed tokens.** `Superseded-by`, `Scope: maintainer`, `Applies-to: all`, `claim-1`, `signal-1` and `#268` are borrowed vocabulary. No criterion asserts a count premise about them at the base; they are only required present in the new document.
- **Relayed, not measurable by this role** (owner: the coordinating session):
  - the issue #782 body (quoted in Summarized sources);
  - the sprint name "context-trim", the release PATCH v2.9.7, and this being the sprint's last backlog item;
  - the stack: T-1198, PR #783, open, with branch point `59e16830`;
  - the operator rulings behind the no-local-past-spec-run disclosure and the dev-scaffold review depth;
  - whether `.shell-team/runs/shell-team.jsonl` carries per-dispatch tokens or durations. The engineer measures this before relying on it.
- **Freeze-run duties** (owner: the coordinating session). A false prediction routes back here as a broken check line, never as a pass.
  - **The base.** Run the discriminator expression and confirm that `B` resolves to `59e16830…` (the T-1198 tip). Record the value beside this line. Also confirm that the expression is byte-identical at its three sites: the `- base-ref-discriminator:` declaration, **AC4** and **AC7**.
  - **The #268 count.** Run `git grep -c -F 'retires when script-generated record tables (issue #268)' -- 'agents/*.md' 'templates/prompt-blocks/playbook-*.md'`. Expect eight files at one occurrence each, and record the output beside this line.
  - **Before implementation.**
    - **AC1**, **AC2**, **AC3**, **AC5**, **AC8** and **AC10** exit non-zero on their first `test -s` of the document.
    - **AC7** is red on its positive control.
    - **AC4** is green: the protected paths are unchanged.
    - **AC6** is green when the board entry is conformant.
    - **AC9** is `SKIP`.
  - **Specimen and mutation probes.** Before implementation every reading criterion stops at its opener, which cannot tell a broken command from a missing document. So, in a scratch clone under `$TMPDIR` (`git clone --shared`), write a throwaway document that carries:
    - the nine headings;
    - one conforming cost line per dimension;
    - the marker line;
    - the strings **AC5** and **AC8** require in their sections;
    - the six candidate paths **AC10** requires.

    Run **AC1**–**AC3**, **AC5**, **AC8** and **AC10** there and expect green. Then apply mutations, each expected red:
    - duplicate a heading (**AC2**);
    - strip a cost line's tail, and drop one dimension (**AC3**);
    - drop the marker (**AC5**);
    - move `Scope: maintainer` out of its section (**AC8**).

    Record the results on the board before the freeze. These are the mutation probes the `no-mechanism` class requires for the check lines this task adds.
  - **Em dash.** The em dash in **AC3**, **AC5** and D2 is the U+2014 bytes the document uses.

## Open questions

None blocking.

## Notes for engineer

- **Reuse candidates (relayed descriptions; read each before you describe it).**
  - `docs/loop-engineering/tier2-subject-harness.md`: a committed fixed subject with a measured serial baseline. It is the nearest existing fixed task set for a with/without comparison.
  - `bin/gen-loop-replay.sh`, `bin/rollup-runs.sh` and `bin/rollup-track.sh`: telemetry replay and rollups.
  - `bin/derive-populations.sh`: set and population derivation.
  - `.shell-team/runs/shell-team.jsonl`: check whether it carries per-dispatch token counts or durations before you use it as a cost source.

  Evaluation depth is the droppable component. A one-line "not evaluated: <reason>" is acceptable where a candidate does not fit.
- **Cost lines.** Every figure under `## Cost of one measurement` goes on a `- cost: ` line ending in `— derivation: <command>` or `— estimate: <basis>`. Elsewhere, a count you state goes through a `bin/derive-populations.sh` block with its `- reproduce:` line, or is labelled as an estimate where it appears. The inventory's word counts use a Unicode-aware split about 2 percent above `LC_ALL=C wc -w`. If you quote a word count, say which method produced it.
- **Grammar hygiene.**
  - Only real cost lines may start a line with `- cost: `.
  - Only the one marker may start a line with `- not-a-criterion: `.
  - If the document explains its own grammar, put the examples mid-sentence in backticks.
- **Literal strings AC8 needs.** Write `Applies-to: all` and `Scope: maintainer` as contiguous text in their sections. A backtick-wrapped `` `Applies-to: all` `` is fine; a split such as `` `Applies-to`: `all` `` is not.
- **Line endings.** Commit the document with LF.
- **The unit question.** One lessons entry with `Applies-to: all` renders as one bullet in each of the four blocks, for example the issue #268 entry at `.shell-team/lessons.md:1235`. Say whether the measured unit is the entry or the rendered bullet, and what a per-role result means for an entry shared by several roles.
- **Removal path.** Describe the `Superseded-by` gap and the `Scope: maintainer` lever. Do not propose a schema change as part of this task. You may name it as a future option, stated as such.
- **Deferral record.** Measuring the effect of each bullet is not a third retirement-stock sweep and not a block-size verdict. If the design would, once run, observe dilution, say how that relates to signal-1 without claiming that it has fired.
- **No private context.** Use no adopter, operator or workstation names, and no host-local paths or tool names. **AC1** runs the PII-shape checker on the document.
- **Measured-at-ref command check.** Not applicable: the deliverable prints no command labelled as measured at a git ref. If you add one, it must read that ref's committed blob.
- **Review depth.** Note depth (Verdict scope).
