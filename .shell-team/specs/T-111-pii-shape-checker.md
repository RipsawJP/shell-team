# T-111 — diff-scoped PII shape checker (`bin/check-pii-shapes.sh`)

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-111
**Source**: GitHub issue #6 (RipsawJP/shell-team) — Layer 2 items 4 and 5, plus the
user instruction that the out-of-scope declarations be stated in `docs/`.
**Branch**: `feature/pii-controls` (from `develop`). Executed first of three tasks
on this one branch (T-111 → T-112 → T-113).

## Problem

Development on this repository happens in the open, which makes PII exposure a
per-commit risk rather than a one-time migration risk. Today there is no
automated control at all: the CI workflow has no step that looks for PII, and
`bin/` has no checker for it. GitHub's secret scanning and push protection
target credentials, not PII — they do not flag an email-shaped string, a
home-directory absolute path, or an employer name. The only control in force is
human discipline plus a paragraph of guidance, which is the wrong shape for
something the project treats as its top constraint. One narrow precedent exists
in-tree (`tests/rollup-track/run.sh` asserts a single tracked artifact carries
no email shape and no `/Users/` or `/home/` path); this task generalizes that
idea from one artifact to what a pull request adds.

## Goal

<!-- BEGIN intent-block: T-111 -->

A pull request that adds a PII-shaped byte to this repository fails a required
CI check, and the same check can be run by a developer from the repository root
before pushing. The check is diff-scoped (it judges what the change adds, not
the whole tree), fail-closed (it can never pass because it failed to evaluate
its input), and it reports *which* shape fired and *where* without echoing the
matched text into a public CI log. Its own test suite proves the detector
actually fires, one shape at a time. A `docs/pii-controls.md` /
`docs/pii-controls.ja.md` pair states plainly, and in words a reader cannot
mistake, that this gate sees shapes only and what it therefore does not cover.

## Non-goals

- **Patterns for named entities.** Customer names, internal hostnames and
  project codes cannot be matched by shape, and the patterns that would match
  them are themselves the sensitive data, so they must not live in this public
  repository. They belong in an operator-local check outside the repo.
- **Semantic sensitivity.** A design decision, or a context from which a reader
  can infer a business relationship, is not a PII shape and is not detected.
- **Image content.** Not inspected. Metadata only, if anything — and this task
  does not add metadata inspection either.
- **Rewriting existing history / removing PII from existing git objects.** This
  task installs a forward-looking gate only.
- **New `.gitignore` patterns.** Out of scope here (and in T-112, where the
  already-shipped coverage is locked by a test, not redesigned).
- **Making `--all` a required CI check.** `--all` necessarily reports the
  deliberately PII-shaped adversarial fixtures that already live under `tests/`,
  so it is an audit flag only.
- **Any AI-driven CI workflow.** This repo's CI invariant stays
  `actions/checkout` + bash only.
- **Commit-identity assertion and the `.gitignore` lock** (T-112), and the
  **lessons de-identification rule** (T-113).
- **A README badge, summary line, or any other claim that this repository is
  PII-checked.** See AC18.

## Acceptance criteria

Every `check:` runs from the repository root. `<base>` in the checks below is
`develop`, the branch this work forks from.

- [ ] **AC1** `bin/check-pii-shapes.sh` and `tests/check-pii-shapes/run.sh`
  exist, are pure bash with a `#!/usr/bin/env bash` shebang, are
  shellcheck-clean, and introduce no runtime dependency outside bash + standard
  POSIX tools (no `jq`, `yq`, `python`, `perl`, `gawk`).
  - check: shellcheck bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh && grep -q '#!/usr/bin/env bash' bin/check-pii-shapes.sh && grep -q '#!/usr/bin/env bash' tests/check-pii-shapes/run.sh && test "$(grep -vcE '^[[:space:]]*#' bin/check-pii-shapes.sh)" -gt 0 && test "$(grep -vE '^[[:space:]]*#' bin/check-pii-shapes.sh | grep -cwE 'jq|yq|python|python3|perl|gawk')" -eq 0
