# T-1000 — this repository's operating conventions, in this repository

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1000
**Source**: GitHub issue #25 (RipsawJP/shell-team).
**Branch**: `docs/operating-conventions` (from `develop`).

## Problem

How work actually gets done here — the pull-request flow, the release
procedure, how a green CI check is confirmed, the board's strict `## Active`
line format — is not written down in this repository. It lived in a status
document in a private predecessor repository and in the maintainer's
per-checkout local memory, and neither travelled. A contributor has access to
neither, so the workflow this repository documents is not reproducible from a
clone. The recovery source for that content is also full of machine- and
operator-specific detail, which makes "write it down" and "write down only the
part that generalises" the same task.

## Goal

<!-- BEGIN intent-block: T-1000 -->

`CONTRIBUTING.md` carries the three operating conventions a contributor needs,
cannot otherwise obtain from a clone, and that **this repository has actually
executed** — the pull-request flow through to publishing the board edit, how the
CI check's green state is confirmed, and the board line format with its
note-placement rule — and every convention sentence in it is either grounded in
an artefact in this tree or is visibly marked in the document itself as a
maintainer decision rather than a measurement. The release procedure is
deliberately **not** among them: it has never been run here, so there is nothing
to observe and no way to verify that what is written is complete. `CLAUDE.md`
gains a single pointer bullet where it previously carried a second, drifting
copy.
Nothing specific to one machine, one operator, or one person's oversight
preferences enters a tracked file, and no existing statement in `README.md`,
`CLAUDE.md` or `docs/` is duplicated — each is pointed at. No behaviour changes:
no script, test, workflow, agent or generated prompt block is touched.

## Non-goals

- **Writing the release procedure. Deferred to a task that runs one first.** A
  `## Cutting a release` section was drafted, reviewed four times, and is removed
  here rather than polished further. The reason is not the quality of the prose:
  `develop..main` is empty, so this repository has **never executed** the procedure,
  and the section was written from recollection of how it ought to go. Three of the
  defects this task produced were the same shape — a missing step (the changelog
  entry, the manifest bump, and, in the pull-request flow, publishing the board
  edit) — and a missing step is not greppable. Every one of this task's criteria
  verifies that what is written is *true*; not one can verify that what is
  *needed* is written, and no criterion of that kind can be built for a procedure
  with no execution to observe. Cutting v1.1.0 is already on the backlog, so the
  correct order is to run the release, watch what it actually takes, and write it
  from that. This is a sequencing decision, not an abandonment: the follow-up is
  filed as its own issue and the measurements already taken are carried forward in
  DP-7 so they do not have to be redone.
- **Fixing `docs/workflow.md`.** Its `## Conventions` section states the branch
  form `feat/T-XXX-<slug>` (contradicted by 9 of 9 merged pull requests) and
  spells the spec and review paths in the legacy `docs/specs/` / `tasks/reviews/`
  layout. Both are wrong-or-stale and both are somebody else's issue; this task
  neither propagates those forms nor corrects them, and AC23 locks that file
  byte-unchanged.
