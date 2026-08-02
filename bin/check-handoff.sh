#!/usr/bin/env bash
# check-handoff.sh — lint tasks/todo.md against the team hand-off contract.
#
# Validates every top-level `- [ ]` line in the `## Active` section:
#   - matches `- [ ] **T-NNN** <title> — `<FLAG>` — spec: <path>.md`
#   - the FLAG is in the allowed status-flag enum
#
# The spec path is intentionally NOT prefix-locked to `docs/specs/`: under the
# T-025 footprint consolidation a host's specs may live under `.shell-team/specs/`
# (or any base dir), so any non-empty path ending in `.md` is accepted. The
# legacy `docs/specs/<slug>.md` form still matches.
#
# A continuation line (T-1016 D4) — an indented, non-blank line — that
# belongs to no task entry (no task line, `^- \[[x ]\] `, seen above it since
# the start of `## Active`) is a STRAND: reported as a violation with the
# frozen reason "stranded continuation line (no task entry above it in this
# section)". `## Done` is deliberately out of scope for this check.
#
# Reads only. Prints `<file>:<lineno>: <reason>: <line>` to stderr per
# violation and exits non-zero if any were found.

set -euo pipefail

FILE="${1:-tasks/todo.md}"

if [[ ! -r "$FILE" ]]; then
  printf '%s: cannot read file\n' "$FILE" >&2
  exit 2
fi

# Allowed status-flag vocabulary.
ALLOWED_FLAGS=(
  READY_FOR_ARCH
  READY_FOR_ENG
  READY_FOR_QA
  READY_FOR_REVIEW
  READY_FOR_MERGE
  BLOCKED
  REWORK
)

flag_allowed() {
  local candidate="$1" f
  for f in "${ALLOWED_FLAGS[@]}"; do
    [[ "$f" == "$candidate" ]] && return 0
  done
  return 1
}

# Extract the Active section while preserving original line numbers.
# Output format: `<lineno>\t<line>` for each line strictly between the
# first `## Active` heading and the next `## ` heading.
active_block="$(awk '
  /^## Active[[:space:]]*$/ && !seen { seen=1; in_active=1; next }
  in_active && /^## / { in_active=0 }
  in_active { printf "%d\t%s\n", NR, $0 }
' "$FILE")"

# Top-level task line shape. Em-dash separator is U+2014.
# The flag token is intentionally widened to `[^`]+` (any non-empty backtick
# content); flag_allowed() is the source of truth for the vocabulary, so a
# shape-valid line with a typo'd / lowercase flag is reported as
# "unknown status flag" rather than misclassified as "format mismatch".
# The title slot is `.*[^[:space:]].*` — at least one non-whitespace char must
# appear somewhere in the title, but leading/trailing padding is tolerated
# (e.g. `  hello world  ` passes; `   ` (whitespace-only) does not).
# shellcheck disable=SC2016
LINE_RE='^- \[ \] \*\*T-[0-9]+\*\* .*[^[:space:]].* — `[^`]+` — spec: [^[:space:]]+\.md$'
# Flag extraction is anchored to the documented separator (` — `<flag>` — spec:`)
# so a backtick-wrapped token in the task title (e.g. `API`, `URL`) cannot be
# mistaken for the status flag.
# shellcheck disable=SC2016
FLAG_RE='— `([^`]+)` — spec:'

violations=0
emit() {
  printf '%s:%s: %s: %s\n' "$FILE" "$1" "$2" "$3" >&2
  violations=$((violations + 1))
}

