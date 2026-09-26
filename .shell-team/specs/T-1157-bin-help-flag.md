# Every `bin/` script answers `--help` / `-h` as its first argument with usage surfaced from its own header comment on stdout and exit 0 (issue #592)

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1157

**Branch**: `feature/592-bin-help-flag`, cut from the tip of `feature/593-codex-host-not-logged-in-diagnosis` (T-1156) at `55a276e2`. T-1156's pull request #617, T-1155's #613 and T-1154's #609 are still open (relayed; see `## Assumptions`), so this branch is **stacked**. Every criterion that reads a base-side blob or a committed range resolves the branch point through the one three-arm expression declared as `- base-ref-discriminator:` below, spelled byte-identically in each (**AC1**, **AC3**, **AC4**, **AC5**).

## Problem

On an adopter run driven from a Codex CLI host, the orchestrating session called `bin/log-run.sh --help` twice to learn its grammar before writing the task's first telemetry span. Both calls failed with a usage error, the session skipped the record, and the task finished with no telemetry row at all, so its duration cannot be reconstructed. 14 of the 55 `bin/*.sh` scripts answer `--help` with an error rather than with usage. `--help` is the first thing an agent without the script's usage in context tries, and a usage question answered with a usage error teaches the caller that the tool is broken.

## Summarized sources

