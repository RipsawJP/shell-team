#!/usr/bin/env bash
# check-run.sh — lint an Operating-Loop telemetry JSONL file, or exactly one
# already-in-hand line (T-042).
#
# Validates every non-empty line of tasks/runs/<loop_id>.jsonl (file mode), or
# a single line passed on the command line (`--line` mode, zero file I/O):
#   - the line is a single JSON object (`{...}`)
#   - all required keys are present:
#       loop_id, run_id, seq, ts, span, phase, iteration, attempt, status
#   - status is in its enum; verdict (when not null) is in its enum
#
# This is a STRUCTURAL lint, not a full JSON parser: `log-run.sh` is the single
# canonical writer, so check-run only has to catch corruption / hand-edits /
# bad enums. Pure bash (no JSON library) — runs anywhere the other bin/ scripts
# do, with zero runtime dependencies, which is the bar for a distributed plugin.
#
# `--line` mode is the re-lint seam log-run.sh's post-write self-check uses
# (defense-in-depth against a bug in log-run.sh's own JSON-serialization
# producing a structurally malformed line despite well-formed CLI input): it
# runs the exact same violation categories below against one line, with no
# file opened at all — so it's safe to call from a hot write path.
#
# Reads only (file mode). Prints `<label>:<lineno>: <reason>` to stderr per
# violation and exits non-zero if any were found.
#
# Usage:
#   check-run.sh <file>           — lint every line of <file>
#   check-run.sh --line '<json>'  — lint exactly one line (no file I/O)
#
# Exit: 0 = clean, 1 = lint violation(s), 2 = file unreadable / usage error.

set -euo pipefail

REQUIRED_KEYS=(loop_id run_id seq ts span phase iteration attempt status)

violations=0
# LABEL is the display prefix for emit() ("<file>" in file mode, "<line>" in
# --line mode) — a GLOBAL set once before linting starts, not a per-call
# argument: passing the file-mode redirect's own path into a function called
# inside its `while ... done < "$FILE"` loop trips shellcheck's SC2094
# ("read and write the same file in the same pipeline") even though nothing
# here ever writes to it.
LABEL=""
emit() { printf '%s:%s: %s\n' "$LABEL" "$1" "$2" >&2; violations=$((violations + 1)); }

# lint_line <lineno> <raw line>
# Runs every violation category against one line and calls emit() per finding.
# Mirrors the original control flow exactly: an object-shape or
# unbalanced-quotes failure short-circuits the rest of this line's checks (a
# truncated/malformed line can't be meaningfully key/enum-checked); a
# missing-key finding does NOT short-circuit (status/verdict are still checked
# independently).
lint_line() {
  local lineno="$1" line="$2"
  line="${line%$'\r'}"                       # tolerate CRLF
  [[ -z "${line//[[:space:]]/}" ]] && return 0   # skip blank lines

  # Object shape.
  if [[ ! "$line" =~ ^[[:space:]]*\{.*\}[[:space:]]*$ ]]; then
    emit "$lineno" "not a JSON object line"
    return 0
  fi

  # Unbalanced (unescaped) double-quotes => a truncated string let a stray `}`
  # slip past the object-shape check above. Drop escaped \" first, then the
  # real string delimiters must come in pairs.
  local unq quotes
  unq="${line//\\\"/}"
  quotes="${unq//[!\"]/}"
  if (( ${#quotes} % 2 != 0 )); then
    emit "$lineno" "unbalanced double-quotes (truncated string?)"
    return 0
  fi

  # Required keys present (as `"key":` tokens).
  local missing="" k
  for k in "${REQUIRED_KEYS[@]}"; do
    [[ "$line" == *"\"$k\":"* ]] || missing+="${missing:+,}$k"
  done
  [[ -n "$missing" ]] && emit "$lineno" "missing required key(s): $missing"

  # status enum.
  if [[ "$line" =~ \"status\":\"([^\"]*)\" ]]; then
    case "${BASH_REMATCH[1]}" in
      success|error|timeout|skipped|stopped) : ;;
      *) emit "$lineno" "invalid status '${BASH_REMATCH[1]}'" ;;
    esac
  elif [[ "$line" == *'"status":'* ]]; then
    emit "$lineno" "status must be a quoted enum value"
  fi

  # verdict enum (only when present and not null).
  if [[ "$line" =~ \"verdict\":\"([^\"]*)\" ]]; then
    case "${BASH_REMATCH[1]}" in
      PASS|FAIL|APPROVE|REQUEST_CHANGES) : ;;
      *) emit "$lineno" "invalid verdict '${BASH_REMATCH[1]}' (PASS|FAIL|APPROVE|REQUEST_CHANGES)" ;;
    esac
  fi
  return 0
}

MODE_ARG="${1:-}"

if [[ "$MODE_ARG" == "--line" ]]; then
  [[ $# -ge 2 ]] || { printf 'check-run: --line requires a value\n' >&2 || true; exit 2; }
  LABEL="<line>"
  lint_line 1 "$2"
  [[ "$violations" -gt 0 ]] && exit 1
  exit 0
fi

FILE="$MODE_ARG"
if [[ -z "$FILE" || ! -f "$FILE" || ! -r "$FILE" ]]; then
  printf '%s: cannot read file\n' "${FILE:-<no file given>}" >&2 || true
  exit 2
fi
LABEL="$FILE"

lineno=0
while IFS= read -r line || [[ -n "$line" ]]; do
  lineno=$((lineno + 1))
  lint_line "$lineno" "$line"
done < "$FILE"

[[ "$violations" -gt 0 ]] && exit 1
exit 0
