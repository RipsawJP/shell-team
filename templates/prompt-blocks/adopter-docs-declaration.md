- user-visible: yes — <rationale>
- user-visible: no — <rationale>
A `yes` declaration additionally requires either an indented `- adopter-surface: <where the adopter-facing documentation lands>` line under an acceptance criterion or a top-level `- adopter-docs-waiver: <why this user-visible capability has no adopter-docs surface>` line — never both, and never either one beside a `no`.
A `yes` declaration additionally requires one or more unindented `- shipped-docs: <repo-relative path> — this-task | issue #<N>` lines: each shipped document the spec's own prose names as changing gets its own line, dispositioned `this-task` when this task's diff edits it or `issue #<N>` when the update is deliberately deferred to a filed follow-up — never beside a `no`.
