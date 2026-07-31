# Lessons learned

Append-only log of corrections and validated approaches. Read at session start.

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

## 2026-01-01 — First entry
- **Category**: process
- **Applies-to**: engineer
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Rule one.
- **Why**: Why one.
- **How to apply**: How one.

## 2026-01-02 — Second entry (superseded)
- **Category**: tooling-ci
- **Applies-to**: qa-verifier, tech-lead
- **Scope**: loop
- **Status**: superseded
- **Source**: T-999
- **Rule**: Rule two.
- **Why**: Why two.
- **How to apply**: How two.
- **Superseded-by**: 2026-01-03 — Third entry (applies to all)

## 2026-01-03 — Third entry (applies to all)
- **Category**: verification-discipline
- **Applies-to**: all
- **Scope**: loop
- **Status**: active
- **Source**: n/a
- **Rule**: Rule three.
- **Why**: Why three.
- **How to apply**: How three.
- **Extended by**: an unrelated free-text note (T-108: field name is recognized, value is never schema-checked).

## 2026-01-04 — Fourth entry (maintainer-scoped)
- **Category**: process
- **Applies-to**: all
- **Scope**: maintainer
- **Bound-in**: CONTRIBUTING.md
- **Status**: active
- **Source**: T-1007 test
- **Rule**: Rule four.
- **Why**: Why four.
- **How to apply**: How four.
