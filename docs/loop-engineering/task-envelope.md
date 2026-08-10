# The task envelope — an adapter contract, not a serialization protocol

**Task**: T-1055 · GitHub issue #203 (host-assigned executor configuration) ·
`.shell-team/specs/T-1055-adapter-envelope.md`

This document is the normative, prose half of the task-envelope contract.
The machine-readable half — the same field tokens, plus the closed channel /
error-class / effort-mechanism vocabularies and the per-role board-transition
authority table — is `templates/task-envelope.txt`, resolved and validated by
`bin/check-adapter.sh`. The two are checked against each other: this
document's field-token set and the registry's field-token set must be equal
in both directions.

T-1054 shipped a host-authored binding config (`bin/check-binding.sh`,
`templates/binding-template.conf`): a host can declare which provider, model,
effort and adapter runs each of the six inner-loop roles. Nothing consumed
that binding yet — this document is what an adapter *is*: what it is handed,
what it must give back, and how an unsupported `effort` value fails closed
before a run rather than surprising a host inside one.

## What this task ships, and what it does not

Four artifacts: this document, `templates/task-envelope.txt`, the two
initial adapter definitions (`templates/adapters/claude-cli.txt` and
`templates/adapters/codex-cli.txt`), and `bin/check-adapter.sh` with its
fixture suite. **Nothing here invokes an executor.** No code composes an
argv, calls a provider, or reads this contract at loop-run time — that is
T-1056's work. No envelope *instance* format exists either (see the boundary
statement below) — this is a vocabulary for describing what a later
component passes and gets back, not a payload anything here constructs.

- boundary: The task envelope is a documented contract for what adapters receive and return, not a new serialization protocol: the substrate (files and the board) remains the actual interchange.

A cross-provider review round (v1 → v2) reproduced four contract-design
gaps a fail-closed checker cannot patch its way out of, each resolved
definitionally rather than by adding an ad hoc check: `carries` now
declares a value's return path and never an authority to act, with the
`board` channel retired (DP13, below); `status` gets a machine-checkable
vocabulary, `status-value` (DP14, below); the plugin-shipped adapter
allowlist (`templates/binding-adapters.txt`) is validated at full parity
with `bin/check-binding.sh`'s own reading of that same file, reusing that
checker's own tokens (DP15 — the fix for round 1's Blocker); and the two
shipped contract forms were held in agreement by the checker itself, via a
`--doc [PATH]` mode.

A second review round (v2 → v3) reproduced that the `board` channel's
retirement was still a fact about the shipped registry FILE rather than a
property of the checker: a scratch contract could re-declare `channel
board` and validate cleanly. This spec's own pre-commitment fired at that
point (two consecutive rounds of new findings against the same component),
and its recorded disposition was executed: the `--doc` mode is carved out
of this branch to a successor issue, and the retirement is fixed
structurally instead (DP17, below) — the checker refuses a retired channel
token from its own compiled-in set, from whichever contract file is
loaded, and the registry declares that same set so a reader of the
contract sees it too. Two-form agreement between this document and the
registry is still required and still checked — by the spec's own AC8, at
spec-check time — but it is no longer a standing CI gate; that is a stated
loss, not an oversight.

A third review round (v3 → v4) reproduced that the checker's cross-check
against a host-authored binding config validated the delegated `schema`
line for presence but not content, the same "trust the shape without
validating it" pattern a prior round had already found in that same
reassertion block. The pre-commitment fired a **second** time, and its
recorded disposition was executed again: the whole cross-check mode is
carved out of this branch to a successor issue (DP18, below). What that
mode once enforced — the fail-closed effort rule and the board-transition
authority rule — now ships as **byte-frozen normative statements** in this
document instead, pinned by the spec's own AC6, so the rules survive the
drop even though nothing in this task checks a binding config against them
any more; that enforcement is inherited by the successor issue and by
T-1056.

## The generalized invocation pattern

