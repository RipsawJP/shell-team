# Playbook bullet measurement — a design for finding out what each lesson still prevents

**Task**: T-1199 (issue #782). **What this is.** A design note. It describes how the four generated playbook blocks could be measured one lesson at a time, what the measurement would cost, and how a result could reach a removal decision. It runs no measurement and no model, it removes nothing, and it edits no lesson, block, agent or script.

The machinery inventory (`docs/loop-engineering/machinery-inventory.md`) marks all four blocks `verdict: unknown` because the live value of each bullet is not separately measured. Removing bullets by impression or by age is ruled out; this note is the step that makes a later, evidence-based decision possible.

## Unit measured

**The unit is the lessons entry** — one `## <date> — <title>` section of `.shell-team/lessons.md` — and not the rendered bullet and not the category.

- **Why not the rendered bullet.** `bin/gen-playbook-blocks.sh` emits one `Rule` line per qualifying entry into each role's block. An entry with `Applies-to: all` therefore appears as four bullets, one per block, and an entry with a comma list appears once per listed role. These renderings are copies of one decision. Every lever the corpus has acts on the entry: `Status`, `Scope` and `Superseded-by` live on the entry, and `bin/check-playbook.sh` validates entries. A measured result on a single rendering has no lever of its own to act on.
- **Why not the category.** `Category` is a small closed taxonomy (process, tooling-ci, security-pii and so on). A category bundles lessons that prevent unrelated failures, so a category-level result cannot say which lesson to keep. It is useful only as a reporting group.
- **Per-role strata.** An entry shared by several roles is measured once per role it renders into, because the same rule can matter to one role and be inert for another (an engineer can be steered by a rule that a tech-lead never meets). The result is a vector of per-role outcomes for one entry. The entry-level reading is deliberately conservative: an entry with `Applies-to: all` is a removal candidate only if **no** role shows an effect, and the removal is then of the entry, taking all of its renderings with it. If it shows an effect in one role only, the honest follow-up is narrowing `Applies-to`, which is an edit of the entry and is also a proposal subject to the same approval path.
- **Entries that appear in several blocks.** The issue #268 entry at `.shell-team/lessons.md` (the one whose digest ends "This entry retires when script-generated record tables (issue #268)") is one entry with `Applies-to: all`, rendered into all four blocks and into four agent files. It is one unit with four strata, not four bullets.

## How an effect is observed

Three evidence tiers, cheapest first. A lesson is carried as far down the tiers as its failure shape allows.

**Tier A — recorded-failure replay (no model run).** Each entry names its incident in `Source`, `Why` and its `Rule`. For each entry, read the telemetry after the entry's promotion date and ask whether the failure class the entry names has recurred: `rework` events (a review or QA bounce back to implementation) and `gate` events (a blocked or failed gate) in `.shell-team/runs/shell-team.jsonl`, joined to the board and review records of the same run. This tier cannot show that a lesson prevents anything — a quiet period is equally explained by the model no longer making the mistake and by the lesson working. What it can do is the reverse: it finds entries whose failure class **recurred despite** the lesson (the lesson is not sufficient, and is a candidate for strengthening, not removal) and it ranks the rest so that Tier B is spent on entries where a with/without difference is plausible.

**Tier B — single-entry ablation on a fixed task set.** Arms, for one role and one entry:

- control-none: the role's block with **no** playbook bullets at all;
- full: the role's current block;
- minus-one: the current block with exactly one entry removed.

Run each arm for a few repetitions on the same fixed subject, and score each run with a detector written beforehand for **that entry's named failure shape** (for example, "the hand-off states a count with no command beside it"), plus the subject's own oracle for pass/fail. The scratch install used for the arms **copies** the plugin files rather than linking the checkout, so an arm that rewrites a block edits the copy only.

**Tier C — not elicitable.** Entries whose failure shape cannot appear in a scratch run of the fixed subject are not measured by this design; see `## What this cannot measure`. They stay `unknown` and are not candidates.

**Reuse candidates, each read before being described here.**

- `docs/loop-engineering/tier2-subject-harness.md` — reused as the fixed subject for Tier B. It is a committed engineer-role implementation subject with an oracle and one recorded serial baseline (two repetitions, large spread between them). It is the only fixed task set the repository has, which is why Tier B is scoped to the engineer role. The pm-spec, qa-verifier and tech-lead strata have no fixed subject, so Tier B does not cover them without new subjects (new infrastructure, below).
- `.shell-team/runs/shell-team.jsonl` — reused as the Tier A source and as the cost source. Span rows carry `tokens` and `duration_ms`, but not always as numbers; the measurement of how often is under `## Cost of one measurement`.
- `bin/rollup-runs.sh` — reused to fold span rows into per-run token and duration totals when pricing a pilot after the fact. It skips event rows by design, so it cannot supply the Tier A `rework` and `gate` signal; that part is a direct read of the event rows.
- `bin/rollup-track.sh` — reused only as the way to persist one dated roll-up of a pilot's cost under the base directory as tracked history, since it wraps `bin/rollup-runs.sh` unchanged. It adds nothing to the measurement itself.
- `bin/derive-populations.sh` — reused for any set statement the result record makes (which entries were measured, which were Tier C, which were candidates): the record embeds its derivation block beside a `- reproduce:` line rather than counting entries by eye.
- `bin/gen-loop-replay.sh` — not evaluated: it renders one run's rows as an HTML replay page for a human to watch. It is a viewer, not a source of a with/without difference, so the design has no use for it.

## Still prevents versus no longer needed

Verdicts are per entry and per role stratum. A control arm is what separates "no longer needed" from "never tested".

- **still-prevents** — the minus-one arm shows the named failure shape in more runs than the full arm, over the pre-declared repetitions, and the control-none arm shows it too. The block is doing work on the current model, and this entry is part of it.
- **no-longer-needed candidate** — the control-none arm **does** show the named failure shape (so the subject can elicit it at all), while both the full arm and the minus-one arm show none. The model avoids the mistake without this entry. This is a candidate only; it is a proposal and not a removal.
- **covered-by-others** — the control-none arm shows the shape, the minus-one arm does not, and the full arm does not: another bullet, or the model itself, covers the ground. This is the case in which a successor could be named, and see `## From result to removal decision` for why that does not map cleanly onto today's retirement schema.
- **not-elicited** — the control-none arm does not show the failure shape either. The subject did not provoke the failure, so no with/without difference could appear. This is **not** evidence that the entry is no longer needed. It stays `unknown`.
- **inconclusive** — the arms disagree with the pre-declared direction, or the repetition-to-repetition spread is as large as the difference between arms. It stays `unknown`.

An entry is promoted from Tier B to a removal proposal only on `no-longer-needed candidate` or `covered-by-others` in every role stratum it renders into and was measured in, plus a Tier A reading that shows no recurrence of the failure class since the last time the rule was extended.

- not-a-criterion: age — an entry's age says nothing about whether the current model still makes the mistake it names; an old rule can still bind and a recent one can already be redundant, so neither the date in an entry's heading nor the time since its last `Extended by` is evidence for or against keeping it.

## Cost of one measurement

All values below are for one pilot of the design: Tier B on the engineer stratum for ten entries, three repetitions per arm-entry pair, plus three control-none repetitions. A full engineer-stratum sweep is priced beside it. Telemetry-derived means are per dispatch of the engineer role, taken over the most recent span rows that carry a number; the sample is small, so every product built on them is an estimate.

- cost: tokens — span rows carrying a numeric `tokens` among the most recent two hundred span rows: see command — derivation: F=.shell-team/runs/shell-team.jsonl; grep '"span":' $F | grep -v '"kind":"event"' | tail -n 200 | grep -c '"tokens":[0-9]'
- cost: tokens — span rows carrying a null `tokens` among the same two hundred — derivation: F=.shell-team/runs/shell-team.jsonl; grep '"span":' $F | grep -v '"kind":"event"' | tail -n 200 | grep -c '"tokens":null'
- cost: wall-clock — span rows carrying a numeric `duration_ms` among the same two hundred — derivation: F=.shell-team/runs/shell-team.jsonl; grep '"span":' $F | grep -v '"kind":"event"' | tail -n 200 | grep -c '"duration_ms":[0-9]'
- cost: tokens — engineer mean tokens per dispatch over the numeric rows of those two hundred — derivation: F=.shell-team/runs/shell-team.jsonl; grep '"span":' $F | grep -v '"kind":"event"' | tail -n 200 | grep '"span":"engineer"' | grep -o '"tokens":[0-9][0-9]*' | cut -d: -f2 | awk '{s+=$1;n++} END{print n, s/n}'
- cost: wall-clock — engineer mean duration per dispatch over the numeric rows of the same sample — derivation: F=.shell-team/runs/shell-team.jsonl; grep '"span":' $F | grep -v '"kind":"event"' | tail -n 200 | grep '"span":"engineer"' | grep -o '"duration_ms":[0-9][0-9]*' | cut -d: -f2 | awk '{s+=$1;n++} END{print n, s/n}'
- cost: runs — engineer-stratum renderings in the current block, an upper bound on engineer-stratum entries — derivation: grep -c '^- ' templates/prompt-blocks/playbook-engineer.md
- cost: runs — pilot, ten entries by three repetitions of minus-one plus three control-none repetitions, thirty-three engineer runs — estimate: ten chosen entries times three repetitions plus three control repetitions; the repetition count is a design choice, three being the smallest that shows any spread at all, not a power calculation
- cost: wall-clock — pilot, about seven and a half serial hours — estimate: thirty-three runs times the sampled engineer mean duration (about thirteen and a half minutes per run), serial because the fixed subject is run one arm at a time on one host; the tier-2 harness's own two recorded repetitions spread by nearly a factor of two, so the true figure can be well off
- cost: tokens — pilot, about five and a third million tokens — estimate: thirty-three runs times the sampled engineer mean tokens per dispatch; this prices the engineer role only and omits any judging or detector pass
- cost: runs — full engineer-stratum sweep, two hundred and sixty-one runs — estimate: eighty-seven rendered engineer bullets as an upper bound on entries, three repetitions each; the real number is lower because Tier C entries drop out
- cost: wall-clock — full engineer-stratum sweep, about fifty-eight serial hours — estimate: two hundred and sixty-one runs times the same sampled mean duration
- cost: tokens — full engineer-stratum sweep, about forty-two and a half million tokens — estimate: two hundred and sixty-one runs times the same sampled mean tokens
- cost: host — one approval before any run, then one approval per removal proposal; no other host action — estimate: the design reuses the committed subject and the existing telemetry, so it asks for no input during a run; the person starting the run is the coordinating session, not the host

**What the host does.** Approves launching a pilot (one decision), and later approves or declines each removal proposal the pilot produces (one decision per proposal, see `## From result to removal decision`). Nothing is typed, pasted or run by the host in between. The cost to the host is the reading of a results table, not operating a measurement.

**New infrastructure, stated plainly.** Tier A needs none beyond a short query over the existing telemetry and lessons file. Tier B needs three things that do not exist today, and each would be its own task: a scratch-install builder that copies the plugin tree and removes one entry's bullet from one block; a per-entry failure-shape detector (for each measured entry, a command that reads a run's outputs and says whether the named failure appeared); and a driver that runs the arms in a fixed order and records the scores. The pm-spec, qa-verifier and tech-lead strata additionally need fixed subjects of their own. None of this is built here.

