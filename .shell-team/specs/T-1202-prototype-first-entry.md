# A task whose requirements only emerge by trying can start with one throwaway prototype run whose findings feed the spec before the first freeze

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1202

## Problem

The loop assumes a spec can be written and frozen before anything is built. Some work breaks that assumption: generating an artifact, a prototype or a visual exploration, and changes whose constraints appear only when the thing actually runs, such as an external generator's length limit. For that work, every constraint found at run time costs a re-freeze and an operator GO. Adopters then move the work out of the loop, where nothing is recorded (relayed adopter measurements in Assumptions). Issue #795 asks for a Plan-time route that runs one throwaway prototype and hands its findings to `pm-spec` before the first freeze. Everything else stays as it is. It also asks for a droppable side item: the task's interventions file is created with the zero-entry sentinel when the task starts.

## Summarized sources

- **Issue #795 body**, relayed verbatim by the coordinating session (this role cannot open the tracker; labelled relayed in Assumptions). Distinctions carried over:
  - routing happens at Plan by `tech-lead`, only for tasks whose requirements cannot be stated before trying;
  - the prototype runs once and is throwaway;
  - its findings are an input to `pm-spec` before the first freeze;
  - freeze, check lines, QA, cross-provider review, mutation tests and fast-follow are unchanged, and the default path does not change for tasks not routed this way;
  - the output is never shipped as the implementation and bypasses no gate;
  - loosening the freeze is ruled out;
  - the interventions-file item is droppable.

  Restated by the Goal, D1–D7, **AC1**–**AC6**, **AC10** and the Non-goals.
- **The operator-approved planning**, relayed: item (1) never-dropped, MINOR; item (2) droppable, PATCH; release premise v2.11.0; the post-release goal metric. Restated by the pre-commitment, **AC14** and `## Version`.
- **tech-lead's Routing Map**, relayed. Its measurable anchors were re-read by this role (below). Restated by D1–D7.
- **`skills/run/SKILL.md:9-16`** (read): the task-aptitude first branch, which asks whether the final verification surface closes inside the loop (human visual gate). This axis differs from D2's trigger. Restated by D2 and **AC6** (that section byte-identical).
- **`skills/run/SKILL.md:42`** (read): the orchestrator is the only producer of interventions entries. Plan-time entries go to `no-task.md` and are copied into the task's own file once the board entry exists. A file with nothing to record carries `no interventions occurred`. Restated by D6, D7 and **AC4**, **AC5**.
- **`skills/run/SKILL.md:57-58`** (read): step 1 Plan, the trivial path (`pm-spec` trivial mode, `- trivial-path:` sub-bullet, no intent block), and the dispatch-record paragraph. Restated by D2 (exclusivity), D5 (`- trivial-path:` precedent) and **AC6** (lines survive).
- **`skills/run/SKILL.md:59-80`** (read): step 2 Specify. Restated by **AC5**.
- **`skills/run/SKILL.md:90`** (read): the orchestrator commits the spec and the board. Restated by D4 (who commits the findings record).
- **`skills/run/SKILL.md:99`** (read): the first real interventions entry replaces the sentinel line; the two never coexist. Restated by D7.
- **`skills/run/SKILL.md:144-163`** (read): telemetry span rows are emitted by the orchestrator per sub-agent call. Restated by D3 and **AC4**.
- **`bin/log-run.sh:340-341`, `:477`** (read): `--span` and `--phase` must be non-empty and are written verbatim; no closed set of values. Restated by D3 (`--span prototype --phase plan` needs no script change).
- **`bin/check-durability.sh:76-83`** (read): the `specs` registry row matches `<task-id>-*.md`, and two or more matches are `structural`. Restated by D4 (the findings record does not start with the task id).
- **`bin/close-out.sh:292-297`** (read): the dispatch axis table `implement`, `verify`, `verify-fixture`, `verify-mechanism`, `specify`, `spec-review`. **`bin/check-entry-mode.sh:471`** (read): the same closed axis keys for reflection rows. Restated by D5 (no new axis) and **AC10**, **AC12**.
- **`bin/check-handoff.sh:37-45`** (read): the closed status-flag set. Restated by D5 (no new flag) and **AC10**.
- **`bin/close-out.sh:412-419`** (read): the conformant zero-entry interventions record, which is exactly three lines (BEGIN marker, `no interventions occurred`, END marker). Restated by D7 and **AC5**.
- **`bin/team-paths.sh:194`** (read): the interventions dir resolves to `<base>/interventions` in every layout. The paths line the orchestrator prepends (`skills/run/SKILL.md:26`) names no interventions dir. Restated by D7 and **AC5**.
- **`agents/tech-lead.md:47-105`** (read): the Routing Map output format, a code block that contains its own `## Routing Map:` line, and `## Rules`, including the trivial-path rule at `:82`. Restated by D2 and **AC1**.
- **`agents/engineer.md:12-58`** (read): the inputs, the loop, and the rules "No worktree by default", "Don't edit `docs/specs/` except … `## Notes from engineer`" and commit-before-`READY_FOR_QA`. The first generated block starts at `:68`. Restated by D3 and **AC2**.
- **`agents/pm-spec.md:61-74`, `:154`** (read): `## Rules`, which includes the trivial-mode bullet; the first generated block starts at `:154`. Restated by D4, D7 and **AC3**, **AC5**, **AC6**.
- **`.shell-team/specs/T-1108-sweep-corpus-isolation.md` AC2 and AC3** (read at the source):
  - AC2 pins `agents/pm-spec.md` from the first `<!-- BEGIN prompt-block:` line to end of file;
  - AC3 requires `agents/pm-spec.md` to be byte-identical to `git merge-base develop HEAD` once the method item is removed, with equal line counts;
  - `.shell-team/specs/T-1200-downstream-diff-default.md` **AC3** asserts the same property, and its **AC4** asserts that the heading counts of `docs/adopting.md` and `docs/adopting.ja.md` equal their base counts and each other.

  Restated by **AC6** (generated spans), **AC7** (heading counts) and `## Blast radius`.
- **`docs/workflow.md:42-53`, `docs/workflow.ja.md:42-53`** (read): the "When to skip phases" table, including the trivial-mode row. **`docs/adopting.md:185-246`, `docs/adopting.ja.md:191-246`** (read): `## How to run` / `## 実行方法`, written as bold-led paragraphs. **`README.md:225-238`, `README.ja.md:225-238`** (read): `## Phase flow` / `## フェーズフロー`, a code block with a conditional `[Design]` line and one sentence about it. Restated by D8 and **AC7**, **AC8**.
- **`bin/gen-codex-agents.sh:15-119`, `bin/check-codex-agents.sh:1-50`** (read headers): generated Codex agents carry `agents/<role>.md` bodies, written to `--out-dir`, and drift is checked against a fresh generation. Restated by **AC9** and `## Blast radius` (adopter-side artifacts).
- **`bin/close-out.sh:421-424`** (read): a missing path, a directory, a FIFO, an unreadable file or a dangling symlink at the interventions path is refused as no readable record. Restated by Input space out-of-scope item 3.
- **`bin/check-pii-shapes.sh:229-245`** (read): the `--paths <path>…` mode. Restated by D4 (normalization) and **AC2**.
- **`.github/workflows/check-handoff.yml`** (step `name:` lines read in full, `:49-56` read): the suites and dogfood steps CI runs. Restated by **AC13** and `## Blast radius`.
- **`tests/codex-skeleton-hygiene/run.sh:1546-1672`** (read): two regex locks over the live `skills/run/SKILL.md`. `NEW_AC3` forbids a `bash|sh|source|.` invocation of `bin/check-(provenance|interventions).sh`. `NEW_AC15` forbids `(provenance|interventions) gate:AC<n>` and `route back through loop guard`. Restated by `## Blast radius` and the engineer notes.
- **`.shell-team/loops/shell-team.contract.yaml:59-61`** (read): this repository declares `ci_runs_test_suites: yes` with `ci_suite_workflows: .github/workflows/check-handoff.yml`. Restated by `## Blast radius`.

