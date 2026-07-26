#!/usr/bin/env bash
# check-contract.sh — lint a loop-contract YAML against the 8-element contract.
#
# Validates that a tasks/loops/*.contract.yaml declares all eight contract
# elements (trigger / scope / action / budget / stop / report / owner /
# evidence) and that the mandatory sections carry their required keys/shape:
#   budget:   max_iterations, max_wallclock_min, max_subagents, max_usd
#   stop:     all_acs_green, max_iterations_reached, budget_exhausted, no_progress
#   owner:    a non-empty scalar value (who is accountable for the loop's runs)
#   evidence: at least one list item (the proof a run must produce to claim
#             "done"; a read-only/no-op loop states '- none: <reason>')
# and that trigger.type is one of: manual | schedule | event.
#
# BUDGET and STOP are the runaway / billing guardrail; OWNER and EVIDENCE are
# the accountability / "unverified done" guardrail (T-028) — a contract missing
# any of them (or their required keys/shape) is rejected.
#
# Reads only. Prints `<file>:<lineno>: <reason>` to stderr per violation
# (lineno 0 = a whole-file / missing-element finding) and exits non-zero if
# any were found. Pure bash — no YAML parser — so it stays dependency-free and
# runs anywhere check-handoff.sh does.
#
# Exit: 0 = clean, 1 = contract violation(s), 2 = file unreadable.

set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" || ! -r "$FILE" ]]; then
  printf '%s: cannot read file\n' "${FILE:-<no file given>}" >&2 || true
  exit 2
fi

violations=0
emit() {
  # $1 = lineno (0 for a missing top-level element), $2 = reason
  printf '%s:%s: %s\n' "$FILE" "$1" "$2" >&2
  violations=$((violations + 1))
}

# Line number of a top-level key (`^key:`), or empty if absent. Uses awk
# (not `grep | head`) so an early-closed pipe cannot raise SIGPIPE and trip
# `set -o pipefail`.
toplevel_lineno() {
  awk -v key="$1" '$0 ~ "^" key ":" { print NR; exit }' "$FILE"
}

# Body of a top-level section: the lines strictly between `^key:` and the next
# line that begins in column 0 (the next top-level key or EOF). A column-0
# comment (`#...`) does NOT close the section — comments are legal inside a
# YAML block and must not truncate it. Emits `<lineno>\t<original-line>` so
# callers keep real line numbers.
section_body() {
  awk -v key="$1" '
    $0 ~ "^" key ":" && !seen { seen=1; in_sec=1; next }
    in_sec && /^[^[:space:]#]/ { in_sec=0 }
    in_sec { printf "%d\t%s\n", NR, $0 }
  ' "$FILE"
}

# Assert an indented sub-key (`<tab><ws>subkey:` in a section_body record)
# is present; otherwise report it against the section header line.
require_subkey() {
  local body="$1" subkey="$2" section="$3" section_line="$4"
  if ! grep -qE $'\t'"[[:space:]]*$subkey:" <<< "$body"; then
    emit "$section_line" "missing required '$section' key: $subkey"
  fi
}

# --- Six required top-level contract elements ---
REQUIRED_SECTIONS=(trigger scope action budget stop report)
for sec in "${REQUIRED_SECTIONS[@]}"; do
  if [[ -z "$(toplevel_lineno "$sec")" ]]; then
    emit 0 "missing required contract element: $sec"
  fi
done

# --- budget: mandatory guardrail keys ---
budget_line="$(toplevel_lineno budget)"
if [[ -n "$budget_line" ]]; then
  budget_body="$(section_body budget)"
  for k in max_iterations max_wallclock_min max_subagents max_usd; do
    require_subkey "$budget_body" "$k" budget "$budget_line"
  done
fi

# --- stop: mandatory terminal conditions ---
stop_line="$(toplevel_lineno stop)"
if [[ -n "$stop_line" ]]; then
  stop_body="$(section_body stop)"
  for k in all_acs_green max_iterations_reached budget_exhausted no_progress; do
    require_subkey "$stop_body" "$k" stop "$stop_line"
  done
fi

# --- trigger.type enum ---
trigger_line="$(toplevel_lineno trigger)"
if [[ -n "$trigger_line" ]]; then
  trigger_body="$(section_body trigger)"
  # First `type:` record. awk single-pass (not `grep | head`) so an early-closed
  # pipe cannot raise SIGPIPE and trip `set -o pipefail` — matching toplevel_lineno.
  type_record="$(awk -F'\t' '$2 ~ /^[[:space:]]*type:/ { print; exit }' <<< "$trigger_body")"
  if [[ -z "$type_record" ]]; then
    emit "$trigger_line" "missing required 'trigger' key: type"
  else
    type_lineno="${type_record%%$'\t'*}"
    type_content="${type_record#*$'\t'}"
    if [[ "$type_content" =~ type:[[:space:]]*([A-Za-z_]+) ]]; then
      type_val="${BASH_REMATCH[1]}"
    else
      type_val=""
    fi
    case "$type_val" in
      manual|schedule|event) : ;;
      *) emit "$type_lineno" "invalid trigger type '$type_val' (must be manual|schedule|event)" ;;
    esac
  fi
fi

# --- owner: required accountability scalar with a non-empty value ---
owner_line="$(toplevel_lineno owner)"
if [[ -z "$owner_line" ]]; then
  emit 0 "missing required contract element: owner"
else
  # The text after `owner:` on that line, leading whitespace stripped.
  owner_rest="$(awk -v ln="$owner_line" 'NR==ln { sub(/^owner:[[:space:]]*/, ""); print }' "$FILE")"
  owner_rest="${owner_rest%$'\r'}"
  owner_rest="${owner_rest%"${owner_rest##*[![:space:]]}"}"   # trim trailing whitespace
  if [[ -z "$owner_rest" || "$owner_rest" == "#"* ]]; then
    emit "$owner_line" "owner has no value (declare who is accountable for this loop's runs)"
  fi
fi

# --- evidence: required list of proof artifacts (>= 1 item) ---
evidence_line="$(toplevel_lineno evidence)"
if [[ -z "$evidence_line" ]]; then
  emit 0 "missing required contract element: evidence"
else
  evidence_body="$(section_body evidence)"
  # The first real content line (non-blank, non column-0-comment) must be a flat
  # list item `- ...` — so a direct list passes but a nested mapping
  # (e.g. `evidence:` then `artifacts:` then `  - x`) does NOT (the `- ` there is
  # a grandchild, not evidence's direct child). A read-only/no-op loop uses
  # `- none: <reason>`. section_body records are `<lineno>\t<original-line>`.
  evidence_first="$(awk -F'\t' 'NF>1 { s=$2; sub(/^[[:space:]]+/, "", s); if (s == "" || s ~ /^#/) next; print s; exit }' <<< "$evidence_body")"
  if [[ "$evidence_first" != "- "* ]]; then
    emit "$evidence_line" "evidence must list at least one required proof artifact as a flat list item (use '- none: <reason>' for a read-only/no-op loop)"
  fi
fi

[[ "$violations" -gt 0 ]] && exit 1
exit 0