**Other figures, labelled.** The entry total and the per-role rendering counts quoted in prose elsewhere in this note are not stated; every population figure sits on a `- cost:` line above with its command.

## From result to removal decision

A measurement result is a proposal. The path from a proposal to a change:

1. **The measurement record** lists, for each measured entry and role stratum, the verdict word from `## Still prevents versus no longer needed`, the run records behind it, and the derivation blocks for every set claim.
2. **The operator approves or declines each proposed removal or narrowing.** The approval comes first. The inventory's own rule (`docs/loop-engineering/machinery-inventory.md`, `## Verdict scope`) is that follow-up issues are filed only after review, one per approved removal or simplification; a measured candidate gets no earlier or looser treatment than an inventory verdict does.
3. **The record kept** is the measurement record plus one line per decision (approved or declined, by whom, on what date), in the task's own spec or board entry, so that a declined candidate is not re-proposed without new evidence.
4. **Only then** is an issue filed for the approved change, and the change is made by the ordinary promotion path (human-approved, schema-checked, regenerated blocks).

**The retirement-schema gap.** The existing retirement mechanism is `Status: superseded` with a `Superseded-by` pointer that names an `active` entry covering the same ground. `bin/check-playbook.sh` refuses a `superseded` entry whose `Superseded-by` is missing or empty ("a retired entry must name its replacement"), and also a dangling pointer, a self-reference, or a chain into another superseded entry. So a lesson judged **no longer needed**, because the model avoids the mistake on its own, has no successor entry to point at, and has no conforming retirement path today. `covered-by-others` can map onto it only if one single active entry actually covers the ground. This note describes that gap and does not close it. A schema change (for example a retirement status that needs no successor) is a possible future option, stated as such, and it would be its own approved task.

