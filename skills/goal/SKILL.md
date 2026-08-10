---
description: Run a /goal self-verification loop — repeatedly implement+verify a single task until a layered completion gate (check-acs → check-intent, only when the spec carries a frozen intent block → check-provenance → qa-verifier → codex-reviewer) is fully green, bounded by loop-guard.sh (iteration / wall-clock / no-progress). Use when you want the team to drive a task to "done" on its own cadence rather than one manual pass.
---

You are driving the **`/goal` runtime self-verification loop** for the single
target task named in the request. Unlike `/shell-team:run` (one pass), `/goal` keeps
running one implement→verify attempt per tick until the task's acceptance
criteria are fully green **or** the loop's contract says stop. The loop is
**bounded by `bin/loop-guard.sh`** (iteration, wall-clock, no-progress) so it
cannot run away. You do **not** merge or push — those stay human gates.

**Step 0 — resolve paths & contract.** Run `team-paths.sh --print` once (on PATH
when the plugin is loaded; else `bin/team-paths.sh`) to read `TEAM_TODO`,
`TEAM_LOOPS_DIR`, `TEAM_RUNS_DIR`, `TEAM_SPECS_DIR`. The loop contract is
`<TEAM_LOOPS_DIR>/goal.contract.yaml`. The cross-tick **state file** is
`<TEAM_RUNS_DIR>/goal-<task-id>.state` (the runs dir is gitignored — state is
volatile, not committed).

⚠️ **Env vars do NOT persist across separate Bash tool calls.** Do not `export`
a path or counter in one call and read it in another. Cross-tick state lives in
the state file (managed by `goal-state.sh`); resolve any path *in the same Bash
call* with `$(team-paths.sh --get KEY)`.

**Language — mirror the user.** Prepend one line to each sub-agent prompt
(`engineer` / `qa-verifier` / `codex-reviewer`, as `/shell-team:run` does) telling it to
**respond in the same language the user is conversing in** (mirror it; default to
English if unclear). Zero-config — no language config file and no env var; pass the
conversation language you observe. **Keep machine-parsed tokens verbatim in
English**: status flags (`READY_FOR_*` / `BLOCKED` / `REWORK`), verdict labels
(`PASS` / `FAIL` / `APPROVE` / `REQUEST_CHANGES`), and each agent's fixed hand-off
headings/keys — `goal-state.sh signature` greps the verdict labels, so translating
them breaks no-progress detection. Prose follows the conversation language; the
contract tokens do not.

## First tick — initialize state

On the **first** tick for this task, create the state file (records the loop
start time + iteration 0):

```
goal-state.sh init "$(team-paths.sh --get runs)/goal-<task-id>.state"
```

(on PATH when the plugin is loaded; else `bin/goal-state.sh`.) Skip this on
later ticks — the state file already exists.

## Each tick