# board-entry continuation canon (T-1016): a boundary is any non-indented
# non-blank line, or EOF; a blank line is neutral and ends nothing; every
# indented non-blank line — whatever its first character (`-`, `|`, a tab, a
# digit, prose) — continues the entry. `in_entry` tracks whether a task line
# (a loose `^- \[[x ]\]` checkbox-shaped prefix, deliberately WITHOUT the
# Terms table's well-formed trailing space) has been seen, with no boundary
# line since, so a continuation line reached with `in_entry` still 0 is a
# STRAND (D4) — a malformed top-level line still opens an entry (one defect,
# one message; no cascade of strand violations for its own sub-bullets), and
# the `_(` placeholder stays a boundary that opens no entry.
#
# Codex round-1 review Blocker: an earlier cut of this predicate required the
# trailing space (`^- \[[x ]\] `, the Terms table's WELL-FORMED "task line"
# shape), which is stricter than the loose `"- [ ]"*` prefix the format gate
# below actually fires on. A near-miss task-shaped line with no space after
# the closing bracket (`- [ ]broken title`) then opened no entry at all, so
# its own legitimate sub-bullets were misreported as strands on top of the
# real format-mismatch message (two defects reported for one root cause) —
# and a checked near-miss (`- [x]done...`) got WORSE: the format gate never
# even fires for `[x]` lines, so the malformed line itself produced NO
# message while its child was still falsely flagged. D4's malformed-line
# clause ("A line beginning `- [ ]` that fails LINE_RE is reported once...
# and does NOT additionally produce a strand violation for each of its
# sub-bullets") governs exactly this near-miss-task-shaped class — the
# Terms table's trailing-space form defines a WELL-FORMED task line, not the
# boundary for "did something open an entry at all". Dropping the trailing
# space here aligns the entry-opener with the loose prefix test, so any
# checkbox-shaped line (open bracket, `x` or space, close bracket, THEN
# anything or nothing) opens an entry regardless of what immediately follows
# the closing bracket — empty, a tab, punctuation, or prose with no
# separating space are all still shapes reachable per the spec's own Input
# space ("A malformed top-level line ... followed by its own continuation
# lines").
# shellcheck disable=SC2016
TASK_LINE_RE='^- \[[x ]\]'
# shellcheck disable=SC2016
CONTINUATION_RE='^[[:space:]]+[^[:space:]]'

in_entry=0

# Read the whole `<lineno>\t<content>` record and split manually. Using
# `IFS=$'\t' read -r lineno content` would coalesce runs of tab and strip a
# leading tab from `content`, causing tab-indented sub-bullets to slip past
# the sub-bullet guard below and be re-evaluated as malformed top-level lines.
while IFS= read -r raw; do
  [[ -z "$raw" ]] && continue
  lineno="${raw%%$'\t'*}"
  content="${raw#*$'\t'}"
  [[ -z "$lineno" ]] && continue
  # Tolerate Windows CRLF line endings: a trailing `\r` survives the awk
  # extraction and would otherwise break the LINE_RE `$` anchor.
  content="${content%$'\r'}"
  # Blank line: neutral no-op, leaves in_entry untouched.
  [[ -z "${content//[[:space:]]/}" ]] && continue

  # Continuation line (indented, non-blank): fine while in_entry, a strand
  # otherwise. Either way it is never itself validated against LINE_RE.
  if [[ "$content" =~ $CONTINUATION_RE ]]; then
    if [[ "$in_entry" -eq 0 ]]; then
      emit "$lineno" "stranded continuation line (no task entry above it in this section)" "$content"
    fi
    continue
  fi

  # Boundary line: closes any open scope first.
  in_entry=0

  # Placeholder lines (`_(none)_`) are a boundary that opens no entry.
  [[ "$content" == _\(* ]] && continue

  # A task line (checked or unchecked) opens a new entry — even a malformed
  # `- [ ]` line that fails LINE_RE below, so its own sub-bullets are not
  # re-reported as strands (D4).
  [[ "$content" =~ $TASK_LINE_RE ]] && in_entry=1

  # Only validate unfinished (`- [ ]`) top-level checklist lines against the
  # hand-off grammar.
  [[ "$content" != "- [ ]"* ]] && continue

  if [[ ! "$content" =~ $LINE_RE ]]; then
    emit "$lineno" "format mismatch" "$content"
    continue
  fi

  if [[ "$content" =~ $FLAG_RE ]]; then
    flag="${BASH_REMATCH[1]}"
    if ! flag_allowed "$flag"; then
      emit "$lineno" "unknown status flag '$flag'" "$content"
    fi
  fi
done <<< "$active_block"

[[ "$violations" -gt 0 ]] && exit 1
exit 0
