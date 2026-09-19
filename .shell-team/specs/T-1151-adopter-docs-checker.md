# The adopter-docs freeze gate becomes a checker, and a `user-visible: yes` spec inventories the shipped documents it changes

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1151

## Problem

Two freeze-time duties on the adopter-docs axis are prose reads today, and both
were left that way deliberately rather than by oversight. T-1061 built a
mechanical gate for its own declaration grammar, then carved the checker, its
fixture suite and its CI wiring out to issue #250 when its pre-commitment
trigger fired — two consecutive review rounds had found independent defects in
the checker's scan-scoping logic, and shipping a gate that passes a spec it
should refuse is worse than shipping an honest prose duty. Separately, issue
#577 records that a `user-visible: yes` spec can name a mechanism in several
shipped documents while editing only some of them, so a shipped document
describing a mechanism goes stale across releases merely because the task that
last touched the mechanism happened to edit a different page.

This task rebuilds the checker on an explicit three-variable state machine that
closes the three open findings the carved-out generation left behind, and adds
the #577 inventory line to the same grammar and the same checker, so one
mechanism enforces both duties at one seam.

## Summarized sources

- `the salvage checker (`git show 5859e247^:bin/check-adopter-docs.sh`, extracted to a scratch directory by the coordinating session)` (the carved-out checker, 444 lines; origin `git show 5859e247^:bin/check-adopter-docs.sh`, an origin this role cannot verify — see `## Assumptions`) — read first-hand. The distinctions carried over: the closed refusal contract (one bare token alone on stderr, zero bytes on stdout, exit `2` for "could not be evaluated at all" and exit `1` for a content refusal); the ten-token set and each token's exit code; the seven positional requirements (`:299`–`:328` declaration, `:362`–`:418` waiver and surface); the value-retention rule "any in-scope occurrence with a non-whitespace value", never the first occurrence's (`:64`–`:72`); the em-dash split-on-first-occurrence-then-trim separator rule (`:330`–`:360`); the deliberate exclusion of tilde fences (`:216`–`:218`); and the **measured** R2 defect at `:388`–`:391` — an unconditional `continue` on a fenced line, placed before any scope transition, so `in_ac` survives a fence as an accident of code placement rather than as a decided rule.
- the salvage suite (`git show 5859e247^:tests/check-adopter-docs/run.sh`) (the carved-out fixture suite, 405 lines) — read first-hand. The distinctions carried over: the **measured** case count of 42 (41 `assert_case` calls plus one manually counted `--help` case); the `grep -x` whole-line token assertion that refuses a wrong-but-nonzero result; the zero-bytes-on-both-streams pass contract; the class ids it already coins; and the **measured** gap that no case among the 42 crosses the fence dimension with the scope dimension — its two `cad-fence-*` cases probe only declaration and marker inertness, and its three `cad-scope-*` cases carry no fence at all.
- the workflow as T-1061 wired it (`git show 5859e247^:.github/workflows/check-handoff.yml`) (the workflow as the carved-out task wired it) — read first-hand, `:31`–`:32` (a **second** `shellcheck` step rather than an edit to the single existing one) and `:273`–`:277` (one suite step plus one dogfood step naming a single fixed spec, never a corpus glob).
- `.github/workflows/check-handoff.yml` (live) — read first-hand. The distinction carried over: **measured** — exactly one step is named `shellcheck` today, at `:28`, and its `run:` is one physical line at `:29` enumerating every script and suite, so an in-place extension changes that line's bytes while a second step does not.
- `skills/run/SKILL.md` — read first-hand, `:51` (the T-1061 gate bullet, carrying the bold label `**Adopter-facing-documentation gate (T-1061)**` and the honesty literal) and its siblings `:52` (T-1081), `:53` (T-1091), `:54` (T-1092), `:55` (T-1093), `:57` (T-1110). The distinction carried over: `:45`'s `check-entry-mode.sh` bullet is this file's own idiom for a bullet that calls a checker and branches on its exit code, and `:52`/`:55`/`:57` cite issue #250 as the canonical home for their own deferred mechanical arms while remaining prose gates that this task does not touch.
- `agents/pm-spec.md` — read first-hand, `:90` (the `## Spec completion self-check` bullet carrying the T-1061 declaration check and the honesty literal) and the generated `<!-- BEGIN prompt-block: playbook-pm-spec -->` region, which is never hand-edited.
- `docs/adopting.md` `:706`–`:736` (`## Declaring adopter-facing documentation`, honesty sentence at `:725`) and `docs/adopting.ja.md` `:712`–`:741` (`## adopter 向けドキュメントの宣言`, honesty sentence at `:732`–`:733`) — read first-hand. The distinctions carried over: both sections state the enforcement as a duty rather than a checker; both state the boundary that the sweep does not open, resolve or validate a named surface; and **measured** — each file carries exactly 21 `^## ` headings today, the parity merged criteria assert.
- `templates/prompt-blocks/adopter-docs-declaration.md` — read first-hand, its three non-empty lines (the two declaration forms and the discharge sentence).
- `templates/prompt-blocks/registry.txt` `:45` — read first-hand: `contain adopter-docs-declaration.md agents/pm-spec.md skills/run/SKILL.md`. The distinction carried over: `contain` mode requires every non-empty canonical line to appear **verbatim in every listed consumer**, so a line added to the block must land in both consumers in the same task.
- `.shell-team/specs/T-1061-adopter-docs-gate.md` — read first-hand, its frozen Goal (`:34`–`:36`) and Non-goals `:40` (no content judgment, no path allowlist, nothing opens/stats/resolves/pattern-matches a surface value), `:44` (no checker ships by that task), `:47` (the generated prompt-block region stays byte-identical), `:48` (no README edit, the adopter surface is the two adopter-workflow pages). The distinction carried over: `:40` is the design invariant this task inherits unchanged and must not violate while adding a token whose name contains the word "unmeasured".
- `.shell-team/test-recipe.md` `:85` — read first-hand, the `## Appended by tasks` append-only heading and its one-entry-per-task-id convention.
- `.shell-team/todo.md` — read first-hand, `## Active` at `:12` and the T-1150 entry at `:6617`–`:6639` for the board sub-bullet shapes this entry follows.

## Goal

<!-- BEGIN intent-block: T-1151 -->

- user-visible: yes — an adopter running this loop gains a freeze-time refusal that is a real exit code rather than a prose duty, and a new line their `user-visible: yes` specs must carry; both change what the loop does to an adopter's work.
- verification-class: mechanism — the diff adds `bin/check-adopter-docs.sh` and `tests/check-adopter-docs/run.sh`, edits `templates/prompt-blocks/adopter-docs-declaration.md`, `skills/run/SKILL.md` and `.github/workflows/check-handoff.yml`, and changes the semantics of a checker, so every executing surface the class names is reached.
- verification-ceiling: unit-and-static — every criterion below is decidable in a plain checkout from committed blobs, synthetic fixtures under a temp root, and a checker's own exit code; no criterion requires a live adopter repository, a network call or an executor CLI.
- base-ref-discriminator: `PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1` — spelled byte-identically in every criterion that reads a base-side blob.
- shipped-docs: templates/prompt-blocks/adopter-docs-declaration.md — this-task
- shipped-docs: agents/pm-spec.md — this-task
- shipped-docs: skills/run/SKILL.md — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: .shell-team/test-recipe.md — this-task

`bin/check-adopter-docs.sh` ships as a stateless predicate over one spec file: it
reads that file, decides from an explicit three-variable state machine, and
exits `0` silently, `1` on a content refusal, or `2` when the input could not be
evaluated at all, writing exactly one token from a closed set of **fourteen**
alone on stderr and zero bytes on stdout. The three state variables are
orthogonal and every line of the file produces a transition in each of them,
identity transitions included: **F** tracks fence state over both backtick and
tilde runs of length three or more, closing only on a run of the same character
at least as long; **R** tracks the declaration region, opening at the
`BEGIN intent-block` marker read as content and closing at the **first** `^## `
heading after it, so the region can never widen without bound; **S** tracks
acceptance-criterion scope across `## Acceptance criteria` and each unindented
`- [ ] **ACn**` bullet. Per line the checker computes the fence event from the
current **F**, sets `content_active` true only when **F** is out and the line is
not itself a delimiter, transitions **F**, then either transitions **R** and
**S** and matches tokens (when the line is content) or **runs the explicitly
listed identity transitions of R and S** (when it is not) — never skipping the
line before its scope effect has been evaluated, which is exactly the shape the
carved-out generation's unconditional `continue` produced. Every token match is
recorded together with the `(R,S)` pair in force at that moment, and the verdict
is decided from the resulting multiset under one frozen refusal precedence, so
it never depends on the order occurrences happen to appear in. The seven
positional requirements T-1061 froze are preserved exactly: the declaration must
be unindented and inside **R**; the waiver must be unindented and inside the
intent block, with no AC-nesting requirement of its own; the surface must be
indented, inside the intent block, and under a real AC bullet. Issue #577's
inventory duty joins the same grammar as a `- shipped-docs: <repo-relative path>
— this-task | issue #<N>` line, unindented and inside **R**, adding four tokens
whose family shape mirrors the declaration family's malformed/misplaced
symmetry; the fourth of them, `shipped-docs-unmeasured`, is decided as a
**string relation between lines of the same file** — a `this-task` path that
appears in none of that spec's own `- check:` or `- adopter-surface:` lines —
and the checker never opens, stats, resolves or pattern-matches that path
against the filesystem, T-1061's frozen Non-goal being the design invariant this
task inherits rather than revisits. A `- shipped-docs:` line beside a `no`
declaration reuses the existing `marker-conflict` token rather than minting a
fifteenth. The fixture suite is derived one-way from the transition table, so
every row of the table has a case and no case exists that the table does not
license. The gate stays **forward-only in its caller**: `skills/run/SKILL.md`'s
bootstrap-freeze branch calls the checker at a task's first freeze only, no
existing spec is retrofitted, and no CI step sweeps the spec corpus.

## Non-goals