- **Fixing the stale CI step name in the generated playbook blocks.**
  `agents/pm-spec.md` claims an invalid Active line fails a CI step named
  "Lint tasks/todo.md"; no step by that name exists (the real one is "Lint the
  shipped board template (hand-off linter)", and its target is the shipped
  template, not this repository's board). That text sits inside a generated
  prompt-block region governed by `bin/check-prompt-sync.sh` and can only be
  changed through `bin/playbook-promote.sh`, so editing it here would red
  prompt-sync. AC23 locks it as-is.
- **Creating `CONTRIBUTING.ja.md`.** It does not exist today; `CLAUDE.md`'s
  Language section makes a `*.ja.md` counterpart optional for human-facing
  documentation, and a second copy is a drift surface with no new reader.
- **Adding any new mechanical check.** No `CHANGELOG` parity check, no
  `marketplace.json` version check, no tag validation, no new CI step, no new
  suite. This task changes documentation only (AC24).
- **Asserting branch-protection specifics.** The GitHub API reports both
  `develop` and `main` as protected, but the protection *details* — the required
  status-check context names, the force-push and deletion settings — live in
  GitHub's settings and are not readable from this tree. The document states
  that both branches are protected and that the check must report success, and
  says nothing further (AC20).
- **Changing the loop's completion gate, or restating it.** The two-gate rule
  already has one statement in `CONTRIBUTING.md` and adopter-facing copies in
  `CLAUDE.md` and `docs/adopting.md`; this task attaches to the existing
  statement instead of adding a fourth (AC25).
- **Re-deriving the `mergeable_state` caution from the tree.** That string
  appears nowhere in this repository; the caution is an operational observation
  and is written as one.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup, invokes
scripts as `bash bin/<script>.sh` (never a bare name), and uses `develop` as the
base ref. **The exact bytes of every canonical line this task adds are the
`grep -qxF` patterns below** — there is no second copy of them elsewhere in this
spec to drift from (DP-2). Each canonical line must be one physical, unwrapped
line in `CONTRIBUTING.md`.

- [ ] **AC1** `CONTRIBUTING.md` carries the four new section headings, exactly as
  spelled, and **no trace of the deferred release section survives**: not the
  heading, and not any of its eight canonical bullets. A section is removed by
  deleting it, and the failure mode of a removal is leaving part of it behind, so
  every bullet the section ever carried is asserted absent by a distinctive
  fragment — including both wordings of the manifest bullet, since the earlier one
  was superseded within this task and either could be the one still sitting in the
  working tree. The file is proved readable first (positive control).
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && grep -qxF '## The pull-request flow' CONTRIBUTING.md && grep -qxF '## Confirming the CI check is green' CONTRIBUTING.md && grep -qxF '## The board line format' CONTRIBUTING.md && grep -qxF '## What does not belong in this file' CONTRIBUTING.md && ! grep -qxF '## Cutting a release' CONTRIBUTING.md && ! grep -qF -- '- **Bump the `version` field of' CONTRIBUTING.md && ! grep -qF -- '- **The version lives in one place**' CONTRIBUTING.md && ! grep -qF -- '- **Bump the static version badge in both' CONTRIBUTING.md && ! grep -qF -- '- **Nothing else is machine-checked.**' CONTRIBUTING.md && ! grep -qF -- '- **Promote `develop` to `main` through a pull request**' CONTRIBUTING.md && ! grep -qF -- '- **Tag the release on `main` with an annotated tag' CONTRIBUTING.md && ! grep -qF -- '- **The install side is documented elsewhere**' CONTRIBUTING.md && ! grep -qF -- '- The promotion and the tag are a **maintainer decision, not an observed practice**' CONTRIBUTING.md && ! grep -qF -- '- **Add the release entry to `CHANGELOG.md`' CONTRIBUTING.md
- [ ] **AC2** The new content is attached to `CONTRIBUTING.md` rather than written
  over it, with exactly one licensed exception: the opening paragraph of the
  existing `## About CI on your pull request` section, whose enumeration of what CI
  checks is inaccurate and is corrected in place by AC27. **The set of deleted lines
  must equal that paragraph exactly** — every line of it and nothing else — so a
  reflow, a re-punctuation, or a deletion anywhere else in the file still fails. A
  bare "at most N deletions" bound is deliberately not used: it does not constrain
  *where* the deletion happened. The expected set is derived from the base blob by
  content anchor rather than transcribed here, both because the paragraph contains
  an ASCII apostrophe a single-quoted pattern cannot hold and so the criterion
  reads the real base text instead of a copy of it; the line count is asserted as a
  positive control that the anchor actually found the paragraph. **Merge-point-scoped**:
  it resolves `develop:CONTRIBUTING.md` and therefore goes stale once other work
  changes that file on `develop`. That is expected; do not widen its base-ref
  resolution or re-derive it per rework round.
  - check: exp="$(git show develop:CONTRIBUTING.md | awk '/^Some checks in this repository test the shipped scripts/{f=1} f{print} f&&/your change\.$/{exit}')" && test "$(printf '%s\n' "$exp" | wc -l | tr -d ' ')" -eq 4 && del="$(git diff develop -- CONTRIBUTING.md | grep -E '^-' | grep -vE '^---' | sed 's/^-//')" && test "$del" = "$exp" && test "$(git diff --numstat develop -- CONTRIBUTING.md | awk '{print $1}')" -gt 0
- [ ] **AC3** The pull-request flow is stated as six canonical bullets: the base
  branch and branch-name form, the pull-request target, the deferral to the
  existing two-gate statement, the board-hygiene step, **publishing the board edit**,
  and the manual issue close. **The flow has to reach a committed state.**
  `bin/close-out.sh` rewrites the board file and stops: it runs no git command at
  all, so the edit is left uncommitted in the working tree, and `develop` is
  protected, so it cannot be pushed there directly. Without that bullet the
  documented flow ends with a modified file and no instruction, which is the same
  missing-step class as the deferred release section — the difference, and the
  reason this one is written rather than deferred, is that the step **has been
  executed here**: the shape below is read off the commit that closed the previous
  three tasks, not off recollection. The naming bullet makes the *form* `<type>/<slug>` normative and reports
  the observed types as observed, with the set left open — the measurement is
  `docs` 5, `chore` 3, `feature` 1, `fix` 0, so a claim that `fix` is "in use"
  would be false while a prohibition on ever using it would be an invention.
  **The same bullet states the `main` rule as a rule, not as a fact about the
  history.** The tree contradicts the factual form exactly once: the branch behind
  the first pull request has its merge base at the commit that was `main`'s tip at
  the time, before the `develop` flow existed. A contributor does not need that
  exception, and a "never" that the tree disproves is the same defect class as the
  `fix` claim, so the clause becomes an instruction. The superseded wording is
  asserted absent.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && grep -qxF -- '- **Branch from `develop`**, named `<type>/<slug>` — the branch names in this repository so far use the types `docs`, `chore` and `feature`, and the set is open. `main` is the release line: do not branch from it.' CONTRIBUTING.md && ! grep -qF -- 'is never the base of a feature branch' CONTRIBUTING.md && grep -qxF -- '- **Open the pull request against `develop`.** The workflow runs on pull requests targeting `main` and `develop`, so the check reports on the pull request itself.' CONTRIBUTING.md && grep -qxF -- '- **Both gates must be green before the merge** — QA and the cross-provider review, as stated under "How changes get merged" above. This section adds the mechanics around that gate and does not restate it.' CONTRIBUTING.md && grep -qxF -- '- **Merge, then run board hygiene.** `bash bin/close-out.sh --task T-NNNN --issue N --pr N` moves the board entry to `## Done`, rewrites its status flag, and prints what to do next.' CONTRIBUTING.md && grep -qxF -- '- **Publish the board edit as its own pull request.** `bin/close-out.sh` rewrites the board file and stops there — it runs no git command — and `develop` is protected, so the edit cannot go straight to it. Branch from `develop` at the merge commit, commit that one file with a message of the form `board: close out T-NNNN — merged via PR #N`, and open that branch as a second pull request.' CONTRIBUTING.md && grep -qxF -- '- **Close the GitHub issue by hand.** A merge into `develop` does not auto-close an issue, so `bin/close-out.sh` prints the `gh issue close` command for a human to run — it never calls `gh` itself.' CONTRIBUTING.md
- [ ] **AC4** Both claims this document makes about `bin/close-out.sh` are grounded
  in the producer, not in recollection: it says itself that a `develop` merge does
  not auto-close, it does write the board file, and it invokes **no git command** —
  which is exactly why the publish bullet in AC3 has to exist. The suite that locks
  the printed procedure and the never-invoking-`gh` property still passes. The
  no-git assertion carries its own **positive control on the pattern**: the same
  regex is run against a script that does invoke git in command position and must
  match there, so a silently broken pattern cannot report a clean absence.
  - check: grep -qF 'develop merges do NOT auto-close' bin/close-out.sh && grep -qF 'cat "$TMP_BOARD" > "$BOARD"' bin/close-out.sh && grep -qE '(^|[;&|(]|\$\()[[:space:]]*git[[:space:]]' bin/check-pii-shapes.sh && ! grep -qE '(^|[;&|(]|\$\()[[:space:]]*git[[:space:]]' bin/close-out.sh && bash tests/close-out/run.sh
- [ ] **AC5** The contradicted branch form is not propagated: no `feat/T-` string
  appears anywhere in `CONTRIBUTING.md`.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && ! grep -qF 'feat/T-' CONTRIBUTING.md
- [ ] **AC9** The CI-green procedure is stated as five canonical bullets: the one
  workflow and its check name, the confirm-the-conclusion rule with the
  mergeability caution, local running, the two checks that apply to a
  documentation-only pull request, and what CI does not do. **The fourth bullet
  states both checks at their measured scope, not at their invocation shape.**
  `bin/check-pii-shapes.sh` takes `--base`, but its own header records that changed
  paths are enumerated from `git diff --raw`, each surviving path is then read
  through `git cat-file`, and "The scanned unit is the FULL committed content of
  each changed path … there is no base-blob comparison" — so "on the diff against
  the base branch" was false in the way that costs a contributor real time: a shape
  a file already carries can surface on a change that touched a different part of
  that file, and a document that promised diff scoping would send that contributor
  to the maintainer instead of to the cause. `bin/check-commit-identity.sh` is
  tightened from the merely loose "on the commits" to its measured range — its
  header declares `git rev-list --no-merges <merge-base>..HEAD` and that "Merge
  commits are excluded wholesale" — because a contributor who merges the base back
  into a branch needs to know which side of that line the merge commit falls on.
  The old text of both is additionally asserted absent, since a rework that adds a
  corrected line without removing the superseded one would otherwise pass.
  **One more narrowing, found by re-reading the checker rather than by review.** The
  previous version of this bullet said a pre-existing shape "is reported" — an
  unconditional claim, while the checker ships `KNOWN_SHAPE_PATHS` (DP-8): a short,
  per-file, test-locked list of paths that deliberately carry a shape as a fixture
  for another guard, on which nothing is reported. That is the same defect class as
  the three lines this round was opened for — a sentence wider than the mechanism it
  describes — so the exception is named in the bullet instead of being papered over
  with a weaker verb, and the superseded wording is asserted absent as well.
  - check: grep -qxF -- '- **There is one workflow and one job.** `.github/workflows/check-handoff.yml` — its job display name, and the check name to look for on a pull request, is `check-handoff lint`.' CONTRIBUTING.md && grep -qxF -- '- **Confirm the reported conclusion of that check on the pull-request head commit.** A mergeability field such as `mergeable_state: clean` is not evidence: it describes whether the branches can be combined, and it can read clean before any check has reported a conclusion at all.' CONTRIBUTING.md && grep -qxF -- '- **Run the suites locally before pushing.** There is no single "run everything" entry point; the workflow file is the authoritative list of every suite and dogfood step, in the order it runs them, and `.shell-team/test-recipe.md` records how to run one.' CONTRIBUTING.md && grep -qxF -- '- **Two CI steps apply even to a documentation-only pull request.** `bin/check-pii-shapes.sh` uses the base branch only to enumerate the paths a change touches and then scans the full committed content of each of them, not the added lines alone — so a shape a file already carried surfaces on a change that touched a different part of that file, unless that path is on the short, test-locked known-shapes list inside the checker. `bin/check-commit-identity.sh` inspects the non-merge commits from the merge base to the head, and never a merge commit.' CONTRIBUTING.md && ! grep -qF -- 'on the diff against the base branch' CONTRIBUTING.md && ! grep -qF -- '`bin/check-commit-identity.sh` on the commits' CONTRIBUTING.md && ! grep -qF -- 'already carried is reported by a change' CONTRIBUTING.md && grep -qxF -- '- **What CI does not do.** It lints the shipped board template, not the board in this repository, and although the spec-layer checkers (`bin/check-acs.sh`, `bin/check-intent.sh`, `bin/check-provenance.sh`) have fixture suites in CI, no step runs them against the specs here. Run those yourself.' CONTRIBUTING.md
- [ ] **AC10** The check name in the document is not transcribed from memory: it
  equals the job display name extracted from the workflow file itself.
  - check: n="$(awk -F': ' '/^    name: /{print $2; exit}' .github/workflows/check-handoff.yml)" && test "$n" = 'check-handoff lint' && grep -qF "$n" CONTRIBUTING.md
- [ ] **AC11** The "what CI does not do" claim is true of the workflow as it
  stands: the hand-off linter runs against the shipped template and never against
  this repository's board; the spec-layer checkers and the board-heading checker
  have no step that runs them, while the `check-acs` fixture suite does have one
  (the positive control the bullet's wording depends on).
  - check: grep -qF 'bash bin/check-handoff.sh templates/todo-template.md' .github/workflows/check-handoff.yml && grep -qE 'run: bash tests/check-acs/run\.sh' .github/workflows/check-handoff.yml && ! grep -qE 'run: (bash )?bin/check-(acs|intent|provenance|board-headings)\.sh' .github/workflows/check-handoff.yml && ! grep -qF 'check-handoff.sh .shell-team/todo.md' .github/workflows/check-handoff.yml
- [ ] **AC12** The board line format is stated as five canonical bullets: that
  `## Active` is machine-linted and both separators are a space-padded U+2014 EM
  DASH, the no-parenthetical rule, the note-placement rule with its consequence
  for `## Done`, how to lint the board locally through the path resolver, and the
  deferral of the flag vocabulary to the shipped template.
  **The linting bullet describes what `bin/check-board-headings.sh` can actually
  see.** Its header states that it diffs the set of `T-NNN` heading ids and fails on
  deletion, id-level replacement, or duplication, and its extraction takes one
  `T-[0-9]+` per line — so an edit that rewrites a title, a flag or a spec path
  while leaving the id in place is invisible to it. The incident it was built for is
  covered (a clobbered heading loses its old id), which is why "catches an edit that
  silently replaced the heading line" was true of the accident and too wide for the
  mechanism. "Only" is separately true and kept: no other checker compares board
  headings against a base ref. The boundary is stated in the bullet rather than
  omitted, so a contributor does not over-trust the check; the superseded wording is
  asserted absent.
  - check: grep -qxF -- '- **The `## Active` section is machine-linted.** `bin/check-handoff.sh` validates every top-level `- [ ]` line in it against a fixed shape and rejects an unrecognised status flag; both separators in that shape are a space-padded U+2014 EM DASH.' CONTRIBUTING.md && grep -qxF -- '- **Nothing may come between the status flag and the spec pointer.** A parenthetical — a date, a review round, a pull-request number — placed after the flag breaks the match; the closing backtick of the flag must be followed directly by the spec pointer.' CONTRIBUTING.md && grep -qxF -- '- **Notes go in indented sub-bullets under the entry.** The linter skips indented lines, the `_(none)_` placeholder, and any top-level line that is not `- [ ]`, which is why the `- [x]` entries under `## Done` are never inspected.' CONTRIBUTING.md && grep -qxF -- '- **Lint the board before pushing**: `bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)"`, and `bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop`, which compares the set of `T-NNN` heading ids against the base ref — it is the only check that notices an id deleted, overwritten with a different id, or duplicated, and it cannot see a rewrite that leaves the id in place.' CONTRIBUTING.md && ! grep -qF -- 'silently replaced the heading line of an existing entry' CONTRIBUTING.md && grep -qxF -- '- **The status-flag vocabulary is not restated here**: it is listed in `templates/todo-template.md` and enforced by `bin/check-handoff.sh`.' CONTRIBUTING.md
- [ ] **AC13** Positive-and-negative control on the documented format: the worked
  example line is extracted from `CONTRIBUTING.md` itself and fed through the real
  enforcer. In the documented shape — with an indented sub-bullet note, and with a
  free top-level prose line and a deliberately malformed `- [x]` line under
  `## Done` — the linter exits 0; with a parenthetical inserted between the flag
  and the spec pointer it exits exactly 1. An exact exit code is asserted on the
  negative case so an unreadable-input error (exit 2) cannot pass as a detected
  violation.
  - check: d="$(mktemp -d "${TMPDIR:-/tmp}/t1000.XXXXXX")" && ex="$(grep -m1 -F -- '- [ ] **T-1042**' CONTRIBUTING.md)" && test -n "$ex" && printf '# Tasks\n\n## Active\n\n%s\n  - a note from whichever agent touched it last\n\nA free top-level prose line, which the linter does not inspect.\n\n## Done\n\n- [x] deliberately malformed Done line\n' "$ex" > "$d/ok.md" && bash bin/check-handoff.sh "$d/ok.md" && printf '# Tasks\n\n## Active\n\n%s\n' "$(printf '%s' "$ex" | sed 's/` — spec:/` (2026-07-28) — spec:/')" > "$d/bad.md" && { bash bin/check-handoff.sh "$d/bad.md" >/dev/null 2>&1; test "$?" -eq 1; } && rm -rf "$d"
- [ ] **AC14** This task dogfoods its own documentation: the board resolved through
  `bin/team-paths.sh` carries a `T-1000` entry, that board passes the hand-off
  linter, and no existing task heading was deleted, replaced or duplicated by the
  insertion.
  - check: B="$(bash bin/team-paths.sh --get todo)" && test -r "$B" && grep -qF -- '- [ ] **T-1000** ' "$B" && bash bin/check-handoff.sh "$B" && bash bin/check-board-headings.sh "$B" --base develop
- [ ] **AC15** The scope boundary is stated in the document as three canonical
  bullets: no machine- or operator-specific content, no personal oversight
  preferences (pointing at `docs/tuning-oversight.md` rather than re-arguing it),
  and no branch-protection configuration.
  - check: grep -qxF -- '- **Nothing specific to one machine or one operator.** No absolute paths into a home directory, no account-to-remote mapping, no credential or token configuration, no per-host execution environment quirks, no tooling only one maintainer has installed. A convention that cannot be re-derived from a fresh clone is not a convention of this repository.' CONTRIBUTING.md && grep -qxF -- '- **No personal oversight preferences.** How often a session stops to ask is a working preference, kept in the gitignored `CLAUDE.local.md`; [`docs/tuning-oversight.md`](docs/tuning-oversight.md) documents that mechanism and this file does not restate it.' CONTRIBUTING.md && grep -qxF -- '- **No branch-protection configuration.** Both `develop` and `main` are protected, and `check-handoff lint` must report success before a merge; the specific rule set lives in the GitHub settings for this repository and is not readable from a clone, so it is not asserted here.' CONTRIBUTING.md
- [ ] **AC16** Negative — zero operator- or machine-specific content actually lands:
  the shape checker is clean on this change, and none of the named forbidden
  classes appears in `CONTRIBUTING.md`. Scoped to that one file on purpose (DP-4),
  and paired with a positive control so an unreadable file cannot pass as clean.
  Per-host execution environment gets a **count anchor** rather than an absolute
  absence, because `CONTRIBUTING.md` already carries exactly one legitimate
  occurrence — the pointer line describing what `docs/distribution.md` covers —
  which AC2 forbids deleting; the count must stay at one.
  - check: bash bin/check-pii-shapes.sh --base develop && grep -qF 'Thanks for looking' CONTRIBUTING.md && test "$(grep -ciF 'sandbox' CONTRIBUTING.md)" -eq 1 && ! grep -qiF -e 'git@github' -e '/Users/' -e '/home/' -e 'personal access token' -e 'token scope' -e 'excludedCommands' CONTRIBUTING.md && ! grep -qw -e 'PAT' -e 'MCP' CONTRIBUTING.md
- [ ] **AC17** `CLAUDE.md`'s `## Branches and pull requests` section is exactly one
  pointer bullet naming `CONTRIBUTING.md`, the claims it used to carry are gone,
  no heading line anywhere in `CLAUDE.md` was added or removed, and the file did
  change (positive control). A wrapped continuation of the single bullet is
  allowed; a second top-level line is not.
  **The bullet also has to point at something that exists.** The shape assertions
  above cannot tell: they check that a bullet is there and mentions the file, never
  what it sends the reader to look for. When `## Cutting a release` was deferred out
  of `CONTRIBUTING.md`, the bullet went on naming a release procedure that no longer
  had a section — a file this repository treats as a trusted instruction channel,
  directing a reader to a heading that is not there, with two criteria watching and
  neither able to see it, because one inspected form and the other inspected a
  different file. The gap was the **correspondence between them**, so that is what
  is checked now: the topics are **read out of the bullet at run time** — it names
  each destination as a backticked `## …` heading token — and every one of them must
  match a real heading in `CONTRIBUTING.md`. A byte-exact pin on the bullet would
  not do this; it would catch the bullet changing, whereas what happened is the
  bullet staying still while its destination was removed. The direction is
  deliberately one-way: a named topic must have a section, but a section need not be
  named (`## What does not belong in this file` is real and unnamed by design). The
  count is pinned at three as the extraction positive control — a broken pattern
  yields zero and fails loudly instead of passing a vacuous empty loop — and it also
  makes any change to the pointer scope require a spec change, which is the right
  friction for this file. Absence of the superseded wording is asserted two ways:
  the exact phrase, and any mention of releasing at all, so a reworded revival is
  caught as well as a verbatim one.
  - check: grep -qxF '## Branches and pull requests' CLAUDE.md && s="$(awk '/^## Branches and pull requests$/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)" && test "$(printf '%s\n' "$s" | grep -cE '^[^[:space:]]')" -eq 1 && printf '%s\n' "$s" | grep -qE '^- ' && printf '%s\n' "$s" | grep -qF 'CONTRIBUTING.md' && ! printf '%s\n' "$s" | grep -qF 'the release procedure' && ! printf '%s\n' "$s" | grep -qiF 'releas' && hs="$(printf '%s\n' "$s" | grep -oE '`## [^`]+`' | tr -d '`')" && test "$(printf '%s\n' "$hs" | grep -c '^## ')" -eq 3 && ok=1 && while IFS= read -r h; do [ -n "$h" ] || continue; grep -qxF "$h" CONTRIBUTING.md || ok=0; done <<< "$hs" && test "$ok" -eq 1 && ! grep -qF 'reject force pushes' CLAUDE.md && test "$(git diff develop -- CLAUDE.md | grep -cE '^[+-]#')" -eq 0 && test "$(git diff --numstat develop -- CLAUDE.md | awk '{print $1}')" -gt 0
- [ ] **AC18** Negative — the generated prompt blocks and every agent definition are
  byte-unchanged, and prompt-sync is green. Paired with a positive control proving
  the diff command sees this task's own change.
  - check: test -z "$(git diff --name-only develop -- templates/prompt-blocks agents)" && test -n "$(git diff --name-only develop -- CONTRIBUTING.md)" && bash bin/check-prompt-sync.sh
- [ ] **AC19** Negative — the document does not enumerate CI's suite list (30+
  entries, stale the moment a suite is added): it carries zero concrete
  `tests/<name>/run.sh` paths and instead points at the workflow file and at the
  test recipe.
  - check: grep -qF '.github/workflows/check-handoff.yml' CONTRIBUTING.md && grep -qF '.shell-team/test-recipe.md' CONTRIBUTING.md && test "$(grep -oE 'tests/[a-z][a-z0-9-]*/run\.sh' CONTRIBUTING.md | wc -l | tr -d ' ')" -eq 0
- [ ] **AC20** Negative — branch-protection restraint: the document nowhere asserts
  a protection setting the tree cannot prove.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && ! grep -qiF -e 'force push' -e 'force-push' -e 'required status check' -e 'branch protection rule' CONTRIBUTING.md
- [ ] **AC21** A decision provenance file for this task exists and is
  schema-conformant.
  - check: bash bin/check-provenance.sh .shell-team/provenance/T-1000.md
- [ ] **AC22** Diff-scope closure: no file outside the allow-list changed, and the
  diff is non-empty (positive control). **This criterion is merge-point-scoped and
  is expected to go stale after this task merges** — once later work lands on
  `develop`, the expected set no longer describes reality. That is by design; do
  not widen its base-ref resolution or re-derive it per rework round to keep it
  evergreen, because merge-ranging it would trade away the confinement it exists
  to provide.
  - check: git diff --name-only develop | grep -q . && test "$(git diff --name-only develop | grep -vcE '^(CONTRIBUTING\.md|CLAUDE\.md|\.shell-team/todo\.md|\.shell-team/specs/T-1000-operating-conventions\.md|\.shell-team/provenance/T-1000\.md|\.shell-team/reviews/T-1000\.md)$')" -eq 0
- [ ] **AC23** Negative — the three named non-goals hold: nothing under `docs/`
  changed, `docs/workflow.md` still carries the contradicted branch form (it is
  someone else's issue, not silently fixed here), the stale generated CI step name
  in `agents/pm-spec.md` is untouched, and no Japanese counterpart of
  `CONTRIBUTING.md` was created.
  - check: test -z "$(git diff --name-only develop -- docs)" && grep -qF 'feat/T-XXX-<slug>' docs/workflow.md && grep -qF 'Lint tasks/todo.md' agents/pm-spec.md && test ! -e CONTRIBUTING.ja.md && test ! -L CONTRIBUTING.ja.md
- [ ] **AC24** Negative — no behaviour change and no new mechanical check: nothing
  under `bin/`, `tests/`, `.github/` or `templates/` changed, with a positive
  control proving the diff command is looking at a real change.
  - check: test -z "$(git diff --name-only develop -- bin tests .github templates)" && test -n "$(git diff --name-only develop -- CONTRIBUTING.md)"
- [ ] **AC25** Negative — no duplication of what another file already carries: the
  two sentences of the existing merge-gate section still appear exactly once each,
  and the dogfood command, the changelog line policy and the marketplace-update
  procedure are not copied in. With the release section deferred these three are no
  longer even pointed at, so the negative half now holds trivially — it is kept
  because it is a **regression lock**: it is what fails if the deferred prose is
  quietly reinstated by copying from `README.md` or `docs/distribution.md` instead
  of from a release that was actually run.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && test "$(grep -cF 'Merging always requires the maintainer' CONTRIBUTING.md)" -eq 1 && test "$(grep -cF 'goes through the loop this' CONTRIBUTING.md)" -eq 1 && ! grep -qF 'claude --plugin-dir' CONTRIBUTING.md && ! grep -qF 'one entry per release, newest first' CONTRIBUTING.md && ! grep -qF 'plugin marketplace update' CONTRIBUTING.md
- [ ] **AC26** Negative — the status-flag enum is not reproduced: only the single
  flag inside the worked example may appear, and none of the other six.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && ! grep -q -e 'READY_FOR_ENG' -e 'READY_FOR_QA' -e 'READY_FOR_REVIEW' -e 'READY_FOR_MERGE' -e 'BLOCKED' -e 'REWORK' CONTRIBUTING.md
- [ ] **AC27** The document does not contradict itself: the inaccurate enumeration
  in the existing `## About CI on your pull request` section is gone, replaced by a
  pair of canonical lines that are accurate about all three of the things the old
  sentence named, and the correct half of that section — the instruction to say so
  in the pull request when a failure looks unrelated — survives. The replacement
  deliberately does **not** present an exhaustive list of the checks that run
  against this tree: there are five dogfood steps plus the shipped template and
  contract lints, and an enumeration would be a fresh unverified claim of exactly
  the kind this task exists to prevent. It is precise only where the old text was
  wrong, and the positive half (prompt blocks) is named because it is the one item
  of the three that was right.
  **The second line asserts the absence of a specific CI action, never the absence
  of a file from CI.** The distinction is the whole point: no step *lints* the board
  this repository runs on and no step *evaluates* a task spec against its
  acceptance criteria, yet both are read byte-for-byte by the shape check the moment
  a change touches them. A line that said they are simply "not in that set" would be
  false in the same direction as the sentence it replaced, and two mutually
  reinforcing understatements in one document are worse than one — a contributor who
  reads both arrives at a wrong conclusion with more confidence, not less.
  Two prior versions of this line are therefore asserted absent: the original
  pre-task enumeration, and the superseded set-membership claim.
  - check: grep -qxF -- 'Some checks in this repository test the shipped scripts — shellcheck, and the fixture suites under `tests/`. Others run a shipped script against this repository itself or against a shipped template, and those can fail for reasons that have nothing to do with your change.' CONTRIBUTING.md && grep -qxF -- 'Two CI steps a reader might expect do not exist: nothing lints the board this repository runs on — the lint target is the shipped template, `templates/todo-template.md` — and nothing evaluates a task spec against its acceptance criteria, since the spec-layer checkers appear in CI only as fixture suites. The board and the specs are still read in full by the PII shape check whenever a change touches them, and the generated prompt blocks are genuinely verified: `bin/check-prompt-sync.sh` runs against this tree on every pull request.' CONTRIBUTING.md && ! grep -qF -- '— the board, the task specs, the generated prompt blocks' CONTRIBUTING.md && ! grep -qF -- 'Two things are **not** in that second set' CONTRIBUTING.md && grep -qF 'If a check fails in a way that looks unrelated to what you touched' CONTRIBUTING.md
### Retired criteria

**AC6, AC7, AC8 and AC28 no longer exist.** All four verified the deferred
`## Cutting a release` section: its six canonical bullets, the tree facts behind
them, the ratified-decision disclosure, and the changelog step. With the section
out of scope they had nothing left to verify — AC7 in particular would have kept
asserting facts about `.claude-plugin/plugin.json` and `bin/check-readme-version.sh`
that no sentence in the deliverable relies on any more, which is a check that
passes whether or not the document is right: the vacuous-PASS class this project
refuses elsewhere. What remains of them is AC1, which asserts that every line they
used to pin is **absent**.

The surviving numbers are deliberately **not** renumbered. Closing the gaps would
mean rewriting every cross-reference in two tables, this section, and the engineer
notes, and a partial renumber leaves a criterion pointing at a criterion that no
longer means what it says — a worse failure than a visible gap, and one this task
has already been warned about. The gap is documented here instead, which answers
the only question it raises. **24 criteria remain**: AC1–AC5 and AC9–AC27.

## Input space

This task produces prose in two tracked files and adds no runtime code, so it has
no input surface of its own. It does, however, make claims *about* the input space
of existing enforcers, and its acceptance criteria feed inputs to them. That is
the space declared here.

**Reachable input classes** — what real usage of the documented conventions can
produce, and what the document must therefore be correct about:

1. A top-level `## Active` line in the documented shape: a live task id (`T-`
   followed by digits), a title containing spaces and possibly backtick-wrapped
   words, one of the seven status flags, and a spec path ending in `.md` under
   either supported layout (`.shell-team/specs/…` or the legacy `docs/specs/…`).
2. The same line followed by one or more indented sub-bullet notes — two-space or
   tab indented, and possibly quoting an em dash or a flag token inside the note
   prose.
3. The malformed variant this repository actually produced before: a parenthetical
   (a date, a review round, a pull-request number) inserted between the flag's
   closing backtick and the ` — spec:` pointer.
4. `## Done` entries in `- [x]` form, and the `_(none)_` placeholder of an empty
   section — both of which the linter passes over.
5. A board edit that appends an entry and, as a side effect, overwrites an
   existing entry's heading line — the class `bin/check-board-headings.sh` exists
   for.
6. The working-tree state `bin/close-out.sh` leaves behind: a modified board file,
   uncommitted, with no branch created and nothing staged — the input the
   publish-the-board-edit bullet has to be correct about.
7. A documentation-only pull request against `develop`, which still reaches the
   diff-scoped PII shape check and the commit-identity check.
8. The base-branch content of `CONTRIBUTING.md` as `git show develop:CONTRIBUTING.md`
   returns it — specifically the four-line opening paragraph of
   `## About CI on your pull request`, which AC2 reads by content anchor to decide
   which deletions are licensed and which are not.

**Out-of-scope synthetic extremes** — named and declined:

1. Board files whose `## Active` heading uses ATX-closing notation or sits inside
   a code fence. `bin/check-board-headings.sh`'s own header records that the
   matching weakness is deliberately left in `bin/check-handoff.sh`; this task
   documents the format, it does not harden either parser.
2. Em-dash look-alikes (U+2013 EN DASH, U+2015 HORIZONTAL BAR, a hyphen-minus
   pair). The document names U+2014; an impostor separator simply fails the
   linter, and enumerating every look-alike is not this document's job.
3. Adversarially long titles or notes, thousands of `## Active` entries, and
   mixed or non-UTF-8 encodings in a board file.
4. **Everything on the release path**: the manifest version value and its
   shields.io-escaped badge counterpart, non-semver manifests, alternative badge
   providers, the changelog pair, tags, and the promotion of `develop` to `main`.
   This was a reachable class in earlier versions of this spec and is deliberately
   demoted, not forgotten — the section that consumed it is deferred to a task that
   runs a release first (see the Non-goals and DP-7). Nothing in the deliverable
   depends on any of it any more, so protecting it here would be protecting an
   input no sentence reads.
5. Any host's credential state, execution environment, or installed tooling, and
   the contents of GitHub's own branch-protection or API responses. None of it is
   readable from a clone, so no claim in this document may depend on it — which is
   the same boundary AC16 and AC20 enforce from the other side.
6. Adopter repositories in the legacy `tasks/` + `docs/specs/` layout. The
   document resolves a board path through `bin/team-paths.sh` where the path is
   load-bearing (the linting bullet in AC12), but every worked example is written
   for the default layout this repository actually runs on. Explaining the legacy
   layout to an adopter is `docs/adopting.md`'s job, not this file's.
7. A base branch whose About-CI paragraph has itself changed shape. AC2 asserts a
   four-line anchor result and therefore fails loudly in that case rather than
   adapting to whatever it finds; adapting would silently widen the set of
   deletions it licenses, which is the one thing that criterion exists to bound.

<!-- END intent-block: T-1000 -->

## Resolved design decisions

### DP-1 — `CLAUDE.md` is reduced to one pointer bullet

Ratified by the coordinator, and it is also the issue's own instruction ("one
pointer line from `CLAUDE.md` rather than a second copy"). `CLAUDE.md` states the
principle against itself two sections earlier: "A second copy drifts from the
[source] that actually configures [the thing], and the copy is the one people
read." The three bullets currently at `CLAUDE.md:83-87` are exactly such a copy —
and one of them (force-push and deletion settings) asserts a configuration this
tree cannot prove, so keeping it is worse than dropping it.

`CLAUDE.md` is a trusted instruction channel in this repository, so its diff draws
reviewer attention by design. AC17 keeps the change minimal and obviously
intentional: one bullet in, the old claims out, no heading line anywhere in the
file added or removed.

### DP-2 — canonical lines live only in the AC `check:` patterns

Earlier specs in this repository carried a separate "Canonical lines" section
*and* the same bytes inside each `check:` pattern. That is two copies of a
byte-exact string in one file, and the failure mode is a silent one-character
divergence that costs a rework round. Here the `grep -qxF` pattern in each AC is
the only copy, and the Notes for engineer say so explicitly.

Cost, accepted: the engineer reads the exact text out of the AC lines rather than
out of a prose block.

**One deliberate exception, added with AC17's correspondence check.** The
`CLAUDE.md` pointer bullet is *not* a canonical line: no criterion pins its bytes,
so its wording is given in the engineer notes instead. That is the point of the
strengthening — a byte-exact pin would freeze the sentence while saying nothing
about whether it points anywhere real, and pinning both the bytes and the
correspondence would make the bullet unrewordable for no gain. What is frozen is
the *property*: every destination it names exists. The three heading tokens do
appear inside AC17's check, but as values read out of the file at run time, not as
a transcribed copy — there is still exactly one place the text lives.

### DP-3 — the worked board example uses the id `T-1042`

`CONTRIBUTING.md` needs one concrete Active line, because a template line
(`**T-XXX**`) does not satisfy the linter's `T-[0-9]+` and so cannot be used as
AC13's positive control. Two candidates were rejected:

- **This task's own id, `T-1000`.** The example would then be a copy of a real
  board line whose flag advances every phase — a guaranteed staleness surface in a
  document about conventions.
- **A fixture-range id below `T-1000`.** `CLAUDE.md` reserves that range for
  `tests/` fixtures, but it also states that live ids start at `T-1000`; an
  example numbered below that would model the wrong convention to the very reader
  the document exists for.

`T-1042` is in the live range, is not any real task, and is mechanically
extractable. The residual risk — a future real `T-1042` colliding with a
documentation example — costs nothing, because no checker keys off it.

### DP-4 — the negative content greps are scoped to `CONTRIBUTING.md`

A repository-wide grep for `sandbox` / `MCP` / `PAT` would fail on this spec, on
the review record, and on `docs/distribution.md`, all of which legitimately
discuss those classes. The checks therefore target the one file this task
authors. `bin/check-pii-shapes.sh --base develop` provides the change-wide half.

The canonical scope bullet (AC15) was additionally worded to avoid the forbidden
tokens themselves — it says "per-host execution environment quirks", not the
literal word the check forbids — so the document cannot fail its own gate by
naming what it excludes.

### DP-5 — the one remaining ratified decision, and why the other one left

**Branch naming** is measured (9 of 9 merged pull requests use `<type>/<slug>`,
split `docs` 5 / `chore` 3 / `feature` 1 / `fix` **0**; zero use
`feat/T-XXX-<slug>`), so the *form* is grounded. Ratification only settles that
this is the written convention and that `docs/workflow.md`'s contradicting line is
wrong rather than authoritative. The `fix` count is the reason AC3's bullet
reports the observed types as observed and leaves the set open instead of claiming
four types are "in use" — a claim that was false for one of the four. The `main`
clause in the same bullet is normative for the same reason in reverse: the history
disproves the factual form once.

**The release procedure was the second ratified decision, and it is gone.** The
disclosure bullet this section used to require — "a maintainer decision, not an
observed practice" — was an honest label on the real problem rather than a
solution to it. Labelling an unexecuted procedure as unobserved does not make it
complete, and completeness is what a procedure is for. DP-7 records why the
deferral is the right answer and carries the measurements forward.

### DP-7 — deferring the release procedure, and the measurements it inherits

The decision, ratified with the human: remove `## Cutting a release` from this
task rather than review it a fifth time.

**The argument.** Two defect classes appeared in this task. The first — a claim
written without checking it against the tree — is closed: an inventory that opened
the mechanism files, run independently twice, found no remaining instance. The
second — a step missing from a procedure — is not closed, and the criteria in this
spec structurally cannot close it. All twenty-four verify that a sentence which is
present is true. An omission has no text to match, so no `grep` can find it and no
acceptance criterion of this kind can be written for one. The only instrument that
detects a missing step is executing the procedure, and `develop..main` is empty:
this repository has never executed this one. Three omissions surfaced across four
rounds, one per round, each found by a human or a reviewer reasoning about what
ought to be there. That rate is not evidence of carelessness; it is what sampling
an unverifiable surface looks like. Cutting v1.1.0 is on the backlog, so the
instrument is about to exist for free.

**What is deliberately *not* claimed:** that the deleted prose was wrong. Most of
it was measured and correct. It was incomplete in a way nothing here could prove
either way, which is a different and worse property for a runbook.

**Measurements carried forward**, so the follow-up task does not re-derive them:

- `develop..main` is empty; `main`'s first-parent history is the initial
  public-release commit plus one merge. No promotion has ever happened.
- The single tag `v1.0.0` is annotated (`git for-each-ref` objecttype `tag`) and
  points at that initial commit, which is reachable from both branches — so it
  evidences the annotated *form* and nothing about tagging after a merge.
- Merge style is measured: **9 of 9** merges reachable from either branch
  (`git log --merges main develop`) are merge commits, never squashes. An earlier
  figure of 10 double-counted the single merge into `main`, which `develop` also
  reaches.
- The version lives only in `.claude-plugin/plugin.json`; `.claude-plugin/marketplace.json`
  has no version field at any level.
- `bin/check-readme-version.sh` is argument-driven (`for FILE in "$@"`), so the
  enforced set is decided by CI's invocation line, `README.md README.ja.md`, not by
  the script. Its own scope note: "this check looks ONLY at the badge".
- Across `bin/` and `.github/`: zero references to `marketplace.json`, zero to
  `CHANGELOG`, and no step that validates a tag — the only tag-touching code reads
  a tag (`bin/install` reports the tag at `HEAD`, `bin/gen-project-status.sh` reads
  the newest tag for a generated block), and neither runs in CI.
- `CHANGELOG.md` declares its own place in the process: "new release entries land
  here as part of this project" release process. Both language files exist.

## Claim-to-evidence table

One row per convention sentence that lands in `CONTRIBUTING.md`. A claim with no
evidence row does not get written; the one ratified row is marked as a decision
rather than a measurement, per DP-5. The eight `R` rows that grounded the deferred
release section were removed with it — their measurements are not lost, they are
carried forward in DP-7 for the task that writes that section after running one.

| # | Claim | Evidence in this tree | AC |
|---|---|---|---|
| P1 | Branch from `develop`, named `<type>/<slug>`; the observed types are reported as observed and the set is open; `main` is the release line and the instruction is not to branch from it | `docs/distribution.md`'s Version-line section — "`main` carries releases and `develop` is its integration branch"; `.github/workflows/check-handoff.yml:3-7`. Branch form measured 9/9 across merged pull requests, split `docs` 5 / `chore` 3 / `feature` 1 / `fix` **0** (the zero rules out "in use" for `fix`) — **ratified** as the written convention (DP-5). The `main` clause is **normative, not factual**: the tree disproves the factual form once, at the branch behind the first pull request, whose merge base is the commit that was `main`'s tip before the `develop` flow existed | AC3, AC5 |
| P2 | Open the pull request against `develop`; the check reports on the PR | `.github/workflows/check-handoff.yml:4-7` (`pull_request` *and* `push`, branches `[main, develop]`) | AC3 |
| P3 | Both gates green before merge — deferred to the existing statement | `CONTRIBUTING.md:23-34`; also `CLAUDE.md:40-42`, `docs/adopting.md:106-111` | AC3, AC25 |
| P4 | Board hygiene runs through `bin/close-out.sh` | `bin/close-out.sh:1-44` (the four steps), `:225-236` (fail-closed rewrite) | AC3, AC4 |
| P4b | The board edit is published as a second pull request: `bin/close-out.sh` writes the file and runs no git command, and `develop` is protected, so the edit is branched from `develop` at the merge commit, committed alone, and opened as its own pull request | `bin/close-out.sh` contains **no `git ` invocation anywhere** (measured by full-file grep; the only `gh ` occurrence is inside a `printf`), and it writes the board with `cat "$TMP_BOARD" > "$BOARD"`. The shape is read off history, not recollection: the commit that closed the previous three tasks has as its parent the merge commit of the feature pull request, touches `.shell-team/todo.md` alone, carries a `board: close out …` message, and landed as its own pull request from a `chore/…` branch. `develop` being protected is the external measurement already declared in S3 | AC3, AC4 |
| P5 | A `develop` merge does not auto-close; the script prints `gh issue close` and never calls `gh` | `bin/close-out.sh:244-245`; locked by `tests/close-out/run.sh:86-90` | AC3, AC4 |
| C1 | One workflow, one job; check name `check-handoff lint` | `.github/workflows/check-handoff.yml:10-12` | AC9, AC10 |
| C2 | A mergeability field is not evidence of a reported conclusion | **No in-tree evidence** — `mergeable_state` appears nowhere in the tree (full-text search, zero hits). Written as an operational observation with its consequence | AC9 (presence); reasoning info-only |
| C3 | No "run everything" entry point; the workflow file is the authoritative list | `.shell-team/test-recipe.md:34-36` | AC9, AC19 |
| C4 | Two CI steps apply to a documentation-only pull request, each stated at its **measured scope** rather than at its invocation shape: the shape check uses the base only to enumerate the paths a change touches and then reads each of those paths in full, and the identity check covers the non-merge commits from the merge base to the head | `bin/check-pii-shapes.sh`'s own header — "The scanned unit is the FULL committed content of each changed path" and "there is no base-blob comparison", with changed paths enumerated from `git diff --raw` and content read through `git cat-file`. `bin/check-commit-identity.sh`'s own header — `git rev-list --no-merges <merge-base>..HEAD` and "Merge commits are excluded wholesale". The one exception to the scan is named rather than elided: the same header declares `KNOWN_SHAPE_PATHS` (DP-8), "a short, per-file (never a directory or glob) list of paths that deliberately carry a shape as a fixture FOR ANOTHER GUARD's own suite", on which nothing is reported. CI wiring at `.github/workflows/check-handoff.yml:148-149`, `:157-158` (both pass `--base "origin/${GITHUB_BASE_REF:-develop}"`, which is what makes the invocation shape misleading if quoted as the scope) | AC9, AC16 |
| C5 | No CI step **lints** the board this repository runs on (the lint target is the shipped template) and no step **evaluates** a task spec against its acceptance criteria (the spec-layer checkers appear only as fixture suites). This is an absence of two specific actions, **not** an absence of those files from CI — the byte-level scan in C4 still reads them when a change touches them, and the two rows must be read together | `:31-32` (the lint target is `templates/todo-template.md`); `:64-65`, `:130-134` (fixture suites only); `:136-137` (`check-board-headings` likewise); the scan half is C4's evidence | AC9, AC11, AC27 |
| B1 | `## Active` is machine-linted against a fixed shape; both separators are U+2014 | `bin/check-handoff.sh:62` (`LINE_RE`), `:47-51` (section extraction), `:26-34` + `:101-106` (flag enum) | AC12, AC13 |
| B2 | Nothing may sit between the flag and the spec pointer | `bin/close-out.sh:8-11` ("NO parenthetical after the flag"); mechanically, `bin/check-handoff.sh:62` | AC12, AC13 |
| B3 | Notes go in indented sub-bullets; `## Done`'s `- [x]` lines are never inspected | `bin/check-handoff.sh:88-94` (blank / `_(` / indented / non-`- [ ]` all skipped) | AC12, AC13 |
| B4 | Lint locally with both board checkers, resolving the path through `bin/team-paths.sh`; the heading checker sees **id-level** change only — deletion, replacement, duplication — and not a rewrite that keeps the id | `bin/check-board-headings.sh`'s own header: it "diffs the whole-board (Active + Done) set of `T-NNN` heading ids" and fails on "deletion, replacement (id-level: same as deletion), or duplication", and the same header records why `check-handoff.sh` cannot do this ("never compares against a base ref"). The extraction takes one `T-[0-9]+` per line, which is what bounds it to ids. "Only" is separately measured: no other checker compares board headings against a base ref. `bin/team-paths.sh`'s `--get KEY` interface for the path | AC12, AC14 |
| B5 | The flag vocabulary is not restated; it lives in the shipped template | `templates/todo-template.md:7-10`, `:20-28`; `templates/prompt-blocks/registry.txt:35,37` (the canonical block and its registered consumers) | AC12, AC26 |
| S1 | Nothing machine- or operator-specific in a tracked file | `CLAUDE.md:123-128` (this repository's own Hygiene rule) | AC15, AC16 |
| S2 | Oversight preferences live in the gitignored `CLAUDE.local.md`; `docs/tuning-oversight.md` documents the mechanism | `docs/tuning-oversight.md:10-20`, `:34-49`; `.gitignore:23-27` | AC15 |
| S3 | Both branches are protected and the check must report success; the rule set is not readable from a clone | GitHub API reports `protected: true` for both branches (external measurement); the protection-detail endpoint is unreachable from this environment, so nothing more is asserted | AC15, AC20 |
| X1 | `CLAUDE.md` keeps one pointer bullet instead of a second copy, and every destination it names is a real heading in `CONTRIBUTING.md` | `CLAUDE.md:81-87` (the copy being replaced), `:24-26` (the no-second-copy principle it violates). The correspondence half is grounded in the deliverable itself rather than in a fixed list: AC17 reads the destinations out of the bullet and looks each up, so the evidence is whatever `CONTRIBUTING.md` actually contains at check time. Measured cause: after the release section was deferred, the bullet still named four destinations while only three headings existed | AC17 |
| X2 | The existing `## About CI on your pull request` opening paragraph is corrected: of the three things it named as CI-verified repository conventions, only the generated prompt blocks is right; for the other two the accurate claim is narrow — no step **lints** the board this repository runs on, and no step **evaluates** a spec against its acceptance criteria — while both are still scanned byte-for-byte when a change touches them | `.github/workflows/check-handoff.yml:31-32` (the lint target is `templates/todo-template.md`); `:106-107` (`check-prompt-sync` dogfood, the one correct item); `:64-65`, `:130-134` (spec-layer checkers appear as fixture suites only); and C4's evidence for the scan half, which is what makes "not in CI at all" the wrong correction | AC27, AC2 (which licenses the deletion) |

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| `CONTRIBUTING.md` carries the three content areas this repository has executed | AC1 (sections), AC3/AC9/AC12 (the sentences) |
| Every convention sentence is grounded in this tree or marked as a decision | the claim-to-evidence table above + AC4, AC10, AC11 |
| The release procedure is deferred to a task that runs one first, and no trace of the drafted section is left behind | AC1 (the heading and all eight of its bullets asserted absent) **and AC17** (the `CLAUDE.md` pointer must not name it, in the exact wording or any other); the reasoning is the Non-goals entry and DP-7 |
| Removing a section is not finished until everything that points at it has been followed | AC17 (each destination the pointer names is looked up in `CONTRIBUTING.md` at check time, so a dangling one fails) |
| A pointer is verified by correspondence with its target, not by pinning its bytes | AC17; a byte-exact pin catches the pointer changing, and what happened was the pointer standing still while the target was removed |
| The documented flow reaches a committed state — the board edit is published, not left uncommitted | AC3 (the publish bullet, byte-exact), AC4 (the no-git-command grounding, with a positive control on its own pattern), grounded in row P4b |
| `CLAUDE.md` gets one pointer bullet, not a second copy | AC17 |
| The new content attaches to the existing sections rather than overwriting them | AC2 (deletions confined to exactly one licensed paragraph, set-equality against the base blob) |
| The one inaccurate existing sentence is corrected in place, not left to contradict the new section | AC27; AC2 is what licenses its deletion |
| The correct half of the existing About-CI section survives | AC27 (the retained sentence is asserted present) |
| The corrected text does not claim an exhaustive list of what CI runs against this tree | AC27's body states the restraint; mechanically, the canonical lines it pins contain no enumeration |
| Each check is described at its measured scope, never at its invocation shape (`--base` is not diff scoping) | AC9 (the fourth bullet, byte-exact), grounded in row C4 |
| The board and the specs are still byte-scanned when a change touches them; only the lint and the acceptance-criteria evaluation are absent | AC27 (the second canonical line asserts the scan explicitly), AC9's fourth bullet, rows C4 and C5 read together |
| The commit-identity range is the non-merge commits from the merge base to the head | AC9 (the fourth bullet), grounded in row C4 |
| A superseded canonical line must not survive alongside its replacement | AC3, AC9, AC12 and AC27 each assert the absence of the text they replace, in addition to the presence of the new text; AC1 does the same for the eight lines of the removed section, which have no replacement at all |
| A sentence must not be wider than the mechanism it describes — state the boundary instead of implying there is none | AC12 (the heading checker sees id-level change only), AC9 (the shape scan has a named per-file exception), each grounded in the checker header quoted in rows B4 and C4 |
| A rule the contributor must follow is written as a rule, never as a claim about the history that the history disproves | AC3 (`main` is not to be branched from), grounded in row P1 |
| A criterion whose subject has left the deliverable is retired rather than kept passing on tree facts nothing reads | the Retired criteria note (AC6, AC7, AC8, AC28); AC7 is the worked example — it would still have gone green with the document silent |
| `fix` is not claimed to be in use; the type set is open while the `<type>/<slug>` form is normative | AC3 (the corrected bullet); measurement recorded in DP-5 and row P1 |
| No duplication of what `README.md` / `CLAUDE.md` / `docs/` already carry | AC25, and AC12's B5 + AC26 for the flag enum |
| No operator- or machine-specific content in a tracked file | AC16 |
| No personal oversight preferences; point at `docs/tuning-oversight.md` | AC15 |
| No branch-protection specifics the tree cannot prove | AC20 |
| Do not enumerate CI's suite list | AC19 |
| Generated prompt blocks and agent definitions stay byte-unchanged | AC18 |
| No behaviour change; no new mechanical check | AC24 |
| Do not fix `docs/workflow.md`, and do not propagate its branch form | AC5 (no propagation), AC23 (untouched) |
| Do not fix the stale CI step name in the generated playbook block | AC23 |
| No `CONTRIBUTING.ja.md` | AC23 |
| The board entry is inserted in the enforced format with no parenthetical after the flag | AC14 |
| Diff stays inside the allow-list | AC22 |
| Provenance file required | AC21 |
| Branch naming is `<type>/<slug>` | AC3 (the bullet), AC5 (the negative) |
| Canonical lines live only in the AC patterns (DP-2) | info-only (not promoted to AC) — a spec-authoring convention about this file, not a property of the deliverable; its effect is that AC3/AC9/AC12/AC15/AC27 are the sole definition of the text |
| The worked example uses `T-1042` (DP-3) | info-only (not promoted to AC) — AC13 depends on the id only as an extraction anchor, and pinning the number as its own criterion would freeze an illustration choice with no reader-visible consequence |
| The negative greps are scoped to `CONTRIBUTING.md` (DP-4) | info-only (not promoted to AC) — a decision about how the checks are written, already visible in every check pattern; the change-wide half is AC16's shape-checker run |
| `mergeable_state` is not sufficient evidence because it reports mergeability | info-only (not promoted to AC) — an operational observation with no in-tree referent (zero hits repository-wide); AC9 pins the sentence, and inventing a grep to "prove" the reasoning would be a hollow check |
| Prose ordering of the four new sections | info-only (not promoted to AC) — a readability choice; no consumer depends on it |
| `CLAUDE.md` is a trusted instruction channel, so keep its diff obviously intentional | info-only (not promoted to AC) — a reviewer-attention argument; the mechanical half of it is AC17's one-bullet and no-heading-churn assertions |
| The pointer names its destinations exactly once, as heading tokens, and not again in prose | info-only (not promoted to AC) — a drift-surface argument about how the bullet is written; its observable consequence is that AC17 finds exactly three tokens, which the count assertion pins |
| The publish bullet sits directly after the board-hygiene bullet | info-only (not promoted to AC) — a logical-ordering choice inside one section, same class as the prose-ordering row above; AC3 pins the text, not its position |
| The merge-style measurement is 9, not 10 (the earlier figure double-counted the single merge into `main`) | info-only (not promoted to AC) — a correction to this spec's own evidence record, outside the frozen block; it changes no AC and no canonical line, and it now lives in DP-7 with the rest of the release measurements rather than being dropped with the section |
| The deferred release prose was mostly *correct*, and is removed for incompleteness rather than error | info-only (not promoted to AC) — a statement about work that is leaving the deliverable, so there is nothing left in the tree for a criterion to hold; recorded in DP-7 so the follow-up task does not start by re-litigating text that was already measured |

## Assumptions

- `develop` is fetched and resolvable locally. Every `check:` compares against it.
  No criterion reads a tag any more — the one that did (AC8) left with the release
  section — so the checkout no longer has to have tags fetched for this spec to be
  verifiable. That matters because `actions/checkout` does not fetch tags by
  default; it is moot here either way, since no `check:` in this spec runs in CI
  (`bin/check-acs.sh` is not wired into the workflow, which AC11 asserts).
- The `## Active` section of the resolved board currently holds only the
  `_(none)_` placeholder, so inserting this task's entry replaces that
  placeholder and touches no existing entry. Verified by reading the board;
  AC14's `bin/check-board-headings.sh` run re-checks it mechanically.
- `.shell-team/reviews/T-1000-codex-*.{txt,json,jsonl}` raw traces are gitignored
  (`.gitignore:15-17`), so AC22's allow-list needs only the curated
  `.shell-team/reviews/T-1000.md`. Verified by reading `.gitignore`.
- `grep -w` and `grep -m1` are available on both GNU and BSD/macOS grep, and
  `grep -qxF` treats the pattern as a whole-line fixed string on both. This
  matters because AC3/AC9/AC12/AC15/AC27 are whole-line exact matches; the
  repository's existing specs already rely on `grep -qxF --` in the same way.
- Every canonical line is free of the ASCII apostrophe, deliberately: the
  patterns are single-quoted inside a `bash -c` string, and an apostrophe would
  need escaping that is easy to get wrong. This constrains wording (no "the
  repository's own board") and is why some bullets read slightly formally. It is
  also why AC2 derives its expected deletion set from the base blob instead of
  transcribing it: the paragraph being replaced contains `repository's`, which no
  single-quoted pattern in this spec could hold.
- `git show develop:CONTRIBUTING.md` is resolvable and its opening About-CI
  paragraph is exactly four physical lines, anchored by the sentence that starts
  `Some checks in this repository test the shipped scripts` and the one that ends
  `your change.`. Verified by reading the base file; AC2 asserts the count of four
  as its own positive control, so a change to that paragraph on `develop` fails the
  criterion loudly rather than silently widening what may be deleted.
- pm-spec has no shell, so none of the `check:` lines above has been executed.
  The executing side runs them all — and corrects anything broken or vacuous with
  the semantics unchanged — *before* the intent-hash is computed and recorded.

## Open questions

None blocking. The one decision that had no in-tree precedent — the branch-name
form — was ratified by the coordinator and is recorded as ratified in DP-5 and in
row P1. The other former candidate, the release procedure, is no longer a question
this spec answers: it is deferred whole (Non-goals, DP-7), which resolves it rather
than leaving it open.

## Notes for engineer

- **This round removes a section.** `## Cutting a release` — its heading and all
  eight of its bullets — comes out of `CONTRIBUTING.md` whole. Do not relocate any
  of it, do not fold a bullet into another section, and do not leave a pointer
  saying it is coming. AC1 asserts the absence of the heading and of every bullet
  the section ever carried, in both wordings of the manifest bullet, because the
  characteristic failure of a section removal is a leftover line rather than a
  wrong one. The reasoning belongs in the spec (Non-goals, DP-7), not in the
  deliverable — a contributor does not need to read about a section that is not
  there.
- **The canonical text is the `grep -qxF` pattern in each AC** (DP-2). Copy each
  line out of AC3, AC9, AC12, AC15 and AC27 verbatim, including the U+2014 EM DASH
  characters and the backticks, and write each as one physical, unwrapped line.
  There is no second copy in this spec to consult.
- **Where the new sections go in `CONTRIBUTING.md`**: after `## About CI on your
  pull request` and before `## Where the behavior is documented`, in the order
  `## The pull-request flow`, `## Confirming the CI check is green`,
  `## The board line format`, `## What does not belong in this file`.
- **The publish bullet goes directly after the board-hygiene bullet** in
  `## The pull-request flow`, so the two steps read as one sequence: run the
  script, then publish what it wrote. Its position is not pinned mechanically.
- **The one existing paragraph you may touch** is the opening paragraph of
  `## About CI on your pull request` — currently four physical lines, from
  `Some checks in this repository test the shipped scripts` through
  `…nothing to do with your change.`. Delete all four and put AC27's two canonical
  lines in their place, each one physical unwrapped line. **Leave the paragraph
  that follows alone** (`If a check fails in a way that looks unrelated…`): it is
  correct, AC27 asserts it is still there, and AC2 fails if it is touched.
  Everywhere else in the file, insert only — AC2 compares the set of deleted lines
  against that one paragraph and fails on any other deletion, including a reflow,
  a re-wrap or a re-punctuation of an existing paragraph.
- **Lines already on this branch are superseded and must be *replaced*, not
  joined.** Swap each for the new pattern in its criterion; every affected criterion
  asserts the absence of the text it replaces as well as the presence of the new
  text, so leaving an old line in place fails even though the new one is there. The
  set, and why each moved:
  - AC27's second canonical line and AC9's fourth bullet — each described a check by
    the flag it takes rather than by what it reads, and the two pointed the same
    way, so a contributor reading both would have concluded that only added lines
    are scanned.
  - AC9's fourth bullet again — "is reported" was unconditional while the checker
    ships a short per-file known-shapes list on which nothing is reported.
  - AC3's naming bullet — the `main` clause was a claim about the history, and the
    history disproves it once.
  - AC12's linting bullet — "catches an edit that silently replaced the heading
    line" is true of the accident but wider than the mechanism, which compares ids.
  - The eight bullets of `## Cutting a release` — these have **no replacement**.
    They are deleted along with their heading, and AC1 is where their absence is
    asserted.
- **None of this affects AC2, including the section removal.** Every superseded
  line, and the whole `## Cutting a release` section, was added by this branch, so
  none of it exists in `develop:CONTRIBUTING.md`. Removing or replacing a line this
  branch introduced changes only the **added** side of `git diff develop`; the
  deleted side stays exactly the four-line About-CI paragraph of the base blob,
  which is the set AC2 licenses. Confirm this by running AC2 after the removal — if
  it fails, something in the pre-existing file was touched by accident, which is
  precisely what that criterion is for.
- **The worked board example** belongs in `## The board line format`, inside a
  fenced block tagged `markdown`, containing a `## Active` heading, the example
  entry, and one indented sub-bullet note. It must be one physical line and
  must start with `- [ ] **T-1042** ` — AC13 extracts it with
  `grep -m1 -F -- '- [ ] **T-1042**'` and feeds it to the real linter, so a
  wrapped or paraphrased example fails. Use a plausible title, the flag
  `READY_FOR_ARCH`, and a spec path ending in `.md`; nothing else about the line
  is pinned.
- **`CLAUDE.md`**: keep the `## Branches and pull requests` heading, delete the
  three bullets under it, and write exactly one bullet in their place naming
  `CONTRIBUTING.md`. It may wrap across physical lines (a continuation line starts
  with whitespace); it may not become two bullets. Do not touch any other section
  — AC17 fails if any heading line in the file is added or removed.
- **The `CLAUDE.md` pointer bullet is replaced this round.** The one currently on
  the branch names four destinations, one of which (the release procedure) no longer
  has a section — the section removal did not reach the file that points at it.
  Write this in its place, wrapped as shown; each backticked heading token must sit
  whole on one physical line, because AC17 extracts them with
  `grep -oE '`## [^`]+`'` and looks each one up in `CONTRIBUTING.md`:

  ```markdown
  - The `## The pull-request flow`, `## Confirming the CI check is green` and
    `## The board line format` sections of [`CONTRIBUTING.md`](CONTRIBUTING.md)
    document how work gets done here; this file does not restate them.
  ```

  The topics are named **once**, as those tokens, and not again in prose — a second
  naming would be a drift surface between the sentence and the list the checker
  reads. Do not mention releasing in this section in any form: AC17 asserts the
  absence of both the exact superseded phrase and the substring, so a reworded
  revival fails too.
- **Do not add a `tests/<name>/run.sh` path to `CONTRIBUTING.md`** (AC19 requires
  zero of them). Point at `.shell-team/test-recipe.md` for how to run one, as the
  canonical bullet already does.
- **Do not write the words the scope bullet excludes.** AC16 forbids `MCP`, `PAT`,
  `git@github`, `/Users/`, `/home/`, credential-token-scope phrasing and
  `excludedCommands` anywhere in `CONTRIBUTING.md`, and pins the existing single
  occurrence of the per-host-environment word at one — so do not add a second one.
  The canonical bullet in AC15 is already worded around all of them, which is why
  it reads "per-host execution environment quirks" rather than naming the thing.
- **Provenance file**: `.shell-team/provenance/T-1000.md`, same shape as the three
  existing files in that directory. The decisions worth recording are the ones you
  actually make while writing — at minimum, where in `CONTRIBUTING.md` the new
  sections attach and why, and the wording of the single `CLAUDE.md` pointer
  bullet. Ground each citation on a durable anchor (a heading, an AC number, a
  `check:` snippet), never a line number.
- **Files expected to change**: `CONTRIBUTING.md`, `CLAUDE.md`,
  `.shell-team/todo.md` (status flag and hand-off sub-bullet),
  `.shell-team/provenance/T-1000.md` (new). Nothing else — AC22 and AC24 both
  fail on anything outside that set.
- **Before hand-off**, run `bash bin/check-acs.sh --dry-run` then
  `bash bin/check-acs.sh` on this spec, and mutation-check AC13, AC17, AC2 and
  **every absence assertion**: break the documented example line, break the pointer
  bullet, delete one extra line somewhere else in `CONTRIBUTING.md`, paste each
  superseded line (AC3, AC9 twice, AC12, AC27) back in *alongside* its replacement,
  and paste back **each of the nine things AC1 says are gone** — the
  `## Cutting a release` heading and its eight bullets — one at a time. Every one
  must turn its check red, and restoring must turn it green again. One at a time is
  the point: a single mutation that trips two criteria at once proves neither of
  them individually, and AC1 now carries nine independent assertions that have never
  been exercised.
- **Mutation-check AC17's correspondence half specifically**, because it is new and
  its failure mode is silence. In a scratch copy: (a) add a fourth backticked
  `## …` token to the bullet naming a section that does not exist — it must go red
  on the count *and* on the lookup, so try it once with the count relaxed to see the
  lookup fire on its own; (b) rename one heading in `CONTRIBUTING.md` while leaving
  the bullet alone — this is the exact defect that got through, and it must now go
  red; (c) mangle the backticks so extraction finds nothing — it must go red on the
  count rather than pass an empty loop.
- **AC4's no-git assertion has a positive control on its own pattern** — the same
  regex must match `bin/check-pii-shapes.sh`, which does invoke git in command
  position. If you change that regex for any reason, re-check both halves: an
  absence proved by a pattern that matches nothing is not a proof.
