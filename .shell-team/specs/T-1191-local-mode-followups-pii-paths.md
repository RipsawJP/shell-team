# check-pii-shapes --paths hardening: a known-shape path prints a skip notice, a trailing slash on a non-directory is refused, and a failed scratch write exits 2

**Status**: READY_FOR_ENG
**Owner**: pm-spec
**Task ID**: T-1191

## Problem

T-1182 added `bin/check-pii-shapes.sh --paths`, the mode the four record-writing roles use for the hand-off shape scan in `local` record mode. Its cross-provider review left four minor findings, filed as #716. This task covers items 1–3; item 4 (docs `rc=n/a` wording) is not in scope. The three items are:

1. A path named with `--paths` that is on the known-shape fixture list is skipped silently. `--paths <known-shape file> clean.txt` therefore reports clean, because the clean file satisfies the read counter.
2. Trailing slashes are stripped before resolving, so `--paths file.txt/` scans the regular file instead of refusing a path that names a directory.
3. Several writes into the checker's own scratch files are unguarded. A failed write ends the run through `set -e` with exit 1 and no `FINDING` line, which is neither the documented exit 2 nor a finding. In the two pattern-scan helpers and the binary detector, a failed write is swallowed outright, and the run can end in a clean exit 0.

## Summarized sources

- Issue #716 body (supplied by the coordinating session as a scratchpad file; read in full). Items 1–3 as listed above. The issue's Expected section says "Items 1–3 land as changes to the `--paths` branch only, with the existing modes still byte-identical to the base on the `tests/check-pii-shapes` fixtures and new suite cases for each". Item 3 itself names the `--all` list write ("in one change for both modes"). This spec keeps that distinction: the success paths of the existing modes stay byte-identical, and the only changes reaching `--all` and diff mode are on write-failure paths. Restated by the Goal sentence, D1–D3, N1, **AC1**–**AC7**.
- `bin/check-pii-shapes.sh` at `01be9002` (read in full over the cited ranges):
  - `:239-256` header. Exit codes are `0` clean, `1` findings, `2` usage or structural error, with a list of causes that names no write failure. The `--paths` paragraph follows. `--help` prints the header (`:295-311`).
  - `:260-265`: `die`, `fail_usage` and `fail_structural`. Each prints `check-pii-shapes: <class>: <message>` to stderr and exits 2.
  - `:327-338`: `--paths` parsing. An empty argument or one beginning with `-` is a usage error.
  - `:646-659`: `KNOWN_SHAPE_PATHS` (four per-file entries under `tests/rollup-track/fixtures/`) and `is_known_shape`.
  - `:661-662`: guarded `mktemp -d` (message `failed to create a scratch directory under mktemp`, the only existing message containing `scratch`).
  - `:674`: `: > "$FINDINGS_FILE"`, unguarded, reached by every mode.
  - `:679`: `is_binary_file`. `tr … > "$WORKDIR/stripped" 2>/dev/null || return 1`, so a failed write reads as "not binary".
  - `:692` and `:707`: `grep … > "$WORKDIR/matches"` / `> "$WORKDIR/emails"`, each followed by `2>/dev/null || true`. Every grep error, a failed write included, is swallowed.
  - `:695` and `:720`: `printf 'FINDING …' >> "$FINDINGS_FILE"`, unguarded.
  - `:746-748`: `announce_skip`, `check-pii-shapes: skip: binary %s (NUL byte present), not scanned: %s`. `:777` and `:954` carry the gitlink `skip:` notice.
  - `--all` branch: `:759` truncates `FILELIST`; `:780` and `:790` append to it; `:795` skips known-shape paths silently; `:803` writes the symlink target into `CONTENT_FILE`. All four writes are unguarded. `:769` and `:787` (the `git ls-files` outputs) are guarded.
  - `--paths` branch:
    - `:831` truncates `PFILELIST` (unguarded).
    - `:837` strips trailing slashes. `:839-848` resolve the leaf without following it, `:850-852` test existence and `:853-856` test containment.
    - `:860-861` is the guarded `find >> "$PFILELIST"` ("unreadable entry"). `:863` is the unguarded `printf '%s\0' "$abs" >> "$PFILELIST"`.
    - `:871` skips known-shape paths silently. `:876` writes the symlink target, unguarded.
    - `:894-895`: a run that read no regular text file is exit 2.
  - Diff mode: `:936` and `:957` write `CHANGED_PATHS`, unguarded. `:963` skips known-shape paths silently.
  - `:983-989`: findings are printed and the run exits 1; otherwise the clean line is printed and the run exits 0.

  Restated by the Goal sentence, D1–D3, Non-goals, **AC1**–**AC5**, **AC8**, Input space.
- `docs/pii-controls.md` `## Running it` (`:70-115`). `:86-90` is the exit-code paragraph, whose `2` causes name no write failure. `:100-114` is the `--paths` paragraph: it says nothing of known-shape paths, a trailing slash or a write failure. `docs/pii-controls.ja.md` `## 実行方法` (`:64-108`) is the counterpart, with exit codes at `:80-82` and the `--paths` paragraph at `:94-107`. Restated by D4, **AC9**.
- `docs/adopting.md:116` and `:1009`, `docs/adopting.ja.md:120` and `:1003`, `docs/migrating-to-local-mode.md:15` and `docs/migrating-to-local-mode.ja.md:15` name `--paths`. They state its purpose (it reads ignored records), `adopting.md:1009` adds "an exit status of `2` is a scan that did not complete", and none lists exit-2 causes, the known-shape list or slash handling. Restated by the Non-goals docs line.
- `templates/prompt-blocks/record-shape-scan.md:4`: exit `2` is a scan that did not complete, never an absence of findings. It does not enumerate causes, so no prompt edit is needed. Restated by N3, **AC10**.
- `tests/check-pii-shapes/run.sh` at `01be9002`:
  - `:61` `set -euo pipefail`; `:65` `BIN="$REPO_ROOT/bin/check-pii-shapes.sh"` (no override); `:68-69` the `pass`/`fail` helpers.
  - `:1504-1537` known-shapes list assertions.
  - `:1945-2127` the T-1182 `--paths` block, with `pr()` at `:1959-1965`; `:2129-2137` the trailer.
  - The recursive-deletion pattern matches neither the suite nor the checker.

  Restated by D5, **AC6**, **AC7**.
- `.shell-team/specs/T-1182-local-mode-shape-scan.md`: D2 and **AC4** compare exit status, stdout and stderr of the base commit's script (from `git show`, run from `$TMPDIR`) and HEAD on one fixture, excluding `--help`. `tmo`/`tms` are the run helpers. This spec's **AC5** reuses that shape. Restated by N1, **AC5**.
- `.github/workflows/check-handoff.yml:271-275`: the fixture suite and the diff-scoped scan of the pull request run in CI. Restated by **AC15**.

## Goal

<!-- BEGIN intent-block: T-1191 -->

