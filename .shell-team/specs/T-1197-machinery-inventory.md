# Machinery inventory: which parts of the loop still earn their keep with current models

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1197

## Problem

The loop has collected instructions, generated prompt blocks, orchestration steps, checkers, CI steps and review passes over many cycles. Many of them were added to make up for a model limitation observed at the time. Nobody has recorded which of those limitations still exist. The host pays for every item on every run, in context size, wall clock and manual steps, whether or not the item still prevents anything. Issue #754 asks for one inventory of the machinery, so that later planning can decide removals and simplifications from evidence rather than by age or by impression.

## Summarized sources

- **Issue #754 body.** The coordinating session relayed its essentials verbatim. This role cannot open the tracker, so the text is labelled relayed in Assumptions. The distinctions carried over:
  - The four groups:
    - `agents/*.md`, including the blocks generated from `templates/prompt-blocks/`;
    - `skills/*`;
    - `bin/*` checkers and the CI steps that run them;
    - review shapes (primary / adversarial / evidence passes).
  - Five fields per item, in this order:
    1. what it does, in one line;
    2. the failure it was added to prevent, with provenance where it survives;
    3. whether that failure can still be reproduced with current models, measured where practical and otherwise marked unmeasured;
    4. a verdict from keep / simplify / candidate for removal / unknown, with the reason;
    5. what the host would stop paying if it went.
  - One platform fact that bounds the options: subagents shipped inside a plugin ignore the `hooks`, `mcpServers` and `permissionMode` frontmatter fields.
  - Acceptance:
    - a single document that covers every item in the four groups, each with all five fields;
    - every simplify and candidate-for-removal verdict cites its evidence, and one that cannot is marked unknown;
    - follow-up issues are filed only after review, one per approved removal or simplification.
  - Ruled out: removing things during the inventory, and judging items by age alone.

  Restated by the Goal sentence, D1–D6, Non-goals, **AC1**–**AC7** and Input space.
- **`bin/derive-populations.sh` header (`:1-94`) and `--help` (`:155-199`)**, read with the Read tool.
  - Grammar (`:30-42`): one `- set: <name> — status: <n> — lines: <n> — items: <n> — command: <cmd>` line per set, then a `- union:` line, then one `- bucket: <sig> — items: <n>` line per non-empty membership signature. `<sig>` joins the names of the sets containing the item with `+`, in declaration order.
  - `lines` counts everything the command printed, and `items` counts the distinct non-empty lines (`:44-49`). So `lines` greater than `items` means duplicates.
  - Exit codes (`:51-61`): `0` means the block was written. `1` means a refusal: a set command's exit status was not accepted, or an item carries a carriage return or another control character. `2` means a usage error, including fewer than two sets.
  - Every set command runs under `set -o pipefail` (`:191-196`).

  Restated by D1, D2, **AC1** and **AC2**.
- **`.github/workflows/check-handoff.yml`**, read with the Read and Grep tools. It holds one job, `lint` (`:10`). Every step's `- name:` line is indented six spaces, and the first step is `Checkout` (`:14`). Steps fall into four kinds:
  - steps that execute a `bin/` script directly, such as `bash bin/check-contract.sh …` (`:69`);
  - steps that run a fixture suite, `bash tests/<suite>/run.sh` (for example `:66`);
  - `shellcheck` steps, which lint scripts without executing them (`:28-47`, `:334`, `:340`, `:417`);
  - setup steps: `Checkout` and `Install shellcheck` (`:14`, `:19`).

  Some suites have no `bin/` script of the same name, for example `machine-tokens` (`:128`), `errexit-safe` (`:265`), `bin-exec-bit` (`:289`), `bin-help` (`:402`) and `local-mode` (`:420`). Restated by D2, **AC2** and Input space.
- **`agents/code-reviewer.md`**, read for the review shapes it defines:
  - the primary pass, a single `codex exec … review` read path (`:42`, step 3);
  - the adversarial pass, with its own `codex` block (`:46`, `:82`);
  - the evidence pass and its widened trigger (`:118`, step 5);
  - `## Finding-evaluation mode (review-response)` (`:172`);
  - `## Spec-review mode (specify seam, T-1092)` (`:193`).

  Restated by D4 and **AC5**.
