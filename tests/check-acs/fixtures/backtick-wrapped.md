# Fixture spec — reproduces T-046 spec's rework1-before format: an AC's
# check: line fully wrapped in a single outer backtick pair (T-048, #126)

## Acceptance criteria

- [ ] **AC1** a check: value fully wrapped in an outer backtick pair, whose
      underlying command genuinely passes when run raw *(scriptable)*
  - check: `true && echo "check-playbook: all entries valid"`
