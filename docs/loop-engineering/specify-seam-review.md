# The `spec-review` axis: an opt-in cross-provider check on a spec's domain premises (T-1092)

Every quality gate in this loop treats the spec as ground truth. `qa-verifier`
verifies the implementation *against* the spec; `codex-reviewer` verifies the
delivered change against it; `drift-evaluator` verifies drift *from* the
frozen intent; the freeze sweep verifies the spec's mechanical truth —
satisfiability, broken or vacuous check lines, measured premises against the
repository and the live trackers. Nothing in that list verifies the spec
against **domain reality**: a wrong deployment-order assumption, a rollback
precondition that does not hold in production, a blast-radius claim about a
system this repository cannot measure. Issue #332 names the gap and the
workaround its author reached for by hand. This note defines `spec-review`, a
fourth dispatch axis alongside `implement`, `verify` (both in
`docs/loop-engineering/phase-multiplexing.md`) and `specify` (in
`docs/loop-engineering/spec-authorship-entry.md`), so electing an independent
cross-provider read of a spec's domain premises is a recorded routing
decision, priced the same way this repository's other dispatch notes price
theirs.

This note deliberately does not live inside `phase-multiplexing.md`. That file
carries T-1079's own frozen label-cardinality locks (exactly two
`- dispatch-axis:` lines, a `- dispatch-rule:` grammar closed over
`implement`/`verify` values only, exactly two `- dispatch-note:` lines),
T-1084's and T-1089's byte-locks — a fourth axis added there would turn
several of that file's own criteria red at once. A new note carries the
fourth axis instead, and the shipped record grammar
(`templates/prompt-blocks/dispatch-record.md`) already sources axis keys from
any priced dispatcher note rather than from one named file, so no further
generalization is owed there.

## Terms and closed vocabularies

- **`spec-review`** — the axis this note defines: whether an extra
  cross-provider `codex-reviewer` pass reads a spec's domain premises at the
  Specify seam, after the freeze sweep and before the `- intent-hash (v1)` is
  recorded. Decided at Plan and recorded at the existing Specify-to-Implement
  seam once `pm-spec` has created the task's board entry — no new seam, no
  new phase.
- **`none`** — the shipped default value: no extra pass runs, and nothing
  about the task changes.
- **`cross-provider`** — one extra `codex-reviewer` pass reads the spec
  document (the frozen intent block plus its declaration region, not a
  branch diff) and records a `## Spec review` section in the task's existing
  review record, routed back to the spec's author on `REQUEST_CHANGES`.
- **`domain-premise`** — issue #332's own criterion for when the extra pass
  is worth paying for: the spec's correctness rests on a domain-premise this
  repository cannot measure — a deployment or ordering assumption, a
  rollback precondition, a blast-radius claim about a system outside this
  repository's reach.
- **`undetermined`** — this note's convention for a priced field with
  nothing measured behind it: used in place of a guessed figure.

## The axis

- dispatch-axis: spec-review — none|cross-provider — whether an extra
  cross-provider `codex-reviewer` pass reviews a spec's domain premises at
  the Specify seam, before the intent hash is recorded.

## Rules

One rule per value, each carrying the modality it actually applies under and
a ground citing one of this note's own priced lines below.

- dispatch-rule: spec-review — none — unconditional — recommendation: spec-review-none-default — a routine mechanism task does not pay the extra round; this is the shipped default and needs no trigger to fire.
- dispatch-rule: spec-review — cross-provider — conditional — trigger: domain-premise — the spec's correctness rests on a domain-premise this repository cannot measure (a deployment or ordering assumption, a rollback precondition, a blast-radius claim about an external system) — cost-input: t1092-domain-premise-count

## Priced lines

- recommendation: spec-review-none-default — elect `none` by default whenever a task's correctness does not turn on a fact this repository cannot itself measure; the extra round earns its keep only against a domain-premise risk, and most mechanism tasks do not carry one.
- cost-input: t1092-domain-premise-count — the count of `**relayed**` premise lines this task's own `## Assumptions` section carries, at this task's own frozen spec-and-board-entry commit — a concrete instance of how many decision inputs a spec relays rather than measures first-hand, and therefore how many candidate domain-premise risks a spec-review round would have to weigh (measured: 8).
  - command: git show c23743d:.shell-team/specs/T-1092-specify-seam-review.md | grep -c '^- \*\*relayed'
  - measured-at: c23743d (this task's own frozen spec-and-board-entry commit)

## Invariant

- invariant-lock: both-gates-green — declared: an elected spec review is never one of the two gates and never substitutes for either. `qa-verifier`'s PASS and `codex-reviewer`'s APPROVE **on the delivered change** both remain required regardless of this axis's value.

## What this note does not measure

The actual saving from electing `cross-provider` over `none` — how often it
prevents a wrong-about-the-world spec from being implemented, or how many
rework rounds it avoids — is `undetermined`: no arm has run under this axis
yet (T-1092 ships no live end-to-end spec-review firing, per its own
Non-goals), and this note records that honestly rather than modelling a
figure nobody measured. The two priced lines above are honest cost inputs —
a default-routing recommendation and a relay-count proxy — not a saving
claim.
