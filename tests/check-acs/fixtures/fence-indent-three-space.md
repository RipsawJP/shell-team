# Fixture — a three-space-indented backtick run DOES open a fence (T-1102 AC9)
#
# The positive control for fence-indent-four-space.md and fence-indent-tab.md:
# proves the indent bound genuinely discriminates rather than never opening
# on any indented line at all.

## Acceptance criteria

   ```
- [ ] **AC1** a three-space-indented run DOES open a fence, so this line must stay inert *(scriptable)*
  - check: exit 43
```

- [ ] **AC2** real criterion, unfenced *(scriptable)*
  - check: true
