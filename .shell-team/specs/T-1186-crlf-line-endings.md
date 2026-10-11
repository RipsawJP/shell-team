# A fresh clone of the plugin is LF whatever `core.autocrlf` says, and the run-start check names a CRLF declaration file before the run stops on it

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1186

## Problem

Issue #720 (shell-team v2.8.8, Windows 11, Git Bash): with `core.autocrlf=true` and no `.gitattributes` in the plugin repository, git writes the plugin's text files to the working tree with CRLF line endings while the index stays LF (`git ls-files --eol` shows `i/lf w/crlf` for `bin/check-invocation-path.sh` and `templates/prompt-blocks/alternate-executor-invocation.md`). `bin/check-invocation-path.sh` reads the recipe's declaration rows line by line and splits each into fields, so the third field becomes `in-process` followed by a carriage return. That value matches neither `in-process` nor `sandbox-read-only`, the gate reports `check-invocation-path: declaration-integrity: invocation-recipe: malformed row` and exits 2 for every role, and `/shell-team:run` stops at Step 1 before any role is dispatched. Nothing warns earlier: `team-setup.sh` and `check-setup.sh` both exit 0. The reporter proposed (1) a `.gitattributes` with `eol=lf` as the root fix, (2) stripping the carriage return in the readers as insurance, and (3) a CRLF check in `check-setup.sh` as a bridge. Their own workaround, which they had not verified, was a clone made with `git clone -c core.autocrlf=false`.

The coordinating session reproduced the failure on macOS at planning. It extracted `git archive HEAD` under `$TMPDIR` and converted only `templates/`, `agents/` and `skills/` to CRLF, leaving `bin/` LF. With `templates/adapters/*` also CRLF, the run fails one step earlier, in `resolve-executor.sh` (`binding-unresolved: … templates/adapters/claude-cli.txt`). With only the recipe file CRLF, it gets exactly the issue's message, rc 2. With every file LF it gets `admitted engineer claude-cli in-process`, rc 0. On that CRLF copy `check-setup.sh` exits 0.

A plugin installed through the plugin manager reaches the disk by the same path, a git clone, so it shows the same symptom.

This task ships options (1) and (3). Option (2) is out of scope (see Non-goals).

## Summarized sources

- Issue #720 body. It was relayed by the coordinating session as text, because this role cannot open the tracker. The facts carried over are these. The environment is `core.autocrlf=true` with no `.gitattributes`, so the working tree is CRLF and the index is LF. The failing field is the third one of the recipe row. The gate exits 2 for every role at Step 1. `team-setup.sh` and `check-setup.sh` both exit 0. The reporter proposed three remedies, ranked as root fix, insurance and bridge. The reporter's clone-time workaround is unverified. Restated by the Goal sentence, D1, D2, Non-goals 1–2 and Input space classes 1–3.
- `bin/check-setup.sh` at the branch point, read in full:
  - Lines 20–27: the write set is none, nothing is created under `$TMPDIR`, the script never suggests a host setting, and the non-help path has no here-string or here-document.
  - Lines 37–42: exit precedence is 2 > 1 > 0.
  - Lines 60–61: `PLUGIN_ROOT` and `TEMPLATES_DIR`.
  - Line 174: `add_note()`, which never sets an exit flag.
  - Line 237: the precedent that an input the script cannot evaluate sets `EC2=1`.
  - Lines 66–95: the `--help` text, which names `- note:` lines only for scaffold drift.

  The script contains no `CRLF`, `crlf` or `\r` today (Grep tool, 0 matches). Restated by D2 and **AC3**.
- `skills/run/SKILL.md` line 22 (Step 0): "On exit `0` continue the run unchanged, relaying any `- note:` lines it printed". A note therefore reaches the operator before Step 1 even though it never changes the exit code. Restated by D2 and the Goal sentence.
- `tests/check-setup/run.sh`, read in full:
  - Line 37: its own recursive-delete gate.
  - Line 65: `ck` runs every check with `TMPDIR` pointed at one empty directory, which line 264 asserts is still empty.
  - Line 177: the `100755` index-mode check, which needs a git checkout.
  - Lines 205–223: the read-only checksum lock, run on a plugin copy of `bin templates agents .claude-plugin`.
  - Lines 278–283: the forbidden-token list, which does not contain `core.autocrlf`.

  Restated by D3, **AC4** and **AC9**.
- `.github/workflows/check-handoff.yml`: line 41 `run: shellcheck bin/check-setup.sh tests/check-setup/run.sh`; lines 408–409 run `tests/check-setup/run.sh`; line 332 dogfoods `bin/check-invocation-path.sh --role tech-lead`. Because of these existing steps, the suite cases this task adds need no workflow edit. Restated by **AC6** and **AC7**.
- `bin/check-invocation-path.sh` lines 28 and 37: usage `check-invocation-path.sh --role <role>`; on success it prints `admitted <role> <adapter> <invocation-kind>`. Restated by **AC1**.
- `templates/adapters/` holds exactly `claude-cli.txt` and `codex-cli.txt` (Glob tool). Restated by D2 and **AC3**.
- `docs/adopting.md` `## How to run`:
  - Lines 192–204: the Step 0 paragraph, opening `**Before the first dispatch, the run checks that setup is in place.**`.
  - Line 206: the next paragraph, opening `**The loop operates on the repository your session is rooted in.**`.
  - Line 464: a second mention of `check-setup.sh`, which describes the prerequisites it checks. It stays true and is not edited.
  - Line 59: the file's only `--global` (global excludes, unrelated to this task).

  `docs/adopting.ja.md` has the counterparts: lines 198–208 (`**最初の dispatch の前に、run は setup が揃っていることを確認します。**`), line 210 (`**ループはセッションの root にある repository に対して動きます。**`), line 469 and line 61. Neither file contains `core.autocrlf` today (Grep tool). Restated by D4 and **AC5**.