**`Scope: maintainer` is the other existing lever.** An entry moved to `Scope: maintainer` stays in the corpus bound to a repository-local file and is never emitted into a shipped block, so it leaves every generated block without being deleted from the log. It fits an entry that is still true for this repository's own maintainers but no longer helps adopter roles. It is an edit of the entry and goes through the same approval path.

## What this cannot measure

- **Rare, severe failures.** A lesson that guards against a leak, a destructive command or a secret in history has a base rate that a handful of scratch runs will never elicit. Zero occurrences across the arms says nothing about it. These entries are Tier C by construction.
- **Behaviour outside the fixed subject.** The only fixed subject is an engineer-role implementation task. Lessons about spec writing, QA verification, board edits, dispatch discipline, review briefings, human gates or record formats cannot be elicited by it, and the other three roles have no fixed subject at all.
- **A single model on a single day.** Any result describes the model that ran. A different model, or the same one after an update, can change every verdict, so a result has a shelf life it cannot state.
- **Small effects under large spread.** The one recorded baseline for the fixed subject has two repetitions whose durations differ by nearly a factor of two. Three repetitions per arm cannot separate a small effect from that noise; only large effects register, and a small real effect reads as `inconclusive`.
- **Interaction between bullets.** One-entry removal measures an entry's marginal effect given the other bullets. Two entries that each cover for the other would each read `covered-by-others`, and removing both is not tested by removing either.
- **Dilution.** Removing one bullet changes the block by a negligible amount, so this design cannot observe whether the block as a whole degrades the role. That would take whole-block arms, which is a different and larger design.
- **Cost in the other direction.** The design measures what a bullet prevents; it does not price the tokens the bullet costs on every dispatch beyond the cost lines above.
- **Telemetry coverage.** A substantial share of recent span rows carry a null token count (the first cost lines show how many), so any cost taken from telemetry rests on the rows that have one.
- **Roles outside the four.** Only the four roles that receive a generated block are in scope; no result speaks for any other role.

