<!-- BEGIN interventions: no-task -->
- intervention: human-stop
  date: 2026-08-13
  summary: The operator said "stop for now" between tasks - T-1063 had just closed out (PR #261, both gates green) and its CI retrigger (empty commit `1b56c7c`, after the runner-side retro-inputs suite failure that reproduces green locally on byte-unchanged code) had been pushed; T-1064 had not been opened.
  effect: The CI-conclusion monitor was stopped (the GitHub-side run completes on its own; its verdict is unread), no agent was running, T-1064 was not started. Open item carried to resumption - read PR #261's re-run CI conclusion; if it fails again deterministically, the log body needs the host's gh run view --log-failed (sandbox-closed path) before T-1064 proceeds on the train.
- intervention: human-interrupt
  date: 2026-08-20
  summary: During T-1086's Specify phase (pm-spec running; no T-1086 board entry existed yet, so this lands in no-task), the operator reported that the dispatcher-sprint retro promotion PR #330 (chore/lessons-2026-08-20, the sprint train head) has a red CI check.
  effect: The orchestrator turned to verify the claim read-only and diagnose/fix the train head before stacking further work on it; T-1086's Specify phase continued uninterrupted in parallel. T-1086's branch is stacked on #330's tip fe31285, so a fix commit on the train head will require re-stacking feature/1086-subject-harness before its freeze.
<!-- END interventions: no-task -->
