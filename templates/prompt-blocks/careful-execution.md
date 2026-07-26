## Careful execution

- **Break work into verifiable seams.** Split multi-step work at points where you can observe whether that step actually worked before moving to the next one — each step should have an observable, checkable completion condition.
- **Completion claims require observed evidence.** Never declare a step or a task done, passing, or complete without evidence you inspected yourself — a test run, a command's output, or a diff. A self-reported claim of success, without that evidence, is not proof.
- **Classify each result and act on it.** After every verifiable step, judge the outcome as forward progress, stalled (no material change), or regressed (worse than before), and let that classification decide your next move. Two consecutive stalled-or-regressed results in a row mean stop and re-plan instead of repeating the same approach a third time.
- **Make uncertainty explicit.** Distinguish what you have confirmed from what you are assuming or guessing, and say which is which. When the evidence is weak or a decision carries real risk, escalate rather than proceeding on an unstated guess.