## Goal

<!-- BEGIN intent-block: T-1202 -->

- user-visible: yes — an adopter's run can now route a task whose requirements emerge only by trying to a prototype-first entry. One throwaway prototype runs in a scratch directory, and its findings record is read by `pm-spec` before the first freeze. Tasks not routed this way run exactly as before.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: docs/workflow.md — this-task
- shipped-docs: docs/workflow.ja.md — this-task
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- verification-class: no-mechanism — the diff edits agent and skill prose and six shipped documents only. It touches no path under `bin/`, `tests/`, `templates/` or `.github/` and changes no checker's semantics. Because it edits `agents/pm-spec.md`, which holds the verification checklist, the norm-editing obligation applies; the read set is in `## Blast radius`.
- verification-ceiling: unit-and-static — **AC1**–**AC12** read the post-implementation tree, the commit range and the exit codes of `check-prompt-sync.sh`, `gen-codex-agents.sh`, `check-adopter-docs.sh`, `check-handoff.sh` and `check-interventions.sh` in a plain checkout. **AC13** (CI) and **AC14** (the post-release goal metric) sit above the ceiling.
- base-ref-discriminator: not-applicable — the branch is not stacked and has no open predecessor. It was cut from `develop`, and every base-side read uses `git merge-base` of `develop` (local branch, else `refs/remotes/origin/develop`) and HEAD.

**Goal.** At Plan, `tech-lead` can route a task to a prototype-first entry when its acceptance criteria cannot be written as testable statements until something is run once. `engineer` in prototype mode then runs one throwaway prototype outside the working tree and writes one tracked findings record, and `pm-spec` reads that record as a primary input before the first freeze. Every gate, the freeze, the trivial path and the default path stay unchanged. As a droppable side item, `pm-spec` creates the task's interventions file with the zero-entry sentinel when it creates the board entry and the file is absent.

**Decisions frozen here** (each is promoted to a criterion or exempted in the correspondence table):

- **D1 — the stage.** The prototype-first entry is a branch of step 1 (Plan). It runs after `tech-lead` returns its Routing Map and before step 2 (Specify). The orchestrator dispatches it; there is no new phase flag.
- **D2 — the routing trigger** (`agents/tech-lead.md`, `## Rules`, one line). Route prototype-first when the task's acceptance criteria cannot be written as testable statements until something is run once, because a constraint, limit or failure mode of a tool, generator or runtime is stated nowhere the repository or its docs can be read.
  - This axis differs from the task-aptitude branch (`skills/run/SKILL.md:9-16`).
  - A task is never routed both prototype-first and trivial.
  - It is compatible with `specify — operator-authored`.
  - The Routing Map carries an optional `[engineer — prototype mode]` step holding the brief:
    - the questions, each one a premise `pm-spec` needs;
    - the stop condition;
    - the findings record's `<slug>`.
- **D3 — who runs it, and where** (`agents/engineer.md`, a new `## Prototype mode` section above the generated blocks).
  - **Where.** `engineer` runs the prototype outside the working tree, under `$TMPDIR` (or the platform temp default when it is unset), in an empty directory or a `git clone --shared`.
  - **Limits.** It stops once every question has a measured answer or is declared unanswerable. There is one prototype run per task; a second run goes back through `tech-lead` re-planning.
  - **Write boundary.** It writes exactly one findings record. It commits nothing, changes no board flag, creates no branch, pushes nothing and performs no recursive deletion; scratch is left in place.
  - **Failure.** If the scratch location is not writable, it stops `BLOCKED` with the error verbatim and never changes the host's environment.
  - **Status.** The prototype output is never shipped as the implementation.
  - **Telemetry.** The orchestrator records the span as `--span prototype --phase plan`.
  - **Separation.** QA never runs the prototype. The implementation-phase `engineer` is dispatched separately and is never given the scratch path.
  - **Interventions.** Plan-phase interventions go to `no-task.md` and are copied in under the existing rule.
- **D4 — the findings record.**
  - **Location.** A tracked file at `<specs dir>/prototype-findings-<slug>.md`. It never starts with the task id, so the `specs` durability row keeps exactly one `<task-id>-*.md` match.
  - **Sections.** Five fixed sections: `## Questions` (copied from the brief), `## What was run` (commands, tool versions), `## Findings` (each a constraint, failure mode or measured limit, with its evidence command and an output excerpt), `## Still unknown`, and `## Not for shipping`.
  - **Normalization.** Recorded commands, paths and output excerpts write the scratch root as `<scratch>` and the checkout root as `<repo-root>`, and carry no home-directory path, user name, host name or credential. Before handing back, the writer runs `check-pii-shapes.sh --paths` on the record and fixes any hit in place.
  - **Commit.** In tracked mode the orchestrator commits the findings record with the spec and board. In local mode it is written and never committed.
  - **Use by `pm-spec`.** `pm-spec` reads it as a primary input, lists it in `## Summarized sources`, and labels each finding it relies on in `## Assumptions` as "measured by the prototype run, <date>". The freeze sweep then re-measures each finding where it is reproducible.
  - **Board lines.** `pm-spec` writes `- prototype-first: <ground>` and `- prototype-findings: <path>` on the board entry.
  - **Fail closed.** On a prototype-first route, if the record is absent or empty, `pm-spec` stops `BLOCKED` and routes back instead of writing the spec.
  - **Operator-authored.** With `specify — operator-authored`, the spec's author carries the read, list and label duties. `pm-spec`, as conformance formatter, still writes the two board lines and still stops `BLOCKED` on an absent or empty record.
- **D5 — no new machinery.** No new dispatch axis, no new status flag, no new role, no new human gate, and no `bin/`, `templates/`, `tests/` or `.github/` edit. The records follow the `- trivial-path:` precedent.
- **D6 — the bound is prose.** The brief, the stop condition and the one-run rule are prose, not a checker. They stay observable through the telemetry span and the findings record, and the adopting guides say so.
- **D7 — item (2), droppable: the interventions file at entry creation.**
  - When `pm-spec` creates a board entry, in full, trivial and conformance-formatter modes alike, it writes `<interventions dir>/<task-id>.md`. The file holds exactly the conformant zero-entry record: the BEGIN marker, `no interventions occurred` and the END marker.
  - It writes the file only if it is absent: it reads first and never overwrites.
  - The orchestrator passes the interventions dir as an `Interventions dir:` line, resolved with `team-paths.sh --get interventions`, when it invokes `pm-spec`.
  - The orchestrator stays the only producer of entries, and the existing replace-the-sentinel rule is unchanged.
  - In tracked mode the orchestrator commits the file with the spec and board. In local mode it is written and never committed.
- **D8 — adopter-facing documentation.**
  - `docs/adopting.md` / `.ja.md` (inside `## How to run` / `## 実行方法`, no new `## ` heading) state the trigger, the scratch location, the findings record and its board lines, that the prototype output is never shipped, and that the bound is prose.
  - `docs/workflow.md` / `.ja.md` add a row to the phase-shortcut table.
  - `README.md` / `.ja.md` add a conditional `[Prototype]` line and one sentence to the phase flow.
- **D9 — unchanged and additive.** Every edited file keeps every base line verbatim (lines are only added). The task-aptitude section and every generated prompt-block span are byte-identical to base.

**Pre-commitment (recorded before round 1).** The never-dropped and droppable classification of items (1) and (2) is the operator-approved planning (relayed). The trigger and the drop disposition are AI self-discipline proposed by the coordinating session, never operator-ratified.

- **Never-dropped:**
  - item (1), the prototype-first entry (D1–D6, D8; **AC1**–**AC4**, **AC7**–**AC10**);
  - the unchanged/additive and scope locks (D5, D9; **AC6**, **AC12**).

  The first defeat of a never-dropped component stops the task and returns it to planning. No patch round is added.
- **Droppable, first:** item (2) (D7; **AC5**). On the trigger, D7 is dropped from this task and filed as its own issue, and the round findings travel into that issue's body as its requirement list. Item (1) ships without it.
- **Trigger:** two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same component. A round interrupted before a verdict does not count.

