# T-1001 — retro input acquisition: a git-derived cycle window and a machine-checked input ledger

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v3 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1001
**Source**: GitHub issue #28 (RipsawJP/shell-team), proposed directions 1 and 2, plus its acceptance-criteria requirements 1, 2 and 4.
**Branch**: `feature/retro-salience-capture` (from `develop`).

## Problem

The retro is the only mechanism this project has for turning experience into
rules a later run can apply, and its declared inputs do not match where this
project's information actually lives. `agents/scrum-master.md` asks for merged
pull requests with `--base main`, while work here merges to `develop`; it reaches
that list through `gh`, which is unavailable in the maintainer's environment; and
it declares `tasks/lessons.md` as an input that no resolver key can locate and
that does not exist in this repository. The one retro that exists records in its
own `## Notes` that its pull-request metadata arrived through a different channel
entirely — the declared mechanism did not work, a human workaround did, and
`bin/check-retro.sh` could not tell the difference, because it validates
headings and never asks what material the retro rests on.

**How this task got to v3.** v1 made a benign status the default and asked for one
hand-written guard per adverse condition; three defects of one class followed
(`unevaluable-condition-reported-as-benign`). v2 inverted that default, and the
inversion worked — the decision layer's class is closed, confirmed independently
by QA, the cross-provider review, and the coordinator. What v2 then attracted was
a *second* class, in the plumbing rather than the decisions
(`shell-construct-aborts-before-ledger-emitted`), and three more rounds went into
hardening against repository states that do not exist here and that nobody is
currently blocked by. The loop reached `STOP:max_iterations_reached`.

v3 is a scope cut, not another mechanism. Two plumbing defects that fire on the
default path are fixed, one bounded regression lock is added for the class they
belong to, six criteria that do not serve the goal are retired, and the
open-ended hardening is handed to its own issue. The reason is recorded in
`## What changed at v3`, because the mistake worth remembering is not in the code.

## Goal

<!-- BEGIN intent-block: T-1001 -->

The retro's declared inputs are the ones that exist, they are acquired by a
mechanism that needs nothing beyond `git` and this repository's own files, and
the presence or absence of each one is a machine-checked declaration rather than
a sentence a human may or may not remember to write. `bin/retro-inputs.sh`
derives the cycle window from `git` merge commits on a ref it resolves rather
than hardcodes, resolves every artefact path through `bin/team-paths.sh`, and
emits a **ledger** naming, for each declared input, whether it was `read`,
`empty`, or `unavailable`. `gh` is optional enrichment, not the acquisition path:
absent, it costs the retro one optional line and nothing else.

**`unavailable` is the default, and a benign status is a promotion that has to be
earned.** Every ledger line begins as `unavailable`; `read` and `empty` are
produced at a small, fixed, enumerated set of promotion sites, each of which
requires an affirmative determination that the input was actually enumerable. A
determination that cannot be made — a ref that cannot be resolved, a directory
whose entries cannot be stat'ed, a shallow boundary, a failing `git` or `gh`, a
resolver that did not answer — never reaches a promotion, so the safe status
stands without anyone having remembered to guard for it. The promotion sites are
enumerated in the script itself as a decision-site inventory, each row stating
what is emitted when its determination cannot be made, and each row is exercised
by a fixture that makes that determination impossible.

**A ledger that was never printed is worse than a ledger full of `unavailable`,
so the script reaches its emission pass or exits with a usage error, and nothing
in between.** Two constructs that abort before emission are removed: an
enumeration whose per-entry test aborts the script on a name that is not a
regular file, and a capped-window pipeline whose reader exits before its writer
finishes. A single **bounded** regression lock asserts one output invariant over
a **closed list of nine** repository states that this task's own review rounds
actually produced: the heading and eight complete ledger lines are printed, and
the exit status is 0 or a usage error. The list is closed at nine in both
directions, so it cannot grow by accretion, and the lock claims nothing about
plumbing defects nobody has found — that claim is not provable, and chasing it is
what this task did for three rounds.

`bin/check-retro.sh` enforces the ledger against a **closed** enum and applies the
same inversion to itself: "the section was located and validated", "the section is
absent", and "the section could not be read" are three distinct outcomes that can
never coincide, cross-checked between two independent determinations, so a
detection failure is reported as its own violation instead of passing as clean.
Where a tolerance property is claimed — CRLF, surrounding whitespace — it is
proved by a **malformed** input in that form still being reported, because an
accepted well-formed input and an unexamined one are indistinguishable.

The enumeration of input ids and status values exists in exactly one file, and
that single-source property is verified by `bin/check-prompt-sync.sh` rather than
asserted. Every new machine token is English; no Japanese required heading is
added, removed, or reworded. Every invocation instruction this task writes uses
this repository's documented form — the bare script name when the plugin is
loaded — so nothing it adds assumes a `bin/` directory in an adopter's tree.

## Non-goals

- **Exhaustive mutation or fuzz coverage of the plumbing layer** — every pipe,
  every `&&`-chain, every external-tool invocation in `bin/retro-inputs.sh`. The
  cross-provider review proposed it and the proposal is technically sound; it is
  declined because there is no current victim. This repository has nine merge
  commits, `--last-n` is not passed by the role's default, and
  `.shell-team/reviews/` contains neither a directory nor a broken symlink. What
  replaces it is the bounded lock over nine enumerated states (AC10), which
  protects the states that were actually produced and explicitly claims nothing
  beyond them. Filed as its own issue.
- **Extending `tests/errexit-safe/run.sh`.** It locks the `die`/`exit N`
  contract shape (T-096), a different class from an abort before emission. QA
  correctly recorded at round 3 that this class had no regression lock; AC10 is
  that lock, and it lives with the script it protects rather than being grafted
  onto a suite about something else.
- **The four minors from the last review round**: the temp-path / here-string
  dependency, a whitespace-only line in a supplied lessons file, a very large
  `--last-n` being accepted silently, and `tr` behaviour on non-UTF-8 bytes. None
  is on a default path and none has a current victim. Filed with the plumbing
  issue above.
- **The salience / intervention capture channel.** Issue #28's direction 3 and
  its trigger points 1, 3 and 5 — the moments a human interrupted, a measurement
  contradicted an assumption, work was abandoned — are what that issue calls its
  most important material, and they are still not in this task. That deferral was
  taken at round 0 and it is now the largest open item this task leaves behind;
  recorded here as a debt rather than a tidy exclusion.
- **What single-pass work owes the retro** (direction 4). Untouched here.
- **Making `## Orchestrator attest` mandatory** (direction 5). It couples to
  issue #20's open problem about which language a generated artefact is written
  in, and this task must not deepen that.
- **The dead `docs/loop-engineering/` pointers.** `loop-traps.md` and
  `model-tiering.md` are referenced in `agents/scrum-master.md` and
  `docs/templates/retro-template.md` and neither file exists. They are left
  exactly as they are; AC26's allow-list keeps this revision out of both files
  entirely, which is a stronger guarantee than the criterion v2 used for it.
- **Whether the retro may read local agent transcripts.** Issue #28 records that
  as an open question and does not propose it; this task does not answer it.
