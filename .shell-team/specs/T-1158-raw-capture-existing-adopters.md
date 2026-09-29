# The run skill warns at Step 0 when a published raw review capture would not be ignored, and states that raw captures are never staged

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1158

**Branch**: `feature/622-raw-capture-existing-adopters`, cut from `develop` at `0b229093` (relayed; see `## Assumptions`). Not stacked: no open predecessor PR, so the base-side reads in **AC1**, **AC4** and **AC5** resolve `develop`'s merge-base directly.

**Scope class**: minimal stop-the-bleed (sprint raw-capture-reach). Only the two run-skill sentences issue #622 names are in scope.

## Problem

v2.7.5 (T-1155) made the shipped `<base>/.gitignore` template ignore `reviews/*.txt`, `reviews/*.jsonl` and `reviews/*.json`, but `team-init` skips an existing `<base>/.gitignore`, so an adopter scaffolded earlier keeps the old two-pattern file and nothing in a run tells them. With that stale file, a published raw capture shows as untracked, and the run skill's "commit records immediately" discipline leads the orchestrator to commit it — raw captures can carry a home-directory path and account or session identifiers. The run skill never says which reviewer records are committed.

## Summarized sources

- GitHub issue #622 — **relayed verbatim by the coordinating session, not read by this role**. Distinctions carried over: the probe is read-only and writes no file; it must count a root-level ignore too (hence git's own resolution, e.g. `git check-ignore`, on a probe path); the warning is one line naming the `docs/adopting.md` migration step; the second change is one sentence that only the curated `<task-id>.md` is committed and `.txt` / `.jsonl` / `.json` raw captures in the reviews dir are never staged; out of scope: a reviewer disposition for already-tracked raws, a `git rm --cached` step, any `team-init` change.
- `skills/run/SKILL.md` (read first-hand at `:1`–`:40`, and grepped). Distinctions: Step 0 is the paragraph at `:18` beginning `**Step 0 — resolve the operating-file paths.**`, which runs `team-paths.sh --print`; the next paragraph `:20` begins `Because **the Bash-less agents`; the file today contains no `git check-ignore`, no `never staged` and no `Upgrading an existing adopter` (grep count 0 each); `:18` carries the `operating-paths-core.md` fragment verbatim.
- `templates/prompt-blocks/registry.txt` (read first-hand at `:35`–`:57`). Distinction: `skills/run/SKILL.md` is a `contain`-mode consumer of fourteen registered blocks (among them `operating-paths-core.md`, whose text sits inside Step 0), so an edit that alters a contained block's bytes fails `bin/check-prompt-sync.sh`. This contradicts the relayed premise that SKILL.md is not a sync target (see `## Assumptions`).
- `templates/prompt-blocks/operating-paths-core.md` (read first-hand, 1 line). Distinction: the fragment that must survive byte-for-byte inside Step 0.
- `docs/adopting.md` (read first-hand at `:38`–`:55`). Distinction: `:42` opens the paragraph `**Upgrading an existing adopter repository.**`, which already tells an existing adopter to append the three patterns to `<base>/.gitignore` by hand and not to use `team-init --force`; it is the target the warning names, and needs no change.
- `README.md:86`, `README.ja.md:86`, `docs/adopting.ja.md:50` (read first-hand by grep). Distinction: each already states the raw patterns the installed `<base>/.gitignore` carries — still true after this task.
- `templates/shell-team.gitignore` (grepped). Distinction: carries `reviews/*.txt` at `:16` (and, per T-1155, `.jsonl` and `.json`); used by **AC3** as the "new template" fixture.
- `bin/team-paths.sh` (read at `:55`–`:191`). Distinction: `--print` / `--get reviews` resolve the reviews dir for all three layouts, so the probe path is derived from it rather than hardcoded.
- `bin/check-adopter-docs.sh` (read at `:28`–`:40`, `:579`–`:643`). Distinction: a `- shipped-docs:` disposition is exactly `this-task` or `issue #<N>` with nothing after it, and each `this-task` path must occur as a literal substring in a `- check:` or `- adopter-surface:` line of the same spec.

## Goal

<!-- BEGIN intent-block: T-1158 -->

