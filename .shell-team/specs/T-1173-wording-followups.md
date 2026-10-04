# Four wording follow-ups: the GIT_CONFIG_PARAMETERS remedy's scope, one severity-calibration sentence, the trivial-path and no-task seams, and a guard_error reason for a spec-review guard refusal (issues #678, #632, #658, #635)

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1173

**Branch**: `feature/678-wording-followups`, cut from `develop` at `06469cb1`. This role read `.git/refs/heads/develop` and `.git/refs/heads/feature/678-wording-followups`, and both are `06469cb14431deb76e811c3e24ac37d7aa43f558`. Not stacked: there is no open predecessor. The pull request targets `develop`.

## Problem

Four small fast-follows each found a wording seam in a shipped surface. Each seam is one where the text says something other than what the mechanism does or should do:
- the `GIT_CONFIG_PARAMETERS` remedy says "for this invocation" about a bare `unset`;
- the review severity calibration both demotes a finding class and forbids lowering a judged severity, in the same paragraph;
- the run skill's Dispatch-record sub-bullet reads as if step 2 always runs, and nothing says what happens to a Plan-time `no-task.md` intervention;
- a refusal from the spec-review round guard is escalated under the cap-stop's reason.

All four are bundled here because three of them edit `skills/run/SKILL.md`, and two issues ask to be bundled with the next edit of that file.

**Issue canon, verbatim.** The coordinating session fetched the four bodies on 2026-10-04 and relayed them in a scratch file, which this role read in full. Each body follows as a quoted block. Its own `##`/`###` headings are demoted to bold labels so that this spec's section structure is unchanged. Otherwise the text is unchanged.

