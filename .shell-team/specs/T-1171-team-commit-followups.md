# bin/team-commit.sh follow-ups: a remedy for the GIT_CONFIG_PARAMETERS refusal, and step 6 / step 10 wording fixes in both adopting guides

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1171

**Branch**: `feature/664-team-commit-followups`, cut from `develop` at `593f2522` (`.git/refs/heads/develop` and the branch ref both read `593f252244d1b7a9a5373e79a198592261bd2faa`, read by this role). Not stacked: no open predecessor. The pull request targets `develop`.

## Problem

T-1169 shipped `bin/team-commit.sh` and its EN/JA step 6 text, and T-1170 extended step 10. Their review records left four follow-ups, filed as issues #664, #665, #666 and #672:

- **#664.** `GIT_CONFIG_PARAMETERS` set in the environment makes `bin/team-commit.sh` exit `2` before any write, with a generic refusal text and no remedy anywhere (not in the refusal, the `--help` text or the guides). The Claude Code sandbox in this repository exports it, so a hand-run of the script there is refused until it is unset. `GIT_CONFIG_COUNT` already has a remedy line; `GIT_CONFIG_PARAMETERS` has none.
- **#665 (1).** In step 6, "Running step 3 from your own shell avoids the `.codex` refusal entirely, since a role's or the orchestrator's own commit needs `.git` write access" now reads as if the `.git` sentence were the reason step 3 avoids the `.codex` refusal (EN and JA). The EN line also runs over the guide's wrap width.
- **#665 (2).** Step 6 says a repository's own hook "may change the commit after that check (`exit 3` reports it ...)". Post-commit verification compares paths and modes only, so a hook (or an attribute filter run at `git add`) that changes a file's content or the commit message is not reported. The `--help` text carries the same overstatement.
- **#666.** On a case-insensitive filesystem, with HEAD tracking a file `a`, a request for `A/b.txt` passes the exact-case leading-directory check and commits the addition (no deletion; the tree keeps `a` and gains `A/b.txt`). T-1169's frozen Input space recorded such aliases as "never a silent commit". Disposition settled by the coordinating session: state the actual outcome in step 6 of both guides; no new refusal, no new fixture, and T-1169's frozen spec is not edited.
- **#672.** In step 10, after T-1170's inserted fallback text, "Its `APPROVE` reaches `READY_FOR_MERGE`" / 「その `APPROVE` は」 has a distant antecedent (the review role); the EN insertion is also wrapped unevenly.

**Issue canon (verbatim, pasted by the coordinating session from the tracker on 2026-10-04).** Each issue's body follows as a quoted block; its own `## ` headings are demoted to bold labels so the spec's section structure is unchanged.