- user-visible: yes — an adopter whose `<base>/.gitignore` predates the raw-capture patterns now sees a one-line warning at the start of every run naming the migration paragraph, and a run no longer stages a raw review capture by following the commit-records discipline. Nothing new becomes possible — the change closes a leak on the shipped default path — so the tier is PATCH.
- verification-class: mechanism — the diff touches only `skills/run/SKILL.md`, but it adds a command the orchestrator executes at Step 0 of every run and the file is a `contain`-mode consumer that `bin/check-prompt-sync.sh` enforces, so it is priced as an executing surface.
- verification-ceiling: unit-and-static — every criterion is settled in a plain checkout by string presence or absence in `skills/run/SKILL.md`, a Step-0 region of it, or its base blob read with `git show`; by `git check-ignore` exit statuses in temp repositories under `$TMPDIR` with `core.excludesFile` pinned; by a shipped suite's or checker's exit code; or by a `git diff` / `git ls-files` read. No criterion needs a real adopter repository or a live run.
- base-ref-discriminator: not-applicable — no open predecessor: the branch is cut directly from `develop`; base-side reads resolve `git merge-base develop HEAD` (local branch) or `git merge-base refs/remotes/origin/develop HEAD` where only the remote-tracking ref exists, selected by `git show-ref --verify --quiet`.
- shipped-docs: skills/run/SKILL.md — this-task

**Goal (one sentence).** `skills/run/SKILL.md`'s Step 0, after `team-paths.sh --print`, instructs a read-only probe — git's own ignore resolution on non-existent `.txt`, `.jsonl` and `.json` probe paths under the resolved reviews dir, so a root-level ignore counts — that prints a one-line warning naming `docs/adopting.md`'s "Upgrading an existing adopter repository" paragraph when any probe is not ignored, writes no file, and reports a probe that cannot be evaluated (exit `128`) on its own line rather than as ignored; and the skill carries one sentence that of the reviewer's records only the curated `<task-id>.md` is committed while `.txt` / `.jsonl` / `.json` raw captures in the reviews dir are never staged.

## Non-goals

- **No change to any other file's behaviour or text**: no `bin/`, `tests/`, `templates/`, `agents/`, `docs/`, README or CHANGELOG edit; the migration paragraph already exists and is only named. (**AC5**)
- **No disposition for raw captures already tracked**, no `git rm --cached` step, no history rewrite. (info-only)
- **No change to `team-init`'s handling of an existing `<base>/.gitignore`.** (**AC5**)
- **No per-task full-population two-arm sweep** — it runs once at the release under the operator's standing mode-A2 ruling. (info-only)

## Acceptance criteria

Every `check:` runs from the repository root under `bash`, reads the post-implementation tree, and writes only under `$TMPDIR`. The Step-0 region is the lines from the one beginning `**Step 0 — resolve the operating-file paths.**` up to, not including, the one beginning `Because **the Bash-less agents` — the probe and its warning live there.

