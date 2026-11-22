# The full-population downstream-impact diff is owed by default and skipped only where the loop contract declares that CI runs the test suites

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1200

## Problem

`agents/pm-spec.md` (`## Spec completion self-check`, the **Downstream-impact inventory method** item at `:87` and the `mechanism` sentence of the **Verification pricing by deliverable class** item at `:92`) and `docs/adopting.md` / `docs/adopting.ja.md` (`## Pricing a spec's verification by task class`) tell every `mechanism`-class task to inventory its effect on already-merged specs by a full-population diff: run every merged spec's criteria at the base ref and at HEAD and difference the verdicts. This repository measured that practice at release time and stopped running it there (relayed figures in Assumptions); the shipped default was never changed, so every adopter's mechanism task still owes a multi-hour diff whose recorded yield here was no functional regression. The self-check item also states the diff as something to run, in a checklist the role that holds no shell works through before any implementation HEAD exists. Issue #216 asks for a default that does not require the diff where it buys nothing, a self-check item `pm-spec` can satisfy as a property of spec text, and a measurement of the effect. The operator's condition, settled and quoted verbatim: "the full-population diff is default-off **only where the adopter repository's CI runs its test suites**; elsewhere the current default stays; where skipped, the task's record states that it was skipped and why."

## Summarized sources

- **Issue #216 body** — relayed by the coordinating session (this role cannot open the tracker; labelled relayed in Assumptions). Distinctions carried over: the shipped default (not only this repository's practice) stops requiring the diff; the replacement is the task's own check lines plus CI, or an opt-in; the change is stated in `agents/pm-spec.md` and in `docs/adopting.md` EN and JA; the self-check item becomes a spec-text property with execution assigned to a role that can execute; the effect is measured. Restated by the Goal, D1–D6, **AC1**, **AC2**, **AC4** and `## Measurement`.
- **The operator condition** (quoted in Problem, relayed verbatim, settled). Distinctions carried over: (i) skipping is conditional on the adopter repository's CI running its test suites, not on CI existing; (ii) everywhere else the current default (diff owed) stays; (iii) a skip is recorded in the task's record together with its reason. Restated by D1, D2, D3, **AC1**, **AC2**, **AC4**, **AC5**.
- **`agents/pm-spec.md:87`** (read in full): the method item says the inventory "is taken as a **full-population diff**: enumerate the whole population of merged specs, run each one's criteria at the base ref and again at HEAD, and difference the two verdict sets" — imperative execution wording — rejects a grep-of-mentions inventory, and carries the runs-corpus staging sentence. Restated by D4, **AC1** and **AC3**.
- **`agents/pm-spec.md:92`** (read in full): `mechanism` is the default for any diff reaching `bin/`, `tests/`, `templates/`, a CI workflow or a checker's semantics, "and for that class nothing changes: every item above applies exactly as written, including the **Downstream-impact inventory method** item, which **governs unchanged** there"; `no-mechanism` gets a read-set-scoped inventory; this item decides **whether** a full inventory is owed and the method item decides **how**. Restated by D4, D5 and **AC3**.
- **Merged criteria that pin `agents/pm-spec.md` and `skills/run/SKILL.md` bytes** (each check line read by this role; liveness judged by reading what it resolves as its base):
  - T-1053 **AC2** (`:93`, `SING` in `skills/run/SKILL.md`) and **AC3** (`:95`, `BLAST` = the `:87` line, whole-line): base `git merge-base develop HEAD`, and each requires the base blob to carry its sentence **zero** times. The sentences are on `develop`, so both are red at today's base whatever this task does.
  - T-1065 **AC1**–**AC11** (`:100`–`:122`, `TIER` = the `:92` line, `BRIEF` in step 6): each opens with `git rev-parse --verify --quiet chore/lesson-promotion-2026-08-13` `|| exit 1`; that ref is absent from `.git/refs/heads/chore/` and `.git/packed-refs` in this checkout, so each exits `1` before reading anything.
  - T-1108 **AC1** (`:63`): base `feature/1107-close-out-gates` if present (absent here), else `git merge-base develop HEAD`; requires the base `:87` line to carry **none** of seven staging literals it already carries at `develop`, so red at today's base. Its HEAD side requires the `:87` line to carry those seven literals and `full-population diff`, `bin/team-paths.sh --get todo` and `committed blobs`.
  - T-1108 **AC2** (`:66`): the span from the first `<!-- BEGIN prompt-block:` line to end of file is byte-identical base vs HEAD, and `check-prompt-sync.sh` exits `0`. Live.
  - T-1108 **AC3** (`:69`): with the single `- **Downstream-impact inventory method (forward-only)**:` line removed from both sides, base and HEAD `agents/pm-spec.md` are byte-identical with equal line counts. Live: green when only that one line changes, red when any other line of the file is added, removed or changed.

  Restated by D4, **AC1** and **AC3**.
- **`bin/check-spec-review.sh:171-193`**: reads `budget.max_spec_review_rounds` from a contract passed with `--contract`, scoped to the first `budget:` section with the same semantics as `loop-guard.sh`'s reader; `tests/check-spec-review/run.sh:385` runs it against this repository's own contract, and `tests/check-contract/run.sh:114` lints that contract. Restated by `## Blast radius` (reached CI steps).
- **`skills/run/SKILL.md:66`** (the `attestation` branch of step 2, read in full): the freeze sweep runs every `check:` line against the pre-implementation tree and reasons each clause against the post-implementation tree state; it carries T-1053's `POST` and `SING` sentences. Restated by D3 and **AC2**, **AC3**.
- **`skills/run/SKILL.md:126`** (step 6, read in full): the review briefing states verdict scope and severity calibration; a calibrated-class finding is recorded at the reviewer's severity and treated as non-gating; a `no-mechanism` spec's briefing names what that class rules out. Carries T-1065's `BRIEF` text. Restated by D3 and **AC2**, **AC3**.
- **`skills/run/SKILL.md:117`, `:284`, `:338`**: a full-population blast-radius sweep is mechanically enumerable verification work, run in a phase's own verification by the within-phase fan-out step and recorded on the `verify-mechanism` dispatch axis. Restated by D3 (where an owed diff runs).
- **`bin/check-contract.sh:1-79`**: requires the six top-level elements `trigger scope action budget stop report` plus `owner` and `evidence`; a section body ends at the next column-0 non-comment line; exit `0` clean, `1` violations, `2` unreadable. It names no rule against an additional top-level key. Restated by **AC8**.
- **`bin/loop-guard.sh:1-57`, `:135-151`**: reads `budget`/`stop` values by section name; exit `0` with stdout `CONTINUE`, `3` STOP, `2` `STOP:guard_error`. Restated by **AC8**.
- **`bin/check-setup.sh:229-249`** and **`bin/team-setup.sh:551`**: an adopter contract that differs from both the installed template and the prior-release template yields a note ("differs from the installed plugin's template"), never a change of exit status. Restated by D6 and **AC4** (`check-setup.sh` named in the docs).
- **`.shell-team/loops/shell-team.contract.yaml`** (read in full): carries no `verification:` section today. Restated by **AC6**.
- **`.github/workflows/check-handoff.yml`** (read in full): `on: pull_request` and `push` for `main`/`develop`; runs each suite as a step of the form `run: bash tests/<suite>/run.sh`. Restated by **AC7**.
- **`bin/check-adopter-docs.sh:1-40`**: reads the declaration region only; each `this-task` shipped-docs path must appear literally in a `- check:` or `- adopter-surface:` line. Restated by **AC9**.
- **`README.md:248`, `README.ja.md:248`, `CONTRIBUTING.md:132`, `agents/qa-verifier.md:175`, `agents/engineer.md:157`, `agents/tech-lead.md:96`** (read): each mentions a full-population diff only conditionally (a dispatch refinement used "when" a task's duty bundles one; a job launched "when a spec calls for" one; a maintainer's release-level sweep). Dispositions in `## Shipped-docs inventory`. Restated by **AC10** (none of them is in the allow-list).