- **`agents/drift-evaluator.md`**: the role is itself an optional pass run after code-reviewer's APPROVE (`:3`). Its loop runs a Codex semantic pass through `codex exec`, whose raw verdict the role may override and must ledger (`:85-122`). The shape this inventory records is that Codex semantic pass. Restated by D4 and **AC5**.
- **`bin/check-adopter-docs.sh:2-40`**: exit `0` is silent, `1` is a content refusal and `2` means the input could not be evaluated, with one token on stderr and nothing on stdout. A `no` declaration carries neither `adopter-surface` nor `shipped-docs`. **`bin/check-handoff.sh`** lints the board line format. **`bin/team-paths.sh --get todo`** resolves the board. Restated by **AC9**.
- **`templates/prompt-blocks/registry.txt:1-16`**: each rule names which consumer files must carry which canonical block. A `marker` rule requires one `<!-- BEGIN prompt-block: <name> -->` / `<!-- END prompt-block: <name> -->` pair in the consumer. A `contain` rule requires the block's lines verbatim, with no marker. Two scripts read it: `bin/check-prompt-sync.sh` and `bin/gen-playbook-blocks.sh` (Grep over `bin/`). The coordinator's wording, "the generator's config", is narrower than this. The document's sentence about `registry.txt` follows what the file says. Restated by D1 and **AC4**.
- **`bin/check-pii-shapes.sh:229-249`**: `--paths <path> [<path>...]` scans exactly the named files. Exit `0` means clean, `1` means findings, and `2` means a usage or structural error, including a `--paths` run that read nothing. Restated by **AC7**.
- **`.shell-team/lessons.md`**:
  - `2026-08-16 — Review depth is priced by the artifact's consumer and stakes, at freeze and again in every review briefing` (`:1192`). Restated by `## Verdict scope`.
  - `2026-08-15 — A completeness claim is written only as the extraction command plus its pasted output` (`:1140`). Restated by D2 and **AC1**/**AC2**.

## Goal

<!-- BEGIN intent-block: T-1197 -->

- user-visible: no — the deliverable is an internal analysis document under `docs/loop-engineering/`, read by the operator and by later planning. No command, configuration key or adopter-facing behaviour changes.
- verification-class: no-mechanism — the diff adds one Markdown document and this task's records. It touches no path under `bin/`, `tests/`, `templates/` or `.github/`, and no checker's semantics.
- verification-ceiling: unit-and-static — **AC1**–**AC9** are settled in a plain checkout. They read the new document, the tracked file lists and the workflow file, and read the exit codes of `derive-populations.sh`, `check-pii-shapes.sh`, `check-adopter-docs.sh` and `check-handoff.sh`. **AC10** (CI on the pull request) sits above the ceiling.
- base-ref-discriminator: not-applicable — no criterion reads a base-side blob. The scope lock reads the commit range from `develop`'s merge base. The branch was cut from `develop` with no open predecessor.

**Goal (one sentence).** `docs/loop-engineering/machinery-inventory.md` exists and holds one row per item of the four groups the issue names. Each row has a stable id and the issue's five fields. Every simplify or candidate-for-removal verdict carries an evidence locator. Every CI step of `.github/workflows/check-handoff.yml` is accounted for exactly once. The review shapes form a list stated as closed. A platform-fact section states the frontmatter limit with its source status. Completeness is shown as set identity between the repository's enumeration and the document's row ids, through `bin/derive-populations.sh`.

**Decisions frozen here** (each is promoted to a criterion or exempted in the correspondence table):

- **D1 — item units (coordinator decision).** One row per item:
  - one row per tracked `agents/*.md` file, which lists inside the row every prompt block the file carries, never as separate rows;
  - one row per tracked `templates/prompt-blocks/*.md` file;
  - one row per skill directory, `skills/<name>`;
  - one row per tracked `bin/*` entry, extensionless entries included;
  - one row per CI step that is not attached to a `bin/` row (D2);
  - one row per review shape (D4).

  `templates/prompt-blocks/registry.txt` is not an item. The document says so in one sentence that names the file. (**AC1**, **AC4**)
- **D2 — CI steps are accounted for exactly once.** Each workflow step name appears in the document exactly once, in one of two ways:
  - attached to a `bin/` row, as a `- ci-step: <exact step name>` line in that row. A step that executes a `bin/` script, directly or through a suite whose primary subject is that script, is attached to that script's row;
  - as a row of its own, `### item: ci:<exact step name>`, in a CI section. A step that executes no `bin/` script gets its own row.

  The two ambiguous families are settled in Assumptions (`shellcheck` steps, and suites with no `bin/` subject). The criterion checks coverage and uniqueness, not the attachment judgment. (**AC2**)
- **D3 — row grammar.** Each item is introduced by a heading line `### item: <id>`.
  - **The id.**
    - For a file-backed item it is the item's repository path. A skill's id is its directory, `skills/<name>`.
    - For a CI row it is `ci:` followed by the step name exactly as written after `- name: ` in the workflow.
    - For a review shape it is `shape:<name>`, where `<name>` uses `[a-z0-9-]`.
  - **A row's extent.** A row runs from its heading to the next line beginning `#`.
  - **The five fields.** Inside that extent, each of the following appears on exactly one line, with a non-empty value:
    - `- does: <one line>`.
    - `- prevents: <failure> — provenance: <locator>[; <locator>…]`, or `— provenance: not found`.
    - `- reproducible: measured: <how, and the result>` or `- reproducible: unmeasured: <reason>`.
    - `- verdict: <keep|simplify|candidate for removal|unknown> — <reason>`. When the verdict is simplify or candidate for removal, the line ends with `— evidence: <locator>[; <locator>…]`.
    - `- host-cost: <what the host stops paying: context size, wall clock, manual steps>`.
  - **A locator** is an in-repository reference, in one of three forms:
    - a `<path>:<line>`, for example a `T-NNN` marker's file and line;
    - an issue or pull request `#<N>`;
    - `lessons: <YYYY-MM-DD> — <heading>`.
  - **Other lines.** Apart from the five field lines, a row may carry `- generated-block: <name>` lines (agent rows), `- ci-step: <name>` lines (`bin/` rows) and free notes.

  (**AC3**)
- **D4 — review shapes are a closed list.** The document has a `## Review shapes` section with one `- closed-list:` line. That line lists every `shape:` id, separated by spaces, and the set equals the `shape:` rows. The list contains at least these ids, read from the two agent files:
  - `shape:primary`, `shape:adversarial` and `shape:evidence` (`agents/code-reviewer.md`);
  - `shape:review-response` and `shape:spec-review` (the two other modes of `agents/code-reviewer.md`);
  - `shape:drift-semantic` (the Codex semantic pass run by `agents/drift-evaluator.md`).

  A further shape found in either file is added to both the list and the rows. (**AC5**)
- **D5 — field 3 is never a live model experiment.**
  - `measured:` names a measurement made against artefacts in this repository: the review records, interventions, retros, telemetry or the lessons corpus. One example is whether the failure class recurs in recent records.
  - Anything else is `unmeasured: <reason>`.

  No model run is staged for the inventory. (info-only, a method choice; QA reads a sample)
- **D6 — the platform fact.** A `## Platform fact` section states that subagents shipped inside a plugin ignore the `hooks`, `mcpServers` and `permissionMode` frontmatter fields, so any per-role protection has to live somewhere else. It either cites an external primary source with an `https://` URL, or carries the exact label `relayed from issue #754, unverified in this repository`. (**AC6**)

**Pre-commitment (frozen before round 1).** The trigger and the disposition below are AI self-discipline proposed by the coordinating session, never operator-ratified.

- **Never-dropped.** The first defeat of either one stops the task and returns it to planning.
  - (N1) The row schema (D3, **AC3**).
  - (N2) Set-identity completeness (D1, D2, **AC1**, **AC2**).
- **Droppable, first.** Any `measured:` cell. A measurement that review shows to be wrong or unsupported falls back to `unmeasured: <reason>`. A verdict that rested on it and has no other evidence becomes `unknown`. The finding travels into that row's reason.
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same component. A round interrupted before a verdict does not count.

## Non-goals

- **Nothing is removed, simplified or changed during the inventory.** No file under `agents/`, `skills/`, `bin/`, `templates/`, `tests/` or `.github/` is edited. (**AC8**)
- **No follow-up issue is filed by this task.** Follow-ups are filed only after the inventory is reviewed, one per approved removal or simplification, and that is outside this task. (info-only; not observable by a command)
- **No item is judged by its age alone.** (info-only; a QA and review reading item)
- **No live model experiment** (D5). (info-only)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no behaviour verification of a mechanism this task does not touch.** The deliverable class is `no-mechanism`. Every criterion is a string presence or absence read, a checker's exit code, or a records-line existence check. (info-only; disclosed in Blast radius)
- **No CHANGELOG entry and no release.** (**AC8**)
- **No judgment of a verdict's truth by a command.** The check lines prove presence and form, not correctness (Verdict scope). (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Temporary files go under `$TMPDIR` and are left there.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **Pre-implementation state.** Every line first asserts that the document is non-empty, so before implementation it is red rather than vacuous.

- [ ] **AC1** (D1; N2.) File-backed completeness, as set identity.
  - **Per-group controls.** Each of `git ls-files -- 'agents/*.md'`, `git ls-files -- 'templates/prompt-blocks/*.md'`, `git ls-files -- 'skills/*/SKILL.md'` and `git ls-files -- 'bin/*'` lists at least one path.
  - **The derivation.** `bin/derive-populations.sh` runs with two sets and exits `0`:
    - `repo`: the tracked paths of `agents/*.md`, `templates/prompt-blocks/*.md` and `bin/*`, plus each tracked `skills/*/SKILL.md` with `/SKILL.md` stripped;
    - `doc`: every `### item: ` id in the document that does not begin `ci:` or `shape:`.
  - **It passes when** the block has a `- bucket: repo+doc` line with a non-zero count, has no `- bucket: repo —` and no `- bucket: doc —` line, and the `doc` set's `lines` equals its `items`, so no id is duplicated.
  - **The registry sentence.** The document names `templates/prompt-blocks/registry.txt`. It has no row for that file, because any such row would form a one-sided `doc` bucket.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac1.XXXXXX") || exit 1; for g in 'agents/*.md' 'templates/prompt-blocks/*.md' 'skills/*/SKILL.md' 'bin/*'; do git ls-files -- "$g" > "$T/g" || exit 1; test -s "$T/g" || exit 1; done; bash bin/derive-populations.sh --label t1197-items --set "repo=git ls-files -- 'agents/*.md' 'templates/prompt-blocks/*.md' 'bin/*' && git ls-files -- 'skills/*/SKILL.md' | sed 's#/SKILL[.]md##'" --set "doc=sed -n 's/^### item: //p' '$D' | grep -vE '^(ci|shape):'" > "$T/d"; test "$?" = 0 || exit 1; grep -qE '^- bucket: repo\+doc — items: [1-9]' "$T/d" || rc=1; grep -E '^- bucket: (repo|doc) — ' "$T/d"; g=$?; test "$g" = 1 || rc=1; sed -n 's/^- set: doc — status: 0 — lines: \([0-9]*\) — items: \([0-9]*\) — .*/\1 \2/p' "$T/d" > "$T/n" || exit 1; read -r a b < "$T/n" || exit 1; test -n "$a" && test "$a" = "$b" || rc=1; grep -qF 'templates/prompt-blocks/registry.txt' "$D" || rc=1; test "$rc" -eq 0
    - stale-at: a later task adds, removes or renames a tracked file under `agents/`, `templates/prompt-blocks/`, `skills/` or `bin/`. From then on the document no longer describes the population this criterion re-derives.

