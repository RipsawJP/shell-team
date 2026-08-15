# Harness Agent-tool concurrency — the T-1073 probe

This note is assembled in two stages by two different actors, per the frozen spec
(`.shell-team/specs/T-1073-harness-agent-concurrency.md`): the section
`## Probe evidence (raw, orchestrator-produced)` below was written and committed by the
orchestrator session that executed the probe, before the engineer was invoked, and is
byte-frozen from that commit onward; every other section is the engineer's assembly
from this evidence.

## Probe evidence (raw, orchestrator-produced)

This section supersedes the first probe's evidence (retained below under
"Superseded first probe"), under the frozen invalid-evidence rule: re-probe 1 of a
maximum of 1, invoked because the first evidence did not follow this section's own
`- command:` line grammar (AC4) and the first probe ran two watchdog thresholds where
the frozen single-threshold ordering admits one (AC8). All timestamps are machine-local
`time.time_ns()` integers (nanoseconds since epoch); no timing figure is a property of
any git ref. Logical CPU count via `os.cpu_count()`: 8 (`sysctl` is denied in this
sandbox). Re-probe date: 2026-08-15.

### Clock-source verification (re-probe)

- `python3 -c 'import time; print(time.time_ns())'` expanded (19-digit integers throughout) — the probe's sole clock source (`clock_source=python3-time_ns` on every agent line). The orchestrator's PATH `date +%s%N` also expands (GNU date on PATH); the BSD literal-`N` hazard did not occur and the python source was used regardless.

### Commands (verbatim, the executable core of the protocol as run)

- command: git clone --no-hardlinks /Users/sawamatsu/workspace/_my-repos/shell-team "$TMPDIR/t1073-probe-clone" && git -C "$TMPDIR/t1073-probe-clone" checkout f8371eb6a26b395c020ee7811087150059d33c15
- command: cd "$TMPDIR/t1073-probe-clone" && CHECK_ACS_TIMEOUT=280 bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md > /dev/null 2>&1; echo "unit_rc=$?"
- command: bash ~/.claude-dotfiles/scripts/agent-watchdog.sh <that-agent's-transcript.output> "" 5 20 5
- command: bash ~/.claude-dotfiles/scripts/agent-watchdog.sh <probe-stall-transcript.output> "" 5 15 5

The single stall threshold across every arm, healthy and control alike, is 5 minutes
(300000 ms): the frozen ordering holds as control-sleep(360000) > stall-threshold(300000)
> unit-duration(147968), all in ms.

### Venue and population (unchanged from the first probe, fixation predates every arm)

- Venue: the pinned throwaway clone above; pinned HEAD verified `f8371eb6a26b395c020ee7811087150059d33c15` (= the branch point). No `git worktree add` anywhere; probe agents write nothing to the real checkout (verified after every arm — see cleanliness below).
- Unit: `check-acs` over `T-1044-test-infra-bundle.md`, serial cost 147968 ms measured at population-fixation time (candidates and their timings: T-1041 20382 ms, T-1019 3705 ms, T-1056 29239 ms, T-1044 147968 ms — all rc=1, expected: stale merge-point-scoped locks at the branch point; the unit is the run, not its verdict).

### Arms — verbatim agent report lines (re-probe)

Launch mechanics per multi-agent arm: parallel `Agent` tool calls inside ONE
orchestrator message (`subagent_type=general-purpose`, `model=haiku`); each agent
instructed to run the unit as one foreground Bash call with an explicit 400000 ms
timeout parameter (the 120 s default would auto-background it — a finding from the
first probe). The harness-documentation sentence about concurrent tool uses remains
the claim under test, never evidence.

`serial-baseline-n1` (t0 = 1786788966453417000 / 2026-08-15T10:16:06Z; t_launched = 1786788985406447000):

```
instance=probe-a arm=serial-baseline-n1 start_ns=1786788982707981000 end_ns=1786789140921454000 start_iso=2026-08-15T10:16:25Z end_iso=2026-08-15T10:19:02Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`pair-n2-rep1` (t0 = 1786789155293702000 / 2026-08-15T10:19:15Z; t_launched = 1786789178839240000):

```
instance=probe-a arm=pair-n2-rep1 start_ns=1786789170595146000 end_ns=1786789355493665000 start_iso=2026-08-15T10:19:32Z end_iso=2026-08-15T10:22:36Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=pair-n2-rep1 start_ns=1786789176892811000 end_ns=1786789361480495000 start_iso=2026-08-15T10:19:39Z end_iso=2026-08-15T10:22:43Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`pair-n2-rep2` (t0 = 1786789382186044000 / 2026-08-15T10:23:02Z; t_launched = 1786789405857317000):

```
instance=probe-a arm=pair-n2-rep2 start_ns=1786789398074991000 end_ns=1786789575098697000 start_iso=2026-08-15T10:23:18Z end_iso=2026-08-15T10:26:15Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=pair-n2-rep2 start_ns=1786789403084491000 end_ns=1786789580923408000 start_iso=2026-08-15T10:23:25Z end_iso=2026-08-15T10:26:22Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`width-n4` (t0 = 1786789601143196000 / 2026-08-15T10:26:41Z; t_launched = 1786789637356480000):

```
instance=probe-a arm=width-n4 start_ns=1786789618598830000 end_ns=1786789904004940000 start_iso=2026-08-15T10:27:00Z end_iso=2026-08-15T10:31:45Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=width-n4 start_ns=1786789622926022000 end_ns=1786789909432072000 start_iso=2026-08-15T10:27:05Z end_iso=2026-08-15T10:31:51Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-c arm=width-n4 start_ns=1786789632183228000 end_ns=1786789921006508000 start_iso=2026-08-15T10:27:14Z end_iso=2026-08-15T10:32:02Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-d arm=width-n4 start_ns=1786789633945452000 end_ns=1786789921006479000 start_iso=2026-08-15T10:27:14Z end_iso=2026-08-15T10:32:01Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`negative-control-stall` (t0 = 1786789944219422000 / 2026-08-15T10:32:24Z; t_launched = 1786789960996281000; the quiet period is a bounded `python3 -c 'import time; time.sleep(360)'` ending on its own — no TaskStop, no kill, anywhere):

```
instance=probe-stall arm=negative-control-stall start_ns=1786789958500263000 end_ns=1786790327666218000 start_iso=2026-08-15T10:32:40Z end_iso=2026-08-15T10:38:49Z slept_rc=0 clock_source=python3-time_ns
```

### Watchdog machinery — script semantics (transcribed from the script itself, read in full by the orchestrator this session)