- user-visible: yes — an adopter running `bin/check-pii-shapes.sh --paths` sees three changes. A new stderr notice names a skipped known-shape path. A path written with a trailing slash that is not a directory is now refused with exit 2 instead of scanned. A failed write into the checker's own scratch files now exits 2 with a structural message instead of exiting 1 with no finding or 0 with a clean line.
- shipped-docs: docs/pii-controls.md — this-task
- shipped-docs: docs/pii-controls.ja.md — this-task
- verification-class: mechanism — the diff changes `bin/check-pii-shapes.sh` and its fixture suite, the executing surfaces of a shipped checker.
- verification-ceiling: unit-and-static — **AC1**–**AC14** are settled in a plain checkout. They run the checker on temp repositories under `$TMPDIR`, compare it with the base commit's committed blob, run the fixture suite and the bin-help suite, and read the exit codes of shellcheck, `check-prompt-sync.sh`, `check-adopter-docs.sh` and `check-handoff.sh`. **AC15**, the CI run on the pull request (Linux, the second platform for the size-limit fixtures), sits above the ceiling.
- base-ref-discriminator: P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1;

**Goal (one sentence).** `bin/check-pii-shapes.sh --paths` prints a `skip:` notice for every known-shape path it meets without counting it as read. It exits `2` for an argument written with a trailing slash that does not name a real directory. It exits `2` with a structural message when a write into its own scratch files fails at any of the eleven in-scope sites. Every existing success path and every existing message of the default mode, `--base` and `--all` stays byte-identical with the base, and the change is documented in `docs/pii-controls.md`, its Japanese counterpart and `--help`.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — item 1, known-shape notice.**
  - Every known-shape path met in `--paths`, named or met in a walk, prints exactly one stderr line: `check-pii-shapes: skip: known-shape fixture, not scanned: <repo-root-relative path>`.
  - Such a path is not counted as read, so a run whose only inputs are known-shape paths still exits `2`.
  - The notice does not reach `--all` or diff mode. (**AC1**, **AC5**)
- **D2 — item 2, trailing slash.**
  - The checker records whether each `--paths` argument ended in `/`.
  - When it did, the resolved entry must be a directory and not a symlink. Otherwise the run exits `2` with a new structural message beginning `--paths: ` and containing `trailing slash`.
  - The expected exit status of every input class is fixed by the table in **AC2**.
- **D3 — item 3, scratch writes.** Eleven sites are in scope:
  - The eight `--paths`/`--all` write sites: `:674` (shared by every mode), `:759`, `:780`, `:790`, `:803`, `:831`, `:863`, `:876`.
  - Three helper sites, `:679`, `:692` and `:707`. Read against the code, these fail the "never yields exit 0 on a write failure" test: `:692` and `:707` swallow every grep error, so a lost match list drops findings and can end clean; `:679` turns a failed write into "not binary", so a binary-only `--paths` run can end clean instead of exit 2.

  A failure at any of the eleven sites goes through `fail_structural` with a new message containing `failed to write scratch file`, so the run exits `2`. Every existing message stays byte-identical. Grep's no-match status (1) is not a failure. (**AC3**, **AC4**, **AC7**)
- **D4 — docs.** `docs/pii-controls.md`, `docs/pii-controls.ja.md` and the `--help` header document all three behaviours, in lockstep. (**AC8**, **AC9**)
- **D5 — tests.**
  - `tests/check-pii-shapes/run.sh` gains item 1, item 2 and item 3 cases.
  - The suite accepts a `CHECK_PII_SHAPES_BIN` override for the script under test.
  - Each item 3 case first proves that its fault injection bites, then asserts exit `2`. Its `FAIL` message ends with `(rc=<exit status of the faulted run>)`.
  - Every existing `pass` label survives. (**AC6**, **AC7**)

**Pre-commitment.** This is the sprint stop rule, approved by the operator at sprint planning on 2026-10-12 (relayed by the coordinating session; see Assumptions). It is an operator-approved rule, not AI self-discipline alone.

- **Never-dropped.**
  - (N1) The default mode, `--base`, `--all`, their usage errors and the tracker-key opt-in give the base copy's exit status, stdout and stderr on the same inputs. This covers success paths and the pre-existing exit-2 paths with every existing message, and excludes `--help` and the newly guarded write-failure paths. The existing T-1182 `--paths` verdicts and every existing suite `pass` label survive, except the deliberately changed behaviour. (**AC5**, **AC6**)
  - (N2) A `--paths` run that read no regular text file exits `2` and never prints the clean line, including a run naming only known-shape paths. (**AC1**, **AC6**)
  - (N3) `check-prompt-sync.sh` stays green and no prompt block or agent file is edited. (**AC10**)

  The first defeat of any never-dropped item stops the task and returns it to planning.
- **Repeated Majors.** Two consecutive rounds, each with a recorded verdict, each raising a Major of the same class, cut T-1191 from the sprint instead of adding rounds. A round interrupted before a verdict is not counted.
- **Droppable, in order.** Each drop removes criterion text, so it is a class-B re-freeze whose ratification cites this operator-approved rule. A dropped item returns to #716 with its round findings as the requirement list.
  1. **Item 3**: D3 with **AC3**, **AC4**, **AC7**, the item 3 labels in **AC6**, and the `scratch file` / `作業ファイル` tokens in **AC8** and **AC9**. It goes first: it is not a fail-open in `--paths` itself, its fixtures are platform-dependent, and it is the only item touching an existing mode.
  2. **Item 2**: D2 with **AC2**, the item 2 label in **AC6**, and the `trailing slash` / `末尾` tokens.
  3. **Item 1**: the notice assertions in **AC1** and **AC5**, the item 1 label, and the `skip: known-shape` tokens. **AC1**'s exit-2 assertions stay, because they are N2. Item 1 is last: it is the most direct fail-open and the cheapest.

## Non-goals

- **Issue #716 item 4** (the `rc=n/a` wording in the loop sections of the PII-controls docs). Out of this task's scope; it stays on #716. (info-only)
- **Write failures that already end in exit 1, never 0.** These are `:695` and `:720` (FINDING appends, ending through `set -e`) and diff mode's `:936` and `:957`. Each turns a write failure into exit 1 with no `FINDING` line, the defect class of item 3, but none can produce exit 0. They go to a follow-up issue that the coordinating session files. (info-only; **AC13** keeps the diff from reaching them only through the scope of `bin/check-pii-shapes.sh`, so this is a disposition, not an assertion)
- **Signal death.** A write past a file-size limit with the default `SIGXFSZ` disposition kills the process (exit 153). The checker installs no `SIGXFSZ` handling and does not route that case to exit 2. (info-only; Input space out-of-scope 1)
- **A write failure on the checker's own stdout or stderr** (the clean line, notices, the structural message). These stay `|| true` as at the base. (info-only)
- **Any edit to a prompt block, an agent file, the lessons corpus, a workflow, or any doc other than the two PII-controls documents.** `docs/adopting.md` / `.ja.md` and `docs/migrating-to-local-mode.md` / `.ja.md` are deliberately not edited: their `--paths` mentions state its purpose and the meaning of exit `2`, which this task does not change. (**AC10**, **AC13**)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** Operator rulings: A2 light operation and the 2026-10-01 ruling. CI and this task's own check lines are the measurement. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`.
- **Run helpers.** Lines that run a script go through `tmo` (120 s per run) or `tms` (1200 s, for whole suites). Each starts the script in its own process group under `ulimit -f` and kills the group on timeout. Those lines export a temp `HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`.
- **Size-limit fixtures.** A limit lower than the line's own is set inside a subshell, never raised. The output of a limited run is captured through a pipe into `head -c`, because a file written from inside the limit would itself fail.
- **What lines never contain.** No line uses `ps`, `xargs` or a recursive deletion. No line compares a per-checkout value: a faulted run's stdout may carry the absolute path of a scratch entry, so no faulted run's output is compared byte for byte.
- **Fixture shapes.** A PII-shaped fixture is assembled at run time from fragments, so this spec carries no literal shape.
- **Base reads.** These use the `base-ref-discriminator` expression above, spelled byte-identically in **AC3**–**AC8**, **AC10** and **AC13**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Runtime.** **AC6** and **AC7** each run the whole fixture suite; QA runs `check-acs.sh` with `CHECK_ACS_TIMEOUT` of at least `3600`.