- `README.md` line 141 describes Step 0 as stopping `BLOCKED` on something missing. It does not list the note lines, so an added note does not contradict it. It is therefore not edited and not listed as a `shipped-docs` line. `README.ja.md` has the counterpart.
- `bin/check-adopter-docs.sh` lines 28–40: the declaration grammar this spec's `- user-visible:`, `- adopter-surface:` and `- shipped-docs:` lines follow.

## Goal

<!-- BEGIN intent-block: T-1186 -->

- user-visible: yes — an adopter whose git converts line endings (`core.autocrlf=true`, the usual Git for Windows setup) gets a plugin checkout the run can start from when the clone is made at the release that ships this task. An adopter whose existing checkout is still CRLF is told so by the run-start check, with a clone-scoped remedy, before the run stops at Step 1. The adopting guide (EN and JA) says both.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- verification-class: mechanism — the diff adds a root `.gitattributes` (it changes how git writes every text file of the plugin), changes `bin/check-setup.sh` and extends `tests/check-setup/run.sh`.
- verification-ceiling: unit-and-static — **AC1**–**AC7** and **AC9** are settled in a plain checkout. They use scratch clones of this checkout under `$TMPDIR` made with `git clone -c core.autocrlf=…`, a `git archive` extraction, a plugin copy with its declaration files converted to CRLF, the fixture suite (at HEAD, at the base, and in a mutated scratch clone), byte-scoped diffs, and shellcheck's exit code. **AC8** (CI on the pull request) sits above the ceiling. No criterion runs on Windows or Git Bash.
- base-ref-discriminator: not-applicable — the branch has no open predecessor: it is cut from `develop` at `f5b0569b` (v2.9.0). Every base-side read in **AC1**, **AC3**, **AC4**, **AC5** and **AC6** resolves `B` with the same byte-identical chain: `git merge-base develop HEAD` when `git show-ref --verify --quiet refs/heads/develop` succeeds, else `git merge-base refs/remotes/origin/develop HEAD` when `git show-ref --verify --quiet refs/remotes/origin/develop` succeeds. If neither resolves, the check fails (exit 1) rather than passing.

**Goal (one sentence).** A clone of the plugin made at HEAD has an LF working tree for every text file whatever its `core.autocrlf` value, except the tracked fixtures that deliberately carry other bytes, which stay byte-identical with their blobs; `bin/check-invocation-path.sh --role engineer` admits the role in such a clone; and `bin/check-setup.sh` prints one `- note:` line for each declaration file under the plugin root that contains a carriage return, naming the file and the two re-clone remedies (re-adding the marketplace for a plugin-manager install, a fresh `git clone -c core.autocrlf=false` for a manual clone), without changing its exit code, while a missing or unreadable declaration file makes it exit 2.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — `.gitattributes` at the repository root.** It contains these lines, each exactly as written:
  - `* text=auto eol=lf`
  - `bin/** text eol=lf`, `templates/** text eol=lf`, `agents/** text eol=lf`, `skills/** text eol=lf` and `tests/** text eol=lf`
  - `tests/check-handoff/fixtures/valid-crlf.md -text`, placed after the `tests/**` line, because a later matching line wins
  - `*.png binary`
  - `tests/derive-populations/fixtures/control-char.txt -text`

  Adding the file changes no tracked blob, so `git add --renormalize .` is a no-op. (**AC1**, **AC2**)
- **D2 — the note in `bin/check-setup.sh`.** The fixed declaration list, read from the plugin root, is:
  - `templates/prompt-blocks/alternate-executor-invocation.md`
  - `templates/adapters/claude-cli.txt`
  - `templates/adapters/codex-cli.txt`
  - `templates/binding-default.conf`

  Each file in the list that contains a carriage return byte gets one `- note:` line. The line contains `CRLF`, names the file's path under the plugin root, and names both remedies, each of which makes a new clone: for a plugin-manager install, `/plugin marketplace remove ripsawjp` followed by `/plugin marketplace add RipsawJP/shell-team`; for a manual clone, cloning again with `git clone -c core.autocrlf=false`. It may also name what happens if nothing is done (the run stops at Step 1).
  - **Exit code.** The note never changes it: 0 stays 0, 1 stays 1.
  - **Fail closed.** A missing or unreadable file in the list sets `EC2=1`, so the script exits 2.
  - **How it detects.** Pure bash and the tools the script already uses, with no here-string, no here-document outside `--help`, and nothing written anywhere, `$TMPDIR` included. No output and no source line carries `--global`.
  - **Help.** `--help` names the CRLF note. (**AC3**)
- **D3 — the fixture suite.** `tests/check-setup/run.sh` gains three cases, built on its existing plugin-copy pattern, with these exact labels (**AC4**):
  - `crlf: declaration files with CRLF line endings get one note each and exit 0`
  - `crlf: LF declaration files get no CRLF note and exit 0`
  - `crlf: an unreadable declaration file exits 2`

  Every label the base suite passes still passes. If the note is suppressed in a scratch clone, the suite fails on the first `crlf:` label. `.shell-team/test-recipe.md` records the mutation. (**AC9**)
- **D4 — the docs paragraph.** One new paragraph in `docs/adopting.md` and one in `docs/adopting.ja.md`, each a pure addition placed between the Step 0 check-setup paragraph and the next paragraph. The two carry the same content:
  - the `core.autocrlf=true` / CRLF symptom
  - that v2.9.1 and later ship `.gitattributes`, so a clone made from then on is LF
  - that a checkout made before stays CRLF until it is re-cloned
  - one sentence saying that `/plugin marketplace update` alone does not fix an existing CRLF checkout
  - what the `- note:` line says
  - the two remedies: `/plugin marketplace remove ripsawjp` then `/plugin marketplace add RipsawJP/shell-team` for a plugin-manager install, and `git clone -c core.autocrlf=false` for a manual clone

  Neither paragraph names `--global`. (**AC5**)
