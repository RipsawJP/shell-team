# T-1007 — the lessons ledger is Scope-typed and the shipping boundary is machine-enforced

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1007
**Source**: GitHub issue #23. This is the **mechanism half** of a two-task split of #23; the corpus half is T-1008 against the same tracker. No new issue was opened: #23 carries the decided design (the D plan) and remains the tracker for both halves.
**Branch**: `feature/scope-typed-ledger` (from `develop` at `72b6e8b`).

## Problem

`templates/prompt-blocks/playbook-*.md` are generated artefacts spliced into
`agents/*.md` and shipped to every adopter, and the file they are generated from
does not exist in this repository. Issue #23 measured the corpus that will fill
that gap and found the defect it must not ship with: **~30% of its active entries
are only meaningful when developing this plugin** — one maintainer's sandbox
quirks, this repository's CI behaviour, its release procedure. Today nothing
stops those entries reaching an adopter's prompt, because the boundary between
"ships" and "stays here" is a convention rather than a check.

`agents/scrum-master.md:52` already has the retro classify each candidate
`[common]` / `[target-specific]`, but `bin/playbook-promote.sh` has no flag
carrying that label, so the classification is discarded at promotion. The three
scripts that read and write the ledger — `bin/check-playbook.sh`,
`bin/gen-playbook-blocks.sh`, `bin/playbook-promote.sh` — have no concept of
scope at all: `KNOWN_FIELD_NAMES` (`bin/check-playbook.sh:166`) is nine fields,
and neither `Scope` nor `Bound-in` appears anywhere in the repository.

The ordering is forced, not preferred. `bin/check-playbook.sh:592-605`'s
catch-all makes **any** unrecognised `- **Name**:` bullet a fail-closed
violation, so a corpus carrying `Scope:` cannot exist before the checker knows
the field. This task therefore ships the machine-enforced boundary **with zero
corpus**, and T-1008 ships the corpus into it.

## Goal

<!-- BEGIN intent-block: T-1007 -->

**One ledger, one key namespace, one `Superseded-by` graph — with a required
`Scope` field.** Every entry carries `- **Scope**: loop` or
`- **Scope**: maintainer`. A missing `Scope`, an empty one, or any value outside
that two-token enum is a fail-closed violation of the same class as a missing
`Category` today. There is no third value and no default: a default would
silently classify, which is the failure this task exists to remove.

**The shipping boundary is enforced in the generator, not by convention.**
`bin/gen-playbook-blocks.sh` emits a line for an entry only when its `Scope`
trims to `loop`. A `maintainer` entry never reaches
`templates/prompt-blocks/playbook-*.md` and therefore never reaches an adopter's
prompt, whatever its `Applies-to` says — `Scope` decides *whether* an entry
ships, `Applies-to` decides *where*. A role whose entries are all `maintainer`
gets the generator's existing "no active entries currently apply to this role"
line, not an empty or malformed block.

**A maintainer entry binds to a repo-local file through `Bound-in`, and the
binding is mandatory.** `- **Bound-in**: <repository-relative path>` is required
on every `Scope: maintainer` entry and forbidden on every `Scope: loop` entry.
Required, because an optional pointer makes the binding a convention again —
the exact defect the D plan refuted. Forbidden on `loop`, because a `Bound-in`
on a shipped entry is the signature of a mis-scoped entry and catching it is
worth more than tolerating it. The checker validates the value's **shape only**
— non-empty after trimming, not absolute, not `~`-prefixed, plus the structural
checks every field value already gets — and never touches the filesystem, so a
verdict never depends on the working directory the checker was invoked from.

**A shipped rule may only be retired in favour of another shipped rule.** A
`Superseded-by` pointer on a `Scope: loop` entry whose target is `Scope:
maintainer` is a fail-closed violation: the reference graph stays healthy while
a rule silently disappears from every adopter's prompt with nothing replacing it
in the shipped set. The other three combinations stay legal — `loop → loop`,
`maintainer → maintainer`, and in particular **`maintainer → loop`**, which
issue #23 names as a requirement of the one-file design (a local lesson that
generalises must be able to name its universal replacement).

**`bin/playbook-promote.sh` carries the retro's classification through
promotion.** `--scope` is required with no default; `--bound-in` is passed
through to the emitted entry. The script does not re-implement the `Scope` ×
`Bound-in` rule: it emits the bullets and lets its existing fail-closed
re-validation against `bin/check-playbook.sh` reject an invalid combination, so
there is exactly one authority for the schema and no second copy to drift.
`--help` documents both flags.

**All of this lands inside the three existing scripts.** No new file enters
`bin/`. A separate checker would make the boundary conventional again — nothing
would stop the generator being pointed at a corpus that never passed it.

**The task ships with zero corpus and zero prompt-block churn.** Nothing is
created at the resolved lessons path, and all four
`templates/prompt-blocks/playbook-*.md` files and their `agents/*.md` consumers
are byte-identical to the base ref. Every new behaviour is proved on fixtures.

## Non-goals

- **No corpus, and no `.shell-team/lessons.md`.** Translating, scrubbing,
  scoping and importing the real corpus is T-1008. This task ships the boundary
  the corpus will have to pass; it does not ship anything that passes it outside
  `tests/`.
- **No CI provenance / regen-diff step.** #23's "validate the corpus at the
  resolved canonical path, regenerate in a scratch checkout, diff all four
  blocks and all four consumers" can only be written once a corpus exists. It
  would fail on every run until T-1008 lands.
- **No prompt-block regeneration.** The four canonical blocks and the four agent
  consumers are pinned byte-unchanged by a criterion, which is how "zero corpus"
  is proved rather than promised.
- **No `agents/`, `skills/`, `docs/`, `templates/` or root `CLAUDE.md` edit.**
  In particular `agents/scrum-master.md`'s `[common]` / `[target-specific]`
  vocabulary is *not* re-worded to `loop` / `maintainer` here: agent prose is
  T-1008's surface, and issue #57 already owns an edit to that same file. The
  omission is verifiable, not silent — the scope lock pins those trees
  unchanged.
- **Issues #57 and #58 are not fixed here.** They were filed as T-1006's
  fast-follows and are carried by T-1008.
