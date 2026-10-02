# A QA round after a rework verifies what the rework changed and carries the rest forward

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1161

**Branch**: `feature/639-rework-qa-scope`, cut from `develop` at `8a6cc48c`. Not stacked: no predecessor PR is open, so every base-side read resolves `git merge-base develop HEAD` (or its `refs/remotes/origin/develop` arm when only that resolves), spelled byte-identically in **AC1**, **AC2**, **AC3**, **AC4**, **AC5** and **AC6**.

## Problem

After a `REQUEST_CHANGES` or `FAIL` rework, the next QA round re-runs every scripted acceptance criterion and every CI-wired suite, however small the rework was. Relayed from issue #639 (measured by the coordinating session over 61 rework rounds, 2026-09-10 to 2026-09-30): 34 QA rework rounds took 534 minutes in total, median 11.5 minutes; 33 of 35 QA rework records re-ran every scripted criterion; a +3/-3 prose rework took a 34-minute QA round; and no QA `FAIL` in a rework round came from content the rework did not touch. The re-verification of untouched criteria therefore costs time and has caught nothing. `code-reviewer` is different: 7 of 13 rework review rounds found a `Blocker` or `Major` on untouched lines, so its rounds stay as they are.

## Summarized sources

- GitHub issue #639. **Relayed by the coordinating session, not read by this role.** Distinctions carried over: the Expected outcome has three verification duties on QA round 2 and later: (1) the criteria whose `- check:` reads a path the rework changed, the rework diff being measured since the previous QA round; (2) each finding that caused the rework, closed as a class with every site enumerated; (3) CI green on the rework head. Every other criterion is carried forward by reference, and the carried set is stated explicitly. "Round 1 is unchanged. `code-reviewer` rounds are unchanged." The effectiveness check has three parts. Immediate: replay T-1160's round-2 QA under the new scope, target at most 10 minutes, same verdict, class-closure re-derivation preserved, and "If the target is not met, the change is not adopted." Ongoing: the median of 5 real rework QA rounds is at most 6 minutes (baseline 11.5). Safety: a defect later found inside a carried-forward criterion reverts the default to full re-verification pending re-evaluation. "Evaluated by a one-off telemetry read at each retro; no new checker." Out of scope: fewer rework rounds, scoping `code-reviewer`, parallelism. Operating constraint: subtractive only, "record the procedure, do not mechanize it". Tier PATCH.
- `skills/run/SKILL.md` (read `:70`–`:129`, anchors grepped). Distinctions: step 5 begins at the column-zero line `5. **Validate**` (`:81`), step 6 at `6. **Review**` (`:100`), step 7 at `7. **Done**` (`:115`). Step 5 already carries the same-class-2 rule (`:96`) and the class-closure check (`:97`), which "fires on the first occurrence" and requires the rework hand-off to report which variants were tried. Step 6 routes a `REQUEST_CHANGES` back to `engineer`, and the next QA round is step 5 again. Step 5 says nothing about what a QA round after a rework re-verifies.
- `agents/qa-verifier.md` (read `:1`–`:110`, anchors grepped). Distinctions: `## Your loop` (`:19`) step 1 is "**Run the full test suite.**" (`:21`), step 2 walks every criterion with `check-acs.sh` (`:22`), and the list ends at step 5 "Decide" (`:25`–`:27`), before `## Output` (`:29`). The every-round items live in `## Rules`: `check-intent.sh` (`:63`), `check-provenance.sh` (`:64`), `check-interventions.sh` (`:65`), Summarized-sources verification (`:66`), the runtime-criterion audit (`:69`), Derived populations (`:70`), the verification-ceiling transcription (`:71`), and CI parity (`:72`), which derives the workflow steps "on every round" and runs them locally. Five generated prompt blocks sit at `:87`–`:192` (careful-execution, playbook-qa-verifier, record-portability, record-shape-scan, language).
- `.shell-team/specs/T-1160-spec-review-round-cap.md` (read in full). Distinctions: its **AC6** reads `skills/run/SKILL.md`, **AC7** reads `agents/code-reviewer.md` and runs `tests/codex-skeleton-hygiene/run.sh` and `tests/codex-agents/run.sh`, **AC8** reads both files, **AC10** runs 14 suites (including three that read `skills/run/SKILL.md`) and `check-handoff.sh` on the board resolved through `team-paths.sh --get todo`, and **AC14** is a diff scope lock. Its declaration shapes, criterion shapes and pre-commitment are the structural precedent here.
- `.shell-team/todo.md`, T-1160's entry (`:6892`–`:6913`) and its two QA verdict blocks (`:12184`–`:12198`). Distinctions: the round-2 verdict (`:12192`) re-ran all 15 criteria with `check-acs.sh`, and its `Class closure (bare-name invocation)` line (`:12196`) re-derived the class over `git diff d48d87b1..HEAD -- agents skills docs templates`, reporting zero `team-paths.sh --get` occurrences outside the plugin-root form. Verdict PASS.
- The telemetry corpus `$(bin/team-paths.sh --get runs)/shell-team.jsonl` (grepped for run `20260930T040100Z-t1160`, read by this role). Distinctions: seq 15 is the `handoff` event labelled `READY_FOR_QA` at `2026-09-30T05:34:12Z`, and seq 16 is the `qa-verifier` `validate` span with `iteration` 2 at `2026-09-30T06:07:46Z`, `duration_ms` null. The difference, 33m34s, is the 34-minute baseline. A rework span can carry `duration_ms: null`, so round time is measured from the preceding handoff event.
- `templates/prompt-blocks/host-dispatch.md` (read in full). Distinction: it covers role dispatch on the two hosts and the Codex-host review recipe. It says nothing about what a QA round verifies. On the Codex CLI host, `qa-verifier` reaches the spawned agent through `bin/gen-codex-agents.sh`, byte-identical after the frontmatter (`:1`).
- `skills/goal/SKILL.md` (grepped). Distinction: the goal loop runs `check-acs.sh` as its own deterministic layer on every iteration and invokes `qa-verifier` without any scoped-round declaration (`:57`, `:79`).
- `docs/adopting.md` `## Both gates green and your own CI` (read `:758`–`:792`) and `docs/adopting.ja.md` `## 両ゲート green と自分のリポジトリの CI` (read `:767`–`:800`). Distinctions: QA "derives those steps from them on every round, runs them locally" (`:765`–`:766`), and "nothing here reads a result back from GitHub — QA runs commands locally and reports what they returned, it does not query a check run or a pull request's status" (`:772`–`:774`). The ja section says the same (`毎 round`).
- `README.md`, `README.ja.md`, `docs/workflow.md`, `docs/workflow.ja.md` (grepped for `every round`, `rework`, `qa-verifier`). Distinction: none of them says what a QA round after a rework re-verifies. Each stays true after this task.
- `tests/codex-skeleton-hygiene/run.sh` (grepped `:1539`–`:1712`). Distinctions: the DP-7 regex `NEW_AC3` (`:1547`) matches an invocation of the form `bash bin/check-(provenance|interventions).sh` across `agents/qa-verifier.md`, `skills/run/SKILL.md` and `skills/goal/SKILL.md` and must match zero lines there. The DP-8 regex `NEW_AC15` (`:1551`) matches `(provenance|interventions) gate:ACn` and `route back through loop guard` (hyphen or space) and must match zero lines in `skills/run/SKILL.md`.
- `bin/derive-populations.sh` (read `:1`–`:70`). Distinction: it emits a `<!-- BEGIN derivation: <label> -->` block from two to eight named extraction commands. Any count a record states goes through it.
- `.shell-team/specs/T-1105-review-executor-resolution.md` (read `:46`–`:52`, `:96`) and `.shell-team/specs/T-1147-class-m-grant-host-neutral-record.md` (grepped). Distinction: the `- verification-ceiling:` line names the criterion above the ceiling, and that criterion carries an indented `- above-ceiling: <owner> — <what the owner does>` line.
- `.shell-team/interventions/T-1161.md` (read). Distinction: the operator ruled to scope QA rework rounds only, with the replay target of at most 10 minutes and an effectiveness-check procedure delivered with the task.

