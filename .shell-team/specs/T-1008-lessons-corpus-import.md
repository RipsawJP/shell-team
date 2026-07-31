# T-1008 — the lessons corpus is imported in English, triaged through a recorded four-outcome routing rule, and its provenance is proved in CI

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1008
**Source**: GitHub issue #23. This is the **corpus half** of a two-task split of #23; the mechanism half shipped as T-1007. No new issue was opened: #23 carries the decided design and stays the tracker for both halves. Fast-follows #57 and #58 are bundled here — #57 because #23 rewrites the file it names anyway, #58 because its direction (b) needs the corpus this task lands.
**Branch**: `feature/lessons-corpus-import` (from `develop` at `902c465`).

## Problem

`templates/prompt-blocks/playbook-*.md` are generated artefacts spliced into
four `agents/*.md` and shipped to every adopter, and the file they are generated
from is not in this repository. Three consequences, all measured:

- Every adopter receives **Japanese** prompt content, from a corpus whose entries
  were written for one maintainer developing this plugin.
- Nothing validates a real corpus and nothing proves the shipped blocks were
  generated from one. `tests/check-playbook/run.sh:6` even advertises an
  assertion — "the real repo's `tasks/lessons.md` passes (dogfood)" — that the
  suite does not contain, and `bin/gen-playbook-blocks.sh:26-30` claims a CI
  freshness step that the workflow does not have (#58).
- `agents/scrum-master.md:45` still tells the retro agent `there is no resolver
  key for it` about the lessons log, which T-1006 made false (#57).

T-1007 shipped the machine-enforced shipping boundary with **zero corpus**:
`Scope: loop | maintainer` required fail-closed, `Bound-in` mandatory on
`maintainer` and forbidden on `loop`, generation restricted to `Scope: loop` +
`Status: active`, `bin/playbook-promote.sh --scope` carrying the retro's
classification. Nothing passes that boundary today outside `tests/`. This task
puts the real corpus through it.

The corpus cannot simply be copied. Against this repository's checker **as it
stands today** the source fails, because none of its entries carries `Scope` —
which is the forced ordering working as designed. Beyond the schema, three
properties have to be produced rather than transferred: the entries are
Japanese; roughly 30% of the active ones are only meaningful when developing
this plugin (#23's measurement); and every entry's `Source`, and much of its
prose, names artefacts of a repository that does not exist here — including
`docs/loop-engineering/playbook-update-path.md`, which **issue #23 itself
references and which this repository does not have** (measured 2026-07-31).

## Goal

<!-- BEGIN intent-block: T-1008 -->

**One corpus at the resolved canonical path, in English, schema-green.** The
imported corpus lives at `$(bin/team-paths.sh --get lessons)` —
`.shell-team/lessons.md` on this repository's layout — carries a header
documenting all eleven field names (angle-bracket placeholders in the `## Format`
fence, so no `sed` or `grep` aimed at a real value can reach the example) and the
four-outcome routing rule, and passes `bin/check-playbook.sh` with exit 0. Every
entry carries `Scope`; every `maintainer` entry carries a `Bound-in` pointer at a
file that **exists**. The corpus contains no Japanese and no full-width
characters at all: the translation is complete, not partial.

**Every source entry's disposition is recorded in a first-class ledger.**
`docs/loop-engineering/lessons-import-disposition.md` carries one row for each of
the **79** entries measured in the source (76 `active`, 3 `superseded` — the
re-measured count; #23's table said 80/77 because it counted the `## Format`
fence's template line). A row is keyed by the source entry's **date plus its
1-based sequence number among the entries sharing that date in source file
order** — never by the untranslated title, which would carry the very content
being translated into the record of the translation. Each row names exactly one
outcome from `loop | maintainer | operator-global | drop`, a one-line reason, and
a destination: the corpus key for a retained row, `n/a` for a row that does not
enter this repository. The ledger and the corpus agree in **both** directions —
every retained row resolves to an entry, every entry is some retained row's
destination, and no third state exists.

**The routing rule has four outcomes and only two of them are `Scope` values.**
`loop` ships; `maintainer` stays in the repository bound to a repo-local file;
`operator-global` (tool-behaviour knowledge that is cross-project rather than
repo-specific) and `drop` (knowledge keyed to a task-numbering convention
`CLAUDE.md` §Task IDs has replaced) do not enter this repository at all. A drop
is justified per entry on its own merits, **never to hit a count**, and a
non-retained row carries no real value of any kind — no employer or customer
name, no internal ticket identifier, no hostname.

**Nothing foreign survives into the shipped surface.** Neither the corpus, nor
the ledger, nor any of the four generated blocks carries a pre-publication task
identifier (`T-` followed by three digits, other than this repository's own
`T-111`/`T-112`/`T-113`), a bare `#<number>` issue or pull-request reference, or
a path that does not resolve in this repository. Operating artefacts are named in
resolver form or by their default-layout path — never as a bare legacy
`tasks/…` or `docs/specs/…` literal. `Source` is either `n/a` or a
repository-relative path that exists.

**The shipped blocks are regenerated from that corpus, and CI proves it.** All
four `templates/prompt-blocks/playbook-*.md` and all four `agents/*.md` consumers
are regenerated, so their pointer text names the resolved path rather than the
legacy literal, and `bin/check-prompt-sync.sh` stays green. Two workflow steps
land: one validating the corpus at the resolver-derived path, one regenerating
into a scratch root and diffing all four blocks and all four consumers, with the
file set derived from `templates/prompt-blocks/registry.txt` rather than
hardcoded, no lessons-path literal anywhere in either step, fail-closed when the
corpus is unreadable, and no mutation of the working tree. Zero `maintainer`
entries reach any block.

**Three advertised-but-absent claims become true.**
`tests/check-playbook/run.sh` gains the dogfood assertion its header line has
advertised since T-045, at the resolved path. `bin/gen-playbook-blocks.sh`'s
header names the CI step that now exists, verbatim, so the claim and the workflow
cannot drift apart silently (#58, direction (b)). `agents/scrum-master.md`'s
`there is no resolver key for it` clause is replaced by the corrected statement
`bin/retro-inputs.sh` already ships — the key exists, the caller supplies the
path — and T-1006's AC18, which pinned that file byte-unchanged, is **hereby
declared intentionally stale**: it recorded a deferral, this task is the deferral
being paid off. T-1007's AC15 (blocks and consumers byte-unchanged) and AC19
(zero corpus) are **likewise intentionally stale**, by the same design that split
the two tasks.

**The adopted subset of the first retro's nine candidates enters through the
promoter.** `.shell-team/retros/2026-07-28.md` carries nine lesson candidates
labelled `[common]` (6) / `[target-specific]` (3). Each gets a recorded
disposition in the same ledger, and the classification maps to scope rather than
being discarded at promotion — which is what T-1007 built `--scope` for. A
`[common]` candidate never becomes a `maintainer` entry and a
`[target-specific]` candidate never becomes a `loop` entry.

## Non-goals

- **The old repository's board, project-status file, retros and reviews.** Only
  the lessons corpus crosses. This repository's board is already running.
- **The destination of `operator-global` knowledge.** It does not enter this
  repository, full stop. Where the operator keeps their cross-project notes is
  outside this task and outside this repository.
- **Hand-editing a generated block.** Every byte inside a
  `<!-- BEGIN prompt-block: playbook-<role> -->` region comes from the generator.
  The regen-diff step exists precisely to make a hand edit fail.
- **Any change to `LINE_WARN_THRESHOLD`** (#23 says so explicitly) or to the
  warning's behaviour. The blocks will exceed the 40-line threshold and the
  generator will warn on stderr; that warning is non-fatal by design and is the
  expected, permitted outcome — not a defect and not a reason to touch the
  threshold.
- **The `Scope` / `Bound-in` schema, the generator's filter, and the promoter's
  flags.** T-1007 shipped all of it. This task adds no schema rule, no new `bin/`
  file, and no logic change to any `bin/` script: the only permitted edit under
  `bin/` is comment text in `bin/gen-playbook-blocks.sh` (#58).
- **Re-triaging the classification of an entry after the fact.** The ledger is
  the record; changing an outcome later is a normal follow-up task, not a silent
  edit.
- **Translating the closed enumerations.** `Category`, `Applies-to`, `Status`
  (and `Scope`) are machine-read values; `Applies-to` decides which role's block
  an entry reaches. Their tokens are copied, never rendered into English prose.
- **Fixture occurrences of `tasks/lessons.md`.** Everything under `tests/*/fixtures/`
  and every fixture corpus a suite builds inline is a legitimate representation
  of the **legacy** layout and stays exactly as it is. So do the generic prose
  mentions in `bin/check-playbook.sh`, `bin/playbook-promote.sh`,
  `bin/retro-inputs.sh`, `bin/review-gate.sh` and `bin/check-readme-version.sh`
  that T-1006's engineer judged non-false and left alone, and the retro
  template's decorated heading `## Lesson 候補（ユーザー判断で tasks/lessons.md
  にマージ）`, which `bin/check-retro.sh` matches by prefix and every committed
  retro reproduces verbatim. Rewriting that heading is issue #20's scope, not
  this task's.
- **A `.ja.md` counterpart** for the ledger, and any Japanese-language
  counterpart of the corpus. The corpus is agent-facing (`CLAUDE.md` §Language);
  a second copy doubles the maintenance surface and the stale copy is the one
  that misleads.
- **Reconstructing entries from the source repository's git history.** Only the
  source file's current state, as measured on 2026-07-31 (79 entries), is in
  scope.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh` or `bash tests/<suite>/run.sh`.

Standing rules, all inherited from what this repository has already paid for:

- **No negated or zero-count `grep` without a same-target positive control.** A
  `! grep -q … FILE` and a `test "$(grep -c … FILE)" -eq 0` both "pass" when
  `FILE` cannot be read. This task is unusually exposed to that class, because
  the corpus and the ledger **do not exist on the pre-implementation tree**:
  every criterion below that asserts an absence first asserts, against the same
  target, that the target is a non-empty file and that something which must be
  present is.
- **A count is pinned in both directions** wherever a count is the property, and
  a pattern that could silently match nothing is proved live against a probe
  fixture in the same criterion (AC2 and AC3 do this).
- **Every temporary fixture uses an explicit `mktemp` template**
  (`"${TMPDIR:-/tmp}/t1008.XXXXXX"`). A bare `mktemp` ignores an inherited
  `TMPDIR` on macOS and targets a directory a sandboxed session cannot write.
  Every criterion that builds one removes it and preserves its own verdict across
  the cleanup.
- **No process substitution.** `/dev/fd` is blocked in some sandboxes this
  repository must still run in; every criterion that needs a list writes it to a
  temp file first.
- **A criterion never mutates the working tree.** Regeneration probes write into
  a scratch root; the corpus and the blocks are read, never written.
- **Which criteria pass before the change** (to be measured live by the executing
  side before the freeze, and this disclosure corrected to the measured result):
  **AC16, AC25, and AC27** (the last as soon as this spec and the board entry are
  on the branch, since both are inside its allow-list). AC16 and AC25 are
  two-sided invariant locks — true before this task and required to still be true
  after it. **AC12 and AC13 carry no `check:` by design** and are reported `SKIP`
  by `bin/check-acs.sh`; they are the two layers that cannot honestly be written
  as exit codes (see the three-layer declaration below). Every other criterion
  fails before the change and is what proves it happened. **pm-spec has no shell
  in this role, so no `check:` line below was executed** — the executing side runs
  all of them live against the pre-implementation tree, corrects any line that is
  broken as a command or would pass vacuously (meaning preserved), corrects this
  disclosure, and only then freezes the intent hash.
- **A criterion states the boundary of what it proves.** These criteria prove
  formal completeness, mechanical consistency, absence of a closed set of
  foreign token shapes, and that regeneration and CI are wired. They prove
  **nothing** about whether an English sentence means what the Japanese one
  meant, and nothing about whether a named entity that no pattern describes
  survived. Those two properties are AC12 and AC13, and they are carried by a
  recorded attestation and by qa-verifier's independent reading of the source.

### The three verification layers, declared

1. **Formal completeness — exit-code mechanical.** Row counts, key shapes, the
   closed outcome enum, ledger↔corpus agreement in both directions, absence of a
   closed set of token shapes, path resolution, regeneration fixed-point, CI
   wiring. AC1–AC11 and AC14–AC27.
2. **Named-entity absence — a recorded enumeration attestation, not an exit
   code.** `bin/check-pii-shapes.sh` finds nothing in the source **today**,
   before any work starts, and would find nothing after a careless translation
   either: it is a shape layer. What remains is exactly what
   `docs/pii-controls.md` declares out of scope — employer and customer names,
   internal ticket identifiers, hostnames, personal names — plus this import's
   two additions, pre-publication task/issue numbers and home-directory absolute
   paths. No checker can see those. The evidence is a written enumeration of the
   classes searched plus a zero-remaining statement (AC11 pins that the record
   exists; AC12 is the property itself). **The search terms are never
   committed** — a file listing the names to look for is the leak it was written
   to prevent. For the same reason the source corpus's absolute path is supplied
   to the engineer out of band and is never transcribed into a tracked file.
3. **Semantic fidelity — process, verified by qa-verifier.** Codex cannot reach
   the source corpus (`codex exec --cd <repo>` sandboxes it out), so the
   cross-provider gate structurally cannot audit fidelity. qa-verifier is the
   only holder of that check: audit all 79 ledger rows against the source,
   adversarially select at least three entries (the longest `Rule`, the one with
   the most conditionals, one whose Japanese carried a parenthetical
   qualification) for semantic-equivalence deep reading, independently sweep the
   six entity classes without transcribing any real value into the hand-off, and
   prove the regen-diff step non-vacuous by mutating one `Rule` in the corpus,
   watching the step FAIL, and restoring. AC13.

### Output contracts this task fixes, so the criteria can pin them

| Artefact | Contract |
|---|---|
| corpus path | `$(bash bin/team-paths.sh --get lessons)` = `.shell-team/lessons.md`; a real file, not a symlink |
| corpus header | an H1, a `## Format` fence documenting all eleven fields with angle-bracket placeholders (`- **Scope**: <loop \| maintainer>`), the four-outcome routing rule, and a pointer to the ledger path |
| corpus entry key | `<source date> — <English title>`; the date is the source entry's date, unchanged |
| corpus field order | `Category`, `Applies-to`, `Scope`, `Bound-in` (maintainer only), `Status`, `Source`, `Rule`, `Why`, `How to apply`, `Superseded-by` / `Extended by` last; no field value carries trailing whitespace |
| ledger path | `docs/loop-engineering/lessons-import-disposition.md` |
| ledger import row | `\| <YYYY-MM-DD> \| <seq> \| <outcome> \| <one-line reason> \| <destination> \|` — outcome ∈ `loop\|maintainer\|operator-global\|drop`; destination = the corpus key, or exactly `n/a`; no cell contains `\|`; per date, the seq values are exactly `1..n` |
| ledger candidate row | `\| <n> \| [common]\|[target-specific] \| <outcome> \| <one-line reason> \| <destination> \|` — outcome ∈ `loop\|maintainer\|operator-global\|drop\|already-covered` |
| ledger attestation | a section naming all six entity classes verbatim, the phrase `zero remaining across all six classes`, and the phrase `search terms are not recorded here` |
| CI step names | begin with `Dogfood check-playbook` and `Dogfood gen-playbook-blocks`; each written as a block scalar (`run: \|`) so it can be extracted and executed |
| `bin/gen-playbook-blocks.sh` header | contains the regen-diff step's **exact** name string, and no longer claims a step that does not exist |
| suite label | `tests/check-playbook/run.sh` prints `T-1008: the real repository corpus at the resolved lessons path passes (dogfood)` |
| both ledger tables | cells are delimited by `\| ` and ` \|` with **exactly one space** around each value — no column padding, no alignment spaces. The criteria's row-shape regexes are written to that contract, and a padded table is a criterion failure rather than a style preference. |

- [ ] **AC1** **The corpus exists at the resolved path, is schema-green, and
  carries its header contract.** The resolver names `.shell-team/lessons.md`; a
  real non-empty file is there (not a symlink, not a dangling one); it holds at
  least one canonical entry heading; `bin/check-playbook.sh` exits 0 against it;
  and its header carries the `## Format` fence with angle-bracket placeholders
  for both T-1007 fields plus the ledger pointer.
  - check: L="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)"; test "$L" = ".shell-team/lessons.md" && test -f "$L" && test ! -L "$L" && test -s "$L" && test "$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2} — ' "$L")" -ge 1 && grep -qxF '## Format' "$L" && grep -qF -- '- **Scope**: <' "$L" && grep -qF -- '- **Bound-in**' "$L" && grep -qF 'docs/loop-engineering/lessons-import-disposition.md' "$L" && bash bin/check-playbook.sh "$L" >/dev/null

- [ ] **AC2** **The translation is complete: no Japanese and no full-width
  character survives in the corpus, the ledger, or any of the four shipped
  blocks.** The test is at the byte level (the UTF-8 lead bytes `0xE3`–`0xEF`,
  which cover kana, CJK ideographs and full-width forms while leaving the em dash
  and the other `0xE2` punctuation this repository uses alone). The pattern is
  proved live against a probe file in the same criterion — otherwise a pattern
  that matched nothing would report every file clean — and each target file is
  asserted non-empty and asserted to contain Latin letters, so an unreadable file
  cannot pass as clean.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=1; CJK=$'[\xe3-\xef]'; printf 'probe \xe3\x81\x82\n' > "$F/probe"; p="$(LC_ALL=C grep -c "$CJK" "$F/probe")"; test "$p" -ge 1 || ok=0; for f in .shell-team/lessons.md docs/loop-engineering/lessons-import-disposition.md templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$f" || { ok=0; continue; }; grep -q '[A-Za-z]' "$f" || ok=0; n="$(LC_ALL=C grep -c "$CJK" "$f")"; rc=$?; test "$rc" -le 1 || ok=0; test "$n" -eq 0 || ok=0; done; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC3** **No pre-publication identifier survives.** Zero
  `T-<three digits>` tokens other than this repository's own
  `T-111`/`T-112`/`T-113` in any of the six files, and zero bare `#<digits>`
  issue or pull-request references in the corpus, in the four blocks, and in
  **every ledger table row** — an old repository's number and this one's are the
  same shape, so the only mechanical rule that can hold is to carry neither. The
  ledger's own surrounding prose is exempt from the `#<digits>` half and may cite
  this repository's tracker; no row may transcribe a number, because a row's
  reason is where an imported entry's references would land. Both patterns are
  proved live against a probe file first, and the ledger's row extraction is
  asserted non-empty.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=1; D=docs/loop-engineering/lessons-import-disposition.md; printf 'probe T-045 and issue #299\n' > "$F/probe"; test "$(grep -oE 'T-[0-9]{3}([^0-9]|$)' "$F/probe" | grep -vcE 'T-11[123]')" -ge 1 || ok=0; test "$(grep -cE '(^|[^A-Za-z0-9])#[0-9]' "$F/probe")" -ge 1 || ok=0; for f in .shell-team/lessons.md "$D" templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$f" || { ok=0; continue; }; grep -q '[A-Za-z]' "$f" || ok=0; test "$(grep -oE 'T-[0-9]{3}([^0-9]|$)' "$f" | grep -vcE 'T-11[123]')" -eq 0 || ok=0; done; for f in .shell-team/lessons.md templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$f" || { ok=0; continue; }; test "$(grep -cE '(^|[^A-Za-z0-9])#[0-9]' "$f")" -eq 0 || ok=0; done; grep '^| ' "$D" > "$F/rows" 2>/dev/null; test -s "$F/rows" || ok=0; test "$(grep -cE '(^|[^A-Za-z0-9])#[0-9]' "$F/rows")" -eq 0 || ok=0; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC4** **Operating artefacts are named in resolver or default-layout form,
  and every block's pointer text proves where it was generated from.** The corpus
  and the four blocks carry none of the legacy or foreign literals
  `tasks/lessons.md`, `tasks/todo.md`, `tasks/reviews/`, `tasks/retros/`,
  `tasks/provenance/`, `tasks/interventions/`, `docs/specs/`; each block carries
  the generated pointer `(.shell-team/lessons.md, ` at least once, which is the
  positive control for the whole criterion — it is only present if regeneration
  actually ran against the resolved path.
  - check: ok=1; for b in templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$b" || ok=0; grep -qF -- '(.shell-team/lessons.md, ' "$b" || ok=0; done; for f in .shell-team/lessons.md templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$f" || { ok=0; continue; }; for t in tasks/lessons.md tasks/todo.md tasks/reviews/ tasks/retros/ tasks/provenance/ tasks/interventions/ docs/specs/; do test "$(grep -cF -- "$t" "$f")" -eq 0 || ok=0; done; done; test "$ok" -eq 1

- [ ] **AC5** **Every repository-relative path the corpus or the ledger names
  resolves.** Tokens under `bin/`, `docs/`, `templates/`, `agents/`, `skills/`,
  `tests/` or `.shell-team/` ending in a known extension must exist on disk. Glob
  and placeholder forms (`agents/*.md`, `<path>`) cannot match the token class at
  all, so they are skipped by construction rather than by an exception list. At
  least three tokens must be found, so an extraction that matched nothing cannot
  report success.
  - check: ok=1; hits=0; for f in .shell-team/lessons.md docs/loop-engineering/lessons-import-disposition.md; do test -s "$f" || { ok=0; continue; }; for p in $(grep -oE '(bin|docs|templates|agents|skills|tests|\.shell-team)/[A-Za-z0-9_./-]+\.(md|sh|ya?ml|txt|json)' "$f" | sort -u); do hits=$((hits + 1)); test -e "$p" || ok=0; done; done; test "$ok" -eq 1 && test "$hits" -ge 3

- [ ] **AC6** **Every `Source` value is `n/a` or an existing
  repository-relative path.** The fence's angle-bracket placeholder is skipped
  (it is the only value containing `<`, which is why the header contract requires
  that shape). At least five values are read, so an empty extraction cannot pass.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=1; L=.shell-team/lessons.md; test -s "$L" || ok=0; sed -n 's/^- \*\*Source\*\*: *//p' "$L" > "$F/src" 2>/dev/null; n="$(grep -c . "$F/src")"; test "$n" -ge 5 || ok=0; while IFS= read -r v; do v="$(printf '%s' "$v" | sed 's/[[:space:]]*$//')"; case "$v" in n/a) continue ;; *'<'*) continue ;; esac; test -e "$v" || ok=0; done < "$F/src"; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC7** **The ledger's import table is formally complete: 79 rows, one per
  source entry, with a closed outcome enum and contiguous per-date sequence
  numbers.** The row count is pinned twice — once by the date-prefix shape and
  once by the full row shape, so a row that is present but malformed cannot hide
  inside the count — the 79 `date`+`seq` pairs are unique, and for every date the
  sequence numbers are exactly `1..n` (proved by both the maximum and the sum,
  which no gap or duplicate can satisfy together).
  - check: D=docs/loop-engineering/lessons-import-disposition.md; test -s "$D" && test "$(grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$D")" -eq 79 && test "$(grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \| [0-9]+ \| (loop|maintainer|operator-global|drop) \| [^|]+ \| [^|]+ \|$' "$D")" -eq 79 && test "$(grep -E '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$D" | awk -F'|' '{ gsub(/ /, "", $2); gsub(/ /, "", $3); print $2 "@" $3 }' | sort -u | wc -l | tr -d ' ')" -eq 79 && grep -E '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$D" | awk -F'|' '{ d = $2; s = $3; gsub(/ /, "", d); gsub(/ /, "", s); c[d]++; if (s + 0 > m[d]) m[d] = s + 0; t[d] += s + 0 } END { bad = 0; for (k in c) { if (m[k] != c[k]) bad = 1; if (t[k] != c[k] * (c[k] + 1) / 2) bad = 1 } exit bad }'

- [ ] **AC8** **The ledger and the corpus agree in both directions, and no row
  is half-retained.** Every `loop`/`maintainer` row's destination is a corpus
  entry key whose date equals the row's own date; every `operator-global`/`drop`
  row's destination is exactly `n/a`; and the sorted multiset of retained
  destinations is byte-identical to the sorted multiset of corpus entry keys —
  which pins the count, the 1:1 mapping and the absence of duplicates in one
  comparison. Both lists are asserted non-empty first, so two empty files cannot
  compare equal.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; D=docs/loop-engineering/lessons-import-disposition.md; L=.shell-team/lessons.md; { test -s "$D" && test -s "$L" && grep -E '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$D" | awk -F'|' 'BEGIN { bad = 0 } { dt = $2; o = $4; d = $6; gsub(/^ +| +$/, "", dt); gsub(/^ +| +$/, "", o); gsub(/^ +| +$/, "", d); if (o == "loop" || o == "maintainer") { if (index(d, dt " ") != 1) bad = 1; print d } else if (d != "n/a") bad = 1 } END { exit bad }' > "$F/dest" && sort "$F/dest" > "$F/dest.s" && grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2} — ' "$L" | sed 's/^## //' | sort > "$F/keys.s" && test -s "$F/dest.s" && test -s "$F/keys.s" && cmp -s "$F/dest.s" "$F/keys.s"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC9** **The first retro's nine candidates each have a recorded
  disposition, and the retro's own classification decides scope rather than being
  discarded.** Exactly nine candidate rows, with the label distribution the retro
  actually carries (6 `[common]`, 3 `[target-specific]`); the outcome column
  closed to five values; **no `[common]` row routed to `maintainer` and no
  `[target-specific]` row routed to `loop`**; every promoted row's destination
  resolving to a corpus entry heading and every other row's destination exactly
  `n/a`.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; D=docs/loop-engineering/lessons-import-disposition.md; L=.shell-team/lessons.md; { test -s "$D" && test -s "$L" && test "$(grep -cE '^\| [0-9]+ \| \[(common|target-specific)\] \| (loop|maintainer|operator-global|drop|already-covered) \| [^|]+ \| [^|]+ \|$' "$D")" -eq 9 && test "$(grep -cE '^\| [0-9]+ \| \[common\] \|' "$D")" -eq 6 && test "$(grep -cE '^\| [0-9]+ \| \[target-specific\] \|' "$D")" -eq 3 && test "$(grep -cE '^\| [0-9]+ \| \[common\] \| maintainer \|' "$D")" -eq 0 && test "$(grep -cE '^\| [0-9]+ \| \[target-specific\] \| loop \|' "$D")" -eq 0 && grep -E '^\| [0-9]+ \| \[' "$D" | awk -F'|' '{ o = $4; d = $6; gsub(/^ +| +$/, "", o); gsub(/^ +| +$/, "", d); if (o == "loop" || o == "maintainer") print d }' > "$F/keys" && grep -E '^\| [0-9]+ \| \[' "$D" | awk -F'|' '{ o = $4; d = $6; gsub(/^ +| +$/, "", o); gsub(/^ +| +$/, "", d); if (o != "loop" && o != "maintainer") print d }' > "$F/na" && bad=0; while IFS= read -r v; do grep -qxF "## $v" "$L" || bad=1; done < "$F/keys"; while IFS= read -r v; do test "$v" = "n/a" || bad=1; done < "$F/na"; test "$bad" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC10** **The shape-level PII gate is green over a change set that
  actually contains the two new files.** `bin/check-pii-shapes.sh --base develop`
  exits 0 **and** both the corpus and the ledger are in the change set it scans —
  without the second half this criterion would be the vacuous "green before the
  work starts" assertion #23 warns about by name.
  - check: bash bin/check-pii-shapes.sh --base develop >/dev/null && test "$(git diff --name-only develop -- .shell-team/lessons.md docs/loop-engineering/lessons-import-disposition.md | wc -l | tr -d ' ')" -eq 2

- [ ] **AC11** **The named-entity scrub attestation is recorded, naming every
  class searched and stating the result, without committing a single search
  term.** This criterion proves the **record exists and is complete in form** —
  all six class names, the zero-remaining statement, and the explicit statement
  that the search terms are not recorded. It proves nothing about the property
  itself; that is AC12.
  - check: D=docs/loop-engineering/lessons-import-disposition.md; test -s "$D" && grep -qF 'employer and customer names' "$D" && grep -qF 'internal ticket identifiers' "$D" && grep -qF 'hostnames' "$D" && grep -qF 'personal names' "$D" && grep -qF 'pre-publication task and issue numbers' "$D" && grep -qF 'home-directory absolute paths' "$D" && grep -qF 'zero remaining across all six classes' "$D" && grep -qF 'search terms are not recorded here' "$D"

- [ ] **AC12** **No named entity survives anywhere in the imported surface** —
  the corpus, the ledger (including every `operator-global` and `drop` row's
  reason), and the four generated blocks carry no employer or customer name, no
  internal ticket identifier, no hostname, no personal name, no pre-publication
  task or issue number, and no home-directory absolute path. **Attestation, not
  an exit code, deliberately: no checker can see this class**, and writing it as
  a `check:` would produce exactly the vacuous green #23 names. Verified by the
  engineer's recorded sweep (AC11) and independently by qa-verifier, who
  re-derives the sweep over all six classes and never transcribes a real value
  into the hand-off. `bin/check-pii-shapes.sh` being green (AC10) is **not**
  evidence for this criterion.

- [ ] **AC13** **Every retained entry means in English what it meant in
  Japanese, and every source entry is accounted for.** **Process, not an exit
  code**: Codex cannot read the source corpus, so qa-verifier is the sole holder
  of this check and it is not delegable. Required: all 79 ledger rows audited
  against the source file; at least three entries selected adversarially (the
  longest `Rule`, the one carrying the most conditional clauses, one whose
  Japanese carried a parenthetical qualification) and read for semantic
  equivalence; every closed-enum value (`Category`, `Applies-to`, `Status`)
  confirmed carried across unchanged; and the regen-diff step proved non-vacuous
  by mutating one `Rule` in the corpus, observing the CI step FAIL, and restoring
  from a pre-mutation file copy verified byte-identical.

- [ ] **AC14** **Zero maintainer leakage: no `Scope: maintainer` entry's `Rule`
  text appears in any generated block.** The maintainer rules are extracted from
  the corpus by an entry-buffering pass (so field order inside an entry cannot
  change the answer), the extraction is asserted non-empty — which also pins that
  the import produced at least one maintainer entry — and a `loop` rule is
  asserted **present** in at least one block as the positive control that the
  extraction and the greps are looking at real content.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; L=.shell-team/lessons.md; P=templates/prompt-blocks; rules() { awk -v want="$1" '/^## [0-9]/ { if (n > 0 && sc == want && rule != "") print rule; sc = ""; rule = ""; n++ } /^- \*\*Scope\*\*: / { sc = $0; sub(/^- \*\*Scope\*\*: */, "", sc); sub(/[[:space:]]*$/, "", sc) } /^- \*\*Rule\*\*: / { rule = $0; sub(/^- \*\*Rule\*\*: */, "", rule) } END { if (n > 0 && sc == want && rule != "") print rule }' "$2"; }; { test -s "$L" && rules maintainer "$L" > "$F/m" && rules loop "$L" > "$F/l" && test -s "$F/m" && test -s "$F/l" && bad=0; while IFS= read -r r; do for b in "$P/playbook-engineer.md" "$P/playbook-qa-verifier.md" "$P/playbook-tech-lead.md" "$P/playbook-pm-spec.md"; do grep -qF -- "$r" "$b" && bad=1; done; done < "$F/m"; r1="$(head -1 "$F/l")"; found=0; for b in "$P/playbook-engineer.md" "$P/playbook-qa-verifier.md" "$P/playbook-tech-lead.md" "$P/playbook-pm-spec.md"; do grep -qF -- "$r1" "$b" && found=1; done; test "$bad" -eq 0 && test "$found" -eq 1; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC15** **Every `Bound-in` target exists in this repository.** T-1007's
  checker validates the value's shape only and never touches the filesystem, on
  purpose — but here the filesystem *is* knowable, so the real corpus's pointers
  are resolved. At least one value is read (the same floor AC14 pins from the
  other side).
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=1; L=.shell-team/lessons.md; test -s "$L" || ok=0; test "$(grep -cF -- '- **Scope**: maintainer' "$L")" -ge 1 || ok=0; sed -n 's/^- \*\*Bound-in\*\*: *//p' "$L" > "$F/b" 2>/dev/null; n=0; while IFS= read -r v; do v="$(printf '%s' "$v" | sed 's/[[:space:]]*$//')"; case "$v" in *'<'*) continue ;; '') continue ;; esac; n=$((n + 1)); test -e "$v" || ok=0; done < "$F/b"; test "$n" -ge 1 || ok=0; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC16** **The blocks and their consumers are in sync, and every role got
  a real playbook.** `bin/check-prompt-sync.sh` exits 0; all four blocks are
  non-empty; none carries the generator's "no active entries" fallback line —
  every one of the four IN roles receives at least one shipped entry. **Two-sided
  invariant lock: true before this task and required to still be true after it**,
  which is what makes it a regression detector rather than a change detector.
  - check: ok=1; for b in templates/prompt-blocks/playbook-engineer.md templates/prompt-blocks/playbook-qa-verifier.md templates/prompt-blocks/playbook-tech-lead.md templates/prompt-blocks/playbook-pm-spec.md; do test -s "$b" || ok=0; grep -q '^- ' "$b" || ok=0; test "$(grep -cF '(no active entries currently apply to this role)' "$b")" -eq 0 || ok=0; done; test "$ok" -eq 1 && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC17** **Regeneration is a fixed point.** Regenerating into a scratch
  root from the resolved corpus reproduces all four canonical blocks and all four
  consumers byte-identically. The file set is **derived from
  `templates/prompt-blocks/registry.txt`**, not written down, and pinned at eight
  entries so a derivation that collapsed to nothing cannot pass; the real tree is
  only read.
  - check: F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; { L="$(env -u TEAM_RUN_BASE bash bin/team-paths.sh --get lessons)" && test -r "$L" && files="$(awk '$1 == "marker" && $2 ~ /^playbook-/ { for (i = 3; i <= NF; i++) print $i; print "templates/prompt-blocks/" $2 }' templates/prompt-blocks/registry.txt | sort -u)" && test "$(printf '%s\n' "$files" | wc -l | tr -d ' ')" -eq 8 && cpok=1; for f in $files; do mkdir -p "$F/repo/$(dirname "$f")" || cpok=0; cp "$f" "$F/repo/$f" || cpok=0; done; mkdir -p "$F/repo/templates/prompt-blocks" && cp templates/prompt-blocks/registry.txt "$F/repo/templates/prompt-blocks/registry.txt" && test "$cpok" -eq 1 && env -u TEAM_RUN_BASE bash bin/gen-playbook-blocks.sh --root "$F/repo" --lessons "$L" >/dev/null 2>&1 && bad=0; for f in $files; do cmp -s "$f" "$F/repo/$f" || bad=1; done; test "$bad" -eq 0; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC18** **CI validates the corpus at the resolver-derived path, and the
  step is fail-closed.** The workflow carries a step whose name begins with
  `Dogfood check-playbook`; its body names no lessons-path literal in either
  layout, resolves the path through `--get lessons`, guards on readability, and
  **exits 0 when extracted from the YAML and executed** — so the criterion tests
  the step itself rather than a paraphrase of it.
  - check: W=.github/workflows/check-handoff.yml; F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; { N="$(grep -n '^      - name: Dogfood check-playbook' "$W" | head -1 | cut -d: -f1)" && test -n "$N" && awk -v s="$N" 'NR > s { if ($0 ~ /^      - name: /) exit; print }' "$W" > "$F/raw" && sed -e 's/^ *run: |$//' -e 's/^ *run: //' -e 's/^          //' "$F/raw" > "$F/step.sh" && grep -q '[A-Za-z]' "$F/step.sh" && grep -qF -- '--get lessons' "$F/step.sh" && grep -qE 'test -[rsf] ' "$F/step.sh" && test "$(grep -cF '.shell-team/lessons.md' "$F/step.sh")" -eq 0 && test "$(grep -cF 'tasks/lessons.md' "$F/step.sh")" -eq 0 && bash "$F/step.sh" >/dev/null 2>&1; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC19** **CI proves provenance: it regenerates into a scratch copy and
  diffs all four blocks and all four consumers, without literals and without
  touching the tree.** The step's name begins with `Dogfood gen-playbook-blocks`;
  its body derives the file set from `registry.txt`, resolves the corpus through
  `--get lessons`, names no lessons-path literal, and exits 0 when extracted and
  executed. The eight files' checksums before and after that execution are
  compared, so a step that "diffs" by regenerating in place fails this criterion.
  - check: W=.github/workflows/check-handoff.yml; F="$(mktemp -d "${TMPDIR:-/tmp}/t1008.XXXXXX")"; ok=0; { files="$(awk '$1 == "marker" && $2 ~ /^playbook-/ { for (i = 3; i <= NF; i++) print $i; print "templates/prompt-blocks/" $2 }' templates/prompt-blocks/registry.txt | sort -u)" && test "$(printf '%s\n' "$files" | wc -l | tr -d ' ')" -eq 8 && s1="$(for f in $files; do cksum < "$f"; done | cksum)" && N="$(grep -n '^      - name: Dogfood gen-playbook-blocks' "$W" | head -1 | cut -d: -f1)" && test -n "$N" && awk -v s="$N" 'NR > s { if ($0 ~ /^      - name: /) exit; print }' "$W" > "$F/raw" && sed -e 's/^ *run: |$//' -e 's/^ *run: //' -e 's/^          //' "$F/raw" > "$F/step.sh" && grep -q '[A-Za-z]' "$F/step.sh" && grep -qF -- '--get lessons' "$F/step.sh" && grep -qF 'registry.txt' "$F/step.sh" && test "$(grep -cF '.shell-team/lessons.md' "$F/step.sh")" -eq 0 && test "$(grep -cF 'tasks/lessons.md' "$F/step.sh")" -eq 0 && bash "$F/step.sh" >/dev/null 2>&1 && s2="$(for f in $files; do cksum < "$f"; done | cksum)" && test "$s1" = "$s2"; } && ok=1; rm -rf "$F"; test "$ok" -eq 1

- [ ] **AC20** **#58 is closed by equality, not by paraphrase: the generator's
  header names the CI step that exists.** The step's exact name is **derived from
  the workflow** (never written down here, so the criterion cannot go stale) and
  must appear verbatim in `bin/gen-playbook-blocks.sh`; the old claim of a step
  that does not exist is gone, with the derivation itself as the positive
  control.
  - check: W=.github/workflows/check-handoff.yml; S="$(grep -m1 '^      - name: Dogfood gen-playbook-blocks' "$W" | sed 's/^      - name: //')"; test -n "$S" && grep -qF -- "$S" bin/gen-playbook-blocks.sh && test "$(grep -cF 'CI adds a freshness dogfood step' bin/gen-playbook-blocks.sh)" -eq 0

- [ ] **AC21** **#57 is closed and the file's frozen pins survive.**
  `agents/scrum-master.md` no longer claims `there is no resolver key for it`,
  states the resolver form `team-paths.sh --get lessons`, still carries exactly
  **18** top-level numbered items (T-1003's frozen AC16), still carries its
  canonical `- input: lessons` line, and `bin/check-prompt-sync.sh` is green (its
  four `contain`-mode blocks intact).
  - check: f=agents/scrum-master.md; test -s "$f" && grep -qF 'team-paths.sh --get lessons' "$f" && grep -qF -- '- input: lessons' "$f" && test "$(grep -cF 'there is no resolver key for it' "$f")" -eq 0 && test "$(grep -cE '^[0-9]+\. ' "$f")" -eq 18 && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC22** **The same-class pointer in `skills/review-response/SKILL.md` is
  corrected too.** Measured: that file does **not** carry #57's false clause — it
  carries a bare legacy-layout pointer (`proposes a tasks/lessons.md entry`),
  which is the same class of stale reference and is inside the class this task
  closes. Zero `tasks/lessons.md` literals remain; the resolver form is present
  as the positive control.
  - check: f=skills/review-response/SKILL.md; test -s "$f" && grep -qF 'team-paths.sh --get lessons' "$f" && test "$(grep -cF 'tasks/lessons.md' "$f")" -eq 0

- [ ] **AC23** **The dogfood assertion `tests/check-playbook/run.sh` has
  advertised since T-045 exists, runs against the resolved path, and the suite is
  green.** The suite prints the labelled case (so a case that exists but is never
  reached cannot satisfy this), names the resolver rather than a literal, and
  carries no `tasks/lessons.md` reference in its own prose — its three
  occurrences today are the false claim on line 6 and two comments that this
  repository's layout has made inaccurate.
  - check: s=tests/check-playbook/run.sh; test -s "$s" && grep -qF 'team-paths.sh --get lessons' "$s" && test "$(grep -cF 'tasks/lessons.md' "$s")" -eq 0 && out="$(bash "$s" 2>&1)"; rc=$?; test "$rc" -eq 0 && printf '%s\n' "$out" | grep -qF 'T-1008: the real repository corpus at the resolved lessons path passes (dogfood)'

- [ ] **AC24** **The cross-suite `NOT_APPLY` pin is re-measured rather than
  assumed, the warning is untouched, and the hazard is written down.** The
  registry entry for `bin/gen-playbook-blocks.sh`'s line-count warning names the
  line number that line actually has now, with the quoted source text after the
  second colon byte-identical; `LINE_WARN_THRESHOLD` is still `40`;
  `tests/errexit-safe/run.sh` exits 0; and `.shell-team/test-recipe.md` gains a
  T-1008 entry (the pre-existing T-1007 entry is the positive control that the
  file was appended to, not replaced). The line number is derived here rather
  than written down, so the criterion cannot go stale by construction. This exact
  class cost T-1006 a rework round and a re-freeze; this task's header edit moves
  the same line again.
  - check: N="$(grep -n '"\$role" "\$line_count" "\$LINE_WARN_THRESHOLD"' bin/gen-playbook-blocks.sh | head -1 | cut -d: -f1)"; test -n "$N" && L="$(sed -n "${N}p" bin/gen-playbook-blocks.sh)" && test -n "$L" && grep -qF "gen-playbook-blocks.sh:${N}:${L}" tests/errexit-safe/run.sh && grep -qxF 'LINE_WARN_THRESHOLD=40' bin/gen-playbook-blocks.sh && grep -qF 'T-1008' .shell-team/test-recipe.md && grep -qF 'T-1007' .shell-team/test-recipe.md && bash tests/errexit-safe/run.sh >/dev/null

- [ ] **AC25** **The codex-skeleton-hygiene suite is green after regeneration.**
  That suite forward-locks the live `agents/qa-verifier.md` against two extended
  regexes, and this task rewrites that file's playbook marker region with
  translated `Rule` text — a translated rule that happens to spell a broken
  invocation shape or a stateful sentinel would red this suite in CI while every
  playbook suite stayed green. **Two-sided invariant lock: green before this task
  and required to still be green after it.**
  - check: bash tests/codex-skeleton-hygiene/run.sh >/dev/null

- [ ] **AC26** **`bin/` changes are comment-only, and no `bin/` file is added.**
  Exactly one file under `bin/` differs from the base ref, none is added, and
  **every** changed line under `bin/` is a comment line — which is how "#58 is a
  wording fix, not a logic change" becomes a tested property. At least two
  comment lines changed, so an empty diff cannot satisfy the first half.
  `shellcheck` stays clean on the touched scripts. **Merge-point-scoped against
  `902c465` and expected to go stale after merge** — do not widen its base-ref
  resolution or re-derive it per rework round.
  - check: test "$(git diff --name-only --diff-filter=A 902c465 -- bin/ | wc -l | tr -d ' ')" -eq 0 && test "$(git diff --name-only 902c465 -- bin/ | wc -l | tr -d ' ')" -eq 1 && test "$(git diff -U0 902c465 -- bin/ | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -cE '^[+-][[:space:]]*#')" -ge 2 && test "$(git diff -U0 902c465 -- bin/ | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vcE '^[+-][[:space:]]*#')" -eq 0 && shellcheck bin/gen-playbook-blocks.sh tests/check-playbook/run.sh

- [ ] **AC27** **The diff is confined to this task's allow-list.** Every changed
  path is on the list below and the diff is non-empty. The list carries this
  task's mechanically-forced companions **from the start** —
  `tests/errexit-safe/run.sh` (its pin is forced to move by the header edit),
  `.shell-team/test-recipe.md`, and the four `agents/*.md` consumers the
  generator rewrites — plus the artefacts this task is certain to produce
  (provenance, review record, interventions file, this spec, the board).
  **Merge-point-scoped against `902c465` and expected to go stale after merge**;
  do not widen or re-derive it.
  - check: L="$(git diff --name-only 902c465)"; test -n "$L" && test "$(printf '%s\n' "$L" | grep -vcE '^(\.shell-team/lessons\.md|docs/loop-engineering/lessons-import-disposition\.md|templates/prompt-blocks/playbook-(engineer|qa-verifier|tech-lead|pm-spec)\.md|agents/(engineer|qa-verifier|tech-lead|pm-spec|scrum-master)\.md|skills/review-response/SKILL\.md|bin/gen-playbook-blocks\.sh|\.github/workflows/check-handoff\.yml|tests/check-playbook/run\.sh|tests/errexit-safe/run\.sh|\.shell-team/test-recipe\.md|\.shell-team/todo\.md|\.shell-team/specs/T-1008-lessons-corpus-import\.md|\.shell-team/provenance/T-1008\.md|\.shell-team/reviews/T-1008\.md|\.shell-team/interventions/T-1008\.md)$')" -eq 0

## Input space

**Reachable input classes** — what real usage produces, and what this change must
therefore be correct about.

1. **The source corpus exactly as measured on 2026-07-31**: 746 lines, **79**
   entries (`## <date> — <title>` headings), 76 `active` / 3 `superseded`, three
   `Superseded-by` pointers that all resolve, one `Extended by` bullet, zero
   home-path shapes, zero mailbox shapes, five lines carrying #8's banned
   vocabulary, and no `Scope` field anywhere (so it fails today's checker until
   the import assigns one). If a re-measurement disagrees with these numbers, the
   numbers are re-pinned before anything else — the ledger's `79` is derived from
   this measurement, not from #23's table.
2. **Entry bodies at the extremes the source actually contains**: one entry whose
   `Why` runs to several thousand characters with nested parentheticals; entries
   whose `Rule` embeds backticked code, an arrow (`→`), an em dash, a
   `[[wiki-style]]` cross-reference to another entry's title, and inline shell
   fragments; one entry whose field order puts `Source` before `Status`; four
   entries sharing one date.
3. **Mixed-scope corpora after triage**: `loop` and `maintainer` interleaved,
   maintainer entries bound to `CONTRIBUTING.md` and `.shell-team/test-recipe.md`,
   and per-role subsets where one role's shipped set is much smaller than
   another's.
4. **Generated blocks well past `LINE_WARN_THRESHOLD`.** With dozens of shipped
   entries, every role's block exceeds 40 lines and the generator warns on
   stderr. The warning is expected output, not a failure.
5. **Translated `Rule` text that collides with a live-file lock.** Two extended
   regexes in `tests/codex-skeleton-hygiene/run.sh` scan the live
   `agents/qa-verifier.md` for a broken-invocation shape
   (`(bash|sh|source|.) bin/check-(provenance|interventions).sh`) and for
   stateful sentinels (`provenance-gate:AC<n>`, `route-back through loop-guard`).
   The source corpus contains entries about the provenance checker and about
   loop-guard STOPs, so a natural English translation can produce exactly those
   shapes and splice them into that file.
6. **Both layouts, and a path resolved rather than assumed.** The corpus is read
   through `bin/team-paths.sh --get lessons`; the same corpus is validated from
   the repository root, from a scratch `--root`, and through
   `--lessons <explicit path>` (which short-circuits the resolver entirely).
7. **Both hosts.** Local macOS/BSD userland (where `mktemp` needs an explicit
   template and BSD `grep` lacks `-P`) and CI's ubuntu/GNU userland. Every
   criterion and every CI step has to hold on both.
8. **The nine retro candidates** as the retro actually wrote them: 6 `[common]`,
   3 `[target-specific]`, one of which restates a lesson the imported corpus
   already carries (an `already-covered` disposition is a real outcome, not an
   edge case), and one whose only source is an issue rather than a repository
   artefact.
9. **Non-retained entries whose reason has to be written without their
   content** — the `operator-global` and `drop` rows, where the ledger records
   why an entry did not cross without transcribing what it said.

**Out-of-scope synthetic extremes** — named and declined.

1. **Adversarially large corpora** — hundreds of entries, a single `Rule` of
   many kilobytes, per-role blocks in the thousands of lines. The import is
   bounded by the 79 entries that exist; prompt-size policy is
   `LINE_WARN_THRESHOLD`'s, and it is untouched.
2. **Corpora with NUL bytes, CRLF endings, non-UTF-8 bytes, unterminated fences,
   forged headings, or reserved marker strings inside a field value.**
   `bin/check-playbook.sh`'s and T-045's declared surface, covered by their own
   suites and not re-tested here.
3. **Adversarial corpus content designed to break the marker splice or escape the
   generated region.** T-045/T-047 own that threat model; this task adds no new
   parsing.
4. **Adopter corpora and any migration path.** No adopter corpus exists (#23's
   measurement), which is exactly why `Scope` could be made required with no
   migration.
5. **Round-trip translation quality metrics, machine-translation scoring, or
   any measure of "how good" the English is** beyond semantic equivalence judged
   by a reader (AC13). There is no metric here and none is claimed.
6. **Non-Latin content in future entries.** AC2's byte rule governs this import;
   whether a future adopter's corpus may carry another script is that adopter's
   decision and a later spec's problem.
7. **The old repository's other files** — board, project-status, retros,
   reviews, provenance — and its git history. Only the current state of the one
   lessons file crosses.
8. **Where `operator-global` knowledge ends up.** Out of this repository by
   definition; no criterion can observe it and none pretends to.
9. **Concurrent promotions, or a second writer appending to the corpus while
   this import runs.** Not introduced by this change.
10. **Cross-file supersession or scope resolution.** Every reference check is
    per-file, unchanged since T-108 DP-7.

<!-- END intent-block: T-1008 -->

## Resolved design decisions

### DP-1 — the ledger is a first-class git-tracked deliverable, keyed by date plus sequence

The disposition of 79 entries is the only durable answer to "why is this rule not
in the corpus?", and #23's own root-cause analysis is that the criterion for
where knowledge goes **was never recorded anywhere**. A hand-off summary does not
survive; a tracked file does.

**Keyed by date plus a per-date sequence number, never by the untranslated
title.** Three reasons, in order of weight: a title transcribed before
translation carries the exact content the task exists to convert, into the file
that records the conversion (and would break AC2 by construction); a
post-translation title in the key column would make the ledger a second copy of
the corpus keys, free to drift; and the source has four entries sharing one date,
so the date alone is not a key. `date` + `seq` is derivable from the source by
anyone holding it, in file order, with no judgement — which is what makes
qa-verifier's completeness audit possible at all.

**Two tables in one file.** The 79-row import ledger and the 9-row retro
candidate disposition answer the same question about two input sets; splitting
them would invite one to be updated without the other. Their row shapes are
disjoint by construction (a date-leading cell versus an integer-leading cell), so
the criteria can count each without seeing the other.

### DP-2 — three verification layers, and two of them are deliberately not exit codes

Stated in full in the Acceptance criteria section above, and repeated here as a
decision because the temptation to "make it mechanical" is exactly the failure
mode. `bin/check-pii-shapes.sh` is green on the source **before any work starts**
and would stay green after a careless translation; an acceptance criterion of the
form "the PII gate is clean" is therefore vacuous for this task, which is why
AC10 pins the gate **plus** the fact that the two new files are inside the change
set it scanned. Named-entity absence (AC12) and semantic fidelity (AC13) carry no
`check:` at all: `bin/check-acs.sh` reports them `SKIP`, and that SKIP is the
honest signal — a green exit code there would be a claim no command can support.

### DP-3 — "translated to English" is a byte-level property, mechanically checked

A partial translation is the likeliest failure of a 79-entry import: the entries
an engineer reads last are the ones that stay Japanese. AC2 therefore tests the
UTF-8 lead-byte range `0xE3`–`0xEF` (kana, CJK ideographs, full-width forms) and
requires zero across the corpus, the ledger and all four blocks — with the
pattern proved live against a probe, because a byte-range pattern that silently
matched nothing would report every file clean. `0xE2`, which carries the em dash
this repository's entry keys depend on and the arrows and quotes its prose uses,
is deliberately outside the range. `grep -P` is not available on BSD grep, which
is why the check is a `LC_ALL=C` byte range and not a Unicode property class.

### DP-4 — `Source` is `n/a` or an existing path, and no bare `#<number>` survives

#23's constraint and T-113's de-identification rule agree: a lesson records the
pattern and the reason it recurs, and `Source` points at an artefact in **this**
repository or is `n/a`. Old-repository task and issue numbers are neither.

The stricter half — **no bare `#<number>` reference in the imported corpus, in
any generated block, or in any ledger table row** (the ledger's own prose may
cite this repository's tracker; a row's reason is where an imported entry's
references would land, so rows carry none) — follows from a measurement, not from
taste:
an old repository's `#299` and this repository's `#23` are the same shape, so no
mechanical rule can distinguish them, and a rule that cannot be checked is the
convention #23 refuted. The cost is small and one-sided: an imported entry cites
a durable in-repository anchor (a path, a heading, an AC label) instead of a
number, which is what this repository's own provenance lesson already prescribes.
The same argument covers `T-<three digits>`: `CLAUDE.md` §Task IDs states that
those ids name a pre-publication history a reader cannot open, and §Hygiene
forbids **adding** internal task or issue references to this public repository.
This repository's own `T-111`/`T-112`/`T-113` are the sole exception, because they
have real board entries and review artefacts here.

### DP-5 — operating artefacts are named in resolver form, and every path must resolve

`CLAUDE.md` §Working rules requires operating paths to be resolved through
`bin/team-paths.sh` and never hardcoded, and the corpus is about to be read by
agents in repositories using either layout. So an imported entry names the board,
the corpus, the specs directory or the reviews directory by resolver key or by
its default-layout path — never as a bare legacy literal (AC4).

The **existence** half (AC5) is grounded in a measurement rather than a
principle: the source corpus's own header points at
`docs/loop-engineering/playbook-update-path.md`, and **issue #23 quotes that same
path** — and it does not exist in this repository (measured 2026-07-31;
`docs/loop-engineering/` holds `goal-loop.md`, `goal-loop.ja.md` and a crontab
example). `docs/specs/…` does not exist either; specs live under
`.shell-team/specs/`. Importing those references verbatim would ship a corpus
whose pointers dangle on arrival, which is the same defect as #57 and #58 in a
new file. AC5 makes it impossible to ship one.

Deliberately **excluded** from both halves: fixture occurrences under
`tests/*/fixtures/`, fixture corpora suites build inline, the generic prose
mentions in `bin/` that T-1006's engineer judged non-false, and the retro
template's decorated heading. Those are legitimate legacy-layout representations
or issue #20's scope. The boundary is drawn by class, not by count: the token
`tasks/lessons.md` appears in 54 files today, most of them inside generated
marker regions that follow regeneration automatically, and re-counting that total
is not a property worth pinning.

### DP-6 — `[common]` maps to `loop`, `[target-specific]` never does

`agents/scrum-master.md` has classified retro candidates `[common]` (applies to
any repository using the agent) / `[target-specific]` (tied to this repository)
since before T-1007, and T-1007 built `--scope` precisely so the label survives
promotion. The mapping is therefore not a new invention but the bridge those two
mechanisms were built for:

| Label | May become | Must never become |
|---|---|---|
| `[common]` | `loop`, `operator-global`, `drop`, `already-covered` | `maintainer` |
| `[target-specific]` | `maintainer`, `operator-global`, `drop`, `already-covered` | `loop` |

`[common]` may still route to `operator-global` — a lesson about tool behaviour
can apply to any repository and still belong outside this one — but it can never
be `maintainer`, which means "specific to developing this plugin", the direct
negation of the label. AC9 pins both prohibitions.

**`already-covered` is a fifth outcome for the candidate table only**, never for
the 79-row import ledger. It exists because at least one candidate restates a
lesson the imported corpus already carries, and recording that as `drop` would
lose the distinction between "not worth keeping" and "already kept". Which
candidates are adopted is per-candidate judgement and is **assigned to the
engineer**, not pre-decided here; what is fixed is that the disposition is
recorded, countable, and constrained by the table above.

### DP-7 — at least one `maintainer` entry, and every `Bound-in` target must exist

T-1007's checker validates `Bound-in`'s **shape** only and never reads the
filesystem, for reasons that remain correct (a checker's verdict must not depend
on its working directory). But this task's corpus is a specific file in a
specific repository, so its pointers can and should be resolved — AC15 does what
the checker deliberately cannot.

The floor of **one** maintainer entry is grounded rather than arbitrary: #23
measured ~30% of active entries as meaningful only when developing this plugin
and names the classes — the release procedure (`.claude-plugin/plugin.json` plus
the README badge), this repository's CI shellcheck behaviour. Those bind to
`CONTRIBUTING.md` or `.shell-team/test-recipe.md` and are unambiguously not
`operator-global` (they are not cross-project) and not `drop` (they are live).
An import that produced zero maintainer entries would mean T-1007's entire
`Bound-in` mechanism shipped unused, which is a signal to re-examine the triage,
not an outcome to accept silently. This is a floor, not a target: **nothing here
licenses routing an entry to `maintainer` to satisfy a count**, and the same rule
#23 states for drops applies in every direction.

### DP-8 — #58 takes direction (b), and the header names the step verbatim

The routing map's decision, adopted: build the step rather than delete the claim,
because a regen-diff lock is what makes "the shipped blocks were generated from
the corpus" a fact instead of a promise — and it can only exist once a corpus
does.

The **equality** shape is this spec's addition, and it is grounded in this
repository's own lesson that a text lock built on containment degrades into
whack-a-mole: the header must contain the workflow step's **exact name string**,
and AC20 derives that string from the workflow rather than restating it. A
paraphrase ("CI regenerates and diffs") would drift the moment the step is
renamed and no check would notice.

### DP-9 — three frozen criteria of merged tasks are declared intentionally stale

Stated explicitly rather than left for a reviewer to infer:

| Frozen criterion | Why it is stale now |
|---|---|
| T-1006 AC18 — `agents/scrum-master.md` byte-unchanged | It recorded DP-7's deferral of the false clause; #57 is that deferral being paid off, and T-1006's own board line names this task's tracker as the natural carrier |
| T-1007 AC15 — blocks and consumers byte-unchanged | It proved "zero corpus, zero prompt churn" for the mechanism half; regenerating them is this half's whole point |
| T-1007 AC19 — nothing at the resolved lessons path | Same split; T-1007's spec already declares it "expected to go stale the moment the corpus lands" |

None of these is re-litigated and none is edited: a merged task's frozen intent
stays as it was written. This table records that the staleness is deliberate and
predicted, which is the difference between a design decision and a drift.

### DP-10 — the CI provenance step derives its file set and never mutates the tree

Two properties, both forced by measurement. **Derived, not hardcoded**: the four
blocks and four consumers are enumerated in
`templates/prompt-blocks/registry.txt`, and `bin/gen-playbook-blocks.sh` reads
that same file to decide where to splice. A step with eight literal paths would
silently stop covering a fifth role's block the day one is registered; deriving
from the registry cannot. (The registry forbids whitespace in consumer paths by
its own documented format, which is what makes iterating its output safe.)
**Scratch root, not in place**: the same step is run by the engineer and by
qa-verifier on a working tree they are mid-edit in, and a step that regenerates
in place to compare would rewrite files it was asked to check. `--root <scratch>`
plus `--lessons <resolved path>` reads the real corpus and writes only into the
scratch copy; `--lessons` also short-circuits the resolver, so the probe behaves
identically on a legacy-layout host. AC19 pins the no-mutation property with a
before/after checksum rather than trusting the wording.

### DP-11 — implementation order is fixed, because each step's verification needs the previous one

1. **The corpus** (translation, triage, `Scope`/`Bound-in`, scrub) —
   `bin/check-playbook.sh` green at the resolved path.
2. **The ledger** — 79 import rows plus the 9 candidate rows plus the
   attestation; the retro candidates promoted through
   `bin/playbook-promote.sh --scope …` (never appended by hand — the promoter's
   fail-closed re-validation is the single authority, and using it is what proves
   T-1007's `--scope` carries the label end to end).
3. **Regeneration** — all four blocks and all four consumers;
   `bin/check-prompt-sync.sh` green.
4. **The two CI steps** — validate, then regen-diff, both resolver-derived.
5. **`tests/check-playbook/run.sh`** — the advertised dogfood assertion made
   true.
6. **#57 and #58** — the two wording fixes, last, because #58's wording depends
   on the step name that now exists.
7. **The re-measured `tests/errexit-safe/run.sh` pin and the
   `.shell-team/test-recipe.md` entry** — immediately after step 6's header edit,
   never deferred to the end.

## Measured inventory (verified against the tree at `902c465`; re-verify before editing)

| Site | What it is | Disposition |
|---|---|---|
| `.shell-team/lessons.md` | resolver-derived corpus path | created (does not exist today) |
| `docs/loop-engineering/lessons-import-disposition.md` | the ledger | created; `docs/loop-engineering/` today holds only `goal-loop.md`, `goal-loop.ja.md`, `loop-cron.crontab.example` |
| `templates/prompt-blocks/playbook-{engineer,qa-verifier,tech-lead,pm-spec}.md` | canonical blocks, Japanese, generated from the old corpus | regenerated |
| `agents/{engineer,qa-verifier,tech-lead,pm-spec}.md` | `marker`-mode consumers (registry rows 42-45) | marker region regenerated; bytes outside it untouched by the generator |
| `agents/scrum-master.md:45` | `there is no resolver key for it` | #57 one-clause fix; 18 numbered items and four `contain`-mode blocks must survive |
| `skills/review-response/SKILL.md:116` | `proposes a tasks/lessons.md entry` — a legacy pointer, **not** #57's clause (measured) | reworded to resolver form |
| `bin/gen-playbook-blocks.sh:26-30` | claims a CI freshness step that does not exist | #58 direction (b): reworded to name the real step; **comment lines only** |
| `bin/gen-playbook-blocks.sh:213` | `LINE_WARN_THRESHOLD=40` | untouched; blocks will exceed it and warn, which is expected |
| `tests/errexit-safe/run.sh` | pins `gen-playbook-blocks.sh:<line>:<content>` | line-number token re-measured after the header edit; quoted content byte-identical |
| `tests/check-playbook/run.sh:6,150,203` | the false "AC5 dogfood" claim plus two now-inaccurate comments | claim made true; all three references corrected |
| `.github/workflows/check-handoff.yml` | 45 steps; `Dogfood team-paths` already asserts the `lessons` key resolves | two steps added; the shellcheck argument list already names both files this task touches (measured — no change needed) |
| `tests/codex-skeleton-hygiene/run.sh:1419-1424` | live-file lock: two extended regexes over `agents/qa-verifier.md` | not edited; run explicitly, because regeneration rewrites that file's marker region |
| `.shell-team/retros/2026-07-28.md` | 9 lesson candidates, 6 `[common]` / 3 `[target-specific]` | read-only input |
| `bin/check-playbook.sh:159-183` | `KNOWN_CATEGORIES` (7), `KNOWN_ROLES` (5), `KNOWN_STATUS` (2), `KNOWN_SCOPES` (2), `KNOWN_FIELD_NAMES` (11) | untouched; the corpus conforms to them |
| `templates/prompt-blocks/registry.txt:42-45` | the four `playbook-*` marker rows | untouched; read by the CI step to derive its file set |
| `docs/templates/retro-template.md` | decorated heading containing `tasks/lessons.md` | **not** changed — `bin/check-retro.sh` matches the heading by prefix and every committed retro reproduces it; issue #20's scope |
| `tests/*/fixtures/**`, `tests/gen-playbook-blocks/run.sh` (51 mentions) | legacy-layout fixture representations | untouched |

## Body-to-AC correspondence

| Body directive | Promoted to |
|---|---|
| The corpus lands at the resolver-derived path, as a real file | AC1 |
| The corpus passes `bin/check-playbook.sh` | AC1, AC23 (again through the suite's dogfood case) |
| The corpus header documents all eleven fields with angle-bracket placeholders and points at the ledger | AC1, AC6 (the placeholder shape is what lets the `Source` sweep skip the fence) |
| Everything is translated to English; no full-width character survives | AC2 |
| Closed enums (`Category`, `Applies-to`, `Status`, `Scope`) are never translated | AC1 (the checker rejects an unknown value), AC13 (read and confirmed carried across) |
| No pre-publication task identifier survives anywhere | AC3 |
| No bare `#<number>` survives in the corpus, the blocks, or any ledger row (the ledger's prose may cite this repository's tracker) | AC3 |
| Operating artefacts are named in resolver / default-layout form | AC4 |
| Every block's pointer text names the resolved path | AC4 |
| Every repository-relative path the corpus or ledger names resolves | AC5 |
| `Source` is `n/a` or an existing repository-relative path | AC6 |
| One ledger row per source entry, 79 rows, keyed date + per-date sequence | AC7 |
| The outcome column is closed to four values | AC7 |
| Sequence numbers are contiguous per date | AC7 |
| Ledger and corpus agree in both directions; non-retained rows carry `n/a` | AC8 |
| A retained row's destination date equals its own date | AC8 |
| The nine retro candidates each have a recorded disposition | AC9 |
| `[common]` never becomes `maintainer`; `[target-specific]` never becomes `loop` | AC9 |
| `already-covered` exists only in the candidate table | AC9 (the import-row regex does not admit it) |
| Non-retained rows carry no real value | AC10 (shape layer), AC11 + AC12 (the classes no checker sees) |
| The scrub is recorded as a class enumeration with a zero-remaining statement | AC11 |
| The search terms are never committed | AC11 (the attestation states it), AC12 (qa-verifier confirms no term list entered the tree) |
| The source corpus's absolute path is never transcribed into a tracked file | AC10 (a home-path shape in any changed file reds the gate), AC12 |
| No named entity survives | AC12 (attestation — deliberately not an exit code) |
| Every retained entry means in English what it meant in Japanese | AC13 (process — qa-verifier is the sole holder) |
| Every source entry is accounted for against the source | AC13 |
| The regen-diff step is proved non-vacuous by mutation | AC13 |
| Zero `maintainer` entries reach any block | AC14 |
| At least one `maintainer` entry exists | AC14, AC15 |
| Every `Bound-in` target exists | AC15 |
| `bin/check-prompt-sync.sh` stays green | AC16, AC21 |
| Every one of the four IN roles gets at least one shipped entry | AC16 |
| All four blocks and all four consumers are regenerated, not hand-edited | AC17 (regeneration is a fixed point — a hand edit breaks it), AC19 (CI keeps it that way) |
| CI validates the corpus at the resolver-derived path, fail-closed | AC18 |
| CI regenerates into a scratch copy and diffs all four blocks and all four consumers | AC19 |
| The CI steps name no lessons-path literal and derive the file set from the registry | AC18, AC19 |
| The CI steps do not mutate the working tree | AC19 (before/after checksum) |
| #58: the generator's header names the real step verbatim | AC20 |
| #57: the false clause is gone and the resolver form is stated | AC21 |
| `agents/scrum-master.md`'s 18 numbered items survive (T-1003's frozen AC16) | AC21 |
| The same-class pointer in `skills/review-response/SKILL.md` is corrected | AC22 |
| `tests/check-playbook/run.sh`'s advertised dogfood assertion becomes true | AC23 |
| The `tests/errexit-safe/run.sh` pin is re-measured, not assumed | AC24 |
| `LINE_WARN_THRESHOLD` is unchanged | AC24 (the value is pinned and the warning line's content is compared byte-identical through the re-measurement) |
| The hazard is recorded for the next engineer | AC24 (`.shell-team/test-recipe.md`) |
| The codex-skeleton-hygiene live-file locks survive regeneration | AC25 |
| Translated `Rule` text must not spell a broken-invocation shape or a stateful sentinel | AC25 |
| No schema change, no new `bin/` file, no logic change under `bin/` | AC26 |
| `bin/` stays shellcheck-clean | AC26 |
| The old repository's board, project-status, retros and reviews do not cross | AC27 (nothing outside the allow-list may enter the diff) |
| `docs/templates/retro-template.md`'s decorated heading is not rewritten | AC27 (the file is not on the allow-list) |
| Fixture occurrences of `tasks/lessons.md` stay | AC27 (no `tests/*/fixtures/**` path is on the allow-list) |
| Three frozen criteria of merged tasks are intentionally stale (DP-9) | info-only (not promoted to AC) — a merged task's frozen intent is not editable and no criterion here can observe another spec's frozen assertion; the table in DP-9 **is** the record, and AC17/AC19/AC21 are the positive evidence that the superseding behaviour shipped |
| The destination of `operator-global` knowledge is out of scope | info-only (not promoted to AC) — by construction unobservable from inside this repository; AC8 pins that such a row's destination is exactly `n/a`, which is the only in-repository consequence |
| A drop is justified per entry and never to hit a count | info-only (not promoted to AC) — no command can distinguish a well-reasoned drop from a lazy one; AC7 forces a non-empty reason on every row and AC13 puts all 79 reasons in front of an independent reader, which is the strongest available form |
| The generator's line-count warning will fire and that is expected | info-only (not promoted to AC) — asserting a warning appears would pin stderr text that `LINE_WARN_THRESHOLD`'s owner may legitimately change; AC24 pins the threshold and the warning line instead |
| No `.ja.md` counterpart for the corpus or the ledger | info-only (not promoted to AC) — AC27's allow-list admits neither path, so creating one fails the scope lock |
| Only the source file's current state crosses (no git-history reconstruction) | info-only (not promoted to AC) — the source repository is outside this tree and no criterion can observe what was not imported; AC7's 79 rows are bound to the 2026-07-31 measurement |

## Assumptions

- **Base ref `902c465`.** Every line number and count in the inventory was read
  there. AC26 and AC27 pin against it and are expected to go stale after merge.
- **The source corpus is unchanged since the 2026-07-31 measurement** (746 lines,
  79 entries, 76 active / 3 superseded). It lives in a separate pre-publication
  development repository; its absolute path is supplied to the engineer out of
  band and **must never be written into a tracked file** — a home-directory path
  is exactly what `bin/check-pii-shapes.sh` reds on, and this spec, the ledger and
  the board are all tracked. If a re-measurement disagrees, AC7's `79` is the
  first thing to re-pin, and re-pinning it is an intent change needing a
  ratified re-freeze.
- **The em dash in every entry key is U+2014**, the same character
  `bin/playbook-promote.sh` writes and `bin/check-playbook.sh` parses. AC1's and
  AC8's heading greps depend on it. **Unverified by pm-spec (no shell in this
  role) — flagged for the executing side.**
- **`LC_ALL=C` byte-range bracket expressions work in the host `grep`.** AC2 and
  AC3 depend on `$'[\xe3-\xef]'` being treated as a byte range. Both GNU and BSD
  grep do this in the C locale; the probe file in each criterion is what turns the
  assumption into a measurement. If the shape proves unportable, the executing
  side substitutes an equivalent with the meaning preserved.
- **`grep -m1`, `cksum`, `cmp`, `awk` with `-F'|'` and associative arrays, and
  `sed -n 's/…//p'` behave identically on both hosts.** Nothing here uses `grep
  -P`, GNU-only `awk` extensions, or `mktemp` without a template.
- **The two CI steps are written as block scalars (`run: |`).** AC18 and AC19
  extract and execute them; the extraction tolerates the single-line `run:` form
  as well, but the block form is the contract.
- **`shellcheck` is available** to the executing side; CI pins 0.11.0. AC26 fails
  loudly rather than soft-skipping.
- **`check-acs.sh`'s 120s per-check cap applies.** AC23 and AC25 each run a whole
  suite; `tests/codex-skeleton-hygiene/run.sh` is the largest in the repository.
  If either exceeds the cap on a slow host, raise `CHECK_ACS_TIMEOUT` for the run
  rather than splitting the criterion.
- **`develop` resolves locally** for AC10's `--base develop`, as it did for
  T-1006 and T-1007.
- **The retro at `.shell-team/retros/2026-07-28.md` carries exactly nine
  candidates, 6 `[common]` and 3 `[target-specific]`** (counted 2026-07-31). AC9
  pins those numbers; if the retro is ever edited, that criterion is the one to
  revisit.
- **No adopter corpus exists**, per #23's measurement — the assumption that made
  `Scope` free to require, and the one that would have to be revisited if an
  adopter reported one.

## Open questions

None blocking. Two decisions deviate from or extend the tech-lead routing map and
are recorded rather than left implicit:

- **`skills/review-response/SKILL.md` does not carry #57's clause.** The routing
  map said to fix its pointer "if measurement confirms it carries the claim". It
  does not: it carries a bare legacy-layout path reference. AC22 therefore
  corrects a same-class stale pointer rather than #57's clause, and says so.
- **DP-4's ban on bare `#<number>` references inside the corpus** is stricter
  than "old-repository issue numbers resolve to `n/a`". The reason is
  mechanical indistinguishability, stated in DP-4. If the executing side reads
  #23 as licensing this repository's own issue numbers inside imported entries,
  that is the one decision to re-open before implementation rather than after —
  AC3 is where it would be relaxed.

## Notes for engineer

**The trap this task is unusually exposed to.** The corpus and the ledger do not
exist yet, so a negated or zero-count `grep` against them "passes" for the wrong
reason. Every criterion above pairs an absence assertion with `test -s` on the
same target and with a positive control; keep that discipline in any probe you
write yourself, and remember that `grep -c` on a missing file exits 2 while
`test "$(…)" -eq 0` happily consumes the empty output.

**The four hazards, in order of what they will cost you.**

1. **A translated `Rule` that reds `tests/codex-skeleton-hygiene/run.sh`.** That
   suite greps the **live** `agents/qa-verifier.md` for
   `(bash|sh|source|.)[[:space:]]+bin/check-(provenance|interventions).sh` and
   for `(provenance|interventions)[-[:space:]]+gate:AC[0-9]` /
   `route[-[:space:]]+back[-[:space:]]+through[-[:space:]]+loop[-[:space:]]+guard`.
   The source corpus has entries about the provenance checker and about
   loop-guard STOPs; the obvious English rendering of one of them produces
   exactly those bytes, and regeneration splices it straight into that file. Say
   "the provenance checker" and "the loop guard's STOP escalation" instead, and
   run that suite (AC25) **before** you believe any playbook suite's green.
2. **`tests/errexit-safe/run.sh`'s `file:line:content` pin.** Your #58 header
   edit changes the line count above `bin/gen-playbook-blocks.sh`'s line-count
   warning, so the pin goes stale the moment you touch the header — and the suite
   fails in CI's list even though the five suites you are watching are green.
   **Re-measure the line number** with the grep in AC24's own check line rather
   than trusting any number written down, including this spec's; change only the
   line-number token and leave the quoted source text byte-identical. This class
   cost T-1006 a rework round and a ratified re-freeze, and T-1007 a pre-emptive
   criterion. `tests/errexit-safe/run.sh` is on AC27's allow-list from the start
   so fixing it needs no re-freeze here.
3. **Field order and the `\x1f` record contract are T-1007's, not yours.** You
   are writing corpus content, not touching the generator's parsing. If a block
   comes out wrong, the cause is in the corpus (a heading whose em dash is not
   U+2014, a field bullet with an unexpected name, a `Rule` spanning two lines) —
   not in the generator. `bin/check-playbook.sh` will tell you which entry.
4. **`agents/scrum-master.md` is a `contain`-mode consumer of four canonical
   blocks and has a frozen item count.** Edit exactly one clause. Do not
   renumber, do not reflow a numbered item into two, and run
   `bin/check-prompt-sync.sh` afterwards (AC21 does both).

**Triage guidance, so the routing rule is applied and not improvised.** For each
source entry, in this order: (i) is it about developing **this plugin** — its
release procedure, its CI behaviour, its own test suites? → `maintainer`, with a
`Bound-in` at the repo-local file that carries the rule. (ii) Is it about the
behaviour of a **tool** the operator uses everywhere — a sandbox quirk, a CLI's
threading model, a host's coreutils? → `operator-global`; it does not enter this
repository. (iii) Is it keyed to a convention this repository has replaced (the
old task-numbering scheme, a file layout that no longer exists)? → `drop`, with
the reason naming the replacement. (iv) Otherwise it is a rule any repository
running this loop would want → `loop`. When (i) and (ii) both seem to fit, ask
whether an adopter running the loop in an unrelated repository would hit the same
thing: if yes it is not `maintainer`.

**Superseded entries.** All three of the source's `superseded` entries carry a
resolving `Superseded-by` pointer. Dropping a superseded entry is safe; dropping
an **active** entry that is a pointer target dangles the graph and
`bin/check-playbook.sh` rejects it — so check every drop candidate against the
pointer graph before you commit to it. T-1007's directional rule also applies:
a `loop` entry superseded by a `maintainer` one is rejected, while
`maintainer → loop` is legal and is the case #23's single-file design exists to
support.

**Promote the retro candidates with the tool.** Use
`bash bin/playbook-promote.sh --scope loop|maintainer [--bound-in PATH] …` for
every adopted candidate rather than appending by hand. Two reasons: the
promoter's fail-closed re-validation against `bin/check-playbook.sh` is the
single authority for the schema, and using the flag end to end is the first real
exercise of what T-1007 built. Record in the ledger which `--scope` each
candidate entered with.

**Mutation self-check before hand-off** — run each, watch the named criterion go
red, restore from a pre-mutation file copy (never `git checkout`), verify
byte-identical with `diff`, and watch it go green again:

1. Leave one entry's `Rule` in Japanese → AC2 red.
2. Restore one `Source` to its old-repository reference → AC3 and AC6 red.
3. Point one `Bound-in` at a file that does not exist → AC15 red.
4. Delete one ledger row → AC7 and AC8 red.
5. Change one retained row's outcome to `drop` without removing the entry →
   AC8 red.
6. Route one `[common]` candidate to `maintainer` → AC9 red.
7. Hand-edit one word inside a generated block's marker region → AC17 red (and
   `bin/check-prompt-sync.sh` red if you edit the consumer rather than the
   block).
8. Replace the CI regen-diff step's `--get lessons` with the literal path →
   AC19 red.
9. Rename the CI step without touching the generator's header → AC20 red.
10. Revert the `tests/errexit-safe/run.sh` pin to its old line number → AC24
    red.

Beyond the list: your own detector's blind spots are the second layer. Ask what
your ledger cannot see (a row whose reason is true but whose outcome is wrong; an
entry translated fluently into a rule that says something narrower than the
original), and write at least one mutation of your own that attacks the answer.
Then check the tail of every file you wrote for tool-wrapper residue
(`grep -c '</content>\|</invoke>'` = 0 plus a `tail` read) before you commit —
this repository has paid for that one.

**Prior art.** T-1007's spec and board entry for the mechanism this corpus must
pass and for the fixture/criterion shapes reused here; T-1006's board entry for
what a stale cross-suite pin costs; `bin/gen-playbook-blocks.sh:89-130` for how
`--lessons` short-circuits the resolver and what the pointer text is derived
from; `templates/prompt-blocks/registry.txt:42-45` for the eight files the CI
step must cover; `tests/codex-skeleton-hygiene/run.sh:1330-1336,1419-1431` for
the two live-file regexes and their fail-closed grep discipline;
`bin/retro-inputs.sh:133-136,460-469` for the exact corrected wording #57's fix
should mirror.
