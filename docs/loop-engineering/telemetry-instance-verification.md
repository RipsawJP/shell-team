# Telemetry instance verification (T-1082)

`.shell-team/specs/T-1082-telemetry-discriminator.md` ships the reading half
of the per-instance telemetry discriminator issue #277's adoption
precondition 1 asks for: `bin/check-fanout-instances.sh`, a fail-closed
checker tying one fan-out's own telemetry span rows to the merged
`fanout-verdict` block `bin/aggregate-verdicts.sh` produced for it. The
writer-side half already shipped — T-1072's `--instance` and its grammar,
T-1076's `--seq auto`, T-1074's `- attribution:` line — and none of it is
re-designed here; this note records what the new checker actually verifies
and reconciles the invariant's own canon contradiction.

## The four properties

One row per property this checker enforces, in the fixed check order it
applies them (block parse first, then per-row shape, presence, grammar,
uniqueness, unattributed ids, and the exit-3 coverage check last).

- property: presence — enforced over every span row the caller's declared scope selects (`--telemetry`/`--run-id`/`--phase`, narrowed by `--iteration`/`--attempt`) — refusal class: `missing-instance`
- property: grammar — enforced on both a row's `instance` value and the aggregation block's `- part:` name, against the writer's own `^[a-z][a-z0-9-]*$` grammar, named verbatim rather than re-derived — refusal classes: `invalid-instance`, `malformed-block`
- property: uniqueness — enforced within the declared scope as an id-to-role functional dependency (the same id on two rows of the same role stays legal) — refusal class: `instance-role-collision`
- property: consistency — enforced in both directions between the scope's own instance set and the aggregation block's declared part set, with the direction deciding the exit code — refusal classes: `unattributed-instance`, `uncovered-part`

Two supporting classes sit outside the four properties: `usage`/`block-not-found`
(invocation defects — the caller named a bad flag or the wrong label) and
`duplicate-block`/`malformed-row`/`no-rows` (structural defects in the block
or the telemetry file, and the zero-rows-selected case). Eleven classes in
total; `bin/check-fanout-instances.sh`'s own header enumerates them and its
own suite (`tests/check-fanout-instances/run.sh`) asserts every one by name.

## Canon reconciliation

The invariant `per-instance-telemetry-discriminator` was declared at four
sites, three saying `implemented` and one saying `named as a follow-up
only`: `skills/run/SKILL.md` (two pastes of the same fan-out block),
`templates/prompt-blocks/fanout-orchestration.md` (the canonical source of
that block), and `docs/loop-engineering/phase-multiplexing.md` (T-1069's
own historical record of what that task itself did, under its own
`no-mechanism` class).

**The disposition, with its reason: both true at different layers, and
neither site is reworded.** The three
`implemented` sites describe writer-side usage — each instance's call
already carries `--instance`, and `--seq auto` makes the concurrent appends
safe — which genuinely is implemented, and predates this task.
`docs/loop-engineering/phase-multiplexing.md`'s `followup-only` line is
**T-1069's own historical record** of what that task did, not a live claim
about the repository's present state, and its frozen **AC7** requires
exactly one `- invariant-lock:` line per id there plus at least one
`- follow-up: .*per-instance` line — editing or discharging either line in
place would redden that merged criterion. `docs/loop-engineering/phase-multiplexing.md`
is therefore left byte-identical; the discharge of its follow-up line is
recorded here and in this task's own records instead. What was genuinely
absent — reading-side verification, the four properties above — is what
this task ships.

## Dogfooded derivation — the invariant's own declaration sites, re-measured at HEAD

The population below is regenerated directly against this repository's own
tree (a working-tree read at HEAD, never a ref measurement — this note
carries no `measured at <ref>` label) with `bin/derive-populations.sh`, the
same tool the spec's own `## Canon reconciliation` section used at the
branch point. Re-running the `- reproduce:` command below reproduces the
embedded block byte-for-byte for as long as the shipped fan-out prompt
block and the run skill carry the same three/one `implemented`/
`followup-only` split; it goes stale the moment either file's own
`- invariant-lock:` line count for this id changes (see the `stale-at`
note on the spec's own **AC12**).

- reproduce: derive-populations.sh --label t1082-note-invariant-declaration-sites --set 'implemented=git grep -n -- "^- invariant-lock: per-instance-telemetry-discriminator — implemented" -- skills templates | cut -d: -f1-2' --set 'followup-only=git grep -n -- "^- invariant-lock: per-instance-telemetry-discriminator — named as a follow-up only" -- docs | cut -d: -f1-2' --accept-status implemented=1 --accept-status followup-only=1
<!-- BEGIN derivation: t1082-note-invariant-declaration-sites -->
- derived-by: bin/derive-populations.sh
- locale: LC_ALL=C
- set: implemented — status: 0 — lines: 3 — items: 3 — command: git grep -n -- "^- invariant-lock: per-instance-telemetry-discriminator — implemented" -- skills templates | cut -d: -f1-2
- set: followup-only — status: 0 — lines: 1 — items: 1 — command: git grep -n -- "^- invariant-lock: per-instance-telemetry-discriminator — named as a follow-up only" -- docs | cut -d: -f1-2
- union: items: 4
- bucket: followup-only — items: 1
  - docs/loop-engineering/phase-multiplexing.md:351
- bucket: implemented — items: 3
  - skills/run/SKILL.md:177
  - skills/run/SKILL.md:197
  - templates/prompt-blocks/fanout-orchestration.md:18
<!-- END derivation: t1082-note-invariant-declaration-sites -->

## What this task does not touch

`bin/log-run.sh`, `bin/check-run.sh` and `bin/aggregate-verdicts.sh` are
consumed exactly as they are and are byte-identical to their branch-point
committed blobs; T-1072's writer-only validation decision stands, and no
charset or presence check was added to `bin/check-run.sh`. No instance is
launched, no phase is rewired, and no dispatcher is built — the one
orchestration edit is the verification bullet inside the already-opt-in
fan-out step in `templates/prompt-blocks/fanout-orchestration.md`, mirrored
into `skills/run/SKILL.md`.
