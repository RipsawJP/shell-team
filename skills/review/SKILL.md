---
description: Run the codex-reviewer on the current branch (skips PM/Engineer/QA — just the cross-provider review)
---

**Executor resolution (T-1057).** For each of the six bound roles a phase invokes, resolve that role's executor immediately before invoking it: run `bin/resolve-executor.sh --role <role>` (on `PATH` when the plugin is loaded; else `bin/resolve-executor.sh`) and treat every refusal — `usage`, `binding-unresolved`, `executor-unavailable`, `capability-unsupported` or `contract-violation` — as a blocker that stops the phase and escalates to the human, quoting the refused token verbatim. Never substitute another executor for a role whose resolution refused, and never continue with any role left unresolved. When a resolved row's own stdout names the `in-process` probe kind, treat the harness's own sub-agent invocation failure for that role as `executor-unavailable` too, stopping the phase and escalating exactly as for any other refusal. Take each `--model` telemetry value from that role's own resolved row rather than from any prompt's pinned model value — the resolved binding is the telemetry source of record for every bound role's model, and this claim is bounded honestly rather than papered over: a role's actual invocation still routes through that role's own pinned model value, not through this resolution, so telemetry drawn from the resolved row matches what actually ran only for as long as a bound role's own pin and the effective binding's model token agree; a custom binding that departs from the shipped default records the bound model as telemetry, not an independently verified executed one. Apply this at this skill's single invocation point: the `codex-reviewer` invocation described below.

Invoke the `codex-reviewer` sub-agent on the current branch's diff against `origin/main`. Use this when you want a quick second opinion without going through the full team pipeline (e.g., reviewing someone else's PR, or sanity-checking a manual change).

Pass through any extra focus from the user if provided:

$ARGUMENTS