- [ ] **AC2** (D2; N2.) Every CI step is accounted for exactly once.
  - **Positive control.** The step names read from `.github/workflows/check-handoff.yml` (every line beginning with six spaces and `- name: `) include `Checkout`.
  - **The derivation.** `bin/derive-populations.sh` runs with two sets and exits `0`:
    - `workflow`: those step names;
    - `doc`: every `### item: ci:<name>` id with the `ci:` prefix stripped, plus every `- ci-step: <name>` value.
  - **It passes when** a `- bucket: workflow+doc` line has a non-zero count, there is no one-sided bucket, and on each set's line `lines` equals `items`. So no step is listed twice in the document, and no two steps share a name.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; D=docs/loop-engineering/machinery-inventory.md; W=.github/workflows/check-handoff.yml; test -s "$D" || exit 1; test -s "$W" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac2.XXXXXX") || exit 1; sed -n 's/^      - name: //p' "$W" > "$T/w" || exit 1; grep -qxF Checkout "$T/w" || exit 1; bash bin/derive-populations.sh --label t1197-ci --set "workflow=sed -n 's/^      - name: //p' '$W'" --set "doc=sed -n -e 's/^### item: ci://p' -e 's/^- ci-step: //p' '$D'" > "$T/d"; test "$?" = 0 || exit 1; grep -qE '^- bucket: workflow\+doc — items: [1-9]' "$T/d" || rc=1; grep -E '^- bucket: (workflow|doc) — ' "$T/d"; g=$?; test "$g" = 1 || rc=1; for s in workflow doc; do sed -n "s/^- set: $s — status: 0 — lines: \([0-9]*\) — items: \([0-9]*\) — .*/\1 \2/p" "$T/d" > "$T/n" || exit 1; read -r a b < "$T/n" || exit 1; test -n "$a" && test "$a" = "$b" || { rc=1; printf 'duplicate in %s\n' "$s"; }; done; test "$rc" -eq 0
    - stale-at: a later task adds, removes or renames a step in `.github/workflows/check-handoff.yml`, or adds another workflow file. From then on the document no longer describes the step population.

