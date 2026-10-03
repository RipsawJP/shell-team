# On the Codex CLI host, the run may ask for per-command approval of a role's own commit, and never requests a grant that widens the session's sandbox, trust or writable roots

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1168

**Branch**: `feature/662-codex-commit-approval`, cut from `develop` at `c68f32b5` (`.git/refs/heads/develop` and `.git/refs/heads/feature/662-codex-commit-approval` both read `c68f32b5898957ee4af4be7421d46a33ceef0a08`, measured by file read). Not stacked. The pull request targets `develop`.

## Problem

The run skill's Codex CLI dispatch paragraph says that whether the session's sandbox may write to `.git` "is the operator's decision to make before the session starts, and the run neither asks for nor adds that grant". In a Codex CLI clean-install run (v2.8.1), that sentence was read as forbidding even a per-command approval request for the engineer's own commit, so the loop stopped `BLOCKED` before `READY_FOR_QA` when the sandbox refused the commit. The rule the sentence was written to state is narrower: the run never widens the session's boundary; it is not barred from asking the operator to approve one concrete command. The canon is issue #662; its Expected section was relayed verbatim by the coordinating session (this role cannot read the tracker) and is quoted here:

> The shipped text distinguishes:
> - Not requested by the run: any grant that widens the session's sandbox, trust, or writable roots (e.g. `.git` as a writable root, a different sandbox mode). The operator decides that before the session starts — unchanged.
> - Allowed: asking the operator to approve a role's own commit as one concrete command at a time, through the host's ordinary per-command approval prompt. The approval covers only the command shown; no boundary is widened.
> Other shipped surfaces stating the same rule (`docs/adopting.md` "Using shell-team from Codex CLI", run skill Step 0 setup-check wording, `skills/setup/SKILL.md`, agents, prompt blocks) are checked for the same ambiguity and kept consistent.

## Summarized sources

- GitHub issue #662, Expected. **Relayed verbatim by the coordinating session; this role did not read it.** Quoted above. Distinctions carried over:
  - Two classes, kept apart: **not requested** = any grant widening the session's sandbox, trust or writable roots (operator's decision before the session starts, **unchanged**); **allowed** = asking the operator to approve **a role's own commit**, **one concrete command at a time**, through **the host's ordinary per-command approval prompt**, covering **only the command shown**.
  - The other surfaces are **checked** for the same ambiguity and **kept consistent** — the issue does not require every one to be edited.
