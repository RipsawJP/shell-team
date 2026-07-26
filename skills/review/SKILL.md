---
description: Run the codex-reviewer on the current branch (skips PM/Engineer/QA — just the cross-provider review)
---

Invoke the `codex-reviewer` sub-agent on the current branch's diff against `origin/main`. Use this when you want a quick second opinion without going through the full team pipeline (e.g., reviewing someone else's PR, or sanity-checking a manual change).

Pass through any extra focus from the user if provided:

$ARGUMENTS