- **D5 — nothing else changes.** The diff is confined to `.gitattributes`, `bin/check-setup.sh`, `tests/check-setup/run.sh`, the two adopting guides and this task's records under `.shell-team/`. So the 23 scripts that read `templates/`, `bin/team-setup.sh`, the declaration rows' grammar and the CI workflow are untouched. (**AC6**)

**Pre-commitment (frozen before round 1; AI self-discipline, never operator-ratified).**

- **Trigger.** Two consecutive rounds, QA or code review, each with a recorded verdict and each with a new Blocker or Major finding of the same class. A round interrupted before a verdict is not counted.
- **Never-dropped.**
  - (N1) LF enforcement by `.gitattributes` (**AC1**, **AC2**).
  - (N2) the note never changes the exit code (**AC3**).

  A defeat of N1 or N2 stops the task and returns it to planning.
- **Droppable, in this order.**
  1. The docs paragraph's placement. **AC5**'s order clauses relax to "anywhere inside `## How to run`", and the paragraph's content clauses stay.
  2. The mutation positive control. **AC9** moves to a fast-follow issue, with the firing round's findings as its requirement list.

  Nothing else is droppable.

## Non-goals

- **No carriage-return stripping in the readers.** The 23 scripts under `bin/` that read something under `templates/` are not touched, and neither are their row grammars. That is the reporter's option (2). It is a separate decision over a much larger surface. (**AC6**)
- **No refusal.** The CRLF note never changes the exit code, and `bin/team-setup.sh` is not changed. (**AC3**, **AC6**)
- **No host-wide setting.** Neither the note nor the docs paragraph tells the operator to change a global git setting. The remedy named is clone-scoped. (**AC3**, **AC5**)
- **No in-place re-checkout command.** The note and the paragraph name only remedies that make a new clone. They do not name a command that rewrites an existing checkout in place. The obvious candidate does not work: it was measured that `git checkout -- .` leaves unchanged files `w/crlf` (see Assumptions). A destructive reset would discard local work. (**AC3**, **AC5**)
- **No CRLF handling for the adopter repository's own files** (board, specs, loop contract). The plugin's `.gitattributes` does not apply to the adopter's repository. That class is reachable on the same hosts and is deferred (see Open questions). (info-only)
- **No release work.** The version bump, `CHANGELOG`, badges and tag land on the release-preparation branch after the merge GO, per `CONTRIBUTING.md` `## Cutting a release`. (**AC6**)
- **No full-population two-arm sweep and no local run of past specs' check lines** (operator rulings: A2 light operation and the 2026-10-01 ruling). CI and this task's own check lines are the measurement. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading committed blobs or the post-implementation tree, and writing only under `$TMPDIR`. Scratch clones and copies stay in place there, and nothing is ever deleted.
- **Timeouts and caps.** A line that runs a script goes through a `tmo` helper. The helper takes a timeout of 120 s, or 1200 s for whole suites, starts the script in its own process group under `ulimit -f`, kills the group on timeout, and writes the captured streams to files bounded by that limit.
- **Environment.** Each line exports a temp `HOME`, `XDG_CONFIG_HOME` and `CODEX_HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and puts stub `claude` and `codex` executables first on `PATH`. A scratch clone's `core.autocrlf` comes only from `git clone -c`, which writes it into that clone's own config.
- **What lines never contain.** No check line uses `ps`, `xargs` or a recursive deletion. A suite or checker is scanned for a recursive-deletion pattern before it runs; if one matches, it is not run and the criterion fails.
- **Base-side reads.** They use the chain in the `base-ref-discriminator` declaration, spelled byte-identically.
- **Staleness.** The criteria that read `B` are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`.

