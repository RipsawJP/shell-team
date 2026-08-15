# Harness Agent-tool concurrency — the T-1073 probe

This note is assembled in two stages by two different actors, per the frozen spec
(`.shell-team/specs/T-1073-harness-agent-concurrency.md`): the section
`## Probe evidence (raw, orchestrator-produced)` below was written and committed by the
orchestrator session that executed the probe, before the engineer was invoked, and is
byte-frozen from that commit onward; every other section is the engineer's assembly
from this evidence.

## Probe evidence (raw, orchestrator-produced)

All timestamps are machine-local, from `python3 -c 'import time; print(time.time_ns())'`
(`time.time_ns()`), on the same host and session; no timing figure below is a property
of any git ref. Timestamps are integers of digits only, nanoseconds since the epoch.
Probe date: 2026-08-15 (UTC times shown where ISO was captured). Logical CPU count
(via `python3 -c 'import os; print(os.cpu_count())'`; `sysctl` is denied in this
sandbox): 8.

### Clock-source verification

- `python3 -c 'import time; print(time.time_ns())'` → `1786784078174650000` (expanded, 19 digits) — used as the probe's clock source everywhere (`clock_source=python3-time_ns` on every agent line).
- `date +%s%N` on the orchestrator's PATH → `1786784078181248000` (expanded — this PATH resolves a GNU date; the BSD-`date` literal-`N` hazard the protocol names did not occur here, and the python source was used regardless for uniformity across orchestrator and agents).

### Venue and population fixation (before any arm ran)

- Venue: throwaway `git clone --no-hardlinks` of the checkout into `$TMPDIR/t1073-probe-clone`, then `git checkout <branch-point>`; pinned HEAD verified: `f8371eb6a26b395c020ee7811087150059d33c15` (equals `git merge-base feature/1072-telemetry-span-discriminator HEAD`). No `git worktree add` anywhere.
- Candidate unit timings measured in the clone, single runs, `CHECK_ACS_TIMEOUT=280`, before any arm:
  - `T-1041-freeze-ux`: rc=1, 20382 ms
  - `T-1019-is-span-row-parity`: rc=1, 3705 ms
  - `T-1056-loop-liveness`: rc=1, 29239 ms
  - `T-1044-test-infra-bundle`: rc=1, 147968 ms
- Population decision, frozen before the arms: unit = `bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md` for every timing arm and every agent (uniform ~148 s duration maximizes overlap detectability; 148 s exceeds 3× any plausible launch latency and sits below the healthy-arm watchdog threshold of 5 min). `unit_rc=1` is expected and honest: several merged merge-point-scoped scope locks are stale at this branch point; the unit is the run, not its verdict.
- The unit's own `mktemp` scratch lands under each agent's `$TMPDIR` (outside the clone): this is the unit's shipped behavior; the frozen sentence's measured form — checkout cleanliness — is what was verified (below) and it passed.

### Arms — verbatim agent report lines

Each line is the probe agent's own final report, copied verbatim from its completion
notification. Launch mechanics: each arm's agents were launched as parallel `Agent`
tool calls inside ONE orchestrator message (`subagent_type=general-purpose`,
`model=haiku` for every probe agent); the harness's own documentation sentence about
concurrent tool uses is the claim UNDER TEST here, never evidence.

`serial-baseline-n1` (t0 = 1786784393330284000 / 2026-08-15T08:59:53Z; t_launched = 1786784418351271000):

```
instance=probe-a arm=serial-baseline-n1 start_ns=1786784414175422000 end_ns=1786784575527858000 start_iso=2026-08-15T09:00:14Z end_iso=2026-08-15T09:02:55Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle
note=unit-was-auto-backgrounded-by-120s-tool-timeout end_ns_includes_wait=true
```

`pair-n2-rep1` (t0 = 1786784596227738000 / 2026-08-15T09:03:16Z; t_launched = 1786784630784571000):

