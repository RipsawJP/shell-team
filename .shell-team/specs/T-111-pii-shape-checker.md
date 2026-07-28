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
before pushing. The check is change-scoped — it reads the committed content of
each path the change touches, resolved against a base ref, rather than the whole
tree — fail-closed (it can never pass because it failed to evaluate its input),
and it reports *which* shape fired and *where* without echoing the matched text
into a public CI log. Because it never parses a diff rendering, its verdict
cannot be changed by a git configuration setting or by content that happens to
resemble diff syntax. It is an **auxiliary layer over generic publishable
shapes**, not a security boundary and not a complete PII control: its pattern
catalogue is deliberately small, its exclusions are chosen to keep it quiet
enough to be trusted, and every limit it accepts is written down where a reader
will find it. Its own test suite proves the detector actually fires, one shape at
a time, and that each exclusion is load-bearing rather than swallowing the rule.
A `docs/pii-controls.md` / `docs/pii-controls.ja.md` pair states plainly, and in
words a reader cannot mistake, that this gate sees shapes only, what it therefore
does not cover, and which reachable inputs it knowingly leaves uncovered.

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
  with the reported id asserted. Its exclusions, and the fixtures each one needs:
  - **The noreply exclusion is a domain match, not an address shape** (DP-9): an
    address whose domain is exactly the GitHub noreply domain, matched
    **end-anchored**, is not a finding, and neither is the plain web-flow
    `noreply@github.com` address. Negative fixtures: a realistic numeric-id and
    login form; the older login-only form; and — named explicitly in its label so
    a later reader knows why it exists — **a printf format placeholder as the
    local part** at that domain, the shape every suite that assembles an identity
    at runtime necessarily carries.
  - **The reserved-domain exclusion** (DP-7): one negative fixture per form — the
    reserved second-level documentation names and each reserved top-level name.
  - **Anti-swallow positives**, so no exclusion can quietly swallow the rule: a
    mailbox shape at an ordinary domain still fires, **and** a suffix-confusable
    domain that merely ends with the noreply domain as a substring still fires,
    with the reported id asserted as `email-nonnoreply` in both cases. The
    suffix-confusable fixture's own domain must **not** be a reserved one, or the
    reserved-domain exclusion would make it clean for the wrong reason and the
    fixture would prove nothing about anchoring.
  - **Precondition**, asserted by the suite rather than assumed: every negative
    fixture provably reaches the email candidate enumeration, so an exclusion is
    what makes it clean rather than the line never matching at all. The
    angle-bracketed documentation placeholder does **not** satisfy this (the
    brackets are outside the local-part class), which is why it belongs to AC9 and
    can never stand in for a negative fixture here.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'POS/NEG pair: email-nonnoreply' tests/check-pii-shapes/run.sh && grep -qF 'negative: the noreply domain, end-anchored, whatever the local part is' tests/check-pii-shapes/run.sh && grep -qF 'negative: a printf format placeholder local part at the noreply domain (runtime-assembly helpers carry one)' tests/check-pii-shapes/run.sh && grep -qF 'negative: one fixture per reserved-domain form' tests/check-pii-shapes/run.sh && grep -qF 'positive: an ordinary domain still fires (anti-swallow)' tests/check-pii-shapes/run.sh && grep -qF 'positive: a suffix-confusable domain at a non-reserved name still fires (anti-swallow)' tests/check-pii-shapes/run.sh && grep -qF 'precondition: each negative fixture reaches the email candidate enumeration' tests/check-pii-shapes/run.sh
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
- [ ] **AC10** Vacuity guard, detector side: for **every** decision rule the
  suite produces a copy of the checker with that one rule neutralised, runs the
  fixture that rule governs against the copy, and requires the copy's verdict to
  flip. The rule set is **nine** rules — the five patterns, plus each of the four
  exclusions individually: the **domain-anchored noreply rule** (DP-9, which
  replaces the former local-part-shape rule), the plain web-flow address, the
  reserved-domain rule (DP-7), and the home-path boundary rule (DP-5). For a
  pattern, neutralising it must make its positive fixture go unreported; for an
  exclusion, neutralising it must make that exclusion's own negative fixture
  become a finding — the only way to prove the branch is reached and load-bearing
  rather than dead code. Neutralising the domain-anchored rule must flip **all**
  of its negatives, the format-placeholder fixture included.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'mutation: pattern is load-bearing' tests/check-pii-shapes/run.sh && grep -qF 'mutation: each exclusion is load-bearing' tests/check-pii-shapes/run.sh
- [ ] **AC11** Vacuity guard, fixture side (meta-assertion): for **every**
  pattern the suite calls its own positive-assertion helper against a
  *neutralised* positive fixture in a subshell and requires that call to FAIL.
  Neutralising a positive fixture therefore makes the suite fail, so a fixture
  that silently stopped carrying its shape cannot pass. This mirrors the
  `control: hostile excludesFile has teeth` assertion in
  `tests/rollup-track/run.sh`.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'meta: neutralised positive fixture makes the assertion FAIL' tests/check-pii-shapes/run.sh
- [ ] **AC12** No PII-shaped byte enters the tree, and no temp artifact outlives
  the run: every fixture is assembled at runtime from fragments under `mktemp`,
  `tests/check-pii-shapes/` contains no fixtures directory and no committed
  fixture file, and **every throwaway git repository the suite creates lives
  inside the single work directory the `EXIT` trap removes** — a successful run
  leaves nothing behind under `$TMPDIR`.
  - check: test ! -e tests/check-pii-shapes/fixtures && test ! -L tests/check-pii-shapes/fixtures && test "$(find tests/check-pii-shapes -type f | wc -l | tr -d ' ')" = "1" && grep -qF 'mktemp' tests/check-pii-shapes/run.sh && grep -qF 'temp hygiene: every throwaway repo is created inside the trap-cleaned work dir' tests/check-pii-shapes/run.sh
- [ ] **AC13** The known-shapes path list (DP-8) is narrow, visible and locked,
  and it is **not** an exemption for this task's own files. A shape is still
  reported when the path carrying it is `bin/check-pii-shapes.sh` itself or a file
  under `tests/check-pii-shapes/` — those stay runtime-generated per DP-1 and are
  never listed. The list itself: per-file paths only (no directory entry, no glob,
  no pattern), living in the checker source so it appears in every pull-request
  diff, and its **exact contents asserted by the suite**, so it cannot grow
  without that growth showing up as a test edit in the same diff. There is no
  inline allow marker anywhere in the checker.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'no-allowlist: finding reported even for the checker own path' tests/check-pii-shapes/run.sh && grep -qF 'known-shapes list: exact contents asserted, per-file only, no directory or glob entry' tests/check-pii-shapes/run.sh
- [ ] **AC14** A finding never echoes the matched text: the report names the
  pattern id and the path (and a line number when one is available) only. The
  suite proves this by asserting the checker output does not contain the
  distinctive positive-fixture string it just caught.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'no-leak: finding output never echoes the matched text' tests/check-pii-shapes/run.sh
- [ ] **AC15** Self-application: the checker, run change-scoped against `<base>`,
  exits 0 on this branch — the branch that adds the checker, its suite, the docs
  pair, these specs, the provenance file and the review record. Because the unit
  is the full committed content of every touched path (DP-4), this covers those
  files entirely, not only their new lines. Where one of this project's own process
  artifacts discusses a shape, it must use the placeholder form of AC9; a
  real-looking name segment in a spec, review record, provenance file or board
  note is fixed by rewriting it to the placeholder form, **never** by adding the
  path to the known-shapes list. That rule is what keeps the gate un-blinded in
  `.shell-team/reviews/`, which is exactly where raw cross-provider output lands.
  - check: bash bin/check-pii-shapes.sh --base develop
