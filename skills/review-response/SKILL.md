---
description: 受領したレビュー指摘（自分の PR に返ってきた変更要求）を Codex でクロス評価し、リスクに応じて人間確認を挟んでからチーム実装に流す。会話キーワード「チームでレビュー対応」または明示起動 /shell-team:review-response で発火する。Unlike `review` (which runs a fresh Codex review of the current branch diff), this skill triages review feedback that has ALREADY come back on a PR. Use when a reviewer left CHANGES_REQUESTED or change-request-equivalent comments and you want them cross-evaluated, risk-gated, and — on your GO — implemented by shell-team.
---

You are running the **review-response loop** for a pull request whose review has come back with changes to make. Your job: pull the received findings, get an independent cross-provider evaluation of each, decide (with a deterministic safety floor) which findings a human must look at vs which are safe to adopt automatically, and — once cleared — hand the adopted findings to `shell-team` as a single spec.

This skill runs **on the main loop** (not as a sub-agent) on purpose: Step 3 can **stop mid-flow and wait for your GO** when a risky finding shows up, and only a main-loop skill can pause for user input and resume. A sub-agent runs to completion and returns; it cannot hold a conditional human gate open. That conditional pause is the whole reason this is a skill.

## Boundary vs the sibling skills (don't confuse them)

- **`review`** — runs a *fresh* Codex review of the **current branch diff**. Unlike `review`, `review-response` does not generate new review findings — it consumes findings a reviewer already left on a PR and decides what to do about them.
- **`loop-triage`** — discovers candidate *work* (failing CI / open PRs / triage issues) and proposes it; read-only, never acts.
- **`run`** — the full PM→Engineer→QA→Codex pipeline that actually implements. `review-response` ends by *calling* `run` with the adopted findings; it does not re-implement the pipeline.

## Step 0 — resolve paths, mirror the language

The shell-team operating files may live under `.shell-team/` (default), a legacy `tasks/` layout, or a `$TEAM_RUN_BASE` override — `team-paths.sh` decides (on PATH when the plugin is loaded; else `bin/team-paths.sh`). Run `team-paths.sh --print` once to read the resolved paths (`TEAM_RUNS_DIR`, `TEAM_SPECS_DIR`, `TEAM_TODO`).

⚠️ **Env vars do NOT persist across separate Bash tool calls** (each call is a fresh shell). When a later call needs a path, resolve it *in that same call* with `$(team-paths.sh --get KEY)` — do not `export` it once and expect it to survive.

**Language — mirror the user.** When you invoke `codex-reviewer`, prepend one line telling it to respond in the same language the user is conversing in. **But machine-parsed tokens stay verbatim in English**: `CHANGES_REQUESTED`, `APPROVE` / `REQUEST_CHANGES`, and the gate labels `auto` / `escalate` / `reject`. Prose follows the conversation language; these tokens do not.

Identify the target PR from the user's request (a number, a URL, or "this branch's PR"). If it's ambiguous, ask once.

## Step 1 — detect the received findings

Fetch the PR's reviews and comments and extract the findings that ask for a change. Two classes count:

1. **`CHANGES_REQUESTED`** — an explicit "Request changes" review.
2. **change-request-equivalent** — a review submitted as *Comment* (not formally requesting changes) whose content is nonetheless a change request (e.g. "must-fix: 0, nice-to-have: 1 — fix this one and it's good to merge"). These carry the real asks in practice and must not be dropped just because the review state is `COMMENTED`.

Use the GitHub MCP tools (`pull_request_read` with review/comment methods) or `gh pr view --json reviews,comments` — either satisfies the requirement. List each extracted finding with its source (review id / comment url) so the run record can cite it.

## Step 2 — Codex cross-evaluation of each finding

