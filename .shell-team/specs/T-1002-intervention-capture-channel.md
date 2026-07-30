# T-1002 — an intervention-capture channel, and a fail-closed gate that makes it mandatory

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1
**Task ID**: T-1002
**Source**: GitHub issue #37 (RipsawJP/shell-team), filed as T-1001's fast-follow; addresses issue #28's third direction in part — its trigger points 1, 3 and 5.
**Branch**: `feature/intervention-capture-channel` (from `develop`).

## Problem

The retro has no channel for the moments a human intervened. Issue #37 states the
gap in one sentence — **"a log preserves what happened; it does not preserve what
mattered"** — and names five trigger points. Two of them already have channels
that T-1001 declared as retro inputs: gate verdicts land in `runs/*.jsonl`
(trigger 2) and non-trivial decisions land in `provenance/<task-id>.md`
(trigger 4). The other three have nowhere to go: **(1)** a human interrupts,
corrects, or stops the work; **(3)** a measurement contradicts a stated
assumption; **(5)** work is abandoned, deferred, or reverted. In the session that
produced #37 the maintainer intervened roughly ten times across T-1001's five
rounds, and the mechanism captured none of it — the record of those ten moments
exists only in a conversation transcript that the retro does not read and that
the next run cannot see.

Issue #37 also names the hard part, and it is not the file format: **"who writes
it."** A human interruption arrives in conversation, and the only participant
that sees the conversation is the coordinator. Every existing per-task record in
this loop is written by the engineer, so a channel modelled on `provenance/`
would be handed to the one role that structurally cannot observe the events it
is being asked to record.

## Goal

<!-- BEGIN intent-block: T-1002 -->

A human intervention leaves a durable, machine-checked record in the repository,
written by the participant that can actually see it, at the moment it happens —
and a task cannot reach Validate without that record existing and being
well-formed.

**The channel.** `<base>/interventions/` holds one append-only markdown file per
task (`<task-id>.md`), plus one well-known file (`no-task.md`) for work that runs
outside a board task. The directory is resolved through a new `interventions`
key in `bin/team-paths.sh` and scaffolded by `bin/team-init.sh`, so it exists in
an adopter's tree the same way `provenance/` does, in both supported layouts and
under a `$TEAM_RUN_BASE` override. It is git-tracked, never ignored.

**The grammar.** Each entry is a **summary**, never a transcript: a class drawn
from a **closed seven-member English enum**, a date, one line saying what
happened, and one line saying what changed as a result. The enum covers issue
#37's trigger points 1, 3 and 5 and nothing else. A file with nothing to record
carries a **zero-entry sentinel** rather than being empty, so "no intervention
happened" and "nobody wrote anything" are different states — the same honesty
role the zero-decision sentinel plays in `bin/check-provenance.sh`, and the
reason the gate below is not pressure to fabricate entries. The grammar is
machine-checkable and **fail closed**: an unrecognised class, a missing field, a
duplicated field, an empty value, a value wrapped onto a second line, a
malformed date, a sentinel coexisting with an entry, a region with neither, and
any unrecognised non-blank line are each a reported violation rather than a
tolerated one.

**The checker.** `bin/check-interventions.sh` verifies that grammar and nothing
else, with the same four-outcome exit discipline as its sibling
`bin/check-provenance.sh` — usage / missing / unreadable / directory argument
exit **2** (`usage`), marker-structure faults exit **2** (`structural`), grammar
faults exit **1** (`schema`), a conforming file exits **0** (`conformant`) — and
a classification token on stderr for every rejection, so a caller can tell a
broken invocation from a genuine violation without parsing prose. It is pure
bash, zero-dependency, shellcheck-clean, and writes nothing.

**The gate, and who the producer is.** A new **unconditional** gate sits at the
Implement→Validate seam in `skills/run/SKILL.md`, alongside the T-075 provenance
gate: before Validate starts, the task's interventions file must exist and the
checker must report `conformant`. On any other outcome, Validate does not start,
nothing is silently retried, and the failure is escalated to the human with the
checker's classification line quoted — the same simple, human-escalation form
T-077 confirmed as the permanent design for the provenance gate. The **producer
is the orchestrator**, not the engineer: interventions arrive in the main
conversation, which only the orchestrator sees. That asymmetry is stated
wherever the gate is stated, and `agents/engineer.md` gains no interventions
obligation at all.

**The producer discipline.** `skills/run/SKILL.md` carries standing
instructions: when a user message arrives during an active task and it
interrupts, corrects, or stops the work, the orchestrator appends the entry **at
that moment, before acting on the message**; a routine gate response — a plain
GO, an approval, an answer to a question the orchestrator itself asked — is not
an intervention and gets no entry. Triggers 3 and 5 are self-checked at existing
checkpoints: each phase transition, every `STOP:` escalation, and a task abort.

**Nothing this task adds coerces an adopter's environment.** Every invocation
instruction it writes names the bare script name, which is on `PATH` when the
plugin is loaded, with `bin/…` only ever as a parenthetical fallback — and the
existing live-file lock that catches the coercive form is **extended to the new
checker's name**, so the class T-1001 closed for one script cannot reappear
through the other. The closed class enum exists in exactly one file and is
verified into its consumers by `bin/check-prompt-sync.sh` rather than copied.

**What the gate proves, and what it cannot.** It proves the record exists and
its grammar is valid. It cannot prove that every intervention was recorded, nor
that an entry was written at the moment rather than reconstructed afterwards —
the same trust boundary `bin/check-provenance.sh` declares. In the shipped
default the at-the-moment property rests on the standing instruction; a
mechanical at-the-moment prompt is an opt-in sample belonging to a later task.
No criterion below claims otherwise.

## Non-goals

- **The retro ledger's ninth input id (`interventions`).** Promoting this
  directory into `bin/retro-inputs.sh`, `bin/check-retro.sh`,
  `templates/prompt-blocks/retro-inputs.md`, `agents/scrum-master.md`,
  `docs/templates/retro-template.md` and their fixtures is **T-1003**, the next
  task. This task's directory shape was chosen precisely so that T-1003 reuses
  `report_dir_input` with zero new promotion sites, leaving T-1001's AC2 pin of
  **exactly eight** promotion call sites untouched here. Adding a ninth input in
  this task would break that pin and force a spec revision of a frozen intent.
- **Any hook, and any edit to `docs/tuning-oversight.md`.** The opt-in sample
  hook that would make the at-the-moment property mechanical, and the
  qualification of that document's `**This project ships no hooks.**` sentence,
  are **T-1004**. Nothing here ships an active hook, and this is a posture rule
  rather than a sequencing convenience: a public repository is the wrong place
  for executable configuration to arrive by default, and this task must not be
  the change that makes it arrive.
- **Trigger points 2 and 4.** Already channelled (`runs/*.jsonl`,
  `provenance/<task-id>.md`) and already declared retro inputs by T-1001.
- **A policy for what single-pass work owes the retro** (issue #28's direction
  4). This task gives taskless work a filename and a grammar; whether such work
  is *obliged* to write anything is decided when #28 is dispositioned at close.
