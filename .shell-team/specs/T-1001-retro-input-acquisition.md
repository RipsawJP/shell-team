# T-1001 — retro input acquisition: a git-derived cycle window and a machine-checked input ledger

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
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

## Goal

<!-- BEGIN intent-block: T-1001 -->

The retro's declared inputs are the ones that exist, they are acquired by a
mechanism that needs nothing beyond `git` and this repository's own files, and
the presence or absence of each one is a machine-checked declaration rather than
a sentence a human may or may not remember to write. A new `bin/retro-inputs.sh`
derives the cycle window from `git` merge commits on a ref it resolves rather
than hardcodes, resolves every artefact path through `bin/team-paths.sh`, and
emits a **ledger** naming, for each declared input, whether it was `read`,
`empty`, or `unavailable`. `gh` is demoted from the acquisition path to optional
enrichment: absent, it costs the retro one optional line and nothing else. The
distinction between *looked and found nothing* and *could not look* is carried by
two different status values, is never collapsed, and is enforced by
`bin/check-retro.sh` against a closed enum that fails closed on anything it does
not recognise. The enumeration of input ids and status values exists in exactly
one file, and that single-source property is verified by `bin/check-prompt-sync.sh`
rather than asserted. Every new machine token is English; no Japanese required
heading is added, removed, or reworded.

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
  AC24 locks the referenced set so this task cannot add a fifth pointer to a
  document that does not exist.
- **Whether the retro may read local agent transcripts.** Issue #28 records that
  as an open question and does not propose it; this task does not answer it.
