# Agent launch fan-out — the plugin-role concurrency probe and the launch record's first live run (T-1083)

## Probe evidence (raw, orchestrator-produced)

Produced by the coordinating session (the orchestrator) on 2026-08-18, before the engineer was invoked, per the frozen probe protocol in `.shell-team/specs/T-1083-agent-launch-fanout.md` (intent v1 `02b43df902d1a0f06c7a2bb353098c0ddceaa7dc`). Everything in this section is a raw observation; analysis lives in the other sections, which were assembled later from this section without altering a byte of it. Every filesystem path below is `$TMPDIR`-relative or a `<placeholder>`; no home-directory absolute path appears anywhere in this evidence.

### Execution conditions

- clock source: `date +%s%N`, verified expanding on this host before any arm ran — sample value `1787061684842511000`, 19 digits, no literal `N` (the BSD non-expansion case did not occur; a python3 `time.time_ns()` cross-read taken in the same second agreed to within 150 ms). All timestamps below are epoch nanoseconds from this one source, single machine, single session.
- logical cores: `getconf _NPROCESSORS_ONLN` = 8. `TEAM_FANOUT_MAX` unset, so the degree rule's cap ground is `measured-cores=8`.
- venue: a throwaway `git clone --no-hardlinks` of the repository under `$TMPDIR/t1083-probe-venue/clone`, checked out detached at the branch point `01ef1108836839120217accfd8a56be4ed2ae008` (verified by `git rev-parse HEAD` in the clone). `git worktree add` was never used. All probe telemetry was written with `TEAM_RUNS_DIR` pointed inside the clone.
- per-spec unit costs, measured singly (serially) in the clone before any arm ran, `CHECK_ACS_TIMEOUT=300`, wall-clock ms: T-1044-test-infra-bundle=156440; T-1077-worktree-reconcile=112703; T-1072-telemetry-span-discriminator=65337; T-1074-fanout-orchestration=44724; T-1048-handoff-durability-barrier=12389; T-1046-ignored-base-verdict=16511; T-1069-phase-multiplexing=4708; T-1080-depth-axis-contract=7612; T-1081-freeze-sweep-hardening=1176; T-1082-telemetry-discriminator=25744. Every run exited 1 (stale merge-point-scoped locks — expected; the unit is the run, never its verdict).

### Arm: plugin-role-n2 (with aggregation-live on the same instances)

Two instances of the plugin role `shell-team:qa-verifier` (an `agents/qa-verifier.md`-derived agent; resolved model recorded verbatim from the emitted span rows below: `sonnet`) were launched as two parallel `Agent` tool calls inside one orchestrator message. Population (2 real committed spec paths) and the launch record were written before the launch; the two epoch fields were appended at the moments they name.

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

Setup 2 (fired): instance qa-2 was relaunched with the Bash tool's timeout parameter pinned to exactly 120000 ms — the documented default made explicit — against the same 156.4 s unit, instructed to run it exactly once with that single call and to write its part only if the captured output carried a final `check-acs:` summary line. The call timed out at its 120 s bound; the captured output held 23 lines ending mid-run (the still-in-flight AC13 sub-invocation, no summary line); the instance wrote **no part file** and ended its turn naturally (first=1787062948229188000, last=1787063101621341000). The harness reported the timed-out process as moved to background rather than killed; the instance neither waited on it nor retried, per its instructions, and the part file remained unwritten — which is the operational fact the aggregation reads.

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

One `Agent` tool call was issued with `subagent_type` set to the deliberately nonexistent plugin role `shell-team:nonexistent-probe-role`, at approximately 1787063440000000000 (between the n4 completions and the cleanliness reads below). The harness refused the launch synchronously — no instance was created, no transcript file appeared — with the verbatim error:

```
Agent type 'shell-team:nonexistent-probe-role' not found. Available agents: artifact-builder, claude, claude-code-guide, codex:codex-rescue, deck-builder, design-system-apply, dotfiles-sync, Explore, general-purpose, pdf-builder, Plan, shell-team:codex-reviewer, shell-team:drift-evaluator, shell-team:engineer, shell-team:pm-spec, shell-team:qa-verifier, shell-team:scrum-master, shell-team:tech-lead, shell-team:triage-orchestrator, shell-team:ui-designer, skill-inventory, sonnet-engineer, statusline-setup
```

A refusal of this class is synchronous and attributable; it never produces a half-launched instance.

### Post-arm cleanliness reads (real checkout)

Read in the real checkout at 1787063497808615000, after every arm had finished:

- probe-writes: none — `git status --short` produced no output and `git ls-files --others --exclude-standard` produced no output in the real checkout; every telemetry write went to `<venue-clone>/.shell-team/runs/` via `TEAM_RUNS_DIR`, and every working file sat under `$TMPDIR/t1083-probe-venue/work/`

### Orchestrator conditions for the record (AC22 items h and i)

- clock: `date +%s%N`, expansion verified (above); every timing figure in this note is machine-local and single-session and carries no git ref.
- cores: 8 (measured); cap ground `measured-cores=8`; `TEAM_FANOUT_MAX` unset.
- resolved agent identity: `subagent_type=shell-team:qa-verifier`, model `sonnet` (verbatim from the emitted span rows), for every instance in every arm.
- per-call foreground-Bash timeouts passed to instances: 300000 ms explicit on every unit call except instance-death setup 1's qa-2 (no guidance, completed anyway) and setup 2's qa-2 (120000 ms explicit, the pinned default, which fired).
- `TEAM_RUNS_DIR` pointed inside the throwaway clone for every telemetry write; the real checkout's own runs corpus received none of the probe's rows.
