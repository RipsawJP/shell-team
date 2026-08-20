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

- T-1084: an `xargs -P <cores>`-fan-out full-population Blast-radius sweep
  (see the T-1083 entry above for the base pattern) that exceeds this
  session's own foreground-Bash-call timeout auto-backgrounds — but that
  auto-background can itself be silently `killed` by the harness partway
  through (observed: 63/88 outputs written, then stopped, no error surfaced
  beyond the background task's own `status: killed` notification). Launch
  the fan-out **explicitly** with `run_in_background: true` from the start
  rather than relying on the timeout-triggered auto-background, and after
  ANY interruption (killed or otherwise), recompute the remaining
  population as a set difference (`comm -23 <the full population, sorted>
  <the outputs already written, sorted>`) and re-launch only that
  remainder — never assume a partial output directory means the population
  is done, and never re-run the whole population from scratch (wasteful and
  risks a second timing-out attempt on the same slow specs). Separately,
  even a completed-count match is not sufficient: verify every single
  output file's own `tail -1 | grep -q '^check-acs: '` completion marker
  (per the T-1082 entry above) before trusting any of them — this sweep's
  first full pass produced 14/88 outputs that reached the 88-file COUNT
  but were individually truncated mid-run (the shared 90s `CHECK_ACS_TIMEOUT`
  under 8-way contention was too tight for a handful of the heavier specs,
  T-1082/T-1083-class full-suite-referencing ones among them); those 14
  were re-run individually at a smaller parallelism factor (`-P 4`) and a
  higher `CHECK_ACS_TIMEOUT=300` to let them complete without contention.

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
- T-1008: **superseded by T-1038** — editing `bin/gen-playbook-blocks.sh`
  above its line-count warning (`LINE_WARN_THRESHOLD`) no longer touches
  `tests/errexit-safe/run.sh`'s `NOT_APPLY` registry at all: since T-1038 the
  registry keys on `<file>:<content>` with an explicit declared occurrence
  count, never a line number, so nothing above a registered line can shift
  its key. What DOES still affect the registry: rewording or re-indenting the
  registered line's TEXT itself (the `printf` continuation this entry used
  to name), deleting it, or adding a second byte-identical unguarded line to
  the same file — any of those changes the declared-vs-measured count and
  the suite's own completeness/staleness self-audit says so loudly, printing
  the up-to-date record. Re-derive by re-running `tests/errexit-safe/run.sh`
  and reading that output, never by hand-editing a count or a line — this is
  the same class of hazard T-1006 and T-1007 each hit once on the identical
  pin before T-1038 closed it structurally. Separately: a `check:` command
  that scans the whole working tree (for example `check-pii-shapes.sh
  --all`, or any acceptance-criteria checker invocation that runs a suite
  covering the entire repository) can take tens of seconds — long enough to
  look hung through a tool with a short default timeout. Run it in the
  background, or raise the timeout, rather than treating the wait itself as
  a failure signal.
- T-1016: **superseded by T-1038** — `tests/errexit-safe/run.sh`'s
  `NOT_APPLY` registry no longer has a position field, so the class this
  entry used to describe (editing the header comment or any code above a
  pinned line in `check-handoff.sh`, `close-out.sh`, `check-board-
  headings.sh`, `check-acs.sh`, `check-contract.sh`, or any other file the
  registry names) no longer shifts anything: the key is `<file>:<content>`
  plus a declared occurrence count, and position never enters the judgment.
  There is no `NOT_APPLY_FILE` filename grep to run before editing one of
  those files, and no drift to chase. The registry only reacts if a
  registered line's TEXT changes (a rewrite, a deletion, or a second byte-
  identical duplicate added to the same file), and the suite's own `comm
  -23`/`comm -13` judgment over the counted key sets surfaces that on both
  sides at once — run the suite and read its failure output for the correct
  record rather than editing the registry by hand. This retires the older
  "grep the registry first, or record a documented finding and let a
  human-ratified scope widening update it" workaround this entry used to
  prescribe; there is no drift left for a same-task collateral fix to chase
  scope around.
- T-1019: `bash tests/is-span-row-parity/run.sh` is the dedicated parity
  suite proving `bin/rollup-runs.sh`'s and `bin/cluster-failures.sh`'s
  independently-maintained `is_span_row()` copies (T-1011 hazard H4) still
  agree, over its own `fixtures/` (six one-row files, one per discriminator
  class). No new prerequisite: pure bash + coreutils, black-box only (it
  invokes both real `bin/` scripts by `$REPO_ROOT`-derived path and reads
  their stdout — never `sed`+`eval` extraction). The mutation-based
  anti-vacuity procedure (AC4/AC5), to run by hand on a `$TMPDIR` scratch
  copy — never the working tree: `mkdir -p "$d/tests" && cp -R bin "$d/bin"
  && cp -R tests/is-span-row-parity "$d/tests/is-span-row-parity"`, run the
  scratch suite once (must be green — the positive control the scratch tree
  runs at all), patch exactly one of `bin/rollup-runs.sh` /
  `bin/cluster-failures.sh` with `sed 's/== "span"/!= "zzz"/'` (assert the
  patch applied and the sibling script is still unpatched), run the scratch
  suite again (must exit non-zero and name the patched script plus
  `kind-event.jsonl`), then delete the scratch dir. Do this once per
  direction (one script patched at a time) and restore/observe green is
  implicit since the scratch copy is discarded rather than un-patched.
- T-1016: a suite run under `set -euo pipefail` that computes a count via
  `x="$(producer | grep -c PATTERN)"` aborts the whole script the moment the
  count is genuinely `0` — `grep -c` still exits 1 when nothing matched (the
  printed `0` does not change that), `pipefail` propagates that 1 as the
  pipeline's exit status, and a plain top-level assignment under `set -e`
  treats that as a script-ending failure, before the `[ "$x" -eq 0 ]`
  assertion that was supposed to accept the zero ever runs. This bit four
  new `## Active`-emptiness assertions in `tests/close-out/run.sh` (the
  suite died with a bare exit 1 and no `FAIL:` line). Fix: append `|| true`
  to the `grep -c` pipeline itself (never to the whole assignment, and keep
  the immediately-following explicit `[ "$x" -eq N ] || fail ...` assertion
  so an unexpectedly non-zero count is still caught) — distinct from, but
  the same family as, the `grep -q`-under-`pipefail`-SIGPIPE entry above.
- T-1022: `tests/close-out/run.sh`'s differential-testing harness
  (`closeout-lineshape-differential`, D9/D10) builds a full board per
  corpus line under `$TMP/lineshape/caseN`, runs the real `bin/close-out.sh`
  against it, classifies the outcome as `notlocated` (pass 1 never finds
  the task) or, for a located line, `refused`/`accepted` against an
  **independently and live re-computed** oracle — `bin/check-handoff.sh`
  run against a freshly-synthesized single-entry board built from that same
  corpus line, never a hardcoded verdict — and prints one summary line
  (`corpus=`/`refused=`/`accepted=`/`notlocated=`/`mismatches=`). Adding a
  corpus line needs no manual prediction of its class: append it to
  `LS_LINES` (or call `lineshape_case` directly for a CRLF variant) and let
  the run classify it; only the five floor/`mismatches=0` assertions at the
  bottom of that section need to hold. The suite's own runtime grew from
  well under 10s to roughly 15s (measured, this machine) purely from this
  harness's ~30 extra `close-out.sh` + `check-handoff.sh` subprocess pairs —
  budget for it if invoking `tests/close-out/run.sh` through a tool with a
  tight default timeout, same caution as the T-1008 entry above for
  whole-tree scans.
- T-1022: **superseded by T-1038** — `tests/errexit-safe/run.sh`'s
  `close-out.sh` pin used to couple **six lines / seven occurrences**: the
  `NOT_APPLY` heredoc entry, the explanatory comment above the mutation
  self-check, the mutation `sed` pattern (twice on one line), the
  `grep -qF`, and the `ok`/`bad` message strings, all keyed on a re-derived
  line number `N`. T-1038 collapsed that to **one**: the registry record is
  now the sole occurrence of its key anywhere in the file (the suite's own
  one-canonical-definition lock enforces this — re-hardcoding a key into a
  message or a comment fails it), and every message that used to name the
  key literally now reads it out of the registry at run time. Editing
  `bin/close-out.sh`'s registered line therefore touches nothing in the
  suite except that one record, and only if the line's TEXT changed — a
  pure re-line-numbering does nothing at all, by design, since position is
  not part of the key. There is no `N` to re-derive with a `close-out\.sh:
  [0-9]+` grep (that command cannot be run after T-1038; the pattern no
  longer matches anything in the file). Instead, re-run
  `tests/errexit-safe/run.sh` — if the line's text changed, its completeness
  or staleness self-audit fails and prints the correct up-to-date record —
  and paste that output into the registry as-is, never hand-typed.
- T-1028: `bash tests/check-refreeze-class/run.sh` is `bin/check-refreeze-class.sh`'s
  fixture suite (the M1 classifier for the class-M/class-B re-freeze split —
  see `docs/tuning-oversight.md`'s "Who may re-freeze a frozen intent block"
  section and `CONTRIBUTING.md`'s "Re-freezing a frozen intent block"
  section). No new prerequisite: pure bash + coreutils + git, same
  synthetic-fixture-in-a-temp-dir convention as `tests/check-intent/run.sh`
  and `tests/check-provenance/run.sh` (no static `fixtures/` directory).
  Every one of its 30 cases runs through a single `assert_case` helper that
  asserts exit code AND classification token together — when adding a new
  case, route it through that helper (never call the classifier directly),
  or the suite's own AC7-shaped self-count (`grep -c 'assert_case '`) and the
  both-assert discipline both silently degrade. The classifier's own bash-3.2
  compatibility bar (indexed arrays only — no associative arrays, no
  `mapfile`) applies to this suite too, since it is invoked with the same
  `bash` this repository's other `tests/*/run.sh` files are.
- T-1034: `bash tests/bin-exec-bit/run.sh` is the lock suite proving every
  tracked file under `bin/` ships at git index mode `100755` (judged via
  `git ls-files -s -- bin/`, never a working-tree `test -x` — a
  `core.fileMode=false` checkout would lie). No new prerequisite: pure bash
  + git, no static fixtures. When editing `bin/check-refreeze-class.sh` or
  `bin/check-intent.sh`'s `EXIT`/signal/`print_help` machinery, also run
  `tests/check-intent/run.sh` and re-derive `check-acs.sh`'s shape against
  any spec whose intent block is extracted by either script — a change to
  the shared `on_signal`/`cleanup_tmp_*`/`print_help` fragments touches both
  scripts at once by design (T-1028 AC5's "one definition, two consumers"
  discipline, reused here for the signal handler).