- [ ] **AC16** `--all` exists as a full-tree audit mode, is fail-closed the same
  way, and **exits 0 on this tree**: with the reserved-domain rule (DP-7), the
  boundary rule (DP-5), the placeholder forms (AC9) and the short known-shapes
  list (DP-8), no tracked path carries an unaccounted shape. That clean audit is
  the honest-bookkeeping invariant this design pays for — if a shape appears
  anywhere in the tree, this criterion goes red. It stays an audit flag and is
  invoked **nowhere** in the CI workflow: promoting it to a required check is out
  of scope (Non-goals), because the audit reads the working tree and untracked
  files, which is a different question from what a change introduces.
  - check: bash bin/check-pii-shapes.sh --all && grep -qF 'check-pii-shapes' .github/workflows/check-handoff.yml && ! grep -qF -- '--all' .github/workflows/check-handoff.yml
- [ ] **AC17** CI wiring: the workflow's single shellcheck argument list gains
  `bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh`, a
  `Run check-pii-shapes fixture suite` step runs the suite, and a separate
  required step runs the checker diff-scoped with an explicit `--base`.
  - check: grep -qF 'bin/check-pii-shapes.sh tests/check-pii-shapes/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: Run check-pii-shapes fixture suite' .github/workflows/check-handoff.yml && grep -qF 'run: bash tests/check-pii-shapes/run.sh' .github/workflows/check-handoff.yml && grep -qF 'name: check-pii-shapes on the PR diff' .github/workflows/check-handoff.yml && grep -qE 'bash bin/check-pii-shapes\.sh --base' .github/workflows/check-handoff.yml
- [ ] **AC18** Every limit this gate accepts is stated verbatim in
  `docs/pii-controls.md`, each as one physical line under the canonical heading:
  the **four** scope limits issue #6 mandates, and the **six** limitations this
  design declares (content-only inspection, the accepted false-positive classes
  around URLs and log prefixes, the conservative ASCII name segment, the
  undeliverable-domain exclusion, the committed-content reading point, and the
  known-shapes list). Each is a whole-line
  exact match, so other tasks can add their own lines to this file freely —
  T-112 writes two — because nothing here constrains the file's overall shape or
  its line count. Exact text in "Canonical document lines" below.
  - check: grep -qxF '## What this gate does not cover' docs/pii-controls.md && grep -qxF -- '- A PII shape in a filename or a path is not inspected; this gate reads file content only.' docs/pii-controls.md && grep -qxF -- '- Some URL-adjacent and log-prefixed forms may be reported even though they carry no personal data: a file scheme URL, a path wrapped in markdown link syntax, and a path following an IPv6 authority. That noise is accepted deliberately, because a one-character lookbehind cannot tell those apart from a real path in prose; the resolution is to write the placeholder form, never to widen the suppression.' docs/pii-controls.md && grep -qxF -- '- The home-path shapes match a conservative ASCII name segment only; a name written in non-ASCII characters, and unusual case spellings of the Windows form, are not covered.' docs/pii-controls.md && grep -qxF -- '- A mailbox shape is not reported when its domain cannot hold a deliverable mailbox: a domain reserved for documentation and testing, or the GitHub noreply domain used for pseudonymous identities. The excluded domains are listed in the checker source.' docs/pii-controls.md && grep -qxF -- '- The gate reads the committed content of each path the change touches, resolved against the base ref; a change that exists only in the working tree is not scanned, and --all is the mode that reads the working tree.' docs/pii-controls.md && grep -qxF -- '- A short list of paths that deliberately carry shapes, as fixtures another guard needs, is excluded by name; the list lives in the checker source and its exact contents are asserted by the test suite.' docs/pii-controls.md && grep -qxF -- '- Named entities — customer names, internal hostnames, project codes — cannot be matched by shape and are not covered by this gate.' docs/pii-controls.md && grep -qxF -- '- The patterns that would match named entities cannot live in this public repository, because the patterns themselves are the sensitive data; they belong in an operator-local check outside the repo.' docs/pii-controls.md && grep -qxF -- '- Semantic sensitivity — a design decision or a context from which a reader can infer a business relationship — is not a PII shape and is not covered.' docs/pii-controls.md && grep -qxF -- '- Image content is not inspected; metadata only, if anything.' docs/pii-controls.md
- [ ] **AC19** The Japanese counterpart carries the same ten lines — the four
  mandated scope limits and the six declared limitations — each as one physical
  line under its own canonical heading, with the same whole-line-exact,
  shape-agnostic matching. Its lines stay consistent with the English side: the
  Japanese file never claimed the stale `--all` behaviour AC20 corrects, and the
  accepted-noise line below replaces its URL-silence line for the same reason.
  - check: grep -qxF '## このゲートが扱わないもの' docs/pii-controls.ja.md && grep -qxF -- '- ファイル名やパス自体に含まれる PII 形状は検査しない。このゲートはファイルの内容だけを読む。' docs/pii-controls.ja.md && grep -qxF -- '- URL に隣接する形やログ接頭辞の付いた形は、個人データを含まないのに報告されることがある。file スキームの URL、markdown のリンク記法で囲まれたパス、IPv6 の authority に続くパスが該当する。1 文字の後読みではこれらを散文中の実際のパスと区別できないため、この雑音は意図して受け入れる。解消はプレースホルダ形で書くことであり、抑制範囲を広げることではない。' docs/pii-controls.ja.md && grep -qxF -- '- home-path の形状は ASCII の保守的な名前セグメントにだけ一致する。非 ASCII の名前や Windows 形式の異なる大小文字表記は対象外である。' docs/pii-controls.ja.md && grep -qxF -- '- 配送可能なメールボックスが存在し得ないドメインのメールアドレス形状は報告しない。ドキュメントおよびテスト用に予約されたドメインと、GitHub の擬名 identity 用 noreply ドメインが該当する。除外ドメインの一覧はチェッカーのソースにある。' docs/pii-controls.ja.md && grep -qxF -- '- このゲートは変更が触れた各パスのコミット済み内容を、base ref に対して解決して読む。ワーキングツリーにだけある変更は検査せず、ワーキングツリーを読むのは --all のモードである。' docs/pii-controls.ja.md && grep -qxF -- '- 別のガードが必要とする fixture として意図的に形状を持つパスの短い一覧を、名前で除外する。一覧はチェッカーのソースにあり、その正確な内容はテストスイートが検証する。' docs/pii-controls.ja.md && grep -qxF -- '- 固有名詞（顧客名・内部ホスト名・プロジェクトコード）は形状では一致させられないため、このゲートの対象外である。' docs/pii-controls.ja.md && grep -qxF -- '- 固有名詞に一致させるためのパターン自体が機密であるため、この公開リポジトリには置けない。リポジトリ外のオペレータ手元のチェックに置く。' docs/pii-controls.ja.md && grep -qxF -- '- 意味的な機微さ（設計判断や文脈から読み手が業務上の関係を推測できてしまう類）は PII の形状ではなく、対象外である。' docs/pii-controls.ja.md && grep -qxF -- '- 画像の内容は検査しない。検査するとしてもメタデータのみである。' docs/pii-controls.ja.md
