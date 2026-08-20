# Agent launch fan-out — the plugin-role concurrency probe and the launch record's first live run (T-1083)

## Probe evidence (raw, orchestrator-produced)

Produced by the coordinating session (the orchestrator) on 2026-08-18, before the engineer was invoked, per the frozen probe protocol in `.shell-team/specs/T-1083-agent-launch-fanout.md` (intent v1 `02b43df902d1a0f06c7a2bb353098c0ddceaa7dc`). Everything in this section is a raw observation; analysis lives in the other sections, which were assembled later from this section without altering a byte of it. Every filesystem path below is `$TMPDIR`-relative or a `<placeholder>`; no home-directory absolute path appears anywhere in this evidence.

### Execution conditions

- clock source: `date +%s%N`, verified expanding on this host before any arm ran — sample value `1787061684842511000`, 19 digits, no literal `N` (the BSD non-expansion case did not occur; a python3 `time.time_ns()` cross-read taken in the same second agreed to within 150 ms). All timestamps below are epoch nanoseconds from this one source, single machine, single session.
- logical cores: `getconf _NPROCESSORS_ONLN` = 8. `TEAM_FANOUT_MAX` unset, so the degree rule's cap ground is `measured-cores=8`.
- venue: a throwaway `git clone --no-hardlinks` of the repository under `$TMPDIR/t1083-probe-venue/clone`, checked out detached at the branch point `01ef1108836839120217accfd8a56be4ed2ae008` (verified by `git rev-parse HEAD` in the clone). `git worktree add` was never used. All probe telemetry was written with `TEAM_RUNS_DIR` pointed inside the clone.
- per-spec unit costs, measured singly (serially) in the clone before any arm ran, `CHECK_ACS_TIMEOUT=300`, wall-clock ms: T-1044-test-infra-bundle=156440; T-1077-worktree-reconcile=112703; T-1072-telemetry-span-discriminator=65337; T-1074-fanout-orchestration=44724; T-1048-handoff-durability-barrier=12389; T-1046-ignored-base-verdict=16511; T-1069-phase-multiplexing=4708; T-1080-depth-axis-contract=7612; T-1081-freeze-sweep-hardening=1176; T-1082-telemetry-discriminator=25744. Every run exited 1 (stale merge-point-scoped locks — expected; the unit is the run, never its verdict).

### Arm: plugin-role-n2 (with aggregation-live on the same instances)

Two instances of the plugin role `shell-team:qa-verifier` (an `agents/qa-verifier.md`-derived agent; model `sonnet` — the orchestrator's own launch parameter, a declared label like the type itself; see the epistemic-status paragraph in the launch-refused arm) were launched as two parallel `Agent` tool calls inside one orchestrator message. *(Corrected 2026-08-19, review round 2: this sentence originally claimed the model was "recorded verbatim from the emitted span rows" — the fourth and, by mechanical signature enumeration, last site of the provenance-misstatement class; the span rows' `"model"` field is itself the orchestrator's own telemetry label, per `bin/log-run.sh`'s own header, which keeps `model` unvalidated and opaque deliberately.)* Population (2 real committed spec paths) and the launch record were written before the launch; the two epoch fields were appended at the moments they name.

The launch record the probe wrote, quoted verbatim from `<venue-clone>/.shell-team/runs/fanout-t1083live.launch` (the path resolved through `bin/team-paths.sh --get runs` inside the clone):

<!-- BEGIN launch-record: aggregation-live -->
launch-record 1
- population: /tmp/claude-502/t1083-probe-venue/work/pop-live.txt
- requested-n: 2
- achieved-n: 2
- cap-ground: measured-cores=8
- assign: qa-1 — .shell-team/specs/T-1044-test-infra-bundle.md
- assign: qa-2 — .shell-team/specs/T-1077-worktree-reconcile.md
- liveness: qa-1 — harness-tracked-background — bash <operator-home>/.claude-dotfiles/scripts/agent-watchdog.sh <qa-1-transcript(.output)> <venue-clone>
- liveness: qa-2 — harness-tracked-background — bash <operator-home>/.claude-dotfiles/scripts/agent-watchdog.sh <qa-2-transcript(.output)> <venue-clone>
- launched-epoch: 1787062345375523000
- completed-epoch: 1787062574009530000
launch-record-end
<!-- END launch-record: aggregation-live -->

Batch clocks: batch-start (orchestrator round preceding the launch message) = 1787062317320115000; launched-epoch (a Bash call placed after both Agent calls in the same message) = 1787062345375523000; completed-epoch (when the second completion notification was observed) = 1787062574009530000.

Instance self-timestamps (each instance ran `date +%s%N` itself, before and after its unit):

- agent-timestamp: plugin-role-n2 — qa-1 — first=1787062348069595000 — last=1787062539566586000 — unit `bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md`, exit 1, part written
- agent-timestamp: plugin-role-n2 — qa-2 — first=1787062355026208000 — last=1787062495411558000 — unit `bash bin/check-acs.sh .shell-team/specs/T-1077-worktree-reconcile.md`, exit 1, part written

Launch latencies derived from the rows above: qa-1 = 2.694 s, qa-2 = 9.651 s after launched-epoch. Intersection window [max(first), min(last)] = [1787062355026208000, 1787062495411558000] = 140.385 s of simultaneous execution. Batch wall clock (completed − launched) = 228.6 s against summed per-instance agent durations 202.6 s + 150.4 s = 353.0 s — the batch-vs-sum necessary condition for overlap holds.