- [ ] **AC2** The exit-code contract follows `bin/check-provenance.sh`: `0` =
  clean, `1` = findings, `2` = usage or structural error — including an
  unresolvable base ref, an unreadable input, an unknown flag, and `--all`
  combined with `--base`. A check that cannot evaluate its input never exits 0.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'exit-code contract' tests/check-pii-shapes/run.sh && grep -qF 'unresolvable base ref' tests/check-pii-shapes/run.sh
- [ ] **AC3** `--help` exits 0 and documents `--all` and `--base <ref>`; an
  unknown flag exits 2.
  - check: bash bin/check-pii-shapes.sh --help | grep -qF -- '--all' && bash bin/check-pii-shapes.sh --help | grep -qF -- '--base' && { bash bin/check-pii-shapes.sh --bogus >/dev/null 2>&1; test $? -eq 2; }
- [ ] **AC4** Pattern `home-path` (a POSIX home-directory absolute path with a
  name segment) has a positive fixture that is reported and a near-miss negative
  fixture that is not, and the suite asserts the reported pattern id is exactly
  `home-path`.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: home-path' tests/check-pii-shapes/run.sh
- [ ] **AC5** Pattern `home-path-win` (the Windows `C:` user-directory form) has
  the same positive / negative pair with the reported id asserted.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: home-path-win' tests/check-pii-shapes/run.sh
- [ ] **AC6** Pattern `email-nonnoreply` has the same positive / negative pair
  with the reported id asserted, and its negative side covers **both** GitHub
  noreply identity shapes (the `<id>+<login>@users.noreply.github.com` form and
  the plain web-flow `noreply@github.com` form) as non-findings.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: email-nonnoreply' tests/check-pii-shapes/run.sh && grep -qF 'negative: both noreply identity shapes' tests/check-pii-shapes/run.sh
- [ ] **AC7** Pattern `private-key` (a PEM private-key header line) has the same
  positive / negative pair with the reported id asserted.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: private-key' tests/check-pii-shapes/run.sh
- [ ] **AC8** Pattern `token` (credential-token prefixes) has the same positive /
  negative pair with the reported id asserted, and its negative side is a
  *short lookalike* that must not fire — the same false-positive class
  `tests/rollup-track/run.sh` already guards for its own write-time guard.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: token' tests/check-pii-shapes/run.sh && grep -qF 'negative: short lookalike must not fire' tests/check-pii-shapes/run.sh
