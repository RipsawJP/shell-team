# Contributing

Thanks for looking. This is a single-maintainer project, and the contribution
policy below is deliberately narrow — narrow enough to be honest about what will
and will not get merged, rather than inviting work that then sits.

## Welcome without asking first

- **Bug reports.** Especially anything that reproduces on a clean install.
- **Small pull requests**: typos, documentation wording, a broken link, a
  one-line bug fix. Open the PR directly.

## Open an issue first

**Anything that adds or changes behavior** — a new agent, a new skill, a change
to a phase boundary, a change to how a loop decides it is done. Open an issue
and let's agree on the shape before you write the code.

A feature PR that arrives without that conversation is likely to be declined
even when the code is good, because the shape of the loop *is* the thing being
designed here. That is about sequencing, not about the quality of the work.

## How changes get merged

Every change — including the maintainer's own — goes through the loop this
plugin implements: specified with acceptance criteria, implemented, verified
against those criteria, then reviewed by a model from a different provider.

**Merging always requires the maintainer's explicit go-ahead. There is no
auto-merge here**, and that is a deliberate design property rather than a
missing feature.

In practice a contribution from outside is often re-shaped on its way in. That
is the loop doing its job, not a verdict on the contribution.

## About CI on your pull request

Some checks in this repository test the shipped scripts — shellcheck, and the fixture suites under `tests/`. Others run a shipped script against this repository itself or against a shipped template, and those can fail for reasons that have nothing to do with your change.

Two CI steps a reader might expect do not exist: nothing lints the board this repository runs on — the lint target is the shipped template, `templates/todo-template.md` — and nothing evaluates a task spec against its acceptance criteria, since the spec-layer checkers appear in CI only as fixture suites. The board and the specs are still read in full by the PII shape check whenever a change touches them, and the generated prompt blocks are genuinely verified: `bin/check-prompt-sync.sh` runs against this tree on every pull request.

If a check fails in a way that looks unrelated to what you touched, **say so in
the pull request rather than trying to satisfy it.** Sorting that out is the
maintainer's side of the work, not yours.

## The pull-request flow

The mechanics around opening, merging, and closing out a pull request:

- **Branch from `develop`**, named `<type>/<slug>` — the branch names in this repository so far use the types `docs`, `chore` and `feature`, and the set is open. `main` is the release line: do not branch from it.
- **Open the pull request against `develop`.** The workflow runs on pull requests targeting `main` and `develop`, so the check reports on the pull request itself.
- **Both gates must be green before the merge** — QA and the cross-provider review, as stated under "How changes get merged" above. This section adds the mechanics around that gate and does not restate it.
- **The task records are complete before the board entry moves.** The interventions record exists alongside the provenance and review records — the zero-entry sentinel when nothing interrupted the task — and a missing one is a gap to fix at close-out rather than later. `bin/close-out.sh` enforces this mechanically: a missing or non-conformant interventions record refuses the close-out before any board write.
- **Branch for the board edit before the close-out step runs.** After the merge, branch from `develop` at the merge commit: the close-out step rewrites the board file in place and runs no git command, and `develop` is protected, so the board edit needs a branch of its own to land on.
- **Run board hygiene on that branch, then publish it.** `bash bin/close-out.sh --task T-NNNN --issue N --pr N` moves the board entry to `## Done`, rewrites its status flag, and prints what to do next; commit that one file with a message of the form `board: close out T-NNNN — merged via PR #N`, and open the branch as a second pull request.
- **Close the GitHub issue by hand.** A merge into `develop` does not auto-close an issue, so `bin/close-out.sh` prints the `gh issue close` command for a human to run — it never calls `gh` itself.

## Confirming the CI check is green

How to read the one required check, rather than a mergeability field that
looks similar but answers a different question:

