# Means-ends reflection: the worked example (T-1095, issue #346)

This note is the one worked example the means-ends reflection duty
(`templates/prompt-blocks/means-ends-reflection.md`, mirrored into
`skills/run/SKILL.md` step 5, step 6, and `skills/goal/SKILL.md`'s Decide
list) currently rests on. It is built from a single live firing, recorded on
the board rather than invented for this note, and it carries the norm's own
bound with it so a reader who never opens the frozen spec still sees the
weight this evidence actually has.

## The firing

T-1093 (the verification-ceiling task) reached `STOP:max_iterations_reached`
at delivered-change review round 3: three consecutive rounds had each landed
an independent Major in the same area — the `## Blast radius` read-set's
completeness against a corpus of 98 tracked specs, one new reader-channel
gap found each round (a literal-path reader, then a run-time path
indirection, then a full-corpus glob). Before composing the STOP escalation,
the orchestrator answered the reflection's four questions in writing:

1. **Is every item of the never-dropped set green?** Yes — the ceiling
   declaration grammar, the QA/board carry, the freeze gate and the
   adopter-facing docs were all already shipped and reviewer-confirmed; only
   the read-set's own completeness kept drawing findings.
2. **Which findings target which auxiliary components?** All three Majors
   targeted the same auxiliary component: the `## Blast radius` verification
   bookkeeping, specifically its channel-by-channel reader enumeration — a
   class this repository had already measured as non-convergent by
   enumeration (T-1092, six adversarial rounds, a fresh defeat every round).
3. **In what drop order did the pre-commitment record a disposition for it,
   and does one exist?** The spec's own pre-commitment priced exactly this
   trade at freeze time: rather than enumerate a fourth reader channel, close
   the class structurally by switching from channel enumeration to
   population coverage — the merged spec corpus is finite, so running every
   criterion against every spec on both sides of the base ref makes no
   enumeration gap possible in principle, regardless of how many reader
   idioms exist. 94 of 98 specs were already covered by the prior fan-out and
   indirection sweeps; the remaining 4 were run live on both sides in the
   same sitting.
4. **What is the aggregate cost against the next pre-priced exit?** Eight
   `check-acs.sh` runs against the four uncovered specs, versus one more
   review round spent enumerating a fourth reader idiom that the prior three
   rounds' own pattern made likely to be followed by a fifth.

## The disposition and its authority

Every item of the never-dropped set was green, every finding targeted the
one named auxiliary component, and a pre-priced disposition existed for it —
all three execution conditions held, so the disposition (population
coverage, closing the class rather than patching the third instance)
executed on the loop's own authority and was recorded on the board with the
four answers as its ground, rather than being escalated as one option beside
a cheaper-looking fourth patch. **AI self-discipline** is the authorship
class this disposition belongs to: the pre-commitment was self-imposed by
this loop at the task's own plan and freeze time, never operator-ratified,
and the board record for this firing names that class explicitly rather than
leaving a reader to infer who authorized it. The **standing loop-escape
instruction** the orchestrator ran this reflection under is the operator's
own instruction of 2026-08-23; the T-1093 loop-escape board record closes
with the same sentence this norm generalizes: "Executed on the orchestrator's
own authority per the operator's standing loop-escape instruction
(2026-08-23); the remaining human gates (batch GO, planning, destructive
ops) are untouched." Commit `a0c3c38` is the commit that carries that board
record.

## The bound: n=1, stated as n=1

This example is the ONLY live firing this norm has been measured against —
**n=1** — and the norm text itself, not just this note, says so rather than
presenting one success as an established pattern. Two things bound a
standing rule grounded in one firing. First, structurally: the norm's own
four-case exception set gates every future firing regardless of how many
have occurred, and every execution is recorded on the board, so a wrong
generalization stays visible in the record instead of failing silently.
Second, by a stated **re-evaluation trigger**: **while at most three live firings are recorded**, the retro following the cycle in which each firing occurred re-reads this norm's standing against the board's own loop-escape records as the ledger — the retro following the third firing is deliberately inside that bound, because that retro is the confirming read the three-firing threshold exists to obtain, and a bound that excluded it would graduate the norm to permanent standing at exactly the point whose review was supposed to confirm it. A re-read that finds a firing whose shape departs
from T-1093's returns the norm to planning rather than amending it in place.

Issue **#346** is the originating requirement this norm and this worked
example both trace back to.
