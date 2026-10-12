# A migration guide tells an existing adopter what local record mode changes, how to move a clone to it and how to go back

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1185

## Problem

Sprint `local-mode` (issue #711) shipped `local` record mode across T-1180–T-1184: a per-clone `shell-team.mode` key, new setup and init output, a `--paths` shape scan, a hand-off that writes records without committing them, and the docs that describe the mode. The shipped docs describe the mode as it is, not how to get there from an existing install. An adopter who has run the loop in `tracked` mode, often with the base dir already committed, has no page that says what changed, which steps to take in which order, what happens to records already in git, and how to go back. Mixed teams have the same gap: some members use shell-team on a shared application repository and some do not. T-1184 listed this guide as a later task (its Non-goals). The operator added it to the end of the sprint, before the release.

## Summarized sources

- The operator's request (2026-10-11, in-session sprint addition, verbatim): 「このスプリントの最後に、仕組みに変化があったので、既存の環境からの変更点や移行手順をドキュメントとして、加えた上でリリースしたい」. It asks for two things before the release: what changed for an existing environment, and the migration steps. Restated by the Goal sentence and **AC1**–**AC2**.
- The tech-lead's Routing Map for T-1185 (relayed by the coordinating session; this role re-read every premise below it relies on): the placement (two new files linked from the Upgrading paragraph and the README Update section, not an extended Upgrading paragraph), the seven reader questions, the claim inventory, the droppable restatement, and the scope exclusions. Restated by D1–D4 and **AC1**–**AC11**.
- `docs/adopting.md` at `dc4136d9`:
  - line 44 opens the paragraph `**Upgrading an existing adopter repository.**`, which runs to line 54; line 55 is blank.
  - line 87 is `### Keeping the records out of git: local record mode`, the section the guide links to rather than restates.
  - lines 101–106 hold the four-row table (two rows led by `` | `tracked` | ``, two by `` | `local` | ``).
  - line 108 covers the committed-base-dir case: setup lists it under `Remains the operator's decision:` and names no command.
  - lines 112–119 list what the gates do in `local` mode; line 118 says `isolation: worktree` and `bin/land-worktree.sh` are unsupported there.
  - line 970 is `## Trying the team on one ticket`, the section `tests/trial-recipe/extract-recipe.sh` reads.

  `docs/adopting.ja.md` at `dc4136d9` has the counterparts: line 46 (`**既存の adopter リポジトリをアップグレードする場合。**`, to line 56), line 91 (`### 記録を git に載せない: local record mode`), lines 105–110 (table), line 112, and line 964 (`## 1 チケットでチームを試す`). Restated by D1, D2, **AC3**, **AC6**.
- `README.md` at `dc4136d9`: line 103 `## Update` (to line 128; line 129 is `## Usage`); line 123 describes `update shell-team`; line 125 the manual Codex CLI regeneration. `README.ja.md`: line 103 `## 更新`, lines 123 and 125, line 129 `## 使い方`. Restated by D2, **AC4**.
- `docs/distribution.md` lines 116–141 (`## Update`): the upgrade commands, `update shell-team`, and the manual `gen-codex-agents.sh --out-dir .codex/agents` / `check-codex-agents.sh` pair. It does not name the record mode (no `shell-team.mode` or "record mode" in `docs/distribution*.md`, measured with the Grep tool). This task leaves it unchanged and the guide may point at it. Restated by D4, **AC10**.
- `bin/team-mode.sh` lines 19–24 and 87–91: only the exact value `local` in the clone's own `.git/config` selects `local`; an absent key or any other value prints `tracked`; global, system and `git -c` values never select it; exit 2 when git cannot read the config. Help line 48: `git config shell-team.mode local`. So `git config shell-team.mode tracked` returns a clone to `tracked` without a removal verb. Restated by D1 (going back) and **AC2**.
- `bin/team-setup.sh` lines 797, 815, 820 and 823: in `local` mode, a committed base dir goes under `Remains the operator's decision:`; an ignored one goes under `Already in place:`; an unquotable path gets no printed line; a not-ignored one gets a `Required:` item naming `/<dir>/` for the clone's exclude file and a root `.gitignore` line as the alternative. Restated by D1 and **AC2**.
- `bin/team-commit.sh` lines 381–393: in `local` mode, any named path equal to or under the base dir is refused (class `local-mode`) before anything is staged, whether or not the path is tracked. Restated by D1 (committed base dir) and the Notes.
- `bin/check-durability.sh` line 207: `check-durability: skipped: shell-team.mode is local — no durability observation was made`. Restated by D1 (checking the result) and **AC2**.
- `bin/land-worktree.sh`: has no `team-mode`, `shell-team.mode` or `local` mode reference (Grep tool). The worktree limitation is stated in `skills/run/SKILL.md` lines 89 and 328 and `docs/adopting.md` line 118, and is not enforced by this script. Restated by the Notes, so the guide says "unsupported" rather than "refused".
- `bin/check-adopter-docs.sh` lines 25–40: a `this-task` `- shipped-docs:` path must appear as a literal substring in one of the spec's own `- check:` or `- adopter-surface:` lines. An `issue #<N>` path needs no such line. The script does not read `- verification-class:`. Restated by the declarations.
- `.github/workflows/check-handoff.yml`: no step lists `docs/*.md` by glob. Line 93 runs `tests/trial-recipe/run.sh`, line 135 runs `tests/check-readme-version/run.sh`, and line 138 runs `bin/check-readme-version.sh README.md README.ja.md`, which reads only the version badge (`bin/check-readme-version.sh` lines 6–8 and 24–26). No file under `tests/` reads `docs/` by a glob (Grep tool: no `docs/*` or `*.ja.md` pattern). Two new doc files therefore need no new mechanism. Restated by D4 and **AC9**.
- The test files that name an edited path (Grep tool over `tests/**/*.sh` for `docs/adopting` and `README.md`/`README.ja.md`):
  - `tests/trial-recipe/run.sh` lines 36–37 read both adopting guides.
  - `tests/check-readme-version/run.sh` lines 74–75 run the badge checker on both READMEs.
  - `tests/check-adopter-docs/run.sh` line 759 requires `README.md` to exist on disk.
  - `tests/team-init/run.sh` lines 786–788 grep `team-init`'s output, not the file.

  Restated by the `verification-class` declaration and **AC9**.
- `tests/trial-recipe/extract-recipe.sh` lines 24–26 (its four modes `setup|teardown|flag|remedy`), 36–37 (the two section headings), 48–49 (whole-file line floors 641 EN / 611 JA, floors only). Restated by **AC3**.
- `.shell-team/todo.md`, T-1184's `- fast-follow disposition (2026-10-11)` sub-bullet: issue #721 carries the README committed-base qualifier, the no-line outcome missing from the four summaries, and the setup skill's `.gitignore` staging clause. Restated by the `issue #721` shipped-docs lines and Non-goals.

## Goal

<!-- BEGIN intent-block: T-1185 -->

- user-visible: yes — an adopter who already runs shell-team gets a page, in English and Japanese, that says what this release changed, how to stay in `tracked` mode, how to move a clone to `local` mode step by step, what happens when the base dir is already committed, how a mixed team works, how to go back, and how to check the result; `docs/adopting.md` and the README link to it.
- shipped-docs: docs/migrating-to-local-mode.md — this-task
- shipped-docs: docs/migrating-to-local-mode.ja.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: README.md — this-task
- shipped-docs: README.ja.md — this-task
- shipped-docs: skills/setup/SKILL.md — issue #721
- shipped-docs: skills/team-init/SKILL.md — issue #721
- verification-class: no-mechanism — the diff adds two Markdown files and one link line each to `docs/adopting.md`, `docs/adopting.ja.md`, `README.md` and `README.ja.md`; it touches nothing under `bin/`, `tests/`, `agents/`, `skills/`, `templates/` or `.github/`, and the executing surfaces that read the edited files are `tests/trial-recipe` (the adopting guides), `bin/check-readme-version.sh` and its suite (the README badge), and `tests/check-adopter-docs` (requires `README.md` on disk), all run by **AC8** and **AC9**. The claim inventory's probes read what the shipped scripts print in order to back a sentence of the guide; they verify the guide, not the scripts.
- verification-ceiling: unit-and-static — **AC1**–**AC11** are settled in a plain checkout through string presence and order, byte-scoped comparisons against the base blobs, the trial-recipe extractor's output, records-line existence in this spec's claim inventory, and the exit codes of `check-adopter-docs.sh`, `check-handoff.sh`, `check-readme-version.sh` and three fixture suites. **AC12** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: two-arm, predecessor `feature/711-local-mode-docs` (T-1184, open at authoring time), integration branch `develop`. Every base-side read in **AC3**–**AC5**, **AC10** and **AC11** resolves `B` with the same byte-identical chain: `git merge-base "feature/711-local-mode-docs" HEAD` when `git show-ref --verify --quiet refs/heads/feature/711-local-mode-docs` succeeds; else `git merge-base "refs/remotes/origin/feature/711-local-mode-docs" HEAD` when `git show-ref --verify --quiet refs/remotes/origin/feature/711-local-mode-docs` succeeds; else `git merge-base "develop" HEAD` (local `refs/heads/develop`, then `refs/remotes/origin/develop`); none of them resolving is a failure (exit 1), never a pass. `B` is `dc4136d9`, T-1184's tip, while this branch stays stacked.

**Goal (one sentence).** Two new documents, `docs/migrating-to-local-mode.md` and `docs/migrating-to-local-mode.ja.md`, answer in seven fixed sections what an existing adopter needs to move to `local` record mode, stay in `tracked`, handle an already-committed base dir, run a mixed team, go back, and check the result. Each sentence that states shipped behaviour is backed by an inventoried script or doc line. The adopting guide and the README each link to it through a pure addition, and no removal command appears anywhere.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — the guide's content, one section per reader question, EN and JA in lockstep.** Both files carry the same level-1 and level-2 headings in the same order (**AC1**). The fenced code lines are byte-identical between the two languages (**AC1**). Section by section (**AC2**):
  - **What changed in this release.** It names `shell-team.mode` and links to the adopting guide's `local` record mode section instead of restating its four-row table (**AC6**). It may summarize setup's and init's new output, `check-pii-shapes.sh --paths`, the hand-off in `local` mode (records written and never committed, code still committed), the worktree limitation, the regenerated Codex agents (`.codex/agents/shell-team-*.toml`, with `check-codex-agents.sh` reporting drift until they are regenerated) and the `update shell-team` / `set up shell-team` prompts. That summary is the droppable component.
  - **Staying in tracked mode.** The upgrade, `update shell-team`, and regenerating `.codex/agents` on a Codex CLI host.
  - **Moving a clone to local mode.** A numbered list. Its first item is `git config shell-team.mode local`. The ignore line follows: `info/exclude` preferred, with the root `.gitignore` alternative and its per-clone caveat, since every clone that inherits the shared line must also declare `local`. `update shell-team` comes after that. The section also says what setup then reports and what the loop stops doing, including `isolation: worktree`.
  - **When the base dir is already committed.** Ignore rules do not apply to tracked files. Setup reports a `Remains the operator's decision:` item. The section describes the consequence of keeping and of stopping tracking, and names no command for either (no fenced block in the section, and no removal command anywhere: **AC5**).
  - **Teams where not everyone uses shell-team.** Adopters declare `shell-team.mode local` in their own clones and keep the ignore line in `info/exclude`. The shared repository does not track the base dir, so members who do not use shell-team see nothing.
  - **Going back to tracked mode.** It names `git config shell-team.mode tracked`; never `--unset`.
  - **Checking the result.** It names what `team-mode.sh`, `check-durability.sh` and `git status` show (and may name `team-setup.sh`).
- **D2 — the links.** One added line inside the `**Upgrading an existing adopter repository.**` paragraph of `docs/adopting.md` links `migrating-to-local-mode.md`. The JA paragraph `**既存の adopter リポジトリをアップグレードする場合。**` in `docs/adopting.ja.md` links `migrating-to-local-mode.ja.md`. Both are pure additions, so every other line is unchanged, and the trial section reads the same to the extractor (**AC3**). One added line in README's `## Update` links `docs/migrating-to-local-mode.md`, and one in README.ja's `## 更新` links `docs/migrating-to-local-mode.ja.md`. Both are pure additions (**AC4**). `check-readme-version.sh` stays green (**AC8**).
- **D3 — claim inventory.** A mutable `## Claim inventory` section, after the intent block, has one row per claim line of the EN guide. Each row gives the JA counterpart line and at least one backing `bin/<script>:<line>` or shipped-doc `<path>:<line>` anchor that exists at HEAD. For runtime behaviour, the row also gives the scratch-repository probe and its observed output. The engineer writes it and QA reads it against the scripts (**AC7**).
- **D4 — unchanged.** Nothing under `bin/`, `tests/`, `agents/`, `skills/`, `templates/` or `.github/`, and none of `CHANGELOG.md`, `CHANGELOG.ja.md`, `CONTRIBUTING.md`, `docs/distribution.md` or `docs/distribution.ja.md` (**AC10**). The diff is confined to the six documents and this task's records (**AC11**).

**Pre-commitment (frozen before round 1; AI self-discipline, never operator-ratified).**

- **Trigger.** Two consecutive rounds, QA or code review, each with a recorded verdict and each with a new finding of the class "a guide sentence is contradicted by a script or by shipped text". A round interrupted before a verdict is not counted.
- **Never-dropped.**
  - (N1) the two ordered step lists: moving to `local` and going back (**AC2**).
  - (N2) the committed-base-dir section, with no command and no removal command (**AC2**, **AC5**).
  - (N3) EN/JA lockstep (**AC1**).

  A defeat of N1–N3 stops the task and returns it to planning.
- **Droppable, first and only.** The restated behaviour detail in "What changed in this release" and "Checking the result". When the trigger fires, those two sections shrink to links into `docs/adopting.md` plus the scripts' `--help`, and keep only the tokens **AC2** requires. The firing round's findings become the requirement list for that rewrite, and the claim-inventory rows shrink with them. **AC2** and **AC7** are written so the shrunk form still passes. No criterion changes.

## Non-goals

- **No change to any executing surface or to the release files.** Nothing under `bin/`, `tests/`, `agents/`, `skills/`, `templates/`, `.github/`; no `CHANGELOG.md` / `CHANGELOG.ja.md`, version bump or badge (written on the release-preparation branch per `CONTRIBUTING.md` `## Cutting a release`); no `CONTRIBUTING.md`; no `docs/distribution.md` / `.ja.md`. (**AC10**)
- **No removal command in any of the six documents.** That covers deleting files, dropping them from the index, rewriting history, and unsetting the key. A committed base dir stays the operator's decision. (**AC5**)
- **No second copy of the four-row mode table.** The guide links to it. (**AC6**)
- **No issue #721 item.** The README committed-base qualifier, the four summaries' no-line outcome and the setup skill's `.gitignore` clause stay on #721. (**AC10**, **AC11**)
- **No fix for worktree isolation in `local` mode** and no change to what setup reports. The guide documents both as they are. (**AC10**)
- **No full-population sweep, no whole CI-equivalent re-run, no behaviour verification of a mechanism this task does not touch, and no local run of past specs' check lines.** The criteria use four verification shapes: string presence, order and absence; byte-scoped diffs; checker and suite exit codes; and records-line existence in the claim inventory. Operator rulings: A2 light operation and the 2026-10-01 ruling. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree, writing only under `$TMPDIR`.
- **Timeouts and caps.** A line that runs a script uses a `tmo` helper (120 s) or a `tms` helper (1200 s, for whole suites). The helper starts the script in its own process group under `ulimit -f`, pipes its stdout through `head -c`, kills the group on timeout, and writes the captured streams to files bounded by that limit. No helper traces its own commands (`set -x`) into a captured stream.
- **What lines never contain.** No check line uses `ps`, a recursive deletion, `xargs` or a removal command. Absence patterns spell the tokens with a bracketed character so the line does not carry the literal token.
- **Scan before run.** A suite or checker is scanned for a recursive-deletion pattern before it runs. If it matches, it is not run and the criterion fails.
- **Base-side reads.** They use the chain in the `base-ref-discriminator` declaration, spelled byte-identically.
- **Staleness.** The criteria that read `B` are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`.

- [ ] **AC1** (D1; N3.) The two guides exist, are committed, and are in lockstep.
  - **Exist and committed.** `docs/migrating-to-local-mode.md` and `docs/migrating-to-local-mode.ja.md` are non-empty and present in the `HEAD` tree.
  - **Fences.** Fences are backtick fences only, so no line begins with `~~~`. Each file has at least one fence, and the number of fence delimiter lines (lines beginning with three backticks) is even.
  - **Headings (EN).** Outside fences, the lines beginning `# ` or `## ` of the EN file are exactly these, in this order:
    1. `# Moving an existing repository to local record mode`
    2. `## What changed in this release`
    3. `## Staying in tracked mode`
    4. `## Moving a clone to local mode`
    5. `## When the base dir is already committed`
    6. `## Teams where not everyone uses shell-team`
    7. `## Going back to tracked mode`
    8. `## Checking the result`
  - **Headings (JA).** The JA file's are exactly these, in this order:
    1. `# 既存のリポジトリを local record mode に移す`
    2. `## このリリースで変わったこと`
    3. `## tracked モードのまま使う`
    4. `## クローンを local モードに移す`
    5. `## base dir がすでにコミットされている場合`
    6. `## shell-team を使う人と使わない人が混在するチーム`
    7. `## tracked モードに戻す`
    8. `## 結果を確かめる`

    Deeper headings (`###`) are free.
  - **Fenced lines identical.** The sequence of fence delimiter and fenced content lines is byte-identical between the two files.
  - adopter-surface: docs/migrating-to-local-mode.md and docs/migrating-to-local-mode.ja.md (the new guide, seven sections), linked from docs/adopting.md and docs/adopting.ja.md (the Upgrading paragraph) and from README.md (`## Update`) and README.ja.md (`## 更新`).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac1.XXXXXX") || exit 1; E=docs/migrating-to-local-mode.md; J=docs/migrating-to-local-mode.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; git cat-file -e "HEAD:$f" || rc=1; grep -q '^~~~' "$f"; test "$?" = 1 || rc=1; awk 'index($0, "```") == 1 { n++ } END { exit (n == 0 || n % 2) }' "$f" || rc=1; done; hd(){ awk 'index($0, "```") == 1 { f = !f; next } !f && /^##? / { print }' "$1"; }; fen(){ awk 'index($0, "```") == 1 { f = !f; print; next } f' "$1"; }; printf '%s\n' '# Moving an existing repository to local record mode' '## What changed in this release' '## Staying in tracked mode' '## Moving a clone to local mode' '## When the base dir is already committed' '## Teams where not everyone uses shell-team' '## Going back to tracked mode' '## Checking the result' > "$T/he"; printf '%s\n' '# 既存のリポジトリを local record mode に移す' '## このリリースで変わったこと' '## tracked モードのまま使う' '## クローンを local モードに移す' '## base dir がすでにコミットされている場合' '## shell-team を使う人と使わない人が混在するチーム' '## tracked モードに戻す' '## 結果を確かめる' > "$T/hj"; hd "$E" > "$T/ae"; hd "$J" > "$T/aj"; cmp -s "$T/he" "$T/ae" || rc=1; cmp -s "$T/hj" "$T/aj" || rc=1; fen "$E" > "$T/fe"; fen "$J" > "$T/fj"; test -s "$T/fe" || rc=1; cmp -s "$T/fe" "$T/fj" || rc=1; test "$rc" -eq 0

- [ ] **AC2** (D1; N1, N2.) What each section carries, in both files. A section runs from its `## ` heading to the next level-1 or level-2 heading outside a fence. Each of the seven sections is non-empty.
  - **What changed.** The section contains `shell-team.mode` and the link target. The EN target is `adopting.md#keeping-the-records-out-of-git-local-record-mode`. The JA target is `adopting.ja.md#記録を-git-に載せない-local-record-mode`.
  - **Staying in tracked mode.** The section contains `update shell-team` and `.codex/agents`.
  - **Moving a clone to local mode (N1).** The section has a numbered list starting at a line that begins `1. `. From that line on, the first occurrences of three tokens fall on three strictly increasing lines: `git config shell-team.mode local`, then `info/exclude`, then `update shell-team`. The section also contains `.gitignore` and `isolation: worktree`.
  - **Committed base dir (N2).** The section contains `Remains the operator's decision:` and no line beginning with three backticks.
  - **Mixed team.** The section contains `info/exclude` and `shell-team.mode local`.
  - **Going back (N1).** The section contains `git config shell-team.mode tracked`.
  - **Checking the result.** The section contains `team-mode.sh`, `check-durability.sh` and `git status`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac2.XXXXXX") || exit 1; sec(){ awk -v h="$1" 'index($0, "```") == 1 { f = !f; if (s) print; next } !f && $0 == h { s = 1; next } !f && s && /^##? / { s = 0 } s' "$2"; }; pos(){ grep -nF -- "$1" "$2" | head -n 1 | cut -d: -f1; }; printf '%s\n' 'docs/migrating-to-local-mode.md|## What changed in this release|## Staying in tracked mode|## Moving a clone to local mode|## When the base dir is already committed|## Teams where not everyone uses shell-team|## Going back to tracked mode|## Checking the result|adopting.md#keeping-the-records-out-of-git-local-record-mode' 'docs/migrating-to-local-mode.ja.md|## このリリースで変わったこと|## tracked モードのまま使う|## クローンを local モードに移す|## base dir がすでにコミットされている場合|## shell-team を使う人と使わない人が混在するチーム|## tracked モードに戻す|## 結果を確かめる|adopting.ja.md#記録を-git-に載せない-local-record-mode' > "$T/rows"; n=0; while IFS='|' read -r f hw hs hm hc hx hb hv an; do n=$((n + 1)); test -s "$f" || { rc=1; continue; }; for h in "$hw" "$hs" "$hm" "$hc" "$hx" "$hb" "$hv"; do sec "$h" "$f" > "$T/s"; grep -q '[^[:space:]]' "$T/s" || rc=1; done; sec "$hw" "$f" > "$T/w"; grep -qF -- "$an" "$T/w" || rc=1; grep -qF 'shell-team.mode' "$T/w" || rc=1; sec "$hs" "$f" > "$T/st"; for q in 'update shell-team' '.codex/agents'; do grep -qF -- "$q" "$T/st" || rc=1; done; sec "$hm" "$f" > "$T/m"; for q in '.gitignore' 'isolation: worktree'; do grep -qF -- "$q" "$T/m" || rc=1; done; awk 'g || /^1\. / { g = 1; print }' "$T/m" > "$T/m2"; test -s "$T/m2" || rc=1; a=$(pos 'git config shell-team.mode local' "$T/m2"); b=$(pos 'info/exclude' "$T/m2"); c=$(pos 'update shell-team' "$T/m2"); { test -n "$a" && test -n "$b" && test -n "$c" && test "$a" -lt "$b" && test "$b" -lt "$c"; } || rc=1; sec "$hc" "$f" > "$T/c"; grep -qF "Remains the operator's decision:" "$T/c" || rc=1; grep -q '^```' "$T/c"; test "$?" = 1 || rc=1; sec "$hx" "$f" > "$T/x"; for q in 'info/exclude' 'shell-team.mode local'; do grep -qF -- "$q" "$T/x" || rc=1; done; sec "$hb" "$f" > "$T/bk"; grep -qF 'git config shell-team.mode tracked' "$T/bk" || rc=1; sec "$hv" "$f" > "$T/v"; for q in 'team-mode.sh' 'check-durability.sh' 'git status'; do grep -qF -- "$q" "$T/v" || rc=1; done; done < "$T/rows"; test "$n" = 2 || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D2.) The adopting guide's link sentence, EN and JA.
  - **Pure addition.** `git diff --no-renames --numstat <base>...HEAD` reports one row for each of `docs/adopting.md` and `docs/adopting.ja.md`, with a positive added count and `0` deleted.
  - **Inside the Upgrading paragraph.** In the HEAD file, exactly one line begins with the paragraph's lead: `**Upgrading an existing adopter repository.**` in EN, `**既存の adopter リポジトリをアップグレードする場合。**` in JA. The paragraph runs from that line to the line before the next empty line. Every added line, located by the HEAD-side line numbers in the diff's hunk headers, lies after the lead line and within the paragraph.
  - **The link.** An added line contains `](migrating-to-local-mode.md` in EN and `](migrating-to-local-mode.ja.md` in JA.
  - **Trial recipe unchanged.** For each file, `tests/trial-recipe/extract-recipe.sh` runs in each of its four modes (`setup`, `teardown`, `flag`, `remedy`) on both the base blob and the HEAD file. Every run exits `0`, the base output is non-empty, and the base and HEAD outputs are identical.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && { "$@" 2> "$e" | head -c 5000000; exit "${PIPESTATUS[0]}"; } ) < /dev/null > "$o" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; BR=feature/711-local-mode-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; EX=tests/trial-recipe/extract-recipe.sh; test -s "$EX" || exit 1; printf '%s\n' 'docs/adopting.md|**Upgrading an existing adopter repository.**|](migrating-to-local-mode.md' 'docs/adopting.ja.md|**既存の adopter リポジトリをアップグレードする場合。**|](migrating-to-local-mode.ja.md' > "$T/rows"; n=0; while IFS='|' read -r f ld k; do n=$((n + 1)); test -s "$f" || { rc=1; continue; }; git diff --no-renames --numstat "$B"...HEAD -- "$f" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; L=$(awk -v l="$ld" 'index($0, l) == 1 { n++; L = NR } END { if (n != 1) exit 1; print L }' "$f") || { rc=1; continue; }; P=$(awk -v L="$L" 'NR > L && NF == 0 { print NR - 1; exit }' "$f"); test -n "$P" || { rc=1; continue; }; git diff --no-renames -U0 "$B"...HEAD -- "$f" > "$T/d" || exit 1; awk '/^@@ / { s = $3; sub(/^\+/, "", s); m = split(s, a, ","); c = a[1] + 0; d = (m > 1) ? a[2] + 0 : 1; for (i = 0; i < d; i++) print c + i }' "$T/d" > "$T/al"; test -s "$T/al" || rc=1; awk -v L="$L" -v P="$P" '{ if ($1 <= L || $1 > P) bad = 1 } END { exit bad }' "$T/al" || rc=1; awk 'index($0, "+") == 1 && index($0, "+++") != 1 { print substr($0, 2) }' "$T/d" | grep -qF -- "$k" || rc=1; git show "$B:$f" > "$T/bd.md" || { rc=1; continue; }; for md in setup teardown flag remedy; do tmo "$R" "$T/x0" "$T/e0" bash "$EX" "$T/bd.md" "$md"; test "$?" = 0 || rc=1; tmo "$R" "$T/x1" "$T/e1" bash "$EX" "$f" "$md"; test "$?" = 0 || rc=1; test -s "$T/x0" || rc=1; cmp -s "$T/x0" "$T/x1" || rc=1; done; done < "$T/rows"; test "$n" = 2 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D2.) The README link sentence, EN and JA.
  - **Pure addition.** `git diff --no-renames --numstat <base>...HEAD` reports one row for each of `README.md` and `README.ja.md`, with a positive added count and `0` deleted.
  - **Inside the update section.** The heading `## Update` (EN) or `## 更新` (JA) occurs exactly once in the base blob and exactly once in the HEAD file. Every added line, by its HEAD-side line number, lies after that heading and before the next line beginning `## ` (or the end of the file).
  - **The link.** An added line contains `](docs/migrating-to-local-mode.md` in EN and `](docs/migrating-to-local-mode.ja.md` in JA.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac4.XXXXXX") || exit 1; BR=feature/711-local-mode-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; printf '%s\n' 'README.md|## Update|](docs/migrating-to-local-mode.md' 'README.ja.md|## 更新|](docs/migrating-to-local-mode.ja.md' > "$T/rows"; n=0; while IFS='|' read -r f h k; do n=$((n + 1)); test -s "$f" || { rc=1; continue; }; git show "$B:$f" > "$T/b" || { rc=1; continue; }; test "$(grep -cxF -- "$h" "$T/b")" = 1 || rc=1; test "$(grep -cxF -- "$h" "$f")" = 1 || { rc=1; continue; }; git diff --no-renames --numstat "$B"...HEAD -- "$f" > "$T/ns" || exit 1; test "$(wc -l < "$T/ns" | tr -d ' ')" = 1 || rc=1; awk '{ if ($1 == "-" || $2 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit bad }' "$T/ns" || rc=1; H=$(grep -nxF -- "$h" "$f" | head -n 1 | cut -d: -f1); E=$(awk -v H="$H" 'NR > H && /^## / { print NR; exit }' "$f"); test -n "$E" || E=$(( $(wc -l < "$f") + 1 )); git diff --no-renames -U0 "$B"...HEAD -- "$f" > "$T/d" || exit 1; awk '/^@@ / { s = $3; sub(/^\+/, "", s); m = split(s, a, ","); c = a[1] + 0; d = (m > 1) ? a[2] + 0 : 1; for (i = 0; i < d; i++) print c + i }' "$T/d" > "$T/al"; test -s "$T/al" || rc=1; awk -v H="$H" -v E="$E" '{ if ($1 <= H || $1 >= E) bad = 1 } END { exit bad }' "$T/al" || rc=1; awk 'index($0, "+") == 1 && index($0, "+++") != 1 { print substr($0, 2) }' "$T/d" | grep -qF -- "$k" || rc=1; done < "$T/rows"; test "$n" = 2 || rc=1; test "$rc" -eq 0

