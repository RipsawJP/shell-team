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
review commands are not the same case, and the difference is one
delegated step. `/shell-team:review` invokes the reviewer directly and
**never consults the binding** — a rebind changes nothing about it, in
either direction. `/shell-team:review-response` does not consult the
binding **for its own review step** either, but its last step hands the
findings you accept to `/shell-team:run`, and that pipeline consults
resolution like any other run — so a rebind **does** reach
`review-response`, through that step and only through it, including by
refusing and stopping it. Issue **#245** tracks wiring resolution into
the review steps themselves. **How a proceeding call is
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
B=$(if git show-ref --verify --quiet refs/heads/<predecessor-branch>; then git merge-base "<predecessor-branch>" HEAD; else git merge-base "<integration-branch>" HEAD; fi)
```

`<predecessor-branch>` is the immediate predecessor this spec's own
branch is stacked on; `<integration-branch>` is a parameter naming
**your own repository's integration branch** — `develop` in this
repository, `main` in many others — substituted for your own convention
rather than coerced into this one. The first arm is
`git merge-base "<predecessor-branch>" HEAD`, deliberately not a
`rev-parse` of the predecessor branch tip: a rework round that advances
the predecessor branch after this branch was cut moves that branch's
tip but not the common ancestor, and the common ancestor is what
"branch point" means here. The fallback arm,
`git merge-base "<integration-branch>" HEAD`, is taken once the
predecessor branch no longer resolves — the era in which it has merged
and been deleted. The arm is selected by an explicit
`git show-ref --verify --quiet` branch-existence test — checked
against `refs/heads/<predecessor-branch>` where the predecessor
resolves as a local branch, or against
`refs/remotes/<remote>/<predecessor-branch>` where a fresh clone or a
CI checkout only fetched it as a remote-tracking ref and never checked
it out locally; the existence test must find the predecessor in
whichever namespace your checkout actually carries it in, never
assumed to be `refs/heads/` alone — and never by a `2>/dev/null ||`
chain, because a `||` chain cannot distinguish "the predecessor branch
is gone" (the expected era change, which must fall back) from
"`git merge-base` failed for another reason" (which must fail closed).
No 40-hex commit literal is ever written into a criterion. Two
residual cases are disclosed rather than engineered around, on the
same footing: a predecessor branch deleted without being merged makes
the fallback arm resolve the integration branch's tip, which is not
the branch point — that invalidates the whole stack and is a
route-back, not something a criterion should paper over; and a
predecessor branch rebased or force-pushed after your branch was cut,
where the recorded common ancestor may no longer be an ancestor of the
predecessor's new tip, so `merge-base` resolves a commit earlier than
the real branch point — also a route-back rather than a case either
arm is redesigned to survive.

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

## Operating rules

- Do not advance a phase until the previous phase's status flag is set in the board.
- A task is done only when the Codex reviewer sets `READY_FOR_MERGE` — which requires QA to have passed first (`READY_FOR_REVIEW`); both the QA pass and the cross-provider review must clear.
- The reviewer runs on a different model provider (Codex) on purpose — keep it in the loop.
- Files are the only shared state between agents (they do not share memory): the
  board (`<base>/todo.md`), the specs (`<base>/specs/`), and the loop contract are
  the single source of truth.
