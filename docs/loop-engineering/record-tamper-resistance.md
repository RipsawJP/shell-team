# Record tamper-resistance: which obligations get a tested primitive (#336)

Three issues describe one gap from three angles (#336, #341, #344). #336
asks the umbrella question directly: this repository has now measured, five
adversarial rounds in a row, that a spec's own inline `- check:` line cannot
be made adversarially complete by enumeration, while the shipped `bin/`
checker layer has never been defeated once. Given that measurement, which
mechanism does this repository use for a record-checking obligation whose
correctness actually matters for a loop transition? This note records the
decision as `tamper-arm-rule-v1` (T-1096) — a criticality-scoped combination,
option (C) among the three the issue sketched, chosen because neither pure
arm survives its own measurement: promoting **every** recurring judgment
into a tested `bin/` primitive is unbounded over a spec corpus that grows
every cycle, while demoting **every** check to a reviewed instrument moves a
gating verdict from the layer this repository has actually measured as
holding to the layer it has measured as falling.

## The rule as a decision procedure

`tamper-arm-rule-v1` is a decision procedure over two prescriptive questions,
asked in this order, about an obligation — never an observation of which
scripts happen to exist today:

1. **Will the obligation's verdict gate a loop transition** (a status-flag
   advance, a freeze, or a close-out — this is what "gates a loop
   transition" means here) **and is the judgment it makes mechanically
   executable from committed bytes by a script?** Both yes:
   the obligation is tamper-relevant and takes **arm-A-tested-primitive** —
   a named script under `bin/` with its own `tests/<name>/run.sh` suite and
   its own step in `.github/workflows/check-handoff.yml`, invoked by every
   caller as a subprocess rather than re-implemented inline. **Both
   conjuncts are prescriptive tests on the obligation's own consequence and
   content, never observations of what happens to exist today**: where no
   shipped script executes an arm-A obligation yet, that is an
   **implementation gap** to close, and it is **never evidence for arm B**.
   Phrasing question 1 this way matters precisely because an observational
   reading ("is it executed by a shipped script?") has no answer for an
   obligation nobody has built yet, and would route every genuinely new
   obligation to arm B by default — describing which arm was chosen
   elsewhere rather than deciding it.
2. **Otherwise** — the verdict gates nothing beyond a single spec's own
   acceptance report, or the judgment is not mechanically executable from
   committed bytes — the obligation takes **arm-B-enumerated-instrument**:
   the check line or the read is an enumerated-case instrument, review reads
   it for computed values, conclusion direction and real instrument defects
   at the depth the artifact's consumer class earns, and adversarial
   guard-completeness is not a Major. This is the operator's **2026-08-22**
   interim re-pricing for dev-scaffold inline check lines, and it **stays in
   force** — it is not reopened by this decision.

## What decides the arm, and what never does

The arm follows **what the obligation's verdict gates and whether its
judgment is mechanically executable** — never by what the obligation is
about, and never by which scripts happen to exist. A check line whose
*subject* is a `bin/` script's own behaviour still takes arm B for the check
line itself, while that behaviour is covered by that script's own suite
under arm A.

**Reclassification is part of the rule, not an exception to it**: an
obligation sitting in arm B whose defeat would let a tamper-relevant verdict
pass is **reclassified to arm A**. This is #336's own second pickup trigger
("immediately if a tamper-class defect is found in a shipped checker").

## Re-evaluation trigger

This decision ships with a **re-evaluation trigger** rather than as
unconditionally settled: the rule is re-read at the first retro following
either a **defeat of a shipped** `bin/` checker — which would invalidate the
control observation arm A's whole justification rests on — or the promotion
of a third obligation into arm A, whichever comes first.

## The two obligations this task sends to arm A

Applying the rule: **#341**'s verdict gates a freeze, and its judgment — do
two committed board sub-bullets exist and agree, and does every gap id carry
a resolution — is executable from committed bytes. **#344**'s verdict gates
a close-out, and its judgment — is the last conformant verdict line an
approval — is likewise executable. Both conjuncts hold for both, so both
take arm A: `bin/check-entry-mode.sh` (#341) and `bin/check-spec-review.sh`
(#344), each a callable script with its own suite and its own CI step —
never an invented `bin/lib/` sourcing convention, since `bin/` carries no
sourcing pattern anywhere in this repository.