- `templates/prompt-blocks/host-dispatch.md` (read in full, 30 lines). Distinctions: `:5` is the one line beginning `On the **Codex CLI** host: dispatch a bound role`; it carries the ambiguous sentence ("… is the operator's decision to make before the session starts, and the run neither asks for nor adds that grant (measured: … exit 128) …") and the separate `.codex/` refusal sentence. `:15` already uses `BLOCKED` with "the exact error" for the review's `claude -p` line. No other line states the `.git` rule.
- `templates/prompt-blocks/registry.txt` `:57`: `contain host-dispatch.md  skills/run/SKILL.md` — the block is embedded by containment, so `bin/check-prompt-sync.sh` compares, never generates; both copies are edited by hand.
- `skills/run/SKILL.md`. Distinctions: `:182` is the contain-mode copy of `host-dispatch.md` `:5`, byte-identical today (read side by side). `:22` (**Step 0 setup check (T-1164)**) ends "never change the host's configuration, and never ask for a grant or add an approval rule" — at that point no role is dispatched, so nothing commits, but the bare "never ask for a grant" carries the same ambiguity.
- `skills/setup/SKILL.md`. Distinctions: Step 3 (`:37`–`:45`) already allows, for a refused write, "request the host's own per-command approval for exactly that command and run it (each confirmation you ask for names **one concrete command**)" or stopping and telling the operator the command, and "Never ask for anything wider". The Boundary list (`:80`–`:89`) — "Never ask for a trust, sandbox, writable-root, network or permission grant, and never for an approval or permission-mode bypass" and "never add a persistent approval or allow rule" — names widening grants, bypasses and persistent rules, not a per-command approval, and sits in the same file as Step 3's allowance. This is the pattern decision 1 mirrors.
- `docs/adopting.md` `## Using shell-team from Codex CLI` (read `:415`–`:734`). Distinctions: `:427`–`:430` (setup never adds an approval rule; a refused setup write is approved per command or run by the operator); `:455`–`:456` list item **Write access to the git directory, for commits** (step 6) states only the default refusal; step 6 (`:571`–`:593`) names the `.git` policy as the operator's decision, states setup's per-command reliance for its own printed command, and says "only a role's own commit needs `.git` write access" — **but says nothing about how a role's own commit proceeds when refused**: that is the gap; `:718`–`:720` ("Nor is `--sandbox workspace-write`'s own refusal of `.git/` writes something this plugin can suppress — it is Codex CLI's own policy, and the operator's to change (step 6)") is about the policy, not a per-command request, and points at step 6.
- `docs/adopting.ja.md` `## Codex CLI から shell-team を使う`. Distinctions: the parallel passages are `:431`–`:435`, the list item `:458`–`:459` (**commit のための git ディレクトリへの書き込み**), step 6 `:573`–`:596` (same gap), and `:715`–`:720`.
- `.shell-team/specs/T-1164-run-prereq-check.md` **AC8** (`:141`) and **AC9** (`:144`). Distinctions: **AC8** forbids fifteen tokens on the `**Step 0 setup check (T-1164)` line (`trust_level`, `writable_roots`, `network_access`, `sandbox_workspace_write`, `danger-full-access`, `excludedCommands`, `dangerously`, `bypassPermissions`, `--full-auto`, `--yolo`, `approval_policy`, `permissions.allow`, `config.toml`, `settings.json`, `settings.local.json`); **AC9** requires that line to occur exactly once and to name eleven tokens. The underscored `writable_roots` is forbidden; the spaced phrase "writable roots" is not.
- `agents/*.md` (grep for `grant`, `writable`, `per-command`, `Operation not permitted`). Distinction: no agent definition states the `.git` sandbox rule; the hits are the class-M "standing grant", `code-reviewer`'s tool grant and its own Codex sandbox diagnostics. `agents/code-reviewer.md` `:104` cites `templates/prompt-blocks/host-dispatch.md:20` by line number.
- `.shell-team/lessons.md`, 2026-10-01 — *A refused command is reported as BLOCKED with the refusal verbatim, never retried in another form or dropped as optional* (through the playbook line in `agents/pm-spec.md`; the same line ships in `agents/engineer.md` `:150`). Distinction: the fallback in decision 1 restates this for the commit case; it is not a new rule.
- `bin/check-adopter-docs.sh` (header and token regexes read). Distinction: a `this-task` `- shipped-docs:` path must appear literally in some `- check:` or `- adopter-surface:` line.
- `CONTRIBUTING.md` `## What a version number encodes` (cited through T-1167's spec, not re-read). Distinction: bug fixes are PATCH.

## Goal

<!-- BEGIN intent-block: T-1168 -->

- user-visible: yes — on the Codex CLI host, a run whose role's commit is refused by the sandbox may now ask the operator to approve that one commit command and continue to `READY_FOR_QA`, instead of stopping `BLOCKED` because the shipped wording was read as forbidding the request; the run skill and both adopting guides state the distinction.
- verification-class: mechanism — the diff edits `templates/prompt-blocks/host-dispatch.md`, a path under `templates/` that `bin/check-prompt-sync.sh` compares, and the run skill text that governs what the orchestrator does on the Codex CLI host.
- verification-ceiling: unit-and-static — **AC1**–**AC11** and **AC13** are settled in a plain checkout: they read shipped files, compare against the base ref's committed blob, or take a checker's or suite's exit code. **AC12**, the behaviour on a real Codex CLI session, sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor: it is cut from `develop` at `c68f32b5`, and every base-side read (**AC7**, **AC8**) resolves `git merge-base develop HEAD` (or `refs/remotes/origin/develop` where only that ref resolves), selected by an explicit `git show-ref --verify --quiet` existence test.
- shipped-docs: templates/prompt-blocks/host-dispatch.md — this-task
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task

**Goal (one sentence).** The shipped text states three things for the Codex CLI host, consistently across the dispatch block, the run skill and both adopting guides: (a) the run never requests a grant that widens the session's sandbox, trust or writable roots — that stays the operator's decision before the session starts; (b) when the sandbox refuses a role's own commit, the run may ask the operator to approve that commit as one concrete command at a time through the host's ordinary per-command approval prompt, the approval covering only the command shown and widening no boundary; (c) where the host offers no such prompt or the operator declines, the role stops `BLOCKED`, reporting the exact refusal and the one command for the operator to run, and never retries in another form.

**Decisions frozen here** (each is promoted to a criterion):

1. **The dispatch sentence.** In `templates/prompt-blocks/host-dispatch.md` `:5` and its contain-mode copy `skills/run/SKILL.md` `:182`, "the run neither asks for nor adds that grant" is replaced by wording that states (a), (b) and (c). The two lines stay byte-identical. The wording describes the run's own discipline and names no Codex approval-policy value or setting. (**AC1**, **AC2**, **AC3**, **AC9**)
2. **The block keeps its line count and line position.** `host-dispatch.md` keeps its line count, and the Codex CLI dispatch line keeps its line number, so a line-number citation into the block (`agents/code-reviewer.md` `:104`) moves no further. (**AC7**)
3. **Step 0 setup check (droppable, first).** `skills/run/SKILL.md` `:22`'s "never ask for a grant or add an approval rule" is narrowed to a grant that widens the session's sandbox, trust or writable roots, keeping T-1164's **AC8** forbidden tokens absent and its **AC9** required tokens present on that line. (**AC4**)
4. **Step 6 of both adopting guides.** `docs/adopting.md` step 6 and `docs/adopting.ja.md` 手順 6 each state (b) and (c) for a role's own commit. (**AC5**, **AC6**)
5. **The operator's-decision list item (droppable, second).** The **Write access to the git directory, for commits** item in `docs/adopting.md` and its Japanese counterpart each say that, without that grant, a role's own commit can still be approved per command (step 6). (**AC13**)
6. **Unchanged surfaces.** `skills/setup/SKILL.md` is unchanged: its Boundary list names widening grants, bypasses and persistent rules, and Step 3 in the same file already states the per-command allowance this task mirrors. No agent definition, `bin/` script, test or CI workflow changes. (**AC8**)
7. **Pre-commitment** (AI self-discipline, recorded before the first round). Never-dropped: decisions 1, 2, 4 and 6. If any round finds that the never-dropped wording cannot state (b) without naming a Codex approval-policy value or a setting, or that (b) widens a boundary, the task stops and returns to planning — no patch round is added. Droppable, in this order: (1) decision 3, then (2) decision 5. Trigger: the same droppable component draws a QA `FAIL` or review `REQUEST_CHANGES` finding in two consecutive rounds. Disposition: that component's edit is reverted, its criterion is reported as dropped (goal N of M), and a follow-up issue carrying that round's findings is filed.

## Non-goals

- **No change to any host setting, and no suggestion of one.** The run still never requests, chooses or writes a sandbox mode, a writable root, a trust level, a network setting, an approval-policy value or a persistent approval rule. (**AC3**, **AC4**, **AC8**)
- **No change to `skills/setup/SKILL.md`, `agents/*.md`, `bin/`, `tests/` or `.github/`.** (**AC8**)
- **No change to what the operator's own pre-session grant does.** An operator who has already made `.git` writable before the session sees no prompt; this task adds nothing for that case. (info-only)
- **Push and merge stay human gates.** The per-command allowance covers a role's own commit only, never a push. (**AC1**, review-judged)
- **The Claude Code host is unchanged.** (**AC8**, review-judged)
- **The stale line citation** `agents/code-reviewer.md` `:104` → `host-dispatch.md:20` is not repaired here; decision 2 only keeps it from moving further. (info-only)
- **Real-host behaviour** is the operator's re-measurement after release, not this task's verification. (**AC12**)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, writes only under `$TMPDIR` (temp directories are left in place, never removed), and contains no recursive delete. `P` below is the line-start anchor `On the **Codex CLI** host: dispatch a bound role`.

- [ ] **AC1** The dispatch sentence states (a), (b) and (c) in both copies (decision 1). `templates/prompt-blocks/host-dispatch.md` and `skills/run/SKILL.md` each carry exactly one line beginning with `P`; the two lines are byte-identical; and the line names each of: `before the session starts`, `sandbox, trust or writable roots`, `own commit`, `one concrete command at a time`, `per-command approval`, `only the command shown`, `BLOCKED`, `exact refusal`, `for the operator to run` and `another form`.

  Review-judged, against decision 1: the line says the run never requests a widening grant, that it may ask for approval of a role's own commit one command at a time through the host's ordinary per-command approval prompt with the approval covering only the shown command, and that a missing prompt or a declined approval stops the role `BLOCKED` without a retry in another form; it describes the run's own discipline, not Codex's approval semantics, and extends the allowance to no push.
  - check: rc=0; export LC_ALL=C; H=templates/prompt-blocks/host-dispatch.md; F=skills/run/SKILL.md; test -s "$H" || exit 1; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac1.XXXXXX") || exit 1; P='On the **Codex CLI** host: dispatch a bound role'; awk -v p="$P" 'index($0,p)==1' "$H" > "$T/h"; awk -v p="$P" 'index($0,p)==1' "$F" > "$T/f"; for f in "$T/h" "$T/f"; do test "$(grep -c . "$f" || true)" = 1 || rc=1; done; cmp -s "$T/h" "$T/f" || rc=1; for w in 'before the session starts' 'sandbox, trust or writable roots' 'own commit' 'one concrete command at a time' 'per-command approval' 'only the command shown' BLOCKED 'exact refusal' 'for the operator to run' 'another form'; do grep -qF -- "$w" "$T/h" || rc=1; done; test "$rc" -eq 0

- [ ] **AC2** The ambiguous phrase is gone from every shipped surface. `git grep -F 'neither asks for nor adds'` over `skills`, `templates`, `agents`, `docs`, `README.md` and `README.ja.md` exits `1` (a completed read with no match, never `2`). Positive control: the same `git grep` form finds `P` under `skills` and `templates`.
  - check: rc=0; export LC_ALL=C; git grep -q -F -- 'On the **Codex CLI** host: dispatch a bound role' -- skills templates || exit 1; git grep -n -F -- 'neither asks for nor adds' -- skills templates agents docs README.md README.ja.md > /dev/null; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC3** The dispatch sentence names no Codex approval-policy value and no widening setting (decision 1, Non-goals). The line beginning with `P` in `templates/prompt-blocks/host-dispatch.md` contains none of `approval_policy`, `on-request`, `on-failure`, `ask-for-approval`, `writable_roots`, `sandbox_workspace_write`, `danger-full-access`, `--full-auto`, `--yolo`, `bypassPermissions`, `dangerously` and `config.toml`; each read is asserted to complete (grep exit `1`). Positive control: the line names `.git`.
  - check: rc=0; export LC_ALL=C; H=templates/prompt-blocks/host-dispatch.md; test -s "$H" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac3.XXXXXX") || exit 1; awk 'index($0,"On the **Codex CLI** host: dispatch a bound role")==1' "$H" > "$T/h"; test "$(grep -c . "$T/h" || true)" = 1 || exit 1; grep -qF '.git' "$T/h" || exit 1; for t in approval_policy on-request on-failure ask-for-approval writable_roots sandbox_workspace_write danger-full-access --full-auto --yolo bypassPermissions dangerously config.toml; do grep -qF -- "$t" "$T/h"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC4** The Step 0 setup check names only widening grants, and T-1164's tokens hold (decision 3, droppable first). `skills/run/SKILL.md` carries exactly one line beginning `**Step 0 setup check (T-1164)`. It names `sandbox, trust or writable roots` and does not contain `never ask for a grant or add an approval rule`. It still names each of T-1164 **AC9**'s tokens (`bash "<plugin root>/bin/check-setup.sh"`, `once`, `BLOCKED`, `verbatim`, `set up shell-team`, `update shell-team`, `operator's decision`, `never substitute`, `another dispatch path or executor`, `the host's configuration`, `both hosts`) and none of T-1164 **AC8**'s fifteen forbidden tokens. Every absence read is asserted to complete (grep exit `1`).
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac4.XXXXXX") || exit 1; awk 'index($0,"**Step 0 setup check (T-1164)")==1' "$F" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1 || exit 1; grep -qF 'sandbox, trust or writable roots' "$T/l" || rc=1; grep -qF 'never ask for a grant or add an approval rule' "$T/l"; g=$?; test "$g" -eq 1 || rc=1; for w in 'bash "<plugin root>/bin/check-setup.sh"' once BLOCKED verbatim 'set up shell-team' 'update shell-team' "operator's decision" 'never substitute' 'another dispatch path or executor' "the host's configuration" 'both hosts'; do grep -qF -- "$w" "$T/l" || rc=1; done; for t in trust_level writable_roots network_access sandbox_workspace_write danger-full-access excludedCommands dangerously bypassPermissions --full-auto --yolo approval_policy permissions.allow config.toml settings.json settings.local.json; do grep -qF -- "$t" "$T/l"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC5** The English adopting guide states (b) and (c) for a role's own commit (decision 4). In `docs/adopting.md`, exactly one line begins `6. **The sandbox's write policy`, and the region from it up to the line beginning `7. **Confirm Claude Code CLI` names each of `own commit`, `one concrete command at a time`, `only the command shown`, `BLOCKED` and `another form`.
  - adopter-surface: `docs/adopting.md` `## Using shell-team from Codex CLI` (the operator's-decision list and step 6) and `docs/adopting.ja.md` `## Codex CLI から shell-team を使う` (the same list and 手順 6, **AC6**); plus `templates/prompt-blocks/host-dispatch.md` and `skills/run/SKILL.md`, which every Codex CLI host's orchestrator reads (**AC1**).
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; test -s "$E" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac5.XXXXXX") || exit 1; awk 'index($0,"6. **The sandbox'"'"'s write policy")==1' "$E" > "$T/h6"; test "$(grep -c . "$T/h6" || true)" = 1 || rc=1; awk 'index($0,"6. **The sandbox'"'"'s write policy")==1{f=1} index($0,"7. **Confirm Claude Code CLI")==1{f=0} f' "$E" > "$T/s6"; test -s "$T/s6" || rc=1; for w in 'own commit' 'one concrete command at a time' 'only the command shown' BLOCKED 'another form'; do grep -qF -- "$w" "$T/s6" || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** The Japanese adopting guide states (b) and (c) for a role's own commit (decision 4). In `docs/adopting.ja.md`, exactly one line begins ``6. **`.git` への``, and the region from it up to the line beginning `7. **この host に Claude Code CLI` names each of `1 つずつ`, `表示されたコマンドだけ`, `BLOCKED` and `別の形`.
  - check: rc=0; export LC_ALL=C; J=docs/adopting.ja.md; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac6.XXXXXX") || exit 1; awk 'index($0,"6. **`.git` への")==1' "$J" > "$T/h6"; test "$(grep -c . "$T/h6" || true)" = 1 || rc=1; awk 'index($0,"6. **`.git` への")==1{f=1} index($0,"7. **この host に Claude Code CLI")==1{f=0} f' "$J" > "$T/s6"; test -s "$T/s6" || rc=1; for w in '1 つずつ' '表示されたコマンドだけ' BLOCKED '別の形'; do grep -qF -- "$w" "$T/s6" || rc=1; done; test "$rc" -eq 0

- [ ] **AC13** The operator's-decision list items point at the per-command path (decision 5, droppable second). `docs/adopting.md` carries exactly one line beginning `- **Write access to the git directory, for commits**`, and that list item (the line and its indented continuation lines) names `per-command`. `docs/adopting.ja.md` carries exactly one line beginning `- **commit のための git ディレクトリへの書き込み**`, and that list item names `コマンド単位`.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac13.XXXXXX") || exit 1; li(){ awk -v p="$1" 'index($0,p)==1' "$2" > "$T/hl"; test "$(grep -c . "$T/hl" || true)" = 1 || return 1; awk -v p="$1" 'index($0,p)==1{f=1;print;next} f&&(index($0,"- **")==1||$0==""){f=0} f' "$2" > "$T/li"; grep -qF -- "$3" "$T/li"; }; li '- **Write access to the git directory, for commits**' "$E" 'per-command' || rc=1; li '- **commit のための git ディレクトリへの書き込み**' "$J" 'コマンド単位' || rc=1; test "$rc" -eq 0

- [ ] **AC7** The dispatch block keeps its line count and the dispatch line keeps its position (decision 2). Against the committed blob of `templates/prompt-blocks/host-dispatch.md` at the merge base with `develop` (the local branch, or `refs/remotes/origin/develop` where only that resolves, chosen by an explicit existence test), the working file has the same number of lines, and the line beginning with `P` sits at the same line number in both. This is merge-point-scoped and expected to go stale once a later task's edit to this file lands on `develop`.
  - check: rc=0; export LC_ALL=C; H=templates/prompt-blocks/host-dispatch.md; test -s "$H" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base "develop" HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base "refs/remotes/origin/develop" HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac7.XXXXXX") || exit 1; git show "$B:$H" > "$T/b" || exit 1; test -s "$T/b" || exit 1; nb=$(awk 'END{print NR}' "$T/b"); nh=$(awk 'END{print NR}' "$H"); test "$nb" = "$nh" || rc=1; lb=$(awk 'index($0,"On the **Codex CLI** host: dispatch a bound role")==1{print NR}' "$T/b"); lh=$(awk 'index($0,"On the **Codex CLI** host: dispatch a bound role")==1{print NR}' "$H"); test -n "$lb" || rc=1; test "$lb" = "$lh" || rc=1; test "$rc" -eq 0

- [ ] **AC8** Nothing outside the stated surfaces changes (decision 6, Non-goals). Measured from `B` = the merge base with `develop` (selected as in **AC7**), the union of the committed range `git diff --no-renames --name-only <B>...HEAD`, the staged delta, the unstaged delta and the untracked strays, each restricted to `bin`, `agents`, `tests`, `.github` and `skills/setup`, is empty. Positive controls: `B` is an ancestor of `HEAD`, and `git ls-files` over the same five paths is non-empty. This is merge-point-scoped and expected to go stale once a later task's edits to these paths land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base "develop" HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base "refs/remotes/origin/develop" HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; git merge-base --is-ancestor "$B" HEAD || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac8.XXXXXX") || exit 1; git ls-files -- bin agents tests .github skills/setup > "$T/t" || exit 1; test -s "$T/t" || exit 1; git diff --no-renames --name-only "$B"...HEAD -- bin agents tests .github skills/setup > "$T/a" || rc=1; git diff --no-renames --cached --name-only -- bin agents tests .github skills/setup >> "$T/a" || rc=1; git diff --no-renames --name-only -- bin agents tests .github skills/setup >> "$T/a" || rc=1; git ls-files --others --exclude-standard -- bin agents tests .github skills/setup >> "$T/a" || rc=1; test ! -s "$T/a" || rc=1; test "$rc" -eq 0

- [ ] **AC9** The prompt blocks stay in sync. `bash bin/check-prompt-sync.sh` exits `0`.
  - check: test -s bin/check-prompt-sync.sh || exit 1; bash bin/check-prompt-sync.sh > /dev/null 2>&1

- [ ] **AC10** Every suite the edited paths reach stays green; no suite with a recursive delete is run. The suite set is every `tests/*/run.sh` that `git grep` finds naming `host-dispatch.md`, `skills/run/SKILL.md`, `docs/adopting.md`, `docs/adopting.ja.md` or `check-prompt-sync`, derived at run time and asserted non-empty. Each suite is first grepped for a recursive delete: a match is a failure and the suite is not run. Otherwise it exits `0` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac10.XXXXXX") || exit 1; git grep -lE 'host-dispatch\.md|skills/run/SKILL\.md|docs/adopting(\.ja)?\.md|check-prompt-sync' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; sort -u "$T/d" > "$T/suites"; test -s "$T/suites" || rc=1; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; bash "$s" < /dev/null > "$T/log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that names one of the five patterns, at which point the derived suite set this criterion runs changes.

- [ ] **AC11** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1168-codex-commit-approval.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1168-ac11.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** On a real Codex CLI session after a clean install of the release carrying this change, with the sandbox refusing `.git` writes, a run whose engineer commits either (i) asks the operator to approve the commit as one concrete command through the host's per-command approval prompt and, once approved, reaches `READY_FOR_QA`; or (ii) where no prompt is offered or the operator declines, stops `BLOCKED` naming the exact refusal and the one command for the operator to run, without retrying in another form. In neither case does the run ask for a sandbox, trust or writable-root change.
  - above-ceiling: the operator's re-measurement after release, recorded by the coordinating session on this task's board entry; a follow-up issue is filed if the run still refuses to ask or asks for a widening grant. QA reports this criterion as `SKIP` and audits that the ownership is recorded.

## Input space

**Reachable input classes**:

1. **Host.** A Codex CLI session whose sandbox refuses writes under `.git/` (the measured `workspace-write` default); a Codex CLI session where the operator made `.git` writable before the session (no refusal, no prompt); a Claude Code session (unaffected).
2. **Approval availability.** A host that shows its ordinary per-command approval prompt for the refused commit; a host configured to show none.
3. **Operator answer.** Approves the shown commit command; declines it.
4. **Committing party.** The `engineer` role's own commit (the observed case); any other role or record commit the run makes on the same host follows the same discipline.
5. **Reader.** The orchestrator reading the installed plugin's run skill; an operator reading `docs/adopting.md` or `docs/adopting.ja.md`.
6. **Shells for the checks.** bash 3.2 (macOS) and bash 5 (Linux CI).

**Out-of-scope synthetic extremes**, declined explicitly:

1. An operator approving a command other than the one shown, or editing it in the prompt — the host's own approval UI behaviour.
2. A Codex approval-policy configuration this repository has not measured (any value other than the shipped default's prompt or no prompt).
3. A push, merge or any non-commit write offered for per-command approval — push and merge stay human gates.
4. Concurrent sessions committing to one checkout.

<!-- END intent-block: T-1168 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | (a) never request a widening grant; operator decides before the session (Goal, decision 1) | **AC1**, **AC3** |
| 2 | (b) per-command approval of a role's own commit, one command at a time, only the shown command (Goal, decision 1) | **AC1** |
| 3 | (c) no prompt or declined → `BLOCKED`, exact refusal, one command, no retry in another form (Goal, decision 1) | **AC1** |
| 4 | Two copies byte-identical (decision 1) | **AC1**, **AC9** |
| 5 | Ambiguous phrase gone from every shipped surface (decision 1, canon) | **AC2** |
| 6 | No Codex approval-policy value or widening setting named (decision 1, Non-goals) | **AC3** |
| 7 | Run's own discipline, not Codex semantics; no push allowance (decision 1, Non-goals) | **AC1** (review-judged half) |
| 8 | Line count and dispatch line position kept (decision 2) | **AC7** |
| 9 | Step 0 narrowed; T-1164 AC8/AC9 tokens kept (decision 3) | **AC4** |
| 10 | Step 6 EN/JA state (b) and (c) (decision 4) | **AC5**, **AC6** |
| 11 | Operator's-decision list item mentions per-command approval (decision 5) | **AC13** |
| 12 | `skills/setup/SKILL.md`, agents, `bin/`, `tests/`, `.github/` unchanged (decision 6, Non-goals) | **AC8** |
| 13 | Claude Code host unchanged (Non-goals) | **AC8** (no agent or setup change); the host-dispatch Claude Code line is outside the edited line, review-judged |
| 14 | Pre-commitment and drop order (decision 7) | info-only (not promoted to AC) — a disposition rule the coordinating session executes, nothing a check can observe before it fires |
| 15 | Operator's pre-session grant unchanged (Non-goals) | info-only (not promoted to AC) — declares an untouched behaviour; nothing in the diff reaches it |
| 16 | Stale `code-reviewer.md:104` citation not repaired (Non-goals) | info-only (not promoted to AC) — out of scope; reported to the coordinating session as a finding |
| 17 | Suites reached stay green; no recursive delete | **AC10** |
| 18 | Real-host behaviour (Non-goals) | **AC12** (above the ceiling) |

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `templates/prompt-blocks/host-dispatch.md` | `:5` | this-task (**AC1**, **AC3**, **AC7**) |
| `skills/run/SKILL.md` | `:182` (contain copy); `:22` Step 0 | this-task (**AC1**, **AC4** droppable) |
| `docs/adopting.md` | step 6 `:571`–`:593`; list item `:455` | this-task (**AC5**; list item **AC13**, droppable) |
| `docs/adopting.ja.md` | 手順 6 `:573`–`:596`; list item `:458` | this-task (**AC6**; list item **AC13**, droppable) |
| `docs/adopting.md` / `.ja.md` | `:427`–`:430` / `:431`–`:435` (setup never adds an approval rule; refused setup write approved per command) | unchanged: already consistent — names a persistent rule and setup's own per-command reliance |
| `docs/adopting.md` / `.ja.md` | `:718`–`:720` / `:715`–`:720` (the `.git` refusal is Codex's policy, the operator's to change, step 6) | unchanged: about the policy, not a per-command request; points at step 6, which now carries (b) and (c) |
| `skills/setup/SKILL.md` | Boundary `:82`–`:85`; Step 3 `:37`–`:45` | unchanged: Boundary names widening grants, bypasses and persistent rules; Step 3 in the same file already allows per-command approval of one concrete command |
| `agents/*.md` | — | unchanged: no agent states the rule |
| `README.md` / `README.ja.md` | — | unchanged: neither states the rule (grep for `grant`, `writable`, `per-command` found no hit) |

## Blast radius

- **Codex CLI adopters.** The run skill is read from the installed plugin and updates with it; no generated `.codex/agents` file carries this text (it is skill text, not agent text), so `update shell-team` is not needed for it.
- **Claude Code adopters.** No behavioural change; the edited line is the Codex CLI paragraph.
- **This checkout.** `agents/code-reviewer.md` `:104` cites `host-dispatch.md:20`; decision 2 keeps the block's line numbers fixed.
- **Merged specs.** No two-arm sweep runs (A2 operation). A merged criterion that pins the replaced sentence (`neither asks for nor adds`) or the old Step 0 ending (`never ask for a grant or add an approval rule`) would turn red; T-1164's **AC8** and **AC9** are restated in **AC4** so their tokens are held here; other reds are judged by CI and the reviewer.

## Version derivation note

Premise: PATCH (relayed). Headline test: not met — the run gains no capability the operator could not already exercise; a shipped sentence that was read as forbidding a per-command approval stops being read that way. Default-reachability: met — every Codex CLI run whose sandbox refuses `.git` writes reaches it. Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed, primary confirmation on the coordinating side:** the triggering observation (a Codex CLI clean-install run (v2.8.1) stopped `BLOCKED` before `READY_FOR_QA` because the sentence was read as forbidding a per-command commit approval). Not re-measured; **AC12** re-observes the path after release.
- **Relayed:** issue #662's Expected text, quoted verbatim above; the expected tier PATCH; the A2 operating conditions.
- **Relayed and re-measured by this role (file reads):** the inventory — `host-dispatch.md` `:5`, `skills/run/SKILL.md` `:22` and `:182`, `skills/setup/SKILL.md` `:41` and `:82`, `docs/adopting.md` `:452`–`:456`, `:571`–`:593`, `:718`–`:720`, `docs/adopting.ja.md` `:459`, `:586`, `:715`, and "agents: none state the rule". All confirmed. **Finding on the hand-off:** the relay said `agents/code-reviewer.md` "cites a line number" in `host-dispatch.md`; measured, it cites `host-dispatch.md:20`, a blank line — the scope rule it means is at `:22`. The citation is already stale by two lines; decision 2 keeps it from moving further and the repair is out of scope (suggested follow-up issue).
- **Assumption (unverified):** the Codex CLI host shows an ordinary per-command approval prompt for a sandbox-refused command under its shipped default configuration — the relayed 0.159.3 runs report such a prompt for the review's `claude -p` call (`docs/adopting.md` `:457`–`:460`), not yet for a commit. (b) is worded as "may ask", and (c) covers the case where no prompt appears, so the text is correct either way; **AC12** measures which case occurs.
- **Assumption:** "a role's own commit" in the canon covers the orchestrator's own record commits on the same host (Input space 4); the frozen tokens say `own commit` and do not narrow it to `engineer`.
- **Borrowed-vocabulary sweep.** Own coinage (new on the edited lines/regions): `sandbox, trust or writable roots`, `one concrete command at a time`, `only the command shown`, `exact refusal`, `for the operator to run`, `1 つずつ`, `表示されたコマンドだけ`, `別の形`. Borrowed tokens whose count at the base ref the criteria rely on, measured by this role by file read at `c68f32b5`'s working tree (to be re-measured at the branch-point blob by the freeze run with `$B` = `git merge-base develop HEAD`):
  - `neither asks for nor adds` — 1 in `templates/prompt-blocks/host-dispatch.md`, 1 in `skills/run/SKILL.md`, 0 elsewhere in `skills templates agents docs README.md README.ja.md` (**AC2** asserts 0 after). Command: `git grep -c -F 'neither asks for nor adds' "$B" -- skills templates agents docs README.md README.ja.md`.
  - `never ask for a grant or add an approval rule` — 1 in `skills/run/SKILL.md` (`:22`). Command: `git show "$B:skills/run/SKILL.md" | grep -cF 'never ask for a grant or add an approval rule'`.
  - `BLOCKED` on the `P` line of `host-dispatch.md` — 0; in `docs/adopting.md` step 6 region — 0; in `docs/adopting.ja.md` 手順 6 region — 0. Command: the **AC1**/**AC5**/**AC6** region extraction applied to `git show "$B:<path>"`, then `grep -c BLOCKED`.
  - `own commit` in `docs/adopting.md` step 6 — 1 already (`:591`, "only a role's own commit needs `.git` write access"); **AC5** therefore does not rely on it to discriminate, the four coinage tokens do. `per-command` in the EN step 6 region — 1 already (`:586`); not required there by **AC5**.
  - `per-command` in the EN list item `:455`–`:456` — 0; `コマンド単位` in the JA list item `:458`–`:459` — 0.
  - The line-start anchors `P`, `**Step 0 setup check (T-1164)`, `6. **The sandbox's write policy`, `7. **Confirm Claude Code CLI`, `- **Write access to the git directory, for commits**`, ``6. **`.git` への``, `7. **この host に Claude Code CLI`, `- **commit のための git ディレクトリへの書き込み**` each occur exactly once today in the file each criterion reads (this role, file read).

## Open questions

- none blocking.

## Notes for engineer

- Files likely touched: `templates/prompt-blocks/host-dispatch.md` (`:5`), `skills/run/SKILL.md` (`:182`, identical to `:5`; `:22`), `docs/adopting.md` (list item `:455`–`:456`; step 6 `:571`–`:593`), `docs/adopting.ja.md` (list item `:458`–`:459`; 手順 6 `:573`–`:596`), plus this task's provenance record. Nothing under `bin/`, `agents/`, `tests/`, `.github/` or `skills/setup/`.
- Gotchas:
  - `host-dispatch.md` `:5` and `skills/run/SKILL.md` `:182` are one physical line each and must stay byte-identical (`bin/check-prompt-sync.sh`, **AC9**); add no line break inside them (**AC7**).
  - Edit only the `.git` sentence; keep the `.codex/` and `check-codex-agents.sh` sentences that follow it.
  - On `:22`, keep every T-1164 **AC9** token and avoid every **AC8** token — write "writable roots" with a space, never `writable_roots`.
  - Keep the docs step-6 additions inside the step (before the `7.` line) and the list-item additions as indented continuation lines.
- Wording guidance (not frozen beyond the tokens). For `:5`/`:182`, replacing from "and the run neither asks for nor adds that grant": "… is the operator's decision to make before the session starts, and the run never requests a grant that widens the session's sandbox, trust or writable roots (measured: … exit 128) — see `docs/adopting.md`'s "Using shell-team from Codex CLI" section for the exact invocation. When the sandbox refuses a role's own commit, the run may ask the operator to approve that commit as one concrete command at a time through the host's ordinary per-command approval prompt; the approval covers only the command shown and widens no boundary. Where the host offers no such prompt or the operator declines, the role stops `BLOCKED`, reporting the exact refusal and the one commit command for the operator to run, and never retries the commit in another form." For `:22`: "… never change the host's configuration, never ask for a grant that widens the session's sandbox, trust or writable roots, and never add an approval rule." For EN step 6: append the same (b)/(c) pair for "a role's own commit". For JA 手順 6: 「sandbox が役割自身の commit を拒否した場合、run はその commit を具体的なコマンドとして 1 つずつ、host の通常のコマンド単位の承認プロンプトで operator に承認を求めてよい。承認は表示されたコマンドだけに及び、境界は広がらない。host にそのプロンプトが無いか operator が承認しない場合、役割は正確な拒否内容と operator が実行する 1 つのコマンドを報告して `BLOCKED` で止まり、別の形で再試行しない。」 For the list items: "Without that grant, a role's own commit can still be approved per-command, one command at a time (step 6)." / 「その許可が無くても、役割自身の commit はコマンド単位で 1 つずつ承認できる（手順 6）。」
- Measured-at-ref command check: not applicable — no deliverable prints a command beside a `measured at <ref>` label.
- A pre-commitment is frozen (decision 7). If the never-dropped wording cannot state (b) without naming a Codex approval-policy value or a setting, stop and report; do not widen the wording to name one.
- Recursive deletion: none in any file you write or any check line here. Leave temp files under `$TMPDIR`.