- **No change to `LINE_WARN_THRESHOLD`** (#23 says so explicitly) and no change
  to the warning's behaviour. Its source line moves as a side effect of editing
  the generator, and the only permitted consequence of that is re-pinning
  `tests/errexit-safe/run.sh`'s `NOT_APPLY` line-number token.
- **No new `bin/` file and no new runtime dependency.** Pure bash, coreutils,
  shellcheck-clean.
- **No re-litigation of the existing schema.** The nine pre-existing field names,
  the fence grammar, the NUL scan, the calendar-date check, the key-uniqueness
  pass and the existing `Superseded-by` checks (dangling, self-reference,
  chained) are untouched except where `Scope` composes with them.
- **No third `Scope` value.** #23's routing table has four outcomes and only two
  of them are `Scope` values; `operator-global` and `drop` never enter the
  repository, so they never need a token.
- **No filesystem semantics for `Bound-in`.** Existence, readability, symlinks,
  directory-versus-file: none of it is checked, deliberately (see DP-d).

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh` or `bash tests/<suite>/run.sh`. Every
criterion below is exit-code mechanical; that is the point of the split.

Six standing rules apply to every criterion:

- **No negated `grep` without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` cannot be read, because `grep` exits 2 and the negation
  swallows it. Every criterion asserting a string is absent asserts, in the same
  command and against the same target, that something which must be present is.
- **A count is pinned in both directions** wherever a count is the property.
- **Every temporary fixture uses an explicit `mktemp` template**
  (`"${TMPDIR:-/tmp}/t1007.XXXXXX"`). A bare `mktemp` ignores an inherited
  `TMPDIR` on macOS and targets the system temp dir, which a sandboxed session
  cannot write. Every criterion that builds a fixture removes it and preserves
  its own verdict across the cleanup.
- **A criterion never mutates the working tree.** Fixtures are copies under
  `$F`; the shipped fixture corpora are read, never written.
- **Which criteria pass before the change** (to be measured live by the
  executing side before the freeze, and this disclosure corrected to the
  measured result): **AC13, AC15, AC16 and AC19**. AC13 is a two-sided
  invariant lock — the `NOT_APPLY` pin matches the generator's current line
  today and must still match after the edit. AC15 and AC19 are locks on things
  this task must *not* do, true before and after. AC16 passes as soon as this
  spec and the board entry are on the branch (both are inside its allow-list).
  Every other criterion fails before the change and is what proves it happened.
  **pm-spec has no shell in this role, so no `check:` line below was executed** —
  the executing side runs all nineteen live against the pre-implementation tree,
  corrects any line that is broken as a command or would pass vacuously
  (meaning preserved), corrects this disclosure, and only then freezes the
  intent hash.
- **A criterion states the boundary of what it proves.** These criteria prove
  the schema, the generator filter, the promotion flags and the absence of
  corpus/prompt churn. They prove nothing about the *content* of a corpus that
  does not exist yet, and nothing about whether a future entry is scoped
  correctly — that is a human judgement T-1008 carries.

**Strings this task fixes as an output contract**, so the criteria can pin them:

| Situation | Contract |
|---|---|
| `Scope` bullet absent | reason contains `missing required field: Scope` (the existing `emit` shape) |
| `Scope` value outside the enum, or empty after trim | exit 1; the outside-enum case's reason contains `unknown Scope value` |
| `Scope: maintainer` with no usable `Bound-in` (absent, or blank after trim) | reason contains `Scope is 'maintainer' but Bound-in is missing` |
| `Scope: loop` carrying a `Bound-in` bullet at all (tested by field presence, not value) | reason contains `Scope is 'loop' but Bound-in is present` |
| `Bound-in` value absolute (`/…`) or `~`-prefixed | reason contains `Bound-in must be a repository-relative path` |
| `Scope: loop` entry superseded by a `Scope: maintainer` entry | reason contains `Superseded-by crosses Scope` |
| `bin/playbook-promote.sh` invoked without `--scope` | `playbook-promote: missing required --scope`, exit 2 (its existing required-field `die` shape) |
| an invalid `Scope` × `Bound-in` combination reaches promote | exit 1 from the existing re-validation, lessons file byte-untouched |
| promoted entry layout | `- **Scope**: …` immediately after `- **Applies-to**: …`, and `- **Bound-in**: …` immediately after it when supplied |

**Fixture contract** (three corpora already shipped; annotate and append, never
remove an existing entry, so every pre-existing assertion keeps passing):

1. `tests/check-playbook/fixtures/valid-base.md` — every entry gains a `Scope`;
   one **new active `Scope: maintainer` entry** carries
   `- **Bound-in**: CONTRIBUTING.md`.

   In **all three** corpora, the `## Format` fenced example documents both new
   fields, and its `Scope` line uses an angle-bracket placeholder
   (`- **Scope**: <loop | maintainer>`) rather than a bare enum token — so a
   `sed` aimed at `- **Scope**: loop` or `- **Scope**: maintainer` cannot reach
   the fenced example.
2. `tests/gen-playbook-blocks/fixtures/root/tasks/lessons.md` — existing entries
   gain `Scope: loop`; the all-roles active entry's `Rule` additionally carries
   the sentinel `T1007-LOOP-SENTINEL`; one **new active entry** carries
   `Applies-to: all`, `Scope: maintainer`, `Bound-in: CONTRIBUTING.md` and the
   sentinel `T1007-MAINTAINER-SENTINEL` in its `Rule`. `Applies-to: all` is
   load-bearing: it is what proves the exclusion is by `Scope` and not by role.
3. `tests/playbook-promote/fixtures/lessons-base.md` — its pre-existing entry
   gains `Scope: loop`.

- [ ] **AC1** **`Scope` is required and its enum is closed, fail-closed in all
  three failure modes.** The shipped fixture is green (positive control); with
  every `Scope` bullet removed the checker exits 1 naming the missing field;
  with the value replaced by `all` it exits 1 naming an unknown value; with the
  value blanked to whitespace it exits 1.
  - check: B=tests/check-playbook/fixtures/valid-base.md; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { bash bin/check-playbook.sh "$B" >/dev/null 2>&1 && grep -v -- '- \*\*Scope\*\*: ' "$B" > "$F/a.md" && r1=0 && { bash bin/check-playbook.sh "$F/a.md" >/dev/null 2>"$F/e1" || r1=$?; } && test "$r1" -eq 1 && grep -qF 'missing required field: Scope' "$F/e1" && sed 's/- \*\*Scope\*\*: loop/- **Scope**: all/' "$B" > "$F/b.md" && r2=0 && { bash bin/check-playbook.sh "$F/b.md" >/dev/null 2>"$F/e2" || r2=$?; } && test "$r2" -eq 1 && grep -qF 'unknown Scope value' "$F/e2" && sed 's/- \*\*Scope\*\*: loop/- **Scope**:   /' "$B" > "$F/c.md" && r3=0 && { bash bin/check-playbook.sh "$F/c.md" >/dev/null 2>&1 || r3=$?; } && test "$r3" -eq 1; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC2** **Both new field names are registered, and the unknown-bullet
  catch-all is not loosened.** All eleven field names appear in the shipped
  fixture, which is green — `Scope` at least three times and `Bound-in` at least
  twice (the `## Format` example plus real entries), pinning that the fixture
  carries both scopes rather than only documenting them. Renaming the `Scope`
  bullet to an unregistered `Zzz` is still rejected, and the catch-all's
  allow-list enumeration names both new fields. The enumeration line is isolated
  before grepping, because the same stderr also carries a
  `missing required field: Scope` line that would satisfy a naive match.
  - check: B=tests/check-playbook/fixtures/valid-base.md; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { bash bin/check-playbook.sh "$B" >/dev/null 2>&1 && grep -qF -- '- **Category**: ' "$B" && grep -qF -- '- **Applies-to**: ' "$B" && grep -qF -- '- **Status**: ' "$B" && grep -qF -- '- **Source**: ' "$B" && grep -qF -- '- **Rule**: ' "$B" && grep -qF -- '- **Why**: ' "$B" && grep -qF -- '- **How to apply**: ' "$B" && grep -qF -- '- **Superseded-by**: ' "$B" && grep -qF -- '- **Extended by**: ' "$B" && test "$(grep -cF -- '- **Scope**: ' "$B")" -ge 3 && test "$(grep -cF -- '- **Bound-in**: ' "$B")" -ge 2 && sed 's/- \*\*Scope\*\*: /- **Zzz**: /' "$B" > "$F/u.md" && r=0 && { bash bin/check-playbook.sh "$F/u.md" >/dev/null 2>"$F/e" || r=$?; } && test "$r" -eq 1 && grep -qF "unknown field bullet: '- **Zzz**:'" "$F/e" && grep -F 'known field allow-list:' "$F/e" | grep -qF 'Scope' && grep -F 'known field allow-list:' "$F/e" | grep -qF 'Bound-in'; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC3** **`Bound-in` is mandatory on `maintainer` and forbidden on
  `loop`.** Against the shipped fixture (green, and carrying the maintainer
  entry's real pointer as the positive control): removing every `Bound-in`
  bullet exits 1 naming the field; blanking its value to whitespace exits 1 —
  the value test, not a presence proxy; flipping the maintainer entry's `Scope`
  to `loop` while it still carries `Bound-in` exits 1 naming the field — the
  presence test, not a value test.
  - check: B=tests/check-playbook/fixtures/valid-base.md; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { bash bin/check-playbook.sh "$B" >/dev/null 2>&1 && grep -qF -- '- **Bound-in**: CONTRIBUTING.md' "$B" && grep -v -- '- \*\*Bound-in\*\*: ' "$B" > "$F/a.md" && r1=0 && { bash bin/check-playbook.sh "$F/a.md" >/dev/null 2>"$F/e1" || r1=$?; } && test "$r1" -eq 1 && grep -qF "Scope is 'maintainer' but Bound-in is missing" "$F/e1" && sed 's|- \*\*Bound-in\*\*: CONTRIBUTING.md|- **Bound-in**:   |' "$B" > "$F/b.md" && r2=0 && { bash bin/check-playbook.sh "$F/b.md" >/dev/null 2>"$F/e2" || r2=$?; } && test "$r2" -eq 1 && grep -qF "Scope is 'maintainer' but Bound-in is missing" "$F/e2" && sed 's|- \*\*Scope\*\*: maintainer|- **Scope**: loop|' "$B" > "$F/c.md" && r3=0 && { bash bin/check-playbook.sh "$F/c.md" >/dev/null 2>"$F/e3" || r3=$?; } && test "$r3" -eq 1 && grep -qF "Scope is 'loop' but Bound-in is present" "$F/e3"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC4** **`Bound-in` is validated by shape only, and the verdict never
  depends on the working directory.** An absolute value and a `~`-prefixed value
  are both rejected; a repository-relative value is accepted (positive control);
  a relative value naming a file that does not exist is *also* accepted, and the
  identical file validates green both from the repository root and from an
  unrelated directory — which is what proves the checker does not read the tree.
  - check: B=tests/check-playbook/fixtures/valid-base.md; R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { bash bin/check-playbook.sh "$B" >/dev/null 2>&1 && sed 's|- \*\*Bound-in\*\*: CONTRIBUTING.md|- **Bound-in**: /etc/hosts|' "$B" > "$F/abs.md" && r1=0 && { bash bin/check-playbook.sh "$F/abs.md" >/dev/null 2>"$F/e1" || r1=$?; } && test "$r1" -eq 1 && grep -qF 'Bound-in must be a repository-relative path' "$F/e1" && sed 's|- \*\*Bound-in\*\*: CONTRIBUTING.md|- **Bound-in**: ~/notes.md|' "$B" > "$F/tilde.md" && r2=0 && { bash bin/check-playbook.sh "$F/tilde.md" >/dev/null 2>&1 || r2=$?; } && test "$r2" -eq 1 && sed 's|- \*\*Bound-in\*\*: CONTRIBUTING.md|- **Bound-in**: .shell-team/test-recipe.md|' "$B" > "$F/rel.md" && bash bin/check-playbook.sh "$F/rel.md" >/dev/null 2>&1 && sed 's|- \*\*Bound-in\*\*: CONTRIBUTING.md|- **Bound-in**: docs/no-such-file-t1007.md|' "$B" > "$F/ghost.md" && bash bin/check-playbook.sh "$F/ghost.md" >/dev/null 2>&1 && (cd "$F" && bash "$R/bin/check-playbook.sh" "$F/ghost.md" >/dev/null 2>&1); } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC5** **Supersession across scopes is directional.** A synthetic corpus
  exercising `loop → loop`, `maintainer → loop` and `maintainer → maintainer`
  validates green — the positive control, and `maintainer → loop` is the
  combination issue #23 requires. Repointing the retired *loop* entry at the
  active *maintainer* entry (one `sed`, which also repoints the retired
  maintainer entry at the maintainer target — a legal move) makes exactly that
  one entry a violation: exit 1, reason naming the crossing.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; emit(){ printf -- '%s\n' "$@"; }; { emit '# Lessons' '' '## 2026-01-01 — Retired loop entry' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: loop' '- **Status**: superseded' '- **Source**: n/a' '- **Rule**: R1.' '- **Why**: W1.' '- **How to apply**: H1.' '- **Superseded-by**: 2026-01-02 — Active loop entry' '' '## 2026-01-02 — Active loop entry' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: loop' '- **Status**: active' '- **Source**: n/a' '- **Rule**: R2.' '- **Why**: W2.' '- **How to apply**: H2.' '' '## 2026-01-03 — Retired maintainer entry' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: maintainer' '- **Bound-in**: CONTRIBUTING.md' '- **Status**: superseded' '- **Source**: n/a' '- **Rule**: R3.' '- **Why**: W3.' '- **How to apply**: H3.' '- **Superseded-by**: 2026-01-02 — Active loop entry' '' '## 2026-01-04 — Active maintainer entry' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: maintainer' '- **Bound-in**: CONTRIBUTING.md' '- **Status**: active' '- **Source**: n/a' '- **Rule**: R4.' '- **Why**: W4.' '- **How to apply**: H4.' '' '## 2026-01-05 — Retired maintainer entry two' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: maintainer' '- **Bound-in**: CONTRIBUTING.md' '- **Status**: superseded' '- **Source**: n/a' '- **Rule**: R5.' '- **Why**: W5.' '- **How to apply**: H5.' '- **Superseded-by**: 2026-01-04 — Active maintainer entry' > "$F/ok.md" && bash bin/check-playbook.sh "$F/ok.md" >/dev/null 2>&1 && sed 's|^- \*\*Superseded-by\*\*: 2026-01-02 — Active loop entry$|- **Superseded-by**: 2026-01-04 — Active maintainer entry|' "$F/ok.md" > "$F/bad.md" && r=0 && { bash bin/check-playbook.sh "$F/bad.md" >/dev/null 2>"$F/e" || r=$?; } && test "$r" -eq 1 && grep -qF 'Superseded-by crosses Scope' "$F/e" && test "$(grep -cF 'Superseded-by crosses Scope' "$F/e")" -eq 1; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC6** **Only `Scope: loop` entries reach a generated block, and the
  exclusion is by scope rather than by role.** Generating from the shipped
  fixture corpus (whose maintainer entry is `Applies-to: all` and `Status:
  active` — both asserted on the corpus first, so the exclusion cannot be
  passing for the wrong reason): the loop sentinel appears in all four blocks,
  the maintainer sentinel appears in none of them.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/tasks/loops" && : > "$F/repo/tasks/loops/shell-team.contract.yaml" && L="$F/repo/tasks/lessons.md" && grep -qF 'T1007-LOOP-SENTINEL' "$L" && grep -qF 'T1007-MAINTAINER-SENTINEL' "$L" && grep -B9 -F 'T1007-MAINTAINER-SENTINEL' "$L" | grep -qF -- '- **Applies-to**: all' && grep -B9 -F 'T1007-MAINTAINER-SENTINEL' "$L" | grep -qF -- '- **Status**: active' && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && P="$F/repo/templates/prompt-blocks" && grep -qF 'T1007-LOOP-SENTINEL' "$P/playbook-engineer.md" && grep -qF 'T1007-LOOP-SENTINEL' "$P/playbook-qa-verifier.md" && grep -qF 'T1007-LOOP-SENTINEL' "$P/playbook-tech-lead.md" && grep -qF 'T1007-LOOP-SENTINEL' "$P/playbook-pm-spec.md" && test "$(grep -cF 'T1007-MAINTAINER-SENTINEL' "$P/playbook-engineer.md")" -eq 0 && test "$(grep -cF 'T1007-MAINTAINER-SENTINEL' "$P/playbook-qa-verifier.md")" -eq 0 && test "$(grep -cF 'T1007-MAINTAINER-SENTINEL' "$P/playbook-tech-lead.md")" -eq 0 && test "$(grep -cF 'T1007-MAINTAINER-SENTINEL' "$P/playbook-pm-spec.md")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC7** **The generator stays fail-closed on a `Scope`-invalid corpus and
  writes nothing.** A clean run first proves the block file is produced (the
  anti-vacuity control); the file is then removed, the corpus' `Scope` values
  are replaced with `operator-global` — the token #23 routes *out* of the
  repository — and the rerun exits 1, names the unknown value, and leaves the
  block absent.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/tasks/loops" && : > "$F/repo/tasks/loops/shell-team.contract.yaml" && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && test -f "$F/repo/templates/prompt-blocks/playbook-engineer.md" && rm -f "$F/repo/templates/prompt-blocks/playbook-engineer.md" && sed 's|- \*\*Scope\*\*: loop|- **Scope**: operator-global|' "$F/repo/tasks/lessons.md" > "$F/t" && mv "$F/t" "$F/repo/tasks/lessons.md" && r=0 && { env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>"$F/e" || r=$?; } && test "$r" -eq 1 && grep -qF 'unknown Scope value' "$F/e" && test ! -e "$F/repo/templates/prompt-blocks/playbook-engineer.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC8** **A corpus with no `loop` entries at all produces the existing
  per-role fallback line, not an empty or crashed block.** A one-entry
  all-maintainer corpus generates successfully; all four blocks carry the
  fallback line and none carries the entry's sentinel.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; emit(){ printf -- '%s\n' "$@"; }; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/tasks/loops" && : > "$F/repo/tasks/loops/shell-team.contract.yaml" && emit '# Lessons' '' '## 2026-02-01 — Only a maintainer entry' '- **Category**: process' '- **Applies-to**: all' '- **Scope**: maintainer' '- **Bound-in**: CONTRIBUTING.md' '- **Status**: active' '- **Source**: n/a' '- **Rule**: T1007-ONLY-MAINTAINER-SENTINEL.' '- **Why**: W.' '- **How to apply**: H.' > "$F/repo/tasks/lessons.md" && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && P="$F/repo/templates/prompt-blocks" && grep -qF '(no active entries currently apply to this role)' "$P/playbook-engineer.md" && grep -qF '(no active entries currently apply to this role)' "$P/playbook-qa-verifier.md" && grep -qF '(no active entries currently apply to this role)' "$P/playbook-tech-lead.md" && grep -qF '(no active entries currently apply to this role)' "$P/playbook-pm-spec.md" && test "$(grep -cF 'T1007-ONLY-MAINTAINER-SENTINEL' "$P/playbook-engineer.md")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC9** **`--scope` is required on `bin/playbook-promote.sh`, with no
  default.** An otherwise-complete invocation omitting it exits 2, names the
  flag, and leaves the lessons file byte-identical.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { cp tests/playbook-promote/fixtures/lessons-base.md "$F/l.md" && cp "$F/l.md" "$F/orig.md" && r=0 && { bash bin/playbook-promote.sh --lessons "$F/l.md" --date 2099-07-01 --title 't1007 no scope' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>"$F/e" || r=$?; } && test "$r" -eq 2 && grep -qF 'missing required --scope' "$F/e" && cmp -s "$F/l.md" "$F/orig.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC10** **A promoted entry carries its scope, and its binding when it has
  one, and the result re-validates green.** `--scope loop` appends an entry
  carrying `- **Scope**: loop` and no `Bound-in`; `--scope maintainer --bound-in
  CONTRIBUTING.md` appends one carrying both bullets; the resulting file passes
  `bin/check-playbook.sh` (the positive control that the emitted layout is
  schema-valid, not merely present).
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { cp tests/playbook-promote/fixtures/lessons-base.md "$F/l.md" && bash bin/playbook-promote.sh --lessons "$F/l.md" --scope loop --date 2099-07-02 --title 't1007 loop entry' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R loop.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1 && grep -qF '## 2099-07-02 — t1007 loop entry' "$F/l.md" && grep -qF -- '- **Scope**: loop' "$F/l.md" && test "$(grep -cF -- '- **Bound-in**: ' "$F/l.md")" -eq 0 && bash bin/playbook-promote.sh --lessons "$F/l.md" --scope maintainer --bound-in CONTRIBUTING.md --date 2099-07-03 --title 't1007 maintainer entry' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R maint.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1 && grep -qF '## 2099-07-03 — t1007 maintainer entry' "$F/l.md" && grep -qF -- '- **Scope**: maintainer' "$F/l.md" && grep -qF -- '- **Bound-in**: CONTRIBUTING.md' "$F/l.md" && bash bin/check-playbook.sh "$F/l.md" >/dev/null 2>&1; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC11** **The schema is the single authority: promote rejects every
  invalid combination and appends nothing.** `--scope maintainer` without
  `--bound-in`, `--scope loop --bound-in …`, and `--scope not-a-scope` each exit
  1 and leave the file byte-identical to a pre-run copy.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1007.XXXXXX")"; ok=0; { cp tests/playbook-promote/fixtures/lessons-base.md "$F/l.md" && cp "$F/l.md" "$F/orig.md" && r1=0 && { bash bin/playbook-promote.sh --lessons "$F/l.md" --scope maintainer --date 2099-07-04 --title 't1007 unbound' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1 || r1=$?; } && test "$r1" -eq 1 && cmp -s "$F/l.md" "$F/orig.md" && r2=0 && { bash bin/playbook-promote.sh --lessons "$F/l.md" --scope loop --bound-in CONTRIBUTING.md --date 2099-07-05 --title 't1007 bound loop' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1 || r2=$?; } && test "$r2" -eq 1 && cmp -s "$F/l.md" "$F/orig.md" && r3=0 && { bash bin/playbook-promote.sh --lessons "$F/l.md" --scope not-a-scope --date 2099-07-06 --title 't1007 bad scope' --category process --applies-to all --status active --source 'T-1007 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1 || r3=$?; } && test "$r3" -eq 1 && cmp -s "$F/l.md" "$F/orig.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC12** **`--help` documents both new flags, inside the window it
  actually prints.** `bin/playbook-promote.sh --help` names `--scope`,
  `--bound-in` and the `loop | maintainer` enum. `--applies-to` is asserted in
  the same output as the positive control that the printed slice reaches the
  options block at all — today it does not, so this criterion is what forces the
  header window to be widened along with the new flags.
  - check: H="$(bash bin/playbook-promote.sh --help)"; printf '%s\n' "$H" | grep -qF -- '--scope' && printf '%s\n' "$H" | grep -qF -- '--bound-in' && printf '%s\n' "$H" | grep -qF -- '--applies-to' && printf '%s\n' "$H" | grep -qF 'loop | maintainer'

- [ ] **AC13** **The cross-suite `NOT_APPLY` pin is re-measured, not assumed,
  and the errexit-safe suite is green.** The registry entry for
  `bin/gen-playbook-blocks.sh`'s line-count warning names the line number that
  line actually has now, with the quoted source text after the second colon
  byte-identical to the real line, and `tests/errexit-safe/run.sh` exits 0.
  The line number is derived here rather than written down, so the criterion
  cannot go stale by construction. **Two-sided invariant lock: it holds before
  this task's edit and must still hold after it** — this exact class caused
  T-1006's QA FAIL round.
  - check: N="$(grep -n '"\$role" "\$line_count" "\$LINE_WARN_THRESHOLD"' bin/gen-playbook-blocks.sh | head -1 | cut -d: -f1)"; test -n "$N" && L="$(sed -n "${N}p" bin/gen-playbook-blocks.sh)" && test -n "$L" && grep -qF "gen-playbook-blocks.sh:${N}:${L}" tests/errexit-safe/run.sh && bash tests/errexit-safe/run.sh >/dev/null

- [ ] **AC14** **The three shipped suites are green and carry labelled cases for
  every new behaviour**, so CI keeps them after these criteria stop being run. A
  case that exists but is never reached would leave the lock vacuous, so the
  labels are pinned in the suites' own output.
  - check: r1=0; a="$(bash tests/check-playbook/run.sh 2>&1)" || r1=$?; r2=0; b="$(bash tests/gen-playbook-blocks/run.sh 2>&1)" || r2=$?; r3=0; c="$(bash tests/playbook-promote/run.sh 2>&1)" || r3=$?; test "$r1" -eq 0 && test "$r2" -eq 0 && test "$r3" -eq 0 && printf '%s\n' "$a" | grep -qF 'T-1007: a missing Scope field is rejected' && printf '%s\n' "$a" | grep -qF 'T-1007: an unknown Scope value is rejected' && printf '%s\n' "$a" | grep -qF 'T-1007: Bound-in is required on a maintainer entry' && printf '%s\n' "$a" | grep -qF 'T-1007: Bound-in is forbidden on a loop entry' && printf '%s\n' "$a" | grep -qF 'T-1007: a loop entry superseded by a maintainer entry is rejected' && printf '%s\n' "$a" | grep -qF 'T-1007: a maintainer entry superseded by a loop entry is accepted' && printf '%s\n' "$b" | grep -qF 'T-1007: maintainer-scoped entries never reach a generated block' && printf '%s\n' "$b" | grep -qF 'T-1007: an all-maintainer corpus yields the no-entries fallback' && printf '%s\n' "$c" | grep -qF 'T-1007: --scope is required' && printf '%s\n' "$c" | grep -qF 'T-1007: an invalid Scope/Bound-in combination appends nothing'

- [ ] **AC15** **Zero prompt-block churn: the shipped blocks and their consumers
  are byte-unchanged, and the sync checker is green.** Nothing under
  `templates/`, `agents/`, `skills/`, `docs/`, either README or the root
  `CLAUDE.md` differs from the base ref; all four canonical blocks still exist
  and are non-empty (the anti-vacuity control — "no diff" must not be satisfiable
  by deleting them); `bin/check-prompt-sync.sh` passes. **Merge-point-scoped
  against `72b6e8b` and expected to go stale after merge** — do not widen its
  base-ref resolution or re-derive it per rework round.
  - check: test "$(git diff --name-only 72b6e8b -- templates/ agents/ skills/ docs/ README.md README.ja.md CLAUDE.md | wc -l | tr -d ' ')" -eq 0 && test -s templates/prompt-blocks/playbook-engineer.md && test -s templates/prompt-blocks/playbook-qa-verifier.md && test -s templates/prompt-blocks/playbook-tech-lead.md && test -s templates/prompt-blocks/playbook-pm-spec.md && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC16** **The diff is confined to this task's allow-list.** Every changed
  path is on the list below and the diff is non-empty. The three fixture
  directories are admitted by prefix (a new fixture file is a legitimate way to
  cover a new schema rule); everything else is an exact path.
  `tests/errexit-safe/run.sh` is on the list **from the start**, because AC13's
  pin is mechanically forced to move by the generator edit — the class that cost
  T-1006 a rework round and a re-freeze. **Merge-point-scoped against `72b6e8b`
  and expected to go stale after merge**; do not widen or re-derive it.
  - check: L="$(git diff --name-only 72b6e8b)"; test -n "$L" && test "$(printf '%s\n' "$L" | grep -vcE '^(bin/check-playbook\.sh|bin/gen-playbook-blocks\.sh|bin/playbook-promote\.sh|tests/check-playbook/run\.sh|tests/check-playbook/fixtures/.+|tests/gen-playbook-blocks/run\.sh|tests/gen-playbook-blocks/fixtures/.+|tests/playbook-promote/run\.sh|tests/playbook-promote/fixtures/.+|tests/errexit-safe/run\.sh|\.shell-team/test-recipe\.md|\.shell-team/todo\.md|\.shell-team/specs/T-1007-scope-typed-ledger\.md|\.shell-team/provenance/T-1007\.md|\.shell-team/reviews/T-1007\.md|\.shell-team/interventions/T-1007\.md)$')" -eq 0

- [ ] **AC17** **No new `bin/` file, exactly the three intended ones changed, and
  `bin/` stays pure bash and shellcheck-clean.** No file is added under `bin/`
  against the base ref, exactly three are modified (pinned both directions), the
  seven touched scripts are shellcheck-clean on the version CI pins, and no new
  runtime (`jq`, `yq`, `python`, `perl`, `node`, `ruby`) appears in the three
  changed scripts. **The count of three is merge-point-scoped** and expected to
  go stale after merge.
  - check: test "$(git diff --name-only --diff-filter=A 72b6e8b -- bin/ | wc -l | tr -d ' ')" -eq 0 && test "$(git diff --name-only 72b6e8b -- bin/ | wc -l | tr -d ' ')" -eq 3 && shellcheck bin/check-playbook.sh bin/gen-playbook-blocks.sh bin/playbook-promote.sh tests/check-playbook/run.sh tests/gen-playbook-blocks/run.sh tests/playbook-promote/run.sh tests/errexit-safe/run.sh && test "$(grep -rnE -- '(^|[^a-z])(jq|yq|python3?|perl|node|ruby)([^a-z]|$)' bin/check-playbook.sh bin/gen-playbook-blocks.sh bin/playbook-promote.sh | wc -l | tr -d ' ')" -eq 0

- [ ] **AC18** **The fixture hazard is written down where the next engineer will
  read it.** `.shell-team/test-recipe.md` gains a T-1007 entry naming all three
  fixture corpora and the fact that a fixture entry without a `Scope` bullet now
  turns its suite red. The pre-existing T-1006 entry is the positive control that
  the file was appended to rather than replaced.
  - check: grep -qF 'T-1007' .shell-team/test-recipe.md && grep -qF 'T-1006' .shell-team/test-recipe.md && grep -qF 'tests/check-playbook/fixtures/valid-base.md' .shell-team/test-recipe.md && grep -qF 'tests/gen-playbook-blocks/fixtures/root/tasks/lessons.md' .shell-team/test-recipe.md && grep -qF 'tests/playbook-promote/fixtures/lessons-base.md' .shell-team/test-recipe.md

- [ ] **AC19** **Zero corpus.** The resolver still names `.shell-team/lessons.md`
  (the positive control that it resolved anything at all), nothing exists at that
  path — not as a file and not as a dangling symlink — and no corpus file entered
  the diff. **Scoped to the pre-T-1008 tree and expected to go stale the moment
  the corpus lands**; it is not to be widened or re-derived to stay evergreen.
  - check: P="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)"; test -n "$P" && test "$P" = ".shell-team/lessons.md" && test ! -e "$P" && test ! -L "$P" && test "$(git diff --name-only 72b6e8b -- .shell-team/lessons.md | wc -l | tr -d ' ')" -eq 0

## Input space

**Reachable input classes** — what real usage produces, and what this change
must therefore be correct about.

1. **An all-`loop` corpus.** Every entry ships; the generated blocks are exactly
   what they would be without a `Scope` field at all. The three shipped fixture
   corpora after annotation are the concrete instances.
2. **A mixed corpus** — `loop` and `maintainer` entries interleaved, maintainer
   entries carrying `Bound-in` pointers at `CONTRIBUTING.md` and
   `.shell-team/test-recipe.md`. This is what T-1008's import produces: ~30% of
   its active entries are maintainer-scoped by #23's own measurement.
3. **An all-`maintainer` corpus**, and a corpus where one *role* has no `loop`
   entries. Reachable during T-1008's import and whenever a role's entries are
   all retired; the per-role fallback line must appear.
4. **A half-annotated corpus** — entries missing `Scope`, carrying an empty or
   whitespace-only `Scope`, or carrying a value from #23's routing table that is
   not a `Scope` value (`operator-global`, `drop`). This is the literal state of
   T-1008's working tree mid-import and is the primary class the fail-closed
   rule protects.
5. **Mis-scoped bindings** — a `maintainer` entry with no `Bound-in`, a `loop`
   entry carrying one, a `Bound-in` whose value is blank after trimming, and a
   `Bound-in` written as an absolute or `~`-prefixed path (the shape a copied
   local path takes, and one `bin/check-pii-shapes.sh` independently dislikes).
6. **All four supersession combinations across scopes**, including a forward
   reference (the target defined later in the file) and the existing dangling /
   self-reference / chained cases, which must keep behaving exactly as they do
   today.
7. **`bin/playbook-promote.sh` invocations**: `--scope` omitted, valid, invalid,
   and with surrounding whitespace (the existing `trim` applies to it like every
   other field); `--bound-in` supplied and omitted under each scope value.
8. **Values carrying the pre-existing structural hazards** — a literal tab, a
   non-tab control character, or a reserved `<!-- BEGIN prompt-block:` /
   `<!-- END prompt-block:` marker string inside a `Scope` or `Bound-in` value.
   The two new fields get the same `check_structural` treatment as every other
   field value, for the same reason: a value that corrupts a marker boundary is
   dangerous wherever it lives.
9. **The same corpus validated from different working directories and through
   both relative and absolute paths.** Real instance, not synthetic:
   `bin/playbook-promote.sh` validates a temp candidate copy under `$TMPDIR`,
   and `bin/gen-playbook-blocks.sh` validates a corpus under an arbitrary
   `--root`.
10. **This repository as it stands** — no corpus at the resolved lessons path,
    so both consumers still exit 2 on a bare invocation, exactly as T-1006 left
    them.

**Out-of-scope synthetic extremes** — named and declined.

1. **A third `Scope` value, per-role scope values, or scope inheritance between
   entries.** DP-c pins the enum at exactly two tokens; anything else is a spec
   change, not an input to handle.
2. **Filesystem semantics for `Bound-in`**: whether the named file exists, is
   readable, is a directory, is a symlink, or matches a glob. The checker never
   reads the tree (DP-d). A `Bound-in` naming a file that has since been deleted
   is a stale pointer — #23's own "Known limitation, accepted" already declares
   that `Bound-in` improves discovery and does not solve staleness.
3. **URLs, `..` traversal, Windows separators, and adversarially long values in
   `Bound-in`.** The shape check is deliberately shallow — non-empty, not
   absolute, not `~`-prefixed — and this criterion set does not claim more than
   that.
4. **Two `Bound-in` bullets on one entry, or a comma list of several bound
   files.** Duplicate field bullets are a pre-existing repository-wide behaviour
   (the last one wins, for every field), not a class this task introduces or
   changes.
5. **Corpora with NUL bytes, CRLF endings, unterminated fences, non-UTF-8 bytes
   or forged headings.** `bin/check-playbook.sh`'s declared surface, already
   covered by its own suite and untouched here.
6. **Cross-file scope or supersession resolution.** Scope, like every other
   reference check, is resolved strictly per file (T-108 DP-7, unchanged).
7. **Concurrent promotions racing on one corpus.** Not introduced by this change.
8. **Migrating an adopter corpus that already carries a differently-named scope
   field.** #23 measured that no adopter corpus exists, which is precisely why
   the field can be made required with no migration path.
9. **Prompt-block size, ordering or line-count policy under scoping.**
   `LINE_WARN_THRESHOLD` is untouched; a smaller shipped set is a consequence,
   not a criterion.

<!-- END intent-block: T-1007 -->

## Resolved design decisions

### DP-a — `Bound-in` is mandatory on `maintainer` and forbidden on `loop`

**Mandatory on `maintainer`, fail-closed.** An optional pointer restores exactly
the property the D plan refuted: the binding becomes a convention that nothing
enforces, and a maintainer entry with no pointer is indistinguishable from one
whose author simply forgot where it was bound. #23's known-limitation note
already concedes that `Bound-in` does not propagate retirement; that concession
is only defensible if the pointer is always there to be read.

**Forbidden on `loop`, fail-closed.** Considered and rejected: tolerating it as
harmless. A `Bound-in` on a shipped entry has no meaning — the entry's
destination is the prompt block, not a repo-local file — so its presence is the
signature of an entry the author scoped wrongly (they were thinking "this lives
in CONTRIBUTING.md" while typing `loop`). Catching that is worth more than
tolerating a field nobody reads. This mirrors the existing asymmetry the
repository already ships: an `active` entry may not carry `Superseded-by`
(`bin/check-playbook.sh:658`), tested by **field presence**, not by value
emptiness — the T-108 round-1 Major. The same distinction applies here: the
`maintainer` rule tests the **trimmed value** (absent and blank are the same
violation), the `loop` rule tests **presence** (a blank bullet is still a
bullet).

If T-1008's import turns up a genuine `loop` entry that needs a repo-local
pointer, that is a ratified intent change with a re-freeze, not a silent
loosening.

### DP-b — supersession across scopes is **directional**, not symmetric

This modifies the tech-lead's recommendation, on the authority of the canonical
issue body. The recommendation was "a `Superseded-by` target must share the
superseded entry's `Scope`". #23's argument for a single file is:

> Splitting into two files … would make a local lesson that generalises unable
> to name its universal replacement — an un-retirable class.

A local lesson that generalises is exactly a `maintainer` entry superseded by a
`loop` one. A symmetric rule would forbid the case the one-file design exists to
support.

The real hazard is the other direction, and only that one. A `Scope: loop` entry
retired in favour of a `Scope: maintainer` replacement leaves the reference
graph perfectly healthy — target exists, target is active, no chain, no
self-reference — while the shipped block silently loses a rule and gains
nothing. So:

| Superseded entry | Target | Verdict |
|---|---|---|
| `loop` | `loop` | allowed — a shipped rule replaced by a shipped rule |
| `maintainer` | `maintainer` | allowed |
| `maintainer` | `loop` | allowed — #23's un-retirable class, the reason for one file |
| `loop` | `maintainer` | **rejected fail-closed** — a shipped rule vanishes with nothing replacing it |

The rule to state in one line: **a shipped rule may only be retired in favour of
another shipped rule.** It belongs in the existing pass 2 (`:619-691`), beside
the dangling / self-reference / chain checks, which means `finalize_entry()`
gains one more parallel array and every push must stay index-aligned.

### DP-c — the enum is exactly `loop | maintainer`

#23's routing table has four outcomes; two of them (`operator-global`, `drop`)
describe knowledge that never enters this repository, so they need no token. An
`all` value was considered and rejected for a second reason beyond redundancy:
`Applies-to` already has an `all` token meaning "all four IN roles", and a second
`all` with a different meaning in an adjacent field is the kind of collision that
reads fine and is understood wrongly.

### DP-d — `Bound-in` is validated by shape, never against the filesystem

Existence-checking was considered and **rejected**, for a reason stronger than
cost. `bin/check-playbook.sh` takes a file path argument and has no concept of a
repository root: a relative `Bound-in` would have to resolve against *something*,
and every candidate is wrong. Against the corpus' own directory — the corpus is
a temp copy under `$TMPDIR` whenever `bin/playbook-promote.sh` re-validates a
candidate. Against the process' cwd — the verdict then changes depending on where
the checker was invoked from, which is the one property a validator must not
have, and `bin/gen-playbook-blocks.sh` invokes it with an arbitrary `--root`.
Against a discovered git root — that is a new dependency and a new failure mode
in a checker that today does nothing but read one file.

So the checker validates: non-empty after trimming, not beginning with `/`, not
beginning with `~`, plus the structural checks (`check_structural`) every other
field value gets. AC4 pins the boundary in the honest direction: a `Bound-in`
naming a file that does not exist validates **green**, and the same corpus gets
the same verdict from two different working directories. That is what makes the
absence of filesystem access a tested property rather than an unstated one.

The residual risk is stated rather than hidden: this is a **shape check, not a
validity check**. It cannot tell a correct pointer from a plausible-looking wrong
one. The defence against a wrong pointer is the human approval step in the
promotion path and normal review — the same "防衛の主従" split
`bin/playbook-promote.sh:26-32` already documents for content.

### DP-e — `--scope` is required; the schema stays the single authority

`--scope` joins the existing required-field loop
(`bin/playbook-promote.sh:188-193`), so an omission dies with
`missing required --scope` and exit 2, the same shape as every other missing
flag. No default: a default silently classifies, which is the defect at the root
of #23.

`--bound-in` is optional at the CLI level and passed through into the emitted
entry. The `Scope` × `Bound-in` combination rules are **not** re-implemented in
the promoter. It builds the candidate, appends it to a temp copy, and runs
`bin/check-playbook.sh` over it — the existing fail-closed re-validation
(`:285-295`) — so an invalid combination is rejected with exit 1 and the real
file byte-untouched. One authority for the schema, no second copy to drift. This
also keeps the script's documented exit-code split intact: exit 2 is a malformed
invocation, exit 1 is a schema-invalid candidate (`:47-62`). The one deliberate
exception in that file — `--title`'s early structural check — is not extended
here, because neither new value is spliced into a line before the temp file
exists.

The emitted bullet order (`Scope` immediately after `Applies-to`, `Bound-in`
immediately after `Scope`) is a formatting contract, not a schema rule: the
checker matches field bullets per line and does not care. It is pinned so the
diff of a promotion is deterministic and the criteria can grep for it.

### DP-f — the enforcement goes into `bin/check-playbook.sh`, not a new checker

Carried from the tech-lead's measurement and restated here because it is the
load-bearing structural decision. A separate scope-checker would have to be
invoked by every path that reads the ledger, and nothing would stop one of them
forgetting — which is the "boundary as a convention" failure the D plan
refuted. It would also mean a new `bin/` file, a new entry in the CI shellcheck
argument list, and a new set of errexit-safe candidate sites. Everything lands
in the three scripts that already exist.

## Measured inventory (verified against the tree at `72b6e8b`; re-verify before editing)

| Site | What it is | Disposition |
|---|---|---|
| `bin/check-playbook.sh:2-140` | header schema documentation | document `Scope` (required, closed enum) and `Bound-in` (conditional) |
| `bin/check-playbook.sh:166` | `KNOWN_FIELD_NAMES` — 9 names | add `Scope`, `Bound-in` |
| `bin/check-playbook.sh:148-150` | `KNOWN_*` enum lists | add a `KNOWN_SCOPES`-style list |
| `bin/check-playbook.sh:339-343` | per-entry `seen_*` / `val_*` reset | add scope + bound-in, both seen and value |
| `bin/check-playbook.sh:367-436` | `finalize_entry()` | required-field + enum checks; push the scope array |
| `bin/check-playbook.sh:365` | the five parallel `ENTRY_*` arrays | a sixth, index-aligned |
| `bin/check-playbook.sh:553-606` | the field-bullet `elif` chain | two new arms **above** the catch-all, each calling `check_structural` |
| `bin/check-playbook.sh:619-691` | pass 2, reference resolution | add the DP-b directional check |
| `bin/gen-playbook-blocks.sh:271-283` | the `\x1f` record shape and `emit_record` | one more field |
| `bin/gen-playbook-blocks.sh:330-336` | pass-1 field capture | capture `Scope` |
| `bin/gen-playbook-blocks.sh:432-434` | pass-2 filter loop | the `read -r` variable list **and** the `Scope: loop` filter |
| `bin/gen-playbook-blocks.sh:447-449` | the line-count warning | untouched, but its **line number moves** — AC13 |
| `bin/playbook-promote.sh:64-89` | Usage / options header | document both flags |
| `bin/playbook-promote.sh:145-171` | argument parsing | `--scope`, `--bound-in` |
| `bin/playbook-promote.sh:166` | `--help` window `sed -n '2,45p'` | widen far enough to print the options block (AC12) |
| `bin/playbook-promote.sh:178-193` | trim + required-field loop | `--scope` joins it; `--bound-in` is trimmed but optional |
| `bin/playbook-promote.sh:252-259` | single-line check loop | both new values join it |
| `bin/playbook-promote.sh:266-275` | entry construction | emit `Scope` after `Applies-to`; emit `Bound-in` only when supplied |
| `tests/errexit-safe/run.sh:313` | `gen-playbook-blocks.sh:449:<content>` pin | re-measure the line number, content byte-identical |
| `tests/check-playbook/fixtures/valid-base.md` | fixture corpus | annotate + one maintainer entry |
| `tests/gen-playbook-blocks/fixtures/root/tasks/lessons.md` | fixture corpus | annotate + sentinels + one maintainer entry |
| `tests/playbook-promote/fixtures/lessons-base.md` | fixture corpus | annotate |
| `.github/workflows/check-handoff.yml:29` | shellcheck argument list | **no change** — all three scripts and all four suites are already listed (measured) |
| `agents/scrum-master.md:52` | `[common]` / `[target-specific]` retro vocabulary | deferred to T-1008 (#57 already touches this file) |
| `templates/prompt-blocks/playbook-*.md` | shipped blocks | byte-unchanged (AC15) |

## Body-to-AC correspondence

| Body directive | Promoted to |
|---|---|
| `Scope` is required on every entry, fail-closed on absence | AC1, AC14 |
| The `Scope` enum is closed at exactly `loop \| maintainer`; no default | AC1, AC7 (`operator-global` rejected), AC9 (no default at the CLI) |
| An empty / whitespace-only `Scope` is a violation | AC1 |
| `Scope` and `Bound-in` are registered field names | AC2 |
| The unknown-bullet catch-all still fires for anything else | AC2 |
| Only `Scope: loop` entries reach a generated block | AC6 |
| `Scope` decides whether an entry ships, `Applies-to` where | AC6 (the excluded entry is `Applies-to: all`) |
| A role with no `loop` entries gets the existing fallback line | AC8 |
| `Bound-in` is mandatory on `maintainer` (value-tested) | AC3, AC11 |
| `Bound-in` is forbidden on `loop` (presence-tested) | AC3, AC11 |
| `Bound-in` is shape-validated: non-empty, not absolute, not `~` | AC4 |
| The checker never reads the filesystem; the verdict is cwd-independent | AC4 |
| `loop` superseded by `maintainer` is rejected | AC5, AC14 |
| `loop→loop`, `maintainer→maintainer`, `maintainer→loop` stay legal | AC5, AC14 |
| `--scope` is required with no default | AC9 |
| `--bound-in` is passed through into the entry | AC10 |
| The promoted entry re-validates green | AC10 |
| Promote does not re-implement the rule; the schema is the single authority | AC11 (all three invalid combinations rejected at exit 1, the re-validation's code, not exit 2) |
| `--help` documents both flags | AC12 |
| The generator stays fail-closed and writes nothing on an invalid corpus | AC7 |
| Existing suites stay green; new behaviour is locked in them | AC14 |
| Zero prompt-block churn; blocks and consumers byte-unchanged | AC15 |
| No `agents/`, `skills/`, `docs/`, `templates/`, root `CLAUDE.md` edit | AC15, AC16 |
| The errexit-safe pin is re-measured and the suite green | AC13 |
| Everything lands in the three existing scripts; no new `bin/` file | AC17 |
| Pure bash, zero-dependency, shellcheck-clean | AC17 |
| The fixture hazard is recorded for the next engineer | AC18 |
| Zero corpus; nothing at the resolved lessons path | AC19 |
| No CI provenance / regen-diff step | AC16 (the workflow is not on the allow-list, so adding a step fails the criterion) |
| #57 / #58 are not fixed here | AC15, AC16 (both would require files outside the allow-list) |
| `LINE_WARN_THRESHOLD` is unchanged | info-only (not promoted to AC) — AC13 pins the warning line's **content** byte-identical through the re-measurement, so a threshold or message edit breaks it; a dedicated criterion would restate that |
| The nine pre-existing fields, the fence grammar, the NUL scan, the calendar check and the existing `Superseded-by` checks are untouched | info-only (not promoted to AC) — `tests/check-playbook/run.sh`'s ~60 existing cases are the regression surface for exactly this, and AC14 requires that suite green; a new criterion would be a worse copy of it |
| The emitted bullet order (`Scope` after `Applies-to`, `Bound-in` after `Scope`) | info-only (not promoted to AC) — a formatting contract the checker is indifferent to; AC10 pins that both bullets are emitted and that the result is schema-valid, which is the property that matters |
| Duplicate-field behaviour (last wins) is unchanged | info-only (not promoted to AC) — pre-existing repository-wide behaviour, declined in the Input space rather than newly specified here |

## Assumptions

- **Base ref `72b6e8b`.** Every line number in the inventory was read there. If
  the branch is rebased, re-verify before editing — line numbers are
  convenience, file contents are the contract. AC15, AC16, AC17 and AC19 all pin
  against that ref and are expected to go stale after merge.
- **The em dash in every heading literal is U+2014**, the same character
  `bin/playbook-promote.sh:267` writes and `bin/check-playbook.sh:479` parses.
  AC5's `emit` corpus, AC5's `sed` pattern and AC10's heading greps all depend
  on it. **Unverified by pm-spec (no shell in this role) — flagged for the
  executing side.**
- **`shellcheck` is available** to the executing side; CI pins 0.11.0. AC17
  fails loudly rather than soft-skipping, deliberately.
- **`grep -B` is available** on the host (used by AC6 to read the fixture entry
  above a sentinel). POSIX-optional but present in both GNU and BSD grep.
- **`check-acs.sh`'s 120s per-check cap applies.** AC14 runs three suites in one
  criterion; if it exceeds the cap on a slow host, raise `CHECK_ACS_TIMEOUT` for
  the run rather than splitting the criterion.
- **T-1008 lands after this task** and owns the corpus, the CI provenance step,
  the agent-prose updates and #57/#58. If that ordering changes, AC15, AC16 and
  AC19 are the criteria to revisit first.
- **AC16 sees tracked changes only.** `git diff --name-only` does not report
  untracked files, so a path enters the criterion once staged or committed —
  including this spec. The criterion's job is to forbid out-of-scope *edits*,
  not to inventory scratch files.
- **No adopter corpus exists**, per #23's measurement. That is what makes a
  required field free of a migration path, and it is the assumption that would
  have to be revisited if an adopter reported one.

## Open questions

None blocking. DP-b modifies the tech-lead's recommendation on the authority of
the canonical issue text quoted in that section; if the executing side reads #23
differently, that is the one decision to re-open before implementation rather
than after.

## Notes for engineer

**Build order.** The first two steps are one commit, not two — there is no green
intermediate state, for the same reason this task exists at all: the catch-all
rejects a `Scope:` bullet the checker does not know, and the required-field
check rejects a fixture that has none.

1. `bin/check-playbook.sh` (both field arms, the enum, the two `Bound-in` rules,
   the DP-b pass-2 check) **plus** all three fixture corpora, in one commit.
2. `tests/check-playbook/run.sh` — the six labelled cases AC14 pins.
3. `bin/gen-playbook-blocks.sh` — record arity, capture, filter — plus
   `tests/gen-playbook-blocks/run.sh`'s two labelled cases.
4. Re-measure and re-pin `tests/errexit-safe/run.sh` (see hazard 2), and run
   that suite before moving on.
5. `bin/playbook-promote.sh` (flags, help window, entry construction) plus its
   suite's two labelled cases.
6. `.shell-team/test-recipe.md`.

**The four hazards, in order of what they will cost you.**

1. **The `\x1f` record arity in `bin/gen-playbook-blocks.sh`.** `emit_record`'s
   `printf` (`:282`) and the pass-2 `while IFS="$FS" read -r …` (`:432`) are two
   halves of one contract. Add a field to one and not the other and every field
   after the insertion point shifts by one — silently, into a generated prompt.
   Insert the new field at a fixed position in both, and prove it with AC6 before
   trusting anything else.
2. **`tests/errexit-safe/run.sh:313` pins `gen-playbook-blocks.sh:449:<content>`
   by file:line:content.** Your edits land above line 449, so the pin goes stale
   the moment you touch the generator, and the suite fails in CI's list even
   though the five suites you are watching are green. **Re-measure the line
   number** — `grep -n '"$role" "$line_count" "$LINE_WARN_THRESHOLD"'
   bin/gen-playbook-blocks.sh` — rather than trusting any number written down,
   including the one in this spec. Change only the line-number token; the quoted
   source text after the second colon must stay byte-identical. This exact class
   cost T-1006 a QA FAIL round and a ratified re-freeze; `tests/errexit-safe/run.sh`
   is on AC16's allow-list from the start so that fixing it needs no re-freeze
   here.
3. **The parallel `ENTRY_*` arrays** (`bin/check-playbook.sh:365`, pushed at
   `:431-435`). Pass 2 indexes five arrays positionally; a sixth must be pushed
   on exactly the same path, unconditionally, or a later entry's scope reads as
   an earlier entry's.
4. **`bin/playbook-promote.sh --help` prints `sed -n '2,45p'`** of its own
   header, which today stops inside the NOTE block and never reaches the options
   list. A required flag documented outside the printed window is a defect this
   task would be creating, so widening the window is in scope and AC12 forces it.

**Mutation self-check before hand-off** — run each, watch the named criterion go
red, restore from a pre-mutation file copy (never `git checkout`), verify
byte-identical with `diff`, and watch it go green again:

1. Drop the `Scope` required-field check → AC1 red.
2. Add a third accepted `Scope` token → AC1 red.
3. Test `Bound-in` presence instead of its trimmed value on a `maintainer` entry
   → AC3's whitespace probe red.
4. Drop the `loop`-forbids-`Bound-in` rule → AC3's third probe red.
5. Remove the DP-b check → AC5 red.
6. Invert DP-b to reject `maintainer → loop` → AC5's positive control red.
7. Remove the `Scope: loop` filter in the generator → AC6 red (the maintainer
   sentinel appears in all four blocks).
8. Give `--scope` a default → AC9 red.
9. Revert the errexit-safe pin to its old line number → AC13 red.

Beyond the list: this is a validator-extension task, the class this repository
has repeatedly measured as multi-round. Before hand-off, ask what your own
detector is blind to — does the `Bound-in` rule fire on the entry that carries
the bullet or on whichever entry was open at the time? does the scope filter run
before or after the `Status: active` filter, and does either order let something
through? does a `Scope` bullet inside a fenced example still get ignored? — and
write at least one mutation of your own that attacks the answer.

**Prior art.** `bin/check-playbook.sh:658` (the `active` × `Superseded-by`
presence rule DP-a mirrors), `:662-687` (the pass-2 resolution loop DP-b
extends), `:592-605` (the catch-all that forces the ordering),
`bin/playbook-promote.sh:285-295` (the fail-closed re-validation DP-e leans on),
`tests/check-playbook/run.sh:745-763` (the T-108 unknown-bullet cases whose shape
AC2 mirrors), and T-1006's board entry for what a stale cross-suite pin costs.