## Non-goals

- **No change to the freeze, the intent block, check lines, QA, cross-provider review, mutation tests or the fast-follow flow.** (**AC6**, **AC12**)
- **No change to the default path or the trivial path for tasks not routed prototype-first.** (**AC6**)
- **No new dispatch axis, status flag, role file, human gate or checker; no `bin/`, `templates/`, `tests/` or `.github/` edit.** (**AC10**, **AC12**)
- **No mechanical enforcement of the one-run bound or the stop condition.** It is prose and disclosed (D6). (info-only)
- **Not addressed here** (deferred by the issue): freeze weight, a default review-round cap, background processes left by `engineer`. (info-only)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no behaviour verification of a mechanism this task does not touch.** The class is `no-mechanism`. Every criterion is a string presence or absence read, a byte-scoped diff, a checker's exit code, or a records-line existence check. (info-only)
- **This task runs no prototype and writes no findings record.** (**AC12**: no `prototype-findings-*` path is allowed)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Temporary files go under `$TMPDIR` and are left there.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **File existence first.** Every line that reads a file first asserts that the file is non-empty.
- **The base.** Where a line reads a base blob, `<base>` is `git merge-base` of `develop` (local branch, else `refs/remotes/origin/develop`) and HEAD, spelled identically in **AC6**, **AC7** and **AC12**. All three are **merge-point-scoped and expected to go stale** after merge; do not widen the base.
- **Phrases are one physical line.** Every multi-word phrase a line matches is matched within one line.

- [ ] **AC1** (D1; D2.) `agents/tech-lead.md` carries the routing rule and the prototype step.
  - **The rule.** In `## Rules` (from that heading to the next `## ` line), exactly one line contains all of `prototype-first`, `cannot be written as testable statements until something is run once`, `trivial`, `operator-authored` and `prototype-findings-`.
  - **The step.** In `## Output format` (from that heading to the `## Rules` heading), a line contains `[engineer — prototype mode]`, and that line contains `INCLUDE ONLY`, `questions`, `stop condition` and `<slug>`.

  That the trigger axis is distinct from the task-aptitude branch, and that the rule makes the trivial path exclusive and operator-authored compatible, is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; F=agents/tech-lead.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac1.XXXXXX") || exit 1; test "$(grep -cxF -- '## Rules' "$F")" = 1 || exit 1; test "$(grep -cxF -- '## Output format' "$F")" = 1 || exit 1; awk '$0=="## Rules"{f=1;next} f&&/^## /{exit} f' "$F" > "$T/r" || exit 1; awk '$0=="## Output format"{f=1;next} $0=="## Rules"{exit} f' "$F" > "$T/o" || exit 1; test -s "$T/r" || exit 1; test -s "$T/o" || exit 1; awk -v a='prototype-first' -v b='cannot be written as testable statements until something is run once' -v c='trivial' -v d='operator-authored' -v e='prototype-findings-' 'index($0,a)&&index($0,b)&&index($0,c)&&index($0,d)&&index($0,e){n++} END{exit (n==1)?0:1}' "$T/r" || { rc=1; echo 'routing rule line missing or repeated'; }; grep -F -- '[engineer — prototype mode]' "$T/o" > "$T/s"; test -s "$T/s" || { rc=1; echo 'prototype step missing from the output format'; }; for s in 'INCLUDE ONLY' 'questions' 'stop condition' '<slug>'; do grep -qF -- "$s" "$T/s" || { rc=1; printf 'step line missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC2** (D3; D4.) `agents/engineer.md` carries exactly one `## Prototype mode` heading, placed before the first `<!-- BEGIN prompt-block:` line. The section (from that heading to the next `## ` line or generated block) contains:
  - `$TMPDIR` and `git clone --shared`;
  - `prototype-findings-` and the five section names `## Questions`, `## What was run`, `## Findings`, `## Still unknown` and `## Not for shipping`, written mid-line;
  - `every question has a measured answer or is declared unanswerable` and `one prototype run per task`;
  - `BLOCKED` and `not writable`;
  - `never shipped as the implementation`;
  - `never commits`, `no board flag`, `no push` and `no recursive deletion`;
  - `<scratch>`, `<repo-root>` and `check-pii-shapes`.

  That the section overrides the `docs/specs/` edit rule for exactly the findings record, and for nothing else, is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; F=agents/engineer.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac2.XXXXXX") || exit 1; test "$(grep -cxF -- '## Prototype mode' "$F")" = 1 || { echo 'heading count is not 1'; exit 1; }; h=$(grep -nxF -- '## Prototype mode' "$F" | cut -d: -f1); p=$(grep -n '^<!-- BEGIN prompt-block:' "$F" | head -n 1 | cut -d: -f1); test -n "$h" || exit 1; test -n "$p" || exit 1; test "$h" -lt "$p" || { rc=1; echo 'section is not above the first generated block'; }; awk '$0=="## Prototype mode"{f=1;next} f&&/^## /{exit} f&&/^<!-- BEGIN prompt-block:/{exit} f' "$F" > "$T/s" || exit 1; test -s "$T/s" || exit 1; for s in '$TMPDIR' 'git clone --shared' 'prototype-findings-' '## Questions' '## What was run' '## Findings' '## Still unknown' '## Not for shipping' 'every question has a measured answer or is declared unanswerable' 'one prototype run per task' 'BLOCKED' 'not writable' 'never shipped as the implementation' 'never commits' 'no board flag' 'no push' 'no recursive deletion' '<scratch>' '<repo-root>' 'check-pii-shapes'; do grep -qF -- "$s" "$T/s" || { rc=1; printf 'missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC3** (D4.) `agents/pm-spec.md`'s `## Rules` section (from that heading to the next `## ` line, above the first generated block) contains `prototype-findings-`, `- prototype-first:`, `- prototype-findings:`, `## Summarized sources`, `measured by the prototype run`, `absent or empty` and `BLOCKED`. That a missing or empty record on a prototype-first route stops `pm-spec` instead of letting it write the spec is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; F=agents/pm-spec.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac3.XXXXXX") || exit 1; test "$(grep -cxF -- '## Rules' "$F")" = 1 || exit 1; awk '$0=="## Rules"{f=1;next} f&&/^## /{exit} f' "$F" > "$T/r" || exit 1; test -s "$T/r" || exit 1; for s in 'prototype-findings-' '- prototype-first:' '- prototype-findings:' '## Summarized sources' 'measured by the prototype run' 'absent or empty' 'BLOCKED'; do grep -qF -- "$s" "$T/r" || { rc=1; printf 'Rules section missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC4** (D1; D3; D4.) `skills/run/SKILL.md` step 1 (from the `1. **Plan**` line to the `2. **Specify**` line) contains `prototype-first`, `prototype mode`, `$TMPDIR`, `--span prototype --phase plan`, `never given the scratch path`, `no-task.md`, `prototype-findings-`, `one prototype run per task`, `BLOCKED` and `commits the findings record`. That the branch sits after the Routing Map and before Specify, and leaves the trivial branch's wording intact, is a QA and review reading item (**AC6** pins the base lines).
  - check: rc=0; export LC_ALL=C; K=skills/run/SKILL.md; test -s "$K" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac4.XXXXXX") || exit 1; test "$(grep -c '^1\. \*\*Plan\*\*' "$K")" = 1 || exit 1; test "$(grep -c '^2\. \*\*Specify\*\*' "$K")" = 1 || exit 1; awk '/^1\. \*\*Plan\*\*/{f=1} /^2\. \*\*Specify\*\*/{exit} f' "$K" > "$T/s1" || exit 1; test -s "$T/s1" || exit 1; for s in 'prototype-first' 'prototype mode' '$TMPDIR' '--span prototype --phase plan' 'never given the scratch path' 'no-task.md' 'prototype-findings-' 'one prototype run per task' 'BLOCKED' 'commits the findings record'; do grep -qF -- "$s" "$T/s1" || { rc=1; printf 'step 1 missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC5** (D7; droppable first.) Item (2) is stated on both sides.
  - **`pm-spec` side.** In `agents/pm-spec.md`'s `## Rules` section, a line contains `no interventions occurred`, `only if the file is absent`, `Interventions dir` and `BEGIN interventions`.
  - **Orchestrator side.** `skills/run/SKILL.md` step 2 (from the `2. **Specify**` line to the next numbered step line) contains `Interventions dir:` and `--get interventions`.

  That the bullet covers full, trivial and conformance-formatter modes, never overwrites, and leaves the orchestrator as the only entry producer is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; F=agents/pm-spec.md; K=skills/run/SKILL.md; test -s "$F" || exit 1; test -s "$K" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac5.XXXXXX") || exit 1; test "$(grep -cxF -- '## Rules' "$F")" = 1 || exit 1; test "$(grep -c '^2\. \*\*Specify\*\*' "$K")" = 1 || exit 1; awk '$0=="## Rules"{f=1;next} f&&/^## /{exit} f' "$F" > "$T/r" || exit 1; awk '/^2\. \*\*Specify\*\*/{f=1;next} f&&/^[0-9]\. /{exit} f' "$K" > "$T/s2" || exit 1; test -s "$T/r" || exit 1; test -s "$T/s2" || exit 1; awk -v a='no interventions occurred' -v b='only if the file is absent' -v c='Interventions dir' -v d='BEGIN interventions' 'index($0,a)&&index($0,b)&&index($0,c)&&index($0,d){n++} END{exit (n>=1)?0:1}' "$T/r" || { rc=1; echo 'pm-spec interventions-file line missing'; }; for s in 'Interventions dir:' '--get interventions'; do grep -qF -- "$s" "$T/s2" || { rc=1; printf 'step 2 missing %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC6** (D5; D9; never-dropped.) Nothing existing moves.
  - **Every base line kept.** For each of `agents/tech-lead.md`, `agents/engineer.md`, `agents/pm-spec.md`, `skills/run/SKILL.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `docs/workflow.md`, `docs/workflow.ja.md`, `README.md` and `README.ja.md`, every line of the `<base>` blob occurs verbatim as a whole line in the working file.
  - **Generated spans unchanged.** In each of the three agent files, the span from the first `<!-- BEGIN prompt-block:` line to end of file is byte-identical to base.
  - **Task-aptitude section unchanged.** In `skills/run/SKILL.md`, the section from `## When the full loop fits (task aptitude)` to the first line starting `**Step 0` is byte-identical to base.
  - **Prompt sync.** `bash bin/check-prompt-sync.sh` exits `0`.
  - **Positive control.** `<base>` resolves to a commit, and every base blob and extracted span is non-empty.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac6.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; for F in agents/tech-lead.md agents/engineer.md agents/pm-spec.md skills/run/SKILL.md docs/adopting.md docs/adopting.ja.md docs/workflow.md docs/workflow.ja.md README.md README.ja.md; do test -s "$F" || exit 1; git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; grep -vxFf "$F" "$T/b" > "$T/gone"; r=$?; test "$r" = 1 || { rc=1; printf 'base line removed or altered in %s (grep rc %s)\n' "$F" "$r"; }; done; for F in agents/tech-lead.md agents/engineer.md agents/pm-spec.md; do git show "$B:$F" > "$T/b" || exit 1; awk '/^<!-- BEGIN prompt-block:/{f=1} f' "$T/b" > "$T/bg"; awk '/^<!-- BEGIN prompt-block:/{f=1} f' "$F" > "$T/hg"; test -s "$T/bg" || exit 1; test -s "$T/hg" || exit 1; cmp -s "$T/bg" "$T/hg" || { rc=1; printf 'generated span moved in %s\n' "$F"; }; done; K=skills/run/SKILL.md; git show "$B:$K" > "$T/kb" || exit 1; awk '$0=="## When the full loop fits (task aptitude)"{f=1} index($0,"**Step 0")==1{exit} f' "$T/kb" > "$T/ab"; awk '$0=="## When the full loop fits (task aptitude)"{f=1} index($0,"**Step 0")==1{exit} f' "$K" > "$T/ah"; test -s "$T/ab" || exit 1; test -s "$T/ah" || exit 1; cmp -s "$T/ab" "$T/ah" || { rc=1; echo 'task-aptitude section changed'; }; test -s bin/check-prompt-sync.sh || exit 1; bash bin/check-prompt-sync.sh > "$T/ps" 2>&1 || { rc=1; cat "$T/ps"; }; test "$rc" -eq 0

