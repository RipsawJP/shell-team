# The shipped docs make `local` the supported way to keep the loop's records out of git, and issue #714's three follow-ups land

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1184

## Problem

T-1183 makes setup print an `info/exclude` line in `local` record mode and makes `team-init` name both modes. The shipped docs still describe one mode and contradict each other. `README.md` says that keeping the base dir out of git is a supported choice. `docs/adopting.md`'s trial section says never-committed operating files are **not supported**. Setup's Required item is described everywhere as commit-only. Separately, issue #714 collects three one-line follow-ups to T-1181's role text, and issue #716 item 4 asks that the PII-controls docs name `rc=n/a`. This task is #711 task C2b. It is stacked on T-1183 (C2a) and also owns the live two-gate run in a `local`-mode fixture repository.

## Summarized sources

- issue #711 body (relayed by the coordinating session as a file; this role cannot open the tracker). `## Design`: "**Ignoring the directory.** Setup prints the `.git/info/exclude` line for the resolved base dir … `info/exclude` is per-clone and invisible to collaborators; a shared root `.gitignore` line is named as the alternative." "**Worktree isolation.** An ignored base dir does not travel into a linked worktree, so `isolation: worktree` and `land-worktree.sh` are unsupported in `local` mode." `## Decision`: "Once the base dir is committed, an ignore rule no longer applies to those tracked files … The four combinations of mode and ignore rule, and what setup says about each, belong in the shipped docs (AC8)." AC2: "With `shell-team.mode local` and the base dir listed in `.git/info/exclude`, one task runs through both gates (QA `READY_FOR_REVIEW`, review `READY_FOR_MERGE`) in a fixture repository and `git log --all -- <base>` is empty afterwards; the code change is committed." AC8: "Shipped docs name the mode: `README.md`, `docs/adopting.md` (the "Trying the team on one ticket" non-support paragraph is rewritten; the global-excludes paragraph points at the mode), `skills/team-init/SKILL.md`, and their `.ja.md` counterparts." Restated by the Goal sentence, D1, D3, **AC1**–**AC3**, **AC13**.
- `.shell-team/specs/T-1183-local-mode-setup-docs.md` D1 and D2 (frozen at T-1183's freeze): the setup items led by `- base directory in local mode: `; cases (a) committed, which is left to the operator; (b) ignored, which goes under Already in place; (c) not ignored, which puts `` `/<dir>/` `` and the exclude file under Required. No `git add` and no removal command in `local` mode. Init's summary names `tracked`, `local` and `git config shell-team.mode local`. These are the behaviours the docs describe. Restated by D1, **AC1**–**AC3**.
- issue #714 (relayed by the coordinating session in the briefing; body not supplied). Its three items: (a) `agents/engineer.md`'s `- **Local record mode (T-1181).**` line reworded to "record files under the base dir"; (b) `skills/goal/SKILL.md` gains a first-tick `bash "<plugin root>/bin/team-mode.sh"` read (exit 2 → `BLOCKED`) and the run skill's mode-line template; (c) one `local` sentence directly after the run skill's T-1158 line. Restated by D2, **AC5**–**AC7**.
- issue #716 item 4 (`.shell-team/todo.md`, T-1182's `- fast-follow disposition (2026-10-11)` sub-bullet): "docs omit `rc=n/a` (nit) — filed as issue #716 — rides #711 task C2's docs pass". Restated by D1, **AC4**.
- `docs/adopting.md` at `3cde89ef` (T-1183 leaves it unchanged; T-1183's **AC11**):
  - line 11 (`## Where the operating files live`);
  - lines 56–70 (the global-excludes scope paragraph);
  - line 145 (`## How to run`) and lines 183–186 (gate note);
  - lines 468–480 (setup's Required paragraph: "the loop does not support never-committed operating files", one `git add` command);
  - lines 923–963 (`## Trying the team on one ticket`: two fenced blocks; 955 "**not supported**"; 957 `check-durability.sh` refuses; 959 `check-pii-shapes.sh` reads neither mode of an ignored base dir; 961 `check-intent.sh`; 963 `TEAM_RUN_BASE` stays repo-relative).

  `docs/adopting.ja.md` at `3cde89ef` has the Japanese counterparts at lines 12, 58–74, 151 and 185–187, 470–480 and 918–958, with `稼働ファイルを一度もコミットしないまま…**サポートされていません (not supported)**` at line 950. Restated by D1, **AC2**.
- `tests/trial-recipe/extract-recipe.sh` lines 36–37 (the two headings it anchors on), 48–49 (whole-file line floors: 641 EN, 611 JA), 92–97 (exactly four fence lines in the section) and 127–155 (the `team-init.sh --trial-branch ` span and the full two-argument `git add -f …` remedy span, each exactly once in the section). Restated by D1, **AC2**, **AC8**.
- `README.md` at `3cde89ef`: line 75 (setup's report, "`Required:` (the base dir must not be ignored by git and must be committed, with the command to do it)") and lines 94–97 ("Both choices are supported"; the "Keep it out of git" bullet). `README.ja.md` lines 75 and 94–97 are the counterparts. `.github/workflows/check-handoff.yml` line 138 runs `bin/check-readme-version.sh README.md README.ja.md`. Restated by D1, **AC1**, **AC9**.
- `skills/setup/SKILL.md` lines 14–15 and 55–58 (step 5 relays each Required item as "the printed command and, where it is printed, the re-include line"). `tests/setup/run.sh` lines 691–738 (its AC10 token lock: fifteen settings and permission tokens must stay absent from the skill). `skills/team-init/SKILL.md` lines 60–62 (whether to ignore the whole base dir "is the user's call"). Restated by D1, **AC3**, **AC8**.
- `agents/engineer.md` line 55 (the T-1181 local line, "write the task's record files (spec notes, board line, provenance) but never stage or commit them"; the record-mode block's contained sentence is line 62, not line 55). `skills/goal/SKILL.md` lines 34–46 (`## First tick — initialize state` to `## Each tick`; no mode read today). `skills/run/SKILL.md` lines 28–30 (Step 0 mode read and the `> Record mode for this repo:` template) and line 92 (T-1158: "only the curated `<task-id>.md` is committed"). Restated by D2, **AC5**–**AC7**.
- `docs/pii-controls.md` lines 137–144 and `docs/pii-controls.ja.md` line 133 say that a round with no record file reports the `- shape-scan:` line "with a zero count". `templates/prompt-blocks/record-shape-scan.md` line 4 says that line carries `<N>` zero and `rc=n/a`. Restated by D1, **AC4**.

## Goal

<!-- BEGIN intent-block: T-1184 -->

- user-visible: yes — the README, the adopting guide, the setup and team-init skills and the PII-controls docs, in English and Japanese, now document `local` record mode as the supported way to run the loop without committing its records: how to declare it, how to ignore the base dir, what setup reports in each of the four combinations of mode and ignore rule, and what the gates do.
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: skills/setup/SKILL.md — this-task
- shipped-docs: skills/team-init/SKILL.md — this-task
- shipped-docs: docs/pii-controls.md — this-task
- shipped-docs: docs/pii-controls.ja.md — this-task
- verification-class: mechanism — the diff changes `agents/engineer.md`, from which `bin/gen-codex-agents.sh` derives a Codex custom agent, and two run skills. Fixture suites read the edited docs (`tests/trial-recipe` extracts the recipe from the adopting guide; `tests/setup` locks tokens in the setup skill).
- verification-ceiling: unit-and-static — **AC1**–**AC11** are settled in a plain checkout through string presence, byte-scoped comparisons against the base blobs, the trial-recipe extractor's output, fixture-suite exit codes, and the exit codes of `check-prompt-sync.sh`, `gen-codex-agents.sh`, `check-codex-agents.sh`, `check-adopter-docs.sh`, `check-handoff.sh` and `check-readme-version.sh`. **AC12** (CI on the pull request) and **AC13** (the live two-gate run) sit above the ceiling.
- base-ref-discriminator: two-arm, predecessor `feature/711-local-mode-setup-docs` (T-1183, open at authoring time), integration branch `develop`. Every base-side read in **AC1**–**AC7**, **AC10** and **AC11** resolves `B` with the same byte-identical chain: `git merge-base "feature/711-local-mode-setup-docs" HEAD` when `git show-ref --verify --quiet refs/heads/feature/711-local-mode-setup-docs` succeeds; else `git merge-base "refs/remotes/origin/feature/711-local-mode-setup-docs" HEAD` when `git show-ref --verify --quiet refs/remotes/origin/feature/711-local-mode-setup-docs` succeeds; else `git merge-base "develop" HEAD` (local `refs/heads/develop`, then `refs/remotes/origin/develop`); none of them resolving is a failure (exit 1), never a pass. `B` is T-1183's tip at the moment this branch is cut (see Assumptions).

**Goal (one sentence).** The shipped README, adopting guide, setup and team-init skills and PII-controls docs, in English and Japanese, document `local` as the supported way to keep the records out of git, including the four combinations of mode and ignore rule and what setup says about each, while the trial recipe stays byte-identical; and issue #714's three follow-ups land in `agents/engineer.md`, `skills/goal/SKILL.md` and `skills/run/SKILL.md` with the prompt blocks still in sync.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — shipped docs, EN and JA in lockstep.**
  - (i) **README.** In `README.md` and `README.ja.md`, the setup-report sentence (line 75) and the "Decide once whether `.shell-team/` belongs in git" block (lines 94–97) say three things: `tracked` commits the records; `local` (`git config shell-team.mode local` plus an ignore line, `info/exclude` by preference) keeps them out of git; and what setup's `Required:` item is in each mode.
  - (ii) **Adopting guide.** `docs/adopting.md` and `docs/adopting.ja.md` gain a new subsection, `### Keeping the records out of git: local record mode` / `### 記録を git に載せない: local record mode`, inside `## Where the operating files live` / `## 稼働ファイルの置き場所`.
    - The subsection carries the declaration command, `info/exclude` against a root `.gitignore`, and a table with one row per combination of mode × ignore rule: two rows led by `` `tracked` `` and two led by `` `local` ``, each saying what setup reports. It also covers the committed-base-dir case, and names no removal command.
    - The `## How to run` / `## 実行方法` gate note gains a `local`-mode sentence naming `shell-team.mode`.
    - Setup's Required paragraph (`Two things in the report are not decisions.` / `報告のうち 2 つは判断ではない。`) is rewritten for both modes.
    - The trial section's non-support paragraphs are rewritten: the "**not supported**" sentence, and the `check-durability.sh` and `check-pii-shapes.sh` paragraphs. The new text says never-committed operating files are supported only in `local` mode, and what the gates then do: `check-durability.sh` prints its `skipped:` line, the shape scan runs with `--paths`, and `isolation: worktree` is unsupported.
    - The section's heading, both fenced recipes, the `--trial-branch` invocation span and the `git add -f` remedy span stay byte-identical, so `tests/trial-recipe` extracts the same recipe.
  - (iii) **Skills.** `skills/setup/SKILL.md` step 5 relays a `local` Required item as the `info/exclude` line to append, with nothing to stage. The skill stays free of the setup suite's fifteen forbidden tokens. `skills/team-init/SKILL.md` gains a note naming both modes and `git config shell-team.mode local`.
  - (iv) **PII-controls docs.** `docs/pii-controls.md` and `.ja.md` take #716 item 4: the `- shape-scan:` line of a round with no record file carries `rc=n/a`.

  Outside the paragraphs named in (i)–(ii), every edit is a pure addition, and no added line carries a removal command. (**AC1**–**AC4**, **AC8**)
- **D2 — issue #714's follow-ups.**
  - (a) `agents/engineer.md`'s `- **Local record mode (T-1181).**` line says `record files under the base dir` instead of `the task's record files`. That one line is replaced; nothing else in the file changes.
  - (b) `skills/goal/SKILL.md` gains a line led by `**First-tick record mode (T-1183).**`, between `## First tick — initialize state` and `## Each tick`. On the first tick it runs `bash "<plugin root>/bin/team-mode.sh"`. On exit 2 it stops `BLOCKED` and never reads that outcome as `tracked`. It prepends the run skill's `> Record mode for this repo: <resolved mode> …` line to every sub-agent prompt, and that template line is carried in the same region.
  - (c) Directly after the run skill's T-1158 sub-bullet, a new sub-bullet led by `- **Reviewer records in local record mode (T-1183).**` says that in `local` mode the curated `<task-id>.md` review record is also written and never committed.

  (b) and (c) are pure additions. The `T-1183` tag in the leads is the #711 task C2 provenance chosen before the split, and is kept. (**AC5**–**AC7**)
- **D3 — the live half of #711 AC2.** One small task runs through QA `READY_FOR_REVIEW` and review `READY_FOR_MERGE` in a `local`-mode fixture repository outside this repository.
  - The plugin is loaded from this branch's checkout with `--plugin-dir`, because the installed snapshot predates `bin/team-mode.sh`.
  - Afterwards `git log --all -- <base>` is empty and the code change is committed.
  - The coordinating session owns the run and runs it before the sprint's batch GO. If it cannot, the run happens right after the release against the released snapshot.
  - The board records which of the two happened, and any host input is recorded in interventions. (**AC13**)
- **D4 — unchanged.** The following stay as they are at `B` (**AC10**):
  - T-1183's deliverables: `bin/team-setup.sh`, `bin/team-init.sh`, `tests/setup/run.sh`, `tests/team-init/run.sh`, `tests/local-mode/run.sh` and `.github/workflows/check-handoff.yml`;
  - `bin/check-setup.sh`, `bin/check-durability.sh`, `bin/team-commit.sh`, `bin/team-mode.sh`, `bin/close-out.sh`, `bin/check-handoff.sh` and `bin/check-pii-shapes.sh`;
  - the four playbook blocks, `templates/prompt-blocks/record-mode.md` and `templates/prompt-blocks/record-shape-scan.md`;
  - `.shell-team/lessons.md` and `tests/trial-recipe/`.

**Pre-commitment (frozen before round 1; AI self-discipline, never operator-ratified).** Trigger: two consecutive code-review rounds, each with a recorded verdict, each raising a new Blocker or Major finding. A round interrupted before a verdict is not counted. Never-dropped: (N1) the trial-recipe byte identity, meaning the extractor's four outputs are identical on the base and HEAD docs and the trial-recipe suite is green (**AC2**, **AC8**); (N3) `check-prompt-sync.sh` green (**AC9**). A defeat of N1 or N3 stops the task and returns it to planning. Droppable, first and only: the goal-skill first-tick read, D2 (b). The drop removes **AC6** from the frozen block and returns the item to issue #714, with that round's findings as its requirement list. Nothing else is droppable.

## Non-goals

- **No change to T-1183's deliverables or to the D4 files.** (**AC10**)
- **No removal command in any doc text.** A committed base dir in a `local` clone is described as the operator's decision. (**AC1**–**AC3**)
- **No migration guide for existing adopters**; that is a later sprint task. (info-only)
- **No fix for worktree isolation in `local` mode.** It stays unsupported and is documented as such. (**AC2**)
- **No change to issue #716's items 1–3**; they stay on #716. (**AC10**)
- **No full-population two-arm sweep and no local run of past specs' check lines** (operator rulings: A2 light operation and the 2026-10-01 ruling). (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree, writing only under `$TMPDIR`.
- **Timeouts.** A line that runs a script uses a `tmo` helper (120 s) or a `tms` helper (1200 s, for whole suites). The helper starts the script in its own process group under `ulimit -f`, kills the group on timeout, and captures output into files capped by that limit.
- **What lines never contain.** No check line uses `ps`, a recursive deletion or `xargs`.
- **Scan before run.** A suite or checker is scanned for a recursive-deletion pattern before it runs. If it matches, it is not run.
- **Base-side reads.** They use the chain in the `base-ref-discriminator` declaration, spelled byte-identically.
- **Staleness.** The criteria that read `B` are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`.

- [ ] **AC1** (D1 (i).) README, EN and JA.
  - **Content.** `README.md` and `README.ja.md` each contain `git config shell-team.mode local` and `info/exclude`.
  - **Bounded removals.** The base blob and HEAD are compared as sets of non-empty lines. Every removed line lies in a base paragraph that begins with one of the named prefixes; a paragraph ends at the next blank line.
    - `README.md` prefixes: `The prompt triggers the setup skill`, `**Decide once whether`, `- **Track it**`, `- **Keep it out of git**`.
    - `README.ja.md` prefixes: `このプロンプトで setup スキル`, ``**`.shell-team/` を git に載せるかを最初に決めてください。**``, `- **追跡する**`, `- **git に載せない**`.
    - Positive control: every prefix begins a line in the base blob.
  - **No removal commands added.** No added line carries `git rm`, `git clean`, a recursive or forced `rm`, `filter-branch`, `filter-repo` or `--cached`.
  - adopter-surface: README.md and README.ja.md (setup report and the "Decide once" block), docs/adopting.md and docs/adopting.ja.md (the new local-record-mode subsection with the four-combination table, setup's Required paragraph, the trial section), skills/setup/SKILL.md step 5, skills/team-init/SKILL.md, docs/pii-controls.md and docs/pii-controls.ja.md.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac1.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; ad(){ git show "$B:$1" > "$T/b" || return 1; test -s "$T/b" || return 1; awk 'NR == FNR { A[++n] = $0; next } { for (i = 1; i <= n; i++) if (index($0, A[i]) == 1) h[i] = 1 } END { for (i = 1; i <= n; i++) if (!h[i]) exit 1 }' "$2" "$T/b" || return 1; awk 'NF' "$T/b" | sort -u > "$T/b1"; awk 'NF' "$1" | sort -u > "$T/h1"; comm -23 "$T/b1" "$T/h1" > "$T/gone"; awk 'NR == FNR { A[++n] = $0; next } NF == 0 { f = 0; next } { for (i = 1; i <= n; i++) if (index($0, A[i]) == 1) f = 1 } f' "$2" "$T/b" | sort -u > "$T/ok"; comm -23 "$T/gone" "$T/ok" > "$T/bad"; test ! -s "$T/bad" || return 1; comm -13 "$T/b1" "$T/h1" > "$T/new"; grep -qE -- 'git rm|git clean|r[m][[:space:]]+-[A-Za-z]*[rRf]|filter-(branch|repo)|--cached' "$T/new"; test "$?" = 1 || return 1; return 0; }; printf '%s\n' 'The prompt triggers the setup skill' '**Decide once whether' '- **Track it**' '- **Keep it out of git**' > "$T/pe"; printf '%s\n' 'このプロンプトで setup スキル' '**`.shell-team/` を git に載せるかを最初に決めてください。**' '- **追跡する**' '- **git に載せない**' > "$T/pj"; for x in 'README.md pe' 'README.ja.md pj'; do set -- $x; test -s "$1" || { rc=1; continue; }; ad "$1" "$T/$2" || rc=1; grep -qF 'git config shell-team.mode local' "$1" || rc=1; grep -qF 'info/exclude' "$1" || rc=1; done; test "$rc" -eq 0

- [ ] **AC2** (D1 (ii); N1.) The adopting guide, EN and JA.
  - **New subsection (EN).** In `docs/adopting.md`, the heading `### Keeping the records out of git: local record mode` occurs exactly once and lies inside `## Where the operating files live`. Its subsection runs to the next heading of level three or higher. It contains `git config shell-team.mode local`, `info/exclude` and `.gitignore`.
  - **The table.** The subsection has exactly six lines beginning `|`. Exactly two begin `` | `tracked` | `` and exactly two begin `` | `local` | ``.
  - **Other sections (EN).** The `## How to run` section contains `shell-team.mode`. The `## Trying the team on one ticket` section contains `shell-team.mode`, `skipped:`, `--paths` and `isolation: worktree`.
  - **Removed sentences (EN).** The file no longer contains `the loop does not support never-committed` or `is **not supported**`. Positive control: both occur in the base blob.
  - **Japanese counterpart.** `docs/adopting.ja.md` meets the same requirements. Its heading `### 記録を git に載せない: local record mode` lies inside `## 稼働ファイルの置き場所`. The section requirements apply to `## 実行方法` and `## 1 チケットでチームを試す`. It no longer contains `ループは一度もコミットされない運用ファイルを支えず` or `**サポートされていません (not supported)**`, and both occur in its base blob.
  - **Trial recipe unchanged (N1).** For each file, `tests/trial-recipe/extract-recipe.sh` is run in each of its four modes on both the base blob and HEAD. Every run exits `0`, and the base and HEAD stdout are identical.
  - **Bounded removals.** Removed lines are bounded as in **AC1**.
    - `docs/adopting.md` prefixes: `Two things in the report are not decisions.`, `Running the loop with the operating files never committed`, `` `bin/check-durability.sh` **refuses** ``, `` `bin/check-pii-shapes.sh` reports clean ``.
    - `docs/adopting.ja.md` prefixes: `報告のうち 2 つは判断ではない。`, `稼働ファイルを一度もコミットしないまま`, `` `bin/check-durability.sh` は**拒否 (refuses)** ``, `` `bin/check-pii-shapes.sh` は、ループ自身の記録を ``.
  - **No removal commands added.** No added line carries a removal command, as in **AC1**.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac2.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; ad(){ git show "$B:$1" > "$T/b" || return 1; test -s "$T/b" || return 1; awk 'NR == FNR { A[++n] = $0; next } { for (i = 1; i <= n; i++) if (index($0, A[i]) == 1) h[i] = 1 } END { for (i = 1; i <= n; i++) if (!h[i]) exit 1 }' "$2" "$T/b" || return 1; awk 'NF' "$T/b" | sort -u > "$T/b1"; awk 'NF' "$1" | sort -u > "$T/h1"; comm -23 "$T/b1" "$T/h1" > "$T/gone"; awk 'NR == FNR { A[++n] = $0; next } NF == 0 { f = 0; next } { for (i = 1; i <= n; i++) if (index($0, A[i]) == 1) f = 1 } f' "$2" "$T/b" | sort -u > "$T/ok"; comm -23 "$T/gone" "$T/ok" > "$T/bad"; test ! -s "$T/bad" || return 1; comm -13 "$T/b1" "$T/h1" > "$T/new"; grep -qE -- 'git rm|git clean|r[m][[:space:]]+-[A-Za-z]*[rRf]|filter-(branch|repo)|--cached' "$T/new"; test "$?" = 1 || return 1; return 0; }; sec(){ awk -v h="$1" '$0 == h { f = 1; next } f && /^## / { f = 0 } f' "$2"; }; sub3(){ awk -v h="$1" '$0 == h { f = 1; next } f && /^(#|##|###) / { f = 0 } f' "$2"; }; EX=tests/trial-recipe/extract-recipe.sh; test -s "$EX" || exit 1; printf '%s\n' 'Two things in the report are not decisions.' 'Running the loop with the operating files never committed' '`bin/check-durability.sh` **refuses**' '`bin/check-pii-shapes.sh` reports clean' > "$T/pe"; printf '%s\n' '報告のうち 2 つは判断ではない。' '稼働ファイルを一度もコミットしないまま' '`bin/check-durability.sh` は**拒否 (refuses)**' '`bin/check-pii-shapes.sh` は、ループ自身の記録を' > "$T/pj"; printf '%s\n' 'docs/adopting.md|pe|### Keeping the records out of git: local record mode|## Where the operating files live|## How to run|## Trying the team on one ticket|the loop does not support never-committed|is **not supported**' 'docs/adopting.ja.md|pj|### 記録を git に載せない: local record mode|## 稼働ファイルの置き場所|## 実行方法|## 1 チケットでチームを試す|ループは一度もコミットされない運用ファイルを支えず|**サポートされていません (not supported)**' > "$T/rows"; n=0; while IFS='|' read -r f p h ws hr tr g1 g2; do n=$((n + 1)); test -s "$f" || { rc=1; continue; }; ad "$f" "$T/$p" || rc=1; test "$(grep -cxF -- "$h" "$f")" = 1 || rc=1; test "$(sec "$ws" "$f" | grep -cxF -- "$h")" = 1 || rc=1; sub3 "$h" "$f" > "$T/sub"; for q in 'git config shell-team.mode local' 'info/exclude' '.gitignore'; do grep -qF -- "$q" "$T/sub" || rc=1; done; test "$(grep -c '^|' "$T/sub")" = 6 || rc=1; test "$(grep -c '^| `tracked` |' "$T/sub")" = 2 || rc=1; test "$(grep -c '^| `local` |' "$T/sub")" = 2 || rc=1; sec "$hr" "$f" | grep -qF 'shell-team.mode' || rc=1; sec "$tr" "$f" > "$T/tr"; for q in 'shell-team.mode' 'skipped:' '--paths' 'isolation: worktree'; do grep -qF -- "$q" "$T/tr" || rc=1; done; git show "$B:$f" > "$T/bd.md" || { rc=1; continue; }; for g in "$g1" "$g2"; do grep -qF -- "$g" "$T/bd.md" || rc=1; grep -qF -- "$g" "$f"; test "$?" = 1 || rc=1; done; for md in setup teardown flag remedy; do bash "$EX" "$T/bd.md" "$md" > "$T/x0" 2> /dev/null || rc=1; bash "$EX" "$f" "$md" > "$T/x1" 2> /dev/null || rc=1; test -s "$T/x0" || rc=1; cmp -s "$T/x0" "$T/x1" || rc=1; done; done < "$T/rows"; test "$n" = 2 || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D1 (iii).) The two skills.
  - **Pure additions.** `git diff --no-renames --numstat <base>...HEAD` reports one row for `skills/setup/SKILL.md` and one for `skills/team-init/SKILL.md`. Each row has a positive added count and `0` deleted.
  - **Setup skill.** One added line in `skills/setup/SKILL.md` contains both `local` and `info/exclude`.
  - **Team-init skill.** An added line in `skills/team-init/SKILL.md` contains `git config shell-team.mode local`, and the file contains `tracked`.
  - **No removal commands.** No added line in either file carries a removal command, as in **AC1**.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac3.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; for f in skills/setup/SKILL.md skills/team-init/SKILL.md; do test -s "$f" || { rc=1; continue; }; git diff --no-renames --numstat "$B"...HEAD -- "$f" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; done; NS="$T/new-setup"; NI="$T/new-team-init"; git diff --no-renames -U0 "$B"...HEAD -- skills/setup/SKILL.md | awk 'index($0, "+") == 1 && index($0, "+++") != 1 { print substr($0, 2) }' > "$NS"; git diff --no-renames -U0 "$B"...HEAD -- skills/team-init/SKILL.md | awk 'index($0, "+") == 1 && index($0, "+++") != 1 { print substr($0, 2) }' > "$NI"; grep -F 'info/exclude' "$NS" | grep -qF 'local' || rc=1; grep -qF 'git config shell-team.mode local' "$NI" || rc=1; grep -qF 'tracked' skills/team-init/SKILL.md || rc=1; grep -qE -- 'git rm|git clean|r[m][[:space:]]+-[A-Za-z]*[rRf]|filter-(branch|repo)|--cached' "$NS" "$NI"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D1 (iv), #716 item 4.) PII-controls docs.
  - **Pure additions.** `git diff --no-renames --numstat <base>...HEAD` reports one row for `docs/pii-controls.md` and one for `docs/pii-controls.ja.md`. Each row has a positive added count and `0` deleted.
  - **Content.** The `## When the loop runs it` section of the first file and the `## ループがこれを走らせる時点` section of the second each contain `rc=n/a`. Each section is non-empty.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac4.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; sec(){ awk -v h="$1" '$0 == h { f = 1; next } f && /^## / { f = 0 } f' "$2"; }; for x in 'docs/pii-controls.md|## When the loop runs it' 'docs/pii-controls.ja.md|## ループがこれを走らせる時点'; do f="${x%%|*}"; h="${x#*|}"; test -s "$f" || { rc=1; continue; }; git diff --no-renames --numstat "$B"...HEAD -- "$f" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; sec "$h" "$f" > "$T/s"; test -s "$T/s" || rc=1; grep -qF 'rc=n/a' "$T/s" || rc=1; done; test "$rc" -eq 0

- [ ] **AC5** (D2 (a).) The engineer line.
  - **One line replaced.** `git diff --no-renames --numstat <base>...HEAD -- agents/engineer.md` reports exactly `1` added and `1` deleted.
  - **New wording.** Exactly one line of the HEAD file begins `- **Local record mode (T-1181).**`. It contains `record files under the base dir` and does not contain `the task's record files`. Positive control: that line contains `the task's record files` in the base blob.
  - **Nothing else changed.** With that line removed from both, the base blob and the HEAD file are byte-identical.
  - **Codex agents regenerate cleanly.** `bin/gen-codex-agents.sh --root . --out-dir <scratch>` exits `0`, and `bin/check-codex-agents.sh --root . --out-dir <scratch>` exits `0`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac5.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=agents/engineer.md; test -s "$F" || exit 1; LD='- **Local record mode (T-1181).**'; git diff --no-renames --numstat "$B"...HEAD -- "$F" > "$T/ns" || exit 1; test "$(awk '{ print $1 " " $2 }' "$T/ns")" = '1 1' || rc=1; awk -v l="$LD" 'index($0, l) == 1' "$F" > "$T/l1"; test "$(wc -l < "$T/l1" | tr -d ' ')" = 1 || rc=1; grep -qF 'record files under the base dir' "$T/l1" || rc=1; grep -qF "the task's record files" "$T/l1"; test "$?" = 1 || rc=1; git show "$B:$F" > "$T/b" || exit 1; awk -v l="$LD" 'index($0, l) == 1' "$T/b" | grep -qF "the task's record files" || rc=1; awk -v l="$LD" 'index($0, l) != 1' "$T/b" > "$T/x0"; awk -v l="$LD" 'index($0, l) != 1' "$F" > "$T/x1"; cmp -s "$T/x0" "$T/x1" || rc=1; tmo "$R" "$T/o" "$T/e" bash "$R/bin/gen-codex-agents.sh" --root . --out-dir "$T/out"; test "$?" = 0 || rc=1; tmo "$R" "$T/o" "$T/e" bash "$R/bin/check-codex-agents.sh" --root . --out-dir "$T/out"; test "$?" = 0 || rc=1; test -s "$T/out/shell-team-engineer.toml" || rc=1; test "$rc" -eq 0

- [ ] **AC6** (D2 (b); the droppable component.) The goal skill's first-tick read.
  - **Pure addition.** `git diff --no-renames --numstat <base>...HEAD -- skills/goal/SKILL.md` reports one row with a positive added count and `0` deleted.
  - **The new line.** Exactly one line of the file begins `**First-tick record mode (T-1183).**`. It lies between the lines `## First tick — initialize state` and `## Each tick`. It contains `bash "<plugin root>/bin/team-mode.sh"`, `BLOCKED` and `tracked`.
  - **The mode-line template.** The same region holds a line beginning `> Record mode for this repo: <resolved mode>`.
  - **Positive control.** Both headings occur exactly once.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac6.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=skills/goal/SKILL.md; test -s "$F" || exit 1; git diff --no-renames --numstat "$B"...HEAD -- "$F" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; H1='## First tick — initialize state'; H2='## Each tick'; test "$(grep -cxF -- "$H1" "$F")" = 1 || rc=1; test "$(grep -cxF -- "$H2" "$F")" = 1 || rc=1; LG='**First-tick record mode (T-1183).**'; test "$(awk -v l="$LG" 'index($0, l) == 1' "$F" | wc -l | tr -d ' ')" = 1 || rc=1; awk -v a="$H1" -v b="$H2" '$0 == a { f = 1; next } $0 == b { f = 0 } f' "$F" > "$T/rg"; awk -v l="$LG" 'index($0, l) == 1' "$T/rg" > "$T/l"; test "$(wc -l < "$T/l" | tr -d ' ')" = 1 || rc=1; for q in 'bash "<plugin root>/bin/team-mode.sh"' 'BLOCKED' 'tracked'; do grep -qF -- "$q" "$T/l" || rc=1; done; awk 'index($0, "> Record mode for this repo: <resolved mode>") == 1' "$T/rg" | grep -q . || rc=1; test "$rc" -eq 0

- [ ] **AC7** (D2 (c).) The run skill's reviewer-record sentence.
  - **Pure addition.** `git diff --no-renames --numstat <base>...HEAD -- skills/run/SKILL.md` reports one row with a positive added count and `0` deleted.
  - **Anchor (positive control).** Exactly one line, after leading whitespace, begins `- **Reviewer records are not all committed (T-1158)**`.
  - **The new sub-bullet.** The line directly after it, after leading whitespace, begins `- **Reviewer records in local record mode (T-1183).**`. It contains `` `<task-id>.md` ``, `never committed` and ``In `local` mode``. That lead occurs nowhere else in the file.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac7.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; F=skills/run/SKILL.md; test -s "$F" || exit 1; git diff --no-renames --numstat "$B"...HEAD -- "$F" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; P1='- **Reviewer records are not all committed (T-1158)**'; P2='- **Reviewer records in local record mode (T-1183).**'; awk -v a="$P1" -v b="$P2" '{ s = $0; sub(/^[[:space:]]+/, "", s) } index(s, a) == 1 { na++; want = NR + 1 } index(s, b) == 1 { nb++; if (NR == want) ok = 1; line = s } END { if (na != 1 || nb != 1 || !ok) exit 1; print line }' "$F" > "$T/l" || rc=1; for q in '`<task-id>.md`' 'never committed' 'In `local` mode'; do grep -qF -- "$q" "$T/l" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** (D1; N1.) The suites that read the edited files.
  - **Suites.** `tests/setup/run.sh` (its token lock reads the setup skill), `tests/trial-recipe/run.sh`, `tests/check-prompt-sync/run.sh`, `tests/codex-skeleton-hygiene/run.sh` and `tests/check-adopter-docs/run.sh`.
  - **Scan.** Before it runs, each suite is scanned for a recursive-deletion pattern, with backslash-continued lines joined. It must not match.
  - **Run.** Each suite runs in its own process group, killed after 1200 s and under a file-size limit. It exits `0`, with no line beginning `FAIL`.
  - **Timeout.** QA runs this criterion with `CHECK_ACS_TIMEOUT` raised to at least `3600`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac8.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID CLAUDE_CONFIG_DIR PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; mkdir -p "$HOME" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; n=0; for s in tests/setup/run.sh tests/trial-recipe/run.sh tests/check-prompt-sync/run.sh tests/codex-skeleton-hygiene/run.sh tests/check-adopter-docs/run.sh; do n=$((n + 1)); test -s "$s" || { rc=1; continue; }; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$s" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || { rc=1; continue; }; test "${ps2[1]}" -eq 1 || { rc=1; continue; }; L="$T/log-$n"; tms "$s" "$L"; test "$?" -eq 0 || rc=1; test -s "$L" || rc=1; grep -q '^FAIL' "$L"; test "$?" = 1 || rc=1; done; test "$n" = 5 || rc=1; test "$rc" -eq 0

- [ ] **AC9** (N3.) Conformance.
  - **Scan.** Before they run, `bin/check-prompt-sync.sh`, `bin/check-adopter-docs.sh`, `bin/check-handoff.sh` and `bin/check-readme-version.sh` are each scanned as in **AC8**. None may match.
  - **`check-prompt-sync.sh`.** `bash bin/check-prompt-sync.sh` exits `0` and prints `check-prompt-sync: all registered prompt blocks in sync`.
  - **`check-adopter-docs.sh`.** `bash bin/check-adopter-docs.sh` on this spec exits `0`, with zero bytes on both streams.
  - **`check-handoff.sh`.** `bash bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - **`check-readme-version.sh`.** `bash bin/check-readme-version.sh README.md README.ja.md` exits `0`, as CI runs it.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac9.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; for s in bin/check-prompt-sync.sh bin/check-adopter-docs.sh bin/check-handoff.sh bin/check-readme-version.sh; do test -s "$s" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$s" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; done; tmo "$R" "$T/o" "$T/e" bash bin/check-prompt-sync.sh; test "$?" = 0 || rc=1; grep -qxF 'check-prompt-sync: all registered prompt blocks in sync' "$T/o" || rc=1; S=.shell-team/specs/T-1184-local-mode-docs.md; test -s "$S" || exit 1; tmo "$R" "$T/o" "$T/e" bash bin/check-adopter-docs.sh "$S"; test "$?" = 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; tmo "$R" "$T/o" "$T/e" bash bin/check-handoff.sh "$BD"; test "$?" = 0 || rc=1; tmo "$R" "$T/o" "$T/e" bash bin/check-readme-version.sh README.md README.ja.md; test "$?" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC10** (D4.) The untouched set. Each file below exists at the base and at HEAD, and has an empty committed diff `<base>...HEAD`:
  - T-1183's deliverables: `bin/team-setup.sh`, `bin/team-init.sh`, `tests/setup/run.sh`, `tests/team-init/run.sh`, `tests/local-mode/run.sh`, `.github/workflows/check-handoff.yml`;
  - checkers: `bin/check-setup.sh`, `bin/check-durability.sh`, `bin/team-commit.sh`, `bin/team-mode.sh`, `bin/close-out.sh`, `bin/check-handoff.sh`, `bin/check-pii-shapes.sh`;
  - prompt blocks: `templates/prompt-blocks/playbook-engineer.md`, `templates/prompt-blocks/playbook-pm-spec.md`, `templates/prompt-blocks/playbook-qa-verifier.md`, `templates/prompt-blocks/playbook-tech-lead.md`, `templates/prompt-blocks/record-mode.md`, `templates/prompt-blocks/record-shape-scan.md`;
  - `.shell-team/lessons.md`, `tests/trial-recipe/extract-recipe.sh` and `tests/trial-recipe/run.sh`.
  - check: rc=0; export LC_ALL=C; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; n=0; for f in bin/team-setup.sh bin/team-init.sh tests/setup/run.sh tests/team-init/run.sh tests/local-mode/run.sh .github/workflows/check-handoff.yml bin/check-setup.sh bin/check-durability.sh bin/team-commit.sh bin/team-mode.sh bin/close-out.sh bin/check-handoff.sh bin/check-pii-shapes.sh templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-pm-spec.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/record-mode.md templates/prompt-blocks/record-shape-scan.md .shell-team/lessons.md tests/trial-recipe/extract-recipe.sh tests/trial-recipe/run.sh; do n=$((n + 1)); test -s "$f" || { rc=1; continue; }; git cat-file -e "$B:$f" || { rc=1; continue; }; git cat-file -e "HEAD:$f" || { rc=1; continue; }; git diff --no-renames --quiet "$B"...HEAD -- "$f"; test "$?" = 0 || rc=1; done; test "$n" = 22 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Scope lock, **merge-point-scoped and expected to go stale** after merge.
  - **Measured set.** The union of four reads, each of which must succeed: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only`, and the untracked strays `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `docs/adopting.md`.
  - **Allowed members.** Every member is one of:
    - `README.md`, `README.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `docs/pii-controls.md`, `docs/pii-controls.ja.md`;
    - `skills/setup/SKILL.md`, `skills/team-init/SKILL.md`, `skills/goal/SKILL.md`, `skills/run/SKILL.md`, `agents/engineer.md`;
    - `.shell-team/specs/T-1184-<slug>.md`, `.shell-team/provenance/T-1184.md`, `.shell-team/interventions/T-1184.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1184.md`, a raw capture `.shell-team/reviews/T-1184-codex-<stem>.{txt,jsonl,json}`, `.shell-team/todo.md`, `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1184-ac11.XXXXXX") || exit 1; BR=feature/711-local-mode-setup-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF docs/adopting.md "$T/s" || rc=1; grep -vxE 'README(\.ja)?\.md|docs/(adopting|pii-controls)(\.ja)?\.md|skills/(setup|team-init|goal|run)/SKILL\.md|agents/engineer\.md|\.shell-team/(specs/T-1184-[a-z0-9-]+\.md|provenance/T-1184\.md|interventions/(T-1184|no-task)\.md|reviews/T-1184\.md|reviews/T-1184-codex-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** CI is green on the pull request. That includes the trial-recipe, setup, check-adopter-docs and check-prompt-sync suites, the readme-version step, the prompt-sync and gen-codex-agents dogfood steps, the suites left to CI because they carry a recursive deletion, and the diff-scoped PII scan of the pull request.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

- [ ] **AC13** (D3.) The live two-gate run in `local` mode (#711 AC2's runtime half).
  - **Setup.** A fixture repository outside this repository, declared `local`, with the base dir in `.git/info/exclude`. The plugin is loaded from this stack's checkout through `--plugin-dir`.
  - **Outcome.** One small task reaches QA `READY_FOR_REVIEW` and review `READY_FOR_MERGE`. Afterwards `git log --all -- <base>` is empty in that repository and the code change is committed there.
  - **Timing.** The run happens before the sprint's batch GO, or else right after the release against the released snapshot.
  - **Records.** The board entry records which of the two happened, the two flags reached, and both git outputs. Any host input is recorded in interventions.
  - above-ceiling: the coordinating session, before the sprint's batch GO or right after the release; QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **The shipped docs and skills as an adopter reads them**, in English and Japanese. The adopter has one of the four combinations of mode (`tracked`, `local`) and ignore rule (base dir ignored or not), or a committed base dir under `local`.
2. **The adopting guide as `tests/trial-recipe/extract-recipe.sh` reads it.** That covers the section headings, the fence count, the `--trial-branch` span, the remedy span and the whole-file line floors.
3. **The setup skill as `tests/setup/run.sh`'s token lock reads it.**
4. **The role and skill text a role reads in either record mode.** This covers the engineer's local line, the goal skill's first tick with `team-mode.sh` printing `tracked` or `local` or exiting `2`, and the run skill's reviewer-record bullets.
5. **The Codex agents generated from `agents/engineer.md`.**
6. **The live run's fixture repository**: one small code task with an ignored base dir in a `local` clone.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Doc renderers other than GitHub's Markdown: table and heading anchors are not checked against other renderers.
2. Translations other than the existing English and Japanese pairs.
3. Adopters reading a doc version that does not match their installed plugin version.
4. A goal-skill tick that changes the clone's mode between ticks.

<!-- END intent-block: T-1184 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | README EN/JA rewritten blocks name `local` (D1 (i)) | **AC1** |
| 2 | Adopting guide subsection, four-row table, gate note, Required paragraph, trial section (D1 (ii)) | **AC2** |
| 3 | Trial recipe byte-identical (D1 (ii); N1) | **AC2**, **AC8** |
| 4 | Setup skill relays the `local` item; forbidden tokens stay absent; team-init skill note (D1 (iii)) | **AC3**, **AC8** (setup suite's AC10 token lock) |
| 5 | `rc=n/a` in the PII-controls docs (D1 (iv)) | **AC4** |
| 6 | Pure addition outside the named paragraphs; no removal command added (D1) | **AC1**–**AC4** |
| 7 | Engineer line reworded, one line only; Codex agents regenerate (D2 (a)) | **AC5** |
| 8 | Goal-skill first-tick read and mode line (D2 (b); droppable) | **AC6** |
| 9 | Run-skill reviewer-record sentence after T-1158 (D2 (c)) | **AC7** |
| 10 | Prompt blocks in sync (N3) | **AC9** |
| 11 | Live two-gate run, its timing and recording (D3) | **AC13** |
| 12 | T-1183's deliverables and the D4 files unchanged; #716 items 1–3 untouched | **AC10** |
| 13 | Scope confined to the listed files | **AC11** |
| 14 | No migration guide; no worktree fix; no sweep | info-only (not promoted to AC): exclusions of scope and process, nothing to observe beyond **AC11**'s file set |
| 15 | Pre-commitment and drop order | info-only (not promoted to AC): a disposition, not a deliverable property |
| 16 | CI green | **AC12** |

## Shipped-docs inventory

| Document | What it says today about keeping the base dir out of git | Disposition |
|---|---|---|
| `README.md`, `README.ja.md` | line 75: Required = "must not be ignored by git and must be committed"; lines 94–97: "Both choices are supported", and an untracked base dir is `not-durable` permanently | this task (**AC1**) |
| `docs/adopting.md`, `docs/adopting.ja.md` | 56–70 scope paragraph; 183–186 gate note; 468–480 setup Required paragraph ("does not support never-committed"); 955–959 "**not supported**" | this task (**AC2**) |
| `skills/setup/SKILL.md` | step 5 relays a printed command and a re-include line | this task (**AC3**) |
| `skills/team-init/SKILL.md` | lines 60–62: ignoring the whole base dir is "the user's call" | this task (**AC3**) |
| `docs/pii-controls.md`, `docs/pii-controls.ja.md` | "a zero count" without `rc=n/a` | this task (**AC4**, #716 item 4) |

## Blast radius

- **Method and disclosed deviation (mechanism class).** The checklist calls for a full-population inventory. As in T-1183, the operator's A2 and 2026-10-01 rulings replace it with CI plus this task's own check lines. The read set was found with the Grep tool and is a lower bound. A criterion that reaches an edited file through indirection stays unmeasured.
- **Specs whose criteria read the docs' rewritten paragraphs** may move where they grep the removed sentences. These include T-1042, T-1046, T-1094, T-1098, T-1137 and T-1155. `tests/trial-recipe` is held green by **AC2** and **AC8**.
- **T-1181's frozen criteria on `agents/engineer.md`.** Any criterion that asserts the old wording of the `- **Local record mode (T-1181).**` line goes stale by design (D2 (a)). Disclosed.
- **Adopter-side generated artifacts.** `bin/gen-codex-agents.sh` derives `<repo>/.codex/agents/shell-team-engineer.toml` from `agents/engineer.md`. An adopter's existing generated file goes stale, and `bin/check-codex-agents.sh` reports drift until the adopter regenerates. Migration path: re-run setup (`update shell-team`).

## Version

- **Per-item derivation (CONTRIBUTING's two tests, `## What a version number encodes`).**

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| D1 docs | not met on its own (documents the opt-in capability shipped by T-1180–T-1183) | met (read by every adopter) | PATCH | documentation of an opt-in capability |
| D2 #714 follow-ups | not met | not met (`local` only) | PATCH | wording and a first-tick read |
| D3 live run | not applicable | not applicable | none | verification, ships nothing |

  The task's derived tier is the column maximum, PATCH.
- **Sprint-level premise on record:** MINOR for sprint `local-mode`. The opt-in judgment point was disclosed at planning, and the final naming is deferred to the release.

## Assumptions

- **Relayed (owner: the coordinating session; primary confirmation: issues #711 and #714 on GitHub):** the #711 body as supplied in the file; the planning split of C2 into T-1183 and T-1184; and #714's three items as stated in the briefing. #714's body was not supplied, so the exact rewording of the engineer line is taken from the briefing.
- **Base and its anchors.** `B` is T-1183's tip at the moment this branch is cut, and is not knowable at authoring time. T-1183 changes none of the files this spec's base-side reads target: its **AC11** holds them unchanged against `3cde89ef`. Every base-side anchor below is therefore read from those files at `3cde89ef`. The freeze run measures them at the real `B` and records the values.
- **Measured by this role** (file reads at `3cde89ef`, tree clean): every line anchor in `## Summarized sources`; the README/adopting contradiction at lines 94 and 955; the extractor's fence count, spans and line floors; the setup suite's token lock reading the skill. `skills/team-init/SKILL.ja.md` does not exist. The record-mode block is a `contain` consumer whose canonical sentence is `agents/engineer.md` line 62, so rewording line 55 does not affect `check-prompt-sync.sh`.
- **Own-coinage count premise:** `shell-team.mode`, `record mode` and `local mode` occur 0 times in `README.md`, `README.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `skills/setup/SKILL.md` and `skills/team-init/SKILL.md`. `rc=n/a` occurs 0 times in `docs/pii-controls*.md`. `bin/team-mode.sh"`, `T-1183` and `Record mode for this repo: <resolved mode>` occur 0 times in `skills/goal/SKILL.md`, and `T-1183` occurs 0 times in `skills/run/SKILL.md` (all by the Grep tool at `3cde89ef`).
- **Borrowed anchors the checks rely on.** The coordinating session measures each one at `B` during this task's freeze:
  - Headings in `docs/adopting.md`: `git show "$B:docs/adopting.md" | grep -cxF` for each of `## Where the operating files live`, `## How to run` and `## Trying the team on one ticket` (each expected 1).
  - Headings in `docs/adopting.ja.md`: the same command for `## 稼働ファイルの置き場所`, `## 実行方法` and `## 1 チケットでチームを試す` (each expected 1).
  - The sentences **AC2** requires removed are present at `B`: `the loop does not support never-committed` and `is **not supported**` in `docs/adopting.md`; `ループは一度もコミットされない運用ファイルを支えず` and `**サポートされていません (not supported)**` in `docs/adopting.ja.md` (each expected 1).
  - Each prefix in **AC1** and **AC2** begins at least one line of the base blob. The criteria assert this themselves.
  - `tests/trial-recipe/extract-recipe.sh` exits 0 on each base blob in all four modes.
  - The T-1158 bullet in `skills/run/SKILL.md`: `git show "$B:skills/run/SKILL.md" | awk '{ s = $0; sub(/^[[:space:]]+/, "", s) } index(s, "- **Reviewer records are not all committed (T-1158)**") == 1' | wc -l` (expected 1).
  - The engineer line: `git show "$B:agents/engineer.md" | grep -c '^- \*\*Local record mode (T-1181)\.\*\*'` (expected 1), and that line contains `the task's record files`.
  - Goal-skill headings: `## First tick — initialize state` (1) and `## Each tick` (1) in `skills/goal/SKILL.md`.
  - PII-controls headings: `## When the loop runs it` (1) in `docs/pii-controls.md` and `## ループがこれを走らせる時点` (1) in `docs/pii-controls.ja.md`.
  - `bash bin/check-readme-version.sh README.md README.ja.md` exits 0 at `B`.
  - The recursive-deletion pattern matches none of the five suites in **AC8** or the four checkers in **AC9**. The tech-lead measured the suites; nobody has measured `bin/check-readme-version.sh`.
- **Measured by the coordinating session at freeze (2026-10-11, `B` = `8030996c`, T-1183's tip; the targeted files are byte-identical there to `3cde89ef`, as T-1183's AC11 held):** the three `docs/adopting.md` headings and the three `docs/adopting.ja.md` headings 1 each; the two EN and two JA sentences AC2 removes present 1 each; the T-1158 bullet 1; the `- **Local record mode (T-1181).**` engineer line 1 and it contains `the task's record files`; the two goal-skill headings 1 each; the two PII-controls headings 1 each; `check-readme-version.sh README.md README.ja.md` exit 0; the coinage strings occur in 0 of the named files (`rc=n/a` 0 in the PII docs; the goal-skill and run-skill coinage 0); the recursive-deletion pattern matches none of the five AC8 suites nor the four AC9 checkers (`bin/check-readme-version.sh` included, now measured). Pre-implementation check-acs at df414c7c: AC8, AC9, AC10 green; AC1–AC7 and AC11 red only for the absent text (traced: coinage greps, heading and table positive controls, the removed-sentence counts still 1); AC12 and AC13 are runtime criteria.
- **Local verification limit:** the CI run (**AC12**) is the evidence for bash 5 and the pinned tools.

## Open questions

- None blocking.

## Notes for engineer

- **Files**: the docs and skills in D1, the three D2 lines, provenance, and `.shell-team/test-recipe.md` as usual.
- **The setup skill and the token lock**: `tests/setup/run.sh`'s AC10 requires the fifteen tokens it lists (settings file names and permission and sandbox keywords) to stay absent from `skills/setup/SKILL.md`. Keep the new step-5 text free of them.
- **The trial section**: the rewritten paragraphs must not add any of these, because `tests/trial-recipe` counts each:
  - a fenced block;
  - a second `team-init.sh --trial-branch ` span;
  - a second `git add -f "$(team-paths.sh --get base)" …` span.

  Keep both documents above their whole-file line floors (641 EN / 611 JA). The heading stays byte-identical.
- **Table form (AC2)**: rows start with `` | `tracked` | `` or `` | `local` | ``. The subsection has exactly one header row and one separator row, so exactly six lines begin `|`. Put the committed-base-dir case in prose under the table, not as a fifth row. Describe what setup reports in each case as T-1183 froze it (its D1).
- **No removal command anywhere in the docs.** The committed-base-dir case is the operator's decision, and no command is named for it.
- **Mutation probes**: before hand-off, break each never-dropped property once in a scratch copy and confirm that the matching criterion goes red, then restore. For example, add a fence to the trial section (**AC2**), or drop the engineer line's lead (**AC5**, **AC9** where it applies).
- **Timeout**: **AC8** runs whole suites. QA runs `check-acs.sh` with `CHECK_ACS_TIMEOUT` raised to at least `3600`.
- **Measured-at-ref command check:** not applicable. No deliverable prints a command labelled as measured at a git ref.
- **Review depth:** the docs and skills are shipped text, and `agents/engineer.md` is shipped role text. The inline check lines get dev-scaffold depth (operator ruling).
