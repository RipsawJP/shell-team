# Lessons corpus import disposition

This ledger records the disposition of every entry considered for import into
`$(bash bin/team-paths.sh --get lessons)` (`.shell-team/lessons.md` on this
repository's layout). It answers, for each entry, "why is this rule (or is it
not) in the corpus?" — the routing criterion this repository's checker forces
but does not itself record.

There are two independent tables. The **import table** carries one row for
each of the 79 entries measured in the source corpus (76 `active`, 3
`superseded`), keyed by the source entry's date plus its 1-based sequence
number among entries sharing that date, in source file order — never by the
entry's title, which would carry the content being translated into the record
of the translation. The **candidate table** carries one row for each of the
nine lesson candidates a prior retro raised, keyed by their 1-based position in
that retro's candidate list.

Every row names exactly one outcome. The import table's outcome is one of
`loop` (ships in the corpus, into every adopter's shipped playbook blocks),
`maintainer` (stays in the corpus, bound to a repository-local file, never
shipped), `operator-global` (tool-behavior knowledge useful across any
project, not specific to this repository — does not enter this repository),
or `drop` (knowledge tied to a convention this repository no longer uses —
does not enter this repository). The candidate table's outcome is one of
those four plus a fifth, `already-covered` (the candidate restates a lesson
the imported corpus already carries — recording that as a plain `drop` would
lose the distinction between "not worth keeping" and "already kept").

A retained row's destination is the corpus entry key it became; every other
row's destination is exactly `n/a`. A drop, an operator-global exclusion, and
an already-covered restatement are each justified on the entry's own merits —
never to hit a count — and none of the three carries a real employer name, a
customer name, an internal ticket identifier, or a hostname in its reason.

## Import table (79 rows)

Columns: source date, per-date sequence, outcome, one-line reason, destination.

| 2026-04-29 | 1 | loop | Establishes the cross-provider review requirement any repository running this loop needs. | 2026-04-29 — Bootstrap |
| 2026-06-12 | 1 | drop | Keyed to an epic task-number reservation convention this repository's task-numbering scheme has replaced. | n/a |
| 2026-06-12 | 2 | loop | General cross-provider review-gate discipline useful to any repository running this loop. | 2026-06-12 — Review gate caught a regression in practice (cross-provider review vindicated) |
| 2026-06-13 | 1 | loop | General guidance on running the review step synchronously, useful to any repository running this loop. | 2026-06-13 — Codex review runs synchronously (background inside a sub-agent never materializes) |
| 2026-06-13 | 2 | maintainer | Specific to this plugin's own release procedure (the manifest version and README badge). | 2026-06-13 — Release: keep the version of record (`plugin.json`) and the README badge in sync (machine-enforced) |
| 2026-06-13 | 3 | operator-global | A general git/GitHub fact about scrubbing history before a repository goes public, not specific to this one. | n/a |
| 2026-06-13 | 4 | loop | General documentation discipline for writing about PII scrubbing, useful to any repository. | 2026-06-13 — Don't transcribe real PII values in documents that describe scrubbing PII |
| 2026-06-14 | 1 | loop | General QA/engineer evidence discipline for runtime acceptance criteria. | 2026-06-14 — Don't mark a runtime user-verify AC done until evidence for its own pass criterion exists (two ACs mis-recorded back to back) |
| 2026-06-13 | 5 | loop | Historical record of a since-superseded review workaround, kept for context. | 2026-06-13 — Don't take a Codex inline-paste review's false positive at face value |
| 2026-06-15 | 1 | loop | General software design discipline for introducing a configurable path. | 2026-06-15 — Introducing a configurable base dir needs a full consumer inventory and untrusted-input validation together |
| 2026-06-15 | 2 | operator-global | A fact about the agent harness's own tool-call lifecycle, not specific to this repository. | n/a |
| 2026-06-17 | 1 | loop | The board's line format is shipped to every adopter running this loop. | 2026-06-17 — The board's `- [ ]` lines follow check-handoff's strict format; don't wedge a note between the flag and `— spec:` |
| 2026-06-17 | 2 | maintainer | A decision about this plugin's own self-improvement-loop tooling. | 2026-06-17 — Adding score-driven eval to the self-improvement loop has limited marginal value at this scale |
| 2026-06-17 | 3 | loop | General guidance on worktree isolation timing, useful to any repository running this loop. | 2026-06-17 — While a spec is still uncommitted on a feature branch, run the engineer step inline instead of in a worktree |
| 2026-06-17 | 4 | maintainer | Specific to how this plugin's own distributed bin scripts must resolve paths. | 2026-06-17 — A distributed `bin/` script should run relative to the caller's cwd / the adopted repo, not its own install location |
| 2026-06-18 | 1 | loop | General acceptance-criteria design discipline for self-hosting a negative check. | 2026-06-18 — A self-hosted negative `check:` can false-positive on the spec's own mention of the token it forbids |
| 2026-06-18 | 2 | maintainer | Specific to this repository's own CI shellcheck configuration. | 2026-06-18 — CI's shellcheck is older than the local one and flags info-level issues as failures; avoid the "A-and-B-or-C" idiom in test scripts |
| 2026-06-18 | 3 | operator-global | A personal workflow habit about confirming a branch, not specific to this loop's mechanics. | n/a |
| 2026-07-06 | 1 | operator-global | A sandbox-environment fact about the agent's own tool constraints, not specific to this repository. | n/a |
| 2026-07-12 | 1 | loop | General spec-writing discipline for cross-cutting fixes, useful to any repository. | 2026-07-12 — Cross-cutting-discipline ACs must specify the mechanism, not just the outcome |
| 2026-07-12 | 2 | loop | General regression-fixture design discipline, useful to any repository. | 2026-07-12 — Regression fixtures must cross the boundary and assertions must check final state, not that the mechanism fired |
| 2026-07-12 | 3 | loop | General engineering discipline for verification-subsystem redesign, useful to any repository. | 2026-07-12 — Two consecutive rounds of new Blocker/Major findings against a verification subsystem should trigger a redesign, not another patch |
| 2026-07-12 | 4 | loop | General verification discipline about stale remote-ref assertions, useful to any repository. | 2026-07-12 — A "whole artifact exits 0" assertion can false-pass against a stale remote-tracking ref — narrow the assertion instead |
| 2026-07-12 | 5 | loop | General retro-tracking discipline for newly-written behavioral rules. | 2026-07-12 — Track whether a newly-written behavioral rule actually got applied, in the retro one or two cycles later |
| 2026-07-12 | 6 | loop | General spec-writing discipline for parser/consumer tasks. | 2026-07-12 — A parser/consumer task's spec must cite the producer's own contract and require negative ACs plus fixtures |
| 2026-07-12 | 7 | loop | General rework-instruction discipline for grounding fixes in the input's canon. | 2026-07-12 — Rework instructions should require a batch verification grounded in the input's canonical contract, not a point-fix transcription |
| 2026-07-12 | 8 | loop | General planning discipline for classifying verification-mechanism tasks. | 2026-07-12 — Tasks that write or extend a verification mechanism itself run long; thicken the spec review up front |
| 2026-07-13 | 1 | loop | General verification discipline about CI-wiring surfacing environment bugs. | 2026-07-13 — Environment-dependent bugs in an existing test suite stay unconfirmed until it's actually wired into CI — treat the real CI run as the primary evidence |
| 2026-07-13 | 2 | loop | General board-editing discipline for simultaneous multi-task edits. | 2026-07-13 — Simultaneous edits to a shared board by multiple tasks are prone to heading-replacement accidents — guard with a structural diff against the base |
| 2026-07-13 | 3 | maintainer | Tech-lead-facing release-procedure checklist specific to this plugin's own README variants. | 2026-07-13 — A release's version bump should update every README variant and run check-readme-version.sh against the full file list before pushing |
| 2026-07-13 | 4 | loop | General decision-recording discipline about conditional settlements. | 2026-07-13 — "Settled, won't revisit" configuration decisions are conditional on a fixed environment — pair them with an explicit re-evaluation trigger |
| 2026-07-13 | 5 | loop | General gate-design discipline about AI evaluator judgment. | 2026-07-13 — Don't punt a gate's judgment to a human — an AI evaluator with grounded context should hold the judgment and escalate only the out-of-distribution cases |
| 2026-07-13 | 6 | loop | General shell-scripting discipline about pipefail and SIGPIPE. | 2026-07-13 — Under `pipefail`, piping into `grep -q` can false-fail on SIGPIPE — verify through a temp file instead |
| 2026-07-13 | 7 | loop | General discipline for scripts generating git-tracked artifacts. | 2026-07-13 — A script that produces a git-tracked artifact should carry a PII/secret content guard before it writes |
| 2026-07-14 | 1 | loop | General path-resolution discipline for protective existence checks. | 2026-07-14 — A protective existence check should treat a dangling symlink as occupied |
| 2026-07-14 | 2 | loop | General engineering discipline for sibling-script resolution. | 2026-07-14 — A new bin/ script's sibling-resolution code should reuse the repo's existing resolver, not reinvent it |
| 2026-07-14 | 3 | loop | General fixture-design discipline for launch-shape-dependent scripts. | 2026-07-14 — A launch-shape-dependent script's fixtures must cover all three invocation forms |
| 2026-07-14 | 4 | loop | General verification discipline about grep-tool versus runtime-grep semantics. | 2026-07-14 — Don't use the Grep tool's matching semantics as a stand-in for the runtime grep the implementation actually uses |
| 2026-07-14 | 5 | loop | General review-trace discipline for docs/board-only pull requests. | 2026-07-14 — A docs/board-only PR still needs a minimal review trace left on the board |
| 2026-07-14 | 6 | loop | General board-recording discipline for fast-follow decisions. | 2026-07-14 — When acting on a fast-follow, state on the board whether an issue was filed and why (or why not) |
| 2026-07-14 | 7 | loop | General QA disclosure discipline for same-class bulk fixes. | 2026-07-14 — QA on a same-class bulk fix should disclose verification depth per site, not one blanket claim |
| 2026-07-14 | 8 | loop | General acceptance-criteria design discipline for same-class completeness. | 2026-07-14 — A same-class completeness AC should be a machine-checkable anchor (e.g. a grep count), not a prose claim |
| 2026-07-15 | 1 | loop | General audit discipline for parallel gate surfaces. | 2026-07-15 — Audit a shared norm across parallel gate surfaces with a symmetry table, not just a diff |
| 2026-07-15 | 2 | loop | General fixture-synthesis discipline for grep/regex invariants. | 2026-07-15 — Verifying a grep/regex invariant needs fixtures that deliberately collide with its own vocabulary |
| 2026-07-15 | 3 | loop | General classification discipline for post-QA review stops. | 2026-07-15 — Classify a post-QA Codex stop by artifact type before treating it as a QA quality problem |
| 2026-07-16 | 1 | loop | General acceptance-criteria design discipline for scope-widening changes. | 2026-07-16 — An AC that widens a scope from narrow to broad needs a paired revert-detection regression lock |
| 2026-07-16 | 2 | loop | General applicability-test discipline for executable artifacts. | 2026-07-16 — Decide "is this an executable artifact" by whether a canonical command exists, not by file extension |
| 2026-07-17 | 1 | loop | General spec-writing discipline for multi-referent terms. | 2026-07-17 — A term with more than one plausible referent needs a definition table before implementation |
| 2026-07-17 | 2 | loop | General fixture-design discipline for board-text guards. | 2026-07-17 — A guard that pattern-matches free-form board text needs a self-referential dogfooding fixture |
| 2026-07-19 | 1 | loop | General rework-escalation discipline for new subsystems. | 2026-07-19 — When a new subsystem grafted onto stable judgment logic hits two consecutive rounds of independent defects, re-propose splitting it out or deferring it |
| 2026-07-19 | 2 | loop | General inventory discipline for same-class bulk fixes. | 2026-07-19 — A same-class bulk-fix inventory claim needs the actual grep command and hit count attached, not just a prose assertion |
| 2026-07-19 | 3 | loop | General acceptance-criteria design discipline for completion-gate changes, later superseded by a combined entry. | 2026-07-19 — A change to a completion gate's condition count needs an AC covering downstream consumers of the gate's result |
| 2026-07-19 | 4 | loop | General escalation-threshold discipline for pre-commitments. | 2026-07-19 — Default a pre-commitment's trigger threshold to the existing "two consecutive rounds"; state the reason if loosening it |
| 2026-07-19 | 5 | loop | General gate-design discipline about stateful boundaries. | 2026-07-19 — A stateful gate boundary can't be machine-enforced by conversational memory alone |
| 2026-07-19 | 6 | loop | General inventory discipline for downstream-impact checks, later superseded by a combined entry. | 2026-07-19 — A downstream-impact inventory needs a check for other-gate raw output bleeding into a combined value |
| 2026-07-20 | 1 | loop | General QA-reporting discipline for advisory-only evaluation paths. | 2026-07-20 — An advisory-only evaluation path report should distinguish "the underlying mechanism ran" from "the production-shaped output actually shipped" |
| 2026-07-20 | 2 | loop | General pre-commitment design discipline separating factual and contextual triggers. | 2026-07-20 — A verification-mechanism pre-commitment should separate its factual trigger condition from its contextual one |
| 2026-07-20 | 3 | loop | General acceptance-criteria design discipline for path-classification tests. | 2026-07-20 — A path-classification AC needs an explicit test case for a same-directory relative link |
| 2026-07-20 | 4 | loop | General disclosure-design discipline for deep dependency graphs. | 2026-07-20 — When a dependency graph runs deep by design, default to a categorical summary rather than an enumeration |
| 2026-07-20 | 5 | loop | General verification discipline for paraphrases that remove internal references. | 2026-07-20 — A paraphrase that removes an internal reference must be cross-checked for meaning drift in the surrounding claim |
| 2026-07-21 | 1 | loop | General spec-writing discipline for completeness-audit tasks. | 2026-07-21 — A completeness-audit spec must say up front that a static scan can't trace indirect or constructed call paths |
| 2026-07-21 | 2 | loop | General cross-file inventory discipline for repeated norms. | 2026-07-21 — When the same class of norm appears across several canonical files, inventory every occurrence before fixing any of them |
| 2026-07-21 | 3 | loop | General spec-design discipline for irreversible procedures. | 2026-07-21 — Design a complex irreversible procedure as a checklist of safety invariants, not numbered sequential steps |
| 2026-07-22 | 1 | loop | General acceptance-criteria design discipline for text-lock regressions. | 2026-07-22 — A text-lock regression AC should be designed around equality, not containment |
| 2026-07-22 | 2 | loop | General provenance-grounding discipline. | 2026-07-22 — Ground provenance citations in a durable anchor, not a line number |
| 2026-07-22 | 3 | loop | General scope-lock allow-list design discipline. | 2026-07-22 — A scope-lock allow-list should include a task's required deliverables from the start |
| 2026-07-23 | 1 | loop | General buildability-estimation discipline for CI-pinned checks. | 2026-07-23 — Before pinning existing logic in CI, estimate whether it's actually buildable |
| 2026-07-24 | 1 | loop | General regression-assertion design discipline for error-exit contracts. | 2026-07-24 — Check an error-exit contract against the runtime's own default failure code before designing its regression assertion |
| 2026-07-24 | 2 | loop | General self-consistency discipline for relaying review findings. | 2026-07-24 — Check a review round's findings for self-consistency before relaying rework instructions |
| 2026-07-24 | 3 | loop | General spec-evaluation discipline for validation depth. | 2026-07-24 — A validation spec should evaluate at write-time how far its own DP actually reaches an abstract guarantee |
| 2026-07-24 | 4 | loop | General freshness-check discipline for inherited prior art. | 2026-07-24 — A carve-out spec inheriting prior art should freshness-check the paths it cites against the current branch |
| 2026-07-25 | 1 | loop | General mutation-self-check discipline for new locks and guards. | 2026-07-25 — A new lock or guard should get a producer-run mutation self-check before its first review round |
| 2026-07-25 | 2 | loop | General file-hygiene discipline for tool-generated residue. | 2026-07-25 — Grep a tool-generated file's tail for wrapper residue before committing it |
| 2026-07-25 | 3 | maintainer | Specific to this plugin's own file-line-pinned bin script registries. | 2026-07-25 — Editing a file-line-pinned `bin/` script needs an explicit check that cross-suite registries still match |
| 2026-07-26 | 1 | loop | General self-check discipline for new verification mechanisms. | 2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind |
| 2026-07-26 | 2 | loop | General acceptance-criteria design discipline for completion-gate changes, combining two earlier entries. | 2026-07-26 — A change to a completion gate's condition count needs a contamination check and a sentinel-distinctness AC (supersedes two earlier entries) |
| 2026-07-26 | 3 | loop | General spec-verification discipline for intent-hash freezing. | 2026-07-26 — Run a spec's `check:` lines live and reconcile them before recording an intent hash |
| 2026-07-26 | 4 | loop | General verification discipline for markdown-bullet purely-additive checks. | 2026-07-26 — Don't use `^-[^-]` to confirm a markdown-bullet file only had lines added |
| 2026-07-26 | 5 | loop | General verification-command design discipline. | 2026-07-26 — A verification command needs array/literal file args, an unswallowed exit code, and a positive control |

## Retro candidate table (9 rows)

Columns: candidate position in the source retro, its `[common]`/`[target-specific]`
label, outcome, one-line reason, destination. `[common]` never becomes
`maintainer`; `[target-specific]` never becomes `loop`; `already-covered` is a
disposition available only in this table, never in the import table above.

None of the nine candidates was promoted into the corpus through
`bin/playbook-promote.sh` this round. Every candidate's own outcome
disposition is honest on its own merits (an already-covered restatement, a
cross-project tool-behavior fact, or a genuinely repository-specific
recommendation better captured directly in an operational document than as a
new corpus entry) — see `## Notes from engineer` in the task spec for the
mechanical reason none of the three `loop`/`maintainer`-eligible candidates
was actually promoted this round.

| 1 | [target-specific] | drop | Recommends editing a specific agent file's prose directly rather than stating a recurring judgment rule; left for a direct follow-up instead of a new ledger entry. | n/a |
| 2 | [common] | already-covered | Restates the already-imported entry about running check: lines live before recording an intent hash; already carried by this corpus. | n/a |
| 3 | [common] | drop | A useful reframing heuristic for gates that cannot draw a clean boundary, but distinct from every already-imported entry and left for a direct follow-up rather than a new ledger entry. | n/a |
| 4 | [common] | operator-global | Describes git's own stash behavior with untracked files, a fact about a tool used across every repository, not specific to this one. | n/a |
| 5 | [target-specific] | drop | Repo-specific advice about backgrounding long full-tree check: commands; captured directly in the test recipe instead of as a new ledger entry. | n/a |
| 6 | [common] | drop | Recommends running a newly-changed checker against one's own generated artifacts before hand-off; distinct from the existing mutation self-check entry and left for a direct follow-up rather than a new ledger entry. | n/a |
| 7 | [common] | drop | Recommends a full content search, not just a filename search, before claiming no precedent exists; distinct from every already-imported entry and left for a direct follow-up rather than a new ledger entry. | n/a |
| 8 | [target-specific] | drop | Recommends always saving the primary review capture even when the adversarial pass does not fire; repo-specific to the review capture convention and left for a direct follow-up rather than a new ledger entry. | n/a |
| 9 | [common] | drop | Suggests replacing prohibition-sounding process vocabulary with plainer wording; sourced only from an external tracker item, not a repository artefact, and left for a direct follow-up rather than a new ledger entry. | n/a |

## Named-entity scrub attestation

Every retained and non-retained row above, and the full corpus and this ledger themselves, were swept for six classes of named entity:

- **employer and customer names**
- **internal ticket identifiers**
- **hostnames**
- **personal names**
- **pre-publication task and issue numbers**
- **home-directory absolute paths**

The result is **zero remaining across all six classes**.

The **search terms are not recorded here** — a file listing the names swept
for would itself be the leak this scrub exists to prevent. What is recorded is
the enumeration of classes searched and the zero-remaining result; the source
corpus's own absolute path was supplied to the engineer out of band for this
task and was never transcribed into any tracked file, including this one.
