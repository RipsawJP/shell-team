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

## The third obligation promoted into arm A (T-1099, 2026-08-25)

Applying the rule a third time, to the duplicate-structural-heading
obligation issue **#301** describes: its verdict **gates a loop
transition** — the new CI step's exit status gates a pull request, and a
board whose structural headings are broken is a board every later phase
gate reads — and its judgment — does each of `## Active`/`## Done` occur
exactly once, and does every other top-level heading occur at most once —
is **mechanically executable from committed bytes**, being a count of
heading lines in one file. Both conjuncts hold, so this obligation takes
**arm A** too. Its structural form is satisfied by an existing arm-A
script rather than a new one: the assertion lands inside
`bin/check-board-headings.sh` (already a named `bin/` script with its own
`tests/check-board-headings/run.sh` suite and its own CI step), beside the
base-relative `T-NNN` id-diff judgment that script already owns.

This is the **third** obligation promoted into arm A, after **#341**
(`bin/check-entry-mode.sh`) and **#344** (`bin/check-spec-review.sh`)
above — which is precisely the condition this note's own re-evaluation
trigger names ("the promotion of a third obligation into arm A"). **T-1099's
own promotion is what fires that trigger**, and it is owed at the next
retro following this task; the trigger counts obligations, not scripts, so
reusing an existing arm-A script for this third promotion makes the
promotion cheap, not absent.

## The fourth obligation promoted into arm A (T-1103, issue #343, 2026-08-28)

Selectable oversight profiles (T-1103) name three duties, and the rule
sends them to two different arms. **Duty A** — does a conformant
`- oversight-approval (<seam>):` record exist for a declared seam, and is
its `approver` handle distinct from its `producer` handle — applies the
rule directly: its verdict gates a freeze (`specify-seam`) and a close-out
(`pre-merge`), two of the three loop transitions this note's own
parenthetical names, and its judgment (a line match, a field extraction, a
charset test and a string inequality over committed bytes) is mechanically
executable from committed bytes. Both conjuncts hold, so this duty takes
**arm-A-tested-primitive**: `bin/check-oversight.sh`, a named `bin/` script
with its own `tests/check-oversight/run.sh` suite and its own step in
`.github/workflows/check-handoff.yml`, invoked by every caller as a
subprocess rather than re-implemented inline.

**Duty B** — profile resolution (which profile is in force, and which
seams it declares) — looks at first glance like configuration reading
rather than a gated judgment. The **reclassification clause** applies
directly, exactly as it does above: a resolution that silently answered
`autonomous` for an unreadable or malformed declaration would let duty A's
verdict pass vacuously at every declared seam at once, so duty B
**reclassifies** into arm A, with fail-closed refusal on every occupancy
and grammar case the declaration can present.

**Duty C** — the approval's substance (did the approver actually read and
approve the artifact) and the handle's ownership (is the handle theirs) —
fails conjunct 2 outright: no judgment over committed bytes distinguishes a
substantive approval from a waved-through one, and nothing in a git
repository binds an opaque handle to a person. This duty takes
**arm-B-enumerated-instrument**: a `disclosed, not closed` eleven-item
enumeration in the task's own spec Goal section, never a check line.

This is the **fourth** obligation promoted into arm A, after **#341**
(`bin/check-entry-mode.sh`), **#344** (`bin/check-spec-review.sh`) and the
third promotion above (T-1099, inside `bin/check-board-headings.sh`). The
re-evaluation trigger already fired on the third promotion, so this fourth
one does not fire it again; discharging it stays owed at a retro.

## The fifth obligation promoted into arm A (T-1104, issue #335, 2026-08-29)

Review-input fidelity (T-1104) names four duties over a review record's
per-pass grammar, and the rule sends two of them to arm A and two to arm
B. **Duty A** — the record-grammar gate (does every executor pass a record
declares carry all four of its fields exactly once, with each
closed-vocabulary field's value inside its vocabulary and each pass id
inside its charset) — applies the rule directly: its verdict gates a
close-out, one of the three loop transitions this note's own parenthetical
names, reached through the sibling-checker wiring `bin/close-out.sh`
already establishes for every other arm-A obligation, and the judgment is
a set of anchored line matches, a field extraction, a membership test over
two closed token sets and a charset test, all over committed record bytes.
Both conjuncts hold, so this duty takes **arm-A-tested-primitive**:
`bin/check-review-input.sh`, a named script under `bin/` with its own
`tests/check-review-input/run.sh` suite and its own step in
`.github/workflows/check-handoff.yml`, invoked by every caller as a
subprocess rather than re-implemented inline.

**Duty B** — the cross-round raw-basename collision (do two executor
passes anywhere in one record name the same raw-capture stem) — shares
duty A's first conjunct (the same close-out gate) and its second conjunct
is likewise a duplicate test over the values of one anchored field family,
read from the record's own committed text, never a file on disk. Both hold
→ **arm A**, and its structural form is satisfied inside the same new
script rather than by a second one — the shape the third promotion above
(T-1099, landed inside the existing `bin/check-board-headings.sh`)
established.

**Duty C** — the raw capture's presence on disk (does the file a record's
`raw-capture` field names actually exist beside the canonical target) —
fails conjunct 2 outright: `/.gitignore` ignores a review record's raw
`.txt`/`.json`/`.jsonl` captures, locked by
`tests/gitignore-raw-dumps/run.sh`, so a raw is untracked by construction
and no judgment over committed bytes can see it. This duty takes
**arm-B-enumerated-instrument**: a `disclosed, not closed` enumeration in
the task's own spec Goal section, never a check line. A local-only opt-in
read (a flag whose verdict is never wired into a CI step) was considered
and declined, because it would ship a second reading surface — a
filesystem read — into a checker whose entire value is one fail-closed
grammar read over text, for a verdict no gate may ever consult.

**Duty D** — whether the briefing content genuinely reached the executor
(did the round's verdict-scope and severity-calibration briefing actually
land in the model's context, and did it act on it) — also fails conjunct
2: the record can state which channel carried the briefing into a given
invocation, but no judgment over committed bytes distinguishes a briefing
that reached a model's context from one that was written and never
delivered, and for the primary pass there is provably no prompt channel to
carry it at all (`agents/codex-reviewer.md`'s primary-pass invocation
carries no prompt argument of any kind). This duty likewise takes
**arm-B-enumerated-instrument**, a `disclosed, not closed` enumeration in
the same frozen Goal section, in the duty-C shape the fourth promotion
above established.

This is the **fifth** obligation promoted into arm A (duties A and B are
one promotion in this note's own counting, which counts obligations
rather than scripts, and duty B reuses this task's own new script exactly
as the third promotion reused an existing one), after **#341**
(`bin/check-entry-mode.sh`), **#344** (`bin/check-spec-review.sh`), the
third promotion (T-1099, inside `bin/check-board-headings.sh`) and the
fourth promotion above (T-1103, `bin/check-oversight.sh`). The
re-evaluation trigger fires on "the promotion of a third obligation into
arm A" and already fired on the third promotion; it was explicitly not
re-fired by the fourth, and a fifth promotion likewise does not re-fire
it — discharging it stays owed at a retro rather than here.
