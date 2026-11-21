# code-reviewer model pin: a model named by the binding reaches every `codex exec` as `-m`, and the review record states the model each pass actually ran on

**Status**: READY_FOR_ARCH
**Owner**: pm-spec
**Task ID**: T-1192

## Problem

The `code-reviewer` binding row has a model column, but no `codex exec` that `code-reviewer` or `drift-evaluator` runs passes it on. The shipped default writes `provider-configured` there, and a host `<base>/binding.conf` that names a model has no effect: Codex runs whatever its own configuration selects. Nothing in the loop pins that configuration, so it can change between two reviews without any record showing it.

The record side has the matching gap. The round-level `- Codex model:` field in the review record is filled from memory. T-1191's record says the CLI reports no model, but the imported rollouts of the same passes do carry one. Issue #755 decided the design and #756 asks for the implementation; this task does both.

## Summarized sources

- **Issue #755 body and the host's answers in this session (2026-11-21).** Relayed by the coordinating session; this role cannot read them. Restated as five fixed decisions:
  1. The default stays `provider-configured`, which composes no flag.
  2. A named model gives every `codex exec` the role runs `-m <model>` immediately after `codex exec`.
  3. Each pass's model is read from that pass's rollout and recorded per pass. A mismatch, or an unreadable or absent value when a model was requested, means the round is not established.
  4. Telemetry `--model` keeps the resolved value.
  5. `drift-evaluator` follows the same rule, using the `code-reviewer` binding's model.

  Restated by the Goal sentence, D1–D6, Non-goals, **AC1**–**AC10** and **AC16**.
- **`agents/code-reviewer.md` at `75866424`:**
  - `:12-19`: the binding gate is the first step of every mode.
  - `:42-69`: the primary pass. The bare skeleton line `:54` is `codex exec --sandbox read-only --cd <repo> review --base <base> --json -o "<RAW_OUT>"`, and `:67` is the publish line with `--thread-id "<THREAD_ID>"`.
  - `:75-99`: the evidence pass, whose pass id and stem are `adversarial`. Skeleton `:83-85`.
  - `:114`: the evidence pass's trigger.
  - `:126`: `- Codex model: <e.g. gpt-5-codex>`, the only `^- Codex model:` line.
  - `:168-183`: Finding-evaluation mode. `:174` launches a bare `codex exec …` line, awaits it, and runs no alloc or publish.
  - `:185-242`: Spec-review mode. Skeleton `:208-218`, publish `:231`.
  - `:249`: `BLOCKED — review not established` writes no verdict heading and logs `--status error`.
  - `:255`: the closed pass-name set and the `-rN` stem rule.
  - `:257`: the `self-detected-host (<pass>):` field.

  Restated by D1–D4, N1–N3, **AC4** and **AC6**.
- **`agents/drift-evaluator.md` at `75866424`:**
  - `:18`: the binding gate is keyed on the `code-reviewer` binding.
  - `:85-116`: the skeleton. Bare line `:92-102`, publish `:115`, stem `T-XXX-drift-codex`.
  - `:125`: `- Codex model: <e.g. gpt-5-codex>`.
  - `:151`: a tooling precondition failure is never one of the four verdicts.

  Restated by D5 and **AC5**.
- **`bin/check-review-provider.sh` at `75866424`:**
  - `:18-28`: a closed table. Stdout is exactly `admit codex-binding` or `admit codex-cli-host`.
  - `:81`: it reads the binding only through `resolve-executor.sh --print-resolved`.
  - `:92`: the `code-reviewer` row has six fields.

  The **T-1177** spec, D1 and **AC1** (`.shell-team/specs/T-1177-reviewer-binding-block.md:52-62,96`), freezes two properties: a sentinel planted as the model appears on no stream, and the admit stdout is exactly `admit codex-binding`. This is why D2 does not extend this checker. Restated by D2 and **AC3**.
- **`bin/resolve-executor.sh:624`**: prints `resolved <role> <provider> <model> <effort> <adapter> <probe-kind>`; field 4 is the model. **`bin/check-binding.sh:188`**: `MODEL_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'`. Restated by D1, D2 and Input space.
- **`bin/codex-capture.sh` at `75866424`:**
  - `:129-131`: usage.
  - `:154-183`: exit codes. `2` is usage, `3` is validation (this includes `rollout import failed` and `review did not run`), and `4` is publish.
  - `:416-449`: the rollout search under `${CODEX_HOME:-$HOME/.codex}/sessions` and the byte-for-byte import.
  - `:471-606`: the structural tokenizer and the completed-run gate, which reads `payload.type`, `payload.item.type`, `payload.item.exit_code` and `task_complete`.
  - `:624-627`: the success summary on stderr, `codex-capture: publish: rollout thread=… commands_executed=… commands_succeeded=… failure_markers=… last_agent_message=…`.

  No test under `tests/` exercises `--publish --thread-id` (measured, see Assumptions). Restated by D3, N1, **AC1**, **AC2** and **AC9**.
- **`bin/check-review-input.sh` at `75866424`:**
  - `:18-23`: it never reads a raw capture.
  - `:39-65`: the optional `self-detected-host` field. It is validated if present, has its own refusal tokens and is never echoed.
  - `:138-139`: refusals exit `1`, usage exits `2`.
  - `:269`: `FIELD_RE`.

  Restated by D4, **AC7** and **AC8**.
- **`templates/binding-default.conf:20-30,43`**: the comment says the measured invocation carries no model flag, and the row is `bind code-reviewer  codex provider-configured - codex-cli`. **`templates/binding-template.conf:26`**: the code-reviewer specimen is `model-2`, and `team-init` scaffolds it as `<base>/binding.conf.example`. Restated by D1, D6, **AC3**, **AC10** and Blast radius.
- **`templates/prompt-blocks/alternate-executor-invocation.md`:**
  - `:23`: the tech-lead `codex-cli` recipe line.
  - `:25`: the conditional effort clause, inserted by prose into an unchanged frozen line. This is the precedent D1 follows.
  - `:27`: "no model override ever appears on this line". It stays true.

  **`templates/prompt-blocks/host-dispatch.md:21`**: the Codex-CLI-host path composes no `--model` and runs `claude -p`, not `codex exec`. **`templates/prompt-blocks/executor-resolution.md:1`**: telemetry `--model` comes from the resolved row. Its `provider-configured` sentence stays accurate under the default. Restated by N1, Non-goals and **AC3**.
- **`skills/review-response/SKILL.md`:**
  - `:36-51`: Step 2 dispatches `code-reviewer` in finding-evaluation mode.
  - `:109-118`: the run record `$(team-paths.sh --get runs)/review-response-<ts>.md`. There is no task id and no review record.

  Restated by D3, D7 and **AC9**.
- **`tests/codex-skeleton-hygiene/run.sh`:**
  - `:837-855`: the `^[[:space:]]*codex exec ` count locks.
  - `:858-877`: the `--publish … --thread-id "<THREAD_ID>"` substring locks.
  - `:1466-1473`: the three byte-frozen block fixtures `fixtures/agentmd-block-{code-reviewer-adversarial,code-reviewer-specreview,drift-evaluator}.txt`.
  - `:251-252`: `fail` exits at the first failure, and `pass` prints `PASS: `.

  Restated by N3 and **AC6**.
- **`docs/adopting.md`:**
  - `## Binding roles to executors` (`:245-`).
  - `:261-268`: the placeholder `model-2` warning.
  - `:302`: the example row `bind code-reviewer  codex  gpt-5  -    codex-cli`.
  - `:305-311`: the claim that the shipped Codex invocation passes no model flag.

  `docs/adopting.ja.md` `## 役割と executor の紐付け` (`:244-`) is the counterpart. **`docs/workflow.md`** `## Codex CLI quick-reference` (`:155-171`) and **`docs/workflow.ja.md`** `## Codex CLI クイックリファレンス` (`:152-168`) are illustrative command lists. Restated by D6 and **AC10**.
- **Scaffold and drift readers of the specimen:**
  - `bin/team-init.sh:191,370`: copies `templates/binding-template.conf` to `<base>/binding.conf.example`.
  - `bin/team-setup.sh:554`: `tpl_drift "$BASE/binding.conf.example" "$TEMPLATES_DIR/binding-template.conf"`, which reports a scaffold that differs from the specimen.
  - `tests/team-init/run.sh:135,211`: a byte comparison with the template, and a required `T-NNN` comment citation.
  - `.github/workflows/check-handoff.yml:302`: `check-binding.sh --config templates/binding-template.conf`.

  The task-time read covered only the cited lines: the `tpl_drift` call, not the `tpl_drift` function body. So the claim that this note reports a drifted scaffold is labelled predicted in Assumptions. Restated by D8, the Non-goals scaffold line, **AC18**, **AC19** and Blast radius.
- **`bin/gen-codex-agents.sh:32-41,375-382`**: the generated `developer_instructions` body is byte-identical to the role file's body. `model =` is emitted only for a `codex-cli` adapter row whose model is not `provider-configured`. Restated by **AC11** and Blast radius.
- **`.shell-team/reviews/T-1191-codex-*.jsonl`**: four imported rollouts from codex-cli 0.160.0, per `.shell-team/reviews/T-1191.md:6`. Their record-type and `"model"` positions were measured by this role with value-free patterns; see Assumptions. They ground D3's extraction rule. **`.shell-team/reviews/T-1191.md:5,84`**: `- Codex model: not reported by the CLI in either capture`. Restated by the Problem and D3.
- **`CONTRIBUTING.md`:**
  - `## The board line format` (`:82-101`).
  - `## Cutting a release` (`:114-133`): the CHANGELOG is written at release prep.
  - `## What a version number encodes` (`:135-147`).

  Restated by the board entry, the Non-goals CHANGELOG line and `## Version`.

## Goal

<!-- BEGIN intent-block: T-1192 -->

- user-visible: yes — a host whose `<base>/binding.conf` names a model for `code-reviewer` now has every `codex exec` that `code-reviewer` and `drift-evaluator` run carry `-m <model>`. A pass whose rollout does not show that model stops the round `BLOCKED` instead of producing a verdict. Every review record, under the default too, states per pass the model the pass ran on, read from its rollout. A freshly scaffolded `binding.conf.example` now carries `provider-configured` for `code-reviewer` instead of the `model-2` placeholder, so copying it unedited keeps today's behaviour.
- shipped-docs: templates/binding-template.conf — this-task
- shipped-docs: docs/adopting.md — this-task
- shipped-docs: docs/adopting.ja.md — this-task
- shipped-docs: docs/workflow.md — this-task
- shipped-docs: docs/workflow.ja.md — this-task
- shipped-docs: templates/binding-default.conf — this-task
- verification-class: mechanism — the diff changes `bin/codex-capture.sh` and `bin/check-review-input.sh` with their fixture suites, and the `codex exec` instructions of two agent definitions.
- verification-ceiling: unit-and-static — **AC1**–**AC14** and **AC18**–**AC20** are settled in a plain checkout. They run the two changed scripts on synthesized rollouts and records under `$TMPDIR`, compare `codex-capture.sh` with the base commit's committed blob, read the agent and doc files and the base blobs, run the fixture suites that read the edited files, and read the exit codes of shellcheck, `check-prompt-sync.sh`, `gen-codex-agents.sh`/`check-codex-agents.sh`, `check-adopter-docs.sh` and `check-handoff.sh`. **AC15** (CI on the pull request), **AC16** (a live named-model review pass) and **AC17** (this task's own review record) sit above the ceiling.
- base-ref-discriminator: not-applicable — the branch `feature/755-codex-review-model-pin` is cut from `develop` at `75866424` with no open predecessor. Criteria that read a base-side blob resolve `B` as `git merge-base develop HEAD`. When only the remote-tracking ref exists (as in this checkout and a fresh clone), they use `git merge-base refs/remotes/origin/develop HEAD`. With neither, they exit `1`.

**Goal (one sentence).** When the effective binding's `code-reviewer` model is anything other than the exact string `provider-configured`, every `codex exec` that `code-reviewer` (all three modes) and `drift-evaluator` run carries `-m <model>` immediately after `codex exec`, and each pass's rollout must show exactly that model or the round is not established. Under `provider-configured` the launch argv stays as today, and the model the rollout shows is recorded for information only. The model each pass ran on is written per pass into the record from its rollout, never from memory. Telemetry, the Codex-CLI-host path and the alternate-executor recipe are unchanged.

**Decisions frozen here** (each is promoted to a criterion):