Heartbeats: a harness-tracked background recorder sampled both instances' transcript sizes and unit-output file sizes every 15 s with a timestamp from the same clock. Twelve samples were taken; the eight below fall strictly inside the intersection window (the other four fell after qa-2's `last` and are retained in the raw recorder log; they are deliberately not written in this grammar). Each sample shows the per-instance unit-output files (`raw1`/`raw2` bytes) present and, across samples, growing while both `first=` stamps existed and neither `last=` did — the parent read the liveness signal before completion.

- heartbeat: plugin-role-n2 — 1787062389650454000 — raw1=6283 raw2=2496, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062404683966000 — raw1=6283 raw2=3555, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062419719237000 — raw1=6283 raw2=9348, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062434751784000 — raw1=6283 raw2=9348, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062449803287000 — raw1=7628 raw2=9348, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062464845332000 — raw1=7628 raw2=9348, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062479913322000 — raw1=7628 raw2=9348, both stamps first-only
- heartbeat: plugin-role-n2 — 1787062494945211000 — raw1=7628 raw2=13898, both stamps first-only

Per-instance liveness checks (the watchdogs named in the launch record) were started via harness-tracked background Bash immediately after the launch message and ran alongside both instances; both reached their lifetime end without a stall alert, after their instances had completed. One incidental confirming observation from the same session: a watchdog launch attempted with a bare shell `&` inside a foreground call failed immediately (`nice(5) failed: operation not permitted`, process never survived the call) — consistent with the bare-`&` death `docs/loop-engineering/harness-agent-concurrency.md` line 385 measured, which is why every liveness launch here used the harness-tracked path.

The probe's own telemetry, written by the orchestrator into the clone's runs file with `--instance` and `--seq auto` (quoted verbatim, two span rows):

```
{"loop_id":"shell-team","run_id":"t1083probe","seq":1,"ts":"2026-08-18T14:16:14Z","span":"qa-verifier","phase":"verify","iteration":1,"attempt":1,"status":"success","model":"sonnet","tokens":63751,"tool_uses":5,"duration_ms":202638,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"qa-1"}
{"loop_id":"shell-team","run_id":"t1083probe","seq":2,"ts":"2026-08-18T14:16:14Z","span":"qa-verifier","phase":"verify","iteration":1,"attempt":1,"status":"success","model":"sonnet","tokens":64892,"tool_uses":4,"duration_ms":150383,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"qa-2"}
```

Part files written by the instances themselves (quoted verbatim):

```
- unit: .shell-team/specs/T-1044-test-infra-bundle.md
- verdict: .shell-team/specs/T-1044-test-infra-bundle.md — rc=1; 10 passed, 4 failed, 1 skipped, 0 unrecognized
- unit: .shell-team/specs/T-1077-worktree-reconcile.md
- verdict: .shell-team/specs/T-1077-worktree-reconcile.md — rc=1; 8 passed, 6 failed, 0 skipped
```

The aggregation and attribution commands, run by the orchestrator against those real parts and that real telemetry:

- command: bash bin/aggregate-verdicts.sh --label t1083live --population $TMPDIR/t1083-probe-venue/work/pop-live.txt --part qa-1=$TMPDIR/t1083-probe-venue/work/part-qa-1.txt --part qa-2=$TMPDIR/t1083-probe-venue/work/part-qa-2.txt
- checker-result: aggregate-verdicts — exit=0 — the block below is its stdout, byte for byte
- command: bash bin/check-fanout-instances.sh --telemetry <venue-clone>/.shell-team/runs/shell-team.jsonl --run-id t1083probe --phase verify --aggregation $TMPDIR/t1083-probe-venue/work/agg-t1083live.txt --label t1083live
- checker-result: check-fanout-instances — exit=0 — stdout: `check-fanout-instances: ok: run-id=t1083probe phase=verify label=t1083live rows=2 parts=2`, stderr empty

The repository's first `fanout-verdict` block produced by real agents (quoted verbatim, the aggregator's stdout):

<!-- BEGIN fanout-verdict: t1083live -->
- aggregated-by: bin/aggregate-verdicts.sh
- locale: LC_ALL=C
- part: qa-1 — /tmp/claude-502/t1083-probe-venue/work/part-qa-1.txt
- part: qa-2 — /tmp/claude-502/t1083-probe-venue/work/part-qa-2.txt
<!-- BEGIN verdict-region: t1083live -->
- summary: units: 2 — verdicts: 2 — sentinels: 0
- verdict: .shell-team/specs/T-1044-test-infra-bundle.md — rc=1; 10 passed, 4 failed, 1 skipped, 0 unrecognized
- verdict: .shell-team/specs/T-1077-worktree-reconcile.md — rc=1; 8 passed, 6 failed, 0 skipped
<!-- END verdict-region: t1083live -->
- attribution: .shell-team/specs/T-1044-test-infra-bundle.md — qa-1
- attribution: .shell-team/specs/T-1077-worktree-reconcile.md — qa-2
<!-- END fanout-verdict: t1083live -->

### Arm: instance-death

Two setups; the first did not realize the arm's defining condition and is recorded here as an observation in its own right.

Setup 1 (did not fire): instance qa-2 was assigned the 156.4 s unit with no timeout guidance on its Bash call, on the expectation that the documented 120 s sub-agent foreground default (`harness-agent-concurrency.md` line 384) would truncate the run. It did not: the unit ran to completion inside the agent's turn (first=1787062681741338000, last=1787062873175536000, exit 1, part written). The truncation's absence was not further instrumented from outside; the most plausible mechanism is that the instance chose an explicit timeout parameter on its own initiative — an agent-autonomy boundary worth knowing about: **an implicit default is not a bound a probe may rely on; only an explicitly pinned parameter is.** (The companion instance of this setup, qa-1 on the 65.3 s unit with an explicit 300 s timeout, completed normally: first=1787062679943123000, last=1787062766230068000, exit 1, part written.)

