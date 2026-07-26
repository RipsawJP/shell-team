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

Some checks in this repository test the shipped scripts (shellcheck, the fixture
suites under `tests/`) and some test the repository's **own working
conventions** — the board, the task specs, the generated prompt blocks. The
second kind can fail for reasons that have nothing to do with your change.

If a check fails in a way that looks unrelated to what you touched, **say so in
the pull request rather than trying to satisfy it.** Sorting that out is the
maintainer's side of the work, not yours.

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