Every adapter generalizes one pattern this repository already runs:
`agents/codex-reviewer.md`'s own invocation of the Codex CLI. That role is
reached as a bare-first-token `codex exec --sandbox read-only --cd <repo>
...` call whose **request** is a prompt and whose **working dir** is an argv
value. Results come back two ways: as **files** — the `-o` last-message
capture, the JSONL event stream, the review record under the resolved
reviews directory — and as a **verdict block** the orchestrator reads and
transcribes (who may act on that transcription is `role-board-authority`'s
to say, not this pattern's — see `## Carries declares a return path, never
an authority` below). Availability is probed with `codex --version`, whose
verbatim output is recorded as provenance; a missing CLI or a failed auth
check is `BLOCKED` with the exact error, never a silent substitution of a
same-family reviewer.

An adapter is the same shape, generalized: an executor is reached through
some concrete invocation (a CLI flag, a prompt convention, a config
override); it receives the envelope's `in` fields through *some* existing
channel (argv, prompt text, stdin, ...) and returns its `out` fields through
some other existing channel (a file, stdout, stderr, the exit code). Which
channel carries which field, for a given adapter, is declared in that
adapter's own `carries <field> <channel>` rows — never invented per
invocation and never a second implementation of the same mapping.

## Envelope fields

Fourteen fields. Direction is stated from the **adapter's** point of view:
`in` is what an adapter receives, `out` is what it returns. A conditional
field is always declared (never silently absent from the contract); its
condition is stated on its own line below, as the literal phrase
`required when`. Each field's own bullet below is machine-checked by the
spec's own AC8: its direction/requiredness tuple must match
`templates/task-envelope.txt`'s row for that field, byte for byte, and this
is what closed a real, reproduced drift (round 1: this section's own
`task-id` bullet was flipped from `in` to `out` with the registry left
unchanged, and nothing before v2 caught it).

- **task-id** — in, required — the `T-NNN` this invocation serves.
- **role** — in, required — which of the six inner-loop roles is being run.
- **phase** — in, required — which loop phase this invocation serves.
- **request** — in, required — the work statement handed to the executor.
- **artifact-paths** — in, required — the operating paths the role reads
  and writes, as already resolved by the orchestrator — never re-derived
  by the adapter itself.
- **working-dir** — in, required — the repository root the invocation
  runs in.
- **resolved-binding** — in, required — the bound row for this role:
  provider, model, effort, adapter — exactly as `bin/check-binding.sh
  --print-binding` resolves it.
- **status** — out, required — whether the invocation completed, from the
  contract's closed `status-value` vocabulary (`templates/task-envelope.txt`'s
  own directive — see `## The status vocabulary` below; exactly one member
  is marked `success`).
- **verdict** — out, conditional — required when the role's phase produces
  one (a `PASS`/`FAIL`, an `APPROVE`/`REQUEST_CHANGES`); absent for a phase
  whose role reports no such token (e.g. an engineer's implementation
  pass).
- **produced-artifacts** — out, required — the paths the invocation wrote.
  The envelope names them; it never carries their content.
- **board-transition** — out, conditional — required when the role's own
  `role-board-authority` is `writes` or `proposes`, absent when it is
  `none`. Its `carries` channel declares only where this field's OWN VALUE
  travels — never who may act on it (DP13, `## Carries declares a return
  path, never an authority` below). For a `writes` role the field records
  what the role itself already wrote to the board; for a `proposes` role
  it is a **request** the orchestrator transcribes, never an act the
  adapter performs on the board's behalf.
- **usage** — out, required — the resource accounting the executor
  reported. Where the executor reports none, the adapter says so
  explicitly rather than omitting the field — an envelope always carries a
  `usage` value, even when that value is "none reported."
- **error-class** — out, conditional — required when `status` is not the
  success value, from the contract's closed error-class vocabulary.
