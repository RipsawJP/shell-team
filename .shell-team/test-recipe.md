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
- T-112: a bare `mktemp` call (no explicit template) is a real, latent
  portability defect, not merely a local sandbox quirk — on macOS the
  bare/`-t` forms resolve against the OS default temp dir regardless of
  `$TMPDIR`, only an explicit template (`mktemp "${TMPDIR:-/tmp}/name.XXXXXX"`)
  respects it, and this repo's own convention (`tests/rollup-track/run.sh`,
  2026-06-16 / T-038) already documents the explicit-template form. In an
  interactive sandboxed shell this surfaces as "Operation not permitted"
  even with `$TMPDIR` exported to an allowed scratch dir, but the underlying
  defect is real regardless of the shell. Before touching one bare-`mktemp`
  site, inventory the WHOLE class first: `grep -rn 'mktemp' bin tests
  --include='*.sh'`, then classify each hit as already-explicit-template
  (no change) or bare/OS-default (needs the explicit-template fix) — do not
  fix a single file and assume the class is covered. After converting a bare
  call, check whether it already fails closed on a `set -euo pipefail` script
  without any extra guard: a plain top-level `x="$(mktemp ...)"` assignment
  (not inside `if`/`&&`/`||`) already aborts the script via errexit on
  failure (verified: `set -e; x="$(false)"` aborts immediately) — no
  additional `|| die` is needed unless the assignment sits inside a context
  that would otherwise swallow the failure.
- T-112: a diff-scoped checker's self-application check against `--base
  develop` (e.g. `bin/check-pii-shapes.sh --base develop`, T-111) scans
  EVERY commit since develop, including already-committed QA/review
  artifacts (`.shell-team/reviews/*.md`) from a task that is still mid-flight
  (`REWORK`), so it can legitimately flag adversarial example shapes that
  review prose quotes to describe a bug — an external, cross-task dependency,
  not necessarily a defect in a later task sharing the branch. But when using
  `git stash -u` to test whether a failure is caused by your own diff, `-u`
  also removes your OWN new **untracked** files from the scan — so a finding
  inside a file you just added can look identical to a pre-existing one
  once stashed. Always check the reported path(s) against your own file
  list BEFORE concluding a failure is external; do not rely on "still fails
  after `git stash -u`" alone. (Confirmed case: a `%s+%s@users.noreply.
  github.com` format-string helper in a fixture suite matches the checker's
  generic mailbox shape and fails its digits-first noreply exclusion — a
  checker-pattern gap on the assembled placeholder, not a real identity
  leak; the correct fix was in the checker's own exclusion shape, not the
  fragment-assembly helper.)