## Verdict scope

The consumer of this note is the operator and the planning that decides whether to run a measurement and what to remove afterwards. It is an internal design note: no adopter executes it and no gate reads it. It runs no measurement and no model; every figure it gives is either derived by the command beside it or labelled an estimate with its basis. Any measurement result the design describes is a proposal: a verdict word is a reading of runs under stated conditions, never a decision, and an approved removal is a separate step with its own record. The cost-line derivation commands prove their own form here; whether one reproduces its value is a reading item for whoever re-runs it.

## Relation to the block-size deferral

`docs/loop-engineering/playbook-block-size-deferral.md` records that the line-count warning on the generated blocks was twice checked for retirement stock without finding any, and that block-size harm was never measured. This note is consistent with its claims 1 to 5 and does not reopen them.

- **What this measures.** The effect of each entry — whether removing it changes what the role does — not block size and not retirement stock. It is therefore not a third sweep of the corpus for entries that dominate each other (claim-3), and it does not defend or replace the line threshold (claim-2) or the choice of quantity the warning counts (claim-4). Re-evaluation stays signal-driven (claim-5).
- **claim-1 and signal-1.** claim-1 says the dilution harm is real as a mechanism but was unmeasured, in either direction. signal-1 is "an injected playbook block is measured to degrade the behaviour of the role it is injected into". A single-entry ablation does not observe that: it changes the block by one bullet. If a future run of this design happened to show a whole-block arm outperforming the full block on the same subject, that would be a signal-1 observation and would be recorded as one; nothing here claims signal-1 has fired, and the design as written does not produce that observation.

## Bullets that state their own retirement condition

Some entries carry the condition under which they should go. The one on record is the issue #268 entry: its `Rule` ends "This entry retires when script-generated record tables (issue #268) remove the recall-written numeric prose it guards", and the sentence is rendered into each of the four blocks and four agent files (it is a single `Applies-to: all` entry; see `## Unit measured`).

The design places such a bullet **outside** the ablation path. Its retirement is decided by whether the stated condition has come true, which is a fact about the repository (is the numeric prose it guards now produced by a script?) and not an effect to be measured on a model. It is checked by reading, at approval time, and is a proposal like any other. Measuring it as well would be redundant, and a quiet ablation could not distinguish "the condition holds" from "the subject did not elicit the mistake". When the condition holds, the entry is a retirement proposal; until it holds, it is excluded from Tier B and kept. Whether the entry would then retire through `Superseded-by` or through `Scope: maintainer` depends on whether a successor entry exists, which is the schema gap described under `## From result to removal decision`.
