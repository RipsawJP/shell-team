# T-1051 — inspection UX polish bundle (#178/#179)

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1051

## Problem

Three deferred inspection-layer minors are open. (1) `bin/check-pii-shapes.sh`'s
`token` pattern has no left boundary guard on its OpenAI-style alternative, so an
ordinary English word ending in the two letters `s`+`k` followed by a hyphen and a
long kebab-case identifier — this repository's own label convention among them —
is reported as a credential shape. The class is real enough that the test recipe
already carries a hand-written spelling workaround for it. (2) `bin/check-intent.sh`
carries three small defects around its own inspection surface: two write sites whose
`||` guards claim to classify a failure that a signal-killed write never reaches, a
`--help` precedence that no fixture pins, and a computed hash that flows to three
consumers with no shape gate. (3) A third item (#180) widens the class-M re-freeze
grammar's normative text; it is **split out of this task** — see the scope decision
below, which records the measurement that forced it.

Left as they are, each defect costs a reader a moment of misdirected review: a
finding that names no secret, a `--help` behaviour nobody can point at, a hash the
code trusts without asking what it is.

## Summarized sources

- `.shell-team/specs/T-111-pii-shape-checker.md` (frozen intent block, lines 27–429) — AC8's two verbatim suite labels (`POS/NEG pair: token`, `negative: short lookalike must not fire`), AC10's rule-set enumeration and the fact that its `check:` line greps two labels and **does not assert the "nine" count**, AC13's no-allowlist rule, AC14's never-echo rule, AC18/AC19's ten whole-line-exact document limits, AC28's fail-noisy direction, and DP-1 (runtime fragment construction, no allowlist), DP-5 (home-path boundary class `(^|[^A-Za-z0-9.-])`), DP-10 (bias toward firing).
- `.shell-team/specs/T-1028-class-m-refreeze.md` — AC12 requires the first fenced `markdown` block after the new heading in **both** `docs/tuning-oversight` files to be byte-identical to that spec's frozen `F5` region, and `F5` (lines 74–93) sits **inside** T-1028's own intent block (lines 19–169). This is the measurement that splits #180 out; AC13's `grep -qF` token list is presence-only, so an additive widening of `CONTRIBUTING.md` would not have broken it.
- `.shell-team/specs/T-1005-tuning-oversight-merge-consequence.md` (line 270 `check:`) — the fenced-block content of the English and Japanese `tuning-oversight` files is compared with `cmp -s`, so those two blocks can only ever move together.
- `bin/check-pii-shapes.sh` — the nine-rule decomposition comment (lines 229–234), the anchoring/boundary inventory's `RE_TOKEN` entry (lines 291–293, "Not applicable"), the `token` pattern description (lines 39–42), `RE_HOME_PATH_BOUNDARY` (line 296), `RE_TOKEN` (line 314), and `report_pattern_lines` (line 358), which reads grep's `N:content` output and discards the content half.
- `bin/check-intent.sh` — the trap trio (lines 202–204, HUP/INT/TERM only), the extraction-pipeline write site (lines 351–352), `computed_hash`'s assignment (line 353) and its three consumers (lines 370, 820, 839), the `--help|-h` first case arm (line 217).
- `bin/check-refreeze-class.sh` — the byte-parallel trap trio (lines 137–139) and `block_signals_for_registration`/`restore_signal_traps` (lines 170–175); `HEX40_RE='^[0-9a-f]{40}$'` (line 178), the shape-gate precedent this task reuses.
- `tests/check-pii-shapes/run.sh` — the fragment-construction idiom (lines 444–446: `TK_P1`/`TK_P2`/`TK_B1`/`TK_B2`, a sequential-alphabet key body), the token POS/NEG block (lines 437–461) and the falsified rationale comment (lines 447–450), plus the "nine independently load-bearing" claim at line 36.
- `docs/pii-controls.md` (lines 35–37) and `docs/pii-controls.ja.md` (lines 31–33) — the same falsified `token` short-lookalike rationale, in both languages. These two sites are **not** named by the Routing Map's row 4; they were found by reading and are carried here as measured additions.
- `.shell-team/test-recipe.md` (line 417) — the emphasis-break spelling idiom (`…task-**id**-malformed…`), the hand-written workaround the #178 defect currently forces.
- The tech-lead's Routing Map for T-1051 — its 13-row measured-premise ledger, the split trigger, and the pre-commitment. Every row that is readable from this role was re-measured; see the ledger below.
- GitHub issues **#178, #179, #180** — **RELAYED**: their substance reached this role only through the Routing Map and the task prompt. pm-spec has no network or `gh` access and opened none of them.

## Measured-premise ledger

Every Routing Map premise this role could reach with a file read was re-read at its
primary source. Measured values replace relayed wording throughout this spec.

| Row | Relayed premise | Measured here | Verdict |
|---|---|---|---|
| 2 | `RE_HOME_PATH_BOUNDARY` at line 296 is `(^|[^A-Za-z0-9.-])` | line 296, exactly that value | confirmed |
| 3 | `report_pattern_lines` (line 358) discards match text | line 358; reads `ln rest`, prints only `ln` | confirmed |
| 4 | Two falsified prose claims: `:291-293`, `:39-42` | both confirmed; **plus two more sites** — `docs/pii-controls.md:35-37` and `docs/pii-controls.ja.md:31-33` carry the same claim | confirmed **and widened to four sites** |
| 5 | Fragment idiom at `tests/check-pii-shapes/run.sh:444-446`; emphasis-break at `.shell-team/test-recipe.md:417` | both confirmed | confirmed |
| 6 | T-111 frozen block covers the checker's ACs; AC8 greps two verbatim labels; **open question: does AC10's check assert the nine-rule count?** | AC8's check (line 130) greps exactly those two labels. **AC10's check (line 149) greps only `mutation: pattern is load-bearing` and `mutation: each exclusion is load-bearing` — it does NOT assert the count.** The word "nine" lives in AC10's frozen *prose* (line 140) and in `tests/check-pii-shapes/run.sh:36` | **open question answered** — see DP2 |
| 7 | `#179(a)` write sites at `:351-352` and `:370`; traps for HUP/INT/TERM only | confirmed: traps at lines 202–204; write sites as named | confirmed |
| 8 | `bin/check-refreeze-class.sh:133-139`, `:170-174` carry the byte-parallel trap trio | trap trio at 137–139; `block_signals_for_registration` at 170 and `restore_signal_traps` at 171–175 (the map's `:170-174` is one line short of the function's close) | confirmed, range corrected |
| 9 | `--help|-h` is the first case arm at `:217` | line 217 | confirmed |
| 10 | `computed_hash` assigned `:353`, consumed `:370`, `:820`, `:839`, no shape gate | all four confirmed; `HEX40_RE` precedent measured at `bin/check-refreeze-class.sh:178` | confirmed |
| 11 | #180's normative text on five English surfaces + one translation | all six confirmed at the cited lines | confirmed |
| 13 | **UNKNOWN**: is `agents/pm-spec.md:92` inside a generated prompt-block region? | **No.** The file's first `<!-- BEGIN prompt-block:` marker is at line 96; line 92 is hand-written prose above it. Whoever picks #180 up edits the agent file directly — there is no generator source for that line | **resolved** |
| — | (not in the ledger) #180 is landable inside T-1051 | **Falsified.** The `verbatim` requirement's canonical statement sits inside a fenced block that T-1028's frozen AC12 pins byte-for-byte to `F5`, which is inside T-1028's frozen intent block. Widening it faithfully needs a class-B re-freeze of a merged frozen spec | **split, see below** |

## Scope decision: #180 splits out

The Routing Map pre-authorized a split: *if the symmetry table needs more than two
cells of genuinely new wording, #180 leaves as its own task and T-1051 ships
#178+#179 — decide and state.* It is decided: **#180 is out of T-1051.** Two
independent grounds, both measured:

1. **Cell count.** Two norm-halves (a: redaction form; b: the `contradictory`
   trigger's definition) across five English surfaces plus the Japanese mirror
   yields far more than two cells of genuinely new wording — even the most
   economical faithful widening needs new sentences at `docs/tuning-oversight.md`
   (twice), `agents/pm-spec.md`, `skills/run/SKILL.md`, `CONTRIBUTING.md` and
   `docs/tuning-oversight.ja.md`.
2. **A frozen byte-lock the map does not name.** The `(a)` half's canonical
   statement — the operator-grant sample's "…every replaced line with its
   replacement **verbatim** on the board" — lives inside the fenced block at
   `docs/tuning-oversight.md:113-130`. T-1028's **AC12** pins that block, in both
   language files, byte-for-byte against T-1028's frozen `F5` region, and `F5`
   (lines 74–93) is inside T-1028's frozen intent block (lines 19–169). T-1005's
   line-270 `check:` additionally pins the English and Japanese fenced content to
   each other with `cmp -s`. So a faithful widening either (i) leaves the grant
   sample contradicting the widened norm, or (ii) re-freezes a merged frozen intent
   block — class B, human GO, which the Routing Map's own "Out of scope" line
   routes to stop-and-escalate.

The measurements above (rows 11 and 13, plus this one) are the split-off task's
requirement list; they are recorded here so nothing has to be re-derived there.
Issue #180 stays open. T-1051 ships **#178 + #179** and touches none of the six
#180 surfaces — locked by AC12 below.

## Design decisions

**DP1 — the token boundary guards the `sk-` alternative only.** The measured
false-positive population is confined to that alternative: English words ending in
`s`+`k` (a project label prefix, `mask`, `risk`, `desk`, `disk`) followed by a
hyphen and 16 or more kebab-case characters. `gh[oprs]_` and `AKIA` have **no**
measured false-positive carrier in this tree, and guarding them would suppress a
real key that happens to follow an alphanumeric character — a false negative, which
DP-10 ranks as the costlier error ("a false positive costs a moment of review, a
false negative is a silent, second-chance-less exposure"). The alternative design —
`(^|[^A-Za-z0-9])(gh…|AKIA…|sk-…)`, guarding all three — is **rejected** on exactly
those DP-10 grounds. `report_pattern_lines` discards grep's match text, so a
consuming group changes nothing about AC14's never-echo output either way; the
decision turns on detection, not on reporting.

**DP2 — the boundary class is `[^A-Za-z0-9]`, deliberately narrower than DP-5's,
and it does not become a tenth rule.** Two consequences, both load-bearing:

- *Class.* DP-5's home-path class also excludes `.` and `-` because those continue a
  host name. A token has no host-name continuation problem, and a real key preceded
  by `.` or `-` must still fire. Copying DP-5's class verbatim would manufacture a
  false-negative class. The two boundary classes therefore differ **on purpose**;
  DP-5's line stays byte-identical (AC2). **The accepted complement, stated here
  because this is where the class is chosen**: whatever a left-context class
  excludes, it excludes for real keys exactly as much as for lookalikes. One
  character is the whole of the information available, and a label chain's `s`+`k`
  ending and an unseparated real key present the identical left context, so no
  choice of class separates them. Selecting `[^A-Za-z0-9]` therefore **accepts**
  the suppression of an `sk-` key sitting immediately after a letter or a digit
  with no separator — the mathematical complement of #178's own prescription, not
  a separable implementation error: any class narrow enough to admit that key is
  also wide enough to re-report the chain the issue asks to silence. DP-10's
  prefer-firing bias would resolve this the other way on its own; the reason it
  does not is that the issue's prescription is the ratified instruction, recorded
  here so the next reader meets a decision rather than an oversight. The Goal
  states the exception, AC1 pins it in both directions, and AC5 requires all four
  repaired prose sites to disclose it.
- *Decomposition.* T-111's frozen AC10 enumerates the rule set as **nine** — five
  patterns plus four named exclusions — and `bin/check-pii-shapes.sh:229-234` states
  the same count, with each rule on its own assignment line so the suite can
  neutralise exactly one. Measured (row 6): AC10's `check:` line does **not** assert
  the count, so a tenth rule would not redden a machine gate — it would silently
  falsify frozen prose, which is worse. The guard is therefore written **inside
  `RE_TOKEN`'s own single assignment line**, adding no new `RE_*` variable: the
  token stays one pattern, the rule set stays exactly what T-111 froze, and no
  re-freeze of T-111 is needed. The anti-vacuity cover T-111 would have demanded of
  a tenth rule is supplied instead by DP3.

**DP3 — the new negative control proves it has teeth by mutation, not by CI red.**
Measured at step 0: `check-pii-shapes.sh --base develop` and `--all` are both clean
on this branch pre-fix, so the defect has no carrier file here and no live red can
witness the repair. The proof is therefore a mutation: a copy of the checker whose
`RE_TOKEN` line is rewritten to its pre-fix form must **report** the new negative
fixture, and the shipped checker must not. This is the same neutralised-copy idiom
T-111's AC10/AC11 already use, added as a new label alongside AC8's two, never
renaming or restructuring them.

**DP4 — the fixture self-reference contract.** No file this task writes may contain
a completed matching literal. Every credential-shaped and lookalike-shaped value —
in the suite, in this spec's own `check:` lines, in any record — is composed at run
time from fragments in the existing `TK_P1`/`TK_P2`/`TK_B1`/`TK_B2` idiom, with an
obviously synthetic sequential-alphabet key body; prose that must show the shape
uses the emphasis-break idiom (`ta**sk**-…`) rather than spelling it out. This is
DP-1 applied to this task's own artifacts, and it is why AC1's check reads the
shipped `RE_TOKEN` value out of the checker and composes its inputs rather than
embedding them.

**DP5 — `#179(a)` takes the trap route, and a site measured already-classified gets
no cosmetic trap.** The prose alternative narrows D3 in T-1041's frozen spec, which
is class-B human-side work; the trap route stays inside `bin/`. Whatever signal set
`bin/check-intent.sh` ends up trapping must be mirrored in
`bin/check-refreeze-class.sh` (the byte-parallel sibling) or the asymmetry declared
with a measured reason — that symmetry is AC8's cell. If the engineer measures that
a write site is *already* classified pre-fix (a pipeline stage's death is visible to
`pipefail` and does reach the `||`), that site is reported as not-applicable with
its evidence and nothing is added for it. A trap that repairs nothing is vacuous.

**DP6 — record shapes and the pre-commitment.** Factual trigger: two consecutive
rework rounds of new independent `Blocker`/`Major` findings against the same
component. Contextual trigger: a third round about to start. **The factual trigger
governs when they disagree.** Disposition, fixed before round 1: ① **#179(a)'s
signal-trap half drops first** — it grafts a new mechanism onto two stable scripts
and repairs no live red; its absence leaves the rest coherent, and the rounds'
findings travel to a new issue as that issue's requirement list. ② **#179(b)+(c)
drop together second** — pure additions to one script's argument and hash handling,
independently landable later. **#178 never drops**: it is the task's reason to
exist.

## Body-to-AC correspondence

| # | Body directive | Promoted to |
|---|---|---|
| 1 | The `sk-` alternative gains a left boundary guard (DP1) | AC1 |
| 2 | `gh[oprs]_` and `AKIA` stay unguarded (DP1) | AC1 |
| 3 | A key preceded by `.`, `-`, `/`, or at line start, still fires (DP2 class) | AC1 |
| 4 | The boundary class is `[^A-Za-z0-9]`, not DP-5's `[^A-Za-z0-9.-]` (DP2) | AC1, AC2 |
| 4a | The accepted complement: an `sk-` key with no separator after a letter or digit is suppressed by construction (DP2 *Class*, Goal) | AC1 (both directions, plus the suite label) |
| 4b | All four repaired prose sites disclose that complement (DP2 *Class*) | AC5 |
| 5 | No tenth rule; `RE_TOKEN` stays one assignment line; DP-5's line untouched (DP2) | AC2 |
| 6 | New suite assertions are added alongside T-111 AC8's labels, never renaming them (DP3) | AC3 |
| 7 | The new negative control is proven to have teeth by a pre-fix mutation copy (DP3) | AC4 |
| 8 | The four falsified prose sites are repaired to describe shipped behaviour (row 4) | AC5 |
| 9 | Both PII modes stay clean, and this task's own files are clean (step-0 oracle) | AC6 |
| 10 | T-111's frozen block and the docs' canonical limit sections are untouched | AC7, AC11 |
| 11 | `#179(a)` write sites are classified, or reported not-applicable with evidence (DP5) | AC8, AC17 |
| 12 | The trap-signal sets of the two sibling scripts stay symmetric (row 8, DP5) | AC8 |
| 13 | `--help` wins in both orderings with `--print-hash`, pinned by fixtures (row 9) | AC9 |
| 14 | `computed_hash` gets a `^[0-9a-f]{40}$` shape gate before any consumer, failing closed (row 10) | AC10 |
| 15 | No merged frozen intent block is re-frozen; drift stays absent | AC11 |
| 16 | #180 splits out; none of its six surfaces is touched here | AC12 |
| 17 | Repo contract: pure bash, zero dependency, shellcheck-clean, fail-closed | AC13 |
| 18 | Scope stays inside the allow-list | AC14 |
| 19 | No completed matching literal in any file this task writes (DP4) | AC15 |
| 20 | Board entry is a pure insertion and lints clean | AC16 |
| 21 | Mutation self-check and live demonstrations are run and reported (DP3, DP5) | AC17 |
| 22 | The pre-commitment's trigger and drop order (DP6) | info-only (not promoted to AC) — a process contract for the rework rounds; it governs what a *future* round does, so no state of this branch can witness it. It is recorded on the board instead, where the round that fires it must cite it. |
| 23 | Issue #180's own content is the split-off task's requirement list | info-only (not promoted to AC) — a hand-off note about work this task does not do; AC12 carries the only part that is checkable here (that nothing moved). |
| 24 | Existing emphasis-break spellings stay as they are (no sweep) | info-only (not promoted to AC) — a non-goal whose observable form is "no diff outside the allow-list", already carried by AC14; a separate criterion would only restate it. |

## Goal

<!-- BEGIN intent-block: T-1051 -->

`bin/check-pii-shapes.sh` no longer reports this repository's own kebab-case label
convention (and its siblings) as a credential token, while every real key shape it
caught before is still caught **with one deliberate, disclosed exception**: an
`sk-` key whose prefix is immediately preceded by a letter or a digit, with no
separating character, is now suppressed too. That exception is the mathematical
complement of the false-positive class issue #178 asks this task to close — one
character of left context cannot tell a label chain's `s`+`k` ending from an
unseparated real key, because the two present the identical left context — so it
is the price of the prescribed design rather than a defect in its implementation,
and rejecting it would mean rejecting #178. DP-10's prefer-firing default yields
here, and only here, because the issue's own prescription is the ratified
instruction. The residual exposure is bounded rather than open-ended: every other
boundary in the reachable set still fires (line start, space, `=`, `:`, quotes,
brackets, `-`, `.`, `/`), and the `gh` and `AKIA` alternatives, which carry no
guard at all, still fire after an alphanumeric. The exception is disclosed at all
four repaired prose sites and pinned by a criterion in both directions, so a later
edit that quietly moves the trade-off either way goes red rather than unnoticed.
`bin/check-intent.sh` classifies its two write-site
failures instead of dying unclassified, honours `--help` identically whatever the
flag order, and refuses a hash that is not 40 lowercase hex before any consumer
reads it; and all four sites of the prose claim the first fix falsifies now describe
shipped behaviour. Nothing outside those two scripts, their suites and the
`pii-controls` document pair moves, and no merged frozen intent block is re-frozen.

## Non-goals

- **No re-freeze of any merged frozen intent block** — T-111, T-1028 and T-1041 in
  particular. If a change appears to require one, the task stops and escalates
  rather than taking the route.
- **#180 is not implemented here.** None of its six surfaces (`CONTRIBUTING.md`,
  `docs/tuning-oversight.md`, `docs/tuning-oversight.ja.md`, `agents/pm-spec.md`,
  `skills/run/SKILL.md`) is edited.
- **No allowlist, no inline-allow marker, no `KNOWN_SHAPE_PATHS` entry** for the
  token pattern (T-111 AC13 + DP-1). The repair is in the pattern or nowhere.
- **No adversarial or bypass construction anywhere** — no fixture, example, record
  or spec line is written to demonstrate slipping past the token pattern. Negative
  controls are the checker's own benign lookalikes; positive controls carry
  obviously synthetic sequential-alphabet bodies.
- **No change to DP-5's home-path boundary class**, and no new `RE_*` rule: the
  checker's rule decomposition is exactly what T-111 froze.
- **No repository-wide sweep** of the emphasis-break spelling idiom. Existing
  spellings stay; they remain correct and this task does not chase them.
- **#178's process half** (running the PII check before a record's first commit as
  an ordering rule) is retro input, not a deliverable here.
- **No change to `bin/check-refreeze-class.sh`'s classification logic**, its
  documented swap blind spot, or the class-M mechanical boundary. The only edit that
  file may receive is the trap-symmetry mirror of DP5.
- **No merge**, no issue closing, and no newly-discovered issue is started inside
  this task.

## Acceptance criteria

Base ref for every `git` anchor is the literal `e57c287`. Every check runs from the
repository root, names the files it reads, asserts readability before any negative
grep, guards every `mktemp` with an immediate non-zero exit, and writes nothing
outside `$TMPDIR`. Per DP4, no check line below contains a completed matching
literal: credential-shaped and lookalike-shaped values are composed from fragments
at run time.

- [ ] **AC1** The shipped `token` regex, read out of the checker source and run as
  the real `grep -E`, has the measured behaviour DP1/DP2 specify. A lookalike whose
  `s`+`k`+hyphen run is preceded by an ASCII letter does **not** match. A key body of
  16 or more characters after the `sk-` prefix **does** match at line start, after a
  space, after a hyphen, after a dot, and after a slash — the four boundary
  characters DP-5 would have suppressed and DP-10 requires to fire. A `gh`-form
  prefix immediately preceded by a letter still matches, proving the guard was
  attached to one alternative and not to the group. The **disclosed exception** of
  the Goal is pinned here in both directions, so neither a silent widening nor a
  silent narrowing of the trade-off survives: the same `sk-` key immediately
  preceded by a letter, and again by a digit, with no separating character, does
  **not** match — asserted as a documented expectation, the accepted complement of
  #178's prescription — while the space-separated form one character away still
  does, and the suite carries the same expectation under its own verbatim label,
  written unwrapped here so it matches byte-for-byte what the check greps:
  `disclosed: alnum-adjacent zero-separator sk form is suppressed by design (#178 complement)`.
  - check: S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; RE=$(awk -F"'" '/^RE_TOKEN=/{print $2}' "$S"); test -n "$RE" || exit 1; rc=0; N1=ta; N2=sk-; N3=ABCDEFGHIJKLMNOP; P1=sk; P2=-; B1=ABCDEFGHIJ; B2=KLMNOP123456; G1=gh; G2=p_; K="${P1}${P2}${B1}${B2}"; if printf '%s\n' "see ${N1}${N2}${N3} here" | grep -qE -- "$RE"; then rc=1; fi; for pre in "" "x " "-" "." "/"; do printf '%s\n' "${pre}${K}" | grep -qE -- "$RE" || rc=1; done; for pre in "x" "9"; do if printf '%s\n' "${pre}${K}" | grep -qE -- "$RE"; then rc=1; fi; done; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; grep -qF -- 'disclosed: alnum-adjacent zero-separator sk form is suppressed by design (#178 complement)' "$T" || rc=1; printf '%s\n' "x${G1}${G2}${B1}${B2}" | grep -qE -- "$RE" || rc=1; test "$rc" -eq 0
- [ ] **AC2** The rule decomposition T-111 froze is intact. The number of top-level
  `RE_*=` assignment lines in the checker equals the base ref's — no rule added, none
  removed — `RE_TOKEN` is still exactly one such line, and `RE_HOME_PATH_BOUNDARY`'s
  line is byte-identical to the base ref, so DP-5's class is untouched and the two
  boundary classes stay deliberately different.
  - check: rc=0; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1051ac2.XXXXXX") || exit 1; git show e57c287:bin/check-pii-shapes.sh > "$D/base.sh" || rc=1; test -s "$D/base.sh" || rc=1; nn=$(grep -cE '^RE_[A-Z0-9_]+=' "$S"); nb=$(grep -cE '^RE_[A-Z0-9_]+=' "$D/base.sh"); test "$nb" -ge 5 || rc=1; test "$nn" = "$nb" || rc=1; test "$(grep -cE '^RE_TOKEN=' "$S")" = "1" || rc=1; grep -E '^RE_HOME_PATH_BOUNDARY=' "$S" > "$D/now.line"; grep -E '^RE_HOME_PATH_BOUNDARY=' "$D/base.sh" > "$D/base.line"; test -s "$D/base.line" || rc=1; cmp -s "$D/now.line" "$D/base.line" || rc=1; rm -rf "$D"; test "$rc" -eq 0
- [ ] **AC3** The suite covers the new boundary and T-111's frozen labels survive
  untouched. `tests/check-pii-shapes/run.sh` is green and carries three new verbatim
  labels — `boundary: an identifier-adjacent label lookalike does not fire (token)`,
  `boundary: a non-identifier boundary still fires (start, dot, hyphen, slash)`, and
  `positive: an unguarded prefix still fires after a letter (gh form)` — **added
  alongside**, never replacing, AC8's two frozen labels (`POS/NEG pair: token`,
  `negative: short lookalike must not fire`), which are still present verbatim, as
  are AC10's, AC13's, AC14's and AC28's.
  - check: rc=0; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; bash "$T" >/dev/null 2>&1 || rc=1; for l in 'POS/NEG pair: token' 'negative: short lookalike must not fire' 'mutation: pattern is load-bearing' 'mutation: each exclusion is load-bearing' 'no-allowlist: finding reported even for the checker own path' 'no-leak: finding output never echoes the matched text' 'boundary: only a host-name character suppresses, so the bare documentation URL stays clean' 'boundary: an identifier-adjacent label lookalike does not fire (token)' 'boundary: a non-identifier boundary still fires (start, dot, hyphen, slash)' 'positive: an unguarded prefix still fires after a letter (gh form)'; do grep -qF -- "$l" "$T" || rc=1; done; test "$rc" -eq 0