## Goal

<!-- BEGIN intent-block: T-1200 -->

- user-visible: yes — an adopter can declare, in its loop contract, that its own CI runs its test suites; a mechanism-class task in that repository then no longer owes the full-population downstream-impact diff on the default path, and its spec records the skip and why. Without the declaration nothing changes.
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- verification-class: no-mechanism — the diff edits agent and skill prose, the two adopting guides and this repository's own loop contract (a data file whose new section no script reads); it touches no path under `bin/`, `tests/`, `templates/` or `.github/` and no checker's semantics. Because it edits the verification norms themselves, the norm-editing obligation applies (read set in `## Blast radius`).
- verification-ceiling: unit-and-static — **AC1**–**AC10** read the post-implementation tree, the commit range and the exit codes of `check-contract.sh`, `loop-guard.sh`, `check-prompt-sync.sh`, `check-adopter-docs.sh` and `check-handoff.sh` in a plain checkout. **AC11** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: not-applicable — the branch has no open predecessor; it was cut from `develop`, and every base-side read uses `develop` (local branch, else `refs/remotes/origin/develop`) through `git merge-base`.

**Goal (one sentence).** A `mechanism`-class task owes the full-population downstream-impact diff unless the repository's loop contract carries the exact declaration `ci_runs_test_suites: yes` with a non-empty `ci_suite_workflows` evidence field, in which case the spec records the skip, the declaration and its evidence in `## Blast radius`; `agents/pm-spec.md`, `skills/run/SKILL.md` and the adopting guides (EN and JA) say so, and this repository's own contract carries the declaration.

**Decisions frozen here** (each promoted to a criterion or exempted in the correspondence table):

- **D1 — the declaration.** An optional top-level section of the loop contract resolved through `bin/team-paths.sh --get loops` (`<loops>/shell-team.contract.yaml`):

  ```yaml
  verification:
    ci_runs_test_suites: yes
    ci_suite_workflows: .github/workflows/check-handoff.yml
  ```

  `ci_suite_workflows` names, on one line, one or more repository-relative paths of the CI workflow files that run the test suites, separated by spaces. It is a declaration, not a detection: nothing verifies that the named workflows run the suites, and the docs say so.
- **D2 — fail closed by construction.** The diff is skipped only when all of these hold: the contract at the resolved path is readable; it carries exactly one top-level `verification:` line; that section carries exactly one `ci_runs_test_suites:` key whose value, with any trailing `# comment` and surrounding whitespace removed, is exactly `yes`; and it carries exactly one non-empty `ci_suite_workflows:` key. In every other case — section absent, value `no`, `true`, `Yes`, `"yes"` or empty, key misspelled or duplicated, evidence missing or empty, contract unreadable — the diff is owed. No new validator is added and `bin/check-contract.sh` is not changed.
- **D3 — the record and who acts.** Forward-only: every `mechanism`-class spec frozen from this task on carries, in its `## Blast radius` section, exactly one decision line, written by the spec's author (`pm-spec` in `pm-authored` mode) from reading the contract:
  - `- full-population-diff: skipped — contract: <path> — ci_runs_test_suites: yes — evidence: <ci_suite_workflows value>`, or
  - `- full-population-diff: owed — population: <the command that enumerates the merged specs> — run by: coordinating session, against the post-implementation HEAD`.

  At the freeze sweep the coordinating session re-reads the contract and confirms the line matches it (a mismatch routes back to `pm-spec` like a broken check line). When owed, the coordinating session runs the diff once HEAD carries the implementation, inside the task's verification (the existing within-phase fan-out home), and records the verdict difference in `## Blast radius`. `pm-spec` runs nothing. The review briefing names a recorded skip as the price the freeze set, so the absent diff is non-gating, while an owed diff with no recorded result stays gating. No new board line family is introduced; no checker parses `## Blast radius`.
- **D4 — the self-check item becomes a spec-text property, rewritten in place.** The **Downstream-impact inventory method** item (`agents/pm-spec.md:87`) is rewritten as one physical line keeping its opening `- **Downstream-impact inventory method (forward-only)**:`:
  - `pm-spec`'s duty is spec text it can satisfy without a shell: from the contract, the spec states whether the diff is owed (D2) and writes the D3 decision line; when owed, it names the population command and that the coordinating session runs the diff against the post-implementation HEAD; `pm-spec` executes nothing;
  - when owed, the existing method text stays the "how" (the full-population diff, why a grep-of-mentions inventory is not a substitute, the base side read from committed blobs, the runs-corpus staging sentence verbatim);
  - it carries the fail-closed anchor `otherwise the diff stays owed`.

  Every other line of `agents/pm-spec.md`, `:92` included, stays byte-identical: the merged T-1108 **AC3** is live and goes red if any other line changes, and `:92`'s "governs unchanged" still holds because the item it points at now carries the condition. In `skills/run/SKILL.md` the change is made by **adding** lines only; every base line survives verbatim.
- **D5 — scope of the decision.** It governs `mechanism`-class specs only. The `no-mechanism` read-set duty, the trivial path (no freeze sweep) and the release-level sweep `CONTRIBUTING.md` describes are unchanged.
- **D6 — adopter-facing documentation.** Both adopting guides, inside the existing `## Pricing a spec's verification by task class` / `## タスククラスによる検証の価格付け` section and adding no `## ` heading, state D1–D3 with the same machine tokens, carry the fail-closed anchor (EN `otherwise the diff stays owed`, JA `それ以外では diff は owed のまま`), say that nothing verifies the declaration, and say that `check-setup.sh` will report a contract carrying the section as differing from the installed template (a note that does not change its exit status).

**Pre-commitment (frozen before round 1).** AI self-discipline proposed by the coordinating session, never operator-ratified.

- **Never-dropped.** The first defeat of either stops the task and returns it to planning.
  - (N1) The fail-closed default (D2; **AC1**, **AC2**, **AC4**, **AC5**).
  - (N2) The skip record (D3; **AC1**, **AC2**, **AC4**, **AC5**).
- **Droppable, first.** This repository's own `yes` declaration (**AC6**, **AC7**). If the suite-coverage criterion cannot be made true, the declaration is dropped from this task to a follow-up issue, the finding travelling into that issue's body; the shipped mechanism stays.
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same component. A round interrupted before a verdict does not count.

## Non-goals