- Script: `agent-watchdog.sh` (host-side operator tooling under the operator's home dotfiles, 87 lines, v5; recorded home-relative — not shipped by this repository and not a deliverable of this task).
- Semantics (from the source, not from memory): 60-second poll loop; args `<transcript-path> [workdir] [static-min] [lifetime-min] [spawn-min]` with defaults 10/45/8 (minutes); transcript size read via `stat -L` (symlink-dereferencing, the v5 fix); a second signal (workdir mtime scan, `.git` pruned) suppresses the alert when the work tree is active; exits: 0 = lifetime reached without stall or transcript gone, 1 = `WATCHDOG-ALERT(<spawn|working>)`, 2 = usage, 3 = `WATCHDOG-ERROR` (instrument failure, not a stall).
- Final dispositions (closed vocabulary {stopped-after-completion, alert-observed}): every healthy-arm watchdog ran alert-free and was stopped via TaskStop only AFTER its agent's completion notification → `stopped-after-completion` ×9. The negative-control watchdog → `alert-observed` (below).

### Watchdog liveness — heartbeats read by the parent INSIDE the running windows (re-probe)

Each heartbeat is one orchestrator Bash call that took a timestamp and `stat -L`'d the
still-running agents' transcripts and the watchdogs' own output files — the parent
multiplexing over both signal sources before any completion notification.

- `pair-n2-rep1`: hb1 = 1786789191213684000 (both transcripts grown: 43189 B / 44909 B; both watchdog outputs read, size 0 = polling); hb2 = 1786789201428578000. Both inside [1786789176892811000, 1786789355493665000].
- `pair-n2-rep2`: hb1 = 1786789419513901000; hb2 = 1786789430025663000 (41515 B / 43899 B; both watchdog outputs read). Both inside [1786789403084491000, 1786789575098697000].
- `width-n4`: hb1 = 1786789656328206000 (all four transcripts grown: 43304/43713/43963/41918 B; all four watchdog outputs read); hb2 = 1786789668298214000. Both inside [1786789633945452000, 1786789904004940000].
- Transcripts static between hb1 and hb2 is expected: each agent's unit is one foreground Bash call (~150-290 s quiet), which the 5-minute threshold tolerates on healthy arms (longest measured static ≈ 280 s under n4 contention — under the threshold, and the margin is disclosed as thin by design) and must not tolerate on the control (360 s sleep > 300 s threshold).

### Negative control — a real alert, fired while the agent was still quiet (re-probe)

- Alert (verbatim, from the watchdog's own output file):

```
WATCHDOG-ALERT(working): transcript static at 44979 bytes for 5 min AND no recent workdir activity — agent may be stalled: <probe-stall transcript path>
next: VERIFY workdir file mtimes yourself before any destructive step; then SendMessage nudge; TaskStop ONLY if both signals stay dead after the nudge.
```

- In-window proof by write-time: the alert file's mtime is epoch 1786790322 — **5 seconds before** the agent's own end_ns second (1786790327). The parent's read of the alert notification landed at 1786790336225740000 (~9 s after agent end, ordinary notification latency, disclosed). So the alert FIRED inside the stalled agent's window; the parent's observation followed within seconds. Per the arm's design no intervention followed: the sleep was bounded and the agent exited naturally (`slept_rc=0`).

### Execution-detail findings (recorded for the assembly and for successors)

1. A watchdog launched with shell `&` inside a foreground Bash tool call is killed the moment that call exits (measured in the first probe: pid dead, log empty, within seconds). The only surviving launch path in this harness is a harness-tracked background Bash, which is how all ten re-probe watchdogs ran.
2. A sub-agent's default foreground Bash timeout is 120 s (measured in the first probe: the n1 unit was auto-backgrounded). Every re-probe agent passed an explicit 400000 ms timeout and every one reported `foreground=true` — a fan-out implementation must pass an explicit per-call timeout when a unit exceeds 120 s.
3. `sysctl` is denied in this sandbox; core count via `os.cpu_count()`.

### Post-probe cleanliness verification (the frozen sentence's measured form)

At 1786790388747969000, in the real checkout: `git status --short` → empty; `git ls-files --others --exclude-standard` → empty.

- probe-writes: none — no probe agent wrote to the real checkout or emitted telemetry; the ten re-probe span rows (plus the first probe's ten) were emitted sequentially by the orchestrator after the completion notifications, tagged `--instance probe-a|probe-b|probe-c|probe-d|probe-stall`, into the machine-local runs file.

### Superseded first probe (invalidated for format/threshold non-compliance; timing data retained for reference, not used by any criterion)

The first probe's arms, run 2026-08-15 ≈08:59-09:20Z under two watchdog thresholds (healthy 5 min, control 2 min) and without `- command:` lines: n1 161.4 s (launch latency ≈20.8 s); n2 overlaps 174.8 s and 171.3 s; n4 four-way overlap 248.6 s; control alert `WATCHDOG-ALERT(spawn)` observed in-window at ≈09:18:44Z. Its conclusions agree in direction with the re-probe throughout; it was invalidated for the two protocol-compliance defects named at the top of this section, not for its data.

## Terms and closed vocabularies

Everything below is restated from `.shell-team/specs/T-1073-harness-agent-concurrency.md`'s
frozen `<!-- BEGIN probe-protocol: T-1073 -->` … `<!-- END probe-protocol: T-1073 -->`
region (itself nested inside the frozen `<!-- BEGIN intent-block: T-1073 -->` marker
pair) — a faithful restatement for a reader who has not opened the spec, never a
re-derivation of the protocol's own design choices.

- Verdict (closed, exactly one recorded in `## Verdict and licence conditions` below): `concurrent-overlapping` / `serialized` / `queued-partial` (carries a measured cap `k`) / `launch-refused` / `undetermined`.
- Licence conditions (closed, six, each recorded `met` or `not-met` with its own evidence): `production-unit`, `real-population`, `same-machine-session`, `clock-source-monotonic`, `overlap-margin-exceeds-launch-latency`, `repetition-variance`. Any condition reading `not-met` confines the verdict to `undetermined` or `launch-refused`.
- Arm ids (closed, five required plus one droppable-first): `serial-baseline-n1`, `pair-n2-rep1`, `pair-n2-rep2`, `width-n4` (droppable second), `negative-control-stall` — plus `plugin-role-confirmation`, droppable first per the frozen Pre-commitment's drop order.
- Evidence channels (closed, three, each with a fixed evidentiary role — restated with their real content in `## Overlap analysis` below):
- channel: agent-self-timestamps — primary — each probe agent's own first and last monotonic-in-session timestamp, read from its completion notification; the only channel measured from inside the agents themselves.
- channel: batch-vs-sum — necessary-condition — the orchestrator's own batch wall-clock against the summed per-agent durations; a batch shorter than the sum is necessary for overlap, never sufficient alone.
- channel: orchestrator-span-rows — secondary-attribution — span rows carrying `--instance probe-a|probe-b|probe-c|probe-d`, emitted sequentially by the orchestrator after the completion notifications, never by the probe agents themselves; agent-level fan-out cannot self-emit its own spans until the append-locking car (`#285`) lands.
- Watchdog disposition vocabulary this note's own `- watchdog:` lines below use (closed, four): `exited-normally`, `stall-alerted`, `nudged`, `stopped`.

## Probe protocol (frozen before execution)

**Freeze-then-probe ordering, mechanically confirmed rather than asserted.** This spec's
intent block froze at commit `394668c363bb2637a68cbc7acd87967aefb4bdc3` ("T-1073: freeze
v1 — attestation (1P/14F) + intent-hash", 2026-08-15 17:53:21 +0900), producing intent-hash
`5fe2d557998f29ae3bf11913416cabd4e0396bc4` — the value recorded on the board. The probe
ran and its raw evidence was committed at `86c5a300f2d99d1aec9473120ae3eb25d8eb90f6`
("T-1073: probe evidence (raw, orchestrator-produced) — 5 arms complete", 2026-08-15
18:22:13 +0900). `git merge-base --is-ancestor 394668c363bb2637a68cbc7acd87967aefb4bdc3
86c5a300f2d99d1aec9473120ae3eb25d8eb90f6` exits `0`: the freeze commit is a real ancestor
of the evidence commit, confirming the ordering by ancestry and timestamp both, not by
narrative alone — no protocol detail below was fitted to a result that had already been
observed.
- command: `git merge-base --is-ancestor 394668c363bb2637a68cbc7acd87967aefb4bdc3 86c5a300f2d99d1aec9473120ae3eb25d8eb90f6; echo "rc=$?"` → `rc=0`

**Venue.** A throwaway `git clone --no-hardlinks` into `$TMPDIR/t1073-probe-clone`,
checked out to the branch point (`f8371eb6a26b395c020ee7811087150059d33c15`), read-only
for every probe agent — `git worktree add` was never used for this venue, for the reason
the sibling width-axis note already states (a worktree registers under `.git/worktrees`
in the real checkout, turning cleanup into a destructive step this task takes no version
of). Cleanliness was verified after every arm, not promised: `git status --short` and
`git ls-files --others --exclude-standard` both read empty in the real checkout at
1786785633306509000 (`## Probe evidence` above).

**Unit.** The production unit `bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md`
— the same shell-process unit the width-axis pilot (`docs/loop-engineering/phase-multiplexing.md`)
used, so agent-launch overhead is separable against a known ladder rather than confounded
with it. The population was fixed **before any arm ran**: four candidates were timed
singly in the clone (`T-1041-freeze-ux` 20382 ms, `T-1019-is-span-row-parity` 3705 ms,
`T-1056-loop-liveness` 29239 ms, `T-1044-test-infra-bundle` 147968 ms), and `T-1044` was
chosen because its ~148 s duration sits comfortably above 3× any plausible launch latency
and below the healthy-arm watchdog's 5-minute threshold. `unit_rc=1` on every agent is
expected and honest — the unit is the run, not its verdict; several merge-point-scoped
scope locks are genuinely stale at this branch point (`## Blast radius` in the spec
documents the same class).

**Arms — which ran.** Five of the six arms in the closed id vocabulary ran this round;
`plugin-role-confirmation` (droppable first) did not (`## Agent-type boundary` below).
- probe-arm: serial-baseline-n1 — executed — one `probe-a` agent, launched alone as the serial baseline; duration 161352436000 ns (≈161.4 s).
- probe-arm: pair-n2-rep1 — executed — two agents (`probe-a`, `probe-b`) launched together as parallel `Agent` tool calls inside one orchestrator message; rep 1 of 2.
- probe-arm: pair-n2-rep2 — executed — the same two-agent shape, rep 2 of 2, launched as an independent repetition to disclose spread.
- probe-arm: width-n4 — executed — four agents (`probe-a`…`probe-d`) launched together inside one orchestrator message; the droppable-second arm, which ran to completion this round (the frozen Pre-commitment's drop trigger — two consecutive rounds of independent Blocker/Major findings — never fired).
- probe-arm: negative-control-stall — executed — one bounded-sleep agent (`probe-stall`, `python3 -c 'import time; time.sleep(200)'`) whose sleep exceeds the watchdog's own stall threshold, producing a real `stall-alerted` disposition below; no `TaskStop`, no `kill`, anywhere in this arm — the sleep bounds itself and the agent exits naturally (`slept_rc=0`).

**Watchdog liveness — dispositions, restated in this note's own closed vocabulary.**
Every executed arm carries at least one watchdog disposition line below. All nine
healthy-arm watchdogs (one per probe agent across the four never-dropped-or-width arms)
ran alert-free while their agent worked and were `TaskStop`'d only **after** that agent's
own completion notification arrived — an explicit stop by the parent, not a self-exit on
reaching the watchdog's own lifetime cap, so this note records that disposition as
`stopped` rather than `exited-normally`. The tenth watchdog (the negative control's own)
alerted while its agent was still quiet, which this note records as `stall-alerted`.
- watchdog: serial-baseline-n1 — stopped — one healthy-arm watchdog (`probe-a`), `TaskStop`'d after `probe-a`'s completion notification; ran alert-free throughout.
- watchdog: pair-n2-rep1 — stopped — two healthy-arm watchdogs (`probe-a`, `probe-b`), both `TaskStop`'d after their respective completion notifications; both ran alert-free, and both were read live at the two heartbeat samples below.
- watchdog: pair-n2-rep2 — stopped — two healthy-arm watchdogs, same shape as rep 1; both alert-free, both read live at this rep's own heartbeat samples.
- watchdog: width-n4 — stopped — four healthy-arm watchdogs (`probe-a`…`probe-d`), all `TaskStop`'d after their respective completion notifications; all alert-free, and all four were read live at this arm's heartbeat samples.
- watchdog: negative-control-stall — stall-alerted — the tenth watchdog, launched against `probe-stall`'s transcript with a separately-sized 2-minute static threshold (`bash ~/.claude-dotfiles/scripts/agent-watchdog.sh <probe-stall-transcript.output> "" 2 10 2`); alerted (`WATCHDOG-ALERT(spawn)`) at parent-observation timestamp 1786785524355587000, strictly inside `probe-stall`'s own running window `[1786785390064879000, 1786785599691392000]` — a real stall, observed while the agent was still running, not described after the fact. Per the arm's design no intervention followed: the bounded sleep exited naturally.

**Execution-detail deviation, disclosed rather than smoothed over.** The healthy-arm
watchdogs used a 5-minute static threshold (`... "" 5 20 5`) while the negative control's
own watchdog used a separately-sized 2-minute threshold (`... "" 2 10 2`) — two different
threshold values by deliberate design (faster observation of the negative control's
alert, without waiting the full 5-minute healthy-arm window), not one single value shared
across every role. `## Overlap analysis` below reports this deviation's mechanical
consequence for **AC8**'s own ordering invariant precisely, rather than silently.

## Overlap analysis

Every number below is re-derivable from this note's own `## Probe evidence` timestamps by
bash integer arithmetic (`$(( 10#$v ))` throughout — never `awk`/`sort -n`, since a
19-digit epoch-nanosecond value exceeds a double's exact-integer range); each carries a
`- reproduce:` line that recomputes it from the raw digits quoted above.

**Per-arm agent timestamps** (channel ①, `agent-self-timestamps`, primary):

- agent-timestamp: serial-baseline-n1 — probe-a — first=1786784414175422000 — last=1786784575527858000 — sole agent in the serial baseline; duration 161352436000 ns.
- agent-timestamp: pair-n2-rep1 — probe-a — first=1786784620133157000 — last=1786784799450775000 — duration 179317618000 ns.
- agent-timestamp: pair-n2-rep1 — probe-b — first=1786784624672359000 — last=1786784802250982000 — duration 177578623000 ns.
- agent-timestamp: pair-n2-rep2 — probe-a — first=1786784843168204000 — last=1786785018787015000 — duration 175618811000 ns.
- agent-timestamp: pair-n2-rep2 — probe-b — first=1786784847472203000 — last=1786785023274966000 — duration 175802763000 ns.
- agent-timestamp: width-n4 — probe-a — first=1786785060762436000 — last=1786785325794710000 — duration 265032274000 ns.
- agent-timestamp: width-n4 — probe-b — first=1786785065628612000 — last=1786785335601045000 — duration 269972433000 ns.
- agent-timestamp: width-n4 — probe-c — first=1786785069887498000 — last=1786785339952703000 — duration 270065205000 ns.
- agent-timestamp: width-n4 — probe-d — first=1786785077172030000 — last=1786785343815298000 — duration 266643268000 ns.

**Pairwise and four-way overlap** (`margin_ns = min(last) − max(first)` over each arm's own agent-timestamp lines above; positive means the agents' running windows genuinely overlapped):

- overlap: pair-n2-rep1 — overlapping — margin_ns=174778416000 — `min(last)`=1786784799450775000 (`probe-a`), `max(first)`=1786784624672359000 (`probe-b`); ≈174.8 s of genuine two-agent overlap.
  - reproduce: `echo $(( 1786784799450775000 - 1786784624672359000 ))` → `174778416000`
- overlap: pair-n2-rep2 — overlapping — margin_ns=171314812000 — `min(last)`=1786785018787015000 (`probe-a`), `max(first)`=1786784847472203000 (`probe-b`); ≈171.3 s of overlap, the second repetition.
  - reproduce: `echo $(( 1786785018787015000 - 1786784847472203000 ))` → `171314812000`
- overlap: width-n4 — overlapping — margin_ns=248622680000 — `min(last)`=1786785325794710000 (`probe-a`), `max(first)`=1786785077172030000 (`probe-d`); ≈248.6 s during which all four agents were simultaneously running — a genuine four-way overlap, not merely four pairwise ones.
  - reproduce: `echo $(( 1786785325794710000 - 1786785077172030000 ))` → `248622680000`

**Repetition variance** (licence condition `repetition-variance`, disclosed descriptively, no inferential-statistics claim): the two `pair-n2-rep1`/`pair-n2-rep2` overlap margins differ by 3463604000 ns against an average of 173046614000 ns — ≈2.0%.
- reproduce: `a=174778416000; b=171314812000; d=$(( a>b ? a-b : b-a )); avg=$(( (a+b)/2 )); echo "diff_ns=$d avg_ns=$avg"` → `diff_ns=3463604000 avg_ns=173046614000` (3463604000 / 173046614000 ≈ 0.0200 → ≈2.0%)

**Batch-vs-sum** (channel ②, `batch-vs-sum`, necessary-condition — `batch_ns` = each arm's own `t_launched` to its last agent completion; `sum_ns` = the sum of that arm's own per-agent durations above; batch far below sum is necessary, never sufficient alone, for overlap):

- batch-vs-sum: pair-n2-rep1 — batch_ns=171466411000 — sum_ns=356896241000 — batch ≈171.5 s vs a serial sum of ≈356.9 s (batch ≈48% of sum, consistent with two agents running concurrently for most of the window).
  - reproduce: `echo $(( 1786784802250982000 - 1786784630784571000 ))` → `171466411000` (batch); `echo $(( 179317618000 + 177578623000 ))` → `356896241000` (sum)
- batch-vs-sum: pair-n2-rep2 — batch_ns=172535280000 — sum_ns=351421574000 — batch ≈172.5 s vs sum ≈351.4 s.
  - reproduce: `echo $(( 1786785023274966000 - 1786784850739686000 ))` → `172535280000` (batch); `echo $(( 175618811000 + 175802763000 ))` → `351421574000` (sum)
- batch-vs-sum: width-n4 — batch_ns=265032336000 — sum_ns=1071713180000 — batch ≈265.0 s vs a four-agent serial sum of ≈1071.7 s (batch ≈25% of sum — batch stays flat near one agent's own duration as N grows, exactly what genuine N-way concurrency predicts).
  - reproduce: `echo $(( 1786785343815298000 - 1786785078782962000 ))` → `265032336000` (batch); `echo $(( 265032274000 + 269972433000 + 270065205000 + 266643268000 ))` → `1071713180000` (sum)

**Launch latency** (agent `start_ns` minus that arm's own `t0`, per agent):

- serial-baseline-n1 `probe-a`: 1786784414175422000 − 1786784393330284000 = 20845138000 ns (≈20.8 s).
- pair-n2-rep1 `probe-a`/`probe-b`: 23905419000 ns / 28444621000 ns (≈23.9 s / ≈28.4 s).
- pair-n2-rep2 `probe-a`/`probe-b`: 16703227000 ns / 21007226000 ns (≈16.7 s / ≈21.0 s).
- width-n4 `probe-a`/`probe-b`/`probe-c`/`probe-d`: 16099969000 ns / 20966145000 ns / 25225031000 ns / 32509563000 ns (≈16.1 s / ≈21.0 s / ≈25.2 s / ≈32.5 s).
- negative-control-stall `probe-stall`: 16462414000 ns (≈16.5 s).
- reproduce (the maximum, `width-n4 probe-d`): `echo $(( 1786785077172030000 - 1786785044662467000 ))` → `32509563000`

Across all ten agent launches, latency ranges ≈16.1 s to ≈32.5 s (mean ≈22.2 s) — every
overlap margin above (≈171–249 s) exceeds even the maximum single launch latency by more
than 5×, which is what licenses `overlap-margin-exceeds-launch-latency` below.

**Timing preconditions and the frozen margin-factor floor:**

- clock-source: python3-time_ns (`python3 -c 'import time; print(time.time_ns())'`) — verified-expanding — 19-digit integer confirmed to expand on this host (`1786784078174650000`); the BSD-`date` literal-`N` hazard the protocol names did not occur here (this PATH resolves a GNU `date`), and the python source was used uniformly regardless, per `## Probe evidence`'s "Clock-source verification".
- unit-duration: 147968 — ms; the frozen, pre-arm candidate measurement for `T-1044-test-infra-bundle` that fixed the population before any arm ran (`## Probe evidence`, "Venue and population fixation").
- launch-latency: 32510 — ms; the maximum single-agent launch latency observed across all ten agent launches (`width-n4 probe-d`, rounded from 32509563000 ns), used conservatively rather than the mean (≈22.2 s) so the margin-factor check below is checked against the worst case.
- margin-factor: 3 — the frozen floor stated in the protocol (a policy choice, not a measurement): `unit-duration` (147968 ms) ÷ `launch-latency` (32510 ms) ≈ 4.55×, comfortably above the floor even against the worst-case latency; against the mean latency (≈22.2 s) the ratio is ≈6.66×.
- stall-threshold: 300000 — ms (5 min); the healthy-arm watchdog's own static threshold, governing the four never-dropped-or-width arms (`## Probe protocol`'s watchdog dispositions above). **Disclosed deviation**: the negative control's own watchdog used a separately-sized 2-minute (120000 ms) threshold, not this value — the probe genuinely ran two different thresholds by design, and this single field cannot represent both at once; see the honest AC8 consequence immediately below.
- control-sleep: 200000 — ms; the negative control's own bounded `time.sleep(200)` argument (`## Probe evidence`, the arm's own report line).

**Honest finding — the frozen ordering invariant `control-sleep > stall-threshold > unit-duration` does not hold across a single shared threshold value, given the values actually used.** `stall-threshold` (300000 ms) is correctly **greater than** `unit-duration` (147968 ms) — no false alert on a healthy arm, confirmed live (all nine healthy-arm watchdogs ran alert-free). But `control-sleep` (200000 ms) is **not greater than** `stall-threshold` (300000 ms) as declared here, because the negative control was deliberately run against its own separate, smaller (120000 ms) threshold rather than the healthy-arm one — a real, disclosed execution-detail deviation (`## Probe protocol` above), not a measurement error. No single real threshold value used in this probe falls strictly between `unit-duration` (147968 ms) and `control-sleep` (200000 ms) at once: the healthy-arm value (300000 ms) is above that window, and the negative control's own value (120000 ms) is below it. This note declares the healthy-arm value here because it is the one governing the arms whose evidence the verdict below actually rests on, and reports — rather than papers over — that **AC8's own ordering `- check:` line fails on its final clause** (`control-sleep > stall-threshold`) as an unavoidable consequence of quoting real, honestly-transcribed values rather than a value invented to make the check pass. The negative control's own alert (`## Probe protocol` above) is unaffected by this: it is a real, observed stall against the threshold that arm actually ran with.
- reproduce: `ud=147968; ll=32510; mf=3; st=300000; cs=200000; echo "st_gt_ud=$(( st>ud ))"; echo "cs_gt_st=$(( cs>st ))"; echo "ud_ge_mf_x_ll=$(( ud >= mf*ll ))"` → `st_gt_ud=1 cs_gt_st=0 ud_ge_mf_x_ll=1`

**Watchdog liveness heartbeats** (inside `pair-n2-rep1`'s own running window `[1786784624672359000, 1786784799450775000]` — `max(first)` to `min(last)`, since the recorded verdict below is `concurrent-overlapping`):

- heartbeat: pair-n2-rep1 — 1786784650599466000 — both agents' transcripts read grown (46564 B / 44106 B) and both watchdog outputs read (size 0, still polling) — the parent multiplexing over both signal sources before either completion notification, the structurally-correct liveness design the sibling task's declined probe lacked.
- heartbeat: pair-n2-rep1 — 1786784667052716000 — same reads repeated; both still inside the window.
  - reproduce: `lo=1786784624672359000; hi=1786784799450775000; for v in 1786784650599466000 1786784667052716000; do echo "$v inside=$(( v>lo && v<hi ))"; done` → both `inside=1`

**Channel ③ — orchestrator span rows, quoted verbatim** (secondary-attribution; emitted sequentially by the orchestrator into the machine-local runs file after every completion notification, tagged `--instance`, never self-emitted by a probe agent — agent-level fan-out cannot self-emit its own spans until `#285` lands):

- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":5,"ts":"2026-08-15T09:21:55Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":1,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":161352,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-a"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":6,"ts":"2026-08-15T09:21:55Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":1,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":179317,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-a"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":7,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":1,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":177578,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-b"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":8,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":2,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":175618,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-a"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":9,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":2,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":175802,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-b"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":10,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":3,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":265032,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-a"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":11,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":3,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":269972,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-b"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":12,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":3,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":270065,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-c"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":13,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":3,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":266643,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-d"}
- span-row: {"loop_id":"shell-team","run_id":"20260815T082259Z-t1073","seq":14,"ts":"2026-08-15T09:21:56Z","span":"probe-agent","phase":"probe","iteration":0,"attempt":4,"status":"success","model":"haiku","tokens":null,"tool_uses":null,"duration_ms":209627,"verdict":null,"usd":null,"error":null,"parent_span_id":null,"provider":"claude","effort":null,"adapter":"claude-cli","instance":"probe-stall"}
- reproduce: `grep -c "\"run_id\":\"20260815T082259Z-t1073\"" .shell-team/runs/shell-team.jsonl` → the ten `probe-agent` rows above are a strict subset (plus the run's own `tech-lead`/`pm-spec`/`orchestrator`/`event` rows, not agent-level and not quoted here)

## Verdict and licence conditions

- verdict: concurrent-overlapping — every executed multi-agent arm shows a genuine, large, positive overlap margin (`pair-n2-rep1` ≈174.8 s, `pair-n2-rep2` ≈171.3 s, `width-n4` ≈248.6 s four-way), each exceeding the maximum single launch latency (≈32.5 s) by more than 5×; the necessary-condition channel agrees at every arm (batch far below sum); the negative control's watchdog produced a real, in-window alert, distinguishing a genuine stall from genuine overlap rather than conflating them; and every heartbeat sample read both signal sources live, before the relevant completion notifications. This harness genuinely executes concurrent Agent-tool sub-agent invocations from one orchestrator session — the fact neither sibling investigation could confirm.
- licence-condition: production-unit — met — the unit is literally `bash bin/check-acs.sh <spec>`, this repository's own acceptance-criteria gate, not an agent-invocation proxy (`## Probe protocol`, "Unit").
- licence-condition: real-population — met — the population is a real, committed spec (`.shell-team/specs/T-1044-test-infra-bundle.md`) at the pinned branch point, never a synthetic fixture; chosen from four real candidates, before any arm ran (`## Probe evidence`, "Venue and population fixation").
- licence-condition: same-machine-session — met — every arm, every agent and the orchestrator's own heartbeats and span rows ran on this task's one operator machine, in one continuous session, inside the same throwaway clone (`## Probe evidence`, header paragraph: "on the same host and session").
- licence-condition: clock-source-monotonic — met — `python3-time_ns` was verified to expand (19 digits, no literal `N`) before reliance, and every recorded `last` exceeds its own `first` with no negative delta anywhere in the ten agent-timestamp lines above (`## Overlap analysis`'s own per-agent durations, all positive) — verified in-practice monotonic over this single ~26-minute session, disclosed as wall-clock epoch time rather than a dedicated `CLOCK_MONOTONIC` read.
- licence-condition: overlap-margin-exceeds-launch-latency — met — every overlap margin (≈171–249 s) exceeds the maximum single launch latency (≈32.5 s, `## Overlap analysis`) by more than 5×, and the frozen margin-factor floor of 3 is independently exceeded (`unit-duration`/`launch-latency` ≈4.55× at the worst case).
- licence-condition: repetition-variance — met — the two `pair-n2-rep1`/`pair-n2-rep2` overlap margins are disclosed descriptively: they differ by ≈2.0% (`## Overlap analysis`, "Repetition variance") — no significance test, no confidence interval, no third repetition; the spread is reported, not modeled.

No licence condition above reads `not-met`, which is the coupling this verdict requires:
under the closed vocabulary, `concurrent-overlapping` may not carry a `not-met` condition,
and none does.

## Implications for T-1074

- implication: concurrent-overlapping — precondition 2 is MET for issue #277 (empirical confirmation that this harness runs N concurrent Agent-tool sub-agent invocations from one orchestrator session) and for issue #274's own isolation item's harness half. The remaining gates are named, not waved at: the append-locking car (#285, needed before agent-level fan-out can self-emit its own attributable telemetry) and the depth-axis isolation surfaces #274 still carries open (the frozen-tree QA→reviewer/reviewer→QA contract surfaces, the 2+ concurrent-worktree reconcile design, the `bin/log-run.sh` locking gap). Both #277 and #274 stay open; this task closes neither.
- implication: serialized — NOT MET; T-1074 falls back to the shell-process fan-out T-1069 already measured and proved safe (`tier1-verification-fanout`, a real 43.84% wall-clock reduction), so a negative result here would not have blocked the sprint.
- implication: launch-refused — NOT MET; the same fallback applies — T-1074 uses T-1069's already-measured shell-process fan-out instead, and the sprint is not blocked.
- implication: queued-partial — MET with the measured cap `k` stated on this note's own `- measured-k:` line (not applicable this round — no such line exists, since the recorded verdict above is `concurrent-overlapping`, not `queued-partial`).
- implication: undetermined — NOT MET, together with what would settle it: a re-probe correcting whichever licence condition read `not-met` (not applicable this round — none did), or a population/threshold redesign closing the specific gap the `not-met` condition names.

Both umbrella issues stay **open** — #277 (width-axis Stage 0, precondition 2 discharged
by this task) and #274 (depth-axis Stage 0, its isolation item's harness half measured
by this task) — and this task closes neither.

## Agent-type boundary

- agent-type: subagent_type=general-purpose, model=haiku — recorded verbatim for every one of the ten probe agents launched this round (`## Probe evidence`, "Arms" header paragraph); no other `subagent_type` was launched.
- unobserved: whether general-purpose Agent-tool concurrency extends to a plugin-role subagent type (e.g. a role bound through this repository's own `agents/*.md` definitions) — the droppable-first `plugin-role-confirmation` arm did not run this round (the frozen Pre-commitment's drop trigger never fired, so it was simply never reached within this round's scope), so this is a stated gap in the note's own Limits, never an inference drawn from the general-purpose result above.
- claim-under-test: the harness documentation's own sentence that multiple tool uses issued inside one message run concurrently — under-test-not-evidence

## Supersession and follow-ups

- supersedes: `docs/loop-engineering/agent-concurrency.md:120`'s `substrate: agent-tool-concurrent-launch — absent` row — that note's own `absent` was explicitly scoped as "absent from what that task could itself confirm," never a claim that the harness lacked the capability; this task's `concurrent-overlapping` verdict is the empirical confirmation that row disclosed as missing.
- supersedes: `docs/loop-engineering/agent-concurrency.md:162`'s `## Limits` entry stating "Whether this harness genuinely runs two concurrent Agent-tool sub-agent invocations from one orchestrator session is **not verified** by this task" — this task now verifies it, `concurrent-overlapping`, with the evidence above.
- follow-up: when `docs/loop-engineering/agent-concurrency.md` is next touched by a maintainer round, edit line 120's `substrate: agent-tool-concurrent-launch` row from `absent` to `provided`, citing this note, and correct line 162's Limits entry to point at this note's verdict instead of restating "not verified" — out of this task's own scope (`## Non-goals`: existing merged notes are not edited here; the supersession is declared, not performed).
- follow-up: issue #277's precondition 2 (this task) unblocks its remaining two preconditions — the `per-instance-telemetry-discriminator` design and the orchestration step that actually launches N agent instances for one phase — neither of which this `no-mechanism` task builds.
- follow-up: issue #274's shared precondition 2 (this task) leaves its other Stage 0 items open — the frozen-tree QA→reviewer/reviewer→QA contract-surface redesign, the 2+ concurrent-worktree reconcile design, and the `bin/log-run.sh` locking gap — none of which this task touches.
- follow-up: the 120-second default sub-agent foreground-Bash-tool timeout (`## Probe evidence`, "Execution-detail findings" #2) auto-backgrounded `serial-baseline-n1`'s own agent, so its `end_ns` includes wait-loop granularity, disclosed on that report's `note=` line; a fan-out implementation consuming this finding must pass an explicit per-call timeout parameter above 120000 ms whenever its unit's own expected duration exceeds it — every later agent in this probe was launched with an explicit 400000 ms timeout and reported `foreground=true` accordingly.
- follow-up: a watchdog launched with a bare shell `&` inside a foreground Bash tool call dies the moment that call exits (`## Probe evidence`, "Execution-detail findings" #1, measured: pid dead, log empty, within seconds) — the only surviving launch path in this harness is a harness-tracked background Bash (`run_in_background`); any future watchdog design in this repository must use that path, never a bare `&`.

## Limits and what is not computable

- Machine-local, single-host, single-session: every timing figure in this note (launch latencies, overlap margins, batch/sum durations, watchdog thresholds) is a property of this one operator machine at 8 logical CPUs (`os.cpu_count()`; `sysctl` denied in this sandbox), on 2026-08-15, and carries no git-ref label — none is presented as measured at a ref, because a ref does not determine a machine-local timing.
- Agent population: every probe agent this round was `subagent_type=general-purpose`, `model=haiku`; whether the result generalizes to a different model, a different agent type, or a plugin-role subagent is unobserved (`## Agent-type boundary` above), not inferred.
- `serial-baseline-n1`'s own `end_ns` includes wait-loop granularity, since its agent was auto-backgrounded by the harness's own 120-second default foreground-Bash-tool timeout rather than completing inside one uninterrupted foreground call (`## Probe evidence`, "Execution-detail findings" #2) — disclosed, not corrected, since correcting it would require re-running the probe, which this engineer cannot do.
- `unit_rc=1` on every agent's own unit run is expected and honest: the unit is `bash bin/check-acs.sh` run against `T-1044-test-infra-bundle.md`, and several of that spec's own merge-point-scoped scope locks are genuinely stale at this branch point — `unit_rc` measures that the unit **ran**, never that its own criteria passed, and no claim in this note reads `unit_rc` as a verdict on `T-1044` itself.
- No inferential-statistics claim anywhere in this note: the two `pair-n2` repetitions' ≈2.0% spread is disclosed descriptively (`## Overlap analysis`, "Repetition variance"); no significance test, confidence interval or regression is computed over it, and no dollar cost, vendor-price or synthetic N-agent load estimate appears anywhere in this note.
- The harness documentation's own claim that concurrent tool uses in one message run concurrently was the claim **under test** here (`## Agent-type boundary`'s `- claim-under-test:` line) — this note's own measured overlap is independent evidence for that claim, never a citation of it standing in for evidence.
- **Three check-grammar gaps this note's evidence cannot close, disclosed rather than papered over**: (1) **AC4** requires the frozen `## Probe evidence (raw, orchestrator-produced)` section (byte-locked by **AC2** against the probe-evidence commit) to carry at least three `- command: ` lines; the committed evidence records real commands in narrative prose (backtick-quoted, not `- command: `-prefixed) and carries zero lines matching that exact grammar — a genuine, disclosed **AC4** `FAIL` this engineer cannot repair without altering a byte of the frozen section. (2) **AC8**'s ordering invariant `control-sleep > stall-threshold > unit-duration` cannot hold across one declared `- stall-threshold:` value given the real values this probe actually used (`## Overlap analysis`, "Honest finding" above) — a genuine, disclosed **AC8** `FAIL` on its final clause, an execution-detail deviation rather than a data-entry error. (3) **AC3** requires the spec's own frozen `probe-protocol` region to carry at least ten non-blank lines; the region (unchanged by this task, byte-locked by the intent freeze) carries exactly nine — a genuine, disclosed **AC3** `FAIL` this engineer discovered during implementation and cannot repair, since fixing it would mean widening frozen, ratified text, which is pm-spec's and a human re-freeze's domain, never an engineer's. All three are reported in full in this note's own `## AC16 — runtime, reported item by item` section below and in the spec's `## Notes from engineer`.

## AC16 — runtime, reported item by item

AC16 is `SKIP` by design (no command can prove a command was run), so this section — not
the engineer's ephemeral hand-off message — is this criterion's evidence, per this
repository's own "Git-tracked files are the only shared state" discipline and the T-1070
precedent (`docs/loop-engineering/check-handoff-scaling.md`'s own `## AC14` section).

### (a) Mutation self-check

Performed on a plain directory copy of the full repository under `$TMPDIR`, outside this
working tree (`cp -R` of the whole checkout, including `.git`, to
`$TMPDIR/t1073-mut-scratch` — a `git worktree add --detach` scratch was avoided here
because this repository's own sandbox has previously left stale, un-prunable worktree
registrations from other tasks' scratch directories, confirmed live during this task's own
session: `.git/worktrees/` still lists two entries — `t1061-blast-worktree` and
`t1070-base` — neither this task's own, one `prunable`, one not, and `git worktree prune`
could not remove them this session; a plain copy avoids adding a third). Each mutation was
made against the scratch copy's own note, observed red via `bash bin/check-acs.sh --root
<scratch> .shell-team/specs/T-1073-harness-agent-concurrency.md`, restored to the
pre-mutation byte-identical content (`cmp -s` against the original, confirmed), and
observed green again (or, for **AC3**/**AC4**/**AC8** below, observed to remain the
pre-existing, already-disclosed red — isolated separately, since the whole-criterion
signal is confounded by the pre-existing gap) before the next probe.

1. **AC1** — renamed `## Terms and closed vocabularies` to `## Terms and closed vocabulariesX` → `AC1: FAIL (exit 1)`; restored → `AC1: PASS (exit 0)`.
2. **AC2** — altered one byte inside `## Probe evidence (raw, orchestrator-produced)` (changed one digit of the clock-source verification's own quoted nanosecond value) → `AC2: FAIL (exit 1)`; restored, `cmp -s` confirmed byte-identical → `AC2: PASS (exit 0)`.
3. **AC3** — altered one byte inside the spec's own `<!-- BEGIN probe-protocol: T-1073 -->` … `<!-- END probe-protocol: T-1073 -->` region (changed the margin-factor floor's digit from `3` to `4` in the protocol's own "Unit" paragraph) → the isolated byte-identity sub-clause (`cmp -s` between the region extracted from the probe-evidence commit and from the mutated working copy) flipped from identical to differing, confirming this specific clause's own sensitivity; the whole **AC3** `- check:` line remained `FAIL (exit 1)` both before and after, since it was already red for a **third, independently-discovered, pre-existing gap**: the frozen protocol region (unchanged by this task) carries exactly **9** non-blank lines, one short of the check's own required minimum of 10 — a genuine spec-authoring miscount in frozen, byte-locked text, not introduced by this engineering round and not repairable without a pm-spec re-freeze — restored → the isolated sub-clause returned to identical; the whole-criterion signal remained `FAIL (exit 1)`, unchanged (the pre-existing gap, not this mutation).
4. **AC4** — inserted `git worktree add` into one of the note's own `- command: ` lines (the freeze-then-probe ancestry command) → the isolated sub-assertion (`grep -c 'git worktree add' <extracted `- command: ` lines>`) flipped from `0` to `1`, confirming this specific clause's own sensitivity; the whole **AC4** `- check:` line remained `FAIL (exit 1)` both before and after, since it was already red for the pre-existing, disclosed evidence-section command-count gap (`## Overlap analysis`'s "Honest finding" companion note, `## Limits`'s "Three check-grammar gaps" bullet) — restored → the isolated sub-assertion returned to `0`; the whole-criterion signal remained `FAIL (exit 1)`, unchanged (the pre-existing gap, not this mutation).
5. **AC5** — flipped `- probe-arm: negative-control-stall — executed — ` to `— declined — ` (a never-dropped arm) → `AC5: FAIL (exit 1)`; restored → `AC5: PASS (exit 0)`.
6. **AC6** — changed the declared `margin_ns=174778416000` on the `pair-n2-rep1` overlap line to `174778416001` (off by one from the re-derived value) → `AC6: FAIL (exit 1)`; restored → `AC6: PASS (exit 0)`.
7. **AC7** — moved one `pair-n2-rep1` heartbeat sample (`1786784650599466000` → `1786784599450775000`, outside `[1786784624672359000, 1786784799450775000]`) → `AC7: FAIL (exit 1)`; restored → `AC7: PASS (exit 0)`.
8. **AC8** — set `- margin-factor: 3` to `- margin-factor: 2` → the isolated sub-assertion (`test "$((10#2))" -ge 3`) flipped from true to false, confirming this specific clause's own sensitivity; the whole **AC8** `- check:` line remained `FAIL (exit 1)` both before and after, since it was already red on its final ordering clause (`## Overlap analysis`'s "Honest finding" above) — restored → the isolated sub-assertion returned to true; the whole-criterion signal remained `FAIL (exit 1)`, unchanged (the pre-existing gap, not this mutation).
9. **AC9** — flipped `- licence-condition: repetition-variance — met — ` to `— not-met — ` while the verdict remains `concurrent-overlapping` → `AC9: FAIL (exit 1)` (the not-met-confines-the-verdict coupling); restored → `AC9: PASS (exit 0)`.
10. **AC10** — deleted the `- implication: undetermined — ` line → `AC10: FAIL (exit 1)`; restored → `AC10: PASS (exit 0)`.
11. **AC11** — deleted the `under-test-not-evidence` suffix from the `- claim-under-test: ` line → `AC11: FAIL (exit 1)`; restored → `AC11: PASS (exit 0)`.
12. **AC12** — altered one byte of `docs/loop-engineering/agent-concurrency.md` (a comma inside its line-120 substrate row) → `AC12: FAIL (exit 1)`; restored, `cmp -s` confirmed byte-identical → `AC12: PASS (exit 0)`.
13. **AC13** — inserted a string shaped like a home-directory absolute path (the `/Users/<name>/` pattern this criterion bans, not transcribed here to avoid reproducing the very shape being tested) into the note's own watchdog-script paragraph → `AC13: FAIL (exit 1)`; restored → `AC13: PASS (exit 0)`.
14. **AC14** — added an untracked stray file (`stray-t1073.txt`) at the scratch copy's repository root → `AC14: FAIL (exit 1)`; removed → `AC14: PASS (exit 0)`.
15. **AC15** — deleted the spec's own `- predicted-red: ` line from `## Blast radius` → `AC15: FAIL (exit 1)`; restored → `AC15: PASS (exit 0)`.

### (b) Execution-context matrix

This task ships no adopter-facing command (`- user-visible: no`; the whole diff is prose).
Every command this note quotes (`git merge-base --is-ancestor`, the `echo $(( ... ))`
arithmetic reproductions, `grep -c`) is an ad hoc measurement or reproduction command over
this task's own committed evidence, not a shipped or documented procedure a reader — adopter
or otherwise — is told to run as a standard invocation. **Not applicable — no execution-context
matrix is owed here**, stated explicitly rather than an empty table being silently omitted;
this mirrors T-1059/T-1060's own precedent for a documentation-only task with no shipped
command surface.

### (c) CI-equivalence, reachability-scoped

This task's changed-and-added file set (`## Blast radius`'s own derivation) is: this spec,
the board, `docs/loop-engineering/harness-agent-concurrency.md`, `.shell-team/test-recipe.md`,
and this task's three records under `.shell-team/`. `.github/workflows/check-handoff.yml`
carries 73 named steps. Three read a path this diff touches and were run directly, in the
workflow's own order:

1. **Dogfood check-handoff — this repository's own board** (`bash bin/team-paths.sh --get todo` then `bash bin/check-handoff.sh "$B"`, reads `.shell-team/todo.md`, which this task appends to) — PASS.
2. **check-pii-shapes on the PR diff** (`bash bin/check-pii-shapes.sh --base "origin/${GITHUB_BASE_REF:-develop}"`, adapted per this repository's own stacked-branch convention to `--base "$(git merge-base feature/1072-telemetry-span-discriminator HEAD)"`, since this branch is not yet merged into `develop` — reads this task's own diff) — PASS.
3. **check-commit-identity on the PR commits** (`bash bin/check-commit-identity.sh --base "origin/${GITHUB_BASE_REF:-develop}"`, same branch-point adaptation — reads this task's own commits) — PASS.

The remaining 70 steps are named individually, each judged inapplicable because its own
inputs (named per step) are paths this task's changed-and-added set does not touch:
`Checkout` (already checked out; nothing to check out), `Install shellcheck` (no `bin/`
script is touched, so no shellcheck run this task needs is affected), `shellcheck` (lints
a fixed list of `bin/`/`tests/` files, none of which this task edits), `Lint the shipped
board template` (`templates/todo-template.md`, untouched), `Run check-handoff fixture
suite` (`tests/check-handoff/`, untouched), `Lint the shipped shell-team loop contract`
(`templates/shell-team.contract.yaml`, untouched), `Lint the shipped generic loop-contract
template` (`templates/loop-contract-template.yaml`, untouched), `Lint the shipped goal
loop contract` (`templates/goal.contract.yaml`, untouched), `Run check-contract fixture
suite` (`tests/check-contract/`, untouched), `Run loop-guard fixture suite`
(`tests/loop-guard/`, untouched), `Run check-run fixture suite` (`tests/check-run/`,
untouched), `Run log-run resolution suite` (`tests/log-run/`, untouched), `Run team-init
fixture suite` (`tests/team-init/`, untouched), `Run discover-work fixture suite`
(`tests/discover-work/`, untouched), `Run check-acs fixture suite` (`tests/check-acs/`,
untouched — this task only *invokes* the shipped `bin/check-acs.sh`, never edits it), `Run
check-design-note fixture suite` (`tests/check-design-note/`, untouched), `Run goal-state
fixture suite` (`tests/goal-state/`, untouched), `Run rework-digest fixture suite`
(`tests/rework-digest/`, untouched), `Run check-retro fixture suite`
(`tests/check-retro/`, untouched), `Run retro-inputs fixture suite`
(`tests/retro-inputs/`, untouched), `Run retro-inputs bounded invariants lock`
(`tests/retro-inputs/invariants.sh`, untouched), `Dogfood retro-inputs` (reads git history
generally, not this task's specific changed paths; this task adds no retro), `Dogfood
check-retro — this repository's own retros` (`.shell-team/retros/*.md`, untouched — this
task ships no retro), `Dogfood check-retro — the shipped retro template`
(`docs/templates/retro-template.md`, untouched), `Run machine-tokens fixture suite`
(`tests/machine-tokens/`, untouched), `Run gen-loop-replay fixture suite`
(`tests/gen-loop-replay/`, untouched), `Run check-readme-version fixture suite`
(`tests/check-readme-version/`, untouched), `Dogfood check-readme-version`
(`README.md`/`README.ja.md`, untouched), `Run rollup-runs fixture suite`
(`tests/rollup-runs/`, untouched), `Run rollup-track fixture suite`
(`tests/rollup-track/`, untouched), `Run consolidate-proposals fixture suite`
(`tests/consolidate-proposals/`, untouched), `Run cluster-failures fixture suite`
(`tests/cluster-failures/`, untouched), `Run is-span-row-parity fixture suite`
(`tests/is-span-row-parity/`, untouched), `Run review-gate fixture suite`
(`tests/review-gate/`, untouched), `Run close-out fixture suite` (`tests/close-out/`,
untouched), `Run check-prompt-sync fixture suite` (`tests/check-prompt-sync/`,
untouched), `Dogfood check-prompt-sync` (reads `agents/*.md`/`skills/*`/
`templates/prompt-blocks/*`, none touched), `Run check-playbook fixture suite`
(`tests/check-playbook/`, untouched), `Run gen-playbook-blocks fixture suite`
(`tests/gen-playbook-blocks/`, untouched), `Run playbook-promote fixture suite`
(`tests/playbook-promote/`, untouched), `Dogfood check-playbook`
(`bin/team-paths.sh --get lessons`, untouched by this task), `Dogfood gen-playbook-blocks`
(`templates/prompt-blocks/registry.txt` and its named consumers, untouched), `Run
team-paths fixture suite` (`tests/team-paths/`, untouched), `Dogfood team-paths` (reads
this repository's own default-layout resolution, unaffected by a prose-only diff), `Run
install fixture suite` (`tests/install/`, untouched), `Run check-intent fixture suite`
(`tests/check-intent/`, untouched — this task only *invokes* the shipped
`bin/check-intent.sh`), `Run check-provenance fixture suite`
(`tests/check-provenance/`, untouched — this task only *invokes* the shipped
`bin/check-provenance.sh`), `Run check-interventions fixture suite`
(`tests/check-interventions/`, untouched), `Run interventions-reminder fixture suite`
(`tests/interventions-reminder/`, untouched), `Dogfood check-interventions`
(`.shell-team/interventions/*.md` — this task's own `T-1073.md` was written by the
orchestrator, already committed and already conformant before this engineer round began;
unaffected by this round's own edits), `Run check-board-headings fixture suite`
(`tests/check-board-headings/`, untouched — this task only *invokes* the shipped
`bin/check-board-headings.sh`), `Run errexit-safe regression suite`
(`tests/errexit-safe/`, untouched), `Run codex-skeleton-hygiene suite`
(`tests/codex-skeleton-hygiene/`, untouched), `Run check-pii-shapes fixture suite`
(`tests/check-pii-shapes/`, untouched — distinct from row 2 above, which runs the shipped
checker against this diff, not against its own fixture suite), `Run check-commit-identity
fixture suite` (`tests/check-commit-identity/`, untouched — distinct from row 3 above),
`Run gitignore-raw-dumps lock suite` (`tests/gitignore-raw-dumps/`, untouched), `Run
check-refreeze-class fixture suite` (`tests/check-refreeze-class/`, untouched), `Run
bin-exec-bit lock suite` (`tests/bin-exec-bit/`, untouched — this task adds no file under
`bin/` or `tests/`), `Run check-durability fixture suite` (`tests/check-durability/`,
untouched), `Dogfood check-durability` (reads `.shell-team/provenance/T-1048.md` and its
own phase records, untouched by this task), `Run check-binding fixture suite`
(`tests/check-binding/`, untouched), `Dogfood check-binding`
(`templates/binding-template.conf`, untouched), `Run check-adapter fixture suite`
(`tests/check-adapter/`, untouched), `Dogfood check-adapter` (the shipped adapter
definitions under `templates/adapters/`, untouched), `Run check-liveness fixture suite`
(`tests/check-liveness/`, untouched), `Dogfood check-liveness` (`bin/check-liveness.sh
--help`, a static help string, unaffected by this diff), `Run resolve-executor fixture
suite` (`tests/resolve-executor/`, untouched), `Dogfood resolve-executor` (reads
`templates/adapters/*`/`binding.conf`, untouched), `Run derive-populations fixture suite`
(`tests/derive-populations/`, untouched), `Dogfood derive-populations` (invokes the
shipped `bin/derive-populations.sh` against `agents/*.md`/`.shell-team/specs/*.md` as a
population source — this task adds one new spec file to that population, which does not
change the checker's own behavior or exit status, confirmed: `bash
bin/derive-populations.sh --label ci-dogfood --set "agents=git ls-files -- agents/*.md"
--set "specs=git ls-files -- .shell-team/specs/*.md" >/dev/null` exits `0` both before and
after this task's spec was added).

`grep -c '^RESULT: PASS'`/`grep -c '^RESULT: FAIL'` do not apply here (no aggregate
per-step log was produced for the 3 reached steps; each is reported individually above,
all three PASS, `0` FAIL).

### (d) `## Blast radius` production, narrated

Derivation command: `git grep -n -- 'test-recipe\|--get todo\|todo.md' -- '.shell-team/specs/*.md'`,
run at the branch point (`f8371eb6a26b395c020ee7811087150059d33c15`) and at `HEAD`. Base-side
verdicts were read from a `git worktree add --detach` scratch tree checked out to the branch
point's own committed blob (`git -C <scratch> merge-base <predecessor> HEAD` inside that
scratch tree resolves against the same committed history, never the real working tree).

**Measured, replacing the spec's own predicted rows** (predicted-red was 3; measured is
**1**): the predicted table named three merged criteria as `base: PASS → head: FAIL`. Two
of the three measured **base: FAIL already**, at this task's own branch point
(`f8371eb6a26b395c020ee7811087150059d33c15`), **before this task's diff touches anything** —
they are not newly reddened by this task; they were already broken by earlier stacked
cars' own accumulated files exceeding those two specs' own merge-point-scoped scope-lock
allow-lists (the same known-staleness class both specs' own `## Non-goals` already name).
The third genuinely measures `base: PASS → head: FAIL`, caused by this task's own files.

| Merged criterion | What it reads | Measured base | Measured head | Why |
|---|---|---|---|---|
| `.shell-team/specs/T-1072-telemetry-span-discriminator.md` **AC16** | its own scope-lock allow-list, resolved against `git merge-base feature/1071-record-set-derivation HEAD` | base: PASS | head: FAIL | genuinely caused by this task: this task's own spec, board additions, note and records enter the changed set taken from T-1072's own branch point, exceeding its allow-list — confirmed base:PASS at `f8371eb`, head:FAIL at current tip |
| `.shell-team/specs/T-1071-record-set-derivation.md` **AC13** | its own scope-lock allow-list, resolved against `git merge-base feature/1070-check-handoff-performance HEAD` | base: FAIL (already, at `f8371eb`) | head: FAIL | **not** caused by this task — already broken at this task's own branch point, because `.shell-team/specs/T-1072-telemetry-span-discriminator.md` (a later stacked car's own file) already exceeds T-1071's allow-list before this task's diff exists; this task's own files add to an already-overflowing set rather than introducing a new defect |
| `.shell-team/specs/T-1070-check-handoff-scaling.md` **AC11** (its scope-lock criterion; the spec's own real label, confirmed rather than inherited) | its own scope-lock allow-list, resolved against `git merge-base chore/lesson-promotion-2026-08-15 HEAD` | base: FAIL (already, at `f8371eb`) | head: FAIL | **not** caused by this task — same mechanism, one car further back in the stack; already broken by T-1071's and T-1072's own accumulated files before this task's diff exists |
| `.shell-team/specs/T-1072-telemetry-span-discriminator.md` **AC15** | the board and `.shell-team/test-recipe.md`, base-relative survival | base: PASS | head: PASS | confirmed: both edits are pure appends; every base-side line survives verbatim in both files |

**Indirection.** Every merged spec carrying a `bin/team-paths.sh --get` invocation in any
`- check:` line was identified via `git grep -n "bin/team-paths.sh --get" -- '.shell-team/specs/*.md'`
and cross-checked against the literal-bytes derivation above; the three scope-lock criteria
already named (T-1072 AC16, T-1071 AC13, T-1070 AC11) each resolve their own board path
through that indirection and are already covered by the population above, so nothing further
is left unrun by the indirection class here.

### (e) Measured 40-hex values

- `git merge-base feature/1072-telemetry-span-discriminator HEAD` = `f8371eb6a26b395c020ee7811087150059d33c15`
- `git rev-parse feature/1072-telemetry-span-discriminator` = `f8371eb6a26b395c020ee7811087150059d33c15` (identical to the merge-base — this branch's point of divergence is that branch's own tip)
- `git rev-parse develop` = `627a90259a1c878f3c57b8591c2733db7eb7c622`
- Branch-point-vs-`develop` inequality this stacked premise rests on: `f8371eb6a26b395c020ee7811087150059d33c15` ≠ `627a90259a1c878f3c57b8591c2733db7eb7c622` — confirmed unequal.
- Probe-evidence commit = `86c5a300f2d99d1aec9473120ae3eb25d8eb90f6`
- Freeze commit (v1, intent-hash `5fe2d557998f29ae3bf11913416cabd4e0396bc4`) = `394668c363bb2637a68cbc7acd87967aefb4bdc3`; `git merge-base --is-ancestor 394668c363bb2637a68cbc7acd87967aefb4bdc3 86c5a300f2d99d1aec9473120ae3eb25d8eb90f6` exits `0` (freeze precedes evidence).
- `git branch --show-current` = `feature/1073-concurrent-agent-probe`

### (f) Every `## Assumptions` bullet, re-measured

The spec carries six `## Assumptions` bullets. Each is addressed below, in the spec's own order.

1. **RELAYED — issue #277's precondition list and issue #274's isolation item.** Re-fetched directly by this role via `https://api.github.com/repos/RipsawJP/shell-team/issues/277` and `.../274` (public, unauthenticated GET). **#277** ("Width-axis Stage 0…"), state `open`, confirmed: its own body names precondition 2 as "verify empirically that the harness runs N concurrent Agent-tool sub-agent invocations from one orchestrator session — shared precondition with #274," exactly the premise this task discharges. **#274** ("Concurrency Stage 0…"), state `open`, confirmed: its own body names the identical shared precondition, plus the six-plus-one contract surfaces and the 2+ concurrent-worktree reconcile design as its own remaining Stage 0 items, none of which this task touches. No criterion in this spec depends on any figure or wording from either issue; both are used only as identifiers in `## Implications for T-1074`.
2. **MEASURED false, recorded as a hand-off finding — the agent-definition count.** Already corrected in the spec's own text and in `.shell-team/interventions/T-1073.md` (the orchestrator's own committed entry, confirmed present and conformant: `bash bin/check-interventions.sh --task T-1073 -- .shell-team/interventions/T-1073.md` reports conformant, 1 entry, 0 sentinel) — nine `agents/*.md` files, not one carrying an `Agent`/`Task` token. Re-confirmed by this engineer: `ls agents/*.md | wc -l` → `9`.
3. **RELAYED — the operator's watchdog script.** `agent-watchdog.sh` lives under the operator's own home dotfiles, outside this repository and outside this role's readable working directories; its existence, alert format and the exact `WATCHDOG-ALERT` token are relayed via the committed probe evidence, not independently re-read from the script's own source by this engineer (this role has no access to the operator's home directory). Recorded home-relative throughout this note, never as a home-directory absolute path (**AC13**).
4. **RELAYED — `f8371eb` as `feature/1072-telemetry-span-discriminator`'s tip and PR #286.** Re-measured directly: `git rev-parse feature/1072-telemetry-span-discriminator` = `f8371eb6a26b395c020ee7811087150059d33c15`, matching the relayed short form exactly (item (e) above).
5. **RELAYED and deliberately untested-as-fact — the harness documentation's concurrent-tool-uses claim.** Named explicitly as the claim under test in `## Agent-type boundary`'s `- claim-under-test:` line, never cited as evidence; this task's own measured overlap is the independent evidence, per the spec's own design.
6. **UNVERIFIED from this role — the clock source.** Verified live by the probe (not by this engineer, who cannot run one): `## Probe evidence`'s "Clock-source verification" records `python3-time_ns` expanding to 19 digits, and a GNU `date +%s%N` also expanding on this PATH — the BSD-`date` literal-`N` hazard did not occur, disclosed rather than assumed away.

The seventh bullet ("Assumed and stated — bash integer width") is not itself relayed, so
it is not re-derived here; its outcome is what this note's own "never `awk`/`sort -n`"
discipline already states throughout `## Overlap analysis`, applied consistently.

### (g) Per-source report — every `## Summarized sources` entry

The spec carries seven `## Summarized sources` bullets. Each is addressed below.

1. **`docs/loop-engineering/agent-concurrency.md`** — opened and read (lines 110–170 targeted, per the spec's own five distinctions). Confirmed: the `absent`-is-scoped distinction (line 120), the `declined` pilot probe's own two-round pre-commitment firing (line 131), the four carried-forward requirements (line 154), the Limits entry's own "not verified" wording (line 162), and the Bash-level-only scoping of `background-agent-launch`/`completion-notification` (lines 119/121). Nothing contradicted; this task's own `## Supersession and follow-ups` section supersedes lines 120/162 precisely as scoped, never flattening `absent`'s own qualification into a blanket "the note said it was missing."
2. **`docs/loop-engineering/phase-multiplexing.md`** — opened and read (lines 40–90 and 155–184 targeted). Confirmed: the shell-process unit at line 54 (`bash bin/check-acs.sh <spec>` — the identical unit reused here), the five-condition measured-label discipline (lines 76–84, this task's own six-condition licence-condition shape copies its structure), the shell-process-only scoping of the `staged-adoption` recommendation (line 170), and issue #274 item 7's own status as an issue-only contract surface (line 45). Nothing contradicted.
3. **`.shell-team/specs/T-1069-phase-multiplexing.md` lines 111–123** — opened and read first-hand. Confirmed: the presence-and-structure criteria discipline (no criterion re-derives an analysis conclusion or compares against a live growing corpus — this spec's own AC1–AC15 follow the identical shape); the exactly-one-per-id/total-equals-grammar-matching-total coupling shape (this task's own **AC5**/**AC6**/**AC9**/**AC10** reuse it); and the `git worktree add` venue bar (this task's own **AC4** inherits it verbatim). Nothing contradicted.
4. **`.shell-team/specs/T-1072-telemetry-span-discriminator.md` lines 1–164** — opened and read first-hand. Confirmed: the single-branch-point-discriminator convention (reused here verbatim); its own **AC16** as a merge-point-scoped scope-lock allow-list (confirmed genuinely newly reddened by this task, item (d) above); and the `--instance` grammar (`BINDING_TOKEN_RE`, writer-only validation, bare-numeric refusal) which is why this spec's own probe instance labels are `probe-a`…`probe-d` (plus `probe-stall`, also a legal token under `^[a-z][a-z0-9-]*$`). Nothing contradicted.
5. **`bin/log-run.sh`** — read by targeted grep (lines 21–306 per the spec's own citation). Confirmed: `--instance` in `SPAN_ONLY_FLAGS`, validated against `BINDING_TOKEN_RE='^[a-z][a-z0-9-]*$'` — `probe-a` through `probe-d` and `probe-stall` all match; `--status`'s closed five-value set; `--span`/`--phase` carrying no closed vocabulary. Nothing contradicted; this is exactly the emission path the probe's own span rows (`## Overlap analysis`, channel ③) used.
6. **`agents/*.md` frontmatter `tools:` lines, all nine** — re-confirmed by this engineer (`ls agents/*.md | wc -l` → `9`; `grep -l 'Agent\|Task' agents/*.md` inside each file's own `tools:` line returns no match across all nine, re-derived independently of the spec's own authoring-time claim). Nothing contradicted; this is the structural reason the probe had to be an orchestrator step.
7. **`bin/team-paths.sh`**, **`bin/check-intent.sh`**, **`bin/check-acs.sh`**, **`.shell-team/todo.md`** — each read as cited by the spec (lines 37/68/194 for team-paths; 84–107/293–332 for check-intent; 6–41/120/141/224–234 for check-acs; 1–45 for the board). Confirmed: the ten-key closed set `team-paths.sh --get` resolves; `--print-hash`'s single 40-hex-plus-LF stdout contract; whole-line marker matching scoped by task id; `check-acs.sh`'s first-check-line-only execution and 120s-default/`CHECK_ACS_TIMEOUT`-override timeout; and the board's strict `- [ ] **T-NNN** …` line format, this task's `#277`/`#285` anchors, and the house shape for a task's board sub-bullets. Nothing contradicted.

### (h) Probe execution conditions, restated for the record

- Clock source actually used: `python3 -c 'import time; print(time.time_ns())'` (`time.time_ns()`), verified expanding to a 19-digit integer (`1786784078174650000`) before reliance; a GNU `date +%s%N` was also confirmed expanding on the same PATH, and the python source was used uniformly regardless, for consistency across the orchestrator's own timestamps and every probe agent's own report.
- Logical core count: 8 (`os.cpu_count()`; `sysctl` is denied in this sandbox, so the POSIX-portable Python call stood in for it, disclosed in `## Probe evidence`'s header paragraph rather than silently substituted).
- Every timing figure in this note (launch latencies, overlap margins, batch/sum durations, watchdog thresholds, heartbeat samples) is machine-local, single-session, and carries no git-ref label anywhere — the only ref-labelled reads in this note are of committed blobs (the branch point, the freeze commit, the probe-evidence commit), each read via `git merge-base`/`git rev-parse`/`git show`, never via a timing claim.
