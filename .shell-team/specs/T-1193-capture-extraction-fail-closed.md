# codex-capture model extraction fails closed on an unterminated string and on a duplicated top-level `type`, and its diagnostics name `--observe`

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1193

## Problem

T-1192 added a model-observation step to `bin/codex-capture.sh`. It reads the model a Codex pass actually ran on out of that pass's rollout. The step uses a small hand-written tokenizer, and the cross-provider review of T-1192 found two inputs it guesses at instead of refusing (fast-follow F1).

- **No closing quote.** A string with no closing quote is accepted, and the quote-stripping helper drops its last byte unchecked. One extra byte after the model name, with no closing quote, therefore reads as that model name.
- **Two top-level `type` keys.** The last one wins, so a record can be read as a type whose first `type` says it is not one.

Neither shape is something the Codex CLI writes, but a checker must refuse what it cannot parse. Separately (F3), the script's own diagnostics predate its third mode. The no-mode error names only `--alloc` and `--publish`, and the `--help` exit-code section reads as if only `--publish` exits `3`.

## Summarized sources

- **Issue #759 body.** Written by the coordinating session and relayed verbatim in this role's briefing; this role cannot open the tracker, so the freeze run confirms it (see Assumptions). The distinctions carried over, quoted:
  - Scope: "Make the observed-model extraction added in #756 (T-1192) fail closed on two malformed-input shapes, and make the script's own diagnostics name its third mode."
  - "An unterminated string anywhere in a record that the extraction reads makes the observation `malformed` (refused under `--expect-model`, never reported as a model)."
  - "A record with more than one top-level `type` key is `malformed`."
  - "The no-mode diagnostic names all three modes, and the header's exit-code section states that `--observe` can exit 3."
  - "Fixtures in `tests/codex-skeleton-hygiene` cover each case, and the existing T-1192 cases stay green."
  - Ruled out: "Treating the duplicated `type` as 'first wins': it would still let an ambiguous record be classified; refusing it is the fail-closed choice."
  - "Neither malformed shape is something the Codex CLI writes; the point is the fail-closed contract, not a live exposure."

  Restated by the Goal sentence, D1–D5, Non-goals, **AC1**, **AC2**, **AC4** and **AC6**.
- **`bin/codex-capture.sh` at `7fccd1e0`** (the T-1192 branch tip, which this branch starts from):
  - `:155-184`: the exit codes. The `0` item names `--alloc` and `--publish` only. The `3` item opens with `` (`--publish` only) ``. The `4` item is `--publish` only, and correctly so, because `--observe` publishes nothing.
  - `:186-211`: the T-1192 extraction paragraph. `:192-193` says any other record type "is never read".
  - `:283-388`: `extract_model`.
    - `:289`: `strip_quotes` returns `substr(s, 2, length(s) - 2)` without checking either end.
    - `:306-341`: `tokenize`. When a string literal reaches the end of the line without its closing quote, it is pushed as an ordinary token.
    - `:345`: a line containing neither the bytes `model` nor a backslash-`u` is skipped before tokenizing.
    - `:356`: the depth-1 `type` value is assigned on every occurrence, so the last one wins.
    - `:370`: only lines typed `session_meta` or `turn_context` are aggregated.
    - `:381-386`: the output is `MALFORMED`, `ABSENT`, `INCONSISTENT` or `OK <token>`.
  - `:394-411`: `apply_model_gate`. `MALFORMED` maps to `cause=malformed`. It exits `3` only under a named (non-`provider-configured`) `--expect-model`; otherwise it is report-only with `model=unavailable`.
  - `:482`: the unexpected-positional usage string names the `--alloc` and `--publish` forms only.
  - `:486`: `exactly one of --alloc / --publish is required`.
  - `:502-516` and `:849-852`: the `--observe` and `--publish --thread-id` callers of the extraction. Both reach the same `model not established (thread=… cause=…)` refusal.
  - `:707-842`: the completed-run gate. It has its own copy of the same `strip_quotes` (`:713-715`) and tokenizer (`:734-769`), tokenizes every line, and reads fields by structural path.

  Restated by D1–D5, Non-goals, **AC1**–**AC3**, **AC6**, **AC7** and Input space.
- **`tests/codex-skeleton-hygiene/run.sh` at `7fccd1e0`:**
  - `:246-252`: `SCRIPT` is `$REPO_ROOT/bin/codex-capture.sh`, with `REPO_ROOT` derived from the suite's own directory. `fail` prints `FAIL: <msg>` on stderr and exits `1`. `pass` prints `PASS: <msg>`.
  - `:1930-2160`: the T-1192 model-gate block.
  - `:2135-2160`: the mutation self-check. Its `sed` probes anchor on the text of `:370` (`any-record-type`) and `:356` (`any-depth-type`), and refuse a probe whose expression changes nothing.

  Restated by **AC4**, **AC5** and Notes for engineer.
- **`tests/bin-help/run.sh:2-9`**: every tracked `bin/` entry, enumerated with `git ls-files -- bin/` rather than by a glob, must answer `--help`. Restated by **AC8**.
- **The documents that describe `cause=malformed`.** They name the cause set and say only that "a malformed value" stops the round:
  - `docs/adopting.md:328-332`;
  - `docs/adopting.ja.md:330-333`;
  - `agents/code-reviewer.md:48`;
  - `agents/drift-evaluator.md:85`.

  None of them lists which shapes are malformed, so the change keeps them accurate. Restated by the Non-goals docs line and Blast radius.
- **`CONTRIBUTING.md` `## What a version number encodes` (`:135-148`)**: PATCH covers bug fixes and internal mechanisms. Restated by `## Version`.
- **`CONTRIBUTING.md` `## Cutting a release` (`:114-133`)**: the `CHANGELOG.md` / `CHANGELOG.ja.md` entry is added on the release-preparation branch (`:122`), not by a task. Restated by the Non-goals CHANGELOG line.
- **`.github/workflows/check-handoff.yml`**: these steps run on every pull request:
  - `:28-29`, `shellcheck`;
  - `:268-269`, `Run codex-skeleton-hygiene suite`;
  - `:388-389`, `Run codex-agents fixture suite`;
  - `:402-403`, `Run bin-help suite`.

  Restated by **AC12**.
- **`bin/check-interventions.sh:8`**: `<base>/interventions/<task-id>.md`, or `no-task.md` for work outside a task. Restated by **AC10**'s allow-list.

## Goal

<!-- BEGIN intent-block: T-1193 -->

- user-visible: yes — `codex-capture.sh --help` changes. Its exit-code section now says that `--observe` can exit `0` and `3`, and the header describes the two new malformed shapes. A bare or positional misuse now names `--observe`. A rollout with an unterminated string or a duplicated top-level `type` now refuses as `cause=malformed` under a named `--expect-model`, where it used to be read as a model.
- shipped-docs: bin/codex-capture.sh — this-task
- verification-class: mechanism — the diff changes `bin/codex-capture.sh`, a shipped checker, and its fixture suite `tests/codex-skeleton-hygiene/run.sh`.
- verification-ceiling: unit-and-static — **AC1**–**AC11** are settled in a plain checkout. They run the base commit's and HEAD's `codex-capture.sh` on rollouts synthesized under `$TMPDIR` in the measured 0.160.0, 0.171.0 and prompt shapes, read `--help` and the diagnostics, run the hygiene suite on HEAD and on a scratch copy of HEAD whose script is reverted to the base blob, run the suites that execute the script, and read the exit codes of shellcheck, `check-adopter-docs.sh` and `check-handoff.sh`. **AC12** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1