```
instance=probe-a arm=pair-n2-rep1 start_ns=1786784620133157000 end_ns=1786784799450775000 start_iso=2026-08-15T09:03:42Z end_iso=2026-08-15T09:06:41Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=pair-n2-rep1 start_ns=1786784624672359000 end_ns=1786784802250982000 start_iso=2026-08-15T09:03:46Z end_iso=2026-08-15T09:06:43Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`pair-n2-rep2` (t0 = 1786784826464977000 / 2026-08-15T09:07:06Z; t_launched = 1786784850739686000):

```
instance=probe-a arm=pair-n2-rep2 start_ns=1786784843168204000 end_ns=1786785018787015000 start_iso=2026-08-15T09:07:23Z end_iso=2026-08-15T09:10:18Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=pair-n2-rep2 start_ns=1786784847472203000 end_ns=1786785023274966000 start_iso=2026-08-15T09:07:29Z end_iso=2026-08-15T09:10:25Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`width-n4` (t0 = 1786785044662467000 / 2026-08-15T09:10:44Z; t_launched = 1786785078782962000):

```
instance=probe-a arm=width-n4 start_ns=1786785060762436000 end_ns=1786785325794710000 start_iso=2026-08-15T09:11:00Z end_iso=2026-08-15T09:15:26Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-b arm=width-n4 start_ns=1786785065628612000 end_ns=1786785335601045000 start_iso=2026-08-15T09:11:08Z end_iso=2026-08-15T09:15:37Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-c arm=width-n4 start_ns=1786785069887498000 end_ns=1786785339952703000 start_iso=2026-08-15T09:11:11Z end_iso=2026-08-15T09:15:41Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
instance=probe-d arm=width-n4 start_ns=1786785077172030000 end_ns=1786785343815298000 start_iso=2026-08-15T09:11:17Z end_iso=2026-08-15T09:15:44Z unit_rc=1 clock_source=python3-time_ns unit=check-acs:T-1044-test-infra-bundle foreground=true
```

