# Plugin-role Agent-tool concurrency — reconciliation, and the resolved-type differential probe (T-1111)

This note is assembled in two stages by two actors (the structure T-1073's note
established): the `## Probe evidence (raw, orchestrator-produced)` section below
is written and committed by the coordinating session before the engineer is
invoked, and is byte-frozen from that commit onward; every other section is
assembled by the engineer from that committed evidence without altering a byte
of it.

## Probe evidence (raw, orchestrator-produced)

Probe executed 2026-09-01 by the coordinating session per the frozen
`<!-- BEGIN probe-protocol: T-1111 -->` region of
`.shell-team/specs/T-1111-plugin-role-agent-concurrency.md` (intent-hash v1
`5c9f7800939f24507d6dd25a08706fe2693dcb3a`, frozen before any arm ran). Venue:
exactly one throwaway `git clone --local` under `$TMPDIR` (written here as
`<probe-clone-root>`; its source is `<this-checkout-root>`), detached at the
resolved branch point. Launch order as frozen: `resolved-type-n3-rep1` →
`control-gp-n3` → `resolved-type-n3-rep2`, three parallel `Agent` tool calls in
one orchestrator message per arm, nine launches total. Every timestamp below is
from `python3 -c 'import time; print(time.time_ns())'` (verified expanding to a
19-digit integer before reliance), taken by the instance itself (`start_ns`/
`end_ns`, transcribed 1:1 onto the `- agent-timestamp:` lines as `first`/`last`)
or by the orchestrator (`- unit-timing:`, `- batch-timestamp:`).

- clone-ref: shared — e14898a5f0f56505f1bea2de23f046fabe590eee — `git -C <probe-clone-root> rev-parse HEAD`, read after the detached checkout and equal to the resolved branch point (arm 1 of the base-ref discriminator).
- probe-arm: resolved-type-n3-rep1 — executed — three shell-team:qa-verifier instances, one message, per the frozen order (first).
- probe-arm: control-gp-n3 — executed — three general-purpose instances, one message, per the frozen order (second, between the subject arms).
- probe-arm: resolved-type-n3-rep2 — executed — three shell-team:qa-verifier instances, one message, per the frozen order (third).
- unit-timing: population-fixation — start=1788189989987830000 — end=1788190190451760000 — plain shell run of the unit in the clone before any arm: `cd <probe-clone-root> && CHECK_ACS_TIMEOUT=900 bash bin/check-acs.sh .shell-team/specs/T-1044-test-infra-bundle.md`; rc=1 (the unit is the run, never its verdict; its tail read `10 passed, 4 failed, 1 skipped`).
- batch-timestamp: resolved-type-n3-rep1 — batch_start=1788190200723271000 — batch_end=1788190535863506000 — orchestrator timestamps immediately before the arm's one launch message and immediately after its last completion notification.
- batch-timestamp: control-gp-n3 — batch_start=1788190535992907000 — batch_end=1788190893103623000 — same method.
- batch-timestamp: resolved-type-n3-rep2 — batch_start=1788190893232586000 — batch_end=1788191236079383000 — same method.
- agent-timestamp: resolved-type-n3-rep1 — qa-1 — first=1788190222808870000 — last=1788190503223358000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep1 — qa-2 — first=1788190227189048000 — last=1788190507903021000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep1 — qa-3 — first=1788190228618590000 — last=1788190508948474000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-1 — first=1788190564703988000 — last=1788190844603067000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-2 — first=1788190563273941000 — last=1788190861254169000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: control-gp-n3 — gp-3 — first=1788190568879956000 — last=1788190866588978000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-1 — first=1788190920375605000 — last=1788191200989511000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-2 — first=1788190918308554000 — last=1788191186978384000 — transcribed 1:1 from the instance's report line below.
- agent-timestamp: resolved-type-n3-rep2 — qa-3 — first=1788190922588647000 — last=1788191190773925000 — transcribed 1:1 from the instance's report line below.
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
- tool-probe: resolved-type-n3-rep2 — qa-3 — write_tool=refused — same; the one self-report differing from its arm-mates, conformant with its own absent artifact under the consistency coupling.
- probe-writes: none — after every arm, `git status --short` and `git ls-files --others --exclude-standard` were read in the real checkout: clean, zero untracked strays; inside the clone the only untracked paths are the three sanctioned control artifacts (`git -C <probe-clone-root> status --short` count 3, all matching `probe-write-control-gp-n3-gp-[123].txt`), so `none` here means no write outside the clone and no unsanctioned write inside it.

Verbatim instance report lines (channel source for the `- agent-timestamp:` and
`- tool-probe:` families above, one line per instance as each completion
notification delivered it):

```
instance=qa-1 arm=resolved-type-n3-rep1 start_ns=1788190222808870000 end_ns=1788190503223358000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-2 arm=resolved-type-n3-rep1 start_ns=1788190227189048000 end_ns=1788190507903021000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-3 arm=resolved-type-n3-rep1 start_ns=1788190228618590000 end_ns=1788190508948474000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=gp-1 arm=control-gp-n3 start_ns=1788190564703988000 end_ns=1788190844603067000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=gp-2 arm=control-gp-n3 start_ns=1788190563273941000 end_ns=1788190861254169000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=gp-3 arm=control-gp-n3 start_ns=1788190568879956000 end_ns=1788190866588978000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=available
instance=qa-1 arm=resolved-type-n3-rep2 start_ns=1788190920375605000 end_ns=1788191200989511000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-2 arm=resolved-type-n3-rep2 start_ns=1788190918308554000 end_ns=1788191186978384000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=absent
instance=qa-3 arm=resolved-type-n3-rep2 start_ns=1788190922588647000 end_ns=1788191190773925000 clock_source=python3-time_ns unit_rc=1 foreground=true write_tool=refused
```

Execution-detail findings, recorded for reuse: every one of the nine instances
reported `foreground=true` under an explicit 400000 ms timeout parameter,
consistent with T-1073's finding that only the 120 s default auto-backgrounds;
the three completion notifications of each arm arrived within seconds of one
another; and the `refused`-vs-`absent` split inside the subject self-reports is
itself evidence the self-report channel is agent-authored interpretation rather
than a harness fact — exactly why it is the corroborating channel and never the
licensing one.
