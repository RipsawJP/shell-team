# History — how shell-team evolved

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=flat-square)](history.md)
[![日本語](https://img.shields.io/badge/lang-日本語-lightgrey?style=flat-square)](history.ja.md)

This page tells the story of how shell-team evolved from a single-pass agent template into a Spec-Driven, cross-provider-reviewed development loop with its own operating discipline. For a bullet-by-bullet release log see [CHANGELOG.md](../CHANGELOG.md); this page is the narrative behind it.

## Bootstrap (2026-04-29)

shell-team started life as a template repo bootstrapped on 2026-04-29: a single-pass pipeline (a Tech Lead orchestrator, PM, Engineer, QA, plus a lightweight review step) distributed by copying files into each adopting repo. There was no plugin, no shared marketplace, and no operating loop wrapped around the pipeline itself — just the hand-off contract between agents.

## Becoming a plugin, and Evolving toward Loop Engineering (v0.1.0)

The project's first big pivot moved it from "files you copy into a repo" to a proper Claude Code **plugin**: install once, use in every repo, with the team's agents, skills, and helper scripts staying centrally maintained. Alongside that pivot, the project set itself a longer-range direction — its README tagline read "**Evolving toward Loop Engineering**": not just an agent pipeline, but an *outer loop* of operating discipline wrapped around it, with explicit BUDGET/STOP guards, telemetry, and — down the road — per-step model routing and a self-paced runtime loop. This chapter carried the working label **Loop Engineering (v0.1.0)**: the agent pipeline was treated as the **inner loop**, and this release wrapped it with the first outer-loop primitives — loop contracts (declaring TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT, linted by a dedicated checker), a runtime guardrail enforcing BUDGET/STOP as a fail-closed kill-switch, per-phase telemetry, and an opt-in, read-only triage skill that only ever proposes work rather than editing the board. At the time, model routing and a run-roll-up mechanism were still on the roadmap; both later shipped as the v0.2.x line matured.

## Footprint consolidation (v0.2.0) and deepening the loop (v0.2.x)

v0.2.0 consolidated every per-repo operating file under a single base directory instead of scattering across the host repo's tree, and stopped touching the host's own configuration files — a stable baseline that the v0.2.x line then spent deepening: loop-contract metadata, the operating "traps" turned into explicit discipline, a cross-tool state file so any assistant (not just Claude) could find the team's working state, and a self-paced runtime loop that drives a single task to completion on its own cadence, bounded by the same guardrails as the full team loop. Over the v0.2.x line the project also added conversation-language mirroring, cross-run failure clustering, a structured and machine-validated lessons playbook that regenerates per-role prompt digests, model-tier realignment as new model generations became available, a hybrid review-response workflow for triaging feedback that comes back on a PR, and a growing adversarial-fixture discipline for QA. A parallel-distribution mechanism distributed two release lines (a stable line and a pre-release next-major line) in parallel under one plugin name while the next major line was under development, while keeping installs mutually exclusive — an adopter got one line or the other, selected by which marketplace ref they used.

## The Oversight-model evolution (v0.3.0)

The v0.3.0 line asked a harder question: as the team's own output grows, does completion still have to depend on one specific human continuously reading every line the team generates? v0.3.0 moved the completion gate's core contract from *sustained human comprehension* to *mechanically-grounded knowledge plus an independent, cross-provider AI evaluator* — while keeping a human as the out-of-distribution exception circuit-breaker for anything the evaluator can't ground. It shipped in five stages: an oversight doctrine naming the new failure mode this shift has to guard against (a team confidently agreeing with itself); a frozen-intent mechanism that hash-pins a task's goal and acceptance criteria so later drift is mechanically detectable; a decision-provenance record so non-trivial implementation choices carry their own reasoning and grounding; an independent drift/alignment evaluator that only escalates to a human when something doesn't check out; and, finally, moving the team's own retrospective process from "human, please answer these questions" to the retrospective agent directly reading the evidence and attesting to it itself. Autonomy stayed deliberately conservative through all of this: every merge still keeps its human "go" — the evaluator informs that decision, it does not replace it.

## Status

v0.3.0 is the current release line. The project keeps its board, specs, and reviews under version control so both the operating history and the reasoning behind it stay inspectable, not just the code.