- **D1 — the flag.** "A model is named" means field 4 of the resolved `code-reviewer` row is not exactly `provider-configured`. When a model is named, every `codex exec` launch the role runs inserts `-m <MODEL>` immediately after `codex exec`, with `<MODEL>` substituted from that field. This covers primary, evidence (`adversarial`), spec-review, finding-evaluation and drift. The first token stays `codex`, nothing is added before or after the line, and it remains one bare command. Under `provider-configured` the line composes exactly as written. Following the effort-clause precedent, the frozen skeleton lines themselves stay byte-identical and the insertion is stated in prose. The effort column stays declared and unapplied for this wrapper-hosted role. (**AC4**, **AC5**, **AC6**)
- **D2 — where the requested model comes from.** In the same round, after the binding gate admits, the role reads the model itself from the primary source: field 4 of the `resolved code-reviewer` row printed by `bash "<plugin root>/bin/resolve-executor.sh" --print-resolved`. It does not use orchestrator relay, a prompt, or `check-review-provider.sh`, whose stdout, code and suite stay unchanged (T-1177 **AC1**). `drift-evaluator` reads the same row. (**AC3**, **AC4**, **AC5**)
- **D3 — observation and comparison in a deterministic script.** `bin/codex-capture.sh --publish … --thread-id <id>` gains `--expect-model <token>`.
  - **Extraction.** The observed model is every value of a key named `model`, at any nesting depth, read structurally with the existing tokenizer's discipline, inside a record whose top-level `type` is `session_meta` or `turn_context`. The top-level `type` filter is mandatory. The rule is deliberately not a fixed path, because the measured shapes differ:
    - codex-cli 0.160.0 writes `session_meta` `payload.provenance.model`;
    - codex-cli 0.171.0 `review` writes `payload.base_instructions.provenance.model`.

    The record-type set is closed at those two. `event_msg` (including `payload.thread_settings…model`), `world_state`, `response_item` and every other record type are never read; `session_meta` is present in both pass kinds. Text inside any string value is never read as a key. A `model` key whose value is an object or an array is ignored. A `model` key whose value is a non-string scalar (`null`, a number, `true`/`false`) counts as malformed.
  - **Established** means at least one string value exists and all of them are one identical token matching `MODEL_RE`.
  - **Comparison.** With `--expect-model <m>` and `<m>` ≠ `provider-configured`, the publish refuses unless the observed value is established and byte-equal to `<m>`. A refusal exits `3`, writes no canonical file, and removes both raws. Its stderr line contains `model not established` and exactly one cause from the closed set:
    - `cause=absent`: no value;
    - `cause=inconsistent`: more than one distinct value;
    - `cause=malformed`: a non-string scalar value, a string outside `MODEL_RE`, or a `\u` escape in the string — such a value is never echoed;
    - `cause=mismatch`: established but not equal.
  - **Report-only.** With `--expect-model provider-configured`, or with no `--expect-model`, the publish never refuses on the model. The canonical bytes and exit status stay as today, and the success summary line gains ` model=<observed>` at its end, where `<observed>` is the established value or `unavailable`.
  - **Usage errors (exit `2`).** `--expect-model` without `--thread-id`, with `--alloc`, with an empty value, or with a value outside `MODEL_RE`.
  - A read-only `--observe --thread-id <id> [--expect-model <token>]` mode applies the same extraction and causes, prints `model=<observed>` on stdout on success, resolves no reviews dir and writes nothing. It serves the finding-evaluation mode, which publishes no capture (**D7**). (**AC1**, **AC2**, **AC9**)
- **D4 — the record.** Each Codex pass of a fresh review or spec-review writes, beside its existing per-pass fields, one line `- codex-model (<pass>): requested=<token> — observed=<token>`. `requested` is the D2 value. `observed` is the publish summary's `model=` value, which is `unavailable` only under `provider-configured`.
  - The round-level `- Codex model:` line is kept and filled from that round's `codex-model` lines, never from memory or a configuration file.
  - `bin/check-review-input.sh` validates the field if present, as an optional sixth per-pass field. It never reads a raw capture and never echoes a field's bytes. It refuses with:
    - `codex-model-vocabulary`: a malformed line, a token outside `MODEL_RE` other than `unavailable` for `observed`, or a missing ` — ` separator;
    - `codex-model-duplicate`;
    - `codex-model-mismatch`: `requested` names a model and `observed` differs, including `unavailable`;
    - `codex-model-contradiction`: the same pass's `executor-invocation`, after leading whitespace and one optional backtick are stripped, begins with `codex exec`, and its third and fourth tokens are not `-m <requested>` when a model is named, or its third token is `-m` under `provider-configured`.

  The two grammar refusals (`codex-model-vocabulary`, `codex-model-duplicate`) are evaluated before `codex-model-mismatch` and `codex-model-contradiction`, so a malformed line never reports as a mismatch. (**AC4**, **AC7**, **AC8**)
- **D5 — failure handling, per mode.** A non-zero `--publish` or `--observe` caused by the model gate is handled per mode, never by a verdict from that pass:
  - default fresh review: `BLOCKED — review not established`, no `### Codex Review verdict:` heading, span `--status error`;
  - spec-review: not a round, so no `### Codex Spec-Review verdict:` heading;
  - finding evaluation: `BLOCKED`;
  - `drift-evaluator`: a tooling precondition failure, never one of its four verdicts, and no report.

  A pass with a named model therefore never reaches `APPROVE` → `READY_FOR_MERGE` unless its rollout shows that model. (**AC4**, **AC5**)
- **D6 — docs.** These say that a named `code-reviewer` model now reaches Codex as `-m <model>`, that the record carries `codex-model` lines, and that a missing or different rollout model stops the round (`model not established`):
  - `docs/adopting.md` and `docs/adopting.ja.md`, in the binding section. They also say three more things. The scaffolded specimen's `code-reviewer` row now carries `provider-configured`, so the placeholder paragraph no longer names `model-2`. The example row's model now takes effect. The model id to bind is the one the rollout reports.
  - The `templates/binding-default.conf` comment.
  - The two workflow quick-references, which gain the `-m <model>` form of the review line beside the unchanged default form.

  (**AC10**)
- **D7 — finding evaluation and `drift-evaluator` records.**
  - Finding-evaluation mode observes its pass through `--observe` by thread id. It returns `- codex-model (review-response): requested=… — observed=…` beside its per-finding output, and `review-response` writes that line into its run record.
  - `drift-evaluator` writes `- codex-model (drift): requested=… — observed=…` into its report. That report is not validated by `check-review-input.sh`.

  (**AC5**, **AC9**)
- **D8 — the scaffolded specimen (host ruling).** In `templates/binding-template.conf`, the `code-reviewer` row's model changes from `model-2` to `provider-configured`. Every other line keeps its base bytes, except comment lines, which may be reworded to match. A copied, unedited example therefore keeps today's behaviour; an adopter who wants a pin edits the row. (**AC19**)
- **D9 — this repository's own pin (host ruling).** This repository gains a tracked host binding `<base>/binding.conf`, with the base resolved through `bin/team-paths.sh --get base`, which is `.shell-team/binding.conf` here. It is well-formed per `bin/check-binding.sh`, resolves `code-reviewer` to model `gpt-6-luna`, and resolves every other row exactly as the shipped default does. The binding is then the single source of truth for this repository's reviewer model, and no `-m` is supplied outside it. (**AC20**, **AC17**)

**Pre-commitment (frozen before round 1).** The trigger and the drop order are AI self-discipline proposed by the coordinating session, never operator-ratified. The scope they protect is the host's: decisions 1–5 in Summarized sources are host rulings, and no drop that removes any part of them executes without a host ruling given at the time.

- **Never-dropped.** The first defeat of any one stops the task and returns it to planning.
  - (N1) Under `provider-configured`, every shipped `codex exec` skeleton line, the three block fixtures and the bare-line counts stay as at the base. `codex-capture.sh`'s `--alloc`, its `--publish` without `--thread-id`, and its `--publish --thread-id` success and refusal paths keep the base's exit status, stdout, stderr and canonical bytes, except for the appended ` model=` token. Telemetry, the Codex-CLI-host path and the alternate-executor recipe are unchanged. (**AC2**, **AC3**, **AC6**)
  - (N2) Part of this is enforced mechanically and part by the role. **Mechanically:** a `--publish` or `--observe` given `--expect-model <m>` with `<m>` a named model refuses, with no canonical write, unless the rollout shows exactly `<m>` (**AC1**, **AC9**). At close-out, `check-review-input.sh` refuses a record line whose `requested` names a model and whose `observed` differs, and a record whose `-m` disagrees with its `requested` (**AC7**, **AC8**). **By the role, and checked by QA's reading and by AC17 for this repository only:** the role reads `requested` from the binding (D2), passes it as `--expect-model`, writes it honestly into the record, and treats the refusal as no verdict (D5). No script cross-checks a record's `requested` against the binding in an adopter repository. (**AC4**, **AC5**, **AC17**)
  - (N3) Every `codex exec` launch line stays one bare command whose first token is `codex`, with nothing after its arguments. (**AC6**)
- **Trigger.** Two consecutive rounds, each with a recorded verdict, each raising a `Blocker` or `Major` of the same finding class against the same droppable component. A round interrupted before a verdict does not count.
- **Droppable, in order.** Each drop removes criterion text, so it is a class-B re-freeze. The dropped part goes to one follow-up issue that carries the rounds' findings as its requirement list.
  1. **D7's finding-evaluation observation** (**AC9**, plus `--observe` and the `codex-model (review-response)` tokens). It is first because review-response has no task id, review record or capture stem, so the observation needs a mode of its own. It covers decision 3, so executing this drop needs a host ruling at that time. `-m` in finding-evaluation mode (D1, decision 2) is never dropped.
  2. **The record contradiction refusal** (**AC8**). It is second because it is a record-level backstop of D1 that adds no protection N2 needs.
  3. **The record grammar and mismatch refusals** (**AC7**). It is third because N2 is carried by the publish gate in **AC1**; this is its close-out backstop.

## Non-goals

- **No change to the shipped default.** `templates/binding-default.conf`'s rows, `bin/resolve-executor.sh`, `bin/check-binding.sh`, `bin/check-invocation-path.sh` and `bin/check-review-provider.sh` (with its suite) keep their base bytes. (**AC3**)
- **No change to telemetry.** `--model` stays the resolved binding value under every binding. The observed model lives in the record only, so no prompt block and no orchestrator skill is edited. (**AC3**)
- **The Codex-CLI-host path is untouched.** That host runs `claude -p` (`templates/prompt-blocks/host-dispatch.md`), runs no `codex exec`, receives no `-m`, and records nothing new. A spawned `shell-team-code-reviewer` custom agent already carries `model =` from `gen-codex-agents.sh` when a model is named. (**AC3**)
- **The alternate-executor recipe is untouched**, including its "no model override ever appears on this line". The tech-lead `codex-cli` recipe is not the `code-reviewer` binding. (**AC3**)
- **The `--ephemeral` fallback example** (`docs/workflow.md:167`, `docs/workflow.ja.md:164`) is not given `-m`. It is a manual fallback for when `codex review` is unavailable, no role runs it, and no rollout is imported for it. (info-only)
- **No effort application** for `code-reviewer`. The effort column stays declared and unapplied for the wrapper-hosted role. (info-only)
- **Provider-side truth is not established.** Whether the rollout's model is what the provider executed or an echo of the request cannot be decided from the client. The rollout is the strongest observable, and this residual is disclosed rather than engineered around. (info-only; Input space out-of-scope 1)
- **Past records are not rewritten.** The requirement is forward-only. An existing record without `codex-model` lines stays conformant, and its old `- Codex model:` values stay as written. (**AC7**)
- **An adopter's already-scaffolded `<base>/binding.conf.example` is not rewritten.** It keeps `model-2` until the adopter re-scaffolds or edits it. `team-setup.sh` already reports it as drifted from the specimen. (info-only; Blast radius)
- **No CHANGELOG entry in this task.** It is written at release prep (`CONTRIBUTING.md`, `## Cutting a release`). The release note must call out that a non-`provider-configured` `code-reviewer` model in a host `binding.conf` now takes effect. (info-only)
- **No full-population two-arm sweep, no whole CI-equivalent re-run, and no local run of past specs' check lines.** This follows the operator rulings relayed in T-1191's spec. CI and this task's own check lines decide the impact. (info-only)

## Acceptance criteria

These rules apply to every `check:` line below:

- **Where it runs.** From the repository root under `bash`, reading the post-implementation tree. Lines write only under `$TMPDIR`, export a temp `HOME`, `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1`, and unset `TEAM_RUN_BASE`, `CODEX_HOME` and `CODEX_THREAD_ID`.
- **What lines never contain.** No line uses `ps` or `xargs`, and none writes or runs a recursive deletion.
- **Base reads.** Lines that read a base blob resolve `B` with the discriminator expression in the declaration region, spelled byte-identically in **AC1**–**AC6**, **AC13** and **AC19**. Those criteria are **merge-point-scoped and expected to go stale** once this task's changes reach `develop`; do not widen their base.
- **Fixture rollouts** are synthesized in the measured record shapes (see Assumptions) and are never copied from a real rollout, which carries identifiers.
- **Model names.** The placeholder models `zq-model-1` and `zq-model-2` name no real model.
- **Suite runs.** Suites run through `tms`: own process group, 1200 s, killed on timeout. Before a suite runs, it is scanned for a recursive-deletion pattern with backslash-continued lines joined.