- T-1024: a delta on the T-112 entry above, not a restatement of it. WHY a
  spec's `- check:` line needs the guard: `bin/check-acs.sh` runs every
  check through `bash -c "$cmd"` with `set +e` immediately before it and
  no `set -e` inside the executed shell, so errexit never rescues an
  unguarded `d=$(mktemp ...); rc=0; ...` assignment the way it would in a
  normal `set -e` script — on failure `$d` is empty and every path
  composed from it (`"$d/x"`) expands root-anchored. The guard: use
  `d=$(mktemp -d "${TMPDIR:-/tmp}/<slug>.XXXXXX") || exit 1`, with the
  failure exit before the first composed path is used (T-1023's own
  `check:` lines already use this idiom; T-1024's audit inventories every
  other spec's site instead of editing them). Two rules travel with the
  idiom: reflect a write/`sort`/`comm`/`git` failure explicitly into
  `rc=1` rather than letting it disappear, and let `|| true` absorb only a
  `grep -c`'s "no match" exit status, never a producer's failure — a
  counted value that could be zero because the file was never written
  needs its own positive control beside it (`test -s`, or a known-present
  anchor), the exact AC11-shape gap `docs/loop-engineering/
  check-line-mktemp-guard-audit.md` measured.
- T-1038: `tests/errexit-safe/run.sh`'s `NOT_APPLY` registry is re-keyed to
  `<count><SP><file>:<content>` — an unpadded declared occurrence count, one
  space, the `bin/`-relative file, a colon, and the source line byte for
  byte — with no line number in any key, record or assertion (T-1008,
  T-1016 and T-1022 above are rewritten in this same change to describe the
  new invariant instead of the retired one). One mechanism produces both
  judgments: `comm -23` over the counted key sets is the forward
  (completeness) failure — an unregistered key, or a registered key whose
  measured count moved — and `comm -13` is the reverse (staleness) failure —
  a registered key whose measured count no longer equals its declaration,
  including a fall to zero. A registered line's position moving within its
  own file no longer fires anything, by design; only its TEXT (a rewrite, a
  deletion, or a second byte-identical duplicate appearing in the same
  file) does. When the registry needs updating, run
  `tests/errexit-safe/run.sh` itself and paste its completeness/staleness
  failure output into the heredoc as-is — never hand-type or hand-edit a
  record; that is exactly the failure mode the pinned eight-space
  `gen-playbook-blocks.sh` continuation record exists to make loud. Three
  quoting hazards apply to any future edit of this suite: **(1)** `awk -v`
  processes backslash escapes in the assigned value, so passing a registry
  content (every one carries a literal two-character `\n`) through `-v`
  silently turns it into a real newline and the comparison never matches —
  pass content through `ENVIRON[...]` instead. **(2)** never locate a
  registry content with `sed` or a regex — the contents carry `.`, `*`,
  `[`, `$`, `%` and quote characters — use an exact whole-line comparison in
  `awk` (`$0 == old`) and assert the match count before and after
  substituting. **(3)** do not build the counts with `uniq -c` unless its
  padding is normalized first (GNU and BSD pad differently); an
  `awk '{c[$0]++} END{...}'` counter avoids the question. `derive_candidates()`
  keeps `grep -n`'s line numbers through its own `sort -u`; `counted_keys()`
  strips the line field only afterward, when the count is formed — the one
  ordering that lets two byte-identical candidate lines in a file survive as
  two distinct rows instead of collapsing at the source.
- T-1041: a fixture/assertion id chosen for a `check:` line or a test suite —
  or any other hand-authored hyphenated compound — that happens to spell an
  unboundaried `sk-` followed by 16+ token characters (letters, digits,
  underscore, hyphen) false-positives `bin/check-pii-shapes.sh`'s `token`
  pattern with no way to suppress it (the checker carries no path allowlist
  or inline-allow by design, issue #178). Measured case: an id containing
  "…task-**id**-malformed…" spells `sk-id-malformed…` as a literal
  substring. Check a candidate id against `RE_TOKEN` in `bin/check-pii-shapes.sh`
  BEFORE writing it into a spec's frozen intent block (where it can no
  longer be renamed without a re-freeze); if the id is already frozen, the
  only lever left is reducing its occurrence count in the files that must
  still spell it verbatim (a shell variable in a test script; a paraphrase
  in prose that avoids re-transcribing the literal, same discipline as the
  PII-scrub-writing entry above) — the finding itself does not go away and
  must be disclosed, not silently absorbed.
- T-1041: `--print-hash`-style "does this leave a temp file behind" fixtures
  are asserted by pointing `TMPDIR` at a fresh, otherwise-empty scratch
  directory for the single invocation under test, then confirming that
  directory is still empty afterward (`find "$dir" -mindepth 1`) — cheaper
  and less flaky than instrumenting the script itself, and it exercises the
  real `mktemp`/EXIT-trap code path rather than a mock.
- T-1041: `tests/check-intent/run.sh` extended past 1300 lines and ~7s
  standalone runtime; the whole `T-1041-freeze-ux.md` spec (23 `check:`
  lines, including three whole-suite re-runs) measured ~19s live — well
  under `CHECK_ACS_TIMEOUT`'s 120s default, so no elevation was needed. A
  later task extending this suite further should re-measure rather than
  assume the same headroom still holds.
- T-1042 (Half A, descoped 2026-08-07 to successor task T-1046 — this
  entry is retained as generic knowledge for whoever picks that work up,
  NOT a description of what `tests/team-paths/run.sh` or
  `tests/team-init/run.sh` currently carry; the Half A fixtures that once
  lived in both were reverted with the rest of that surface, and both
  files are byte-identical to `6439eb6` again): the T-1001 entry above ("a
  fixture suite that needs a real throwaway `git init` repository ... must
  NOT create it under $HERE/tmp inside this repo's own working tree") is
  not limited to `tests/retro-inputs/run.sh` — it also hit
  `tests/team-paths/run.sh` and `tests/team-init/run.sh` the first time
  either needed a real `git init`-ed fixture (both previously used only
  plain, non-git directories under `$HERE/tmp-roots` / `$HERE/tmp-targets`,
  and are back to that today). Whoever adds git-needing fixtures to either
  suite next should reach for a second, `$TMPDIR`-backed root (the same
  `${TMPDIR:+...}`-falls-back-to-`$HERE/<name>-tmp` idiom, its own trap)
  reserved for git-needing fixtures, kept separate from the pre-existing
  plain `$TMP` root — a fixture built under `$TMP` fails with
  `Operation not permitted` copying `.git/`'s hook templates (or, with
  `--template=`, writing `.git/config` itself) in a sandboxed run, even
  though plain non-git file writes to the same directory succeed.
  Separately: pinning `git check-ignore`'s `core.excludesFile` input for an
  assertion that exercises code which itself calls `git` internally
  (rather than the test calling `check-ignore` directly, the shape
  `tests/rollup-track/run.sh` and `tests/gitignore-raw-dumps/run.sh`
  already show) needs the fixture repo's OWN **persisted**
  `core.excludesFile` config
  (`git -C "$dir" config core.excludesFile <path-or-/dev/null>`), not a
  transient `git -c core.excludesFile=... <cmd>` on the outer invocation —
  a `-c` flag on the test's own command never reaches a git call made
  inside the script under test, while a persisted repo-local config value
  is read by every subsequent git invocation against that repo regardless
  of who makes it. T-1046 (Half A's successor) is the most likely
  consumer of both points.
- T-1044: one lock suite, pure bash + git + coreutils, no new
  prerequisite. `bash tests/bin-exec-bit/run.sh` (extended, not renamed —
  same suite T-1034 shipped) now also enforces a BIDIRECTIONAL rule over
  every tracked file under `tests/`: the committed blob begins `#!` iff
  the index mode is `100755`, judged from `git ls-files -s -- tests/` plus
  `git cat-file blob` (index-read both halves, same discipline as the
  `bin/` half above — never a working-tree `test -x`). A second, standing
  shape lint against a fixed, guessable scratch root under `tests/` was
  drafted for this task and then descoped after two consecutive
  cross-provider rework rounds against it; that standing lint is deferred
  to its own follow-up task and ships nothing here. When adding a new
  `tests/<suite>/run.sh`: it must be committed at index mode `100755`
  (the bidirectional rule now catches a `100644` shebang script under
  `tests/` exactly as loudly as it always did under `bin/`), and its
  scratch root must be built with `mktemp -d ... XXXXXX` — the two-arm
  `TMPDIR`-then-`$HERE`-fallback idiom at
  `tests/check-refreeze-class/run.sh:82-87` is the shape to copy, UNLESS
  the new suite either (a) builds throwaway `git init` repos under its
  scratch root, in which case keep the root under `${TMPDIR:-/tmp}` only
  and never add a `$HERE` fallback (a fallback would put a nested `.git`
  inside this checkout's own tree, which sandboxed runs deny — see
  `tests/check-board-headings/run.sh` and
  `tests/codex-skeleton-hygiene/run.sh`), or (b) depends on its scratch
  root sitting at a FIXED DEPTH under the repo root for a relative-symlink
  launch-path case, in which case keep a single `$HERE` arm only and never
  add a `$TMPDIR` arm that would relocate the root out of tree and change
  the hop count (see `tests/rework-digest/run.sh`'s
  `../../../../bin/rework-digest.sh` case). Separately,
  `tests/install/run.sh`'s temp files now live under its own already-
  `mktemp`'d `$WORK` rather than directly under the shared, fixed
  `/tmp/claude` parent — a cleanup glob over a directory other concurrent
  runs also write to is its own defect class (DP7), out of the lock's
  machine scope; a new suite should never `rm -rf` a wildcard over a
  parent directory anything else might be writing to.
- T-1051: the T-1041 entry above (a hyphenated compound spelling an
  unboundaried `sk-` + 16+ token characters false-positives `token` with no
  way to suppress it) is **narrowed, not retired**, by #178's left boundary
  guard on `RE_TOKEN`'s `sk-` alternative (class `[^A-Za-z0-9]`). The exact
  measured case that entry names — `…task-**id**-malformed…`, where the
  character immediately before `sk-` is the letter `a` — no longer
  false-positives at all; confirmed live (`echo 'task-id-malformed-example'
  | grep -qE -- "$RE_TOKEN"` now reports no match). The same id at line
  start, after a space, or after any other non-alphanumeric character
  still fires (DP-10's bias toward firing, deliberately unchanged) — so
  the check-before-freezing discipline that entry describes still applies
  in general; only the specific "immediately after a letter or digit"
  sub-case is closed. Do not sweep existing emphasis-break spellings
  elsewhere in this repo to remove them (T-1051's own Non-goals; they
  remain correct either way) — this note only corrects the "no way to
  suppress it" claim for the boundary this fix actually closes.
- T-1054: `bash tests/check-binding/run.sh` is `bin/check-binding.sh`'s
  fixture suite (the T-1054 fail-closed binding-config validator and its
  `--print-binding`/`--print-lock`/`--verify` integrity primitives). No new
  prerequisite: pure bash + git, same synthetic-fixture-in-a-scratch-dir
  convention as `tests/check-refreeze-class/run.sh` (the two-arm
  `TMPDIR`-then-`$HERE` `mktemp -d … XXXXXX` idiom, no static `fixtures/`
  directory — this suite builds no `git init` repositories, so the
  `$HERE` fallback arm is the right one, not the `${TMPDIR:-/tmp}`-only
  arm T-1044 reserves for suites that do). One non-obvious authoring trap
  worth inheriting: proving `--verify`'s comment-only-edit tolerance and
  its `binding-changed` refusal both require editing the SAME config
  path the lock recorded (in place, then restored byte for byte before
  the next case) — a differently-NAMED file with identical or edited
  content trips `path-mismatch` first and never reaches the property the
  case is meant to prove, since per-mode refusals in this checker are
  ordered path-match before content-validate. Separately, a payload
  string meant to prove "a field value is refused, never evaluated"
  (a `$(...)`, a `;...;`, a backtick payload) must contain no embedded
  whitespace — a payload with a space splits into two fields under this
  format's whitespace-delimited grammar and is refused as
  `unparseable-line` (a wrong-field-count row) rather than the intended
  `bad-token` (a malformed single token), which still proves no
  evaluation happened but asserts the wrong token if the test pins one.
- T-1051: a bash builtin's write (`printf`, `echo`) to a broken pipe can
  behave two very different ways depending on SIGPIPE's disposition, and
  this coding sandbox's inherited disposition (SIG_IGN, from its own
  parent process tree) masks the more dangerous of the two — do not trust
  a "no failure observed" result from a SIGPIPE-adjacent probe run
  directly in this environment without first checking
  `python3 -c "import signal; print(signal.getsignal(signal.SIGPIPE))"`
  (`1` means `SIG_IGN`, inherited, not the real-world default). Under the
  TRUE default (SIG_DFL, terminate — what a normal shell/CI/terminal
  gives you), a builtin write to a closed pipe kills the whole process
  synchronously inside the write() syscall, before any `||`/`trap`/`set -e`
  handling ever runs; under SIG_IGN, the same write instead returns an
  ordinary non-zero status from the builtin ("printf: write error: Broken
  pipe"). To force the TRUE default disposition for a live probe despite
  the sandbox's inheritance (bash's own `trap - PIPE` only restores the
  INHERITED disposition, which is already SIG_IGN here, so it does not
  help): fork in Python, explicitly `signal.signal(signal.SIGPIPE,
  signal.SIG_DFL)` (or `SIG_IGN`, to compare) in the child BEFORE
  `os.execvp`, close the pipe's read end first, then exec into the target
  shell command with its stdout `dup2`'d onto the write end.
- T-1055: `bash tests/check-adapter/run.sh` is `bin/check-adapter.sh`'s
  fixture suite (the T-1055 fail-closed task-envelope contract + adapter
  definition validator, plus its `--print-contract`/`--adapter`/
  `--definitions`/`--contract`/`--binding` modes). No new prerequisite: pure
  bash + git, same synthetic-fixture-in-a-scratch-dir convention as
  `tests/check-binding/run.sh` (the two-arm `TMPDIR`-then-`$HERE` `mktemp -d
  ... XXXXXX` idiom, no static `fixtures/` directory - this suite builds no
  `git init` repositories). One authoring trap this suite's own fixtures
  hit: a spec `- check:` line that asserts a `carries <field> <channel>`
  row via a single-literal-space regex (`grep -cE "^carries $fl
  [a-z][a-z0-9-]*$"`) means the SHIPPED definition files must themselves be
  single-space-delimited on that directive - a visually column-aligned
  `carries` row (extra internal whitespace for readability) reads fine to
  the checker's own `read -r -a f` field splitting but silently fails a
  frozen criterion's exact-single-space grep. Author every `carries` row
  (and any other directive a frozen `- check:` line greps by fixed
  whitespace shape) single-space from the start rather than aligning
  columns. Measuring an executor's real effort/reasoning mechanism (DP7 of
  `.shell-team/specs/T-1055-adapter-envelope.md`) for the Codex CLI: its
  `--help`/`exec --help` document no dedicated `--effort` flag, only a
  generic `-c key=value` config override with NO client-side validation -
  passing a deliberately invalid `-c model_reasoning_effort=<garbage>`
  value reaches the provider, which refuses it with a 400 whose message
  enumerates the complete accepted value set verbatim; that provider-side
  refusal message, not documentation, is the measurement. Separately: a
  spec's own `## Blast radius` full-population diff (running
  `bin/check-acs.sh` against every `.shell-team/specs/*.md` file at both
  the base ref, via a disposable `git worktree add --detach`, and at HEAD)
  takes on the order of ten-plus minutes per side on this machine - poll a
  backgrounded run's output file for row-count growth rather than waiting
  on a single long timeout, and NEVER launch a second background attempt
  of the identical script "just in case" the first one's own launch looked
  suspicious (e.g. a `nice(5) failed: operation not permitted` warning from
  a manual `&`-backgrounding attempt) without first confirming, from the
  output file itself, that only one instance is actually running - two
  concurrent instances of the same script race to truncate-then-append the
  same output file, producing silently duplicated rows for whichever specs
  both instances processed before one finished, which is easy to miss
  since the corruption is partial (only the early portion of the file) and
  every individual line still looks well-formed.
