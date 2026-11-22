# Machinery inventory: which parts of the loop still earn their keep

## Purpose and scope

This document inventories the machinery of the loop so that later planning can decide removals and simplifications from evidence rather than from age or impression. For each item it records what the item does, the failure it was added to prevent, whether that failure can still be reproduced, a verdict, and what the host would stop paying if the item went. It covers four groups: agent definitions with the prompt blocks generated into them, skills, `bin/` scripts with the CI steps that run them, and the review shapes (the Codex passes the loop defines). Nothing is removed, simplified or changed by this document.

`templates/prompt-blocks/registry.txt` is not an item. It is configuration, not a mechanism: it states which consumer files must carry which canonical block, and it is read by two scripts, `bin/check-prompt-sync.sh` and `bin/gen-playbook-blocks.sh`. The blocks it governs each have a row of their own.

## How to read a row

Each item is a heading line of the form `### item: <id>` followed by five field lines.

- The id is the item's repository path, a skill's directory (`skills/<name>`), `ci:` followed by the exact CI step name, or `shape:` followed by a shape name.
- The five fields are `does`, `prevents` (the failure, then `provenance:`), `reproducible`, `verdict` and `host-cost`.
- A provenance cell holds one locator: a `<path>:<line>` where a marker or a stated reason sits, an issue number, or a lessons entry as `lessons: <date> — <heading>`. `not found` means no line in the repository states the reason; it is not a claim that no reason exists.
- A `reproducible` cell starts `measured:` only where a fixture or record in this repository demonstrates the failure shape. Everything else is `unmeasured:` with the reason. No model was run for this inventory.
- A verdict is one of keep, simplify, candidate for removal, unknown. A simplify or removal verdict must end with an evidence locator; a verdict that cannot cite evidence is keep (with the protective reason) or unknown.
- Line counts in host-cost cells are `wc -l` of the file; word counts are whitespace-separated tokens under a Unicode-aware split, not `LC_ALL=C wc -w`; on the four playbook files the split runs about 2 percent above `wc -w`.
- Optional lines: one generated-block line per prompt block an agent file carries (marker mode), one CI-step line per workflow step attached to a `bin/` row, and free notes.

## Verdict scope

The consumer of this document is the operator and the planning that follows it; it is an internal analysis note that no adopter executes and no gate reads. Its check lines prove presence and form (every item has a row, every row has five fields, every simplify or removal verdict carries something shaped like a locator). They do not prove that a verdict is right, that a locator resolves, or that a `measured:` cell measured what it says. Every provenance locator and every evidence citation behind a non-keep verdict was re-opened at its source when this document was written; a locator that did not resolve is written `not found`. The reader should treat verdicts as proposals: follow-up issues are filed only after review, one per approved removal or simplification.

## Platform fact

Subagents shipped inside a plugin do not support the `hooks`, `mcpServers` or `permissionMode` frontmatter fields, so any per-role protection (a tool restriction enforced by a hook, a role-scoped server, a permission mode) has to live somewhere other than a plugin agent's frontmatter. The source is the Claude Code subagent documentation, https://code.claude.com/docs/en/sub-agents. The coordinating session confirmed on 2026-11-22 that the page states that plugin subagents do not support these fields; its frontmatter table also marks `initialPrompt` as ignored for them. The same fact is stated in issue #754.

## Summary of findings

The verdict counts per group are derived, not typed: the six derivation blocks in the appendix at the end of this document each carry the command that regenerates them, and their set lines are the counts. The findings below are prose over those blocks and the rows.

- **One row is a simplify candidate, and no row is a removal candidate.** The simplify row is `skills/run`: its Review step repeats a paragraph its Validate step already carries (the row names both lines and the evidence locator). The simplify and candidate sets in the appendix blocks are the derived record of this. Nine CI lint steps (the `shellcheck (T-1151 additions)` family and two lint steps named for T-1177 and T-1178) were first marked simplify by the readers. Re-measured at the workflow, none of the paths they lint appears in the main `shellcheck` step (`.github/workflows/check-handoff.yml:29`), so each step is the only lint of its files and the evidence for a simplify verdict does not hold; those rows are keep. What remains is a pattern, noted in each row: lint paths are added as one extra step per task instead of a list edit, which is a structural tidy-up, not a saving of lint work.
- **The largest host-cost levers sit in the prompts, and their live value is unmeasured.** The four generated playbook blocks are loaded in full each time their role is dispatched. Their size, by the command beside it:

```
$ LC_ALL=C wc -l templates/prompt-blocks/playbook-*.md
    88 templates/prompt-blocks/playbook-engineer.md
   108 templates/prompt-blocks/playbook-pm-spec.md
    76 templates/prompt-blocks/playbook-qa-verifier.md
    53 templates/prompt-blocks/playbook-tech-lead.md
   325 total
```

  The three largest single prompts, by the command beside them:

```
$ LC_ALL=C wc -l agents/pm-spec.md agents/code-reviewer.md skills/run/SKILL.md
   277 agents/pm-spec.md
   301 agents/code-reviewer.md
   349 skills/run/SKILL.md
   927 total
```

  The four playbook blocks are verdict unknown rather than keep because no per-bullet evidence was gathered that a failure class no longer occurs. `skills/run` is the simplify row above; its steps other than the duplicated paragraph carry no per-step evidence, and the row says they should be priced step by step. One bullet in the engineer playbook states its own retirement condition (`agents/engineer.md:136`).
- **The adversarial and evidence shapes are one Codex invocation.** Both rows describe the perspectives-file pass: its raw capture is the adversarial one and its answer is the evidence ledger. Removing or simplifying one of them cannot be priced apart from the other; the extra cost is an additional Codex pass on each approving round, bounded by the await rule stated in the review-shapes section.
- **The unknown rows have four different reasons; none is a single shared one.** The ids are the unknown buckets of the appendix blocks.
  - Per-bullet value unmeasured: the four playbook blocks.
  - Use frequency of an optional or conditional pass is not recorded: the drift-evaluator role and its shape, the spec-review shape, the alternate-executor invocation block, and the adversarial shape (which also cannot be priced apart from the evidence shape).
  - Callers limited to triage, on-demand use or documentation, so no consumer is shown: the liveness classifier (invoked by a timer this repository does not ship), the triage-only scripts (cluster-failures, consolidate-proposals, rollup-runs), rollup-track, gen-loop-replay and the installer.
  - Duplicated text with no decision on it: the goal skill, which repeats the run skill's escalation paragraphs; whether the goal path is used in current runs was not measured.
  A telemetry count of invocations per item would settle most of the second and third groups; none was taken, because this inventory stages no model run and reads no live telemetry.
- **Failure reproducibility is almost entirely unmeasured.** Exactly one row carries a `measured:` cell (the errexit-safe suite), by the command beside it:

```
$ grep -c '^- reproducible: measured' docs/loop-engineering/machinery-inventory.md
1
```

  Read that as a statement about the evidence this repository holds, not as a statement that the other failure classes are gone.


## Agents

Nine role files. Each row lists the generated prompt blocks the file carries in marker mode; blocks a file carries only in contain mode (verbatim lines, no marker) are named in the host-cost cell.

### item: agents/code-reviewer.md
- does: Cross-provider reviewer: drives the Codex CLI through primary, adversarial and evidence passes, plus spec-review and finding-evaluation modes, and returns an APPROVE or REQUEST_CHANGES verdict block.
- prevents: Same-family reviewers share blind spots, so the final review goes to a different model family — provenance: agents/code-reviewer.md:23
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — it is one of the two gates that define done (QA plus cross-provider review); the review shapes it carries are inventoried separately as shape rows.
- generated-block: record-portability
- generated-block: record-shape-scan
- host-cost: about 301 lines / 13677 words of agent prompt loaded each time the role is dispatched; roughly 13 of those lines are generated block regions; also carries contain-mode core lines of: derived-populations, language-code-reviewer, operating-paths-core

### item: agents/drift-evaluator.md
- does: Optional post-APPROVE pass that runs a Codex semantic check of the frozen intent block and decision provenance against the delivered diff and returns a four-value advisory verdict.
- prevents: Nobody otherwise asks, in a machine-grounded way, whether a delivered diff still means what the frozen intent said (machine-level cognitive surrender) — provenance: agents/drift-evaluator.md:14
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: unknown — it is an optional pass; how often a run invokes it, and whether it ever changed an outcome, is not recorded in the files read.
- host-cost: about 164 lines / 5053 words of agent prompt loaded each time the role is dispatched

### item: agents/engineer.md
- does: Implementation role: implements the spec, runs tests, commits implementation before flipping READY_FOR_QA, and writes a hand-off with decision provenance and counted claims carrying their own commands.
- prevents: An uncommitted implementation diff exposed at the engineer-to-QA hand-off, plus unverified counts and recall-written claims — provenance: agents/engineer.md:54
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — the only role that writes production code; its rules each cite a task or lesson, and the generated regions are held byte-identical by the sync checker.
- generated-block: careful-execution
- generated-block: playbook-engineer
- generated-block: record-portability
- generated-block: record-shape-scan
- generated-block: language
- host-cost: about 191 lines / 11758 words of agent prompt loaded each time the role is dispatched; roughly 110 of those lines are generated block regions; also carries contain-mode core lines of: derived-populations, flag-enum, operating-paths-core, record-mode

### item: agents/pm-spec.md
- does: Spec author: turns a request into a spec with acceptance criteria, an intent block, check lines and the board entry, and carries the freeze, conformance-formatter and spec-review hand-off duties.
- prevents: Ambiguous specs, acceptance criteria without a mechanism, and malformed check lines (a spec that hit the backtick-wrapped check failure) — provenance: agents/pm-spec.md:67
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — the largest prompt, but every rule cites a task or issue; trimming would need per-rule evidence not gathered here.
- generated-block: playbook-pm-spec
- generated-block: record-portability
- generated-block: language
- host-cost: about 277 lines / 20186 words of agent prompt loaded each time the role is dispatched; roughly 116 of those lines are generated block regions; also carries contain-mode core lines of: adopter-docs-declaration, board-line-format, derived-populations, flag-enum, record-mode

### item: agents/qa-verifier.md
- does: Verification role: runs the suite and each acceptance criterion's check, audits runtime criteria item by item, and returns a PASS or FAIL verdict that moves the board flag.
- prevents: PASS declared on the engineer's self-reported success, and verification that destroys the working tree — provenance: agents/qa-verifier.md:59
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — it is the first of the two gates that define done.
- generated-block: careful-execution
- generated-block: playbook-qa-verifier
- generated-block: record-portability
- generated-block: record-shape-scan
- generated-block: language
- host-cost: about 207 lines / 12468 words of agent prompt loaded each time the role is dispatched; roughly 98 of those lines are generated block regions; also carries contain-mode core lines of: derived-populations, flag-enum, operating-paths-core, record-mode, verdict-labels

### item: agents/scrum-master.md
- does: Retro generator: reads merged PRs, review records, lessons, telemetry and intervention records and writes one Keep / Problem / Try retro file with labelled lesson candidates.
- prevents: End-of-cycle reflection is skipped when no agent owns it, leaving lesson candidates buried in review comments — provenance: agents/scrum-master.md:21
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — manual-trigger only, so it costs nothing in a run that does not call it; the retro checker and retro-input blocks depend on its output shape.
- generated-block: record-portability
- generated-block: record-shape-scan
- host-cost: about 145 lines / 5490 words of agent prompt loaded each time the role is dispatched; roughly 13 of those lines are generated block regions; also carries contain-mode core lines of: flag-enum, language, operating-paths-core, retro-inputs, retro-sections

### item: agents/tech-lead.md
- does: Planner: reads the request and returns a Routing Map naming which role handles each step and the per-axis dispatch decisions; never writes files.
- prevents: Unplanned multi-role work with no recorded dispatch choice per axis — provenance: agents/tech-lead.md:89
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — read-only planner whose Routing Map is the source for the board's dispatch rows.
- generated-block: careful-execution
- generated-block: playbook-tech-lead
- generated-block: record-portability
- generated-block: language
- host-cost: about 192 lines / 8020 words of agent prompt loaded each time the role is dispatched; roughly 67 of those lines are generated block regions; also carries contain-mode core lines of: derived-populations, dispatch-record, flag-enum, record-mode

### item: agents/triage-orchestrator.md
- does: Outer-loop triage: consolidates discovery, telemetry roll-up and failure clusters into one de-duplicated, budget-capped proposal file; propose-only, never edits the board.
- prevents: Three separate outer-loop signals (open work, run health, recurring failures) with no single proposal for a human to act on — provenance: agents/triage-orchestrator.md:18
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — manual-trigger only and propose-only, so it costs nothing in a run that does not call it.
- host-cost: about 82 lines / 1454 words of agent prompt loaded each time the role is dispatched; also carries contain-mode core lines of: flag-enum, language-triage-orchestrator, operating-paths-core