- **No content judgment, and no path allowlist.** Nothing this task ships opens,
  stats, resolves, globs or pattern-matches the value of an `- adopter-surface:`
  or `- shipped-docs:` line against the filesystem. `shipped-docs-unmeasured` is
  decided purely by comparing lines of the spec file to each other. Whether a
  named document is *really* the right one is a matter for the reviewing gates
  and the human.
- **No retro-fit of any existing spec.** No spec file present at this branch's
  point of divergence gains a declaration, surface, waiver or `- shipped-docs:`
  line. This spec is the first and only one to carry `- shipped-docs:` lines.
- **No corpus sweep, in CI or anywhere else.** No step added by this task reads
  `.shell-team/specs/*.md` as a set; the only spec any CI step of this task
  names is this one.
- **No repair, widening or annotation of any merged criterion**, including the
  ones already red at the branch point and the ones this task's diff reddens.
- **No fifteenth refusal token, no new status flag, verdict label, board field,
  telemetry key or event id.** A `- shipped-docs:` line beside a `no` reuses
  `marker-conflict`; a refused freeze routes back to `pm-spec` in the words the
  sweep item already uses.
- **No edit to the freeze pipeline's existing scripts** — `bin/check-acs.sh`,
  `bin/check-intent.sh`, `bin/check-refreeze-class.sh` and `bin/team-paths.sh`
  are outside this task's change set entirely; none of their grammars, exit
  codes or parsing rules is modified here.
- **No edit to `README.md` or `README.ja.md`**, to `.shell-team/lessons.md`, or
  to any existing spec file. The adopter surface for this mechanism is the two
  adopter-workflow pages, exactly as T-1061 settled.
- **No edit to the generated prompt-block regions of any consumer.**
  `agents/pm-spec.md`'s `playbook-pm-spec` region stays byte-identical to the
  branch point; the grammar lands in the hand-written self-check section.
- **No touching of the sibling prose gates.** `skills/run/SKILL.md`'s T-1081,
  T-1093 and T-1110 bullets keep their own honesty literal and their own
  citation of issue #250; only the T-1061 bullet becomes a checker call.
- **No in-place edit of the workflow's existing `shellcheck` step.** Its single
  physical `run:` line stays byte-identical; a second step carries this task's
  additions.
- **No re-litigation of the carved-out generation's exit contract, token names
  or positional requirements.** They are inherited as fixed inventories, not
  redesigned.
- **No full-population two-arm blast-radius sweep inside this task.** It is
  deferred to the release sweep under the operator's standing mode-A2 ruling and
  disclosed as a deviation in `## Blast radius`.

## Acceptance criteria

- [ ] **AC1** `bin/check-adopter-docs.sh` exists as a tracked file whose git
  **index** mode is `100755` and whose committed blob begins `#!`, and the same
  bidirectional rule holds for `tests/check-adopter-docs/run.sh` under `tests/`
  (the repository's own `tests/bin-exec-bit` lock, asserted here so this task
  does not discover it in CI). Both files are non-empty. Positive control: the
  `git ls-files -s` extraction is asserted non-empty before any mode is judged,
  so an empty parse cannot satisfy the clause.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac1.XXXXXX") || exit 1; git ls-files -s -- bin/check-adopter-docs.sh tests/check-adopter-docs/run.sh > "$T/ls" || rc=1; test "$(grep -c . "$T/ls" || true)" = "2" || rc=1; test "$(awk '$1=="100755"' "$T/ls" | grep -c . || true)" = "2" || rc=1; for f in bin/check-adopter-docs.sh tests/check-adopter-docs/run.sh; do test -s "$f" || rc=1; head -c 2 "$f" > "$T/hb" 2>/dev/null || rc=1; test "$(cat "$T/hb")" = '#!' || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC2** The checker tracks **tilde** fences as well as backtick fences.
  Against two generated fixtures differing only in that one wraps its
  declaration in a `~~~` fence, the unfenced one exits `0` with zero bytes on
  both streams and the tilde-fenced one exits `1` with exactly the token
  `declaration-missing` alone on stderr. Positive controls: the unfenced fixture
  passing proves the generator produces a spec the checker accepts, so the
  tilde fixture's refusal is attributable to the fence alone; and the tilde
  fixture is asserted to contain the literal token text, so "the token is
  absent" cannot masquerade as "the token is inert".
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac2.XXXXXX") || exit 1; hd() { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; }; tl() { printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; }; { hd; printf -- '- user-visible: no — plain\n'; tl; } > "$T/ok.md"; { hd; printf '~~~\n'; printf -- '- user-visible: no — fenced\n'; printf '~~~\n'; tl; } > "$T/tilde.md"; grep -qF -- 'user-visible' "$T/tilde.md" || rc=1; o=$(bash "$C" "$T/ok.md" 2>"$T/e1"); r=$?; test "$r" -eq 0 || rc=1; test -z "$o" || rc=1; test ! -s "$T/e1" || rc=1; bash "$C" "$T/tilde.md" >"$T/o2" 2>"$T/e2"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o2" || rc=1; grep -qx -- 'declaration-missing' "$T/e2" || rc=1; test "$(grep -c . "$T/e2" || true)" = "1" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC3** A fenced line's **scope effect is evaluated as an explicitly
  listed identity transition**, never swallowed by skipping the line — the open
  R2 finding. The fence/no-fence control pair proves it behaviourally: two
  fixtures identical except that one wraps an intervening `^## ` heading in a
  backtick fence produce **different** verdicts in the direction the transition
  table states — unfenced, the heading closes AC scope so the following indented
  surface line does not discharge (`obligation-undischarged`, exit `1`); fenced,
  the heading is inert, AC scope survives as an identity transition, the surface
  discharges and the fixture passes with zero bytes on both streams. Positive
  control: both fixtures are asserted to contain the heading text and the
  surface token, so neither verdict can come from a missing line.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; TIC=$(printf '\140\140\140'); T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac3.XXXXXX") || exit 1; hd() { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: yes — ships a new command\n'; printf -- '- shipped-docs: docs/x.md — this-task\n'; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n'; }; tl() { printf '  - adopter-surface: docs/x.md\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; }; { hd; printf '## Notes\n'; tl; } > "$T/plain.md"; { hd; printf '%s\n## Notes\n%s\n' "$TIC" "$TIC"; tl; } > "$T/fenced.md"; for f in "$T/plain.md" "$T/fenced.md"; do grep -qF -- '## Notes' "$f" || rc=1; grep -qF -- '- adopter-surface: docs/x.md' "$f" || rc=1; done; bash "$C" "$T/plain.md" >"$T/o1" 2>"$T/e1"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o1" || rc=1; grep -qx -- 'obligation-undischarged' "$T/e1" || rc=1; bash "$C" "$T/fenced.md" >"$T/o2" 2>"$T/e2"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o2" || rc=1; test ! -s "$T/e2" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC4** The declaration region **R** closes at the first `^## ` heading
  after the `BEGIN` marker and can never widen without bound. A fixture whose
  intent block carries **no** `## Non-goals` heading at all but does carry a
  later `^## ` heading, with a well-formed declaration placed after that
  heading, is refused `declaration-misplaced` (exit `1`) rather than accepted —
  the behaviour the carved-out generation's unbounded fallback admitted.
  Positive control: the same fixture with the declaration moved **before** that
  heading passes with zero bytes on both streams, so the refusal is attributable
  to position alone and not to the fixture's missing `## Non-goals`.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac4.XXXXXX") || exit 1; { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n'; printf -- '- user-visible: no — after the first heading\n'; printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; } > "$T/after.md"; { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: no — before the first heading\n'; printf '\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; } > "$T/before.md"; grep -qF -- 'user-visible' "$T/after.md" || rc=1; grep -qF -- '## Non-goals' "$T/after.md" && rc=1; grep -qF -- '## Acceptance criteria' "$T/after.md" || rc=1; bash "$C" "$T/after.md" >"$T/o1" 2>"$T/e1"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o1" || rc=1; grep -qx -- 'declaration-misplaced' "$T/e1" || rc=1; bash "$C" "$T/before.md" >"$T/o2" 2>"$T/e2"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o2" || rc=1; test ! -s "$T/e2" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC5** All **seven** positional requirements T-1061 froze are preserved,
  each probed independently: a declaration that is indented is invisible
  (`declaration-missing`); a well-formed declaration outside **R** is
  `declaration-misplaced`; an indented waiver is not a waiver; a waiver after
  the `END` marker is not a waiver; an unindented surface line is not a surface;
  a surface after the `END` marker is not a surface; a surface inside the block
  but not under an AC bullet is not a surface. The four non-discharging
  waiver/surface probes each sit on an otherwise bare `yes`, so each is refused
  `obligation-undischarged` (exit `1`). Positive control: each of the seven
  fixtures is asserted to contain the literal token text it is meant to render
  inert, so "absent" cannot be mistaken for "inert".
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac5.XXXXXX") || exit 1; hd() { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; }; ng() { printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n'; }; tail_() { printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; }; { hd; printf '  '; printf -- '- user-visible: no — indented\n'; ng; tail_; } > "$T/p1.md"; { hd; ng; tail_; printf '\n## Notes for engineer\n\n'; printf -- '- user-visible: no — outside\n'; } > "$T/p2.md"; { hd; printf -- '- user-visible: yes — r\n'; printf -- '- shipped-docs: docs/x.md — this-task\n'; ng; printf '  '; printf -- '- adopter-docs-waiver: indented so inert\n'; tail_; printf '\ndocs/x.md appears in no check line here.\n'; } > "$T/p3.md"; { hd; printf -- '- user-visible: yes — r\n'; ng; tail_; printf '\n## Assumptions\n\n'; printf -- '- adopter-docs-waiver: after END so inert\n'; } > "$T/p4.md"; { hd; printf -- '- user-visible: yes — r\n'; ng; printf -- '- adopter-surface: unindented so inert\n'; tail_; } > "$T/p5.md"; { hd; printf -- '- user-visible: yes — r\n'; ng; tail_; printf '\n## Notes for engineer\n\n  '; printf -- '- adopter-surface: after END so inert\n'; } > "$T/p6.md"; { hd; printf -- '- user-visible: yes — r\n'; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n  '; printf -- '- adopter-surface: not under an AC bullet\n'; printf '\n- [ ] **AC1** x\n'; tail_; } > "$T/p7.md"; for f in p1 p2; do grep -qF -- 'user-visible' "$T/$f.md" || rc=1; done; for f in p3 p4; do grep -qF -- 'adopter-docs-waiver' "$T/$f.md" || rc=1; done; for f in p5 p6 p7; do grep -qF -- 'adopter-surface' "$T/$f.md" || rc=1; done; for pair in 'p1 declaration-missing' 'p2 declaration-misplaced' 'p3 obligation-undischarged' 'p4 obligation-undischarged' 'p5 obligation-undischarged' 'p6 obligation-undischarged' 'p7 obligation-undischarged'; do set -- $pair; bash "$C" "$T/$1.md" >"$T/o" 2>"$T/e"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o" || rc=1; grep -qx -- "$2" "$T/e" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC6** The verdict is decided from an **order-independent multiset**, not
  from whichever occurrence comes first. Four fixture pairs are asserted, each
  pair being the same two in-scope marker occurrences (one empty-valued, one
  valid) in both orders, for `- adopter-surface:` under two AC bullets and for
  the top-level `- adopter-docs-waiver:`; both members of every pair produce the
  identical verdict. Positive control: each fixture is asserted to carry exactly
  two occurrences of the marker it probes, so a fixture that silently lost one
  cannot pass the pair by accident.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac6.XXXXXX") || exit 1; hd() { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: yes — r\n'; printf -- '- shipped-docs: docs/x.md — this-task\n'; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n'; }; tail_() { printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; }; { hd; printf -- '- [ ] **AC1** a\n  - adopter-surface:\n\n- [ ] **AC2** b\n  - adopter-surface: docs/x.md\n'; tail_; } > "$T/sa.md"; { hd; printf -- '- [ ] **AC1** a\n  - adopter-surface: docs/x.md\n\n- [ ] **AC2** b\n  - adopter-surface:\n'; tail_; } > "$T/sb.md"; { hd; printf -- '- adopter-docs-waiver:\n'; printf -- '- adopter-docs-waiver: no adopter surface exists\n'; printf -- '\n- [ ] **AC1** a\n  - check: test -e docs/x.md\n'; tail_; } > "$T/wa.md"; { hd; printf -- '- adopter-docs-waiver: no adopter surface exists\n'; printf -- '- adopter-docs-waiver:\n'; printf -- '\n- [ ] **AC1** a\n  - check: test -e docs/x.md\n'; tail_; } > "$T/wb.md"; for f in sa sb; do test "$(grep -c -- '- adopter-surface:' "$T/$f.md" || true)" = "2" || rc=1; done; for f in wa wb; do test "$(grep -c -- '- adopter-docs-waiver:' "$T/$f.md" || true)" = "2" || rc=1; grep -qF -- '- adopter-surface:' "$T/$f.md" && rc=1; done; bash "$C" "$T/sa.md" >/dev/null 2>"$T/e1"; r1=$?; bash "$C" "$T/sb.md" >/dev/null 2>"$T/e2"; r2=$?; test "$r1" -eq "$r2" || rc=1; cmp -s "$T/e1" "$T/e2" || rc=1; test "$r1" -eq 0 || rc=1; bash "$C" "$T/wa.md" >/dev/null 2>"$T/e3"; r3=$?; bash "$C" "$T/wb.md" >/dev/null 2>"$T/e4"; r4=$?; test "$r3" -eq "$r4" || rc=1; cmp -s "$T/e3" "$T/e4" || rc=1; test "$r3" -eq 0 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC7** The refusal set is **closed at fourteen tokens** with the frozen
  exit codes — `usage`, `spec-unreadable`, `intent-block-missing` at exit `2`;
  `declaration-missing`, `declaration-duplicate`, `declaration-malformed`,
  `declaration-misplaced`, `marker-conflict`, `waiver-reason-empty`,
  `obligation-undischarged`, `shipped-docs-misplaced`,
  `shipped-docs-malformed`, `shipped-docs-missing`, `shipped-docs-unmeasured`
  at exit `1`. The checker's own `--help` output names all fourteen and the
  count `fourteen`, and names no fifteenth token of the form
  `<word>-<word>` that the spec does not license. Positive controls: `--help`
  is asserted to exit `0` with non-empty stdout before its content is judged,
  and the count of matched tokens is asserted equal to fourteen rather than
  merely non-zero.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac7.XXXXXX") || exit 1; bash "$C" --help > "$T/h" 2>"$T/he"; r=$?; test "$r" -eq 0 || rc=1; test -s "$T/h" || rc=1; n=0; for t in usage spec-unreadable intent-block-missing declaration-missing declaration-duplicate declaration-malformed declaration-misplaced marker-conflict waiver-reason-empty obligation-undischarged shipped-docs-misplaced shipped-docs-malformed shipped-docs-missing shipped-docs-unmeasured; do if grep -qF -- "$t" "$T/h"; then n=$((n + 1)); fi; done; test "$n" -eq 14 || rc=1; grep -qF -- 'fourteen' "$T/h" || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: a later task adds or removes a refusal token in `bin/check-adopter-docs.sh`, at which point the declared fourteen no longer describes the closed set this criterion counts.