- T-1074: `bash tests/aggregate-verdicts/run.sh` is `bin/aggregate-verdicts.sh`'s
  fixture suite (the T-1074 fail-closed fan-out aggregator). No new
  prerequisite: pure bash + coreutils, no static `fixtures/` directory (every
  population/part file is built inline via `printf`, the same convention
  `tests/derive-populations/run.sh` uses). Measured: standalone run
  `exit=0 elapsed=3s`, 18 `PASS:` lines, 0 `FAIL:` lines
  (`grep -c '^PASS:' <log>` = 18, `grep -c '^FAIL:' <log>` = 0). The whole
  spec's own `CHECK_ACS_TIMEOUT=300 bash bin/check-acs.sh
  .shell-team/specs/T-1074-fanout-orchestration.md` (all 19 criteria,
  `--dry-run` first) measured `elapsed=54s` on this machine — comfortably
  inside the spec's own instruction to raise `CHECK_ACS_TIMEOUT` to at least
  300 for this spec (AC8/AC17 each run a whole fixture suite). AC9's
  negative control builds its coverage-check-disabled mutant by `sed`-
  neutering the single, literal `die 3 uncovered-unit` call in a scratch
  copy of `bin/aggregate-verdicts.sh` under `$TMPDIR` — never the working
  tree — and asserts the occurrence count of that literal text is exactly 1
  before the substitution and exactly 0 after, so a future rewording of
  that line does not let the mutation silently no-op.
- T-1055 (round 2 / v2 rework): a doc's "canon region" delimited by a
  marker-comment pair that itself sits inside a fenced code block (e.g.
  `` ``` ``, then `<!-- BEGIN X -->`, content, `<!-- END X -->`, then
  `` ``` `` again) must have the FENCE lines OUTSIDE the marker pair, not
  inside it — an `awk` extraction keyed on the marker lines (not the fence
  lines) captures the fence lines too if they sit between the markers,
  which then fails a byte-identity comparison against a command's raw
  output that never included them. Verify a marker-plus-fence layout by
  running the actual extraction command against the first draft, not by
  reasoning about which delimiter nests inside which. Separately: when
  writing a NEW shape-check against another script's own canonical output
  format (here, `bin/check-binding.sh --print-binding`'s `schema <version>`
  line followed by N `bound` rows), re-read that format's full grammar
  before parsing it — a check written to expect only the row type under
  test (all lines are `bound` rows) breaks immediately against the real
  producer's own leading `schema` line, which its own spec's `## Summarized
  sources` already documented.
- T-1056: `bash tests/check-liveness/run.sh` is `bin/check-liveness.sh`'s
  fixture suite (the fail-closed, out-of-band loop-liveness classifier). No
  new prerequisite: pure bash + git + coreutils, the two-arm
  `TMPDIR`-then-`$HERE` `mktemp -d ... XXXXXX` idiom (the same shape
  `tests/check-refreeze-class/run.sh:82-87` uses). Deliberately **no git
  init scratch repository**: every git-band case (`STALLED` via a stale
  state file with a fresh `HEAD`, `DEAD` via both clocks old) instead
  measures THIS checkout's own real `HEAD` committer epoch live
  (`git log -1 --format=%ct HEAD`) and derives `$LIVENESS_NOW` relative to
  it — reaching the same cells a scratch repository would, without the
  sandboxed nested-`.git` write restriction the T-1001 entry above already
  documents. Every threshold boundary is exercised through `$LIVENESS_NOW`
  (no `sleep` anywhere, matching this checker's own design). Two portability
  notes specific to this checker: **(1)** its reason registry
  (`templates/liveness-reasons.txt`) is resolved from the checker's own
  installed directory (`$SCRIPT_DIR/..`), never the working directory — to
  exercise `registry-unreadable`/`registry-malformed` against a
  deliberately corrupted registry, build a scratch "install" (a copy of
  `bin/check-liveness.sh` plus `bin/team-paths.sh` under a scratch `bin/`,
  with a scratch `templates/liveness-reasons.txt` beside it) rather than
  editing the shipped file. **(2)** a `sed` pattern deliberately containing
  literal `$(...)`/`;...;` text (the no-eval CANARY proof) needs
  `# shellcheck disable=SC2016` on its own line, immediately above a
  single-statement line — shellcheck does not honor the directive when it
  shares a `;`-joined line with a preceding assignment.
- T-1056 (Codex round-1 rework): `exec N< file` (or any bare `exec` with
  redirections and no command word) applies EVERY redirection it is given
  to the CURRENT shell PERSISTENTLY, not scoped to that one statement —
  writing `exec 3< "$path" 2>/dev/null || refuse ...` to suppress a
  diagnostic on open failure silently and permanently redirects the
  script's own stderr to `/dev/null` for the rest of its run **on the
  success path too**, since the `2>/dev/null` isn't scoped to the `exec`
  call, it just becomes the shell's new stderr. This produced a real bug
  (a downstream `printf ... >&2` after a successful guarded `exec` open
  went silently missing) that a live invocation caught (empty stderr,
  correct verdict) — the frozen fixture suite's own coverage of that
  stderr line did not, since it happened to grep an ERROR path this
  particular success-path bug never touched. Fix: never attach a trailing
  redirect to a bare `exec` used only to open/close a numbered fd; let a
  failed open print bash's own diagnostic (harmless — no `- check:` line
  or fixture in this repo asserts an EXACT stderr line, only substring
  containment) and catch the failure via `||` on the `exec` itself.
  Before shipping any new bare `exec <N>{<,>} file` fd-management site,
  grep the same file for every OTHER site using the pattern and confirm a
  live run's stderr still carries every message emitted before AND after
  that site — a suite that only asserts "the expected message is present
  somewhere" cannot by itself catch "and every OTHER message after this
  point silently vanished" the way this bug did.