- [ ] **AC5** (Non-goals; N2.) No removal command is added to any of the six documents.
  - **Scope.** The added lines of `git diff --no-renames -U0 <base>...HEAD` over `docs/migrating-to-local-mode.md`, `docs/migrating-to-local-mode.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `README.md` and `README.ja.md`.
  - **Positive control.** The added lines are non-empty and contain `git config shell-team.mode local`.
  - **Forbidden tokens.** No added line carries any of: `git rm`; `--cached`; `rm` as a word followed by whitespace; `git clean`; `filter-`; `reset --hard`; `--unset`. The grep exits exactly `1` (no match). An exit status of `2` (read error) fails the criterion.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac5.XXXXXX") || exit 1; BR=feature/711-local-mode-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; git diff --no-renames -U0 "$B"...HEAD -- docs/migrating-to-local-mode.md docs/migrating-to-local-mode.ja.md docs/adopting.md docs/adopting.ja.md README.md README.ja.md > "$T/d" || exit 1; awk 'index($0, "+") == 1 && index($0, "+++") != 1 { print substr($0, 2) }' "$T/d" > "$T/new"; test -s "$T/new" || rc=1; grep -qF 'git config shell-team.mode local' "$T/new" || rc=1; grep -qE -- 'git r[m]([[:space:]]|$)|--cache[d]|(^|[^A-Za-z0-9_-])r[m][[:space:]]|git clea[n]|filte[r]-|rese[t][[:space:]]+--har[d]|--unse[t]' "$T/new"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC6** (D1; the restatement guard.) The four-row table is linked, not restated.
  - **No restated rows.** Neither guide has a line matching `^\|[[:space:]]*`(tracked|local)`[[:space:]]*\|`, the shape of a row led by a mode.
  - **Live pattern (positive control).** The same pattern matches at least one line of `docs/adopting.md` and of `docs/adopting.ja.md`.
  - **The link.** The EN guide contains `adopting.md#keeping-the-records-out-of-git-local-record-mode`, and the JA guide contains `adopting.ja.md#記録を-git-に載せない-local-record-mode`.

  The guard holds equally before and after the droppable detail is dropped.
  - check: rc=0; export LC_ALL=C; RX='^\|[[:space:]]*`(tracked|local)`[[:space:]]*\|'; for x in 'docs/migrating-to-local-mode.md|docs/adopting.md|adopting.md#keeping-the-records-out-of-git-local-record-mode' 'docs/migrating-to-local-mode.ja.md|docs/adopting.ja.md|adopting.ja.md#記録を-git-に載せない-local-record-mode'; do g="${x%%|*}"; r="${x#*|}"; a="${r%%|*}"; k="${r#*|}"; test -s "$g" || { rc=1; continue; }; test -s "$a" || { rc=1; continue; }; grep -qE -- "$RX" "$g"; test "$?" = 1 || rc=1; grep -qE -- "$RX" "$a" || rc=1; grep -qF -- "$k" "$g" || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** (D3.) The claim inventory is complete and its anchors exist.
  - **Section.** This spec has exactly one `## Claim inventory` heading line. Its section runs to the next `## ` line. Its rows are the lines beginning `| EN `.
  - **Row format.** Each row has at least five cells, in the form `| EN <n> | JA <m> | <claim> | <anchors> | <probe and observed output, or static> |`. The first cell is `EN` and a number, and the second is `JA` and a number.
  - **Claim lines.** A claim line is a non-empty line of the EN guide that lies outside fences and is not a heading. It must contain at least one of these, matched as an extended regular expression: `\.sh`, `` `local` ``, `` `tracked` ``, `shell-team\.mode`, `info/exclude`, `\.gitignore`, `git status`, `update shell-team`, `set up shell-team`, `\.codex/agents`, `Remains the operator`.
  - **Coverage.** The set of `EN` line numbers in the rows equals the set of claim-line numbers, and is non-empty. Every `JA` line number names a non-empty, non-heading line outside fences in the JA guide.
  - **Anchors.** Each row carries at least one anchor matching `(bin/<name>.sh|docs/<name>.md|README(.ja)?.md|skills/<name>/SKILL.md|agents/<name>.md):<line>` that does not point into the guide itself. Every such anchor names a path present in the `HEAD` tree whose line count is at least `<line>`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac7.XXXXXX") || exit 1; S=.shell-team/specs/T-1185-local-mode-migration-guide.md; E=docs/migrating-to-local-mode.md; J=docs/migrating-to-local-mode.ja.md; for f in "$S" "$E" "$J"; do test -s "$f" || exit 1; done; test "$(grep -cxF '## Claim inventory' "$S")" = 1 || exit 1; awk '$0 == "## Claim inventory" { s = 1; next } s && /^## / { s = 0 } s' "$S" | awk 'index($0, "| EN ") == 1' > "$T/rows"; test -s "$T/rows" || rc=1; awk -F'|' '{ if (NF < 7) { bad = 1; next } e = $2; j = $3; if (e !~ /^ EN [0-9]+ $/ || j !~ /^ JA [0-9]+ $/) { bad = 1; next } gsub(/[^0-9]/, "", e); gsub(/[^0-9]/, "", j); print e "\t" j } END { exit bad }' "$T/rows" > "$T/pairs" || rc=1; CR='\.sh|`local`|`tracked`|shell-team\.mode|info/exclude|\.gitignore|git status|update shell-team|set up shell-team|\.codex/agents|Remains the operator'; elig(){ awk 'index($0, "```") == 1 { f = !f; next } !f && NF && !/^#/ { print NR "\t" $0 }' "$1"; }; elig "$E" | grep -E -- "$CR" | cut -f1 | sort -u > "$T/cl"; test -s "$T/cl" || rc=1; cut -f1 "$T/pairs" | sort -u > "$T/en"; test -z "$(comm -3 "$T/cl" "$T/en")" || rc=1; elig "$J" | cut -f1 | sort -u > "$T/jok"; cut -f2 "$T/pairs" | sort -u > "$T/ja"; test -s "$T/ja" || rc=1; test -z "$(comm -23 "$T/ja" "$T/jok")" || rc=1; AR='(bin/[A-Za-z0-9._-]+\.sh|docs/[A-Za-z0-9._-]+\.md|README(\.ja)?\.md|skills/[A-Za-z0-9._-]+/SKILL\.md|agents/[A-Za-z0-9._-]+\.md):[0-9]+'; while IFS= read -r row; do printf '%s\n' "$row" | grep -oE -- "$AR" | grep -v '^docs/migrating-to-local-mode' > "$T/a"; test -s "$T/a" || { rc=1; continue; }; while IFS=: read -r p ln; do git cat-file -e "HEAD:$p" 2> /dev/null || { rc=1; continue; }; L=$(git show "HEAD:$p" | wc -l | tr -d ' '); { test "$ln" -ge 1 && test "$ln" -le "$L"; } || rc=1; done < "$T/a"; done < "$T/rows"; test "$rc" -eq 0