- [ ] **AC4** The new negative control is proven load-bearing rather than vacuous:
  the suite produces a copy of the checker whose `RE_TOKEN` line is rewritten to its
  pre-fix (unguarded) form, runs the new lookalike fixture against that copy, and
  requires the copy to **report** it while the shipped checker does not. The
  assertion carries the verbatim label `mutation: the token boundary is load-bearing
  (pre-fix rule reports the lookalike)`, and its fixture is composed at run time from
  fragments in the file's existing idiom — the label lookalike never appears as a
  completed literal in the suite source.
  - check: rc=0; T=tests/check-pii-shapes/run.sh; test -r "$T" || exit 1; grep -qF -- 'mutation: the token boundary is load-bearing (pre-fix rule reports the lookalike)' "$T" || rc=1; bash "$T" >/dev/null 2>&1 || rc=1; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; RE=$(awk -F"'" '/^RE_TOKEN=/{print $2}' "$S"); test -n "$RE" || exit 1; if grep -qE -- "$RE" "$T"; then rc=1; fi; P1=sk; P2=-; B1=ABCDEFGHIJ; B2=KLMNOP12; printf '%s\n' "${P1}${P2}${B1}${B2}" | grep -qE -- "$RE" || rc=1; test "$rc" -eq 0
- [ ] **AC5** All four measured sites of the falsified prose now describe shipped
  behaviour. In `bin/check-pii-shapes.sh`: the anchoring/boundary inventory's
  `RE_TOKEN` entry no longer says `Not applicable` and names the applied class
  `[^A-Za-z0-9]`, and the `token` pattern description no longer rests the negative
  case on key-body length alone. In `docs/pii-controls.md` and
  `docs/pii-controls.ja.md`: the `token` bullet differs from the base ref, while
  every line of each file **outside** that bullet is byte-identical to the base ref —
  so the repair landed exactly where the claim was and nowhere else. All four sites
  additionally **disclose the accepted complement**: that the same guard suppresses
  an `sk-` key with no separator after a letter or a digit. Each carries the
  boundary-class literal `[^A-Za-z0-9]` as its language-neutral anchor — chosen
  because these two documents cite no issue numbers anywhere (measured), so a
  `#178` reference would be foreign to them, while a regex literal already appears
  in the Japanese file's own token bullet. The anchor is a **necessary condition
  the check can read, not the whole assertion**: whether each site states the
  consequence in words is a reading judgment that stays with review.
  - check: rc=0; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1051ac5.XXXXXX") || exit 1; awk '/^#   RE_TOKEN /{f=1} f&&/^# shellcheck/{exit} f{print}' "$S" > "$D/inv.txt"; test -s "$D/inv.txt" || rc=1; if grep -qF -- 'Not applicable' "$D/inv.txt"; then rc=1; fi; grep -qF -- '[^A-Za-z0-9]' "$D/inv.txt" || rc=1; awk '/^#   token /{f=1} f&&/^#$/{exit} f{print}' "$S" > "$D/desc.txt"; test -s "$D/desc.txt" || rc=1; grep -qF -- '[^A-Za-z0-9]' "$D/desc.txt" || rc=1; BT=$(printf '\140'); pat="^- ${BT}token${BT}"; for f in docs/pii-controls.md docs/pii-controls.ja.md; do test -r "$f" || exit 1; b="$D/$(basename "$f").base"; git show "e57c287:$f" > "$b" || rc=1; test -s "$b" || rc=1; awk -v p="$pat" '$0 ~ p {f=1; print; next} f && /^- / {exit} f {print}' "$f" > "$D/reg.now"; awk -v p="$pat" '$0 ~ p {f=1; print; next} f && /^- / {exit} f {print}' "$b" > "$D/reg.base"; test -s "$D/reg.base" || rc=1; if cmp -s "$D/reg.now" "$D/reg.base"; then rc=1; fi; grep -qF -- '[^A-Za-z0-9]' "$D/reg.now" || rc=1; awk -v p="$pat" '$0 ~ p {f=1; next} f && /^- / {f=0} !f {print}' "$f" > "$D/out.now"; awk -v p="$pat" '$0 ~ p {f=1; next} f && /^- / {f=0} !f {print}' "$b" > "$D/out.base"; cmp -s "$D/out.now" "$D/out.base" || rc=1; done; rm -rf "$D"; test "$rc" -eq 0