- [ ] **AC7** (D2; D3; D4; D6; D8.) Adopter-facing documentation lands in both adopting guides, inside `## How to run` (EN) and `## 実行方法` (JA), each read from its heading to the next `## ` line. Each heading occurs once.
  - **EN section** contains `prototype-first`, `prototype-findings-`, `$TMPDIR`, `- prototype-first:`, `cannot be written as testable statements until something is run once`, `the prototype output is never shipped as the implementation`, `the bound is prose, not a checker` and `one prototype run per task`.
  - **JA section** contains `prototype-first`, `prototype-findings-`, `$TMPDIR`, `- prototype-first:`, `一度実行するまで受け入れ基準をテスト可能な文として書けない`, `プロトタイプの出力は実装として出荷されない` and `この上限は文章であってチェッカーではない`.
  - **Heading counts.** Each file's count of `^## ` lines equals its count at `<base>`, and the two counts are equal.

  That EN and JA state the same conditions is a QA and review reading item.
  - adopter-surface: docs/adopting.md (`## How to run`) and docs/adopting.ja.md (`## 実行方法`) — the trigger, the scratch location, the findings record and its board lines, never shipped, the prose-only bound. docs/workflow.md and docs/workflow.ja.md — a phase-shortcut table row (**AC8**). README.md and README.ja.md — the conditional `[Prototype]` line in the phase flow (**AC8**).
  - check: rc=0; export LC_ALL=C; A=docs/adopting.md; J=docs/adopting.ja.md; HA='## How to run'; HJ='## 実行方法'; test -s "$A" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac7.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test "$(grep -cxF -- "$HA" "$A")" = 1 || rc=1; test "$(grep -cxF -- "$HJ" "$J")" = 1 || rc=1; awk -v h="$HA" '$0==h{f=1;next} f&&/^## /{exit} f' "$A" > "$T/en" || exit 1; awk -v h="$HJ" '$0==h{f=1;next} f&&/^## /{exit} f' "$J" > "$T/ja" || exit 1; test -s "$T/en" || exit 1; test -s "$T/ja" || exit 1; for s in 'prototype-first' 'prototype-findings-' '$TMPDIR' '- prototype-first:' 'cannot be written as testable statements until something is run once' 'the prototype output is never shipped as the implementation' 'the bound is prose, not a checker' 'one prototype run per task'; do grep -qF -- "$s" "$T/en" || { rc=1; printf 'EN section missing %s\n' "$s"; }; done; for s in 'prototype-first' 'prototype-findings-' '$TMPDIR' '- prototype-first:' '一度実行するまで受け入れ基準をテスト可能な文として書けない' 'プロトタイプの出力は実装として出荷されない' 'この上限は文章であってチェッカーではない'; do grep -qF -- "$s" "$T/ja" || { rc=1; printf 'JA section missing %s\n' "$s"; }; done; for F in "$A" "$J"; do git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; test "$(grep -c '^## ' "$T/b")" = "$(grep -c '^## ' "$F")" || { rc=1; printf 'heading count changed in %s\n' "$F"; }; done; test "$(grep -c '^## ' "$A")" = "$(grep -c '^## ' "$J")" || { rc=1; echo 'EN and JA heading counts differ'; }; test "$rc" -eq 0

