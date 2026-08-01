#!/usr/bin/env bash
# check-run.sh — lint an Operating-Loop telemetry JSONL file, or exactly one
# already-in-hand line (T-042).
#
# Validates every non-empty line of tasks/runs/<loop_id>.jsonl (file mode), or
# a single line passed on the command line (`--line` mode, zero file I/O).
# Two row shapes share the file (T-1011), discriminated per line by the
# `kind` key: absent or `"kind":"span"` is a SPAN row (the original T-014/
# T-015 shape, validated exactly as before this task); `"kind":"event"` is an
# EVENT row (T-1011: a hand-off, a route-back, a gate verdict, a human
# stop/GO, a release). Any other `kind` value is itself a violation.
#
#   SPAN row required keys:
#       loop_id, run_id, seq, ts, span, phase, iteration, attempt, status
#     status is in its enum; verdict (when not null) is in its enum; an
#     `event` key on a span row is itself a violation (shape mixing, D2).
#
#   EVENT row required keys:
#       loop_id, run_id, seq, ts, kind, event
#     `event` is in its closed 5-member enum (handoff|rework|gate|human|
#     release), and per-event-id required fields (from/to/label) must be
#     present and non-null (D3's table). None of the 13 span-only keys may
#     appear on an event row (shape mixing, D2).
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
REQUIRED_EVENT_KEYS=(loop_id run_id seq ts kind event)
SPAN_ONLY_KEYS=(span phase iteration attempt status model tokens tool_uses duration_ms verdict usd error parent_span_id)

violations=0
# LABEL is the display prefix for emit() ("<file>" in file mode, "<line>" in
# --line mode) — a GLOBAL set once before linting starts, not a per-call
# argument: passing the file-mode redirect's own path into a function called
# inside its `while ... done < "$FILE"` loop trips shellcheck's SC2094
# ("read and write the same file in the same pipeline") even though nothing
# here ever writes to it.
LABEL=""
emit() { printf '%s:%s: %s\n' "$LABEL" "$1" "$2" >&2; violations=$((violations + 1)); }

# key_present <line> <key> — boundary-anchored presence test: the key token
# must be preceded by `{` or `,`, exactly as bin/rollup-runs.sh's field_str
# already does (D2) — so a key that is a substring of a longer key, or one
# that appears escaped inside a string value, can never match. Used by every
# new (event-side and kind-discriminator) check below; the pre-existing
# span-side REQUIRED_KEYS presence test further down is intentionally left
# unanchored, byte-identical to before this task — changing how span rows
# are detected is a span-side behavior change, out of scope (D2).
key_present() {
  local line="$1" key="$2"
  [[ "$line" =~ [\{,]\"$key\": ]]
}

# field_nonnull_anchored <line> <key> — true iff <key> is present as a
# boundary-anchored, non-empty quoted string. Absent, JSON `null`, an
# unquoted value, or an explicit empty string ("") all read as "not
# provided" (D3: "required" = present and non-null; empty string is a
# violation same as absent/null). Event-side only.
field_nonnull_anchored() {
  local line="$1" key="$2"
  [[ "$line" =~ [\{,]\"$key\":\"([^\"]*)\" ]] && [[ -n "${BASH_REMATCH[1]}" ]]
}

# lint_span_line <lineno> <line> — the pre-T-1011 span checks, byte-identical
# in logic to before this task, plus one new D2 mixing check: a span row must
# not carry the event-only `event` key.
lint_span_line() {
  local lineno="$1" line="$2"

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

  # D2: shape mixing, span-side direction — an `event` key on a span row.
  key_present "$line" event && emit "$lineno" "span row carries event-only key: event"
  return 0
}

# lint_event_line <lineno> <line> — the T-1011 event checks (D3/D4). Never
# runs the span-side required-key / status / verdict checks above: an event
# row is not a defective span and must not be reported as one.
lint_event_line() {
  local lineno="$1" line="$2"

  # Required event keys present (boundary-anchored, D2).
  local missing="" k
  for k in "${REQUIRED_EVENT_KEYS[@]}"; do
    key_present "$line" "$k" || missing+="${missing:+,}$k"
  done
  [[ -n "$missing" ]] && emit "$lineno" "missing required event key(s): $missing"

  # event enum (closed 5-member vocabulary, D3).
  local event_val="" event_known=0
  if [[ "$line" =~ [\{,]\"event\":\"([^\"]*)\" ]]; then
    event_val="${BASH_REMATCH[1]}"
    case "$event_val" in
      handoff|rework|gate|human|release) event_known=1 ;;
      *) emit "$lineno" "invalid event '${event_val}' (handoff|rework|gate|human|release)" ;;
    esac
  elif key_present "$line" event; then
    emit "$lineno" "event must be a quoted enum value"
  fi

  # D2: shape mixing, event-side direction — any of the 13 span-only keys.
  local found="" sk
  for sk in "${SPAN_ONLY_KEYS[@]}"; do
    key_present "$line" "$sk" && found+="${found:+,}$sk"
  done
  [[ -n "$found" ]] && emit "$lineno" "event row carries span-only key(s): $found"

  # Per-event-id requiredness (D3's table) — only meaningful once the id
  # itself is known-valid; an unknown id was already reported above.
  if [[ "$event_known" -eq 1 ]]; then
    local req_from=0 req_to=0 req_label=0
    case "$event_val" in
      handoff) req_from=1; req_to=1 ;;
      rework)  req_from=1; req_to=1; req_label=1 ;;
      gate)    req_from=1; req_label=1 ;;
      human)   req_label=1 ;;
      release) : ;;
    esac
    [[ "$req_from"  -eq 1 ]] && ! field_nonnull_anchored "$line" from  && emit "$lineno" "event '${event_val}' requires non-null from"
    [[ "$req_to"    -eq 1 ]] && ! field_nonnull_anchored "$line" to    && emit "$lineno" "event '${event_val}' requires non-null to"
    [[ "$req_label" -eq 1 ]] && ! field_nonnull_anchored "$line" label && emit "$lineno" "event '${event_val}' requires non-null label"
  fi
  return 0
}

# lint_line <lineno> <raw line>
# Runs every violation category against one line and calls emit() per finding.
# Shape-independent checks first (object shape, quote balance — a malformed
# line short-circuits exactly as before this task); then the `kind`
# discriminator (D2); then exactly one shape-specific branch. A
# missing-key/enum finding does NOT short-circuit further checks within a
# branch (status/verdict are still checked independently, matching the
# pre-existing span behavior).
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

  # kind discriminator (D2): absent or "span" => span; "event" => event; any
  # other quoted value, or an unquoted/null kind, is itself a violation — and
  # (not being a recognized "event") falls back to the span branch, so a row
  # with a garbage `kind` is also diagnosed for whatever else is wrong with it.
  local is_event=0
  if [[ "$line" =~ [\{,]\"kind\":\"([^\"]*)\" ]]; then
    case "${BASH_REMATCH[1]}" in
      span)  : ;;
      event) is_event=1 ;;
      *) emit "$lineno" "invalid kind '${BASH_REMATCH[1]}' (span|event)" ;;
    esac
  elif key_present "$line" kind; then
    emit "$lineno" "kind must be a quoted enum value"
  fi

  if [[ "$is_event" -eq 1 ]]; then
    lint_event_line "$lineno" "$line"
  else
    lint_span_line "$lineno" "$line"
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
