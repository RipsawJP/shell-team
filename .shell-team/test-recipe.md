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