- [ ] **AC1** (D1; N1.) A clone of HEAD is LF whatever `core.autocrlf` says, and the gate admits.
  - **Attribute lines.** `HEAD:.gitattributes` exists and holds each D1 line as a whole line. `tests/check-handoff/fixtures/valid-crlf.md -text` sits on a later line than `tests/** text eol=lf`.
  - **Clone with `core.autocrlf=true`.** The clone checks out HEAD and its config reads `true`.
    - The only `git ls-files --eol` row whose worktree column is `w/crlf` is `tests/check-handoff/fixtures/valid-crlf.md`.
    - Every row under `bin/`, `templates/`, `agents/` and `skills/` is `w/lf`, and there is at least one such row.
    - `valid-crlf.md`, `control-char.txt` and the two PNGs are byte-identical with their HEAD blobs. As a positive control, `valid-crlf.md` contains a carriage return.
    - `bash bin/check-invocation-path.sh --role engineer`, run in the clone, exits `0` and prints the line `admitted engineer claude-cli in-process`.
  - **Clone with `core.autocrlf=false`.** The same single `w/crlf` row. This is the fresh-clone remedy the note names.
  - **Positive control at the base.** A `core.autocrlf=true` clone checked out at `B` lists the recipe file among several `w/crlf` rows.
  - **The issue's reproduction.** In a `git archive` extraction of HEAD, the gate admits the role. With only the recipe file converted to CRLF, it exits `2` with `invocation-recipe: malformed row`.
  - check: rc=0; export LC_ALL=C; ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" CODEX_HOME="$T/ch" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID CLAUDE_CONFIG_DIR GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || exit 1; for b in claude codex; do printf '#!/usr/bin/env bash\nexit 0\n' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; export PATH="$T/s:$PATH"; tmo(){ local d="$1" o="$2" e="$3" s="$4" p w r; shift 4; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep "$s"; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; H=$(git rev-parse HEAD) || exit 1; git show HEAD:.gitattributes > "$T/ga" || exit 1; for l in '* text=auto eol=lf' 'bin/** text eol=lf' 'templates/** text eol=lf' 'agents/** text eol=lf' 'skills/** text eol=lf' 'tests/** text eol=lf' 'tests/check-handoff/fixtures/valid-crlf.md -text' '*.png binary' 'tests/derive-populations/fixtures/control-char.txt -text'; do grep -qxF -- "$l" "$T/ga" || rc=1; done; awk -v a='tests/** text eol=lf' -v b='tests/check-handoff/fixtures/valid-crlf.md -text' '$0 == a { x = NR } $0 == b { y = NR } END { exit !(x && y && y > x) }' "$T/ga" || rc=1; crl(){ git -C "$1" ls-files --eol > "$T/eol" || return 1; test -s "$T/eol" || return 1; awk -F '\t' '{ split($1, a, " "); if (a[2] == "w/crlf") print $2 }' "$T/eol"; }; V=tests/check-handoff/fixtures/valid-crlf.md; C1="$T/c1"; git clone -q -n -c core.autocrlf=true "$R" "$C1" && git -C "$C1" checkout -q --detach "$H" || exit 1; test "$(git -C "$C1" config core.autocrlf)" = true || rc=1; test "$(crl "$C1")" = "$V" || rc=1; awk -F '\t' '$2 ~ /^(bin|templates|agents|skills)\// { n++; split($1, a, " "); if (a[2] != "w/lf") bad = 1 } END { exit (bad || n == 0) }' "$T/eol" || rc=1; for p in "$V" tests/derive-populations/fixtures/control-char.txt docs/images/i-just-want-less-work-header.png docs/images/shell-team-concept.png; do git -C "$C1" cat-file blob "HEAD:$p" > "$T/blob" || rc=1; cmp -s "$T/blob" "$C1/$p" || rc=1; done; grep -q $'\r' "$C1/$V" || rc=1; tmo "$C1" "$T/o1" "$T/e1" 120 bash bin/check-invocation-path.sh --role engineer; test "$?" = 0 || rc=1; grep -qxF 'admitted engineer claude-cli in-process' "$T/o1" || rc=1; C2="$T/c2"; git clone -q -n -c core.autocrlf=false "$R" "$C2" && git -C "$C2" checkout -q --detach "$H" || exit 1; test "$(crl "$C2")" = "$V" || rc=1; CB="$T/cb"; git clone -q -n -c core.autocrlf=true "$R" "$CB" && git -C "$CB" checkout -q --detach "$B" || exit 1; crl "$CB" > "$T/cbl"; grep -qxF 'templates/prompt-blocks/alternate-executor-invocation.md' "$T/cbl" || rc=1; test "$(wc -l < "$T/cbl" | tr -d ' ')" -gt 1 || rc=1; X="$T/x"; mkdir -p "$X" && git archive --format=tar "$H" > "$T/x.tar" && tar -x -f "$T/x.tar" -C "$X" || exit 1; tmo "$X" "$T/o2" "$T/e2" 120 bash bin/check-invocation-path.sh --role engineer; test "$?" = 0 || rc=1; F="$X/templates/prompt-blocks/alternate-executor-invocation.md"; awk '{ printf "%s\r\n", $0 }' "$F" > "$F.t" && mv "$F.t" "$F" || exit 1; tmo "$X" "$T/o3" "$T/e3" 120 bash bin/check-invocation-path.sh --role engineer; test "$?" = 2 || rc=1; cat "$T/o3" "$T/e3" | grep -qF 'invocation-recipe: malformed row' || rc=1; test "$rc" -eq 0

