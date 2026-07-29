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
#   4. A `## Retro inputs` section (T-1001, inverted at v2) is present and its
#      ledger is a CLOSED enum, validated fail-closed. This rule cannot report
#      "could not evaluate" as "clean": it produces exactly three outcomes that
#      never coincide — the section was located and its ledger validated; the
#      section is absent; or the section's heading is present but its ledger
#      region could not be read (the heading search and the region walk are
#      two INDEPENDENT determinations, cross-checked, so a future regression in
#      either one is caught as a disagreement rather than passing as clean).
#      When the region was read: every canonical id (cycle-window,
#      review-artifacts, provenance, specs, run-telemetry, previous-retro,
#      lessons, pr-metadata) must appear EXACTLY once, each with a status in
#      {read, empty, unavailable} and a detail that is non-empty AND not
#      whitespace-only. An id outside the enum, a status outside the enum, a
#      missing id, a duplicated id, an empty or whitespace-only detail, a
#      duplicated section heading, a ledger-shaped line found outside the
#      section, or any other unrecognised non-blank line inside the section
#      (indented sub-bullets carrying raw material are the only exemption) is
#      a violation.
#
# structure only: a retro whose ledger says 'read' is not thereby proven to have read anything.
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

# Canonical ids and statuses (single source: templates/prompt-blocks/retro-inputs.md;
# kept in sync across consumers by bin/check-prompt-sync.sh):
#   - input: cycle-window
#   - input: review-artifacts
#   - input: provenance
#   - input: specs
#   - input: run-telemetry
#   - input: previous-retro
#   - input: lessons
#   - input: pr-metadata
#   - status: read
#   - status: empty
#   - status: unavailable
#   empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.
RETRO_INPUTS='## Retro inputs'
RETRO_INPUTS_IDS="cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata"
RETRO_INPUTS_STATUSES="read empty unavailable"

violations=0
emit() { printf '%s:%s\n' "$1" "$2" >&2; violations=$((violations + 1)); }

