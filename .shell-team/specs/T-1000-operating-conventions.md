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

`CONTRIBUTING.md` carries the four operating conventions a contributor needs and
cannot otherwise obtain from a clone — the pull-request flow, the release
procedure, how the CI check's green state is confirmed, and the board line
format with its note-placement rule — and every convention sentence in it is
either grounded in an artefact in this tree or is visibly marked in the document
itself as a maintainer decision rather than a measurement. `CLAUDE.md` gains a
single pointer bullet where it previously carried a second, drifting copy.
Nothing specific to one machine, one operator, or one person's oversight
preferences enters a tracked file, and no existing statement in `README.md`,
`CLAUDE.md` or `docs/` is duplicated — each is pointed at. No behaviour changes:
no script, test, workflow, agent or generated prompt block is touched.

## Non-goals

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

- [ ] **AC1** `CONTRIBUTING.md` carries all five new section headings, exactly as
  spelled, and the file is readable (positive control).
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && grep -qxF '## The pull-request flow' CONTRIBUTING.md && grep -qxF '## Confirming the CI check is green' CONTRIBUTING.md && grep -qxF '## The board line format' CONTRIBUTING.md && grep -qxF '## Cutting a release' CONTRIBUTING.md && grep -qxF '## What does not belong in this file' CONTRIBUTING.md
- [ ] **AC2** The new content is attached to `CONTRIBUTING.md`, not written over
  it: the diff against `develop` has zero deleted lines and a non-zero number of
  added lines. (Deletion counting uses `--numstat`'s own column rather than a
  `^-` diff-line pattern, which mis-reads a bullet-heavy markdown file.)
  - check: test "$(git diff --numstat develop -- CONTRIBUTING.md | awk '{print $2}')" = "0" && test "$(git diff --numstat develop -- CONTRIBUTING.md | awk '{print $1}')" -gt 0
- [ ] **AC3** The pull-request flow is stated as five canonical bullets: the base
  branch and branch-name form, the pull-request target, the deferral to the
  existing two-gate statement, the board-hygiene step, and the manual issue
  close.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && grep -qxF -- '- **Branch from `develop`**, named `<type>/<slug>` — the types in use are `docs`, `chore`, `feature` and `fix`. `main` is the release line and is never the base of a feature branch.' CONTRIBUTING.md && grep -qxF -- '- **Open the pull request against `develop`.** The workflow runs on pull requests targeting `main` and `develop`, so the check reports on the pull request itself.' CONTRIBUTING.md && grep -qxF -- '- **Both gates must be green before the merge** — QA and the cross-provider review, as stated under "How changes get merged" above. This section adds the mechanics around that gate and does not restate it.' CONTRIBUTING.md && grep -qxF -- '- **Merge, then run board hygiene.** `bash bin/close-out.sh --task T-NNNN --issue N --pr N` moves the board entry to `## Done`, rewrites its status flag, and prints what to do next.' CONTRIBUTING.md && grep -qxF -- '- **Close the GitHub issue by hand.** A merge into `develop` does not auto-close an issue, so `bin/close-out.sh` prints the `gh issue close` command for a human to run — it never calls `gh` itself.' CONTRIBUTING.md
- [ ] **AC4** The manual-close claim is grounded in the producer, not in
  recollection: `bin/close-out.sh` itself says a `develop` merge does not
  auto-close, and the suite that locks both halves of that behaviour (the printed
  procedure, and the script never invoking `gh`) still passes.
  - check: grep -qF 'develop merges do NOT auto-close' bin/close-out.sh && bash tests/close-out/run.sh
- [ ] **AC5** The contradicted branch form is not propagated: no `feat/T-` string
  appears anywhere in `CONTRIBUTING.md`.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && ! grep -qF 'feat/T-' CONTRIBUTING.md