`negative-control-stall` (t0 = 1786785373602465000 / 2026-08-15T09:16:13Z; t_launched = 1786785395470372000; the agent's quiet period is a bounded `python3 -c 'import time; time.sleep(200)'` that ends on its own — no TaskStop, no kill, anywhere in this probe):

```
instance=probe-stall arm=negative-control-stall start_ns=1786785390064879000 end_ns=1786785599691392000 start_iso=2026-08-15T09:16:32Z end_iso=2026-08-15T09:20:01Z slept_rc=0 clock_source=python3-time_ns
```

### Watchdog machinery — script semantics (transcribed from the script itself, read in full by the orchestrator this session)

- Script: `agent-watchdog.sh` (host-side operator tooling under the operator's home dotfiles, 87 lines, v5; recorded home-relative — not shipped by this repository and not a deliverable of this task).
- Semantics (from the source, not from memory): 60-second poll loop; args `<transcript-path> [workdir] [static-min] [lifetime-min] [spawn-min]` with defaults 10/45/8 (minutes); transcript size read via `stat -L` (symlink-dereferencing — the v5 fix); a second signal (workdir mtime scan, `.git` pruned) suppresses the alert when the work tree is active; exits: 0 = lifetime reached without stall or transcript gone, 1 = `WATCHDOG-ALERT(<spawn|working>)` (transcript static ≥ threshold minutes AND no workdir activity), 2 = usage, 3 = `WATCHDOG-ERROR` (instrument failure, not a stall).
- Healthy-arm invocations (verbatim shape, one per probe agent, launched as a harness-tracked background Bash immediately after each arm's launch): `bash ~/.claude-dotfiles/scripts/agent-watchdog.sh <that-agent's-transcript.output> "" 5 20 5`
- Negative-control invocation (verbatim shape): `bash ~/.claude-dotfiles/scripts/agent-watchdog.sh <probe-stall-transcript.output> "" 2 10 2`
- Final dispositions (closed vocabulary {stopped-after-completion, alert-observed}): every healthy-arm watchdog ran alert-free while its agent worked and was stopped via TaskStop only AFTER that agent's completion notification arrived → `stopped-after-completion` ×9. The negative-control watchdog → `alert-observed` (below).

### Watchdog liveness — heartbeats read by the parent INSIDE the running windows

Each heartbeat is one orchestrator Bash call that took a timestamp and then `stat -L`'d
the still-running agents' transcripts and the watchdogs' own output files — i.e. the
parent multiplexing over both signal sources before any completion notification.

- `pair-n2-rep1`: hb1 = 1786784650599466000 (both transcripts present and grown: 46564 B mtime 18:03:46, 44106 B mtime 18:03:50; both watchdog outputs read, size 0 = polling); hb2 = 1786784667052716000 (same reads repeated). Both heartbeats sit inside [max(start_ns)=1786784624672359000, min(end_ns)=1786784799450775000].
- `pair-n2-rep2`: hb1 = 1786784864882826000; hb2 = 1786784876021630000 (transcripts 42038 B / 43732 B; both watchdog outputs read). Both inside [1786784847472203000, 1786785018787015000].
- `width-n4`: hb1 = 1786785097595603000 (all four transcripts present and grown: 41783/43192/43905/41583 B, mtimes 18:11:04–18:11:20; all four watchdog outputs read); hb2 = 1786785108123055000. Both inside [1786785077172030000, 1786785325794710000].
- The transcripts being static between hb1 and hb2 is expected and correct: each agent's ~148 s unit is a single foreground Bash call, during which its transcript does not grow — exactly the quiet period the watchdog's threshold must tolerate on healthy arms (5 min > ~2.5 min) and must NOT tolerate on the negative control (2 min < 200 s sleep).

### Negative control — a real alert, observed by the parent while the agent was still quiet

- Alert (verbatim, from the watchdog's output file, delivered to the parent as the background task's failure notification at parent-observation timestamp 1786785524355587000 / ≈09:18:44Z):

```
WATCHDOG-ALERT(spawn): transcript static at 44143 bytes for 2 min AND no recent workdir activity — agent may be stalled: <probe-stall transcript path>
next: VERIFY workdir file mtimes yourself before any destructive step; then SendMessage nudge; TaskStop ONLY if both signals stay dead after the nudge.
```

- The observation timestamp sits INSIDE the stalled agent's own window [1786785390064879000, 1786785599691392000]: the parent received and read a genuine stall alert while the agent was still running — the structural property whose absence defeated the sibling task's probe (a watchdog whose only reportable outcome was `exited-normally`). Per the arm's design, no intervention followed: the sleep was bounded and the agent exited naturally (`slept_rc=0`).

### Execution-detail findings (recorded for the assembly and for successors)

1. A watchdog launched with shell `&` inside a foreground Bash tool call is killed the moment that call exits (measured: pid dead, log empty, within seconds). The only surviving launch path in this harness is a harness-tracked background Bash (`run_in_background`), which is how all ten probe watchdogs ran.
2. A sub-agent's default foreground Bash timeout is 120 s: the n1 agent's ~148 s unit was auto-backgrounded by its own harness, so its `end_ns` includes wait-loop granularity (disclosed on its report's `note=` line). Every later agent was instructed to set its Bash timeout parameter to 400000 ms and every one reported `foreground=true` — a fan-out implementation must pass an explicit per-call timeout when a unit exceeds 120 s.
3. `sysctl` is denied in this sandbox; core count came from `os.cpu_count()`.

### Post-probe cleanliness verification (the frozen sentence's measured form)

At 1786785633306509000, in the real checkout: `git status --short` → empty; `git ls-files --others --exclude-standard` → empty.

- probe-writes: none — no probe agent wrote to the real checkout or emitted telemetry; the ten span rows for the ten agent invocations were emitted sequentially by the orchestrator after the completion notifications (channel ③), tagged `--instance probe-a|probe-b|probe-c|probe-d|probe-stall`, into the machine-local runs file.
