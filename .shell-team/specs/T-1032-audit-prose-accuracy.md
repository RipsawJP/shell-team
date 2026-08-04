# Two shipped audits carry claims their own measurements contradict, and one interpretive call in T-1024 went undisclosed

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1032

## Problem

Two audit documents this repository ships as accounting records state things
that are false against the corpus they account for.

**(1) The `{1,4}` width-bound rationale (T-1021, issue #119).** The reason given
for bounding `bin/check-intent.sh`'s six numeric captures to `{1,4}` names this
repository's real ceiling for `- check:` lines in a spec's intent block as
*"this task's own spec, the largest measured, carries 24"*. T-1021's own spec
does carry 24 — but it is not the largest. Eight specs exceed 24, and the
maximum is 35 (`.shell-team/specs/T-1011-telemetry-event-rows.md`). The bound
itself is unaffected — 9999 against 35 is still enormous headroom — but the
*ground the bound rests on* is a superlative that was never measured, restated
verbatim at seven sites across three surfaces. A decision record whose stated
ground is false is worse than one with no ground: the next person tightening a
bound will copy the method, not the number.

**(2) The mktemp tie-break claim (T-1024, issue #127).** The audit's
Classification section records a "live finding" that no population line carries
more than one real `mktemp` invocation, "so the tie-break never actually fires
here". Measured false:
`.shell-team/specs/T-1005-tuning-oversight-merge-consequence.md` lines
270/283/291/298 carry 2-4 invocations each. Every one of them is `&&`-guarded,
so all four still land in class (a) and no count moves — but the correct
statement is that the tie-break was **never exercised**, not that it was never
needed. The document currently claims its own tie-break rule is dead code when
it is in fact live and simply never had to break a tie.

**(3) An undisclosed interpretive call (T-1024, issue #127).**
`.shell-team/provenance/T-1024.md` discloses three interpretive calls. There
was a fourth: DP2 rung 1's literal wording ("is *every* invocation on the line
guarded?") is **vacuously true** for a line whose only `mktemp` occurrences are
mentions, so a mention-only line could have been read into class (a) rather
than class (c). The audit resolved mention-only lines to class (c) via rung 3 —
a defensible reading, and the one the second disclosed decision assumes — but
the *rejected* reading was never named, and it moves real numbers
(a=45 / c=1 instead of a=36 / c=10). A provenance record's whole function is
that a later reader can see which fork was taken; a fork taken silently is
indistinguishable from a fork nobody noticed.

## Summarized sources

Everything this spec leans on that pm-spec did not read at first hand is listed
here rather than absorbed into the body as fact. pm-spec has no shell, no
network and no `gh` access.

- **GitHub issue #119** — **relayed** through the task prompt, stated by the
  orchestrator to have been fetched verbatim from GitHub. Its substance (the
  false superlative, the "name the true maximum or drop the superlative" fix
  shape, the "no grammar or bound change" constraint, the one-pass bulk-apply
  requirement) is carried into D1/D2 and the Non-goals. **Its own site count of
  "three surfaces (six sites total)" is corrected here to seven** — see AC1.
- **GitHub issue #127** — **relayed**, likewise stated as fetched verbatim. Its
  two items are carried into D3 and D4.
- **The tech-lead's measurements** — relayed, and **re-derived by pm-spec at
  first hand in the working tree** for every claim an acceptance criterion
  depends on: the four audit rows at
  `docs/loop-engineering/arith-base10-audit.md:201/203/205/207`;
  `bin/check-intent.sh:310-322` (the comment block, with the false phrase
  contiguous on `:317` and the block's prose beginning at `:316`);
  `.shell-team/provenance/T-1021.md:12` (the `reason:` line) and `:13` (the
  `grounding:` line); `docs/loop-engineering/check-line-mktemp-guard-audit.md:36`
  (the false tie-break sentence) and `:38-41` (the four class counts);
  `.shell-team/provenance/T-1024.md` (three decision triples);
  `.shell-team/specs/T-1005-tuning-oversight-merge-consequence.md:270/283/291/298`
  (2 / 4 / n / 4 invocations read directly on `:270`, `:283`, `:298`; `:291` read
  as part of the same run); and the per-spec `- check:` line distribution
  (T-1021 = 24, maximum = 35 at T-1011, eight specs above 24 at
  35/30/29/28/28/28/25/25). **One measurement pm-spec could not make** is the
  *intent-block-scoped* variant of that distribution — see the Assumptions.
- **`.shell-team/reviews/T-1021.md`, the Codex round-1 record** — read at first
  hand. It already carries this exact finding as a Minor with a filed-issue
  disposition ("correct it to name `T-1011`'s 35"), which is why this task
  exists and why the review record itself is a **historical record that stays
  untouched** (D5).
- **`.shell-team/reviews/T-1024.md`** — **not opened by pm-spec.** It is on the
  untouched-historical-record list (D5) and no acceptance criterion depends on
  its contents beyond byte-identity, which AC10 measures directly.
- **The base ref `7deb02a` and the branch `feature/119-127-audit-prose-accuracy`
  created off it** — relayed. pm-spec observed the working tree on `develop`,
  not the base blob. If `7deb02a` is not the real branch point, AC1, AC5, AC6,
  AC7, AC9, AC10, AC11, AC13 and AC14 measure the wrong comparison.
- **`## Active` was empty at `7deb02a`** — relayed; pm-spec observed an empty
  `## Active` (board lines 12-14) in the **working tree**, a different object
  from the base blob.
- **`T-1024`'s spec AC2 is pre-existing red at HEAD** — relayed, and
  **corroborated** by pm-spec against the document itself: the audit's
  `- population: 214 — files: 26` line is frozen prose while AC2 re-derives the
  population live, and T-1024's own spec (`Notes for engineer`) states the
  coupling explicitly. The declared 214/26 against a live 254/33 is the relayed
  pair. **Not fixed here** (Non-goals); disclosed by AC15.

## Goal

<!-- BEGIN intent-block: T-1032 -->

Every surviving statement of the check-line ceiling names the maximum that was
actually measured, cites the command and the ref that measured it, and
re-grounds the `{1,4}` headroom against that true maximum — at all seven sites,
in one pass, with identical wording. The `{1,4}` / `[1-9][0-9]{0,3}` grammar,
every class assignment, and every count in both audits are byte-unchanged: this
task corrects *claims*, never *decisions*. The mktemp audit says the tie-break
was never exercised rather than never needed, names the four lines that carry
multiple invocations, and shows why the classes do not move. T-1024's provenance
discloses its fourth interpretive call, marked as a non-contemporaneous
disclosure, with the rejected reading and the numbers it would have produced.
`bin/check-intent.sh` has the same number of lines it had before, and every line
number the arithmetic audit quotes still resolves to the same bytes. The dated
evidence of the defect — the board's `## Done` entries and the two review
records — is left exactly as it stands.

### Settled decisions (D1-D7)

These are binding. An engineer who wants to depart from one raises it before
implementing rather than after.

**D1 — measurement venue: each document states the ceiling as measured at its
own accounting ref; live code states it as measured at this task's merge
point.** `docs/loop-engineering/arith-base10-audit.md` and
`.shell-team/provenance/T-1021.md` are accounts of `a865ec0` and keep that ref:
their corrected sentences state the maximum **as measured at `a865ec0`**, with
the command. `bin/check-intent.sh` is live code, not an account of a past ref,
so its comment states the maximum **as measured at `7deb02a`**. Both refs are
named in the audit's measurement section so a reader can see whether they agree.
The engineer measures both with `git show <ref>:<path>` (R2), never from the
working tree alone, and never from this spec's prose. The rejected alternative —
re-pointing the audits at today's tree — is refused because a document that
re-measures itself at each read stops being an account of anything.

**D2 — correction form: name the true maximum and re-ground the headroom.** The
superlative is not merely dropped. Each corrected site carries two frozen ASCII
anchors verbatim:

- **A1** = `35 (T-1011)` — the measured maximum and its holder.
- **A2** = `285x` — the re-grounded headroom, `9999 / 35 = 285.7`, stated as a
  **floor** (`over 285x`). A ceiling-rounded `286x` would overstate headroom by
  a hair, which is the wrong direction for a number whose whole job is to
  justify a bound.

A1 appears at all **seven** sites. A2 appears at the **six** sites that state
the headroom; the provenance `grounding:` line is exempt (it is a citation list,
not a claim — reason recorded in the correspondence table). Every corrected
surface additionally carries the string `T-1032` at least once, so the change is
traceable to this task the way `bin/close-out.sh` and `tests/errexit-safe/run.sh`
were made traceable to T-1031. T-1021's AC10 machine-checks that the `headroom:`
and `stale-at:` fields exist in the audit rows — **both survive**, at their
existing occurrence counts.

**D3 — the mktemp tie-break sentence is replaced, not deleted.** The
replacement states: the tie-break was **never exercised, not never needed**;
`.shell-team/specs/T-1005-tuning-oversight-merge-consequence.md` lines
`270/283/291/298` each carry more than one invocation; every one of those
invocations is `&&`-guarded, which is why all four lines stay class (a) and the
corpus counts do not move. It carries a `- measurement:` line with the literal
command and the ref `1e31600` (the audit's own base ref, per D1). The four
`class-*` count lines and the reconciliation identity are byte-unchanged.

**D4 — the fourth interpretive call is disclosed as a fourth decision triple in
`.shell-team/provenance/T-1024.md`, marked non-contemporaneous.** Venue: the
provenance record itself, because that is the file whose declared purpose is the
decision inventory, and a disclosure filed anywhere else leaves the inventory
still incomplete. The new triple opens with the bracketed annotation
`[disclosed 2026-08-05 by T-1032, not contemporaneous]`, following the existing
in-file precedent (`T-1021.md`'s first decision opens
`[superseded this round, retained as the historical record]`), which
`bin/check-provenance.sh`'s `DECISION_RE` accepts unchanged. It names DP2 rung
1's **vacuous truth** for mention-only lines, the rejected reading, and the
counts that reading would have produced (`a=45` / `c=1`) against the shipped
`a=36` / `c=10`. The three pre-existing triples are byte-unchanged.
`.shell-team/provenance/T-1032.md` cross-references it.

**D5 — the historical records are not edited.** `.shell-team/todo.md`'s `## Done`
entries for T-1021 and T-1024, `.shell-team/reviews/T-1021.md` and
`.shell-team/reviews/T-1024.md` all carry the same false phrases and all stay
exactly as they are. They are the **dated evidence** that the defect existed and
that a gate caught it — `reviews/T-1021.md` is where the finding was raised in
the first place. Editing them would destroy the record of the review that
produced this task. The distinction against D1/D4, which *do* edit
`.shell-team/provenance/*`: a provenance file is a **decision inventory that is
supposed to be complete and correct**, while a board `## Done` entry and a review
record are **transcripts of what was said at a moment**. Correcting an inventory
is maintenance; correcting a transcript is falsification.

**D6 — `bin/check-intent.sh` keeps its exact total line count, and no line
number the arithmetic audit quotes may move (R1).** The audit addresses this
file at 47 distinct line numbers, and `bin/check-intent.sh:313` — a cited
comment-only occurrence — sits three lines above the false phrase. A one-line
growth in the comment block silently invalidates every citation below it, and
T-1021's own acceptance criteria cannot detect that. The edit therefore rewraps
**within** the comment block, keeping the file's line count identical and every
cited address byte-identical. Padding the file with filler to restore a line
count after an overshoot is forbidden for the same reason T-1031 forbade padding
a source file to preserve a ledger pin: it makes the file lie to keep a number.

**D7 — no bound, class, count, decision or grammar changes.** `ATTEST_FULL_RE`
and `HASH_FULL_RE` are byte-identical to their base blobs. The arithmetic audit's
`NEEDS-WIDTH-BOUND` row count, `headroom:` count and `stale-at:` count are
unchanged. The mktemp audit's four `class-*` lines and its reconciliation line
are unchanged. `bin/check-intent.sh` changes **comment text only** — no
executable line is touched, and the file stays shellcheck-clean.

## Non-goals

- **Changing the `{1,4}` / `[1-9][0-9]{0,3}` width bound, or any regex, in
  `bin/check-intent.sh`** (D7). The bound is correct; only its stated ground was
  wrong.
- **Changing any class, count, decision or reconciliation identity in either
  audit** (D3, D7). Both corrections are claim-fidelity fixes that leave every
  number that was measured exactly where it is.
- **Re-measuring or refreshing T-1024's declared population (`214` / `26`).** The
  live population has since grown, so T-1024's spec AC2 is **already red at
  `7deb02a`, before this task touches anything**. That is a pre-existing
  condition caused by later tasks' specs landing, it is out of scope here, and it
  is a candidate for the next planning input. AC15 requires it to be disclosed
  with both measured pairs rather than quietly inherited. This spec's own
  `mktemp`-bearing `check:` lines move that live population further; that too is
  disclosed, not fixed.
- **Editing `.shell-team/todo.md`'s `## Done` entries, `.shell-team/reviews/T-1021.md`
  or `.shell-team/reviews/T-1024.md`** (D5).
- **Editing `.shell-team/specs/T-1021-arith-base10-audit.md` or
  `.shell-team/specs/T-1024-check-line-mktemp-guard.md`.** Both frozen intent
  blocks are untouched and both ledgers stay aligned (R3). No re-freeze of any
  task is proposed, requested or implied.
- **Amending the text of GitHub issue #119 itself** to correct its "six sites"
  count. This role has no network; the correction is recorded in AC1, in the
  provenance record and in the pull-request body, and whether the filed issue is
  amended is the orchestrator's call.
- **Fixing, re-guarding or re-classifying T-1005's four multi-invocation lines.**
  They are already guarded, and T-1024's rule-1 marks every closed-task site
  not-apply. This task changes what the document *says* about them, nothing else.
- **Building a checker that detects a superlative or an unmeasured claim in a
  shipped document.** That is verification-mechanism work at a different review
  standard and would breach this task's scope lock.
- **Adding, removing or renumbering any acceptance criterion in T-1021's or
  T-1024's frozen specs**, including the pre-existing red one.

## Acceptance criteria

Every `check:` below runs from the repository root. `7deb02a` is this task's
merge point; the criteria that name it are **merge-point-scoped and expected to
go stale after merge** — do not widen their base-ref resolution and do not
re-derive them per rework round.

Two frozen fragments name the false claim, quoted here once so every criterion
below refers to the same bytes:

- **F-A** = `the largest measured, carries 24` (the audit rows, the
  `check-intent.sh` comment, and the provenance `reason:` line)
- **F-B** = `the largest measured intent block` (the provenance `grounding:`
  line)

- [ ] **AC1** **The site census is seven, re-derived from the base blobs, and
  the issue's own count of six is corrected.** At `7deb02a`: F-A occurs on
  **4** lines of `docs/loop-engineering/arith-base10-audit.md`, **1** line of
  `bin/check-intent.sh` and **1** line of `.shell-team/provenance/T-1021.md`;
  F-B occurs on **1** line of `.shell-team/provenance/T-1021.md`. Total **7**.
  The provenance file carries the phrase at **two** lines — its `reason:` line
  and its `grounding:` line — which is the single site issue #119 counted as one.
  Every count is printed before the verdict, so the census is visible evidence
  rather than a claim.
  - check: A='the largest measured, carries 24'; B='the largest measured intent block'; a1=$(git show 7deb02a:docs/loop-engineering/arith-base10-audit.md | grep -cF -- "$A"); a2=$(git show 7deb02a:bin/check-intent.sh | grep -cF -- "$A"); a3=$(git show 7deb02a:.shell-team/provenance/T-1021.md | grep -cF -- "$A"); b3=$(git show 7deb02a:.shell-team/provenance/T-1021.md | grep -cF -- "$B"); printf 'base census: audit=%s check-intent=%s prov-reason=%s prov-grounding=%s total=%s\n' "$a1" "$a2" "$a3" "$b3" "$((a1+a2+a3+b3))"; [ "$a1" -eq 4 ] && [ "$a2" -eq 1 ] && [ "$a3" -eq 1 ] && [ "$b3" -eq 1 ] && [ "$((a1+a2+a3+b3))" -eq 7 ]

- [ ] **AC2** **The false claim is gone from all three operational surfaces.**
  F-A occurs zero times in `docs/loop-engineering/arith-base10-audit.md`,
  `bin/check-intent.sh` and `.shell-team/provenance/T-1021.md`; F-B occurs zero
  times in `.shell-team/provenance/T-1021.md`. Each file is first grepped for a
  token that must be there (`NEEDS-WIDTH-BOUND`, `ATTEST_FULL_RE`, `decision:`),
  so a zero cannot come from an unreadable or emptied file. The search is
  deliberately **scoped to these three operational files** and not run
  repository-wide: this spec, the board's `## Done` entries and the two review
  records all quote the false claim on purpose, and a blanket search would
  report the discussion of the defect as the defect.
  - check: A='the largest measured, carries 24'; B='the largest measured intent block'; grep -qF -- 'NEEDS-WIDTH-BOUND' docs/loop-engineering/arith-base10-audit.md && grep -qF -- 'ATTEST_FULL_RE' bin/check-intent.sh && grep -qF -- 'decision:' .shell-team/provenance/T-1021.md && [ "$(grep -cF -- "$A" docs/loop-engineering/arith-base10-audit.md)" -eq 0 ] && [ "$(grep -cF -- "$A" bin/check-intent.sh)" -eq 0 ] && [ "$(grep -cF -- "$A" .shell-team/provenance/T-1021.md)" -eq 0 ] && [ "$(grep -cF -- "$B" .shell-team/provenance/T-1021.md)" -eq 0 ]

- [ ] **AC3** **D2's anchors are applied at every site, in one pass, with
  identical wording.** A1 (`35 (T-1011)`) occurs on exactly **4** lines of the
  arithmetic audit, **1** line of `bin/check-intent.sh` and **2** lines of
  `.shell-team/provenance/T-1021.md` — seven, matching AC1's census exactly. A2
  (`285x`) occurs on **4** / **1** / **1** lines of the same three files (the
  provenance `grounding:` line is exempt per D2). `T-1032` occurs at least once
  in each. Exact counts, not floors: a partial bulk-apply that fixes three of the
  four audit rows fails here, which is the whole point of the one-pass
  requirement.
  - check: A1='35 (T-1011)'; A2='285x'; a=$(grep -cF -- "$A1" docs/loop-engineering/arith-base10-audit.md); b=$(grep -cF -- "$A1" bin/check-intent.sh); c=$(grep -cF -- "$A1" .shell-team/provenance/T-1021.md); d=$(grep -cF -- "$A2" docs/loop-engineering/arith-base10-audit.md); e=$(grep -cF -- "$A2" bin/check-intent.sh); f=$(grep -cF -- "$A2" .shell-team/provenance/T-1021.md); printf 'A1 audit=%s intent=%s prov=%s | A2 audit=%s intent=%s prov=%s\n' "$a" "$b" "$c" "$d" "$e" "$f"; [ "$a" -eq 4 ] && [ "$b" -eq 1 ] && [ "$c" -eq 2 ] && [ "$d" -eq 4 ] && [ "$e" -eq 1 ] && [ "$f" -eq 1 ] && grep -qF -- 'T-1032' docs/loop-engineering/arith-base10-audit.md && grep -qF -- 'T-1032' bin/check-intent.sh && grep -qF -- 'T-1032' .shell-team/provenance/T-1021.md

- [ ] **AC4** **The corrected claim is measurement-grounded, and the measuring
  command is re-run live rather than trusted.** The arithmetic audit carries a
  section headed `## Check-line ceiling measurement (T-1032)` that names the
  maximum-holder's full spec path, both refs (`a865ec0`, the document's own
  accounting ref, and `7deb02a`, this task's merge point), and the literal
  command. The same intent-block-scoped command is then executed against the
  working tree inside this check and must print
  `35 .shell-team/specs/T-1011-telemetry-event-rows.md`. **If the live
  re-derivation names a different file or a different number, that is a finding
  about this spec's premise** — route it back to pm-spec and correct A1 before
  the freeze rather than editing the check to match.
  - check: grep -qF -- '## Check-line ceiling measurement (T-1032)' docs/loop-engineering/arith-base10-audit.md && grep -qF -- '.shell-team/specs/T-1011-telemetry-event-rows.md' docs/loop-engineering/arith-base10-audit.md && grep -qF -- 'a865ec0' docs/loop-engineering/arith-base10-audit.md && grep -qF -- '7deb02a' docs/loop-engineering/arith-base10-audit.md && o=$(for s in .shell-team/specs/*.md; do n=$(awk '/BEGIN intent-block/{inb=1;next} /END intent-block/{inb=0} inb' "$s" | grep -c '^[[:space:]]*- check:'); printf '%s %s\n' "$n" "$s"; done | sort -rn | head -1); printf 'live intent-block-scoped maximum: %s\n' "$o"; [ "$o" = "35 .shell-team/specs/T-1011-telemetry-event-rows.md" ]

- [ ] **AC5** **R1 holds: `bin/check-intent.sh` has the same line count, and
  every line number the arithmetic audit quotes resolves to the same bytes.**
  The cited-address set is **extracted from the audit document itself** (all
  `check-intent.sh:<n>` and `check-intent.sh:<n>,<n>,…` forms, comma-split,
  de-duplicated) rather than transcribed here, so a citation added by this task's
  own edit joins the set automatically. The set must hold at least 45 addresses
  (an anti-vacuity floor against a broken extraction — 47 were present at the
  base ref). Each address is compared byte-for-byte between the base blob and the
  working tree, and any drift is printed. `git diff --numstat`'s own added and
  removed columns must be equal.
  - check: L=$(mktemp "${TMPDIR:-/tmp}/T1032-ac5.XXXXXX") || exit 2; git show 7deb02a:bin/check-intent.sh > "$L" || { rm -f "$L"; exit 2; }; N=$(grep -oE 'check-intent\.sh:[0-9]+(,[0-9]+)*' docs/loop-engineering/arith-base10-audit.md | cut -d: -f2 | tr ',' '\n' | sort -un); c=$(printf '%s\n' "$N" | grep -c .); bad=0; for n in $N; do x=$(sed -n "${n}p" "$L"); y=$(sed -n "${n}p" bin/check-intent.sh); if [ "$x" != "$y" ]; then printf 'cited address drifted: %s\n' "$n"; bad=1; fi; done; nb=$(grep -c '' "$L"); nw=$(grep -c '' bin/check-intent.sh); add=$(git diff --numstat 7deb02a -- bin/check-intent.sh | cut -f1); del=$(git diff --numstat 7deb02a -- bin/check-intent.sh | cut -f2); printf 'cited=%s base-lines=%s live-lines=%s added=%s removed=%s drift=%s\n' "$c" "$nb" "$nw" "${add:-0}" "${del:-0}" "$bad"; rm -f "$L"; [ "$c" -ge 45 ] && [ "$nb" -eq "$nw" ] && [ "$bad" -eq 0 ] && [ "${add:-0}" -eq "${del:-0}" ]

- [ ] **AC6** **D7 holds on the arithmetic side: no bound, class or field
  count moved.** `ATTEST_FULL_RE=` and `HASH_FULL_RE=` are **string-equal** to
  the same lines in the base blob (equality, not containment — a rewritten regex
  that merely still contains `{1,4}` must not pass). In the audit document, the
  occurrence counts of `NEEDS-WIDTH-BOUND`, `headroom:` and `stale-at:` are
  identical to their base counts, which is the machine half of "T-1021's AC10
  fields survive". Every count compared here is non-zero at base, so the
  comparison is its own positive control.
  - check: a=$(git show 7deb02a:bin/check-intent.sh | grep -F 'ATTEST_FULL_RE=') && b=$(grep -F 'ATTEST_FULL_RE=' bin/check-intent.sh) && [ -n "$a" ] && [ "$a" = "$b" ] && c=$(git show 7deb02a:bin/check-intent.sh | grep -F 'HASH_FULL_RE=') && d=$(grep -F 'HASH_FULL_RE=' bin/check-intent.sh) && [ -n "$c" ] && [ "$c" = "$d" ] && for t in NEEDS-WIDTH-BOUND 'headroom:' 'stale-at:'; do x=$(git show 7deb02a:docs/loop-engineering/arith-base10-audit.md | grep -cF -- "$t") && y=$(grep -cF -- "$t" docs/loop-engineering/arith-base10-audit.md) && [ "$x" -eq "$y" ] || exit 1; done

- [ ] **AC7** **D3's replacement landed.** The false sentence occurred on
  **exactly one** line at `7deb02a` (re-derived inside the check, so the "one
  sentence" premise is measured) and occurs **zero** times now. The replacement
  carries the corrected reading verbatim
  (`never exercised, not never needed`), names T-1005's spec file and the four
  line numbers as the token `270/283/291/298`, cites the audit's own ref
  `1e31600`, carries a `- measurement:` line, and cites `T-1032`.
  - check: F='so the tie-break never actually fires here'; M=docs/loop-engineering/check-line-mktemp-guard-audit.md; nb=$(git show 7deb02a:"$M" | grep -cF -- "$F"); printf 'base occurrences of the false sentence: %s\n' "$nb"; [ "$nb" -eq 1 ] && [ "$(grep -cF -- "$F" "$M")" -eq 0 ] && grep -qF -- 'never exercised, not never needed' "$M" && grep -qF -- 'T-1005-tuning-oversight-merge-consequence.md' "$M" && grep -qF -- '270/283/291/298' "$M" && grep -qF -- '1e31600' "$M" && grep -qF -- 'T-1032' "$M" && grep -qE '^- measurement: ' "$M"

- [ ] **AC8** **D3's counts did not move, and the rejected reading was not
  adopted.** The four `class-*` lines and the reconciliation identity line are
  present as **whole lines** (`grep -xF`, so a reworded line carrying the same
  substring cannot pass), and the alternate reading's totals (`a=45` as a class
  line, `c=1` as a class line) appear nowhere as class counts.
  - check: M=docs/loop-engineering/check-line-mktemp-guard-audit.md; for s in '- class-a-guarded: 36' '- class-b-unguarded-path-composed: 168' '- class-c-no-path-composed: 10' '- class-d-other: 0'; do grep -qxF -- "$s" "$M" || exit 1; done; grep -qF -- 'reconcile: population 214 = 36 (class-a-guarded) + 168 (class-b-unguarded-path-composed) + 10 (class-c-no-path-composed) + 0 (class-d-other)' "$M" && [ "$(grep -cxF -- '- class-a-guarded: 45' "$M")" -eq 0 ] && [ "$(grep -cxF -- '- class-c-no-path-composed: 1' "$M")" -eq 0 ]

- [ ] **AC9** **D4's fourth disclosure landed and is conformant.**
  `.shell-team/provenance/T-1024.md` carried **3** `- decision:` lines at
  `7deb02a` (re-derived inside the check) and carries **4** now. The new triple
  carries the bracketed non-contemporaneous annotation verbatim, names the
  vacuous-truth reading, and names both rejected counts (`a=45`, `c=1`). Every
  `- decision:` / `reason:` / `grounding:` line present at base still occurs
  verbatim, so the append cannot have rewritten a pre-existing triple. Both
  edited provenance files pass `bin/check-provenance.sh`.
  - check: P=.shell-team/provenance/T-1024.md; T=$(mktemp "${TMPDIR:-/tmp}/T1032-ac9.XXXXXX") || exit 2; git show 7deb02a:"$P" | grep -E '^(- decision:|[[:space:]]+(reason|grounding):)' > "$T" || { rm -f "$T"; exit 2; }; nb=$(git show 7deb02a:"$P" | grep -c '^- decision:'); nw=$(grep -c '^- decision:' "$P"); base_lines=$(grep -c . "$T"); miss=0; while IFS= read -r l; do grep -qxF -- "$l" "$P" || miss=1; done < "$T"; printf 'decisions base=%s now=%s base-triple-lines=%s missing=%s\n' "$nb" "$nw" "$base_lines" "$miss"; rm -f "$T"; [ "$nb" -eq 3 ] && [ "$nw" -eq 4 ] && [ "$base_lines" -ge 9 ] && [ "$miss" -eq 0 ] && grep -qF -- '[disclosed 2026-08-05 by T-1032, not contemporaneous]' "$P" && grep -qF -- 'vacuously true' "$P" && grep -qF -- 'a=45' "$P" && grep -qF -- 'c=1' "$P" && bash bin/check-provenance.sh "$P" && bash bin/check-provenance.sh .shell-team/provenance/T-1021.md

- [ ] **AC10** **D5 holds: the dated evidence is untouched.**
  `.shell-team/reviews/T-1021.md` and `.shell-team/reviews/T-1024.md` are
  byte-identical to their base blobs, and both still contain the false phrase
  (so "unchanged" is a claim about files that still hold the evidence, not files
  that lost it). `.shell-team/todo.md`'s F-A occurrence count is **identical to
  its base count** — which additionally proves this task's own board entry did
  not reproduce the false phrase verbatim.
  - check: A='the largest measured, carries 24'; git diff --quiet 7deb02a -- .shell-team/reviews/T-1021.md && git diff --quiet 7deb02a -- .shell-team/reviews/T-1024.md && grep -qF -- "$A" .shell-team/reviews/T-1021.md && x=$(git show 7deb02a:.shell-team/todo.md | grep -cF -- "$A") && y=$(grep -cF -- "$A" .shell-team/todo.md) && printf 'board F-A occurrences base=%s now=%s\n' "$x" "$y" && [ "$x" -ge 1 ] && [ "$x" -eq "$y" ]

- [ ] **AC11** **R3 holds: both frozen intent blocks are untouched and every
  stacked ledger stays aligned.** `.shell-team/specs/T-1021-arith-base10-audit.md`
  and `.shell-team/specs/T-1024-check-line-mktemp-guard.md` are byte-identical to
  their base blobs, and `bin/check-intent.sh` reports `aligned` for those two
  specs and for all five stacked neighbours (T-1027, T-1028, T-1029, T-1030,
  T-1031) against the live board — so a board edit or a comment edit that broke
  one is caught here rather than at the next task's gate.
  - check: git diff --quiet 7deb02a -- .shell-team/specs/T-1021-arith-base10-audit.md && git diff --quiet 7deb02a -- .shell-team/specs/T-1024-check-line-mktemp-guard.md && for s in T-1021-arith-base10-audit T-1024-check-line-mktemp-guard T-1027-promote-retro-2026-08-04 T-1028-class-m-refreeze T-1029-claim-fidelity-qa-step T-1030-reviewer-board-write-boundary T-1031-check-handoff-flag-anchor; do bash bin/check-intent.sh ".shell-team/specs/$s.md" .shell-team/todo.md || exit 1; done

- [ ] **AC12** **The CI-wired surfaces this task touches are green.**
  `bin/check-intent.sh` is shellcheck-clean (it is on the workflow's lint list)
  and its fixture suite passes — a comment-only edit must not disturb either.
  The board lints under `bin/check-handoff.sh`, the shipped template still lints
  (a positive control that the linter is not passing by accepting everything),
  and `bin/check-board-headings.sh` finds no heading deletion or replacement
  against the base.
  - check: shellcheck bin/check-intent.sh && bash tests/check-intent/run.sh && bash bin/check-handoff.sh .shell-team/todo.md && bash bin/check-handoff.sh templates/todo-template.md && bash bin/check-board-headings.sh .shell-team/todo.md --base 7deb02a

- [ ] **AC13** **Scope lock and required deliverables.** `git diff --name-only
  7deb02a` contains nothing outside the allow-list (the two audit documents,
  `bin/check-intent.sh`, the two edited provenance records, this spec, the board,
  and this task's three records — provenance, review, interventions); the changed
  set is non-empty, so the comparison is not vacuous; and the provenance and
  review records exist. Anything outside the allow-list is printed before the
  verdict. Merge-point-scoped: expected to go stale once later work lands on the
  same base.
  - check: A=$(mktemp "${TMPDIR:-/tmp}/T1032-a.XXXXXX") || exit 2; B=$(mktemp "${TMPDIR:-/tmp}/T1032-b.XXXXXX") || exit 2; git diff --name-only 7deb02a | sort -u > "$A"; printf '%s\n' .shell-team/interventions/T-1032.md .shell-team/provenance/T-1021.md .shell-team/provenance/T-1024.md .shell-team/provenance/T-1032.md .shell-team/reviews/T-1032.md .shell-team/specs/T-1032-audit-prose-accuracy.md .shell-team/todo.md bin/check-intent.sh docs/loop-engineering/arith-base10-audit.md docs/loop-engineering/check-line-mktemp-guard-audit.md | sort -u > "$B"; printf 'outside the allow-list:\n'; comm -23 "$A" "$B"; X=$(comm -23 "$A" "$B" | grep -c .); S=$(grep -c . "$A"); rm -f "$A" "$B"; [ "$S" -ge 1 ] && [ "$X" -eq 0 ] && [ -f .shell-team/provenance/T-1032.md ] && [ -f .shell-team/reviews/T-1032.md ]

- [ ] **AC14** **The board entry is present and the edit is a pure insertion.**
  T-1032's own `## Active` entry exists, and `.shell-team/todo.md`'s diff against
  the base has a **deletions column of 0**, measured through
  `git diff --numstat`'s own column rather than by counting `^-` diff markers,
  which is vacuous in a file whose entry lines all begin with a hyphen.
  - check: grep -qF -- '- [ ] **T-1032**' .shell-team/todo.md && D=$(git diff --numstat 7deb02a -- .shell-team/todo.md | cut -f2) && A=$(git diff --numstat 7deb02a -- .shell-team/todo.md | cut -f1) && printf 'board added=%s removed=%s\n' "${A:-0}" "${D:-0}" && [ "${A:-0}" -ge 1 ] && [ "${D:-1}" -eq 0 ]

- [ ] **AC15** **Runtime disclosure, recorded in the provenance record** (no
  `check:` — this is evidence a human or a later gate reads, not a command).
  Five items, each stated as a measurement with the command that produced it.
  **(a) CI wiring** — which of the surfaces this task touches are actually read
  by `.github/workflows/check-handoff.yml`, and which are not. The relayed claim
  is that CI reads nothing under `docs/loop-engineering/`, so the two audit
  documents' correctness has **no CI backstop at all** and the acceptance
  criteria above are the only mechanical evidence; confirm or refute that by
  reading the workflow, and name the steps that do cover `bin/check-intent.sh`.
  **(b) Mutation self-check** — each new lock deliberately broken one at a time,
  each confirmed to FAIL the criterion that should catch it, then restored and
  confirmed green. At minimum: insert one blank line into `bin/check-intent.sh`
  (AC5 must go red on both the line-count and the cited-address clauses); revert
  one of the four audit rows to the old wording (AC3's exact-4 count must go red
  while the other three stay corrected — the partial-bulk-apply case); delete the
  provenance `grounding:` line's correction (AC3's prov count 2 must go red);
  and one mutation aimed at a **detector's own blind spot** — for example, verify
  whether AC5's cited-address extraction still yields ≥45 addresses if the audit
  row containing the citations is reworded, and disclose what it would miss.
  **(c) Both measurement refs** — the intent-block-scoped maximum measured at
  `a865ec0` and at `7deb02a`, side by side with the command, and a statement of
  whether they agree. **(d) The pre-existing red** — T-1024's spec AC2 run at
  `7deb02a` **before any edit**, with its declared pair (214 / 26) and its live
  pair recorded as measured numbers, plus the same run after this task's changes
  showing the failure is unchanged in kind and not caused here. **(e) Wall-clock**
  for AC12 (`tests/check-intent/run.sh`) and AC11 (seven `check-intent.sh` runs
  over an 846KB board), so a later task sets `CHECK_ACS_TIMEOUT` from data.

- [ ] **AC16** **Pre-commitment, recorded before the first review round** (no
  `check:`). **R-a — the settled decisions are settled.** An argument that the
  bound should change, that a class or count should move, that the historical
  records should be corrected after all, that the fourth disclosure belongs
  somewhere other than T-1024's provenance, or that T-1024's population should be
  refreshed here, is a **re-freeze proposal (vK→vK+1) routed to pm-spec**, not a
  rework fix — conditional only on a fixed environment (if the intent-block-scoped
  re-measurement in AC4 contradicts `35 (T-1011)`, D2's anchors reopen by
  construction). **R-b — the escalation trigger.** *Factual condition*: the
  correction surface — the seven sites, the two audit documents and the two
  provenance records — draws **new, independent** Blocker or Major findings in
  **two consecutive** review rounds. *Contextual condition*: a third round of
  rework on that surface is about to start. **The factual condition governs when
  the two disagree.** The threshold is this repository's standing two-consecutive-
  rounds convention, taken without loosening. On trigger, the response is not a
  third patch: propose splitting the two issues apart — ship the #119 seven-site
  correction alone and carve #127's two items into their own task — and put that
  to the orchestrator before any further edit. Commit separation is required for
  exactly that reason: (1) the #119 surfaces (`bin/check-intent.sh`, the
  arithmetic audit, `.shell-team/provenance/T-1021.md`), (2) the #127 surfaces
  (the mktemp audit, `.shell-team/provenance/T-1024.md`), (3) the board and this
  task's own records.

## Input space

**Reachable input classes** — the inputs the corrections and their checks must
handle correctly:

1. **The three #119 surfaces as they stand at `7deb02a`**: four `- site:` rows in
   a markdown document (single lines of ~400 characters, whose `width: bound (…)`
   parenthetical repeats verbatim across rows), one wrapped `#`-comment block of
   13 physical lines in a bash script, and two indented continuation lines
   (`reason:` / `grounding:`) inside a provenance record.
2. **The two #127 surfaces**: one prose sentence inside a `## Classification`
   section, and a provenance record holding three decision triples that a new
   fourth is appended to, before the file's `<!-- END provenance: T-1024 -->`
   marker.
3. **The live spec corpus that the pinned measurement reads**: today 35 files
   under `.shell-team/specs/`, each carrying an `<!-- BEGIN/END intent-block -->`
   marker pair and between 7 and 35 `- check:` lines. The corpus **grows every
   sprint**, including by this task's own spec, so the measurement command must
   be re-derivable rather than transcribed, and its result is pinned to a named
   ref.
4. **T-1005's four population lines**, each 300-1200 characters, carrying 2-4
   `mktemp` invocations chained with `&&`.
5. **Line-number citations of `bin/check-intent.sh` inside the arithmetic
   audit**, in both the single (`check-intent.sh:467`) and comma-list
   (`check-intent.sh:134,227,468,…`) forms — 47 distinct addresses at the base
   ref, spanning lines 134 to 702.
6. **The 846KB board**, read seven times by AC11's `check-intent.sh` loop.

**Out-of-scope synthetic extremes** — named concretely, and declined:

- **A spec whose intent block carries more than 9999 `- check:` lines.** That is
  the `stale-at:` condition the bound already documents; this task re-grounds the
  headroom against the measured maximum and does not re-open the bound. A finding
  of the form "what if a spec had 10000 criteria" is out of scope by this
  declaration.
- **Ever-larger spec corpora and scan performance** — thousands of specs, timing
  of AC4's per-file loop. The corpus is this repository's own spec directory.
- **Range-form line citations (`check-intent.sh:616-623`) inside the arithmetic
  audit.** None exists there at the base ref (measured); the one range form in
  the repository is inside `bin/check-intent.sh`'s own comment, which is not the
  document AC5 extracts from. AC5's extraction is not required to parse ranges,
  and a synthetic range added to the audit is out of scope. If the engineer's own
  correction introduces a range citation, that is a spec-premise question to
  raise, not a silent extension.
- **Adversarial or non-UTF-8 bytes in any of the five edited files**, look-alike
  em-dashes substituted for U+2014, or a hostile `$TMPDIR`. The files are
  hand-written repository records.
- **Concurrent writers mutating the board or a provenance record while a check
  reads it.** No locking exists and none is added.
- **A `mktemp` invocation spelled through a variable, `command`/`env`-prefixed,
  or assembled at run time** inside T-1005's four lines. T-1024's own audit
  records that a static text scan cannot trace that class in principle; this task
  inherits that limit verbatim rather than re-litigating it, and the corrected
  sentence states the counts it measured, not a completeness guarantee.

<!-- END intent-block: T-1032 -->

## Body-to-AC correspondence

Every normative directive in the body above, mapped 1:1. A directive missing from
this table means the spec is incomplete.

| # | Body directive | Where | Promoted to |
|---|---|---|---|
| 1 | The site census is seven, not the issue's six | Problem, Summarized sources | **AC1** |
| 2 | The provenance record carries the phrase at two lines, not one | Summarized sources | **AC1** |
| 3 | The false claim is removed from all three operational surfaces | Goal, D2 | **AC2** |
| 4 | The negative search is scoped to operational files, not repository-wide | AC2 body | **AC2** (the surface list is the criterion) |
| 5 | Each document states the ceiling at its own accounting ref; live code at the merge point | D1 | **AC4** (both refs named in the measurement section) + **AC15(c)** |
| 6 | Measurement uses `git show <ref>:<path>`, never the working tree alone (R2) | D1 | **AC15(c)** (the refs and commands are recorded as measurements) |
| 7 | The audits are not re-pointed at today's tree | D1 | **AC6** + **AC8** (every ref-pinned count byte-unchanged) |
| 8 | A1 (`35 (T-1011)`) appears at all seven sites | D2 | **AC3** |
| 9 | A2 (`285x`) appears at the six headroom-stating sites; the grounding line is exempt | D2 | **AC3** (counts 4/1/1) — the exemption is the criterion's own asymmetry, stated in its body |
| 10 | The headroom is floored, not ceiling-rounded | D2 | **AC3** (the frozen token is `285x`) |
| 11 | Every corrected surface cites `T-1032` | D2 | **AC3** + **AC7** |
| 12 | `headroom:` and `stale-at:` survive at their existing counts | D2, D7 | **AC6** |
| 13 | The correction is one pass, all sites, identical wording | D2, Problem | **AC3** (exact counts, so a partial apply fails) |
| 14 | The tie-break sentence is replaced with the corrected reading | D3 | **AC7** |
| 15 | The replacement names T-1005's four line numbers and the guarded finding | D3 | **AC7** |
| 16 | The replacement carries a `- measurement:` line with command and ref `1e31600` | D3 | **AC7** |
| 17 | The four class counts and the reconciliation identity are byte-unchanged | D3, D7, Non-goals | **AC8** |
| 18 | The rejected reading's numbers are not adopted as class counts | D4, D3 | **AC8** |
| 19 | The fourth disclosure lands in T-1024's provenance, as a fourth triple | D4 | **AC9** |
| 20 | The new triple is marked non-contemporaneous with the bracketed annotation | D4 | **AC9** |
| 21 | The new triple names the vacuous-truth reading and the rejected counts | D4 | **AC9** |
| 22 | The three pre-existing triples are byte-unchanged | D4 | **AC9** (every base triple line re-found verbatim) |
| 23 | `check-provenance.sh` stays conformant on both edited records | D4 | **AC9** |
| 24 | `.shell-team/provenance/T-1032.md` cross-references the disclosure | D4 | info-only (not promoted to AC) — a property of a record the engineer writes and QA reads; asserting a cross-reference string would lock prose this spec deliberately leaves to the writer, and AC13 already requires the record to exist |
| 25 | The board's `## Done` entries and both review records are untouched | D5, Non-goals | **AC10** |
| 26 | The untouched records still hold the false phrase (evidence preserved) | D5 | **AC10** |
| 27 | The distinction between a decision inventory and a transcript | D5 | info-only (not promoted to AC) — the rationale for AC10's and AC9's opposite treatments; the two criteria are the mechanism, the sentence is why they differ |
| 28 | `bin/check-intent.sh` keeps its exact line count | D6 | **AC5** |
| 29 | No line number the audit quotes may move | D6 | **AC5** |
| 30 | Padding the file to restore a line count is forbidden | D6 | info-only (not promoted to AC) — a prohibited *method* whose outcome is already indistinguishable-by-construction from the permitted one under AC5; the cited-address byte-equality clause makes padding fail anyway, since filler shifts a cited line |
| 31 | `ATTEST_FULL_RE` / `HASH_FULL_RE` byte-identical | D7, Non-goals | **AC6** (string equality against the base blob) |
| 32 | The `NEEDS-WIDTH-BOUND` row count is unchanged | D7 | **AC6** |
| 33 | `bin/check-intent.sh` changes comment text only and stays shellcheck-clean | D7 | **AC5** (line count + cited addresses) + **AC6** (regex equality) + **AC12** (shellcheck, fixture suite) |
| 34 | T-1024's population is not refreshed; the pre-existing red is disclosed | Non-goals | **AC15(d)** |
| 35 | This spec's own `mktemp` check lines move the live population; disclosed not fixed | Non-goals | **AC15(d)** |
| 36 | Neither frozen spec is edited and no re-freeze is proposed (R3) | Non-goals | **AC11** |
| 37 | Every stacked ledger stays aligned | R3 | **AC11** |
| 38 | Issue #119's own text is not amended | Non-goals | info-only (not promoted to AC) — an action outside this repository; AC13's allow-list is the machine half (no tracker artifact can enter the diff), and the correction itself is AC1 |
| 39 | T-1005's four lines are not re-guarded or re-classified | Non-goals | **AC13** (scope lock — the file is not on the allow-list) + **AC8** |
| 40 | No claim-fidelity checker is built | Non-goals | **AC13** (a new checker would appear outside the allow-list) |
| 41 | The diff stays inside the allow-list and the required records exist | AC preamble | **AC13** |
| 42 | The board edit is a pure insertion | Goal (implicit), board hygiene | **AC14** |
| 43 | CI wiring, mutations, both refs, the pre-existing red and wall-clock are disclosed | D1, D6 | **AC15** |
| 44 | The pre-commitment is recorded before round 1, factual condition governing | — | **AC16** |
| 45 | Diff-scope criteria are merge-point-scoped and must not be merge-ranged | AC preamble | info-only (not promoted to AC) — a norm addressed to future maintainers of this spec, not a property of the shipped artifact; promoting it would require asserting the absence of a future edit |
| 46 | Range-form citations are out of AC5's extraction scope | Input space | info-only (not promoted to AC) — a scope declaration bounding what QA and the cross-provider review may escalate to, deliberately not itself a check |

## Assumptions

- **The base ref `7deb02a` is the real branch point** for
  `feature/119-127-audit-prose-accuracy`. Relayed. Nine criteria read base blobs
  through it; if it is wrong they measure the wrong comparison. Verify before the
  freeze.
- **The intent-block-scoped maximum is 35 at T-1011.** pm-spec measured the
  **whole-file** `- check:` distribution with a search tool (T-1021 = 24,
  maximum = 35 at T-1011, eight specs above 24) and **could not run the
  intent-block-scoped variant**, having no shell. The two agree only if every
  `- check:` line in those files sits inside its intent block — likely, and
  consistent with T-1024's finding that all 214 of its population lines do, but
  **not verified for this population**. AC4 re-derives the scoped number live and
  is designed to go red if it differs. If it does, A1's frozen token is wrong and
  the correction is a pre-freeze fix, not a rework finding.
- **`9999 / 35 = 285.7`**, so `over 285x` is a floor and `286x` would be a
  ceiling round. Stated so the reviewer does not read `285x` as an arithmetic
  slip.
- **`bin/check-provenance.sh` accepts a leading bracketed annotation in a
  `- decision:` value.** Grounded in its `DECISION_RE` (`^- decision:(.*)$`,
  read at first hand) and in the existing precedent at
  `.shell-team/provenance/T-1021.md`'s first decision. AC9 runs the checker, so
  the claim is verified rather than assumed.
- **`## Active` was empty at the base ref**, making this board entry a pure
  insertion (AC14).
- **CI reads nothing under `docs/loop-engineering/`.** Relayed, and corroborated
  by pm-spec's own reading of `.github/workflows/check-handoff.yml` (no step
  names that directory; the only steps touching this task's files are the
  `shellcheck` list and the `check-intent` fixture suite, both of which cover
  `bin/check-intent.sh`). AC15(a) requires the engineer to confirm or refute it
  against the workflow rather than inheriting this sentence.
- **No test or checker pins the text of `bin/check-intent.sh`'s comment block.**
  Derived from pm-spec's own search of `tests/` for `check-intent.sh:<line>`
  citations (zero matches) plus the tech-lead's inventory. A pin written through
  indirection — a path built from a loop variable, a computed line number — is
  not something a static scan can trace in principle, so the completeness of this
  claim is delegated to AC12's live fixture-suite run rather than to the scan.

## Open questions

None blocking. One item is recorded rather than asked: whether the arithmetic
audit's four `- site:` rows should carry the full measuring command inline (as
they carry everything else verbatim) or reference the new
`## Check-line ceiling measurement (T-1032)` section for it. D2 requires only A1,
A2 and the ref in the rows; where the command text lives is the engineer's call,
because the rows are already ~400 characters and the trade-off between
self-containment and legibility needs the file in front of it. Both outcomes
satisfy AC3 and AC4.

## Notes for engineer

**Files (five edited, three created).** `docs/loop-engineering/arith-base10-audit.md`
(four `- site:` rows at 201/203/205/207, plus one new
`## Check-line ceiling measurement (T-1032)` section);
`bin/check-intent.sh` (comment lines 314-322 only — see the line-budget note
below); `.shell-team/provenance/T-1021.md` (the `reason:` and `grounding:` lines
of the third decision, at :12 and :13);
`docs/loop-engineering/check-line-mktemp-guard-audit.md` (line 36 plus a
`- measurement:` line); `.shell-team/provenance/T-1024.md` (append one triple
before the END marker). Created: `.shell-team/provenance/T-1032.md`, the board
entry, and (by later phases) the review and interventions records.

**`CHECK_ACS_TIMEOUT`: no elevation expected.** Twelve of the fourteen `check:`
lines are greps and `git show` reads. The two that are not: AC12 runs
`shellcheck` plus `tests/check-intent/run.sh` (a fixture suite, not a
directory-tree builder like `tests/close-out/run.sh`), and AC11 runs
`bin/check-intent.sh` seven times over an 846KB board. Both are estimated well
inside the 120s default — T-1030's three-run `check-intent` criterion measured in
seconds — but pm-spec has no shell and will not manufacture a timing. **Record
the measured wall-clock of AC11 and AC12 in the provenance record** (AC15(e)) so
the next task sets this from data. If either approaches the default, say so and
run with `CHECK_ACS_TIMEOUT=300` rather than trimming a criterion.

**The line budget in `bin/check-intent.sh` is the tightest constraint in this
task.** The comment block is lines 310-322. Line **313** is a cited address
(`check-intent.sh:285,286,313,620,621,623,634` in the audit's excluded-occurrence
row) and must not move or change. The next cited address above the block's end is
**335**, and lines 323-334 are executable (`ATTEST_LINE_RE`, `ATTEST_FULL_RE`,
the board-parser comment). So the free rewrap window is **314-322, exactly nine
lines**, and the corrected text must fit in nine. Today's nine lines hold roughly
630 characters of prose and the correction is longer than what it replaces —
compress the `Stale-at:` sentence (320-322) rather than growing the block. Keep
`35 (T-1011)` and `285x` each whole on one physical line: a wrap through the
middle of either token defeats AC3's fixed-string grep.

**Gotchas.**

- **Do not reproduce F-A or F-B verbatim in the board entry**, or AC10's
  "board count unchanged" clause goes red. Refer to the claim descriptively
  (the largest-measured / carries-24 claim) instead. The same caution applies to
  any new record whose path is on AC13's allow-list — AC10 only measures the
  board, but a stray verbatim copy elsewhere is the class of thing this task
  exists to remove.
- **The em-dash is U+2014** in the audit rows, the board line and the `check:`
  values above. A U+2013 substituted by an editor is a silent break.
- **AC5's extraction reads the audit document, post-edit.** If your correction
  adds a new `check-intent.sh:<n>` citation, it joins the compared set — which is
  intended, but means an incorrect new citation fails AC5 rather than passing
  unnoticed.
- **`.shell-team/provenance/T-1024.md`'s new triple goes *before* the
  `<!-- END provenance: T-1024 -->` marker**, with a blank line separating it from
  the third triple, matching the file's existing shape. `check-provenance.sh`
  requires the marker pair intact.
- **This spec's own `check:` lines use `mktemp` with a guarded idiom**
  (`|| exit 2`), because this is an open task and T-1024's rule-3 makes a live
  surface apply. They also add to the live population T-1024's AC2 re-derives,
  which is already red — disclose, do not chase.
- **`grep -c` returns exit 1 on a zero count.** Several checks above capture
  counts into variables and compare them numerically rather than chaining on
  `grep`'s status, deliberately. If you add a clause, keep that shape: a `grep`
  exit code 1 (no match, normal) and exit code 2 (unreadable file) must not
  collapse into the same displayed result.

**Prior art worth reading before you start.**
`.shell-team/reviews/T-1021.md`'s round-1 Minor and its file-an-issue disposition
(this task's origin, and the wording it recommended);
`.shell-team/specs/T-1031-check-handoff-flag-anchor.md` (the ledger-re-derivation
discipline in D2 and the base-blob equality shape in its AC8/AC11, both mirrored
here); `docs/loop-engineering/check-line-mktemp-guard-audit.md`'s
"What this audit does not claim" section (the limit language this task's
corrected sentence must stay consistent with).