- [ ] **AC20** No wording that implies complete coverage. Positive half: the
  canonical "shapes only" sentence is present as one physical line in each doc,
  and so is the categorical `--all` statement — which states the **shipped**
  invariant, that the deliberate shape-bearing fixtures are carried by the
  test-locked known-shapes list and `--all` therefore exits 0 on this tree. (The
  pre-v3 wording claimed the opposite, that those fixtures are known *findings*
  of `--all`; it contradicted the corrected prose beside it and, being matched
  whole-line-exact here, could only be fixed in the recorded intent.) Negative
  half: none of the badge-shaped claim compounds `PII-gated`, `PII-free`,
  `PII-clean`, `PII-safe` appears in the docs pair or in either README (each file
  is proved readable first, so an unreadable file cannot masquerade as "no
  match").
  - check: grep -qxF 'This gate sees shapes only. It is not a complete PII control, and passing it is not evidence that a change is free of PII.' docs/pii-controls.md && grep -qxF 'このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。' docs/pii-controls.ja.md && grep -qxF -- '- The deliberate shape-bearing fixtures under tests/ are carried by the test-locked known-shapes list, so --all exits 0 on this tree; --all remains an audit flag and is deliberately not a required CI check.' docs/pii-controls.md && grep -qF 'PII' docs/pii-controls.md && grep -qF 'PII' docs/pii-controls.ja.md && grep -qF 'shell-team' README.md && grep -qF 'shell-team' README.ja.md && ! grep -F -e 'PII-gated' -e 'PII-free' -e 'PII-clean' -e 'PII-safe' docs/pii-controls.md docs/pii-controls.ja.md README.md README.ja.md
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
- [ ] **AC25** Mechanism (DP-4): the checker never parses git's textual diff
  rendering. It enumerates the changed paths from NUL-separated git output with
  rename detection disabled, then reads each path's committed content through
  `git cat-file`. It never classifies a line by a leading `+` or `-`, never
  recognises a `+++` / `---` / `@@` header, and never interprets a
  `Binary files ... differ` line — those three anchors do not appear in its code
  at all, which is what makes the whole rendering class (colour, external diff,
  textconv, a `-diff` gitattribute) structurally unable to reach it. Every `git`
  invocation still pins its rendering, which is free insurance rather than a
  load-bearing defence.
  - check: test "$(grep -vcE '^[[:space:]]*#' bin/check-pii-shapes.sh)" -gt 0 && grep -qF 'cat-file' bin/check-pii-shapes.sh && grep -qF -- '--no-color' bin/check-pii-shapes.sh && test "$(grep -vE '^[[:space:]]*#' bin/check-pii-shapes.sh | grep -cF -e '+++' -e '@@' -e 'Binary files')" -eq 0
- [ ] **AC26** Every candidate on a line is judged, never only the leftmost. The
  email rule enumerates all candidates on a line and reports a finding if any
  candidate survives the exclusions. Fixtures: one line carrying an allowed
  noreply address **and** a mailbox shape at an ordinary domain is a finding with
  id `email-nonnoreply`; a line carrying only excluded forms is clean.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'all candidates per line: an excluded address on the same line never masks a real mailbox shape' tests/check-pii-shapes/run.sh
- [ ] **AC27** Text or binary is decided by the presence of a NUL byte — git's
  own convention — never by a printable-character heuristic. A UTF-8 file of
  Japanese prose that also carries a home-path shape is scanned and reported in
  **both** modes. A blob containing a NUL byte is not scanned and the skip is
  announced on stderr, never silent. A path that cannot be read at all is exit 2,
  never a skip.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'text-vs-binary: NUL byte decides, Japanese prose is scanned, a skip is announced' tests/check-pii-shapes/run.sh
- [ ] **AC28** The boundary rule stays at its narrow form and the gate **prefers
  firing** (DP-5, DP-10). Suppression happens only when the character immediately
  before the leading `/` can continue a host name — an ASCII letter or digit, a
  dot, or a hyphen. That is exactly what closes the one measured, in-tree false
  positive: a bare documentation URL whose path carries a home-directory-looking
  segment. Its negative fixture is permanent, in the same class as AC9.
  Everything else fires. Two positive fixtures lock the direction, both
  mechanically reachable rather than contrived — the doubled-leading-slash form
  of a home path, which bash's own diagnostics emit, and a home path immediately
  preceded by `]`, which an xtrace prefix emits. Neither `/` nor `]` is a
  suppressing character, and no criterion here may be satisfied by widening the
  lookbehind: the accepted false-positive classes are declared in the documents
  (AC18 / AC19) instead.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF 'boundary: only a host-name character suppresses, so the bare documentation URL stays clean' tests/check-pii-shapes/run.sh && grep -qF 'positive: a doubled-leading-slash home path fires (fail-noisy, bash diagnostics emit this)' tests/check-pii-shapes/run.sh && grep -qF 'positive: a home path preceded by a bracket fires (fail-noisy, xtrace prefixes emit this)' tests/check-pii-shapes/run.sh
- [ ] **AC29** `--all` never silently skips: it enumerates from the repository top
  level regardless of the directory it was invoked from; it scans the target
  string git stores for a symbolic link instead of following the link; it reads a
  path whose name contains `=`, a space, or non-ASCII bytes; and any path it
  cannot read is exit 2. Fixtures cover all four.
  - check: bash tests/check-pii-shapes/run.sh && grep -qF -- '--all no-silent-skip: repo-root scope, symlink target, = in a filename, unreadable is exit 2' tests/check-pii-shapes/run.sh

## Input space

**Reachable input classes** — what the content of a changed path in this
repository can contain, and what the checker must therefore handle correctly:

1. Markdown prose, in English and in Japanese, including full-width punctuation
   and em-dashes (`docs/`, `.shell-team/`, `agents/`).
2. Bash source, including regex literals that themselves contain character
   classes and the pattern text the checker matches on.
3. YAML (`.github/workflows/`, `templates/*.yaml`) and JSONL fixture content.
4. Placeholder identity forms written deliberately in documentation:
   `/Users/<name>/`, `/home/<name>/`, `C:\Users\<name>\`,
   `<id>+<login>@users.noreply.github.com`, plain `noreply@github.com`.
5. Real PII shapes: a home-directory absolute path with a real name segment, a
   mailbox-shaped string at a real domain, a PEM private-key header, a
   credential-token prefix followed by a key body.
6. Short lookalikes that must not fire — this repo's own `task-0NN` labels and
   truncated token prefixes (the class `tests/rollup-track/run.sh` already
   regression-guards).
7. Change mechanics: a range with no changed path at all; a change whose only
   effect is a deletion; a newly added path; a renamed path; a path added and
   then removed within the same range; a final line with no trailing newline;
   CRLF line endings.
8. Base-ref conditions: a resolvable base ref, a base ref that only exists as a
   remote-tracking ref, and an unresolvable base ref (must exit 2).
9. **Content that resembles diff syntax**, because this repository documents diff
   handling in prose and in fixtures: a line beginning with `++ `, the
   `++ /dev/null` form, a line beginning with `@@`, and a line reading like a
   `Binary files ... differ` notice. Under DP-4 these are simply content; no
   criterion is spent proving it, because nothing in the checker parses them.
10. **Caller git configuration**, none of it adversarial: `color.ui=always`, an
    external-diff or textconv driver, and a `-diff` gitattribute set in an
    earlier unrelated commit to keep generated files out of diffs. Under DP-4
    none of these can reach the checker's judgment at all.
11. **Path shapes git tracks**: a symbolic link (whose content is the target
    string), a filename containing `=`, a space, or non-ASCII bytes, and a path
    reached while the tool is invoked from a subdirectory.
12. **Mailbox shapes at domains reserved for documentation and testing**, which
    every test suite, fixture, spec and document in this repository uses. This is
    the most common mailbox shape in the tree by a wide margin, not an edge case.
    In the same class: **a printf format string that assembles an address at
    runtime**, which every suite following this project's runtime-fixture
    discipline necessarily contains — observed in T-112's suite, not hypothesised
    (DP-9).
13. **A URL whose path contains a home-directory-looking segment**, written in
    ordinary English or Japanese documentation prose — in its bare form (measured
    in-tree), and in the file-scheme, markdown-wrapped and IPv6-authority variants.
14. **Machine-emitted path prefixes**: the doubled-leading-slash form bash's own
    diagnostics produce, and the bracket-adjacent form an xtrace / `PS4` prefix
    produces. Both are genuine paths and must fire (AC28); round 4 proved they are
    mechanically reachable rather than contrived.
15. **A NUL-bearing blob** (a genuine binary), and a path that cannot be read at
    all (must exit 2, never a skip).
16. **A tracked path that deliberately carries a shape** as an adversarial fixture
    for another guard — this repository has five such files today.

**Declared limitations — reachable, knowingly not covered.** These are stated
here and, in the reader's own words, in the documents (AC18 / AC19) rather than
silently left out, because a gate that reads as exhaustive when it is not is
worse than none:

1. Content that exists only in the working tree. The change-scoped mode reads
   committed content (DP-6); `--all` is the mode that reads the working tree.
2. A shape carried by a **filename or path** rather than by file content.
3. A home-path shape whose leading `/` directly follows a host-name character —
   the bare documentation URL of DP-5, the one measured false positive, and the
   only form the boundary rule suppresses.
4. A home-directory name segment written in **non-ASCII** characters, and unusual
   **case** spellings of the Windows form. The name class stays conservative ASCII
   on purpose: widening it under a full-content unit buys more false positives
   than findings, and a false positive in a required gate costs more than a miss
   in an auxiliary layer.
5. A mailbox shape at a **domain reserved for documentation and testing** (DP-7).
   Those names cannot route to a real mailbox, so the exclusion removes noise
   without creating a place to hide a real address — but it is an exclusion, and
   it is written down as one.
6. Any shape inside a path on the **known-shapes list** (DP-8). The list is
   per-file, short, in the checker source, and its exact contents are asserted by
   the suite, so what it hides is always visible in a diff.

**Accepted noise — reachable inputs that fire without carrying personal data.**
Declared, not suppressed, per DP-10, and stated in the documents (AC18 / AC19):

1. A home-path-looking segment in a **file scheme URL**, where the leading `/`
   follows another `/` rather than a host-name character.
2. A path wrapped in **markdown link syntax**, where the character before it is a
   bracket or parenthesis.
3. A path following an **IPv6 authority**, where the character before it is a
   closing bracket.

The resolution for all three is the placeholder discipline of AC9 at the authoring
site — write the placeholder form — never a wider suppression rule. Two shapes in
this same neighbourhood are **not** noise and must fire: the doubled-leading-slash
form bash's diagnostics emit and the bracket-adjacent form an xtrace prefix emits
(AC28), which is why the lookbehind cannot be widened to quiet the three above.

**Out-of-scope synthetic extremes** — declined deliberately, so a reviewer or QA
finding built on one of these is not grounds for rework:

1. Deliberately obfuscated or encoded PII: base64, percent-encoding, homoglyphs,
   zero-width characters splitting a shape, a shape spread across two lines.
   A shape checker cannot see these and this spec does not claim to.
2. Named entities of any kind (see Non-goals) — including a synthetic "customer
   name" fixture, which cannot be added here at all because the pattern that
   would catch it is the sensitive data.
3. Binary and image payloads, and any metadata inside them.
4. Adversarially large inputs as a performance attack: an ever-larger change set,
   an ever-longer single line, an ever-deeper directory tree. The checker is a
   line-oriented `grep`-class scan over blob content; sizing beyond what this
   repository's own history produces is not protected.
5. A hostile author who edits the checker in the same commit to disable it. Like
   `bin/check-acs.sh`'s TRUST BOUNDARY and `bin/check-intent.sh`'s ledger note,
   this is a discipline aid for trusted, reviewed artifacts, not a security
   boundary against the person writing the commit; PR review is that layer. This
   is the framing issue #6 sets: an auxiliary detection layer, with Layer 1
   (prevention — commit identity, ignore coverage, authoring rules) as the
   substantive half. A criterion that only makes sense against an adversary who
   controls the same commit is out of scope here by construction.
   Note the boundary move kept from v3: a `-diff` gitattribute set in an earlier,
   unrelated commit is **not** in this class — it needs no hostile intent and no
   timing, so it is a reachable input (class 10). Under DP-4 it simply cannot
   reach the checker, which is why v4 spends no criterion on it.
6. A path whose name contains a literal newline or a `\x1f` byte. NUL-separated
   enumeration removes the practical exposure; constructing one deliberately is
   an adversarial extreme.
7. Credential-prefix catalogue completeness. The five pattern ids are the whole
   set for this task; newer provider token prefixes are a fast-follow, and
   GitHub's own secret scanning remains the primary control for credentials.

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

### DP-2 — the diff-scoped unit and base resolution (superseded in part by DP-4)

- **Scanned unit** (v3, replacing v2's added-line parsing): the content newly
  present in each changed path, derived without reading any diff rendering — see
  DP-4 for the mechanism and DP-6 for which side of the comparison is read.
- **Comparison point**: `git merge-base <base> HEAD` when that resolves, else
  `<base>` itself. This mirrors `bin/check-board-headings.sh`'s documented
  base-resolution behavior and stays stable across squash, rebase and
  multi-commit PRs. Unchanged in v3.
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

### DP-4 — the mechanism: stop parsing git's diff rendering (v3, the premise change)

v2's checker parsed `git diff`'s textual output with awk. Cross-provider review
returned three blockers where the **required** check reported `exit 0 clean` on
content that needed no adversarial intent, and all three share that one root
cause: a diff rendering is a human-facing format whose framing is
configuration-dependent (binary framing via a `-diff` gitattribute, colour,
textconv, external diff) and whose escape syntax collides with content (a line
whose content starts with `++ ` renders as `+++ `; the `++ /dev/null` form
additionally reset the parser's file state, silently dropping every later added
line of that file). Two rounds of defects landed in that parser, and the
rework-history digest returned `same-class-repetition`. So the mechanism changes
rather than the parser being patched a third time.

| Option | Shape | Verdict |
|---|---|---|
| (A) Keep diff parsing, pin the rendering (`--no-color --no-ext-diff --no-textconv --text`), make the parser a real state machine (headers recognised only before a hunk; after `@@`, classify by first byte until the next `diff --git`) | Closes all three blockers and the colour major | **Rejected.** It is a legitimate engineering answer and would probably work, but it keeps a hand-rolled reader of a human-facing rendering — the path field retains an escape grammar (`core.quotepath`), every future git version or config knob is a fresh exposure, and the code that failed twice stays the code we depend on. This repo's own rule for invariants that need syntactic-state tracking is to prefer the grammar-aware tool over hand-rolled scanning |
| (B) Stop parsing diff text: enumerate changed paths from NUL-separated plumbing output, read content through `git cat-file` | Structurally immune to the whole rendering class — no framing, no colour, no escape grammar, and no state machine to get wrong | **Chosen**, in the narrowed form below |

**(B) as adopted — and simplified in v4 to the blunt unit.** v3 adopted (B) but
kept a base-blob comparison so the unit would remain "newly present content",
because touching a path that already carried a shape would otherwise red the
required check on content the author did not write. v4 removes that machinery:

- **Scan the full committed content of each changed path.** Enumerate changed
  paths from **NUL-separated** git output (so a filename containing `=`, a space,
  a non-ASCII byte, or a quoted character is never mis-split), with **rename
  detection disabled**, skip deletions, and read each surviving path through
  `git cat-file`. No base blob is read, no set difference is computed, and no
  `grep -f` empty-pattern-file portability trap exists to handle.
- **Why this is now safe**: the measurement in Assumptions found the "noise" that
  justified the comparison was **not pre-existing real PII — it was false
  positives**, plus five deliberate adversarial fixtures. False positives are
  fixed at the pattern level (DP-5, DP-7) and the fixtures are handled by name
  (DP-8). Suppressing them with a per-path content diff was solving a pattern
  problem with a unit mechanism, which is the inversion this rework exists to
  undo.
- Decide text vs binary by the **NUL byte**, git's own convention, replacing the
  `[:print:]` heuristic that misclassified ordinary UTF-8 Japanese prose as
  binary (AC27).
- Every `git` invocation still pins its rendering. Under (B) that can no longer
  change a verdict, so it is free insurance, not a defence to prove.

**Honest cost, recorded rather than hidden**: a change that touches a path which
already contains a shape now reds the required check even though the author did
not introduce the shape. There are exactly two legitimate responses, and adding
to the known-shapes list is only the second: **fix the pattern** if it was a
false positive, or **normalise the artifact** to the placeholder form of AC9 if it
is one of this project's own records. Listing a path is reserved for a file whose
shapes are deliberate fixtures for another guard (DP-8) — never for a document,
spec, review record or provenance file.

### Removed in v4, and why (kept so the reasoning is not re-litigated)

| Removed | Reason |
|---|---|
| v3 AC26, the three-condition hostile-git-config proof | Under DP-4 colour, external diff, textconv and a `-diff` gitattribute cannot reach the checker, so the criterion asserted the absence of a structurally absent property. AC25's code-level assertion (the three parsing anchors do not exist in the source) is the honest form of the same guarantee |
| v3 AC27, the diff-syntax-mimicry fixtures | Same class: with nothing parsing diff text, a line beginning with `++ ` is just a line. Kept as reachable input class 9 with an explicit note that no criterion is spent on it |
| v3 AC30, the charset / case expansion | Under a full-content unit, widening the name class buys more false positives than findings. Now a **declared limitation** in the documents (AC18 / AC19) and Input space limitation 4 — stated plainly rather than half-solved |
| v3 AC32, the comparison-point fixture | With full-content scanning the HEAD-versus-working-tree distinction collapses to one sentence (DP-6), and the documents state it (AC18 / AC19) |
| v3 AC33, the added-content unit and its six edge cases | The unit it tested no longer exists |

### DP-7 — the reserved-domain exclusion for mailbox shapes

Mailbox shapes at the second-level names reserved for documentation
(`example.com`, `example.org`, `example.net`) and at the reserved top-level names
(`.example`, `.invalid`, `.test`, `.localhost`) are not findings.

Two reasons, in order of weight. First, **those names cannot route to a real
mailbox** — they are reserved precisely so that documentation and tests can use
them — so excluding them removes false positives without creating a place to hide
a real address. That is what makes this an exclusion the gate can afford; an
exclusion justified only by "our fixtures happen to use it" would not be.
Second, empirically it covers **every** mailbox-shaped string in the tracked tree
today (Assumptions), and it structurally covers the dummy addresses every future
test, fixture and document will use — so the gate stays quiet enough to be
believed instead of being routinely overridden.

The risk of an exclusion is that it swallows the rule it modifies, so AC6
requires an **anti-swallow positive** (an ordinary domain still fires) alongside
one negative fixture per excluded form, and AC10 requires the exclusion itself to
be individually load-bearing under mutation.

### DP-8 — the known-shapes path list, and why it is not the allowlist DP-1 rejected

Five tracked files under `tests/rollup-track/fixtures/` deliberately carry shapes
so that another guard's suite can prove it fires. They are excluded by name.

DP-1 rejected a path allowlist on the grounds that an allowlisted path becomes a
place to hide PII, and that objection is answered rather than waved away:

- **Per-file only** — no directory entry, no glob, no pattern (AC13). Adding a
  file is a deliberate, visible act.
- **In the checker source**, so every entry appears in the pull-request diff of
  whoever adds it.
- **Contents asserted by the suite** (AC13), so the list cannot grow without the
  growth also appearing as a test edit in the same diff.
- **Scoped to fixtures for another guard.** It is not an exemption for this
  task's own files: `bin/check-pii-shapes.sh` and `tests/check-pii-shapes/`
  stay runtime-generated per DP-1 and are never listed, and AC13 asserts a shape
  in them is still reported.
- **Declared to the reader** as a limitation in both documents (AC18 / AC19).

The alternative — leaving those five files as permanent findings — is what forced
`--all` to be a mode nobody could run cleanly, and under a full-content unit it
would red the required check for anyone who touched them. Naming five files, in
public, with a test lock, is the more honest bookkeeping. It also buys the clean
audit invariant of AC16.

### DP-9 — the noreply exclusion is a domain match, not an address shape

**Found by dogfooding, after v4's draft.** T-112's implementation landed and its
own suite tripped this checker. The flagged line is the helper that assembles a
conformant noreply identity at runtime — precisely what T-112's own criteria
require, and precisely the discipline DP-1 mandates here. It contains no address
at all: it is a **printf format string**. But the format placeholder characters
sit inside the local-part class, so the string matched the email shape, while the
old exclusion demanded a local part shaped `<digits>+<login>`, which a format
placeholder is not. Verified directly rather than reasoned about: it matched the
email pattern, and the old exclusion did not exempt it.

Two things make this worth a design decision rather than a fixture:

1. **It punished the very discipline this spec mandates.** Any suite that
   assembles an identity from fragments — which is what keeps PII-shaped bytes out
   of the tree — necessarily carries a format string that looks like a
   non-noreply address. A rule that fines you for following the other rules is
   wrong at the rule level.
2. **Neither QA's mutation testing nor cross-provider review found it.** Both
   were looking at whether the detector fires; this is a class where it fires
   when it should not, on content generated by our own conventions.

Resolution: exclude on the **domain**, end-anchored — an address whose domain is
exactly the GitHub noreply domain — plus the plain web-flow address as its own
clause.

**Why this is more correct rather than a loosening.** That domain is GitHub's own
namespace for pseudonymous public identifiers; a real, deliverable mailbox cannot
exist there by construction. "The domain is that domain" is therefore a sound
exclusion criterion in its own right, whereas "the local part has shape
`<digits>+<login>`" was only ever an incidental proxy for it — and a leaky one:
it also rejected GitHub's older login-only noreply form, another false positive
nobody had hit yet. The rule gets shorter and covers more. End-anchoring is
load-bearing (a suffix-confusable or subdomain trick must still fire), and AC6
requires that anti-swallow positive to use a **non-reserved** domain so DP-7
cannot make it clean for the wrong reason.

**What this does not fix.** It is not a fix for the AC6 vacuity gap
cross-provider review reported. The angle-bracketed documentation placeholder
contains `<` and `>`, which are outside the local-part class, so it still never
reaches any exclusion branch; that gap is closed separately by requiring
realistic negative fixtures (AC6) and it stays closed on its own terms.

### DP-10 — asymmetric error costs: where a shape rule cannot separate, it fires

For a PII gate the two errors do not cost the same. A **false positive** costs a
moment of human review — read the finding, see it is a URL or a log prefix, write
the placeholder form instead. A **false negative** is a silent exposure in a
public repository, with no second chance and nobody looking. So where a shape rule
cannot cleanly separate the two populations, **the rule prefers firing**, and the
resulting noise is declared in the documents rather than suppressed in the code.

This is the ratified answer to a convergence failure, not a preference: the
boundary see-saw (DP-5) produced a defect on one side or the other in six
findings across three review rounds, and the loop reached
`STOP:max_iterations_reached` still oscillating. When a rule's discriminator is
structurally too weak to separate its inputs — a one-character lookbehind here —
tightening and loosening it alternately cannot converge, so the decision has to be
made at the level of *which error we choose to make*.

Consequences, which are the operative part:

- Suppression is added only for a false-positive class that has been **measured in
  this repository**, never for one imagined during review. Exactly one qualifies
  today (DP-5's bare documentation URL).
- A reviewer or QA finding of the form "input X is a false positive" is **not**
  grounds for widening a suppression rule. It is grounds for a declared class in
  the documents, or for the placeholder discipline (AC9) at the authoring site.
  The fail-noisy direction is itself locked by test (AC28's two positives), so a
  future round cannot quietly re-widen the boundary.
- The declared classes must be worded so they cannot be read as a completeness
  claim — the same discipline as every other line in that documentation section.
- This principle is scoped to **shape-rule boundaries**, not to the fail-closed
  exit contract (AC2) or to the no-leak property (AC14), which are unaffected.

### DP-5 — the home-path boundary requirement, closing the URL false positive

An unanchored home-path pattern fires on an ordinary documentation URL whose path
contains a home-directory-looking segment. That input is squarely inside the
declared reachable class (English and Japanese prose), and a false positive in a
**required** gate is not a cosmetic problem: it reds a change the author can only
fix by rewording, which is precisely how a control loses its authority. The
previous justification for leaving the pattern unanchored reached two tested
near-misses (a relative path, the `<name>` placeholder) and did not reach this
class.

Resolution, and its **final, narrow** form: the shape is suppressed only when the
character immediately before its leading `/` can continue a **host name** — an
ASCII letter or digit, a dot, or a hyphen. A URL authority (`example.com/…`)
therefore suppresses; a quoted path, a path after a space, a path at line start,
a path after a bracket and a path after another slash all still fire.

This rule is **empirically earned, not defensive gold-plating**: the measurement
in Assumptions found a URL path fragment of exactly this shape already in the
tracked tree, so without the rule the required gate would red on existing,
harmless documentation content. That single measured case is the whole warrant for
the rule — and, per DP-10, the whole extent of it.

**What was tried and reverted.** Round 3 widened the suppression so that a `/` or
a `]` before the match also silenced it, aiming to quiet the `file://`,
markdown-link and IPv6-authority variants. Round 4 then proved the widening
silences genuine true positives that are mechanically reachable: the
doubled-leading-slash form bash's own diagnostics emit, and the bracket-adjacent
form an xtrace prefix emits. The widening is reverted (AC28 locks both of those as
positives). A one-character lookbehind cannot separate "a path inside a URL" from
"a path in prose or a log line" — the class recurred six times across three
rounds, each adjustment leaking on the opposite side — so the choice is not which
regex to write next but which way the rule should lean. DP-10 answers that.

