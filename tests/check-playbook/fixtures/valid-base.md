# Lessons learned

Append-only log of corrections and validated approaches. Read at session start.

## Format

```markdown
## YYYY-MM-DD — <short title>
- **Category**: <small closed taxonomy>
- **Applies-to**: <comma list from {engineer, qa-verifier, tech-lead, pm-spec, all}>
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
- **Status**: active
- **Source**: n/a
- **Rule**: Rule one.
- **Why**: Why one.
- **How to apply**: How one.

## 2026-01-02 — Second entry (superseded)
- **Category**: tooling-ci
- **Applies-to**: qa-verifier, tech-lead
- **Status**: superseded
- **Source**: T-999
- **Rule**: Rule two.
- **Why**: Why two.
- **How to apply**: How two.
- **Superseded-by**: 2026-01-03 — Third entry (applies to all)

## 2026-01-03 — Third entry (applies to all)
- **Category**: verification-discipline
- **Applies-to**: all
- **Status**: active
- **Source**: n/a
- **Rule**: Rule three.
- **Why**: Why three.
- **How to apply**: How three.
- **Extended by**: an unrelated free-text note (T-108: field name is recognized, value is never schema-checked).