- [ ] **AC8** Conformance.
  - **Scan.** Before they run, `bin/check-adopter-docs.sh`, `bin/check-handoff.sh` and `bin/check-readme-version.sh` are each scanned for a recursive-deletion pattern, with backslash-continued lines joined. None may match.
  - **`check-adopter-docs.sh`.** `bash bin/check-adopter-docs.sh` on this spec exits `0`, with zero bytes on both streams.
  - **`check-handoff.sh`.** `bash bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - **`check-readme-version.sh`.** `bash bin/check-readme-version.sh README.md README.ja.md` exits `0`, given its arguments as CI gives them.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac8.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && { "$@" 2> "$e" | head -c 5000000; exit "${PIPESTATUS[0]}"; } ) < /dev/null > "$o" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; for s in bin/check-adopter-docs.sh bin/check-handoff.sh bin/check-readme-version.sh; do test -s "$s" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$s" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; done; S=.shell-team/specs/T-1185-local-mode-migration-guide.md; test -s "$S" || exit 1; tmo "$R" "$T/o" "$T/e" bash bin/check-adopter-docs.sh "$S"; test "$?" = 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; tmo "$R" "$T/o" "$T/e" bash bin/check-handoff.sh "$BD"; test "$?" = 0 || rc=1; tmo "$R" "$T/o" "$T/e" bash bin/check-readme-version.sh README.md README.ja.md; test "$?" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC9** The suites that read the edited files.
  - **Suites.** `tests/trial-recipe/run.sh`, `tests/check-readme-version/run.sh` and `tests/check-adopter-docs/run.sh`: the suites that name an edited path (see Summarized sources).
  - **Scan.** Before it runs, each suite is scanned for a recursive-deletion pattern, with backslash-continued lines joined. It must not match.
  - **Run.** Each suite runs in its own process group, killed after 1200 s, under a file-size limit, with its output capped by `head -c`. It exits `0`, and its output is non-empty with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac9.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID CLAUDE_CONFIG_DIR PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; mkdir -p "$HOME" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; bash "$1" < /dev/null 2>&1 | head -c 20000000; exit "${PIPESTATUS[0]}" ) > "$2" & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; n=0; for s in tests/trial-recipe/run.sh tests/check-readme-version/run.sh tests/check-adopter-docs/run.sh; do n=$((n + 1)); test -s "$s" || { rc=1; continue; }; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$s" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || { rc=1; continue; }; test "${ps2[1]}" -eq 1 || { rc=1; continue; }; L="$T/log-$n"; tms "$s" "$L"; test "$?" -eq 0 || rc=1; test -s "$L" || rc=1; grep -q '^FAIL' "$L"; test "$?" = 1 || rc=1; done; test "$n" = 3 || rc=1; test "$rc" -eq 0

- [ ] **AC10** (D4.) The untouched set.
  - **Positive control.** Each of `bin`, `tests`, `agents`, `skills`, `templates`, `.github`, `CHANGELOG.md`, `CHANGELOG.ja.md`, `CONTRIBUTING.md`, `docs/distribution.md` and `docs/distribution.ja.md` exists in the base tree.
  - **Empty diff.** `git diff --no-renames --quiet <base>...HEAD` over all of them exits `0`.
  - check: rc=0; export LC_ALL=C; BR=feature/711-local-mode-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; n=0; for p in bin tests agents skills templates .github CHANGELOG.md CHANGELOG.ja.md CONTRIBUTING.md docs/distribution.md docs/distribution.ja.md; do n=$((n + 1)); git cat-file -e "$B:$p" || rc=1; done; test "$n" = 11 || rc=1; git diff --no-renames --quiet "$B"...HEAD -- bin tests agents skills templates .github CHANGELOG.md CHANGELOG.ja.md CONTRIBUTING.md docs/distribution.md docs/distribution.ja.md; test "$?" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `docs/migrating-to-local-mode.md`.
  - **Allowed members.** Every member is one of:
    - `docs/migrating-to-local-mode.md`, `docs/migrating-to-local-mode.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `README.md`, `README.ja.md`;
    - `.shell-team/specs/T-1185-<slug>.md`, `.shell-team/provenance/T-1185.md`, `.shell-team/interventions/T-1185.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1185.md`;
    - a raw capture `.shell-team/reviews/T-1185-codex-<stem>.{txt,jsonl,json}`;
    - `.shell-team/todo.md`, `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1185-ac11.XXXXXX") || exit 1; BR=feature/711-local-mode-docs; if git show-ref --verify --quiet "refs/heads/$BR"; then B=$(git merge-base "$BR" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$BR"; then B=$(git merge-base "refs/remotes/origin/$BR" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF docs/migrating-to-local-mode.md "$T/s" || rc=1; grep -vxE 'docs/migrating-to-local-mode(\.ja)?\.md|docs/adopting(\.ja)?\.md|README(\.ja)?\.md|\.shell-team/(specs/T-1185-[a-z0-9-]+\.md|provenance/T-1185\.md|interventions/(T-1185|no-task)\.md|reviews/T-1185\.md|reviews/T-1185-codex-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** CI is green on the pull request, including the trial-recipe and check-readme-version suites, the readme-version dogfood step and the diff-scoped PII scan of the pull request.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **An adopter in `tracked` mode whose base dir is committed** (the shipped default up to this release), who upgrades and either stays `tracked` or moves the clone to `local`.
2. **An adopter whose base dir is ignored but who never declared `local`.** That clone is `tracked` with an ignored base dir, so setup reports a blocking rule; the adopter declares `local` to resolve it.
3. **A mixed team on a shared application repository.** Some members use shell-team and declare `local` in their own clones with `info/exclude`; others never run it.
4. **An adopter going back from `local` to `tracked`.** That covers `git config shell-team.mode tracked`, and any value other than exact `local`, which reads as `tracked`.
5. **Both hosts.** Claude Code, and the Codex CLI with generated `.codex/agents/shell-team-*.toml` that drift until they are regenerated.
6. **The six documents as their readers parse them.** That is: the EN and JA guides as an adopter reads them; the adopting guides as `tests/trial-recipe/extract-recipe.sh` reads them (its four modes and line floors); the READMEs as `bin/check-readme-version.sh` reads them (the badge).

**Out-of-scope synthetic extremes**, declined explicitly:

1. Doc renderers other than GitHub's Markdown: heading anchors are not checked against other renderers.
2. Translations other than the English and Japanese pair.
3. An adopter reading this guide while running a plugin version older than the release that ships it.
4. `isolation: worktree` users who want `local` mode: the guide documents it as unsupported and offers no workaround.
5. A `shell-team.mode` value set at global or system scope or through `git -c`. The adopting guide already says it never selects `local`, and the guide links there rather than covering it.
6. A legacy-layout repository (`tasks/` + `docs/specs/`) whose specs directory lies outside the base dir: the adopting guide covers how setup reports it, and the guide does not add a separate procedure.

<!-- END intent-block: T-1185 -->

## Claim inventory

Written by the engineer, and rewritten whenever the EN guide's line numbers move. There is one row per claim line, as **AC7** defines it. The header row must not begin with `| EN `. Use `| Guide line (EN) | Guide line (JA) | Claim | Backing anchors | Probe and observed output |` followed by `|---|---|---|---|---|`. A row looks like `| EN 12 | JA 12 | <claim in a few words> | bin/team-mode.sh:87 | <command> → <observed line>, or static |`. Do not use a literal `|` inside a cell; write a pipe as "piped to".

| Guide line (EN) | Guide line (JA) | Claim | Backing anchors | Probe and observed output |
|---|---|---|---|---|
| EN 7 | JA 7 | a clone with no `shell-team.mode` key is `tracked`; `local` is opt-in per clone | bin/team-mode.sh:17 bin/team-mode.sh:90 docs/adopting.md:90 | P1: fresh scratch clone, no key, team-mode.sh printed `tracked` |
| EN 9 | JA 9 | the key is per clone, in its own git config; the adopting guide holds the one description and the table | bin/team-mode.sh:19 docs/adopting.md:88 docs/adopting.md:96 | P8: a fresh clone of a `local` clone has no key (git config exit 1) and team-mode.sh printed `tracked` |
| EN 13 | JA 13 | setup reports the base dir per mode: ignore line to append (none for a base path outside the safe character set), Already in place, Remains the operator's decision; tracked report unchanged | bin/team-setup.sh:797 bin/team-setup.sh:815 bin/team-setup.sh:819 bin/team-setup.sh:820 bin/team-setup.sh:823 bin/team-setup.sh:142 docs/adopting.md:104 docs/adopting.md:111 | P17 matrix, local rows: base not in HEAD and not ignored gave a Required item "Append the line /.shell-team/ ... exclude file"; not in HEAD and ignored gave "is ignored by git" under Already in place; committed in HEAD, ignored or not, gave "is tracked in git ... names no command for it" under Remains. P17 unsafe path (a base dir named with a plus sign): "its path cannot be quoted safely, so setup prints no line for it". The tracked rows are in EN 30 |
| EN 14 | JA 14 | team-init prints two record-mode lines in every mode, just before its closing Next line | bin/team-init.sh:404 bin/team-init.sh:406 | P3: team-init on a fresh scratch repo printed "Record mode: the operating files are committed by default (mode tracked) ..." and "To select local mode in this clone, run once: git config shell-team.mode local ..." |
| EN 15 | JA 15 | check-pii-shapes.sh --paths scans only the named files; --all and the default mode read nothing in an ignored untracked base dir | bin/check-pii-shapes.sh:232 agents/engineer.md:174 docs/adopting.md:116 | P4: ignored base dir with a fixture holding a home-path shape; --all exit 0 and 0 FINDING lines; --paths on that file exit 1 and one FINDING line with pattern home-path naming it |
| EN 16 | JA 16 | in local mode records are written and never committed; implementation and tests are still committed | docs/adopting.md:118 skills/run/SKILL.md:91 skills/run/SKILL.md:93 | static; the code-commit half observed in P5: team-commit.sh on app.txt exit 0 in a local clone |
| EN 17 | JA 17 | team-commit.sh refuses named base-dir paths in local mode; check-durability.sh prints skipped | bin/team-commit.sh:381 bin/team-commit.sh:389 bin/check-durability.sh:207 docs/adopting.md:115 docs/adopting.md:117 | P5: refused (local-mode) exit 2 for a record path; P10: check-durability.sh in a local clone printed "check-durability: skipped: shell-team.mode is local — no durability observation was made"; P17: the same skipped line with the base dir committed in HEAD, and a refusal (local-mode, rc 2) for an untracked new record under the base dir |
| EN 18 | JA 18 | worktree isolation and land-worktree.sh are unsupported in local mode; the script reads no mode and refuses nothing on it | skills/run/SKILL.md:89 skills/run/SKILL.md:328 docs/adopting.md:119 bin/land-worktree.sh:46 | P6: grep -c for team-mode or shell-team.mode on land-worktree.sh printed 0, and the same grep on team-commit.sh printed a positive count as the control; the script header lists its refusal classes (usage, structural, overlap, diverged, empty-landing, ref-moved, lock) and none concerns the mode |
| EN 19 | JA 19 | role prompts changed, so older generated .codex/agents TOML files drift until regenerated | bin/check-codex-agents.sh:140 bin/gen-codex-agents.sh:366 agents/engineer.md:174 | P7: TOML files generated from the tree before the sprint, checked against this tree, printed drift for all five roles |
| EN 20 | JA 20 | update shell-team and set up shell-team run the same flow; it does not change the mode and edits no ignore line for the base dir; on a Codex CLI host it appends .codex/agents to info/exclude under Done when that path is not already ignored, and otherwise reports Already in place | README.md:123 skills/setup/SKILL.md:16 bin/team-setup.sh:134 bin/team-setup.sh:437 bin/team-setup.sh:445 docs/adopting.md:98 | P2b: setup in a local clone (Claude Code host) left info/exclude and .git/config byte-identical (cmp) and the key still read local; P17 codex: with --host codex-cli, setup printed under Done "appended .codex/agents to <clone>/.git/info/exclude" and the exclude file then ended with the base line and .codex/agents |
| EN 24 | JA 24 | no key or any value other than exact local is tracked | bin/team-mode.sh:17 bin/team-mode.sh:90 docs/adopting.md:96 | P1 and P9: no key printed `tracked`; value Local (capital L) printed `tracked` |
| EN 26 | JA 26 | upgrade then update shell-team per repository; a second run changes nothing | README.md:123 docs/distribution.md:134 skills/setup/SKILL.md:16 | static |
| EN 28 | JA 28 | on a Codex CLI host the prompt regenerates a drifted .codex/agents; the manual generator and checker pair | docs/distribution.md:134 docs/distribution.md:137 docs/distribution.md:138 README.md:125 skills/setup/SKILL.md:78 | P7: regenerating with this tree's generator then checking printed "in sync" |
| EN 30 | JA 30 | in tracked mode a committed base dir with no ignored files needs nothing else and the gates keep checking; an uncommitted, ignored or ignored-files-holding base dir still gets Required | docs/adopting.md:90 docs/adopting.md:104 docs/adopting.md:105 bin/check-durability.sh:207 | P17 matrix, tracked rows: absent and not ignored gave Required "is not committed yet"; absent and ignored gave Required "ignored by .git/info/exclude:7 and its anchor is not in HEAD"; committed and not ignored gave Already in place "not ignored by git, and the anchor of each ... is committed in HEAD"; committed with an exclude line gave Required "holds ignored files". P9: check-durability.sh ran the check in tracked mode and printed not-durable for an uncommitted record |
| EN 36 | JA 36 | step 1: git config shell-team.mode local; stored in the clone's own config; a global value never selects local | bin/team-mode.sh:19 bin/team-mode.sh:48 docs/adopting.md:96 | P16: a global config file holding the key, with the clone having none, printed `tracked`; after the declaration the local scope read `local` |
| EN 37 | JA 37 | step 2: ignore line in info/exclude (path from rev-parse --git-path); default line /.shell-team/; root .gitignore is shared and needs the declaration in every clone; the blocking-rule report holds while the base dir is not committed | docs/adopting.md:98 bin/team-setup.sh:823 bin/team-setup.sh:52 | P11: the append from a subdirectory wrote /.shell-team/ to the clone exclude file (path printed relative to cwd) and the directory became ignored; P12 and P17 (tracked, absent): a tracked clone with an ignore line and the base dir not in HEAD printed a Required base-directory-in-git item naming that rule; with the base dir committed the report differs (EN 30), so the sentence is conditioned |
| EN 38 | JA 38 | step 3: update shell-team reports per mode; base dir not in HEAD is Already in place when ignored, else a Required line (none for an unsafe path); committed is the next section | bin/team-setup.sh:797 bin/team-setup.sh:815 bin/team-setup.sh:819 bin/team-setup.sh:820 bin/team-setup.sh:823 | P17: see EN 13 (both base-dir states times ignored and not ignored under local; unsafe path printed no line) |
| EN 39 | JA 39 | step 4: records written not committed, code committed, no worktree isolation, default path unaffected | skills/run/SKILL.md:89 skills/run/SKILL.md:91 docs/adopting.md:118 docs/adopting.md:119 | static |
| EN 40 | JA 40 | step 5: base dir not in HEAD means the records exist only in this working copy and a fresh clone starts without them in tracked mode; committed means a fresh clone contains the committed records | docs/adopting.md:120 bin/team-mode.sh:17 bin/team-setup.sh:797 | P8: the clone of a clone whose base dir was never committed had no .shell-team directory, git status empty, key unset and team-mode.sh printed `tracked`; the committed half follows from the committed blobs being in the repository history (P17 committed rows hold them in HEAD) |
| EN 44 | JA 44 | ignore rules do not apply to tracked files: with a committed base dir an info/exclude line leaves tracked records visible and hides only new untracked ones | docs/adopting.md:109 bin/team-setup.sh:797 | P17 status cells, base committed: with the exclude line, git status showed only the modified todo.md (new.md hidden); without the line it showed the modified todo.md and `?? .shell-team/new.md` |
| EN 46 | JA 46 | committed base dir under local is a Remains item that prints no info/exclude line and no command | bin/team-setup.sh:797 docs/adopting.md:109 | P2: item text "is tracked in git (.shell-team/todo.md is committed in HEAD), and ignore rules do not apply to tracked files; whether to keep tracking it is the operator's decision, and setup names no command for it" |
| EN 48 | JA 48 | kept tracking: edited tracked records show modified, new records untracked unless excluded; team-commit.sh refuses base-dir paths (local-mode, exit 2, nothing staged) tracked or not | bin/team-commit.sh:381 bin/team-commit.sh:389 docs/adopting.md:117 | P5 and P17: git status showed the modified record (and the new one as untracked when not excluded); team-commit.sh printed "refused (local-mode)" exit 2 for both the tracked todo.md and the untracked new.md, with or without the exclude line, and status and log were unchanged |
| EN 50 | JA 50 | once the directory is no longer tracked and HEAD lacks it, an info/exclude line hides it and setup lists it as Already in place; history keeps earlier commits | bin/team-setup.sh:775 bin/team-setup.sh:797 bin/team-setup.sh:815 docs/adopting.md:109 | P17 untracked-equivalent: a scratch history rebuilt with a tree-only commit and the index re-read from HEAD (no removal command), exclude line present: git status empty and setup printed "is ignored by git" under Already in place; with the line absent it printed `?? .shell-team/` and a Required append item; with the index still holding the files (HEAD rebuilt, index not) setup reported not ignored, which is why the guide says "no longer tracked". The commit step itself is the operator's and static |
| EN 54 | JA 54 | members declare local and keep the ignore line per clone; neither is pushed | docs/adopting.md:96 docs/adopting.md:98 bin/team-mode.sh:19 | P8: a clone of the declaring clone had no key and an exclude file without the line |
| EN 56 | JA 56 | an uncommitted base dir is absent from the shared repository; a fresh clone is tracked with nothing to ignore | docs/adopting.md:98 docs/adopting.md:120 | P8: same clone; no .shell-team, git status empty, team-mode.sh printed `tracked` |
| EN 58 | JA 58 | a root .gitignore line is shared; a clone with it and no declaration is tracked with an ignored base dir that setup reports as blocking while the base dir is not committed | docs/adopting.md:98 bin/team-setup.sh:820 | P12: printed "base directory in git: .shell-team/ is ignored by .gitignore:1 and its anchor is not in HEAD ..." under Required; P17 tracked rows: with the base dir committed the report is not that item (EN 30) |
| EN 68 | JA 68 | any value other than exact local reads as tracked | bin/team-mode.sh:90 bin/team-mode.sh:19 docs/adopting.md:96 | P9: value tracked and value Local both printed `tracked` |
| EN 70 | JA 70 | in tracked mode a base dir that is ignored and not yet committed is a blocking rule under Required with the ignore source and line, git add and a re-include line; a base path with a character outside A-Za-z0-9._/- gets a Required item that says the path cannot be quoted safely and no git add command and no re-include line | docs/adopting.md:105 bin/team-setup.sh:134 bin/team-setup.sh:1002 bin/team-setup.sh:1027 | P9 and P17 (tracked, absent, ignored): setup printed under Required "ignored by .git/info/exclude:7 and its anchor is not in HEAD ... Add !.shell-team/ ... Run git add -- ..." and committed nothing; the committed and ignored cell printed a different Required item ("holds ignored files"), so the sentence is conditioned |
| EN 72 | JA 72 | records written in local stay in the working copy; in tracked mode check-durability.sh runs at once and reports an uncommitted or changed record not-durable | docs/adopting.md:118 bin/check-durability.sh:207 bin/check-durability.sh:120 | P9 and P17: tracked clone with the base dir not in HEAD printed "not-durable: not-in-recorded-commit"; tracked clone with the base dir committed and todo.md edited printed "not-durable: uncommitted-change" |
| EN 76 | JA 76 | team-mode.sh prints local or tracked and exits 2 (loop BLOCKED) when git cannot read the config | bin/team-mode.sh:80 bin/team-mode.sh:83 skills/run/SKILL.md:28 | P13: team-mode.sh outside any repository exited 2 with "cannot read the repository configuration ... not reading it as tracked" |
| EN 83 | JA 83 | git status shows nothing for ignored untracked records, a modified mark for an edited tracked record, and untracked for a new record unless excluded | docs/adopting.md:90 docs/adopting.md:109 | P17 status cells: base not in HEAD and ignored gave empty status; base not in HEAD and not ignored gave `?? .shell-team/`; base committed gave ` M .shell-team/todo.md` plus `?? .shell-team/new.md` without the exclude line and only the modified entry with it |
| EN 85 | JA 85 | check-durability.sh prints the skipped line and exits 0 in local mode (with its required arguments) | bin/check-durability.sh:207 bin/check-durability.sh:208 docs/adopting.md:115 | P10: --phase close-out --task T-9999 --ref HEAD printed the skipped line; without the arguments it printed a usage error and exit 2 (arguments are read first) |
| EN 87 | JA 87 | in local mode Already in place for the base dir means git ignores it (and it is not in HEAD); a second run changes nothing | bin/team-setup.sh:815 README.md:123 | P17 local rows: the ignored, not-in-HEAD cell printed the Already in place item; the committed cells printed Remains instead; second-run claim is the README text |
| EN 89 | JA 89 | check-codex-agents.sh reports in sync after regeneration, unless an extra shell-team-*.toml the generator does not own is present, which it names and which stops the in sync report | bin/check-codex-agents.sh:226 bin/check-codex-agents.sh:236 docs/distribution.md:138 | P7: printed "check-codex-agents: .codex/agents in sync with <plugin root>/agents" |

Probe recipe. Common setup for every probe: `export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`; unset `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT`, `CODEX_THREAD_ID` and `TEAM_RUN_BASE`; a scratch root made with `mktemp -d "$TMPDIR/t1185-probe.XXXXXX"`; a scratch clone is `git init -q -b main`, a user name and email set, one committed file `app.txt`. `R` is this checkout, and every script is run as `bash "$R/bin/<script>"` from the scratch clone.

- P1: no key set; `bash "$R/bin/team-mode.sh"`.
- P2: clones C (local, base not ignored), D (local, `/.shell-team/` in `.git/info/exclude`), E (base dir committed with `git add`, then local plus the exclude line); in each `bash "$R/bin/team-setup.sh"` and read the lines containing `base director`. In E also append a line to the committed `.shell-team/todo.md` and run `git status --short`. P2b: in a fresh local clone, copy `.git/info/exclude` and `.git/config`, run setup, `cmp` both.
- P3: `bash "$R/bin/team-init.sh" <scratch clone>`; read `tail -3` of its output (the two record-mode lines, then the `Next:` line).
- P4: in D, write a file `.shell-team/todo-probe.md` holding a home-path-shaped string assembled from two `printf` fragments; run `PII_CHECK_TRACKER_KEY=1 bash "$R/bin/check-pii-shapes.sh" --all` and then `--paths .shell-team/todo-probe.md`, counting `FINDING` lines.
- P5: in E, `bash "$R/bin/team-commit.sh" --message-file <file outside the clone> -- .shell-team/todo.md` (refused, exit 2), then the same for the edited `app.txt` (committed, exit 0); compare `git status --short` and `git log --oneline` before and after.
- P6: `grep -c -E "team-mode|shell-team[.]mode" "$R/bin/land-worktree.sh"` (0) and the same on `"$R/bin/team-commit.sh"` (positive control).
- P7: `git archive` of the tree before the first sprint commit (`agents bin templates`) into a scratch dir; generate TOML with that tree's `gen-codex-agents.sh --root <it> --out-dir .codex/agents` in a scratch repo; `bash "$R/bin/check-codex-agents.sh"` there (five drift lines); regenerate with `bash "$R/bin/gen-codex-agents.sh" --out-dir .codex/agents` and check again (in sync).
- P8: `git clone` of the declaring clone; `ls -a`, `git status --short`, `git config shell-team.mode` (exit 1) and team-mode.sh in the new clone.
- P9: in D set the key to `tracked`, then to `Local`; team-mode.sh; setup; and `bash "$R/bin/check-durability.sh" --phase close-out --task T-9999 --ref HEAD`.
- P10: the same check-durability.sh invocation with the key at `local`.
- P11: in a subdirectory of a local clone run `printf '%s\n' '/.shell-team/' >> "$(git rev-parse --git-path info/exclude)"`, print the path, run setup and `git status --short`.
- P12: a clone in `tracked` mode with `/.shell-team/` written into its root `.gitignore`; setup.
- P13: team-mode.sh from a directory that is not a git repository.
- P17 (class audit after review round 1): for each cell of {`local`, `tracked`} x {base dir not in HEAD, base dir committed in HEAD} x {`/.shell-team/` in `.git/info/exclude`, not}, a fresh scratch clone, `team-init.sh` run on it (committed with `git add` for the committed cells), the exclude line appended for the ignored cells, then setup (read with its section headings), `git status --short` after appending a line to `.shell-team/todo.md` and creating `.shell-team/new.md`; plus `team-commit.sh -- .shell-team/new.md` in the local committed cells, `check-durability.sh --phase close-out --task T-9999 --ref HEAD` in the local committed cell and in the two tracked cells that hold an edited todo.md and no committed base, the untracked-equivalent rebuild (the base committed, then HEAD set with `git commit-tree` to a tree-only commit built from the parent tree and the index re-read from HEAD, so no removal command runs), a Codex-host setup with `--host codex-cli`, and an unsafe base path given as `TEAM_RUN_BASE` with a plus sign.
- P16: `GIT_CONFIG_GLOBAL=<file holding the key set to local> bash "$R/bin/team-mode.sh"` in a clone with no key, then `git config shell-team.mode local` and `git config --local --get shell-team.mode`.

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Two files, committed, fixed heading order, EN/JA identical fenced lines (D1; N3) | **AC1** |
| 2 | Section contents, the ordered move-to-`local` steps and the going-back command (D1; N1) | **AC2** |
| 3 | Committed-base-dir section names no command (D1; N2) | **AC2**, **AC5** |
| 4 | No removal command anywhere, `--unset` included (D1, Non-goals) | **AC5** |
| 5 | Four-row table linked, not restated (D1, Non-goals) | **AC6** |
| 6 | Adopting-guide link as a pure addition inside the Upgrading paragraph; trial recipe unchanged (D2) | **AC3** |
| 7 | README link as a pure addition inside the update section (D2) | **AC4** |
| 8 | `check-readme-version.sh` green (D2) | **AC8** |
| 9 | Claim inventory with anchors that exist (D3) | **AC7** |
| 10 | Untouched executing surfaces, release files, CONTRIBUTING and distribution docs (D4, Non-goals) | **AC10** |
| 11 | #721 items stay on #721 (Non-goals) | **AC10** (skills), **AC11** |
| 12 | No worktree fix, no change to setup's report (Non-goals) | **AC10** |
| 13 | Diff confined to the six documents and this task's records (D4) | **AC11** |
| 14 | Declarations conform | **AC8** |
| 15 | The suites that read the edited files stay green | **AC9** |
| 16 | CI green | **AC12** |
| 17 | Pre-commitment and drop order | info-only (not promoted to AC): a disposition, not a deliverable property |
| 18 | No sweep, no whole CI re-run, no behaviour verification of untouched mechanisms, no local run of past specs' check lines | info-only (not promoted to AC): exclusions of process that leave no observable trace beyond **AC10**/**AC11** |

## Shipped-docs inventory

| Document | Relation to this task | Disposition |
|---|---|---|
| `docs/migrating-to-local-mode.md`, `.ja.md` | new | this task (**AC1**, **AC2**, **AC5**–**AC7**) |
| `docs/adopting.md`, `.ja.md` | one link line in the Upgrading paragraph | this task (**AC3**) |
| `README.md`, `README.ja.md` | one link line in the update section | this task (**AC4**); README's committed-base qualifier stays on issue #721 |
| `docs/pii-controls.md`, `.ja.md` | describe the shape scan's `--paths` use; summary qualifier gap | unchanged; not a #721 item (the `rc=n/a` sentence shipped with T-1184, #716 item 4) |
| `skills/setup/SKILL.md`, `skills/team-init/SKILL.md` | relay setup's and init's report; `.gitignore` staging clause and no-line outcome | issue #721 |
| `docs/distribution.md`, `.ja.md` | `## Update` names no record mode | unchanged (**AC10**); the guide may link to it |

