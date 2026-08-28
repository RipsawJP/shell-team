# Example oversight-approval record (T-1103)

This fixture exists so `bin/team-paths.sh`-independent tooling (AC13's own
positive control) can confirm the anchored record-grammar pattern
`^[[:space:]]*- oversight-approval \(` actually matches real content
somewhere under `tests/check-oversight/`, rather than matching nothing
everywhere. This is not read by `run.sh`; it is a static, committed,
line-start example of the grammar `bin/check-oversight.sh` itself scans
for.

  - oversight-approval (specify-seam): approver=reviewer-01 — producer=author-02 — approves=v1 — date=2026-08-27 — record=docs/specs/example.md
