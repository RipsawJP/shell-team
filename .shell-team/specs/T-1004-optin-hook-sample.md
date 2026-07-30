# T-1004 — the opt-in at-the-moment sample hook, and the honest qualification of "ships no hooks"

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Recorded intent**: v1 (the version of record for this task's intent lives on the board and nowhere else)
**Task ID**: T-1004
**Source**: GitHub issue #37 — "who writes it is the hard part … a rule without a mechanical prompt is a rule that gets followed while it is fresh". The final piece of the #37 arc (T-1002 shipped the channel, T-1003 made the retro read it). Also carries issue #44, T-1003's cross-provider fast-follow. No new issue was opened for the sample itself: #37 already carries the design brief and is the tracker, as it was for T-1002 and T-1003.
**Branch**: `feature/optin-hook-sample` (from `develop` at `415bcd8`).

## Problem

T-1002 shipped the intervention-capture channel and a fail-closed gate; T-1003
made the retro read it. In the shipped default, the one property the whole
mechanism rests on — that a trigger-1 capture happens **at the moment** a human
interrupts, corrects or stops the work — is carried by a standing instruction in
`skills/run/SKILL.md`. Issue #37 named that residual itself: an instruction is
followed while it is fresh, which is precisely the human failure mode this
project set out to improve on. Nothing fires at the moment a user message
arrives, so nothing reminds the orchestrator to classify and record before it
starts acting on the message.

The mechanical fix is a `UserPromptSubmit` hook. But `docs/tuning-oversight.md`
carries a ratified posture — **"This project ships no hooks."** — with its reason
stated: a hook is executable configuration, and a public repository is the wrong
place for one to arrive by default. Left as it is, the project either ships an
active hook against its own documented posture, or keeps the residual and says
nothing about it.

## Goal

<!-- BEGIN intent-block: T-1004 -->

**The mechanical prompt exists, and it ships inert.** One pure-bash,
zero-dependency, shellcheck-clean sample script is added to the repository as a
*readable sample the adopter installs themselves* — which is exactly what
`docs/tuning-oversight.md`'s own Limits paragraph prescribes, and exactly the
distribution shape this repository already uses for its other non-portable piece
(`docs/loop-engineering/loop-cron.crontab.example`: "the framework ships no
scheduler … you wire the clock on your host"). **Nothing activates by default**:
`.claude-plugin/plugin.json` gains no `hooks` key, no file lands on any plugin
load path, no directory named `hooks` exists anywhere in the repository, and the
file is committed non-executable.

**What the sample does, on each `UserPromptSubmit` event.** It resolves the
cwd's board through `team-paths.sh --get todo` (bare name on `PATH`, which is how
`bin/` is reachable while the plugin is enabled) and asks one cheap question: does
that board carry an in-flight task line? If the board is absent, unreadable, or
carries no in-flight line — or if the resolver is not on `PATH` at all — it
**exits 0 with byte-empty stdout and byte-empty stderr: a silent no-op**. That is
the load-bearing behaviour, not a detail: the adopter registers this hook
user-wide, so it fires in *every* repository they open, and it must cost almost
nothing and say nothing everywhere shell-team is not in play. Otherwise it emits
one line of JSON on stdout — the `hookSpecificOutput.additionalContext` form —
carrying a one-line reminder to classify the message and append the entry to the
task's interventions file **now, before acting on it**, and stating that a routine
gate response gets no entry.

**The hook never reads the user's message.** It drains stdin without parsing it
and reads no field of the event JSON — not `prompt`, not `cwd`. Classification is
the orchestrator's judgment; the hook's whole job is to prompt that judgment at
the right moment. No byte of the user's message, and no byte of the board, ever
reaches stdout, stderr, or any file: the emitted string is a fixed constant.

**Fail-open here, and only here.** Any internal failure — an unreadable board, a
missing resolver, a malformed event, a `grep` that cannot read its input —
degrades to the silent no-op. This deliberately inverts this repository's
fail-closed norm, and the inversion is sound because of what the component is: a
hook runs inside the adopter's session and must never break it, and this hook is
an **enhancer**, not a gate. Its absence returns the operator to the shipped
default — instruction-strength capture — while the parts that actually gate
(`bin/check-interventions.sh` and the Implement-to-Validate gate) stay fail-closed
and are not touched.

**The two documentation surfaces tell the truth, in both languages.**
`docs/tuning-oversight.md` and `docs/tuning-oversight.ja.md` keep the "ships no
hooks" sentence — it stays true, because no *active* hook ships — and gain the
qualification: the project now ships one inert, readable sample you install
yourself, which is what the Limits paragraph already told you to do. Both files
also state the capture-fidelity asymmetry honestly: in the shipped default the
at-the-moment property is instruction-strength; with the sample installed it is
mechanically prompted; and in neither case does anything prove that every
intervention was recorded. Both files carry the same install snippet, byte-identical
in its code block, and both tell the adopter to read the script before registering
it.

**Issue #44 is closed in the same pass.** `agents/scrum-master.md`'s citation
rule enumerates the accepted citation types and does not name an interventions-file
reference — reachable in practice through the reserved `no-task.md`, where no task
id and no PR exist to cite. One clause is added to that sentence. It is a clause,
not a new numbered item: T-1003's frozen AC16 pins the file's top-level numbered
items at exactly eighteen.

## Non-goals

- **No `hooks` key in `.claude-plugin/plugin.json`, and nothing on a load path.**
  A plugin-shipped active hook is not this task under any review finding. The
  posture decision is the reason the task has the shape it has, not a sequencing
  convenience.
- **No `hooks` directory anywhere in the repository.** `<plugin-root>/hooks/` is a
  discovery convention; the repository stays free of that directory name so the
  "nothing can activate" property is auditable by a single `find`.
- **No change to `skills/run/SKILL.md`, `skills/goal/SKILL.md`,
  `bin/check-interventions.sh`, `templates/prompt-blocks/interventions-classes.md`,
  the seven-class enum, the Implement-to-Validate gate, or the retro ledger.**
  T-1002 and T-1003 shipped those and their criteria are frozen. In particular the
  sample is **not** added as a consumer of `interventions-classes.md`: T-1002's
  frozen AC17 pins that registry row at exactly two consumers, and a third would
  break it. The sample **references** the block's language instead of embedding it.
- **No parsing or classification of the user's message inside the hook**, and no
  per-class or per-trigger logic. The hook has exactly two outcomes.
- **No event other than `UserPromptSubmit`.** Trigger 1 is the trigger with no
  substitute — it arrives from outside and there is no checkpoint to self-check it
  at. Triggers 3 and 5 remain checkpoint self-checks by design (T-1002), and
  `Stop` / `PostToolUse` / `SessionStart` / `PreCompact` are out of scope.
- **No mechanical close-out durability gate.** That is issue #41 and is not
  reopened here.
- **No re-litigation of the ships-no-hooks decision, and no new recording of its
  re-evaluation trigger.** The trigger stays where it is (the board and the
  operator's memory): if the harness ever grows per-hook install consent, the
  decision can be revisited then.
- **No `docs/distribution.md` / `docs/distribution.ja.md` edit.** Considered and
  declined with a reason (DP-6): that document's subject is install and
  distribution surfaces, the sample is neither installed nor enabled by the
  framework, and its prescribing document is `docs/tuning-oversight.md`. A
  fourth and fifth copy of the qualification would be two more drift sites with
  no reader arriving there to look for it.
- **No `README.md` / `README.ja.md` edit.** The sample is not a `templates/`
  scaffold and the README's directory tree does not enumerate individual files.
- **No claim that the harness actually invokes the hook.** Whether Claude Code
  fires `UserPromptSubmit`, injects `additionalContext`, and fires again after an
  Esc interrupt is host-runtime behaviour, verified by an operator dogfooding on a
  real host — exactly the status `docs/distribution.md` already assigns to
  scheduling. This repository's tests prove the script's own contract only.
- **No enforcement claim.** The hook prompts a judgment; it cannot make the
  judgment happen, and no criterion here asserts that it does.

## Acceptance criteria

Every `check:` runs from the repository root with no environment setup and
invokes scripts as `bash bin/<script>.sh` — the spec's invocation convention,
distinct from the agent-instruction convention (bare name on `PATH`) that
T-1001's AC30 governs and that this task must not break.

Four standing rules apply to every criterion below, each learned from a defect
this repository produced:

- **No negated `grep` without a same-target positive control.** A `! grep -q … FILE`
  passes when `FILE` cannot be read, because `grep` exits 2 and the negation
  swallows it.
- **A count is pinned in both directions** wherever a count is the property.
- **Tolerance is proved against input of the tolerated shape that is otherwise
  broken**, never against valid input — a passing valid input cannot distinguish
  "accepted" from "never inspected".
- **A criterion states the boundary of what it proves.** Where a criterion pins a
  fixture *case* by label, the label proves the case exists, not that its
  assertion tests what its name says; reading that attachment is QA's and the
  reviewer's job.

**The two canonical strings this task ships are this spec's bytes.** They exist
in exactly one authoritative place — here — and are copied into the sample and
its suite, which AC3 pins against each other. The emitted stdout is exactly this
one line followed by exactly one newline:

```
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"shell-team: a task is in flight. If this message interrupts, corrects, or stops the work, classify it and append the entry to the task interventions file (team-paths.sh --get interventions) NOW, before acting on the message, then commit it immediately. Use one of the seven classes the run skill lists (canonical source: templates/prompt-blocks/interventions-classes.md). A routine gate response (a plain GO, an approval, or an answer to a question you asked) is not an intervention and gets no entry."}}
```

and the in-flight detection pattern is exactly this ERE (the flag enum
substituted into `bin/check-handoff.sh`'s own enforced line grammar, so detection
keys off a checked invariant rather than a convention; the end anchor is
deliberately absent so a CRLF board still matches):

```
^- \[ \] \*\*T-[0-9]+\*\* .* — `(READY_FOR_ARCH|READY_FOR_ENG|READY_FOR_QA|READY_FOR_REVIEW|READY_FOR_MERGE|BLOCKED|REWORK)` — spec: 
```

**pm-spec has no shell in this role, so no `check:` line below was executed.**
The executing side runs all eighteen live against the pre-implementation tree
before the intent-hash is recorded, corrects any line that is broken as a command
or would pass vacuously (meaning preserved), and only then freezes.

- [ ] **AC1** The sample exists at `docs/interventions-reminder-hook.sample.sh`,
  is a bash script, and is **inert by construction**: committed non-executable
  (git index mode `100644`, and not executable in the working tree), with a header
  comment that says so in the crontab-example idiom — that it is a sample, never
  bundled by `team-init`, never on any load path, and activated only by the
  adopter's own settings file. The header is honest about the one thing CI *does*
  do with it (lint it and run its fixture suite), so no reader concludes from
  "inert" that it is unverified.
  - check: F=docs/interventions-reminder-hook.sample.sh && test -f "$F" && test ! -x "$F" && test "$(git ls-files -s -- "$F" | cut -d' ' -f1)" = 100644 && head -n 1 "$F" | grep -qxF -- '#!/usr/bin/env bash' && grep -qF -- 'never bundled by team-init' "$F" && grep -qF -- 'never on any load path' "$F" && grep -qF -- 'CI does lint this file and run its fixture suite' "$F"

- [ ] **AC2** **Zero activation footprint.** `.claude-plugin/plugin.json` has no
  `hooks` key and the whole `.claude-plugin/` directory is byte-unchanged against
  the base ref; no directory named `hooks` exists anywhere in the repository; and
  the diff adds nothing under `agents/`, `skills/` or `commands/`. Positive
  controls: the manifest is readable and names the plugin, and the overall diff is
  non-empty. **Merge-point-scoped**: the diff halves resolve `develop` and are
  expected to go stale once this task lands there; do not widen the base-ref
  resolution or re-derive them per rework round.
  - check: P=.claude-plugin/plugin.json && grep -qF -- '"name": "shell-team"' "$P" && ! grep -q -- '"hooks"' "$P" && git diff --quiet develop -- .claude-plugin/ && test -z "$(find . -path ./.git -prune -o -type d -name hooks -print)" && d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -E -- '^(agents|skills|commands)/')"

- [ ] **AC3** **The emitted JSON and the reminder are single-sourced from this
  spec and identical in the sample and its suite.** The exact one-line payload
  quoted above appears verbatim exactly once in
  `docs/interventions-reminder-hook.sample.sh` and exactly once in
  `tests/interventions-reminder/run.sh`, and the in-flight ERE quoted above
  appears verbatim in the sample. The reminder contains no `"` and no backslash,
  so the JSON needs no escaping and cannot be broken by a quoting slip — this
  criterion is what holds that property, since it compares against the literal.
  - check: E='{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"shell-team: a task is in flight. If this message interrupts, corrects, or stops the work, classify it and append the entry to the task interventions file (team-paths.sh --get interventions) NOW, before acting on the message, then commit it immediately. Use one of the seven classes the run skill lists (canonical source: templates/prompt-blocks/interventions-classes.md). A routine gate response (a plain GO, an approval, or an answer to a question you asked) is not an intervention and gets no entry."}}' && test "$(grep -cF -- "$E" docs/interventions-reminder-hook.sample.sh)" -eq 1 && test "$(grep -cF -- "$E" tests/interventions-reminder/run.sh)" -eq 1 && grep -qF -- '^- \[ \] \*\*T-[0-9]+\*\* .* — `(READY_FOR_ARCH|READY_FOR_ENG|READY_FOR_QA|READY_FOR_REVIEW|READY_FOR_MERGE|BLOCKED|REWORK)` — spec: ' docs/interventions-reminder-hook.sample.sh

- [ ] **AC4** **With an in-flight board, the sample emits exactly the expected
  bytes** — that one JSON line and exactly one newline on stdout, nothing on
  stderr, exit 0 — resolving the board through the resolver rather than a
  hardcoded path. The fixture is built under an explicit `mktemp` template and the
  resolver is made reachable as a bare name in a throwaway shim directory, whose
  reachability is asserted first as the anti-vacuity positive control: without it
  the sample would silently no-op and the *silence* criteria would pass for the
  wrong reason.
  - check: R="$PWD" && d="$(mktemp -d "${TMPDIR:-/tmp}/t1004ac4.XXXXXX")" && mkdir -p "$d/shim" "$d/.shell-team" && cp "$R/bin/team-paths.sh" "$d/shim/team-paths.sh" && chmod 755 "$d/shim/team-paths.sh" && printf '%s\n' '## Active' '- [ ] **T-1004** the opt-in sample hook — `READY_FOR_ENG` — spec: .shell-team/specs/T-1004-optin-hook-sample.md' > "$d/.shell-team/todo.md" && (cd "$d" && PATH="$d/shim:$PATH" command -v team-paths.sh >/dev/null) && (cd "$d" && PATH="$d/shim:$PATH" bash "$R/docs/interventions-reminder-hook.sample.sh" </dev/null >"$d/out" 2>"$d/err") && test ! -s "$d/err" && test "$(wc -l < "$d/out" | tr -d ' ')" -eq 1 && test "$(cat "$d/out")" = '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"shell-team: a task is in flight. If this message interrupts, corrects, or stops the work, classify it and append the entry to the task interventions file (team-paths.sh --get interventions) NOW, before acting on the message, then commit it immediately. Use one of the seven classes the run skill lists (canonical source: templates/prompt-blocks/interventions-classes.md). A routine gate response (a plain GO, an approval, or an answer to a question you asked) is not an intervention and gets no entry."}}' && rm -rf "$d"

- [ ] **AC5** **The silent no-op is proved on the two states every other
  repository is in**, directly rather than only through a case label: a cwd with
  no board at all, and a board whose only flag-bearing lines are `- [x]` Done
  lines plus the status-flag legend, with an empty `## Active` section. Both must
  produce byte-empty stdout, byte-empty stderr and exit 0. The second is the
  discrimination case: it fails for any implementation that greps the whole board
  for a flag token. The same shim positive control applies, so a no-op caused by
  an unreachable resolver cannot be mistaken for a no-op caused by the board.
  - check: R="$PWD" && d="$(mktemp -d "${TMPDIR:-/tmp}/t1004ac5.XXXXXX")" && mkdir -p "$d/shim" "$d/empty/.shell-team" "$d/done/.shell-team" && cp "$R/bin/team-paths.sh" "$d/shim/team-paths.sh" && chmod 755 "$d/shim/team-paths.sh" && (cd "$d/empty" && PATH="$d/shim:$PATH" command -v team-paths.sh >/dev/null) && printf '%s\n' '## Status flags' '`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`' '' '## Active' '' '## Done' '- [x] **T-1003** the retro reads interventions — `READY_FOR_MERGE` — spec: .shell-team/specs/T-1003-retro-reads-interventions.md' > "$d/done/.shell-team/todo.md" && for c in empty done; do (cd "$d/$c" && PATH="$d/shim:$PATH" bash "$R/docs/interventions-reminder-hook.sample.sh" </dev/null >"$d/$c.out" 2>"$d/$c.err") || exit 1; test ! -s "$d/$c.out" || exit 1; test ! -s "$d/$c.err" || exit 1; done && rm -rf "$d"

- [ ] **AC6** **The user's message is never echoed, and no byte of the board is
  either.** Fed a well-formed event whose `prompt` field carries a distinctive
  marker, and with an in-flight board whose title carries a second marker, the
  sample emits the fixed payload and neither marker appears in its stdout or
  stderr. The payload's own opening phrase is the positive control, so a criterion
  that passes because nothing was emitted at all is impossible.
  - check: R="$PWD" && d="$(mktemp -d "${TMPDIR:-/tmp}/t1004ac6.XXXXXX")" && mkdir -p "$d/shim" "$d/.shell-team" && cp "$R/bin/team-paths.sh" "$d/shim/team-paths.sh" && chmod 755 "$d/shim/team-paths.sh" && printf '%s\n' '## Active' '- [ ] **T-1004** BOARDMARKER-2f7a1c — `READY_FOR_QA` — spec: .shell-team/specs/T-1004-optin-hook-sample.md' > "$d/.shell-team/todo.md" && printf '%s' '{"hook_event_name":"UserPromptSubmit","prompt":"PROMPTMARKER-9c3f4b stop and revert everything"}' > "$d/in.json" && (cd "$d" && PATH="$d/shim:$PATH" bash "$R/docs/interventions-reminder-hook.sample.sh" <"$d/in.json" >"$d/out" 2>"$d/err") && grep -qF -- 'shell-team: a task is in flight' "$d/out" && test ! -s "$d/err" && ! grep -qF -- 'PROMPTMARKER-9c3f4b' "$d/out" && ! grep -qF -- 'BOARDMARKER-2f7a1c' "$d/out" && rm -rf "$d"

- [ ] **AC7** **Every degradation path fails open, silently.** Four states, each
  asserted to produce byte-empty stdout, byte-empty stderr and exit 0 while an
  in-flight board is present — so silence is caused by the degradation and not by
  the board: an unreadable board (`chmod 000`); the board path being a directory
  instead of a file; the resolver absent from `PATH`; and non-JSON garbage on
  stdin combined with the unreadable board. Tolerance is proved against broken
  input of the tolerated shape, never against valid input. Each state's stdout is
  compared as bytes, so a diagnostic leaking to stdout fails the criterion.
  - check: R="$PWD" && d="$(mktemp -d "${TMPDIR:-/tmp}/t1004ac7.XXXXXX")" && mkdir -p "$d/shim" && cp "$R/bin/team-paths.sh" "$d/shim/team-paths.sh" && chmod 755 "$d/shim/team-paths.sh" && S="$R/docs/interventions-reminder-hook.sample.sh" && B='- [ ] **T-1004** the opt-in sample hook — `READY_FOR_ENG` — spec: .shell-team/specs/T-1004-optin-hook-sample.md' && for c in unreadable isdir noresolver garbage; do mkdir -p "$d/$c/.shell-team"; done && printf '%s\n' '## Active' "$B" > "$d/unreadable/.shell-team/todo.md" && chmod 000 "$d/unreadable/.shell-team/todo.md" && mkdir -p "$d/isdir/.shell-team/todo.md" && printf '%s\n' '## Active' "$B" > "$d/noresolver/.shell-team/todo.md" && printf '%s\n' '## Active' "$B" > "$d/garbage/.shell-team/todo.md" && chmod 000 "$d/garbage/.shell-team/todo.md" && (cd "$d/unreadable" && PATH="$d/shim:$PATH" bash "$S" </dev/null >"$d/1.out" 2>"$d/1.err") && (cd "$d/isdir" && PATH="$d/shim:$PATH" bash "$S" </dev/null >"$d/2.out" 2>"$d/2.err") && (cd "$d/noresolver" && PATH=/usr/bin:/bin bash "$S" </dev/null >"$d/3.out" 2>"$d/3.err") && (cd "$d/garbage" && printf '%s\n' 'not json at all }{ oops' | PATH="$d/shim:$PATH" bash "$S" >"$d/4.out" 2>"$d/4.err") && for n in 1 2 3 4; do test ! -s "$d/$n.out" || exit 1; test ! -s "$d/$n.err" || exit 1; done && chmod 644 "$d/unreadable/.shell-team/todo.md" "$d/garbage/.shell-team/todo.md" && rm -rf "$d"

- [ ] **AC8** **The board is located through the resolver, in whichever layout the
  adopter has**, and no path is synthesised: the sample contains no literal
  `.shell-team/` or `tasks/` path, it names `team-paths.sh`, and it fires in the
  **legacy** layout (`tasks/loops/shell-team.contract.yaml` present, board at
  `tasks/todo.md`) exactly as in the default layout — which is the criterion a
  hardcoded `.shell-team/todo.md` cannot pass. The non-negated halves are the
  positive controls for the negated grep.
  - check: F=docs/interventions-reminder-hook.sample.sh && grep -qF -- 'team-paths.sh' "$F" && ! grep -qE -- '\.shell-team/|(^|[^A-Za-z0-9_./-])tasks/' "$F" && R="$PWD" && d="$(mktemp -d "${TMPDIR:-/tmp}/t1004ac8.XXXXXX")" && mkdir -p "$d/shim" "$d/tasks/loops" && cp "$R/bin/team-paths.sh" "$d/shim/team-paths.sh" && chmod 755 "$d/shim/team-paths.sh" && printf 'name: legacy\n' > "$d/tasks/loops/shell-team.contract.yaml" && printf '%s\n' '## Active' '- [ ] **T-1004** the opt-in sample hook — `READY_FOR_ENG` — spec: docs/specs/T-1004-optin-hook-sample.md' > "$d/tasks/todo.md" && (cd "$d" && PATH="$d/shim:$PATH" test "$(team-paths.sh --get todo)" = tasks/todo.md) && (cd "$d" && PATH="$d/shim:$PATH" bash "$R/docs/interventions-reminder-hook.sample.sh" </dev/null >"$d/out" 2>"$d/err") && test ! -s "$d/err" && grep -qF -- 'shell-team: a task is in flight' "$d/out" && test "$(wc -l < "$d/out" | tr -d ' ')" -eq 1 && rm -rf "$d"

- [ ] **AC9** **The fixture suite exists, passes, and covers both paths plus every
  degradation state**, in the house idiom (explicit `mktemp` template, fixtures
  built inline, no nested `git init`, no dependency on the repository's own board).
  Its case count is pinned in both directions at **twelve** by its own
  `CASES_EXPECTED` counter, and the load-bearing case labels below are pinned by
  name; every case asserts exit status, stdout and stderr, so a case can no longer
  pass on exit code alone. All four degradation states live **here** as well as in
  AC7, because the suite is the lock CI re-runs forever while a frozen criterion is
  evaluated once. Boundary: a label proves a case exists, not that its assertion
  tests what its name says.
  - check: T=tests/interventions-reminder/run.sh && test -f "$T" && grep -qxF -- 'CASES_EXPECTED=12' "$T" && for l in 'case: an in-flight board emits the exact reminder payload and nothing else' 'case: no board at all -> silent no-op (empty stdout, empty stderr, exit 0)' 'case: a board with only - [x] Done lines carrying flags -> silent no-op' 'case: a CRLF board with an in-flight line still emits the payload' 'case: the legacy tasks/ layout is resolved, not hardcoded' 'case: garbage on stdin changes nothing (the event is never parsed)' 'case: the prompt field is never echoed into the emitted context' 'case: the resolver missing from PATH -> silent no-op' 'case: an unreadable board -> silent no-op, never a diagnostic' 'case: the board path being a directory -> silent no-op' 'case: a non-conforming - [ ] line is not in flight' 'case: two in-flight lines emit exactly one reminder'; do grep -qF -- "$l" "$T" || exit 1; done && bash "$T" >/dev/null

- [ ] **AC10** **Zero new runtime dependency, and shellcheck-clean.** The sample
  invokes no interpreter or non-POSIX runtime (`jq`, `python`, `perl`, `node`,
  `ruby`), and `shellcheck` is run unconditionally over the sample and its suite so
  its absence fails the criterion loudly instead of passing it vacuously. Positive
  control on the same file for the negated grep: the sample names `team-paths.sh`.
  - check: F=docs/interventions-reminder-hook.sample.sh && grep -qF -- 'team-paths.sh' "$F" && ! grep -qE -- '(^|[^A-Za-z0-9_-])(jq|python|python3|perl|node|ruby)([^A-Za-z0-9_-]|$)' "$F" && shellcheck "$F" tests/interventions-reminder/run.sh

- [ ] **AC11** **CI lints and runs it, and the procedure is recorded.** The
  workflow's `shellcheck` argument list names both new files, a step runs the new
  suite, and `.shell-team/test-recipe.md` gains a `T-1004` entry naming the one
  non-obvious environment requirement — that the suite must make `team-paths.sh`
  reachable as a **bare name** (a chmod'd copy in a throwaway shim dir), because
  the sample deliberately has no `bin/` fallback and would otherwise silently
  no-op through every case.
  - check: W=.github/workflows/check-handoff.yml && grep -F -- 'docs/interventions-reminder-hook.sample.sh' "$W" | grep -q -- 'shellcheck ' && grep -F -- 'tests/interventions-reminder/run.sh' "$W" | grep -q -- 'shellcheck ' && grep -qF -- 'run: bash tests/interventions-reminder/run.sh' "$W" && grep -qF -- 'T-1004' .shell-team/test-recipe.md && grep -qF -- 'reachable as a bare name' .shell-team/test-recipe.md

- [ ] **AC12** **The flag enum has one canonical home and the sample is bound to
  it.** `docs/interventions-reminder-hook.sample.sh` is registered in
  `templates/prompt-blocks/registry.txt` as a `contain` consumer of `flag-enum.md`,
  all seven flag tokens appear in it, and `bin/check-prompt-sync.sh` is green — so
  a later flag added to the enum fails CI instead of silently making the hook
  under-fire. The `interventions-classes.md` row is unchanged and still names
  **exactly** its two T-1002 consumers, asserted by equality rather than
  containment, because T-1002's frozen AC17 pins it and the sample must not become
  a third consumer.
  - check: G=templates/prompt-blocks/registry.txt && test "$(awk '$1=="contain" && $2=="interventions-classes.md" {print $3" "$4" "NF-2}' "$G")" = 'bin/check-interventions.sh skills/run/SKILL.md 2' && awk '$1=="contain" && $2=="flag-enum.md"' "$G" | grep -qF -- 'docs/interventions-reminder-hook.sample.sh' && for t in READY_FOR_ARCH READY_FOR_ENG READY_FOR_QA READY_FOR_REVIEW READY_FOR_MERGE BLOCKED REWORK; do grep -qF -- "$t" docs/interventions-reminder-hook.sample.sh || exit 1; done && bash bin/check-prompt-sync.sh >/dev/null

- [ ] **AC13** **The posture sentence survives and gains the qualification, in
  both languages.** `docs/tuning-oversight.md` still carries
  `**This project ships no hooks.**` exactly once and gains a new H2 section
  stating that no *active* hook ships, that what ships is an inert readable sample
  the adopter installs, and linking the sample by name;
  `docs/tuning-oversight.ja.md` carries the byte-identical parity of each of those
  three claims. Nothing checks en/ja parity in this repository, so the assertion
  names **both** files explicitly and fails if either drifts.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && test "$(grep -cF -- '**This project ships no hooks.**' "$E")" -eq 1 && test "$(grep -cF -- '**このプロジェクトは hook を出荷しません。**' "$J")" -eq 1 && grep -qxF -- '## The one sample hook, and why it ships inert' "$E" && grep -qxF -- '## 唯一のサンプル hook と、それが無効のまま出荷される理由' "$J" && grep -qF -- 'still ships no active hook' "$E" && grep -qF -- '有効な hook は今も出荷していません' "$J" && grep -qF -- 'an inert, readable sample you install yourself' "$E" && grep -qF -- '自分でインストールする、読める無効なサンプル' "$J" && grep -qF -- 'interventions-reminder-hook.sample.sh' "$E" && grep -qF -- 'interventions-reminder-hook.sample.sh' "$J"

- [ ] **AC14** **The capture-fidelity asymmetry is stated honestly in both
  languages**: the shipped default is instruction-strength at the moment (naming
  `skills/run/SKILL.md` as where that instruction lives), the sample makes it
  mechanically prompted, and neither state proves that every intervention was
  recorded — `bin/check-interventions.sh` proves a record exists and is well-formed,
  never that it is complete. Each language's three anchors are asserted
  independently so a paragraph cannot be half-translated.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && grep -qF -- 'instruction-strength' "$E" && grep -qF -- 'skills/run/SKILL.md' "$E" && grep -qF -- 'mechanically prompted' "$E" && grep -qF -- 'never that every intervention was recorded' "$E" && grep -qF -- '指示の強度' "$J" && grep -qF -- 'skills/run/SKILL.md' "$J" && grep -qF -- '機械的に促されます' "$J" && grep -qF -- 'すべての介入が記録されたことは証明しません' "$J"

- [ ] **AC15** **The install snippet is copy-ready, identical in both languages,
  and tells the adopter to read the script first.** Both documents carry a fenced
  block registering the hook under `UserPromptSubmit` as a `command` hook whose
  path is the adopter's own (`$HOME`-based), and both carry the read-it-first
  instruction. No literal `/Users/` or `/home/` path appears in either file — a
  hygiene property, asserted with each file's own snippet line as the positive
  control.
  - check: E=docs/tuning-oversight.md && J=docs/tuning-oversight.ja.md && C='"command": "bash $HOME/.claude/hooks/interventions-reminder.sh"' && for f in "$E" "$J"; do test "$(grep -cF -- "$C" "$f")" -eq 1 || exit 1; grep -qF -- '"UserPromptSubmit"' "$f" || exit 1; grep -qF -- '"type": "command"' "$f" || exit 1; ! grep -qE -- '/Users/|/home/' "$f" || exit 1; done && grep -qF -- 'read the script before you register it' "$E" && grep -qF -- '登録する前にスクリプトを読んでください' "$J"

- [ ] **AC16** **Issue #44: the citation rule names an interventions-file
  reference, as a clause and not a new item.** `agents/scrum-master.md`'s
  citation sentence gains exactly one clause naming an interventions-file
  reference and its reserved `no-task.md`; the file's top-level numbered items
  stay at **eighteen** (T-1003's frozen AC16 pin, re-asserted here because this is
  the task that could break it); its `nine canonical inputs` declaration is
  untouched; and T-1001's AC30 invocation invariant still holds — every
  relative-path occurrence of `bin/retro-inputs.sh` is preceded by `bash `. The
  existing citation-sentence anchor is the positive control.
  - check: F=agents/scrum-master.md && C='an interventions-file reference (`tasks/interventions/<task-id>.md`, or its reserved `no-task.md`)' && grep -qF -- 'cites a source' "$F" && test "$(grep -cF -- "$C" "$F")" -eq 1 && test "$(grep -cE -- '^[0-9]+\. ' "$F")" -eq 18 && test "$(grep -c -- 'nine canonical inputs' "$F")" -eq 1 && test "$(grep -o -- 'bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')" -eq "$(grep -o -- 'bash bin/retro-inputs\.sh' "$F" | wc -l | tr -d ' ')"

- [ ] **AC17** **The protected invariants are still intact after the change.**
  Nine paths this task must not touch are byte-unchanged against the base ref: the
  channel's checker and canonical class block, both skill files that carry the gate
  and the producer discipline, the retro ledger's two scripts, the path resolver,
  and `agents/engineer.md` and `agents/qa-verifier.md`. The non-empty overall diff
  is the positive control. **Merge-point-scoped**: tied to the merge point it was
  authored at and expected to go stale after merge; do not merge-range it, widen
  its base-ref resolution, or re-derive it per rework round.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(git diff --name-only develop -- bin/check-interventions.sh templates/prompt-blocks/interventions-classes.md skills/run/SKILL.md skills/goal/SKILL.md bin/retro-inputs.sh bin/check-retro.sh bin/team-paths.sh agents/engineer.md agents/qa-verifier.md)"

- [ ] **AC18** The change stays inside its declared surface — every path in
  `git diff --name-only develop` matches the allow-list below, with the non-empty
  diff as the positive control — and nothing that already worked stops working:
  the board linter on the shipped template and on this repository's board, prompt
  sync and its suite, the resolver suite, the codex-skeleton-hygiene suite (whose
  live-file locks scan `agents/qa-verifier.md` and both skill files, none of which
  this task edits — so a green run here is the evidence that the T-1002 DP-8
  extension is untouched), the retro checker over this repository's retros, and the
  interventions checker over both committed records. The allow-list carries this
  task's mandatory artefacts — spec, provenance, review record, the interventions
  file the gate requires, the board and the test recipe — so a required artefact is
  never outside the scope lock. **Merge-point-scoped**, on the same terms as AC17.
  - check: d="$(git diff --name-only develop)" && test -n "$d" && test -z "$(printf '%s\n' "$d" | grep -vE -- '^(\.shell-team/(todo\.md|test-recipe\.md|specs/T-1004-optin-hook-sample\.md|provenance/T-1004\.md|reviews/T-1004[^/]*|interventions/T-1004\.md)|docs/(tuning-oversight\.md|tuning-oversight\.ja\.md|interventions-reminder-hook\.sample\.sh)|agents/scrum-master\.md|templates/prompt-blocks/registry\.txt|tests/interventions-reminder/.+|\.github/workflows/check-handoff\.yml)$')" && bash bin/check-handoff.sh templates/todo-template.md >/dev/null && bash bin/check-handoff.sh "$(bash bin/team-paths.sh --get todo)" >/dev/null && bash bin/check-prompt-sync.sh >/dev/null && bash tests/check-prompt-sync/run.sh >/dev/null && bash tests/team-paths/run.sh >/dev/null && bash tests/codex-skeleton-hygiene/run.sh >/dev/null && bash bin/check-retro.sh .shell-team/retros/*.md >/dev/null && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1002.md" >/dev/null && bash bin/check-interventions.sh "$(bash bin/team-paths.sh --get interventions)/T-1003.md" >/dev/null && bash bin/check-provenance.sh "$(bash bin/team-paths.sh --get provenance)/T-1004.md" >/dev/null

## Input space

**Reachable input classes** — what real usage can produce, and what the
implementation must therefore be correct about. The dominant fact shaping this
list: the adopter registers the hook **user-wide**, so its input space is *every
directory they ever open a session in*, not just a shell-team repository.

1. **Every cwd class a session can start in**: a repository with no shell-team
   layout at all (the overwhelming majority — every other project the adopter
   owns); a shell-team repository in the `.shell-team/` default layout; one in the
   legacy `tasks/` split-root layout; one under a `$TEAM_RUN_BASE` override; and a
   directory that is not a git repository at all (a home directory, a scratch
   directory). Only the in-flight case may produce output.
2. **Board states**: absent; present and empty; present with an empty `## Active`
   section and a populated `## Done` section whose `- [x]` lines carry status
   flags; present with one in-flight `- [ ]` line at any of the seven flags;
   present with several in-flight lines (one reminder, not one per line); present
   with a `- [ ]` line that does not conform to `bin/check-handoff.sh`'s grammar (a
   half-written entry, an unbackticked flag) — which reads as **not** in flight,
   the silent direction; present with CRLF line endings; present but unreadable;
   and the board path existing as a directory rather than a file.
3. **Event JSON on stdin**: the documented `UserPromptSubmit` payload; a payload
   whose `prompt` field carries arbitrary user text including quotes, newlines,
   backticks, shell metacharacters and multibyte characters; non-JSON garbage;
   empty stdin; and closed stdin. None of it is parsed, and every one of them
   reaches the same two outcomes, decided by the board alone.
4. **The plugin not enabled**: `team-paths.sh` absent from `PATH`, because the
   adopter disabled the plugin or never installed it in that repository. Silent
   no-op.
5. **The hook not installed at all** — the shipped default, and the state every
   existing adopter stays in. Everything must behave exactly as before, which is
   what the zero-activation-footprint criterion holds.
6. **The status-flag enum growing.** A later flag is a reachable change to this
   repository, not a synthetic input: it makes the hook under-fire, and the
   `contain`-mode registration is what turns that into a CI failure.

**Out-of-scope synthetic extremes** — named and declined:

1. **Adversarially large or pathological boards** — a board of a million lines, a
   task title megabytes long, a crafted line built to make the ERE backtrack. Real
   boards are kilobytes and are linted by `bin/check-handoff.sh` in CI.
2. **A hostile `team-paths.sh` earlier on `PATH`** returning a crafted path. The
   hook reads a file the adopter owns, in a session the adopter started, under an
   interpreter the adopter registered; it is not a security boundary. The worst a
   crafted value achieves is that a different file is tested for one pattern —
   and no byte of any file reaches the output, which is a fixed constant.
3. **Non-UTF-8 bytes, NUL bytes, or Unicode line/bidi separators in the board.**
   `grep` may classify such a file as binary and report no match, which reads as
   not-in-flight — the silent direction. No such byte can reach the output,
   because the output is a constant.
4. **Whether the orchestrator actually obeys the injected reminder.** Not
   observable from a hook and not asserted by any criterion. The mechanism prompts
   a judgment; it does not make it.
5. **Whether the harness invokes the hook, injects `additionalContext`, or fires
   after an Esc interrupt.** Host-runtime behaviour of Claude Code, verified by an
   operator dogfooding on a real host — the same status this project already
   assigns to host scheduling. The criteria prove the script's contract (given
   stdin and a cwd, these bytes), never the harness's.
6. **Timing or benchmarking the hook.** The cost constraint is met structurally —
   one resolver call and one `grep`, no interpreter, no network — and is asserted
   that way, never as a measured upper bound.
7. **Other hook events and other capture triggers.** `Stop`, `PostToolUse`,
   `SessionStart`, `PreCompact`; triggers 3 and 5.
8. **Concurrency**: two sessions firing the hook at once, or a board being
   rewritten while it is read. The hook only reads, and a torn read yields at
   worst a missed reminder.
9. **Non-bash hosts** — Windows `cmd`/PowerShell, a shell without `grep`. The
   sample is bash, as every script in this repository is.

<!-- END intent-block: T-1004 -->

## Resolved design decisions

### DP-1 — the sample lives in `docs/`, beside the document that prescribes it

`docs/interventions-reminder-hook.sample.sh`. Three grounds, in order of weight.
**(a) The sibling precedent.** The only other inert, host-only, non-portable
sample this repository ships — `docs/loop-engineering/loop-cron.crontab.example` —
lives in `docs/`, next to the prose that prescribes it (`docs/distribution.md`
§Host-only scheduling links it directly). This sample's prescribing prose is
`docs/tuning-oversight.md` §Limits, so `docs/` is where a reader arrives from.
**(b) `templates/` would be a false statement.** `README.md`'s tree describes
`templates/` as "generic scaffolds used by team-init"; this file is never
scaffolded by `team-init`, so putting it there either falsifies that line or costs
a README edit in two languages to describe one file. `templates/CLAUDE-routing-snippet.md`
is a *markdown snippet pasted into a config file* — which is what the install
snippet is, and the install snippet does live with the prose. **(c) The name
carries the inertness** the way `.example` does, while keeping `.sh` so shellcheck
and editors treat it as bash — because unlike the crontab example, this file **is**
linted and tested. No path component is named `hooks`, so nothing sits on or near
`<plugin-root>/hooks/`, and that property is checkable with one `find`.

### DP-2 — in-flight detection reuses `bin/check-handoff.sh`'s enforced grammar

The cheap options were a whole-file grep for a flag token, or an `awk` range
scoped to `## Active`. The first is wrong: this repository's own board keeps
`- [x]` Done lines that carry `READY_FOR_MERGE`, and a status-flag legend that
lists all five, so a whole-file grep fires forever after the first task closes.
The second adds a stateful scan to buy a scope the `- [ ]` / `- [x]` distinction
already gives. The chosen pattern is `check-handoff.sh`'s own `LINE_RE` with the
flag enum substituted for the generic flag capture — detection therefore keys off
an invariant CI already enforces, not a convention. Two consequences stated
plainly: a board line that does not conform reads as not-in-flight (the hook errs
toward silence, never toward a false alarm), and the end anchor is dropped so a
CRLF board still matches.

### DP-3 — `READY_FOR_MERGE` counts as in flight

A task awaiting the human merge decision is exactly where a trigger-1 moment is
most likely — the maintainer stopping or redirecting at the gate. The flag set is
therefore all seven, and the only thing that ends the reminder is the line
becoming `- [x]`.

### DP-4 — the hook drains stdin and parses nothing

Not `prompt`, not `cwd`. Three reasons, all load-bearing. **Privacy**: a hook that
never reads the message cannot leak it into context, a log, or a diagnostic — the
strongest possible form of the discipline, and one a criterion can prove by
construction. **Zero dependency**: parsing JSON in pure bash is either wrong or
long, and `jq` is not available to an adopter by assumption. **Correct division of
labour**: classification is a judgment the orchestrator makes with the whole
conversation in view; the hook's job is to prompt that judgment at the right
moment, and it needs to know nothing about the message to do so. stdin is drained
rather than ignored so the harness's write never lands on a closed pipe.

### DP-5 — fail-open, stated as an exception with its reason

This repository's norm is that a checker which cannot evaluate its input reports
an error. This component is not a checker: it runs inside the adopter's session,
and a hook that errors, hangs, or prints a diagnostic degrades the session it was
meant to help. It is an **enhancer** whose absence returns the operator to the
shipped default. So every failure path is exit 0 with byte-empty stdout and
stderr, and the parts that gate — `bin/check-interventions.sh`, the
Implement-to-Validate gate — keep failing closed and are not touched. The
implementation consequence the criteria hold: all output comes from exactly one
`printf` at the end, so a partial JSON object can never be emitted, and no
diagnostic ever reaches stdout.

### DP-6 — `docs/distribution.md` gains nothing; considered and declined

The scheduler paragraph is the closest structural sibling, so a one-line mention
there was genuinely on the table. Declined: that document's subject is install and
distribution surfaces, and the sample is neither installed nor enabled by the
framework — nothing in the manifest references it. Adding the qualification there
would put it in four and five copies (en + ja), each a drift site, for a reader
who did not arrive looking for oversight tuning. Declining creates no falsehood:
`distribution.md` makes no claim about hooks today, so there is nothing there to
correct. The sibling precedent argues about the sample's *shape*, not about which
document owns the prose.

### DP-7 — the sample references the class vocabulary; it does not embed the block

`templates/prompt-blocks/interventions-classes.md` is registered `contain`-mode
with exactly two consumers, and T-1002's frozen AC17 pins that row. A third
consumer breaks a frozen criterion, so the reminder **names** the canonical source
and reuses its vocabulary (interrupt / correct / stop, the routine-gate-response
exclusion) without reproducing the block. The flag enum is the opposite case: the
sample necessarily contains all seven tokens, `flag-enum.md`'s row is pinned by
nothing, and registering the sample there converts a silent under-fire on a future
eighth flag into a red CI run. Take the drift protection where it is free; decline
it where it costs a frozen criterion.

### DP-8 — one reminder per event, with no state

No deduplication, no rate limiting, no memory of previous events. State means a
file to write, a race to lose, and something to clean up in the adopter's
repository — for a benefit ("do not remind twice in a row") that the reminder's
own wording already handles, since it is conditional on its face. The hook is a
pure function of (board, cwd).

### DP-9 — issue #44 is one clause, in one place, after an inventory

The class is "enumerations of accepted citation sources in `agents/scrum-master.md`".
Inventoried with `grep -n 'cite\|Cite\|cites' agents/scrum-master.md`, three sites
exist and only one is an enumeration: the `## Output` citation sentence ("at
minimum a PR number, a … reference, or a … line range") — **fixed here**. The
`Cite or remove` rule speaks of "no source you can point at in the inputs" with no
enumeration — **n-a**, it already covers the new type. The `title` and
`headRefName` rule says to cite a PR by number rather than reproducing its text —
**n-a**, its subject is attacker-controlled strings, not which artefacts count.
The `Stay generic` rule lists artefacts the role's *logic* keys off, not citation
types — **n-a**, and extending it would imply a file-existence check this task
does not add. The clause uses the file's existing legacy-path idiom
(`tasks/interventions/<task-id>.md`), which the document's own operating-paths
note at the top already maps onto whichever layout the resolver reports.

## Measured inventory (verified against the tree at `415bcd8`; re-verify before editing)

| File | New / edited | What changes |
|---|---|---|
| `docs/interventions-reminder-hook.sample.sh` | new | the sample, mode 644, ~60 lines including its header |
| `tests/interventions-reminder/run.sh` | new | twelve cases, `CASES_EXPECTED=12` |
| `docs/tuning-oversight.md` | edited | one new H2 after `## Limits` (the existing section ends at the ships-no-hooks paragraph, line 100–103) |
| `docs/tuning-oversight.ja.md` | edited | the same section, after `## 限界` (line 77–81) |
| `templates/prompt-blocks/registry.txt` | edited | the `contain flag-enum.md` row (line 35) gains one consumer; the `interventions-classes.md` row (line 40) is untouched |
| `agents/scrum-master.md` | edited | one clause in the citation sentence under `## Output` (line 71) |
| `.github/workflows/check-handoff.yml` | edited | two paths appended to the `shellcheck` argument list (line 29) and one new suite step |
| `.shell-team/test-recipe.md` | edited | one appended `T-1004` entry |

Two measured facts the engineer should not re-derive: the codex-skeleton-hygiene
live-file locks scan `agents/qa-verifier.md`, `skills/run/SKILL.md` and
`skills/goal/SKILL.md` only — none of which this task edits, so the DP-8 lock
extension from T-1002 is out of reach here; and `templates/prompt-blocks/flag-enum.md`
is exactly the seven bare tokens, one per line, so `contain` mode is satisfied by
the tokens appearing anywhere in the sample, including inside its ERE.

## Body-to-AC correspondence

Every normative directive in this spec's body, mapped to the criterion that holds
it or to an explicit exemption with a reason.

| Body directive | Held by |
|---|---|
| The sample ships inert: non-executable, mode 644, header says so | AC1 |
| No `hooks` key in `plugin.json`; `.claude-plugin/` untouched | AC2 |
| No directory named `hooks` anywhere in the repository | AC2 |
| Nothing added under `agents/` / `skills/` / `commands/` | AC2 |
| The JSON payload and the reminder are this spec's bytes, single-sourced | AC3 |
| The reminder contains no `"` and no backslash | AC3 (compared against the literal) |
| The in-flight ERE is exactly the pinned pattern | AC3 |
| An in-flight board emits exactly that one line plus one newline, exit 0, empty stderr | AC4 |
| No board, or no in-flight line, is a silent no-op | AC5 |
| A `- [x]` Done line carrying a flag is not in flight | AC5 |
| The user's message is never echoed | AC6 |
| No byte of the board reaches the output | AC6 |
| Every degradation path fails open, silently | AC7 |
| Tolerance is proved against broken input of the tolerated shape | AC7 |
| The board is resolved through `team-paths.sh`, never synthesised | AC8 |
| Both layouts work; no literal `.shell-team/` or `tasks/` path in the sample | AC8 |
| Both paths and every degradation state are covered by a fixture suite | AC9 |
| Case count pinned in both directions | AC9 (`CASES_EXPECTED=12`) |
| Pure bash, zero new runtime dependency | AC10 |
| shellcheck-clean, with shellcheck invoked unconditionally | AC10 |
| CI lints the sample and runs the suite | AC11 |
| The suite's bare-name resolver requirement is recorded in the test recipe | AC11 |
| The sample is bound to the canonical flag enum via `contain` mode | AC12 |
| The sample is **not** a consumer of `interventions-classes.md` (T-1002 AC17) | AC12 (equality pin on that row) |
| The ships-no-hooks sentence survives verbatim | AC13 |
| The qualification is stated in both languages, and the sample is linked | AC13 |
| The capture-fidelity asymmetry is stated honestly in both languages | AC14 |
| The install snippet is copy-ready and identical in both languages | AC15 |
| The adopter is told to read the script first | AC15 |
| No literal `/Users/` or `/home/` path in either document | AC15 |
| Issue #44: the citation rule names an interventions-file reference | AC16 |
| It is a clause, not a new numbered item (T-1003 AC16's count of eighteen) | AC16 |
| T-1001's AC30 invocation convention stays intact | AC16 |
| The channel, both skill files, the ledger scripts and the resolver are untouched | AC17 |
| `agents/engineer.md` and `agents/qa-verifier.md` are untouched | AC17 |
| The change stays inside its declared surface | AC18 |
| Nothing that already worked stops working | AC18 |
| The T-1002 DP-8 live-file lock extension is untouched | AC18 (the hygiene suite passes; the files it scans are outside this diff) |
| Provenance record exists and is conformant | AC18 |
| One reminder per event, no state (DP-8) | AC4 (one line of output), AC9 (the two-in-flight-lines case) — no separate criterion, because "no state file" is the absence of a write and the scope lock (AC18) already forbids any path outside the allow-list |
| `docs/distribution.md` gains nothing (DP-6) | **info-only (not promoted to AC)** — an absence no grep distinguishes from "not yet written"; the mechanical half is AC18's allow-list, which excludes that path |
| `README.md` / `README.ja.md` gain nothing | **info-only (not promoted to AC)** — same shape; held by AC18's allow-list |
| No event other than `UserPromptSubmit`; triggers 3 and 5 unchanged | **info-only (not promoted to AC)** — the positive half is pinned by AC3 (the payload names `UserPromptSubmit`) and AC17 (the skill files carrying the trigger-3/5 self-checks are byte-unchanged); asserting the absence of code for four other events is asserting that unwritten code is unwritten |
| No mechanical close-out durability gate (issue #41) | **info-only (not promoted to AC)** — a deferral to a filed issue, with no artefact in the tree to assert against |
| The re-evaluation trigger for ships-no-hooks stays where it is | **info-only (not promoted to AC)** — a decision about where a record lives, already recorded on the board; a criterion here would pin prose in a file this task does not otherwise touch |
| Whether the harness invokes the hook is unverifiable here | **info-only (not promoted to AC)** — a declared limit, and the point of declaring it is that no criterion may claim it |
| Line numbers in the measured inventory must be re-verified | **info-only (not promoted to AC)** — an instruction about how to work; every criterion asserts content, never a line number |
| No new issue was opened; #37 is the tracker and #44 is bundled | **info-only (not promoted to AC)** — a provenance statement about how the task was filed |

## Assumptions

- **The external hook contract, recorded as an external assumption.** Verified
  against the official Claude Code hooks documentation (hooks reference +
  hooks guide) on 2026-07-30: `UserPromptSubmit` receives the event as JSON on
  stdin with the user's message in a `prompt` field; a `hookSpecificOutput` object
  with `hookEventName` and `additionalContext` injects context into the session;
  exit 0 with empty stdout is a no-op; hooks are invoked with the project
  directory as cwd; a user-scope hook fires in every session, which is why the
  sample must self-gate; and the event fires for a message typed after an Esc
  interrupt, which is the case trigger 1 cares about most. **None of this is
  provable by this repository's tests** — they prove the script's own contract.
  If the harness's schema changes, the failure mode is a no-op or an ignored
  field, and the shipped default is unaffected.
- `bin/team-paths.sh` is reachable as the bare name `team-paths.sh` whenever the
  plugin is enabled (`docs/distribution.md`: "`bin/` scripts are added to `PATH`
  while the plugin is enabled"). The sample deliberately has **no** `bin/…`
  fallback, because an adopter's repository has no `bin/team-paths.sh` — which is
  also why the fixture suite must build a bare-name shim (AC11's recipe entry).
- The board grammar the detection keys off is `bin/check-handoff.sh`'s enforced
  `LINE_RE`, read at `415bcd8`. If that grammar changes, the hook under-fires
  (silence), never over-fires.
- The seven-flag enum is `templates/prompt-blocks/flag-enum.md`, which is exactly
  seven bare tokens one per line — so `contain`-mode registration works without
  reshaping the sample.
- `templates/prompt-blocks/registry.txt`'s `flag-enum.md` row is pinned by no
  criterion in any spec and by no test, so extending its consumer list is a safe
  additive edit. Verified by reading `tests/check-prompt-sync/run.sh` (which pins
  only the `careful-execution.md` row's non-emptiness) and by grepping the specs
  for that row.
- The adopter's copy of the sample can live anywhere they own; the snippet's
  `$HOME/.claude/hooks/` path is illustrative, and the directory it names is in
  the adopter's home — it is not a plugin load path and creates none.

## Open questions

None blocking.

## Notes for engineer

**Build order.**

1. `docs/interventions-reminder-hook.sample.sh` first, from the two pinned strings
   in the Acceptance criteria section — copy them, do not retype them.
2. `tests/interventions-reminder/run.sh` next, with the shim helper, and run it
   before touching anything else. Doing the suite second gives you a worklist for
   every degradation state.
3. `templates/prompt-blocks/registry.txt` and `bin/check-prompt-sync.sh` green.
4. The two `docs/tuning-oversight*.md` sections — write the English one, then
   translate, then re-read the two side by side for the three anchor claims AC13
   and AC14 pin in each.
5. `agents/scrum-master.md`'s one clause. Re-read the file fresh: T-1003 edited it
   two commits ago, and its numbered-item count of eighteen is a frozen pin — add a
   clause to the sentence under `## Output`, never a list item.
6. CI wiring and the test-recipe entry last.

**Traps measured in advance.**

- **The shim is the anti-vacuity device.** If `team-paths.sh` is not reachable as
  a bare name, the sample silently no-ops and *every silence case passes for the
  wrong reason* while only the emit cases fail. Assert `command -v team-paths.sh`
  under the modified `PATH` before each emit case, and copy-plus-`chmod 755` rather
  than relying on the repository file's own mode.
- **All output from exactly one `printf` at the end.** With no `set -e` (which is
  the right choice for a fail-open script), a mid-function abort must not be able
  to leave a half-written JSON object on stdout. Silence the resolver's stderr at
  the call site rather than globally, so a future edit cannot accidentally start
  writing diagnostics to stdout.
- **The em dash in the ERE is a multibyte literal.** It matches as bytes under
  both a UTF-8 and a `C` locale, so no locale pinning is needed — but do not
  "clean it up" into `.*`, which would drop the anchor on the enforced separator
  and let a backticked word in a task title read as a status flag.
- **shellcheck and the single-quoted pattern.** The pattern contains backticks and
  brackets inside single quotes; if shellcheck objects, add a narrowly scoped
  `# shellcheck disable=` with the reason on the line above, as `bin/check-handoff.sh`
  and `tests/codex-skeleton-hygiene/run.sh` already do for literal ERE sources.
- **`chmod 000` fixtures must be restored before cleanup** so `rm -rf` cannot fail
  on a directory the suite made unreadable; and the suite must not `chmod` anything
  inside this repository's own tree.

**Mutation self-check before hand-off**, per the standing discipline: break each
new lock deliberately, observe it go red, restore, observe green. At minimum —
(a) change one character of the reminder in the sample only (AC3 and AC4 must both
fire, and this is the check that the two copies are genuinely compared);
(b) replace the in-flight ERE with a bare flag-token grep (AC5's Done-only case
must fire — the discrimination that the whole silent-no-op property rests on);
(c) delete the resolver call and hardcode `.shell-team/todo.md` (AC8's legacy-layout
and no-hardcode halves must both fire); (d) make one failure path print a
diagnostic to stdout (AC7 must fire). Then invent one mutation of your own aimed at
your own detector's blind spots — the obvious candidates are "does the emit path
still work when the board has CRLF endings", "does the silence path really produce
*byte-empty* stdout rather than a blank line", and "does a `- [ ]` line whose flag
sits in the title rather than the flag position read as in flight". Report each
mutation with the observed failure.

**Prior art to read before writing.** `docs/loop-engineering/loop-cron.crontab.example`
(the header idiom for an inert sample, and the tone to match);
`bin/check-handoff.sh`'s `LINE_RE` / `FLAG_RE` block (the grammar being reused, and
the reason `FLAG_RE` is anchored to the separator); `bin/team-paths.sh`'s `--get`
mode; `tests/check-interventions/run.sh` (the inline-fixture, `CASES_EXPECTED` house
idiom); `.shell-team/test-recipe.md` (append the procedure you establish).

**Records this task must produce**: `.shell-team/provenance/T-1004.md` (AC18),
`.shell-team/interventions/T-1004.md` (the T-1002 gate at the Implement-to-Validate
seam — the orchestrator is the producer, not you), and the review record. All three
are inside AC18's allow-list already.
