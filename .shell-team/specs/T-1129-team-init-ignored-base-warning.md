# `team-init` warns when the resolved base dir is git-ignored — BLOCKED before freeze

**Status**: BLOCKED
**Owner**: pm-spec
**Task ID**: T-1129
**Entry mode**: pm-authored
**Spec review**: none

> **No intent block is present in this file, deliberately.** Freezing an intent
> block records what the loop intends to build. This task's proposed deliverable
> is forbidden by the Non-goals of a **merged, frozen** spec in this repository
> (`.shell-team/specs/T-1046-ignored-base-verdict.md`) and turns one of that
> spec's own live-tree acceptance criteria red **by construction**. Recording
> that intent as frozen would commit the loop to something it is not authorized
> to hold. The markers go in when — and only when — a disposition below is
> chosen. `bin/check-intent.sh` and `bin/check-acs.sh` are therefore not
> runnable against this file yet; that is the intended pre-freeze state, not a
> defect.

## Problem

GitHub issue #452 reports a real, reproduced adopter trap: on a machine whose
`core.excludesFile` carries a `.shell-team/` line, `team-init` succeeds while the
base dir is invisible to git — the board, specs, interventions and loop contract
never reach `git status`, and every tracked-state gate in the loop reads nothing.
`docs/adopting.md` (*Where the operating files live*, lines 41–52) already
documents the trap and its one-line re-include; the issue's complaint is
**ordering** — the documentation is read after the symptom, and the symptom is
indirect. Its proposal: at the end of `team-init`, ask git whether the base dir
is ignored and print one warning line — a warning, not a gate.

That problem statement is sound. The **proposed answer** is the one this
repository has already tried twice, across two tasks, and terminally closed.

## Summarized sources

- **`.shell-team/specs/T-1046-ignored-base-verdict.md` — read first-hand, in full (267 lines).** The distinctions carried over below are the ones that file itself draws: that its frozen Goal asserts a zero-occurrence invariant for the token `check-ignore` across `bin/` and `.github/`; that its Non-goals forbid reviving *any* mechanism for asking git this question inside the plugin; that its Input space names **a `team-init` prompt** verbatim as an out-of-scope third design; that **AC4** is deliberately a live-tree zero-invariant carrying no staleness trigger, because "a later file introducing one of these tokens is exactly the event it exists to make red"; that six defeat vectors are recorded, each live-reproduced by at least two parties; and that its `## Same-class-2 pre-commitment` routes any further attempt to "#167's own record … and a future planning cycle's decision about whether to spend more on it."
- **`.shell-team/specs/T-1042-ignored-base-and-retro-ledger.md`:181 — read first-hand at the cited row.** Carried over: the predecessor task's own directive was "No warning, notice, probe or ignore-status classification ships in this task, on any script". Its force is task-scoped rather than forward-binding, which is why T-1046 and not T-1042 is the blocking document.
- **`.shell-team/specs/T-1097-trial-branch-flag.md`:88–111 — read first-hand at **AC9**–**AC16**.** Carried over: **AC13**'s exact shape, which is a *conditional* rather than an absence — the trial section of `docs/adopting.md` must carry **at least one** line containing both `no git command` and `--trial-branch`, and **no** line containing `no git command` without it. So the claim-site repair this task would need is a re-scoping, never a deletion; deleting the phrase reddens **AC13** as surely as leaving it unqualified does.
- **`bin/team-init.sh` — read first-hand, end to end (393 lines).** Carried over: the no-flag path invokes zero git commands; the `--trial-branch` path's git calls at `:235`–`:268` are each `git -C "$TARGET"` under `env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE`; `log_warn` writes to stderr; the ignore check the issue proposes would have to run after the scaffold, because a trailing-slash pattern only matches a path that exists as a directory.
- **`tests/team-init/run.sh`:581–601 — read first-hand.** Carried over: the "T-1097 git-free" arm asserts `[ ! -e "$GF/marker" ]` with a failing `git` shim first on `PATH`, i.e. it mechanically asserts the no-flag path reaches git **zero** times, and its `PASS` string states that property in words.
- **`docs/adopting.md`:35–61 and `:391`–`:404`, and `docs/adopting.ja.md`:36–65 and `:402`–`:417` — read first-hand.** Carried over: the trap and its remedy are already documented in both languages; `docs/adopting.md`:54–59 (mirror at `.ja.md`:58–63) is the standing instruction that any assertion about ignore behaviour must pin `core.excludesFile` explicitly rather than inherit the operator's; and `docs/adopting.ja.md`:415 **does** carry the mirror of `docs/adopting.md`:402's now-would-be-false claim — see `## Measurements`.
- **`templates/shell-team.gitignore` — read first-hand (8 lines).** Carried over: the scaffolded `<base>/.gitignore` ignores `runs/` and `reviews/.codex-capture.*`, and nothing else. So a descendant of the base dir is ignored **by design** in every default scaffold, which is the fact issue #452's arm (c) is built on.
- **GitHub issue #452 — body relayed verbatim into this role in the task dispatch, not opened by this role.** Carried over: the failure narrative, the "warning, not a gate" scoping, the four-arm acceptance sketch, the fail-closed requirement, and the PATCH tier. Its body names no prior work on this question.
- **GitHub issue #167 — RELAYED as still open and unanswered, from T-1046's own frozen text and board record; not opened by this role** (no readable tracker path from here). Carried over: it is the tracker item this question belongs to, left open deliberately with two review records named as its evidence.