Setup 2 (fired): instance qa-2 was relaunched with the Bash tool's timeout parameter pinned to exactly 120000 ms — the documented default made explicit — against the same 156.4 s unit, instructed to run it exactly once with that single call and to write its part only if the captured output carried a final `check-acs:` summary line. The call timed out at its 120 s bound; the captured output held 23 lines ending mid-run at the moment the instance read it (the still-in-flight AC13 sub-invocation, no summary line); the instance wrote **no part file** and ended its turn naturally (first=1787062948229188000, last=1787063101621341000). The harness reported the timed-out process as moved to background rather than killed; the instance neither waited on it nor retried, per its instructions, and the part file remained unwritten — which is the operational fact the aggregation reads. *(Full-evidence inventory note, 2026-08-19: the backgrounded orphan kept writing after the instance ended — the raw file later measures 31 lines and does eventually carry the `check-acs:` summary. This changes nothing the arm claims: the 23-line state is the snapshot the instance decided on, and no part file was ever written by anyone, which is what `bin/aggregate-verdicts.sh` refused on.)*

- command: bash bin/aggregate-verdicts.sh --label t1083death --population $TMPDIR/t1083-probe-venue/work/death/pop.txt --part qa-1=$TMPDIR/t1083-probe-venue/work/death/part-qa-1.txt --part qa-2=$TMPDIR/t1083-probe-venue/work/death/part-qa-2b.txt
- checker-result: aggregate-verdicts — exit=3 — stdout empty (0 bytes); stderr exactly one classified line: `aggregate-verdicts: missing-part: part 'qa-2' file not found: /tmp/claude-502/t1083-probe-venue/work/death/part-qa-2b.txt`
- phase-advanced: no — the fan-out's reduction refused with the incomplete-fan-out exit code; no authoritative verdict exists for this fan-out and nothing downstream of it was run
- termination: none — no TaskStop tool call and no process signal was used anywhere in this arm; the dead instance ended its own turn after its single bounded call timed out

### Arm: plugin-role-n4

Four instances of `shell-team:qa-verifier`, launched as four parallel `Agent` tool calls inside one orchestrator message, units T-1044/T-1077/T-1072/T-1074 (one per instance, population of 4 written before launch), N = min(4, 8) = 4 requested, 4 achieved. Epoch bounds for this launch: the pre-launch round's clock read 1787063147852758000 and the post-launch read 1787063170637685000; qa-1's own `first` (1787063166889477000) precedes the post-launch read, so the launch issuance is bounded by the pair rather than pointed at — disclosed rather than smoothed.