- **No detection.** Nothing inspects CI files to decide whether the diff is owed; the contract declaration is the only input. (info-only; D1)
- **No `bin/`, `templates/`, `tests/` or `.github/` edit.** In particular `templates/shell-team.contract.yaml` is unchanged, so no adopter receives a drift notice from this task, and `bin/check-contract.sh` is unchanged. (**AC10**)
- **No change to setup.** `bin/team-setup.sh` / `bin/check-setup.sh` do not surface the new key; that is a follow-up issue (Open questions). (**AC10**)
- **No change to the `no-mechanism` read-set duty, the trivial path, or the release-level sweep wording.** (**AC3** for the pinned lines; **AC10**)
- **No change to any line of `agents/pm-spec.md` other than the method item, and no removal or rewording of any existing line of `skills/run/SKILL.md`.** (**AC3**)
- **No new board line family and no new checker.** (**AC10**)
- **No full-population two-arm sweep, no whole CI-equivalent re-run and no behaviour verification of a mechanism this task does not touch.** The class is `no-mechanism`; every criterion is a string presence or absence read, a byte-scoped diff, a checker's exit code, or a records-line existence check. (info-only; Blast radius)
- **No in-task measurement of the effect.** The measurement is post-release (`## Measurement`). (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Temporary files go under `$TMPDIR` and are left there.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **File existence first.** Every line that reads a file first asserts that the file is non-empty.
- **The base.** Where a line reads a base blob, `<base>` is `git merge-base` of `develop` (local branch, else `refs/remotes/origin/develop`) and HEAD, spelled identically in **AC3**, **AC4** and **AC10**. All three are **merge-point-scoped and expected to go stale** after merge; do not widen the base.

- [ ] **AC1** (D2; D3; D4; N1; N2.) The rewritten method item in `agents/pm-spec.md`:
  - exactly one line of the file contains `- **Downstream-impact inventory method (forward-only)**:`, and that line sits inside `## Spec completion self-check`;
  - it contains the new tokens `full-population-diff: skipped`, `full-population-diff: owed`, `ci_runs_test_suites: yes`, `ci_suite_workflows`, `shell-team.contract.yaml`, `## Blast radius`, `coordinating session`, `post-implementation HEAD` and `otherwise the diff stays owed`;
  - it keeps the method text's phrases `full-population diff`, `bin/team-paths.sh --get todo`, `committed blobs`, `snapshot of the runs corpus`, `once per sweep`, `before either arm runs`, `a real directory, never a symlink`, `bin/team-paths.sh --get runs`, `TEAM_RUNS_DIR` and `leaves every tracked member at its base-ref bytes`;
  - no other line of the file contains `full-population-diff: skipped`.

  That the item no longer states the diff as something `pm-spec` runs, states every D2 fail-closed case, and keeps the method as the "how" when owed is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; A=agents/pm-spec.md; M='- **Downstream-impact inventory method (forward-only)**:'; test -s "$A" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac1.XXXXXX") || exit 1; test "$(grep -cxF -- '## Spec completion self-check' "$A")" = 1 || exit 1; awk '/^## Spec completion self-check$/{f=1;next} f&&/^## /{exit} f' "$A" > "$T/sec" || exit 1; test -s "$T/sec" || exit 1; test "$(grep -cF -- "$M" "$A")" = 1 || { echo 'method item count is not 1'; exit 1; }; grep -F -- "$M" "$T/sec" > "$T/l"; test -s "$T/l" || { echo 'method item outside the section'; exit 1; }; for s in 'full-population-diff: skipped' 'full-population-diff: owed' 'ci_runs_test_suites: yes' 'ci_suite_workflows' 'shell-team.contract.yaml' '## Blast radius' 'coordinating session' 'post-implementation HEAD' 'otherwise the diff stays owed' 'full-population diff' 'bin/team-paths.sh --get todo' 'committed blobs' 'snapshot of the runs corpus' 'once per sweep' 'before either arm runs' 'a real directory, never a symlink' 'bin/team-paths.sh --get runs' 'TEAM_RUNS_DIR' 'leaves every tracked member at its base-ref bytes'; do grep -qF -- "$s" "$T/l" || { rc=1; printf 'missing %s\n' "$s"; }; done; w=$(grep -cF -- 'full-population-diff: skipped' "$A"); test "$w" = 1 || { rc=1; printf 'file lines with the skip token: %s\n' "$w"; }; test "$rc" -eq 0

- [ ] **AC2** (D3; N1; N2.) `skills/run/SKILL.md` carries both run-skill halves as added lines:
  - in step 2 (from the `2. **Specify**` line to the next numbered step line), a line containing `full-population-diff: skipped`, `full-population-diff: owed`, `ci_runs_test_suites: yes`, `otherwise the diff stays owed` and `post-implementation HEAD`;
  - in step 6 (from the `6. **Review**` line to the `7. **Done**` line), a line containing `full-population-diff: skipped`, `full-population-diff: owed`, `ci_runs_test_suites: yes`, `otherwise the diff stays owed` and `non-gating`.

  That the step-6 line leaves the reviewer's independence over findings intact (it scopes the verdict, never asks to withhold a finding) is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; K=skills/run/SKILL.md; test -s "$K" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac2.XXXXXX") || exit 1; test "$(grep -c '^2\. \*\*Specify\*\*' "$K")" = 1 || exit 1; test "$(grep -c '^6\. \*\*Review\*\*' "$K")" = 1 || exit 1; test "$(grep -c '^7\. \*\*Done\*\*' "$K")" = 1 || exit 1; awk '/^2\. \*\*Specify\*\*/{f=1;next} f&&/^[0-9]\. /{exit} f' "$K" > "$T/s2" || exit 1; awk '/^6\. \*\*Review\*\*/{f=1;next} f&&/^7\. \*\*Done\*\*/{exit} f' "$K" > "$T/s6" || exit 1; test -s "$T/s2" || exit 1; test -s "$T/s6" || exit 1; hit() { awk -v a="$2" -v b="$3" -v c="$4" -v d="$5" -v e="$6" 'index($0,a)&&index($0,b)&&index($0,c)&&index($0,d)&&index($0,e){n++} END{exit (n>=1)?0:1}' "$1"; }; hit "$T/s2" 'full-population-diff: skipped' 'full-population-diff: owed' 'ci_runs_test_suites: yes' 'otherwise the diff stays owed' 'post-implementation HEAD' || { rc=1; echo 'step 2 line missing'; }; hit "$T/s6" 'full-population-diff: skipped' 'full-population-diff: owed' 'ci_runs_test_suites: yes' 'otherwise the diff stays owed' 'non-gating' || { rc=1; echo 'step 6 line missing'; }; test "$rc" -eq 0

- [ ] **AC3** (D4; D5.) Nothing else moves in the two prompt files.
  - `agents/pm-spec.md`: with every line containing `- **Downstream-impact inventory method (forward-only)**:` removed from both the `<base>` blob and the working file, the two are byte-identical, and the two unreduced files have the same line count (the same property the merged T-1108 **AC3** asserts, so it stays green).
  - `skills/run/SKILL.md`: every line of the `<base>` blob occurs verbatim as a whole line in the working file (lines are only added).
  - `bash bin/check-prompt-sync.sh` exits `0`, so no generated prompt block moved.
  - **Positive control.** `<base>` resolves to a commit, both base blobs and both reduced files are non-empty.
  - check: rc=0; export LC_ALL=C; M='- **Downstream-impact inventory method (forward-only)**:'; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac3.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; P=agents/pm-spec.md; test -s "$P" || exit 1; git show "$B:$P" > "$T/pb" || exit 1; test -s "$T/pb" || exit 1; grep -vF -- "$M" "$T/pb" > "$T/pbr"; grep -vF -- "$M" "$P" > "$T/phr"; test -s "$T/pbr" || exit 1; test -s "$T/phr" || exit 1; cmp -s "$T/pbr" "$T/phr" || { rc=1; echo 'agents/pm-spec.md changed outside the method item'; }; test "$(grep -c '' "$T/pb")" = "$(grep -c '' "$P")" || { rc=1; echo 'agents/pm-spec.md line count changed'; }; K=skills/run/SKILL.md; test -s "$K" || exit 1; git show "$B:$K" > "$T/kb" || exit 1; test -s "$T/kb" || exit 1; grep -vxFf "$K" "$T/kb" > "$T/gone"; r=$?; test "$r" = 1 || { rc=1; printf 'base line removed or altered in %s (grep rc %s)\n' "$K" "$r"; }; test -s bin/check-prompt-sync.sh || exit 1; bash bin/check-prompt-sync.sh > "$T/ps" 2>&1 || { rc=1; cat "$T/ps"; }; test "$rc" -eq 0

- [ ] **AC4** (D1; D2; D3; D6; N1; N2.) Adopter-facing documentation lands in both guides. `docs/adopting.md` carries `## Pricing a spec's verification by task class` once and `docs/adopting.ja.md` carries `## タスククラスによる検証の価格付け` once. Each section, read from its heading to the next `## ` line, contains `verification:`, `ci_runs_test_suites: yes`, `ci_suite_workflows`, `full-population-diff: skipped`, `full-population-diff: owed`, `shell-team.contract.yaml`, `## Blast radius` and `check-setup.sh`; the EN section contains `nothing verifies this declaration` and `otherwise the diff stays owed`, and the JA section contains `この宣言を検証するものはない` and `それ以外では diff は owed のまま`. Each file's count of `^## ` lines equals its count at `<base>`, and the two counts are equal. That the EN and JA sections state the same conditions (every D2 case, D5's scope) is a QA and review reading item.
  - adopter-surface: docs/adopting.md and docs/adopting.ja.md, inside `## Pricing a spec's verification by task class` (`## タスククラスによる検証の価格付け`): the `verification:` contract section, the exact-`yes` fail-closed rule, the skip and owed record lines in `## Blast radius`, that nothing verifies the declaration, and the `check-setup.sh` template-difference note.
  - check: rc=0; export LC_ALL=C; A=docs/adopting.md; J=docs/adopting.ja.md; HA="## Pricing a spec's verification by task class"; HJ='## タスククラスによる検証の価格付け'; test -s "$A" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac4.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; test "$(grep -cxF -- "$HA" "$A")" = 1 || rc=1; test "$(grep -cxF -- "$HJ" "$J")" = 1 || rc=1; awk -v h="$HA" '$0==h{f=1;next} f&&/^## /{exit} f' "$A" > "$T/en" || exit 1; awk -v h="$HJ" '$0==h{f=1;next} f&&/^## /{exit} f' "$J" > "$T/ja" || exit 1; test -s "$T/en" || exit 1; test -s "$T/ja" || exit 1; for n in en ja; do for s in 'verification:' 'ci_runs_test_suites: yes' 'ci_suite_workflows' 'full-population-diff: skipped' 'full-population-diff: owed' 'shell-team.contract.yaml' '## Blast radius' 'check-setup.sh'; do grep -qF -- "$s" "$T/$n" || { rc=1; printf '%s section missing %s\n' "$n" "$s"; }; done; done; grep -qF -- 'nothing verifies this declaration' "$T/en" || { rc=1; echo 'EN honesty anchor missing'; }; grep -qF -- 'otherwise the diff stays owed' "$T/en" || { rc=1; echo 'EN fail-closed anchor missing'; }; grep -qF -- 'この宣言を検証するものはない' "$T/ja" || { rc=1; echo 'JA honesty anchor missing'; }; grep -qF -- 'それ以外では diff は owed のまま' "$T/ja" || { rc=1; echo 'JA fail-closed anchor missing'; }; for F in "$A" "$J"; do git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; test "$(grep -c '^## ' "$T/b")" = "$(grep -c '^## ' "$F")" || { rc=1; printf 'heading count changed in %s\n' "$F"; }; done; test "$(grep -c '^## ' "$A")" = "$(grep -c '^## ' "$J")" || { rc=1; echo 'EN and JA heading counts differ'; }; test "$rc" -eq 0

