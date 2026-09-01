# Adopting shell-team in your repository

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](adopting.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](adopting.ja.md)

This repo can run the **shell-team** plugin — a PM → Engineer → QA →
Codex-Reviewer pipeline driven by spec-first, file-based hand-offs. The plugin
lives centrally (installed once); each adopting repo only holds the per-repo
*instances* scaffolded by `team-init`.

## Where the operating files live

`team-init` scaffolds everything under a **single base directory**, so the
plugin's footprint never scatters across your mainline tree. By default that base
is `.shell-team/`; override it with the `TEAM_RUN_BASE` environment variable. A repo
that already uses the legacy `tasks/` + `docs/specs/` layout is detected and reused
(the resolver `bin/team-paths.sh` decides which layout is in effect).

```
<base>/                          # .shell-team/ by default
├── todo.md                      # the task board / hand-off contract (status flags)
├── loops/
│   └── shell-team.contract.yaml   # the loop's TRIGGER/SCOPE/ACTION/BUDGET/STOP contract
├── specs/                       # the spec + acceptance criteria for each task
├── runs/                        # per-run telemetry (git-ignored via <base>/.gitignore)
├── retros/                      # retrospectives
├── reviews/                     # cross-provider review artifacts
├── AGENTS.md                    # cross-tool pointer doc (see below) — not a source of truth
├── test-recipe.md               # per-repo test-run recipe (engineer/QA read first, append
│                                #   established procedures; never overwritten, even with --force)
├── binding.conf.example         # inert executor-binding specimen; rename to binding.conf to opt in
└── .gitignore                   # self-contained; ignores runs/ telemetry
```

**Your host root is left untouched.** `team-init` does not edit your `CLAUDE.md`
and does not append to your root `.gitignore`. Telemetry is ignored via the
self-contained `<base>/.gitignore`. Whether to also git-ignore the whole base
dir — and whether to copy the operating rules below into your own `CLAUDE.md` —
is your call; the plugin will not make those edits for you.

If you keep the base dir out of git, the two ways of doing that differ in scope.
A `.shell-team/` line in the repo's own `.gitignore` applies to that repo and is
trivially reversed. Putting it in your global excludes (`git config --global
core.excludesFile`) hides the base dir in *every* repo on the machine —
including one where you later decide the board should be tracked, and there the
symptom is indirect: the board simply never appears in `git status`. To
re-include it in a single repo, add `!.shell-team/` to that repo's root
`.gitignore`; repo-level patterns outrank the global file. This repository
carries that line for exactly that reason, so its own base dir stays tracked
even for an operator who ignores `.shell-team/` globally.

For what the loop's **gates** actually do if you leave the operating files untracked instead of committing them, see [Trying the team on one ticket](#trying-the-team-on-one-ticket) below — this paragraph is about scope, not about what happens if you skip tracking altogether.

That global file has a second consequence. Anything that asks git whether a
path is ignored — `git check-ignore`, and checks built on it — reads it too, so
such a check can fail on your machine while passing in CI, where no global
excludes exist. Pin it explicitly (`git -c core.excludesFile=/dev/null …`) in
any assertion about ignore behavior rather than inheriting whatever the operator
has configured.

How often the session stops to check with you is your call too, and it is set
per-checkout rather than shipped: see
[tuning-oversight.md](tuning-oversight.md).

## `AGENTS.md` — a cross-tool pointer doc

`team-init` also scaffolds **`<base>/AGENTS.md`**: a portable doc that tells any
tool or agent (Claude, the Codex reviewer, or another assistant) *where this
repo keeps its working state* — the task board and status-flag chain, the specs,
the `project_status` snapshot, the per-device MEMORY.md index caveat, and the
fact that review is cross-provider (Codex).

It is a **pointer/mirror, not a source of truth**. It carries no progress log,
completion history, or dated entries; the actual state stays in `<base>/todo.md`,
the specs, and `project_status`. Read those for current truth — `AGENTS.md` only
tells you which files to read.

**Placement and trade-off.** It lives under the base dir (`<base>/AGENTS.md`),
**not** at your repo root — because `team-init` never touches the host root.
The consequence: tools that auto-detect a *root* `AGENTS.md` convention will
**not** auto-pick-up this one. That is a deliberate trade-off — we keep the
host-root-untouched guarantee and treat `AGENTS.md` purely as a portable pointer
doc rather than an auto-loaded root convention file. If you want a tool to read
it, point that tool at `<base>/AGENTS.md` explicitly.

## Pricing a spec's verification by task class

Every spec frozen from T-1065 onward additionally carries, on one line
inside its own frozen intent block, a declaration of its deliverable's
verification class: a top-level bullet
`- verification-class: mechanism — <rationale>` or
`- verification-class: no-mechanism — <rationale>`. **`mechanism`** is the
default whenever the task's diff can reach an executing surface — any path
under `bin/`, `tests/`, `templates/`, a CI workflow, or the semantics of a
checker — and for that class the full verification protocol applies
exactly as before: a full-population downstream-impact diff over every
merged spec, the whole CI-equivalent step list, and a mutation-probe matrix
over the spec's own criteria.

**`no-mechanism`** is for a task that changes no executing surface —
wording, prose, editorial or documentation deliverables — and it prices
three things down. The downstream-impact inventory is taken as a
**read-set**-scoped analysis instead of a **full-population** diff:
mechanically derive the set of merged criteria that read any path the task
edits, and difference their verdicts at the base ref and at HEAD. CI
equivalence runs only for the steps whose inputs the task's diff can
reach. Mutation probes are required only for the `- check:` lines the
task adds or changes, not for the whole spec. A `no-mechanism` spec
correspondingly declares as an explicit non-goal that it runs no
full-population sweep, no whole CI-equivalent re-run and no behaviour
verification of a mechanism it does not touch.