- [ ] **AC8** Every refusal writes **exactly one token, alone, on stderr and zero
  bytes on stdout**, and the two exit-`2` input-error classes are reachable:
  `usage` for no argument, an extra positional argument and an unknown flag;
  `spec-unreadable` for a missing path and for a directory. Positive control:
  the token is matched with a whole-line `grep -x` against a stderr asserted to
  be exactly one non-empty line, so a token embedded in a longer diagnostic
  cannot pass.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac8.XXXXXX") || exit 1; mkdir -p "$T/adir"; probe() { bash "$C" "$@" >"$T/o" 2>"$T/e"; r=$?; test "$r" -eq "$WANT_RC" || rc=1; test ! -s "$T/o" || rc=1; test "$(grep -c . "$T/e" || true)" = "1" || rc=1; grep -qx -- "$WANT_TOK" "$T/e" || rc=1; }; WANT_RC=2; WANT_TOK=usage; probe; probe "$T/a" "$T/b"; probe --nope "$T/a"; WANT_TOK=spec-unreadable; probe "$T/does-not-exist-xyz.md"; probe "$T/adir"; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC9** The `- shipped-docs:` grammar exists **once**, in the canonical
  prompt block, and reaches both registered consumers verbatim.
  `templates/prompt-blocks/adopter-docs-declaration.md` gains a non-empty line
  carrying the literal fragments `- shipped-docs:`, `this-task` and `issue #`;
  `templates/prompt-blocks/registry.txt` still carries exactly one `contain` row
  for that block whose consumers are exactly `agents/pm-spec.md` and
  `skills/run/SKILL.md` and no third; and `bash bin/check-prompt-sync.sh` exits
  `0`, which is what proves every non-empty canonical line really does appear
  verbatim in both consumers rather than being registered and diverged. Positive
  controls: the block file and the registry are asserted readable and non-empty
  first, and the extracted consumer list is asserted non-empty, so an empty parse
  cannot satisfy the exactly-two clause.
  - check: rc=0; BL=templates/prompt-blocks/adopter-docs-declaration.md; RG=templates/prompt-blocks/registry.txt; test -s "$BL" || exit 1; test -s "$RG" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac9.XXXXXX") || exit 1; for s in '- shipped-docs:' 'this-task' 'issue #'; do grep -qF -- "$s" "$BL" || rc=1; done; awk '$1=="contain" && $2=="adopter-docs-declaration.md"' "$RG" > "$T/row"; test "$(grep -c . "$T/row" || true)" = "1" || rc=1; awk '{for(i=3;i<=NF;i++) print $i}' "$T/row" | LC_ALL=C sort > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' agents/pm-spec.md skills/run/SKILL.md | LC_ALL=C sort > "$T/want"; cmp -s "$T/got" "$T/want" || rc=1; bash bin/check-prompt-sync.sh >/dev/null 2>&1 || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC10** The three positional and grammatical `shipped-docs` tokens are
  reachable and distinct. On a `yes` declaration: zero `- shipped-docs:` lines
  is `shipped-docs-missing`; a line with no em-dash separator, a line with an
  empty path, and a line whose disposition is neither `this-task` nor
  `issue #<digits>` are each `shipped-docs-malformed`; an unindented
  `- shipped-docs:` line placed outside **R** is `shipped-docs-misplaced`. All
  are exit `1` with one token alone on stderr. Positive control: a conformant
  fixture carrying `- shipped-docs: docs/x.md — this-task` and a conformant
  fixture carrying `- shipped-docs: docs/y.md — issue #577` each pass with zero
  bytes on both streams, so every refusal above is attributable to its own
  defect rather than to the family being refused wholesale.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac10.XXXXXX") || exit 1; mk() { { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: yes — r\n'; if [ -n "$1" ]; then printf '%s\n' "$1"; fi; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n  - adopter-surface: docs/x.md\n  - adopter-surface: docs/y.md\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; if [ -n "$2" ]; then printf '\n## Notes for engineer\n\n%s\n' "$2"; fi; } > "$3"; }; mk '- shipped-docs: docs/x.md — this-task' '' "$T/ok1.md"; mk '- shipped-docs: docs/y.md — issue #577' '' "$T/ok2.md"; mk '' '' "$T/miss.md"; mk '- shipped-docs: docs/x.md this-task' '' "$T/m1.md"; mk '- shipped-docs:  — this-task' '' "$T/m2.md"; mk '- shipped-docs: docs/x.md — someday' '' "$T/m3.md"; mk '' '- shipped-docs: docs/x.md — this-task' "$T/mis.md"; for f in ok1 ok2; do bash "$C" "$T/$f.md" >"$T/o" 2>"$T/e"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; done; for pair in 'miss shipped-docs-missing' 'm1 shipped-docs-malformed' 'm2 shipped-docs-malformed' 'm3 shipped-docs-malformed' 'mis shipped-docs-misplaced'; do set -- $pair; grep -qF -- 'shipped-docs' "$T/$1.md" || test "$1" = "miss" || rc=1; bash "$C" "$T/$1.md" >"$T/o" 2>"$T/e"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o" || rc=1; test "$(grep -c . "$T/e" || true)" = "1" || rc=1; grep -qx -- "$2" "$T/e" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC11** `shipped-docs-unmeasured` is decided as a **string relation
  between lines of the same file** and the checker performs **no filesystem
  access** on the named path. A fixture whose `this-task` path appears in
  neither a `- check:` nor an `- adopter-surface:` line is refused
  `shipped-docs-unmeasured` (exit `1`) **even though that path exists on disk**;
  a fixture whose `this-task` path is named in a `- check:` line passes with
  zero bytes on both streams **even though that path does not exist on disk**;
  and a fixture whose `this-task` path appears only inside a fenced block is
  refused, the reading side being fence-aware so a spec cannot discharge by
  quoting itself. Positive control: the on-disk existence of the first fixture's
  path and the on-disk absence of the second's are both asserted before the
  verdicts are read, so the pair genuinely inverts filesystem truth against
  checker verdict.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; TIC=$(printf '\140\140\140'); T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac11.XXXXXX") || exit 1; test -f README.md || rc=1; test ! -e no/such/path-xyz.md || rc=1; hd() { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: yes — r\n'; printf -- '- shipped-docs: %s — this-task\n' "$1"; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n  - adopter-surface: docs/other.md\n'; }; tl() { printf '\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; }; { hd README.md; tl; } > "$T/exists-unmeasured.md"; { hd no/such/path-xyz.md; printf '  - check: test -f no/such/path-xyz.md\n'; tl; } > "$T/absent-measured.md"; { hd README.md; printf '%s\n  - check: grep -q README.md .\n%s\n' "$TIC" "$TIC"; tl; } > "$T/fenced.md"; bash "$C" "$T/exists-unmeasured.md" >"$T/o1" 2>"$T/e1"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o1" || rc=1; grep -qx -- 'shipped-docs-unmeasured' "$T/e1" || rc=1; bash "$C" "$T/absent-measured.md" >"$T/o2" 2>"$T/e2"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o2" || rc=1; test ! -s "$T/e2" || rc=1; bash "$C" "$T/fenced.md" >"$T/o3" 2>"$T/e3"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o3" || rc=1; grep -qx -- 'shipped-docs-unmeasured' "$T/e3" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC12** A `- shipped-docs:` line beside a `no` declaration reuses the
  existing `marker-conflict` token and **no fifteenth token is minted**: the
  fixture is refused `marker-conflict` (exit `1`), and the checker's source
  carries no occurrence of a `shipped-docs-conflict`-shaped name. Positive
  control: the same `no` fixture without the `- shipped-docs:` line passes with
  zero bytes on both streams.
  - check: rc=0; C=bin/check-adopter-docs.sh; test -s "$C" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac12.XXXXXX") || exit 1; mk() { { printf '# F\n\n## Goal\n\n<!-- BEGIN intent-block: T-999 -->\n'; printf -- '- user-visible: no — internal\n'; if [ -n "$1" ]; then printf '%s\n' "$1"; fi; printf '\n## Non-goals\n\n- none\n\n## Acceptance criteria\n\n- [ ] **AC1** x\n\n## Input space\n\nn/a\n\n<!-- END intent-block: T-999 -->\n'; } > "$2"; }; mk '- shipped-docs: docs/x.md — this-task' "$T/conf.md"; mk '' "$T/clean.md"; bash "$C" "$T/clean.md" >"$T/o0" 2>"$T/e0"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o0" || rc=1; test ! -s "$T/e0" || rc=1; bash "$C" "$T/conf.md" >"$T/o1" 2>"$T/e1"; r=$?; test "$r" -eq 1 || rc=1; test ! -s "$T/o1" || rc=1; grep -qx -- 'marker-conflict' "$T/e1" || rc=1; grep -qF -- 'shipped-docs-conflict' "$C" && rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC13** `tests/check-adopter-docs/run.sh` runs green and its case
  inventory is derived one-way from the transition table: it carries every class
  id the carved-out suite coined, plus the new classes this design requires —
  at least one `cad-fence-` case exercising a fenced line's **scope** effect, at
  least one `cad-scope-` case, the fence/no-fence control pair, `cad-shipped-`
  cases for each of the four new tokens plus a conformant pass and the
  `no`-beside-`shipped-docs` conflict, and a no-filesystem probe. The suite's
  own final line reports a case count **strictly greater** than the 42 the
  carved-out suite carried, re-derived from its own run rather than restated.
  Positive control: the suite is asserted to exit `0` and to emit a non-empty
  final summary line before that line's count is parsed, so a suite that
  silently produced nothing cannot pass.
  - check: rc=0; S=tests/check-adopter-docs/run.sh; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac13.XXXXXX") || exit 1; bash "$S" > "$T/out" 2>"$T/err"; r=$?; test "$r" -eq 0 || rc=1; test -s "$T/out" || rc=1; for s in cad-usage- cad-unreadable- cad-block- cad-missing- cad-duplicate cad-malformed- cad-misplaced- cad-boundary- cad-undischarged- cad-waiver-empty cad-conflict- cad-pass- cad-fence- cad-scope- cad-order- cad-shipped- cad-control-pair cad-nofs; do grep -qF -- "$s" "$S" || rc=1; done; n=$(grep -oE 'all [0-9]+ cases passed' "$T/out" | grep -oE '[0-9]+' | tail -1); test -n "$n" || rc=1; test "${n:-0}" -gt 42 || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: the fixture suite gains or loses a case class, at which point the greater-than-42 floor and the class-id list this criterion asserts no longer describe the suite.