- [ ] **AC3** (D3; N1.) Every row carries the five fields in grammar. At least one row exists. For every `### item: ` row:
  - each of `does`, `prevents`, `reproducible`, `verdict` and `host-cost` occurs on exactly one field line within the row's extent, with a non-empty value;
  - the `prevents` line carries `— provenance: not found` or a locator in one of the three forms;
  - the `reproducible` value begins `measured: ` or `unmeasured: ` followed by text;
  - the `verdict` value begins with one of the four verdicts, then ` — ` and a reason;
  - a `simplify` or `candidate for removal` verdict line carries `— evidence: ` followed by a locator.

  The violations are printed per row.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; awk 'BEGIN { split("does prevents reproducible verdict host-cost", K, " "); L = "([A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+:[0-9]+|#[0-9]+|lessons: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" } function flush(i) { if (id == "") return; for (i = 1; i <= 5; i++) { if (c[K[i]] != 1) { printf "row %s: field %s occurs %d times\n", id, K[i], c[K[i]] + 0; bad = 1 } c[K[i]] = 0 } } /^### item: / { flush(); id = substr($0, 11); n++; if (id == "") { print "empty id"; bad = 1; id = "?" } next } /^#/ { flush(); id = ""; next } id != "" && /^- (does|prevents|reproducible|verdict|host-cost):/ { k = $0; sub(/^- /, "", k); sub(/:.*/, "", k); c[k]++; v = $0; sub(/^- [a-z-]+:[ ]*/, "", v); if (v !~ /[^ ]/) { printf "row %s: %s empty\n", id, k; bad = 1 } if (k == "prevents" && $0 !~ ("— provenance: (not found$|.*(" L "))")) { printf "row %s: provenance cell\n", id; bad = 1 } if (k == "reproducible" && v !~ /^(measured|unmeasured): [^ ]/) { printf "row %s: reproducible form\n", id; bad = 1 } if (k == "verdict") { if (v !~ /^(keep|simplify|candidate for removal|unknown) — [^ ]/) { printf "row %s: verdict form\n", id; bad = 1 } if (v ~ /^(simplify|candidate for removal) / && $0 !~ ("— evidence: .*(" L ")")) { printf "row %s: evidence locator\n", id; bad = 1 } } } END { flush(); if (n == 0) { print "no rows"; bad = 1 } exit bad }' "$D" || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D1.) Each agent row lists its generated blocks. Every tracked `agents/*.md` file is checked for `<!-- BEGIN prompt-block: <name> -->` lines. Each name it carries appears as a `- generated-block: <name>` line inside that file's own `### item: agents/<file>` row.
  - **Positive control.** At least one marker exists across the agent files.
  - Whether the row also names the blocks a file carries in `contain` mode (no marker) is a QA reading item.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac4.XXXXXX") || exit 1; git ls-files -- 'agents/*.md' > "$T/a" || exit 1; test -s "$T/a" || exit 1; m=0; while IFS= read -r f; do awk -v id="$f" 'index($0, "### item: ") == 1 { on = (substr($0, 11) == id); next } /^#/ { on = 0; next } on' "$D" > "$T/row" || exit 1; sed -n 's/^<!-- BEGIN prompt-block: \([A-Za-z0-9_-]*\) -->$/\1/p' "$f" > "$T/b" || exit 1; while IFS= read -r b; do m=$((m + 1)); grep -qxF -- "- generated-block: $b" "$T/row" || { rc=1; printf 'missing %s in %s\n' "$b" "$f"; }; done < "$T/b"; done < "$T/a"; test "$m" -gt 0 || rc=1; test "$rc" -eq 0
    - stale-at: a later task adds or removes a prompt-block marker pair in an agent file. From then on the agent rows no longer describe the blocks this criterion re-reads.