**Executor resolution (T-1057).** For each of the six bound roles a phase invokes, resolve that role's executor immediately before invoking it: run `bin/resolve-executor.sh --role <role>` (on `PATH` when the plugin is loaded; else `bin/resolve-executor.sh`) and treat every refusal — `usage`, `binding-unresolved`, `executor-unavailable`, `capability-unsupported` or `contract-violation` — as a blocker that stops the phase and escalates to the human, quoting the refused token verbatim. Never substitute another executor for a role whose resolution refused, and never continue with any role left unresolved. When a resolved row's own stdout names the `in-process` probe kind, treat the harness's own sub-agent invocation failure for that role as `executor-unavailable` too, stopping the phase and escalating exactly as for any other refusal. Take each `--model` telemetry value from that role's own resolved row rather than from any prompt's pinned model value — the resolved binding is the telemetry source of record for every bound role's model, and this claim is bounded honestly rather than papered over: a role's actual invocation still routes through that role's own pinned model value, not through this resolution, so telemetry drawn from the resolved row matches what actually ran only for as long as a bound role's own pin and the effective binding's model token agree; a custom binding that departs from the shipped default records the bound model as telemetry, not an independently verified executed one. Bindings to an alternate-executor adapter are the disclosed exception to that pin-routes-execution claim: such invocations execute under that adapter's own installation rather than under any pinned model value, so a resolved row's model column stops declaring a pin and states what actually ran; where that adapter's own recipe passes no model flag, `provider-configured` is the honest token to record, exactly as it already is for the shipped default's `codex-reviewer` row. Apply this at this step's own invocation point (`codex-reviewer`); Step 4's hand-off to `shell-team:run` resolves again inside that loop, and that is a second path rather than a substitute for this one.

Hand the extracted findings **plus the PR diff** to the `codex-reviewer` agent (Agent tool, `subagent_type: shell-team:codex-reviewer`) and ask it to evaluate each finding **independently**, returning for each:

- **validity** — is the finding correct about the code? (`agree` / `partially` / `disagree`)
- **severity** — `blocker` | `major` | `minor` | `nit`
- **recommended fix** — the concrete change the finding implies (or "none needed" if invalid)
- **objection** — if Codex thinks the reviewer is wrong, its counter-argument (this is a cross-provider disagreement signal)
- **risk-area** — which risk surface (if any) the recommended fix would touch: one of `architecture` / `security` / `prod` / `db-migration` / `irreversible` / `numeric-accuracy` / `external-docs` / `rca`, or `none` (the 8-category table is in Step 3)
- **confidence** — Codex's confidence in *this evaluation*: `high` / `medium` / `low`

The last four fields — **objection, severity, risk-area, confidence** — are exactly the four inputs the deterministic floor consumes in Step 3. They come from Codex, **not** from your own guess: sourcing all four from the cross-provider evaluation is what keeps the floor mechanical and keeps the independence real. If Codex omits `risk-area`/`confidence` for a finding, ask it again rather than filling them in yourself.

This is a *finding-evaluation* use of `codex-reviewer`, distinct from its default "review the current branch diff" mode — construct the evaluation prompt here and pass the findings + diff in it (see `agents/codex-reviewer.md` → "Finding-evaluation mode"). The cross-provider point stands: the evaluation must come from Codex, never a Claude-only judgment.

## Step 3 — risk gate (hybrid: deterministic floor + grey-zone judgment)

Classify **each finding** into `auto` / `escalate` / `reject`. This is a **hybrid**: a mechanical floor you cannot argue with, plus your own judgment only in the space the floor leaves open.

### The deterministic floor (mechanical — always escalates)

For each finding, run the floor helper with **the four attributes Codex returned in Step 2** (`objection`, `severity`, `risk-area`, `confidence`) — do not substitute your own values:

```
review-gate.sh --objection <yes|no> --severity <blocker|major|minor|nit> \
               --risk-area <CATEGORY|none> --confidence <high|medium|low>
```