**Goal (one sentence).** `codex-capture.sh`'s model extraction reports a rollout as `malformed` in two cases: when any line it reads carries an unterminated string, and when such a line carries the top-level `type` key more than once. A named `--expect-model` then refuses it on both `--publish --thread-id` and `--observe`, and report-only use prints `model=unavailable`. Every well-formed rollout keeps exactly the T-1192 outcome. The script's no-mode diagnostic, its positional-usage string and its `--help` exit-code section name `--observe` as the third mode, which can exit `0` and `3`.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — unterminated string (coordinating-session decision D-a).** An unterminated string is a string literal whose closing unescaped `"` is not found before the end of the line, as the line is read. A CRLF line's trailing carriage return is part of the line, and an escaped `\"` closes nothing. Such a string, in any line the extraction reads (any line that passes the `:345` prefilter), makes the whole observation `MALFORMED`.
  - This holds whatever that line's top-level `type` is, and whether or not a `type` was read at all. An unterminated string can swallow the `type` key, so a rule limited to lines whose type was read would miss exactly the dangerous case.
  - It holds equally for a string in key position. (**AC1**)
- **D2 — duplicated top-level `type` (D-b).** A line the extraction reads that carries the depth-1 `type` key more than once is `MALFORMED`. That covers equal values, differing values in either order, and a non-string value beside a string one. A `type` key at depth 2 or deeper is not counted, including two of them in the same nested object. (**AC2**)
- **D3 — no new vocabulary (D-c).** Both shapes reuse `cause=malformed`. The cause set `absent | inconsistent | malformed | mismatch`, the exit codes, the refusal text `model not established`, and the report-only ` model=unavailable` suffix and `model=unavailable` stdout stay as they are. Every rollout outside the two shapes keeps its T-1192 outcome byte for byte. (**AC1**–**AC3**)
- **D4 — diagnostics (D-e).**
  - The no-mode diagnostic names `--alloc`, `--publish` and `--observe`.
  - The `--help` exit-code section's `0` and `3` items name `--observe`. `--observe` exits `3` only for a failed rollout import and for `model not established`. The `3` item's other causes (an empty capture, no valid event line, `review did not run`, `unicode-escape`) remain `--publish`-only, and the item may say so. The `4` item may stay `--publish`-only.
  - The header describes both the unterminated-string rule and the duplicated-`type` rule.
  - The unexpected-positional usage string names the `--observe` form. (**AC6**, **AC7**)
- **D5 — the fixture suite.** `tests/codex-skeleton-hygiene/run.sh` covers every class in **AC1** and **AC2** with fixtures synthesized inline. Every T-1192 `pass` label at the base still prints. Reverting only `bin/codex-capture.sh` to the base blob makes the suite fail on a `T-1193` case. (**AC4**, **AC5**)

