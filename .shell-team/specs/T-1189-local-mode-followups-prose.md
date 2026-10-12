# Prose follow-ups: the freeze-sweep item's re-freeze trigger, the invocation-path comment, and the local-mode summary qualifiers in the README, skills and migration guide

**Status**: READY_FOR_ENG
**Owner**: pm-spec
**Task ID**: T-1189

## Problem

Four open follow-up issues each name a sentence that is true for its main case but says too little, or names an outdated mechanism. The fix in each case is wording only.

- **#737.** The run skill's freeze-sweep item for per-checkout values (added by T-1188) routes such a line through a re-freeze trigger without naming the trigger. It also says the line "passes only on the checkout that wrote it", which does not fit a per-run value such as a timestamp.
- **#738.** A header comment in `bin/check-invocation-path.sh` describes the sandbox exclusion as a first-token match. That was the rule before Claude Code 2.1.278.
- **#721.** The README and the setup / team-init skill summaries of what setup reports in `local` record mode leave out two outcomes: a base dir already committed in HEAD, and a base path that cannot be quoted safely. The setup skill also says "there is nothing to stage" right beside the root `.gitignore` alternative, which is itself a change someone commits.
- **#723.** Three sentences of the local-mode migration guide (EN and JA, lines 20, 70 and 89) each leave out one outcome that a script produces. The T-1185 claim inventory cites a blank line, `bin/team-mode.sh:86`, in three rows.

Two further items sit on the same issues but were already delivered by T-1184 and are recorded here as measured premises, not edited: #714 (all three items) and #716 item 4.

## Summarized sources

- Issue #737 (body supplied by the coordinating session; this role read it in full) — two edits only: name the trigger ("broken as a command") and replace the checkout clause with a value-equality statement. `bin/check-prompt-sync.sh` stays green.
- Issue #738 — the comment's conclusion is kept and only the mechanism it names changes. The issue says "no reader-visible output". That is **contradicted by measurement**: see `bin/check-invocation-path.sh` below.
- Issue #721 — three items. (1) README lines 77 and 99 describe only the uncommitted flow. (2) README line 51, `skills/setup/SKILL.md:16` and `skills/team-init/SKILL.md:67` omit the outcome where no line is printed. (3) `skills/setup/SKILL.md:91`'s staging clause sits beside the `.gitignore` alternative. A fourth item (the README durability clause) is waived on T-1184's board entry.
- Issue #723 — three items plus a nit. (1) Line 20 applies only when `.codex/agents` is not already ignored. (2) Line 70 lacks the no-command exception for an unsafe path. (3) Line 89 omits the extra-file report. (Nit) The inventory anchor `bin/team-mode.sh:86` is a blank line; it should be 87 or 90. The guide keeps its 89-line structure and its fences.
- Issues #714 and #716. #714's three items, and #716 item 4 (the `rc=n/a` docs wording), are what T-1184 delivered. #716 items 1–3 are `bin/check-pii-shapes.sh` behaviour and are out of scope here.
- `skills/run/SKILL.md:76` (at `68873e2c`). This is the sub-bullet starting `     - **Per-checkout value spliced into a compared stream (T-1188, issue #734)**:`. It contains "such a line passes only on the checkout that wrote it, so it is treated as a broken check line". Its scope clause starts `**Scope, stated because this item's position beside the `Cross-join step``. The string `broken as a command` occurs 0 times in this file (Grep tool).
- `skills/run/SKILL.md:94`. This is the `**Reviewer records in local record mode (T-1183).**` line, which is #714 item 3, already delivered.
- `docs/tuning-oversight.md:136`, `docs/tuning-oversight.ja.md:122` and `agents/pm-spec.md:103`. These name the class-M trigger as "repairing a line that is broken as a command, vacuous, or measured-contradictory". That is the trigger name AC1 carries over.
- `bin/check-invocation-path.sh`:
  - Lines 21–23: "a Claude Code sandbox matches its own exclusion patterns on a command line's first token, so a wrapper-embedded `codex exec` invocation can never run outside the sandbox".
  - Lines 2–90 are all comment lines, and line 91 is the first non-comment line.
  - `print_help` (line 159) prints every comment line from line 2 up to the first non-comment line. So lines 21–23 **are** part of `--help` output.
  - Line 109's "first token alone" concerns field validation and is not in scope.
- `bin/codex-capture.sh:15-18`. Patterns "used to match on a command line's leading token alone; Claude Code 2.1.278 changed this so a command is exempted only when EVERY part of it matches". This is the wording AC2 aligns to.
- `bin/team-setup.sh`:
  - `:436-437`: when `.codex/agents` is already ignored, an `Already in place:` item is written and nothing is appended.
  - `:819-820`: in `local` mode, a base path with a character outside `A-Za-z0-9._/-` gets a `Required:` item with no printed line.
  - `:1002-1005` and `:1026-1027`: in `tracked` mode, the same unsafe path gets "no command for it".
  - `:797`: in `local` mode, a base dir committed in HEAD gets a `Remains the operator's decision:` item and no command.
  - `:823`: the `local` exclude-line item, with "Setup edits neither file and stages nothing".
- `bin/check-codex-agents.sh:226`. An extra `shell-team-*.toml` the generator does not own is a violation line. `:232-236`: any violation exits 1, and only a clean run prints `… in sync with …`.
- `bin/team-mode.sh:86` is blank, `:87` is the `local` branch and `:90` prints `tracked`.
- `docs/adopting.md:111` ("Two limits of that report", with the unsafe-path case) and `docs/adopting.ja.md:115`. Pointed to; not edited.
- `docs/migrating-to-local-mode.md` / `.ja.md` (at `68873e2c`). Both have 89 lines. Lines 13 and 38 already state the unsafe-path no-line case with the token `A-Za-z0-9._/-`. Lines 20, 70 and 89 are quoted in the Problem.
- `.shell-team/specs/T-1185-local-mode-migration-guide.md`:
  - `<!-- END intent-block: T-1185 -->` is at line 234, and `## Claim inventory` starts at 236 (mutable; "rewritten whenever the EN guide's line numbers move").
  - The rows `| EN 7 |`, `| EN 24 |` and `| EN 68 |` cite `bin/team-mode.sh:86`.
  - Row `| EN 20 |` cites `bin/team-setup.sh:425` and `:444`, row `| EN 70 |` cites `bin/team-setup.sh:134`, and row `| EN 89 |` cites `bin/check-codex-agents.sh:236`.
