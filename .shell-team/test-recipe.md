# Test recipe — how to run tests in this repository

> Scaffolded by team-init. This file is the persistent, per-repo record of how
> to actually run the test suite here — the launch command, prerequisite
> builds, and environment quirks. The engineer reads it FIRST before running
> tests, and appends any newly established procedure so the next task inherits
> it instead of re-inventing it. qa-verifier runs tests by this recipe too.
> This file is never overwritten by team-init (not even with --force).

## How to run tests

<!-- The canonical command(s) to run the test suite in this repo. -->

Load the plugin from this checkout so `bin/` is on `PATH`:

```bash
claude --plugin-dir ./     # then /reload-plugins after editing agents, skills or bin
```

Run a single suite directly with bash (works with or without the plugin loaded):

```bash
bash tests/<suite>/run.sh
```

To check one spec's acceptance criteria mechanically (dry-run first to catch
unrecognized AC labels, then live):

```bash
bash bin/check-acs.sh --dry-run .shell-team/specs/<slug>.md
bash bin/check-acs.sh .shell-team/specs/<slug>.md
```

There is no single "run everything" entrypoint; CI (`.github/workflows/check-handoff.yml`)
is the authoritative list of every suite + dogfood step that must pass, run in
that file's order.

## Environment quirks / prerequisite builds

<!-- Anything the launch command assumes: test-only images to build first,
     extras to install (e.g. a `.[dev]` extra), services to start, env vars. -->

- `shellcheck` is required, pinned to the version CI installs (currently
  0.11.0 — see `.github/workflows/check-handoff.yml`'s `SHELLCHECK_VERSION`).
  Verify locally with `shellcheck --version` before trusting a shellcheck-clean
  claim; CI installs its own pinned copy regardless of what's on the runner.
- No other prerequisite builds or services — every suite is bash + git +
  standard POSIX tools, run directly from the repo root.

## Appended by tasks

<!-- Append-only log: when a task (T-NNN) establishes a new environment
     procedure, add it here with the task id so the next task inherits it. -->

- T-111: `bash bin/check-acs.sh --dry-run <spec>` then `bash bin/check-acs.sh
  <spec>` (live) is the mechanical per-AC gate; run both, in that order,
  before trusting a spec's acceptance criteria are green. A `check:` line
  that begins a `grep`/`grep -x` invocation with a pattern starting with `-`
  needs `--` (or `-e`) before the pattern or it fails with "invalid option"
  on BOTH BSD and GNU grep — worth checking for when authoring or reviewing
  new `check:` lines.
- T-112: in an interactive sandboxed shell (not real CI), a bare `mktemp`
  call (no explicit template) can fail with "Operation not permitted" on
  macOS even when `$TMPDIR` is exported to an allowed scratch dir — the
  bare/`-t` forms resolve against the OS default temp dir regardless of
  `$TMPDIR`, only an explicit template (`mktemp "${TMPDIR:-/tmp}/name.XXXXXX"`)
  respects it. `tests/check-handoff/run.sh` uses the bare form and fails this
  way in such a sandbox; reproduced identically against `develop` HEAD, so it
  is a sandbox-only artifact, not a regression — verify affected suites via
  actual CI (GitHub Actions has a normal writable `/tmp`) rather than treating
  a local sandboxed failure as authoritative.
- T-112: a diff-scoped checker's self-application check against `--base
  develop` (e.g. `bin/check-pii-shapes.sh --base develop`, T-111) scans
  EVERY commit since develop, including already-committed QA/review
  artifacts (`.shell-team/reviews/*.md`) from a task that is still mid-flight
  (`REWORK`). If that task's own review prose quotes adversarial
  example content by shape (to describe a bug), the still-unfixed checker
  can legitimately flag it — this is an external, cross-task dependency, not
  a defect in a later task sharing the branch. Confirm with `git stash -u`
  (temporarily removing your own in-progress changes) before concluding a
  self-application AC failure is caused by your own diff.
