# codex-capture's completed-run gate refuses an unterminated string, and a backslash-u-escaped depth-1 key counts toward the duplicated-`type` rule in both extractors

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1196

## Problem

T-1193 (#759) made `bin/codex-capture.sh`'s model extraction fail closed on an unterminated string and on a duplicated top-level `type`, and T-1195 copied that logic into the effort extraction. It deliberately left two neighbouring surfaces alone.

- **The completed-run gate (T-1152).** It decides whether a published rollout shows a completed run. Its tokenizer pushes a string with no closing quote as an ordinary token, and its quote-stripping helper drops the last byte without checking that it is a quote. A damaged line can therefore be counted as a completed `CommandExecution` or a `task_complete` record. A gate that cannot parse its input should refuse, not guess.
- **The duplicated-`type` rule.** Both extractors compare key text as written. A `type` key spelled with a backslash-u escape (`"<BS>u0074ype"`, where `<BS>` stands for one literal backslash throughout this spec) never matches `type`, so a record carrying it beside a plain `type` is not detected as a duplicate. Under `--observe`, a record whose plain `type` names an unread kind and whose escaped `type` names a read kind is silently skipped. A later well-formed line then establishes a value instead of the observation being `malformed`.

The Codex CLI writes neither shape. This task is about the checker's fail-closed contract, not about a live exposure.

## Summarized sources

- **Issue #760 body.** It was relayed verbatim in essentials by the coordinating session. This role cannot open the tracker, so the freeze run confirms it (see Assumptions). The distinctions carried over:
  - Surface 1: the completed-run gate's tokenizer pushes an unterminated string as a normal token, and `strip_quotes` drops the last byte unchecked. "The gate decides whether a capture shows a completed run, so it should refuse what it cannot parse."
  - Surface 2: "A `type` key spelled with a `\u` escape next to a plain `type` key is not detected as a duplicate by the #759 rule, which compares the decoded-as-written key text."
  - "Neither shape is written by the Codex CLI; this is about the checker's fail-closed contract."
  - Expected:
    - "an unterminated string in a line the completed-run gate reads makes the gate refuse (no canonical publish)";
    - "a `\u`-escaped `type` key counts toward the duplicated-`type` rule";
    - "fixtures in `tests/codex-skeleton-hygiene` cover both";
    - "existing cases stay green".

  Restated by the Goal sentence, D1–D5, Non-goals, **AC1**–**AC6** and Input space.
- **`bin/codex-capture.sh` at `f80d97e1`** (the T-1195 branch tip, which this branch starts from). This role read it with the Read tool.
  - `:155-188`: the exit codes. The `3` item (`:166-184`) names `rollout not parseable` with `cause=unicode-escape` and says those causes are `--publish`-only.
  - `:201-206`: the T-1193 model rule (an unterminated string, or the depth-1 `type` key more than once, on a read line).
  - `:232-234`: the same rule for the effort reader.
  - `:320-435`: `extract_model`.
    - `:343-381`: a tokenizer that tracks `closed` and `unterm`.
    - `:385`: the prefilter, which admits any line carrying `model` or a backslash-u.
    - `:396`: `key_u` is set for any escaped key.
    - `:398`: `ntype` counts a depth-1 key only when its text is exactly `type`.
    - `:416`: `ntype > 1` makes the line malformed.
    - `:417-418`: `key_u` is malformed only on a line whose plain `type` is `session_meta` or `turn_context`.
  - `:472-583`: `extract_effort`, with the same discipline.
    - `:536`: the prefilter, `effort` or a backslash-u.
    - `:544`: `key_u`.
    - `:546`: `ntype`.
    - `:550`: `payload_type`, read at depth 2 under `payload`.
    - `:564`: `ntype > 1` is malformed.
    - `:565-566`: `key_u` is malformed only on a read record.
  - `:911-922`: `--thread-id` imports the rollout, then the structural check. That check exits `3` with no message when no line is a `{…}` object carrying `"type"`.
  - `:936-1071`: the completed-run gate. It runs only on `--publish` with `--thread-id`.
    - `:942-944`: `strip_quotes`, which checks neither end.
    - `:963-998`: `tokenize`, which has no closed tracking. `:981` pushes an unclosed string as a token.
    - `:1000`: every line is tokenized.
    - `:1012`: any key containing a backslash-u sets `g_unicode_bad`.
    - `:1016`: so does a `type` value containing one.
    - `:1053`: `UNICODE_ESCAPE` is printed.
    - `:1057-1058`: the refusal `publish: rollout not parseable (thread=… cause=unicode-escape)`, exit `3`.
    - `:1067-1069`: `review did not run`.
  - `:1078-1085`: the model and effort gates run after the completed-run gate. `--observe` runs neither the import check nor the completed-run gate.

  Restated by D1–D4, Non-goals, **AC1**–**AC5**, **AC8** and Input space.
- **`tests/codex-skeleton-hygiene/run.sh` at `f80d97e1`:**
  - `:1942-1950`: the T-1192 record builders (`T1192_CE`, `T1192_TC`, `t1192_sm`, `t1192_tl`).
  - `:1982-1997`: `t1192_pub`, a publish with `--thread-id`.
  - `:2135-2227`: the T-1193 block.
    - `:2149-2157`: `u1`–`u9`, the unterminated fixtures.
    - `:2202-2218`: `t1193_four`. Its publish-named path expects `model not established`/`cause=malformed`, and its report-only publish expects exit `0` with ` model=unavailable` (`:2211-2215`). Its two observe paths are at `:2206-2210` and `:2216-2217`.
    - `:2220`: the label `T-1193 unterminated string: … malformed on publish-named, observe-named and both report-only paths`.
  - `:2229-2257`: the T-1193 mutation probes. Probes `:2244-2249` (`u1`, `u7`, `u9`) publish and fail only on "exit 3 with `cause=malformed`".
  - `:2304-2501`: the T-1195 block.
    - `:2319`, `:2339`: `T1195_UT` and fixture `f10`, an unterminated `turn_context` line with no `model` bytes.
    - `:2366-2371`: a positive control that publishes every fixture, `f10` included, expecting exit `0`.
    - `:2384`: the `f10` publish refusal, expecting `effort not established`/`cause=malformed`.
    - `:2481-2482`: the `no-unterm` probe on `f10`, a publish.
  - **No suite in `tests/` contains `unicode-escape`, `not parseable` or `review did not run`** (Grep tool over `tests/`). The completed-run gate's refusals have no fixture of their own; T-1152's checks lived in its spec.

  Restated by D4, D5, **AC6**, **AC7** and Notes for engineer.
- **`.shell-team/specs/T-1193-capture-extraction-fail-closed.md`** (frozen, not edited). Its Non-goal (D-d) left the completed-run gate unchanged and named a follow-up, which is this task. Its Input-space out-of-scope 2 disclosed the escaped-`type` residual for that follow-up. **AC1** asserts publish-named `model not established` and report-only publish exit `0` on `u1`–`u9`. Restated by Blast radius.
- **`.shell-team/specs/T-1195-codex-review-effort-pin.md`** (frozen, not edited). **AC1** asserts that HEAD publishes `f10` with `--expect-effort zq-eff-a` and refuses it as `effort not established`/`cause=malformed`. Restated by Blast radius.
- **The shipped prose that describes the publish exit `3`.** Read by this role for the shipped-docs inventory.
  - `agents/code-reviewer.md:265` and `agents/drift-evaluator.md:158`: "A `publish` that exits `3` means either … `review did not run` or … `model not established` or … `effort not established` — quote the script's stderr line verbatim", then stop `BLOCKED`, or report a precondition failure.
  - `skills/run/SKILL.md:274` and `templates/prompt-blocks/alternate-executor-invocation.md:42`: "A publish that exits `3` means `review did not run`: quote the script's stderr line verbatim and stop".
  - `agents/code-reviewer.md:48`, `:50`, `agents/drift-evaluator.md:85`, `:87`, `docs/adopting.md:322-337` and `docs/adopting.ja.md:326-335`: these name the model and effort gates' cause sets (`absent | inconsistent | malformed | mismatch`) and no completed-run-gate cause.
  - Outside `.shell-team/`, a Grep for `review did not run|not parseable|unicode-escape` names exactly these files: `bin/codex-capture.sh`, `agents/code-reviewer.md`, `agents/drift-evaluator.md`, `skills/run/SKILL.md`, `templates/prompt-blocks/alternate-executor-invocation.md`, `CHANGELOG.md` and `CHANGELOG.ja.md`. The last two are release history.

  Restated by the shipped-docs inventory and Non-goals.
- **`.gitignore:17-19`**: `.shell-team/reviews/*.txt`, `*.json` and `*.jsonl` are ignored. Restated by **AC13** and Assumptions.
- **`.github/workflows/check-handoff.yml`**: the steps `shellcheck` (`:28`), `Run codex-skeleton-hygiene suite` (`:268`), `Run codex-agents fixture suite` (`:388`) and `Run bin-help suite` (`:402`). Restated by **AC14**.
- **`bin/check-interventions.sh:8`**: `<base>/interventions/<task-id>.md`, or `no-task.md`. Restated by **AC11**.
- **`CONTRIBUTING.md`** `## What a version number encodes` (`:135`) and `## Cutting a release` (`:114`). Restated by `## Version` and the Non-goals CHANGELOG line.

## Goal

<!-- BEGIN intent-block: T-1196 -->

- user-visible: yes — `codex-capture.sh --help` changes: its exit-code `3` item names the new `cause=unterminated-string`, and its header describes the escaped-key rule. A `--publish --thread-id` of a rollout carrying an unterminated string now refuses (exit `3`, nothing published) where it used to publish. `--observe` of a rollout carrying a backslash-u-escaped depth-1 key beside a plain `type` now reports `malformed` where it used to establish a value.
- shipped-docs: bin/codex-capture.sh — this-task
- verification-class: mechanism — the diff changes `bin/codex-capture.sh`, a shipped checker, and its fixture suite `tests/codex-skeleton-hygiene/run.sh`.
- verification-ceiling: unit-and-static — **AC1**–**AC12** are settled in a plain checkout. They run the base commit's and HEAD's `codex-capture.sh` on rollouts synthesized under `$TMPDIR`, read `--help`, run the hygiene suite on HEAD and on an extracted copy of HEAD whose script is reverted, run the suites that execute the script, and read the exit codes of shellcheck, `check-adopter-docs.sh` and `check-handoff.sh`. **AC13** is settled at the same level but only in a checkout that holds local review captures, which are gitignored: it runs both scripts over this checkout's captures, and in a checkout with none it exits `1` on its population control. **AC14** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1

**Goal (one sentence).** A `--publish --thread-id` refuses, with exit `3`, nothing published and `publish: rollout not parseable (thread=… cause=unterminated-string)` on stderr, whenever any line of the imported rollout carries a string literal with no closing unescaped quote. That cause takes precedence over `cause=unicode-escape` and over `review did not run`. Under `--observe`, each of `extract_model` and `extract_effort` counts every depth-1 key whose text contains a backslash-u toward its duplicated-`type` rule, so an escaped key beside a plain `type` makes the observation `malformed`. Every rollout carrying neither shape keeps its base outcome byte for byte.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — the gate refuses an unterminated string (coordinator decision D1).**
  - **What counts.** An unterminated string is a string literal whose closing unescaped `"` is not found before the end of the line as read, exactly the T-1193 definition.
    - A CRLF line's trailing carriage return is part of the line, and an escaped `\"` closes nothing.
    - A string in key position counts, and so does a lone trailing `"`.
  - **Where it counts.** Any such string, in any line the gate tokenizes, refuses. The gate tokenizes every line of the imported rollout, so this holds whatever the line's type and whether or not the gate would have counted that line.
  - **How it refuses.** Exit `3`. No canonical file is written, and both raws are removed by the existing EXIT trap. Stderr carries the existing refusal shape with a new cause token: `publish: rollout not parseable (thread=<id> cause=unterminated-string)`. The refusal echoes no byte of the offending line.
  - **How it is decided.** The decision is made while tokenizing (whether the closing quote was found), never from the token's last byte. (**AC1**, **AC3**)
- **D2 — order (coordinator decision D1, ordering left to this role).** When a rollout carries both an unterminated string and a backslash-u escape the gate refuses on, the cause is `unterminated-string`, not `unicode-escape`. The reason: an unterminated string can swallow the rest of its line, so an escape finding made on that line rests on a mis-tokenized line, and the parse failure is the more fundamental one. A rollout carrying an unterminated string and showing no completed run reports `unterminated-string`, not `review did not run`, because the counts behind `review did not run` come from the same unparsed lines. A rollout carrying only an escape still refuses as `cause=unicode-escape` (**AC3**). (**AC2**)
- **D3 — escaped depth-1 keys count toward the duplicated-`type` rule (coordinator decision D2, conservative form).**
  - **The rule.** In both `extract_model` and `extract_effort`, every depth-1 key whose text, as written, contains a backslash-u counts toward the depth-1 `type`-key count, exactly as a plain `type` key does. No escape is decoded.
  - **The consequence.** A line past the extractor's prefilter that carries a plain depth-1 `type` and any escaped depth-1 key (an escaped spelling of `type` or of any other key) has a count of at least 2, and the observation is `malformed`.
  - **Why the conservative form.** It is fail-closed by construction. It needs no decoder that a crafted escape (surrogates, mixed case, partial escapes) could defeat, and it cannot under-count an escaped `type`. Its only over-count is an escaped depth-1 key that decodes to something other than `type`. The record shapes T-1192 and T-1195 measured carry plain ASCII depth-1 keys only (Input space). Whether any real capture carries an escaped depth-1 key is measured by **AC13**, where such a capture would surface as an observe difference.
  - **Scope.** A key at depth 2 or deeper is not counted. `cause=malformed` is reused: the cause set, refusal texts, exit codes and output lines of both gates stay as they are. (**AC4**, **AC5**)
- **D4 — existing assertions whose outcome changes by design (coordinator decision D4).** "Existing cases stay green" means every existing case that carries neither new shape keeps its outcome and its label. The cases below carry a new shape, and their outcome changes by design.
  - The T-1193 publish paths for `u1`–`u9` (`:2204-2205`, publish-named; `:2211-2215`, report-only publish): from `model not established`/`cause=malformed`, and from exit `0` with ` model=unavailable`, to the D1 gate refusal. **Choice:** for `u1`–`u9` they are rewritten to assert the gate refusal, so the nine T-1193 shapes also cover D1 on publish. Their observe paths (`:2206-2210`, `:2216-2217`) keep their assertions, because `--observe` runs no gate. `t1193_four` is shared: `:2221` runs `d1`, `d2`, `d3`, `d5` and `d7` through it, and those duplicated-`type` fixtures keep all four of their T-1193 paths unchanged. So the helper is split (or parameterized) for the `u` fixtures, never edited in place for both. The label at `:2220` describes the publish outcomes and may be reworded, provided it still begins `T-1193 unterminated string:`.
  - The T-1193 probes `:2244-2249` (`no-unterm`/`u1`, `unterm-disabled`/`u7`, `last-byte`/`u9`) would stay green but become vacuous. The gate now refuses those fixtures with a cause other than `malformed`, so "not refused as malformed" holds for any mutant. **Choice:** they move to `--observe`, where `extract_model` is the only refuser. Each keeps a control showing that the unmutated script refuses the fixture with `cause=malformed` on that path.
  - The T-1195 positive control `:2366-2370`, which expects `f10` to publish with exit `0`: `f10` now refuses at the gate. **Choice:** `f10` is asserted as a gate refusal there, or taken out of that loop. The label at `:2371` may be reworded, provided it still begins `T-1195 positive control:`.
  - The T-1195 `f10` publish refusal at `:2384` (`effort not established`/`cause=malformed`): now the gate refusal. **Choice:** the `f10` malformed assertion moves to `--observe` with `--expect-effort zq-eff-a` and no `--expect-model`, where it still expects `effort not established` and `cause=malformed`.
  - The T-1195 `no-unterm` probe on `f10` (`:2481-2482`) would also become vacuous. **Choice:** it moves to `--observe`, with the same kind of control.

  No other base assertion is expected to change. The T-1192 block (`:1930-2134`) carries no unterminated fixture, and the duplicated-`type` fixtures (`d1`–`d7`, `f12`) carry no escaped key. (**AC6**)
- **D5 — the fixture suite.**
  - `tests/codex-skeleton-hygiene/run.sh` gains a T-1196 block, synthesized inline, covering every class in **AC1**, **AC2**, **AC4** and **AC5**.
  - Mutation probes, one per new guard, each break the guard in a scratch copy and are caught by a fixture:
    - the gate's unterminated refusal removed;
    - the gate's closed-quote decision replaced by a last-byte test;
    - the escaped-key count removed from `extract_model` only;
    - the escaped-key count removed from `extract_effort` only.

    The two extractors carry textually identical lines, so the extractor probes are range-scoped to their own function.
  - Every base `pass` label prints, except the two families D4 allows to be reworded, which must still print under their prefix.
  - Reverting only `bin/codex-capture.sh` to the base blob makes the suite fail on a `T-1196` case. (**AC6**, **AC7**)
- **D6 — the header.** The `--help` exit-code `3` item names `unterminated-string` beside `unicode-escape`. The header describes that the gate refuses an unterminated string, and that an escaped depth-1 key counts toward the duplicated-`type` rule of both extractors. (**AC8**)

**Pre-commitment (frozen before round 1).** The trigger and the disposition below are AI self-discipline proposed by the coordinating session, never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning.
  - (N1) D1/D2: the gate's unterminated-string refusal and its precedence (**AC1**, **AC2**).
  - (N2) D3: the escaped depth-1 key count, in both `extract_model` and `extract_effort` (**AC4**, **AC5**).
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same component. A round interrupted before a verdict does not count.
- **Droppable.** None. The one neighbour that could have been dropped, `extract_effort`'s depth-2 `payload.type`, is out of scope from the start (Non-goals; follow-up in Open questions). The remaining components (D4–D6) are ordinary deliverables: a defeat there is reworked in place and is never carved out.

## Non-goals

- **`extract_effort`'s depth-2 `payload.type` is not changed (coordinator decision D3).** A duplicated `payload.type` is not counted. An escaped `payload` or `type` key at depth 2 leaves the record unread rather than making it malformed. Both stay as they are. The coordinating session files a follow-up issue (title and body in Open questions). (info-only; Input space out-of-scope 3)
- **`--observe` gains no completed-run gate.** The gate stays `--publish`-only. An unterminated string in a line neither extractor reads stays unjudged on `--observe`. (**AC3**, observe identity)
- **No escape decoding.** Neither extractor nor the gate decodes a backslash-u. A lone escaped `type` key with no plain `type` beside it leaves its record unread, as at the base, and is neither required nor forbidden to refuse. (info-only; Input space out-of-scope 2)
- **No new cause token on the extractors and no exit-code change.** The model and effort gates keep `absent | inconsistent | malformed | mismatch`, and the gate keeps exit `3`. (**AC4**, **AC5**, **AC1**)
- **No change to the gate's other refusals.** `unicode-escape` and `review did not run` keep their conditions and texts on rollouts without an unterminated string. (**AC3**)
- **No agent-prose or adopter-doc edit.** Per the shipped-docs inventory below, every shipped sentence about a publish exit `3` either names no gate cause or treats any exit `3` as a stop with the stderr line quoted verbatim. Both stay accurate. (**AC11**)
- **No general JSON validation.** Unbalanced braces, bytes outside strings and invalid escapes other than backslash-u stay outside what the gate judges. (info-only; Input space out-of-scope 4)
- **No fixture files.** Fixtures are synthesized inline in `tests/codex-skeleton-hygiene/run.sh`. (**AC11**)
- **No CHANGELOG entry.** It is written at release prep (`CONTRIBUTING.md`, `## Cutting a release`). (**AC11**)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** This follows the operator rulings relayed in T-1191 to T-1195's specs. CI and this task's own check lines decide the impact. (info-only; disclosed in Blast radius)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`, export a temp `HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and unset `TEAM_RUN_BASE`, `CODEX_HOME` and `CODEX_THREAD_ID`.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion. Temp directories are left in `$TMPDIR`.
- **Base reads.** Lines that read a base blob resolve `B` with the declaration region's discriminator expression, spelled byte-identically in **AC1**–**AC8**, **AC11** and **AC13**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Fixtures** are synthesized in the T-1192/T-1195 record shapes and never copied from a real rollout.
  - The placeholders `zq-model-1`/`zq-model-2` and `zq-eff-a`/`zq-eff-b` name no real model or effort.
  - The canary `zqcanary` sits inside every unterminated string, so an echoed line is detectable.
  - In prose, `<BS>` stands for one literal backslash: `"<BS>u0074ype"` is the key `type` with its first letter written as a backslash-u escape. The check lines build the backslash with `printf '\134'`.
  - A literal backslash and carriage return are built with `printf '\134'` and `printf '\015'`, and every fixture needing one is checked for it.
- **Suite runs** go through `tms`: own process group, 1200 s, killed on timeout. Each suite is first scanned for a recursive-deletion pattern, with backslash-continued lines joined.

- [ ] **AC1** (D1; N1.) The gate refuses an unterminated string. Each fixture is a well-formed `session_meta` (model `zq-model-1`), the damaged line, then a completed `CommandExecution` and a `task_complete` record, except where stated. No damaged line carries the bytes `model` or `effort`, so neither extractor would refuse it.
  - `g1`: a value ending at end of line, `"text":"zqcanary`.
  - `g2`: the same ending in a backslash.
  - `g3`: the same ending in an escaped quote, `"zqcanary\"`.
  - `g4`: an unterminated key after a complete payload, `…},"zqcanary`.
  - `g5`: `g1` with a CRLF line end.
  - `g6`: a complete record followed by a lone `"`.
  - `g7`: the counted `CommandExecution` line itself, truncated inside `aggregated_output` after `"exit_code":0`, then `task_complete`.
  - `g8`: the `task_complete` line itself, truncated inside `last_agent_message`, after a complete `CommandExecution`.

  **Positive control** (the defect exists at the base): the base commit's script publishes every fixture with exit `0` (report-only). **At HEAD**, each fixture refuses on both `--publish --thread-id <id>` and `--publish --thread-id <id> --expect-model zq-model-1 --expect-effort -`. Each refusal exits `3`, its stderr contains `rollout not parseable` and `cause=unterminated-string`, the reviews dir is empty afterwards, and `zqcanary` is not on stderr.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; NP='{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"zqcanary'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; cr=$(printf '\015'); test "${#cr}" = 1 || exit 1; mk(){ local f="$1" l; shift; { printf '%s\n' "$SM"; for l in "$@"; do printf '%s\n' "$l"; done; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$f"; }; mr(){ local f="$1" l; shift; for l in "$@"; do printf '%s\n' "$l"; done > "$T/$f"; }; mk g1 "$NP" || exit 1; mk g2 "$NP$bs" || exit 1; mk g3 "$NP$bs\"" || exit 1; mk g4 '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"ok"},"zqcanary' || exit 1; mk g5 "$NP$cr" || exit 1; mk g6 '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"zqcanary"}}"' || exit 1; mr g7 "$SM" '{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"zqcanary' "$TC" || exit 1; mr g8 "$SM" "$CE" '{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":"zqcanary' || exit 1; grep -qF "zqcanary$bs" "$T/g2" || exit 1; grep -qF "zqcanary$bs\"" "$T/g3" || exit 1; test "$(grep -c "$cr" "$T/g5")" = 1 || exit 1; for f in g1 g2 g3 g4 g5 g6 g7 g8; do grep -F zqcanary "$T/$f" > "$T/dl" || exit 1; grep -qE 'model|effort' "$T/dl"; test "$?" = 1 || exit 1; done; n=0; pc(){ local src="$1" o j; shift; n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" "$T/rv$n" || return 97; cp "$T/$src" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$n" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch$n"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$n" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; nz(){ grep -qF zqcanary "$T/pe"; test "$?" = 1; }; ref(){ test "$1" = 3 && grep -qF 'rollout not parseable' "$T/pe" && grep -qF cause=unterminated-string "$T/pe" && nz && test -z "$(ls -A "$T/rv$n")"; }; S="$T/base.sh"; for f in g1 g2 g3 g4 g5 g6 g7 g8; do pc "$f"; test "$?" = 0 || exit 1; done; S="$X"; for f in g1 g2 g3 g4 g5 g6 g7 g8; do pc "$f"; s=$?; ref "$s" || { rc=1; printf 'not refused (report-only): %s\n' "$f"; }; pc "$f" --expect-model zq-model-1 --expect-effort -; s=$?; ref "$s" || { rc=1; printf 'not refused (named model): %s\n' "$f"; }; done; test "$rc" -eq 0

- [ ] **AC2** (D2; N1.) Order.
  - `o1`: a `session_meta`, a complete `CommandExecution`, then `g1`'s damaged line, with no `task_complete`.
  - `o2`: a `session_meta`, an `event_msg` whose depth-2 key is spelled `t<BS>u0065xt`, `g1`'s damaged line, then the two completion records.

  **Positive control**: the base commit's script refuses `o1` with exit `3` and `review did not run`, and `o2` with exit `3` and `cause=unicode-escape`. **At HEAD**, both exit `3` with `rollout not parseable` and `cause=unterminated-string`, with neither `review did not run` nor `unicode-escape` on stderr, and an empty reviews dir.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; NP='{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"zqcanary'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; UE=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","t%su0065xt":"ok"}}' "$bs") || exit 1; grep -qF "t${bs}u0065xt" <<< "$UE" || exit 1; mr(){ local f="$1" l; shift; for l in "$@"; do printf '%s\n' "$l"; done > "$T/$f"; }; mr o1 "$SM" "$CE" "$NP" || exit 1; mr o2 "$SM" "$UE" "$NP" "$CE" "$TC" || exit 1; n=0; pc(){ local src="$1" o j; shift; n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" "$T/rv$n" || return 97; cp "$T/$src" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$n" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch$n"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$n" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; S="$T/base.sh"; pc o1; test "$?" = 3 || exit 1; grep -qF 'review did not run' "$T/pe" || exit 1; pc o2; test "$?" = 3 || exit 1; grep -qF cause=unicode-escape "$T/pe" || exit 1; S="$X"; for f in o1 o2; do pc "$f"; s=$?; test "$s" = 3 || rc=1; grep -qF 'rollout not parseable' "$T/pe" || rc=1; grep -qF cause=unterminated-string "$T/pe" || rc=1; grep -qE 'review did not run|unicode-escape' "$T/pe"; test "$?" = 1 || rc=1; test -z "$(ls -A "$T/rv$n")" || rc=1; done; test "$rc" -eq 0

- [ ] **AC3** (D1, D2, D3; Non-goals.) Rollouts carrying neither new shape keep the base outcome byte for byte, and `--observe` runs no gate.
  - The fixtures:
    - `w1`: a `session_meta` and the two completion records.
    - `w2`: `w1` plus a value ending in an escaped backslash before its closing quote, `"abc\\"`.
    - `w3`: `w1` plus a value with an escaped quote inside it, `"a\"b"`.
    - `w4`: `w1` with a CRLF end on the `session_meta` line.
    - `w5`: `w1` plus `o2`'s escaped depth-2 key and no unterminated string. The gate refuses it as `unicode-escape`. For both extractors it is a depth-2 key on an unread line.
    - `w6`: a `session_meta` and a `CommandExecution` with no `task_complete` (`review did not run`).
  - Each `w` fixture runs four ways, publish and observe each with and without `--expect-model zq-model-1 --expect-effort -`. Each of **AC1**'s `g1`–`g8` runs the two observe ways only.
  - The base script and HEAD's script run on identical inputs, in an identical directory path, under one `CODEX_HOME` per fixture. The reviews dir is renamed with `mv` after each run, and nothing is deleted. Each pair has equal exit status, stdout and stderr, and an identical reviews-dir tree (`diff -r`).
  - Positive controls:
    - HEAD's script differs from the base blob.
    - At HEAD, `w1`–`w4` publish with the expectation and exit `0`.
    - `w5`'s report-only publish stderr carries `cause=unicode-escape`.
    - `w6`'s carries `review did not run`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; cmp -s "$T/base.sh" "$X"; test "$?" = 1 || rc=1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; NP='{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"zqcanary'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; cr=$(printf '\015'); test "${#cr}" = 1 || exit 1; UE=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","t%su0065xt":"ok"}}' "$bs") || exit 1; mk(){ local f="$1" l; shift; { printf '%s\n' "$SM"; for l in "$@"; do printf '%s\n' "$l"; done; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$f"; }; mr(){ local f="$1" l; shift; for l in "$@"; do printf '%s\n' "$l"; done > "$T/$f"; }; mk w1 || exit 1; mk w2 "{\"timestamp\":\"2026-11-21T00:00:01Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_reasoning\",\"text\":\"abc$bs$bs\"}}" || exit 1; mk w3 "{\"timestamp\":\"2026-11-21T00:00:01Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_reasoning\",\"text\":\"a$bs\"b\"}}" || exit 1; mr w4 "$SM$cr" "$CE" "$TC" || exit 1; mk w5 "$UE" || exit 1; mr w6 "$SM" "$CE" || exit 1; grep -qF "abc$bs$bs\"" "$T/w2" || exit 1; grep -qF "a$bs\"b" "$T/w3" || exit 1; test "$(grep -c "$cr" "$T/w4")" = 1 || exit 1; mk g1 "$NP" || exit 1; mk g2 "$NP$bs" || exit 1; mk g3 "$NP$bs\"" || exit 1; mk g4 '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"ok"},"zqcanary' || exit 1; mk g5 "$NP$cr" || exit 1; mk g6 '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"agent_reasoning","text":"zqcanary"}}"' || exit 1; mr g7 "$SM" '{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"zqcanary' "$TC" || exit 1; mr g8 "$SM" "$CE" '{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":"zqcanary' || exit 1; run(){ local f="$1" md="$2" t="$1-$2-$3" o j r; mkdir -p "$T/w" || return 97; set --; case "$md" in p?) bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/w" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; set -- --publish --stem T-000-codex-primary --reviews-dir "$T/w" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I";; *) set -- --observe --thread-id "$I";; esac; case "$md" in ?e) set -- "$@" --expect-model zq-model-1 --expect-effort -;; esac; ( export CODEX_HOME="$T/ch-$f"; cd "$T/oc" || exit 97; exec bash "$S" "$@" ) < /dev/null > "$T/o-$t" 2> "$T/e-$t"; r=$?; printf '%s\n' "$r" > "$T/rc-$t" || return 97; mv "$T/w" "$T/w-$t" || return 97; }; same(){ test "$(cat "$T/rc-$1-b")" = "$(cat "$T/rc-$1-h")" && cmp -s "$T/o-$1-b" "$T/o-$1-h" && cmp -s "$T/e-$1-b" "$T/e-$1-h" && diff -r "$T/w-$1-b" "$T/w-$1-h" > /dev/null; }; k=0; for f in w1 w2 w3 w4 w5 w6 g1 g2 g3 g4 g5 g6 g7 g8; do k=$((k + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$k"); mkdir -p "$T/ch-$f/sessions/2026/11/21" || exit 1; cp "$T/$f" "$T/ch-$f/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || exit 1; case "$f" in w*) ms="pe pn oe on";; *) ms="oe on";; esac; for md in $ms; do S="$T/base.sh"; run "$f" "$md" b || exit 1; S="$X"; run "$f" "$md" h || exit 1; same "$f-$md" || { rc=1; printf 'differs %s %s\n' "$f" "$md"; }; done; done; for f in w1 w2 w3 w4; do test "$(cat "$T/rc-$f-pe-h")" = 0 || rc=1; done; grep -qF cause=unicode-escape "$T/e-w5-pn-h" || rc=1; grep -qF 'review did not run' "$T/e-w6-pn-h" || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D3; N2.) `extract_model` counts escaped depth-1 keys, exercised on `--observe`, since the gate already refuses any escaped key on publish. Each fixture is a well-formed `session_meta` carrying `zq-model-1`, the line listed (carrying `zq-model-2` unless stated), and the two completion records.
  - `e1`: `"<BS>u0074ype":"session_meta"` before a plain `"type":"other"`.
  - `e2`: a plain `"type":"other"` before `"typ<BS>u0065":"session_meta"`.
  - `e3`: `"t<BS>u0079pe":"session_meta"` before a plain `"type":"other"`.
  - `e4`: an escaped non-`type` depth-1 key, `"ti<BS>u006Destamp"` with an upper-case hex digit, beside a plain `"type":"other"`. This is the conservative form's over-count, pinned on purpose.
  - `e5`: a plain `"type":"session_meta"` before `"<BS>u0074ype":"other"`, carrying `zq-model-1`. It is already malformed at the base (`key_u`) and stays malformed.

  **Positive control**: the base script prints exactly `model=zq-model-1` with exit `0` on `--observe --expect-model zq-model-1` for `e1`–`e4`, and refuses `e5` with exit `3` and `cause=malformed`. **At HEAD**, for each of `e1`–`e5`:
  - `--observe --thread-id <id> --expect-model zq-model-1` exits `3`, with `model not established` and `cause=malformed` on stderr, empty stdout and no `zq-model-2` on stderr;
  - `--observe --thread-id <id>` exits `0` with stdout exactly `model=unavailable`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac4.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; e1=$(printf '{"timestamp":"2026-11-21T00:00:01Z","%su0074ype":"session_meta","type":"other","payload":{"provenance":{"model":"zq-model-2"}}}' "$bs") || exit 1; e2=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"other","typ%su0065":"session_meta","payload":{"provenance":{"model":"zq-model-2"}}}' "$bs") || exit 1; e3=$(printf '{"timestamp":"2026-11-21T00:00:01Z","t%su0079pe":"session_meta","type":"other","payload":{"provenance":{"model":"zq-model-2"}}}' "$bs") || exit 1; e4=$(printf '{"ti%su006Destamp":"2026-11-21T00:00:01Z","type":"other","payload":{"provenance":{"model":"zq-model-2"}}}' "$bs") || exit 1; e5=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"session_meta","%su0074ype":"other","payload":{"provenance":{"model":"zq-model-1"}}}' "$bs") || exit 1; for v in "$e1" "$e2" "$e3" "$e4" "$e5"; do grep -qF "${bs}u00" <<< "$v" || exit 1; done; mk(){ { printf '%s\n%s\n' "$SM" "$2"; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$1"; }; mk e1 "$e1" || exit 1; mk e2 "$e2" || exit 1; mk e3 "$e3" || exit 1; mk e4 "$e4" || exit 1; mk e5 "$e5" || exit 1; n=0; po(){ local src="$1"; shift; n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" || return 97; cp "$T/$src" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; ( export CODEX_HOME="$T/ch$n"; cd "$T/oc" || exit 97; exec bash "$S" --observe --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; S="$T/base.sh"; for f in e1 e2 e3 e4; do po "$f" --expect-model zq-model-1; test "$?" = 0 || exit 1; test "$(cat "$T/po")" = model=zq-model-1 || exit 1; done; po e5 --expect-model zq-model-1; test "$?" = 3 || exit 1; grep -qF cause=malformed "$T/pe" || exit 1; S="$X"; for f in e1 e2 e3 e4 e5; do po "$f" --expect-model zq-model-1; s=$?; test "$s" = 3 || { rc=1; printf 'not refused: %s\n' "$f"; }; grep -qF 'model not established' "$T/pe" || rc=1; grep -qF cause=malformed "$T/pe" || rc=1; test ! -s "$T/po" || rc=1; grep -qF zq-model-2 "$T/pe"; test "$?" = 1 || rc=1; po "$f"; s=$?; test "$s" = 0 || rc=1; test "$(cat "$T/po")" = model=unavailable || { rc=1; printf 'report-only differs: %s\n' "$f"; }; done; test "$rc" -eq 0

- [ ] **AC5** (D3; N2.) `extract_effort` counts escaped depth-1 keys, on `--observe` with no `--expect-model`, so the model gate is report-only and the effort gate is the refuser. Each fixture is a well-formed `session_meta` (`zq-model-1`), the line listed (each carrying `zq-eff-b`), a well-formed `turn_context` carrying `zq-eff-a`, and the two completion records.
  - `x1`: `"<BS>u0074ype":"turn_context"` before a plain `"type":"other"`.
  - `x2`: a plain `"type":"other"` before `"typ<BS>u0065":"turn_context"`.
  - `x3`: the issue's shape, `{"type":"other","<BS>u0074ype":"turn_context","effort":"zq-eff-b"}`.
  - `x4`: a plain `"type":"other"` before `"<BS>u0074ype":"event_msg"`, with a `payload` whose `type` is `thread_settings_applied`.
  - `x5`: an escaped non-`type` depth-1 key, `"ti<BS>u006Destamp"`, beside a plain `"type":"other"`.

  **Positive control**: the base script, on `--observe --expect-effort zq-eff-a`, exits `0` with stdout exactly the two lines `model=zq-model-1` and `effort=zq-eff-a` for each fixture. **At HEAD**, for each of `x1`–`x5`:
  - `--observe --thread-id <id> --expect-effort zq-eff-a` exits `3`, with `effort not established` and `cause=malformed` on stderr, empty stdout and no `zq-eff-b` on stderr;
  - `--observe --thread-id <id> --expect-effort -` exits `0` with stdout exactly `model=unavailable` and `effort=unavailable`. The model line follows from **AC4**'s rule applied to the same line.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac5.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; TX='{"timestamp":"2026-11-21T00:00:02Z","type":"turn_context","payload":{"turn_id":"t1","effort":"zq-eff-a"}}'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; x1=$(printf '{"timestamp":"2026-11-21T00:00:01Z","%su0074ype":"turn_context","type":"other","payload":{"effort":"zq-eff-b"}}' "$bs") || exit 1; x2=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"other","typ%su0065":"turn_context","payload":{"effort":"zq-eff-b"}}' "$bs") || exit 1; x3=$(printf '{"type":"other","%su0074ype":"turn_context","effort":"zq-eff-b"}' "$bs") || exit 1; x4=$(printf '{"timestamp":"2026-11-21T00:00:01Z","type":"other","%su0074ype":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{"reasoning_effort":"zq-eff-b"}}}' "$bs") || exit 1; x5=$(printf '{"ti%su006Destamp":"2026-11-21T00:00:01Z","type":"other","payload":{"effort":"zq-eff-b"}}' "$bs") || exit 1; for v in "$x1" "$x2" "$x3" "$x4" "$x5"; do grep -qF "${bs}u00" <<< "$v" || exit 1; done; mk(){ printf '%s\n%s\n%s\n%s\n%s\n' "$SM" "$2" "$TX" "$CE" "$TC" > "$T/$1"; }; mk x1 "$x1" || exit 1; mk x2 "$x2" || exit 1; mk x3 "$x3" || exit 1; mk x4 "$x4" || exit 1; mk x5 "$x5" || exit 1; n=0; po(){ local src="$1"; shift; n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" || return 97; cp "$T/$src" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; ( export CODEX_HOME="$T/ch$n"; cd "$T/oc" || exit 97; exec bash "$S" --observe --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; OK2=$(printf 'model=zq-model-1\neffort=zq-eff-a'); UN2=$(printf 'model=unavailable\neffort=unavailable'); S="$T/base.sh"; for f in x1 x2 x3 x4 x5; do po "$f" --expect-effort zq-eff-a; test "$?" = 0 || exit 1; test "$(cat "$T/po")" = "$OK2" || exit 1; done; S="$X"; for f in x1 x2 x3 x4 x5; do po "$f" --expect-effort zq-eff-a; s=$?; test "$s" = 3 || { rc=1; printf 'not refused: %s\n' "$f"; }; grep -qF 'effort not established' "$T/pe" || rc=1; grep -qF cause=malformed "$T/pe" || rc=1; test ! -s "$T/po" || rc=1; grep -qF zq-eff-b "$T/pe"; test "$?" = 1 || rc=1; po "$f" --expect-effort -; s=$?; test "$s" = 0 || rc=1; test "$(cat "$T/po")" = "$UN2" || { rc=1; printf 'report-only differs: %s\n' "$f"; }; done; test "$rc" -eq 0

- [ ] **AC6** (D4, D5.) The hygiene suite at HEAD exits `0` under `tms` with no line beginning `FAIL`.
  - Every `pass` label in the base blob of `tests/codex-skeleton-hygiene/run.sh` still prints as `PASS: <label>`. The labels counted are column-0 literal labels without `$`, `"` or a backslash. The set is derived from the base blob at run time and must be non-empty.
  - There are two exceptions, the label families D4 allows to be reworded. A base label beginning `T-1193 unterminated string:` or `T-1195 positive control:` is satisfied by any line beginning `PASS: ` followed by that prefix. Both prefixes must occur in the base label set.
  - At least one line begins `PASS: T-1196 `.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac6.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; S=tests/codex-skeleton-hygiene/run.sh; test -s "$S" || exit 1; git show "$B:$S" > "$T/bs" || exit 1; sed -n 's/^pass "\([^"$\\]*\)"$/\1/p' "$T/bs" > "$T/lab" || exit 1; test -s "$T/lab" || exit 1; grep -q '^T-1193 unterminated string:' "$T/lab" || exit 1; grep -q '^T-1195 positive control:' "$T/lab" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; while IFS= read -r l; do case "$l" in 'T-1193 unterminated string:'*) grep -q '^PASS: T-1193 unterminated string:' "$T/log" || { rc=1; printf 'missing family: %s\n' "$l"; };; 'T-1195 positive control:'*) grep -q '^PASS: T-1195 positive control:' "$T/log" || { rc=1; printf 'missing family: %s\n' "$l"; };; *) grep -qxF "PASS: $l" "$T/log" || { rc=1; printf 'missing: %s\n' "$l"; };; esac; done < "$T/lab"; grep -q '^PASS: T-1196 ' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC7** (D5; N1, N2.) The suite detects a revert.
  - HEAD's committed tree is extracted with `git archive HEAD` into a scratch directory, and only `bin/codex-capture.sh` there is replaced with the base blob.
  - The scratch copy's hygiene suite then exits non-zero, and not by timeout. Its log carries a line beginning `FAIL: T-1196`.
  - Positive control: the replaced script differs from the checkout's `bin/codex-capture.sh`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac7.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/h" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; git archive HEAD > "$T/h.tar" || exit 1; tar -xf "$T/h.tar" -C "$T/h" || exit 1; M="$T/h/tests/codex-skeleton-hygiene/run.sh"; test -s "$M" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/h/bin/codex-capture.sh" || exit 1; test -s "$T/h/bin/codex-capture.sh" || exit 1; cmp -s "$T/h/bin/codex-capture.sh" bin/codex-capture.sh; test "$?" = 1 || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$M" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; tms "$M" "$T/log"; s=$?; test "$s" -ne 0 || rc=1; test "$s" -ne 99 || rc=1; grep -q '^FAIL: T-1196' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC8** (D6.) The `--help` header. The exit-code section is the `--help` output from the line beginning `Exit codes:` to the first empty line. Within it, an item runs from a line beginning `<digit>` plus two spaces to the next such line.
  - **Positive controls at the base.** The base blob's `--help` contains no `unterminated-string`, and its `3` item contains `unicode-escape`. That shows the item extraction reads the intended item.
  - **At HEAD**, `--help` exits `0`, and its `3` item contains both `unterminated-string` and `unicode-escape`.
  - That the header also describes the gate's unterminated-string refusal, D2's order and the escaped-key rule of both extractors is a QA reading item. The wording is free, and a token grep would freeze a vocabulary.
  - adopter-surface: the header of bin/codex-capture.sh, printed by `--help`. Its exit-code `3` item names `cause=unterminated-string` beside `cause=unicode-escape`, and its extraction paragraphs state that an escaped depth-1 key counts toward the duplicated-`type` rule.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac8.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X=bin/codex-capture.sh; test -s "$X" || exit 1; git show "$B:$X" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; sec(){ awk 'index($0, "Exit codes:") == 1 { f = 1 } f && $0 == "" { exit } f' "$1"; }; item(){ awk -v d="$1" 'index($0, d "  ") == 1 { f = 1; print; next } f && $0 ~ /^[0-9]  / { exit } f' "$2"; }; bash "$T/base.sh" --help > "$T/hb" 2>&1 || exit 1; grep -qF unterminated-string "$T/hb"; test "$?" = 1 || exit 1; sec "$T/hb" > "$T/xb"; item 3 "$T/xb" > "$T/b3"; test -s "$T/b3" || exit 1; grep -qF unicode-escape "$T/b3" || exit 1; bash "$X" --help > "$T/h" 2> /dev/null; test "$?" = 0 || rc=1; sec "$T/h" > "$T/x"; item 3 "$T/x" > "$T/i3"; test -s "$T/i3" || rc=1; grep -qF unterminated-string "$T/i3" || rc=1; grep -qF unicode-escape "$T/i3" || rc=1; test "$rc" -eq 0

- [ ] **AC9** (D1, D3; Blast radius.) The other suites that execute `codex-capture.sh` stay green.
  - The set is derived at run time. It is every `tests/*/run.sh` that `grep -l -- codex-capture` names, except the hygiene suite, which **AC6** runs, plus `tests/bin-help/run.sh`, which reaches the script through `git ls-files -- bin/`.
  - Each derived suite is scanned for the recursive-deletion pattern, with backslash-continued lines joined.
    - A suite that matches is never run locally. It is printed as CI-covered, and CI (**AC14**) runs it.
    - A scan that cannot read its suite fails the line.
  - Positive control: the run set contains `tests/codex-agents/run.sh`.
  - Each suite in the run set exits `0` under `tms` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac9.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; grep -l -- codex-capture tests/*/run.sh > "$T/l"; test "$?" = 0 || exit 1; { grep -vxF tests/codex-skeleton-hygiene/run.sh "$T/l"; printf '%s\n' tests/bin-help/run.sh; } | sort -u > "$T/suites"; grep -qxF tests/codex-agents/run.sh "$T/suites" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; : > "$T/run" || exit 1; : > "$T/ci" || exit 1; while IFS= read -r S; do test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; if [ "$g" -eq 0 ]; then printf '%s\n' "$S" >> "$T/ci"; elif [ "$g" -eq 1 ]; then printf '%s\n' "$S" >> "$T/run"; else exit 1; fi; done < "$T/suites"; grep -qxF tests/codex-agents/run.sh "$T/run" || exit 1; while IFS= read -r S; do printf 'CI-covered, not run locally (recursive deletion): %s\n' "$S"; done < "$T/ci"; while IFS= read -r S; do tms "$S" "$T/log"; test "$?" -eq 0 || { rc=1; printf 'suite failed: %s\n' "$S"; }; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; done < "$T/run"; test "$rc" -eq 0

- [ ] **AC10** shellcheck exits `0` on `bin/codex-capture.sh` and `tests/codex-skeleton-hygiene/run.sh`. Neither file matches the recursive-deletion pattern once backslash-continued lines are joined.
  - check: rc=0; export LC_ALL=C; L=(bin/codex-capture.sh tests/codex-skeleton-hygiene/run.sh); for f in "${L[@]}"; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac10.XXXXXX") || exit 1; shellcheck "${L[@]}" > "$T/sc" 2>&1 || rc=1; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e'; for f in "${L[@]}"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || rc=1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC11** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `bin/codex-capture.sh`.
  - **Allowed members.**
    - `bin/codex-capture.sh`.
    - `tests/codex-skeleton-hygiene/run.sh`.
    - This task's records:
      - `.shell-team/specs/T-1196-completed-run-gate-fail-closed.md`;
      - `.shell-team/provenance/T-1196.md`;
      - `.shell-team/interventions/T-1196.md`;
      - `.shell-team/reviews/T-1196.md` and `.shell-team/reviews/T-1196-drift.md`;
      - raw captures `.shell-team/reviews/T-1196-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`, the reserved taskless interventions file (`bin/check-interventions.sh:8`).
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac11.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/codex-capture.sh "$T/s" || rc=1; grep -vxE 'bin/codex-capture\.sh|tests/codex-skeleton-hygiene/run\.sh|\.shell-team/(specs/T-1196-completed-run-gate-fail-closed\.md|provenance/T-1196\.md|interventions/(T-1196|no-task)\.md|reviews/T-1196(-drift)?\.md|reviews/T-1196-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || { rc=1; cat "$T/bad"; }; test "$rc" -eq 0

- [ ] **AC12** Records conformant.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - Positive control: the spec, the checker and the board are each first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac12.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1196-completed-run-gate-fail-closed.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC13** (D1, D3; coordinator QA requirement.) No real capture newly refuses or newly changes its observation.
  - **Subject.** This checkout's own local review captures: every `*codex*.jsonl` file directly under the reviews dir resolved through `bin/team-paths.sh --get reviews`.
  - **Why checkout-local.** These files are gitignored (`.gitignore:19`) and are not tracked (Assumptions), so a fresh clone or CI has none. In such a checkout this line exits `1` on its population control. That is expected, and QA runs it in this checkout.
  - **Method.** Each capture in turn is copied onto one fixed rollout path in a temp `CODEX_HOME` under a synthetic thread id. Both the base script and HEAD's script then run, each arm with its own temp reviews dir reused across captures:
    - `--publish --thread-id <id>` with no expectation;
    - `--observe --thread-id <id> --expect-effort -`.
  - **It fails when** a capture the base publishes with exit `0` does not publish with exit `0` at HEAD, or when the two observe runs differ in exit status or stdout.
  - **Positive controls.** The population is non-empty, and the base publishes at least one capture with exit `0`.
  - **Output.** Only the population count, the base-published count and the basenames of differing captures are printed, from a log capped at 20000 bytes. A capture's content, and the scripts' stderr and stdout, are never printed (captures carry identifiers).
  - **Bounds.** The loop runs in its own process group under `ulimit -f`, killed with its descendants after 3600 s; a timeout fails the line. Its footprint under `$TMPDIR` is one rollout copy plus one canonical pair per arm, overwritten capture by capture.
  - check: rc=0; export LC_ALL=C; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1196-ac13.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; RV=$(bash bin/team-paths.sh --get reviews) || exit 1; test -d "$RV" || exit 1; RV=$(cd "$RV" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; I=00000000-0000-4000-8000-000000000196; mkdir -p "$HOME" "$T/oc" "$T/rvb" "$T/rvh" "$T/ch/sessions/2026/11/21" || exit 1; RF="$T/ch/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl"; if git show-ref --verify --quiet refs/heads/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/heads/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/757-codex-review-effort-pin; then B=$(git merge-base refs/remotes/origin/feature/757-codex-review-effort-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; for f in "$RV"/*codex*.jsonl; do if [ -f "$f" ]; then printf '%s\n' "$f"; fi; done > "$T/pop"; test -s "$T/pop" || exit 1; body(){ local f n=0 k=0 s S o j b; while IFS= read -r f; do n=$((n + 1)); cp "$f" "$RF" || return 97; for s in b h; do if [ "$s" = b ]; then S="$T/base.sh"; else S="$X"; fi; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$s" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$s" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" ) < /dev/null > /dev/null 2>&1; printf '%s\n' "$?" > "$T/p$s"; ( export CODEX_HOME="$T/ch"; cd "$T/oc" || exit 97; exec bash "$S" --observe --thread-id "$I" --expect-effort - ) < /dev/null > "$T/o$s" 2> /dev/null; printf '%s\n' "$?" > "$T/q$s"; done; b=${f##*/}; if [ "$(cat "$T/pb")" = 0 ]; then k=$((k + 1)); if [ "$(cat "$T/ph")" != 0 ]; then printf 'newly refused on publish: %s\n' "$b"; fi; fi; if ! cmp -s "$T/qb" "$T/qh" || ! cmp -s "$T/ob" "$T/oh"; then printf 'observe differs: %s\n' "$b"; fi; done < "$T/pop"; printf 'population: %s\n' "$n"; printf 'base-published: %s\n' "$k"; }; set -m; ( ulimit -f 400000; body ) > "$T/log" 2>&1 & p=$!; ( sleep 3600; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; kk=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; head -c 20000 "$T/log"; test "$kk" = 0 || exit 1; test "$r" = 0 || exit 1; grep -qE '^(newly refused on publish|observe differs): ' "$T/log"; test "$?" = 1 || rc=1; grep -qE '^base-published: [1-9]' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC14** CI on the pull request is green, including the `shellcheck` step and the `Run codex-skeleton-hygiene suite`, `Run codex-agents fixture suite` and `Run bin-help suite` steps.
  - above-ceiling: the coordinating session, after the push and before the merge GO, recording the check run's result on the board. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **Rollouts the Codex CLI writes.** These are the shapes T-1192 and T-1195 measured:
   - the 0.160.0 and 0.171.0 `review` shapes and the prompt shape;
   - `session_meta`, `turn_context`, `event_msg` (including `thread_settings_applied`, `item_completed`/`CommandExecution`, `task_complete`), `world_state` and `response_item` records.

   Every real line is one complete JSON object. Its depth-1 keys are plain ASCII (`timestamp`, `type`, `payload`). Its strings carry escaped quotes and escaped backslashes, and serialized command output and messages sit inside string values. **AC3** keeps the synthesized forms on their base outcome, and **AC13** runs this checkout's real captures base against HEAD.
2. **Damaged or hand-made rollouts reaching `--thread-id`.** These are reachable through truncation, hand editing or a future CLI defect.
   - Publish: an unterminated value or key ending at end of line, in a backslash, in an escaped quote or in a carriage return; a lone trailing `"`; a truncated counted `CommandExecution` or `task_complete` line; an unterminated string together with an escape or with no completed run. Covered by **AC1** and **AC2**.
   - Observe: an escaped depth-1 `type` key at the first, middle or last character position, in either order relative to the plain `type`; an escaped non-`type` depth-1 key beside a plain `type`; the issue's depth-1-`effort` shape; an escaped `event_msg` type over a `thread_settings_applied` payload. Covered by **AC4** and **AC5**.
3. **Invocations.**
   - `--publish --thread-id` with no expectation, and with `--expect-model zq-model-1 --expect-effort -`.
   - `--observe --thread-id` with and without `--expect-model`, and with `--expect-effort <named>` or `-`.
   - `--help`.
4. **Platforms.** bash on the CI runner (Linux) and on maintainer workstations, under `LC_ALL=C`.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **An unterminated string on `--observe` in a line neither extractor reads.** The gate stays publish-only, and such a line is neither required nor forbidden to refuse.
2. **A lone escaped `type` key with no plain `type` beside it.** No escape is decoded, so the record reads as untyped and is not read. This is neither required nor forbidden to refuse. On publish the gate already refuses it as `unicode-escape`.
3. **`extract_effort`'s depth-2 `payload.type`**: a duplicated `payload.type`, or an escaped `payload` or `type` key at depth 2 (Non-goals; follow-up).
4. **General JSON invalidity outside the two shapes.** Unbalanced or extra braces, bytes outside strings, invalid escapes other than backslash-u, a raw newline inside a value, and a record split across physical lines.
5. **A rollout edited on disk between the pass and `--publish`/`--observe`, or more than one rollout per thread id.** The existing search refuses the latter.

<!-- END intent-block: T-1196 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | The gate refuses an unterminated string in any line it tokenizes, whatever the line's type, including a key, a lone quote, CRLF, a trailing backslash and an escaped quote (D1) | **AC1** (`g1`–`g8`) |
| 2 | The refusal is exit `3`, writes no canonical file, leaves no raw, uses the `rollout not parseable … cause=unterminated-string` shape and echoes no line bytes (D1) | **AC1** (reviews dir empty, `zqcanary` absent from stderr) |
| 3 | The gate decides by closing-quote tracking, not a last-byte test (D1) | **AC1** (`g3`), **AC3** (`w2`, `w3`), mutation probe (D5) |
| 4 | `unterminated-string` precedes `unicode-escape` and `review did not run` (D2) | **AC2** |
| 5 | An escape-only rollout still refuses `unicode-escape`, and `review did not run` is unchanged (D2; Non-goals) | **AC3** (`w5`, `w6`) |
| 6 | Escaped depth-1 keys count toward `ntype` in `extract_model` (D3) | **AC4** (`e1`–`e5`) |
| 7 | The same in `extract_effort` (D3) | **AC5** (`x1`–`x5`) |
| 8 | Conservative form: an escaped non-`type` key also counts (D3) | **AC4** (`e4`), **AC5** (`x5`) |
| 9 | Depth-2 keys are not counted (D3) | **AC3** (`w5` observe identity) |
| 10 | `cause=malformed` is reused; cause sets, texts and exit codes are unchanged (D3; Non-goals) | **AC4**, **AC5** |
| 11 | Rollouts with neither shape keep the base outcome byte for byte (Goal) | **AC3**; real captures **AC13** |
| 12 | `--observe` runs no gate (Non-goals) | **AC3** (`g1`–`g8` observe identity) |
| 13 | D4's changed assertions; other labels unchanged; the two label families keep their prefixes | **AC6** |
| 14 | Vacuous probes move to `--observe` with a non-vacuity control (D4) | **AC6** (suite green) plus a QA reading item: whether each moved probe's control asserts `cause=malformed` on `--observe` is read, not grepped |
| 15 | One mutation probe per new guard, the extractor probes range-scoped (D5) | **AC6** (suite green, `PASS: T-1196`) plus a QA reading item for the scoping |
| 16 | A revert makes the suite fail on a T-1196 case (D5) | **AC7** |
| 17 | The header's exit-code `3` item names `unterminated-string` (D6) | **AC8** |
| 18 | The header describes D1, D2 and D3 (D6) | info-only (not promoted to AC): QA reading item, because the wording is free |
| 19 | Other suites executing the script stay green (Blast radius) | **AC9** |
| 20 | shellcheck clean, no recursive deletion (AC rules) | **AC10** |
| 21 | Scope: no docs, no agent prose, no fixture files, no CHANGELOG (Non-goals) | **AC11** |
| 22 | Records conformant | **AC12** |
| 23 | No real capture newly refuses or newly becomes MALFORMED (coordinator QA requirement) | **AC13** |
| 24 | CI green | **AC14** (above-ceiling) |
| 25 | `extract_effort`'s depth-2 `payload.type` is unchanged (Non-goals, D3 out of scope) | info-only (not promoted to AC): an exclusion of scope, with a follow-up issue |
| 26 | No escape decoding; a lone escaped `type` is unjudged (Non-goals) | info-only (not promoted to AC): Input space out-of-scope 2 names the class |
| 27 | No general JSON validation (Non-goals) | info-only (not promoted to AC): Input space out-of-scope 4 |
| 28 | No full-population sweep (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 29 | Pre-commitment | info-only (not promoted to AC): a disposition, not a deliverable property |

## Symmetry audit (parallel surfaces)

| Surface | Unterminated string (D1/D2) | Escaped depth-1 key (D3) | Identity (neither shape) |
|---|---|---|---|
| Completed-run gate, `--publish --thread-id` report-only | **AC1**, **AC2** | not reached: `:1012` already refuses any escaped key as `unicode-escape` (**AC3** `w5`) | **AC3** `pn` |
| Completed-run gate, `--publish --thread-id --expect-model … --expect-effort -` | **AC1** | same | **AC3** `pe` |
| `extract_model` via `--observe` | unchanged (T-1193 rule), observe identity in **AC3** | **AC4** | **AC3** `oe`/`on` |
| `extract_effort` via `--observe` | unchanged (T-1195 rule) | **AC5** | **AC3** `oe` (`--expect-effort -`) |
| `extract_model`/`extract_effort` on publish | unreachable: the gate refuses first | unreachable: the gate refuses first | **AC3** |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. Following T-1191 to T-1195 and the operator rulings relayed there (labelled relayed; the coordinating session holds the primary confirmation), CI and this task's own check lines decide the impact.
- **Known readers.** The Grep tool over `tests/` finds these suites naming `codex-capture`: `codex-agents`, `codex-skeleton-hygiene`, `gitignore-raw-dumps`, `retro-inputs` and `team-init`. Only `codex-skeleton-hygiene` passes `--thread-id` (Grep over `tests/`), and only that flag reaches the gate or the extractors. `tests/bin-help` reaches the script through `git ls-files -- bin/`. **AC6** and **AC9** run all of them, except any suite carrying a recursive deletion, which is left to CI (**AC14**).
- **Merged criteria that turn red by design** once this lands (disclosed, not repaired, because they are frozen):
  - T-1193 **AC1**, at HEAD: its publish-named and report-only-publish paths on `u1`–`u9` now meet the gate refusal.
  - T-1195 **AC1**: the HEAD `f10` refusal now reads `rollout not parseable … cause=unterminated-string`, not `effort not established`.
  - Other merged criteria running `codex-capture.sh` (T-107, T-1152, T-1192) were not re-run. That is a lower bound, disclosed per the deviation above. **AC3** keeps every rollout with neither shape byte-identical.
- **Shipped prose.** The shipped-docs inventory below dispositions every sentence about a publish exit `3`. None is edited.
- **Adopter-side artifacts.** No generated file changes: `gen-codex-agents.sh` copies agent bodies, which this task does not touch. Past review records and local captures are unchanged. The behavioural change an adopter can meet is limited to already-damaged rollouts: they now refuse loudly instead of publishing or establishing a value.

## Shipped-docs inventory

| Document (read by this role) | What it says | Disposition |
|---|---|---|
| `bin/codex-capture.sh` header (`--help`) | Exit-code `3` item names `rollout not parseable` / `cause=unicode-escape`; T-1193/T-1195 rule paragraphs | **updated in this task** (D6, **AC8**) |
| `agents/code-reviewer.md:265` | "A `publish` that exits `3` means either … `review did not run` or … `model not established` or … `effort not established` — quote the script's stderr line verbatim", then `BLOCKED` | not edited. The sentence enumerates exit-3 meanings without naming any gate cause token, and at the base it already omits `rollout not parseable` (`unicode-escape`) and `rollout import failed`. Its instruction (quote stderr verbatim, never a verdict) handles the new cause correctly. Widening the enumeration is noted under Open questions, not done here |
| `agents/code-reviewer.md:48`, `:50` | The model and effort gates' cause sets | not edited. No claim enumerates gate causes, and D3 reuses `malformed` |
| `agents/drift-evaluator.md:158` | The same exit-3 sentence, ending in a precondition failure | not edited. Same ground as `:265` |
| `agents/drift-evaluator.md:85`, `:87` | The model-gate and effort-gate cause sets | not edited. No claim enumerates completed-run-gate causes, and D3 reuses `malformed` |
| `skills/run/SKILL.md:274` | "A publish that exits `3` means `review did not run`: quote the script's stderr line verbatim and stop" | not edited. It treats every exit `3` as a stop and quotes stderr verbatim, so the new cause is covered. It already conflates `unicode-escape` with `review did not run` at the base |
| `templates/prompt-blocks/alternate-executor-invocation.md:42` (contained copy of `skills/run/SKILL.md:274`) | Same sentence | not edited. Same ground. The block and its contained copy stay byte-identical, so prompt sync is unaffected |
| `docs/adopting.md:331` | The model gate's `cause=` set | not edited. No claim enumerates completed-run-gate causes, and D3 reuses `malformed` |
| `docs/adopting.ja.md:332` | Same, Japanese | not edited. Same ground |
| `CHANGELOG.md`, `CHANGELOG.ja.md` | Release history naming earlier gate causes | not edited. History is not rewritten, and this task's entry is written at release prep |

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| Gate refuses an unterminated string (D1, D2) | not met | not met: no Codex CLI writes the shape | PATCH | a fail-closed bug fix |
| Escaped depth-1 key counts toward `ntype` (D3) | not met | not met: no Codex CLI writes the shape | PATCH | a fail-closed bug fix |
| `--help` names the new cause (D6) | not met | met: shown by `--help` | PATCH | documentation of an existing mode |

The derived tier is PATCH, the maximum of the column. Sprint release: PATCH, v2.9.6 (relayed from the coordinating session's planning).

## Assumptions

- **Measured by this role** (Read, Grep and Glob tools; the working tree was clean at `f80d97e1`):
  - `.git/refs/heads/feature/757-codex-review-effort-pin`, `.git/refs/remotes/origin/feature/757-codex-review-effort-pin` and `.git/refs/heads/feature/760-completed-run-gate-fail-closed` all hold `f80d97e192112c1927f72123d9e45c79724809e3`. `.git/packed-refs` maps `refs/remotes/origin/develop` to `75866424…`, and there is no local `refs/heads/develop`.
  - Every line anchor in `## Summarized sources`. The tech-lead's relayed anchors (`:924-1071`, `:942-944`, `:963-998`, `:981`, `:1012`, `:1016`, `:1057-1058`, `:1079`, `:1082`, `:320-435`, `:396`, `:398`, `:472-583`, `:546`, `:564`, `:565-566`, `:2135-2257`, `:2212-2214`, `~2324`) were re-read and hold. The gate's comment block begins at `:924` and its code at `:936`.
  - No file under `tests/` contains `unicode-escape`, `not parseable` or `review did not run`.
  - **Own-coinage zero-at-base:** `unterminated-string` occurs 0 times in `bin/` and `tests/` (Grep over the repository: hits only in `.shell-team/provenance/T-1193.md`, the T-1193 spec and the board, all prose). The freeze run measures `git show "$B:bin/codex-capture.sh" | grep -c unterminated-string` and records the value here. `PASS: T-1196 ` and `FAIL: T-1196` are expected at 0 before implementation.
  - **Relayed premise measured false (a finding about the hand-off).** The coordinator's QA requirement names "every committed `.shell-team/reviews/*codex*.jsonl` capture". `.gitignore:19` ignores `.shell-team/reviews/*.jsonl`. A Grep-tool search of `.git/index` for `reviews/<name>.jsonl` finds no match, while `reviews/T-1195` (the `.md` record) is found. So the committed population is empty, matching T-1193's withdrawn criterion. **AC13** therefore runs over the checkout-local captures and prints their population itself. The freeze run measures the tracked count with `git ls-files -- '.shell-team/reviews/*.jsonl' | wc -l` (expected `0`) and records it here. The coordinating session records the finding as an interventions entry.
- **Relayed, not measurable by this role** (owner: the coordinating session):
  - the issue #760 body (quoted in Summarized sources);
  - the sprint name "effort-pin" and release PATCH v2.9.6;
  - PR #772 open with base `develop`;
  - the operator rulings behind the no-sweep deviation.
- **Departure from a settled coordinator decision (declared).** The briefing settled `user-visible: no`. This spec declares `yes` with `shipped-docs: bin/codex-capture.sh — this-task`. The ground is measured: the task changes the `--help` exit-code item that enumerates gate causes (`:166-184`), and T-1193 declared `yes` for the same kind of `--help` change. The coordinating session confirms or reverses before freeze. Reversing means dropping the `shipped-docs` line and the **AC8** `adopter-surface` line and keeping **AC8** itself.
- **Predicted, unmeasured** (owner: the freeze run). A false prediction routes back here as a broken check line, never as a pass.
  - **Base outcomes of AC1's fixtures:** all of `g1`–`g8` publish with exit `0`. Traced through `:963-1069`:
    - the base tokenizer pushes the unclosed token, and no field the gate counts depends on it;
    - `g7`'s `exit_code` is read before the truncation;
    - `g8`'s `last_agent_message` reads `present`;
    - no damaged line carries `model` or `effort`, so neither extractor reads it.
  - **Base outcomes of AC2:** `o1` is `review did not run` (no `task_complete`). `o2` is `cause=unicode-escape`.
  - **Base outcomes of AC4:** `e1`–`e4` print `model=zq-model-1` (the plain `type` is `other`, so the line is unread and the escaped key is not counted). `e5` is malformed through `key_u`.
  - **Base outcomes of AC5:** each fixture prints `model=zq-model-1` and `effort=zq-eff-a`. The model extractor admits each line through its backslash-u prefilter but does not read it (type `other`), and the effort extractor reads only the well-formed `turn_context`.
  - **The help layout:** at the base, the exit-code `3` item spans `:166-184` and contains `unicode-escape`.
  - **AC13's runtime:** four script runs per local capture, run in sequence. Expected to take minutes, within its 3600 s bound.
- **Stacked branch.** This branch is stacked behind an open predecessor at authoring time: T-1195 on `feature/757-codex-review-effort-pin`, PR #772, base `develop`. The open state is relayed. T-1195 itself is stacked on T-1194/T-1193/T-1192 in the same unmerged train.
  - The declaration region's four arms, in order: the local predecessor branch, the remote-tracking predecessor, then `develop` (local, then remote-tracking) as the era-change fallback.
  - Route-back residuals, disclosed rather than engineered around:
    - the predecessor deleted unmerged;
    - the predecessor rebased, force-pushed or squash-merged after this branch was cut. A squash merge would make the fallback resolve to a `develop` commit without the T-1192–T-1195 changes, so every base-reading criterion would compare against an unrelated script;
    - a checkout that never fetched the predecessor. That checkout fetches it first.
- **Borrowed tokens.** These are presence-asserted only, so no literal count premise rests on them:
  - `rollout not parseable`, `cause=unicode-escape`, `review did not run` (T-1152);
  - `model not established`, `cause=malformed`, `model=unavailable` (T-1192);
  - `effort not established`, `effort=unavailable` (T-1195);
  - the base `pass` labels, derived from the base blob by **AC6**.

  Both label-family prefixes `T-1193 unterminated string:` and `T-1195 positive control:` are asserted present in the base label set by **AC6** itself. This role measured each at 1, at `:2220` and `:2371`.
- **Pre-implementation expectation (for the freeze read).** At freeze, HEAD's script equals the base blob.
  - **AC1**, **AC2**, **AC4**, **AC5**: the base controls pass, then the line is red on the first HEAD case.
  - **AC3**: red only on its "HEAD differs" control; every identity pair is green.
  - **AC6**: red on the missing `PASS: T-1196 ` line.
  - **AC7**: red. Its "script differs" control fails, and the suite passes on the extracted tree without a `FAIL: T-1196` line.
  - **AC8**: the base controls pass, then the line is red at HEAD.
  - **AC9**, **AC10**: green.
  - **AC11**: red on its positive control.
  - **AC12**: green when the board entry is conformant.
  - **AC13**: green, vacuously by construction at freeze, because base and HEAD are the same script. It discriminates only after implementation.
  - **AC14**: `SKIP`.

## Open questions

- **Follow-up issue for coordinator decision D3** (filed by the coordinating session, not this role). Proposed title: "codex-capture: extract_effort's payload.type — count a duplicated depth-2 `payload.type` and make an escaped `payload`/`type` key at depth 2 malformed". Proposed body: "`extract_effort` decides an `event_msg`'s subtype from `payload.type` at depth 2 (`bin/codex-capture.sh` `:550`). Two shapes are not judged. (1) `payload` carrying `type` more than once: the last value wins, so `{"type":"x","type":"thread_settings_applied"}` is read. (2) A `payload` or `type` key spelled with a backslash-u at depth 2: the record is left unread instead of `malformed`. Neither shape is written by the Codex CLI; this is about the checker's fail-closed contract. Expected: both make the effort observation `malformed`; fixtures in `tests/codex-skeleton-hygiene` cover both; existing cases stay green. Left out of #760 on purpose (T-1196 Non-goals)."
- **Optional, not blocking: the exit-3 enumeration in `agents/code-reviewer.md:265` / `agents/drift-evaluator.md:158`.** It names three meanings of a publish exit `3` and has omitted `rollout not parseable` and `rollout import failed` since before this task. Its behaviour (quote stderr verbatim, stop) is correct for every cause. Whether to widen the sentence is a candidate for the next planning, not this task.

## Notes for engineer

- **Files.** The allow-list is in **AC11**: `bin/codex-capture.sh`, `tests/codex-skeleton-hygiene/run.sh`, and this task's records. Fixtures are synthesized inline.
- **Where to place the T-1196 block in the suite.** Put it **before** the T-1193 block (`:2135`), after the T-1192 observe block ends (`:2133`). **AC7** runs the suite on a reverted script, and the suite stops at its first `fail`. The rewritten T-1193 publish assertions would fail first, with a `FAIL: T-1193` line, if they ran before the T-1196 block.
- **Labels.** Every T-1196 `pass` line starts `T-1196 ` and every T-1196 `fail` message starts `T-1196`. Keep every other base label byte-identical, except the two families D4 names, which keep their prefixes.
- **The gate.** Track whether each string literal closed, as `extract_model`'s tokenizer already does (`:354`, `:360`, `:363`). A last-byte test is wrong both ways: it passes `g3` (`"…\"`) and `g6` (a lone `"`), and it fails `w2` (`"abc\\"`), which must stay well-formed. Emit the new cause through the existing `rollout not parseable` refusal. D2's order means the unterminated verdict wins over the escape verdict and is decided before the completed-run counts are trusted.
- **The extractors.** Count an escaped depth-1 key where `ntype` is counted (`:398`, `:546`). `key_u` keeps its current meaning for read records. The two functions carry textually identical lines, so mutation probes must be range-scoped to one function (the T-1195 probes at `:2456-2462` show the pattern).
- **Moved probes.** The T-1193 probes `no-unterm`, `unterm-disabled` and `last-byte`, and the T-1195 `no-unterm` probe, move to `--observe`. Each first asserts that the unmutated script refuses its fixture on `--observe` with `cause=malformed`, so the probe cannot pass vacuously.
- **Mutation probes (mechanism class), one per new guard, in the suite:**
  - the gate's unterminated refusal removed (caught by an **AC1** shape publishing);
  - the gate's closed-quote decision replaced by a last-byte test (caught by `g3` or `g6` publishing);
  - the escaped-key count removed from `extract_model` only (caught by `e1`);
  - the escaped-key count removed from `extract_effort` only (caught by `x1`).
- **No echo.** A refusal prints no line bytes, no model or effort value and no account identifier.
- **Help text.** Keep the exit-code items in their `<digit>` plus two spaces layout and the section ending at the bare `#` line (**AC8** reads it that way).
- **AC13 (QA).** It reads this checkout's local captures. They carry identifiers, so never paste their content, or the scripts' output on them, into a record. Report the counts and the basenames only.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** `codex-capture.sh` is a shipped `bin/` gate and gets full strength. The inline check lines get dev-scaffold depth (operator ruling 2026-08-22).