- [ ] **AC1** (D1; N2.) Known-shape notice in `--paths`. In a temp repository holding `tests/rollup-track/fixtures/winpath.jsonl` (with a home-path shape), `ctl.txt` (the same bytes) and a clean `clean.txt`:
  - `--paths ctl.txt` exits `1` with `FINDING pattern=home-path path=ctl.txt line=1`. This is the positive control that the bytes are a shape.
  - `--paths <that path> clean.txt` and `--paths tests clean.txt` each exit `0`. Stdout is exactly the clean line, there is no `FINDING` line, and stderr carries exactly one line equal to `check-pii-shapes: skip: known-shape fixture, not scanned: tests/rollup-track/fixtures/winpath.jsonl`.
  - `--paths <that path>` alone and `--paths tests` alone each exit `2` with that notice, and the clean line appears on neither stream (N2).
  - `--all` on the same repository prints no `skip: known-shape` text on stderr.
  - adopter-surface: docs/pii-controls.md and docs/pii-controls.ja.md (`## Running it` / `## 実行方法`, the `--paths` paragraph) and the `--help` header — the `skip: known-shape` notice and that such a path is not counted as read.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; X="$R/bin/check-pii-shapes.sh"; test -s "$X" || exit 1; C='check-pii-shapes: clean (no PII-shaped bytes found)'; mk(){ mkdir -p "$1" && git -C "$1" init -q && git -C "$1" -c user.email=t -c user.name=t commit -q --allow-empty -m base; }; H=$(printf '/%s/%s/x' Users qzname); KS=tests/rollup-track/fixtures/winpath.jsonl; N="check-pii-shapes: skip: known-shape fixture, not scanned: $KS"; A="$T/a"; mk "$A" || exit 1; mkdir -p "$A/tests/rollup-track/fixtures" || exit 1; printf '%s\n' "$H" > "$A/$KS" || exit 1; printf '%s\n' "$H" > "$A/ctl.txt" || exit 1; printf 'ok\n' > "$A/clean.txt" || exit 1; tmo "$A" "$T/o" "$T/e" bash "$X" --paths ctl.txt; test "$?" = 1 || rc=1; grep -qxF 'FINDING pattern=home-path path=ctl.txt line=1' "$T/o" || rc=1; for a in "$KS" tests; do tmo "$A" "$T/o" "$T/e" bash "$X" --paths "$a" clean.txt; test "$?" = 0 || rc=1; test "$(cat "$T/o")" = "$C" || rc=1; test "$(grep -cxF -- "$N" "$T/e")" = 1 || rc=1; tmo "$A" "$T/o" "$T/e" bash "$X" --paths "$a"; test "$?" = 2 || rc=1; grep -qF "$C" "$T/o" "$T/e"; test "$?" = 1 || rc=1; test "$(grep -cxF -- "$N" "$T/e")" = 1 || rc=1; done; tmo "$A" "$T/o" "$T/e" bash "$X" --all; grep -qF 'skip: known-shape' "$T/e"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC2** (D2.) Trailing slash. The temp repository holds clean files `ok.txt`, `f.txt`, `d/g.txt`, `sub dir/h.txt` and `my f.txt`, a symlink `lf` → `f.txt` and a symlink `ld` → `d`. Runs are from the repository root unless stated.

  | # | Input class | Invocation | Expected |
  |---|---|---|---|
  | 1 | `file/` | `--paths f.txt/ ok.txt` | `2`, new message |
  | 2 | `file//` | `--paths f.txt// ok.txt` | `2`, new message |
  | 3 | `link-to-file/` | `--paths lf/ ok.txt` | `2`, new message |
  | 4 | `link-to-dir/` | `--paths ld/ ok.txt` | `2`, new message |
  | 5 | absolute file with slash | `--paths <abs>/f.txt/ ok.txt` | `2`, new message |
  | 6 | space plus slash, file | `--paths "my f.txt/" ok.txt` | `2`, new message |
  | 7 | `missing/` | `--paths missing/ ok.txt` | `2` |
  | 8 | `file/.` | `--paths f.txt/. ok.txt` | `2` |
  | 9 | `/` | `--paths / ok.txt` | `2` |
  | 10 | `dir/` | `--paths d/` | `0`, exactly the clean line |
  | 11 | `dir//` | `--paths d//` | `0`, exactly the clean line |
  | 12 | `./` | `--paths ./` | `0`, exactly the clean line |
  | 13 | absolute dir with slash | `--paths <abs>/d/` | `0`, exactly the clean line |
  | 14 | space plus slash, dir | `--paths "sub dir/"` | `0`, exactly the clean line |
  | 15 | `../` | `--paths ../`, run from `d/` | `0`, exactly the clean line |
  | 16 | no slash (control) | `--paths f.txt` | `0`, exactly the clean line |
  | 17 | no slash, symlink (control) | `--paths lf ok.txt` | `0`, exactly the clean line |

  - "New message" means a stderr line beginning `check-pii-shapes: structural: --paths: ` that contains `trailing slash`.
  - Every row expecting `2` prints the clean line on neither stream.
  - Rows 1–6 exit `0` at the base, so the criterion is red there.
  - adopter-surface: docs/pii-controls.md and docs/pii-controls.ja.md (the `--paths` paragraph) and the `--help` header — an argument written with a trailing slash must name a real directory, and otherwise the run exits `2`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; X="$R/bin/check-pii-shapes.sh"; test -s "$X" || exit 1; C='check-pii-shapes: clean (no PII-shaped bytes found)'; mk(){ mkdir -p "$1" && git -C "$1" init -q && git -C "$1" -c user.email=t -c user.name=t commit -q --allow-empty -m base; }; A="$T/a"; mk "$A" || exit 1; mkdir -p "$A/d" "$A/sub dir" || exit 1; for f in ok.txt f.txt d/g.txt "sub dir/h.txt" "my f.txt"; do printf 'ok\n' > "$A/$f" || exit 1; done; ln -s f.txt "$A/lf" && ln -s d "$A/ld" || exit 1; rf(){ tmo "$A" "$T/o" "$T/e" bash "$X" --paths "$@"; test "$?" = 2 || return 1; grep -qF "$C" "$T/o" "$T/e"; test "$?" = 1 || return 1; grep '^check-pii-shapes: structural: --paths: ' "$T/e" | grep -qF 'trailing slash' || return 1; }; r2(){ tmo "$A" "$T/o" "$T/e" bash "$X" --paths "$@"; test "$?" = 2 || return 1; grep -qF "$C" "$T/o" "$T/e"; test "$?" = 1 || return 1; }; ok(){ local d="$1"; shift; tmo "$d" "$T/o" "$T/e" bash "$X" --paths "$@"; test "$?" = 0 || return 1; test "$(cat "$T/o")" = "$C" || return 1; }; rf f.txt/ ok.txt || rc=1; rf f.txt// ok.txt || rc=1; rf lf/ ok.txt || rc=1; rf ld/ ok.txt || rc=1; rf "$A/f.txt/" ok.txt || rc=1; rf "my f.txt/" ok.txt || rc=1; r2 missing/ ok.txt || rc=1; r2 f.txt/. ok.txt || rc=1; r2 / ok.txt || rc=1; ok "$A" d/ || rc=1; ok "$A" d// || rc=1; ok "$A" ./ || rc=1; ok "$A" "$A/d/" || rc=1; ok "$A" "sub dir/" || rc=1; ok "$A/d" ../ || rc=1; ok "$A" f.txt || rc=1; ok "$A" lf ok.txt || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D3.) Measured route for `:863`. A temp repository holds one clean `clean.txt`.
  - Precondition: the base commit's script, run as `--paths clean.txt` in a subshell that ignores `SIGXFSZ` and sets `ulimit -f 0`, exits `1`. If it does not, the line fails: the instrument is broken, and a vacuous pass is ruled out.
  - Positive control: HEAD's script, run without a limit, exits `0` with exactly the clean line.
  - HEAD's script under the same limit exits `2`. Its combined output contains `check-pii-shapes: structural: ` and `failed to write scratch file`, has no line beginning `FINDING ` and does not contain the clean line.
  - adopter-surface: docs/pii-controls.md and docs/pii-controls.ja.md (the exit-code paragraph and the `--paths` paragraph) and the `--help` header — a failed write into the checker's own scratch files is exit `2`, a scan that did not complete.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac3.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/check-pii-shapes.sh"; test -s "$X" || exit 1; git show "$B:bin/check-pii-shapes.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; C='check-pii-shapes: clean (no PII-shaped bytes found)'; A="$T/a"; mkdir -p "$A" && git -C "$A" init -q && git -C "$A" -c user.email=t -c user.name=t commit -q --allow-empty -m base || exit 1; printf 'ok\n' > "$A/clean.txt" || exit 1; lim(){ ( cd "$A" && trap '' XFSZ && ulimit -f 0 && exec bash "$1" --paths clean.txt ) < /dev/null 2>&1 | head -c 100000 > "$T/lo"; s=("${PIPESTATUS[@]}"); test "${s[1]}" = 0 || return 99; return "${s[0]}"; }; lim "$T/base.sh"; test "$?" = 1 || exit 1; tmo "$A" "$T/o" "$T/e" bash "$X" --paths clean.txt; test "$?" = 0 || rc=1; test "$(cat "$T/o")" = "$C" || rc=1; lim "$X"; test "$?" = 2 || rc=1; grep -qF 'check-pii-shapes: structural: ' "$T/lo" || rc=1; grep -qF 'failed to write scratch file' "$T/lo" || rc=1; grep -q '^FINDING ' "$T/lo"; test "$?" = 1 || rc=1; grep -qF "$C" "$T/lo"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D3.) Static guard over the scratch-file redirections. Backslash-continued lines of `bin/check-pii-shapes.sh` are first joined into logical lines.
  - The criterion selects every logical line that redirects (`>` or `>>`) into `"$FINDINGS_FILE"`, `"$FILELIST"`, `"$PFILELIST"` or `"$CONTENT_FILE"`, leaving out lines containing `printf 'FINDING ` (`:695`/`:720`, a non-goal).
  - At HEAD that set is non-empty, and every member contains `fail_structural`.
  - Positive control: at the base the same selection is non-empty and has at least one member without `fail_structural`.
  - This is the only evidence for the truncation sites `:674`, `:759` and `:831` and for `:780`, which no size-limit fixture can reach (see Assumptions).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac4.XXXXXX") || exit 1; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; S=bin/check-pii-shapes.sh; test -s "$S" || exit 1; git show "$B:$S" > "$T/b.sh" || exit 1; test -s "$T/b.sh" || exit 1; sel(){ awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$1" | grep -E '>>?[[:space:]]*"\$(FINDINGS_FILE|FILELIST|PFILELIST|CONTENT_FILE)"' | grep -vF "printf 'FINDING "; }; sel "$T/b.sh" > "$T/b0"; test -s "$T/b0" || exit 1; grep -vF fail_structural "$T/b0" > "$T/b1"; test -s "$T/b1" || exit 1; sel "$S" > "$T/h0"; test -s "$T/h0" || rc=1; grep -vF fail_structural "$T/h0" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC5** (D1, D3; N1.) The existing modes are byte-identical with the base.
  - Fixture repository:
    - committed after the root commit `r0`: a token file, a tracker-key file, and `tests/rollup-track/fixtures/winpath.jsonl` carrying a home-path shape;
    - untracked: a home-path file, a NUL-bearing file and a symlink whose target is a home path;
    - an ignored directory holding a token.
  - The base commit's script (from `git show`) and HEAD's script run on it with each of: no argument, `--all`, `--base <r0>`, `--all --base <r0>`, `--bogus`, `--base` with no value, and a stray argument. Each runs with `PII_CHECK_TRACKER_KEY` empty and set to `1`. The two scripts give the same exit status, stdout bytes and stderr bytes in all fourteen pairs.
  - Positive controls:
    - HEAD differs from the base blob.
    - HEAD `--all` with the opt-in exits `1`. It reports the token, tracker-key and both home-path findings, nothing under `ign/` or `tests/`, prints `skip: binary`, and prints no `skip: known-shape`.
    - HEAD `--base <r0>` reports the token and nothing under `tests/`.
    - HEAD `--paths tests` exits `2` with the known-shape notice for `tests/rollup-track/fixtures/winpath.jsonl`, showing that the fixture path is on the list.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac5.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/check-pii-shapes.sh"; test -s "$X" || exit 1; git show "$B:bin/check-pii-shapes.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; cmp -s "$T/base.sh" "$X"; test "$?" = 1 || rc=1; K=$(printf 'gh%s_%s' p "$(printf '%024d' 5)"); H=$(printf '/%s/%s/x' Users qzname); KS=tests/rollup-track/fixtures/winpath.jsonl; F="$T/f"; mkdir -p "$F" && git -C "$F" init -q && git -C "$F" -c user.email=t -c user.name=t commit -q --allow-empty -m base || exit 1; r0=$(git -C "$F" rev-parse HEAD) || exit 1; mkdir -p "$F/tests/rollup-track/fixtures" || exit 1; printf 'k %s\n' "$K" > "$F/t.txt"; printf 'see %s-%s\n' QZX 42 > "$F/k.txt"; printf '%s\n' "$H" > "$F/$KS"; git -C "$F" add t.txt k.txt "$KS" && git -C "$F" -c user.email=t -c user.name=t commit -q -m f || exit 1; printf '%s\n' "$H" > "$F/un.txt"; printf 'a\000b\n' > "$F/b.dat"; ln -s "$H" "$F/ln" || exit 1; mkdir -p "$F/.git/info" "$F/ign" || exit 1; printf 'ign/\n' >> "$F/.git/info/exclude" || exit 1; printf 'k %s\n' "$K" > "$F/ign/i.txt"; n=0; for v in '' '--all' "--base $r0" "--all --base $r0" '--bogus' '--base' 'extra'; do for tk in '' 1; do tmo "$F" "$T/o0" "$T/e0" env PII_CHECK_TRACKER_KEY="$tk" bash "$T/base.sh" $v; a=$?; tmo "$F" "$T/o1" "$T/e1" env PII_CHECK_TRACKER_KEY="$tk" bash "$X" $v; b=$?; test "$a" = "$b" || rc=1; cmp -s "$T/o0" "$T/o1" || rc=1; cmp -s "$T/e0" "$T/e1" || rc=1; n=$((n + 1)); done; done; test "$n" = 14 || rc=1; tmo "$F" "$T/o" "$T/e" env PII_CHECK_TRACKER_KEY=1 bash "$X" --all; test "$?" = 1 || rc=1; for q in 'pattern=token path=t.txt' 'pattern=tracker-key path=k.txt' 'pattern=home-path path=un.txt' 'pattern=home-path path=ln'; do grep -qF "FINDING $q " "$T/o" || rc=1; done; grep -qF -e 'path=ign/' -e 'path=tests/' "$T/o"; test "$?" = 1 || rc=1; grep -qF 'skip: binary' "$T/e" || rc=1; grep -qF 'skip: known-shape' "$T/e"; test "$?" = 1 || rc=1; tmo "$F" "$T/o" "$T/e" bash "$X" --base "$r0"; test "$?" = 1 || rc=1; grep -qF 'FINDING pattern=token path=t.txt ' "$T/o" || rc=1; grep -qF 'path=tests/' "$T/o"; test "$?" = 1 || rc=1; tmo "$F" "$T/o" "$T/e" bash "$X" --paths tests; test "$?" = 2 || rc=1; grep -qxF "check-pii-shapes: skip: known-shape fixture, not scanned: $KS" "$T/e" || rc=1; test "$rc" -eq 0