## Blast radius

- **Method and disclosed deviation (no-mechanism class).** The checklist's no-mechanism item asks for a read-set-scoped inventory: run each merged criterion that reads an edited path at the base and at HEAD. The operator's 2026-10-01 ruling forbids running past specs' check lines locally. CI and this task's own check lines decide the impact instead, as in T-1183 and T-1184.
- **Known readers of the edited paths.** The read set below was found by reading T-1184's spec, and is a lower bound. A criterion that reaches `docs/adopting*.md` or `README*` through indirection stays unmeasured, and that is disclosed.
  - T-1184's **AC1** and **AC2** compare `README*` and `docs/adopting*.md` against `8030996c` as line sets. They stay green: the added link lines carry no removal token, and the table count in the `local` subsection is unchanged.
  - T-1184's **AC11** scope lock goes stale by design.
  - `tests/trial-recipe` is held green by **AC3** and **AC9**.
- **New files.** No CI step or `bin/` checker globs `docs/*.md`, so the two new files enter only the diff-scoped PII scan (**AC12**).
- **Adopter-side artifacts.** None generated. The guide tells Codex CLI adopters to regenerate `.codex/agents`, which T-1181 and T-1184 already made stale.
- **Sprint retro.** If the sprint's retro or its lesson promotions land on this branch after the gates, **AC10** and **AC11** go stale by design and are not chased.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| D1–D3 migration guide and links | not met (documents the opt-in capability shipped by T-1180–T-1184; makes nothing new possible) | met (README and adopting guide are read by every adopter) | PATCH | documentation |