### item: agents/ui-designer.md
- does: Conditional design role: for UI-touching tasks only, commits to one aesthetic direction (via the frontend-design skill when present) and hands a design note to the engineer.
- prevents: UI work implemented with generic defaults rather than an intentional design — provenance: agents/ui-designer.md:9
- reproducible: unmeasured: no fixture reproduces the absence of this role's prose; the prompt-sync suite checks only that generated regions match their canonical blocks, not that the role behaves differently without them
- verdict: keep — participates only when tech-lead routes UI work, so non-UI runs never load it.
- host-cost: about 141 lines / 1282 words of agent prompt loaded each time the role is dispatched; also carries contain-mode core lines of: flag-enum, language, operating-paths-core

## Prompt blocks

One row per canonical block file under `templates/prompt-blocks/`. The four playbook blocks are generated from the lessons corpus; the others are written by hand and copied into their consumers.

### item: templates/prompt-blocks/adopter-docs-declaration.md
- does: Canonical declaration grammar for a spec's user-visible line and its adopter-docs surface, waiver or shipped-docs lines.
- prevents: A user-visible capability frozen with no adopter-facing documentation disposition — provenance: lessons: 2026-08-11 — A spec for a user-visible capability carries an adopter-facing-documentation acceptance criterion as a freeze-time blocker
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — read by bin/check-adopter-docs.sh as its declaration grammar and held verbatim in two consumers.
- host-cost: 4 lines / 113 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/alternate-executor-invocation.md
- does: Recipe, admissibility gate and briefing template for dispatching a bound role through the Codex CLI instead of in-process (tech-lead under codex-cli is the only wired role).
- prevents: Each phase inventing its own argv and capture for an alternate executor, with no read-scope or write-authority check — provenance: templates/prompt-blocks/alternate-executor-invocation.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: unknown — its own text says it wires exactly one role under one adapter; how often that path fires is unmeasured in the files read.
- host-cost: 46 lines / 2083 words in the block, copied into 1 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/board-line-format.md
- does: Two-line fragment of the board entry format that check-handoff.sh lints.
- prevents: A note wedged between the status flag and the spec link, breaking the strict board line — provenance: lessons: 2026-06-17 — The board's `- [ ]` lines follow check-handoff's strict format; don't wedge a note between the flag and `— spec:`
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — held verbatim in three consumers including the checker.
- host-cost: 2 lines / 7 words in the block, copied into 3 consumer file(s) (contain mode)

### item: templates/prompt-blocks/careful-execution.md
- does: Four-bullet working discipline: verifiable seams, evidence before completion claims, classify each result as progress/stalled/regressed, make uncertainty explicit.
- prevents: Completion claims without observed evidence and repeated stalled approaches — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — short and generated into three roles; no evidence of non-use.
- host-cost: 6 lines / 177 words in the block, copied into 3 consumer file(s) (marker mode)

### item: templates/prompt-blocks/convergence-escalation.md
- does: Requires the STOP escalation to carry the rework digest's convergence verdict and its three grounds.
- prevents: A max-iterations STOP that reported only the bare iteration count — provenance: templates/prompt-blocks/convergence-escalation.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — one line, consumed by two skills, backed by bin/rework-digest.sh.
- host-cost: 1 lines / 211 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run

### item: templates/prompt-blocks/derived-populations.md
- does: Population totals, set deltas and bucket splits in a record come from bin/derive-populations.sh with an embedded block and a reproduce line.
- prevents: Hand-counted whole-set claims that recur until the inventory itself is command-derived — provenance: lessons: 2026-08-16 — Mechanizing the count does not mechanize the enumeration: whole-set claims recur until the claim inventory itself is command-derived
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — four lines, held in five role prompts, and it is the mechanism this inventory's own completeness check uses.
- host-cost: 4 lines / 112 words in the block, copied into 5 consumer file(s) (contain mode)

### item: templates/prompt-blocks/dispatch-record.md
- does: Grammar and rules for the per-axis dispatch decision (who decides, who records, closed value sets, reflection rows).
- prevents: Dispatch choices left implicit with no recorded price or axis value — provenance: templates/prompt-blocks/dispatch-record.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — validated at close-out by bin/close-out.sh per its own validation bullet; consumed by tech-lead and the run skill.
- host-cost: 15 lines / 881 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/executor-resolution.md
- does: Requires resolving each bound role's executor before invoking it and treating every refusal as a blocker.
- prevents: Invoking a bound role without resolving its executor, or substituting another executor on refusal — provenance: templates/prompt-blocks/alternate-executor-invocation.md:46
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — one line held in four skills; the cited line calls it the discipline the admissibility gate copies.
- host-cost: 1 lines / 319 words in the block, copied into 4 consumer file(s) (contain mode); also loaded each time the goal/review/review-response/run skill(s) run

### item: templates/prompt-blocks/fanout-orchestration.md
- does: Protocol for within-phase fan-out across N instances: population file, one output per instance, degree rule, launch record, aggregation and seven locked invariants.
- prevents: Serial verification of mechanically enumerable populations, and unattributable or partial fan-out results — provenance: templates/prompt-blocks/fanout-orchestration.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — backed by bin/aggregate-verdicts.sh and bin/check-fanout-instances.sh, which refuse partial results.
- host-cost: 22 lines / 1280 words in the block, copied into 1 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/flag-enum.md
- does: The seven board status flags as invariant tokens.
- prevents: Flag spelling drift between the board, the checker and the prompts — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — an invariant-token list checked in contain mode in eleven consumers including check-handoff.sh.
- host-cost: 7 lines / 7 words in the block, copied into 11 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/host-dispatch.md
- does: Describes dispatching roles from either a Claude Code host or a Codex CLI host, including waiting rules, the review step on the Codex host and local-mode commit rules.
- prevents: Role dispatch on the second host being improvised, and a Codex-host review that would not be cross-provider — provenance: templates/prompt-blocks/host-dispatch.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — the only place the Codex-host dispatch rules live; loaded by the run skill.
- host-cost: 34 lines / 2771 words in the block, copied into 1 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/interventions-classes.md
- does: Canonical seven-class intervention enum, entry template and append rules for interventions files.
- prevents: Human interrupts and corrections going unindexed so a retro cannot classify them — provenance: agents/scrum-master.md:48
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — single canonical source for bin/check-interventions.sh.
- host-cost: 13 lines / 155 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the run skill(s) run

### item: templates/prompt-blocks/language.md
- does: Mirror-the-conversation language rule that keeps machine-parsed tokens verbatim in English.
- prevents: Translated status flags and verdict labels that the checkers grep — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — marker-mode generated into four role prompts and contained in two more.
- host-cost: 3 lines / 91 words in the block, copied into 6 consumer file(s) (contain/marker mode)

### item: templates/prompt-blocks/language-code-reviewer.md
- does: Registered variant of the language rule specific to code-reviewer's verdict block and Codex prompt.
- prevents: Prose language drift in the verdict block and in the prompt handed to Codex — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — registry.txt names it as an explicitly allowed variant of language.md.
- host-cost: 1 lines / 144 words in the block, copied into 1 consumer file(s) (contain mode)

### item: templates/prompt-blocks/language-triage-orchestrator.md
- does: Registered variant of the language rule for triage-orchestrator, naming its candidate-line and source-key tokens.
- prevents: Translation of machine-parsed triage tokens — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — registry.txt names it as an explicitly allowed variant.
- host-cost: 3 lines / 102 words in the block, copied into 1 consumer file(s) (contain mode)

### item: templates/prompt-blocks/liveness-declaration.md
- does: Requires writing and removing a human-gate declaration file at every point a skill waits on a human.
- prevents: A wait on a human that no liveness check can distinguish from a stall — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — one line consumed by two skills and read by bin/check-liveness.sh.
- host-cost: 1 lines / 205 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run

### item: templates/prompt-blocks/means-ends-reflection.md
- does: Four-question reflection at three firing points and the rule for executing a pre-priced disposition versus escalating.
- prevents: Escalating to the operator for a decision already priced at freeze, or executing one without checking the never-dropped set — provenance: docs/loop-engineering/means-ends-reflection.md:52
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — read by bin/rework-digest.sh and referenced from workflow docs.
- host-cost: 4 lines / 304 words in the block, copied into 2 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run; skills/run/SKILL.md carries this paragraph twice (lines 108 and 131) although the registry requires one copy, so one extra copy of about 310 words is loaded on every run

### item: templates/prompt-blocks/operating-paths-core.md
- does: One-sentence core of the operating-paths note: scripts run as bash "<plugin root>/bin/<script>", never assumed on PATH.
- prevents: Scripts called by bare name that fail when the plugin's bin is not on PATH — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — a single line held in eight consumers.
- host-cost: 1 lines / 35 words in the block, copied into 8 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run

### item: templates/prompt-blocks/playbook-engineer.md
- does: Generated 'Lessons playbook' region for the engineer role, one bullet per promoted lesson with a lessons.md citation.
- prevents: The failures named by the lessons it carries (summarized: review-gate regressions, synchronous Codex review, PII in scrub documents, uncommitted-spec worktrees, quantitative-conclusion QA, hand-off counts and others) — provenance: lessons: 2026-06-12 — Review gate caught a regression in practice (cross-provider review vindicated)
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: unknown — the live value of each lesson bullet is not separately measured; it is the largest single block per engineer dispatch, and one bullet states its own retirement condition (agents/engineer.md:136).
- host-cost: 88 lines / 8997 words in the block, copied into 1 consumer file(s) (marker mode); loaded in full on every dispatch of its role

### item: templates/prompt-blocks/playbook-pm-spec.md
- does: Generated 'Lessons playbook' region for the pm-spec role.
- prevents: The failures named by the lessons it carries (summarized: check-line shape, spec mechanism criteria, freeze sweeps, summarized sources, completeness claims and others) — provenance: lessons: 2026-07-12 — Cross-cutting-discipline ACs must specify the mechanism, not just the outcome
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: unknown — per-bullet live value is not separately measured; it is the largest block in the largest prompt.
- host-cost: 108 lines / 10785 words in the block, copied into 1 consumer file(s) (marker mode); loaded in full on every dispatch of its role

### item: templates/prompt-blocks/playbook-qa-verifier.md
- does: Generated 'Lessons playbook' region for the qa-verifier role.
- prevents: The failures named by the lessons it carries (summarized: no PASS on self-report, per-site verification depth, hand-off recounts, fixture preconditions, runbook branch disclosure and others) — provenance: lessons: 2026-07-14 — QA on a same-class bulk fix should disclose verification depth per site, not one blanket claim
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: unknown — per-bullet live value is not separately measured.
- host-cost: 76 lines / 7837 words in the block, copied into 1 consumer file(s) (marker mode); loaded in full on every dispatch of its role

### item: templates/prompt-blocks/playbook-tech-lead.md
- does: Generated 'Lessons playbook' region for the tech-lead role.
- prevents: The failures named by the lessons it carries (summarized: Codex as reviewer, isolated-worktree and uncommitted-spec, board edits, dispatch discipline and others) — provenance: lessons: 2026-04-29 — Bootstrap
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: unknown — per-bullet live value is not separately measured.
- host-cost: 53 lines / 5395 words in the block, copied into 1 consumer file(s) (marker mode); loaded in full on every dispatch of its role

### item: templates/prompt-blocks/record-mode.md
- does: Defines the shell-team.mode git-config record mode and what local mode never stages or commits.
- prevents: Record files committed or force-added in a clone that keeps its base dir out of git — provenance: agents/engineer.md:60
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — held in four roles and two skills; the mode rule is read by bin/team-mode.sh.
- host-cost: 3 lines / 107 words in the block, copied into 6 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run

### item: templates/prompt-blocks/record-portability.md
- does: Requires naming outside projects, trackers, people and machines by role rather than by name in any committed record.
- prevents: A committed record carrying an identifying name that does not travel to another repository — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — marker-mode generated into six role prompts; it is an authoring-time rule only, with no detector (the block says so).
- host-cost: 5 lines / 188 words in the block, copied into 6 consumer file(s) (marker mode)

### item: templates/prompt-blocks/record-shape-scan.md
- does: Requires running the PII shape checker on the records a role wrote this round and quoting the one-line summary in the hand-off.
- prevents: A record with a flagged shape handed on unscanned — provenance: templates/prompt-blocks/record-shape-scan.md:4
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — marker-mode in four roles; the scan itself is bin/check-pii-shapes.sh.
- host-cost: 8 lines / 561 words in the block, copied into 4 consumer file(s) (marker mode)