- [ ] **AC6** The release procedure is stated as six canonical bullets: the single
  version location, the badge bump and what actually enforces it, the explicit
  list of what is *not* checked, the promotion-by-pull-request and merge style,
  the annotated tag, and the pointers to the install side and the changelog.
  - check: grep -qxF -- '- **The version lives in one place**: the `version` field of `.claude-plugin/plugin.json`. `.claude-plugin/marketplace.json` carries no version field.' CONTRIBUTING.md && grep -qxF -- '- **Bump the static version badge in both `README.md` and `README.ja.md` to match.** `bin/check-readme-version.sh` compares each badge against the manifest, but it checks only the files handed to it as arguments — the enforced set is decided by the invocation line in the workflow, not by the script.' CONTRIBUTING.md && grep -qxF -- '- **Nothing else is machine-checked.** `CHANGELOG.md` and `CHANGELOG.ja.md` parity, `marketplace.json`, git tags, and version numbers mentioned in prose have no check at all; the badge is the only enforced site.' CONTRIBUTING.md && grep -qxF -- '- **Promote `develop` to `main` through a pull request**, not a direct push, and merge it as a merge commit rather than a squash, once `check-handoff lint` has reported success.' CONTRIBUTING.md && grep -qxF -- '- **Tag the release on `main` with an annotated tag `vX.Y.Z`** after that merge lands.' CONTRIBUTING.md && grep -qxF -- '- **The install side is documented elsewhere**: [`docs/distribution.md`](docs/distribution.md) covers what an adopter does after a bump, and [`CHANGELOG.md`](CHANGELOG.md) carries the release history that [`README.md`](README.md) points at.' CONTRIBUTING.md
- [ ] **AC7** Every mechanical claim in the release section is true of this tree:
  the manifest carries a version field, `marketplace.json` does not, the checker
  declares badge-only scope, CI's invocation line is exactly the two READMEs, and
  running that invocation passes. Each negative grep is paired with a positive
  control on the same file so an unreadable file cannot pass as an absence.
  - check: grep -qF '"version": "' .claude-plugin/plugin.json && grep -qF '"plugins"' .claude-plugin/marketplace.json && ! grep -qF '"version"' .claude-plugin/marketplace.json && grep -qF 'this check looks ONLY at the badge' bin/check-readme-version.sh && grep -qF 'bash bin/check-readme-version.sh README.md README.ja.md' .github/workflows/check-handoff.yml && bash bin/check-readme-version.sh README.md README.ja.md
- [ ] **AC8** The document itself marks the promotion and tagging steps as a
  maintainer decision rather than an observed practice, so a later reader cannot
  mistake them for a measurement. The one tree-grounded part of them — that the
  established tag form is *annotated* — holds.
  - check: grep -qxF -- '- The promotion and the tag are a **maintainer decision, not an observed practice**: at the time of writing, `develop` had never been promoted to `main`, and the single existing tag sits on a commit reachable from both branches, so it does not by itself evidence tagging after a merge.' CONTRIBUTING.md && test "$(git for-each-ref --format='%(objecttype)' refs/tags/v1.0.0)" = 'tag'
