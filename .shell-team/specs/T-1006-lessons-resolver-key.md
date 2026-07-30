# T-1006 — the lessons file is resolved through `team-paths.sh`, not hardcoded to the legacy layout

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1006
**Source**: GitHub issue #24. No new issue was opened: #24 already carries the decided shape, the two reasons it became a prerequisite for #23, and is the tracker.
**Branch**: `feature/lessons-resolver-key` (from `develop` at `d691a6f`).

## Problem

`CLAUDE.md` §Working rules requires every operating path to be resolved through
`bin/team-paths.sh`. The lessons file is an operating path and is the one
exception: `bin/gen-playbook-blocks.sh:93` sets `LESSONS="$ROOT/tasks/lessons.md"`
and `bin/playbook-promote.sh:226` sets `LESSONS="tasks/lessons.md"`. That default
is the *legacy* layout, so on the shipped default layout — including this
repository — the no-argument invocation points at a directory that does not
exist:

```
$ bash bin/gen-playbook-blocks.sh
gen-playbook-blocks: lessons file not found: ./tasks/lessons.md      # rc=2
```

Two consequences make this a prerequisite for #23 rather than a cosmetic
cleanup. The documented no-argument command is broken on this layout, so the
first person to run it after a corpus lands hits an error; and pinning the
canonical corpus path in CI (`check-playbook.sh "$(team-paths.sh --get lessons)"`)
is impossible without the key, while naming the path literally in the workflow is
exactly the hardcode the rule forbids.