### item: templates/prompt-blocks/retro-inputs.md
- does: Canonical retro input ids and status values (read, empty, unavailable).
- prevents: A retro reporting an input as empty when it could not be consulted — provenance: bin/retro-inputs.sh:31
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — single source for bin/retro-inputs.sh and bin/check-retro.sh.
- host-cost: 13 lines / 60 words in the block, copied into 4 consumer file(s) (contain mode)

### item: templates/prompt-blocks/retro-sections.md
- does: Canonical retro section markers in order.
- prevents: Retro structure checked by matching natural-language headings — provenance: bin/check-retro.sh:8
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — single source for bin/check-retro.sh.
- host-cost: 6 lines / 22 words in the block, copied into 3 consumer file(s) (contain mode)

### item: templates/prompt-blocks/telemetry-binding.md
- does: After each bound role call, passes the resolved row's provider, effort and adapter to log-run.sh, and records a refusal as a gate event instead of a span.
- prevents: Spans recording a call that did not happen, and telemetry missing the executor that ran — provenance: templates/prompt-blocks/telemetry-binding.md:1
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — one long line held in three skills.
- host-cost: 1 lines / 136 words in the block, copied into 3 consumer file(s) (contain mode); also loaded each time the goal/review-response/run skill(s) run

### item: templates/prompt-blocks/verdict-labels.md
- does: The four verdict labels PASS, FAIL, APPROVE, REQUEST_CHANGES as invariant tokens.
- prevents: Verdict label drift between prompts and the scripts that grep them — provenance: not found
- reproducible: unmeasured: no fixture in the files read demonstrates the failure shape this block prevents
- verdict: keep — invariant-token list held in five consumers including log-run.sh.
- host-cost: 4 lines / 4 words in the block, copied into 5 consumer file(s) (contain mode); also loaded each time the goal/run skill(s) run

## Skills

Seven skill directories, each holding one `SKILL.md`. A free note in a skill row prices its steps one by one where the skill is long.

### item: skills/run
- does: Orchestrates the full loop (Plan, Specify, Design when UI, Implement, Validate, Review, Done) on either host, with Step 0 path/probe/setup-check/record-mode resolution, seam gates, loop-guard retries, telemetry rows, executor resolution and the Codex-host recipes.
- prevents: Skipped phases and unguarded hand-offs between roles (every seam has a gate: durability barrier, provenance, interventions, frozen-intent confirmation, spec-review, evidence-ledger and downgrade-ground checks); unbounded rework (loop-guard plus same-class-2 and means-ends rules); a review or resolution step that silently substitutes another executor; unrecorded human interrupts — provenance: skills/run/SKILL.md:96
- reproducible: unmeasured: the skill is an orchestration prompt; runtime behaviour is exercised by dogfood runs, and no repo fixture replays a model skipping a seam. The checkers it calls have their own suites under tests/, which test the scripts and not the skill's instruction-following.
- verdict: simplify — the Review step (skills/run/SKILL.md:131) repeats the 'Means-ends reflection and disposition rule (T-1095)' paragraph that the Validate step already carries at skills/run/SKILL.md:108: the first 310 words (the length of line 108 by `wc -w`) are the same text, and line 131 then adds an authorship-class sentence of about 60 words; the registry rule for that block (`templates/prompt-blocks/registry.txt:54`) is `contain` with one copy per consumer, and neither line sits inside a prompt-block marker, so the second copy is not required by the registry. Beyond that duplicate the skill is a long accretion of per-task seam gates with no per-step evidence gathered, so its other steps stay unpriced and should be priced step by step, not as a whole — evidence: skills/run/SKILL.md:131
- host-cost: loaded on every /shell-team:run, about 349 lines and 25,000 words (175 KB, with very long lines) of orchestrator context per run; each seam gate adds a Bash call and a wait; four standing steps run before any role dispatches (path resolve, ignore probe, setup check, record-mode read).
- steps (what each exists to prevent): Step 0 resolve/probe/setup-check/record-mode — prevents running against an unscaffolded, mis-ignored or ambiguous-mode repo (skills/run/SKILL.md:22; skills/run/SKILL.md:28). Interventions discipline — prevents the host's interrupts and corrections going unrecorded (skills/run/SKILL.md:42). 1 Plan (tech-lead Routing Map, dispatch record) — prevents ad hoc role routing (skills/run/SKILL.md:58). 2 Specify plus freeze gates (frozen-intent, adopter-docs, spec-review, oversight, version derivation) — prevents implementing against an unfrozen or unratified spec (skills/run/SKILL.md:67; skills/run/SKILL.md:70; skills/run/SKILL.md:72; skills/run/SKILL.md:73). 3 Design (UI only) — prevents the engineer inferring UI intent from a missing note. 4 Implement plus commit/durability/provenance/interventions gates — prevents QA running over uncommitted or unrecorded work (skills/run/SKILL.md:91; skills/run/SKILL.md:95; skills/run/SKILL.md:96). 5 Validate plus loop-guard, same-class-2, rework digest — prevents endless identical retries (skills/run/SKILL.md:99). 6 Review plus binding pre-dispatch, evidence-ledger gate, downgrade-ground check — prevents an unverified APPROVE reaching READY_FOR_MERGE and a defect being lowered on its own frozen status (skills/run/SKILL.md:119; skills/run/SKILL.md:120; skills/run/SKILL.md:121). 7 Done — the human gate before merge stays with the operator. Telemetry rows, human-gate declaration and executor resolution — prevent unobservable runs and a role running on an unresolved executor (skills/run/SKILL.md:194; skills/run/SKILL.md:196). Codex-host and alternate-executor recipes (skills/run/SKILL.md:198 onward) — prevent re-deriving the host dispatch each run. The fan-out and concurrent-worktree sections (skills/run/SKILL.md:284; skills/run/SKILL.md:309) are opt-in and wired to no default phase.

### item: skills/goal
- does: Drives one task through repeated implement-and-verify ticks until a layered completion gate (check-acs, check-intent, check-provenance, qa-verifier, code-reviewer) is green, bounded by loop-guard (iteration, wall-clock, no-progress), then stops at the human gate.
- prevents: A self-verification loop that runs away or merges on its own; one verifier's PASS anchoring the next (gate layers run independently); cross-tick state lost between separate shell calls (state file via goal-state.sh) — provenance: skills/goal/SKILL.md:9
- reproducible: unmeasured: the skill itself states its tick cadence and end-to-end behaviour are dogfood-verified, not CI-tested (skills/goal/SKILL.md:292); only goal-state.sh and the contract lint have fixtures.
- verdict: unknown — it repeats the run skill's escalation and digest paragraphs (a second copy of the STOP, rework-digest, means-ends and ratifier text: skills/goal/SKILL.md:248 repeats the rework-history digest paragraph, :252 the extension ratifier and :254 the means-ends paragraph); whether the /goal path is used in current runs was not measured here.
- host-cost: loaded only when /goal is invoked; about 309 lines and 5,300 words (39 KB); each tick adds a loop-guard call, a state-file bump and a ScheduleWakeup.
- steps (what each exists to prevent): Step 0 path and contract resolve — prevents hardcoded layout (skills/goal/SKILL.md:12). First-tick state init and record mode — prevents lost cross-tick counters and an unread record mode (skills/goal/SKILL.md:46). 1 Implement attempt plus commit guard — prevents verifying uncommitted work (skills/goal/SKILL.md:53). 2 Layered completion gate — prevents false-positive PASS chaining (skills/goal/SKILL.md:60). 3 Bound gate (loop-guard) — prevents runaway loops (skills/goal/SKILL.md:113). 4 Decide (green stop, STOP reporting, early escalation, means-ends reflection) — prevents merging or pushing and unreflective escalations (skills/goal/SKILL.md:237; skills/goal/SKILL.md:254).

### item: skills/review-response
- does: Pulls review findings already left on a PR, has code-reviewer (Codex) evaluate each, classifies them auto, escalate or reject through the deterministic floor (bin/review-gate.sh) plus grey-zone judgment, pauses for the human on any escalate, then hands the adopted findings to run as one spec and writes a run record.
- prevents: Auto-adopting a risky finding, adopting findings on a Claude-only judgment, and silently dropping change-request-equivalent comments posted as plain Comment reviews — provenance: skills/review-response/SKILL.md:7
- reproducible: unmeasured: the deterministic floor has its own fixture suite (tests/review-gate) but no fixture replays a mis-classified real finding; the Codex evaluation step has no repo-held failure record.
- verdict: keep — the conditional human pause is the stated reason the flow is a main-loop skill (skills/review-response/SKILL.md:7), and the floor is mechanical; no evidence found that its failure class is enforced elsewhere.
- host-cost: loaded only on explicit review-response invocation; about 126 lines and 2,500 words (17 KB); one Codex evaluation pass per invocation plus a conditional manual GO when any finding escalates.
- steps (what each exists to prevent): Step 0 path resolve and language mirror — prevents hardcoded paths and translated machine tokens (skills/review-response/SKILL.md:15). 1 Detect findings (CHANGES_REQUESTED and equivalents) — prevents dropping real asks left under a COMMENTED state (skills/review-response/SKILL.md:30). 2 Executor resolution, binding pre-check, Codex evaluation — prevents a same-family evaluation and gate inputs filled by guess (skills/review-response/SKILL.md:36; skills/review-response/SKILL.md:38; skills/review-response/SKILL.md:49). 3 Risk gate (floor, grey zone, conditional gate) — prevents auto-adopting objected, high-severity, risk-area or low-confidence findings (skills/review-response/SKILL.md:57; skills/review-response/SKILL.md:96). 4 Single hand-off to run — prevents per-finding pipelines and merging without the operator (skills/review-response/SKILL.md:105). Run record with the never-overwrite rule — prevents unauditable gate decisions (skills/review-response/SKILL.md:111; skills/review-response/SKILL.md:118).

### item: skills/review
- does: Runs the code-reviewer on the current branch against origin/main, after resolving the reviewer executor and passing the reviewer-binding pre-dispatch check, skipping PM, Engineer and QA.
- prevents: Dispatching a review to a refused or non-Codex reviewer binding, and substituting another executor when resolution refuses — provenance: skills/review/SKILL.md:5
- reproducible: unmeasured: no repo record of the failure; the provider checker has a suite (tests/check-review-provider) that tests the script, not this skill's instruction.
- verdict: keep — a 13-line wrapper whose only content is the executor-resolution and binding pre-dispatch gate; that gate text is also carried by run and review-response, so the duplication (not this skill) is the thing to price later.
- host-cost: about 13 lines and 510 words (3.6 KB) when invoked; the gate paragraph is long relative to the skill; one extra checker call before each review.

### item: skills/loop-triage
- does: Runs discover-work.sh read-only, writes the candidate proposals with a rationale per candidate to a dated run file under the runs dir, and never edits the board or acts on a candidate.
- prevents: Triage mutating the board or opening and closing issues, hand-built candidate lines drifting from the discovery engine's dedup, cap and sanitization, and an existing proposal file being overwritten — provenance: skills/loop-triage/SKILL.md:57
- reproducible: unmeasured: the discovery engine has its own tests; no repo record shows an agent mutating the board under this skill.
- verdict: keep — read-only and propose-only by design; no evidence of duplication found.
- host-cost: loaded only when triage is invoked; about 74 lines and 560 words (3.8 KB); one script run and one file written per invocation; the human copies a chosen candidate into the board by hand.
- steps (what each exists to prevent): Step 0 path resolve — prevents hardcoded layout. 1 Run discover-work.sh — prevents hand-built candidate lines (skills/loop-triage/SKILL.md:72). 2 Capture proposal with a collision suffix — prevents overwriting a prior proposal (skills/loop-triage/SKILL.md:53). 3 Never touch the board — prevents autonomous promotion (skills/loop-triage/SKILL.md:57). 4 Hand-off summary — prevents silent partial runs when gh is missing.

