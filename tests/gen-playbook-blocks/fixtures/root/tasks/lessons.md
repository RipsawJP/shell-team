# Lessons learned

Fixture lessons file for tests/gen-playbook-blocks.

## Format

```markdown
## YYYY-MM-DD — <short title>
- **Category**: <small closed taxonomy>
- **Applies-to**: <comma list from {engineer, qa-verifier, tech-lead, pm-spec, all}>
- **Scope**: <loop | maintainer>
- **Bound-in**: <repository-relative path — required if Scope is maintainer, forbidden if Scope is loop>
- **Status**: active | superseded
- **Source**: <task/issue/PR reference, an external citation, or n/a>
- **Rule**: <the takeaway, in one sentence>
- **Why**: <the incident or reasoning that led to it>
- **How to apply**: <where in the workflow this kicks in>
```

---

## 2026-01-01 — Engineer-only active entry
- **Category**: process
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Engineer rule one.
- **Why**: This full prose explanation must never appear in a generated block.
- **How to apply**: Neither must this full prose explanation.

## 2026-01-02 — All-roles active entry
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: All-roles rule two. T1007-LOOP-SENTINEL.
- **Why**: Why two.
- **How to apply**: How two.

## 2026-01-03 — Superseded entry (must be excluded from every block)
- **Category**: tooling-ci
- **Applies-to**: all
- **Scope**: loop
- **Status**: superseded
- **Source**: n/a
- **Rule**: Superseded rule three — must never appear in any generated block.
- **Why**: Why three.
- **How to apply**: How three.
- **Superseded-by**: 2026-01-02 — All-roles active entry

## 2026-01-04 — QA and tech-lead active entry
- **Category**: process
- **Applies-to**: qa-verifier, tech-lead
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: QA/tech-lead rule four.
- **Why**: Why four.
- **How to apply**: How four.

## 2026-01-05 — Maintainer-scoped all-roles entry (must never ship)
- **Category**: process
- **Applies-to**: all
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: n/a
- **Rule**: Maintainer rule five (T1007-MAINTAINER-SENTINEL).
- **Why**: This full prose explanation must never appear in a generated block.
- **How to apply**: Neither must this full prose explanation.