- [ ] **AC9** The CI-green procedure is stated as five canonical bullets: the one
  workflow and its check name, the confirm-the-conclusion rule with the
  mergeability caution, local running, the two checks that apply to a
  documentation-only pull request, and what CI does not do.
  - check: grep -qxF -- '- **There is one workflow and one job.** `.github/workflows/check-handoff.yml` — its job display name, and the check name to look for on a pull request, is `check-handoff lint`.' CONTRIBUTING.md && grep -qxF -- '- **Confirm the reported conclusion of that check on the pull-request head commit.** A mergeability field such as `mergeable_state: clean` is not evidence: it describes whether the branches can be combined, and it can read clean before any check has reported a conclusion at all.' CONTRIBUTING.md && grep -qxF -- '- **Run the suites locally before pushing.** There is no single "run everything" entry point; the workflow file is the authoritative list of every suite and dogfood step, in the order it runs them, and `.shell-team/test-recipe.md` records how to run one.' CONTRIBUTING.md && grep -qxF -- '- **Two CI steps apply even to a documentation-only pull request**: `bin/check-pii-shapes.sh` on the diff against the base branch, and `bin/check-commit-identity.sh` on the commits.' CONTRIBUTING.md && grep -qxF -- '- **What CI does not do.** It lints the shipped board template, not the board in this repository, and although the spec-layer checkers (`bin/check-acs.sh`, `bin/check-intent.sh`, `bin/check-provenance.sh`) have fixture suites in CI, no step runs them against the specs here. Run those yourself.' CONTRIBUTING.md
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
  - check: grep -qxF -- '- **The `## Active` section is machine-linted.** `bin/check-handoff.sh` validates every top-level `- [ ]` line in it against a fixed shape and rejects an unrecognised status flag; both separators in that shape are a space-padded U+2014 EM DASH.' CONTRIBUTING.md && grep -qxF -- '- **Nothing may come between the status flag and the spec pointer.** A parenthetical — a date, a review round, a pull-request number — placed after the flag breaks the match; the closing backtick of the flag must be followed directly by the spec pointer.' CONTRIBUTING.md && grep -qxF -- '- **Notes go in indented sub-bullets under the entry.** The linter skips indented lines, the `_(none)_` placeholder, and any top-level line that is not `- [ ]`, which is why the `- [x]` entries under `## Done` are never inspected.' CONTRIBUTING.md && grep -qxF -- '- **Lint the board before pushing**: `bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)"`, and `bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop`, which is the only check that catches an edit that silently replaced the heading line of an existing entry.' CONTRIBUTING.md && grep -qxF -- '- **The status-flag vocabulary is not restated here**: it is listed in `templates/todo-template.md` and enforced by `bin/check-handoff.sh`.' CONTRIBUTING.md
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
  - check: grep -qxF '## Branches and pull requests' CLAUDE.md && s="$(awk '/^## Branches and pull requests$/{f=1;next} f&&/^## /{exit} f' CLAUDE.md)" && test "$(printf '%s\n' "$s" | grep -cE '^[^[:space:]]')" -eq 1 && printf '%s\n' "$s" | grep -qE '^- ' && printf '%s\n' "$s" | grep -qF 'CONTRIBUTING.md' && ! grep -qF 'reject force pushes' CLAUDE.md && test "$(git diff develop -- CLAUDE.md | grep -cE '^[+-]#')" -eq 0 && test "$(git diff --numstat develop -- CLAUDE.md | awk '{print $1}')" -gt 0
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
  procedure are pointed at rather than copied.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && test "$(grep -cF 'Merging always requires the maintainer' CONTRIBUTING.md)" -eq 1 && test "$(grep -cF 'goes through the loop this' CONTRIBUTING.md)" -eq 1 && ! grep -qF 'claude --plugin-dir' CONTRIBUTING.md && ! grep -qF 'one entry per release, newest first' CONTRIBUTING.md && ! grep -qF 'plugin marketplace update' CONTRIBUTING.md
- [ ] **AC26** Negative — the status-flag enum is not reproduced: only the single
  flag inside the worked example may appear, and none of the other six.
  - check: grep -qF 'Thanks for looking' CONTRIBUTING.md && ! grep -q -e 'READY_FOR_ENG' -e 'READY_FOR_QA' -e 'READY_FOR_REVIEW' -e 'READY_FOR_MERGE' -e 'BLOCKED' -e 'REWORK' CONTRIBUTING.md

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
6. A manifest version value of `X.Y.Z` with an optional semver pre-release suffix,
   and its shields.io-escaped counterpart in each README badge (a literal `-`
   written `--`).
7. A documentation-only pull request against `develop`, which still reaches the
   diff-scoped PII shape check and the commit-identity check.

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
4. Non-semver manifests, multiple `"version"` fields, alternative badge providers,
   and dynamic badges — `bin/check-readme-version.sh` already declares its own
   scope, and this document quotes that scope rather than extending it.
5. Any host's credential state, execution environment, or installed tooling, and
   the contents of GitHub's own branch-protection or API responses. None of it is
   readable from a clone, so no claim in this document may depend on it — which is
   the same boundary AC16 and AC20 enforce from the other side.
6. Adopter repositories in the legacy `tasks/` + `docs/specs/` layout. The
   document resolves a board path through `bin/team-paths.sh` where the path is
   load-bearing (the linting bullet in AC12), but every worked example is written
   for the default layout this repository actually runs on. Explaining the legacy
   layout to an adopter is `docs/adopting.md`'s job, not this file's.

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