### item: skills/setup
- does: Runs bin/team-setup.sh from the repo root on either host and relays its five report sections verbatim, handling a refused write only as one exact operator-approved command and closing with what the operator must do.
- prevents: The agent changing trust, sandbox, permission or network settings, or hand-writing the scaffold, to get past a refusal, and a rewritten or dropped report line hiding an operator decision — provenance: skills/setup/SKILL.md:96
- reproducible: unmeasured: tests/setup covers the script's report and exit statuses; no repo record shows an agent widening a grant under this skill.
- verdict: keep — the boundary list is the point of the skill and the script is the single source of the scaffold; no evidence found that another item enforces the same boundary.
- host-cost: about 106 lines and 1,040 words (6.5 KB) when invoked; one script run; manual steps are the operator's own Required items.
- steps (what each exists to prevent): 1 Run the script from the repo root — prevents a mis-scoped scaffold. 2 Relay the report as printed — prevents dropped operator-decision lines (skills/setup/SKILL.md:33). 3 Handle each run-yourself line as one exact command — prevents wider grants (skills/setup/SKILL.md:40). 4 Read the exit status — prevents reading a refusal as success. 5 Close with the operator's asks and the Codex new-session rule — prevents an unselectable generated role (skills/setup/SKILL.md:74). Boundary list — prevents settings writes (skills/setup/SKILL.md:96; skills/setup/SKILL.md:104).

### item: skills/team-init
- does: Runs bin/team-init.sh against the current repo to scaffold the board, loop contract, runs, retros, reviews, specs, cross-tool pointer, test recipe and base-dir ignore file under one base dir, leaving host root files untouched, and reports what was created or skipped.
- prevents: Hand-created scaffold files drifting from the script, host-root CLAUDE.md or .gitignore being edited, and existing scaffold files being overwritten on re-run — provenance: skills/team-init/SKILL.md:77
- reproducible: unmeasured: tests/team-init exercises the scaffolder; no repo record shows an agent hand-creating the scaffold.
- verdict: keep — a thin wrapper whose rules mirror the setup skill's boundary; overlap with setup is noted but no evidence was found that either is redundant.
- host-cost: about 79 lines and 620 words (4.4 KB) when invoked; one script run; none on ordinary runs.

## bin checkers and scripts

One row per tracked `bin/` entry. A CI step that executes a script, directly or through a suite whose subject is that script, is attached to that script's row as a CI-step line. The attachment of a step that reaches two scripts is a judgment and follows the step's own name.

### item: bin/aggregate-verdicts.sh
- does: Reduces N per-instance fan-out part files into one authoritative verdict block, or refuses on a partial, duplicate-claim or malformed input.
- prevents: A fan-out of one phase's read-only checks across N instances promoting a partial or malformed result as if complete — provenance: bin/aggregate-verdicts.sh:3
- reproducible: unmeasured: the failure is a property of an unchecked reduction; no recorded fixture run was read for this row.
- verdict: keep — it is the only reduction step for the fan-out path and refuses rather than promotes; no replacement enforces the same property.
- host-cost: ~495 lines of bash, never loaded into a model prompt; run only when a fan-out is used (skills/run/SKILL.md, templates/prompt-blocks/fanout-orchestration.md); no manual step.
- ci-step: Run aggregate-verdicts fixture suite

### item: bin/check-acs.sh
- does: Runs the `check:` command under each scriptable acceptance criterion of a spec and reports PASS/FAIL/SKIP per criterion.
- prevents: QA accepting a spec's scriptable criteria by reading instead of executing them (an unverified "done") — provenance: bin/check-acs.sh:2
- reproducible: unmeasured: the failure is a process gap (criteria not run), not a model behaviour that a repo fixture reproduces.
- verdict: keep — it is the mechanical QA gate named by six agent files and the run skill; no other item executes the criteria.
- host-cost: ~427 lines of bash, not loaded into prompts; the agent files that name it carry a few lines each; wall-clock is the sum of the specs' check commands, run by QA (and by close-out paths).
- ci-step: Run check-acs fixture suite

### item: bin/check-adapter.sh
- does: Validates the task-envelope contract registry and each adapter definition under templates/adapters, refusing with one token on stderr.
- prevents: A malformed or contradictory executor-adapter contract being accepted silently — provenance: bin/check-adapter.sh:3
- reproducible: unmeasured: the checker guards shipped static files; no failure fixture was read for this row.
- verdict: keep — it is the sole validator of the envelope and adapter registry and is called by check-durability, check-invocation-path, resolve-executor and team-init.
- host-cost: ~750 lines of bash, not loaded into prompts; runs in CI and as a sub-check of the executor-resolution scripts; no manual step.
- ci-step: Run check-adapter fixture suite
- ci-step: Dogfood check-adapter — the shipped contract and definitions validate

### item: bin/check-adopter-docs.sh
- does: Reads one spec's frozen intent block and refuses unless a user-visible capability carries an adopter-docs surface or waiver, plus the shipped-docs inventory.
- prevents: A user-visible capability reaching READY_FOR_ARCH with no adopter-facing documentation criterion — provenance: bin/check-adopter-docs.sh:4
- reproducible: unmeasured: a spec-grammar gate; no recorded run was read for this row.
- verdict: keep — a freeze-time gate named by agents/pm-spec.md and the run skill that no other checker duplicates.
- host-cost: ~678 lines of bash, not loaded into prompts; one run per freeze; the declaration it enforces adds a few lines to each spec.
- ci-step: Run check-adopter-docs fixture suite
- ci-step: Dogfood check-adopter-docs — this task's own spec

### item: bin/check-binding.sh
- does: Validates the host-authored executor binding config (six role rows) and prints the canonical binding or a lock, or verifies a lock.
- prevents: A malformed or tampered role-to-executor binding being accepted, including a stale lock — provenance: bin/check-binding.sh:3
- reproducible: unmeasured: the checker guards a config file; no failure fixture was read for this row.
- verdict: keep — it is the only reader of the binding config and is composed by nine other scripts (resolve-executor, check-model-pins, check-oversight and others).
- host-cost: ~675 lines of bash, not loaded into prompts; invoked indirectly on each executor resolution and in CI; no manual step.
- ci-step: Run check-binding fixture suite
- ci-step: Dogfood check-binding — the shipped binding-config specimen validates

### item: bin/check-board-headings.sh
- does: Diffs the set of T-NNN heading ids on the board against a base ref and fails on deletion, replacement or duplication.
- prevents: An edit that inserts a board entry silently clobbering an existing task's heading while check-handoff still lints clean — provenance: bin/check-board-headings.sh:2
- reproducible: unmeasured: the two incidents it cites are historical; no fixture result was read for this row.
- verdict: keep — check-handoff checks line shape only and by design (bin/check-board-headings.sh:7-19) cannot see heading replacement; no other item covers it.
- host-cost: ~493 lines of bash, not loaded into prompts; runs in CI and from check-acs / check-binding paths; no manual step.
- ci-step: Run check-board-headings fixture suite
- ci-step: Dogfood check-board-headings — this repository's own board

### item: bin/check-codex-agents.sh
- does: Regenerates the Codex agent files into a scratch directory and compares them byte-for-byte with the checked-in out-dir, refusing on drift, missing or extra owned files.
- prevents: The generated Codex role files drifting from the agent sources they derive from — provenance: bin/check-codex-agents.sh:4
- reproducible: unmeasured: a generated-file drift gate; no recorded failure was read for this row.
- verdict: keep — it is the check-only sibling of gen-codex-agents.sh and the only freshness test of those outputs.
- host-cost: ~237 lines of bash, not loaded into prompts; runs in CI and from team-setup / the run skill; no manual step.

### item: bin/check-commit-identity.sh
- does: Rejects any non-merge commit in the PR range whose author or committer identity is not the noreply "+login" form (web-flow allowed for the committer).
- prevents: Commits carrying a personal or work email address into a public repository, which a content scan cannot see — provenance: bin/check-commit-identity.sh:2
- reproducible: unmeasured: depends on host git configuration; no recorded failure was read for this row.
- verdict: keep — identity metadata is outside every content scanner (check-pii-shapes.sh does not read it); the gate is the only control and rewriting history cannot remove the exposure.
- host-cost: ~173 lines of bash, not loaded into prompts; runs in CI per pull request; a failure costs the host a history rewrite.
- ci-step: Run check-commit-identity fixture suite
- ci-step: check-commit-identity on the PR commits

### item: bin/check-contract.sh
- does: Lints a loop-contract YAML for the eight contract elements and the required keys of budget, stop, owner and evidence.
- prevents: A loop contract missing its budget, stop, owner or evidence guardrails (runaway cost, unverified done) — provenance: bin/check-contract.sh:15
- reproducible: unmeasured: a schema lint; no recorded failure was read for this row.
- verdict: keep — sole validator of the contract template and the shipped contract file; small and CI-only.
- host-cost: ~174 lines of bash, not loaded into prompts; runs in CI only; no manual step.
- ci-step: Lint the shipped shell-team loop contract
- ci-step: Lint the shipped generic loop-contract template
- ci-step: Lint the shipped goal loop contract
- ci-step: Run check-contract fixture suite

### item: bin/check-count-claims.sh
- does: Verifies that every `- count:` row on the board carries a derivation command whose output equals the relayed value.
- prevents: A relayed quantity (a count in a spec or record) passed on without a command that reproduces it — provenance: bin/check-count-claims.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — a freeze/close-out gate called by check-review-input and close-out; the claim grammar it enforces has no second reader.
- host-cost: ~318 lines of bash, not loaded into prompts; runs in CI and at close-out; each count row adds one line to a record.
- ci-step: Run check-count-claims fixture suite

### item: bin/check-design-note.sh
- does: Validates a UI designer's design note has real content, both required bold-marker sections, and is not banner-only or a stale wrong-task note.
- prevents: An empty, placeholder or wrong-task design note passing a bare `test -s` as the design contract — provenance: not found
- reproducible: unmeasured: no failure record or fixture was read for this row.
- verdict: keep — named by agents/ui-designer.md and the run skill and called by check-interventions; no other item checks the note.
- host-cost: ~119 lines of bash, not loaded into prompts; runs only on tasks with UI work and in CI; no manual step.
- ci-step: Run check-design-note fixture suite

### item: bin/check-durability.sh
- does: Checks that a handoff's artifacts are committed (tracked and content-matching the committed blob) before the next role relies on them, with a local-mode variant.
- prevents: A role handing off a spec or record that exists only in a working tree, lost when the next agent starts — provenance: bin/check-durability.sh:5
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the handoff barrier named by pm-spec, qa-verifier and the run skill; subagents share state only through git-tracked files, so nothing else enforces it.
- host-cost: ~369 lines of bash, not loaded into prompts; one run per handoff; agents carry a short instruction to call it.
- ci-step: Run check-durability fixture suite
- ci-step: Dogfood check-durability — this repository's own T-1048 implement-phase records

### item: bin/check-entry-mode.sh
- does: Pre-freeze gate that requires the board's entry-mode and dispatch sub-bullets to exist and agree, plus the dispatch-reflection and refreeze-ratifier families.
- prevents: A spec freezing under a mode that the board's two independent records do not agree on — provenance: bin/check-entry-mode.sh:2
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — one of the arm-A record gates; named by pm-spec, tech-lead and the run skill and consumed by check-oversight; no other item reads those records.
- host-cost: ~609 lines of bash, not loaded into prompts; one run per freeze; the record lines it requires add a few board lines per task.
- ci-step: Run check-entry-mode fixture suite

### item: bin/check-fanout-instances.sh
- does: Ties one fan-out's telemetry span rows to the merged verdict block and refuses unless presence, grammar, uniqueness and coverage of instance discriminators hold.
- prevents: A fan-out whose per-instance telemetry cannot be attributed, so a claimed saving or verdict cannot be audited — provenance: bin/check-fanout-instances.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — reading half of the fan-out mechanism; no other item reads discriminators back.
- host-cost: ~492 lines of bash, not loaded into prompts; run only when a fan-out is used and in CI; no manual step.
- ci-step: Run check-fanout-instances fixture suite

### item: bin/check-handoff.sh
- does: Lints the board's Active section against the hand-off line format (task id, status flag enum, spec path, continuation lines).
- prevents: A malformed or stranded board line breaking the status-flag hand-off between roles — provenance: bin/check-handoff.sh:13
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the board lint named by every role file and the run skill, the CI gate, and a precondition inside close-out; the board is the loop's only shared control state.
- host-cost: ~216 lines of bash, not loaded into prompts; every agent carries a line telling it to run it; runs in CI on every push; sub-second.
- ci-step: Lint the shipped board template (hand-off linter)
- ci-step: Dogfood check-handoff — this repository's own board
- ci-step: Run check-handoff fixture suite

### item: bin/check-intent.sh
- does: Verifies a spec's frozen intent block against the board's intent-hash and intent-ratified ledger, including the freeze-attestation record.
- prevents: Drift being measured against a spec that silently changed with the code instead of the frozen intent — provenance: bin/check-intent.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the freeze ledger check named by pm-spec, qa-verifier, the reviewers and the run skill; refreeze-class and oversight depend on its normalization.
- host-cost: ~880 lines of bash, not loaded into prompts; one run per freeze, re-freeze and QA read; agents carry short instructions to call it.
- ci-step: Run check-intent fixture suite

