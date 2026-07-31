#!/usr/bin/env bash
# check-retro.sh — lint scrum-master retro files against their structural contract.
#
# Validates each tasks/retros/*.md given on the command line:
#   1. The first non-empty line is the H1 `# Retro <...>`.
#   2. Five sections — ids keep, problem, try, traps, lessons, in that
#      canonical order — are each anchored on a language-neutral marker
#      (T-1010, single source: templates/prompt-blocks/retro-sections.md):
#        <!-- retro-section: keep -->
#        <!-- retro-section: problem -->
#        <!-- retro-section: try -->
#        <!-- retro-section: traps -->
#        <!-- retro-section: lessons -->
#      A marker's frozen form is a line whose entire content, after stripping
#      a trailing CR and trailing whitespace, is EXACTLY `<!-- retro-section:
#      <id> -->` — no leading whitespace, no blockquote prefix, no other text
#      on the line (so a marker string quoted in prose, indented under a list
#      item, or reflowed under a `> ` blockquote does not satisfy the rule).
#      The heading text beside each marker is free — any language, any
#      wording, with or without a parenthetical — because the contract is the
#      marker, never the heading string. This is the whole point of T-1010:
#      an adopter who never writes a word of the maintainer's language still
#      satisfies this checker. Each marker must be immediately followed (the
#      next non-blank line) by an H2 heading with a non-empty title, so a
#      marker floating in prose anchors nothing. Missing / duplicated /
#      out-of-order markers are each a violation, and the traps
#      (loop-trap self-check) marker is mandatory by design: the
#      Comprehension Debt / Cognitive Surrender traps are exactly the
#      reflection that gets skipped when convenient, so the linter forbids
#      skipping it. See docs/loop-engineering/loop-traps.md.
#   3. Every top-level bullet under the `lessons` section (the heading right
#      after the `<!-- retro-section: lessons -->` marker) starts with a
#      label `` `[common]` `` or `` `[target-specific]` `` (backtick-wrapped,
#      as the template and canonical retro write them). A lone `- (none)`
#      placeholder is the only allowed empty-section token — it is the
#      shipped, English machine token; any other lone bullet (including a
#      translated placeholder) is an unlabelled bullet and a violation.
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
#      lessons, pr-metadata, interventions) must appear EXACTLY once, each with a
#      status in {read, empty, unavailable} and a detail that is non-empty AND
#      not whitespace-only. An id outside the enum, a status outside the
#      enum, a missing id, a duplicated id, an empty or whitespace-only
#      detail, a duplicated section heading, a ledger-shaped line found
#      outside the section, or any other unrecognised non-blank line inside
#      the section (indented sub-bullets carrying raw material are the only
#      exemption) is a violation.
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

# The five canonical section ids, in canonical order (single source:
# templates/prompt-blocks/retro-sections.md). Each is anchored on its own
# language-neutral marker line:
#   <!-- retro-section: keep -->
#   <!-- retro-section: problem -->
#   <!-- retro-section: try -->
#   <!-- retro-section: traps -->
#   <!-- retro-section: lessons -->
# Empty-section placeholder (the only allowed lone bullet under `lessons`
# when there is genuinely nothing to propose): - (none)
RETRO_SECTION_IDS="keep problem try traps lessons"

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
#   - input: interventions
#   - status: read
#   - status: empty
#   - status: unavailable
#   empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.
RETRO_INPUTS='## Retro inputs'
RETRO_INPUTS_IDS="cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions"
RETRO_INPUTS_STATUSES="read empty unavailable"

violations=0
emit() { printf '%s:%s\n' "$1" "$2" >&2; violations=$((violations + 1)); }

