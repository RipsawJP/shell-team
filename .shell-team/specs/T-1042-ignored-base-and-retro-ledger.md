# An ignored base dir announces itself instead of silently voiding the commit-immediately discipline, and the retro ledger stops under-reporting a review trail it can see

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1042
**Base**: `6439eb6` — relayed as the tip of T-1041's branch (`feature/166-freeze-ux`, PR #183) and this branch's real branch point; sprint v1.7.0 train car 4. Every `git` anchor inside the intent block resolves that literal. **Relayed, not measured by this role** — see `## Assumptions` item 1; re-measure before the freeze.
**Branch**: `feature/167-gitignored-base` — PR base stays `develop`, PR held open for the sprint batch merge (stacked on #183).
**Authoring sources**: in-repo, read directly with a file-reading tool — `bin/team-paths.sh`, `bin/team-init.sh`, `bin/retro-inputs.sh`, `bin/codex-capture.sh`, `bin/check-pii-shapes.sh`, `tests/team-paths/run.sh`, `tests/team-init/run.sh`, `tests/retro-inputs/run.sh`, `tests/gitignore-raw-dumps/run.sh`, `templates/prompt-blocks/retro-inputs.md`, `templates/prompt-blocks/registry.txt`, `agents/scrum-master.md`, `README.md`, `README.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, the repository root `.gitignore`, `.shell-team/test-recipe.md`, `.shell-team/todo.md` and `.shell-team/specs/T-1040-frozen-repair-batch.md` (for the frozen-block and check-line conventions).

## Problem

Two independent under-reporting defects, both of the same shape: a documented discipline reports success while doing nothing.

**Half A.** In an adopter repo whose resolved base dir is listed in that repo's `.gitignore`, everything the loop writes there is untracked. The producer disciplines that say "commit this record immediately" (interventions, T-1002; provenance, T-074) cannot hold, because staging an ignored path is a no-op. Both fail-closed seam gates still pass — they validate file *conformance*, not durability — and `git status --short` stays clean, so the T-073 uncommitted-diff guard reports success too. The entire decision record for a task therefore exists only in the working tree, and nothing anywhere says so. Ignoring the base dir is a **supported adopter choice** (`README.md` lines 57-60, `docs/adopting.md` lines 34-49); what is wrong is that the choice silently voids a documented discipline while every gate stays green.

**Half B.** `bin/retro-inputs.sh` reports the `review-artifacts` input as `empty` — "consulted and held nothing" — for a reviews directory that in fact holds material, because it counts only names ending in `.md`. This is not an adopter-specific quirk: the plugin's **own** review capture publishes `<reviews_dir>/<stem>.txt` and `<reviews_dir>/<stem>.jsonl` (`bin/codex-capture.sh` lines 275-276, read directly). A cycle whose review output is exactly those two files is reported as having no review trail at all. The retro's whole point is that `empty` and `unavailable` are never substituted for one another; a false `empty` is the same failure in the other direction, and an agent that trusts the ledger records an absence that is not there.

**The relayed mechanism for the second half of the adopter report is false, and is corrected here rather than absorbed.** The report states that `specs` "is resolved against the default location rather than through `team-paths.sh`". Measured at `6439eb6`: `bin/retro-inputs.sh` line 454 reads `report_dir_input specs "${TEAM_SPECS_DIR:-}" ".md" "spec files"`, and `TEAM_SPECS_DIR` is set by the resolver invocation at line 372. The path **does** go through `team-paths.sh`. Three candidate mechanisms were weighed against the code, and the discrimination is recorded in `### Settled decisions` D1 — the outcome is that the `.md`-only suffix is a measured first-party defect and is fixed, while the `specs` symptom's only self-consistent mechanism is the legacy layout's documented split root (`docs/specs`), which is out of scope; what *is* fixed alongside it is the documentation contradiction inside `bin/team-paths.sh` that would lead an adopter to build a legacy layout the resolver then declines to detect.

## Summarized sources

One line per document whose facts this spec restates, naming the distinction carried over. This section sits outside the intent block deliberately; naming a further source during a rework is an ordinary edit, not a re-freeze.

- **GitHub issue #167 — RELAYED verbatim into this role's task prompt by the coordinating session, not opened.** pm-spec has no network or `gh` access. Distinctions carried over: that the ignored-base condition voids the two commit-immediately disciplines while *both* seam gates and the uncommitted-diff guard still report success (three named, distinct green signals, not one); that ignoring the base dir is a legitimate adopter choice rather than a defect in the adopter repo; and that the issue *suggests* `git check-ignore` and an acknowledgement flag without settling either. The suggestion is treated as a suggestion: D5 declines the flag with reasons.
- **The GitHub issue #67 comment of 2026-08-06 — RELAYED verbatim, not opened; issue #67 itself stays OPEN and only its `bin/retro-inputs.sh` slice ships here.** Distinctions carried over: the two symptoms are reported as *different statuses* (`specs` → `unavailable`; `review-artifacts` → `empty`), which is the discriminating fact D1 uses, and the consequence named is a **false absence** an agent would have trusted, not merely an inaccurate count. **Its stated mechanism for the `specs` symptom was re-measured against `bin/retro-inputs.sh` and does not hold** (see `## Problem` and D1); the `review-artifacts` mechanism was re-measured and does hold.
- **The host's sprint v1.7.0 planning GO of 2026-08-06 — itself a RELAY**, held by the coordinating session, which is the authority for this task existing, for its two-half scope, and for the exclusions listed under `## Non-goals`.
- `bin/retro-inputs.sh` — read directly. Distinctions carried over: `unavailable` is the default for every ledger line and `read`/`empty` are promotions requiring an affirmative determination (header lines 24-29); the ledger line grammar is exactly three ` — `-separated fields (lines 61-64); the directory enumeration glob is `"$dir"/*` under `nullglob` **without** `dotglob`, so dotfiles are already excluded; and the resolver is invoked at line 372 with no `--root`.
- `bin/codex-capture.sh` lines 267-280 — read directly. Distinction carried over: the canonical published names are `<stem>.txt` and `<stem>.jsonl` inside the resolved reviews dir, and the pre-publish temps are `.codex-capture.<stem>.*` **dotfiles**. This is the measured ground for D3 — the producer that writes non-`.md` material into that directory is first-party, not hypothetical.
- `bin/team-paths.sh` — read directly. Distinctions carried over: legacy detection is anchored on the file `tasks/loops/shell-team.contract.yaml` at line 146, while the header at lines 14-18 and `print_help` at line 61 state the marker as a bare `tasks/loops/` directory; `docs/specs` is the one path the legacy layout keeps outside the base dir (lines 26-28); and every emitted path is **ROOT-relative** in all three modes, so `--root` changes which layout is detected but never the shape of what is printed.
- The repository root `.gitignore` — read directly. Distinction carried over: this repository ignores `.shell-team/reviews/*.txt`, `*.json` and `*.jsonl` while re-including `.shell-team/` itself via `!.shell-team/`, so opening the `review-artifacts` extension counts files here that are deliberately never committed — a working-tree count, which is what a retro's material actually is.
- `docs/adopting.md` lines 40-56 and `.shell-team/test-recipe.md` lines 47-53 — read directly. Distinction carried over: the pinning discipline is "pin the excludes file **explicitly**", not "always pin it to `/dev/null`" — which is what lets one fixture pin a hostile excludes file to prove the production notice honours global excludes.
- `bin/check-pii-shapes.sh` lines 296-314 — read directly. Distinction carried over: `RE_HOME_PATH` matches `/(Users|home)/<name>`, so an absolute path emitted into a git-tracked retro is a PII-shaped finding — the measured ground for D4's "the ledger keeps printing repo-root-relative paths".
- `templates/prompt-blocks/retro-inputs.md` and `templates/prompt-blocks/registry.txt` line 39 — read directly. Distinction carried over: the canonical block carries **only** the nine input ids, the three statuses and the empty-vs-unavailable sentence — no suffix, no extension, no path — and is mirrored into four consumers in `contain` mode. Opening a suffix therefore moves nothing the block declares (D6).
- `agents/scrum-master.md` lines 25-50 — read directly. Distinction carried over: the agent's own review-artifact lookup is hardcoded to `tasks/reviews/<task-id>.md`, which is the *non-`retro-inputs.sh`* surface of #67 and stays out of scope; its line 25 claim that the script "resolves every artefact path through `bin/team-paths.sh`" stays true after this task.

## Goal

<!-- BEGIN intent-block: T-1042 -->

An operator whose resolved base dir is git-ignored and holds no tracked file is told so, once, on stderr, by both `bin/team-init.sh` and `bin/team-paths.sh --print`, in one message body that is byte-identical between the two scripts and states that the loop's records cannot be committed there; the same two surfaces stay silent when no ignore rule matches and when the base dir already holds tracked files, and report an undeterminable ignore status in wording distinct from both other outcomes when the path is outside a git work tree or git does not answer. Every mode of `bin/team-paths.sh` still writes byte-identical stdout and exits 0 in every one of those cases, no acknowledgement flag is introduced anywhere, and the production probe honours the operator's global excludes while every new assertion about ignore behaviour pins that input explicitly. `bin/retro-inputs.sh` counts **any regular file** as a review artifact, so a reviews directory holding only the plugin's own `.txt` / `.jsonl` capture output reports `read` with a count rather than `empty`, while the `.md` and `.jsonl` suffix rules governing the other five directory-backed inputs, the nine-line three-field ledger grammar, the canonical id/status block and the resolver's deliberately cwd-relative invocation are all unchanged. `bin/team-paths.sh` no longer documents its legacy marker as a bare `tasks/loops/` directory in either its header or its `--help` output, and its detection behaviour is unchanged. `templates/shell-team.gitignore`, the repository root `.gitignore`, `.github/workflows/check-handoff.yml`, `templates/prompt-blocks/`, `agents/` and `skills/` are byte-identical to the base ref.

### Settled decisions

Each decision below is resolved; nothing here is left to implementation judgment. Every message body this task ships is frozen byte for byte in this section, and every acceptance criterion reads its expected bytes **out of this file** rather than restating them, so a criterion cannot drift from the text it guards.

- **D1 — the `specs`-symptom mechanism, discriminated and named.** Three candidates were weighed against the code at `6439eb6`. **(i) "the resolver is invoked with no `--root`, so layout detection resolves against the process cwd."** True as a description of line 372, but it is **the house convention, not a defect**: nine `bin/` scripts resolve cwd-relative with no `--root` (`retro-inputs.sh`, `discover-work.sh`, `log-run.sh`, `consolidate-proposals.sh`, `rollup-track.sh`, `close-out.sh`, `playbook-promote.sh`, `codex-capture.sh`, and only `team-init.sh`, `gen-project-status.sh` and `gen-playbook-blocks.sh` pass `--root`, each because it has an explicit target argument), and `bin/codex-capture.sh` line 168 states it is deliberate, citing the 2026-06-17 lesson to self-resolve from the caller's cwd. Making one script the exception is a cross-cutting change to a resolver convention, not a one-line fix. **(ii) "legacy detection requires the contract file while the documentation says a bare `tasks/loops/` directory."** The contradiction is real and measured (line 146 versus lines 14-18 and line 61). **(iii) the legacy layout's split root sends `specs` to `docs/specs`.** The relayed report is the discriminator: it states `review-artifacts` was `empty` and `specs` was `unavailable`. Under (i) or (ii) every directory-backed input resolves through the same rule and would be `unavailable` together, because the reviews directory would not be found either — so neither explains an `empty` beside an `unavailable`. Only (iii) does: legacy detection succeeded, `tasks/reviews` was found and held no `.md`, and `docs/specs` was absent. **Decision**: fix the `.md`-only suffix (a measured first-party defect, D3); fix (ii)'s documentation contradiction here, doc-only and behaviour-unchanged (D7), because it is the documented enabling condition for an adopter to build a layout the resolver declines to detect; change nothing about (i) or (iii). This inference assumes both relayed statuses come from one ledger; that assumption is stated so it can be falsified rather than buried.
- **D2 — the warning is advisory, exits 0, and that is not a fail-closed violation.** This repository's invariant is that a **checker** fails closed: a component whose job is to evaluate an input against a contract and return a verdict reports an error when it cannot evaluate, and never silently passes. `bin/team-paths.sh` is a resolver and `bin/team-init.sh` is a scaffolder; neither returns a verdict, and the condition being reported violates no contract — README lines 57-60 and `docs/adopting.md` lines 34-49 both declare ignoring the base dir a supported choice. What the fail-closed discipline *does* require here is its applicable form, and D6 enforces it: an ignore status that cannot be determined is reported as undeterminable in its own distinct wording, never left silent, because silence in this design means "not ignored".
- **D3 — `review-artifacts` counts any regular file; the other five directory inputs keep their suffix rules.** Ground: the reviews directory is the only resolved directory with a first-party non-`.md` producer (`bin/codex-capture.sh` publishes `<stem>.txt` and `<stem>.jsonl`). Provenance, interventions, retros and specs have `.md` producer contracts enforced by their own checkers; run telemetry is `.jsonl` by `bin/log-run.sh`'s contract. "Any regular file" is the rule, not an enumerated suffix set: an extensionless file and an unfamiliar extension both count, a subdirectory does not, and dotfiles remain excluded by the existing `nullglob`-without-`dotglob` enumeration — so the `.codex-capture.*` pre-publish temps stay out with no new exclusion logic.
- **D4 — the ledger keeps printing repo-root-relative paths, and the enumeration keeps resolving from the caller's cwd.** `bin/check-pii-shapes.sh`'s `RE_HOME_PATH` treats `/Users/<name>` and `/home/<name>` as PII shapes, and a retro is a git-tracked artifact, so an absolute path in a ledger detail is a finding waiting to happen. The detail text for a directory input therefore names the resolved path exactly as the resolver emits it — which is also what makes an `unavailable` self-diagnosing today, since `directory not found: docs/specs` and `directory not found: .shell-team/specs` name which precedence rule fired.
- **D5 — no acknowledgement flag ships, on either script.** `--allow-ignored-base` has no durable home: `team-init` is one-shot and writes nothing outside the base dir, and the base dir is precisely what is ignored in the failing case, so an acknowledgement recorded there is itself uncommittable. An environment variable would acknowledge one invocation. A flag that persists nothing acknowledges nothing, and the notice it would suppress is a single stderr line from two human-facing one-shots, one of which (`--print`) is silent in any repository that tracks its base dir. Recorded as an issue candidate for the next planning input, not filed from this role.
- **D6 — three outcome classes, mutually distinguishable, and the warning condition has two parts.** The notice fires when **both** hold: the resolved base dir is matched by an ignore rule, **and** git tracks no file under it. If an ignore rule matches but files under the base dir are already tracked, the records are committable and the notice is a false positive, so the surface stays silent. The three classes are: *ignored* (frozen body `N1`), *outside a git work tree* (`N2`), *undeterminable* (`N3`) — the last covering git being unavailable and any `git check-ignore` exit status other than the two that mean "ignored" and "not ignored". Silence is reserved for the not-ignored and already-tracked cases alone. The probe must fire for a directory-form ignore rule (`<base>/`) as well as a bare one (`<base>`), which is what makes the notice non-vacuous for the pattern shape `docs/adopting.md` actually recommends.
- **D7 — the legacy-marker documentation drift is repaired here, doc-only.** Four lines state the marker as a bare directory, frozen below as `OD1`–`OD4`: `bin/team-paths.sh`'s header precedence entry, its header "the marker is …" sentence, its `print_help` precedence line, and `tests/team-paths/run.sh`'s own header comment. The `elif` at line 146, the `RULE` string at line 149 and the header note at lines 137-139 are already correct and are the authority the four are corrected against. **No detection behaviour changes**: the marker stays the contract file, and `tests/team-paths/run.sh`'s existing case that a `tasks/loops/` directory *without* the contract file stays in default mode is untouched.
- **D8 — one message body, two implementations, locked by byte-identity.** Each script carries its own copy of the probe and of the three frozen bodies, and an acceptance criterion compares the two copies against each other and against this file. Ground: `bin/` scripts are standalone and zero-dependency by design and already duplicate small bootstrap blocks across five scripts rather than sharing a library; introducing a shared library, or having one script invoke the other for its side effect, buys less than it costs. Each script keeps its own stderr prefix; what is frozen is the body after that prefix.
- **D9 — `bin/team-init.sh` emits the notice after scaffolding, not before.** A directory-form ignore rule (`<base>/`) cannot match a path that does not exist yet, so a probe run before the base dir is created would be silently vacuous in exactly the common case.
- **D10 — the two halves are independently shippable, and Half B goes first.** Half B touches `bin/retro-inputs.sh`, `tests/retro-inputs/run.sh` and the documentation-only region of `bin/team-paths.sh`; Half A touches the executable region of `bin/team-paths.sh`, `bin/team-init.sh`, their two suites and the four adopter-facing documents. The only shared file is `bin/team-paths.sh`, in disjoint regions. AC1-AC6 verify Half B and AC7-AC13 verify Half A, with no criterion depending on both.
- **D11 — no new test suite and no CI change.** Every fixture extends an existing suite (`tests/retro-inputs/run.sh`, `tests/team-paths/run.sh`, `tests/team-init/run.sh`), so `.github/workflows/check-handoff.yml` needs no edit and stays byte-identical.
- **D12 — every fixture root for an ignore assertion is an independently `git init`-ed work tree, and every such assertion pins the excludes file explicitly.** `tests/team-paths/run.sh` deliberately avoids `mktemp` and builds its roots under its own directory *inside this repository*, so a fixture that is not its own work tree would have `git check-ignore` answer from this repository's rules instead of the fixture's. Pinning follows `docs/adopting.md` lines 51-56: `/dev/null` where the operator's global file must not create a false positive, and a hostile excludes file in the one case that proves the production probe honours global excludes.

Frozen message body **N1** — the *ignored* notice, one line, with a single `%s` for the resolved base dir:

<!-- frozen-begin: N1 -->
```text
the resolved base dir %s is matched by a git ignore rule and holds no tracked file, so the board, specs, provenance, interventions and review records written there cannot be committed and survive only in this working tree. Ignoring the base dir is a supported choice (see the README section on deciding whether the base dir belongs in git); if you meant these records to be versioned, remove or override the ignore rule that matches this path.
```
<!-- frozen-end: N1 -->

Frozen message body **N2** — the *outside a git work tree* notice:

<!-- frozen-begin: N2 -->
```text
the resolved base dir %s is not inside a git work tree, so whether it can be committed could not be determined and nothing written there is under version control.
```
<!-- frozen-end: N2 -->

Frozen message body **N3** — the *undeterminable* notice:

<!-- frozen-begin: N3 -->
```text
whether the resolved base dir %s is matched by a git ignore rule could not be determined (git did not answer), so treat the durability of anything written there as unknown rather than as fine.
```
<!-- frozen-end: N3 -->

Superseded documentation lines **OD1**–**OD4**, each a whole line whose occurrence count must reach zero in its own file. `OD1`, `OD2` and `OD3` live in `bin/team-paths.sh`; `OD4` lives in `tests/team-paths/run.sh`. They are quoted here so every extinction assertion reads them out of this file rather than restating them.

<!-- frozen-begin: OD1 -->
```text
#   2. legacy layout       — if ROOT/tasks/loops/ exists, use the historical
```
<!-- frozen-end: OD1 -->

<!-- frozen-begin: OD2 -->
```text
#                            marker is `tasks/loops/` (plugin-unique), NOT a bare
```
<!-- frozen-end: OD2 -->

<!-- frozen-begin: OD3 -->
```text
  2. legacy layout        if ROOT/tasks/loops/ exists -> base=tasks, specs=docs/specs
```
<!-- frozen-end: OD3 -->

<!-- frozen-begin: OD4 -->
```text
#   - legacy mode       : root with tasks/loops/ -> base=tasks, specs=docs/specs
```
<!-- frozen-end: OD4 -->

Frozen fixture labels **LB1**–**LB5** (`tests/retro-inputs/run.sh`) and **LA1**–**LA11** (`tests/team-paths/run.sh` for `LA1`–`LA8`, `tests/team-init/run.sh` for `LA9`–`LA11`). Each is the exact argument its suite passes to `pass`, so each appears in that suite's output as `PASS: ` followed by the label.

<!-- frozen-begin: LB1 -->
```text
case: review-artifacts counts any regular file, so a reviews dir holding only non-.md artifacts reads
```
<!-- frozen-end: LB1 -->

<!-- frozen-begin: LB2 -->
```text
case: review-artifacts reports empty for a reviews dir holding no regular file
```
<!-- frozen-end: LB2 -->

<!-- frozen-begin: LB3 -->
```text
case: review-artifacts counts neither a capture-temp dotfile nor a subdirectory
```
<!-- frozen-end: LB3 -->

<!-- frozen-begin: LB4 -->
```text
case: the .md and .jsonl suffix rules are unchanged for the other five directory inputs
```
<!-- frozen-end: LB4 -->

<!-- frozen-begin: LB5 -->
```text
case: a directory-input detail names the resolved path and never an absolute one
```
<!-- frozen-end: LB5 -->

<!-- frozen-begin: LA1 -->
```text
ignored-base notice: fires on stderr for a base dir a repo-level ignore rule matches
```
<!-- frozen-end: LA1 -->

<!-- frozen-begin: LA2 -->
```text
ignored-base notice: silent for a base dir no ignore rule matches
```
<!-- frozen-end: LA2 -->

<!-- frozen-begin: LA3 -->
```text
ignored-base notice: silent when the base dir already holds a tracked file
```
<!-- frozen-end: LA3 -->

<!-- frozen-begin: LA4 -->
```text
ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike
```
<!-- frozen-end: LA4 -->

<!-- frozen-begin: LA5 -->
```text
ignored-base notice: fires when only a global excludes file ignores the base dir
```
<!-- frozen-end: LA5 -->

<!-- frozen-begin: LA6 -->
```text
ignored-base notice: reports an undeterminable ignore status outside a git work tree
```
<!-- frozen-end: LA6 -->

<!-- frozen-begin: LA7 -->
```text
ignored-base notice: reports an undeterminable ignore status when git is unavailable
```
<!-- frozen-end: LA7 -->

<!-- frozen-begin: LA8 -->
```text
ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0
```
<!-- frozen-end: LA8 -->

<!-- frozen-begin: LA9 -->
```text
ignored-base notice: team-init emits the identical notice body for an ignored base dir
```
<!-- frozen-end: LA9 -->

<!-- frozen-begin: LA10 -->
```text
ignored-base notice: team-init stays silent and unchanged for a base dir no rule matches
```
<!-- frozen-end: LA10 -->

<!-- frozen-begin: LA11 -->
```text
ignored-base notice: team-init reports an undeterminable ignore status for a non-git target
```
<!-- frozen-end: LA11 -->

## Non-goals

- **The ignored-base condition never becomes a hard failure in any gate.** No checker gains it, no exit status changes, no seam gate consults it. Tech-lead ruling; also D2's whole argument.
- **No acknowledgement flag** — `--allow-ignored-base` or any equivalent, on either script (D5). Issue candidate for the next planning input, not filed from this role.
- **No change to the resolver's cwd-relative invocation convention** in `bin/retro-inputs.sh` or in any of the eight other scripts that share it (D1(i)). A repo-root-derived resolution is a cross-cutting change to nine call sites with its own review standard; recorded as an issue candidate.
- **No change to the legacy layout's split root** (`docs/specs`) or to what the legacy marker *is* (D1(iii), D7). Only what the documentation *says* the marker is moves.
- **No re-wiring of `--lessons` to the resolver.** Standing decision T-1006 DP-1(b), `bin/retro-inputs.sh` lines 11-17.
- **No edit to `templates/shell-team.gitignore` or to the repository root `.gitignore`.** `tests/gitignore-raw-dumps/run.sh` locks both byte-unchanged against `develop`.
- **No work on the non-`bin/retro-inputs.sh` surface of #67.** `agents/scrum-master.md`'s hardcoded `tasks/reviews/<task-id>.md` lookup is that surface; #67 stays OPEN and keeps it.
- **No change to `templates/prompt-blocks/retro-inputs.md`, to any `agents/*.md`, or to any `skills/*`.** The canonical block declares ids and statuses only; no suffix moves through it (D6 of the source list, verified by AC3).
- **No new test suite, no new CI step, no version bump and no CHANGELOG entry** (D11); release-cut time writes the latter two, per `CONTRIBUTING.md`'s `## Cutting a release`.
- **No corpus promotion and no playbook regeneration.** `.shell-team/lessons.md` and the generated prompt blocks are untouched.

## Acceptance criteria

Every check runs from the repository root, names every file it reads, asserts readability (and, for base-ref reads, that the ref resolves) before any comparison or negative grep, writes only inside a `mktemp -d` scratch directory created with the guarded `${TMPDIR:-/tmp}` template, reflects producer failures into `rc`, and carries a positive control wherever it counts or greps for an absent condition. Every criterion that pins a text reads its expected bytes out of this file's own `<!-- frozen-begin: X -->` / `<!-- frozen-end: X -->` fenced blocks, fence lines stripped with `sed '1d;$d'`. The three suite-running criteria (AC1, AC7, AC8) may need `CHECK_ACS_TIMEOUT` elevated; `300` is the value to start from.

- [ ] **AC1** `tests/retro-inputs/run.sh` exits 0, and its output carries a `PASS:` line for each of the five frozen Half-B labels `LB1`–`LB5` **and** for the two pre-existing preservation labels this task must not break: `case: every ledger is complete (all nine input ids, exactly once)` and `case: default base resolves to develop when it exists`. `LB1`'s case must exercise a reviews directory holding a `.txt`, a `.jsonl`, a `.json`, a file with an unfamiliar extension and an extensionless file, and assert the line reads `status: read` with the count of all five — an explicit suffix set would fail on the last two, which is what pins "any regular file". `LB3`'s case must place a `.codex-capture.`-prefixed dotfile and a subdirectory in that directory and assert neither is counted. Positive controls: each frozen label must extract to exactly one line, and the suite's own output must be non-empty.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; S=tests/retro-inputs/run.sh; test -r "$SP" || exit 1; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a1.XXXXXX") || exit 1; for n in LB1 LB2 LB3 LB4 LB5; do awk -v b="<!-- frozen-begin: $n -->" -v e="<!-- frozen-end: $n -->" '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/$n"; test "$(grep -c . "$T/$n" || true)" = "1" || rc=1; printf 'PASS: %s\n' "$(cat "$T/$n")" > "$T/$n.exp"; done; bash "$S" > "$T/out" 2>&1 || rc=1; test -s "$T/out" || rc=1; for n in LB1 LB2 LB3 LB4 LB5; do grep -qxFf "$T/$n.exp" "$T/out" || rc=1; done; grep -qxF -- 'PASS: case: every ledger is complete (all nine input ids, exactly once)' "$T/out" || rc=1; grep -qxF -- 'PASS: case: default base resolves to develop when it exists' "$T/out" || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC2** The six directory-backed inputs still resolve through the resolver and still emit under their canonical ids: `bin/retro-inputs.sh` calls `report_dir_input` exactly six times at column 0, exactly once for each of `review-artifacts`, `provenance`, `specs`, `run-telemetry`, `previous-retro` and `interventions`, and every one of those six lines names a `TEAM_` resolver variable. The nine canonical ids appear in the `IDS` list in the canonical order unchanged from the base blob. Positive control: the base blob must itself satisfy the six-call and `IDS` assertions, proving the anchors are live rather than matching an artefact of the edit.
  - check: rc=0; R=bin/retro-inputs.sh; test -r "$R" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a2.XXXXXX") || exit 1; git show 6439eb6:bin/retro-inputs.sh > "$T/base.sh" || rc=1; test -s "$T/base.sh" || rc=1; for f in "$R" "$T/base.sh"; do test "$(grep -c '^report_dir_input ' "$f" || true)" = "6" || rc=1; for id in review-artifacts provenance specs run-telemetry previous-retro interventions; do test "$(grep -c "^report_dir_input $id " "$f" || true)" = "1" || rc=1; done; test "$(grep -c '^report_dir_input .*TEAM_' "$f" || true)" = "6" || rc=1; done; grep -m1 '^IDS=' "$R" > "$T/ids.new"; grep -m1 '^IDS=' "$T/base.sh" > "$T/ids.old"; test -s "$T/ids.new" || rc=1; cmp -s "$T/ids.new" "$T/ids.old" || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC3** The canonical id/status contract is untouched and its consumers stay in sync: `templates/prompt-blocks/retro-inputs.md` is byte-identical to the base blob, it still carries exactly nine `- input: ` lines and exactly three `- status: ` lines, and `bash bin/check-prompt-sync.sh` exits 0. Positive control: the extracted base blob must be non-empty before the comparison is trusted.
  - check: rc=0; B=templates/prompt-blocks/retro-inputs.md; test -r "$B" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a3.XXXXXX") || exit 1; git show "6439eb6:$B" > "$T/base.md" || rc=1; test -s "$T/base.md" || rc=1; cmp -s "$B" "$T/base.md" || rc=1; test "$(grep -c '^- input: ' "$B" || true)" = "9" || rc=1; test "$(grep -c '^- status: ' "$B" || true)" = "3" || rc=1; bash bin/check-prompt-sync.sh >/dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC4** The deliberately cwd-relative resolver invocation is preserved exactly (D1(i), D4): the single line of `bin/retro-inputs.sh` that invokes `team-paths.sh --export` is byte-identical to the base blob's, and the script contains no `--root` argument anywhere. Positive controls: the extracted line must be non-empty and must contain `--export`, and the base blob must yield exactly one such line.
  - check: rc=0; R=bin/retro-inputs.sh; test -r "$R" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a4.XXXXXX") || exit 1; git show 6439eb6:bin/retro-inputs.sh > "$T/base.sh" || rc=1; test -s "$T/base.sh" || rc=1; test "$(grep -c -- 'team-paths.sh" --export' "$R" || true)" = "1" || rc=1; test "$(grep -c -- 'team-paths.sh" --export' "$T/base.sh" || true)" = "1" || rc=1; grep -m1 -- 'team-paths.sh" --export' "$R" > "$T/new.line"; grep -m1 -- 'team-paths.sh" --export' "$T/base.sh" > "$T/old.line"; test -s "$T/new.line" || rc=1; grep -qF -- '--export' "$T/new.line" || rc=1; cmp -s "$T/new.line" "$T/old.line" || rc=1; test "$(grep -c -- '--root' "$R" || true)" = "0" || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC5** The legacy-marker documentation drift is extinct and corrected, with no behaviour change (D7). The four frozen superseded lines occur **zero** times in their own files — `OD1`, `OD2`, `OD3` in `bin/team-paths.sh` and `OD4` in `tests/team-paths/run.sh` — while each occurred exactly once in that file's base blob, which is the positive control proving each pattern was live. Both files carry strictly more occurrences of `tasks/loops/shell-team.contract.yaml` than their base blobs do. Detection is unchanged: `bin/team-paths.sh` still carries the `elif` line testing that file and still sets `BASE="tasks"` and `SPECS="docs/specs"` in that branch, all three byte-identical to the base blob.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; P=bin/team-paths.sh; S=tests/team-paths/run.sh; test -r "$SP" || exit 1; test -r "$P" || exit 1; test -r "$S" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a5.XXXXXX") || exit 1; git show 6439eb6:bin/team-paths.sh > "$T/bp.sh" || rc=1; git show 6439eb6:tests/team-paths/run.sh > "$T/bt.sh" || rc=1; test -s "$T/bp.sh" || rc=1; test -s "$T/bt.sh" || rc=1; for n in OD1 OD2 OD3 OD4; do awk -v b="<!-- frozen-begin: $n -->" -v e="<!-- frozen-end: $n -->" '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/$n"; test "$(grep -c . "$T/$n" || true)" = "1" || rc=1; done; for n in OD1 OD2 OD3; do test "$(grep -cxFf "$T/$n" "$T/bp.sh" || true)" = "1" || rc=1; test "$(grep -cxFf "$T/$n" "$P" || true)" = "0" || rc=1; done; test "$(grep -cxFf "$T/OD4" "$T/bt.sh" || true)" = "1" || rc=1; test "$(grep -cxFf "$T/OD4" "$S" || true)" = "0" || rc=1; np=$(grep -cF -- 'tasks/loops/shell-team.contract.yaml' "$P" || true); op=$(grep -cF -- 'tasks/loops/shell-team.contract.yaml' "$T/bp.sh" || true); test "$((10#$np))" -gt "$((10#$op))" || rc=1; nt=$(grep -cF -- 'tasks/loops/shell-team.contract.yaml' "$S" || true); ot=$(grep -cF -- 'tasks/loops/shell-team.contract.yaml' "$T/bt.sh" || true); test "$((10#$nt))" -gt "$((10#$ot))" || rc=1; for pat in 'elif \[ -f "\$ROOT/tasks/loops/shell-team.contract.yaml" \]; then' '  BASE="tasks"' '  SPECS="docs/specs"'; do grep -m1 -- "$pat" "$P" > "$T/n.line"; grep -m1 -- "$pat" "$T/bp.sh" > "$T/o.line"; test -s "$T/n.line" || rc=1; cmp -s "$T/n.line" "$T/o.line" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC6** `bin/retro-inputs.sh`'s header documents the open-extension rule and grounds it in the real producer: the script's whole leading comment block — extracted by walking from line 1 to the first line that is neither a comment nor blank, so the assertion cannot be defeated or falsely satisfied by the header growing — contains the phrase `any regular file`, names `review-artifacts`, and names `bin/codex-capture.sh` as the producer that publishes non-`.md` material into the reviews dir. That grounding is re-derived rather than trusted: `bin/codex-capture.sh` really does publish both `$stem.txt` and `$stem.jsonl` into the resolved reviews dir, asserted directly on that file. Positive controls: the two `codex-capture` anchors must be found, and the extracted header block must be non-empty, before any header claim is accepted.
  - check: rc=0; R=bin/retro-inputs.sh; C=bin/codex-capture.sh; test -r "$R" || exit 1; test -r "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a6.XXXXXX") || exit 1; grep -qF -- '$reviews_dir/$stem.txt' "$C" || rc=1; grep -qF -- '$reviews_dir/$stem.jsonl' "$C" || rc=1; awk '/^[^#]/{exit} {print}' "$R" > "$T/hdr"; test -s "$T/hdr" || rc=1; grep -qF -- 'any regular file' "$T/hdr" || rc=1; grep -qF -- 'review-artifacts' "$T/hdr" || rc=1; grep -qF -- 'bin/codex-capture.sh' "$T/hdr" || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC7** `tests/team-paths/run.sh` exits 0 and its output carries a `PASS:` line for each of the eight frozen labels `LA1`–`LA8`, **and** for the two pre-existing preservation labels this task must not break: `tasks/loops/ without shell-team.contract.yaml stays in default mode` and `default mode resolves all paths under .shell-team/`. Each new case's fixture root is its own `git init`-ed work tree and every ignore assertion in the suite pins the excludes file explicitly. Positive controls: each frozen label must extract to exactly one line, and the suite output must be non-empty.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; S=tests/team-paths/run.sh; test -r "$SP" || exit 1; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a7.XXXXXX") || exit 1; for n in LA1 LA2 LA3 LA4 LA5 LA6 LA7 LA8; do awk -v b="<!-- frozen-begin: $n -->" -v e="<!-- frozen-end: $n -->" '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/$n"; test "$(grep -c . "$T/$n" || true)" = "1" || rc=1; printf 'PASS: %s\n' "$(cat "$T/$n")" > "$T/$n.exp"; done; bash "$S" > "$T/out" 2>&1 || rc=1; test -s "$T/out" || rc=1; for n in LA1 LA2 LA3 LA4 LA5 LA6 LA7 LA8; do grep -qxFf "$T/$n.exp" "$T/out" || rc=1; done; grep -qxF -- 'PASS: tasks/loops/ without shell-team.contract.yaml stays in default mode' "$T/out" || rc=1; grep -qxF -- 'PASS: default mode resolves all paths under .shell-team/' "$T/out" || rc=1; test "$(grep -c 'git init' "$S" || true)" -ge 1 || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC8** `tests/team-init/run.sh` exits 0 and its output carries a `PASS:` line for each of the three frozen labels `LA9`–`LA11`. `LA9`'s case must assert the emitted stderr contains the `N1` body with the resolved base substituted, `LA10`'s that stderr carries no notice body at all and that stdout and exit status match a non-ignored control run, and `LA11`'s that a non-git target yields the `N2` body and exit 0. Positive controls: each frozen label must extract to exactly one line, and the suite output must be non-empty.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; S=tests/team-init/run.sh; test -r "$SP" || exit 1; test -r "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a8.XXXXXX") || exit 1; for n in LA9 LA10 LA11; do awk -v b="<!-- frozen-begin: $n -->" -v e="<!-- frozen-end: $n -->" '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/$n"; test "$(grep -c . "$T/$n" || true)" = "1" || rc=1; printf 'PASS: %s\n' "$(cat "$T/$n")" > "$T/$n.exp"; done; bash "$S" > "$T/out" 2>&1 || rc=1; test -s "$T/out" || rc=1; for n in LA9 LA10 LA11; do grep -qxFf "$T/$n.exp" "$T/out" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC9** One message body, two implementations (D8): each of the three frozen bodies `N1`, `N2` and `N3` occurs **exactly once** in `bin/team-paths.sh` and **exactly once** in `bin/team-init.sh`, and the occurrence extracted from each script is byte-identical to the other's and to this spec's frozen block. None of the three occurs in the base blob of either script, which is the positive control that the comparison is measuring new text rather than pre-existing prose.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; P=bin/team-paths.sh; I=bin/team-init.sh; test -r "$SP" || exit 1; test -r "$P" || exit 1; test -r "$I" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042a9.XXXXXX") || exit 1; git show 6439eb6:bin/team-paths.sh > "$T/bp.sh" || rc=1; git show 6439eb6:bin/team-init.sh > "$T/bi.sh" || rc=1; test -s "$T/bp.sh" || rc=1; test -s "$T/bi.sh" || rc=1; for n in N1 N2 N3; do awk -v b="<!-- frozen-begin: $n -->" -v e="<!-- frozen-end: $n -->" '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/$n"; test "$(grep -c . "$T/$n" || true)" = "1" || rc=1; test "$(grep -cFf "$T/$n" "$P" || true)" = "1" || rc=1; test "$(grep -cFf "$T/$n" "$I" || true)" = "1" || rc=1; test "$(grep -cFf "$T/$n" "$T/bp.sh" || true)" = "0" || rc=1; test "$(grep -cFf "$T/$n" "$T/bi.sh" || true)" = "0" || rc=1; grep -m1 -Ff "$T/$n" "$P" > "$T/$n.p"; grep -m1 -Ff "$T/$n" "$I" > "$T/$n.i"; test -s "$T/$n.p" || rc=1; test -s "$T/$n.i" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC10** Every mode of `bin/team-paths.sh` writes byte-identical stdout and exits 0 while the notice fires. Against a scratch fixture that is its own `git init`-ed work tree, whose `.gitignore` ignores `.shell-team/` and under which nothing is tracked: `--export`, `--print` and all ten `--get` keys produce stdout byte-identical to the same invocation of the base blob's script, and every invocation exits 0. The comparison is not vacuous, because the fixture genuinely triggers the notice: the working script's `--print` stderr is non-empty and contains the frozen `N1` body, while the base blob's `--print` stderr is empty. The excludes file is pinned to `/dev/null` for the git operations so the operator's global configuration cannot manufacture or mask the condition.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; P=bin/team-paths.sh; test -r "$SP" || exit 1; test -r "$P" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b0.XXXXXX") || exit 1; git show 6439eb6:bin/team-paths.sh > "$T/base.sh" || rc=1; test -s "$T/base.sh" || rc=1; awk -v b='<!-- frozen-begin: N1 -->' -v e='<!-- frozen-end: N1 -->' '$0==b{f=1;next} $0==e{f=0} f' "$SP" | sed '1d;$d' > "$T/N1"; test "$(grep -c . "$T/N1" || true)" = "1" || rc=1; sed 's/%s.*//' "$T/N1" > "$T/N1.head"; F="$T/fx"; mkdir -p "$F/.shell-team"; git -c core.excludesFile=/dev/null init -q "$F" || rc=1; printf '.shell-team/\n' > "$F/.gitignore"; for m in export print; do env -u TEAM_RUN_BASE bash "$P" --root "$F" "--$m" > "$T/new.$m" 2> "$T/new.$m.err"; test "$?" = "0" || rc=1; env -u TEAM_RUN_BASE bash "$T/base.sh" --root "$F" "--$m" > "$T/old.$m" 2> "$T/old.$m.err"; test "$?" = "0" || rc=1; cmp -s "$T/new.$m" "$T/old.$m" || rc=1; done; test -s "$T/new.print.err" || rc=1; grep -qFf "$T/N1.head" "$T/new.print.err" || rc=1; test -s "$T/old.print.err" && rc=1; for k in base todo loops runs retros reviews specs provenance interventions lessons; do env -u TEAM_RUN_BASE bash "$P" --root "$F" --get "$k" > "$T/n.$k" 2>/dev/null || rc=1; env -u TEAM_RUN_BASE bash "$T/base.sh" --root "$F" --get "$k" > "$T/o.$k" 2>/dev/null || rc=1; cmp -s "$T/n.$k" "$T/o.$k" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC11** No acknowledgement flag exists and neither script's flag surface moved (D5). The token `allow-ignored-base` occurs zero times across `bin/`, `tests/`, `skills/`, `agents/`, `templates/`, `docs/`, `README.md` and `README.ja.md`; the negative sweep is deliberately scoped to those operational surfaces because this spec and the board discuss the rejected flag in prose, and its positive control is that the token occurs at least once in this spec itself. The sorted set of long-flag tokens in `bin/team-paths.sh` and in `bin/team-init.sh` is identical to each script's base blob, extracted **line-anchored** — the flag surface is exactly where a flag literal opens a line, in an argument parser's case labels and in a `print_help` row, so a flag literal appearing mid-line inside a `git` invocation or a usage message is deliberately not part of the surface this criterion locks. Both sides of every comparison are extracted the same way.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; test -r "$SP" || exit 1; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b1.XXXXXX") || exit 1; test "$(grep -rlF -- 'allow-ignored-base' bin tests skills agents templates docs README.md README.ja.md 2>/dev/null | grep -c . || true)" = "0" || rc=1; test "$(grep -cF -- 'allow-ignored-base' "$SP" || true)" -ge 1 || rc=1; for f in bin/team-paths.sh bin/team-init.sh; do test -r "$f" || rc=1; git show "6439eb6:$f" > "$T/base" || rc=1; test -s "$T/base" || rc=1; grep -oE -- '^[[:space:]]*--[a-z][a-z-]*' "$f" | sed 's/^[[:space:]]*//' | sort -u > "$T/new.flags"; grep -oE -- '^[[:space:]]*--[a-z][a-z-]*' "$T/base" | sed 's/^[[:space:]]*//' | sort -u > "$T/old.flags"; test -s "$T/new.flags" || rc=1; test -s "$T/old.flags" || rc=1; cmp -s "$T/new.flags" "$T/old.flags" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC12** The global-excludes asymmetry holds in both directions (D12). The production probe honours the operator's global excludes: `core.excludesFile` occurs zero times anywhere under `bin/`, exactly as at the base ref. Every new assertion pins that input explicitly: `tests/team-paths/run.sh` and `tests/team-init/run.sh` each carry strictly more `core.excludesFile` occurrences than their base blobs, and at least one of them pins a **hostile** excludes file naming the base dir — the `LA5` case, which is what proves the production probe really does read the global file rather than only the repository's own rules. Positive controls: each base blob must be non-empty, and `bin/` must be non-empty as a search target, evidenced by `core` matching at least once somewhere under `bin/`.
  - check: rc=0; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b2.XXXXXX") || exit 1; test "$(grep -rlF -- 'core.excludesFile' bin 2>/dev/null | grep -c . || true)" = "0" || rc=1; test "$(grep -rl -- 'core' bin 2>/dev/null | grep -c . || true)" -ge 1 || rc=1; for f in tests/team-paths/run.sh tests/team-init/run.sh; do test -r "$f" || rc=1; git show "6439eb6:$f" > "$T/base" || rc=1; test -s "$T/base" || rc=1; n=$(grep -cF -- 'core.excludesFile' "$f" || true); o=$(grep -cF -- 'core.excludesFile' "$T/base" || true); test "$((10#$n))" -gt "$((10#$o))" || rc=1; done; test "$(cat tests/team-paths/run.sh tests/team-init/run.sh | grep -cF -- 'hostile' || true)" -ge 1 || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC13** The four adopter-facing documents describe the notice, in both languages. `README.md`, `README.ja.md`, `docs/adopting.md` and `docs/adopting.ja.md` each gain at least one added line against the base ref, and `docs/adopting.md` and `docs/adopting.ja.md` each carry strictly more occurrences of `check-ignore` than their base blobs do — the base count is re-derived from each blob rather than written here as a literal. Both comparisons are pinned to a named ref and stated as a one-directional delta, so ordinary growth of either document cannot turn this criterion red and it carries no re-measurement trigger. Positive control: each base blob must be non-empty and must already contain `check-ignore` at least once, proving the pattern is live in both files.
  - check: rc=0; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b3.XXXXXX") || exit 1; for f in README.md README.ja.md docs/adopting.md docs/adopting.ja.md; do test -r "$f" || rc=1; add=$(git diff --numstat 6439eb6 -- "$f" | awk '{print $1+0}'); test -n "$add" || rc=1; test "$((10#${add:-0}))" -ge 1 || rc=1; done; for f in docs/adopting.md docs/adopting.ja.md; do git show "6439eb6:$f" > "$T/base" || rc=1; test -s "$T/base" || rc=1; o=$(grep -cF -- 'check-ignore' "$T/base" || true); test "$((10#$o))" -ge 1 || rc=1; n=$(grep -cF -- 'check-ignore' "$f" || true); test "$((10#$n))" -gt "$((10#$o))" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC14** Every shell file this task changes is shellcheck-clean at the version CI pins: `shellcheck` reports no finding for `bin/team-paths.sh`, `bin/team-init.sh`, `bin/retro-inputs.sh`, `tests/team-paths/run.sh`, `tests/team-init/run.sh` and `tests/retro-inputs/run.sh`, and the installed `shellcheck --version` matches the `SHELLCHECK_VERSION` value in `.github/workflows/check-handoff.yml`. Positive control: the version string extracted from the workflow must be non-empty before the comparison is trusted.
  - check: rc=0; W=.github/workflows/check-handoff.yml; test -r "$W" || exit 1; command -v shellcheck >/dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b4.XXXXXX") || exit 1; grep -m1 -oE 'SHELLCHECK_VERSION:[[:space:]]*"?[0-9.]+' "$W" | grep -oE '[0-9.]+$' > "$T/ver"; test -s "$T/ver" || rc=1; shellcheck --version | grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' > "$T/have"; test -s "$T/have" || rc=1; grep -qxFf "$T/ver" "$T/have" || rc=1; shellcheck bin/team-paths.sh bin/team-init.sh bin/retro-inputs.sh tests/team-paths/run.sh tests/team-init/run.sh tests/retro-inputs/run.sh >/dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC15** The ignore-behaviour locks this task must not disturb still hold: `bash tests/gitignore-raw-dumps/run.sh` exits 0, and `templates/shell-team.gitignore` and the repository root `.gitignore` are byte-identical to their base blobs. Positive control: both base blobs must be non-empty before either comparison is trusted.
  - check: rc=0; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b5.XXXXXX") || exit 1; for f in templates/shell-team.gitignore .gitignore; do test -r "$f" || rc=1; git show "6439eb6:$f" > "$T/base" || rc=1; test -s "$T/base" || rc=1; cmp -s "$f" "$T/base" || rc=1; done; bash tests/gitignore-raw-dumps/run.sh >/dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC16** The change set is closed at the ratified scope: every path in `git diff --name-only 6439eb6` is a member of the allow-list — `bin/team-paths.sh`, `bin/team-init.sh`, `bin/retro-inputs.sh`, `tests/team-paths/run.sh`, `tests/team-init/run.sh`, `tests/retro-inputs/run.sh`, `README.md`, `README.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, `.shell-team/todo.md`, this spec, `.shell-team/provenance/T-1042.md`, `.shell-team/reviews/T-1042.md`, `.shell-team/interventions/T-1042.md` and `.shell-team/test-recipe.md` — and the six code and test files plus the board and this spec are all present in it. **This criterion is merge-point-scoped and is expected to go stale after merge**: once a later task's files land on `6439eb6`, its expected set no longer describes reality. It must not be merge-ranged, re-derived per rework round, or otherwise kept evergreen; a finding that it should be is out of contract.
  - check: rc=0; SP=.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1042b6.XXXXXX") || exit 1; git diff --name-only 6439eb6 > "$T/files" || rc=1; test -s "$T/files" || rc=1; while read -r f; do case "$f" in bin/team-paths.sh|bin/team-init.sh|bin/retro-inputs.sh|tests/team-paths/run.sh|tests/team-init/run.sh|tests/retro-inputs/run.sh|README.md|README.ja.md|docs/adopting.md|docs/adopting.ja.md|.shell-team/todo.md|.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md|.shell-team/provenance/T-1042.md|.shell-team/reviews/T-1042.md|.shell-team/interventions/T-1042.md|.shell-team/test-recipe.md) : ;; *) rc=1 ;; esac; done < "$T/files"; for f in bin/team-paths.sh bin/team-init.sh bin/retro-inputs.sh tests/team-paths/run.sh tests/team-init/run.sh tests/retro-inputs/run.sh .shell-team/todo.md "$SP"; do grep -qxF -- "$f" "$T/files" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
- [ ] **AC17** The provenance record exists, is conformant, and belongs to this task: `.shell-team/provenance/T-1042.md` is readable, non-empty, and `bash bin/check-provenance.sh` accepts it. That checker takes exactly one positional argument and derives the task id from the file's own opening marker rather than from a flag, so the ownership half is asserted separately — the file carries the whole-line marker `<!-- BEGIN provenance: T-1042 -->`. It records, at minimum, the discrimination in D1, the "any regular file" choice in D3 and the dropped flag in D5, evidenced by each of the tokens `D1`, `D3` and `D5` appearing in it.
  - check: rc=0; F=.shell-team/provenance/T-1042.md; test -r "$F" || exit 1; test -s "$F" || exit 1; bash bin/check-provenance.sh "$F" >/dev/null 2>&1 || rc=1; grep -qxF -- '<!-- BEGIN provenance: T-1042 -->' "$F" || rc=1; for t in D1 D3 D5; do grep -qF -- "$t" "$F" || rc=1; done; test "$rc" -eq 0
- [ ] **AC18** The cross-provider review record exists at the resolved reviews dir and names this task: `.shell-team/reviews/T-1042.md` is readable, non-empty, and contains one of the verdict tokens `APPROVE` or `REQUEST_CHANGES`.
  - check: rc=0; F=.shell-team/reviews/T-1042.md; test -r "$F" || exit 1; test -s "$F" || exit 1; grep -qE -- '(APPROVE|REQUEST_CHANGES)' "$F" || rc=1; test "$rc" -eq 0
- [ ] **AC19** Nothing in the change set carries a PII-shaped or secret-shaped value: `bash bin/check-pii-shapes.sh --base 6439eb6` exits 0. This covers the new fixture identifiers as well as the new prose — the `sk-`-prefixed `RE_TOKEN` false-positive class fired four times in the previous cycle, so every new fixture name, capture-temp name and assertion label is chosen not to collide with `RE_TOKEN`.
  - check: rc=0; git rev-parse --verify --quiet 6439eb6^{commit} >/dev/null || exit 1; bash bin/check-pii-shapes.sh --base 6439eb6 >/dev/null 2>&1 || rc=1; test "$rc" -eq 0
- [ ] **AC20** The board carries a conformant entry for this task: `bash bin/check-handoff.sh .shell-team/todo.md` exits 0, and the board holds exactly one line whose task id is `T-1042` pointing at this spec path. Positive control: the board file must be readable and non-empty before the count is trusted.
  - check: rc=0; B=.shell-team/todo.md; test -r "$B" || exit 1; test -s "$B" || exit 1; bash bin/check-handoff.sh "$B" >/dev/null 2>&1 || rc=1; test "$(grep -cE '^- \[[ xX]\] \*\*T-1042\*\* ' "$B" || true)" = "1" || rc=1; grep -E '^- \[[ xX]\] \*\*T-1042\*\* ' "$B" | grep -qF -- '.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md' || rc=1; test "$rc" -eq 0

## Input space

**Reachable input classes** — what the changed code really receives, and what it must handle correctly:

- **A resolved base dir path**: a repo-relative subpath with no whitespace and no `.` / `..` component (`bin/team-paths.sh`'s `validate_base` already refuses everything else), one of `.shell-team`, `tasks`, or an operator's `$TEAM_RUN_BASE` value such as `.ops` or `ops/team`.
- **A repository state**, one of: base dir matched by a repo-level ignore rule with nothing tracked under it; matched only by a global excludes file; matched but with at least one tracked file under it; matched by a re-include (`!<base>/`) that outranks a global rule, which is this repository's own state; not matched at all; the path not inside any git work tree; git absent from `PATH`.
- **Ignore-rule syntax reachable from the documented guidance**: a bare `<base>` line and a directory-form `<base>/` line, in the repository's own `.gitignore` or in a `core.excludesFile`. `docs/adopting.md` recommends the directory form, so both must fire.
- **`git check-ignore` exit statuses**: the status meaning one or more paths are ignored, the status meaning none are, and any other status (including the fatal one returned outside a work tree) — the last classified as undeterminable rather than as either answer.
- **A resolved reviews directory** holding any mixture of: curated `.md` notes; the plugin's own published `<stem>.txt` and `<stem>.jsonl`; `.json` dumps; a file with no extension or an unfamiliar one; `.codex-capture.*` dotfile temps; a subdirectory; a symlink to a regular file; a broken symlink; and the empty case. The other five resolved directories hold their own producers' `.md` or `.jsonl` files.
- **The two suites' own fixture roots**: throwaway directories created under `tests/team-paths/tmp-roots` and `tests/team-init/`'s scratch area, each `git init`-ed so it is its own work tree, and under `$TMPDIR` for `tests/retro-inputs/run.sh`, which already uses that convention.

**Out-of-scope synthetic extremes** — inputs this spec explicitly declines to protect, so a finding that escalates one of them is answerable rather than open-ended:

- **A partially tracked base dir** — some files under it tracked while an ignore rule would catch newly added ones. D6 treats any tracked file under the base dir as the adopter having decided to track it, and stays silent. Declared here as a conscious boundary, not an oversight.
- **Ever-more-exotic gitignore pattern syntax** — negations nested several levels deep, `**` globs crossing the base dir, patterns in a `.gitignore` inside a subdirectory that re-include the base from below, or an ignore rule delivered through `.git/info/exclude`. The probe asks git the question rather than parsing patterns, so whatever git answers is the answer; a demand for a fixture per pattern form is out of input space once the bare and directory forms both fire.
- **A hostile filesystem under the base dir or the reviews dir** — a symlink race, a directory that becomes unreadable between enumeration and stat, a path containing a newline or a regex metacharacter, an adversarial `$TMPDIR`. The existing enumeration-completeness determination in `count_dir_entries` covers failure, not hostility, and this task does not widen it.
- **A reviews directory with a very large number of entries**, or ever-larger files in it. The count is a count; a demand to bound it is out of scope.
- **A repository whose `git` binary answers incorrectly rather than not at all** — a stubbed or wrapped `git` that returns a plausible-but-wrong ignore verdict. `LA7` covers git being unavailable; a lying git is not an input class this repository's own scripts defend against anywhere.
- **Any surface of issue #67 other than `bin/retro-inputs.sh`**, and any second consumer of the ignored-base condition. Named as an input-space boundary and not only as a Non-goal, because the escalation this task is most exposed to is "here is one more place the same condition matters" — the answer is an issue candidate for the next planning input, not a widened diff.
- **The nine-script cwd-relative resolver convention** (D1(i)). A finding that `bin/retro-inputs.sh` should derive its root from git is a finding about all nine call sites and belongs to its own task.

<!-- END intent-block: T-1042 -->

## Body-to-AC correspondence

Every normative directive in the body above maps to an acceptance criterion or carries an explicit exemption with a reason. A directive missing from this table means the spec is not complete.

| # | Body directive | Source | Where it is verified |
|---|---|---|---|
| 1 | The notice fires on stderr for an ignored base dir, from both scripts | Goal, D6, D8 | AC7 (`LA1`), AC8 (`LA9`) |
| 2 | The notice stays silent when no ignore rule matches | Goal, D6 | AC7 (`LA2`), AC8 (`LA10`) |
| 3 | The notice stays silent when the base dir already holds tracked files | D6 | AC7 (`LA3`) |
| 4 | The probe fires for the bare and the directory-form ignore rule alike | D6 | AC7 (`LA4`) |
| 5 | Undeterminable status is reported in wording distinct from both other outcomes | D2, D6 | AC7 (`LA6`, `LA7`), AC8 (`LA11`), AC9 (three distinct frozen bodies, each present once per script) |
| 6 | `--export` / `--get` / `--print` stdout stays byte-identical and exit status stays 0 | Goal, A-1 hard constraint | AC10 (direct, against the base blob), AC7 (`LA8`) |
| 7 | One message body, byte-identical between the two implementing scripts | D8 | AC9 |
| 8 | The warning is advisory and exits 0 — not a fail-closed violation | D2 | AC10 (exit 0 in every mode while the notice fires); the *argument* is info-only (not promoted to AC) — a rationale for a reviewer cannot be machine-checked, and its consequences are all covered by AC10 and AC7 |
| 9 | No acknowledgement flag ships, on either script | D5, Non-goals | AC11 |
| 10 | The production probe honours global excludes; every new assertion pins the excludes file explicitly | D12, A-5 | AC12 |
| 11 | `team-init` emits the notice after scaffolding, not before | D9 | Covered behaviourally by AC8 (`LA9`) — a pre-scaffold probe cannot match a directory-form rule, so `LA9` fails if the order is wrong. The ordering itself is info-only (not promoted to AC): a source-position assertion would pin an implementation shape without adding detection. |
| 12 | `review-artifacts` counts any regular file, including extensionless and unfamiliar extensions | D3 | AC1 (`LB1`) |
| 13 | Dotfiles and subdirectories are still not counted | D3 | AC1 (`LB3`) |
| 14 | The `.md` / `.jsonl` suffix rules for the other five inputs are unchanged | D3, Goal | AC1 (`LB4`), AC2 |
| 15 | The nine-line, three-field ledger grammar and the canonical id order are unchanged | Goal | AC1 (pre-existing completeness label), AC2 (`IDS` byte-identical), AC3 |
| 16 | The canonical id/status prompt block and its consumers are unchanged | Goal, Non-goals | AC3 |
| 17 | Ledger details name repo-root-relative paths, never absolute ones | D4 | AC1 (`LB5`) |
| 18 | The resolver's cwd-relative invocation is preserved | D1(i), D4, Non-goals | AC4 |
| 19 | The legacy-marker documentation drift is extinct in all four sites | D7 | AC5 |
| 20 | Legacy detection behaviour is unchanged | D7, Non-goals | AC5 (three behaviour lines byte-identical), AC7 (pre-existing default-mode label) |
| 21 | The open-extension rule is documented in the script header and grounded in the real producer | D3 | AC6 |
| 22 | The two halves are independently verifiable | D10 | Info-only (not promoted to AC): it is a property of how AC1-AC6 and AC7-AC13 are partitioned, readable from the criteria themselves, and an AC asserting it would only restate that partition |
| 23 | No new test suite and no CI change | D11 | AC16 (the workflow file is absent from the allow-list) |
| 24 | Fixture roots are their own git work trees | D12 | AC7 (`git init` present in the suite; each new case's fixture is its own work tree, exercised by `LA1`–`LA5` producing verdicts that this repository's own rules would contradict) |
| 25 | `templates/shell-team.gitignore` and the root `.gitignore` stay byte-identical | Non-goals | AC15 |
| 26 | `agents/`, `skills/`, `templates/prompt-blocks/`, `.github/` stay byte-identical | Goal, Non-goals | AC16 (none is in the allow-list), AC3 (the block itself) |
| 27 | The four adopter-facing documents describe the notice, in both languages | Docs scope | AC13 |
| 28 | Every changed shell file stays shellcheck-clean at the pinned version | Repo invariant | AC14 |
| 29 | No new fixture identifier collides with a PII or secret shape | Repo invariant | AC19 |
| 30 | The relayed `specs` mechanism is corrected rather than absorbed | Problem, D1 | Info-only (not promoted to AC): the correction *is* this spec's own prose, and a criterion asserting that a spec says what it says adds no detection surface. Its consequences are promoted — AC4 locks the non-change D1 decides on, and AC5 locks the drift D1 sends to repair. |
| 31 | The `specs` symptom's own mechanism (the legacy split root) stays unfixed | D1(iii), Non-goals | Info-only (not promoted to AC): a negative AC over an unchanged resolver rule would restate AC5's three byte-identity clauses, which already pin the legacy branch's behaviour lines |

## Parallel-surface symmetry — the two notice sites

Half A adds one norm across two surfaces. Every row is confirmed cell by cell before the hand-off; `mirrored-now` means this task creates it on both sides in the same commit.

| Behaviour | `bin/team-paths.sh --print` | `bin/team-init.sh` | Verified by |
|---|---|---|---|
| Ignored base dir → `N1` on stderr | mirrored-now | mirrored-now | AC7 (`LA1`), AC8 (`LA9`), AC9 |
| Not ignored → silence | mirrored-now | mirrored-now | AC7 (`LA2`), AC8 (`LA10`) |
| Ignore rule matches but files are tracked → silence | mirrored-now | mirrored-now (same probe) | AC7 (`LA3`); not-applicable as a separate `team-init` case — the condition is evaluated by the same two-part test whose byte-identity AC9 locks |
| Outside a git work tree → `N2` | mirrored-now | mirrored-now | AC7 (`LA6`), AC8 (`LA11`) |
| git unavailable / unexpected status → `N3` | mirrored-now | mirrored-now | AC7 (`LA7`); not-applicable as a separate `team-init` case for the same reason as the tracked-file row |
| stdout byte-identical, exit 0 | mirrored-now | mirrored-now | AC10 and AC7 (`LA8`) for the resolver; AC8 (`LA10`) for the scaffolder |
| Honours global excludes | mirrored-now | mirrored-now | AC12, AC7 (`LA5`) |
| Emitted after the base dir exists | not-applicable — `--print` creates nothing and the base dir's existence is the caller's state | mirrored-now (D9) | AC8 (`LA9`) |
| Script's own stderr prefix | `team-paths: ` (existing convention) | `WARN: ` (existing `log_warn`) | Deliberately **not** unified — D8 freezes the body, not the prefix |

## Same-class-2 pre-commitment

Half A creates a new verification-adjacent mechanism (a probe with three outcome classes across two surfaces), which this corpus measures as the category that runs several rounds. Threshold is the house default of **two consecutive rounds** and is deliberately not loosened.

- **Factual trigger**: the Half A warning mechanism draws new Blocker or Major findings on two consecutive cross-provider review rounds.
- **Contextual trigger**: before a third round of rework begins.
- **Priority when the two disagree**: the factual condition governs — if two consecutive rounds have fired, the dispositions below are presented even if a third round has already started.
- **Dispositions presented, each with its content rather than a label**: (i) split Half A into its own task and ship Half B alone, which is already independently verifiable by AC1-AC6 and requires no criterion to change; (ii) reduce Half A to the single `bin/team-init.sh` site by class-B re-freeze, dropping the `--print` site and the symmetry table with it; (iii) drop the two-part warning condition to the ignore test alone, accepting the tracked-base false positive and removing `LA3`.

## Assumptions

1. **The base ref `6439eb6` is relayed, not measured by this role.** Every base-relative check line resolves that literal. If the real branch point differs, all of AC2, AC4, AC5, AC9, AC10, AC11, AC12, AC13, AC15, AC16 and AC19 must be re-pointed before the freeze.
2. **The relayed adopter report's two statuses come from one ledger invocation.** D1's discrimination depends on it. Stated so it can be falsified: if they came from two different repositories or two different runs, the discrimination collapses and only the measured `.md`-only defect (D3) survives — which is the half that ships regardless.
3. **`git check-ignore`'s default index consultation is not relied on.** D6 asks the tracked-file question separately rather than assuming git's own index behaviour for a directory path, so the false-positive lock in `LA3` holds whatever that behaviour turns out to be.
4. **`shellcheck` is available at the pinned version** in whatever environment AC14 runs; the criterion exits non-zero rather than passing vacuously if it is absent.
5. **pm-spec cannot run a `check:` line** — all twenty were written by reading the target files at this HEAD. The executing side runs them live and in full, repairs anything broken or vacuous with a meaning-preserving fix, and only then records the hash. The ones most likely to need repair are named in `## Notes for engineer`.

## Open questions

None blocking. Two items are recorded as issue candidates for the next planning input rather than filed from this role, which has no network access: the acknowledgement-flag persistence question D5 declines, and the nine-site cwd-relative resolver convention D1(i) declines to change.

## Notes for engineer

- **Order: Half B first.** It is small, independent and self-evidencing. `bin/retro-inputs.sh`'s `count_dir_entries` already takes a suffix parameter and matches with `case "$f" in *"$suffix")`, so the open-extension rule has a natural minimal shape; whichever shape you pick, `LB1` must pass with an extensionless file and an unfamiliar extension present, which rules out an enumerated suffix set.
- **The `noun` parameter for `review-artifacts` stays `review artifacts`.** The ledger's third field is a parsed grammar (`bin/retro-inputs.sh` lines 61-64) and the detail's shape (`<N> <noun> in <dir>`) is what `LB5` reads.
- **Fixture roots for the ignore cases must each be `git init`-ed.** `tests/team-paths/run.sh` deliberately avoids `mktemp` and builds roots under `tests/team-paths/tmp-roots`, which is inside this repository's own work tree — an un-`init`-ed fixture would have `git check-ignore` answer from *this* repository's rules, including its `!.shell-team/` re-include, and every ignored-base case would silently invert. Clean them up through the suite's existing `trap`.
- **A file is tracked as soon as it is `git add`-ed**; `LA3` needs no commit and therefore no `user.email` / `user.name` configuration.
- **AC11 locks the flag surface line-anchored, so do not open a line with a long-flag literal.** A `--flag` token that starts a line is read as part of the argument-parser / `print_help` surface; if the new probe needs a `git` invocation long enough to wrap, keep the continuation from beginning with `--is-inside-work-tree`, `--git-dir` or any other long flag (put the subcommand or the `git` word first, or do not wrap). Mid-line occurrences are outside the lock by design.
- **Three check lines were repaired at the freeze gate and are already correct in this file**: AC6 now extracts the whole leading comment block by walking to the first non-comment, non-blank line instead of a fixed `sed` window, so adding the very sentence it demands cannot push the header out of range; AC11 is line-anchored as above, because a whole-file extraction would have been mutually unsatisfiable with any probe that distinguishes "outside a work tree"; AC17 uses `bin/check-provenance.sh`'s real single-positional-argument shape plus a separate whole-line `<!-- BEGIN provenance: T-1042 -->` assertion, since that checker derives the task id from the file rather than from a flag. **AC14 remains dependent on `shellcheck` being on `PATH`** in the executing environment and exits non-zero rather than passing vacuously without it.
- **Measured-at-ref command check**: `not applicable — none of this task's deliverables prints a command beside a label naming the git ref its result was measured at.` The base-relative criteria above read `6439eb6`'s committed blobs through `git show` and `git diff` and never the working tree, which is the same discipline applied to the criteria rather than to a printed document.
- **Files likely touched**: `bin/retro-inputs.sh`, `bin/team-paths.sh`, `bin/team-init.sh`, `tests/retro-inputs/run.sh`, `tests/team-paths/run.sh`, `tests/team-init/run.sh`, `README.md`, `README.ja.md`, `docs/adopting.md`, `docs/adopting.ja.md`, plus the board, this spec, the provenance record and (if any intervention occurs) the interventions record.
- **Prior art worth reading before starting**: `tests/gitignore-raw-dumps/run.sh` lines 70-128 for the excludes-pinning idiom and its teeth control; `tests/rollup-track/run.sh` lines 140-190 for the same pattern under a hostile excludes file; `.shell-team/test-recipe.md` lines 47-53 for the discipline itself and lines 411-425 for the `RE_TOKEN` false-positive class.
