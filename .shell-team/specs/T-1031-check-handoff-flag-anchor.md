# check-handoff.sh validates the status flag through two grammars that resolve different separators, so a decoy-separator title produces a false PASS or a false FAIL

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1031

## Problem

`bin/check-handoff.sh` decides the same question twice with two different
regular expressions, and they do not agree. `LINE_RE` (line 68) is `$`-anchored
with a greedy title slot, so under POSIX leftmost-longest subexpression
assignment it resolves the **rightmost** `` — `<flag>` — spec:  `` sequence on
the line as the flag slot; `FLAG_RE` (line 73) is unanchored, so it matches the
**leftmost** one. A board line whose *title* contains a decoy copy of that
separator therefore gets its shape judged against one slot and its flag
vocabulary judged against another. Both failure directions are real: a decoy
holding a valid token in front of a real slot holding garbage lints clean (false
PASS — a malformed flag reaches `bin/close-out.sh`, whose own gate trusts this
checker), and the reverse pairing is reported as `unknown status flag` against a
token that is not the flag at all (false FAIL — a legitimate entry is blocked by
a message naming the wrong string). `bin/close-out.sh:316-318` documents its own
rewrite regex as using the "same disambiguation as check-handoff.sh's
`FLAG_RE`", which is currently false — `close-out.sh:319` resolves rightmost,
`FLAG_RE` resolves leftmost — so the comment points a future maintainer at the
wrong sibling. Separately, `bin/check-handoff.sh:165-170` wraps the flag check in
an `if [[ … =~ $FLAG_RE ]]` with **no else branch**: a shape-valid line whose
flag extraction failed would be accepted silently. That branch is unreachable
today only because `LINE_RE` passing implies `FLAG_RE` matching somewhere on the
line; it is a fail-open structure surviving on a coincidence between two regexes
that already disagree.

## Summarized sources

Everything this spec leans on that pm-spec did not read at first hand is listed
here rather than absorbed into the body as fact.

