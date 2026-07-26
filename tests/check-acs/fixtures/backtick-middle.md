# Fixture spec — a check: value containing a LEGITIMATE backtick in the
# MIDDLE of an otherwise-unwrapped command must NOT be rejected (AC4
# regression negative case, matching docs/specs/T-037-review-response.md's
# real shape: a regex alternation matching literal backticks in prose)

## Acceptance criteria

- [ ] **AC1** a check: value with a backtick in the middle, not wrapping the
      whole command *(scriptable)*
  - check: echo 'auto`escalate`reject' | grep -qE '`?auto`?'