**Pre-commitment (frozen before round 1).** The trigger and drop order below are AI self-discipline proposed by the coordinating session, never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning:
  - (N1) D1, the unterminated-string rule (**AC1**);
  - (N2) D2, the duplicated-`type` rule (**AC2**).
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same droppable component. A round interrupted before a verdict does not count.
- **Droppable, in order.** A drop removes criterion text, so it is a class-B re-freeze. The dropped part goes to one follow-up issue that carries the rounds' findings as its requirement list.
  1. **The positional-usage wording (D4's last bullet, **AC7**).** It is first because it is the widest wording surface and the one the issue does not name.

## Non-goals

- **The completed-run gate is not changed (D-d).** Its copy of the same tokenizer (`:707-842`) has the same unterminated-string pattern, but issue #759 names only the extraction. The coordinating session files a separate follow-up issue for it, and this sprint does not touch it. The report-only paths in **AC1** and **AC2** show that the gate still admits those fixtures.
- **No new cause token and no exit-code change.** (**AC1**–**AC3**)
- **No general JSON validation.** Unbalanced braces, bytes outside strings, invalid escapes other than `\u`, and a record split across lines stay outside what the extraction judges. (info-only; Input space out-of-scope)
- **No change for lines the extraction does not read.** A line without `model` and without a backslash-`u` stays skipped by the prefilter. An unterminated string or a duplicated `type` there is neither required nor forbidden to refuse. (info-only; Input space out-of-scope 1)
- **No adopter-doc or agent-prose edit.** `docs/adopting.md`, `docs/adopting.ja.md`, `agents/code-reviewer.md` and `agents/drift-evaluator.md` describe `malformed` without listing its shapes, so they stay accurate. (**AC10**)
- **No fixture files.** Fixtures are synthesized inline in `tests/codex-skeleton-hygiene/run.sh`, not under `fixtures/`. (**AC10**)
- **No CHANGELOG entry.** It is written at release prep (`CONTRIBUTING.md`, `## Cutting a release`). (**AC10**)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** This follows the precedent of T-1191 and T-1192 and the operator rulings relayed there. CI and this task's own check lines decide the impact. (info-only; disclosed in Blast radius)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`, export a temp `HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and unset `TEAM_RUN_BASE`, `CODEX_HOME` and `CODEX_THREAD_ID`.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **Base reads.** Lines that read a base blob resolve `B` with the declaration region's discriminator expression, spelled byte-identically in **AC1**–**AC7** and **AC10**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Fixture rollouts** are synthesized in the T-1192 record shapes and never copied from a real rollout.
- **Model names.** The placeholder models `zq-model-1` and `zq-model-2` name no real model. The literal backslash and carriage return are built at run time with `printf '\134'` and `printf '\015'`, and every fixture that needs one is first checked for it.
- **Suite runs.** Suites run through `tms`: own process group, 1200 s, killed on timeout.
  - Before a suite runs, it is scanned for a recursive-deletion pattern with backslash-continued lines joined. The joined text is written to a file first and grepped there, so no pipeline status is read after `grep -q`.
  - In **AC4** and **AC5**, a match is a broken instrument and exits `1`. **AC8** instead excludes a matching suite and names it as CI-covered.
- **The three paths.** Each malformed class in **AC1** and **AC2** is run on three paths, and report-only is checked twice:
  - **publish-named.** `--publish --thread-id <id> --expect-model zq-model-1` exits `3`. Stderr contains `model not established` and `cause=malformed`. The reviews dir is empty afterwards, so there is no canonical file and no surviving raw. `zq-model` appears nowhere on stderr.
  - **observe-named.** `--observe --thread-id <id> --expect-model zq-model-1` exits `3` with the same two strings, empty stdout, and no `zq-model` on stderr.
  - **report-only publish.** `--publish --thread-id <id>` without `--expect-model` exits `0`. The summary line ends in ` model=unavailable`, the canonical `.jsonl` equals the rollout, and no `zq-model` is on stderr.
  - **report-only observe.** `--observe --thread-id <id>` without `--expect-model` exits `0` with stdout exactly `model=unavailable`.

- [ ] **AC1** (D1, D3; N1.) Unterminated strings. Each fixture is the record line or lines listed, followed by a completed `CommandExecution` and a `task_complete` record:
  - `u1`: a `session_meta` line ending `"model":"zq-model-1X` with no closing quote. This is the issue's reproduction.
  - `u2`: the same ending `"model":"zq-model-1`, an ordinary truncation.
  - `u3`: the same ending in a backslash, `"model":"zq-model-1\`.
  - `u4`: a complete `session_meta` record followed by a lone `"`.
  - `u5`: the same as `u2`, with a CRLF line end.
  - `u6`: an unterminated key, `…"model":"zq-model-1","zq`.
  - `u7`: an `event_msg` line ending `"model":"zq-model-1X`, beside a well-formed `session_meta` line carrying `zq-model-1`. The line's type is not one the extraction aggregates.
  - `u8`: a line whose `timestamp` value lost its closing quote, so the `type` key is swallowed and no type is read, beside a well-formed `session_meta` line.
  - `u9`: a well-formed `model` value followed by `"note":"abc\"`, a non-model value that ends in an escaped quote.

  **Positive control** (the defect exists at the base): the base commit's script, with `--expect-model zq-model-1`, publishes `u1`, `u3`–`u9` with exit `0`. It publishes `u2` with exit `0` without `--expect-model`, and refuses it as `cause=mismatch` with one. **At HEAD**, every fixture `u1`–`u9` meets all three paths.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; P0='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1'; SMOK="$P0\"}}}"; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; cr=$(printf '\015'); test "${#cr}" = 1 || exit 1; mk(){ local f="$1" l; shift; { for l in "$@"; do printf '%s\n' "$l"; done; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$f"; }; mk u1 "${P0}X" || exit 1; mk u2 "$P0" || exit 1; mk u3 "$P0$bs" || exit 1; mk u4 "$SMOK\"" || exit 1; mk u5 "$P0$cr" || exit 1; mk u6 "$P0\",\"zq" || exit 1; mk u7 '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"session_configured","thread_settings":{"model":"zq-model-1X' "$SMOK" || exit 1; mk u8 '{"timestamp":"2026-11-21T00:00:00Z,"type":"session_meta","payload":{"provenance":{"model":"zq-model-2"}}}' "$SMOK" || exit 1; mk u9 "$P0\"},\"note\":\"abc$bs\"" || exit 1; grep -qF "zq-model-1$bs" "$T/u3" || exit 1; grep -qF "abc$bs\"" "$T/u9" || exit 1; test "$(grep -c "$cr" "$T/u5")" = 1 || exit 1; n=0; place(){ n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" "$T/rv$n" || return 97; cp "$T/$1" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; }; pc(){ local src="$1" o j; shift; place "$src" || return 97; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$n" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch$n"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$n" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; po(){ local src="$1"; shift; place "$src" || return 97; ( export CODEX_HOME="$T/ch$n"; cd "$T/oc" || exit 97; exec bash "$S" --observe --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; nz(){ grep -qF zq-model "$T/pe"; test "$?" = 1; }; rfp(){ test "$1" = 3 && grep -qF 'model not established' "$T/pe" && grep -qF cause=malformed "$T/pe" && nz && test -z "$(ls -A "$T/rv$n")"; }; rfo(){ test "$1" = 3 && grep -qF 'model not established' "$T/pe" && grep -qF cause=malformed "$T/pe" && nz && test ! -s "$T/po"; }; okp(){ test "$1" = 0 && grep -qE "^codex-capture: publish: rollout thread=$I .* model=unavailable\$" "$T/pe" && nz && cmp -s "$T/$2" "$T/rv$n/T-000-codex-primary.jsonl"; }; oko(){ test "$1" = 0 && test "$(cat "$T/po")" = model=unavailable && nz; }; four(){ local f="$1" s; pc "$f" --expect-model zq-model-1; s=$?; rfp "$s" || { rc=1; printf 'miss publish-named %s\n' "$f"; }; po "$f" --expect-model zq-model-1; s=$?; rfo "$s" || { rc=1; printf 'miss observe-named %s\n' "$f"; }; pc "$f"; s=$?; okp "$s" "$f" || { rc=1; printf 'miss publish-report %s\n' "$f"; }; po "$f"; s=$?; oko "$s" || { rc=1; printf 'miss observe-report %s\n' "$f"; }; }; S="$T/base.sh"; for f in u1 u3 u4 u5 u6 u7 u8 u9; do pc "$f" --expect-model zq-model-1; test "$?" = 0 || exit 1; done; pc u2; test "$?" = 0 || exit 1; pc u2 --expect-model zq-model-1; test "$?" = 3 || exit 1; grep -qF cause=mismatch "$T/pe" || exit 1; S="$X"; for f in u1 u2 u3 u4 u5 u6 u7 u8 u9; do four "$f"; done; test "$rc" -eq 0

- [ ] **AC2** (D2, D3; N2.) Duplicated top-level `type`. Each fixture is the record line or lines listed, followed by the same two completion records:
  - `d1`: `"type":"session_meta","type":"session_meta"`, equal values.
  - `d2`: `"type":"event_msg","type":"session_meta"`. The base reads this as `session_meta`, which is the dangerous order.
  - `d3`: `"type":"session_meta","type":"event_msg"` carrying `zq-model-2`, beside a well-formed `session_meta` line carrying `zq-model-1`.
  - `d5`: `"type":1,"type":"session_meta"`, a non-string value beside a string one.
  - `d6`: one depth-1 `type`, plus `"type":"x","type":"y"` inside `payload`. Depth 2 is not counted.

  **Positive control**: the base commit's script publishes all five with `--expect-model zq-model-1` and exit `0`. **At HEAD**, `d1`, `d2`, `d3` and `d5` each meet all three paths. `d6` publishes with exit `0` and a summary ending in ` model=zq-model-1`, and `--observe … --expect-model zq-model-1` prints exactly `model=zq-model-1`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SMOK='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; mk(){ local f="$1" l; shift; { for l in "$@"; do printf '%s\n' "$l"; done; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$f"; }; mk d1 '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}' || exit 1; mk d2 '{"timestamp":"2026-11-21T00:00:00Z","type":"event_msg","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}' || exit 1; mk d3 '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","type":"event_msg","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-2"}}}' "$SMOK" || exit 1; mk d5 '{"timestamp":"2026-11-21T00:00:00Z","type":1,"type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}' || exit 1; mk d6 '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"type":"x","type":"y","provenance":{"type":"model","model":"zq-model-1"}}}' || exit 1; n=0; place(){ n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" "$T/rv$n" || return 97; cp "$T/$1" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; }; pc(){ local src="$1" o j; shift; place "$src" || return 97; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$n" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch$n"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$n" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; po(){ local src="$1"; shift; place "$src" || return 97; ( export CODEX_HOME="$T/ch$n"; cd "$T/oc" || exit 97; exec bash "$S" --observe --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; nz(){ grep -qF zq-model "$T/pe"; test "$?" = 1; }; rfp(){ test "$1" = 3 && grep -qF 'model not established' "$T/pe" && grep -qF cause=malformed "$T/pe" && nz && test -z "$(ls -A "$T/rv$n")"; }; rfo(){ test "$1" = 3 && grep -qF 'model not established' "$T/pe" && grep -qF cause=malformed "$T/pe" && nz && test ! -s "$T/po"; }; okp(){ test "$1" = 0 && grep -qE "^codex-capture: publish: rollout thread=$I .* model=unavailable\$" "$T/pe" && nz && cmp -s "$T/$2" "$T/rv$n/T-000-codex-primary.jsonl"; }; oko(){ test "$1" = 0 && test "$(cat "$T/po")" = model=unavailable && nz; }; four(){ local f="$1" s; pc "$f" --expect-model zq-model-1; s=$?; rfp "$s" || { rc=1; printf 'miss publish-named %s\n' "$f"; }; po "$f" --expect-model zq-model-1; s=$?; rfo "$s" || { rc=1; printf 'miss observe-named %s\n' "$f"; }; pc "$f"; s=$?; okp "$s" "$f" || { rc=1; printf 'miss publish-report %s\n' "$f"; }; po "$f"; s=$?; oko "$s" || { rc=1; printf 'miss observe-report %s\n' "$f"; }; }; S="$T/base.sh"; for f in d1 d2 d3 d5 d6; do pc "$f" --expect-model zq-model-1; test "$?" = 0 || exit 1; done; S="$X"; for f in d1 d2 d3 d5; do four "$f"; done; pc d6 --expect-model zq-model-1; s=$?; test "$s" = 0 || rc=1; grep -qE ' model=zq-model-1$' "$T/pe" || rc=1; po d6 --expect-model zq-model-1; s=$?; test "$s" = 0 || rc=1; test "$(cat "$T/po")" = model=zq-model-1 || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D3.) Well-formed and T-1192-refused rollouts keep the base's outcome byte for byte. The fixtures:
  - `w1`: the 0.160.0 `review` shape.
  - `w2`: the prompt shape, a `session_meta` line, a `world_state` decoy quoting `\"model\"` inside a string, and a `turn_context` line.
  - `w3`: the 0.171.0 `review` shape, `session_meta` `base_instructions.provenance.model` plus an `event_msg` with `thread_settings`.
  - `w4`: `w1` with a CRLF line end.
  - `w5`: a depth-2 `payload.type` beside the depth-1 one.
  - `w6`: a value ending in an escaped backslash before its closing quote, `"note":"abc\\"`.
  - `a1`: no model.
  - `i1`: `session_meta` and `turn_context` disagree.
  - `n1`: a `null` model.

  Each fixture runs four ways: publish with and without `--expect-model zq-model-1`, and observe with and without it. The base script and HEAD's script run on identical inputs in an identical directory path; the reviews dir is renamed with `mv` after each run, and nothing is deleted.
  - Each pair has equal exit status, stdout and stderr, and an identical reviews-dir tree (`diff -r`).
  - Positive controls: HEAD's script differs from the base blob. At HEAD, `w1`–`w6` publish with `--expect-model zq-model-1` with exit `0` and a summary ending in ` model=zq-model-1`, and observe with it prints exactly `model=zq-model-1`. `a1`, `i1` and `n1` refuse that publish with exit `3` and `cause=absent`, `cause=inconsistent` and `cause=malformed` respectively.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/oc" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; cmp -s "$T/base.sh" "$X"; test "$?" = 1 || rc=1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; P0='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1'; SMOK="$P0\"}}}"; SM2='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-2"}}}'; NL='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":null}}}'; WS='{"timestamp":"2026-11-21T00:00:01Z","type":"world_state","payload":{"full":{"model":"zq-decoy","instructions":"quoted \"model\":\"zq-decoy\" text"}}}'; TX='{"timestamp":"2026-11-21T00:00:02Z","type":"turn_context","payload":{"turn_id":"t1","model":"zq-model-1","collaboration_mode":{"mode":"default","settings":{"model":"zq-model-1"}}}}'; S7='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","base_instructions":{"text":"x","provenance":{"type":"model","model":"zq-model-1"}}}}'; EV='{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"session_configured","thread_settings":{"model":"zq-model-1","collaboration_mode":{"mode":"default","settings":{"model":"zq-model-1"}}}}}'; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; cr=$(printf '\015'); test "${#cr}" = 1 || exit 1; mk(){ local f="$1" l; shift; { for l in "$@"; do printf '%s\n' "$l"; done; printf '%s\n%s\n' "$CE" "$TC"; } > "$T/$f"; }; mk w1 "$SMOK" || exit 1; mk w2 "$SMOK" "$WS" "$TX" || exit 1; mk w3 "$S7" "$EV" || exit 1; mk w4 "$SMOK$cr" || exit 1; mk w5 '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"type":"x","model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}' || exit 1; mk w6 "$P0\"},\"note\":\"abc$bs$bs\"}}" || exit 1; mk a1 || exit 1; mk i1 "$SM2" "$TX" || exit 1; mk n1 "$NL" || exit 1; grep -qF "abc$bs$bs\"" "$T/w6" || exit 1; test "$(grep -c "$cr" "$T/w4")" = 1 || exit 1; run(){ local f="$1" md="$2" t="$1-$2-$3" o j r; mkdir -p "$T/w" || return 97; set --; case "$md" in p?) bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/w" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; set -- --publish --stem T-000-codex-primary --reviews-dir "$T/w" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I";; *) set -- --observe --thread-id "$I";; esac; case "$md" in ?e) set -- "$@" --expect-model zq-model-1;; esac; ( export CODEX_HOME="$T/ch-$f"; cd "$T/oc" || exit 97; exec bash "$S" "$@" ) < /dev/null > "$T/o-$t" 2> "$T/e-$t"; r=$?; printf '%s\n' "$r" > "$T/rc-$t" || return 97; mv "$T/w" "$T/w-$t" || return 97; }; same(){ test "$(cat "$T/rc-$1-b")" = "$(cat "$T/rc-$1-h")" && cmp -s "$T/o-$1-b" "$T/o-$1-h" && cmp -s "$T/e-$1-b" "$T/e-$1-h" && diff -r "$T/w-$1-b" "$T/w-$1-h" > /dev/null; }; k=0; for f in w1 w2 w3 w4 w5 w6 a1 i1 n1; do k=$((k + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$k"); mkdir -p "$T/ch-$f/sessions/2026/11/21" || exit 1; cp "$T/$f" "$T/ch-$f/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || exit 1; for md in pe pn oe on; do S="$T/base.sh"; run "$f" "$md" b || exit 1; S="$X"; run "$f" "$md" h || exit 1; same "$f-$md" || { rc=1; printf 'differs %s %s\n' "$f" "$md"; }; done; done; for f in w1 w2 w3 w4 w5 w6; do test "$(cat "$T/rc-$f-pe-h")" = 0 || rc=1; grep -qE ' model=zq-model-1$' "$T/e-$f-pe-h" || rc=1; test "$(cat "$T/o-$f-oe-h")" = model=zq-model-1 || rc=1; done; for p in a1:absent i1:inconsistent n1:malformed; do f=${p%%:*}; test "$(cat "$T/rc-$f-pe-h")" = 3 || rc=1; grep -qF "cause=${p#*:}" "$T/e-$f-pe-h" || rc=1; done; test "$rc" -eq 0

- [ ] **AC4** (D5.) The hygiene suite at HEAD exits `0` under `tms` with no line beginning `FAIL`.
  - Every `pass "T-1192 …"` label in the base blob of `tests/codex-skeleton-hygiene/run.sh` (column-0 literal labels without `$`, `"` or a backslash) still prints as `PASS: <label>`. The label set is derived from the base blob at run time and must be non-empty.
  - At least one line begins `PASS: T-1193 `.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac4.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; S=tests/codex-skeleton-hygiene/run.sh; test -s "$S" || exit 1; git show "$B:$S" > "$T/bs" || exit 1; sed -n 's/^pass "\(T-1192 [^"$\\]*\)"$/\1/p' "$T/bs" > "$T/lab" || exit 1; test -s "$T/lab" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; while IFS= read -r l; do grep -qxF "PASS: $l" "$T/log" || { rc=1; printf 'missing: %s\n' "$l"; }; done < "$T/lab"; grep -q '^PASS: T-1193 ' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC5** (D5; N1, N2.) The suite detects a revert. HEAD's committed tree is extracted with `git archive HEAD` into a scratch directory, and only `bin/codex-capture.sh` there is replaced with the base blob. The scratch copy's hygiene suite then exits non-zero (and not by timeout), and its log carries a line beginning `FAIL: T-1193`.
  - Positive control: the replaced script differs from the checkout's `bin/codex-capture.sh`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac5.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/h" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; git archive HEAD > "$T/h.tar" || exit 1; tar -xf "$T/h.tar" -C "$T/h" || exit 1; M="$T/h/tests/codex-skeleton-hygiene/run.sh"; test -s "$M" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/h/bin/codex-capture.sh" || exit 1; test -s "$T/h/bin/codex-capture.sh" || exit 1; cmp -s "$T/h/bin/codex-capture.sh" bin/codex-capture.sh; test "$?" = 1 || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$M" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || exit 1; tms "$M" "$T/log"; s=$?; test "$s" -ne 0 || rc=1; test "$s" -ne 99 || rc=1; grep -q '^FAIL: T-1193' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC6** (D4.) The diagnostics and the `--help` header. The exit-code section is the `--help` output from the line beginning `Exit codes:` to the first empty line. Within it, an item runs from a line beginning `<digit>` plus two spaces to the next such line.
  - **Positive controls at the base.** The base blob's `--help` contains no `unterminated`. Its `3` item contains `--publish` followed (after at most one character) by ` only`, and no `--observe`. That shows the item extraction reads the intended item.
  - **At HEAD:**
    - `--help` exits `0` and contains `unterminated` (case-insensitive). That the header also describes the duplicated-`type` rule is a QA reading item.
    - The `0` and `3` items each contain `--observe`. No absence is asserted on the `3` item, which may keep publish-only qualifiers for its publish-only causes (D4).
    - Running the script with no arguments, and with only `--stem T-000-x`, exits `2` with empty stdout. Stderr names `--alloc`, `--publish` and `--observe`, and no longer contains `exactly one of --alloc / --publish is required`.
  - adopter-surface: the header of bin/codex-capture.sh, printed by `--help`. Its exit-code section states that `--observe` exits `0` on success and `3` when the model is not established, and the extraction paragraph describes the unterminated-string and duplicated-`type` rules. The no-mode and positional-usage diagnostics name `--observe`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac6.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X=bin/codex-capture.sh; test -s "$X" || exit 1; git show "$B:$X" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; sec(){ awk 'index($0, "Exit codes:") == 1 { f = 1 } f && $0 == "" { exit } f' "$1"; }; item(){ awk -v d="$1" 'index($0, d "  ") == 1 { f = 1; print; next } f && $0 ~ /^[0-9]  / { exit } f' "$2"; }; bash "$T/base.sh" --help > "$T/hb" 2>&1 || exit 1; grep -qi unterminated "$T/hb"; test "$?" = 1 || exit 1; sec "$T/hb" > "$T/xb"; item 3 "$T/xb" > "$T/b3"; test -s "$T/b3" || exit 1; grep -qE 'publish.? only' "$T/b3" || exit 1; grep -qF -- '--observe' "$T/b3"; test "$?" = 1 || exit 1; bash "$X" --help > "$T/h" 2> /dev/null; test "$?" = 0 || rc=1; grep -qi unterminated "$T/h" || rc=1; sec "$T/h" > "$T/x"; for d in 0 3; do item "$d" "$T/x" > "$T/i$d"; test -s "$T/i$d" || rc=1; grep -qF -- '--observe' "$T/i$d" || rc=1; done; bash "$X" < /dev/null > "$T/o1" 2> "$T/e1"; test "$?" = 2 || rc=1; bash "$X" --stem T-000-x < /dev/null > "$T/o2" 2> "$T/e2"; test "$?" = 2 || rc=1; for e in 1 2; do test ! -s "$T/o$e" || rc=1; for q in --alloc --publish --observe; do grep -qF -- "$q" "$T/e$e" || rc=1; done; grep -qF 'exactly one of --alloc / --publish is required' "$T/e$e"; test "$?" = 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** (D4, droppable 1.) The unexpected-positional usage string. `bash bin/codex-capture.sh stray` exits `2`, and its stderr contains `unexpected positional argument: stray` and `--observe`.
  - Positive control: the base blob's stderr for the same call contains `unexpected positional argument: stray` and no `--observe`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac7.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X=bin/codex-capture.sh; test -s "$X" || exit 1; git show "$B:$X" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; bash "$T/base.sh" stray < /dev/null > /dev/null 2> "$T/eb"; test "$?" = 2 || exit 1; grep -qF 'unexpected positional argument: stray' "$T/eb" || exit 1; grep -qF -- '--observe' "$T/eb"; test "$?" = 1 || exit 1; bash "$X" stray < /dev/null > /dev/null 2> "$T/e"; test "$?" = 2 || rc=1; grep -qF 'unexpected positional argument: stray' "$T/e" || rc=1; grep -qF -- '--observe' "$T/e" || rc=1; test "$rc" -eq 0

- [ ] **AC8** (D3; Blast radius.) The other suites that execute `codex-capture.sh` stay green.
  - The set is derived at run time. It is every `tests/*/run.sh` that `grep -l -- codex-capture` names, except the hygiene suite, which **AC4** runs, plus `tests/bin-help/run.sh`, which reaches the script through `git ls-files -- bin/` rather than by name.
  - Each derived suite is scanned for the recursive-deletion pattern, with backslash-continued lines joined.
    - A suite that matches is never run locally. It is printed as CI-covered, and CI (**AC12**) runs it.
    - A scan that cannot read its suite fails the line.
    - Every other suite forms the run set.
  - Positive control: the run set contains `tests/codex-agents/run.sh`.
  - Each suite in the run set exits `0` under `tms` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac8.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; grep -l -- codex-capture tests/*/run.sh > "$T/l"; test "$?" = 0 || exit 1; { grep -vxF tests/codex-skeleton-hygiene/run.sh "$T/l"; printf '%s\n' tests/bin-help/run.sh; } | sort -u > "$T/suites"; grep -qxF tests/codex-agents/run.sh "$T/suites" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; : > "$T/run" || exit 1; : > "$T/ci" || exit 1; while IFS= read -r S; do test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" > "$T/j" || exit 1; grep -qE "$rd" "$T/j"; g=$?; if [ "$g" -eq 0 ]; then printf '%s\n' "$S" >> "$T/ci"; elif [ "$g" -eq 1 ]; then printf '%s\n' "$S" >> "$T/run"; else exit 1; fi; done < "$T/suites"; grep -qxF tests/codex-agents/run.sh "$T/run" || exit 1; while IFS= read -r S; do printf 'CI-covered, not run locally (recursive deletion): %s\n' "$S"; done < "$T/ci"; while IFS= read -r S; do tms "$S" "$T/log"; test "$?" -eq 0 || { rc=1; printf 'suite failed: %s\n' "$S"; }; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; done < "$T/run"; test "$rc" -eq 0

- [ ] **AC9** shellcheck exits `0` on `bin/codex-capture.sh` and `tests/codex-skeleton-hygiene/run.sh`, and neither file matches the recursive-deletion pattern once backslash-continued lines are joined.
  - check: rc=0; export LC_ALL=C; L=(bin/codex-capture.sh tests/codex-skeleton-hygiene/run.sh); for f in "${L[@]}"; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac9.XXXXXX") || exit 1; shellcheck "${L[@]}" > "$T/sc" 2>&1 || rc=1; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e'; for f in "${L[@]}"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" > "$T/j" || rc=1; grep -qE "$rd" "$T/j"; g=$?; test "$g" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC10** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `bin/codex-capture.sh`.
  - **Allowed members.**
    - `bin/codex-capture.sh`.
    - `tests/codex-skeleton-hygiene/run.sh`.
    - This task's records: `.shell-team/specs/T-1193-capture-extraction-fail-closed.md`, `.shell-team/provenance/T-1193.md`, `.shell-team/interventions/T-1193.md`, `.shell-team/reviews/T-1193.md`, `.shell-team/reviews/T-1193-drift.md`, and raw captures `.shell-team/reviews/T-1193-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`, the reserved taskless interventions file (`bin/check-interventions.sh:8`). T-1192's allow-list carried it, because the coordinating session can append to it during a task.
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac10.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/feature/755-codex-review-model-pin; then B=$(git merge-base refs/heads/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/feature/755-codex-review-model-pin; then B=$(git merge-base refs/remotes/origin/feature/755-codex-review-model-pin HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/codex-capture.sh "$T/s" || rc=1; grep -vxE 'bin/codex-capture\.sh|tests/codex-skeleton-hygiene/run\.sh|\.shell-team/(specs/T-1193-capture-extraction-fail-closed\.md|provenance/T-1193\.md|interventions/(T-1193|no-task)\.md|reviews/T-1193(-drift)?\.md|reviews/T-1193-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC11** Records conformant.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - Positive control: the spec, the checker and the board are each first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1193-ac11.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1193-capture-extraction-fail-closed.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** CI on the pull request is green, including the `shellcheck` step and the `Run codex-skeleton-hygiene suite`, `Run codex-agents fixture suite` and `Run bin-help suite` steps.
  - above-ceiling: the coordinating session, after the push and before the merge GO, recording the check run's result on the board. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **Rollouts the Codex CLI writes.** These are the shapes T-1192 measured:
   - codex-cli 0.160.0: a `session_meta` record carrying `payload.provenance.model`;
   - codex-cli 0.171.0 `review`: `payload.base_instructions.provenance.model`, plus `event_msg` `thread_settings`;
   - prompt passes: `session_meta`, `turn_context`, and a `world_state` record quoting `"model"` text inside a string.

   Every real record carries exactly one depth-1 `type` and nested `type` keys at depth 2 or deeper. Strings contain escaped quotes and escaped backslashes. **AC3** keeps the synthesized forms of these shapes on their T-1192 outcome. Real raw captures are gitignored and never tracked (T-1158), so no criterion reads them. A base-vs-HEAD `--observe` over whatever local raw captures exist is a non-gating reading item (Notes for engineer).
2. **Damaged or hand-made rollouts reaching `--thread-id`.** These are the issue's two shapes and their near relatives:
   - an unterminated value with one extra byte, with none, ending in a backslash, or ending in a carriage return (CRLF);
   - a lone trailing `"`;
   - an unterminated key;
   - an unterminated string in a line of an unread type, or one that swallows the `type` key;
   - a non-model value ending in an escaped quote;
   - a duplicated depth-1 `type`, with equal values, differing values in either order, or a non-string value beside a string one.

   These are reachable through truncation, hand editing or a future CLI defect. **AC1** and **AC2** cover them.
3. **Invocations.** `--publish --thread-id` with a named `--expect-model`, with `provider-configured`, and with no `--expect-model`. `--observe --thread-id` with and without `--expect-model`. Bare and positional misuse, and `--help`.
4. **Platforms.** bash on the CI runner (Linux) and on maintainer workstations, under `LC_ALL=C`.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **Lines the extraction never reads.** These are lines without `model` and without a backslash-`u` (the `:345` prefilter). An unterminated string or a duplicated `type` there is neither required nor forbidden to refuse.
2. **A `type` key spelled through a `\u` escape** (`"type"`) beside a plain `type`. The extraction does not decode escapes, so it cannot see this as a duplicate. The existing key-escape rule marks it malformed only on aggregated lines. This is disclosed as a residual for the follow-up, not engineered here.
3. **General JSON invalidity outside the two shapes.** Unbalanced or extra braces, bytes outside strings, invalid escapes other than `\u`, a raw newline inside a value, and a record split across physical lines.
4. **The completed-run gate's own tokenizer** (D-d, Non-goals).
5. **A rollout edited on disk between the pass and `--publish` or `--observe`, or more than one rollout per thread id.** The existing search refuses the latter.

<!-- END intent-block: T-1193 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | An unterminated string in any prefiltered line makes the observation malformed, whatever the line's type, including a swallowed `type` (D1) | **AC1** (`u7`, `u8`) |
| 2 | Unterminated key (D1) | **AC1** (`u6`) |
| 3 | Unterminated forms: one extra byte, none, trailing backslash, lone `"`, CRLF, escaped quote at line end (D1; Input space 2) | **AC1** (`u1`–`u5`, `u9`) |
| 4 | Duplicated depth-1 `type`: equal values, either order, non-string value (D2) | **AC2** (`d1`, `d2`, `d3`, `d5`) |
| 5 | Depth-2 `type` not counted (D2) | **AC2** (`d6`), **AC3** (`w5`) |
| 6 | Reuse `cause=malformed`; cause set, exit codes, refusal text and report-only suffix unchanged (D3) | **AC1**, **AC2** (three paths), **AC3** (T-1192 causes byte-identical) |
| 7 | Well-formed rollouts keep the T-1192 outcome byte for byte, including CRLF and an escaped backslash (D3) | **AC3** (`w1`–`w6`). Real captures are a non-gating reading item, because raw captures are gitignored (T-1158) and absent from a fresh clone or CI |
| 8 | A refused value is never echoed (D3; issue "never reported as a model") | **AC1**, **AC2** (`zq-model` on no stderr) |
| 9 | No-mode diagnostic names all three modes (D4) | **AC6** |
| 10 | `--help` exit `0` and `3` items name `--observe`; the publish-only causes inside `3` may keep their qualifier; `4` may stay (D4) | **AC6** (presence of `--observe` in both items; no absence asserted, by design) |
| 11 | Header describes the unterminated-string rule (D4) | **AC6** (`unterminated` token). That the header also describes the duplicated-`type` rule and no longer says other record types are "never read" in a way D1 contradicts is a QA reading item: the wording is free, and a token grep would freeze a vocabulary |
| 12 | Positional usage names `--observe` (D4) | **AC7** |
| 13 | Fixtures in the hygiene suite; T-1192 labels still print (D5) | **AC4** |
| 14 | Reverting the script makes the suite fail on a T-1193 case (D5) | **AC5** |
| 15 | Other suites executing the script stay green (Blast radius) | **AC8** |
| 16 | shellcheck clean, no recursive deletion (AC rules) | **AC9** |
| 17 | Scope, including no fixture files, no docs, no CHANGELOG (Non-goals) | **AC10** |
| 18 | Completed-run gate not changed (Non-goals, D-d) | **AC1**/**AC2** report-only paths (the gate still admits the fixtures); that its tokenizer text is unchanged is a QA reading item, because the gate shares no extractable boundary with the edited function |
| 19 | No general JSON validation; lines the extraction does not read are not judged (Non-goals) | info-only (not promoted to AC): an exclusion of scope. Input space out-of-scope 1 and 3 name the classes |
| 20 | Adopter docs and agent prose stay accurate and unedited (Non-goals) | **AC10** keeps them out of the diff; their accuracy is info-only (not promoted to AC), because they describe `malformed` without listing its shapes (Summarized sources) |
| 21 | No full-population sweep (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 22 | Records conformant | **AC11** |
| 23 | CI green | **AC12** (above-ceiling) |
| 24 | Pre-commitment and drop order | info-only (not promoted to AC): dispositions, not deliverable properties |

## Symmetry audit (parallel surfaces)

| Surface | Unterminated string (D1) | Duplicated `type` (D2) | Well-formed identity (D3) |
|---|---|---|---|
| `--publish --thread-id --expect-model <named>` | **AC1** publish-named | **AC2** publish-named | **AC3** `pe` |
| `--publish --thread-id` report-only | **AC1** report-only publish | **AC2** report-only publish | **AC3** `pn` |
| `--observe --thread-id --expect-model <named>` | **AC1** observe-named | **AC2** observe-named | **AC3** `oe` |
| `--observe --thread-id` report-only | **AC1** report-only observe | **AC2** report-only observe | **AC3** `on` |
| `--publish --thread-id --expect-model provider-configured` | not tested separately: the same report-only branch of `apply_model_gate` (`:403`) as no `--expect-model` | same | covered by T-1192's suite |
| Completed-run gate (`:707-842`) | out of scope (D-d) | out of scope (D-d) | unchanged; **AC3**'s identity covers its outcomes on these fixtures |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. Following T-1191 and T-1192, and the operator rulings relayed there (labelled relayed; the primary confirmation is held by the coordinating session), CI and this task's own check lines decide the impact.
- **Known readers.** The Grep tool over `tests/` finds these suites naming `codex-capture`: `tests/codex-agents`, `tests/codex-skeleton-hygiene`, `tests/gitignore-raw-dumps`, `tests/retro-inputs` and `tests/team-init`. `tests/bin-help` reaches the script through `git ls-files -- bin/`, an indirection a name search cannot see. **AC4** and **AC8** run all of them except any suite that contains a recursive deletion (`tests/retro-inputs/run.sh`, per the pre-freeze sweep). Such a suite is named as CI-covered and left to CI (**AC12**). The set is re-derived at run time.
  - Merged criteria in `.shell-team/specs` that run `codex-capture.sh` (T-107, T-1152, T-1192) were not re-run. That is a lower bound, disclosed per the deviation above. **AC3** keeps every non-malformed outcome byte-identical to the base.
- **Shipped prose naming the cause set.** `docs/adopting.md:328-332`, `docs/adopting.ja.md:330-333`, `agents/code-reviewer.md:48` and `agents/drift-evaluator.md:85` stay accurate, because none of them lists the malformed shapes. This is not edited in this task, and no follow-up is needed.
- **Adopter-side artifacts.** No generated file changes. `gen-codex-agents.sh` copies agent bodies, which this task does not touch. Past review records and imported rollouts are unchanged. The only behavioural change an adopter can meet is a rollout that is already damaged: it now refuses loudly under a named model, where before it might have passed.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| Unterminated string → `malformed` (D1) | not met | not met: no Codex CLI writes the shape | PATCH | a fail-closed bug fix |
| Duplicated top-level `type` → `malformed` (D2) | not met | not met: no Codex CLI writes the shape | PATCH | a fail-closed bug fix |
| Diagnostics and `--help` name `--observe` (D4) | not met | met: shown on misuse and `--help` | PATCH | a documentation fix to an existing mode |

The derived tier is PATCH, the maximum of the column. Sprint release: PATCH, v2.9.5 (relayed from the coordinating session's host-approved planning).

## Assumptions

- **Measured by this role** (Read, Grep and Glob tools). The working tree was clean at `7fccd1e0`. `.git/refs/heads/feature/759-capture-extraction-fail-closed`, `.git/refs/heads/feature/755-codex-review-model-pin` and `.git/refs/remotes/origin/feature/755-codex-review-model-pin` all hold `7fccd1e04e1fed0c806c1c521419cf56b5e77860`. `.git/packed-refs` maps `refs/remotes/origin/develop` to `75866424…`, and there is no local `refs/heads/develop`.
  - Every line anchor in `## Summarized sources`.
  - `exactly one of --alloc` occurs in `bin/codex-capture.sh` and `.shell-team/reviews/T-1192.md` only, so no test pins the `:486` string. This re-measures the Routing Map's relayed claim, and it holds.
  - No suite among `tests/{codex-agents,bin-help,team-init,gitignore-raw-dumps,retro-inputs,codex-skeleton-hygiene}/run.sh` matches the recursive-deletion pattern. That was a single-line match, without joining continuation lines. The check lines repeat the scan with lines joined.
  - `.gitattributes` carries no `export-ignore`, so `git archive HEAD` (**AC5**) includes `tests/` and `bin/`.
  - The hygiene suite runs `git` only inside throwaway repos under its own temp dir (`:1844-1851`), so a copy without `.git` can run it (**AC5**).
- **Relayed and re-measured here:** every Routing Map anchor (`:289`, `:306-341`, `:345`, `:356`, `:370`, `:394-411`, `:482`, `:486`, `:155-184`, `:708-769`), the cause set, and the claim that T-1192's cases live only in `tests/codex-skeleton-hygiene/run.sh`. All hold. The completed-run gate spans `:707-842`; its tokenizer is `:734-769`.
- **Relayed, not measurable by this role** (owner: the coordinating session, whose freeze run confirms them):
  - the issue #759 body (quoted in Summarized sources);
  - the sprint name and the release tier, PATCH v2.9.5;
  - the operator rulings behind the no-sweep deviation.
- **Predicted, unmeasured** (owner: the freeze run). A false prediction routes back here as a broken check line, never as a pass.
  - **The base outcome of each AC1 fixture.** `u1`, `u3`, `u4`, `u5`, `u6`, `u7`, `u8` and `u9` publish as `OK zq-model-1` at the base; `u2` refuses as `cause=mismatch`, because it reads as `zq-model-`. Traced through `:306-356`:
    - `u1` drops `X`; `u3` drops the backslash; `u5` drops the carriage return.
    - `u4` and `u6` leave a trailing unterminated token with no key.
    - `u7`'s line is `event_msg` and is not aggregated. `u8`'s line reads no type.
    - `u9`'s unterminated `note` is not a `model` key.
  - **The base outcome of each AC2 fixture.** `d1`, `d2`, `d3`, `d5` and `d6` all publish as `OK zq-model-1` at the base:
    - `d2`: the last `type` wins, giving `session_meta`.
    - `d3`: the last `type` wins, giving `event_msg`, so the line is not aggregated.
    - `d5`: a bareword `type` value assigns nothing.
  - **Every AC1/AC2/AC3 fixture passes the completed-run gate.** It tokenizes per line and reads only `payload.type`, `payload.item.*` and `task_complete`, so the `CommandExecution` and `task_complete` lines carry the run. **AC1**'s and **AC2**'s base controls assert this, and the line exits `1` if it is false.
  - **The help layout.** At the base, the `--help` exit-code section is bounded by an empty line (the bare `#` at `:185`), and its items begin with `<digit>` plus two spaces once the `--help` printer strips the comment prefix and leading blanks (`:216`).
- **Stacked branch.** This branch is classified as stacked behind an open predecessor at authoring time. The predecessor is T-1192 on `feature/755-codex-review-model-pin`, PR #758, base `develop`; its open state is relayed by the coordinating session. The declaration region's four-arm discriminator follows from that.
  - The arms are tried in order: the local predecessor branch, the remote-tracking predecessor, then the integration branch `develop` (local, then remote-tracking), which is the era-change fallback once the predecessor is gone.
  - Route-back residuals, disclosed rather than engineered around:
    - the predecessor branch deleted without being merged;
    - the predecessor rebased, force-pushed or squash-merged after this branch was cut. A squash merge makes the fallback resolve to `75866424`, before T-1192, so every base-reading criterion would compare against a script without the model gate;
    - a checkout that never fetched the predecessor. That checkout fetches it first; freezing on the fallback there is ruled out.
- **Borrowed tokens.** `cause=malformed`, `model not established`, `model=unavailable`, ` model=` and the T-1192 `pass` labels are vocabulary T-1192 coined. Every criterion asserts them by presence only, or derives them from the base blob (**AC4**), so no literal count premise rests on them.
  - **One zero-at-base premise rests on a borrowed, generic word:** `unterminated` does not occur in the base script (**AC6**'s base control). This role measured it with a case-insensitive Grep-tool count over `bin/codex-capture.sh` at `7fccd1e0`, header lines `1-99` included: 0. The freeze run measures `git show "$B:bin/codex-capture.sh" | grep -ci unterminated` and records the value here.
  - The own-coinage tokens `PASS: T-1193 ` and `FAIL: T-1193` are expected at 0 before implementation.
- **Coupled suites, measured live by the pre-freeze sweep (2026-11-21, relayed by the coordinating session).** `tests/retro-inputs/run.sh` matches the recursive-deletion pattern. This role's own single-line Grep missed it; that earlier claim is withdrawn.
  - So **AC8** runs only the derived suites that do not match the pattern. It names any suite that does match as CI-covered and never runs it locally.
  - **AC8** predicts that `tests/gitignore-raw-dumps/run.sh` exits `0` under `tms`, if it is in the run set. No earlier spec ran it that way.
- **Withdrawn criterion (pre-freeze, never frozen).** A former AC13 compared base and HEAD `--observe` over tracked rollout captures. Raw captures are gitignored and never tracked (T-1158), so its population was empty by construction, and it was removed. Real-shape coverage rests on **AC3**'s synthesized 0.160.0, 0.171.0 and prompt shapes.
- **Pre-implementation expectation (for the freeze read).** At freeze, HEAD's script equals the base blob.
  - **AC1** and **AC2**: the base controls pass, then the line is red on the first HEAD fixture.
  - **AC3**: red only on its "HEAD differs" control.
  - **AC4**: red on the missing `PASS: T-1193 ` line.
  - **AC5**: red. Its "script differs" control fails, the suite then still runs on the extracted tree and passes on the base script, and no `FAIL: T-1193` line appears.
  - **AC6** and **AC7**: the base controls pass, then the line is red at HEAD.
  - **AC8** and **AC9**: green (AC8 predicted, see above).
  - **AC10**: red on its positive control. The spec and board edits are allowed members.
  - **AC11**: green when the board entry is conformant.
  - **AC12**: `SKIP`.

## Open questions

- None. The design points were decided by the coordinating session (D-a to D-e) and are recorded as D1–D4 and Non-goals.

## Notes for engineer

- **Files.** The allow-list is in **AC10**: `bin/codex-capture.sh`, `tests/codex-skeleton-hygiene/run.sh`, and this task's records. Fixtures are synthesized inline in the suite, not as files under `fixtures/`.
- **Where to place the T-1193 block in the suite.** Put it **before** the T-1192 mutation self-check (`:2135`). That self-check's `sed` probes anchor on the text of `:370` and `:356`, and it fails a probe whose expression changes nothing.
  - If your change rewrites those lines, update the probes' `sed` expressions so they still mutate the intended guard, and keep their `pass`/`fail` labels byte-identical (**AC4** derives the T-1192 labels from the base blob).
  - With the T-1193 block placed earlier, the reverted-script run in **AC5** fails on a `T-1193` case first, before any probe written against your new text runs.
- **Labels.** Every T-1193 `pass` line starts `T-1193 ` and every T-1193 `fail` message starts `T-1193`.
- **Extraction.** Decide unterminated-ness while tokenizing (whether the closing quote was found), not from the token's last byte. A last-byte test passes `u9` (`"abc\"`) and the lone `"` in `u4`, and fails `w6` (`"abc\\"`), which must stay well-formed.
  - The rule applies to every line past the `:345` prefilter, before and independent of the `line_type` filter at `:370`.
  - Count depth-1 `type` **keys**, not string values, so `d5` (`"type":1,"type":"session_meta"`) is caught.
- **No echo.** A refusal prints no model value, no line bytes and no account identifier.
- **Help text.** Keep the exit-code items in their `<digit>` plus two spaces layout (**AC6** reads items that way), and keep the section ending at the bare `#` line. The `4` item may stay `--publish`-only. Reconcile the `:192-193` "is never read" sentence with D1 (a QA reading item).
- **Mutation probes (mechanism class).** In a scratch copy, break each never-dropped rule once, confirm the matching criterion goes red, then restore it. For example:
  - limit the unterminated check to lines whose type was read (**AC1** `u7`, `u8`);
  - use a last-byte test (**AC1** `u9`, **AC3** `w6`);
  - count only string `type` values (**AC2** `d5`);
  - count `type` at any depth (**AC2** `d6`, **AC3** `w5`).
- **Local real captures (non-gating reading item).** Raw captures are gitignored (T-1158), so no criterion reads them. Where a checkout holds local `*.jsonl` raw captures under the reviews dir, QA may copy each into a temp `CODEX_HOME` under a synthetic id and compare base vs HEAD `--observe` output. A difference is a finding to read, never an automatic `FAIL`.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** `codex-capture.sh` is a shipped `bin/` gate and gets full strength. The inline check lines get dev-scaffold depth (operator ruling 2026-08-22).