- **A `lessons` key for `bin/team-paths.sh` (issue #24) and the lessons corpus
  import (issue #23).** Both open. This spec assumes **no resolvable lessons path
  exists**, treats the lessons log as an optional input, and locates it only from
  an explicit argument (DP-4).
- **Correcting the `tasks/provenance/<task-id>.md` hardcodes** across `skills/`,
  `agents/` and the generated `playbook-*.md` blocks. See DP-3.
- **An alternative cycle window for squash-merge-only repositories.** A history
  with no merge commits, confirmed complete, reports `empty` with a detail saying
  why (DP-6).
- **Making `docs/templates/retro-template.md` itself pass `bin/check-retro.sh`.**
  It does not pass today: its `## Lesson 候補（…）` section carries a bare
  `` - `<...>` `` bullet that rule 3 rejects. No CI step is added that would
  require it to.
- **Any change to the five decorated Japanese H2 headings, the
  `` `[common]` ``/`` `[target-specific]` `` label rule, or the exit-code
  contract of `bin/check-retro.sh`.** AC21 holds them in place.
- **Rewriting rule 3's region walk.** It matches its region by prefix, so it is
  CR-tolerant already; AC21 confirms that by fixture rather than restructuring a
  rule that does not carry the defect.
- **Stripping Unicode line separators (U+2028 / U+2029) and bidirectional control
  characters in `sanitize()`.** Declined at v2 with three reasons and re-confirmed
  as sound by the cross-provider review: `awk` and `grep` split records on LF and
  neither character is a record separator for any POSIX text tool, so no such
  character can forge a ledger line and AC15's property holds without it; the
  residual display-level risk belongs to a repository-wide content guard over
  every tracked file — `bin/check-pii-shapes.sh` is the existing home for that
  shape — rather than to one emitter, since the retro is committed and such a
  character could be typed in by hand; and `tr -d` is byte-oriented and cannot
  delete a multi-byte code point at all, so a fix means changing the sanitiser's
  tool, which reopens the injection surface. Filed as its own issue.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup, invokes
scripts as `bash bin/<script>.sh` (never a bare name — that is the *spec's*
invocation convention, distinct from the *agent instruction* convention AC30
governs), and uses `develop` as the base ref where a base ref is needed. **The
exact bytes of every canonical line this task adds are the `grep` patterns
below** — there is no second copy of them elsewhere in this spec to drift from
(DP-8).

Three rules apply to every criterion here, each learned from a defect this task
produced:

- **No negated grep without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` does not exist, because `grep` exits 2 and the negation
  swallows it. v1's zero-dependency criterion did not do this and would have
  passed against a script that was never written.
- **A tolerance claim is proved by a malformed input, never a well-formed one.**
  "This checker tolerates CRLF" cannot be demonstrated by a valid CRLF file
  passing, because a checker that skips the file entirely produces the same
  result. v1 required exactly that fixture, and a blocker shipped through it.
- **A criterion states the boundary of what it proves.** AC10 asserts an
  invariant over an enumerated list and says so; it does not assert that no
  further plumbing defect exists, because that is not provable and pursuing it is
  what cost this task three rounds.

Some criteria assert a fixture *case* rather than the behaviour directly, because
the behaviour needs a purpose-built git history, a permission-restricted
directory, a linked worktree, or a stubbed `PATH` that a `check:` line must not
build in the working repository. Those criteria pin the case's label byte-exact so
deleting the case fails the criterion, and AC17 asserts that every case in the
suite passes. The pair is only as strong as a label attached to a real assertion;
verifying that attachment is QA's and the reviewer's job.

- [ ] **AC1** `bin/retro-inputs.sh` exists, prints help and exits 0 for `--help`,
  and rejects an unknown flag with exit **2**. The exit-2-on-usage-error half is
  load-bearing for AC10, whose invariant permits exactly two exit statuses.
  - check: test -f bin/retro-inputs.sh && bash bin/retro-inputs.sh --help >/dev/null && rc=0 && { bash bin/retro-inputs.sh --no-such-flag-t1001 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2

- [ ] **AC2** **`unavailable` is the default and a benign status is a promotion.**
  There is exactly one place in the script that formats a ledger line, exactly two
  promotion functions — `promote_read` and `promote_empty`, the only paths by which
  `read` or `empty` can reach a ledger line — and exactly **eight** promotion call
  sites, one per line. The count is pinned in both directions: a ninth site fails,
  and so does deleting one. The behavioural half is exercised directly: pointed at
  a base directory that does not exist, every directory-backed input and the
  lessons line report `unavailable` and the ledger is still complete, without any
  per-input guard having been consulted.
  - check: test -f bin/retro-inputs.sh && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && test "$(printf '%s\n' "$nc" | grep -cE -- '^(promote_read|promote_empty)\(\)')" -eq 2 && test "$(printf '%s\n' "$nc" | grep -oE -- '(^|[^a-z_])(promote_read|promote_empty)[[:space:]]' | wc -l | tr -d ' ')" -eq 8 && test "$(printf '%s\n' "$nc" | grep -cF -- '- input: %s — status: %s — detail: %s')" -eq 1 && out="$(TEAM_RUN_BASE=no-such-base-t1001 bash bin/retro-inputs.sh)" && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 && test "$(printf '%s\n' "$out" | grep -c -- ' — status: unavailable — ')" -ge 6

- [ ] **AC3** Probing and emission are separate passes. The eight canonical ids are
  emitted once each, in the canonical order of
  `templates/prompt-blocks/retro-inputs.md`, after every probe has run — so a probe
  that returns early, fails, or forgets a branch cannot remove a line from the
  ledger or leave its status unstated.
  - check: out="$(bash bin/retro-inputs.sh --base HEAD)" && test "$(printf '%s\n' "$out" | grep -oE -- '^- input: [a-z-]+' | sed 's/^- input: //' | tr '\n' ' ')" = "cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata "

- [ ] **AC4** **The decision-site inventory is complete and each row answers the
  unevaluable question.** `bin/retro-inputs.sh`'s header carries one row per
  promotion site, labelled `DS-1` … `DS-8`, and each row names the determination
  the site makes, the precondition(s) that determination requires, and states that
  `unavailable` stands when the determination cannot be made. The fixture suite
  carries one case per `DS-n` that makes that determination impossible and asserts
  the resulting status is `unavailable`. Both counts are pinned at eight, so
  neither the inventory nor the fixture matrix can be short of the other.
  - check: test "$(grep -cE -- '^# +DS-[1-8] ' bin/retro-inputs.sh)" -eq 8 && test "$(grep -ohE -- 'case: DS-[1-8]' tests/retro-inputs/run.sh | sort -u | wc -l | tr -d ' ')" -eq 8 && for i in 1 2 3 4 5 6 7 8; do grep -qE -- "^# +DS-$i " bin/retro-inputs.sh || exit 1; grep -qF -- "case: DS-$i " tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC5** **The three decision-layer defects each keep their named fixture.** A
  directory that contains matching files but whose entries cannot be stat'ed is
  `unavailable`, never `empty` — the determination is made by confirming the
  enumeration itself succeeded, not by reading a permission bit. A shallow
  repository is detected as shallow **from a linked worktree as well as from the
  primary one**, and a shallow question that cannot be answered at all yields
  `unavailable`. The default-ref probe distinguishes "the ref does not exist" from
  "git could not answer", and reports the second as `unavailable` with a reason
  naming it. This criterion is unchanged at v3: the class it closes is closed, and
  these fixtures are what keep it closed.
  - check: for l in 'case: a directory containing files but not traversable -> unavailable, never empty' 'case: a shallow linked worktree with zero merges -> unavailable, never empty' 'case: the default-ref probe cannot answer -> unavailable with a reason distinct from ref-absent'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done && grep -qF -- 'is-shallow-repository' bin/retro-inputs.sh

- [ ] **AC6** Run against this repository with no arguments, `bin/retro-inputs.sh`
  emits a **complete, well-formed ledger**: the heading `## Retro inputs`, exactly
  eight top-level `- input: ` lines, each with a status drawn from the closed enum
  and a non-empty `detail:`. The grammar is exactly three ` — `-separated fields,
  so a script-generated detail can never contain the separator and split a line
  into a fourth field. A `read` status must say **how much** was found, asserted
  mechanically as "the detail contains a digit".
  - check: out="$(bash bin/retro-inputs.sh)" && printf '%s\n' "$out" | grep -qxF -- '## Retro inputs' && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 && test "$(printf '%s\n' "$out" | grep -cE -- '^- input: (cycle-window|review-artifacts|provenance|specs|run-telemetry|previous-retro|lessons|pr-metadata) — status: (read|empty|unavailable) — detail: [^[:space:]]')" -eq 8 && test "$(printf '%s\n' "$out" | grep -- '^- input: ' | awk -F' — ' '{ print NF }' | sort -u | tr -d '\n')" = "3" && printf '%s\n' "$out" | awk -F' — ' '/^- input: /{ if ($2 == "status: read" && $3 !~ /[0-9]/) bad = 1 } END { exit bad + 0 }'

- [ ] **AC7** Every artefact path is resolved through `bin/team-paths.sh`: no
  non-comment line of `bin/retro-inputs.sh` contains a literal `.shell-team/` or
  `tasks/` path, and the script does call the resolver. Both positive controls are
  present — the non-comment extraction is non-empty, and it names the resolver.
  A fixture case covers both layouts and a `$TEAM_RUN_BASE` override.
  - check: test -f bin/retro-inputs.sh && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && printf '%s\n' "$nc" | grep -qF -- 'team-paths.sh' && ! printf '%s\n' "$nc" | grep -qE -- '\.shell-team/|(^|[^A-Za-z0-9_./-])tasks/' && grep -qF -- 'case: both layouts and a TEAM_RUN_BASE override resolve every input path' tests/retro-inputs/run.sh

- [ ] **AC8** **The directory enumeration cannot abort before the ledger is
  printed.** A name ending in the suffix that is not a regular file — a directory
  called something ending in `.md`, or a broken symlink — is an ordinary,
  reachable entry, and it must be counted as enumerated-and-not-a-match. It was
  instead making the per-entry test the last thing the enumeration did, so the
  function returned non-zero and the bare call site killed the script under
  `errexit`: exit 1, zero lines of output, on the default path, with no permission
  trickery and no scale. Two properties therefore hold. The enumeration function
  ends with an unconditional success. And neither the enumeration function nor the
  cycle-window function conditions an **assignment** on a preceding test with `&&`
  — the shape whose survival depends on a later statement happening to succeed,
  which is why one reproduction of this defect was initially hidden. This is
  deliberately scoped to the two functions this revision edits: it is not a sweep
  of the file, and the class-wide sweep is a Non-goal. `&&` inside an `if`
  condition is untouched and remains correct.
  - check: for fn in count_dir_entries compute_cycle_window; do b="$(awk -v n="$fn" 'index($0, n "() {") == 1 { i = 1; next } i && /^\}$/ { exit } i' bin/retro-inputs.sh)"; test -n "$b" || exit 1; if printf '%s\n' "$b" | grep -qE -- '&&[[:space:]]*[A-Za-z_][A-Za-z0-9_]*='; then exit 1; fi; done && b="$(awk 'index($0, "count_dir_entries() {") == 1 { i = 1; next } i && /^\}$/ { exit } i' bin/retro-inputs.sh)" && test -n "$b" && test "$(printf '%s\n' "$b" | grep -vE '^[[:space:]]*(#|$)' | tail -n 1 | sed 's/^[[:space:]]*//')" = "return 0"

- [ ] **AC9** **The capped window is produced without a reader that can exit before
  its writer finishes.** Piping the full merge log into `head` makes the writer
  take a SIGPIPE once the data exceeds the pipe buffer; under `pipefail` the
  assignment fails, `errexit` fires, and the script exits 141 with no output. The
  measured trigger is **bytes, not merge count** — around 64 KB — so a repository
  with long branch names reaches it with far fewer merges than a count-based
  estimate suggests. `--last-n` is not passed by the role's default, so this is an
  opt-in path; it is fixed here anyway because it closes in one line and a one-line
  fix is not worth deferring. No pipeline in the script feeds `head`.
  - check: test -f bin/retro-inputs.sh && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && printf '%s\n' "$nc" | grep -qF -- 'last_n' && ! printf '%s\n' "$nc" | grep -qE -- '\|[[:space:]]*head([[:space:]]|$)'

- [ ] **AC10** **One bounded regression lock for the abort-before-emission class,
  and it states its own boundary.** `tests/retro-inputs/invariants.sh` asserts a
  single output invariant across a **closed list of nine** repository states: the
  heading and eight complete ledger lines are printed, and the exit status is 0 or
  the usage code. Any other exit status — 1 and 141 included — and any output with
  fewer than eight ledger lines is a violation. The nine states are the ones this
  task's own review rounds actually produced: a directory whose name ends in `.md`;
  a broken symlink whose name ends in `.md`; a merge log larger than the pipe
  buffer with `--last-n`; an empty operating directory; a readable but
  non-traversable directory; a shallow repository; a linked worktree; a `--base`
  ref that does not resolve; and `--last-n 0`. **The count is pinned at nine in
  both directions**, so the list cannot grow by accretion round after round — a
  tenth state is a change to this criterion, decided deliberately, not something a
  review round adds. **What this does not claim**: it does not assert that no
  further plumbing defect exists. That is not provable, and treating it as the goal
  is what took this task three rounds past the point of usefulness. It asserts the
  invariant for the enumerated states and nothing more. No fuzz harness.
  - check: T=tests/retro-inputs/invariants.sh && test -f "$T" && grep -qF -- 'In every state below, retro-inputs.sh prints "## Retro inputs" and eight complete ledger lines and exits 0 or 2; any other exit status (including 1 and 141) and any output with fewer than eight ledger lines is a violation.' "$T" && test "$(grep -ohE -- 'state: [a-z0-9 .-]+' "$T" | sort -u | wc -l | tr -d ' ')" -eq 9 && for l in 'state: a directory whose name ends in .md' 'state: a broken symlink whose name ends in .md' 'state: a merge log larger than the pipe buffer with --last-n' 'state: an empty operating directory' 'state: a readable but not traversable directory' 'state: a shallow repository' 'state: a linked worktree' 'state: a --base ref that does not resolve' 'state: --last-n 0'; do grep -qF -- "$l" "$T" || exit 1; done && bash "$T" >/dev/null

- [ ] **AC11** `gh` is optional enrichment, not the acquisition path. With `gh`
  absent the script emits a complete ledger, reports `pr-metadata` as
  `unavailable` with a reason, and **exits 0**; with `gh` present it never
  requests the `body` field. Both are fixture cases, and the fixture `gh` stub
  carries the same hard guard as `tests/discover-work/fixtures/gh` — it fails
  loudly if any argv mentions `body`, so the prohibition is enforced at runtime
  and not only by reading the source.
  - check: grep -qF -- 'case: gh absent -> pr-metadata unavailable, exit 0' tests/retro-inputs/run.sh && grep -qF -- 'case: gh present -> the PR body field is never requested' tests/retro-inputs/run.sh && test -f tests/retro-inputs/fixtures/gh && grep -qF -- 'PR body must not be requested' tests/retro-inputs/fixtures/gh

- [ ] **AC12** When `gh` is used, the requested field set is exactly the six
  structured fields the role already trusts — `number`, `title`, `mergedAt`,
  `author`, `url`, `headRefName` — and no `--json` argument anywhere in the script
  names `body`. The positive grep on the same file is the control for the negative.
  - check: grep -qF -- 'number,title,mergedAt,author,url,headRefName' bin/retro-inputs.sh && ! grep -qE -- '--json.*body' bin/retro-inputs.sh

- [ ] **AC13** The cycle window is **derived from git**, not from `gh` and not from
  a hardcoded branch: merge commits reachable from the resolved base ref along the
  first-parent path. The ref is resolved as `develop` when it resolves and `HEAD`
  otherwise, is overridable with `--base REF`, and **every** cycle-window line —
  `read`, `empty` and `unavailable` alike — names the ref actually used and states
  that a fallback occurred whenever one did. `--last-n N` caps the window, and the
  detail states **every** qualifier that applies rather than the first one: a cap
  and a shallow truncation are different facts and can be true at once. The help
  text states the default and the fallback so an adopter with no `develop` is not
  left guessing.
  - check: out="$(bash bin/retro-inputs.sh --base HEAD)" && printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: (read|empty|unavailable) — detail: .*HEAD' && grep -qF -- 'git log --merges --first-parent' bin/retro-inputs.sh && bash bin/retro-inputs.sh --help | grep -qF -- 'default: develop, falling back to HEAD' && for l in 'case: default base resolves to develop when it exists' 'case: no develop branch falls back to HEAD and declares the fallback in every status branch' 'case: --last-n caps the window and the cap is declared, distinct from a shallow truncation' 'case: a shallow repository with a cap states both qualifiers' 'case: every ledger is complete (all eight input ids, exactly once)'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC14** Degenerate histories are classified honestly. A base ref that does
  not resolve locally is `unavailable` with the ref named — not `empty`. A history
  with zero merge commits, where the ref *did* resolve and the history is
  **confirmed** complete, is `empty`. A shallow repository with zero merges inside
  the boundary is `unavailable`, because "no merges" and "merges beyond the
  boundary" are indistinguishable there. A shallow repository that does find merges
  is `read` with the truncation declared. A failing `git` invocation is
  `unavailable`, the ledger is still complete, and the exit status is still 0. The
  missing-ref case is exercised directly here; the rest are fixture cases.
  - check: out="$(bash bin/retro-inputs.sh --base no-such-ref-t1001)" && printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: .*no-such-ref-t1001' && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 && test -f tests/retro-inputs/fixtures/git && for l in 'case: --base names a ref that does not exist locally -> unavailable' 'case: zero merge commits (squash-merge history) -> empty' 'case: shallow repository with zero merges in the boundary -> unavailable' 'case: shallow repository with merges -> read with a truncation note' 'case: git invocation failure -> unavailable, complete ledger, exit 0'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC15** Text this script does not control cannot forge a ledger line. A
  merge-commit subject, a pull-request title and a branch name are all
  attacker-controlled in a public repository, and a merge subject carrying
  ` — status: read — detail: …`, a backtick, or an embedded newline must not
  produce a second parseable ledger line. Untrusted text is neutralised before it
  is emitted, the same discipline `bin/discover-work.sh` already applies to a
  candidate title, and the emitted ledger — with adversarial material in it —
  still passes `bin/check-retro.sh` when embedded in a retro.
  - check: grep -qF -- 'untrusted text (a merge subject, a PR title, a branch name) is stripped of CR, LF, TAB and backticks and has U+2014 replaced before it is emitted, so it can never forge a ledger line' bin/retro-inputs.sh && grep -qF -- 'case: adversarial merge subject cannot forge a ledger line' tests/retro-inputs/run.sh && grep -qF -- 'case: the emitted ledger embedded in a retro passes check-retro.sh' tests/retro-inputs/run.sh

- [ ] **AC16** The lessons log is an **optional** input, and its absence is a
  recorded status rather than a gap someone has to notice. With no path supplied it
  is `unavailable` with a reason; with a readable path supplied whose non-blank
  lines could be counted it is `read`. The role's prose says so, and the superseded
  framing that made it a required input is gone.
  - check: test -f agents/scrum-master.md && bash bin/retro-inputs.sh | grep -qE -- '^- input: lessons — status: unavailable — detail: .+' && bash bin/retro-inputs.sh --lessons README.md | grep -qE -- '^- input: lessons — status: read — detail: .+' && grep -qF -- 'The lessons log is OPTIONAL: there is no resolver key for it, so it is read only when a path is supplied, and its absence is recorded as unavailable rather than as a failure.' agents/scrum-master.md && ! grep -qF -- '**Lessons log** — read' agents/scrum-master.md && grep -qF -- 'case: lessons path not supplied -> unavailable' tests/retro-inputs/run.sh && grep -qF -- 'case: lessons path supplied -> read' tests/retro-inputs/run.sh

- [ ] **AC17** `tests/retro-inputs/run.sh` exists and **every** case in it passes.
  This is the criterion that makes every label lock above mean something. A
  positive control guards against a stub suite that passes by doing nothing: it
  must drive the script under test at least eight times.
  - check: test -f tests/retro-inputs/run.sh && test "$(grep -c -- 'retro-inputs.sh' tests/retro-inputs/run.sh)" -ge 8 && bash tests/retro-inputs/run.sh >/dev/null

- [ ] **AC18** **The checker cannot report "could not evaluate" as "clean".** Rule
  4 has three outcomes that never coincide, each with its own message: the section
  was located and its ledger validated; the section is absent; the section's
  heading is present but its ledger region **could not be read**. Two independent
  determinations are cross-checked — the CR-tolerant heading search and the region
  walk must agree that the section was entered — and a disagreement is its own
  violation. A duplicate `## Retro inputs` heading is a violation rather than a
  silently unvalidated region, and any top-level ledger-shaped line that falls
  outside the walked region is a violation too. To discuss a ledger line in a
  retro's prose, indent it.
  - check: for l in '## Retro inputs section heading is present but its ledger region could not be read' 'duplicated ## Retro inputs section heading' 'ledger-shaped line outside the ## Retro inputs section' 'whitespace-only Retro inputs detail'; do grep -qF -- "$l" bin/check-retro.sh || exit 1; done && grep -qF -- 'missing decorated section heading: $RETRO_INPUTS' bin/check-retro.sh

- [ ] **AC19** **A tolerance claim is proved by a malformed input.** The suite's
  CRLF case takes a ledger that is *broken* — an id present with no status, other
  ids missing — converts it to CRLF, and asserts it is **still reported**. A
  `detail:` consisting only of whitespace is reported for the same reason: "a
  detail is present" and "there are spaces there" are not the same determination.
  And AC18's agreement backstop is proved to bite by a **mutation self-check inside
  the suite**: a copy of the checker in a temporary directory, with the region
  walk's CR handling removed, must still report the malformed CRLF ledger. The real
  script is never modified.
  - check: for l in 'case: a MALFORMED ledger in a CRLF file is still reported (not silently accepted)' 'case: a whitespace-only detail is reported' 'case: with the region walk CR handling removed, a malformed CRLF ledger is STILL reported (agreement backstop)'; do grep -qF -- "$l" tests/check-retro/run.sh || exit 1; done && bash tests/check-retro/run.sh >/dev/null

- [ ] **AC20** Every named malformed ledger is rejected with exit 1, exercised
  directly here rather than only through the suite. Ten committed fixtures: no
  section, unknown status, unknown id, missing id, duplicated id, empty detail,
  whitespace-only detail, an unrecognised line inside the section, a duplicated
  section heading, and a ledger-shaped line outside the section. The canonical
  fixture still passes, which is the positive control.
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-canonical.md >/dev/null && for f in fail-inputs-missing-section fail-inputs-unknown-status fail-inputs-unknown-id fail-inputs-missing-id fail-inputs-duplicate-id fail-inputs-empty-detail fail-inputs-blank-detail fail-inputs-stray-line fail-inputs-duplicate-section fail-inputs-line-outside-section; do test -f "tests/check-retro/fixtures/$f.md" || exit 1; rc=0; bash bin/check-retro.sh "tests/check-retro/fixtures/$f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done

- [ ] **AC21** The checker's existing contract is untouched. All five decorated
  heading constants are byte-identical, so no Japanese heading is reworded, renamed
  or dropped; the repository's own retro still passes; and rule 3's own CR
  tolerance — which it has by construction, since it matches its region by
  prefix — is confirmed by a fixture rather than assumed.
  - check: for l in "KEEP='## Keep（続けたい良い動き）'" "PROBLEM='## Problem（直面した課題 / 痛み）'" "TRY='## Try（次サイクルで試すこと）'" "TRAPS='## 罠の点検（Comprehension Debt / Cognitive Surrender）'" "LESSON_PREFIX='## Lesson 候補（'"; do grep -qxF -- "$l" bin/check-retro.sh || exit 1; done && bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null && grep -qF -- 'case: rule 3 still catches an unlabelled Lesson bullet in a CRLF file' tests/check-retro/run.sh

- [ ] **AC22** `bin/team-paths.sh` resolves a `provenance` key, in every mode a
  consumer can use: `--get provenance`, `TEAM_PROVENANCE_DIR` in `--export`, a row
  in `--print`, and the key named in `--help`. An unknown key still exits 2, and
  the resolver's own suite covers the default layout and the legacy layout in the
  idiom it already uses.
  - check: test "$(bash bin/team-paths.sh --get provenance)" = ".shell-team/provenance" && bash bin/team-paths.sh --export | grep -qE -- '^export TEAM_PROVENANCE_DIR=' && bash bin/team-paths.sh --print | grep -qE -- '^[[:space:]]+provenance[[:space:]]+\.shell-team/provenance$' && bash bin/team-paths.sh --help | grep -qF -- 'provenance' && rc=0 && { bash bin/team-paths.sh --get no-such-key-t1001 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && grep -qF -- 'default: provenance path wrong' tests/team-paths/run.sh && grep -qF -- 'legacy: provenance path wrong' tests/team-paths/run.sh && bash tests/team-paths/run.sh >/dev/null

- [ ] **AC23** The one retro that already exists carries a ledger, so the rule
  applies to every retro in the tree with no date-based exception inside the
  checker (DP-5). Its two unambiguously recorded absences — the lessons log and the
  pull-request metadata — are declared as `unavailable`, and the file passes.
  - check: bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null && grep -qxF -- '## Retro inputs' .shell-team/retros/2026-07-28.md && test "$(grep -c -- '^- input: ' .shell-team/retros/2026-07-28.md)" -eq 8 && grep -qE -- '^- input: lessons — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md && grep -qE -- '^- input: pr-metadata — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md

- [ ] **AC24** CI runs all of it: the scripts and every fixture stub are on the
  shellcheck argument list, both fixture suites are steps, the declared acquisition
  path is exercised against a real repository, and `bin/check-retro.sh` is
  dogfooded against this repository's own retros. `shellcheck` is invoked
  unconditionally, so a missing shellcheck fails the criterion loudly instead of
  passing it vacuously.
  - check: W=.github/workflows/check-handoff.yml && grep -qF -- 'bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/invariants.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git' "$W" && grep -qF -- 'bash tests/retro-inputs/run.sh' "$W" && grep -qF -- 'bash tests/retro-inputs/invariants.sh' "$W" && grep -qF -- 'bash bin/retro-inputs.sh --base HEAD' "$W" && grep -qF -- 'bash bin/check-retro.sh .shell-team/retros/*.md' "$W" && shellcheck bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/invariants.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git

- [ ] **AC25** The hardcoded release-branch query is gone from the whole operative
  surface. `--base main` occurs exactly once in the pre-task tree, in
  `agents/scrum-master.md`'s merged-PR command; after this task it occurs nowhere
  under `agents/`, `bin/`, `skills/` or `templates/`. Two positive controls: the
  base blob is read first, proving the defect genuinely existed, and the recursive
  grep is proved to be reading those directories before its result is negated.
  **Merge-point-scoped**: it resolves `develop:agents/scrum-master.md` and goes
  stale once this task lands on `develop`. That is expected; do not widen its
  base-ref resolution or re-derive it per rework round.
  - check: git show develop:agents/scrum-master.md | grep -qF -- '--state merged --base main' && grep -rqF -- 'retro-inputs' agents bin skills templates && ! grep -rqF -- '--base main' agents bin skills templates

- [ ] **AC26** The change stays inside its declared surface: every path in
  `git diff --name-only develop` matches the allow-list below, and the diff is
  non-empty as a positive control. The allow-list is unchanged from v2 and still
  lists every file earlier rounds legitimately touched — retiring a criterion does
  not retire the work it named — plus this task's mandatory records. It is also
  what keeps this revision out of `agents/scrum-master.md` and
  `docs/templates/retro-template.md`, which v3 has no reason to reopen.
  **Merge-point-scoped**: tied to the merge point it was authored at and expected
  to go stale after merge, when later work moves `develop` forward. Do not
  merge-range it, re-derive it per rework round, or widen its base-ref resolution.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.github/workflows/check-handoff\.yml|\.shell-team/(todo\.md|test-recipe\.md|provenance/T-1001\.md|reviews/T-1001[^/]*|retros/2026-07-28\.md|specs/T-1001-retro-input-acquisition\.md)|agents/scrum-master\.md|bin/(check-retro|retro-inputs|team-init|team-paths)\.sh|docs/templates/retro-template\.md|templates/prompt-blocks/(registry\.txt|retro-inputs\.md)|tests/(check-retro|retro-inputs|team-init|team-paths)/.+)$')"

- [ ] **AC27** Nothing that already worked stops working: prompt sync, the board
  linter on both the shipped template and this repository's board, and the two
  suites this revision does not otherwise run. The suites already run by AC17,
  AC19 and AC22 are not repeated here.
  - check: bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash tests/team-init/run.sh >/dev/null

- [ ] **AC28** The task's decision provenance file exists and is conformant, and it
  is located through the new resolver key rather than a hardcoded path — so the key
  AC22 adds is dogfooded by this criterion.
  - check: bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1001.md" >/dev/null

- [ ] **AC29** `bin/retro-inputs.sh` writes nothing. Two consecutive runs leave the
  working tree's git status byte-identical, and no non-comment line invokes a
  file-creating command. The runs must also succeed, which is the positive control
  — and which, after AC8 and AC9, is also the cheapest confirmation that the
  default path still reaches its emission pass.
  - check: before="$(git status --porcelain)" && bash bin/retro-inputs.sh >/dev/null && bash bin/retro-inputs.sh --base HEAD >/dev/null && test "$(git status --porcelain)" = "$before" && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && ! printf '%s\n' "$nc" | grep -qE -- '(mktemp|[[:space:]](tee|cp|mv|rm|touch)[[:space:]])'

- [ ] **AC30** `agents/scrum-master.md` declares the mechanism that actually runs,
  **and invokes it the way this repository documents**: the bare script name, which
  is on `PATH` when the plugin is loaded, with the relative path only ever as the
  parenthetical fallback for running inside this repository. The plugin's `bin/` is
  on an adopter's `PATH` but does not exist in an adopter's tree, so an instruction
  to run `bin/retro-inputs.sh` fails there and degrades the retro silently — the
  same failure issue #28 exists to remove. Mechanically: every occurrence of the
  relative path is preceded by `bash `, the bare form appears at least twice, and
  the role reports the ledger's tally in its hand-off while the superseded
  PR-counting line is gone.
  - check: F=agents/scrum-master.md && test -f "$F" && grep -qxF -- '## Inputs you read' "$F" && test "$(grep -o -- 'bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" -eq "$(grep -o -- 'bash bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" && test "$(grep -o -- '`retro-inputs\.sh`' "$F" | wc -l | tr -d ' ')" -ge 2 && grep -qF -- 'on `PATH` when the plugin is loaded' "$F" && grep -qF -- 'Retro inputs: <n> read / <n> empty / <n> unavailable' "$F" && ! grep -qF -- 'Inputs read: <count> PRs' "$F"

## Input space

**Reachable input classes** — what real usage of this mechanism can produce, and
what the implementation must therefore be correct about:

1. A git work tree whose history reaches the base ref through merge commits, with
   subjects of the form `Merge pull request #N from <owner>/<branch>`. In a public
   repository those subjects embed a pull-request title or branch name, i.e.
   attacker-controlled text, which can contain backticks, a U+2014 EM DASH, quote
   characters, and — through a crafted branch name — the ledger grammar itself.
2. A git work tree with **zero merge commits**: a squash-merge-only project.
3. A **shallow** repository, where history is truncated at a boundary and the
   absence of a merge commit proves nothing.
4. A **linked worktree**, where repository-level state lives in the common
   directory rather than the worktree's own git directory, so a probe of
   repository state can answer differently depending on which worktree it runs in.
5. A base ref that does not resolve locally: an adopter whose default branch is
   `main`, and a CI checkout where `develop` exists only as a remote-tracking ref.
6. A failing or unanswerable `git` invocation: `git` absent from `PATH`, a
   `safe.directory` refusal, an unreadable object store, or a `git` too old to
   answer a particular query. "The ref does not exist" and "git could not tell me"
   are different answers and reach the ledger differently.
7. `gh` in all four of its states — absent, present but unauthenticated, present
   and authenticated, and present but failing on one subcommand.
8. Each declared input's location in five states: absent; present and empty;
   present with files; present but not readable; and **present, readable, but not
   traversable**. The run-telemetry directory reaches two of these routinely in
   this repository: `.shell-team/.gitignore` ignores `runs/`, so the maintainer's
   checkout has a populated `.shell-team/runs/shell-team.jsonl` while a fresh
   clone has only the tracked `.gitkeep`.
9. **An operating directory containing an entry that matches the suffix but is not
   a regular file** — a directory whose name ends in `.md`, or a broken symlink.
   Neither is present in this repository today; both are ordinary states a host
   repository can be in, and one of them was measured to abort the script on the
   default path. This class is what AC8 and AC10 exist for.
10. **A merge log whose byte size exceeds the pipe buffer** (measured around
    64 KB). Reachable by merge count and subject length together, so a repository
    with long branch names reaches it sooner than a count-based estimate suggests;
    reachable only when `--last-n` is passed, which the role's default does not do.
11. A path resolver that does not answer at all, and one that answers with a base
    directory that does not exist on disk.
12. Retro files a checker must judge: a well-formed ledger; a ledger missing an id;
    a duplicated id; a status outside the enum; an id outside the enum; an empty
    `detail:`; a `detail:` of whitespace only; a stray non-bullet line inside the
    section; no `## Retro inputs` section at all; two `## Retro inputs` headings; a
    top-level ledger-shaped line outside the section; and **CRLF line endings in a
    file whose ledger is malformed**.
13. A ledger whose `detail:` free text **quotes the ledger grammar** — this
    repository's habit of describing a mechanism inside the artefact the mechanism
    governs.
14. Both supported layouts (the `.shell-team/` default and the legacy `tasks/`
    split-root layout) and a `$TEAM_RUN_BASE` override.

**Out-of-scope synthetic extremes** — named and declined:

1. **Adversarial repository states beyond the nine AC10 enumerates.** The nine are
   the states this task's own review rounds actually produced. A tenth is a change
   to AC10, taken deliberately, not something a rework round appends — and the
   count is pinned in both directions precisely so that boundary is enforced rather
   than trusted. This is the declared limit of the abort-before-emission lock:
   inside the nine, the invariant is asserted; outside them, nothing is claimed.
2. Adversarially large inputs: megabyte-scale commit subjects or pull-request
   titles, tens of thousands of merge commits, a retro with thousands of ledger
   lines. The one size threshold that *is* in scope is class 10, because it was
   measured on a default construct rather than imagined.
3. Non-UTF-8 or mixed-encoding retro files and commit messages, NUL bytes inside a
   commit subject, and Unicode line separators (U+2028 / U+2029) or bidirectional
   control characters in untrusted text. None is a record separator for any POSIX
   text tool, so none can forge a ledger line; the display-level concern is a
   Non-goal above with its reasons.
4. A retro crafted to defeat the section parser through markdown notation rather
   than line endings: `## Retro inputs ##` in ATX-closing form, or the heading
   inside a fenced code block. `bin/check-board-headings.sh`'s header records that
   this matching weakness is deliberately left in place in `bin/check-handoff.sh`.
   CRLF is explicitly **not** in this class — it is reachable class 12.
5. A hostile `git` or `gh` earlier on `PATH` returning well-formed but fabricated
   output. The ledger is a discipline aid for a trusted, committed, reviewed
   artefact, not a security boundary against an adversarial author — the same trust
   boundary `bin/check-acs.sh` and `bin/check-provenance.sh` declare. The fixture
   stubs simulate absence and failure; they do not model an attacker.
6. Malformed or reordered `gh` JSON. Field extraction uses `gh`'s own `--jq`, as
   `bin/discover-work.sh` already does.
7. Concurrent retro runs racing on the same output path.
8. Local agent transcripts.

<!-- END intent-block: T-1001 -->

## What changed at v3

For the approval record, and the first item is not about the code.

1. **The scope was cut, and the reason is a misclassification at the coordination
   layer.** The cross-provider review labelled two plumbing defects Blocker, and
   the label was accepted as a reason to keep the loop open. Finding defects is the
   reviewer's job; deciding which defects stop a change from shipping is not. Put
   the question "who is blocked by this today" to both, and neither answers: this
   repository has nine merge commits, `--last-n` is not passed by the role's
   default, and `.shell-team/reviews/` holds no directory and no broken symlink.
   Three rounds and a large token spend went into hardening against repository
   states nobody here is in, while the item issue #28 calls its most important —
   a channel for capturing human interventions — has not been started. v3 fixes
   what fires on the default path, bounds the regression lock, and stops.
2. **Two plumbing fixes (new AC8, AC9).** The directory enumeration no longer
   conditions an assignment on a preceding test, and ends with an unconditional
   success, so an entry that matches the suffix without being a regular file is
   counted rather than fatal. The capped window no longer pipes the full log into a
   reader that exits early, so the SIGPIPE path is gone. AC8's scope is the two
   functions this revision edits — not a file-wide sweep, which is a Non-goal.
3. **One bounded regression lock (new AC10)**, for the class QA correctly recorded
   at round 3 as having none. One output invariant, a closed list of nine states,
   the count pinned in both directions so the list cannot grow by accretion, and an
   explicit statement of what it does not claim. No fuzz harness.
4. **Six criteria retired.** Listed with reasons in `## Retired criteria` below.
   Net 33 → 30.
5. **Two reachable input classes promoted from nowhere to declared** (classes 9 and
   10): an operating-directory entry that matches the suffix without being a
   regular file, and a merge log exceeding the pipe buffer. Both were reachable all
   along; the second is the only size threshold this spec accepts as in scope,
   because it was measured on a default construct rather than imagined.
6. **The escalation boundary is now written into the Input space** as out-of-scope
   item 1, so the next round has something to point at instead of re-litigating how
   adversarial is adversarial enough.
7. **Unchanged on purpose**: the inverted default and its chokepoint, the eight
   promotion sites pinned in both directions, the `DS-n` inventory, the checker's
   three-outcome cross-check, the git-derived window, the demotion of `gh`, the
   eight-input ledger, both round-1 fixes, and AC30's bare-name convention. The
   decision-layer class is closed and three independent parties confirmed it.

## Retired criteria

Retiring a criterion retires the assertion, never the work. Every file these named
stays exactly as it is, and AC26's allow-list still lists it, so nothing here is
an invitation to revert.

| v2 criterion | Why it is retired |
|---|---|
| **v2 AC8** — no `jq`/`yq`/`python`/`perl`/`node` in `bin/retro-inputs.sh` | A standing repository rule (`CLAUDE.md`: `bin/` stays pure bash, zero-dependency), not an outcome of this task. It never fired, and it carried a hazard needing its own note — a comment reading `depends on … jq` at end of line trips the criterion's own pattern. Review and the CI shellcheck step cover the ground; v3 adds no external tool call at all |
| **v2 AC20** — the trust-boundary sentence pinned byte-exact in `bin/check-retro.sh`'s header | Pins the bytes of a comment. The limit it protects is stated in this spec's `## What this mechanism does not deliver`, which is inside the recorded intent and therefore the stronger record. A byte pin on a comment adds nothing to the mechanism and costs an agreement update to reword |
| **v2 AC22** — `bin/team-init.sh` scaffolds `<base>/provenance/.gitkeep` | Already asserted by `tests/team-init/run.sh`, which CI runs on every pull request. Re-asserting a CI-enforced property in the spec adds a verification pass without adding protection. The suite still runs, in AC27 |
| **v2 AC23** — the template's `## Retro inputs` section sits before `## Keep（…）` | Documentation placement, load-bearing for nothing: `bin/retro-inputs.sh` emits the heading itself, so a real retro's ledger placement comes from the producer, not from a human copying the template. `bin/check-prompt-sync.sh` still requires the twelve canonical lines to be present in the template |
| **v2 AC27** — the distinct `docs/loop-engineering/*` set referenced by the role and the template is exactly two | The risk it guarded was a rewrite of the role's sections adding a pointer to a nonexistent document. That rewrite has happened and been reviewed. v3 does not touch either file, and AC26's allow-list is what now prevents it — a stronger guarantee than a content grep, and one that does not also forbid a legitimate removal |
| **v2 AC28** — the count of lines carrying a full-width parenthesis in `bin/check-retro.sh` is unchanged from the base ref | A proxy for "no Japanese required token was added", and a leaky one: it breaks for a comment that merely mentions a Japanese heading, and it goes stale at merge. AC21 asserts the thing that matters directly — all five heading constants byte-identical — and v3 adds no token of any language to that file |

## Resolved design decisions

### DP-1 — the ledger lives under its own English `## Retro inputs` heading

The alternative was `## Notes`. The dedicated heading wins for a mechanical
reason: a section that ends at the next `## ` is a **closed region**, and inside a
closed region an unrecognised non-blank line can be a violation. Inside `## Notes`
— free prose by design — it cannot be, so a missing or mistyped ledger line would
have to be tolerated. All of AC18 depends on the region being closed: a ledger in
`## Notes` could have no "unrecognised line" rule, no "line outside the region"
rule, and therefore no agreement cross-check. The heading is also why the ledger
can be *pasted*: the producer emits the heading and its lines together.

### DP-2 — the chokepoint is a promotion, and it sits between determination and emission

v1 had a single formatter and treated that as the chokepoint, but a formatter that
accepts any status from any caller is a funnel with no filter. Each input's status
is `unavailable` until a promotion function is called, promotion requires an
affirmative determination, and the formatter renders whatever the table holds at
the end. Three consequences worth naming:

- A probe that returns early, aborts under `errexit`, or has an unhandled branch
  produces `unavailable` rather than nothing and rather than something benign.
- The number of places a benign status can be produced becomes **countable**, which
  is what makes an omission class checkable at all: you cannot grep for an absent
  guard, but you can pin the number of promotion sites at eight and require an
  inventory row and a fixture for each.
- The enum stays closed in both directions: an unrecognised status is an error and
  a missing id is an error, so "I did not mention that input" cannot read as "that
  input was fine".

**What v3 adds to this decision, and why it is a different problem.** The
inversion protects the *contents* of the ledger. It cannot protect the ledger's
*existence*: a script that dies before its emission pass prints nothing at all,
and no default value helps. That is the second class, and the answer is not a
third mechanism but a much smaller one — remove the two constructs measured to
abort, and lock the invariant "a ledger was printed" over a closed list of states.
Recorded explicitly because the temptation, having inverted one default
successfully, is to invert something else.

### DP-3 — `bin/team-paths.sh` gains a `provenance` key; the legacy hardcodes are a separate issue

Synthesising `base + /provenance` inside `bin/retro-inputs.sh` would put the
knowledge of the directory's name in two places, and this project's most frequent
recorded defect is a second copy drifting from the first. The key goes in the
resolver.

`skills/run/SKILL.md`, `skills/goal/SKILL.md`, `agents/engineer.md`,
`agents/qa-verifier.md`, `agents/codex-reviewer.md`, `agents/drift-evaluator.md`
and the generated `templates/prompt-blocks/playbook-engineer.md` /
`playbook-pm-spec.md` blocks all spell the provenance path as the legacy
`tasks/provenance/<task-id>.md`, while this repository's files are at
`.shell-team/provenance/`. **A separate issue, not T-1001**: the hardcodes are
stale-but-covered (each file's operating-paths note already says the `tasks/…`
spellings name the same artefacts in the legacy layout); three sites sit inside
generated marker regions changeable only through `bin/playbook-promote.sh`, which
this task may not run; and a correct fix is a cross-cutting inventory across
seven-plus files needing its own completeness criterion.

### DP-4 — the lessons log is located only from an explicit argument

There is no `lessons` key in `bin/team-paths.sh` and the file does not exist here
(issues #23 and #24, both open). Probing a fixed candidate list invents a path
convention that #24 would then have to contradict; inventing a resolver key *is*
#24. So the path comes from `--lessons PATH`, and with nothing supplied the status
is `unavailable` with the reason stated. When #24 lands, the status flips to `read`
with no grammar change.

### DP-5 — the rule applies to the retro that already exists

Applying it only going forward needs a grandfathering rule, and a date-based
exception inside a checker is a second rule adopters inherit and nobody removes.
Adding the section to the existing retro is a **transcription rather than a
reconstruction**: that file already records in its own `## Notes` that `gh` was
unusable and that the lessons log does not exist here, and in its
`## Orchestrator attest` that the pull-request metadata came through another
channel. Those are the statuses. The CI dogfood step therefore covers
`.shell-team/retros/*.md` unconditionally, with no exclusion to explain.

### DP-6 — a squash-merge history reports `empty`, and that is the whole answer

Substituting a different window would mean two definitions of "cycle" behind one
ledger line, which is the ambiguity this task exists to remove. Note the
sharpening from v2: `empty` requires the history to have been **confirmed**
complete — a shallow repository with zero merges is `unavailable`, because there
the same observation has two possible causes. Giving a squash-merge repository a
first-class window of its own is a real gap and a follow-up issue, not a silent
fallback.

### DP-7 — `develop` is the default and `HEAD` is the fallback, and every branch says so

`bin/discover-work.sh` sets the precedent with a bare `develop` default and a
`--base` override. This task adds one step: when `develop` does not resolve, the
window is taken from `HEAD` and the detail says a fallback was used. A mandatory
`develop` would make the normal case `unavailable` for every adopter whose default
branch differs; reporting the ref actually used is what makes the two-step default
safe. The declaration appears in **all three** status branches. And the probe that
decides whether `develop` resolves distinguishes "it does not exist" from "git
could not answer" — a probe that cannot answer is not evidence that the ref is
missing.

### DP-8 — canonical bytes live in exactly one place per kind

The twelve enumeration lines live in `templates/prompt-blocks/retro-inputs.md` and
are verified into their four consumers by `bin/check-prompt-sync.sh`. Every other
canonical line this task adds — the optional-lessons sentence, the sanitisation
sentence, the hand-off tally line, the four rule-4 violation messages, AC10's
invariant sentence and its nine state labels — exists in this spec only as the
`grep` pattern of the criterion that pins it.

## What this mechanism does not deliver

Said plainly, because this repository has a recorded history of criteria that
claim more than their mechanism supports.

The ledger check validates **structure**. It confirms that a retro declares a
status for every input, that each status is one of three known values, and that
each declaration carries a reason. It cannot confirm that any of them is true. A
retro that writes `status: read` is not thereby proven to have read anything, in
exactly the way `bin/check-provenance.sh` confirms that a decision carries a
`grounding:` line without judging whether the citation is real. No criterion here
asserts otherwise: AC6 and AC23 assert that a ledger is well-formed and complete,
never that it is honest.

The inverted default is a **bias, not a proof**. It guarantees that a status
nobody determined is `unavailable`; it does not guarantee that a determination
someone did make was correct. What it buys is that the failure mode of *omission*
lands on the safe side, and that the sites where a wrong determination could
matter are eight, enumerated, and individually exercised.

**AC10 is bounded, and its boundary is the point.** It proves the output invariant
holds for nine named repository states. It does not prove that no other shell
construct in the script can abort before emission, and no criterion here should be
read as proving that. An unbounded version of this claim is unfalsifiable, and
pursuing it is what took this task three rounds past usefulness — which is why the
state count is pinned in both directions rather than left open to grow.

The same limit applies to the fixture-label criteria (AC4, AC5, AC7, AC10, AC11,
AC13, AC14, AC15, AC16, AC19, AC21). A label proves a case exists; AC10, AC17,
AC19 and AC22's suite runs prove every case passes; neither proves the label is
attached to an assertion that tests what its name says. That is a reading job, and
it belongs to QA and to the cross-provider review.

## Measured tree facts

Issue #28's first acceptance requirement is that every claim about what an input
currently does be measured against this tree. Rows marked **(v2)** were measured
against the implementation v2 revised; rows marked **(v3)** against the one v3
revises.

| Claim | Where it was measured |
|---|---|
| The merged-PR query asks for `--base main` | `develop:agents/scrum-master.md`, input 1 of `## Inputs you read` |
| `--base main` occurs exactly once in the pre-task tree | repository-wide search; the single hit is that line |
| `bin/team-paths.sh --get` accepted `base\|todo\|loops\|runs\|retros\|reviews\|specs` — no `lessons` key, no `provenance` key | the `case "$GET_KEY"` block, the header usage comment, and `print_help` |
| `.shell-team/provenance/` holds four files and no `.gitkeep`, and `bin/team-init.sh` scaffolded only `runs`, `retros`, `reviews`, `specs` | directory listing; the `ensure_gitkeep` calls |
| `agents/scrum-master.md` carries **no** prompt-block marker region; it is registered in `contain` mode only | `templates/prompt-blocks/registry.txt` rows 2, 5 and 8 |
| `operating-paths-core.md`'s only non-empty line is `on PATH when the plugin is loaded; else` | the file |
| `docs/loop-engineering/loop-traps.md` and `model-tiering.md` do not exist; the distinct referenced set across the role and the template is exactly those two paths | directory listing; targeted search in both files |
| `.shell-team/.gitignore` ignores `runs/`, so run telemetry is present locally and absent from a fresh clone while `.shell-team/runs/.gitkeep` stays tracked | the ignore file and the tracked-file listing |
| The existing retro records that `gh` was unusable, that the lessons log does not exist here, and that PR metadata came from another channel | `.shell-team/retros/2026-07-28.md` |
| `docs/templates/retro-template.md` does **not** pass `bin/check-retro.sh`: its Lesson section carries a bare `` - `<...>` `` bullet | the template against rule 3 |
| `tests/discover-work/fixtures/gh` is an env-driven stub whose `pr` branch exits 3 if any argv mentions `body` | the stub |
| `bin/discover-work.sh` defaults to `BASE="develop"`, exposes `--base BRANCH`, fail-softs on a missing `gh`, and sanitises untrusted titles | its argument parsing, `gh` readiness block, and `sanitize()` |
| **(v2)** Rule 4's region walk matched `/^## Retro inputs$/` with no CR strip while rule 2's helper did strip a trailing CR, so a CRLF file's heading was found and its region never entered | the rule-4 awk program against `has_exact_line` |
| **(v2)** The directory report guarded `-d` and `-r` and not traversability | `report_dir_input()` |
| **(v2)** Shallow detection read `$(git rev-parse --git-dir)/shallow`, the worktree-specific directory in a linked worktree | `compute_cycle_window` |
| **(v3)** `count_dir_entries` ends its per-entry work with `[ -f "$f" ] && DIR_N_MATCH=…` inside a `case` branch, so the function's last executed command returns 1 for an entry that matches the suffix without being a regular file; the call site is bare, so `errexit` ends the script before any ledger line is printed | `bin/retro-inputs.sh`, `count_dir_entries` and its call site in `report_dir_input` |
| **(v3)** The same `&&`-conditioned-assignment shape appears twice more, in the qualifier block, where it survives only because an assignment follows it — an order dependency, which is why one reproduction of the defect was initially hidden | `compute_cycle_window`'s qualifier block |
| **(v3)** The capped window is built as `printf '%s\n' "$log_out" \| head -n "$last_n"`, so the writer takes a SIGPIPE once the log exceeds the pipe buffer and `pipefail` turns that into a failed assignment | `compute_cycle_window`, the cap branch |
| **(v3)** `--last-n` has no default value and `agents/scrum-master.md` documents `default: no cap`, so the SIGPIPE path is opt-in while the enumeration path is not | the argument parser and the role's `## Loop` step 1 |
| **(v3)** `tests/errexit-safe/run.sh` locks the `die`/`exit N` contract shape, not an abort before output | that suite's own header and assertions |

## Body-to-AC correspondence

| Body directive | Where |
|---|---|
| `unavailable` is the default; a benign status is a promotion | AC2 |
| Exactly one formatter, two promotion functions, eight promotion sites | AC2 |
| Probing is separate from emission; all eight ids always emitted, in canonical order | AC3 |
| Each promotion site states what happens when its determination cannot be made | AC4 |
| Each promotion site has a fixture that makes its determination impossible | AC4 |
| A directory that cannot be enumerated is `unavailable`, never `empty` | AC5 |
| Shallow detection is correct from a linked worktree | AC5 |
| "Ref absent" and "git could not answer" are different answers | AC5, AC14 |
| The script reaches its emission pass or exits with a usage error, nothing between | AC8, AC9, AC10 |
| An entry matching the suffix that is not a regular file is counted, not fatal | AC8, AC10 |
| The enumeration function ends with an unconditional success | AC8 |
| No `&&`-conditioned assignment in the two functions this revision edits | AC8 |
| The scope of that rule is those two functions, not the whole file | AC8 (its own wording), Non-goals |
| No pipeline feeds a reader that can exit before its writer finishes | AC9 |
| One bounded lock, nine states, count pinned in both directions | AC10 |
| The lock claims nothing about undiscovered plumbing defects | AC10 (its own wording), Input space out-of-scope 1 |
| No fuzz harness | AC10 (its own wording), Non-goals |
| The cycle window is derived from git, not from `gh`, not hardcoded | AC13 |
| The hardcoded `main` base is removed from the operative surface | AC25 |
| `gh` is optional enrichment; absent, the retro is not degraded | AC11 |
| `gh` is never asked for `body`; the field set is exactly six | AC12 |
| The ledger records `read`/`empty`/`unavailable` per declared input | AC6 |
| The ledger is complete: all eight ids, exactly once each | AC3, AC6, AC10, AC14 |
| Each `detail:` is non-empty and a `read` detail says how much | AC6 |
| The grammar is exactly three ` — `-separated fields | AC6 |
| The enumeration exists in one file, enforced not asserted | AC3 (order), AC27 (`check-prompt-sync` green) |
| Every artefact path resolves through `team-paths.sh` | AC7 |
| The checker validates a closed enum and fails closed | AC20 |
| "Located and validated", "absent" and "could not be read" never coincide | AC18 |
| Two independent determinations of section entry must agree | AC18 |
| A duplicate section heading, and a ledger-shaped line outside the region, are violations | AC18, AC20 |
| A whitespace-only detail is a violation | AC18, AC20 |
| A tolerance claim is proved by a malformed input | AC19 |
| The agreement backstop is proved by a mutation self-check on a copy | AC19 |
| No Japanese required heading is added, removed or reworded | AC21 |
| The five decorated headings and the label rule are untouched | AC21 |
| Rule 3 is CR-tolerant already and is confirmed by fixture, not rewritten | AC21 |
| `team-paths.sh` gains a `provenance` key (DP-3) | AC22 |
| The ref used is named in every cycle-window branch, fallback included | AC13 |
| Every applicable qualifier is stated, cap and shallow together | AC13 |
| A confirmed-complete zero-merge history is `empty` (DP-6) | AC14 |
| Attacker-controlled text cannot forge a ledger line | AC15 |
| The emitted ledger passes the checker end to end | AC15 |
| The lessons log is optional (DP-4) | AC16 |
| The rule applies to the existing retro (DP-5) | AC23 |
| CI dogfoods the checker, runs both suites, and exercises the acquisition path | AC24 |
| `bin/retro-inputs.sh` writes nothing | AC29 |
| The change stays inside its declared surface | AC26 |
| Nothing that already worked stops working | AC27 |
| The provenance record exists and is conformant | AC28 |
| Agent instructions invoke the script by bare name; no adopter-tree assumption | AC30 |
| The role declares the mechanism that actually runs, and reports the tally | AC30 |
| Retiring a criterion does not retire the work it named | **info-only (not promoted to AC)** — a statement about this document's own history; the mechanical consequence is that AC26's allow-list is unchanged, which is checked |
| No negated grep without a same-target positive control | **info-only (not promoted to AC)** — a rule about how the criteria are written, applied inside AC7, AC8, AC9, AC12, AC16, AC25, AC29 and AC30; a criterion asserting the shape of other criteria would be checking this document rather than the deliverable |
| Every claim about a current input is measured against this tree | **info-only (not promoted to AC)** — constrains this spec's authoring; `## Measured tree facts` is the artefact, and AC25's base-blob read is the one mechanically provable part |
| The ledger check validates structure only and proves nothing about honesty | **info-only (not promoted to AC)** — a statement of what is *not* claimed; promoting it would need a criterion asserting the absence of an assertion. Enforcement is that no AC claims more, which the correspondence table makes auditable |
| The inverted default is a bias, not a proof | **info-only (not promoted to AC)** — bounds what AC2 and AC4 may be read as proving; cannot itself be checked |
| A fixture label proves presence, not attachment to a real assertion | **info-only (not promoted to AC)** — a declared limit on the label-owning criteria, handed to QA and the reviewer |
| Deciding which defects stop a change from shipping is the coordinator's job, not the reviewer's | **info-only (not promoted to AC)** — a coordination-layer lesson, recorded in `## What changed at v3` because it is the actual cause of this revision; it has no deliverable to check |
| Unicode line separators and bidi controls are not stripped | **info-only (not promoted to AC)** — a Non-goal with three reasons; the property that *is* required (no forged ledger line) is AC15's and holds independently |
| The exhaustive plumbing sweep, `tests/errexit-safe` extension, the four round-4 minors, the salience channel, single-pass obligations, mandatory attest, dead pointers, transcripts, and issues #23/#24 are out of scope | **info-only (not promoted to AC)** — Non-goals; AC26's allow-list is the one mechanically held part, the rest are absences no grep can distinguish from "not yet written" |

## Assumptions

- **The two plumbing reproductions are the coordinator's measurements**, restated
  here against the source lines pm-spec read for itself. The `(v3)` rows of
  `## Measured tree facts` are what this spec verified: the code paths that produce
  those behaviours, and the order dependency that hid one of them.
- **The pipe-buffer threshold is environment-dependent.** Around 64 KB was
  measured; a different platform may differ. AC10's merge-log state should
  therefore be driven with a canned log far larger than any plausible buffer rather
  than one sized to the measured figure, so the case is deterministic wherever it
  runs.
- **The nine-merged-pull-requests measurement in issue #28 is taken on trust.**
  pm-spec has no shell in this role. Nothing in the criteria depends on it.
- **`develop` exists as a local branch in the checkout where the criteria are
  run.** AC25 and AC26 read `develop` directly. In a CI checkout it may exist only
  as a remote-tracking ref; both are for local and QA use, and CI does not evaluate
  this spec.
- **`shellcheck` is installed locally at the pinned 0.11.0.** AC24 invokes it
  unconditionally on purpose.
- **A shallow repository can be simulated without cloning**, and a linked worktree
  can be created with `git worktree add`. Both matter because `git clone --depth`
  has been denied by sandbox policy here before. The criteria name the behaviour,
  not the technique.
- **`git rev-parse --is-shallow-repository` is available** (git 2.15+), and is the
  worktree-correct probe. On an older git the inverted default applies and the
  cycle window is `unavailable` — a declared absence rather than a wrong `empty`.
- **`run-telemetry` legitimately differs between the maintainer's checkout and a
  fresh clone**, which is why AC6 pins the ledger's shape rather than a status for
  that input.
- **`bin/` purity is still required** even though the criterion asserting it is
  retired: it is a standing rule in `CLAUDE.md`, and v3 adds no external tool call.

## Open questions

None blocking. Five things were decided rather than asked: the ledger's placement
(DP-1), the chokepoint's placement (DP-2), the retroactive backfill (DP-5), the
exclusion of the legacy provenance hardcodes (DP-3), and — new at v3 — the
boundary of the abort-before-emission lock at nine enumerated states (AC10 and
Input space out-of-scope 1).

## Notes for engineer

**What v3 changes, and nothing else.** `bin/retro-inputs.sh` (two constructs),
`tests/retro-inputs/invariants.sh` (new), `.github/workflows/check-handoff.yml`
(shellcheck list plus one step), and this task's board entry, provenance file and
review record. Do not reopen `agents/scrum-master.md`,
`docs/templates/retro-template.md`, `bin/check-retro.sh`, `bin/team-paths.sh` or
`bin/team-init.sh` — the criteria that read them assert current state, and AC26's
allow-list permits them only because earlier rounds already changed them.

**The enumeration fix.** Replace the `&&`-conditioned assignment with an
`if`/`fi`, and end `count_dir_entries` with a literal `return 0` so the function's
status never depends on which entry happened to come last. Do the same to the two
qualifier assignments in `compute_cycle_window`. Leave `&&` inside `if` conditions
alone — it is correct there, and AC8's pattern only forbids an assignment as the
right-hand side.

**The cap fix.** A here-string or a read loop instead of a pipe. Either removes the
SIGPIPE path; the here-string is one line.

**The invariants test.** One file, nine states, one assertion helper. For each
state: run the script, capture stdout and the exit status, and assert the
invariant — heading present, exactly eight `- input: ` lines with an enum status
and a non-empty detail, exit status 0 or 2. Two practical notes. The merge-log
state is best driven through the fixture `git` stub emitting a canned log of a
megabyte or so, which is fast, deterministic, and independent of the host's
pipe-buffer size; building thousands of real merge commits would be slow and would
still be buffer-size-dependent. And none of the nine states is a usage error, so
all nine are expected to exit 0 — the invariant admits 2 so the wording stays
reusable, and the eight-line requirement is what actually keeps a spurious exit 2
from passing, since the usage path prints no ledger.

**Before you hand off**, mutate each of the three new locks and watch it fail.
Restore the `&&`-conditioned assignment and confirm both AC8 and the
`.md`-directory state turn red. Restore the `| head` pipe and confirm the
merge-log state turns red — if it does not, the canned log is too small and the
case proves nothing. Delete one state label and confirm AC10's count of nine turns
red. A lock you have not seen fail is a lock you have not tested.

**Prior art worth reading before writing anything.**
`bin/discover-work.sh` for the `--base` default, the `gh` fail-soft path and
`sanitize()`; `tests/discover-work/fixtures/gh` for the env-driven stub shape;
`tests/errexit-safe/run.sh` for how this repository writes an assertion about a
shell construct — noting that its subject is the `die`/`exit N` contract, a
different class from an abort before output, which is why AC10 lives beside the
script it protects instead of being added there.