Instance self-timestamps (same grammar, this arm's own label):

- agent-timestamp: plugin-role-n4 — qa-1 — first=1787063166889477000 — last=1787063398101265000 — unit T-1044, exit 1
- agent-timestamp: plugin-role-n4 — qa-2 — first=1787063174568990000 — last=1787063354573439000 — unit T-1077, exit 1
- agent-timestamp: plugin-role-n4 — qa-3 — first=1787063177385099000 — last=1787063290605795000 — unit T-1072, exit 1
- agent-timestamp: plugin-role-n4 — qa-4 — first=1787063177712739000 — last=1787063278285424000 — unit T-1074, exit 1

Four-way intersection window [max(first), min(last)] = [1787063177712739000, 1787063278285424000] = 100.573 s during which all four instances were executing simultaneously. A background recorder took twelve 15 s samples of the four unit-output files; five samples fall strictly inside that four-way window (1787063204372581000, 1787063219454879000, 1787063234500642000, 1787063249570182000, 1787063264659825000), each showing all four output files present. Per-instance harness-tracked liveness checks ran alongside all four instances, as in the n2 arm. No aggregation was run and no `- checker-result:` line is recorded for this arm, per the frozen protocol.

### Arm: launch-refused

> **Amendment (2026-08-19, cross-provider review round 1, Blocker 1).** The original capture of this arm quoted the harness error's full `Available agents:` enumeration verbatim, which included the operator's own environment-specific tool names — a violation of this repository's public-repo hygiene rule, caught by the cross-provider review before any push (this branch had never left the local checkout). Under the frozen protocol's invalid-evidence rule (at most one re-probe), the arm was re-executed on 2026-08-19 and re-captured selectively below; the private enumeration is redacted by class, not transcribed. This is the same disposition T-1073's own redaction-only amendment took for its home-path defect.
>
> **Correction (2026-08-19, QA round 2).** The first version of this amendment wrote "all ten of this repository's shipped `shell-team:*` plugin roles" with a parenthetical that double-counted the triage orchestrator as if it sat outside `agents/*.md`. Both were wrong and neither was measured before writing: the enumeration carries exactly **nine** `shell-team:*` names, and `git ls-files -- 'agents/*.md' | wc -l` measures exactly **9** — the two sets coincide, triage-orchestrator included. (A naive `grep -c 'shell-team:'` over the whole quoted line measures 10 because the refused token `shell-team:nonexistent-probe-role` in the error's first sentence also matches; it is the launch argument, not an available role.) Corrected in place with this note; no probe execution was re-run for it and the one-re-probe budget is untouched.

One `Agent` tool call was issued with `subagent_type` set to the deliberately nonexistent plugin role `shell-team:nonexistent-probe-role` — first at approximately 1787063440000000000 (between the n4 completions and the cleanliness reads below), and again at 1787076324656839000 in the re-probe, with identical behavior both times. The harness refused the launch synchronously — no instance was created, no transcript file appeared — with an error of the shape:

```
Agent type 'shell-team:nonexistent-probe-role' not found. Available agents: <operator-environment entries, redacted>, shell-team:codex-reviewer, shell-team:drift-evaluator, shell-team:engineer, shell-team:pm-spec, shell-team:qa-verifier, shell-team:scrum-master, shell-team:tech-lead, shell-team:triage-orchestrator, shell-team:ui-designer, <operator-environment entries, redacted>
```

Two facts from that enumeration are evidentiary and are stated rather than left inside a redaction: **all nine of this repository's shipped `shell-team:*` plugin roles appeared in the available-agents enumeration** (the nine quoted above are exactly this repo's nine `agents/*.md`-derived roles — public, shipped names; measured, not counted by eye: `git ls-files -- 'agents/*.md' | wc -l` → 9), and **`shell-team:qa-verifier` specifically appeared**, the role every executed instance in this probe was launched as. A refusal of this class is synchronous and attributable; it never produces a half-launched instance. The same behavior additionally establishes that the harness **validates the `subagent_type` token at launch time**: a token that does not resolve never creates an instance, so any launch that proceeded did so with a token the harness resolved against its registry — the corroboration the epistemic-status paragraph below leans on.

**Epistemic status of the recorded `subagent_type` (added in the same amendment).** The `subagent_type=shell-team:qa-verifier` and `model=sonnet` values recorded for the positive arms are the orchestrator's own launch parameters, recorded verbatim as **declared labels** — the same epistemic footing as T-1073's own `subagent_type=general-purpose, model=haiku` records, and the same declared-not-observed doctrine every T-1058 telemetry binding field carries ("the resolved binding as declared, never an independently verified observation"). The harness exposes no committable artifact of the resolved type for a successful launch; the span rows' `"span"` field and the launch record's `- assign:` ids are attribution labels the orchestrator itself supplies, and are deliberately not cited as type evidence. What narrows the gap is the launch-refused arm's measured behavior above: the token is validated synchronously at launch, so the surviving self-reported link is only that the orchestrator's calls carried the token they are recorded as carrying — the same self-attestation trust boundary this repository's freeze-attestations and provenance records already sit on.

### Post-arm cleanliness reads (real checkout)

Read in the real checkout at 1787063497808615000, after every arm had finished:

- probe-writes: none — `git status --short` produced no output and `git ls-files --others --exclude-standard` produced no output in the real checkout; every telemetry write went to `<venue-clone>/.shell-team/runs/` via `TEAM_RUNS_DIR`, and every working file sat under `$TMPDIR/t1083-probe-venue/work/`

### Orchestrator conditions for the record (AC22 items h and i)

- clock: `date +%s%N`, expansion verified (above); every timing figure in this note is machine-local and single-session and carries no git ref.
- cores: 8 (measured); cap ground `measured-cores=8`; `TEAM_FANOUT_MAX` unset.
- resolved agent identity: `subagent_type=shell-team:qa-verifier`, model `sonnet` — the orchestrator's own launch parameters, recorded as **declared labels**; the span rows' `"span"`/`"model"` fields are the orchestrator's own telemetry labels and are not harness evidence of the resolved type (see the epistemic-status paragraph in the launch-refused arm). Applies to every instance in the four arms that created instances; the launch-refused arm created none. *(Corrected 2026-08-19, QA round 3: this line originally claimed the values were "verbatim from the emitted span rows" and covered "every instance in every arm" — the same provenance-misstatement class review round 1's Blocker 2 removed at the analysis layer, surviving here at a third site until the full-evidence claim inventory below swept it.)*
- per-call foreground-Bash timeouts passed to instances: 300000 ms explicit on every unit call except instance-death setup 1's qa-2 (no guidance, completed anyway) and setup 2's qa-2 (120000 ms explicit, the pinned default, which fired).
- `TEAM_RUNS_DIR` pointed inside the throwaway clone for every telemetry write; the real checkout's own runs corpus received none of the probe's rows.
## Terms and closed vocabularies

Restated from `.shell-team/specs/T-1083-agent-launch-fanout.md`'s frozen
`<!-- BEGIN probe-protocol: T-1083 -->` … `<!-- END probe-protocol: T-1083 -->`
region — a faithful restatement for a reader who has not opened the spec, never a
re-derivation of the protocol's own design choices.

- Verdict (closed, exactly one recorded in `## Verdict and licence conditions` below), borrowed verbatim from T-1073's own frozen vocabulary, no new token: `concurrent-overlapping` / `serialized` / `queued-partial` (carries a measured cap `k`) / `launch-refused` / `undetermined`.
- Licence conditions (closed, seven — one more than T-1073's six, `plugin-role-subagent-type` added because this task's own boundary is the agent type, not merely overlap), each recorded `met` or `not-met` with its own evidence: `plugin-role-subagent-type`, `production-unit`, `real-population`, `same-machine-session`, `clock-source-monotonic`, `overlap-margin-exceeds-launch-latency`, `aggregation-end-to-end`. Any condition reading `not-met` confines the verdict to `undetermined` or `launch-refused`.
- Arm ids (closed, five, with a fixed drop order): `plugin-role-n2` (never dropped), `aggregation-live` (never dropped), `instance-death` (never dropped), `plugin-role-n4` (droppable second), `launch-refused` (droppable first).
- Evidence channels (closed, three, borrowed verbatim from T-1073 rather than re-coined, each with a fixed evidentiary role):
  - channel: agent-self-timestamps — primary — each instance's own first and last timestamp, the only channel measured from inside the agents.
  - channel: batch-vs-sum — necessary-condition — the orchestrator's batch wall clock against the summed per-instance durations; necessary for overlap, never sufficient alone.
  - channel: orchestrator-span-rows — secondary-attribution — span rows carrying `--instance <role-qualified-id>` and `--seq auto`, emitted by the orchestrator, never self-emitted by an instance; in this task additionally the input `bin/check-fanout-instances.sh` reads.