- T-1057: `bash tests/resolve-executor/run.sh` is `bin/resolve-executor.sh`'s
  fixture suite (the T-1057 fail-closed per-role executor resolver). No new
  prerequisite: pure bash + git, but its scratch root is the
  `${TMPDIR:-/tmp}`-only `mktemp -d ... XXXXXX` arm — **no `$HERE` fallback
  arm at all** — because this suite copies an installed tree (`bin/` +
  `templates/`) out of the checkout to mutate a scratch copy, and the
  ancestor-symlink fixtures a sibling suite builds for the identical reason
  would otherwise land inside this repository's own working tree (a nested
  nested-install shape sandboxed runs deny, the same restriction the T-1044
  entry above already documents for a different suite shape). Reaching the
  effort-unsupported and board-transition-not-carried branches requires
  editing a SCRATCH COPY of `templates/adapters/claude-cli.txt` — both
  shipped adapters declare `capability effort supported` and a real
  `carries board-transition` channel, so those branches are unreachable
  against the installed tree as shipped. One authoring trap specific to
  this resolver: its two normative-rule reads (`capability effort
  <supported|unsupported>`, `carries board-transition <channel>`) are done
  with a direct `awk` field read against the bound adapter's own definition
  file, never by delegating to `bin/check-adapter.sh --adapter TOKEN` —
  that mode's own internal-consistency check refuses a definition mutated
  to declare `capability effort unsupported` while its `effort-mechanism`/
  `effort-value` rows are left untouched with a DIFFERENT token
  (`capability-inconsistent`) than the one this resolver's own rule
  requires (`capability-unsupported`), so a fixture built by mutating only
  the one field the rule under test reads is exactly the shape that mode's
  stricter grammar was never meant to validate. Two sibling suites gained
  an ancestor-symlink case in the same round (`bin/check-durability.sh`'s
  and `bin/team-init.sh`'s own `$SCRIPT_DIR/..`-crossing sites, issue #218):
  the fixture model is `tests/check-binding/run.sh`'s
  `cb-ancestor-symlink-registry-ignored` (an `adopter/bin -> $REPO_ROOT/bin`
  directory symlink, plus a decoy in the adopter's own `templates/`, that
  must have zero effect on which shipped file the checker actually reads).
- T-1059: purely a documentation task — no new `bin/` script, no new test suite,
  no workflow edit. The mechanical gates that matter are `bash
  bin/check-acs.sh .shell-team/specs/T-1059-docs-release-notes.md` (all 10
  `check:` lines), `bash bin/check-intent.sh
  .shell-team/specs/T-1059-docs-release-notes.md .shell-team/todo.md`
  (confirms the frozen intent block is untouched), and `bash
  tests/team-init/run.sh` (the one suite that content-asserts the scaffolded
  `AGENTS.md` this task rewrites — it must still match `Codex`
  case-insensitively and carry no `YYYY-MM-DD` date after the rewrite). A
  `## Cutting a release` bullet count is a **base-relative delta**
  (branch-point count + 2), never an absolute literal — re-derive it live
  rather than hardcoding a number, the same discipline the population-count
  entries elsewhere in this file already establish. Observing whether a
  two-space-indented `CHANGELOG.md` sub-bullet (this task's own
  `docs/templates/release-notes-template.md` instructs transcribing it
  verbatim into `## Highlights`) renders as a Markdown list rather than an
  indented code block can be checked without a browser: POST the candidate
  text to `https://api.github.com/markdown` with `{"mode":"gfm","text":
  "<content>"}` and inspect the returned HTML for `<ul><li>` vs `<pre><code>` —
  `api.github.com` is on this environment's network allow-list and needs no
  authentication for this endpoint.
- T-1060: purely a documentation task — no new `bin/` script, no new test suite,
  no workflow edit, no config-grammar or checker change. The mechanical gates
  that matter are `bash bin/check-acs.sh .shell-team/specs/T-1060-adopter-binding-docs.md`
  (11 `check:`-bearing criteria; AC12 is runtime `SKIP` by design, reported
  item by item in the hand-off) and `bash bin/check-intent.sh
  .shell-team/specs/T-1060-adopter-binding-docs.md .shell-team/todo.md`
  (confirms the frozen intent block is untouched). Validating a documented
  grammar example before committing it: write it to a scratch file (not
  `/tmp` directly — this sandbox denies writes there; use `$TMPDIR` or the
  session scratchpad) and run `bash bin/check-binding.sh --config <that
  file>`; exit `0` confirms the example is not merely illustrative but
  actually accepted by the shipped validator. AC1/AC2's fenced-block
  extraction concatenates the content of *every* triple-backtick block in
  the section (not just the first), so a section meant to carry exactly one
  config example must not include a second, unrelated fenced block (e.g. a
  standalone shell-command block) or its `bind`/`schema` line count and
  byte-identity comparisons will pick up unintended lines.
- T-1058: no new CI wiring needed — `bin/log-run.sh`, `bin/check-run.sh` and
  `bin/rollup-runs.sh`, and their three suites (`tests/log-run/run.sh`,
  `tests/check-run/run.sh`, `tests/rollup-runs/run.sh`), were already in
  `.github/workflows/check-handoff.yml`'s shellcheck argument list and each
  already had its own `bash tests/<suite>/run.sh` step, confirmed by
  targeted search before touching anything (this task adds no `bin/` file,
  no test suite, and makes no workflow edit). `bash tests/log-run/run.sh`,
  `bash tests/check-run/run.sh` and `bash tests/rollup-runs/run.sh` run the
  same way as every other suite here: pure bash + coreutils, no
  prerequisite build, `${TMPDIR:-/tmp}` scratch space. One regression trap
  worth recording for the next task that touches `bin/rollup-runs.sh`'s
  stdout shape: `tests/rollup-runs/run.sh`'s pre-existing T-1011 AC30 check
  used to compare `with-events.jsonl`'s roll-up output byte-for-byte
  against the SEPARATELY fixtured `clean.jsonl`'s output — a comparison
  that only worked because `rollup-runs.sh` never printed a row's own
  `seq` anywhere; the two fixtures' span rows carry genuinely different
  `seq` values (1/3/5/7 vs 1/2/3/4). The moment any output line prints
  `seq` (this task's `review: <span>#<seq>=<relation>` line does), that
  comparison must be rewritten to derive the "no events" side from the
  SAME file (`grep -v -- '"kind":"event"' "$FIX/with-events.jsonl"`),
  never from a different fixture — the shape `bin/log-run.sh`'s own
  header and this task's AC5 check already use for the identical
  invariance property.
- T-1061 (corrected round 3, 2026-08-12 — no suite ships): a standalone
  checker (`bin/check-adopter-docs.sh`) and its 42-case suite
  (`tests/check-adopter-docs/run.sh`) were built in rounds 1-2, then reverted
  in round 3 (`git rm` — both remain recoverable from git history at commits
  `b731f44`/`a9459e5`/`62e53aa`) when this task's own pre-commitment trigger
  fired at Codex round 2 (two consecutive rounds of independent Majors
  against the checker's discharge-marker scan). The mechanical gate, all
  three rounds' findings, the fence-tracking probe procedure this entry used
  to document, and the fixed inventories (7 positional requirements, the
  10-token refusal set, the 42-case class inventory) are carried instead as
  fast-follow issue **#250**'s requirement list — nothing under `bin/` or
  `tests/` ships for T-1061, and `.github/workflows/check-handoff.yml` is
  byte-identical to the branch point. The gate itself now ships as two prose
  duties only (`agents/pm-spec.md`'s spec-completion self-check,
  `skills/run/SKILL.md`'s bootstrap-freeze sweep item) plus this task's own
  inline dogfood (AC10) — there is no test recipe to run here until #250
  rebuilds the checker as a state machine over the fence/scope cross-product,
  per the redesign guidance recorded in that issue.
- T-1062 (2026-08-13): a spec's AC7(c)-style "full-population diff" (running
  `bin/check-acs.sh` once per merged spec at a base ref via a detached
  `git worktree add --detach`, and once more per spec at HEAD, then
  differencing every `(spec, AC)` verdict pair) takes real wall-clock time
  once the corpus reaches this size — roughly 45-plus minutes end to end for
  66 base specs plus 67 head specs on this machine, since several specs'
  own `- check:` lines shell out to git and to other suites in turn. Budget
  for it accordingly rather than assuming it finishes inside a single
  interactive command: run the base-side and head-side sweeps as two
  separate background jobs (one `bash bin/check-acs.sh <spec>` per spec,
  appending `<spec>\t<AC-line>` to a shared log file) and poll the log's
  distinct-spec count against the population total rather than polling on a
  fixed sleep, so a slow but still-progressing run is not mistaken for a
  stall. Separately: `bin/check-acs.sh` is not fence-aware — a spec that
  quotes an illustrative example AC inside a fenced code block (as
  `.shell-team/specs/T-1061-adopter-docs-gate.md`'s `## Round-3
  drop-execution package` section does) gets that example's `**AC1**` label
  matched a second time, with its literal `check: ...` placeholder text
  run as if it were a real command (exit 127) — deterministic and identical
  on both sides of any diff, not evidence of flakiness, but it means a
  naive positional pairing of duplicate-labelled rows between two runs can
  produce spurious differences unless the verdicts are paired by matching
  value (not by row order) before comparing.
- T-1064: a delta on the T-1056 and T-1057 entries above, not a restatement
  of them. `bin/check-durability.sh` resolves its registry from its own
  script directory (`$SCRIPT_DIR/..` → `templates/durability-records.txt`)
  and its path resolver from the same directory (`$SCRIPT_DIR/team-paths.sh`),
  failing `structural` on either — so a scratch copy of the checker alone is
  unusable by construction, and the fixture shape is the scratch "install"
  the T-1056 entry above already prescribes for `bin/check-liveness.sh`: the
  script plus `bin/team-paths.sh` under a scratch `bin/`, with
  `templates/durability-records.txt` beside it. The `--records` flag is
  documented in the script's own header as a testing affordance for the
  malformed-registry case; pointing a scratch copy at a real registry with
  it bypasses the resolution path the shipped invocation takes, so it
  proves nothing about the resolver and is not the workaround to reach for.
  The ancestor-symlink property of this same resolver is covered by the
  T-1057 entry above (issue #218) and is not restated here.
- T-1070: measuring `bin/check-handoff.sh`'s own runtime needs three things
  this repo's other suites haven't needed before. **(1)** No `timeout` binary
  resolves on this host by default (matching `bin/check-acs.sh`'s own header)
  — bound a slow pre-fix run yourself; do not assume a runaway command will
  be killed. **(2)** Pin the board being timed to a committed blob (`git show
  <ref>:<path> > scratch`) and read that SAME scratch file from both the
  pre-change and post-change implementation — the board is a live,
  append-only artifact and re-reading the working tree between arms compares
  different bytes without saying so. **(3)** Bash's own `time` reserved word
  (`TIMEFORMAT='%R'` for a bare wall-clock-seconds line) only respects
  `TIMEFORMAT` when the invoking shell is bash itself — the Bash tool in this
  environment runs commands through `zsh`, so a bare `{ time cmd; }` at the
  top level prints zsh's own multi-field format regardless of `TIMEFORMAT`;
  wrap the whole timing block in an explicit `bash -c '...'` (or put it
  inside a `#!/usr/bin/env bash` script and invoke that) to get the `%R`
  format reliably. Obtaining a SECOND bash `<major.minor>` floor beyond this
  host's stock 3.2.57 needed a source build (no bash 5 package is reachable
  within this sandbox's network allow-list, and no prebuilt macOS binary is
  published for one) from `gitGNU/gnu_bash`'s GitHub mirror (`bash-4.4` tag —
  that mirror carries no tag past 4.4), configured with
  `CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int"`
  (recent clang treats an implicit function declaration in this 1990s-era C
  source as a hard error by default) and built entirely under an isolated
  scratch prefix, never installed onto `PATH` or the host package manager.
- T-1071: `bash tests/derive-populations/run.sh` is `bin/derive-populations.sh`'s
  fixture suite (the set-derivation helper). No new prerequisite: pure bash +
  coreutils + POSIX awk, the standard `mktemp "${TMPDIR:-/tmp}/…XXXXXX"`
  scratch idiom, and committed fixtures under
  `tests/derive-populations/fixtures/` rather than runtime generation (the
  `tests/check-pii-shapes/run.sh` runtime-generation pattern exists solely
  because no PII-shaped byte may enter this tree; no such constraint applies
  to population listings). `tests/derive-populations/fixtures/control-char.txt`
  carries a literal embedded carriage-return byte (built with `printf 'p\rq\n'
  > …`, never a shell-escape stand-in inside a fixture-building `--set`
  value) — read it with `od -c`, not `cat`, when inspecting it, since a
  plain `cat` on this host renders the embedded CR as an in-place cursor
  return rather than visible text. The helper forces `export LC_ALL=C` as
  one of its own first lines, which reaches every `--set` command's own
  child processes too (not just this script's own sort/comm/awk calls) —
  a dogfood command that shells out to something locale-sensitive runs
  under the pinned collation regardless of the invoking shell's ambient
  locale. `docs/loop-engineering/record-set-derivation.md` carries this
  task's own dogfooded derivations and is regenerated by re-running its
  `- reproduce:` lines from the repository root, never hand-edited.
- T-1073: no new `bin/` script, no new test suite — purely an assembled note plus
  records (`- verification-class: no-mechanism`). The **probe procedure** (an
  orchestrator-only step, since no `agents/*.md` `tools:` line carries an `Agent`/
  `Task` token — the engineer holds no Agent tool and cannot re-run it): a throwaway
  `git clone --no-hardlinks` under `$TMPDIR`, pinned to the branch point, never a
  `git worktree add` (the same venue bar `docs/loop-engineering/phase-multiplexing.md`
  already uses); the population is fixed by timing a few real candidate specs singly,
  *before* any concurrent arm runs, choosing the one whose duration clears both a
  ≥3× launch-latency margin and stays under the watchdog's own stall threshold;
  every watchdog launches as a harness-tracked background Bash (`run_in_background`)
  — a bare shell `&` inside a foreground Bash tool call dies the instant that call
  exits (measured, T-1073); a sub-agent's own foreground Bash tool call defaults to
  a 120-second timeout, so any unit expected to run longer needs an explicit timeout
  parameter passed to that call or the harness auto-backgrounds it (disclosed
  wait-loop granularity on the affected report). **QA verifies the committed probe
  evidence** the same way **AC2**'s own `- check:` line does: `git show
  <probe-evidence-sha>:docs/loop-engineering/harness-agent-concurrency.md` extracted
  to a scratch file, the `## Probe evidence (raw, orchestrator-produced)` section
  sliced out of both that extraction and the working tree via the identical `awk`
  boundary (`/^## Probe evidence \(raw, orchestrator-produced\)$/{f=1;next}
  f&&/^## /{exit} f`), then `cmp -s` between the two slices — never a whole-file
  `diff`, since only that one section is byte-locked. `CHECK_ACS_TIMEOUT` needs
  raising above the 120 s default for this spec's full sweep (this task used 300,
  per the spec's own Notes for engineer) because **AC13** runs five checkers
  including `check-handoff.sh` over the real board. Numeric criteria in this spec
  compare 19-digit epoch-nanosecond values via `$(( 10#$v ))` bash arithmetic —
  never `awk`/`sort -n` (a double cannot hold them exactly), the same discipline
  T-1069/T-1071/T-1072 already established; do not "simplify" a reproduction of one
  of these comparisons into a form that reaches for either.
- T-1072: no new environment procedure — reuses T-1071's
  `bin/derive-populations.sh` dogfood pattern (a single `- reproduce:` line
  in `docs/loop-engineering/telemetry-span-discriminator.md`, regenerated
  from the repository root, never hand-edited) to derive the
  `SPAN_ONLY_FLAGS`/`SPAN_ONLY_KEYS` set-equality claim instead of asserting
  it by eye. `bin/check-run.sh --line` and `bash tests/is-span-row-parity/run.sh`
  need no prerequisite build beyond what earlier entries in this file already
  document. As with T-1070/T-1071, `CHECK_ACS_TIMEOUT` needs raising above
  the 120s default for this spec's full sweep (this task used 400) because
  **AC6** lints the full local telemetry corpus under two separate linter
  blobs and **AC14** runs four test suites in the same check.
- T-1076: **a real, measured performance ceiling in `bin/check-run.sh` that
  the next task touching this writer, its readers, or its contention fixture
  needs to inherit rather than re-discover.** Its unbalanced-quote detection
  (`unq="${line//\\\\/}"; unq="${unq//\\\"/}"; quotes="${unq//[!\"]/}"`,
  lines 205-207) is a chained bash global pattern-substitution over the
  WHOLE line, and this repo's own stock dev-host bash (3.2.57, macOS) is
  measured to run each stage with severe super-quadratic cost whenever the
  substitution removes a large fraction of a long string — direct isolated
  benchmarks of that exact chain: 500B→0.03s, 1000B→0.13s, 2000B→0.82s,
  4000B→5.7s (third stage dominant) / 8000B→20s (second stage dominant,
  tested separately with an all-`\"`-pair payload), 16384B→did not complete
  within 120s. The determining factor is how much of the string actually
  gets REMOVED at each stage, not its content otherwise — an all-quote
  payload is fast at the third stage but slow at the second, and vice
  versa, so no payload composition avoids the ceiling once a JSON string
  field passes a few KB. This is why `tests/log-run/run.sh`'s T-1076
  contention suite splits its two arms: the AC9 positive/main 8x20 case
  carries NO `--error` payload (kept fast and lintable — its file is the
  one `bin/check-run.sh` actually runs against for the
  `contention-check-run-clean` assertion), while the AC10 negative control
  alone carries the 16384-byte floor D6 requires, built as a scratch copy
  under `$TMPDIR` with NO sibling `check-run.sh` (so the writer's own
  post-write self-check silently skips, per its documented
  missing-checker behavior) and judged only by cheap measurements (line
  count, derived seq-set exactness) that never invoke `bin/check-run.sh`.
  Whoever next touches `bin/check-run.sh` itself should re-measure this
  ceiling before assuming it moved. Separately: `bin/log-run.sh`'s own
  `jesc()` (backslash/quote escaping) does NOT hit this ceiling for the
  same payload sizes, because its two substitutions have near-zero matches
  against a payload containing neither backslash nor quote characters
  (measured: an all-`x` 16000-byte string through the equivalent
  substitution shape completes in ~0.006s) — the slow path is specific to
  `bin/check-run.sh`'s quote-BALANCE check, not to string escaping in
  general.
- T-1076: retry granularity for the append lock's bounded wait is
  whole-second (`sleep 1`), a deliberate choice (D2 leaves either option
  open) rather than a portability necessity — fractional `sleep 0.2` is
  measured to work on this session's own sandboxed bash 3.2.57, but whole
  seconds need no per-host verification and comfortably satisfy every
  acceptance criterion's own timing bound (AC6's `TEAM_LOG_LOCK_TIMEOUT=1`
  case returns in ~1s, well inside its 10s ceiling).
- T-1076: `tests/log-run/run.sh`'s full contention suite (positive arm,
  D2-refusal case, signal-release case, AC10 negative control) measured
  **~167s wall-clock** end to end on this host
  (`bash tests/log-run/run.sh`, timed twice, both ~167s and both exiting
  0) — almost entirely the negative control's 160 real `bash
  bin/log-run.sh`-equivalent process launches with a 16KB argv payload
  each. This is well past a sub-agent's own default 120s foreground Bash
  tool timeout: invoke it with an explicit longer timeout (or as a
  backgrounded command polled for completion) rather than assuming a hang
  when nothing prints for two minutes. `CHECK_ACS_TIMEOUT=400` was used
  for this spec's full `bin/check-acs.sh` sweep (**AC9** and **AC10** each
  run the whole suite once, back to back, so budget at least
  2×167s ≈ 340s for those two criteria alone before any of the spec's
  other checks run).
- T-1076 round 2 (rework, Codex review round 1): the suite grew three cases
  (`seq-auto-escaping`, `signal-race-acquire-side`, `signal-race-release-side`
  — the Major #1 and Blocker regression pins) and now measures
  **~189s wall-clock** end to end on this host (`bash tests/log-run/run.sh`,
  timed, exit 0) — up from round 1's ~167s, almost entirely the two new
  signal-race cases' own deliberate multi-second `sleep`-widened windows
  (each choreography holds a lock for several seconds on purpose so a real
  `kill -TERM` can be aimed inside it deterministically). Re-budget
  `CHECK_ACS_TIMEOUT` accordingly (this round used 400, still comfortable).
  A bash-3.2.57-specific pitfall found and worked around while building
  these fixtures: `${content//"$pat"/"$rep"}` — quoting BOTH the pattern
  and the replacement — either leaks literal `"` characters into the
  replacement text or, for a multi-line pattern spanning this script's own
  ~600-line body, hangs outright (this repo's own super-quadratic
  string-substitution ceiling, recorded above for `bin/check-run.sh`,
  generalizes to bash's own glob engine here too). The working fixture
  technique is line-range replacement via `awk` keyed on unique anchor
  lines (`$0 == start` / `$0 == end`, both verified unique with
  `grep -cFx` before use), not a bash pattern substitution — fast and
  correct regardless of content size, and the technique to reach for
  first the next time a test needs to patch a specific span inside an
  existing `bin/` script rather than a single line.
- T-1076 round 3 (bounded rework, Codex review round 2 — Blocker + Major +
  Minor, all in test/diagnostic code): three fixes.
  1. **`signal-race-release-side` (Blocker) — the fixture's own kill was
     scheduling-dependent.** Round 2's choreography sent `kill -TERM` to P1
     the instant P1's own post-rmdir marker appeared, then polled (up to
     5x1s) for the successor P2 to have reacquired the freed lock —
     AFTER the kill, so it could not retroactively fix the ordering.
     Fixed by building a DEDICATED P2 mutant that writes its own
     `.p2-acquired-marker` the instant its own `mkdir` succeeds, and
     moving the wait for THAT marker to BEFORE the kill. This required
     widening both mutants' injected vulnerability window (`sleep 3` →
     `sleep 8` in the two P1 mutants) so the added pre-kill poll fits
     inside it, and widening P2's own post-acquire hold (`sleep 5` →
     `sleep 12`, in the new dedicated P2 mutant only) so the FIXED-shape
     arm's "successor's lock must still be there" check is never read
     against a P2 that already finished its own lifecycle for an
     unrelated, benign reason (P1's fixed-shape arm does not return until
     it has run its own full masked window to completion). Verified with
     a standalone extraction driver (replays this file's own
     `replace_range`/`ACQ_START`/`ACQ_END`/release-side block, keyed on
     unique anchor lines, in a loop — the same technique round 2 recorded
     above, reused rather than reinvented) run 5 consecutive times:
     `grep -c '^PASS: T-1076 signal-race-release-side' <log>` = **5**,
     `grep -c '^=== iteration' <log>` = **5**, no flake. Each iteration now
     takes noticeably longer (~30-35s, up from round 2's much shorter
     per-arm time) because of the widened windows and P2's longer hold —
     wall-clock cost this round's engineer paid deliberately for
     determinism, not a regression to chase.
  2. **AC10 negative control (Major) — disclosed rather than
     barrier-forced.** No explicit synchronization barrier was added
     (would require pausing the lock-disabled mutant's own
     compute-then-append critical section on a shared rendezvous —
     restructuring the very TOCTOU mechanism this arm exists to observe,
     out of this bounded rework's scope). Instead, the arm's actual
     (empirical, not structurally forced) guarantee is disclosed in a
     test comment: with CONT_N (>=8) writers each performing CONT_M
     (>=20) fully-unserialized cycles against one shared file (>=160
     total appends, zero serialization in the mutant), at least one
     collision is empirically near-certain, not certain by construction.
     Verified with the same standalone-driver technique, run 5
     consecutive times: `grep -c '^PASS: T-1076 negative-control —
     detected' <log>` = **5**, `grep -c '^=== iteration' <log>` = **5**,
     every run `detected — seq-set-mismatch`, no `not-detected` observed.
     Each iteration of JUST this arm alone (isolated from the rest of the
     suite, no parallelism benefit from the other ~40 earlier test cases
     that would otherwise share the host's idle time) took on the order
     of several minutes on this shared, contended sandbox host — the
     dominant cost is still `compute_auto_seq`'s O(file) bash-native
     `while read` scan re-run on every one of the 160 total appends
     against a file that grows to ~2.5MB (160 rows x ~16KB `--error`
     payload each), unchanged from round 2. Budget accordingly: running
     this arm's 5x tally in isolation is markedly slower per-iteration
     than its share of the full suite's own ~189s total (where it runs
     once, and other tests' CPU-idle windows do not compound the way five
     back-to-back isolated runs do on a busy shared host).
  3. **`lock_mtime` (Minor) — the BSD-form probe silently "succeeded" with
     garbage on GNU/Linux.** Fixed by probing the dialect itself
     (`stat --version` succeeds on GNU coreutils, fails on BSD/macOS
     `stat`) and running ONLY that dialect's own format string, instead of
     trying the BSD form first and falling through to the GNU form on a
     non-zero exit (GNU's `-f '%Sm'` is a syntactically valid, if
     nonsensical, format string on GNU `stat`, so the old fallthrough
     never triggered there). Verified on this host: `stat --version`
     exits 1 with `illegal option -- -` (confirming the BSD branch is the
     one actually selected here), and a manual invocation against a real
     lock directory produced a legible timestamp, not `unknown` or
     garbage. Honest bound, unchanged from the review finding itself:
     only the BSD branch is exercised from this repo's own dev host — the
     GNU branch is written from GNU `stat`'s documented behaviour and is
     NOT independently verified against a live GNU/Linux host from here.
     **Mutation self-check finding on the new `lock-mtime-legible` test
     itself, worth remembering for anyone else writing a "does this look
     like a real timestamp" guard**: a first draft asserted only
     `grep -qE '[0-9]{4}'` (a bare four-digit check). Feeding it the exact
     garbled value this round's own finding named (`4096m`) — the mutant a
     real GNU-dialect bug would actually produce — WRONGLY PASSED, because
     `4096` alone is four digits. A digit-count check does not verify
     "looks like a timestamp"; it verifies "contains some four-digit
     number," which a filesystem block size satisfies just as well.
     Strengthened to require the recognizable SHAPE (a three-letter month
     abbreviation, an `HH:MM:SS` time, a trailing plausible year), which
     both `4096m` and a plain `unknown` correctly fail.
  A reusable technique recorded for the next task that needs to
  iterate quickly on one expensive arm of an already-slow suite:
  extract just that arm's own code (plus whatever earlier variable/
  function definitions it depends on) out of the suite file with
  `sed -n '/START-ANCHOR/,/END-ANCHOR/p'` into a small driver script that
  `eval`s it in a loop with a fresh scratch root each iteration — far
  faster to iterate on than re-running the whole ~189s suite for every
  probe, and the anchors stay in sync with the real file since they are
  read from it live rather than copied.
