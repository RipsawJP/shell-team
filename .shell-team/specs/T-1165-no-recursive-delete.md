# No recursive delete in the test suites, the docs fixture or the eight bin tools' cleanup

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1165

**Branch**: `feature/641-no-recursive-delete`, cut from `develop` at `8a6cc48c` (measured: `.git/refs/heads/develop` and `.git/refs/heads/feature/641-no-recursive-delete` both read `8a6cc48c8e6b82bf1cf99a1ec740dc8915a7a50b`). No open predecessor PR. PR base: `develop`.

## Problem

Agents running this loop execute recursive deletes on the operator's machine without ever typing one. A permission rule on a typed command does not see the same deletion inside a script the agent runs: a test suite's EXIT trap, a spec's `- check:` line run through `check-acs`, or a `bin/` tool's cleanup trap. A deletion that reaches the wrong target cannot be undone. This task removes every recursive delete from the test suites, the docs fixture and the eight `bin/` tools that remove their scratch directory with one, so nothing the loop runs locally can delete a directory tree.

## Summarized sources

- GitHub issue #641. **Relayed verbatim by the coordinating session, not read by this role.** Distinctions carried over: Expected has three clauses. (1) No file under `tests/` and no docs fixture contains a recursive delete, and temp directories are left under `$TMPDIR`. (2) Each of the 8 named `bin/` tools cleans up without a recursive delete, by removing its own files by name and then the directory with `rmdir`, **or**, where that is not possible, keeps its current cleanup with the reason stated. (3) The changed suites are judged by CI, not by running suites that still contain recursive deletes on the operator's machine. Out of scope: merged specs' frozen `- check:` lines, `.github/workflows/check-handoff.yml` (it runs only on the CI runner), and the operator's sandbox or permission settings. The issue's counts (56 files / 99 occurrences) are relayed and are not frozen anywhere here.
- The operator's standing rule of 2026-10-01, relayed verbatim by the coordinating session. It is quoted word for word in the constraint block inside the frozen intent below.
- `bin/aggregate-verdicts.sh:225`–`:228`, `bin/check-board-headings.sh:115`–`:137`, `bin/check-codex-agents.sh:103`–`:121`, `bin/check-commit-identity.sh:134`–`:144`, `bin/check-fanout-instances.sh:288`–`:291`, `bin/check-pii-shapes.sh:623`–`:630`, `bin/check-review-input.sh:217`–`:218`, `bin/derive-populations.sh:299`–`:302` (read). Distinctions: each creates one `mktemp -d "${TMPDIR:-/tmp}/<tool>.XXXXXX"` directory and removes it with a recursive delete in an EXIT trap. Five guard the cleanup with `2>/dev/null || true`. `check-pii-shapes.sh` and `check-commit-identity.sh` use a bare `cleanup() { … ; }` under `set -euo pipefail`. `check-review-input.sh` uses an inline `trap '…' EXIT`. `check-board-headings.sh` uses an `if` form, and its comment at `:115`–`:121` records why: temp files are created inside command-substitution subshells (`new_tmp`), so the parent shell cannot list them by name, and an earlier `&&`-form cleanup flipped exit `0` to `1`. `check-codex-agents.sh` is the only one with a nested level: the generator writes into `$SCRATCH/fresh/`. `aggregate-verdicts.sh` and `derive-populations.sh` create indexed names (`part.$i.raw`, `raw.$idx`). No other `bin/` file contains a recursive delete (Grep-tool read of `bin/`; the freeze run re-measures it with the gate's own `git grep`).
- `bin/land-worktree.sh:377`–`:390` (read). Distinction: prior art for the target shape. `rm -f "$WORKDIR"/* 2>/dev/null || true` then `rmdir "$WORKDIR" 2>/dev/null || true` inside the EXIT trap. A non-recursive glob does not match dotfiles, so `rmdir` then fails and leaves the directory in place.
- `bin/close-out.sh:651`–`:666` (grepped). Distinction: `close-out.sh` invokes `check-review-input.sh` and dies on an exit status it does not expect, so a cleanup that changed that tool's exit status would break close-out.
- `tests/` (Grep-tool read of every recursive-delete site at `8a6cc48c`). Distinctions: the sites fall into the five classes named in **AC1**'s body and in the Notes. `tests/close-out/run.sh:141` and `tests/check-review-input/run.sh:215` carry a recursive delete inside an attack string that the suite proves is never executed. `tests/close-out/run.sh:111` deletes a directory so it can put a regular file at the same path.
- `tests/rework-digest/run.sh:56`–`:62` and `:166` (read). Distinction: this suite's root is always under `$HERE` on purpose. Its relative-symlink launch case `../../../../bin/rework-digest.sh` depends on the root sitting at a fixed depth under the repository root, and moving the root to `$TMPDIR` changes that depth.
- `.shell-team/test-recipe.md:136`–`:150`, `:545`–`:571`, `:588`–`:596`, `:815`, `:1539`–`:1631` (read or grepped). Distinctions: it recommends the two-arm `TMPDIR`-then-`$HERE` fallback idiom, recommends `rm -r` over `rm -rf` for some sandbox cases, and records that this sandbox denies direct writes to `/tmp`. It is internal, not shipped.
- `.github/workflows/check-handoff.yml:19`–`:35` and the lines matching `rm -rf` (read or grepped). Distinctions: CI runs `shellcheck` 0.11.0 on an explicit file list, not a glob. It carries exactly two recursive deletes (`:206`, `:376`), both on the runner. No AI runs in it.
- `.gitignore` (read in full). Distinction: nothing under `tests/` is ignored, so a scratch root left inside the checkout shows in `git status`.
- `docs/loop-engineering/subjects/subject-01/acceptance.sh:60`–`:64` and `manifest.txt` (read). Distinction: the fixture's own scratch directory is under `${TMPDIR:-/tmp}`, and the EXIT trap removes it recursively. The manifest lists paths, not hashes.
- `README.md`, `README.ja.md`, `docs/*.md`, `CONTRIBUTING.md`, `SECURITY.md` (grepped for `cleanup`, `clean-up`, `scratch director`, `temp director`, `left behind`, `leaves no`). Distinction: no shipped document describes how these tools clean up their scratch space. This grounds `user-visible: no`.
- `.shell-team/specs/T-1160-spec-review-round-cap.md` (read). Distinction: template and convention reference. Its **AC5** requires every base line of `tests/check-spec-review/run.sh` to survive at HEAD, including the trap line `:28` this task removes (see Blast radius).

## Goal

<!-- BEGIN intent-block: T-1165 -->

- user-visible: no — a normal run of every changed suite and tool keeps its exit status, stdout and stderr, and leaves nothing behind. No shipped document describes how these tools clean up (grep of README, docs and CONTRIBUTING returns no match). What changes is an internal safety property: nothing the loop runs can remove a directory tree.
- verification-class: mechanism — the diff reaches eight `bin/` tools that ship to adopters and run inside the loop, the test suites under `tests/`, and a docs fixture that `tests/trial-recipe/` runs.
- verification-ceiling: unit-and-static — every criterion except **AC9** is settled in a plain checkout: by a `git grep` over named paths, by running a tool or a grep-clean suite against fixtures under `$TMPDIR` with exit status and leftover entries counted, by a base-blob read with `git show`, by `shellcheck`, or by a checker's exit code. **AC9** sits above this ceiling: the full suite population is judged by CI on the pull request.
- base-ref-discriminator: not-applicable — this branch has no open predecessor PR. It is cut from `develop` at `8a6cc48c`, and every criterion that reads a base-side blob resolves `git merge-base develop HEAD` (through `refs/heads/develop`, else `refs/remotes/origin/develop`; a checkout resolving neither refuses with exit `1`).

**Constraint block (operator standing rule, ratified 2026-10-01, non-negotiable; quoted word for word):**

> recursive deletes (`rm -rf`, `rm -r`, `find -delete` and similar) are never used — not in direct commands and not in any script, test, `- check:` line or fixture you write. Temp files are left under $TMPDIR. If a deletion becomes necessary, stop and report BLOCKED; never try an alternative. A file that contains a recursive delete is never run locally. Merged specs' `- check:` lines are never run, and no spec may require a blast-radius check through merged specs.

Every `- check:` line in this spec obeys the block. None contains a recursive delete. Each check that runs a tool or a suite first runs the **AC1**/**AC2** gate over `bin`, `tests` and `docs/loop-engineering/subjects`, and exits `1` without running anything while any match remains. Temp directories created by the checks are left under `$TMPDIR`.

**Goal (one sentence).** After this task, a `git grep` for any recursive-delete form (`rm` with any `-r`/`-R`/`--recursive` flag form, `find … -delete`, `xargs rm`, `-exec rm`, `git clean`) finds nothing in `tests/`, in `docs/loop-engineering/subjects/` or anywhere in `bin/`. Every test suite's scratch root sits under `${TMPDIR:-/tmp}` and is left there. Each of the eight `bin/` tools removes its own scratch files without a recursive delete and then the directory with `rmdir`, leaves no directory under `$TMPDIR` on a normal run, and exits with the same status whether or not that cleanup fails. `derive-populations.sh` and `check-pii-shapes.sh` use the by-name form without exception. The full suite population is judged green by CI on the pull request.

**Pre-commitment (frozen before round 1; authorship: AI self-discipline from tech-lead's Routing Map, never operator-ratified).**

Never-dropped. A defeat of any never-dropped item in two consecutive rounds stops the task and returns it to planning, with no carve-out:

1. N1: zero recursive deletes in `tests/` and the docs fixture (**AC1**).
2. N2: zero recursive deletes in `bin/`. The fallback below never keeps one (**AC2**).
3. N3: exit-status preservation in all eight tools when cleanup fails (**AC4**, and the exit-status label in **AC5**).

Droppable:

1. D1: by-name cleanup for any of the six tools other than `derive-populations.sh` and `check-pii-shapes.sh` whose scratch layout cannot be enumerated. Disposition: that tool leaves its scratch directory under `$TMPDIR`, its suite prints the fallback label **AC5** accepts, and `.shell-team/provenance/T-1165.md` names the tool with the reason. A recursive delete is never kept. No re-freeze is needed, because **AC5** already admits this outcome.

Trigger: two consecutive rounds (a QA `FAIL` or a Codex `REQUEST_CHANGES`) that each carry a new `Blocker` or `Major` against the same component.

## Non-goals

- **The operator's standing rule (constraint block above) binds this task's own work, not only its deliverable.** No recursive delete is typed, scripted or written into a check line or fixture. A file that still contains one is never run locally. If a deletion becomes necessary, the role stops and reports `BLOCKED` rather than trying an alternative. (**AC1**, **AC2**, and the gate at the head of **AC4**, **AC5** and **AC6**)
- **Merged specs' frozen `- check:` lines are not rewritten and are not run.** No criterion here requires a blast-radius check through merged specs. (info-only; see Blast radius)
- **No change to `.github/workflows/check-handoff.yml`.** Its two recursive deletes run only on the CI runner. (**AC10**: byte-identical to the base blob)
- **No change to the operator's sandbox, permission or hook settings**, and no new guard, hook or checker that scans for recursive deletes at run time. The gate is a criterion of this task, not a shipped mechanism. (**AC10**: no new `bin/` file)
- **No change to `bin/close-out.sh`** or to any `bin/` file outside the eight. (**AC10**)
- **The issue's alternative "keep the current cleanup with the reason stated" is not exercised.** Leaving the scratch directory under `$TMPDIR` is always possible, and a tool that kept a recursive delete could never be run locally under the standing rule. (**AC2**)
- **No cleanup of directories left under `$TMPDIR`.** Suites leave their roots there by design. Reclaiming that space is the operator's or the OS's business. (info-only)
- **No change to `docs/loop-engineering/context-lifecycle.md`**, whose printed reproduce command at `:97` contains a recursive delete. It is an analysis note, not a fixture, and the issue does not name it. Recorded as an observation for a follow-up. (info-only)
- **No per-task full-population two-arm sweep and no release sweep.** Neither is run under the operator's standing A2 mode, and the standing rule forbids running merged specs' check lines. (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`, where it leaves what it creates. `P` below is the one gate pattern, spelled byte-identically in every criterion that uses it. It is an ERE covering `rm` with any `-r`/`-R`/`--recursive` flag form, alone or combined with other flags, in code, strings and comments; `find … -delete`; `xargs … rm`; `-exec`/`-execdir rm`; and `git clean`. The `git grep` exit contract is: `1` = no match, the only pass; `0` = a match, fail; greater than `1` = the read failed, fail closed. Criteria **AC4**, **AC5**, **AC6** and **AC7** depend on the eight `bin/` tools being converted first (Routing Map step 2a). Until then, their gate refuses before anything runs.

- [ ] **AC1** (N1.) No file under `tests/` or `docs/loop-engineering/subjects/`, tracked or untracked, contains a recursive delete in any form, in code, a string or a comment. This covers all five classes of site measured at `8a6cc48c`:
  - (1) EXIT traps or `cleanup()` functions that remove the suite's root;
  - (2) mid-suite resets and re-creations;
  - (3) attack-string fixtures;
  - (4) comments that mention a recursive delete;
  - (5) the `chmod -R u+rwx …` plus recursive delete traps in `tests/retro-inputs/run.sh` and `tests/retro-inputs/invariants.sh`. There the non-writable tree is simply left under `$TMPDIR`, which is acceptable.

  Positive controls: the pattern matches each of fourteen recursive-delete spellings and none of seven near-misses (`rm -f`, `rmdir`, `chmod -R`, `cp -R`, `confirm -r`, a hyphenated `-deleted` word, and the prose `mid-delete`). It still matches the two runner-only sites in the out-of-scope workflow file. Each spelling is assembled from fragments, so this line itself contains no recursive delete.
  - check: rc=0; export LC_ALL=C; P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; r=rm; n=0; for s in "$r -rf x" "$r -r x" "$r -R x" "$r -fr x" "$r -Rf x" "$r -f -r x" "$r --recursive x" "trap '$r -rf \"\$T\"' EXIT" "x;$r -rf /" "# a single $r -rf x comment" "find . -type f -delete" "printf x | xargs $r -f" "find . -exec $r {} +" "git clean -fdx"; do printf '%s\n' "$s" | grep -qE -- "$P" || n=$((n+1)); done; test "$n" -eq 0 || rc=1; m=0; for s in "$r -f x" "${r}dir x" "chmod -R u+rwx x" "cp -R a b" "confirm -r x" "opt-out-mode-file-deleted-runs-check" "recreating files mid-delete failed"; do printf '%s\n' "$s" | grep -qE -- "$P" && m=$((m+1)); done; test "$m" -eq 0 || rc=1; git grep -q -E -- "$P" -- .github/workflows/check-handoff.yml || rc=1; git grep -n --untracked -E -- "$P" -- tests docs/loop-engineering/subjects; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC2** (N2.) None of the eight tools contains a recursive delete, in code or comment, and no other file under `bin/` does either. The eight are `bin/aggregate-verdicts.sh`, `bin/check-board-headings.sh`, `bin/check-codex-agents.sh`, `bin/check-commit-identity.sh`, `bin/check-fanout-instances.sh`, `bin/check-pii-shapes.sh`, `bin/check-review-input.sh` and `bin/derive-populations.sh`. Positive controls: each of the eight still exists and still arms a trap, and the pattern still matches the out-of-scope workflow file.
  - check: rc=0; export LC_ALL=C; P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; set -- bin/aggregate-verdicts.sh bin/check-board-headings.sh bin/check-codex-agents.sh bin/check-commit-identity.sh bin/check-fanout-instances.sh bin/check-pii-shapes.sh bin/check-review-input.sh bin/derive-populations.sh; test "$#" -eq 8 || exit 1; for f in "$@"; do test -s "$f" || rc=1; grep -q 'trap ' "$f" || rc=1; done; git grep -q -E -- "$P" -- .github/workflows/check-handoff.yml || rc=1; git grep -n -E -- "$P" -- "$@"; g=$?; test "$g" -eq 1 || rc=1; git grep -n --untracked -E -- "$P" -- bin; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC3** Every suite's scratch root is under `${TMPDIR:-/tmp}`, never inside the checkout. No file under `tests/` builds a directory with `mktemp -d "$HERE…` or `mktemp -d "${HERE}…`. That includes `tests/rework-digest/run.sh`, whose fixed-depth relative-symlink launch case must keep proving relative-symlink resolution from a root under `$TMPDIR`. Positive control: `mktemp -d` is still used under `tests/`.
  - check: rc=0; export LC_ALL=C; git grep -q -F -e 'mktemp -d' -- tests || rc=1; git grep -n --untracked -F -e 'mktemp -d "$HERE' -e 'mktemp -d "${HERE}' -- tests; g=$?; test "$g" -eq 1 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (N3; depends on step 2a.) `derive-populations.sh` and `check-pii-shapes.sh` leave no scratch directory under `$TMPDIR` on a normal run, and their exit status survives a failed cleanup. Each case runs the tool twice against a fresh, empty `TMPDIR`: once plainly, and once with a `PATH` shim whose `rmdir` exits `1` without touching anything. Both runs must exit with the same status. The plain run leaves zero `<tool>.*` entries. The shimmed run leaves exactly one, which proves its cleanup really reached `rmdir` and failed. The cases are:
  - a successful `derive-populations.sh` derivation (exit `0`);
  - a refused one, whose set command exits `3` (exit `1`);
  - `check-pii-shapes.sh --base HEAD` (exit `0` or `1`, never `2`).

  The gate runs first, and nothing runs while it matches.
  - check: rc=0; export LC_ALL=C; P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; git grep -q --untracked -E -- "$P" -- bin tests docs/loop-engineering/subjects; g=$?; test "$g" -eq 1 || exit 1; D="$PWD/bin/derive-populations.sh"; K="$PWD/bin/check-pii-shapes.sh"; test -s "$D" || exit 1; test -s "$K" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac4.XXXXXX") || exit 1; mkdir "$T/shim" || exit 1; printf '#!/bin/sh\nexit 1\n' > "$T/shim/rmdir" || exit 1; chmod +x "$T/shim/rmdir" || exit 1; cnt(){ c=0; for e in "$1"/"$2".*; do test -e "$e" && c=$((c+1)); done; printf '%s' "$c"; }; go(){ k=$1; p=$2; w=$3; shift 3; mkdir "$T/n$k" "$T/s$k" || return 1; TMPDIR="$T/n$k" "$@" > "$T/o$k" 2>&1; a=$?; PATH="$T/shim:$PATH" TMPDIR="$T/s$k" "$@" > "$T/q$k" 2>&1; b=$?; printf '%s' "$a" > "$T/rc$k"; test "$a" = "$b" || return 1; test -z "$w" || test "$a" = "$w" || return 1; test "$(cnt "$T/n$k" "$p")" = 0 || return 1; test "$(cnt "$T/s$k" "$p")" = 1 || return 1; }; go 1 derive-populations 0 bash "$D" --label t1165 --set 'a=printf "x\n"' --set 'b=printf "y\n"' || rc=1; go 2 derive-populations 1 bash "$D" --label t1165 --set 'a=exit 3' --set 'b=printf "y\n"' || rc=1; go 3 check-pii-shapes '' bash "$K" --base HEAD || rc=1; case "$(cat "$T/rc3" 2>/dev/null)" in 0|1) ;; *) rc=1;; esac; test "$rc" -eq 0

- [ ] **AC5** (N3, D1; depends on step 2a.) Each of the eight tools' own suites carries the same two-run shim case, exits `0`, prints no `FAIL` line, and prints two labels. The first is `T-1165: <tool>.sh exit status survives a failed rmdir`. The second is one of:
  - `T-1165: <tool>.sh leaves no scratch directory`, for a normal run that leaves nothing; or
  - `T-1165: <tool>.sh leaves its scratch directory under TMPDIR`, only under disposition D1. Then `.shell-team/provenance/T-1165.md` names that tool. D1 is never available to `derive-populations.sh` or `check-pii-shapes.sh`.

  The eight suites are `tests/aggregate-verdicts`, `tests/check-board-headings`, `tests/codex-agents` (for `check-codex-agents.sh`), `tests/check-commit-identity`, `tests/check-fanout-instances`, `tests/check-pii-shapes`, `tests/check-review-input` and `tests/derive-populations`. `tests/check-review-input/run.sh` additionally prints `T-1165: injected command was not executed` for its class-3 attack string, whose payload can create a canary file if executed but can delete nothing. The suites run with `TMPDIR` pointed at a fresh directory, and `git status --porcelain -- tests docs bin` is identical before and after. The gate runs first, and nothing runs while it matches.
  - check: rc=0; export LC_ALL=C; P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; git grep -q --untracked -E -- "$P" -- bin tests docs/loop-engineering/subjects; g=$?; test "$g" -eq 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac5.XXXXXX") || exit 1; mkdir "$T/tmp" || exit 1; git status --porcelain -- tests docs bin > "$T/st0" || exit 1; PV=.shell-team/provenance/T-1165.md; for pair in aggregate-verdicts:aggregate-verdicts check-board-headings:check-board-headings codex-agents:check-codex-agents check-commit-identity:check-commit-identity check-fanout-instances:check-fanout-instances check-pii-shapes:check-pii-shapes check-review-input:check-review-input derive-populations:derive-populations; do s=${pair%%:*}; t=${pair#*:}; test -s "tests/$s/run.sh" || { rc=1; continue; }; TMPDIR="$T/tmp" bash "tests/$s/run.sh" > "$T/$s.log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/$s.log" || true)" = 0 || rc=1; grep -qF -- "T-1165: $t.sh exit status survives a failed rmdir" "$T/$s.log" || rc=1; a=$(grep -cF -- "T-1165: $t.sh leaves no scratch directory" "$T/$s.log" || true); b=$(grep -cF -- "T-1165: $t.sh leaves its scratch directory under TMPDIR" "$T/$s.log" || true); case "$t" in derive-populations|check-pii-shapes) { test "$a" -ge 1 && test "$b" = 0; } || rc=1;; *) if test "$b" -ge 1; then { test "$a" = 0 && grep -qF -- "$t.sh" "$PV"; } || rc=1; else test "$a" -ge 1 || rc=1; fi;; esac; done; grep -qF -- 'T-1165: injected command was not executed' "$T/check-review-input.log" || rc=1; git status --porcelain -- tests docs bin > "$T/st1" || rc=1; cmp -s "$T/st0" "$T/st1" || rc=1; test "$rc" -eq 0

- [ ] **AC6** (depends on step 2a.) The suites carrying class-2 mid-suite resets, class-3 attack strings or class-5 traps, plus `tests/rework-digest` (redesigned per **AC3**), pass when run locally with `TMPDIR` pointed at a fresh directory. Each exits `0` and prints no `FAIL` line. Each class-2 reset is replaced by a fresh `mktemp -d` per case (or a move into the suite's own root), and each case still asserts what it did: per suite, the number of non-comment lines calling `pass` at HEAD is at least the base blob's. `tests/close-out/run.sh` prints `T-1165: injected command was not executed` for its class-3 attack string, whose payload can create a canary file if executed but can delete nothing. `git status --porcelain -- tests docs bin` is identical before and after. The gate runs first, and nothing runs while it matches.

  Suites: `check-refreeze-grant`, `errexit-safe`, `trial-recipe`, `gen-playbook-blocks`, `check-prompt-sync`, `close-out`, `check-retro`, `check-provenance`, `check-intent`, `playbook-promote`, `cluster-failures`, `bin-help`, `rollup-runs`, `rework-digest`, `retro-inputs`.
  - check: rc=0; export LC_ALL=C; P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; git grep -q --untracked -E -- "$P" -- bin tests docs/loop-engineering/subjects; g=$?; test "$g" -eq 1 || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac6.XXXXXX") || exit 1; mkdir "$T/tmp" || exit 1; git status --porcelain -- tests docs bin > "$T/st0" || exit 1; pc(){ grep -vE '^[[:space:]]*#' "$1" | grep -cE '(^|[^[:alnum:]_])pass[[:space:]]' || true; }; for s in check-refreeze-grant errexit-safe trial-recipe gen-playbook-blocks check-prompt-sync close-out check-retro check-provenance check-intent playbook-promote cluster-failures bin-help rollup-runs rework-digest retro-inputs; do f="tests/$s/run.sh"; test -s "$f" || { rc=1; continue; }; git show "$B:$f" > "$T/$s.base" 2>/dev/null || rc=1; test -s "$T/$s.base" || rc=1; test "$(pc "$f")" -ge "$(pc "$T/$s.base")" || rc=1; TMPDIR="$T/tmp" bash "$f" > "$T/$s.log" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/$s.log" || true)" = 0 || rc=1; done; grep -qF -- 'T-1165: injected command was not executed' "$T/close-out.log" || rc=1; git status --porcelain -- tests docs bin > "$T/st1" || rc=1; cmp -s "$T/st0" "$T/st1" || rc=1; test "$rc" -eq 0

- [ ] **AC7** (depends on step 2a for its content, not for running.) Every file this task adds or modifies under `bin/`, `tests/` or `docs/loop-engineering/subjects/` that CI names in a `shellcheck` step is `shellcheck`-clean locally. The measured set is the union of the committed range, the unstaged delta and untracked strays. At least one such file is linted. `bin/derive-populations.sh` and `bin/check-pii-shapes.sh` are asserted to be in CI's list. `shellcheck` must be installed; a missing binary fails.
  - check: rc=0; export LC_ALL=C; command -v shellcheck > /dev/null || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac7.XXXXXX") || exit 1; W=.github/workflows/check-handoff.yml; test -s "$W" || exit 1; { git diff --no-renames --name-only --diff-filter=AM "$B"...HEAD -- bin tests docs/loop-engineering/subjects; git diff --no-renames --cached --name-only --diff-filter=AM -- bin tests docs/loop-engineering/subjects; git diff --no-renames --name-only --diff-filter=AM -- bin tests docs/loop-engineering/subjects; git ls-files --others --exclude-standard -- bin tests docs/loop-engineering/subjects; } > "$T/raw" || rc=1; sort -u "$T/raw" > "$T/ch"; n=0; while IFS= read -r f; do grep -qF -- "$f" "$W" || continue; n=$((n+1)); shellcheck "$f" > "$T/sc.$n" 2>&1 || rc=1; done < "$T/ch"; test "$n" -ge 1 || rc=1; for f in bin/derive-populations.sh bin/check-pii-shapes.sh; do grep -qF -- "$f" "$W" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** `.shell-team/test-recipe.md` gains a note tagged `T-1165`, where its base blob carries none. The note names `TMPDIR` and supersedes the file's earlier `$HERE`-fallback and `rm -r` advice for new suites.
  - check: rc=0; export LC_ALL=C; F=.shell-team/test-recipe.md; test -s "$F" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac8.XXXXXX") || exit 1; git show "$B:$F" > "$T/b" 2>/dev/null || exit 1; test -s "$T/b" || exit 1; test "$(grep -c 'T-1165' "$T/b" || true)" = 0 || rc=1; grep -F 'T-1165' "$F" > "$T/n" || rc=1; grep -qF 'TMPDIR' "$T/n" || rc=1; test "$rc" -eq 0

- [ ] **AC9** CI on the pull request is the authority for the full suite population this spec does not run locally. The task's own board entry carries exactly one sub-bullet `  - ci: <check-run id> — conclusion: success — head: <40-hex sha>`. The recorded head is an ancestor of HEAD, and nothing outside `.shell-team/` changed between it and HEAD.
  - above-ceiling: coordinating session — reads the pull request's check runs through MCP after the push and records the line. The CI run itself, not this record, verifies the suites.
  - check: export LC_ALL=C; TD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$TD" || exit 1; L=$(awk '/^- \[[ x]\] \*\*T-1165\*\*/{f=1;next} f&&(/^- \[/||/^#/||/^$/){f=0} f' "$TD" | grep -E '^  - ci: [0-9]+ — conclusion: success — head: [0-9a-f]{40}$'); test "$(printf '%s\n' "$L" | grep -c .)" = 1 || exit 1; H=${L##* }; git merge-base --is-ancestor "$H" HEAD || exit 1; D=$(git diff --no-renames --name-only "$H" HEAD) || exit 1; printf '%s\n' "$D" | grep -v '^\.shell-team/' | grep -q . && exit 1; exit 0

- [ ] **AC10** This task's diff is confined to a fixed allow-list. The measured set is the union of four reads: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only` and the untracked strays `git ls-files --others --exclude-standard`.
  - Allowed: any path under `tests/` or `docs/loop-engineering/subjects/subject-01/`; the eight tools; `.shell-team/test-recipe.md`; `.shell-team/todo.md`; and this task's own spec, provenance, interventions and review records.
  - `.github/workflows/check-handoff.yml` and `bin/close-out.sh` are each byte-identical to their base blobs.
  - Controls: the measured union is asserted non-empty, and the allow-list is asserted not to contain the workflow file or `bin/close-out.sh`.

  **This criterion is merge-point-scoped and expected to go stale after merge**, once later tasks' files land on the same base. That is expected. It is never repaired by widening the base resolution or re-deriving it per rework round.
  - check: rc=0; export LC_ALL=C; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac10.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' bin/aggregate-verdicts.sh bin/check-board-headings.sh bin/check-codex-agents.sh bin/check-commit-identity.sh bin/check-fanout-instances.sh bin/check-pii-shapes.sh bin/check-review-input.sh bin/derive-populations.sh .shell-team/test-recipe.md .shell-team/todo.md .shell-team/specs/T-1165-no-recursive-delete.md .shell-team/provenance/T-1165.md .shell-team/interventions/T-1165.md .shell-team/reviews/T-1165.md | sort -u > "$T/allow"; for n in .github/workflows/check-handoff.yml bin/close-out.sh; do grep -qxF -- "$n" "$T/allow" && rc=1; git show "$B:$n" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; cmp -s "$T/b" "$n" || rc=1; done; grep -vxF -f "$T/allow" "$T/got" | grep -vE '^(tests/|docs/loop-engineering/subjects/subject-01/)' > "$T/extra" || true; test ! -s "$T/extra" || rc=1; test "$rc" -eq 0

- [ ] **AC11** This spec is a conformant carrier of its own declarations. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. Positive control: the spec and the checker are asserted non-empty first.
  - check: C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1165-no-recursive-delete.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1165-ac11.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; rc=0; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes**: what the repository's own suites, tools and the environments they run in actually produce.

1. Recursive-delete spellings in suite and fixture source as measured at `8a6cc48c`:
   - `rm -rf` in an inline `trap '…' EXIT`, in a `cleanup()` function and as a bare mid-suite statement;
   - inside a quoted attack string;
   - inside comments and backticks;
   - after `chmod -R u+rwx …;` in the same trap.
   The gate also covers the reachable variants an author could write: split or reordered flags (`-r`, `-R`, `-fr`, `-f -r`, `--recursive`), `find … -delete`, `xargs rm`, `-exec rm` and `git clean`.
2. Scratch-root creation in suites, both inside and outside an `if [ -n "${TMPDIR:-}" ]` branch, including the unconditional fixed-depth root in `tests/rework-digest/run.sh`.
3. `TMPDIR` set (a sandbox session root, or a fresh per-check directory) or unset (fallback `/tmp`).
4. Tool scratch layouts:
   - flat fixed names;
   - indexed names (`part.$i`, `raw.$idx`, `stderr.$idx`);
   - files created in command-substitution subshells whose names the parent never learns (`check-board-headings.sh`);
   - one nested generator directory (`check-codex-agents.sh`'s `fresh/`).
5. Tool exits after the scratch directory exists: success `0`; a finding or refusal `1`; usage or structural `2`; drift `1` (`check-codex-agents.sh`); `3` for an uncovered unit or part.
6. Cleanup failures: `rmdir` refusing a non-empty directory (an unknown or dot file left behind), and `rmdir` failing outright (simulated by the `PATH` shim).
7. Both execution venues: the operator's machine, which runs only grep-clean files, and the CI runner, which runs every suite.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Deletion reached through indirection a static scan cannot trace: a command name in a variable (`"$RM" -rf`), `eval` of an assembled string, an alias, or a function wrapping `rm`.
2. Deletion in a language other than bash (a `python -c 'shutil.rmtree…'`). No suite or fixture uses one today.
3. A shell loop that removes a tree file by file with non-recursive `rm -f` calls.
4. `SIGKILL` or power loss during cleanup, which leaves the scratch directory behind. That is acceptable under the standing rule.
5. A `TMPDIR` that points at an unwritable or non-directory path. Today's `mktemp` failure handling covers it unchanged.
6. Concurrent runs of one suite sharing a `TMPDIR`. Unique `mktemp` names already isolate them.

<!-- END intent-block: T-1165 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | No recursive delete under `tests/` or the docs fixture, in code, strings or comments (Goal, issue Expected 1) | **AC1** |
| 2 | Temp directories are left under `$TMPDIR`; no in-checkout scratch roots (Goal, constraint block) | **AC3**, and the status-unchanged assertions in **AC5** and **AC6** |
| 3 | Eight tools: no recursive delete; by-name removal then `rmdir` (Goal, issue Expected 2) | **AC2**, **AC4**, **AC5** |
| 4 | Normal run leaves nothing under `$TMPDIR`; exit status survives a failed cleanup (Goal, N3) | **AC4**, **AC5** |
| 5 | `derive-populations.sh` and `check-pii-shapes.sh` must use the by-name form (Goal) | **AC4**, and **AC5**'s D1 exclusion |
| 6 | Issue's "keep current cleanup with reason" alternative not exercised (Non-goals) | **AC2** |
| 7 | Class-3 attack strings keep proving non-execution with a payload that deletes nothing (AC1 body) | **AC5**, **AC6** (canary labels) |
| 8 | Class-2 cases still assert what they did (AC6 body) | **AC6** (pass-call count at least the base's); the meaning is review-judged |
| 9 | Class-5 non-writable tree left under `$TMPDIR` (AC1 body) | **AC1** (gate); **AC6** runs `retro-inputs` |
| 10 | `rework-digest`'s fixed-depth case keeps proving relative-symlink resolution (AC3 body) | **AC3**, **AC6** |
| 11 | Changed suites judged by CI; no local run of a file that still contains a recursive delete (constraint block, issue Expected 3) | **AC9**, and the gate at the head of **AC4**, **AC5** and **AC6** |
| 12 | Every check line obeys the constraint block (Goal) | info-only (not promoted to AC). It is a property of this spec's own text, enforced at freeze by the coordinating session's live read of each line, and no criterion can meaningfully assert it about itself. |
| 13 | Shellcheck-clean (repository working rule) | **AC7** |
| 14 | Supersede the test recipe's old advice | **AC8** |
| 15 | No workflow change, no `close-out.sh` change, no new `bin/` mechanism (Non-goals) | **AC10** |
| 16 | No sandbox or permission change (Non-goals) | info-only (not promoted to AC). Operator configuration lives outside the repository and no repository read can observe it. |
| 17 | Merged specs not rewritten or run; no blast-radius sweep (Non-goals, constraint block) | **AC10** (no `.shell-team/specs/` path besides this spec in the allow-list); not running them is info-only, since an absence of execution cannot be observed statically |
| 18 | `context-lifecycle.md:97` untouched, recorded as an observation (Non-goals) | **AC10** (outside the allow-list) |
| 19 | No reclaiming of `$TMPDIR` space (Non-goals) | info-only (not promoted to AC). A declined duty, not a behaviour. |
| 20 | No sweep under A2 (Non-goals) | info-only (not promoted to AC). A process deviation recorded by the operator's standing mode. |
| 21 | Pre-commitment drop order (Goal) | info-only (not promoted to AC). An executable disposition, already admitted by **AC5**. |
| 22 | Declarations conformant | **AC11** |

## Verification order (for QA and the coordinating session)

1. Run the **AC1**/**AC2** gate first (`git grep`). Any match is a `FAIL`, and nothing else runs.
2. Run `shellcheck` (**AC7**).
3. Run locally only grep-clean files: the eight tools' suites (**AC5**), the class-2/3/5 suites and `rework-digest` (**AC6**), and the direct tool cases (**AC4**). Each check counts entries under its own fresh `TMPDIR` and requires `git status --porcelain -- tests docs bin` to be unchanged.
4. Run `check-acs` on this spec only. Never run it on a merged spec.
5. CI on the pull request is the authority for every other suite. The coordinating session reads the check runs through MCP and records the `- ci:` sub-bullet (**AC9**).

The `AC4`–`AC6` lines run real suites. Set `CHECK_ACS_TIMEOUT` high enough for `close-out`, `errexit-safe` and `codex-agents` (the precedent value is `300`; raise it if a run times out rather than splitting the criterion).

## Population (placeholder)

The relayed issue counts (56 files / 99 occurrences) and tech-lead's tool read (55 / 97) disagree, and neither is frozen. After step 2a, the coordinating session produces the base-side population with `bin/derive-populations.sh`, reading the base blobs and never running a file, and embeds the emitted block here, preceded by its own `- reproduce:` line.

Produced after step 2a (the tool is clean at that point), reading the base blobs through `git grep <ref>` and never running a file. The tool reports 56 files and 95 sites (`path:line`) for the gate pattern `P`; the issue relayed 99 occurrences and tech-lead's read 55 / 97, and none of those counts is frozen.

- reproduce: P='(^|[^[:alnum:]_.-])rm([[:space:]]+-[^[:space:]]*)*[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|$)|(^|[^[:alnum:]_-])find[[:space:]].*[[:space:]]-delete([[:space:]]|;|$)|xargs([[:space:]]+[^|;&]*)?[[:space:]]rm([[:space:]]|$)|-exec(dir)?[[:space:]]+rm([[:space:]]|$)|git[[:space:]]+clean([[:space:]]|$)'; export P; B=8a6cc48c8e6b82bf1cf99a1ec740dc8915a7a50b; bash bin/derive-populations.sh --label t1165-base --set 'tests-docs-sites=git grep -n -E -- "$P" '"$B"' -- tests docs/loop-engineering/subjects | cut -d: -f2,3' --set 'tests-docs-files=git grep -l -E -- "$P" '"$B"' -- tests docs/loop-engineering/subjects | cut -d: -f2' --set 'bin-sites=git grep -n -E -- "$P" '"$B"' -- bin | cut -d: -f2,3'

<!-- BEGIN derivation: t1165-base -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: tests-docs-sites — status: 0 — lines: 95 — items: 95 — command: git grep -n -E -- "$P" 8a6cc48c8e6b82bf1cf99a1ec740dc8915a7a50b -- tests docs/loop-engineering/subjects | cut -d: -f2,3
- set: tests-docs-files — status: 0 — lines: 56 — items: 56 — command: git grep -l -E -- "$P" 8a6cc48c8e6b82bf1cf99a1ec740dc8915a7a50b -- tests docs/loop-engineering/subjects | cut -d: -f2
- set: bin-sites — status: 0 — lines: 9 — items: 9 — command: git grep -n -E -- "$P" 8a6cc48c8e6b82bf1cf99a1ec740dc8915a7a50b -- bin | cut -d: -f2,3
- union: items: 160
- bucket: bin-sites — items: 9
  - bin/aggregate-verdicts.sh:227
  - bin/check-board-headings.sh:120
  - bin/check-board-headings.sh:130
  - bin/check-codex-agents.sh:105
  - bin/check-commit-identity.sh:137
  - bin/check-fanout-instances.sh:290
  - bin/check-pii-shapes.sh:626
  - bin/check-review-input.sh:218
  - bin/derive-populations.sh:301
- bucket: tests-docs-files — items: 56
  - docs/loop-engineering/subjects/subject-01/acceptance.sh
  - tests/aggregate-verdicts/run.sh
  - tests/bin-help/run.sh
  - tests/check-acs/run.sh
  - tests/check-adapter/run.sh
  - tests/check-adopter-docs/run.sh
  - tests/check-binding/run.sh
  - tests/check-board-headings/run.sh
  - tests/check-commit-identity/run.sh
  - tests/check-count-claims/run.sh
  - tests/check-durability/run.sh
  - tests/check-entry-mode/run.sh
  - tests/check-fanout-instances/run.sh
  - tests/check-intent/run.sh
  - tests/check-interventions/run.sh
  - tests/check-invocation-path/run.sh
  - tests/check-liveness/run.sh
  - tests/check-model-pins/run.sh
  - tests/check-oversight/run.sh
  - tests/check-pii-shapes/run.sh
  - tests/check-playbook/run.sh
  - tests/check-prompt-sync/run.sh
  - tests/check-provenance/run.sh
  - tests/check-refreeze-class/run.sh
  - tests/check-refreeze-grant/run.sh
  - tests/check-retro/run.sh
  - tests/check-review-input/run.sh
  - tests/check-run/run.sh
  - tests/check-spec-review/run.sh
  - tests/close-out/run.sh
  - tests/cluster-failures/run.sh
  - tests/codex-agents/run.sh
  - tests/codex-skeleton-hygiene/run.sh
  - tests/consolidate-proposals/run.sh
  - tests/derive-populations/run.sh
  - tests/discover-work/run.sh
  - tests/errexit-safe/run.sh
  - tests/gen-loop-replay/run.sh
  - tests/gen-playbook-blocks/run.sh
  - tests/gitignore-raw-dumps/run.sh
  - tests/goal-state/run.sh
  - tests/install/run.sh
  - tests/interventions-reminder/run.sh
  - tests/land-worktree/run.sh
  - tests/log-run/run.sh
  - tests/loop-guard/run.sh
  - tests/playbook-promote/run.sh
  - tests/resolve-executor/run.sh
  - tests/retro-inputs/invariants.sh
  - tests/retro-inputs/run.sh
  - tests/rework-digest/run.sh
  - tests/rollup-runs/run.sh
  - tests/rollup-track/run.sh
  - tests/team-init/run.sh
  - tests/team-paths/run.sh
  - tests/trial-recipe/run.sh
- bucket: tests-docs-sites — items: 95
  - docs/loop-engineering/subjects/subject-01/acceptance.sh:64
  - tests/aggregate-verdicts/run.sh:38
  - tests/bin-help/run.sh:54
  - tests/bin-help/run.sh:74
  - tests/check-acs/run.sh:27
  - tests/check-adapter/run.sh:137
  - tests/check-adopter-docs/run.sh:97
  - tests/check-binding/run.sh:142
  - tests/check-board-headings/run.sh:29
  - tests/check-commit-identity/run.sh:51
  - tests/check-count-claims/run.sh:18
  - tests/check-durability/run.sh:44
  - tests/check-entry-mode/run.sh:19
  - tests/check-fanout-instances/run.sh:29
  - tests/check-intent/run.sh:431
  - tests/check-intent/run.sh:70
  - tests/check-intent/run.sh:77
  - tests/check-intent/run.sh:813
  - tests/check-intent/run.sh:827
  - tests/check-interventions/run.sh:54
  - tests/check-invocation-path/run.sh:31
  - tests/check-liveness/run.sh:82
  - tests/check-model-pins/run.sh:40
  - tests/check-oversight/run.sh:20
  - tests/check-pii-shapes/run.sh:73
  - tests/check-playbook/run.sh:33
  - tests/check-prompt-sync/run.sh:249
  - tests/check-prompt-sync/run.sh:33
  - tests/check-prompt-sync/run.sh:37
  - tests/check-provenance/run.sh:602
  - tests/check-provenance/run.sh:63
  - tests/check-provenance/run.sh:657
  - tests/check-provenance/run.sh:671
  - tests/check-provenance/run.sh:70
  - tests/check-refreeze-class/run.sh:87
  - tests/check-refreeze-grant/run.sh:150
  - tests/check-refreeze-grant/run.sh:155
  - tests/check-refreeze-grant/run.sh:160
  - tests/check-refreeze-grant/run.sh:168
  - tests/check-refreeze-grant/run.sh:21
  - tests/check-retro/run.sh:204
  - tests/check-retro/run.sh:260
  - tests/check-retro/run.sh:269
  - tests/check-retro/run.sh:286
  - tests/check-retro/run.sh:98
  - tests/check-review-input/run.sh:215
  - tests/check-review-input/run.sh:29
  - tests/check-run/run.sh:31
  - tests/check-spec-review/run.sh:28
  - tests/close-out/run.sh:111
  - tests/close-out/run.sh:141
  - tests/close-out/run.sh:34
  - tests/cluster-failures/run.sh:122
  - tests/codex-agents/run.sh:30
  - tests/codex-skeleton-hygiene/run.sh:255
  - tests/consolidate-proposals/run.sh:24
  - tests/derive-populations/run.sh:40
  - tests/discover-work/run.sh:31
  - tests/errexit-safe/run.sh:477
  - tests/errexit-safe/run.sh:483
  - tests/errexit-safe/run.sh:490
  - tests/errexit-safe/run.sh:500
  - tests/errexit-safe/run.sh:529
  - tests/errexit-safe/run.sh:540
  - tests/errexit-safe/run.sh:77
  - tests/gen-loop-replay/run.sh:47
  - tests/gen-playbook-blocks/run.sh:149
  - tests/gen-playbook-blocks/run.sh:29
  - tests/gen-playbook-blocks/run.sh:40
  - tests/gen-playbook-blocks/run.sh:51
  - tests/gitignore-raw-dumps/run.sh:45
  - tests/goal-state/run.sh:25
  - tests/install/run.sh:34
  - tests/interventions-reminder/run.sh:62
  - tests/land-worktree/run.sh:45
  - tests/log-run/run.sh:132
  - tests/log-run/run.sh:33
  - tests/loop-guard/run.sh:14
  - tests/loop-guard/run.sh:32
  - tests/playbook-promote/run.sh:135
  - tests/playbook-promote/run.sh:34
  - tests/resolve-executor/run.sh:42
  - tests/retro-inputs/invariants.sh:121
  - tests/retro-inputs/invariants.sh:82
  - tests/retro-inputs/invariants.sh:85
  - tests/retro-inputs/run.sh:44
  - tests/rework-digest/run.sh:62
  - tests/rollup-runs/run.sh:106
  - tests/rollup-runs/run.sh:137
  - tests/rollup-track/run.sh:35
  - tests/team-init/run.sh:60
  - tests/team-paths/run.sh:28
  - tests/trial-recipe/run.sh:149
  - tests/trial-recipe/run.sh:153
  - tests/trial-recipe/run.sh:55
<!-- END derivation: t1165-base -->

## Blast radius

`- verification-class: mechanism`. The full-population downstream-impact inventory this role would normally take is **not taken**. The operator's standing rule forbids running merged specs' check lines and forbids any spec requiring a blast-radius check through them. This is a disclosed deviation from the pm-spec checklist, made on operator authority.

Known consequences, from reading merged spec text only (nothing run):

- **Expected to go red.** `.shell-team/specs/T-1160-spec-review-round-cap.md` **AC5** requires every base line of `tests/check-spec-review/run.sh` to survive at HEAD. This task removes that suite's trap line `:28` (and the `$HERE` fallback at `:26`). Any other merged criterion that pins suite lines, counts recursive-delete strings, or asserts `$HERE` scratch roots goes red in the same way. That class is disclosed categorically rather than enumerated, because enumerating it would require running merged specs' check lines.
- **Indirection class:** merged criteria that reach these files through a suite run or a run-time path are unmeasured by construction.

**Adopter-side artifacts:**

- The eight tools ship. A normal run behaves as before. A run whose cleanup fails, or (under D1) a tool that falls back, now leaves one directory under the adopter's `$TMPDIR` instead of attempting a recursive delete. No adopter configuration, generated file or telemetry changes name or shape.

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #641: no recursive delete in suites, fixture or tool cleanup | not met | met (the eight tools run on every default loop path, e.g. `close-out.sh` → `check-review-input.sh`) | PATCH | A safety fix to internals. Nothing new becomes possible for an adopter. **Relayed premise:** sprint "delete-guardrail" approved 2026-10-01 with v2.7.8 PATCH (owner: coordinating session). The derived tier matches it. |

## Assumptions

- **Relayed:** issue #641's body and the operator's standing rule, both via the coordinating session (primary: the coordinating session). Not read by this role.
- **Relayed:** the sprint premise "delete-guardrail, approved 2026-10-01, v2.7.8 PATCH". The freeze run records the version-derivation line on the board.
- **Relayed premise measured true:** tech-lead's site list by class (Routing Map step 1). Every listed `tests/` site was found at the listed line by this role's Grep-tool read at `8a6cc48c`, plus the class-1 trap sites. Tech-lead's "31 suites fall back to `$HERE`" was read as 34 matching lines over 32 files. Not frozen: **AC3** asserts zero at HEAD, not a base count.
- **Relayed premise measured true:** `bin/close-out.sh:651`–`:666` calls `check-review-input.sh`.
- **Measured here:** no `bin/` file outside the eight contains a recursive delete; `rmdir` appears in `bin/` only in `land-worktree.sh` and `log-run.sh`, neither of which the shim cases run. These are Grep-tool reads (case-sensitive, ripgrep semantics), not the `git grep -E` the criteria run. The freeze run's live execution is the measurement of record.
- **Decisions made here** (the engineer may not relax them without a re-freeze):
  - The gate covers comments and strings as well as code. A mention is reworded, never exempted.
  - The gate also covers `-exec rm` and `git clean`, which the standing rule's "and similar" reaches, at no measured cost (zero occurrences in `bin/`, `tests/` and the fixture today).
  - The shim is a `rmdir` that exits `1`. Tools therefore call `rmdir` by name through `PATH`, so the failure case is observable. The shimmed run must leave exactly one directory, which proves the shim fired.
  - D1 is admitted by **AC5** without a re-freeze, and is closed to `derive-populations.sh` and `check-pii-shapes.sh`.
- **Borrowed and own-coinage count premises** (read by this role at `8a6cc48c`; the freeze run re-measures each live and records the value here):

| Token or read | Class | Value read now | Command |
|---|---|---|---|
| gate pattern `P` in `.github/workflows/check-handoff.yml` | borrowed (runner-only sites) | at least 1 (two `rm -rf` lines, `:206`, `:376`) | `git grep -c -E -- "$P" -- .github/workflows/check-handoff.yml` |
| gate pattern `P` in `bin/` outside the eight | borrowed | 0 | `git grep -l -E -- "$P" -- bin` (expect the eight files only, at base) |
| `T-1165` in `.shell-team/test-recipe.md` | own coinage | 0 | `git show "$B:.shell-team/test-recipe.md" \| grep -c T-1165` |
| `T-1165:` labels in `tests/` | own coinage | 0 | `git grep -c -F 'T-1165:' -- tests` |
| `bin/derive-populations.sh`, `bin/check-pii-shapes.sh` in the workflow's shellcheck list | borrowed | present | `grep -cF <path> .github/workflows/check-handoff.yml` |

(`\|` is markdown escaping for `|`.)

## Open questions

None blocking.

## Notes for engineer

- **Standing rule in your own work.** Never run a suite or tool that still contains a recursive delete. Convert a file first, confirm it is grep-clean with the gate, and only then run it. Never type one, even to tidy up. If a deletion seems necessary, stop and report `BLOCKED`.
- **Files touched:** the eight `bin/` tools, the suites under `tests/`, `docs/loop-engineering/subjects/subject-01/acceptance.sh`, `.shell-team/test-recipe.md` (append only), and this task's records. Nothing else (**AC10**).
- **Site classes** (Grep-tool line numbers at `8a6cc48c`; the gate is the authority, not this list):
  - (1) EXIT traps or `cleanup()` that remove the root: drop the deletion and leave the root under `$TMPDIR`. Where a trap did nothing else, remove the trap.
  - (2) mid-suite resets: use a fresh `mktemp -d` per case, or move the old directory into the suite's own root with `mv` (not a deletion). Sites:
    - `tests/check-refreeze-grant/run.sh:150,155,160,168`
    - `tests/errexit-safe/run.sh:477,483,490,500,529,540`
    - `tests/trial-recipe/run.sh:149,153`
    - `tests/gen-playbook-blocks/run.sh:40,51,149`
    - `tests/check-prompt-sync/run.sh:37,249`
    - `tests/close-out/run.sh:111` (a directory replaced by a file: `mv` the directory aside, or build that root without it)
    - `tests/check-retro/run.sh:204,269`, plus the re-armed traps at `:98,260,286`
    - `tests/check-provenance/run.sh:602,671`
    - `tests/check-intent/run.sh:431,827`
    - `tests/playbook-promote/run.sh:135`
    - `tests/cluster-failures/run.sh:122`
    - `tests/bin-help/run.sh:74`
    - `tests/rollup-runs/run.sh:106,137`
  - (3) attack strings: `tests/close-out/run.sh:141`, `tests/check-review-input/run.sh:215`. Use a payload that would create a canary file if executed, for example `touch "$ROOT/canary"`. Assert that file is absent, and print the **AC5**/**AC6** label.
  - (4) comments: `tests/check-provenance/run.sh:57,70,657`, `tests/check-intent/run.sh:64,77,813`, `tests/loop-guard/run.sh:14`, `tests/log-run/run.sh:132`, `tests/retro-inputs/run.sh:42`, `tests/retro-inputs/invariants.sh:82,121`, `bin/check-board-headings.sh:120`. Reword them without the spelling.
  - (5) `tests/retro-inputs/run.sh:44`, `tests/retro-inputs/invariants.sh:85`: drop the trap. Leaving the non-writable tree under `$TMPDIR` is acceptable.
- **Scratch roots:** replace each `$HERE` fallback arm with `${TMPDIR:-/tmp}`. `.shell-team/test-recipe.md:815` records that this sandbox denies direct writes to `/tmp`, which is why `TMPDIR` is set in practice.
- **`tests/rework-digest/run.sh`:** the root must move under `$TMPDIR` (**AC3**), but `:166`'s `../../../../bin/rework-digest.sh` relative link depends on a fixed depth below the repository root. One shape that keeps the property: copy `bin/` into the root, and point the relative link at that copy from a fixed depth inside the root. The case must still prove that a relative-symlink launch resolves the sibling scripts.
- **Tool cleanup shape:** the prior art is `bin/land-worktree.sh:383`–`:386`. Use `rm -f "$DIR"/* 2>/dev/null || true; rmdir "$DIR" 2>/dev/null || true`, or remove the files by name. Call `rmdir` by name so the `PATH` shim can reach it. `rm -f` with a non-recursive glob is not a recursive delete, and it skips dotfiles, so `rmdir` then leaves the directory. That is acceptable.
  - `check-board-headings.sh`: temp files come from `new_tmp` in subshells, so use the glob form inside its own `WORKDIR`, and keep the `if` form and its comment's reason (exit-status safety under `set -e`).
  - `check-codex-agents.sh`: clean `$SCRATCH/fresh/*`, then `rmdir` `fresh`, then `rmdir` `$SCRATCH`. Leave both in place if anything unknown remains.
  - `check-pii-shapes.sh` and `check-commit-identity.sh` have bare `cleanup()` bodies under `set -euo pipefail`. Guard every command so a failure cannot change the exit status (N3).
  - `check-review-input.sh` is called by `bin/close-out.sh:651`–`:666`, so its exit statuses must not move.
- **Suite labels** (exact strings, one per tool in that tool's own suite):
  - `T-1165: <tool>.sh exit status survives a failed rmdir`
  - `T-1165: <tool>.sh leaves no scratch directory`, or the D1 fallback `T-1165: <tool>.sh leaves its scratch directory under TMPDIR`
  - for the two attack strings, `T-1165: injected command was not executed`

  Print them through each suite's existing `pass` helper.
- **D1:** if you take it for a tool, record it in `.shell-team/provenance/T-1165.md` with the tool's file name and the reason its layout cannot be enumerated.
- **`.shell-team/test-recipe.md`:** append a `T-1165` note naming `TMPDIR` that supersedes the `$HERE`-fallback idiom (`:552`–`:565`, `:593`–`:596`) and the `rm -r` advice (`:1539`–`:1631`) for new suites.
- **Measured-at-ref command check:** not applicable. No deliverable prints a command labelled as measured at a git ref.
- **Observation, out of scope:** `docs/loop-engineering/context-lifecycle.md:97` prints a reproduce command containing a recursive delete. It is a candidate follow-up issue for the coordinating session, not this task.

## Notes from engineer

- **Deviation (PII check order).** The pattern-based PII-shape check was not run on the spec, board and records at the spec's first commit, because `bin/check-pii-shapes.sh` itself contained a recursive delete until step 2a and the standing rule forbids running such a file. It was run after 2a, on the working tree, before the hand-off (result recorded on the board entry).
- **Step 2a design.** The eight tools empty their own scratch directory with a non-recursive `rm -f "$DIR"/*` and then `rmdir "$DIR"`, both guarded with `|| true` and wrapped in an `if [ -n … ] && [ -d … ]` so an empty variable can never turn the glob into `/*`. `check-codex-agents.sh` does the same for `$SCRATCH/fresh` first and then for `$SCRATCH`. D1 was not taken for any tool.
- **Merged-spec criteria expected to go red (read from text only, nothing run).** `T-1160-spec-review-round-cap.md` **AC5** (every base line of `tests/check-spec-review/run.sh` survives at HEAD: the trap line and the `$HERE` fallback arm are gone). The same class applies to any merged criterion that pins suite lines or counts recursive-delete strings or `$HERE` scratch roots; it is disclosed by class, not enumerated.
