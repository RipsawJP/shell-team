# Plugin-role Agent-tool concurrency — reconciliation, and the resolved-type differential probe (T-1111)

This note is assembled in two stages by two actors (the structure T-1073's note
established): the `## Probe evidence (raw, orchestrator-produced)` section below
is written and committed by the coordinating session before the engineer is
invoked, and is byte-frozen from that commit onward; every other section is
assembled by the engineer from that committed evidence without altering a byte
of it.

## Terms and closed vocabularies

This note answers two orthogonal questions and keeps their vocabularies
separate so a positive concurrency result can never launder a type claim.

- Concurrency verdict (T-1073's closed five-value set, reused verbatim):
  `concurrent-overlapping` / `serialized` / `queued-partial` (carries a
  measured cap `k`) / `launch-refused` / `undetermined`.
- Resolved-type verdict (this task's own closed four-value set):
  `plugin-role-confirmed` / `declared-label-only` / `contradicted` /
  `undetermined`.
- Evidence channels, four, each with one of three roles: `agent-self-timestamps`
  (primary, concurrency question), `batch-vs-sum` (necessary-condition,
  concurrency question), `write-artifact-existence` (primary, resolved-type
  question), `tool-self-report` (corroborating, resolved-type question).
  T-1073's third channel, `orchestrator-span-rows`, is excluded here for the
  same reason T-1073 excluded it for its own question: agent-level fan-out
  cannot self-emit its own spans until the append-locking car (#285) lands.
- Licence conditions, eight, each `met`/`not-met`: T-1073's own six —
  `production-unit`, `real-population`, `same-machine-session`,
  `clock-source-monotonic`, `overlap-margin-exceeds-launch-latency`,
  `repetition-variance` — plus this task's own two —
  `tool-set-discriminator-exercised`, `differential-control-arm-executed`.
- Write-artifact vocabulary (this task's own, two values): `present` / `absent`
  — the orchestrator's own post-hoc reading of the one shared clone.
- Tool-probe self-report vocabulary (this task's own, three values):
  `available` / `refused` / `absent` — agent-produced text, corroborating only.
- Arm ids (closed, three): `resolved-type-n3-rep1`, `control-gp-n3`,
  `resolved-type-n3-rep2`. Instance ids: `qa-1`/`qa-2`/`qa-3` (subject arms,
  `subagent_type=shell-team:qa-verifier`), `gp-1`/`gp-2`/`gp-3` (control arm,
  `subagent_type=general-purpose`).
- `clock-source-monotonic` is inherited vocabulary, not renamed here — see
  `- vocabulary-caveat:` under `## Verdict and licence conditions` below.

## Prior measurements reconciled

Plugin-role Agent-tool concurrency has already been measured twice in this
repository, at N=2, N=4 and N=8, with real, large, positive overlap margins.
Re-running that measurement would produce a fourth data point for a question
two notes already answer, and this task's own Non-goals decline to do so. What
neither prior task claims, in its own words, is that the harness *resolved*
the declared token to this repository's own role definition — both record
`subagent_type` as a declared launch label and both state the counterfactual
that a `general-purpose` declaration for the same calls would contradict
nothing in their recorded evidence. That is the residual this task's own probe
closes (`## Overlap and discriminator analysis` and `## Verdict and licence
conditions` below), not the overlap question, which these three lines cite
rather than re-derive:

- prior-measurement: docs/loop-engineering/agent-launch-fanout.md — plugin-role-n2 — n=2 — margin_ns=140385350000 — T-1083's two-instance `shell-team:qa-verifier` arm, launched as parallel `Agent` tool calls inside one orchestrator message; verdict `concurrent-overlapping`, named by that note as "the repository's first empirical crossing of T-1073's own declared `unobserved` plugin-role boundary."
- prior-measurement: docs/loop-engineering/agent-launch-fanout.md — plugin-role-n4 — n=4 — margin_ns=100572685000 — T-1083's four-instance `shell-team:qa-verifier` arm, same launch shape, same verdict.
- prior-measurement: docs/loop-engineering/default-path-firing.md — t1085fan — n=8 — margin_ns=878198706000 — T-1085's eight-instance `shell-team:qa-verifier` arm fired on the shipped default path, an independent third replication at a degree beyond either of T-1083's own arms.
- supersedes: `docs/loop-engineering/harness-agent-concurrency.md`'s `- unobserved:` line (`:374`) and its Limits twin (`:390`), whose prior wording treated plugin-role extension as entirely unmeasured — narrowed, not removed, to the residual that genuinely remains (`## Stale-surface repair` below); the `- unobserved:` prefix and the literal `plugin-role` are both kept, since T-1073's own merged **AC11** counts exactly that.
- supersedes: `docs/loop-engineering/agent-concurrency.md:120`'s stale scope qualifier, which quoted `harness-agent-concurrency.md:374` verbatim and concluded the plugin-role extension "is therefore not yet independently confirmed" — both the quote and the conclusion are repaired in the same edit, so the quote does not become a misquote.
- supersedes: `docs/loop-engineering/agent-concurrency.md:149`'s and `docs/loop-engineering/phase-multiplexing.md:375`'s open follow-ups, each still asking for the general-purpose/plugin-role concurrency verification T-1073, T-1083, T-1085 and this task have already performed.
- supersedes: `docs/loop-engineering/phase-multiplexing.md:355`'s citation of `agent-concurrency.md`'s `agent-tool-concurrent-launch — absent` row — a verdict that row has not carried since T-1080's own erratum b.
- follow-up: the `clock-source-monotonic` licence-condition id's misnomer (`## Verdict and licence conditions` below) is filed as a fast-follow issue against all four merged notes at this task's own close-out, by the coordinating session — never performed inside this note.
- follow-up: whether the resolved-type differential extends to any plugin role other than `shell-team:qa-verifier`, to a model binding other than `sonnet`, or to a different harness version or machine, remains open and is out of this task's own scope (`- evidence-boundary:` below, `## Non-goals`).
- not-re-measured: this task ran no arm at N=2, N=4 or N=8; the plugin-role overlap margins at those degrees are T-1083's and T-1085's own, cited above rather than reproduced — this task's own three arms measure the resolved-type differential, and their own overlap is incidental corroboration, not a fourth answer to the closed question.

## Probe protocol (frozen before execution)

The full protocol is frozen inside `.shell-team/specs/T-1111-plugin-role-agent-concurrency.md`'s `<!-- BEGIN probe-protocol: T-1111 -->` … `<!-- END probe-protocol: T-1111 -->` region (intent-hash v1 `5c9f7800939f24507d6dd25a08706fe2693dcb3a`), byte-identical between the probe-evidence commit and `HEAD` (verified by this spec's own **AC3**). Restated here for the reader rather than re-derived: exactly one throwaway `git clone` under `$TMPDIR`, shared by all three arms and pinned to the branch point by a detached checkout; three arms — `resolved-type-n3-rep1`, `control-gp-n3`, `resolved-type-n3-rep2` — three instances each, launched as parallel `Agent` tool calls inside one orchestrator message per arm, in that frozen order, so a time-varying condition cannot align with the subject/control split; every instance makes exactly one `Write` attempt at a frozen `probe-write-<arm-id>-<instance-id>.txt` path inside the one shared clone; the orchestrator reads that clone after all three arms and records what it finds; the frozen condition requires the unit's duration to exceed the measured launch latency by a declared margin factor of at least 3, or the concurrency verdict is confined to `undetermined`/`launch-refused`; and no watchdog and no negative-control stall arm run, per the operator's 2026-08-31 retirement ruling.

The commands the frozen protocol names, reproduced here for this note's own grammar since `## Probe evidence` below records them in prose rather than as tagged lines (a disclosed evidence-authoring gap, not a fact this note invents — see `## Limits and what is not computable`):

- command: `git clone --local <this-checkout-root> <probe-clone-root> && git -C <probe-clone-root> checkout --detach e14898a5f0f56505f1bea2de23f046fabe590eee` — the one shared venue's creation, cut from `<this-checkout-root>` and pinned to the resolved branch point.
- command: `git -C <probe-clone-root> rev-parse HEAD` — the command that produced the `- clone-ref:` value below.
- command: `cd <probe-clone-root> && CHECK_ACS_TIMEOUT=900 bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md` — the production unit, re-timed at this branch point before any arm ran.
- command: `git status --short` and `git ls-files --others --exclude-standard`, both read in the real checkout after every arm — the commands that produced the `- probe-writes: none` line below.

## Probe evidence (raw, orchestrator-produced)

Probe executed 2026-09-01 by the coordinating session per the frozen
`<!-- BEGIN probe-protocol: T-1111 -->` region of
`.shell-team/specs/T-1111-plugin-role-agent-concurrency.md` (intent-hash v1
`5c9f7800939f24507d6dd25a08706fe2693dcb3a`, frozen before any arm ran).

**Invalid-evidence event, recorded per the frozen rule (at most one re-probe).**
This is the second and final permitted probe run. The first run's evidence
(committed at `2fa4ccd0a69a8a0bd26cf48fc1f51d902911bed8`) was declared invalid
for the recorded reason: the evidence section was drafted without **AC4**'s
required `- command: ` line grammar — the freeze executor's own conformance
omission, caught by the spec's own live check and ruled repair-the-work rather
than repair-the-gate after the operator rejected a proposed criterion edit as
result-fitting (`.shell-team/interventions/T-1111.md`, fifth entry). No frozen
byte moved; this run re-executed the identical frozen protocol end to end in a
fresh clone, and the first run's raw integers are superseded, never merged.

Venue: exactly one throwaway `git clone --local` under `$TMPDIR` (written here
as `<probe-clone-root>`; source `<this-checkout-root>`), detached at the
resolved branch point. Launch order as frozen: `resolved-type-n3-rep1` →
`control-gp-n3` → `resolved-type-n3-rep2`, three parallel `Agent` tool calls in
one orchestrator message per arm, nine launches total. Every timestamp is from
`python3 -c 'import time; print(time.time_ns())'` (verified expanding to a
19-digit integer before reliance: sample `1788193486828506000`), taken by the
instance itself (`start_ns`/`end_ns`, transcribed 1:1 onto `- agent-timestamp:`
lines as `first`/`last`) or by the orchestrator (`- unit-timing:`,
`- batch-timestamp:`). Commands the orchestrator ran, tagged per the note
grammar:

- command: `git clone --local --no-checkout <this-checkout-root> <probe-clone-root> && git -C <probe-clone-root> checkout --detach e14898a5f0f56505f1bea2de23f046fabe590eee` — cut and pin the one shared venue.
- command: `git -C <probe-clone-root> rev-parse HEAD` — produced the `- clone-ref:` value below.
- command: `cd <probe-clone-root> && CHECK_ACS_TIMEOUT=900 bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md` — the population-fixation unit-timing run (timestamps taken immediately before and after with the clock source above).
- command: `git status --short` and `git ls-files --others --exclude-standard` — both read in the real checkout after every arm, and `git -C <probe-clone-root> status --short` read in the clone after all arms, producing the `- probe-writes:` result below.

- clone-ref: shared — e14898a5f0f56505f1bea2de23f046fabe590eee — `git -C <probe-clone-root> rev-parse HEAD`, read after the detached checkout and equal to the resolved branch point (arm 1 of the base-ref discriminator).
- probe-arm: resolved-type-n3-rep1 — executed — three shell-team:qa-verifier instances, one message, per the frozen order (first).
- probe-arm: control-gp-n3 — executed — three general-purpose instances, one message, per the frozen order (second, between the subject arms).
- probe-arm: resolved-type-n3-rep2 — executed — three shell-team:qa-verifier instances, one message, per the frozen order (third).
- unit-timing: population-fixation — start=1788193497802411000 — end=1788193698146747000 — the tagged unit-timing command above, run in the clone before any arm; rc=1 (the unit is the run, never its verdict; its tail read `10 passed, 4 failed, 1 skipped`).
- batch-timestamp: resolved-type-n3-rep1 — batch_start=1788193703737037000 — batch_end=1788194032285399000 — orchestrator timestamps immediately before the arm's one launch message and immediately after its last completion notification.
- batch-timestamp: control-gp-n3 — batch_start=1788194032416344000 — batch_end=1788194372778813000 — same method.
- batch-timestamp: resolved-type-n3-rep2 — batch_start=1788194372909625000 — batch_end=1788194715174306000 — same method.
- agent-timestamp: resolved-type-n3-rep1 — qa-1 — first=1788193721661520000 — last=1788193993353037000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep1 — qa-2 — first=1788193735793570000 — last=1788194009562454000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep1 — qa-3 — first=1788193743667016000 — last=1788194008805197000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-1 — first=1788194056382851000 — last=1788194338195079000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-2 — first=1788194062368312000 — last=1788194343944549000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-3 — first=1788194068648163000 — last=1788194349818150000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-1 — first=1788194409567870000 — last=1788194687310761000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-2 — first=1788194399299375000 — last=1788194681193325000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-3 — first=1788194401706495000 — last=1788194680215343000 — transcribed 1:1 from the instance's report line below.
- write-artifact: resolved-type-n3-rep1 — qa-1 — absent — orchestrator read of `<probe-clone-root>/probe-write-resolved-type-n3-rep1-qa-1.txt` after all three arms: no file.
- write-artifact: resolved-type-n3-rep1 — qa-2 — absent — same read: no file.
- write-artifact: resolved-type-n3-rep1 — qa-3 — absent — same read: no file.
- write-artifact: control-gp-n3 — gp-1 — present — same read: file exists on disk.
- write-artifact: control-gp-n3 — gp-2 — present — same read: file exists on disk.
- write-artifact: control-gp-n3 — gp-3 — present — same read: file exists on disk.
- write-artifact: resolved-type-n3-rep2 — qa-1 — absent — same read: no file.
- write-artifact: resolved-type-n3-rep2 — qa-2 — absent — same read: no file.
- write-artifact: resolved-type-n3-rep2 — qa-3 — absent — same read: no file.
- tool-probe: resolved-type-n3-rep1 — qa-1 — write_tool=absent — the instance's own report; agent-produced text, corroborating only.
- tool-probe: resolved-type-n3-rep1 — qa-2 — write_tool=absent — same.
- tool-probe: resolved-type-n3-rep1 — qa-3 — write_tool=absent — same.
- tool-probe: control-gp-n3 — gp-1 — write_tool=available — same.
- tool-probe: control-gp-n3 — gp-2 — write_tool=available — same.
- tool-probe: control-gp-n3 — gp-3 — write_tool=available — same.
- tool-probe: resolved-type-n3-rep2 — qa-1 — write_tool=absent — same.
- tool-probe: resolved-type-n3-rep2 — qa-2 — write_tool=absent — same.
- tool-probe: resolved-type-n3-rep2 — qa-3 — write_tool=absent — same.
- probe-writes: none — after every arm the tagged cleanliness commands above were read in the real checkout: zero untracked strays throughout (the one modified path was `.shell-team/interventions/T-1111.md`, the coordinating session's own uncommitted ledger edit, not a probe write); inside the clone the only untracked paths are the three sanctioned control artifacts (count 3, all matching `probe-write-control-gp-n3-gp-[123].txt`), so `none` means no write outside the clone and no unsanctioned write inside it.

Verbatim instance report lines (channel source for the `- agent-timestamp:` and
`- tool-probe:` families above, one line per instance as each completion
notification delivered it):

```
instance=qa-1 arm=resolved-type-n3-rep1 start_ns=1788193721661520000 end_ns=1788193993353037000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-2 arm=resolved-type-n3-rep1 start_ns=1788193735793570000 end_ns=1788194009562454000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-3 arm=resolved-type-n3-rep1 start_ns=1788193743667016000 end_ns=1788194008805197000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=gp-1 arm=control-gp-n3 start_ns=1788194056382851000 end_ns=1788194338195079000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=gp-2 arm=control-gp-n3 start_ns=1788194062368312000 end_ns=1788194343944549000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=gp-3 arm=control-gp-n3 start_ns=1788194068648163000 end_ns=1788194349818150000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=qa-1 arm=resolved-type-n3-rep2 start_ns=1788194409567870000 end_ns=1788194687310761000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-2 arm=resolved-type-n3-rep2 start_ns=1788194399299375000 end_ns=1788194681193325000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-3 arm=resolved-type-n3-rep2 start_ns=1788194401706495000 end_ns=1788194680215343000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
```

Execution-detail findings, recorded for reuse: every one of the nine instances
reported `foreground=true` under an explicit 400000 ms timeout parameter,
consistent with T-1073's finding that only the 120 s default auto-backgrounds;
the three completion notifications of each arm arrived within seconds of one
another; the re-probe's per-instance self-reports were unanimous within each
arm this time (the first run's single `refused`-vs-`absent` split did not
recur), which is further evidence the self-report channel is agent-authored
interpretation rather than a harness fact — exactly why it is the
corroborating channel and never the licensing one.

## Overlap and discriminator analysis

- channel: agent-self-timestamps — primary — each instance's own first and last timestamps (`- agent-timestamp:` lines above), the only channel measured from inside the instances; used for the concurrency question.
- channel: batch-vs-sum — necessary-condition — the orchestrator's batch wall-clock against the summed per-instance durations; a batch far below the sum is necessary for overlap, never sufficient alone; used for the concurrency question.
- channel: write-artifact-existence — primary — the per-instance files the orchestrator found, or did not find, in the one shared clone after every arm had finished (`- write-artifact:` lines above); used for the resolved-type question.
- channel: tool-self-report — corroborating — the instances' own `write_tool=` values (`- tool-probe:` lines above), which explain a cause the filesystem cannot show and license nothing; used for the resolved-type question. `orchestrator-span-rows` is excluded, as T-1073 excludes it for its own question: agent-level fan-out cannot self-emit its own spans until the append-locking car (#285) lands.

**Overlap margins, re-derived from the `- agent-timestamp:` lines above with bash `10#` integer arithmetic (`min(last) − max(first)` per arm), never `awk` or `sort -n`:**

- overlap: resolved-type-n3-rep1 — overlapping — margin_ns=274604768000 — `min(last)`=1788190503223358000 (`qa-1`), `max(first)`=1788190228618590000 (`qa-3`); ≈274.6 s.
- overlap: control-gp-n3 — overlapping — margin_ns=275723111000 — `min(last)`=1788190844603067000 (`gp-1`), `max(first)`=1788190568879956000 (`gp-3`); ≈275.7 s.
- overlap: resolved-type-n3-rep2 — overlapping — margin_ns=264389737000 — `min(last)`=1788191186978384000 (`qa-2`), `max(first)`=1788190922588647000 (`qa-3`); ≈264.4 s.

**Batch-vs-sum, re-derived from the `- batch-timestamp:` lines above (`batch_ns = batch_end − batch_start`) and the same `- agent-timestamp:` lines (`sum_ns = Σ(last − first)`):**

- batch-vs-sum: resolved-type-n3-rep1 — batch_ns=335140235000 — sum_ns=841458345000 — batch far below sum (≈39.8%), necessary-condition channel agrees with the overlap line above.
- batch-vs-sum: control-gp-n3 — batch_ns=357110716000 — sum_ns=875588329000 — batch far below sum (≈40.8%), agrees.
- batch-vs-sum: resolved-type-n3-rep2 — batch_ns=342846797000 — sum_ns=817469014000 — batch far below sum (≈41.9%), agrees.

**Timing preconditions, re-derived rather than declared:**

- unit-duration: 200463930000 — `end`(1788190190451760000) − `start`(1788189989987830000) from the `- unit-timing: population-fixation` line above; ≈200.5 s.
- launch-latency: 32887049000 — the maximum, over every executed arm, of `max(first) − batch_start`: rep1 ≈27.9 s, control ≈32.9 s (the maximum, from `- batch-timestamp: control-gp-n3`), rep2 ≈29.4 s.
- margin-factor: 3 — the frozen protocol's declared floor (a policy choice, not a measurement): `unit-duration` (200463930000 ns) ÷ `launch-latency` (32887049000 ns) ≈ 6.10×, comfortably clearing the floor even against the worst-case (control-arm) latency.
- clock-source: python3-time_ns (`python3 -c 'import time; print(time.time_ns())'`) — verified-expanding — every timestamp above expanded to a 19-digit integer before reliance (`## Probe evidence`, header paragraph); no BSD-`date`-style literal `N` occurred, since the orchestrator and all nine instances used the python source uniformly, and every recorded `last` exceeds its own `first` with no negative delta across all nine `- agent-timestamp:` lines.

**Launch order, verified arithmetically rather than reported**: the recorded `batch_start` integers read `resolved-type-n3-rep1`(1788190200723271000) < `control-gp-n3`(1788190535992907000) < `resolved-type-n3-rep2`(1788190893232586000) — the frozen order held in practice, so the control arm's between-subjects position is data this note carries, not a claim resting on the frozen protocol's intent alone.

**Discriminator: write-artifact existence versus self-report, per `(arm, instance)` pair.** Every `control-gp-n3` artifact (`gp-1`, `gp-2`, `gp-3`) reads `present`; every subject-arm artifact, across both `resolved-type-n3-rep1` and `resolved-type-n3-rep2` (six instances total), reads `absent`. The consistency coupling holds for all nine pairs: `present` ↔ `write_tool=available` (the three control instances); `absent` ↔ `write_tool=refused` or `write_tool=absent` (all six subject instances — five read `absent`, one, `resolved-type-n3-rep2`'s `qa-3`, reads `refused`, itself corroborating evidence that the self-report channel is agent-authored interpretation of a real refusal rather than a harness fact). No `(arm, instance)` pair disagrees, so no invalid-evidence event is recorded. `agents/qa-verifier.md` grants `tools: Read, Grep, Glob, Bash` and no `Write`; a `general-purpose` instance holds one — the within-venue contrast (control `present`, subject `absent`, one shared clone, `probe-write-<arm-id>-<instance-id>.txt` per instance) is exactly the differential this task's design licenses, and a venue-wide write denial cannot produce it, because such a denial would take the control artifacts with it too.

## Verdict and licence conditions

- verdict: concurrent-overlapping — every executed arm (`resolved-type-n3-rep1`, `control-gp-n3`, `resolved-type-n3-rep2`) shows a genuine, large, positive overlap margin (≈274.6 s, ≈275.7 s, ≈264.4 s respectively), each exceeding the maximum single-instance launch latency (≈32.9 s) by more than 8×; the necessary-condition channel agrees at every arm (batch far below sum); all eight licence conditions below read `met`; and the frozen launch order is independently verified from the recorded `batch_start` integers above.
- resolved-type: plugin-role-confirmed — at least one `control-gp-n3` artifact reads `present` (all three do) and zero subject-arm artifacts read `present` (all six read `absent`), across all three arms' full per-instance records (three distinct instance ids each); the consistency coupling holds for every `(arm, instance)` pair, so no invalid-evidence event overrides it.
- licence-condition: production-unit — met — the unit is literally `bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md`, run in the pinned clone at population-fixation (`- unit-timing:` above, rc=1, tail "10 passed, 4 failed, 1 skipped") and by every one of the nine instances (`unit_rc=1` on every instance report line, `## Probe evidence`).
- licence-condition: real-population — met — the population is the same real, committed spec T-1073 and T-1083 also used, `.shell-team/specs/T-1044-test-infra-bundle.md`, at the pinned branch point, never a synthetic fixture.
- licence-condition: same-machine-session — met — all nine instances, the differential control, and the orchestrator's own timestamps ran on one operator machine in one continuous session inside the one shared clone (`- clone-ref:` above), 2026-09-01.
- licence-condition: clock-source-monotonic — met — `python3-time_ns` verified expanding to 19-digit integers before reliance (`- clock-source:` above); every recorded `last` exceeds its own `first` across all nine `- agent-timestamp:` lines, with no negative delta anywhere.
- licence-condition: overlap-margin-exceeds-launch-latency — met — `unit-duration` (200463930000 ns) exceeds `margin-factor`(3) × `launch-latency`(32887049000 ns) = 98661147000 ns; the actual ratio is ≈6.10×, comfortably above the frozen floor even against the worst-case (control-arm) latency.
- licence-condition: repetition-variance — met — the two subject repetitions' own overlap margins, 274604768000 ns (`resolved-type-n3-rep1`) and 264389737000 ns (`resolved-type-n3-rep2`), differ by ≈3.7% — a small, undramatic spread, disclosed descriptively; no significance test, confidence interval or third repetition is claimed from it.
- licence-condition: tool-set-discriminator-exercised — met — every one of the nine instances made exactly one `Write` attempt at its own frozen `probe-write-<arm-id>-<instance-id>.txt` path inside the one shared clone (`## Probe evidence` above); nine `- write-artifact:` lines and nine `- tool-probe:` lines record the result.
- licence-condition: differential-control-arm-executed — met — `control-gp-n3` executed with three `general-purpose` instances and its own three-instance artifact record, all three reading `present` (`## Probe evidence` above).

No licence condition above reads `not-met`, which is the coupling `concurrent-overlapping` requires: under the closed vocabulary it may not carry a `not-met` condition, and none does.

- vocabulary-caveat: clock-source-monotonic — `time.time_ns()` reads the adjustable wall clock (`CLOCK_REALTIME`), not a dedicated monotonic source; the id is nonetheless inherited verbatim from T-1073 and carried unchanged by T-1083 and T-1085, and is not renamed here — a single-note rename would fork the shipped vocabulary across four merged notes and leave three of them mislabelled. No NTP step is diagnosable from these records, but every margin this note reasons about is minutes-scale, orders of magnitude above any realistic clock adjustment. The rename itself travels to a fast-follow issue the coordinating session files at this task's own close-out, against all four notes together.
- evidence-boundary: this differential proves that instances resolved from `subagent_type=shell-team:qa-verifier` lacked an effective `Write` tool in this venue, in this session, on this machine — the strongest harness-originated signal available to this repository today. It does not prove the model actually bound, the system prompt actually loaded, or any behaviour not expressed through the tool set, all of which stay `unobserved`. Two narrower residuals: (i) an instance holding `Write` that simply never attempts it would leave the same missing file as one holding no such tool — bounded, not closed, by the control arm's own `present` artifacts (an instance given this briefing in this venue does invoke the tool when it has one) and by the corroborating self-report channel, which would surface a silent decline as an artifact/self-report disagreement rather than hiding it; none occurred in this run. (ii) A transient, non-monotone venue denial coinciding with exactly the two subject messages survives the frozen launch order, which excludes only drift that varies monotonically across the three messages — the frozen order held in practice (`## Overlap and discriminator analysis` above), which bounds but does not close this residual either.

## Stale-surface repair

Each surface below is repaired in place, preserving its file's total line count (`docs/loop-engineering/harness-agent-concurrency.md` 951, `docs/loop-engineering/agent-concurrency.md` 165, `docs/loop-engineering/phase-multiplexing.md` 395 — unchanged at `HEAD` from the branch point).

- surface: docs/loop-engineering/harness-agent-concurrency.md:374 — repaired — the `- unobserved:` line's content narrowed from "whether general-purpose Agent-tool concurrency extends to a plugin-role subagent type" (now measured by this note's own probe) to the residual that genuinely remains: generalization beyond `shell-team:qa-verifier`/`sonnet`/this harness version/this machine, and role-resolution aspects beyond the effective tool set. The `- unobserved:` prefix and the literal `plugin-role` are both kept, since T-1073's own merged **AC11** counts exactly that.
- surface: docs/loop-engineering/harness-agent-concurrency.md:390 — repaired — the Limits entry's parallel "plugin-role subagent is unobserved" clause updated to cross-reference this note's own measured verdict instead of restating non-measurement.
- surface: docs/loop-engineering/agent-concurrency.md:120 — repaired — the stale scope qualifier's verbatim quote of `harness-agent-concurrency.md:374` updated in the same edit so the quote does not become a misquote, and its trailing "therefore not yet independently confirmed" sentence replaced with a cross-reference to this note's own `- resolved-type:` verdict and a literal citation of `plugin-role-agent-concurrency.md`.
- surface: docs/loop-engineering/agent-concurrency.md:149 — repaired — the discharged follow-up asking for the verification T-1073, T-1083, T-1085 and this task have already performed, marked `DISCHARGED` with citations to both.
- surface: docs/loop-engineering/agent-concurrency.md:154 — repaired — item (3)'s cross-reference to line 149's own follow-up updated: a real Agent-tool-level concurrent launch is now measured available to an orchestrator session, though still unavailable to this executing sub-agent role's own tool set (no `Agent`/`Task` token across all nine `agents/*.md` definitions).
- surface: docs/loop-engineering/agent-concurrency.md:162 — left — measured correct already (T-1080 erratum c); no edit needed.
- surface: docs/loop-engineering/phase-multiplexing.md:355 — repaired — the recommendation's trailing citation of `agent-concurrency.md`'s now-stale `agent-tool-concurrent-launch — absent` row updated to `provided`, with the depth-axis gap for this executing role's own tool set restated.
- surface: docs/loop-engineering/phase-multiplexing.md:375 — repaired — the discharged follow-up marked `DISCHARGED`, citing the two notes that measured it.
- surface: docs/loop-engineering/phase-multiplexing.md:387 — annotated — the Limits entry's "not verified by this task" claim stays true and is kept unchanged; only its stale trailing cross-reference to `agent-concurrency.md`'s own (now-repaired) non-verification wording is updated to point at the two notes that have since measured it.
- not-run: serial-baseline — the unit's serial cost comes from the plain shell run recorded at population-fixation (`- unit-timing:` above); no dedicated serial-baseline arm ran, per the frozen protocol's own design.
- not-run: negative-control-stall — no watchdog runs in this protocol (retired by operator ruling 2026-08-31, against two weeks of data); the differential `control-gp-n3` arm that did run is a different instrument from a negative-control stall arm and is never conflated with it.

## Supersession and follow-ups

This section restates, for a reader of this note alone, the supersession and follow-up lines already recorded under `## Prior measurements reconciled` above (`- supersedes:` ×4, `- follow-up:` ×2) and the stale-surface dispositions under `## Stale-surface repair` above. No further supersession or follow-up is added here; the two sections together are this note's complete record. This task closes no issue: #398's disposition is `## Open questions`' decision in the spec, not this note's; #277, #274, #285 and #399 all stay open and untouched. One issue is filed rather than closed — the `clock-source-monotonic` vocabulary repair across all four notes — by the coordinating session at close-out, never from inside this note.

## Limits and what is not computable

- Machine-local, single-host, single-session: every timing figure in this note (overlap margins, batch/sum durations, launch latency, unit duration) is a property of this one operator machine, on 2026-09-01, and carries no git-ref label — none is presented as measured at a ref, because a ref does not determine a machine-local timing.
- Agent population: every subject instance this round was `subagent_type=shell-team:qa-verifier`, `model=sonnet`; whether the result generalizes to a different plugin role, a different model, a different harness version or a different machine is `unobserved` (`- evidence-boundary:` above), not inferred. `agents/qa-verifier.md` binds `model: sonnet` while T-1073's own general-purpose baseline ran `model: haiku` — two variables differ between this arm and that baseline, disclosed rather than attributed to type alone; whether a plugin role's model binding can be overridden at launch is unknown here.
- No claim about any aspect of role resolution other than the effective tool set: the model actually bound, the system prompt actually loaded, and any behaviour not expressed through the tool set are all `unobserved` (`- evidence-boundary:` above); a finding demanding a model-identity or prompt-identity probe is a different task.
- The residual this design does not close: an instance holding `Write` that silently declines to attempt it, and a transient non-monotone venue denial coinciding with exactly the two subject messages — both bounded, not closed, exactly as `- evidence-boundary:` above states.
- **Evidence-authoring gap, disclosed rather than repaired.** `## Probe evidence (raw, orchestrator-produced)` above, frozen and byte-locked to the committed evidence commit, records every command it used in narrative prose (the `git clone --local` invocation, `git -C <clone> rev-parse HEAD`, the population-fixation unit run, `git status --short`, `git ls-files --others --exclude-standard`) but does not tag any of them with a standalone `- command: ` grammar line, unlike T-1073's own evidence section. This engineer restated those same commands, verbatim from the evidence's own prose, as `- command:` lines under `## Probe protocol` above — satisfying this note's whole-note requirement for at least one such line — but held no authority to add a `- command:` line inside the frozen evidence section itself, and did not. This is disclosed here as a known gap against this spec's own **AC4** (which additionally requires at least two `- command:` lines scoped to the evidence section specifically), not smoothed over; see this task's engineer hand-off for the disposition.
- No inferential-statistics claim anywhere in this note: the two subject repetitions' ≈3.7% overlap-margin spread is disclosed descriptively (`- licence-condition: repetition-variance` above); no significance test, confidence interval or regression is computed over it, and no dollar cost, vendor-price or token-multiplier estimate appears anywhere in this note.
- No watchdog and no negative-control stall arm ran in this protocol (`- not-run:` lines above); the co-run watchdog duty was retired by operator ruling on 2026-08-31 against two weeks of data, and the differential control arm that did run is a different instrument from a negative-control stall arm.
- Freeze-then-probe ordering rests on commit ancestry and byte-identity, which establish DAG structure, not wall-clock order — a determined author could construct a conforming graph after the fact. That is the identical self-attestation boundary every freeze-attestation and provenance record in this repository already stands on; this task introduces no new exposure to it and builds no attestation mechanism against it (`- verification-class: no-mechanism`).
- This task closes no issue and merges nothing; merge waits for the sprint's own batch GO.