- T-1076 round 4 (surgical rework, Codex review round 3 — Blocker + Major +
  Minor): three fixes, all confined to `tests/log-run/run.sh` (no
  production-code change this round — `bin/log-run.sh`'s own `lock_mtime`
  was re-read and confirmed correct; the defect was entirely in the test's
  own assertions).
  1. **`lock-mtime-legible` (Blocker) — the round-3 assertions were
     BSD-shape-only and would fail deterministically on this repo's own
     `ubuntu-latest` CI (GNU `stat -c '%y'`).** Round 3's own "disclosed as
     unverified" bound on the GNU branch is exactly what let this Blocker
     through, so this round closes the gap by EXECUTING the GNU branch,
     not by disclosing it more carefully a second time. Fixed two ways:
     (a) rewrote the three round-3 assertions (month name, HH:MM:SS,
     year-anchored-to-tail) into a platform-agnostic pair — an
     HH:MM:SS-shaped time anywhere in the string, AND a plausible
     `(19|20)[0-9]{2}` year anywhere in the string, neither anchored to
     either end — verified to hold for both BSD's default format (`Jan 15
     10:30:45 2024`) and GNU's documented format
     (`2024-01-15 10:30:45.123456789 +0000`), and to still reject all four
     garbled values this test exists to catch (`4096m`, `unknown`,
     `4096manual`, `Aug 4096` — none has a colon-separated time, so all
     four fail the time check alone) via a dedicated negative-literal loop
     run before the real-host assertion. (b) built a PATH-prepended fake
     `stat` (answers `--version` so `lock_mtime`'s own dialect probe
     selects the GNU branch, `-c '%y'` with a realistic GNU byte string,
     refuses `-f` outright) and ran the REAL `lock_mtime` function —
     extracted from `bin/log-run.sh` with `sed -n
     '/^lock_mtime() {$/,/^}$/p'`, the same unique-anchor technique this
     file already uses elsewhere, not a reimplementation — against that
     stub, live, on this session's own macOS host. Stub run's actual
     output, captured this session: `2024-03-07 10:15:42.123456789
     +0000`, printed via `PASS: T-1076 lock-mtime-legible (GNU stub) —
     lock_mtime selects the GNU branch against a fake GNU stat and
     returns '2024-03-07 10:15:42.123456789 +0000', which the
     platform-agnostic check pair accepts` — an executed positive
     control, not another round of reasoning about a documented format
     string.
  2. **`signal-race-release-side` (Major) — the reworked choreography's
     ordering was already deterministic (round 3's own fix), but the
     `sleep 8` (both P1 mutants) / `sleep 12` (the dedicated P2 mutant)
     widths remained fixed wall-clock BUDGETS: exhausted under enough CI
     contention, either could let a mutant complete its own lifecycle and
     return before the driver even sent — or benefited from — the kill,
     flipping the verdict on scheduling grounds. This is the third
     consecutive round this exact fixture family drew a scheduling-timing
     finding, which the review itself reads as a signal about the
     fixed-sleep-margin PATTERN, not about any one width. Removed the
     load-bearing widths entirely: `REL_OLD_REPL`/`REL_FIXED_REPL` now
     wait on an explicit `${LOCK_DIR}.rel-proceed-marker` file the test
     driver writes (gated so it is only ever written for the
     `expect_rc=0` FIXED-shape call — OLD-shape's kill is delivered
     essentially instantly since its traps stay unmasked, so it never
     needs or waits on this marker), and the dedicated P2 mutant
     (`REL_P2_BIN`) now waits on `${LOCK_DIR}.p2-proceed-marker`, written
     by the driver only after the "successor survives" check has already
     run. Both waits carry a `-lt 60` iteration cap as a pure anti-hang
     backstop (a test bug that never sends the kill or writes the marker
     should eventually fail loudly rather than hang the suite forever) —
     it is NOT sized to budget any correctness-relevant transition, unlike
     the widths it replaces. Verified with a standalone extraction driver
     (the same technique round 3 recorded, reused rather than reinvented:
     `replace_range`, `ACQ_START`/`ACQ_END`, the release-side block, all
     replayed from the real file's own anchors) run 5 consecutive times:
     `grep -c '^=== iteration' <log>` = **5**, `grep -c '^PASS: T-1076
     signal-race-release-side' <log>` = **5**, `grep -c '^FAIL:' <log>` =
     **0** — no flake, both the OLD-shape theft arm and the FIXED-shape
     absorb arm passing on every run. Per-iteration wall time (this driver
     also runs the unrelated `signal-race-acquire-side` case in the same
     pass): 5 iterations totaled ~7 minutes on this shared, contended
     sandbox host (~82s/iteration average) — measured once in isolation
     (release-side only, no acquire-side): a single run took 69s. Neither
     number is directly comparable to round 3's own recorded ~30-35s
     figure (different isolation scope, different host-contention sample
     at measurement time); recorded here as this round's own honest
     measurement, not a claimed improvement or regression.
  3. **AC10 disclosure comment (Minor) — wording only.** Removed
     "guarantees" and "near-certain... on any real multi-core host" (an
     unqualified universal claim from a sample of runs on one host);
     restated as the measured evidence only (`detected` observed in every
     recorded run of this arm across this task's full history, not
     established for any other host or scheduler), and reframed the
     omitted synchronization barrier as a scope choice for this bounded
     rework rather than a technical necessity. No change to the test's
     actual behavior or pass/fail outcome.
  Full-suite re-verification this round: `bash tests/log-run/run.sh` run
  once, live, this session — see this task's own hand-off for the exact
  PASS/FAIL tally command and result; budget the same `CHECK_ACS_TIMEOUT`
  window recorded above (this round did not reduce the suite's own
  worst-case wall-clock ceiling, since AC9/AC10 each still run the whole
  suite once).