- [ ] **AC6** (D5; N1, N2.) The suites at HEAD.
  - `tests/check-pii-shapes/run.sh` and `tests/bin-help/run.sh` are scanned for a recursive-deletion pattern, with backslash-continued lines joined; neither may match.
  - With `CHECK_PII_SHAPES_BIN` unset, each runs under `tms`, exits `0`, and has no line beginning `FAIL`.
  - Every distinct `pass "…"` literal in the base blob of the PII suite is still in the HEAD file.
  - The PII suite's output has at least one line beginning `PASS: T-1191 item1 ` and at least one beginning `PASS: T-1191 item2 `.
  - For each of `paths-list` (`:863`), `paths-symlink-target` (`:876`), `all-untracked-list` (`:790`), `all-symlink-target` (`:803`), `binary-detection` (`:679`), `pattern-scan` (`:692`) and `email-scan` (`:707`), the output has exactly one line beginning `PASS: T-1191 item3 <name> `.
  - No line begins `FAIL: T-1191 `.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac6.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CODEX_THREAD_ID CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; S=tests/check-pii-shapes/run.sh; for s in "$S" tests/bin-help/run.sh; do test -s "$s" || { rc=1; continue; }; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$s" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || { rc=1; continue; }; test "${ps2[1]}" -eq 1 || { rc=1; continue; }; L="$T/log-$(basename "$(dirname "$s")")"; tms "$s" "$L"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$L"; test "$?" = 1 || rc=1; done; L="$T/log-check-pii-shapes"; test -s "$L" || rc=1; git show "$B:$S" > "$T/bs" || exit 1; test -s "$T/bs" || exit 1; grep -o 'pass "[^"]*"' "$T/bs" | sort -u > "$T/p0"; grep -o 'pass "[^"]*"' "$S" | sort -u > "$T/p1"; test -s "$T/p0" || rc=1; test -z "$(comm -23 "$T/p0" "$T/p1")" || rc=1; for i in item1 item2; do grep -q "^PASS: T-1191 $i " "$L" || rc=1; done; for nm in paths-list paths-symlink-target all-untracked-list all-symlink-target binary-detection pattern-scan email-scan; do test "$(grep -c "^PASS: T-1191 item3 $nm " "$L")" = 1 || rc=1; done; grep -q '^FAIL: T-1191 ' "$L"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC7** (D3, D5.) Each item 3 case reproduces the defect against the base script, so none passes vacuously.
  - `tests/check-pii-shapes/run.sh` names `CHECK_PII_SHAPES_BIN`, and the base blob of the checker differs from HEAD's.
  - With `CHECK_PII_SHAPES_BIN` pointing at the base commit's script (copied under `$TMPDIR`), the suite runs under `tms` and exits `1`.
  - Its output carries, for each case, a line beginning `FAIL: T-1191 item3 <name> ` that contains `(rc=<n>)`:
    - `n` is `1` for `paths-list`, `paths-symlink-target`, `all-untracked-list` and `all-symlink-target` (the base ends through `set -e`);
    - `n` is `0` for `binary-detection`, `pattern-scan` and `email-scan` (the base swallows the failure and reports clean).
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac7.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT CODEX_THREAD_ID CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; S=tests/check-pii-shapes/run.sh; test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; grep -qF 'CHECK_PII_SHAPES_BIN' "$S" || rc=1; git show "$B:bin/check-pii-shapes.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; cmp -s "$T/base.sh" bin/check-pii-shapes.sh; test "$?" = 1 || rc=1; ( export CHECK_PII_SHAPES_BIN="$T/base.sh"; tms "$S" "$T/lb" ); tb=$?; test "$tb" = 1 || rc=1; for pr in paths-list:1 paths-symlink-target:1 all-untracked-list:1 all-symlink-target:1 binary-detection:0 pattern-scan:0 email-scan:0; do nm="${pr%%:*}"; ex="${pr##*:}"; grep "^FAIL: T-1191 item3 $nm " "$T/lb" | grep -qF "(rc=$ex)" || rc=1; done; test "$rc" -eq 0

- [ ] **AC8** (D4.) `--help`. `bash bin/check-pii-shapes.sh --help` exits `0` with non-empty output.
  - The output contains `skip: known-shape`.
  - The part after the `Exit codes:` line contains `trailing slash` and `scratch file`.
  - Every Usage line of the base script's `--help` output (a line beginning `  check-pii-shapes.sh `, at least one; read from the base blob, so not subject to population growth) is still present verbatim.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac8.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE PII_CHECK_TRACKER_KEY CHECK_PII_SHAPES_BIN; mkdir -p "$HOME" || exit 1; tmo(){ local d="$1" o="$2" e="$3" p w r; shift 3; set -m; ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" & p=$!; ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -KILL -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; return "$r"; }; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/check-pii-shapes.sh"; test -s "$X" || exit 1; git show "$B:bin/check-pii-shapes.sh" > "$T/base.sh" || exit 1; tmo "$T" "$T/h0" "$T/e" bash "$T/base.sh" --help; test "$?" = 0 || exit 1; tmo "$T" "$T/h1" "$T/e" bash "$X" --help; test "$?" = 0 || rc=1; test -s "$T/h1" || rc=1; grep -E '^  check-pii-shapes\.sh ' "$T/h0" > "$T/u0"; test -s "$T/u0" || exit 1; grep -qvxF -f "$T/h1" "$T/u0"; test "$?" = 1 || rc=1; grep -qF 'skip: known-shape' "$T/h1" || rc=1; awk '/^Exit codes:/ { f = 1; next } f' "$T/h1" > "$T/x"; for q in 'trailing slash' 'scratch file'; do grep -qF -- "$q" "$T/x" || rc=1; done; test "$rc" -eq 0

- [ ] **AC9** (D4.) Docs in lockstep.
  - In `docs/pii-controls.md`, the `## Running it` section (to the next `## ` heading) contains `skip: known-shape`, `trailing slash` and `scratch file`.
  - In `docs/pii-controls.ja.md`, the `## 実行方法` section contains `skip: known-shape`, `末尾` and `作業ファイル`.
  - Both sections are non-empty (positive control that each heading still exists).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac9.XXXXXX") || exit 1; E=docs/pii-controls.md; J=docs/pii-controls.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; sec(){ awk -v h="$1" '$0 == h { f = 1; next } f && /^## / { f = 0 } f' "$2"; }; sec '## Running it' "$E" > "$T/e1"; sec '## 実行方法' "$J" > "$T/j1"; test -s "$T/e1" || rc=1; test -s "$T/j1" || rc=1; for q in 'skip: known-shape' 'trailing slash' 'scratch file'; do grep -qF -- "$q" "$T/e1" || rc=1; done; for q in 'skip: known-shape' '末尾' '作業ファイル'; do grep -qF -- "$q" "$T/j1" || rc=1; done; test "$rc" -eq 0

- [ ] **AC10** (N3.) Prompt sync, no prompt edit. `bash bin/check-prompt-sync.sh` exits `0` and prints the line `check-prompt-sync: all registered prompt blocks in sync`. The committed diff `<base>...HEAD` over `templates/prompt-blocks` and `agents` is empty.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac10.XXXXXX") || exit 1; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; test -s bin/check-prompt-sync.sh || exit 1; test -d templates/prompt-blocks || exit 1; test -d agents || exit 1; bash bin/check-prompt-sync.sh > "$T/o" 2> "$T/e"; test "$?" = 0 || rc=1; grep -qxF 'check-prompt-sync: all registered prompt blocks in sync' "$T/o" || rc=1; git diff --no-renames --quiet "$B"...HEAD -- templates/prompt-blocks agents; test "$?" = 0 || rc=1; test "$rc" -eq 0

- [ ] **AC11** `shellcheck` exits `0` on `bin/check-pii-shapes.sh` and `tests/check-pii-shapes/run.sh`.
  - check: rc=0; for f in bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac11.XXXXXX") || exit 1; shellcheck bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh > "$T/sc" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** No recursive deletion.
  - Neither `bin/check-pii-shapes.sh` nor `tests/check-pii-shapes/run.sh` matches the pattern `rm -[a-zA-Z]*[rR]|find .*-delete`.
  - In this spec, once every literal occurrence of that pattern string is removed from each line, no line matches it.
  - The pattern string itself occurs in this spec, as a positive control that the read happened.
  - check: rc=0; K='rm -[a-zA-Z]*[rR]|find .*-delete'; S=.shell-team/specs/T-1191-local-mode-followups-pii-paths.md; for f in bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh "$S"; do test -r "$f" || exit 1; done; for f in bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh; do grep -qE -- "$K" "$f"; r=$?; test "$r" = 1 || rc=1; done; test "$(grep -cF -- "$K" "$S")" -ge 1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac12.XXXXXX") || exit 1; awk -v k="$K" '{ s = $0; o = ""; while ((i = index(s, k)) > 0) { o = o substr(s, 1, i - 1); s = substr(s, i + length(k)) } print o s }' "$S" > "$T/x" || exit 1; test "$(grep -c '' "$T/x")" = "$(grep -c '' "$S")" || exit 1; grep -qE -- "$K" "$T/x"; r=$?; test "$r" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC13** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only`, and the untracked strays `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `bin/check-pii-shapes.sh`.
  - **Allowed members.**
    - `bin/check-pii-shapes.sh`, `tests/check-pii-shapes/run.sh`, `docs/pii-controls.md`, `docs/pii-controls.ja.md`.
    - This task's records: `.shell-team/specs/T-1191-<slug>.md`, `.shell-team/provenance/T-1191.md`, `.shell-team/interventions/T-1191.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1191.md`, and a raw capture `.shell-team/reviews/T-1191-codex-<stem>.{txt,jsonl,json}`.
    - `.shell-team/todo.md`, `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac13.XXXXXX") || exit 1; P=feature/local-mode-followups-tests; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD) || exit 1; elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD) || exit 1; elif git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/check-pii-shapes.sh "$T/s" || rc=1; grep -vxE 'bin/check-pii-shapes\.sh|tests/check-pii-shapes/run\.sh|docs/pii-controls(\.ja)?\.md|\.shell-team/(specs/T-1191-[a-z0-9-]+\.md|provenance/T-1191\.md|interventions/(T-1191|no-task)\.md|reviews/T-1191\.md|reviews/T-1191-codex-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC14** Records conformant. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`. Positive control: the spec, the checker and the board are first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1191-ac14.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1191-local-mode-followups-pii-paths.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC15** CI is green on the pull request: the shellcheck step, the check-pii-shapes fixture suite (the Linux run of every item 3 size-limit fixture), the diff-scoped PII scan, the prompt-sync dogfood and the bin-help suite.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **`--paths` arguments a role or a maintainer writes**: record files and the base dir; subdirectories; several paths in one call; relative from the root or a subdirectory, or absolute; names with spaces; a single or doubled trailing slash on a file, a directory, a symlink to a file, a symlink to a directory, or a missing path; `./`, `../`, `file/.` and `/`.
2. **A path equal to a known-shape list entry**, named directly or met in a walk. This happens in this repository and in an adopter repository that happens to carry the same relative path.
3. **A failed write into the checker's scratch files under `$TMPDIR`**, as an error return:
   - `EFBIG` under a file-size limit with `SIGXFSZ` ignored by the invoking shell;
   - `ENOSPC` on a full temp filesystem;
   - `EACCES`;
   - `EIO`.

   A helper tool (`tr`, `grep`) reports such a failure as its error status (above grep's no-match status `1`).
4. **The existing modes** (default, `--base`, `--all`, their usage errors, the tracker-key opt-in) on the fixture classes of **AC5** and the existing suite.
5. **Platforms**: bash on the CI runner (Linux) and on the maintainer's workstation (macOS).
6. **These check lines** run from a fresh clone, where no gitignored path exists.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Signal death under the default `SIGXFSZ` disposition (exit 153). The process is killed before any handler could route it.
2. A temp-filesystem condition that appears or clears between two writes of the same run (for example free space reclaimed mid-run).
3. Write failures at `:695`, `:720`, `:936` and `:957` (exit 1, never 0; follow-up issue).
4. A write failure on the checker's own stdout or stderr.
5. A path changed by another process during the scan (waived in #716), and physical resolution of a symlinked parent component (the stated T-1182 design).
6. A repository whose root is `/`, and a path containing a newline.
7. A file-size limit low enough to fail `mktemp -d` or the guarded `git ls-files` outputs first. Those already exit `2` through existing guards.

<!-- END intent-block: T-1191 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Known-shape notice, exact line, named or walked; not counted as read (D1) | **AC1** |
| 2 | Known-shape-only run exits 2 without the clean line (D1; N2) | **AC1** |
| 3 | Notice does not reach `--all` or diff mode (D1) | **AC1** (`--all`), **AC5** (`--all`, `--base`, default; byte identity) |
| 4 | Trailing slash requires a real directory; new structural message; input-class table (D2) | **AC2** |
| 5 | Eleven write sites through `fail_structural`, message `failed to write scratch file`, exit 2 (D3) | **AC3** (`:863` direct), **AC6**/**AC7** (`:863`, `:876`, `:790`, `:803`, `:679`, `:692`, `:707` fixtures), **AC4** (static, all `FILELIST`/`PFILELIST`/`CONTENT_FILE`/`FINDINGS_FILE` redirections incl. `:674`, `:759`, `:780`, `:831`) |
| 6 | Grep's no-match status is not a failure (D3) | **AC5** and **AC6** (every existing no-match run unchanged) |
| 7 | Existing messages byte-identical (D3; N1) | **AC5** |
| 8 | Each fixture first proves its fault bites; base reproduces the defect (D5) | **AC3** (base precondition), **AC7** (base rc per case); the in-suite bite assertion is a reading item for QA plus the engineer's mutation probes, because a check line cannot see what a passing case asserted |
| 9 | `CHECK_PII_SHAPES_BIN` override (D5) | **AC7** |
| 10 | Existing suite `pass` labels survive; suites green (D5; N1) | **AC6** |
| 11 | Docs EN/JA and `--help` in lockstep (D4) | **AC8**, **AC9** |
| 12 | Prompt sync green, no prompt or agent edit (N3) | **AC10** |
| 13 | No edit to adopting / migrating docs or any other file (Non-goals) | **AC13** |
| 14 | Item 4 out of scope (Non-goals) | info-only (not promoted to AC): an exclusion; **AC13** keeps the diff off the loop sections only insofar as it confines the docs edit to two files, and nothing measures which section an edit touched beyond **AC9** |
| 15 | Exit-1 sites go to a follow-up issue (Non-goals) | info-only (not promoted to AC): a disposition; no committed byte can show that an issue exists, and the coordinating session records the number on the board |
| 16 | No `SIGXFSZ` handling (Non-goals) | info-only (not promoted to AC): an absence that no fixture can distinguish from a correct implementation without testing signal death, which is out of scope; QA reads the diff |
| 17 | Stdout/stderr writes stay `\|\| true` (Non-goals) | info-only (not promoted to AC): unchanged lines; **AC5** byte identity covers their success behaviour |
| 18 | Never-dropped stops the task; Majors rule; drop order (Pre-commitment) | info-only (not promoted to AC): dispositions, not deliverable properties |
| 19 | No sweep, no whole CI re-run, no past specs' check lines (Non-goals) | info-only (not promoted to AC): process exclusions |
| 20 | No recursive deletion; shellcheck clean (Acceptance-criteria rules) | **AC12**, **AC11** |
| 21 | CI green (verification ceiling) | **AC15** (above-ceiling) |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. The operator's 2026-10-01 ruling forbids running past specs' check lines locally, and the A2 ruling drops per-task sweeps. CI and this task's own check lines decide the impact, as in T-1182, T-1189 and T-1190.
- **Known readers** (Grep tool over `.shell-team/specs` for check lines naming `check-pii-shapes` or `pii-controls`; 107 specs, a lower bound — a criterion reaching the checker through indirection stays unmeasured, and that is disclosed).
  - Almost all of them run the checker as a shape scan of their own records and depend only on its success paths, which **AC5** keeps byte-identical.
  - T-1182's criteria assert the `--paths` verdicts; **AC6** keeps every existing suite label and keeps the suite green.
  - A literal search for a `--paths` argument ending in `/` across specs, tests, templates, agents, skills, docs and READMEs found none, so no existing caller hits the new refusal.
- **Adopter-side artifacts.** A role's hand-off shape scan in `local` mode sees the new notice when it names a known-shape path, and exit `2` on a trailing-slash file argument or a failed scratch write. The record-shape-scan block already treats exit `2` as a scan that did not complete. No generated or untracked adopter artifact changes.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| #716 item 1 (notice) | not met | not met (stderr notice in an opt-in mode) | PATCH | a diagnostic on an existing path |
| #716 item 2 (trailing slash) | not met | not met | PATCH | a refusal fix in an existing mode |
| #716 item 3 (scratch writes) | not met | not met (failure paths only) | PATCH | exit-code fix on write failure |

The derived tier is PATCH, the maximum of the column.

## Assumptions

- **Measured by this role** (Read and Grep tools, working tree clean at `01be9002`):
  - Every line anchor in `## Summarized sources`.
  - `refs/heads/feature/local-mode-followups-tests` and `refs/heads/feature/local-mode-followups-pii-paths` both hold `01be9002fec48e4295fc7a2c60b93a0c34abd54a` (read from `.git/refs/heads/`), so `B` resolves to `01be9002` today.
  - The recursive-deletion pattern matches neither `bin/check-pii-shapes.sh` nor `tests/check-pii-shapes/run.sh`.
  - Under `bin/`, `tests/` and `docs/`, there are 0 occurrences of `skip: known-shape`, `CHECK_PII_SHAPES_BIN`, `failed to write scratch file` and `T-1191`. `trailing slash` occurs only in unrelated files (`bin/team-commit.sh`, `bin/team-paths.sh`, other suites), never in the PII checker, its suite or its docs. In `bin/check-pii-shapes.sh`, `scratch` occurs only in the `mktemp` message.
  - A literal search found no `--paths` argument ending in `/` in specs, tests, templates, agents, skills, docs or READMEs.
- **Measured by the coordinating session** (relayed, owner: the coordinating session; 2026-10-12, base script at `01be9002`, macOS workstation). The scratch repository was under `$TMPDIR` with `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1` and one plain-text `clean.txt`:
  - (a) no limit: exit `0`, clean line;
  - (b) `ulimit -f 0` alone: `Filesize limit exceeded`, exit `153`;
  - (c) `trap '' XFSZ; ulimit -f 0`: exit `1`. The combined output was only the absolute path of `clean.txt`, with no `FINDING` line.

  **AC3** rests on (c), which is the route at `:863`.
- **Predicted, unmeasured** (owner: the coordinating session's freeze run, then the engineer). A false prediction routes back here as a broken check line, never as a pass.
  - **Stale buffer.** The absolute path in (c) is bash's `printf` buffer, left behind by the failed write and flushed to the real stdout later. HEAD's structural message may therefore share a line with it, so **AC3** greps the message unanchored and never compares stdout.
  - **`:790`.** Reachable by an exact-size fixture: at least one tracked entry, and untracked names whose `ls-files --others -z` output fits the limit while the combined `FILELIST` does not.
  - **`:780`.** Not reachable by `EFBIG`: the guarded `ls-files -s -z` output is always larger than the tracked part of `FILELIST`. It is left to **AC4**.
  - **`:803` and `:876`.** Reachable with a symlink target longer than the limit while the list entries fit. The `ulimit -f` unit is 1024 bytes in normal bash and 512 bytes in POSIX mode, and a macOS symlink target is at most 1023 bytes, so on macOS the fixture uses POSIX-mode units. Linux (CI, **AC15**) can also use normal units.
  - **`:674`, `:759`, `:831`.** Truncations of a new or empty file never exceed a limit, so they are reachable only through `ENOSPC`/`EACCES`, which no fixture builds. They are left to **AC4**.
  - **`:679`, `:692`, `:707`.** Reachable by a PATH stub for `tr`, or for `grep` restricted to `-nE` or `-noE` respectively, exiting above `1`. The base then exits `0`: a binary-only `--paths` run reads as text and ends clean, and a planted token or mailbox is missed and the run ends clean. A stub of that kind is how a failed write surfaces to the script. The coordinating session's freeze run measures the base exit status of each.
  - **The suite's base run** (`CHECK_PII_SHAPES_BIN` = base copy, **AC7**) exits `1`: the new T-1191 cases fail, every pre-existing case passes against the base.
- **Relayed, not readable from this role.**
  - The operator's approval of the sprint stop rule at sprint planning on 2026-10-12 (owner: the coordinating session).
  - The open state of PR #743 (T-1189) and PR #745 (T-1190, predecessor `feature/local-mode-followups-tests`) against `develop`.
- **Fresh-clone limit of the discriminator.** While PR #745 is open, a fresh clone resolves `B` through the `refs/remotes/origin/` arm. After the predecessor is merged and deleted, the line falls back to `develop`; with neither branch present it exits `1` (fail closed). That is acceptable for merge-point-scoped criteria.
- **Own-coinage count premises** (expected 0 at `B`; the freeze run measures each with `git show "$B:<path>" | grep -c '<token>'` over the checker, its suite and the two docs): `skip: known-shape`, `failed to write scratch file`, `CHECK_PII_SHAPES_BIN`, `T-1191 item1`, `T-1191 item2`, `T-1191 item3`, `trailing slash` (in the checker and the two docs), `作業ファイル` (in the JA doc).
- **Borrowed tokens** (the freeze run measures each at `B`):
  - `check-pii-shapes: skip: ` in the checker (expected 3 printf sites: `:747`, `:777`, `:954`);
  - `check-pii-shapes: structural: ` produced through `die` (expected 1 format site, `:261`);
  - `末尾` in the `## 実行方法` section of `docs/pii-controls.ja.md` (expected 0; if non-zero, **AC9**'s `末尾` token is vacuous at the base and the freeze run reports it here for a meaning-preserving correction);
  - the recursive-deletion pattern in both files (expected 0).
- **Pre-implementation expectation (for the freeze read).**
  - **AC1** red: no notice.
  - **AC2** red: rows 1–6 exit `0`.
  - **AC3** red: HEAD exits `1`.
  - **AC4** red: unguarded lines.
  - **AC5** red, on its first positive control only (HEAD equals the base blob) and on the `--paths tests` notice control; every byte-identity pair is green.
  - **AC6** red: no T-1191 labels.
  - **AC7** red: no override, the blobs are equal, and no T-1191 lines.
  - **AC8** and **AC9** red.
  - **AC10**, **AC11** and **AC12** green. **AC12** reads this spec.
  - **AC13** red on its positive control.
  - **AC14** green when the board entry is conformant.
  - **AC15** `SKIP`.

## Open questions

- None blocking.

## Notes for engineer

- **Files.** `bin/check-pii-shapes.sh`, `tests/check-pii-shapes/run.sh`, `docs/pii-controls.md`, `docs/pii-controls.ja.md`, plus provenance and the test recipe as usual. Nothing else (**AC13**).
- **Fixed strings the checks read.**
  - The notice: `check-pii-shapes: skip: known-shape fixture, not scanned: <path>`.
  - The trailing-slash message: through `fail_structural`, beginning `--paths: ` and containing `trailing slash`.
  - Every new write-failure message contains `failed to write scratch file`.
  - Suite labels: `PASS: T-1191 item1 …`, `PASS: T-1191 item2 …`, and `PASS: T-1191 item3 <name> …` for the seven names in **AC6**, each through the existing `pass`/`fail` helpers. Each item 3 `fail` message ends with `(rc=<n>)`.
  - The override is `CHECK_PII_SHAPES_BIN`.
- **AC4's shape.** A guarded redirection keeps `fail_structural` on the same logical line (a backslash continuation is fine). Routing all writes through one small helper also satisfies it, but QA then reads that helper.
- **Grep guards.** Distinguish grep's no-match status `1` from an error (above `1`). Only the error routes to `fail_structural`.
- **Size-limit fixtures.**
  - Set `trap '' XFSZ` and the limit inside a subshell, and capture the faulted run through a pipe (a file written inside the limit fails too).
  - In POSIX mode, `ulimit -f` counts 512-byte blocks.
  - Build the scratch repository before entering the limit.
  - Each case first proves its fault bites: the unfaulted run exits `0` or `1` as expected, and the faulted run does not print the clean line.
- **Order inside the `--paths` loop.** The slash check can run after the existing existence and containment checks, so `missing/` keeps its existing message. The table only fixes exit statuses.
- **Mutation probes (mechanism class).** In a scratch copy under `$TMPDIR`, break each never-dropped property once and confirm the matching criterion goes red, then restore. For example:
  - reword one existing structural message (**AC5**);
  - make a known-shape-only run print the clean line (**AC1**);
  - drop the slash check (**AC2**);
  - unguard `:863` (**AC3**, **AC4**);
  - restore `|| true` at `:692` (**AC6**/**AC7**).
- **Runtime.** Run long suites in their own process group with a timeout that kills the group, under `ulimit -f`, with output capped.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** The checker is a shipped `bin/` gate (full strength); the docs are shipped text; the inline check lines get dev-scaffold depth (operator ruling 2026-08-22).

## Notes from engineer

- Measured premises (macOS host, bash 3.2, base script at `01be9002`, each run in a subshell with `trap '' XFSZ` and the output captured through a pipe):
  - `:863`: `ulimit -f 0` with `--paths clean.txt` ends the base at exit `1` (stale absolute path on stdout, no `FINDING` line) and HEAD at exit `2` with the message sharing that line, as predicted.
  - `ulimit -f` counts 1024-byte units in POSIX mode too on this bash, so the predicted 512-byte route does not exist here. On this host an append (`>>`) is refused only when one single write exceeds the limit, so no limit makes the `:790` list append fail after the smaller guarded writes, and a 900-byte symlink target stayed under a 1-block limit. The `:790`, `:803` and `:876` fixtures therefore use read-only scratch files made through PATH stubs for `mktemp` and `git` (see the suite's T-1191 block); `:863` keeps the limit route.
  - Against the base script the suite's T-1191 item 3 cases end at exit `1` (`paths-list`, `paths-symlink-target`, `all-untracked-list`, `all-symlink-target`) and `0` (`binary-detection`, `pattern-scan`, `email-scan`), as AC7 expects.
- A `--paths` argument that resolves outside the repository keeps its existing message ahead of the trailing-slash check, so `/` still exits `2` through the containment check.
