# Cutting a release, written from the release that was run

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1015
**Source**: GitHub issues #29 (the deferred release procedure) and #31 (the board-hygiene bullets read in the wrong order), plus one promoted lessons-corpus entry — the `## 2026-08-01 — Close-out verifies the task's interventions record exists` entry at the resolved lessons file, whose `**Bound-in**` field names `CONTRIBUTING.md`. Three sources, one document, one ratification round.
**Base**: the branch point `6750dcf` — `develop` @ `c9d88ae` plus the board repair that reattached T-1013's close-out sub-bullets to its Done entry.
**Branch**: `feature/29-31-cutting-a-release`

## Problem

T-1000 wrote three of the four operating conventions issue #25 asked for and
deferred the fourth. The reason is on the record and was correct: `develop..main`
was empty, this repository had never executed a release, and every criterion that
task could write verifies that a written sentence is *true* — none can verify that
a *needed* sentence is written. Three of the defects that task produced were the
same shape, a missing step, and a missing step is not greppable. So the section was
removed whole and filed as issue #29, with the constraint attached: write it from
an executed release, not from recollection.

That release has now happened. v1.1.0 was cut, and it was observed while it ran —
including one failure the recollection version would never have predicted: the
promotion pull request was opened with `develop` itself as its head branch, and
`develop` was deleted when the merge completed. It had to be restored by pushing
the branch back from a local clone. That is exactly the class of knowledge a
runbook exists to carry, and exactly the class that no amount of careful drafting
produces.

Two smaller items are batched into the same edit because they touch the same
frozen region and a ratification round is the expensive part, not the typing.
Issue #31: the two board-hygiene bullets read as a sequence that runs the close-out
step before branching, which inverts the only order that works — the script
rewrites the board file in place, so the branch it lands on has to exist first.
And one promoted lesson, whose `Bound-in` field names this same document: the
close-out step should confirm that the task's interventions record exists (the
zero-entry sentinel when nothing happened) rather than discovering its absence at
a retro, after the record's provenance value has decayed.

All three land in `CONTRIBUTING.md`, and all three collide with `T-1000`'s frozen
intent, currently at v6. That is the shape of this task: one document edit, and one
ratified amendment to a merged task's frozen criteria, scoped as narrowly as the
collisions actually require.

## Goal

<!-- BEGIN intent-block: T-1015 -->

`CONTRIBUTING.md` carries a `## Cutting a release` section written from the v1.1.0
execution and from nothing else, stating what has to be true at each step —
including the head-branch mitigation that release paid for — and stating nothing
about which environment, wrapper or tool performs a step. It carries **both** git-state
cautions the promotion path needs, not one of them: bring `develop` up to date
before cutting the release branch from it, and fetch `main` before tagging its merge
commit. It says which of the local checks mean anything before the preparation is
committed and which do not. And it states, where a reader meets it, that the release
path is the scoped exception to the rule under `## How changes get merged` — exempt
from the loop, not from the check, the merge gate or the maintainer go-ahead — so
the two statements no longer contradict each other in silence. Its two board-hygiene
bullets run in the order the steps actually run, and the flow gains one bullet
requiring the task records, the interventions record included, to be complete
before the board entry moves. `CLAUDE.md`'s single pointer bullet names the new
section as a fourth destination, and every destination it names is still a real
heading. `T-1000`'s frozen intent is amended at exactly three criteria — AC1, AC3
and AC17, the three that evaluate the live tree and would otherwise assert
something now false about it — ratified from v6 to v7 with a human GO obtained
before any of it is written, its ledger left arithmetically sound (one hash
bullet, six ratification records, an unbroken v1→v7 chain). Nothing under `bin/`,
`tests/`, `.github/`, `templates/`, `docs/`, `agents/` or `skills/` changes, and no
release is performed by this task.

### Settled decisions

Each decision below is resolved. Nothing here is left to implementation judgment.

- **D1 — the T-1000 v6→v7 ratification is a distinct human act, obtained at the
  freeze gate, and the amendment is authored by pm-spec rather than the engineer.**
  The frozen-region edit to `T-1000`'s AC1/AC3/AC17 is written into that spec as
  part of *this* spec's authoring. At the freeze gate — the same gate at which this
  task's own intent is frozen — the orchestrator presents the real frozen-region
  diff of `T-1000` (not a transcription of it) to the human, obtains the GO,
  appends `- intent-ratified (<the date the GO was given>): v6→v7 — <human GO
  record> — <reason>` to `T-1000`'s Done entry, and **replaces** its
  `- intent-hash (v6): …` sub-bullet with the v7 value. Only then does
  implementation start.
  - **The two human acts are named separately and neither substitutes for the
    other.** The v6→v7 ratification GO is given at the freeze gate, before any
    implementation; this task's own merge GO is given at the merge gate, as for
    every task. A merge GO does not retroactively ratify a frozen-region edit, and
    a ratification GO is not permission to merge.
  - **Why pm-spec authors it, and why it happens before implementation.** A human
    ratifying an intent change should read the bytes that will be frozen, and the
    only way to show them is to write them. It also keeps the engineer out of a
    frozen region entirely: by the time implementation starts, the criteria are
    ratified and the engineer's job is to satisfy them. `bin/check-intent.sh`
    reports an unratified frozen-region change as drift, so an engineer editing
    that region would be doing the one thing the mechanism exists to catch.
  - **The hash bullet is replaced, never appended to.** `bin/check-intent.sh`
    requires exactly one well-formed hash sub-bullet under a task's own entry; a
    second one is a structural error (exit 2), not a drift finding. Five
    ratification records exist for v1→v6, so v7 requires a sixth.
  - **If the GO is refused or the human asks for different wording**, the
    frozen-region edit is reverted or rewritten *before* the hash is recorded. A
    recorded hash is the commitment point; nothing before it is.
  - **Rejected — leaving `T-1000` untouched and adding a supersession note
    elsewhere.** The three criteria are executable assertions about the live tree,
    not prose: at v6, AC1 asserted `## Cutting a release` was absent, AC3 pinned the
    bytes of the two bullets this task rewords, and AC17 pinned the pointer at three
    tokens while forbidding the substring `releas` in that section. A note somewhere
    else does not
    change what they evaluate to; they would simply be red, and a red criterion on
    a merged task is indistinguishable from a regression. This repository's own
    record already calls the fix a ratification round — `T-1000`'s fast-follow
    disposition for #31 says so in as many words, and says it is worth batching
    with another change that needs one. Writing the amended text into a second
    document would also put a canonical byte string in two places, which DP-2
    exists to prevent.
