# The trivial path creates a minimal board entry and spec, so a trivial run passes the Implement-to-Validate seams and reaches READY_FOR_QA

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1167

**Branch**: `feature/655-trivial-skip-record-gates`, cut from `90a131a6` (the T-1166 branch tip; `.git/refs/heads/feature/655-trivial-skip-record-gates` and `.git/refs/heads/feature/654-codex-new-session` both read `90a131a6cc31d0e55ac8706db57da108832d9088`, and `.git/refs/remotes/origin/feature/654-codex-new-session` exists). Stacked: T-1166's PR #656 is open against `develop` and unmerged. The pull request targets `develop`.

## Problem

The run skill lets the orchestrator skip from Plan to Implement when `tech-lead` calls a task trivial. That path creates no board task. The Implement-to-Validate seam then requires records keyed by a board task id, and the provenance checker accepts only a `T-<digits>` marker. A trivial run therefore stops `BLOCKED` before Validate and never reaches `READY_FOR_QA`. The canon is issue #655. Its Problem and Expected sections were relayed verbatim by the coordinating session (this role cannot read the tracker) and are quoted here:

> ## Problem
> The run skill's Plan step lets the orchestrator skip to Implement when `tech-lead` calls the task trivial. That path has no board task, so the records use the reserved id `no-task`. But the Implement-to-Validate seam then requires the provenance gate, and `bin/check-provenance.sh` accepts only `<!-- BEGIN provenance: T-NNN -->` (`BEGIN_ANY_RE`, `T-[0-9]+` only). The interventions checker does accept `no-task`, but the skill does not give the orchestrator the exact file shape for a taskless run.
> Observed in a clean-install run on the Codex CLI host (shell-team 2.8.0): for the request "add `--version` to `hello.sh` and print `0.1.0`", `tech-lead` judged it trivial; the engineer implemented and committed; the orchestrator wrote `provenance/no-task.md` and `interventions/no-task.md` without markers; both checkers failed closed (structural); the run stopped `BLOCKED` before Validate, with no board row and no `READY_FOR_QA`. The same request on a Claude Code host took the full path (spec, board row) and reached `READY_FOR_MERGE`, so the defect only shows when the trivial path is chosen.
> An earlier run on the Codex CLI host also took the trivial path with id `no-task` and no board row. So the path is chosen in practice and is not a corner case.
>
> ## Expected
> A run that `tech-lead` calls trivial reaches `READY_FOR_QA` and then the two gates the loop requires, or the trivial skip is defined so that it cannot leave the loop unable to pass its own seams. Which of these, and what the board and records look like for such a run, is decided in the spec. Whatever is chosen is covered by a fixture, and the checkers keep failing closed on malformed input.

