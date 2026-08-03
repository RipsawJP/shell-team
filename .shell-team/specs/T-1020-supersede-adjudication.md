# T-1020 — supersede adjudication (the artifact the human ratifies from)

**Companion to**: `.shell-team/specs/T-1020-lessons-supersede-sweep.md`
**Owner**: pm-spec
**Corpus adjudicated**: `.shell-team/lessons.md` at `develop` @ `392b934`
**Status of this document**: **ratified 2026-08-03.** The human ratified **C-01 only**; all 23 remaining `KEEP` verdicts stand, and both priced overrides in section 7 were declined. The ratified pair is recorded in the spec's "Ratified retirement set" section and baked into its acceptance criteria; this document is the durable record of *why* each candidate went the way it did, and is not edited further by the implementation.

One item surfaced at the ratification gate and is recorded here as corroboration rather than as an input: the pre-publication repository ran a 74-entry pairwise domination sweep on 2026-07-26 (its T-108) and found **zero dominations**, and that deferral record never migrated into this repository. Porting it is **issue #112**, outside T-1020's scope. It matters here only as an independent second measurement pointing the same way as section 7's finding — this adjudication was performed against the committed corpus without knowledge of it. Section 3.4 states precisely how the two instruments differ.

Every count and every piece of arithmetic in this document is marked `pm-spec-measured-by-reading`: pm-spec has no shell, so each number was derived by reading the corpus and the committed block files. The coordinating session re-measures all of them on a scratch copy before this is presented for ratification. Where a number below is wrong, the adjudication's *verdicts* are unaffected — they rest on quoted text, not on counts — but the ceiling arithmetic in the closing section is.

---

## 0. The anti-count-gaming pre-commitment, restated before the proposal

This was set in the spec (D3) before the adjudication was written, and it is repeated here because it is the thing that makes the proposal below readable as a finding rather than as a failure:

> The target arithmetic (−11 bullets for `playbook-pm-spec.md`, −1 for `playbook-engineer.md`) is a consequence of the retirement set, never an input to it. If the set of pairs that satisfy the predicate falls short, no pair is manufactured, no predicate condition is relaxed, and no borderline pair is upgraded to reach a number. The task instead accepts the remaining overage on the board with a stated reason.

**The proposal below falls short, and by a wide margin.** That is the honest outcome of the sweep, not a preliminary result to be improved by looking harder. Section 7 states exactly what the human would have to override to reach the target, so the choice is decidable rather than merely disappointing; section 3 accounts for how the candidate set was derived, so "falls short" can be checked rather than taken on trust.

## 1. The predicate every block below is scored against

- **(i-a) occasion subsumption** — whenever the retiree's rule fires, the successor's rule also fires. A successor whose occasions are a strict special case of the retiree's fails.
- **(i-b) protection subsumption** — at those occasions, the failure the retiree prevents is still prevented by the successor's required action. An outcome test, not a wording test: a *means* the successor reaches another way does not block retirement; a protection it secures by no means at all does.
- **(ii) `Applies-to` role coverage does not shrink** — successor roles (with `all` expanded to the four IN roles) ⊇ retiree roles. If it would shrink, the verdict is keep.
- **(iii) the `Why` incident class is the same** — the same *kind* of failure, not merely the same category.

Machine pre-filters applied before the predicate (properties of `bin/check-playbook.sh`, read from the script): **C1** an entry already targeted by another `Superseded-by` cannot be retired; **C2** a `loop` entry may not point at a `maintainer` entry; **C3** the pointer equals the target's `date — title` key exactly after trim; **C4** the target must be `active`; **C5** a `maintainer` entry never appears in a block, so retiring one has zero line impact; **C6** an `Applies-to: all` retirement shrinks all four blocks.

## 2. Baseline arithmetic (`pm-spec-measured-by-reading`)

| block | lines now | bullets now | threshold | bullets needed | retirements needed |
|---|---|---|---|---|---|
| `templates/prompt-blocks/playbook-pm-spec.md` | 51 | 49 | ≤ 40 lines | ≤ 38 | **−11** |
| `templates/prompt-blocks/playbook-engineer.md` | 41 | 39 | ≤ 40 lines | ≤ 38 | **−1** |
| `templates/prompt-blocks/playbook-qa-verifier.md` | 28 | 26 | ≤ 40 lines | — | under threshold |
| `templates/prompt-blocks/playbook-tech-lead.md` | 23 | 21 | ≤ 40 lines | — | under threshold |

A block is `## Lessons playbook` + one blank line + one bullet per qualifying entry, so lines = bullets + 2, and the generator warns only when lines **exceed** 40 (so 38 bullets / 40 lines is compliant, 39 bullets / 41 lines is not).

Corpus totals: 83 entries — 3 already `superseded`, 80 `active`, of which 71 are `Scope: loop` and 9 are `Scope: maintainer`. Cross-check that validates the reading: deriving each role's bullet set from `Scope: loop` × `Applies-to` reproduces 49 / 39 / 26 / 21 exactly against the four committed block files.

## 3. Candidate selection: the method actually used, and a complete accounting over all 80 active entries

Added in rework round 1. Codex round 1 raised, as a Major, that this document adjudicated 24 candidates and concluded "no retirement stock" without ever showing how those 24 were derived from the 80 active entries — issue #97's task 1 is *"Inventory active entries whose ground is now covered by a newer entry"*, and a reader could not verify that no plausible pair had been missed. The finding is correct: sections 4 through 6 were written, and section 7's conclusion drawn, with the selection step left implicit. This section supplies it. It changes no verdict and adds no candidate.

### 3.1 What pass 1 actually did

Described as performed, not as an idealized procedure.

1. **Full read of all 83 entries** in `.shell-team/lessons.md` at the base ref — every field, not only `Rule`. 80 are `active`; 3 were already `superseded` before this task and are outside the adjudication by definition (an entry cannot be retired twice).
2. **Built the membership table.** For all 83 entries, recorded `(date — title, Scope, Applies-to, Status)` and derived which of the four generated blocks each `Scope: loop` entry lands in. This produced the baseline arithmetic of section 2 and was corroborated by reproducing all four committed block files exactly (49 / 39 / 26 / 21 bullets). The same table defines the **retiree candidate space**: an entry can only shrink an over-threshold block if it is in that block, so the space is the union of the pm-spec and engineer block memberships — **65 entries** (49 + 39 − 23 in both).
3. **C1 pre-filter pass.** Scanned every `Superseded-by` value in the corpus (three of them) and marked each pointed-at entry out of candidacy. Two distinct entries: C-23 and C-24.
4. **Positioning-sentence harvest.** This corpus has an unusual habit — most entries state their own relationship to a neighbour in prose. Every occurrence of "adjacent to, but distinct from", "complements", "extends", "generalizes", "same class of", "sits one step before" and "that one targets X, this one targets Y" was read and the named neighbour treated as a candidate pair. This is the highest-yield source and it is what produced the strongest candidates (C-03, C-11, C-12, C-13, C-16, C-17, C-18) — including the three where the successor's own text claims to generalize or replace the retiree.
5. **Forward successor search over the 65-entry candidate space.** For each entry in the space, walked forward through later `active` entries looking for one whose `Rule` fires on the same occasion, narrowing by `Category`, by `Applies-to` overlap, and by subject vocabulary. A pair was written up as a numbered block when it was plausible enough that a reader could propose it — concretely, when either the corpus itself named the neighbour (step 4) **or** the two rules overlapped in *both* subject and remedy. A pair sharing only a subject, refuted by one mechanical test with no remedy overlap, was resolved in place and not written up; §3.3 is where those now appear, named.
6. **Both directions checked for the `all` and multi-role entries**, since retiring one of those shrinks blocks that are already under the threshold (C6) — the reason section 7's second decision point could be priced at all.