> **#664 — team-commit.sh: GIT_CONFIG_PARAMETERS refusal has no remedy line — decide after the Codex CLI re-measurement**
>
> Fast-follow from T-1169 (#662), Codex review round 2.
>
> `bin/team-commit.sh` refuses (exit 2, before any write) when `GIT_CONFIG_PARAMETERS` is set, because it can carry arbitrary configuration such as a hooks path. That refusal is an operator ruling and stays. Neither the refusal text nor any shipped prose tells a role or operator what to do about it, unlike `GIT_CONFIG_COUNT`, whose refusal carries a one-line remedy.
>
> The Claude Code sandbox exports `GIT_CONFIG_PARAMETERS`, holding proxy and credential settings. Whether the Codex CLI environment, or the process an approved command runs in, exports it is not yet measured. T-1169's AC20 re-measurement on a real Codex CLI session will answer it.
>
> **Expected**
> - After that re-measurement, decide the remedy.
> - At minimum, add a remedy line to the refusal text.
> - If the Codex CLI environment does export the variable, every invocation is refused, and the remedy must let the goal of #662 be met without widening any boundary.
>
> **Prior art**
> #662 (parent). No other issue covers this variable.

> **#665 — Adopting guide step 6 (EN/JA): two wording fixes around team-commit.sh**
>
> Fast-follow from T-1169 (#662), Codex review round 2. These are wording-only fixes in `docs/adopting.md` and `docs/adopting.ja.md`, step 6.
>
> 1. **The `.git` write-access sentence (EN :591, JA :593–594).** After the round-1 repair, the sentence reads as the reason step 3 avoids the `.codex` refusal ("since a role's or the orchestrator's own commit needs `.git` write access"). Rephrase it as a separate statement: "…entirely; only a role's or the orchestrator's own commit needs `.git` write access."
> 2. **The hook-reporting sentence (EN :610–612, JA :611–614).** "A hook may change the commit (`exit 3` reports it)" overstates what is detected. The post-commit check sees changed paths and modes only. A commit-msg hook, or a content change by a hook or a `.gitattributes` filter, is not detected. Narrow the sentence, and name filters beside hooks.
>
> **Prior art**
> #662 (parent).

> **#666 — team-commit.sh: a case-variant leading directory of a tracked file commits silently on a case-insensitive filesystem**
>
> Fast-follow from T-1169 (#662). Found by the engineer, confirmed by QA and by the Codex review round 2.
>
> **Observed**
> On a case-insensitive filesystem:
> - HEAD tracks the regular file `a`.
> - The work tree has `a` moved away and `A/b.txt` created.
> - `team-commit.sh … -- A/b.txt` exits 0 and commits exactly the addition of `A/b.txt`.
>
> Nothing is deleted, and the tree keeps `a`. The resulting tree then holds two entries that differ only by case.
>
> The T-1169 spec's out-of-scope wording says a case-variant outcome is "refusal at a later stage or exit 3, never a silent commit". This case is a silent commit.
>
> **Expected**
> Pick one:
> - refuse when a requested path's leading directory matches, case-insensitively, a non-tree entry tracked in HEAD (exit 2), with a fixture; or
> - amend the recorded wording to accept this outcome.
>
> **Prior art**
> #662 (parent).

> **#672 — Adopting guide step 10 (EN/JA): name the reviewer before "Its APPROVE" / 「その APPROVE は」 and rewrap the inserted lines**
>
> **Observed**
>
> T-1170 (#670) inserted a paragraph into step 10 of `docs/adopting.md` and `docs/adopting.ja.md` (Codex CLI host: the orchestrating session keeps its turn while spawned roles run). The sentence that follows the insertion still opens with a pronoun:
>
> - EN: "Its `APPROVE` reaches …" now follows "the run is not finished until then".
> - JA: 「その `APPROVE` は…」 now follows 「それまで run は完了していない」.
>
> The antecedent (the review role) is now several sentences away, so the pronoun can be read as referring to the run. The EN inserted lines are also hard-wrapped unevenly (a short line followed by a long one).
>
> Raised by QA and by the cross-provider review of T-1170 as a non-blocking fast-follow (wording only, no behavioural effect).
>
> **Expected**
>
> - Both guides name the reviewer (`code-reviewer`) in that sentence instead of the pronoun.
> - The EN inserted lines are rewrapped to the surrounding width.
>
> **Prior art**
>
> Searched open/closed issues: #665 covers two wording fixes in step 6 of the same guides (team-commit.sh); nothing covers step 10. The two can be folded into the same change.

Expected-to-criteria trace (coordinating session): #664 — the re-measurement has run (sprint C and D Codex CLI runs: every approved invocation succeeded), so the decided remedy is the one-line refusal remedy (AC1) plus its guide sentence (AC2); the "if the Codex CLI environment does export the variable" branch did not occur. #665 (1) — AC4. #665 (2) — AC5, and AC6 for the parallel `--help` sentence. #666 — the second option ("amend the recorded wording to accept this outcome") was chosen at sprint planning; the frozen T-1169 spec is a record and is not edited, so the accepted outcome is stated in shipped prose instead (AC7) — that placement is the only narrowing, and it is deliberate. #672 — AC8 and AC9. No other Expected line is narrowed.

## Summarized sources

- GitHub issues #664, #665, #666, #672 — bodies pasted verbatim into `## Problem` by the coordinating session before the freeze; the distinctions below were drafted from the review records the issues were filed from, and agree with the bodies.
- `.shell-team/reviews/T-1169.md` round 2 (read: Major, Minor / nits, Fast-follow disposition, `:200`–`:233`). Distinctions:
  - `GIT_CONFIG_PARAMETERS` stays refused **on purpose** (operator ruling): unlike `safe.directory` pairs it can carry arbitrary configuration (a hooks path, core settings). The follow-up is a **remedy line** in the refusal text and step 6, not accepting the variable.
  - Whether the Codex CLI environment exports it was AC20's measurement; this spec carries no claim either way (coordinating-session decision 1).
  - Step 6 `.git` sentence: the suggested fix is a separate statement ("...entirely; only a role's or the orchestrator's own commit needs `.git` write access"), EN and JA.
  - Hook sentence: true **for paths and modes only**; a commit-msg or content-changing hook is not reported; filters are not named beside hooks. Suggested fix: narrow to a changed set of paths or modes and name filters.
  - Case-fold: `A/b.txt` against tracked `a` exits `0` committing exactly the addition, no deletion; it departs from T-1169's recorded "never a silent commit" wording. Two suggested fixes (refuse, or amend the recorded wording); the coordinating session chose a statement in the guides (decision 3).
- `.shell-team/reviews/T-1170.md` `:59`, `:71` (read). Distinction: "Its `APPROVE` reaches" / 「その `APPROVE` は」 now follows the inserted fallback text, so the antecedent (the review role) is far away; fix: name `code-reviewer` and rewrap the EN insertion. Wording only, no behavioural effect.
- `bin/team-commit.sh` (read `:1`–`:200`). Distinctions: `:164`–`:171` refuses 12 variables in one loop with the single text `$v is set; it redirects the repository, index or pathspec semantics`; `:177` `COUNT_REMEDY` is the precedent remedy, appended as `; $COUNT_REMEDY` at `:179`, `:181`, `:188`, `:192`; the environment check runs after argument parsing and before `command -v git` and every repository check; help `:89`–`:95` lists `GIT_CONFIG_PARAMETERS` among refused variables and gives a remedy only for `GIT_CONFIG_COUNT`; help `:106`–`:109` "A mismatch there is reported and the commit is kept. A repository's own hook may change the commit after the first check"; code comment `:39`–`:41` says the same of the invariant.
- `tests/team-commit/run.sh` (read `:1`–`:135`, `:142`–`:157`, `:560`–`:600`, `:770`–`:798`). Distinctions: `:46`–`:54` unset the refused variables and `GIT_CONFIG_KEY_n`/`VALUE_n`; `:576` `ref-env-config-parameters` asserts exit `2`, unchanged state and the stderr class only; `:577`–`:586` `ref-env-config-count-other` is the precedent remedy assertion (`grep -qF 'unset'`), whose failure line begins `FAIL: ref-env-config-count-other:`; `fail` writes `FAIL: <text>` to stderr; `TEAM_COMMIT_SCRIPT` points the suite at a scratch copy.
- `docs/adopting.md` step 6 (`:571`–`:615`, read) and step 10 (`:668`–`:704`, read); `docs/adopting.ja.md` 手順 6 (`:573`–`:616`, read) and 手順 10 (`:666`–`:699`, read). Distinctions: EN `:590`–`:592` and JA `:592`–`:595` carry the `.git` sentence; EN `:610`–`:613` and JA `:611`–`:614` the hook sentence; EN `:613`–`:615` and JA `:614`–`:616` the `GIT_CONFIG_COUNT` remedy sentence; neither step 6 names `GIT_CONFIG_PARAMETERS`, `filter` or case folding; EN `:690` and JA `:687` carry the pronoun sentence.
- `.shell-team/test-recipe.md` `:2647`–`:2674` (read). Distinction: this repository's coding sandbox (Claude Code) exports `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT` and `GIT_CONFIG_KEY_n`/`VALUE_n`; a hand-run of the script there is refused until `GIT_CONFIG_PARAMETERS` is unset.
- `.shell-team/specs/T-1169-team-commit-script.md` decision 4 (`:66`), Input space out-of-scope 5 (`:195`), **AC13** and **AC14** (`:137`–`:142`, read). Distinctions: the recorded case-fold wording "never a silent commit" stays as frozen; **AC13** requires the EN step 6 region to name `orchestrator's own commit`, `exit 3`, `concurrent` (each on one physical line) and not contain `only a role's own commit needs`; **AC14** requires the JA region to name `orchestrator 自身の commit`, `exit 3`, `同時` and not contain `役割自身の commit だけが`. This spec keeps those true (**AC4**).
- `.shell-team/specs/T-1170-codex-parent-turn.md` **AC5** (read). Distinction: the joined step-10 regions must keep `end its turn`, `per-command approval`, `any message`, `resume`, `READY_FOR_MERGE`, `elapsed time alone never justifies` (EN) and `ターン`, `承認`, `メッセージ`, `再開`, `経過時間だけを理由に abort してはならない` (JA). This spec keeps those true (**AC8**).
- `README.md` / `README.ja.md` `:210` (read). Distinction: the layout comment says the script "commits exactly the named paths; the one commit command on the Codex CLI host" / 「指定した path だけを commit する。Codex CLI host での唯一の commit コマンド」; nothing this task changes makes it wrong, so neither README changes (**AC10**).
- `.github/workflows/check-handoff.yml` `:43`–`:44`, `:396`–`:397` (read). Distinction: CI runs plain `shellcheck bin/team-commit.sh tests/team-commit/run.sh` and `bash tests/team-commit/run.sh`.
- `bin/check-adopter-docs.sh` (read `:1`–`:90`). Distinction: each `- shipped-docs: <path> — this-task` path must appear as a literal substring in one of this spec's own `- check:` or `- adopter-surface:` lines.

## Goal

<!-- BEGIN intent-block: T-1171 -->

- user-visible: yes — an operator whose environment exports `GIT_CONFIG_PARAMETERS` is now told, in the refusal itself, in `--help` and in both adopting guides, why the script refuses it and how to clear it for that invocation; the guides' step 6 and step 10 sentences that were misleading or overstated now state what the script actually does.
- verification-class: mechanism — the diff edits `bin/team-commit.sh` (refusal text and help text) and `tests/team-commit/run.sh`, plus shipped documentation.
- verification-ceiling: unit-and-static — every criterion, **AC1**–**AC12**, is settled in a plain checkout: it runs the script and its suite in `$TMPDIR`, reads shipped files, compares them with their base blobs and takes checker exit codes. None sits above the ceiling; the plain-git case-fold outcome **AC7**'s statement describes is re-measured by QA in a scratch repository, which is also unit level.
- base-ref-discriminator: not-applicable — the branch has no open predecessor; it was cut from `develop` at `593f2522`, and the base-side reads in **AC9** and **AC10** use `git merge-base develop HEAD` (or `git merge-base refs/remotes/origin/develop HEAD` when only that ref resolves), each arm selected by `git show-ref --verify --quiet`.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task

**Goal (one sentence).** `bin/team-commit.sh` refuses `GIT_CONFIG_PARAMETERS` exactly as before but with its own one-line remedy (`unset GIT_CONFIG_PARAMETERS` for that invocation), stated also in `--help` and in step 6 of both adopting guides, while the other eleven refused variables keep their refusal text byte for byte; step 6 of both guides separates the `.git` write-access statement from the step 3 sentence, narrows the hook sentence to a changed set of paths or modes and names filters beside hooks (the help text likewise), and states the case-insensitive leading-directory outcome; step 10 names `code-reviewer` in the `APPROVE` sentence; the EN lines this task rewrites wrap within 80 bytes; and nothing else in the repository changes.

**Decisions frozen here** (each is promoted to a criterion):

1. **Remedy, not acceptance (#664).** `GIT_CONFIG_PARAMETERS` set (any value, including empty) is still refused with exit `2` before any write. Its refusal is one stderr line beginning `team-commit: refused (environment): GIT_CONFIG_PARAMETERS is set` and naming the remedy `unset GIT_CONFIG_PARAMETERS`; the source spells that literal. Each of the other eleven variables keeps the exact base refusal line. `--help` names the same remedy. The suite's `ref-env-config-parameters` case asserts the remedy. (**AC1**, **AC3**)
2. **Guides' remedy sentence (#664).** Step 6 of both guides says the variable can carry arbitrary git configuration (for example a hooks path), so the script refuses it; that some sandboxes export it (measured: the Claude Code sandbox, in this plugin's own repository); and that `unset GIT_CONFIG_PARAMETERS` clears it for that one invocation. It makes no claim about which other host does or does not export it. (**AC2**)
3. **`.git` sentence (#665 (1)).** The `.git` write-access statement becomes a statement of its own, no longer the reason clause of the step 3 sentence, EN and JA. T-1169 **AC13**/**AC14**'s step-6 tokens stay true. (**AC4**)
4. **Hook sentence (#665 (2)).** Both guides and `--help` stop saying a hook "may change the commit after" the check as if every change were reported; they say that a repository's own hook or filter may change what is committed, that a changed set of paths or modes is reported by `exit 3` with the commit kept, and that a change to a file's content or to the commit message is not detected. (**AC5**, **AC6**)
5. **Case-fold statement (#666).** Step 6 of both guides states that on a case-insensitive filesystem, a requested path whose leading directory differs only in letter case from a file HEAD tracks (for example `A/b.txt` beside a tracked `a`) is committed as requested, with no deletion, leaving both entries in the tree; the script does not refuse it. No refusal and no fixture are added; T-1169's spec is unchanged. (**AC7**, **AC10**)
6. **Pronoun (#672).** Step 10's sentence saying the `APPROVE` reaches `READY_FOR_MERGE` without leaving the Codex CLI session names `code-reviewer`, EN and JA; T-1170 **AC5**'s step-10 tokens stay true. (**AC8**)
7. **Wrap.** Every line of `docs/adopting.md` that this task adds or rewrites is at most 80 bytes; the two over-wide base lines (`entirely, since ...` and `... Its `APPROVE` reaches`) are gone. (**AC9**)

**Pre-commitment (AI self-discipline, not an operator ruling).** Never-dropped: decision 1's remedy line in the refusal (**AC1**'s refusal half). A review or QA finding that the remedy cannot be stated correctly in the refusal, or that stating it changes which variables are refused or what the script commits, is not patched in place: the task stops and returns to planning. Droppable: the help-text narrowing of decision 4 (**AC6**). Trigger: the same reviewer class of finding against that help text in two consecutive rounds. Disposition: restore help-text lines `:106`–`:109` to their base bytes, remove **AC6** in a class-B re-freeze recorded as executing this pre-commitment, and carry the rounds' findings to a follow-up issue as its requirement list; no further wording round on it. The guides' half of decision 4 (**AC5**) is never dropped.

## Non-goals

- **No change to which variables are refused, to the `GIT_CONFIG_COUNT` handling, or to what the script stages, checks or commits.** Only refusal and help text change. (**AC1**, **AC11**: the suite's existing cases stay green)
- **No refusal for case-variant leading directories (#666) and no new fixture for it.** (**AC7**, **AC10**)
- **T-1169's spec and records are not edited.** (**AC10**)
- **No re-measurement of whether the Codex CLI environment exports `GIT_CONFIG_PARAMETERS`, and no claim about it in shipped text.** (**AC2**, review-judged)
- **No change to `agents/*`, `templates/*`, `skills/*`, `.github/*`, any other `bin/` or `tests/` file, any other `docs/` file, `README.md` / `README.ja.md`, `CHANGELOG.md` or `.claude-plugin/plugin.json`** (the version bump and changelog are the release step's). (**AC10**)
- **No push, merge or release.** (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, writes only under `$TMPDIR` (temp directories are left in place, never removed), contains no recursive delete, and unsets `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT` and `GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n` (and the other refused variables) before it runs the script or a suite. "EN step 6" is the region of `docs/adopting.md` from the line beginning `6. **The sandbox` up to the next line beginning `7. `; "JA step 6" is the region of `docs/adopting.ja.md` from the line beginning `6. **` that contains `への、そして Codex 自身が` up to the next line beginning `7. `; "EN step 10" / "JA step 10" are T-1170 **AC5**'s regions. "Joined" means leading spaces stripped and lines joined by one space (EN) or by nothing (JA).

- [ ] **AC1** The refusal carries its own remedy; the other eleven are unchanged (decision 1). Run from a scratch directory with `--message-file <x> -- a`: for each of `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`, `GIT_NAMESPACE`, `GIT_LITERAL_PATHSPECS`, `GIT_GLOB_PATHSPECS`, `GIT_NOGLOB_PATHSPECS`, `GIT_ICASE_PATHSPECS` set alone, the script exits `2`, prints nothing on stdout, and its stderr is exactly `team-commit: refused (environment): <VAR> is set; it redirects the repository, index or pathspec semantics` plus a newline. With `GIT_CONFIG_PARAMETERS` set alone, it exits `2`, prints nothing on stdout, and its stderr is exactly one line, beginning `team-commit: refused (environment): GIT_CONFIG_PARAMETERS is set` and containing `unset GIT_CONFIG_PARAMETERS`. The script source contains the literal `unset GIT_CONFIG_PARAMETERS`. `--help` exits `0` with empty stderr, and its stdout, joined, names `GIT_CONFIG_PARAMETERS` and `unset GIT_CONFIG_PARAMETERS`.

  Review-judged, against decision 1: the remedy line is the refusal's own (not the `GIT_CONFIG_COUNT` remedy), says the variable is refused because it can carry arbitrary configuration, and tells the operator to unset it for that invocation and re-run.
  - check: rc=0; export LC_ALL=C; S="$(pwd -P)/bin/team-commit.sh"; test -s "$S" || exit 1; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; for n in 0 1 2 3 4 5 6 7 8 9; do unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac1.XXXXXX") || exit 1; for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS; do r=$(cd "$T" && env "$v=x" bash "$S" --message-file "$T/m" -- a < /dev/null > "$T/o" 2> "$T/e"; printf '%s' "$?"); test "$r" = 2 || rc=1; test ! -s "$T/o" || rc=1; printf 'team-commit: refused (environment): %s is set; it redirects the repository, index or pathspec semantics\n' "$v" > "$T/x"; cmp -s "$T/x" "$T/e" || rc=1; done; r=$(cd "$T" && env "GIT_CONFIG_PARAMETERS='core.x'='y'" bash "$S" --message-file "$T/m" -- a < /dev/null > "$T/o" 2> "$T/e"; printf '%s' "$?"); test "$r" = 2 || rc=1; test ! -s "$T/o" || rc=1; test "$(grep -c '' "$T/e" || true)" = 1 || rc=1; grep -q '^team-commit: refused (environment): GIT_CONFIG_PARAMETERS is set' "$T/e" || rc=1; grep -qF 'unset GIT_CONFIG_PARAMETERS' "$T/e" || rc=1; grep -qF 'unset GIT_CONFIG_PARAMETERS' "$S" || rc=1; r=$(cd "$T" && bash "$S" --help < /dev/null > "$T/h" 2> "$T/he"; printf '%s' "$?"); test "$r" = 0 || rc=1; test ! -s "$T/he" || rc=1; tr '\n' ' ' < "$T/h" | tr -s ' ' > "$T/hj"; grep -qF 'GIT_CONFIG_PARAMETERS' "$T/hj" || rc=1; grep -qF 'unset GIT_CONFIG_PARAMETERS' "$T/hj" || rc=1; test "$rc" -eq 0

- [ ] **AC2** Both guides' step 6 state the remedy (decision 2). Joined EN step 6 names `GIT_CONFIG_PARAMETERS`, `unset GIT_CONFIG_PARAMETERS`, `hooks path` and `Claude Code sandbox`; joined JA step 6 names `GIT_CONFIG_PARAMETERS`, `unset GIT_CONFIG_PARAMETERS` and `Claude Code`. Each start line occurs exactly once; positive control: both joined regions name `GIT_CONFIG_COUNT`.
  - adopter-surface: `docs/adopting.md` step 6 of `## Using shell-team from Codex CLI` and `docs/adopting.ja.md` 手順 6 of `## Codex CLI から shell-team を使う`; plus the refusal line and `--help` text of `bin/team-commit.sh` (**AC1**), which is what an operator or a role meeting the refusal reads first.

  Review-judged, against decision 2: each guide says the variable can carry arbitrary git configuration (for example a hooks path) so the script refuses it, that some sandboxes export it (the Claude Code sandbox, measured in this plugin's own repository), and that `unset GIT_CONFIG_PARAMETERS` clears it for that one invocation; neither claims anything about whether the Codex CLI host or any other host exports it; EN and JA are equivalent.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac2.XXXXXX") || exit 1; test "$(awk 'index($0,"6. **The sandbox")==1' "$E" | grep -c . || true)" = 1 || rc=1; test "$(awk 'index($0,"6. **")==1 && index($0,"への、そして Codex 自身が")>0' "$J" | grep -c . || true)" = 1 || rc=1; awk 'index($0,"6. **The sandbox")==1{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$E" > "$T/e"; awk 'index($0,"6. **")==1 && index($0,"への、そして Codex 自身が")>0{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s", $0}' "$J" > "$T/j"; test -s "$T/e" || exit 1; test -s "$T/j" || exit 1; grep -qF GIT_CONFIG_COUNT "$T/e" || exit 1; grep -qF GIT_CONFIG_COUNT "$T/j" || exit 1; for w in GIT_CONFIG_PARAMETERS 'unset GIT_CONFIG_PARAMETERS' 'hooks path' 'Claude Code sandbox'; do grep -qF -- "$w" "$T/e" || rc=1; done; for w in GIT_CONFIG_PARAMETERS 'unset GIT_CONFIG_PARAMETERS' 'Claude Code'; do grep -qF -- "$w" "$T/j" || rc=1; done; test "$rc" -eq 0

- [ ] **AC3** The suite asserts the remedy (decision 1). A scratch copy of `bin/team-commit.sh` with every `unset GIT_CONFIG_PARAMETERS` replaced by `remedy-removed` differs from the original (positive control), and `tests/team-commit/run.sh` run against it (`TEAM_COMMIT_SCRIPT`) exits non-zero and prints a line beginning `FAIL: ref-env-config-parameters`. Neither file contains a recursive delete (grep exit `1`). The run has a file-size limit and capped output.
  - check: rc=0; export LC_ALL=C; S=bin/team-commit.sh; U=tests/team-commit/run.sh; test -s "$S" || exit 1; test -s "$U" || exit 1; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; for n in 0 1 2 3 4 5 6 7 8 9; do unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac3.XXXXXX") || exit 1; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$S" "$U"; g=$?; test "$g" -eq 1 || exit 1; sed 's/unset GIT_CONFIG_PARAMETERS/remedy-removed/g' "$S" > "$T/m.sh" || exit 1; cmp -s "$S" "$T/m.sh"; c=$?; test "$c" -eq 1 || exit 1; ( ulimit -f 200000; set -o pipefail; TEAM_COMMIT_SCRIPT="$T/m.sh" bash "$U" < /dev/null 2>&1 | head -c 20000000 > "$T/log" ); r=$?; test "$r" -ne 0 || rc=1; grep -q '^FAIL: ref-env-config-parameters' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC4** The `.git` statement stands on its own (decision 3). Joined EN step 6 does not contain `entirely, since` and names `orchestrator's own commit needs`; joined JA step 6 does not contain `必要とするため`. T-1169 **AC13**/**AC14** stay true: the raw EN step 6 names `orchestrator's own commit`, `exit 3` and `concurrent`, each on one physical line, and does not contain `only a role's own commit needs`; the raw JA step 6 names `orchestrator 自身の commit`, `exit 3` and `同時`, each on one physical line, and does not contain `役割自身の commit だけが` (each absence read asserted to complete, grep exit `1`).

  Review-judged, against decision 3: neither guide any longer reads the `.git` write-access statement as the reason running step 3 from your own shell avoids the `.codex` refusal.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac4.XXXXXX") || exit 1; awk 'index($0,"6. **The sandbox")==1{f=1} index($0,"7. ")==1{f=0} f' "$E" > "$T/er"; awk 'index($0,"6. **")==1 && index($0,"への、そして Codex 自身が")>0{f=1} index($0,"7. ")==1{f=0} f' "$J" > "$T/jr"; test -s "$T/er" || exit 1; test -s "$T/jr" || exit 1; awk '{sub(/^ +/,""); printf "%s ", $0}' "$T/er" > "$T/e"; awk '{sub(/^ +/,""); printf "%s", $0}' "$T/jr" > "$T/j"; grep -qF 'entirely, since' "$T/e"; g=$?; test "$g" -eq 1 || rc=1; grep -qF "orchestrator's own commit needs" "$T/e" || rc=1; grep -qF '必要とするため' "$T/j"; g=$?; test "$g" -eq 1 || rc=1; for w in "orchestrator's own commit" 'exit 3' concurrent; do grep -qF -- "$w" "$T/er" || rc=1; done; grep -qF "only a role's own commit needs" "$T/er"; g=$?; test "$g" -eq 1 || rc=1; for w in 'orchestrator 自身の commit' 'exit 3' '同時'; do grep -qF -- "$w" "$T/jr" || rc=1; done; grep -qF '役割自身の commit だけが' "$T/jr"; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** The guides' hook sentence is narrowed and names filters (decision 4). Joined EN step 6 does not contain `may change the commit after that check` and names `filter`, `content` and `exit 3`; joined JA step 6 does not contain `確認の後に commit を変えることがある` and names `filter`, `メッセージ` and `exit 3` (each absence read asserted to complete).

  Review-judged, against decision 4: each guide says a repository's own hook or filter may change what is committed, that a changed set of paths or modes is reported by `exit 3` with the commit kept, and that a change to a file's content or to the commit message is not detected; EN and JA are equivalent.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac5.XXXXXX") || exit 1; awk 'index($0,"6. **The sandbox")==1{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$E" > "$T/e"; awk 'index($0,"6. **")==1 && index($0,"への、そして Codex 自身が")>0{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s", $0}' "$J" > "$T/j"; test -s "$T/e" || exit 1; test -s "$T/j" || exit 1; grep -qF 'may change the commit after that check' "$T/e"; g=$?; test "$g" -eq 1 || rc=1; for w in filter content 'exit 3'; do grep -qF -- "$w" "$T/e" || rc=1; done; grep -qF '確認の後に commit を変えることがある' "$T/j"; g=$?; test "$g" -eq 1 || rc=1; for w in filter 'メッセージ' 'exit 3'; do grep -qF -- "$w" "$T/j" || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** The help text's hook sentence is narrowed and names filters (decision 4; droppable per the pre-commitment). `bin/team-commit.sh --help` exits `0`, and its stdout, joined, does not contain `may change the commit after the first check` (read asserted to complete) and names `filter` and `content`.
  - check: rc=0; export LC_ALL=C; S="$(pwd -P)/bin/team-commit.sh"; test -s "$S" || exit 1; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; for n in 0 1 2 3 4 5 6 7 8 9; do unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac6.XXXXXX") || exit 1; r=$(cd "$T" && bash "$S" --help < /dev/null > "$T/h" 2> "$T/he"; printf '%s' "$?"); test "$r" = 0 || rc=1; test -s "$T/h" || exit 1; tr '\n' ' ' < "$T/h" | tr -s ' ' > "$T/hj"; grep -qF 'may change the commit after the first check' "$T/hj"; g=$?; test "$g" -eq 1 || rc=1; for w in filter content; do grep -qF -- "$w" "$T/hj" || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** Both guides state the case-insensitive outcome (decision 5). Joined EN step 6 names `case-insensitive` and `A/b.txt`; joined JA step 6 names `大文字` and `A/b.txt`.

  Review-judged, against decision 5: each guide says that on a case-insensitive filesystem a requested path whose leading directory differs only in letter case from a file HEAD tracks is committed as requested, with no deletion, leaving both entries in the tree, and that the script does not refuse it; if a guide also compares this with plain git, QA has re-measured that comparison in a scratch repository on a case-insensitive filesystem and reports the measured outcome.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac7.XXXXXX") || exit 1; awk 'index($0,"6. **The sandbox")==1{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$E" > "$T/e"; awk 'index($0,"6. **")==1 && index($0,"への、そして Codex 自身が")>0{f=1} index($0,"7. ")==1{f=0} f{sub(/^ +/,""); printf "%s", $0}' "$J" > "$T/j"; test -s "$T/e" || exit 1; test -s "$T/j" || exit 1; for w in case-insensitive A/b.txt; do grep -qF -- "$w" "$T/e" || rc=1; done; for w in '大文字' A/b.txt; do grep -qF -- "$w" "$T/j" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** Step 10 names `code-reviewer` in the `APPROVE` sentence (decision 6). Joined EN step 10 does not match the extended regex `Its .APPROVE. reaches`, and, split into sentences on `. `, has one sentence naming `code-reviewer`, `APPROVE` and `leaving the Codex CLI session`. Joined JA step 10 does not match `その .APPROVE. は`, and, split on `。`, has one sentence naming `code-reviewer`, `APPROVE` and `READY_FOR_MERGE`. T-1170 **AC5**'s tokens stay: joined EN step 10 names `end its turn`, `per-command approval`, `any message`, `resume`, `READY_FOR_MERGE`, `elapsed time alone never justifies`; joined JA step 10 names `ターン`, `承認`, `メッセージ`, `再開`, `経過時間だけを理由に abort してはならない`.
  - check: rc=0; export LC_ALL=C; E=docs/adopting.md; J=docs/adopting.ja.md; for f in "$E" "$J"; do test -s "$f" || exit 1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac8.XXXXXX") || exit 1; awk 'index($0,"10. Start a Codex CLI session")==1{f=1} index($0,"11. ")==1{f=0} f{sub(/^ +/,""); printf "%s ", $0}' "$E" > "$T/e"; awk 'index($0,"10. その repository で Codex CLI")==1{f=1} index($0,"11. ")==1{f=0} f{sub(/^ +/,""); printf "%s", $0}' "$J" > "$T/j"; test -s "$T/e" || exit 1; test -s "$T/j" || exit 1; grep -qE 'Its .APPROVE. reaches' "$T/e"; g=$?; test "$g" -eq 1 || rc=1; grep -qE 'その .APPROVE. は' "$T/j"; g=$?; test "$g" -eq 1 || rc=1; awk '{n=split($0,a,/\. /); for(i=1;i<=n;i++) print a[i]}' "$T/e" > "$T/es"; awk '{n=split($0,a,"。"); for(i=1;i<=n;i++) print a[i]}' "$T/j" > "$T/js"; grep -F 'leaving the Codex CLI session' "$T/es" | grep -F code-reviewer | grep -qF APPROVE || rc=1; grep -F READY_FOR_MERGE "$T/js" | grep -F code-reviewer | grep -qF APPROVE || rc=1; for w in 'end its turn' 'per-command approval' 'any message' resume READY_FOR_MERGE 'elapsed time alone never justifies'; do grep -qF -- "$w" "$T/e" || rc=1; done; for w in 'ターン' '承認' 'メッセージ' '再開' '経過時間だけを理由に abort してはならない'; do grep -qF -- "$w" "$T/j" || rc=1; done; test "$rc" -eq 0

- [ ] **AC9** The EN lines this task rewrites wrap within 80 bytes (decision 7). In `docs/adopting.md`'s base blob at `git merge-base develop HEAD`, exactly one line contains `entirely, since` and exactly one matches `Its .APPROVE. reaches` (positive control); neither of those two lines occurs verbatim as a line of the head file; and every line of the head file that does not occur verbatim as a line of the base blob is at most 80 bytes (`LC_ALL=C` `awk` length; an em dash counts 3). This is merge-point-scoped and expected to go stale once a later task's edits to `docs/adopting.md` land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; E=docs/adopting.md; test -s "$E" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac9.XXXXXX") || exit 1; git show "$B:$E" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; grep -F 'entirely, since' "$T/b" > "$T/o1"; grep -E 'Its .APPROVE. reaches' "$T/b" > "$T/o2"; test "$(grep -c '' "$T/o1" || true)" = 1 || exit 1; test "$(grep -c '' "$T/o2" || true)" = 1 || exit 1; for o in "$T/o1" "$T/o2"; do grep -qxF -f "$o" "$E"; g=$?; test "$g" -eq 1 || rc=1; done; n=$(awk 'NR==FNR{b[$0]=1; next} !($0 in b) && length($0)>80{c++} END{print c+0}' "$T/b" "$E") || rc=1; test "$n" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC10** Nothing else changes (Non-goals). Every file tracked at `git merge-base develop HEAD` under `agents/`, `bin/`, `templates/`, `skills/`, `tests/`, `docs/` and `.github/`, except `bin/team-commit.sh`, `tests/team-commit/run.sh`, `docs/adopting.md` and `docs/adopting.ja.md`, plus `README.md`, `README.ja.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json` and every file tracked there under `.shell-team/` whose name begins `T-1169` followed by `-` or `.`, exists and is byte-identical to its base blob (a symlink compared by its target text). The set of files the index tracks under those seven directories equals the base set, and no untracked, non-ignored file exists under them. Positive control: the base set names `bin/team-commit.sh` and `.shell-team/specs/T-1169-team-commit-script.md`. This is merge-point-scoped and expected to go stale once a later task's edits to these files land on `develop`.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac10.XXXXXX") || exit 1; git ls-tree -r --name-only "$B" -- agents bin templates skills tests docs .github > "$T/l" || exit 1; grep -qxF bin/team-commit.sh "$T/l" || exit 1; git ls-tree -r --name-only "$B" -- .shell-team > "$T/st" || exit 1; grep -E '/T-1169[-.]' "$T/st" > "$T/t69"; grep -qxF .shell-team/specs/T-1169-team-commit-script.md "$T/t69" || exit 1; grep -vxF -e bin/team-commit.sh -e tests/team-commit/run.sh -e docs/adopting.md -e docs/adopting.ja.md "$T/l" > "$T/k"; cat "$T/t69" >> "$T/k"; printf '%s\n' README.md README.ja.md CHANGELOG.md .claude-plugin/plugin.json >> "$T/k"; while IFS= read -r f; do git show "$B:$f" > "$T/x" 2>/dev/null || { rc=1; continue; }; if [ -L "$f" ]; then test "$(readlink "$f")" = "$(cat "$T/x")" || rc=1; elif [ -f "$f" ]; then cmp -s "$T/x" "$f" || rc=1; else rc=1; fi; done < "$T/k"; sort "$T/l" > "$T/o"; git ls-files -- agents bin templates skills tests docs .github | sort > "$T/n"; cmp -s "$T/o" "$T/n" || rc=1; git ls-files --others --exclude-standard -- agents bin templates skills tests docs .github > "$T/u" || rc=1; test ! -s "$T/u" || rc=1; test "$rc" -eq 0

- [ ] **AC11** Shellcheck is clean and every suite the edited paths reach stays green; no suite with a recursive delete is run. `shellcheck bin/team-commit.sh tests/team-commit/run.sh` exits `0`. The suite set is every `tests/*/run.sh` that `git grep` finds naming `team-commit` or `adopting.md` / `adopting.ja.md`, plus `tests/bin-help/run.sh`, derived at run time; it includes `tests/team-commit/run.sh`. Each suite is first grepped for a recursive delete: a match is a failure and the suite is not run. Otherwise it runs with a file-size limit and capped output, exits `0` and prints no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; command -v shellcheck > /dev/null 2>&1 || exit 1; shellcheck bin/team-commit.sh tests/team-commit/run.sh > /dev/null 2>&1 || rc=1; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; for n in 0 1 2 3 4 5 6 7 8 9; do unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac11.XXXXXX") || exit 1; git grep -lE 'team-commit|adopting(\.ja)?\.md' -- 'tests/*/run.sh' > "$T/d"; test "$?" -eq 0 || rc=1; test -s tests/bin-help/run.sh || rc=1; printf '%s\n' tests/bin-help/run.sh >> "$T/d"; sort -u "$T/d" > "$T/suites"; grep -qxF tests/team-commit/run.sh "$T/suites" || rc=1; while IFS= read -r s; do test -s "$s" || { rc=1; continue; }; grep -qE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$s"; g=$?; if [ "$g" -ne 1 ]; then rc=1; continue; fi; ( ulimit -f 200000; set -o pipefail; bash "$s" < /dev/null 2>&1 | head -c 20000000 > "$T/log" ) || rc=1; test "$(grep -c '^FAIL' "$T/log" || true)" = 0 || rc=1; done < "$T/suites"; test "$rc" -eq 0
  - stale-at: a task adds, removes or renames a `tests/*/run.sh` that names `team-commit` or an adopting guide, at which point the derived suite set this criterion runs changes.

- [ ] **AC12** This spec's own declarations are conformant, and so is the board. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bin/check-handoff.sh` exits `0` on the board resolved through `bin/team-paths.sh --get todo`.
  - check: rc=0; export LC_ALL=C; D=bin/check-adopter-docs.sh; SPEC=.shell-team/specs/T-1171-team-commit-followups.md; test -s "$D" || exit 1; test -s "$SPEC" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1171-ac12.XXXXXX") || exit 1; bash "$D" "$SPEC" > "$T/do" 2> "$T/de"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/do" || rc=1; test ! -s "$T/de" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; bash bin/check-handoff.sh "$BD" > /dev/null 2>&1 || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes:**

1. **Invocation environment.** `GIT_CONFIG_PARAMETERS` set (any value, including empty), alone or together with a `safe.directory`-only `GIT_CONFIG_COUNT` (the shape the Claude Code sandbox in this repository exports); exactly one of the other eleven refused variables set; none set.
2. **Invocation form.** `--help` / `-h`; a normal commit invocation run by a role, by the orchestrator or by the operator in their own shell.
3. **Readers.** An operator reading EN or JA step 6 / step 10; a role or orchestrator reading the refusal on stderr and relaying it.
4. **Filesystem.** Case-insensitive (`core.ignorecase=true`, the macOS default) with HEAD tracking a file `a` and `A/b.txt` requested; case-sensitive.
5. **Repository hooks and filters.** A hook that changes the staged set of paths or modes (reported by `exit 3`); a hook or attribute filter that changes a file's content or the commit message (not detected).

**Out-of-scope synthetic extremes**, declined explicitly:

1. A `GIT_CONFIG_PARAMETERS` carrying only `safe.directory` entries: still refused; no narrow acceptance is added (operator ruling kept).
2. Several refused variables set at once: the first in loop order is reported, as before; no combined message.
3. Machine parsing of `--help` output or of the refusal line beyond the fixed prefix `team-commit: refused (environment): <VAR> is set`.
4. Case aliases other than a leading directory differing only in ASCII letter case (Unicode normalisation, case-variant duplicates within one request): no new statement.
5. Whether the Codex CLI host's environment exports `GIT_CONFIG_PARAMETERS`: not measured, not stated.

<!-- END intent-block: T-1171 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | `GIT_CONFIG_PARAMETERS` still refused, exit 2, own remedy line naming `unset GIT_CONFIG_PARAMETERS` (decision 1) | **AC1** |
| 2 | The other eleven refusal texts unchanged byte for byte (decision 1, coordinating decision 1) | **AC1** |
| 3 | `--help` names the remedy (decision 1) | **AC1** |
| 4 | Suite's `ref-env-config-parameters` asserts the remedy (decision 1) | **AC3** |
| 5 | Guides' remedy sentence, measured claim only, no claim about other hosts (decision 2) | **AC2** (tokens + review-judged) |
| 6 | `.git` statement separate; T-1169 AC13/AC14 tokens kept (decision 3) | **AC4** |
| 7 | Guides' hook sentence narrowed, filters named (decision 4) | **AC5** |
| 8 | Help hook sentence narrowed (decision 4, droppable) | **AC6** |
| 9 | Case-insensitive outcome stated in both guides (decision 5) | **AC7** |
| 10 | No #666 refusal and no fixture; T-1169 spec unchanged (decision 5, Non-goals) | **AC10** (T-1169 records locked; the suite is an allowed path, so "no new fixture" is review-judged against the diff) |
| 11 | Step 10 names `code-reviewer`; T-1170 AC5 tokens kept (decision 6) | **AC8** |
| 12 | EN rewritten lines within 80 bytes; the two over-wide base lines gone (decision 7) | **AC9** |
| 13 | No change to refused variables, `GIT_CONFIG_COUNT` handling or commit logic (Non-goals) | **AC1**, **AC11** (existing suite cases stay green) |
| 14 | No other file changes (Non-goals) | **AC10** |
| 15 | No Codex-environment re-measurement or claim (Non-goals) | **AC2** (review-judged) |
| 16 | No push, merge or release (Non-goals) | info-only (not promoted to AC) — loop actions, not a property of the diff |
| 17 | No recursive delete in check lines or run suites (AC preamble) | **AC3**, **AC11** (grep gates) |
| 18 | Spec declarations and board conformant | **AC12** |
| 19 | Pre-commitment drop order (Goal) | info-only (not promoted to AC) — a disposition for the loop to execute, not a property of the diff |

## Shipped-docs inventory

| Document | Where | Disposition |
|---|---|---|
| `docs/adopting.md` | step 6 (`:571`–`:615`), step 10 (`:668`–`:704`) | this-task (**AC2**, **AC4**, **AC5**, **AC7**–**AC9**) |
| `docs/adopting.ja.md` | 手順 6 (`:573`–`:616`), 手順 10 (`:666`–`:699`) | this-task (**AC2**, **AC4**, **AC5**, **AC7**, **AC8**) |

`README.md` / `README.ja.md` `:210` say only that the script commits exactly the named paths and is the one commit command on the Codex CLI host; nothing this task changes makes that wrong, so neither carries a shipped-docs line and both stay unchanged (**AC10**). `bin/team-commit.sh`'s `--help` text is the script's own output, covered by **AC1** and **AC6**, not a shipped document. `.shell-team/test-recipe.md` `:2668`–`:2671` ("a hand-run still needs `unset GIT_CONFIG_PARAMETERS`") stays true. `CHANGELOG.md` is the release step's.

## Version derivation note

Premise (relayed from the Routing Map): PATCH. Headline test: not met — nothing new becomes possible; the refusal gains a remedy and the guides' wording is corrected. Default-reachability: met — every Codex CLI adopter reads steps 6 and 10, and every operator whose environment exports `GIT_CONFIG_PARAMETERS` meets the refusal. Derived: PATCH. Verdict: match.

## Assumptions

- **Relayed (#664, primary confirmation on the coordinating side):** the Codex CLI host does not export `GIT_CONFIG_PARAMETERS` (4 + 6 approved invocations succeeded in sprints C and D). Not stated in shipped text (decision 2); recorded only as why the remedy is a convenience on that host rather than a blocker.
- **Relayed (#666; QA re-measures):** plain git gives the same outcome on a case-insensitive filesystem (`core.ignorecase=true`): with `a` committed, moved away, `A/b.txt` created, `git add -- A/b.txt && git commit` exits `0` and HEAD lists `A/b.txt` and `a`. Only needed if a guide's statement compares with plain git (**AC7**, review-judged).
- **Relayed:** the issue bodies' Observed/Expected text (not supplied; see Problem and Open questions) and the PATCH premise.
- **Measured here (read):** `.shell-team/test-recipe.md` `:2652`–`:2657`, `:2668`–`:2671` record that this repository's Claude Code sandbox exports `GIT_CONFIG_PARAMETERS`; this is the "measured" sandbox decision 2 names.
- **Measured here (read):** the Routing Map's anchors — `bin/team-commit.sh` `:164`–`:171`, `:177`, `:179`/`:181`/`:188`/`:192`, `:93`–`:95`, `:106`–`:109`; `docs/adopting.md` `:590`–`:592`, `:610`–`:615`, `:690`; `docs/adopting.ja.md` `:593`–`:595`, `:612`–`:616`, `:687`; `tests/team-commit/run.sh` `:49`–`:51`, `:119`, `:576`, `:577`–`:585`, `:780`–`:794`; CI `:396`–`:397` — all match what this role opened. The help's refused-variable list starts at `:89`; the JA `.git` sentence spans `:592`–`:595`.
- The next task id is T-1171: no `T-1171`–`T-1179` string occurs under `.shell-team/` (this role's search); the board's highest is T-1170.
- **Count premises at the base (this role's reading; the freeze run measures each live at `593f2522`, all own-coinage or ordinary words rather than another document's vocabulary):** in EN step 6, `GIT_CONFIG_PARAMETERS`, `hooks path`, `Claude Code sandbox`, `filter`, `content`, `case-insensitive`, `A/b.txt` each occur 0 times, and `entirely, since` and `may change the commit after that check` once each (joined); in JA step 6, `GIT_CONFIG_PARAMETERS`, `filter`, `メッセージ`, `大文字`, `A/b.txt` 0 times, and `必要とするため` and `確認の後に commit を変えることがある` once each (joined); `unset GIT_CONFIG_PARAMETERS` 0 times in `bin/team-commit.sh` and its joined `--help`; `filter`, `content` 0 times and `may change the commit after the first check` once in joined `--help`; `Its .APPROVE. reaches` once in joined EN step 10 and once in the whole EN file; `その .APPROVE. は` once in joined JA step 10. So **AC1**–**AC9** are each red at base; **AC10**–**AC12** are green at base.
- **Borrowed-vocabulary sweep:** the only borrowed tokens are T-1169 **AC13**/**AC14**'s and T-1170 **AC5**'s step tokens, which **AC4** and **AC8** assert present (not `= 0`); `only a role's own commit needs` and `役割自身の commit だけが` are asserted absent and are absent at base by this role's reading of the two step-6 regions. The freeze run measures them.
- **AC10** handles a tracked symlink by comparing its target text; the freeze run notes whether any exists under the seven directories.
- **AC11**'s derived suites: whether any contains a recursive delete is measured by the freeze run (this role cannot run `git grep`); a match makes **AC11** red without running that suite, which then needs a decision before freeze.
- Downstream impact on merged specs is judged by CI and this task's own check lines, not by re-running past specs' check lines (operator ruling, A2 / delete-guardrail). By reading, T-1169 **AC3** (`GIT_CONFIG_PARAMETERS=$R/.git` → exit `2`), **AC13**, **AC14** and T-1170 **AC5** stay satisfiable; **AC4** and **AC8** here assert their step tokens.

## Open questions

- Resolved before the freeze (coordinating session, 2026-10-04): the four issue bodies are pasted verbatim into `## Problem`, with an Expected-to-criteria trace; the only narrowing is #666's placement of the accepted-outcome statement in shipped prose instead of the frozen T-1169 record, chosen at sprint planning.

## Notes for engineer

- Files touched: `bin/team-commit.sh` (the `GIT_CONFIG_PARAMETERS` refusal, `--help` `:89`–`:95` and `:106`–`:109`), `tests/team-commit/run.sh` (extend `ref-env-config-parameters` at `:576`), `docs/adopting.md` and `docs/adopting.ja.md` (step 6 and step 10).
- **Refusal (AC1).** Take `GIT_CONFIG_PARAMETERS` out of the shared loop's text (or special-case it) so the other eleven keep `"$v is set; it redirects the repository, index or pathspec semantics"` byte for byte, and give it its own line, following the `COUNT_REMEDY` precedent at `:177`. Spell the literal `unset GIT_CONFIG_PARAMETERS` in the source: **AC3** replaces that literal in a scratch copy and expects the suite to fail. Suggested text: `GIT_CONFIG_PARAMETERS is set; it can carry arbitrary git configuration (a hooks path, for example), so it is refused; unset GIT_CONFIG_PARAMETERS for this invocation and re-run`. One line. Still refused for any value, including empty; still before any git call.
- **Suite (AC3).** Extend `ref-env-config-parameters` like `ref-env-config-count-other` (`:577`–`:586`): after `assert_ref_env`, require `grep -qF 'unset GIT_CONFIG_PARAMETERS'` on `$ERR`, and on failure call `fail "ref-env-config-parameters: ..."` so the line begins `FAIL: ref-env-config-parameters`. No case-fold fixture (#666 is docs only).
- **Help (AC1, AC6).** Name the `GIT_CONFIG_PARAMETERS` remedy beside the `GIT_CONFIG_COUNT` one. Replace "A repository's own hook may change the commit after the first check" with the narrowed statement (hook or filter; a changed set of paths or modes is reported by exit 3; content or message changes are not detected); it must contain `filter` and `content`. You may align the code comment at `:39`–`:41` the same way (not required).
- **Guides, step 6.** EN and JA, equivalent content. (a) Make the `.git` statement its own sentence, e.g. "...avoids the `.codex` refusal entirely. Only a role's or the orchestrator's own commit needs `.git` write access." — keep `orchestrator's own commit` and `orchestrator 自身の commit` intact on one physical line, and do not write `only a role's own commit needs` or `役割自身の commit だけが` (T-1169 **AC13**/**AC14**). JA: drop the `必要とするため` reason clause. (b) Narrow the hook sentence; keep `exit 3` and `concurrent` / `同時` on one physical line each; write `filter` in ASCII in JA too (as `hook` already is); EN must name `content`, JA `メッセージ`. (c) After the `GIT_CONFIG_COUNT` sentence, add the `GIT_CONFIG_PARAMETERS` sentence (decision 2); EN must contain `hooks path` and `Claude Code sandbox`; in JA keep `unset GIT_CONFIG_PARAMETERS` on one physical line (JA joins lines with nothing, so a break inside it breaks the token). Do not name `.shell-team/test-recipe.md` in the guide (it is this repository's file, not the adopter's); "measured in this plugin's own repository" suffices. (d) Add the case-fold sentence (decision 5) with the example `A/b.txt` and, in JA, `大文字`.
- **Guides, step 10.** Rewrite "Its `APPROVE` reaches `READY_FOR_MERGE` — both gates green — without either host ever leaving the Codex CLI session" so it names `code-reviewer` (e.g. "`code-reviewer`'s `APPROVE` reaches ..."), keep `leaving the Codex CLI session` within that sentence, and do not put `. ` inside it. JA: replace 「その `APPROVE` は」 with e.g. 「`code-reviewer` の `APPROVE` は」, keeping `READY_FOR_MERGE` in that sentence. Keep T-1170's step-10 tokens.
- **Wrap (AC9).** Every EN line you add or rewrite is at most 80 bytes (an em dash is 3 bytes); match the surrounding ~76-column wrap. Lines you leave untouched are not measured. JA wrap is not measured.
- No `agents/*`, `templates/*` or `skills/*` change, so `.codex/agents/` needs no regeneration and `check-prompt-sync` is unaffected.
- Measured-at-ref command check: not applicable — no deliverable prints a command beside a `measured at <ref>` label.
- Recursive deletion: none in any file you write or any check line here. Leave temp files under `$TMPDIR`. Run the suite and any mutation self-check with `ulimit -f` and capped output, stopping the whole process group on timeout.