The task's derived tier is PATCH. The sprint-level premise on record is MINOR for sprint `local-mode`. The opt-in judgment point was disclosed at planning, and the final naming is made at the batch GO.

## Assumptions

- **Relayed (owner: the coordinating session).**
  - The tech-lead's Routing Map, including its design and its measurement that no CI step or checker globs `docs/*.md`. This role re-read the measurement against `.github/workflows/check-handoff.yml` and `tests/` (see Summarized sources).
  - Issue #721's scope, confirmed by the coordinating session from its body. It covers three items only: the README committed-base qualifier (README.md lines 77 and 99, EN and JA); the no-line outcome missing from the README line 51, setup-skill line 16 and team-init-skill line 67 summaries; and the setup skill's `.gitignore` staging clause. It does not name `docs/pii-controls*.md`. Their `rc=n/a` sentence shipped with T-1184 (#716 item 4), and the guide changes nothing they describe, so they carry no `- shipped-docs:` line here.
- **Measured by this role** (Read and Grep tools on the tree at `dc4136d9`, tree clean). Every line anchor in `## Summarized sources`, and:
  - `migrating-to-local-mode` and `T-1185` occur nowhere in the repository.
  - `bin/land-worktree.sh` has no mode read.
  - `docs/distribution*.md` do not name the record mode.
  - None of the three AC9 suites matches the recursive-deletion pattern (Grep tool, a proxy for the runtime grep).