- `bin/check-adopter-docs.sh:30-40`. A `this-task` `- shipped-docs:` path must appear as a literal substring in one of this spec's `- check:` or `- adopter-surface:` lines.
- `bin/check-intent.sh:87`. Usage is `check-intent.sh [--] <spec.md> <board.md>`.
- Already-delivered anchors (Grep tool):
  - `agents/engineer.md:55` ("under the base dir") — #714 item 1.
  - `skills/goal/SKILL.md:46` and `:48` (`team-mode.sh`, "under the base dir") — #714 item 2.
  - `docs/pii-controls.md:147` and `docs/pii-controls.ja.md:138` (`rc=n/a`) — #716 item 4.

## Goal

<!-- BEGIN intent-block: T-1189 -->

- user-visible: yes — adopters read the README, the setup and team-init skill instructions their agent follows, and the migration guide; each now states the outcome it previously left out.
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- shipped-docs: docs/migrating-to-local-mode.md — this-task
- shipped-docs: docs/migrating-to-local-mode.ja.md — this-task
- shipped-docs: skills/setup/SKILL.md — this-task
- shipped-docs: skills/team-init/SKILL.md — this-task
- shipped-docs: skills/run/SKILL.md — this-task
- verification-class: mechanism — the diff reaches `bin/check-invocation-path.sh` (comment lines that `--help` prints) and three skill files that agents execute as instructions. No logic line changes (**AC2** proves the non-comment lines are byte-identical). The full-population downstream inventory is replaced by CI plus this task's own check lines, as disclosed in `## Blast radius`.
- verification-ceiling: unit-and-static — **AC1**–**AC13** are settled in a plain checkout by string presence and absence, byte-scoped comparisons against `68873e2c` blobs, line-number locks, and checker and suite exit codes. **AC14** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: not-applicable — no open predecessor PR; the branch `feature/local-mode-followups-prose` is cut from `develop` at `68873e2c`, and every base-side read uses that fixed commit after `git cat-file -e "68873e2c^{commit}"`.

**Goal (one sentence).** The run skill's per-checkout freeze-sweep item names the "broken as a command" trigger and states its condition as value equality, the `bin/check-invocation-path.sh` header names the every-part matching rule, and the README, the setup and team-init skills, and the migration guide (EN and JA at unchanged line numbers) each state the outcome they omitted — every new qualifier backed by a cited script line. The T-1185 claim inventory cites live lines, and nothing else changes.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — #737.** One edit to the `Per-checkout value spliced into a compared stream` sub-bullet (**AC1**):
  - It names the trigger `broken as a command`.
  - It replaces "passes only on the checkout that wrote it" with a statement that the line passes only while the spliced value happens to equal the fixed expectation.
  - The title prefix and the scope clause stay byte-identical, because T-1188's spec checks read the title.
- **D2 — #738.** The comment names the every-part rule (Claude Code 2.1.278) and keeps the conclusion that a wrapper-embedded invocation never runs outside the sandbox. Comment lines only; shellcheck and the suite stay green (**AC2**).
- **D3 — #721.** Three summary qualifiers:
  - (1) README lines 77 and 99 say the exclude-line outcome is for a base dir not yet committed (**AC3**).
  - (2) README line 51, the setup skill's line 16 and the team-init skill's record-mode paragraph name the no-line outcome for a path outside `A-Za-z0-9._/-` (**AC4**).
  - (3) The setup skill's `local`-mode paragraph says no base-dir record is staged and that a `.gitignore` edit is a separate change the operator commits (**AC5**).
- **D4 — #723.** Lines 20, 70 and 89 of both guides gain one qualifier each (**AC6**–**AC8**). The T-1185 inventory rows are corrected outside its frozen block (**AC9**).
- **D5 — lockstep and exclusions.** The README and guide edits stay on fixed line numbers in both languages, with fences unchanged (**AC11**). The already-delivered #714 / #716-item-4 files and every other surface stay byte-identical (**AC10**, **AC13**).

**Pre-commitment (frozen before round 1; AI self-discipline, never operator-ratified).**

- **Trigger.** Two consecutive rounds, QA or code review, each with a recorded verdict and each with a new finding of the class "a sentence this task edits is contradicted by a script line". A round interrupted before a verdict is not counted.
- **Never-dropped.**
  - (N1) EN/JA lockstep at the same line numbers (**AC11** with **AC3**, **AC4**, **AC6**–**AC8**).
  - (N2) Every new qualifier is backed by a script line cited in `## Backing lines`.
  - (N3) T-1185's frozen block is untouched and its hash still verifies (**AC9**).

  A defeat of N1–N3 stops the task and returns it to planning.
- **Droppable, in order.**
  1. The #738 comment (**AC2**).
  2. The #737 sub-bullet edit (**AC1**).

  Each is independent of the docs items, and dropping one leaves its issue open. Dropping removes a criterion, so it is a class-B re-freeze and is raised to the operator, never taken on this role's own authority. The firing round's findings travel to the reopened issue as its requirement list.

## Non-goals

- **#716 items 1–3** (the `--paths` hardening of `bin/check-pii-shapes.sh`): left for a later task (**AC10**).
- **README's "every durability gate … `not-durable` permanently" clause** (on README line 99, the same line **AC3** edits): waived on T-1184's board entry. The clause's wording stays as it is; this is a reading item for QA, not a check, because the line itself legitimately changes. (info-only)
- **Any `bin/` behaviour change.** The only `bin/` file touched is `bin/check-invocation-path.sh`, and only in comment lines (**AC2**, **AC10**).
- **Any `agents/*.md` edit**, and no edit to `skills/goal/SKILL.md`, `docs/pii-controls.md`, `docs/pii-controls.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `docs/tuning-oversight.md`, `docs/tuning-oversight.ja.md`, `templates/`, `tests/` or `.github/` (**AC10**).
- **T-1185's intent block**: byte-identical (**AC9**).
- **No full-population sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** Operator rulings: A2 light operation and the 2026-10-01 ruling. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`.
- **Base.** `B=68873e2c` is the branch point; a line that reads it first runs `git cat-file -e "$B^{commit}"`.
- **What lines never contain.** No line reads a gitignored path, compares a stream that carries a per-checkout value (absolute path, temp path, trace or timestamp), or contains a recursive deletion. A suite or checker is scanned for a recursive-deletion pattern before it runs, and is not run if the pattern matches.
- **Staleness.** **AC1**, **AC9**, **AC10**, **AC11** and **AC13** read `B`. They are **merge-point-scoped and expected to go stale** once later work lands on the same base; do not widen their base to keep them evergreen.

