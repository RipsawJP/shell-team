# Tasks

## Active

- [ ] **T-501** alpha task in flight — `READY_FOR_ARCH` — spec: docs/specs/t-501.md

## Done

- [x] **T-071** done alpha — `READY_FOR_MERGE` — spec: docs/specs/t-071.md

## Format

Example showing a common closing mistake (a fence "closer" line with trailing content after the backticks does NOT actually close the fence per CommonMark — only whitespace may follow the backtick run):

```markdown
some fence content line 1
```payload-not-a-real-close
## Active

- [ ] **T-502** phantom example — still meant to be fence CONTENT, since the line above has trailing content after the backticks and must NOT close the fence — spec: docs/specs/example.md
```