- [ ] **AC1** The probe instruction sits in Step 0 after `--print`. The Step-0 region names `git check-ignore` at a later position than `team-paths.sh --print`, and names `.txt`, `.jsonl` and `.json` (not only as a prefix of `.jsonl`). The base blob of `skills/run/SKILL.md` names `git check-ignore` nowhere (positive control on the delta), and the region and its closing line are each asserted present.
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac1.XXXXXX") || exit 1; test "$(grep -cF -- 'Because **the Bash-less agents' "$S" || true)" = 1 || rc=1; awk 'index($0,"**Step 0 — resolve the operating-file paths.**")==1{f=1} index($0,"Because **the Bash-less agents")==1{f=0} f' "$S" > "$T/r"; test -s "$T/r" || rc=1; awk '{s=s $0 "\n"} END{p=index(s,"team-paths.sh --print"); c=index(s,"git check-ignore"); exit !(p>0 && c>p)}' "$T/r" || rc=1; grep -qF -- '.txt' "$T/r" || rc=1; grep -qF -- '.jsonl' "$T/r" || rc=1; grep -Eq '\.json([^l]|$)' "$T/r" || rc=1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; test "$(grep -cF -- 'git check-ignore' "$T/b" || true)" = 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** The warning names the migration paragraph and the probe writes nothing. The Step-0 region names `docs/adopting.md`, the paragraph title `Upgrading an existing adopter repository`, a warning (`warn`, case-insensitive), and that no file is written (`no file`, case-insensitive). `docs/adopting.md` still carries exactly one line beginning `**Upgrading an existing adopter repository.**`, so the named target exists.
  - adopter-surface: `skills/run/SKILL.md` Step 0 — the one-line warning an adopter sees at the start of a run, pointing at `docs/adopting.md`'s "Upgrading an existing adopter repository" paragraph.
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; test -s docs/adopting.md || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac2.XXXXXX") || exit 1; awk 'index($0,"**Step 0 — resolve the operating-file paths.**")==1{f=1} index($0,"Because **the Bash-less agents")==1{f=0} f' "$S" > "$T/r"; test -s "$T/r" || rc=1; grep -qF -- 'docs/adopting.md' "$T/r" || rc=1; grep -qF -- 'Upgrading an existing adopter repository' "$T/r" || rc=1; grep -qi -- 'warn' "$T/r" || rc=1; grep -qi -- 'no file' "$T/r" || rc=1; test "$(grep -c '^\*\*Upgrading an existing adopter repository\.\*\*' docs/adopting.md || true)" = 1 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC3** A probe that cannot be evaluated is never read as ignored, and the git behaviour the probe relies on holds. The Step-0 region names exit status `128`. In a temp git repository with `core.excludesFile=/dev/null`: with the pre-v2.7.5 two-line `<base>/.gitignore` (`runs/`, `reviews/.codex-capture.*`), `git check-ignore -q` on non-existent `.shell-team/reviews/t1158-probe.{txt,jsonl,json}` exits exactly `1` each; with those three patterns in the root `.gitignore` only, each exits `0` (a root-level ignore counts); with `templates/shell-team.gitignore` as `<base>/.gitignore` and no root file, each exits `0`; and outside any repository the same call exits exactly `128`.
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; test -s templates/shell-team.gitignore || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac3.XXXXXX") || exit 1; awk 'index($0,"**Step 0 — resolve the operating-file paths.**")==1{f=1} index($0,"Because **the Bash-less agents")==1{f=0} f' "$S" > "$T/r"; test -s "$T/r" || rc=1; grep -qF -- '128' "$T/r" || rc=1; G="$T/g"; mkdir -p "$G/.shell-team/reviews" "$T/n" || exit 1; git init -q "$G" > /dev/null 2>&1 || exit 1; ig() { git -C "$G" -c core.excludesFile=/dev/null check-ignore -q -- "$1"; }; printf 'runs/\nreviews/.codex-capture.*\n' > "$G/.shell-team/.gitignore"; for e in txt jsonl json; do ig ".shell-team/reviews/t1158-probe.$e"; r=$?; test "$r" -eq 1 || rc=1; done; printf '.shell-team/reviews/*.txt\n.shell-team/reviews/*.jsonl\n.shell-team/reviews/*.json\n' > "$G/.gitignore"; for e in txt jsonl json; do ig ".shell-team/reviews/t1158-probe.$e" || rc=1; done; rm -f "$G/.gitignore"; cp templates/shell-team.gitignore "$G/.shell-team/.gitignore" || exit 1; for e in txt jsonl json; do ig ".shell-team/reviews/t1158-probe.$e" || rc=1; done; GIT_CEILING_DIRECTORIES="$T" git -C "$T/n" -c core.excludesFile=/dev/null check-ignore -q -- t1158-probe.txt > /dev/null 2>&1; r=$?; test "$r" -eq 128 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** The never-staged sentence. `skills/run/SKILL.md` has exactly one line containing `never staged`, and that line names `<task-id>.md`, `.txt`, `.jsonl` and `.json` (not only as a prefix of `.jsonl`). The base blob has no such line (positive control on the delta).
  - check: rc=0; S=skills/run/SKILL.md; test -s "$S" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac4.XXXXXX") || exit 1; grep -F -- 'never staged' "$S" > "$T/l"; test "$(grep -c . "$T/l" || true)" = 1 || rc=1; grep -qF -- '<task-id>.md' "$T/l" || rc=1; grep -qF -- '.txt' "$T/l" || rc=1; grep -qF -- '.jsonl' "$T/l" || rc=1; grep -Eq '\.json([^l]|$)' "$T/l" || rc=1; git show "$B:$S" > "$T/b" 2>/dev/null || rc=1; test -s "$T/b" || rc=1; test "$(grep -cF -- 'never staged' "$T/b" || true)" = 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** This task's diff is confined to a fixed allow-list. The union of the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only` and the untracked strays `git ls-files --others --exclude-standard` contains no path outside `skills/run/SKILL.md`, `.shell-team/todo.md`, and this task's own spec, provenance, interventions and review records. **This criterion is merge-point-scoped and expected to go stale after merge**, once later tasks' files land on the same base; that is expected and is never repaired by widening the base resolution or re-deriving it per rework round. Positive control: the measured union is asserted non-empty.
  - check: rc=0; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac5.XXXXXX") || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; LC_ALL=C sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' skills/run/SKILL.md .shell-team/todo.md .shell-team/specs/T-1158-raw-capture-existing-adopters.md .shell-team/provenance/T-1158.md .shell-team/interventions/T-1158.md .shell-team/reviews/T-1158.md | LC_ALL=C sort -u > "$T/allow"; LC_ALL=C comm -23 "$T/got" "$T/allow" > "$T/extra"; test ! -s "$T/extra" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** The suites that read `skills/run/SKILL.md` and the prompt-block sync stay green. `bash bin/check-prompt-sync.sh`, `bash tests/codex-skeleton-hygiene/run.sh`, `bash tests/check-oversight/run.sh` and `bash tests/check-refreeze-grant/run.sh` each exit `0` and print no line beginning `FAIL` on either stream. Positive control: each file is asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac6.XXXXXX") || exit 1; for s in bin/check-prompt-sync.sh tests/codex-skeleton-hygiene/run.sh tests/check-oversight/run.sh tests/check-refreeze-grant/run.sh; do test -s "$s" || rc=1; bash "$s" > "$T/o" 2>&1 || rc=1; test "$(grep -c '^FAIL' "$T/o" || true)" = 0 || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC7** This spec is a conformant carrier of its own declarations. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams. Positive control: the spec and the checker are asserted non-empty first.
  - check: C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1158-raw-capture-existing-adopters.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1158-ac7.XXXXXX") || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; r=$?; rc=0; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; rm -rf "$T"; test "$rc" -eq 0