- [ ] **AC5** (Negative; D2; N1; N2.) No edited surface states the skip without its fail-closed condition. The record form `full-population-diff: skipped — … — ci_runs_test_suites: yes — …` already contains the declaration value, so the partner asserted here is the fail-closed anchor, which the record form does not contain: EN `otherwise the diff stays owed`, JA `それ以外では diff は owed のまま`.
  - In `agents/pm-spec.md` and `skills/run/SKILL.md`, every line containing `full-population-diff: skipped` also contains `ci_runs_test_suites: yes` and the EN anchor.
  - In `docs/adopting.md` (EN anchor) and `docs/adopting.ja.md` (JA anchor), every blank-line-separated paragraph containing `full-population-diff: skipped` also contains `ci_runs_test_suites: yes` and the file's anchor.
  - **Positive control.** Each of the four files carries at least one such line or paragraph.

  That no prose elsewhere in these files calls the diff off, skipped or default-off without the declaration is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; K='full-population-diff: skipped'; Q='ci_runs_test_suites: yes'; E='otherwise the diff stays owed'; JA='それ以外では diff は owed のまま'; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac5.XXXXXX") || exit 1; for F in agents/pm-spec.md skills/run/SKILL.md; do test -s "$F" || exit 1; grep -F -- "$K" "$F" > "$T/k"; test -s "$T/k" || { rc=1; printf 'no skip line in %s\n' "$F"; }; awk -v q="$Q" -v e="$E" '!(index($0,q)&&index($0,e))' "$T/k" > "$T/bad" || exit 1; test ! -s "$T/bad" || { rc=1; printf 'unconditioned skip line in %s\n' "$F"; }; done; for p in "docs/adopting.md|$E" "docs/adopting.ja.md|$JA"; do F=${p%%|*}; X=${p#*|}; test -s "$F" || exit 1; awk -v RS= -v k="$K" -v q="$Q" -v x="$X" 'index($0,k){n++; if(!(index($0,q)&&index($0,x))){bad++}} END{if(n<1){print "no skip paragraph"; exit 1} if(bad>0){print "unconditioned skip paragraphs: " bad; exit 1} exit 0}' "$F" || { rc=1; printf 'in %s\n' "$F"; }; done; test "$rc" -eq 0