- [ ] **AC14** `skills/run/SKILL.md`'s T-1061 gate bullet becomes a **checker
  call that branches on an exit code**, in the idiom `:45`'s
  `check-entry-mode.sh` bullet already uses, while its three sibling prose gates
  are untouched. That file contains the literal `bin/check-adopter-docs.sh`, the
  bold label `**Adopter-facing-documentation gate (T-1061)**` **exactly once**,
  and the phrase `branch on its exit code` within the same file; and the count
  of the honesty literal `no checker ships for it yet` in that file is exactly
  **3**, down from the 4 measured at authoring time — the T-1081, T-1093 and
  T-1110 bullets keeping theirs. Positive controls: the file is asserted
  readable and non-empty first, and the three sibling bullets' own anchors
  (`T-1081`, `T-1093`, `T-1110`) are asserted still present, so a count that
  fell to 3 by deleting a sibling rather than by closing this one cannot pass.
  - check: rc=0; F=skills/run/SKILL.md; test -s "$F" || exit 1; grep -qF -- 'bin/check-adopter-docs.sh' "$F" || rc=1; grep -qF -- 'branch on its exit code' "$F" || rc=1; test "$(grep -cF -- '**Adopter-facing-documentation gate (T-1061)**' "$F" || true)" = "1" || rc=1; test "$(grep -cF -- 'no checker ships for it yet' "$F" || true)" = "3" || rc=1; for a in 'T-1081' 'T-1093' 'T-1110'; do grep -qF -- "$a" "$F" || rc=1; done; test "$rc" -eq 0
  - stale-at: another prose gate in `skills/run/SKILL.md` is added carrying the honesty literal, or an existing one is closed by its own follow-up task, at which point the declared 3 no longer describes the population this criterion counts.

- [ ] **AC15** `agents/pm-spec.md`'s hand-written self-check names the checker
  instead of denying one, and its machine-owned region is untouched. The
  `## Spec completion self-check` section contains the literal
  `bin/check-adopter-docs.sh` and the `- shipped-docs:` token; the honesty
  literal `no checker ships for it yet` appears in that file exactly **1** time,
  down from the 2 measured at authoring time (the T-1093 bullet keeping its
  own); and the generated region between the `playbook-pm-spec` markers is
  **byte-identical** to the same extraction from the branch point's committed
  blob. Positive controls: the file is asserted non-empty and still carrying
  `## Spec completion self-check`; both marker-region extractions are asserted
  non-empty before they are compared, so two empty extractions cannot pass.
  - check: rc=0; F=agents/pm-spec.md; test -s "$F" || exit 1; PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac15.XXXXXX") || exit 1; grep -qF -- '## Spec completion self-check' "$F" || rc=1; grep -qF -- 'bin/check-adopter-docs.sh' "$F" || rc=1; grep -qF -- '- shipped-docs:' "$F" || rc=1; test "$(grep -cF -- 'no checker ships for it yet' "$F" || true)" = "1" || rc=1; git show "$B:$F" > "$T/base" 2>/dev/null || rc=1; test -s "$T/base" || rc=1; ext() { awk '/<!-- BEGIN prompt-block: playbook-pm-spec -->/{f=1} f{print} /<!-- END prompt-block: playbook-pm-spec -->/{if(f) exit}' "$1"; }; ext "$T/base" > "$T/rb"; ext "$F" > "$T/rn"; test -s "$T/rb" || rc=1; test -s "$T/rn" || rc=1; cmp -s "$T/rb" "$T/rn" || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: another `agents/pm-spec.md` checklist item gains or loses the honesty literal, at which point the declared 1 no longer describes the population this criterion counts.