## Input space

**Reachable input classes** — what real adopter checkouts present at Step 0:

1. Base-dir layouts: default `.shell-team/`, legacy `tasks/`, a `$TEAM_RUN_BASE` override (single or nested subpath); the reviews dir resolved by `team-paths.sh`.
2. `<base>/.gitignore` states: the pre-v2.7.5 two-pattern file; the v2.7.5 template; a hand-appended file; no file at all.
3. Root-level ignores: none; the three raw patterns in the root `.gitignore`; the whole base dir ignored at root (probe then reads as ignored, no warning — correct, since nothing there can be staged).
4. An operator's global `core.excludesFile` honoured by the real probe (it governs `git add` too), pinned to `/dev/null` in the fixtures.
5. A Step 0 run where git cannot evaluate the probe (not a work tree, a broken repository): exit `128`.

**Out-of-scope synthetic extremes** — declined explicitly:

1. Raw captures already tracked in the index (a separate disposition, next planning).
2. An adopter's own negation rules re-including raw captures, or patterns scoped by stem rather than extension.
3. Non-canonical extension case (`.TXT`) and `core.ignorecase` interactions.
4. Version-control systems other than git; bare repositories.

<!-- END intent-block: T-1158 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Probe in Step 0 after `--print`, via git's ignore resolution on `.txt`/`.jsonl`/`.json` probe paths under the resolved reviews dir (Goal) | **AC1** |
| 2 | Root-level ignore counts; non-existent probe paths work (Goal) | **AC3** (git-behaviour fixture) |
| 3 | One-line warning naming the adopting.md paragraph; writes no file (Goal) | **AC2** ("one line" itself: info-only (not promoted to AC) — line count of a printed message is judged by review, not by a grep of prose) |
| 4 | Exit `128` never read as ignored, reported on its own line (Goal) | **AC3** |
| 5 | Never-staged sentence naming `<task-id>.md` and the three raw extensions (Goal) | **AC4** |
| 6 | No other file changes; no `team-init` change (Non-goals) | **AC5** |
| 7 | Prompt-block sync and reading suites stay green (Summarized sources, registry) | **AC6** |
| 8 | Declarations conformant | **AC7** |
| 9 | No tracked-raw disposition / `git rm --cached` (Non-goals) | info-only (not promoted to AC) — an action not taken leaves no observable beyond **AC5** |
| 10 | Sweep deferred to release (Non-goals) | info-only (not promoted to AC) — process deviation under mode A2 |

## Shipped-docs inventory

| Shipped document | Disposition | Ground |
|---|---|---|
| `skills/run/SKILL.md` | this-task | The deliverable (**AC1**–**AC4**). |
| `docs/adopting.md:42`–`:52` | unchanged | Already the migration step; the warning names it. |
| `docs/adopting.ja.md:~50` | unchanged | Same paragraph in Japanese; still true. |
| `README.md:86`, `README.ja.md:86` | unchanged | State what the v2.7.5 `<base>/.gitignore` ignores; still true. |