### DP-5 — two conventions are ratified decisions, not measurements, and say so

The branch-name form and the release procedure are the two places where this
document is at risk of laundering a decision into a fact:

- **Branch naming** is measured (9 of 9 merged pull requests use
  `<type>/<slug>`: `docs/`, `chore/`, `feature/`; zero use `feat/T-XXX-<slug>`),
  so the *form* is grounded. Ratification only settles that this is the written
  convention and that `docs/workflow.md`'s contradicting line is wrong rather
  than authoritative.
- **The release procedure** is not measured at all. `develop..main` is empty —
  `develop` has never been promoted to `main` — and `main`'s first-parent history
  is the initial public-release commit plus one merge. The single tag `v1.0.0` is
  annotated and points at that initial commit, which is reachable from both
  branches, so it evidences the *annotated* tag form and nothing about tagging
  after a merge. Merge style *is* measured: 10 of 10 merges into either branch are
  merge commits, never squashes.

The consequence is a document-level obligation, not just a spec-level note: the
release section carries the disclosure bullet AC8 pins, so a reader six months
from now cannot mistake the extrapolation for an observation.

## Claim-to-evidence table

One row per convention sentence that lands in `CONTRIBUTING.md`. A claim with no
evidence row does not get written; the two ratified rows are marked as decisions
rather than measurements, per DP-5.