- [ ] **AC6** (D1; droppable first.) This repository's own loop contract, resolved through `bin/team-paths.sh --get loops`, declares the CI: exactly one top-level `verification:` line; in that section exactly one `ci_runs_test_suites:` key whose value (trailing `# comment` and whitespace removed) is exactly `yes`; exactly one `ci_suite_workflows:` key whose value is non-empty, includes `.github/workflows/check-handoff.yml`, and names only files that exist and are non-empty.
  - check: rc=0; export LC_ALL=C; L=$(bash bin/team-paths.sh --get loops) || exit 1; C="$L/shell-team.contract.yaml"; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac6.XXXXXX") || exit 1; test "$(grep -c '^verification:' "$C")" = 1 || { echo 'verification section count is not 1'; exit 1; }; awk '/^verification:/{f=1;next} f&&/^[^[:space:]#]/{f=0} f' "$C" > "$T/sec" || exit 1; test -s "$T/sec" || exit 1; val() { awk -v k="$1" 'match($0, "^[[:space:]]+" k ":[[:space:]]*"){v=substr($0,RLENGTH+1); sub(/[[:space:]]*#.*$/,"",v); sub(/[[:space:]]+$/,"",v); n++; out=v} END{if(n!=1) exit 1; print out}' "$T/sec"; }; v=$(val ci_runs_test_suites) || { rc=1; echo 'ci_runs_test_suites count is not 1'; }; test "$v" = yes || { rc=1; printf 'value is [%s]\n' "$v"; }; w=$(val ci_suite_workflows) || { rc=1; echo 'ci_suite_workflows count is not 1'; }; test -n "$w" || { rc=1; echo 'empty evidence'; }; case " $w " in *' .github/workflows/check-handoff.yml '*) ;; *) rc=1; echo 'check-handoff.yml not named';; esac; for p in $w; do test -s "$p" || { rc=1; printf 'evidence path missing: %s\n' "$p"; }; done; test "$rc" -eq 0

- [ ] **AC7** (Evidence for **AC6**; droppable first.) Every tracked `tests/*/run.sh` (one directory level, `:(glob)` pathspec) appears in `.github/workflows/check-handoff.yml` as a whole step line `run: bash tests/<suite>/run.sh` once leading and trailing whitespace is removed; missing suites are printed. **Positive control.** The suite list is non-empty. The population is re-derived at run time and compared with nothing declared, so it needs no `stale-at` trigger; a suite added without a CI step turns this red, which is the property being asserted.
  - check: rc=0; export LC_ALL=C; W=.github/workflows/check-handoff.yml; test -s "$W" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac7.XXXXXX") || exit 1; git ls-files -- ':(glob)tests/*/run.sh' > "$T/s" || exit 1; test -s "$T/s" || exit 1; sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$W" > "$T/w" || exit 1; while IFS= read -r p; do grep -qxF -- "run: bash $p" "$T/w" || { rc=1; printf 'not run by CI: %s\n' "$p"; }; done < "$T/s"; test "$rc" -eq 0

- [ ] **AC8** (D1; D2.) The edited contract is still accepted by the two scripts that read it: `bash bin/check-contract.sh <contract>` exits `0`, and `bash bin/loop-guard.sh <contract> --iteration 0` exits `0` with stdout exactly `CONTINUE`. If either refuses the new section, that is an Open question for the coordinating session, never a silent `bin/` change (**AC10**).
  - check: rc=0; L=$(bash bin/team-paths.sh --get loops) || exit 1; C="$L/shell-team.contract.yaml"; test -s "$C" || exit 1; test -s bin/check-contract.sh || exit 1; test -s bin/loop-guard.sh || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac8.XXXXXX") || exit 1; bash bin/check-contract.sh "$C" > "$T/c" 2>&1 || { rc=1; cat "$T/c"; }; bash bin/loop-guard.sh "$C" --iteration 0 > "$T/g" 2> "$T/ge"; g=$?; test "$g" = 0 || { rc=1; printf 'loop-guard exit %s\n' "$g"; cat "$T/ge"; }; test "$(cat "$T/g")" = CONTINUE || { rc=1; cat "$T/g"; }; test "$rc" -eq 0

- [ ] **AC9** The records conform. `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams, and `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`. **Positive control.** The spec, the checker and the board are each asserted non-empty first.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac9.XXXXXX") || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1200-downstream-diff-default.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || { rc=1; cat "$T/e"; }; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || { rc=1; cat "$T/h"; }; test "$rc" -eq 0

- [ ] **AC10** Scope lock. **Merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed: `git diff --no-renames --name-only <base>...HEAD`; `git diff --no-renames --cached --name-only`; `git diff --no-renames --name-only`; `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `agents/pm-spec.md`.
  - **Allowed members.** `agents/pm-spec.md`, `skills/run/SKILL.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `.shell-team/loops/shell-team.contract.yaml`, and this task's records: `.shell-team/specs/T-1200-downstream-diff-default.md`, `.shell-team/provenance/T-1200.md`, `.shell-team/interventions/T-1200.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1200.md`, `.shell-team/reviews/T-1200-drift.md`, raw captures `.shell-team/reviews/T-1200-<stem>.{txt,jsonl,json}`, `.shell-team/todo.md` and `.shell-team/test-recipe.md`. Anything under `bin/`, `templates/`, `tests/`, `.github/`, any README, `CONTRIBUTING.md`, any other agent or skill file is outside.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1200-ac10.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF agents/pm-spec.md "$T/s" || { rc=1; echo 'positive control: agents/pm-spec.md not in the set'; }; grep -vxE 'agents/pm-spec\.md|skills/run/SKILL\.md|docs/adopting(\.ja)?\.md|\.shell-team/(loops/shell-team\.contract\.yaml|specs/T-1200-downstream-diff-default\.md|provenance/T-1200\.md|interventions/(T-1200|no-task)\.md|reviews/T-1200(-drift)?\.md|reviews/T-1200-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || { rc=1; cat "$T/bad"; }; test "$rc" -eq 0

- [ ] **AC11** CI on the pull request is green; the workflow runs every suite, the board dogfood steps and `check-pii-shapes on the PR diff` over the changed files.
  - above-ceiling: the coordinating session, after the push and before the sprint batch GO, records the check run's result on the board. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **Contract shapes an adopter or `team-init` produces.**
   - No `verification:` section at all (the shipped template and every existing adopter contract): diff owed.
   - A `verification:` section with `ci_runs_test_suites: yes` and one or more space-separated workflow paths: diff skipped.
   - Values other than the exact `yes` (`no`, `true`, `Yes`, `"yes"`, empty), a trailing `# comment` after the value, a missing or empty `ci_suite_workflows`, a misspelled key: diff owed (except the comment case, which is stripped).
   - The section placed before, between or after the eight required elements, with column-0 comments inside it.