- **GitHub issue #592** — quoted verbatim below as relayed by the coordinating session, which read it on 2026-09-26. This role did not open it. Distinctions carried over: the trigger is `--help` / `-h` as the **first** argument ("before any other argument validation runs"), not as the only argument; usage goes to **stdout** with exit **0**; the usage text is **surfaced from the existing header comment, not written**; a fixture suite (one shared case over `bin/*.sh` is allowed) locks the count; recovering the adopter run's lost telemetry is out of scope; the `bin/` portability rule is unaffected. The issue's own count (41 exit 0, 14 do not) was measured at `8723b47d` with `bash "$s" --help`, a different method from the derivation below, which greps for the arm; both name the same 14. These distinctions are carried into the Goal, Non-goals, **AC1**, **AC2** and **AC5**. The body, verbatim:

  > Title: bin/: 14 of 55 scripts refuse `--help` (usage error, exit 2) — an orchestrating Codex session lost a task's whole telemetry after `log-run.sh --help` failed twice
  > What happened: On an adopter run driven from the Codex CLI host (plugin 2.7.3, Claude Code 2.1.281, codex-cli 0.156.1), the orchestrating session called `bin/log-run.sh --help` twice to learn the argument grammar before writing the task's first telemetry span. Both calls exited with an argument error (`log-run: missing <loop_id> as first argument`, exit 2). The session moved on, and the task finished both gates green with **no span or event row at all** in `.shell-team/runs/shell-team.jsonl` — so the task's wall-clock duration, the mode-A2 measurement this repository asks adopters to report, cannot be reconstructed from telemetry. Measured in this checkout at `8723b47d`: of the 55 scripts under `bin/`, 41 exit 0 on `--help` and **14 do not**: `check-contract.sh` `check-design-note.sh` `check-handoff.sh` `check-playbook.sh` `check-readme-version.sh` `check-retro.sh` `check-run.sh` `cluster-failures.sh` `codex-capture.sh` `goal-state.sh` `log-run.sh` `loop-guard.sh` `rework-digest.sh` `rollup-runs.sh` (Measurement: `for s in bin/*.sh; do bash "$s" --help >/dev/null 2>&1 || echo "$s"; done`.)
  > Why it matters: `--help` is the first thing an agent that does not hold the script's usage in context will try, on either host. A script that answers a usage question with a usage *error* teaches the caller that the tool is broken, and the caller's cheapest move is to skip the record — exactly what happened here. The loss is not the one call; it is every downstream measurement that depended on the row it never wrote.
  > Expected: Every script under `bin/` accepts `--help` (and `-h`) as its first argument, prints its usage block to stdout, and exits 0, before any other argument validation runs. The usage text already exists as a header comment in each of the 14; this is surfacing it, not writing it. A fixture-suite case per script (or one shared case that iterates `bin/*.sh`) locks the behaviour so the count cannot regress.
  > Prior art: Issue search for `--help` / usage handling across `bin/` found no existing issue. The `bin/` portability rule (pure bash, zero-dependency, shellcheck-clean) is unaffected.
  > Out of scope: Recovering the lost telemetry for the adopter run (not possible; recorded as a telemetry gap in that run's own report).

- **The population derivation** (produced by the coordinating session with `bin/derive-populations.sh`, relayed and embedded verbatim; this role cannot run it). Distinction: the set is `bin/*.sh` (55) and the arm test is the literal `--help|-h)`; the 14 lacking it are the ones this task changes. The 41-item bucket is reproduced by the command, not listed here.

  - reproduce: bash bin/derive-populations.sh --label t1157-help-arm --set all="git ls-files -- 'bin/*.sh'" --set has-help-arm="git grep -l -E -e '--help[|]-h[)]' -- 'bin/*.sh'" --accept-status has-help-arm=1

  <!-- BEGIN derivation: t1157-help-arm -->
  - derived-by: bin/derive-populations.sh
  - locale: LC_ALL=C
  - set: all — status: 0 — lines: 55 — items: 55 — command: git ls-files -- 'bin/*.sh'
  - set: has-help-arm — status: 0 — lines: 41 — items: 41 — command: git grep -l -E -e '--help[|]-h[)]' -- 'bin/*.sh'
  - union: items: 55
  - bucket: all — items: 14
    - bin/check-contract.sh
    - bin/check-design-note.sh
    - bin/check-handoff.sh
    - bin/check-playbook.sh
    - bin/check-readme-version.sh
    - bin/check-retro.sh
    - bin/check-run.sh
    - bin/cluster-failures.sh
    - bin/codex-capture.sh
    - bin/goal-state.sh
    - bin/log-run.sh
    - bin/loop-guard.sh
    - bin/rework-digest.sh
    - bin/rollup-runs.sh
  - bucket: all+has-help-arm — items: 41
  <!-- END derivation: t1157-help-arm -->

- **The 14 scripts' heads** (read first-hand at `55a276e2`: each file from line 1 to its `set -euo pipefail` line, plus the argument handling right after it). Distinctions carried over:
  - Every line from 2 up to the `set -euo pipefail` line is a comment or a blank line. That line is `:25` check-contract, `:39` check-design-note, `:22` check-handoff, `:152` check-playbook, `:36` check-readme-version, `:69` check-retro, `:49` check-run, `:65` cluster-failures, `:185` codex-capture, `:35` goal-state, `:184` log-run, `:65` loop-guard, `:115` rework-digest and `:64` rollup-runs. Line 2 of each names the script's own file name.
  - **12 of the 14 headers carry a `Usage` comment line**, and **two do not**: `check-contract.sh` and `check-handoff.sh`. Their headers describe the input (`tasks/loops/*.contract.yaml`, `tasks/todo.md`) and, for check-contract, the exit codes, but they give no invocation line. So the issue's "the usage text already exists as a header comment in each of the 14" holds for 12 of 14 (see `## Assumptions`).
  - How each script currently handles a leading `--help` (this re-reads the Routing Map's classes). (A) The first argument is read as a file path and the script exits 2 with "cannot read" or a usage line: check-contract (`:27`–`:31`), check-handoff (`:24`–`:28`), check-readme-version (after resolving `ROOT` and reading the manifest, `:38`–`:49`), check-playbook, check-retro, cluster-failures, rollup-runs and check-run. (B) An unknown flag is a usage error, exit 2 on stderr: check-design-note (`:51`–`:52`), codex-capture (`:241`), goal-state (its `usage()` at `:39`–`:42` prints to **stderr**), and rework-digest (its `usage()` heredoc at `:117`ff prints to **stderr**). (C) loop-guard (`:78`–`:81`) prints `STOP:guard_error` on stdout and exits 2 for any leading `--*`; its header `:52`–`:53` states "stdout always carries the decision". log-run (`:200`–`:201`) dies with "missing <loop_id> as first argument" on a leading `--*`. `-h` passes log-run's loop_id charset (`:204`) and fails later on missing flags.
- `bin/check-pii-shapes.sh:278`–`:294` (read first-hand). Distinction: the precedent for surfacing the header, where `print_help` finds the header's end at the `set -euo pipefail` line rather than a hardcoded range. Its comment records that a hardcoded `sed -n '2,Np'` range truncated `--help` once the header grew. It uses `grep | head`, which the Routing Map advises against under `pipefail`.
- `bin/install` (read `:1`–`:60`, `:118`). Distinction: tracked under `bin/`, extension-less (so `bin/*.sh` misses it), and already armed with `--help|-h)` at `:118`. Its header `Usage` block is at `:13`–`:15`.
- `tests/bin-exec-bit/run.sh` (read first-hand in full). Distinctions: this is the precedent for enumerating `bin/` by `git ls-files -s -- bin/` rather than a `bin/*.sh` glob, with `bin/install` named as the positive control a glob would miss. It fails closed on empty output or a non-zero `git` status. Its tests/ rule requires every tracked `tests/` entry whose blob begins `#!` to be mode 100755, and the reverse. `pass` prints `PASS: <text>`; `fail` prints `FAIL: <text>` to stderr.
- `.github/workflows/check-handoff.yml` (read `:20`–`:34`, `:274`–`:275`). Distinctions: shellcheck targets are listed on the `shellcheck` step's `run:` line (`:29`), with a separate `shellcheck (T-1151 additions)` step at `:31`–`:32`. Every one of the 56 tracked `bin/` entries already appears on one of those lines. Each suite is its own `run: bash tests/<suite>/run.sh` step.
- `.shell-team/test-recipe.md` `## CI parity` (`:57`–`:84`, read). Distinction: the static-analysis block (`:72`–`:74`) mirrors the workflow's `shellcheck` line. It does not currently carry the T-1151 additions, a pre-existing lag this task does not repair.
- `CONTRIBUTING.md` (headings and `:23`–`:75` read). Distinction: no section states a rule for new `bin/` scripts, and `--help` occurs zero times in the file.
- `docs/adopting.md` (headings; `## How to run` `:143`–`:187`; `## Operating rules` `:1350`–`:1357`) and `docs/adopting.ja.md` (grep for `--help`). Distinctions: the adopter's invocation form is `bash "<plugin root>/bin/<script>"` (e.g. `:217`, `:221`). The only `--help` occurrences are `codex plugin --help` / `codex plugin marketplace upgrade --help` (en `:410`, `:449`; ja `:426`, `:456`), which are Codex CLI's own flags, not ours. No sentence states that the plugin's scripts answer `--help`.
- `README.md` / `README.ja.md` (grep for `--help`). Distinction: they cite `bash resolve-executor.sh --help`, `derive-populations.sh --help` and `check-count-claims.sh --help` (en `:242`, `:312`, `:343`), all of which are among the 41 already armed. This task makes none of these false.
- `tests/` suites of the 14 (grep for `--help` / `-h`). Distinction: none of `tests/{check-contract,check-design-note,check-handoff,check-playbook,check-readme-version,check-retro,check-run,cluster-failures,codex-skeleton-hygiene,goal-state,log-run,loop-guard,rework-digest,rollup-runs}/` exercises `--help` or `-h` today, so no existing assertion pins the refusal.
- `bin/check-adopter-docs.sh` (distinction carried from the shape model `.shell-team/specs/T-1155-gitignore-published-raw-captures.md`, which read it): a `yes` declaration needs an `- adopter-surface:` line or a waiver, and each `this-task` `- shipped-docs:` path must be a literal substring of some `- check:` or `- adopter-surface:` line of the same spec.
- `.shell-team/specs/T-1155-gitignore-published-raw-captures.md` and `.shell-team/specs/T-1156-codex-host-not-logged-in-diagnosis.md:42` (read first-hand). Distinction: they give the shape of the declarations, allow-list, correspondence table, pre-commitment and blast radius, and the three-arm discriminator spelling.

## Goal

<!-- BEGIN intent-block: T-1157 -->

- user-visible: yes — an adopter's session, on either host, that asks one of the 14 `bin/` scripts for `--help` or `-h` now gets that script's usage on stdout with exit 0, instead of a usage error that invites it to skip the call, and the adopting guide says every `bin/` script answers `--help`. Nothing new becomes possible — this fixes the existing scripts' answer to a usage question on the shipped default path — so the tier is PATCH.
- verification-class: mechanism — the diff reaches 14 scripts under `bin/`, a new suite under `tests/`, and the CI workflow.
- verification-ceiling: unit-and-static — every criterion is settled in a plain checkout. The means are: running the scripts with `bash` from scratch directories under `$TMPDIR` with stdin at `/dev/null`; comparing against branch-point blobs read with `git show`; a shipped suite's or checker's exit code; string or paragraph presence in a file or its branch-point blob; or a `git diff` / `git ls-files` read. No criterion needs a Codex CLI, a real adopter repository or a network.
- base-ref-discriminator: `B=$(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "feature/593-codex-host-not-logged-in-diagnosis" HEAD; elif git show-ref --verify --quiet refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis" HEAD; else git merge-base "develop" HEAD; fi)` — this is required rather than `not-applicable`. **AC1**, **AC3**, **AC4** and **AC5** read base-side blobs or the committed range, and the immediate predecessor T-1156 (PR #617) is open at authoring time. The predecessor resolves in `refs/heads/` and in `refs/remotes/origin/` (both read first-hand as `55a276e211d7bd8858779208956a7c58b937c6fe`), so arm 1 is selected today. `develop` is the integration-branch parameter. The expression is spelled byte-identically in each of the four criteria.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: CONTRIBUTING.md — this-task

**Goal (one sentence).** Each of the 14 `bin/*.sh` scripts that carry no `--help|-h)` arm at the branch point, given `--help` or `-h` as its **first** argument (whatever follows it), prints to stdout text surfaced from its own existing header comment — every printed line a header comment line, naming the script, and including the header's `Usage` line where the header has one — and exits 0 before any other processing; every other invocation of those scripts keeps its exit code, stdout and stderr byte-for-byte; every header comment stays byte-unchanged except `bin/loop-guard.sh`'s, which now names `--help` as the exception to "stdout always carries the decision"; a new CI-wired suite `tests/bin-help/run.sh` proves, for every tracked `bin/` entry (`bin/install` included), that `--help` and `-h` answer with exit 0 and non-empty stdout without reading stdin or writing into an empty working directory, and any already-armed script failing that invariant is fixed here; `docs/adopting.md`, `docs/adopting.ja.md` and `CONTRIBUTING.md` state that every `bin/` script answers `--help` / `-h`; and no file is added to or removed from `bin/`.

## Non-goals

- **A file path, loop_id, subcommand or other operand literally spelled `--help` or `-h` can no longer be passed as the first argument** of the 14. That is the accepted cost of the issue's first-argument trigger. (**AC1**)
- **`bin/loop-guard.sh --help` no longer prints `STOP:guard_error`**, and its header contract is amended to say so. Every other leading `--*` still prints `STOP:guard_error` and exits 2. (**AC1**, **AC3**)
- **The existing stderr `usage()` of `bin/rework-digest.sh` and `bin/goal-state.sh` is not reused** for `--help`. Their stderr usage paths are unchanged. (**AC1** — every printed line must be a header line; **AC3**)
- **No new usage prose is written.** The headers of `bin/check-contract.sh` and `bin/check-handoff.sh`, which carry no `Usage` line, are surfaced as they stand. Adding a usage line to them belongs to a follow-up, not here. (**AC1** — header byte-unchanged)
- **No change to any non-`--help` / `-h` behaviour** of the 14 — exit codes, stdout, stderr. (**AC3**, **AC6**)
- **No new file under `bin/`**, no shared or sourced help helper: each script stays standalone and invocable by path. (**AC5**)
- **The 41 already-armed scripts and `bin/install` change only if they fail the suite's invariant** (`--help` or `-h` as the sole argument). If one fails, it is fixed here as the same class. Their behaviour for `--help` followed by further arguments is not measured or changed. (**AC2**, **AC5**)
- **Recovering the adopter run's lost telemetry** (the issue's out-of-scope). Info-only.
- **`README.md` / `README.ja.md` are unchanged**: their `--help` citations name already-armed scripts and stay true. (**AC5**)
- **No per-task full-population two-arm sweep, no version bump, no CHANGELOG entry in this diff.** The sweep runs once at the release under the operator's standing mode-A2 ruling. The CHANGELOG line drafted below lands on the release branch. (**AC5**)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`. **AC1** and **AC3** derive the 14 at run time from the branch-point blobs: they take the `bin/*.sh` paths in `git ls-tree "$B"` that `git grep -l -E -e '--help[|]-h[)]' "$B"` does not list. The set is therefore pinned to a named ref and needs no staleness trigger. Positive controls check that the derived set is non-empty, that it contains `bin/log-run.sh`, and that it does not contain the already-armed `bin/team-paths.sh`.

- [ ] **AC1** The 14 answer `--help` / `-h` as the first argument by surfacing their own header. This is a **never-dropped** component. For each of the 14, run from an empty scratch working directory with stdin at `/dev/null`, `TEAM_RUN_BASE` unset and `TEAM_RUNS_DIR` / `RUNS_DIR` pointing at a non-existent scratch path, four invocations are checked: `--help`, `-h`, `--help t1157-extra-arg` and `-h t1157-extra-arg`. Each must exit `0` with non-empty stdout, and all four must print byte-identical stdout. After all four, the working directory is still empty and the runs path still does not exist. The stdout names the script's file name and contains no line exactly `STOP:guard_error`. Each non-blank stdout line, with leading and trailing whitespace trimmed, equals some comment line of the script's header region (the lines above its first `set -euo pipefail` line) with the leading `#` and following whitespace removed. Where that header has a `Usage` comment line, stdout has a line beginning `Usage`. The header region is byte-identical to its branch-point blob's for every script except `bin/loop-guard.sh`, whose header region names `--help` and whose branch-point header carried `stdout always carries the decision`.
  - check: rc=0; B=$(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "feature/593-codex-host-not-logged-in-diagnosis" HEAD; elif git show-ref --verify --quiet refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis" HEAD; else git merge-base "develop" HEAD; fi) || exit 1; test -n "$B" || exit 1; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac1.XXXXXX") || exit 1; git ls-tree -r --name-only "$B" -- bin/ > "$T/lt" || exit 1; grep '\.sh$' "$T/lt" | LC_ALL=C sort > "$T/all"; git grep -l -E -e '--help[|]-h[)]' "$B" -- 'bin/*.sh' > "$T/ar" || exit 1; sed "s|^$B:||" "$T/ar" | LC_ALL=C sort > "$T/arm"; LC_ALL=C comm -23 "$T/all" "$T/arm" > "$T/set"; test -s "$T/set" || exit 1; grep -qxF bin/log-run.sh "$T/set" || exit 1; if grep -qxF bin/team-paths.sh "$T/set"; then exit 1; fi; mkdir "$T/cwd" || exit 1; while IFS= read -r s; do f="$R/$s"; n=${s##*/}; test -s "$f" || { rc=1; continue; }; git show "$B:$s" | awk '/^set -euo pipefail$/{exit} {print}' > "$T/hb"; awk '/^set -euo pipefail$/{exit} {print}' "$f" > "$T/hh"; test -s "$T/hb" || rc=1; if [ "$s" = bin/loop-guard.sh ]; then grep -qF -- '--help' "$T/hh" || rc=1; grep -qF -- 'stdout always carries the decision' "$T/hb" || rc=1; else cmp -s "$T/hb" "$T/hh" || rc=1; fi; i=0; for a in --help -h; do for x in '' t1157-extra-arg; do i=$((i+1)); ( cd "$T/cwd" && env -u TEAM_RUN_BASE TEAM_RUNS_DIR="$T/probe" RUNS_DIR="$T/probe" bash "$f" "$a" ${x:+"$x"} < /dev/null > "$T/o$i" 2> /dev/null ); test "$?" -eq 0 || rc=1; test -s "$T/o$i" || rc=1; cmp -s "$T/o1" "$T/o$i" || rc=1; done; done; test -z "$(find "$T/cwd" -mindepth 1 -print)" || rc=1; test ! -e "$T/probe" || rc=1; grep -qF -- "$n" "$T/o1" || rc=1; if grep -qxF 'STOP:guard_error' "$T/o1"; then rc=1; fi; awk 'NR==FNR { h=$0; if (h !~ /^#/) next; sub(/^#[ \t]*/, "", h); sub(/[ \t]+$/, "", h); H[h]=1; next } { l=$0; sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l); if (l != "" && !(l in H)) bad=1 } END { exit bad ? 1 : 0 }' "$T/hh" "$T/o1" || rc=1; if grep -Eq '^#[[:space:]]*Usage' "$T/hh"; then grep -Eq '^[[:space:]]*Usage' "$T/o1" || rc=1; fi; done < "$T/set"; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** A CI-wired suite locks `--help` / `-h` for every tracked `bin/` entry. `tests/bin-help/run.sh` is tracked at index mode `100755`. `bash tests/bin-help/run.sh` must exit `0`, print non-empty stdout, and print no `FAIL` line on either stream. It must print a `PASS: population ` line: its positive control, a population re-derived from `git ls-files` over `bin/` and asserted non-empty, failing closed on an empty listing or a non-zero `git` status. For each member and each flag, it prints one `PASS: ` line naming the member's path and the flag, the flag preceded by a space. Among these are lines for `bin/log-run.sh`, `bin/loop-guard.sh`, the already-armed `bin/team-paths.sh` and the extension-less `bin/install`. Each case runs the member with the flag as its only argument, stdin at `/dev/null`, from an empty scratch working directory under `$TMPDIR`. It asserts exit `0`, non-empty stdout, and that the directory is still empty afterwards (`find … -mindepth 1`). The suite source reads its population with `ls-files … -- bin/`, redirects stdin from `/dev/null`, and carries `-mindepth 1`. `.github/workflows/check-handoff.yml` has a step `run: bash tests/bin-help/run.sh` and names `tests/bin-help/run.sh` on a `run: shellcheck …` line. `.shell-team/test-recipe.md`'s `## CI parity` section names it on its `shellcheck …` line. Whether removing one script's arm turns the suite red (the negative control) is for QA to observe and report.
  - check: rc=0; S=tests/bin-help/run.sh; W=.github/workflows/check-handoff.yml; Q=.shell-team/test-recipe.md; for f in "$S" "$W" "$Q"; do test -s "$f" || exit 1; done; test "$(git ls-files -s -- "$S" | cut -c1-6)" = 100755 || rc=1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac2.XXXXXX") || exit 1; bash "$S" > "$T/out" 2> "$T/err" < /dev/null; test "$?" -eq 0 || rc=1; test -s "$T/out" || rc=1; test "$(cat "$T/out" "$T/err" | grep -c '^FAIL' || true)" = 0 || rc=1; grep -q '^PASS: population ' "$T/out" || rc=1; for p in bin/log-run.sh bin/loop-guard.sh bin/team-paths.sh bin/install; do for fl in ' --help' ' -h'; do grep '^PASS: ' "$T/out" | grep -F -- "$p" | grep -qF -- "$fl" || rc=1; done; done; grep -Eq 'ls-files.* -- bin/' "$S" || rc=1; grep -Eq '<[[:space:]]*/dev/null' "$S" || rc=1; grep -qF -- '-mindepth 1' "$S" || rc=1; grep -Eq '^[[:space:]]+run: bash tests/bin-help/run.sh[[:space:]]*$' "$W" || rc=1; grep -E '^[[:space:]]+run: shellcheck ' "$W" | grep -qF -- 'tests/bin-help/run.sh' || rc=1; awk '/^## CI parity[[:space:]]*$/ {f=1; next} /^## / {f=0} f && /^[[:space:]]*shellcheck / && index($0, "tests/bin-help/run.sh") {n++} END {exit n ? 0 : 1}' "$Q" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC3** Every other invocation of the 14 is byte-for-byte unchanged. Each of the 14 is copied in turn from its branch-point blob and from HEAD into the same scratch path `bin/<name>`, and run from that scratch directory by the relative path `bin/<name>` with stdin at `/dev/null` and `TEAM_RUN_BASE`, `TEAM_RUNS_DIR` and `RUNS_DIR` unset. Three probes are run: no argument, the unknown flag `--t1157-unknown-flag`, and the operand `t1157-missing-operand`. Exit status, stdout and stderr are byte-identical between the base copy and the HEAD copy for every probe. Positive control: the base copy of every one of the 14 exits `2` on the unknown-flag probe, so each probe reaches a usage or argument-error path rather than a trivially empty one.
  - check: rc=0; B=$(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "feature/593-codex-host-not-logged-in-diagnosis" HEAD; elif git show-ref --verify --quiet refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis" HEAD; else git merge-base "develop" HEAD; fi) || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac3.XXXXXX") || exit 1; git ls-tree -r --name-only "$B" -- bin/ > "$T/lt" || exit 1; grep '\.sh$' "$T/lt" | LC_ALL=C sort > "$T/all"; git grep -l -E -e '--help[|]-h[)]' "$B" -- 'bin/*.sh' > "$T/ar" || exit 1; sed "s|^$B:||" "$T/ar" | LC_ALL=C sort > "$T/arm"; LC_ALL=C comm -23 "$T/all" "$T/arm" > "$T/set"; test -s "$T/set" || exit 1; grep -qxF bin/log-run.sh "$T/set" || exit 1; if grep -qxF bin/team-paths.sh "$T/set"; then exit 1; fi; while IFS= read -r s; do n=${s##*/}; for side in base head; do rm -rf "$T/arm.d"; mkdir -p "$T/arm.d/bin" || exit 1; if [ "$side" = base ]; then git show "$B:$s" > "$T/arm.d/bin/$n" || rc=1; else cp "$s" "$T/arm.d/bin/$n" || rc=1; fi; i=0; for a in '' --t1157-unknown-flag t1157-missing-operand; do i=$((i+1)); ( cd "$T/arm.d" && env -u TEAM_RUN_BASE -u TEAM_RUNS_DIR -u RUNS_DIR bash "bin/$n" ${a:+"$a"} < /dev/null > "$T/$side.$i.o" 2> "$T/$side.$i.e"; printf '%s\n' "$?" > "$T/$side.$i.r" ); done; done; test "$(cat "$T/base.2.r")" = 2 || rc=1; for i in 1 2 3; do for k in o e r; do cmp -s "$T/base.$i.$k" "$T/head.$i.$k" || rc=1; done; done; done < "$T/set"; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** The shipped texts state the rule. In each of `docs/adopting.md` and `docs/adopting.ja.md`, one paragraph (a blank-line-delimited block) names `` `--help` ``, `` `-h` `` and `bin/`: every `bin/` script answers `--help` / `-h` as its first argument with usage on stdout and exit 0. No paragraph of either page's branch-point blob names both `` `--help` `` and `` `-h` ``, which is the positive control that the paragraph is new. One paragraph of `CONTRIBUTING.md` names `--help` and the `` `bin-help` `` suite by name: a new `bin/` script must answer `--help` / `-h`, and that suite enforces it in CI. `CONTRIBUTING.md` carries no literal `tests/<name>/run.sh` path, so T-1000 AC19's rule stays true (v2, 2026-09-26: v1 required the literal path, which that rule forbids). The branch-point `CONTRIBUTING.md` does not name `` `bin-help` ``.
  - adopter-surface: `docs/adopting.md` / `docs/adopting.ja.md` (one paragraph stating the `--help` / `-h` rule for every `bin/` script, near where the adopter's `bash "<plugin root>/bin/<script>"` invocation is described), and `CONTRIBUTING.md` (the rule for new `bin/` scripts and the suite that enforces it).
  - check: rc=0; B=$(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "feature/593-codex-host-not-logged-in-diagnosis" HEAD; elif git show-ref --verify --quiet refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis" HEAD; else git merge-base "develop" HEAD; fi) || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac4.XXXXXX") || exit 1; for f in docs/adopting.md docs/adopting.ja.md CONTRIBUTING.md; do test -s "$f" || rc=1; done; for f in docs/adopting.md docs/adopting.ja.md; do awk -v RS= 'index($0, "`--help`") && index($0, "`-h`") && index($0, "bin/") {n++} END {exit n ? 0 : 1}' "$f" || rc=1; git show "$B:$f" > "$T/b" 2> /dev/null || rc=1; test -s "$T/b" || rc=1; if awk -v RS= 'index($0, "`--help`") && index($0, "`-h`") {n++} END {exit n ? 0 : 1}' "$T/b"; then rc=1; fi; done; awk -v RS= 'index($0, "--help") && index($0, "`bin-help`") {n++} END {exit n ? 0 : 1}' CONTRIBUTING.md || rc=1; if grep -qE 'tests/[a-z][a-z0-9-]*/run\.sh' CONTRIBUTING.md; then rc=1; fi; git show "$B:CONTRIBUTING.md" > "$T/c" 2> /dev/null || rc=1; test -s "$T/c" || rc=1; if grep -qF -- '`bin-help`' "$T/c"; then rc=1; fi; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** This task's diff is confined to a fixed allow-list, and `bin/` gains and loses no file. The measured set is the union of four reads: the committed range `git diff --no-renames --name-only <base>...HEAD` from the discriminator's branch point, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only`, and the untracked strays `git ls-files --others --exclude-standard`. It must contain no path outside: every path under `bin/` tracked at the branch point; `tests/bin-help/run.sh`, `.github/workflows/check-handoff.yml` and `.shell-team/test-recipe.md`; `docs/adopting.md`, `docs/adopting.ja.md` and `CONTRIBUTING.md`; and `.shell-team/todo.md` with this task's own spec, provenance, review and interventions records. The sorted `git ls-files -- bin/` equals the branch point's sorted `git ls-tree -r --name-only` over `bin/`. **This criterion is merge-point-scoped and expected to go stale after merge**, once later tasks' files land on the same base. That is expected, and it is never repaired by widening the base resolution or re-deriving it per rework round. Positive control: the measured union and the branch-point `bin/` listing are both asserted non-empty.
  - check: rc=0; B=$(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "feature/593-codex-host-not-logged-in-diagnosis" HEAD; elif git show-ref --verify --quiet refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis; then git merge-base "refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis" HEAD; else git merge-base "develop" HEAD; fi) || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac5.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; LC_ALL=C sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; git ls-tree -r --name-only "$B" -- bin/ > "$T/bin" || rc=1; test -s "$T/bin" || rc=1; { cat "$T/bin"; printf '%s\n' tests/bin-help/run.sh .github/workflows/check-handoff.yml .shell-team/test-recipe.md docs/adopting.md docs/adopting.ja.md CONTRIBUTING.md .shell-team/todo.md .shell-team/specs/T-1157-bin-help-flag.md .shell-team/provenance/T-1157.md .shell-team/reviews/T-1157.md .shell-team/interventions/T-1157.md; } | LC_ALL=C sort -u > "$T/allow"; LC_ALL=C comm -23 "$T/got" "$T/allow" > "$T/extra"; test ! -s "$T/extra" || rc=1; LC_ALL=C sort "$T/bin" > "$T/bins"; git ls-files -- bin/ | LC_ALL=C sort > "$T/binh"; cmp -s "$T/bins" "$T/binh" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** The suites covering the 14 and the exec-bit lock stay green. Each suite below must exit `0` with stdin at `/dev/null`: `tests/check-contract`, `check-design-note`, `check-handoff`, `check-playbook`, `check-readme-version`, `check-retro`, `check-run`, `cluster-failures`, `codex-skeleton-hygiene`, `codex-agents`, `goal-state`, `log-run`, `loop-guard`, `rework-digest`, `rollup-runs` and `bin-exec-bit` (each `run.sh`). The last of these also locks the new suite's mode against its shebang. Positive control: each suite file is asserted non-empty.
  - check: rc=0; for s in tests/check-contract/run.sh tests/check-design-note/run.sh tests/check-handoff/run.sh tests/check-playbook/run.sh tests/check-readme-version/run.sh tests/check-retro/run.sh tests/check-run/run.sh tests/cluster-failures/run.sh tests/codex-skeleton-hygiene/run.sh tests/codex-agents/run.sh tests/goal-state/run.sh tests/log-run/run.sh tests/loop-guard/run.sh tests/rework-digest/run.sh tests/rollup-runs/run.sh tests/bin-exec-bit/run.sh; do test -s "$s" || { rc=1; continue; }; bash "$s" > /dev/null 2>&1 < /dev/null || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** Every tracked `bin/` entry and the new suite are shellcheck-clean. `shellcheck` over every path `git ls-files -- bin/` lists plus `tests/bin-help/run.sh` exits `0`. Positive control: `shellcheck` is asserted resolvable, the listing non-empty and the suite file non-empty.
  - check: command -v shellcheck > /dev/null 2>&1 || exit 1; S=tests/bin-help/run.sh; test -s "$S" || exit 1; F=(); while IFS= read -r p; do F+=("$p"); done < <(git ls-files -- bin/); test "${#F[@]}" -gt 0 || exit 1; shellcheck "${F[@]}" "$S" > /dev/null 2>&1

- [ ] **AC8** This spec is a conformant carrier of its own declarations. `bash bin/check-adopter-docs.sh` on this spec must exit `0` with zero bytes on both streams. The spec carries exactly one line-initial `- user-visible: yes — `, `- verification-class: mechanism — `, `- verification-ceiling: unit-and-static — ` and `- base-ref-discriminator: ` naming the predecessor branch in its first arm. It carries exactly one whole line `- shipped-docs: <path> — this-task` for each of the three documents **AC4** measures. Positive control: the spec and the checker are asserted non-empty first.
  - check: rc=0; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1157-bin-help-flag.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1157-ac8.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; for k in '^- user-visible: yes — ' '^- verification-class: mechanism — ' '^- verification-ceiling: unit-and-static — ' '^- base-ref-discriminator: .B=.(if git show-ref --verify --quiet refs/heads/feature/593-codex-host-not-logged-in-diagnosis; '; do test "$(grep -c -- "$k" "$S" || true)" = 1 || rc=1; done; for p in docs/adopting.md docs/adopting.ja.md CONTRIBUTING.md; do test "$(grep -cxF -- "- shipped-docs: $p — this-task" "$S" || true)" = 1 || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

## Input space

**Reachable input classes** — how real sessions invoke these scripts:

1. Invocation forms: `bash "<plugin root>/bin/<script>"` (the adopter's documented form), a bare name on `PATH` in this checkout, a direct execution by path, and `bash bin/<script>` from a checkout root. This applies on the Claude Code host and on the Codex CLI host, under macOS bash 3.2 and GNU bash.
2. Arguments: `--help` or `-h` alone. Also `--help` / `-h` followed by further arguments (an agent retrying with its intended arguments after the flag). Every pre-existing argument shape of the 14 (file paths, `--line`, subcommands, flags, a loop_id, none at all) keeps its current behaviour.
3. Working directory: an adopter repository of any base-dir layout, this checkout, an unrelated directory, or an empty one.
4. Environment: `TEAM_RUN_BASE`, `TEAM_RUNS_DIR`, `RUNS_DIR` and `VERSION_MANIFEST` set or unset. Stdin is a terminal, `/dev/null`, or closed by the harness.
5. The tracked `bin/` population as it stands at the branch point: `bin/*.sh`, plus the extension-less `bin/install`.

**Out-of-scope synthetic extremes** — declined explicitly:

1. Spellings other than `--help` and `-h`: `--help=…`, `--HELP`, `-help`, `-?`, a `help` subcommand.
2. `--help` / `-h` in a position other than first (for example `check-run.sh <file> --help`), and, for the 41 already-armed scripts, `--help` followed by further arguments.
3. The exit status seen when the caller closes stdout early (`--help | head -1`). The caller's pipeline reports `head`'s status, and a write error inside the script under `set -e` is not guarded here.
4. Header comments carrying control characters or non-UTF-8 bytes, and scripts run through `sh`, `zsh` or another non-bash interpreter.
5. A future `bin/` entry that is a symlink, a gitlink or a non-shell file (`tests/bin-exec-bit/run.sh` already refuses any mode other than `100755`).

<!-- END intent-block: T-1157 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Issue Expected 1 — every `bin/` script accepts `--help` (and `-h`) as its first argument, prints usage to stdout, exits 0, before any other argument validation (Goal) | **AC1** (the 14, first argument with and without trailing arguments, no side effects), **AC2** (every tracked entry, sole argument) |
| 2 | Issue Expected 2 — the usage text is surfaced from the existing header comment, not written (Goal; Non-goals "no new usage prose") | **AC1** (every printed line is a header line; header region byte-unchanged except loop-guard; the `Usage` line printed where one exists) |
| 3 | Issue Expected 3 — a fixture suite locks the behaviour so the count cannot regress (Goal) | **AC2** |
| 4 | Operand literally spelled `--help` / `-h` no longer passable (Non-goals) | **AC1** (a leading `--help` / `-h` always answers usage) |
| 5 | loop-guard `--help` no longer prints `STOP:guard_error`; header amended; other leading `--*` still `STOP:guard_error` (Non-goals) | **AC1** (no `STOP:guard_error` line; header names `--help`), **AC3** (the unknown-flag probe is byte-identical to base) |
| 6 | The stderr `usage()` of rework-digest / goal-state is not reused (Non-goals) | **AC1** (their `usage:` text is not a header line), **AC3** |
| 7 | All non-`--help` behaviour unchanged (Goal, Non-goals) | **AC3**, **AC6** |
| 8 | No new or removed `bin/` file; no shared helper (Goal, Non-goals) | **AC5** |
| 9 | Already-armed scripts change only if they fail the invariant; fixed here as the same class (Non-goals) | **AC2** (the suite's invariant over all members); **AC5** (bin/ paths allowed for this reason). The count of such fixes is info-only (not promoted to AC): it is recorded by derivation in provenance, because a count of zero is equally correct. |
| 10 | Suite wired into CI and the CI-parity list; mode 100755 (Goal) | **AC2**, **AC6** (bin-exec-bit) |
| 11 | adopting pages and CONTRIBUTING state the rule (Goal) | **AC4** |
| 12 | README unchanged; no CHANGELOG or version bump in this diff (Non-goals) | **AC5** |
| 13 | `bin/` stays pure bash and shellcheck-clean (issue Prior art) | **AC7**. "Zero-dependency" is info-only (not promoted to AC): the header-surfacing needs only awk/sed, already used throughout `bin/`, and review reads it. |
| 14 | Recovering the lost telemetry is out of scope (issue Out of scope) | info-only (not promoted to AC) — an action nobody takes leaves no observable. |
| 15 | Sweep deferred to release (Non-goals) | info-only (not promoted to AC) — a process decision under mode A2. |
| 16 | `bin/install` is in the suite's population (Goal) | **AC2** (a `PASS:` line naming `bin/install` for each flag) |

## Shipped-docs inventory

- reproduce: git grep -n -F -e '--help' -- README.md README.ja.md CONTRIBUTING.md docs skills agents

| Shipped document | Disposition | Ground |
|---|---|---|
| `docs/adopting.md`, `docs/adopting.ja.md` | this-task | The adopter's reference for invoking `bin/` scripts; it gains the one rule (**AC4**). Its existing `--help` mentions are Codex CLI's own flags and stay. |
| `CONTRIBUTING.md` | this-task | New `bin/` scripts must answer `--help` / `-h`; the suite enforces it (**AC4**). |
| `README.md`, `README.ja.md` | unchanged | They cite `--help` of `resolve-executor.sh`, `derive-populations.sh` and `check-count-claims.sh`, all already armed; nothing becomes false. |
| The 14 scripts' header comments | unchanged except `bin/loop-guard.sh` | Their text is what `--help` now prints. Only loop-guard's "stdout always carries the decision" becomes false and is amended (**AC1**). |

## Pre-commitment

The drop order and dispositions below are AI self-discipline, not an operator ruling. The "return to planning" clause follows the operator-ratified 2026-09-06 ruling.

**Never-dropped:** the 14 answering `--help` / `-h` as the first argument with exit 0 and header-surfaced stdout (**AC1** apart from its working-directory and runs-path clauses). If a never-dropped component is defeated in two consecutive rounds, the task stops and returns to planning instead of taking a third patch round.

**Droppable, in order:**

1. **The working-directory-unchanged assertion.** This means the suite's scratch-cwd `find … -mindepth 1` case and **AC2**'s `-mindepth 1` clause, together with **AC1**'s empty-cwd and runs-path-absent clauses. Disposition: remove them, and file an issue carrying the rounds' findings as its requirement list. Disclosed cost: it changes **AC1**/**AC2** prose and the Goal, so executing it is a class-B re-freeze.

**Trigger:** two consecutive review rounds each finding a new defect in the droppable component.

## Blast radius

`- verification-class: mechanism`. The read-set of merged criteria naming the edited paths is derived at run time:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*(check-contract|check-design-note|check-handoff|check-playbook|check-readme-version|check-retro|check-run|cluster-failures|codex-capture|goal-state|log-run|loop-guard|rework-digest|rollup-runs|check-handoff\.yml|test-recipe|adopting(\.ja)?\.md|CONTRIBUTING)' -- .shell-team/specs

This is a literal search, a lower bound and not a population count. Predictions:

- Criteria that byte-pin or `git diff` a whole script among the 14, the workflow, the test recipe, the adopting pages or `CONTRIBUTING.md` against a fixed ref are predicted to flip.
- Criteria that read only a script's header region are predicted to hold for 13 of the 14, since only loop-guard's header changes.
- Criteria that run one of the 14 with a non-`--help` argument are predicted to stay green (**AC3**).

Which criteria are red already at the branch point is not measured here.

**Indirection class:** a merged criterion that reaches these files through a path built at run time matches none of the literal bytes above. It is disclosed, not measured here.

**Disclosed deviation:** the full-population two-arm inventory is deferred to the release sweep under the operator's standing mode-A2 ruling. The docs-only carve-out does not apply, because the diff reaches `bin/`, `tests/` and `.github/`.

**Adopter-side artifacts:**

1. **A vendored copy of `bin/`** (the air-gapped fallback in `docs/distribution.md`) keeps the old refusal until it is re-vendored. Limit: the plugin cannot reach it.
2. **The installed plugin cache** picks up the change with the next plugin update; no migration step exists or is needed.
3. **Telemetry already lost** in adopter runs stays lost (issue out-of-scope).

## Review depth

- **The 14 scripts' new arm and the suite** get full depth. The focus:
  - whether any of the 14 does anything before the arm (a file read, a `team-paths.sh` call, a `mkdir`, a stdin read);
  - whether any non-`--help` path changed;
  - whether printed lines are only header lines;
  - whether the suite fails closed on an empty or failed population and actually goes red when an arm is removed (mutation observability is for QA to observe and report).
- **The shipped-doc edits** are reviewed for truth against the scripts, not for style.
- **This spec's own inline `- check:` lines** are reviewed only for computed values, the direction of their conclusion, and material instrument defects. Their adversarial completeness is not a Major.

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #592 `--help` / `-h` on the 14 `bin/` scripts | not met | met | PATCH | Nothing new becomes possible. The existing scripts stop answering a usage question with a usage error on the shipped default path. |

**CHANGELOG draft** (for the release branch, not this diff):

> - **Every `bin/` script answers `--help` and `-h`.** Fourteen scripts (`check-contract.sh`, `check-design-note.sh`, `check-handoff.sh`, `check-playbook.sh`, `check-readme-version.sh`, `check-retro.sh`, `check-run.sh`, `cluster-failures.sh`, `codex-capture.sh`, `goal-state.sh`, `log-run.sh`, `loop-guard.sh`, `rework-digest.sh`, `rollup-runs.sh`) used to answer `--help` with a usage error. Given `--help` or `-h` as the first argument, they now print usage from their own header comment to stdout and exit 0, before any other processing. A session that asks a script for its usage no longer concludes the tool is broken and skips the call. A new CI suite locks the behaviour for every tracked `bin/` entry. A file or operand literally named `--help` or `-h` can no longer be passed first (issue #592).

## Assumptions

- **Relayed:** GitHub issue #592's body, quoted verbatim above. The coordinating session holds the primary.
- **Relayed:** PRs #617, #613 and #609 are open at authoring time. Measured by this role: `refs/heads/feature/593-codex-host-not-logged-in-diagnosis` and `refs/remotes/origin/feature/593-codex-host-not-logged-in-diagnosis` both read `55a276e211d7bd8858779208956a7c58b937c6fe`, the cut point the briefing gives. The freeze run confirms `git rev-parse HEAD`, `git status --short` and the discriminator's resolved `$B`, and reports them.
- **Finding about the hand-off, measured false in part:** the issue's "the usage text already exists as a header comment in each of the 14" holds for 12 of the 14. `check-contract.sh` and `check-handoff.sh` carry no `Usage` comment line. Per the coordinating session's correction, this spec surfaces their headers as they stand and writes no prose. **AC1**'s `Usage` clause is conditional on the header having such a line. The coordinating session records this as an interventions entry and decides whether to file the header-usage-line follow-up.
- **`bin/install` is in the suite's population.** It is tracked under `bin/`, it is the adopter-facing installer, and it is already armed (`:118`). A `bin/*.sh` glob would miss it, as `tests/bin-exec-bit/run.sh` documents. Including it costs nothing and keeps the suite's population the one `git ls-files -- bin/` names.
- **The 41 already-armed scripts are expected to pass the sole-argument invariant.** The issue measured `--help` exit 0 for all 41. `-h`, empty-cwd and non-empty-stdout have not been measured by anyone. Any failure is fixed in this task, and the engineer records the failing set in provenance as a `bin/derive-populations.sh` block with its `- reproduce:` line.
- **This spec is a first freeze**, so its intent hash is owed by the freeze run: this role has no shell to run `bin/check-intent.sh --print-hash`.
- **Count premises** — the freeze run re-measures each at the discriminator's `$B` with the command shown and records the value here. In the table, `\|` is markdown escaping for a literal `|`; remove the backslashes, and set `B` with the declared expression, before running the commands. Per the derived-populations rule, the value marked *read by this role* was not produced by `bin/derive-populations.sh`. The freeze run re-derives it with that tool before relying on it.

| Token / count | Class | Value | Command at the branch point |
|---|---|---|---|
| `bin/*.sh` lacking the `--help\|-h)` arm | borrowed (the orchestrator's derivation) | **14** (relayed derivation above) | `bash bin/derive-populations.sh --label t1157-help-arm --set all="git ls-files -- 'bin/*.sh'" --set has-help-arm="git grep -l -E -e '--help[\|]-h[)]' -- 'bin/*.sh'" --accept-status has-help-arm=1` (at a checkout of `$B`) |
| headers of the 14 carrying a `Usage` comment line above `set -euo pipefail` | borrowed | **12** (freeze run 2026-09-26 at `55a276e2`, re-derived with an awk header scan: missing in `check-contract.sh`, `check-handoff.sh`) | `for s in $(cat "$T/set"); do git show "$B:$s" \| awk '/^set -euo pipefail$/{exit} /^#[ \t]*Usage/{f=1} END{exit !f}' && echo "$s"; done \| grep -c .` (with `$T/set` built as in **AC1**) |
| `stdout always carries the decision` in `bin/loop-guard.sh` | borrowed | **1** (`:53`, read) | `git show "$B:bin/loop-guard.sh" \| grep -cF 'stdout always carries the decision'` |
| `--help` / ` -h` in the 14 scripts' own suites | borrowed | **0** (read, grep over the 14 suite directories) | `git grep -n -E -e '--help\|[[:space:]]-h([[:space:]]\|$)' "$B" -- tests/check-contract tests/check-design-note tests/check-handoff tests/check-playbook tests/check-readme-version tests/check-retro tests/check-run tests/cluster-failures tests/codex-skeleton-hygiene tests/goal-state tests/log-run tests/loop-guard tests/rework-digest tests/rollup-runs \| grep -c .` |
| paragraph naming both `` `--help` `` and `` `-h` `` in each adopting page | borrowed | **0** / **0** (expected; not measured by this role) | `git show "$B:docs/adopting.md" \| awk -v RS= 'index($0,"\`--help\`") && index($0,"\`-h\`"){n++} END{print n+0}'` (and `.ja.md`) |
| `tests/bin-help/run.sh` in `CONTRIBUTING.md`; the path `tests/bin-help/` in the tree | own-coinage | **0** / absent (Glob found no file) | `git show "$B:CONTRIBUTING.md" \| grep -cF 'tests/bin-help/run.sh'`; `git ls-tree -r --name-only "$B" -- tests/bin-help \| grep -c .` |
| `PASS: population ` label | own-coinage | **0** in `tests/` (expected) | `git grep -c -F -e 'PASS: population ' "$B" -- tests` |

## Open questions

None blocking.

## Notes for engineer

- **Files likely touched:** the 14 scripts, `tests/bin-help/run.sh` (new, mode 100755), `.github/workflows/check-handoff.yml`, `.shell-team/test-recipe.md` (`## CI parity` shellcheck block), `docs/adopting.md`, `docs/adopting.ja.md` and `CONTRIBUTING.md`. Touch other `bin/` files only if the suite finds them failing (**AC5** allows it; record the set by derivation in provenance).
- **Placement:** put the arm immediately after each script's `set -euo pipefail` line, before any other statement. The header region above that line must stay byte-identical (**AC1**) except in `bin/loop-guard.sh`. Test only `$1` (with a `${1:-}` guard for `set -u`), so trailing arguments are ignored.
- **Surfacing:** one `awk` pass over the script's own file, finding the header's end at the first `set -euo pipefail` line rather than a hardcoded line range (see `bin/check-pii-shapes.sh:278`–`:294` and its comment on the truncation). Strip the leading `#` / `# ` from each line. Avoid `grep | head` under `pipefail`. Resolve the script's own path from `BASH_SOURCE[0]` as the scripts already do. Whether you print the whole header or only its `Usage` section is your call; either satisfies **AC1**, provided every printed line is a header line and the script's name is printed. For codex-capture and log-run the header is long (up to ~180 lines); that is acceptable.
- **loop-guard:** amend the header's "stdout always carries the decision" so that it names `--help` / `-h` as the exception. The amended header is what `--help` then prints.
- **log-run / check-readme-version / codex-capture:** the arm must come before the `SCRIPT_DIR`/`ROOT`/manifest/`team-paths` work, not only before the loop_id check.
- **Suite:** model it on `tests/bin-exec-bit/run.sh`:
  - take the population from `git -C "$REPO_ROOT" ls-files -- bin/` with its exit status captured, failing closed on empty output or a non-zero status;
  - print a `PASS: population …` line and one `PASS: <path> <flag> …` line per member per flag;
  - run each case from a fresh empty directory under `$TMPDIR` with `</dev/null` and `env -u TEAM_RUN_BASE`;
  - assert exit 0, non-empty stdout and an unchanged `find "$dir" -mindepth 1`.

  Before hand-off, run a mutation self-check: remove one script's arm in a scratch copy and confirm the suite goes red. QA observes the same.
- **CI:** add a `Run bin-help suite` step (`run: bash tests/bin-help/run.sh`), and add `tests/bin-help/run.sh` to a `run: shellcheck …` line (the main one or a new "T-1157 additions" step). Append it to the test recipe's CI-parity shellcheck block. The recipe block already lags the T-1151 additions; do not repair that here.
- **Docs:** one paragraph in each adopting page, near the `bash "<plugin root>/bin/<script>"` invocation form (for example under `## How to run` or `## Operating rules`), naming `` `--help` ``, `` `-h` `` and `bin/` in backticks as written. One paragraph in `CONTRIBUTING.md` (for example near `## About CI on your pull request`) naming `--help` and `tests/bin-help/run.sh`.
- **Measured-at-ref command check:** not applicable — no deliverable prints a command labelled as measured at a git ref.