- [ ] **AC1** (#737; D1.) `skills/run/SKILL.md` edits only the per-checkout freeze-sweep sub-bullet.
  - **Title.** Exactly one line begins with `     - **Per-checkout value spliced into a compared stream (T-1188, issue #734)**:`, byte-identical to its prefix at `B`.
  - **New wording.** That line contains `broken as a command`, `happens to equal` and `pm-spec`.
  - **Old wording gone.** The file no longer contains `passes only on the checkout that wrote it`.
  - **Scope clause unchanged.** The text from `**Scope, stated because this item` to the end of the line is byte-identical to `B`'s.
  - **One line changed.** `git diff --numstat B...HEAD` on the file reports `1` added and `1` deleted.
  - **Prompt sync.** `bash bin/check-prompt-sync.sh` exits 0.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; S=skills/run/SKILL.md; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac1.XXXXXX") || exit 1; H='     - **Per-checkout value spliced into a compared stream (T-1188, issue #734)**:'; git show "$B:$S" > "$T/b" || exit 1; test "$(grep -cF -- "$H" "$T/b")" = 1 || exit 1; test "$(grep -cF -- "$H" "$S")" = 1 || rc=1; grep -F -- "$H" "$S" > "$T/line" || rc=1; awk -v h="$H" 'index($0, h) != 1 { bad = 1 } END { exit bad }' "$T/line" || rc=1; for k in 'broken as a command' 'happens to equal' 'pm-spec'; do grep -qF -- "$k" "$T/line" || rc=1; done; test "$(grep -cF -- 'passes only on the checkout that wrote it' "$T/b")" = 1 || exit 1; test "$(grep -cF -- 'passes only on the checkout that wrote it' "$S")" = 0 || rc=1; grep -F -- "$H" "$T/b" | grep -oE '\*\*Scope, stated because this item.*$' > "$T/sb" || exit 1; grep -oE '\*\*Scope, stated because this item.*$' "$T/line" > "$T/sh" || rc=1; test -s "$T/sb" && cmp -s "$T/sb" "$T/sh" || rc=1; git diff --no-renames --numstat "$B"...HEAD -- "$S" > "$T/ns" || exit 1; awk -F '\t' 'END { exit !(NR == 1 && $1 == 1 && $2 == 1) }' "$T/ns" || rc=1; bash bin/check-prompt-sync.sh < /dev/null > "$T/ps" 2>&1 || rc=1; test "$rc" -eq 0
  - adopter-surface: skills/run/SKILL.md (the freeze sweep the run skill executes in the adopter's repository)

- [ ] **AC2** (#738; D2.) The `bin/check-invocation-path.sh` header names the every-part rule and keeps its conclusion; only comment lines change.
  - **Header text.** Read the header the way `print_help` does: the comment lines from line 2 to the first non-comment line, with the `# ` prefix stripped and the lines joined by single spaces.
    - At `B` it contains `on a command line's first token`. At HEAD it does not.
    - At HEAD it contains `every part` (case-insensitive), `2.1.278` and `never run outside the sandbox`.
  - **Non-comment lines unchanged.** After every line beginning `#` (after optional whitespace) is dropped, the file is byte-identical to `B`'s.
  - **Shellcheck and suite.** `shellcheck` exits 0 on the file. `tests/check-invocation-path/run.sh` exits 0 under `ulimit -f 400000`, with output capped by `head -c`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; F=bin/check-invocation-path.sh; test -r "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac2.XXXXXX") || exit 1; hd(){ awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); printf "%s ", $0; next } { exit }' | tr -s ' '; }; git show "$B:$F" > "$T/b" || exit 1; hd < "$T/b" > "$T/hb"; grep -qF -- "on a command line's first token" "$T/hb" || exit 1; hd < "$F" > "$T/hh"; test -s "$T/hh" || rc=1; grep -qF -- "on a command line's first token" "$T/hh"; test "$?" = 1 || rc=1; grep -qiF -- 'every part' "$T/hh" || rc=1; grep -qF -- '2.1.278' "$T/hh" || rc=1; grep -qF -- 'never run outside the sandbox' "$T/hh" || rc=1; grep -v '^[[:space:]]*#' "$T/b" > "$T/nb"; grep -v '^[[:space:]]*#' "$F" > "$T/nh"; test -s "$T/nb" && cmp -s "$T/nb" "$T/nh" || rc=1; command -v shellcheck > /dev/null 2>&1 || exit 1; shellcheck "$F" > "$T/sc" 2>&1 || rc=1; R=tests/check-invocation-path/run.sh; test -r "$R" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$R"; r=$?; test "$r" = 1 || exit 1; ulimit -f 400000 2>/dev/null; bash "$R" < /dev/null 2>&1 | head -c 20000000 > "$T/suite"; s=("${PIPESTATUS[@]}"); test "${s[0]}" -eq 0 && test "${s[1]}" -eq 0 || rc=1; test "$rc" -eq 0

- [ ] **AC3** (#721 item 1; D3.) The README `local`-mode exclude-line outcome is qualified to a base dir not yet committed, in four places: lines 77 and 99 of `README.md` and `README.ja.md`. Each place is located by an anchor that occurs exactly once. At HEAD the anchored line carries the phrase; at `B` the phrase does not occur in the file.

  | File | Anchor (line 77 / line 99) | Phrase |
  |---|---|---|
  | `README.md` | ``` `Required:` (in the default `tracked` record mode ``` / `- **Keep it out of git**` | `for a base dir not yet committed` |
  | `README.ja.md` | ``` `Required:`（既定の `tracked` 記録モードでは ``` / `- **git に載せない**` | `まだコミットされていない base dir` |
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac3.XXXXXX") || exit 1; printf '%s\n' 'README.md|`Required:` (in the default `tracked` record mode|for a base dir not yet committed' 'README.md|- **Keep it out of git**|for a base dir not yet committed' 'README.ja.md|`Required:`（既定の `tracked` 記録モードでは|まだコミットされていない base dir' 'README.ja.md|- **git に載せない**|まだコミットされていない base dir' > "$T/rows"; n=0; while IFS='|' read -r f a k; do n=$((n + 1)); test -r "$f" || { rc=1; continue; }; test "$(git show "$B:$f" | grep -cF -- "$k")" = 0 || rc=1; test "$(grep -cF -- "$a" "$f")" = 1 || { rc=1; continue; }; grep -F -- "$a" "$f" | grep -qF -- "$k" || rc=1; done < "$T/rows"; test "$n" = 4 || rc=1; test "$rc" -eq 0
  - adopter-surface: README.md and README.ja.md (the setup report summary at lines 51, 77 and 99)

- [ ] **AC4** (#721 item 2; D3.) The four `local`-mode summaries name the no-line outcome by its character set `A-Za-z0-9._/-`. That token occurs 0 times in each of the three files at `B`. At HEAD it occurs:
  - in `README.md` on the line beginning ``The `Required:` base-directory item described there``;
  - in `README.ja.md` on the line beginning ``ここで述べた `Required:` の base dir 項目``;
  - in `skills/setup/SKILL.md` on the line beginning ``In `local` record mode the base-directory item is instead``;
  - in `skills/team-init/SKILL.md`, in the paragraph that begins with the line `   Record mode:` and runs to the next empty line. That paragraph still contains `Remains`, the committed-base case.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; K='A-Za-z0-9._/-'; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac4.XXXXXX") || exit 1; printf '%s\n' 'README.md|The `Required:` base-directory item described there' 'README.ja.md|ここで述べた `Required:` の base dir 項目' 'skills/setup/SKILL.md|In `local` record mode the base-directory item is instead' > "$T/rows"; n=0; while IFS='|' read -r f a; do n=$((n + 1)); test -r "$f" || { rc=1; continue; }; test "$(git show "$B:$f" | grep -cF -- "$K")" = 0 || rc=1; awk -v a="$a" 'index($0, a) == 1' "$f" > "$T/l"; test "$(grep -c '' "$T/l")" = 1 || rc=1; grep -qF -- "$K" "$T/l" || rc=1; done < "$T/rows"; test "$n" = 3 || rc=1; I=skills/team-init/SKILL.md; test -r "$I" || exit 1; test "$(git show "$B:$I" | grep -cF -- "$K")" = 0 || rc=1; awk 'index($0, "   Record mode:") == 1 { p = 1 } p && NF == 0 { exit } p { sub(/^ +/, ""); printf "%s ", $0 }' "$I" > "$T/p"; test -s "$T/p" || rc=1; grep -qF -- "$K" "$T/p" || rc=1; grep -qF -- 'Remains' "$T/p" || rc=1; test "$rc" -eq 0
  - adopter-surface: skills/setup/SKILL.md (line 16) and skills/team-init/SKILL.md (the record-mode note), the instructions an adopter's agent follows when relaying setup's report

- [ ] **AC5** (#721 item 3; D3.) The setup skill's `local`-mode paragraph no longer tells the agent to say there is nothing to stage. The paragraph begins with the line ``   In `local` record mode (`shell-team.mode` `` and runs to the next empty line; its lines are read joined by single spaces.
  - At `B` the paragraph contains `say that there is nothing to stage`.
  - At HEAD the paragraph does not contain it, and neither does any line of the file.
  - At HEAD the paragraph contains `no base-dir record is staged`, `a separate change the operator commits`, ``Never offer a `git add` `` and `.gitignore`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; S=skills/setup/SKILL.md; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac5.XXXXXX") || exit 1; par(){ awk 'index($0, "   In `local` record mode (`shell-team.mode`") == 1 { p = 1 } p && NF == 0 { exit } p { sub(/^ +/, ""); printf "%s ", $0 }'; }; git show "$B:$S" | par > "$T/pb"; grep -qF -- 'say that there is nothing to stage' "$T/pb" || exit 1; par < "$S" > "$T/ph"; test -s "$T/ph" || rc=1; grep -qF -- 'say that there is nothing to stage' "$T/ph"; test "$?" = 1 || rc=1; test "$(grep -cF -- 'say that there is nothing to stage' "$S")" = 0 || rc=1; for k in 'no base-dir record is staged' 'a separate change the operator commits' 'Never offer a `git add`' '.gitignore'; do grep -qF -- "$k" "$T/ph" || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** (#723 item 1; D4.) Line 20 of both migration guides says the `.codex/agents` append happens only when it is not already ignored, and names the `Already in place:` outcome.
  - **Base.** At `B`, line 20 of each guide does not contain `Already in place:`.
  - **EN.** At HEAD, line 20 of `docs/migrating-to-local-mode.md` contains `.codex/agents`, `info/exclude`, `Done:`, `Already in place:` and `not already ignored`.
  - **JA.** Line 20 of `docs/migrating-to-local-mode.ja.md` contains `.codex/agents`, `info/exclude`, `Done:`, `Already in place:` and `無視されて`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; E=docs/migrating-to-local-mode.md; J=docs/migrating-to-local-mode.ja.md; test -r "$E" && test -r "$J" || exit 1; for f in "$E" "$J"; do test "$(git show "$B:$f" | sed -n 20p | grep -cF -- 'Already in place:')" = 0 || exit 1; done; e=$(sed -n 20p "$E"); j=$(sed -n 20p "$J"); for k in '.codex/agents' 'info/exclude' 'Done:' 'Already in place:' 'not already ignored'; do printf '%s\n' "$e" | grep -qF -- "$k" || rc=1; done; for k in '.codex/agents' 'info/exclude' 'Done:' 'Already in place:' '無視されて'; do printf '%s\n' "$j" | grep -qF -- "$k" || rc=1; done; test "$rc" -eq 0
  - adopter-surface: docs/migrating-to-local-mode.md and docs/migrating-to-local-mode.ja.md (lines 20, 70 and 89)

- [ ] **AC7** (#723 item 2; D4.) Line 70 of both guides states the no-command exception for a base path outside the safe character set.
  - At `B`, line 70 of each guide does not contain `A-Za-z0-9._/-`.
  - At HEAD, line 70 of each guide contains `A-Za-z0-9._/-`, `git add` and `Required:`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; for f in docs/migrating-to-local-mode.md docs/migrating-to-local-mode.ja.md; do test -r "$f" || exit 1; test "$(git show "$B:$f" | sed -n 70p | grep -cF -- 'A-Za-z0-9._/-')" = 0 || exit 1; l=$(sed -n 70p "$f"); for k in 'A-Za-z0-9._/-' 'git add' 'Required:'; do printf '%s\n' "$l" | grep -qF -- "$k" || rc=1; done; done; test "$rc" -eq 0

- [ ] **AC8** (#723 item 3; D4.) Line 89 of both guides says that `bin/check-codex-agents.sh` also names any extra `shell-team-*.toml` it does not own.
  - At `B`, line 89 of each guide does not contain `shell-team-*.toml`.
  - At HEAD, line 89 of each guide contains `bin/check-codex-agents.sh`, `in sync` and `shell-team-*.toml`. The EN line also contains `by hand`, and the JA line contains `手で`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; E=docs/migrating-to-local-mode.md; J=docs/migrating-to-local-mode.ja.md; for f in "$E" "$J"; do test -r "$f" || exit 1; test "$(git show "$B:$f" | sed -n 89p | grep -cF -- 'shell-team-*.toml')" = 0 || exit 1; l=$(sed -n 89p "$f"); for k in 'bin/check-codex-agents.sh' 'in sync' 'shell-team-*.toml'; do printf '%s\n' "$l" | grep -qF -- "$k" || rc=1; done; done; sed -n 89p "$E" | grep -qF -- 'by hand' || rc=1; sed -n 89p "$J" | grep -qF -- '手で' || rc=1; test "$rc" -eq 0

- [ ] **AC9** (#723 item 4; D4; N3.) The T-1185 claim inventory cites live lines, and the T-1185 frozen region is untouched.
  - **Frozen region.** In `.shell-team/specs/T-1185-local-mode-migration-guide.md`, `<!-- END intent-block: T-1185 -->` occurs exactly once. Every line up to and including it is byte-identical to `B`.
  - **Hash still verifies.** `bash bin/check-intent.sh` on that spec and the board (resolved through `bin/team-paths.sh --get todo`) exits 0.
  - **Blank anchor gone.** `bin/team-mode.sh:86` occurs at `B` and not at HEAD.
  - **New anchors.**
    - Rows `| EN 7 |`, `| EN 24 |` and `| EN 68 |` each occur once and each cite `bin/team-mode.sh:87` or `bin/team-mode.sh:90`.
    - Row `| EN 20 |` cites `bin/team-setup.sh:436` or `:437`.
    - Row `| EN 70 |` cites one of `bin/team-setup.sh:1002`–`:1005`, `:1027` or `:1028`.
    - Row `| EN 89 |` cites `bin/check-codex-agents.sh:226`.
  - **Row count unchanged.** The number of lines beginning `| EN ` is the same as at `B`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; S=.shell-team/specs/T-1185-local-mode-migration-guide.md; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac9.XXXXXX") || exit 1; M='<!-- END intent-block: T-1185 -->'; test "$(grep -cxF -- "$M" "$S")" = 1 || exit 1; git show "$B:$S" > "$T/b" || exit 1; awk -v m="$M" '{ print } $0 == m { exit }' "$T/b" > "$T/hb"; awk -v m="$M" '{ print } $0 == m { exit }' "$S" > "$T/hh"; test -s "$T/hb" && cmp -s "$T/hb" "$T/hh" || rc=1; test "$(grep -cF -- 'bin/team-mode.sh:86' "$T/b")" -ge 1 || exit 1; test "$(grep -cF -- 'bin/team-mode.sh:86' "$S")" = 0 || rc=1; row(){ grep -E "^\| EN $1 \|" "$S"; }; for n in 7 24 68; do test "$(row "$n" | grep -c '')" = 1 || rc=1; row "$n" | grep -qE 'bin/team-mode\.sh:(87|90)([^0-9]|$)' || rc=1; done; row 20 | grep -qE 'bin/team-setup\.sh:43[67]([^0-9]|$)' || rc=1; row 70 | grep -qE 'bin/team-setup\.sh:(100[2-5]|102[78])([^0-9]|$)' || rc=1; row 89 | grep -qE 'bin/check-codex-agents\.sh:226([^0-9]|$)' || rc=1; test "$(grep -c '^| EN ' "$T/b")" = "$(grep -c '^| EN ' "$S")" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-intent.sh "$S" "$BD" < /dev/null > "$T/ci" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** (D5; Non-goals.) The already-delivered files and every out-of-scope surface are untouched.
  - **Positive control.** Each of these exists at `B`: `agents`, `agents/engineer.md`, `skills/goal/SKILL.md`, `docs/pii-controls.md`, `docs/pii-controls.ja.md`, `bin/check-pii-shapes.sh`, `docs/adopting.md`, `docs/adopting.ja.md`, `docs/tuning-oversight.md`, `docs/tuning-oversight.ja.md`, `templates`, `tests` and `.github`.
  - **Empty diff.** `git diff --no-renames --quiet B...HEAD` over all of them exits 0.
  - **`bin/`.** The only path under `bin/` that the committed range changes is `bin/check-invocation-path.sh`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac10.XXXXXX") || exit 1; set -- agents agents/engineer.md skills/goal/SKILL.md docs/pii-controls.md docs/pii-controls.ja.md bin/check-pii-shapes.sh docs/adopting.md docs/adopting.ja.md docs/tuning-oversight.md docs/tuning-oversight.ja.md templates tests .github; test "$#" = 13 || exit 1; for p in "$@"; do git cat-file -e "$B:$p" || rc=1; done; git diff --no-renames --quiet "$B"...HEAD -- "$@"; test "$?" = 0 || rc=1; git diff --no-renames --name-only "$B"...HEAD -- bin > "$T/bin" || exit 1; grep -vxF bin/check-invocation-path.sh "$T/bin" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** (D5; N1.) The edits stay on fixed line numbers in both languages, and the guides keep their structure.
  - **Single-line hunks.** In `git diff --no-renames -U0 B...HEAD`, every hunk header of `README.md` and `README.ja.md` replaces one line with one line at the same line number, and that number is one of 51, 77 and 99. The same holds for both migration guides, with the numbers 20, 70 and 89.
  - **Line count.** Both guides have 89 lines at `B` and at HEAD.
  - **Fences unchanged.** Each guide's fence delimiter and fenced content lines are byte-identical to `B`'s, and non-empty.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac11.XXXXXX") || exit 1; lk(){ git diff --no-renames -U0 "$B"...HEAD -- "$1" > "$T/d" || return 2; awk -v ok=" $2 " '/^@@ / { split($2, x, ","); split($3, y, ","); a = substr(x[1], 2) + 0; c = substr(y[1], 2) + 0; b = (2 in x) ? x[2] + 0 : 1; d = (2 in y) ? y[2] + 0 : 1; if (a != c || b != 1 || d != 1 || index(ok, " " a " ") == 0) bad = 1 } END { exit bad }' "$T/d"; }; for f in README.md README.ja.md; do test -r "$f" || exit 1; lk "$f" '51 77 99' || rc=1; done; for f in docs/migrating-to-local-mode.md docs/migrating-to-local-mode.ja.md; do test -r "$f" || exit 1; lk "$f" '20 70 89' || rc=1; test "$(git show "$B:$f" | wc -l | tr -d ' ')" = 89 || exit 1; test "$(wc -l < "$f" | tr -d ' ')" = 89 || rc=1; git show "$B:$f" | awk 'index($0, "```") == 1 { f = !f; print; next } f' > "$T/fb"; awk 'index($0, "```") == 1 { f = !f; print; next } f' "$f" > "$T/fh"; test -s "$T/fb" && cmp -s "$T/fb" "$T/fh" || rc=1; done; test "$rc" -eq 0

- [ ] **AC12** Conformance.
  - **Scan.** Before they run, `bin/check-adopter-docs.sh`, `bin/check-readme-version.sh` and `bin/check-handoff.sh` are each scanned for a recursive-deletion pattern; none may match.
  - **`check-adopter-docs.sh`.** On this spec it exits 0 with zero bytes on both streams.
  - **`check-readme-version.sh`.** `bash bin/check-readme-version.sh README.md README.ja.md` exits 0.
  - **`check-handoff.sh`.** It exits 0 on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac12.XXXXXX") || exit 1; for s in bin/check-adopter-docs.sh bin/check-readme-version.sh bin/check-handoff.sh; do test -r "$s" || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-delete' "$s"; r=$?; test "$r" = 1 || exit 1; done; S=.shell-team/specs/T-1189-local-mode-followups-prose.md; test -r "$S" || exit 1; bash bin/check-adopter-docs.sh "$S" < /dev/null > "$T/o" 2> "$T/e"; test "$?" = 0 || rc=1; test ! -s "$T/o" && test ! -s "$T/e" || rc=1; bash bin/check-readme-version.sh README.md README.ja.md < /dev/null > "$T/rv" 2>&1 || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" < /dev/null > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC13** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only B...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `skills/run/SKILL.md`.
  - **Allowed members.** Every member is one of:
    - `README.md`, `README.ja.md`, `skills/run/SKILL.md`, `skills/setup/SKILL.md`, `skills/team-init/SKILL.md`, `bin/check-invocation-path.sh`, `docs/migrating-to-local-mode.md`, `docs/migrating-to-local-mode.ja.md`;
    - `.shell-team/specs/T-1189-<slug>.md`, `.shell-team/specs/T-1185-local-mode-migration-guide.md`, `.shell-team/provenance/T-1189.md`, `.shell-team/interventions/T-1189.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1189.md`;
    - a raw capture `.shell-team/reviews/T-1189-codex-<stem>.{txt,jsonl,json}`;
    - `.shell-team/todo.md`, `.shell-team/test-recipe.md`.
  - check: rc=0; B=68873e2c; git cat-file -e "$B^{commit}" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1189-ac13.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF skills/run/SKILL.md "$T/s" || rc=1; grep -vxE 'README(\.ja)?\.md|skills/(run|setup|team-init)/SKILL\.md|bin/check-invocation-path\.sh|docs/migrating-to-local-mode(\.ja)?\.md|\.shell-team/(specs/T-1189-[a-z0-9-]+\.md|specs/T-1185-local-mode-migration-guide\.md|provenance/T-1189\.md|interventions/(T-1189|no-task)\.md|reviews/T-1189\.md|reviews/T-1189-codex-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC14** CI is green on the pull request. That includes the shellcheck lint over `bin/`, the check-invocation-path suite and dogfood step, the readme-version step and the diff-scoped PII scan.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **An adopter reading the README or the migration guide (EN or JA)** whose clone is in one of these states:
   - `local` mode with the base dir not committed, ignored or not;
   - `local` mode with the base dir committed in HEAD;
   - either mode with a base path containing a character outside `A-Za-z0-9._/-`;
   - `tracked` again after `local`;
   - on a Codex CLI host, with `.codex/agents` already ignored or not, or holding an extra `shell-team-*.toml` the generator does not own.
2. **An adopter's agent following `skills/setup/SKILL.md` and `skills/team-init/SKILL.md`** while relaying setup's report in each of those states, including an operator who chooses the root `.gitignore` alternative.
3. **The coordinating session running the run skill's freeze sweep** over a check line that splices a per-checkout or per-run value into a compared stream.
4. **A reader of `bin/check-invocation-path.sh --help`** or of its source header.
5. **A maintainer re-reading the T-1185 claim inventory** against the scripts.
6. **These check lines** run from a fresh clone of the repository, where no gitignored path exists.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Markdown renderers other than GitHub's.
2. Translations other than the English and Japanese pair.
3. Claude Code versions before 2.1.278 (the comment states the current rule only).
4. A legacy-layout specs directory outside the base dir. The adopting guide's "Two limits" paragraph already covers it, and the summaries are not extended to it.
5. A `.codex/agents` path ignored by a rule that matches only some files inside it (setup's own check-ignore probe decides; the guide does not restate that probe).
6. README wording other than lines 51, 77 and 99, including the waived durability clause.

<!-- END intent-block: T-1189 -->

## Backing lines

Every qualifier this task adds is backed by a script line (N2). QA reads each edited sentence against its row.

| Edit | Qualifier | Backing |
|---|---|---|
| **AC1** | trigger named "broken as a command" | `docs/tuning-oversight.md:136`, `docs/tuning-oversight.ja.md:122`, `agents/pm-spec.md:103` |
| **AC1** | passes only while the spliced value equals the expectation | the item's own definition (a value compared against a fixed expected value); no script line, a prompt rule |
| **AC2** | every part must match since 2.1.278; conclusion kept | `bin/codex-capture.sh:15-18`; `docs/distribution.md` matching-rule paragraph |
| **AC3** | exclude-line outcome only for a base dir not yet committed; committed means a `Remains` item | `bin/team-setup.sh:796-797` |
| **AC4** | no printed line for a path outside `A-Za-z0-9._/-` | `bin/team-setup.sh:819-820`; `docs/adopting.md:111` |
| **AC5** | setup stages nothing; a `.gitignore` edit is the operator's own change | `bin/team-setup.sh:823` ("Setup edits neither file and stages nothing") |
| **AC6** | append only when not already ignored, else `Already in place:` | `bin/team-setup.sh:436-437` |
| **AC7** | no command for an unsafe path after going back | `bin/team-setup.sh:1002-1005`, `:1026-1027` |
| **AC8** | an extra unowned `shell-team-*.toml` is named, exit 1, not in sync | `bin/check-codex-agents.sh:226`, `:232-236` |
| **AC9** | `team-mode.sh` anchors | `bin/team-mode.sh:87` (`local`), `:90` (`tracked`) |

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Name the "broken as a command" trigger; value-equality wording; title and scope clause byte-identical; one line changed (D1) | **AC1** |
| 2 | `check-prompt-sync` stays green (D1) | **AC1** |
| 3 | Comment names the every-part rule, keeps the conclusion; comment lines only; shellcheck and suite green (D2) | **AC2** |
| 4 | README 77/99 committed-base qualifier (D3 item 1) | **AC3** |
| 5 | No-line outcome in the four summaries (D3 item 2) | **AC4** |
| 6 | Setup skill staging clause (D3 item 3) | **AC5** |
| 7 | Guide lines 20, 70, 89 qualifiers (D4) | **AC6**, **AC7**, **AC8** |
| 8 | Inventory anchors corrected; T-1185 frozen block untouched; hash verifies (D4; N3) | **AC9** |
| 9 | Already-delivered #714 / #716-item-4 files untouched (D5) | **AC10** |
| 10 | No `bin/` behaviour change, no `agents/*.md` edit, other docs untouched (Non-goals) | **AC10**, **AC2** |
| 11 | EN/JA lockstep at fixed line numbers; 89 lines; fences unchanged (D5; N1) | **AC11** |
| 12 | Declarations conform; README badge and board lint green | **AC12** |
| 13 | Diff confined to the named files and this task's records (D5) | **AC13** |
| 14 | CI green | **AC14** |
| 15 | Every qualifier backed by a script line (N2) | info-only (not promoted to AC): a reading judgment over `## Backing lines`; no command can tell whether a sentence is entailed by a script line |
| 16 | #716 items 1–3 left alone (Non-goals) | **AC10** |
| 19 | README durability clause on line 99 left as is (Non-goals) | info-only (not promoted to AC): it shares line 99 with the **AC3** edit, so no line-level check can isolate it; QA reads it |
| 17 | Pre-commitment and drop order | info-only (not promoted to AC): a disposition, not a deliverable property |
| 18 | No sweep, no whole CI re-run, no local run of past specs' check lines | info-only (not promoted to AC): process exclusions that leave no trace beyond **AC10**/**AC13** |

## Shipped-docs inventory

| Document | Relation | Disposition |
|---|---|---|
| `README.md`, `README.ja.md` | lines 51, 77, 99 summarize setup's `local`-mode report | this task (**AC3**, **AC4**) |
| `skills/setup/SKILL.md` | line 16 and the `local`-mode paragraph | this task (**AC4**, **AC5**) |
| `skills/team-init/SKILL.md` | the record-mode note | this task (**AC4**) |
| `skills/run/SKILL.md` | the freeze-sweep item | this task (**AC1**) |
| `docs/migrating-to-local-mode.md`, `.ja.md` | lines 20, 70, 89 | this task (**AC6**–**AC8**) |
| `docs/adopting.md`, `.ja.md` | the full statement ("Two limits", the four-row table); already accurate | unchanged (**AC10**) |
| `docs/pii-controls.md`, `.ja.md` | `rc=n/a` already shipped (#716 item 4, T-1184) | unchanged (**AC10**) |
| `docs/distribution.md`, `.ja.md` | already states the every-part rule (T-1187) | unchanged |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. The operator's 2026-10-01 ruling forbids running past specs' check lines locally, and the A2 ruling drops per-task sweeps. CI and this task's own check lines decide the impact instead, as in T-1185.
- **Known readers of the edited paths** (found by reading specs this role opened; a lower bound). A criterion reaching these paths through indirection stays unmeasured, and that is disclosed.
  - T-1188's criteria read `skills/run/SKILL.md` (title of the per-checkout item, `+2/-1` numstat at its own base). The title stays byte-identical (**AC1**). Its numstat criterion is merge-point-scoped and already stale by design.
  - T-1185's **AC1**–**AC2**, **AC5** and **AC7** read the guides and its own inventory. Headings, fences and claim-line numbers are unchanged (**AC11**, **AC9**), so **AC7**'s coverage set is unchanged. Its anchors move to existing lines. **AC5** reads only added lines against its own base, and the new wording carries no removal command.
  - T-1184's criteria compare `README*` against its own base; merge-point-scoped.
  - `tests/check-invocation-path/run.sh` runs the script and is held green by **AC2**. No suite locks the header text (Grep over `tests/`: no `first token` / `exclusion patterns` / `never run outside` match for this script).
- **Adopter-side artifacts.** None generated. `.codex/agents` is generated from `agents/` and `templates/`, which this task does not touch (**AC10**).

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| #737 run-skill wording | not met | met | PATCH | precision edit to a prompt line |
| #738 comment | not met | met (`--help`) | PATCH | comment wording |
| #721 summaries | not met | met | PATCH | docs qualifiers |
| #723 guide | not met | met | PATCH | docs qualifiers and record anchors |

The derived tier is PATCH, the maximum of the column.

## Assumptions

- **Relayed (owner: the coordinating session).**
  - The branch `feature/local-mode-followups-prose` was cut from `develop` at `68873e2c` with one interventions commit on top. The freeze run confirms this with `git diff --no-renames --name-only 68873e2c HEAD`, which should name only `.shell-team/interventions/T-1189.md`.
  - The issue bodies, as supplied in the scratchpad file. This role read all five in full.
- **Relayed premise contradicted by measurement (a finding about the hand-off).** Issue #738 says the comment has "no reader-visible output". `bin/check-invocation-path.sh` lines 2–90 are all comments, and `print_help` (line 159) prints them up to line 91, so lines 21–23 appear in `--help`. The edit stays comment-only. **AC2** asserts that the non-comment lines are byte-identical and does not claim `--help` is unchanged. The coordinating session should record this as an interventions entry.
- **Measured by this role** (Read and Grep tools on the working tree at `1fec7fe6`, whose shipped files equal `68873e2c`): every line anchor in `## Summarized sources`.
- **Own-coinage count premises** (each expected 0 at `B`; the freeze run measures each with `git show 68873e2c:<path> | grep -cF -- '<token>'`):
  - `for a base dir not yet committed` in `README.md`;
  - `まだコミットされていない base dir` in `README.ja.md`;
  - `happens to equal` on the `skills/run/SKILL.md` per-checkout line;
  - `no base-dir record is staged` and `a separate change the operator commits` in `skills/setup/SKILL.md`;
  - `not already ignored` on line 20 of the EN guide.
- **Borrowed tokens** (count premises asserted by the checks; the freeze run measures each at `B` and records the value here):
  - `broken as a command` in `skills/run/SKILL.md` (expected 0; Grep tool: 0).
  - `A-Za-z0-9._/-` in `README.md`, `README.ja.md`, `skills/setup/SKILL.md` and `skills/team-init/SKILL.md` (expected 0 each; Grep tool: 0), and on line 70 of each guide (expected absent).
  - `Already in place:` on line 20 of each guide (expected absent).
  - `shell-team-*.toml` on line 89 of each guide (expected absent).
  - `bin/team-mode.sh:86` in the T-1185 spec (expected ≥ 1; Grep tool: 3).
  - `on a command line's first token` in the joined header of `bin/check-invocation-path.sh` (expected present).
  - `say that there is nothing to stage` in the `skills/setup/SKILL.md` paragraph (expected present).
  - `passes only on the checkout that wrote it` in `skills/run/SKILL.md` (expected 1).
  - The per-checkout title prefix (expected 1).
  - The README anchors (each expected exactly 1).
  - Both guides have 89 lines.
  - The recursive-deletion pattern matches none of `tests/check-invocation-path/run.sh`, `bin/check-adopter-docs.sh`, `bin/check-readme-version.sh` and `bin/check-handoff.sh`.
- **Pre-implementation expectation (for the freeze read).**
  - **AC1**–**AC9** are red only because the new wording is absent. **AC9**'s blank-anchor and new-anchor clauses are red, and its frozen-region and hash clauses are green.
  - **AC10**, **AC11** and **AC12** are green. **AC11** has no hunks yet.
  - **AC13** is red on its positive control.
  - **AC14** is above the ceiling.
- **Local verification limit.** The CI run (**AC14**) is the evidence for the pinned shellcheck and bash versions.

## Open questions

- None blocking.

## Notes for engineer

- **Files.** The eight shipped files in the scope lock, the `## Claim inventory` rows of the T-1185 spec (outside its intent block only), provenance, and `.shell-team/test-recipe.md` as usual.
- **Fixed phrases.** The checks read these phrases:
  - `broken as a command`, `happens to equal`
  - `every part`, `2.1.278`, `never run outside the sandbox`
  - `for a base dir not yet committed` / `まだコミットされていない base dir`
  - `A-Za-z0-9._/-`
  - `no base-dir record is staged`, `a separate change the operator commits`
  - `not already ignored` / `無視されて`
  - `shell-team-*.toml`, `by hand` / `手で`

  The rest of each sentence is your call. Keep EN and JA meaning-symmetric; QA reads them side by side.
- **Line numbers.** README lines 51, 77, 99 and guide lines 20, 70, 89 must each stay one line (no new line, no wrap), in both languages (**AC11**).
- **#737.** Edit only the `such a line passes only on the checkout that wrote it, so it is treated as a broken check line` clause. Name the trigger in the form the trigger list uses ("broken as a command"). Leave the title and the `**Scope, …` clause byte-for-byte.
- **#738.** Keep the conclusion and the `(bin/codex-capture.sh:8-23)` pointer. Rewrapping the comment is fine (the check joins lines). Touch no non-comment line.
- **#721 item 3.** Keep "Never offer a `git add` for it" (it is about the base dir). The new clause says that no base-dir record is staged and that a `.gitignore` edit, if the operator chooses it, is a separate change the operator commits.
- **#723 item 3.** Do not use a removal command in the guide sentence. "Deal with it by hand" is enough; T-1185's guide names no removal command.
- **T-1185 inventory.**
  - Rewrite only rows EN 7, 24, 68 (anchor `:86` → `:87` or `:90`) and rows EN 20, 70, 89 (claim cell resynced to the new sentence, and anchors as **AC9** requires).
  - Leave the header row and the probe recipe as they are, unless a probe for the new claims is needed. In that case append a probe line; `P17 codex` already covers the not-ignored half of line 20.
  - Never touch a line at or above `<!-- END intent-block: T-1185 -->`.
- **Mutation probes.** Before hand-off, break each new check line's subject once in a scratch copy under `$TMPDIR`, confirm the criterion goes red, and restore. Suggested breaks:
  - restore `passes only on the checkout that wrote it` (**AC1**);
  - change one non-comment line of the script (**AC2**);
  - drop the phrase from README.ja line 99 (**AC3**);
  - wrap guide line 70 onto two lines (**AC11**);
  - leave one `:86` anchor (**AC9**).
- **Shape scan.** Run the PII-shape checker over this task's records before the first commit.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** The README, skills and guide are shipped adopter text and are reviewed for accuracy against the scripts. The inline check lines get dev-scaffold depth (operator ruling).