- Launch-record grammar (closed, frozen before the probe ran — see `## Probe evidence` above for the field-by-field definition): `launch-record 1` / `- population:` / `- requested-n:` / `- achieved-n:` / `- cap-ground:` / `- assign:` / `- liveness:` / `- launched-epoch:` / `- completed-epoch:` / `launch-record-end`.

## Probe protocol (frozen before execution)

Restated from the same frozen region, for a reader who has not opened the spec.

**Venue.** A throwaway `git clone --no-hardlinks` under `$TMPDIR`, checked out to the branch point, is the only tree any probe agent touches — `git worktree add` is never used for this venue, since a worktree registers under `.git/worktrees` in the real checkout and turns cleanup into a destructive step this task takes no version of. Telemetry is written into that clone with `TEAM_RUNS_DIR` pointed inside it. No probe agent writes to the real checkout, verified rather than promised (`## Probe evidence`, "Post-arm cleanliness reads").

**Unit and population.** The production unit is `bash bin/check-acs.sh <spec>` over real committed specs in the pinned clone. The population is written to a population file before any instance is launched and never re-selected after a verdict is seen; per-spec costs are measured singly before any arm runs so the fan-out's own unit durations sit above the measured launch latency by a declared margin factor of at least 3 and below the liveness check's stall threshold. The unit is the run, never its verdict — a non-zero `unit_rc` from a stale merge-point-scoped lock is expected.

