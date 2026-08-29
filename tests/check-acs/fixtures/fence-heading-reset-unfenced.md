# Fixture — positive control for fence-heading-reset.md: same heading, fence lines removed (T-1102 AC3b)
#
# This is the pre-change behaviour: an UNFENCED "## " heading between an AC
# line and its intended check: line DOES sever the attribution, so AC1 stays
# SKIP here — proving the heading reset itself is still live for unfenced
# headings.

## Acceptance criteria

- [ ] **AC1** criterion separated from its check: line by an unfenced heading *(scriptable)*

## Unfenced heading — resets the current AC

  - check: true