- [ ] **AC8** (D8.) The workflow tables and the READMEs name the route. Each section below is read from its heading to the next `## ` line, and each heading occurs once.
  - **Workflow.** The `docs/workflow.md` section `## When to skip phases` and the `docs/workflow.ja.md` section `## フェーズをスキップしてよい場面` each contain `prototype-first` and `prototype-findings-`.
  - **README.** The `README.md` section `## Phase flow` and the `README.ja.md` section `## フェーズフロー` each contain `[Prototype]` and `prototype-first`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac8.XXXXXX") || exit 1; sec() { test -s "$1" || return 2; test "$(grep -cxF -- "$2" "$1")" = 1 || return 2; awk -v h="$2" '$0==h{f=1;next} f&&/^## /{exit} f' "$1" > "$T/s" || return 2; test -s "$T/s" || return 2; shift 2; for s in "$@"; do grep -qF -- "$s" "$T/s" || { printf 'missing %s\n' "$s"; return 1; }; done; return 0; }; sec docs/workflow.md '## When to skip phases' 'prototype-first' 'prototype-findings-' || { rc=1; echo 'in docs/workflow.md'; }; sec docs/workflow.ja.md '## フェーズをスキップしてよい場面' 'prototype-first' 'prototype-findings-' || { rc=1; echo 'in docs/workflow.ja.md'; }; sec README.md '## Phase flow' '[Prototype]' 'prototype-first' || { rc=1; echo 'in README.md'; }; sec README.ja.md '## フェーズフロー' '[Prototype]' 'prototype-first' || { rc=1; echo 'in README.ja.md'; }; test "$rc" -eq 0

- [ ] **AC9** (D2; D3; D4; adopter-side generated agents.) A fresh generation of the Codex agents for `tech-lead`, `engineer` and `pm-spec` into a scratch out-dir exits `0`, and:
  - `shell-team-tech-lead.toml` contains `prototype-first` and `cannot be written as testable statements until something is run once`;
  - `shell-team-engineer.toml` contains `Prototype mode` and `one prototype run per task`;
  - `shell-team-pm-spec.toml` contains `measured by the prototype run`.

  This reads no gitignored `.codex/agents`.
  - check: rc=0; export LC_ALL=C; G=bin/gen-codex-agents.sh; test -s "$G" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac9.XXXXXX") || exit 1; bash "$G" --root "$(pwd)" --out-dir "$T/out" --roles "tech-lead engineer pm-spec" > "$T/g" 2>&1 || { cat "$T/g"; exit 1; }; for p in 'tech-lead|prototype-first' 'tech-lead|cannot be written as testable statements until something is run once' 'engineer|Prototype mode' 'engineer|one prototype run per task' 'pm-spec|measured by the prototype run'; do r=${p%%|*}; s=${p#*|}; f="$T/out/shell-team-$r.toml"; test -s "$f" || { rc=1; printf 'not generated: %s\n' "$f"; continue; }; grep -qF -- "$s" "$f" || { rc=1; printf '%s missing %s\n' "$r" "$s"; }; done; test "$rc" -eq 0

- [ ] **AC10** (Negative; D5.) No new dispatch axis or status flag is introduced anywhere operational.
  - **Absence.** A tracked-content search of `agents`, `skills`, `docs`, `bin`, `templates`, `README.md` and `README.ja.md` for `dispatch(-reflection)?: prototype` or `READY_FOR_PROTO` matches nothing; `git grep` exits `1`, which is distinct from an error.
  - **Positive control.** The same search for `prototype-first` in `agents` and `skills` exits `0`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac10.XXXXXX") || exit 1; git grep -n -E -e 'dispatch(-reflection)?: prototype' -e 'READY_FOR_PROTO' -- agents skills docs bin templates README.md README.ja.md > "$T/n"; r=$?; test "$r" = 1 || { rc=1; printf 'absence search rc %s\n' "$r"; cat "$T/n"; }; git grep -q -F -e 'prototype-first' -- agents skills; r=$?; test "$r" = 0 || { rc=1; printf 'positive control rc %s\n' "$r"; }; test "$rc" -eq 0

- [ ] **AC11** The records conform:
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams;
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`;
  - `bash bin/check-interventions.sh --task T-1202` on `<interventions dir>/T-1202.md`, resolved through `bin/team-paths.sh --get interventions`, exits `0`.

  **Positive control.** Each input file is asserted non-empty first.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac11.XXXXXX") || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1202-prototype-first-entry.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || { rc=1; cat "$T/e"; }; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || { rc=1; cat "$T/h"; }; ID=$(bash bin/team-paths.sh --get interventions) || exit 1; IV="$ID/T-1202.md"; test -s "$IV" || exit 1; bash bin/check-interventions.sh --task T-1202 "$IV" > "$T/i" 2>&1 || { rc=1; cat "$T/i"; }; test "$rc" -eq 0

- [ ] **AC12** (D5; D9; never-dropped.) Scope lock. **Merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed: `git diff --no-renames --name-only <base>...HEAD`, `git diff --no-renames --cached --name-only`, `git diff --no-renames --name-only` and `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `agents/engineer.md`.
  - **Allowed members.**
    - Prose: `agents/tech-lead.md`, `agents/engineer.md`, `agents/pm-spec.md`, `skills/run/SKILL.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `docs/workflow.md`, `docs/workflow.ja.md`, `README.md` and `README.ja.md`.
    - This task's records: `.shell-team/specs/T-1202-prototype-first-entry.md`, `.shell-team/provenance/T-1202.md`, `.shell-team/interventions/T-1202.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1202.md`, `.shell-team/reviews/T-1202-drift.md`, raw captures `.shell-team/reviews/T-1202-<stem>.{txt,jsonl,json}`, `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - **Outside.** Anything under `bin/`, `templates/`, `tests/` or `.github/`, any other agent or skill file, `CONTRIBUTING.md`, and any `prototype-findings-*` file.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1202-ac12.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF agents/engineer.md "$T/s" || { rc=1; echo 'positive control: agents/engineer.md not in the set'; }; grep -vxE 'agents/(tech-lead|engineer|pm-spec)\.md|skills/run/SKILL\.md|docs/(adopting|workflow)(\.ja)?\.md|README(\.ja)?\.md|\.shell-team/(specs/T-1202-prototype-first-entry\.md|provenance/T-1202\.md|interventions/(T-1202|no-task)\.md|reviews/T-1202(-drift)?\.md|reviews/T-1202-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || { rc=1; cat "$T/bad"; }; test "$rc" -eq 0

- [ ] **AC13** The CI workflow `.github/workflows/check-handoff.yml` is green on the pull request.
  - above-ceiling: the coordinating session, after the push and before the sprint batch GO, records the check run's result on the board. QA reports this criterion as `SKIP`.

- [ ] **AC14** (Goal metric; post-release.) In an adopter repository, one task routed prototype-first runs inside the loop with 0 re-freezes, 0 bypasses (no work moved out of the loop), and at most 2 host turns.
  - above-ceiling: the operator, after v2.11.0 ships, measures this in an adopter repository and reports it at the following retro. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **Routing outcomes at Plan.**
   - The trigger fires: an external generator's length limit, a runtime's measured limit, or a tool failure mode documented nowhere readable. Route prototype-first.
   - The trigger does not fire. The default path is unchanged.
   - A trivial task. The trivial path applies, and never together with prototype-first.
   - Prototype-first combined with `specify — operator-authored`. The author reads the findings record in place of `pm-spec`'s full-mode authoring.
2. **The scratch location.**
   - `$TMPDIR` set and writable.
   - `$TMPDIR` unset: the platform's temp default.
   - The location not writable: `BLOCKED` with the error verbatim.
   - Scratch as an empty directory, or as a `git clone --shared` of the repository.
3. **The findings record.**
   - Present with all five sections.
   - Present with some questions under `## Still unknown`.
   - Absent or empty on a prototype-first route: `pm-spec` stops `BLOCKED`.
   - The default layout (`.shell-team/specs/`) and the legacy layout (`docs/specs/`).