- **Own-coinage count premise.** `migrating-to-local-mode` occurs 0 times in `docs/adopting.md`, `docs/adopting.ja.md`, `README.md` and `README.ja.md` at `B`.
- **Borrowed anchors the checks rely on.** The coordinating session measures each one at `B` during the freeze and records the value beside it:
  - `git show "$B:docs/adopting.md" | grep -c '^\*\*Upgrading an existing adopter repository\.\*\*'` (expected 1), and `git show "$B:docs/adopting.ja.md" | grep -c '^\*\*既存の adopter リポジトリをアップグレードする場合。\*\*'` (expected 1).
  - `git show "$B:README.md" | grep -cxF '## Update'` (1) and `git show "$B:README.ja.md" | grep -cxF '## 更新'` (1).
  - `git show "$B:docs/adopting.md" | grep -cxF '### Keeping the records out of git: local record mode'` (1); the JA heading `### 記録を git に載せない: local record mode` (1).
  - The **AC6** row pattern matches 4 lines in each of `docs/adopting.md` and `docs/adopting.ja.md` at `B`.
  - `tests/trial-recipe/extract-recipe.sh` exits 0 on each base blob in all four modes.
  - `bash bin/check-readme-version.sh README.md README.ja.md` exits 0 at `B`.
  - `git cat-file -e "$B:docs/migrating-to-local-mode.md"` fails, as does the JA path (neither file exists at `B`).
  - Each of the 11 **AC10** paths exists at `B`.
  - The recursive-deletion pattern matches none of the three **AC9** suites and none of the three **AC8** checkers.
  - The script lines the guide will quote: `bin/team-mode.sh` lines 48 and 87–91; `bin/check-durability.sh` line 207; `bin/team-setup.sh` lines 797, 815 and 823; `bin/team-commit.sh` lines 381–389.