- [ ] **AC16** The adopter-facing documentation lands in the same task, in both
  languages, inside the existing sections and adding no heading. `docs/adopting.md`
  and `docs/adopting.ja.md` each still carry exactly **21** `^## ` headings and
  their totals are equal; each still carries its own adopter-docs heading
  (`## Declaring adopter-facing documentation` / `## adopter 向けドキュメントの宣言`);
  the literal `bin/check-adopter-docs.sh` and the `- shipped-docs:` token appear
  **inside that section** in each language, which is what "the paragraph lands
  in the existing section" means; and the honesty sentence fragment
  (`no mechanical checker ships for it yet` in English,
  `機械的なチェッカーはまだ出荷` in Japanese) is absent **from that section**.
  The absence is deliberately section-scoped and not whole-file: the same
  fragment occurs elsewhere in each file in **other** prose gates' sections —
  in English at T-1110's derivation-gate sentence, in Japanese there and in two
  further gate sections — and this task must leave every one of them standing.
  T-1110's own sentences are pinned separately: the literal `version-derivation`
  still appears in both files. Positive controls: both files are asserted
  readable and non-empty and the heading counts asserted non-zero before
  equality is judged; both extracted sections are asserted non-empty before
  anything is judged inside them; and the honesty fragment is asserted **still
  present in the whole file** in each language — the survival of those
  out-of-section occurrences is what proves the grep instrument reads and the
  fragment's spelling is right, so a renamed fragment cannot make the
  section-scoped absence pass vacuously.
  - adopter-surface: `docs/adopting.md` and `docs/adopting.ja.md`, inside the existing `## Declaring adopter-facing documentation` / `## adopter 向けドキュメントの宣言` sections.
  - check: rc=0; E=docs/adopting.md; J=docs/adopting.ja.md; test -s "$E" || exit 1; test -s "$J" || exit 1; ne=$(grep -c '^## ' "$E" || true); nj=$(grep -c '^## ' "$J" || true); test "${ne:-0}" -gt 0 || rc=1; test "$ne" = "$nj" || rc=1; test "$ne" = "21" || rc=1; grep -qF -- '## Declaring adopter-facing documentation' "$E" || rc=1; grep -qF -- '## adopter 向けドキュメントの宣言' "$J" || rc=1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac16.XXXXXX") || exit 1; sec() { awk -v h="$2" '$0==h{f=1;next} f && /^## /{exit} f{print}' "$1"; }; sec "$E" '## Declaring adopter-facing documentation' > "$T/es"; sec "$J" '## adopter 向けドキュメントの宣言' > "$T/js"; test -s "$T/es" || rc=1; test -s "$T/js" || rc=1; for f in "$T/es" "$T/js"; do grep -qF -- 'bin/check-adopter-docs.sh' "$f" || rc=1; grep -qF -- '- shipped-docs:' "$f" || rc=1; done; grep -qF -- 'no mechanical checker ships for it yet' "$T/es" && rc=1; grep -qF -- '機械的なチェッカーはまだ出荷' "$T/js" && rc=1; grep -qF -- 'no mechanical checker ships for it yet' "$E" || rc=1; grep -qF -- '機械的なチェッカーはまだ出荷' "$J" || rc=1; for f in "$E" "$J"; do grep -qF -- 'version-derivation' "$f" || rc=1; done; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: a task adds or removes a `^## ` heading in either adopting page, at which point the declared 21 no longer describes the population this criterion counts.

- [ ] **AC17** CI wires the new script and suite without editing the existing
  `shellcheck` step. `.github/workflows/check-handoff.yml` carries a second step
  named `shellcheck (T-1151 additions)` whose `run:` names both
  `bin/check-adopter-docs.sh` and `tests/check-adopter-docs/run.sh`; it carries a
  step running `bash tests/check-adopter-docs/run.sh`; the pre-existing step
  named exactly `shellcheck` is still present and its `run:` line is
  **byte-identical** to the branch point's committed blob; and this task **adds
  no step that reads `.shell-team/specs/*.md` as a glob**, asserted
  base-relatively as "the count of that literal in the working file equals its
  count in the branch-point blob". That clause is a base-relative delta rather
  than a whole-file absence because the literal **already occurs** at the branch
  point, inside an existing `derive-populations.sh` step this task must not
  edit; an absence assertion would therefore be red today and after every future
  merge, while what this criterion actually needs to forbid is a *new*
  occurrence. Positive controls: the workflow is asserted readable and
  non-empty, the branch-point blob asserted non-empty, both extracted `run:`
  lines asserted non-empty before comparison, and the base-side count asserted
  `>= 1` — so a failed read of the base blob, which would yield zero, cannot
  make the equality hold vacuously against a working file that also lost the
  step.
  - check: rc=0; W=.github/workflows/check-handoff.yml; test -s "$W" || exit 1; PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac17.XXXXXX") || exit 1; git show "$B:$W" > "$T/base" 2>/dev/null || rc=1; test -s "$T/base" || rc=1; ext() { awk '/^      - name: shellcheck$/{f=1;next} f && /^        run: /{print;exit}' "$1"; }; ext "$T/base" > "$T/rb"; ext "$W" > "$T/rn"; test -s "$T/rb" || rc=1; test -s "$T/rn" || rc=1; cmp -s "$T/rb" "$T/rn" || rc=1; grep -qF -- 'name: shellcheck (T-1151 additions)' "$W" || rc=1; awk '/^      - name: shellcheck \(T-1151 additions\)$/{f=1;next} f && /^        run: /{print;exit}' "$W" > "$T/add"; test -s "$T/add" || rc=1; grep -qF -- 'bin/check-adopter-docs.sh' "$T/add" || rc=1; grep -qF -- 'tests/check-adopter-docs/run.sh' "$T/add" || rc=1; grep -qF -- 'bash tests/check-adopter-docs/run.sh' "$W" || rc=1; g_now=$(grep -cF -- '.shell-team/specs/*.md' "$W" || true); g_base=$(grep -cF -- '.shell-team/specs/*.md' "$T/base" || true); test "${g_base:-0}" -ge 1 || rc=1; test "${g_now:-x}" = "${g_base:-y}" || rc=1; rm -rf "$T"; test "$rc" -eq 0
  - stale-at: a task adds a second step named exactly `shellcheck` to the workflow, at which point this criterion's single-anchor extraction no longer identifies the step it pins.

- [ ] **AC18** `.shell-team/test-recipe.md` gains a `T-1151` entry under its
  `## Appended by tasks` heading naming the new suite, and every non-blank line
  the branch point's committed blob carries is still present verbatim in the
  working file — the mechanical form of "this log is appended to, never
  rewritten". Positive controls: the file and the branch-point blob are both
  asserted non-empty first.
  - check: rc=0; F=.shell-team/test-recipe.md; test -s "$F" || exit 1; PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac18.XXXXXX") || exit 1; grep -qF -- '## Appended by tasks' "$F" || rc=1; awk '/^## Appended by tasks$/{f=1} f' "$F" > "$T/tailsec"; test -s "$T/tailsec" || rc=1; grep -qF -- 'T-1151' "$T/tailsec" || rc=1; grep -qF -- 'tests/check-adopter-docs' "$T/tailsec" || rc=1; git show "$B:$F" > "$T/base" 2>/dev/null || rc=1; test -s "$T/base" || rc=1; while IFS= read -r l; do test -n "$l" || continue; grep -qxF -- "$l" "$F" || rc=1; done < "$T/base"; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC19** This task's own diff is confined to a fixed allow-list. The union
  of four reads — the committed range `git diff --no-renames --name-only
  <base>...HEAD`, the staged delta, the unstaged delta, and the untracked strays
  from `git ls-files --others --exclude-standard` — contains no path outside the
  fourteen this task declares. **This criterion is merge-point-scoped and is
  expected to go stale after merge**, once later tasks' files land on the same
  base ref; that staleness is expected and is never to be repaired by widening
  the base-ref resolution or re-deriving the criterion per rework round. Positive
  control: the measured union is asserted non-empty, so an empty read cannot
  satisfy the allow-list vacuously.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac19.XXXXXX") || exit 1; PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1; { git diff --no-renames --name-only "$B"...HEAD; git diff --no-renames --cached --name-only; git diff --no-renames --name-only; git ls-files --others --exclude-standard; } > "$T/raw" || rc=1; LC_ALL=C sort -u "$T/raw" > "$T/got"; test -s "$T/got" || rc=1; printf '%s\n' .github/workflows/check-handoff.yml .shell-team/interventions/T-1151.md .shell-team/provenance/T-1151.md .shell-team/reviews/T-1151.md .shell-team/specs/T-1151-adopter-docs-checker.md .shell-team/test-recipe.md .shell-team/todo.md agents/pm-spec.md bin/check-adopter-docs.sh docs/adopting.ja.md docs/adopting.md skills/run/SKILL.md templates/prompt-blocks/adopter-docs-declaration.md tests/check-adopter-docs/run.sh | LC_ALL=C sort -u > "$T/allow"; comm -23 "$T/got" "$T/allow" > "$T/extra"; test ! -s "$T/extra" || rc=1; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC20** This task dogfoods its own rule: `bash bin/check-adopter-docs.sh
  .shell-team/specs/T-1151-adopter-docs-checker.md` exits `0` with zero bytes on
  both streams, and this spec's own declaration region carries exactly one
  `- user-visible:` line and **six or more** unindented `- shipped-docs:` lines,
  every one of whose `this-task` paths is named in a `- check:` or
  `- adopter-surface:` line of this same file. Positive control: this spec file
  is asserted readable and non-empty and the counted `- shipped-docs:` set
  asserted non-empty before the per-path relation is judged.
  - check: rc=0; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1151-adopter-docs-checker.md; test -s "$C" || exit 1; test -s "$S" || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac20.XXXXXX") || exit 1; bash "$C" "$S" >"$T/o" 2>"$T/e"; r=$?; test "$r" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; test "$(grep -c '^- user-visible:' "$S" || true)" = "1" || rc=1; grep '^- shipped-docs:' "$S" > "$T/sd"; test "$(grep -c . "$T/sd" || true)" -ge 6 || rc=1; grep -E '^[[:space:]]*- (check|adopter-surface):' "$S" > "$T/meas"; test -s "$T/meas" || rc=1; while IFS= read -r l; do p=$(printf '%s' "$l" | sed 's/^- shipped-docs:[[:space:]]*//; s/[[:space:]]*—.*$//'); test -n "$p" || { rc=1; continue; }; grep -qF -- "$p" "$T/meas" || rc=1; done < "$T/sd"; rm -rf "$T"; test "$rc" -eq 0

- [ ] **AC21** The change is forward-only and no merged spec is retrofitted. No
  spec file other than this one carries a `- shipped-docs:` line, measured over
  the branch point's committed tree plus HEAD; and the committed range of this
  task modifies no file under `.shell-team/specs/` other than this task's own
  spec. Positive control: the enumeration of spec files is asserted non-empty
  before the absence is judged, so a failed enumeration cannot read as a clean
  absence.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1151-ac21.XXXXXX") || exit 1; PB=feature/566-codex-wait-on-spawned-role; if git show-ref --verify --quiet "refs/heads/$PB"; then B=$(git merge-base "$PB" HEAD); elif git show-ref --verify --quiet "refs/remotes/origin/$PB"; then B=$(git merge-base "refs/remotes/origin/$PB" HEAD); else B=$(git merge-base "develop" HEAD); fi || exit 1; test -n "$B" || exit 1; git ls-files -- '.shell-team/specs/*.md' > "$T/all"; test -s "$T/all" || rc=1; git grep -l -e '^- shipped-docs:' HEAD -- '.shell-team/specs/*.md' > "$T/hit"; s=$?; test "$s" -le 1 || rc=1; sed 's#^HEAD:##' "$T/hit" | LC_ALL=C sort > "$T/hits"; printf '%s\n' .shell-team/specs/T-1151-adopter-docs-checker.md > "$T/want"; cmp -s "$T/hits" "$T/want" || rc=1; git diff --no-renames --name-only "$B"...HEAD -- '.shell-team/specs' | LC_ALL=C sort > "$T/ch"; comm -23 "$T/ch" "$T/want" > "$T/extra"; test ! -s "$T/extra" || rc=1; rm -rf "$T"; test "$rc" -eq 0

## Input space

**Reachable input classes** — inputs this checker must handle correctly because
this loop's own specs, and an adopter's, really produce them:

1. A conformant spec: one unindented declaration in the declaration region, a
   discharge marker of one kind, zero or more `- shipped-docs:` lines.
2. A spec that **quotes its own governing grammar** inside a fenced block —
   backtick-fenced with or without an info string, and (new) tilde-fenced —
   including quoting the intent-block markers themselves. This repository's
   specs do this routinely; T-1061's own spec does.
3. A spec with **more than one** in-scope `- adopter-surface:` or
   `- adopter-docs-waiver:` occurrence, in either order, some with empty values.
4. A spec carrying discharge-shaped example lines in mutable prose after the
   `END` marker (`## Notes for engineer`, `## Assumptions`).
