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

## The generalized invocation pattern

Every adapter generalizes one pattern this repository already runs:
`agents/codex-reviewer.md`'s own invocation of the Codex CLI. That role is
reached as a bare-first-token `codex exec --sandbox read-only --cd <repo>
...` call whose **request** is a prompt and whose **working dir** is an argv
value. Results come back two ways: as **files** — the `-o` last-message
capture, the JSONL event stream, the review record under the resolved
reviews directory — and as **board tokens** inside a verdict block that the
orchestrator reads and transcribes; the role itself never edits the board.
Availability is probed with `codex --version`, whose verbatim output is
recorded as provenance; a missing CLI or a failed auth check is `BLOCKED`
with the exact error, never a silent substitution of a same-family reviewer.

An adapter is the same shape, generalized: an executor is reached through
some concrete invocation (a CLI flag, a prompt convention, a config
override); it receives the envelope's `in` fields through *some* existing
channel (argv, prompt text, stdin, ...) and returns its `out` fields through
some other existing channel (a file, stdout, the exit code, the board
itself). Which channel carries which field, for a given adapter, is declared
in that adapter's own `carries <field> <channel>` rows — never invented per
invocation and never a second implementation of the same mapping.

## Envelope fields

Fourteen fields. Direction is stated from the **adapter's** point of view:
`in` is what an adapter receives, `out` is what it returns. A conditional
field is always declared (never silently absent from the contract); its
condition is stated on its own line below.

- **task-id** (in, required): the `T-NNN` this invocation serves.
- **role** (in, required): which of the six inner-loop roles is being run.
- **phase** (in, required): which loop phase this invocation serves.
- **request** (in, required): the work statement handed to the executor.
- **artifact-paths** (in, required): the operating paths the role reads and
  writes, as already resolved by the orchestrator — never re-derived by the
  adapter itself.
- **working-dir** (in, required): the repository root the invocation runs
  in.
- **resolved-binding** (in, required): the bound row for this role —
  provider, model, effort, adapter — exactly as `bin/check-binding.sh
  --print-binding` resolves it.
- **status** (out, required): whether the invocation completed, from the
  contract's closed status vocabulary (a success token, a refusal token, and
  an error token — see `## Notes for engineer` in the spec for the suggested
  shape; this cut does not freeze the status vocabulary's membership).
- **verdict** (out, conditional): required when the role's phase produces
  one (a `PASS`/`FAIL`, an `APPROVE`/`REQUEST_CHANGES`) — absent for a phase
  whose role reports no such token (e.g. an engineer's implementation pass).
- **produced-artifacts** (out, required): the paths the invocation wrote.
  The envelope names them; it never carries their content.
- **board-transition** (out, conditional): required when the role's own
  `role-board-authority` is `writes` or `proposes`, absent when it is
  `none`. For a `writes` role the field records what the role itself already
  wrote to the board; for a `proposes` role it is a **request** the
  orchestrator transcribes, never an act the adapter performs on the
  board's behalf.
- **usage** (out, required): the resource accounting the executor reported.
  Where the executor reports none, the adapter says so explicitly rather
  than omitting the field — an envelope always carries a `usage` value, even
  when that value is "none reported."
- **error-class** (out, conditional): required when `status` is not the
  success value, from the contract's closed error-class vocabulary.
- **adapter-version** (out, required): the version of the adapter
  *definition* that actually ran — read from the definition file itself
  (`templates/adapters/<token>.txt`'s own `adapter-version` line), not
  something the executor process reports back.

## The channel vocabulary

A `carries <field> <channel>` row in an adapter definition claims which part
of the existing substrate carries that field for that adapter — never an
instruction to execute anything. The channels `templates/task-envelope.txt`
declares:

| Channel | What it names |
|---|---|
| `argv` | a command-line argument to the executor's invocation |
| `prompt` | embedded in the prompt / request text handed to the executor |
| `stdin` | piped to the executor's standard input |
| `stdout` | the executor's standard output (its final answer, in a headless/print invocation) |
| `stderr` | the executor's standard error stream |
| `file` | a file the executor reads from or writes to (a captured output, a review record, the definition file itself) |
| `board` | the literal, git-tracked task board (`bin/team-paths.sh --get todo`) |
| `exit-status` | the executor process's exit code |
| `not-carried` | this field is not carried by this adapter at all |

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

Two halves. **Static** (this task, `bin/check-adapter.sh --binding`): an
unset effort (`-`) is always accepted, by an adapter that supports the
capability and by one that does not. A bound, non-`-` value is checked
against the bound adapter's own declared `effort-value` set; an adapter
declaring `capability effort unsupported` refuses *any* non-`-` value; one
declaring `supported` refuses any value outside its declared set. Either
refusal is `effort-unsupported`, available to a host before a run.
**Runtime** (T-1056, not shipped here): an adapter actually invoked with an
effort value it cannot honour returns `status` non-success with
`error-class capability-unsupported` and invokes nothing — the error class
already exists in this contract's vocabulary so that task does not have to
invent one.

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