- **adapter-version** — out, required — the version of the adapter
  *definition* that actually ran — read from the definition file itself
  (`templates/adapters/<token>.txt`'s own `adapter-version` line), not
  something the executor process reports back.

```
<!-- BEGIN contract-canon -->
schema 1
field adapter-version out required
field artifact-paths in required
field board-transition out conditional
field error-class out conditional
field phase in required
field produced-artifacts out required
field request in required
field resolved-binding in required
field role in required
field status out required
field task-id in required
field usage out required
field verdict out conditional
field working-dir in required
channel argv
channel exit-status
channel file
channel not-carried
channel prompt
channel stderr
channel stdin
channel stdout
retired-channel board
status-value error failure
status-value ok success
status-value refused failure
error-class capability-unsupported
error-class contract-violation
error-class executor-unavailable
error-class invocation-failed
effort-mechanism cli-config-override
effort-mechanism cli-flag
effort-mechanism none
role-board-authority codex-reviewer proposes
role-board-authority engineer writes
role-board-authority pm-spec writes
role-board-authority qa-verifier writes
role-board-authority tech-lead none
role-board-authority ui-designer none
<!-- END contract-canon -->
```

The block above is regenerated, never hand-edited: `bash
bin/check-adapter.sh --print-contract` redirected between the two marker
lines. The spec's own AC8 requires it byte-identical to that command's live
output — this is the **table-level** half of the two-form agreement,
covering every directive (including one a later task adds) with no parser
to extend; the **tuple-level** half is each field's own bullet above,
checked independently, with exactly one bullet required per field.

## Carries declares a return path, never an authority (DP13)

Round 1 reproduced a category error in the v1 cut: `role-board-authority` is
**role**-scoped (which of the six roles may write, propose or request
nothing), while `carries` is **adapter**-scoped (what an adapter's own
invocation shape can return) — and nothing in `bin/check-binding.sh`'s
grammar restricts which role may bind to which adapter (only the
provider/adapter pairing is checked). `templates/adapters/claude-cli.txt`
declared `carries board-transition board` unconditionally in v1, which
read as "this adapter writes the board itself" — wrong for a `proposes`
role (`codex-reviewer`) legally bound to it, since that role must never
write the board directly.

The fix is definitional, not a new check bolted on: **a `carries <field>
<channel>` row states which part of the existing substrate the field's own
VALUE travels on between the orchestrator and the executor, and states
nothing about who may act on it.** `codex-reviewer` is the measured
instance: its `role-board-authority` is `proposes`, so the role itself
never edits the board — it states the transition it wants in its verdict
block and its review record, and the orchestrator transcribes it. Whether
the board is actually written during a given invocation is decided
**solely** by the bound role's `role-board-authority` row (below) — never
by any adapter's channel
declaration. Making the wrong state unrepresentable is preferred here over
detecting it after the fact, which is why the `board` channel token —
which named an action rather than a path — is **retired** from the
contract's channel vocabulary entirely, rather than kept and cross-checked
against role authority everywhere it might appear.

One genuine join remains, and is stated here as a **normative obligation**
rather than something this task's checker enforces: `board-transition` is a
*conditional* field, so `carries board-transition not-carried` stays legal
in general (an adapter through which no transition ever returns) — but
binding a role whose authority is `writes` or `proposes` to such an adapter
is a contradiction the contract forbids (the role must produce a
transition, and the adapter declares no path for it). Checking a host's
binding config against this join was `bin/check-adapter.sh`'s
cross-check mode — the one mode that knew the role and the adapter
together — until it was carved out at v4 (DP18, below); the rule survives
in the `- normative: ` line under `## Board-transition authority`, and its
enforcement is inherited by the successor issue and by T-1056.

## The channel vocabulary

A `carries <field> <channel>` row in an adapter definition claims which part
of the existing substrate a field's VALUE travels on for that adapter —
never an instruction to execute anything, and never a claim about who may
act (above). The channels `templates/task-envelope.txt` declares:

| Channel | What it names |
|---|---|
| `argv` | a command-line argument to the executor's invocation |
| `prompt` | embedded in the prompt / request text handed to the executor |
| `stdin` | piped to the executor's standard input |
| `stdout` | the executor's standard output (its final answer, in a headless/print invocation) |
| `stderr` | the executor's standard error stream |
| `file` | a file the executor reads from or writes to (a captured output, a review record, the definition file itself) |
| `exit-status` | the executor process's exit code |
| `not-carried` | this field is not carried by this adapter at all |

There is deliberately no `board` channel (above) — a v1 row of that name is
retired and must not be reintroduced. Since v3 (DP17) that retirement is
enforced structurally, not merely observed on this shipped file: the
checker refuses a `channel` row naming `board` from its own compiled-in
retired set, whichever contract is loaded, and the registry's own
`retired-channel board` row makes the retirement visible in the contract
itself — see `templates/task-envelope.txt`'s header comment for the
directive's shape.

## The status vocabulary (DP14)

The `status` field's closed vocabulary now has a machine-checkable form:
`templates/task-envelope.txt`'s `status-value <token> <success|failure>`
directive. Exactly one row is marked `success`; at least one is marked
`failure` — `error-class` is required exactly when `status` is not the
success value, so "which token means success" cannot be left as a
convention nobody encodes. The shipped set:

| Token | Kind | What it means |
|---|---|---|
| `ok` | success | the invocation completed and every required `out` field is present. |
| `refused` | failure | the invocation completed, but the executor's own request or content was rejected — a content-level failure, not an infrastructure one. |
| `error` | failure | the invocation could not complete at all — an infrastructure or environment failure, distinct from a content refusal. |

None of this set's membership is frozen (only the shape — closed, declared
here, exactly one `success`, no token declared more than once even across
`success` and `failure` — is); a later task that finds it needs a
different or finer-grained set edits this registry, and the spec's own
AC8 immediately proves the document and the registry still agree.

