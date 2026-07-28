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
- **Merge, then run board hygiene.** `bash bin/close-out.sh --task T-NNNN --issue N --pr N` moves the board entry to `## Done`, rewrites its status flag, and prints what to do next.
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

## Cutting a release

The steps a release actually takes in this repository, and — since two of
them have no in-tree precedent yet — a disclosure about which parts are
measured and which are a standing decision:

- **Bump the `version` field of `.claude-plugin/plugin.json`.** That manifest is the single source of the version — `.claude-plugin/marketplace.json` carries no version field, so there is nothing to change there.
- **Bump the static version badge in both `README.md` and `README.ja.md` to match.** `bin/check-readme-version.sh` compares each badge against the manifest, but it checks only the files handed to it as arguments — the enforced set is decided by the invocation line in the workflow, not by the script.
- **Add the release entry to `CHANGELOG.md` and `CHANGELOG.ja.md`.** The changelog is where release history lives and, by its own account, is written as part of this release process; nothing checks the two files against each other, so the parity is yours to keep.
- **Nothing else is machine-checked.** `CHANGELOG.md` and `CHANGELOG.ja.md` parity, `marketplace.json`, git tags, and version numbers mentioned in prose have no check at all; the badge is the only enforced site.
- **Promote `develop` to `main` through a pull request**, not a direct push, and merge it as a merge commit rather than a squash, once `check-handoff lint` has reported success.
- **Tag the release on `main` with an annotated tag `vX.Y.Z`** after that merge lands.
- The promotion and the tag are a **maintainer decision, not an observed practice**: at the time of writing, `develop` had never been promoted to `main`, and the single existing tag sits on a commit reachable from both branches, so it does not by itself evidence tagging after a merge.
- **The install side is documented elsewhere**: [`docs/distribution.md`](docs/distribution.md) covers what an adopter does after a bump, and [`CHANGELOG.md`](CHANGELOG.md) carries the release history that [`README.md`](README.md) points at.

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