# has_exact_line <line> <file> — CRLF-tolerant full-line exact match (a plain
# `grep -qxF` would miss a heading in a CRLF file, since grep treats a trailing
# CR as part of the line content). Used for rule 2's KPT/traps headings so
# their canonical string constants above stay untouched (AC17) while the
# comparison itself tolerates CRLF (T-1001 AC16's CRLF case).
has_exact_line() {
  awk -v want="$1" '{ sub(/\r$/, "", $0); if ($0 == want) { f=1; exit } } END { exit !f }' "$2"
}

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
  # blockquote does not satisfy the check). KPT match the whole line exactly
  # (CRLF-tolerant via has_exact_line); Lesson matches the `## Lesson 候補（`
  # prefix (its parenthetical names a path — grep -E's substring match is
  # already CR-tolerant since it has no end anchor).
  has_exact_line "$KEEP"    "$FILE" || emit "$FILE" "missing decorated section heading: $KEEP"
  has_exact_line "$PROBLEM" "$FILE" || emit "$FILE" "missing decorated section heading: $PROBLEM"
  has_exact_line "$TRY"     "$FILE" || emit "$FILE" "missing decorated section heading: $TRY"
  has_exact_line "$TRAPS"   "$FILE" || emit "$FILE" "missing decorated section heading: $TRAPS"
  grep -qE  -- "^## Lesson 候補（" "$FILE" || emit "$FILE" "missing decorated section heading: ${LESSON_PREFIX}…）"
  has_exact_line "$RETRO_INPUTS" "$FILE" || emit "$FILE" "missing decorated section heading: $RETRO_INPUTS"
  # Independent determination #1 for rule 4's agreement cross-check: found via
  # has_exact_line, the SAME CRLF-tolerant mechanism used above — untouched by
  # anything the rule-4 awk pass below does, so a regression confined to that
  # awk (e.g. its own CR handling regressing) cannot silently agree with itself.
  retro_inputs_heading_found=0
  has_exact_line "$RETRO_INPUTS" "$FILE" && retro_inputs_heading_found=1

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

  # Rule 4: the "## Retro inputs" ledger (T-1001, inverted at v2) — a CLOSED
  # enum, validated fail-closed with three outcomes that never coincide.
  #
  # Outcome determination: `retro_inputs_heading_found` (above) is ONE
  # independent determination (bash-level, CRLF-tolerant `has_exact_line`).
  # `region_entered` below is the SECOND, independent determination — the
  # awk pass's own record of whether it ever walked into the section. The two
  # are cross-checked at END: heading found but region never entered means
  # "the section heading is present but its ledger region could not be read"
  # — a violation in its own right, distinct from "absent" (heading not
  # found at all, already handled by has_exact_line above) and distinct from
  # "located and validated" (both agree the region was entered). This is what
  # makes a future regression in EITHER determination alone show up as a
  # disagreement instead of silently reading as clean (AC16/AC17).
  #
  # Only top-level `- input: ` lines inside the (first) entered region are
  # ledger entries; blank lines and indented sub-bullets (raw material — a
  # merge commit, a pull request) are ignored; any other non-blank line
  # inside the section is an "unrecognised line" violation. A ledger-shaped
  # `- input: ` line found OUTSIDE the walked region (before the heading, or
  # after the section has closed) is its own violation — a region walk that
  # stops early cannot leave entries silently unexamined. A second, duplicate
  # `## Retro inputs` heading is its own violation rather than a silently
  # unvalidated second region. Field extraction uses leftmost match() on the
  # ` — status: ` / ` — detail: ` markers (never a naive split on every
  # ` — `), so a detail that itself quotes the ledger grammar (e.g.
  # describing a past ledger line) is never miscounted as a malformed split
  # or a second ledger line. A detail of only whitespace is its own
  # violation, distinct from a wholly empty one: "a detail is present" and
  # "there are spaces there" are not the same determination.
  # shellcheck disable=SC2016  # backticks in the awk source are literal, not a subshell.
  inputs_violations="$(awk -v file="$FILE" -v ids="$RETRO_INPUTS_IDS" -v statuses="$RETRO_INPUTS_STATUSES" -v heading_found="$retro_inputs_heading_found" '
    BEGIN {
      nids = split(ids, idarr, " ")
      for (i = 1; i <= nids; i++) valid_id[idarr[i]] = 1
      nst = split(statuses, starr, " ")
      for (i = 1; i <= nst; i++) valid_status[starr[i]] = 1
      heading_count = 0
      region_entered = 0
      in_s = 0
    }
    {
      line = $0
      sub(/\r$/, "", line)

      if (line == "## Retro inputs") {
        heading_count++
        if (in_s) {
          in_s = 0                       # a second heading closes the currently-open region
        } else if (!region_entered) {
          in_s = 1
          region_entered = 1
        }
        next
      }

      if (in_s && line ~ /^## /) { in_s = 0 }

      if (in_s) {
        if (line == "") next
        if (line ~ /^  +- /) next        # indented sub-bullet: raw material, not parsed
        if (line !~ /^- input: /) {
          printf "%s:unrecognised line inside ## Retro inputs: %s\n", file, line > "/dev/stderr"
          n++
          next
        }
        body = line
        sub(/^- input: /, "", body)
        if (!match(body, / — status: /)) {
          printf "%s:malformed Retro inputs line (missing status field): %s\n", file, line > "/dev/stderr"
          n++
          next
        }
        id = substr(body, 1, RSTART - 1)
        rest = substr(body, RSTART + RLENGTH)
        if (!match(rest, / — detail: /)) {
          printf "%s:malformed Retro inputs line (missing detail field): %s\n", file, line > "/dev/stderr"
          n++
          next
        }
        st = substr(rest, 1, RSTART - 1)
        de = substr(rest, RSTART + RLENGTH)
        if (!(id in valid_id)) {
          printf "%s:unknown Retro inputs id: %s\n", file, line > "/dev/stderr"
          n++
        } else if (id in seen_id) {
          printf "%s:duplicated Retro inputs id: %s\n", file, line > "/dev/stderr"
          n++
        } else {
          seen_id[id] = 1
        }
        if (!(st in valid_status)) {
          printf "%s:unknown Retro inputs status: %s\n", file, line > "/dev/stderr"
          n++
        }
        trimmed = de
        gsub(/^[ \t]+|[ \t]+$/, "", trimmed)
        if (de == "") {
          printf "%s:empty Retro inputs detail: %s\n", file, line > "/dev/stderr"
          n++
        } else if (trimmed == "") {
          printf "%s:whitespace-only Retro inputs detail: %s\n", file, line > "/dev/stderr"
          n++
        }
      } else {
        if (line ~ /^- input: /) {
          printf "%s:ledger-shaped line outside the ## Retro inputs section: %s\n", file, line > "/dev/stderr"
          n++
        }
      }
    }
    END {
      if (heading_count >= 2) {
        printf "%s:duplicated ## Retro inputs section heading\n", file > "/dev/stderr"
        n++
      }
      if (heading_found == 1) {
        if (region_entered == 0) {
          printf "%s:## Retro inputs section heading is present but its ledger region could not be read\n", file > "/dev/stderr"
          n++
        } else {
          for (i = 1; i <= nids; i++) {
            if (!(idarr[i] in seen_id)) {
              printf "%s:missing Retro inputs id: %s\n", file, idarr[i] > "/dev/stderr"
              n++
            }
          }
        }
      }
      print n + 0
    }
  ' "$FILE")"
  violations=$((violations + inputs_violations))
done

[[ "$violations" -gt 0 ]] && exit 1
exit 0