- T-1076 rework round 5 (operator-ratified design-premise change, board
  record `d726e80`, "b GO"): retired the OLD-shape reproduction machinery
  from `signal-race-acquire-side` and `signal-race-release-side` — the
  mutant construction, its A/B assertions, and (release-side) the
  re-entrant-release choreography that itself generated round 4's
  finding — after this exact fixture family drew an independent
  timing-adjacent Blocker or Major finding in four consecutive review
  rounds. Kept the FIXED-shape determinism tests (the shipped code,
  driven through the same choreography, absorbing a real `kill -TERM`
  cleanly: lock released, exactly one row from the killed holder rather
  than a duplicate, successor's lock left untouched, lock reusable), and
  added a new grep-level regression test, `signal-mask-shape-pin`, as the
  fixture family's ongoing regression protection — see
  `.shell-team/provenance/T-1076.md`'s two round-5 decision entries for
  the full rationale and the mutation self-check.

  **Correction (round 4's own finding, this round):** round 4's own entry
  immediately above states, of the `-lt 60` marker-wait backstop, that it
  "is NOT sized to budget any correctness-relevant transition" and that
  "OLD-shape's kill is delivered essentially instantly since its traps
  stay unmasked, so it never needs or waits on this marker." Both claims
  are FALSE for the OLD-shape arm specifically, per round 4's own review
  (`.shell-team/reviews/T-1076.md`, appended at `17ee49f`): the OLD-shape
  arm's re-entrant `release_lock()` call also waited on
  `rel-proceed-marker` (a marker the driver deliberately never wrote for
  that arm), so the killed OLD-shape holder in fact exited only once the
  60-iteration backstop fired — an unconditional ~60s stall, and a very
  real correctness-relevant-to-the-test-itself transition the backstop
  was budgeting. This entry corrects both claims rather than editing the
  round-4 prose above (this section is an append-only log; the round-4
  entry is left standing as a historical record of what round 4 shipped
  and believed at the time). The retirement above removes the OLD-shape
  arm entirely, so neither claim describes any code that still exists
  after this round; the surviving FIXED-shape arm was never subject to
  either claim — its own `p1proceed` marker is always written
  immediately after the kill, by design, so its own 60-iteration backstop
  genuinely never fires in a healthy run.

  **Measured consequence:** `bash tests/log-run/run.sh`, run twice this
  round (own `date +%s` bracket each time) — pre-commit: `exit=0
  elapsed=164s`; post-commit, final/authoritative: `exit=0 elapsed=162s` —
  down from round 4's own recorded `elapsed=227s`, a ~65s reduction,
  consistent with the ~60s unconditional stall this round removes
  together with the retired arm's own remaining setup/comparison steps. `grep -c '^PASS:' <log>` =
  **38** (37 round-4 tokens, unchanged for `signal-race-acquire-side` and
  `signal-race-release-side` — each still emits exactly ONE `PASS:` token,
  same as before the retirement, since retiring the OLD-shape arm removed
  setup/comparison code but not either case's own single pass banner —
  plus 1 new token for `signal-mask-shape-pin`), `grep -c '^PASS: T-1076'
  <log>` = **16**, `grep -c '^FAIL:' <log>` = **0**.

  The two retained signal-mask tests plus the new shape pin were also run
  5 consecutive times each, isolated from the rest of the suite, via a
  standalone extraction driver replaying `tests/log-run/run.sh`'s own
  lines 644-936 (the retained/rewritten block) against a fresh harness:
  `grep -c '^=== iteration' <driver-log>` = **5**,
  `grep -c '^PASS: T-1076 signal-race-acquire-side' <driver-log>` = **5**,
  `grep -c '^PASS: T-1076 signal-race-release-side' <driver-log>` = **5**,
  `grep -c '^PASS: T-1076 signal-mask-shape-pin' <driver-log>` = **5**,
  `grep -c '^FAIL:' <driver-log>` = **0** — no flake.

  Mutation self-check on the new `signal-mask-shape-pin` test (both
  mutants built under `$TMPDIR`, never the working tree): a mask-stripped
  mutant (`grep -v` removing both `  trap '' INT TERM` lines from a
  scratch copy of `bin/log-run.sh`) makes the pin fail with "expected
  exactly 2 masked transitions... found 0"; an exit-stripped mutant
  (replacing `on_lock_signal`'s `exit "$2"` with a no-op) makes the pin
  fail with "must call exit explicitly" — both confirmed by direct
  execution this round, against the real pin logic extracted from the
  committed test file, not reasoned about.

- T-1076 rework round 6 (bounded fix, Codex review round 5 Major —
  `signal-mask-shape-pin` pinned counts only, never ORDER): strengthened the
  pin to also assert the RELATIVE LINE ORDER of each critical section's
  load-bearing statements, not just their occurrence counts. Technique:
  extract each critical section's own body first (the acquire loop via
  `sed -n '/^while :; do$/,/^done$/p'`, `release_lock`'s own body via the
  same anchor pattern already used for `on_lock_signal`'s extraction), then
  locate each statement's line NUMBER within that small extracted body with
  a `smp_line_of` helper (`grep -nF` + `head -1` + `cut -d: -f1`,
  `|| true`-guarded the same way the file's existing count checks already
  are under `set -euo pipefail`), and assert `mask < mkdir < flag=1 <
  re-arm` (acquire) / `mask < flag=0 < rmdir < re-arm` (release) as plain
  integer `-lt` comparisons. Extracting the body FIRST (rather than
  searching the whole 685-line file) is what makes an unqualified
  first-match lookup safe — within each extracted body every pattern
  occurs exactly once.

  One collision found and fixed by this round's own mutation self-check,
  before the entry was written: the initial `LOCK_ACQUIRED=1` search
  pattern (no leading whitespace) also matched a COMMENT line inside the
  acquire loop's body (`bin/log-run.sh:627`, prose describing the very race
  being guarded against, which happens to quote `` `LOCK_ACQUIRED=1` ``
  verbatim) — sitting BEFORE the real statement, this made the order check
  falsely FAIL against the real, correct, committed code. Fixed by
  anchoring to the real statement's exact 4-space indentation
  (`'    LOCK_ACQUIRED=1'`), which the `#`-prefixed comment line never
  carries. Lesson for the next task reaching for this same
  extract-a-body-then-grep-within-it idiom: a plain, unanchored fixed-string
  search inside an extracted body is only as safe as that body's own
  freedom from comment lines that happen to quote the same token — check
  for that collision explicitly rather than assuming it away.

  Mutation self-check, three mutants, all built under `$TMPDIR`/scratch,
  never the working tree, each verified via a standalone driver replaying
  `tests/log-run/run.sh:906-996` (the whole `signal-mask-shape-pin` case)
  against the mutant path:
  - mask-stripped (round-5 mutant, re-confirmed): `grep -v` removing both
    `  trap '' INT TERM` lines -> pin fails with "expected exactly 2 masked
    transitions... found 0".
  - exit-stripped (round-5 mutant, re-confirmed): `on_lock_signal`'s
    `exit "$2"` replaced with a no-op -> pin fails with "must call exit
    explicitly".
  - reorder (NEW this round, the exact class the finding named): the
    acquire-side `  trap '' INT TERM` line moved to directly after
    `LOCK_ACQUIRED=1` (same total line count as the real file, same total
    mask-line count of 2 — order broken, not count broken), built via a
    state-tracked `awk` script (a `past_while` flag is required to
    distinguish the acquire-side mask from `release_lock`'s own mask, which
    appears EARLIER in the file when scanning top-to-bottom — a first
    unguarded attempt, without this flag, stripped the wrong mask instead).
    `diff` against the real file confirmed exactly one line moved and
    nothing else changed. Pin fails with "acquire-side order violated — the
    INT/TERM mask (relative line 9) must precede the mkdir acquire attempt
    (relative line 7)".
  All three mutants FAILED the strengthened pin (own command:
  `bash "$SCRATCH/pin_driver.sh" "$SCRATCH/mutants/<name>.sh"`, exit=1
  each, each with the message above); the real, committed
  `bin/log-run.sh` PASSES the same driver (exit=0). `bin/log-run.sh` itself
  is byte-unchanged this round (`git diff --stat -- bin/log-run.sh` empty).

  **Measured consequence:** `bash tests/log-run/run.sh` run once live, this
  round: `exit=0 elapsed=159s` (own `date +%s` bracket), consistent with
  round 5's own ~162-164s measurements (the strengthened pin adds only a
  handful of `grep`/`sed` calls, no new mutant construction, so no
  meaningful wall-clock change). `grep -c '^PASS:' <log>` = **38** (unchanged
  — the strengthened checks live inside the SAME `signal-mask-shape-pin`
  test/pass banner, no new PASS token added), `grep -c '^PASS: T-1076'
  <log>` = **16** (unchanged), `grep -c '^FAIL:' <log>` = **0**.
- T-1075: no new `bin/` script, no new test suite, and no shellcheck
  surface (`git diff --stat feature/1074-fanout-orchestration...HEAD --
  bin/ tests/ .github/` empty). This task's own full-population
  `## Blast radius` sweep (80 `.shell-team/specs/*.md` files, base ref via
  a disposable `git worktree add --detach`, head against the working
  tree) took long enough on this machine that six-way parallel
  `bin/check-acs.sh` invocations per side (population split into six
  ~12-spec chunks, each side's six workers run concurrently) were needed
  to finish in a practical wall-clock time; a single serial pass over 80
  specs did not complete inside two ~10-minute polling windows and was
  abandoned mid-sweep in favour of the chunked approach — the earlier
  T-1073 test-recipe entry's ten-plus-minutes-per-side estimate (for the
  79-spec T-1074 sweep) understates the cost once the corpus reaches 80
  specs and several of them run whole fixture suites inside their own
  `- check:` lines (T-1074's own AC17, T-1076's AC9/AC14). `bin/check-acs.sh`
  only reads the single spec path it is given and writes only to `mktemp`
  scratch directories, so running six instances concurrently against the
  same read-only scratch worktree (base side) or the same working tree
  (head side) is safe — verified after the fact via a per-spec
  verdict-line-count join across the combined output
  (`join -j 2 -o 1.2,1.1,2.1 <(awk -F'\t' '{c[$1]++} END{for(s in c)
  print c[s], s}' base.tsv | sort -k2) <(… head.tsv …) | awk '{if ($2 !=
  $3) print}'`, empty — no spec's line count drifted between runs).
  Two population entries, `design-note-T-1012.md` and
  `T-1020-supersede-adjudication.md`, are not specs with acceptance
  criteria at all (`bin/check-acs.sh` reports
  `no acceptance criteria (- [ ] **ACn** / **AC-N**) found` for both,
  identically on base and head) — expected, not a sweep defect.
- T-1077: `bash tests/land-worktree/run.sh` measured wall-clock, this host,
  this session: `elapsed=17s` (own `date +%s` bracket, one live run;
  `grep -c '^PASS:' <log>` = **34**, `grep -c '^FAIL:' <log>` = **0**) —
  comfortably inside a `CHECK_ACS_TIMEOUT` of **300**, the value this task's
  own `bash bin/check-acs.sh` run used (AC2/AC3/AC5/AC10 each run the whole
  suite, or a whole sibling suite, inside one `- check:` line). Host: macOS,
  bash 3.2.57, git 2.53.0. Fractional `sleep 0.1` measured to work on this
  host (used only by the suite's own two test-only rendezvous seams — the
  `ref-moved` and `lock-released-on-signal` fixtures — never by the shipped
  coordinator's own lock retry loop, which keeps T-1076's whole-second
  `sleep 1` for portability toward an unknown adopter host, per this task's
  own provenance record). Git-config pinning: this suite does not pin an
  ambient config file the way `tests/rollup-track/run.sh` pins
  `core.excludesFile`, because none of `bin/land-worktree.sh`'s own git
  invocations read a config value that could silently change its behavior —
  every diff/ls-tree call passes `--no-renames`/`-z` explicitly (a CLI flag
  always overrides its matching config key in git, by git's own documented
  precedence; there is no "config could silently win" case to guard here
  the way an unpinned `core.excludesFile` genuinely could for a
  `check-ignore` call), and `core.quotepath` — the one setting D7 itself
  names as a real question — is exercised BOTH ways
  (`overlap-quotepath-independent`, one throwaway repo configured
  `core.quotepath=true` and a second configured `core.quotepath=false`)
  and confirmed to make no difference to the tool's own overlap
  detection, which is this suite's version of the paired-control-proves-
  the-pinning-has-teeth discipline: proving the ONE ambient setting that
  could matter here does not, rather than pinning settings that cannot.
- T-1078: `CHECK_ACS_TIMEOUT=120` is sufficient for
  `T-1078-tier3-pilot.md` itself (spec preamble's own stated value; no
  raise beyond that needed). `CHECK_ACS_TIMEOUT=300` was needed for the
  five older, heavier merged specs this task's own Blast radius exercise
  re-ran in full at both the branch point and HEAD
  (`T-1069-phase-multiplexing.md`, `T-1073-harness-agent-concurrency.md`,
  `T-1074-fanout-orchestration.md`,
  `T-1075-fanout-adoption-versioning.md`,
  `T-1077-worktree-reconcile.md`); `T-1077`'s own full suite alone took
  long enough to need a dedicated single, longer-timeout invocation
  rather than sharing a 2-minute parallel batch with the other four. A
  later task doing the same kind of base-vs-head re-run for a merged
  spec that reads this note should expect the same 300s floor, not
  120s. **A `git worktree add --detach <path> <ref>` scratch clone does
  not carry the gitignored runs corpus** (`.shell-team/runs/*.jsonl`):
  any criterion reading that corpus (e.g. T-1076's own **AC15**) reads
  `not-met`/FAIL in a scratch worktree even when it is `met`/PASS in the
  long-lived checkout, which is a measurement artefact of the worktree
  itself, not a regression — already documented once in
  `T-1075-fanout-adoption-versioning.md`'s own Blast radius entry above,
  and reproduced identically here; a later task differencing base vs
  head via a scratch worktree should expect and disclose this same
  artefact rather than chase it as a real flip.
- T-1079: `CHECK_ACS_TIMEOUT=120` is sufficient for
  `T-1079-tier2-judge.md` itself (spec preamble's own stated value; the
  heaviest commands are `bin/check-pii-shapes.sh --base` and
  `bin/check-intent.sh`, no full fixture suite runs, no other spec's own
  full suite is re-run — this task's declared `- verification-class:
  no-mechanism` prices the Blast radius at read-set scope, not a
  full-population re-run). One authoring trap worth recording for a
  future task adding a new `- judge-*: `/`- cost-input: `-style label
  family with a literal-text requirement (a `tie-break`, a bounded
  mechanism name, a phase-position phrase): a bolded Markdown span
  (`**Tie-break, ...**`) capitalizing the FIRST letter of a literal a
  `grep -qF` check requires in its exact-case form defeats that check
  silently — `grep -qF` is case-sensitive under `LC_ALL=C`, and
  "Tie-break" does not match a check requiring the substring
  `tie-break`. Confirmed live: writing the section heading as
  "**Tie-break, stated once...**" left `check-acs.sh`'s AC3 FAILED
  (`grep -qF -- 'tie-break' "$T/sec"` found nothing); the fix was to
  keep the literal lowercase token verbatim inside the prose
  (`` `tie-break` ``) rather than relying on a capitalized natural-language
  heading to satisfy a case-sensitive literal check.
- T-1080: `CHECK_ACS_TIMEOUT=120` is sufficient for
  `T-1080-depth-axis-contract.md` itself (no full fixture suite runs beyond
  `tests/loop-guard/run.sh`, the one bounded exception this task's own
  `- verification-class: no-mechanism` licenses; the heaviest commands are
  `bin/check-pii-shapes.sh --base` and `bin/check-handoff.sh`).
  `CHECK_ACS_TIMEOUT=100`–`120` was also sufficient for every merged spec
  this task's `## Blast radius` read-set sweep re-ran (T-1068, T-1069,
  T-1072 through T-1079, T-1001, T-1041). Two traps worth recording for a
  future task that adds a lowercase-literal-and-capitalized-heading pair
  in the same section (e.g. a body heading `**Indirection, ...**` next to a
  `- check:` that greps a lowercase word from that same heading's own
  vocabulary): `grep -qF` is case-sensitive, and a heading capitalized for
  readability does not satisfy a check requiring the lowercase substring —
  confirmed live, this task's own `## Blast radius`'s `**Indirection, named
  and discharged.**` paragraph did not itself contain the lowercase
  substring `indirection` anywhere, only the capitalized word, and
  `check-acs.sh`'s **AC18** FAILED until a lowercase occurrence was added
  inline in that same paragraph's prose. Second, this task's own three
  `git status --porcelain -- bin/ tests/` working-tree-subject clauses in
  three *other*, already-merged specs (`T-1074-fanout-orchestration.md`
  **AC9**, `T-1076-log-run-locking.md` **AC10**,
  `T-1077-worktree-reconcile.md` **AC3**) read `FAIL` at HEAD the moment
  this task's own edit to `bin/loop-guard.sh` was still uncommitted, and
  returned to `PASS` once that edit was committed — a base-vs-head
  Blast-radius measurement taken with an uncommitted diff under `bin/` or
  `tests/` will misreport any such clause as newly reddened; measure after
  committing, or disclose the measurement's own uncommitted-diff timing
  explicitly rather than reporting the flip as caused by the diff's
  content.
- T-1081: two environment facts measured on this host, worth knowing
  before writing a `- check:` line or a verification script here.
  **(1)** `diff <(cmd1) <(cmd2)` (process substitution) fails with
  `diff: /dev/fd/NN: Operation not permitted` under this sandbox — `diff`
  cannot read a `/dev/fd` argument here — while `comm <(cmd1) <(cmd2)`
  reads the same kind of argument successfully; where a check needs a
  byte-identity comparison, extract each side to a **regular file** under
  `"$TMPDIR"` first and `diff -q`/`cmp -s` the two files, and where a
  check needs a set-difference (e.g. "every line on the left also
  appears on the right"), `comm`'s own process-substitution form is fine
  as-is. Do not "normalize" every such check to one spelling — the two
  forms exist because of this asymmetry, not by inconsistency.
  **(2)** A bare `/tmp/...` path is denied for writing on this host, while
  `"${TMPDIR:-/tmp}"/...` (or bare `"$TMPDIR"`) succeeds — always resolve
  a scratch path through `${TMPDIR:-/tmp}` in a `- check:` line or a
  verification script, never hardcode `/tmp` directly. Third, an
  instrumentation trap independent of either fact above: GNU `timeout`
  is **not installed** on this host's `bash` (`timeout: command not
  found`, exit 127) — a probe script that wraps each candidate command in
  `timeout N bash -c "$cmd"` to bound a sweep's runtime will report every
  single command as failed, uniformly and silently, with no diagnostic
  distinguishing "the command genuinely failed" from "the wrapper itself
  doesn't exist" (confirmed live: a 177-line population sweep reported
  0/177 passing under the `timeout`-wrapped script and a genuine
  63/72-ish split once the wrapper was removed) — never trust a uniform
  all-fail or all-pass result from a bulk probe without first confirming,
  via a single known-good positive control run through the same wrapper,
  that the wrapper itself executes the command at all.
- T-1082: `rm -rf` on any path (even a `mktemp -d "${TMPDIR:-/tmp}/…"`
  scratch dir this same command created) is denied outright by this
  session's sandboxed Bash tool, silently, with no output distinguishing
  it from a legitimate refusal — a raw ad-hoc probe command ending in
  `rm -rf "$T"` simply never runs at all. This does **not** affect
  `bin/check-acs.sh`'s own live `- check:` execution (its own harness runs
  fixture `rm -rf`s successfully; only this session's own Bash tool calls
  are affected) — prefer running a spec's `- check:` lines through
  `bin/check-acs.sh` (dry-run first, per the T-111 entry above, then live)
  over hand-copying a check body into an ad-hoc Bash call, and when a
  manual probe is unavoidable, skip the cleanup step (leave the scratch
  dir under `$TMPDIR`) rather than chaining a trailing `rm -rf`.
  Separately: this task's own reading-side checker for
  `bin/aggregate-verdicts.sh`'s `fanout-verdict` block reuses that
  script's own skeleton (the `die` helper, the `LC_ALL=C` export, the
  ANSI-C-quoted em dash, boundary-anchored key matching) rather than
  reinventing it — a real time-saver when a new checker reads a sibling
  checker's own output format.
- T-1083: no new `bin/` script, no new test suite (`- verification-class:
  mechanism`, but the diff is a documentation/prompt-block surface, not a
  script). The **probe venue procedure** (orchestrator-only, per the same
  no-Agent/Task-token measurement T-1073 already established): a throwaway
  `git clone --no-hardlinks` under `$TMPDIR`, pinned to the branch point,
  with `TEAM_RUNS_DIR` pointed **inside that clone** for every telemetry
  write the probe agents make — never into this checkout's own
  `.shell-team/runs/` corpus. Verify the real checkout stayed clean
  afterward with `git status --short` and `git ls-files --others
  --exclude-standard`, both read empty, rather than assumed. `CHECK_ACS_TIMEOUT`
  needs raising above the 120 s default for this spec's own full sweep
  (this task used 300, per the spec's Notes for engineer) because **AC19**
  runs five checkers including `check-handoff.sh` over the real board.
  Separately, this task's own **AC21** full-population Blast-radius sweep
  (87 specs at the branch point, run at both refs) is materially different
  from a single spec's own suite: a `git worktree add --detach <scratch>
  <branch-point>` gives a real base-side checkout `bin/check-acs.sh --root
  <scratch> <scratch>/<spec>` can run against, and running the 87-spec
  population **serially** at even a 90 s per-check cap takes on the order
  of hours on this host — `xargs -P <cores>` fan-out (one `check-acs.sh`
  invocation pair per spec, run in parallel, each writing to its own named
  output file, with a `tail -1 | grep -q '^check-acs: '` completion-marker
  check before trusting a partial or truncated output file, per the T-1082
  entry's own killed-mid-sweep lesson above) is what makes this tractable
  in one sitting; do not attempt the 87-spec population serially.
  Numeric criteria in this spec compare 19-digit epoch-nanosecond values
  via `$(( 10#$v ))` bash arithmetic — never `awk`/`sort -n` (a double
  cannot hold them exactly), the same discipline T-1069/T-1071/T-1072/
  T-1073 already established.