# has_exact_line <line> <file> — CRLF-tolerant full-line exact match (a plain
# `grep -qxF` would miss a heading in a CRLF file, since grep treats a trailing
# CR as part of the line content). Used for rule 4's `## Retro inputs` heading
# so the comparison tolerates CRLF (T-1001 AC16's CRLF case).
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

  # Rule 4's independent determination #1 (used at END below): found via
  # has_exact_line, the SAME CRLF-tolerant mechanism used for that rule's own
  # awk pass — untouched by anything rule 2/3's marker walk does.
  retro_inputs_heading_found=0
  has_exact_line "$RETRO_INPUTS" "$FILE" && retro_inputs_heading_found=1
  has_exact_line "$RETRO_INPUTS" "$FILE" || emit "$FILE" "missing section heading: $RETRO_INPUTS"

  # Rules 2 and 3: language-neutral section markers, and the lessons label
  # rule keyed off the `lessons` marker's section body. Both need whole-file
  # random access (order across the file, next-non-blank-line lookahead,
  # section-body boundaries), so the whole file is read into an array once
  # and every determination is made in the END block of a single awk pass —
  # no here-string / temp-file dependency (T-087 D-a discipline).
  # shellcheck disable=SC2016  # backticks in the awk source are literal label syntax, not a subshell.
  marker_violations="$(awk -v file="$FILE" -v ids="$RETRO_SECTION_IDS" '
    { raw = $0; sub(/\r$/, "", raw); lines[NR] = raw }
    END {
      n = NR
      nids = split(ids, order, " ")
      for (i = 1; i <= nids; i++) rank[order[i]] = i

      # --- locate marker lines: strict, anchored at column 1, no leading
      # whitespace tolerated, trailing whitespace trimmed before comparison.
      noccur = 0
      for (ln = 1; ln <= n; ln++) {
        trimmed = lines[ln]
        sub(/[ \t]+$/, "", trimmed)
        if (trimmed ~ /^<!-- retro-section: [A-Za-z0-9_-]+ -->$/) {
          id = trimmed
          sub(/^<!-- retro-section: /, "", id)
          sub(/ -->$/, "", id)
          if (id in rank) {
            count[id]++
            if (!(id in firstline)) firstline[id] = ln
            noccur++
            occ_line[noccur] = ln
            occ_id[noccur] = id
          }
        }
      }

      # --- missing / duplicated markers.
      for (i = 1; i <= nids; i++) {
        sid = order[i]
        if (count[sid] == 0) {
          printf "%s:missing section marker <!-- retro-section: %s -->\n", file, sid > "/dev/stderr"
          n_v++
        } else if (count[sid] > 1) {
          printf "%s:duplicated section marker <!-- retro-section: %s -->\n", file, sid > "/dev/stderr"
          n_v++
        }
      }

      # --- canonical order, checked over each ids first occurrence, sorted
      # by line number (insertion sort — at most 5 elements).
      m = 0
      for (sid in firstline) { m++; fl_id[m] = sid; fl_line[m] = firstline[sid] }
      for (a = 2; a <= m; a++) {
        keyid = fl_id[a]; keyline = fl_line[a]; b = a - 1
        while (b >= 1 && fl_line[b] > keyline) {
          fl_line[b + 1] = fl_line[b]; fl_id[b + 1] = fl_id[b]; b--
        }
        fl_line[b + 1] = keyline; fl_id[b + 1] = keyid
      }
      prev_rank = 0
      out_of_order = 0
      bad_id = ""
      for (a = 1; a <= m; a++) {
        r = rank[fl_id[a]]
        if (r < prev_rank) { out_of_order = 1; bad_id = fl_id[a] }
        if (r > prev_rank) prev_rank = r
      }
      if (out_of_order) {
        printf "%s:retro-section: %s out of order (markers must appear in canonical order: keep, problem, try, traps, lessons)\n", file, bad_id > "/dev/stderr"
        n_v++
      }

      # --- each marker occurrence must be immediately followed (next
      # non-blank line) by an H2 heading with a non-empty title.
      lessons_heading_ln = 0
      for (o = 1; o <= noccur; o++) {
        ln = occ_line[o]; sid = occ_id[o]
        j = ln + 1
        while (j <= n && lines[j] ~ /^[ \t]*$/) j++
        ok = 0
        if (j <= n && lines[j] ~ /^## /) {
          title = lines[j]
          sub(/^## /, "", title)
          gsub(/^[ \t]+|[ \t]+$/, "", title)
          if (title != "") ok = 1
        }
        if (!ok) {
          printf "%s:retro-section: %s marker is not immediately followed by an H2 heading with a title\n", file, sid > "/dev/stderr"
          n_v++
        } else if (sid == "lessons" && lessons_heading_ln == 0) {
          lessons_heading_ln = j
        }
      }

      # --- rule 3: every top-level bullet under the lessons heading is
      # labelled. Only evaluated when the lessons marker resolved to a real
      # heading above (an unresolved lessons marker already reported its own
      # violation and has no well-defined section body to walk).
      if (lessons_heading_ln > 0) {
        for (ln = lessons_heading_ln + 1; ln <= n; ln++) {
          line = lines[ln]
          if (line ~ /^## /) break
          if (substr(line, 1, 2) != "- ") continue   # only top-level bullets
          if (line == "- (none)") continue            # allowed empty placeholder
          common = "- `[common]`"
          target = "- `[target-specific]`"
          if (substr(line, 1, length(common)) == common) continue
          if (substr(line, 1, length(target)) == target) continue
          printf "%s:unlabelled lesson bullet (need `[common]` or `[target-specific]`): %s\n", file, line > "/dev/stderr"
          n_v++
        }
      }

      print n_v + 0
    }
  ' "$FILE")"
  violations=$((violations + marker_violations))

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

      # A T-1010 section marker (`<!-- retro-section: <id> -->`) closes an
      # open region exactly the way the next `## ` heading always did — a
      # marker line always immediately precedes the NEXT H2, so for this
      # rule it counts as the start of the next section too, even though it
      # is not itself a `## ` line.
      if (in_s && (line ~ /^## / || line ~ /^<!-- retro-section: /)) { in_s = 0 }

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
