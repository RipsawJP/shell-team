# Fixture spec — all scriptable ACs pass, one runtime AC skipped

## Acceptance criteria

- [ ] **AC1** trivially true scriptable check *(scriptable)*
  - check: true
- [ ] **AC2** a runtime AC with no check: *(runtime — user dogfood)*
- [ ] **AC3** a real read-only check from the repo root *(scriptable)*
  - check: test -x bin/check-acs.sh