### item: bin/check-interventions.sh
- does: Validates a task's interventions record against its structural schema (marker pair, sentinel, entry fields).
- prevents: Human interruptions in a loop having no recorded channel, so the retro cannot see them — provenance: bin/check-interventions.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — sole schema check of the interventions record, named by qa-verifier, scrum-master and the run skill and used at close-out.
- host-cost: ~435 lines of bash, not loaded into prompts; one run per task close-out and in CI; the orchestrator must write the record (a recurring manual-ish step).
- ci-step: Run check-interventions fixture suite
- ci-step: Dogfood check-interventions — every committed interventions file in this repository is conformant

### item: bin/check-invocation-path.sh
- does: Answers whether a shipped recipe exists for a role's resolved adapter and whether the role's board authority is admitted under the recipe's sandbox mode.
- prevents: An alternate-executor invocation proceeding with no recipe or with board authority the sandbox mode does not admit — provenance: bin/check-invocation-path.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the admissibility gate for the alternate-executor path, called by the run skill and check-review-provider.
- host-cost: ~441 lines of bash, not loaded into prompts; runs only when a non-default executor is resolved and in CI.
- ci-step: Run check-invocation-path fixture suite
- ci-step: Dogfood check-invocation-path — the alternate-executor admissibility gate against this repository

### item: bin/check-liveness.sh
- does: Out-of-band classifier that reads the run state, the human-gate declaration and git and prints one liveness token on stdout and the exit code.
- prevents: A stalled loop being indistinguishable from a healthy one waiting at a human gate — provenance: bin/check-liveness.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: unknown — the header says it is invoked by a timer process this repository does not ship, and no agent, skill or other bin script invokes it (only CI, templates/liveness-reasons.txt and design docs name it), so current use cannot be established from the repo.
- host-cost: ~504 lines of bash, not loaded into prompts; CI-only inside this repository; an adopter-side timer would pay the run cost.
- ci-step: Run check-liveness fixture suite
- ci-step: Dogfood check-liveness — the real classifier's --help

### item: bin/check-model-pins.sh
- does: Equality-locks every claude-provider role's frontmatter model pin to the shipped default binding's model token for that role.
- prevents: An agent's model pin and the default binding drifting apart between releases — provenance: bin/check-model-pins.sh:5
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — it makes T-1057's one-time equality check continuous (bin/check-model-pins.sh:6); no other item compares the two.
- host-cost: ~260 lines of bash, not loaded into prompts; CI-only; no manual step.
- ci-step: Run check-model-pins fixture suite
- ci-step: Dogfood check-model-pins — the equality lock against this repository's own conf and pins

### item: bin/check-oversight.sh
- does: Resolves the oversight profile and, at declared seams, requires a conformant approval record whose approver differs from the producer.
- prevents: A freeze or close-out passing at a governed seam without a distinct-approver record, including a silent autonomous answer for a malformed declaration — provenance: bin/check-oversight.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the arm-A approval-record gate used by the run skill, close-out and check-refreeze-grant; the oversight profile has no other enforcer.
- host-cost: ~666 lines of bash, not loaded into prompts; runs at freeze and close-out; under a non-autonomous profile it adds a human approval step per seam.
- ci-step: Run check-oversight fixture suite

### item: bin/check-pii-shapes.sh
- does: Scans a diff or named paths for personal-data shapes (addresses, identifiers) and exits 1 on findings.
- prevents: Personal or identifying data reaching the repository through content a reviewer would not notice — provenance: bin/check-pii-shapes.sh:2
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the only content scanner for the public repository; named by four agent files and the record-shape-scan block; commit identity is covered separately.
- host-cost: ~1030 lines of bash, not loaded into prompts; runs in CI and by engineer, QA and scrum-master; agents carry a short instruction to run it before commit.
- ci-step: Run check-pii-shapes fixture suite
- ci-step: check-pii-shapes on the PR diff

### item: bin/check-playbook.sh
- does: Validates the lessons file's structured playbook fields (category, applies-to, scope, bound-in) for each entry.
- prevents: Lessons entries missing the structured fields the generated prompt blocks are built from — provenance: bin/check-playbook.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — called by gen-playbook-blocks and playbook-promote as well as CI; the generated blocks rely on its schema.
- host-cost: ~811 lines of bash, not loaded into prompts; runs in CI and when lessons are promoted; no manual step.
- ci-step: Run check-playbook fixture suite
- ci-step: Dogfood check-playbook — the real repository corpus at the resolved lessons path is schema-valid

### item: bin/check-prompt-sync.sh
- does: Verifies each consumer file carries its canonical prompt block from templates/prompt-blocks per registry.txt, check-only.
- prevents: Hand-copied prompt blocks drifting from their canonical source — provenance: bin/check-prompt-sync.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the freshness check for every generated or copied block; eleven scripts and templates call or name it.
- host-cost: ~175 lines of bash, not loaded into prompts; runs in CI and from other checkers; no manual step.
- ci-step: Run check-prompt-sync fixture suite
- ci-step: Dogfood check-prompt-sync — this repo's prompt blocks must be in sync

### item: bin/check-provenance.sh
- does: Verifies a task's decision-provenance file against its structural schema (marker pair, decision/reason/grounding triples).
- prevents: Non-trivial implementation decisions with no recorded grounding, hiding drift — provenance: bin/check-provenance.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — sole grammar check of the provenance ledger, named by the engineer, QA, reviewers and the run skill.
- host-cost: ~358 lines of bash, not loaded into prompts; one run per task; the engineer must write the provenance file, a per-task step.
- ci-step: Run check-provenance fixture suite

### item: bin/check-readme-version.sh
- does: Fails when a README's static version badge differs from the version in the plugin manifest.
- prevents: The README version badge going stale on release — provenance: bin/check-readme-version.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — a 87-line manifest comparison that CONTRIBUTING.md:125 lists in the release preparation; trivially cheap.
- host-cost: ~87 lines of bash, not loaded into prompts; CI and one release-preparation command; no per-task cost.
- ci-step: Run check-readme-version fixture suite
- ci-step: Dogfood check-readme-version on the repo's READMEs

### item: bin/check-refreeze-class.sh
- does: Classifies an intent-block delta between two spec files as confined to `- check:` lines (mechanics repair) or touching anything else.
- prevents: A mechanics re-freeze (delegable) hiding a change to goal, non-goals, criterion prose or input space — provenance: bin/check-refreeze-class.sh:6
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the sole classifier behind the delegable class-M re-freeze path, named by pm-spec, code-reviewer and the run skill.
- host-cost: ~417 lines of bash, not loaded into prompts; one run per re-freeze; without it every re-freeze would need a human decision.
- ci-step: Run check-refreeze-class fixture suite

### item: bin/check-refreeze-grant.sh
- does: Reads the host-neutral standing class-M re-freeze grant record and prints `grant none` or `grant <value>`, refusing when malformed.
- prevents: A standing re-freeze grant living only in one host's local instruction file, unreadable on another host — provenance: bin/check-refreeze-grant.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the single reader of the grant record (called by the run skill and CI); malformed state fails closed to no grant.
- host-cost: ~286 lines of bash, not loaded into prompts; one run per re-freeze decision; no manual step.
- ci-step: Run check-refreeze-grant fixture suite

### item: bin/check-retro.sh
- does: Lints scrum-master retro files for the H1, the five language-neutral section markers in order and the retro-inputs section.
- prevents: A retro whose structure cannot be machine-validated across languages — provenance: bin/check-retro.sh:21
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — named by agents/scrum-master.md and CI; the section markers are shared with the registry block, so no other item validates them.
- host-cost: ~417 lines of bash, not loaded into prompts; one run per retro and in CI; no manual step.
- ci-step: Run check-retro fixture suite
- ci-step: Dogfood check-retro — this repository's own retros pass the ledger contract
- ci-step: Dogfood check-retro — the shipped retro template passes its own contract

### item: bin/check-review-input.sh
- does: Checks the review record's per-pass fields (closed vocabularies, pass-id charset, capture-stem collisions) at close-out.
- prevents: A review record whose passes or captures were mis-recorded or reused, so an approval cannot be tied to the work reviewed — provenance: bin/check-review-input.sh:2
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — arm-A close-out gate named by code-reviewer, drift-evaluator, the run skill and close-out; no other item reads those fields.
- host-cost: ~760 lines of bash, not loaded into prompts; one run per review round and at close-out; reviewer briefings must name pass ids it accepts.
- ci-step: Run check-review-input fixture suite

### item: bin/check-review-provider.sh
- does: Refuses (BLOCKED) when the effective code-reviewer binding is not Codex, before any reviewer mode sends repository content to Codex.
- prevents: Repository content being sent to Codex under an operator binding that says it must not be — provenance: bin/check-review-provider.sh:3
- reproducible: unmeasured: no recorded failure was read for this row.
- verdict: keep — the single provider gate run first by every reviewer mode, review-response, drift-evaluator's optional pass and the orchestrator skills.
- host-cost: ~112 lines of bash, not loaded into prompts; one cheap run per reviewer dispatch; reviewer and skill files each carry a line telling them to run it.
- ci-step: Run check-review-provider fixture suite

### item: bin/check-run.sh
- does: Lints an Operating-Loop telemetry JSONL file (or one line) against the span and event row schemas.
- prevents: A corrupt or shape-mixed telemetry row silently entering the run log and skewing roll-ups — provenance: bin/check-run.sh:3
- reproducible: unmeasured: no live model experiment; the schema is deterministic and the shape-mixing rule is exercised only by the script's own suite
- verdict: keep — validates the single writer's output and gates every roll-up and replay that reads the log
- host-cost: none per run unless called; invoked by gen-loop-replay.sh and CI, about 265 lines of bash, no agent-prompt context
- ci-step: Run check-run fixture suite

### item: bin/check-setup.sh
- does: Read-only run-start check that the board, specs dir, loop contract and host-specific files exist, with CRLF notes.
- prevents: Starting a run in a repository whose scaffold is missing or whose plugin files carry CRLF — provenance: bin/check-setup.sh:2
- reproducible: unmeasured: no live model experiment; the CRLF case depends on an operator checkout setting that is not reproducible from the repo alone
- verdict: keep — it is the run skill's Step 0 and the read-only counterpart of the setup writer
- host-cost: one short command at the start of each run; skills/run/SKILL.md carries the step text
- ci-step: Run check-setup fixture suite

### item: bin/check-spec-review.sh
- does: Close-out backstop that refuses an elected spec review whose last verdict line is not an approval, plus a round-guard mode.
- prevents: A task closing after a spec review that never reached approval, via six named defeat classes — provenance: bin/check-spec-review.sh:3
- reproducible: unmeasured: no live model experiment; the six defeat classes are string-matching cases an adopter record could still produce
- verdict: keep — it guards a loop transition and is called from close-out.sh and the run skill
- host-cost: about 371 lines of bash run at close-out; adds no manual step when the review was approved
- ci-step: Run check-spec-review fixture suite

### item: bin/close-out.sh
- does: One-command post-merge close-out: moves the board entry to Done, prints the issue-close procedure, logs a span, regenerates the status block.
- prevents: A hand-edited board close-out that skips the READY_FOR_MERGE pre-flip check or the review backstop — provenance: bin/close-out.sh:2
- reproducible: unmeasured: no live model experiment; the refusal cases are deterministic
- verdict: keep — replaces a multi-step manual board edit and enforces the pre-flip gate
- host-cost: replaces several manual board edits per task; about 827 lines of bash, no prompt context beyond the skill's call line
- ci-step: Run close-out fixture suite

### item: bin/cluster-failures.sh
- does: Groups failing telemetry spans across runs by a normalized phase and reason signature and ranks the themes.
- prevents: Recurring failure shapes staying invisible because the per-run roll-up never looks across runs — provenance: bin/cluster-failures.sh:3
- reproducible: unmeasured: no live model experiment; output is a pure function of the telemetry files
- verdict: unknown — only the optional triage orchestrator and the consolidation script call it; no run in the repo records that it changed a decision
- host-cost: none unless a triage is run; about 215 lines of bash, one extra input to the triage proposal
- ci-step: Run cluster-failures fixture suite