- [ ] **AC6** The #178 oracle, in the shape the pre-fix step-0 measurement fixed:
  the checker is clean in **both** modes after the change — change-scoped against
  `develop` and against this task's own base ref, and full-tree under `--all` — which
  also proves every file this task writes is itself clean, since `--all` reads the
  working tree and the change-scoped run reads this branch's committed paths.
  - check: rc=0; test -r bin/check-pii-shapes.sh || exit 1; bash bin/check-pii-shapes.sh --base develop >/dev/null || rc=1; bash bin/check-pii-shapes.sh --base e57c287 >/dev/null || rc=1; bash bin/check-pii-shapes.sh --all >/dev/null || rc=1; test "$rc" -eq 0
- [ ] **AC7** T-111's frozen intent is neither edited nor perturbed: its spec file is
  byte-identical to the base ref, its board ledger still reports `aligned`, and the
  ten whole-line-exact limits AC18/AC19 pin are untouched — the canonical section of
  each `pii-controls` file is byte-identical to the base ref, checked section by
  section rather than inferred from a whole-file diff.
  - check: rc=0; B=$(bash bin/team-paths.sh --get todo) || exit 1; test -r "$B" || exit 1; test -z "$(git diff --name-only e57c287...HEAD -- .shell-team/specs/T-111-pii-shape-checker.md)" || rc=1; bash bin/check-intent.sh .shell-team/specs/T-111-pii-shape-checker.md "$B" >/dev/null || rc=1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1051ac7.XXXXXX") || exit 1; sec(){ awk -v h="$2" '$0==h{f=1;next} f&&/^## /{exit} f{print}' "$1"; }; for pair in "docs/pii-controls.md|## What this gate does not cover" "docs/pii-controls.ja.md|## このゲートが扱わないもの"; do f=${pair%%|*}; h=${pair#*|}; test -r "$f" || exit 1; git show "e57c287:$f" > "$D/base" || rc=1; sec "$f" "$h" > "$D/now.sec"; sec "$D/base" "$h" > "$D/base.sec"; test -s "$D/base.sec" || rc=1; cmp -s "$D/now.sec" "$D/base.sec" || rc=1; done; rm -rf "$D"; test "$rc" -eq 0