**Design decision (coordinating session, accepting `tech-lead`'s recommendation A; relayed).** The trivial path still creates a minimal board entry with a task id and a minimal spec, so every seam (T-073, T-075 provenance, T-1002 interventions, T-1048 durability, QA, the cross-provider review, close-out) runs unchanged. No `bin/` checker changes: each keeps its accepted shapes, and non-`T-<digits>` provenance and durability stay refused.

## Summarized sources

- GitHub issue #655 (Problem and Expected). **Relayed verbatim by the coordinating session; this role did not read it.** Quoted above. Distinctions carried over:
  - The defect fires **only on the trivial path**. The full path on the Claude Code host reached `READY_FOR_MERGE` for the same request.
  - The observed failure: marker-less `provenance/no-task.md` and `interventions/no-task.md`, both checkers failing closed (structural), stop before Validate, **no board row and no `READY_FOR_QA`**.
  - Expected allows **either** of two resolutions (reach `READY_FOR_QA` and both gates, **or** define the skip so it cannot leave the loop unable to pass its seams); the spec picks one and fixes what the board and records look like. **A fixture covers it**, and **the checkers keep failing closed on malformed input**.
- `skills/run/SKILL.md` (read `:1`–`:168`). Distinctions:
  - Step 1 `:45`: "If `tech-lead` says the task is trivial, you may skip to step 4 (Implement)." Nothing else in the skill defines the trivial path.
  - `:43`: phases run in order, and the board flag gates each advance.
  - `:32` (Interventions producer discipline): "use `no-task.md` when no board task is active" — the interventions file for a moment when no board task exists.
  - `:79` (durability barrier, Implement-to-Validate) and `:120` (durability barrier, pre-merge) each end: the checker refuses any non-`T-<digits>` `--task`, "a no-task run has no spec, provenance or review record to be durable by construction", "in a no-task flow this step is skipped rather than adapted".
  - `:80` (provenance gate): unconditional, fail-closed, file `tasks/provenance/<task-id>.md`.
  - `:81` (interventions gate): fail-closed, unconditional, and substitutes `no-task.md` / `--task no-task` "when no board task is active".
  - `:66`: the frozen-intent confirmation is skipped "entirely when the spec has no intent block".
  - `:76`: the engineer's edits "land directly on the current feature branch HEAD of your checkout". No step in the skill cuts a branch.
  - `:82`: the interventions entry template lines are `contain`-synced from `templates/prompt-blocks/interventions-classes.md` (`templates/prompt-blocks/registry.txt:41`), as is `:32`'s class list.
- `agents/pm-spec.md` `## Rules` `:65`: "If you find the request is actually trivial (one-line fix, typo), skip the full spec, just add a one-line entry to `tasks/todo.md` with `READY_FOR_ENG` directly." Distinction: today's trivial rule writes **no spec file**. The rule sits outside every marker block (the first `BEGIN prompt-block` marker is at `:145`).
- `agents/tech-lead.md`. Distinctions: `:82` "If the change is trivial (single typo, one-line fix), say so and recommend skipping the team workflow." `:66` (Routing Map template) "Spec: `docs/specs/<slug>.md` (if non-trivial)". Both outside every marker block (the first is at `:106`).
- `agents/engineer.md` `:14` (finds a task at `READY_FOR_ARCH` **or** `READY_FOR_ENG`) and `:45` (works on the current feature branch HEAD; no worktree by default).
- `bin/check-handoff.sh` (read `:1`–`:217`). Distinctions: `LINE_RE` (`:92`) requires `— spec: <path>.md` on every `- [ ]` line of `## Active`; it validates the **line shape and the flag vocabulary only** and never opens the spec path, so it does not check that the spec file exists. Indented continuation lines are never validated against `LINE_RE`. A board with no `## Active` heading validates nothing and exits `0`.
- `bin/check-provenance.sh` (read `:1`–`:254`). Distinctions: takes one positional file, derives the id from `BEGIN_ANY_RE='^<!-- BEGIN provenance: (T-[0-9]+) -->$'` (`:191`). A marker-less file and a `<!-- BEGIN provenance: no-task -->` file both find zero BEGIN markers → `structural`, exit `2` (`:206`–`:207`). The sentinel `no non-trivial decisions` alone is conformant.
- `bin/check-interventions.sh` (read `:1`–`:90`). Distinctions: the marker id is `T-<digits>` **or the reserved literal `no-task`** (`:32`–`:34`); `--task <id>` must equal the BEGIN id; absent markers → `structural` exit `2`; the sentinel `no interventions occurred` alone is conformant.
- `bin/check-durability.sh` (read `:1`–`:140`) and `templates/durability-records.txt`. Distinctions: `--task` shape `^T-[0-9]+$`, any other value `usage` exit `2` (`:80`–`:82`). The `implement` phase requires four records, each a blob at `--ref` matching the working file: the board, `specs/<task-id>-*.md` (exactly one match), `provenance/<task-id>.md`, `interventions/<task-id>.md` (registry `:42`–`:45`). A minimal spec named `<task-id>-<slug>.md` satisfies the `specs` row.
- `bin/close-out.sh` (read `:1`–`:112`, `:560`–`:670`). Distinctions: gates in order — pending fast-follow (only a literal `pending:`), dispatch grammar (**validate-if-present**: silent with no `- dispatch:` sub-bullet), interventions (required), elected spec review (**validate-if-present**), oversight (unconditional, silent under the shipped `autonomous` default), `- count:` grammar (validate-if-present), review-input fidelity (an absent record is "nothing to check yet"), source line (via `check-handoff.sh`), pre-flip (`READY_FOR_MERGE` required). **No gate reads `- entry-mode:`**; `bin/check-entry-mode.sh` is not invoked from close-out (`:64`–`:68`).
- `bin/check-acs.sh` (read `:1`–`:110` and `AC_RE` `:172`, `CANDIDATE_RE` `:185`, `CHECK_RE` `:193`, summary `:416`). Distinctions: no section heading and no intent block is required — only `- [ ] **ACn**` lines with indented `- check:` sub-bullets; check commands run from the caller's cwd; the summary `check-acs: N passed, N failed, …` goes to stdout; zero criteria is exit `2`.
- `agents/qa-verifier.md` `:66` and `agents/code-reviewer.md` `:238` (located by grep, not read in full). Distinction: each states a fallback for a spec with no intent block / no input-space definition, so a minimal spec does not by itself fail those gates. **Not fully verified by this role**; AC13 re-observes it on a real host.
- `docs/workflow.md` `## When to skip phases` `:46` ("Single-line typo or comment fix | `tech-lead` may skip directly to `engineer`") and `:48` ("Test-only change | Skip `pm-spec`"); `:175` (engineer works on the task's feature branch). `docs/workflow.ja.md` `:46` (same row, "`tech-lead` は直接 `engineer` へスキップしてよい") and `:48`.
- `templates/CLAUDE-routing-snippet.md` `:21` ("Trivial fix … → just do it; no loop needed"). Distinction: this is the main session's decision **not to start a loop at all** — no board, no seams — not the run skill's in-loop skip. It is outside this task.
- `.gitignore` `:39` (`.codex/agents` is ignored in this checkout, so no generated role file is tracked here).
- `templates/prompt-blocks/registry.txt` (read). Distinction: `skills/run/SKILL.md`, `agents/pm-spec.md` and `agents/tech-lead.md` are consumers of several `contain`/`marker` blocks, so `bin/check-prompt-sync.sh` reads all three.
- `CONTRIBUTING.md` `## What a version number encodes` (cited through T-1166's spec). Distinction: bug fixes are PATCH.

## Goal

<!-- BEGIN intent-block: T-1167 -->

- user-visible: yes — a run that `tech-lead` calls trivial now creates a minimal board entry and spec and reaches `READY_FOR_QA` and both gates on either host, instead of stopping `BLOCKED` before Validate; the run skill, the `pm-spec` and `tech-lead` definitions and the workflow guide state the new path.
- verification-class: mechanism — the diff changes the run skill's control flow (what the orchestrator does on the trivial path) and two agent definitions that `bin/gen-codex-agents.sh` compiles into the Codex CLI host's roles; no path under `bin/`, `tests/` or `templates/` changes.
- verification-ceiling: unit-and-static — **AC1**–**AC12** are settled in a plain checkout: they run the shipped, unchanged checkers against a temp git repository under `$TMPDIR`, read shipped files, compare against a base ref, or take a suite's or checker's exit code. **AC13**, a real trivial run on a clean install, sits above the ceiling.
- base-ref-discriminator: git merge-base "feature/654-codex-new-session" HEAD while the predecessor resolves as a local branch, git merge-base "refs/remotes/origin/feature/654-codex-new-session" HEAD while it resolves only as a remote-tracking ref, and git merge-base "develop" HEAD (or "refs/remotes/origin/develop" where only that ref resolves) once it resolves in neither — the arm selected by an explicit `git show-ref --verify --quiet` existence test against `refs/heads/feature/654-codex-new-session` and then `refs/remotes/origin/feature/654-codex-new-session`, never a `2>/dev/null ||` chain, and no 40-hex literal anywhere. Both namespaces carry the predecessor at authoring time. The only criterion reading a base-side blob is **AC9**.
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: agents/pm-spec.md — this-task
- shipped-docs: agents/tech-lead.md — this-task
- shipped-docs: docs/workflow.md — this-task
- shipped-docs: docs/workflow.ja.md — this-task

**Goal (one sentence).** When `tech-lead` calls a task trivial, the orchestrator invokes `pm-spec` in trivial mode, which creates a board entry with a real task id at `READY_FOR_ENG` and a minimal spec at `<specs dir>/<task-id>-<slug>.md`, and the run then goes to step 4 and passes every Implement-to-Validate seam, QA, the cross-provider review and close-out with that task id and the unchanged checkers; `no-task` is never used for a seam gate.

**Decisions frozen here** (each is promoted to a criterion):

1. **Run skill step 1.** "you may skip to step 4" is replaced by: invoke `pm-spec` in trivial mode, then go to step 4. The invocation itself names the shape `pm-spec` must produce (the entry at `READY_FOR_ENG`; the minimal spec with a `## Problem` paragraph and at least one acceptance criterion carrying a `- check:` line; no intent block), so a stale generated role on a Codex CLI host still gets the shape from the briefing. Step 2's freeze sweep, intent hash, Specify-seam gates and dispatch transcription do not run on this path; steps 4–7 run unchanged. (**AC4**)
2. **Seam gates always carry a task id.** The skill's interventions gate (T-1002) no longer offers the `no-task` substitution, and the two durability-barrier bullets (T-1048) no longer describe a no-task flow that skips them. The Interventions producer discipline keeps `no-task.md` for interventions recorded when no board task is active. (**AC5**)
3. **`pm-spec` trivial mode.** Its `## Rules` trivial line is replaced: in trivial mode it creates the board entry at `READY_FOR_ENG` with `- entry-mode: pm-authored` and a `- trivial-path: <tech-lead's one-line ground>` sub-bullet, and writes the minimal spec at `<task-id>-<slug>.md` (title, `**Task ID**:` line, `## Problem` paragraph, `## Acceptance criteria` with at least one criterion carrying a `- check:` line); no intent block, no freeze, and the Spec completion self-check does not apply. (**AC6**)
4. **The record shapes pass the unchanged checkers.** The worked example below — board entry, minimal spec, provenance, interventions — passes `check-handoff`, `check-provenance`, `check-interventions --task`, `check-durability --phase implement`, `check-acs` and, at `READY_FOR_MERGE`, `close-out`. (**AC1**)
5. **The checkers keep failing closed.** A marker-less `provenance/no-task.md` and a `no-task`-marked provenance file are refused `structural`; `check-durability --task no-task` is refused `usage`; a marker-less `interventions/no-task.md` is refused, and a marked one is conformant (the remaining scope of `no-task`). (**AC2**)
6. **No checker changes.** Nothing under `bin/` or `templates/` changes. (**AC9**)
7. **`tech-lead` alignment (droppable, second).** Its trivial rule says to route to `pm-spec` in trivial mode instead of recommending skipping the team workflow, and the Routing Map template's spec line no longer says "(if non-trivial)". (**AC7**)
8. **Workflow guide alignment (droppable, first).** The "Single-line typo or comment fix" row of `docs/workflow.md` / `.ja.md` names `pm-spec`'s trivial mode instead of a direct skip to `engineer`. (**AC8**)
9. **Pre-commitment** (AI self-discipline, recorded before the first round). Never-dropped: decisions 1–6. If any round finds a seam that a task-id trivial entry still cannot pass, or a finding can only be closed by widening a `bin/` checker's accepted shapes, the task stops and returns to planning — no patch round is added. Droppable, in this order: (1) decision 8, then (2) decision 7. Trigger: the same droppable component draws a QA `FAIL` or review `REQUEST_CHANGES` finding in two consecutive rounds. Disposition: the component's edit is reverted, its criterion is reported as dropped (goal N of M), and a follow-up issue carrying that round's findings is filed; the board records that issue as the doc's disposition in place of `this-task`.

**Worked example** (decision 4; the fixture in **AC1** builds exactly this, with fixture id `T-901`):

- Board entry, top of `## Active`:
  ```
  - [ ] **T-901** Add --version to hello.sh — `READY_FOR_ENG` — spec: .shell-team/specs/T-901-hello-version.md
    - entry-mode: pm-authored
    - trivial-path: tech-lead judged the task trivial (one flag, one printed line)
  ```
- Minimal spec `.shell-team/specs/T-901-hello-version.md`: a `# Add --version to hello.sh` title, `**Task ID**: T-901`, `## Problem` with one sentence, `## Acceptance criteria` with `- [ ] **AC1** bash hello.sh --version prints 0.1.0.` and its indented check line `test "$(bash hello.sh --version)" = 0.1.0`.
- `.shell-team/provenance/T-901.md`: the `T-901` provenance marker pair around `no non-trivial decisions` (or decision triples).
- `.shell-team/interventions/T-901.md`: the `T-901` interventions marker pair around `no interventions occurred` (or entries).

## Non-goals

- **No change to any `bin/` checker or to `templates/`**: accepted shapes, refusals and the durability registry stay byte-identical. (**AC9**)
- **No branch rule.** Neither path gains a branch-cutting step: the trivial path commits on whatever branch the checkout is on, exactly as the full path does today (`skills/run/SKILL.md` `:76`, `agents/engineer.md` `:45`). (info-only)
- **The main session's "no loop needed" routing** (`templates/CLAUDE-routing-snippet.md` `:21`) and the workflow guide's "Test-only change — Skip `pm-spec`" row are not changed. (**AC9** for the snippet; info-only for the row)
- **No new status flag, phase or gate.** The trivial entry enters at the existing `READY_FOR_ENG`. (**AC9**, **AC12**)
- **Real-host behaviour** is the sprint's step V re-measurement, not this task's verification. (**AC13**)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, writes only under `$TMPDIR` (temp directories are left in place, never removed), and contains no recursive delete. Fixtures export a temp `HOME` and `XDG_CONFIG_HOME`, set `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and unset every `TEAM_*` override the checkers honour. `k <tool> <args>` runs `bin/<tool>.sh` from the fixture repository and prints its exit status.

- [ ] **AC1** The worked example passes every record gate on the trivial path. A temp git repository carrying the worked example's board entry (flag `READY_FOR_QA`), minimal spec, `hello.sh`, provenance and interventions, committed, gives exit `0` from: `check-handoff.sh` on the board; `check-provenance.sh` on `provenance/T-901.md`; `check-interventions.sh --task T-901` on `interventions/T-901.md`; `check-durability.sh --phase implement --task T-901 --ref HEAD`; and `check-acs.sh` on the minimal spec, whose summary reads `1 passed, 0 failed`. Positive controls: the same spec with the expected version `9.9.9` makes `check-acs.sh` exit `1`, and a board whose `T-901` line lacks `— spec:` makes `check-handoff.sh` exit `1`. With the flag rewritten to `READY_FOR_MERGE` and committed, `close-out.sh --task T-901 --date 2026-10-02` exits `0`, `## Active` no longer names `T-901`, and `## Done` carries `**T-901**`.
  - check: rc=0; P=$(pwd -P); for f in check-handoff check-provenance check-interventions check-durability check-acs close-out team-paths; do test -s "$P/bin/$f.sh" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_INTERVENTIONS_DIR TEAM_REVIEWS_DIR TEAM_OVERSIGHT_BASE TEAM_RUNS_DIR; mkdir -p "$HOME" || exit 1; R="$T/r"; S=.shell-team; mkdir -p "$R/$S/specs" "$R/$S/provenance" "$R/$S/interventions" || exit 1; git -C "$R" init -q || exit 1; bd(){ printf '%s\n' '# Tasks' '' '## Active' '' "- [ ] **T-901** Add --version to hello.sh — \`$1\` — spec: $S/specs/T-901-hello-version.md" '  - entry-mode: pm-authored' '  - trivial-path: tech-lead judged the task trivial (one flag, one printed line)' '' '## Done' '' > "$R/$S/todo.md"; }; sp(){ printf '%s\n' '# Add --version to hello.sh' '' '**Task ID**: T-901' '' '## Problem' '' 'hello.sh has no --version flag; it should print 0.1.0.' '' '## Acceptance criteria' '' '- [ ] **AC1** bash hello.sh --version prints 0.1.0.' "  - check: test \"\$(bash hello.sh --version)\" = $1" > "$2"; }; bd READY_FOR_QA || rc=1; sp 0.1.0 "$R/$S/specs/T-901-hello-version.md" || rc=1; sp 9.9.9 "$T/bad.md" || rc=1; printf '%s\n' '#!/usr/bin/env bash' 'if [ "${1:-}" = --version ]; then echo 0.1.0; exit 0; fi' 'echo hello' > "$R/hello.sh" || rc=1; printf '%s\n' '<!-- BEGIN provenance: T-901 -->' 'no non-trivial decisions' '<!-- END provenance: T-901 -->' > "$R/$S/provenance/T-901.md" || rc=1; printf '%s\n' '<!-- BEGIN interventions: T-901 -->' 'no interventions occurred' '<!-- END interventions: T-901 -->' > "$R/$S/interventions/T-901.md" || rc=1; cm(){ git -C "$R" add -A && git -C "$R" -c user.email=t@example.com -c user.name=t commit -q -m "$1"; }; cm i || rc=1; k(){ (cd "$R" && bash "$P/bin/$1.sh" "${@:2}" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; test "$(k check-handoff "$S/todo.md")" = 0 || rc=1; test "$(k check-provenance "$S/provenance/T-901.md")" = 0 || rc=1; test "$(k check-interventions --task T-901 "$S/interventions/T-901.md")" = 0 || rc=1; test "$(k check-durability --phase implement --task T-901 --ref HEAD)" = 0 || rc=1; test "$(k check-acs "$S/specs/T-901-hello-version.md")" = 0 || rc=1; grep -qF '1 passed, 0 failed' "$T/o" || rc=1; test "$(k check-acs "$T/bad.md")" = 1 || rc=1; printf '%s\n' '## Active' '' '- [ ] **T-901** no spec path — `READY_FOR_QA`' > "$T/bb.md" || rc=1; test "$(k check-handoff "$T/bb.md")" = 1 || rc=1; bd READY_FOR_MERGE || rc=1; cm m || rc=1; test "$(k close-out --task T-901 --date 2026-10-02)" = 0 || rc=1; awk '/^## Active/{a=1;next} /^## /{a=0} a' "$R/$S/todo.md" > "$T/act"; grep -qF 'T-901' "$T/act"; g=$?; test "$g" -eq 1 || rc=1; awk '/^## Done/{d=1;next} /^## /{d=0} d' "$R/$S/todo.md" > "$T/done"; grep -qF '**T-901**' "$T/done" || rc=1; test "$rc" -eq 0

- [ ] **AC2** The checkers keep failing closed on taskless record shapes, and `no-task` keeps only its interventions scope. In a temp git repository with one commit: a provenance file holding only the sentinel, and one wrapped in `no-task` provenance markers, each make `check-provenance.sh` exit `2` with `structural` on stderr, while the same sentinel wrapped in `T-901` markers exits `0`. `check-durability.sh --phase implement --task no-task --ref HEAD` exits `2` with `usage` on stderr. `check-interventions.sh --task no-task` exits `2` on a marker-less `no-task.md` and `0` on one wrapped in `no-task` interventions markers.
  - check: rc=0; P=$(pwd -P); for f in check-provenance check-interventions check-durability; do test -s "$P/bin/$f.sh" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE TEAM_TODO TEAM_INTERVENTIONS_DIR TEAM_REVIEWS_DIR TEAM_OVERSIGHT_BASE TEAM_RUNS_DIR; mkdir -p "$HOME" || exit 1; R="$T/r"; S=.shell-team; mkdir -p "$R/$S/provenance" "$R/$S/interventions" || exit 1; git -C "$R" init -q || exit 1; printf 'x\n' > "$R/README" || exit 1; git -C "$R" add README && git -C "$R" -c user.email=t@example.com -c user.name=t commit -q -m i || exit 1; k(){ (cd "$R" && bash "$P/bin/$1.sh" "${@:2}" < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?"; }; F="$S/provenance/no-task.md"; printf 'no non-trivial decisions\n' > "$R/$F" || rc=1; test "$(k check-provenance "$F")" = 2 || rc=1; grep -qF structural "$T/e" || rc=1; printf '%s\n' '<!-- BEGIN provenance: no-task -->' 'no non-trivial decisions' '<!-- END provenance: no-task -->' > "$R/$F" || rc=1; test "$(k check-provenance "$F")" = 2 || rc=1; grep -qF structural "$T/e" || rc=1; printf '%s\n' '<!-- BEGIN provenance: T-901 -->' 'no non-trivial decisions' '<!-- END provenance: T-901 -->' > "$R/$S/provenance/T-901.md" || rc=1; test "$(k check-provenance "$S/provenance/T-901.md")" = 0 || rc=1; test "$(k check-durability --phase implement --task no-task --ref HEAD)" = 2 || rc=1; grep -qF usage "$T/e" || rc=1; I="$S/interventions/no-task.md"; printf 'no interventions occurred\n' > "$R/$I" || rc=1; test "$(k check-interventions --task no-task "$I")" = 2 || rc=1; printf '%s\n' '<!-- BEGIN interventions: no-task -->' 'no interventions occurred' '<!-- END interventions: no-task -->' > "$R/$I" || rc=1; test "$(k check-interventions --task no-task "$I")" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC3** This spec names the worked example's four shapes, so the fixture in **AC1** and the frozen example cannot drift apart unnoticed. Inside this spec's intent block, the worked-example region names `T-901-hello-version.md`, `trivial-path:`, `entry-mode: pm-authored`, `no non-trivial decisions` and `no interventions occurred`, and **AC1**'s check line names each of those five strings too.
  - check: rc=0; export LC_ALL=C; F=.shell-team/specs/T-1167-trivial-path-record-gates.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac3.XXXXXX") || exit 1; awk 'index($0,"**Worked example**")==1{f=1} index($0,"## Non-goals")==1{f=0} f' "$F" > "$T/w"; test -s "$T/w" || rc=1; awk 'index($0,"- [ ] **AC1**")==1{f=1;next} f&&index($0,"  - check:")==1{print;exit}' "$F" > "$T/c"; test -s "$T/c" || rc=1; for w in T-901-hello-version.md trivial-path: 'entry-mode: pm-authored' 'no non-trivial decisions' 'no interventions occurred'; do grep -qF -- "$w" "$T/w" || rc=1; grep -qF -- "$w" "$T/c" || rc=1; done; test "$rc" -eq 0

- [ ] **AC4** Run skill step 1 carries the trivial path (decision 1). `skills/run/SKILL.md` carries exactly one line beginning `1. **Plan**`. The region from that line up to the line beginning `2. **Specify**` names each of: `trivial mode`, `pm-spec`, `READY_FOR_ENG`, `## Problem`, `- check:`, `intent block` and `step 4`. The file no longer contains `you may skip to step 4` (the read is asserted to complete: grep exit `1`).

  Review-judged, against decision 1: the region tells the orchestrator to invoke `pm-spec` in trivial mode with the minimal shape named in the invocation, that step 2's freeze sweep, intent hash, Specify-seam gates and dispatch transcription do not run on this path, and that steps 4–7 run unchanged with the new task id.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac4.XXXXXX") || exit 1; awk 'index($0,"1. **Plan**")==1' "$F" > "$T/h"; test "$(grep -c . "$T/h" || true)" = 1 || rc=1; awk 'index($0,"1. **Plan**")==1{f=1} index($0,"2. **Specify**")==1{f=0} f' "$F" > "$T/p"; test -s "$T/p" || rc=1; for w in 'trivial mode' pm-spec READY_FOR_ENG '## Problem' '- check:' 'intent block' 'step 4'; do grep -qF -- "$w" "$T/p" || rc=1; done; grep -qF 'you may skip to step 4' "$F"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** The seam gates always carry a task id, and `no-task` keeps its interventions scope (decision 2). In `skills/run/SKILL.md`: exactly one line begins `   - **Interventions gate at the Implement-to-Validate seam (T-1002)**` and it does not contain `no-task`; exactly one line begins `   - **Durability barrier at the Implement-to-Validate seam (T-1048)**` and exactly one `   - **Durability barrier at the pre-merge backstop (T-1048)**`, and neither contains `no-task flow`; exactly one line begins `**Interventions producer discipline (T-1002)**` and it still contains `no-task.md`. Every absence read is asserted to complete (grep exit `1`).
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac5.XXXXXX") || exit 1; ln(){ awk -v p="$1" 'index($0,p)==1' "$F" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1; }; ln '   - **Interventions gate at the Implement-to-Validate seam (T-1002)**' || rc=1; grep -qF no-task "$T/l"; g=$?; test "$g" -eq 1 || rc=1; for p in '   - **Durability barrier at the Implement-to-Validate seam (T-1048)**' '   - **Durability barrier at the pre-merge backstop (T-1048)**'; do ln "$p" || rc=1; grep -qF 'no-task flow' "$T/l"; g=$?; test "$g" -eq 1 || rc=1; done; ln '**Interventions producer discipline (T-1002)**' || rc=1; grep -qF no-task.md "$T/l" || rc=1; test "$rc" -eq 0

- [ ] **AC6** `pm-spec` carries trivial mode (decision 3). In `agents/pm-spec.md`'s `## Rules` section, exactly one line contains `trivial mode`, and that line names each of: `READY_FOR_ENG`, `trivial-path`, `entry-mode`, `## Problem`, `- check:`, `intent block`, `<task-id>-<slug>.md` and `self-check`. The file no longer contains `skip the full spec, just add a one-line entry` (grep exit `1`).
  - check: rc=0; export LC_ALL=C; F=agents/pm-spec.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac6.XXXXXX") || exit 1; awk '/^## Rules/{f=1;next} /^## /{f=0} f' "$F" > "$T/r"; test -s "$T/r" || rc=1; grep -F 'trivial mode' "$T/r" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1 || rc=1; for w in READY_FOR_ENG trivial-path entry-mode '## Problem' '- check:' 'intent block' '<task-id>-<slug>.md' self-check; do grep -qF -- "$w" "$T/l" || rc=1; done; grep -qF 'skip the full spec, just add a one-line entry' "$F"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC7** `tech-lead` routes a trivial task to `pm-spec`'s trivial mode (decision 7, droppable second). `agents/tech-lead.md` carries exactly one line beginning `- If the change is trivial`; it names `pm-spec` and `trivial mode`, and the file no longer contains `skipping the team workflow`. Exactly one line begins `- Spec:`, and it does not contain `(if non-trivial)`. Every absence read is asserted to complete.
  - check: rc=0; export LC_ALL=C; F=agents/tech-lead.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac7.XXXXXX") || exit 1; awk 'index($0,"- If the change is trivial")==1' "$F" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1 || rc=1; for w in pm-spec 'trivial mode'; do grep -qF -- "$w" "$T/l" || rc=1; done; grep -qF 'skipping the team workflow' "$F"; g=$?; test "$g" -eq 1 || rc=1; awk 'index($0,"- Spec:")==1' "$F" > "$T/s"; test "$(grep -c . "$T/s" || true)" = 1 || rc=1; grep -qF '(if non-trivial)' "$T/s"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC8** The workflow guide's skip table states the trivial path (decision 8, droppable first). `docs/workflow.md` carries exactly one line beginning `| Single-line typo or comment fix |`; it names `pm-spec` and `trivial mode` and does not contain `may skip directly to`. `docs/workflow.ja.md` carries exactly one line beginning `| 1 行のタイポ修正やコメント修正 |`; it names `pm-spec` and `trivial mode` and does not contain `へスキップしてよい`. Every absence read is asserted to complete.
  - adopter-surface: `docs/workflow.md` `## When to skip phases` and `docs/workflow.ja.md` `## フェーズをスキップしてよい場面` (the trivial row); plus `skills/run/SKILL.md` step 1 (**AC4**), which every host's orchestrator reads, and `agents/pm-spec.md` trivial mode (**AC6**).
  - check: rc=0; export LC_ALL=C; E=docs/workflow.md; J=docs/workflow.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac8.XXXXXX") || exit 1; awk 'index($0,"| Single-line typo or comment fix |")==1' "$E" > "$T/e"; awk 'index($0,"| 1 行のタイポ修正やコメント修正 |")==1' "$J" > "$T/j"; for f in "$T/e" "$T/j"; do test "$(grep -c . "$f" || true)" = 1 || rc=1; for w in pm-spec 'trivial mode'; do grep -qF -- "$w" "$f" || rc=1; done; done; grep -qF 'may skip directly to' "$T/e"; g=$?; test "$g" -eq 1 || rc=1; grep -qF 'へスキップしてよい' "$T/j"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC9** No checker, registry or template changes (decision 6). Measured from the base ref the `- base-ref-discriminator:` declaration fixes, the union of the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta, the unstaged delta and the untracked strays, each restricted to `bin` and `templates`, is empty. Positive controls: the base is an ancestor of `HEAD`, and `git ls-files -- bin templates` is non-empty. This is merge-point-scoped and expected to go stale once a later task's edits to these paths land on the base ref.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/feature/654-codex-new-session; then B=$(git merge-base "feature/654-codex-new-session" HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/654-codex-new-session; then B=$(git merge-base "refs/remotes/origin/feature/654-codex-new-session" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base "develop" HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base "refs/remotes/origin/develop" HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; git merge-base --is-ancestor "$B" HEAD || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac9.XXXXXX") || exit 1; git ls-files -- bin templates > "$T/t" || exit 1; test -s "$T/t" || exit 1; git diff --no-renames --name-only "$B"...HEAD -- bin templates > "$T/a" || rc=1; git diff --no-renames --cached --name-only -- bin templates >> "$T/a" || rc=1; git diff --no-renames --name-only -- bin templates >> "$T/a" || rc=1; git ls-files --others --exclude-standard -- bin templates >> "$T/a" || rc=1; test ! -s "$T/a" || rc=1; test "$rc" -eq 0

- [ ] **AC10** The prompt blocks stay in sync and the Codex CLI roles still generate. `bash bin/check-prompt-sync.sh` exits `0`. `bin/gen-codex-agents.sh --root . --out-dir <scratch>` exits `0` and writes a non-empty `shell-team-pm-spec.toml` and `shell-team-tech-lead.toml`, the generated `shell-team-pm-spec.toml` contains `trivial mode`, and `bin/check-codex-agents.sh --root . --out-dir <scratch>` exits `0`.
  - check: rc=0; export LC_ALL=C; for f in bin/check-prompt-sync.sh bin/gen-codex-agents.sh bin/check-codex-agents.sh; do test -s "$f" || exit 1; done; bash bin/check-prompt-sync.sh > /dev/null 2>&1 || rc=1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac10.XXXXXX") || exit 1; bash bin/gen-codex-agents.sh --root . --out-dir "$T/out" > /dev/null 2>&1 || rc=1; for r in pm-spec tech-lead; do test -s "$T/out/shell-team-$r.toml" || rc=1; done; grep -qF 'trivial mode' "$T/out/shell-team-pm-spec.toml" || rc=1; bash bin/check-codex-agents.sh --root . --out-dir "$T/out" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Every suite the edited paths reach stays green; no suite with a recursive delete is run. The suite set is `tests/codex-agents/run.sh` plus every `tests/*/run.sh` that `git grep` finds naming `skills/run/SKILL.md`, `agents/pm-spec.md`, `agents/tech-lead.md`, `docs/workflow.md` or `docs/workflow.ja.md`, derived at run time and asserted non-empty. Each suite is first grepped for a recursive delete: a match is a failure and the suite is not run. Otherwise it exits `0` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac11.XXXXXX") || exit 1; test -s tests/codex-agents/run.sh || exit 1; git grep -lE 'skills/run/SKILL\.md|agents/pm-spec\.md|agents/tech-lead\.md|docs/workflow(\.ja)?\.md' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; printf '%s\n' tests/codex-agents/run.sh >> "$T/d"; sort -u "$T/d" > "$T/suites"; test -s "$T/suites" || rc=1; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; bash "$s" < /dev/null > "$T/log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that names one of the five paths, at which point the derived suite set this criterion runs changes.

- [ ] **AC12** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1167-trivial-path-record-gates.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1167-ac12.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC13** On a clean install of each real host, a request `tech-lead` judges trivial (for example the issue's "add `--version` to `hello.sh` and print `0.1.0`") creates a board entry with a task id and a minimal spec, passes the Implement-to-Validate seam gates, and reaches `READY_FOR_QA`, then both gates.
  - above-ceiling: step V, the coordinating session — it runs the clean-install re-measurement on both hosts after the engineer's hand-off, records the observed board entry, records and flags on this task's board entry, and files a follow-up issue for any seam the trivial entry did not pass. QA reports this criterion as `SKIP` and audits the recorded result.

## Input space

**Reachable input classes**:

1. **Host.** A Claude Code session; a Codex CLI session, whose generated `.codex/agents/` may predate this change (stale role text) until `update shell-team` is run.
2. **Trivial requests.** Requests `tech-lead` judges trivial: a one-line fix, a typo in code or a comment, a single flag or printed value. Each can carry one checkable criterion (a command's output, or a `grep` for the corrected text).
3. **Board state before the run.** No board entries yet (fresh setup); a board with other `## Active` and `## Done` entries.
4. **Layout.** The default `.shell-team/` layout, and the legacy `tasks/` + `docs/specs/` layout; both resolved by the unchanged `bin/team-paths.sh`. The fixture covers the default layout only.
5. **Interventions timing.** An intervention arriving before the trivial entry exists (Plan, before `pm-spec` runs) goes to `no-task.md`; one arriving after goes to `<task-id>.md`.
6. **Records.** Provenance with the sentinel or with decision triples; interventions with the sentinel or with entries.
7. **Shells.** bash 3.2 (macOS) and bash 5 (Linux CI).

**Out-of-scope synthetic extremes**, declined explicitly:

1. `tech-lead` misjudging a non-trivial task as trivial — the quality of that judgment is not this task's subject.
2. Two trivial runs creating entries concurrently on one board.
3. A trivial request with no checkable outcome at all (nothing a command or `grep` can observe).
4. Hand-written provenance or interventions files that are malformed in ways other than the ones **AC2** names; the unchanged checkers already refuse them.

<!-- END intent-block: T-1167 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Step 1 invokes `pm-spec` trivial mode, names the minimal shape, then step 4 (decision 1) | **AC4** |
| 2 | Step 2's freeze sweep, hash, Specify-seam gates and dispatch transcription skipped; steps 4–7 unchanged (decision 1) | **AC4** (review-judged half) |
| 3 | Seam gates carry a task id; no `no-task` substitution at the seam (decision 2) | **AC5** |
| 4 | `no-task.md` kept for interventions with no board task active (decision 2, Input space 5) | **AC5**, **AC2** |
| 5 | `pm-spec` trivial mode shape (decision 3) | **AC6** |
| 6 | The worked example passes every record gate and close-out (decision 4) | **AC1**, **AC3** |
| 7 | Checkers keep failing closed (decision 5, canon Expected) | **AC2** |
| 8 | No `bin/` or `templates/` change (decision 6, Non-goals) | **AC9** |
| 9 | `tech-lead` alignment (decision 7) | **AC7** |
| 10 | Workflow guide alignment (decision 8) | **AC8** |
| 11 | Pre-commitment and drop order (decision 9) | info-only (not promoted to AC) — a disposition rule the coordinating session executes, nothing a check can observe before it fires |
| 12 | No branch rule (Non-goals) | info-only (not promoted to AC) — declares an unchanged behaviour, nothing new to verify |
| 13 | Routing snippet unchanged (Non-goals) | **AC9** |
| 14 | Test-only row unchanged (Non-goals) | info-only (not promoted to AC) — declares an untouched row; a follow-up is suggested below |
| 15 | No new flag, phase or gate (Non-goals) | **AC9**, **AC12** |
| 16 | Prompt-block sync and Codex role generation keep working | **AC10** |
| 17 | Suites reached by the edited paths stay green; no recursive delete | **AC11** |
| 18 | Real-host behaviour (Non-goals) | **AC13** (above the ceiling) |

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `skills/run/SKILL.md` | step 1 `:45`; seam bullets `:79`, `:81`, `:120` | this-task (**AC4**, **AC5**) |
| `agents/pm-spec.md` | `## Rules` `:65` | this-task (**AC6**) |
| `agents/tech-lead.md` | `## Rules` `:82`; Routing Map template `:66` | this-task (**AC7**, droppable) |
| `docs/workflow.md` | `## When to skip phases` `:46` | this-task (**AC8**, droppable) |
| `docs/workflow.ja.md` | `## フェーズをスキップしてよい場面` `:46` | this-task (**AC8**, droppable) |
| `templates/CLAUDE-routing-snippet.md` | `:21` | unchanged: it describes not starting a loop at all, not the in-loop skip |
| `docs/workflow.md` / `.ja.md` | `:48` "Test-only change — Skip `pm-spec`" | unchanged here. The run skill implements no such skip, so the row describes a path that would also reach the seams with no board task. Suggested follow-up issue for the coordinating session. |

`README.md` and `README.ja.md` were searched for `trivial`. Their hits (`:97` "trivially reversed", `:135` "non-trivial request") do not describe the skip.

## Blast radius

- **Codex CLI adopters' generated roles.** `.codex/agents/shell-team-pm-spec.toml` and `shell-team-tech-lead.toml` in an adopter repository carry the old trivial text until `update shell-team` regenerates them. The run skill is read from the installed plugin and updates with it. Decision 1 makes the skill's trivial-mode invocation name the minimal shape itself, so a stale `pm-spec` role still receives it in the briefing. Release notes should still tell Codex CLI adopters to run `update shell-team`.
- **Claude Code adopters.** The agents are read from the installed plugin; nothing is regenerated.
- **This checkout.** `.codex/agents` is ignored (`.gitignore` `:39`); no tracked generated file changes.
- **Merged specs.** No two-arm sweep runs (A2 operation). A merged criterion that pins the replaced sentences of `skills/run/SKILL.md` `:45`/`:79`/`:81`/`:120`, `agents/pm-spec.md` `:65`, `agents/tech-lead.md` `:66`/`:82` or `docs/workflow*.md` `:46` would turn red; such reds are expected and are judged by CI and the reviewer, not chased here.

## Version derivation note

Premise: PATCH v2.8.1, approved at the 2026-10-02 sprint re-plan (relayed). Headline test: not met — nothing new becomes possible; a path the skill already offered stops failing its own seams. Default-reachability: met — any run whose request `tech-lead` calls trivial takes the path. Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed, primary confirmation on the coordinating side:** the observed Codex CLI host run (trivial judgment, marker-less `no-task` records, `BLOCKED` before Validate, no board row) and the earlier taskless run. Not re-measured by the freeze; **AC13** re-observes the path.
- **Relayed:** the design decision (recommendation A), the pre-commitment's never-dropped set and drop order, the sprint premise (PATCH v2.8.1) and the A2 operating conditions.
- **Relayed:** the observed engineer committed directly to the default branch. This role did not measure it; the Non-goals keep branch behaviour unchanged.
- **Measured by this role (file reads):** `check-handoff.sh` does not open the spec path; `check-provenance.sh` refuses any non-`T-<digits>` marker; `check-durability.sh` refuses `--task no-task` and requires the four `implement` records; `close-out.sh` reads no `- entry-mode:` and validates dispatch, spec-review, count and review-input only if present. **Not executed** — this role has no shell. **AC1** and **AC2** execute them; if the freeze run finds either red on the unchanged checkers, a seam the minimal entry cannot pass exists and the pre-commitment's stop-and-return-to-planning applies before any implementation.
- `check-oversight.sh` (called by close-out) is assumed silent with no oversight declaration in a fresh repository (the shipped `autonomous` default, per `close-out.sh` `:563`–`:567`). **AC1** exercises it.
- **Borrowed-vocabulary sweep.** Own coinage: `trivial mode`, `trivial-path` (a grep of the repository outside `.shell-team/` found 0 occurrences of either). Borrowed tokens asserted absent after the change, each present at the branch point (measured by file read at `90a131a6`'s working tree, to be re-measured at the branch point's blob by the freeze run): `you may skip to step 4` (`skills/run/SKILL.md` `:45`, 1); `no-task flow` (`:79`, `:120`); `no-task` in the `:81` gate line; `skip the full spec, just add a one-line entry` (`agents/pm-spec.md` `:65`, 1); `skipping the team workflow` (`agents/tech-lead.md` `:82`, 1); `(if non-trivial)` (`agents/tech-lead.md` `:66`, 1); `may skip directly to` (`docs/workflow.md` `:46`, 1); `へスキップしてよい` (`docs/workflow.ja.md` `:46`, 1). Measurement command for each: `git show "$B:<path>" | grep -cF '<token>'` with `$B` from the base-ref-discriminator expression.
  - Measured at freeze (2026-10-02, coordinating session, `$B` = `90a131a6`): `you may skip to step 4` 1; `no-task flow` 2; `no-task` in `skills/run/SKILL.md` 4 lines; `skip the full spec, just add a one-line entry` 1; `skipping the team workflow` 1; `(if non-trivial)` 1; `may skip directly to` 1; `へスキップしてよい` 1; own coinage `trivial mode` / `trivial-path` outside `.shell-team/` 0. Each matches the value stated above.
- Line-start anchors used by **AC4**–**AC8** (`1. **Plan**`, `2. **Specify**`, the three seam bullets, `**Interventions producer discipline (T-1002)**`, `- If the change is trivial`, `- Spec:`, the two table rows) each occur exactly once today (grep count, this role).

## Open questions

- none blocking.

## Notes for engineer

- Files likely touched: `skills/run/SKILL.md` (step 1 `:45`, and the seam bullets `:79`, `:81`, `:120`), `agents/pm-spec.md` (`## Rules` `:65`), `agents/tech-lead.md` (`:66`, `:82`), `docs/workflow.md` and `docs/workflow.ja.md` (`:46`), plus this task's provenance record. Nothing under `bin/`, `tests/` or `templates/`.
- Gotchas:
  - `skills/run/SKILL.md` `:32` and `:82` carry lines `contain`-synced from `templates/prompt-blocks/interventions-classes.md`; keep them byte-identical (**AC10**).
  - The `pm-spec` trivial line must be one line inside `## Rules` (**AC6** counts lines containing `trivial mode` there).
  - In `:81`, drop the `no-task` substitution only; keep the gate's fail-closed and escalation text. In `:79`/`:120`, keep the statement that the checker refuses a non-`T-<digits>` `--task`; replace "in a no-task flow this step is skipped" with the fact that every path reaching this seam has a board task.
  - The skill's step 1 sentence names the minimal shape itself (decision 1), because a Codex CLI adopter's generated `pm-spec` role may be stale.
- Wording guidance (not frozen beyond the tokens): for `agents/pm-spec.md` — "**Trivial mode.** When the orchestrator invokes you in trivial mode (`tech-lead` judged the task trivial), create the board entry with the next task id at `READY_FOR_ENG`, with `- entry-mode: pm-authored` and a `- trivial-path: <tech-lead's one-line ground>` sub-bullet, and write a minimal spec at `<specs dir>/<task-id>-<slug>.md`: a title, a `**Task ID**:` line, a `## Problem` paragraph and an `## Acceptance criteria` section with at least one criterion carrying a `- check:` line. No intent block and no freeze; the Spec completion self-check does not apply. Your hand-off still carries `- entry-mode:` and `- spec-review: none`."
- Measured-at-ref command check: not applicable — no deliverable prints a command beside a `measured at <ref>` label.
- A pre-commitment is frozen (decision 9). If **AC1** or **AC2** is red on the unchanged checkers, stop and report; do not change a checker.
- Recursive deletion: none in any file you write or any check line here. Leave temp files under `$TMPDIR`.
