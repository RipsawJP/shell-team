# `/goal` — runtime self-verification loop

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](goal-loop.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](goal-loop.ja.md)

`/shell-team:goal <task>` drives a single task to "done" on its own cadence:
it repeats one **implement → verify** attempt per tick until a layered
**completion gate** is fully green, or `loop-guard.sh` returns a STOP. It
implements an earlier feasibility spike's GO(partial) wiring sketch. The skill
itself is `skills/goal/SKILL.md`.

## When to use `/goal` (task suitability)

`/goal` is bounded but not free: an unsuited task doesn't break the loop
(`loop-guard.sh` still STOPs), it just burns iterations before escalating to
you. Filter *before* starting. A task suits the loop when **all four** hold:

1. **Recurring / backlog-shaped** — the work shows up repeatedly (test fixes,
   lint debt, docstrings), so setting up a loop pays back.
2. **Objectively verifiable** — "done" is checkable by the completion gate
   without a human eye: machine-checkable acceptance criteria (`check:` lines
   for `check-acs.sh`) or behavior `qa-verifier` can exercise empirically.
3. **Cheaper to verify than to execute** — the layered gate can judge an
   attempt for less than the attempt costs. If verification itself needs long
   human review, the gate never goes green on its own.
4. **Fits the context** — one implement → verify attempt fits a single working
   context. Tasks needing fresh cross-repo archaeology every tick stall and
   trip `STOP:no_progress`.

If any criterion fails, prefer a single human-paced `/shell-team:run` pass instead.
The criteria map 1:1 onto this repo's primitives — #2 ⇔ machine-checkable ACs,
#3 ⇔ the gate's cheap-deterministic-first ordering, #4 ⇔ the `no_progress`
signature's assumption that repeated failure shapes mean a stall.
(Criteria phrasing follows field guidance on Claude Code loops, e.g.
<https://x.com/mnilax/status/2074880097597689957>, 2026-07.)

## How it composes existing primitives

| concern | primitive | role |
|---|---|---|
| cadence | the environment's `/loop` + `ScheduleWakeup` | re-fire the driver each tick ([host-only scheduling](../distribution.md#host-only-scheduling) for an OS-scheduler alternative) |
| bound (runaway STOP) | `bin/loop-guard.sh` + `goal.contract.yaml` | iteration / wall-clock / no-progress |
| completion (per-tick judge) | `check-acs.sh` → `check-intent.sh` (only when the spec carries a frozen intent block) → `check-provenance.sh` → `qa-verifier` → `codex-reviewer` | deterministic → deterministic (conditional) → deterministic → judgement → cross-provider, each independent |
| cross-tick state | `bin/goal-state.sh` + `<runs>/goal-<task>.state` | loop start time, iteration, prev failure signature |
| telemetry | `bin/log-run.sh` | one span per sub-agent call (`loop_id=goal`) |

The completion signal is **layered**, not a single small model — deterministic
`check-acs` first (free, no false "looks done"), then `check-intent` (only when
the spec carries a frozen intent block) and `check-provenance`, then `qa-verifier`,
then the cross-provider `codex-reviewer`. This is stronger than the literal `/goal`
"one small model judges each turn" framing.

## Boundedness (why it can't run away)

`loop-guard.sh` is the kill-switch, not the model's own judgement:

- **iteration cap** (`budget.max_iterations`) — the always-on hard bound.
- **wall-clock cap** (`budget.max_wallclock_min`) — enforced **only because the
  driver passes `--elapsed-min`** each tick (derived from the persisted loop
  start time via `goal-state.sh elapsed-min`). `loop-guard.sh` defaults
  `ELAPSED_MIN=0`, so the cap is inert if `--elapsed-min` is omitted — the `/goal`
  driver always passes it. (This is the gap the original feasibility spike's
  Codex review flagged; `/goal` closes it.)
- **no-progress** (`stop.no_progress: true`) — the verdict hash is a **normalized
  failure signature** (verdict labels + AC ids only; volatile prose like
  timestamps and token counts is stripped by `goal-state.sh signature`), so two
  ticks with the same failure shape trip `STOP:no_progress` instead of burning the
  full iteration budget.
- **fail-closed** — an unreadable/garbled contract yields `STOP:guard_error`.

`token`/`usd` are **never** a hard STOP lever (`max_usd: 0` = untracked); the real
bounds are iteration + wall-clock, per the epic non-goal.

## Human gates

`/goal` drives to green and then **stops** — it never merges, pushes, or tags.
Those remain human gates (`human_gate: [merge, push]` in the contract).

## What is and isn't CI-tested (honest scope)

- **CI-tested**: `goal-state.sh` (unit suite `tests/goal-state/`), the
  `goal.contract.yaml` lint (`check-contract.sh`), and that the reused primitives
  are unchanged.
- **NOT CI-tested**: the `/loop`/`ScheduleWakeup` cadence and the end-to-end
  implement→verify→stop behavior. These run at **runtime** with primitives the
  skill cannot self-invoke, so end-to-end behavior is confirmed by **dogfood**
  runs and external evidence, not the test suite. Treat the runtime loop the way
  this project's earliest runtime-only acceptance criteria were treated —
  verified outside CI.

## State files

`<runs>/goal-<task-id>.state` (runs dir is gitignored) holds `start_epoch`,
`iteration`, and `prev_sig`. It is volatile per-run state, never committed.