A two-arm sweep additionally stages a single snapshot of the gitignored
`.shell-team/runs` corpus into its base arm before either arm runs
(once per sweep) — without that staging step, a criterion reading the
corpus reports a base-arm FAIL that the diff never caused.

Enforcement today is a **duty, not a checker**: the declaration is
performed by the authoring role at spec-completion time and read by both
review gates and by the human — **no mechanical checker ships for this**,
because judging whether a task honestly belongs to the class it declares
is a reading judgment, not something a machine can verify from the diff
alone.

## How to run

```
/shell-team:run <what you want built>
```

The loop runs Plan → Specify → Implement → Validate → Review, advancing a status
flag in the board (`<base>/todo.md`) at each phase gate, and pauses for a human
before merge/push.

## Binding roles to executors

`team-init` scaffolds an inert `<base>/binding.conf.example`
(`<base>` resolves via `bin/team-paths.sh --get base`) — a copy of
`templates/binding-template.conf`. A host `<base>/binding.conf` is
adopted **whole**: there is no per-role merge, layering or fallback
against the shipped default, so it must carry exactly one `bind` row for
each of the six inner-loop roles (`tech-lead`, `pm-spec`, `engineer`,
`qa-verifier`, `codex-reviewer`, `ui-designer`) — no more, no fewer. A
partial file is refused, not completed from the default. Author one when
you want to assign specific executors to all six:

1. `mv <base>/binding.conf.example <base>/binding.conf` — or, if
   `team-init` has not run yet, copy the plugin's own
   `templates/binding-template.conf` (resolved from the plugin's
   installed directory, not a path under your own repository) to
   `<base>/binding.conf` by hand. **Its six rows carry placeholder model
   tokens** — `model-1` on the five `claude` rows, `model-2` on
   `codex-reviewer` — that name no real model: replace **every** row
   before relying on it, or transcribe the actual rows from
   `templates/binding-default.conf` (**not** the grammar example below,
   which is a custom-binding illustration with different values) for any
   role you are not changing. Editing one row and stopping there ships
   five placeholder bindings into resolution and telemetry.
2. Edit its `bind <role> <provider> <model> <effort|-> <adapter>` rows —
   one per role. `effort` is positionally required; spell "no value" as
   a literal `-`, never by omitting the field (only the effort column
   spells "unset" that way — the model column always needs a leading
   alphanumeric).
3. `bash check-binding.sh --config <base>/binding.conf` — with the plugin
   loaded, `bin/` is on `PATH`, so this resolves with no `bin/` prefix;
   inside a checkout with no plugin loaded, run `bash bin/check-binding.sh
   ...` instead.
4. `bash resolve-executor.sh --print-resolved` (same `bin/`-on-`PATH` note
   as step 3) — this resolves all six roles' effective bindings but runs
   **no availability probe at all**. `resolve-executor.sh --role <role>`
   goes further, but only for an **out-of-process** provider (`codex`) —
   checking `codex --version` is observable on `PATH` and then running
   that read-only probe; for an **in-process** provider (`claude`) it
   performs **no availability check at all**, printing the probe kind
   and leaving grounding the harness's own sub-agent invocation failure
   to the caller. Under the shipped default, five of the six roles bind
   `claude`, so `resolve-executor.sh --role codex-reviewer` is the only
   one of the six invocations that actually probes anything (see
   `executor-unavailable` below).

A config the real validator accepts — all six roles, as an adopted
config must carry:

```
schema 1

bind tech-lead      claude opus   high claude-cli
bind pm-spec        claude opus   high claude-cli
bind engineer       claude sonnet -    claude-cli
bind qa-verifier    claude sonnet -    claude-cli
bind ui-designer    claude sonnet -    claude-cli
bind codex-reviewer codex  gpt-5  -    codex-cli
```

With no host `<base>/binding.conf` at all — the ordinary, unconfigured
case — `resolve-executor.sh` falls back to the plugin-shipped default,
`templates/binding-default.conf`; its `model` column carries
`provider-configured` only for `codex-reviewer`, naming the boundary that
the shipped Codex invocation passes no model flag at all, while every
other role's column carries that role's own `agents/<role>.md` pin, from
the plugin's own agent definitions.

`resolve-executor.sh`'s refusal set is closed and has **five** tokens;
`usage` is a bad invocation (a CLI-argument error), not a config state,
so it sits outside this adopter workflow. The other four are
config-condition refusals: three of them are things an ordinary config
edit can trigger; the fourth is a contract the two shipped adapters
already both satisfy, so it is not reachable by binding to either of
them today:

- `binding-unresolved` (exit code `2`) — the effective binding failed to
  resolve to a well-formed, trustworthy form. Two ordinary-edit causes:
  an occupant at `<base>/binding.conf` that is not a regular file (a
  directory, a FIFO, a dangling symlink) — never silently substituted
  with the shipped default, which is reserved for true absence — or the
  config itself is malformed in a way `check-binding.sh`'s own grammar
  refuses, such as a `bind` row with the wrong field count or an
  unrecognized provider/adapter/role token. `resolve-executor.sh` folds
  both causes into this one token; `check-binding.sh --config
  <base>/binding.conf` (step 3) reports the more specific underlying
  reason when it's a malformed row.
- `capability-unsupported` (exit code `1`) — a role requests an effort
  value its bound adapter does not declare.
- `executor-unavailable` (exit code `1`) — raised only in `--role <role>`
  mode (`--print-resolved`, step 4 above, never raises it) and only for
  an **out-of-process** provider whose probe command isn't observable on
  `PATH` or fails its read-only check — for example, binding a role to
  `codex`/`codex-cli` without the `Codex` CLI installed. For an
  **in-process** provider (`claude`) `--role` performs no availability
  check at all, so binding a role to `claude` never reaches this refusal
  through the probe path.