- [ ] **AC1** (D3; N2.) The `--expect-model` gate of `codex-capture.sh --publish --thread-id`. Fixture rollouts live in a temp `CODEX_HOME`, with one temp reviews dir per case. Every rollout carries a completed `CommandExecution` and a `task_complete` record.
  - Positive control: the base commit's script publishes three rollouts with exit `0`, so the fixtures pass the existing completed-run gate:
    - the 0.160.0 `review` shape (`session_meta` `payload.provenance.model` only);
    - the prompt shape (`session_meta` + `world_state` decoy + `turn_context`);
    - the 0.171.0 `review` shape (`session_meta` `payload.base_instructions.provenance.model` + an `event_msg` carrying `thread_settings.model` + `collaboration_mode.settings.model`, no `turn_context`).
  - Exit `0` with the canonical `.jsonl` equal to the rollout and the stderr summary line ending in ` model=zq-model-1`. Each case runs with `--expect-model zq-model-1`:
    - the 0.160.0 `review` shape;
    - the prompt shape;
    - the 0.171.0 `review` shape;
    - an object-valued `model` in `session_meta` beside a `turn_context` carrying `zq-model-1`, where the object value is ignored;
    - `session_meta` carrying `zq-model-1` beside an `event_msg` whose `thread_settings` carry `zq-model-2`, where `event_msg` is not read.
  - Exit `3` with `model not established`, no canonical file and an empty reviews dir, with the cause:
    - `cause=mismatch`: `--expect-model zq-model-2`; a prefix near-miss either way (`zq-model-1x` observed, or `zq-model-1x` expected);
    - `cause=absent`: no model record; a `model` key only in `world_state`; a `model` key only in `event_msg` `thread_settings`; a `model` only as text inside a `CommandExecution` string;
    - `cause=inconsistent`: `session_meta` and `turn_context` disagree;
    - `cause=malformed`: a `null` model; a value with a space and `;` (that value never appears on stderr); a backslash-`u0031` escape in the value. The line builds that backslash at run time with `printf '\134'` and first asserts that the fixture really carries it.
  - Exit `0` with ` model=unavailable`: `--expect-model provider-configured` on a rollout with no model; no `--expect-model` on the disagreeing rollout.
  - Exit `0` with ` model=zq-model-1`: no `--expect-model` on the session_meta-only rollout.
  - Exit `2`: `--expect-model 'zq model'`; `--expect-model ''`; `--alloc … --expect-model`; `--publish --expect-model` without `--thread-id`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac1.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; M1=zq-model-1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; CE2='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"\"model\":\"zq-model-1\""}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; sm(){ printf '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":%s}}}\n' "$1"; }; tx(){ printf '{"timestamp":"2026-11-21T00:00:02Z","type":"turn_context","payload":{"turn_id":"t1","model":%s,"collaboration_mode":{"mode":"default","settings":{"model":%s}}}}\n' "$1" "$1"; }; ws(){ printf '{"timestamp":"2026-11-21T00:00:01Z","type":"world_state","payload":{"full":{"model":"%s","instructions":"quoted \\"model\\":\\"%s\\" text"}}}\n' "$1" "$1"; }; tl(){ printf '%s\n%s\n' "$CE" "$TC"; }; s7(){ printf '{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","base_instructions":{"text":"x","provenance":{"type":"model","model":%s}}}}\n' "$1"; }; ev(){ printf '{"timestamp":"2026-11-21T00:00:01Z","type":"event_msg","payload":{"type":"session_configured","thread_settings":{"model":%s,"collaboration_mode":{"mode":"default","settings":{"model":%s}}}}}\n' "$1" "$1"; }; bs=$(printf '\134'); test "${#bs}" = 1 || exit 1; { sm "\"$M1\""; tl; } > "$T/r1" || exit 1; { sm "\"$M1\""; ws zq-decoy; tx "\"$M1\""; tl; } > "$T/r2" || exit 1; tl > "$T/r4" || exit 1; { sm '"zq-model-2"'; tx "\"$M1\""; tl; } > "$T/r5" || exit 1; { sm null; tl; } > "$T/r6" || exit 1; { tx '"zq bad;x"'; tl; } > "$T/r7" || exit 1; { tx "\"zq-model-${bs}u0031\""; tl; } > "$T/r8" || exit 1; grep -qF "zq-model-${bs}u0031" "$T/r8" || exit 1; { s7 "\"$M1\""; ev "\"$M1\""; tl; } > "$T/r12" || exit 1; { ev "\"$M1\""; tl; } > "$T/r13" || exit 1; { sm '{"id":"zq-other"}'; tx "\"$M1\""; tl; } > "$T/r14" || exit 1; { sm "\"$M1\""; ev '"zq-model-2"'; tl; } > "$T/r15" || exit 1; { sm '"zq-model-1x"'; tl; } > "$T/r9" || exit 1; { ws "$M1"; tl; } > "$T/r10" || exit 1; printf '%s\n%s\n' "$CE2" "$TC" > "$T/r11" || exit 1; n=0; pc(){ local src="$1" o j; shift; n=$((n + 1)); I=$(printf '00000000-0000-4000-8000-%012d' "$n"); mkdir -p "$T/ch$n/sessions/2026/11/21" "$T/rv$n" || return 97; cp "$src" "$T/ch$n/sessions/2026/11/21/rollout-2026-11-21T00-00-00-$I.jsonl" || return 97; bash "$S" --alloc --stem T-000-codex-primary --reviews-dir "$T/rv$n" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; ( export CODEX_HOME="$T/ch$n"; exec bash "$S" --publish --stem T-000-codex-primary --reviews-dir "$T/rv$n" --publish-out "$o" --publish-jsonl "$j" --thread-id "$I" "$@" ) < /dev/null > "$T/po" 2> "$T/pe"; }; okc(){ test "$1" = 0 || return 1; grep -qE "^codex-capture: publish: rollout thread=$I .* model=$2\$" "$T/pe" || return 1; cmp -s "$3" "$T/rv$n/T-000-codex-primary.jsonl" || return 1; }; rfc(){ test "$1" = 3 || return 1; grep -qF 'model not established' "$T/pe" || return 1; grep -qF "cause=$2" "$T/pe" || return 1; test ! -e "$T/rv$n/T-000-codex-primary.txt" || return 1; test ! -e "$T/rv$n/T-000-codex-primary.jsonl" || return 1; test -z "$(ls -A "$T/rv$n")" || return 1; }; S="$T/base.sh"; pc "$T/r1"; test "$?" = 0 || exit 1; pc "$T/r2"; test "$?" = 0 || exit 1; pc "$T/r12"; test "$?" = 0 || exit 1; S="$X"; pc "$T/r1" --expect-model "$M1"; s=$?; okc "$s" "$M1" "$T/r1" || rc=1; pc "$T/r2" --expect-model "$M1"; s=$?; okc "$s" "$M1" "$T/r2" || rc=1; pc "$T/r12" --expect-model "$M1"; s=$?; okc "$s" "$M1" "$T/r12" || rc=1; pc "$T/r14" --expect-model "$M1"; s=$?; okc "$s" "$M1" "$T/r14" || rc=1; pc "$T/r15" --expect-model "$M1"; s=$?; okc "$s" "$M1" "$T/r15" || rc=1; pc "$T/r13" --expect-model "$M1"; s=$?; rfc "$s" absent || rc=1; pc "$T/r1" --expect-model zq-model-2; s=$?; rfc "$s" mismatch || rc=1; pc "$T/r9" --expect-model "$M1"; s=$?; rfc "$s" mismatch || rc=1; pc "$T/r1" --expect-model zq-model-1x; s=$?; rfc "$s" mismatch || rc=1; pc "$T/r4" --expect-model "$M1"; s=$?; rfc "$s" absent || rc=1; pc "$T/r10" --expect-model "$M1"; s=$?; rfc "$s" absent || rc=1; pc "$T/r11" --expect-model "$M1"; s=$?; rfc "$s" absent || rc=1; pc "$T/r5" --expect-model "$M1"; s=$?; rfc "$s" inconsistent || rc=1; pc "$T/r6" --expect-model "$M1"; s=$?; rfc "$s" malformed || rc=1; pc "$T/r7" --expect-model "$M1"; s=$?; rfc "$s" malformed || rc=1; grep -qF 'zq bad' "$T/pe"; test "$?" = 1 || rc=1; pc "$T/r8" --expect-model "$M1"; s=$?; rfc "$s" malformed || rc=1; pc "$T/r4" --expect-model provider-configured; s=$?; okc "$s" unavailable "$T/r4" || rc=1; pc "$T/r5"; s=$?; okc "$s" unavailable "$T/r5" || rc=1; pc "$T/r1"; s=$?; okc "$s" "$M1" "$T/r1" || rc=1; pc "$T/r1" --expect-model 'zq model'; test "$?" = 2 || rc=1; pc "$T/r1" --expect-model ''; test "$?" = 2 || rc=1; mkdir -p "$T/u1" "$T/u2" || exit 1; bash "$X" --alloc --stem T-000-codex-primary --reviews-dir "$T/u1" --expect-model "$M1" < /dev/null > /dev/null 2>&1; test "$?" = 2 || rc=1; bash "$X" --alloc --stem T-000-codex-primary --reviews-dir "$T/u2" > "$T/al" 2> /dev/null || exit 1; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); printf 'review text\n' > "$o" || exit 1; printf '{"type":"x"}\n' > "$j" || exit 1; bash "$X" --publish --stem T-000-codex-primary --reviews-dir "$T/u2" --publish-out "$o" --publish-jsonl "$j" --expect-model "$M1" < /dev/null > /dev/null 2>&1; test "$?" = 2 || rc=1; test "$rc" -eq 0

- [ ] **AC2** (D3; N1.) `codex-capture.sh` keeps the base's behaviour outside the gate. The base commit's script and HEAD's script run on identical inputs in an identical directory path; the directory is renamed with `mv` between runs, and nothing is deleted.
  - Pairs with equal exit status, stdout and stderr bytes:
    - `--publish` without `--thread-id` on a valid capture: exit `0`, with byte-equal published `.txt` and `.jsonl`;
    - the same on a non-JSON `.jsonl`: exit `3`;
    - `--thread-id` with no rollout present: exit `3`;
    - `--thread-id` with a rollout lacking `task_complete`: exit `3`.
  - On a complete rollout without `--expect-model`, both scripts exit `0` with equal stdout and published bytes, and HEAD's stderr equals the base's non-empty stderr followed by:
    - ` model=zq-model-1` when the rollout carries that model;
    - ` model=unavailable` when it carries none.
  - Positive control: HEAD's script differs from the base blob.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac2.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; git show "$B:bin/codex-capture.sh" > "$T/base.sh" || exit 1; test -s "$T/base.sh" || exit 1; cmp -s "$T/base.sh" "$X"; test "$?" = 1 || rc=1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; D="$T/ch/sessions/2026/11/21"; mkdir -p "$D" || exit 1; i1=00000000-0000-4000-8000-000000000101; i2=00000000-0000-4000-8000-000000000102; i3=00000000-0000-4000-8000-000000000103; i4=00000000-0000-4000-8000-000000000104; printf '%s\n%s\n%s\n' "$SM" "$CE" "$TC" > "$D/rollout-2026-11-21T00-00-00-$i1.jsonl" || exit 1; printf '%s\n%s\n' "$CE" "$TC" > "$D/rollout-2026-11-21T00-00-00-$i2.jsonl" || exit 1; printf '%s\n' "$CE" > "$D/rollout-2026-11-21T00-00-00-$i3.jsonl" || exit 1; pb(){ local s="$1" t="$2" id="$3" o j r; mkdir -p "$T/w" || return 97; bash "$s" --alloc --stem T-000-codex-primary --reviews-dir "$T/w" > "$T/al" 2> /dev/null || return 97; o=$(sed -n 1p "$T/al"); j=$(sed -n 2p "$T/al"); test -n "$o" && test -n "$j" || return 97; printf 'review text\n' > "$o" || return 97; if [ "$id" = - ]; then printf '%s\n' "$4" > "$j" || return 97; ( export CODEX_HOME="$T/ch"; exec bash "$s" --publish --stem T-000-codex-primary --reviews-dir "$T/w" --publish-out "$o" --publish-jsonl "$j" ) < /dev/null > "$T/o-$t" 2> "$T/e-$t"; r=$?; else ( export CODEX_HOME="$T/ch"; exec bash "$s" --publish --stem T-000-codex-primary --reviews-dir "$T/w" --publish-out "$o" --publish-jsonl "$j" --thread-id "$id" ) < /dev/null > "$T/o-$t" 2> "$T/e-$t"; r=$?; fi; printf '%s\n' "$r" > "$T/rc-$t" || return 97; mv "$T/w" "$T/w-$t" || return 97; return 0; }; eq(){ test "$(cat "$T/rc-$1")" = "$(cat "$T/rc-$2")" && cmp -s "$T/o-$1" "$T/o-$2" && cmp -s "$T/e-$1" "$T/e-$2"; }; pub(){ cmp -s "$T/w-$1/T-000-codex-primary.txt" "$T/w-$2/T-000-codex-primary.txt" && cmp -s "$T/w-$1/T-000-codex-primary.jsonl" "$T/w-$2/T-000-codex-primary.jsonl"; }; pb "$T/base.sh" a0 - '{"type":"x"}' || exit 1; pb "$X" a1 - '{"type":"x"}' || rc=1; eq a0 a1 || rc=1; pub a0 a1 || rc=1; test "$(cat "$T/rc-a0")" = 0 || exit 1; pb "$T/base.sh" b0 - 'not json' || exit 1; pb "$X" b1 - 'not json' || rc=1; eq b0 b1 || rc=1; test "$(cat "$T/rc-b0")" = 3 || exit 1; pb "$T/base.sh" c0 "$i4" || exit 1; pb "$X" c1 "$i4" || rc=1; eq c0 c1 || rc=1; test "$(cat "$T/rc-c0")" = 3 || exit 1; pb "$T/base.sh" d0 "$i3" || exit 1; pb "$X" d1 "$i3" || rc=1; eq d0 d1 || rc=1; test "$(cat "$T/rc-d0")" = 3 || exit 1; pb "$T/base.sh" e0 "$i1" || exit 1; pb "$X" e1 "$i1" || rc=1; test "$(cat "$T/rc-e0")" = 0 || exit 1; test "$(cat "$T/rc-e1")" = 0 || rc=1; cmp -s "$T/o-e0" "$T/o-e1" || rc=1; pub e0 e1 || rc=1; test -s "$T/e-e0" || exit 1; test "$(cat "$T/e-e1")" = "$(cat "$T/e-e0") model=zq-model-1" || rc=1; pb "$T/base.sh" f0 "$i2" || exit 1; pb "$X" f1 "$i2" || rc=1; test "$(cat "$T/rc-f0")" = 0 || exit 1; test "$(cat "$T/rc-f1")" = 0 || rc=1; pub f0 f1 || rc=1; test "$(cat "$T/e-f1")" = "$(cat "$T/e-f0") model=unavailable" || rc=1; test "$rc" -eq 0