## Board-transition authority

One `role-board-authority <role> <writes|proposes|none>` row per inner-loop
role, measured from that role's own shipped prompt rather than assigned by
this task:

| Role | Authority | Measured from |
|---|---|---|
| `tech-lead` | `none` | `agents/tech-lead.md` frontmatter (`tools: Read, Grep, Glob` — no `Edit`/`Write`) and its description ("Does NOT execute code or write files"); it writes no file at all, so it requests no board transition. |
| `pm-spec` | `writes` | `agents/pm-spec.md`: "Set the status flag to `READY_FOR_ARCH` when done" — the role edits the board itself. |
| `engineer` | `writes` | `agents/engineer.md`: "Update `tasks/todo.md`: ... set status to `READY_FOR_QA`" — the role edits the board itself. |
| `qa-verifier` | `writes` | `agents/qa-verifier.md`: "set status to `READY_FOR_REVIEW`" or "set status back to `READY_FOR_ENG`" — the role edits the board itself. |
| `codex-reviewer` | `proposes` | `agents/codex-reviewer.md`: "you never edit the board ... You state it in your verdict block and in your review record, and the orchestrator transcribes it." |
| `ui-designer` | `none` | `agents/ui-designer.md`: "Don't introduce a new status flag. The board flag stays where pm-spec set it." |

- normative: Whether the board is written during an invocation is decided solely by the bound role, from its role-board-authority value, and never by the adapter; binding a role whose authority is writes or proposes to an adapter that declares no return path for board-transition is a contradiction this contract forbids.

This rule was enforced by `bin/check-adapter.sh`'s binding-config
cross-check mode until DP18 carved that mode out at v4; it now ships as
the byte-frozen statement above, with its enforcement inherited by the
successor issue and by T-1056 (`## What T-1056 inherits from here`,
below).

A disclosed, unresolved nuance carried over rather than fixed here (it is a
pre-existing property of a file this task must not edit):
`agents/qa-verifier.md`'s own `tools:` line grants neither `Edit` nor `Write`
while its loop instructs a board update. That inconsistency is not this
task's to repair.

## Effort mechanism measurements (DP7)

The `effort` capability is measured against the real, locally installed
executor, never guessed — a claim with no positive content until it is
actually run once. Both measurements below were taken 2026-08-10.

### `codex-cli`

```
$ codex --version
codex-cli 0.145.0
```

The Codex CLI's top-level `--help` and `codex exec --help` document no
dedicated `--effort` or `--reasoning` flag. What exists is a generic
per-invocation config override, `-c key=value` (already used, per this
machine's own `~/.codex/config.toml`, to set `model_reasoning_effort =
"high"` as a *persisted* default) — so the per-invocation mechanism is that
same override spelled at the command line: `-c
model_reasoning_effort=<value>`.

The CLI performs no client-side validation of the value passed this way; the
provider itself does. Confirmed live by deliberately passing a value no
provider defines:

```
$ codex exec -c model_reasoning_effort=not-a-real-value --skip-git-repo-check "reply OK"
...
reasoning effort: not-a-real-value
...
ERROR: {
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "[ReasoningEffortParam] [reasoning.effort] [invalid_enum_value] Invalid value: 'not-a-real-value'. Supported values are: 'none', 'minimal', 'low', 'medium', 'high', 'xhigh', and 'max'."
  },
  "status": 400
}
```

This is a measurement, not documentation read and trusted: the provider's
own 400 response is the authoritative statement of its accepted value set.
Recorded in `templates/adapters/codex-cli.txt` as `capability effort
supported`, `effort-mechanism cli-config-override`, and seven `effort-value`
rows (`none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`) transcribed
verbatim from that error message.

### `claude-cli`

```
$ claude --version
2.1.226 (Claude Code)
```

`claude --help` documents a dedicated, first-class flag:

```
--effort <level>                      Effort level for the current session
                                       (low, medium, high, xhigh, max)
