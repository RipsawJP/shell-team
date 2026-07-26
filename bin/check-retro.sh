#!/usr/bin/env bash
# check-retro.sh — lint scrum-master retro files against their structural contract.
#
# Validates each tasks/retros/*.md given on the command line:
#   1. The first non-empty line is the H1 `# Retro <...>`.
#   2. All five decorated H2 sections are present, verbatim (bare forms rejected):
#        ## Keep（続けたい良い動き）
#        ## Problem（直面した課題 / 痛み）
#        ## Try（次サイクルで試すこと）
#        ## 罠の点検（Comprehension Debt / Cognitive Surrender）
#        ## Lesson 候補（…）          (matched by the `## Lesson 候補（` prefix)
#      The 罠の点検 (loop-trap self-check) section is mandatory by design: the
#      Comprehension Debt / Cognitive Surrender traps are exactly the reflection
#      that gets skipped when convenient, so the linter forbids skipping it.
#      See docs/loop-engineering/loop-traps.md.
#   3. Every top-level bullet under `## Lesson 候補（…）` starts with a label
#      `` `[common]` `` or `` `[target-specific]` `` (backtick-wrapped, as the
#      template and canonical retro write them). A lone `- (該当なし)`
#      placeholder is allowed. Bare/unlabelled bullets are a violation.
#
# This makes the retro structure — currently only described in the scrum-master
# agent prompt and docs/templates/retro-template.md — mechanically enforceable,
# so a prompt drift is caught in CI rather than silently shipping a malformed retro.
#
# Reads only. Pure bash + coreutils (awk/grep) — no jq/yq/python. Prints
# `<file>:<reason>` per violation to stderr.
#
# Usage:  check-retro.sh <retro.md> [<retro.md>...]
# Exit:   0 = all clean, 1 = violation(s), 2 = usage / unreadable file.

set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  printf 'usage: check-retro.sh <retro.md> [<retro.md>...]\n' >&2 || true
  exit 2
fi

# The five decorated H2 headings. KPT and 罠の点検 are fixed contract strings;
# the Lesson heading is matched by prefix because its parenthetical names a path.
KEEP='## Keep（続けたい良い動き）'
PROBLEM='## Problem（直面した課題 / 痛み）'
TRY='## Try（次サイクルで試すこと）'
TRAPS='## 罠の点検（Comprehension Debt / Cognitive Surrender）'
LESSON_PREFIX='## Lesson 候補（'

violations=0
emit() { printf '%s:%s\n' "$1" "$2" >&2; violations=$((violations + 1)); }

for FILE in "$@"; do
  if [[ ! -r "$FILE" ]]; then
    printf '%s: cannot read file\n' "$FILE" >&2 || true
    exit 2
  fi

  # Rule 1: first non-empty line is the H1 `# Retro <...>` with a non-empty title.
  first="$(awk 'NF { print; exit }' "$FILE")"
  first="${first%$'\r'}"
  if [[ ! "$first" =~ ^#\ Retro\ +[^[:space:]] ]]; then
    emit "$FILE" "first non-empty line is not '# Retro <non-empty title>' (got: ${first:-<empty file>})"
  fi

  # Rule 2: the four decorated H2 sections are present *as headings* (anchored to
  # line start, not a substring — so the decorated text appearing in prose / a
  # blockquote does not satisfy the check). KPT match the whole line exactly;
  # Lesson matches the `## Lesson 候補（` prefix (its parenthetical names a path).
  grep -qxF -- "$KEEP"    "$FILE" || emit "$FILE" "missing decorated section heading: $KEEP"
  grep -qxF -- "$PROBLEM" "$FILE" || emit "$FILE" "missing decorated section heading: $PROBLEM"
  grep -qxF -- "$TRY"     "$FILE" || emit "$FILE" "missing decorated section heading: $TRY"
  grep -qxF -- "$TRAPS"   "$FILE" || emit "$FILE" "missing decorated section heading: $TRAPS"
  grep -qE  -- "^## Lesson 候補（" "$FILE" || emit "$FILE" "missing decorated section heading: ${LESSON_PREFIX}…）"

  # Rule 3: every top-level bullet in the Lesson 候補 section is labelled.
  # Extract the section body (between the Lesson heading and the next `## `)
  # and validate each `- ` top-level bullet in the SAME awk pass that reads
  # $FILE directly — no here-string / temp-file dependency (D-a), so this
  # check cannot be silently skipped when temp-file creation is unavailable.
  # `> ` blockquote lines and indented sub-bullets are ignored;
  # `- (該当なし)` is the allowed empty placeholder. awk prints one reason
  # line per violation to stderr and its violation count to stdout; the
  # parent shell folds that count into `violations` (looping over awk's
  # output in a `| while` subshell would lose the increment instead).
  # shellcheck disable=SC2016  # backticks in the awk source are literal label syntax, not a subshell.
  lesson_violations="$(awk -v file="$FILE" '
    /^## Lesson 候補（/ && !seen { seen=1; in_s=1; next }
    in_s && /^## / { in_s=0 }
    in_s {
      line = $0
      sub(/\r$/, "", line)
      if (substr(line, 1, 2) != "- ") next            # only top-level bullets
      if (line == "- (該当なし)") next                 # allowed empty placeholder
      common = "- `[common]`"
      target = "- `[target-specific]`"
      if (substr(line, 1, length(common)) == common) next
      if (substr(line, 1, length(target)) == target) next
      printf "%s:unlabelled Lesson 候補 bullet (need `[common]` or `[target-specific]`): %s\n", file, line > "/dev/stderr"
      n++
    }
    END { print n + 0 }
  ' "$FILE")"
  violations=$((violations + lesson_violations))
done

[[ "$violations" -gt 0 ]] && exit 1
exit 0