4. **Record mode.** Tracked: the findings record and the interventions file are committed by the orchestrator. Local: both are written and never committed.
5. **Item (2), the interventions file.**
   - Absent when `pm-spec` creates the entry, in full, trivial and conformance-formatter modes: created with the zero-entry record.
   - Already present, for example an entry the orchestrator copied in from `no-task.md`: left untouched.
6. **The prose surfaces.**
   - One-line bullets in `agents/*.md` and `skills/run/SKILL.md`.
   - Hard-wrapped and one-line paragraphs in the adopting guides.
   - Markdown table rows in the workflow docs.
   - A code-block line in the READMEs.
   - Japanese text with machine tokens in English.
7. **Hosts.**
   - Claude Code.
   - Codex CLI, where the role bodies reach the agents through `gen-codex-agents.sh`.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **A second prototype run inside one task, or a prototype that keeps working past its stop condition.** The bound is prose (D6). Only the telemetry span and the findings record make it observable, and no checker enforces it.
2. **A prototype that needs network, credentials or a sandbox grant the host lacks.** It stops `BLOCKED`. The host's environment is never changed, and nothing beyond that stop is protected.
3. **A dangling symlink, a directory or an unreadable file at the interventions path.** `pm-spec` has no shell and cannot observe a link's type. Item (2) protects only the absent and present-regular-file cases. At close-out, `bin/close-out.sh:421-424` still refuses each of them as no readable record.
4. **Two concurrent tasks choosing the same findings `<slug>`.**
5. **A `$TEAM_INTERVENTIONS_DIR` override that differs from `team-paths.sh --get interventions`.** D7 uses the resolver's value only.
6. **A findings record whose evidence cannot be reproduced at the freeze sweep**, for example a paid or rate-limited generator. The finding stays labelled "measured by the prototype run" and is not re-measured.

<!-- END intent-block: T-1202 -->

## Verdict scope

- **Consumer.** Adopters (the docs and the new Plan route), and every later orchestrator, `tech-lead`, `engineer` and `pm-spec` that executes the shipped prompt text. Review depth is shipped-norm depth for the prose. It covers four things:
  - consistency across the four role and skill surfaces and the six docs;
  - the write boundary of prototype mode;
  - that nothing in the new branch bypasses a gate;
  - that the default and trivial paths read unchanged.