- [ ] **AC5** (D4.) The review shapes form a closed list.
  - The document has exactly one `- closed-list: ` line.
  - The `shape:` ids on that line, sorted, equal the sorted `### item: shape:` ids, and the set is non-empty.
  - The ids include `primary`, `adversarial`, `evidence`, `review-response`, `spec-review` and `drift-semantic`.
  - Whether either agent file defines a further shape the list omits is a QA reading item.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac5.XXXXXX") || exit 1; sed -n 's/^### item: shape://p' "$D" | sort > "$T/h" || exit 1; test "$(grep -c '^- closed-list: ' "$D")" = 1 || rc=1; sed -n 's/^- closed-list: //p' "$D" | tr ' ' '\n' | sed -n 's/^shape://p' | sort > "$T/c" || exit 1; test -s "$T/h" || rc=1; cmp -s "$T/h" "$T/c" || { rc=1; printf 'closed-list differs from shape rows\n'; }; for s in primary adversarial evidence review-response spec-review drift-semantic; do grep -qxF "$s" "$T/h" || { rc=1; printf 'missing shape %s\n' "$s"; }; done; test "$rc" -eq 0

- [ ] **AC6** (D6.) The platform fact. The document has exactly one line beginning `## Platform fact`.
  - The section, from that line to the next `## ` heading, contains `hooks`, `mcpServers` and `permissionMode`.
  - It also contains either `https://` or the exact label `relayed from issue #754, unverified in this repository`.
  - That the sentence states the issue's fact, and that a cited URL is a primary source saying it, is a QA and review reading item.
  - check: rc=0; export LC_ALL=C; D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac6.XXXXXX") || exit 1; test "$(grep -c '^## Platform fact' "$D")" = 1 || exit 1; awk 'index($0, "## Platform fact") == 1 { on = 1; next } /^## / { on = 0 } on' "$D" > "$T/p" || exit 1; test -s "$T/p" || exit 1; for w in hooks mcpServers permissionMode; do grep -qF -- "$w" "$T/p" || { rc=1; printf 'missing %s\n' "$w"; }; done; grep -qF 'https://' "$T/p" || grep -qF 'relayed from issue #754, unverified in this repository' "$T/p" || rc=1; test "$rc" -eq 0

- [ ] **AC7** The document carries no PII-shaped or host-local content. `bash bin/check-pii-shapes.sh --paths docs/loop-engineering/machinery-inventory.md` exits `0`.
  - check: D=docs/loop-engineering/machinery-inventory.md; test -s "$D" || exit 1; test -s bin/check-pii-shapes.sh || exit 1; bash bin/check-pii-shapes.sh --paths "$D"

- [ ] **AC8** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **The base.** `<base>` is `git merge-base` of `develop` and `HEAD`. It is chosen by an existence test, `refs/heads/develop` first and then `refs/remotes/origin/develop`, and the line fails when neither exists.
  - **Measured set.** The union of four reads, each of which must succeed:
    - the committed range, `git diff --no-renames --name-only <base>...HEAD`;
    - the staged delta, `git diff --no-renames --cached --name-only`;
    - the unstaged delta, `git diff --no-renames --name-only`;
    - the untracked strays, `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains the document.
  - **Allowed members.**
    - `docs/loop-engineering/machinery-inventory.md`.
    - This task's records:
      - `.shell-team/specs/T-1197-machinery-inventory.md`;
      - `.shell-team/provenance/T-1197.md`;
      - `.shell-team/interventions/T-1197.md`;
      - `.shell-team/reviews/T-1197.md` and `.shell-team/reviews/T-1197-drift.md`;
      - raw captures `.shell-team/reviews/T-1197-<stem>.{txt,jsonl,json}`.
    - `.shell-team/interventions/no-task.md`.
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac8.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base refs/heads/develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF docs/loop-engineering/machinery-inventory.md "$T/s" || rc=1; grep -vxE 'docs/loop-engineering/machinery-inventory\.md|\.shell-team/(specs/T-1197-machinery-inventory\.md|provenance/T-1197\.md|interventions/(T-1197|no-task)\.md|reviews/T-1197(-drift)?\.md|reviews/T-1197-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md)' "$T/s" > "$T/bad"; test "$?" = 1 || { rc=1; cat "$T/bad"; }; test "$rc" -eq 0

- [ ] **AC9** The records conform.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - **Positive control.** The spec, the checker and the board are each asserted non-empty first.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1197-ac9.XXXXXX") || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1197-machinery-inventory.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC10** CI on the pull request is green. CI's `check-pii-shapes on the PR diff` step scans the new document.
  - above-ceiling: the coordinating session, after the push and before the merge GO, records the check run's result on the board. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **The tracked files of the four groups at HEAD.**
   - Agent files carrying zero or more prompt-block marker pairs, plus `contain`-mode blocks with no marker.
   - Prompt-block files, among them the four `playbook-<role>.md` files generated from the lessons corpus.
   - Skill directories, each holding one `SKILL.md`.
   - `bin/` entries with a `.sh` extension, and the extensionless `bin/install`.
2. **Workflow step names as written.** Plain ASCII names, and names carrying an em dash, parentheses, an apostrophe or a task-id marker, for example `Dogfood check-adopter-docs — this task's own spec` and `shellcheck (T-1151 additions)`. They sit in one job, at one indentation.
3. **The document's own lines.**
   - Ids that contain spaces (CI rows).
   - Locators of all three forms, several per cell separated by `; `.
   - Verdict reasons and host-cost values that themselves contain ` — `.