5. CRLF-terminated lines, and lines with trailing whitespace around the em-dash
   separator.
6. Input errors an ordinary invocation reaches: no argument, an extra positional
   argument, an unknown flag, a missing path, a directory, a dangling symlink,
   an unreadable regular file.
7. A spec whose intent-block marker pair does not resolve to exactly one region:
   zero, duplicated, reversed, or fenced-only.
8. A spec whose `- shipped-docs:` path names a document that does not exist in
   this checkout (an adopter's layout, a path created later in the same task).

**Out-of-scope synthetic extremes** — inputs this spec explicitly declines to
protect, named concretely so the boundary is falsifiable:

1. Adversarially nested or interleaved fence constructions beyond "a longer or
   equal run of the same character closes": a fence opener inside an HTML
   comment, a fence inside a blockquote or list-continuation context, indented
   code blocks (four-space), and CommonMark link-reference or setext
   constructions. This checker is an honest-error tool over specs this loop
   produces, not a CommonMark parser.
2. Unicode confusables for the em-dash separator (en dash, horizontal bar,
   minus sign) and for the grammar tokens themselves. The separator is the
   literal U+2014 and nothing else.
3. Spec files above a few thousand lines, or with lines above a few thousand
   bytes — no performance bound is asserted.
4. Any input whose correct handling would require opening, resolving, globbing
   or stat-ing a path named in an `- adopter-surface:` or `- shipped-docs:`
   line. This is refused by design, not unimplemented.
5. Concurrent modification of the spec file while the checker reads it.
6. Binary content, NUL bytes, and non-UTF-8 encodings in a spec file.

<!-- END intent-block: T-1151 -->

## Body-to-AC correspondence

| # | Body directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Stateless predicate over one spec file; exit 0/1/2 (Goal) | **AC8**, **AC10**, **AC12** |
| 2 | One token alone on stderr, zero bytes on stdout (Goal) | **AC8** |
| 3 | Closed set of fourteen tokens (Goal) | **AC7** |
| 4 | Three orthogonal state variables, every line transitions each (Goal) | **AC3**, **AC4**, **AC5** |
| 5 | Fence tracks backtick **and** tilde, len ≥ 3, closes on same char ≥ len (Goal) | **AC2** |
| 6 | **R** closes at the first `^## ` after BEGIN, never unbounded (Goal) | **AC4** |
| 7 | **S** opens on `## Acceptance criteria` and unindented `- [ ] **ACn**` (Goal) | **AC3**, **AC5** |
| 8 | A delimiter line is never content (Goal) | **AC2**, **AC3** |
| 9 | Non-content lines run **explicitly listed identity transitions**, never a skip (Goal) | **AC3** |
| 10 | Verdict from an order-independent multiset under one frozen precedence (Goal) | **AC6** |
| 11 | Seven positional requirements preserved exactly (Goal) | **AC5** |
| 12 | Waiver has no AC-nesting requirement of its own (Goal) | **AC5** (probes p3/p4 place it top-level) |
| 13 | `- shipped-docs:` grammar, unindented, inside **R** (Goal) | **AC9**, **AC10** |
| 14 | Four new tokens mirroring the declaration family's symmetry (Goal) | **AC10**, **AC11** |
| 15 | `shipped-docs-unmeasured` is a same-file string relation (Goal) | **AC11** |
| 16 | Checker never opens/stats/resolves/pattern-matches a path (Goal, Non-goals) | **AC11** |
| 17 | `- shipped-docs:` beside `no` reuses `marker-conflict`; no fifteenth token (Goal, Non-goals) | **AC12** |
| 18 | Fixture suite derived one-way from the transition table (Goal) | **AC13** |
| 19 | Forward-only in the caller; first freeze only (Goal) | **AC14** (the bullet's own scope sentence), **AC21** |
| 20 | No spec retrofitted; this spec is the only one with `- shipped-docs:` (Goal, Non-goals) | **AC21**, **AC20** |
| 21 | No corpus sweep in CI (Non-goals) | **AC17** (the base-relative `.shell-team/specs/*.md` glob-count clause — no *new* occurrence; one already exists at the branch point) |
| 22 | No merged criterion repaired, widened or annotated (Non-goals) | **AC21** |
| 23 | No edit to the freeze pipeline's existing scripts (Non-goals) | **AC19** (allow-list excludes them) |
| 24 | No README, lessons-corpus or existing-spec edit (Non-goals) | **AC19**, **AC21** |
| 25 | Generated prompt-block region byte-identical (Non-goals) | **AC15** |
| 26 | Sibling prose gates untouched (Non-goals) | **AC14** |
| 27 | Existing `shellcheck` step byte-identical (Non-goals) | **AC17** |
| 28 | Adopter docs land in the same task, both languages, no new heading (Goal via `user-visible: yes`) | **AC16** |
| 29 | Grammar exists once, registered, verbatim in both consumers (Goal) | **AC9** |
| 30 | `agents/pm-spec.md` self-check names the checker (Goal) | **AC15** |
| 31 | Suite and script satisfy the exec-bit lock (Goal, implied by shipping under `bin/`/`tests/`) | **AC1** |
| 32 | Test recipe gains the suite entry (`## Wiring`) | **AC18** |
| 33 | No exit contract, token name or positional requirement re-litigated (Non-goals) | info-only (not promoted to AC) — a negative about *design process*, not about an observable artifact state; **AC5** and **AC7** already pin the inherited inventories, so a re-litigation would show up there. |
| 34 | No full-population two-arm sweep inside this task (Non-goals) | info-only (not promoted to AC) — a disclosed process deviation under the operator's standing mode-A2 ruling; a criterion asserting that a sweep did *not* run would gate on absence of evidence, which is unfalsifiable. Recorded in `## Blast radius`. |
| 35 | No new status flag, board field, telemetry key or event id (Non-goals) | info-only (not promoted to AC) — subsumed by **AC19**'s allow-list, which excludes every file those tokens are defined in (`bin/check-handoff.sh`, `bin/log-run.sh`, `templates/`), so the change set cannot reach them. |

## Version derivation note

`CONTRIBUTING.md`'s `## What a version number encodes`, applied item by item to
this task's single backlog item:

| Item | headline test | default-reachability test | derived tier | ground |
|---|---|---|---|---|
| #250 + #577, one spec | **not met** | **met** | PATCH | The gate sits on the shipped default freeze path, so an adopter reaches it without configuring anything — default-reachability is met. But nothing an adopter can newly *do* appears: the declaration duty already shipped in T-1061 as prose, and this task converts a read into an exit code and adds one required line to the same existing declaration. "Internal mechanisms … are PATCH regardless of diff size." |

Sprint tier = the maximum of that column = **PATCH**, matching the premise on
record (v2.7.3).

**Reservation, recorded so the freeze-time derivation gate re-judges it
explicitly rather than inheriting this row:** the new required
`- shipped-docs:` line is a *felt* change to the default spec-authoring path —
an author who writes a `user-visible: yes` spec after this ships must write
something they did not have to write before, and a freeze that used to pass now
refuses. That is a stronger adopter-facing consequence than most PATCH-tier
internal work carries, and the headline test's "nothing newly *doable*" reading
is the whole of what holds it at PATCH. If the freeze-time gate reads the
headline test differently, the honest outcome is a deviation notice, not a
silent re-use of this row.

## Shipped-docs inventory

The population is derived by command rather than counted by eye; this role holds
no shell, so the enumeration is run and its output recorded at the freeze run.

- reproduce: git grep -l -E 'user-visible|adopter-surface|adopter-docs-waiver|Declaring adopter-facing documentation|adopter 向けドキュメントの宣言' -- README.md README.ja.md docs skills agents templates

**That command has been run at the freeze sweep, and its output is exactly these
ten paths**: `agents/code-reviewer.md`, `agents/pm-spec.md`,
`agents/tech-lead.md`, `agents/ui-designer.md`, `docs/adopting.ja.md`,
`docs/adopting.md`, `skills/run/SKILL.md`,
`templates/prompt-blocks/adopter-docs-declaration.md`,
`templates/prompt-blocks/playbook-pm-spec.md`,
`templates/prompt-blocks/playbook-tech-lead.md`. Every one of the ten has a row
below and every row carries a disposition; enumerated-but-undecided is zero
against the command's own output rather than against a recollected list. Each of
the five the first draft had missed was opened and read before its disposition
was written, and none of them asserts that no checker ships — which is the one
finding that would have forced `this-task` or a filed issue instead of
`unchanged`.

Four further rows below — `README.md`, `README.ja.md`, `docs/tuning-oversight.md`,
`docs/distribution.md` / `docs/distribution.ja.md`, `CONTRIBUTING.md` — are
**not in the command's output**. They are retained deliberately, marked as such,
because a reader asking "why was the README not updated for an adopter-facing
change?" is better served by an explicit answer than by the row's absence; they
carry no weight in the zero-undecided count, which is taken over the ten the
command returned.

| Shipped document | Disposition | Ground |
|---|---|---|
| `templates/prompt-blocks/adopter-docs-declaration.md` | **this-task** | The canonical grammar; the `- shipped-docs:` line is added here and nowhere else. |
| `agents/pm-spec.md` | **this-task** | Its `## Spec completion self-check` states the declaration duty and denies a checker; both statements move. |
| `skills/run/SKILL.md` | **this-task** | Its `:51` bullet *is* the gate; it becomes a checker call. |
| `docs/adopting.md` | **this-task** | The adopter-facing statement of the mechanism and its honesty sentence. |
| `docs/adopting.ja.md` | **this-task** | Same, Japanese. |
| `.shell-team/test-recipe.md` | **this-task** | The suite's run procedure lands here. (Not in the command's output — the command's pathspec does not cover `.shell-team/`; retained because the task really does edit it.) |
| `agents/code-reviewer.md` | **unchanged** | Read first-hand at `:171`: it names the spec's declaration region as a **read surface** for spec-review mode, enumerating `- user-visible:` / `- verification-class:` / `- base-ref-discriminator:` as examples. It makes no claim that a checker is or is not shipped, so nothing in it goes stale when the gate becomes an exit code. Its parenthetical enumeration is **already incomplete** at the branch point — `- verification-ceiling:` (T-1093) is absent from it — so declining to add `- shipped-docs:` follows the precedent T-1093 set rather than creating a new gap. See the note below this table. |
| `agents/tech-lead.md` | **unchanged** | Read first-hand at `:166`: a **generated** lessons-playbook line (the 2026-09-19 adopter-docs-gate lesson). It lives inside a `<!-- BEGIN/END prompt-block: playbook-tech-lead -->` region regenerated by lesson promotion, which this spec's own Non-goals forbid hand-editing. |
| `agents/ui-designer.md` | **unchanged** | Read first-hand at `:124`: the phrase is `no user-visible UI surface` in the design-decline template — ordinary English about a UI surface, **not** the declaration grammar. A false positive of the enumeration pattern, carrying no statement about this mechanism at all. |
| `templates/prompt-blocks/playbook-pm-spec.md` | **unchanged** | Read first-hand at `:65` (the 2026-08-11 freeze-time-blocker lesson) and `:100`. A **generated** block, regenerated from `.shell-team/lessons.md` by `bin/gen-playbook-blocks.sh`; both the block and the corpus are outside this task's allow-list by its own Non-goals. Neither line claims a checker's absence — they state the pm-spec authoring duty, which this task does not change. |
| `templates/prompt-blocks/playbook-tech-lead.md` | **unchanged** | Same class: a generated lessons-playbook block, the source of `agents/tech-lead.md:166` above. Hand-edit-forbidden; regenerated only by lesson promotion. |
| `README.md` | **unchanged** (not in the command's output) | The READMEs delegate this mechanism's detail to the adopting pages and describe no part of the declaration grammar; T-1061's own Non-goals settled that a README section would create a second place for the grammar to drift. |
| `README.ja.md` | **unchanged** (not in the command's output) | Same ground, Japanese. |
| `docs/tuning-oversight.md` | **unchanged** (not in the command's output) | It documents the re-freeze class boundary, which this task does not move; the declaration is not a re-freeze surface. |
| `docs/distribution.md` / `docs/distribution.ja.md` | **unchanged** (not in the command's output) | They cover install and update paths; no new install step, no new adopter-invoked command name. |
| `CONTRIBUTING.md` | **unchanged** (not in the command's output) | Its version-encoding section is cited by `## Version derivation note` but not modified; this task changes no versioning rule. |

Enumerated-but-undecided rows: **zero**, taken over the ten paths the command
returned. Follow-up issues filed for a stale row: **zero**.

**One row is a judgment call and is named rather than buried**:
`agents/code-reviewer.md:171`'s parenthetical list of declaration-region keys is
the only surfaced document where a reader could argue the 2026-09-19 lesson's
two-way choice ("updated in this task" or "a filed follow-up issue naming it
explicitly") applies instead of `unchanged`. It is recorded `unchanged` because
the list is an illustrative enumeration that was **already** out of date before
this task existed, and closing half of a pre-existing gap in a file outside this
task's scope allow-list would be the scope creep the allow-list exists to
prevent. Whoever holds issue-filing capability may reasonably file one covering
both missing keys at once (`- verification-ceiling:` and `- shipped-docs:`);
this task does not, and says so here rather than leaving the choice implicit.

## Blast radius

`- verification-class: mechanism`. The read-set is derived at run time rather
than restated as a count:

- reproduce: git grep -l -E '^[[:space:]]*- check:.*(check-adopter-docs|adopter-docs-declaration|pm-spec\.md|skills/run/SKILL|adopting|check-handoff\.yml|test-recipe)' -- .shell-team/specs

**Pre-existing red, not caused by this task.**
`CHECK_ACS_TIMEOUT=300 bash bin/check-acs.sh .shell-team/specs/T-1061-adopter-docs-gate.md`
was measured by the coordinating session at the branch point as **1 passed
(AC10), 9 failed (AC1 AC2 AC3 AC9 AC11 AC12 AC13 AC14 AC15), 1 skipped** — a
relayed measurement (see `## Assumptions`). Those criteria resolve their base
through a branch that no longer exists in this checkout, so they are red for a
structural reason unrelated to this task's diff. They are recorded here as
**pre-existing red**, and the reviewing gates should not be told they are flips
this task caused.

**Predicted flips this task does cause.** Criteria in merged specs that assert
byte-identity or a heading/occurrence count over `skills/run/SKILL.md`,
`agents/pm-spec.md`, `docs/adopting.md`, `docs/adopting.ja.md`,
`templates/prompt-blocks/adopter-docs-declaration.md`,
`.github/workflows/check-handoff.yml` or `.shell-team/test-recipe.md` will move,
because this task edits all seven. The heading-count criteria specifically
should **not** flip: `## ` totals stay 21/21 in both adopting pages and no new
heading lands anywhere (**AC16**, **AC17**).

**Disclosed deviation.** The full-population two-arm inventory this class
normally owes is **deferred to the release sweep** under the operator's standing
mode-A2 ruling. The 2026-09-19 docs-only carve-out does **not** apply — this
task's diff reaches `bin/`, `tests/`, `templates/`, `skills/` and `.github/`.
This deviation is disclosed, not closed.

**Indirection class, named rather than left to be discovered.** A merged
criterion that reaches one of the seven edited paths through a value built at
run time (a path resolved through `bin/team-paths.sh --get todo` or `--get
specs`, a file named only through a shell variable) matches none of the literal
bytes the `- reproduce:` command above searches for, and is invisible to the
read-set derivation in principle. It is discharged here by **disclosure**: the
release sweep's full-population arm is what covers it, and until that runs it
stays unmeasured.

## Review depth

This task's deliverable is a **shipped shared checker** under `bin/` — the
loop's own trust base, executed by every adopter's freeze. The dev-scaffold
carve-out recorded for a spec's own inline `- check:` lines does **not** apply:
review runs at full strength and adversarial depth against
`bin/check-adopter-docs.sh` and `tests/check-adopter-docs/run.sh`.

The reference class is against us and is stated rather than discovered mid-loop:
a hand-written bash parser in this repository has a recorded probability of
**≤0.3** of passing two adversarial review rounds, and the previous generation
of *this exact component* was defeated in two consecutive rounds and carved out.
The mitigation this task offers is a change in kind rather than in effort: the
fixture matrix is **derived one-way from an explicit transition table** instead
of enumerated from imagination, so a blind spot in the implementation shows up
as a table row with no case rather than as a case nobody thought to write. That
is the whole of the mitigation; it is not a claim that the reference class has
moved.

## Reading-judgment sweep round

This spec deliberately declines to fix a mechanical pre-check for one inventory:
"every row of the transition table has a fixture, and no fixture exists the
table does not license" cannot be reduced to a grep without freezing a
vocabulary this task has no authority to close. It is left to the verifying
roles' reading judgment, and the round it becomes a systematic sweep is named
here: **the second finding in that one meta-class converts the next engineer
round into a full sweep, delivered as a table** (table row × fixture id ×
present/absent/not-applicable-with-reason), rather than an ad-hoc response to
each individual finding.

## Pre-commitment

Labelled **AI self-discipline** except where a clause names an operator ruling.

**Never-dropped:**

1. The three-variable state machine, its transition table, and the closure of R1
   Major #1 (discharge-marker scope), R1 Major #2 (order independence) and the
   open R2 Major (fenced-line scope effect) in `bin/check-adopter-docs.sh`.
2. `tests/check-adopter-docs/run.sh`, derived from the table, including
   `cad-fence-*`, `cad-scope-*` and the fence/no-fence control pair.
3. CI wiring (second `shellcheck` step plus the suite step).
4. The run-skill call and the `agents/pm-spec.md` update.
5. The `docs/adopting.*` update (the declared adopter surface).

**Defeat of a never-dropped component across two consecutive rounds → stop the
task and return to planning.** Not a third patch round. The previous generation
of this same component already fired T-1061's pre-commitment; a second
generation failing is evidence about the design premise rather than about this
implementation's craft. This clause cites the **2026-09-06 T-1121 operator
ruling** — an operator-ratified ruling, not AI self-discipline.

**Droppable, in order:**

1. **The #577 group** — the grammar line, the four `shipped-docs-*` tokens, the
   `cad-shipped-*` fixtures, and the adopting-page paragraph. Disposition:
   returned to issue **#577**, with that round's findings travelling as the
   requirement list rather than being re-derived there.
2. **Tilde-fence support** (the carved-out generation's Minor #4). Disposition:
   a new issue, same travelling-findings rule.

**Trigger:** two consecutive review or QA rounds producing an independent
Blocker or Major on the same droppable component.

## Assumptions

**Measured first-hand by this role** (file reads in this checkout):

- The salvage checker's R2 defect is at `:388`–`:391`: an unconditional
  `continue` on `FENCED[i] -eq 1`, placed before `in_ac` can be cleared, so
  `in_ac` survives a fence. The relayed line numbers **hold exactly**.
- The salvage suite carries **42** cases (41 `assert_case` calls plus one
  manually counted `--help` case).
- The salvage suite's fence × scope gap: its `cad-fence-*` cases probe only
  declaration and marker inertness and its `cad-scope-*` cases carry no fence,
  so **no** case among the 42 crosses the two dimensions. (The brief's phrasing
  "no `cad-fence-*` / `cad-scope-*`" understates what is there; the accurate
  measured gap is the cross-product, and it is stated that way above.)
- `grep -c 'no checker ships for it yet' skills/run/SKILL.md` = **4** today;
  `agents/pm-spec.md` = **2**.
- `docs/adopting.md` and `docs/adopting.ja.md` each carry **21** `^## `
  headings.
- `.github/workflows/check-handoff.yml` has exactly **one** step named
  `shellcheck`, at `:28`, its `run:` one physical line at `:29`.
- `templates/prompt-blocks/registry.txt:45` is
  `contain adopter-docs-declaration.md agents/pm-spec.md skills/run/SKILL.md`.
- `refs/heads/feature/566-codex-wait-on-spawned-role` **exists as a local
  branch** in this checkout (read from `.git/refs/heads/…`) and points at this
  branch's point of divergence, so the first arm of the base-ref discriminator
  is the one that resolves today.

**Relayed — not measurable from this role**, each naming the side holding the
primary confirmation, to be measured and reported beside this line at the freeze
run:

- PR #579's state (`open`, `merged=false`, head `cf97531d`, base `develop`).
  Held by the coordinating session via the GitHub API. This is the premise that
  makes the two-arm discriminator the *required* form rather than a choice.
- The salvage blobs' origin commit `5859e247^`. Held by the coordinating
  session; the blobs themselves were read first-hand, their provenance was not.
- The T-1061 pre-existing-red measurement (1 passed / 9 failed / 1 skipped, and
  that `chore/lesson-promotion-2026-08-11` no longer resolves in this checkout).
  Held by the coordinating session. Measurement command:
  `CHECK_ACS_TIMEOUT=300 bash bin/check-acs.sh .shell-team/specs/T-1061-adopter-docs-gate.md`.

**Borrowed-vocabulary count premises**, enumerated per the classification duty;
the execution-capable side runs each at the branch point's committed blob and
records the measured value here before the freeze. **Measured at the branch point `cf97531d` by the coordinating session (2026-09-19 freeze sweep)**: `no checker ships for it yet` **4** / **2**; `^## ` **21** / **21**; `- shipped-docs:` **0**; the four `shipped-docs-*` tokens **0** each; `name: shellcheck` step **1**; `cad-` **6 occurrences in tracked files** — in `.shell-team/reviews/T-1061.md` (1), `.shell-team/specs/T-1061-adopter-docs-gate.md` (2) and `.shell-team/todo.md` (3), all inside T-1061's own records quoting the carved-out suite's class ids — so the row below's "zero in tracked files" premise is **corrected to six-in-records / zero-in-shipped-files**; no criterion of this spec depends on that count (AC13 reads the suite file it ships, not the tree):

| Token | Class | Premise | Measurement command at the branch point |
|---|---|---|---|
| `no checker ships for it yet` | **borrowed** (coined by T-1061, reused by T-1081, T-1093, T-1110) | 4 in `skills/run/SKILL.md`, 2 in `agents/pm-spec.md` | `git show "$B:skills/run/SKILL.md" \| grep -c 'no checker ships for it yet'; git show "$B:agents/pm-spec.md" \| grep -c 'no checker ships for it yet'` |
| `^## ` | **borrowed** (heading vocabulary asserted by merged criteria) | 21 in each adopting page | `git show "$B:docs/adopting.md" \| grep -c '^## '; git show "$B:docs/adopting.ja.md" \| grep -c '^## '` |
| `- shipped-docs:` | **own-coinage** | zero occurrences anywhere at the branch point | `git grep -c -- '- shipped-docs:' "$B" -- . \|\| echo 0` |
| `shipped-docs-missing`, `shipped-docs-malformed`, `shipped-docs-misplaced`, `shipped-docs-unmeasured` | **own-coinage** | zero occurrences anywhere at the branch point | `for t in shipped-docs-missing shipped-docs-malformed shipped-docs-misplaced shipped-docs-unmeasured; do git grep -c -- "$t" "$B" -- . \|\| echo "0 $t"; done` |
| `name: shellcheck` | **borrowed** (workflow step vocabulary) | exactly 1 step so named | `git show "$B:.github/workflows/check-handoff.yml" \| grep -c '^      - name: shellcheck$'` |
| `cad-` class-id prefix | **own-coinage carried from the salvage** (the salvage is untracked scratch, so zero in tracked files) | zero occurrences in shipped (non-record) files at the branch point; six in T-1061's own records — measured, see the sentence above | `git grep -c -- 'cad-' "$B" -- . \|\| echo 0` |

## Open questions

1. **The waiver's window: intent block, or declaration region?** The brief's
   token map places `- adopter-docs-waiver:` in `R-decl`, while its own fixed
   inventory of the seven positional requirements places it "unindented + inside
   intent block". These disagree, and **no fixture among the salvage's 42
   distinguishes them** (its `cad-order-waiver-*` cases put the waiver right
   after the declaration, where both readings agree; its
   `cad-scope-notes-unfenced-waiver` case puts it after `END`, where both
   readings refuse). This spec freezes the **intent-block** reading, because
   narrowing to `R-decl` would narrow a positional requirement T-1061 already
   froze in its Goal ("the spec carries a top-level … line"), which is a
   behaviour change to merged frozen intent's meaning rather than a design
   choice this task is free to make. **AC5**'s probes p3/p4 are written to that
   reading. Flagged for the freeze run to confirm or overrule; if overruled, the
   correction is confined to **AC5** and is meaning-preserving.

## Notes for engineer

**Salvage, and how to use it.** The carved-out checker and suite are at
a scratch directory the coordinating session extracts with `git show 5859e247^:bin/check-adopter-docs.sh`, `git show 5859e247^:tests/check-adopter-docs/run.sh` and `git show 5859e247^:.github/workflows/check-handoff.yml` — re-extract them yourself with those commands under `$TMPDIR`; never write them into the repository.
Reuse the symlink-safe `SCRIPT_DIR` resolver, the `refuse()` helper, the
argument parser, the `trim()` function, the em-dash split rule and the
`assert_case` harness verbatim. **Do not** reuse the fence/scope scanning
structure: the single `continue` at `:388`–`:391` is the open finding, and the
whole point of the rewrite is that `F`, `R` and `S` become three explicit
per-line transitions with identity rows listed, not a pre-computed `FENCED[]`
array consumed by a skip.

**Refusal precedence, frozen.** Decide from the multiset in this fixed order, so
the verdict never depends on file order: `usage`, `spec-unreadable`,
`intent-block-missing`, `declaration-missing`, `declaration-duplicate`,
`declaration-malformed`, `declaration-misplaced`, `marker-conflict`,
`waiver-reason-empty`, `obligation-undischarged`, `shipped-docs-misplaced`,
`shipped-docs-malformed`, `shipped-docs-missing`, `shipped-docs-unmeasured`.
The `shipped-docs-*` family sits **last** deliberately: it preserves every one
of the salvage's 42 refusal verdicts unchanged, so the only salvaged fixtures
whose *input* must change are the six `yes`-declaring pass cases
(`cad-pass-surface`, `cad-pass-waiver`, the four `cad-order-*`), which each gain
a conformant `- shipped-docs:` line, plus `cad-dogfood`, whose target becomes
this task's own spec.

**Separator rule, decided deliberately** (issue #250 requirement 6): the
`- shipped-docs:` line uses the **same** rule as the declaration — split on the
first em-dash character, trim both sides — rather than requiring a literal
` — ` with exactly one space each side. Ground: two different separator rules
inside one canonical grammar file is precisely the drift this block exists to
prevent, and the declaration's rule is already frozen.

**Disposition vocabulary is closed** at `this-task` and `issue #<digits>`. An
`unchanged` row lives only in the spec's prose `## Shipped-docs inventory`
section and never gets a `- shipped-docs:` line — that is why the grammar admits
only two dispositions.

**`shipped-docs-unmeasured` reading side**: whole-file, fence-aware, matching
any line whose content matches `^[[:space:]]*- check:` or
`^[[:space:]]*- adopter-surface:`, with the path tested as a **literal
substring** of that line. Never a path resolution, never a glob, never a
`test -f`.

**Measured-at-ref command check**: this task's deliverables print no `measured
at <ref>` label, no `**Base ref**:` header and no per-row `- measurement:`
field — `not applicable — the checker prints only refusal tokens, and the suite
prints only per-case PASS/FAIL lines and a case count`.

**Files likely touched**: exactly the fourteen in **AC19**'s allow-list. Note
that `bin/check-acs.sh`, `bin/check-intent.sh`, `bin/check-refreeze-class.sh`,
`bin/team-paths.sh`, `README*`, every existing spec and `.shell-team/lessons.md`
are **outside** it.

**Prior art for the wiring shape**: the workflow as T-1061 wired it (`git show 5859e247^:.github/workflows/check-handoff.yml`)
`:31`–`:32` and `:273`–`:277`. Note the deliberate divergence: that version's
dogfood step named T-1061's spec; this task's names this task's own spec, and no
step globs `.shell-team/specs/*.md`.