- [ ] **AC8** `#179(a)`'s symmetry cell holds and the errexit contract is green: the
  set of signals `bin/check-intent.sh` installs an `on_signal` trap for is **equal**
  to the set `bin/check-refreeze-class.sh` installs, whichever route the write-site
  repair took — a trap added to one and not to its byte-parallel sibling is the
  asymmetry this criterion exists to catch — and `tests/errexit-safe/run.sh` is
  green. A site the engineer measures as already classified pre-fix receives no
  trap; that measurement is reported under AC17 rather than repaired cosmetically,
  and this criterion stays green either way because the base sets are already equal.
  - check: rc=0; C=bin/check-intent.sh; R=bin/check-refreeze-class.sh; for f in "$C" "$R"; do test -r "$f" || exit 1; done; D=$(mktemp -d "${TMPDIR:-/tmp}/t1051ac8.XXXXXX") || exit 1; sigs(){ grep -oE "^[[:space:]]*trap '[^']*' [A-Z ]+$" "$1" | sed -E "s/^[[:space:]]*trap '[^']*' //" | tr ' ' '\n' | grep -v '^$' | sort -u; }; sigs "$C" > "$D/c"; sigs "$R" > "$D/r"; test -s "$D/c" || rc=1; grep -qxF HUP "$D/c" || rc=1; cmp -s "$D/c" "$D/r" || rc=1; bash tests/errexit-safe/run.sh >/dev/null 2>&1 || rc=1; rm -rf "$D"; test "$rc" -eq 0