### DP-6 — where the changed-path set comes from, and which content is read

The changed-path set is the diff of the base ref against `HEAD`, resolved as in
DP-2, and the content read for each path is that path's **committed** content.
One sentence is enough now that the unit is full-content: a required CI check
judges what was pushed, and a local pre-push check is only useful if it judges
what is about to be pushed. The working tree is not abandoned — `--all` reads it,
including untracked files — and both halves are stated in the documents
(AC18 / AC19).

Practical consequence for the engineer and for QA: the self-application check
(AC15) reads committed content, so changes must be committed before it means
anything.

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
- The deliberate shape-bearing fixtures under tests/ are carried by the test-locked known-shapes list, so --all exits 0 on this tree; --all remains an audit flag and is deliberately not a required CI check.
- A PII shape in a filename or a path is not inspected; this gate reads file content only.
- Some URL-adjacent and log-prefixed forms may be reported even though they carry no personal data: a file scheme URL, a path wrapped in markdown link syntax, and a path following an IPv6 authority. That noise is accepted deliberately, because a one-character lookbehind cannot tell those apart from a real path in prose; the resolution is to write the placeholder form, never to widen the suppression.
- The home-path shapes match a conservative ASCII name segment only; a name written in non-ASCII characters, and unusual case spellings of the Windows form, are not covered.
- A mailbox shape is not reported when its domain cannot hold a deliverable mailbox: a domain reserved for documentation and testing, or the GitHub noreply domain used for pseudonymous identities. The excluded domains are listed in the checker source.
- The gate reads the committed content of each path the change touches, resolved against the base ref; a change that exists only in the working tree is not scanned, and --all is the mode that reads the working tree.
- A short list of paths that deliberately carry shapes, as fixtures another guard needs, is excluded by name; the list lives in the checker source and its exact contents are asserted by the test suite.
```

The last six lines are v4's declared limitations; the first five are issue #6's
four mandated limits plus the `--all` statement, and they stay byte-unchanged.
All ten are matched whole-line-exact and in no particular order, so T-112's own
two lines can land in the same file without interference.

`docs/pii-controls.ja.md`:

```text
## このゲートが扱わないもの
- 固有名詞（顧客名・内部ホスト名・プロジェクトコード）は形状では一致させられないため、このゲートの対象外である。
- 固有名詞に一致させるためのパターン自体が機密であるため、この公開リポジトリには置けない。リポジトリ外のオペレータ手元のチェックに置く。
- 意味的な機微さ（設計判断や文脈から読み手が業務上の関係を推測できてしまう類）は PII の形状ではなく、対象外である。
- 画像の内容は検査しない。検査するとしてもメタデータのみである。
このゲートは形状だけを見る。PII 対策として完全ではなく、通過したことは変更に PII が含まれないことの証拠にはならない。
- ファイル名やパス自体に含まれる PII 形状は検査しない。このゲートはファイルの内容だけを読む。
- URL に隣接する形やログ接頭辞の付いた形は、個人データを含まないのに報告されることがある。file スキームの URL、markdown のリンク記法で囲まれたパス、IPv6 の authority に続くパスが該当する。1 文字の後読みではこれらを散文中の実際のパスと区別できないため、この雑音は意図して受け入れる。解消はプレースホルダ形で書くことであり、抑制範囲を広げることではない。
- home-path の形状は ASCII の保守的な名前セグメントにだけ一致する。非 ASCII の名前や Windows 形式の異なる大小文字表記は対象外である。
- 配送可能なメールボックスが存在し得ないドメインのメールアドレス形状は報告しない。ドキュメントおよびテスト用に予約されたドメインと、GitHub の擬名 identity 用 noreply ドメインが該当する。除外ドメインの一覧はチェッカーのソースにある。
- このゲートは変更が触れた各パスのコミット済み内容を、base ref に対して解決して読む。ワーキングツリーにだけある変更は検査せず、ワーキングツリーを読むのは --all のモードである。
- 別のガードが必要とする fixture として意図的に形状を持つパスの短い一覧を、名前で除外する。一覧はチェッカーのソースにあり、その正確な内容はテストスイートが検証する。
```

### Canonical suite assertion labels

`tests/check-pii-shapes/run.sh` must print or contain these labels verbatim —
they are the anchors QA greps (AC2, AC4-AC14, AC26-AC29):

```text
exit-code contract
unresolvable base ref
POS/NEG pair: home-path
POS/NEG pair: home-path-win
POS/NEG pair: email-nonnoreply
POS/NEG pair: private-key
POS/NEG pair: token
negative: short lookalike must not fire
placeholder forms are not findings
mutation: pattern is load-bearing
meta: neutralised positive fixture makes the assertion FAIL
no-allowlist: finding reported even for the checker own path
no-leak: finding output never echoes the matched text
negative: the noreply domain, end-anchored, whatever the local part is
negative: a printf format placeholder local part at the noreply domain (runtime-assembly helpers carry one)
negative: one fixture per reserved-domain form
positive: an ordinary domain still fires (anti-swallow)
positive: a suffix-confusable domain at a non-reserved name still fires (anti-swallow)
precondition: each negative fixture reaches the email candidate enumeration
mutation: each exclusion is load-bearing
known-shapes list: exact contents asserted, per-file only, no directory or glob entry
temp hygiene: every throwaway repo is created inside the trap-cleaned work dir
all candidates per line: an excluded address on the same line never masks a real mailbox shape
text-vs-binary: NUL byte decides, Japanese prose is scanned, a skip is announced
boundary: only a host-name character suppresses, so the bare documentation URL stays clean
positive: a doubled-leading-slash home path fires (fail-noisy, bash diagnostics emit this)
positive: a home path preceded by a bracket fires (fail-noisy, xtrace prefixes emit this)
--all no-silent-skip: repo-root scope, symlink target, = in a filename, unreadable is exit 2
```

## Body-to-AC correspondence

| Body directive | Where it lands |
|---|---|
| Change-scoped, not whole-tree | AC15 (self-application over a real change set), DP-2 + DP-4 fix the unit |
| Never parse git's diff rendering (DP-4) | AC25 (the three parsing anchors are absent from the source, `cat-file` is present) |
| A verdict must not depend on git configuration | AC25 — structurally guaranteed by the mechanism rather than proved behaviorally; v3's three-condition proof was removed as an assertion of a structurally absent property (see "Removed in v4") |
| Full content of each changed path, no base-blob comparison | AC15, AC16, and DP-4's unit statement |
| Every candidate on a line is judged, not the leftmost | AC26 |
| Text vs binary decided by the NUL byte; a skip is announced; unreadable is exit 2 | AC27 |
| The one measured URL false positive is closed by a narrow boundary rule (DP-5) | AC28 (its negative fixture) |
| Where a shape rule cannot separate the populations, it fires (DP-10) | AC28 (two positive fixtures lock the direction), AC18 / AC19 (the accepted classes are declared instead of suppressed) |
| The round-3 boundary widening is reverted; `/` and `]` do not suppress | AC28 |
| A false-positive report is not grounds for widening a suppression rule | info-only (not promoted to AC) — a rule about how future review rounds are handled, not a property of the artifact; AC28's positives are what make a quiet re-widening fail |
| The `--all` documentation bullet states the shipped invariant | AC20 |
| The reserved-domain exclusion, with an anti-swallow positive (DP-7) | AC6, AC10 |
| The noreply exclusion is an end-anchored domain match, not an address shape (DP-9) | AC6 (three negatives including the format-placeholder class, plus the suffix-confusable anti-swallow positive), AC10 (individually load-bearing) |
| A suffix-confusable or subdomain trick on the noreply domain still fires | AC6 |
| The anti-swallow fixture must not sit at a reserved domain | AC6 (stated as a fixture constraint so the fixture cannot pass for the wrong reason) |
| Nine mutation rules: five patterns, four exclusions | AC10 |
| The known-shapes list is per-file, in-source, and test-locked (DP-8) | AC13 |
| The list is not an exemption for this task's own files | AC13 |
| `--all` never silently skips | AC29 |
| `--all` is clean on this tree (honest-bookkeeping invariant) | AC16 |
| Every limit is stated in `docs/` — four mandated plus six declared | AC18 (en), AC19 (ja) |
| Process artifacts use placeholder forms; listing them is forbidden | AC15 (a real-looking segment in a spec, review record or provenance file reds it) |
| Each exclusion is load-bearing, not only each pattern | AC10, AC6 (the precondition that the branch is reached) |
| Throwaway repos live inside the trap-cleaned work dir | AC12 |
| An auxiliary layer, not a security boundary; catalogue deliberately small | info-only (not promoted to AC) — a framing statement from issue #6 that bounds what other criteria may demand; the Input space out-of-scope list is where it becomes operative |
| Non-ASCII name segments and unusual Windows case forms are not covered | AC18 / AC19 (stated as a declared limitation) — deliberately NOT a detection criterion; see "Removed in v4" |
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
| Untracked files are not scanned in diff mode | AC35 (v3 promotes it: the working-tree limitation is now one of the three canonical document lines, so it is no longer body-only prose) |
| A credential-prefix catalogue is not exhaustive; newer provider prefixes are a fast-follow | info-only (not promoted to AC) — a declared scope limit recorded in the Input space out-of-scope list; promoting it would mean asserting the absence of patterns this task deliberately does not add |
| (A) pin-and-state-machine was considered and rejected | info-only (not promoted to AC) — a rejected alternative; AC25 asserts the chosen mechanism positively, which is the observable half |
| Prose names shapes by pattern id, never by transcribing a match | info-only (not promoted to AC) — enforced indirectly and sufficiently by AC15: a transcribed literal would red the self-application check |
| Not UI work; no design note | info-only (not promoted to AC) — routing decision from tech-lead, no artifact to verify |
| No AI-driven CI workflow | info-only (not promoted to AC) — a repo-wide invariant in `CLAUDE.md`, not introduced by this task; AC17 pins the only workflow edits made |

## Assumptions

- shellcheck is available to QA at the version CI pins (0.11.0). AC1 fails
  loudly rather than skipping if it is absent — that is deliberate.
- **The measurement v4 rests on** (taken by the orchestrator with independent
  patterns, not with this checker's own `--all`, whose UTF-8 misjudgment and
  symlink skip would have undercounted): eight tracked paths carry a shape, and
  **not one of them is a real PII value**. Every mailbox shape is at an
  RFC-reserved documentation or testing domain; the home-path shapes are
  placeholder names plus one URL path fragment — the exact false positive
  cross-provider review reported, now confirmed to exist in-tree; the token and
  private-key shapes are the five deliberate adversarial fixtures under
  `tests/rollup-track/fixtures/` that exist to prove another guard fires. This is
  what licenses v4's three simplifications: the blunt unit (DP-4), the
  reserved-domain rule (DP-7) and the five-file list (DP-8). Touch-frequency
  across history was also measured but is **not** relied on: `develop` has only
  seven reachable commits, too few to support an argument.
- Consequently AC16 expects `--all` to exit **0**. If a ninth shape-bearing path
  appears, the correct response is a pattern fix (if it is a false positive) or a
  placeholder rewrite (if it is one of our own records) — not list growth.
- One instance of the placeholder discipline is **already outstanding**: the
  Codex round wrote a home-path shape with a real-looking ASCII name segment into
  `.shell-team/reviews/T-111.md`. AC15 and AC16 will red until it is normalised to
  the AC9 placeholder form. Normalising it changes no finding, no verdict and no
  severity — only the shape literal.
- **The boundary see-saw, and how it was settled.** Round 3 widened the
  suppression to quiet the URL-adjacent variants; round 4 proved the widening also
  silences two mechanically reachable true positives. Six findings of this one
  class across three rounds, and the loop reached
  `STOP:max_iterations_reached` still oscillating. The human's decision — recorded
  here as the warrant for DP-10 and AC28 — is to **bias toward firing**. That is a
  directional choice about which error to accept, not a new mechanism, which is why
  the criteria count does not grow.
- **A second dogfooding measurement, taken after v4's draft** and verified against
  the mechanism rather than accepted on report: T-112's implementation
  (`fdfd5f9`) tripped this checker, and one of the findings is in T-112's **own**
  new test file — the runtime identity-assembly helper, whose printf format string
  matched the email shape and was not exempted by the old local-part-shape
  exclusion. DP-9 is the fix. The engineer's initial reading ("unrelated to
  T-112's diff") was incorrect, which is itself the reason this spec asks for
  empirical confirmation rather than a report: the finding named the file.
- `.shell-team/runs/` is ignored by `.shell-team/.gitignore`, so run telemetry
  never enters the change set AC15 scans. Verified by reading that file.
- CI's `actions/checkout` uses `fetch-depth: 0`, so `origin/$GITHUB_BASE_REF`
  resolves in the pull_request context. Unverified for the push-to-`develop`
  event, where the change set is expected to be empty or trivially clean.
- v3 assumption, **unverified by pm-spec** (no shell): that `git cat-file` and a
  NUL-separated `--name-only` / `--name-status` enumeration are available and
  behave identically on the macOS git QA runs and the CI runner's git. Both are
  long-standing plumbing, but the engineer should confirm on both rather than
  infer it. If some enumeration flag turns out unavailable, DP-4's requirement is
  the *property* (NUL separation, no rename detection, no rendering parsed), not a
  particular flag string.
- v3 assumption, **unverified**: that reading two blobs per changed path stays
  fast enough for this repository's change sizes. The largest realistic change in
  this repo is a few thousand lines; if a path is pathologically large, the
  Input space's out-of-scope class 4 applies.

## Open questions

None blocking. DP-1 through DP-6 are decided here; the engineer does not need to
reopen them. In particular the mechanism question (parse a pinned diff rendering
versus stop parsing it) is closed by DP-4 — if it looks reopenable during
implementation, that is a signal to raise it as a spec question, not to choose
locally.

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
- Ask yourself the detector-blind-spot questions explicitly. v2's list is obsolete
  because DP-4 removes the parser; the v4 list is: does the candidate enumeration
  stop at the first match on a line (AC26); does the text/binary decision look for
  a NUL byte or for printability (AC27); does the enumeration split on NUL or on
  whitespace (AC29); does a path that cannot be read exit 2 or get skipped (it
  must exit 2); is the boundary rule applied to **both** home-path patterns
  (AC28); does either domain exclusion swallow ordinary domains (AC6's two
  anti-swallow positives); is the noreply domain compared **end-anchored** or as a
  substring (DP-9 — a substring test is the classic bug here).
- **The noreply exclusion keys off the domain, never the local part** (DP-9). Do
  not reintroduce a `<digits>+<login>` local-part test as an extra condition: it
  is what flagged T-112's runtime identity helper, and it also rejects GitHub's
  older login-only form. Whatever the local part looks like — a login, an id plus
  a login, or a printf placeholder — the domain decides.
- **The boundary lookbehind suppresses host-name characters only** (DP-5): an
  ASCII letter or digit, a dot, a hyphen. Do not re-add `/` or `]` — round 3 did,
  and round 4 proved it silences real paths. If a review round hands you another
  false-positive input, the answer is a declared class in the documents or the
  placeholder form at the authoring site (DP-10), not a wider rule; AC28's two
  positives will fail if you widen it.
- When you write the suffix-confusable anti-swallow fixture, pick a domain that is
  **not** reserved. A reserved one would be excluded by DP-7, the fixture would
  pass while proving nothing about anchoring, and that is precisely the vacuity
  class this task has already been burned by twice.
- **Keep the name class conservative ASCII.** v4 deliberately does not widen it
  (see "Removed in v4"), which also preserves the incidental property that the
  checker's own source does not match its own patterns. If you widen it anyway,
  AC15 will red: the line that *defines* the pattern contains the literal
  directory prefix immediately followed by the bracket expression, and a class
  spelled with the slash listed first lets the segment reach a `/`, so the
  defining line matches the pattern it defines. Ordering the `<` and `>`
  exclusions before any `/`, or assembling the pattern from fragments at runtime
  as DP-1 already does for fixtures, avoids it — but the simplest answer is not to
  widen. The same trap applies to prose, which is why this spec describes shapes
  instead of showing them.
- **Do not write a concrete real-looking home path into any tracked file** —
  spec, docs, test source, comment, provenance or review record. Assemble fixtures
  at runtime and use the AC9 placeholder form in prose. One instance is already
  outstanding in the review record (Assumptions); normalising it is part of this
  rework, and it is a shape-literal edit only — do not touch any finding, verdict
  or severity in that file.
- Commit before running AC15 by hand: DP-6 makes the change-scoped mode read
  committed content, so an uncommitted fix is invisible to it.
- **`--all` should now come back clean** (AC16). If it does not, read the finding
  before reaching for the list: the intended fixes are a pattern correction or a
  placeholder rewrite, and DP-8's list is only for a file whose shapes are
  deliberate fixtures for another guard.
- Files expected to change in the v4 rework: `bin/check-pii-shapes.sh` (replace
  the diff mechanism per DP-4 and scan full content, bound the home-path shapes
  per DP-5, add the reserved-domain exclusion per DP-7 and the five-file list per
  DP-8, replace the noreply exclusion with the end-anchored domain match per DP-9,
  replace the text/binary test per AC27, harden `--all` per AC29),
  `tests/check-pii-shapes/run.sh` (the new label groups, mutation rows for the
  exclusions, the list-contents assertion, throwaway repos inside the work dir),
  `docs/pii-controls.md` and `docs/pii-controls.ja.md` (six new lines each;
  **the existing lines stay byte-identical** — AC20 must keep passing unchanged),
  `.shell-team/reviews/T-111.md` (normalise the one outstanding shape literal —
  nothing else), `.shell-team/provenance/T-111.md` (record DP-4's simplification,
  DP-7 and DP-8 with grounding), `.shell-team/todo.md` (status flag only — the
  orchestrator owns the hash ledger). `.github/workflows/check-handoff.yml` needs
  no further edit if AC17's wiring is already in place; do not re-add it.
- **T-112 is being implemented in parallel** and writes two lines into each
  document. Append your lines; do not reflow, reorder or rewrite the files, and do
  not assume a line count. Every docs assertion here is whole-line exact for that
  reason.
- The five pattern ids, the runtime-generated-fixtures decision (DP-1), the
  no-leak property, the CLI surface (`--base` / `--all` / `--help`) and the
  0/1/2 exit codes are **unchanged and load-bearing for other specs**: T-112's
  AC17/AC20 and T-113's AC10 already assert `bash bin/check-pii-shapes.sh --base
  develop` and grep the workflow for that invocation, and both specs are frozen.
  Renaming a flag would break two frozen specs.
- There is deliberately **no whole-diff scope-lock AC** here: all three tasks
  share one branch, so a file-set allow-list authored now would go stale the
  moment T-112 lands. AC24 pins the specific files that must stay untouched
  instead.

## Notes from engineer

- **Resolved in v2.** The blocking `grep -qxF` leading-hyphen defect
  originally reported here for AC18/AC19/AC20 was inventoried across all
  three specs (15 sites) and fixed by pm-spec's v1→v2 re-freeze (`--`
  inserted at every site, nothing else changed; user-ratified, committed as
  763fae7). `bash bin/check-acs.sh .shell-team/specs/T-111-pii-shape-checker.md`
  now reports 24 passed, 0 failed. A separate, small rendering fix (bullet
  list/paragraph ordering and a missing blank line in
  `docs/pii-controls.md`'s "## What this gate does not cover" section, AC18
  and AC20's matched lines left byte-identical) is recorded in
  `.shell-team/provenance/T-111.md`.