- [ ] **AC9** The documented placeholder forms are not findings: a line
  containing `/Users/<name>/`, `/home/<name>/`, `C:\Users\<name>\` or
  `<id>+<login>@users.noreply.github.com` is clean. This is what makes this
  spec, the docs pair, and the checker's own source writable without an
  exemption mechanism, so it is a permanent false-positive regression case.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'placeholder forms are not findings' tests/check-pii-shapes/run.sh
- [ ] **AC10** Vacuity guard, detector side: for **every** pattern the suite
  produces a copy of the checker with that one pattern neutralised, runs that
  pattern's positive fixture against the copy, and requires the copy to report
  nothing. This proves each pattern is individually load-bearing and that no
  positive fixture is being caught by a different pattern.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'mutation: pattern is load-bearing' tests/check-pii-shapes/run.sh
- [ ] **AC11** Vacuity guard, fixture side (meta-assertion): for **every**
  pattern the suite calls its own positive-assertion helper against a
  *neutralised* positive fixture in a subshell and requires that call to FAIL.
  Neutralising a positive fixture therefore makes the suite fail, so a fixture
  that silently stopped carrying its shape cannot pass. This mirrors the
  `control: hostile excludesFile has teeth` assertion in
  `tests/rollup-track/run.sh`.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'meta: neutralised positive fixture makes the assertion FAIL' tests/check-pii-shapes/run.sh
- [ ] **AC12** No PII-shaped byte enters the tree: every fixture is assembled at
  runtime from fragments under `mktemp`, and `tests/check-pii-shapes/` contains
  no fixtures directory and no committed fixture file.
  - check: test ! -e tests/check-pii-shapes/fixtures && test ! -L tests/check-pii-shapes/fixtures && test "$(find tests/check-pii-shapes -type f | wc -l | tr -d ' ')" = "1" && grep -qF 'mktemp' tests/check-pii-shapes/run.sh
- [ ] **AC13** No per-path exemption: a PII-shaped added line is reported even
  when the path carrying it is `bin/check-pii-shapes.sh` itself or a file under
  `tests/check-pii-shapes/`. There is no path allowlist and no inline allow
  marker anywhere in the checker.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'no-allowlist: finding reported even for the checker own path' tests/check-pii-shapes/run.sh
- [ ] **AC14** A finding never echoes the matched text: the report names the
  pattern id and the path (and a line number when one is available) only. The
  suite proves this by asserting the checker output does not contain the
  distinctive positive-fixture string it just caught.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'no-leak: finding output never echoes the matched text' tests/check-pii-shapes/run.sh
- [ ] **AC15** Self-application: the checker, run diff-scoped against `<base>`,
  exits 0 on this branch — the branch that adds the checker, its suite, the docs
  pair and these specs.
  - check: bash bin/check-pii-shapes.sh --base develop
- [ ] **AC16** `--all` exists as a full-tree audit mode, is fail-closed the same
  way, reports the deliberately PII-shaped adversarial fixtures that already
  live under `tests/` (so it exits 1 on this tree, naming at least one `tests/`
  path), and is invoked **nowhere** in the CI workflow.
  - check: out="$(bash bin/check-pii-shapes.sh --all 2>&1)"; rc=$?; test "$rc" -eq 1 && printf '%s\n' "$out" | grep -qE 'tests/' && grep -qF 'check-pii-shapes' .github/workflows/check-handoff.yml && ! grep -qF -- '--all' .github/workflows/check-handoff.yml
- [ ] **AC17** CI wiring: the workflow's single shellcheck argument list gains
  `bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh`, a
  `Run check-pii-shapes fixture suite` step runs the suite, and a separate
  required step runs the checker diff-scoped with an explicit `--base`.
  - check: grep -qF 'bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: Run check-pii-shapes fixture suite' .github/workflows/check-handoff.yml && grep -qF 'run: bash tests/check-pii-shapes/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: check-pii-shapes on the PR diff' .github/workflows/check-handoff.yml && grep -qE 'bash bin/check-pii-shapes\.sh --base' .github/workflows/check-handoff.yml
- [ ] **AC18** The four scope limits are stated verbatim, each as one physical
  line, in both `docs/pii-controls.md` and `docs/pii-controls.ja.md`, under the
  canonical heading of each file. The exact lines are fixed in
  "Canonical document lines" below.
  - check: grep -qxF '## What this gate does not cover' docs/pii-controls.md && grep -qxF '- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.' docs/pii-controls.md && grep -qxF '- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.' docs/pii-controls.md && grep -qxF '- Semantic sensitivity — a design decision or a context from which a reader can infer a business relationship — is not a PII shape and is not covered.' docs/pii-controls.md && grep -qxF '- Image content is not inspected; metadata only, if anything.' docs/pii-controls.md
- [ ] **AC19** The Japanese counterpart carries the same four limits, each as one
  physical line, under its own canonical heading.
  - check: grep -qxF '## このゲートが扱わないもの' docs/pii-controls.ja.md && grep -qxF '- 固有名詞（顧客名・内部ホスト名・プロジェクトコード）は形状では一致させられないため、このゲートの対象外である。' docs/pii-controls.ja.md && grep -qxF '- 固有名詞に一致させるためのパターン自体が機密であるため、この公開リポジトリには置けない。リポジトリ外のオペレータ手元のチェックに置く。' docs/pii-controls.ja.md && grep -qxF '- 意味的な機微さ（設計判断や文脈から読み手が業務上の関係を推測できてしまう類）は PII の形状ではなく、対象外である。' docs/pii-controls.ja.md && grep -qxF '- 画像の内容は検査しない。検査するとしてもメタデータのみである。' docs/pii-controls.ja.md
- [ ] **AC20** No wording that implies complete coverage. Positive half: the
  canonical "shapes only" sentence is present as one physical line in each doc,
  and so is the categorical `--all` statement. Negative half: none of the
  badge-shaped claim compounds `PII-gated`, `PII-free`, `PII-clean`, `PII-safe`
  appears in the docs pair or in either README (each file is proved readable
  first, so an unreadable file cannot masquerade as "no match").
  - check: grep -qxF 'This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.' docs/pii-controls.md && grep -qxF 'このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。' docs/pii-controls.ja.md && grep -qxF '- The deliberately PII-shaped adversarial fixtures that already live under tests/ are known findings of --all; --all is an audit flag and is deliberately not a required CI check.' docs/pii-controls.md && grep -qF 'PII' docs/pii-controls.md && grep -qF 'PII' docs/pii-controls.ja.md && grep -qF 'shell-team' README.md && grep -qF 'shell-team' README.ja.md && ! grep -F -e 'PII-gated' -e 'PII-free' -e 'PII-clean' -e 'PII-safe' docs/pii-controls.md docs/pii-controls.ja.md README.md README.ja.md
- [ ] **AC21** Every stderr write in the new script — outside comment lines —
  carries a `|| true` guard on the same physical line, so a write failure on a
  path whose contract exit is 2 cannot be downgraded to errexit's own fallback of
  1. The check counts non-comment lines only, so prose that merely mentions a
  redirection does not trip it, and it fails if there are no stderr writes at all.
  - check: test "$(grep -vE '^[[:space:]]*#' bin/check-pii-shapes.sh | grep -c '>&2')" -gt 0 && test "$(grep -vE '^[[:space:]]*#' bin/check-pii-shapes.sh | grep '>&2' | grep -vc '|| true')" -eq 0
- [ ] **AC22** Operating paths are resolved through `bin/team-paths.sh`, never
  hardcoded: no non-comment line of the new script contains a literal
  `.shell-team/` or `tasks/todo` path (comments may discuss either layout).
  - check: test "$(grep -vcE '^[[:space:]]*#' bin/check-pii-shapes.sh)" -gt 0 && test "$(grep -vE '^[[:space:]]*#' bin/check-pii-shapes.sh | grep -cE '\.shell-team/|tasks/todo')" -eq 0
- [ ] **AC23** A decision provenance file for this task exists and is
  schema-conformant.
  - check: bash bin/check-provenance.sh .shell-team/provenance/T-111.md
- [ ] **AC24** Nothing outside this task's own surface is disturbed: the whole
  existing suite set still passes, the prompt blocks are still in sync, and
  `bin/check-handoff.sh`, `bin/check-acs.sh`, `.gitignore` and
  `.shell-team/.gitignore` are byte-unchanged against `<base>`.
  - check: bash bin/check-prompt-sync.sh && bash tests/rollup-track/run.sh && bash tests/check-acs/run.sh && git diff --quiet develop -- bin/check-handoff.sh bin/check-acs.sh .gitignore .shell-team/.gitignore

## Input space

**Reachable input classes** — what a real diff in this repository can contain,
and what the checker must therefore handle correctly:

1. Added markdown prose lines, in English and in Japanese, including full-width
   punctuation and em-dashes (`docs/`, `.shell-team/specs/`, `agents/`).
2. Added bash source lines, including regex literals that themselves contain
   character classes and the pattern text the checker matches on.
3. Added YAML (`.github/workflows/`, `templates/*.yaml`) and JSONL fixture lines.
4. Placeholder identity forms written deliberately in documentation:
   `/Users/<name>/`, `/home/<name>/`, `C:\Users\<name>\`,
   `<id>+<login>@users.noreply.github.com`, plain `noreply@github.com`.
5. Real PII shapes: a home-directory absolute path with a real name segment, a
   mailbox-shaped string at a real domain, a PEM private-key header, a
   credential-token prefix followed by a key body.
6. Short lookalikes that must not fire — this repo's own `task-0NN` labels and
   truncated token prefixes (the class `tests/rollup-track/run.sh` already
   regression-guards).
7. Diff mechanics: a diff with no added lines at all; a diff whose only change
   is a deletion; a binary file whose diff carries no added lines; CRLF line
   endings; a file added and then removed within the same range.
8. Base-ref conditions: a resolvable base ref, a base ref that only exists as a
   remote-tracking ref, and an unresolvable base ref (must exit 2).

**Out-of-scope synthetic extremes** — declined deliberately, so a reviewer or QA
finding built on one of these is not grounds for rework:

1. Deliberately obfuscated or encoded PII: base64, percent-encoding, homoglyphs,
   zero-width characters splitting a shape, a shape spread across two lines.
   A shape checker cannot see these and this spec does not claim to.
2. Named entities of any kind (see Non-goals) — including a synthetic "customer
   name" fixture, which cannot be added here at all because the pattern that
   would catch it is the sensitive data.
3. Binary and image payloads, and any metadata inside them.
4. Adversarially large inputs as a performance attack: an ever-larger diff, an
   ever-longer single line, an ever-deeper directory tree. The checker is a
   line-oriented `grep`-class scan over `git diff` output; sizing beyond what
   this repository's own history produces is not protected.
5. A hostile author who edits the checker in the same commit to disable it. Like
   `bin/check-acs.sh`'s TRUST BOUNDARY and `bin/check-intent.sh`'s ledger note,
   this is a discipline aid for trusted, reviewed artifacts, not a security
   boundary against the person writing the commit; PR review is that layer.

<!-- END intent-block: T-111 -->

## Resolved design decisions

### DP-1 — the self-reference problem: runtime-generated fixtures (option (a))

The checker's own source and its fixtures contain PII-shaped bytes, and the
checker runs on the very PR that adds them. Three options were on the table.

| Option | How it removes the conflict | Why not / why yes |
|---|---|---|
| (a) Generate every fixture at runtime under `mktemp`, assembling the shapes from fragments | No PII-shaped byte ever enters the tree, so there is nothing to exempt | **Chosen.** No hole in the gate; `--all` stays clean over the new files; the self-application AC (AC15) passes by construction rather than by exemption. Cost is readability, paid down by a commented generator (AC12) |
| (b) A narrow per-file path allowlist (the checker plus its fixtures dir) | Named paths are skipped | Rejected: an allowlisted path is a place to hide PII, and it is exactly the file a reviewer is least likely to re-read. Rejected *behaviorally*, not just in prose — AC13 requires a finding to still be reported when the carrying path is the checker itself |
| (c) Inline allow markers | Review-visible per occurrence | Rejected: needs its own abuse control (who may add a marker, how many, are they audited), which is a second mechanism to build and lock for no gain over (a) |

Two consequences make (a) sufficient rather than merely tidy:

- **Placeholder forms must not match** (AC9). Documentation and specs need to
  *name* the shapes. Because the name segment of the home-path patterns is a
  character class that excludes `<` and `>`, the documented forms
  `/Users/<name>/` and `C:\Users\<name>\` are not matches, and because both
  GitHub noreply shapes are non-findings, the identity forms this project must
  discuss in prose are not matches either. This is what lets AC15 hold over the
  docs pair and over these specs.
- **Documents name shapes by pattern id, never by transcribing a match.** Prose
  in this work refers to `private-key` and `token` by their pattern ids and
  describes them in words; it never reproduces the literal header or prefix. A
  document that transcribed a matching literal would red its own gate, and the
  correct fix would be to stop transcribing it, not to add an exemption.

### DP-2 — the diff-scoped unit and base resolution

- **Scanned unit**: the added lines of `git diff <point>` — lines beginning with
  a single `+`, excluding the `+++` file header. Deletions, context lines and
  binary-file diffs carry no added lines and are therefore clean.
- **Comparison point**: `git merge-base <base> HEAD` when that resolves, else
  `<base>` itself. This mirrors `bin/check-board-headings.sh`'s documented
  base-resolution behavior and stays stable across squash, rebase and
  multi-commit PRs.
- **Default base when `--base` is omitted**: the first of `$PII_CHECK_BASE`,
  `origin/$GITHUB_BASE_REF` (only when `GITHUB_BASE_REF` is non-empty),
  `origin/develop`, `develop` that resolves; if none resolves, exit 2. Unlike
  `check-board-headings.sh`'s deliberately lenient default chain, this one is
  fail-closed at the end, per the exit-code convention handed down for this
  work: a checker that cannot determine what the change *is* must not report it
  clean. CI passes `--base` explicitly anyway (AC17).
- **Known limitation, to be documented**: untracked files are not in a diff and
  are therefore not scanned in diff mode; `--all` is the mode that sees them.

### DP-3 — why the "no completeness wording" check is split into presence + a narrow absence lock

A broad grep for completeness-implying wording collides with the documents' own
negated statements — a doc that must say "this is not comprehensive" contains
"comprehensive", and patching around that is unbounded. So the mechanical check
is (i) an **equality lock** on the canonical sentences that carry the meaning
(`grep -qxF`, full-line exact, the same shape `check-retro.sh` uses for the
retro headings) and (ii) an **absence lock** restricted to badge-shaped
affirmative compounds (`PII-gated`, `PII-free`, `PII-clean`, `PII-safe`) that
have no legitimate negated use. Both halves are in AC20.

### Canonical document lines

Each must be exactly one physical line (the checks are full-line exact
matches). `docs/pii-controls.md`:

```text
## What this gate does not cover
- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.
- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.
- Semantic sensitivity — a design decision or a context from which a reader can infer a business relationship — is not a PII shape and is not covered.
- Image content is not inspected; metadata only, if anything.
This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.
- The deliberately PII-shaped adversarial fixtures that already live under tests/ are known findings of --all; --all is an audit flag and is deliberately not a required CI check.
```

`docs/pii-controls.ja.md`:

```text
## このゲートが扱わないもの
- 固有名詞（顧客名・内部ホスト名・プロジェクトコード）は形状では一致させられないため、このゲートの対象外である。
- 固有名詞に一致させるためのパターン自体が機密であるため、この公開リポジトリには置けない。リポジトリ外のオペレータ手元のチェックに置く。
- 意味的な機微さ（設計判断や文脈から読み手が業務上の関係を推測できてしまう類）は PII の形状ではなく、対象外である。
- 画像の内容は検査しない。検査するとしてもメタデータのみである。
このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。
```

### Canonical suite assertion labels

`tests/check-pii-shapes/run.sh` must print or contain these labels verbatim —
they are the anchors QA greps (AC2, AC4-AC14):

```text
exit-code contract
unresolvable base ref
POS/NEG pair: home-path
POS/NEG pair: home-path-win
POS/NEG pair: email-nonnoreply
negative: both noreply identity shapes
POS/NEG pair: private-key
POS/NEG pair: token
negative: short lookalike must not fire
placeholder forms are not findings
mutation: pattern is load-bearing
meta: neutralised positive fixture makes the assertion FAIL
no-allowlist: finding reported even for the checker own path
no-leak: finding output never echoes the matched text
```

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| Diff-scoped, not whole-tree | AC15 (self-application over a real diff), DP-2 fixes the unit |
| Fail-closed; cannot pass because it could not evaluate | AC2 |
| Exit codes 0/1/2 per `check-provenance.sh` | AC2, AC3 |
| Patterns limited to generic publishable shapes | AC4-AC8 (the five ids are the whole set) |
| Positive/negative fixture pair per pattern, asserting which pattern fired | AC4-AC8 |
| Vacuity guard, detector side | AC10 |
| Vacuity guard, fixture side (meta-assertion) | AC11 |
| No PII-shaped byte enters the tree (DP-1 option (a)) | AC12 |
| Options (b) and (c) rejected | AC13 (behavioral lock, not prose alone) |
| Findings must not leak the matched text into public CI logs | AC14 |
| Self-application on this PR's own diff | AC15 |
| `--all` exists, is an audit flag, never a required CI check | AC16, and the categorical statement in AC20 |
| CI wiring (shellcheck list, suite step, diff step) | AC17 |
| Four scope limits stated in `docs/` | AC18 (en), AC19 (ja) |
| No wording implying complete coverage | AC20 (presence + narrow absence, per DP-3) |
| `|| true`-guarded stderr writes | AC21 |
| Never hardcode operating paths | AC22 |
| Provenance file required | AC23 |
| Placeholder forms are a permanent false-positive regression case | AC9 |
| Untracked files are not scanned in diff mode | info-only (not promoted to AC) — a documented consequence of DP-2's unit, verified by reading the docs, and covering it with an AC would require asserting a *limitation* rather than a behavior |
| Prose names shapes by pattern id, never by transcribing a match | info-only (not promoted to AC) — enforced indirectly and sufficiently by AC15: a transcribed literal would red the self-application check |
| Not UI work; no design note | info-only (not promoted to AC) — routing decision from tech-lead, no artifact to verify |
| No AI-driven CI workflow | info-only (not promoted to AC) — a repo-wide invariant in `CLAUDE.md`, not introduced by this task; AC17 pins the only workflow edits made |

## Assumptions

- shellcheck is available to QA at the version CI pins (0.11.0). AC1 fails
  loudly rather than skipping if it is absent — that is deliberate.
- The adversarial fixtures already in `tests/rollup-track/fixtures/` carry a
  mailbox shape and a home-path shape that these patterns match, so AC16's
  `exit 1` expectation holds. `tests/rollup-track/run.sh` asserts exactly those
  two shapes are present in that fixture's derived summary, which is the
  evidence for this assumption; if a pattern turns out narrower than that
  fixture's bytes, the pattern is what needs to change.
- `.shell-team/runs/` is ignored by `.shell-team/.gitignore`, so run telemetry
  never enters the diff AC15 scans. Verified by reading that file.
- CI's `actions/checkout` uses `fetch-depth: 0`, so `origin/$GITHUB_BASE_REF`
  resolves in the pull_request context. Unverified for the push-to-`develop`
  event, where the diff is expected to be empty or trivially clean.

## Open questions

None blocking. DP-1, DP-2 and DP-3 are decided here; the engineer does not need
to reopen them.

## Notes for engineer

- Prior art to imitate closely, in this order: `bin/check-provenance.sh` for
  the fail-closed skeleton, the `die` / `fail_usage` / `fail_structural`
  classification tokens on stderr, the symlink-resolution bootstrap and the
  argument-type guards; `tests/rollup-track/run.sh` for adversarial fixtures
  proven one at a time, the false-positive regression case, and the
  `control: ... has teeth` idiom AC11 generalizes; `bin/check-board-headings.sh`
  for base-ref resolution.
- `bin/` is on `PATH` when the plugin is loaded via `claude --plugin-dir ./`;
  read `.shell-team/test-recipe.md` before running suites and append any
  procedure you establish.
- Before hand-off, run the mutation self-check on your own detector, not just
  the fixtures: break each pattern, watch the suite go red, restore it. AC10 is
  the committed form of that, but do it by hand once first — a lock that has
  never been observed failing has not been shown to work.
- Ask yourself the detector-blind-spot questions explicitly: does the scan read
  only the first hunk; does it treat a `+++` header as an added line; does it
  fold CRLF; does it silently skip a file it cannot read (it must not).
- Files expected to change: `bin/check-pii-shapes.sh` (new),
  `tests/check-pii-shapes/run.sh` (new), `docs/pii-controls.md` (new),
  `docs/pii-controls.ja.md` (new), `.github/workflows/check-handoff.yml` (the
  shellcheck argument list plus two new steps),
  `.shell-team/provenance/T-111.md` (new), `.shell-team/todo.md` (status flag).
  T-112 edits the same shellcheck argument line, which is why these two tasks
  are sequential.
- There is deliberately **no whole-diff scope-lock AC** here: all three tasks
  share one branch, so a file-set allow-list authored now would go stale the
  moment T-112 lands. AC24 pins the specific files that must stay untouched
  instead.