- **What a check line proves.** It proves the presence of fixed tokens in the named sections, that no base line was lost, the generated spans, the generated Codex agents' content, the absence of a new axis or flag, and the exit codes of the named scripts. It never proves that the prose says what D1–D7 require; that is a reading item for QA and review.
- **Briefing.** Every review briefing names the class `no-mechanism` and what it rules out: no full-population sweep, no whole CI-equivalent re-run, and no behaviour verification of an unchanged mechanism.

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | The prototype-first branch sits in step 1, after the Routing Map and before Specify (D1) | **AC4**; placement is a reading item |
| 2 | Routing trigger, distinct axis from task aptitude (D2) | **AC1**; **AC6** keeps `:9-16` byte-identical |
| 3 | Exclusive with the trivial path, compatible with operator-authored (D2) | **AC1** (tokens on the rule line); meaning is a reading item |
| 4 | Brief carries questions, stop condition, slug (D2) | **AC1** |
| 5 | `engineer` prototype mode runs it, under `$TMPDIR`, empty dir or `git clone --shared` (D3) | **AC2**, **AC4** |
| 6 | Stop condition; one run per task; second run goes back to `tech-lead` (D3) | **AC2**, **AC4**, **AC7** |
| 7 | Write boundary: one record, no commit, no flag, no branch or push, no recursive deletion, scratch left (D3) | **AC2** |
| 8 | Unwritable scratch: `BLOCKED` verbatim, host environment never changed (D3) | **AC2**, **AC4** |
| 9 | Output never shipped as the implementation (D3) | **AC2**, **AC7** |
| 10 | Telemetry span `--span prototype --phase plan` (D3) | **AC4** |
| 11 | QA never runs it; the implementation `engineer` never gets the scratch path (D3) | **AC4** (`never given the scratch path`); the QA half is info-only (not promoted to AC): an absence of an instruction, which no added line can show and which **AC6** plus review reading cover |
| 12 | Plan-phase interventions to `no-task.md`, copied in under the existing rule (D3) | **AC4** |
| 13 | Findings record path, not task-id-prefixed (D4) | **AC2**, **AC3**, **AC4**, **AC7**, **AC8** (`prototype-findings-`); **AC12** forbids such a file in this task |
| 14 | Five fixed sections (D4) | **AC2** |
| 15 | Orchestrator commits the record in tracked mode, never in local mode (D4) | **AC4** (`commits the findings record`); the local half is a reading item |
| 16 | `pm-spec` reads it, lists it, labels findings in Assumptions (D4) | **AC3**, **AC9** |
| 17 | Board lines `- prototype-first:` / `- prototype-findings:` (D4) | **AC3**, **AC7** |
| 18 | Fail closed on an absent or empty record (D4) | **AC3** |
| 19 | No new axis, flag, role, gate, `bin/`/`templates/`/`tests/`/`.github/` edit (D5) | **AC10**, **AC12** |
| 20 | The bound is prose and disclosed (D6) | **AC7** (EN and JA anchors) |
| 21 | Item (2): sentinel file at entry creation, all modes, only if absent, never overwrite (D7) | **AC5**; modes and never-overwrite are reading items |
| 22 | The orchestrator passes `Interventions dir:` (D7) | **AC5** |
| 23 | The orchestrator stays the only entry producer; replace-the-sentinel rule unchanged (D7) | **AC6** (`:42`, `:99` lines kept); reading item |
| 24 | Docs in the adopting guides, no new heading (D8) | **AC7** |
| 25 | Workflow table rows and README phase-flow line (D8) | **AC8** |
| 26 | Every base line kept, generated spans and task-aptitude section unchanged (D9) | **AC6** |
| 27 | Freeze, gates, fast-follow unchanged (Non-goals) | **AC6**, **AC12** |
| 28 | Generated Codex agents carry the new prose (Blast radius) | **AC9** |
| 29 | Deferred frictions not addressed (Non-goals) | info-only (not promoted to AC): an exclusion of scope with no artifact to check |
| 30 | No full sweep, no whole CI re-run (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 31 | This task runs no prototype (Non-goals) | **AC12** |
| 32 | Pre-commitment | info-only (not promoted to AC): a disposition, not a deliverable property |
| 33 | Records conform | **AC11** |
| 34 | CI green | **AC13** (above ceiling) |
| 35 | Goal metric | **AC14** (above ceiling) |
| 36 | Findings record normalization: `<scratch>`, `<repo-root>`, no home path or identity, `check-pii-shapes.sh --paths` before hand-back (D4) | **AC2** |
| 37 | Operator-authored: the author carries the read, list and label duties; `pm-spec` writes the board lines and fails closed (D4) | info-only (not promoted to AC): no fixed token distinguishes this mode's sentence from the pm-authored one; a QA and review reading item on **AC3**'s section |
| 38 | `$TMPDIR` unset falls back to the platform temp default (D3) | info-only (not promoted to AC): a parenthetical with no stable anchor; a reading item on **AC2**'s section |
| 39 | The interventions file is committed by the orchestrator in tracked mode and never in local mode (D7) | info-only (not promoted to AC): the commit is the existing orchestrator duty (`skills/run/SKILL.md:42`, `:90`); a reading item on **AC5** |

## Symmetry table

Marks: `present` (already true at base), `mirrored-now` (this task adds it), `not-applicable` (with reason).

| Surface | Routing trigger | Prototype run and bound | Findings record use | Item (2) |
|---|---|---|---|---|
| `agents/tech-lead.md` | mirrored-now (**AC1**) | mirrored-now: the brief in the step (**AC1**) | not-applicable: `tech-lead` does not read it | not-applicable: `tech-lead` creates no entry |
| `skills/run/SKILL.md` | mirrored-now: step 1 branch (**AC4**) | mirrored-now: dispatch, span, BLOCKED, separation (**AC4**) | mirrored-now: the commit (**AC4**) | mirrored-now: `Interventions dir:` (**AC5**) |
| `agents/engineer.md` | not-applicable: `engineer` does not route | mirrored-now (**AC2**) | mirrored-now: writes it (**AC2**) | not-applicable |
| `agents/pm-spec.md` | not-applicable: `pm-spec` does not route | not-applicable: `pm-spec` runs nothing | mirrored-now (**AC3**) | mirrored-now (**AC5**) |
| `agents/qa-verifier.md`, `agents/code-reviewer.md` | not-applicable: gates unchanged by design | not-applicable: QA never runs the prototype | not-applicable: the record is a `pm-spec` input. Findings relied on surface as labelled Assumptions, which the existing gates already read | not-applicable |
| Adopting EN / JA | mirrored-now (**AC7**) | mirrored-now (**AC7**) | mirrored-now (**AC7**) | not-applicable: an internal record detail, no adopter action |
| Workflow EN / JA, README EN / JA | mirrored-now (**AC8**) | named only | named only | not-applicable |

Singular-determiner read. The norm says "one prototype run per task" and "exactly one findings record". The cardinality one is intended: a second run is a re-plan. The questions are plural by design. Several prototype-first tasks in one sprint each get their own slug, and out-of-scope item 4 declines a slug collision.

## Shipped-docs inventory

| Document | Disposition | Ground |
|---|---|---|
| `docs/adopting.md`, `docs/adopting.ja.md` | this task | the adopter-facing description of how a run proceeds; `:176` / `:184` mention the trivial path only inside the T-1200 paragraph |
| `docs/workflow.md`, `docs/workflow.ja.md` | this task | the phase-shortcut table names the trivial route (`:46`) |
| `README.md`, `README.ja.md` | this task | the phase flow names the conditional `[Design]` stage; a conditional `[Prototype]` stage is the same kind of fact |
| `docs/usage-conversational.md` | unchanged | describes how a request enters the loop, not its routes |
| `CONTRIBUTING.md` | unchanged | maintainer workflow; no route described |
| `skills/goal/SKILL.md` | unchanged | a Grep for `trivial`, `tech-lead` and `Routing Map` found no match, so it restates no step-1 route |

## Blast radius

- **Class.** `no-mechanism`, so the analysis is read-set-scoped. This repository's contract declares `ci_runs_test_suites: yes` (`.shell-team/loops/shell-team.contract.yaml:59-61`), so a `mechanism` reclassification would also record a skip. The decision line is not written, because it applies to `mechanism`-class specs only.
- **Read set (norm-editing obligation).** The merged criteria whose `- check:` lines name an edited path by its literal bytes. The coordinating session embeds the block at the freeze run:
  - reproduce: bash bin/derive-populations.sh --label t1202-read-set --set "read=git grep -l -E '^[[:space:]]*- check:.*(agents/(tech-lead|engineer|pm-spec)[.]md|skills/run/SKILL[.]md|docs/(adopting|workflow)([.]ja)?[.]md|README([.]ja)?[.]md)' -- .shell-team/specs/*.md" --set "all=git ls-files -- .shell-team/specs/*.md"
- **Criteria this role read at the source and expects to move:**
  - T-1108 **AC3** and T-1200 **AC3**. Each requires `agents/pm-spec.md` to be byte-identical to its `git merge-base develop HEAD` blob, apart from the method item, with an equal line count. Adding the D4 and D7 lines turns both red on this branch. Both read a merge-base, so both are merge-point-scoped and were already bound to go stale once a later task edited that file; this is disclosed, not repaired.
  - T-1108 **AC2** stays green, because the new lines sit above the first generated block (**AC6**).
  - T-1200 **AC4**'s heading-count clauses stay green, because no `## ` heading is added to the adopting guides (**AC7**).
  - Other merged criteria that count lines or pin bytes of the edited files, through a merge-base read, are expected to move the same way. They are enumerated by the derivation, not by this role.
- **The indirection class.** Criteria that reach these files through a glob or a variable without the literal path are not re-run locally. This follows the operator ruling against running past specs' check lines locally (relayed), and it is a disclosed gap. CI (**AC13**) decides for the suites.
- **CI steps the diff reaches.** These were reverse-mapped by this role with a content Grep over `tests/**/*.sh` for `agents/(tech-lead|engineer|pm-spec).md`, `agents/*`, `skills/run`, `docs/adopting`, `docs/workflow` and `README`, and over the workflow's step names. The list is a lower bound, since a suite may also reach a file through a variable.
  - `tests/codex-agents/run.sh` and the `gen-codex-agents` dogfood step generate from the real `agents/*.md`.
  - `tests/check-invocation-path/run.sh` copies the real `agents/*.md` and asserts that `agents/pm-spec.md` carries no anchored `codex exec ` line. New prose must not open a line with `codex exec `.
  - `tests/check-model-pins/run.sh` copies the real `agents/*.md` (model pins; frontmatter unchanged).
  - `tests/install/run.sh` installs the real agent files (checksums and mtimes only).
  - `tests/check-prompt-sync/run.sh` (`:254`, the consumers `agents/engineer.md`, `agents/tech-lead.md`) and its dogfood step.
  - `tests/codex-skeleton-hygiene/run.sh:1637-1672`. The new `skills/run/SKILL.md` prose must name `check-interventions.sh` only in the `bash "<plugin root>/bin/…"` form and must not match `NEW_AC15`.
  - `tests/check-oversight/run.sh:268` and `tests/check-refreeze-grant/run.sh:238` read `skills/run/SKILL.md` for specific invocation strings this task does not add.
  - `tests/trial-recipe/run.sh` extracts the trial recipe and checks fence parity in `docs/adopting.md` / `.ja.md`. This task adds no fenced block and edits outside that section.
  - The `check-readme-version` suite and dogfood step read `README.md` and `README.ja.md`. The version badge is untouched.
  - The board, board-headings and interventions dogfood steps, `check-pii-shapes on the PR diff` and `check-commit-identity on the PR commits` are reached by the records.
- **Inapplicable steps, by name:**
  - every `shellcheck` step: no shell file changes;
  - the three loop-contract lint steps: they lint the shipped loop contracts, which this task does not edit;
  - `tests/check-adopter-docs/run.sh` and its dogfood step: fixtures and the T-1151 spec only; the `README.md` it names is an existence check;
  - `tests/gen-playbook-blocks/run.sh`: a fixture root;
  - `tests/setup`, `tests/check-setup`, `tests/local-mode`, `tests/team-commit` and `tests/land-worktree`: each `README` they name is a fixture file in a scratch repository;
  - `tests/machine-tokens`: reads `agents/scrum-master.md` only;
  - every other suite: the content Grep found no reference to an edited path.
- **Not run by this role.** This role has no shell. The engineer and QA run the reached suites through the repository's test recipe, and CI decides.
- **Adopter-side artefacts.**
  - Generated Codex agents (`<adopter>/.codex/agents/shell-team-<role>.toml`, gitignored, generated by `set up shell-team` / `update shell-team`) carry the old bodies until regenerated. The migration path is `update shell-team`. `check-codex-agents.sh` reports the drift; `check-setup.sh` checks presence only.
  - The stated limit: on a Codex CLI host whose agents are not regenerated, a prototype-first dispatch reaches an `engineer` without the `## Prototype mode` section.
  - No other adopter-side artefact is generated or renamed.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| (1) prototype-first entry (D1–D6, D8) | met: an adopter can newly keep try-first work in the loop | met: reachable on the default `/shell-team:run` path whenever `tech-lead` judges the trigger | MINOR | a new route an adopter can use |
| (2) interventions file at entry creation (D7) | not met: no new capability | met: every default run's `pm-spec` now writes the file | PATCH | removes a recurring QA red; no new capability |

Sprint tier: the maximum, MINOR. The release premise v2.11.0 is relayed from the approved planning.

## Assumptions

- **Measured by this role** (Read, Grep and Glob on the working tree, branch `feature/795-prototype-entry`, status clean at session start):
  - every cited line in Summarized sources, and its content;
  - the relayed Routing Map anchors, which were re-read and hold:
    - `bin/check-durability.sh:76-83`, `bin/close-out.sh:292-297`, `:412-419`, `bin/check-entry-mode.sh:471`, `bin/check-handoff.sh:37-45` and `skills/run/SKILL.md:9-16`, `:42`, `:99`;
    - the `design-note-T-NNNN.md` precedent (`.shell-team/specs/design-note-T-1012.md` exists);
  - one finding about the relayed shipped-docs list. `docs/workflow.md:46` and `docs/workflow.ja.md:46` describe the trivial path directly. `docs/adopting.md:176` and `docs/adopting.ja.md:184` mention it only inside the T-1200 paragraph, as "unchanged". All four are still dispositioned `this-task`, because the route belongs in `## How to run`;
  - no file under `agents/`, `skills/`, `docs/adopting*`, `docs/workflow*`, `README*`, `templates/` or `bin/` contains `prototype` in any letter case, except two comments in `templates/loop-replay.html` that are unrelated and outside every token this spec matches;
  - nothing outside `.shell-team/` contains `prototype-first`, `prototype-findings`, `dispatch: prototype` or `READY_FOR_PROTO`;
  - `agents/pm-spec.md` contains neither `no interventions occurred` nor `Interventions dir`. `skills/run/SKILL.md` contains `no interventions occurred` at `:42` and `:99` only, both outside step 2;
  - `bin/log-run.sh` places no closed set on `--span` or `--phase`.
- **Own-coinage tokens**:
  - `prototype-first`, `prototype-findings-`, `- prototype-first:`, `- prototype-findings:`;
  - `[engineer — prototype mode]`, `## Prototype mode`, `--span prototype --phase plan`;
  - `one prototype run per task`, `never given the scratch path`, `commits the findings record`, `measured by the prototype run`, `Interventions dir:`;
  - the EN and JA doc anchors in **AC7**.
- **Borrowed tokens** (no zero-count premise at base is asserted for any of them; each is matched only inside a section this task adds to):
  - `no interventions occurred`;
  - `BEGIN interventions`;
  - `BLOCKED`;
  - `$TMPDIR`;
  - `git clone --shared`;
  - `trivial`;
  - `operator-authored`;
  - `## Summarized sources`.

  No criterion's verdict depends on a borrowed token's count at base: each one is required present in an added section whose own-coinage tokens are absent at base. So the freeze run records, per token, `git show "$B:<file>" | grep -c -F -- '<token>'` for the file each criterion reads, only as context.
- **Relayed, not measured by this role** (owner: the coordinating session):
  - the issue #795 body, including the adopter measurements: 16 tasks before work moved out, 16 `intent-ratified` lines, and the quoted orchestrating-session remark. No relayed figure appears in the intent block or in any required shipped wording;
  - the operator-approved planning: the sprint goal, the item classifications, v2.11.0 and the goal metric;
  - the branch point `develop` at `f501a8b6`;
  - the operator ruling behind the no-local-past-spec-run disclosure;
  - that T-1201 is skipped on purpose.
- **Freeze-run duties** (owner: the coordinating session). A false prediction routes back here as a broken check line.
  - **The base.** `<base>` resolves to the relayed `f501a8b6`; record the value.
  - **Own-coinage absence at base.** Read the base commit, not the working tree: `git grep -n -F -e 'prototype-first' -e 'prototype-findings' -e 'Interventions dir:' "$B" -- agents skills docs README.md README.ja.md` prints nothing (exit `1`).
  - **Before implementation.**
    - **AC1**, **AC2**, **AC3**, **AC4**, **AC5**, **AC7**, **AC8** and **AC9** red, because their tokens are absent.
    - **AC6** green, because nothing has been removed yet.
    - **AC10** red on its positive control only.
    - **AC11** green when the board entry and the interventions file are conformant.
    - **AC12** red on its positive control.
    - **AC13** and **AC14** `SKIP`.
  - **Specimen green.** In the scratch clone carrying the specimen implementation, all twelve check lines (**AC1**–**AC12**) run green. A line predicted red before implementation could be broken by an early `exit 1`, and only a green run on the specimen tells the two apart.
  - **AC9 premise.** `gen-codex-agents.sh --root "$(pwd)" --out-dir <scratch> --roles "tech-lead engineer pm-spec"` exits `0` in a plain checkout with no Codex install. If it does not, that is a broken check line, not a task defect; report it.
  - **Mutation probes.** The `no-mechanism` class requires them for the lines this task adds. In a scratch clone under `$TMPDIR`, after writing a specimen implementation:
    - drop `no recursive deletion` from the prototype section (**AC2** red);
    - move `## Prototype mode` below the first generated block (**AC2** red);
    - delete one base line of `docs/workflow.md` (**AC6** red);
    - change one character of the task-aptitude section (**AC6** red);
    - add a line `- dispatch: prototype — serial` to `skills/run/SKILL.md` (**AC10** red);
    - remove the JA prose-bound anchor (**AC7** red);
    - add a `## ` heading to `docs/adopting.md` (**AC7** red);
    - add a stray `prototype-findings-x.md` under the specs dir (**AC12** red).

## Open questions

None blocking.

## Notes for engineer

- **Add lines only, in every edited file** (**AC6**). Never edit or remove an existing line, including the trivial-path text at `skills/run/SKILL.md:57`, `agents/tech-lead.md:82` and the `**Trivial mode.**` bullet in `agents/pm-spec.md`.
- **Agent files.** All new text goes above the first `<!-- BEGIN prompt-block:` line. Never run a prompt-block regeneration.
- **`agents/tech-lead.md`.** Add one `## Rules` bullet holding the D2 trigger, the exclusivity with the trivial path, the compatibility with `operator-authored`, and the record name `prototype-findings-<slug>.md`, all on one line (**AC1**). Inside the `## Output format` code block, add one step line containing `[engineer — prototype mode]`, `INCLUDE ONLY …`, the `questions`, the `stop condition` and the `<slug>`.
- **`agents/engineer.md`.** Add a `## Prototype mode` section between `## Rules` and `## Record mode (T-1181)`. Name the five record sections mid-line (for example in backticks); a line that starts with `## ` ends the section **AC2** reads. State in it that it is the one exception to the `docs/specs/` edit rule, for the findings record only.
- **`agents/pm-spec.md`.** Add two `## Rules` bullets, the findings-record input (D4) and the interventions file (D7). The D7 bullet keeps `no interventions occurred`, `only if the file is absent`, `Interventions dir` and `BEGIN interventions` on one line.
- **`skills/run/SKILL.md`.** Add an indented sub-bullet in step 1 carrying the D1, D3 and D4 commit tokens, and one in step 2 that tells the orchestrator to prepend `Interventions dir: <team-paths.sh --get interventions output>` to `pm-spec`'s prompt. Do not open a line with `codex exec `.
- **Docs.**
  - Adopting guides: a bold-led paragraph inside `## How to run` / `## 実行方法`, with no new `## ` heading.
  - Workflow docs: one table row in `## When to skip phases` / `## フェーズをスキップしてよい場面`.
  - READMEs: one `[Prototype]` line in the phase-flow code block, between `[Plan]` and `[Specify]`, plus one sentence after the `[Design]` sentence.
  - Keep every matched phrase on one physical line, and keep machine tokens in English in the JA text.
- **Words the gates forbid.**
  - Never write `dispatch: prototype`, `dispatch-reflection: prototype` or `READY_FOR_PROTO` literally in any new prose (**AC10**).
  - In `skills/run/SKILL.md`, name `check-interventions.sh` only as `bash "<plugin root>/bin/check-interventions.sh"`, never as `bash bin/check-interventions.sh`.
  - Never write `interventions gate:AC<n>` or `route back through loop guard` (`tests/codex-skeleton-hygiene/run.sh:1546-1550`).
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **No private context.** Write no adopter, operator or workstation names and no host-local paths or tool names in any file.