### item: bin/codex-await.sh
- does: Bounded wait on a launched Codex pass's JSON event stream for a start or end event, then exits.
- prevents: A reviewer sub-agent hanging on an unbounded wait when codex exec blocks on an open stdin pipe — provenance: bin/codex-await.sh:3
- reproducible: unmeasured: no live model experiment; the hang depends on how the host wires a sub-agent's stdin
- verdict: keep — both Codex-running roles use it to bound their waits, and the stdin behaviour belongs to the Codex CLI, not the model
- host-cost: each Codex pass waits through it, bounded by its timeout; two agent files carry the call lines
- ci-step: Run codex-await suite

### item: bin/codex-capture.sh
- does: Temp-capture hygiene helper for codex exec output: same-filesystem temp placement, JSONL validation and atomic publish.
- prevents: Partial or unvalidated Codex output being published as a review capture, and the wrapper-nesting sandbox failure — provenance: bin/codex-capture.sh:10
- reproducible: unmeasured: no live model experiment; the sandbox nesting failure depends on host sandbox behaviour
- verdict: keep — it is the only path that validates and publishes a review capture, and both reviewer roles and the run skill call it
- host-cost: about 1130 lines of bash, run per Codex pass; its mode lines appear in two agent files and the run skill
- ci-step: Run codex-skeleton-hygiene suite

### item: bin/consolidate-proposals.sh
- does: Merges discovery, telemetry escalations and failure clusters into one de-duplicated, budget-capped proposal file.
- prevents: A triage proposal flooded with duplicate or uncapped candidates, and attacker-controlled issue bodies reaching the model — provenance: bin/consolidate-proposals.sh:2
- reproducible: unmeasured: no live model experiment; the de-duplication and cap rules are deterministic
- verdict: unknown — only the optional triage orchestrator calls it; the repo does not show how often triage is run
- host-cost: none unless a triage is run; about 461 lines of bash, one proposal file to read per triage
- ci-step: Run consolidate-proposals fixture suite

### item: bin/derive-populations.sh
- does: Runs named population commands under a pinned collation and prints one delimited block of counts, union and a gap-free partition.
- prevents: Set arithmetic done by eye in record prose, which caused five adverse gate rounds in one task — provenance: bin/derive-populations.sh:6
- reproducible: unmeasured: no live model experiment; five rounds are recorded in the header but no failing fixture cites them
- verdict: keep — five agent files carry its call line and the task's own acceptance checks depend on its output
- host-cost: replaces by-hand counting at each completeness claim; about 482 lines of bash, call line in five agent prompts
- ci-step: Run derive-populations fixture suite
- ci-step: Dogfood derive-populations — derive a real population against this repository

### item: bin/discover-work.sh
- does: Read-only discovery of failing CI, open PRs and labelled issues, printed as board-shaped candidate lines.
- prevents: Candidate discovery that reads attacker-controlled PR or issue bodies — provenance: bin/discover-work.sh:2
- reproducible: unmeasured: no live model experiment; depends on gh availability and repository state
- verdict: keep — it is the triage skill and orchestrator's source of candidates and fails soft without gh
- host-cost: none unless a triage is run; about 281 lines of bash, one gh call per source
- ci-step: Run discover-work fixture suite

### item: bin/gen-codex-agents.sh
- does: Derives one Codex CLI custom-agent TOML per shipped role from the unmodified agents/<role>.md.
- prevents: Duplicated role prose drifting between the Claude Code and Codex CLI hosts — provenance: bin/gen-codex-agents.sh:5
- reproducible: unmeasured: no live model experiment; generation is deterministic
- verdict: keep — it is how the Codex host receives the same role prose, called by the setup script and referenced by the run and setup skills
- host-cost: runs once per setup or refresh on the Codex host; about 480 lines of bash, no per-run cost on Claude Code
- ci-step: Run codex-agents fixture suite
- ci-step: Dogfood gen-codex-agents — regenerating this repository's own roles into a scratch out-dir succeeds, and check-codex-agents.sh confirms no drift

### item: bin/gen-loop-replay.sh
- does: Renders one run's telemetry rows into a self-contained HTML replay page from a template.
- prevents: Reading a run only from raw JSONL; no failure is named — provenance: bin/gen-loop-replay.sh:3
- reproducible: unmeasured: no live model experiment; the output is a presentation of existing rows
- verdict: unknown — no agent or skill invokes it; README.md:318 documents it as an on-demand command, so the value is unmeasured
- host-cost: none per run; operator-invoked, about 370 lines of bash plus the HTML template
- ci-step: Run gen-loop-replay fixture suite

### item: bin/gen-playbook-blocks.sh
- does: Derives per-role playbook digest blocks from the lessons file and splices them into their registered consumer files.
- prevents: Role prompts carrying stale or hand-copied lesson rules — provenance: bin/gen-playbook-blocks.sh:4
- reproducible: unmeasured: no live model experiment; the effect on a model's behaviour is not measured here
- verdict: keep — it is the only writer of the generated blocks that the prompt-sync checker verifies, so removal would orphan those blocks
- host-cost: every generated block adds lines to four role prompts on every dispatch; the script itself runs only on a lessons edit, about 510 lines of bash
- ci-step: Run gen-playbook-blocks fixture suite
- ci-step: Dogfood gen-playbook-blocks — regenerating into a scratch copy reproduces every shipped block and consumer

### item: bin/gen-project-status.sh
- does: Regenerates only the marked block of the project status file from the board and git state.
- prevents: A hand-maintained status summary drifting from the board — provenance: bin/gen-project-status.sh:3
- reproducible: unmeasured: no live model experiment; output is deterministic from board and git
- verdict: keep — close-out.sh calls it as a step, and it touches only its own marker region
- host-cost: one extra step inside each close-out; about 155 lines of bash

### item: bin/goal-state.sh
- does: Per-run state helper for the goal loop: iteration counter, elapsed minutes and a normalized failure signature.
- prevents: Loop state lost across separate Bash invocations because environment variables do not persist — provenance: bin/goal-state.sh:5
- reproducible: unmeasured: no live model experiment; the persistence limit is a property of the tool environment
- verdict: keep — it supplies the inputs the budget guard needs, and eight agent files and the goal and run skills reference it
- host-cost: a few small commands per goal tick; about 146 lines of bash
- ci-step: Run goal-state fixture suite

### item: bin/install
- does: Snapshot-copies agent definition files into a target repository and writes a manifest.
- prevents: Adopting the pipeline without the plugin mechanism; no failure is named — provenance: not found
- reproducible: unmeasured: no live model experiment; deterministic file copy
- verdict: unknown — docs/distribution.md:167 describes it only as the fallback where plugin install is unavailable; whether any adopter uses it is not recorded
- host-cost: none per run; about 328 lines of bash, operator-invoked
- ci-step: Run install fixture suite

### item: bin/land-worktree.sh
- does: Serializes landing one worker's committed work onto a task branch behind a never-stolen lock, refusing path overlap.
- prevents: Two concurrent worktrees that cannot both fast-forward into one branch — provenance: bin/land-worktree.sh:4
- reproducible: unmeasured: no live model experiment; the fast-forward limit is a git property
- verdict: keep — the run skill names it as the way parallel worktrees are integrated
- host-cost: used only when 2 or more concurrent workers exist; about 721 lines of bash, one call per worker landing
- ci-step: Run land-worktree fixture suite

### item: bin/log-run.sh
- does: The single writer of Operating-Loop telemetry; validates every field and appends one span or event row.
- prevents: A corrupt telemetry line entering the log through an unvalidated write — provenance: bin/log-run.sh:7
- reproducible: unmeasured: no live model experiment; deterministic validation
- verdict: keep — the run, goal and review-response skills write every row through it
- host-cost: one call per phase and per hand-off in each run; about 726 lines of bash
- ci-step: Run log-run resolution suite

### item: bin/loop-guard.sh
- does: Reads a loop contract and runtime flags and prints CONTINUE or STOP with a reason, failing closed.
- prevents: A runaway or billing-heavy loop with no kill-switch — provenance: bin/loop-guard.sh:5
- reproducible: unmeasured: no live model experiment; deterministic arithmetic over flags
- verdict: keep — it is the budget and stop enforcement the goal and run skills call at each tick, and it fails closed
- host-cost: one call per loop tick; about 220 lines of bash
- ci-step: Run loop-guard fixture suite

### item: bin/playbook-promote.sh
- does: Appends one human-approved lesson candidate to the lessons file after validating a temp copy with the playbook checker.
- prevents: A malformed lesson entry corrupting the lessons file that the generated blocks derive from — provenance: bin/playbook-promote.sh:3
- reproducible: unmeasured: no live model experiment; deterministic schema validation
- verdict: keep — it is step 3 of the documented human promotion path and is never run automatically
- host-cost: one human-run command per promoted lesson; about 361 lines of bash
- ci-step: Run playbook-promote fixture suite

### item: bin/resolve-executor.sh
- does: Fail-closed resolution of which executor runs one named role under the effective binding, writing nothing.
- prevents: A role running on an executor the binding does not permit, or an unresolvable binding being ignored — provenance: bin/resolve-executor.sh:3
- reproducible: unmeasured: no live model experiment; deterministic over binding files
- verdict: keep — six skill and agent files call it before invoking a reviewer, and the shipped reviewer binding depends on it
- host-cost: one call per role dispatch that needs resolution; about 627 lines of bash
- ci-step: Run resolve-executor fixture suite
- ci-step: Dogfood resolve-executor — probe-free mode against this repository (the runner carries neither executor CLI)

### item: bin/retro-inputs.sh
- does: Acquires the retro's nine inputs and emits a machine-checked ledger marking each as read, empty or unavailable.
- prevents: A retro written from a wrong-branch PR query or a nonexistent lessons file with no record of what was consulted — provenance: bin/retro-inputs.sh:3
- reproducible: unmeasured: no live model experiment; the v1 failure modes are described in the header and spec, not in a failing fixture
- verdict: keep — the scrum-master role uses it, and its default of unavailable fails closed
- host-cost: one call per retro; about 584 lines of bash
- ci-step: Run retro-inputs fixture suite
- ci-step: Run retro-inputs bounded invariants lock
- ci-step: Dogfood retro-inputs — the cycle window resolves against this repository

### item: bin/review-gate.sh
- does: Deterministic floor of the review-response risk gate: decides whether a finding must escalate to a human.
- prevents: A dangerous finding class being auto-adopted because a prompt regression eroded the model's judgment — provenance: bin/review-gate.sh:3
- reproducible: unmeasured: no live model experiment; the floor is four deterministic conditions
- verdict: keep — it is an un-removable mechanical floor under the skill's grey-zone judgment
- host-cost: one call per review finding processed; about 141 lines of bash
- ci-step: Run review-gate fixture suite

### item: bin/rework-digest.sh
- does: Formats the rework-history digest for a loop-guard STOP or an early same-class-2 escalation, and self-checks its signature.
- prevents: An escalation shown to the human without the round and class history needed to decide extend or stop — provenance: bin/rework-digest.sh:3
- reproducible: unmeasured: no live model experiment; presentation only
- verdict: keep — the goal and run skills call it at escalation, and it reads no files
- host-cost: one call per escalation; about 585 lines of bash
- ci-step: Run rework-digest fixture suite

### item: bin/rollup-runs.sh
- does: Folds per-span telemetry into a per-run summary with a health flag, skipping event rows.
- prevents: Telemetry that is written but never read back into a per-run view — provenance: bin/rollup-runs.sh:5
- reproducible: unmeasured: no live model experiment; deterministic aggregation
- verdict: unknown — only the optional triage orchestrator and sibling scripts call it; no record shows its summary changed a decision
- host-cost: none unless triage or roll-up is run; about 330 lines of bash
- ci-step: Run rollup-runs fixture suite

### item: bin/rollup-track.sh
- does: Wraps rollup-runs.sh and saves its summary as a dated tracked file, refusing to persist PII-shaped or secret-shaped content.
- prevents: The roll-up evaporating from terminal output, and tracked output carrying PII or secrets — provenance: bin/rollup-track.sh:3
- reproducible: unmeasured: no live model experiment; the PII-refusal behaviour is only described in docs, no failing fixture is cited here
- verdict: unknown — no agent or skill invokes it (only documentation, CI and bin/check-pii-shapes.sh name it), so no consumer of the tracked files is shown
- host-cost: none per run; operator-invoked, about 180 lines of bash
- ci-step: Run rollup-track fixture suite

### item: bin/team-commit.sh
- does: Commits exactly the named paths with one add and one commit, after a closed set of pre-write refusals.
- prevents: Open-ended git commands on the Codex CLI host where the sandbox refuses writes under .git — provenance: bin/team-commit.sh:3
- reproducible: unmeasured: no live model experiment; the sandbox refusal is a host property
- verdict: keep — four role files and the run and goal skills name it as the commit path, and it never pushes or resets
- host-cost: replaces an open-ended commit class with one approvable command per commit; about 530 lines of bash
- ci-step: Run team-commit fixture suite