## The blocking conflict, as measured

**1. A merged frozen Non-goal forbids the deliverable.**
`.shell-team/specs/T-1046-ignored-base-verdict.md`:131, inside that spec's frozen
intent block:

> **No revival of any mechanism for asking git this question inside the plugin.**
> Dispositions (a) and (c) are ruled and spent; an opt-in
> `bin/check-ignored-base.sh` is explicitly not built; both pre-commitments
> forbid presenting the menu again.

and its frozen `## Input space`, out-of-scope, at `:185`, which names this
task's shape in so many words:

> **Any third design for answering #167** — an opt-in checker, a per-loop-step
> notice, a README line, **a `team-init` prompt**.

**2. A merged frozen criterion goes red by construction, and it is not the
merge-point-scoped kind that is *supposed* to.** T-1046 **AC4** (`:151`–`:152`)
requires `grep -rlF -- 'check-ignore' bin .github` to name **zero** files, and
its own body forecloses the reading that this is acceptable drift:

> This is a zero-invariant re-derived over the live tree rather than a declared
> population size, so it needs no re-measurement trigger — a later file
> introducing one of these tokens is exactly the event it exists to make red.

T-1046's frozen **Goal** sentence (`:115`) states the same invariant directly.
Measured now, at this branch: `check-ignore` occurs in **zero** files under
`bin/`, so **AC4** is green today and this task is the event that reddens it.

**3. The proposed design's own acceptance sketch is defeated by a recorded,
thrice-reproduced defect — and this is the substantive objection, independent of
governance.** T-1046 `:105`, defeat vector 6:

> **A directory-form query blind to name- and extension-scoped ignore rules.**
> … With `.shell-team/*.md`, or an ordinary repo-wide `*.md`, that query stays
> silent while every record the loop writes is genuinely ignored and
> `git add .shell-team/todo.md` stages zero files — **#167's own failure
> occurring while the prescribed self-check reports an all-clear**, and every
> record the loop writes is markdown.

Reproduced independently three times on `git 2.53.0` (the primary Codex pass, the
adversarial pass with its own positive control, and the coordinating session).
Issue #452's acceptance sketch has **no arm** for this class, and the routing
map's arm (c) elevates the very rule that produces it — "the query asks about the
base dir itself, never a descendant" — to frozen intended behaviour. So as
sketched, the new warning would print nothing in a real, reproduced instance of
exactly the trap it exists to catch: a false all-clear, shipped.