No `- shipped-docs:` line is written for the unchanged documents: the checker's disposition vocabulary is `this-task` / `issue #<N>` only, and neither describes a document that stays true and needs no follow-up.

## Blast radius

`- verification-class: mechanism`; the only edited shipped path is `skills/run/SKILL.md`. Read-set of merged criteria naming it, derived at run time:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*skills/run/SKILL\.md' -- .shell-team/specs

**Indirection class:** a merged criterion reaching SKILL.md through a run-time path is disclosed, not measured here. **Disclosed deviation:** the full-population two-arm inventory is deferred to the release sweep under the operator's standing mode-A2 ruling. **Adopter-side artifacts:** an already-installed stale `<base>/.gitignore` is exactly what the warning surfaces; raw captures already committed stay tracked (out of scope).

## Review depth

- **The two SKILL.md sentences** get full depth: does the probe resolve the reviews dir rather than hardcode it, does it read-only, does `128` stay distinct from ignored, does the warning name the right paragraph, does the never-staged sentence sit where the commit-records discipline would otherwise stage a raw.
- **This spec's own inline `- check:` lines** are reviewed for computed values, conclusion direction and material instrument defects only; their adversarial completeness is not a Major (operator ruling for dev-scaffold inline checks).

## Version derivation note

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| issue #622 existing adopter warned; raws never staged | not met | met | PATCH | Nothing new becomes possible; a stale-gitignore run stops leaking on the default path. |

## Assumptions

- **Relayed:** issue #622's body, via the coordinating session (primary: the coordinating session).
- **Relayed:** the branch is cut from `develop` at `0b229093` and no predecessor PR is open. The freeze run reports `git rev-parse HEAD`, `git merge-base develop HEAD` and `git status --short`.
- **Relayed premise measured false:** the Routing Map said `skills/run/SKILL.md` is not a prompt-block sync target. `templates/prompt-blocks/registry.txt:35`–`:57` lists it as a `contain`-mode consumer of fourteen blocks, including `operating-paths-core.md` inside Step 0 itself. Consequence carried into **AC6** (`bin/check-prompt-sync.sh` must stay green) and the Notes. This is a hand-off finding for the coordinating session's interventions record.
- **Borrowed count premises** (read by this role in the working tree at `0b229093`; the freeze run re-measures at `$B` and records the value here):

| Token | Class | Value read now | Command at the base |
|---|---|---|---|
| `git check-ignore` in `skills/run/SKILL.md` | borrowed (git vocabulary) | **0** | `git show "$B:skills/run/SKILL.md" \| grep -cF 'git check-ignore'` |
| `never staged` in `skills/run/SKILL.md` | borrowed (issue #622 wording) | **0** | `git show "$B:skills/run/SKILL.md" \| grep -cF 'never staged'` |
| line `**Upgrading an existing adopter repository.**` in `docs/adopting.md` | borrowed | **1** (`:42`) | `git show "$B:docs/adopting.md" \| grep -c '^\*\*Upgrading an existing adopter repository\.\*\*'` |
| `Because **the Bash-less agents` in `skills/run/SKILL.md` | borrowed | **1** (`:20`) | `git show "$B:skills/run/SKILL.md" \| grep -cF 'Because **the Bash-less agents'` |

(`\|` is markdown escaping for `|`.)

**Measured at the freeze (coordinating session, 2026-09-29, `$B` = `0b229093`):** `git check-ignore` 0, `never staged` 0, `**Upgrading an existing adopter repository.**` line 1, `Because **the Bash-less agents` 1 — each equals the value read above.

## Open questions

None blocking.

## Notes for engineer

- **Files touched:** `skills/run/SKILL.md` only (plus this task's records). Keep the `operating-paths-core.md` fragment in Step 0 byte-identical and do not edit inside any other `contain`-registered block's bytes — run `bash bin/check-prompt-sync.sh`.
- **Probe placement:** inside the Step-0 region (before the `Because **the Bash-less agents` paragraph), after the `--print` sentence. Derive the probe path from the resolved reviews dir; a non-existent probe name is enough for `git check-ignore`. Distinguish `0` (ignored), `1` (not ignored → warning) and `128` (cannot evaluate → its own line, never treated as ignored).
- **Never-staged sentence:** placement is your call — near the reviewer-record / "commit records immediately" discipline is where it closes the leak.
- **Measured-at-ref command check:** not applicable — no deliverable prints a command labelled as measured at a git ref.