### item: bin/team-init.sh
- does: Scaffolds an adopting repository's board, contract and directories under one base directory without touching root files.
- prevents: Adopter scaffolding scattered across the host's main tree — provenance: bin/team-init.sh:10
- reproducible: unmeasured: no live model experiment; deterministic file creation
- verdict: keep — the team-init skill and the setup script both use it, and re-running is non-destructive
- host-cost: one call per adoption or update; about 409 lines of bash
- ci-step: Run team-init fixture suite

### item: bin/team-mode.sh
- does: Prints `tracked` or `local` from the clone's own declared git key and nothing else.
- prevents: A global or injected setting putting every clone of every repository into local mode at once — provenance: bin/team-mode.sh:3
- reproducible: unmeasured: no live model experiment; deterministic git-config read
- verdict: keep — eight agent and skill files read the mode through it, so it is the single reader
- host-cost: one short call wherever a role must know the mode; about 91 lines of bash
- ci-step: Run team-mode fixture suite

### item: bin/team-paths.sh
- does: Single source of truth resolving the base directory and the board, specs, runs, reviews and lessons paths.
- prevents: Consumers hardcoding paths that are right in only one of the two supported layouts — provenance: bin/team-paths.sh:3
- reproducible: unmeasured: no live model experiment; deterministic precedence chain
- verdict: keep — thirteen agent and skill files resolve paths through it, and the repository's own rules require it
- host-cost: a few short calls per role dispatch; about 241 lines of bash
- ci-step: Run team-paths fixture suite
- ci-step: Dogfood team-paths — a repo with no legacy markers resolves to the default layout

### item: bin/team-setup.sh
- does: Deterministic half of the setup and update prompt: scaffolds, generates Codex agents on that host, and prints a five-part report.
- prevents: Setup steps done by hand differing between the Claude Code and Codex CLI hosts — provenance: bin/team-setup.sh:3
- reproducible: unmeasured: no live model experiment; deterministic writes and a read-only report
- verdict: keep — the setup skill runs it, and it never rewrites existing scaffold files
- host-cost: one call per setup or update; about 1082 lines of bash, the largest in this group
- ci-step: Run setup fixture suite

## CI steps without a bin row

Workflow steps that execute no `bin/` script: setup steps, `shellcheck` steps (which lint scripts without running them), and suites or inline checks whose subject is not one `bin/` script. Every other workflow step is attached to a `bin/` row.

### item: ci:Checkout
- does: Checks the repository out with full history so later steps can diff against the base branch
- prevents: a job that cannot read the repository runs nothing, and fetch-depth 0 serves the base-branch diffs the PR-diff steps take — provenance: not found
- reproducible: unmeasured: platform step, no repository fixture exercises its absence
- verdict: keep — every later step reads the checkout and the PR-diff steps need the full history
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here

### item: ci:Install shellcheck (pinned — must match local dev version)
- does: Downloads and installs a pinned shellcheck release on the runner
- prevents: CI linting with a different shellcheck version than local development gives different results — provenance: .github/workflows/check-handoff.yml:19
- reproducible: unmeasured: version drift between runner and local is not exercised by a fixture
- verdict: keep — the pin line states the reason and the shellcheck steps depend on it
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one archive download per run

### item: ci:shellcheck
- does: Lints the shell scripts and suites in one shipped bin/ and tests/ list with shellcheck
- prevents: `bin/` stays shellcheck-clean for adopters who run the scripts in repositories we know nothing about — provenance: CLAUDE.md:52
- reproducible: unmeasured: the lint is the check itself, no fixture shows a failure it was added for
- verdict: keep — it is the lint gate the repository rules require for every bin/ script
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one long argument list that every new script is appended to by hand

### item: ci:shellcheck (T-1151 additions)
- does: Lints bin/check-adopter-docs.sh and its suite with shellcheck as a separate step added by T-1151
- prevents: the scripts added by T-1151 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:31
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1157 additions)
- does: Lints tests/bin-help/run.sh with shellcheck as a separate step added by T-1157
- prevents: the scripts added by T-1157 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:34
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1163 additions)
- does: Lints bin/team-setup.sh and tests/setup/run.sh with shellcheck as a separate step added by T-1163
- prevents: the scripts added by T-1163 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:37
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1164 additions)
- does: Lints bin/check-setup.sh and its suite with shellcheck as a separate step added by T-1164
- prevents: the scripts added by T-1164 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:40
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1169 additions)
- does: Lints bin/team-commit.sh and its suite with shellcheck as a separate step added by T-1169
- prevents: the scripts added by T-1169 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:43
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1180 additions)
- does: Lints bin/team-mode.sh and its suite with shellcheck as a separate step added by T-1180
- prevents: the scripts added by T-1180 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:46
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:shellcheck (T-1183 additions)
- does: Lints tests/local-mode/run.sh with shellcheck as a separate step added by T-1183
- prevents: the scripts added by T-1183 would otherwise ship unlinted — provenance: .github/workflows/check-handoff.yml:417
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one extra step per task