- [ ] **AC9** `#179(b)`: `--help` wins whatever the flag order. `--print-hash --help`
  and `--help --print-hash` both exit **0**, both print the script's own help text,
  neither prints a 40-hex value, and the two outputs are byte-identical to each
  other. Both orderings are pinned by fixtures in `tests/check-intent/run.sh` under
  the verbatim case ids `help-wins-before-print-hash` and
  `help-wins-after-print-hash` — the file's own bare kebab-case label convention,
  measured at `tests/check-intent/run.sh:1268`, not a prefix imported from another
  suite — each present in the suite source **and** in the suite's own output, so a
  case that was deleted or silently skipped fails here.
  - check: rc=0; C=bin/check-intent.sh; T=tests/check-intent/run.sh; test -r "$C" || exit 1; test -r "$T" || exit 1; o1=$(bash "$C" --print-hash --help 2>&1); s1=$?; o2=$(bash "$C" --help --print-hash 2>&1); s2=$?; test "$s1" -eq 0 || rc=1; test "$s2" -eq 0 || rc=1; test "$o1" = "$o2" || rc=1; printf '%s\n' "$o1" | grep -qF -- 'check-intent.sh' || rc=1; if printf '%s\n' "$o1" | grep -qE -- '^[0-9a-f]{40}$'; then rc=1; fi; out=$(bash "$T" 2>&1) || rc=1; for id in help-wins-before-print-hash help-wins-after-print-hash; do grep -qF -- "$id" "$T" || rc=1; printf '%s\n' "$out" | grep -qF -- "$id" || rc=1; done; test "$rc" -eq 0