- [ ] **AC2** (D1; N1.) Adding the attributes changes no tracked byte.
  - **No-op renormalization.** In a plain scratch clone of HEAD, `git add --renormalize .` leaves `git status --porcelain` empty.
  - **Positive control.** In a second clone whose `.gitattributes` lacks the `valid-crlf.md -text` line, the same command stages a change to `tests/check-handoff/fixtures/valid-crlf.md`.
  - check: rc=0; export LC_ALL=C; ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; mkdir -p "$HOME" || exit 1; H=$(git rev-parse HEAD) || exit 1; C3="$T/c3"; git clone -q -n "$R" "$C3" && git -C "$C3" checkout -q --detach "$H" || exit 1; git -C "$C3" add --renormalize . || rc=1; git -C "$C3" status --porcelain > "$T/st" || rc=1; test ! -s "$T/st" || rc=1; C4="$T/c4"; git clone -q -n "$R" "$C4" && git -C "$C4" checkout -q --detach "$H" || exit 1; grep -vxF 'tests/check-handoff/fixtures/valid-crlf.md -text' "$C4/.gitattributes" > "$T/ga" || rc=1; cp "$T/ga" "$C4/.gitattributes" || exit 1; git -C "$C4" add --renormalize . || rc=1; git -C "$C4" status --porcelain > "$T/st4" || rc=1; grep -qF 'tests/check-handoff/fixtures/valid-crlf.md' "$T/st4" || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D2; N2.) The CRLF note.
  - **Setup.** A copy of the plugin (`bin templates agents .claude-plugin`) under `$TMPDIR` sets up a fixture repository on the Claude Code host. Every `check-setup.sh` run uses the copy and points `TMPDIR` at one empty directory.
  - **LF.** The run exits `0` with no `- note:` line containing `CRLF`.
  - **Recipe file CRLF.** The run exits `0`. Exactly one CRLF note appears, and it names `templates/prompt-blocks/alternate-executor-invocation.md`.
  - **All four declaration files CRLF.** The run exits `0` with exactly four CRLF notes, one naming each file. Each of those notes contains `git clone -c core.autocrlf=false` and `marketplace remove`. Neither stream contains `--global`.
  - **Fail closed.** With `templates/adapters/codex-cli.txt` unreadable, the run exits `2`; as a precondition, `cat` must fail on the file. With `templates/binding-default.conf` moved away, the run exits `2`. With both restored, it exits `0` again.
  - **Nothing written.** The directory given as `TMPDIR` is still empty.
  - **Help and source.** `--help` exits `0` and names `CRLF`. `bin/check-setup.sh` contains no `<<<` and no `--global`. Its count of lines containing `<<` equals the base blob's count.
  - check: rc=0; export LC_ALL=C; ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" CODEX_HOME="$T/ch" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID CLAUDE_CONFIG_DIR GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; mkdir -p "$HOME" "$CODEX_HOME" "$T/s" "$T/tmpd" || exit 1; for b in claude codex; do printf '#!/usr/bin/env bash\nexit 0\n' > "$T/s/$b" && chmod +x "$T/s/$b" || exit 1; done; export PATH="$T/s:$PATH"; tmo(){ local d="$1" o="$2" e="$3" s="$4" p w r; shift 4; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep "$s"; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; grep -nE 'rm -[a-zA-Z]*[rR]|rm --recursive|find .*-delete' "$R/bin/check-setup.sh" > /dev/null; test "$?" = 1 || exit 1; mk(){ mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }; P="$T/p"; mkdir -p "$P" && cp -R "$R/bin" "$R/templates" "$R/agents" "$R/.claude-plugin" "$P/" || exit 1; K="$P/bin/check-setup.sh"; test -s "$K" || exit 1; F="$T/f"; mk "$F" || exit 1; tmo "$F" "$T/so" "$T/se" 120 bash "$P/bin/team-setup.sh" --host claude-code; test "$?" = 0 || exit 1; run(){ tmo "$F" "$T/o" "$T/e" 120 env TMPDIR="$T/tmpd" bash "$K" --host claude-code; }; cv(){ awk '{ printf "%s\r\n", $0 }' "$P/$1" > "$P/$1.t" && mv "$P/$1.t" "$P/$1" && grep -q $'\r' "$P/$1"; }; run; test "$?" = 0 || rc=1; test "$(grep -c '^- note: .*CRLF' "$T/o")" = 0 || rc=1; D1=templates/prompt-blocks/alternate-executor-invocation.md; cv "$D1" || exit 1; run; test "$?" = 0 || rc=1; grep '^- note: .*CRLF' "$T/o" > "$T/nl"; test "$(wc -l < "$T/nl" | tr -d ' ')" = 1 || rc=1; grep -qF -- "$D1" "$T/nl" || rc=1; for d in templates/adapters/claude-cli.txt templates/adapters/codex-cli.txt templates/binding-default.conf; do cv "$d" || exit 1; done; run; test "$?" = 0 || rc=1; grep '^- note: .*CRLF' "$T/o" > "$T/nl"; test "$(wc -l < "$T/nl" | tr -d ' ')" = 4 || rc=1; for d in "$D1" templates/adapters/claude-cli.txt templates/adapters/codex-cli.txt templates/binding-default.conf; do grep -F -- "$d" "$T/nl" | grep -qF 'git clone -c core.autocrlf=false' || rc=1; grep -F -- "$d" "$T/nl" | grep -qF 'marketplace remove' || rc=1; done; grep -qF -- '--global' "$T/o" "$T/e"; test "$?" = 1 || rc=1; U="$P/templates/adapters/codex-cli.txt"; chmod 000 "$U" || exit 1; if cat "$U" > /dev/null 2>&1; then rc=1; fi; run; test "$?" = 2 || rc=1; chmod 644 "$U" || exit 1; mv "$P/templates/binding-default.conf" "$T/bdc" || exit 1; run; test "$?" = 2 || rc=1; mv "$T/bdc" "$P/templates/binding-default.conf" || exit 1; run; test "$?" = 0 || rc=1; test -z "$(find "$T/tmpd" -mindepth 1 -print)" || rc=1; tmo "$T" "$T/h" "$T/he" 120 bash "$R/bin/check-setup.sh" --help; test "$?" = 0 || rc=1; grep -qF 'CRLF' "$T/h" || rc=1; grep -qF -- '<<<' "$R/bin/check-setup.sh"; test "$?" = 1 || rc=1; grep -qF -- '--global' "$R/bin/check-setup.sh"; test "$?" = 1 || rc=1; git show "$B:bin/check-setup.sh" > "$T/base.sh" || exit 1; nb=$(grep -c '<<' "$T/base.sh"); nh=$(grep -c '<<' "$R/bin/check-setup.sh"); test -n "$nb" && test "$nb" = "$nh" || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D3.) The suite.
  - **Scan.** The HEAD suite and checker, and the base suite and checker in a scratch clone checked out at `B`, are each scanned before they run.
  - **Base run.** The base suite exits `0` in its clone. This is a precondition, not a pass.
  - **HEAD run.** The HEAD suite exits `0`, and no line of its output begins `FAIL`.
  - **Labels survive.** Every distinct `PASS:` line of the base run appears in the HEAD run.
  - **New labels.** Each of the three D3 labels is in `tests/check-setup/run.sh`, and the HEAD output has the line `PASS: <label>` for it.
  - check: rc=0; export LC_ALL=C; ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac4.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; tmo(){ local d="$1" o="$2" e="$3" s="$4" p w r; shift 4; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep "$s"; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; CB="$T/cb"; git clone -q -n "$R" "$CB" && git -C "$CB" checkout -q --detach "$B" || exit 1; for f in "$R/tests/check-setup/run.sh" "$R/bin/check-setup.sh" "$CB/tests/check-setup/run.sh" "$CB/bin/check-setup.sh"; do test -s "$f" || exit 1; grep -nE 'rm -[a-zA-Z]*[rR]|rm --recursive|find .*-delete' "$f" > /dev/null; test "$?" = 1 || exit 1; done; tmo "$CB" "$T/ob" "$T/eb" 1200 bash tests/check-setup/run.sh; test "$?" = 0 || exit 1; tmo "$R" "$T/oh" "$T/eh" 1200 bash tests/check-setup/run.sh; test "$?" = 0 || rc=1; cat "$T/oh" "$T/eh" | grep -q '^FAIL'; test "$?" = 1 || rc=1; grep '^PASS: ' "$T/ob" | sort -u > "$T/pb"; grep '^PASS: ' "$T/oh" | sort -u > "$T/ph"; test -s "$T/pb" || rc=1; test -z "$(comm -23 "$T/pb" "$T/ph")" || rc=1; for l in 'crlf: declaration files with CRLF line endings get one note each and exit 0' 'crlf: LF declaration files get no CRLF note and exit 0' 'crlf: an unreadable declaration file exits 2'; do grep -qF -- "$l" "$R/tests/check-setup/run.sh" || rc=1; grep -qxF -- "PASS: $l" "$T/oh" || rc=1; done; test "$rc" -eq 0

- [ ] **AC5** (D4.) The adopting guide, EN and JA.
  - **Anchors.** In each file's HEAD blob, the Step 0 anchor and the next-paragraph anchor each occur exactly once.
  - **Placement.** The first line containing `core.autocrlf` lies strictly between the two anchors, and no heading line lies between them.
  - **Content.** The text from the first anchor to the second contains `core.autocrlf`, `.gitattributes`, `CRLF`, `git clone -c core.autocrlf=false`, `plugin marketplace remove`, `plugin marketplace update`, `2.9.1` and `- note:`.
  - **Pure addition.** `git diff --numstat B...HEAD` for the file is one row with `0` deleted.
  - **No global setting.** No added line contains `--global`.
  - adopter-surface: docs/adopting.md and docs/adopting.ja.md, `## How to run` (`## 実行方法`), naming both re-clone remedies and that `/plugin marketplace update` alone does not fix an existing CRLF checkout, the paragraph right after the Step 0 check-setup paragraph; the `- note:` line printed by `bin/check-setup.sh` itself, which the run relays at Step 0.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac5.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; for f in docs/adopting.md docs/adopting.ja.md; do case "$f" in *.ja.md) A='**最初の dispatch の前に、run は setup が揃っていることを確認します。**'; N='**ループはセッションの root にある repository に対して動きます。**' ;; *) A='**Before the first dispatch, the run checks that setup is in place.**'; N='**The loop operates on the repository your session is rooted in.**' ;; esac; git show "HEAD:$f" > "$T/f" || exit 1; test "$(grep -cF -- "$A" "$T/f")" = 1 || rc=1; test "$(grep -cF -- "$N" "$T/f")" = 1 || rc=1; a=$(grep -nF -- "$A" "$T/f" | head -n 1 | cut -d: -f1); n=$(grep -nF -- "$N" "$T/f" | head -n 1 | cut -d: -f1); k=$(grep -nF 'core.autocrlf' "$T/f" | head -n 1 | cut -d: -f1); if test -n "$a" && test -n "$n" && test -n "$k" && test "$a" -lt "$k" && test "$k" -lt "$n"; then :; else rc=1; continue; fi; awk -v a="$a" -v n="$n" 'NR > a && NR < n && /^#/ { bad = 1 } END { exit bad }' "$T/f" || rc=1; sed -n "${a},${n}p" "$T/f" > "$T/sec"; for t in 'core.autocrlf' '.gitattributes' 'CRLF' 'git clone -c core.autocrlf=false' 'plugin marketplace remove' 'plugin marketplace update' '2.9.1' '- note:'; do grep -qF -- "$t" "$T/sec" || rc=1; done; git diff --no-renames --numstat "$B"...HEAD -- "$f" > "$T/ns" || rc=1; awk '{ n++; if ($1 == "-" || $1 + 0 == 0 || $2 + 0 != 0) bad = 1 } END { exit (bad || n != 1) }' "$T/ns" || rc=1; git diff --no-renames -U0 "$B"...HEAD -- "$f" > "$T/d" || rc=1; grep '^+' "$T/d" | grep -v '^+++' | grep -qF -- '--global'; test "$?" = 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC6** (D5.) Scope lock. The measured set is the union of the committed range `B...HEAD`, the staged delta, the unstaged delta (each read `--no-renames`) and the untracked strays.
  - **Allowed paths.** Every path in the set is `.gitattributes`, `bin/check-setup.sh`, `tests/check-setup/run.sh`, `docs/adopting.md`, `docs/adopting.ja.md`, or a path under `.shell-team/`.
  - **Required paths.** The committed range contains each of the five named files.
  - **Staleness.** This criterion is merge-point-scoped and expected to go stale after merge; it is not merge-ranged.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac6.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; git diff --no-renames --name-only "$B"...HEAD > "$T/r" || exit 1; git diff --no-renames --cached --name-only > "$T/c" || exit 1; git diff --no-renames --name-only > "$T/w" || exit 1; git ls-files --others --exclude-standard > "$T/u" || exit 1; sort -u "$T/r" "$T/c" "$T/w" "$T/u" > "$T/all"; test -s "$T/all" || rc=1; grep -vxE '\.gitattributes|bin/check-setup\.sh|tests/check-setup/run\.sh|docs/adopting\.md|docs/adopting\.ja\.md|\.shell-team/.+' "$T/all" > "$T/out"; test "$?" = 1 || rc=1; for f in .gitattributes bin/check-setup.sh tests/check-setup/run.sh docs/adopting.md docs/adopting.ja.md; do grep -qxF -- "$f" "$T/r" || rc=1; done; test "$rc" -eq 0