- [ ] **AC3** (D2; N1; Non-goals.) Unchanged surfaces.
  - The committed diff `<base>...HEAD` is empty over: `bin/check-review-provider.sh`, `bin/resolve-executor.sh`, `bin/check-binding.sh`, `bin/check-invocation-path.sh`, `tests/check-review-provider`, `templates/prompt-blocks`, `skills/run/SKILL.md`, `skills/goal/SKILL.md` and `skills/review/SKILL.md`.
  - The non-comment lines of `templates/binding-default.conf` and `templates/adapters/codex-cli.txt` equal the base blob's, and the default file still carries the line `bind code-reviewer  codex provider-configured - codex-cli`.
  - `bin/resolve-executor.sh --print-resolved`, run in a temp tree whose base dir `.ops` (`TEAM_RUN_BASE=.ops`) holds no `binding.conf`, prints the line `resolved code-reviewer codex provider-configured - codex-cli`. That is the shipped default, independent of any host binding in this checkout.
  - `tests/check-review-provider/run.sh` exits `0` with no `FAIL` line, which keeps T-1177's sentinel and exact-admit assertions.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac3.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; for f in bin/check-review-provider.sh bin/resolve-executor.sh templates/prompt-blocks/alternate-executor-invocation.md templates/prompt-blocks/host-dispatch.md templates/binding-template.conf tests/check-review-provider/run.sh; do test -s "$f" || exit 1; done; git diff --no-renames --quiet "$B"...HEAD -- bin/check-review-provider.sh bin/resolve-executor.sh bin/check-binding.sh bin/check-invocation-path.sh tests/check-review-provider templates/prompt-blocks skills/run/SKILL.md skills/goal/SKILL.md skills/review/SKILL.md; test "$?" = 0 || rc=1; for f in templates/binding-default.conf templates/adapters/codex-cli.txt; do git show "$B:$f" > "$T/b" || exit 1; grep -v '^#' "$T/b" > "$T/b1"; test -s "$T/b1" || exit 1; grep -v '^#' "$f" > "$T/h1"; cmp -s "$T/b1" "$T/h1" || rc=1; done; grep -qxF 'bind code-reviewer  codex provider-configured - codex-cli' templates/binding-default.conf || rc=1; R=$(pwd -P) || exit 1; mkdir -p "$T/def/.ops" || exit 1; ( cd "$T/def" && exec env TEAM_RUN_BASE=.ops bash "$R/bin/resolve-executor.sh" --print-resolved ) < /dev/null > "$T/pr" 2> /dev/null || rc=1; grep -qxF 'resolved code-reviewer codex provider-configured - codex-cli' "$T/pr" || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; S=tests/check-review-provider/run.sh; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC4** (D1, D2, D4, D5; N2.) `agents/code-reviewer.md` states the mechanism in every mode. Three regions are read:
  - the fresh review, from the line beginning `## Your loop` to the line beginning `## Output`;
  - Finding-evaluation, from `## Finding-evaluation mode` to `## Spec-review mode`;
  - Spec-review, from `## Spec-review mode` to `## Rules`.

  Required:
  - Each region is non-empty and contains `-m <MODEL>`.
  - The fresh-review region also contains `--print-resolved`, `provider-configured` and `--expect-model`. The Spec-review region contains `--expect-model`.
  - The file contains `codex-model (<pass>): requested=` and `model not established`.
  - The file has exactly one line beginning `- Codex model:`. That line contains `codex-model` and no longer contains `<e.g.`.
  - Lines 2 (`name:`) and 4 (`tools:`) equal the base blob's.

  The handling D5 fixes for each mode (no verdict heading, not a round, `BLOCKED`) is a QA reading item against those regions.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac4.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; F=agents/code-reviewer.md; test -s "$F" || exit 1; sec(){ awk -v a="$1" -v b="$2" 'index($0, a) == 1 { f = 1 } f && index($0, b) == 1 { f = 0 } f' "$F"; }; sec '## Your loop' '## Output' > "$T/s1"; sec '## Finding-evaluation mode' '## Spec-review mode' > "$T/s2"; sec '## Spec-review mode' '## Rules' > "$T/s3"; for s in s1 s2 s3; do test -s "$T/$s" || rc=1; grep -qF -- '-m <MODEL>' "$T/$s" || rc=1; done; for q in '--print-resolved' 'provider-configured' '--expect-model'; do grep -qF -- "$q" "$T/s1" || rc=1; done; grep -qF -- '--expect-model' "$T/s3" || rc=1; for q in 'codex-model (<pass>): requested=' 'model not established'; do grep -qF -- "$q" "$F" || rc=1; done; grep -E '^- Codex model:' "$F" > "$T/cm"; test "$(grep -c '' "$T/cm")" = 1 || rc=1; grep -qF 'codex-model' "$T/cm" || rc=1; grep -qF '<e.g.' "$T/cm"; test "$?" = 1 || rc=1; git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; test "$(sed -n '2p;4p' "$T/b")" = "$(sed -n '2p;4p' "$F")" || rc=1; test "$rc" -eq 0

- [ ] **AC5** (D1, D2, D5, D7; N2.) `agents/drift-evaluator.md` requires:
  - the tokens `-m <MODEL>`, `--print-resolved`, `--expect-model`, `codex-model (drift): requested=` and `model not established`;
  - exactly one line beginning `- Codex model:`, which contains `codex-model` and not `<e.g.`;
  - lines 2 and 4 equal to the base blob's.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac5.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; F=agents/drift-evaluator.md; test -s "$F" || exit 1; for q in '-m <MODEL>' '--print-resolved' '--expect-model' 'codex-model (drift): requested=' 'model not established'; do grep -qF -- "$q" "$F" || rc=1; done; grep -E '^- Codex model:' "$F" > "$T/cm"; test "$(grep -c '' "$T/cm")" = 1 || rc=1; grep -qF 'codex-model' "$T/cm" || rc=1; grep -qF '<e.g.' "$T/cm"; test "$?" = 1 || rc=1; git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; test "$(sed -n '2p;4p' "$T/b")" = "$(sed -n '2p;4p' "$F")" || rc=1; test "$rc" -eq 0

- [ ] **AC6** (D1; N1, N3.) The launch-line shape. For each of `agents/code-reviewer.md` and `agents/drift-evaluator.md`:
  - The number of lines matching `^[[:space:]]*codex exec ` equals the base blob's count, which is at least one. This is read from the base blob, so it does not go stale with population growth.
  - No such line carries a `-m` or `--model` token.

  The three block fixtures `tests/codex-skeleton-hygiene/fixtures/agentmd-block-{code-reviewer-adversarial,code-reviewer-specreview,drift-evaluator}.txt` exist and have an empty committed diff `<base>...HEAD`. `tests/codex-skeleton-hygiene/run.sh` exits `0` with no `FAIL` line and at least one line beginning `PASS: T-1192 `.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac6.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; for f in agents/code-reviewer.md agents/drift-evaluator.md; do test -s "$f" || exit 1; git show "$B:$f" > "$T/b" || exit 1; b=$(grep -cE '^[[:space:]]*codex exec ' "$T/b"); h=$(grep -cE '^[[:space:]]*codex exec ' "$f"); test "$b" -ge 1 || exit 1; test "$b" = "$h" || rc=1; grep -E '^[[:space:]]*codex exec ' "$f" | grep -qE '(^|[[:space:]])(-m|--model)([[:space:]]|=|$)'; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" = 0 || rc=1; test "${ps2[1]}" = 1 || rc=1; done; FX=tests/codex-skeleton-hygiene/fixtures; for x in code-reviewer-adversarial code-reviewer-specreview drift-evaluator; do test -s "$FX/agentmd-block-$x.txt" || exit 1; done; git diff --no-renames --quiet "$B"...HEAD -- "$FX/agentmd-block-code-reviewer-adversarial.txt" "$FX/agentmd-block-code-reviewer-specreview.txt" "$FX/agentmd-block-drift-evaluator.txt"; test "$?" = 0 || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; S=tests/codex-skeleton-hygiene/run.sh; test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" | grep -qE "$rd"; ps3=("${PIPESTATUS[@]}"); test "${ps3[0]}" -eq 0 || exit 1; test "${ps3[1]}" -eq 1 || exit 1; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; grep -q '^PASS: T-1192 ' "$T/log" || rc=1; test "$rc" -eq 0

- [ ] **AC7** (D4; N2 backstop.) `bin/check-review-input.sh` validates `codex-model` lines if present. Records are built from a verdict heading, the four fields of pass `p1`, and the lines under test. Each case is run as `--record <file> --task T-000`.
  - **Exit `0`:**
    - no `codex-model` line (forward-only control);
    - `requested=provider-configured — observed=zq-model-1`;
    - `requested=provider-configured — observed=unavailable`;
    - `requested=zq-model-1 — observed=zq-model-1` beside an invocation carrying `-m zq-model-1`.
  - **Exit `1` with `codex-model-mismatch`,** where stderr never carries the observed value:
    - observed `zq-model-2`;
    - observed `unavailable`;
    - observed `zq-model-1x`.
  - **Exit `1` with `codex-model-vocabulary`:**
    - no ` — ` separator;
    - a requested token with a space;
    - an empty observed value.
  - **Exit `1` with `codex-model-duplicate`:** two lines for `p1`.
  - `tests/check-review-input/run.sh` exits `0` with no `FAIL` line and at least one `PASS:` line containing `codex-model`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac7.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID TEAM_REVIEWS_DIR; mkdir -p "$HOME" || exit 1; X=bin/check-review-input.sh; test -s "$X" || exit 1; hdr(){ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; }; f2='  - pass-role (p1): generation'; f3='  - briefing-fidelity (p1): carried - scope stated in the argv'; f4='  - raw-capture (p1): T-000-codex-primary'; E0='  - executor-invocation (p1): codex exec --sandbox read-only review --base develop'; E1='  - executor-invocation (p1): codex exec -m zq-model-1 --sandbox read-only review --base develop'; CM(){ printf '  - codex-model (p1): requested=%s — observed=%s' "$1" "$2"; }; mk(){ local e="$1" l; shift; { hdr; printf '%s\n%s\n%s\n%s\n' "$e" "$f2" "$f3" "$f4"; for l in "$@"; do printf '%s\n' "$l"; done; } > "$T/r.md"; }; ck(){ bash "$X" --record "$T/r.md" --task T-000 < /dev/null > "$T/o" 2> "$T/e"; r=$?; test "$r" = "$1" || return 1; if [ -n "$2" ]; then grep -qF -- "$2" "$T/e" || return 1; fi; return 0; }; mk "$E0"; ck 0 '' || rc=1; mk "$E0" "$(CM provider-configured zq-model-1)"; ck 0 '' || rc=1; mk "$E0" "$(CM provider-configured unavailable)"; ck 0 '' || rc=1; mk "$E1" "$(CM zq-model-1 zq-model-1)"; ck 0 '' || rc=1; mk "$E1" "$(CM zq-model-1 zq-model-2)"; ck 1 codex-model-mismatch || rc=1; grep -qF zq-model-2 "$T/e"; test "$?" = 1 || rc=1; mk "$E1" "$(CM zq-model-1 unavailable)"; ck 1 codex-model-mismatch || rc=1; mk "$E1" "$(CM zq-model-1 zq-model-1x)"; ck 1 codex-model-mismatch || rc=1; mk "$E1" '  - codex-model (p1): requested=zq-model-1 observed=zq-model-1'; ck 1 codex-model-vocabulary || rc=1; mk "$E1" "$(CM 'zq model' zq-model-1)"; ck 1 codex-model-vocabulary || rc=1; mk "$E1" "$(CM zq-model-1 '')"; ck 1 codex-model-vocabulary || rc=1; mk "$E1" "$(CM zq-model-1 zq-model-1)" "$(CM zq-model-1 zq-model-1)"; ck 1 codex-model-duplicate || rc=1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; S=tests/check-review-input/run.sh; test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; tms "$S" "$T/log"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log"; test "$?" = 1 || rc=1; grep '^PASS:' "$T/log" | grep -qF 'codex-model' || rc=1; test "$rc" -eq 0

