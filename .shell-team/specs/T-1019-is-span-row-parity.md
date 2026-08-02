# One shared fixture set holds both `is_span_row` copies to the same answer

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1019
**Source**: GitHub issue #80 — the whole of it. Filed out of T-1011's merge gate as the regression half of hazard H4.
**Base**: `develop` (the merge point of PR #106 / T-1018). Every `git` anchor below resolves the base ref by the name `develop`; the executing side may substitute the resolved 7-hex literal before freezing if it prefers a pinned ref — a meaning-preserving correction.
**Branch**: `feature/80-is-span-row-shared-fixtures`

## Problem

T-1011 added a `kind` discriminator to the telemetry row schema and taught both reporters to skip non-span rows. `bin/rollup-runs.sh:57` and `bin/cluster-failures.sh:82` each carry their own `is_span_row()` — byte-identical today, deliberately duplicated (T-1011 hazard H4: the sibling-script pattern, no shared helper, so neither script depends on the other). Nothing checks that the two copies still agree. Each suite tests its own script against its own `with-events.jsonl`, and those two fixtures are different files with different contents (H8), so a change applied to one copy and forgotten on the other produces two reporters that disagree about what a span is, over the same input file, with both suites green.

That is the failure the duplication buys and nobody pays for: `bin/rollup-runs.sh` would count a row that `bin/cluster-failures.sh` drops, and `agents/triage-orchestrator.md` invokes both over the same `<runs>/*.jsonl` glob, so the two reports would silently describe different populations.

## Goal

<!-- BEGIN intent-block: T-1019 -->

One committed fixture set — six single-row files, one per discriminator class — is executed against **both** real scripts by one suite, and every class's classification is asserted twice: once per consumer against the frozen expected answer, and once as a parity comparison between the two consumers. A drift applied to exactly one copy of `is_span_row` turns the suite red and the failure line names the drifted script and the fixture. Nothing under `bin/` changes; the two existing suites are untouched and stay green.

### Settled decisions

Each decision below is resolved. Nothing here is left to implementation judgment.

- **D1 — the common oracle: every probe row is a FAILING span, and the two consumers' observable answers are defined as one shared pair of outcomes.** This is the decision the task turns on. The two consumers do not observe alike: `bin/rollup-runs.sh` reports every counted row (`spans: N`), but `bin/cluster-failures.sh` only surfaces a row that is a *failing* span — a counted-but-clean row and a skipped row both print `(no failure clusters found)`. A fixture built from a clean span would therefore make the cluster side unable to distinguish "skipped" from "counted", and every cluster-side assertion would be green no matter what the discriminator did. Every probe row consequently carries `"status":"error"`, which makes it failing under `bin/cluster-failures.sh`'s own condition (status ∈ {error, timeout, stopped}).
  - The two frozen outcomes, over a one-row fixture:
    - **`counted`** ⇔ `bin/rollup-runs.sh`'s stdout contains `spans: 1` **and** `bin/cluster-failures.sh`'s stdout contains `count=1`.
    - **`skipped`** ⇔ `bin/rollup-runs.sh`'s stdout is exactly `(no runs found)` **and** `bin/cluster-failures.sh`'s stdout is exactly `(no failure clusters found)`.
    - Both consumers exit 0 in every case. Any other observation is a divergence and fails (D5).
  - **A probe row may be a hybrid shape, and this is deliberate.** `kind-event.jsonl` carries `"kind":"event"` **and** the span-shaped failing payload. A faithful event row (no `status`, no `verdict`) would be invisible to the cluster consumer even if the discriminator wrongly counted it, which is the same vacuity trap in a different disguise. The hybrid row is what makes "wrongly counted" observable on both sides. It is a discriminator probe, not a claim about valid telemetry: both scripts document that they assume `bin/check-run.sh`-valid input, and the discriminator runs before any schema judgment, so this row exercises exactly the code under test and nothing else.
  - Rejected — a per-consumer oracle (asserting `spans:` on one side and a cluster line on the other, with no shared vocabulary). It is what the two existing suites already do, and it cannot express "the two answers are the same", which is the whole property.
- **D2 — a dedicated suite, `tests/is-span-row-parity/`, with its own `fixtures/` directory; the fixture set exists exactly once.** This matches the repository convention (every suite owns its fixtures) and keeps the two existing suites byte-identical, so their green is untouched evidence rather than co-edited evidence.
  - Rejected — a shared fixture directory read by both existing suites. It introduces a new convention (a cross-suite fixture path) to save six small files, and it would require editing both existing suites, which is precisely the coupling H4 exists to avoid.
  - **Single-source invariant, mechanically checked (AC6):** the probe marker `RUN-ISR-PARITY` occurs in operational files (`bin`, `tests`, `templates`, `skills`, `agents`, `.github`) only under `tests/is-span-row-parity/`, with at least one occurrence required so the check cannot pass vacuously; and each of the six fixture basenames occurs exactly once anywhere under `tests/`.
- **D3 — judgment is black-box execution of the real scripts; there is no white-box extraction at all.** The suite invokes `$REPO_ROOT/bin/rollup-runs.sh` and `$REPO_ROOT/bin/cluster-failures.sh` by path and reads their stdout. It never extracts a function body with `sed` and never uses `eval` — so the worst failure mode of white-box extraction (a zero-line extraction that silently evaluates to nothing and passes) cannot occur, rather than being guarded against after the fact. AC9 locks the absence of `eval`.
  - **The suite must resolve both scripts through `$REPO_ROOT` derived from `${BASH_SOURCE[0]}`** (the shape both existing suites already use), never through `PATH`. AC4/AC5 depend on it: they run the suite from a scratch tree containing only `bin/` and `tests/is-span-row-parity/`, and a `PATH` lookup there would silently exercise the unmutated checkout.
- **D4 — the fixture set is issue #80's six classes, one row per file, attributable by construction.** `tests/*/fixtures/with-events.jsonl` is the source of the real event-row shape: the `kind` field's spelling and its position among the keys are copied from it, so `kind-event.jsonl`'s discriminator input is the real one. Those two existing fixtures keep covering the faithful event-row shape end to end; this task does not duplicate that coverage.

  | fixture (`tests/is-span-row-parity/fixtures/`) | class | expected |
  |---|---|---|
  | `valid-span.jsonl` | a full real-shaped span row, every schema key present, no `kind` key | `counted` |
  | `kind-absent.jsonl` | the base probe row, no `kind` key | `counted` |
  | `kind-span.jsonl` | base row + `"kind":"span"` | `counted` |
  | `kind-event.jsonl` | base row + `"kind":"event"` | `skipped` |
  | `kind-unknown.jsonl` | base row + an unrecognized `kind` value (a quoted string that is neither `span` nor `event`) | `skipped` |
  | `kind-malformed.jsonl` | base row + a `kind` field whose value is not a quoted string (`"kind":null`) | `skipped` |

  - **Everything except the `kind` field is well-formed and identical across the five `kind-*` files**, so a classification difference is attributable to the `kind` field alone. Frozen consequences: the five files reduce to one identical line once the `kind` field is deleted (AC1's mechanical form), the `kind` field is written as `,"kind":<value>` — never the first key, and with no comma or brace inside the value — and every fixture carries `"run_id":"RUN-ISR-PARITY"`, `"status":"error"` and `"phase":"implement"`.
  - `valid-span.jsonl` sits outside that family on purpose: it is the realism control, the row shape `bin/log-run.sh` actually writes, proving the harness reports `counted` for a genuine row and not only for a stripped-down probe.
  - The expected column is asserted, not merely compared between the two consumers. Parity alone would accept two copies drifting in the same direction; asserting the frozen answer catches that too, for these six classes (see the Non-goals' statement of the residual boundary).
- **D5 — a divergence names the drifted script and the fixture.** Every failure line begins `FAIL:` (the shape both existing suites use) and contains the repository-relative path of the script whose observed classification does not match the expected one — `bin/rollup-runs.sh` or `bin/cluster-failures.sh` — together with the fixture's basename. When the two consumers disagree with each other, the parity failure names both. An observation that is neither `counted` nor `skipped` (unexpected stdout, or a non-zero exit) is a failure of that consumer, named the same way, never a skip.
- **D6 — the suite is registered in CI, and the recipe records it.** `.github/workflows/check-handoff.yml` is the authoritative suite list: an unregistered suite never runs, which would make every criterion below a local-only claim. The suite is added to the `shellcheck` argument list *and* gets its own `run:` step. `.shell-team/test-recipe.md`'s `## Appended by tasks` section gains a `T-1019` entry naming the suite and the mutation procedure.

## Non-goals

- **Extracting `is_span_row` into a shared helper.** T-1011 hazard H4's rationale stands: `bin/cluster-failures.sh` is a sibling script that deliberately does not depend on `bin/rollup-runs.sh` (T-044 design decision (a)). This task makes the duplication *safe*, it does not remove it, and a review finding that proposes the extraction is out of contract.
- **Any behavior change in `bin/`.** Not one byte changes under `bin/`. No new flag, no new output line, no change to either discriminator, no shared source file.
- **Re-opening the discriminator's tolerance.** Whitespace inside the JSON (`"kind" : "span"`), duplicate `kind` keys and key-order permutations were waived in T-1011; they are not reopened here, no fixture covers them, and a finding grounded in one of them is out of contract.
- **Editing the two existing suites or their fixtures.** `tests/rollup-runs/**` and `tests/cluster-failures/**` are byte-identical to the base ref (AC10). Their `with-events.jsonl` files stay the coverage of the faithful event-row shape.
- **The known detection boundary, stated precisely and accepted.** If both copies receive the *same* change simultaneously, parity holds by construction and the parity half of this suite cannot see it. The expected-answer half narrows that: a same-direction change that alters any of the six classes' classifications is caught. What remains undetectable is a same-direction change whose effect falls entirely outside the six classes — accepted as an intended limit, not a defect to design around.
- **Registering the suite as a machine-token consumer.** `tests/machine-tokens/run.sh` registers `bin/`, `templates/` and `agents/` files only; no test suite is registered there, and this one is not the exception.
- **Validating the probe fixtures with `bin/check-run.sh`.** The hybrid probe row (D1) is deliberately not a valid telemetry row, and no criterion asserts that it is.
- **A CHANGELOG entry, a version bump, or any adopter-facing document change** (`README*`, `docs/`, `CONTRIBUTING.md`, `templates/`).

## Acceptance criteria

Base ref for every `git` anchor is `develop`. Every check runs from the repository root, uses an explicit `mktemp` template, names every file it reads explicitly, and writes only under `$TMPDIR`. Where a criterion greps for an *absent* token, the file's readability is asserted first, so an unreadable file can never read as a clean pass.

- [ ] **AC1** The suite and all six fixtures exist at the frozen paths; each fixture holds exactly one non-empty line carrying the frozen probe tokens (`"run_id":"RUN-ISR-PARITY"`, `"status":"error"`, `"phase":"implement"`); and the five `kind-*` fixtures are identical once the `kind` field is deleted — the mechanical form of D4's attributability rule.
  - check: rc=0; D=tests/is-span-row-parity/fixtures; test -r tests/is-span-row-parity/run.sh || exit 1; for f in valid-span kind-absent kind-span kind-event kind-unknown kind-malformed; do p="$D/$f.jsonl"; if [ ! -r "$p" ]; then rc=1; continue; fi; n=$(grep -c . "$p" || true); test "$n" = "1" || rc=1; grep -qF -- '"run_id":"RUN-ISR-PARITY"' "$p" || rc=1; grep -qF -- '"status":"error"' "$p" || rc=1; grep -qF -- '"phase":"implement"' "$p" || rc=1; done; if [ "$rc" -eq 0 ]; then u=$(cat "$D/kind-absent.jsonl" "$D/kind-span.jsonl" "$D/kind-event.jsonl" "$D/kind-unknown.jsonl" "$D/kind-malformed.jsonl" | sed 's/,"kind":[^,}]*//' | sort -u | grep -c . || true); test "$u" = "1" || rc=1; fi; test "$rc" -eq 0
- [ ] **AC2** D4's expected column holds against the real scripts, measured independently of the suite: all twelve observations (six fixtures × two consumers) match D1's frozen oracle — `counted` for `valid-span`, `kind-absent`, `kind-span`; `skipped` for `kind-event`, `kind-unknown`, `kind-malformed`, with the two `skipped` sentinels compared for full-output equality rather than containment.
  - check: rc=0; D=tests/is-span-row-parity/fixtures; for f in valid-span kind-absent kind-span; do p="$D/$f.jsonl"; if [ ! -r "$p" ]; then rc=1; continue; fi; bash bin/rollup-runs.sh "$p" | grep -qF -- 'spans: 1' || rc=1; bash bin/cluster-failures.sh "$p" | grep -qF -- 'count=1' || rc=1; done; for f in kind-event kind-unknown kind-malformed; do p="$D/$f.jsonl"; if [ ! -r "$p" ]; then rc=1; continue; fi; test "$(bash bin/rollup-runs.sh "$p")" = '(no runs found)' || rc=1; test "$(bash bin/cluster-failures.sh "$p")" = '(no failure clusters found)' || rc=1; done; test "$rc" -eq 0
- [ ] **AC3** The suite is green, and it really executed all six classes: the six frozen assertion ids — `parity-valid-span`, `parity-kind-absent`, `parity-kind-span`, `parity-kind-event`, `parity-kind-unknown`, `parity-kind-malformed` — are present in the suite file **and** in its own output, so a suite that silently skips a fixture cannot pass this criterion.
  - check: rc=0; S=tests/is-span-row-parity/run.sh; test -r "$S" || exit 1; out=$(bash "$S" 2>&1) || rc=1; for id in parity-valid-span parity-kind-absent parity-kind-span parity-kind-event parity-kind-unknown parity-kind-malformed; do grep -qF -- "$id" "$S" || rc=1; printf '%s\n' "$out" | grep -qF -- "$id" || rc=1; done; test "$rc" -eq 0
- [ ] **AC4** Mutation-based anti-vacuity, direction 1: in a scratch copy of `bin/` plus the new suite (never the working tree), the suite is first proved green — the positive control that the scratch tree runs at all — then **only** `bin/rollup-runs.sh`'s discriminator is patched to accept any `kind` value; the suite must then exit non-zero and its output must name `bin/rollup-runs.sh` and `kind-event.jsonl`. The patch is asserted to have applied, so a silently-failed `sed` cannot make this pass.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1019a.XXXXXX"); rc=0; mkdir -p "$d/tests" && cp -R bin "$d/bin" && cp -R tests/is-span-row-parity "$d/tests/is-span-row-parity" || rc=1; if [ "$rc" -eq 0 ]; then bash "$d/tests/is-span-row-parity/run.sh" >/dev/null 2>&1 || rc=1; fi; if [ "$rc" -eq 0 ]; then sed 's/== "span"/!= "zzz"/' "$d/bin/rollup-runs.sh" > "$d/p.sh" && mv "$d/p.sh" "$d/bin/rollup-runs.sh"; grep -qF -- '!= "zzz"' "$d/bin/rollup-runs.sh" || rc=1; grep -qF -- '== "span"' "$d/bin/cluster-failures.sh" || rc=1; fi; if [ "$rc" -eq 0 ]; then out=$(bash "$d/tests/is-span-row-parity/run.sh" 2>&1); mrc=$?; test "$mrc" -ne 0 || rc=1; printf '%s\n' "$out" | grep -qF -- 'bin/rollup-runs.sh' || rc=1; printf '%s\n' "$out" | grep -qF -- 'kind-event.jsonl' || rc=1; fi; rm -rf "$d"; test "$rc" -eq 0
- [ ] **AC5** Mutation-based anti-vacuity, direction 2: the same procedure with the patch applied to `bin/cluster-failures.sh` only — suite green first, then red, naming `bin/cluster-failures.sh` and `kind-event.jsonl`, with `bin/rollup-runs.sh` asserted unpatched in the scratch copy.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1019b.XXXXXX"); rc=0; mkdir -p "$d/tests" && cp -R bin "$d/bin" && cp -R tests/is-span-row-parity "$d/tests/is-span-row-parity" || rc=1; if [ "$rc" -eq 0 ]; then bash "$d/tests/is-span-row-parity/run.sh" >/dev/null 2>&1 || rc=1; fi; if [ "$rc" -eq 0 ]; then sed 's/== "span"/!= "zzz"/' "$d/bin/cluster-failures.sh" > "$d/p.sh" && mv "$d/p.sh" "$d/bin/cluster-failures.sh"; grep -qF -- '!= "zzz"' "$d/bin/cluster-failures.sh" || rc=1; grep -qF -- '== "span"' "$d/bin/rollup-runs.sh" || rc=1; fi; if [ "$rc" -eq 0 ]; then out=$(bash "$d/tests/is-span-row-parity/run.sh" 2>&1); mrc=$?; test "$mrc" -ne 0 || rc=1; printf '%s\n' "$out" | grep -qF -- 'bin/cluster-failures.sh' || rc=1; printf '%s\n' "$out" | grep -qF -- 'kind-event.jsonl' || rc=1; fi; rm -rf "$d"; test "$rc" -eq 0
- [ ] **AC6** D2's single-source invariant: among operational files, the probe marker occurs only under `tests/is-span-row-parity/` (at least one occurrence required, so the check cannot pass by the marker not existing), and each of the six fixture basenames occurs exactly once anywhere under `tests/`.
  - check: rc=0; hits=$(grep -rl -- 'RUN-ISR-PARITY' bin tests templates skills agents .github 2>/dev/null | sort); test -n "$hits" || rc=1; if [ "$rc" -eq 0 ]; then bad=$(printf '%s\n' "$hits" | grep -v '^tests/is-span-row-parity/' | grep -c . || true); test "$bad" = "0" || rc=1; fi; for f in valid-span kind-absent kind-span kind-event kind-unknown kind-malformed; do n=$(find tests -name "$f.jsonl" | grep -c . || true); test "$n" = "1" || rc=1; done; test "$rc" -eq 0
- [ ] **AC7** D6's CI registration: `.github/workflows/check-handoff.yml` names `tests/is-span-row-parity/run.sh` exactly twice — once in the `shellcheck` argument list and once as its own `run:` step — so the suite is both linted and executed by the authoritative list.
  - check: rc=0; W=.github/workflows/check-handoff.yml; test -r "$W" || exit 1; grep -qF -- 'tests/is-span-row-parity/run.sh' "$W" || rc=1; grep -qE '^[[:space:]]+run: bash tests/is-span-row-parity/run\.sh$' "$W" || rc=1; n=$(grep -oF -- 'tests/is-span-row-parity/run.sh' "$W" | grep -c . || true); test "$n" = "2" || rc=1; test "$rc" -eq 0
- [ ] **AC8** The new suite is shellcheck-clean (CI pins 0.11.0; the local run must use the same version — see `.shell-team/test-recipe.md`).
  - check: test -r tests/is-span-row-parity/run.sh || exit 1; shellcheck tests/is-span-row-parity/run.sh
- [ ] **AC9** D3's negative lock: the suite contains no `eval`, so no silent-pass extraction path exists; positive control — it names both real scripts, proving the file was read and that judgment is black-box.
  - check: rc=0; S=tests/is-span-row-parity/run.sh; test -r "$S" || exit 1; if grep -qE '(^|[^[:alnum:]_])eval([^[:alnum:]_]|$)' "$S"; then rc=1; fi; grep -qF -- 'bin/rollup-runs.sh' "$S" || rc=1; grep -qF -- 'bin/cluster-failures.sh' "$S" || rc=1; test "$rc" -eq 0
- [ ] **AC10** Preservation lock (expected green at the base ref, and it must stay green): not one byte changes under `bin/`, `tests/rollup-runs/` or `tests/cluster-failures/`; both `bin/` scripts are still present; and both existing suites still pass.
  - check: rc=0; test -z "$(git diff --name-only develop -- bin tests/rollup-runs tests/cluster-failures)" || rc=1; test -r bin/rollup-runs.sh || rc=1; test -r bin/cluster-failures.sh || rc=1; bash tests/rollup-runs/run.sh >/dev/null || rc=1; bash tests/cluster-failures/run.sh >/dev/null || rc=1; test "$rc" -eq 0
- [ ] **AC11** Scope lock: the branch's changed-and-added file set (the union of tracked changes and untracked additions, since the fixtures are untracked at freeze time) contains every required file and nothing outside the allow-list in Notes for engineer. **This criterion is merge-point-scoped and is expected to go stale after merge** — once later work lands on `develop`, `git diff develop` no longer describes this task. Do not widen its base-ref resolution or re-derive it per rework round.
  - check: d=$(mktemp -d "${TMPDIR:-/tmp}/t1019c.XXXXXX"); git diff --name-only develop > "$d/raw.txt"; git ls-files --others --exclude-standard >> "$d/raw.txt"; sort -u "$d/raw.txt" > "$d/actual.txt"; printf '%s\n' tests/is-span-row-parity/run.sh tests/is-span-row-parity/fixtures/valid-span.jsonl tests/is-span-row-parity/fixtures/kind-absent.jsonl tests/is-span-row-parity/fixtures/kind-span.jsonl tests/is-span-row-parity/fixtures/kind-event.jsonl tests/is-span-row-parity/fixtures/kind-unknown.jsonl tests/is-span-row-parity/fixtures/kind-malformed.jsonl .github/workflows/check-handoff.yml .shell-team/test-recipe.md .shell-team/specs/T-1019-is-span-row-parity.md .shell-team/todo.md | sort > "$d/required.txt"; miss=$(comm -13 "$d/actual.txt" "$d/required.txt" | grep -c . || true); extra=$(comm -23 "$d/actual.txt" "$d/required.txt" | grep -vE '^\.shell-team/(provenance|reviews|interventions)/T-1019\.md$' | grep -c . || true); rm -rf "$d"; test "$miss" = "0" && test "$extra" = "0"
- [ ] **AC12** `.shell-team/test-recipe.md`'s `## Appended by tasks` section carries a `T-1019` entry naming the new suite, so the next task inherits the procedure rather than re-deriving it.
  - check: rc=0; R=.shell-team/test-recipe.md; test -r "$R" || exit 1; grep -qF -- '## Appended by tasks' "$R" || rc=1; awk '/^## Appended by tasks/{f=1} f' "$R" | grep -qF -- 'T-1019' || rc=1; awk '/^## Appended by tasks/{f=1} f' "$R" | grep -qF -- 'tests/is-span-row-parity/run.sh' || rc=1; test "$rc" -eq 0
- [ ] **AC13** The task's records exist and the board lints, including the structural check that this entry was a pure insertion and the PII-shape check over the branch diff.
  - check: test -r .shell-team/provenance/T-1019.md && test -r .shell-team/reviews/T-1019.md && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" && bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop && bash bin/check-pii-shapes.sh --base develop
- [ ] **AC14** Every suite and dogfood step in `.github/workflows/check-handoff.yml` was run locally, in the order the workflow lists them, and the two mutation experiments of AC4/AC5 were additionally performed by hand on a scratch copy — observed red, restored, observed green — with both reported in the hand-off. No `check:` — no command can prove that a command was run. `SKIP` is its expected `check-acs.sh` result.

## Input space

**Reachable input classes** — what real usage produces, and the implementation must classify correctly:

- Rows written by `bin/log-run.sh`, the single canonical writer: a span row with **no `kind` key** and an event row with **`"kind":"event"`**. These are the only two shapes committed telemetry contains today, and they are the classes `valid-span.jsonl` / `kind-absent.jsonl` / `kind-event.jsonl` stand for.
- A row carrying an explicit `"kind":"span"`. Not written today, but valid under T-1011's schema and accepted by `bin/check-run.sh`, so any writer may emit it.
- A row whose `kind` value is an unrecognized quoted string. Reachable the moment a future task adds a third row kind and updates one consumer before the other — the exact condition T-1011 D1's fail-safe rule exists for, and the exact condition this suite exists to notice.
- A `kind` field whose value is not a quoted string (`null`, a number). Reachable from a hand-edited runs file, a partially-written line, or a writer that omits a value; both scripts must skip it rather than crash or count it.
- Failing spans (`status` ∈ {error, timeout, stopped}, `verdict` ∈ {FAIL, REQUEST_CHANGES}) — the only span population the cluster consumer surfaces at all, which is why D1 builds every probe from one.
- Single-row files. Both scripts accept one or more files of one or more rows; a one-row file is the smallest real input and makes `spans: 1` / `count=1` unambiguous.
- The hybrid probe row (event-discriminated, span-payload-bearing) is declared **in scope for this suite** by D1, as the only shape that makes a wrongly-counted event row observable at both consumers. It is a discriminator input, not a claim of schema validity.

**Out-of-scope synthetic extremes** — declined deliberately; a finding grounded only in one of these is out of contract:

- Whitespace variants inside the JSON (`"kind" : "span"`, a newline between key and value), duplicate `kind` keys, and key-order permutations. Waived in T-1011 and not reopened here.
- A `kind`-shaped token smuggled inside another field's value through escaped quotes, and Unicode confusables or full-width spellings of `span` / `event`. The discriminator's boundary anchoring is T-1011's decision, tested there; escalating exotic near-misses is not an open finding class here.
- Multi-row, multi-file and multi-run inputs, cross-file grouping, ranking, tie-breaks and every other reporting behavior of either script. Those are the two existing suites' subject, and this suite deliberately observes only two tokens of each consumer's output.
- Scale and performance: thousands of rows, megabyte lines, arbitrarily long `kind` values, deeply nested values, binary bytes.
- CRLF line endings, empty lines and unreadable/absent input files. Both scripts already handle these and both existing suites already assert the usage-error paths.
- Any behavior of `bin/check-run.sh`, `bin/log-run.sh` or `bin/rollup-track.sh` over these fixtures. No writer-side or validator-side input class is in scope, because no `bin/` file changes.

<!-- END intent-block: T-1019 -->

## Body-to-AC correspondence

Every normative directive stated in the body above, mapped to the criterion that enforces it or to an explicit exemption with a reason.

| Body directive | Where | AC / disposition |
|---|---|---|
| Every probe row is a failing span (`"status":"error"`) | D1 | AC1 (the token is asserted in all six fixtures), AC2 (the cluster side actually reports `count=1` for the counted ones — impossible for a clean row) |
| `counted` / `skipped` are the shared two-consumer oracle | D1 | AC2 (independent measurement of all twelve observations), AC3 (the suite asserts the same pair) |
| `skipped` is full-output equality against the two sentinels | D1 | AC2 (`test "$(…)" = '(no runs found)'`, likewise for the cluster sentinel) |
| The event probe row is a hybrid, deliberately | D1 | AC1 (identical-except-`kind` family includes `kind-event.jsonl`), AC4/AC5 (the mutation is detected *at* that fixture) |
| A per-consumer oracle is rejected | D1 | `info-only (not promoted to AC)` — a rejection of an alternative design; AC2/AC3's shared vocabulary is the positive form, and no command can assert that a different design was not chosen |
| Dedicated suite `tests/is-span-row-parity/` with its own fixtures | D2 | AC1, AC3, AC11 |
| A shared cross-suite fixture directory is rejected | D2 | AC6 (each basename occurs exactly once under `tests/`), AC10 (neither existing suite is edited) |
| The fixture set exists exactly once | D2 | AC6 |
| Judgment is black-box; no extraction, no `eval` | D3 | AC9 |
| A zero-line extraction must fail closed | D3 | `info-only (not promoted to AC)` — the design removes the extraction path entirely, so there is no extraction to fail closed; AC9's zero-`eval` lock is the assertable form of the same guarantee |
| The suite resolves both scripts via `$REPO_ROOT`, not `PATH` | D3 | AC4/AC5 — the scratch tree has no `PATH` entry for either script, so a `PATH`-resolving suite would exercise the unmutated checkout and fail to go red |
| The six classes and their expected classifications | D4 | AC2 (the frozen table, measured), AC3 (the six assertion ids) |
| Everything except `kind` is well-formed and identical across the five `kind-*` fixtures | D4 | AC1 (the delete-the-`kind`-field reduction to one unique line) |
| `kind` is written as `,"kind":<value>`, never first, no comma/brace inside | D4 | AC1 — the reduction only succeeds for that layout, so the constraint is enforced by the check that depends on it |
| `valid-span.jsonl` is the realism control | D4 | AC2 (it must measure `counted` through both consumers) |
| `with-events.jsonl` is the source of the real event-row shape | D4 | `info-only (not promoted to AC)` — provenance of a byte pattern; no command can distinguish a copied spelling from an identically-typed one. AC10 keeps both source fixtures byte-identical so the reference stays intact |
| The expected answer is asserted, not just parity | D4 | AC2, AC3 |
| A divergence names the drifted script and the fixture | D5 | AC4, AC5 (both directions assert the two names appear in the failing output) |
| An unexpected observation is a failure, never a skip | D5 | AC3 (all six ids must appear in the output — a skipped case cannot be silent), AC4/AC5 (non-zero exit required) |
| CI registration: shellcheck arg list + own `run:` step | D6 | AC7 |
| `.shell-team/test-recipe.md` gains a `T-1019` entry | D6 | AC12 |
| No shared-helper extraction | Non-goals | AC10 (`bin/` byte-identical — an extraction cannot happen without touching it) |
| No behavior change in `bin/`; not one byte | Non-goals | AC10, AC11 |
| Whitespace / duplicate-key tolerance not reopened | Non-goals | `info-only (not promoted to AC)` — a scope declaration recorded in the Input space's out-of-scope list; the assertable half is AC10 (`bin/` unchanged, so no tolerance can have been added) |
| The two existing suites and their fixtures are untouched | Non-goals | AC10, AC11 |
| The both-copies-patched boundary is an accepted limit | Non-goals | `info-only (not promoted to AC)` — a declared residual. AC4/AC5 deliberately patch exactly one copy each; asserting the undetectable case would require asserting a failure to detect, which is not a property worth locking |
| Not registered as a machine-token consumer | Non-goals | AC11 (`tests/machine-tokens/**` is outside the allow-list, so any registration change fails the scope lock) |
| Probe fixtures are not validated by `bin/check-run.sh` | Non-goals | `info-only (not promoted to AC)` — the absence of a criterion is the enforcement; no AC invokes the validator on these fixtures |
| No CHANGELOG, version bump or adopter-facing doc change | Non-goals | AC11 |
| `bin/` stays pure bash, zero-dependency, shellcheck-clean | repo contract | AC8 (the one new script), AC10 (`bin/` unchanged) |
| Checkers fail closed; a check cannot pass on an unreadable file | repo contract | AC1, AC3, AC6, AC7, AC8, AC9, AC12 each assert readability (or a non-empty result) before any negative grep |
| The full CI list is run locally, in order; the mutations are run by hand | Notes for engineer | AC14 (runtime, `SKIP` by design) |

## Assumptions

- **pm-spec has no shell in this role, so no `check:` line here has been executed.** The executing side runs all 13 live `check:` lines against the pre-implementation tree (base + this spec + the board entry), corrects anything mechanically broken or vacuously passing (meaning preserved), records the measured shape, and only then records `- intent-hash (v1): <40-hex>`. Verify, then correct, then freeze.
- **Predicted pre-implementation shape, recorded so a mismatch is itself a finding: PASS AC10 (the only preservation lock); FAIL AC1–AC9, AC11, AC12, AC13; SKIP AC14.** Every failure is an artifact-does-not-exist failure. If AC6 or AC11 passes at the base ref, that is a vacuity to fix before freezing, not a pleasant surprise.
- **Shapes the executing side should confirm at the freeze**, disclosed rather than left to be discovered:
  1. `git diff --name-only develop -- …` resolving `develop` locally (AC10/AC11), and `bin/check-board-headings.sh … --base develop` / `bin/check-pii-shapes.sh --base develop` likewise (AC13). All three forms are copied from T-1014/T-1017, where they passed.
  2. `grep -oF … | grep -c .` returning the intended count on the host's `grep` (AC6, AC7). The host `PATH` `grep` has been observed to be a non-GNU implementation in this repository before.
  3. `sed 's/== "span"/!= "zzz"/'` matching exactly one line in each script. Read statically while drafting: the string `== "span"` occurs once in `bin/rollup-runs.sh` (line 60) and once in `bin/cluster-failures.sh` (line 85), inside `is_span_row` in both. Not executed. If a future edit adds a second occurrence, AC4/AC5's patch assertion still holds, but the mutation stops being minimal — re-anchor rather than widen.
  4. AC4/AC5's scratch-tree run (`cp -R bin` plus the one suite directory) completing inside `check-acs.sh`'s 120s per-check cap. Each runs the suite twice plus a `cp -R` of `bin/`; if either exceeds the cap, split the criterion into the green-control half and the red half rather than raising the cap.
- **This spec is self-hosting and quotes strings it also asserts.** AC6's marker grep is scoped to six operational directories and never to the repository root, so this file's own mention of `RUN-ISR-PARITY` cannot trip it. AC9's `eval` grep is scoped to one named file for the same reason.
- **No `check:` value begins or ends with a backtick** (`bin/check-acs.sh` rejects that shape fail-closed), and no AC label carries a suffix glued to its digits.

## Open questions

None blocking.

## Notes for engineer

**Read `bin/rollup-runs.sh:51-64` and `bin/cluster-failures.sh:77-89` side by side before you start**, and read T-1011's hazard H4 in `.shell-team/specs/T-1011-telemetry-event-rows.md`. The two copies are byte-identical today; keeping them that way is not your job, proving that a divergence is *noticed* is.

**Run every suite and dogfood step in `.github/workflows/check-handoff.yml`, in the order the workflow lists them** (`CONTRIBUTING.md` §"Run the suites locally before pushing"), and append the procedure you establish to `.shell-team/test-recipe.md`.

Scope-lock allow-list (the files you may change). Required:

```
tests/is-span-row-parity/run.sh                              (new)
tests/is-span-row-parity/fixtures/valid-span.jsonl           (new)
tests/is-span-row-parity/fixtures/kind-absent.jsonl          (new)
tests/is-span-row-parity/fixtures/kind-span.jsonl            (new)
tests/is-span-row-parity/fixtures/kind-event.jsonl           (new)
tests/is-span-row-parity/fixtures/kind-unknown.jsonl         (new)
tests/is-span-row-parity/fixtures/kind-malformed.jsonl       (new)
.github/workflows/check-handoff.yml                          (shellcheck arg list + one run: step)
.shell-team/test-recipe.md                                   (## Appended by tasks)
.shell-team/specs/T-1019-is-span-row-parity.md
.shell-team/todo.md
```

Permitted in addition, not required: `.shell-team/provenance/T-1019.md`, `.shell-team/reviews/T-1019.md`, `.shell-team/interventions/T-1019.md`.

Known pitfalls, each of which has cost this repository a round before:

- **`grep -c` under `set -euo pipefail`.** `x="$(producer | grep -c PATTERN)"` aborts the whole suite the moment the count is genuinely `0` — `grep -c` exits 1 when nothing matched, `pipefail` propagates it, and `set -e` kills the script before your `[ "$x" -eq 0 ]` assertion runs (T-1016). Append `|| true` to the pipeline itself, never to the assignment, and keep the explicit assertion immediately after.
- **`mktemp` needs an explicit template**: `mktemp -d "${TMPDIR:-/tmp}/name.XXXXXX"`. The bare and `-t` forms ignore `$TMPDIR` on macOS (T-112).
- **Mutation experiments run on a `$TMPDIR` clone, never the working tree.** Copy `bin/` and the new suite directory into a scratch root, patch there, run there, delete it. A reviewer reading the working tree while you mutate it will report defects that do not exist.
- **`tests/errexit-safe/run.sh` pins `file:line:content` for several `bin/` scripts.** This task edits no `bin/` file, so no pin shifts — but if you find yourself about to touch one, stop: that file is not on the allow-list and editing it fails AC11.
- **Both existing suites' `FAIL:`/`PASS:` shape is the house style** (`fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }`). Reuse it, and make the failure text carry the script path and the fixture basename that D5 requires — AC4/AC5 grep for exactly those two strings.
- Suite output must print each of the six frozen assertion ids on its own success line (AC3 greps the output as well as the file), so an id that only exists in a comment fails the criterion.