- **Measured by the coordinating session at freeze (2026-10-11, `B` = `dc4136d9`, the merge-base of `feature/711-local-mode-docs` and HEAD):** the Upgrading paragraph lead 1 in `docs/adopting.md` and 1 in `docs/adopting.ja.md`; `## Update` 1 in `README.md`, `## 更新` 1 in `README.ja.md`; the local-record-mode subsection heading 1 in each adopting doc; the AC6 row pattern 4 lines in each; `tests/trial-recipe/extract-recipe.sh` exits 0 on the base `docs/adopting.md` blob in all four modes; `check-readme-version.sh README.md README.ja.md` exit 0; neither guide exists at `B`; `migrating-to-local-mode` occurs in 0 of the four link targets; the recursive-deletion pattern matches none of the three AC9 suites nor the three AC8 checkers; the script lines the guide will quote read as expected (`bin/team-mode.sh:48`, `:87-91`; `bin/check-durability.sh:207`; `bin/team-setup.sh:797`, `:815`, `:823`; `bin/team-commit.sh:381-389`); the shape scan on this spec reports 0 findings.
- **Pre-implementation expectation (for the freeze read).** **AC1**–**AC7** and **AC11** are red only because the guide and the links do not exist yet (AC11's positive control). **AC8**, **AC9** and **AC10** are green. **AC12** is a runtime criterion.
- **Local verification limit.** The CI run (**AC12**) is the evidence for bash 5 and the pinned tools.

## Open questions

- None blocking.

## Notes for engineer

- **Files.** The two guides, one link line in each of `docs/adopting.md`, `docs/adopting.ja.md`, `README.md` and `README.ja.md`, the `## Claim inventory` rows in this spec, provenance, and `.shell-team/test-recipe.md` as usual.
- **Two facts to settle with a script line, not prose.** Record each in the claim inventory with its probe.
  - **Worktree.** Is the `local`-mode worktree limitation enforced by a script, or only stated? This role read `bin/land-worktree.sh` and found no mode read. The limitation is stated in `skills/run/SKILL.md` lines 89 and 328 and in `docs/adopting.md` line 118. Unless a probe shows otherwise, the guide says "unsupported", never "refused".
  - **Committed base dir in `local` mode.** Probe it in a scratch repository: does `git status` show the modified record files, and does `bin/team-commit.sh` refuse them? Its lines 381–393 refuse any named path under the base dir before staging, whether or not the path is tracked. Write what the probe shows, and name no command for the operator's keep or stop decision.
- **Line shape.** Write one paragraph or bullet per line (no hard wrap), as the adopting guide's `local` subsection does, so that each claim line carries few claims and the inventory stays small.
- **Moving-section order (AC2).** In "Moving a clone to local mode", start the numbered list at `1. `. Before the first item of that list, do not mention `info/exclude` or `update shell-team`; the order check reads from that line on.
- **Fenced lines (AC1).** Keep comments out of fenced blocks, or keep them identical in both languages; any explanation goes in prose.
- **No removal words in commands (AC5).** The stop-tracking consequence is prose. Do not use `--unset` for going back; `git config shell-team.mode tracked` is the step.
- **Trial section (AC3).** Add the link line inside the Upgrading paragraph only, so the extractor's section, fences, spans and line floors are untouched.
- **CI-equivalence (no-mechanism item ii).** The reached steps are the ones that read edited paths: `tests/trial-recipe/run.sh` (workflow line 93), `tests/check-adopter-docs/run.sh` (line 50), `tests/check-readme-version/run.sh` (line 135), `bin/check-readme-version.sh README.md README.ja.md` (line 138), and the diff-scoped PII scan (line 275), which reads every changed file. Derive this with `git grep -n -E 'docs/adopting|README(\.ja)?\.md' -- .github/workflows tests` and paste the output into provenance. Name every other step as not reached because it reads none of the six paths; one line per step group, citing the derivation output, is enough.
- **Mutation probes (no-mechanism item iii).** Before hand-off, break each new check line's subject once in a scratch copy, confirm the criterion goes red, then restore. Suggested breaks:
  - swap two headings in the JA guide (**AC1**);
  - move `info/exclude` above `git config shell-team.mode local` in the step list (**AC2**);
  - add the link line one line after the paragraph's blank line (**AC3**);
  - add an `--unset` line (**AC5**);
  - paste one table row (**AC6**);
  - delete one inventory row (**AC7**).
- **Shape scan.** Run the PII-shape checker over the two new guides and this task's records before the first commit.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** The guides are shipped adopter text and are reviewed for accuracy against the scripts. The inline check lines get dev-scaffold depth (operator ruling).