- **There is one workflow and one job.** `.github/workflows/check-handoff.yml` — its job display name, and the check name to look for on a pull request, is `check-handoff lint`.
- **Confirm the reported conclusion of that check on the pull-request head commit.** A mergeability field such as `mergeable_state: clean` is not evidence: it describes whether the branches can be combined, and it can read clean before any check has reported a conclusion at all.
- **Run the suites locally before pushing.** There is no single "run everything" entry point; the workflow file is the authoritative list of every suite and dogfood step, in the order it runs them, and `.shell-team/test-recipe.md` records how to run one.
- **Two CI steps apply even to a documentation-only pull request.** `bin/check-pii-shapes.sh` uses the base branch only to enumerate the paths a change touches and then scans the full committed content of each of them, not the added lines alone — so a shape a file already carried surfaces on a change that touched a different part of that file, unless that path is on the short, test-locked known-shapes list inside the checker. `bin/check-commit-identity.sh` inspects the non-merge commits from the merge base to the head, and never a merge commit.
- **What CI does not do.** It lints the shipped board template, not the board in this repository, and although the spec-layer checkers (`bin/check-acs.sh`, `bin/check-intent.sh`, `bin/check-provenance.sh`) have fixture suites in CI, no step runs them against the specs here. Run those yourself.

## The board line format

The task board's `## Active` section follows a strict, machine-checked shape.

- **The `## Active` section is machine-linted.** `bin/check-handoff.sh` validates every top-level `- [ ]` line in it against a fixed shape and rejects an unrecognised status flag; both separators in that shape are a space-padded U+2014 EM DASH.
- **Nothing may come between the status flag and the spec pointer.** A parenthetical — a date, a review round, a pull-request number — placed after the flag breaks the match; the closing backtick of the flag must be followed directly by the spec pointer.
- **Notes go in indented sub-bullets under the entry.** The linter skips indented lines, the `_(none)_` placeholder, and any top-level line that is not `- [ ]`, which is why the `- [x]` entries under `## Done` are never inspected.

A worked example — the entry itself, one indented sub-bullet note under it,
and nothing else added to either supporting section:

```markdown
## Active

- [ ] **T-1042** Add a caching layer to the spec-lookup helper — `READY_FOR_ARCH` — spec: .shell-team/specs/T-1042-spec-lookup-cache.md
  - note: a supporting detail from whichever agent last touched this entry.
```

- **Lint the board before pushing**: `bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)"`, and `bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop`, which compares the set of `T-NNN` heading ids against the base ref — it is the only check that notices an id deleted, overwritten with a different id, or duplicated, and it cannot see a rewrite that leaves the id in place.
- **The status-flag vocabulary is not restated here**: it is listed in `templates/todo-template.md` and enforced by `bin/check-handoff.sh`.

## Re-freezing a frozen intent block

A frozen intent block's default re-freeze procedure is a per-instance human GO, whatever changed — that stays true here regardless of anything below; see `docs/tuning-oversight.md`'s "Who may re-freeze a frozen intent block" section for the policy, the knob, and what an operator's standing grant does and does not authorize. This section documents this repository's own **mechanics**: the two board-record shapes a re-freeze under either class adds, and the checker that decides which class a delta belongs to.