**4. Vectors 1–4 are partially, but only partially, neutralized by the "warning,
not a gate" framing — and that difference is real and is why this is a planning
question rather than a flat refusal.** T-1046 `:97`–`:100` records four
verdict-flipping channels (`GIT_CONFIG_COUNT`/`KEY_n`/`VALUE_n`,
`GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_GLOBAL`/`SYSTEM`, `GIT_DIR`+`GIT_WORK_TREE`
redirection, `XDG_CONFIG_HOME`, an exported shell function named `env` or `git`,
and system-scope `$(prefix)/etc/gitconfig`). Those killed a design whose output
was a **verdict** other logic relied on. An advisory line that never changes exit
status has materially lower stakes, and #452's framing is a genuine improvement
over both earlier attempts. Vector 6 is untouched by that improvement: a false
all-clear is a false all-clear whether it is advisory or gating.

## Why this cannot be routed around from inside this task

- **Satisfying **AC4**'s letter by avoiding the literal token is off the table.**
  `git status --porcelain --ignored`, `git add --dry-run` or `git ls-files
  --ignored` would keep the string `check-ignore` out of `bin/` while shipping
  exactly the mechanism the Non-goal names. That is gaming a criterion against
  its plainly stated intent, and T-1046's Input space closes the loophole by
  naming the *shape* ("a `team-init` prompt") rather than a token. Recorded here
  so nobody spends a round discovering it.
- **Amending T-1046 is a class-B re-freeze of merged frozen intent.** Rewriting
  a merged spec's Goal, Non-goals or a criterion needs human GO plus an
  `- intent-ratified` record under the freeze procedure — and this checkout's own
  standing ruling (`CLAUDE.local.md`, 2026-08-04) delegates *freezing* to the
  coordinating session, never *amending another task's already-ratified frozen
  intent*. It is not mine to do and not the engineer's.
- **T-1046 already named the legitimate route, and it is not this task.**
  `:235`: "The correct home for any further attempt is **#167's own record** …
  and a future planning cycle's decision about whether to spend more on it." A
  planning decision **can** authorize a third attempt. This sprint's planning
  approval, though, derived T-1129's PATCH row from issue #452's body — which
  names no prior work — so the operator approved this item without #167,
  T-1042, T-1046 or the six defeat vectors in view. The approval's premise is
  incomplete rather than the approval being wrong, which under this checkout's
  own rule (premise break ⇒ approval lapse) is a stop-and-report, not a
  proceed-and-disclose.
- **The base rate is on the record, quoted rather than aggregated by this role.**
  T-1046 `:91` states, of that task alone and before its own v5 re-freeze: "four
  freezes (v1–v4)", "three cross-provider rounds", "four QA rounds" and "two full
  implementations of a mechanism plus one of a documentation deliverable"; and of
  its predecessor T-1042: "two further cross-provider rounds and seven Majors on
  the same question". Both shipped no behaviour. A third attempt priced as a
  PATCH wording-tier item, under a sprint mode that runs one freeze and no
  per-task sweep, is mispriced by a wide margin.

## Measurements this role took (relayed premises re-measured)

| Premise as relayed | Measured | Verdict |
|---|---|---|
| `bin/team-init.sh` invokes zero git commands on the no-flag path | Read end to end; the only git calls are `:235`–`:268`, inside `if [ "$TRIAL_BRANCH_GIVEN" -eq 1 ]` | confirmed |
| `tests/team-init/run.sh`:581–601 asserts it with a failing `git` shim | Read; `[ ! -e "$GF/marker" ]` at `:592`, `PASS` text at `:601` | confirmed |
| 5 prose sites become false | **6 sites.** The relayed grep used English-only patterns over 3 files, so it could not see the Japanese mirror — as the routing map itself anticipated | corrected |
| `docs/adopting.ja.md` carries no such claim (English patterns returned nothing) | **False.** `:415` carries 「`--trial-branch` を指定しない場合、`team-init.sh` は自身で git コマンドを一切実行せず、どのブランチにいるかも気にしません。」 — the exact mirror of `docs/adopting.md`:402 | corrected |
| `docs/adopting.md`:404 is a second trap-teaching site; decide in or out | **Out**, with reason: its claim is about what `git add` does, and stays true after any disposition below. Its mirror is `docs/adopting.ja.md`:417 | decided |
| A tracked base dir is "by definition not hidden", and `git check-ignore` returning non-zero there is the correct no-warning outcome | **Not confirmed, and not freezable as stated.** `git check-ignore` skips paths *in the index*; a base **directory** is never itself an index entry, so whether it reports ignored while its contents are tracked is a live measurement nobody in this chain has taken. It must be measured, not assumed, by whichever disposition proceeds | unverified — flagged |
| `check-ignore` occurs zero times under `bin/` today (T-1046 **AC4** green) | Content search over `bin/`: no matches | confirmed |