- [ ] **AC10** `#179(c)`: the computed hash is shape-gated before any consumer reads
  it. A `[0-9a-f]{40}` shape assertion — the same anchor
  `bin/check-refreeze-class.sh`'s `HEX40_RE` already uses — occurs in
  `bin/check-intent.sh` at a line after the `computed_hash` assignment and before the
  print-mode branch, the file carries strictly more occurrences of that shape literal
  than the base ref did (so the gate is new rather than the pre-existing board
  grammar being miscounted), and the gate fails closed with a classified exit rather
  than a bare non-zero. Print mode still prints a conformant hash for a real spec —
  this spec — proving the gate admits the true value it guards.
  - check: rc=0; C=bin/check-intent.sh; SP=.shell-team/specs/T-1051-inspection-ux-polish.md; test -r "$C" || exit 1; test -r "$SP" || exit 1; D=$(mktemp -d "${TMPDIR:-/tmp}/t1051ac10.XXXXXX") || exit 1; git show e57c287:bin/check-intent.sh > "$D/base.sh" || rc=1; test -s "$D/base.sh" || rc=1; la=$(grep -nF -- 'computed_hash="$(git hash-object' "$C" | head -1 | cut -d: -f1); lp=$(grep -nF -- 'if [ "$PRINT_HASH" -eq 1 ]' "$C" | head -1 | cut -d: -f1); test -n "$la" || rc=1; test -n "$lp" || rc=1; if [ -n "$la" ] && [ -n "$lp" ]; then n=$(grep -nF -- '[0-9a-f]{40}' "$C" | awk -F: -v a="$la" -v p="$lp" '$1>a && $1<p {c++} END{print c+0}'); test "$n" -ge 1 || rc=1; fi; fn=$(grep -cF -- '[0-9a-f]{40}' "$C"); fb=$(grep -cF -- '[0-9a-f]{40}' "$D/base.sh"); test "$fn" -gt "$fb" || rc=1; h=$(bash "$C" --print-hash "$SP" 2>/dev/null) || rc=1; printf '%s\n' "$h" | grep -qE -- '^[0-9a-f]{40}$' || rc=1; rm -rf "$D"; test "$rc" -eq 0
- [ ] **AC11** No merged frozen intent block moved. The spec files of T-111, T-1028
  and T-1041 are byte-identical to the base ref, and each still reports `aligned`
  against the live board — so this task caused no drift, took no class-M path, and
  needed no ratification. T-111's `aligned` verdict is the specific one the step-0
  measurement pinned before any edit, which is what makes a later `drift-detected`
  attributable to this task and nothing else.
  - check: rc=0; B=$(bash bin/team-paths.sh --get todo) || exit 1; test -r "$B" || exit 1; test -z "$(git diff --name-only e57c287...HEAD -- .shell-team/specs/T-111-pii-shape-checker.md .shell-team/specs/T-1028-class-m-refreeze.md .shell-team/specs/T-1041-freeze-ux.md)" || rc=1; for s in T-111-pii-shape-checker T-1028-class-m-refreeze T-1041-freeze-ux; do test -r ".shell-team/specs/$s.md" || rc=1; bash bin/check-intent.sh ".shell-team/specs/$s.md" "$B" >/dev/null || rc=1; done; test "$rc" -eq 0
- [ ] **AC12** The #180 split is real and locked: not one byte differs from the base
  ref at any of the five English surfaces or the Japanese mirror that carry the
  class-M re-freeze grammar's normative text. **This criterion is merge-point-scoped
  and expected to go stale after merge**; do not widen its base-ref resolution and do
  not re-derive it per rework round.
  - check: test -z "$(git diff --name-only e57c287...HEAD -- CONTRIBUTING.md docs/tuning-oversight.md docs/tuning-oversight.ja.md agents/pm-spec.md skills/run/SKILL.md)"
- [ ] **AC13** The repository's shell contract holds for everything this task
  touches: every script it may edit is shellcheck-clean at the pinned version, and
  the suites that exercise the two changed checkers and their neighbours are green —
  `check-pii-shapes`, `check-intent`, `check-refreeze-class`, `errexit-safe`,
  `rollup-track` (whose `secret-openai.jsonl` fixture is guarded by name through
  `KNOWN_SHAPE_PATHS`, the one place the token pattern and another guard's fixtures
  meet), `bin-exec-bit`, and `machine-tokens`.
  - check: rc=0; for s in bin/check-pii-shapes.sh bin/check-intent.sh bin/check-refreeze-class.sh; do test -r "$s" || exit 1; shellcheck "$s" || rc=1; done; for t in tests/check-pii-shapes/run.sh tests/check-intent/run.sh tests/check-refreeze-class/run.sh tests/errexit-safe/run.sh tests/rollup-track/run.sh tests/bin-exec-bit/run.sh tests/machine-tokens/run.sh; do test -r "$t" || exit 1; bash "$t" >/dev/null 2>&1 || rc=1; done; test "$rc" -eq 0