| # | Claim | Evidence in this tree | AC |
|---|---|---|---|
| P1 | Branch from `develop`, named `<type>/<slug>`; `main` is the release line | `docs/distribution.md:91-93` ("`main` carries releases and `develop` is its integration branch"); `.github/workflows/check-handoff.yml:3-7`. Branch form measured 9/9 across merged pull requests — **ratified** as the written convention (DP-5) | AC3, AC5 |
| P2 | Open the pull request against `develop`; the check reports on the PR | `.github/workflows/check-handoff.yml:4-7` (`pull_request` *and* `push`, branches `[main, develop]`) | AC3 |
| P3 | Both gates green before merge — deferred to the existing statement | `CONTRIBUTING.md:23-34`; also `CLAUDE.md:40-42`, `docs/adopting.md:106-111` | AC3, AC25 |
| P4 | Board hygiene runs through `bin/close-out.sh` | `bin/close-out.sh:1-44` (the four steps), `:225-236` (fail-closed rewrite) | AC3, AC4 |
| P5 | A `develop` merge does not auto-close; the script prints `gh issue close` and never calls `gh` | `bin/close-out.sh:244-245`; locked by `tests/close-out/run.sh:86-90` | AC3, AC4 |
| C1 | One workflow, one job; check name `check-handoff lint` | `.github/workflows/check-handoff.yml:10-12` | AC9, AC10 |
| C2 | A mergeability field is not evidence of a reported conclusion | **No in-tree evidence** — `mergeable_state` appears nowhere in the tree (full-text search, zero hits). Written as an operational observation with its consequence | AC9 (presence); reasoning info-only |
| C3 | No "run everything" entry point; the workflow file is the authoritative list | `.shell-team/test-recipe.md:34-36` | AC9, AC19 |
| C4 | Two CI steps apply to a documentation-only PR | `.github/workflows/check-handoff.yml:148-149`, `:157-158` (both `--base "origin/${GITHUB_BASE_REF:-develop}"`) | AC9, AC16 |
| C5 | CI lints the shipped template, not this board; the spec-layer checkers have suites but no run-against-this-repo step | `:31-32` (template is the target); `:64-65`, `:130-134` (fixture suites only); `:136-137` (`check-board-headings` likewise) | AC9, AC11 |
| B1 | `## Active` is machine-linted against a fixed shape; both separators are U+2014 | `bin/check-handoff.sh:62` (`LINE_RE`), `:47-51` (section extraction), `:26-34` + `:101-106` (flag enum) | AC12, AC13 |
| B2 | Nothing may sit between the flag and the spec pointer | `bin/close-out.sh:8-11` ("NO parenthetical after the flag"); mechanically, `bin/check-handoff.sh:62` | AC12, AC13 |
| B3 | Notes go in indented sub-bullets; `## Done`'s `- [x]` lines are never inspected | `bin/check-handoff.sh:88-94` (blank / `_(` / indented / non-`- [ ]` all skipped) | AC12, AC13 |
| B4 | Lint locally with both board checkers, resolving the path through `bin/team-paths.sh` | `bin/check-board-headings.sh:1-13` (the gap it closes and why `check-handoff.sh` cannot); `bin/team-paths.sh:32-36` (`--get` interface) | AC12, AC14 |
| B5 | The flag vocabulary is not restated; it lives in the shipped template | `templates/todo-template.md:7-10`, `:20-28`; `templates/prompt-blocks/registry.txt:35,37` (the canonical block and its registered consumers) | AC12, AC26 |
| R1 | The version lives only in `.claude-plugin/plugin.json`; `marketplace.json` has no version field | `.claude-plugin/plugin.json:4`; `.claude-plugin/marketplace.json` (read in full — no version field) | AC6, AC7 |
| R2 | Badge in both READMEs; the script is argument-driven and CI's invocation decides the enforced set | `bin/check-readme-version.sh:6-8`, `:31`, `:63-78`; `.github/workflows/check-handoff.yml:82-83` (`README.md README.ja.md`) | AC6, AC7 |
| R3 | Nothing else is machine-checked (CHANGELOG parity, `marketplace.json`, tags, prose mentions) | `bin/check-readme-version.sh:24-26` (declared badge-only scope); no CHANGELOG/tag step anywhere in the workflow | AC6, AC7 |
| R4 | Promote `develop` to `main` by pull request, merged as a merge commit, after the check reports success | **Ratified decision** (DP-5). Merge style is measured: 10/10 merges into either branch are merge commits, zero squashes | AC6, AC8 |
| R5 | Tag `main` with an annotated `vX.Y.Z` after the merge | **Ratified decision** (DP-5). Grounded only in part: the sole tag `v1.0.0` is annotated (objecttype `tag`); the after-the-merge timing is an extrapolation | AC6, AC8 |
| R6 | Install side, changelog and README are pointed at, not copied | `docs/distribution.md:81-93`; `README.md:187-189`; `CHANGELOG.md:1-5` | AC6, AC25 |
| R7 | The promotion and tag are a maintainer decision, not an observed practice | `develop..main` is empty; `main`'s first-parent history is the initial release commit plus one merge — measured, and the reason the disclosure is required | AC8 |
| S1 | Nothing machine- or operator-specific in a tracked file | `CLAUDE.md:123-128` (this repository's own Hygiene rule) | AC15, AC16 |
| S2 | Oversight preferences live in the gitignored `CLAUDE.local.md`; `docs/tuning-oversight.md` documents the mechanism | `docs/tuning-oversight.md:10-20`, `:34-49`; `.gitignore:23-27` | AC15 |
| S3 | Both branches are protected and the check must report success; the rule set is not readable from a clone | GitHub API reports `protected: true` for both branches (external measurement); the protection-detail endpoint is unreachable from this environment, so nothing more is asserted | AC15, AC20 |
| X1 | `CLAUDE.md` keeps one pointer bullet instead of a second copy | `CLAUDE.md:81-87` (the copy being replaced), `:24-26` (the no-second-copy principle it violates) | AC17 |

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| `CONTRIBUTING.md` carries the four content areas | AC1 (sections), AC3/AC6/AC9/AC12 (the sentences) |
| Every convention sentence is grounded in this tree or marked as a decision | the claim-to-evidence table above + AC4, AC7, AC8, AC10, AC11 |
| `CLAUDE.md` gets one pointer bullet, not a second copy | AC17 |
| The new content attaches to the existing sections rather than overwriting them | AC2 (zero deletions) |
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
| The release procedure and the tag are ratified, not observed — and the document says so | AC8 |
| Branch naming is `<type>/<slug>` | AC3 (the bullet), AC5 (the negative) |
| Canonical lines live only in the AC patterns (DP-2) | info-only (not promoted to AC) — a spec-authoring convention about this file, not a property of the deliverable; its effect is that AC3/AC6/AC9/AC12/AC15 are the sole definition of the text |
| The worked example uses `T-1042` (DP-3) | info-only (not promoted to AC) — AC13 depends on the id only as an extraction anchor, and pinning the number as its own criterion would freeze an illustration choice with no reader-visible consequence |
| The negative greps are scoped to `CONTRIBUTING.md` (DP-4) | info-only (not promoted to AC) — a decision about how the checks are written, already visible in every check pattern; the change-wide half is AC16's shape-checker run |
| `mergeable_state` is not sufficient evidence because it reports mergeability | info-only (not promoted to AC) — an operational observation with no in-tree referent (zero hits repository-wide); AC9 pins the sentence, and inventing a grep to "prove" the reasoning would be a hollow check |
| Prose ordering of the five new sections | info-only (not promoted to AC) — a readability choice; no consumer depends on it |
| `CLAUDE.md` is a trusted instruction channel, so keep its diff obviously intentional | info-only (not promoted to AC) — a reviewer-attention argument; the mechanical half of it is AC17's one-bullet and no-heading-churn assertions |

## Assumptions

- `develop` is fetched and resolvable locally, and the checkout has tags. Every
  `check:` compares against `develop`, and AC8 reads `refs/tags/v1.0.0`. Both hold
  in a normal `git clone`; `actions/checkout` does *not* fetch tags by default,
  but no `check:` in this spec runs in CI (`bin/check-acs.sh` is not wired into
  the workflow — AC11 asserts exactly that).
- The `## Active` section of the resolved board currently holds only the
  `_(none)_` placeholder, so inserting this task's entry replaces that
  placeholder and touches no existing entry. Verified by reading the board;
  AC14's `bin/check-board-headings.sh` run re-checks it mechanically.
- `.shell-team/reviews/T-1000-codex-*.{txt,json,jsonl}` raw traces are gitignored
  (`.gitignore:15-17`), so AC22's allow-list needs only the curated
  `.shell-team/reviews/T-1000.md`. Verified by reading `.gitignore`.
- `grep -w` and `grep -m1` are available on both GNU and BSD/macOS grep, and
  `grep -qxF` treats the pattern as a whole-line fixed string on both. This
  matters because AC3/AC6/AC9/AC12/AC15 are whole-line exact matches; the
  repository's existing specs already rely on `grep -qxF --` in the same way.
- Every canonical line is free of the ASCII apostrophe, deliberately: the
  patterns are single-quoted inside a `bash -c` string, and an apostrophe would
  need escaping that is easy to get wrong. This constrains wording (no "the
  repository's own board") and is why some bullets read slightly formally.
- pm-spec has no shell, so none of the `check:` lines above has been executed.
  The executing side runs them all — and corrects anything broken or vacuous with
  the semantics unchanged — *before* the intent-hash is computed and recorded.

## Open questions

None blocking. The two decisions that had no in-tree precedent (the release
procedure, the branch-name form) were ratified by the coordinator and are recorded
as ratified in DP-5 and in the claim-to-evidence table, with the release section
carrying that disclosure to the reader as well.

## Notes for engineer

- **The canonical text is the `grep -qxF` pattern in each AC** (DP-2). Copy each
  line out of AC3, AC6, AC8, AC9, AC12 and AC15 verbatim, including the U+2014 EM
  DASH characters and the backticks, and write each as one physical, unwrapped
  line. There is no second copy in this spec to consult.
- **Where the new sections go in `CONTRIBUTING.md`**: after `## About CI on your
  pull request` and before `## Where the behavior is documented`, in the order
  `## The pull-request flow`, `## Confirming the CI check is green`,
  `## The board line format`, `## Cutting a release`,
  `## What does not belong in this file`. Insert only — AC2 requires zero deleted
  lines, so do not reflow, re-wrap or re-punctuate any existing paragraph.
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
  `bash bin/check-acs.sh` on this spec, and mutation-check at least AC13 and AC17:
  break the documented example line (or the pointer bullet) in a scratch copy,
  confirm the check turns red, restore, confirm it turns green. AC13 is a new
  positive-and-negative control pair, which is exactly the class that ships blind.
