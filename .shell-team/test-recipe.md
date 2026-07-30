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
- Assertions about ignore behavior must pin the excludes file. `git check-ignore`
  reads the operator's global `core.excludesFile`, so a check that inherits it can
  fail on a contributor's machine while CI stays green (runners have no global
  excludes) — the least useful direction for the discrepancy to run. Pin it with
  `git -c core.excludesFile=…`; `tests/rollup-track/run.sh` and
  `tests/gitignore-raw-dumps/run.sh` show the pattern, asserting once under a
  hostile excludes fixture and once under `/dev/null`.
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
  after `git stash -u`" alone. (Confirmed case: a printf format-string
  helper that assembles a GitHub noreply identity at runtime — a `+`-joined
  local part built from two `%s` placeholders, at GitHub's noreply domain —
  in a fixture suite matches the checker's generic mailbox shape and fails
  its (then) digits-first-local-part noreply exclusion — a checker-pattern
  gap on the assembled placeholder, not a real identity leak; the correct
  fix was in the checker's own exclusion shape, not the fragment-assembly
  helper. Resolved by T-111's v4 rework (DP-9): the noreply exclusion is now
  matched on the domain, end-anchored, never on the local part's shape.)
- T-111 (v4 rework): `bash bin/check-acs.sh <spec>` for `T-111-pii-shape-checker.md`
  runs `bin/check-pii-shapes.sh --all` against the whole tree as part of
  AC16, which takes noticeably longer than this repo's other suites (tens
  of seconds) — if invoking it through a tool with a short default timeout,
  run it as a background/long-running command rather than assuming a hang.
  Separately: `grep -nE`/`grep -noE`/`grep -qoE` calls whose PATTERN
  argument is a shell variable need an explicit `--` before that variable
  (the same leading-hyphen defect class already documented above for
  `grep -qxF`), because `RE_PRIVATE_KEY`'s value begins with `-----BEGIN`
  and grep otherwise parses it as a run of short options and exits 2
  instead of scanning. When writing a NEW process artifact (a lessons
  entry, a provenance file, a spec) that needs to DISCUSS a PII shape
  already reported by `check-pii-shapes.sh` (e.g. quoting a fixture's own
  content to explain a design decision), do not transcribe the literal
  match — describe it in words or use the documented placeholder form
  instead, and then run `bin/check-pii-shapes.sh --all` again before
  hand-off: transcribing a real match into a NEW file reproduces the same
  finding on the new file, which is easy to miss since the file you just
  wrote is not the file the original finding named.
