<!-- BEGIN interventions: no-task -->
- intervention: human-stop
  date: 2026-08-13
  summary: The operator said "stop for now" between tasks - T-1063 had just closed out (PR #261, both gates green) and its CI retrigger (empty commit `1b56c7c`, after the runner-side retro-inputs suite failure that reproduces green locally on byte-unchanged code) had been pushed; T-1064 had not been opened.
  effect: The CI-conclusion monitor was stopped (the GitHub-side run completes on its own; its verdict is unread), no agent was running, T-1064 was not started. Open item carried to resumption - read PR #261's re-run CI conclusion; if it fails again deterministically, the log body needs the host's gh run view --log-failed (sandbox-closed path) before T-1064 proceeds on the train.
- intervention: human-interrupt
  date: 2026-08-20
  summary: During T-1086's Specify phase (pm-spec running; no T-1086 board entry existed yet, so this lands in no-task), the operator reported that the dispatcher-sprint retro promotion PR #330 (chore/lessons-2026-08-20, the sprint train head) has a red CI check.
  effect: The orchestrator turned to verify the claim read-only and diagnose/fix the train head before stacking further work on it; T-1086's Specify phase continued uninterrupted in parallel. T-1086's branch is stacked on #330's tip fe31285, so a fix commit on the train head will require re-stacking feature/1086-subject-harness before its freeze.
- intervention: assumption-contradicted
  date: 2026-09-02
  summary: Sprint r3-body planning, before any board task existed. The coordinating session's briefing to tech-lead cited `docs/loop-engineering/plugin-role-agent-concurrency.md` as recording that whether a plugin role's model binding can be overridden at launch is `unobserved`. tech-lead re-read the source: that note leaves the model actually bound `unobserved` (a model-identity claim) and names other model bindings as out of scope — it does not measure launch-time overridability; the in-repo record of that question is `.shell-team/provenance/T-1057.md` and T-1057's DP6.
  effect: The conclusion (the capability is unestablished) stood; the citation was wrong. Recorded as a live instance of the precedent-citation lesson promoted the same day, and carried into the T-1116 probe issue (#418) with the correct primary source. A second briefing premise — that the Agent tool exposes a `model` parameter — was labelled relayed by tech-lead and confirmed first-hand by the coordinating session from the tool schema (enum sonnet/opus/haiku/fable; no effort parameter).
<!-- END interventions: no-task -->
