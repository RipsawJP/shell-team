# On the Codex CLI host, the orchestrating session keeps its turn while a spawned role it waits on is still running

**Status**: READY_FOR_ENG
**Owner**: pm-spec
**Task ID**: T-1170

**Branch**: `feature/670-codex-parent-turn`, cut from `develop` at `04303f79` (`.git/refs/heads/develop` and the branch ref both read `04303f79ba92cd080fa92a1679394026a0ca8c8f`). Not stacked: no open predecessor. The pull request targets `develop`.

## Problem

On the Codex CLI host, a run reached `READY_FOR_QA` with no extra operator input, and then the orchestrating session ended its own turn while the spawned QA and review roles were still in flight. On that host a child's completion message does not start a new turn in a parent whose turn has ended, so the review's `APPROVE` sat unread for about 7 minutes until the operator typed a progress question. The shipped dispatch text only says not to abort a spawned role on elapsed time; it says nothing about the parent ending its own turn. The canon is issue #670, relayed verbatim by the coordinating session (this role cannot read the tracker) and quoted here:

> ## Observed
> On a Codex CLI clean-install run (v2.8.2, codex-cli 0.159.3), the run reached `READY_FOR_QA` with no extra operator input. After that, the orchestrating session ended its own turn while the spawned QA and review roles were still in flight. Its last message said the QA record commit and the review were not finished yet.
> - The review role completed with `APPROVE` and messaged the parent. In the session rollout, that inter-agent message carries `trigger_turn: false`, so it did not start a new turn in the parent.
> - The parent stayed idle for about 7 minutes after the review completed. It resumed only when the operator typed a progress question; it then set `READY_FOR_MERGE`.
> - The operator's text inputs rose from 2 (setup prompt and run request) to 3.
> Before ending its turn, the parent had polled `wait_agent` (10-second timeouts) for about 6 minutes while both roles were waiting on per-command approvals. The operator saw a long series of execution-approval prompts and could not tell which role or step each one belonged to.
> ## Why the shipped text does not cover it
> `templates/prompt-blocks/host-dispatch.md`, the "Waiting on a spawned role, on the Codex CLI host" paragraph (from #566), says to wait on a spawned role until its turn completes, and that elapsed time alone never justifies aborting it. Here the parent did not abort a role. It ended its own turn, and on this host a child's completion message does not wake a parent whose turn has ended.
> ## Expected
> - On the Codex CLI host, the orchestrating session does not end its turn while any spawned role it is waiting on is still running, including a role waiting on an operator approval. It keeps waiting until each role has returned.
> - If it does end its turn with roles in flight, its final message says so explicitly and tells the operator to send any message to resume once the pending approvals are done. Until then, the run is not reported as finished.

Both Expected bullets are in scope and are not narrowed. Telling the operator which role or step each approval prompt belongs to is **not** in scope (a separate candidate, per the coordinating session).

## Summarized sources

- GitHub issue #670 (Observed, Why, Expected). **Relayed verbatim by the coordinating session; this role did not read it.** Quoted above. Distinctions carried over:
  - The defect is the **parent ending its own turn**, not the parent aborting a role. The T-1150 rule (do not abort on elapsed time) is correct and stays.
  - Bullet 1 covers **any** spawned role the parent is waiting on, **including one waiting on an operator approval**, and the parent waits **until each** has returned.
  - Bullet 2 is the fallback when the turn ends anyway: the final message **says so explicitly**, tells the operator to **send any message to resume once the pending approvals are done**, and the run is **not reported as finished** until then.
  - Both bullets are scoped to the **Codex CLI host**.
- `templates/prompt-blocks/host-dispatch.md` (read in full, 31 lines at `04303f79`). Distinctions: `:7` is the T-1150 paragraph `**Waiting on a spawned role, on the Codex CLI host (T-1150).**` — wait on a spawned role until its turn completes, elapsed time never justifies aborting, nudge, re-measure before any abort; it ends "This paragraph governs the Codex CLI host's `spawn_agent` dispatch; the Claude Code host's own dispatch is unchanged." It says nothing about the parent's own turn. `:3` is the Claude Code host's dispatch sentence. `:9` is the class-B re-freeze paragraph for this host. Every paragraph is one physical line.
- `templates/prompt-blocks/registry.txt` `:57` (read): `contain host-dispatch.md skills/run/SKILL.md` — every non-empty line of the canonical block must appear verbatim in `skills/run/SKILL.md`, checked by `bin/check-prompt-sync.sh`.
- `skills/run/SKILL.md` `:178`–`:188` (read). Distinction: the host-dispatch block is spliced there; `:184` is the T-1150 paragraph, byte-identical to the template's `:7`.
- `docs/adopting.md` step 10 (`:668`–`:700`, read). Distinction: it tells the operator to "Wait on each spawned role until its turn completes", restates the T-1150 nudge and re-measure rule ("elapsed time alone never justifies one"), and says the `APPROVE` reaches `READY_FOR_MERGE` without leaving the Codex CLI session. It says nothing about the parent's own turn. Step 11 begins at `:701`.
- `docs/adopting.ja.md` step 10 (`:666`–`:696`, read). Distinction: the same content in Japanese ("spawn した役割は、その番が完了するまで待つ", "経過時間だけを理由に abort してはならない" at `:677`). Step 11 begins at `:697`.
- `README.md` `:27` / `README.ja.md` `:27` (read). Distinction: they state the outcome (the run reaches `READY_FOR_MERGE` on either host), not the waiting mechanism; this task makes that statement true on the Codex CLI host and does not edit them.
- `bin/check-adopter-docs.sh` (read `:1`–`:80`). Distinction: each `- shipped-docs: <path> — this-task` path must appear as a literal substring in one of this spec's own `- check:` or `- adopter-surface:` lines.
- `.shell-team/specs/T-1166-codex-new-session.md` (read in full). Distinction: precedent for this spec's declaration shapes, base-ref arms and fixture conventions.
- openai/codex source and the run's rollout. **Relayed by the coordinating session; this role did not read them** (see Assumptions). Distinction carried over: a child's completion message does not start a turn in an idle parent. Only that observed behaviour is carried into shipped text, never Codex's internal file or field names.

## Goal

<!-- BEGIN intent-block: T-1170 -->

- user-visible: yes — on the Codex CLI host, the orchestrating session now keeps its turn until each spawned role it waits on has returned, so a run reaches `READY_FOR_MERGE` without an extra operator message; when the turn ends anyway, the operator is told which roles are still running and to send any message to resume. The run skill's dispatch text and both adopting guides state it.
- verification-class: mechanism — the diff edits `templates/prompt-blocks/host-dispatch.md`, a prompt block whose sync into `skills/run/SKILL.md` is enforced by `bin/check-prompt-sync.sh`, plus shipped documentation.
- verification-ceiling: unit-and-static — **AC1**–**AC8** are settled in a plain checkout: they read shipped files, compare them with their base blobs, and take checker and suite exit codes. **AC9**, the behaviour of a real Codex CLI session, sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor; it was cut from `develop` at `04303f79`, and the base-side reads in **AC3**, **AC5** and **AC7** use `git merge-base develop HEAD` (or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves), each arm selected by `git show-ref --verify --quiet`.
- shipped-docs: templates/prompt-blocks/host-dispatch.md — this-task
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task

**Goal (one sentence).** `templates/prompt-blocks/host-dispatch.md`, and verbatim `skills/run/SKILL.md`, carry one new Codex-CLI-only paragraph opening `**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**` that tells the orchestrating session not to end its turn while any spawned role it waits on is still running — including one waiting on a per-command approval — and to keep waiting until each has returned, because a child's completion message does not wake a parent whose turn has ended; and, if the turn ends anyway, to make its final message name the roles still running, tell the operator to send any message to resume once the pending approvals are done, and not report the run as finished; both adopting guides' step 10 say the same, and every other line of those files is unchanged.

**Decisions frozen here** (each is promoted to a criterion):

1. **Keep the turn (Expected bullet 1).** On the Codex CLI host, while any role spawned with `spawn_agent` that the session is waiting on is still running, the session does not end its turn. A role waiting on a per-command operator approval counts as still running. A wait call that returns because its own timeout expired, with the role still running, is not a reason to end the turn: wait again. The session keeps waiting until each role has returned. The stated reason is the observed behaviour: on this host a child's completion message does not wake a parent whose turn has ended, so ending the turn stalls the run until the operator types. (**AC1**)
2. **Fallback when the turn ends anyway (Expected bullet 2).** If the turn ends with roles still running, its final message says so explicitly: it names each role still running, says it may be waiting on a per-command approval, tells the operator to send any message to resume once the pending approvals are done, and does not report the run as finished or set `READY_FOR_MERGE`. (**AC2**)
3. **Placement.** One new paragraph, one physical line, in `templates/prompt-blocks/host-dispatch.md`, carried verbatim into `skills/run/SKILL.md`; `bin/check-prompt-sync.sh` exits `0`. Every other line of both files is unchanged, so the T-1150 paragraph, the class-B re-freeze paragraph and the Claude Code host's dispatch text stay byte-identical. (**AC3**, **AC4**)
4. **Observed behaviour only.** The shipped text states the host behaviour, not Codex's internal names: the new paragraph and the guides' step 10 contain none of `trigger_turn`, `codex-rs`, `completion.rs`, `mod.rs`. (**AC1**, **AC5**)
5. **Docs.** `docs/adopting.md` and `docs/adopting.ja.md` step 10 state both rules for the operator, keep the existing elapsed-time rule, add no `## ` heading, and name no path under `/Users/` or `/home/`. (**AC5**)

**Pre-commitment (AI self-discipline, not an operator ruling).** Never-dropped: decision 1 (keep the turn). A review or QA finding that decision 1's rule cannot be stated correctly for this host, or that it is wrong on this host, is not patched in place: the task stops and returns to planning. Droppable: the wording of decision 2 beyond **AC2**'s frozen tokens. Trigger: the same reviewer class of finding against decision 2's wording in two consecutive rounds. Disposition: reduce decision 2's sentence to the shortest wording that carries **AC2**'s tokens and decision 2's four items, carry the findings to a follow-up issue as its requirement list, and do not run another wording round. Decision 2 itself is never dropped.

## Non-goals

- **No change to Codex's own turn behaviour** (whether a child's completion message wakes the parent), and no host-configuration write. (**AC7**)
- **No `bin/` wait, poll or monitor script**: no file under `bin/` is added, removed or changed. (**AC7**)
- **The T-1150 paragraph (no abort on elapsed time) and the class-B re-freeze paragraph are unchanged.** (**AC3**)
- **The Claude Code host's dispatch text is unchanged.** (**AC3**)
- **No change to `agents/*`, to any other `templates/*` or `skills/*` file, to `README.md` / `README.ja.md`, or to `.claude-plugin/plugin.json`** (the version bump is the release step's). (**AC7**)
- **Approval prompts are not reduced in number or attributed to a role or step.** Which role an approval prompt belongs to is a separate candidate. (info-only)
- **The real-host outcome** is the operator's post-release re-measurement, not this task's verification. (**AC9**)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, writes only under `$TMPDIR` (temp directories are left in place, never removed), and contains no recursive delete. `L` is the literal label `**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**`.

- [ ] **AC1** Keep the turn (decision 1). `templates/prompt-blocks/host-dispatch.md` carries exactly one line beginning with `L`. That line names each of `spawn_agent`, `end its turn`, `still running`, `per-command approval`, `until each`, `completion message`, `does not wake` and `Claude Code host`, and contains none of `trigger_turn`, `codex-rs`, `completion.rs`, `mod.rs` (the read is asserted to complete: grep exit `1`).

  Review-judged, against decision 1: the line tells the orchestrating session on the Codex CLI host not to end its turn while any spawned role it waits on is still running, counts a role waiting on a per-command approval as running, treats a wait call's own timeout as a reason to wait again rather than to end the turn, keeps waiting until each role has returned, states the observed reason, and says the Claude Code host's dispatch is unchanged.
  - check: rc=0; export LC_ALL=C; F=templates/prompt-blocks/host-dispatch.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac1.XXXXXX") || exit 1; L='**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**'; awk -v l="$L" 'index($0,l)==1' "$F" > "$T/p"; test "$(grep -c . "$T/p" || true)" = 1 || rc=1; for w in spawn_agent 'end its turn' 'still running' 'per-command approval' 'until each' 'completion message' 'does not wake' 'Claude Code host'; do grep -qF -- "$w" "$T/p" || rc=1; done; grep -qE 'trigger_turn|codex-rs|completion\.rs|mod\.rs' "$T/p"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC2** Fallback when the turn ends anyway (decision 2). The same line beginning with `L` names each of `final message`, `any message`, `resume`, `finished` and `READY_FOR_MERGE`.

  Review-judged, against decision 2: the line says that if the turn ends with roles still running, the final message names each role still running, says it may be waiting on a per-command approval, tells the operator to send any message to resume once the pending approvals are done, and does not report the run as finished or set `READY_FOR_MERGE`.
  - check: rc=0; export LC_ALL=C; F=templates/prompt-blocks/host-dispatch.md; test -s "$F" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac2.XXXXXX") || exit 1; L='**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**'; awk -v l="$L" 'index($0,l)==1' "$F" > "$T/p"; test "$(grep -c . "$T/p" || true)" = 1 || rc=1; for w in 'final message' 'any message' resume finished READY_FOR_MERGE; do grep -qF -- "$w" "$T/p" || rc=1; done; test "$rc" -eq 0

- [ ] **AC3** The two files change only by the new line (decision 3). For each of `templates/prompt-blocks/host-dispatch.md` and `skills/run/SKILL.md`: it carries exactly one line beginning with `L`; its base blob at `git merge-base develop HEAD` exists, is non-empty and carries `**Waiting on a spawned role, on the Codex CLI host (T-1150).**` (positive control); and the head file with the line beginning `L` removed equals the base blob once runs of blank lines are squeezed (`cat -s`). This is merge-point-scoped and expected to go stale once a later task's edits to either file land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac3.XXXXXX") || exit 1; L='**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**'; for f in templates/prompt-blocks/host-dispatch.md skills/run/SKILL.md; do test -s "$f" || exit 1; git show "$B:$f" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; grep -qF '**Waiting on a spawned role, on the Codex CLI host (T-1150).**' "$T/b" || rc=1; test "$(awk -v l="$L" 'index($0,l)==1' "$f" | grep -c . || true)" = 1 || rc=1; awk -v l="$L" 'index($0,l)!=1' "$f" | cat -s > "$T/h"; cat -s "$T/b" > "$T/bs"; cmp -s "$T/bs" "$T/h" || rc=1; done; test "$rc" -eq 0

- [ ] **AC4** The run skill carries the paragraph verbatim (decision 3). The line beginning with `L` in `skills/run/SKILL.md` is byte-identical to the one in `templates/prompt-blocks/host-dispatch.md`, the registry still reads `contain host-dispatch.md skills/run/SKILL.md`, and `bash bin/check-prompt-sync.sh` exits `0`.
  - check: rc=0; export LC_ALL=C; H=templates/prompt-blocks/host-dispatch.md; S=skills/run/SKILL.md; R=templates/prompt-blocks/registry.txt; for f in "$H" "$S" "$R" bin/check-prompt-sync.sh; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac4.XXXXXX") || exit 1; L='**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).**'; awk -v l="$L" 'index($0,l)==1' "$H" > "$T/h"; awk -v l="$L" 'index($0,l)==1' "$S" > "$T/s"; test -s "$T/h" || rc=1; cmp -s "$T/h" "$T/s" || rc=1; grep -qE '^contain[[:space:]]+host-dispatch\.md[[:space:]]+skills/run/SKILL\.md[[:space:]]*$' "$R" || rc=1; bash bin/check-prompt-sync.sh > "$T/o" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** Both adopting guides' step 10 state the rules (decision 5).
  - English: `docs/adopting.md` carries exactly one line beginning `10. Start a Codex CLI session`. The region from that line up to the line beginning `11. `, with leading spaces stripped and lines joined by one space, names `end its turn`, `per-command approval`, `any message`, `resume`, `READY_FOR_MERGE` and `elapsed time alone never justifies`.
  - Japanese: `docs/adopting.ja.md` carries exactly one line beginning `10. その repository で Codex CLI`. The region from that line up to the line beginning `11. `, with leading spaces stripped and lines joined with nothing between them, names `ターン`, `承認`, `メッセージ`, `再開` and `経過時間だけを理由に abort してはならない`.
  - Neither region contains `trigger_turn`, `codex-rs`, `/Users/` or `/home/` (each read asserted to complete).
  - Each guide's `## ` heading count equals its base blob's.
  - adopter-surface: `docs/adopting.md` and `docs/adopting.ja.md` step 10 of `## Using shell-team from Codex CLI` / `## Codex CLI から shell-team を使う`; plus the run skill's dispatch text (**AC1**, **AC2**, **AC4**), which is what the orchestrating session on that host reads.

  Review-judged, against decisions 1 and 2: each guide tells the operator that the orchestrating session keeps its turn until each spawned role has returned, including one waiting on a per-command approval, and that if the turn ends with roles still running, the final message says so and asks for any message to resume once the approvals are done, and the run is not finished until then.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac5.XXXXXX") || exit 1; test "$(grep -c '^10\. Start a Codex CLI session' "$E" || true)" = 1 || rc=1; test "$(grep -c '^10\. その repository で Codex CLI' "$J" || true)" = 1 || rc=1; awk 'index($0,"10. Start a Codex CLI session")==1{f=1} index($0,"11. ")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$E" > "$T/e"; awk 'index($0,"10. その repository で Codex CLI")==1{f=1} index($0,"11. ")==1{f=0} f{sub(/^ +/,""); printf "%s", $0}' "$J" > "$T/j"; test -s "$T/e" || rc=1; test -s "$T/j" || rc=1; for w in 'end its turn' 'per-command approval' 'any message' resume READY_FOR_MERGE 'elapsed time alone never justifies'; do grep -qF -- "$w" "$T/e" || rc=1; done; for w in ターン 承認 メッセージ 再開 '経過時間だけを理由に abort してはならない'; do grep -qF -- "$w" "$T/j" || rc=1; done; for f in "$T/e" "$T/j"; do grep -qE 'trigger_turn|codex-rs|/Users/|/home/' "$f"; g=$?; test "$g" -eq 1 || rc=1; done; for f in "$E" "$J"; do git show "$B:$f" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; test "$(grep -c '^## ' "$f" || true)" = "$(grep -c '^## ' "$T/b" || true)" || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1170-codex-parent-turn.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac6.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC7** Nothing else changes (Non-goals). Every file tracked at `git merge-base develop HEAD` under `agents/`, `bin/`, `templates/` and `skills/`, except `templates/prompt-blocks/host-dispatch.md` and `skills/run/SKILL.md`, plus `README.md`, `README.ja.md` and `.claude-plugin/plugin.json`, exists and is byte-identical to its base blob. The set of files the index tracks under those four directories equals the base set, and no untracked, non-ignored file exists under them. Positive control: the base set names `agents/engineer.md` and `bin/team-commit.sh`. This is merge-point-scoped and expected to go stale once a later task's edits to these files land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac7.XXXXXX") || exit 1; git ls-tree -r --name-only "$B" -- agents bin templates skills > "$T/l" || exit 1; grep -qxF agents/engineer.md "$T/l" || rc=1; grep -qxF bin/team-commit.sh "$T/l" || rc=1; grep -vxF -e templates/prompt-blocks/host-dispatch.md -e skills/run/SKILL.md "$T/l" > "$T/k"; printf '%s\n' README.md README.ja.md .claude-plugin/plugin.json >> "$T/k"; while IFS= read -r f; do test -f "$f" || { rc=1; continue; }; git show "$B:$f" > "$T/x" 2>/dev/null || { rc=1; continue; }; cmp -s "$T/x" "$f" || rc=1; done < "$T/k"; sort "$T/l" > "$T/o"; git ls-files -- agents bin templates skills | sort > "$T/n"; cmp -s "$T/o" "$T/n" || rc=1; git ls-files --others --exclude-standard -- agents bin templates skills > "$T/u" || rc=1; test ! -s "$T/u" || rc=1; test "$rc" -eq 0

- [ ] **AC8** Every suite the edited paths reach stays green; no suite with a recursive delete is run. Every `tests/*/run.sh` that `git grep` finds naming `skills/run/SKILL`, `prompt-blocks` or `adopting.md` / `adopting.ja.md` is derived at run time; the derived set is non-empty and includes `tests/check-prompt-sync/run.sh`. Each suite is first grepped for a recursive delete: a match is a failure and the suite is not run. Otherwise it runs with a file-size limit (`ulimit -f`) and capped output, exits `0` and prints no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1170-ac8.XXXXXX") || exit 1; git grep -lE 'skills/run/SKILL|prompt-blocks|adopting(\.ja)?\.md' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; test -s "$T/d" || rc=1; sort -u "$T/d" > "$T/suites"; grep -qxF tests/check-prompt-sync/run.sh "$T/suites" || rc=1; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; ( ulimit -f 200000; set -o pipefail; bash "$s" < /dev/null 2>&1 | head -c 20000000 > "$T/log" ) || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that names one of the three patterns, at which point the derived suite set this criterion runs changes.

- [ ] **AC9** On a clean install of the real Codex CLI host after release, a run request reaches `READY_FOR_MERGE` with the orchestrating session keeping its turn through the QA and review roles, including while they wait on per-command approvals, and with no operator text input beyond the setup prompt and the run request. If the session's turn does end with roles in flight, its final message names them and asks for any message to resume, and the run is not reported finished before then.
  - above-ceiling: the operator — re-measures on a real Codex CLI session after the release, counts the operator's text inputs, and records the outcome on this task's board entry; a run that still idles after a role's completion goes to a follow-up issue. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes** (the states the orchestrating session on the Codex CLI host can be in when it would otherwise end its turn):

1. **Role state.** One or more spawned roles still running and working; one or more waiting on a per-command operator approval; all spawned roles returned (no rule applies: the session proceeds as before).
2. **Wait outcome.** A wait call returning because its own timeout expired with the role still running (the observed 10-second polling); a wait call returning the role's completion.
3. **Phase.** Waiting on `qa-verifier`, on `code-reviewer`, or on both at once (the observed case); waiting on `engineer` or `pm-spec` earlier in the chain.
4. **Turn ending anyway.** The session's turn ends with roles still running, for a reason the session does not control.
5. **Operator approval answer.** The operator approves; declines (the role then returns `BLOCKED` under the existing commit rule, which counts as having returned); has not answered yet.
6. **Host.** Codex CLI (the new paragraph applies); Claude Code (the paragraph does not apply; its dispatch is unchanged).

**Out-of-scope synthetic extremes**, declined explicitly:

1. A Codex CLI version in which a child's completion message does wake an idle parent: the rule still holds and is merely not needed.
2. An operator who never answers a pending approval: the session keeps waiting; no timeout or abort rule is added (the T-1150 rule governs any abort).
3. More than one orchestrating session driving the same run.
4. Attributing each approval prompt to a role or step (a separate candidate).

<!-- END intent-block: T-1170 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Do not end the turn while a spawned role is running, including one waiting on an approval; wait until each returns (decision 1, Expected bullet 1) | **AC1** |
| 2 | A wait call's own timeout is a reason to wait again (decision 1) | **AC1** (review-judged) |
| 3 | State the observed reason (decision 1) | **AC1** |
| 4 | Fallback final message: names roles, approvals, any message to resume, not finished, no `READY_FOR_MERGE` (decision 2, Expected bullet 2) | **AC2** |
| 5 | One paragraph line, verbatim in the run skill, prompt sync green (decision 3) | **AC3**, **AC4** |
| 6 | T-1150 paragraph, re-freeze paragraph and Claude Code dispatch text unchanged (decision 3, Non-goals) | **AC3** |
| 7 | No Codex internal names in shipped text (decision 4) | **AC1**, **AC5** |
| 8 | Guides' step 10 state both rules, keep the elapsed-time rule, no new heading, no paths (decision 5) | **AC5** |
| 9 | No Codex turn-behaviour change, no host-config write (Non-goals) | **AC7** (no `bin/`, `agents/`, `templates/` or `skills/` change beyond the two files) |
| 10 | No `bin/` wait or monitor script (Non-goals) | **AC7** |
| 11 | No other `agents/`, `templates/`, `skills/`, README or plugin.json change (Non-goals) | **AC7** |
| 12 | Approval prompts not reduced or attributed (Non-goals) | info-only (not promoted to AC) — declares an untouched surface; any change to it would have to land in a file **AC7** locks |
| 13 | Real-host outcome (Non-goals) | **AC9** (above the ceiling) |
| 14 | No recursive delete in check lines or run suites (AC preamble) | **AC8** (grep gate before each suite) |
| 15 | Spec declarations and board conformant | **AC6** |
| 16 | Pre-commitment drop order (Goal) | info-only (not promoted to AC) — a disposition for the loop to execute, not a property of the diff |

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `templates/prompt-blocks/host-dispatch.md` | new paragraph after `:7` (placement within the file is the engineer's call) | this-task (**AC1**–**AC3**) |
| `skills/run/SKILL.md` | the spliced block, `:178`–`:188` | this-task (**AC3**, **AC4**) |
| `docs/adopting.md` | step 10, `:668`–`:700` | this-task (**AC5**) |
| `docs/adopting.ja.md` | step 10, `:666`–`:696` | this-task (**AC5**) |

`README.md` / `README.ja.md` `:27` state only that the run reaches `READY_FOR_MERGE` on either host; they describe no waiting mechanism and stay unchanged (**AC7**). `CHANGELOG.md` is the release step's.

## Version derivation note

Premise (relayed): PATCH v2.8.3, approved at the sprint D planning. Headline test: not met — nothing new becomes possible; the change makes the documented "the run reaches `READY_FOR_MERGE`" true on the Codex CLI host. Default-reachability: met — every Codex CLI run reads the dispatch text. Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed (primary confirmation on the coordinating side, measured 2026-10-04):** openai/codex `main` at `dde5f8c5ae9b644c6882b3a48581ac317255d597` — `codex-rs/core/src/agent/control/completion.rs` builds the child-completion result message to the parent with `trigger_turn` false, and `codex-rs/core/src/tasks/mod.rs` documents that only mailbox mail marked `trigger_turn` (or any mail while a durable sleep is attached) starts a turn. The v2.8.2 run's rollout shows `trigger_turn:false` at the review completion. This role read none of these. The shipped text states only the observed behaviour (decision 4). **AC9** is where it is re-observed after release.
- **Relayed:** the `wait_agent` tool name and its 10-second polling come from the issue's observation, not from a measurement in this repository. The shipped text need not name `wait_agent`.
- **Relayed:** the sprint premise (PATCH v2.8.3, sprint D planning) and the A2 operating conditions (pm-authored spec, no spec review, single freeze).
- **Relayed and re-read here:** the Routing Map's anchors — `host-dispatch.md:7`, `registry.txt:57`, `docs/adopting.md` step 10 — were opened by this role and match. The Japanese step 10 sits at `docs/adopting.ja.md:666`–`:696` (measured here; the Routing Map left it unmeasured).
- The next task id is T-1170: no `T-117x` string occurs anywhere under `.shell-team/` (this role's search), and the board's highest is T-1169.
- By this role's reading, the base step-10 regions contain none of the new tokens **AC5** names except `READY_FOR_MERGE` and the two elapsed-time tokens (kept on purpose), so **AC5** is not vacuous at base. The freeze run measures it.
- **Borrowed-vocabulary sweep:** this spec makes no count premise over a borrowed token. The label `Keeping the turn while spawned roles run` is own coinage. The `= 0` assertions in **AC1** and **AC5** are scoped to the new line and the two step-10 regions, not to the repository.
- **AC7** compares base blobs with `cmp` against working files. If a tracked symlink exists under those four directories, `git show` prints its target text and the comparison fails; the freeze run measures whether any exists.
- None of the 11 suites **AC8** derives today contains a recursive delete (this role's grep over `tests/*/run.sh` matched nothing).

## Open questions

- none blocking.

## Notes for engineer

- Files touched: `templates/prompt-blocks/host-dispatch.md` (one new paragraph line; insert it next to the T-1150 paragraph, e.g. right after `:7`), `skills/run/SKILL.md` (the same line, at the matching place in the spliced block), `docs/adopting.md` and `docs/adopting.ja.md` step 10.
- Keep the new paragraph a single physical line, like every paragraph in the block. Do not touch any other line of either file (**AC3** compares everything else with the base blob after squeezing blank lines).
- The guides are hard-wrapped. **AC5** joins the step-10 lines before searching, so wrapping does not matter, but keep `elapsed time alone never justifies` and `経過時間だけを理由に abort してはならない` intact.
- No `agents/*` change, so `.codex/agents/` needs no regeneration.
- Wording guidance (not frozen beyond the tokens): "**Keeping the turn while spawned roles run, on the Codex CLI host (T-1170).** While any role the orchestrating session spawned with `spawn_agent` and is waiting on is still running — including one waiting on a per-command approval from the operator — the session does not end its turn: on this host a child's completion message does not wake a parent whose turn has ended, so ending it stalls the run until the operator types. A wait call that returns on its own timeout with the role still running means wait again; the session keeps waiting until each role has returned. If its turn ends anyway with roles in flight, its final message says so: it names each role still running, says it may be waiting on a per-command approval, tells the operator to send any message to resume once the pending approvals are done, and does not report the run as finished or set `READY_FOR_MERGE`. The Claude Code host's own dispatch is unchanged."
- Name no Codex source file or internal field (`trigger_turn`, `codex-rs`, …) in shipped text.
- Measured-at-ref command check: not applicable — no deliverable prints a command beside a `measured at <ref>` label.
- Recursive deletion: none in any file you write or any check line here. Leave temp files under `$TMPDIR`. Run long suites with `ulimit -f` and capped output, as **AC8** does.