- T-1001: a fixture suite that needs a real throwaway `git init` repository
  (not a mocked `git`) must NOT create it under `$HERE/tmp` inside this
  repo's own working tree — the sandbox denies writes to a NESTED `.git/`
  (e.g. copying `hooks/*.sample` during `git init` fails with "Operation not
  permitted"), even though the same sandbox allows normal file writes under
  `$HERE`. Use a `${TMPDIR:+...}` / fallback-to-`$HERE/tmp` temp root instead
  (the exact pattern `tests/close-out/run.sh` already uses) so the suite runs
  the same way in the sandbox and in plain CI. A shallow repository can be
  SIMULATED for a fixture by creating a dummy (even empty) `.git/shallow`
  file inside a normally-built repo — this is existence-only and needs no
  real `git clone --depth`, which sandbox policy has denied in this
  repository before.

- T-1001: a criterion or fixture that asserts **tolerance** — that some input
  shape is accepted — must be proved against BROKEN input of that shape, never
  against valid input. A passing valid input cannot distinguish "accepted" from
  "never inspected", so the two failure modes look identical from the outside.
  This bit twice in one task. A dependency criterion asserted `! grep <tool>
  <script>` with no existence precondition, and `grep` on a missing path also
  exits non-zero, so the criterion was satisfied by the script not existing yet.
  A CRLF-tolerance criterion asserted that a well-formed CRLF ledger passes, and
  the very defect it should have caught — a section-heading match that did not
  strip the carriage return, so the rule never ran — satisfied it by not reading
  the file at all. The shape that works: assert the file exists and that a
  positive pattern matches it FIRST, then assert the negative; and prove
  tolerance by converting a KNOWN-BAD input to the tolerated form and requiring
  that it is still reported.
- T-1001: a fixture whose load-bearing property depends on a threshold must
  assert its own precondition, and must sit far enough from the threshold that a
  kernel or platform difference cannot silently move it to the wrong side. The
  invariants suite's pipe-buffer state produced roughly 77KB of merge log while
  this machine's abort boundary sits between 72KB and 90KB, so reverting the fix
  it was meant to lock left it green — a fixture whose name promised more than
  its assertion delivered. Widened to about 271KB and given a mechanical check
  of its own measured byte count against a declared floor, so shrinking it later
  fails loudly with the number named instead of quietly reverting to
  non-load-bearing. Measure the threshold rather than estimating from a proxy:
  the trigger is bytes written to the pipe, not the merge count, and a
  count-based estimate is wrong by whatever the subject length happens to be.

- T-1002: `bash tests/check-interventions/run.sh` is `bin/check-interventions.sh`'s
  fixture suite — run it the same way as `tests/check-provenance/run.sh`
  (no new prerequisite: pure bash + coreutils, same explicit
  `"${TMPDIR:-/tmp}/...XXXXXX"` mktemp-template convention, fixtures built
  inline per case, no static `fixtures/` directory).
- T-1004: `bash tests/interventions-reminder/run.sh` is
  `docs/interventions-reminder-hook.sample.sh`'s fixture suite. The one
  non-obvious environment requirement: the suite must make `team-paths.sh`
  reachable as a bare name on `PATH` (a `cp`'d-plus-`chmod 755` copy in a
  throwaway shim dir per fixture cwd), because the sample deliberately has no
  `bin/` fallback and would otherwise silently no-op through every case —
  the suite asserts `command -v team-paths.sh` under the modified `PATH`
  before every case that expects an emission, as the anti-vacuity control.
- T-1006: `tests/gen-playbook-blocks/fixtures/root/` is committed WITHOUT the
  legacy marker (`tasks/loops/shell-team.contract.yaml`), even though it
  carries `tasks/lessons.md` — so `bin/team-paths.sh` classifies a bare
  `--root` clone of it as the DEFAULT layout, not legacy, and now that
  `bin/gen-playbook-blocks.sh` derives its lessons default from the resolver
  (T-1006), a clone with no marker looks for `.shell-team/lessons.md` instead
  of the fixture's actual `tasks/lessons.md`. `tests/gen-playbook-blocks/run.sh`'s
  `clone_fixture()` creates the marker at runtime (never committed into the
  fixture tree — every other suite in this repo already does the same), and a
  sibling `clone_fixture_default_layout()` derives the opposite variant
  (moves the corpus to `.shell-team/lessons.md`, no marker) for the
  default-layout coverage cases. Before adding a NEW fixture-consuming case to
  that suite, use one of these two helpers rather than a bare `cp -R
  "$FIX" ...` — a bare clone silently drifts to whichever layout the fixture
  tree happens to carry that day.
- T-1007: every entry in all three of `bin/check-playbook.sh`'s ledger
  fixture corpora — `tests/check-playbook/fixtures/valid-base.md`,
  `tests/gen-playbook-blocks/fixtures/root/tasks/lessons.md`, and
  `tests/playbook-promote/fixtures/lessons-base.md` — now carries a required
  `- **Scope**: loop | maintainer` bullet, and a `Scope: maintainer` entry
  additionally requires `- **Bound-in**: <repository-relative path>`
  (forbidden on `Scope: loop`). A fixture entry with no `Scope` bullet at all
  is not merely incomplete: `bin/check-playbook.sh` now rejects it fail-closed
  (`missing required field: Scope`), which turns the ENTIRE consuming suite
  red, not just the one assertion that happened to touch the malformed entry
  — because most ad-hoc printf-built entries in `tests/check-playbook/run.sh`
  and `tests/gen-playbook-blocks/run.sh` are fed straight through the real
  checker/generator as fixtures-in-fixtures. Before adding a new synthetic
  entry to either suite (a fence-content probe, a Superseded-by probe, a
  bulk/threshold probe, ...), add `- **Scope**: loop` to it as a matter of
  course, the same way `- **Category**: process` already is. The three
  corpora's own `## Format` fenced examples document both new fields; the
  `Scope` line there uses the angle-bracket placeholder `<loop | maintainer>`
  (never a bare `loop`/`maintainer` token) precisely so a `sed` targeting a
  real entry's `Scope` value cannot also mutate the documentation — but
  `Bound-in`'s placeholder line does NOT get the same free pass everywhere:
  `tests/playbook-promote/fixtures/lessons-base.md`'s own `## Format` fence
  intentionally spells it `- **Bound-in** (required when Scope is
  maintainer, forbidden when Scope is loop): <repository-relative path>`
  (no colon immediately after `**Bound-in**`) rather than the
  `- **Bound-in**: <...>` shape the other two corpora use, because
  `bin/playbook-promote.sh`'s own suite greps for the exact substring
  `- **Bound-in**: ` (with the colon) to assert "no Bound-in bullet has been
  emitted yet" after a `--scope loop` promotion — a literal fenced-example
  bullet in that shape would satisfy the same substring and produce a false
  positive, since `grep -F` matches anywhere in the file, fenced content
  included.