(map Codex's `objection` field to `yes` when it raised a counter-argument, else `no`.)

(on PATH when the plugin is loaded; else `bin/review-gate.sh`.) It prints `escalate <rules>` or `clear`. If it prints `escalate`, that finding is **red — no exceptions**. The floor fires on any of:

- **objection** — Codex disputes the reviewer (two model families disagree → a human breaks the tie).
- **high-severity** — `blocker` or `major`.
- **risk-area** — the fix touches one of the frozen risk surfaces below.
- **low-confidence** — Codex's evaluation is low-confidence.

**Risk-area categories** (a frozen snapshot embedded here and in `bin/review-gate.sh`; NOT read from any host's private global config at run time, because this plugin is a generic distributable — edit both together to change the list):

| category | covers |
|---|---|
| `architecture` | architecture design / technical selection |
| `security` | auth/authz, certs/CA, IAM policy, **secrets**, security-review |
| `prod` | operations touching the production environment |
| `db-migration` | DB schema design / **migration** |
| `irreversible` | **irreversible** / destructive operations |
| `numeric-accuracy` | logic where numeric correctness matters (money, aggregation) |
| `external-docs` | outward-facing docs / compliance |
| `rca` | root-cause analysis of a complex bug |

These mirror the "high cost of being wrong" (xhigh) surfaces: getting one of these wrong is expensive and hard to undo, so it always gets human eyes.

### The grey zone (your judgment — only when the floor is `clear`)

For findings the floor rules `clear`, you decide `auto` vs `reject`:

- **`auto` (green)** — adopt automatically. Requires **`validity = agree`**, severity `minor`/`nit` and mechanical (typo, lint, naming, docs, a localized non-behavioral fix), no risk area, and an unambiguous recommended fix.
- **`reject`** — Codex found the finding invalid (`validity = disagree`) and nothing on the floor forced escalation; record why you're not adopting it.
- **`validity = partially`** — never `auto`. A partially-valid finding isn't cleanly correct, so it doesn't qualify as green. If the valid part is a real ask, treat it like a red finding and surface it for the human GO (don't silently drop it); if the residue is not worth acting on, `reject` with a note. In no case adopt a `partially`-valid finding automatically.

### The conditional human gate

- **If there are 0 `escalate` findings**, do **not** stop — proceed straight to Step 4 with the `auto` set. (The final human gate is still `shell-team`'s pre-merge stop.)
- **If there is ≥1 `escalate` finding**, present the red findings to the user (each with Codex's evaluation, the fired floor rule, and the recommended fix) and **STOP**. Show the `auto`-adopted (green) findings as FYI in the same message so nothing is hidden, but only the red set needs a decision. Wait for the user's explicit GO (which red findings to adopt). Do not proceed to Step 4 until they respond.

## Step 4 — hand the adopted findings to shell-team

Combine the adopted findings — `auto` ∪ the red findings the user approved — into **one** spec and invoke `shell-team` (Skill tool, `shell-team:run`) once. Do **not** launch shell-team per finding. `shell-team` then runs its own PM→Engineer→QA→Codex pipeline.

**Human gate on merge.** shell-team stops before merge by default and this skill does not change that: do not merge, push, or tag without the user's explicit instruction. The pre-merge stop is shell-team's, and it stays.

## Run record (for retro / lessons)

Append every finding's gate decision to a run record so a mis-classification is auditable later:

```
$(team-paths.sh --get runs)/review-response-<ts>.md
```
(resolve the runs dir in the same Bash call; `<ts>` is a UTC timestamp.) For each finding record: the source (review/comment ref), the classification (`auto` / `escalate` / `reject`), **which rule fired** (the deterministic floor rule name, or your grey-zone rationale), and Codex's evaluation summary.

**Collision rule: never-overwrite.** If that file already exists, append a numeric suffix (`-2`, `-3`, …) and use the first free slot.

This record is what `scrum-master` reads at retro time: when a finding that was auto-adopted (or wrongly escalated) later causes a problem, the retro names the exact rule that mis-fired and proposes an entry for the lessons log (resolved via `team-paths.sh --get lessons`) to tighten it — closing the self-improvement loop. The gate is transparent by design, never a black box.

## Telemetry (best-effort)

If you drive sub-agents, you may emit a span per call via `log-run.sh` (see `shell-team`'s Telemetry section). Best-effort: if `log-run.sh` is not callable, ignore it — it must never stop the flow. Append `|| true`.

**Telemetry binding (T-1058).** After each bound role's sub-agent call returns, and using the same resolved row `--model` telemetry already reads (`bin/resolve-executor.sh --role <role>`), pass that row's provider, effort and adapter fields on that call's span as `--provider`, `--effort` and `--adapter` to `bin/log-run.sh`, carrying the row's effort field verbatim including a bare `-`; when instead that role's resolution refused, write no span row for that call at all, and record the refusal as an `--event gate --from <phase> --label <refusal token>` row with the token verbatim, because a span records a call that happened and a refused resolution made none. Every value recorded this way is the resolved binding as declared, never an independently verified observation of what executed, and a span that omits one or more of the three is read at aggregation as `undetermined`, never as a default. Whether this skill emits telemetry at all stays best-effort as this section already states; the paragraph above fixes what values a span carries when one is emitted, and what shape the refusal row takes when a resolution refused.