The six claim sites, for whichever disposition proceeds:
`bin/team-init.sh`:28–29, `:31`–`32`, `:115` (`--help`); `docs/adopting.md`:402;
`docs/adopting.ja.md`:415; `tests/team-init/run.sh`:592 (the assertion) and
`:601` (its `PASS` text).

- count: no-git-claim-lines — 5 — command: cd "$(git rev-parse --show-toplevel)" || exit 3; for f in bin/team-init.sh docs/adopting.md docs/adopting.ja.md tests/team-init/run.sh; do test -r "$f" || exit 3; done; git grep -n -F -e 'no git command' -e 'git コマンドを一切実行せず' -- bin/team-init.sh docs/adopting.md docs/adopting.ja.md tests/team-init/run.sh | wc -l | tr -d ' '

That command returns 5 **lines**; the sixth site (`bin/team-init.sh`:31–32,
"plus, only when `--trial-branch` is given, git.") states the same claim in
different words and is matched by neither pattern. Re-run the command rather
than quoting either number.

## Candidate dispositions

Each option's content is stated, not just its label. Choosing among them is a
planning decision, not this role's.

**A — Return T-1129 to planning; leave #452 open, cross-referenced to #167.**
*Content*: no shipped change. T-1129 closes as BLOCKED; #452 is annotated with
`.shell-team/reviews/T-1042.md`, `.shell-team/reviews/T-1046.md` and this record
as its prior art, and marked a re-opening of #167 under a lower-stakes framing.
The sprint's goal row for this item is recorded **not met** rather than softened.
*Cost*: one planning turn. *Risk*: the adopter trap stays as it is — already
documented in both languages, and no worse than yesterday.
**Recommended.**

**B — Re-scope to a design that answers vector 6, and take it through planning
with the full history in view.** *Content*: the query stops asking about the base
**dir** and asks about **the record files the loop actually writes** — the
scaffolded `<base>/todo.md` and the specs dir's `.gitkeep`, which are precisely
what a later `git add` would refuse. That inverts arm (c) into its correct form:
the rule is not "never query a descendant" (which is what *produces* the false
all-clear) but "an ignored `runs/` must not trigger a warning" — two different
rules that #452's sketch conflates into one. This is a materially different
deliverable from the issue's acceptance sketch, so it needs #452's body amended,
its planning row re-derived with the defeat history cited, and a human-GO'd
class-B amendment (or an explicit planning-level supersession) of T-1046's
Non-goals and **AC4** before any freeze. Vectors 1–4 would additionally have to
be dispositioned in writing as accepted-for-an-advisory-line rather than
re-litigated. *Cost*: a planning turn plus a task priced as a mechanism change
against an adversarial gate, not a PATCH wording item. *Risk*: the class's own
base rate above.

**C — Proceed exactly as issue #452 and the routing map specify.** *Content*: the
four arms as sketched. *Consequences, all three certain rather than possible*: a
merged frozen Non-goal is contradicted; T-1046 **AC4** goes red by construction,
in the one way its own text says must never be treated as acceptable staleness;
and the shipped warning stays silent in the reproduced `.shell-team/*.md` /
repo-wide `*.md` case, i.e. the loop ships a false all-clear for the exact trap.
**Not recommended, and not something this role will freeze.**