## Goal

<!-- BEGIN intent-block: T-1161 -->

- user-visible: yes — every adopter's default loop changes how a QA round after a rework runs: from QA round 2 on, `qa-verifier` re-verifies what the rework reached and carries the rest forward by an explicit label list, instead of re-running everything. Round 1, `code-reviewer` rounds and the goal loop are unchanged. Nothing new becomes possible, so the tier is PATCH.
- verification-class: no-mechanism — the diff reaches no path under `bin/`, `tests/`, `templates/` or `.github/`, and changes no checker's semantics. It edits prose in `skills/run/SKILL.md`, `agents/qa-verifier.md` and two docs. Because `agents/qa-verifier.md` and the step-5 bullet are a gate surface's briefing, the added obligation applies: the shipped norm text is read against this spec, and the read set includes every merged criterion asserting those files' bytes (disclosed under Blast radius).
- verification-ceiling: unit-and-static — **AC1**–**AC7** are settled in a plain checkout by string presence or absence in a named region of a shipped file or of its base blob read with `git show`, by a byte comparison against that base blob, by a shipped suite's or checker's exit code, or by a `git diff` / `git ls-files` read. **AC8** sits above the ceiling and carries its own `- above-ceiling:` line: it needs a live `qa-verifier` dispatch timed by the coordinating session.
- base-ref-discriminator: not-applicable — this branch has no open predecessor PR. It was cut from `develop` at `8a6cc48c`, and every base-side read resolves `git merge-base develop HEAD`, or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves, selected by `git show-ref --verify --quiet`.
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: agents/qa-verifier.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task

**Goal (one sentence).** On every QA round after a rework (QA round 2 and later), the run skill's Validate step briefs `qa-verifier` to run a **scoped re-verification round** against a named **previous QA base** (the commit that recorded the previous QA round's verdict), and in such a round `qa-verifier` re-runs every criterion the rework diff can reach, independently re-derives the closure of each finding that caused the rework as a class, and runs the CI-parity steps and CI-wired suites the rework diff reaches on the rework head, while every other criterion that passed in the previous round is carried forward and named in an explicit AC-label list; QA round 1, every invocation whose briefing declares no scoped round (the goal loop included), and every `code-reviewer` round verify exactly as they do today, and the change is prose only, with no new checker, script, gate or record layer.

**Pre-commitment (frozen before round 1; authorship: AI self-discipline, never operator-ratified).**

Never-dropped. A defeat of any never-dropped item in two consecutive rounds (a QA `FAIL` or a Codex `REQUEST_CHANGES` that each carry a new `Blocker` or `Major` against it) stops the task and returns it to planning, with no carve-out:

1. N1: QA round 1 is unchanged (**AC1**, **AC3**).
2. N2: `code-reviewer` rounds are unchanged (**AC2**).
3. N3: the class-closure re-derivation of each finding that caused the rework survives the scoping (**AC1**, **AC3**, **AC8**).

Droppable: none. Every component is a clause of one briefing duty and one verifier duty, and dropping any of them breaks the issue's Expected outcome rather than narrowing it.

Adoption trigger: **AC8**'s replay misses its target (more than 10 minutes, a verdict other than PASS, or no class-closure re-derivation). Disposition: the change is not adopted. The engineer reverts this branch's prose changes, the task is not merged, and the coordinating session tells the operator three things: the measured failure (elapsed time, verdict, re-run and carried sets), the alternative approach that would close the item, and why that approach belongs to a later cycle.

## Non-goals