- **The checker.** `bin/check-refreeze-class.sh` classifies a delta between two intent-block versions as `mechanics` (a delta confined to `- check:` lines), `class-b` (anything else — Goal sentence, Non-goals, a criterion's prose, or Input space), or a structural/usage error. Only `mechanics` can ever take the class-M path below; every other result routes to the ordinary per-instance human-GO procedure. It always takes **both** positional arguments — `check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] <old-spec.md> <new-spec.md>` — in every mode; a flags-only invocation is a `usage` error, not a verification. Its `mechanics` line prints `differing=<n>`, and that count is what fills the `lines=<n>` field of the record below — read off the tool, never counted by hand.
- **A class-M re-freeze's ratification record** reuses the existing `- intent-ratified` line, with the class recorded in its GO field: `- intent-ratified (YYYY-MM-DD): vK→vK+1 — class=mechanics; standing grant: <where the grant is recorded> — <reason>`.
- **Its companion record**, carrying the bulk of what makes it auditable: `- refreeze-class (vK→vK+1): mechanics — trigger=<broken-as-command|vacuous|contradictory> — old-hash=<40-hex> — lines=<n> — old[1]: <the superseded line> — new[1]: <the replacement line> — evidence: <the live run that showed the defect>`, carrying **exactly `<n>`** `old[i]:`/`new[i]:` pairs, numbered from 1 in the order the lines appear in the block — a repair that replaces three `- check:` lines writes `lines=3` and three pairs, never one pair standing in for all three. The trigger is one of exactly four closed tokens: `broken-as-command`, `vacuous`, or `contradictory` for the re-freeze itself, and `review-rejected` for the revert form below.
- **A reverted class-M re-freeze** (the cross-provider reviewer's mandatory item rejected it) restores the superseded block byte-for-byte as a new ratified version and records both: `- intent-ratified (YYYY-MM-DD): vK+1→vK+2 — reverting a class-M re-freeze the cross-provider review rejected; restores the vK block and exercises no new authority — <reason>` plus `- refreeze-class (vK+1→vK+2): reverted — trigger=review-rejected — new-hash=<40-hex> — lines=<n> — old[1]: <line> — new[1]: <line> — evidence: <the review record> — grant-status=suspended-pending-human-review`, in the same `lines=<n>` plus numbered-pair shape.
- **Neither record shape is parsed by `bin/check-intent.sh`** — they are inert, indented sub-bullets alongside the existing `- intent-hash` / `- intent-ratified` / `- freeze-attestation` lines it does parse, so a class-M re-freeze changes no board grammar.
- **Where the recorded hash value comes from (T-1041).** Whoever records or re-records an intent-hash, under either class, obtains it from `check-intent.sh --print-hash <spec.md>` — the single pipeline that normalizes and hashes the marker region — and never from a hand re-implementation of that normalization; the value it prints is byte-identical to the value `check-intent.sh <spec.md> <board.md>` itself verifies.

## Cutting a release

The steps of a release, written from the release this repository has actually run.

- **Start from a quiet tree.** Every task meant for the release is merged and closed out, the board carries no entry under `## Active`, and the working tree is clean before anything is bumped.
- **A release does not run the loop, and gets no board entry.** Every change it publishes already went through the loop one at a time; what a release adds of its own is the mechanical output of this procedure — the bump, the badges and the changelog entries — which lands as an ordinary pull request under the same check and the same maintainer go-ahead as anything else, with no spec of its own for a board entry to point at, and the enforced Active line requires a spec pointer. What records a release is its changelog entry, its tag, and its published release page. Read this as the scoped exception to the rule under "How changes get merged" above: the procedure itself was specified, verified and reviewed once, as the task that wrote this section.
- **Measure the release before naming it.** `git log <previous-tag>..develop --oneline` is the content of the release, and the number follows semantic versioning applied to the surface this project declared stable at v1.0.0 — the plugin namespace and its command names.
- **The version lives in exactly one tracked file.** `.claude-plugin/plugin.json` carries it, `.claude-plugin/marketplace.json` carries no version at any level, and CI compares the static version badge in both READMEs against that manifest — so the manifest and the two badges move together or the check fails.
- **Prepare the release on its own branch off `develop`.** Bump the manifest version, move the version badge in both READMEs to match, and add the new entry to `CHANGELOG.md` and `CHANGELOG.ja.md` — newest entry first, describing behaviour a reader can observe, with no internal task or issue references, which is the style those files declare for themselves.
- **Verify the preparation locally before pushing, in two passes.** `bash bin/check-readme-version.sh README.md README.ja.md` is the badge check, with the argument list CI itself uses, and it reads the working tree — so it is the only one of the three that means anything before the change is committed. The two named under "Confirming the CI check is green" above both read committed content — one enumerates the changed paths and reads each of them out of the commit, the other reads the commits themselves — so both belong after the preparation is committed, and neither can see an uncommitted edit.
- **Land the preparation on `develop` through a pull request** and wait for the check to report a conclusion on it before merging, exactly as for any other change; a release has no board hygiene and no issue to close.
- **Promote `develop` to `main` from a throwaway `release/vX.Y.Z` branch cut from `develop`, and fetch `develop` before cutting it.** The preparation merged on the remote moments earlier, so the local branch is still behind until it is updated: confirm that the local `develop` and the remote one name the same commit, and cut the throwaway branch from that. A stale cut is the quiet failure of this step — the release tree would carry none of the bump, the badges or the changelog entries, and no check would notice, because the manifest and the badges stay consistent with each other. A pull request whose head branch is `develop` itself can leave `develop` deleted once the merge completes — that happened at v1.1.0 and had to be repaired by pushing the branch back from a local clone — and a throwaway head branch is what keeps the integration branch out of reach. The merge waits for the maintainer go-ahead and for the check to report its conclusion.
- **Tag the merge commit on `main` with an annotated tag named `vX.Y.Z`.** Fetch `main` first so that the merge commit exists locally, tag that commit rather than a local approximation of it, push the tag, and confirm the remote lists it.
- **Title the release with the tag name, verbatim** — `vX.Y.Z`, nothing prepended and nothing appended — never a summary suffix or a prefix the tag itself does not carry, whatever a release page's own draft field proposes by default.
- **Publish the release against that tag.** The notes are drafted before the promotion merges and approved by the maintainer with the same go-ahead, they are written in English as both earlier releases were, and the release is confirmed published rather than left as a draft.
- **Draft the release body from `docs/templates/release-notes-template.md`.** Copy the region between its two marker comments into the release body, fill it in per the instructions beside each section, and publish it as that region reads — this is the shipped answer to issue #223's ratified body properties, and it is forward-only: no earlier release's title or body is edited to match it.
- **Version numbers follow a value rule, not this list.** See `## What a version number encodes` for what a version number means and how MAJOR, MINOR and PATCH are chosen; the steps above cover only the mechanics of publishing once a number is decided.

## What a version number encodes

A version number is a claim made to whoever receives this project, not a record of how the work was done. This section states what earns each tier.

- **What the number encodes.** A version number encodes how much more useful this project became for the person who receives it, never how much work it took to build: diff size, invasiveness and volume of change carry no meaning of their own, and a large, invasive change that leaves the user's felt experience unchanged is not progress — it is wasted cost.
- **MAJOR.** A break to the stable surface `## Cutting a release` defines — the plugin namespace and its command names — requiring an adopter to change their own setup or usage to keep working.
- **MINOR.** A new adopter-perceivable benefit, gated jointly on the headline test and the default-reachability test below — passing only one of the two is not sufficient, and both must hold before a change earns MINOR.
- **The headline test.** Could this change be named as the headline of the release notes — a benefit an adopter would actually recognize — rather than folded into an inventory of internal changes nobody outside the project would notice.
- **The default-reachability test.** Does the adopter feel this benefit by running the project's own default shipped path, or does it stay latent behind an explicit opt-in that most adopters never touch — a latent, opt-in-only capability does not pass this test no matter how valuable it could become.
- **PATCH.** Bug fixes, performance work, internal mechanisms, and capabilities that ship but stay latent behind an opt-in are PATCH regardless of diff size or how invasive the change was to make.
- **Releases decouple from merges.** A train may merge fully unversioned; the version number is assigned only when a value-bearing release actually ships, applying `## Cutting a release`'s own "Measure the release before naming it" step to that release rather than to any earlier merge.
- **Release notes trace to the request.** A release note names the adopter-facing request or need it answers, not merely a summary of what changed; a note that reads as an inventory of internal changes rather than a traced answer to a request signals the headline test was not actually met.
- **Internal work needs a named benefit.** Internal work — a mechanism, a refactor, a piece of infrastructure — is justifiable only as a traced precondition to a user-felt benefit that is named at planning time, not assumed to pay off on its own later.

## What does not belong in this file

This document describes conventions a contributor can re-derive from a
fresh clone. Three classes stay out of it on purpose:

- **Nothing specific to one machine or one operator.** No absolute paths into a home directory, no account-to-remote mapping, no credential or token configuration, no per-host execution environment quirks, no tooling only one maintainer has installed. A convention that cannot be re-derived from a fresh clone is not a convention of this repository.
- **No personal oversight preferences.** How often a session stops to ask is a working preference, kept in the gitignored `CLAUDE.local.md`; [`docs/tuning-oversight.md`](docs/tuning-oversight.md) documents that mechanism and this file does not restate it.
- **No branch-protection configuration.** Both `develop` and `main` are protected, and `check-handoff lint` must report success before a merge; the specific rule set lives in the GitHub settings for this repository and is not readable from a clone, so it is not asserted here.

## Where the behavior is documented

- [`README.md`](README.md) — what this is, prerequisites, install, and the
  shortest path to running it
- [`docs/workflow.md`](docs/workflow.md) — phase boundaries and the hand-off
  contract between roles
- [`docs/adopting.md`](docs/adopting.md) — adopting the plugin in your own
  repository
- [`docs/usage-conversational.md`](docs/usage-conversational.md) — driving the
  team conversationally instead of by explicit commands
- [`docs/distribution.md`](docs/distribution.md) — install, update, and the
  extra settings a sandboxed session needs

## On the absence of a code of conduct

There is no `CODE_OF_CONDUCT.md`, and that is a decision rather than an
oversight: with one maintainer it would be a document with no process behind it.
If this project grows past that, it gets one.
