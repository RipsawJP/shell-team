# Fixture — a tab-indented backtick run opens no fence (T-1102 AC9)
#
# CommonMark counts a leading tab as column 4, so a tab-indented backtick run
# must NOT open a fence (unlike three literal spaces, see
# fence-indent-three-space.md) — this is the sibling checker's round-2 Major
# regression lock, ported here.

## Acceptance criteria

	```
- [ ] **AC1** a tab-indented run opens no fence, so this line IS recognized *(scriptable)*
  - check: true