- **No reduction in the number of rework rounds.** (info-only)
- **`code-reviewer` rounds are unchanged**, including step 6 of the run skill and `agents/code-reviewer.md`. (**AC2**)
- **No parallelism** in QA or anywhere else. (info-only)
- **No change to `skills/goal/SKILL.md`**, its `check-acs.sh` layer, or `templates/prompt-blocks/host-dispatch.md`. (**AC2**)
- **No change to the lessons corpus or to any generated prompt block** in `agents/qa-verifier.md`. (**AC2**, **AC4**)
- **No new checker, `bin/` script, test, gate, status flag or record layer.** The ongoing evaluation and the safety revert are procedures, not mechanisms. (**AC6**)
- **QA reads nothing back from GitHub.** Clause (3), "CI green on the rework head", is discharged by the local run of the reached CI-parity steps and suites on the rework head, and the adopter docs' statement that QA does not query a check run stays true. (**AC5**)
- **No full-population sweep, no whole CI-equivalent re-run and no behaviour verification of a mechanism this task does not touch** (`no-mechanism` class). (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`. The base `$B` is `git merge-base develop HEAD`, or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves. After this task merges into `develop`, `$B` becomes HEAD itself, so every base-side delta below is merge-point-scoped and expected to go stale. That is expected and is never repaired by re-deriving the base.

- [ ] **AC1** (N1, N3.) The run skill's step 5 carries the scoped-round briefing duty as one new bullet, and nothing else in the file changes.
  - `skills/run/SKILL.md` has exactly one line beginning `5. **Validate**` and exactly one beginning `6. **Review**`, both at HEAD and in the base blob.
  - The line containing `**Scoped re-verification briefing (T-1161)**` occurs exactly once in the file and lies in the step-5 region (from the `5. **Validate**` line up to, not including, the `6. **Review**` line).
  - That line names `scoped re-verification round`, `previous QA base`, `git log`, `Carried forward from round`, `Re-run this round`, `Class closure`, `reverts the default to full re-verification` and `code-reviewer`, and contains `round 1` (case-insensitive). The meaning is review-judged: the duty fires on QA round 2 and later only, never on round 1; the briefing names the previous QA base and the findings that caused the rework; the previous QA base is the most recent commit that added the task's previous QA verdict heading to the board, findable with `git log`; `code-reviewer` rounds are unchanged; and a defect later found inside a carried-forward criterion reverts the default to full re-verification pending the operator's re-evaluation, recorded as an interventions entry.
  - The base blob contains no `scoped re-verification` (case-insensitive), and every line of the base blob is present, whole, at HEAD.
  - check: rc=0; export LC_ALL=C; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac1.XXXXXX") || exit 1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; A='5. **Validate**'; Z='6. **Review**'; for f in "$S" "$T/b"; do test "$(awk -v a="$A" 'index($0,a)==1' "$f" | grep -c . || true)" = 1 || rc=1; test "$(awk -v z="$Z" 'index($0,z)==1' "$f" | grep -c . || true)" = 1 || rc=1; done; awk -v a="$A" -v z="$Z" 'index($0,a)==1{f=1} index($0,z)==1{f=0} f' "$S" > "$T/r"; test -s "$T/r" || rc=1; N='**Scoped re-verification briefing (T-1161)**'; test "$(grep -cF -- "$N" "$S" || true)" = 1 || rc=1; grep -F -- "$N" "$T/r" > "$T/n" || rc=1; test "$(grep -c . "$T/n" || true)" = 1 || rc=1; for w in 'scoped re-verification round' 'previous QA base' 'git log' 'Carried forward from round' 'Re-run this round' 'Class closure' 'reverts the default to full re-verification' 'code-reviewer'; do grep -qF -- "$w" "$T/n" || rc=1; done; grep -qiF -- 'round 1' "$T/n" || rc=1; test "$(grep -ciF -- 'scoped re-verification' "$T/b" || true)" = 0 || rc=1; grep -vxF -f "$S" "$T/b" > "$T/miss"; g=$?; test "$g" -le 1 || rc=1; test ! -s "$T/miss" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** (N2.) The surfaces this task must not touch are byte-identical to their base blobs: the step-6 region of `skills/run/SKILL.md` (from the `6. **Review**` line up to, not including, the `7. **Done**` line, asserted non-empty), and the whole of `agents/code-reviewer.md`, `skills/goal/SKILL.md`, `templates/prompt-blocks/host-dispatch.md` and the lessons corpus `.shell-team/lessons.md`.
  - check: rc=0; export LC_ALL=C; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac2.XXXXXX") || exit 1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; Y='index($0,a)==1{f=1} index($0,z)==1{f=0} f'; awk -v a='6. **Review**' -v z='7. **Done**' "$Y" "$S" > "$T/h6"; awk -v a='6. **Review**' -v z='7. **Done**' "$Y" "$T/b" > "$T/b6"; test -s "$T/b6" || rc=1; cmp -s "$T/b6" "$T/h6" || rc=1; for f in agents/code-reviewer.md skills/goal/SKILL.md templates/prompt-blocks/host-dispatch.md .shell-team/lessons.md; do test -s "$f" || rc=1; git show "$B:$f" > "$T/x" 2>/dev/null || rc=1; test -s "$T/x" || rc=1; cmp -s "$T/x" "$f" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC3** (N1, N3.) `agents/qa-verifier.md` carries the scoped-round rule inside `## Your loop`, its CI parity rule names the scoped round, and nothing else in the file changes except loop steps 1 and 2 and the CI parity line. The rule, whose meaning is review-judged, settles each of the following:
  1. **Trigger.** It fires only when the orchestrator's briefing declares a scoped re-verification round and names the previous QA base and the findings that caused the rework. Without that declaration (QA round 1, the goal loop, any direct invocation) the round runs exactly as today.
  2. **Rework diff.** `git diff --no-renames --name-only <previous QA base>...HEAD`.
  3. **Re-run set.** A criterion is re-run, as a whole and never partially, when its `- check:` line names a rework-diff path or its directory; runs a suite, script or checker that reads such a path; reaches such a path through indirection (`team-paths.sh`, a variable, a glob); measures the diff or the tree itself (a `git diff` or `git ls-files` read, a scope lock); was named by a finding that caused the rework; did not PASS in the previous round; or cannot be classified. Every other criterion that passed in the previous round is carried forward.
  4. **Full-round fallback.** When the previous QA base cannot be resolved or is not an ancestor of HEAD, or the rework diff contains the task's own spec, the whole round is full re-verification.
  5. **Every round, whatever the scope.** `check-intent.sh`, `check-provenance.sh`, `check-interventions.sh` and `check-handoff.sh` are re-run, and the verification-ceiling line is transcribed.
  6. **Summarized sources.** Carried forward, except that a named source the rework diff contains is re-verified.
  7. **Runtime criteria.** A criterion with no `- check:` is re-audited when the rework diff contains a path its enumeration names or a finding named it. Otherwise it is carried forward.
  8. **Test suite and CI parity.** The CI-parity steps are still derived from the workflow files every round. The steps and CI-wired suites whose inputs the rework diff reaches (reverse-mapped from each rework-diff path and its parent directory) are run locally on the rework head. That run discharges "CI green on the rework head". Nothing is read back from GitHub.
  9. **Class closure.** For each finding that caused the rework, QA independently re-derives the class inventory (every site) over the rework diff and reports it on a `Class closure` line per finding.
  10. **Verdict.** The verdict states the carried set on a `Carried forward from round <n>` line and the re-run set on a `Re-run this round` line, each as an AC-label enumeration. It states no count of either set unless that count carries its own derivation under the Derived populations rule.

  Checked:
  - The line containing `**Scoped re-verification round (T-1161)**` occurs exactly once in the file and lies between `## Your loop` and `## Output`.
  - Its paragraph (that line plus the following lines up to a blank line, a numbered-list line or a `## ` heading) names `briefing`, `previous QA base`, `Carried forward from round`, `Re-run this round`, `Class closure`, `check-intent.sh`, `check-provenance.sh`, `check-interventions.sh`, `Summarized sources`, `runtime`, `CI parity`, `unchanged` and `PASS`.
  - Exactly one line begins `- **CI parity (T-1133)**`, and it names `scoped re-verification round`.
  - The base blob contains no `scoped re-verification` (case-insensitive). Every base line, other than those beginning `1. **Run the full test suite.**`, `2. **Walk each acceptance criterion**` and `- **CI parity (T-1133)**`, is present, whole, at HEAD.
  - check: rc=0; export LC_ALL=C; F=agents/qa-verifier.md; test -s "$F" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac3.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; N='**Scoped re-verification round (T-1161)**'; test "$(grep -cF -- "$N" "$F" || true)" = 1 || rc=1; test "$(grep -ciF -- 'scoped re-verification' "$T/b" || true)" = 0 || rc=1; awk 'index($0,"## Your loop")==1{f=1;next} f&&index($0,"## Output")==1{f=0} f' "$F" > "$T/loop"; test -s "$T/loop" || rc=1; test "$(grep -cF -- "$N" "$T/loop" || true)" = 1 || rc=1; awk -v n="$N" 'index($0,n){f=1;print;next} f&&($0==""||$0~/^[0-9]+\. /||index($0,"## ")==1){f=0} f' "$F" > "$T/p"; test -s "$T/p" || rc=1; for w in 'briefing' 'previous QA base' 'Carried forward from round' 'Re-run this round' 'Class closure' 'check-intent.sh' 'check-provenance.sh' 'check-interventions.sh' 'Summarized sources' 'runtime' 'CI parity' 'unchanged' 'PASS'; do grep -qF -- "$w" "$T/p" || rc=1; done; C='- **CI parity (T-1133)**'; awk -v c="$C" 'index($0,c)==1' "$F" > "$T/ci"; test "$(grep -c . "$T/ci" || true)" = 1 || rc=1; grep -qF -- 'scoped re-verification round' "$T/ci" || rc=1; awk 'index($0,"1. **Run the full test suite.**")!=1 && index($0,"2. **Walk each acceptance criterion**")!=1 && index($0,"- **CI parity (T-1133)**")!=1' "$T/b" > "$T/keep"; test -s "$T/keep" || rc=1; grep -vxF -f "$F" "$T/keep" > "$T/miss"; g=$?; test "$g" -le 1 || rc=1; test ! -s "$T/miss" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** Generated blocks, prompt-block sync, the suites that read the edited paths, the board and the generated Codex agent all stay green.
  - The concatenated `<!-- BEGIN prompt-block: … -->` … `<!-- END prompt-block: … -->` regions of `agents/qa-verifier.md` are byte-identical to the base blob's, and asserted non-empty.
  - `bash bin/check-prompt-sync.sh` exits `0`.
  - Each of these suites exits `0` and prints no line beginning `FAIL`: `codex-skeleton-hygiene` (the DP-7 broken-invocation and DP-8 stateful-trace live-file locks over `agents/qa-verifier.md` and `skills/run/SKILL.md`), `check-prompt-sync`, `codex-agents`, `check-invocation-path`, `check-refreeze-grant`, `check-oversight`, `team-init`, `check-adopter-docs` and `trial-recipe`.
  - Generating the roles into a scratch directory with `bin/gen-codex-agents.sh --root .`, then checking them with `bin/check-codex-agents.sh --root .`, both exit `0`, and the generated `shell-team-qa-verifier.toml` contains `Scoped re-verification round (T-1161)`.
  - `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; F=agents/qa-verifier.md; test -s "$F" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac4.XXXXXX") || exit 1; X='index($0,"<!-- BEGIN prompt-block:")==1{f=1} f{print} index($0,"<!-- END prompt-block:")==1{f=0}'; git show "$B:$F" > "$T/b" 2>/dev/null || rc=1; awk "$X" "$T/b" > "$T/bb"; awk "$X" "$F" > "$T/hb"; test -s "$T/bb" || rc=1; cmp -s "$T/bb" "$T/hb" || rc=1; bash bin/check-prompt-sync.sh > /dev/null 2>&1 || rc=1; for s in tests/codex-skeleton-hygiene/run.sh tests/check-prompt-sync/run.sh tests/codex-agents/run.sh tests/check-invocation-path/run.sh tests/check-refreeze-grant/run.sh tests/check-oversight/run.sh tests/team-init/run.sh tests/check-adopter-docs/run.sh tests/trial-recipe/run.sh; do test -s "$s" || rc=1; bash "$s" > "$T/log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done; mkdir -p "$T/out" || rc=1; bash bin/gen-codex-agents.sh --root . --out-dir "$T/out" > /dev/null 2>&1 || rc=1; bash bin/check-codex-agents.sh --root . --out-dir "$T/out" > /dev/null 2>&1 || rc=1; G="$T/out/shell-team-qa-verifier.toml"; test -s "$G" || rc=1; grep -qF -- 'Scoped re-verification round (T-1161)' "$G" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** The adopter-facing documentation lands in the same task, in both languages, and still says QA reads nothing back from GitHub.
  - `docs/adopting.md` has exactly one `## Both gates green and your own CI` line. The section's flattened form names `scoped re-verification round`, `Carried forward from round` and `Re-run this round`, and still contains `does not query a check run`.
  - `docs/adopting.ja.md` has exactly one `## 両ゲート green と自分のリポジトリの CI` line, and that section names `scoped re-verification round` and `Carried forward from round`.
  - Positive controls on the delta: both base blobs are non-empty and contain no `scoped re-verification` (case-insensitive).
  - adopter-surface: `docs/adopting.md` `## Both gates green and your own CI` and `docs/adopting.ja.md` `## 両ゲート green と自分のリポジトリの CI` — what a QA round after a rework re-runs, what it carries forward, how the carried set appears in the verdict, that round 1 and `code-reviewer` rounds are unchanged, and when a round falls back to full re-verification.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac5.XXXXXX") || exit 1; HE='## Both gates green and your own CI'; HJ='## 両ゲート green と自分のリポジトリの CI'; test "$(grep -cxF -- "$HE" "$E" || true)" = 1 || rc=1; test "$(grep -cxF -- "$HJ" "$J" || true)" = 1 || rc=1; X='index($0,h)==1{f=1;next} f&&index($0,"## ")==1{f=0} f'; fl(){ tr '\n' ' ' < "$1" | tr -s ' '; }; awk -v h="$HE" "$X" "$E" > "$T/e"; awk -v h="$HJ" "$X" "$J" > "$T/j"; test -s "$T/e" || rc=1; test -s "$T/j" || rc=1; fl "$T/e" > "$T/fe"; fl "$T/j" > "$T/fj"; for w in 'scoped re-verification round' 'Carried forward from round' 'Re-run this round' 'does not query a check run'; do grep -qF -- "$w" "$T/fe" || rc=1; done; for w in 'scoped re-verification round' 'Carried forward from round'; do grep -qF -- "$w" "$T/fj" || rc=1; done; for f in "$E" "$J"; do git show "$B:$f" > "$T/bf" 2>/dev/null || rc=1; test -s "$T/bf" || rc=1; test "$(grep -ciF -- 'scoped re-verification' "$T/bf" || true)" = 0 || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** This task's diff is confined to a fixed allow-list, so no checker, script, test, template, workflow or record layer is added. The measured set is the union of four reads: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only` and the untracked strays `git ls-files --others --exclude-standard`.
  - Allowed paths: `agents/qa-verifier.md`, `skills/run/SKILL.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `.shell-team/todo.md`, `.shell-team/test-recipe.md`, and this task's own spec, provenance, interventions and review records.
  - Controls: the measured union is asserted non-empty, and the allow-list is asserted to contain no path under `bin/`, `tests/`, `templates/` or `.github/`.

  **This criterion is merge-point-scoped and expected to go stale after merge**, once later tasks' files land on the same base. That is expected. It is never repaired by widening the base resolution or re-deriving it per rework round.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac6.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' agents/qa-verifier.md skills/run/SKILL.md docs/adopting.md docs/adopting.ja.md .shell-team/todo.md .shell-team/test-recipe.md .shell-team/specs/T-1161-rework-qa-scope.md .shell-team/provenance/T-1161.md .shell-team/interventions/T-1161.md .shell-team/reviews/T-1161.md | sort -u > "$T/allow"; grep -qE '^(bin|tests|templates|\.github)/' "$T/allow" && rc=1; grep -vxF -f "$T/allow" "$T/got" > "$T/extra"; g=$?; test "$g" -le 1 || rc=1; test ! -s "$T/extra" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC7** This spec is a conformant carrier of its own declarations. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. Positive control: the spec and the checker are asserted non-empty first.
  - check: C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1161-rework-qa-scope.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1161-ac7.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; rc=0; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC8** (N3; the immediate effectiveness check and this task's adoption trigger.) Replaying T-1160's round-2 QA under the new scope meets the target. The replay is performed by the coordinating session after the engineer's hand-off and before this task's own QA round:
  - in a `$TMPDIR` `git clone --shared` of this repository, detached at `9a941a17` (T-1160's rework commit);
  - one `qa-verifier` is dispatched, with a briefing that declares a scoped re-verification round, quotes this branch's new `agents/qa-verifier.md` rule text and step-5 bullet verbatim, names the previous QA base the step-5 bullet's own `git log` form returns in that clone, and names the round-1 review finding (Major N3: bare `team-paths.sh` in the reviewer's contract-path fallback) as the finding that caused the rework;
  - elapsed time runs from a `date -u` taken immediately before dispatch to a `date -u` taken on the completion notification.

  Pass condition, all of the following:
  - Elapsed is at most 10 minutes.
  - The verdict is `PASS`, the same verdict as the baseline.
  - The verdict carries a `Carried forward from round 1` line with a non-empty AC-label enumeration, and a `Re-run this round` line whose enumeration includes at least T-1160's **AC6**, **AC7**, **AC8**, **AC10** and **AC14**. Each of those reads a path the rework changed, reaches one through a suite or `team-paths.sh`, or reads the diff (measured by this role from T-1160's check lines).
  - The verdict carries a `Class closure` line that independently re-derives the bare-name-invocation class over the rework's added prose, matching in substance the baseline's line (`.shell-team/todo.md`, T-1160 round-2 QA verdict, `Class closure (bare-name invocation)`).
  - The result is recorded on T-1161's board entry as one sub-bullet: `- replay (YYYY-MM-DD): dispatched <UTC> — completed <UTC> — elapsed <m>m<s>s — verdict <PASS|FAIL> — previous QA base <sha> — carried <labels> — re-run <labels> — class-closure <preserved|missing> — confound: <the qa-verifier definition actually dispatched>`. Nothing is written into telemetry under T-1160's run_id.
  - The confound is always recorded: the dispatched agent is the installed plugin snapshot's own `qa-verifier` definition, not this branch's, which reaches it only through the briefing's quoted text.

  A miss on any condition fires the adoption trigger in the pre-commitment above.
  - above-ceiling: the coordinating session — it alone can dispatch `qa-verifier` and time it. It runs the replay once in the scratch clone, records the sub-bullet above, and tells the operator the result. QA for this task reports this criterion as `SKIP`, audits the recorded sub-bullet against the pass condition item by item, and does not re-run the replay.

## Input space

**Reachable input classes**: what the loop's own producers put in front of the scoped rule.

1. Rework diffs of every real shape: prose only (T-1160 r2's +3/-3 across three files); a `bin/` script with its suite; a test-only change; record-only changes (board, review record, provenance); the task's own spec after a re-freeze.
2. Reworks caused by a QA `FAIL` (step 5) or by a `code-reviewer` `REQUEST_CHANGES` (step 6), with one or several findings, and QA round 2 or any later round. From round 3 on, the previous QA base is the latest QA verdict commit.
3. A previous round in which every criterion passed, and a previous round in which some failed, were skipped or were never verified.
4. Criteria that read their targets literally, through a directory or glob, through a suite that reads them, through `team-paths.sh` or a variable, or through a diff or scope-lock read. Specs with runtime criteria (no `- check:`), with a `## Summarized sources` section and without one.
5. Invocations with and without a scoped-round declaration: the run skill's round 2+, round 1, the goal loop, a direct invocation. A briefing whose previous QA base does not resolve or is not an ancestor of HEAD (after a rebase).
6. Repositories with and without `.github/workflows`, and CI-parity steps that do and do not read a rework-diff path.
7. Both hosts. On Claude Code the orchestrator reads `skills/run/SKILL.md` and `qa-verifier` reads `agents/qa-verifier.md` directly. On Codex CLI the same role text reaches the spawned `shell-team-qa-verifier` agent through `gen-codex-agents.sh`.

**Out-of-scope synthetic extremes**, declined explicitly:

1. A briefing that names a deliberately wrong previous QA base, or a board whose QA verdict headings were hand-edited to mislead the `git log` search.
2. A history rewrite that deletes the previous verdict commit while leaving an unrelated ancestor matching the search. The rule falls back to a full round only when no ancestor resolves.
3. A scoped round inside a declared `concurrent-review-window`. No default path enters that window, and the pinned-SHA rules there are unchanged.
4. A criterion whose `- check:` reads a path through a mechanism no reading of its text can reveal (a network fetch, a path computed from the current time).
5. An orchestrator or `qa-verifier` that ignores the written rule. The prose states the duty, and nothing executes it for them.

<!-- END intent-block: T-1161 -->

## Symmetry audit: scoped-round norm × surfaces

| Norm boundary | `skills/run/SKILL.md` step 5 briefing | `agents/qa-verifier.md` loop rule | `agents/qa-verifier.md` CI parity rule | `skills/goal/SKILL.md` | `templates/prompt-blocks/host-dispatch.md` | `docs/adopting.md` / `.ja.md` |
|---|---|---|---|---|---|---|
| Fires only on a declared round 2+ | mirrored-now (**AC1**, `round 1`) | mirrored-now (**AC3** item 1, `briefing`, `unchanged`) | mirrored-now (**AC3**) | not-applicable: it declares no scoped round, so `qa-verifier` stays full there (**AC2**, byte-identical) | not-applicable: it carries no QA-round text (**AC2**) | mirrored-now (**AC5**) |
| Previous QA base, found with `git log` | mirrored-now (**AC1**) | mirrored-now (**AC3** item 2) | not-applicable | not-applicable | not-applicable | info-only (the docs name the behaviour, not the mechanics) |
| Re-run selection and full-round fallback | info-only: the orchestrator names inputs, QA selects | mirrored-now (**AC3** items 3–4, review-judged) | not-applicable | not-applicable | not-applicable | mirrored-now (**AC5**, `Re-run this round`) |
| Carried set as an AC-label enumeration | mirrored-now (**AC1**, `Carried forward from round`) | mirrored-now (**AC3** item 10) | not-applicable | not-applicable | not-applicable | mirrored-now (**AC5**) |
| Class closure per finding | mirrored-now (**AC1**, `Class closure`) | mirrored-now (**AC3** item 9) | not-applicable | not-applicable | not-applicable | info-only |
| CI reached-steps run on the rework head, no GitHub read | info-only | mirrored-now (**AC3** item 8) | mirrored-now (**AC3**, `scoped re-verification round`) | not-applicable | not-applicable | mirrored-now (**AC5**, `does not query a check run`) |
| Every-round checkers | not-applicable | mirrored-now (**AC3** item 5) | not-applicable | not-applicable | not-applicable | info-only |
| Safety revert | mirrored-now (**AC1**, `reverts the default to full re-verification`) | not-applicable: the revert is the orchestrator's (it stops declaring scoped rounds) | not-applicable | not-applicable | not-applicable | info-only |
| `code-reviewer` rounds unchanged | mirrored-now (**AC1** `code-reviewer`; **AC2** step 6 byte-identical) | not-applicable | not-applicable | not-applicable | not-applicable | info-only |
| Codex CLI host | same text, read by the host's orchestrator (relayed, see Assumptions) | generated agent carries it (**AC4**) | same (**AC4**) | not-applicable | not-applicable | not-applicable |

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Step 5 briefs a scoped round on QA round 2+ with the previous QA base and the findings (Goal) | **AC1** |
| 2 | Round 1 unchanged (Goal, N1) | **AC1** (`round 1`), **AC3** item 1 |
| 3 | `code-reviewer` rounds unchanged (Goal, N2, Non-goals) | **AC2** |
| 4 | Re-run selection, full fallback, every-round items, sources, runtime criteria, CI reached steps, class closure, verdict enumeration (Goal) | **AC3** items 1–10 |
| 5 | Previous QA base = the verdict commit found with `git log`, no new record field (Goal) | **AC1**, **AC3** item 2, **AC6** (no record file added) |
| 6 | Safety revert in one sentence of shipped prose (Goal via issue canon) | **AC1** |
| 7 | Counts in the verdict go through the Derived populations rule (Goal) | **AC3** item 10 |
| 8 | Generated blocks and lessons corpus untouched (Non-goals) | **AC2**, **AC4** |
| 9 | Goal loop and host-dispatch untouched (Non-goals) | **AC2** |
| 10 | No new checker, script, test, gate or record layer (Non-goals) | **AC6** |
| 11 | No GitHub read; clause (3) discharged locally (Non-goals) | **AC3** item 8, **AC5** |
| 12 | Adopter docs in both languages (user-visible) | **AC5** |
| 13 | Codex-host parity through the generated agent | **AC4** |
| 14 | Immediate replay ≤ 10 min, same verdict, class closure preserved; otherwise not adopted (issue canon, pre-commitment) | **AC8** |
| 15 | Declarations conformant | **AC7** |
| 16 | No fewer rework rounds; no parallelism (Non-goals) | info-only (not promoted to AC): both record decisions not to act. |
| 17 | Ongoing evaluation (median of 5 real rounds ≤ 6 min) by a one-off telemetry read at each retro | info-only (not promoted to AC): it happens after merge and is deliberately not mechanized. The command is under `## Ongoing evaluation procedure`. |
| 18 | No full-population sweep or whole CI re-run (no-mechanism class) | info-only (not promoted to AC): a pricing decision about this task's own verification. |

## Singular-determiner read (freeze-time duty)

Singular determiners in the norm text: "the previous QA base", "the rework diff", "the finding that caused the rework", "the carried set". Read against T-1146's board history (three QA rounds, `:12161`) and T-1160's (two rework-causing findings over its life):

- "the previous QA base" is one commit per round by construction: the latest QA verdict commit. Round 3 uses round 2's, never round 1's.
- "the finding that caused the rework" is plural in practice. The rule says "each finding" and requires one `Class closure` line per finding.
- "the carried set" is one enumeration per round, and it may be empty. An empty carried set is a full round and is written as `none`.

## Blast radius

`- verification-class: no-mechanism`. Edited shipped paths: `skills/run/SKILL.md`, `agents/qa-verifier.md`, `docs/adopting.md`, `docs/adopting.ja.md`. Read set of merged criteria naming them, derived at run time:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*(agents/qa-verifier\.md|skills/run/SKILL\.md|docs/adopting(\.ja)?\.md)' -- .shell-team/specs

Known consequences, stated rather than discovered:

- **Kept green by construction.** **AC1** keeps `skills/run/SKILL.md` purely additive, and **AC3** keeps every line of `agents/qa-verifier.md` except three whole. A merged criterion that asserts a line's presence or a region's tokens in those files stays green. A merged criterion that asserts a region's byte-equality or a line count in step 5, loop steps 1–2 or the CI parity line can flip. The read-set run identifies it.
- **Expected to go red.** No merged scope lock names these files for this branch. Every merged scope lock is merge-point-scoped by its own prose.

**Indirection class:** merged criteria that reach these files through a suite (the nine in **AC4**) or through `team-paths.sh` are disclosed here and not measured separately. **AC4** runs those suites at HEAD. **Disclosed deviation:** under the operator's standing A2 mode, the read-set two-arm run is not executed per task. The deviation is recorded here rather than silently skipped.

**Adopter-side artifacts:**

- Codex-host adopters' generated `.codex/agents/shell-team-qa-verifier.toml` goes stale when `agents/qa-verifier.md` changes, and must be regenerated with `gen-codex-agents.sh`. The detection and re-run path is already documented in `docs/adopting.md`'s Codex CLI section, and this task adds no mechanism for it.
- An adopter whose orchestrator runs an older installed snapshot keeps full re-verification until the snapshot is updated. That is the safe direction.

## Ongoing evaluation procedure (a retro-time read; not mechanized)

At each retro after adoption, the coordinating session runs this once and reports the median over the first five real rework QA rounds after adoption (target at most 6 minutes, baseline 11.5). Round time is the `qa-verifier` `validate` span's `ts` minus the `ts` of the preceding `READY_FOR_QA` handoff event in the same run, because rework spans can carry `duration_ms: null`.

```bash
R="$(bash bin/team-paths.sh --get runs)/shell-team.jsonl"; test -s "$R" || exit 1
awk -v since="<adoption UTC timestamp, e.g. 2026-10-01T00:00:00Z>" '
function fld(k,  r) { if (match($0, "\"" k "\":\"[^\"]*\"")) { r = substr($0, RSTART, RLENGTH); sub("^\"" k "\":\"", "", r); sub("\"$", "", r); return r } return "" }
function ep(s,  y, m, d) { y = substr(s,1,4)+0; m = substr(s,6,2)+0; d = substr(s,9,2)+0; if (m <= 2) { y--; m += 12 }
  return (365*y + int(y/4) - int(y/100) + int(y/400) + int((153*(m-3)+2)/5) + d) * 86400 + substr(s,12,2)*3600 + substr(s,15,2)*60 + substr(s,18,2) }
{ id = fld("run_id"); ts = fld("ts") }
index($0, "\"event\":\"handoff\"") && index($0, "\"label\":\"READY_FOR_QA\"") { q[id] = ts; next }
fld("span") == "qa-verifier" && fld("phase") == "validate" && match($0, /"iteration":[0-9]+/) {
  it = substr($0, RSTART + 12, RLENGTH - 12) + 0
  if (it >= 2 && (id in q) && ts >= since) printf "%s\t%s\t%d\t%.1f\n", id, ts, it, (ep(ts) - ep(q[id])) / 60 }' "$R" > "${TMPDIR:-/tmp}/rework-qa.tsv"
head -n 5 "${TMPDIR:-/tmp}/rework-qa.tsv" | sort -t "$(printf '\t')" -k4,4n | awk -F '\t' '{ print } NR == 3 { m = $4 } END { if (NR < 5) print "fewer than 5 rounds:", NR; else print "median minutes:", m }'
```

Positive control, **measured at freeze by the coordinating session** (it returned exactly this line and `fewer than 5 rounds: 1`): with `since="2026-09-30T00:00:00Z"` the first file includes the line `20260930T040100Z-t1160	2026-09-30T06:07:46Z	2	33.6` (seq 16 minus seq 15 = 33m34s). **Safety:** a defect later found inside a carried-forward criterion is recorded as an `assumption-contradicted` interventions entry, and the orchestrator stops declaring scoped rounds (**AC1**). The retro reads that entry for the re-evaluation.

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #639: a QA round after a rework verifies what the rework reached | not met | met (every run-skill rework on the default path) | PATCH | It makes an existing gate cheaper on the default path. Nothing new becomes possible. The issue states tier PATCH. |

## Assumptions

- **Relayed:** issue #639's body, including the 61-round measurement, via the coordinating session (primary: the coordinating session and the issue itself).
- **Relayed:** T-1160's rework commit `9a941a17` (parent `04c7925b`, the Codex round-1 review record; before it `08c4d527` "QA verdict wording" and `97b6b7c1` "QA PASS, READY_FOR_REVIEW") changes three files, +3/-3: `.shell-team/todo.md`, `agents/code-reviewer.md`, `skills/run/SKILL.md`. Primary: the coordinating session's git read. The freeze run re-measures it with `git show --stat 9a941a17` and records the value beside this line. **Measured at freeze (2026-09-30, coordinating session):** `git show --shortstat --format= 9a941a17` → `3 files changed, 3 insertions(+), 3 deletions(-)`. Which of `97b6b7c1` / `08c4d527` the `git log` search returns as the previous QA base depends on whether the wording commit touched the heading line. Either gives the same code diff, differing only in record files that every criterion listed in **AC8** already reaches.
- **Relayed:** the Codex CLI host's orchestrator follows the same `skills/run/SKILL.md` text (as T-1160 also assumed). This role did not measure how the run skill reaches that host.
- **Measured by this role:** the telemetry baseline (seq 15 `05:34:12Z`, seq 16 `06:07:46Z`, `duration_ms` null), the T-1160 round-2 class-closure line (`.shell-team/todo.md:12196`), T-1160's check-line read targets for **AC6**/**AC7**/**AC8**/**AC10**/**AC14**, and that `tests/codex-skeleton-hygiene/run.sh`, `tests/check-refreeze-grant/run.sh` and `tests/check-oversight/run.sh` name `skills/run/SKILL.md` (Grep tool, not the runtime grep; the freeze run re-measures with `grep -rlF -- skills/run/SKILL.md tests/*/run.sh`). **Measured at freeze:** that command lists exactly `tests/check-oversight/run.sh`, `tests/check-refreeze-grant/run.sh` and `tests/codex-skeleton-hygiene/run.sh`.
- **Interpretation of issue clause (3), flagged for the coordinating session:** "CI green on the rework head" is discharged by `qa-verifier`'s local run of the reached CI-parity steps and suites on the rework head. The reason: QA reads nothing back from GitHub (`docs/adopting.md:772`–`:774`), and adding a check-run read would be a new mechanism the operating constraint forbids. The real CI still runs on every pull request and is confirmed before merge outside QA. If the operator reads the clause as a GitHub check-run read, this is a class-B re-freeze.
- **Residual, disclosed:** the safety revert takes effect for the rest of the run at once. Across sessions it persists only through the interventions entry the retro reads, because no record layer may be added. A fresh session before that retro would still declare scoped rounds.
- **Decisions made here** (the engineer may not relax them without a re-freeze): a criterion is re-run whole or carried whole, never partially; a criterion that did not PASS in the previous round is always re-run; an unclassifiable criterion is re-run; a rework that touches the task's own spec makes the whole round full; the every-round checkers of **AC3** item 5 always run because each takes seconds.
- **Own-coinage count premises** (read by this role with the Grep tool in the working tree at `cc9004dd`, which differs from `develop` only by `.shell-team/interventions/T-1161.md`): `scoped re-verification`, `Carried forward from round`, `previous QA base` and `reverts the default to full re-verification` occur **0** times across `agents/*.md`, `skills/**/*.md`, `docs/*.md` and `templates/**`. `Re-run this round` also occurs 0 times there, but it occurs in review records, which is why no criterion asserts its base count.
- **Borrowed count premises** (read by this role at `cc9004dd`; the freeze run re-measures each at `$B` and records the value here):

| Token | Class | Value read now | Command at the base |
|---|---|---|---|
| column-zero `5. **Validate**` / `6. **Review**` / `7. **Done**` in `skills/run/SKILL.md` | borrowed | **1** / **1** / **1** (`:81` / `:100` / `:115`) | `git show "$B:skills/run/SKILL.md" \| awk 'index($0,"<anchor>")==1' \| grep -c .` |
| `## Your loop` / `## Output` in `agents/qa-verifier.md` | borrowed | **1** / **1** (`:19` / `:29`) | `git show "$B:agents/qa-verifier.md" \| grep -cxF '<heading>'` |
| `1. **Run the full test suite.**` / `2. **Walk each acceptance criterion**` / `- **CI parity (T-1133)**` line starts | borrowed | **1** / **1** / **1** (`:21` / `:22` / `:72`) | `git show "$B:agents/qa-verifier.md" \| awk 'index($0,"<start>")==1' \| grep -c .` |
| `<!-- BEGIN prompt-block:` lines in `agents/qa-verifier.md` | borrowed | **5** (`:87`–`:188`) | `git show "$B:agents/qa-verifier.md" \| grep -c '^<!-- BEGIN prompt-block:'` |
| `## Both gates green and your own CI` / `## 両ゲート green と自分のリポジトリの CI` | borrowed | **1** / **1** (`:758` / `:767`) | `git show "$B:<file>" \| grep -cxF '<heading>'` |
| `does not query a check run` in the en section | borrowed | **1** (`:774`) | **AC5**'s section extraction piped to `grep -cF` |

(`\|` is markdown escaping for `|`.)

**Measured at freeze (2026-09-30, coordinating session, `$B` = `8a6cc48c`):** each command above re-run at the base returns the value in the "Value read now" column: step anchors 1/1/1, loop headings 1/1, loop-step and CI-parity line starts 1/1/1, prompt-block BEGIN lines 5, doc headings 1/1, `does not query a check run` 1.

## Open questions

None blocking. The interpretation of clause (3) is an assumption, flagged above for the coordinating session.

## Notes for engineer

- **Files touched:** `skills/run/SKILL.md` (one new bullet in step 5), `agents/qa-verifier.md` (one new paragraph in `## Your loop`, plus minimal edits to loop steps 1 and 2 and the CI parity rule line), `docs/adopting.md` and `docs/adopting.ja.md` (the `## Both gates green and your own CI` sections), and this task's records. Nothing under `bin/`, `tests/` or `templates/` (**AC6**).
- **`skills/run/SKILL.md`:**
  - Add exactly one single-line bullet in step 5, e.g. right after the class-closure bullet (`:97`), beginning `- **Scoped re-verification briefing (T-1161)**:`. Every existing line stays whole (**AC1**), and step 6 stays byte-identical (**AC2**).
  - The bullet should say: from QA round 2 on (never round 1), declare a scoped re-verification round in the `qa-verifier` briefing; name the previous QA base, found as the most recent commit adding the task's previous QA verdict heading to the board (e.g. `git log -1 --format=%H -G '^### QA verdict.*<task-id>' -- <board>`); name each finding that caused the rework; expect `Carried forward from round <n>`, `Re-run this round` and `Class closure` lines back. It should also carry the safety sentence containing `reverts the default to full re-verification`: stop declaring scoped rounds, record an `assumption-contradicted` interventions entry naming the criterion, and surface it to the operator. Finally it should state that `code-reviewer` rounds are unchanged.
  - **DP-8 lock:** do not write `route back through loop guard` (hyphen or space) or a `provenance gate:ACn` / `interventions gate:ACn` sentinel. **DP-7 lock:** never write `bash bin/check-provenance.sh` or `bash bin/check-interventions.sh`. Name scripts as nouns, or invoke them as `bash "<plugin root>/bin/<script>"`.
- **`agents/qa-verifier.md`:**
  - Put the new paragraph after the numbered list ends (after `:27`, before `## Output`), starting with `**Scoped re-verification round (T-1161)**`, and end it with a blank line. Inserting a new numbered step would renumber `5. Decide` and break **AC3**'s line-survival lock.
  - Cover items 1–10 of **AC3**. Suggested verdict lines: `- Carried forward from round <n> (previous QA base <sha>): <AC labels> | none`, `- Re-run this round: <AC label> (<reason>), …`, `- Class closure (<finding class>): <inventory and result>`.
  - Loop steps 1 and 2 may gain a short "(narrowed on a scoped re-verification round, see below)" clause. The CI parity line must name `scoped re-verification round`, and its "on every round" derivation stays true.
  - Leave all five generated blocks untouched (**AC4**). Do not edit the lessons corpus.
- **Docs:** replace or extend the "derives those steps from them on every round, runs them locally" sentence so it stays accurate, and keep "it does not query a check run" (**AC5**). Keep the English tokens `scoped re-verification round` and `Carried forward from round` verbatim in the ja section, and do not wrap a line break inside either token. **AC5** flattens newlines to spaces, so wrap only at spaces.
- **Codex host:** after editing, `gen-codex-agents.sh` output changes for `qa-verifier`. **AC4** proves parity in a scratch directory, and `.codex/agents` is gitignored here.
- **Measured-at-ref command check:** not applicable. No deliverable prints a command labelled as measured at a git ref. The ongoing-evaluation command reads the live telemetry file, not a ref.
- **Replay (AC8):** the coordinating session's duty, not yours. Your hand-off should quote the final new `agents/qa-verifier.md` paragraph and step-5 bullet verbatim, so the replay briefing can quote them.