- [ ] **AC8** (D4, D1; droppable 2.) The `codex-model-contradiction` refusal. Records are built as in **AC7**.
  - **Exit `1` with `codex-model-contradiction`:**
    - a named model beside an invocation without `-m`;
    - `provider-configured` beside an invocation carrying `-m zq-model-1`;
    - a backtick-wrapped invocation carrying `-m zq-model-2` beside `requested=zq-model-1 — observed=zq-model-1`.
  - **Exit `0`:** a `claude -p` invocation beside a named model, because the refusal applies only to a `codex exec` invocation.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac8.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID TEAM_REVIEWS_DIR; mkdir -p "$HOME" || exit 1; X=bin/check-review-input.sh; test -s "$X" || exit 1; hdr(){ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; }; f2='  - pass-role (p1): generation'; f3='  - briefing-fidelity (p1): carried - scope stated in the argv'; f4='  - raw-capture (p1): T-000-codex-primary'; E0='  - executor-invocation (p1): codex exec --sandbox read-only review --base develop'; E1='  - executor-invocation (p1): codex exec -m zq-model-1 --sandbox read-only review --base develop'; E2='  - executor-invocation (p1): `codex exec -m zq-model-2 --sandbox read-only review --base develop`'; E3='  - executor-invocation (p1): claude -p --prompt-file p.txt'; CM(){ printf '  - codex-model (p1): requested=%s — observed=%s' "$1" "$2"; }; mk(){ local e="$1" l; shift; { hdr; printf '%s\n%s\n%s\n%s\n' "$e" "$f2" "$f3" "$f4"; for l in "$@"; do printf '%s\n' "$l"; done; } > "$T/r.md"; }; ck(){ bash "$X" --record "$T/r.md" --task T-000 < /dev/null > "$T/o" 2> "$T/e"; r=$?; test "$r" = "$1" || return 1; if [ -n "$2" ]; then grep -qF -- "$2" "$T/e" || return 1; fi; return 0; }; mk "$E1" "$(CM zq-model-1 zq-model-1)"; ck 0 '' || exit 1; mk "$E0" "$(CM zq-model-1 zq-model-1)"; ck 1 codex-model-contradiction || rc=1; mk "$E1" "$(CM provider-configured zq-model-1)"; ck 1 codex-model-contradiction || rc=1; mk "$E2" "$(CM zq-model-1 zq-model-1)"; ck 1 codex-model-contradiction || rc=1; mk "$E3" "$(CM zq-model-1 zq-model-1)"; ck 0 '' || rc=1; test "$rc" -eq 0

- [ ] **AC9** (D3, D7; droppable 1, host ruling required.) The finding-evaluation observation. `bin/codex-capture.sh --observe --thread-id <id>` is run in an empty, non-repository working directory with a temp `CODEX_HOME`.
  - On a rollout carrying `zq-model-1`, with `--expect-model zq-model-1`: exit `0`, stdout exactly `model=zq-model-1`.
  - With `--expect-model zq-model-2`: exit `3`, with `model not established` and `cause=mismatch` on stderr.
  - On a rollout with no model and no `--expect-model`: exit `0`, stdout exactly `model=unavailable`.
  - On a rollout in the 0.171.0 `review` shape (`session_meta` `payload.base_instructions.provenance.model` = `zq-model-1`), with `--expect-model zq-model-1`: exit `0`, stdout exactly `model=zq-model-1`.
  - Exit `2` for `--observe` without `--thread-id`, and for `--observe` combined with `--alloc`.
  - The `CODEX_HOME` tree and the working directory are byte-identical before and after every run.
  - The `## Finding-evaluation mode` region of `agents/code-reviewer.md` contains `--observe` and `codex-model (review-response)`, and the `## Run record` section of `skills/review-response/SKILL.md` contains `codex-model (review-response)`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; R=$(pwd -P) || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac9.XXXXXX") || exit 1; T=$(cd "$T" && pwd -P) || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" "$T/cwd" "$T/out" || exit 1; X="$R/bin/codex-capture.sh"; test -s "$X" || exit 1; CE='{"timestamp":"2026-11-21T00:00:03Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","exit_code":0,"aggregated_output":"ok"}}}'; TC='{"timestamp":"2026-11-21T00:00:09Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":null}}'; SM='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","provenance":{"type":"model","model":"zq-model-1"}}}'; D="$T/ch/sessions/2026/11/21"; mkdir -p "$D" || exit 1; i1=00000000-0000-4000-8000-000000000201; i2=00000000-0000-4000-8000-000000000202; printf '%s\n%s\n%s\n' "$SM" "$CE" "$TC" > "$D/rollout-2026-11-21T00-00-00-$i1.jsonl" || exit 1; printf '%s\n%s\n' "$CE" "$TC" > "$D/rollout-2026-11-21T00-00-00-$i2.jsonl" || exit 1; i3=00000000-0000-4000-8000-000000000203; S7='{"timestamp":"2026-11-21T00:00:00Z","type":"session_meta","payload":{"model_provider":"openai","base_instructions":{"text":"x","provenance":{"type":"model","model":"zq-model-1"}}}}'; printf '%s\n%s\n%s\n' "$S7" "$CE" "$TC" > "$D/rollout-2026-11-21T00-00-00-$i3.jsonl" || exit 1; snap(){ (cd "$T" && find ch cwd -print | sort && find ch -type f -exec cksum {} +); }; snap > "$T/out/s0" || exit 1; ob(){ ( cd "$T/cwd" && export CODEX_HOME="$T/ch" && exec bash "$X" "$@" ) < /dev/null > "$T/out/o" 2> "$T/out/e"; }; ob --observe --thread-id "$i1" --expect-model zq-model-1; test "$?" = 0 || rc=1; test "$(cat "$T/out/o")" = 'model=zq-model-1' || rc=1; ob --observe --thread-id "$i1" --expect-model zq-model-2; test "$?" = 3 || rc=1; grep -qF 'model not established' "$T/out/e" || rc=1; grep -qF 'cause=mismatch' "$T/out/e" || rc=1; ob --observe --thread-id "$i2"; test "$?" = 0 || rc=1; test "$(cat "$T/out/o")" = 'model=unavailable' || rc=1; ob --observe --thread-id "$i3" --expect-model zq-model-1; test "$?" = 0 || rc=1; test "$(cat "$T/out/o")" = 'model=zq-model-1' || rc=1; ob --observe; test "$?" = 2 || rc=1; ob --observe --alloc --stem T-000-codex-primary --thread-id "$i1"; test "$?" = 2 || rc=1; snap > "$T/out/s1" || exit 1; cmp -s "$T/out/s0" "$T/out/s1" || rc=1; test -z "$(ls -A "$T/cwd")" || rc=1; F="$R/agents/code-reviewer.md"; test -s "$F" || exit 1; awk 'index($0, "## Finding-evaluation mode") == 1 { f = 1 } f && index($0, "## Spec-review mode") == 1 { f = 0 } f' "$F" > "$T/out/s2"; for q in '--observe' 'codex-model (review-response)'; do grep -qF -- "$q" "$T/out/s2" || rc=1; done; K="$R/skills/review-response/SKILL.md"; test -s "$K" || exit 1; awk '$0 == "## Run record (for retro / lessons)" { f = 1; next } f && /^## / { f = 0 } f' "$K" > "$T/out/rr"; test -s "$T/out/rr" || rc=1; grep -qF 'codex-model (review-response)' "$T/out/rr" || rc=1; test "$rc" -eq 0

- [ ] **AC10** (D6.) Adopter docs.
  - In `docs/adopting.md`, the `## Binding roles to executors` section (to the next `## ` heading) contains `-m <model>`, `codex-model (`, `model not established` and `provider-configured`.
  - In `docs/adopting.ja.md`, the `## 役割と executor の紐付け` section contains the same four tokens.
  - Neither of those two sections contains the standalone token `model-2` any longer (D8). The test uses **AC19**'s boundary pattern, so `zq-model-2` would not count. At the base both do (measured: `docs/adopting.md:262`, `docs/adopting.ja.md:263`).
  - In `docs/workflow.md`, the `## Codex CLI quick-reference` section, and in `docs/workflow.ja.md`, the `## Codex CLI クイックリファレンス` section, each carries both lines:
    - `codex exec -m <model> --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>`;
    - the unchanged `codex exec --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>`.
  - A comment line of `templates/binding-default.conf` contains `-m <model>`.
  - At the base, `-m <model>`, `codex-model` and `model not established` occur in none of these files (measured; see Assumptions).
  - adopter-surface: docs/adopting.md and docs/adopting.ja.md (`## Binding roles to executors` / `## 役割と executor の紐付け`), docs/workflow.md and docs/workflow.ja.md (the Codex CLI quick-reference) and the `templates/binding-default.conf` comment. They cover: a named `code-reviewer` model reaches every Codex pass as `-m <model>`; `provider-configured` keeps today's behaviour; the record's `codex-model` lines; `model not established` stops the round; the scaffolded specimen's `code-reviewer` row is `provider-configured`; the example row's model now takes effect; bind the model id the rollout reports.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac10.XXXXXX") || exit 1; for f in docs/adopting.md docs/adopting.ja.md docs/workflow.md docs/workflow.ja.md templates/binding-default.conf; do test -s "$f" || exit 1; done; sec(){ awk -v h="$1" '$0 == h { f = 1; next } f && /^## / { f = 0 } f' "$2"; }; sec '## Binding roles to executors' docs/adopting.md > "$T/e1"; sec '## 役割と executor の紐付け' docs/adopting.ja.md > "$T/j1"; for s in e1 j1; do test -s "$T/$s" || rc=1; for q in '-m <model>' 'codex-model (' 'model not established' 'provider-configured'; do grep -qF -- "$q" "$T/$s" || rc=1; done; grep -qE -- '(^|[^A-Za-z0-9_-])model-2([^A-Za-z0-9._-]|$)' "$T/$s"; test "$?" = 1 || rc=1; done; sec '## Codex CLI quick-reference' docs/workflow.md > "$T/e2"; sec '## Codex CLI クイックリファレンス' docs/workflow.ja.md > "$T/j2"; for s in e2 j2; do test -s "$T/$s" || rc=1; grep -qxF 'codex exec -m <model> --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>' "$T/$s" || rc=1; grep -qxF 'codex exec --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>' "$T/$s" || rc=1; done; grep '^#' templates/binding-default.conf | grep -qF -- '-m <model>' || rc=1; test "$rc" -eq 0

