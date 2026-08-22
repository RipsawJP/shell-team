# The `specify` axis: spec authorship as a dispatch decision (T-1091)

Every task's spec has an author. Until this note existed, that author was an
implicit assumption — `pm-spec`, always — rather than a decision anyone
recorded or priced. Issue #331 names the cost of that implicitness: in a
hub-and-spoke setup (an orchestrator resident in a coordination repo,
implementation in separate repos), the decision inputs for an accuracy-critical
change already live in the coordinating session's own context, and delegating
authorship to `pm-spec` there converts verified first-hand facts into relayed
ones for no benefit. This note defines `specify`, a third dispatch axis
alongside `implement` and `verify` (both defined in
`docs/loop-engineering/phase-multiplexing.md`), so the authorship choice is a
recorded routing decision like any other, priced the same way this
repository's other dispatch notes price theirs.

This note deliberately does not live inside `phase-multiplexing.md`. That file
carries T-1079's own frozen label-cardinality locks (exactly two
`- dispatch-axis:` lines, a `- dispatch-rule:` grammar closed over
`implement`/`verify` values only, exactly two `- dispatch-note:` lines) and
T-1084's byte-lock — a third axis added there would turn three of that file's
own criteria red at once. A new note carries the third axis instead, and the
shipped record grammar (`templates/prompt-blocks/dispatch-record.md`) is
generalized to source axis keys from any priced dispatcher note rather than
from one named file.

## Terms and closed vocabularies

- **`specify`** — the axis this note defines: which party authors a task's
  spec. Decided at Plan, alongside `implement` and `verify`, and recorded at
  the existing Specify-to-Implement seam once `pm-spec` has created the
  task's board entry — no new seam, no new phase.
- **`pm-authored`** — the shipped default value: `pm-spec` authors the spec,
  exactly as `agents/pm-spec.md`'s `## Your job` describes today.
- **`operator-authored`** — the coordinating session (the operator) has
  already authored the spec. `pm-spec` then participates as a **conformance
  formatter** rather than as an author — see `agents/pm-spec.md`'s
  `## Conformance-formatter mode (T-1091)` section for the per-item boundary
  between what it may fix in place and what it must flag back to the author.
- **`judgment-density`** — issue #331's own criterion for when delegating
  spec authorship is worthless: the decision inputs (measured facts across
  repositories, live-environment confirmations, incident history) already
  live in the coordinating session's own context, so relaying them to a
  formalizer converts verified first-hand facts into relayed ones for no
  benefit — the formalizer earns its keep when formalization itself is the
  bottleneck, not when integrating already-verified facts is.
- **`undetermined`** — this note's convention for a priced field with
  nothing measured behind it: used in place of a guessed figure.

## The axis

- dispatch-axis: specify — pm-authored|operator-authored — which party
  authors the task's spec; decided at Plan and recorded at the existing
  Specify-to-Implement seam.

## Rules

One rule per value, each carrying the modality it actually applies under and
a ground citing one of this note's own priced lines below.

- dispatch-rule: specify — pm-authored — unconditional — recommendation: pm-authored-default — pm-spec authors unless something says otherwise; this is the shipped default and needs no trigger to fire.
- dispatch-rule: specify — operator-authored — conditional — trigger: judgment-density — the task's decision inputs live in the coordinating session's own context (issue #331's hub-and-spoke case), where delegating spec authorship to pm-spec has arithmetically zero value because writing a complete hand-off package already is writing the spec — cost-input: t1091-relay-count

## Priced lines

- recommendation: pm-authored-default — pm-spec authors by default whenever a task's decision inputs are not concentrated in one session's own context; formalization is pm-spec's comparative advantage, and most tasks fit this shape.
- cost-input: t1091-relay-count — the count of `**relayed**` premise lines T-1091's own `## Assumptions` section carries, at that task's own frozen spec-and-board-entry commit — a concrete instance of how many decision inputs a hub-and-spoke task's spec relays rather than measures first-hand (measured: 6).
  - command: git show 6cbd845:.shell-team/specs/T-1091-operator-authored-entry.md | grep -c '^- \*\*relayed'
  - measured-at: 6cbd845 (T-1091's own frozen spec + board-entry commit)
- cost-input: rounds-to-approve-series — the total count of `### Codex Review verdict` headings across every `.shell-team/reviews/*.md` file at this task's own branch point — the closest recorded proxy this repository carries for how many review rounds a task needs before APPROVE (measured: 213).
  - command: git ls-tree -r --name-only 1fca08c313b634d03c4e88e1bf06b6ca4d7a19c6 -- .shell-team/reviews | grep '\.md$' | while read -r f; do git show 1fca08c313b634d03c4e88e1bf06b6ca4d7a19c6:"$f"; done | grep -c '^### Codex Review verdict'
  - measured-at: 1fca08c313b634d03c4e88e1bf06b6ca4d7a19c6 (this task's own branch point)

## What this note does not measure

The actual saving from routing a task `operator-authored` instead of
`pm-authored` — how often it avoids a rework round, or how much wall-clock
time it saves — is `undetermined`: no arm has run under this axis yet (T-1091
ships no live end-to-end operator-authored run, per its own Non-goals), and
this note records that honestly rather than modelling a figure nobody
measured. The two priced lines above are honest cost inputs — a relay count
and a rounds-to-approve proxy — not a saving claim.
