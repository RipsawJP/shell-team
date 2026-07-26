# Fixture spec — hyphenated **AC-N — title.** numbering (T-088 / #286)

Modeled on T-085's real convention
(`docs/specs/T-085-rename-shell-team.md`): the bold wraps the WHOLE title, so
the closing `**` falls AFTER the title, not right after the digits — this is
the shape that defeated both the original regex and the merely-hyphen-optional
`AC-?([0-9]+)\*\*` regex.

## Acceptance criteria

- [ ] **AC-1 — some title.** a hyphenated scriptable AC with a passing check,
  bold wrapping the whole title (T-085 style) *(scriptable)*
  - check: true
- [ ] **AC-2 — another title.** a hyphenated runtime AC with no check:,
  bold wrapping the whole title (T-085 style) *(runtime)*
