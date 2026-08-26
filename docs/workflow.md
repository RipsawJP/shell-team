# Workflow detail

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](workflow.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](workflow.ja.md)

## Phase boundaries (status flags)

```
   pm-spec                engineer              qa-verifier            codex-reviewer
      │                      │                      │                       │
      ▼                      ▼                      ▼                       ▼
  READY_FOR_ARCH ──► READY_FOR_ENG ──► READY_FOR_QA ──► READY_FOR_REVIEW ──► READY_FOR_MERGE
      ▲                                       │                       │
      └─────────── REWORK (engineer) ◄────────┘ ◄─────────────────────┘
```

`tech-lead` slots in before `pm-spec` for non-trivial work, producing the Routing Map. It does not write a status flag.

`ui-designer` slots in **between `pm-spec` and `engineer`, but only for UI work** (screens, components, styles, visual/UX changes). It produces a design note (`<specs dir>/design-note-T-NNN.md`) that the engineer implements against, and — like `tech-lead` — it does **not** write a status flag (the board stays at `READY_FOR_ARCH`; the design note's existence gates the engineer). For non-UI tasks `ui-designer` does not participate at all. It uses the `frontend-design` Skill when available and degrades to in-house guidance (announced, not silent) when it is not — `frontend-design` is an optional, not a hard, dependency.

## Task aptitude — When the full loop fits

**First branch — does the final verification surface close inside the loop?**

- **Closes inside the loop** (correctness is settled by *mechanical* verification — tests, lint, execution/output comparison): the full PM → Engineer → QA → Codex loop **fits**. QA and Codex can confirm the acceptance criteria empirically and statically, so a FAIL is caught inside the loop rather than after a human looks at the result.
- **Does not close inside the loop** (the final gate is *human visual inspection, a real renderer, or subjective evaluation* — e.g. slide/PDF layout, pixel-level UI polish, prose tone): the full loop is a **poor fit, or fits only in a limited way**. QA cannot substitute for the human eye, and the loop only surfaces the human visual gate at the very end, so a visual FAIL costs a whole round-trip and can churn the same code path for many rounds (observed in practice: 10+ rework rounds on a single visual task before a human caught the real issue).

**Provisional operation for visual-output tasks** (a stop-gap until a dedicated short-cycle / variant loop is built): do **not** put such a task on a single full-loop pass. Instead run a short manual cycle (implement, render, human check) where the human views the real rendered output each turn; keep spec / QA in a supporting role rather than as the completion gate.

> This first branch anticipates the same shape as a grounded-AI-evaluator's OOD-novelty / human-gate criterion: a verification surface that cannot be mechanically grounded escalates to a human.

## When to skip phases

| Situation | Allowed shortcut |
|-----------|------------------|
| Single-line typo or comment fix | `tech-lead` may skip directly to `engineer` |
| Non-UI task (CI/bash/backend/docs/config, or non-visual frontend edits) | `ui-designer` does not participate — no `[Design]` phase |
| Test-only change (adding a missing test) | Skip `pm-spec`; `engineer` + `qa-verifier` + `codex-reviewer` |
| Reviewing someone else's PR | Use `/review` — only `codex-reviewer` runs |
| Responding to review feedback already on your PR | Use `/review-response` — Codex-evaluates the received findings, risk-gates them (a deterministic floor forces risky ones to a human), then hands the adopted set to `shell-team` |
| Spec only (no code yet) | Stop after `pm-spec`; task is at `READY_FOR_ARCH` (spec written) and pauses |
| Spec already authored (`specify — operator-authored`, not the shipped `pm-authored` default) | `pm-spec` does not skip — it runs as a conformance formatter instead of an author; see [Choosing who authors the spec](adopting.md#choosing-who-authors-the-spec-t-1091) |
| Spec review elected (`spec-review — cross-provider`, not the shipped `none` default) | No phase is skipped — an extra `codex-reviewer` pass reads the spec document's domain premises at the Specify seam, after the freeze sweep and before the intent hash; a `REQUEST_CHANGES` routes back to the spec's own author before Implement starts. See [Electing a spec review at the Specify seam](adopting.md#electing-a-spec-review-at-the-specify-seam-t-1092), `docs/loop-engineering/specify-seam-review.md` |

`/review` vs `/review-response`: `review` generates a *fresh* Codex review of the current branch diff; `review-response` triages review findings that **already came back** on a PR — it evaluates and risk-gates them, then (on your GO for any risky ones) drives `shell-team` to implement the adopted set. Neither replaces the other.

## Hand-off contract

Each agent's hand-off block in the main session must include:
- Task ID
- New status flag
- Files touched (or files read, for read-only roles)
- One sentence on what's notable for the next agent

This block is the *only* reliable channel between agents — they don't share memory.

When a spec carries a `- verification-ceiling:` declaration (T-1093), a
`READY_FOR_REVIEW` hand-off additionally carries the declared value —
transcribed verbatim from the spec, never invented — so the flag reads
"green up to" this level rather than bare green; the same line rides onto
the board's own record of that hand-off. See
[Declaring the verification ceiling](adopting.md#declaring-the-verification-ceiling)
for the grammar and what it does and does not guarantee.

At three mechanically detectable points — the same-class-2 count reaching
two, a spec pre-commitment's factual trigger, and a loop-guard `STOP:`
escalation — the loop runs a **means-ends reflection** (T-1095, issue #346)
before it composes any hand-off to you: it answers four fixed questions in
writing, and when (1) the task's own never-dropped items are all still
green, (2) every finding targets one or more already-named auxiliary
components (in the pre-commitment's own recorded drop order, when there is
more than one), and (3) a pre-priced disposition exists for the earliest of
them, that disposition executes on the loop's own authority and is recorded
on your board with the four answers as its ground, rather than being
escalated as one option beside a cheaper-looking patch. Escalation to you
stays mandatory whenever one of those three conditions fails, whenever the
disposition itself would be destructive or irreversible, or whenever the
finding set is empty or not yet classified. The three standing human gates —
the batch GO before a merge, sprint planning approval, and any destructive
or irreversible operation — are unchanged; this only changes what the loop
will and will not interrupt you for at those three points. See
[`docs/loop-engineering/means-ends-reflection.md`](loop-engineering/means-ends-reflection.md)
for the one worked example this reflection currently rests on.

## Language — mirror the conversation

Team output **mirrors the user's conversation language**: when `/shell-team:run` or
`/goal` drive the pipeline, the orchestrator prepends a one-line directive to each
sub-agent's prompt telling it to respond in the same language the user is
conversing in (default English if unclear). This is **zero-config** — no
language config file and no environment variable, and the host's `CLAUDE.md` is untouched; the
framework stays generic and adopters opt in simply by conversing in their
language. There is no explicit override (e.g. English chat but Japanese team
output).

**Machine-parsed tokens stay verbatim in English — never translated**: the status
flags (`READY_FOR_ARCH` … `READY_FOR_MERGE`, `BLOCKED`, `REWORK`), the verdict
labels (`PASS` / `FAIL` / `APPROVE` / `REQUEST_CHANGES`), and each agent's fixed
hand-off headings/keys. These are grepped by `check-handoff.sh`, `goal-state.sh`
(no-progress signature), and `check-acs.sh`, so translating them would break the
pipeline. Prose follows the conversation language; the contract tokens do not.

**Per-cycle artifacts** (retros written by `scrum-master`) follow the same
zero-config rule: there is no separate language setting for them either.
`bin/check-retro.sh` validates a retro's *structure* only, anchored on
language-neutral `<!-- retro-section: keep|problem|try|traps|lessons -->`
markers — the heading text beside each marker is free, so a retro in
Japanese, English, or anything else passes the same structural check. See
`docs/templates/retro-template.md` for the shipped (English) skeleton and its
migration note for retros written before the marker contract existed. The
run-replay page `bin/gen-loop-replay.sh` renders on demand joins the same
class: the operator-authored `label` text an event carries renders verbatim
in the page, and the page's own UI dictionary carries both languages, while
machine tokens (the rail's five `READY_FOR_*` stops, the verdict labels) stay
verbatim English — the shipped `templates/loop-replay.html` itself is
shipped surface, written in English like every other shipped file.

**Known limitation**: the mirror is guaranteed only on the **SKILL-driven path**
(`/shell-team:run`, `/goal`), where the orchestrator injects the directive. Invoking an
agent **directly / standalone** (`@engineer`, etc.) is **not guaranteed** to
mirror — the Bash-less `pm-spec` / `tech-lead` cannot self-resolve the
conversation language (no env, no config file by design). `codex-reviewer`
partially mitigates this by following its task-prompt language on a standalone
`/review`.

## Codex CLI quick-reference

```bash
# Version check — codex-reviewer and drift-evaluator each run this every round
# and transcribe its output into the verdict's `- Codex CLI:` line
codex --version

# Structured branch review (preferred, canonical form —
# top-level `codex review` has --base but no --json, so use the `review` subcommand under `codex exec`)
codex exec --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>

# Fallback when `codex review` is unavailable
codex exec --ephemeral --json "<prompt>"

# Adversarial second pass on suspect files
codex exec --ephemeral --json "Play devil's advocate on <file>. What could break this?"
```

## Conventions

- **Branches**: the engineer works directly on the task's feature branch (worktrees only when the orchestrator opts in for parallel implementations) — see `CONTRIBUTING.md` for this repository's naming convention
- **Specs**: `<specs dir>/T-XXX-<slug>.md`, slug = kebab-case of the title, where `<specs dir>` is `team-paths.sh --get specs` (on `PATH` when the plugin is loaded; else `bin/team-paths.sh`)
- **Review artifacts**: `<reviews dir>/T-XXX.md` (curated verdict + severity ledger) plus the raw Codex traces `<reviews dir>/T-XXX-codex-*.{txt,jsonl}`, where `<reviews dir>` is `team-paths.sh --get reviews` (on `PATH` when the plugin is loaded; else `bin/team-paths.sh`)
- **PR body diff stats** (file/line counts): take them from a fresh `git diff --stat <base>...HEAD` run at PR-creation time and re-measure just before merge — never transcribe them from the QA hand-off snapshot, because review-record and disposition commits land after QA and silently stale the numbers (observed in practice during a retro)
- **Never edit `.claude/agents/*` as part of a feature task** — that's team-config work and goes through its own task ID
