# T-112 — commit-identity assertion, and a lock on the raw-dump ignore coverage

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-112
**Intent version**: v2 — re-frozen 2026-07-27 under a human-ratified v1→v2. The
only change was inserting `--` after the option cluster of every `grep` whose
fixed-string pattern begins with a literal `-` (15 sites across the three
specs), because getopt made grep parse the pattern as an option and exit 2. The
asserted semantics (whole-line fixed-string match) are identical to v1. This
line lives OUTSIDE the intent block: the version of record is the board's
`intent-hash (vN)` ledger, and the marker lines themselves are matched by exact
full-line compare, so neither may carry a version token.
**Source**: GitHub issue #6 (RipsawJP/shell-team) — Layer 1 items 1 and 2.
**Branch**: `feature/pii-controls` (from `develop`). Second of three tasks on this
one branch; depends on T-111 (both edit the same shellcheck argument line, and
this task's own diff is scanned by the checker T-111 adds).

## Problem

Identity metadata is not file content, so a content scan misses it entirely, and
rewriting history does not remove the objects that already carry it. This is the
one PII class that has actually bitten this project. The measured state of this
repository's history shows two distinct shapes: locally-made commits where
author and committer are both the `<id>+<login>@users.noreply.github.com` form,
and GitHub-generated merge commits whose author is a personal mailbox at a
personal domain and whose committer is GitHub's plain web-flow noreply identity.
So a naive assertion demanding the `+login` form of every commit would both fail
on history it cannot fix and reject GitHub's own web-flow identity. Separately,
the ignore coverage that keeps raw review dumps and telemetry untracked already
ships, but nothing fails if someone deletes it.

## Goal

<!-- BEGIN intent-block: T-112 -->

A pull request whose own commits carry a non-noreply author or committer
identity fails a required CI check, with a report that names the commit and the
side that is non-conformant and never echoes the identity value into a public
log. The check is scoped to the commits the pull request contributes, so it
never reds on pre-existing history, and its disposition for merge commits and
for GitHub's web-flow identity is explicit and covered by fixtures. Separately,
the already-shipped ignore coverage for raw review dumps becomes a test: if
someone removes a pattern, a suite fails.

## Non-goals

- **Designing new `.gitignore` patterns.** Item 2 is a lock, not a design. The
  existing coverage in `/.gitignore` and `.shell-team/.gitignore` stays
  byte-unchanged (AC18).
- **Duplicating what `tests/rollup-track/run.sh` already locks.** That suite
  already asserts `.shell-team/runs/` stays ignored and `.shell-team/rollups/`
  does not; this task's new suite covers the raw review dumps and the
  `.codex-review.json` dump, and the tracked side (curated review notes).
- **Removing PII from commits that are already published.** The pre-existing
  author-side exposure in already-merged history is a separate concern: a
  forward-looking gate does not remove existing objects, rewriting published
  history is a separate human decision, and the remediation is an operator-side
  account setting rather than a repository change. This spec states that without
  quoting any value.
- **Verifying who an identity belongs to.** The gate checks the *shape* of the
  identity, not that the login inside it is the person who pushed. Signature
  (GPG / sigstore) verification is out of scope.
- **Named entities, semantic sensitivity, image content** — the same out-of-scope
  list as T-111, restated in `docs/pii-controls.md` by T-111 and not weakened
  here.
- **Making `--all` (T-111) a required CI check**, and **any AI-driven CI
  workflow**.
- **The lessons de-identification rule** (T-113).

## Acceptance criteria

Every `check:` runs from the repository root. `<base>` is `develop`.

- [ ] **AC1** `bin/check-commit-identity.sh`,
  `tests/check-commit-identity/run.sh` and `tests/gitignore-raw-dumps/run.sh`
  exist, are pure bash with a `#!/usr/bin/env bash` shebang, are
  shellcheck-clean, and add no runtime dependency outside bash + standard POSIX
  tools + `git`.
  - check: shellcheck bin/check-commit-identity.sh tests/check-commit-identity/run.sh tests/gitignore-raw-dumps/run.sh && grep -q '#!/usr/bin/env bash' bin/check-commit-identity.sh && test "$(grep -vcE '^[[:space:]]*#' bin/check-commit-identity.sh)" -gt 0 && test "$(grep -vE '^[[:space:]]*#' bin/check-commit-identity.sh | grep -cwE 'jq|yq|python|python3|perl|gawk')" -eq 0
- [ ] **AC2** The exit-code contract follows `bin/check-provenance.sh`: `0` =
  conformant, `1` = findings, `2` = usage or structural error — including an
  unresolvable base ref, a path that is not a git repository, and an unknown
  flag.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'exit-code contract' tests/check-commit-identity/run.sh && grep -qF 'unresolvable base ref' tests/check-commit-identity/run.sh
- [ ] **AC3** `--help` exits 0 and documents `--base <ref>`; an unknown flag
  exits 2.
  - check: bash bin/check-commit-identity.sh --help | grep -qF -- '--base' && { bash bin/check-commit-identity.sh --bogus >/dev/null 2>&1; test $? -eq 2; }
- [ ] **AC4** The checked range is exactly the non-merge commits from
  `git merge-base <base> HEAD` to `HEAD` (see DP-1). A commit outside that range
  is never inspected, so pre-existing history cannot red the gate.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'range: non-merge commits from the merge-base to HEAD' tests/check-commit-identity/run.sh
- [ ] **AC5** A commit in range whose **author** identity is a mailbox shape
  outside the allowed set is reported with the pattern id `author-identity`; the
  conformant counterpart is clean.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'POS/NEG pair: author-identity' tests/check-commit-identity/run.sh
- [ ] **AC6** A commit in range whose **committer** identity is a mailbox shape
  outside the allowed set is reported with the pattern id
  `committer-identity`; the conformant counterpart is clean. Both sides are
  checked, not just the author.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'POS/NEG pair: committer-identity' tests/check-commit-identity/run.sh
- [ ] **AC7** Merge-commit disposition (DP-1): a merge commit in the range whose
  author is a non-noreply mailbox shape and whose committer is the plain
  web-flow noreply identity — the exact shape this repository's own merged
  history contains — is clean, because merge commits are excluded from the
  range.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'disposition: merge commits are excluded from the range' tests/check-commit-identity/run.sh
- [ ] **AC8** Web-flow disposition, allowed half (DP-1): a **non-merge** commit
  whose committer is the plain web-flow noreply identity and whose author is the
  `<id>+<login>@users.noreply.github.com` form is clean. This is the shape a
  commit created through the GitHub web editor or the API carries.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'disposition: web-flow committer identity is allowed' tests/check-commit-identity/run.sh
- [ ] **AC9** Web-flow disposition, refused half (DP-1): the plain web-flow
  noreply identity on the **author** side is a finding. The allowance is
  committer-side only.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'disposition: web-flow identity is NOT allowed on the author side' tests/check-commit-identity/run.sh
- [ ] **AC10** Suffix anchoring: an identity whose domain merely *contains* the
  noreply domain as a substring (a lookalike domain with anything appended) is a
  finding, on both sides. The allowed-form match is anchored at the end of the
  address, never a substring test.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'anchor: lookalike noreply domain is a finding' tests/check-commit-identity/run.sh
- [ ] **AC11** An empty range (no commits between the comparison point and
  `HEAD`) exits 0 and reports nothing — a gate that has nothing to judge is
  clean, not an error.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'empty range is clean' tests/check-commit-identity/run.sh
- [ ] **AC12** Vacuity guard, detector side: the suite produces a copy of the
  checker with the allowed-identity rule neutralised, runs the positive fixtures
  against the copy, and requires the copy to report nothing — proving the rule
  is load-bearing rather than the fixtures being caught by something else.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'mutation: identity pattern is load-bearing' tests/check-commit-identity/run.sh
- [ ] **AC13** Vacuity guard, fixture side (meta-assertion): for every positive
  fixture the suite calls its own positive-assertion helper against a
  *neutralised* fixture (one whose identity has been replaced by a conformant
  one) in a subshell and requires that call to FAIL. Neutralising a positive
  fixture therefore makes the suite fail.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'meta: neutralised positive fixture makes the assertion FAIL' tests/check-commit-identity/run.sh
- [ ] **AC14** A finding never echoes the identity value: the report names the
  commit and the non-conformant side (`author-identity` / `committer-identity`)
  only. The suite proves this by asserting the checker output does not contain
  the distinctive local part of the fixture identity it just rejected.
  - check: bash tests/check-commit-identity/run.sh && grep -qF 'no-leak: finding output never echoes the identity value' tests/check-commit-identity/run.sh
- [ ] **AC15** Fixtures are throwaway git repositories created under `mktemp`,
  and every non-noreply address used in them is synthetic and assembled at
  runtime from fragments, so no mailbox-shaped literal enters the tree (the same
  discipline T-111 DP-1 option (a) fixed, and what keeps AC17 passing).
  - check: grep -qF 'mktemp' tests/check-commit-identity/run.sh && grep -qF 'identities are assembled at runtime from fragments' tests/check-commit-identity/run.sh
- [ ] **AC16** Self-application, identity side: the new checker, run against
  `<base>`, exits 0 for this branch's own commits.
  - check: bash bin/check-commit-identity.sh --base develop
- [ ] **AC17** Self-application, shape side: T-111's checker still exits 0 on
  this branch's diff after this task's files land, and T-111's suite still
  passes.
  - check: bash bin/check-pii-shapes.sh --base develop && bash tests/check-pii-shapes/run.sh
- [ ] **AC18** The ignore coverage is locked by test, not redesigned: raw review
  dumps (`.txt` / `.json` / `.jsonl` under the resolved reviews dir) and
  `.codex-review.json` are ignored, curated review notes (`.md`) are **not**
  ignored, each assertion pins `core.excludesFile` explicitly, and a control
  assertion proves the hostile `core.excludesFile` has teeth — the three-check
  structure `tests/rollup-track/run.sh` established. Both `.gitignore` files
  are byte-unchanged against `<base>`.
  - check: bash tests/gitignore-raw-dumps/run.sh && grep -qF 'lock: raw review dumps are ignored' tests/gitignore-raw-dumps/run.sh && grep -qF 'lock: codex-review json dump is ignored' tests/gitignore-raw-dumps/run.sh && grep -qF 'lock: curated review notes are NOT ignored' tests/gitignore-raw-dumps/run.sh && grep -qF 'control: hostile excludesFile has teeth' tests/gitignore-raw-dumps/run.sh && git diff --quiet develop -- .gitignore .shell-team/.gitignore
- [ ] **AC19** Operating paths are resolved through `bin/team-paths.sh`: the new
  ignore-lock suite derives the reviews dir from the resolver rather than
  hardcoding `.shell-team/reviews`, and covers both the default and legacy
  layouts the resolver reports.
  - check: grep -qF 'team-paths.sh' tests/gitignore-raw-dumps/run.sh && grep -qF 'legacy' tests/gitignore-raw-dumps/run.sh
- [ ] **AC20** CI wiring: the shellcheck argument list gains all three new
  files, each suite gets its own step, and a required step runs the identity
  check against the pull request's base.
  - check: grep -qF 'bin/check-commit-identity.sh tests/check-commit-identity/run.sh tests/gitignore-raw-dumps/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: Run check-commit-identity fixture suite' .github/workflows/check-handoff.yml && grep -qF 'run: bash tests/check-commit-identity/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: Run gitignore-raw-dumps lock suite' .github/workflows/check-handoff.yml && grep -qF 'run: bash tests/gitignore-raw-dumps/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: check-commit-identity on the PR commits' .github/workflows/check-handoff.yml && grep -qE 'bash bin/check-commit-identity\.sh --base' .github/workflows/check-handoff.yml
- [ ] **AC21** The two scope statements for this gate are present verbatim, each
  as one physical line, in both documents (exact text under "Canonical document
  lines"): the merge-commit exclusion, and the forward-looking-only limitation
  whose remediation is an operator-side account setting.
  - check: grep -qxF -- '- The commit-identity gate checks only the non-merge commits a pull request adds; merge commits are excluded because their identity is set by the merging party, not by the author of the change.' docs/pii-controls.md && grep -qxF -- '- The gate is forward-looking: it does not remove identity metadata from commits that are already published, and the remediation for a past exposure is an operator-side account setting, not a repository change.' docs/pii-controls.md && grep -qxF -- '- commit identity のゲートは pull request が追加する非マージコミットだけを見る。マージコミットの identity はマージした側が決めるものであり、変更の作者には直せないため対象外とする。' docs/pii-controls.ja.md && grep -qxF -- '- このゲートは前向きの制御であり、すでに公開されたコミットの identity メタデータは取り除かない。過去の露出に対する是正はリポジトリの変更ではなくオペレータ側のアカウント設定で行う。' docs/pii-controls.ja.md
- [ ] **AC22** No wording that implies complete coverage: T-111's canonical
  "shapes only" line is still present in both documents after this task edits
  them, and none of the badge-shaped claim compounds appears in the documents or
  either README (each file proved readable first).
  - check: grep -qxF 'This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.' docs/pii-controls.md && grep -qxF 'このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。' docs/pii-controls.ja.md && grep -qF 'shell-team' README.md && grep -qF 'shell-team' README.ja.md && ! grep -F -e 'PII-gated' -e 'PII-free' -e 'PII-clean' -e 'PII-safe' docs/pii-controls.md docs/pii-controls.ja.md README.md README.ja.md
- [ ] **AC23** Every stderr write in the new script — outside comment lines —
  carries a `|| true` guard on the same physical line, and the check fails if
  there are no stderr writes at all.
  - check: test "$(grep -vE '^[[:space:]]*#' bin/check-commit-identity.sh | grep -c '>&2')" -gt 0 && test "$(grep -vE '^[[:space:]]*#' bin/check-commit-identity.sh | grep '>&2' | grep -vc '|| true')" -eq 0
- [ ] **AC24** A decision provenance file for this task exists and is
  schema-conformant.
  - check: bash bin/check-provenance.sh .shell-team/provenance/T-112.md
- [ ] **AC25** Nothing outside this task's surface is disturbed: prompt blocks
  are still in sync, and the suites this task's neighbours own still pass.
  - check: bash bin/check-prompt-sync.sh && bash tests/rollup-track/run.sh && bash tests/check-handoff/run.sh && bash tests/team-paths/run.sh

## Input space

**Reachable input classes** — identity and range conditions this repository and
its workflow actually produce:

1. A locally-made commit whose author and committer are both the
   `<id>+<login>@users.noreply.github.com` form (measured: the conformant shape
   in this repo's history).
2. A GitHub-generated merge commit whose author is a personal mailbox at a
   personal domain and whose committer is the plain web-flow noreply identity
   (measured: present in this repo's merged history).
3. A commit created through the GitHub web editor or the REST API — a *non-merge*
   commit whose committer is the plain web-flow noreply identity. This project's
   documented fallback for pushing from a sandbox creates exactly this shape.
4. A commit authored on a machine whose git config was never set to the noreply
   form — the class this gate exists to catch, on either the author or the
   committer side.
5. An identity with an unusual but legitimate local part: a `+` tag, dots, a
   long numeric id.
6. Range conditions: an empty range; a single commit; a branch that has had the
   base merged back into it; a squashed or rebased branch where the merge-base
   moved; a base ref that exists only as a remote-tracking ref; an unresolvable
   base ref (exit 2); a directory that is not a git repository (exit 2).
7. Ignore-lock conditions: this repo's real config, a repo with no re-include, a
   pinned-empty `core.excludesFile`, and a hostile global `core.excludesFile`
   that ignores the whole base dir — plus both layouts the path resolver reports.

**Out-of-scope synthetic extremes** — declined deliberately:

1. Forged or spoofed identity ownership: a syntactically conformant noreply
   address belonging to someone else, or a mismatch between the numeric id and
   the login. The gate reads shape, not ownership.
2. Cryptographic verification of any kind (GPG / sigstore signatures, signed
   pushes).
3. Homoglyph or internationalised-domain variants of the noreply domain, and
   deliberately malformed identity metadata written directly into a commit
   object with plumbing commands.
4. Ever-larger commit ranges as a performance adversary, and shallow clones
   deeper than what CI's `fetch-depth: 0` checkout produces.
5. A hostile author who edits the checker or the ignore files in the same commit
   to disable them — PR review is that layer, not this checker (the same trust
   boundary `bin/check-acs.sh` documents).

<!-- END intent-block: T-112 -->

## Resolved design decisions

### DP-1 — commit range, and the merge-commit / web-flow disposition

**Range.** The non-merge commits from `git merge-base <base> HEAD` to `HEAD`
(`git rev-list --no-merges <merge-base>..HEAD`). Reasons: the pull request's own
commits are the only ones its author can fix; the merge-base makes the range
stable across squash, rebase and multi-commit branches (the same resolution
`bin/check-board-headings.sh` documents); and anything reachable outside that
range is pre-existing published history that a forward-looking gate must not red.

**Disposition.** One composite disposition, both halves fixture-covered:

1. **Merge commits are excluded from the range** (`--no-merges`). A merge
   commit's identity is set by the merging party — GitHub's web flow, or a
   maintainer merging the base back in — not by the author of the change under
   review, so demanding the `+login` form there would reject an identity nobody
   on the pull request can change. Fixture: AC7, reproducing the exact shape
   measured in this repository's merged history.
2. **The plain web-flow noreply identity is a named allowed identity on the
   committer side only.** Fixture: AC8 (allowed on the committer side), AC9
   (refused on the author side).

**Why not exclusion alone.** Exclusion by itself would leave a reachable false
red: a commit created through the GitHub web editor or the REST API is *not* a
merge commit, and its committer is the plain web-flow noreply identity. This
project's own documented fallback for pushing from a sandboxed session creates
commits that way, so that class is reachable, not hypothetical (input class 3).
Excluding merges closes the measured merge-commit case; the committer-side
allowance closes the API/web-editor case. Neither half is redundant, and neither
half loosens the author side — which remains exactly the
`<id>+<login>@users.noreply.github.com` form.

**Stated coverage hole.** A merge commit made locally by a contributor is not
identity-checked, because merges are excluded wholesale. This is accepted and
documented (AC21's first canonical line) rather than papered over: the
alternative — checking merges while allowing the web-flow identity on both sides
— would weaken the author-side rule for every commit, which is the rule that
matters most.

### DP-2 — the allowed-form match must be end-anchored

The allowed set is matched against the *end* of the address, never as a
substring: a lookalike domain that merely contains the noreply domain with
anything appended is a finding (AC10). This is the classic suffix-anchor blind
spot in this class of checker, so it gets its own fixture rather than a comment.

### DP-3 — findings must not print the identity

A report that echoed the rejected address would write PII into a public CI log —
converting a control into a leak. The report names the commit and the
non-conformant side only (AC14). The same reasoning governs T-111's AC14, and
the two must stay consistent.

### Canonical document lines

Each is one physical line, appended to the documents T-111 creates.
`docs/pii-controls.md`:

```text
- The commit-identity gate checks only the non-merge commits a pull request adds; merge commits are excluded because their identity is set by the merging party, not by the author of the change.
- The gate is forward-looking: it does not remove identity metadata from commits that are already published, and the remediation for a past exposure is an operator-side account setting, not a repository change.
```

`docs/pii-controls.ja.md`:

```text
- commit identity のゲートは pull request が追加する非マージコミットだけを見る。マージコミットの identity はマージした側が決めるものであり、変更の作者には直せないため対象外とする。
- このゲートは前向きの制御であり、すでに公開されたコミットの identity メタデータは取り除かない。過去の露出に対する是正はリポジトリの変更ではなくオペレータ側のアカウント設定で行う。
```

### Canonical suite assertion labels

`tests/check-commit-identity/run.sh`:

```text
exit-code contract
unresolvable base ref
range: non-merge commits from the merge-base to HEAD
POS/NEG pair: author-identity
POS/NEG pair: committer-identity
disposition: merge commits are excluded from the range
disposition: web-flow committer identity is allowed
disposition: web-flow identity is NOT allowed on the author side
anchor: lookalike noreply domain is a finding
empty range is clean
mutation: identity pattern is load-bearing
meta: neutralised positive fixture makes the assertion FAIL
no-leak: finding output never echoes the identity value
identities are assembled at runtime from fragments
```

`tests/gitignore-raw-dumps/run.sh`:

```text
lock: raw review dumps are ignored
lock: codex-review json dump is ignored
lock: curated review notes are NOT ignored
control: hostile excludesFile has teeth
```

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| Author **and** committer must both be the noreply `+login` form | AC5, AC6 |
| Range is the PR branch's own commits, not reachable history | AC4 |
| Merge commits excluded (DP-1 half 1) | AC7 |
| Web-flow identity allowed on the committer side (DP-1 half 2) | AC8 |
| Web-flow identity refused on the author side | AC9 |
| Allowed-form match end-anchored (DP-2) | AC10 |
| Empty range is clean, not an error | AC11 |
| Vacuity guard, detector side | AC12 |
| Vacuity guard, fixture side (meta-assertion) | AC13 |
| Findings must not echo the identity (DP-3) | AC14 |
| No mailbox-shaped literal enters the tree | AC15, enforced by AC17 |
| Self-application on this PR's own commits and diff | AC16, AC17 |
| Item 2 is lock-by-test only; no new ignore patterns | AC18 (both halves: the lock, and byte-unchanged ignore files) |
| Control assertion proving the lock is not vacuous | AC18 (`control: hostile excludesFile has teeth`) |
| Never hardcode operating paths | AC19 |
| CI wiring | AC20 |
| Merge-commit exclusion and the forward-looking limitation stated in `docs/` | AC21 |
| No wording implying complete coverage | AC22 |
| `|| true`-guarded stderr writes | AC23 |
| Provenance file required | AC24 |
| Pre-existing author-side exposure is out of scope; remediation is an operator-side account setting | AC21 (second canonical line) — the *statement* is promoted; the remediation itself is deliberately not an AC because it is not a repository change |
| Identity values are described by shape only, never transcribed | info-only (not promoted to AC) — a writing constraint on this task's artifacts; enforced indirectly by AC17, since a transcribed non-noreply address would red the shape checker |
| Does not duplicate `tests/rollup-track/run.sh`'s existing ignore coverage | info-only (not promoted to AC) — a scoping choice; AC25 pins that suite still passing, which is the only observable property that matters |
| Shape, not ownership; no signature verification | info-only (not promoted to AC) — a declared limit of the mechanism, recorded in Input space out-of-scope class 1-2 |
| No AI-driven CI workflow | info-only (not promoted to AC) — repo-wide invariant, not introduced here; AC20 pins the workflow edits made |

## Assumptions

- `origin/$GITHUB_BASE_REF` resolves in CI's pull_request context because the
  checkout uses `fetch-depth: 0`. Unverified for the push-to-`develop` event,
  where the range is expected to be empty (AC11 covers that path).
- T-111 has landed on this branch before this task starts, so
  `bin/check-pii-shapes.sh` exists for AC17. This is the declared dependency
  edge.
- The measured identity shapes in this repository's history (input classes 1 and
  2) were read read-only by the orchestrator at task-open time and are recorded
  here by shape only. No concrete address appears in this spec, in the fixtures,
  or in the board.
- `git check-ignore -c core.excludesFile=<file>` behaves as
  `tests/rollup-track/run.sh` already relies on; the new suite reuses that
  pattern rather than inventing one.

## Open questions

None blocking. DP-1, DP-2 and DP-3 are decided here.

## Notes for engineer

- Prior art: `tests/rollup-track/run.sh` lines that pin `core.excludesFile` and
  the `control: hostile excludesFile has teeth` assertion — copy that structure
  for the ignore lock, including the "no re-include" control repo, so the lock
  cannot pass because the hostile file was silently ineffective.
  `bin/check-provenance.sh` for the fail-closed skeleton and the classification
  tokens on stderr. `bin/check-board-headings.sh` for merge-base resolution.
- Building fixtures means `git init` in `mktemp` directories and committing with
  `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_EMAIL` set per commit — that is how the
  author and committer sides get to differ, and how the merge-commit shape in
  AC7 is reproduced. Keep every address synthetic and assembled from fragments.
- Before hand-off, run the mutation self-check by hand: neutralise the
  allowed-identity rule, watch the suite go red, restore it. Then ask what your
  own detector is blind to — does it read only the first commit in the range;
  does it compare the address with a substring test instead of an anchored one
  (AC10 exists because that is the likely bug); does it treat a commit whose
  committer field is empty as conformant.
- Files expected to change: `bin/check-commit-identity.sh` (new),
  `tests/check-commit-identity/run.sh` (new),
  `tests/gitignore-raw-dumps/run.sh` (new), `docs/pii-controls.md` and
  `docs/pii-controls.ja.md` (append the two canonical lines each),
  `.github/workflows/check-handoff.yml` (shellcheck list plus three steps),
  `.shell-team/provenance/T-112.md` (new), `.shell-team/todo.md` (status flag).
- No whole-diff scope-lock AC here, for the same reason as T-111: three tasks
  share one branch and such an allow-list would go stale when T-113 lands.
  AC18's `git diff --quiet develop -- .gitignore .shell-team/.gitignore` and
  AC25's suite runs are the targeted invariants instead.