- [ ] **AC11** (D1; N1; Blast radius.) Prompt sync and the generated Codex custom agents.
  - `bash bin/check-prompt-sync.sh` exits `0` and prints `check-prompt-sync: all registered prompt blocks in sync`.
  - `bin/gen-codex-agents.sh --root <checkout> --out-dir <tmp>` and `bin/check-codex-agents.sh --root <checkout> --out-dir <tmp>` both exit `0`. Both run from a temp tree whose base dir `.ops` (`TEAM_RUN_BASE=.ops`) holds no `binding.conf`, so the shipped default binding governs whatever this checkout holds.
  - The generated `shell-team-code-reviewer.toml` contains `-m <MODEL>`, showing the body tracks the edited role file. Under the default binding it carries no line beginning `model = `.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac11.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; for f in bin/check-prompt-sync.sh bin/gen-codex-agents.sh bin/check-codex-agents.sh; do test -s "$f" || exit 1; done; bash bin/check-prompt-sync.sh < /dev/null > "$T/o" 2> "$T/e"; test "$?" = 0 || rc=1; grep -qxF 'check-prompt-sync: all registered prompt blocks in sync' "$T/o" || rc=1; R=$(pwd -P) || exit 1; mkdir -p "$T/def/.ops" || exit 1; ( cd "$T/def" && exec env TEAM_RUN_BASE=.ops bash "$R/bin/gen-codex-agents.sh" --root "$R" --out-dir "$T/out" ) < /dev/null > "$T/g" 2>&1 || rc=1; ( cd "$T/def" && exec env TEAM_RUN_BASE=.ops bash "$R/bin/check-codex-agents.sh" --root "$R" --out-dir "$T/out" ) < /dev/null > "$T/c" 2>&1 || rc=1; G="$T/out/shell-team-code-reviewer.toml"; test -s "$G" || rc=1; grep -qF -- '-m <MODEL>' "$G" || rc=1; grep -q '^model = ' "$G"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC12** shellcheck exits `0` on `bin/codex-capture.sh`, `bin/check-review-input.sh`, `tests/codex-skeleton-hygiene/run.sh` and `tests/check-review-input/run.sh`. None of the four matches the recursive-deletion pattern once backslash-continued lines are joined.
  - check: rc=0; export LC_ALL=C; L=(bin/codex-capture.sh bin/check-review-input.sh tests/codex-skeleton-hygiene/run.sh tests/check-review-input/run.sh); for f in "${L[@]}"; do test -s "$f" || exit 1; done; command -v shellcheck > /dev/null 2>&1 || exit 1; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac12.XXXXXX") || exit 1; shellcheck bin/codex-capture.sh bin/check-review-input.sh tests/codex-skeleton-hygiene/run.sh tests/check-review-input/run.sh > "$T/sc" 2>&1 || rc=1; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e'; for f in "${L[@]}"; do awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$f" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || rc=1; test "${ps2[1]}" -eq 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC13** Scope lock. This criterion is **merge-point-scoped and expected to go stale** after merge; do not widen its base.
  - **Measured set.** The union of four reads, each of which must succeed: the committed range `git diff --no-renames --name-only <base>...HEAD`, the staged delta `git diff --no-renames --cached --name-only`, the unstaged delta `git diff --no-renames --name-only`, and the untracked strays `git ls-files --others --exclude-standard`.
  - **Positive control.** The set contains `bin/codex-capture.sh`.
  - **Allowed members.**
    - `agents/code-reviewer.md` and `agents/drift-evaluator.md`.
    - `bin/codex-capture.sh` and `bin/check-review-input.sh`.
    - Comment-level prose in `bin/codex-await.sh`, `bin/gen-codex-agents.sh` and `bin/team-setup.sh` (engineer's judgement).
    - `tests/codex-skeleton-hygiene/run.sh`, new fixtures `tests/codex-skeleton-hygiene/fixtures/t1192-*.{jsonl,txt}`, `tests/check-review-input/run.sh` and `tests/codex-agents/run.sh`.
    - `tests/check-invocation-path/run.sh`. D9's tracked host binding makes that suite's checkout-root working directory resolve the host binding instead of the scratch default the suite mutates.
    - `skills/review-response/SKILL.md`.
    - `templates/binding-default.conf` (comment only, per **AC3**), `templates/binding-template.conf` and `templates/adapters/codex-cli.txt`.
    - `docs/adopting.md`, `docs/adopting.ja.md`, `docs/workflow.md`, `docs/workflow.ja.md` and `docs/loop-engineering/task-envelope.md`.
    - This task's records: `.shell-team/specs/T-1192-<slug>.md`, `.shell-team/provenance/T-1192.md`, `.shell-team/interventions/T-1192.md`, `.shell-team/interventions/no-task.md`, `.shell-team/reviews/T-1192.md`, `.shell-team/reviews/T-1192-drift.md`, and raw captures `.shell-team/reviews/T-1192-<stem>.{txt,jsonl,json}`.
    - `.shell-team/todo.md` and `.shell-team/test-recipe.md`.
    - `.shell-team/binding.conf` (D9).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac13.XXXXXX") || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; { git diff --no-renames --name-only "$B"...HEAD || exit 1; git diff --no-renames --cached --name-only || exit 1; git diff --no-renames --name-only || exit 1; git ls-files --others --exclude-standard || exit 1; } > "$T/set"; sort -u "$T/set" > "$T/s" || exit 1; grep -qxF bin/codex-capture.sh "$T/s" || rc=1; grep -vxE 'agents/(code-reviewer|drift-evaluator)\.md|bin/(codex-capture|check-review-input|codex-await|gen-codex-agents|team-setup)\.sh|tests/codex-skeleton-hygiene/run\.sh|tests/codex-skeleton-hygiene/fixtures/t1192-[a-z0-9-]+\.(jsonl|txt)|tests/(check-review-input|codex-agents|check-invocation-path)/run\.sh|skills/review-response/SKILL\.md|templates/binding-(default|template)\.conf|templates/adapters/codex-cli\.txt|docs/(adopting|workflow)(\.ja)?\.md|docs/loop-engineering/task-envelope\.md|\.shell-team/(specs/T-1192-[a-z0-9-]+\.md|provenance/T-1192\.md|interventions/(T-1192|no-task)\.md|reviews/T-1192(-drift)?\.md|reviews/T-1192-[a-z0-9-]+\.(txt|jsonl|json)|todo\.md|test-recipe\.md|binding\.conf)' "$T/s" > "$T/bad"; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC14** Records conformant.
  - `bash bin/check-adopter-docs.sh` on this spec exits `0` with zero bytes on both streams.
  - `bash bin/check-handoff.sh` on the board resolved through `bin/team-paths.sh --get todo` exits `0`.
  - Positive control: the spec, the checker and the board are each first asserted non-empty.
  - check: rc=0; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac14.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE; mkdir -p "$HOME" || exit 1; C=bin/check-adopter-docs.sh; S=.shell-team/specs/T-1192-codex-review-model-pin.md; test -s "$C" || exit 1; test -s "$S" || exit 1; bash "$C" "$S" > "$T/o" 2> "$T/e"; test "$?" -eq 0 || rc=1; test ! -s "$T/o" || rc=1; test ! -s "$T/e" || rc=1; BD=$(bash bin/team-paths.sh --get todo) || exit 1; test -s "$BD" || exit 1; bash bin/check-handoff.sh "$BD" > "$T/h" 2>&1 || rc=1; test "$rc" -eq 0

- [ ] **AC18** (N1; Blast radius.) Coupled suites stay green. Each suite below reads a file this task edits. It was found by grepping `tests/` for the edited paths:
  - `tests/check-invocation-path/run.sh` (the bare `codex exec` lines of `agents/code-reviewer.md`, `templates/binding-default.conf`);
  - `tests/check-model-pins/run.sh`, `tests/resolve-executor/run.sh` and `tests/check-setup/run.sh` (`templates/binding-default.conf`; `check-setup` also reads `templates/adapters/codex-cli.txt`);
  - `tests/check-adapter/run.sh` (`templates/adapters/codex-cli.txt`);
  - `tests/codex-agents/run.sh` (the `agents/code-reviewer.md` body, `codex-capture.sh --publish` without `--thread-id`);
  - `tests/trial-recipe/run.sh` (`docs/adopting.md` and `docs/adopting.ja.md`);
  - `tests/team-init/run.sh`, `tests/setup/run.sh` and `tests/check-binding/run.sh` (`templates/binding-template.conf`, which `team-init` copies byte-for-byte as `binding.conf.example`);
  - `tests/bin-help/run.sh`.

  Each suite is scanned for a recursive-deletion pattern first; a match is a broken instrument and exits `1`. Each then exits `0` under `tms` with no line beginning `FAIL`.
  - check: rc=0; export LC_ALL=C; ulimit -f 200000 2>/dev/null; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac18.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; tms(){ local p w k r; set -m; ( ulimit -f 200000; exec bash "$1" ) < /dev/null > "$2" 2>&1 & p=$!; ( sleep 1200; kill -TERM -- -"$p" ) > /dev/null 2>&1 & w=$!; wait "$p"; r=$?; kill -0 -- -"$w" 2> /dev/null; k=$?; kill -TERM -- -"$w" > /dev/null 2>&1; wait "$w" > /dev/null 2>&1; set +m; test "$k" = 0 || return 99; return "$r"; }; rd='r[m][[:space:]]+(-[A-Za-z]*[rR]|--recursive)|find[^|]*-dele[t]e|worktree[[:space:]]+remov[e]'; L=(check-invocation-path check-model-pins resolve-executor check-setup check-adapter codex-agents trial-recipe team-init setup check-binding bin-help); for s in "${L[@]}"; do S="tests/$s/run.sh"; test -s "$S" || exit 1; awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' "$S" | grep -qE "$rd"; ps2=("${PIPESTATUS[@]}"); test "${ps2[0]}" -eq 0 || exit 1; test "${ps2[1]}" -eq 1 || exit 1; done; for s in "${L[@]}"; do tms "tests/$s/run.sh" "$T/log-$s"; test "$?" -eq 0 || rc=1; grep -q '^FAIL' "$T/log-$s"; test "$?" = 1 || rc=1; done; test "$rc" -eq 0

- [ ] **AC19** (D8.) The scaffolded specimen.
  - `templates/binding-template.conf` has exactly one row whose first two fields are `bind code-reviewer`, and with whitespace normalized it reads `bind code-reviewer codex provider-configured - codex-cli`.
  - Positive control: the base blob's row reads `bind code-reviewer codex model-2 - codex-cli`.
  - With comment lines and that row removed, the file equals the base blob with the same lines removed.
  - `bash bin/check-binding.sh --config templates/binding-template.conf` exits `0`.
  - The old specimen token `model-2` occurs as a standalone token nowhere in `templates`, `bin`, `tests`, `skills`, `agents`, `docs` or either README. That is checked with `git grep -E` for `model-2`, not preceded by a letter, digit, `_` or `-` and not followed by a letter, digit, `.`, `_` or `-`. The required result is no match (exit `1`; an exit above `1` fails the line).
    - The pattern cannot match the fixture placeholder `zq-model-2`, which **AC1**, **AC7** and **AC9** use; the line asserts that it does not.
    - At the base, the pattern matches the template row and the two adopting-doc spots, and nothing in `tests` (measured).
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac19.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; if git show-ref --verify --quiet refs/heads/develop; then B=$(git merge-base develop HEAD) || exit 1; elif git show-ref --verify --quiet refs/remotes/origin/develop; then B=$(git merge-base refs/remotes/origin/develop HEAD) || exit 1; else exit 1; fi; git cat-file -e "$B^{commit}" || exit 1; F=templates/binding-template.conf; test -s "$F" || exit 1; git show "$B:$F" > "$T/b" || exit 1; test -s "$T/b" || exit 1; row(){ grep -E '^bind[[:space:]]+code-reviewer[[:space:]]' "$1" | awk '{ $1 = $1; print }'; }; test "$(row "$T/b")" = 'bind code-reviewer codex model-2 - codex-cli' || exit 1; row "$F" > "$T/hr"; test "$(grep -c '' "$T/hr")" = 1 || rc=1; test "$(cat "$T/hr")" = 'bind code-reviewer codex provider-configured - codex-cli' || rc=1; rest(){ grep -v '^#' "$1" | grep -vE '^bind[[:space:]]+code-reviewer[[:space:]]'; }; rest "$T/b" > "$T/b1"; rest "$F" > "$T/h1"; test -s "$T/b1" || exit 1; cmp -s "$T/b1" "$T/h1" || rc=1; bash bin/check-binding.sh --config "$F" < /dev/null > "$T/o" 2> "$T/e"; test "$?" = 0 || rc=1; P='(^|[^A-Za-z0-9_-])model-2([^A-Za-z0-9._-]|$)'; printf 'x zq-model-2 x\n' | grep -qE -- "$P"; test "$?" = 1 || exit 1; git show "$B:$F" | grep -qE -- "$P" || exit 1; git grep -q -E -- "$P" -- templates bin tests skills agents docs README.md README.ja.md; test "$?" = 1 || rc=1; test "$rc" -eq 0

- [ ] **AC20** (D9.) This repository's own binding.
  - `<base>/binding.conf`, with the base from `bash bin/team-paths.sh --get base`, exists, is tracked (`git ls-files --error-unmatch`), and passes `bash bin/check-binding.sh --config`.
  - `bash bin/resolve-executor.sh --print-resolved`, run in this checkout, prints the line `resolved code-reviewer codex gpt-6-luna - codex-cli`.
  - Its `resolved` lines other than `code-reviewer` equal, as a sorted set, the same lines printed in a temp tree whose base dir `.ops` holds no `binding.conf` (the shipped default). That set is non-empty.
  - check: rc=0; export LC_ALL=C; T=$(mktemp -d "${TMPDIR:-/tmp}/t1192-ac20.XXXXXX") || exit 1; export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1; unset TEAM_RUN_BASE CODEX_HOME CODEX_THREAD_ID; mkdir -p "$HOME" || exit 1; R=$(pwd -P) || exit 1; BASE=$(bash bin/team-paths.sh --get base) || exit 1; test -n "$BASE" || exit 1; F="$BASE/binding.conf"; test -s "$F" || rc=1; git ls-files --error-unmatch -- "$F" > /dev/null 2>&1 || rc=1; bash bin/check-binding.sh --config "$F" < /dev/null > "$T/cb" 2>&1 || rc=1; bash bin/resolve-executor.sh --print-resolved < /dev/null > "$T/h" 2> /dev/null || rc=1; grep -qxF 'resolved code-reviewer codex gpt-6-luna - codex-cli' "$T/h" || rc=1; mkdir -p "$T/def/.ops" || exit 1; ( cd "$T/def" && exec env TEAM_RUN_BASE=.ops bash "$R/bin/resolve-executor.sh" --print-resolved ) < /dev/null > "$T/d" 2> /dev/null || exit 1; grep '^resolved ' "$T/d" | grep -v '^resolved code-reviewer ' | sort > "$T/d1"; grep '^resolved ' "$T/h" | grep -v '^resolved code-reviewer ' | sort > "$T/h1"; test -s "$T/d1" || exit 1; cmp -s "$T/d1" "$T/h1" || rc=1; test "$rc" -eq 0

- [ ] **AC15** CI is green on the pull request. This covers the shellcheck step, the codex-skeleton-hygiene, check-review-input, check-review-provider, codex-agents and resolve-executor suites, the prompt-sync and gen-codex-agents dogfood steps, and the diff-scoped PII scan.
  - above-ceiling: the coordinating session, reading the pull request's check run after push. QA reports this criterion as `SKIP`.

- [ ] **AC16** (D1–D3, D5.) A live explicit-model review pass. In a checkout whose effective binding names, for `code-reviewer`, a model the operator's Codex installation accepts, a real fresh-review round shows the items below. This repository qualifies once D9 lands, so this task's own review round may serve.
  - every recorded `executor-invocation` beginning `codex exec -m <that model> `;
  - every `codex-model` line carrying `requested=<that model> — observed=<that model>`;
  - `check-review-input.sh` exiting `0` on that record.

  This is the only real-shape evidence that a CLI-produced rollout passes the extraction rule end to end.
  - above-ceiling: the coordinating session, after QA and before the merge GO, recording the run's verdict and the `codex-model` lines (no account identifiers) on the board. QA reports this criterion as `SKIP`.

- [ ] **AC17** (D1, D4; N1.) This task's own review record. `.shell-team/reviews/T-1192.md` carries one `codex-model (<pass>)` line for every Codex pass, and `bash bin/check-review-input.sh --task T-1192` exits `0`. On each line:
  - `requested` equals field 4 of the effective `code-reviewer` row at review time;
  - the pass's `executor-invocation` carries `-m <requested>` immediately after `codex exec` exactly when `requested` is not `provider-configured`;
  - `observed` equals `requested` whenever a model is named.

  The criterion is value-independent: it holds under the shipped default and under a host binding alike. With D9 in place, `requested` is `gpt-6-luna` and every invocation carries `-m gpt-6-luna`. **AC8**'s contradiction rule refuses any pass whose `-m` disagrees with that binding, so no out-of-binding `-m` can produce a conformant record.
  - above-ceiling: the coordinating session at close-out, because the record is written after QA by the review phase. QA reports this criterion as `SKIP`.

## Input space

**Reachable input classes**:

1. **The effective `code-reviewer` model token:**
   - `provider-configured`, from the shipped default or a host row;
   - a real model id the operator's Codex accepts;
   - a token the provider rejects. The P3 measurement shows a loud `turn.failed`, rc `1`, which the existing non-zero-exit path turns into `BLOCKED`.
   - a model copied unedited, either from an older scaffolded `binding.conf.example` that still carries `model-2` or from the docs example row.

   Every token already satisfies `MODEL_RE`, because the binding validator refuses anything else.
2. **Rollout shapes written by the Codex CLI:**
   - a `review`-subcommand pass. On codex-cli 0.160.0 the string `model` is at `session_meta` `payload.provenance.model`. On 0.171.0 it is at `session_meta` `payload.base_instructions.provenance.model`, with further copies in `event_msg` `thread_settings`, and there is no `turn_context`;
   - a prompt pass. `model` appears in `session_meta`, `turn_context` (twice), `world_state` (some of them object-valued), `event_msg` and `response_item` (a tool-schema object). `world_state` embeds quoted instruction text;
   - a rollout from a CLI version that writes no `model` key in those records;
   - records that disagree;
   - a model value given as a `\u` escape;
   - `model` text inside a command's output string.
3. **Pass ids** `primary`, `adversarial`, `specreview` and their `-rN` forms, plus `drift` and `review-response`.
4. **Review records** with and without the new field, and invocations written bare or wrapped in one pair of backticks.
5. **Hosts.** A Claude Code host runs every `codex exec` path. The Codex CLI host runs the `claude -p` recipe and none of them.
6. **Platforms.** bash on the CI runner (Linux) and on maintainer workstations.

**Out-of-scope synthetic extremes**, declined explicitly:

1. Provider-side substitution behind an unchanged rollout value (P2). This is undecidable from the client.
2. A model id the provider silently maps to another id that the rollout then reports. This is unmeasured; see Assumptions. The docs tell the adopter to bind the id the rollout reports.
3. A rollout record split across physical lines, or a JSON value containing a raw newline. The Codex CLI writes one record per line.
4. A rollout edited on disk between the end of the pass and `--publish` or `--observe`.
5. A binding model token that `check-binding.sh` would refuse (outside `MODEL_RE`, or over its length limit). It never reaches a role.
6. More than one rollout for one thread id. The existing search already refuses `matches=<n>`.

<!-- END intent-block: T-1192 -->

## Body-to-AC correspondence

| # | Directive (where stated) | AC or exemption |
|---|---|---|
| 1 | Named model ⇒ `-m <MODEL>` right after `codex exec` in every mode; `provider-configured` composes as written (D1, decisions 1–2) | **AC4**, **AC5**, **AC6**; record-level backstop **AC8**; live **AC16**, **AC17** |
| 2 | Skeleton lines unchanged; insertion is prose (D1; N1, N3) | **AC6** |
| 3 | Requested model read by the role from `--print-resolved`, never relayed; `check-review-provider.sh` unchanged (D2) | **AC4**, **AC5** (token), **AC3** (checker unchanged); that the role actually reads it is a QA reading item, because a check line cannot see a role's runtime read |
| 4 | Structural extraction of string `model` keys at any depth from `session_meta`/`turn_context` only, covering the 0.160.0 and 0.171.0 shapes; object values ignored; `event_msg` not read; closed causes; exit 3; no canonical write; no echo of a malformed value (D3) | **AC1**, **AC9** (0.171.0 shape) |
| 4a | N2 split into mechanical enforcement and role/QA enforcement (Pre-commitment) | **AC1**, **AC7**, **AC8**, **AC9** (mechanical); **AC4**, **AC5**, **AC17** plus QA reading (role) |
| 5 | Report-only behaviour without a named expectation; ` model=` appended; usage refusals (D3) | **AC1**, **AC2** |
| 6 | `--observe` read-only mode (D3, D7) | **AC9** |
| 7 | Per-pass `codex-model` line; `- Codex model:` filled from it (D4) | **AC4**, **AC5**; **AC17** |
| 8 | `check-review-input.sh` grammar, mismatch and duplicate refusals; no raw read; no echo (D4) | **AC7** |
| 9 | Contradiction refusal (D4) | **AC8** |
| 10 | Per-mode failure handling; never `APPROVE` on an unestablished model (D5; N2) | **AC1** (gate), **AC4**, **AC5** (tokens). The per-mode wording is a QA reading item, because a check line cannot run a role |
| 11 | Docs (D6) | **AC10** |
| 12 | Review-response record line (D7) | **AC9** |
| 13 | Drift report line (D7) | **AC5** |
| 14 | Telemetry unchanged (decision 4; Non-goals) | **AC3** (no prompt block or orchestrator skill edited). That `agents/*.md` does not tell the role to log the observed model is a QA reading item |
| 15 | Codex-CLI-host path and alternate-executor recipe untouched (Non-goals) | **AC3** |
| 16 | Shipped default rows, resolver and validator unchanged (Non-goals) | **AC3** |
| 16a | Specimen `code-reviewer` row becomes `provider-configured`; rest unchanged; `model-2` gone from shipped surfaces (D8) | **AC19**, **AC10** (docs sections) |
| 16b | This repository's tracked binding: well-formed, `code-reviewer` = `gpt-6-luna`, other rows = shipped default; no out-of-binding `-m` (D9) | **AC20**; **AC8** and **AC17** (no out-of-binding `-m`) |
| 16c | Already-scaffolded `binding.conf.example` not rewritten (Non-goals) | info-only (not promoted to AC): it sits in an adopter repository, outside this diff; **AC13** keeps the diff to this repository |
| 17 | `--ephemeral` example not given `-m` (Non-goals) | **AC10** requires both review-line forms. The `--ephemeral` line is info-only (not promoted to AC): a manual fallback, and QA reads the quick-reference |
| 18 | No effort application (Non-goals) | info-only (not promoted to AC): an absence that the unchanged `alternate-executor-invocation.md` (**AC3**) and the unchanged skeleton lines (**AC6**) already keep |
| 19 | P2 residual disclosed (Non-goals) | info-only (not promoted to AC): a disclosure, not a deliverable property |
| 20 | Past records not rewritten (Non-goals) | **AC7** (a legacy record without the field exits `0`); **AC13** keeps other tasks' records out of the diff |
| 21 | No CHANGELOG edit; release note must carry the callout (Non-goals) | **AC13** keeps `CHANGELOG*` out of the diff; the release-note content is info-only (not promoted to AC), because it is release-time work outside this task |
| 22 | No sweep, CI re-run or past check lines (Non-goals) | info-only (not promoted to AC): process exclusions |
| 23 | Pre-commitment and drop order | info-only (not promoted to AC): dispositions, not deliverable properties |
| 24 | Generated custom agents track the role body; suites reading edited files stay green (Blast radius) | **AC11**, **AC18** |
| 25 | shellcheck clean, no recursive deletion (AC rules) | **AC12** |
| 26 | Scope (Notes) | **AC13** |
| 27 | CI green | **AC15** (above-ceiling) |

## Symmetry audit (parallel surfaces)

| Surface | Gets `-m <MODEL>`? | Observation source | Record field | Failure handling |
|---|---|---|---|---|
| primary (`review --base`) | yes when named (D1) | `--publish --thread-id --expect-model`, `session_meta` | `- codex-model (primary[-rN]): …` in `<task>.md` | `BLOCKED — review not established`, no verdict heading, span `--status error` |
| adversarial (evidence pass) | yes when named | `--publish --thread-id --expect-model`, `session_meta` + `turn_context` | `- codex-model (adversarial[-rN]): …` | same as primary |
| specreview | yes when named | `--publish --thread-id --expect-model` | `- codex-model (specreview[-rN]): …` in the `## Spec review` section | not a round, no `### Codex Spec-Review verdict:` heading |
| review-response | yes when named (never dropped) | `--observe --thread-id [--expect-model]` (droppable 1, host ruling) | `- codex-model (review-response): …` in the mode's return and the skill's run record | `BLOCKED`, no per-finding evaluation |
| drift-evaluator | yes when named, using the `code-reviewer` row | `--publish --thread-id --expect-model` | `- codex-model (drift): …` in `<task>-drift.md` (not validated by `check-review-input.sh`) | tooling precondition failure, none of the four verdicts, no report |
| Codex-CLI-host path (`claude -p`) | not applicable: no `codex exec` runs | none | none new | unchanged |

## Blast radius

- **Method and disclosed deviation.** The class is `mechanism`, so the checklist asks for a full-population two-arm diff of merged criteria. Following T-1191 and the operator rulings relayed there (the 2026-10-01 ruling against running past specs' check lines locally, and the A2 light-operation ruling), CI and this task's own check lines decide the impact.
- **Known readers.** These were found with the Grep tool over `.shell-team/specs` for check lines naming the touched paths. The result is a lower bound: a criterion that reaches a path through indirection stays unmeasured, and that is disclosed.
  - T-1177 **AC1** asserts `check-review-provider.sh`'s exact admit stdout and that a model sentinel appears on no stream. D2 keeps the checker unchanged (**AC3**), and this is the reason the recommended "extend the admit line" design was not taken.
  - T-1177 **AC2** compares the `^[[:space:]]*codex exec ` count with its branch-point blob. **AC6** keeps the count equal to this task's base, so the property is unchanged.
  - T-1152's and T-107's criteria and the hygiene suite read `codex-capture.sh`'s alloc/publish behaviour and the skeleton blocks. **AC2** and **AC6** keep them.
  - T-1104's and T-1138's criteria read `check-review-input.sh`. The new field is optional and validated only if present, so a record without it is unchanged (**AC7**).
- **Adopter-side artifacts** (outside version control):
  - **A host `<base>/binding.conf` naming a non-`provider-configured` model** for `code-reviewer` starts taking effect: `-m <model>` reaches Codex. If Codex refuses the id, the pass fails loudly (P3) and the round is `BLOCKED`. If it accepts the id, the review runs on it. Migration: documented in D6, and called out in the release note.
  - **`binding.conf.example`**: a fresh scaffold carries `provider-configured` (D8). An adopter's already-scaffolded copy keeps `model-2`, and `team-setup.sh`'s template-drift note names it. If such a copy is renamed to `binding.conf` without editing, reviews now stop loudly instead of silently running the config default.
  - **Merged criteria on the specimen.** Grep over `.shell-team/specs` found no merged `check:` line asserting the specimen's `model-2`; T-1105's `model-2` is its own fixture's text. This is a lower bound, as above. The specimen's byte copy is compared dynamically by `tests/team-init` (**AC18**).
  - **This repository's binding (D9).** CI's `resolve-executor.sh --print-resolved` dogfood and any check run from the checkout root now resolve `code-reviewer` to `gpt-6-luna`. Criteria in this spec that need the shipped default read it from a temp tree (**AC3**, **AC11**, **AC20**).
  - **Generated Codex custom agents** (`shell-team-code-reviewer.toml`, `shell-team-drift-evaluator.toml`) carry the role body. After an upgrade, `check-codex-agents.sh` reports them as drifted until the adopter re-runs `gen-codex-agents.sh`. That changes nothing on the Codex CLI host, where `claude -p` runs.
  - **Past review records and telemetry** are unchanged (forward-only).

## Version

| Item | Headline | Default-reach | Derived | Ground |
|---|---|---|---|---|
| Named `code-reviewer` model applied as `-m` (decisions 1–2) | met: "pin the model the Codex reviewer runs on" | not met: needs a host `binding.conf`, which most adopters never author | PATCH | an opt-in capability |
| Observed model recorded per pass (decision 3, report-only under the default) | not met: it corrects how an existing field (`- Codex model:`) is sourced | met | PATCH | a fix to a record field |
| Mismatch or absence stops the round (decision 3) | not met | not met: only under a named model | PATCH | an opt-in gate |
| Inert `binding.conf` model now takes effect (claim inversion of `docs/adopting.md:305-311`) | met | not met: the shipped default path is unchanged, so the two tests do not jointly hold | PATCH | per `CONTRIBUTING.md`, the inversion rule only routes the item to the two tests; it is not the default path |
| Specimen `code-reviewer` row becomes `provider-configured` (D8) | not met | not met: it reaches only a newly scaffolded, opt-in example | PATCH | keeps an opt-in file's unedited behaviour as it was |
| This repository's own binding (D9) | not met | not met: the repository's own configuration, not shipped to adopters | PATCH | internal |

The derived tier is PATCH, the maximum of the column. **Host ruling (2026-11-21, relayed): PATCH accepted, released as v2.9.5.**

## Assumptions

- **Measured by this role** (Read, Grep and Glob tools; working tree clean at `75866424`, which `.git/refs/heads/feature/755-codex-review-model-pin` holds; `.git/packed-refs` maps `refs/remotes/origin/develop` to the same SHA, and there is no local `refs/heads/develop`):
  - Every line anchor in `## Summarized sources`.
  - In the four imported T-1191 rollouts (codex-cli 0.160.0), with value-free patterns:
    - The `review`-subcommand rollouts (`primary`, `primary-r2`) carry `"model":` only on line 1, the `session_meta` record, inside an object `"provenance":{"type":"model","model":"<m>"}`. Its parent path under `payload` was not resolved.
    - The prompt-pass rollouts (`adversarial`, `adversarial-r2`) carry it on line 1 (`session_meta`), twice on line 7 (`world_state`, followed by the keys `instructions` and `multi_agent_mode`) and twice on line 8 (`turn_context`). The `turn_context` occurrences are a `model` key followed by `comp_hash`, and `"collaboration_mode":{"mode":"default","settings":{"model":"<m>"}`.
    - All values in each file are one identical value.

    The fixture shapes in **AC1**, **AC2** and **AC9** follow these positions.
  - No file under `tests/` names `--thread-id` other than the hygiene suite's four markdown greps (`:867-876`), and none names `task_complete` or `review did not run`. `--publish --thread-id` has no fixture suite today.
  - Outside `.shell-team/`, these occur 0 times: `-m <model>`, `-m <MODEL>`, `codex-model`, `model not established`, `expect-model`, `--observe`, `cause=absent|mismatch|inconsistent|malformed`, `codex-model-(mismatch|vocabulary|duplicate|contradiction)` and `model=unavailable`.
  - `agents/code-reviewer.md` and `agents/drift-evaluator.md` each have exactly one `^- Codex model:` line, and it carries `<e.g.`. `--print-resolved` occurs in `code-reviewer.md` only before `## Your loop` (`:14`) and not at all in `drift-evaluator.md`. `provider-configured` does not occur in either file.
  - No `.shell-team/binding.conf` exists, so this checkout runs the shipped default. No `.codex/agents/*.toml` is tracked.
  - `templates/binding-template.conf:26` carries `model-2`, and `docs/adopting.md:302` carries `gpt-5`.
- **Relayed from the host through the coordinating session** (2026-11-21; primary source: issue #755 body and the host's answers, which this role cannot read): the five decisions in Summarized sources. The freeze run confirms them against the issue body.
- **Host rulings on this spec's open questions** (2026-11-21, relayed by the coordinating session; primary confirmation is held by the coordinating session):
  1. The version tier is PATCH, released as v2.9.5.
  2. Decision 3's record for review-response is the mode's return value plus the skill's run record, so D7 and **AC9** stand.
  3. `templates/binding-template.conf`'s `code-reviewer` model becomes `provider-configured`, in scope (D8, **AC19**). The docs-warning-only plan is dropped.
  4. This repository's reviewer pin moves into `.shell-team/binding.conf`, with `code-reviewer` set to `gpt-6-luna` and every other row equal to the shipped default (D9, **AC20**). The coordinating session retires its own out-of-binding briefing rule after merge; that is not repository work.
- **`model-2` inventory** (measured by this role, Grep over the tree outside `.shell-team/`): `templates/binding-template.conf:26`, `docs/adopting.md:262` and `docs/adopting.ja.md:263`, and nothing else.
  - No test asserts the literal. `tests/team-init/run.sh:135` compares the scaffold byte-for-byte with the template, and `.github/workflows/check-handoff.yml:302` runs `check-binding.sh --config templates/binding-template.conf`. Both read the template dynamically.
  - `tests/team-init/run.sh:211` requires a `T-NNN` citation in the template's comment, so the specimen keeps its provenance comment.
  - No `.gitignore` entry names `binding.conf`, so `.shell-team/binding.conf` is tracked once committed.
- **Measured on codex-cli 0.171.0** (2026-11-21, value-free structural walks, relayed to this role).
  - **The coordinating session's `review`-subcommand rollout (P1b).**
    - `session_meta` carries the model as a string at `payload.base_instructions.provenance.model`, not at the 0.160.0 position `payload.provenance.model`.
    - `event_msg` records carry it as strings at `payload.thread_settings.model` and `payload.thread_settings.collaboration_mode.settings.model`.
    - There is no `turn_context` record.
  - **The spec-review round 1 reviewer's prompt-pass rollout.**
    - `session_meta`: once, at `payload.provenance.model`, a string.
    - `turn_context`: twice, at `payload.model` and `collaboration_mode.settings.model`, both strings.
    - `world_state`: three times, including object-valued `model` keys.
    - `event_msg`: twice. `response_item`: once, a tool-schema object.
    - The `session_meta` and `turn_context` string values agreed.

  Consequence for D3: extraction reads every string-valued `model` key at any depth, only inside `session_meta` and `turn_context` records, and ignores object-valued keys. `event_msg` is not read, because `session_meta` is present in both pass kinds. **AC1** and **AC9** carry a 0.171.0 `review`-shape fixture.
- **Relayed measurements** (2026-11-21, codex-cli 0.171.0, owner: the coordinating session):
  - P1: `-m <m>` placed before the `review` subcommand is accepted and overrides the configured default, and the rollout carries only `<m>`.
  - P2: provider truth is undecidable client-side.
  - P3: an unsupported id ends the run with rc `1` and `turn.failed`.
- **Relayed by the tech-lead Routing Map and re-measured here:**
  - the invocation sites and lines;
  - the hygiene locks;
  - `check-review-input.sh`'s raw-never-read header;
  - the publish summary at `:625`;
  - `MODEL_RE`;
  - field 4 of the resolver row.

  These two were re-measured and found partly false:
  - `docs/loop-engineering/tier2-firing.md` holds only historical telemetry rows, with no stale prose.
  - `templates/prompt-blocks/executor-resolution.md`'s `provider-configured` sentence stays accurate under the default.

  Neither is edited (see the hand-off).
- **Predicted, unmeasured** (owner: the coordinating session's freeze run, then the engineer). A false prediction routes back here as a broken check line, never as a pass.
  - `bin/team-setup.sh`'s `tpl_drift` reports an already-scaffolded `binding.conf.example` that differs from the changed specimen. This rests on the call site only; the engineer confirms it by reading the function and corrects the Non-goals and Blast-radius wording through pm-spec if it is false.
  - The synthesized rollouts in **AC1**, **AC2** and **AC9** pass the base script's completed-run gate. **AC1** asserts this as its own positive control and exits `1` if it fails.
  - `bash bin/resolve-executor.sh --print-resolved` in this checkout prints `resolved code-reviewer codex provider-configured - codex-cli` (**AC3**).
  - (The former freeze-run duty to measure the 0.171.0 shapes is discharged; see "Measured on codex-cli 0.171.0" below.)
- **Exact equality across aliases.** Whether the provider canonicalizes an alias id, so that a bound id and a reported id differ, is measured for one model only (P1). Exact byte equality is the rule, and a canonicalizing provider produces a loud `cause=mismatch`, never a silent pass.
  - stale-at: the Codex CLI changes its rollout schema, or a measured bound id is reported back under another id.
- **Borrowed tokens** (the freeze run measures each at `B`):
  - `^- Codex model:` in each agent file (expected 1 each);
  - `^[[:space:]]*codex exec ` per agent file (read from the base blob by **AC6**, so no literal is asserted);
  - `admit codex-binding` in `bin/check-review-provider.sh` (expected 2, unchanged by **AC3**);
  - `provider-configured` in `templates/binding-default.conf` non-comment lines (expected 1).

  Own-coinage tokens are listed above at 0.
- **Pre-implementation expectation (for the freeze read).**
  - **AC1** exits `0` on the base positive control and is red on the first `--expect-model` case (base exit `2`).
  - **AC2** is red only on its "HEAD differs" control and the two appended-token comparisons; every base-identity pair is green.
  - **AC3** green.
  - **AC4**, **AC5**, **AC7**, **AC8**, **AC9** and **AC10** red.
  - **AC6** red only on the missing `PASS: T-1192 ` line.
  - **AC11** red on `-m <MODEL>`.
  - **AC12** green.
  - **AC13** red on its positive control.
  - **AC14** green when the board entry is conformant.
  - **AC18** green.
  - **AC19** red: the row still reads `model-2`.
  - **AC20** red: there is no binding file.
  - **AC15**–**AC17** `SKIP`.

## Re-freeze record

- **v1→v2 (2026-11-21), class-B.** **Trigger:** the engineer's implementation of D9 (the tracked `.shell-team/binding.conf`) made `tests/check-invocation-path/run.sh` fail. That suite ran from the checkout root, where the new host binding overrides the scratch default it mutates. The engineer's fix is one hunk that changes into the suite's scratch dir at the top. As frozen in v1, **AC13** (scope lock) and **AC18** (that suite exits `0`) could not both pass.
- **Host ruling** (2026-11-21, relayed by the coordinating session): Option A. Keep the test fix, add the path to **AC13**'s allow-list, and re-freeze as v2.
- **Delta.** **AC13** only: one allow-list bullet naming `tests/check-invocation-path/run.sh` with its reason, and that path added to the `- check:` line's allow-list regex. Nothing else in the intent block changed.
- The v2 hash and attestation are recorded by the coordinating session after its live sweep.

## Open questions

- None open. All four earlier questions were resolved by host rulings on 2026-11-21 (relayed; see Assumptions):
  1. version tier: PATCH, as v2.9.5;
  2. review-response record location: the mode's return value plus the run record (D7);
  3. specimen row: `provider-configured` (D8, **AC19**);
  4. this repository's pin: `.shell-team/binding.conf` with `gpt-6-luna` (D9, **AC20**).

## Notes for engineer

- **Files.** The allow-list is in **AC13**. Everything else, prompt blocks and orchestrator skills included, stays as at the base (**AC3**).
- **The two binding files.**
  - `templates/binding-template.conf`: change only the `code-reviewer` row's model column (**AC19**). Comment wording may follow it, but keep its `T-NNN` provenance citation, which `tests/team-init` requires.
  - `.shell-team/binding.conf`: copy the six rows from `templates/binding-default.conf` and change only `code-reviewer`'s model to `gpt-6-luna` (**AC20**). Check it with `check-binding.sh --config` and commit it. Do not resolve the base path by hand: use `team-paths.sh --get base`.
- **Fixed strings the checks read.**
  - In the agent files: `-m <MODEL>` in the prose that states the D1 insertion (the effort-clause precedent); `--print-resolved`; `--expect-model`; `--observe`; `codex-model (<pass>): requested=`; `codex-model (drift): requested=`; `codex-model (review-response)`; `model not established`.
  - `codex-capture.sh`: the summary suffix ` model=<v>`, the refusal text `model not established`, and the causes `cause=absent|mismatch|inconsistent|malformed`.
  - `check-review-input.sh` refusal tokens: `codex-model-vocabulary`, `codex-model-duplicate`, `codex-model-mismatch` and `codex-model-contradiction`.
  - Suite labels: the hygiene suite prints at least one `PASS: T-1192 …` line, and the check-review-input suite prints at least one `PASS:` line containing `codex-model`.
- **Extraction.** Reuse the publish gate's tokenizer discipline: string literals are opaque, and a key is a string followed by `:`. Read `model` keys at any depth, only in records whose top-level `type` is `session_meta` or `turn_context`. Ignore an object- or array-valued `model`, and treat a non-string scalar as malformed. Do not hard-code one path: 0.160.0 and 0.171.0 differ. Never substring-grep a rollout for `"model"`: `world_state` quotes instruction text.
- **Publish lines.** The hygiene suite locks the substring `--publish --stem … --thread-id "<THREAD_ID>"`, so append `--expect-model "<MODEL>"` after it. `--expect-model provider-configured` is report-only, so the publish line may carry it unconditionally.
- **Fixtures.** Synthesize rollouts in the measured shapes: session_meta-only, prompt-shaped with a `world_state` decoy, disagreeing, malformed and missing. Never copy a real rollout: `session_meta` carries account identifiers. New fixture files are named `t1192-*` under `tests/codex-skeleton-hygiene/fixtures/`.
- **No echo.** Neither script echoes an account identifier, a non-`MODEL_RE` value or a field's bytes in a refusal.
- **Mutation probes (mechanism class).** In a scratch copy, break each never-dropped property once and confirm the matching criterion goes red, then restore it. For example:
  - append a token to the no-`--expect-model` summary differently (**AC2**);
  - let `world_state` count (**AC1**, the `r10` case);
  - compare by prefix (**AC1**, the `r9` case);
  - add `-m` to a skeleton line (**AC6**).
- **Measured-at-ref command check.** Not applicable: no deliverable prints a command labelled as measured at a git ref.
- **Review depth.** `codex-capture.sh` and `check-review-input.sh` are shipped `bin/` gates and get full strength. The agent prose and docs are shipped text. The inline check lines get dev-scaffold depth (operator ruling 2026-08-22).

## Notes from engineer

- **Predicted claim confirmed.** `bin/team-setup.sh`'s `tpl_drift` body (the `cmp -s` then `case "$r"` arm for status 1) reports an already-scaffolded `binding.conf.example` that differs from the changed specimen as `differs from the installed plugin's template`, so the Non-goals and Blast-radius wording about `team-setup.sh` is true as written.
- **D9 side effect not named in the allow-list.** A tracked `<base>/binding.conf` in this repository is read by every script run from the checkout root, because `resolve-executor.sh` resolves its base dir from the caller's cwd. `tests/codex-agents/run.sh` fixture 6 (the "no `model =` under the shipped default" half) and three cases of `tests/check-invocation-path/run.sh` (which mutate a scratch copy of `templates/binding-default.conf` and expect the copied scripts to honour it) went red for that reason. The first is on **AC13**'s allow-list; the second, `tests/check-invocation-path/run.sh`, is **not**, yet **AC18** requires it to exit `0`. It now runs from its scratch root (one `cd` after the scratch root is made), so **AC18** is green and **AC13** names that file as outside the allow-list. The two criteria cannot both pass as frozen; the allow-list needs that path added (a class-B change) or the one-line edit dropped.