- [ ] **AC14** Scope lock: the branch's changed-and-added file set — tracked changes
  in the commit range **union** untracked additions, since this spec and the records
  are untracked at freeze time — contains the required deliverables and **nothing**
  outside the allow-list in Notes for engineer. **This criterion is merge-point-scoped
  and expected to go stale after merge**; do not widen its base-ref resolution and do
  not re-derive it per rework round.
  - check: rc=0; changed=$( { git diff --name-only e57c287...HEAD; git ls-files --others --exclude-standard; } | sort -u ); test -n "$changed" || rc=1; for f in bin/check-pii-shapes.sh bin/check-intent.sh tests/check-pii-shapes/run.sh tests/check-intent/run.sh docs/pii-controls.md docs/pii-controls.ja.md .shell-team/specs/T-1051-inspection-ux-polish.md .shell-team/todo.md; do printf '%s\n' "$changed" | grep -qxF -- "$f" || rc=1; done; extra=$(printf '%s\n' "$changed" | grep -v '^\.shell-team/reviews/T-1051' | grep -vxF -e 'bin/check-pii-shapes.sh' -e 'bin/check-intent.sh' -e 'bin/check-refreeze-class.sh' -e 'tests/check-pii-shapes/run.sh' -e 'tests/check-intent/run.sh' -e 'tests/check-refreeze-class/run.sh' -e 'docs/pii-controls.md' -e 'docs/pii-controls.ja.md' -e '.shell-team/specs/T-1051-inspection-ux-polish.md' -e '.shell-team/todo.md' -e '.shell-team/provenance/T-1051.md' -e '.shell-team/interventions/T-1051.md' -e '.shell-team/test-recipe.md' | grep -c . || true); test "$extra" = "0" || rc=1; test "$rc" -eq 0
- [ ] **AC15** Records exist, are conformant, and carry no completed matching
  literal: `.shell-team/provenance/T-1051.md` passes `bin/check-provenance.sh`, and
  neither this spec nor any record this task writes contains a line the shipped
  `token` regex matches — measured with that live regex, alongside a positive control
  proving the regex is the real one and not an empty string.
  - check: rc=0; S=bin/check-pii-shapes.sh; test -r "$S" || exit 1; RE=$(awk -F"'" '/^RE_TOKEN=/{print $2}' "$S"); test -n "$RE" || exit 1; P1=sk; P2=-; B1=ABCDEFGHIJ; B2=KLMNOP12; printf '%s\n' "${P1}${P2}${B1}${B2}" | grep -qE -- "$RE" || rc=1; for f in .shell-team/specs/T-1051-inspection-ux-polish.md .shell-team/provenance/T-1051.md; do test -r "$f" || rc=1; if [ -r "$f" ] && grep -qE -- "$RE" "$f"; then rc=1; fi; done; if [ -r .shell-team/provenance/T-1051.md ]; then bash bin/check-provenance.sh .shell-team/provenance/T-1051.md >/dev/null || rc=1; else rc=1; fi; test "$rc" -eq 0
- [ ] **AC16** Board hygiene: this task's entry is a **pure insertion** — the board's
  deletion column against the base ref is 0, read from `git diff --numstat` rather
  than from a `^-[^-]` count, which is vacuous in a file whose entry lines all begin
  with a hyphen — and the board passes both linters. **This criterion is
  merge-point-scoped and expected to go stale after merge.**
  - check: rc=0; B=$(bash bin/team-paths.sh --get todo) || exit 1; test -r "$B" || exit 1; bash bin/check-handoff.sh "$B" >/dev/null || rc=1; bash bin/check-board-headings.sh "$B" --base e57c287 >/dev/null || rc=1; del=$(git diff --numstat e57c287...HEAD -- "$B" | awk '{print $2}'); test -n "$del" || rc=1; test "$del" = "0" || rc=1; test "$rc" -eq 0
- [ ] **AC17** Runtime, `SKIP` by design — no command can prove a command was run.
  All four parts are reported in the board hand-off. **(a)** A producer-run mutation
  self-check on scratch copies outside the checkout, each mutation observed red,
  restored, observed green again, covering at least: reverting `RE_TOKEN` to its
  pre-fix form (AC1 and AC4 red); widening the token guard to DP-5's class so a key
  after a dot or hyphen stops firing (AC1 red); attaching the guard to the whole
  alternation group so the `gh` form after a letter stops firing (AC1 red); adding a
  tenth `RE_*` assignment line (AC2 red); and removing the hash shape gate (AC10
  red). **(b)** For each of the two `#179(a)` write sites, the live demonstration
  that decided its route: the pre-fix exit code and whether it was classified, the
  post-fix exit code, and — where a site was measured already-classified — the
  evidence, with no trap added for it. **(c)** The CI-wired step list run locally in
  workflow order, each step declared inapplicable named individually with its reason.
  **(d)** `bin/check-pii-shapes.sh` was run against every newly written record
  **before** that record's first commit, and the result reported per record.

## Input space

**Reachable input classes** — what the two changed checkers really read in this
repository, and must handle correctly:

1. Markdown prose and shell source containing kebab-case identifier chains, in
   English and Japanese, including chains whose segment ends in the letters `s`+`k`
   immediately before a hyphen (this repository's own label convention, hyphenated
   file names, chained flag names) followed by 16 or more `[A-Za-z0-9_-]` characters.
2. Real credential-token shapes at every separated boundary that occurs in this
   tree — line start, after a space, after `=`, `:`, `"`, `'`, `(`, `-`, `.`, `/` —
   all of which must fire, for all three alternatives. The alphanumeric-adjacent
   zero-separator boundary splits by alternative and is stated precisely rather
   than left general: a `gh` or `AKIA` form immediately preceded by a letter or a
   digit **must still fire**, since neither alternative carries a guard; the same
   position for an `sk-` form is the **disclosed suppressed case** the Goal names —
   reachable, deliberately not protected, and pinned as a documented expectation by
   AC1 rather than treated as a defect to be reported.
3. The four documented placeholder identity forms, and the existing emphasis-break
   spellings already committed in `.shell-team/test-recipe.md` and elsewhere.
4. `bin/check-intent.sh` invoked with `--print-hash` and `--help` in either order,
   with and without positional arguments, from the repository root and with `bin/`
   on `PATH`.
5. A 40-lowercase-hex object name as produced by `git hash-object --stdin` on a
   normalized intent-block region.
6. Spec, board, provenance, review and interventions files this task writes, read
   back by the PII checker in both of its modes.

**Out-of-scope synthetic extremes** — inputs this spec explicitly declines to
protect, so a gate escalating them has a stated boundary to push back against:

1. **Any adversarial or bypass construction**, of any shape: a payload designed to
   slip a real credential past the token pattern, a hostile-operator fixture, an
   input constructed to make a redaction or a record misleading. None is written,
   reviewed, or accepted as a finding's grounds. A review item asking for one is
   refused with this line as the reason.
2. Ever-longer or ever-shorter key bodies, non-ASCII or full-width lookalikes of the
   `s`+`k` letters, homoglyph prefixes, and key bodies containing characters outside
   `[A-Za-z0-9_-]` — the pattern's own alphabet has been fixed since T-111 and this
   task does not reopen it.