- **Reconsidering `## Orchestrator attest`** (issue #28's direction 5).
  Untouched, for the reason T-1001 recorded: it couples to issue #20.
- **Correcting the legacy `tasks/provenance/<task-id>.md` hardcodes** across
  `skills/`, `agents/` and the generated `playbook-*.md` blocks. Issue #38, filed.
  The **new** prose this task writes resolves its path through
  `bin/team-paths.sh` and adds no new hardcode (AC18), but the existing ones are
  not this task's to fix — two of them sit inside generated marker regions
  reachable only through `bin/playbook-promote.sh`.
- **Adding `interventions/` to the layout-enumeration documents**
  (`docs/adopting.md`, `docs/distribution.md`, `skills/team-init/SKILL.md`,
  `README.md` and their `*.ja.md` mirrors). None of them lists `provenance/`
  either, so they are not mandatory surface — the T-1001 precedent — and
  touching six documents to add one line each would widen this task's diff for
  no mechanical gain. A separate consistency issue may be filed; this is a
  deliberate exclusion, not an oversight.
- **Making the checker judge an entry's truth.** Whether an intervention really
  happened, whether the summary is accurate, whether the stated effect is the
  real effect: none is machine-decidable, and none is asserted. Structure only.
- **A calendar-valid date check.** The `date:` field is validated for **format
  only** (`YYYY-MM-DD`); `2026-13-45` is conformant. The field exists to group
  entries by cycle, which a syntactically valid date already achieves, and full
  calendar validation in pure bash is a second grammar to get wrong for no gain
  the consumer can use. Declared, not overlooked (AC11).
- **Retro-facing consumption of any kind** — counting entries, clustering
  classes, reporting a tally. Nothing reads this directory in this task except
  the gate and the checker.
- **Extending `tests/errexit-safe/run.sh`** or any other existing suite beyond
  the two files this task must touch (`tests/codex-skeleton-hygiene/run.sh`,
  whose lock hardcodes a script name, and the two resolver suites).
- **Migrating past interventions.** The ten interventions from T-1001's session
  are not reconstructed into a file. They were not recorded at the time, and a
  reconstruction from memory is exactly the artefact this mechanism exists to
  replace. T-1001's board entry is where that history stays.

## Acceptance criteria

Every `check:` below runs from the repository root with no environment setup,
invokes scripts as `bash bin/<script>.sh` (the *spec's* invocation convention,
deliberately distinct from the *agent-instruction* convention AC20 governs), and
uses `develop` as the base ref where one is needed. **The exact bytes of every
canonical line this task adds are the `grep` patterns below** — there is no
second copy of them elsewhere in this spec to drift from.

Four rules apply to every criterion, each inherited from a defect a previous
task in this repository produced:

- **No negated grep without a same-target positive control.** `! grep -q … FILE`
  also passes when `FILE` cannot be read, because `grep` exits 2 and the
  negation swallows it.
- **A tolerance claim is proved by a malformed input, never a well-formed one.**
  A passing valid input cannot distinguish "accepted" from "never inspected".
- **A count is pinned in both directions**, so a list cannot grow by accretion.
- **A criterion states the boundary of what it proves.**

Several criteria build a throwaway fixture inline with an explicit `mktemp`
template (`"${TMPDIR:-/tmp}/…XXXXXX"`, per this repository's recorded
portability lesson) so that a rejection path is proved *directly* rather than
only through a case label. Where a criterion pins a fixture case by label
instead, the label proves the case exists — AC13's suite run proves every case
passes, and whether a label is attached to an assertion that tests what its name
says is a reading job belonging to QA and the cross-provider review.

- [ ] **AC1** `bin/check-interventions.sh` exists and its argument contract is
  the sibling's: `--help` exits 0; an unknown flag, a missing argument, an extra
  argument, a directory argument and an unreadable path each exit **2**; and
  every rejection prints a classification token (`check-interventions: usage: `
  or `check-interventions: structural: ` or `check-interventions: schema: `) to
  stderr, so a caller never has to parse prose. The two-exit-code contract is
  load-bearing for the gate in AC18, which branches on it.
  - check: test -f bin/check-interventions.sh && bash bin/check-interventions.sh --help >/dev/null && for a in "--no-such-flag-t1002" "" "." "bin/check-interventions.sh extra-arg-t1002"; do rc=0; eval "bash bin/check-interventions.sh $a" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 2 || exit 1; done && bash bin/check-interventions.sh . 2>&1 | grep -qE -- '^check-interventions: (usage|structural): '

- [ ] **AC2** **The class enum is closed at seven, in both directions, and lives
  in one file.** `templates/prompt-blocks/interventions-classes.md` carries
  exactly seven `- intervention: <class>` lines — `human-interrupt`,
  `human-correction`, `human-stop`, `assumption-contradicted`, `work-deferred`,
  `work-abandoned`, `unclassified` — and the checker accepts exactly those: each
  of the seven is `conformant` and an eighth token is a `schema` violation
  (exit 1). An eighth class, or the removal of one, is a change to this
  criterion, taken deliberately.
  - check: B=templates/prompt-blocks/interventions-classes.md && test -f "$B" && test "$(grep -c -- '^- intervention: ' "$B")" -eq 7 && T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac2.XXXXXX")" && for c in human-interrupt human-correction human-stop assumption-contradicted work-deferred work-abandoned unclassified; do grep -qxF -- "- intervention: $c" "$B" || exit 1; printf '<!-- BEGIN interventions: T-900 -->\n- intervention: %s\n  date: 2026-07-30\n  summary: s\n  effect: e\n<!-- END interventions: T-900 -->\n' "$c" > "$T/f.md"; bash bin/check-interventions.sh "$T/f.md" >/dev/null || exit 1; done && printf '<!-- BEGIN interventions: T-900 -->\n- intervention: human-nudge\n  date: 2026-07-30\n  summary: s\n  effect: e\n<!-- END interventions: T-900 -->\n' > "$T/g.md" && rc=0 && { bash bin/check-interventions.sh "$T/g.md" >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 1 && rm -rf "$T"

- [ ] **AC3** **An entry is a quad, and every field is required.** A top-level
  `- intervention: <class>` line is followed, before the next entry / the
  sentinel / the end of the region, by **exactly one** indented `date:`, exactly
  one indented `summary:` and exactly one indented `effect:` line, each with a
  non-empty value. A missing field, a duplicated field, or an empty value is a
  `schema` violation (exit 1). Field **order is not enforced** — an `effect:`
  written before its `summary:` is conformant — because ordering adds a rule
  without adding a property, and the sibling checker does not enforce one either.
  `effect:` is never left empty to mean "nothing changed": that case is written
  out in words.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac3.XXXXXX")" && mk() { printf '<!-- BEGIN interventions: T-900 -->\n%b<!-- END interventions: T-900 -->\n' "$1" > "$T/f.md"; }; mk '- intervention: human-stop\n  date: 2026-07-30\n  effect: e\n  summary: s\n' && bash bin/check-interventions.sh "$T/f.md" >/dev/null && for body in '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n' '- intervention: human-stop\n  summary: s\n  effect: e\n' '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  summary: s2\n  effect: e\n' '- intervention: human-stop\n  date: 2026-07-30\n  summary:\n  effect: e\n' '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect:   \n'; do mk "$body"; rc=0; bash bin/check-interventions.sh "$T/f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done && rm -rf "$T"

- [ ] **AC4** **Every field is matched anchored at line start.** An indented
  `- intervention:` line is not an entry anchor, and a zero-indent `date:` /
  `summary:` / `effect:` line is not a field — both are `schema` violations
  (exit 1) rather than silently accepted, which is the regression class the
  sibling checker's own suite already locks. The positive control is the same
  well-formed file passing.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac4.XXXXXX")" && mk() { printf '<!-- BEGIN interventions: T-900 -->\n%b<!-- END interventions: T-900 -->\n' "$1" > "$T/f.md"; }; mk '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n' && bash bin/check-interventions.sh "$T/f.md" >/dev/null && for body in '  - intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n' '- intervention: human-stop\ndate: 2026-07-30\nsummary: s\neffect: e\n'; do mk "$body"; rc=0; bash bin/check-interventions.sh "$T/f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done && rm -rf "$T"

- [ ] **AC5** **The zero-entry sentinel, and its mutual exclusion.** The line
  `no interventions occurred`, as the only non-blank line between the markers,
  is `conformant` — so a task with nothing to record still writes a file, and
  "nothing happened" is distinguishable from "nobody wrote anything". The
  sentinel and an entry cannot coexist **in either order**, a repeated sentinel
  is a violation, and a region carrying neither the sentinel nor an entry is a
  violation. All three are `schema` (exit 1).
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac5.XXXXXX")" && mk() { printf '<!-- BEGIN interventions: T-900 -->\n%b<!-- END interventions: T-900 -->\n' "$1" > "$T/f.md"; }; mk 'no interventions occurred\n' && bash bin/check-interventions.sh "$T/f.md" >/dev/null && for body in 'no interventions occurred\n- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n' '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\nno interventions occurred\n' 'no interventions occurred\nno interventions occurred\n' '\n'; do mk "$body"; rc=0; bash bin/check-interventions.sh "$T/f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done && rm -rf "$T"

- [ ] **AC6** **The marker pair is the file's own declaration of which task it
  belongs to.** A conformant file carries exactly one
  `<!-- BEGIN interventions: <id> -->` line and exactly one
  `<!-- END interventions: <id> -->` line carrying the **same** id, BEGIN
  strictly before END, matched by **exact full-line comparison** rather than a
  substring search — so a marker quoted inside a `summary:` value is never
  miscounted. The id is derived from the BEGIN marker's own capture and is
  either `T-<digits>` or the reserved literal `no-task` (the id of the taskless
  file, DP-2); anything else, and an absent / duplicated / reversed / mismatched
  pair, is `structural` (exit 2), never `schema`.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac6.XXXXXX")" && body='no interventions occurred\n' && printf "<!-- BEGIN interventions: no-task -->\n$body<!-- END interventions: no-task -->\n" > "$T/ok.md" && bash bin/check-interventions.sh "$T/ok.md" >/dev/null && printf "$body" > "$T/a.md" && printf "<!-- BEGIN interventions: T-900 -->\n$body<!-- END interventions: T-901 -->\n" > "$T/b.md" && printf "<!-- END interventions: T-900 -->\n$body<!-- BEGIN interventions: T-900 -->\n" > "$T/c.md" && printf "<!-- BEGIN interventions: T-900 -->\n$body<!-- END interventions: T-900 -->\n<!-- BEGIN interventions: T-900 -->\n$body<!-- END interventions: T-900 -->\n" > "$T/d.md" && printf "<!-- BEGIN interventions: nope -->\n$body<!-- END interventions: nope -->\n" > "$T/e.md" && for f in a b c d e; do rc=0; bash bin/check-interventions.sh "$T/$f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 2 || exit 1; done && rm -rf "$T"

- [ ] **AC7** **`--task <id>` closes the wrong-file hazard the gate cannot
  see.** Given `--task`, a BEGIN-marker id that differs from it is `structural`
  (exit 2); a matching id behaves exactly as the flagless invocation. Without
  the flag the checker stays self-contained (AC6). The gate in AC18 passes the
  flag, so an interventions file copied from another task — the one mistake the
  gate's own existence check cannot catch, because the file does exist — fails
  closed instead of passing.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac7.XXXXXX")" && printf '<!-- BEGIN interventions: T-900 -->\nno interventions occurred\n<!-- END interventions: T-900 -->\n' > "$T/f.md" && bash bin/check-interventions.sh --task T-900 "$T/f.md" >/dev/null && rc=0 && { bash bin/check-interventions.sh --task T-901 "$T/f.md" >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && bash bin/check-interventions.sh --task T-901 "$T/f.md" 2>&1 | grep -qF -- 'check-interventions: structural: ' && rm -rf "$T"

- [ ] **AC8** **A file that discusses its own grammar is still conformant.**
  This repository habitually describes a mechanism inside the artefact the
  mechanism governs, so a `summary:` or `effect:` value that quotes a marker
  literal, another field's keyword, a class token, or the sentinel string must
  not be miscounted as a second structural occurrence. Proved directly on a file
  whose values quote all four.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac8.XXXXXX")" && { printf '<!-- BEGIN interventions: T-900 -->\n'; printf -- '- intervention: unclassified\n'; printf '  date: 2026-07-30\n'; printf '  summary: the file quotes <!-- BEGIN interventions: T-901 --> and no interventions occurred and effect: x inside this value\n'; printf '  effect: the value also names - intervention: human-stop and <!-- END interventions: T-901 --> without adding an entry\n'; printf '<!-- END interventions: T-900 -->\n'; } > "$T/f.md" && bash bin/check-interventions.sh "$T/f.md" >/dev/null && rm -rf "$T"

- [ ] **AC9** **CRLF tolerance is proved against a malformed file.** A file with
  CRLF line endings whose entry is **broken** — a class token that is not in the
  enum — is **still reported** (exit 1). A well-formed CRLF file passing would
  prove nothing, because a checker that never examines the file produces the same
  result; that mistake shipped a blocker in T-1001 and is not repeated here. The
  positive control is the same CRLF bytes with a valid class passing.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac9.XXXXXX")" && printf '<!-- BEGIN interventions: T-900 -->\r\n- intervention: human-nudge\r\n  date: 2026-07-30\r\n  summary: s\r\n  effect: e\r\n<!-- END interventions: T-900 -->\r\n' > "$T/bad.md" && rc=0 && { bash bin/check-interventions.sh "$T/bad.md" >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 1 && printf '<!-- BEGIN interventions: T-900 -->\r\n- intervention: human-stop\r\n  date: 2026-07-30\r\n  summary: s\r\n  effect: e\r\n<!-- END interventions: T-900 -->\r\n' > "$T/ok.md" && bash bin/check-interventions.sh "$T/ok.md" >/dev/null && rm -rf "$T"

- [ ] **AC10** **One physical line per field.** A producer writing a paragraph
  that wraps onto a second, unindented line is a reachable mistake, and the
  continuation line is an unrecognised non-blank line inside the region: a
  `schema` violation (exit 1), not silently absorbed into the field above.
  Blank lines inside the region are ignored everywhere, which is the positive
  control that the region walk is not simply rejecting whitespace.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac10.XXXXXX")" && printf '<!-- BEGIN interventions: T-900 -->\n\n- intervention: human-stop\n\n  date: 2026-07-30\n  summary: s\n  effect: e\n\n<!-- END interventions: T-900 -->\n' > "$T/ok.md" && bash bin/check-interventions.sh "$T/ok.md" >/dev/null && printf '<!-- BEGIN interventions: T-900 -->\n- intervention: human-stop\n  date: 2026-07-30\n  summary: the first line of the summary\nand its continuation on an unindented second line\n  effect: e\n<!-- END interventions: T-900 -->\n' > "$T/bad.md" && rc=0 && { bash bin/check-interventions.sh "$T/bad.md" >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 1 && rm -rf "$T"

- [ ] **AC11** **The date is validated for format only, and says so.** A
  `date:` value that is not `YYYY-MM-DD` (four digits, hyphen, two digits,
  hyphen, two digits, nothing else) is a `schema` violation (exit 1). A
  format-valid but calendar-invalid value such as `2026-13-45` is **conformant**
  — a declared limit, not an oversight: the field exists to group entries by
  cycle, and the checker's own header states the boundary so no reader infers a
  calendar check that does not exist.
  - check: T="$(mktemp -d "${TMPDIR:-/tmp}/t1002-ac11.XXXXXX")" && mk() { printf '<!-- BEGIN interventions: T-900 -->\n- intervention: human-stop\n  date: %s\n  summary: s\n  effect: e\n<!-- END interventions: T-900 -->\n' "$1" > "$T/f.md"; }; mk '2026-13-45' && bash bin/check-interventions.sh "$T/f.md" >/dev/null && for d in '2026-7-30' '30-07-2026' 'yesterday' '2026-07-30 14:02' '20260730'; do mk "$d"; rc=0; bash bin/check-interventions.sh "$T/f.md" >/dev/null 2>&1 || rc=$?; test "$rc" -eq 1 || exit 1; done && grep -qF -- 'the date is validated for FORMAT only (YYYY-MM-DD); calendar validity is deliberately not checked' bin/check-interventions.sh && rm -rf "$T"

- [ ] **AC12** **The checker adds no dependency and writes nothing.** It is
  shellcheck-clean at the version CI pins; no non-comment line invokes a
  file-creating command or a non-POSIX tool; and two consecutive runs leave the
  working tree's git status byte-identical. The runs must also succeed, which is
  the positive control.
  - check: shellcheck bin/check-interventions.sh tests/check-interventions/run.sh && before="$(git status --porcelain)" && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1002.md" >/dev/null && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1002.md" >/dev/null && test "$(git status --porcelain)" = "$before" && nc="$(grep -vE '^[[:space:]]*#' bin/check-interventions.sh)" && test -n "$nc" && ! printf '%s\n' "$nc" | grep -qE -- '(mktemp|[[:space:]](tee|cp|mv|rm|touch|jq|yq|python[0-9]?|perl|node)[[:space:]])'

- [ ] **AC13** **The fixture suite covers sixteen case classes, the count is
  pinned in both directions, and every case passes.** `tests/check-interventions/run.sh`
  builds its fixtures inline under an explicit `mktemp` template (never a nested
  `git init` inside this repository's tree, which sandbox policy denies), asserts
  **both** the exit code and the stderr classification token for every rejection,
  and carries its own executed-case-class counter checked against
  `CASES_EXPECTED=16`, so adding a seventeenth case without changing this
  criterion fails the suite rather than passing silently.
  - check: S=tests/check-interventions/run.sh && test -f "$S" && grep -qF -- 'CASES_EXPECTED=16' "$S" && for l in 'case: well-formed entries are conformant' 'case: the zero-entry sentinel alone is conformant' 'case: an unknown class token is a schema violation' 'case: a missing required field is a schema violation' 'case: a duplicated field within one entry is a schema violation' 'case: an empty field value is a schema violation' 'case: the sentinel and an entry cannot coexist, in either order' 'case: a region with neither the sentinel nor an entry is a schema violation' 'case: a malformed date is a schema violation and the check is format-only' 'case: a wrapped field value on a second unindented line is a schema violation' 'case: absent, duplicated, reversed and id-mismatched markers are structural errors' 'case: usage errors — no argument, an extra argument, a directory, an unreadable file' 'case: a MALFORMED file with CRLF line endings is still reported' 'case: field values quoting a marker, a class token or the sentinel are not miscounted' 'case: the three invocation forms agree on rc and produce byte-identical output' 'case: a --task disagreement is structural and the reserved no-task id is accepted'; do grep -qF -- "$l" "$S" || exit 1; done && test "$(grep -c -- 'check-interventions.sh' "$S")" -ge 16 && bash "$S" >/dev/null

- [ ] **AC14** `bin/team-paths.sh` resolves an `interventions` key in **every**
  mode a consumer can use: `--get interventions`, `TEAM_INTERVENTIONS_DIR` in
  `--export`, a row in `--print`, the key named in `--help`, and the key named in
  the unknown-key error message. An unknown key still exits 2. The resolver's own
  suite covers the default and legacy layouts in the idiom it already uses, and
  the `--print` table's columns are re-padded so the new, longer key does not
  overrun them (DP-6).
  - check: test "$(bash bin/team-paths.sh --get interventions)" = ".shell-team/interventions" && bash bin/team-paths.sh --export | grep -qE -- '^export TEAM_INTERVENTIONS_DIR=' && bash bin/team-paths.sh --print | grep -qE -- '^[[:space:]]+interventions[[:space:]]+\.shell-team/interventions$' && bash bin/team-paths.sh --print | grep -qE -- '^[[:space:]]+provenance[[:space:]]+\.shell-team/provenance$' && bash bin/team-paths.sh --help | grep -qF -- 'interventions' && rc=0 && { bash bin/team-paths.sh --get no-such-key-t1002 >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && bash bin/team-paths.sh --get no-such-key-t1002 2>&1 | grep -qF -- 'interventions' && test "$(grep -ci -- 'interventions' bin/team-paths.sh)" -ge 8 && grep -qF -- 'default: interventions path wrong' tests/team-paths/run.sh && grep -qF -- 'legacy: interventions path wrong' tests/team-paths/run.sh && bash tests/team-paths/run.sh >/dev/null

- [ ] **AC15** **The resolver's key set is pinned at nine in both directions, and
  the resolver's own suite carries that pin.** All nine keys resolve, an unlisted
  key exits 2, `--export` prints exactly nine `export TEAM_` lines and `--print`
  exactly nine rows — so a tenth key added without updating this criterion fails
  it, and a key silently dropped from one mode fails it too. The same total
  assertion lives in `tests/team-paths/run.sh`, because that suite previously
  asserted only per-key paths: a key missing from its list failed nothing.
  - check: for k in base todo loops runs retros reviews specs provenance interventions; do bash bin/team-paths.sh --get "$k" >/dev/null || exit 1; done && rc=0 && { bash bin/team-paths.sh --get lessons >/dev/null 2>&1 || rc=$?; } && test "$rc" -eq 2 && test "$(bash bin/team-paths.sh --export | grep -c -- '^export TEAM_')" -eq 9 && test "$(bash bin/team-paths.sh --print | grep -cE -- '^[[:space:]]+[a-z]+[[:space:]]+[^[:space:]]+$')" -eq 9 && grep -qF -- 'total-key set is exactly nine' tests/team-paths/run.sh

- [ ] **AC16** `bin/team-init.sh` scaffolds `<base>/interventions/.gitkeep`, its
  `--help` lists it, and `tests/team-init/run.sh` asserts the scaffolded path.
  The directory is **git-tracked**: `<base>/.gitignore` does not ignore it, with
  the fact that it *does* ignore `runs/` as the positive control that the
  negative assertion is reading a real file.
  - check: grep -qF -- '<base>/interventions/.gitkeep' bin/team-init.sh && grep -qF -- 'ensure_gitkeep "$TEAM_INTERVENTIONS_DIR"' bin/team-init.sh && grep -qF -- '.shell-team/interventions/.gitkeep' tests/team-init/run.sh && bash tests/team-init/run.sh >/dev/null && G=templates/shell-team.gitignore && test -f "$G" && grep -qF -- 'runs/' "$G" && ! grep -qF -- 'interventions' "$G" && test -f .shell-team/.gitignore && grep -qF -- 'runs/' .shell-team/.gitignore && ! grep -qF -- 'interventions' .shell-team/.gitignore

- [ ] **AC17** **The class enum has exactly one canonical home, verified rather
  than asserted.** `templates/prompt-blocks/interventions-classes.md` is
  registered in `templates/prompt-blocks/registry.txt` in `contain` mode with
  both consumers — `bin/check-interventions.sh` and `skills/run/SKILL.md` — and
  `bin/check-prompt-sync.sh` is green, so the seven tokens and the
  routine-response exclusion cannot drift between the checker that enforces them
  and the instructions that produce them.
  - check: grep -qE -- '^contain[[:space:]]+interventions-classes\.md[[:space:]]+bin/check-interventions\.sh[[:space:]]+skills/run/SKILL\.md[[:space:]]*$' templates/prompt-blocks/registry.txt && test -f templates/prompt-blocks/interventions-classes.md && grep -qxF -- 'A routine gate response — a plain GO, an approval, or an answer to a question you asked — is not an intervention and gets no entry.' templates/prompt-blocks/interventions-classes.md && bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null

- [ ] **AC18** **The gate is one unconditional paragraph at the Implement→Validate
  seam, and it resolves its own path.** `skills/run/SKILL.md` step 4 carries a
  paragraph anchored `**Interventions gate at the Implement-to-Validate seam
  (T-1002)**` which, on its own single line, states: the file is located through
  `team-paths.sh --get interventions`; the checker must report `conformant`; the
  gate is **fail-closed** and **unconditional**; on any other outcome Validate
  does not start, nothing is auto-retried, and the human is escalated to with the
  checker's **classification** line quoted; and that the **orchestrator** is the
  producer. That line contains **no** hardcoded `tasks/` or `.shell-team/` path
  literal — the defect issue #38 exists to clean up is not reintroduced by the
  prose that adds a gate.
  - check: F=skills/run/SKILL.md && test -f "$F" && n="$(grep -n -- 'Interventions gate at the Implement-to-Validate seam' "$F" | head -n 1 | cut -d: -f1)" && test -n "$n" && P="$(sed -n "${n}p" "$F")" && for s in 'team-paths.sh --get interventions' '--task' 'conformant' 'fail-closed' 'unconditional' 'classification' 'orchestrator' 'do not start Validate'; do printf '%s\n' "$P" | grep -qF -- "$s" || exit 1; done && ! printf '%s\n' "$P" | grep -qE -- '(^|[^A-Za-z0-9_./-])tasks/|\.shell-team/'

- [ ] **AC19** **The producer discipline is standing, at-the-moment, and bounded.**
  `skills/run/SKILL.md` carries a paragraph anchored
  `**Interventions producer discipline (T-1002)**` stating all five of: trigger 1
  is appended **at that moment, before you act on the message**; a routine gate
  response is **not** an intervention (the canonical exclusion sentence, shared
  with the enum block); trigger 3 is self-checked when a measurement contradicts
  a stated assumption; trigger 5 is self-checked when work is deferred,
  abandoned or reverted; and the self-checks happen at the existing checkpoints —
  each phase transition, every `STOP:` escalation, and a task abort.
  - check: F=skills/run/SKILL.md && test -f "$F" && for s in '**Interventions producer discipline (T-1002)**' 'append the entry at that moment, before you act on the message' 'A routine gate response — a plain GO, an approval, or an answer to a question you asked — is not an intervention and gets no entry.' 'when a measurement contradicts an assumption you have stated' 'when work is deferred, abandoned or reverted' 'at each phase transition, at every `STOP:` escalation, and when a task is aborted'; do grep -qF -- "$s" "$F" || exit 1; done

- [ ] **AC20** **Nothing this task writes coerces an adopter's environment.**
  Every agent-facing file it touches (`skills/run/SKILL.md`,
  `skills/goal/SKILL.md`, `agents/qa-verifier.md`) names the checker by its
  **bare** name as the primary form, with `bin/check-interventions.sh` only ever
  inside the parenthetical fallback and **never** preceded by an interpreter —
  the plugin's `bin/` is on an adopter's `PATH` but does not exist in an
  adopter's tree, so an interpreter-prefixed relative path fails there silently.
  Mechanically: the bare name appears in each file, the fallback phrasing this
  repository already uses is present, and the coercive form's match count is zero
  in all three.
  - check: for F in skills/run/SKILL.md skills/goal/SKILL.md agents/qa-verifier.md; do test -f "$F" || exit 1; grep -qF -- 'check-interventions.sh' "$F" || exit 1; grep -qF -- 'on `PATH` when the plugin is loaded; else `bin/check-interventions.sh`' "$F" || exit 1; test "$(grep -cE -- '(^|[[:space:]])([^[:space:]]*/)?(bash|sh|source|\.)[[:space:]]+bin/check-interventions\.sh' "$F")" -eq 0 || exit 1; done

- [ ] **AC21** **The live-file lock is extended to the new checker, and the
  extension is proved to add coverage.** `tests/codex-skeleton-hygiene/run.sh`'s
  two ZERO-match live-file regexes name **both** checkers rather than hardcoding
  one: the broken-invocation regex covers
  `bin/check-(provenance|interventions).sh` and the stateful-trace regex covers
  `(provenance|interventions) gate:AC<digit>`. Two new mutation cases prove the
  extension is not vacuous — an injected `bash bin/check-interventions.sh` line
  and an injected `interventions gate:AC1` line are each caught in a mutated
  `$TMPDIR` copy — and two `oldmiss` cases prove the extension genuinely widens
  the lock: the **frozen** T-077 literals miss both injections, so reverting the
  extension makes this suite red. The suite passes.
  - check: S=tests/codex-skeleton-hygiene/run.sh && test -f "$S" && for l in 'bin/check-(provenance|interventions)\.sh' '(provenance|interventions)[-[:space:]]+gate:AC' 'livefile-mutation-ac3-interventions' 'livefile-mutation-ac15-interventions' 'oldmiss (AC3, interventions)' 'oldmiss (AC15, interventions)' 'bin/check-provenance\.sh'; do grep -qF -- "$l" "$S" || exit 1; done && bash "$S" >/dev/null

- [ ] **AC22** **QA verifies the record too, and the item is mandatory.**
  `agents/qa-verifier.md` carries a verification item — written in **English**,
  per this repository's language rule for agent-facing files, even though its
  neighbouring items carry inherited Japanese prose — requiring
  `check-interventions.sh` to report `conformant` for the task's interventions
  file, treating `usage` / `schema` / `structural` alike as a FAIL, judging
  **structure only** (never whether an intervention was classified correctly),
  and stating that this item is **not** subject to the `## Input space`
  out-of-input-space exemption.
  - check: F=agents/qa-verifier.md && test -f "$F" && for s in 'Read the task'"'"'s intervention record as a primary input' 'structure only — never whether a class token was the right choice' 'not subject to the out-of-input-space exemption' 'check-interventions.sh'; do grep -qF -- "$s" "$F" || exit 1; done

- [ ] **AC23** **The goal loop's signature vocabulary is mirrored additively, and
  the two new sentinels are measurably distinct.** `skills/goal/SKILL.md`
  translates the checker's outcomes into existing signature vocabulary —
  `conformant` → `check-interventions: PASS`, `schema` →
  `check-interventions: FAIL AC900005`, `usage`/`structural` →
  `check-interventions: FAIL AC900006` — and names the new gate in the combined
  `SIG` text template inside its fenced Bound-gate block, so the raw
  `conformant`/`schema`/`usage` words are never concatenated (they are outside
  `goal-state.sh`'s recognised vocabulary and would be silently dropped).
  `bin/goal-state.sh` itself is **not** modified. The reserved-sentinel id set in
  that file is pinned at exactly `AC900001`–`AC900006`, in both directions, and
  the distinctness is **measured** rather than asserted: all three new outcome
  texts, and the four pre-existing sentinels, produce seven different signatures.
  - check: F=skills/goal/SKILL.md && test -f "$F" && test "$(grep -ohE -- 'AC9000[0-9][0-9]' "$F" | sort -u | tr '\n' ' ')" = "AC900001 AC900002 AC900003 AC900004 AC900005 AC900006 " && grep -qF -- 'check-interventions (translated)' "$F" && grep -qF -- 'check-interventions: FAIL AC900005' "$F" && grep -qF -- 'check-interventions: FAIL AC900006' "$F" && git diff --quiet develop -- bin/goal-state.sh && out="$(for t in 'check-interventions: PASS' 'check-interventions: FAIL AC900005' 'check-interventions: FAIL AC900006' 'check-intent: FAIL AC900001' 'check-intent: FAIL AC900002' 'check-provenance: FAIL AC900003' 'check-provenance: FAIL AC900004'; do printf '%s' "$t" | bash bin/goal-state.sh signature; done)" && test "$(printf '%s\n' "$out" | grep -c .)" -eq 7 && test "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" -eq 7

- [ ] **AC24** **CI runs all of it, and the dogfood step cannot pass vacuously.**
  `.github/workflows/check-handoff.yml` names the new script and its suite on the
  shellcheck argument list, runs the suite as a step, and dogfoods the checker
  against **every** committed file in this repository's own interventions
  directory with a `found` counter asserted `-ge 1`, so an empty or renamed
  directory fails the step instead of silently passing over zero files.
  `.shell-team/test-recipe.md` records the new suite's procedure under its
  append-only section.
  - check: W=.github/workflows/check-handoff.yml && grep -qF -- 'bin/check-interventions.sh tests/check-interventions/run.sh' "$W" && grep -qF -- 'bash tests/check-interventions/run.sh' "$W" && grep -qF -- 'bash bin/check-interventions.sh "$f"' "$W" && grep -qF -- 'test "$found" -ge 1' "$W" && grep -qF -- 'T-1002' .shell-team/test-recipe.md && grep -qF -- 'tests/check-interventions/run.sh' .shell-team/test-recipe.md

- [ ] **AC25** **The mechanism is dogfooded by this task's own records.** The
  interventions file for T-1002 exists at the path the **new resolver key**
  reports, is `conformant` under `--task T-1002`, and this task's decision
  provenance file is conformant too. Both are located through
  `bin/team-paths.sh`, never a hardcoded path, so the key AC14 adds is exercised
  by this criterion rather than only asserted by it.
  - check: I="$(bash bin/team-paths.sh --get interventions)/T-1002.md" && test -f "$I" && bash bin/check-interventions.sh --task T-1002 "$I" >/dev/null && bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1002.md" >/dev/null

- [ ] **AC26** **Posture and producer asymmetry, both held mechanically.** No
  hook ships: no path in this change set is a hook, and
  `docs/tuning-oversight.md` is untouched with its
  `**This project ships no hooks.**` sentence intact — the opt-in sample hook and
  that document's qualification are T-1004's, and this task must not be the
  change that makes executable configuration arrive by default. And the engineer
  gains no interventions obligation: `agents/engineer.md` is byte-unchanged from
  `develop` and names the token nowhere, with its existing `provenance` mention
  as the positive control that the negative grep is reading a real file.
  - check: grep -qF -- '**This project ships no hooks.**' docs/tuning-oversight.md && git diff --quiet develop -- docs/tuning-oversight.md && git diff --quiet develop -- agents/engineer.md && grep -qF -- 'provenance' agents/engineer.md && ! grep -qi -- 'intervention' agents/engineer.md && d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -iE -- 'hook')"

- [ ] **AC27** **The change stays inside its declared surface.** Every path in
  `git diff --name-only develop` matches the allow-list below, and the diff is
  non-empty as a positive control. The list already carries this task's mandatory
  records (spec, board, provenance, review, interventions), so no round has to
  widen it to hand off. **Merge-point-scoped**: this criterion is tied to the
  merge point it was authored at and is **expected to go stale** after merge,
  when later work moves `develop` forward. Do not merge-range it, re-derive it
  per rework round, or widen its base-ref resolution — that trades away the only
  thing it exists to confine.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.github/workflows/check-handoff\.yml|\.shell-team/(todo\.md|test-recipe\.md|specs/T-1002-intervention-capture-channel\.md|provenance/T-1002\.md|reviews/T-1002[^/]*|interventions/[^/]+\.md)|agents/qa-verifier\.md|bin/(check-interventions|team-init|team-paths)\.sh|skills/(run|goal)/SKILL\.md|templates/prompt-blocks/(registry\.txt|interventions-classes\.md)|tests/(check-interventions|codex-skeleton-hygiene|team-init|team-paths)/.+)$')"

- [ ] **AC28** **Nothing that already worked stops working.** The board linter on
  the shipped template and on this repository's own board, the sibling provenance
  checker against a real conformant file, and the two suites this task edits but
  no criterion above runs on their own — all green. Suites already run by AC13,
  AC14, AC16, AC17 and AC21 are not repeated here.
  - check: bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1001.md" >/dev/null && bash bin/check-board-headings.sh "$(bash bin/team-paths.sh --get todo)" --base develop >/dev/null && bash tests/check-provenance/run.sh >/dev/null

## Input space

**Reachable input classes** — what real usage of this mechanism can produce, and
what the implementation must therefore be correct about:

1. **An interventions file at every population level**: zero entries (the
   sentinel), one entry, and tens of entries appended across many rounds of one
   task. T-1001's five rounds and roughly ten interventions is the measured
   scale of a single task's file.
2. **A file whose field values quote the mechanism's own vocabulary** — a marker
   literal, another field's keyword, a class token, or the sentinel string. This
   repository describes its mechanisms inside the artefacts those mechanisms
   govern, so this is habitual rather than adversarial.
3. **CRLF line endings**, including on a file whose entry is malformed.
4. **A hand-edited or copy-pasted marker region**: markers absent, duplicated,
   reversed, or carrying a task id that disagrees between BEGIN and END, or with
   the file's own name. The last of these is the concrete failure mode of the
   orchestrator writing many files across many tasks in one session.
5. **The taskless file** (`no-task.md`) accumulating entries over many sessions
   with no task id to group them, which is why the date field exists.
6. **A producer writing under interrupt pressure**: a wrapped field value on a
   second unindented line, a missing field, a duplicated field, an empty value, a
   date typed in another format (`2026-7-30`, `30-07-2026`, a date with a time
   appended), and a class that the producer believes fits none of the six named
   ones — which is what `unclassified` exists for.
7. **A producer tempted to paste conversation** instead of summarising it. The
   grammar's `summary:`/`effect:` field names and the one-physical-line rule are
   the discipline; `bin/check-pii-shapes.sh`, already wired into CI over the
   committed content of every changed path, is the mechanical backstop, and it
   needs no change to cover this directory.
8. **All three invocation forms**: the bare name on `PATH` with the plugin
   loaded, `bash bin/check-interventions.sh`, and `./bin/check-interventions.sh`
   — including through a symlink on `PATH`, which is how a plugin install exposes
   `bin/`.
9. **A path argument that is not a readable regular file**: missing, a directory,
   a FIFO, unreadable, or a dangling symlink.
10. **Both supported layouts** (the `.shell-team/` default and the legacy
    `tasks/` split-root layout) and a `$TEAM_RUN_BASE` override, in every mode of
    the resolver, plus a fresh adopter tree where `team-init.sh` has just created
    the directory and it contains only `.gitkeep`.
11. **The gate firing before the file exists at all** — the ordinary first
    encounter for any task whose orchestrator has not yet written a record. This
    is a `usage` exit, and it must escalate rather than be absorbed.

**Out-of-scope synthetic extremes** — named and declined:

1. **Adversarially large inputs**: thousands of entries in one file,
   megabyte-scale `summary:` values, a marker region megabytes long. The
   measured scale is class 1 above, and no threshold in this mechanism is
   size-dependent — there is no pipeline, no cap, and no buffer, which is the
   one size-related class T-1001 accepted and this task does not reproduce.
2. **Non-UTF-8 or mixed encodings, NUL bytes, Unicode line separators
   (U+2028 / U+2029) and bidirectional control characters** inside field values.
   None is a record separator for any POSIX text tool, so none can forge an entry
   line or a marker; the residual display-level concern belongs to a
   repository-wide content guard over every tracked file rather than to this
   checker, exactly as T-1001 recorded for the same class.
3. **A hostile author.** A file that claims the sentinel while ten interventions
   happened, or whose summaries are fiction, is `conformant` — this is a
   discipline aid for a trusted, committed, reviewed artefact, not a security
   boundary, the same trust boundary `bin/check-provenance.sh` and
   `bin/check-acs.sh` declare.
4. **Calendar-invalid but format-valid dates** (`2026-13-45`). Declined with its
   reason in the Non-goals and stated in the checker's own header (AC11).
5. **Markdown-notation attacks on the marker match**: an ATX-closing
   `<!-- BEGIN interventions: T-1 --> #`, the marker inside a fenced code block,
   or the marker indented. The declared mechanism is an exact full-line
   comparison; a marker that is not a whole line is not a marker.
6. **Concurrent writers** appending to one interventions file simultaneously, and
   a file replaced between the gate's existence check and the checker's read.
   Single-orchestrator operation is the declared model.
7. **Local agent transcripts as an input.** Issue #28 records that as an open
   question; nothing here answers it, and nothing here reads a transcript.

<!-- END intent-block: T-1002 -->

## Resolved design decisions

### DP-1 — the entry is a class + date + summary + effect quad, and the class enum is closed at seven

The grammar is the judgment core of this task, so its shape is argued rather than
assumed.

**Why a closed enum rather than free text.** A free-text label makes the record
unsearchable and the retro's job unbounded: "what did the human have to step in
about" becomes a reading task over prose instead of a count over classes. A
closed enum is also the only form a checker can fail closed on, which is what
makes an unrecognised label a reported violation rather than a silent new
category. This repository already took the same decision for the retro ledger's
three-value status enum.

**Why these seven.** Issue #37's trigger 1 is three verbs — interrupts, corrects,
stops — and they are split into three classes because the retro acts differently
on each: being asked to explain oneself, being factually wrong, and being told to
stop are three different signals about what judgment the human is still carrying.
Trigger 3 is `assumption-contradicted`. Trigger 5's three verbs collapse into two
classes rather than three, because "abandoned" and "reverted" are one outcome
from the retro's point of view — what was planned or done is discarded — whereas
"deferred" is the opposite claim (still intended, later). The rule generating
this split is one class per distinguishable decision the retro would act on
differently, and it is written here so a later task adds a class by argument
rather than by accretion.

| Issue #37 trigger point | Class token(s) |
|---|---|
| 1 — a human interrupts, corrects, or stops the work | `human-interrupt`, `human-correction`, `human-stop` |
| 3 — a measurement contradicts a stated assumption | `assumption-contradicted` |
| 5 — work is abandoned, deferred, or reverted | `work-deferred`, `work-abandoned` |
| none of the above, honestly declared | `unclassified` |

**Why `unclassified` exists, and its declared risk.** A closed enum with no
escape hatch leaves a producer facing a genuine intervention that fits nothing
with two options, both destructive: mislabel it (which corrupts the taxonomy
silently) or skip it (which destroys the record this task exists to create).
`unclassified` preserves the capture and surfaces the taxonomy gap to the retro,
whose job is exactly to notice such a gap. The risk is real and named: a
catch-all is the cheapest option under time pressure and can become the default.
Nothing mechanical prevents that — a count would be the wrong instrument, since
a legitimately high `unclassified` share is information rather than a defect — so
it is stated as a limit here and as a "last resort" in the producer instructions,
and noticing its growth is the retro's job once T-1003 makes this directory an
input.

**Why `summary:` and `effect:` rather than one field.** Issue #37's requirement
is that an entry says what happened *and* what changed as a result. One field
invites the second half to be dropped, and the second half is the part with
retro value: an intervention that changed nothing is a different fact from one
that redirected the work, and both must be sayable. `effect:` is never left empty
to mean "nothing changed"; that case is written out in words, which is why the
checker requires a non-empty value rather than merely a present key.

**Why `summary:` is named `summary:`.** The field name is the discipline. The one
thing this file must never become is a transcript of conversation — both because
a conversation transcript in a public repository is a PII surface (this is
`docs/pii-controls.md`'s subject, and `bin/check-pii-shapes.sh` scans committed
content on every pull request) and because a transcript reproduces the failure
mode issue #37 describes: a complete log with no salience. Naming the field
`summary` puts the instruction where the producer is looking when it writes.

**Why a `date:` field at all.** For a task file the task id already groups
entries by cycle, but `no-task.md` has no such grouping and grows across
sessions, so without a date it cannot answer "which cycle did this belong to" —
the exact deficiency already filed as issue #36 against another retro input. Ten
characters is a cheap price for the retro being able to ask when in a cycle the
human had to step in. Format-only validation is DP-5.

### DP-2 — taskless work gets `no-task.md`, and `no-task` is a reserved marker id

The taskless file needs a name that cannot collide with the `<task-id>.md`
convention and that reads as what it is in a directory listing. `no-task.md` does
both: no task id is `no-task`, so the two namespaces cannot overlap, and the
marker id slot accepts either `T-<digits>` or that one reserved literal, which
keeps the file self-describing in exactly the way a task file is.

The alternatives were a date-based file (`2026-07-30.md`) and a single
`_untasked.md`. A date-based file invents a rotation policy — which day owns an
intervention that spans midnight, when does a file get created, what does the
retro do with a gap — for no gain the consumer can use, because T-1003 counts
files in a directory and one growing file counts the same as thirty small ones.
An underscore prefix sorts oddly beside `T-…` names and looks like a hidden file
without being one.

### DP-3 — the producer is the orchestrator, and that asymmetry is stated everywhere the gate is

`provenance/<task-id>.md` is written by the engineer, and copying that shape
would hand this channel to the one role that structurally cannot see the events
it records: a sub-agent has no view of the main conversation, so an interruption
arriving there is invisible to it. Issue #37 names this as the hard part of the
whole design. Consequences taken deliberately:

- The gate lives in `skills/run/SKILL.md` (and its mirror in
  `skills/goal/SKILL.md`) because that is where the orchestrator's own
  instructions live, and it is stated *as* an asymmetry so a reader who knows the
  provenance gate does not assume the same producer.
- `agents/engineer.md` gains nothing, and AC26 locks it byte-unchanged. An
  engineer instructed to record interventions would either invent them or record
  nothing, and both outcomes are worse than the honest absence.
- The gate therefore checks a file the orchestrator itself wrote, which is a
  weaker check than one party verifying another's work. That is why
  `agents/qa-verifier.md` gains its own verification item (AC22): the second
  reader is what keeps the gate from being self-attestation all the way down.

### DP-4 — `--task` is an optional flag, and the gate passes it

`bin/check-provenance.sh` is deliberately self-contained: it derives the task id
from its own BEGIN marker and never cross-references a board or a spec. That
property is kept here as the default. But this channel has a failure mode the
sibling does not: one producer writes files for many tasks in one session, so an
interventions file copied from the previous task — right filename, wrong marker
id — is a reachable mistake that the gate's existence check cannot catch, because
the file does exist and its grammar is valid. `--task <id>` closes exactly that,
following `bin/check-design-note.sh`'s existing `--task` precedent rather than
inventing a mechanism, and the flagless invocation keeps the self-contained
behaviour for any other caller.

### DP-5 — the date is checked for format only, and the checker says so

Full calendar validation in pure bash (month lengths, leap years) is a second
grammar to get wrong, and its only beneficiary would be a consumer that does date
arithmetic — which nothing in this task or T-1003 does. Format validation gives
the grouping property the field exists for and rejects the mistakes a producer
actually makes (a single-digit month, a reversed order, a date with a time
appended). The boundary is written into the checker's own header, because the
recorded failure mode here is a validator whose stated purpose implies more
checking than its implementation performs.

### DP-6 — the `--print` table is re-padded rather than left overrunning

`bin/team-paths.sh --print`'s columns are hand-padded to the width of
`provenance` (ten characters); `interventions` is thirteen and overruns them. The
only pinned assertion over that output — T-1001's AC22 — matches with
`[[:space:]]+`, and no suite pins the spacing, so re-padding every row to the new
width is mechanically safe and whitespace-only. It is done because `--print`'s
entire deliverable is a readable table for a human, and one overrunning row
degrades the only thing it provides. AC14 pins both the new row and the existing
`provenance` row so the re-padding cannot silently drop one.

### DP-7 — the class enum is single-sourced through the prompt-block mechanism

The seven tokens and the routine-response exclusion have to be identical in two
places: the checker that enforces them and the instructions that produce them.
This repository's answer to exactly that problem is
`templates/prompt-blocks/` plus `bin/check-prompt-sync.sh`, already wired into
CI, and T-1001 used it for the retro ledger's enumeration. A new `contain`-mode
block costs one file and one registry row and makes drift impossible to ship;
without it, the enum's second copy is the one that goes stale, which is this
project's most frequently recorded defect. Note the registry's own scope limit: a
consumer that is not listed is invisible to the checker, so both consumers are
named in the row AC17 pins.

### DP-8 — the coercive-invocation lock is extended to both regexes, and the extension is proved to widen it

`tests/codex-skeleton-hygiene/run.sh`'s live-file locks hardcode
`check-provenance.sh`. Left alone, a coercive `bash bin/check-interventions.sh`
in the new prose would ship undetected — the `adopter-environment-coercion` class
T-1001 closed for one script, reappearing through the other. Both regexes are
extended, not just the invocation one: the stateful-trace regex has the same
hardcode and the same blind spot for a sentinel naming the new gate.

Widening a guard's scope needs revert detection, so the extension is paired with
it: two new mutation cases prove the extended regexes catch injected violations,
and two `oldmiss` cases prove the **frozen** T-077 literals miss those same
injections. The pair means the extension cannot be quietly reverted — a revert
turns the oldmiss cases' contrast into a contradiction and the suite red.

### DP-9 — the goal-loop mirror is additive, with two new reserved sentinel ids

`skills/goal/SKILL.md` cannot concatenate a raw `conformant`/`schema`/`usage`
word into its no-progress signature: `bin/goal-state.sh`'s normalisation
recognises only `PASS`/`FAIL`/`APPROVE`/`REQUEST_CHANGES`/`AC[0-9]+`, so the raw
word is silently dropped and two ticks with different outcomes collapse onto one
signature. The established answer in that file is a translation into reserved
sentinel AC ids, and it is mechanically identical here: `AC900005` for `schema`,
`AC900006` for `usage`/`structural`, `check-interventions: PASS` for
`conformant`. `bin/goal-state.sh` is not touched, which is the whole point of the
sentinel approach.

Measured before choosing the numbers: the reserved ids in use in that file today
are exactly `AC900001`–`AC900004`, so the two new ones are free. AC23 pins the
set at six in both directions and **measures** the resulting signatures rather
than asserting distinctness, because a sentinel that collides with an existing
gate's signature would reintroduce the false-`STOP:no_progress` defect this
mechanism exists to avoid. Two sites change, not one: the translation bullet and
the `SIG` template line inside the fenced Bound-gate block — the prose and the
code block are a canonical pair, and fixing one without the other is the recorded
way this class of edit goes wrong.

## Mirroring symmetry audit

The provenance discipline exists in more places than the run skill. Every site is
dispositioned; nothing is silently omitted.

| Site | What it carries for provenance | Disposition here | Reason |
|---|---|---|---|
| `skills/run/SKILL.md` | the T-075 gate paragraph | **mirrored-now** (AC18, AC19) | the gate's home, and the orchestrator's own instructions — the producer lives here |
| `agents/qa-verifier.md` | a mandatory verification item | **mirrored-now** (AC22) | cheap, and it is the second reader that keeps an orchestrator-written record from being self-attestation (DP-3) |
| `skills/goal/SKILL.md` | 17 sites incl. reserved sentinel ids `AC900003`/`AC900004` | **mirrored-now**, additively (AC23) | the autonomous loop has the same seam and the same producer; the mirror is not copy-paste — it needs its own reserved ids, which is why DP-9 measures distinctness rather than assuming it |
| `agents/engineer.md` | the T-074 producer discipline | **n-a**, and locked byte-unchanged (AC26) | producer asymmetry: interventions arrive in the main conversation, which a sub-agent never sees. An obligation here would produce invented entries or none |
| `agents/codex-reviewer.md` | reads provenance as receiving-side canon | **n-a** | its canon is the task's *design* record — frozen intent plus decisions the diff must be consistent with. Interventions record coordination events, not design decisions, so the read would enlarge an evaluator's input with no stated use. If a later task finds one, that is a change to this disposition, not a gap |
| `agents/drift-evaluator.md` | ~20 sites, advisory-only | **n-a** | the S4 advisory pass judges the delivered diff against frozen intent and the grounding of decisions; an intervention is not grounding for a decision, and this pass gates nothing |
| `bin/team-paths.sh` | the `provenance` resolver key | **mirrored-now** (AC14, AC15) | a synthesised `base + /interventions` would put the directory's name in two places |
| `bin/team-init.sh` | scaffolds `provenance/.gitkeep` | **mirrored-now** (AC16) | the directory must exist in an adopter's tree, git-tracked |
| `bin/retro-inputs.sh`, `bin/check-retro.sh`, `templates/prompt-blocks/retro-inputs.md`, `agents/scrum-master.md`, `docs/templates/retro-template.md` | the eight-input retro ledger | **n-a here — T-1003** | deliberate sequencing, not an omission: T-1001's AC2 pins the promotion sites at exactly eight, and this task's directory shape was chosen so T-1003 reuses `report_dir_input` with zero new promotion sites |
| `tests/codex-skeleton-hygiene/run.sh` | two ZERO-match live-file locks naming `check-provenance.sh` | **mirrored-now** (AC21, DP-8) | the hardcoded script name is the blind spot; extending it is what stops a closed class reappearing through a new name |
| `.github/workflows/check-handoff.yml` | shellcheck arg, suite step, dogfood | **mirrored-now** (AC24) | a lock CI does not run is a lock that is not wired |
| `.shell-team/test-recipe.md` | per-suite procedure notes | **mirrored-now** (AC24) | the append-only convention this repository already follows |
| `docs/adopting.md`, `docs/distribution.md`, `skills/team-init/SKILL.md`, `README.md` + `*.ja.md` mirrors | layout enumerations | **n-a — decided, not overlooked** | none of them lists `provenance/` either, so they are not mandatory surface (T-1001 precedent). Six documents for one line each widens the diff without a mechanical gain; a separate consistency issue may be filed |
| `bin/check-pii-shapes.sh` | change-scoped scan over committed content | **n-a — already covers it** | it is path-agnostic and already runs on the pull-request diff, so the new directory is scanned with no change. This is the mechanical backstop for the summary-not-transcript discipline (DP-1) |
| `bin/close-out.sh` | no provenance-directory awareness | **n-a** | nothing to mirror |

## What this mechanism does not deliver

Said plainly, because this repository has a recorded history of criteria that
claim more than their mechanism supports.

**The gate proves existence and grammar. It cannot prove completeness.** A task
whose orchestrator recorded three of its eight interventions passes exactly like
one that recorded all eight, and a file carrying the sentinel while ten
interventions happened is `conformant`. This is the same trust boundary
`bin/check-provenance.sh` declares, and it is the reason the sentinel exists at
all: without it the gate would be pressure to fabricate, which is worse than an
honest gap.

**It cannot prove an entry was written at the moment.** An entry reconstructed at
the end of a task is byte-indistinguishable from one written mid-interruption. In
the shipped default the at-the-moment property rests entirely on the standing
instruction in `skills/run/SKILL.md` (AC19); the mechanical prompt that would
make it structural is the opt-in sample hook belonging to T-1004, and it is
opt-in because a public repository is the wrong place for executable
configuration to arrive by default. Anyone reading AC18 as proof of timeliness is
reading more than it says.

**The class enum records what the producer believed.** A misclassified entry — a
correction recorded as an interrupt — is conformant, and `unclassified` may
absorb entries that would have fitted a named class. The mechanism buys a
searchable record with a known vocabulary, not a correct one.

**Nothing consumes the record in this task.** Its value is realised when T-1003
makes the directory a retro input; until then this task delivers a channel and a
gate, and no criterion here claims a retro improvement.

## Measured tree facts

Every claim below was read out of the tree by pm-spec, which has no shell in this
role: these are file reads, not command runs. Anything that needs execution is
marked in `## Assumptions`.

| Claim | Where it was measured |
|---|---|
| `bin/team-paths.sh` has eight sites per key: header derived-paths list, header usage comment, `print_help` KEY line, the assignment block, the `--export` printf, the `--get` case arm, the unknown-key `die` enum, and the `--print` row | lines 23, 35, 64, 159, 172, 183, 184, 196 |
| `--print`'s columns are hand-padded to `provenance`'s ten characters | the `printf '  provenance %s\n'` row |
| No suite pins `--print`'s spacing — only the rule line it reports | `tests/team-paths/run.sh` lines 134-144 |
| `tests/team-paths/run.sh` asserts per-key paths and has **no** total-key assertion, so a key missing from its list fails nothing | its default and legacy blocks, lines 37-57 |
| `bin/team-init.sh` has two sites: the `--help` scaffold list and the `ensure_gitkeep` call | its `print_help` list and line 230 |
| `tests/team-init/run.sh` asserts the scaffolded paths in one `for f in …` list | lines 45-55 |
| The reserved sentinel AC ids in use in `skills/goal/SKILL.md` are exactly `AC900001`–`AC900004`; `AC900005`/`AC900006` are unused anywhere in the tree | repository-wide search for `AC9000[0-9][0-9]` |
| `skills/goal/SKILL.md` names the translated gates in two coupled places: the `SIG` template inside the fenced Bound-gate block and the per-gate translation bullets | lines 107 and 172-193 |
| The live-file locks' regexes hardcode `bin/check-provenance\.sh` and `provenance[-[:space:]]+gate:AC[0-9]`; the frozen T-077 literals hardcode the same | `tests/codex-skeleton-hygiene/run.sh` lines 1323-1329 |
| Those locks scan `agents/qa-verifier.md`, `skills/run/SKILL.md`, `skills/goal/SKILL.md` (broken-invocation) and `skills/run/SKILL.md` (stateful-trace), and fail closed on grep rc>=2 | lines 1412-1449 |
| `bin/check-provenance.sh` is 359 lines; its suite enumerates fourteen case classes `(i)`–`(xiv)` and builds every fixture inline under an explicit `mktemp` template | both files' headers |
| The T-075 provenance-gate paragraph is a single physical line in `skills/run/SKILL.md` step 4 | line 48 |
| `bin/check-prompt-sync.sh` walks the registry only — an unregistered block file is invisible to it | lines 136-154, and the registry's own "Scope limits" note |
| `docs/tuning-oversight.md` carries the sentence `**This project ships no hooks.**` | line 100 |
| `bin/check-pii-shapes.sh` is change-scoped over committed blob content and path-agnostic, and CI runs it on the pull-request diff | its header; `.github/workflows/check-handoff.yml` lines 160-161 |
| No file under `bin/`, `skills/`, `agents/`, `tests/` or `templates/` contains the token `intervention` in any case — the name is free | repository-wide case-insensitive search (only `.shell-team/todo.md` and T-1001's spec mention it, in prose) |
| The board's `## Active` section is empty; T-1001 sits under `## Done` | `.shell-team/todo.md` |

## Body-to-AC correspondence

| Body directive | Where |
|---|---|
| One append-only file per task under `<base>/interventions/` | AC25, AC27 |
| The directory is resolved through a new `interventions` resolver key | AC14, AC25 |
| The key works in every resolver mode, and the unknown-key message names it | AC14 |
| The resolver's key set stays pinned in both directions, and its suite carries that pin | AC15 |
| `team-init.sh` scaffolds the directory in an adopter's tree | AC16 |
| The directory is git-tracked, never ignored | AC16 |
| The `--print` table is re-padded rather than left overrunning (DP-6) | AC14 |
| Taskless work has one well-known filename, `no-task.md`, with `no-task` a reserved marker id (DP-2) | AC6 |
| The class enum is a closed, English, seven-member set covering triggers 1/3/5 | AC2 |
| An eighth class token is rejected; the count is pinned in both directions | AC2 |
| Each entry is class + date + summary + effect, every field required and non-empty | AC3 |
| Field order is not enforced | AC3 |
| `effect:` states "nothing changed" in words rather than by being empty | AC3 |
| Every field is matched anchored at line start | AC4 |
| An entry is a summary, never a transcript | AC3 (the field names and one-line rule), AC10; PII backstop **info-only** below |
| A zero-entry sentinel exists and carries the same honesty role as the sibling's | AC5 |
| The sentinel and an entry can never coexist, in either order | AC5 |
| A region with neither the sentinel nor an entry is a violation | AC5 |
| Markers are matched by exact full-line comparison; the id comes from BEGIN's own capture | AC6, AC8 |
| Absent / duplicated / reversed / mismatched markers are `structural` | AC6 |
| `--task` disagreement is `structural`, and the gate passes the flag (DP-4) | AC7, AC18 |
| A file quoting its own grammar is still conformant | AC8 |
| A tolerance claim is proved against malformed input | AC9 |
| One physical line per field; a wrapped value is a violation | AC10 |
| Blank lines are ignored everywhere in the region | AC10 |
| The date is validated for format only, and the checker says so (DP-5) | AC11 |
| Four outcomes: `conformant` 0, `schema` 1, `structural` 2, `usage` 2 | AC1, AC2, AC3, AC5, AC6, AC7 |
| Every rejection prints a classification token to stderr | AC1, AC7 |
| Pure bash, zero-dependency, shellcheck-clean, writes nothing | AC12 |
| The fixture suite covers sixteen case classes, pinned in both directions, all passing | AC13 |
| The gate is unconditional, at the Implement→Validate seam, alongside the T-075 paragraph | AC18 |
| The gate is fail-closed: Validate does not start, nothing is auto-retried, the human is escalated to with the classification line quoted | AC18 |
| The gate resolves its own path and adds no new hardcoded path literal | AC18 |
| The producer is the orchestrator, stated wherever the gate is (DP-3) | AC18, AC22, AC23 |
| The engineer gains no interventions obligation | AC26 |
| Trigger 1 is appended at that moment, before acting on the message | AC19 |
| A routine gate response is not an intervention | AC17 (canonical line), AC19 |
| Triggers 3 and 5 are self-checked at the existing checkpoints | AC19 |
| Every invocation instruction is bare-name-first, with `bin/…` only as the fallback | AC20 |
| The coercive-invocation live-file lock is extended to the new checker | AC21 |
| The extension is proved to widen the lock, and cannot be quietly reverted (DP-8) | AC21 |
| QA verifies the record as a mandatory, non-exemptible item, judging structure only | AC22 |
| The goal loop mirrors the gate additively, with two new reserved sentinel ids (DP-9) | AC23 |
| `bin/goal-state.sh` is not modified | AC23 |
| Signature distinctness is measured, not asserted | AC23 |
| The class enum lives in exactly one file, verified by `check-prompt-sync` (DP-7) | AC17 |
| CI runs the suite and dogfoods the checker non-vacuously | AC24 |
| The new suite's procedure is recorded in the test recipe | AC24 |
| The mechanism is dogfooded by this task's own records | AC25 |
| No hook ships and `docs/tuning-oversight.md` is untouched | AC26 |
| The change stays inside its declared surface | AC27 |
| Nothing that already worked stops working | AC28 |
| The retro ledger's ninth input is T-1003, and T-1001's eight-site pin stays untouched | **info-only (not promoted to AC)** — a Non-goal about a *future* task; the mechanically held part is AC27's allow-list, which excludes every retro-ledger file, and T-1001's own criteria remain the pin |
| The opt-in sample hook and the tuning-oversight qualification are T-1004 | AC26 (the posture half is checked); the sequencing half is **info-only** — an absence no grep distinguishes from "not yet written" |
| Triggers 2 and 4 already have channels | **info-only (not promoted to AC)** — a statement about the existing tree, not a deliverable; T-1001's criteria already hold both |
| Past interventions are not reconstructed | **info-only (not promoted to AC)** — an absence; AC27's allow-list is the mechanically held part (no file outside this task's surface is created) |
| The layout-enumeration documents are deliberately not touched | AC27 (the allow-list excludes all six), reason **info-only** |
| The gate cannot prove completeness or at-the-moment authorship | **info-only (not promoted to AC)** — a statement of what is *not* claimed; promoting it would need a criterion asserting the absence of an assertion. Enforcement is that no AC claims more, which this table makes auditable |
| The class enum records what the producer believed, not what was true | **info-only (not promoted to AC)** — bounds how AC2 may be read; not machine-decidable |
| `unclassified` carries a named degradation risk, and noticing its growth is the retro's job | **info-only (not promoted to AC)** — a count would be the wrong instrument, since a high share can be legitimate information (DP-1) |
| Nothing consumes the record in this task | **info-only (not promoted to AC)** — the absence of a consumer; AC27's allow-list is what holds it |
| `bin/check-pii-shapes.sh` is the mechanical backstop for the transcript discipline | **info-only (not promoted to AC)** — pre-existing, unchanged behaviour; re-asserting a CI-enforced property adds a verification pass without adding protection |
| One class per distinguishable decision the retro would act on differently | **info-only (not promoted to AC)** — the rule that generated the enum, recorded so a later class is added by argument rather than accretion; it constrains authorship, not the deliverable |

## Assumptions

- **pm-spec has no shell in this role, so no `check:` line below was executed.**
  Every one is written against files pm-spec read directly, but the orchestrator
  must run all 28 live before the intent-hash is frozen — the recorded division
  of labour — and correct, meaning-preserving, any line that is broken as a
  command or that would pass vacuously. Two shapes to check first: the inline
  `mk()` helper definitions inside AC3/AC4/AC5/AC11 (a function defined and used
  inside a single `bash -c` string), and whether `printf` in those criteria
  expands the `\n` sequences as intended when the body is passed through a
  variable.
- **`shellcheck` is installed locally at the version CI pins** (0.11.0 at the
  time of writing). AC12 invokes it unconditionally on purpose, so a missing
  shellcheck fails the criterion loudly rather than passing it vacuously.
- **`develop` exists as a local branch in the checkout where the criteria run.**
  AC23, AC26 and AC27 read it directly. In a CI checkout it may exist only as a
  remote-tracking ref; these criteria are for local and QA use, and CI does not
  evaluate this spec.
- **`templates/shell-team.gitignore` is the shipped `<base>/.gitignore` template**
  (read directly: `bin/team-init.sh:131` sets `GITIGNORE_TPL` to it, and the file
  ignores `runs/` plus `reviews/.codex-capture.*`). AC16 asserts against both it
  and this repository's own `.shell-team/.gitignore`.
- **This spec contains the literal tokens `FAIL AC900005` / `AC900006`.** So does
  `skills/goal/SKILL.md`'s own spec history, and the goal skill already forbids
  concatenating raw `check-acs` stdout into a signature for exactly this reason —
  a `check:` line's text reproduced into a signature would inject the tokens
  regardless of outcome. Nothing here changes that rule; it is noted so nobody
  rediscovers it as a defect.
- **The ten-interventions figure from issue #37's session is taken on trust.** It
  sizes reachable input class 1 and nothing depends on it being exact.
- **`no-task.md` will be rare in this repository.** Nothing in the criteria
  depends on it existing; AC6 proves the reserved id is accepted using a
  throwaway fixture, not a committed file.

## Open questions

None blocking. Six things were decided rather than asked, each with its reasoning
recorded above: the entry grammar and the seven-member enum (DP-1), the taskless
filename and its reserved id (DP-2), the producer asymmetry and its consequences
(DP-3), the optional `--task` flag (DP-4), format-only date validation (DP-5),
and mirroring into `skills/goal/SKILL.md` now rather than deferring it (DP-9 —
judged specifiable because the reserved-id translation is purely additive and
`bin/goal-state.sh` is not touched).

## Notes for engineer

**What to read before writing anything.** `bin/check-provenance.sh` end to end —
this checker is its sibling and should be recognisably so: the same `die` /
`fail_usage` / `fail_structural` / `fail_schema` helpers defined before anything
else, the same symlink-resolving bootstrap with every external command guarded,
the same "load the file into a 1-indexed array with a per-line CR strip", the
same exact-full-line marker compare, and the same `finalize_entry` shape for
closing an entry's scope. `tests/check-provenance/run.sh` for the suite idiom
(fixtures built inline per case under an explicit `mktemp` template, both rc and
the stderr classification token asserted, the three-invocation-form comparison).
`bin/check-design-note.sh` for the `--task` flag's precedent.
`.shell-team/test-recipe.md` before running anything: a nested `git init` under
this repository's tree is sandbox-denied, so fixtures live under `$TMPDIR`.

**Order that keeps each step verifiable.** The resolver key and the scaffold
first (AC14–AC16 are runnable immediately). Then the canonical block and its
registry row, then the checker, then the suite, then the four agent-facing
surfaces (`skills/run/SKILL.md`, `skills/goal/SKILL.md`,
`agents/qa-verifier.md`), then the lock extension, then CI and the test recipe.
Write this task's own `<base>/interventions/T-1002.md` last — it is the dogfood
in AC25, and by then the checker exists to validate it. It may legitimately carry
the sentinel or real entries, whichever is true.

**Traps this task's own surface contains.**

- Your new prose must not itself match the locks you are extending: no
  interpreter-prefixed `bin/check-interventions.sh` anywhere in
  `skills/run/SKILL.md`, `skills/goal/SKILL.md` or `agents/qa-verifier.md`
  (AC20), and no `interventions gate:AC<digit>` sentinel string in them either.
  Run the extended suite against the live files before hand-off, not after.
- The canonical block's prose line is checked into **both** consumers by
  `contain` mode, including `bin/check-interventions.sh` — put it in the script's
  header comment verbatim, em dash included.
- AC18 extracts a **single line** from `skills/run/SKILL.md` and forbids a
  `tasks/` or `.shell-team/` literal on it. Step 4's paragraphs are one physical
  line each in that file; keep yours that way, and resolve the path through
  `team-paths.sh --get interventions` rather than naming a directory.
- Two coupled sites in `skills/goal/SKILL.md` (DP-9): the translation bullet and
  the `SIG` template line inside the fenced block. Editing one is the recorded
  way this class of change goes wrong.
- Do not touch `bin/goal-state.sh`, `agents/engineer.md`,
  `docs/tuning-oversight.md`, or anything in the retro-ledger set — AC23, AC26
  and AC27 each assert one of those absences.

**Before you hand off, mutate every new lock and watch it fail.** Delete one
class token from the canonical block and confirm AC2 and `check-prompt-sync` both
go red. Loosen the date regex to accept `2026-7-30` and confirm AC11 goes red.
Remove the entry-scope finalisation and confirm the missing-field case in AC3
goes red. Revert the two regex extensions in
`tests/codex-skeleton-hygiene/run.sh` and confirm its own new mutation and
oldmiss cases go red. Drop the `found` counter from the CI dogfood step and
confirm AC24 goes red. Then interrogate your **detector's** blind spots, not just
the subject's: does your region walk see only the first line of a wrapped value;
does it distinguish an indented `- intervention:` from a top-level one; does it
fail closed when the markers are absent rather than skipping silently; does the
`--task` comparison happen before or after the BEGIN/END agreement check. Write
one mutation of your own that targets whichever answer you are least sure of. A
lock you have not seen fail is a lock you have not tested.