- **A `lessons` key for `bin/team-paths.sh` (issue #24) and the lessons corpus
  import (issue #23).** Both are open. This spec therefore assumes **no
  resolvable lessons path exists**, demotes the lessons log from a required input
  to an optional one, and locates it only from an explicit argument (DP-4).
- **Correcting the `tasks/provenance/<task-id>.md` hardcodes** in
  `skills/run/SKILL.md`, `skills/goal/SKILL.md`, `agents/engineer.md`,
  `agents/qa-verifier.md`, `agents/codex-reviewer.md`, `agents/drift-evaluator.md`
  and the generated `templates/prompt-blocks/playbook-*.md` blocks. See DP-3: it
  is a separate issue, not this task.
- **An alternative cycle window for squash-merge-only repositories.** A history
  with no merge commits reports `empty` with a detail saying why. Giving such a
  repository a different window is a design decision this task declines (DP-6).
- **Making `docs/templates/retro-template.md` itself pass `bin/check-retro.sh`.**
  It does not pass today: its `## Lesson 候補（…）` section carries a bare
  `` - `<...>` `` bullet that rule 3 rejects. No CI step is added that would
  require it to.
- **Any change to the five decorated Japanese H2 headings, the
  `` `[common]` ``/`` `[target-specific]` `` label rule, or the exit-code
  contract of `bin/check-retro.sh`.** AC17 and AC25 lock them.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup, invokes
scripts as `bash bin/<script>.sh` (never a bare name), and uses `develop` as the
base ref where a base ref is needed. **The exact bytes of every canonical line
this task adds are the `grep` patterns below** — there is no second copy of them
elsewhere in this spec to drift from (DP-8).

Two ACs assert a fixture *case* rather than the behaviour directly, because the
behaviour needs a purpose-built git history or a stubbed `PATH` that a `check:`
line must not build in the working repository. Those ACs pin the case's label
byte-exact so deleting the case fails the criterion, and AC15 asserts that every
case in the suite passes. The pair is only as strong as a label attached to a
real assertion; the spec says so plainly here rather than pretending otherwise,
and verifying that attachment is QA's and the reviewer's job.

- [ ] **AC1** `bin/retro-inputs.sh` exists, prints help and exits 0 for `--help`,
  and rejects an unknown flag with exit **2** (the usage-error code every script
  in `bin/` uses).
  - check: test -f bin/retro-inputs.sh && bash bin/retro-inputs.sh --help >/dev/null && rc=0 && { bash bin/retro-inputs.sh --no-such-flag-t1001 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2

- [ ] **AC2** `templates/prompt-blocks/retro-inputs.md` is the single canonical
  enumeration: exactly **twelve** non-blank lines — the eight input ids, the three
  status values, and the one sentence that separates the two failure meanings — and
  nothing else. The file is **pure ASCII**, so registering it against four
  consumers cannot introduce a new non-English machine token anywhere (issue #20).
  - check: B=templates/prompt-blocks/retro-inputs.md && test -f "$B" && test "$(grep -cvE '^[[:space:]]*$' "$B")" -eq 12 && test -z "$(LC_ALL=C tr -d '[:print:]\t\r\n' < "$B")" && for l in '- input: cycle-window' '- input: review-artifacts' '- input: provenance' '- input: specs' '- input: run-telemetry' '- input: previous-retro' '- input: lessons' '- input: pr-metadata' '- status: read' '- status: empty' '- status: unavailable' 'empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.'; do grep -qxF -- "$l" "$B" || exit 1; done

- [ ] **AC3** The block is registered in `templates/prompt-blocks/registry.txt` in
  `contain` mode against exactly four consumers — the producer, the checker, the
  role, and the template — and `bin/check-prompt-sync.sh` is green on this tree.
  Registration is checked field-by-field rather than as a byte-exact row, so the
  criterion does not break on the registry's column alignment.
  - check: awk '$1=="contain" && $2=="retro-inputs.md" { found=1; if (NF==6 && $3=="bin/retro-inputs.sh" && $4=="bin/check-retro.sh" && $5=="agents/scrum-master.md" && $6=="docs/templates/retro-template.md") ok=1 } END { exit !(found && ok) }' templates/prompt-blocks/registry.txt && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC4** Each of the four consumers carries all twelve canonical lines
  verbatim. This is what AC3's registration causes `bin/check-prompt-sync.sh` to
  enforce; it is asserted independently here so a registry typo cannot hide a
  consumer that never received the block. The count of lines actually compared is
  asserted as a positive control against an empty read.
  - check: for f in bin/retro-inputs.sh bin/check-retro.sh agents/scrum-master.md docs/templates/retro-template.md; do test -f "$f" || exit 1; n=0; while IFS= read -r l; do [ -n "$l" ] || continue; n=$((n + 1)); grep -qF -- "$l" "$f" || exit 1; done < templates/prompt-blocks/retro-inputs.md; test "$n" -eq 12 || exit 1; done

- [ ] **AC5** The hardcoded release-branch query is gone from the whole operative
  surface. `--base main` occurs exactly once in this tree today, in
  `agents/scrum-master.md`'s merged-PR command; after this task it occurs nowhere
  under `agents/`, `bin/`, `skills/` or `templates/`. The base blob is read first
  as a positive control that the defect being fixed genuinely existed.
  **Merge-point-scoped**: it resolves `develop:agents/scrum-master.md` and goes
  stale once this task lands on `develop`. That is expected; do not widen its
  base-ref resolution or re-derive it per rework round.
  - check: git show develop:agents/scrum-master.md | grep -qF -- '--state merged --base main' && ! grep -rqF -- '--base main' agents bin skills templates

- [ ] **AC6** Run against this repository with no arguments, `bin/retro-inputs.sh`
  emits a **complete, well-formed ledger**: the heading `## Retro inputs`, exactly
  eight top-level `- input: ` lines, one per canonical id, each with a status drawn
  from the closed enum and a non-empty `detail:`. The grammar is exactly three
  ` — `-separated fields, so a script-generated detail can never contain the
  separator and split a line into a fourth field. A `read` status must say **how
  much** was found, which is asserted mechanically as "the detail contains a digit".
  - check: out="$(bash bin/retro-inputs.sh)" && printf '%s\n' "$out" | grep -qxF -- '## Retro inputs' && test "$(printf '%s\n' "$out" | grep -c -- '^- input: ')" -eq 8 && test "$(printf '%s\n' "$out" | grep -cE -- '^- input: (cycle-window|review-artifacts|provenance|specs|run-telemetry|previous-retro|lessons|pr-metadata) — status: (read|empty|unavailable) — detail: [^[:space:]]')" -eq 8 && test "$(printf '%s\n' "$out" | grep -- '^- input: ' | awk -F' — ' '{ print NF }' | sort -u | tr -d '\n')" = "3" && printf '%s\n' "$out" | awk -F' — ' '/^- input: /{ if ($2 == "status: read" && $3 !~ /[0-9]/) bad = 1 } END { exit bad + 0 }'

- [ ] **AC7** Every artefact path is resolved through `bin/team-paths.sh`: no
  non-comment line of `bin/retro-inputs.sh` contains a literal `.shell-team/` or
  `tasks/` path, and the script does call the resolver. Both positive controls are
  present — the non-comment extraction is non-empty, and it names the resolver.
  A fixture case covers both layouts and a `$TEAM_RUN_BASE` override.
  - check: nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && printf '%s\n' "$nc" | grep -qF -- 'team-paths.sh' && ! printf '%s\n' "$nc" | grep -qE -- '\.shell-team/|(^|[^A-Za-z0-9_./-])tasks/' && grep -qF -- 'case: both layouts and a TEAM_RUN_BASE override resolve every input path' tests/retro-inputs/run.sh

- [ ] **AC8** `bin/retro-inputs.sh` introduces no runtime dependency beyond bash
  and standard POSIX tools: it invokes no `jq`, `yq`, `python`, `perl` or `node`.
  The pattern is proved to bite on a synthetic line first, so the criterion cannot
  pass because the regex matches nothing. The file's existence is asserted before
  the negative assertion, because `grep` on a missing path also exits non-zero and
  a bare negation would therefore be satisfied by the file not existing at all —
  measured on the pre-implementation tree, where this criterion passed vacuously.
  - check: test -f bin/retro-inputs.sh && printf 'x | jq .\n' | grep -qE -- '(^|[[:space:]|(])(jq|yq|python3?|perl|node)([[:space:]]|$)' && ! grep -qE -- '(^|[[:space:]|(])(jq|yq|python3?|perl|node)([[:space:]]|$)' bin/retro-inputs.sh

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
  names `body`.
  - check: grep -qF -- 'number,title,mergedAt,author,url,headRefName' bin/retro-inputs.sh && ! grep -qE -- '--json.*body' bin/retro-inputs.sh

- [ ] **AC11** The cycle window is **derived from git**, not from `gh` and not from
  a hardcoded branch: merge commits reachable from the resolved base ref along the
  first-parent path. The ref is resolved as `develop` when it resolves and `HEAD`
  otherwise, is overridable with `--base REF`, and the `detail:` names the ref
  string actually used. `--last-n N` caps the window; a cap is a declared,
  ordinary outcome and must read differently from a truncated history. The help
  text states the default and the fallback so an adopter with no `develop` is not
  left guessing.
  - check: out="$(bash bin/retro-inputs.sh --base HEAD)" && printf '%s\n' "$out" | grep -qE -- '^- input: cycle-window — status: (read|empty) — detail: .*HEAD' && grep -qF -- 'git log --merges --first-parent' bin/retro-inputs.sh && bash bin/retro-inputs.sh --help | grep -qF -- 'default: develop, falling back to HEAD' && for l in 'case: default base resolves to develop when it exists' 'case: no develop branch falls back to HEAD and declares the fallback' 'case: --last-n caps the window and the cap is declared, distinct from a shallow truncation' 'case: every ledger is complete (all eight input ids, exactly once)'; do grep -qF -- "$l" tests/retro-inputs/run.sh || exit 1; done

- [ ] **AC12** Degenerate histories are classified honestly, and this is the part
  of the task most able to make a retro read as sound while resting on nothing.
  A base ref that does not resolve locally is `unavailable` with the ref named — not
  `empty`. A history with zero merge commits, where the ref *did* resolve and the
  history is complete, is `empty`. A **shallow** repository with zero merges inside
  the boundary is `unavailable`, because "no merges" and "merges beyond the
  boundary" are indistinguishable there. A shallow repository that does find
  merges is `read` **with the truncation declared**. A failing `git` invocation is
  `unavailable`, the ledger is still complete, and the exit status is still 0.
  The missing-ref case is exercised directly here; the other four are fixture
  cases, because each needs a purpose-built repository or a stubbed `PATH`.
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
  is `unavailable` with a reason; with a path supplied it is `read`. The role's
  prose says so, and the superseded framing that made it a required input is gone.
  - check: bash bin/retro-inputs.sh | grep -qE -- '^- input: lessons — status: unavailable — detail: .+' && bash bin/retro-inputs.sh --lessons README.md | grep -qE -- '^- input: lessons — status: read — detail: .+' && grep -qF -- 'The lessons log is OPTIONAL: there is no resolver key for it, so it is read only when a path is supplied, and its absence is recorded as unavailable rather than as a failure.' agents/scrum-master.md && ! grep -qF -- '**Lessons log** — read' agents/scrum-master.md && grep -qF -- 'case: lessons path not supplied -> unavailable' tests/retro-inputs/run.sh && grep -qF -- 'case: lessons path supplied -> read' tests/retro-inputs/run.sh

- [ ] **AC15** `tests/retro-inputs/run.sh` exists and **every** case in it passes.
  This is the criterion that makes the label locks in AC7, AC9, AC11, AC12, AC13
  and AC14 mean something. A positive control guards against a stub suite that
  passes by doing nothing: it must drive the script under test at least eight times.
  - check: test -f tests/retro-inputs/run.sh && test "$(grep -c -- 'retro-inputs.sh' tests/retro-inputs/run.sh)" -ge 8 && bash tests/retro-inputs/run.sh >/dev/null

- [ ] **AC16** `bin/check-retro.sh` validates the ledger against the **closed**
  enum and **fails closed**. A retro with no `## Retro inputs` section, a status
  outside the enum, an input id outside the enum, a missing id, a duplicated id, an
  empty `detail:`, or an unrecognised non-blank line inside the section is a
  violation reported as exit 1 — never a silent pass. Each of the seven is a
  committed fixture and is exercised directly here rather than only through the
  suite. Two further cases are generated at run time inside the suite: CRLF line
  endings still pass, and a `detail:` that quotes the ledger grammar is not
  miscounted as a second ledger line.
  - check: bash bin/check-retro.sh tests/check-retro/fixtures/pass-canonical.md >/dev/null && for f in fail-inputs-missing-section fail-inputs-unknown-status fail-inputs-unknown-id fail-inputs-missing-id fail-inputs-duplicate-id fail-inputs-empty-detail fail-inputs-stray-line; do test -f "tests/check-retro/fixtures/$f.md" || exit 1; rc=0; bash bin/check-retro.sh "tests/check-retro/fixtures/$f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done && for l in 'case: a well-formed Retro inputs ledger passes' 'case: a ledger with CRLF line endings still passes' 'case: a detail that quotes the ledger grammar is not a second ledger line'; do grep -qF -- "$l" tests/check-retro/run.sh || exit 1; done && bash tests/check-retro/run.sh >/dev/null

- [ ] **AC17** The checker's existing contract is untouched. All five decorated
  heading constants are byte-identical, so no Japanese heading is reworded,
  renamed or dropped while the ledger rule is added, and the repository's own
  retro still passes.
  - check: for l in "KEEP='## Keep（続けたい良い動き）'" "PROBLEM='## Problem（直面した課題 / 痛み）'" "TRY='## Try（次サイクルで試すこと）'" "TRAPS='## 罠の点検（Comprehension Debt / Cognitive Surrender）'" "LESSON_PREFIX='## Lesson 候補（'"; do grep -qxF -- "$l" bin/check-retro.sh || exit 1; done && bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null

- [ ] **AC18** The ledger check's trust boundary is stated where a reader of the
  checker will see it, in the checker's own header, and in one line that says what
  the mechanism does not deliver.
  - check: grep -qxF -- "# structure only: a retro whose ledger says 'read' is not thereby proven to have read anything." bin/check-retro.sh

- [ ] **AC19** `bin/team-paths.sh` resolves a `provenance` key, in every mode a
  consumer can use: `--get provenance`, `TEAM_PROVENANCE_DIR` in `--export`, a row
  in `--print`, and the key named in `--help`. An unknown key still exits 2, and
  the resolver's own suite covers the default layout and the legacy layout in the
  idiom it already uses.
  - check: test "$(bash bin/team-paths.sh --get provenance)" = ".shell-team/provenance" && bash bin/team-paths.sh --export | grep -qE -- '^export TEAM_PROVENANCE_DIR=' && bash bin/team-paths.sh --print | grep -qE -- '^[[:space:]]+provenance[[:space:]]+\.shell-team/provenance$' && bash bin/team-paths.sh --help | grep -qF -- 'provenance' && rc=0 && { bash bin/team-paths.sh --get no-such-key-t1001 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && grep -qF -- 'default: provenance path wrong' tests/team-paths/run.sh && grep -qF -- 'legacy: provenance path wrong' tests/team-paths/run.sh && bash tests/team-paths/run.sh >/dev/null

- [ ] **AC20** `bin/team-init.sh` scaffolds the provenance directory alongside the
  four it already creates, its usage listing says so, and the scaffolder's own
  suite asserts the file exists on a fresh target.
  - check: grep -qF -- '<base>/provenance/.gitkeep' bin/team-init.sh && grep -qF -- '.shell-team/provenance/.gitkeep' tests/team-init/run.sh && bash tests/team-init/run.sh >/dev/null

- [ ] **AC21** `docs/templates/retro-template.md` carries a `## Retro inputs`
  section, and it sits **before** `## Keep（続けたい良い動き）` — the ledger
  declares the material the rest of the retro rests on, so it is read first.
  - check: grep -qxF -- '## Retro inputs' docs/templates/retro-template.md && awk '/^## Retro inputs$/ { a = NR } /^## Keep（続けたい良い動き）$/ { b = NR } END { exit !(a > 0 && b > 0 && a < b) }' docs/templates/retro-template.md

- [ ] **AC22** The one retro that already exists is backfilled, so the ledger rule
  applies to every retro in the tree with no date-based exception inside the
  checker (DP-5). Its two unambiguously recorded absences — the lessons log and the
  pull-request metadata — are declared as `unavailable`, and the file passes.
  - check: bash bin/check-retro.sh .shell-team/retros/2026-07-28.md >/dev/null && grep -qxF -- '## Retro inputs' .shell-team/retros/2026-07-28.md && test "$(grep -c -- '^- input: ' .shell-team/retros/2026-07-28.md)" -eq 8 && grep -qE -- '^- input: lessons — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md && grep -qE -- '^- input: pr-metadata — status: unavailable — detail: .+' .shell-team/retros/2026-07-28.md

- [ ] **AC23** CI runs all of it: the two new scripts and both fixture stubs are on
  the shellcheck argument list, the new fixture suite is a step, the declared
  acquisition path is exercised against a real repository, and
  `bin/check-retro.sh` is dogfooded against this repository's own retros — which
  no step does today. `shellcheck` is invoked unconditionally, so a missing
  shellcheck fails the criterion loudly instead of passing it vacuously.
  - check: W=.github/workflows/check-handoff.yml && grep -qF -- 'bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git' "$W" && grep -qF -- 'bash tests/retro-inputs/run.sh' "$W" && grep -qF -- 'bash bin/retro-inputs.sh --base HEAD' "$W" && grep -qF -- 'bash bin/check-retro.sh .shell-team/retros/*.md' "$W" && shellcheck bin/retro-inputs.sh tests/retro-inputs/run.sh tests/retro-inputs/fixtures/gh tests/retro-inputs/fixtures/git

- [ ] **AC24** No new pointer to a document that does not exist. The set of
  distinct `docs/loop-engineering/*` paths referenced across the role and the
  template is exactly the two that are referenced today — so this task can neither
  add a third nor quietly drop one while rewriting the sections around them.
  - check: test "$(grep -ohE -- 'docs/loop-engineering/[A-Za-z0-9._-]+' agents/scrum-master.md docs/templates/retro-template.md | sort -u | tr '\n' ' ')" = "docs/loop-engineering/loop-traps.md docs/loop-engineering/model-tiering.md "

- [ ] **AC25** Issue #20 is not deepened: the number of lines in
  `bin/check-retro.sh` carrying a full-width parenthesis — the marker of every
  Japanese required token it enforces — is unchanged from the base ref. A positive
  control asserts the count is non-zero, so the equality cannot hold because the
  pattern matched nothing. **Merge-point-scoped**, like AC5: it goes stale once this
  task lands on `develop`, and must not be widened to survive that.
  - check: n="$(grep -c -- '（' bin/check-retro.sh)" && b="$(git show develop:bin/check-retro.sh | grep -c -- '（')" && test "$n" -gt 0 && test "$n" -eq "$b"

- [ ] **AC26** The change stays inside its declared surface: every path in
  `git diff --name-only develop` matches the allow-list below, and the diff is
  non-empty as a positive control. The allow-list includes this task's own
  mandatory records — the provenance file and the review record — so they do not
  read as scope creep. **Merge-point-scoped**: this criterion is tied to the merge
  point it was authored at and is expected to go stale after merge, when later work
  moves `develop` forward. Do not merge-range it, re-derive it per rework round, or
  widen its base-ref resolution — confining the change is the only thing it exists
  to do.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.github/workflows/check-handoff\.yml|\.shell-team/(todo\.md|test-recipe\.md|provenance/T-1001\.md|reviews/T-1001[^/]*|retros/2026-07-28\.md|specs/T-1001-retro-input-acquisition\.md)|agents/scrum-master\.md|bin/(check-retro|retro-inputs|team-init|team-paths)\.sh|docs/templates/retro-template\.md|templates/prompt-blocks/(registry\.txt|retro-inputs\.md)|tests/(check-retro|retro-inputs|team-init|team-paths)/.+)$')"

- [ ] **AC27** Nothing that already worked stops working: prompt sync, the board
  linter on both the shipped template and this repository's board, and every
  fixture suite whose subject this task edits.
  - check: bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash tests/check-retro/run.sh >/dev/null && bash tests/team-paths/run.sh >/dev/null && bash tests/team-init/run.sh >/dev/null

- [ ] **AC28** The task's decision provenance file exists and is conformant, and it
  is located through the new resolver key rather than a hardcoded path — so the key
  AC19 adds is dogfooded by this criterion.
  - check: bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1001.md" >/dev/null

- [ ] **AC29** `bin/retro-inputs.sh` writes nothing. Two consecutive runs leave the
  working tree's git status byte-identical, and no non-comment line invokes a
  file-creating command. The runs must also succeed, which is the positive control.
  - check: before="$(git status --porcelain)" && bash bin/retro-inputs.sh >/dev/null && bash bin/retro-inputs.sh --base HEAD >/dev/null && test "$(git status --porcelain)" = "$before" && nc="$(grep -vE '^[[:space:]]*#' bin/retro-inputs.sh)" && test -n "$nc" && ! printf '%s\n' "$nc" | grep -qE -- '(mktemp|[[:space:]](tee|cp|mv|rm|touch)[[:space:]])'

- [ ] **AC30** `agents/scrum-master.md`'s `## Inputs you read`, `## Loop` and
  hand-off block declare the mechanism that actually runs: the role acquires its
  material by running `retro-inputs.sh`, pastes the ledger into the retro, and
  reports the ledger's tally in its hand-off. The superseded hand-off line, which
  counted PRs and named the lessons log as though it were always there, is gone.
  - check: grep -qxF -- '## Inputs you read' agents/scrum-master.md && grep -qF -- 'retro-inputs.sh' agents/scrum-master.md && grep -qF -- 'Retro inputs: <n> read / <n> empty / <n> unavailable' agents/scrum-master.md && ! grep -qF -- 'Inputs read: <count> PRs' agents/scrum-master.md

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
3. A **shallow** repository (`git clone --depth`, or any tree with a `.git/shallow`
   file), where the history is truncated at a boundary and the absence of a merge
   commit proves nothing.
4. A base ref that does not resolve locally: an adopter whose default branch is
   `main`, and a CI checkout where `develop` exists only as
   `refs/remotes/origin/develop`.
5. A failing `git` invocation: `git` absent from `PATH`, a `safe.directory`
   refusal (reachable in CI containers), or an unreadable object store.
6. `gh` in all four of its states — absent, present but unauthenticated, present
   and authenticated, and present but failing on one subcommand.
7. Each declared input's location in all four of its states: absent,
   present-and-empty, present-with-files, and present-but-unreadable. The
   run-telemetry directory reaches two of these routinely in this very repository:
   `.shell-team/.gitignore` ignores `runs/`, so the maintainer's checkout has a
   populated `.shell-team/runs/shell-team.jsonl` while a fresh clone has only the
   tracked `.gitkeep`.
8. Retro files a checker must judge: a well-formed ledger; a ledger missing an id;
   a duplicated id; a status outside the enum; an id outside the enum; an empty
   `detail:`; a stray non-bullet line inside the section; no `## Retro inputs`
   section at all; and CRLF line endings throughout.
9. A ledger whose `detail:` free text **quotes the ledger grammar** — this
   repository's own habit of describing a mechanism inside the artefact the
   mechanism governs, the class `bin/check-provenance.sh`'s header already records
   for its own markers.
10. Both supported layouts (the `.shell-team/` default and the legacy `tasks/`
    split-root layout) and a `$TEAM_RUN_BASE` override.

**Out-of-scope synthetic extremes** — named and declined:

1. Adversarially large inputs: megabyte-scale commit subjects or pull-request
   titles, tens of thousands of merge commits, a retro with thousands of ledger
   lines. Real material is bounded by what a review cycle produces.
2. Non-UTF-8 or mixed-encoding retro files and commit messages, and NUL bytes
   inside a commit subject.
3. A retro crafted to defeat the section parser: `## Retro inputs ##` in
   ATX-closing notation, or the heading inside a fenced code block.
   `bin/check-board-headings.sh`'s own header records that this matching weakness
   is deliberately left in place in `bin/check-handoff.sh`; this task adds a
   section, it does not harden markdown parsing.
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

## Resolved design decisions

### DP-1 — the ledger lives under its own English `## Retro inputs` heading

The alternative was to put it inside the existing `## Notes` section, where the
one retro that exists already records its gaps in prose. The dedicated heading
wins for a mechanical reason: a section that ends at the next `## ` is a **closed
region**, and `bin/check-retro.sh` can reuse the same awk region walk it already
uses for `## Lesson 候補（`. Inside a closed region, an unrecognised non-blank
line can be a violation, which is what "fail closed" requires. Inside `## Notes`
— a free-prose section by design — an unrecognised line cannot be a violation
without forbidding notes, so a missing or mistyped ledger line would have to be
tolerated, and the checker would be back to trusting prose. The heading is also
the reason the ledger can be *pasted*: `bin/retro-inputs.sh` emits the heading and
its lines together, so the producer's output is the consumer's input with nothing
in between to retype.

### DP-2 — the enum is closed, and the checker fails closed on it

Three statuses, no fourth, and no free-form alternative. A status the checker does
not recognise is an error, not a pass-through — the alternative (ignore what you
do not understand) is exactly how a ledger stops meaning anything. The same
applies to the id set: an id outside the eight is an error, and a missing id is an
error, so "I did not mention that input" cannot read as "that input was fine".

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

The alternative was to apply it only going forward, which needs a
grandfathering rule, and a date-based exception inside a checker is a second rule
that adopters inherit and that nobody will remember to remove. The backfill is
cheap and, more importantly, is a **transcription rather than a reconstruction**:
`.shell-team/retros/2026-07-28.md` already records in its own `## Notes` that `gh`
was unusable and that the lessons log does not exist here, and in its
`## Orchestrator attest` that the pull-request metadata came through a different
channel. Those are the statuses. The CI dogfood step therefore covers
`.shell-team/retros/*.md` unconditionally, with no exclusion to explain, and the
backfill is recorded as a decision in the provenance file with the same reasoning.

### DP-6 — a squash-merge history reports `empty`, and that is the whole answer

A merge-commit window is empty in a squash-merge-only repository, and the useful
response is to say so with a detail naming the reason, not to silently substitute
a different window. Substituting one would mean two different definitions of
"cycle" behind the same ledger line, which is the ambiguity this task exists to
remove. An adopter in that position still has the review artefacts, the specs, the
provenance files and the run telemetry, all of which are separate ledger lines.
Giving such a repository a first-class window of its own is a real gap and a
follow-up issue, not a silent fallback.

### DP-7 — `develop` is the default and `HEAD` is the fallback

`bin/discover-work.sh` sets the precedent with a bare `develop` default and a
`--base` override, and this task follows it. It adds one step the precedent does
not have: when `develop` does not resolve, the window is taken from `HEAD` and the
`detail:` says that a fallback was used. The reason is hard constraint 1 — this
ships to adopters whose default branch we do not know, and a mandatory `develop`
would make the normal case `unavailable` for every one of them. The reason it is
safe to add is that the ledger reports the ref it actually used, so a two-step
default can never be mistaken for a measurement of a different branch.

### DP-8 — canonical bytes live in exactly one place per kind

The twelve enumeration lines live in `templates/prompt-blocks/retro-inputs.md`
and are verified into their four consumers by `bin/check-prompt-sync.sh`. Every
other canonical line this task adds — the trust-boundary sentence, the optional-
lessons sentence, the sanitisation sentence, the hand-off tally line — exists in
this spec only as the `grep` pattern of the criterion that pins it, so there is no
second copy in the spec body to drift from.

## What this mechanism does not deliver

Said plainly, because this repository has a recorded history of criteria that
claim more than their mechanism supports.

The ledger check validates **structure**. It confirms that a retro declares a
status for every input, that each status is one of three known values, and that
each declaration carries a reason. It cannot confirm that any of them is true. A
retro that writes `status: read` is not thereby proven to have read anything, in
exactly the way `bin/check-provenance.sh` confirms that a decision carries a
`grounding:` line without judging whether the citation is real. No criterion in
this spec asserts otherwise: AC6 and AC22 assert that a ledger is well-formed and
complete, never that it is honest.

The same limit applies to the fixture-label criteria (AC7, AC9, AC11, AC12, AC13,
AC14). A label proves a case exists; AC15 proves every case passes; neither proves
the label is attached to an assertion that tests what its name says. That is a
reading job, and it belongs to QA and to the cross-provider review.

## Measured tree facts

Issue #28's first acceptance requirement is that every claim about what an input
currently does be measured against this tree. Each row below was read directly
from the file named, in this session.

| Claim | Where it was measured |
|---|---|
| The merged-PR query asks for `--base main` | `agents/scrum-master.md`, input 1 of `## Inputs you read` |
| `--base main` occurs exactly once in the whole tree | repository-wide search; the single hit is that line |
| The four declared inputs are the merged PR list, `tasks/reviews/<task-id>.md`, `tasks/lessons.md`, and `docs/specs/<task-id>-*.md` | `agents/scrum-master.md`, `## Inputs you read` items 1–4 |
| `bin/team-paths.sh --get` accepts `base\|todo\|loops\|runs\|retros\|reviews\|specs` — no `lessons` key, no `provenance` key | the `case "$GET_KEY"` block, the header usage comment, and `print_help` |
| `.shell-team/provenance/` holds four files and no `.gitkeep`, and `bin/team-init.sh` scaffolds only `runs`, `retros`, `reviews`, `specs` | directory listing; the four `ensure_gitkeep` calls in `bin/team-init.sh` |
| `bin/check-retro.sh` validates the H1, five decorated H2 headings, and the Lesson-candidate label rule, and nothing about material | the whole script |
| `agents/scrum-master.md` carries **no** prompt-block marker region; it is registered in `contain` mode only, for `language.md`, `flag-enum.md` and `operating-paths-core.md` | `templates/prompt-blocks/registry.txt` rows 2, 5 and 8 |
| `operating-paths-core.md`'s only non-empty line is `on PATH when the plugin is loaded; else` | the file |
| `docs/loop-engineering/` contains only `goal-loop.md`, `goal-loop.ja.md` and `loop-cron.crontab.example`; `loop-traps.md` and `model-tiering.md` do not exist | directory listing |
| Those two nonexistent files are referenced 4 times over 3 lines in `agents/scrum-master.md` and 3 times in `docs/templates/retro-template.md`; the distinct set is exactly two paths | targeted search in both files |
| `.shell-team/.gitignore` ignores `runs/`, so run telemetry is present locally and absent from a fresh clone while `.shell-team/runs/.gitkeep` stays tracked | the ignore file and the tracked-file listing |
| The existing retro records that `gh` was unusable, that the lessons log does not exist here, and that PR metadata came from another channel | `.shell-team/retros/2026-07-28.md`, `## Notes` and `## Orchestrator attest` |
| CI has one job, runs `bash tests/check-retro/run.sh`, and never runs `bin/check-retro.sh` against this repository's own retros | `.github/workflows/check-handoff.yml` |
| `tests/check-retro/run.sh`'s header still claims a dogfood assertion on `tasks/retros/2026-04-30.md`; no such assertion is in the file and no such file is in the tree | the suite's header comment versus its body |
| `docs/templates/retro-template.md` does **not** pass `bin/check-retro.sh` today: its Lesson section carries a bare `` - `<...>` `` bullet | the template's Lesson section against rule 3 |
| `tests/discover-work/fixtures/gh` is an env-driven stub whose `pr` branch exits 3 if any argv mentions `body` | the stub |
| `bin/discover-work.sh` defaults to `BASE="develop"`, exposes `--base BRANCH`, exits 0 with a `# note:` line when `gh` is missing or unauthenticated, and sanitises untrusted titles by stripping CR/LF/TAB/backticks and replacing U+2014 | the script's argument parsing, `gh` readiness block, and `sanitize()` |

## Body-to-AC correspondence

Every normative directive stated in the body above, mapped to the criterion that
carries it or to an explicit exemption with its reason.

| Body directive | Where |
|---|---|
| The cycle window is derived from git, not hardcoded and not from `gh` | AC11 |
| The hardcoded `main` base is removed from the operative surface | AC5 |
| `gh` is optional enrichment; absent, the retro is not degraded | AC9 |
| `gh` is never asked for the `body` field | AC10 |
| The `gh` field set is exactly the six structured fields | AC10 |
| The ledger records `read`/`empty`/`unavailable` per declared input | AC6 |
| The ledger is complete: all eight ids, exactly once each | AC6, AC12 |
| Each `detail:` is non-empty, and a `read` detail says how much was found | AC6 |
| The grammar is exactly three ` — `-separated fields | AC6 |
| The enumeration exists in exactly one file | AC2 |
| Single-sourcing is enforced by `check-prompt-sync`, not asserted | AC3, AC4 |
| Every artefact path resolves through `team-paths.sh` | AC7 |
| `bin/` stays pure bash and zero-dependency | AC8 |
| The checker validates against a closed enum and fails closed | AC16 |
| Unknown status, unknown id, missing id, duplicate id, empty detail, stray line are each violations | AC16 |
| New tokens are English only; no Japanese required heading is added | AC2 (block is ASCII), AC25 (count unchanged) |
| The five decorated headings and the label rule are untouched | AC17 |
| The trust boundary is stated in the checker's header | AC18 |
| `team-paths.sh` gains a `provenance` key (DP-3) | AC19 |
| `team-init.sh` scaffolds the provenance dir | AC20 |
| The template carries a ledger section, before `## Keep` | AC21 |
| The role's declared inputs are the ones that exist | AC30 |
| The lessons log is demoted to optional (DP-4) | AC14 |
| A missing ref is `unavailable`, never `empty` | AC12 |
| A zero-merge history is `empty` (DP-6) | AC12 |
| A shallow repo with no merges is `unavailable`; with merges, `read` plus a truncation note | AC12 |
| A `git` failure is `unavailable` and the ledger is still complete | AC12 |
| `--last-n` caps the window and reads differently from a truncation | AC11 |
| `develop` default, `HEAD` fallback, ref named in the detail (DP-7) | AC11 |
| Attacker-controlled text cannot forge a ledger line | AC13 |
| The emitted ledger passes the checker end to end | AC13 |
| The rule applies to the existing retro (DP-5) | AC22 |
| CI dogfoods the checker on this repository's retros | AC23 |
| CI exercises the acquisition path and shellchecks the new scripts | AC23 |
| No new pointer to a nonexistent document | AC24 |
| `bin/retro-inputs.sh` writes nothing | AC29 |
| The change stays inside its declared surface | AC26 |
| Nothing that already worked stops working | AC27 |
| The provenance record exists and is conformant | AC28 |
| Every claim about a current input is measured against this tree | **info-only (not promoted to AC)** — it constrains this spec's authoring rather than the deliverable; the `## Measured tree facts` table is the artefact that satisfies it, and AC5's base-blob read is the one part of it that is mechanically provable |
| The ledger check validates structure only and proves nothing about honesty | **info-only (not promoted to AC)** — it is a statement of what is *not* claimed; promoting it would require a criterion asserting the absence of an assertion, which is not testable. Its enforcement is that no AC in this spec claims more, which the correspondence table above makes auditable |
| A fixture label proves presence, not attachment to a real assertion | **info-only (not promoted to AC)** — the same shape as the row above; it is a declared limit on AC7/AC9/AC11–AC14, handed to QA and the reviewer rather than to a check |
| The salience channel, single-pass obligations, mandatory attest, dead pointers, transcripts, and issues #23/#24 are out of scope | **info-only (not promoted to AC)** — Non-goals; AC24 and AC26 are the two that are mechanically locked, the rest are absences no grep can distinguish from "not yet written" |

## Assumptions

- **The nine-merged-pull-requests measurement in issue #28 is taken on trust.**
  pm-spec has no shell in this role and cannot run `git log`, so the claims that
  nine pull requests merged to `develop` and that exactly one targeted `main` are
  the issue's measurements, not this spec's. Nothing in the acceptance criteria
  depends on them: AC5 proves the defect existed by reading the base blob, which
  is checkable, and AC11's behaviour is asserted against `HEAD` rather than against
  a count of merges.
- **`develop` exists as a local branch in the checkout where the criteria are
  run.** AC5, AC25 and AC26 read `develop` directly. In a CI checkout `develop`
  may exist only as a remote-tracking ref; those three criteria are for local and
  QA use, and CI does not evaluate this spec (no workflow step runs
  `bin/check-acs.sh`).
- **`shellcheck` is installed locally at the pinned 0.11.0.** AC23 invokes it
  unconditionally on purpose; a vacuous skip when it is missing would be worse
  than a loud failure.
- **`.git/shallow` is a usable way to simulate a shallow repository in a fixture.**
  It avoids `git clone --depth`, which has been denied by sandbox policy in this
  repository before. If the engineer finds a tree where that is not equivalent,
  the fixture may use a real shallow clone instead — the criterion names the
  behaviour, not the technique.
- **`run-telemetry` legitimately differs between the maintainer's checkout and a
  fresh clone.** This is a measured consequence of `.shell-team/.gitignore`, not a
  defect, and it is why AC6 pins the ledger's *shape* rather than a specific status
  for that input.

## Open questions

None blocking. Two things were decided rather than asked, and both are recorded
above with their reasoning: the retroactive backfill (DP-5) and the exclusion of
the legacy provenance hardcodes (DP-3).

## Notes for engineer

**Files this task touches.** `bin/retro-inputs.sh` (new),
`templates/prompt-blocks/retro-inputs.md` (new),
`templates/prompt-blocks/registry.txt`, `bin/check-retro.sh`,
`bin/team-paths.sh`, `bin/team-init.sh`, `agents/scrum-master.md`,
`docs/templates/retro-template.md`, `.shell-team/retros/2026-07-28.md`,
`tests/retro-inputs/` (new, with `fixtures/gh` and `fixtures/git` stubs),
`tests/check-retro/` (seven new fixtures plus suite cases),
`tests/team-paths/run.sh`, `tests/team-init/run.sh`,
`.github/workflows/check-handoff.yml`, plus this task's board entry, provenance
file and review record. AC26's allow-list is the authority.

**The ledger grammar, once.** One physical line per input:

```
- input: <id> — status: <read|empty|unavailable> — detail: <one non-empty line>
```

with optional indented sub-bullets beneath carrying the material itself (the merge
commits, the pull requests). Separators are space-padded U+2014 EM DASH, the same
separator `bin/check-handoff.sh`'s `LINE_RE` uses. Indentation is what keeps
material out of the parsed surface: a sub-bullet is not a top-level bullet, so it
cannot be read as a ledger line — which is exactly why stripping newlines from
untrusted text (AC13) is load-bearing rather than decorative.

**Sequence that avoids rework.** Write
`templates/prompt-blocks/retro-inputs.md` first, register it, and let
`bin/check-prompt-sync.sh` tell you which consumer is missing a line, rather than
hand-copying twelve lines four times and discovering a typo at the end.

**Watch the self-hitting grep in AC8.** Write the dependency note in
`bin/retro-inputs.sh` as `no jq/yq/python` — a slash or comma after the word.
`depends on nothing but bash and jq` at end of line would trip AC8's own pattern.

**`bin/team-paths.sh` has four places that list the keys**, not one: the header
usage comment, `print_help`, the `case "$GET_KEY"` branches, and the `die`
message's key list. AC19 reads three of them; miss the fourth and the error
message lies.

**The existing `pass-canonical.md` fixture will start failing** the moment
`bin/check-retro.sh` requires a `## Retro inputs` section, and so will
`.shell-team/retros/2026-07-28.md`. Update the fixture and backfill the retro in
the same change as the checker, or the suite is red in between.

**Do not add a CI step that runs `bin/check-retro.sh` on
`docs/templates/retro-template.md`.** It does not pass today, for a reason
unrelated to this task (a bare bullet in its Lesson section), and making it pass
is a Non-goal.

**Before you hand off**, mutate each new lock and watch it fail: delete a ledger
line from a fixture, change a status to a fourth value, duplicate an id, blank a
`detail:`, and re-widen the shallow-repository classification from `unavailable`
to `empty`. A lock you have not seen fail is a lock you have not tested. The same
applies to the fixture-label criteria: the label is the lock's handle, the
assertion under it is the lock, and only you can confirm the two match.

**Prior art worth reading before writing anything.**
`bin/discover-work.sh` for the `--base` default, the `gh` fail-soft path and
`sanitize()`; `tests/discover-work/fixtures/gh` for the env-driven stub shape and
its `body` guard; `bin/check-provenance.sh` for a checker that states its own
trust boundary in its header; `bin/check-retro.sh`'s existing rule-3 awk pass for
the region walk the ledger check should follow.