The honest limit of this method: step 5's "plausible enough" was a judgment threshold, and pass 1 applied it inconsistently once. See §3.3's entry for `2026-07-12 — Regression fixtures must cross the boundary …`.

### 3.2 Disposition accounting — every active entry lands in exactly one bucket

Buckets are assigned in the order listed; each entry falls into the first one it satisfies.

**Re-measure this table against the base ref, not against the branch tip.** The accounting is taken at `develop` @ `392b934`, where the corpus holds 83 entries — 80 `active`, 3 `superseded`. Once C-01 is applied the tip holds 79 `active` and 4 `superseded`, so a count run against the working tree will disagree with every number below by exactly that one entry (C-01's retiree, which is in bucket (a) either way). Use `git show develop:.shell-team/lessons.md`.

| bucket | test | count |
|---|---|---|
| **(a)** appears in one of the numbered blocks, as retiree or as successor | named in §4–§6 | **36** |
| **(b1)** outside the 65-entry retiree candidate space (`Scope: maintainer`, **or** `Applies-to` containing none of `pm-spec` / `engineer` / `all`) and not needed as any candidate's successor | mechanical, from the two fields | **13** |
| **(b2)** inside the candidate space; the forward search found **no** later active entry whose rule fires on the same occasion — there is no successor to name, so no pair exists | forward search returned empty | **22** |
| **(b3)** inside the candidate space; a later active entry **does** share the subject, but the pairing is refuted by one mechanical test and no other successor exists | named below with the refuting test | **9** |
| | **total** | **80** |

Second arithmetic identity, independently re-measurable: of bucket (a)'s 36 entries, 2 sit outside the candidate space (C-01's `maintainer` retiree and C-22's `maintainer` successor), so 34 are inside it — and 34 + 22 + 9 = **65**, the candidate space exactly.

Bucket (a) breaks down as 24 retirees (one per numbered block, C-01 through C-24) plus 12 further entries that appear only as successors, with 2 entries holding both roles. The 12 successor-only entries: `2026-07-19 — When a new subsystem grafted …` (C-18), `2026-07-19 — A same-class bulk-fix inventory claim …` (C-07), `2026-07-21 — A completeness-audit spec must say up front …` (C-10), `2026-07-21 — When the same class of norm appears …` (C-03), `2026-07-26 — A task that creates a verification mechanism …` (C-04, C-11, C-19, C-21), `2026-07-26 — A verification command needs array/literal file args …` (C-02, C-06, C-17), `2026-08-01 — A bin/ edit's completion checklist …` (C-01), `2026-08-01 — A task that builds a fail-closed gate …` (C-08, C-09, C-20), `2026-08-02 — A spec that ships runnable commands …` (C-15), `2026-08-02 — An approval gate presents every option's content …` (C-05), `2026-08-02 — Run the PII-shape checker …` (C-12, C-13), `2026-08-02 — A spec's descriptive grounding claim …` (C-22). The 2 dual-role entries: `2026-07-24 — A validation spec should evaluate at write-time …` (retiree in C-04, successor in C-16) and `2026-07-25 — A new lock or guard should get a producer-run mutation self-check …` (retiree in C-11, successor in C-14).

**Bucket (b1) — 13 entries, out of retiree scope by this task's own Non-goals and AC15, and never needed as a successor.** Retiring any of them could only shrink an already-under-threshold block or no block at all, so none was a candidate retiree by construction: `2026-04-29 — Bootstrap` (tech-lead), `2026-06-13 — Release: keep the version of record …` (maintainer), `2026-06-17 — Adding score-driven eval …` (maintainer), `2026-06-17 — A distributed bin/ script should run relative to the caller's cwd …` (maintainer), `2026-06-18 — CI's shellcheck is older than the local one …` (maintainer), `2026-07-12 — Rework instructions should require a batch verification …` (tech-lead), `2026-07-13 — A release's version bump should update every README variant …` (maintainer), `2026-07-14 — QA on a same-class bulk fix should disclose verification depth per site …` (qa-verifier), `2026-07-15 — Classify a post-QA Codex stop by artifact type …` (tech-lead, qa-verifier), `2026-07-20 — An advisory-only evaluation path report …` (qa-verifier), `2026-07-24 — Check a review round's findings for self-consistency …` (tech-lead), `2026-08-01 — Close-out verifies the task's interventions record exists` (maintainer), `2026-08-02 — A review-record appendix is committed by the round that writes it` (maintainer).

**Bucket (b2) — 22 entries, inside the candidate space, forward search empty.** Each was a genuine candidate retiree and each returned no later entry firing on the same occasion, so there is no pair to adjudicate: `2026-06-13 — Codex review runs synchronously …`, `2026-06-15 — Introducing a configurable base dir …`, `2026-06-17 — The board's - [ ] lines follow check-handoff's strict format …`, `2026-06-17 — While a spec is still uncommitted on a feature branch …`, `2026-07-12 — Track whether a newly-written behavioral rule actually got applied …`, `2026-07-12 — A parser/consumer task's spec must cite the producer's own contract …`, `2026-07-13 — Simultaneous edits to a shared board …`, `2026-07-13 — "Settled, won't revisit" configuration decisions …`, `2026-07-13 — Don't punt a gate's judgment to a human …`, `2026-07-14 — A protective existence check should treat a dangling symlink as occupied`, `2026-07-14 — A launch-shape-dependent script's fixtures must cover all three invocation forms`, `2026-07-14 — When acting on a fast-follow, state on the board whether an issue was filed …`, `2026-07-17 — A term with more than one plausible referent needs a definition table …`, `2026-07-19 — A stateful gate boundary can't be machine-enforced by conversational memory alone`, `2026-07-20 — A verification-mechanism pre-commitment should separate its factual trigger condition …`, `2026-07-20 — A paraphrase that removes an internal reference …`, `2026-07-21 — Design a complex irreversible procedure as a checklist of safety invariants …`, `2026-07-22 — A text-lock regression AC should be designed around equality …`, `2026-07-22 — Ground provenance citations in a durable anchor …`, `2026-07-22 — A scope-lock allow-list should include a task's required deliverables …`, `2026-07-25 — Grep a tool-generated file's tail for wrapper residue …`, `2026-07-26 — Don't use ^-[^-] to confirm a markdown-bullet file only had lines added`.

### 3.3 Bucket (b3) — 9 entries whose near-successor was found, adjudicated in place, and not written up as a block

These are the entries a reader is most likely to propose as "missed", so each is named with its near-successor and the single test that refutes it. All nine land on keep; none satisfies the predicate.

| entry (candidate retiree) | near-successor considered | refuting test |
|---|---|---|
| `2026-06-14 — Don't mark a runtime user-verify AC done …` (qa-verifier, engineer) | `2026-07-20 — An advisory-only evaluation path report …` (qa-verifier) | **(ii)** engineer lost; and **(i-a)** the successor fires only on an advisory or optional evaluation path, not on every runtime user-verified criterion |
| `2026-06-18 — A self-hosted negative check: can false-positive …` (engineer, pm-spec) | `2026-07-22 — A text-lock regression AC should be designed around equality …` (pm-spec, engineer) | **(i-a)** one governs a negative-absence grep, the other a positive presence lock; the remedies (scope the grep to operational directories / use equality not containment) do not overlap |
| `2026-07-12 — Regression fixtures must cross the boundary …` (engineer, qa-verifier) | `2026-07-25 — A new lock or guard should get a producer-run mutation self-check …` (engineer, pm-spec), which names it in its own "extends" sentence | **(ii)** qa-verifier lost. Secondary near-successor `2026-07-26 — A task that creates a verification mechanism …` (pm-spec, engineer, qa-verifier) passes (ii) but fails **(i-a)** as a verification-mechanism-task special case |
| `2026-07-13 — Environment-dependent bugs in an existing test suite …` (pm-spec, engineer, qa-verifier) | `2026-08-02 — A spec that ships runnable commands verifies them across an execution-context matrix` (pm-spec, qa-verifier) | **(ii)** engineer lost |
| `2026-07-13 — Under pipefail, piping into grep -q can false-fail on SIGPIPE …` (engineer) | `2026-07-26 — A verification command needs array/literal file args …` (engineer, qa-verifier, pm-spec) | **(i-a)** the retiree fires inside a production script's own pipeline, the successor on a command run to verify something |
| `2026-07-14 — A new bin/ script's sibling-resolution code should reuse the repo's existing resolver …` (engineer) | `2026-07-14 — A launch-shape-dependent script's fixtures must cover all three invocation forms` (engineer, qa-verifier) | **(i-a)** implementation-time versus fixture-writing-time; **(i-b)** prevention versus detection |
| `2026-07-14 — A docs/board-only PR still needs a minimal review trace …` (engineer, qa-verifier) | `2026-08-02 — A review-record appendix is committed by the round that writes it` (all, **maintainer**) | **C2** — a `loop` entry may not be superseded by a `maintainer` entry; unratifiable, the checker rejects it |
| `2026-07-15 — Audit a shared norm across parallel gate surfaces with a symmetry table …` (pm-spec, tech-lead) | `2026-07-21 — When the same class of norm appears across several canonical files …` (engineer, pm-spec) | **(ii)** tech-lead lost |
| `2026-07-19 — Default a pre-commitment's trigger threshold …` (pm-spec, tech-lead) | `2026-07-20 — A verification-mechanism pre-commitment should separate its factual trigger condition …` (pm-spec) | **(ii)** tech-lead lost |

Two of these deserve to be called out rather than left in a table row.

- **The sibling-resolver pair is the one the Codex round-1 adversarial pass proposed as a missed candidate.** It re-adjudicated the pair itself against this document's own predicate and rejected it, on exactly the grounds in the table — occasion (implementation versus verification) and protection (prevention versus detection) — noting that the prevention/detection distinction is the same one this document already applies in C-04, C-19 and C-21. Recording it here puts the disposition in the adjudication rather than only in the review record, which is where the reviewer's point was aimed: the pair being constructible at all is what made the missing accounting visible.
- **The regression-fixtures pair is where pass 1 applied its own block-writing bar inconsistently.** Its near-successor names it in a positioning sentence, which is step 4's trigger and should have produced a numbered block; it was adjudicated in place instead. No block is added for it now — its verdict is keep either way, the ratified set is frozen, and adding a 25th block would change no outcome while touching a document the human has already ratified. The gap was in the record, not in the judgment, and this row closes it.

### 3.4 What this accounting does and does not establish

It establishes that all 80 active entries were dispositioned, that the 65-entry retiree candidate space was walked entry by entry, and that every entry not adjudicated in a numbered block has a stated reason class that can be re-derived from two fields (`Scope`, `Applies-to`) or from a named near-successor. That is what makes the word "exhaustive" checkable for this sweep rather than asserted.

It does not establish that the sweep was a mechanical all-pairs comparison. It was not: an all-pairs walk over 80 entries is 3,160 unordered pairs, and this sweep instead walked the 65-entry candidate space forward with the corpus's own positioning sentences as the primary index. The genuinely mechanical all-pairs measurement is the *other* one the board's acceptance line cites — the pre-publication repository's 74-entry pairwise domination sweep of 2026-07-26, which found zero dominations (issue #112 ports its record). The two measurements are different instruments pointing the same way, and this section is the reason the second one can be read as corroboration rather than as the only real evidence.

## 4. Candidates recommended for retirement

### C-01 — the maintainer-scoped `bin/` pin rule, superseded by the loop-scoped CI-list rule

**Retiree**: `2026-07-25 — Editing a file-line-pinned `bin/` script needs an explicit check that cross-suite registries still match` — Scope: maintainer, Applies-to: engineer, qa-verifier
**Successor**: `2026-08-01 — A bin/ edit's completion checklist runs the full CI-wired suite list, not a self-selected subset` — Scope: loop, Applies-to: engineer,qa-verifier

- (i) **PASS / PASS.** (i-a): the retiree fires "When a task edits a `bin/` script pinned elsewhere by a `file:line:content` registry"; the successor fires "When an implementation touches a bin/ script" — strictly broader, so it fires wherever the retiree does. (i-b): the retiree's protection is *a stale line-number pin is caught before the round closes*. It reaches it by two means — "confirm with a repository-wide grep whether the edit shifted any pinned line number" and "explicitly run the pinning suite (at minimum the errexit-safe suite)". The successor mandates "running every suite the CI workflow wires, in the order the workflow lists them", which contains the pinning suite unconditionally, and adds "QA re-runs at minimum the pinning/registry suites rather than trusting the claim". The grep is a means to the protection, not the protection; the protection survives.
- (ii) **PASS.** `{engineer, qa-verifier}` → `{engineer, qa-verifier}` — equal, no shrink. (The successor spells its value without the space, `engineer,qa-verifier`; both scripts trim per token, so the sets are identical.)
- (iii) **PASS.** Retiree's `Why`: "A usage-string rewrite shifted a script's line numbers by several lines, and both the engineer and QA only ran that script's own suite and judged it green — CI then failed because the pinning registry had gone stale". Successor's `Why`: "A task edited a bin/ script whose line numbers were pinned by another suite's registry, ran only a narrow self-declared list of suites, and declared the work ready; QA failed the round on the stale pin. **The corpus already carried an adjacent rule for exactly this class, but it was bound in a maintainer document the roles never see at run time**". Same incident class, and the successor names the retiree as the rule it replaces.
- C2 direction: `maintainer` → `loop` is one of the three legal directions (only `loop` → `maintainer` is a violation).

**Line impact**: none. The retiree is `Scope: maintainer`, so it appears in no generated block (C5). pm-spec 51 → 51, engineer 41 → 41.
**Verdict**: **RETIRE** — the only pair in the corpus that satisfies all three conditions cleanly. It is corpus hygiene, not threshold relief: it contributes zero lines toward either target, and the human may reasonably decline it purely to keep the diff minimal.

## 5. Candidates adjudicated and recommended for keeping

Presented in full, with verdicts, so the ratification is over an adjudicated set rather than a pre-trimmed one. Each block states what would be lost if the human overrides the recommendation.

### C-02 — the Grep-tool-semantics rule, against the general verification-command rule

**Retiree**: `2026-07-14 — Don't use the Grep tool's matching semantics as a stand-in for the runtime grep the implementation actually uses` — Scope: loop, Applies-to: pm-spec, qa-verifier
**Successor**: `2026-07-26 — A verification command needs array/literal file args, an unswallowed exit code, and a positive control` — Scope: loop, Applies-to: engineer, qa-verifier, pm-spec

- (i) **PASS / FAIL.** (i-a) passes: a grep-based acceptance criterion is "a verification command that inspects files (a spec's `check:` line, a self-run test's supporting grep …)", so the successor fires wherever the retiree does. (i-b) fails: the retiree's protection is *a verification result produced by a different tool whose matching semantics differ from the runtime's is not trusted* — it names the mechanism precisely, "with its real flags, e.g. a case-insensitive or extended-regex form … rather than relying on an editor-integrated search tool's own (typically case-sensitive) matching semantics as a proxy". The successor's three points are file-argument shape, exit-code fidelity, and a positive control; none of them concerns a second tool's matching semantics, and a positive control ("the command actually hits a term guaranteed to exist") is only meaningful once the real command is already the one being run.
- (ii) **PASS.** `{pm-spec, qa-verifier}` ⊂ `{engineer, qa-verifier, pm-spec}`.
- (iii) **MARGINAL.** Both `Why` sections are "the verifier's own command produced a false pass", but the mechanisms differ: tool-semantics divergence (a case-insensitive runtime grep matched where a case-sensitive editor search did not) versus argument-and-exit-code handling (four filenames in one string, exit 2 swallowed by an "or echo zero" fallback).

**Line impact**: pm-spec −1, qa-verifier −1.
**Verdict**: **KEEP** — and this one is not close. The hazard fired again on 2026-08-02, inside T-1019: the board records that the interactive shell's ugrep-backed grep wrapper masked a match that the authoritative `bash -c` invocation caught. Retiring a rule four days after it demonstrably prevented a shipped defect trades a measured protection for one bullet.

### C-03 — the cross-cutting AC-mechanism rule, against the canonical-files inventory rule

**Retiree**: `2026-07-12 — Cross-cutting-discipline ACs must specify the mechanism, not just the outcome` — Scope: loop, Applies-to: pm-spec
**Successor**: `2026-07-21 — When the same class of norm appears across several canonical files, inventory every occurrence before fixing any of them` — Scope: loop, Applies-to: engineer, pm-spec

- (i) **PASS / FAIL.** (i-a) passes: "one discipline applied across many sites" and "the same class of norm or token appears across more than one canonical file" fire together in practice, and the successor explicitly widens "site" to include prose and the code it governs inside one file. (i-b) fails: the retiree's protection lives in the *frozen acceptance criteria* — "the spec's acceptance criteria must specify not just the outcome but the mechanism: a full inventory of applicable sites, a requirement that every site is covered, and … a per-fix mirrored-application checklist". The successor's action is behavioral and rework-time — "before starting, do a repository-wide grep inventory … pm-spec should state explicitly in a rework instruction that the target is every file in the diff's scope". A behavioral instruction is not a criterion the acceptance-criteria checker can run, and the mirrored-application checklist between parallel surfaces has no counterpart at all.
- (ii) **PASS.** `{pm-spec}` ⊂ `{engineer, pm-spec}`.
- (iii) **PASS.** Both are "a same-class gap fixed at one site and left standing at another, resurfacing in a later round".
- The successor's own wording settles it: "This **extends** the existing same-class-2/mirrored-application discipline across file boundaries" — extension presupposes the thing extended.

**Line impact**: pm-spec −1.
**Verdict**: **KEEP** — retiring it would leave the pm-spec block with a rework-time grep habit in place of its only AC-level cross-cutting mechanism requirement.

### C-04 — the shallow-proxy DP rule, against the verification-mechanism two-self-checks rule

**Retiree**: `2026-07-24 — A validation spec should evaluate at write-time how far its own DP actually reaches an abstract guarantee` — Scope: loop, Applies-to: pm-spec
**Successor**: `2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind` — Scope: loop, Applies-to: pm-spec, engineer, qa-verifier

- (i) **FAIL / —.** (i-a) fails: the successor's spec-stage question is a strict special case of the retiree's. The successor asks one question — "whether this invariant can only be judged correctly by tracking grammar-level state (quote open/close state, nesting, multi-line structure)". The retiree asks whether the design "actually reaches that abstract goal or only approximates it as a shallow proxy", and its own worked example (a "does the first line start with a brace" check standing in for JSON validity) is only *incidentally* a grammar question. A shallow proxy on a non-grammar property — a count standing in for coverage, a presence lock standing in for correctness — never triggers the successor's question and would pass unexamined.
- (ii) **PASS.** `{pm-spec}` ⊂ `{pm-spec, engineer, qa-verifier}`.
- (iii) **MARGINAL.** Both are spec-stage failures to ask whether the chosen method can reach the stated goal; the retiree's incident is depth of guarantee, the successor's is a detector's blind spots.

**Line impact**: pm-spec −1.
**Verdict**: **KEEP** — a special case cannot subsume its generalization, and this is the clearest instance of that shape in the corpus.

### C-05 — the ratification-language rule, against the approval-gate content rule

**Retiree**: `2026-08-02 — A ratification request pairs the exact bytes with a summary in the approver's language` — Scope: loop, Applies-to: all
**Successor**: `2026-08-02 — An approval gate presents every option's content, never a bare label` — Scope: loop, Applies-to: all

- (i) **PASS / FAIL.** (i-a) passes outright: the successor names the occasion — "When presenting options for a human decision (an escalation, a rework disposition, **a ratification**)". (i-b) fails on two halves. The successor requires that "every option's actual content … must appear in the same message as its label" and, for a long option, "include a faithful summary inline together with the exact text" — but it never requires the summary to be **in the approver's working language**, which is the entire content of the retiree's incident, and it carries no counterpart to the retiree's third element, "the presenter's own attestation of what was checked". The retiree's `How to apply` names all three together as jointly required: "a summary in the approver's working language, the exact bytes being ratified, and the presenter's own attestation".
- (ii) **PASS.** `all` → `all`.
- (iii) **PASS**, by the successor's own words: its `Why` incorporates the retiree's incident as its second data point — "a sibling incident presented replacement text in a form the approver could not evaluate. Both gates existed formally, and neither was exercisable as presented."

**Line impact**: all four blocks −1 (C6) — pm-spec 51 → 50, engineer 41 → **40**, qa-verifier 28 → 27, tech-lead 23 → 22. **This is one of only two single retirements in the entire candidate set that would close the engineer block's −1 on its own.**
**Verdict**: **KEEP** — despite being the cheapest route to the engineer target. The retiree exists because a ratification gate "existed formally but could not be exercised", and the successor does not carry the language requirement that made it exercisable. Retiring it would re-open that gate — including this very ratification request, which is being presented under the retiree's own rule.

### C-06 — the whole-artifact-exits-0 rule, against the general verification-command rule

**Retiree**: `2026-07-12 — A "whole artifact exits 0" assertion can false-pass against a stale remote-tracking ref — narrow the assertion instead` — Scope: loop, Applies-to: engineer, qa-verifier
**Successor**: `2026-07-26 — A verification command needs array/literal file args, an unswallowed exit code, and a positive control` — Scope: loop, Applies-to: engineer, qa-verifier, pm-spec

- (i) **PASS / FAIL.** (i-a) passes: a "the whole target spec or artifact exits 0" assertion is a verification command that inspects files. (i-b) fails: the retiree's protection is *a regression assertion is not allowed to depend on a nondeterministic input* — "first check whether any individual acceptance criterion inside that artifact depends on a remote-tracking ref comparison, a network call, or the current time". None of the successor's three points reaches a nondeterministic dependency; a command can satisfy all three and still pass locally against a stale remote-tracking ref while failing in CI, which is exactly the retiree's incident.
- (ii) **PASS.** `{engineer, qa-verifier}` ⊂ `{engineer, qa-verifier, pm-spec}`.
- (iii) **MARGINAL.** Both are "a verification passed without actually verifying"; the mechanisms (environment-dependent coincidence versus argument/exit-code handling) are different.

**Line impact**: engineer −1 (41 → **40**), qa-verifier −1. pm-spec unchanged. **The second of the two single retirements that would close the engineer target.**
**Verdict**: **KEEP** — but if the human wants the engineer block closed by exactly one retirement, this is the cheaper of the two options in content terms: it removes a narrow CI-versus-local trap rather than a human-gate discipline. Recorded here so that choice is available and priced, not hidden.

### C-07 — the same-class completeness AC anchor, against the bulk-fix inventory grep rule

**Retiree**: `2026-07-14 — A same-class completeness AC should be a machine-checkable anchor (e.g. a grep count), not a prose claim` — Scope: loop, Applies-to: pm-spec, engineer
**Successor**: `2026-07-19 — A same-class bulk-fix inventory claim needs the actual grep command and hit count attached, not just a prose assertion` — Scope: loop, Applies-to: pm-spec, engineer, qa-verifier

- (i) **FAIL / FAIL.** (i-a) fails: the successor fires "When a same-class bulk-fix inventory (an apply/not-apply table) **is produced**"; the retiree fires when "An acceptance criterion asserting 'every site of this class was fixed with no omissions'" is written, which happens at spec time whether or not any inventory table is ever produced. (i-b) fails: the retiree's protection is *a completeness claim that the acceptance-criteria checker itself can re-run* ("a machine-checkable anchor runnable by the acceptance-criteria checker"); the successor's is a hand-off annotation a human re-runs ("write 'grep run: <command> → N hits, all listed in the table' directly under the table").
- (ii) **PASS.** `{pm-spec, engineer}` ⊂ `{pm-spec, engineer, qa-verifier}`.
- (iii) **MARGINAL.** The retiree's `Why` is a positive example (a criterion expressed as a grep count that a reviewer independently re-ran); the successor's is a negative one (a prose completeness claim that missed two sites).

**Line impact**: pm-spec −1, engineer −1.
**Verdict**: **KEEP** — the two rules protect different artifacts (a frozen criterion versus a hand-off table) and neither is redundant against the other.

### C-08 — the path-classification AC rule, against the fail-closed gate boundary rule

**Retiree**: `2026-07-20 — A path-classification AC needs an explicit test case for a same-directory relative link` — Scope: loop, Applies-to: pm-spec
**Successor**: `2026-08-01 — A task that builds a fail-closed gate writes boundary-shape acceptance criteria against the gate itself` — Scope: loop, Applies-to: pm-spec, qa-verifier

- (i) **FAIL / —.** (i-a) fails: the successor fires only "When a task creates or extends a fail-closed validation gate". The retiree fires whenever a path-classification acceptance criterion is written — "a carry-out/retain decision, a self-containment grep" — and those appear in documentation and scrub tasks that build no gate at all.
- (ii) **PASS.** `{pm-spec}` ⊂ `{pm-spec, qa-verifier}`.
- (iii) **MARGINAL-PASS.** Both are "the check's own assumption did not match a real shape of the data, so it reported green while blind" — the retiree's regex required a literal directory prefix; the successor's region-closing condition matched any marker-shaped line.

**Line impact**: pm-spec −1.
**Verdict**: **KEEP** — the occasion gap is real, and the retiree's remedy (enumerate every way a link can be written and decide each in or out) has no counterpart in the successor.

### C-09 — the self-referential dogfooding fixture, against the fail-closed gate boundary rule

**Retiree**: `2026-07-17 — A guard that pattern-matches free-form board text needs a self-referential dogfooding fixture` — Scope: loop, Applies-to: pm-spec, qa-verifier
**Successor**: `2026-08-01 — A task that builds a fail-closed gate writes boundary-shape acceptance criteria against the gate itself` — Scope: loop, Applies-to: pm-spec, qa-verifier

- (i) **MARGINAL-PASS / FAIL.** (i-a) mostly passes: a board-prose guard is usually a fail-closed gate. (i-b) fails: the successor's required fixture classes are synthetic near-misses — "unknown identifiers, near-miss spellings, region-closing conditions" — while the retiree's required fixture is a *real-data self-reference*: "the guard-introducing task's own board entry quotes the guard's anchor string inside its own prose … or run a dry-run pass against the real board as part of QA". The retiree's `Why` states the class recurs by construction ("A guard-introducing task's own board prose will structurally tend to quote the guard's own vocabulary"), and its incident is explicitly one "synthetic fixtures never surfaced".
- (ii) **PASS.** Equal role sets.
- (iii) **MARGINAL.** Both are the gate's own boundary colliding with input nobody aimed a criterion at; one collides with real data, the other with a malformed synthetic shape.

**Line impact**: pm-spec −1, qa-verifier −1.
**Verdict**: **KEEP** — "synthetic near-miss shapes" and "run it against the real board, including this task's own entry" are different fixture obligations, and the retiree exists precisely because the synthetic set missed it.

### C-10 — the categorical-summary rule, against the static-scan-limits rule

**Retiree**: `2026-07-20 — When a dependency graph runs deep by design, default to a categorical summary rather than an enumeration` — Scope: loop, Applies-to: pm-spec
**Successor**: `2026-07-21 — A completeness-audit spec must say up front that a static scan can't trace indirect or constructed call paths` — Scope: loop, Applies-to: pm-spec

- (i) **PASS / FAIL.** (i-a) passes: both fire on a completeness claim about a deep dependency graph, and their incidents are from the same retained-dogfood-dependency work. (i-b) fails: the remedies are different and not substitutable. The retiree's is a *form* requirement on the disclosure — "set its verifiable condition as 'a categorical summary exists, with a stable anchor phrase' rather than 'the enumeration is exhaustive'". The successor's is a *scope* requirement on the audit — "list the classes of dependency a scan cannot trace … in the input space's out-of-scope section, and design completeness around empirical/runtime verification instead". A spec can follow the successor exactly and still ship an enumerated disclosure that loses to the next fresh audit.
- (ii) **PASS.** Equal (`{pm-spec}`).
- (iii) **PASS.** Same non-convergent-audit family.
- One more reason not to fold them: they state *different* trigger thresholds — the retiree escalates after "even one round of a fresh audit turns up a newly-found omission", the successor after "Two consecutive rounds of non-convergent same-class findings". Retiring one silently picks a winner between two deliberately different thresholds.

**Line impact**: pm-spec −1.
**Verdict**: **KEEP**.

### C-11 — the producer-run mutation self-check, against the two-self-checks rule

**Retiree**: `2026-07-25 — A new lock or guard should get a producer-run mutation self-check before its first review round` — Scope: loop, Applies-to: engineer, pm-spec
**Successor**: `2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind` — Scope: loop, Applies-to: pm-spec, engineer, qa-verifier

- (i) **FAIL / —.** (i-a) fails: the retiree fires for *any* new lock in any task — "an acceptance criterion's `check:` line, a test assertion, a golden file, a grep lock" — while the successor fires only for "A task creating a verification mechanism itself (a lock, guard, or checker)". A spec that adds one grep lock to an otherwise ordinary feature task triggers the retiree and not the successor.
- (ii) **PASS.** `{engineer, pm-spec}` ⊂ `{pm-spec, engineer, qa-verifier}`.
- (iii) **PASS.** Both concern a lock that looks like it works and is blind to a mutation.
- The successor's `Why` is explicit that it is additive, not replacing: "Despite a producer already following the practice of running a mutation self-check every round … The existing self-check discipline had settled 'when to self-check' but had not yet required a recursive second layer."

**Line impact**: pm-spec −1, engineer −1.
**Verdict**: **KEEP**.

### C-12 — the PII-transcription rule, against the PII-shape-checker rule

**Retiree**: `2026-06-13 — Don't transcribe real PII values in documents that describe scrubbing PII` — Scope: loop, Applies-to: pm-spec, engineer
**Successor**: `2026-08-02 — Run the PII-shape checker on a newly written record before its first commit` — Scope: loop, Applies-to: all

- (i) **FAIL / —.** (i-a) fails: the retiree's occasions are "an issue, a pull request, a commit message, a spec"; the successor's is "a new git-tracked record (a review, provenance, or interventions file)" checked "before its first commit". An issue body and a pull-request description are not files in the repository and no checker can be run against them before they are published — which is the case the retiree's own `Why` records, and the case it warns applies "with extra force to anything hosted externally".
- (ii) **PASS.** `{pm-spec, engineer}` ⊂ `all`.
- (iii) **PASS.** Both are a document describing a PII shape reproducing the value.
- The successor says so itself: "This **complements** the existing lessons on not transcribing PII into planning documents and on write-time guards inside generating scripts: this one is the habit for records written by hand."

**Line impact**: all four blocks −1 (C6).
**Verdict**: **KEEP**.

### C-13 — the write-time PII guard, against the PII-shape-checker rule

**Retiree**: `2026-07-13 — A script that produces a git-tracked artifact should carry a PII/secret content guard before it writes` — Scope: loop, Applies-to: engineer, pm-spec
**Successor**: `2026-08-02 — Run the PII-shape checker on a newly written record before its first commit` — Scope: loop, Applies-to: all

- (i) **FAIL / —.** (i-a) fails: the retiree's occasion is *writing or specifying a generator script*, and its required action is a guard inside that script, at the moment it writes ("refuse loudly (a non-zero exit, no file written)"). The successor's occasion is *a human having written a record*, and its action is a checker run afterwards. Neither fires where the other does: a generator producing an artifact unattended has no human to run a pre-commit check.
- (ii) **PASS.** `{engineer, pm-spec}` ⊂ `all`.
- (iii) **MARGINAL.** Both are PII reaching a git-tracked artifact; one through an automated writer, one through hand-written prose.
- The retiree already distinguishes itself in its own `Why`: "This is distinct from an earlier, related lesson about not transcribing PII into planning documents — this one is about a guard checked at the moment of writing an artifact." The successor names both as complements.

**Line impact**: all four blocks −1 (C6).
**Verdict**: **KEEP**.

### C-14 — the revert-detection regression lock, against the producer-run mutation self-check

**Retiree**: `2026-07-16 — An AC that widens a scope from narrow to broad needs a paired revert-detection regression lock` — Scope: loop, Applies-to: pm-spec, engineer
**Successor**: `2026-07-25 — A new lock or guard should get a producer-run mutation self-check before its first review round` — Scope: loop, Applies-to: engineer, pm-spec

- (i) **PASS / FAIL.** (i-a) passes: a widening acceptance criterion is a new check, so the successor fires. (i-b) fails on permanence. The retiree requires a *committed artifact* — "pair it with a regression-lock acceptance criterion proving that a commit reverting the widening fails the machine check — so a future edit that quietly reverts the widening back to its narrower form is caught". The successor requires a *one-time act* by the producer before hand-off — "deliberately break it, confirm it fails, restore it, confirm it passes again". A self-check leaves nothing behind for a future edit to trip.
- (ii) **PASS.** Equal role sets.
- (iii) **PASS.** Both are "nobody proved the lock goes red".

**Line impact**: pm-spec −1, engineer −1.
**Verdict**: **KEEP** — a transient check cannot stand in for a permanent one.

### C-15 — the executable-artifact classification rule, against the execution-context matrix rule

**Retiree**: `2026-07-16 — Decide "is this an executable artifact" by whether a canonical command exists, not by file extension` — Scope: loop, Applies-to: pm-spec, qa-verifier
**Successor**: `2026-08-02 — A spec that ships runnable commands verifies them across an execution-context matrix` — Scope: loop, Applies-to: pm-spec, qa-verifier

- (i) **FAIL / —.** (i-a) fails: the retiree governs the *applicability test itself*, including the negative case — "If excluding by file category, require an explicit reason for the exclusion." The successor fires only once a deliverable is already known to document runnable commands, so it can never reach the decision the retiree exists to make.
- (ii) **PASS.** Equal role sets.
- (iii) **FAIL.** The retiree's incident is an internal contradiction in an applicability condition, found by review; the successor's is a documented command that regressed in a second execution context. Different failures.

**Line impact**: pm-spec −1, qa-verifier −1.
**Verdict**: **KEEP**.

## 6. Candidates blocked by a predicate condition or a machine constraint

These are the pairs with the *strongest* content overlap in the corpus — in three of them the successor's own text claims to generalize or replace the retiree. Each is blocked, and the block is stated so the human can see that the blocking is structural rather than a matter of taste.

Condition (ii) is a **predicate** condition, not a checker rule: `bin/check-playbook.sh` would accept C-16 through C-21 without complaint. Ratifying one of them is therefore possible, and its cost is exact — a named role's block loses a rule with nothing replacing it there. C-22 is different: it is rejected by the checker itself and cannot be ratified at all.

### C-16 — the error-exit-contract rule, against the rule that says it generalizes it

**Retiree**: `2026-07-24 — Check an error-exit contract against the runtime's own default failure code before designing its regression assertion` — Scope: loop, Applies-to: pm-spec, engineer
**Successor**: `2026-07-24 — A validation spec should evaluate at write-time how far its own DP actually reaches an abstract guarantee` — Scope: loop, Applies-to: pm-spec

- (i) **PASS / MARGINAL-PASS.** The successor states the relationship itself: "This generalizes an adjacent, earlier lesson about checking an error-exit contract against a runtime's default failure value (foreseeing a vacuous check at design time, before escalation) to validation depth in general." That is the corpus's most explicit generalization claim.
- (ii) **FAIL — role coverage shrinks.** `{pm-spec, engineer}` → `{pm-spec}`. The engineer block would lose the rule outright. The retiree's `How to apply` is addressed to both moments — "When designing a DP … Apply the same sort **when implementing the harness**" — so the engineer half is load-bearing, not incidental.
- (iii) **PASS.** Both are a check that cannot, in principle, distinguish a working fix from no fix.
- Note that D5 forbids the obvious rescue: widening the successor's `Applies-to` to include `engineer` is a prose edit to an entry, and this task does not edit entry prose.

**Line impact**: pm-spec −1, engineer −1 — with the engineer block losing a rule that has no replacement there.
**Verdict**: **KEEP**.

### C-17 — the pre-freeze live-run rule, against the general verification-command rule

**Retiree**: `2026-07-26 — Run a spec's check: lines live and reconcile them before recording an intent hash` — Scope: loop, Applies-to: pm-spec, tech-lead
**Successor**: `2026-07-26 — A verification command needs array/literal file args, an unswallowed exit code, and a positive control` — Scope: loop, Applies-to: engineer, qa-verifier, pm-spec

- (i) **PASS / FAIL.** (i-b) fails plainly: none of the successor's three points requires that every `check:` line be *run* before the freeze, which is the whole of the retiree's rule ("run every `check:` line in the spec live, in full … Verify, then correct, then freeze — in that order").
- (ii) **FAIL — role coverage shrinks.** `{pm-spec, tech-lead}` → `{engineer, qa-verifier, pm-spec}`. tech-lead is lost, and tech-lead is one of the two owners the retiree explicitly names for the pre-freeze run ("whichever side has execution capability (the coordinating session, or tech-lead)").
- (iii) **PASS**, by the successor's own words: "This is the same class of vacuous pass as an existing lesson about running a spec's `check:` lines live before recording an intent hash — that one targets a `check:` line written into a spec, this one targets verification commands in general."

**Line impact**: pm-spec −1, tech-lead −1.
**Verdict**: **KEEP** — the freeze gate this repository shipped in T-1018 is built on this entry; retiring it would remove the written rule the gate mechanizes from the block of the role that owns the run.

### C-18 — the task-level two-strike protocol, against the spec-level one that generalizes it

**Retiree**: `2026-07-12 — Two consecutive rounds of new Blocker/Major findings against a verification subsystem should trigger a redesign, not another patch` — Scope: loop, Applies-to: engineer, tech-lead
**Successor**: `2026-07-19 — When a new subsystem grafted onto stable judgment logic hits two consecutive rounds of independent defects, re-propose splitting it out or deferring it` — Scope: loop, Applies-to: pm-spec, tech-lead

- (i) **PASS / MARGINAL.** The successor says "This generalizes an existing two-strike protocol from task level to spec level." Its remedy (split out or defer, escalated to the user) differs from the retiree's (propose a formal grammar or state-machine redesign), so the protection is adjacent rather than identical.
- (ii) **FAIL — role coverage shrinks.** `{engineer, tech-lead}` → `{pm-spec, tech-lead}`. The engineer block loses the rule; the retiree is the engineer-facing half ("explicitly consider and propose a formal grammar or state-machine redesign of that subsystem before proposing a third round of individual patches").
- (iii) **PASS.**

**Line impact**: engineer −1, tech-lead −1.
**Verdict**: **KEEP**.

### C-19 — the verification-mechanism task classification, against the two-self-checks rule

**Retiree**: `2026-07-12 — Tasks that write or extend a verification mechanism itself run long; thicken the spec review up front` — Scope: loop, Applies-to: tech-lead, pm-spec
**Successor**: `2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind` — Scope: loop, Applies-to: pm-spec, engineer, qa-verifier

- (i) **PASS / FAIL.** (i-b) fails: the retiree's protection is a *planning-time classification* that sets the review standard for the whole task ("Classify a task this way at planning time, and apply spec-review rigor at the higher standard for the latter category as a default"). The successor prescribes two concrete self-checks inside a task already known to be of that class; it never asks anyone to classify.
- (ii) **FAIL — role coverage shrinks.** `{tech-lead, pm-spec}` → `{pm-spec, engineer, qa-verifier}`. tech-lead is lost, and planning-time classification is the tech-lead's moment.
- (iii) **MARGINAL.**

**Line impact**: pm-spec −1, tech-lead −1.
**Verdict**: **KEEP**.

### C-20 — the vocabulary-collision fixture rule, against the fail-closed gate boundary rule

**Retiree**: `2026-07-15 — Verifying a grep/regex invariant needs fixtures that deliberately collide with its own vocabulary` — Scope: loop, Applies-to: qa-verifier, engineer
**Successor**: `2026-08-01 — A task that builds a fail-closed gate writes boundary-shape acceptance criteria against the gate itself` — Scope: loop, Applies-to: pm-spec, qa-verifier

- (i) **MARGINAL-PASS / MARGINAL-PASS.** The fixture classes overlap substantially ("a legal slug that contains a verdict word as a substring" versus "unknown identifiers, near-miss spellings"), though the retiree also mandates a specific enumeration procedure ("mechanically enumerate collision candidates … turn at least three shapes into fixtures: substring containment, word-boundary evasion (hyphen/underscore), and case variation").
- (ii) **FAIL — role coverage shrinks.** `{qa-verifier, engineer}` → `{pm-spec, qa-verifier}`. The engineer block loses it, and the retiree explicitly assigns the engineer a share ("The engineer should include the same three shapes in their own self-test at implementation time").
- (iii) **MARGINAL-PASS.**

**Line impact**: engineer −1, qa-verifier −1.
**Verdict**: **KEEP**.

### C-21 — the CI-pin buildability rule, against the two-self-checks rule

**Retiree**: `2026-07-23 — Before pinning existing logic in CI, estimate whether it's actually buildable` — Scope: loop, Applies-to: pm-spec, tech-lead
**Successor**: `2026-07-26 — A task that creates a verification mechanism needs two self-checks: is the method sound, and where is the detector itself blind` — Scope: loop, Applies-to: pm-spec, engineer, qa-verifier

- (i) **PASS / FAIL.** (i-b) fails on the retiree's second question, which has no counterpart anywhere in the successor: "if the real script has to be run directly, what is the blast radius (the side effects on other, future pull requests)?" The successor's spec-stage question is about method soundness only, never about the cost imposed on unrelated future work.
- (ii) **FAIL — role coverage shrinks.** `{pm-spec, tech-lead}` → `{pm-spec, engineer, qa-verifier}`. tech-lead is lost, and the retiree names the tech-lead's own moment ("When generating the routing map, evaluate up front whether a small script can really close the loop").
- (iii) **MARGINAL.**

**Line impact**: pm-spec −1, tech-lead −1.
**Verdict**: **KEEP**.

### C-22 — the carve-out freshness rule, against a maintainer-scoped successor (rejected by the checker)

**Retiree**: `2026-07-24 — A carve-out spec inheriting prior art should freshness-check the paths it cites against the current branch` — Scope: **loop**, Applies-to: pm-spec
**Successor**: `2026-08-02 — A spec's descriptive grounding claim is re-measured before it is trusted` — Scope: **maintainer**, Applies-to: pm-spec, qa-verifier

- (i) **PASS / PASS**, on the merits. A cited file path is a descriptive claim about the tree, and the successor's rule covers it: "re-measure any descriptive claim against the primary artifacts before relying on it — an inherited descriptive claim is trusted by every later reader and re-checked by none of them", versus the retiree's "freshness-check any file path the inherited material cites against the current branch's real file tree with a grep, rather than trusting the inherited text's own description".
- (ii) **PASS.** `{pm-spec}` ⊂ `{pm-spec, qa-verifier}`.
- (iii) **PASS.** Both are an inherited claim that was already stale when it was relied on.
- **Blocked by C2, absolutely.** A `loop` entry may not be superseded by a `maintainer` entry (T-1007 DP-b: "A shipped ('loop') rule may only be retired in favour of another shipped rule"). `bin/check-playbook.sh` reports it as "Superseded-by crosses Scope", the run fails, and `bin/gen-playbook-blocks.sh` refuses to generate anything at all. The only rescues are editing a `Scope` value or promoting a new loop-scoped entry, and both are non-goals of this task.

**Line impact**: pm-spec −1, if it were legal. It is not.
**Verdict**: **KEEP** — unratifiable, not merely unrecommended.

### C-23 — excluded from candidacy by C1

**Retiree**: `2026-06-12 — Review gate caught a regression in practice (cross-provider review vindicated)` — Scope: loop, Applies-to: engineer, qa-verifier
**Successor**: n/a — excluded before any successor is considered.

- (i) not evaluated — C1 pre-filter.
- (ii) not evaluated — C1 pre-filter.
- (iii) not evaluated — C1 pre-filter.
- It is the target of `2026-06-13 — Don't take a Codex inline-paste review's false positive at face value`'s `Superseded-by` pointer. Retiring it would make that pointer resolve to a non-`active` entry, which `bin/check-playbook.sh` rejects as "chained/duplicate supersession is not allowed".

**Line impact**: n/a.
**Verdict**: **KEEP** — out of candidacy.

### C-24 — excluded from candidacy by C1

**Retiree**: `2026-07-26 — A change to a completion gate's condition count needs a contamination check and a sentinel-distinctness AC (supersedes two earlier entries)` — Scope: loop, Applies-to: pm-spec
**Successor**: n/a — excluded before any successor is considered.

- (i) not evaluated — C1 pre-filter.
- (ii) not evaluated — C1 pre-filter.
- (iii) not evaluated — C1 pre-filter.
- It is the target of **two** pointers (`2026-07-19 — A change to a completion gate's condition count needs an AC covering downstream consumers of the gate's result` and `2026-07-19 — A downstream-impact inventory needs a check for other-gate raw output bleeding into a combined value`). It is also this corpus's worked precedent for what a legitimate supersede looks like — a successor that absorbs two predecessors and says so in its own title.

**Line impact**: n/a.
**Verdict**: **KEEP** — out of candidacy.

## 7. What the sweep found, and what the human is being asked to decide

**The finding.** Of 24 numbered candidates over the whole corpus — 22 pairs adjudicated against all three predicate conditions, plus 2 excluded by the C1 pre-filter before any successor was considered — exactly one satisfies the predicate and every machine constraint: C-01, and it is `Scope: maintainer`, so it removes zero bullets from any block. Section 3 accounts for the other 44 active entries, so this finding rests on a complete disposition of all 80 rather than on the 24 alone. Every other overlap fails on (i-a) or (i-b) (the successor is narrower, or secures a different protection), on (ii) (a named role would lose a rule with no replacement in its block), or on a checker constraint. This is not an artifact of a strict reading: in the three cases where the successor's own text claims to generalize or replace the retiree (C-16, C-17, C-18), it is condition (ii) that blocks it, and in C-22 it is the checker itself.

**Why the corpus is this non-redundant.** Nearly every entry carries an explicit positioning sentence against its neighbours — "This is adjacent to, but distinct from …", "This complements …", "This extends …", "that one targets X, this one targets Y". The promotion discipline that produced the corpus was already doing the deduplication work at write time. A 49-bullet block does not therefore contain 11 stale entries, and the 40-line threshold's own remedy text ("consider superseding stale entries") assumes a redundancy that this corpus does not have.

**Recommended outcome.**

| | pm-spec | engineer | qa-verifier | tech-lead |
|---|---|---|---|---|
| now | 51 | 41 | 28 | 23 |
| after C-01 only | 51 | 41 | 28 | 23 |
| threshold | 40 | 40 | 40 | 40 |

Ratify C-01 (or decline it, at no cost to the goal), and accept the remaining overage on the board under D3, naming `playbook-pm-spec.md` at 51 lines and `playbook-engineer.md` at 41 lines and the reason: the corpus's promotion discipline left no further pair that satisfies the retirement predicate, and no pair will be manufactured to reach a number.

**The two decision points, priced.** Both are overrides of a recommendation above; each is presented with its exact content so the choice is decidable from this document alone.

1. **Close the engineer block's −1 with one retirement.** Two candidates do it alone, and no others exist: **C-06** (retire the whole-artifact-exits-0 rule, losing the nondeterministic-dependency check on regression assertions; engineer 41 → 40, qa-verifier 28 → 27) or **C-05** (retire the ratification-language rule, losing the approver-language and presenter-attestation requirements; all four blocks −1, engineer 41 → 40). If the engineer half is worth closing, **C-06 is the cheaper of the two** in content terms. Recommended: neither; accept the overage.
2. **Close the pm-spec block's −11.** Seventeen candidates shrink the pm-spec block (C-02, C-03, C-04, C-05, C-07, C-08, C-09, C-10, C-11, C-12, C-13, C-14, C-15, C-16, C-17, C-19, C-21). C-22 also would, but the checker rejects it. Reaching −11 therefore means overriding eleven of those seventeen keep verdicts — and only thirteen of them can be ratified without violating condition (ii), so at least eight of the thirteen non-(ii)-violating keeps would have to fall. Recommended: none; accept the overage.

## 8. Observations recorded, not acted on

- **Two entries in the pm-spec block describe disciplines a shipped checker now also enforces**: `2026-07-13 — Simultaneous edits to a shared board by multiple tasks are prone to heading-replacement accidents — guard with a structural diff against the base` (whose own `How to apply` says "A permanent, machine-checked heading-identity check has been proposed as a follow-up" — that follow-up shipped as `bin/check-board-headings.sh`), and `2026-06-17 — The board's `- [ ]` lines follow check-handoff's strict format; don't wedge a note between the flag and `— spec:`` (enforced after the fact by `bin/check-handoff.sh`). Neither is retirable: `Status: superseded` structurally requires a *successor entry*, and there is none — the schema has no "obsolete by mechanization" path. Both rules also still govern the moment *before* the checker runs, which is where the cost of the mistake is paid. If a mechanized-obsolescence retirement path is wanted, it is a schema and `bin/` change and belongs in its own issue.
- **The threshold's remedy text presumes a redundancy this corpus does not have.** `bin/gen-playbook-blocks.sh`'s warning says "consider superseding stale entries". Section 7, underwritten by section 3's accounting, is the measured answer for this corpus at this date. If prompt economy remains the concern after the overage is accepted, the levers that are actually available are different ones — tightening the `Applies-to` of entries that ship to roles that do not act on them, shortening `Rule` fields (the injected text is the `Rule` verbatim), or raising the threshold with a stated reason — and each is its own task with its own issue.
- **Presenting this document for ratification is itself governed by C-05's retiree.** The request that carries it must pair the exact text with a summary in the approver's working language and the presenter's own attestation of what was checked, per `2026-08-02 — A ratification request pairs the exact bytes with a summary in the approver's language`, and must state each option's actual content rather than its label, per `2026-08-02 — An approval gate presents every option's content, never a bare label`.