**Clock source.** The probe records which clock it read and verifies it before relying on it: a source whose nanosecond field does not expand (BSD `date`'s literal `N`) is `unusable` and is substituted. Every timestamp is an integer of digits only.

**The launch record — grammar, frozen.** One file per fan-out at `<runs>/fanout-<label>.launch`, `<runs>` resolved via `bin/team-paths.sh --get runs`, `<label>` the same `--label` value passed to both shipped checkers. Written before any instance is launched, except the two epoch fields. The field-by-field grammar is quoted verbatim in `## Probe evidence` above (the `aggregation-live` arm's own launch record) and defined identically in `templates/prompt-blocks/fanout-orchestration.md` and its `skills/run/SKILL.md` mirror (**AC1**–**AC3**). Four fields are `audit-only` (`- liveness:`, `- launched-epoch:`, `- completed-epoch:`, `- cap-ground:`) because every gated field is already an argument to a shipped fail-closed checker — no third checker is built.

**Arms.** Five, with a closed id vocabulary and a fixed drop order: `plugin-role-n2` (two instances of one `agents/*.md`-derived plugin role, never dropped), `aggregation-live` (the same instances' real part files reduced and verified, never dropped, the only end-to-end evidence precondition 3 has ever had), `instance-death` (one instance genuinely writes no or a partial part, aggregation refused with exit 3, no `TaskStop`, no `kill`, never dropped), `plugin-role-n4` (the same launch-and-overlap shape at `N = min(<unit count>, cap)`, no aggregation, droppable second), `launch-refused` (an induced genuine launch refusal, droppable first).

**Liveness, never dropped.** A per-instance liveness check runs alongside each instance, started at launch, through a harness-tracked background launch and never a bare shell `&`. The evidence carries at least two heartbeat samples timestamped inside the window in which that arm's instances were still running, each watchdog's launch command verbatim, and its final disposition — satisfying, for this arm's shape, the structurally-correct-watchdog requirement recorded in issue #274's body, cited as prior art since that issue is closed.

**Verdict.** Exactly one, from T-1073's frozen five-value vocabulary, under seven licence conditions, each `met`/`not-met` with its own evidence. Any condition reading `not-met` confines the verdict to `undetermined` or `launch-refused`.

- probe-arm: plugin-role-n2 — executed — two instances of `shell-team:qa-verifier` launched as parallel `Agent` tool calls inside one orchestrator message; a real two-instance overlap measured (margin 140.385 s against a maximum single launch latency of 9.651 s, ≈14.5×); never dropped, per the pre-commitment.
- probe-arm: aggregation-live — executed — the plugin-role-n2 instances' real part files reduced by `bin/aggregate-verdicts.sh` (exit 0) and verified by `bin/check-fanout-instances.sh` (exit 0) against the probe's own real telemetry under label `t1083live`; never dropped, the only end-to-end evidence precondition 3 has ever had.
- probe-arm: instance-death — executed — its defining condition (a genuine part-write failure refused with exit 3, `missing-part`) fired on setup 2, after setup 1 did not realize it (the unit ran to completion inside the agent's turn with no explicit timeout, disclosed as an agent-autonomy finding in `## Limits` below rather than smoothed over); never dropped.
- probe-arm: plugin-role-n4 — executed — four instances of `shell-team:qa-verifier` launched together inside one orchestrator message; a genuine four-way overlap window of 100.573 s measured; no aggregation and no `- checker-result:` line of its own, per the frozen protocol; droppable second, not dropped this round.
- probe-arm: launch-refused — executed — an `Agent` tool call against the deliberately nonexistent plugin role `shell-team:nonexistent-probe-role` was refused synchronously by the harness, with the verbatim error quoted in `## Probe evidence` above; droppable first, not dropped this round.

## Launch record and aggregation analysis

Every number below is re-derived from `## Probe evidence` above by bash integer
arithmetic (`$(( 10#$v ))` throughout — never `awk`/`sort -n`, since a 19-digit
epoch-nanosecond value exceeds a double's exact-integer range); each carries a
`- reproduce:` line that recomputes it from the raw digits quoted there.

**`plugin-role-n2` overlap** (channel ①, `agent-self-timestamps`, primary — `max(first)`=1787062355026208000 (`qa-2`), `min(last)`=1787062495411558000 (`qa-2`)):

- overlap: plugin-role-n2 — overlapping — margin_ns=140385350000 — ≈140.385 s of genuine two-instance simultaneous execution.
  - reproduce: `f1=1787062348069595000; f2=1787062355026208000; l1=1787062539566586000; l2=1787062495411558000; maxf=$(( 10#$f1 > 10#$f2 ? 10#$f1 : 10#$f2 )); minl=$(( 10#$l1 < 10#$l2 ? 10#$l1 : 10#$l2 )); echo $(( minl - maxf ))` → `140385350000`

**Launch latencies** (`first` minus `launched-epoch=1787062345375523000`):

- qa-1: `echo $(( 10#1787062348069595000 - 10#1787062345375523000 ))` → `2694072000` (≈2.694 s)
- qa-2: `echo $(( 10#1787062355026208000 - 10#1787062345375523000 ))` → `9650685000` (≈9.651 s)
- The overlap margin (≈140.385 s) exceeds the maximum single launch latency (≈9.651 s) by ≈14.5×, comfortably above the frozen margin-factor floor of 3.
  - reproduce: `margin=140385350000; ll=9650685000; awk -v m="$margin" -v l="$ll" 'BEGIN{printf "%.2f\n", m/l}'` → `14.55`

**Batch-vs-sum** (channel ②, necessary-condition — `batch_ns` = `completed-epoch − launched-epoch`; `sum_ns` = the two instances' own `duration_ms` from the span rows quoted in `## Probe evidence` above):

- batch-vs-sum: plugin-role-n2 — batch_ns=228634007000 — sum_ns=353021000000 — batch ≈228.6 s vs a serial sum of ≈353.0 s (batch ≈65% of sum, consistent with two instances running concurrently for most of the window).
  - reproduce: `echo $(( 10#1787062574009530000 - 10#1787062345375523000 ))` → `228634007000` (batch); `echo $(( 202638 + 150383 ))` → `353021` ms = `353021000000` ns (sum)

**`plugin-role-n4` overlap** (four-way, `max(first)`=1787063177712739000 (`qa-4`), `min(last)`=1787063278285424000 (`qa-4`)):

- overlap: plugin-role-n4 — overlapping — margin_ns=100572685000 — ≈100.573 s during which all four instances were simultaneously executing (a genuine four-way overlap, not merely pairwise ones); this arm ran no aggregation, per the frozen protocol, so it contributes no `overlap-margin-exceeds-launch-latency` evidence of its own — that condition is licensed by `plugin-role-n2` above.
  - reproduce: `f1=1787063166889477000; f2=1787063174568990000; f3=1787063177385099000; f4=1787063177712739000; l1=1787063398101265000; l2=1787063354573439000; l3=1787063290605795000; l4=1787063278285424000; maxf=$(( 10#$f1 )); for v in $f2 $f3 $f4; do vv=$(( 10#$v )); [ "$vv" -gt "$maxf" ] && maxf=$vv; done; minl=$(( 10#$l1 )); for v in $l2 $l3 $l4; do vv=$(( 10#$v )); [ "$vv" -lt "$minl" ] && minl=$vv; done; echo $(( minl - maxf ))` → `100572685000`

**Aggregation and attribution, end to end.** The `aggregation-live` arm's launch record (quoted in `## Probe evidence` above, region `<!-- BEGIN launch-record: aggregation-live -->` … `<!-- END launch-record: aggregation-live -->`) carries two `- assign:` lines whose instance-id set is `{qa-1, qa-2}`; the `<!-- BEGIN fanout-verdict: t1083live -->` block quoted in the same section carries two `- part:` lines whose name set is also `{qa-1, qa-2}` — the two sets are equal in both directions, which is the whole no-new-checker argument made measurable: the record's assignments are the aggregator's own arguments, so the identity a third checker would otherwise have been built to assert already holds by construction (**AC14**). Both shipped checkers exited 0 against the probe's own real telemetry and real part files (`## Probe evidence`, "The aggregation and attribution commands").

## Verdict and licence conditions

- verdict: concurrent-overlapping — every licence condition below reads `met`; the plugin-role-n2 arm shows a genuine, large, positive overlap margin (≈140.385 s) exceeding the maximum single launch latency (≈9.651 s) by ≈14.5×, the batch-vs-sum necessary condition agrees (batch ≈228.6 s far below the summed ≈353.0 s), the plugin-role-n4 arm independently reproduces a four-way overlap (≈100.573 s) at a different agent type from T-1073's own general-purpose result, and the aggregation-live arm ran the full shipped fail-closed pair end to end against real telemetry and real part files. This is the repository's first empirical crossing of T-1073's own declared `unobserved` plugin-role boundary.
- licence-condition: plugin-role-subagent-type — met — `## Agent-type boundary` below records `subagent_type=shell-team:qa-verifier` as the orchestrator's own **declared label** for every instance in the arms that created one (`plugin-role-n2`, `plugin-role-n4`), not as an independently harness-observed resolved type. The `launch-refused` arm's verbatim error body (`## Probe evidence` above) corroborates rather than proves it: an unresolvable token is refused synchronously before any instance ever exists, and `shell-team:qa-verifier` itself appears in the harness's own available-agents enumeration — which is what licenses treating a launch that did proceed as one the harness resolved against its registry, since an unresolvable token never reaches that point. The surviving self-reported link is narrower than that inference: only that these calls carried the token they are recorded as carrying, the same self-attestation boundary this repository's freeze-attestations and provenance records already sit on. Met as a declared, harness-corroborated-but-not-independently-observed label; had `general-purpose` been declared instead for these same calls, nothing recorded in this note's evidence would contradict it.
- licence-condition: production-unit — met — the unit is literally `bash bin/check-acs.sh <spec>`, this repository's own acceptance-criteria gate (`## Probe evidence`, "Execution conditions" — per-spec unit costs), unchanged from T-1073's own choice.
- licence-condition: real-population — met — the population is real, committed spec paths at the pinned branch point (T-1044, T-1077, T-1072, T-1074, and others measured singly before any arm ran), never a synthetic fixture.
- licence-condition: same-machine-session — met — every arm, every instance and the orchestrator's own heartbeats and span rows ran on this task's one operator machine, in one continuous session (clock reads span from 1787061684842511000 to 1787063497808615000, ≈30 minutes), inside the same throwaway clone.
- licence-condition: clock-source-monotonic — met — `date +%s%N` was verified to expand (19-digit integers, no literal `N`) before reliance, cross-checked against a `python3 time.time_ns()` read agreeing within 150 ms, and every recorded `last` exceeds its own `first` with no negative delta anywhere in the `agent-timestamp` lines quoted in `## Probe evidence` above.
- licence-condition: overlap-margin-exceeds-launch-latency — met — the plugin-role-n2 margin (≈140.385 s) exceeds the maximum single launch latency (≈9.651 s) by ≈14.5×, independently exceeding the frozen margin-factor floor of 3.
- licence-condition: aggregation-end-to-end — met — `bin/aggregate-verdicts.sh` and `bin/check-fanout-instances.sh` both exited 0 against the probe's own real telemetry and real part files (`## Probe evidence`, checker-result lines), and the `- assign:`/`- part:` instance-id sets agree in both directions (`## Launch record and aggregation analysis` above).

No licence condition above reads `not-met`, which is the coupling this verdict requires: under the closed vocabulary, `concurrent-overlapping` may not carry a `not-met` condition, and none does.

## Implications for T-1084 and T-1085

- implication: concurrent-overlapping — T-1073's own declared `unobserved` plugin-role boundary (`harness-agent-concurrency.md:373`–`374`/`390`) is closed: this task's `plugin-role-n2` and `plugin-role-n4` arms measured genuine, large, positive overlap margins for `subagent_type=shell-team:qa-verifier`, and the `aggregation-live` arm ran the shipped fail-closed pair end to end against real telemetry. T-1084 may dispatch plugin-role instances concurrently; the remaining named gates are the dispatcher's own scheduling design (T-1084) and default-path firing (T-1085).
- implication: serialized — NOT MET this round (the measured verdict is `concurrent-overlapping`, above). Had this been the recorded verdict instead, the boundary would have closed negatively: T-1084 would be redesigned around serial plugin-role execution or around general-purpose worker agents driving plugin-role work, and T-1085's default-path firing would wait.
- implication: queued-partial — NOT MET this round. Had this been the recorded verdict, T-1084's degree rule would be capped at the measured `k` this note would then state on its own `- measured-k:` line (no such line exists this round, since the recorded verdict is `concurrent-overlapping`).
- implication: launch-refused — NOT MET as the recorded **verdict** (the recorded verdict is `concurrent-overlapping`, above) — distinct from the fact that the `launch-refused` **arm** did run and did induce a genuine synchronous refusal (`## Probe evidence`, "Arm: launch-refused"); an arm executing and a verdict being licensed are different facts, and only the latter is what this line reports. Had the verdict itself been `launch-refused`, plugin-role fan-out would not be available in this harness at all, and both T-1084 and T-1085 would be re-planned.
- implication: undetermined — NOT MET this round. Had this been the recorded verdict, nothing would be licensed, and this note would state what would settle it (a re-probe correcting whichever licence condition read `not-met`).
- umbrella: 277 — open — this task delivers precondition 3's launch-record half (`## Probe protocol` and `templates/prompt-blocks/fanout-orchestration.md`'s launch-record grammar); the live-firing half remains owed to T-1085, and precondition 2 is not re-litigated (T-1073 already discharged it for general-purpose agents; this task extends its boundary rather than re-deciding it).
- prior-art: 274 — closed — closed `completed` on 2026-08-17 at the engineer-parallel sprint's batch close-out (its seven contract surfaces shipped in T-1080), measured live rather than assumed; cited here only for the structurally-correct-watchdog requirement its body recorded, which this task's liveness evidence (two per-instance `- liveness:` lines, eight heartbeat samples inside the `plugin-role-n2` intersection window, `## Probe evidence` above) satisfies for this arm's shape. Nothing here reopens, re-files, or records it as an outstanding obligation.

## Agent-type boundary

- agent-type: plugin-role-n2 — subagent_type=shell-team:qa-verifier — model=sonnet — a **declared label**: the orchestrator's own launch parameter, recorded as passed, for every instance in the arms that actually created an instance (`plugin-role-n2`, `plugin-role-n4`; `launch-refused` created no instance at all and is excluded from that count — `## Probe evidence` above, "Arm: launch-refused"). This is not harness-originated evidence of the *resolved* type: the span rows' `"span"` field and the launch record's `- assign:` ids quoted in `## Probe evidence` above are the orchestrator's own attribution labels, and are deliberately not cited here as type evidence — the citable ground for this line is the epistemic-status paragraph added to `## Probe evidence` above ("Arm: launch-refused"). What that paragraph grounds the claim in is a harness-originated artifact that genuinely exists — the `launch-refused` arm's verbatim error body — which shows (a) a token the harness cannot resolve is refused synchronously with no instance ever created, and (b) `shell-team:qa-verifier` itself appeared in the harness's own available-agents enumeration. That artifact is not itself tied to the positive arms (`plugin-role-n2`/`plugin-role-n4`); what it licenses is the narrower inference that a launch which *did* proceed carried a token the harness had resolved against its registry, since an unresolvable one is refused before any instance exists. The surviving self-reported link stops there: only that the orchestrator's calls are recorded as having carried the token named here — the same self-attestation boundary this repository's freeze-attestations and provenance records already sit on. **Counterfactual, stated rather than left implicit**: had the orchestrator instead declared `subagent_type=general-purpose` for these same calls, nothing in this note's recorded evidence would contradict it; the claim that the plugin-role boundary was actually crossed rests on that same self-attestation boundary, not on an independent harness confirmation of the resolved type. T-1058's declared-not-observed doctrine and T-1073's own recording of `subagent_type=general-purpose` are cited here only as grounds for treating this value as a declared label and for the recording practice itself — never as evidence that the declaration is true. The role derives from `agents/qa-verifier.md` (`tools: Read, Grep, Glob, Bash`, `model: sonnet`) — the one role among this repository's nine `agents/*.md` definitions that can run `bash bin/check-acs.sh`, which is why it was launched rather than a role picked for convenience.
- unobserved: whether this result generalizes to a different plugin role, a different model, a different harness version or a different machine — recorded as a stated gap in `## Limits` below, never inferred past.
- claim-under-test: T-1073's own declared `unobserved` boundary — "whether general-purpose Agent-tool concurrency extends to a plugin-role subagent type" (`harness-agent-concurrency.md:374`) — under-test-not-evidence.

## Supersession and follow-ups

- supersedes: `docs/loop-engineering/harness-agent-concurrency.md`'s `## Agent-type boundary` `- unobserved:` line (lines 373–374 and 390) — that line disclosed, as a stated gap rather than an inference, that whether general-purpose Agent-tool concurrency extends to a plugin-role subagent type was `unobserved`; this task's `plugin-role-n2`/`plugin-role-n4` measurements are the empirical confirmation that boundary disclosed as missing.
- follow-up: when `docs/loop-engineering/harness-agent-concurrency.md` is next touched by a maintainer round, edit its `## Agent-type boundary` `- unobserved:` line to point at this note's `concurrent-overlapping` verdict instead of restating the gap — out of this task's own scope (`## Non-goals`: `docs/loop-engineering/harness-agent-concurrency.md` stays byte-identical here; the supersession is declared, not performed).
- follow-up: issue #277's remaining live-firing half (default-path firing) is T-1085's; issue #274's citation here is prior-art only and owes no further edit from this task.

## Limits and what is not computable

- Machine-local, single-host, single-session: every timing figure in this note (launch latencies, overlap margins, batch/sum durations) is a property of this one operator machine at 8 logical CPUs (`getconf _NPROCESSORS_ONLN`), on 2026-08-18, and carries no git-ref label — a ref does not determine a machine-local timing.
- Agent population: every probe instance this round was `subagent_type=shell-team:qa-verifier`, `model=sonnet`; whether the result generalizes to a different plugin role, a different model, or a different machine is `unobserved` (`## Agent-type boundary` above), not inferred.
- No second repetition of `plugin-role-n2` and no `repetition-variance` licence condition, per the frozen Non-goals: T-1073 already disclosed the n=2 spread for this harness (≈3.8%); this task's question is a boundary question — does a plugin-role subagent type launch concurrently at all — not a timing-precision question, and one execution with a margin (≈140.385 s) exceeding the measured launch latency (≈9.651 s) by ≈14.5× answers it.
- No inferential-statistics claim anywhere in this note: no significance test, no confidence interval, no variance model, no regression, and no dollar-cost, vendor-price or token-multiplier estimate.
- **`instance-death`'s agent-autonomy observation, disclosed rather than smoothed over.** Setup 1 of the `instance-death` arm expected the documented 120 s sub-agent foreground-Bash default to truncate a 156.4 s unit run with no explicit timeout parameter; it did not — the unit ran to completion inside the agent's own turn (`## Probe evidence`, "Arm: instance-death"). The most plausible mechanism, not further instrumented from outside, is that the instance chose an explicit timeout on its own initiative. The lesson this note draws: **an implicit default is not a bound a probe (or any future fan-out orchestration) may rely on; only an explicitly pinned parameter is** — which is exactly what setup 2 then did (an explicit 120000 ms timeout), and which is exactly what fired the genuine `missing-part` refusal this arm exists to produce.
- Model, harness-version and machine generalization: unobserved, exactly as T-1073 recorded its own — nothing here claims this result holds on a different model, a different harness version, or a different machine.