```

This is a CLI flag, not a generic config override, so its mechanism is
recorded as `cli-flag` (distinct from `codex-cli`'s `cli-config-override`).
Recorded in `templates/adapters/claude-cli.txt` as `capability effort
supported`, `effort-mechanism cli-flag`, and five `effort-value` rows (`low`,
`medium`, `high`, `xhigh`, `max`) transcribed verbatim from that help text.

### The specimen reconciliation (DP7's two branches)

`templates/binding-template.conf` binds `tech-lead` at effort `high` on the
`claude-cli` adapter. The measurement above shows `claude-cli` supports
`high` (it is one of the five values `--effort` accepts), so DP7's **first**
branch applies: the specimen is left exactly as T-1054 shipped it. No edit
was made to `templates/binding-template.conf` by this task.

## Fail-closed effort, statically and at runtime

- normative: An adapter presented an effort value it does not declare fails closed: it returns a non-success status with error-class capability-unsupported and invokes nothing, never silently ignoring the value and never substituting a default. An unset effort means the provider or model default.

An unset effort (`-`) is always accepted, by an adapter that supports the
capability and by one that does not. A bound, non-`-` value must be one
the bound adapter's own declared `effort-value` set names; an adapter
declaring `capability effort unsupported` accepts no non-`-` value; one
declaring `supported` accepts only values inside its declared set.

**Static enforcement of this rule, before a run** was `bin/check-adapter.sh`'s
binding-config cross-check mode, refusing `effort-unsupported`; it was
carved out at v4 when this spec's pre-commitment fired a second time
(DP18). The rule above is what survives the drop, byte-frozen and pinned
by the spec's own AC6; checking a host's bound effort value against it,
before a run, is inherited by the successor issue rather than shipped
here. **Runtime** (T-1056, not shipped here either): an adapter actually
invoked with an effort value it cannot honour returns `status`
non-success with `error-class capability-unsupported` and invokes
nothing — the error class already exists in this contract's vocabulary
so that task does not have to invent one.

A second, related normative rule — the board-transition authority join a
role/adapter binding must satisfy — lives under `## Board-transition
authority` above (DP13); it was enforced by the same now-carved-out mode.

## Telemetry readiness

This envelope already carries what #203 design point 4's telemetry
(T-1057) needs, so that task does not have to reopen this contract. Five
fields supply it directly: `role` (which of the six roles ran),
`resolved-binding` (which packages `provider`, `model` and `effort` for this
invocation), `adapter-version` (which adapter definition actually ran),
`usage` (the resource accounting the executor reported), and `error-class`
(the failure category, when the invocation did not succeed). `provider`,
`model` and `effort` are not separate envelope fields in their own right —
they are the three values `resolved-binding` packages, exactly as
`bin/check-binding.sh --print-binding`'s own `bound <role> <provider>
<model> <effort|-> <adapter>` row already resolves them.

## What T-1056 inherits from here

- The runtime half of the fail-closed effort rule (above).
- The runtime half of GitHub issue #221: re-asserting, over whatever
  production call sites it adds, that nothing forwards
  `bin/check-binding.sh`'s registry-override testing affordance except that
  script itself — this task creates no production caller, so it can only
  assert that invariant holds today (`bin/check-adapter.sh`'s own AC12).
- Adopter-facing documentation of the whole feature (`README.md`,
  `docs/adopting.md`) — declined here for the same reason T-1054 declined
  it: nothing is wired for an adopter to use yet.
- The decision about what a repository with no binding config does at all —
  T-1054's own open item, unchanged by this task.