> **#678 — team-commit.sh: the GIT_CONFIG_PARAMETERS remedy says "for this invocation", but a bare unset lasts for the rest of the shell**
>
> Fast-follow from T-1171 (#664), cross-provider review round 1 (minor).
>
> **Observed**
>
> The `GIT_CONFIG_PARAMETERS` refusal in `bin/team-commit.sh`, its `--help` text, and step 6 of `docs/adopting.md` and `docs/adopting.ja.md` tell the operator to run `unset GIT_CONFIG_PARAMETERS` "for this invocation" (EN) / for that one invocation (JA).
>
> A bare `unset` in an interactive shell lasts for the rest of that shell, not for one invocation. It is per-invocation only where each command runs in its own shell, as in a sandboxed tool call. The remedy itself is correct. Nothing about what is refused or committed changes.
>
> **Expected**
>
> The remedy wording matches what the command does. Either:
> - name a per-invocation form, for example `env -u GIT_CONFIG_PARAMETERS bash <plugin root>/bin/team-commit.sh …`; or
> - say that the unset lasts for the rest of the shell.
>
> Apply this in the refusal text, `--help`, and both guides, keeping EN and JA equivalent.
>
> **Prior art**
>
> Searched issues for `GIT_CONFIG_PARAMETERS unset invocation`. The only match is #664, the parent this wording came from (closed by T-1171). The wording was frozen in T-1171's spec decision 2, so it is filed rather than changed in that task.

> **#632 — Review-briefing calibration says a finding class is "not a Blocker or Major" and, in the same paragraph, "never lower a severity it judges" — state which one wins**
>
> **What**
>
> T-1159 (#631) added a severity calibration to the Specify-seam spec review, mirroring the shape of `skills/run/SKILL.md` step 6's "Verdict scope and severity calibration in the review briefing". Both texts now say, in one paragraph, that a finding class (process/records findings at step 6; the adversarial completeness of an enumerative `- check:` line at the Specify seam) is reported as a note or fast-follow and not as a `Blocker`/`Major`, and that the reviewer never lowers a severity it judges.
>
> Read literally, a reviewer that judges such a finding `Major` is given both instructions. The literal reading errs toward over-reporting rather than withholding, so nothing is hidden today, but the calibration can be defeated by the same paragraph that states it — which is the churn #631 exists to stop.
>
> Sites: `skills/run/SKILL.md` (step 6 bullet and the Specify-seam spec-review gate bullet), `agents/code-reviewer.md` (spec-review mode, "Verdict scope and severity calibration" paragraph), `docs/adopting.md` / `docs/adopting.ja.md` ("What gates the verdict" in the spec-review section).
>
> **Expected**
>
> One sentence, applied identically at every site, that separates the two: the finding is still reported, with the reviewer's own severity judgment recorded, while the verdict treats that class as non-gating unless it makes the criterion vacuous (or, at step 6, invalidates the deliverable). The reviewer's independence over findings stays untouched.
>
> **Source**
>
> T-1159 cross-provider review round 1, Minor 1 (`.shell-team/reviews/T-1159.md`), declared `file-an-issue`, to be bundled with the next edit of the step-6 bullet since the phrasing is shared.
>
> Prior art: searched open and closed issues for "never lower a severity" / severity calibration; closest are #631 (the calibration itself) and #591 (review evidence contract, closed). Neither covers this conflict.

> **#658 — run skill: two wording seams left by the trivial-mode path (T-1167)**
>
> **Problem**
>
> Two minor findings from the T-1167 cross-provider review (#655, `.shell-team/reviews/T-1167.md`, round 1), deferred as fast-follows:
>
> - `skills/run/SKILL.md` step 1's **Dispatch record (T-1084)** sub-bullet still says the orchestrator transcribes the dispatch rows "once `pm-spec` has created that entry in step 2". Step 1 now says that on the trivial path `pm-spec` runs in trivial mode and no dispatch rows are transcribed. The orchestrator's path is not ambiguous, because step 1 states the trivial case explicitly, but the sub-bullet reads as if step 2 always runs.
> - An intervention recorded during Plan, before any board entry exists, lands in `no-task.md`, and nothing says to carry it into the task's own interventions file once the entry is created. This was frozen behaviour in T-1167 (its Input space) and the full path behaves the same, but one sentence would close it.
>
> **Expected**
>
> The Dispatch-record sub-bullet names both paths (full: after `pm-spec` creates the entry in step 2; trivial: no rows), and the interventions producer-discipline paragraph says what happens to a `no-task.md` entry once the task's board entry exists.
>
> **Notes**
>
> To be bundled with the next task that edits `skills/run/SKILL.md`. Prior art: searched issues for "dispatch record trivial"; none.

> **#635 — Specify-seam gate: a refusal from the spec-review round guard is escalated "the same way" as a cap stop — name its own reason**
>
> **What**
>
> Deferred from the T-1160 cross-provider review round 2 (#630; `.shell-team/reviews/T-1160.md`), Minor [N2]. The Specify-seam spec-review gate in `skills/run/SKILL.md` says a refusal from `check-spec-review.sh --rounds` (any exit status other than 0/3, or no stdout) "is a stop that you escalate the same way" as `STOP:spec_review_rounds_reached`. Read literally, the escalation then runs `rework-digest.sh --stop-reason spec_review_rounds_reached`, which states the wrong cause: the guard could not evaluate its input, it did not count to the cap.
>
> The behaviour is correct — the refusal is escalated and never read as `CONTINUE` — only the stated reason is wrong.
>
> **Expected**
>
> The gate names a distinct reason for a guard refusal (for example `guard_error`, already in `rework-digest.sh`'s `--stop-reason` set) and quotes the guard's own stderr in the escalation, while keeping the no-re-invoke rule.
>
> Prior art: searched open and closed issues for the spec-review guard escalation wording; the only related item is #630 itself.

**Expected-to-criteria trace.**

| Issue | Expected line | Criteria |
|---|---|---|
| #678 | the remedy wording matches what the command does (one of the two named options) | **AC1** (refusal text, `--help`, the refusal as run), **AC2** (both guides). The second option is taken (decision 1). The first option, `env -u`, is not taken, and **AC1**/**AC2** assert its absence. Choosing between the issue's own "Either" options narrows nothing. |
| #678 | refusal text, `--help` and both guides, EN and JA equivalent | **AC1**, **AC2** |
| #632 | one sentence, applied identically at every site | **AC3** (run skill, two sites), **AC4** (code-reviewer spec-review mode), **AC5** (both guides). Widened: also the embedded Codex prompt in `agents/code-reviewer.md` (**AC4**), a parallel site the issue does not name (decision 3). |
| #632 | reported with the reviewer's own severity recorded; the verdict treats the class as non-gating unless vacuous / invalidates the deliverable | **AC3**–**AC5** (canonical sentence with its exception slot) |
| #632 | the reviewer's independence over findings stays untouched | **AC3**–**AC5** (the independence clause is retained at every site) |
| #632 | (coordinating-session decision) read consistently against T-1172 without changing T-1172's rule | **AC3**–**AC5** (the sentence's ledger and T-1172-check clauses), **AC6** (T-1172's text byte-identical) |
| #658 | Dispatch-record sub-bullet names both paths | **AC7**. Widened: the parallel "Where this fits above" bullet (**AC8**, droppable first). |
| #658 | interventions paragraph says what happens to a `no-task.md` entry once the board entry exists | **AC9** |
| #635 | a distinct reason (`guard_error`) for a guard refusal | **AC10**, **AC12** (the shipped digest accepts it) |
| #635 | quote the guard's own stderr; keep the no-re-invoke rule | **AC10** |
| #635 | (Routing Map) the EN/JA guides carry the matching clause | **AC11**. Widened: the issue names only the run skill. |

## Summarized sources

- The four issue bodies, relayed verbatim in `## Problem` (scratch file, read in full). Distinctions carried over:
  - #678 offers **two alternative** remedies ("Either"), names four sites (refusal, `--help`, both guides), and states that what is refused or committed does not change.
  - #632 asks for **one sentence identical at every site**, separating *reporting at the judged severity* from *gating the verdict*, with **two different exception clauses** (vacuous criterion at the Specify seam; invalidates the deliverable at step 6). It keeps independence over findings.
  - #658 asks for **both paths** in the Dispatch-record sub-bullet, and for the interventions paragraph to say what happens to a `no-task.md` entry **once the board entry exists**.
  - #635 asks for a **distinct reason**, the guard's **own stderr quoted**, and the **no-re-invoke rule kept**. The behaviour (escalate, never `CONTINUE`) is already correct.
- `bin/team-commit.sh` (read `:1`–`:189`). Distinctions:
  - The refusal is one line at `:178` and is `refuse environment`, exit 2, before any git call or write (`:75`, `:164`–`:179`).
  - `--help` is a heredoc (`:78`–`:123`). Its `GIT_CONFIG_PARAMETERS` remedy sits at `:94`–`:96`, ahead of the `GIT_CONFIG_COUNT` clause.
  - No `GIT_CONFIG_PARAMETERS` occurs before `:94`.
- `tests/team-commit/run.sh` `:576`–`:581` (read). Distinction: the suite requires the literal `unset GIT_CONFIG_PARAMETERS` in the refusal's stderr, so that literal is kept.
- `templates/prompt-blocks/host-dispatch.md` `:5` (read). Distinction: on the Codex CLI host every commit goes through **one invocation** of `bin/team-commit.sh` with single-quoted literal arguments, approved for **that identical invocation, unchanged**, and is "never retried in another form". An `env -u` prefix is another form, so decision 1 rejects it.
- `docs/adopting.md` `:620`–`:626` and `docs/adopting.ja.md` `:620`–`:626` (read). Distinction: the EN text says "clears it for that one invocation" and the JA text says `その 1 回の呼び出しについて解除できる`. The `GIT_CONFIG_COUNT` sentence follows in both.
- `skills/run/SKILL.md` (read `:28`–`:58`, `:100`–`:117`, `:315`–`:323`). Distinctions:
  - `:32` is the interventions producer-discipline paragraph, which already routes Plan-time entries to `no-task.md` "when no board task is active".
  - `:45` states the trivial path, on which dispatch transcription does not run.
  - `:46` is the Dispatch-record sub-bullet ("once `pm-spec` has created that entry in step 2 and before `engineer` is invoked in step 4").
  - `:58` is the Specify-seam spec-review gate on one physical line. It carries its calibration paragraph mid-line, between `**Verdict scope and severity calibration in the spec-review briefing**` and `**A spec-review round is not a loop iteration**`, and its refusal clause "a refusal (any other exit status, or no stdout) is a stop that you escalate the same way, never read as `CONTINUE`".
  - `:104` is T-1172's `Downgrade-ground check`: a row lowered below the highest pass severity whose ground fails is "not downgraded", and "when that leaves a blocker or major standing, transcribe no APPROVE".
  - `:109` is the step-6 calibration bullet ("unless it invalidates the deliverable itself"; "never ask it ... to lower a severity it judges").
  - `:323` is "Where this fits above" ("once `pm-spec` has created that entry in step 2").
  - No prompt-block marker region exists in the file. The `:34` mention names a contain-mode source.
- `agents/code-reviewer.md` (read `:98`–`:108`, `:168`–`:249`). Distinctions:
  - `:105`–`:108` hold step 6's synthesis audit ledger and T-1172's rule: a row lowering a finding's severity keeps it only on a ground that holds with the status struck.
  - `:182` is the spec-review calibration ("not as a `Blocker` or `Major`, unless ... vacuous"; "never lower a severity you judge"; "This calibrates severity only").
  - `:193`–`:200` is the embedded `codex exec` prompt, a bash double-quoted string continued with a trailing ` \` on every line but the last. Its `:197`–`:199` are the calibration lines.
  - `:184` is the Round-cap guard, which is unchanged.
  - Spec-review mode writes no synthesis ledger (`:230`, and T-1172's Non-goals).
- `docs/adopting.md` `:1221`–`:1229`, `:1253`–`:1274` and `docs/adopting.ja.md` `:1182`–`:1189`, `:1202`–`:1222` (read). Distinctions:
  - "What gates the verdict" says "not as a `Blocker` or `Major`" and "no severity it judges is lowered".
  - The round-bound paragraph names only `--stop-reason spec_review_rounds_reached`, and says "a refusal is never read as `CONTINUE`".
- `bin/check-spec-review.sh` header `:63`–`:97`, `:166`–`:169` (read). Distinctions:
  - `--rounds` prints `APPROVED`/`CONTINUE`/`STOP:spec_review_rounds_reached`.
  - Any refusal "exits 1 or 2 with nothing on stdout".
  - An unreadable contract is refused first.
- `bin/rework-digest.sh` `:30`–`:35`, `:125`–`:169`, `:245`–`:250`, `:520` (read). Distinctions:
  - `--stop-reason` accepts `guard_error` beside `spec_review_rounds_reached`.
  - Records are `--round/--phase/--class` triples.
  - The digest prints a `stop-reason: <reason>` line.
- `bin/check-interventions.sh` `:1`–`:118` (read). Distinctions:
  - There is exactly one marker pair per file, with id `T-<digits>` or `no-task`.
  - An entry is `- intervention: <class>` plus exactly one indented `date:`, `summary:` and `effect:`.
  - Any other non-blank line is a schema violation (exit 1).
  - The first real entry replaces the sentinel.
- `templates/prompt-blocks/dispatch-record.md` (read) and `templates/prompt-blocks/registry.txt` `:1`–`:53` (read). Distinctions:
  - `dispatch-record.md` is contain-mode into `agents/tech-lead.md` and `skills/run/SKILL.md`. Its `:4` says "once `pm-spec` has created that entry" with no "step 2". Neither `:46` nor `:323` of the run skill is one of its lines.
  - `interventions-classes.md` lines 8 and 13 are contained as substrings of the run skill's `:32`.
- `skills/goal/SKILL.md` `:87`–`:88` (read). Distinction: it references the run skill's calibration bullet and Downgrade-ground check "rather than restating" them, so it needs no edit.
- `docs/loop-engineering/specify-seam-review.md` `:37` and `docs/loop-engineering/spec-authorship-entry.md` `:30`–`:31` (read). Distinction: both say "once `pm-spec` has created the task's board entry" without "step 2", so they stay accurate on both paths (`## Shipped-docs inventory`).
- `.shell-team/specs/T-1172-synthesis-downgrade-ground.md` (read in full). Distinction: the shape this spec follows. Its rule governs lowered or rejected ledger rows only, and reaches neither spec-review nor review-response mode.

## Goal

<!-- BEGIN intent-block: T-1173 -->

- user-visible: yes — an adopter reads `bin/team-commit.sh`'s refusal and `--help` text and the two adopting guides, and the run skill they invoke changes how it escalates a spec-review guard refusal and how it words the review severity calibration it briefs the reviewer with.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- verification-class: mechanism — the diff reaches `bin/team-commit.sh` (an executed script's own output) and the run-skill and agent prose that drives the Specify-seam and Review gates, including a `codex exec` prompt string.
- verification-ceiling: unit-and-static — every criterion, **AC1**–**AC16**, is settled in a plain checkout. Each one reads shipped files, runs a shipped script against a scratch input in `$TMPDIR`, regenerates generated files into `$TMPDIR`, or runs checkers and suites. No criterion claims that a live reviewer or orchestrator applies the wording in a real round, and none sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor. It was cut from `develop` at `06469cb1`, and the base-side reads in **AC6**, **AC10** and **AC15** use `git merge-base develop HEAD` (or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves), each arm selected by `git show-ref --verify --quiet`.

**Goal (one sentence).** The `GIT_CONFIG_PARAMETERS` remedy in `bin/team-commit.sh`'s refusal and `--help` and in both adopting guides keeps `unset GIT_CONFIG_PARAMETERS` and says that the unset lasts for the rest of the shell it runs in. Every review-severity calibration site carries one canonical sentence that separates reporting a finding at the reviewer's own severity from whether it gates the verdict, without changing T-1172's downgrade rule. The run skill's dispatch-record text names both the full and the trivial path, and its interventions paragraph says how a Plan-time `no-task.md` entry reaches the task's own file. A refusal from the spec-review round guard is escalated with `--stop-reason guard_error`, quoting the guard's stderr, in the run skill and both guides.

**Decisions frozen here** (each is promoted to a criterion):

1. **#678, the remedy's scope.** Keep `unset GIT_CONFIG_PARAMETERS` and say what it does: it lasts for the rest of the shell it runs in, and it covers one invocation only where each command runs in its own shell (as in a sandboxed tool call).
   - This applies to the refusal line, the `--help` text and both guides, EN and JA equivalent.
   - No `env -u` form is named, because on the Codex CLI host a role's commit is one identical `bash "<plugin root>/bin/team-commit.sh" …` invocation, never retried in another form (`templates/prompt-blocks/host-dispatch.md` `:5`).
   - The refusal stays one line, and what is refused and its exit status do not change. (**AC1**, **AC2**)
2. **#632, the canonical sentence.** Every calibration site carries this one sentence verbatim (JA: its equivalent translation). Only the exception slot `<X>` differs:

   > A finding in a calibrated class is still reported at the severity the reviewer judges and recorded at that severity, with no Synthesis-audit-ledger downgrade row, because the calibration scopes the verdict and lowers no severity; the verdict treats that finding as non-gating unless it `<X>`, and because no severity is lowered, the run skill's step-6 check of lowered ledger rows (T-1172) does not apply to it, and it does not count as a blocker or major standing under that check.

   `<X>` is `invalidates the deliverable itself` at step 6, and `makes that check line's own criterion vacuous` at every Specify-seam site.
   - At every site, the earlier phrasing that the class "is reported as a note or a fast-follow" instead of a `Blocker`/`Major` is removed.
   - The site still defines its calibrated class and still states the reviewer's independence over findings.
   - At step 6 the two clauses about the ledger and the T-1172 check do real work. At the Specify seam no synthesis ledger and no such check exist, so those clauses are inert there. They are kept so that the sentence is one sentence everywhere, as #632 asks.
   - The sentence refers to T-1172's check by description and does not repeat its bullet name, so no new line of `skills/run/SKILL.md` contains `Downgrade-ground check`. That keeps T-1172's **AC4** (exactly one such line) green.
   
   (**AC3**, **AC4**, **AC5**)
3. **#632, the sites.** Six sites:
   - `skills/run/SKILL.md` step-6 calibration bullet (`:109`);
   - the calibration paragraph inside the Specify-seam gate line (`:58`);
   - `agents/code-reviewer.md` spec-review calibration (`:182`);
   - its embedded `codex exec` prompt (`:193`–`:200`). This parallel site is not named by the issue, and its text must stay shell-safe inside its double quotes: no backtick, no `$`, no inner `"`, and every line but the last continued with ` \`;
   - `docs/adopting.md` "What gates the verdict";
   - `docs/adopting.ja.md` "verdict を左右するもの".
   
   (**AC3**, **AC4**, **AC5**)
4. **#632 against T-1172.** The calibration lowers no severity. So a calibrated finding gets no ledger downgrade row, T-1172's test (which reads lowered rows) has nothing to read, and a calibrated non-gating finding is not a "blocker or major standing" for the run skill's step-6 check of lowered ledger rows (T-1172). T-1172's own text stays byte-identical: `agents/code-reviewer.md` step 6's three T-1172 lines and the run skill's `Downgrade-ground check (T-1172)` bullet, which remains the only line of `skills/run/SKILL.md` containing `Downgrade-ground check`. (**AC6**)
5. **#658, both paths.** The Dispatch-record sub-bullet (`:46`) and the parallel "Where this fits above" bullet (`:323`) each say: on the full path, transcribe after `pm-spec` creates the entry in step 2; on the trivial path, no dispatch rows are transcribed. The shared `dispatch-record` prompt block and its consumers are not edited. (**AC7**, **AC8**, **AC15**)
6. **#658, the Plan-time entry.** The interventions producer-discipline paragraph (`:32`) gains one sentence. Once the task's board entry exists, each entry recorded in `no-task.md` during this task's Plan is copied into the task's own interventions file. The copy is a well-formed entry that cites its origin in its `summary:` value, and the `no-task.md` entry stays in place, because the file is append-only. The copy fits `bin/check-interventions.sh` unchanged. (**AC9**)
7. **#635, the refusal's own reason.** In the Specify-seam gate's refusal clause, a refusal is a stop for its own reason: the review is not re-invoked, the escalation runs `rework-digest.sh --stop-reason guard_error` quoting the guard's stderr verbatim, and the refusal is never read as `CONTINUE`.
   - The cap-stop branch keeps `--stop-reason spec_review_rounds_reached`.
   - `bin/rework-digest.sh` already accepts `guard_error` and is not changed.
   - `agents/code-reviewer.md`'s Round-cap guard (`:184`) is not changed.
   
   (**AC10**, **AC12**)
8. **#635, the guides.** The EN and JA round-bound paragraphs gain the matching clause. (**AC11**)

**Pre-commitment (AI self-discipline, not an operator ruling).**
- **Never-dropped:**
  - #632's canonical sentence and its T-1172 consistency (**AC3**–**AC6**);
  - #635's refusal reason (**AC10**–**AC12**).
  
  A review or QA finding of either kind below is not patched in place: the task stops and returns to planning.
  - The canonical sentence cannot be stated so that it reads consistently against T-1172's rule without changing that rule.
  - The refusal cannot be given its own reason without a `bin/` change.
- **Droppable, first:** the parallel `:323` edit (decision 5's second site, **AC8**).
- **Trigger:** the same reviewer class of finding against the droppable item in two consecutive rounds.
- **Disposition:** restore `:323` to its base bytes, and remove **AC8** in a class-B re-freeze recorded as executing this pre-commitment. Carry the rounds' findings to a follow-up issue as its requirement list. No further wording round on it.

## Non-goals

- **No `env -u` (or any other per-invocation wrapper) form of the remedy.** (decision 1; **AC1**, **AC2**)
- **No change to what `bin/team-commit.sh` refuses, commits or exits with.** Only two strings change: the refusal text and the `--help` text. (**AC1**, **AC14**)
- **No change to any file outside the five deliverables and this task's records.** This includes:
  - nothing else under `bin/`: `bin/rework-digest.sh` and `bin/check-spec-review.sh` are untouched;
  - nothing under `tests/`: `tests/team-commit/run.sh`'s `unset GIT_CONFIG_PARAMETERS` literal stays;
  - nothing under `templates/`: the `dispatch-record` and `host-dispatch` blocks are untouched;
  - `skills/goal/SKILL.md`, `docs/loop-engineering/`, `.github/`, `README.md` / `README.ja.md`, `CHANGELOG.md` / `CHANGELOG.ja.md`, `.claude-plugin/plugin.json` and the lessons corpus.
  
  (**AC15**)
- **No change to T-1172's rule text or to the Round-cap guard.** (**AC6**, **AC10**)
- **No change to which finding classes are calibrated.** Each site keeps its class definition. (**AC3**, **AC4**, **AC5**)
- **No retroactive application** to merged review records, interventions files or `no-task.md` entries. (info-only)
- **No claim that a live reviewer or orchestrator obeys the wording.** (info-only, see the ceiling declaration)
- **No version bump, changelog, push, merge or release in this task.** (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree (worktree, except where a base blob is named), writes only under `$TMPDIR` (temporary directories are left in place, never removed), and contains no recursive delete.

Region and term names used below:
- **Remedy region** of a file: from its first line containing `GIT_CONFIG_PARAMETERS` through the first line at or after it containing `GIT_CONFIG_COUNT`. In `bin/team-commit.sh` this is the `--help` remedy. In each guide it is step 6's remedy.
- **Refusal line**: the one line of `bin/team-commit.sh` containing `GIT_CONFIG_PARAMETERS is set;`.
- **Joined (EN)**: leading spaces stripped and lines joined by one space.
- **Joined (JA)**: both that form and the form with lines joined by nothing; a JA token is present when either form carries it, and absent only when neither does.
- **Paragraph** of a guide: from the line beginning with the named bold label up to the next empty line.
- **Seam line**: the one line of `skills/run/SKILL.md` containing `Specify-seam spec-review gate (T-1092)`.
- **Codex prompt region**: the lines of `agents/code-reviewer.md` from the one line containing `Review the spec document at <spec path>` through the next line containing `Return findings as a JSON array`.
- **S6** and **SS**: the decision-2 canonical sentence with `<X>` = `invalidates the deliverable itself` and = `makes that check line's own criterion vacuous` respectively, written without markdown.
- **Base**: `git merge-base develop HEAD`, or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves.

- [ ] **AC1** `bin/team-commit.sh` states the remedy's real scope (decision 1).
  - The refusal line and the remedy region each name `unset GIT_CONFIG_PARAMETERS`, `rest of the shell` and `own shell`, each on one physical line.
  - Neither one, joined, names `for this invocation`, `for that invocation`, `for that one invocation` or `env -u`.
  - The remedy region still names `GIT_ICASE_PATHSPECS` (positive control).
  - The script parses (`bash -n`), and `--help` exits `0` printing `rest of the shell`.
  - Run from a scratch directory with `GIT_CONFIG_PARAMETERS` set, the script exits `2` with nothing on stdout, and its stderr names `GIT_CONFIG_PARAMETERS is set`, `unset GIT_CONFIG_PARAMETERS` and `rest of the shell`.
  
  Red at base: `rest of the shell` is absent.
  - check: rc=0; export LC_ALL=C; F=bin/team-commit.sh; test -s "$F" || exit 1; R=$(pwd); T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac1.XXXXXX") || exit 1; grep -F 'GIT_CONFIG_PARAMETERS is set;' "$F" > "$T/ref"; test "$(grep -c '' "$T/ref" || true)" = 1 || exit 1; awk 'index($0,"GIT_CONFIG_PARAMETERS")>0 && !s {s=1} s {print} s && index($0,"GIT_CONFIG_COUNT")>0 {exit}' "$F" > "$T/help"; grep -qF GIT_ICASE_PATHSPECS "$T/help" || exit 1; grep -qF GIT_CONFIG_COUNT "$T/help" || exit 1; for x in "$T/ref" "$T/help"; do for w in 'unset GIT_CONFIG_PARAMETERS' 'rest of the shell' 'own shell'; do grep -qF -- "$w" "$x" || rc=1; done; sed 's/^ *//' "$x" | tr '\n' ' ' > "$x.j"; for w in 'for this invocation' 'for that invocation' 'for that one invocation' 'env -u'; do grep -qF -- "$w" "$x.j"; g=$?; test "$g" -eq 1 || rc=1; done; done; bash -n "$F" || rc=1; bash "$F" --help > "$T/h" 2> "$T/he" || rc=1; grep -qF 'rest of the shell' "$T/h" || rc=1; ( cd "$T" && GIT_CONFIG_PARAMETERS="'core.x'='y'" bash "$R/$F" --message-file m -- p ) > "$T/o" 2> "$T/e"; e=$?; test "$e" -eq 2 || rc=1; test ! -s "$T/o" || rc=1; for w in 'GIT_CONFIG_PARAMETERS is set' 'unset GIT_CONFIG_PARAMETERS' 'rest of the shell'; do grep -qF -- "$w" "$T/e" || rc=1; done; test "$rc" -eq 0

- [ ] **AC2** Both guides state the remedy's real scope, EN and JA equivalent (decision 1).
  - The remedy region of `docs/adopting.md` names `unset GIT_CONFIG_PARAMETERS`, `rest of the shell` and `own shell`, each on one physical line. Joined (EN), it names none of `for this invocation`, `for that invocation`, `for that one invocation` or `env -u`.
  - The remedy region of `docs/adopting.ja.md` names `unset GIT_CONFIG_PARAMETERS`, `シェルが終わるまで` and `別のシェル`, each on one physical line. Joined (JA), it names neither `呼び出しについて解除` nor `env -u`.
  - Each region reaches its `GIT_CONFIG_COUNT` line (positive control).
  
  Review-judged: the EN and JA remedy sentences say the same thing.
  - adopter-surface: docs/adopting.md and docs/adopting.ja.md, step 6 of "Using shell-team from Codex CLI" (the `GIT_CONFIG_PARAMETERS` remedy)
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac2.XXXXXX") || exit 1; awk 'index($0,"GIT_CONFIG_PARAMETERS")>0 && !s {s=1} s {print} s && index($0,"GIT_CONFIG_COUNT")>0 {exit}' "$E" > "$T/e"; awk 'index($0,"GIT_CONFIG_PARAMETERS")>0 && !s {s=1} s {print} s && index($0,"GIT_CONFIG_COUNT")>0 {exit}' "$J" > "$T/j"; grep -qF GIT_CONFIG_COUNT "$T/e" || exit 1; grep -qF GIT_CONFIG_COUNT "$T/j" || exit 1; for w in 'unset GIT_CONFIG_PARAMETERS' 'rest of the shell' 'own shell'; do grep -qF -- "$w" "$T/e" || rc=1; done; sed 's/^ *//' "$T/e" | tr '\n' ' ' > "$T/e1"; for w in 'for this invocation' 'for that invocation' 'for that one invocation' 'env -u'; do grep -qF -- "$w" "$T/e1"; g=$?; test "$g" -eq 1 || rc=1; done; for w in 'unset GIT_CONFIG_PARAMETERS' 'シェルが終わるまで' '別のシェル'; do grep -qF -- "$w" "$T/j" || rc=1; done; sed 's/^ *//' "$T/j" | tr '\n' ' ' > "$T/j1"; sed 's/^ *//' "$T/j" | tr -d '\n' > "$T/j2"; for w in '呼び出しについて解除' 'env -u'; do for x in "$T/j1" "$T/j2"; do grep -qF -- "$w" "$x"; g=$?; test "$g" -eq 1 || rc=1; done; done; test "$rc" -eq 0

- [ ] **AC3** The run skill carries the canonical sentence at both its calibration sites (decisions 2, 3).
  - Exactly one line contains `**Verdict scope and severity calibration in the review briefing**`, and that line contains **S6**.
  - The seam line's calibration paragraph contains **SS**. That paragraph runs from `**Verdict scope and severity calibration in the spec-review briefing**` up to `**A spec-review round is not a loop iteration**`.
  - Both still contain `never ask it to withhold a finding`.
  - The step-6 line still names `process bookkeeping, QA-audit completeness or records hygiene`, and the seam paragraph still names `adversarial completeness of an enumerative`.
  - Neither contains `as a note or`.

  Review-judged, plural read (two calibrated findings in one round, one of them meeting the exception):
  - each finding is reported at its own judged severity;
  - only the finding meeting the exception gates;
  - no phrase reads as if only one finding could be calibrated.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac3.XXXXXX") || exit 1; H="A finding in a calibrated class is still reported at the severity the reviewer judges and recorded at that severity, with no Synthesis-audit-ledger downgrade row, because the calibration scopes the verdict and lowers no severity; the verdict treats that finding as non-gating unless it"; Z="and because no severity is lowered, the run skill's step-6 check of lowered ledger rows (T-1172) does not apply to it, and it does not count as a blocker or major standing under that check."; S6="$H invalidates the deliverable itself, $Z"; SS="$H makes that check line's own criterion vacuous, $Z"; grep -F '**Verdict scope and severity calibration in the review briefing**' "$F" > "$T/a"; test "$(grep -c '' "$T/a" || true)" = 1 || exit 1; grep -F 'Specify-seam spec-review gate (T-1092)' "$F" > "$T/l58"; test "$(grep -c '' "$T/l58" || true)" = 1 || exit 1; awk '{i=index($0,"**Verdict scope and severity calibration in the spec-review briefing**"); if(i==0) exit; s=substr($0,i); j=index(s,"**A spec-review round is not a loop iteration**"); if(j==0) exit; print substr(s,1,j-1)}' "$T/l58" > "$T/b"; test -s "$T/b" || exit 1; grep -qF -- "$S6" "$T/a" || rc=1; grep -qF -- "$SS" "$T/b" || rc=1; for x in "$T/a" "$T/b"; do grep -qF 'never ask it to withhold a finding' "$x" || rc=1; grep -qF 'as a note or' "$x"; g=$?; test "$g" -eq 1 || rc=1; done; grep -qF 'process bookkeeping, QA-audit completeness or records hygiene' "$T/a" || rc=1; grep -qF 'adversarial completeness of an enumerative' "$T/b" || rc=1; test "$rc" -eq 0

- [ ] **AC4** `agents/code-reviewer.md` carries the canonical sentence in spec-review mode and in its embedded Codex prompt, and the prompt stays shell-safe (decisions 2, 3).
  - **The calibration line.** Exactly one line begins `**Verdict scope and severity calibration**:`. That line:
    - contains **SS**;
    - still names `never withhold a finding` and `adversarial completeness of an enumerative`;
    - names neither `as a note or` nor `calibrates severity only`.
  - **The Codex prompt region.** `Review the spec document at <spec path>` occurs on exactly one line, and the region reaches its `Return findings as a JSON array` line and has at least three lines. With leading spaces and trailing ` \` stripped and the lines joined by one space, the region:
    - contains **SS**;
    - still names `Still report every finding you judge` and `adversarial completeness of an enumerative`;
    - does not name `as a note or`.
  - **The region stays shell-safe.**
    - It contains no backtick and no `$`.
    - Its first and last lines each contain exactly one `"`, and no line between them contains one.
    - Every line but the last ends with ` \`.
  - check: rc=0; export LC_ALL=C; F=agents/code-reviewer.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac4.XXXXXX") || exit 1; H="A finding in a calibrated class is still reported at the severity the reviewer judges and recorded at that severity, with no Synthesis-audit-ledger downgrade row, because the calibration scopes the verdict and lowers no severity; the verdict treats that finding as non-gating unless it"; Z="and because no severity is lowered, the run skill's step-6 check of lowered ledger rows (T-1172) does not apply to it, and it does not count as a blocker or major standing under that check."; SS="$H makes that check line's own criterion vacuous, $Z"; awk 'index($0,"**Verdict scope and severity calibration**:")==1' "$F" > "$T/a"; test "$(grep -c '' "$T/a" || true)" = 1 || exit 1; grep -qF -- "$SS" "$T/a" || rc=1; for w in 'never withhold a finding' 'adversarial completeness of an enumerative'; do grep -qF -- "$w" "$T/a" || rc=1; done; for w in 'as a note or' 'calibrates severity only'; do grep -qF -- "$w" "$T/a"; g=$?; test "$g" -eq 1 || rc=1; done; test "$(grep -cF 'Review the spec document at <spec path>' "$F" || true)" = 1 || exit 1; awk 'index($0,"Review the spec document at <spec path>")>0{f=1} f{print} f && index($0,"Return findings as a JSON array")>0{exit}' "$F" > "$T/x"; grep -qF 'Return findings as a JSON array' "$T/x" || exit 1; test "$(grep -c '' "$T/x")" -ge 3 || exit 1; sed 's/^ *//; s/ *\\$//' "$T/x" | tr '\n' ' ' > "$T/xj"; grep -qF -- "$SS" "$T/xj" || rc=1; for w in 'Still report every finding you judge' 'adversarial completeness of an enumerative'; do grep -qF -- "$w" "$T/xj" || rc=1; done; grep -qF 'as a note or' "$T/xj"; g=$?; test "$g" -eq 1 || rc=1; grep -qF '`' "$T/x"; g=$?; test "$g" -eq 1 || rc=1; grep -qF '$' "$T/x"; g=$?; test "$g" -eq 1 || rc=1; sed '1d;$d' "$T/x" > "$T/mid"; grep -qF '"' "$T/mid"; g=$?; test "$g" -eq 1 || rc=1; test "$(head -n 1 "$T/x" | tr -cd '"' | wc -c | tr -d ' ')" = 1 || rc=1; test "$(tail -n 1 "$T/x" | tr -cd '"' | wc -c | tr -d ' ')" = 1 || rc=1; awk 'NR>1 && p !~ / \\$/ {b=1} {p=$0} END{exit b}' "$T/x" || rc=1; test "$rc" -eq 0

- [ ] **AC5** Both guides carry the canonical sentence, EN and JA equivalent (decisions 2, 3).
  - **EN.** Exactly one line of `docs/adopting.md` begins `**What gates the verdict.**`. Its paragraph, joined (EN):
    - contains **SS**;
    - still names `nothing is withheld` and `adversarial completeness of an`;
    - does not name `as a note or`.
  - **JA.** Exactly one line of `docs/adopting.ja.md` begins `**verdict を左右するもの。**`. Its paragraph, joined (JA):
    - names each of `判断した severity のまま`, `downgrade 行は書かれない`, `non-gating`, `下げられた ledger 行の check`, `blocker または major`, `vacuous`, `何も伏せず` and `敵対的な網羅性`;
    - does not name `fast-follow として報告`.
  
  Review-judged: the JA sentence says what **SS** says.
  - adopter-surface: docs/adopting.md "What gates the verdict" and docs/adopting.ja.md "verdict を左右するもの" in the spec-review section
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac5.XXXXXX") || exit 1; H="A finding in a calibrated class is still reported at the severity the reviewer judges and recorded at that severity, with no Synthesis-audit-ledger downgrade row, because the calibration scopes the verdict and lowers no severity; the verdict treats that finding as non-gating unless it"; Z="and because no severity is lowered, the run skill's step-6 check of lowered ledger rows (T-1172) does not apply to it, and it does not count as a blocker or major standing under that check."; SS="$H makes that check line's own criterion vacuous, $Z"; test "$(awk 'index($0,"**What gates the verdict.**")==1' "$E" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"**What gates the verdict.**")==1{f=1} f && $0==""{exit} f{print}' "$E" > "$T/e"; test -s "$T/e" || exit 1; sed 's/^ *//' "$T/e" | tr '\n' ' ' > "$T/e1"; grep -qF -- "$SS" "$T/e1" || rc=1; for w in 'nothing is withheld' 'adversarial completeness of an'; do grep -qF -- "$w" "$T/e1" || rc=1; done; grep -qF 'as a note or' "$T/e1"; g=$?; test "$g" -eq 1 || rc=1; test "$(awk 'index($0,"**verdict を左右するもの。**")==1' "$J" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"**verdict を左右するもの。**")==1{f=1} f && $0==""{exit} f{print}' "$J" > "$T/j"; test -s "$T/j" || exit 1; sed 's/^ *//' "$T/j" | tr '\n' ' ' > "$T/j1"; sed 's/^ *//' "$T/j" | tr -d '\n' > "$T/j2"; for w in '判断した severity のまま' 'downgrade 行は書かれない' non-gating '下げられた ledger 行の check' 'blocker または major' vacuous '何も伏せず' '敵対的な網羅性'; do { grep -qF -- "$w" "$T/j1" || grep -qF -- "$w" "$T/j2"; } || rc=1; done; for x in "$T/j1" "$T/j2"; do grep -qF 'fast-follow として報告' "$x"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** T-1172's text is unchanged (decision 4; Non-goals).
  - The base blob of `skills/run/SKILL.md` has exactly one line containing `**Downgrade-ground check (T-1172).**` (positive control), and that exact line occurs exactly once in the head file.
  - The head file has exactly one line containing `Downgrade-ground check`, so T-1172's **AC4** stays green.
  - The base blob of `agents/code-reviewer.md` has exactly one line containing `A downgrade's ground must stand without` (positive control). That line and the two lines after it each occur exactly once, as whole lines, in the head file.
  
  Green at base by construction: this is a protected invariant that pairs with **AC3**–**AC5**.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac6.XXXXXX") || exit 1; git show "$B:skills/run/SKILL.md" > "$T/rb" 2>/dev/null || exit 1; grep -F '**Downgrade-ground check (T-1172).**' "$T/rb" > "$T/l1"; test "$(grep -c '' "$T/l1" || true)" = 1 || exit 1; test "$(grep -cxF -f "$T/l1" skills/run/SKILL.md || true)" = 1 || rc=1; test "$(grep -cF 'Downgrade-ground check' skills/run/SKILL.md || true)" = 1 || rc=1; git show "$B:agents/code-reviewer.md" > "$T/cb" 2>/dev/null || exit 1; n=$(grep -nF "A downgrade's ground must stand without" "$T/cb" | cut -d: -f1); test "$(printf '%s\n' "$n" | grep -c .)" = 1 || exit 1; sed -n "${n},$((n+2))p" "$T/cb" > "$T/l2"; test "$(grep -c '' "$T/l2")" = 3 || exit 1; while IFS= read -r x; do test "$(grep -cxF -- "$x" agents/code-reviewer.md || true)" = 1 || rc=1; done < "$T/l2"; test "$rc" -eq 0

- [ ] **AC7** The Dispatch-record sub-bullet names both paths (decision 5). Exactly one line of `skills/run/SKILL.md` contains `**Dispatch record (T-1084)**`. It names `full path`, `trivial path`, `no dispatch rows`, `step 2` and `step 4`.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac7.XXXXXX") || exit 1; grep -F '**Dispatch record (T-1084)**' "$F" > "$T/l"; test "$(grep -c '' "$T/l" || true)" = 1 || exit 1; for w in 'full path' 'trivial path' 'no dispatch rows' 'step 2' 'step 4'; do grep -qF -- "$w" "$T/l" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** The parallel "Where this fits above" bullet names both paths (decision 5; droppable first per the pre-commitment). Exactly one line of `skills/run/SKILL.md` contains `**Where this fits above**`. It names `full path`, `trivial path`, `no dispatch rows` and `step 2`.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac8.XXXXXX") || exit 1; grep -F '**Where this fits above**' "$F" > "$T/l"; test "$(grep -c '' "$T/l" || true)" = 1 || exit 1; for w in 'full path' 'trivial path' 'no dispatch rows' 'step 2'; do grep -qF -- "$w" "$T/l" || rc=1; done; test "$rc" -eq 0

- [ ] **AC9** The interventions paragraph says what happens to a Plan-time `no-task.md` entry, and the described copy fits the checker (decision 6).
  - Exactly one line of `skills/run/SKILL.md` contains `**Interventions producer discipline (T-1002)**`. It still names `no-task.md` (positive control), and names `copied into the task's own interventions file`, `stays in place`, `its origin` and `summary`.
  - Fixture, in `$TMPDIR`: a `T-1173` interventions file holding one entry whose `summary:` value cites `no-task.md` passes `bin/check-interventions.sh --task T-1173` (exit `0`).
  - Fixture, in `$TMPDIR`: the same entry with the origin on its own unindented line instead is refused (exit `1`).
  
  The fixture half is green at base. It anchors that the origin belongs inside a field value.

  Review-judged, plural read:
  - the sentence covers each Plan-time entry (zero, one or several);
  - it is append-only on both files;
  - the copy into a file holding the sentinel replaces it, per the existing entry-template line.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; C=bin/check-interventions.sh; test -s "$F" || exit 1; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac9.XXXXXX") || exit 1; grep -F '**Interventions producer discipline (T-1002)**' "$F" > "$T/l"; test "$(grep -c '' "$T/l" || true)" = 1 || exit 1; grep -qF 'no-task.md' "$T/l" || exit 1; for w in "copied into the task's own interventions file" 'stays in place' 'its origin' summary; do grep -qF -- "$w" "$T/l" || rc=1; done; printf '%s\n' '<!-- BEGIN interventions: T-1173 -->' '- intervention: human-correction' '  date: 2026-10-04' '  summary: copied from no-task.md, where it was recorded at Plan before this board entry existed; the operator corrected the task scope' '  effect: the plan was revised before Specify' '<!-- END interventions: T-1173 -->' > "$T/ok.md"; bash "$C" --task T-1173 "$T/ok.md" > "$T/o1" 2>&1; e=$?; test "$e" -eq 0 || rc=1; printf '%s\n' '<!-- BEGIN interventions: T-1173 -->' '- intervention: human-correction' '  date: 2026-10-04' '  summary: the operator corrected the task scope' '  effect: the plan was revised before Specify' 'copied from no-task.md' '<!-- END interventions: T-1173 -->' > "$T/bad.md"; bash "$C" --task T-1173 "$T/bad.md" > "$T/o2" 2>&1; e=$?; test "$e" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** A guard refusal is escalated under its own reason, and the Round-cap guard is unchanged (decision 7). The seam line still names `--stop-reason spec_review_rounds_reached` (positive control). Its refusal clause runs from `a refusal (any other exit status` up to the next `SAME_CLASS_2`. That clause:
  - names `--stop-reason guard_error`, `stderr`, `verbatim`, `re-invoke` and `CONTINUE`;
  - names neither `the same way` nor `spec_review_rounds_reached`.
  
  The base blob of `agents/code-reviewer.md` has exactly one line containing `**Round-cap guard, the first step of every pass (T-1160, issue #630)**` (positive control). That exact line occurs exactly once in the head file, and the label occurs on no other line.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac10.XXXXXX") || exit 1; grep -F 'Specify-seam spec-review gate (T-1092)' "$F" > "$T/l"; test "$(grep -c '' "$T/l" || true)" = 1 || exit 1; grep -qF -- '--stop-reason spec_review_rounds_reached' "$T/l" || exit 1; awk '{i=index($0,"a refusal (any other exit status"); if(i==0) exit; s=substr($0,i); j=index(s,"SAME_CLASS_2"); if(j==0) exit; print substr(s,1,j-1)}' "$T/l" > "$T/c"; test -s "$T/c" || exit 1; for w in '--stop-reason guard_error' stderr verbatim re-invoke CONTINUE; do grep -qF -- "$w" "$T/c" || rc=1; done; for w in 'the same way' spec_review_rounds_reached; do grep -qF -- "$w" "$T/c"; g=$?; test "$g" -eq 1 || rc=1; done; git show "$B:agents/code-reviewer.md" > "$T/cb" 2>/dev/null || exit 1; grep -F '**Round-cap guard, the first step of every pass (T-1160, issue #630)**' "$T/cb" > "$T/rg"; test "$(grep -c '' "$T/rg" || true)" = 1 || exit 1; test "$(grep -cxF -f "$T/rg" agents/code-reviewer.md || true)" = 1 || rc=1; test "$(grep -cF '**Round-cap guard, the first step of every pass (T-1160, issue #630)**' agents/code-reviewer.md || true)" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Both guides carry the matching clause (decision 8).
  - **EN.** Exactly one line of `docs/adopting.md` begins `**The round bound (T-1160, issue #630).**`. Its paragraph, joined (EN), names `--stop-reason guard_error`, `stderr`, `CONTINUE` and `spec_review_rounds_reached`.
  - **JA.** Exactly one line of `docs/adopting.ja.md` begins `**round の上限（T-1160、issue #630）。**`. Its paragraph, joined (JA), names `--stop-reason guard_error`, `stderr` and `CONTINUE`.
  
  Review-judged: the EN and JA clauses say the same thing, including that the review is not invoked again.
  - adopter-surface: docs/adopting.md "The round bound" and docs/adopting.ja.md "round の上限" paragraphs
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac11.XXXXXX") || exit 1; test "$(awk 'index($0,"**The round bound (T-1160, issue #630).**")==1' "$E" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"**The round bound (T-1160, issue #630).**")==1{f=1} f && $0==""{exit} f{print}' "$E" > "$T/e"; test -s "$T/e" || exit 1; sed 's/^ *//' "$T/e" | tr '\n' ' ' > "$T/e1"; for w in '--stop-reason guard_error' stderr CONTINUE spec_review_rounds_reached; do grep -qF -- "$w" "$T/e1" || rc=1; done; test "$(awk 'index($0,"**round の上限（T-1160、issue #630）。**")==1' "$J" | grep -c . || true)" = 1 || exit 1; awk 'index($0,"**round の上限（T-1160、issue #630）。**")==1{f=1} f && $0==""{exit} f{print}' "$J" > "$T/j"; test -s "$T/j" || exit 1; sed 's/^ *//' "$T/j" | tr '\n' ' ' > "$T/j1"; sed 's/^ *//' "$T/j" | tr -d '\n' > "$T/j2"; for w in '--stop-reason guard_error' stderr CONTINUE; do { grep -qF -- "$w" "$T/j1" || grep -qF -- "$w" "$T/j2"; } || rc=1; done; test "$rc" -eq 0

- [ ] **AC12** The shipped scripts support the documented escalation (decision 7; premise anchor, green at base).
  - `bin/rework-digest.sh --round 1 --phase review --class premise --stop-reason guard_error` exits `0` and prints `stop-reason: guard_error`. The same call with `spec_review_rounds_reached` also exits `0` (positive control).
  - `bin/check-spec-review.sh --rounds --task T-1173 --contract <an absent path under $TMPDIR>` is a refusal: an exit status other than `0` and `3`, nothing on stdout, and a non-empty stderr. This is what the refusal clause tells the orchestrator to quote.
  
  A red means the premise the wording rests on moved.
  - check: rc=0; export LC_ALL=C; D=bin/rework-digest.sh; S=bin/check-spec-review.sh; test -s "$D" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac12.XXXXXX") || exit 1; bash "$D" --round 1 --phase review --class premise --stop-reason spec_review_rounds_reached > "$T/o0" 2> "$T/e0"; e=$?; test "$e" -eq 0 || exit 1; bash "$D" --round 1 --phase review --class premise --stop-reason guard_error > "$T/o" 2> "$T/e"; e=$?; test "$e" -eq 0 || rc=1; grep -qF 'stop-reason: guard_error' "$T/o" || rc=1; bash "$S" --rounds --task T-1173 --contract "$T/absent-contract.yaml" > "$T/so" 2> "$T/se"; e=$?; test "$e" -ne 0 || rc=1; test "$e" -ne 3 || rc=1; test ! -s "$T/so" || rc=1; test -s "$T/se" || rc=1; test "$rc" -eq 0

- [ ] **AC13** Generated and synchronized files stay consistent.
  - `bin/check-prompt-sync.sh` exits `0`. This covers the contain-mode lines the run skill carries inside `:32`, and the untouched `dispatch-record` block.
  - `bin/gen-codex-agents.sh --root . --out-dir <scratch>/out` exits `0` and writes a non-empty `shell-team-code-reviewer.toml` that contains `check of lowered ledger rows (T-1172) does not apply`. `bin/check-codex-agents.sh --root . --out-dir <scratch>/out` exits `0`.
  - None of the five deliverables contains three consecutive apostrophes (each grep exit `1`).
  
  Red at base: the generated agent lacks the new sentence.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac13.XXXXXX") || exit 1; bash bin/check-prompt-sync.sh > "$T/ps" 2>&1 || rc=1; bash bin/gen-codex-agents.sh --root . --out-dir "$T/out" > "$T/gc" 2>&1 || rc=1; test -s "$T/out/shell-team-code-reviewer.toml" || rc=1; grep -qF 'check of lowered ledger rows (T-1172) does not apply' "$T/out/shell-team-code-reviewer.toml" || rc=1; bash bin/check-codex-agents.sh --root . --out-dir "$T/out" > "$T/cc" 2>&1 || rc=1; for f in agents/code-reviewer.md skills/run/SKILL.md docs/adopting.md docs/adopting.ja.md bin/team-commit.sh; do test -s "$f" || rc=1; grep -qF "'''" "$f"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC14** The suites the edited files reach stay green, and no suite with a recursive delete is run. The list is the reverse map of the five edited paths, measured by this role at `06469cb1`, plus the suites of the scripts this spec's wording names. `tests/codex-agents` is reverse-mapped too, but is left to CI on the coordinating session's instruction; **AC13** runs its two scripts directly. Each suite is first grepped for a recursive delete, and a match is a failure: that suite is not run. Otherwise the suite runs with a file-size limit and capped output, exits `0` and prints no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac14.XXXXXX") || exit 1; for s in tests/team-commit/run.sh tests/rework-digest/run.sh tests/check-spec-review/run.sh tests/check-interventions/run.sh tests/check-prompt-sync/run.sh tests/bin-help/run.sh tests/codex-skeleton-hygiene/run.sh tests/check-adopter-docs/run.sh tests/check-invocation-path/run.sh tests/check-oversight/run.sh tests/check-refreeze-grant/run.sh tests/team-init/run.sh tests/trial-recipe/run.sh tests/install/run.sh; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; ( ulimit -f 200000; set -o pipefail; bash "$s" < /dev/null 2>&1 | head -c 20000000 > "$T/log" ) || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that reads one of the five edited paths, at which point this named list no longer equals the reverse map it was measured as.

- [ ] **AC15** The change set stays inside the deliverables and this task's records (Non-goals). The measured set is the union of four reads:
  - `git diff --no-renames --name-only <base>...HEAD`;
  - `git diff --no-renames --cached --name-only`;
  - `git diff --no-renames --name-only`;
  - `git ls-files --others --exclude-standard`.
  
  No read may fail. The union names this spec (positive control). Every path in it is one of:
  - `bin/team-commit.sh`, `skills/run/SKILL.md`, `agents/code-reviewer.md`, `docs/adopting.md`, `docs/adopting.ja.md`;
  - `.shell-team/todo.md`, `.shell-team/interventions/no-task.md`;
  - a `T-1173`-named file under `.shell-team/specs`, `reviews`, `provenance` or `interventions`;
  - a file directly under `.shell-team/retros` or `.shell-team/rollups`.
  
  Green at base: it is an invariant. This criterion is merge-point-scoped and is expected to go stale once later tasks' files land on `develop`. Do not merge-range it.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac15.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B...HEAD" || echo __ERR__; git diff --no-renames --cached --name-only || echo __ERR__; git diff --no-renames --name-only || echo __ERR__; git ls-files --others --exclude-standard || echo __ERR__; } > "$T/u"; grep -qxF __ERR__ "$T/u"; g=$?; test "$g" -eq 1 || exit 1; grep -qxF .shell-team/specs/T-1173-wording-followups.md "$T/u" || exit 1; sort -u "$T/u" | grep -vE '^(bin/team-commit\.sh|skills/run/SKILL\.md|agents/code-reviewer\.md|docs/adopting\.md|docs/adopting\.ja\.md|\.shell-team/todo\.md|\.shell-team/interventions/no-task\.md|\.shell-team/(specs|reviews|provenance|interventions)/T-1173[-.][^/]*|\.shell-team/(retros|rollups)/[^/]*)$' > "$T/bad"; test ! -s "$T/bad" || rc=1; test "$rc" -eq 0

- [ ] **AC16** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1173-wording-followups.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1173-ac16.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes:**

1. **Where the `GIT_CONFIG_PARAMETERS` remedy is run.**
   - An interactive POSIX shell (bash, zsh), where a bare `unset` lasts for the rest of that shell.
   - A sandboxed tool call, where each command runs in its own shell.
   - The variable set non-empty or set empty. Both stay refused, as today.
2. **Calibrated findings in one review round.**
   - Zero, one, two or more of them.
   - Each one judged blocker, major, minor or nit.
   - One that meets the exception (vacuous criterion at the Specify seam, invalidates the deliverable at step 6) beside one that does not.
   - Passes that disagree on a calibrated finding's severity.
3. **Ledger rows beside calibrated findings.**
   - A calibrated finding with no ledger row, which is the case this task settles.
   - A ledger row that lowers a calibrated finding anyway. T-1172's test still governs it, and the calibration is not a ground for it.
4. **Hosts.** The Claude Code host, where `code-reviewer` runs the embedded `codex exec` spec-review prompt. The Codex CLI host, which reads the same `agents/code-reviewer.md` prose.
5. **Paths through the run skill.** The full path, where step 2 creates the entry and the dispatch rows are transcribed. The trivial path, where no dispatch rows are transcribed.
6. **Plan-time interventions.**
   - No entry, one entry or several recorded in `no-task.md` before this task's entry exists.
   - The task's own file holding the sentinel, so the first copy replaces it, or already holding entries.
7. **Round-guard outcomes.**
   - `CONTINUE` and `APPROVED`, each exit `0`.
   - `STOP:spec_review_rounds_reached`, exit `3`.
   - A refusal: exit `1` or `2` with empty stdout, or any outcome with no stdout.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Non-POSIX interactive shells (fish, csh) whose command for removing a variable is not `unset`. The remedy names the POSIX form, as it does today.
2. A per-invocation `env -u` (or other wrapper) form of the commit invocation (Non-goals).
3. Machine detection of whether a finding falls in a calibrated class. No checker parses findings.
4. A reviewer that labels an in-scope finding as calibrated in order to keep it from gating. The coordinating session's reading judges that case, and no further wording is added for it.
5. Retroactive application to merged review records, interventions files or `no-task.md` entries recorded before this change.
6. A `no-task.md` entry that was not recorded during this task's own Plan. It belongs to other work and is not copied.

<!-- END intent-block: T-1173 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Keep `unset GIT_CONFIG_PARAMETERS`; say it lasts for the rest of the shell, and covers one invocation only in a per-command shell (decision 1) | **AC1**, **AC2** |
| 2 | No `env -u` form (decision 1, Non-goals) | **AC1**, **AC2** (absence), **AC15** |
| 3 | The refusal stays one line; refusal class and exit unchanged (decision 1) | **AC1** (one line; exit 2 as run), **AC14** (team-commit suite) |
| 4 | EN/JA equivalent (decision 1, decision 2, decision 8) | **AC2**, **AC5**, **AC11** (tokens + review-judged) |
| 5 | One canonical sentence at every calibration site; exception slot only (decision 2) | **AC3**, **AC4**, **AC5** |
| 6 | Remove "reported as a note or a fast-follow"; keep each class definition and the independence clause (decision 2, Non-goals) | **AC3**, **AC4**, **AC5** |
| 7 | Six sites, including the shell-safe Codex prompt (decision 3) | **AC3**, **AC4**, **AC5** |
| 8 | T-1172's text byte-identical (decision 4, Non-goals) | **AC6** |
| 9 | Dispatch-record sub-bullet and `:323` name both paths (decision 5) | **AC7**, **AC8** |
| 10 | `dispatch-record` block and its consumers not edited (decision 5) | **AC15**, **AC13** (prompt-sync) |
| 11 | Plan-time `no-task.md` entry copied, origin cited in `summary:`, original stays (decision 6) | **AC9** |
| 12 | Refusal escalated with `guard_error`, stderr quoted verbatim, no re-invoke, never `CONTINUE`; cap branch keeps its reason (decision 7) | **AC10** |
| 13 | `rework-digest.sh` and `check-spec-review.sh` unchanged and already support it (decision 7) | **AC12**, **AC15** |
| 14 | Round-cap guard unchanged (decision 7, Non-goals) | **AC10** |
| 15 | Guides carry the matching clause (decision 8) | **AC11** |
| 16 | Generated and synchronized files consistent | **AC13** |
| 17 | Suites the edited files reach stay green; none with a recursive delete run | **AC14** |
| 18 | No change outside the deliverables and records (Non-goals) | **AC15** |
| 19 | Spec declarations and board conformant | **AC16** |
| 20 | No retroactive application (Non-goals) | info-only (not promoted to AC) — concerns records this task does not touch, and **AC15** already keeps them untouched |
| 21 | No claim of live obedience (Non-goals) | info-only (not promoted to AC) — a disclosure of the ceiling, not a property of the diff |
| 22 | No version bump, changelog, push, merge or release (Non-goals) | info-only (not promoted to AC) — loop and release actions; **AC15** keeps `CHANGELOG*` and `plugin.json` out of the diff |
| 23 | Pre-commitment drop order (Goal) | info-only (not promoted to AC) — a disposition for the loop to execute, not a property of the diff |

## Symmetry table (#632, site × clause)

Cells name what the criterion checks. "review" means the reviewer judges it.

| Site | Canonical sentence | Exception slot | Class definition kept | Independence kept | "as a note or" removed | Shell safety |
|---|---|---|---|---|---|---|
| run skill step 6 (`:109`) | **S6**, **AC3** | invalidates the deliverable itself | `process bookkeeping, QA-audit completeness or records hygiene` | `never ask it to withhold a finding` | **AC3** | n/a: markdown |
| run skill Specify-seam paragraph (`:58`, mid-line) | **SS**, **AC3** | makes that check line's own criterion vacuous | `adversarial completeness of an enumerative` | `never ask it to withhold a finding` | **AC3** | n/a: markdown |
| code-reviewer spec-review calibration (`:182`) | **SS**, **AC4** | same | `adversarial completeness of an enumerative` | `never withhold a finding` | **AC4** (also `calibrates severity only` removed) | n/a: markdown |
| code-reviewer embedded Codex prompt (`:193`–`:200`) | **SS**, **AC4** | same | `adversarial completeness of an enumerative` | `Still report every finding you judge` | **AC4** | **AC4**: no backtick, no `$`, no inner `"`, ` \` continuation |
| `docs/adopting.md` "What gates the verdict" | **SS**, **AC5** | same | `adversarial completeness of an` | `nothing is withheld` | **AC5** | n/a: prose |
| `docs/adopting.ja.md` "verdict を左右するもの" | JA tokens, **AC5**, plus review | `vacuous` | `敵対的な網羅性` | `何も伏せず` | **AC5** (`fast-follow として報告`) | n/a: prose |

**Singular-determiner read, against a plural instance.** The instance is one review round with two calibrated findings, A judged `major` and B judged `minor`, where A's gap makes its own criterion vacuous and B's does not.
- "A finding in a calibrated class" binds each finding separately.
- "That finding" and "it" are per finding, so A gates and B does not.
- Neither gets a ledger downgrade row.
- B does not count as a blocker or major standing under T-1172's check (it is minor anyway). A gates through the exception, not through that check.
- The remaining singulars are genuinely single: "the verdict" (one per round), "the calibration" (one rule per site), "the run skill's step-6 check of lowered ledger rows (T-1172)" (one check), and "that check line's own criterion" (one criterion per check line, as the existing "bound to that one criterion" clause already says).

No surviving cardinality-one defect was found. The freeze sweep re-reads the shipped sentence the same way.

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `docs/adopting.md` | step 6 remedy (`:620`–`:626`); "What gates the verdict" (`:1221`–`:1229`); "The round bound" (`:1253`–`:1274`) | this-task |
| `docs/adopting.ja.md` | step 6 remedy (`:620`–`:626`); "verdict を左右するもの" (`:1182`–`:1189`); "round の上限" (`:1202`–`:1222`) | this-task |
| `docs/loop-engineering/specify-seam-review.md` | `:37` "once `pm-spec` has created the task's board entry" | not-applicable: no "step 2", and the trivial path creates the entry too, so the sentence is accurate on both paths |
| `docs/loop-engineering/spec-authorship-entry.md` | `:30`–`:31`, same wording | not-applicable, same reason |
| `README.md` / `README.ja.md` | none | no sentence describes these four surfaces |
| `CHANGELOG.md` / `CHANGELOG.ja.md` | `:12` quotes the v2.8.x remedy wording | historical release notes, not edited; the release that ships this task adds its own entry |

## Version derivation note

Premise (relayed from the Routing Map, operator-approved): PATCH v2.8.6.
- **Headline test: not met.** Nothing new becomes possible for an adopter. Four wordings now match what their mechanisms do.
- **Default-reachability test: met.** The refusal text, the review briefing and the round guard are on default paths.

Derived: PATCH. Verdict: match.

## Blast radius

Downstream impact on merged specs is judged by CI and this task's own check lines, not by re-running past specs' check lines (operator ruling). This role searched `.shell-team/specs` by literal string, and that search is a disclosed lower bound, not a full-population diff. It found these merged criteria that read the edited lines:
- `T-1172` **AC4** requires exactly one `Downgrade-ground check` line in `skills/run/SKILL.md`. It **stays green**: the canonical sentence refers to that check as "the run skill's step-6 check of lowered ledger rows (T-1172)" and adds no line carrying the literal, and this task's **AC6** locks the count at one.
- `T-1172` **AC5** and **AC3** are byte-scoped against T-1172's own base. They are already merge-point-stale.
- `T-1171` quotes `for this invocation` / `for that one invocation` (`:129`, `:159`, `:277`). Criteria asserting that wording flip.
- `T-1167` **AC4**/**AC5** read step 1 and `:32`. Their tokens survive this change by this role's reading.
- `T-1084`, `T-1091`, `T-1092` and `T-1100` name `Dispatch record (T-1084)` / `Where this fits above`. They are not measured here.

The sentence names T-1172's check by description rather than by its bullet name, specifically so that T-1172 **AC4**, which shipped one release ago, is not flipped (coordinating-session correction before the freeze sweep).

## Assumptions

- **Relayed:** the four issue bodies are the coordinating session's fetch of 2026-10-04, read from its scratch file. This role cannot reach the tracker. The sites they name were re-measured here and match.
- **Relayed, measured, partly not confirmed:** the Routing Map's anchors.
  - Matched as relayed: `bin/team-commit.sh` `:94`–`:96`, `:178`; `tests/team-commit/run.sh` `:576`–`:580`; `skills/run/SKILL.md` `:32`, `:46`, `:58`, `:104`, `:109`, `:323`; `agents/code-reviewer.md` `:182`, `:184`, `:197`–`:199`; `docs/adopting.md` `:620`–`:624`, `:1221`–`:1229`, `:1264`–`:1273`; `docs/adopting.ja.md` `:620`–`:623`, `:1182`–`:1189`, `:1212`–`:1221`; `bin/rework-digest.sh` `:249`; `bin/check-spec-review.sh` `:84`–`:87`; `templates/prompt-blocks/dispatch-record.md` `:4`; `docs/loop-engineering/specify-seam-review.md` `:37`.
  - Small differences:
    - `docs/loop-engineering/spec-authorship-entry.md`'s phrase spans `:30`–`:31`.
    - The T-1172 rule in `agents/code-reviewer.md` is `:106`–`:108`. `:105` is the pre-existing ledger paragraph.
    - The relayed "first-token matching" premise is not stated in `host-dispatch.md` `:5`. That line states the "one identical invocation, never retried in another form" rule this spec relies on. The first-token wording comes from the 2026-10-01 lessons entry (Codex CLI host: "only through one invocation of `bash "<plugin root>/bin/team-commit.sh"`").
  - **Not confirmed:** "`tests/codex-agents/run.sh` contains recursive deletes." This role's search found `rm -f` (`:210`, `:223`), `rmdir` (`:986`–`:1008`) and a comment mentioning a recursive delete (`:974`), but no `rm -r`/`rm -R` and no `find … -delete`. The suite is still left out of **AC14** as instructed, and the discrepancy is a finding about the hand-off for the coordinating session to record.
- **Measured here (read):**
  - No file under `bin/` or `tests/*/run.sh` matches `rm -[a-zA-Z]*[rR]` or `find .*-delete`. So every suite in **AC14** passes its own pre-run grep.
  - No `env -u` occurs in `bin/team-commit.sh`, `docs/adopting.md`, `docs/adopting.ja.md` or `templates/prompt-blocks/host-dispatch.md`.
- **Count premises at the base, own coinage (this role's reading; the freeze run measures each live at `06469cb1`):**
  - `rest of the shell`, `シェルが終わるまで` and `別のシェル` occur 0 times in the four S1 files. `own shell` occurs in `docs/adopting.md` only outside the remedy region (`:547`, `:581`, `:590`, `:731`, `:764`).
  - `severity the reviewer judges`, `Synthesis-audit-ledger downgrade row`, `non-gating`, `full path`, `no dispatch rows`, `stays in place` and `copied into the task` occur 0 times in `skills/run/SKILL.md`, `agents/code-reviewer.md` and the two guides.
  - `guard_error` occurs in `skills/run/SKILL.md` only at `:86` (outside the seam line), and in neither guide.
  - `check of lowered ledger rows` occurs 0 times in `agents/code-reviewer.md`, `skills/run/SKILL.md` and the two guides. That is why **AC13**'s generated-agent token is red at base. `下げられた ledger 行の check` occurs 0 times in `docs/adopting.ja.md`.
  - `Downgrade-ground check` (borrowed, T-1172's coinage) occurs on exactly one line of `skills/run/SKILL.md` (`:104`) by this role's reading. **AC6** asserts that count stays at one; the freeze run measures it at `06469cb1`.
  - So **AC1**, **AC2**, **AC3**, **AC4**, **AC5**, **AC7**, **AC8**, **AC9** (its token half), **AC10**, **AC11** and **AC13** are red at base.
  - **AC6**, **AC12**, **AC14** and **AC15** are green at base. Each is an invariant, a premise anchor or a regression suite, and the reason is stated in its criterion. **AC16** is green once this board entry exists.
- **Borrowed-vocabulary sweep:** the following are another document's tokens. Each is asserted present (never `= 0`), and each line or anchor occurs once by this role's reading. The freeze run measures them at `06469cb1`.
  - `GIT_CONFIG_PARAMETERS is set;`, `GIT_ICASE_PATHSPECS`, `GIT_CONFIG_COUNT` (`bin/team-commit.sh`);
  - `**Verdict scope and severity calibration in the review briefing**`, `Specify-seam spec-review gate (T-1092)`, `**Verdict scope and severity calibration in the spec-review briefing**`, `**A spec-review round is not a loop iteration**`, `a refusal (any other exit status`, `SAME_CLASS_2`, `--stop-reason spec_review_rounds_reached`, `**Downgrade-ground check (T-1172).**`, `**Dispatch record (T-1084)**`, `**Where this fits above**`, `**Interventions producer discipline (T-1002)**`, `never ask it to withhold a finding`, `process bookkeeping, QA-audit completeness or records hygiene` (`skills/run/SKILL.md`);
  - `**Verdict scope and severity calibration**:`, `Review the spec document at <spec path>`, `Return findings as a JSON array`, `A downgrade's ground must stand without`, `**Round-cap guard, the first step of every pass (T-1160, issue #630)**`, `never withhold a finding`, `Still report every finding you judge`, `adversarial completeness of an enumerative` (`agents/code-reviewer.md`);
  - `**What gates the verdict.**`, `**The round bound (T-1160, issue #630).**`, `nothing is withheld` (`docs/adopting.md`); `**verdict を左右するもの。**`, `**round の上限（T-1160、issue #630）。**`, `何も伏せず`, `敵対的な網羅性` (`docs/adopting.ja.md`).
- **Process-group termination** on timeout for **AC14** relies on `bin/check-acs.sh`'s own `CHECK_ACS_TIMEOUT` handling, the same shape T-1172's **AC12** used. The freeze run states whether that kills the whole group, or runs the suites under its own group-kill wrapper.
- The next task id is T-1173. The board's highest is T-1172 (in `## Done`), and the only `T-1173` file under `.shell-team/` is the interventions record.

## Open questions

- none blocking.
- Non-blocking, noted for the reviewer: `agents/code-reviewer.md`'s Fast-follow disposition rule speaks of deferred "minor / nit" findings. A calibrated finding judged `major` under an `APPROVE` is still "recorded and dispositioned rather than discarded" under the existing step-6 and Specify-seam clauses, which this task keeps. This spec does not widen the Fast-follow rule.

## Notes for engineer

- **Files touched:**
  - `bin/team-commit.sh`: two strings, the refusal line and the `--help` remedy.
  - `skills/run/SKILL.md`: `:32`, `:46`, `:58` (two mid-line edits), `:109`, `:323`.
  - `agents/code-reviewer.md`: `:182`, and the embedded Codex prompt `:193`–`:200`.
  - `docs/adopting.md` and `docs/adopting.ja.md`: three paragraphs each.
- **Required literals, and which check needs them.** Every required literal must sit on **one physical line**: never break a line inside it, and break wrapped prose only at a space.
  - **AC1**: in the refusal line and in the `--help` remedy lines, `unset GIT_CONFIG_PARAMETERS`, `rest of the shell` and `own shell`, with no `for this invocation`, `for that invocation` or `for that one invocation`. Keep the refusal one line.
    - Suggested refusal: `GIT_CONFIG_PARAMETERS is set; it can carry arbitrary git configuration (for example a hooks path); run unset GIT_CONFIG_PARAMETERS and re-run (in an interactive shell the unset lasts for the rest of the shell; it covers one invocation only where each command runs in its own shell, as in a sandboxed tool call)`.
    - The `--help` remedy gets the same content, wrapped at spaces, still before the `GIT_CONFIG_COUNT` clause.
  - **AC2**: EN step 6 gets the same three literals. JA step 6 gets `unset GIT_CONFIG_PARAMETERS`, `シェルが終わるまで` and `別のシェル`, and drops `その 1 回の呼び出しについて解除できる`. Suggested JA: `` `unset GIT_CONFIG_PARAMETERS` で解除できる。対話シェルでの `unset` は、実行したそのシェルが終わるまで有効で、1 回の呼び出しに限られるのは、sandbox のツール呼び出しのようにコマンドごとに別のシェルで動く場合だけである。 ``
  - **AC3**/**AC4**/**AC5**: the canonical sentence verbatim, as plain text with no backticks or other markup inside it. Use **S6** at `:109`, and **SS** at `:58`, `:182`, the Codex prompt and EN "What gates the verdict".
    - Remove the "reported as a note or a fast-follow … not as (a verdict-gating) `Blocker` or `Major`" clause at each site. The sentence replaces it.
    - Keep each site's class definition and independence clause (the tokens are listed in **AC3**–**AC5**).
    - At `:182`, also reword "This calibrates severity only", because the calibration now lowers no severity. For example: "This calibration scopes the verdict only".
    - Avoid `as a note or` anywhere in those regions.
  - **AC4**, the Codex prompt:
    - Wrap the sentence over continuation lines, each ending ` \`, with no backtick, no `$` and no `"` except the opening and closing quotes.
    - Keep `Still report every finding you judge` and the class definition, and keep the closing `Return findings as a JSON array …"` line last.
    - `tests/codex-skeleton-hygiene` (**AC14**) also locks this block's shape.
  - **AC5**, JA: tokens `判断した severity のまま`, `downgrade 行は書かれない`, `non-gating`, `下げられた ledger 行の check`, `blocker または major`, `vacuous`. Keep `何も伏せず` and `敵対的な網羅性`, and drop `fast-follow として報告`. Suggested JA: `較正の対象となる class の finding も、reviewer が判断した severity のまま報告・記録され、Synthesis audit ledger に downgrade 行は書かれない（較正は verdict の範囲を決めるもので、severity を下げない）。verdict はその finding を、それがその check 行自身の criterion を vacuous にしない限り non-gating として扱う。severity が下がっていないので、run skill の step 6 にある下げられた ledger 行の check（T-1172）はこれに適用されず、その check の下で残った blocker または major としても数えない。`
  - **AC6**: do not touch `skills/run/SKILL.md` `:104` or `agents/code-reviewer.md` `:106`–`:108`. **No new line in `skills/run/SKILL.md` may contain `Downgrade-ground check`.** Refer to that check only as the canonical sentence does ("the run skill's step-6 check of lowered ledger rows (T-1172)"). **AC6** fails if the literal appears on a second line, and so would T-1172's **AC4**.
  - **AC7**/**AC8**: `full path`, `trivial path`, `no dispatch rows`, and `step 2` (plus `step 4` at `:46`). Suggested insertion at `:46`: "… at the Specify-to-Implement seam below — on the full path once `pm-spec` has created that entry in step 2 and before `engineer` is invoked in step 4; on the trivial path (step 1's trivial mode) no dispatch rows are transcribed — see …". Mirror it at `:323`.
  - **AC9**: one added sentence in `:32` naming `no-task.md`, `copied into the task's own interventions file`, `its origin`, `summary` and `stays in place`. For example: "Once the task's board entry exists, each entry recorded in `no-task.md` during this task's Plan is copied into the task's own interventions file as a well-formed entry that cites its origin in its `summary:` value, and the `no-task.md` entry stays in place (both files are append-only)."
    - Do not alter the two contain-mode substrings already in `:32`: "A routine gate response — … gets no entry." and "Every append to an interventions file is committed immediately, …". `bin/check-prompt-sync.sh` (**AC13**) requires them verbatim.
  - **AC10**: rewrite only the refusal clause on `:58`, keeping its opening words `a refusal (any other exit status`. Name `--stop-reason guard_error`, `stderr`, `verbatim`, `re-invoke` and `CONTINUE`, and use neither `the same way` nor `spec_review_rounds_reached` inside the clause.
    - For example: "a refusal (any other exit status, or no stdout) is a stop for its own reason: do not re-invoke the review, escalate by running `bash "<plugin root>/bin/rework-digest.sh" --stop-reason guard_error` with the same per-round records, quote the guard's stderr verbatim in the escalation, and never read it as `CONTINUE`."
    - The clause ends where `Each `SAME_CLASS_2:` begins.
  - **AC11**: add to each round-bound paragraph, after its refusal sentence, a clause naming `--stop-reason guard_error` and `stderr` (EN example: "A refusal from the guard itself also stops the review: the loop does not invoke it again, escalates through the rework digest with `--stop-reason guard_error`, and quotes the guard's stderr verbatim."). Keep `CONTINUE` and `spec_review_rounds_reached` in the paragraph.
- **Do not edit** `templates/` (including `dispatch-record.md` and `host-dispatch.md`), `tests/` (`tests/team-commit/run.sh` `:577` must keep finding `unset GIT_CONFIG_PARAMETERS`), `skills/goal/SKILL.md`, `docs/loop-engineering/`, any other `bin/` script, README, CHANGELOG or `plugin.json` (**AC15**).
- **Not run in any check line:** `tests/codex-agents/run.sh` (CI covers it; **AC13** runs `gen-codex-agents.sh`/`check-codex-agents.sh` directly).
- **Mutation self-check (optional):** confirm that deleting `rest of the shell` from the refusal reddens **AC1**, that removing the backslash from one Codex-prompt continuation line reddens **AC4**, and that restoring `escalate the same way` reddens **AC10**. Run each under `ulimit -f` with capped output, scratch in `$TMPDIR`, and restore every file afterwards.
- Measured-at-ref command check: not applicable. No deliverable prints a command beside a `measured at <ref>` label.
- Recursive deletion: none in any file you write or in any check line here. Leave temp files under `$TMPDIR`.