- `contract-violation` (exit code `1`) — enforced for any role with write
  or propose board authority bound to an adapter that does not carry a
  board-transition channel. Both shipped adapters, `claude-cli` and
  `codex-cli`, declare `carries board-transition`, so binding a role to
  either one cannot reach this refusal today; it stays part of the closed
  set because a future shipped adapter could declare otherwise.

Each adapter declares its own effort vocabulary; there is no shared list:
`claude-cli` accepts `low`, `medium`, `high`, `xhigh`, `max`; `codex-cli`
accepts `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`.

**The honest boundary** has two axes, and collapsing them is what makes
this easy to get wrong. **Whether a call proceeds** — the binding gates
that **in the loops that consult it**, and a rebind can stop a call
outright. In the `/shell-team:run` and `/shell-team:goal` loops each
role's executor is resolved before any invocation, and a refusal is a
blocker that stops the phase rather than falling back to anything: an
ordinary edit can reach `binding-unresolved`, `capability-unsupported`
and `executor-unavailable`, each described above. The two standalone
review commands consult the binding too, in their own review step.
`/shell-team:review` resolves `codex-reviewer`'s executor immediately
before it invokes the reviewer, and `/shell-team:review-response` does
the same before its own cross-evaluation step; in both, a refusal is a
blocker that stops the command rather than falling back, so a rebind
reaches them exactly as it reaches a run. `/shell-team:review-response`
additionally reaches resolution a second way, through the last step
that hands the findings you accept to `/shell-team:run`. The two
remaining commands, `/shell-team:loop-triage` and
`/shell-team:team-init`, invoke no bound role at all, so there is
nothing for resolution to resolve in them. **How a proceeding call is
executed** — there the binding changes
**only** what `resolve-executor.sh` resolves and reports and what
**telemetry** records, provider, model, effort and adapter alike, and
nothing about the execution itself, so no alternate-executor
**invocation path** is wired. Three instances of that second axis,
illustrative rather than exhaustive: the **model** a role runs at still
comes from that role's own `agents/<role>.md` pin, not from the resolved
row — issue **#236** tracks retiring those pins, for the five
`claude-cli`-bound roles only, and deliberately excludes `codex-reviewer`,
whose pin configures the Claude wrapper that shells out to the Codex CLI
rather than the model that reviews; a declared **effort** is recorded on
the span but applied to no call, its only other effect being the
`capability-unsupported` refusal above — an adapter definition declares
an effort *mechanism*, and declaring one is not applying it; and which
**executor** — provider and adapter — a role is invoked through is not
routed by resolution at all, for any role, with no issue tracking that.
The rule to take away is the second axis stated universally rather than
its list: every bound value is **declared, never an observation of what
executed**.

## Conversational usage (no slash commands)

