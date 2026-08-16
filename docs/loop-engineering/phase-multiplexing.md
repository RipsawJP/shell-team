# Within-phase agent scaling (the width axis): three tiers priced, a measured Tier-1 fan-out pilot with a real N sweep and proven aggregation, and seven invariants locked

**Task**: T-1069 · **Base ref**: `336c7835af04382ccb920a332ecd4dc2b2f0ddca` (`git merge-base feature/1068-agent-concurrency HEAD`) · **Run context**: this repository's checkout root; every command below not explicitly scoped to the Tier-1 pilot's own throwaway clone is written to run from the repo root exactly as shown. This note answers issue #253's width-axis question — whether, and where, fanning a phase's own work across N instances of one role pays — committing to no mechanism. `docs/loop-engineering/agent-concurrency.md` (#252, the depth axis), `docs/loop-engineering/effort-time-trend.md` (#248) and `docs/loop-engineering/context-lifecycle.md` (#249) are this investigation's inputs, per issue #253's own relationship to #252.

## Terms and closed vocabularies

Fixed once, here, before anything below uses one.

- **Tier ids** (closed, three — issue #253 items 1–3): `tier1-verification-fanout`, `tier2-parallel-implementations-judge`, `tier3-work-splitting`.
- **Saving-confidence words** (closed, three, inherited verbatim from `docs/loop-engineering/agent-concurrency.md`): `measured` — observed by this task's own pilot probe, never modelled; `modeled` — derived from this repository's own recorded telemetry or git-tracked corpora, never observed live by a pilot; `undetermined` — no recorded field supports either a measurement or a defensible model, stated with the reason rather than estimated. "This task's own pilot" resolves to T-1069's own Tier-1 fan-out pilot below.
- **Partition-kind words** (closed, two — issue #253's own central dividing line): `mechanical` (the work-list can be split into independent units with no design judgment) and `design-judgment` (partitioning the work itself requires a human or PM decision).
- **Measured-legitimacy ids** (closed, five, DP-D): `production-unit`, `real-population`, `same-machine-session`, `aggregation-proven`, `repetition-variance`.
- **Pilot-safety ids** (closed, five, DP-C): `scratch-clone-venue`, `no-worktree-add`, `per-worker-output-files`, `no-real-writes`, `liveness-control`.
- **Liveness vocabulary** (closed, two): `timeout-available`, `timeout-absent`.
- **Invariant ids** (closed, seven — the six `docs/loop-engineering/agent-concurrency.md` locks plus the width axis's own): `both-gates-green`, `fail-closed-checkers`, `bin-pure-bash`, `human-gate-set`, `frozen-intent-no-concurrent-attest`, `handoff-attributable`, `per-instance-telemetry-discriminator`.
- **Recommendation words** (closed, three — extended from the sibling note's two, since issue #253 asks for a per-tier disposition in which outright adoption is a legal outcome): `staged-adoption`, `not-yet`, `adopt`.
- **Dividing-line verdicts** (closed, three): `supported`, `not-supported`, `undetermined`.
- **Aggregation-check verdicts** (closed, two): `identical`, `divergent`.
- **Break-even parameter confidence** (closed, three, the same saving-confidence words applied to a single symbolic parameter): `measured`, `modeled`, `undetermined`.

**Line grammars**, every labelled line at column 0 unless noted, evidence sub-bullets indented exactly two spaces:

- `- tier: <id> — <mechanical|design-judgment> — <S|M|L> — <description>`
- `- saving: <id> — <measured|modeled|undetermined> — <text>`, with indented `- removes-phase: `, `- saving-cap: `, `- precision-cost: `, `- token-cost: `, `- rework-amplification: ` sub-bullets, each non-empty
- `- dividing-line: <supported|not-supported|undetermined> — <reason>` (exactly one, note-wide)
- `- population: <id> — <digits> — <text>`, with indented `- command: ` and `- measured-at: ` sub-bullets
- `- cores: <digits> — <text>`, with an indented `- command: ` sub-bullet
- `- pilot-arm: n=<digits> — <wall-clock-ns> — reps=<digits> — <spread>`
- `- aggregation-check: <arm-id> — <identical|divergent> — <text>`
- `- pilot-safety: <id> — <text>`
- `- liveness: <timeout-available|timeout-absent> — <control-actually-used> — <reason>`
- `- measured-label: <id> — <met|not-met> — <evidence>`
- `- break-even: <parameter-id> — <measured|modeled|undetermined> — <value-or-reason>`
- `- break-even-condition: <text>` (exactly one)
- `- invariant-lock: <id> — <text>`
- `- recommendation: <tier-id> — <staged-adoption|not-yet|adopt> — <text>`
- `- follow-up: <text>`

A block ends at the next column-0 `- ` line or the next `## ` heading.

## Relationship to the depth axis

`docs/loop-engineering/agent-concurrency.md` already shipped on this branch's base and answers issue #252's six depth-axis questions (intra-task overlap, inter-task pipelining, isolation mechanics, shared-state contention, hard serialization points, orchestration substrate). Issue #253 permits merging this width-axis investigation into that deliverable "if the depth/width designs converge" — but that note is already merged prose this task has no mandate to touch (DP-A), so this is a **separate note that cross-references it**, the settled shape.

The contract-surface count is stated honestly here rather than inherited by assumption: the sibling note enumerates six contract surfaces; the seventh is recorded only in issue #274 — a `codex-reviewer` record commit racing qa-verifier's own HEAD-relative checks in the reviewer→QA direction, disclosed in issue #274's item 7 and never in `docs/loop-engineering/agent-concurrency.md` itself. No claim anywhere in this note attributes a seventh surface to that sibling note.

The joint evaluation issue #253 asks for against `docs/loop-engineering/context-lifecycle.md`'s three accumulation sites (`S1-orchestrator-session`, `S2-resumed-subagent`, `S3-launch-brief`) lands on `S3-launch-brief`: N instances of one role each need their own launch brief, so a width-axis fan-out multiplies that one site by N while leaving `S1` and `S2` exactly where they are. This is the concrete component the `precision-cost` axis below prices, rather than a vague appeal to "coordination overhead."

## Tier inventory and cost model

Each tier occupies exactly one `- tier: ` line and exactly one paired `- saving: ` line.

- tier: tier1-verification-fanout — mechanical — M — fan out an existing phase's own mechanically-enumerable, read-only verification work (e.g. a full-population blast-radius sweep, one `bash bin/check-acs.sh <spec>` run per spec) across N instances of one role, aggregating N partial verdicts into one authoritative verdict before that phase's own existing, unchanged gate.
- saving: tier1-verification-fanout — measured — this pilot's own serial arm (`n=1`) averaged 297164683500 ns across 2 reps; the fastest swept arm (`n=9`) averaged 166883349000 ns — a 43.84% wall-clock reduction (`(297164683500-166883349000)/297164683500`) — with all five `- measured-label: ` conditions below `met`.
  - removes-phase: the wait for one worker to sequentially run `bash bin/check-acs.sh` once per spec across an independent, read-only spec population — the same phase shape T-1062's own engineer-phase blast-radius sweep exercised in production.
  - saving-cap: bounded below by this population's own single most expensive unit, `.shell-team/specs/T-1044-test-infra-bundle.md`, measured alone at 142965525000 ns (≈48.1% of the serial total) — no degree of fan-out below sub-dividing that one spec's own AC-level checks can push the wall clock under that unit's own serial cost, which is exactly what this sweep observed (the wall clock plateaus at `n≥4`: 171141504500 ns, then 167382372500 ns, then 166883349000 ns, never approaching zero).
  - precision-cost: the deterministic-selection judgment this pilot itself performed (choosing and fixing the population before any arm ran, per DP-C) is the concrete unit here; a real per-instance agent fan-out additionally multiplies the `S3-launch-brief` accumulation site above by N, since N agent instances each need their own launch brief rather than one shared verification-phase brief.
  - token-cost: undetermined — this pilot's own units are shell processes running an existing checker, not N agent invocations; no telemetry field isolates a verification-only agent's own token cost from a full phase's recorded total, so the real per-instance token multiplier a true agent-level fan-out would carry is not observed here.
  - rework-amplification: undetermined — no fan-out of any kind has ever run in this repository's own history; no recorded field measures whether decomposing verification work across N instances raises or lowers the `rounds-to-approve` series `docs/loop-engineering/agent-concurrency.md` publishes from the git-tracked reviews corpus.
- tier: tier2-parallel-implementations-judge — design-judgment — M — run 2+ independent engineer attempts at the same task concurrently, then a new judge role picks (or merges non-overlapping pieces of) one candidate before Validate — discarding the losing attempt(s) rather than reconciling them, so it does not need the multi-worktree merge Tier 3 needs.
- saving: tier2-parallel-implementations-judge — undetermined — no experiment was run (Non-goals); DP-D(a) bars `measured` without a pilot's own arm, and no recorded field models a judge pass's own cost or benefit.
  - removes-phase: a single first-shot implementation that fails Validate/Review and must be reworked — parallel competing implementations would, in principle, let a judge pick a stronger candidate before Validate, potentially removing some fraction of the `rounds-to-approve` rework this task inherits from the sibling note's own series.
  - saving-cap: undetermined — no historical run of competing implementations exists in this repository to bound how often a second independent attempt would have passed where the first failed.
  - precision-cost: a new judge role and a mechanical scoring contract it could apply across N candidate diffs — a contract this task does not design, priced only as a named gap.
  - token-cost: at minimum an N-times multiple of one task's own engineer-phase token cost, since N full independent implementations must be produced before any judging can occur; `docs/loop-engineering/effort-time-trend.md`'s own per-task engineer figures are the base this multiple would apply to, but N itself is undetermined.
  - rework-amplification: undetermined — no historical run of this tier exists to measure whether judging shifts or reduces rework rounds.
- tier: tier3-work-splitting — design-judgment — L — partition one feature's own implementation across N engineers each owning a disjoint file set, landing all N onto one branch — the true engineer×N split issue #253 names as lowest-value, research-grade, blocked on the same 2+ concurrent-worktree reconcile `skills/run/SKILL.md` itself declares NOT covered.
- saving: tier3-work-splitting — undetermined — no experiment was run (Non-goals); the break-even model below is symbolic, not a measurement.
  - removes-phase: the serial wall clock of one engineer implementing a large, partitionable feature — in principle, N engineers each owning a disjoint file-set slice, landing concurrently, could remove most of a single task's own serial engineer-phase wall clock, for a feature large enough to partition that way.
  - saving-cap: undetermined — no baseline measures how much of a real feature's own implementation work is genuinely partition-safe versus interface-coupled.
  - precision-cost: pm-spec would need to author a spec-partition grammar (non-overlapping file sets, pre-agreed interfaces as frozen spec artefacts, per DP-E) before any split could run safely — a new authoring discipline never used in this repository, priced only as a written sketch below.
  - token-cost: undetermined — no recorded field isolates a partitioned engineer sub-task's own token cost from a whole-feature engineer phase's total.
  - rework-amplification: modeled from the canonical `rounds-to-approve` series `docs/loop-engineering/agent-concurrency.md` publishes from the git-tracked reviews corpus (`T-1056` 3, `T-1057` 2, `T-1058` 1, `T-1060` 9, `T-1061` 3, `T-1062` 4, `T-1063` 2, `T-1064` 1, `T-1065` 4, `T-1066` 5, `T-1067` 3) — the base rate any split-induced rework increase would have to be compared against, used as an input to the break-even model below rather than re-derived from telemetry.
- dividing-line: supported — the only tier this task could pilot end-to-end and prove safe (`tier1-verification-fanout`, `mechanical`) produced a real, sizable, `measured` wall-clock saving; both `design-judgment` tiers (`tier2`, `tier3`) remain `undetermined` or blocked on unbuilt mechanism, exactly as issue #253's own hypothesis predicts — qualified, because even the mechanical tier's own saving is capped by this population's own unit granularity (the `T-1044` outlier), not unbounded, so "the same-day wins live on the mechanical side" is supported as a direction, not as a guarantee of an arbitrarily large win.

**What licenses `measured` for `tier1-verification-fanout` (DP-D)**:

- measured-label: production-unit — met — the pilot's own unit is literally `bash bin/check-acs.sh <spec>`, the exact command T-1062's own verification-heavy phase and this repository's own acceptance-criteria gate use, not an agent-invocation proxy.
- measured-label: real-population — met — every arm ran the same 9-file subset enumerated live from the pinned ref's own committed tree (`## Tier-1 pilot: verification fan-out`'s own `- population: ` line); every file is a real, committed spec (or, in one case, a real committed design note), never a synthetic fixture.
- measured-label: same-machine-session — met — every arm and every rep ran on this task's own operator machine, in one continuous working session, inside the same throwaway clone; the core count was measured live on that same host.
- measured-label: aggregation-proven — met — every one of the 9 non-baseline arm/rep files produced a byte-identical `LC_ALL=C sort` output against the serial `n=1, rep=1` baseline; none diverged.
- measured-label: repetition-variance — met — every one of the 5 swept degrees (`n=1,2,4,8,9`) ran 2 reps; the spread (max−min) is disclosed on each `- pilot-arm: ` line, ranging from 87997000 ns (`n=4`) to 2737808000 ns (`n=9`).

All five conditions are `met`; no condition here is `not-met`, so `measured` is licensed for `tier1-verification-fanout`'s own saving above and for no other tier's saving.

## Tier-1 pilot: verification fan-out

**Unit and venue.** The pilot's unit is one `bash bin/check-acs.sh <spec>` run per spec file — the production verification unit itself, not an agent-invocation proxy. The venue is a throwaway `git clone` under `$TMPDIR` (referred to below as `$SCRATCH/clone`), created from this repository's own working tree and pinned to `336c7835af04382ccb920a332ecd4dc2b2f0ddca` before the population was enumerated or any arm ran; `git -C "$SCRATCH/clone" status --short` read empty at that point, confirming the clone's own committed tree matched the pinned ref exactly. `git worktree add` was never used for this venue — a plain `git clone` was.

- population: spec-corpus-subset — 9 — a deterministically-selected stride-9 subset of the pinned ref's committed spec corpus, selected once, before any arm ran, and never re-selected after seeing a verdict. The full corpus at this ref carries 73 spec files (`git ls-tree -r --name-only 336c7835af04382ccb920a332ecd4dc2b2f0ddca -- .shell-team/specs/ | grep -c '\.md$'` → `73`); an initial stride-5 selection (15 files) was tried first and abandoned before any of its runs completed, once a single serial pass exceeded this pilot's own wall-clock budget — a budget decision, made before any of that abandoned attempt's own AC verdicts were read, disclosed in full in `## Limits and what is not computable` below.
  - command: `git ls-tree -r --name-only 336c7835af04382ccb920a332ecd4dc2b2f0ddca -- .shell-team/specs/ | grep '\.md$' | LC_ALL=C sort | awk 'NR%9==1'`
  - measured-at: `336c7835af04382ccb920a332ecd4dc2b2f0ddca` (`git merge-base feature/1068-agent-concurrency HEAD`), read from the pinned clone's own committed tree, never the working tree.
  - result: 9 files — `T-1000-operating-conventions.md`, `T-1009-doc-drift-and-false-ci-claim.md`, `T-1018-freeze-attestation-gate.md`, `T-1026-skill-md-doc-completeness.md`, `T-1035-spec-template-staleness-locks.md`, `T-1044-test-infra-bundle.md`, `T-1054-binding-config.md`, `T-1063-editorial-batch.md`, `design-note-T-1012.md` (all under `.shell-team/specs/`).
- cores: 8 — measured live on the pilot host, never inherited from `docs/loop-engineering/agent-concurrency.md`'s own single N=2 measurement (also 8 on that task's own machine — a coincidence disclosed, not assumed).
  - command: `getconf _NPROCESSORS_ONLN`
  - result: 8

**The sweep.** Five degrees of concurrency were run, each for 2 reps: `n=1` (serial), `n=2`, `n=4`, `n=8` (equal to the measured core count), and `n=9` (strictly greater than the measured core count, and equal to the population size — one worker per spec, the finest granularity this population supports). Each rep's workers were split from the population by round-robin assignment, each worker running its own chunk of specs through `bash bin/check-acs.sh` sequentially and appending `<spec>\t<AC-verdict-line>` to its own private output file; files were concatenated into one merged file per arm/rep only after every worker in that arm had exited. T-1062's 133 check-runs are an order-of-magnitude anchor, not this pilot's serial arm — this pilot's own serial arm measured a real, independent 9-file subset directly, at 297164683500 ns (≈297.16 s) average across 2 reps, never borrowed from that different population on that different date.

- pilot-arm: n=1 — 297164683500 — reps=2 — spread 842645000 ns (rep1=297586006000, rep2=296743361000)
- pilot-arm: n=2 — 196897639500 — reps=2 — spread 2574973000 ns (rep1=198185126000, rep2=195610153000)
- pilot-arm: n=4 — 171141504500 — reps=2 — spread 87997000 ns (rep1=171185503000, rep2=171097506000)
- pilot-arm: n=8 — 167382372500 — reps=2 — spread 2644277000 ns (rep1=168704511000, rep2=166060234000)
- pilot-arm: n=9 — 166883349000 — reps=2 — spread 2737808000 ns (rep1=168252253000, rep2=165514445000)

**The knee.** Wall clock drops sharply from `n=1` to `n=2` (≈33.7%), a further, smaller drop from `n=2` to `n=4` (≈13.1%), then plateaus: `n=4`→`n=8` moves only ≈2.2%, and `n=8`→`n=9` moves ≈0.3%. The floor is explained by one outlier unit, measured directly and separately from the sweep:

- command: `bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md` (run alone, once, inside `$SCRATCH/clone`)
- result: 142965525000 ns (≈142.97 s) — `T-1044-test-infra-bundle.md`'s own checks recursively invoke `bash bin/check-acs.sh` against other specs and loop over every file under `tests/` and `bin/`, making it roughly 48.1% of the serial total's own wall clock on its own. Because the pilot's unit is one whole spec per worker (not one AC per worker), no degree of fan-out can push any arm's wall clock below this single unit's own serial cost once it lands in some worker's queue — which is exactly why every arm at `n≥4` converges near, but never below, that value.

**Aggregation correctness.** Every arm's merged, per-rep file was compared against the `n=1, rep=1` baseline by writing `<spec>\t<AC-verdict-line>` records, `LC_ALL=C sort`-ing both sides, and `diff`-ing the sorted files — verdicts are paired by matching value, never by row order, since a spec quoting an illustrative example AC inside a fenced block (a real, documented hazard in this corpus, per `.shell-team/test-recipe.md`'s own T-1062 entry, though not present in this pilot's own 9-file population) would otherwise make positional pairing produce spurious differences that are artefacts of ordering rather than of concurrency; a spec producing no verdict line is recorded with an explicit sentinel row: this pilot's own population supplied a real instance — `design-note-T-1012.md` is a design note, not a spec, and `bash bin/check-acs.sh` exits 2 against it with zero `AC<n>:` lines; every one of the 10 arm/rep runs recorded the identical `SENTINEL: exit=2 no-verdict-lines` row for it, confirmed byte-identical in every comparison below.

- command: `LC_ALL=C sort <merged-arm-rep>.tsv > <merged-arm-rep>.sorted.tsv` (run once per one of the 10 arm/rep files)
- command: `diff n1-rep1.sorted.tsv <other-arm-rep>.sorted.tsv` (run once per one of the 9 non-baseline arm/rep files)
- aggregation-check: n1-rep2-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n2-rep1-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n2-rep2-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n4-rep1-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n4-rep2-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n8-rep1-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n8-rep2-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n9-rep1-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0
- aggregation-check: n9-rep2-vs-n1-rep1 — identical — 135 rows each side, byte-identical after sort, `diff` exit 0

Every arm's 135 rows break down identically as 76 `PASS`, 50 `FAIL`, 8 `SKIP` and 1 sentinel row — no arm gained or lost a row relative to any other. No spec in this pilot's own population happened to carry a duplicate-labelled AC from a fenced illustrative example (the fence-unawareness hazard `.shell-team/test-recipe.md` documents); this pilot's own aggregation was never exercised against that specific hazard, which is disclosed in the Limits below rather than claimed tested.

**Pilot safety (DP-C, five ids, closed):**

- pilot-safety: scratch-clone-venue — every arm ran inside one throwaway `git clone` under `$SCRATCH` (a directory under `$TMPDIR`), pinned to `336c7835af04382ccb920a332ecd4dc2b2f0ddca`; `git -C "$SCRATCH/clone" status --short` read empty before the population was enumerated, confirming the population and every unit executed came from that exact committed tree.
- pilot-safety: no-worktree-add — no arm, worker or aggregation step invoked `git worktree add`; the clone above was created with a plain `git clone`, never a worktree, and no `- command: ` line anywhere in this note contains `git worktree add`.
- pilot-safety: per-worker-output-files — every worker (one per population chunk, per arm/rep) wrote its own `<spec>\t<AC-verdict-line>` records to its own private output file; files were concatenated into one merged-per-arm-rep file only after every worker in that arm had exited, never appended to concurrently by two workers.
- pilot-safety: no-real-writes — no pilot process wrote to `.shell-team/todo.md`, any `.shell-team/provenance|interventions|reviews/` file, or `.shell-team/runs/shell-team.jsonl`; every unit ran read-only inside `$SCRATCH/clone`, and this task's own commits (below) were all made afterward, from outside that clone, against the real checkout.
- pilot-safety: liveness-control — see the `- liveness: ` line below; no per-unit kill mechanism existed on this host, so the actual bound enforced was this pilot's own small, deterministically-selected population plus foreground wall-clock supervision of every arm.

- liveness: timeout-absent — `command -v timeout` and `command -v gtimeout` both resolved to nothing on this pilot host — no parent-signal watchdog structure is re-attempted (the design defeated twice in consecutive rounds on the sibling task's own pilot); with `timeout` absent, `bash bin/check-acs.sh`'s own internal per-check cap was equally absent, so the bound actually enforced was this pilot's own small, deterministically-selected population (9 of 73 spec files) plus this task's own foreground wall-clock supervision of every arm — no unit ever ran long enough to need a kill, and the single longest unit (`T-1044-test-infra-bundle.md`, measured alone above) completed in 142965525000 ns with no hang.

## Tier-2 feasibility (paper only)

No experiment was run for this tier (Non-goals); the disposition above is entirely paper-based. A judge role would need to read N candidate diffs against the frozen spec's own acceptance criteria and pick one (or, if the candidates' own changes are non-overlapping, merge disjoint pieces) before Validate — never after, since Validate and Review already gate on one committed tree per `docs/loop-engineering/agent-concurrency.md`'s own `both-gates-green` invariant. Two costs this tier carries that Tier 1 does not: the discard cost of N−1 wasted implementation attempts (full engineer-phase token and wall-clock cost each, per the `token-cost` sub-bullet above), and the judge's own scoring reliability, which this task has no data to evaluate — no judge role exists anywhere in this repository's own shipped `agents/` today, and building one to pilot would itself be a mechanism this task's own `- verification-class: no-mechanism` declaration forbids. Unlike Tier 3, this tier does not need the 2+ concurrent-worktree reconcile below, because only one candidate's own work ever lands; the other N−1 are discarded entire; that structural difference is why Tier 2 is priced `M` rather than `L`.

## Tier-3 pilot: work splitting

(The analysis of this section is written by the engineer phase; the raw evidence below was committed by the orchestrator at the end of the pilot's execution phase and is byte-frozen from that commit.)

- evidence-commit: 443ce84cb736b3b152825cb238a96a833f21807e — the orchestrator's own commit of the raw-evidence region below; the region is byte-frozen from it (AC11 compares this commit's blob against HEAD).

<!-- BEGIN pilot3-evidence: T-1078 -->
- venue: a throwaway clone of this repository under the session temp dir; every `git worktree add` ran inside that clone, never in the real checkout; the coordinator branches were never checked out anywhere.
- pinned-base: pilot-base = 4657de19b264cd6fd2a36d80efdb374243fe84e0 (the subject task's README, frozen interface contract, and the partition manifest, committed before any instance launched and never re-partitioned).
- subject: `wordstats` — a two-library-plus-CLI shell tool with two standalone test suites; partition: owner-a = { lib/parse.sh, tests/parse_test.sh }, owner-b = { lib/stats.sh, bin/wordstats, tests/stats_test.sh } (disjoint by construction; the serial arm implements the union).
- wall-clock definition applied to every arm: t0 is the orchestrator's own launch call for that arm; the arm ends at the last completion notification plus that arm's own landing spans. Orchestrator-idle gaps between a notification and the next command are excluded by this definition.
- arm-timing: serial-n1 — rep1 334625 ms, rep2 278772 ms — mean 306699 ms.
- arm-timing: parallel-n2 — rep1 456099 ms, rep2 515770 ms — mean 485935 ms (landings included: rep1 468+490 ms; rep2 landing-a approximated from record-file mtime because a shell error lost its timer — disclosed, sub-second, consistent with the three exact measurements — plus 475 ms).
- arm-timing: rework-parallel-n2 (seeded cross-partition change-request) — rep1 236690 ms, rep2 293220 ms — mean 264955 ms.
- arm-timing: rework-serial-n1 (same seeded change-request) — rep1 220822 ms, rep2 221039 ms — mean 220931 ms.
- per-instance agent runtimes (harness usage, ms): serial 303524 / 240020; parallel workers a=177034 b=396914 (rep1), a=189918 b=470048 (rep2); rework a=132029 b=184510 serial=191091 (rep1), a=110877 b=246359 serial=147300 (rep2).
- launch-plus-notification overhead per arm, derived (arm wall-clock minus the arm's longest instance runtime): serial rep1 31101 ms, serial rep2 38752 ms — consistent with the launch-latency range the harness note records, plus notification handling.
- landings: 8 of 8 `mode: landed`, zero refusals, through the unmodified shipped coordinator; measured durations 468, 490, 475, 458, 459, 475, 462 ms (one further landing's timer was lost to a shell error and is mtime-approximated at under one second).
- landed tips: primary rep1 1b201fd -> 49c220c; primary rep2 2afc858 -> cf3ca2f; rework rep1 02d1386 -> ddce642; rework rep2 1d54a85 -> 35bc040 (all clone-local refs).
- composed-tip verification: all four compositions extracted with `git archive` and both test suites run — every suite exit 0; end-to-end CLI checks correct on the primary compositions and on both rework compositions (MINLEN filtering observed working through the real composed pipeline).
- seeded rework observation: the seeded change-request (an interface extension spanning the partition boundary: a new optional MINLEN parameter threaded from the CLI into the parser) forced BOTH owners to rework in BOTH parallel reps (2 of 2 owners), versus exactly one instance in each serial rep.
- partition-overhead, serialization half: the landing durations above — well under one second per landing at this repository's scale.
- partition-overhead, authoring half: the partition manifest (7 lines) and the frozen interface contract (5 lines) were authored by the orchestrator inside the venue-setup interval, measured as 139 s between the adjacent commits that bound it (the spec-freeze commit and pilot-base) — an upper bound that also contains the clone itself and one denied-command retry; not separately instrumented below that bound.
- telemetry: 18 span rows recorded in the real runs file under one run id, instance-tagged with `--instance` and `--seq auto`; two verbatim reconcile rows follow.
- span-row verbatim: {"loop_id":"shell-team","run_id":"t1078-20260816T190505Z","seq":7,"ts":"2026-08-16T19:59:41Z","span":"orchestrator","phase":"reconcile","iteration":0,"attempt":1,"status":"success","model":null,"tokens":null,"tool_uses":null,"duration_ms":468,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":null,"effort":null,"adapter":null,"instance":"eng-a-r1"}
- span-row verbatim: {"loop_id":"shell-team","run_id":"t1078-20260816T190505Z","seq":8,"ts":"2026-08-16T19:59:41Z","span":"orchestrator","phase":"reconcile","iteration":0,"attempt":2,"status":"success","model":null,"tokens":null,"tool_uses":null,"duration_ms":490,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":null,"effort":null,"adapter":null,"instance":"eng-b-r1"}
- real-checkout cleanliness: measured after every arm — `git status --short` empty and `git ls-files --others --exclude-standard` empty, every time (five readings).
- instances: 12 of 12 launched instances ran to completion with a liveness watchdog started at launch through a harness-tracked background launch; no stall, no partial return, no out-of-partition write (every landing's claim set matched its owner's manifest lines exactly).
<!-- END pilot3-evidence: T-1078 -->

## Tier-3 feasibility and break-even model (paper only)

No experiment was run for this tier (Non-goals); issue #253 itself asks for a written feasibility verdict only, in three parts.

**Multi-worktree integration sketch.** `docs/loop-engineering/agent-concurrency.md`'s own `## Isolation and reconcile` section already describes, in prose, what closing the 2+ concurrent-worktree gap `skills/run/SKILL.md` itself declares NOT covered would require: a single serializing coordinator (the same merge-queue shape that note's own `## Prior art (external)` names) that processes pending worktrees one at a time, rebasing each pending worktree's own commit onto the *current* tip rather than its original base, re-running the same verification gate against the rebased commit before advancing, and only then merging `--ff-only` before the next pending worktree's own rebase. Tier 3's own engineer×N split needs exactly this reconcile, because unlike Tier 2, every one of the N engineers' own work is meant to land, not be discarded — the reconcile is not optional scaffolding for Tier 3, it is the mechanism that makes N-way landing possible at all.

**Spec-partition grammar.** pm-spec would need a new authoring discipline before any split could run safely: non-overlapping file sets assigned per engineer instance, and pre-agreed interfaces recorded as frozen spec artefacts (so that engineer A's own work does not silently assume a function signature engineer B's own work changes). No spec in this repository has ever been authored this way; this is a written requirement, not a built grammar.

**Break-even model**, every parameter labelled with its own confidence word, at least one `undetermined`:

- break-even: engineer-phase-duration — modeled — per-task engineer-phase wall clock, per `docs/loop-engineering/effort-time-trend.md`'s own published per-task figures — the serial baseline any split's own combined wall clock would have to beat.
- break-even: partition-overhead — undetermined — no recorded field isolates the wall-clock or token cost of authoring a multi-engineer spec-partition grammar, since this discipline has never been used in this repository's own history; no baseline exists to model it from.
- break-even: reconcile-cost — modeled — bounded below by the single-serializing-coordinator shape `## Isolation and reconcile` above describes: each pending worktree beyond the first needs a rebase, a re-run of the chosen verification gate, and a `--ff-only` merge before the next proceeds, so the reconcile cost scales with the number of concurrent splits queued behind the first, not with a fixed constant.
- break-even: rework-amplification-input — modeled — the canonical `rounds-to-approve` series `docs/loop-engineering/agent-concurrency.md` publishes from the git-tracked reviews corpus (`T-1056` 3, `T-1057` 2, `T-1058` 1, `T-1060` 9, `T-1061` 3, `T-1062` 4, `T-1063` 2, `T-1064` 1, `T-1065` 4, `T-1066` 5, `T-1067` 3), used as the base rate any split-induced rework increase must be compared against, cited by that note's own path rather than re-derived from telemetry.

- break-even-condition: breaks even if N engineers' own combined implement-phase wall clock, plus the reconcile coordinator's own per-split rebase-and-re-verify cost, stays below the single-engineer serial implement-phase wall clock the same feature would otherwise have taken — a condition this note cannot evaluate numerically today, because `partition-overhead` is `undetermined` and no reconcile mechanism exists yet to measure `reconcile-cost` against in production.

## Invariants that must not loosen

- invariant-lock: both-gates-green — fanning a phase's own verification work across N instances changes only how many workers produce partial verdicts before they are aggregated into one board-visible verdict, never whether a task still needs `qa-verifier`'s own subsequent `PASS` and `codex-reviewer`'s own subsequent `APPROVE` before `READY_FOR_MERGE`; this pilot's own aggregation proof (a byte-identical verdict multiset across every swept arm) is exactly what a real adoption would need before reducing N partial verdicts to the one authoritative verdict that unchanged gate reads.
- invariant-lock: fail-closed-checkers — every worker in this pilot ran the identical, unmodified `bash bin/check-acs.sh`; no checker's own semantics moved, and a real fan-out would still run each unit through that same unmodified check — concurrency changes only which process runs which unit, never what any unit checks.
- invariant-lock: bin-pure-bash — this task ships no mechanism (`- verification-class: no-mechanism`); nothing under `bin/` was added or edited, and this pilot's own worker/driver scripts exist only inside the throwaway clone under `$TMPDIR`, never committed to this repository.
- invariant-lock: human-gate-set — the three human gates (the sprint's own batch GO, planning approval, and confirmation before a destructive or irreversible operation) are untouched; within-phase width scaling changes how many workers a phase's own work is split across, never which decisions require a human.
- invariant-lock: frozen-intent-no-concurrent-attest — a spec's frozen intent block is still attested by exactly one role at one point in time, at Specify, before Implement/Validate/Review begin; nothing about fanning a later phase's own verification work out across N instances of one role touches the freeze/attestation flow, which happens earlier in the loop and is structurally unaffected by width-scaling a downstream phase.
- invariant-lock: handoff-attributable — every pilot worker wrote its own per-worker output file, merged only after every worker in that arm had exited, never appending to one shared file two workers could race on (`- pilot-safety: per-worker-output-files` above); a real N-instance fan-out inherits the same shape for its own scratch state, and the seventh invariant below is exactly what closes the remaining gap — attributing the *merged*, board-visible hand-off record itself to the instance that produced each of its parts, not merely keeping scratch files apart.
- invariant-lock: per-instance-telemetry-discriminator — named as a follow-up only (DP-F): no discriminator is designed, no telemetry schema changes, and no `bin/` script is touched by this task. A real N-instance fan-out would need one so that a hand-off record stays attributable to the specific instance that produced it, exactly as issue #253's own invariants paragraph asks; this task's own `no-mechanism` class forbids building it here.

## Recommendation and follow-ups

- recommendation: tier1-verification-fanout — staged-adoption — the only tier with a real, `measured`, positive wall-clock saving (43.84% at this pilot's own swept degrees) and a proven-safe aggregation method; gated explicitly on two named preconditions this task's own pilot could not build, per the `no-mechanism` class: (1) the `per-instance-telemetry-discriminator` invariant above, carried as a follow-up; (2) an orchestration step (in `skills/run/SKILL.md` or equivalent) that can actually launch N *agent* instances for one phase and aggregate their verdicts — this pilot's own units were shell processes running an existing checker, never a real Agent-tool-level launch, exactly as `docs/loop-engineering/agent-concurrency.md`'s own `agent-tool-concurrent-launch — absent` row already discloses for the depth axis and this task does not re-test.
- recommendation: tier2-parallel-implementations-judge — not-yet — blocked on a judge role and its own scoring contract, neither of which exists in this repository's own shipped `agents/` today; no experiment has been run (Non-goals), and the saving remains `undetermined`.
- recommendation: tier3-work-splitting — not-yet — blocked on the same 2+ concurrent-worktree reconcile `docs/loop-engineering/agent-concurrency.md`'s own `## Isolation and reconcile` section already describes and does not build; the break-even model above cannot be evaluated numerically while `partition-overhead` stays `undetermined`.
- follow-up: design the `per-instance-telemetry-discriminator` so a real N-instance fan-out's own merged hand-off records stay attributable per the seventh invariant above — out of this task's own `no-mechanism` scope.
- follow-up: verify empirically whether this harness genuinely runs N concurrent Agent-tool sub-agent invocations from one orchestrator session — the same open item `docs/loop-engineering/agent-concurrency.md`'s own follow-ups already name for the depth axis, unresolved by this task's own shell-process-only pilot and a precondition `staged-adoption` above is explicitly gated on.
- follow-up: re-run this pilot's sweep over the full 73-file spec corpus, or a larger deterministically-selected subset, once a wall-clock budget larger than this pilot's own ~9-file allowance exists, to confirm the knee holds at a larger, more heterogeneous population.
- follow-up: investigate splitting the single largest per-spec check-run (`T-1044-test-infra-bundle.md`, measured alone at 142965525000 ns) into its own AC-level units, since this pilot's own measurement shows spec-level fan-out granularity caps the achievable speedup at roughly that one unit's own serial cost, regardless of N.

## Limits and what is not computable

- This pilot's own population is a 9-file, stride-9 subset of a 73-file corpus, on one operator machine, at one point in time; the knee measured here is a property of this machine's core count, not a portable constant, and the specific plateau point (`n≥4`) is additionally a property of this population's own cost distribution (one outlier unit dominating), not a property of `check-acs.sh` or of concurrency in general.
- An initial stride-5 selection (15 files) was tried first and abandoned mid-run once its own serial pass exceeded this pilot's own wall-clock budget; this was a budget decision made before any of that attempt's own AC verdicts were read or compared, never a re-selection made after seeing a verdict, and none of that attempt's own data is used anywhere in this note.
- No spec in this pilot's own 9-file population happened to carry the fence-unawareness hazard `.shell-team/test-recipe.md` documents (a duplicate-labelled AC from a fenced illustrative example); this pilot's own aggregation method is designed to survive that hazard (value-matched, never positional, pairing), but the hazard itself was not exercised by this specific run, which is a gap in coverage, not a claim that the hazard cannot occur.
- `implement-tail-parallel-qa`-style precision costs are not modeled for either Tier 2 or Tier 3 beyond what is stated above; no recorded telemetry field isolates a partitioned or duplicated engineer sub-phase's own token cost from a whole-task engineer phase's total, the same decomposition gap `docs/loop-engineering/agent-concurrency.md` names for its own `implement-tail-parallel-qa` candidate.
- No inferential-statistics claim (a significance test, a confidence interval, a regression) is made anywhere in this note over the sweep's 2 reps per arm or over the 11-task `rounds-to-approve` series it cites; both are small, non-experimental, single-repository samples, and spread is disclosed descriptively only.
- No dollar cost, vendor price model, or estimated/interpolated value is reported anywhere in this note; every figure is either read from a git-tracked source and named, or measured live on this pilot's own host and labelled as such.
- Whether this harness genuinely runs N concurrent Agent-tool sub-agent invocations from one orchestrator session is not verified by this task, exactly as `docs/loop-engineering/agent-concurrency.md` already discloses for the depth axis; this task's own pilot exercised only shell-process-level concurrency inside a throwaway clone.
- This pilot ran on a host where `command -v timeout` and `command -v gtimeout` both resolve to nothing; a host where `timeout` is available would let a real adoption bound each unit's own worst case directly, a control this pilot's own measurement could not exercise.