- **GitHub issue #122** — **relayed** through the task prompt. This role has no
  network and no `gh` access, so the issue body was not opened. If the filed
  text asks for something this spec declines (a different fix shape, a change to
  `close-out.sh`'s matching logic, a new checker), that is a scope question to
  raise before the freeze, not a rework finding afterwards.
- **The tech-lead's measurements** — relayed, and **re-measured by pm-spec at
  first hand in the working tree** for every claim this spec's acceptance
  criteria depend on: `bin/check-handoff.sh:68` (`LINE_RE`), `:73` (`FLAG_RE`),
  `:160-170` (the two-gate block and the missing else), `bin/close-out.sh:316-318`
  (the false comment) and `:319` (the greedy `$`-anchored rewrite regex),
  `tests/errexit-safe/run.sh:297-298` (the scope prose) and `:304-305` (the two
  pinned triples), `tests/close-out/run.sh:967` (the decoy line) and
  `:1054-1058` (the differential floors), `tests/machine-tokens/run.sh:48-68`
  (the token assertions), `templates/prompt-blocks/board-line-format.md` (two
  lines), `docs/interventions-reminder-hook.sample.sh:60` (`IN_FLIGHT_RE`), and
  the nine existing fixtures under `tests/check-handoff/fixtures/`. The one
  measurement pm-spec could **not** re-derive is the R2 outcome, because this
  role has no shell: see the Assumptions.
- **`tests/check-handoff/run.sh:4`'s M1 history** — read at first hand. The file
  header names "M1: unanchored flag extraction" as a Codex review finding, and
  lines 55-65 carry the guard (`valid.md`'s T-103 line with a backticked `API`
  token in the title). `FLAG_RE` **is** the fix that landed for M1. This task is
  therefore the **second** fix to the same extraction, which is why D1 removes
  the second grammar instead of adjusting it.
- **The base ref `1686495` and the branch `feature/122-check-handoff-flag-anchor`
  created off it** — relayed. pm-spec observed the working tree on `develop`, not
  the base blob. If `1686495` is not the real branch point, AC3, AC8, AC11 and
  AC15 measure the wrong comparison and must be corrected before the freeze.
- **`## Active` was empty at `1686495`** — relayed; pm-spec observed an empty
  `## Active` (board lines 12-14) in the **working tree**, which is a different
  object from the base blob.

## Goal

<!-- BEGIN intent-block: T-1031 -->

`bin/check-handoff.sh` decides a line's shape and its flag vocabulary from **one**
grammar, so the two answers cannot disagree by construction. A board line whose
title contains a decoy `` — `<token>` — spec: <path>.md `` sequence is judged
against the same slot the documented format defines — the last one on the line,
matching what `bin/close-out.sh` already rewrites — in both directions: the
false-PASS direction is reported, the false-FAIL direction lints clean. No
shape-valid `- [ ]` line can reach the end of the loop body without its flag
having been checked against `ALLOWED_FLAGS`. Every observable contract of the
checker — its three exit codes, its three classification strings, its message
format, and the tokens other suites assert against its source — is byte-identical
to what it was before. `bin/close-out.sh`'s comment describes what its own regex
actually does. The line-number ledger in `tests/errexit-safe/run.sh` names the
lines that exist after the edit, and its surrounding scope prose no longer claims
something this task makes untrue.

### Settled decisions (D1-D8)

These are binding. An engineer who wants to depart from one raises it before
implementing rather than after.

**D1 — fix shape A: one grammar, one extraction site.** The flag slot in
`LINE_RE` becomes a capture group (`` … — `([^`]+)` — spec: … ``), the flag is
taken from that same match, and `FLAG_RE` is **deleted**. Three grounds, all
measured. (i) Two regexes answering one question can drift again, and this is
already the **second** fix to this extraction — `FLAG_RE` is itself M1's fix
(`tests/check-handoff/run.sh:4`); a third grammar-adjustment patch would be the
third. (ii) It introduces **no new portability dependency**: `bin/close-out.sh:319`
(`if [[ "$MAIN_LINE" =~ ^(.+)\ —\ \`[^\`]+\`\ —\ spec:\ ([^[:space:]]+\.md)[[:space:]]*$ ]]`)
already relies on exactly the same POSIX greedy-subexpression assignment, in a
path CI exercises on every run. (iii) It removes the fail-open branch at
`:165-170` entirely rather than adding an else to it, because the branch only
exists to serve the second grammar. The extraction must be **restructured so the
match array is not carried across intervening statements** — the value is bound
in the same conditional construct whose test performed the match, before any
other command runs. Shape B (keeping `FLAG_RE` and tail-anchoring it with `$`) is
rejected as the primary: it preserves two grammars and the fail-open branch, and
buys nothing shape A does not. B remains the **fallback** if and only if R3
fires; taking it requires stating why in the provenance record.

**D2 — the line-number ledger is re-derived, not padded around.**
`tests/errexit-safe/run.sh:304-305` pins two `file:line:content` triples for this
file (`check-handoff.sh:27:` and `check-handoff.sh:77:`). The ledger defines
itself (`:293-294`) as "the EXACT file:line:content triple a fresh
`derive_candidates()` run produces today", so when the regex-region edit moves
the `emit()` write, **the ledger moves with it**. Padding `bin/check-handoff.sh`
with comment lines so the old number still resolves is forbidden: it makes the
ledger lie about the source in order to keep the ledger literally unchanged.
The `:27` triple is expected to survive at 27 (the edit is entirely below it) —
that expectation is itself asserted, not assumed. Separately, the prose at
`:297-298` ("check-handoff.sh is the ONLY (a) — the single inviolable,
byte-unchanged file (DP-1)") is a T-110-era scope statement that this task makes
false, and the not-apply *reason letter* it assigns to both triples rests on that
statement. It is corrected — or, if the engineer concludes the classification
survives on other grounds, the reason is recorded in the same place — and either
way the corrected text cites `T-1031` so a later reader can find why it changed.

**D3 — `bin/close-out.sh` gets a comment correction and nothing else.** Lines
316-318 claim the "same disambiguation as check-handoff.sh's `FLAG_RE`". After
this task, `FLAG_RE` does not exist, and the claim was false before it too:
`close-out.sh:319` resolves rightmost, `FLAG_RE` resolved leftmost. The
correction is **prose only**. No `close-out.sh` logic changes — the regex at
`:319` stays byte-identical, and the file carries its own ledger pin at
`close-out.sh:444` that a logic edit could disturb.

**D4 — both decoy directions ship as NEW fixture files.** They are not appended
to the existing ones, because both existing negative fixtures are pinned in ways
appending would break: `bad-format.md` is asserted at **exactly 2** total
violations (`tests/check-handoff/run.sh:103-105`), and `bad-flag.md` is
string-grepped for specific tokens (`:117-128`). The M1 regression guard —
`valid.md`'s T-103 line carrying a backticked `API` token in the title, and
`run.sh:64`'s assertion that the line is still there — stays intact and is
re-asserted here rather than assumed.

**D5 — `docs/interventions-reminder-hook.sample.sh:60`'s `IN_FLIGHT_RE` is a
third copy of this grammar and is declared NOT APPLICABLE, with the reason.** It
is boolean-only (`grep -E -q`, no capture, no extraction — the flag enum is
inlined as an alternation rather than captured), it is **deliberately
end-unanchored** so a CRLF board still matches, and it is explicitly fail-open
advisory: every failure path in that file is `exit 0`, and a non-conforming line
reads as *not in flight*, which errs toward silence. A decoy separator there can
at worst suppress or emit an advisory reminder; there is no verdict to
falsify. Changing it would tighten an advisory hook that documents its own
looseness as intentional, and would put a shipped sample outside this task's
scope lock. The file stays byte-identical.

**D6 — the tokens other suites read out of this file survive the edit.**
`tests/machine-tokens/run.sh:48-52` requires all seven flag tokens verbatim in
`bin/check-handoff.sh`, and `:60-68` requires **every non-empty line of**
`templates/prompt-blocks/board-line-format.md` (`- [ ] **T-` and
`` ` — spec:  ``) verbatim in the same file. Today both live in the header
comment at `:4-6`, which sits directly above the region being edited. Their
survival is locked, not left to luck.

**D7 — the observable contract is frozen.** Exit codes 0 (clean), 1 (violations
found) and 2 (unreadable file); the classification strings `format mismatch`,
`unknown status flag '<flag>'` and the frozen stranded-continuation reason; and
the `emit()` message format `<file>:<lineno>: <reason>: <line>` are all
byte-unchanged. `bin/close-out.sh:368-370` transcribes this checker's stderr
**verbatim** into its own refusal output, and `tests/close-out/run.sh` greps
fixed strings, so a reworded message is a downstream break, not a cosmetic one.

**D8 — no vacuous acceptance criteria.** In particular, "the T-1027..T-1030 board
entries keep passing the lint" is **not** an acceptance criterion: those entries
live in `## Done`, which `bin/check-handoff.sh` deliberately does not validate
(`:17`), so the assertion is true no matter what the checker does. What is
asserted instead is that **T-1031's own `## Active` entry** lints clean under the
edited checker and that `templates/todo-template.md` — the shipped positive
control — still does.

## Non-goals

- **Changing `bin/close-out.sh`'s matching or rewriting logic.** Comment text
  only (D3).
- **Changing `docs/interventions-reminder-hook.sample.sh`** (D5).
- **Widening or narrowing what the checker accepts.** The set of lines that lint
  clean changes in exactly one respect: lines carrying a decoy separator are now
  judged at the same slot in both gates. No new shape is accepted or rejected.
- **Any change to the classification strings, exit codes, or message format**
  (D7) — including "improving" the `unknown status flag` message to also print
  the resolved slot position.
- **Validating `## Done` lines, `- [x]` lines, or the spec path's prefix.** All
  three are existing, deliberate scope boundaries and stay where they are.
- **Putting a self-referential decoy separator into T-1031's own board title.**
  The repository's dogfooding lesson ("a guard that pattern-matches free-form
  board text needs a self-referential fixture") is honoured through the two new
  **fixtures**, not through the live board: a decoy in this task's own board
  entry would be judged by the *pre-fix* checker from the moment the entry lands,
  producing a false FAIL on the board that gates every hand-off in the repository
  before the fix exists. The fixture files carry that coverage instead.
- **Building a detector for the two grammars re-diverging in future.** D1 removes
  the second grammar; a checker that watches for a third one being introduced is
  a different task at a different review standard.

## Acceptance criteria

Every `check:` below runs from the repository root. `1686495` is this task's
merge point; the criteria that name it are **merge-point-scoped and expected to
go stale after merge** — do not widen their base-ref resolution and do not
re-derive them per rework round.

- [ ] **AC1** The **false-PASS direction is closed.** A new fixture
  `tests/check-handoff/fixtures/decoy-real-flag-invalid.md` contains a top-level
  `## Active` line whose *title* holds a decoy
  `` — `READY_FOR_QA` — spec: decoy.md `` sequence and whose real (last) flag
  slot holds `` `T1031_DECOY_BAD` ``, plus at least one ordinary well-formed
  entry. Running the checker against it exits **1**, reports
  `unknown status flag 'T1031_DECOY_BAD'`, emits **exactly one** violation line
  in total, and emits **zero** `format mismatch` lines. The exact-count and
  zero-mismatch clauses are what make this a totality assertion rather than a
  presence assertion.
  - check: e=$(mktemp "${TMPDIR:-/tmp}/T1031-ac1.XXXXXX") || exit 2; bash bin/check-handoff.sh tests/check-handoff/fixtures/decoy-real-flag-invalid.md 2>"$e"; rc=$?; cat "$e"; grep -qF -- "unknown status flag 'T1031_DECOY_BAD'" "$e" && [ "$rc" -eq 1 ] && [ "$(grep -c . "$e")" -eq 1 ] && ! grep -q 'format mismatch' "$e"; s=$?; rm -f "$e"; exit $s

- [ ] **AC2** The **false-FAIL direction is closed.** A new fixture
  `tests/check-handoff/fixtures/decoy-real-flag-valid.md` contains a top-level
  `## Active` line whose *title* holds a decoy
  `` — `T1031_DECOY_BAD` — spec: decoy.md `` sequence and whose real (last) flag
  slot holds an allowed flag. The checker exits **0** with **empty stderr**. The
  fixture is grepped for the decoy token first, so exit 0 cannot pass vacuously
  against a fixture that lost its decoy.
  - check: e=$(mktemp "${TMPDIR:-/tmp}/T1031-ac2.XXXXXX") || exit 2; grep -qF -- 'T1031_DECOY_BAD' tests/check-handoff/fixtures/decoy-real-flag-valid.md || { rm -f "$e"; exit 1; }; bash bin/check-handoff.sh tests/check-handoff/fixtures/decoy-real-flag-valid.md 2>"$e"; rc=$?; cat "$e"; [ "$rc" -eq 0 ] && [ ! -s "$e" ]; s=$?; rm -f "$e"; exit $s

- [ ] **AC3** **D4's fixture discipline holds.** The two decoy fixtures are
  **new files**, and all **nine** fixtures that existed at `1686495`
  (`bad-format.md`, `bad-flag.md`, `valid.md`, `valid-crlf.md`,
  `whitespace-title.md`, `tab-subbullet.md`, `strand-top.md`,
  `strand-boundaries.md`, `strand-tolerant.md`) are byte-identical to their base
  blobs. The population total (9) is re-derived from the base tree inside the
  check rather than trusted from this list, so an added-and-forgotten tenth
  fixture at base would fail here rather than escape the enumeration.
  - check: n=$(git ls-tree --name-only 1686495 tests/check-handoff/fixtures/ | grep -c .) && [ "$n" -eq 9 ] && for f in bad-format.md bad-flag.md valid.md valid-crlf.md whitespace-title.md tab-subbullet.md strand-top.md strand-boundaries.md strand-tolerant.md; do git diff --quiet 1686495 -- "tests/check-handoff/fixtures/$f" || exit 1; done; [ -f tests/check-handoff/fixtures/decoy-real-flag-invalid.md ] && [ -f tests/check-handoff/fixtures/decoy-real-flag-valid.md ]

- [ ] **AC4** **D1 landed as one grammar with one extraction site.** In
  `bin/check-handoff.sh`: the token `FLAG_RE` occurs **zero** times; there is
  **exactly one** line-grammar assignment (`^LINE_RE=`); that grammar contains
  the capture-group flag slot `` — `([^`]+)` — spec:  `` verbatim; and
  `BASH_REMATCH[1]` is referenced **exactly once** in the whole file. The last
  clause pins the single extraction site — if a comment needs to talk about the
  match array, phrase it without writing the indexed expansion. `ALLOWED_FLAGS`
  is grepped as a positive control that the check is reading the real file.
  - check: grep -qF -- 'ALLOWED_FLAGS' bin/check-handoff.sh && [ "$(grep -c 'FLAG_RE' bin/check-handoff.sh)" -eq 0 ] && [ "$(grep -c '^LINE_RE=' bin/check-handoff.sh)" -eq 1 ] && grep -qF -- '— `([^`]+)` — spec: ' bin/check-handoff.sh && [ "$(grep -c 'BASH_REMATCH\[1\]' bin/check-handoff.sh)" -eq 1 ]

- [ ] **AC5** **The M1 regression guard is intact.** `valid.md` is byte-identical
  to its base blob, still contains both backticked title tokens that guard the
  original unanchored-extraction finding, and still lints clean at exit 0. Exit 0
  means the T-103 line produced no message, which is the guard.
  - check: git diff --quiet 1686495 -- tests/check-handoff/fixtures/valid.md && grep -qF -- '`API`' tests/check-handoff/fixtures/valid.md && grep -qF -- '`URL`' tests/check-handoff/fixtures/valid.md && bash bin/check-handoff.sh tests/check-handoff/fixtures/valid.md

- [ ] **AC6** **D2's ledger is re-derived and the whole errexit-safe suite is
  green.** In `tests/errexit-safe/run.sh`: no ledger line begins
  `check-handoff.sh:77:` (the stale pin is gone); exactly one begins
  `check-handoff.sh:27:` (the write above the edit region kept its line number);
  and the ledger contains exactly one triple whose line number equals the **live**
  line number of `bin/check-handoff.sh`'s `emit()` write, re-derived from the file
  inside the check rather than transcribed. Then `bash tests/errexit-safe/run.sh`
  passes, which is the content-aware `comm` the ledger exists for. If an honest
  re-derivation genuinely lands back on 77, that is a finding about this spec's
  premise — route it back to pm-spec rather than padding the source to fit.
  - check: [ "$(grep -c '^check-handoff.sh:77:' tests/errexit-safe/run.sh)" -eq 0 ] && [ "$(grep -c '^check-handoff.sh:27:' tests/errexit-safe/run.sh)" -eq 1 ] && n=$(grep -n "printf '%s:%s: %s: %s" bin/check-handoff.sh | cut -d: -f1) && [ -n "$n" ] && [ "$(grep -c "^check-handoff.sh:$n:" tests/errexit-safe/run.sh)" -eq 1 ] && bash tests/errexit-safe/run.sh

- [ ] **AC7** **D2's scope prose is reconciled.** The T-110-era sentence
  asserting that `check-handoff.sh` is the only reason-(a) site and the single
  inviolable, byte-unchanged file no longer appears in
  `tests/errexit-safe/run.sh`, and the corrected text cites `T-1031` so the
  change is traceable to this task. `NOT_APPLY` is grepped as a positive control.
  - check: grep -qF -- 'NOT_APPLY' tests/errexit-safe/run.sh && [ "$(grep -c 'check-handoff.sh is the ONLY (a)' tests/errexit-safe/run.sh)" -eq 0 ] && [ "$(grep -c 'byte-unchanged file (DP-1)' tests/errexit-safe/run.sh)" -eq 0 ] && grep -qF -- 'T-1031' tests/errexit-safe/run.sh

- [ ] **AC8** **D3's comment correction landed and D3's logic freeze held.** In
  `bin/close-out.sh`: the token `FLAG_RE` occurs **zero** times (it occurred
  exactly once at base — re-derived from the base blob inside the check, so this
  is a measured before/after, not an assumption); the corrected comment cites
  `T-1031`; and the Done-entry rewrite conditional is **byte-identical** to its
  base-blob text.
  - check: [ "$(git show 1686495:bin/close-out.sh | grep -c 'FLAG_RE')" -eq 1 ] && [ "$(grep -c 'FLAG_RE' bin/close-out.sh)" -eq 0 ] && grep -qF -- 'T-1031' bin/close-out.sh && a=$(git show 1686495:bin/close-out.sh | grep -F 'if [[ "$MAIN_LINE" =~ ') && b=$(grep -F 'if [[ "$MAIN_LINE" =~ ' bin/close-out.sh) && [ -n "$a" ] && [ "$a" = "$b" ]

- [ ] **AC9** **D5's not-applicable declaration is honoured and grounded.**
  `docs/interventions-reminder-hook.sample.sh` is byte-identical to its base blob,
  still contains `IN_FLIGHT_RE` (so the "unchanged" claim is about a file that
  still holds the third copy, not one that lost it), and this spec records the
  not-applicable reason by name.
  - check: git diff --quiet 1686495 -- docs/interventions-reminder-hook.sample.sh && grep -qF -- 'IN_FLIGHT_RE' docs/interventions-reminder-hook.sample.sh && grep -qF -- 'IN_FLIGHT_RE' .shell-team/specs/T-1031-check-handoff-flag-anchor.md

- [ ] **AC10** **D6's tokens survive.** `bash tests/machine-tokens/run.sh` passes,
  and — independently of that suite, so a change to the suite cannot hide a loss —
  every non-empty line of `templates/prompt-blocks/board-line-format.md` still
  appears verbatim in `bin/check-handoff.sh`, and so do all seven flag tokens. The
  canonical block is read from the file rather than transcribed here.
  - check: bash tests/machine-tokens/run.sh && while IFS= read -r l; do l="${l%$'\r'}"; [ -n "$l" ] || continue; grep -qF -- "$l" bin/check-handoff.sh || exit 1; done < templates/prompt-blocks/board-line-format.md && for t in READY_FOR_ARCH READY_FOR_ENG READY_FOR_QA READY_FOR_REVIEW READY_FOR_MERGE BLOCKED REWORK; do grep -qF -- "$t" bin/check-handoff.sh || exit 1; done

- [ ] **AC11** **D7's contract is byte-unchanged.** `bin/check-handoff.sh` still
  contains the three classification strings and the frozen stranded-continuation
  reason verbatim; still carries all three exit paths; and its `emit()` message
  format line is **string-equal** to the same line in the base blob (equality, not
  containment — a reworded message that merely still contains the old format
  fragment must not pass).
  - check: for s in 'format mismatch' "unknown status flag '" 'cannot read file' 'stranded continuation line (no task entry above it in this section)'; do grep -qF -- "$s" bin/check-handoff.sh || exit 1; done; grep -qF -- 'exit 2' bin/check-handoff.sh && grep -qF -- '[[ "$violations" -gt 0 ]] && exit 1' bin/check-handoff.sh && grep -qF -- 'exit 0' bin/check-handoff.sh && a=$(git show 1686495:bin/check-handoff.sh | grep -F "printf '%s:%s: %s: %s") && b=$(grep -F "printf '%s:%s: %s: %s" bin/check-handoff.sh) && [ -n "$a" ] && [ "$a" = "$b" ]

- [ ] **AC12** **R2's flip is measured at its source, not transcribed.** The
  decoy line already present in `tests/close-out/run.sh`'s differential corpus is
  **extracted from that file** (matched by `- [ ] **T-901** decoy separator`,
  which must occur exactly once — the axes comment above it mentions the phrase
  but not the task id), written into a synthesized single-entry board, and linted:
  it must now exit **0**. At `1686495` the same line exits 1, so this criterion is
  the refused→accepted flip stated as a measurement rather than an estimate.
  - check: [ "$(grep -cF -- '- [ ] **T-901** decoy separator' tests/close-out/run.sh)" -eq 1 ] && d=$(grep -F -- '- [ ] **T-901** decoy separator' tests/close-out/run.sh | sed -e "s/^[[:space:]]*'//" -e "s/'[[:space:]]*$//") && [ -n "$d" ] && t=$(mktemp "${TMPDIR:-/tmp}/T1031-ac12.XXXXXX") && printf '## Active\n\n%s\n' "$d" > "$t" && printf 'line under test: %s\n' "$d" && bash bin/check-handoff.sh "$t"; s=$?; rm -f "$t" 2>/dev/null; exit $s

- [ ] **AC13** **The close-out differential still holds after the flip.**
  `bash tests/close-out/run.sh` passes — which is where the floors
  `refused>=6` / `accepted>=8` / `notlocated>=3` / `corpus>=24` and
  `mismatches=0` are asserted (`run.sh:1054-1058`) — and the differential summary
  line is present with `mismatches=0` and is **printed into the check output**, so
  the post-flip refused/accepted counts are visible evidence rather than a claim.
  This criterion also exercises, for the first time, close-out's full rewrite path
  for the decoy line, which was refused before this task and is accepted after it.
  **This is the only criterion that needs an elevated `CHECK_ACS_TIMEOUT`** — see
  the Notes for engineer.
  - check: o=$(mktemp "${TMPDIR:-/tmp}/T1031-ac13.XXXXXX") || exit 2; bash tests/close-out/run.sh >"$o" 2>&1; rc=$?; grep -F 'closeout-lineshape-differential corpus=' "$o"; grep -qE 'closeout-lineshape-differential corpus=[0-9]+ refused=[0-9]+ accepted=[0-9]+ notlocated=[0-9]+ mismatches=0' "$o"; g=$?; tail -5 "$o"; rm -f "$o"; [ "$rc" -eq 0 ] && [ "$g" -eq 0 ]

- [ ] **AC14** **The new fixtures are wired into the suite, not orphaned.**
  `bash tests/check-handoff/run.sh` passes, and `run.sh` references both new
  fixture basenames — so the fixtures are exercised by the suite CI runs, not only
  by AC1/AC2.
  - check: bash tests/check-handoff/run.sh && grep -qF -- 'decoy-real-flag-invalid.md' tests/check-handoff/run.sh && grep -qF -- 'decoy-real-flag-valid.md' tests/check-handoff/run.sh

- [ ] **AC15** **Scope lock and required deliverables.** `git diff --name-only
  1686495` contains nothing outside the allow-list (`bin/check-handoff.sh`,
  `bin/close-out.sh`, `tests/check-handoff/run.sh`, the two new fixtures,
  `tests/errexit-safe/run.sh`, this spec, the board, and the three task records
  — provenance, review, interventions); the changed set is non-empty (so the
  comparison is not vacuous); the provenance and review records exist; and the
  board's diff has a **deletions column of 0**, measured through
  `git diff --numstat`'s own column rather than by counting `^-` diff markers,
  which is vacuous in a file whose entry lines all begin with a hyphen. Anything
  outside the allow-list is printed before the verdict. Merge-point-scoped: this
  criterion is expected to go stale once later work lands on the same base.
  - check: A=$(mktemp "${TMPDIR:-/tmp}/T1031-a.XXXXXX") || exit 2; B=$(mktemp "${TMPDIR:-/tmp}/T1031-b.XXXXXX") || exit 2; git diff --name-only 1686495 | sort -u > "$A"; printf '%s\n' .shell-team/interventions/T-1031.md .shell-team/provenance/T-1031.md .shell-team/reviews/T-1031.md .shell-team/specs/T-1031-check-handoff-flag-anchor.md .shell-team/todo.md bin/check-handoff.sh bin/close-out.sh tests/check-handoff/fixtures/decoy-real-flag-invalid.md tests/check-handoff/fixtures/decoy-real-flag-valid.md tests/check-handoff/run.sh tests/errexit-safe/run.sh | sort -u > "$B"; printf 'outside the allow-list:\n'; comm -23 "$A" "$B"; X=$(comm -23 "$A" "$B" | grep -c .); S=$(grep -c . "$A"); D=$(git diff --numstat 1686495 -- .shell-team/todo.md | cut -f2); rm -f "$A" "$B"; [ "$S" -ge 1 ] && [ "$X" -eq 0 ] && [ "${D:-1}" -eq 0 ] && [ -f .shell-team/provenance/T-1031.md ] && [ -f .shell-team/reviews/T-1031.md ]

- [ ] **AC16** **D8's non-vacuous board assertions.** T-1031's own `## Active`
  entry is present and the live board lints clean under the **edited** checker;
  `templates/todo-template.md` — the shipped positive control — still lints clean,
  so the checker cannot be passing by rejecting nothing or accepting everything;
  and `bin/check-board-headings.sh` finds no heading deletion or replacement
  against the base. Deliberately **not** asserted: that the T-1027..T-1030 entries
  keep passing — they are in `## Done`, outside this checker's scope, so the
  assertion would be true unconditionally.
  - check: grep -qF -- '- [ ] **T-1031**' .shell-team/todo.md && bash bin/check-handoff.sh .shell-team/todo.md && bash bin/check-handoff.sh templates/todo-template.md && bash bin/check-board-headings.sh .shell-team/todo.md --base 1686495

- [ ] **AC17** **Runtime disclosure, recorded in the provenance record** (no
  `check:` — this is evidence a human or a later gate reads, not a command).
  Four items, each stated as a measurement with the command that produced it:
  (a) **CI wiring** — which of the suites this task touches actually run in
  `.github/workflows/check-handoff.yml`, and for any that do not, that local
  execution on one OS and one coreutils is the only evidence available;
  (b) **mutation self-check** — the fix and each new lock were deliberately broken
  one at a time (at minimum: revert `LINE_RE`'s capture group; re-introduce a
  leftmost-anchored second extraction; blank one new fixture's decoy token; move
  the `emit()` write without updating the ledger), each confirmed to FAIL the
  criterion that should catch it, then restored and confirmed green — including
  at least one mutation aimed at the **detector's own blind spot** (e.g. a
  fixture that still contains the token but no longer reaches the flag slot);
  (c) **R2 before/after** — the differential's `refused`/`accepted` counts
  measured at `1686495` and after the fix, side by side, from AC13's own output;
  (d) **R3 portability** — the host's `bash --version` and OS, and the statement
  that AC1/AC2/AC12 passing on it is the direct behavioural evidence that greedy
  subexpression assignment resolved the **rightmost** slot there. If it did not,
  shape B is taken per D1 and the reason is recorded in the same place.

- [ ] **AC18** **R4 pre-commitment, recorded before the first review round** (no
  `check:`). The trigger has two conditions, stated separately because they can
  disagree. **Factual**: this subsystem — `bin/check-handoff.sh`'s line grammar
  and flag extraction, together with the fixtures and ledgers that pin it — draws
  **new, independent** Blocker or Major findings in **two consecutive** review
  rounds (a repeat of the same finding, or a finding elsewhere in the diff, does
  not count). **Contextual**: a third round of rework on this subsystem is about
  to start. Default threshold is the repository's standing "two consecutive
  rounds" convention, taken without loosening because this is already the
  **second** fix to the same extraction (`FLAG_RE` was M1's fix). When the two
  conditions disagree, the **factual** condition governs. On trigger, the
  response is not a third patch: propose either (i) rebuilding the line grammar
  as a single explicitly-specified parser with its own fixture corpus, or
  (ii) splitting the ledger/prose reconciliation (D2/D3) out into a separate task
  so the grammar change can be judged alone — and put that proposal to the
  orchestrator before any further edit.

## Input space

**Reachable input classes** — boards this checker actually meets, all of which
the edited grammar must handle correctly:

1. Well-formed entries per `templates/prompt-blocks/board-line-format.md`:
   `- [ ] **T-NNN** <title> — ` + backticked flag + ` — spec: <path>.md`, with
   legacy `docs/specs/…`, default `.shell-team/specs/…`, and bare `x.md` paths.
2. Titles containing backtick-wrapped tokens with no separator around them
   (`API`, `URL`) — the M1 class, present in `valid.md` today.
3. **Titles containing a full decoy separator sequence** — the defect class. This
   is reachable, not synthetic: this repository's own board entries routinely
   quote board-line grammar in prose, `tests/close-out/run.sh:967` already
   carries such a line as a deliberate corpus member, and a PM writing an entry
   about the board format produces one naturally. **One** decoy is the class; the
   resolution rule (last slot on the line) is total over any count.
4. Titles that are padded, whitespace-only, tab-only or empty; flags that are
   lowercase, near-miss (`READY_FOR_MERGED`), space-bearing (`READY FOR QA`), or
   carry trailing whitespace inside the backticks.
5. CRLF-terminated boards (Windows checkouts), including CRLF versions of all of
   the above.
6. Continuation lines of every shape — dash sub-bullets, table rows, tab-indented
   lines, blank lines inside an entry — plus stranded continuation lines, the
   `_(none)_` placeholder, `- [x]` lines, and near-miss checkbox shapes with no
   space after the bracket.
7. **Synthesized single-entry boards written by `bin/close-out.sh`**: exactly one
   `## Active` heading, one blank line, one candidate line, no `## Done`. This is
   a first-class caller, not a test artifact.
8. An empty `## Active` section, and a board with no `## Active` heading at all
   (awk yields an empty block; the checker exits 0). Existing behaviour,
   unchanged and not extended here.
9. An unreadable or missing file → exit 2. Existing behaviour, locked by AC11.

**Out-of-scope synthetic extremes** — named concretely, and declined:

- **Escalating decoy counts.** Two, three, ten repetitions of the separator in
  one title. The rule is "the last one on the line", which is total over any
  count; the fixtures cover one decoy, and no further acceptance criterion is
  owed per additional decoy. A finding of the form "what about N+1 decoys" is out
  of scope by this declaration.
- **A backtick or the separator sequence inside the spec *path*** (e.g.
  `spec: a — `b` — spec: c.md`). The path slot is `[^[:space:]]+\.md`, no
  producer emits such a path, and no filesystem in this loop's use carries one.
- **Board grammar spanning multiple lines.** The format is single-line by
  contract; a wrapped entry is a continuation line by definition and is covered
  by class 6, not by a multi-line grammar.
- **Adversarial width or length escalation**: titles of 10k+ characters,
  thousands of `## Active` entries, pathological regex inputs. Bash's POSIX ERE
  engine is not the subject of this task, real boards are hand-written, and no AC
  will be added for an ever-larger width.
- **Non-UTF-8 byte sequences, lone surrogates, or a U+2013/U+2012 look-alike
  substituted for the U+2014 em-dash.** The separator is a fixed byte sequence in
  the shipped canonical block; a look-alike is a format mismatch by the existing
  grammar and stays one.
- **Concurrent writers mutating the board while the checker reads it.** No
  locking exists today and none is added.

<!-- END intent-block: T-1031 -->

## Body-to-AC correspondence

Every normative directive in the body above, mapped 1:1. A directive missing from
this table means the spec is incomplete.

| # | Body directive | Where | Promoted to |
|---|---|---|---|
| 1 | One grammar decides shape and flag; `FLAG_RE` is deleted | Goal, D1 | **AC4** |
| 2 | The flag slot becomes a capture group in the line grammar | D1 | **AC4** |
| 3 | The match array is not carried across intervening statements | D1 | info-only (not promoted to AC) — a statement-layout requirement inside one function-free block; AC4's single-`BASH_REMATCH[1]` clause makes a second site impossible, and the ordering itself is the engineer's call per the Rules |
| 4 | No shape-valid `- [ ]` line reaches the loop's end unchecked (fail-open branch removed) | Problem, Goal | **AC4** (`FLAG_RE` count 0 ⇒ the branch is gone) + **AC1** (exact-count totality on a fixture) |
| 5 | Shape B only if R3 fires, with the reason recorded | D1 | **AC17(d)** |
| 6 | Decoy resolution matches `bin/close-out.sh`'s rightmost slot | Goal | **AC12** (close-out's own corpus line lints clean) + **AC13** |
| 7 | False-PASS direction reported | Goal, Problem | **AC1** |
| 8 | False-FAIL direction lints clean | Goal, Problem | **AC2** |
| 9 | The ledger is re-derived, never padded around | D2 | **AC6** |
| 10 | The `:27` triple survives at 27 | D2 | **AC6** |
| 11 | The T-110-era scope prose is corrected and cites T-1031 | D2 | **AC7** |
| 12 | `close-out.sh`'s false comment is corrected | D3 | **AC8** |
| 13 | `close-out.sh` logic is byte-unchanged | D3, Non-goals | **AC8** (base-blob string equality on the rewrite conditional) |
| 14 | Both decoy directions are NEW fixture files | D4 | **AC3** |
| 15 | `bad-format.md` / `bad-flag.md` are not appended to | D4 | **AC3** (byte-identical to base) |
| 16 | The M1 regression guard stays intact | D4 | **AC5** |
| 17 | The hook sample is not applicable and stays byte-identical | D5, Non-goals | **AC9** |
| 18 | The `board-line-format.md` lines and seven flag tokens survive | D6 | **AC10** |
| 19 | Exit codes, classification strings and message format are byte-unchanged | D7, Non-goals | **AC11** |
| 20 | No vacuous `## Done`-entry assertion | D8 | **AC16** (stated as a deliberate exclusion in the AC body) |
| 21 | T-1031's own Active entry and the shipped template lint clean | D8 | **AC16** |
| 22 | The accepted/rejected set changes in exactly one respect | Non-goals | **AC13** (`mismatches=0` against the live oracle across the whole corpus) + **AC14** (the existing suite, unmodified in its assertions, still passes) |
| 23 | `## Done` / `- [x]` / spec-path-prefix scope boundaries are unchanged | Non-goals | **AC14** (the strand and `- [x]` fixtures assert them) + **AC11** |
| 24 | No self-referential decoy in T-1031's own board title | Non-goals | **AC16** (the live board lints clean under the pre-fix checker too, which a self-referential decoy would break) |
| 25 | No re-divergence detector is built | Non-goals | **AC15** (scope lock — a new checker would appear outside the allow-list) |
| 26 | The diff stays inside the allow-list; the board edit is a pure insertion | AC preamble, D8 | **AC15** |
| 27 | CI-wiring, mutation self-check, R2 before/after and R3 portability are disclosed | Assumptions, D1 | **AC17** |
| 28 | The R4 pre-commitment is recorded before round 1 | Assumptions | **AC18** |
| 29 | Diff-scope criteria are merge-point-scoped and not to be merge-ranged | AC preamble | info-only (not promoted to AC) — a norm addressed to future maintainers of this spec, not a property of the shipped artifact; promoting it would require asserting the absence of a future edit |
| 30 | The decoy resolution rule is total over any decoy count | Input space | info-only (not promoted to AC) — a scope declaration bounding what QA and the cross-provider review may escalate to, deliberately not itself a check |

## Assumptions

- **The base ref `1686495` is the real branch point** for
  `feature/122-check-handoff-flag-anchor`. Relayed. AC3, AC8, AC11 and AC15 all
  read base blobs through it; if it is wrong they measure the wrong comparison.
  Verify before the freeze.
- **R2 (the differential floor) is estimated, not measured, by pm-spec** — this
  role has no shell. pm-spec's own static re-derivation of the 29-member corpus
  puts today's counts at roughly `refused=14 / accepted=11 / notlocated=4`, so
  the single refused→accepted flip of the decoy line leaves `refused≈13 ≥ 6` and
  `accepted≈12 ≥ 8` — both floors holding with margin. **This estimate is not
  evidence.** AC13 measures it live and prints the real line; AC17(c) records the
  before/after pair. If the real counts sit near a floor, that is a finding about
  this spec, not something to work around by lowering a floor.
- **The decoy line's close-out rewrite path executes for the first time** in
  AC13, because that line was refused at the gate before this task. Nothing in
  `close-out.sh` changes, but a previously-unreached path becoming reachable is
  where a latent defect would surface — treat an AC13 failure as a genuine
  finding rather than a fixture problem.
- **POSIX greedy-subexpression assignment resolves the rightmost slot on both
  BSD and glibc regex** (R3). Grounded in `bin/close-out.sh:319` already relying
  on it in CI, but not independently verified across both libcs by pm-spec.
  AC1/AC2/AC12 are the behavioural proof on whatever host runs them; a divergence
  means shape B (D1's fallback), which is a re-freeze proposal, not a rework fix.
- **`## Active` was empty at the base ref**, making this board entry a pure
  insertion (AC15's deletions-column clause).
- **`tests/errexit-safe/run.sh`'s two `check-handoff.sh` ledger triples are the
  only line-number pins on this file.** Derived from the tech-lead's inventory
  plus pm-spec's own reading of the file; a pin written through indirection — a
  path built from a loop variable, a computed line number — is not something a
  static grep can trace in principle, so the completeness of this claim is
  delegated to AC6's live suite run rather than to the scan.

## Open questions

None blocking. One item is recorded rather than asked: whether the reason-letter
classification of `check-handoff.sh`'s two ledger triples survives the file
ceasing to be "inviolable" is left to the engineer's reading of
`tests/errexit-safe/run.sh`'s own not-apply criteria (D2 permits either
correcting the letter or recording why it stands), because that judgement needs
the file in front of it and both outcomes satisfy AC6 and AC7.

## Notes for engineer

**Files.** `bin/check-handoff.sh` (lines 59-73 and 160-170 are the whole edit),
`bin/close-out.sh` (lines 316-318, comment only), `tests/errexit-safe/run.sh`
(lines 297-298 prose, 304-305 ledger), `tests/check-handoff/run.sh` (wire the two
new fixtures, following the existing marker-derived-line-number convention at
`:70` and `:91-94` rather than hardcoding line numbers),
`tests/check-handoff/fixtures/decoy-real-flag-invalid.md` and
`decoy-real-flag-valid.md` (new).

**`CHECK_ACS_TIMEOUT`.** AC13 runs `tests/close-out/run.sh`, the heaviest suite
in the repository — roughly 60+ cases, each creating a directory tree and
invoking `close-out.sh`, which itself shells out to `check-handoff.sh` twice and
to `check-interventions.sh`; the line-shape harness alone is 29 close-out runs
plus 29 oracle runs. pm-spec cannot time it (no shell) and will not pretend
otherwise, but it plausibly exceeds the 120s default. **Run
`CHECK_ACS_TIMEOUT=900`** for the check-acs pass, and record the measured
wall-clock of AC13 in the provenance record so a later task can set this from
data instead of from caution. Every other criterion is greps, one `git` read, or
a fast suite. If AC13 is measured well under 120s, say so and drop the elevation
next time.

**Gotchas.**

- `templates/prompt-blocks/board-line-format.md`'s two lines currently live in
  `bin/check-handoff.sh`'s **header comment** (`:4-6`), directly above the region
  being edited. Rewriting that comment is the most likely way to break AC10.
- The em-dash is U+2014 everywhere — in `LINE_RE`, in the fixtures, and in the
  `check:` values above. A U+2013 substituted by an editor is a silent break.
- `tests/close-out/run.sh:956` mentions the phrase "decoy separator" in an axes
  comment; AC12 matches on `- [ ] **T-901** decoy separator` precisely to avoid
  it. If you edit that comment, AC12's count clause is what will tell you.
- Do not touch `tests/close-out/run.sh`. AC12 reads it, AC13 runs it, and it is
  not on the allow-list — the flip is supposed to be observed there, not
  accommodated.
- The two new fixtures need the same shape as the existing negative fixtures
  (`# Tasks` / `## Active` / entries / `## Done`) so the awk section extraction
  behaves, and `decoy-real-flag-invalid.md` needs at least one ordinary valid
  entry so AC1's exact-count-of-1 assertion is meaningful rather than trivially
  true on a one-line file.

**Prior art.** `tests/check-handoff/run.sh:4` (M1's history — read it before
choosing the fix shape), `bin/close-out.sh:319` (the rightmost-resolving regex
this fix aligns with), `bin/close-out.sh:348-379` (the caller that trusts this
checker's verdict and transcribes its stderr).
