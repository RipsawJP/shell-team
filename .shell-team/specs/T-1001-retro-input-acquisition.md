# T-1001 — retro input acquisition: a git-derived cycle window and a machine-checked input ledger

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v2 (the version of record for this task's intent lives on the board and nowhere else)
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

**What v1 of this task got wrong, and why v2 exists.** v1 declared the right
statuses and then defended them the wrong way round: benign was the default, and
each adverse condition got its own hand-written guard. Three independent defects
followed, and all three were the same class —
`unevaluable-condition-reported-as-benign`. A ledger with one input id and no
status at all produced nine violations in LF and **zero** in CRLF, because the
section-detection rule was not CR-tolerant and "could not find the section"
became "the section was fine". A directory holding two files but not traversable
was reported `empty`, because the guard tested read permission while enumerating
entries needs search permission — the exact substitution this whole task exists
to prevent. And a shallow repository was reported non-shallow from inside a
linked worktree, because the shallow marker lives in the common directory. N
hand-written guards need all N to be right; that is why the class repeated. v2
inverts the default instead of adding a fourth guard.

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

- **The salience / intervention capture channel.** Issue #28's direction 3 and
  its trigger points 1, 3 and 5 — the moments a human interrupted, a measurement
  contradicted an assumption, work was abandoned — are the most valuable material
  named in that issue and are deliberately not in this task. This task fixes the
  inputs that already exist and are wrong; a new channel is its own design with
  its own write surface, and mixing the two would make neither reviewable.
- **What single-pass work owes the retro** (direction 4). Untouched here.
- **Making `## Orchestrator attest` mandatory** (direction 5). It couples to
  issue #20's open problem about which language a generated artefact is written
  in, and this task must not deepen that; the section stays the optional
  convention `docs/templates/retro-template.md` already makes it.
- **The dead `docs/loop-engineering/` pointers.** `loop-traps.md` and
  `model-tiering.md` are referenced four times over three lines in
  `agents/scrum-master.md` and three times in `docs/templates/retro-template.md`,
  and neither file exists in the tree. They are left exactly as they are, and
  AC27 holds the referenced set in place so this task cannot add a fifth pointer
  to a document that does not exist.
- **Whether the retro may read local agent transcripts.** Issue #28 records that
  as an open question and does not propose it; this task does not answer it.
- **A `lessons` key for `bin/team-paths.sh` (issue #24) and the lessons corpus
  import (issue #23).** Both are open. This spec therefore assumes **no
  resolvable lessons path exists**, treats the lessons log as an optional input,
  and locates it only from an explicit argument (DP-4).
- **Correcting the `tasks/provenance/<task-id>.md` hardcodes** in
  `skills/run/SKILL.md`, `skills/goal/SKILL.md`, `agents/engineer.md`,
  `agents/qa-verifier.md`, `agents/codex-reviewer.md`, `agents/drift-evaluator.md`
  and the generated `templates/prompt-blocks/playbook-*.md` blocks. See DP-3: a
  separate issue, not this task.
- **An alternative cycle window for squash-merge-only repositories.** A history
  with no merge commits, confirmed complete, reports `empty` with a detail saying
  why. Giving such a repository a different window is a design decision this task
  declines (DP-6).
- **Making `docs/templates/retro-template.md` itself pass `bin/check-retro.sh`.**
  It does not pass today: its `## Lesson 候補（…）` section carries a bare
  `` - `<...>` `` bullet that rule 3 rejects. No CI step is added that would
  require it to.
- **Any change to the five decorated Japanese H2 headings, the
  `` `[common]` ``/`` `[target-specific]` `` label rule, or the exit-code
  contract of `bin/check-retro.sh`.** AC19 and AC28 hold them in place.
- **Rewriting rule 3's region walk.** The Lesson-candidate region is matched by
  prefix rather than by an anchored full line, so it is CR-tolerant already. This
  task adds a fixture proving that (AC19) rather than restructuring a rule that
  does not carry the defect.
- **Stripping Unicode line separators (U+2028 / U+2029) and bidirectional control
  characters in `sanitize()`.** Declined deliberately, and not because a reviewer
  offered it as a follow-up. Three reasons. The machine-parsed surface is
  unaffected: `awk` and `grep` split records on LF, and neither U+2028 nor a bidi
  control is a record separator for any POSIX text tool, so no such character can
  forge a ledger line — the property AC13 exists to protect is intact. The concern
  that remains is a human reader being shown a re-ordered line, which is a
  different requirement ("a tracked artefact must not display differently from its
  bytes") and one that belongs to a repository-wide content guard over every
  tracked file — `bin/check-pii-shapes.sh` is the existing home for exactly that
  shape of control — rather than to one emitter, since the retro is committed and
  a hostile character could enter it by hand. And `tr -d` is byte-oriented and
  cannot delete a multi-byte code point at all, so a fix here means changing the
  sanitiser's tool, i.e. reopening the injection surface in the same round as the
  status-determination class. Filed as its own issue.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup, invokes
scripts as `bash bin/<script>.sh` (never a bare name — that is the *spec's*
invocation convention, distinct from the *agent instruction* convention AC33
governs), and uses `develop` as the base ref where a base ref is needed. **The
exact bytes of every canonical line this task adds are the `grep` patterns
below** — there is no second copy of them elsewhere in this spec to drift from
(DP-8).

Two rules apply to every criterion here, both learned from v1's failures:

- **No negated grep without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` does not exist, because `grep` exits 2 and the negation
  swallows it. Every negative assertion below is preceded by an assertion that the
  same file is present and readable by the same tool. v1's zero-dependency
  criterion did not do this and would have passed against a script that was never
  written.
- **A tolerance claim is proved by a malformed input, never a well-formed one.**
  "This checker tolerates CRLF" cannot be demonstrated by a valid CRLF file
  passing, because a checker that skips the file entirely produces the same
  result. v1 required exactly that fixture, and the CRLF blocker satisfied it.

Some criteria assert a fixture *case* rather than the behaviour directly, because
the behaviour needs a purpose-built git history, a permission-restricted
directory, a linked worktree, or a stubbed `PATH` that a `check:` line must not
build in the working repository. Those criteria pin the case's label byte-exact so
deleting the case fails the criterion, and AC15 asserts that every case in the
suite passes. The pair is only as strong as a label attached to a real assertion;
the spec says so plainly rather than pretending otherwise, and verifying that
attachment is QA's and the reviewer's job.

- [ ] **AC1** `bin/retro-inputs.sh` exists, prints help and exits 0 for `--help`,
  and rejects an unknown flag with exit **2** (the usage-error code every script
  in `bin/` uses).
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

- [ ] **AC5** **The three reproduced defects each have a named fixture that pins
  the correct status.** A directory that contains matching files but whose entries
  cannot be stat'ed is `unavailable`, never `empty` — the determination is made by
  confirming the enumeration itself succeeded, not by reading a permission bit: a
  name the glob returned that cannot then be stat'ed means the enumeration is
  incomplete. A shallow repository is detected as shallow **from a linked worktree
  as well as from the primary one**, and a shallow question that cannot be answered
  at all yields `unavailable` rather than the non-shallow branch. The default-ref
  probe distinguishes "the ref does not exist" from "git could not answer", and
  reports the second as `unavailable` with a reason naming it.
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

- [ ] **AC8** `bin/retro-inputs.sh` introduces no runtime dependency beyond bash
  and standard POSIX tools: it invokes no `jq`, `yq`, `python`, `perl` or `node`.
  Two positive controls, because v1's version of this criterion had neither and
  would have passed against a file that did not exist: the file is confirmed
  present and greppable, and the pattern is confirmed to bite on a synthetic line.
  - check: test -f bin/retro-inputs.sh && grep -q -- 'retro-inputs' bin/retro-inputs.sh && printf 'x | jq .\n' | grep -qE -- '(^|[[:space:]|(])(jq|yq|python3?|perl|node)([[:space:]]|$)' && ! grep -qE -- '(^|[[:space:]|(])(jq|yq|python3?|perl|node)([[:space:]]|$)' bin/retro-inputs.sh

- [ ] **AC9** `gh` is optional enrichment, not the acquisition path. With `gh`
  absent the script emits a complete ledger, reports `pr-metadata` as
  `unavailable` with a reason, and **exits 0**; with `gh` present it never
  requests the `body` field. Both are fixture cases, and the fixture `gh` stub
  carries the same hard guard as `tests/discover-work/fixtures/gh` — it fails
  loudly if any argv mentions `body`, so the prohibition is enforced at runtime
  and not only by reading the source.
  - check: grep -qF -- 'case: gh absent -> pr-metadata unavailable, exit 0' tests/retro-inputs/run.sh && grep -qF -- 'case: gh present -> the PR body field is never requested' tests/retro-inputs/run.sh && test -f tests/retro-inputs/fixtures/gh && grep -qF -- 'PR body must not be requested' tests/retro-inputs/fixtures/gh

- [ ] **AC10** When `gh` is used, the requested field set is exactly the six
  structured fields the role already trusts — `number`, `title`, `mergedAt`,
  `author`, `url`, `headRefName` — and no `--json` argument anywhere in the script
  names `body`. The positive grep on the same file is the control for the negative.
  - check: grep -qF -- 'number,title,mergedAt,author,url,headRefName' bin/retro-inputs.sh && ! grep -qE -- '--json.*body' bin/retro-inputs.sh

- [ ] **AC11** The cycle window is **derived from git**, not from `gh` and not from
  a hardcoded branch: merge commits reachable from the resolved base ref along the
  first-parent path. The ref is resolved as `develop` when it resolves and `HEAD`
  otherwise, is overridable with `--base REF`, and **every** cycle-window line —
  `read`, `empty` and `unavailable` alike — names the ref actually used and states
  that a fallback occurred whenever one did. v1 required the ref to be declared and
  its criterion only exercised the branch where it was; two of the three branches
  dropped the declaration. `--last-n N` caps the window, and the detail states
  **every** qualifier that applies rather than the first one: a cap and a shallow
  truncation are different facts and can be true at once. The help text states the
  default and the fallback so an adopter with no `develop` is not left guessing.
  - check: out="$(bash bin/retro-inputs.sh --base HEAD)" && printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: (read|empty|unavailable) — detail: .*HEAD' && grep -qF -- 'git log --merges --first-parent' bin/retro-inputs.sh && bash bin/retro-inputs.sh --help | grep -qF -- 'default: develop, falling back to HEAD' && for l in 'case: default base resolves to develop when it exists' 'case: no develop branch falls back to HEAD and declares the fallback in every status branch' 'case: --last-n caps the window and the cap is declared, distinct from a shallow truncation' 'case: a shallow repository with a cap states both qualifiers' 'case: every ledger is complete (all eight input ids, exactly once)'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC12** Degenerate histories are classified honestly, and this is the part
  of the task most able to make a retro read as sound while resting on nothing.
  A base ref that does not resolve locally is `unavailable` with the ref named — not
  `empty`. A history with zero merge commits, where the ref *did* resolve and the
  history is **confirmed** complete, is `empty`. A shallow repository with zero
  merges inside the boundary is `unavailable`, because "no merges" and "merges
  beyond the boundary" are indistinguishable there. A shallow repository that does
  find merges is `read` with the truncation declared. A failing `git` invocation
  is `unavailable`, the ledger is still complete, and the exit status is still 0.
  The missing-ref case is exercised directly here; the rest are fixture cases,
  because each needs a purpose-built repository or a stubbed `PATH`.
  - check: out="$(bash bin/retro-inputs.sh --base no-such-ref-t1001)" && printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: unavailable — detail: .*no-such-ref-t1001' && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 && test -f tests/retro-inputs/fixtures/git && for l in 'case: --base names a ref that does not exist locally -> unavailable' 'case: zero merge commits (squash-merge history) -> empty' 'case: shallow repository with zero merges in the boundary -> unavailable' 'case: shallow repository with merges -> read with a truncation note' 'case: git invocation failure -> unavailable, complete ledger, exit 0'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC13** Text this script does not control cannot forge a ledger line. A
  merge-commit subject, a pull-request title and a branch name are all
  attacker-controlled in a public repository, and a merge subject carrying
  ` — status: read — detail: …`, a backtick, or an embedded newline must not
  produce a second parseable ledger line. Untrusted text is neutralised before it
  is emitted, the same discipline `bin/discover-work.sh` already applies to a
  candidate title, and the emitted ledger — with adversarial material in it —
  still passes `bin/check-retro.sh` when embedded in a retro.
  - check: grep -qF -- 'untrusted text (a merge subject, a PR title, a branch name) is stripped of CR, LF, TAB and backticks and has U+2014 replaced before it is emitted, so it can never forge a ledger line' bin/retro-inputs.sh && grep -qF -- 'case: adversarial merge subject cannot forge a ledger line' tests/retro-inputs/run.sh && grep -qF -- 'case: the emitted ledger embedded in a retro passes check-retro.sh' tests/retro-inputs/run.sh

- [ ] **AC14** The lessons log is an **optional** input, and its absence is a
  recorded status rather than a gap someone has to notice. With no path supplied it
  is `unavailable` with a reason; with a readable path supplied whose non-blank
  lines could be counted it is `read`. The role's prose says so, and the superseded
  framing that made it a required input is gone.
  - check: test -f agents/scrum-master.md && bash bin/retro-inputs.sh | grep -qE -- '^- input: lessons — status: unavailable — detail: .+' && bash bin/retro-inputs.sh --lessons README.md | grep -qE -- '^- input: lessons — status: read — detail: .+' && grep -qF -- 'The lessons log is OPTIONAL: there is no resolver key for it, so it is read only when a path is supplied, and its absence is recorded as unavailable rather than as a failure.' agents/scrum-master.md && ! grep -qF -- '**Lessons log** — read' agents/scrum-master.md && grep -qF -- 'case: lessons path not supplied -> unavailable' tests/retro-inputs/run.sh && grep -qF -- 'case: lessons path supplied -> read' tests/retro-inputs/run.sh

- [ ] **AC15** `tests/retro-inputs/run.sh` exists and **every** case in it passes.
  This is the criterion that makes every label lock above mean something. A
  positive control guards against a stub suite that passes by doing nothing: it
  must drive the script under test at least eight times.
  - check: test -f tests/retro-inputs/run.sh && test "$(grep -c -- 'retro-inputs.sh' tests/retro-inputs/run.sh)" -ge 8 && bash tests/retro-inputs/run.sh >/dev/null

- [ ] **AC16** **The checker cannot report "could not evaluate" as "clean".** Rule
  4 has three outcomes that never coincide, each with its own message: the section
  was located and its ledger validated; the section is absent; the section's
  heading is present but its ledger region **could not be read**. The third exists
  because that is exactly what happened — the heading was found by one rule and
  the region was missed by another, and the disagreement produced silence. Two
  independent determinations are therefore cross-checked: the CR-tolerant
  heading search and the region walk must agree that the section was entered, and
  a disagreement is its own violation. A second, duplicate `## Retro inputs`
  heading is a violation rather than a silently unvalidated region, and any
  top-level ledger-shaped line that falls outside the walked region is a violation
  too — so a region walk that stops early cannot leave entries unexamined. To
  discuss a ledger line in a retro's prose, indent it.
  - check: for l in '## Retro inputs section heading is present but its ledger region could not be read' 'duplicated ## Retro inputs section heading' 'ledger-shaped line outside the ## Retro inputs section' 'whitespace-only Retro inputs detail'; do grep -qF -- "$l" bin/check-retro.sh || exit 1; done && grep -qF -- 'missing decorated section heading: $RETRO_INPUTS' bin/check-retro.sh

- [ ] **AC17** **A tolerance claim is proved by a malformed input.** The suite's
  CRLF case takes a ledger that is *broken* — an id present with no status, other
  ids missing — converts it to CRLF, and asserts it is **still reported**. v1
  asked for a valid CRLF file to pass, which the CR-unaware region walk satisfied
  by never examining the file, and the blocker shipped. A `detail:` consisting only
  of whitespace is reported for the same reason: "a detail is present" and "there
  are spaces there" are not the same determination. And the agreement backstop of
  AC16 is proved to bite by a **mutation self-check inside the suite**: a copy of
  the checker in a temporary directory, with the region walk's CR handling removed,
  must still report the malformed CRLF ledger. The real script is never modified.
  - check: for l in 'case: a MALFORMED ledger in a CRLF file is still reported (not silently accepted)' 'case: a whitespace-only detail is reported' 'case: with the region walk CR handling removed, a malformed CRLF ledger is STILL reported (agreement backstop)'; do grep -qF -- "$l" tests/check-retro/run.sh || exit 1; done && bash tests/check-retro/run.sh >/dev/null

- [ ] **AC18** Every named malformed ledger is rejected with exit 1, exercised
  directly here rather than only through the suite. Ten committed fixtures: no
  section, unknown status, unknown id, missing id, duplicated id, empty detail,
  whitespace-only detail, an unrecognised line inside the section, a duplicated
  section heading, and a ledger-shaped line outside the section. The canonical
  fixture still passes, which is the positive control.
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-canonical.md >/dev/null && for f in fail-inputs-missing-section fail-inputs-unknown-status fail-inputs-unknown-id fail-inputs-missing-id fail-inputs-duplicate-id fail-inputs-empty-detail fail-inputs-blank-detail fail-inputs-stray-line fail-inputs-duplicate-section fail-inputs-line-outside-section; do test -f "tests/check-retro/fixtures/$f.md" || exit 1; rc=0; bash bin/check-retro.sh "tests/check-retro/fixtures/$f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done

- [ ] **AC19** The checker's existing contract is untouched. All five decorated
  heading constants are byte-identical, so no Japanese heading is reworded,
  renamed or dropped while the ledger rule is added; the repository's own retro
  still passes; and rule 3's own CR tolerance — which it has by construction, since
  it matches its region by prefix — is confirmed by a fixture rather than assumed,
  so this task can state that only rule 4 carried the defect.
  - check: for l in "KEEP='## Keep（続けたい良い動き）'" "PROBLEM='## Problem（直面した課題 / 痛み）'" "TRY='## Try（次サイクルで試すこと）'" "TRAPS='## 罠の点検（Comprehension Debt / Cognitive Surrender）'" "LESSON_PREFIX='## Lesson 候補（'"; do grep -qxF -- "$l" bin/check-retro.sh || exit 1; done && bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null && grep -qF -- 'case: rule 3 still catches an unlabelled Lesson bullet in a CRLF file' tests/check-retro/run.sh

- [ ] **AC20** The ledger check's trust boundary is stated where a reader of the
  checker will see it, in the checker's own header, and in one line that says what
  the mechanism does not deliver.
  - check: grep -qxF -- "# structure only: a retro whose ledger says 'read' is not thereby proven to have read anything." bin/check-retro.sh

- [ ] **AC21** `bin/team-paths.sh` resolves a `provenance` key, in every mode a
  consumer can use: `--get provenance`, `TEAM_PROVENANCE_DIR` in `--export`, a row
  in `--print`, and the key named in `--help`. An unknown key still exits 2, and
  the resolver's own suite covers the default layout and the legacy layout in the
  idiom it already uses.
  - check: test "$(bash bin/team-paths.sh --get provenance)" = ".shell-team/provenance" && bash bin/team-paths.sh --export | grep -qE -- '^export TEAM_PROVENANCE_DIR=' && bash bin/team-paths.sh --print | grep -qE -- '^[[:space:]]+provenance[[:space:]]+\.shell-team/provenance$' && bash bin/team-paths.sh --help | grep -qF -- 'provenance' && rc=0 && { bash bin/team-paths.sh --get no-such-key-t1001 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && grep -qF -- 'default: provenance path wrong' tests/team-paths/run.sh && grep -qF -- 'legacy: provenance path wrong' tests/team-paths/run.sh && bash tests/team-paths/run.sh >/dev/null

- [ ] **AC22** `bin/team-init.sh` scaffolds the provenance directory alongside the
  four it already creates, its usage listing says so, and the scaffolder's own
  suite asserts the file exists on a fresh target.
  - check: grep -qF -- '<base>/provenance/.gitkeep' bin/team-init.sh && grep -qF -- '.shell-team/provenance/.gitkeep' tests/team-init/run.sh && bash tests/team-init/run.sh >/dev/null

- [ ] **AC23** `docs/templates/retro-template.md` carries a `## Retro inputs`
  section, and it sits **before** `## Keep（続けたい良い動き）` — the ledger
  declares the material the rest of the retro rests on, so it is read first.
  - check: grep -qxF -- '## Retro inputs' docs/templates/retro-template.md && awk '/^## Retro inputs$/ { a = NR } /^## Keep（続けたい良い動き）$/ { b = NR } END { exit !(a > 0 && b > 0 && a < b) }' docs/templates/retro-template.md

- [ ] **AC24** The one retro that already exists carries a ledger, so the rule
  applies to every retro in the tree with no date-based exception inside the
  checker (DP-5). Its two unambiguously recorded absences — the lessons log and the
  pull-request metadata — are declared as `unavailable`, and the file passes.
  - check: bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null && grep -qxF -- '## Retro inputs' .shell-team/retros/2026-07-28.md && test "$(grep -c -- '^- input: ' .shell-team/retros/2026-07-28.md)" -eq 8 && grep -qE -- '^- input: lessons — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md && grep -qE -- '^- input: pr-metadata — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md

- [ ] **AC25** CI runs all of it: the two new scripts and both fixture stubs are on
  the shellcheck argument list, the new fixture suite is a step, the declared
  acquisition path is exercised against a real repository, and
  `bin/check-retro.sh` is dogfooded against this repository's own retros — which
  no step does today. `shellcheck` is invoked unconditionally, so a missing
  shellcheck fails the criterion loudly instead of passing it vacuously.
  - check: W=.github/workflows/check-handoff.yml && grep -qF -- 'bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git' "$W" && grep -qF -- 'bash tests/retro-inputs/run.sh' "$W" && grep -qF -- 'bash bin/retro-inputs.sh --base HEAD' "$W" && grep -qF -- 'bash bin/check-retro.sh .shell-team/retros/*.md' "$W" && shellcheck bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git

- [ ] **AC26** The hardcoded release-branch query is gone from the whole operative
  surface. `--base main` occurs exactly once in the pre-task tree, in
  `agents/scrum-master.md`'s merged-PR command; after this task it occurs nowhere
  under `agents/`, `bin/`, `skills/` or `templates/`. Two positive controls: the
  base blob is read first, proving the defect genuinely existed, and the recursive
  grep is proved to be reading those directories before its result is negated.
  **Merge-point-scoped**: it resolves `develop:agents/scrum-master.md` and goes
  stale once this task lands on `develop`. That is expected; do not widen its
  base-ref resolution or re-derive it per rework round.
  - check: git show develop:agents/scrum-master.md | grep -qF -- '--state merged --base main' && grep -rqF -- 'retro-inputs' agents bin skills templates && ! grep -rqF -- '--base main' agents bin skills templates

- [ ] **AC27** No new pointer to a document that does not exist. The set of
  distinct `docs/loop-engineering/*` paths referenced across the role and the
  template is exactly the two that are referenced today — so this task can neither
  add a third nor quietly drop one while rewriting the sections around them.
  - check: test "$(grep -ohE -- 'docs/loop-engineering/[A-Za-z0-9._-]+' agents/scrum-master.md docs/templates/retro-template.md | sort -u | tr '\n' ' ')" = "docs/loop-engineering/loop-traps.md docs/loop-engineering/model-tiering.md "

- [ ] **AC28** Issue #20 is not deepened: the number of lines in
  `bin/check-retro.sh` carrying a full-width parenthesis — the marker of every
  Japanese required token it enforces — is unchanged from the base ref. A positive
  control asserts the count is non-zero, so the equality cannot hold because the
  pattern matched nothing. **Merge-point-scoped**, like AC26: it goes stale once
  this task lands on `develop`, and must not be widened to survive that.
  - check: n="$(grep -c -- '（' bin/check-retro.sh)" && b="$(git show develop:bin/check-retro.sh | grep -c -- '（')" && test "$n" -gt 0 && test "$n" -eq "$b"

- [ ] **AC29** The change stays inside its declared surface: every path in
  `git diff --name-only develop` matches the allow-list below, and the diff is
  non-empty as a positive control. The allow-list includes this task's own
  mandatory records — the provenance file and the review record — so they do not
  read as scope creep. **Merge-point-scoped**: this criterion is tied to the merge
  point it was authored at and is expected to go stale after merge, when later work
  moves `develop` forward. Do not merge-range it, re-derive it per rework round, or
  widen its base-ref resolution — confining the change is the only thing it exists
  to do.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.github/workflows/check-handoff\.yml|\.shell-team/(todo\.md|test-recipe\.md|provenance/T-1001\.md|reviews/T-1001[^/]*|retros/2026-07-28\.md|specs/T-1001-retro-input-acquisition\.md)|agents/scrum-master\.md|bin/(check-retro|retro-inputs|team-init|team-paths)\.sh|docs/templates/retro-template\.md|templates/prompt-blocks/(registry\.txt|retro-inputs\.md)|tests/(check-retro|retro-inputs|team-init|team-paths)/.+)$')"

- [ ] **AC30** Nothing that already worked stops working: prompt sync, the board
  linter on both the shipped template and this repository's board, and every
  fixture suite whose subject this task edits.
  - check: bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash tests/check-retro/run.sh >/dev/null && bash tests/team-paths/run.sh >/dev/null && bash tests/team-init/run.sh >/dev/null

- [ ] **AC31** The task's decision provenance file exists and is conformant, and it
  is located through the new resolver key rather than a hardcoded path — so the key
  AC21 adds is dogfooded by this criterion.
  - check: bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1001.md" >/dev/null

- [ ] **AC32** `bin/retro-inputs.sh` writes nothing. Two consecutive runs leave the
  working tree's git status byte-identical, and no non-comment line invokes a
  file-creating command. The runs must also succeed, which is the positive control.
  - check: before="$(git status --porcelain)" && bash bin/retro-inputs.sh >/dev/null && bash bin/retro-inputs.sh --base HEAD >/dev/null && test "$(git status --porcelain)" = "$before" && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && ! printf '%s\n' "$nc" | grep -qE -- '(mktemp|[[:space:]](tee|cp|mv|rm|touch)[[:space:]])'

- [ ] **AC33** `agents/scrum-master.md` declares the mechanism that actually runs,
  **and invokes it the way this repository documents**: the bare script name, which
  is on `PATH` when the plugin is loaded, with the relative path only ever as the
  parenthetical fallback for running inside this repository. This matters beyond
  style: the plugin's `bin/` is on an adopter's `PATH` but does not exist in an
  adopter's tree, so an instruction to run `bin/retro-inputs.sh` fails there and
  degrades the retro silently — the same failure issue #28 exists to remove,
  reintroduced by the fix. Mechanically: every occurrence of the relative path is
  preceded by `bash `, the bare form appears at least twice, and the role reports
  the ledger's tally in its hand-off while the superseded PR-counting line is gone.
  - check: F=agents/scrum-master.md && test -f "$F" && grep -qxF -- '## Inputs you read' "$F" && test "$(grep -o -- 'bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" -eq "$(grep -o -- 'bash bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" && test "$(grep -o -- '`retro-inputs\.sh`' "$F" | wc -l | tr -d ' ')" -ge 2 && grep -qF -- 'on `PATH` when the plugin is loaded' "$F" && grep -qF -- 'Retro inputs: <n> read / <n> empty / <n> unavailable' "$F" && ! grep -qF -- 'Inputs read: <count> PRs' "$F"

## Input space

**Reachable input classes** — what real usage of this mechanism can produce, and
what the implementation must therefore be correct about:

1. A git work tree whose history reaches the base ref through merge commits, with
   subjects of the form `Merge pull request #N from <owner>/<branch>`. In a public
   repository those subjects embed a pull-request title or branch name, i.e.
   attacker-controlled text, which can contain backticks, a U+2014 EM DASH, quote
   characters, and — through a crafted branch name — the ledger grammar itself.
2. A git work tree with **zero merge commits**: a squash-merge-only project, which
   is GitHub's default for many repositories.
3. A **shallow** repository (`git clone --depth`, or any tree carrying a shallow
   marker), where the history is truncated at a boundary and the absence of a merge
   commit proves nothing.
4. A **linked worktree** (`git worktree add`), where repository-level state lives in
   the common directory rather than the worktree's own git directory — so a probe
   of repository state can answer differently depending on which worktree it runs
   in. This is where the shallow probe was measured wrong.
5. A base ref that does not resolve locally: an adopter whose default branch is
   `main`, and a CI checkout where `develop` exists only as
   `refs/remotes/origin/develop`.
6. A failing or unanswerable `git` invocation: `git` absent from `PATH`, a
   `safe.directory` refusal (reachable in CI containers), an unreadable object
   store, or a `git` too old to answer a particular query. "The ref does not
   exist" and "git could not tell me" are different answers and reach the ledger
   differently.
7. `gh` in all four of its states — absent, present but unauthenticated, present
   and authenticated, and present but failing on one subcommand.
8. Each declared input's location in five states: absent; present and empty;
   present with files; present but not readable; and **present, readable, but not
   traversable** — a directory whose names can be listed while its entries cannot
   be stat'ed. The last is where `empty` was measured to be reported for a
   directory holding two files. The run-telemetry directory reaches two of these
   states routinely in this very repository: `.shell-team/.gitignore` ignores
   `runs/`, so the maintainer's checkout has a populated
   `.shell-team/runs/shell-team.jsonl` while a fresh clone has only the tracked
   `.gitkeep`.
9. A path resolver that does not answer at all, and one that answers with a base
   directory that does not exist on disk.
10. Retro files a checker must judge: a well-formed ledger; a ledger missing an id;
    a duplicated id; a status outside the enum; an id outside the enum; an empty
    `detail:`; a `detail:` of whitespace only; a stray non-bullet line inside the
    section; no `## Retro inputs` section at all; **two** `## Retro inputs`
    headings; a top-level ledger-shaped line outside the section; and **CRLF line
    endings, in a file whose ledger is malformed** — the combination that was
    measured to pass clean.
11. A ledger whose `detail:` free text **quotes the ledger grammar** — this
    repository's own habit of describing a mechanism inside the artefact the
    mechanism governs, the class `bin/check-provenance.sh`'s header already records
    for its own markers.
12. Both supported layouts (the `.shell-team/` default and the legacy `tasks/`
    split-root layout) and a `$TEAM_RUN_BASE` override.

**Out-of-scope synthetic extremes** — named and declined:

1. Adversarially large inputs: megabyte-scale commit subjects or pull-request
   titles, tens of thousands of merge commits, a retro with thousands of ledger
   lines. Real material is bounded by what a review cycle produces.
2. Non-UTF-8 or mixed-encoding retro files and commit messages, NUL bytes inside a
   commit subject, and Unicode line separators (U+2028 / U+2029) or bidirectional
   control characters in untrusted text. None of these is a record separator for
   any POSIX text tool, so none can forge a ledger line; the display-level concern
   is declared a Non-goal above with its reasons.
3. A retro crafted to defeat the section parser through markdown notation rather
   than line endings: `## Retro inputs ##` in ATX-closing form, or the heading
   inside a fenced code block. `bin/check-board-headings.sh`'s own header records
   that this matching weakness is deliberately left in place in
   `bin/check-handoff.sh`; this task adds a section, it does not harden markdown
   parsing. CRLF is explicitly **not** in this class — it is reachable class 10.
4. A hostile `git` or `gh` earlier on `PATH` returning well-formed but fabricated
   output. The ledger is a discipline aid for a trusted, committed, reviewed
   artefact, not a security boundary against an adversarial author — the same
   trust boundary `bin/check-acs.sh` and `bin/check-provenance.sh` declare for
   themselves. The fixture stubs exist to *simulate* absence and failure, not to
   model an attacker.
5. Malformed or reordered `gh` JSON. Field extraction uses `gh`'s own built-in
   `--jq`, as `bin/discover-work.sh` already does; re-implementing a JSON parser
   in bash is out of scope.
6. Concurrent retro runs racing on the same output path. The existing numeric
   suffix collision rule is untouched and no new concurrency guarantee is claimed.
7. Local agent transcripts. Issue #28 raises whether they are material at all and
   does not propose it; they are not an input class here.

<!-- END intent-block: T-1001 -->

## What changed at v2

For the approval record. The skeleton is unchanged and stays unchanged
deliberately: the git-derived cycle window, the demotion of `gh` to enrichment,
the eight-input ledger, and the region walk were each verified independently by QA
against fixtures and found sound. What changed is the direction of the default and
the location of the chokepoint.

1. **Inverted default (new AC2, AC3, AC4, AC5).** v1 said what each status means
   and left the engineer to guard every adverse condition individually; three
   guards were missing and the same class repeated three times. v2 makes
   `unavailable` the initial value of every ledger line, confines `read` and
   `empty` to two promotion functions with exactly eight call sites, separates
   probing from emission, and requires a decision-site inventory in which every
   promotion site states what happens when its determination cannot be made — with
   a fixture per site that makes the determination impossible.
2. **The checker gets the same inversion (rewritten AC16).** "Located and
   validated", "absent" and "could not be read" are now three outcomes that cannot
   coincide, cross-checked between the heading search and the region walk, plus a
   violation for a duplicate heading and for any ledger-shaped line the walk did
   not examine.
3. **Tolerance claims are now proved negatively (new AC17).** v1's CRLF criterion
   asked for a valid CRLF file to pass — a requirement the CRLF blocker satisfied
   by skipping the file. v2 requires a malformed CRLF ledger to still be reported,
   plus a mutation self-check in the suite that removes the CR handling from a copy
   of the checker and confirms the backstop still catches it.
4. **Five of the six deferred minors folded in** (AC5, AC11, AC16, AC17, AC18),
   each because it is an instance of the class being closed, not because it is
   cheap. The sixth is declined in Non-goals with its reasons.
5. **The bare-name invocation Major (new AC33)**, a different class —
   `adopter-environment-coercion` — but the same round.
6. **Two of v1's own criteria were vacuous and are fixed** (AC8, AC26). Both
   negated a grep against a file without first proving the file was readable by the
   same tool, so both would have passed against a file that did not exist. The
   rule is now stated at the head of the criteria section and applied throughout.
7. **Linked worktrees and non-traversable directories are now declared reachable
   input classes** (10 → 12 classes), because both were reachable all along and
   their absence from the declaration is why no criterion asked about them.

## Resolved design decisions

### DP-1 — the ledger lives under its own English `## Retro inputs` heading (unchanged at v2, and re-examined)

The alternative was `## Notes`, where the one retro that exists already records
its gaps in prose. The dedicated heading wins for a mechanical reason: a section
that ends at the next `## ` is a **closed region**, and inside a closed region an
unrecognised non-blank line can be a violation. Inside `## Notes` — free prose by
design — it cannot be, so a missing or mistyped ledger line would have to be
tolerated. v2 re-examined this because the placement was named in the routing
decision, and it survives for a stronger reason than it was chosen for: the whole
of AC16 depends on the region being closed. A ledger in `## Notes` could not have
an "unrecognised line" rule, could not have a "line outside the region" rule, and
therefore could not have the agreement cross-check that closes the blocker. The
heading is also why the ledger can be *pasted*: the producer emits the heading and
its lines together, so the producer's output is the consumer's input with nothing
retyped in between.

### DP-2 — the chokepoint is a promotion, and it sits between determination and emission

This is the v2 decision. v1 had a single formatter (`emit_ledger`) and treated
that as the chokepoint, but a formatter that accepts any status from any caller is
not a chokepoint — it is a funnel with no filter. The property that was missing is
that a *benign* status cannot be produced without evidence. So the chokepoint moves
one step earlier: each input's status is `unavailable` until a promotion function
is called, promotion requires an affirmative determination, and the formatter
renders whatever the table holds at the end. Three consequences worth naming:

- A probe that returns early, aborts under `errexit`, or has an unhandled branch
  produces `unavailable` rather than nothing and rather than something benign. The
  missing guard stops being a defect.
- The number of places a benign status can be produced becomes **countable**, which
  is what makes an omission class checkable at all: you cannot grep for an absent
  guard, but you can pin the number of promotion sites at eight and require an
  inventory row and a fixture for each. That is the inventory shape this rework
  uses in place of a "sweep every site" instruction, which cannot close an
  omission class.
- The enum stays closed in both directions: a status the checker does not
  recognise is an error, and a missing id is an error, so "I did not mention that
  input" cannot read as "that input was fine".

### DP-3 — `bin/team-paths.sh` gains a `provenance` key; the legacy hardcodes are a separate issue

Synthesising `base + /provenance` inside `bin/retro-inputs.sh` would put the
knowledge of the directory's name in two places, and this project's most frequent
recorded defect is a second copy drifting from the first. The key goes in the
resolver.

The measured related fact, and the decision about it: `skills/run/SKILL.md`,
`skills/goal/SKILL.md`, `agents/engineer.md`, `agents/qa-verifier.md`,
`agents/codex-reviewer.md`, `agents/drift-evaluator.md` and the generated
`templates/prompt-blocks/playbook-engineer.md` / `playbook-pm-spec.md` blocks all
spell the provenance path as the legacy `tasks/provenance/<task-id>.md`, while
this repository's own files are at `.shell-team/provenance/`. **Correcting them is
a separate issue, not T-1001**, for three reasons. The hardcodes are stale-but-
covered rather than broken: each file's operating-paths note already says the
`tasks/…` spellings name the same artefacts in the legacy layout. Three of the
sites sit inside generated `playbook-*.md` marker regions that can only change
through `bin/playbook-promote.sh`, which this task is explicitly not allowed to
run. And a correct fix is a cross-cutting inventory across seven-plus files, which
needs its own same-class completeness criterion rather than a passing mention in a
task about retro inputs.

### DP-4 — the lessons log is located only from an explicit argument

There is no `lessons` key in `bin/team-paths.sh` and the file does not exist here
(issues #23 and #24, both open). Three options were available: probe a fixed
candidate list, invent a resolver key, or take the path from the caller. The
first invents a path convention that issue #24 would then have to contradict; the
second is issue #24 itself and out of scope. So the path comes from `--lessons
PATH`, and with nothing supplied the status is `unavailable` with the reason
stated. This is honest about the current state and costs one line to change when
#24 lands: the status flips from `unavailable` to `read` with no grammar change.

### DP-5 — the rule applies to the retro that already exists

The alternative was to apply it only going forward, which needs a grandfathering
rule, and a date-based exception inside a checker is a second rule that adopters
inherit and that nobody will remember to remove. Adding the section to the
existing retro is cheap and, more importantly, is a **transcription rather than a
reconstruction**: `.shell-team/retros/2026-07-28.md` already records in its own
`## Notes` that `gh` was unusable and that the lessons log does not exist here,
and in its `## Orchestrator attest` that the pull-request metadata came through a
different channel. Those are the statuses. The CI dogfood step therefore covers
`.shell-team/retros/*.md` unconditionally, with no exclusion to explain.

### DP-6 — a squash-merge history reports `empty`, and that is the whole answer

A merge-commit window is empty in a squash-merge-only repository, and the useful
response is to say so with a detail naming the reason, not to silently substitute
a different window. Substituting one would mean two different definitions of
"cycle" behind the same ledger line, which is the ambiguity this task exists to
remove. Note the v2 sharpening: `empty` here now requires the history to have been
**confirmed** complete — a shallow repository with zero merges is `unavailable`,
because there the same observation has two possible causes. An adopter with a
squash-merge history still has the review artefacts, the specs, the provenance
files and the run telemetry, all of which are separate ledger lines. Giving such a
repository a first-class window of its own is a real gap and a follow-up issue,
not a silent fallback.

### DP-7 — `develop` is the default and `HEAD` is the fallback, and every branch says so

`bin/discover-work.sh` sets the precedent with a bare `develop` default and a
`--base` override, and this task follows it. It adds one step the precedent does
not have: when `develop` does not resolve, the window is taken from `HEAD` and the
detail says a fallback was used. The reason is the adopter constraint — this ships
to repositories whose default branch we do not know, and a mandatory `develop`
would make the normal case `unavailable` for every one of them. The reason it is
safe is that the ledger reports the ref it actually used, so a two-step default
can never be mistaken for a measurement of a different branch. v2 adds the part v1
assumed: the declaration appears in **all three** status branches, not only the
one the v1 criterion happened to exercise. And the probe that decides whether
`develop` resolves must distinguish "it does not exist" from "git could not
answer" — the second is `unavailable` with its own reason, since a probe that
cannot answer is not evidence that the ref is missing.

### DP-8 — canonical bytes live in exactly one place per kind

The twelve enumeration lines live in `templates/prompt-blocks/retro-inputs.md`
and are verified into their four consumers by `bin/check-prompt-sync.sh`. Every
other canonical line this task adds — the trust-boundary sentence, the optional-
lessons sentence, the sanitisation sentence, the hand-off tally line, the four
rule-4 violation messages — exists in this spec only as the `grep` pattern of the
criterion that pins it, so there is no second copy in the spec body to drift from.

## What this mechanism does not deliver

Said plainly, because this repository has a recorded history of criteria that
claim more than their mechanism supports.

The ledger check validates **structure**. It confirms that a retro declares a
status for every input, that each status is one of three known values, and that
each declaration carries a reason. It cannot confirm that any of them is true. A
retro that writes `status: read` is not thereby proven to have read anything, in
exactly the way `bin/check-provenance.sh` confirms that a decision carries a
`grounding:` line without judging whether the citation is real. No criterion in
this spec asserts otherwise: AC6 and AC24 assert that a ledger is well-formed and
complete, never that it is honest.

The inverted default is a **bias, not a proof**. It guarantees that a status
nobody determined is `unavailable`; it does not guarantee that a determination
someone did make was correct. A promotion site whose precondition is itself
wrongly implemented still promotes. What the inversion buys is that the failure
mode of *omission* — the class that repeated three times — lands on the safe side,
and that the sites where a wrong determination could matter are eight, enumerated,
and individually exercised, rather than unbounded.

The same limit applies to the fixture-label criteria (AC4, AC5, AC7, AC9, AC11,
AC12, AC13, AC14, AC17, AC19). A label proves a case exists; AC15 and AC17's suite
run prove every case passes; neither proves the label is attached to an assertion
that tests what its name says. That is a reading job, and it belongs to QA and to
the cross-provider review.

## Measured tree facts

Issue #28's first acceptance requirement is that every claim about what an input
currently does be measured against this tree. Each row below was read directly
from the file named. Rows marked **(v2)** were measured against the
implementation this rework revises, not against the pre-task tree.

| Claim | Where it was measured |
|---|---|
| The merged-PR query asks for `--base main` | `develop:agents/scrum-master.md`, input 1 of `## Inputs you read` |
| `--base main` occurs exactly once in the pre-task tree | repository-wide search; the single hit is that line |
| `bin/team-paths.sh --get` accepts `base\|todo\|loops\|runs\|retros\|reviews\|specs` — no `lessons` key, no `provenance` key | the `case "$GET_KEY"` block, the header usage comment, and `print_help` |
| `.shell-team/provenance/` holds four files and no `.gitkeep`, and `bin/team-init.sh` scaffolds only `runs`, `retros`, `reviews`, `specs` | directory listing; the `ensure_gitkeep` calls in `bin/team-init.sh` |
| `agents/scrum-master.md` carries **no** prompt-block marker region; it is registered in `contain` mode only, for `language.md`, `flag-enum.md` and `operating-paths-core.md` | `templates/prompt-blocks/registry.txt` rows 2, 5 and 8 |
| `operating-paths-core.md`'s only non-empty line is `on PATH when the plugin is loaded; else` | the file |
| `docs/loop-engineering/` contains only `goal-loop.md`, `goal-loop.ja.md` and `loop-cron.crontab.example`; `loop-traps.md` and `model-tiering.md` do not exist, and the distinct referenced set across the role and the template is exactly those two paths | directory listing; targeted search in both files |
| `.shell-team/.gitignore` ignores `runs/`, so run telemetry is present locally and absent from a fresh clone while `.shell-team/runs/.gitkeep` stays tracked | the ignore file and the tracked-file listing |
| The existing retro records that `gh` was unusable, that the lessons log does not exist here, and that PR metadata came from another channel | `.shell-team/retros/2026-07-28.md`, `## Notes` and `## Orchestrator attest` |
| `tests/check-retro/run.sh`'s header still claims a dogfood assertion on `tasks/retros/2026-04-30.md`; no such assertion is in the file and no such file is in the tree | the suite's header comment versus its body |
| `docs/templates/retro-template.md` does **not** pass `bin/check-retro.sh`: its Lesson section carries a bare `` - `<...>` `` bullet | the template's Lesson section against rule 3 |
| `tests/discover-work/fixtures/gh` is an env-driven stub whose `pr` branch exits 3 if any argv mentions `body` | the stub |
| `bin/discover-work.sh` defaults to `BASE="develop"`, exposes `--base BRANCH`, exits 0 with a `# note:` line when `gh` is missing or unauthenticated, and sanitises untrusted titles by stripping CR/LF/TAB/backticks and replacing U+2014 | the script's argument parsing, `gh` readiness block, and `sanitize()` |
| **(v2)** Rule 4's region walk matches `/^## Retro inputs$/` with no CR strip, while rule 2's `has_exact_line()` does strip a trailing CR — so in a CRLF file the heading is found and the region is never entered, and `END { if (seen) … }` skips the missing-id sweep | `bin/check-retro.sh`, the rule-4 awk program against `has_exact_line` |
| **(v2)** `report_dir_input()` guards `-d` and `-r` and not traversability, and `count_files()` decides membership with `[ -f "$f" ]`, which needs search permission on the directory | `bin/retro-inputs.sh`, both functions |
| **(v2)** Shallow detection reads `$(git rev-parse --git-dir)/shallow`, which is the worktree-specific directory in a linked worktree while the marker lives in the common directory | `bin/retro-inputs.sh`'s `compute_cycle_window` |
| **(v2)** The fallback declaration is appended only on the path that reaches the `read` branch; the `unavailable` and `empty` branches return before it | `bin/retro-inputs.sh`, the early returns above the qualifier block |
| **(v2)** The shallow and cap qualifiers are an `if`/`elif`, so a shallow repository with a cap states only the shallow half | the qualifier block |
| **(v2)** Rule 4's empty-detail test is `de == ""`, so a detail of spaces satisfies it | `bin/check-retro.sh` |
| **(v2)** Rule 4's region walk sets `in_s = 0` on any `^## ` line and re-enters only on the first `## Retro inputs`, so a second such heading leaves its region unvalidated | the rule-4 awk program |
| **(v2)** `agents/scrum-master.md` instructs the reader to run `bin/retro-inputs.sh` as the primary form in both `## Inputs you read` and `## Loop` | those two sections |

## Body-to-AC correspondence

Every normative directive stated in the body above, mapped to the criterion that
carries it or to an explicit exemption with its reason.

| Body directive | Where |
|---|---|
| `unavailable` is the default; a benign status is a promotion | AC2 |
| Exactly one formatter, two promotion functions, eight promotion sites | AC2 |
| Probing is separate from emission; all eight ids always emitted, in canonical order | AC3 |
| Each promotion site states what happens when its determination cannot be made | AC4 |
| Each promotion site has a fixture that makes its determination impossible | AC4 |
| A directory that cannot be enumerated is `unavailable`, never `empty` | AC5 |
| Enumerability is confirmed, not inferred from a permission bit | AC5 |
| Shallow detection is correct from a linked worktree | AC5 |
| An unanswerable shallow question yields `unavailable` | AC5, AC12 |
| "Ref absent" and "git could not answer" are different answers | AC5, AC12 |
| The cycle window is derived from git, not from `gh`, not hardcoded | AC11 |
| The hardcoded `main` base is removed from the operative surface | AC26 |
| `gh` is optional enrichment; absent, the retro is not degraded | AC9 |
| `gh` is never asked for `body`; the field set is exactly six | AC10 |
| The ledger records `read`/`empty`/`unavailable` per declared input | AC6 |
| The ledger is complete: all eight ids, exactly once each | AC3, AC6, AC12 |
| Each `detail:` is non-empty and a `read` detail says how much | AC6 |
| The grammar is exactly three ` — `-separated fields | AC6 |
| The enumeration exists in exactly one file, enforced not asserted | AC3 (order), AC30 (`check-prompt-sync` green) |
| Every artefact path resolves through `team-paths.sh` | AC7 |
| `bin/` stays pure bash and zero-dependency | AC8 |
| The checker validates a closed enum and fails closed | AC18 |
| "Located and validated", "absent" and "could not be read" never coincide | AC16 |
| Two independent determinations of section entry must agree | AC16 |
| A duplicate section heading is a violation | AC16, AC18 |
| A ledger-shaped line outside the region is a violation | AC16, AC18 |
| A whitespace-only detail is a violation | AC16, AC18 |
| A tolerance claim is proved by a malformed input | AC17 |
| The agreement backstop is proved by a mutation self-check on a copy | AC17 |
| New tokens are English only; no Japanese required heading is added | AC28 |
| The five decorated headings and the label rule are untouched | AC19 |
| Rule 3 is CR-tolerant already and is confirmed by fixture, not rewritten | AC19 |
| The trust boundary is stated in the checker's header | AC20 |
| `team-paths.sh` gains a `provenance` key (DP-3) | AC21 |
| `team-init.sh` scaffolds the provenance dir | AC22 |
| The template carries a ledger section, before `## Keep` | AC23 |
| The ref used is named in every cycle-window branch, fallback included | AC11 |
| Every applicable qualifier is stated, cap and shallow together | AC11 |
| A confirmed-complete zero-merge history is `empty` (DP-6) | AC12 |
| Attacker-controlled text cannot forge a ledger line | AC13 |
| The emitted ledger passes the checker end to end | AC13 |
| The lessons log is optional (DP-4) | AC14 |
| The rule applies to the existing retro (DP-5) | AC24 |
| CI dogfoods the checker on this repository's retros | AC25 |
| CI exercises the acquisition path and shellchecks the new scripts | AC25 |
| No new pointer to a nonexistent document | AC27 |
| `bin/retro-inputs.sh` writes nothing | AC32 |
| The change stays inside its declared surface | AC29 |
| Nothing that already worked stops working | AC30 |
| The provenance record exists and is conformant | AC31 |
| Agent instructions invoke the script by bare name; no adopter-tree assumption | AC33 |
| The role declares the mechanism that actually runs, and reports the tally | AC33 |
| No negated grep without a same-target positive control | **info-only (not promoted to AC)** — it is a rule about how the criteria below it are written, applied inside AC8, AC10, AC14, AC26, AC32 and AC33; a criterion asserting the shape of other criteria would be checking this document rather than the deliverable |
| Every claim about a current input is measured against this tree | **info-only (not promoted to AC)** — it constrains this spec's authoring rather than the deliverable; the `## Measured tree facts` table is the artefact that satisfies it, and AC26's base-blob read is the one part of it that is mechanically provable |
| The ledger check validates structure only and proves nothing about honesty | **info-only (not promoted to AC)** — a statement of what is *not* claimed; promoting it would require a criterion asserting the absence of an assertion, which is not testable. Its enforcement is that no AC claims more, which the correspondence table makes auditable |
| The inverted default is a bias, not a proof | **info-only (not promoted to AC)** — same shape as the row above: it bounds what AC2 and AC4 may be read as proving, and cannot itself be checked |
| A fixture label proves presence, not attachment to a real assertion | **info-only (not promoted to AC)** — a declared limit on the label-owning criteria, handed to QA and the reviewer rather than to a check |
| Unicode line separators and bidi controls are not stripped | **info-only (not promoted to AC)** — a Non-goal with three stated reasons; the property that *is* required (no forged ledger line) is AC13's, and it holds independently because those characters are not record separators |
| The salience channel, single-pass obligations, mandatory attest, dead pointers, transcripts, and issues #23/#24 are out of scope | **info-only (not promoted to AC)** — Non-goals; AC27 and AC29 are the two that are mechanically held, the rest are absences no grep can distinguish from "not yet written" |

## Assumptions

- **The nine-merged-pull-requests measurement in issue #28 is taken on trust.**
  pm-spec has no shell in this role and cannot run `git log`, so the claims that
  nine pull requests merged to `develop` and that exactly one targeted `main` are
  the issue's measurements, not this spec's. Nothing in the acceptance criteria
  depends on them.
- **The three defect reproductions are the coordinator's measurements**, restated
  here with the source lines they correspond to, which pm-spec did read. The
  `## Measured tree facts` rows marked (v2) are what this spec verified for itself:
  the code paths that produce those behaviours.
- **`develop` exists as a local branch in the checkout where the criteria are
  run.** AC26, AC28 and AC29 read `develop` directly. In a CI checkout `develop`
  may exist only as a remote-tracking ref; those three criteria are for local and
  QA use, and CI does not evaluate this spec.
- **`shellcheck` is installed locally at the pinned 0.11.0.** AC25 invokes it
  unconditionally on purpose; a vacuous skip when it is missing would be worse
  than a loud failure.
- **A shallow repository can be simulated without cloning**, and a linked worktree
  can be created with `git worktree add`. Both matter because a `git clone --depth`
  has been denied by sandbox policy in this repository before. The criteria name
  the behaviour, not the technique.
- **`git rev-parse --is-shallow-repository` is available.** It has shipped since
  git 2.15 and is the worktree-correct probe, which is why AC5 names it. On a git
  too old to answer, the inverted default applies and the cycle window is
  `unavailable` — a conscious trade: an adopter on such a git gets a declared
  absence rather than a wrong `empty`.
- **`run-telemetry` legitimately differs between the maintainer's checkout and a
  fresh clone.** A measured consequence of `.shell-team/.gitignore`, not a defect,
  and it is why AC6 pins the ledger's *shape* rather than a specific status for
  that input.

## Open questions

None blocking. Four things were decided rather than asked, each recorded with its
reasoning: the ledger's placement (DP-1, re-examined at v2), the chokepoint's
placement (DP-2), the retroactive backfill (DP-5), and the exclusion of the legacy
provenance hardcodes (DP-3).

## Notes for engineer

**Files this task touches.** `bin/retro-inputs.sh`,
`templates/prompt-blocks/retro-inputs.md`, `templates/prompt-blocks/registry.txt`,
`bin/check-retro.sh`, `bin/team-paths.sh`, `bin/team-init.sh`,
`agents/scrum-master.md`, `docs/templates/retro-template.md`,
`.shell-team/retros/2026-07-28.md`, `tests/retro-inputs/` (with `fixtures/gh` and
`fixtures/git` stubs), `tests/check-retro/` (ten fail fixtures plus suite cases),
`tests/team-paths/run.sh`, `tests/team-init/run.sh`,
`.github/workflows/check-handoff.yml`, plus this task's board entry, provenance
file and review record. AC29's allow-list is the authority.

**The ledger grammar, once.** One physical line per input:

```
- input: <id> — status: <read|empty|unavailable> — detail: <one non-empty line>
```

with optional indented sub-bullets beneath carrying the material itself. Separators
are space-padded U+2014 EM DASH, the same separator `bin/check-handoff.sh`'s
`LINE_RE` uses. Indentation is what keeps material out of the parsed surface, which
is why stripping newlines from untrusted text (AC13) is load-bearing.

**The shape AC2 asks for, in outline.** A status and a detail per id, both
initialised to the `unavailable` value before any probe runs; probes that call
`promote_read` / `promote_empty` and otherwise leave the initial value alone; one
emission pass over the canonical id list at the end. The eight promotion sites are
cycle-window read, cycle-window empty, directory read, directory empty, lessons
read, lessons empty, pr-metadata read, pr-metadata empty — the directory pair
being one site each because the five directory inputs share one function. One call
per line, since AC2 counts occurrences.

**Why `-r` was not enough, and what to do instead.** Listing a directory's names
needs read permission; stat'ing an entry needs search permission. A glob under
`nullglob` over a readable-but-not-traversable directory yields names, and every
`[ -f "$name" ]` then fails silently, so the count is zero and nothing errors.
Do not swap `-r` for `-r` plus `-x`: that is a different inference, and the class
being closed is "inferred instead of determined". Determine it — compare the
number of names the glob returned against the number of those names that can be
stat'ed at all, and treat a disagreement as an incomplete enumeration. That also
behaves correctly for a directory entry that happens to match the suffix, since it
is stat-able and merely fails the regular-file test afterwards.

**Rule 4's three outcomes, concretely.** Keep rule 2's heading assertion. Have the
region walk report whether it entered the section, and compare: heading present
and region entered → validate; heading absent → the existing missing-heading
violation; heading present and region not entered → the new
`could not be read` violation. Count the headings while you are there (two or more
is its own violation), and count the top-level ledger-shaped lines in the whole
file against the number the walk examined, reporting any excess by line. The point
is not the specific comparison; it is that no combination of the two
determinations can produce silence.

**Watch the self-hitting grep in AC8.** Write the dependency note in
`bin/retro-inputs.sh` as `no jq/yq/python` — a slash or comma after the word.
`depends on nothing but bash and jq` at end of line would trip AC8's own pattern.

**`bin/team-paths.sh` has four places that list the keys**, not one: the header
usage comment, `print_help`, the `case "$GET_KEY"` branches, and the `die`
message's key list. AC21 reads three of them; miss the fourth and the error
message lies.

**Do not add a CI step that runs `bin/check-retro.sh` on
`docs/templates/retro-template.md`.** It does not pass today, for a reason
unrelated to this task, and making it pass is a Non-goal.

**Before you hand off**, mutate each new lock and watch it fail. At minimum: delete
a promotion call and confirm the count criterion turns red; make one DS fixture's
directory traversable again and confirm its case turns red; convert the malformed
CRLF fixture to LF and confirm the CRLF case no longer proves anything; remove the
CR handling from the copied checker in the mutation case and confirm the backstop
still reports; re-widen the shallow classification from `unavailable` to `empty`
and confirm AC12's fixture catches it. A lock you have not seen fail is a lock you
have not tested. The same applies to every fixture label: the label is the handle,
the assertion under it is the lock, and only you can confirm the two match.

**Prior art worth reading before writing anything.**
`bin/discover-work.sh` for the `--base` default, the `gh` fail-soft path and
`sanitize()`; `tests/discover-work/fixtures/gh` for the env-driven stub shape and
its `body` guard; `bin/check-provenance.sh` for a checker that states its own
trust boundary in its header and for its fail-closed classification helpers; the
board's T-111 entry (DP-10) for the precedent this rework follows — where a rule
cannot separate two populations cleanly, it prefers the loud side, and the noise
is declared rather than chased.