4. **Platforms.** bash under `LC_ALL=C` on the CI runner (Linux) and on maintainer workstations. The document is committed with LF line endings.

**Out-of-scope synthetic extremes**, declined explicitly:

1. **Workflow names using YAML quoting, block scalars or a different indentation, or steps in a second job or workflow file.** None exists at HEAD. A later addition is the stale-at event of **AC2**.
2. **Nested directories under `bin/` or `skills/<name>/`, or untracked or gitignored files in the four groups.** The enumeration is `git ls-files`, so untracked content is not an item.
3. **A document that starts a non-row line with `### item: `, `- ci-step: ` or `- closed-list: `**, for example inside a grammar explainer. Such a line is read as data, and the engineer avoids it (Notes for engineer).
4. **A locator that has the right form but points nowhere.** Form is checked by **AC3**. Whether a locator resolves is the engineer's re-measurement duty and a review sampling item (Verdict scope), never a command.
5. **Shapes defined outside `agents/code-reviewer.md` and `agents/drift-evaluator.md`.** A skill's own review procedure is part of that skill's row.

<!-- END intent-block: T-1197 -->

## Verdict scope

- **Consumer.** The operator, and the later planning that decides removals and simplifications from this document. It is an internal analysis note. No adopter executes it, and no gate reads it.
- **What a check line proves.** Presence and form: every item has a row, every row has five fields, every removal or simplify verdict carries something shaped like a locator. A check line never proves that a verdict is right, that a locator resolves, or that a `measured:` cell measured what it says.
- **What review does.** Review samples citations against their sources: provenance locators, evidence behind simplify and candidate-for-removal verdicts, and `measured:` cells. It judges whether each verdict follows from its cited evidence. Findings about the check lines' own adversarial completeness are out of scope for a Major (operator ruling on dev-scaffold inline checks, relayed). Every review briefing for this task names the consumer class above.
- **Depth.** Note depth, not shipped-code depth. An unresolvable citation found in review is repaired by turning that cell into `not found` and the verdict into `unknown`, never by a round of strengthening the check lines.

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | One row per agent file, prompt block, skill directory, `bin/` entry (D1) | **AC1** |
| 2 | An agent row lists its generated blocks inside the row (D1) | **AC4**; `contain`-mode blocks are a QA reading item |
| 3 | `registry.txt` is not an item, and one sentence says so (D1) | **AC1** (the name is present and no row exists) |
| 4 | Every CI step is accounted for exactly once, attached or as its own row (D2) | **AC2** |
| 5 | Steps that run a `bin/` script attach to that row; the rest get `ci:` rows (D2) | info-only (not promoted to AC): attachment is a judgment the Assumptions tie-break settles, and QA reads a sample. **AC2** checks coverage and uniqueness |
| 6 | Row grammar: heading id, five fields, provenance cell, field-3 prefix, closed verdict set (D3) | **AC3** |
| 7 | Simplify and candidate-for-removal verdicts carry an evidence locator (D3; issue acceptance) | **AC3** |
| 8 | An unresolvable citation becomes `not found`, with the verdict `unknown` (coordinator decision; Verdict scope) | info-only (not promoted to AC): resolution is not observable by a command. It is the engineer's re-measurement duty and a review sampling item |
| 9 | Review shapes are a closed list containing at least the six named ids (D4) | **AC5** |
| 10 | Field 3 is never a live model experiment (D5) | info-only (not promoted to AC): a method choice, read by QA on a sample |
| 11 | Platform fact with source status (D6) | **AC6** |
| 12 | Nothing removed or changed; no CHANGELOG (Non-goals) | **AC8** |
| 13 | No follow-up issues filed (Non-goals) | info-only (not promoted to AC): filing happens outside the repository, and no command here can observe its absence. The coordinating session reports it |
| 14 | No judging by age alone (Non-goals) | info-only (not promoted to AC): a reading item for QA and review |
| 15 | No full-population sweep, no whole CI re-run (Non-goals) | info-only (not promoted to AC): a process exclusion, disclosed in Blast radius |
| 16 | The document carries no PII or host-local value | **AC7** |
| 17 | The records conform | **AC9** |
| 18 | CI green | **AC10** (above ceiling) |
| 19 | Pre-commitment | info-only (not promoted to AC): a disposition, not a deliverable property |
| 20 | Verdict scope: review depth priced by consumer (Verdict scope) | info-only (not promoted to AC): it prices a gate's behaviour. It is carried into each review briefing by the coordinating session |

