# Playbook block-size deferral — twice measured, not re-adjudicated

**Task**: T-1023 · **Base ref**: `develop` (`7a64def`) · **Run context**: this
document is a decision record, not a runnable procedure — it accounts for two
measurements that already happened, and issues no command of its own.

## Why this document exists

`bin/gen-playbook-blocks.sh` warns, non-fatally, when a generated per-role
playbook block crosses `LINE_WARN_THRESHOLD=40` lines. Until this record
existed, the warning's remedy text pointed a reader at superseding stale
corpus entries — but that remedy has now been checked twice, by two different
measurements, on two different corpora, and both times found nothing to
supersede. Without a citable place holding that answer, the warning was a
standing invitation to launch a third check of a question two prior checks had
already answered. This document is that citable place: the warning now points
here instead of at a task, and a future reader can read the five claims below
instead of re-deriving them.

## Provenance of the two measurements

- The pre-publication repository ran an exhaustive pairwise domination sweep
  over all 74 then-active corpus entries on 2026-07-26 and found zero
  dominations. Issue #112 quotes that record in full and is the source this
  document ports it from.
- This repository's `.shell-team/specs/T-1020-supersede-adjudication.md`
  (issue #97) scored 24 candidates against a stricter three-condition
  predicate on 2026-08-03 and found exactly one ratifiable pair — `Scope:
  maintainer`, so zero block-line impact. Its section "What this accounting
  does and does not establish" is where the two measurements are named as
  different instruments pointing the same way rather than one mechanical
  all-pairs walk repeated twice; its section "Observations recorded, not
  acted on" already notes that the warning's own remedy text presumes a
  redundancy this corpus does not have — the observation this document exists
  to answer.
- Both measurements are cited here as answers already produced, not as an
  invitation to reproduce them: the four re-evaluation signals below, not a
  re-run of either sweep, are what would make a third measurement worth
  taking.

## Claims

- claim-1: The dilution that the 40-line threshold proxies for is a real mechanism, but at both measurements its harm was both unmeasured and unobserved — it was never measured and found to be small.
- claim-2: The value 40 in LINE_WARN_THRESHOLD=40 has no technical basis: it was a judgment call by one engineer, not a token budget and not a measured degradation point.
- claim-3: Two independent sweeps looked for retirement stock in the corpus and both found effectively none: the pre-publication exhaustive pairwise domination sweep of 2026-07-26 over all 74 then-active entries found zero dominations, and the T-1020 adjudication of 2026-08-03 in this repository scored 24 candidates against a stricter three-condition predicate and found exactly one ratifiable pair, which is Scope: maintainer and therefore has zero block-line impact.
- cause: Both measurements came out empty for the same reason: the promotion discipline writes positioning sentences at write time, so the corpus never accumulates retirement stock for a sweep to find.
- rejected-levers: The follow-up re-evaluation at the pre-publication measurement rejected every corpus-size lever it considered, on the ground that the dilution harm those levers would buy relief from was unmeasured and unobserved.
- claim-4: The instrument measures the wrong quantity: the warning counts per-role block lines, while the one cost that was observed to scale is retro dedup, which is O(n) in total corpus size.
- claim-5: Re-evaluation of this deferral is signal-driven and not scheduled: exactly four signals would reopen it, and they are listed in the signals block below.

None of the seven lines above weakens under paraphrase into a claim that the
mechanism's effect is small: claim-1 states the opposite of that directly, and
claim-4's wrong-quantity finding is a statement about what the instrument
measures, not a statement about the size of what it misses.

## Re-evaluation signals

- signal-1: Dilution is actually observed — an injected playbook block is measured to degrade the behaviour of the role it is injected into, instead of the harm being inferred from a line count.
- signal-2: Retro dedup becomes genuinely painful, so the one cost that was observed to scale starts actually costing a retro round.
- signal-3: The corpus grows by an order of magnitude beyond the roughly 80 entries measured here.
- signal-4: Loop throughput becomes high enough that the dilution harm can be measured for real rather than proxied.

Any one of the four is sufficient to reopen this deferral. None of the four
has fired as of this writing, and that absence — not an elapsed interval — is
the entire reason nothing further is queued against this record.

## What this record is not

- Not a claim about the mechanism's size: claim-1 says the mechanism is real
  and that its harm has never been measured, in either direction. This record
  does not go further than that in either direction, and a reader who wants to
  round it down to "the overage doesn't matter" is rounding past what claim-1
  actually says.
- Not a plan: no date governs when this deferral is checked again, and no one
  is holding it as a standing item to revisit. Reopening it depends only on
  whether one of the four signals above has actually fired — see claim-5 — and
  the absence of a fired signal is why nothing is queued, not a choice to defer
  action to a later point in time.
- Not a defense of the number 40: claim-2 already states that the threshold
  has no technical basis. Porting two measurements that found no retirement
  stock is not the same thing as supplying a basis for the number itself, and
  this record does not attempt to.
- Not a third sweep: this record reports what the two sweeps already run
  found. It adds no new count over the corpus, and running one is exactly what
  the four signals above gate rather than invite.
