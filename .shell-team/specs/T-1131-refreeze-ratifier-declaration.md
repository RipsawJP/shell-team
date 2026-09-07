# An operator-authored spec declares who ratifies its class-B re-freeze, in a board sub-bullet the pre-freeze gate validates when present

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1131

## Problem

A `drift-detected` result at freeze routes to a *human-ratified* re-freeze. For an
`entry-mode: operator-authored` spec, nothing on the spec or the board says **which**
human that is — the operator in person, or an authoring session acting for them in a
hub-and-spoke run — so the run session invents the procedure at fire time.

The requester's canon is GitHub issue #459, reproduced verbatim below. It was
**relayed into this role in the task brief**, not opened by it.

> ## Problem
> A `drift-detected` result at freeze escalates to pm-spec for a *human-ratified* re-freeze (`skills/run/SKILL.md` ~line 60, `docs/tuning-oversight.md`). For `entry-mode: operator-authored` specs nothing on the spec or board says **who** that human is — the operator in person, or an authoring session acting for them in a hub-and-spoke run.
> Measured in the sprint `b-first-run` retro (`.shell-team/retros/2026-09-07-b-first-run.md`, Problem 5 / Try 4): the run session decided on its own that the operator had to type into *that* session, negotiated the procedure with the authoring session, and drew two operator corrections plus one blocking question.
> ## Proposal
> 1. **Spec template / pm-spec producer duty**: when `entry-mode` is `operator-authored`, the freeze writes one line, for example on the board entry next to `- entry-mode:`:
>    ```
>    - refreeze-ratifier: operator | authoring-session:<label>
>    ```
>    `pm-authored` specs do not carry the line (the ratifier is the operator by construction).
> 2. **`bin/check-entry-mode.sh`**: validate-if-present, the same shape as the `- dispatch:` family — value outside the closed set fails; an `operator-authored` entry without the line is a warning at first (forward-only), promoted to a failure after one sprint of measurement.
> 3. **Run skill**: the class-B re-freeze escalation reads the ratifier from that line and addresses it there, instead of inventing a procedure at fire time.
> The corpus already carries the prose half as an `Extended by` on the 2026-08-13 disposition-owner entry (PR #457); this issue is the mechanism half.
> ## Origin
> Sprint `b-first-run` retro, lesson candidate 5 — ruled "extend existing entry + file the template/checker change" (2026-09-07). Planning candidate A-2, operator-ranked third among the three v3-ma frictions.

Two of the issue's own proposals are **superseded** by decisions taken before this
spec was written, and both supersessions are stated in the frozen region with their
grounds: the `authoring-session:<label>` suffix is dropped, and the "warning first,
failure after one sprint" tier is dropped.

## Summarized sources

- **GitHub issue #459 — RELAYED verbatim into this role in the task brief, not opened by it.** Distinctions carried over exactly as the relay draws them: the gap is *who* the human ratifier is for an `operator-authored` spec's class-B re-freeze; the record is **one line on the board entry next to `- entry-mode:`**; a `pm-authored` spec carries no line because the ratifier is the operator by construction; the checker arm is **validate-if-present, the same shape as the `- dispatch:` family**; and the run skill **reads the ratifier from that line instead of inventing a procedure at fire time**. Two of its clauses are carried over *as superseded*, named so in the frozen region rather than silently dropped: the `authoring-session:<label>` suffix, and the warning-then-promotion tier.
- **`.shell-team/retros/2026-09-07-b-first-run.md`:94–98 (Problem) and :122–125 (Try) — read first-hand.** Distinction carried over, and it qualifies the issue's framing: the Problem entry is itself prefixed `（relayed）` and cites a v3-ma retro-input file outside this repository as its source, so this repository holds a **relayed record** of the incident rather than a first-hand measurement of it. Its measured wording: the class-B re-freeze ratifier for an `operator-authored` spec was not declared at freeze, the run session decided the procedure itself and negotiated it with the authoring session, and this drew **two operator corrections** (`:97`). The Try entry (`:122`–`:125`) proposes exactly a one-line declaration at freeze, and prices it as "凍結時の1行" read only when a class-B re-freeze actually fires.
- **`bin/check-entry-mode.sh` — read first-hand, end to end (529 lines).** Distinctions carried over: its usage surface is `--board PATH --task T-NNN` and nothing else (`:71`–`:83`); exit 0 = conformant, 1 = a refusal about the entry's content, 2 = a usage or environment error; the entry extent is located by one `awk` scan over `## Active` only (`:113`–`:129`), and a trailing CR is stripped per line before any field is read (`:136`); `EM_VALUE` is already parsed and closed to the pair `pm-authored`/`operator-authored` (`:174`–`:178`); the `- dispatch-reflection:` family (`:282`–`:527`) is the shipped precedent for a **validate-if-present** family arm, gated on `REFL_ROW_COUNT -gt 0` so an entry carrying none of those sub-bullets still passes; and the recurring defect class this script has been repaired for twice is **collect wide, parse strict** — the stem net tolerates extra whitespace after the bullet dash (`:239`–`:242`) and, after Codex round 1 Major 4, on both sides of the colon (`:298`–`:309`), while the full grammar stays strict, so a malformed line is collected and refused rather than read as the conformant absent case.
- **`tests/check-entry-mode/run.sh` — read first-hand, end to end (554 lines).** Distinctions carried over: `SCRIPT` is `$REPO_ROOT/bin/check-entry-mode.sh` derived from the suite's own location, so the suite runs whichever checker sits beside it; scratch boards are built **inline** by the `bd`/`mk`/`mk_pair`/`refl_board` helpers under a `$TMPDIR`-backed root, and the suite carries **no `fixtures/` directory at all**; `pass` prints `PASS: <desc>` and `fail` prints `FAIL: <desc>` to stderr and exits 1; the closing line is `All check-entry-mode assertions passed.` (not a bare `OK`, unlike the loop-guard suite); and `local -a` is used at `:361` while `mapfile`/`readarray`/`declare -A`/`coproc` occur zero times in either file (measured).
- **`skills/run/SKILL.md`:40–69 — read first-hand.** Distinctions carried over: the class-B escalation is the `drift-detected` bullet at `:60` ("do not record or overwrite; stop and escalate to `pm-spec` for a human-ratified re-freeze (vK→vK+1)"), and the **same branch is reachable from `:50`**, whose `attestation` paragraph ends by routing `drift-detected` to that bullet — two sites, one rule; `:45` is the T-1096 board-transcription paragraph naming the fixed window and the `check-entry-mode.sh` invocation; `:53` is the Conformance-read confirmation gate; and `rework-digest.sh` is a pre-existing token in this file, usable as a read-happened positive control.
- **`skills/goal/SKILL.md`:150–180 — read first-hand at its `drift-detected` handling.** Distinction carried over, and it is the measurement grounding this task's Non-goal: the goal skill's only `drift-detected` handling is **signature translation** — `:169` names the branch and `:175` records that its signature is `AC900002`, distinct from `structural`'s `AC900001` — and it carries **no class-B re-freeze escalation branch** to extend. It is therefore out of scope by measurement rather than by preference.
- **`docs/tuning-oversight.md`:105–139 — read first-hand.** Distinctions carried over: `:107` is the sentence this task must not leave standing unqualified — "A frozen intent block is the record the loop is judged against, so by default it never moves without a per-instance human GO — whatever changed" (whole-line count of that fragment in the repository at authoring time: **1**, measured); `:109` draws the class-B / class-M split and states that class-B "always needs your GO, because the frozen intent is a record of your own decisions"; `:132` documents the `- refreeze-class` board sub-bullet; and `:136`–`:138` is this document's own idiom for disclosing what a mechanism does **not** prove, including that nothing "opens a channel or verifies an identity" for the party named — the ground on which the `<label>` suffix is superseded below.
- **`docs/tuning-oversight.ja.md`:91–125 — read first-hand.** Distinctions carried over: the mirror section is `## 凍結された intent block を誰が再凍結してよいか` (`:91`), it embeds the identical English fenced grant block verbatim (`:99`–`:116`) rather than translating it, and it carries bracketed English machine tokens inline — the shape the new Japanese prose follows. Its own next section is `## ループの延長を誰が裁定してよいか` (`:126`), T-1130's mirror.
- **`agents/pm-spec.md`:112–129 — read first-hand.** Distinctions carried over: `:119` is the conformance-formatter hand-off grammar; `:123` is the T-1096 board-transcription paragraph, which fixes the window ("immediately after the entry exists and **before the freeze sweep** runs") and already uses the verb `transcribes`; `:125` extends that same window to the `- flagged-gap:` family and states the author/flagger split ("you flag, the author resolves") — the precedent this task's producer duty follows; and `:129` is the disclosed-enforcement paragraph naming what `bin/check-entry-mode.sh` does and does not verify.
- **`bin/check-prompt-sync.sh`:1–34 — read first-hand at its header contract.** Distinction carried over precisely, because this spec uses its exit code as a negative control and the two are not the same claim: exit 0 means every consumer registered in `templates/prompt-blocks/registry.txt` still carries its canonical block (byte-equal inside a `marker` pair, or every canonical line present as a fixed substring in `contain` mode); exit 1 is drift, exit 2 a usage or configuration error. It is **check-only and never rewrites a consumer**. What a 0 therefore does *not* establish is that no canonical block file was edited — an edit propagated to both sides still reports in sync — which is why **AC5** records it as a partial control rather than as proof.
- **`.shell-team/specs/T-1130-stop-extension-ratifier.md` — read first-hand, end to end.** Distinctions carried over: `budget.extension_ratifier` is closed to exactly the two words `operator` and `authoring-session` with **no label suffix**, `authoring-session` takes effect only for an entry carrying `- entry-mode: operator-authored`, and the fallback anchor phrase shipped on both skill surfaces is the fixed string `falls back to the operator with the reason stated`. This spec reuses that vocabulary and that anchor phrase deliberately, so the two ratifier surfaces carry one vocabulary rather than two.
- **`.shell-team/todo.md`:4307–4328 (T-1130's first `## Done` entry) — read first-hand.** Distinctions carried over: the entry line's shape, and the sub-bullet grammar for `- entry-mode:`, `- spec-review:`, `- dispatch:` and `- dispatch-reflection:`. Also carried over as a **negative** finding: no board entry carries a `- refreeze-ratifier:` sub-bullet today (measured: zero occurrences of the token anywhere in the repository), so the record shape this spec names is **new** and nothing satisfies its criteria by inheritance.

## Goal

<!-- BEGIN intent-block: T-1131 -->

- user-visible: yes — this task edits two adopter-facing oversight documents that answer "who may re-freeze a frozen intent block", changing the answer they give for an `operator-authored` spec, and it changes the escalation message an adopter reads when `drift-detected` fires. The capability is reachable only by an adopter who writes the new sub-bullet on their own board, which is why the release-tier premise on record is PATCH rather than MINOR; latency is not invisibility, so the adopter-facing-documentation obligation applies and is discharged by **AC6**.
- verification-class: mechanism — this task's diff reaches `bin/check-entry-mode.sh` and `tests/check-entry-mode/run.sh`, both executing surfaces whose semantics change, so every item of the freeze-time protocol applies as written.
- verification-ceiling: unit-and-static — every criterion runs the shipped checker, the shipped suite, `shellcheck`, or a fixed-string read against this checkout; none needs a real adopter environment or a real hub-and-spoke run, and none is marked `- above-ceiling:`. Non-vacuity holds: seven criteria sit at the declared ceiling.
- base-ref-discriminator: `git merge-base "feature/458-stop-extension-ratifier" HEAD` — the local-branch arm, selected by the explicit existence test `git show-ref --verify --quiet refs/heads/feature/458-stop-extension-ratifier`, which this checkout satisfies; where a checkout carries the predecessor only as a remote-tracking ref the arm is `git merge-base "refs/remotes/origin/feature/458-stop-extension-ratifier" HEAD`, naming that full ref path rather than the bare name, and the era-change fallback once the predecessor resolves in **neither** namespace is `git merge-base "develop" HEAD`, `develop` being this repository's integration branch. The two-arm expression is the conformant form rather than `not-applicable` because both halves of the conjunction hold: **AC1** reads base-side blobs (the branch point's `bin/check-entry-mode.sh` and `tests/check-entry-mode/`), and this branch is stacked behind an open predecessor PR (#460, branch `feature/458-stop-extension-ratifier`) at authoring time. `develop` alone would be wrong here, not merely different: it predates T-1130's edits, so a base-side read there would compare against a tree this branch was never cut from. No 40-hex literal is written into any criterion; every criterion resolves the ref live through that test.

A board sub-bullet, `- refreeze-ratifier:`, declares **who ratifies a class-B
re-freeze** for a spec whose entry carries `- entry-mode: operator-authored`. Its
vocabulary is closed to exactly two words, `operator` and `authoring-session` — the
same two words and the same meaning `budget.extension_ratifier` already carries, so
the two ratifier surfaces share one vocabulary. `authoring-session` names a distinct
party only when the spec's own author is not `pm-spec`.

**The issue's `authoring-session:<label>` suffix is superseded, and no label is
accepted.** Ground: a label would have no consumer — `docs/tuning-oversight.md`'s own
disclosure idiom states that nothing here opens a channel or verifies an identity, so
a label names a party no mechanism addresses; and T-1130 shipped this same vocabulary
closed to exactly these two words on the sibling escalation surface, so a second
ratifier vocabulary differing only by a label would be an unjustified divergence.

**`bin/check-entry-mode.sh` gains one family arm, strict validate-if-present.**
Present ⇒ the grammar and the vocabulary are enforced and any violation exits 1: a
value outside the closed pair, a duplicated line, a malformed spacing variant
(collected wide, parsed strict, as this script's two prior repairs already require),
and the line appearing on a `pm-authored` entry — the record disagreeing with itself,
the same class the script already refuses at its two-source mismatch. Absent ⇒ pass,
in both modes. **The issue's warning tier and its scheduled promotion to a failure are
superseded**: the consuming seam branches on the exit code alone, so a warning exiting
0 is a pass at the only place the verdict is read, and this repository requires a
checker to fail closed. Presence on an `operator-authored` entry is therefore a prose
producer duty on `pm-spec`, exactly as the `- dispatch:` family's presence is a duty
on the coordinating session — never a refusal by this script.

**`skills/run/SKILL.md`'s class-B escalation reads the line instead of inventing a
procedure.** On `- refreeze-ratifier: authoring-session` with an `operator-authored`
entry, the ratification request is addressed to the declared authoring session. On
`operator`, on an **absent** line, or on a `pm-authored` entry, it is addressed to the
operator and the message **names which of those three produced the fallback** — never
silently, reusing T-1130's shipped anchor phrase `falls back to the operator with the
reason stated`. The escalation also declares whose authority the declaration carries:
the line is written on an `operator-authored` entry by the authoring session
(`pm-spec` transcribing the author's declared value), so the message names its writer
rather than framing the operator as its author.

**`agents/pm-spec.md` carries the producer duty**: in `operator-authored` mode
`pm-spec` **transcribes** the value the author declared, in the same fixed window as
`- entry-mode:` and `- flagged-gap:`, and never chooses one itself. Absence is legal
and means `operator`, so an undeclared value is never a freeze blocker.

**Both adopter-facing oversight documents are extended, in both languages**, so their
`## Who may re-freeze a frozen intent block` sections stop implying that the human is
the operator in person. The shipped default sentence is **kept and qualified**, never
deleted: the default is still a per-instance human GO for every class-B delta, and
what the new prose adds is which human that GO is addressed to.

## Non-goals

- **No `<label>` suffix, no free-form session identifier, and no widening of the vocabulary.** Exactly two accepted words. A value carrying a colon and a label is a rejected value, not an extended one.
- **No warning tier and no scheduled promotion.** The arm has one behaviour from the day it ships: enforce when present, pass when absent.
- **No refusal for an absent line.** An `operator-authored` entry carrying no `- refreeze-ratifier:` sub-bullet passes; the duty to write it lives in prose, not in this exit code.
- **No edit to `skills/goal/SKILL.md`.** Measured, not assumed: its only `drift-detected` handling is signature translation into `AC900002` (`:169`, `:175`) and it carries no class-B re-freeze escalation branch to extend.
- **No edit to `templates/prompt-blocks/dispatch-record.md`.** `- refreeze-ratifier:` is not a dispatch axis; `bin/check-prompt-sync.sh` runs as the negative control, at exactly the width its own header states — a 0 exit means every registered consumer's block region still matches its canonical file, which is a partial control rather than a proof that no canonical block was edited.
- **No change to `bin/close-out.sh`, to the `- dispatch:` grammar, or to the `- dispatch-reflection:` family.** This task's diff touches none of them, and the new marker is a distinct string from both marker families, so the new arm is additive.
- **No delivery channel, no authentication, and no verification that the named ratifier actually ruled.** Nothing is sent anywhere, no identity is checked, and no session is addressed programmatically. These are re-disclosed residuals of the existing gate, not gaps this task closes.
- **Forward-only.** No existing board entry is retro-annotated with the new sub-bullet, and no already-frozen spec is re-opened.
- **No new checked-in fixtures.** The suite builds scratch boards inline through its existing `bd`/`mk` helpers under `$TMPDIR`; `tests/check-entry-mode/` gains no `fixtures/` directory.
- **No new checker, no new `bin/` script, no new test suite, and no CI change.**
- **No version bump and no CHANGELOG entry**, and no release-tier re-derivation in this spec — the sprint's release step owns those.

## Acceptance criteria

Every check runs from the repository root, asserts its inputs are readable before
judging, writes only inside a `mktemp -d` scratch directory built on the guarded
`${TMPDIR:-/tmp}` template, and carries a positive control wherever it counts or greps
for an absent condition. Where a base-side blob is read, it is read at the branch
point the `- base-ref-discriminator:` declaration fixes, never at a hex literal and
never from the working tree.

- [ ] **AC1** *(never-dropped)* The existing suite stays green and **no existing arm's
      verdict changes**, and an entry carrying no `- refreeze-ratifier:` line passes in
      both modes. Two arms are built under one scratch root: the base arm carries the
      branch point's `tests/check-entry-mode/` tree **and** the branch point's
      `bin/check-entry-mode.sh`; the head arm is this checkout. Both suites exit 0,
      print zero `^FAIL` lines, and end with the line `All check-entry-mode assertions
      passed.` Every `^PASS` line the base arm prints is asserted present **verbatim**
      in the head arm's output — which is what "unchanged in verdict" means here, and
      it additionally forbids rewording an existing arm's description — and the head
      arm's `^PASS` count is greater than or equal to the base arm's, measured as a
      base-relative comparison rather than against any literal. Positive control: the
      base arm's `^PASS` count is greater than zero, so an arm that produced nothing
      cannot satisfy the comparison vacuously. Negative control against the criterion's
      own vacuity: the two arms' `bin/check-entry-mode.sh` files are asserted **not**
      byte-identical, so an unedited checker fails here rather than passing by
      comparing a file to itself. Absent-line arm: a scratch board whose entry carries
      `- entry-mode: operator-authored` plus its agreeing `- dispatch: specify` row and
      **no** `- refreeze-ratifier:` line exits 0, and so does the same shape at
      `pm-authored`. No count in this criterion is a population count over a growing
      corpus — both are pinned to the branch point or derived at run time — so no
      `- stale-at:` trigger is attached. **Merge-point-scoped and expected to go stale
      after merge**: once this branch lands, the discriminator resolves to a commit
      already containing the edit, both arms become the same script, and the negative
      control correctly reddens. That is expected, is not a defect to chase, and this
      criterion is deliberately **not** merge-ranged.
  - check: rc=0; export LC_ALL=C; P=feature/458-stop-extension-ratifier; if git show-ref --verify --quiet "refs/heads/$P"; then B=$(git merge-base "$P" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$P"; then B=$(git merge-base "refs/remotes/origin/$P" HEAD); else B=$(git merge-base "develop" HEAD); fi; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a1.XXXXXX") || exit 1; mkdir -p "$T/base/bin" || exit 1; git archive "$B" tests/check-entry-mode | tar -x -C "$T/base" || exit 1; git show "$B:bin/check-entry-mode.sh" > "$T/base/bin/check-entry-mode.sh" || exit 1; test -s "$T/base/tests/check-entry-mode/run.sh" || exit 1; test -s "$T/base/bin/check-entry-mode.sh" || exit 1; ( cd "$T/base" && bash tests/check-entry-mode/run.sh ) > "$T/base.out" 2> "$T/base.err"; bs=$?; bash tests/check-entry-mode/run.sh > "$T/head.out" 2> "$T/head.err"; hs=$?; test "$bs" -eq 0 || rc=1; test "$hs" -eq 0 || rc=1; bp=$(grep -c '^PASS' "$T/base.out" || true); hp=$(grep -c '^PASS' "$T/head.out" || true); test "$bp" -gt 0 || rc=1; test "$hp" -ge "$bp" || rc=1; test "$(grep -c '^FAIL' "$T/base.out" || true)" = "0" || rc=1; test "$(grep -c '^FAIL' "$T/head.out" || true)" = "0" || rc=1; grep -qxF 'All check-entry-mode assertions passed.' "$T/base.out" || rc=1; grep -qxF 'All check-entry-mode assertions passed.' "$T/head.out" || rc=1; grep '^PASS' "$T/base.out" > "$T/bp"; while IFS= read -r l; do grep -qxF "$l" "$T/head.out" || rc=1; done < "$T/bp"; cmp -s "$T/base/bin/check-entry-mode.sh" bin/check-entry-mode.sh && rc=1; for m in operator-authored pm-authored; do printf '## Active\n\n- [ ] **T-902** fixture entry\n  - entry-mode: %s\n  - dispatch: specify — %s — unconditional — recommendation: r\n\n' "$m" "$m" > "$T/n.md"; bash bin/check-entry-mode.sh --board "$T/n.md" --task T-902 >/dev/null 2>&1 || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** *(never-dropped)* The arm fails closed on every violation, accepts both
      vocabulary words, and nothing on the live board was retro-annotated. Eight
      rejected board shapes are each built as a scratch board and each must exit
      **1**: the case variant `Operator`; the superseded label form
      `authoring-session:hub`; the near-miss `operators`; an empty value; the sub-bullet
      written twice on one entry; the doubled-space-after-dash spacing variant; the
      space-before-colon spacing variant; and a well-formed `operator` line sitting on a
      `pm-authored` entry. Both accepted shapes — `operator` and `authoring-session` on
      an `operator-authored` entry — must exit **0**. Construction control: each
      rejected board is asserted to contain the token `refreeze-ratifier`, so a failed
      insertion fails here rather than producing a refusal for an unrelated reason.
      Attribution control: the same base board **without** the line exits 0 in both
      modes, so each exit 1 above is attributable to the line rather than to the
      fixture. Enumeration control: the criterion asserts it ran all eight rejected
      shapes, so a truncated list fails rather than passing on a subset. Forward-only
      control, run against this repository's own live board: the board resolved through
      `bin/team-paths.sh --get todo` carries **zero** `- refreeze-ratifier:` sub-bullets
      (this task is `pm-authored` and writes none, and no existing entry is
      retro-annotated), with the pre-existing `- entry-mode:` sub-bullet asserted
      present as the read-happened positive control.
  - check: rc=0; export LC_ALL=C; test -s bin/check-entry-mode.sh || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a2.XXXXXX") || exit 1; set -- 'op:- refreeze-ratifier: Operator' 'op:- refreeze-ratifier: authoring-session:hub' 'op:- refreeze-ratifier: operators' 'op:- refreeze-ratifier: ' 'op:- refreeze-ratifier: operator@@- refreeze-ratifier: operator' 'op:-  refreeze-ratifier: operator' 'op:- refreeze-ratifier : operator' 'pm:- refreeze-ratifier: operator'; n=0; for spec in "$@"; do n=$((n+1)); tag=${spec%%:*}; body=${spec#*:}; if [ "$tag" = "pm" ]; then m=pm-authored; else m=operator-authored; fi; { printf '## Active\n\n- [ ] **T-904** fixture entry\n  - entry-mode: %s\n  - dispatch: specify — %s — unconditional — recommendation: r\n' "$m" "$m"; printf '%s\n' "$body" | tr '@' '\n' | grep -v '^$' | sed 's/^/  /'; printf '\n'; } > "$T/r$n.md"; grep -qF -- 'refreeze-ratifier' "$T/r$n.md" || rc=1; bash bin/check-entry-mode.sh --board "$T/r$n.md" --task T-904 >/dev/null 2>&1; s=$?; test "$s" -eq 1 || rc=1; done; test "$n" = "8" || rc=1; for v in operator authoring-session; do printf '## Active\n\n- [ ] **T-905** fixture entry\n  - entry-mode: operator-authored\n  - dispatch: specify — operator-authored — unconditional — recommendation: r\n  - refreeze-ratifier: %s\n\n' "$v" > "$T/a.md"; bash bin/check-entry-mode.sh --board "$T/a.md" --task T-905 >/dev/null 2>&1 || rc=1; done; for m in operator-authored pm-authored; do printf '## Active\n\n- [ ] **T-904** fixture entry\n  - entry-mode: %s\n  - dispatch: specify — %s — unconditional — recommendation: r\n\n' "$m" "$m" > "$T/c.md"; bash bin/check-entry-mode.sh --board "$T/c.md" --task T-904 >/dev/null 2>&1 || rc=1; done; BD=$(bash bin/team-paths.sh --get todo) || rc=1; test -s "$BD" || rc=1; grep -qF -- '- entry-mode:' "$BD" || rc=1; test "$(grep -cF -- '- refreeze-ratifier:' "$BD" || true)" = "0" || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: a future task legitimately writes a `- refreeze-ratifier:` sub-bullet onto this repository's own board for an `operator-authored` task, at which point the forward-only zero-count control no longer describes the board it reads and must be re-scoped to "no entry predating T-1131 carries the line".

- [ ] **AC3** The shipped suite covers both halves of the arm's contract, and no
      checked-in fixture was added. `bash tests/check-entry-mode/run.sh` exits 0, prints
      zero `^FAIL` lines, ends with the line `All check-entry-mode assertions passed.`,
      and carries a `^PASS` line matching `T-1131 ratifier-accepted` **and** one
      matching `T-1131 ratifier-rejected`. The directory `tests/check-entry-mode/
      fixtures` is asserted **not** to exist, so the Non-goal that new cases are built
      as inline scratch boards is observable rather than only stated. The arm-name stems
      `ratifier-accepted` / `ratifier-rejected` are borrowed vocabulary — T-1130 coined
      them in `tests/loop-guard/run.sh` — which is why both tokens are matched with
      their `T-1131` prefix, a string that occurs zero times in the repository at
      authoring time.
  - check: rc=0; export LC_ALL=C; S=tests/check-entry-mode/run.sh; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a3.XXXXXX") || exit 1; bash "$S" > "$T/o" 2>&1; s=$?; test "$s" -eq 0 || rc=1; test -s "$T/o" || rc=1; test "$(grep -c '^FAIL' "$T/o" || true)" = "0" || rc=1; grep -qxF 'All check-entry-mode assertions passed.' "$T/o" || rc=1; i=0; for t in 'T-1131 ratifier-accepted' 'T-1131 ratifier-rejected'; do i=$((i+1)); grep -q "^PASS.*$t" "$T/o" || rc=1; done; test "$i" = "2" || rc=1; test ! -d tests/check-entry-mode/fixtures || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** The run skill's class-B escalation carries the whole rule on one
      self-contained line, and the goal skill is untouched. `skills/run/SKILL.md` has at
      least one line carrying **all six** of: the sub-bullet name `refreeze-ratifier`;
      the branch it fires on, `drift-detected`; the second vocabulary word
      `authoring-session`; the board condition `operator-authored`; the fixed fallback
      anchor phrase `falls back to the operator with the reason stated`, reused verbatim
      from T-1130 so one anchor covers both ratifier surfaces; and the writer-authorship
      token `authoring-session-declared`, declaring that on an `operator-authored` entry
      this line is written by the authoring session through `pm-spec`'s transcription
      rather than by the operator. Read-happened positive control: the pre-existing
      token `rework-digest.sh` is asserted present in that file. Negative control for
      the Non-goal: `skills/goal/SKILL.md` contains **zero** occurrences of
      `refreeze-ratifier`, with its pre-existing `drift-detected` token asserted present
      so the zero-count is measured against a file that was actually read.
  - check: rc=0; export LC_ALL=C; F=skills/run/SKILL.md; G=skills/goal/SKILL.md; test -s "$F" || exit 1; test -s "$G" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a4.XXXXXX") || exit 1; grep -qF -- 'rework-digest.sh' "$F" || rc=1; grep -F -- 'refreeze-ratifier' "$F" | grep -F -- 'drift-detected' | grep -F -- 'authoring-session' | grep -F -- 'operator-authored' | grep -F -- 'falls back to the operator with the reason stated' | grep -F -- 'authoring-session-declared' > "$T/e"; test -s "$T/e" || rc=1; grep -qF -- 'drift-detected' "$G" || rc=1; test "$(grep -cF -- 'refreeze-ratifier' "$G" || true)" = "0" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** `agents/pm-spec.md` carries the producer duty, and no registered prompt
      block moved. That file has at least one line carrying all three of
      `refreeze-ratifier`, `operator-authored` and `transcribes` — the duty stated in
      one sentence, so no half of it can be read without the others — and
      `bash bin/check-prompt-sync.sh` exits 0, which is the negative control for the
      `templates/prompt-blocks/dispatch-record.md` Non-goal at exactly the width that
      script's own header states: a 0 exit means every registered consumer's block
      region still matches its canonical file. It is deliberately recorded as a partial
      control — an edit made to a canonical block *and* its consumers together would
      still report in sync — rather than as a proof that no prompt block moved.
      `transcribes` and `operator-authored` are borrowed
      vocabulary already present in this file; `refreeze-ratifier` occurs zero times in
      the repository at authoring time, so the required co-location cannot be satisfied
      by inherited text.
  - check: rc=0; export LC_ALL=C; A=agents/pm-spec.md; test -s "$A" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a5.XXXXXX") || exit 1; grep -F -- 'refreeze-ratifier' "$A" | grep -F -- 'operator-authored' | grep -F -- 'transcribes' > "$T/e"; test -s "$T/e" || rc=1; bash bin/check-prompt-sync.sh >/dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** Both adopter-facing oversight documents answer the new question inside
      their existing "who may re-freeze" section, each in its own file and its own
      language, and the shipped default sentence is kept rather than deleted.
      `docs/tuning-oversight.md` carries the whole line `## Who may re-freeze a frozen
      intent block` and `docs/tuning-oversight.ja.md` carries the whole line
      `## 凍結された intent block を誰が再凍結してよいか`; each section, extracted from
      its heading to the next `^## `, carries at least six non-empty lines and all four
      of the literals `refreeze-ratifier`, `operator`, `authoring-session` and
      `entry-mode`, so both languages share one machine-token set and cannot drift apart
      on it. The English section additionally still carries the shipped fragment `never
      moves without a per-instance human GO — whatever changed` — the default is
      unchanged and is not to be deleted — **and** the coined qualifier `which human
      that GO is addressed to`, so the sentence is qualified rather than left implying
      the operator in person. Positive controls: each heading is asserted present as a
      whole line before extraction, and the six-line floor makes a failed or empty
      extraction fail here rather than pass.
  - check: rc=0; export LC_ALL=C; A=docs/tuning-oversight.md; J=docs/tuning-oversight.ja.md; test -s "$A" || exit 1; test -s "$J" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a6.XXXXXX") || exit 1; grep -qxF -- '## Who may re-freeze a frozen intent block' "$A" || rc=1; grep -qxF -- '## 凍結された intent block を誰が再凍結してよいか' "$J" || rc=1; awk '/^## /{if(f)exit} /^## /&&!f{if($0=="## Who may re-freeze a frozen intent block"){f=1;next}} f{print}' "$A" > "$T/en"; awk '/^## /{if(f)exit} /^## /&&!f{if($0=="## 凍結された intent block を誰が再凍結してよいか"){f=1;next}} f{print}' "$J" > "$T/ja"; for s in "$T/en" "$T/ja"; do test "$(grep -c . "$s" || true)" -ge 6 || rc=1; for t in 'refreeze-ratifier' 'operator' 'authoring-session' 'entry-mode'; do grep -qF -- "$t" "$s" || rc=1; done; done; grep -qF -- 'never moves without a per-instance human GO — whatever changed' "$T/en" || rc=1; grep -qF -- 'which human that GO is addressed to' "$T/en" || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - adopter-surface: `docs/tuning-oversight.md`'s `## Who may re-freeze a frozen intent block` section and its `docs/tuning-oversight.ja.md` mirror `## 凍結された intent block を誰が再凍結してよいか` — landing in this same task rather than as a fast-follow, because those two sections are where an adopter goes to learn who may re-freeze, and leaving them unqualified would have them contradict the shipped behaviour.

- [ ] **AC7** The two edited executing surfaces keep this repository's `bin/` purity
      floor, and the checker's own header documents the new family. `shellcheck` exits 0
      on `bin/check-entry-mode.sh` and on `tests/check-entry-mode/run.sh`, and neither
      file contains a bash-4-only construct (`mapfile`, `readarray`, `declare -A`,
      `coproc`), so the bash 3.2 floor holds — all four occur zero times in both files
      at authoring time, so this locks a property rather than repairing one. The
      checker's leading comment header names `refreeze-ratifier`, so the file's own
      documentation matches its behaviour, with the pre-existing header phrase `Two
      condition sources` asserted present as the read-happened positive control.
      Positive control chosen so a missing tool cannot read as a clean lint:
      `shellcheck` is asserted present on `PATH` and its `--version` output asserted
      non-empty before either file is linted. The version the claim is trusted at is the
      pinned `0.11.0` recorded in `.shell-team/test-recipe.md` and
      `.github/workflows/check-handoff.yml`; the criterion does not hard-gate on the
      version string, because CI installs its own pinned copy regardless of the
      runner's, and a local run at a different version is disclosed in the hand-off
      rather than silently trusted.
  - check: rc=0; export LC_ALL=C; command -v shellcheck >/dev/null 2>&1 || rc=1; test -n "$(shellcheck --version 2>/dev/null)" || rc=1; shellcheck bin/check-entry-mode.sh >/dev/null 2>&1 || rc=1; shellcheck tests/check-entry-mode/run.sh >/dev/null 2>&1 || rc=1; for f in bin/check-entry-mode.sh tests/check-entry-mode/run.sh; do test -s "$f" || rc=1; test "$(grep -cE '(mapfile|readarray|declare -A|coproc)' "$f" || true)" = "0" || rc=1; done; T=$(mktemp -d "${TMPDIR:-/tmp}/t1131a7.XXXXXX") || exit 1; sed -n '1,140p' bin/check-entry-mode.sh | grep '^#' > "$T/h"; test -s "$T/h" || rc=1; grep -qF -- 'Two condition sources' "$T/h" || rc=1; grep -qF -- 'refreeze-ratifier' "$T/h" || rc=1; rm -rf "$T"; test "$rc" -eq 0

## Input space

**Reachable input classes** — what real board records, this repository's own board and
the shipped suite produce, all of which the implementation must handle correctly:

1. An entry carrying **no** `- refreeze-ratifier:` sub-bullet — every entry on every
   board in existence today, in both `pm-authored` and `operator-authored` mode. Must
   pass, unchanged from the branch point's verdict.
2. `- refreeze-ratifier: operator` on an `operator-authored` entry — the explicit
   default. Must pass.
3. `- refreeze-ratifier: authoring-session` on an `operator-authored` entry — the
   hub-and-spoke state. Must pass.
4. The line on a `pm-authored` entry — a record disagreeing with itself. Must refuse.
5. A value outside the closed pair: a case variant (`Operator`), a plural or prefix
   near-miss (`operators`, `author`), the superseded label form
   (`authoring-session:hub`), and an empty value. All must refuse.
6. The sub-bullet written more than once on one entry. Must refuse.
7. Whitespace variants this script's own history names as reachable: extra spaces
   after the bullet dash, and whitespace on either side of the colon. Each must be
   **collected** by the stem net and then **refused** against the strict full grammar
   — never rendered invisible, which would read as the conformant absent case.
8. A CRLF-terminated board. The shipped per-line CR strip at `:136` already normalizes
   the entry before any field is read, so an otherwise-conformant line must not be
   refused merely for the file's line endings.
9. An entry whose sub-bullets appear in any order, and an entry carrying the new line
   alongside the `- flagged-gap:` and `- dispatch-reflection:` families — the new scan
   must be additive and must not collide with either.
10. Readers of the two `docs/tuning-oversight` sections: a GitHub markdown renderer and
    a plain-text reader.

**Out-of-scope synthetic extremes** — declined explicitly, so a finding escalating one
of these is answerable rather than open-ended:

- **Adversarial encodings of the value**: zero-width or homoglyph substitutes for
  either accepted word, a non-UTF-8 re-encoded board, an embedded NUL, and an
  arbitrarily long value. The vocabulary match is an exact byte comparison against two
  ASCII words; anything else is refused, which is the safe direction.
- **Markdown shapes the shipped entry scan has never supported for the three existing
  sub-bullet families**: the marker inside a fenced code block, inside an HTML comment,
  on a continuation line, or nested under a second-level sub-bullet. The new family
  inherits exactly the support `- entry-mode:` and `- dispatch:` already have and no
  more.
- **Scale**: ever-larger boards, ever-deeper indentation, thousands of duplicate
  `- refreeze-ratifier:` lines, and boards with thousands of entries.
- **Every environment-injection and configuration-scope channel** — `GIT_CONFIG_*`,
  `XDG_CONFIG_HOME`, a shadowing shell function or a hostile `PATH`. The new arm reads
  a string out of a file already in hand and launches no process.
- **Authentication and impersonation.** Whether the party that answers a class-B
  ratification request is genuinely the declared authoring session, whether an
  authoring session may be spoofed, and whether a hostile board entry could redirect a
  ratification. The line is a declaration on a file both parties can already write —
  a re-disclosed residual of the existing gate, never a claim this task closes.
- **Concurrency.** Two sessions answering the same `drift-detected` firing at once, or
  a ratification arriving after the freeze already proceeded.
- **Terminal rendering and localization of the escalation message**: width, wrapping,
  ANSI handling. `bin/` output stays English; only the two oversight documents carry a
  Japanese mirror.
- **A repository where the branch point is unreachable** (a shallow or
  `--single-branch` clone that never fetched the predecessor). **AC1** reads the branch
  point and would fail there; that is a checkout defect to fix by fetching, not an
  input class this spec protects.

<!-- END intent-block: T-1131 -->

## Assumptions

- **Relayed premises, not measurable from this role.** Each is recorded with the side
  holding primary confirmation, and none contributes a hex literal or a count to any
  criterion.
  1. **GitHub issue #459's text** — relayed verbatim into this role in the task brief
     and reproduced verbatim in `## Problem`; not opened by this role (no network or
     tracker access from this role's toolset). Primary confirmation: the coordinating
     session.
  2. **The stack state.** This branch is cut from the predecessor branch
     `feature/458-stop-extension-ratifier` at its tip `421428a` (T-1130's close-out
     commit), and PR #460 against `develop` is **open, not merged**. Every criterion
     resolves the branch point live through the declared two-arm expression, so the hex
     literal is load-bearing nowhere in the frozen region. Primary confirmation: the
     coordinating session, which measured `git show-ref` and `git merge-base`.
  3. **Release tier PATCH**, on the ground that a board sub-bullet family plus a
     validate-if-present checker arm leaves an entry carrying no line reaching the
     operator byte-unchanged (default-reachability not met), so `CONTRIBUTING.md`'s two
     tests are not jointly met. Re-derived at freeze by the T-1110 gate; this spec
     asserts nothing about the tier and carries no criterion for it. Primary
     confirmation: the coordinating session.
  4. **The operator-approved lightweight mode A2** for this sprint — pm-authored spec,
     no spec review, one freeze, wording mutable, no per-task two-arm sweep or
     blast-radius sweep. Primary confirmation: the coordinating session.
- **T-1131 is the next free task id — corroborated by this role, not relayed.**
  Measured on 2026-09-08 with a repository-wide content search: `T-1131` occurs **zero**
  times, and T-1130 is the first entry of `## Done`.
- **The retro's measurement is itself relayed, and this spec says so rather than
  inheriting the issue's framing.** Issue #459 describes the incident as "Measured in
  the sprint `b-first-run` retro". Re-read at the primary source,
  `.shell-team/retros/2026-09-07-b-first-run.md`:94–98 is prefixed `（relayed）` and
  cites a v3-ma retro-input file outside this repository as its source. The correct
  statement of the premise is therefore: **this repository holds a relayed record of
  the incident, not a first-hand measurement of it.** Nothing in the frozen region
  depends on the correction count being two — the design is unchanged at one or five —
  so this is recorded as a correction to the framing rather than as a blocker.
- **Borrowed-vocabulary count-premise sweep (T-1081).** Classified by this role at
  authoring time; the execution-capable side runs each command live against the branch
  point's committed blobs and records the measured value beside the line before the
  freeze.
  - **own-coinage — asserted to occur zero times before this task.** Measured by this
    role on 2026-09-08 with repository-wide content searches over the working tree,
    each returning no matches: `refreeze-ratifier`, `T-1131`,
    `authoring-session-declared`, and `which human that GO is addressed to`. These are
    the non-vacuity ground for **AC2**, **AC3**, **AC4**, **AC5**, **AC6** and **AC7**.
    Command to confirm at the branch point:
    `git grep -c -F -e 'refreeze-ratifier' -e 'T-1131' -e 'authoring-session-declared' -e 'which human that GO is addressed to' "$(git merge-base feature/458-stop-extension-ratifier HEAD)" -- . ; echo rc=$?`
    — rc=1 with no output is the expected zero.
    **Measured at the branch point `421428a` by the coordinating session on 2026-09-08: rc=1, no output (zero).**
  - **borrowed — vocabulary another document already coined, which this spec's criteria
    rely on being *present* rather than absent.** `ratifier-accepted` and
    `ratifier-rejected` (coined by **T-1130** in `tests/loop-guard/run.sh`, already on
    this stack — which is exactly why **AC3** matches them only with a `T-1131` prefix
    and never bare); `falls back to the operator with the reason stated` (T-1130's
    anchor phrase, already present in `skills/run/SKILL.md` and `skills/goal/SKILL.md`
    — **AC4** requires it co-located with five other tokens on one line, so the
    pre-existing T-1130 line cannot satisfy it); `authoring-session` (T-1130);
    `operator-authored` (T-1091); `drift-detected`; `transcribes`; `entry-mode`;
    `rework-digest.sh`; `Two condition sources`; the whole-line heading
    `## Who may re-freeze a frozen intent block`; the whole-line heading
    `## 凍結された intent block を誰が再凍結してよいか`; and the sentence fragment
    `never moves without a per-instance human GO — whatever changed` (whole-file count
    measured by this role: **1**, in `docs/tuning-oversight.md`). Commands to confirm
    the presence premises at the branch point:
    `git grep -c -F -e 'ratifier-accepted' -e 'ratifier-rejected' "$(git merge-base feature/458-stop-extension-ratifier HEAD)" -- tests/loop-guard/run.sh`
    ;
    `git grep -c -F -e 'falls back to the operator with the reason stated' -e 'rework-digest.sh' "$(git merge-base feature/458-stop-extension-ratifier HEAD)" -- skills/run/SKILL.md skills/goal/SKILL.md`
    ;
    `git grep -c -F -e 'transcribes' -e 'operator-authored' "$(git merge-base feature/458-stop-extension-ratifier HEAD)" -- agents/pm-spec.md`
    ;
    `git show "$(git merge-base feature/458-stop-extension-ratifier HEAD):docs/tuning-oversight.md" | grep -c -F -- 'never moves without a per-instance human GO — whatever changed'`
    .
    **Measured at the branch point `421428a` by the coordinating session on 2026-09-08: `tests/loop-guard/run.sh` = 4; `skills/run/SKILL.md` = 5, `skills/goal/SKILL.md` = 3; `agents/pm-spec.md` = 8; the EN default fragment = 1.**
- **pm-spec cannot run a `check:` line.** All seven were written by reading the target
  files at this HEAD. The execution-capable side runs them live and in full before the
  freeze, repairs anything broken or vacuous with a meaning-preserving fix, and only
  then records the hash. Expected distribution at a pre-implementation sweep: **AC1**
  red (its negative control requires the two arms' checkers to differ, which they do
  not yet), **AC2** red (the new arm does not exist, so every rejected shape exits 0),
  **AC3** red, **AC4** red, **AC5** red, **AC6** red, **AC7** red (its
  `refreeze-ratifier`-in-header control). Nothing here is expected green at base; a
  green result at base is a sign the criterion is vacuous and routes back for repair.
- **Downstream-impact analysis, and what stays unmeasured.** A literal-path derivation
  over the merged spec corpus is the method available to this role for the paths this
  task edits (`bin/check-entry-mode.sh`, `tests/check-entry-mode/run.sh`,
  `skills/run/SKILL.md`, `agents/pm-spec.md`, the two oversight documents).
  **Indirection class disclosed, not engineered around**: a merged criterion reaching
  any of these through a directory-level pathspec, a glob, or a path built at run time
  from `bin/team-paths.sh --get …` is invisible to a literal-path derivation in
  principle — and **AC2** itself is an instance of that class, since it reaches the
  board through `bin/team-paths.sh --get todo`. Under the operator-approved lightweight
  mode this task runs **no per-task two-arm full-population sweep** — the sprint runs
  one before release — so that class stays **disclosed as unmeasured** rather than
  claimed as covered.
- **Line numbers move.** Every `:NNN` in this file was measured on 2026-09-08. Locate
  each site by its quoted text, not by its line number.

## Open questions

None blocking.

## Pre-commitment

Dispositions are named here, before review round 1, so a firing trigger executes a
decision instead of opening one. Threshold is this repository's default **two
consecutive rounds of the same-class defect**, not loosened. Authorship class of every
disposition below: **AI self-discipline** — self-imposed by this spec, not an
operator-ratified ruling.

- **Droppable, first — the Japanese mirror in `docs/tuning-oversight.ja.md` (the
  `.ja.md` half of AC6).** Trigger: two consecutive review rounds producing independent
  new defects against the Japanese section's wording or extraction. Disposition:
  **AC6** narrows to the English document, the findings travel to a fast-follow issue
  as the mirror's requirement list, and the `- adopter-surface:` obligation is
  discharged by the English section, which is the surface the change actually needs.
- **Droppable, second — the `agents/pm-spec.md` producer-duty wording (AC5's first
  half).** Trigger: same threshold, against that wording specifically. Disposition:
  **AC5** narrows to the `check-prompt-sync.sh` clause and the producer duty falls back
  to the spec's own frozen Goal plus `skills/run/SKILL.md`'s line, both of which state
  it; the findings go to a fast-follow issue. Ground for this ordering: the duty is
  already carried by two surfaces without it, whereas the Japanese mirror has no
  substitute reader.
- **Never-dropped — AC1 and AC2.** **AC1** (every existing arm's verdict unchanged, and
  an absent line passing in both modes) is the promise every existing board is owed, and
  **AC2** (the arm fails closed on out-of-set, duplicate, malformed-spacing and
  `pm-authored`-with-line) is the arm's own reason to exist. Defeat of either **stops
  the task and returns it to planning**; it is not answered by another patch round,
  because a validate-if-present arm that cannot leave the absent case alone, or cannot
  fail closed on a violation, is evidence about the design premise rather than about
  the implementation's craft.

## Symmetry table — norm boundary by parallel surface

Placed outside the frozen region so it can be corrected without a re-freeze. Every
"no" is a scope decision recorded with its reason, not a claim about an unread file's
behaviour.

| Surface | In scope | Reason |
|---|---|---|
| `bin/check-entry-mode.sh` | yes | The reader. Gains one family arm, strict validate-if-present, modelled on the shipped `- dispatch-reflection:` family gate. Covered by **AC1**, **AC2**, **AC7**. |
| `tests/check-entry-mode/run.sh` | yes | Where the arm's CI coverage lands, as inline scratch boards through the existing `bd`/`mk` helpers. Covered by **AC1**, **AC3**, **AC7**. |
| `skills/run/SKILL.md` class-B escalation | yes | The surface issue #459's record is about. Both its `drift-detected` sites — the bullet at `:60` and the branch reachable from `:50` — are one rule; **AC4** requires the rule on at least one self-contained line. |
| `skills/goal/SKILL.md` | **no** | **Measured, not assumed**: its only `drift-detected` handling is signature translation into `AC900002` (`:169`, `:175`); it carries no class-B re-freeze escalation branch to extend. **AC4** runs a zero-occurrence check over it as the negative control. |
| `agents/pm-spec.md` | yes | Where the producer duty lives, beside the T-1096 board-transcription paragraph (`:123`) and the `- flagged-gap:` window (`:125`) it copies. Covered by **AC5**; droppable second. |
| `docs/tuning-oversight.md` | yes | The adopter-facing home for "who may re-freeze", and the file whose `:107` sentence would otherwise contradict the shipped behaviour. Covered by **AC6**; carries the `- adopter-surface:`. |
| `docs/tuning-oversight.ja.md` | yes | Its `:91` section is the twin of the English one, by the T-1130 precedent that both languages ship in the same task. Covered by **AC6**; droppable first. |
| `templates/prompt-blocks/dispatch-record.md` | **no** | `- refreeze-ratifier:` is not a dispatch axis — it records who ratifies a re-freeze, not how a phase is dispatched. `bin/check-prompt-sync.sh` runs in **AC5** as the negative control that no registered block moved. |
| `bin/close-out.sh` | **no** | It gates on the `- dispatch:` family and on unresolved fast-follow dispositions; the new sub-bullet has no resolution state and, per `## Non-goals`, no close-out gate in this task. |
| `bin/check-handoff.sh` | **no** | It validates the board's `- [ ]` line format, which this task does not change; sub-bullets sit outside its reach. |
| `docs/loop-engineering/spec-authorship-entry.md` | **no** | It governs which party authors a spec (the `specify` axis), not who ratifies a re-freeze afterwards. No criterion here asserts anything about its content. |
| `README.md` | **no** | Adopter-facing oversight tuning is documented in `docs/tuning-oversight.md`, which this task edits. |
| `.shell-team/todo.md` (this repository's own board) | read-only | **AC2** reads it through `bin/team-paths.sh --get todo` as the forward-only control. This task writes only its own entry's `- entry-mode:` / `- spec-review:` sub-bullets, and no `- refreeze-ratifier:` line, because it is `pm-authored`. |

## Body-to-AC correspondence

| # | Body directive | Source | Where it lands |
|---|---|---|---|
| 1 | The sub-bullet is `- refreeze-ratifier:`, closed to `operator` / `authoring-session` | Goal, #459 Proposal 1 | **AC2** (both accepted; four out-of-set spellings refused) |
| 2 | The `authoring-session:<label>` suffix is superseded — no label accepted | Goal (supersession), routing-map decision (a) | **AC2** (`authoring-session:hub` is one of the eight refused shapes) |
| 3 | Same meaning as T-1130's tokens; `authoring-session` is a distinct party only when the author is not `pm-spec` | Goal | info-only (not promoted to AC) — a semantic identity between two vocabularies has no artifact to read; held by **AC2**'s closed pair being byte-identical to T-1130's and by **AC4**'s reuse of T-1130's anchor phrase |
| 4 | The checker gains one arm, strict validate-if-present | Goal, #459 Proposal 2 | **AC1** (absent ⇒ exit 0 in both modes) + **AC2** (present ⇒ enforced) |
| 5 | The warning tier and its scheduled promotion are superseded | Goal (supersession), routing-map decision (b) | **AC2** (every violation exits **1** — an exit 0 with a warning fails the criterion) |
| 6 | The line on a `pm-authored` entry refuses | Goal | **AC2** (rejected shape 8) |
| 7 | Presence is a prose producer duty, never a refusal | Goal, Non-goals | **AC1** (absent-line arm exits 0 on an `operator-authored` entry) + **AC5** (the duty is written where `pm-spec` reads it) |
| 8 | Malformed spacing is collected wide and parsed strict | Goal, `bin/check-entry-mode.sh`'s own repair history | **AC2** (the doubled-space and space-before-colon shapes each refuse rather than reading as absent) |
| 9 | The run skill's class-B escalation reads the line and addresses it there | Goal, #459 Proposal 3 | **AC4** (`refreeze-ratifier` co-located with `drift-detected`) |
| 10 | The fallback names which of the three cases produced it, never silently | Goal, routing-map decision (d) | **AC4** (the fixed anchor phrase `falls back to the operator with the reason stated`) |
| 11 | The escalation declares whose authority the declaration carries (its writer, not the operator) | Goal, 2026-08-13 lesson | **AC4** (the token `authoring-session-declared` on the same line) |
| 12 | `skills/goal/SKILL.md` is not touched | Non-goals (with its measurement) | **AC4** (zero occurrences of `refreeze-ratifier`, with a read-happened positive control) |
| 13 | `pm-spec` transcribes the author's declared value and never chooses one | Goal | **AC5** (one line carrying `refreeze-ratifier`, `operator-authored` and `transcribes`) |
| 14 | Absence is legal and means `operator`; an undeclared value is never a freeze blocker | Goal | **AC1** (absent-line arm) |
| 15 | Both oversight documents are extended, in both languages | Goal | **AC6** (both headings, both sections, four shared literals, six-line floor) |
| 16 | The shipped default sentence is kept and qualified, never deleted | Goal | **AC6** (the shipped fragment still present **and** the coined qualifier present) |
| 17 | `templates/prompt-blocks/dispatch-record.md` is not edited | Non-goals | **AC5** (`bin/check-prompt-sync.sh` exit 0 as the negative control) |
| 18 | Forward-only — no existing entry is retro-annotated | Non-goals | **AC2** (the live board carries zero `- refreeze-ratifier:` sub-bullets, with a read-happened positive control) |
| 19 | No new checked-in fixtures; new cases are inline scratch boards | Non-goals | **AC3** (`tests/check-entry-mode/fixtures` asserted not to exist) |
| 20 | Every existing suite arm's verdict is unchanged | Goal, Pre-commitment (never-dropped) | **AC1** (every base-arm `^PASS` line present verbatim in the head arm) |
| 21 | Pure bash, zero new dependency, shellcheck-clean, bash 3.2 floor | Shipped invariant (`CLAUDE.md`) | **AC7** |
| 22 | The checker's own header documents the new family | Goal (implied by the file's existing self-documentation), routing-map scope | **AC7** (`refreeze-ratifier` in the leading comment header) |
| 23 | No change to `bin/close-out.sh`, the `- dispatch:` grammar or the `- dispatch-reflection:` family | Non-goals | info-only (not promoted to AC) — no scope-lock criterion is written here by design: an allow-list diff would duplicate what **AC1**'s verdict-unchanged lock already measures for the only file whose semantics could regress, and the rest is held by review and by the symmetry table's recorded grounds |
| 24 | No delivery channel, no authentication, no verification that the ratifier ruled | Non-goals | info-only (not promoted to AC) — a declared absence of a mechanism has no artifact to read; it is held by the criteria's narrowness, since no criterion requires or permits any network, process-launch or identity surface |
| 25 | No new checker, no new `bin/` script, no new test suite, no CI change | Non-goals | info-only (not promoted to AC) — same ground as row 23 |
| 26 | Release tier PATCH, no version bump, no CHANGELOG | Relayed planning premise, Non-goals | info-only (not promoted to AC) — the tier is a property of the sprint's version derivation, not of any file this task edits, so no check over this checkout can observe it |

## Notes for engineer

- **Collect wide, parse strict — this script's recurring defect class, and the one trap
  most likely to sink this task.** Two prior repairs to this file exist for exactly
  this: `bin/check-entry-mode.sh`:239–242 widened the gap/resolution stem net after
  T-1096 rework Blocker 2, and `:298`–`:309` widened the reflection stem across the
  colon after Codex round 1 Major 4. Write the new stem net the same way —
  `'^[[:space:]]*-[[:space:]]+refreeze-ratifier[[:space:]]*:[[:space:]]*'` — and keep
  the full grammar strict (`'^[[:space:]]*- refreeze-ratifier: (.*)$'`). A malformed
  line that neither net collects reads as the conformant absent case, which is the
  dangerous direction and is what **AC2**'s two spacing shapes measure.
- **Placement inside the script.** `EM_VALUE` is already parsed and validated at
  `:174`–`:178`, so the `pm-authored`-with-line refusal is one comparison against a
  value already in hand. Put the whole arm after the two-source mismatch check at
  `:215`–`:217` and before the flagged-gap block, so its refusals read in a natural
  order; the arm must not disturb `ENTRY`, `EM_VALUE` or `D_VALUE`.
- **`- refreeze-ratifier:` collides with none of the existing scans.** Every
  `- dispatch:`-anchored scan requires the literal colon immediately after the bare word
  `dispatch`, and the gap/resolution stems anchor on `flagged-gap`. Confirm this by
  reading, not by assuming — the same way the reflection family's own header comment
  records its non-collision at `:293`–`:296`.
- **The two new suite arms build inline scratch boards** through the existing `bd` (or
  `mk_pair`) helper under the suite's `$T` root — `tests/check-entry-mode/run.sh`:29–35
  and `:187`–`:192` are the patterns to copy. Name the cases so that
  `T-1131 ratifier-accepted` and `T-1131 ratifier-rejected` appear in the `pass`
  description, since **AC3** greps `^PASS.*<token>`. The bare stems `ratifier-accepted`
  / `ratifier-rejected` are **already taken** by T-1130 in `tests/loop-guard/run.sh`, so
  the `T-1131` prefix is load-bearing, not decorative.
- **The run-skill line is one self-contained sentence carrying six tokens** (**AC4**):
  `refreeze-ratifier`, `drift-detected`, `authoring-session`, `operator-authored`,
  `falls back to the operator with the reason stated`, `authoring-session-declared`.
  Place it in step 2's `drift-detected` bullet at `:60` — the file's existing bullets
  there are already long single lines, so this matches the local shape rather than
  fighting it. The anchor phrase is T-1130's, reused verbatim on purpose; do not coin a
  second one.
- **The `agents/pm-spec.md` line is one sentence carrying three tokens** (**AC5**):
  `refreeze-ratifier`, `operator-authored`, `transcribes`. Extend the T-1096
  board-transcription paragraph at `:123` and the hand-off grammar at `:119`, reusing
  the file's own scoping idiom ("in `operator-authored` mode … in `pm-authored` mode you
  flag nothing") so the duty does not silently acquire the mode that has no carrier for
  it.
- **The oversight sections keep their shipped sentence.** `docs/tuning-oversight.md`:107
  stays exactly as it is; add prose after it. **AC6** requires both the shipped fragment
  `never moves without a per-instance human GO — whatever changed` **and** the coined
  qualifier `which human that GO is addressed to` in the English section — deleting the
  first to make room for the second fails the criterion. In the Japanese mirror, write
  natural Japanese around the four shared English literals, exactly as
  `docs/tuning-oversight.ja.md` already embeds bracketed English tokens; that file
  embeds the English fenced grant block verbatim rather than translating it, so do not
  translate the machine tokens either.
- **Say what the fallback is, not just that there is one.** Both the skill line and the
  oversight sections must state the three-state condition explicitly (`operator-authored`
  with `authoring-session` → the declared authoring session; `operator`, an absent line,
  or a `pm-authored` entry → the operator, with which of the three it was said out
  loud), because the whole point of the declaration is that nobody has to guess.
- **Measured-at-ref command check**: `not applicable — no deliverable of this task prints
  a command beside a label naming the git ref its result was measured at.` The one
  base-side read (**AC1**) is a criterion rather than a deliverable, and it reads
  committed blobs via `git archive` / `git show` at the declared branch point rather
  than the working tree.
- **Prior art worth reading first**:
  `.shell-team/specs/T-1130-stop-extension-ratifier.md` (the shape this spec follows,
  and the source of the shared vocabulary and anchor phrase),
  `bin/check-entry-mode.sh`:282–316 (the validate-if-present family gate this arm
  copies, and its two collect-wide comments), and `tests/check-entry-mode/run.sh`:169–213
  (the whitespace-variant arms whose shape the two new arms follow).