- [ ] **AC7** (D2, D3.) shellcheck is clean on the changed scripts.
  - check: shellcheck bin/check-setup.sh tests/check-setup/run.sh

- [ ] **AC8** CI is green on the pull request, including the `check-handoff lint` check run, the check-setup fixture suite step and the check-invocation-path dogfood step.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

- [ ] **AC9** (D3; the second droppable component.) Mutation positive control for the suite.
  - **The mutation.** In a scratch clone of HEAD, `bin/check-setup.sh` is moved aside and replaced by a wrapper. The wrapper runs the moved script and filters out every `- note:` line containing `CRLF`, keeping the exit status. The suite is scanned before it runs.
  - **Required result.** The mutated suite exits non-zero, and its stderr has a line beginning `FAIL: crlf: declaration files with CRLF line endings get one note each and exit 0`.
  - **Record.** `.shell-team/test-recipe.md` has a line naming `T-1186` that records the mutation.
  - check: rc=0; export LC_ALL=C; ulimit -f 400000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1186-ac9.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_THREAD_ID GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; tmo(){ local d="$1" o="$2" e="$3" s="$4" p w r; shift 4; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep "$s"; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; H=$(git rev-parse HEAD) || exit 1; CM="$T/cm"; git clone -q -n "$R" "$CM" && git -C "$CM" checkout -q --detach "$H" || exit 1; for f in "$CM/tests/check-setup/run.sh" "$CM/bin/check-setup.sh"; do test -s "$f" || exit 1; grep -nE 'rm -[a-zA-Z]*[rR]|rm --recursive|find .*-delete' "$f" > /dev/null; test "$?" = 1 || exit 1; done; mv "$CM/bin/check-setup.sh" "$CM/bin/check-setup.real" || exit 1; printf '%s\n' '#!/usr/bin/env bash' 's="${BASH_SOURCE[0]}"; while [ -L "$s" ]; do s="$(readlink "$s")"; done' 'd="$(cd "$(dirname "$s")" && pwd -P)"' 'bash "$d/check-setup.real" "$@" | grep -v "^- note: .*CRLF"' 'exit "${PIPESTATUS[0]}"' > "$CM/bin/check-setup.sh" && chmod +x "$CM/bin/check-setup.sh" || exit 1; tmo "$CM" "$T/om" "$T/em" 1200 bash tests/check-setup/run.sh; test "$?" = 0 && rc=1; grep -q '^FAIL: crlf: declaration files with CRLF line endings get one note each and exit 0' "$T/em" || rc=1; grep -F 'T-1186' "$R/.shell-team/test-recipe.md" > /dev/null || rc=1; test "$rc" -eq 0

## Input space

- **Reachable input classes.**
  1. A plugin checkout cloned with `core.autocrlf=true` (the usual Git for Windows setup) at a version with no `.gitattributes`. Every text file is CRLF in the working tree and LF in the index.
  2. A clone made at HEAD or later, with `core.autocrlf` set to `true`, `false` or `input`, or unset.
  3. A checkout cloned CRLF before this release and then moved to a version that ships `.gitattributes`. Files that changed between the two versions are rewritten LF. Unchanged files stay CRLF, so the tree is mixed, and some declaration files may be CRLF while others are LF.
  4. An LF tree on macOS or Linux, the common case. It gets no note.
  5. A plugin root in which a declaration file is missing or unreadable.
- **Reachable but not protected by this task.**
  - CRLF in the adopter repository's own files (board, specs, loop contract). This is deferred (see Non-goals).
  - `bin/*.sh` themselves CRLF under a bash that rejects a carriage return. The checker cannot run at all to report it.
- **Out-of-scope synthetic extremes.**
  - Lone-CR (classic Mac) line endings.
  - A declaration file that is CRLF on only some lines. The note fires on any carriage-return byte and does not grade it.
  - UTF-16 or BOM-prefixed declaration files.
  - Plugin roots assembled by an archiver that converts line endings itself.
  - A process running as root, for which `chmod 000` does not make a file unreadable. **AC3**'s precondition fails closed rather than passing there.

<!-- END intent-block: T-1186 -->

## Directive-to-criterion correspondence

| # | Body directive | Criterion |
|---|---|---|
| 1 | `.gitattributes` with the D1 lines, `valid-crlf.md -text` after `tests/**` | **AC1** |
| 2 | A clone is LF whatever `core.autocrlf` says; the gate admits | **AC1** |
| 3 | Deliberate non-LF fixtures and binaries stay byte-identical | **AC1**, **AC2** |
| 4 | Adding the attributes changes no tracked blob | **AC2** |
| 5 | One `- note:` per CRLF declaration file, naming the file and both re-clone remedies (marketplace remove/add, `git clone -c core.autocrlf=false`) | **AC3** |
| 6 | The note never changes the exit code | **AC3** |
| 7 | Missing or unreadable declaration file → exit 2 | **AC3** |
| 8 | No here-string, nothing written, `$TMPDIR` untouched | **AC3**, **AC4** |
| 9 | `--help` names the CRLF note | **AC3** |
| 10 | No `--global` in script, output or added docs lines | **AC3**, **AC5** |
| 11 | No in-place re-checkout command | **AC3**, **AC5** (only the re-clone remedies are required); info-only for the absence: a negative grep for every possible in-place spelling is not a finite set |
| 11a | Docs say `/plugin marketplace update` alone does not fix an existing CRLF checkout | **AC5** (`plugin marketplace update` token in the paragraph) |
| 12 | Three suite cases with the fixed labels; base labels survive | **AC4** |
| 13 | Mutation positive control and test-recipe line | **AC9** |
| 14 | Docs paragraph, EN and JA, placed after the Step 0 paragraph, pure addition | **AC5** |
| 15 | No reader, `team-setup.sh`, grammar or workflow change; no release files | **AC6** |
| 16 | shellcheck clean | **AC7** |
| 17 | CI green | **AC8** |
| 18 | No adopter-repository CRLF handling | info-only (not promoted to AC): a deferred class with no surface in this diff, guarded indirectly by **AC6** |
| 19 | Pre-commitment and drop order | info-only (not promoted to AC): a disposition, not a deliverable property |
| 20 | No sweep, no local run of past specs' check lines | info-only (not promoted to AC): a process exclusion with no observable trace in the diff |

## Assumptions

Each item gives its source and who re-measures it. Items labelled **relayed** came from the coordinating session at planning and have not been measured by this role.

- **The branch base is `f5b0569b` (v2.9.0) on `develop`, with no open predecessor PR.** **Relayed** (planning brief and session git status). The freeze run measures `git merge-base develop HEAD`.
- **The only tracked file with a carriage return in the index is `tests/check-handoff/fixtures/valid-crlf.md`; the binaries are the two PNGs and `control-char.txt`.** **Relayed** (`git ls-files --eol` on HEAD at planning). A borrowed count premise. The freeze run re-measures it with `git ls-files --eol | awk '$1 != "i/lf" && $1 != "i/none"'` at `B`. **AC1** and **AC2** depend on it.
- **No `.gitattributes` exists at `B`.** Measured by this role with the Glob tool on the working tree at authoring. The freeze run confirms it with `git cat-file -e "$B:.gitattributes"` failing.
- **`check-invocation-path.sh --role engineer` prints `admitted engineer claude-cli in-process` in an LF archive extraction and in a clone, with a temp `HOME` and stub CLIs.** **Relayed** for the archive extraction. The clone case and the temp environment are unmeasured. The engineer runs **AC1** before implementing. If the environment changes the line, that is a broken check line, repaired as class-M.
- **With only the recipe file CRLF and `bin/` LF, the gate exits 2 with `invocation-recipe: malformed row`.** **Relayed** (macOS reproduction at planning). The engineer re-measures it through **AC1**'s reproduction clause.
- **CRLF `bin/*.sh` make bash on macOS die at `set -euo pipefail`.** **Relayed**. How the reporter's Git Bash ran CRLF scripts is unverified, and this spec asserts neither way.
- **Updating an existing CRLF checkout does not rewrite unchanged files.** Measured by the coordinating session at the freeze sweep. The test was a `core.autocrlf=true` clone of the base (v2.9.0), moved by fetch and checkout to a commit that adds `.gitattributes`. Unchanged files stayed `w/crlf` and only gained `attr/text eol=lf`. A following `git checkout -- .` left them `w/crlf`. A new clone was `w/lf`. So `/plugin marketplace update` does not fix an existing Windows install, and only a new clone does.
- **The Claude Code plugin manager installs by git clone followed by a byte-identical copy.** Measured by the coordinating session at the freeze sweep, on macOS with Claude Code 2.1.x. The marketplace is held as a git clone whose origin is GitHub. The plugin cache is a copy of that working tree with no `.git`, and `cmp` shows the two are identical. So `.gitattributes` applies to a new plugin install exactly as it does to a manual clone. `claude plugin marketplace remove <name>` exists (`--help`). The internals of the Codex CLI's `codex plugin marketplace` were not measured, and this spec asserts nothing about them.
- **This task ships as v2.9.1.** **Relayed** (planning). The docs paragraph names `2.9.1`. If the release number changes, the paragraph and **AC5** change with it (class-B).
- **The run skill relays a `- note:` line on exit 0** (`skills/run/SKILL.md` line 22, read by this role). So the note reaches the operator before the run stops at Step 1.
- **Borrowed tokens.** `core.autocrlf` occurs in neither `docs/adopting.md` nor `docs/adopting.ja.md` at `B` (measured by this role with the Grep tool on the working tree; the freeze run confirms with `git show "$B:docs/adopting.md" | grep -c core.autocrlf` and the same for `.ja.md`, expected `0`). `CRLF` does not occur in `bin/check-setup.sh` at `B` (Grep tool; confirm with `git show "$B:bin/check-setup.sh" | grep -c CRLF`, expected `0`).

## Open questions

- None blocking.
- Follow-up, not this task: CRLF in the adopter repository's own records on the same hosts. The coordinating session may file an issue for it.

## Notes for engineer

- **Files.**
  - `.gitattributes` (new).
  - `bin/check-setup.sh`: a detection step beside the template-drift step, plus the help text and the header comment item list.
  - `tests/check-setup/run.sh`: three cases on a plugin copy, the same pattern as the read-only lock at lines 205–223. Run them through the suite's `ck` so `$T/tmpd` stays empty.
  - `docs/adopting.md` and `docs/adopting.ja.md`.
  - `.shell-team/test-recipe.md`: one line for **AC9**'s mutation.
  - `.shell-team/provenance/T-1186.md`.
- **Detection.** It must distinguish "no carriage return" from "unreadable". `grep -q` with a pattern of `$'\r'` exits 1 for none and 2 for an error, so take the status explicitly instead of letting `set -e` or `|| true` swallow it. Check readability or existence first if that is clearer. Do not use a here-string. Keep `LC_ALL=C`, which is already exported.
- **Note text.** It must contain `CRLF`, the file's path (relative to the plugin root or absolute), `marketplace remove` (the plugin-manager remedy: `/plugin marketplace remove ripsawjp` then `/plugin marketplace add RipsawJP/shell-team`) and `git clone -c core.autocrlf=false` (the manual-clone remedy). It may say that the run will stop at Step 1 and that a clone made from v2.9.1 on is LF. The header says the script "never chooses, asks for or suggests a grant, a permission or a host setting". A clone-time `-c` option is scoped to that clone, so it is not a host setting. Say so in the header comment if you touch it.
- **The suite's forbidden-token list (line 278).** Leave it alone. Adding `core.autocrlf` would contradict the note.
- **CI.** It already runs shellcheck and the suite for these two files (workflow lines 41 and 408–409), and dogfoods `check-invocation-path.sh --role tech-lead` from the repository's own checkout (line 332). On the Ubuntu runner that checkout is LF anyway. **AC1** is the evidence for the CRLF case.
- **No recursive deletion** anywhere: commands, tests, fixtures. Scratch files stay under `$TMPDIR`. If cleanup seems necessary, stop and report `BLOCKED`.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a `measured at <ref>` label.
- **Downstream impact.** The `.gitattributes` affects how every clone writes text files. On an LF host (CI, macOS, Linux) checkouts are byte-identical to before, and **AC2** shows no tracked blob changes. So no merged spec's criterion that reads committed or checked-out bytes changes verdict on these hosts. This is disclosed rather than measured by a full-population sweep (operator ruling, Non-goals).