## Assumptions

- **Relayed, not measurable from this role**: the branch point `e00f560`; that
  this branch has no open predecessor PR; the sprint "b-first-run" planning
  approval of 2026-09-07T05:52Z and its per-item PATCH derivation; the
  operator-approved lightweight mode; and issue #452's and #167's current tracker
  state. No 40-hex literal from any of these appears anywhere in this file as a
  load-bearing anchor. The coordinating session holds the primary confirmation
  for each and should report #167's live state beside disposition A or B, since
  whether #167 is still open decides whether #452 is a duplicate or a re-scope.
- **Unverified and flagged above**: `git check-ignore`'s answer for a base
  **directory** whose contents are tracked.
- **Declarations are deliberately absent.** No `- user-visible:`,
  `- verification-class:`, `- verification-ceiling:` or
  `- base-ref-discriminator:` line is written, because each is a first-freeze
  declaration about a deliverable and this file declares none. Had the design
  been freezable they would have read: `user-visible: yes` (a new line in a
  shipped script's adopter-facing output, adopter surface *Where the operating
  files live* in both languages plus `--help`); `verification-class: mechanism`
  (the diff reaches `bin/` and `tests/`); `verification-ceiling:
  unit-and-static`; and `base-ref-discriminator: not-applicable` — no open
  predecessor PR, so the branch point is `git merge-base develop HEAD` and no
  predecessor-versus-merge-base ambiguity exists. They are recorded here as
  worked-out inputs to a later freeze, not as declarations in force.

## Open questions — blocking

1. **Which disposition (A, B or C)?** This is the block. It is a planning
   decision because T-1046's own terminal pre-commitment routes it there, and
   because the approval that authorized T-1129 was derived without the defeat
   history in view.
2. **Is #167 still open?** Not readable from this role. If open, #452 is a
   duplicate re-filing and the two should be merged before either is worked.

## Notes for engineer

**Do not implement anything from this file.** It is a pre-freeze record of a
blocking conflict, not a work order: there are no acceptance criteria, no intent
block and no frozen intent to implement against.

If disposition **B** is later authorized, these are the measured inputs worth
carrying into its spec rather than re-deriving:

- The six claim sites listed under `## Measurements`, and the constraint that
  T-1097 **AC13** makes their repair a **re-scoping** — the trial section of
  `docs/adopting.md` must keep at least one line carrying both `no git command`
  and `--trial-branch`, and no line carrying the former without the latter.
  Deleting the phrase reddens **AC13**; leaving it unqualified makes it false.
- The surviving half of the T-1097 git-free invariant, if that arm is ever
  re-scoped: "git's absence or failure never fails `team-init` — exit status
  stays 0 and the scaffold still lands". `tests/team-init/run.sh`:592 is the
  assertion that would have to change, and `:601` its `PASS` text.
- Any ignore assertion must pin `core.excludesFile` explicitly rather than
  inherit the operator's, per `docs/adopting.md`:54–59. Pinning it *for the
  script's own internal call* is not possible from outside with `git -c`; the
  portable, git-version-agnostic pin for a fixture is repo-local
  (`git -C "$repo" config core.excludesFile <fixture>`), which overrides the
  global file by config precedence. `GIT_CONFIG_GLOBAL` needs git ≥ 2.32 and is
  itself one of T-1046's recorded injection vectors.
- The ignore query has to run **after** the scaffold: a trailing-slash pattern
  such as `.shell-team/` only matches a path that exists as a directory on disk.
- The T-1097 environment-hygiene pattern at `bin/team-init.sh`:235–268 —
  `git -C "$TARGET"` under `env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE` —
  and the shipped invariants it protects: pure bash, zero new dependency,
  shellcheck-clean, no host-root file written.
- **Measured-at-ref command check**: `not applicable — no deliverable of this
  task prints a command beside a label naming the git ref its result was measured
  at.` The one `- count:` line above reads the working tree deliberately and
  carries no ref label.