A third consumer the issue does not name compounds it: `bin/retro-inputs.sh`
ships four statements asserting that no resolver key exists for the lessons log
(`:128-129` help, `:453-454` design comment, `:460` runtime ledger detail, plus
the header's framing at `:7-10` that the script "resolves every artefact path
through `bin/team-paths.sh`"). Adding the key without touching them ships
statements that are false the moment they are read.

## Goal

<!-- BEGIN intent-block: T-1006 -->

**`bin/team-paths.sh` registers a tenth key, `lessons`.** It follows the same
precedence rule as every other key: `<base>/lessons.md` under the default layout
and under a `$TEAM_RUN_BASE` override, and `tasks/lessons.md` when the legacy
marker (`tasks/loops/shell-team.contract.yaml`) is present. The canonical path on
the shipped default layout is therefore `.shell-team/lessons.md`. Resolution is
path-only: it never creates the file and it succeeds when the file is absent.

**Both playbook consumers derive their default from the resolver.**
`bin/gen-playbook-blocks.sh` and `bin/playbook-promote.sh` stop carrying a
hardcoded legacy default. `--lessons PATH` remains an override on both, and it
short-circuits the resolver entirely — an explicit path must keep working in a
repository whose `$TEAM_RUN_BASE` is invalid.

**Both consumers are fail-closed on the resolver.** The resolver's exit status is
captured and checked, and a resolved path that is empty is rejected with the same
error rather than being concatenated into `<root>/` — which is a *directory*, for
which `[ -r ]` is true, so an unchecked empty value would silently pass a
readability gate and generate from nothing.

**No statement shipped under `bin/` asserts that the key does not exist, and no
script under `bin/` carries a hardcoded lessons default.** That is the one
forbidden outcome of this task. `bin/retro-inputs.sh`'s observable behaviour is
deliberately unchanged — the lessons line stays flag-supplied, and its ledger
status without `--lessons` stays `unavailable` — but its statements are corrected
to say that this is a choice rather than an absence.

**No adopter has to move a file.** A checkout carrying `tasks/lessons.md` with
the legacy marker keeps resolving to it. `bin/team-init.sh` still scaffolds no
lessons file: the corpus is optional for adopters, and an empty placeholder would
be worse than none.

**The new key's coverage matches the existing keys', including the legacy path,
and the suite's own total-key lock moves 9 → 10 in all three of its counting
sites.** `tests/team-paths/run.sh` currently uses the token `lessons` itself as
the negative control for "an unregistered key exits 2"; that control is swapped
to a token that is not, and will not become, a registered key. Leaving either
half undone turns the lock vacuous, which is the one way this task can silently
weaken the thing it extends.

## Non-goals

- **No prompt-block regeneration and no pointer-string swap.**
  `bin/gen-playbook-blocks.sh` splices the resolved path into every generated
  line, so a default change would rewrite `templates/prompt-blocks/playbook-*.md`
  wholesale. #23 regenerates all four blocks from the imported corpus, so the
  pointer change is free there and a churn-only diff here.
  `templates/prompt-blocks/` is untouched and pinned so by a criterion.
- **No corpus.** Nothing is created at `.shell-team/lessons.md`, and no existing
  corpus is imported, migrated or moved. This task ships the *resolution* of that
  path; #23 ships the file.
- **No CI pin of the corpus.** The `check-playbook.sh "$(… --get lessons)"` step
  is #23's, and cannot exist before the corpus does. This task adds exactly one
  resolver-level assertion to the workflow's existing dogfood step, which
  requires no file to exist.
- **No lessons scaffold in `bin/team-init.sh`** — rejected in the issue, and
  locked by a negative criterion so the rejection is verifiable rather than
  merely stated.
- **No `agents/*.md` or `skills/*` edit.** `agents/scrum-master.md:45` carries the
  clause `there is no resolver key for it`, which this task makes false. It is
  deliberately **deferred, not overlooked**: it is agent prose (assigned
  elsewhere by this task's routing), the file is a `contain`-mode consumer of two
  canonical prompt blocks, and T-1003's frozen AC16 pins its numbered items at
  eighteen — so an edit there carries a different task's risk profile. The
  deferral is made verifiable: the file is pinned byte-unchanged, the board entry
  names the exact clause, and a fast-follow issue is filed at the recording step.
  `skills/review-response/SKILL.md`'s `tasks/lessons.md` pointer is a prose
  pointer of the same class #23 rewrites.
- **No switch of `bin/retro-inputs.sh` to the resolver** (DP-1). Behaviour is
  unchanged; only its false statements are corrected. Switching it would drag in
  the DS-5/DS-6 determination semantics, `templates/prompt-blocks/retro-inputs.md`
  and `tests/retro-inputs/run.sh`, all of which belong with #23's retro side.
- **No new flag on either consumer**, in particular no `--root` on
  `bin/playbook-promote.sh`: it resolves against the current working directory
  today and must keep doing exactly that.
- **No change to `bin/check-playbook.sh`.** It takes an explicit path argument and
  has no default to correct.
- **No adopter-facing documentation change.** No file under `docs/`, no `README*`,
  and no `templates/` file enumerates the resolver's key set (measured: the only
  three enumerations in the repository are inside `bin/team-paths.sh` itself), so
  the key can be added without a documentation edit falling out of it.
- **No repair of two pre-existing `--help` window warts.** `--help` in both
  consumers prints a fixed `sed -n '2,45p'` slice of its own header, which today
  truncates before `--blocks-dir` (gen) and before the whole Usage block
  (promote). Widening the gen window is *permitted* where the corrected
  `--lessons` text needs the room; neither wart is this task's to fix.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup, and
invokes scripts as `bash bin/<script>.sh` or `bash tests/<suite>/run.sh`.

Five standing rules apply to every criterion below:

- **No negated `grep` without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` cannot be read, because `grep` exits 2 and the negation
  swallows it. Every criterion asserting that a string is *gone*, or that a count
  is zero, asserts in the same command that something which must be present is
  present in the same target.
- **A count is pinned in both directions** wherever a count is the property — in
  particular the key count, pinned at exactly ten in both emitters.
- **Every temporary fixture uses an explicit `mktemp` template**
  (`"${TMPDIR:-/tmp}/t1006.XXXXXX"`). A bare `mktemp` ignores an inherited
  `TMPDIR` on macOS and targets the system temp dir, which a sandboxed session
  cannot write — broken as a command on one of the environments that must run it.
  Every criterion that builds a fixture removes it and preserves its own verdict
  across the cleanup.
- **Which criteria pass before the change** (measured live by the executing side
  before the freeze): AC4, AC5, AC13, AC17, AC18 and AC20. AC4 and AC5 pass
  today *through the hardcoded legacy default and the existing `--lessons`
  short-circuit* — they are behaviour-survives locks, true before the change via
  the old mechanism and after it via the resolver. AC13 and AC20 are suites and
  checkers that must stay green. AC17 passes as soon as this spec and the board
  entry are on the branch (both inside its allow-list); AC18 as soon as the
  board sub-bullet naming the deferral is there. **AC15 fails before the
  change**, deliberately: its empirical half (team-init scaffolds no lessons
  file) is true today, but its suite-label half (`T-1006: team-init scaffolds no
  lessons file` in the shipped suite output) is a change detector. Every other
  criterion fails before the change and is what proves it happened.
  **pm-spec has no shell in this role, so no `check:` line below was executed** —
  the executing side runs all twenty-one live against the pre-implementation
  tree, corrects any line that is broken as a command or would pass vacuously
  (meaning preserved), corrects this disclosure to the measured result, and only
  then freezes the intent hash.
- **A criterion states the boundary of what it proves.** These criteria prove
  resolution, precedence, fail-closed behaviour and statement hygiene. They do
  not prove anything about a corpus that does not exist yet, and they do not
  prove the generated prompt blocks are correct — that is #23's.

**Strings this task fixes as an output contract**, so the criteria can pin them:

- Both consumers, on a resolver failure *or* an empty resolved path, print
  `could not resolve the lessons path` (prefixed by their own name, as their
  existing `die` does) and exit `2`.
- `bin/gen-playbook-blocks.sh`'s schema-rejection message names the file it
  actually read: `<resolved-path> fails schema validation`, never the literal
  `tasks/lessons.md`.
- `tests/team-paths/run.sh`'s unregistered-key negative control is the token
  `not-a-key` — chosen because it is not a plausible artifact name and so can
  never become a registered key, which is precisely how the current control
  (`lessons`) came to be swallowed by the thing it was guarding.
- `lessons` is appended **last** in every enumeration it joins (the `--get` case
  arm, `--export`, `--print`, `--help`, the unknown-key `die` message, the header
  comment, and the suite's all-keys loop), so the diff is additive everywhere.

- [ ] **AC1** **The resolver registers `lessons` under all three precedence rules
  and in all three modes, and resolution creates nothing.** Default layout →
  `.shell-team/lessons.md`; legacy marker present → `tasks/lessons.md`;
  `$TEAM_RUN_BASE=.ops` over a legacy root → `.ops/lessons.md`. `--export` emits
  `TEAM_LESSONS` (a file, so no `_DIR` suffix) and evals to the same value;
  `--print` carries a `lessons` row. After all of it, no `lessons.md` exists
  anywhere under the fixture roots.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { mkdir -p "$F/fresh" "$F/legacy/tasks/loops" && : > "$F/legacy/tasks/loops/shell-team.contract.yaml" && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --root "$F/fresh" --get lessons)" = ".shell-team/lessons.md" && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --root "$F/legacy" --get lessons)" = "tasks/lessons.md" && test "$(TEAM_RUN_BASE=.ops bash bin/team-paths.sh --root "$F/legacy" --get lessons)" = ".ops/lessons.md" && env -u TEAM_RUN_BASE bash bin/team-paths.sh --root "$F/fresh" --print | grep -qE '^[[:space:]]+lessons[[:space:]]+\.shell-team/lessons\.md$' && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --root "$F/fresh" --export | grep -c -- '^export TEAM_LESSONS=')" -eq 1 && test "$(find "$F" -name 'lessons.md' | wc -l | tr -d ' ')" -eq 0 && eval "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --root "$F/fresh" --export)" && test "$TEAM_LESSONS" = ".shell-team/lessons.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC2** **The total-key set is exactly ten, pinned in both directions in all
  three counting sites, and the unregistered-key negative control no longer uses
  `lessons`.** `--get lessons` resolves; `--get not-a-key` exits 2; `--export`
  prints exactly ten lines and `--print` exactly ten rows; the resolver's own
  `--help` and unknown-key `die` message both name the key; `TEAM_LESSONS` appears
  in at least two places in the script (the emitter and the header's derived-path
  list). In the suite, `exactly nine` is gone (count 0) with `exactly ten` present
  as the same-file positive control, the all-keys loop ends `interventions lessons`,
  the old `--get lessons` negative-control invocation is gone (count 0), and the
  suite passes.
  - check: rc=0; env -u TEAM_RUN_BASE bash bin/team-paths.sh --get not-a-key >/dev/null 2>&1 || rc=$?; test "$rc" -eq 2 && env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons >/dev/null && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --export | grep -c -- '^export TEAM_')" -eq 10 && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --print | grep -cE -- '^[[:space:]]+[a-z]+[[:space:]]+[^[:space:]]+$')" -eq 10 && bash bin/team-paths.sh --help | grep -qF 'lessons' && env -u TEAM_RUN_BASE bash bin/team-paths.sh --get not-a-key 2>&1 | grep -qF 'lessons' && test "$(grep -cF 'TEAM_LESSONS' bin/team-paths.sh)" -ge 2 && test "$(grep -cF 'exactly nine' tests/team-paths/run.sh)" -eq 0 && test "$(grep -cF 'exactly ten' tests/team-paths/run.sh)" -ge 1 && grep -qF 'interventions lessons' tests/team-paths/run.sh && grep -qF -- '--get not-a-key' tests/team-paths/run.sh && test "$(grep -cF -- '--get lessons >/dev/null 2>&1' tests/team-paths/run.sh)" -eq 0 && bash tests/team-paths/run.sh >/dev/null

- [ ] **AC3** **`gen-playbook-blocks.sh` derives its default from the resolver on
  the default layout.** With the fixture corpus moved to `.shell-team/lessons.md`
  and no `--lessons`, the run succeeds and the generated engineer block's pointer
  text names `.shell-team/lessons.md`, with no `tasks/lessons.md` literal left in
  it. The pointer assertion is the positive control for the negated half — both
  read the same generated file.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/.shell-team" && mv "$F/repo/tasks/lessons.md" "$F/repo/.shell-team/lessons.md" && rmdir "$F/repo/tasks" && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && grep -qF '.shell-team/lessons.md, 2026-01-01' "$F/repo/templates/prompt-blocks/playbook-engineer.md" && test "$(grep -cF 'tasks/lessons.md' "$F/repo/templates/prompt-blocks/playbook-engineer.md")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC4** **`gen-playbook-blocks.sh` still resolves `tasks/lessons.md` on the
  legacy layout — the no-adopter-file-moves guarantee.** The same fixture with the
  legacy marker present and the corpus left at `tasks/lessons.md` generates a
  pointer naming `tasks/lessons.md`, with no `.shell-team/lessons.md` literal in
  it.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/tasks/loops" && : > "$F/repo/tasks/loops/shell-team.contract.yaml" && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && grep -qF 'tasks/lessons.md, 2026-01-01' "$F/repo/templates/prompt-blocks/playbook-engineer.md" && test "$(grep -cF '.shell-team/lessons.md' "$F/repo/templates/prompt-blocks/playbook-engineer.md")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC5** **`--lessons` still wins on `gen-playbook-blocks.sh`, and it does not
  require the resolver to succeed.** With `$TEAM_RUN_BASE` set to a value the
  resolver rejects (`..`) and an explicit `--lessons PATH`, the run succeeds and
  the pointer names the given path, with no resolved-default literal in the
  generated block.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/.shell-team" && mv "$F/repo/tasks/lessons.md" "$F/repo/.shell-team/lessons.md" && rmdir "$F/repo/tasks" && cp "$F/repo/.shell-team/lessons.md" "$F/custom.md" && TEAM_RUN_BASE=.. bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" --lessons "$F/custom.md" >/dev/null 2>&1 && grep -qF "$F/custom.md, 2026-01-01" "$F/repo/templates/prompt-blocks/playbook-engineer.md" && test "$(grep -cF '.shell-team/lessons.md' "$F/repo/templates/prompt-blocks/playbook-engineer.md")" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC6** **`gen-playbook-blocks.sh` is fail-closed on the resolver, in both
  failure modes, and writes nothing.** The criterion first generates successfully
  and asserts the block file exists (the anti-vacuity control — without it, "the
  file is absent" would pass for the wrong reason), then removes it and runs two
  probes: (a) an invalid `$TEAM_RUN_BASE` with no `--lessons`, and (b) a sibling
  `team-paths.sh` replaced by a stub that exits 0 printing nothing — the empty-path
  hole, which would otherwise concatenate to `<root>/`, a directory that passes
  `[ -r ]`. Both must exit 2, print `could not resolve the lessons path`, and
  leave no generated block.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/.shell-team" && mv "$F/repo/tasks/lessons.md" "$F/repo/.shell-team/lessons.md" && rmdir "$F/repo/tasks" && env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>&1 && test -f "$F/repo/templates/prompt-blocks/playbook-engineer.md" && rm -f "$F/repo/templates/prompt-blocks/playbook-engineer.md" && cp -R bin "$F/bin" && printf '#!/usr/bin/env bash\nexit 0\n' > "$F/bin/team-paths.sh" && chmod 755 "$F/bin/team-paths.sh" && rca=0 && { TEAM_RUN_BASE=.. bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>"$F/ea" || rca=$?; } && test "$rca" -eq 2 && grep -qF 'could not resolve the lessons path' "$F/ea" && test ! -e "$F/repo/templates/prompt-blocks/playbook-engineer.md" && rcb=0 && { env -u TEAM_RUN_BASE bash "$F/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>"$F/eb" || rcb=$?; } && test "$rcb" -eq 2 && grep -qF 'could not resolve the lessons path' "$F/eb" && test ! -e "$F/repo/templates/prompt-blocks/playbook-engineer.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC7** **The schema-rejection message names the file that was actually
  read.** With a schema-invalid entry appended to a default-layout corpus, the run
  exits 1, its own message names the resolved absolute path, no `tasks/lessons.md`
  literal appears anywhere in the output, and nothing is generated. The message is
  matched as the composed line (`gen-playbook-blocks: <path> fails schema
  validation`) rather than as a bare path substring, because `check-playbook.sh`'s
  own diagnostics print above it and already contain the path — a bare substring
  match would pass without the consumer's message being fixed at all.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { cp -R tests/gen-playbook-blocks/fixtures/root "$F/repo" && mkdir -p "$F/repo/.shell-team" && mv "$F/repo/tasks/lessons.md" "$F/repo/.shell-team/lessons.md" && rmdir "$F/repo/tasks" && printf '\n## 2099-01-01 — t1006 broken entry\n' >> "$F/repo/.shell-team/lessons.md" && rc=0 && { env -u TEAM_RUN_BASE bash "$R/bin/gen-playbook-blocks.sh" --root "$F/repo" >/dev/null 2>"$F/err" || rc=$?; } && test "$rc" -eq 1 && grep -qF "gen-playbook-blocks: $F/repo/.shell-team/lessons.md fails schema validation" "$F/err" && test "$(grep -cF 'tasks/lessons.md' "$F/err")" -eq 0 && test ! -e "$F/repo/templates/prompt-blocks/playbook-engineer.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC8** **`gen-playbook-blocks.sh --help` is truthful about the default.** Its
  output names the resolver key and no longer advertises a hardcoded default; the
  `--lessons` option line itself is still inside the printed window, which is the
  positive control that the help text was not simply truncated past the fix.
  - check: bash bin/gen-playbook-blocks.sh --help | grep -qF 'team-paths.sh --get lessons' && bash bin/gen-playbook-blocks.sh --help | grep -qF -- '--lessons' && test "$(bash bin/gen-playbook-blocks.sh --help | grep -cF 'default: <root>/tasks/lessons.md')" -eq 0

- [ ] **AC9** **`playbook-promote.sh` derives its default from the resolver, in both
  layouts, resolving against the current working directory as it does today.** Run
  from a default-layout root with no `--lessons`, the entry lands in
  `.shell-team/lessons.md`; run from a legacy root, it lands in
  `tasks/lessons.md`.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { mkdir -p "$F/def/.shell-team" "$F/leg/tasks/loops" && cp tests/playbook-promote/fixtures/lessons-base.md "$F/def/.shell-team/lessons.md" && cp tests/playbook-promote/fixtures/lessons-base.md "$F/leg/tasks/lessons.md" && : > "$F/leg/tasks/loops/shell-team.contract.yaml" && (cd "$F/def" && env -u TEAM_RUN_BASE bash "$R/bin/playbook-promote.sh" --date 2099-06-01 --title 't1006 default layout' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1) && grep -qF '## 2099-06-01 — t1006 default layout' "$F/def/.shell-team/lessons.md" && (cd "$F/leg" && env -u TEAM_RUN_BASE bash "$R/bin/playbook-promote.sh" --date 2099-06-02 --title 't1006 legacy layout' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1) && grep -qF '## 2099-06-02 — t1006 legacy layout' "$F/leg/tasks/lessons.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC10** **`playbook-promote.sh` keeps `--lessons` as an override and is
  fail-closed on the resolver, appending nothing.** With an invalid
  `$TEAM_RUN_BASE`, an explicit `--lessons` still appends (the positive control),
  while the resolved default file stays byte-identical. Then the same invalid
  environment without `--lessons`, and a stub resolver that exits 0 printing
  nothing, must each exit 2 with `could not resolve the lessons path` and leave the
  file byte-identical.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { mkdir -p "$F/def/.shell-team" && cp tests/playbook-promote/fixtures/lessons-base.md "$F/def/.shell-team/lessons.md" && cp "$F/def/.shell-team/lessons.md" "$F/orig.md" && cp "$F/def/.shell-team/lessons.md" "$F/custom.md" && (cd "$F/def" && TEAM_RUN_BASE=.. bash "$R/bin/playbook-promote.sh" --lessons "$F/custom.md" --date 2099-06-03 --title 't1006 override' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>&1) && grep -qF '## 2099-06-03 — t1006 override' "$F/custom.md" && cmp -s "$F/def/.shell-team/lessons.md" "$F/orig.md" && rca=0 && { (cd "$F/def" && TEAM_RUN_BASE=.. bash "$R/bin/playbook-promote.sh" --date 2099-06-04 --title 't1006 broken env' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>"$F/ea") || rca=$?; } && test "$rca" -eq 2 && grep -qF 'could not resolve the lessons path' "$F/ea" && cmp -s "$F/def/.shell-team/lessons.md" "$F/orig.md" && cp -R bin "$F/bin" && printf '#!/usr/bin/env bash\nexit 0\n' > "$F/bin/team-paths.sh" && chmod 755 "$F/bin/team-paths.sh" && rcb=0 && { (cd "$F/def" && env -u TEAM_RUN_BASE bash "$F/bin/playbook-promote.sh" --date 2099-06-05 --title 't1006 empty resolver' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' >/dev/null 2>"$F/eb") || rcb=$?; } && test "$rcb" -eq 2 && grep -qF 'could not resolve the lessons path' "$F/eb" && cmp -s "$F/def/.shell-team/lessons.md" "$F/orig.md"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC11** **On this repository, the bare invocation of both consumers resolves
  the canonical path and says so — and creates nothing.** The criterion is
  deliberately *not* "the command succeeds": there is no corpus at
  `.shell-team/lessons.md` until #23, so both still exit 2. What must be true is
  that the error names the canonical path, no `tasks/lessons.md` literal appears in
  either message, and neither script brings the file into existence. **This
  criterion is scoped to the pre-#23 tree and is expected to go stale once the
  corpus lands** (both invocations then succeed); it is not to be widened or
  re-derived to stay evergreen.
  - check: rc=0; err="$(env -u TEAM_RUN_BASE bash bin/gen-playbook-blocks.sh 2>&1)" || rc=$?; rc2=0; err2="$(env -u TEAM_RUN_BASE bash bin/playbook-promote.sh --date 2099-06-06 --title 't1006 probe' --category process --applies-to all --status active --source 'T-1006 test' --rule 'R.' --why 'W.' --how-to-apply 'H.' 2>&1)" || rc2=$?; test "$rc" -eq 2 && test "$rc2" -eq 2 && printf '%s\n' "$err" | grep -qF '.shell-team/lessons.md' && printf '%s\n' "$err2" | grep -qF '.shell-team/lessons.md' && test "$(printf '%s\n%s\n' "$err" "$err2" | grep -cF 'tasks/lessons.md')" -eq 0 && test ! -e .shell-team/lessons.md

- [ ] **AC12** **No script under `bin/` asserts that the key does not exist, and
  none carries a hardcoded lessons default.** The whole-directory inventory: the
  assertion phrases `no resolver key`, `key exists yet` and `issues #23/#24` are
  gone from `bin/` (count 0 each), the two hardcoded assignments are gone, both
  stale `(default: … tasks/lessons.md)` option descriptions are gone, and
  `bin/retro-inputs.sh` now points at the key it used to deny. Only the *assertion*
  phrasings are banned, deliberately — a provenance reference such as `#24` or
  `see issue #24` beside a corrected sentence is legitimate and must stay possible.
  The positive control that the greps are actually reading the directory is
  asserted in the same command: at least five files under `bin/` still mention
  `lessons`.
  - check: test "$(grep -rn -- 'no resolver key' bin/ | wc -l | tr -d ' ')" -eq 0 && test "$(grep -rn -- 'key exists yet' bin/ | wc -l | tr -d ' ')" -eq 0 && test "$(grep -rn -- 'issues #23/#24' bin/ | wc -l | tr -d ' ')" -eq 0 && test "$(grep -cF -- 'LESSONS="tasks/lessons.md"' bin/playbook-promote.sh)" -eq 0 && test "$(grep -cF -- 'LESSONS="$ROOT/tasks/lessons.md"' bin/gen-playbook-blocks.sh)" -eq 0 && test "$(grep -cF -- 'default: tasks/lessons.md' bin/playbook-promote.sh)" -eq 0 && test "$(grep -cF -- 'default: <root>/tasks/lessons.md' bin/gen-playbook-blocks.sh)" -eq 0 && test "$(grep -cF -- 'team-paths.sh --get lessons' bin/retro-inputs.sh)" -ge 1 && test "$(grep -rl -- 'lessons' bin/ | wc -l | tr -d ' ')" -ge 5

- [ ] **AC13** **`bin/retro-inputs.sh`'s observable behaviour is unchanged.** Its
  suite passes and both lessons cases still report what they report today: no
  `--lessons` → `unavailable`, a supplied readable path → `read`. This is the
  DP-1(b) lock — the statements change, the ledger does not. Passes before the
  change and must keep passing after it.
  - check: rc=0; out="$(bash tests/retro-inputs/run.sh 2>&1)" || rc=$?; test "$rc" -eq 0 && printf '%s\n' "$out" | grep -qF 'PASS: case: lessons path not supplied -> unavailable' && printf '%s\n' "$out" | grep -qF 'PASS: case: lessons path supplied -> read'

- [ ] **AC14** **CI dogfoods the new key at resolver level.** The existing
  `Dogfood team-paths` step gains one assertion naming `--get lessons` and
  `.shell-team/lessons.md` on the same line, and that assertion is true when run
  here. It asserts resolution only — no file has to exist, which is what keeps it
  independent of #23.
  - check: grep -qF 'Dogfood team-paths' .github/workflows/check-handoff.yml && grep -F -- '--get lessons' .github/workflows/check-handoff.yml | grep -qF -- '.shell-team/lessons.md' && test "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)" = ".shell-team/lessons.md"

- [ ] **AC15** **`bin/team-init.sh` scaffolds no lessons file** — the corpus stays
  opt-in, and adding an export key must not change that. A fresh target gets the
  board (the positive control that the scaffold ran at all) and no file named
  `lessons.md` anywhere beneath it, and the shipped suite carries the case so CI
  keeps it locked. Two-sided invariant lock: passes before the change too.
  - check: R="$PWD"; F="$(mktemp -d "${TMPDIR:-/tmp}/t1006.XXXXXX")"; ok=0; { mkdir -p "$F/t" && env -u TEAM_RUN_BASE bash bin/team-init.sh "$F/t" >/dev/null 2>&1 && test -f "$F/t/.shell-team/todo.md" && test "$(find "$F/t" -name 'lessons.md' | wc -l | tr -d ' ')" -eq 0 && bash "$R/tests/team-init/run.sh" 2>&1 | grep -qF 'T-1006: team-init scaffolds no lessons file'; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC16** **`bin/` stays pure bash, zero-dependency and shellcheck-clean.**
  `shellcheck` is clean over every file this task touches, no new
  `shellcheck disable` directive is added to `bin/team-paths.sh`, and no new
  runtime (`jq`, `yq`, `python`, `perl`, `node`, `ruby`) appears in the three
  changed `bin/` scripts. The runtime alternation avoids `\b`, which is a GNU
  extension the host `grep` may not honour, in favour of a portable
  character-class boundary. The positive control that those greps read the files:
  both consumers reference `team-paths.sh`.
  - check: shellcheck bin/team-paths.sh bin/gen-playbook-blocks.sh bin/playbook-promote.sh bin/retro-inputs.sh tests/team-paths/run.sh tests/gen-playbook-blocks/run.sh tests/playbook-promote/run.sh tests/team-init/run.sh && test "$(grep -rnE -- '(^|[^a-z])(jq|yq|python3?|perl|node|ruby)([^a-z]|$)' bin/team-paths.sh bin/gen-playbook-blocks.sh bin/playbook-promote.sh | wc -l | tr -d ' ')" -eq 0 && test "$(grep -cF -- 'shellcheck disable' bin/team-paths.sh)" -eq 0 && test "$(grep -rnF -- 'team-paths.sh' bin/gen-playbook-blocks.sh bin/playbook-promote.sh | wc -l | tr -d ' ')" -ge 2

- [ ] **AC17** **The diff is confined to this task's allow-list, and the surfaces
  #23 owns are untouched.** Every changed path is on the list below, the diff is
  non-empty (the anti-vacuity control), and nothing under `templates/`, `agents/`,
  `skills/` or `docs/` is touched — which is how "no prompt-block regeneration, no
  pointer swap, no corpus" is proved rather than promised. (`tests/errexit-safe/run.sh`
  entered the list at the ratified v1→v2 re-freeze: its `NOT_APPLY` registry pins a
  `gen-playbook-blocks.sh` warning line by `file:line:content`, and this task's edit
  shifts that line, so the pin update is a mechanically-required companion edit.) **This criterion is
  merge-point-scoped: it is tied to `d691a6f` and is expected to go stale once
  later work lands on `develop`.** Do not widen its base-ref resolution or
  re-derive it per rework round.
  - check: L="$(git diff --name-only d691a6f)"; test -n "$L" && test "$(printf '%s\n' "$L" | grep -vcE '^(bin/team-paths\.sh|bin/gen-playbook-blocks\.sh|bin/playbook-promote\.sh|bin/retro-inputs\.sh|tests/team-paths/run\.sh|tests/gen-playbook-blocks/run\.sh|tests/playbook-promote/run\.sh|tests/team-init/run\.sh|tests/errexit-safe/run\.sh|\.github/workflows/check-handoff\.yml|\.shell-team/test-recipe\.md|\.shell-team/todo\.md|\.shell-team/specs/T-1006-lessons-resolver-key\.md|\.shell-team/provenance/T-1006\.md|\.shell-team/reviews/T-1006\.md|\.shell-team/interventions/T-1006\.md)$')" -eq 0 && test "$(git diff --name-only d691a6f -- templates/ agents/ skills/ docs/ | wc -l | tr -d ' ')" -eq 0

- [ ] **AC18** **The one known false statement this task does not fix is declared
  and traceable.** `agents/scrum-master.md` is byte-unchanged against the base ref,
  its `there is no resolver key for it` clause is still present (the positive
  control that the file was neither edited nor emptied), and the board entry names
  the deferral explicitly so it cannot be lost between this task and its
  fast-follow. **Merge-point-scoped and deferral-scoped: expected to go stale**
  once the fast-follow fixes the clause.
  - check: test "$(git diff --name-only d691a6f -- agents/scrum-master.md | wc -l | tr -d ' ')" -eq 0 && grep -qF 'there is no resolver key for it' agents/scrum-master.md && grep -qF 'deferred: agents/scrum-master.md' "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get todo)"

- [ ] **AC19** **The fixture-layout hazard is written down where the next engineer
  will read it.** `.shell-team/test-recipe.md` gains a T-1006 entry naming
  `tests/gen-playbook-blocks/fixtures/root` and the fact that which lessons path
  the resolver picks now depends on whether the legacy marker is present in the
  fixture root. The pre-existing T-1004 entry is the positive control that the
  file was appended to, not replaced.
  - check: grep -qF 'T-1006' .shell-team/test-recipe.md && grep -qF 'tests/gen-playbook-blocks/fixtures/root' .shell-team/test-recipe.md && grep -qF 'T-1004' .shell-team/test-recipe.md

- [ ] **AC20** **The shipped suites and the board/prompt checkers stay green.**
  `tests/team-paths`, `tests/gen-playbook-blocks`, `tests/playbook-promote` and
  `tests/team-init` all pass, as do `check-prompt-sync.sh` and the board linter on
  the resolved board path. (`tests/retro-inputs` is covered by AC13, kept separate
  so no single criterion runs long enough to hit `check-acs.sh`'s 120s cap.)
  - check: bash tests/team-paths/run.sh >/dev/null && bash tests/gen-playbook-blocks/run.sh >/dev/null && bash tests/playbook-promote/run.sh >/dev/null && bash tests/team-init/run.sh >/dev/null && bash bin/check-prompt-sync.sh >/dev/null && bash bin/check-handoff.sh "$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get todo)" >/dev/null

- [ ] **AC21** **The new behaviour is locked in the shipped suites, not only in
  these criteria.** The two consumer suites carry labelled cases for the
  resolver-derived default on both layouts and for the fail-closed path, so CI
  keeps them after this spec's criteria stop being run. The labels are pinned
  because a case that exists but is never reached would leave the lock vacuous.
  - check: rc=0; g="$(bash tests/gen-playbook-blocks/run.sh 2>&1)" || rc=$?; rc2=0; p="$(bash tests/playbook-promote/run.sh 2>&1)" || rc2=$?; test "$rc" -eq 0 && test "$rc2" -eq 0 && printf '%s\n' "$g" | grep -qF 'T-1006: the default layout resolves the lessons path via bin/team-paths.sh' && printf '%s\n' "$g" | grep -qF 'T-1006: the legacy layout resolves tasks/lessons.md via bin/team-paths.sh' && printf '%s\n' "$g" | grep -qF 'T-1006: a resolver failure is fail-closed (nothing written)' && printf '%s\n' "$p" | grep -qF 'T-1006: the resolver-derived default is used when --lessons is omitted' && printf '%s\n' "$p" | grep -qF 'T-1006: a resolver failure is fail-closed (nothing appended)'

## Input space

**Reachable input classes** — what real usage produces, and what this change must
therefore be correct about.

1. **Three layouts × three modes.** A fresh repository (default `.shell-team`), a
   repository carrying `tasks/loops/shell-team.contract.yaml` (legacy), and a
   `$TEAM_RUN_BASE` override including a two-component base such as `a/b`;
   each through `--get lessons`, `--export` and `--print`.
2. **A repository where the resolved lessons file does not exist** — this
   repository, today, until #23. Both consumers must fail with an error naming
   the canonical path and must create nothing.
3. **A repository where it exists and is schema-valid.** The two shipped fixture
   corpora (`tests/gen-playbook-blocks/fixtures/root/tasks/lessons.md`,
   `tests/playbook-promote/fixtures/lessons-base.md`) are the concrete instances.
4. **A repository where it exists and is schema-invalid.** Fail-closed: nothing
   written or appended, and the message names the file that was read.
5. **`--lessons PATH` supplied** — absolute, relative, and pointing at a
   differently-named file. It must win over the resolver and must not require the
   resolver to succeed.
6. **A resolver failure reachable from real usage:** an invalid `$TEAM_RUN_BASE`
   (`.`, `..`, an absolute path, a `~` path, a value containing whitespace — the
   values `validate_base` already rejects), and a `--root` that is not a
   directory.
7. **A resolver that exits 0 printing nothing.** Synthetic in origin — produced
   here with a stub — and deliberately **in scope**, because it is the exact hole
   the fail-closed rule exists to close: an empty value concatenates to `<root>/`,
   a *directory*, for which `[ -r ]` is true, so the run would proceed on nothing.
   One guard and one fixture close it.
8. **A repository root path containing a space.** The resolver's existing
   eval-safety class; `--export` must still eval cleanly with the new variable in
   it.
9. **`bin/retro-inputs.sh` invoked with and without `--lessons`,** including an
   unreadable path and a directory — its ledger line must be exactly what it is
   today in every one of those states.
10. **`bin/team-init.sh` on a fresh target and on a target that already has a
    scaffold** — neither may produce a lessons file.

**Out-of-scope synthetic extremes** — named and declined:

1. **A resolver that prints multiple lines, a path containing an embedded
   newline, or a NUL byte.** `bin/team-paths.sh` is this repository's own script
   under the same CI and the same shellcheck gate, not untrusted input; the
   operator-supplied `--lessons` path already has its own structural checks
   (embedded newline, marker-string collision) and those are unchanged.
2. **Adopter corpora at arbitrary third paths, and any migration of an existing
   `tasks/lessons.md`.** No adopter file moves — the legacy layout keeps
   resolving to the file it already has, and that is the whole compatibility
   claim.
3. **Concurrent invocations racing on the same lessons file.** Not introduced by
   this change; `playbook-promote.sh`'s append is as atomic after it as before.
4. **Non-UTF-8, CRLF or NUL-bearing corpora.** That is `bin/check-playbook.sh`'s
   declared surface and it is untouched here.
5. **Re-litigating `$TEAM_RUN_BASE` validation for the new key.** The existing
   suite already locks the full rejection set against `--get base`; one
   representative invalid value is exercised for `lessons` and no more.
6. **Ever-deeper base-dir nestings** (`a/b/c/d/…`). One two-component base is the
   boundary.
7. **Symlinked lessons files, symlinked base dirs, and case-insensitive
   filesystem collisions** (`Lessons.md` vs `lessons.md`).
8. **The behaviour `bin/retro-inputs.sh` would have if it were switched to the
   resolver** (DP-1 option (a)) — deferred with #23's retro side, so its
   determination semantics are not in this task's input space at all.
9. **Windows path separators.**

<!-- END intent-block: T-1006 -->

## Resolved design decisions

### DP-1 — `bin/retro-inputs.sh`: correct the statements, do not switch it to the resolver

Option (a), switching it to resolve the lessons path itself, is **rejected for
this task**: the lessons line's status is produced by the DS-5/DS-6 promotion
preconditions, whose canonical wording lives in
`templates/prompt-blocks/retro-inputs.md` and is asserted in
`tests/retro-inputs/run.sh`. Changing when the line is `read` versus
`unavailable` is a change to the retro's declared-inputs contract and belongs
with #23's retro side, where the corpus it would read actually exists.

Option (b) is adopted: **behaviour unchanged, statements corrected.** The four
sites (help `:128-129`, design comment `:453-454`, runtime detail `:460`, and the
header's framing at `:7-10`) must stop saying that no resolver key exists and
start saying what will then be true — this script asks for the path explicitly,
by choice, and the key is available for the caller to supply
(`team-paths.sh --get lessons`). The exact wording is the engineer's; the
forbidden outcome is a shipped statement asserting the key does not exist (AC12),
and the forbidden side effect is a behaviour change (AC13).

### DP-2 — the export variable is `TEAM_LESSONS`, and the 9 → 10 lock is explicit

`TEAM_LESSONS`, not `TEAM_LESSONS_DIR`: the `_DIR` suffix is this script's marker
for directory-valued keys, and this one is a file. `TEAM_LESSONS_FILE` was
considered and rejected — no existing key carries a type suffix for files
(`TEAM_TODO` is a file), so a new suffix convention would be introduced for one
key.

The lock in `tests/team-paths/run.sh:148-164` counts the key set three
independent ways and **uses `lessons` as its negative control** at `:156`.
Raising the two `-eq 9` assertions without swapping that control leaves a
contradiction the suite would report; swapping the control without raising the
counts leaves the lock reporting nine. Both halves are one atomic edit, pinned by
AC2, and the replacement token is `not-a-key` specifically so that no future task
can register it and repeat this failure.

### DP-3 — the criterion is "resolves correctly", never "the command succeeds"

There is no corpus at `.shell-team/lessons.md` and this task does not create one,
so the bare invocation of either consumer still exits non-zero here. Writing an
acceptance criterion as "the documented command now works" would be unsatisfiable
without importing the corpus — i.e. without absorbing #23. AC11 therefore pins
the two properties that *are* achievable and are what #23 needs: the resolved
path is the canonical one, and the error says so. Regenerating the prompt blocks
so their pointer strings name the new path is #23's, and `templates/` is pinned
untouched (AC17) so it cannot leak in.

### DP-4 — CI gets one resolver-level assertion, in the step that already exists

The workflow's `Dogfood team-paths` step already asserts `base`, `todo` and
`specs` against the default layout. One more line there covers `lessons` at the
same level, needs no file to exist, and adds no step. The corpus-validating pin
(`check-playbook.sh "$(… --get lessons)"`) is deliberately *not* added: it would
fail on every run until #23 lands.

### DP-5 — fail-closed means capture-then-check, and an empty path is a failure

`bin/team-init.sh:144-147` is the in-repo precedent: capture the resolver's
output, check its exit status, and die with a message pointing at
`$TEAM_RUN_BASE` rather than letting command substitution swallow the error. Both
consumers adopt it, with one addition specific to this key: **an empty resolved
path is treated as the same failure.** Unchecked, `LESSONS="$ROOT/"` names a
directory, `[ -r ]` returns true for a directory, and generation would proceed
against nothing — the failure mode is a silent pass, which is the one outcome
this repository's checker discipline forbids. Both failure modes share one
message so there is a single contract to pin.

The resolver is called **only when `--lessons` is absent.** An override that
required the resolver to succeed would make an explicit path unusable in exactly
the situation where someone reaches for it.

### DP-6 — the legacy marker is created at runtime by the suite, not committed as a fixture file

`tests/gen-playbook-blocks/fixtures/root/` holds `tasks/lessons.md` but **no**
`tasks/loops/shell-team.contract.yaml`, so the resolver classifies it as the
*default* layout. Every bare `--root` invocation in that suite would therefore
start looking for `.shell-team/lessons.md` and fail the moment the consumer is
wired up. This is the single largest breakage risk in the task and it is invisible
until the wiring lands.

Two shapes were considered. Committing the marker into the fixture tree (the
tech-lead's suggestion) works and doubles as legacy coverage. **Adopted instead:
create the marker at runtime in the suite's `clone_fixture` helper**, and derive
the default-layout variant at runtime too (clone, then move `tasks/lessons.md` to
`.shell-team/lessons.md`). Reasons: every other suite in this repository creates
that marker at runtime (`tests/team-paths`, `tests/log-run`, `tests/close-out`,
`tests/rollup-track`, `tests/interventions-reminder`, `tests/gitignore-raw-dumps`,
`tests/retro-inputs`) and a committed one would be the only exception; the
existing cases keep resolving to `tasks/lessons.md` with no per-case edits; and no
new fixture file is added, which keeps AC17's allow-list to source files only.

### DP-7 — `agents/scrum-master.md`'s stale clause is deferred, with the deferral made verifiable

`agents/scrum-master.md:45` states `there is no resolver key for it`, which this
task falsifies. Fixing it here was considered and declined: agent prose is
assigned away from this task, the file is a `contain`-mode consumer of two
canonical prompt blocks, and T-1003's frozen AC16 pins its numbered items at
eighteen — so a one-clause edit carries review surface disproportionate to its
size, and #23 is the task that rewrites that file's lessons references anyway.

Declining silently is the outcome that is not acceptable, because a false shipped
statement with no record is exactly the class this task exists to remove. The
deferral therefore carries three obligations, two of them machine-checked (AC18):
the file is byte-unchanged, the board entry names the clause with the literal
`deferred: agents/scrum-master.md`, and a fast-follow issue is filed at the
recording step naming the file, the line and the one-clause fix.

## Measured inventory (verified against the tree at `d691a6f`; re-verify before editing)

| Site | What it is | Disposition |
|---|---|---|
| `bin/team-paths.sh:22-23` | header derived-paths variable list | add `TEAM_LESSONS` |
| `bin/team-paths.sh:34-36` | header `--get KEY` enumeration | append `lessons` |
| `bin/team-paths.sh:65` | `--help` `--get KEY` enumeration | append `lessons` |
| `bin/team-paths.sh:155-161` | derived-path assignments | add `LESSONS="$BASE/lessons.md"` |
| `bin/team-paths.sh:167-175` | `--export` emitters (9) | add a tenth, last |
| `bin/team-paths.sh:178-188` | `--get` case arms + unknown-key `die` list | add arm + enum entry |
| `bin/team-paths.sh:193-201` | `--print` rows (9) | add a tenth, last |
| `bin/gen-playbook-blocks.sh:90-95` | `--lessons` / default + `POINTER_PATH` | resolve; `LESSONS="$ROOT/<resolved>"`, `POINTER_PATH="<resolved>"` |
| `bin/gen-playbook-blocks.sh:44-47` | `--lessons` help text | correct the default description |
| `bin/gen-playbook-blocks.sh:3,13,25,51,86,89,103,257` | prose naming `tasks/lessons.md` generically | engineer's judgment; only false statements must go |
| `bin/gen-playbook-blocks.sh:193` | schema-rejection message | must name the resolved file (AC7) |
| `bin/playbook-promote.sh:226` | hardcoded default | resolve against cwd |
| `bin/playbook-promote.sh:84` | header `--lessons` default description | correct |
| `bin/retro-inputs.sh:7-10,128-129,453-454,460` | four "no resolver key" statements | correct per DP-1 |
| `tests/team-paths/run.sh:37-46,52-59,79-83` | per-layout assertions | add a `lessons` assertion to each |
| `tests/team-paths/run.sh:148-164` | total-key lock, 3 counting sites + negative control | 9 → 10 and swap the control |
| `tests/gen-playbook-blocks/run.sh:33-36` | `clone_fixture` | create the legacy marker; add a default-layout variant |
| `tests/playbook-promote/run.sh` | 18 `--lessons` invocations | unaffected; add resolver-default cases |
| `tests/team-init/run.sh:45-60` | scaffold file list | add the no-lessons-file case |
| `.github/workflows/check-handoff.yml:133-137` | `Dogfood team-paths` | one added assertion |
| `agents/scrum-master.md:45` | `there is no resolver key for it` | deferred (DP-7), pinned unchanged |
| `skills/review-response/SKILL.md` | `tasks/lessons.md` prose pointer | #23's |
| `bin/check-playbook.sh`, `bin/review-gate.sh:14`, `bin/check-readme-version.sh:3` | prose mentions of `tasks/lessons.md` | no default to correct; untouched |

## Body-to-AC correspondence

| Body directive | Promoted to |
|---|---|
| Canonical default path is `<base>/lessons.md`, i.e. `.shell-team/lessons.md` here | AC1, AC14 |
| Legacy layout resolves `tasks/lessons.md` | AC1, AC4, AC9 |
| `$TEAM_RUN_BASE` override yields `<base>/lessons.md` | AC1 |
| Resolution is path-only — never creates the file, succeeds when absent | AC1, AC11 |
| Export variable is `TEAM_LESSONS` (file, no `_DIR`) | AC1, AC2 |
| Key set moves 9 → 10 in all three counting sites | AC2 |
| The suite's negative control is swapped off `lessons` | AC2 |
| `lessons` appended last in every enumeration | AC2 (`interventions lessons`), AC1 (`--print` row) |
| Both consumers derive the default from the resolver | AC3, AC4, AC9 |
| `--lessons` stays an override on both consumers | AC5, AC10 |
| The override short-circuits the resolver (works with an invalid `$TEAM_RUN_BASE`) | AC5, AC10 |
| Fail-closed on resolver non-zero exit; nothing written/appended | AC6, AC10 |
| An empty resolved path is a failure, not `<root>/` | AC6, AC10 |
| Both failure modes share the message `could not resolve the lessons path`, exit 2 | AC6, AC10 |
| The schema-rejection message names the file actually read | AC7 |
| `--help` must not advertise a hardcoded default | AC8 |
| No `bin/` statement asserts the key does not exist | AC12 |
| No `bin/` script carries a hardcoded lessons default | AC12 |
| `bin/retro-inputs.sh` behaviour unchanged (DP-1(b)) | AC13 |
| CI dogfoods the key at resolver level, one line, existing step | AC14 |
| `bin/team-init.sh` scaffolds no lessons file | AC15 |
| Pure bash, zero-dependency, shellcheck-clean | AC16 |
| No prompt-block regeneration, no pointer swap, no corpus, no corpus CI pin | AC17 |
| No `agents/`, `skills/`, `docs/`, `templates/` edit | AC17, AC18 |
| No adopter has to move a file | AC4, AC9 (legacy path still resolved and written) |
| `agents/scrum-master.md`'s stale clause deferred, declared and traceable | AC18 |
| The fixture-layout hazard is recorded for the next engineer | AC19 |
| Existing suites and checkers stay green | AC13, AC20 |
| The new behaviour is locked in the shipped suites, not only in these criteria | AC21 |
| No new flag on either consumer, in particular no `--root` on `playbook-promote.sh` | info-only (not promoted to AC) — proved negatively by AC9, which exercises the cwd-relative behaviour that a `--root` flag would replace; a separate criterion would only restate it |
| No change to `bin/check-playbook.sh` | info-only (not promoted to AC) — AC17's allow-list already excludes it, so a dedicated criterion would be a second copy of the same assertion |
| No adopter-facing documentation change | info-only (not promoted to AC) — measured that no `docs/`, `README*` or `templates/` file enumerates the key set, so nothing becomes false; AC17 pins those trees unchanged regardless |
| The two pre-existing `--help` window warts are not repaired | info-only (not promoted to AC) — a criterion asserting a pre-existing wart *persists* would obstruct the permitted widening of the gen window; AC8 pins the property that matters (the `--lessons` text is truthful and inside the window) |
| The gen header's claim that "CI adds a freshness dogfood step" (no such step exists) | info-only (not promoted to AC) — a pre-existing inaccuracy unrelated to the key; flagged in Notes as a fast-follow candidate rather than fixed inside a scope-locked diff |
| `lessons` is appended last for diff-additivity | info-only for the sites AC1/AC2 do not reach (header comments) — ordering there is cosmetic and asserting it would pin comment text |

## Assumptions

- **Base ref `d691a6f`.** Every line number above was read there. If the branch
  is rebased, re-verify the inventory before editing — the line numbers are
  convenience, the file contents are the contract.
- **`shellcheck` is available to the executing side.** CI installs 0.11.0; AC16
  fails loudly rather than soft-skipping, which is deliberate.
- **#23 lands after this task** and owns the corpus, the prompt-block
  regeneration, the pointer strings, and the corpus CI pin. If that ordering
  changes, AC11 and AC17 are the criteria that need revisiting first.
- **The em dash in AC7's and AC9's/AC10's literals is U+2014**, the same character
  `playbook-promote.sh` writes into a heading and `check-playbook.sh` parses.
  Unverified by pm-spec (no shell in this role) — flagged for the executing side.
- **`check-acs.sh`'s 120s per-check cap applies.** AC20 and AC21 each run more
  than one suite; if either exceeds the cap on a slow host, raise
  `CHECK_ACS_TIMEOUT` for the run rather than splitting the criterion.
- **`cmp` and `find` are available** (POSIX, already used by suites in this
  repository).
- **AC17's allow-list sees tracked changes only.** `git diff --name-only` does not
  report untracked files, so a path enters the criterion once it is staged or
  committed — including this spec. That is the same shape T-1005's scope-lock used;
  the criterion's job is to forbid out-of-scope *edits*, not to inventory scratch
  files.
- **AC12 bans assertion phrasings, not references.** `no resolver key`,
  `key exists yet` and `issues #23/#24` are the three strings that carry the false
  claim; a bare `#24` or `see issue #24` as provenance is deliberately still
  allowed, so the engineer is not forced to strip the reason a line exists.

## Open questions

None blocking.

## Notes for engineer

**Build order that keeps the tree green at each step.** (1) `bin/team-paths.sh` +
`tests/team-paths/run.sh` — the 9 → 10 lock and the negative-control swap in one
commit, because the suite is red between them. (2)
`tests/gen-playbook-blocks/run.sh`'s `clone_fixture` — create the legacy marker
*before* wiring the consumer, so the suite never goes through a red state caused
by DP-6's hazard rather than by your change. (3) `bin/gen-playbook-blocks.sh`. (4)
`bin/playbook-promote.sh` + its suite's new cases. (5) `bin/retro-inputs.sh`
statements. (6) workflow line, `tests/team-init/run.sh` case, test-recipe entry.

**The three hazards, in order of how much they will cost you.**

1. `tests/team-paths/run.sh:156` uses the literal token `lessons` as the
   negative control for "an unregistered key exits 2". Wire the key without
   swapping it and the suite reports a contradiction; swap it without raising the
   two `-eq 9` assertions and the lock silently reports nine. One edit.
2. `tests/gen-playbook-blocks/fixtures/root/` has `tasks/lessons.md` and **no**
   legacy marker, so the resolver calls it the default layout. Bare `--root`
   invocations at `run.sh:40`, `:174`, `:482` and elsewhere break the moment the
   consumer resolves. DP-6 is the fix; do it first.
3. `[ -r "$LESSONS" ]` at `gen-playbook-blocks.sh:116` is **true for a
   directory**, so an empty resolved path (`"$ROOT/"`) passes the readability gate
   and generation proceeds against nothing. `bin/team-init.sh:144-147` is the
   capture-then-check precedent to copy.

**Mutation self-check before hand-off** (run each, observe the named criterion go
red, restore, observe it green again, and confirm the restore is byte-identical):

1. Restore `lessons` as the suite's negative-control token → AC2 red.
2. Leave one of the three counting sites at nine → AC2 and the suite red.
3. Remove the empty-path guard in `gen-playbook-blocks.sh`, then in
   `playbook-promote.sh` → AC6 and AC10's stub probes red.
4. Drop the runtime legacy marker from `clone_fixture` → AC4 (and existing gen
   cases) red.
5. Put the `tasks/lessons.md` literal back in the schema-rejection message → AC7
   red.
6. Re-add a `no resolver key` phrase to any `bin/` comment → AC12 red.
7. Call the resolver even when `--lessons` is given → AC5 and AC10's override half
   red.

**Two things to leave alone even though you will see them.**
`agents/scrum-master.md:45` says `there is no resolver key for it` and will be
false when you are done — DP-7 defers it deliberately and AC18 pins it unchanged;
raise it in the hand-off so the fast-follow issue gets filed.
`bin/gen-playbook-blocks.sh:26-27` claims CI has a freshness dogfood step that
regenerates into a temp copy and diffs; the workflow has no such step. Unrelated
to the key, outside AC17's allow-list rationale, and worth naming in the hand-off
as a second fast-follow candidate rather than fixing inside a scope-locked diff.

**Prior art.** `bin/team-init.sh:139-147` (capture-then-eval resolver call, the
fail-closed precedent), `bin/team-init.sh:225-232` (the explicit variable
enumeration that is why an added export key does not scaffold a file),
`tests/team-paths/run.sh:148-164` (the lock you are moving),
`tests/gen-playbook-blocks/run.sh:101-115` (the existing `--lessons` pointer test,
whose shape AC5 mirrors).