## Blast radius

- **Class.** The class is `no-mechanism`, so the analysis is scoped to what this task reads and writes.
- **Read set.** No merged criterion can read `docs/loop-engineering/machinery-inventory.md` by its literal path, because the file does not exist at the base.
- **The indirection class.** This means criteria that reach `docs/` through a glob or a constructed path.
  - A Grep over `.shell-team/specs` for check lines that list or glob `docs/` names 15 merged specs. These are mostly scope locks and `git ls-files -- docs`-style reads.
  - A Grep over `bin/` and `tests/` finds no suite or checker that globs `docs/loop-engineering/` or `docs/`.
  - Those merged criteria are not re-run locally, following the operator ruling relayed in T-1191 to T-1196 (no local run of past specs' check lines). This is a disclosed gap. CI (**AC10**) decides for the suites.
- **Merged scope locks.** Every merged scope lock that reads `<base>...HEAD` is already merge-point-scoped, so a new file on a later branch makes no difference.
- **CI steps the diff reaches.** Each is named here with its reason. The diff adds no `bin/`, `tests/`, `templates/` or `.github/` path, so every fixture-suite step and every `shellcheck` step has unchanged inputs.
  - `check-pii-shapes on the PR diff` (`:274`) scans the new document and the records. **AC7** runs the same checker on the document.
  - `check-commit-identity on the PR commits` (`:283`) reads this branch's commits.
  - `Dogfood check-handoff — this repository's own board` (`:58`) and `Dogfood check-board-headings — this repository's own board` (`:258`) read the board this task edits. **AC9** runs `check-handoff.sh`.
  - `Dogfood check-interventions — every committed interventions file in this repository is conformant` (`:245`) reads any interventions file this task adds.
- **Adopter-side artefacts.** None. No generated file, template or prompt block changes.

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| Machinery inventory document (D1–D6) | not met: no new capability for a user | not met: an internal note no command reads | none | an analysis note. Nothing shipped changes behaviour |

The derived tier is none, the maximum of the column. The sprint ships no release (relayed from the coordinating session's planning).

## Assumptions

- **Measured by this role** (Read, Grep and Glob tools on the working tree; branch `feature/754-machinery-inventory`, status clean at session start):
  - `.git/refs/heads/develop` holds `a35e040b6489e5c23e2fca417faa54817d7534fa`, the commit this branch was cut from (relayed), and `refs/remotes/origin/develop` exists in `.git/refs/remotes/origin/`. So **AC8**'s first existence arm is the one exercised here.
  - The tech-lead's relayed counts were re-measured on the working tree. The freeze run measures each count with the `git ls-files` command beside it and records the value here, because tracked status is not readable by this role.
    - `agents/*.md`: 9 files. Freeze run: `git ls-files -- 'agents/*.md' | wc -l`.
    - `skills/*/SKILL.md`: 7 files. Each skill directory holds nothing else. Freeze run: `git ls-files -- 'skills/*/SKILL.md' | wc -l`.
    - `bin/*`: 62 entries, including the extensionless `bin/install`, and no subdirectory. Freeze run: `git ls-files -- 'bin/*' | wc -l`.
    - `templates/prompt-blocks/`: 29 `.md` files plus `registry.txt`. Freeze run: `git ls-files -- 'templates/prompt-blocks/*.md' | wc -l`.
    - `.github/workflows/check-handoff.yml`: 110 lines matching `^\s*- name:`, all in the one workflow file, in one job `lint`. Freeze run: `sed -n 's/^      - name: //p' .github/workflows/check-handoff.yml | sort | uniq -d`, expected empty. This confirms **AC2**'s workflow-side uniqueness premise; a duplicate routes back here as a broken check line.
  - `BEGIN prompt-block:` markers occur in six of the nine agent files (Grep count): `code-reviewer` 2, `engineer` 5, `pm-spec` 3, `qa-verifier` 5, `scrum-master` 2, `tech-lead` 4. **AC4**'s positive control holds.
  - `registry.txt` is read by `bin/check-prompt-sync.sh` and `bin/gen-playbook-blocks.sh`. The coordinator's phrase "the generator's config" is incomplete. The document's sentence names both readers. This is a refinement, not a reversal of the decision that it is not an item.
  - No CI step name carries YAML quoting. The single job has no `name:`-bearing step outside six-space indentation (Grep of `- name:` lines).
  - **Own-coinage tokens.** `### item: `, `- ci-step: `, `- generated-block: `, `- closed-list: ` and `## Platform fact` are coined by this task. The document does not exist before implementation, so every criterion reads a missing file and is red.
- **Settled tie-breaks for D2's ambiguous families** (this role's assumption; surfaced in the hand-off):
  - A `shellcheck` step lints scripts and executes none, so it gets its own `ci:` row. Its row may name the scripts it lints in a note.
  - A suite step whose suite has no `bin/` script as primary subject gets its own `ci:` row. Examples are `machine-tokens`, `errexit-safe`, `bin-exec-bit`, `bin-help`, `local-mode`, `trial-recipe`, `is-span-row-parity`, `gitignore-raw-dumps` and `interventions-reminder`.
  - A suite named after a script attaches to that script's row, for example `tests/check-handoff/run.sh` to `bin/check-handoff.sh`. So does a suite whose subject is a differently named script, for example `codex-skeleton-hygiene` to `bin/codex-capture.sh`, `codex-agents` to `bin/gen-codex-agents.sh` or `bin/check-codex-agents.sh`, and `setup` to `bin/team-setup.sh`. A step reaching two scripts attaches to one of them. The choice is the engineer's and is noted in the row.
- **Relayed, not measurable by this role** (owner: the coordinating session):
  - the issue #754 body (quoted in Summarized sources);
  - the platform fact itself (D6). Its source status is what **AC6** requires the document to declare;
  - the sprint name "machinery-inventory", its goal, and no release;
  - the operator rulings behind the no-local-past-spec-run disclosure and the dev-scaffold review depth.
- **Predicted, unmeasured** (owner: the freeze run). A false prediction routes back here as a broken check line, never as a pass.
  - **Before implementation**, every criterion except **AC9** and **AC10** exits non-zero on its first `test -s` of the document. **AC8** is red on its positive control. **AC9** is green when the board entry is conformant. **AC10** is `SKIP`.
  - `bin/derive-populations.sh` accepts the two `--set` commands as written. Their text carries no control character, and `#`, `'` and `|` are data.
  - **Em-dash items are accepted.** Workflow step names with an em dash pass through `derive-populations.sh`. Its item refusal is `grep -q '[[:cntrl:]]'` (`:374`) under its own `export LC_ALL=C` (`:103`), and in the C locale bytes at or above 0x80 are not in `[[:cntrl:]]`. Read, not run; the specimen below confirms it.
  - The em dash in **AC1**/**AC2**/**AC3** is the same U+2014 bytes the derivation block and the document use.
  - **Line endings.** Neither `.github/workflows/check-handoff.yml` nor any `agents/*.md` file contains a carriage return in this working tree (Grep for `\r`). A CRLF checkout would make **AC2** refuse and **AC4**'s `-->$` miss, so these lines need an LF checkout.
- **Specimen duty (owner: the freeze run).** Before implementation, every criterion stops at its `test -s` opener. That cannot tell a broken command from a missing document.
  - In a scratch git clone under `$TMPDIR` (`git clone --shared`, so `git ls-files` works; an extracted archive is not a repository), generate a throwaway document at `docs/loop-engineering/machinery-inventory.md` from the enumeration commands. It holds:
    - one dummy five-field row per file-backed id, with a `keep` verdict and a `not found` provenance;
    - one `- generated-block:` line per marker in each agent row;
    - one `ci:` row per workflow step;
    - the six shape rows and the `- closed-list:` line;
    - a `## Platform fact` section carrying the D6 label.
  - Run **AC1**–**AC7** there and expect green.
  - Then apply three mutations, each expected red: drop one row (**AC1**), duplicate one `- ci-step:` or `ci:` entry (**AC2**), and blank one field value (**AC3**).
  - Record the results on the board before the freeze. These are also the mutation probes the `no-mechanism` class requires for the check lines this task adds.

## Open questions

None blocking.

## Notes for engineer

- **Shape of the work (from the tech-lead's map, relayed).** Parallel read-only readers may gather candidate rows per group as text. You are the single writer. Before you write a provenance locator or an evidence citation behind a simplify or candidate-for-removal verdict, re-measure it at its source with your own reads. Where it does not resolve, write `not found` and set the verdict to `unknown`.
- **Grammar hygiene.** Only rows may start a line with `### item: `. Only rows and the closed list may start a line with `- ci-step: `, `- generated-block: ` or `- closed-list: `. If the document explains its own grammar, put the examples inside backticks mid-sentence or in an indented code block, never at the start of a line. Otherwise **AC1**, **AC2** or **AC5** read them as data.
- **Row extent.** A row ends at the next line beginning `#`. Do not use `#`-headings inside a row.
- **Line endings.** Commit the document with LF. `derive-populations.sh` refuses an item carrying a carriage return.
- **Locators.** Prefer durable anchors:
  - a `T-NNN` comment marker as `bin/<file>:<line>`;
  - a lessons entry as `lessons: <YYYY-MM-DD> — <heading>`;
  - an issue as `#<N>`.

  `T-001`–`T-111` markers are pre-publication provenance, so cite the file and line carrying the marker, not a spec that is not in this repository.
- **Field 3.** `measured:` cites what was read and what it showed, for example "no recurrence of the class in reviews/ since T-1150". Otherwise write `unmeasured: <reason>`. Never stage a model run.
- **Field 5.** Name the cost concretely: lines of injected context, a CI step's wall clock, an extra hand-off or manual step.
- **Verdicts.** Keep an item for its evidence, not its age. A simplify or candidate-for-removal verdict without a resolvable evidence locator is `unknown`.
- **Platform fact.** If you cite an external primary source, use its `https://` URL. Otherwise write the exact label from D6.
- **No private context.** Use no adopter, operator or workstation names, and no host-local paths or tool names. **AC7** runs the PII-shape checker on the document.
- **Measured-at-ref command check.** Not applicable: the document prints no command labelled as measured at a git ref. If you add any count, derive it with `bin/derive-populations.sh` and embed the block with its `- reproduce:` line.
- **Review depth.** Note depth (Verdict scope). The inline check lines get dev-scaffold depth (operator ruling 2026-08-22, relayed).