1. **Implement/verify attempt** — invoke `engineer` for one implement+test pass
   over the target task's spec (prepend the Operating-paths line to its prompt,
   as `/shell-team:run` does). It updates the board to `READY_FOR_QA`.
   - **Preserve the implementation across the seam (T-073)**: the engineer commits its implementation and tests before it sets `READY_FOR_QA`; as a second-layer guard, confirm there is no uncommitted implementation diff before invoking `qa-verifier` in the completion gate (`git status --short` shows nothing to commit). When you (the orchestrator) edit the task's interventions file at this same seam under the producer discipline below, commit that edit immediately — the same way the engineer commits its own work — before this check runs: this check is over the whole working tree, so an uncommitted interventions append at that exact moment would otherwise make it non-empty for a reason this guard's own prose does not name (T-1002 rework1 fix, mirroring `skills/run/SKILL.md`'s same fix).
   - **Interventions producer discipline (T-1002, referenced not restated)**: the same producer discipline `skills/run/SKILL.md`'s Implement phase carries applies to every tick here too — when a user message during an active tick interrupts, corrects, or stops the work (trigger 1), append the entry at that moment, before you act on the message; self-check `assumption-contradicted` (trigger 3) and `work-deferred`/`work-abandoned` (trigger 5) at this tick's own checkpoints — the Implement/verify attempt boundary above, the Completion-gate branch below, and any `STOP:` this tick reaches. The entry grammar (the marker pair and the field quad) is not restated here — see `skills/run/SKILL.md`'s own producer-discipline paragraph and `templates/prompt-blocks/interventions-classes.md`'s canonical template. The same durability duty applies identically here too (T-1002 rework2): every append to an interventions file is committed immediately, as its own commit, at the moment of recording, at every one of this tick's own checkpoints — never deferred to the next tick or to the Completion gate above to notice.

2. **Completion gate (layered, each verifier independent)** — run in order, and
   **do not carry one verifier's conclusion into the next** (a QA false-positive
   PASS must not anchor Codex):
   - `check-acs.sh <spec>` — deterministic: are the scriptable ACs all PASS?
   - if the spec carries a frozen `<!-- BEGIN/END intent-block: T-NNN -->`
     (T-072), also run `check-intent.sh <spec> <board>` alongside `check-acs.sh`
     as a second deterministic layer — the gate is not green unless it reports
     `aligned` (exit 0); when the spec has no intent block, skip this check
     (backward compatible).
   - also run `check-provenance.sh tasks/provenance/<task-id>.md` alongside
     `check-acs.sh` as a third deterministic layer — the gate is not green
     unless it reports `conformant` (exit 0). The engineer's T-074 producer
     discipline records this file (decision/reason/grounding triples or the
     zero-decision sentinel) every implement pass, so — unlike the opt-in
     intent-block check — this layer is unconditional: a missing file (usage
     exit 2) or a non-conformant file (schema exit 1 / structural exit 2) is
     itself a non-green outcome that routes back to `engineer`, never a skip
     (fail-closed by design — the mechanical enforcement point of the
     provenance discipline; provenance is mandatory per task, not opt-in per
     spec). A non-conformant provenance layer feeds this tick's SIG (step 3,
     translated below) and is therefore bounded by `loop-guard.sh` just like
     check-acs / check-intent — no separate retry cap is needed on the goal
     side (unlike the shell-team seam gate, which fails closed and escalates
     to the human immediately rather than bounding retries).
   - also run `check-interventions.sh --task <task-id> "$(team-paths.sh --get interventions)/<task-id>.md"` (on `PATH` when the plugin is loaded; else `bin/check-interventions.sh`) alongside `check-acs.sh` as a further deterministic layer — the gate is not green unless it reports `conformant` (exit 0). Unlike the provenance file, this record is the **orchestrator's own** (T-1002 DP-3: interventions arrive in the main conversation, which only you see) — a missing file (usage exit 2) or a non-conformant file (schema exit 1 / structural exit 2) is a non-green outcome for this tick that you resolve yourself (write or fix the interventions file) before the next tick, rather than routing back to `engineer`. If this interventions layer is the ONLY layer that failed this tick (check-acs / check-intent / check-provenance were already green), repair the interventions file yourself and re-run `check-interventions.sh` again in the SAME tick, before this tick reaches the Bound gate below (step 3) — do not re-invoke `engineer` for this repair, since interventions are outside its remit (T-1002 DP-3); a record-only gap here therefore never consumes a fresh implement pass, never forces a wasted loop-guard iteration, and never on its own fabricates a `STOP:no_progress` (T-1002 rework1 fix, Codex round1 Major 4).
   - if so, invoke `qa-verifier` — judges the non-scriptable ACs (PASS/FAIL).
   - if QA PASS, invoke `codex-reviewer` — cross-provider verdict
     (APPROVE / REQUEST_CHANGES).
   - **Detection lens** (same distinction as `/shell-team:run`'s step 5/6):
     `qa-verifier` verifies empirically/by execution (does it actually run,
     actually produce the claimed output); `codex-reviewer` verifies
     formulaically/statically (boundary conditions, arithmetic, structural
     edge cases) — an orthogonal detection surface, not a duplicate of QA's.
   The gate is **green** only when all applicable layers pass — six when an
   intent block exists, otherwise five — check-acs PASS + check-intent.sh
   aligned (when the spec carries an intent block) +
   check-provenance.sh conformant + check-interventions.sh conformant + QA
   PASS + Codex APPROVE.
   - **Per-tick failure-class tracking (T-058)**: on every non-green tick,
     classify each gate finding by root-cause class slug — check-acs /
     `check-intent.sh` (a non-`aligned` result) /
     `check-provenance.sh (a non-conformant result)` /
     `check-interventions.sh (a non-conformant result)` / `qa-verifier` findings
     all as phase `validate`, `codex-reviewer` findings as phase `review` — and keep
     the per-tick list (round = the iteration number
     this tick gets from `goal-state.sh bump` in step 3) in your working
     context across ticks (a ScheduleWakeup re-entry stays in the same
     conversation; the state file stores no classes — reuse, don't modify).
     These records are the input for the STOP escalation digest in step 4.

3. **Bound gate** — compute the loop-guard inputs *in one Bash call each*, then
   ask the guard whether to continue:
   ```
   STATE="$(team-paths.sh --get runs)/goal-<task-id>.state"
   ITER="$(goal-state.sh bump "$STATE")"
   ELAPSED="$(goal-state.sh elapsed-min "$STATE")"
   SIG="$(printf '%s' "<combined check-acs (normalized: check-acs: PASS or check-acs: FAIL <ids>) + check-intent (translated) + check-provenance (translated) + check-interventions (translated) + QA/Codex verdict labels only — never the raw check-acs stdout or free-form prose>" | goal-state.sh signature)"
   PREV="$(goal-state.sh prev-sig "$STATE")"
   loop-guard.sh "$(team-paths.sh --get loops)/goal.contract.yaml" \
     --iteration "$ITER" --elapsed-min "$ELAPSED" \
     --verdict-hash "$SIG" --prev-verdict-hash "$PREV"
   goal-state.sh set-sig "$STATE" "$SIG"
   ```
   - **`check-acs.sh`'s contribution to the combined text must be a normalized
     summary, never its raw stdout**: concatenate `check-acs: PASS` when every
     scriptable AC passed, or `check-acs: FAIL <space-separated failing AC
     ids>` otherwise. Never paste the raw `check-acs.sh` stdout — its per-AC
     `running: <check command text>` diagnostic lines are literal
     reproductions of each AC's `check:` command, and this very spec's own
     AC5/AC16 check commands contain the literal tokens `FAIL AC900003` /
     `AC900004`; concatenating the raw stdout would inject those tokens into
     every tick's signature regardless of the actual check-provenance
     outcome, making the signature non-injective — a false `STOP:no_progress`
     that Codex round1 (Blocker 1) reproduced byte-for-byte in this repo.
     **Derive this deterministically — no orchestrator discretion left in how
     to extract it (Codex round2 M2)**: decide PASS/FAIL from
     `check-acs.sh <spec>`'s **exit code** — exit 0 means `check-acs: PASS`.
     On exit 1, parse the trailing `check-acs: FAILED: AC3 AC7 …` summary
     line (equivalently, the `n` in each `ACn: FAIL (exit …)` line) and pull
     out only the **bare `ACn` ids** to build `check-acs: FAIL AC3 AC7` —
     **never take the `ACn: running: <check command>` diagnostic lines**,
     which reproduce each AC's check command verbatim and are exactly the B1
     poisoning source. The same rule applies to QA/Codex: contribute their
     **verdict label only** (`PASS`/`FAIL`/`APPROVE`/`REQUEST_CHANGES`),
     never their free-form prose — a stray verdict-label word inside a
     finding's write-up would otherwise corrupt the signature in the
     opposite direction.
   - **`check-acs.sh`'s exit 2 (usage) must never poison the signature (T-077
     req 3)**: on a `check-acs.sh <spec>` exit 2 (usage — an unreadable/missing
     spec, bad args, or an unrecognized AC label line), check-acs exit 2 never
     poisons the signature: treat it as a `guard_error`-class condition and
     escalate to the human immediately — never translate it into a sentinel,
     and never fold check-acs's raw error text into the combined signature
     text. The goal loop is bounded by `loop-guard.sh`, but a spec you cannot
     read is a broken setup, not a convergence failure.
   - The `verdict-hash` is a **normalized failure signature** (verdict labels + AC
     ids only — `goal-state.sh signature` strips volatile prose), so a tick that
     repeats the same failure shape trips `STOP:no_progress`.
   - **`check-intent.sh` must be translated into existing signature vocabulary
     before you concatenate it into the combined text** — `goal-state.sh`'s
     normalization regex only recognizes `PASS`/`FAIL`/`APPROVE`/
     `REQUEST_CHANGES`/`AC[0-9]+`, and it is a primitive ("Reuse, don't modify"
     below), so a raw literal `aligned`/`structural`/`drift-detected` token
     would be silently dropped by the regex and two ticks with genuinely
     different check-intent outcomes would collapse onto the same signature
     (false `STOP:no_progress`, or a real repeated failure going undetected).
     When the spec carries an intent block, append one of these to the
     combined text instead of the raw exit-code word:
     - `aligned` (exit 0) → `check-intent: PASS`.
     - `structural` (exit 2, hash not yet recorded) → `check-intent: FAIL
       AC900001` — `AC900001` is a **reserved sentinel** AC id (never a real
       spec AC number — this repo's specs never reach anywhere near 900) used
       only so this failure mode's signature differs from `drift-detected`'s.
     - `drift-detected` (exit 1, recorded hash mismatches the current intent
       block) → `check-intent: FAIL AC900002` — a second, distinct sentinel.
     - `attestation` (exit 2, T-1018: the board carries no conformant
       `- freeze-attestation` record for the version about to be recorded) →
       `check-intent: FAIL AC900007` — a fourth, distinct reserved sentinel
       (never a real spec AC number), so this outcome's signature differs
       from `structural`'s (`AC900001`) and `drift-detected`'s (`AC900002`)
       and cannot collapse a real `no_progress` false-positive onto either.
     This keeps `goal-state.sh` itself untouched while still making
     `structural` and `drift-detected` (and `aligned`) each produce a distinct
     signature — verified: `printf '%s' "AC1: PASS\ncheck-intent: FAIL
     AC900001" | goal-state.sh signature` → `AC1;AC900001;FAIL;PASS`, versus
     `...AC900002` → `AC1;AC900002;FAIL;PASS` (different), versus the aligned
     case `...check-intent: PASS` → `AC1;PASS` (different from both).
   - **`check-provenance.sh` must also be translated into the signature
     vocabulary before you concatenate it** — same reason as `check-intent.sh`
     (`goal-state.sh`'s regex only recognizes `PASS`/`FAIL`/`APPROVE`/
     `REQUEST_CHANGES`/`AC[0-9]+`, so a raw `conformant`/`schema`/`usage` word
     would be silently dropped and two ticks with different provenance outcomes
     would collapse onto one signature — a false `STOP:no_progress` or a missed
     repeated failure, the exact T-072 SIG-follow-through miss). When the
     provenance gate ran this tick, append one of these to the combined text:
     - `conformant` (exit 0) → `check-provenance: PASS`.
     - `schema` (exit 1, a malformed/incomplete triple or an
       ungrounded-without-declaration decision) → `check-provenance: FAIL
       AC900003` — a **reserved sentinel** AC id (never a real spec AC; distinct
       from check-intent's AC900001/AC900002).
     - `usage` / `structural` (exit 2, a missing/unreadable provenance file or
       broken markers) → `check-provenance: FAIL AC900004` — a second reserved
       sentinel.
     This keeps `goal-state.sh` itself untouched while making conformant /
     schema / usage-structural each produce a distinct signature — verified:
     `printf '%s' "check-provenance: FAIL AC900003" | goal-state.sh signature`
     → `AC900003;FAIL`, versus `...AC900004` → `AC900004;FAIL` (different),
     versus `check-provenance: PASS` → `PASS` (different from both, and from
     check-intent's sentinels).
   - **`check-interventions.sh` (translated)** must also be translated into
     the signature vocabulary before you concatenate it — same reason as
     `check-intent.sh`/`check-provenance.sh` (`goal-state.sh`'s regex only
     recognizes `PASS`/`FAIL`/`APPROVE`/`REQUEST_CHANGES`/`AC[0-9]+`, so a raw
     `conformant`/`schema`/`usage`/`structural` word would be silently dropped
     and two ticks with different interventions outcomes would collapse onto
     one signature). When the interventions gate ran this tick, append one of
     these to the combined text:
     - `conformant` (exit 0) → `check-interventions: PASS`.
     - `schema` (exit 1, an unrecognized class token or a malformed/incomplete
       entry) → `check-interventions: FAIL AC900005` — a **reserved sentinel**
       AC id (never a real spec AC; distinct from every prior reserved id).
     - `usage` / `structural` (exit 2, a missing/unreadable interventions
       file, broken markers, or a `--task` disagreement) →
       `check-interventions: FAIL AC900006` — a second reserved sentinel.
     This keeps `goal-state.sh` itself untouched while making conformant /
     schema / usage-structural each produce a distinct signature — verified:
     `printf '%s' "check-interventions: FAIL AC900005" | goal-state.sh
     signature` → `AC900005;FAIL`, versus `...AC900006` → `AC900006;FAIL`
     (different), versus `check-interventions: PASS` → `PASS` (different from
     both, and from every other reserved sentinel).
   - **`--elapsed-min` is required**: `loop-guard.sh` defaults `ELAPSED_MIN=0` and
     the contract's `max_wallclock_min` is inert without it. `goal-state.sh
     elapsed-min` derives it from the persisted start time — always pass it.

4. **Decide**:
   - Gate **green** → the loop **succeeds**; report done (board at
     `READY_FOR_MERGE`, review recorded) and **stop**. Do not merge/push (human
     gate).
   - **Fast-follow disposition recording (T-068)**: before reporting done at `READY_FOR_MERGE`, act on `codex-reviewer`'s `#### Fast-follow disposition` declaration — the reviewer states intent only (file-an-issue or won't-fix) and never opens issues or edits the board, so **you (the orchestrator) are the actor**: for a file-an-issue intent, open the issue (via this repo's normal issue-creation flow, user-approval gate where it applies) and capture its number; for a won't-fix intent, capture the reason. Transcribe the result onto the task's board entry as a sub-bullet anchored `- fast-follow disposition (YYYY-MM-DD): …`, using the same closed disposition set as `/shell-team:run`'s Review step — `filed as issue #N`, `waived: <reason>`, or a time-bound `pending: <reason> — <deadline>` that must resolve to `filed as issue #N` or `waived: <reason>` before close-out (`pending` must never survive close-out — `bin/close-out.sh` fails closed if one remains). If the reviewer declared `no fast-follow deferrals`, no line is required. The reviewer does not edit the board — a rule it follows, carried in its own board-and-write-boundary Rule in `agents/codex-reviewer.md`, and not a capability it lacks: its `tools:` line grants `Bash`, so it could write the board and does not. Filing and recording are the orchestrator's job, so a surfaced deferral never silently vanishes (the T-066 record gap).
   - loop-guard prints **`STOP:<reason>`** (`max_iterations_reached` /
     `budget_exhausted` / `no_progress` / `guard_error`) → **stop** and report the
     reason verbatim to the user.
     - **Rework-history digest (T-058)**: when escalating a `STOP:`, run `rework-digest.sh` with the per-round root-cause classes you have been tracking across rounds — one `--round <n> --phase <validate|review> --class <slug>` triple per classified rework finding — plus `--stop-reason <reason>` (on PATH when the plugin is loaded; else `bin/rework-digest.sh`), and paste its stdout into the escalation message. It prints the per-round failure-class list and the same-class-repetition vs new-classes judgment the human needs for the extend/stop decision. Do not re-describe the digest format by hand — the script is its single source of truth.
     - **Re-routing branch (T-063)**: when the digest's judgment is `same-class-repetition`, its `recommended-action` block is present in the pasted stdout — surface those choices to the human as-is and lead with reconsider the design premise (routing back to pm-spec/ui-designer) as the first choice, not a hand-copied restatement; the script's output is the single source of truth for the choice text.
   - **Early escalation branch (T-100, distinct from the STOP escalation above)**: classify each rework finding by root-cause class the same way as `/shell-team:run`'s Same-class-2 rule. The moment the same class reaches 2 cumulative occurrences — before any loop-guard `STOP:` is reached — run `rework-digest.sh` with `--trigger same-class-2` in place of `--stop-reason` (no `STOP:` is required to run it in this mode) and surface the `recommended-action` block to the human early, leading with reconsider-the-design-premise; the script's stdout is the single source of truth for the choice text. This early call does not replace the STOP-mode digest above — that one still runs if a `STOP:` is later reached.
   - loop-guard prints **`CONTINUE`** and the gate is **not** green → schedule the
     next tick with `ScheduleWakeup(delaySeconds, <re-invoke this /goal prompt>)`.
     Pick `delaySeconds` ≤ the 5-minute cache TTL when the loop should continue
     soon (a cost optimization only — it never affects the bound).

## Telemetry (best-effort)

After each sub-agent call, emit one span (never let it stop the loop — append
`|| true`):

```
log-run.sh goal --run-id <run_id> --seq <n> --span <engineer|qa-verifier|codex-reviewer> \
  --phase <implement|verify|review> --iteration <ITER> --attempt 1 \
  --status <success|error> [--verdict <PASS|FAIL|APPROVE|REQUEST_CHANGES>] [usage flags…] || true
```

`log-run.sh` self-resolves the runs dir (no path injection needed). Use `goal`
as the `loop_id`.

## Rules / boundaries

- **Bounded, not autonomous-to-merge**: the loop drives to green, then stops at
  the human gate. Never `git merge`/`git push`/tag — quote the contract's
  `human_gate`.
- **Reuse, don't modify** the primitives (`loop-guard.sh`, `check-acs.sh`,
  `log-run.sh`, `goal-state.sh`, the `qa-verifier`/`codex-reviewer` agents).
- **token/usd is never a hard STOP lever** — the contract's `max_usd: 0` is
  untracked; the real bounds are iteration + wall-clock.

## Runtime is dogfood-verified, not CI-tested

The `/loop`/`ScheduleWakeup` cadence and the end-to-end implement→verify→stop
behavior run at **runtime** and are **not** exercised by CI — they depend on
runtime primitives this skill cannot self-invoke. What CI does verify is the
machinery this skill leans on: `goal-state.sh` (unit-tested), the
`goal.contract.yaml` lint, and that the primitives are unchanged. End-to-end loop
behavior is confirmed by **dogfood** runs, not the test suite. See
`docs/loop-engineering/goal-loop.md`.

**Human-gate declaration (T-1056).** At every point where a skill hands control to a human and waits, write a human-gate declaration to `<runs>/gate-<task-id>.decl` (with `<runs>` resolved via `bin/team-paths.sh --get runs`) before you wait, and remove that declaration the moment you act on the human's answer — the same choke point performs both duties, at each such point, never only one of them. The declaration carries a `gate-declaration 1` version line first, one each of `task`, `reason`, `run-epoch` and `declared-epoch`, and a `gate-declaration-end` terminator. Select `reason` from the shipped closed registry (`templates/liveness-reasons.txt`) — never a guessed token — using `merge-go` for the human GO before a merge, `push-go` for the human GO before a push, `fast-follow-approval` for a fast-follow issue awaiting user approval before filing, `intent-ratification` for a frozen intent block awaiting a human-ratified re-freeze or a class-M grant suspended pending human review, `gate-escalation` for a fail-closed seam gate handed to the human, `stop-escalation` for a loop-guard `STOP:<reason>` handed to the human with the rework digest, `same-class-2` for the pre-STOP early escalation the second occurrence of one root-cause class triggers, and `advisory-escalation` for a non-aligned drift-evaluator verdict surfaced before the merge pledge. This duty applies at every write site a skill's own gates enumerate, never only at one of them. See `## Declaration write-site inventory` in `.shell-team/specs/T-1056-loop-liveness.md` for where this loop reaches such a point in the phases above.

**Executor resolution (T-1057).** For each of the six bound roles a phase invokes, resolve that role's executor immediately before invoking it: run `bin/resolve-executor.sh --role <role>` (on `PATH` when the plugin is loaded; else `bin/resolve-executor.sh`) and treat every refusal — `usage`, `binding-unresolved`, `executor-unavailable`, `capability-unsupported` or `contract-violation` — as a blocker that stops the phase and escalates to the human, quoting the refused token verbatim. Never substitute another executor for a role whose resolution refused, and never continue with any role left unresolved. When a resolved row's own stdout names the `in-process` probe kind, treat the harness's own sub-agent invocation failure for that role as `executor-unavailable` too, stopping the phase and escalating exactly as for any other refusal. Take each `--model` telemetry value from that role's own resolved row rather than from any prompt's pinned model value — the resolved binding is the telemetry source of record for every bound role's model, and this claim is bounded honestly rather than papered over: a role's actual invocation still routes through that role's own pinned model value, not through this resolution, so telemetry drawn from the resolved row matches what actually ran only for as long as a bound role's own pin and the effective binding's model token agree; a custom binding that departs from the shipped default records the bound model as telemetry, not an independently verified executed one. Apply this at each of this tick's own invocation points (`engineer`, `qa-verifier`, `codex-reviewer`).

**Telemetry binding (T-1058).** After each bound role's sub-agent call returns, and using the same resolved row `--model` telemetry already reads (`bin/resolve-executor.sh --role <role>`), pass that row's provider, effort and adapter fields on that call's span as `--provider`, `--effort` and `--adapter` to `bin/log-run.sh`, carrying the row's effort field verbatim including a bare `-`; when instead that role's resolution refused, write no span row for that call at all, and record the refusal as an `--event gate --from <phase> --label <refusal token>` row with the token verbatim, because a span records a call that happened and a refused resolution made none. Every value recorded this way is the resolved binding as declared, never an independently verified observation of what executed, and a span that omits one or more of the three is read at aggregation as `undetermined`, never as a default. Apply this at each of this tick's own invocation points (`engineer`, `qa-verifier`, `codex-reviewer`).

Target task / request:
$ARGUMENTS