2. **Where the contract lives.** The default layout (`.shell-team/loops/`), the legacy layout (`tasks/loops/`), and local record mode, where the contract is untracked but readable at the resolved path; a missing or unreadable contract: diff owed.
3. **Task classes.** `mechanism` (the decision applies), `no-mechanism` (read-set duty unchanged, the decision line not required), the trivial path (no freeze sweep; unchanged).
4. **Repositories.** This repository, whose workflow runs each suite as `run: bash tests/<suite>/run.sh`; an adopter with no `.github/workflows` (it cannot honestly declare, and an undeclared contract keeps the diff owed).
5. **The prose surfaces.** One-line bullets in `agents/pm-spec.md` and `skills/run/SKILL.md`; hard-wrapped paragraphs in `docs/adopting.md`; Japanese paragraphs in `docs/adopting.ja.md` with machine tokens in English.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **YAML forms the line-based reading does not recognise** — flow mappings (`verification: {ci_runs_test_suites: yes}`), anchors and aliases, a multi-line list for `ci_suite_workflows`, quoted keys. They are read as no declaration, so the diff stays owed; nothing beyond that fail-closed outcome is protected.
2. **Duplicate `verification:` sections or duplicate keys.** Read as no declaration (D2); not otherwise interpreted.
3. **A false declaration** — `yes` in a repository whose CI does not in fact run its suites. Nothing verifies the attestation; it is the operator's.
4. **A CRLF contract or a workflow file with CRLF line endings.**
5. **Suites nested deeper than `tests/<suite>/run.sh`, or a workflow that runs suites through a loop or a matrix** rather than one `run: bash tests/<suite>/run.sh` step each; **AC7** reads only the one-step-per-suite shape this repository uses.

<!-- END intent-block: T-1200 -->

## Verdict scope