### item: ci:Lint the reviewer-binding gate and its suite (T-1177)
- does: Lints bin/check-review-provider.sh and tests/check-review-provider/run.sh with shellcheck
- prevents: T-1177 added the reviewer-binding gate (issue #700) and it must pass the repository lint — provenance: bin/check-review-provider.sh:2
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here

### item: ci:Lint the bounded Codex wait and its suite (T-1178)
- does: Lints bin/codex-await.sh and tests/codex-await/run.sh with shellcheck
- prevents: T-1178 added the bounded Codex wait (issue #695) and it must pass the repository lint — provenance: bin/codex-await.sh:2
- reproducible: unmeasured: no fixture shows a lint failure this step caught
- verdict: keep — the main shellcheck step (.github/workflows/check-handoff.yml:29) does not list these paths, so this step is the only lint of them; folding the paths into that one list would remove the per-task step but no lint work, so it is a structural tidy-up, not a removal
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here

### item: ci:Run trial-recipe fixture suite
- does: Executes the shipped trial-adoption recipe end to end in throwaway repositories under both layouts
- prevents: T-1094 left three deferred findings (recipe not exercised across layouts, ambient global git config, specs path not asserted committed) and T-1098 made them permanent regression locks — provenance: tests/trial-recipe/run.sh:2
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it is the only check that runs the documented recipe rather than a transcription of it
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run machine-tokens fixture suite
- does: Asserts each machine token (status flags, verdict labels, board-line format, markers) appears verbatim in the file that consumes it
- prevents: the token vocabulary of issue #20 was trusted to prose, so drift was found by hand — provenance: tests/machine-tokens/run.sh:2
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it guards a vocabulary that has no single owning script
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run is-span-row-parity fixture suite
- does: Feeds one row per fixture to rollup-runs.sh and cluster-failures.sh and asserts their duplicated is_span_row() copies agree
- prevents: two deliberately duplicated is_span_row() copies (hazard H4) could drift apart silently, issue #80 — provenance: tests/is-span-row-parity/run.sh:5
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it is the only guard on the deliberate duplication
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run errexit-safe regression suite
- does: Fires each checker die/exit path with stderr closed and asserts the contracted exit code is still reached
- prevents: a die path shaped printf >&2; exit N exits 1 instead of N when stderr is closed, breaking the exit-code contract of fail-closed gates, issue #296 — provenance: tests/errexit-safe/run.sh:2
- reproducible: measured: tests/errexit-safe/run.sh:16 (part (i) counterfactual proves the unsafe and safe shapes differ under 2>&-)
- verdict: keep — it protects the exit-code contract that fail-closed callers depend on
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run gitignore-raw-dumps lock suite
- does: Proves the raw-review-dump ignore patterns still ignore dumps under a hostile global excludes file while curated notes stay tracked
- prevents: raw review dumps and .codex-review.json must not be committed, and removing an ignore pattern otherwise fails silently, issue #6 — provenance: tests/gitignore-raw-dumps/run.sh:2
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it locks a property that already holds and has no other guard
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run interventions-reminder fixture suite
- does: Drives the opt-in reminder hook sample against synthetic board fixtures and asserts the two-outcome contract (payload or silent no-op)
- prevents: the shipped opt-in hook sample must emit the reminder for an in-flight board and nothing in every other state, T-1004 — provenance: tests/interventions-reminder/run.sh:4
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it is the only test of a shipped adopter-facing sample
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run bin-exec-bit lock suite
- does: Asserts every tracked file under bin/ has git index mode 100755
- prevents: a missing exec bit was found by hand in T-1028 review because every mechanical caller uses bash bin/..., issue #138 — provenance: tests/bin-exec-bit/run.sh:3
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it catches a defect no caller exercises
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run bin-help suite
- does: Asserts every tracked bin/ entry answers --help and -h with exit 0 and non-empty stdout, reading no stdin and writing nothing
- prevents: 14 of 55 bin scripts answered --help with a usage error instead of usage, issue #592 — provenance: tests/bin-help/run.sh:4
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it locks the --help contract across the whole bin/ population
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Run local-mode fixture suite
- does: Drives the whole mechanical local record-mode path in a fixture repository and asserts no record reaches git history
- prevents: the mechanical half of the local record-mode acceptance (issue #711 task C2a) needs an end-to-end proof across several scripts — provenance: tests/local-mode/run.sh:3
- reproducible: unmeasured: the suite is the lock itself and was not re-run for this inventory
- verdict: keep — it is the only end-to-end check across the local-mode scripts
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here; one bash suite run per CI job

### item: ci:Dogfood applies-effort — the recipe's declaration agrees with each adapter's own effort-mechanism (T-1119)
- does: Checks that each applies-effort declaration in the alternate-executor recipe equals the adapter's effort-mechanism
- prevents: a recipe declaration that disagrees with its adapter would misstate whether effort is applied, T-1119 — provenance: .github/workflows/check-handoff.yml:346
- reproducible: unmeasured: no fixture shows a disagreement this step caught
- verdict: keep — an inline check with no script or suite behind it, nothing else covers the equality
- host-cost: CI-only (runs on the hosted runner for each PR and push; no host context, no manual step); the host would stop paying that CI wall-clock, not measured here

## Review shapes

Every Codex pass the plugin defines is listed here, with the closed list below. The adversarial and evidence shapes are one `codex exec` invocation (the perspectives-file pass, whose raw capture stem is the adversarial one and whose answer is the evidence ledger), kept as two rows because the review record names them separately. The wall-clock bound for a Codex pass is the await rule: a start wait of 120 s then up to seven end waits of 540 s each (agents/code-reviewer.md:46), a ceiling of about 65 minutes per pass, not a typical figure.

- closed-list: shape:primary shape:adversarial shape:evidence shape:review-response shape:spec-review shape:drift-semantic

### item: shape:primary
- does: Default fresh-review pass: one `codex exec ... review --base <base>` read-only run in the repo, whose final message is captured and grouped by severity into the verdict.
- prevents: Same-family blind spots when a Claude-family model reviews Claude-family output — provenance: agents/code-reviewer.md:23
- reproducible: unmeasured: no repo fixture shows a Claude-only review missing a defect that Codex catches; the review records are the corpus but were not sampled for this row.
- verdict: keep — it is the cross-provider gate that Done depends on (one of the two green gates); no evidence another item replaces it.
- host-cost: one Codex pass on every review round, background-launched and awaited with bounded waits (ceiling about 65 min, agents/code-reviewer.md:46); Codex usage per round; the reviewer role prompt is about 301 lines and 13,000 words loaded per review.

### item: shape:adversarial
- does: The second `codex exec` of a round, prompted by a perspectives file (T1-T5 including a devil's-advocate perspective that tries to break the primary pass's judgment, plus spec-derived rows); its raw capture stem is the adversarial one and its findings land under the "Adversarial findings" heading.
- prevents: A primary pass understating a problem or returning an empty findings list that is read as clean — provenance: agents/code-reviewer.md:119
- reproducible: unmeasured: no live model experiment is staged; a lesson on empty reviewer findings exists in the corpus but was not tied to this pass by a line in the agent file.
- verdict: unknown — the pass shares its invocation with the evidence shape, so removing or simplifying it cannot be judged apart from that row; no evidence was gathered on how often it changes a verdict.
- host-cost: one extra Codex pass per round heading for APPROVE (the trigger holds by construction on those rounds, agents/code-reviewer.md:118), roughly doubling Codex wall-clock and usage for an approving round.

### item: shape:evidence
- does: The same perspectives-file pass viewed as the evidence ledger: Codex answers one row per perspective (holds, defect, not-applicable) with file:line anchors, and APPROVE is structurally impossible without a complete ledger.
- prevents: An APPROVE resting on an empty findings list alone, with no demonstrated reading of the code — provenance: agents/code-reviewer.md:261
- reproducible: unmeasured: bin/check-review-input.sh validates the per-pass record fields fail-closed and has a suite (tests/check-review-input), but no cited fixture shows the empty-APPROVE failure with a current model.
- verdict: keep — the ledger is enforced mechanically on the records and re-checked by the orchestrator at the review step (skills/run/SKILL.md:120); no evidence it duplicates another gate.
- host-cost: shares the adversarial pass's Codex run (no separate wall-clock beyond it) but adds the perspectives-file build and the ledger transcription to every approving round, and one extra per-pass record block the checker validates.

### item: shape:review-response
- does: Finding-evaluation mode of code-reviewer: one Codex pass over the PR diff plus the already-received findings, returning per finding validity, severity, recommended fix, objection, risk-area and confidence.
- prevents: The risk gate being fed guessed inputs or a Claude-only evaluation of someone else's findings — provenance: agents/code-reviewer.md:191
- reproducible: unmeasured: no repo record of a Claude-only evaluation passing the gate; tests/review-gate checks the floor on given inputs, not the evaluation.
- verdict: keep — the deterministic floor consumes exactly its four fields and the cross-provider point is stated in the same lines; no evidence of duplication.
- host-cost: one Codex pass per review-response invocation (same await ceiling as the primary), plus a possible manual GO when any finding escalates; none on runs that never use the skill.

### item: shape:spec-review
- does: Spec-review mode of code-reviewer at the Specify seam: a Codex pass over the spec document itself, before implementation and before the intent hash is recorded, ending in a distinct Spec-Review verdict block and guarded by a round cap.
- prevents: Implementing against a spec whose acceptance criteria or check lines are wrong, and an unbounded spec-review loop — provenance: agents/code-reviewer.md:195
- reproducible: unmeasured: docs/loop-engineering/specify-seam-review.md records the pricing of this axis, but it was not sampled for a measured cell here.
- verdict: unknown — entry is conditional (only when the Routing Map elects it), so its firing frequency in current runs decides its cost and was not measured here.
- host-cost: when elected, one Codex pass per spec round (up to the round cap) before implementation starts, plus a round-cap check call and a record section; zero when the Routing Map does not elect it.

### item: shape:drift-semantic
- does: The Codex semantic pass of drift-evaluator: Codex reads the frozen intent block, the provenance file and the diff and returns one of aligned, drift-detected, ungrounded-decision or OOD-novelty, which the role may override and must ledger.
- prevents: A delivered diff whose meaning drifts from the frozen intent while every mechanical check passes, and ungrounded decisions slipping through — provenance: agents/drift-evaluator.md:8
- reproducible: unmeasured: the pass is advisory and optional; no repo record was sampled for how often it returns a non-aligned verdict.
- verdict: unknown — it is an optional pass run only on tasks carrying a frozen intent block after APPROVE; how often it runs and changes an outcome was not measured here.
- host-cost: one extra Codex pass after APPROVE on opted-in tasks, with the same await ceiling as the primary; the drift-evaluator prompt is about 164 lines and 4,900 words, loaded only when it runs.

## Appendix: derived verdict populations

Each block below is the output of the command on the `- reproduce:` line above it, run at the repository root against this document. The sets count rows by verdict within one id prefix group.

- reproduce: bash bin/derive-populations.sh --label verdicts-agents --set "keep=awk -v p=agents/ -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=agents/ -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=agents/ -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=agents/ -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-agents -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 8 — items: 8 — command: awk -v p=agents/ -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 0 — items: 0 — command: awk -v p=agents/ -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=agents/ -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 1 — items: 1 — command: awk -v p=agents/ -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 9
- bucket: keep — items: 8
  - agents/code-reviewer.md
  - agents/engineer.md
  - agents/pm-spec.md
  - agents/qa-verifier.md
  - agents/scrum-master.md
  - agents/tech-lead.md
  - agents/triage-orchestrator.md
  - agents/ui-designer.md
- bucket: unknown — items: 1
  - agents/drift-evaluator.md
<!-- END derivation: verdicts-agents -->

- reproduce: bash bin/derive-populations.sh --label verdicts-templates --set "keep=awk -v p=templates/ -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=templates/ -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=templates/ -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=templates/ -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-templates -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 24 — items: 24 — command: awk -v p=templates/ -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 0 — items: 0 — command: awk -v p=templates/ -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=templates/ -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 5 — items: 5 — command: awk -v p=templates/ -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 29
- bucket: keep — items: 24
  - templates/prompt-blocks/adopter-docs-declaration.md
  - templates/prompt-blocks/board-line-format.md
  - templates/prompt-blocks/careful-execution.md
  - templates/prompt-blocks/convergence-escalation.md
  - templates/prompt-blocks/derived-populations.md
  - templates/prompt-blocks/dispatch-record.md
  - templates/prompt-blocks/executor-resolution.md
  - templates/prompt-blocks/fanout-orchestration.md
  - templates/prompt-blocks/flag-enum.md
  - templates/prompt-blocks/host-dispatch.md
  - templates/prompt-blocks/interventions-classes.md
  - templates/prompt-blocks/language-code-reviewer.md
  - templates/prompt-blocks/language-triage-orchestrator.md
  - templates/prompt-blocks/language.md
  - templates/prompt-blocks/liveness-declaration.md
  - templates/prompt-blocks/means-ends-reflection.md
  - templates/prompt-blocks/operating-paths-core.md
  - templates/prompt-blocks/record-mode.md
  - templates/prompt-blocks/record-portability.md
  - templates/prompt-blocks/record-shape-scan.md
  - templates/prompt-blocks/retro-inputs.md
  - templates/prompt-blocks/retro-sections.md
  - templates/prompt-blocks/telemetry-binding.md
  - templates/prompt-blocks/verdict-labels.md
- bucket: unknown — items: 5
  - templates/prompt-blocks/alternate-executor-invocation.md
  - templates/prompt-blocks/playbook-engineer.md
  - templates/prompt-blocks/playbook-pm-spec.md
  - templates/prompt-blocks/playbook-qa-verifier.md
  - templates/prompt-blocks/playbook-tech-lead.md
<!-- END derivation: verdicts-templates -->

- reproduce: bash bin/derive-populations.sh --label verdicts-skills --set "keep=awk -v p=skills/ -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=skills/ -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=skills/ -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=skills/ -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-skills -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 5 — items: 5 — command: awk -v p=skills/ -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 1 — items: 1 — command: awk -v p=skills/ -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=skills/ -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 1 — items: 1 — command: awk -v p=skills/ -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 7
- bucket: keep — items: 5
  - skills/loop-triage
  - skills/review
  - skills/review-response
  - skills/setup
  - skills/team-init
- bucket: simplify — items: 1
  - skills/run
- bucket: unknown — items: 1
  - skills/goal
<!-- END derivation: verdicts-skills -->

- reproduce: bash bin/derive-populations.sh --label verdicts-bin --set "keep=awk -v p=bin/ -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=bin/ -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=bin/ -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=bin/ -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-bin -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 55 — items: 55 — command: awk -v p=bin/ -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 0 — items: 0 — command: awk -v p=bin/ -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=bin/ -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 7 — items: 7 — command: awk -v p=bin/ -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 62
- bucket: keep — items: 55
  - bin/aggregate-verdicts.sh
  - bin/check-acs.sh
  - bin/check-adapter.sh
  - bin/check-adopter-docs.sh
  - bin/check-binding.sh
  - bin/check-board-headings.sh
  - bin/check-codex-agents.sh
  - bin/check-commit-identity.sh
  - bin/check-contract.sh
  - bin/check-count-claims.sh
  - bin/check-design-note.sh
  - bin/check-durability.sh
  - bin/check-entry-mode.sh
  - bin/check-fanout-instances.sh
  - bin/check-handoff.sh
  - bin/check-intent.sh
  - bin/check-interventions.sh
  - bin/check-invocation-path.sh
  - bin/check-model-pins.sh
  - bin/check-oversight.sh
  - bin/check-pii-shapes.sh
  - bin/check-playbook.sh
  - bin/check-prompt-sync.sh
  - bin/check-provenance.sh
  - bin/check-readme-version.sh
  - bin/check-refreeze-class.sh
  - bin/check-refreeze-grant.sh
  - bin/check-retro.sh
  - bin/check-review-input.sh
  - bin/check-review-provider.sh
  - bin/check-run.sh
  - bin/check-setup.sh
  - bin/check-spec-review.sh
  - bin/close-out.sh
  - bin/codex-await.sh
  - bin/codex-capture.sh
  - bin/derive-populations.sh
  - bin/discover-work.sh
  - bin/gen-codex-agents.sh
  - bin/gen-playbook-blocks.sh
  - bin/gen-project-status.sh
  - bin/goal-state.sh
  - bin/land-worktree.sh
  - bin/log-run.sh
  - bin/loop-guard.sh
  - bin/playbook-promote.sh
  - bin/resolve-executor.sh
  - bin/retro-inputs.sh
  - bin/review-gate.sh
  - bin/rework-digest.sh
  - bin/team-commit.sh
  - bin/team-init.sh
  - bin/team-mode.sh
  - bin/team-paths.sh
  - bin/team-setup.sh
- bucket: unknown — items: 7
  - bin/check-liveness.sh
  - bin/cluster-failures.sh
  - bin/consolidate-proposals.sh
  - bin/gen-loop-replay.sh
  - bin/install
  - bin/rollup-runs.sh
  - bin/rollup-track.sh
<!-- END derivation: verdicts-bin -->

- reproduce: bash bin/derive-populations.sh --label verdicts-ci --set "keep=awk -v p=ci: -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=ci: -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=ci: -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=ci: -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-ci -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 22 — items: 22 — command: awk -v p=ci: -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 0 — items: 0 — command: awk -v p=ci: -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=ci: -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 0 — items: 0 — command: awk -v p=ci: -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 22
- bucket: keep — items: 22
  - ci:Checkout
  - ci:Dogfood applies-effort — the recipe's declaration agrees with each adapter's own effort-mechanism (T-1119)
  - ci:Install shellcheck (pinned — must match local dev version)
  - ci:Lint the bounded Codex wait and its suite (T-1178)
  - ci:Lint the reviewer-binding gate and its suite (T-1177)
  - ci:Run bin-exec-bit lock suite
  - ci:Run bin-help suite
  - ci:Run errexit-safe regression suite
  - ci:Run gitignore-raw-dumps lock suite
  - ci:Run interventions-reminder fixture suite
  - ci:Run is-span-row-parity fixture suite
  - ci:Run local-mode fixture suite
  - ci:Run machine-tokens fixture suite
  - ci:Run trial-recipe fixture suite
  - ci:shellcheck
  - ci:shellcheck (T-1151 additions)
  - ci:shellcheck (T-1157 additions)
  - ci:shellcheck (T-1163 additions)
  - ci:shellcheck (T-1164 additions)
  - ci:shellcheck (T-1169 additions)
  - ci:shellcheck (T-1180 additions)
  - ci:shellcheck (T-1183 additions)
<!-- END derivation: verdicts-ci -->

- reproduce: bash bin/derive-populations.sh --label verdicts-shape --set "keep=awk -v p=shape: -v v=keep '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "simplify=awk -v p=shape: -v v=simplify '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "candidate=awk -v p=shape: -v v=candidate '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md" --set "unknown=awk -v p=shape: -v v=unknown '/^### item: /{id=substr(\$0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr(\$0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md"
<!-- BEGIN derivation: verdicts-shape -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: keep — status: 0 — lines: 3 — items: 3 — command: awk -v p=shape: -v v=keep '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: simplify — status: 0 — lines: 0 — items: 0 — command: awk -v p=shape: -v v=simplify '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: candidate — status: 0 — lines: 0 — items: 0 — command: awk -v p=shape: -v v=candidate '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- set: unknown — status: 0 — lines: 3 — items: 3 — command: awk -v p=shape: -v v=unknown '/^### item: /{id=substr($0,11)} /^- verdict: /{if(index(id,p)==1&&index(substr($0,12),v)==1)print id}' docs/loop-engineering/machinery-inventory.md
- union: items: 6
- bucket: keep — items: 3
  - shape:evidence
  - shape:primary
  - shape:review-response
- bucket: unknown — items: 3
  - shape:adversarial
  - shape:drift-semantic
  - shape:spec-review
<!-- END derivation: verdicts-shape -->