- **D2 — the amendment is bounded to AC1, AC3 and AC17, and `T-1000` is not
  restored to all-green.** Four of its twenty-four criteria are expected to report
  FAIL and must not be chased: AC2 and AC22 declare themselves merge-point-scoped
  in their own text; AC14 additionally greps for `T-1000`'s entry in its `- [ ]`
  Active form, which closing the task made false; and AC23 grounds two of its
  clauses on strings that a later task legitimately removed from
  `docs/workflow.md` and `agents/pm-spec.md` (issue #30, shipped in v1.1.0), so it
  has been red since long before this task. The disposition of all twenty-four is
  fixed in the table below, and the criteria expected to pass are asserted
  mechanically (AC6).
  - **`T-1000`'s Goal and Non-goals are deliberately not amended.** They record
    what *that* task's scope was, and it stays true that it deferred the release
    procedure to a follow-up. The boundary is: frozen prose describing a task's own
    scope is history and stays as written; a frozen *criterion* that evaluates the
    live tree is amended when the tree legitimately moves under it. The deferral is
    discharged, not undone.
  - **AC23's staleness is recorded, not fixed.** Fixing it would widen the
    amendment past the collisions this task actually causes, and the fix is not
    obvious — the right answer may be retirement rather than re-grounding. pm-spec
    has no shell or network in this role and filed no issue; the board entry says
    so and names the finding, so the orchestrator can file one or decide it is not
    worth an issue.
- **D3 — every pinned byte string has exactly one owner across the two specs.**
  `T-1000` v7 keeps the five section headings, the six pull-request-flow bullets
  (including the reordered pair), the CI-green, board-format and scope bullets, and
  the one surviving absence assertion. This spec pins the ten canonical bullets of
  the new section, the records-complete bullet, the backticked heading token inside
  `CLAUDE.md`'s pointer, and — at v2 — the three superseded v1 openers, each
  asserted absent by exactly the criterion that pins its replacement. Neither spec
  restates the other's bytes. The ownership table below is the whole list, including
  the two deliberate, bounded exceptions.
  - **The `CLAUDE.md` pointer bullet's own bytes stay unpinned**, preserving
    `T-1000`'s DP-2 exception: what is frozen is the *property* that every
    destination it names exists, not the sentence. This task adds one property to
    it — that the release section is among the destinations — and still pins no
    prose.
- **D4 — the #75 mitigation prescribed is a throwaway `release/vX.Y.Z` head
  branch, not a configuration change.** The promotion pull request is opened from a
  short-lived branch cut from `develop`, so that whatever deletes a head branch on
  merge deletes the throwaway rather than the integration branch. `release` fits
  the open `<type>/<slug>` type set the flow already documents.
  - **Rejected — prescribing a repository setting or a protection rule.** Those are
    not readable from a clone, which is precisely why `T-1000`'s own scope bullet
    excludes them, and AC20 forbids the vocabulary outright. The document states
    the observed consequence and the mitigation for it, and asserts nothing about
    which setting produced the consequence.
  - **v2 — the same bullet also says to bring `develop` up to date before cutting
    from it, and to confirm the local and remote refs name the same commit.** The
    cross-provider review found the omission adversarially, and it is the second
    git-state hazard of the same step: the preceding bullet merges the preparation
    on the remote, a local branch pointer does not follow a merge that happened
    elsewhere, and a branch cut from the stale pointer carries none of the bump, the
    badges or the changelog entries. **Nothing detects it.** The badge check compares
    the badges against the manifest, and in a stale tree those still agree with each
    other; no check in this repository compares either against the release number
    being cut. So the operator tags and publishes the previous release under a new
    number, and every gate stays green throughout.
    - **Rejected — adding a check that compares the tree against the intended
      release number.** New mechanical checks are a Non-goal of this task, and the
      hazard is a transient local state rather than a property of the committed
      tree, which is a poor fit for a content checker. The documented state
      confirmation is the proportionate answer; if this recurs in practice, a
      checker is a separate task with its own design question.
    - **Rejected — leaving it to the reader as ordinary git hygiene.** The very next
      bullet already spells out the identical caution for the tag step (fetch first,
      do not tag a local approximation), so the document would be teaching the
      discipline in one step and assuming it in the step before — and the assumed
      one is where the damage is silent.
- **D5 — a release does not run the loop, and gets no board entry.** Three reasons
  for the board half, in order of weight: the
  enforced `## Active` line requires a `spec:` pointer and a release has no spec,
  so an entry could only be created by inventing one; v1.0.0 and v1.1.0 both
  shipped without one, so writing "a release gets an entry" would document a
  practice this repository does not have; and a release already leaves three
  durable records — its changelog entry, its tag, and its published release page.
  This is written into the section as its own canonical line rather than left
  implicit, so the next operator does not have to re-decide it.
  - **v2 — the same bullet reconciles the release path with the unqualified rule
    under `## How changes get merged`.** "No board entry" was only the visible half
    of the decision; the other half is that a release runs no spec, no acceptance
    criteria and no second review, which makes this section the first worked
    counter-example to a sentence two sections up that admits no exceptions. The
    decision is to state the exception **where it applies and with its reason**
    rather than to weaken the older sentence: every change a release publishes
    already went through the loop one at a time, what a release adds of its own
    lands as an ordinary pull request under the same check and the same maintainer
    go-ahead, and the procedure itself was specified, verified and reviewed once —
    as this task.
    - **Rejected — amending `## How changes get merged` to admit exceptions.** That
      paragraph is inside `T-1000`'s pinned territory, so it would cost a further
      ratification of a merged task to say something that is only true of one
      section; and a rule qualified at its source reads weaker everywhere, while a
      scoped exception reads exactly where a reader needs it.
    - **Rejected — saying nothing and letting the reader reconcile it.** That is the
      state the cross-provider review found and named: two statements in one
      document that cannot both be read literally, with nothing telling the reader
      which governs. An operator would most likely resolve it conservatively and
      route a release through a review that does not exist, which is a slower
      failure than a wrong one but still a failure of the document.

## Non-goals

- **Performing a release.** This task writes the procedure; running v1.2.0 is a
  separate act with its own human GO. Nothing here bumps a version, adds a
  changelog entry, moves a badge, creates a branch named `release/…`, or creates a
  tag.
- **The changelog entry bodies for any release.** Writing them is a step *of* a
  release, performed when one is cut.
- **Any change to `bin/close-out.sh`**, including wiring the interventions-record
  check into it. That half of the promoted lesson is filed as issue #90; only the
  contributor-facing line — the half whose `Bound-in` field names this document —
  is in scope here.
- **Editing the lessons corpus.** The promoted entry is the input, not the
  deliverable: its `Bound-in` field already names this document, its `Scope` is
  `maintainer` so it reaches no generated prompt block, and the schema has no field
  that records "this rule has now landed". The corpus file is outside the scope
  lock, so touching it fails AC10.
- **Creating `CONTRIBUTING.ja.md`**, unchanged from `T-1000`'s reasoning.
- **Environment-specific prose**: which wrapper, host, tool or credential state
  performs a step, and what any particular execution environment can or cannot
  reach. The section states what must be true and what must be verified.
- **Restoring `T-1000` to all-green** (D2), and fixing `docs/workflow.md`,
  `agents/pm-spec.md` or anything else AC23 grounds on.
- **Any new mechanical check, suite, CI step or script.** No file under `bin/`,
  `tests/`, `.github/`, `templates/`, `docs/`, `agents/` or `skills/` changes.
- **Re-litigating `T-1000`'s deferral.** The measurements it carried forward in
  DP-7 are inputs to the section, not claims to re-argue.

## Acceptance criteria

Every check runs from the repository root with no environment setup, invokes
scripts as `bash bin/<script>.sh`, asserts readability before any negative grep,
names every file it reads explicitly, and writes only under `$TMPDIR`. The base ref
for every `git` anchor is the branch point `6750dcf`, except where a criterion
names `develop` deliberately to match what CI compares against. **The exact bytes
of every canonical line this task adds are the `grep -qxF` patterns below**, and the
three v1 lines that v2 replaces are the three `grep -qF` absence patterns beside
them — there is no second copy of any of them anywhere in this spec (D3). Each
canonical line must be one physical, unwrapped line in `CONTRIBUTING.md`.

- [ ] **AC1** The new section opens with four canonical bullets: the quiet-tree
  precondition, the no-loop-and-no-board-entry rule with the scoped exception it
  states (D5), how the release content is measured and the number chosen, and where
  the version lives together with what CI compares against it. The heading itself is
  asserted by `T-1000`'s amended AC1, which owns those bytes; this criterion asserts
  the bullets. The file is proved readable and a stable sentence of it is grepped
  first, so an unreadable or truncated file cannot read as a clean pass.
  **At v2 the second bullet also reconciles the release path with the unqualified
  rule two sections up.** `## How changes get merged` says every change goes through
  the loop, and this section describes a path with no spec, no acceptance criteria
  and no second review — the first worked example of an exception to a sentence that
  states none. Leaving the two to contradict each other silently is the defect;
  editing the older sentence to admit exceptions is the expensive fix, because that
  paragraph is `T-1000`-pinned territory and would cost a further ratification of a
  merged task. The cheap and more readable form is a **scoped exception stated where
  the exception applies**: the release bullet says what is exempt (the loop), what is
  not (the check, the merge gate, the maintainer go-ahead), and why (every change a
  release publishes already went through the loop individually, and the procedure
  itself was specified and reviewed once, as this task). It is worded to avoid both
  literals `T-1000` AC25 counts at exactly one occurrence apiece in that older
  paragraph, so an adjacent exemption cannot trip the duplication lock.
  **The superseded v1 opener is asserted absent**, because a presence-only check
  passes while the old and the new line sit side by side — the failure mode this
  repository has hit before and the reason `T-1000` AC3 carries the same pair of
  assertions.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; grep -qF 'Thanks for looking' "$F" || rc=1; grep -qxF -- '- **Start from a quiet tree.** Every task meant for the release is merged and closed out, the board carries no entry under `## Active`, and the working tree is clean before anything is bumped.' "$F" || rc=1; grep -qxF -- '- **A release does not run the loop, and gets no board entry.** Every change it publishes already went through the loop one at a time; what a release adds of its own is the mechanical output of this procedure — the bump, the badges and the changelog entries — which lands as an ordinary pull request under the same check and the same maintainer go-ahead as anything else, with no spec of its own for a board entry to point at, and the enforced Active line requires a spec pointer. What records a release is its changelog entry, its tag, and its published release page. Read this as the scoped exception to the rule under "How changes get merged" above: the procedure itself was specified, verified and reviewed once, as the task that wrote this section.' "$F" || rc=1; if grep -qF -- '- **A release gets no board entry.**' "$F"; then rc=1; fi; grep -qxF -- '- **Measure the release before naming it.** `git log <previous-tag>..develop --oneline` is the content of the release, and the number follows semantic versioning applied to the surface this project declared stable at v1.0.0 — the plugin namespace and its command names.' "$F" || rc=1; grep -qxF -- '- **The version lives in exactly one tracked file.** `.claude-plugin/plugin.json` carries it, `.claude-plugin/marketplace.json` carries no version at any level, and CI compares the static version badge in both READMEs against that manifest — so the manifest and the two badges move together or the check fails.' "$F" || rc=1; test "$rc" -eq 0
- [ ] **AC2** The preparation half is stated as three canonical bullets: the
  release-prep branch and the four edits on it, the local verification that
  precedes the push, and landing the preparation on `develop`. The verification
  bullet points at the checks the CI-green section already names rather than
  restating them.
  **At v2 the verification bullet splits the three checks by what they read, not by
  which one is special.** The v1 wording named only the commit-identity check as
  post-commit, which is true of it and equally true of the shape check beside it:
  measured in the producers, the shape check enumerates changed paths from a git
  diff and reads each path out of the commit object, so it cannot see an uncommitted
  edit either, while the badge check contains no git invocation at all and reads the
  working tree directly. Singling out one of the two invites a reader to run the
  other before committing and conclude that the preparation was verified when
  nothing of it was read. The bullet therefore states the split itself — one check
  before the commit, two after — which is correct for all three and stays correct if
  a fourth is ever added to the section it points at. The superseded v1 opener is
  asserted absent, for the same reason AC1's is.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; grep -qF 'Thanks for looking' "$F" || rc=1; grep -qxF -- '- **Prepare the release on its own branch off `develop`.** Bump the manifest version, move the version badge in both READMEs to match, and add the new entry to `CHANGELOG.md` and `CHANGELOG.ja.md` — newest entry first, describing behaviour a reader can observe, with no internal task or issue references, which is the style those files declare for themselves.' "$F" || rc=1; grep -qxF -- '- **Verify the preparation locally before pushing, in two passes.** `bash bin/check-readme-version.sh README.md README.ja.md` is the badge check, with the argument list CI itself uses, and it reads the working tree — so it is the only one of the three that means anything before the change is committed. The two named under "Confirming the CI check is green" above both read committed content — one enumerates the changed paths and reads each of them out of the commit, the other reads the commits themselves — so both belong after the preparation is committed, and neither can see an uncommitted edit.' "$F" || rc=1; if grep -qF -- '- **Verify the preparation locally before pushing.**' "$F"; then rc=1; fi; grep -qxF -- '- **Land the preparation on `develop` through a pull request** and wait for the check to report a conclusion on it before merging, exactly as for any other change; a release has no board hygiene and no issue to close.' "$F" || rc=1; test "$rc" -eq 0
- [ ] **AC3** The promotion half is stated as three canonical bullets: the
  promotion from a throwaway `release/vX.Y.Z` head branch with the reason it exists
  (D4), the annotated tag on the merge commit, and publishing the release against
  that tag. The head-branch bullet names the observed consequence and the repair,
  and asserts no configuration.
  **At v2 the promotion bullet also says to update `develop` before cutting from
  it**, which the v1 wording left out. The preceding step merges the preparation on
  the remote; a local branch pointer does not move because a merge happened
  elsewhere, so the very next instruction — cut a branch from `develop` — can cut
  from a commit that predates the bump, the badges and the changelog entries. **The
  failure is silent by construction**: a stale tree carries a manifest and two
  badges that still agree with each other, which is the only relation the badge
  check compares, so nothing local and nothing in CI reports it, and the operator
  tags and publishes a release whose content is the previous one. This is the same
  class as the head-branch deletion this bullet already warns about — a git state
  transition whose damage is invisible at the moment it is taken — and the very next
  bullet already applies the same caution to the tag step (fetch first, do not tag a
  local approximation). The asymmetry was the defect; the two bullets now carry the
  same discipline. The instruction is written as a **state to verify** (the local and
  remote `develop` name the same commit) rather than as a tool to run, per this
  section, and it names no configuration, so `T-1000` AC20's vocabulary lock is
  untouched. The superseded v1 opener is asserted absent, for the same reason
  AC1's is.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; grep -qF 'Thanks for looking' "$F" || rc=1; grep -qxF -- '- **Promote `develop` to `main` from a throwaway `release/vX.Y.Z` branch cut from `develop`, and fetch `develop` before cutting it.** The preparation merged on the remote moments earlier, so the local branch is still behind until it is updated: confirm that the local `develop` and the remote one name the same commit, and cut the throwaway branch from that. A stale cut is the quiet failure of this step — the release tree would carry none of the bump, the badges or the changelog entries, and no check would notice, because the manifest and the badges stay consistent with each other. A pull request whose head branch is `develop` itself can leave `develop` deleted once the merge completes — that happened at v1.1.0 and had to be repaired by pushing the branch back from a local clone — and a throwaway head branch is what keeps the integration branch out of reach. The merge waits for the maintainer go-ahead and for the check to report its conclusion.' "$F" || rc=1; if grep -qF -- '- **Promote `develop` to `main` from a throwaway `release/vX.Y.Z` branch cut from `develop`.**' "$F"; then rc=1; fi; grep -qxF -- '- **Tag the merge commit on `main` with an annotated tag named `vX.Y.Z`.** Fetch `main` first so that the merge commit exists locally, tag that commit rather than a local approximation of it, push the tag, and confirm the remote lists it.' "$F" || rc=1; grep -qxF -- '- **Publish the release against that tag.** The notes are drafted before the promotion merges and approved by the maintainer with the same go-ahead, they are written in English as both earlier releases were, and the release is confirmed published rather than left as a draft.' "$F" || rc=1; test "$rc" -eq 0
- [ ] **AC4** The promoted lesson lands as one canonical bullet inside
  `## The pull-request flow`, and it names all three records rather than only the
  new one — the point of the lesson is that the interventions record is checked
  *alongside* the two that were never missing. It carries no status-flag token: the
  lesson's own wording refers to the entry moving, and reproducing the flag the
  close-out step writes would trip the enum lock `T-1000` AC26 holds on this file.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; grep -qF 'Thanks for looking' "$F" || rc=1; grep -qxF -- '- **The task records are complete before the board entry moves.** The interventions record exists alongside the provenance and review records — the zero-entry sentinel when nothing interrupted the task — and a missing one is a gap to fix at close-out rather than later.' "$F" || rc=1; test "$rc" -eq 0
- [ ] **AC5** Issue #31 is actually fixed, and the fix is verified as an **order**,
  not as bytes: inside `## The pull-request flow`, the first line mentioning the
  merge commit (the branching bullet) precedes the first line naming
  `close-out.sh` (the board-hygiene bullet). The bytes of both bullets belong to
  `T-1000` AC3 and are not restated here; these two anchors are used as positions
  only, which is why the branching bullet says "the close-out step" and never
  `close-out.sh`. **This criterion is red at the base ref** — before the reorder the
  same two anchors appear in the opposite order — so it cannot pass by being green
  already. Both anchors are proved found, and the extracted section is proved
  non-empty, so a broken extraction fails loudly instead of comparing two empty
  values.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; s="$(awk '/^## The pull-request flow$/{f=1;next} f&&/^## /{exit} f' "$F")"; test -n "$s" || rc=1; i="$(printf '%s\n' "$s" | grep -nF -- 'merge commit' | head -1 | cut -d: -f1)"; j="$(printf '%s\n' "$s" | grep -nF -- 'close-out.sh' | head -1 | cut -d: -f1)"; test -n "$i" || rc=1; test -n "$j" || rc=1; if [ -n "$i" ] && [ -n "$j" ]; then test "$i" -lt "$j" || rc=1; fi; test "$rc" -eq 0
- [ ] **AC6** `T-1000`'s criteria are evaluated once, and every criterion the
  disposition table says must pass reports `PASS`: AC1, AC3 and AC17 amended at v7,
  and the seventeen others the table lists as unaffected. The four the table
  declares stale by design (AC2, AC14, AC22, AC23) are **not** asserted in either
  direction — asserting FAIL would freeze their staleness and break the moment
  someone legitimately repairs one. The total number of reported criteria is pinned
  at twenty-four as the extraction positive control, so a parse failure or a
  renamed label cannot pass as a vacuous empty result. This is also where the whole
  collision audit executes: AC5, AC16, AC19, AC20, AC25 and AC26 are the negative
  criteria the new prose could trip, and each is in the must-pass list.
  - check: d="$(mktemp -d "${TMPDIR:-/tmp}/t1015.XXXXXX")"; S=.shell-team/specs/T-1000-operating-conventions.md; rc=0; if [ ! -r "$S" ]; then rc=1; else bash bin/check-acs.sh "$S" > "$d/out.txt" 2>&1; n="$(grep -cE '^AC[0-9]+: (PASS|FAIL|SKIP)' "$d/out.txt")"; test "$n" = "24" || rc=1; for a in 1 3 4 5 9 10 11 12 13 15 16 17 18 19 20 21 24 25 26 27; do grep -qxF -- "AC$a: PASS (exit 0)" "$d/out.txt" || rc=1; done; fi; rm -rf "$d"; test "$rc" -eq 0
- [ ] **AC7** `T-1000`'s ledger is arithmetically sound at v7 and its frozen bytes
  still hash to what was ratified: `bin/check-intent.sh` reports aligned, its Done
  entry carries **exactly one** hash sub-bullet, that sub-bullet is v7 with a
  40-hex value, and **exactly six** ratification records sit under the same entry
  (five for v1→v6, one for v6→v7). The entry is sliced from the resolved board and
  proved non-empty first. This is also the mechanical half of D1: an engineer who
  edited the frozen region after ratification would change its hash, and this
  criterion is what goes red.
  - check: rc=0; S=.shell-team/specs/T-1000-operating-conventions.md; B="$(bash bin/team-paths.sh --get todo)"; if [ ! -r "$S" ] || [ -z "$B" ] || [ ! -r "$B" ]; then rc=1; else bash bin/check-intent.sh "$S" "$B" >/dev/null 2>&1 || rc=1; e="$(awk '/^- \[[ x]\] \*\*T-1000\*\* /{f=1;next} f&&/^- \[/{exit} f' "$B")"; test -n "$e" || rc=1; test "$(printf '%s\n' "$e" | grep -cE '^[[:space:]]*- intent-hash \(')" = "1" || rc=1; test "$(printf '%s\n' "$e" | grep -cE '^[[:space:]]*- intent-hash \(v7\): [0-9a-f]{40}$')" = "1" || rc=1; test "$(printf '%s\n' "$e" | grep -cE '^[[:space:]]*- intent-ratified \(')" = "6" || rc=1; fi; test "$rc" -eq 0
- [ ] **AC8** `CLAUDE.md`'s pointer names the new section specifically. `T-1000`
  AC17 counts four destinations and requires each to exist, which four of the five
  headings would satisfy equally; this criterion is the one that says *which*
  fourth. The section slice is proved non-empty as the extraction positive control,
  and the bullet's own bytes stay unpinned (D3).
  - check: rc=0; test -r CLAUDE.md || exit 1; s="$(awk '/^## Branches and pull requests$/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)"; test -n "$s" || rc=1; printf '%s\n' "$s" | grep -qF -- '`## Cutting a release`' || rc=1; test "$rc" -eq 0
- [ ] **AC9** This task's own records exist and the board is sound: the provenance,
  review and **interventions** records are all present — this task dogfoods the
  line it adds, and is the first whose criteria require the interventions record —
  provenance is schema-conformant, the board carries a `T-1015` entry, the hand-off
  linter passes, no existing heading id was deleted, replaced or duplicated by the
  insertion, and the PII shape check is clean over the change. **Scoped to the
  task's active life**: the entry is grepped in its `- [ ]` form, which close-out
  rewrites, so this criterion is expected to stop passing once the task is closed.
  - check: rc=0; B="$(bash bin/team-paths.sh --get todo)"; if [ -z "$B" ] || [ ! -r "$B" ]; then rc=1; else grep -qF -- '- [ ] **T-1015** ' "$B" || rc=1; bash bin/check-handoff.sh "$B" >/dev/null || rc=1; bash bin/check-board-headings.sh "$B" --base 6750dcf >/dev/null || rc=1; fi; for f in .shell-team/provenance/T-1015.md .shell-team/reviews/T-1015.md .shell-team/interventions/T-1015.md; do test -r "$f" || rc=1; done; bash bin/check-provenance.sh .shell-team/provenance/T-1015.md >/dev/null 2>&1 || rc=1; bash bin/check-pii-shapes.sh --base develop >/dev/null || rc=1; test "$rc" -eq 0
- [ ] **AC10** Diff-scope closure: the branch's changed-and-added file set is
  exactly the allow-list in Notes for engineer. The set is the **union** of tracked
  changes and untracked additions, because this spec and the three record files are
  untracked at freeze time and `git diff` alone cannot see them. This is also what
  enforces the non-goals mechanically — a `CONTRIBUTING.ja.md`, a `docs/` edit or a
  new suite file all surface as an extra path. **This criterion is merge-point-scoped
  and is expected to go stale after this task merges**: once later work lands,
  `git diff 6750dcf` no longer describes this task. That is by design; do not widen
  its base-ref resolution or re-derive it per rework round, because merge-ranging it
  trades away the confinement it exists to provide.
  - check: d="$(mktemp -d "${TMPDIR:-/tmp}/t1015.XXXXXX")"; git diff --name-only 6750dcf > "$d/raw.txt"; git ls-files --others --exclude-standard >> "$d/raw.txt"; sort -u "$d/raw.txt" > "$d/actual.txt"; printf '%s\n' CONTRIBUTING.md CLAUDE.md .shell-team/specs/T-1000-operating-conventions.md .shell-team/specs/T-1015-cutting-a-release.md .shell-team/todo.md | sort > "$d/required.txt"; miss="$(comm -13 "$d/actual.txt" "$d/required.txt" | grep -c .)"; extra="$(comm -23 "$d/actual.txt" "$d/required.txt" | grep -vE '^\.shell-team/(provenance|reviews|interventions)/T-1015\.md$|^\.shell-team/test-recipe\.md$' | grep -c .)"; rm -rf "$d"; test "$miss" = "0" && test "$extra" = "0"
- [ ] **AC11** Negative — the new section names no execution environment and no
  tool whose availability differs between environments. Scoped to the section slice
  on purpose: the words are legitimate elsewhere in the repository and the tool is
  legitimate two sections up, where the flow already names it for closing an issue.
  This is an honest **proxy** for the whole property, which review judges: a
  vocabulary check cannot prove that no capability note was written, only that the
  three nouns and the one tool the v1.1.0 observation log used for its excluded
  half do not appear. The slice is proved non-empty and a sentence of it grepped
  positively, so an extraction failure cannot pass as a clean absence.
  - check: rc=0; F=CONTRIBUTING.md; test -r "$F" || exit 1; s="$(awk '/^## Cutting a release$/{f=1;next} f&&/^## /{exit} f' "$F")"; test -n "$s" || rc=1; printf '%s\n' "$s" | grep -qF -- 'semantic versioning' || rc=1; for t in host terminal laptop; do if printf '%s\n' "$s" | grep -qiF -- "$t"; then rc=1; fi; done; if printf '%s\n' "$s" | grep -qwF -- 'gh'; then rc=1; fi; test "$rc" -eq 0
- [ ] **AC12** Every suite and dogfood step in `.github/workflows/check-handoff.yml`
  was run locally, in the order the workflow runs them, and the producer-run
  mutation self-check named in Notes for engineer was performed, observed to fail,
  restored, and observed to pass — both reported in the hand-off. No `check:` — this
  is the "the whole list was actually run" property, and no command can prove that a
  command was run. `SKIP` is its expected `check-acs.sh` result.
- [ ] **AC13** Two attestations, both reported in the hand-off. **Grounding**: every
  sentence of `## Cutting a release` traces to the v1.1.0 execution as recorded in
  the claim-to-evidence table below or to a fact re-measured in this tree; anything
  neither observed nor measurable was not written. **Ratification order**: the
  v6→v7 GO was obtained at the freeze gate on the real frozen-region diff, before
  implementation started, and the engineer made no edit inside `T-1000`'s intent
  block. No `check:` — the first is a judgment about completeness that no grep can
  make (it is the exact reason `T-1000` deferred this section), and the second is
  the ordering of two human acts. The mechanical residue of both is elsewhere: AC7
  for the ledger and the hash, AC6 for the criteria. `SKIP` is the expected result.

## Input space

This task writes prose into two tracked documents and amends three criteria in a
third. It adds no runtime code and has no input surface of its own; what it does
have is a set of inputs its criteria feed to existing enforcers, and a procedure
whose own inputs the prose must be correct about. That is the space declared here.

**Reachable input classes** — what real usage produces, and what the document and
the criteria must therefore handle correctly:

1. A three-component version string as `.claude-plugin/plugin.json` carries it
   today (`1.1.0`), and its counterpart inside the static badge URL in both
   READMEs. `bin/check-readme-version.sh` is the enforcer, and it compares the
   badge against the manifest and nothing else.
2. An annotated tag named `vX.Y.Z` created on a merge commit on `main`, and the
   remote's view of it after a push.
3. A head branch named `release/vX.Y.Z` cut from `develop` — a `<type>/<slug>`
   name in the open type set the flow already documents, and one that the board
   and branch conventions therefore already accept.
4. The `## The pull-request flow` section as it stands after this change: seven
   top-level bullets, six pinned by `T-1000` AC3 and one by AC4 here, in an order
   two anchors are read out of at run time.
5. `T-1000`'s spec with exactly one task-scoped intent-marker pair, and its board
   entry with one hash sub-bullet plus a ratification chain — six records at v7,
   any of which may be a multi-sentence line containing em dashes and arrows.
6. The resolved board with an empty `## Active` section, into which exactly one
   entry is inserted, and a `## Done` section whose entries this task must leave
   untouched — including the T-1013 close-out sub-bullets that the branch point
   reattached.
7. `CLAUDE.md`'s pointer bullet as one top-level bullet wrapped across several
   physical lines, each backticked heading token whole on one of them, four tokens
   after this change.
8. A documentation-only pull request against `develop`, which still reaches the
   PII shape check and the commit-identity check, and whose full committed content
   is scanned for every path it touches — this spec included.
9. The output of `bin/check-acs.sh` on a spec where some criteria pass and others
   fail: one `running:` line and one result line per criterion, results on stdout,
   diagnostics interleaved.

**Out-of-scope synthetic extremes** — named and declined; a finding grounded only
in one of these is out of contract:

1. Version strings this project has never shipped: pre-release or build-metadata
   forms (`1.2.0-rc.1`, `+build`), a two- or four-component number, a manifest with
   no version field, a badge in only one README. The section documents the shape
   released twice here; hardening the badge checker is a different task, and the
   checker already fails closed on the shapes it does not accept.
2. Release paths this repository has not walked: a hotfix cut from `main`, a
   release from a branch other than `develop`, re-releasing an existing tag,
   deleting and recreating a tag, a lightweight tag, a release with no changelog
   entry.
3. Adopter repositories with no plugin manifest, no changelog pair, a different
   badge provider, or the legacy `tasks/` + `docs/specs/` layout. The document
   describes this repository's release, and `docs/adopting.md` owns the adopter's
   view.
4. GitHub state that is not readable from a clone: which setting deleted `develop`
   at v1.1.0, the protection rule set on either branch, account-level merge
   settings, and the API's own responses. The section records an observed
   consequence and a mitigation and asserts no setting — the same boundary
   `T-1000`'s AC15 and AC20 enforce from the other side.
5. Any host's tooling availability, credential state, network reachability, or
   which wrapper performs a step. Out by decision, and AC11 is the proxy that keeps
   the vocabulary out.
6. Malformed ledgers and malformed intent blocks: two marker pairs, two hash
   sub-bullets, a ratification chain with a gap, a reversal or a duplicate.
   `bin/check-intent.sh` owns those classes and fails closed on them; AC7 consumes
   its verdict and does not re-test the checker.
7. A `T-1000` spec whose criteria were renumbered, retired or added to beyond the
   three amended here. AC6 pins the reported count at twenty-four and fails loudly
   rather than adapting, which is the confinement that criterion exists for.
8. Adversarial scale: a release with hundreds of changelog entries, a board with
   thousands of entries, adversarially long release notes, non-UTF-8 bytes in the
   manifest or the board.
9. Concurrent edits: another task appending to the board, or to `CONTRIBUTING.md`,
   while this one is in flight. The scope lock reads a single working tree at one
   moment and makes no claim beyond it.

<!-- END intent-block: T-1015 -->

## Body-to-AC correspondence

Every normative directive stated above, mapped to the criterion that enforces it or
to an explicit exemption with a reason.

| Body directive | Where | AC / disposition |
|---|---|---|
| `CONTRIBUTING.md` gains `## Cutting a release` | Goal | `T-1000` AC1 (amended; it owns the heading bytes), reached mechanically through AC6 |
| The section is written from the v1.1.0 execution and from nothing else | Goal, Problem | AC13 (attested), with the claim-to-evidence table as its record; AC1/AC2/AC3 pin the sentences that resulted |
| The section states what must be true, never which environment or tool performs a step | Goal, Non-goals | AC11 (vocabulary proxy), AC13 (the judgment half) |
| The head-branch mitigation is a throwaway `release/vX.Y.Z` branch | D4 | AC3 |
| The throwaway branch is cut from a `develop` brought up to date, and the local/remote match is confirmed first (v2) | D4, AC3 body | AC3 — the pinned bullet carries the instruction and its reason |
| The stale-cut failure is silent because no check compares the manifest or the badges against a release number (v2) | AC3 body, row R8 | `info-only (not promoted to AC)` — it is a statement about what the existing checkers do *not* compare, and the response to it is the documented state check, not a new check (adding one is a Non-goal). The assertable half is that the instruction is present, which AC3 pins |
| All three local checks are placed correctly relative to the commit: one before, two after (v2) | AC2 body, row R6 | AC2 |
| A release does not run the loop; the exception is scoped, reasoned, and stated where it applies (v2) | D5, AC1 body | AC1 |
| The `## How changes get merged` section is not edited, and the exemption is worded so the two duplication anchors it carries stay at exactly one occurrence each (v2) | AC1 body | AC6 (through `T-1000` AC25, which counts both anchors), AC10 (a `CONTRIBUTING.md` edit outside the release section and the flow bullets would still be inside the allow-listed file, so the count lock is the real guard here, not the scope lock) |
| No configuration or protection setting is asserted | D4, Non-goals | `T-1000` AC20 via AC6 (the forbidden vocabulary), AC3 (the bullet states a consequence, not a setting) |
| A release gets no board entry | D5 | AC1 |
| The two board-hygiene bullets run in the order the steps run | Goal, Problem | AC5 (order), `T-1000` AC3 via AC6 (the reworded bytes and both superseded openings asserted absent) |
| The flow gains a records-complete bullet naming the interventions record | Goal, Problem | AC4 |
| That bullet carries no status-flag token | AC4 body | `T-1000` AC26 via AC6, and AC4 pins the line that has to satisfy it |
| `CLAUDE.md` names the new section as a fourth destination | Goal | AC8 (which fourth), `T-1000` AC17 via AC6 (four tokens, each a real heading) |
| The pointer bullet's bytes stay unpinned | D3 | `info-only (not promoted to AC)` — it is a decision *not* to add a pin, and the absence of a criterion is its whole implementation; `T-1000`'s DP-2 records the reasoning and AC17 pins the property instead |
| `T-1000` is amended at exactly AC1, AC3 and AC17 | Goal, D2 | AC6 (the three report PASS and the count stays twenty-four), AC7 (the frozen bytes hash to the ratified value), AC10 (only that spec file changes) |
| The v6→v7 GO is a distinct human act obtained at the freeze gate, before implementation | D1 | AC13 (ordering, attested), AC7 (the record exists and the chain is unbroken) |
| pm-spec authors the amendment; the engineer never edits a frozen region | D1 | AC7 — an engineer edit after ratification changes the hash and reports drift |
| The hash sub-bullet is replaced, not appended to; six ratification records at v7 | D1 | AC7 |
| If the GO is refused, the edit is reverted before any hash is recorded | D1 | `info-only (not promoted to AC)` — it describes the state of the world in a branch this task does not take; if it happens there is no v7 to check, and AC7 fails closed on the mismatch |
| Rejected: a supersession note instead of a ratification | D1 | `info-only (not promoted to AC)` — a rejected alternative leaves nothing in the tree to assert; its observable consequence is that the three criteria are green (AC6) rather than red-with-an-excuse |
| `T-1000` is not restored to all-green; four criteria are stale by design | D2 | AC6 asserts only the must-pass list and deliberately says nothing about AC2, AC14, AC22, AC23 |
| `T-1000`'s Goal and Non-goals are not amended | D2 | AC7 — amending them would change the frozen bytes, and the hash recorded at the freeze is of the region containing exactly the three criterion edits |
| AC23's staleness is recorded, not fixed | D2 | `info-only (not promoted to AC)` — the directive is inaction on a file this task must not touch; AC10 is what fails if `docs/workflow.md` or `agents/pm-spec.md` is touched anyway, and the board entry carries the finding |
| Every pinned byte string has exactly one owner | D3 | the ownership table below; mechanically, no `grep -qxF` pattern in this spec appears in `T-1000` and none of `T-1000`'s appears here |
| No release is performed | Non-goals | AC10 (no manifest, README, changelog or tag file appears in the diff) |
| No change to `bin/close-out.sh`; the tooling half is issue #90 | Non-goals | AC10 |
| The lessons corpus is not edited; the promoted entry is an input | Non-goals | AC10 (the corpus file is outside the allow-list, so an edit surfaces as an extra path) |
| No `CONTRIBUTING.ja.md`; nothing under `bin/`, `tests/`, `.github/`, `templates/`, `docs/`, `agents/`, `skills/` | Non-goals | AC10 (any of them surfaces as an extra path), `T-1000` AC24 via AC6 for the four directories it already covers |
| A superseded canonical line must not survive alongside its replacement (v2) | AC1/AC2/AC3 bodies | AC1, AC2 and AC3 each assert the v1 opener they replace absent, mirroring `T-1000` AC3's own pair |
| Canonical lines are one physical unwrapped line each | AC preamble | AC1–AC4 (`grep -qxF` is a whole-line match, so a wrapped line cannot pass) |
| Every check asserts readability before a negative grep and proves its extraction non-empty | AC preamble | AC1–AC5, AC7–AC11 each carry the guard; AC6 guards `T-1000`'s spec path |
| The whole CI list is run locally, and the mutation self-check is performed | AC12 | AC12 (runtime, `SKIP` by design) |
| The section's prose ordering and where the section sits in the file | Notes for engineer | `info-only (not promoted to AC)` — a readability choice, same class as `T-1000`'s own; no consumer depends on it, and AC1–AC3 pin the text rather than its position |
| The section's unpinned intro sentence | Notes for engineer | `info-only (not promoted to AC)` — every other section of this document has an unpinned intro line; pinning one here would freeze a sentence no criterion reads |

## Claim-to-evidence table

One row per canonical line the new section adds. A claim with no evidence row does
not get written. "Observed" means it happened during the v1.1.0 release and was
recorded in the observation log the orchestrator carried into this task;
"measured" means it was re-derived from this tree while writing this spec.

| # | Canonical line | Evidence | AC |
|---|---|---|---|
| R1 | Start from a quiet tree | Observed: the v1.1.0 preparation began with every task merged and closed out, an empty `## Active`, and a clean tree. Measured: the board's `## Active` section is empty today, immediately after the T-1013 close-out | AC1 |
| R2 | A release does not run the loop, gets no board entry, and this is a scoped exception to the rule two sections up | Measured four ways: the board has no entry for v1.0.0 or v1.1.0; `bin/check-handoff.sh`'s `LINE_RE` requires ` — spec: <path>.md` on every Active line, and a release has no spec; the three records a release leaves (changelog entry, tag, release page) all exist for both shipped releases; and `## How changes get merged` states its rule unqualified, with no exception clause anywhere in the file — so the reconciliation had to be written rather than found. **v2**: the exception half was added after the cross-provider review observed that this section is the first worked counter-example to that unqualified sentence and that the two were left silently contradicting each other | AC1 |
| R3 | Measure the release, then choose the number | Observed: the content of v1.1.0 was read off the commit range from the previous tag to `develop` before the number was chosen. Measured: `CHANGELOG.md`'s v1.0.0 entry states that the namespace and command surface were adopted "as the stable public surface under semantic versioning", which is the surface the number is judged against | AC1 |
| R4 | The version lives in exactly one tracked file; CI compares both badges against it | Measured: `.claude-plugin/plugin.json` carries `"version"`; `.claude-plugin/marketplace.json` has no version field at any level; `bin/check-readme-version.sh`'s header names the manifest as the source of truth and says the check "looks ONLY at the badge"; the workflow's dogfood step passes `README.md README.ja.md` | AC1 |
| R5 | Prepare on a branch off `develop`; four edits; changelog style | Observed: v1.1.0 was prepared on a branch off `develop` carrying exactly the manifest bump, both badges, and the two changelog entries. Measured: `CHANGELOG.md`'s own opening paragraph declares the style — newest first, and scrubbed of internal task and issue references | AC2 |
| R6 | Verify locally before pushing, in two passes — one check before the commit, two after | Observed: the badge check, the shape check against `develop`, and the identity check after committing were all run locally before the push. Measured: the two checks other than the badge one are already described in `## Confirming the CI check is green`, which is why this bullet points at that section instead of restating them. **v2, measured in the producers rather than inferred**: `bin/check-commit-identity.sh` reads commits, and `bin/check-pii-shapes.sh` enumerates changed paths from a git diff and reads each path's content out of the commit — so **both** are post-commit, while `bin/check-readme-version.sh` contains no git invocation at all and reads the working tree, so it is the only one of the three that means anything before the commit. The v1 wording named only the identity check as post-commit, which was true but asymmetric, and the asymmetry invited exactly the wrong inference about the other one | AC2 |
| R7 | Land the preparation on `develop` through a pull request and wait for a reported conclusion | Observed: the preparation went in as an ordinary pull request and its check was allowed to report before the merge. Measured: the flow's existing bullets already state the target and the confirmation rule, so this line adds only the two things that differ for a release — no board hygiene, no issue to close | AC2 |
| R8 | Promote from a throwaway `release/vX.Y.Z` head branch, cut from a `develop` that has been brought up to date | Observed, and this is the row the whole task exists for: at v1.1.0 the promotion pull request was opened with `develop` as its head branch, `develop` was deleted when the merge completed, and it was restored by pushing the branch back from a local clone. Measured: `release` is a legal `<type>/<slug>` type, since the flow's own bullet leaves the type set open. **v2, the fetch-before-cut half**: derived rather than observed, and stated as such — the preceding bullet merges the preparation on the remote, a local branch pointer does not follow a merge that happened elsewhere, and `bin/check-readme-version.sh` compares the badges against the manifest only, so a tree that predates the bump is internally consistent and passes. No check in this repository compares either against a release number, which is what makes the failure silent; the mitigation is therefore a documented state to confirm, not a check to add (adding one is a Non-goal). The same caution is already applied one bullet later to the tag step, and the two are now symmetric | AC3 |
| R9 | Annotated tag on the merge commit; fetch first; verify on the remote | Observed: the merge commit had to be fetched before it could be tagged locally, and the tag's presence on the remote was confirmed after the push. Measured (carried forward from `T-1000` DP-7): the single pre-existing tag `v1.0.0` is annotated, so the annotated form is this project's practice and not an invention. **Corrected — see the dated note directly below this table; the grounding sentence in this cell is stale and the row is kept as written for the trail** | AC3 |
| R10 | Publish the release against the tag; notes drafted and approved beforehand; English | Observed: the notes were drafted before the promotion merged, approved by the maintainer together with the go-ahead, and the published state was confirmed afterwards. Measured: the release notes for v1.0.0 and v1.1.0 are both in English | AC3 |
| R11 | The task records are complete before the board entry moves | Grounded in the promoted lessons entry `## 2026-08-01 — Close-out verifies the task's interventions record exists`, whose `Bound-in` field names this document. Measured across the last sprint's tasks (T-1005 through T-1013): every one of them has a provenance record and a review record, and every one has an interventions record **except exactly one** — the omission the lesson was written from. Measured on the tooling side: `bin/close-out.sh` contains no occurrence of the word at all, which is why the tooling half is a separate issue (#90) and this line is the whole of the in-scope half | AC4 |

### Correction to R9 (2026-08-02) — the annotated-tag grounding is stale

**Measured independently by QA and by the cross-provider review, and reproduced in
both records** (`.shell-team/reviews/T-1015.md`, §6 and the Minor entry of the Codex
verdict): `v1.0.0` is a genuine annotated tag object, but **`v1.1.0` — the very
release this section is written from — is a lightweight tag**. R9's sentence "the
annotated form is this project's practice" was accurate when `T-1000` DP-7 measured
it, because `v1.1.0` did not exist yet; by the time this spec was drafted it
described one of two releases and therefore no longer described a practice.

**Disposition, stated explicitly.**

- **The row is not amended and the correction lives here instead.** R9 sits outside
  the intent block, so amending it would cost no ratification — but it is a
  *historical* evidence record, and rewriting a measurement after the fact erases
  the trail of what the spec was grounded on when it was frozen. The correction is
  therefore additive and dated, and R9 carries a pointer to it. This also keeps the
  v1→v2 ratification scope to exactly the three shipped bullets the review found
  defects in, which is the point of scoping a ratification at all.
- **The shipped bullet is not changed and is not defective.** It reads "Tag the
  merge commit on `main` with an annotated tag named `vX.Y.Z`" — an instruction for
  the next release, never a claim to the reader about past practice. QA and the
  review independently reached the same conclusion: no criterion is violated and no
  reader is misled. AC13's attestation is qualified by this note rather than by a
  changed row.
- **Retagging `v1.1.0` is not proposed.** Deleting and recreating a tag is a named
  out-of-scope class in this spec's own Input space, and doing it to make a past
  release match a sentence would be the tail wagging the dog. The historical fact
  stands; only the description of it is corrected.
- **A fast-follow is recommended and not filed here** — pm-spec has no shell or
  network in this role. The review's own disposition names it: soften the grounding
  language to "prescribed going forward" wherever it recurs, which is a spec-hygiene
  item and not a merge blocker.

## `T-1000` criterion disposition after v7

All twenty-four, so that "must pass" is a closed list rather than an impression.
"Unaffected" means this task changes nothing the criterion reads.

| Criterion | Disposition | Why |
|---|---|---|
| AC1 | **amended, must pass** | asserts the release heading present and retires eight spent absence assertions, keeping the one that still means something |
| AC2 | **stale by design — expected FAIL, already red before this task** | self-declared merge-point-scoped, and it fails at its own positive control: the four-line About-CI paragraph it anchors on `develop` was replaced by that task with two single physical lines, so the anchor now yields one line and the `-eq 4` assertion fires — the loud-failure behaviour its own body specifies for a base whose paragraph changed shape. #31's reorder additionally deletes two lines that do exist on `develop`, which the licensed set does not cover |
| AC3 | **amended, must pass** | the two board-hygiene bullets are reworded into the order the steps run; both superseded openings asserted absent |
| AC4 | unaffected, must pass | grounds the close-out claims in the script; nothing here touches `bin/` |
| AC5 | unaffected, must pass | **collision row** — no `feat/T-` string may enter the file |
| AC9 | unaffected, must pass | the CI-green bullets are untouched |
| AC10 | unaffected, must pass | reads the workflow file only |
| AC11 | unaffected, must pass | reads the workflow file only |
| AC12 | unaffected, must pass | the board-format bullets are untouched |
| AC13 | unaffected, must pass | the worked example line is untouched |
| AC14 | **stale by design — expected FAIL** | greps `T-1000`'s entry in its `- [ ]` Active form, which close-out rewrote to `- [x]`; also base-ref dependent |
| AC15 | unaffected, must pass | the scope bullets are untouched |
| AC16 | unaffected, must pass | **collision row** — the shape check over the change, the `sandbox` count pinned at one, and eight forbidden classes absent from the file |
| AC17 | **amended, must pass** | four destinations instead of three; the two absence assertions guarding the deferral retire with it |
| AC18 | unaffected, must pass | prompt blocks and agents byte-unchanged, prompt-sync green, and its positive control (`CONTRIBUTING.md` changed) holds while this task is in flight |
| AC19 | unaffected, must pass | **collision row** — zero `tests/<name>/run.sh` paths anywhere in the file, so the new section must name no suite path; the two pointers it also requires (the workflow file and `.shell-team/test-recipe.md`) are already carried by the CI-green section, and the release section points there rather than adding a third copy |
| AC20 | unaffected, must pass | **collision row** — none of the four branch-protection literals may appear |
| AC21 | unaffected, must pass | `T-1000`'s provenance file is untouched |
| AC22 | **stale by design — expected FAIL** | self-declared merge-point-scoped; this task's own files are outside `T-1000`'s allow-list by construction |
| AC23 | **stale, expected FAIL, not fixed here** | two of its clauses grep for strings a later task legitimately removed (issue #30, shipped in v1.1.0), so it has been red since then; recorded in D2, out of scope |
| AC24 | unaffected, must pass | nothing under `bin/`, `tests/`, `.github/` or `templates/` changes, and its positive control holds while this task is in flight |
| AC25 | unaffected, must pass | **collision row**, and at v2 the tightest one — it is the regression lock against re-importing release prose from `README.md` or `docs/distribution.md` (none of the three forbidden phrases may appear), **and** it counts two sentences of `## How changes get merged` at exactly one occurrence each. v2's loop-exemption sentence sits adjacent to that paragraph and refers to it, so it is worded to contain neither anchor string; reproducing either while paraphrasing the rule would take the count to two and fail this criterion |
| AC26 | unaffected, must pass | **collision row** — six of the seven status-flag tokens must not appear; the records bullet is the line most at risk |
| AC27 | unaffected, must pass | the About-CI correction is untouched |

## Canonical-bytes ownership

| Byte string | Owner | Note |
|---|---|---|
| The five `## …` section headings of `CONTRIBUTING.md` | `T-1000` AC1 | including `## Cutting a release`, asserted present at v7 |
| `- The promotion and the tag are a **maintainer decision, not an observed practice**` (absence) | `T-1000` AC1 | the one surviving absence assertion of the original eight |
| The six pull-request-flow bullets, including the reordered pair | `T-1000` AC3 | this spec restates none of them |
| `- **Merge, then run board hygiene.**` and `- **Publish the board edit as its own pull request.**` (absence) | `T-1000` AC3 | the superseded pre-reorder openings |
| The five CI-green bullets, the five board-format bullets, the three scope bullets | `T-1000` AC9 / AC12 / AC15 | untouched by this task |
| The ten `## Cutting a release` bullets | this spec, AC1 / AC2 / AC3 | four, three and three respectively. **v2 rewords three of the ten** — the no-loop/no-board-entry bullet (AC1), the local-verification bullet (AC2) and the promotion bullet (AC3). Ownership does not move: each reworded line is still pinned by exactly the criterion that pinned its predecessor, and no fragment of any of the three appears in `T-1000` or anywhere else in this spec |
| The records-complete bullet | this spec, AC4 | the seventh bullet of the pull-request flow |
| The three superseded v1 openers (absence) — `- **A release gets no board entry.**`, `- **Verify the preparation locally before pushing.**`, and the promotion opener ending `cut from `develop`.**` | this spec, AC1 / AC2 / AC3 respectively | added at v2; each is asserted absent by exactly the criterion that pins its replacement, and none of the three appears anywhere else in either spec |
| `` `## Cutting a release` `` as a backticked token inside `CLAUDE.md` | this spec, AC8 | **declared exception**: a different string in a different file from AC1's whole-line heading assertion. The two are near-duplicates by nature — a pointer names its target — and the alternative, deriving one from the other at run time, buys nothing and costs legibility |
| `merge commit` and `close-out.sh` as **position** anchors | this spec, AC5 | **declared exception**: both are substrings of bullets `T-1000` AC3 pins. They are used to establish an order, never to assert content, and the branching bullet is worded so that the second anchor appears only in the bullet that must come later |
| The `CLAUDE.md` pointer bullet's prose | nobody, deliberately | `T-1000`'s DP-2 exception, preserved: AC17 freezes the property, not the sentence |

## Assumptions

- **pm-spec has no shell in this role, so none of the `check:` lines above has been
  executed.** Per the standing discipline the executing side runs all eleven live
  checks against the pre-implementation tree — base `6750dcf` plus this spec, the
  `T-1000` amendment and the board entry — corrects anything mechanically broken or
  vacuously passing with the semantics unchanged, records the measured pass/fail
  disclosure here, and only then records the two hashes (`T-1000` v7 and this
  task's v1). Verify, then correct, then freeze.
- **Measured at the freeze (orchestrator, 2026-08-02): exactly as predicted below — 11 FAIL, every one exit 1, 0 PASS (a freeze-time pass would itself have been a finding), AC12/AC13 SKIP.** After the human-ratified v6→v7 ledger recording, `check-intent.sh` on `T-1000` flipped to `aligned v7` as the prediction for AC7 states. No `check:` line needed correction.
- **Predicted pre-implementation result, so the measured run has something to be
  compared against rather than merely recorded.** All eleven live checks are
  expected to FAIL against the freeze-time tree (base `6750dcf` plus this spec, the
  `T-1000` amendment and the board entry): AC1–AC4 because their canonical lines do
  not exist yet, AC5 because the two position anchors are still in the opposite
  order, AC6 because `T-1000`'s AC1/AC3/AC17 are red until the deliverable lands
  (and AC18/AC24 are red too, since their `CONTRIBUTING.md`-changed positive
  controls have nothing to see yet), AC7 because no v7 record exists until the
  orchestrator writes it, AC8 because the pointer still names three destinations,
  AC9 because none of the three record files exists, AC10 because two required
  paths are still unchanged, and AC11 because the section slice is empty. AC12 and
  AC13 report `SKIP`. **A pass at the freeze would itself be the finding** — it
  would mean the criterion is measuring something that was already true. Two
  disclosed nuances. First, every freeze-time failure is expected to be a clean
  assertion failure (exit 1), not a checker error: `T-1000`'s AC17 short-circuits at
  its token-count assertion (three, not four) before ever reaching the `git diff`
  clause whose empty result would be an integer-expression error, and AC18 and AC24
  fail at a `test -n ""` positive control, which is a plain false rather than an
  error. An exit other than 1 anywhere in the freeze run is therefore worth reading
  before it is accepted. Second, **AC7's result flips during the freeze gate
  itself**: it passes only after the v7 hash and the sixth ratification record are
  written, so re-run it after the ledger update rather than reading its first result
  as final.
- **v1→v2 re-freeze (2026-08-02), and its own predicted result.** The
  cross-provider review returned `REQUEST_CHANGES` with one Blocker and two Majors,
  all three of them inside pinned canonical bytes, so the fix is a frozen-region
  revision rather than an implementation change: three of the ten shipped bullets
  are reworded (the promotion bullet gains fetch-before-cut; the verification bullet
  states the pre/post-commit split for all three checks; the no-board-entry bullet
  becomes the no-loop-and-no-board-entry bullet carrying the scoped exception), and
  AC1, AC2 and AC3's `grep -qxF` patterns move with them, each gaining an absence
  assertion against the v1 opener it supersedes. Nothing else in the intent block
  changes — no criterion is added or retired, the count stays at thirteen, the ten
  bullets stay ten, `T-1000`'s v7 region is not touched, and the Input space is
  unchanged. **Predicted at the v2 freeze, against the tree as the engineer left it
  (v1 bullets shipped): AC1, AC2 and AC3 report FAIL — twice over each, since the
  reworded pattern does not match the v1 line still in the file and the absence
  assertion finds that same v1 line present — and the other eight live checks report
  PASS**, because the v1 work they measure (the flow reorder, the records bullet,
  the pointer, both ledgers, the records, the scope lock, the vocabulary) is
  untouched by this revision. AC6 in particular must stay PASS: no `T-1000` pattern
  changes, so its twenty must-pass criteria are unaffected. Any other shape is worth
  reading before it is accepted — an AC4/AC5/AC7/AC8 failure would mean the revision
  reached further than it was scoped to.
- **Shapes the executing side must verify at the freeze, disclosed rather than left
  to be discovered:**
  1. **AC6's wall time.** It runs `bin/check-acs.sh` over `T-1000`'s twenty-four
     criteria from inside a `check:` line that is itself capped at 120s. Those
     criteria include one fixture suite, prompt-sync, the shape check and two board
     checkers. If the nested run exceeds the cap, the meaning-preserving correction
     is to raise the cap for this spec's own run (`CHECK_ACS_TIMEOUT`) rather than
     to weaken the criterion — and if that is judged unacceptable, to replace the
     aggregate run with a per-criterion extraction that reads the three amended
     `check:` values out of `T-1000` and runs only those. The aggregate form is
     preferred because it needs no nested quoting and because pinning the reported
     count at twenty-four is itself a parse control.
  2. **The `AC<n>: PASS (exit 0)` result-line format** that AC6 greps for, and the
     `^AC[0-9]+: (PASS|FAIL|SKIP)` count of twenty-four. Read out of
     `bin/check-acs.sh` while drafting (its summary loop prints one `running:` line
     and one result line per criterion, both on stdout); not executed.
  3. **`bin/check-board-headings.sh --base 6750dcf`** resolving. The branch point is
     an ancestor of `HEAD`, so `git merge-base` returns it; an explicit `--base`
     that fails to resolve is fail-closed (exit 2) by that script's own contract, so
     a wrong ref reports loudly rather than silently skipping the structural half.
  4. **`grep -qwF -- 'gh'`** matching a standalone word only. AC11 depends on it:
     the section legitimately contains `through`, and a substring match would
     false-positive on it.
  5. **`grep -cE '^[[:space:]]*- intent-hash \(v7\): [0-9a-f]{40}$'`** — an ERE
     interval on the host's `grep`. Both board sub-bullets are indented two spaces.
  6. **`bash bin/check-pii-shapes.sh --base develop`** enumerating this spec as a
     changed path and scanning it in full. It is written with no absolute path, no
     address-shaped token and no credential-shaped literal for exactly that reason.
- **`T-1000`'s frozen region is amended in this same change set**, so between the
  edit and the recorded v7 hash, `bin/check-intent.sh` reports drift on that spec.
  That interval is the ratification gate itself and is expected; AC7 is what proves
  it closed.
- **Static cross-check performed while drafting**, against the classes that have
  cost recent tasks a round each:
  - No `check:` line compares a command substitution against `sort` output. AC10 is
    the only criterion that sorts, and it compares **file to file** with `comm` over
    two sorted files.
  - No `check:` line globs a directory this task adds a file to. The three record
    files are named in full in AC9 and matched by an anchored regex in AC10, never
    as a directory glob.
  - No `check:` line anchors on a token that is already green at the base ref as
    proof of new work. AC1–AC4 pin lines that do not exist yet; AC5 is red at the
    base ref because the two anchors currently appear in the opposite order; AC6's
    must-pass list includes three criteria that are red until the amendment lands;
    AC7 asks for a v7 record that does not exist; AC8 asks for a fourth token that
    does not exist. The only already-green components are the positive controls,
    each labelled as such in its criterion.
  - `test -r` precedes every read of a file this task adds or negatively greps, and
    every extraction is proved non-empty before it is compared, so an unreadable
    file or a broken `awk` slice fails loudly instead of passing vacuously.
  - No suite runs twice inside one `check:`. Declared nesting: AC6 runs
    `T-1000`'s criteria, which transitively run the close-out fixture suite,
    prompt-sync, the shape check and both board checkers. AC9 runs the shape check,
    the hand-off linter and the heading checker again, at this task's own scope.
    That duplication is deliberate — if AC6's aggregate form is ever narrowed, this
    task's own board and change must still be checked — and it is disclosed rather
    than left for a reviewer to find.
  - AC10's scope lock unions `git ls-files --others --exclude-standard`, because
    this spec and all three record files are untracked at freeze time.
  - No `check:` value begins or ends with a backtick; the backticks that appear
    inside AC8's pattern sit within single quotes, where they are literal.
  - **Execution-context matrix**, one row per runnable command example this task
    puts into a tracked file or into a criterion. The class it guards against is a
    documented command that cannot run in the context its reader is in.

    | Command example | Where it lands | Context it runs in | Preconditions beyond a clone |
    |---|---|---|---|
    | `git log <previous-tag>..develop --oneline` | the new section (R3) | a shell at the repository root | none — `git clone` fetches tags by default, so the previous tag resolves; the placeholder is filled in by the operator |
    | `bash bin/check-readme-version.sh README.md README.ja.md` | the new section (R6) | a shell at the repository root | none — the script and both READMEs are tracked, and the argument list is the workflow's own |
    | the tag and fetch operations of R9 | the new section | a shell at the repository root | written as prose (`fetch`, `tag`, `push`, `confirm`) rather than as literal command lines, precisely because the exact invocation is the part that varies |
    | **v2** — updating `develop` and confirming it names the same commit as the remote, before cutting `release/vX.Y.Z` (R8) | the new section | a shell at the repository root, with a remote configured — which is already true of any clone the promotion step can be performed from | written as a **state to confirm**, not as a command line, for the same reason as the row above: the fetch invocation and the way an operator compares the two refs both vary, while the state that must hold does not. No new runnable example is introduced |
    | `bash bin/close-out.sh --task T-NNNN --issue N --pr N` | the flow's reworded bullet | a shell at the repository root | unchanged from before this task; `T-1000` AC4 grounds it |
    | every `check:` line in this spec | this spec | `bin/check-acs.sh`, from the repository root, on this branch | `develop` and `6750dcf` resolvable locally; no network, no tags, no environment variable |

    Nothing in the new section is a command that runs only in some environments,
    which is the same property AC11 approaches from the vocabulary side.
- **This spec is self-hosting and deliberately quotes strings it also asserts.**
  Every negative grep is scoped to one named file or to one extracted section slice;
  none is repository-wide, so this file's own prose naming a forbidden literal
  cannot trip a criterion.
- **The board's `## Active` section is empty at the branch point**, so inserting
  this task's entry touches no existing entry. The branch point additionally
  carries a repair that reattached T-1013's close-out sub-bullets to its Done
  entry, which is why AC9 and AC10 compare against `6750dcf` rather than `develop`:
  the comparison should show this task's insertion and nothing else.

## Open questions

None blocking. Two judgments are settled above rather than left open: when the
v6→v7 ratification is presented (D1) and whether a release gets a board entry
(D5). One finding is recorded and deliberately not acted on: `T-1000`'s AC23 has
been red since issue #30 shipped, and deciding between re-grounding it and
retiring it is not this task's call (D2).

## Notes for engineer

### v2 rework (2026-08-02) — read this first; the rest of this section is the v1 brief

**Three shipped bullets are replaced in place, and nothing else changes.** The
section, the flow bullets, the pointer, both ledgers and all the records are already
correct and stay as they are. Swap each of the three for the new `grep -qxF` pattern
in its criterion, one physical unwrapped line each, and confirm the superseded line
is gone rather than sitting alongside its replacement:

1. **AC1's second pattern** — `- **A release gets no board entry.** …` becomes
   `- **A release does not run the loop, and gets no board entry.** …`, which is
   longer: it carries the scoped exception to `## How changes get merged`.
2. **AC2's second pattern** — `- **Verify the preparation locally before pushing.** …`
   becomes `- **Verify the preparation locally before pushing, in two passes.** …`,
   which states the pre/post-commit split for all three checks instead of naming one.
3. **AC3's first pattern** — the promotion bullet gains `, and fetch `develop` before
   cutting it` in its bold opener plus two sentences of reason before the existing
   head-branch text, which is otherwise unchanged.

**Do not touch `## How changes get merged`.** The reconciliation is written into the
release bullet on purpose (AC1's body says why): that paragraph is `T-1000`-pinned
and editing it would cost a further ratification of a merged task. `T-1000` AC25
counts two of its sentences at exactly one occurrence each, so also do not
paraphrase either of them into the new bullet — check both counts are still one
after your edit, which AC6 does for you.

Each of the three criteria now also **asserts its superseded v1 opener absent**, so
replacing a line means replacing it: adding the new bullet while leaving the old one
above it fails, even though the new text is present.

**Mutation self-check for this round** (AC12, same discipline as v1, one at a time
on a scratch copy): each of the three reworded lines altered by a single character
must turn exactly its own criterion red; **each superseded v1 line pasted back
alongside its replacement must turn its criterion red too** — that is the one
mutation a presence-only check would have passed, and it is what the three new
absence assertions exist for; and after restoring, re-run AC6 to confirm none of
`T-1000`'s twenty must-pass criteria moved — in particular AC25, whose two counts
the new exemption sentence sits next to.

### v1 brief (unchanged, and already implemented)

**Read `T-1000`'s amended AC1, AC3 and AC17 before you touch `CONTRIBUTING.md`.**
They are already written and already ratified by the time you start; the canonical
bytes of the six pull-request-flow bullets live in AC3's `grep -qxF` patterns and
nowhere else. **Do not edit anything between `T-1000`'s intent-block markers.** The
hash recorded at the freeze covers exactly the region as it stands; changing so much
as a space inside it reports drift and costs another ratification round.

**Where the new section goes**: in `CONTRIBUTING.md`, after `## The board line
format` and before `## What does not belong in this file` — the position the
deferred draft occupied. Give it one unpinned intro line in the style of the other
sections (a single sentence saying these are the steps of a release as this
repository has performed one), then the ten canonical bullets in the order AC1,
AC2, AC3 list them. The intro line is not pinned, but it is inside AC11's slice, so
keep the three nouns and the one tool out of it too.

**The pull-request flow's three-bullet change**, in document order:

1. the new records-complete bullet (AC4) goes directly after the two-gate bullet;
2. the branching bullet (AC3 of `T-1000`) replaces the old *board-hygiene* bullet
   in place;
3. the run-and-publish bullet (AC3 of `T-1000`) replaces the old *publish* bullet
   in place.

The result is that the branching step now precedes the close-out step, which is
issue #31's whole content. Both superseded openings are asserted absent, so leaving
either old bullet in place alongside its replacement fails even though the new text
is present. Note the deliberate wording: the branching bullet says "the close-out
step" and never `close-out.sh`, because AC5 uses the first occurrence of that
string as a position anchor.

**`CLAUDE.md`**: replace the pointer bullet with the four-destination form below,
wrapped as shown. Each backticked heading token must sit whole on one physical line
— `T-1000` AC17 extracts them with `grep -oE` and looks each one up — and the
section must stay exactly one top-level bullet.

```markdown
- The `## The pull-request flow`, `## Confirming the CI check is green`,
  `## The board line format` and `## Cutting a release` sections of
  [`CONTRIBUTING.md`](CONTRIBUTING.md) document how work gets done here; this
  file does not restate them.
```

**Scope-lock allow-list.** Required:

```
CONTRIBUTING.md                                      (the new section + the three flow bullets)
CLAUDE.md                                            (the pointer bullet only)
.shell-team/specs/T-1000-operating-conventions.md    (already amended at the freeze — do not touch the intent block)
.shell-team/specs/T-1015-cutting-a-release.md
.shell-team/todo.md
```

Permitted in addition, not required: `.shell-team/provenance/T-1015.md`,
`.shell-team/reviews/T-1015.md`, `.shell-team/interventions/T-1015.md`,
`.shell-team/test-recipe.md`. The three record files under `.shell-team/` are
**required by AC9** even though the scope lock only permits them — write all three,
including the interventions record as a zero-entry sentinel if nothing interrupted
the task. This task dogfoods the line it adds.

**Producer-run mutation self-check, before the hand-off** (AC12). One mutation at a
time, in a scratch copy outside the repository, each one turning exactly its own
criterion red and green again on restore:

- **AC5, both directions.** Swap the two board-hygiene bullets back into their old
  order — AC5 must go red. Then, separately, delete the branching bullet entirely —
  AC5 must go red on the missing anchor rather than passing with one empty value.
- **AC11.** Insert each of the three nouns, and then the tool name as a standalone
  word, into the new section one at a time — each must go red. Then delete the
  section heading so the slice comes back empty — it must go red on the positive
  control, not pass an empty scan.
- **AC8.** Remove the release token from the pointer bullet — AC8 red. Then rename
  the section heading in `CONTRIBUTING.md` while leaving the bullet alone —
  `T-1000` AC17's correspondence half must go red, which is the defect class that
  produced its v6 amendment.
- **AC6.** Break one of the three amended criteria (delete one canonical line from
  `CONTRIBUTING.md`) — AC6 must go red naming that criterion. Confirm separately
  that the count assertion bites: it must fail if `T-1000` reports any number of
  criteria other than twenty-four.
- **AC7.** Append a second `- intent-hash` sub-bullet under `T-1000`'s entry — the
  criterion must go red, and `bin/check-intent.sh`'s own exit must be the structural
  2, not a drift 1.
- Each of AC1–AC4's canonical lines, one at a time, altered by a single character.

**Run every suite and dogfood step in `.github/workflows/check-handoff.yml`, in the
order the workflow lists them** — not just the ones you touched.
`.shell-team/test-recipe.md` records how to run one, and you may append a procedure
you establish there.

**Provenance file**: `.shell-team/provenance/T-1015.md`, same shape as the existing
files in that directory. The decisions worth recording are the ones you actually
make: the unpinned intro sentence, the exact insertion points, and anything you had
to resolve that this spec left to you. Ground each citation on a durable anchor — a
heading, a criterion number, a `check:` fragment — never a line number.

**Commit before evaluating any diff-based criterion.** AC10 reads `git diff` and
`git ls-files --others`; the second sees untracked files, the first does not, and
the union is only meaningful once your work is in one of those two states
deliberately rather than by accident.