- **Consumer.** Adopters (the docs and the new contract key), and every later spec author and coordinating session (the `pm-spec` item and the run-skill lines are shipped prompt text the loop executes by). Review depth is shipped-norm depth for the prose: consistency between the four surfaces, the fail-closed reading, and the scoping against the pinned lines.
- **What a check line proves.** Presence and co-occurrence of fixed tokens, that no base line of the two prompt files was lost, the contract's declaration shape, suite coverage in the workflow, and the exit codes of the named scripts. It never proves that the added prose says what D2–D5 require; that is a reading item for QA and review.
- **Briefing.** Every review briefing names the class `no-mechanism` and what it rules out (no full-population sweep, no whole CI-equivalent re-run, no behaviour verification of an unchanged mechanism).

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | The contract declaration shape (D1) | **AC4** (documented), **AC6** (this repository) |
| 2 | Nothing verifies the attestation; docs say so (D1, D6) | **AC4** (honesty anchors) |
| 3 | Fail closed: only exact `yes` plus non-empty evidence skips (D2) | **AC1**, **AC2**, **AC4** for the tokens, **AC5** for co-occurrence; each D2 case is a reading item |
| 4 | No new validator; `check-contract.sh` unchanged (D2) | **AC10** |
| 5 | Decision line in `## Blast radius`, skip and owed forms (D3) | **AC1**, **AC2**, **AC4** |
| 6 | Freeze sweep confirms the decision; owed diff run by the coordinating session against the post-implementation HEAD (D3) | **AC2** (step 2 line) |
| 7 | Review briefing: recorded skip non-gating, missing owed result gating (D3) | **AC2** (step 6 line); reviewer independence is a reading item |
| 8 | `pm-spec` runs nothing (D3) | info-only (not promoted to AC): an absence of activity; a reading item on **AC1**'s line |
| 9 | No new board line family; no checker parses `## Blast radius` (D3) | **AC10** (no `bin/` change); the parse absence was measured by this role (Assumptions) |
| 10 | Method item rewritten in place; every other `agents/pm-spec.md` line byte-identical; `skills/run/SKILL.md` additive (D4) | **AC1**, **AC3** |
| 11 | The method item is a spec-text property, keeps the method as the "how" when owed, keeps the staging sentence (D4) | **AC1** for the kept phrases; the reframing is a reading item |
| 12 | Scope: mechanism only; read-set, trivial path, release sweep unchanged (D5) | **AC3**, **AC10**; the scope sentence is a reading item |
| 13 | Docs in both guides, same section, no new heading, same tokens, `check-setup.sh` note (D6) | **AC4** |
| 14 | EN/JA parity of the conditions | **AC4** for tokens; meaning parity is a reading item |
| 15 | No document says off without the declaration (operator condition) | **AC5** |
| 16 | This repository declares, with evidence (design (a)) | **AC6**, **AC7** |
| 17 | The edited contract still accepted by `check-contract.sh` and `loop-guard.sh` | **AC8** |
| 18 | No `bin/`, `templates/`, `tests/`, `.github/` edit; no setup change (Non-goals) | **AC10** |
| 19 | No detection (Non-goals) | info-only (not promoted to AC): an absence of a mechanism; **AC10** keeps `bin/` unchanged |
| 20 | No full sweep, no whole CI re-run (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 21 | Post-release measurement (Non-goals, `## Measurement`) | info-only (not promoted to AC): the effect occurs only after release in an adopter repository |
| 22 | Pre-commitment | info-only (not promoted to AC): a disposition, not a deliverable property |
| 23 | The records conform | **AC9** |
| 24 | CI green | **AC11** (above ceiling) |

## Symmetry table

Marks: `present` (already true at base), `mirrored-now` (this task adds it), `not-applicable` (with reason).

| Surface | Owed/skipped decision | Fail-closed default | Skip record |
|---|---|---|---|
| `agents/pm-spec.md` self-check | mirrored-now (**AC1**) | mirrored-now (**AC1**, **AC5**) | mirrored-now — `pm-spec` writes the line (**AC1**) |
| `skills/run/SKILL.md` freeze sweep (step 2) | mirrored-now — confirms the line against the contract (**AC2**) | mirrored-now — a mismatch routes back (**AC2**, **AC5**) | mirrored-now — confirms the skip line exists (**AC2**) |
| `skills/run/SKILL.md` reviewer briefing (step 6) | mirrored-now — names the recorded decision (**AC2**) | mirrored-now — an owed diff without a result stays gating (**AC2**) | mirrored-now — a recorded skip is non-gating (**AC2**) |
| `agents/qa-verifier.md` (`:175`) | not-applicable — QA verifies a spec's criteria; its `:175` duty triggers only "when a spec calls for" a population job, which a recorded skip does not | not-applicable — same ground | not-applicable — QA does not write the spec |
| `docs/adopting.md` | mirrored-now (**AC4**) | mirrored-now (**AC4**, **AC5**) | mirrored-now (**AC4**) |
| `docs/adopting.ja.md` | mirrored-now (**AC4**) | mirrored-now (**AC4**, **AC5**) | mirrored-now (**AC4**) |

Singular-determiner read: the norm governs "the diff" per task and "the contract" per repository; each task has one spec and each repository one resolved contract, so the singular is exact. The workflow evidence is plural (`ci_suite_workflows`, one or more paths) by design; the coordinating session reads the norm text against this repository's own case, where one workflow carries all suites.

## Shipped-docs inventory

Every shipped document naming the full-population diff, read by this role, with its disposition:

| Document | Disposition | Ground |
|---|---|---|
| `docs/adopting.md` | this task | its `mechanism` paragraph states the diff as unconditional; the section gains D1–D3 |
| `docs/adopting.ja.md` | this task | mirror of the EN section |
| `README.md:248` / `README.ja.md:248` | unchanged | describes the `verify-mechanism` refinement used "when" a task's duty bundles a full-population diff; a recorded skip means the task has no such half, so the sentence stays true |
| `CONTRIBUTING.md:132` | unchanged | describes how a maintainer prices a release-level sweep when one is run; this task governs per-task inventories only (D5) |
| `agents/qa-verifier.md:175`, `agents/engineer.md:157` | unchanged | conditional on "a spec calls for" a population job |
| `agents/tech-lead.md:96`, `templates/prompt-blocks/dispatch-record.md`, `templates/prompt-blocks/fanout-orchestration.md` | unchanged | dispatch grammar for a sweep when one is run |
| generated playbook blocks | unchanged | generated from the lessons corpus; never hand-edited |
| `skills/goal/SKILL.md` | unchanged | its review briefing carries the run skill's norm by reference ("not restated", T-1065 `BRIEFG`), so the step-6 addition reaches it by reference |

## Blast radius

- **Class.** `no-mechanism`, so the analysis is read-set-scoped; the new `full-population-diff:` decision line does not apply to this spec.
- **Read set (norm-editing obligation).** The merged criteria whose `- check:` lines name an edited path by its literal bytes. The coordinating session embeds the block at the freeze run:
  - reproduce: bash bin/derive-populations.sh --label t1200-read-set --set "read=git grep -l -E '^[[:space:]]*- check:.*(agents/pm-spec[.]md|skills/run/SKILL[.]md|docs/adopting([.]ja)?[.]md|shell-team[.]contract[.]yaml|--get loops)' -- .shell-team/specs/*.md" --set "all=git ls-files -- .shell-team/specs/*.md"
  - Byte locks this role opened (Summarized sources): T-1108 **AC2** and **AC3** are live and stay green by construction (**AC3** of this spec asserts T-1108 **AC3**'s property; the method item stays outside the generated region). T-1053 **AC2**/**AC3** and T-1108 **AC1** are already red at today's base (each requires its sentence absent from a `develop` blob that carries it); this task rewrites the `:87` line T-1053 `BLAST` compares whole-line, which changes the HEAD half of an already-red criterion, and keeps every HEAD-side literal T-1108 **AC1** asks for (**AC1** of this spec). T-1065's criteria exit `1` on a branch absent from this checkout; `:92` (`TIER`) and the `BRIEF` text survive unchanged anyway (**AC3**).
  - Criteria asserting docs bytes: T-1065 **AC6** requires `- verification-class:`, `no-mechanism`, `full-population`, `read-set` and the two honesty anchors inside the pricing sections; the edit keeps them (engineer note). Its heading-adjacency clauses were already stale at base and are not touched by this task (no heading change, **AC4**).
- **The indirection class.** Criteria that reach these files through a glob, a variable or `bin/team-paths.sh --get loops` without the literal path. They are not re-run locally, following the operator ruling relayed for this sprint (no local run of past specs' check lines); this is a disclosed gap. Every merged scope lock reading `<base>...HEAD` is already merge-point-scoped. CI (**AC11**) decides for the suites.
- **CI steps the diff reaches** (reverse-mapped by this role with a Grep over `tests/**/run.sh` and the workflow for the edited paths, `agents/*.md` copies and `.shell-team/loops`; a lower bound, since a suite may also reach a file through a variable):
  - `tests/check-contract/run.sh` (`:114` lints this repository's contract) and `tests/check-spec-review/run.sh` (`:385` reads this repository's contract's `budget:` section) — reached by the contract edit; **AC8** runs `check-contract.sh` and `loop-guard.sh` on it directly.
  - `tests/codex-agents/run.sh`, `tests/check-invocation-path/run.sh`, `tests/check-model-pins/run.sh` (copy or regenerate from the real `agents/*.md`), the `gen-codex-agents` dogfood step, `tests/check-prompt-sync/run.sh` and the `check-prompt-sync` dogfood step — reached by the `agents/pm-spec.md` edit.
  - `tests/check-oversight/run.sh` and `tests/check-refreeze-grant/run.sh` (read `skills/run/SKILL.md` for specific invocation strings this task does not add) — reached by the skill edit.
  - The board dogfood steps (`check-handoff`, `check-board-headings`), the interventions dogfood step, `check-pii-shapes on the PR diff` and `check-commit-identity on the PR commits` — reached by the records.
  - Inapplicable: every `shellcheck` step (no shell file changes); every other suite step (the reverse map found no reference to an edited path); the three shipped-contract lint steps (they read `templates/*.yaml`, unchanged).
  - Not run locally by this role (no shell); the engineer and QA run the reached suites through the repository's test recipe, and CI (**AC11**) decides.
- **Adopter-side artefacts.** None generated. An adopter that later adds the section will see `check-setup.sh` report its contract as differing from the template (a note only); D6 documents it.

## Measurement

Owned by the coordinating session, after the release ships: for the first adopter mechanism-class task run with the declaration in place, compare its wall clock (telemetry, `run_id`'s first span to its `release` event) with that adopter's prior mechanism-class tasks' wall clock from the same telemetry, and record both values and the commands that produced them in the retro that follows. It cannot be an in-task check line: the effect occurs only in an adopter repository after release, the telemetry corpus is gitignored and not readable from a fresh checkout, and no adopter carries the declaration before this task ships.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| CI-declared repositories skip the full-population diff (D1–D6) | met: an adopter can newly declare its CI and stop paying the diff | met: a declared adopter's mechanism tasks lose a 1–5 h diff (relayed) on the default `/shell-team:run` path | MINOR | a new contract key that changes what a default run owes |

Sprint tier MINOR, v2.10.0 (relayed); T-1201 (#639) stacks after this task.

## Assumptions

- **Measured by this role** (Read, Grep and Glob on the working tree, branch `feature/216-downstream-diff-default`, status clean at session start):
  - The cited lines and their content in Summarized sources.
  - `.shell-team/loops/shell-team.contract.yaml` has no `verification:` section; no file under `templates/*.yaml`, `bin/*.sh`, `docs/*.md`, `README*.md` or `CONTRIBUTING.md` carries `verification:`, `ci_runs_test_suites` or `ci_suite_workflows`.
  - No script under `bin/` contains `Blast radius`, `blast-radius` or `full-population-diff` (design point (c): no checker parses the record).
  - `bin/` scripts that read or name the loop contract: `team-paths.sh`, `team-init.sh`, `team-setup.sh`, `check-setup.sh`, `check-contract.sh`, `loop-guard.sh` (named by path) and `check-spec-review.sh` (via `--contract`); the three that parse it read sections by name, and none carries a rule against an extra top-level key. A script reaching the contract through some other variable would not be found by this search.
  - `chore/lesson-promotion-2026-08-13` and `feature/1107-close-out-gates` are absent from `.git/refs/heads/` and `.git/packed-refs` in this checkout (the T-1065 and T-1108 base refs).
  - The board's `release-sweep` sub-bullets exist (e.g. v2.7.7, v2.7.6, v2.7.5), and some are narrowed or disposition rows rather than full-population sweeps.
  - **Own-coinage tokens:** `full-population-diff: skipped`, `full-population-diff: owed`, `ci_runs_test_suites`, `ci_suite_workflows`, the top-level contract key `verification:`, `post-implementation HEAD` and `non-gating` as used together in the step lines, and the two honesty anchors. **Borrowed tokens** with no count premise at base: `## Blast radius`, `verification-class`, `coordinating session`, `check-setup.sh`, `shell-team.contract.yaml`.
- **Relayed, not measured by this role** (owner: the coordinating session):
  - the issue #216 body and the operator condition (Problem);
  - the measured history: 16 release-time sweeps, 0 functional regressions, one that caught two record-format conventions, 1–5 h each, and the stop on 2026-09-30. Partial primary source: the board's `release-sweep` lines. Freeze-run result (coordinating session, 2026-11-22): the board carries 18 `release-sweep` rows, 10 of which mention `full-population`; two rows are pointers to a sprint's single sweep, one is a stopped sweep and one a narrowed sweep, so the rows hold about 15 sweep records and do not by themselves yield 16 — the figure 16 stays relayed from the issue body and is not restated as derived anywhere in this task. Freeze-run duty — embed:
    - reproduce: bash bin/derive-populations.sh --label t1200-release-sweeps --set "rows=grep -n '^[[:space:]]*- release-sweep' .shell-team/todo.md" --set "full=grep -n '^[[:space:]]*- release-sweep.*full-population' .shell-team/todo.md"
    and report whether the row counts support the relayed 16; no relayed figure appears in the intent block or in any required shipped wording;
  - sprint "verify-cost", release MINOR v2.10.0, T-1201 (#639) stacking after;
  - the branch point `develop` at `d8ca827e`;
  - the operator ruling behind the no-local-past-spec-run disclosure.
- **Freeze-run duties** (owner: the coordinating session). A false prediction routes back here as a broken check line.
  - **The base.** `<base>` resolves to the relayed `d8ca827e`; record the value.
  - **Own-coinage absence at base.** Read the base commit, not the working tree (the board entry and this spec already carry the tokens): `git grep -n -F -e 'full-population-diff:' -e 'ci_runs_test_suites' -e 'ci_suite_workflows' -e 'otherwise the diff stays owed' "$B" -- .` prints nothing (exit `1`).
  - **T-1108 AC2/AC3 liveness** is judged by reading, not by running: both lines end in a recursive deletion of their temp dir, so they are not run locally. This spec's **AC3** asserts T-1108 **AC3**'s property with its own line.
  - **Before implementation.** **AC1**, **AC2**, **AC4**, **AC5**, **AC6** red (tokens or section absent); **AC3** green (nothing removed yet); **AC7** predicted green (this role's reading of the suite list against the workflow found no suite missing); **AC8** green (contract unchanged); **AC9** green when the board entry is conformant; **AC10** red on its positive control; **AC11** `SKIP`.
  - **Mutation probes** (the `no-mechanism` class requires them for the lines this task adds), in a scratch clone under `$TMPDIR` after writing a specimen implementation: drop `otherwise the diff stays owed` from the method item (**AC1**, **AC5** red); add a docs paragraph that quotes the skip record form (`full-population-diff: skipped — contract: … — ci_runs_test_suites: yes — evidence: …`) without the fail-closed anchor (**AC5** red); set the contract value to `true` (**AC6** red); delete one `run: bash tests/<suite>/run.sh` step (**AC7** red); alter one character of `:92` in `agents/pm-spec.md` and, separately, of a base line in `skills/run/SKILL.md` (**AC3** red); drop a staging literal from the method item (**AC1** red); remove the JA honesty anchor (**AC4** red).

## Open questions

None blocking. For the coordinating session to file (title and body; no issue number is invented here):

- **Title:** setup surfaces the optional `verification:` contract section. **Body:** T-1200 adds an optional loop-contract section (`verification:` with `ci_runs_test_suites: yes` and `ci_suite_workflows: <paths>`) that turns off the full-population downstream-impact diff for mechanism-class tasks. `team-setup.sh` / `check-setup.sh` do not mention it, and an adopter who adds it sees the contract reported as differing from the installed template. Decide whether setup should offer the declaration (e.g. when `.github/workflows` exists) and whether the template-difference note should ignore this section; any change to `templates/shell-team.contract.yaml` triggers drift notices for every adopter and needs its own prior-template step.

## Notes for engineer

- **Where the owed diff runs (differs from the relayed design).** The relayed design had the coordinating session run the diff "at the freeze sweep". That sweep runs against the pre-implementation tree, where HEAD has no implementation arm, so this spec freezes D3 instead: the freeze sweep confirms the decision line; an owed diff runs once HEAD carries the implementation, inside verification. Reported in the hand-off.
- **`agents/pm-spec.md`: change exactly one line.** Rewrite `:87` in place as one physical line starting `- **Downstream-impact inventory method (forward-only)**:`. Keep the phrases **AC1** lists, keep the runs-corpus staging sentence verbatim, and keep the method as the "how" when owed. Do not touch `:92` or any other line (**AC3**, and the merged T-1108 **AC3**). Do not wrap the line.
- **`skills/run/SKILL.md`: add lines only.** Do not edit `:66` or `:126`. Add a three-space-indented `- **…**` sub-bullet in step 2 near the freeze-sweep gates and one in step 6 beside the verdict-scope bullet. Do not repeat T-1053's `POST`/`SING` or T-1065's `BRIEF` text.
- **Every line or paragraph naming `full-population-diff: skipped` also names `ci_runs_test_suites: yes` and the fail-closed anchor** (`otherwise the diff stays owed`; JA `それ以外では diff は owed のまま`) (**AC5**). Write the record line forms in backticks mid-sentence.
- **The step-6 line** scopes the verdict the way `:126` does: a recorded skip under the declaration is the price the freeze set and is non-gating; an owed diff with no recorded result is gating. Never ask the reviewer to withhold a finding.
- **Docs.** Edit inside the existing pricing section, add no `## ` heading, keep T-1065's tokens (`- verification-class:`, `no-mechanism`, `full-population`, `read-set`, `no mechanical checker ships for this`, `機械的なチェッカーは出荷されない`). The `mechanism` paragraph's "exactly as before: a full-population downstream-impact diff" may be qualified so it does not contradict the new paragraph. Use the exact anchors `nothing verifies this declaration` and `この宣言を検証するものはない`. Name `check-setup.sh` and the template-difference note. Machine tokens stay English in the JA text.
- **Contract.** Append the section at the end of `.shell-team/loops/shell-team.contract.yaml` with a short comment; do not touch `templates/`. Run `bin/check-contract.sh` and `bin/loop-guard.sh … --iteration 0` on it.
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **No private context**: no adopter, operator or workstation names, no host-local paths or tool names in any file.
- **Keep each matched phrase on one physical line.** AC4 matches the multi-word anchors (`nothing verifies this declaration`, `otherwise the diff stays owed`) and the record tokens (`full-population-diff: skipped`, `ci_runs_test_suites: yes`) per line, case-sensitively, and AC5 per paragraph; when hard-wrapping `docs/adopting.md` / `.ja.md`, never break inside one of them (freeze-run specimen finding).
