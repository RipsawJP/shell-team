#!/usr/bin/env bash
# run.sh — tests/machine-tokens/run.sh (T-1010 D4).
#
# The machine-token vocabulary enumerated by issue #20 — status flags,
# verdict labels, the board-line format, intent-block tokens, prompt-block
# markers, lesson labels, and the retro contract tokens/markers — used to be
# trusted to prose. This suite asserts, per group, that each token appears
# verbatim in the file that actually consumes/enforces it, so a future drift
# is caught as a test failure rather than discovered by hand.
#
# `bin/check-playbook.sh` deliberately does NOT carry the lesson labels — the
# shipped lessons corpus uses the `Category` / `Scope` schema instead
# (measured, not assumed) — so it is not asserted here.
#
# Usage: run.sh [--root DIR]   (default: repo root, i.e. this suite's own
#        checkout — pass --root to point it at a scratch copy instead, e.g.
#        for a mutation self-check).
# Exit: 0 = every token present; 1 = a token is missing (drift); 2 = usage /
#       a registered consumer file could not be read (fail closed — never a
#       silent pass).

set -euo pipefail

die() { printf 'machine-tokens: %s\n' "$1" >&2 || true; exit 2; }

ROOT="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --help|-h) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"

violations=0
emit() { printf 'machine-tokens: %s\n' "$1" >&2; violations=$((violations + 1)); }

# assert_token <consumer-relative-path> <token> — literal substring; fail
# closed (exit 2) when the consumer file cannot be read at all, so a missing
# file never reads as a silent pass.
assert_token() {
  local rel="$1" tok="$2" path="$ROOT/$1"
  [ -r "$path" ] || die "cannot read consumer file: $rel"
  grep -qF -- "$tok" "$path" || emit "$rel: missing token: $tok"
}

# --- status flags: bin/check-handoff.sh + templates/prompt-blocks/flag-enum.md
for t in READY_FOR_ARCH READY_FOR_ENG READY_FOR_QA READY_FOR_REVIEW READY_FOR_MERGE BLOCKED REWORK; do
  assert_token bin/check-handoff.sh "$t"
  assert_token templates/prompt-blocks/flag-enum.md "$t"
done

# --- verdict labels: bin/goal-state.sh + templates/prompt-blocks/verdict-labels.md
for t in PASS FAIL APPROVE REQUEST_CHANGES; do
  assert_token bin/goal-state.sh "$t"
  assert_token templates/prompt-blocks/verdict-labels.md "$t"
done

# --- board-line format: every non-empty line of the canonical block must
# appear verbatim in bin/check-handoff.sh (the checker that enforces it).
BLF_PATH="$ROOT/templates/prompt-blocks/board-line-format.md"
[ -r "$BLF_PATH" ] || die "cannot read canonical block: templates/prompt-blocks/board-line-format.md"
while IFS= read -r line; do
  line="${line%$'\r'}"
  [ -n "$line" ] || continue
  assert_token bin/check-handoff.sh "$line"
done < "$BLF_PATH"

# --- intent-block tokens: bin/check-intent.sh
for t in 'intent-block' 'intent-hash' 'intent-ratified' \
         '<!-- BEGIN intent-block:' '<!-- END intent-block:'; do
  assert_token bin/check-intent.sh "$t"
done

# --- prompt-block markers: bin/check-prompt-sync.sh
for t in '<!-- BEGIN prompt-block:' '<!-- END prompt-block:'; do
  assert_token bin/check-prompt-sync.sh "$t"
done

# --- lesson labels: bin/check-retro.sh + agents/scrum-master.md only.
for t in '[common]' '[target-specific]'; do
  assert_token bin/check-retro.sh "$t"
  assert_token agents/scrum-master.md "$t"
done

# --- retro contract tokens (structure + T-1010 section markers): bin/check-retro.sh
for t in '# Retro' '## Retro inputs' '- input: ' \
         '<!-- retro-section: keep -->' '<!-- retro-section: problem -->' \
         '<!-- retro-section: try -->' '<!-- retro-section: traps -->' \
         '<!-- retro-section: lessons -->' '- (none)'; do
  assert_token bin/check-retro.sh "$t"
done

if [ "$violations" -gt 0 ]; then
  printf 'machine-tokens: %d violation(s)\n' "$violations" >&2 || true
  exit 1
fi
printf 'machine-tokens: all tokens present in their consuming files\n'
exit 0
