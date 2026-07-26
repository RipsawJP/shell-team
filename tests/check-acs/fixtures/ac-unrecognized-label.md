# Fixture — unrecognized AC label lines are surfaced, not silently dropped (T-110)

This fixture mixes two well-formed AC lines with two unrecognized ones (a
digit-glued suffix and a punctuation-glued suffix), in this exact order, so
the DP-6 misattribution regression (a `check:` under an unrecognized line
being absorbed by the PRECEDING recognized AC) has something real to attach
to right after AC2.

## Acceptance criteria

- [ ] **AC1** a well-formed scriptable AC *(scriptable)*
  - check: true
- [ ] **AC2** a well-formed runtime AC, no check: sub-bullet *(runtime)*
- [ ] **AC19b** unrecognized — a digit run glued to more letters (T-108's real incident shape) *(scriptable)*
  - check: touch "$T110_UNRECOGNIZED_SENTINEL"
- [ ] **AC1_foo** unrecognized — a digit run glued by an ASCII word-continuation punctuation *(scriptable)*
  - check: touch "$T110_UNRECOGNIZED_SENTINEL"
