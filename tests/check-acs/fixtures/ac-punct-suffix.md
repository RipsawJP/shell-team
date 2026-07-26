# Fixture — a number glued by ASCII word-continuation punctuation is NOT an AC (T-089 / #295)

## Acceptance criteria

- [ ] **AC1_foo** underscore-glued — must be rejected *(scriptable)*
  - check: true
- [ ] **AC1:foo** colon-glued — must be rejected *(scriptable)*
  - check: true
- [ ] **AC1.foo** period-glued — must be rejected *(scriptable)*
  - check: true
- [ ] **AC1-foo** hyphen-glued — must be rejected *(scriptable)*
  - check: true