You can also just describe what you want in plain language and let the main Claude
session delegate to the team (the way you already get a Codex review without
typing a slash command). See [usage-conversational.md](usage-conversational.md) for
the model and example conversations. To make the full loop fire reliably from
chat, copy the opt-in routing block from
[`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
into your repo's `CLAUDE.md` — `team-init` does not add it for you (it never
touches your `CLAUDE.md`); whether to adopt the routing policy is your call.

## Declaring adopter-facing documentation

Every spec frozen from T-1061 onward declares, on one line inside its own
frozen intent block, whether its deliverable is a **user-visible capability**:
a top-level bullet `- user-visible: yes — <rationale>` or
`- user-visible: no — <rationale>`. A `yes` declaration is discharged in
exactly one of two ways: an acceptance criterion carries an indented
`- adopter-surface: <where the documentation lands>` line, or the spec
carries a top-level `- adopter-docs-waiver: <reason>` line for a
user-visible capability with no adopter-docs surface — a first-class
outcome, not a workaround. Carrying either marker beside a `no` declaration
is refused, on the same footing as a `no` declaration passing on its own.

Enforcement today is a **duty, not a checker**. At a task's first freeze
the coordinating session reads that declaration region itself, requires
exactly one declaration with a non-empty rationale, and — for `yes` —
requires either the `- adopter-surface:` line under a criterion or a
non-empty `- adopter-docs-waiver:`, never both and never either beside a
`no`; anything else refuses the freeze and routes the spec back to its
author. **no mechanical checker ships for it yet.** One was built and
then carved out to issue #250 under T-1061's own pre-commitment, after
two consecutive review rounds found independent defects in its
scan-scoping logic; shipping a gate that passes a spec it should refuse
is worse than shipping an honest prose duty, so the mechanism waits for a
redesign rather than a third patch. The boundary is unchanged in either
form: the sweep **does not open**, resolve or validate the surface a spec
names — whether a named surface is really adopter-facing is a matter for
the reviewing gates and the human, never for a mechanical check, and a
path allowlist would coerce every adopter's repository into this one's
layout. The duty applies at a task's bootstrap freeze only, never at a
re-freeze of an already-recorded hash.

## Trying the team on one ticket

If you just want to run the loop once, on one real ticket, without deciding anything about how your whole team adopts it: create a **trial branch**, scaffold onto it with shipped mechanics, commit the operating files there, run the loop, and delete the branch afterward. The loop's gates assume the operating files are **tracked**, and this route honors that assumption instead of working around it — `git switch -c` followed by `team-init`, or the two combined with `team-init.sh`'s own `--trial-branch <name>` flag.

**Setup.**

```bash
git switch -c trial/one-ticket
team-init.sh .
git add "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"
git commit -m "chore: scaffold shell-team for a one-ticket trial"
```

Both `--get` arguments matter: in the default layout they resolve to the same directory, but in the legacy `tasks/` + `docs/specs/` layout `docs/specs/` sits outside the base dir, and dropping the second argument would leave it permanently untracked — commit with both, never with a hardcoded, single-directory form.

The first line and the `team-init.sh` line above can also be run as one step: `team-init.sh --trial-branch trial/one-ticket .` creates `trial/one-ticket` and switches to it before scaffolding, refusing (exit 2, with a remedy) if the target is not inside a git work tree, is not that work tree's top level, or the branch already exists — the two commands staying separate is not required, only convenient to show. Without `--trial-branch`, `team-init.sh` invokes no git command of its own and does not care which branch you are on.

If your machine's global excludes (`core.excludesFile`) hide the base dir, that plain `git add` refuses outright the moment you run it. Force the scaffolded files onto this one branch with `git add -f "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"`, or add a repo-level re-include to your root `.gitignore` for whatever `team-paths.sh --get base` resolves to in your repo — `!.shell-team/` in the default layout, `!tasks/` in the legacy layout — as described in [Where the operating files live](#where-the-operating-files-live), so the ordinary form works for good.

Now run `/shell-team:run <what you want built>` as usual, on the trial branch.

**Teardown.** Substitute your own repository's integration branch for `<integration-branch>` — `develop` in this repository, `main` in many others.

```bash
git switch <integration-branch>
git branch -D trial/one-ticket
```

Deleting an **unmerged** branch destroys every commit **reachable only from** it — the scaffolded base dir, the board, the spec and the task's own records — and nothing else: no other branch's tip moves, no mainline history changes, and no file you never committed to the trial branch is touched. Because the branch is unmerged by design, `git branch -d` declines the deletion and you need the force form, `git branch -D`; that is the expected, non-anomalous outcome here, not a sign something went wrong. Those commits stay recoverable from `git reflog` until they are eventually garbage-collected.

"Unmerged" is not the same as "never propagated." A commit made on the trial branch can still reach your mainline without the branch ever merging — someone can `cherry-pick` it, or you can `push` the branch to a shared remote where automation or another person picks it up. Keep the trial branch **local**, and if you did push it, delete the remote copy too when you delete the local one — the isolation rests on that discipline, not on the branch being unmerged alone.

Running the loop with the operating files never committed — git-ignored, or simply never added — is **not supported**. The reason differs per gate, stated in the failure mode each one actually has and in the scenario that actually reaches it, rather than as one blanket claim that they all stop working.

`bin/check-durability.sh` **refuses**, and which refusal you meet depends on what you did. With no `<base>/durability-mode` file at all the default mode is `tracked`, and every record the loop needs resolves to no blob in the recorded commit: `not-in-recorded-commit`, or `missing-working-file` when the working file itself is gone too. `untracked-opt-out` is the narrower case — it fires only when a **mode file** declaring `working-tree-only` is itself not committed. Either way the trial reaches no green hand-off.

`bin/check-pii-shapes.sh` reports clean **without having read** the loop's own records at all. Its diff-scoped mode only sees committed changes, and its `--all` mode reaches untracked-but-not-ignored files only — a **gitignored** base dir is read by **neither mode**, which is exactly how you keep the base dir out of git in the first place.

`bin/check-intent.sh` keeps answering from a ledger with no durable existence of its own: the frozen-intent hash and its attestation live on the board, so a **fresh** clone or checkout, or `git clean -fdx` (its `-x` flag is what reaches a gitignored path), simply never has them. `git reset --hard` **leaves an untracked** board alone, so that is not the operation that removes it.

And relocating the base dir outside the repository is not an escape hatch either: `bin/team-paths.sh` refuses an absolute `TEAM_RUN_BASE` outright, so the base dir stays **repo-relative** by the resolver's own decision.

## Declaring the stacked-branch base-ref discriminator and the borrowed-vocabulary sweep

Every spec frozen from T-1081 onward additionally declares, on one line
inside its own frozen intent block, in the same declaration region the
`- user-visible:` and `- verification-class:` keys above already occupy:
a top-level bullet `- base-ref-discriminator: <the instantiated
two-arm expression>` or `- base-ref-discriminator: not-applicable —
<reason>`. This is required of every first-freeze spec, not only one
frozen on a stacked branch. The two forms are not a free choice: the
two-arm expression is the value only when some criterion reads a
base-side blob **and** the branch has an open predecessor at authoring
time (classified once — a later era change, such as the predecessor
merging mid-task, never reclassifies it); every other case — no
base-side blob read at all, or no open predecessor to name — takes
`not-applicable — <reason>` naming the branch's own actual base ref.

Where a spec is frozen on a branch stacked behind one or more still-open
predecessor PRs and its criteria read a base-side blob (a stack-delivered
file's prior state, a pre-change value), the value spelled there is one
two-arm expression, byte-identical across every criterion that reads a
base-side blob:

```
B=$(if git show-ref --verify --quiet refs/heads/<predecessor-branch>; then git merge-base "<predecessor-branch>" HEAD; elif git show-ref --verify --quiet refs/remotes/<remote>/<predecessor-branch>; then git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD; else git merge-base "<integration-branch>" HEAD; fi)
```

This is the canonical shape to copy verbatim — it is not the local-branch-only
shortcut that the prose below merely describes: a checkout where the
predecessor exists only as a remote-tracking ref takes the `elif` arm, whose
`merge-base` argument is the full `refs/remotes/<remote>/<predecessor-branch>`
path (a bare `<predecessor-branch>` would not resolve in that checkout at all).

`<predecessor-branch>` is the immediate predecessor this spec's own
branch is stacked on; `<integration-branch>` is a parameter naming
**your own repository's integration branch** — `develop` in this
repository, `main` in many others — substituted for your own convention
rather than coerced into this one. The first arm is
`git merge-base "<predecessor-branch>" HEAD` when the predecessor
resolves as a local branch, deliberately not a `rev-parse` of its tip: a
rework round that advances the predecessor branch after this branch was
cut moves that branch's tip but not the common ancestor, and the common
ancestor is what "branch point" means here. Where the existence test
instead found the predecessor only as a remote-tracking ref, the same
arm is `git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD`
— that same full ref path, never the bare predecessor name, which a
checkout carrying no local branch of that name cannot resolve
(`fatal: Not a valid object name`). The fallback arm,
`git merge-base "<integration-branch>" HEAD`, is taken once the
predecessor resolves in **neither** namespace and is genuinely gone —
the era in which it has merged and been deleted. The arm is selected by
an explicit `git show-ref --verify --quiet` branch-existence test —
checked against `refs/heads/<predecessor-branch>` where the predecessor
resolves as a local branch, or against
`refs/remotes/<remote>/<predecessor-branch>` where a fresh clone or a
CI checkout only fetched it as a remote-tracking ref and never checked
it out locally; the existence test must find the predecessor in
whichever namespace your checkout actually carries it in, never
assumed to be `refs/heads/` alone — and never by a `2>/dev/null ||`
chain, because a `||` chain cannot distinguish "the predecessor branch
is gone" (the expected era change, which must fall back) from
"`git merge-base` failed for another reason" (which must fail closed).
No 40-hex commit literal is ever written into a criterion.

A checkout where the predecessor resolves in **neither** namespace —
never fetched at all: a shallow or `--single-branch` clone, or a CI
checkout that fetched only the child branch — is not the era the
fallback arm exists for. Whether the predecessor has an open PR is a
fact of the repository's state of record (the train the branch sits
in), never of what your checkout happens to have fetched, so this case
is not a `not-applicable` declaration either: fetch the predecessor
first, or route back, rather than freeze on the arm the existence
test's absence silently selects — that absence looks identical, at the
existence test alone, to a genuine merge, and freezing through it is
ruled out.

Three residual cases are disclosed rather than engineered around, on
the same footing: a predecessor branch deleted without being merged
makes the fallback arm resolve the integration branch's tip, which is
not the branch point — that invalidates the whole stack and is a
route-back, not something a criterion should paper over; and a
predecessor branch rebased, force-pushed, or squash-merged after your
branch was cut is a route-back on the same footing rather than a case
either arm is redesigned to survive — rebase and force-push move the
predecessor's tip so the recorded common ancestor may no longer be an
ancestor of it, and a squash merge instead lands the predecessor's
changes on the integration branch as a commit sharing no SHA with any
of its originals, so `merge-base` resolves a commit earlier than the
real branch point even once the era-change fallback correctly fires —
different mechanisms, the same consequence.

Enforcement today is a **duty, not a checker**, on the same footing as
the adopter-facing-documentation declaration above: at a task's first
freeze the coordinating session reads the declaration region itself and
refuses a spec carrying none, more than one, or one placed outside the
declaration region. No mechanical checker ships for it yet.

Alongside that declaration, every spec's freeze-time premise sweep
classifies each literal count premise it makes about a string token's
occurrences — especially a `= 0` premise — as `own-coinage` (a literal
the task itself introduces) or `borrowed` (a token another document
already coined: an invariant-lock id, a status flag, a grammar family
name, or any other pre-existing vocabulary). This is freeze-time duty
on the spec author: every borrowed token is enumerated in the spec's
own `## Assumptions` section together with the measurement command
that confirms it, and the execution-capable side runs that command
live against the branch point's committed blob before the freeze,
recording the measured value beside the assumption. A sweep scoped
only to "the new literals this task introduces" is not sufficient — a
token already carried onto the stack by a merged sibling task escapes
it, and an unmeasured borrowed-vocabulary count premise is treated as a
broken check line.

## Declaring the verification ceiling

Every spec frozen from T-1093 onward additionally declares, on one line
inside its own frozen intent block, in the same declaration region the
`- user-visible:`, `- verification-class:` and `- base-ref-discriminator:`
keys above already occupy: a top-level bullet
`- verification-ceiling: unit-and-static | real-environment — <rationale>`.
This is the **verification ceiling** — the level QA can actually reach for
this spec — and it exists so a green flag reads "green *up to* this level"
rather than bare green: `unit-and-static` means the loop's own gate can
reach unit tests plus static and textual verification and nothing beyond
the checkout, and `real-environment` means it can additionally exercise the
real runtime a criterion names (a storage put feeding a queue feeding a
worker, a manual deploy, work reachable only behind cloud credentials).

**Neither value is all-or-nothing.** The declared value states what the
gate reached for every criterion *not* individually marked otherwise; a
criterion that sits above the declared ceiling carries its own indented
`- above-ceiling: <who owns this criterion after the gate>` sub-bullet,
naming the human who owns it once the gate has passed — reusing the
shipped `- adopter-surface:` idiom rather than a new free-text list, and
never one sub-bullet standing in for several criteria. This sub-bullet is
available under **either declared value**, which is what makes the honest
mixed case possible: a spec whose criteria span more than one
real-environment capability class at different reach — say a staging
storage-to-queue-to-worker path the gate genuinely exercises for one
criterion, alongside a production deploy or credentialed work it cannot
reach for another — declares `real-environment` for what the gate reached
and marks the rest `- above-ceiling:`, rather than being forced into a
value that misdescribes one criterion or the other.

**The exception set has a floor, so the symmetry cannot be used to say
nothing.** A declared value must attest **at least one criterion at it**:
a `real-environment` declaration under which every criterion is marked
`- above-ceiling:` is refused, because it would be interchangeable with
`unit-and-static` and tell a reader nothing — the honest declaration for
that spec is the highest value at which at least one criterion is actually
verified. `unit-and-static` is the floor and cannot be lowered further, so
the one remaining degenerate case — every criterion sitting above even the
floor — is documented rather than refused: the declaration line must carry
the fixed token `no criterion verified at this ceiling` immediately after
the declared value. That token is then **carried forward, verbatim**, onto
both QA's PASS-block field and the board's `READY_FOR_REVIEW` append, so
the reader who never opens the spec still sees the disclosure on the line
they actually read, rather than a bare value that looks like baseline
coverage.

Enforcement today is a **duty, not a checker**, on the same footing as the
declarations above: at a task's first freeze the coordinating session
reads the declaration region itself, requires exactly one conformant
`- verification-ceiling:` line, and refuses a missing, duplicated,
out-of-vocabulary or vacuous declaration — or a criterion plainly
demanding capabilities above the declared ceiling with no
`- above-ceiling:` sub-bullet naming its owner — routing the spec back to
its author. **No mechanical checker ships for it yet**; the mismatch case
is a reading judgment a human performs, not a state a grep can decide, and
it rides on the same disclosed-limitation pattern issue #250 already
carries for this repository's other declaration-region gates. The duty
applies at a task's bootstrap freeze only, never at a re-freeze of an
already-recorded hash, and it makes no claim about what a declared ceiling
prevents — it only makes the level QA reached legible to whoever reads the
hand-off or the board line afterward.

## Choosing who authors the spec (T-1091)

From T-1091 onward, spec authorship is itself a dispatch decision — a
third axis, `specify`, closed over `pm-authored` and `operator-authored` —
alongside the existing `implement`/`verify` axes, decided at Plan and
recorded on the task's board entry at the same seam.

**`pm-authored` is the shipped default.** `pm-spec` authors the spec, exactly
as it does today. Pick this whenever a task's decision inputs are not
concentrated in one session's own context — most tasks fit this shape, and
formalization (turning a request into a testable spec) is `pm-spec`'s
comparative advantage.

**`operator-authored` is for a judgment-density bottleneck.** Route here when
the decision inputs for the task — measured facts across repositories,
live-environment confirmations, incident history — already live in the
coordinating session's own context, so delegating authorship to `pm-spec`
would have arithmetically zero value: writing a complete hand-off package
already **is** writing the spec, and the delegation would only convert
verified first-hand facts into relayed ones. In this mode the coordinating
session (the operator) writes the spec directly; `pm-spec` then participates
as a **conformance formatter**, not an author — it shapes the document into
the check-intent and check-acs grammars, never rewrites what the author
decided, and flags any substantive gap back to the author rather than
closing it on its own judgment.

**The anti-pattern this guide exists to prevent.** Refusing `pm-spec`
authorship is not a reason to leave the loop's machinery behind. The
frozen intent block, the board records, the freeze sweep, both review
gates, and the interventions ledger are what catch mistakes an operator
makes just as readily as ones `pm-spec` makes — an operator-authored spec
still runs the full loop, unchanged from the freeze sweep onward. Choosing
`operator-authored` chooses who writes the spec, never whether the rest of
the machinery runs.

**A mechanical backstop now exists for the conformance read itself
(T-1096, issue #341).** `bin/check-entry-mode.sh` refuses a task's freeze
unless the board carries both `pm-spec`'s own `- entry-mode:` sub-bullet
and the coordinating session's `- dispatch: specify — …` sub-bullet,
agreeing in both directions, with every flagged gap answered by a
matching `- flagged-gap-resolution:` sub-bullet — a missing source refuses
rather than passing silently, so the verdict does not depend on which
sub-bullet was transcribed first. This checker's `operator-authored` arm
is shipped **fixture-exercised only**, deliberately **not exercised by a
live run** in this repository yet: the task that built this checker
elected `pm-authored` for itself, since becoming the first live
`operator-authored` case would have made the coordinating session the
author of the very check auditing author/attester separation. The
checker still does not verify that the conformance read itself
happened — only that a conformant record of it exists and agrees with
what Plan decided.

**The same checker also gates a cross-task dispatch reflection (T-1109,
issue #365).** Before transcribing the situational dispatch record above,
the coordinating session skims the immediately preceding task's own board
entry and records, per axis, whether this task repeats or diverges from
what that predecessor elected: `- dispatch-reflection: <axis> —
<predecessor> — <repeat|differs|no-predecessor-row> — <ground>`, or the
single `- dispatch-reflection: all — no-predecessor — no-predecessor-row
— <ground>` line where the task has no predecessor at all.
`bin/check-entry-mode.sh` refuses the freeze when this family is present
but malformed, when it does not cover every axis the entry's own
`- dispatch:` rows record, when it mixes the no-predecessor form with a
per-axis row, when a named predecessor id does not resolve to exactly one
top-level board entry in either the active or the done section of the
board, or when a stated verdict disagrees with the predecessor entry's
own recorded value for that axis — the same validate-if-present shape as
the dispatch record itself: an entry carrying no reflection line at all
still passes. The substantive judgment the record exists to provoke —
whether a repeated election is actually sound — stays a reading a human
or an agent performs; the checker never claims to close it.

## Electing a spec review at the Specify seam (T-1092)

Alongside `specify`, a fourth dispatch axis elects whether an extra
cross-provider `codex-reviewer` pass reads a spec's **domain** premises
before implementation begins: `spec-review`, closed over `none` and
`cross-provider`, defined and priced in
`docs/loop-engineering/specify-seam-review.md`.

**`none` is the shipped default.** No extra pass runs, and nothing about
the task changes; a routine mechanism task does not pay for the extra
round.

**Elect `cross-provider` when the spec's correctness rests on a domain
premise this repository cannot itself measure** — a deployment or ordering
assumption, a rollback precondition that may not hold in production, a
blast-radius claim about a system outside this repository's reach. The
extra round reads the spec document itself — the frozen intent block plus
its declaration region, never a branch diff — after the freeze sweep and
before the `- intent-hash (v1)` is recorded, and returns `APPROVE` or
`REQUEST_CHANGES` in a `## Spec review` section of the task's review
record. A `REQUEST_CHANGES` routes back to the spec's own author
(`pm-spec` in `pm-authored` mode, the operator in `operator-authored`
mode); the freeze sweep does not proceed until it is answered.

**What it does and does not guarantee.** An elected spec review is never
one of the loop's **both gates** — `qa-verifier`'s PASS and
`codex-reviewer`'s APPROVE on the delivered change both remain required
regardless of this axis's value, and a spec-review APPROVE never
substitutes for either. It also does not authenticate its own inputs (both
condition texts it is cross-checked against are agent-produced), does not
verify that the read actually happened, and does not turn "the domain
premises are sound" into anything more than a reading judgment.

**A close-out backstop now exists for the elected review's own verdict
(T-1096, issue #344).** `bin/check-spec-review.sh` **refuses at
close-out** — inside `bin/close-out.sh` — a `spec-review — cross-provider`
task whose review record's last anchored spec-review verdict line is not
an approval, consulting no heading at all and refusing any unrecognised
tail rather than skipping past it. This axis's `cross-provider` arm
**has** now run end to end, measured directly against this repository's
own **review records**: three of its own tasks reached an APPROVE past
round 1, and this task's own review record is the first one the shipped
close-out backstop reads for real. How often the round changes an
otherwise-implemented, wrong-about-the-world spec remains `undetermined` —
that claim is about the axis's *effect*, which neither checker measures.

## Choosing an oversight profile

A host repository selects an **oversight profile** in a host-authored
`<base>/oversight.conf`, resolved and validated by `bin/check-oversight.sh`
(T-1103, issue #343). The profile is closed over two values, `autonomous`
and `governance-controlled`, and it governs two closed **seam** values,
`specify-seam` (the Specify-seam freeze) and `pre-merge` (`bin/close-out.sh`'s
own exit status). No `- dispatch:` record, no environment variable and no
per-task board field selects a different profile for one task — the
declaration is a per-repository property of one file.

**`autonomous` is the shipped default.** No `<base>/oversight.conf` at all
resolves to it, and it changes nothing: no existing seam gains a
requirement, no existing gate's verdict moves, and every board, spec and
record that is conformant today stays conformant byte for byte.

**Declare `governance-controlled` when your organization's IT governance
imposes segregation of duties** — a change may not advance on the approval
of the party that produced it. Author `<base>/oversight.conf` with `schema
1`, `profile governance-controlled`, and one `seam` row per gated seam.
Each declared seam then requires a recorded, conformant
`- oversight-approval (<seam>): approver=<handle> — producer=<handle> —
approves=<anchor> — date=<YYYY-MM-DD> — record=<locator>` sub-bullet on the
task's own board entry, whose `approver` handle must be distinct from its
`producer` handle after a stated ASCII normalization, and whose `approves=`
anchor must still name the artifact being gated — a stale or inflated
anchor refuses rather than being silently accepted.

**Enrollment does not evaporate.** Once your board carries at least one
prior approval record anywhere on it — in `## Active` or `## Done`, on any
task, for either seam — the declaration going missing refuses
(`enrollment-vanished`) instead of silently resolving back to `autonomous`.
The only authorized way out of governance — the **de-enrollment** path — is
an explicit `profile autonomous` declaration: a present, diffable file,
never a deletion. That evidence is deliberately **the whole board**,
because the profile it protects is a repository-wide property rather than
a per-task one.

**An approval never substitutes for either of the loop's both gates.**
`qa-verifier`'s PASS and `codex-reviewer`'s APPROVE on the delivered change
remain required in **both** profiles; an oversight-profile approval record
is never one of the two gates, in either direction.

**What this mechanism claims, and what it does not guarantee.** It ships a
**self-declared conflict check** with a content anchor — recorded as
tracked workflow evidence, not an authenticated segregation-of-duties
control. It **does not authenticate** any handle: no signature, no SSO or
OIDC binding, no directory lookup, and nothing confirms the named
`producer=` party is the change's actual producer or that the `approver`
ever read what they approved. The board record is best-effort workflow
evidence in the current snapshot, not a tamper-evident or independently
retained audit store — pair it with your own branch protection, commit
signing, retention and removal-monitoring **compensating controls** if your
organization needs those guarantees. The two seams are this loop's own
**callable transitions**, not an organization's release or deployment
authorization boundary: a direct merge, a cherry-pick or a hotfix that
never crosses either seam is never gated. A class-M mechanics-repair
re-freeze is not exempt either — the gate is version-based and
class-blind, so enrolling means every freeze owes a record, a
**mechanics-repair re-freeze** included. Whether an opaque-handle
comparison satisfies any real segregation-of-duties control is
`undetermined`, and no checker in this repository measures it.

**No requirement to wire anything into your CI.** The `pre-merge` seam's
teeth are `bin/close-out.sh`'s own exit status, which an adopter already
runs at that boundary; `check-oversight.sh --seam pre-merge` is documented
here as an option for a host who additionally wants it inside their own CI,
never as a precondition for the profile working. This checker's
`governance-controlled` arm ships **fixture-exercised only**, deliberately
not exercised by a live run in this repository — enrolling this repository
would make the coordinating session both the producer and the approver of
the very mechanism auditing that separation.

## The close-out pre-flip gate

`bin/close-out.sh` reads the task's Active flag before it ever writes to the
board (T-1107, issue #53). Unless that flag already reads `READY_FOR_MERGE`
— the one state `codex-reviewer` writes on APPROVE — the close-out refuses
at exit 1, naming the board path, the source line and the flag it found,
and the board file is left byte-untouched. A task still at
`READY_FOR_ARCH`, `READY_FOR_ENG`, `READY_FOR_QA`, `READY_FOR_REVIEW`,
`BLOCKED` or `REWORK` is refused rather than silently promoted; the fix is
a single flag edit on the board once the review that should have set
`READY_FOR_MERGE` has actually run.

Separately, `close-out.sh --issue N` prints the manual GitHub issue-close
procedure (`develop` merges do **not** auto-close an issue). When `--issue`
is omitted — or passed as an empty string — the script instead prints a
one-line note (`close-out: note: no --issue given`) so the operator learns
the procedure exists rather than seeing nothing; the note and the procedure
are exact complements of one condition, so they can never both fire or both
stay silent on the same run. A printed note is disclosure, not a gate: it
does not refuse the close-out, and an operator who does not read stdout
learns nothing from it either way.

## A relayed count carries its own derivation command

`bin/check-count-claims.sh` (T-1113, issue #397) reads a task's own
`## Active` board entry for `- count: <label> — <value> — command: <cmd>`
sub-bullets, refuses a malformed or duplicated row, and — unless run with
`--no-exec` — re-runs each conformant row's command and refuses when the
measured output disagrees with the declared value. `bin/close-out.sh`
delegates to it unconditionally, in `--no-exec` mode: grammar validation
only, so an entry carrying no `- count:` row still closes out untouched
and the shipped default path gains zero new execution surface. Running the
checker without `--no-exec` is an explicit, separate operator choice — it
warns on stderr (never refusing, never changing the exit status) when the
board it reads is a tracked path carrying uncommitted modifications, since
a board entry, unlike this project's own frozen and review-gated specs,
can be edited by any role at any point in a task's life.

## Recording review-input fidelity

Each executor pass a review record's verdict section names states four
things under one opaque pass id, and `bin/check-review-input.sh` (T-1104,
issue #335) validates the grammar fail-closed: the pass's
**executor-invocation** — the verbatim argv rendered on a single line —
its **pass-role** from the closed set `generation` / `confirmation`, a
**briefing-fidelity** statement whose first token is `carried` /
`not-carried` / `not-applicable` followed by a non-empty explanation, and
the **raw-capture** stem that pass published. A record carrying zero such
fields — every record already committed today — exits 0: the requirement
is forward-only.

**What the verbatim field must never carry.** The `executor-invocation`
value is real argv, and it lands in permanently tracked git history. It
must never carry an environment dump or a variable's expanded value, a
credential, token, key or authentication header, an
absolute path outside the repository (a home-directory path or a
`$TMPDIR` session root in particular), or any operator or account
identity. Where the real argv carries an absolute path under the
invoker's home directory — the `--cd` argument in particular — record
that path as `<repo-root>`, relative to the repository root, instead;
every flag, every other argument and their order stay verbatim. This is
a recording convention, not something the checker enforces: it never
judges the field's content, so a record written either way is
conformant.
`bin/check-pii-shapes.sh`'s diff-scoped CI step is a real, and equally
finite, backstop — a **finite known-shape screen** keyed on named
prefixes, named roots and stated length minimums, never comprehensive
secret detection — so the field contract above is the primary control,
applied at the moment of writing, which is the only moment it is cheap.

**What this mechanism does not close.** It records what was invoked,
never what a model actually received: no judgment over committed bytes
can tell an invocation whose briefing reached the executor's context from
one where it did not. It does not verify a `pass-role` label's
truthfulness against its own verbatim field, or that a recorded argv is
the argv that actually ran. And it cannot see whether the raw file a
`raw-capture` field names is **not present on disk** — raw captures are
untracked by construction (`/.gitignore`), so a stem naming nothing is
conformant to this checker.

## Deriving the release version at freeze time

At every freeze — a task's first freeze and any re-freeze, including a
class-M mechanics-repair re-freeze — the coordinating session
re-derives the release tier from the spec's own declarations, before
that freeze's `- intent-hash` line is appended: a `- user-visible:`
line and a `- verification-class:` line. The derivation applies
`CONTRIBUTING.md`'s `## What a version number encodes` headline test
and default-reachability test jointly: a `- user-visible: yes`
declaration is the derivation's **trigger**, never its verdict, and the
derived tier is one of `MAJOR`, `MINOR` or `PATCH`.

The result is recorded on the task's own board entry as a
`- version-derivation` sub-bullet, in the shape
`- version-derivation (v<N>, YYYY-MM-DD):`, whose closed fields —
`verdict=`, `derived=`, `headline=`, `default-reach=` — precede one
free-form `grounds:` field, so a later checker can validate the family
when it is present while an entry carrying none of this still passes.
The `premise=` field between them is required to be self-contained: it
carries the expected tier together with the ground the planning
approval was given on, never a bare pointer to an approval a later
reader has no way to open. Where the repository has no approved
planning premise on record — the shipped default for an adopter who
never configured one — there is nothing to derive against; this is
never a reason to refuse the freeze, and the record is still written
with `verdict=no-premise-on-record`.

When the derived tier disagrees with the repository's approved planning
premise, the freeze stops before any further work on the task and
issues a deviation notice: stated in English, never a bare "proceed?",
and carrying all three of its required elements — that the work now exceeds the approved estimate, the continue-or-stop question, and a
recommendation with its rationale. This stop is not a fourth human gate: it re-enters the existing planning-approval gate, one of the
three standing human gates this loop already declares, because a
derived tier that disagrees with the approved premise means that
approval has lapsed. No new status flag and no new phase are added.

Enforcement today is a **duty, not a checker**: the coordinating
session performs this derivation as a read, and no mechanical checker ships for it yet.

## Operating rules

- Do not advance a phase until the previous phase's status flag is set in the board.
- A task is done only when the Codex reviewer sets `READY_FOR_MERGE` — which requires QA to have passed first (`READY_FOR_REVIEW`); both the QA pass and the cross-provider review must clear.
- The reviewer runs on a different model provider (Codex) on purpose — keep it in the loop.
- Files are the only shared state between agents (they do not share memory): the
  board (`<base>/todo.md`), the specs (`<base>/specs/`), and the loop contract are
  the single source of truth.