3. Credential prefixes other than the three the pattern already carries. Adding a
   fourth is a different task.
4. Signals other than the two write-site failure classes `#179(a)` names, and any
   signal delivered to a subprocess rather than to the shell itself.
5. A `git hash-object` invocation that returns a non-hex value: the shape gate is
   defence-in-depth against a future edit, not against real `git`, and no fixture
   manufactures one by patching or shimming `git`. The gate's behaviour is proven by
   mutation (AC17a), never by faking its input.
6. Board or spec files whose grammar is malformed in ways `bin/check-handoff.sh` and
   `bin/check-intent.sh` already classify — this task adds no new parsing.

<!-- END intent-block: T-1051 -->

## Assumptions

- **RELAYED — issues #178, #179 and #180.** Their full substance reached this role
  through the tech-lead's Routing Map and the task prompt; pm-spec has no network or
  `gh` access and opened none of them. The coordinating session holds the primary
  confirmation (read live 2026-08-09: all three open, targeting `develop`). The
  freeze run re-measures that they are open and that the scope written here matches
  their bodies, and reports the values beside this line. In particular, **#180's two
  norm-halves** (a: redaction form; b: the `contradictory` trigger's definition) are
  relayed labels, not text this role read — which is a further reason the split
  above is the safer disposition.
- **RELAYED — base ref and ancestry.** `e57c287` is HEAD of
  `feature/1051-inspection-ux-polish` and the T-1050 tip, with `develop` (`99d4038`)
  an ancestor. Sixteen criteria resolve that literal; the freeze run confirms both
  the identity and the ancestry (`git merge-base --is-ancestor develop HEAD`) rather
  than only that the ref exists.
- **RELAYED — the step-0 PII oracle.** `--base develop` and `--all` were both
  measured clean pre-fix by the orchestrator. AC6 is written as "still clean" on that
  basis; if the freeze run finds either mode already red at base, that is a
  disclosed pre-existing red, not this task's defect, and AC6's verdict is recorded
  against the measured baseline.
- All suites named in AC13 are assumed green at the base ref. Any pre-existing red is
  disclosed at the freeze gate and attributed to its own task, never absorbed here.
- The engineer's `shellcheck` is the CI-pinned version. AC13 asserts cleanliness, not
  which binary produced it; the version is confirmed before the claim is trusted.

## Open questions

None blocking. The one open design decision the Routing Map raised (row 3 — guard the
`sk-` alternative alone, or the whole group) is decided in DP1 with the rejected
side's reason recorded, and the one open measurement it raised (row 6 — does AC10's
check assert the nine-rule count) is answered in the ledger: it does not, which is
exactly why DP2 avoids a tenth rule rather than relying on a machine gate to notice.

## Notes for engineer

**Order of work, one commit per item so any can be dropped alone under DP6's
disposition**: #178 (pattern, suite, four prose sites) → #179(a) → #179(b) →
#179(c) → records.

**Files likely touched (this is AC14's allow-list):** `bin/check-pii-shapes.sh`,
`bin/check-intent.sh`, `bin/check-refreeze-class.sh` (trap mirror only),
`tests/check-pii-shapes/run.sh`, `tests/check-intent/run.sh`,
`tests/check-refreeze-class/run.sh` (only if the mirror needs a case),
`docs/pii-controls.md`, `docs/pii-controls.ja.md`, this spec, `.shell-team/todo.md`,
`.shell-team/provenance/T-1051.md`, `.shell-team/reviews/T-1051*`,
`.shell-team/interventions/T-1051.md`, `.shell-team/test-recipe.md`.

**Gotchas, each measured:**

1. **The rule count is prose-only.** T-111's AC10 says "nine" in frozen prose and its
   `check:` line never counts. A tenth `RE_*` assignment would pass every machine
   gate and silently falsify a merged frozen block. AC2 is the substitute gate.
2. **`tests/check-pii-shapes/run.sh:36` and `:24` and `:447-450` are comments that
   repeat the falsified claim.** They are inside the allow-list and should be
   corrected with the four prose sites; AC5's machine half reads the checker and the
   docs pair, so the suite comments are on you.
3. **The two boundary classes must stay different.** A future reader will be tempted
   to "unify" `RE_HOME_PATH_BOUNDARY` and the token guard. Say why they differ, in
   the inventory entry, at the point of the difference.
4. **`report_pattern_lines` discards grep's match text**, so a consuming group in the
   token regex cannot leak into a finding line (T-111 AC14 stays satisfied
   structurally, not by care).
5. **`#179(a)`: measure before you trap.** A failure inside a *pipeline stage* is
   already visible to `pipefail` and does reach the `||`; the unclassified case is a
   signal delivered to the shell's own builtin write. Demonstrate each site live and
   let the measurement decide the route (DP5). If the trap route turns out to
   contradict T-1041's frozen D3 prose on measurement, **stop and escalate** — do not
   re-freeze.
6. **Mirror or declare.** `bin/check-refreeze-class.sh:137-139` and `:170-175` are
   byte-parallel with `bin/check-intent.sh:202-204` and `:325-330`. AC8 compares the
   two signal sets; keep `block_signals_for_registration` and `restore_signal_traps`
   internally consistent with whatever you install, or the restore path silently
   drops a trap after the mktemp window.
7. **Measured-at-ref command check: not applicable** — none of this task's
   deliverables prints a command beside a label naming the git ref its result was
   measured at. The `git show e57c287:<path>` forms inside the criteria above are
   themselves committed-blob reads, not working-tree reads, and are the only
   ref-labelled measurements this task ships.
8. **The v3 disclosure has two extraction boundaries AC5 depends on.** The
   inventory entry is read from `^#   RE_TOKEN ` to the next `^# shellcheck`, and
   the header's `token` description from `^#   token ` to the next bare `^#$`.
   Both are the file's own existing comment grammar — keep the block markers where
   they are when you add the disclosure sentence, or the extraction goes empty and
   AC5 reds on a `test -s` that has nothing to do with your wording. The fourth and
   first sites are the two document bullets, extracted by the same `token` bullet
   boundary AC5 already used at v2.
9. **The fixture self-reference contract (DP4) applies to your records too.** Compose
   every shape from fragments; run `bin/check-pii-shapes.sh` against each new record
   **before** its first commit (AC17d) rather than trusting the CI diff-time check.

**Prior art**: T-1028's AC12/AC15 for scope-lock and section-extraction idioms;
T-111's AC10/AC11 for the neutralised-copy mutation harness; `HEX40_RE` at
`bin/check-refreeze-class.sh:178` for the shape gate.

**Task classification**: this **is** verification-mechanism work — it edits a
detector's own pattern and a checker's argument, signal and validation handling — so
review runs at the higher standard, and DP6's pre-commitment is live from round 1.
**17 criteria, 16 `check:` lines.**
