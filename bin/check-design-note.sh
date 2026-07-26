#!/usr/bin/env bash
# check-design-note.sh — validate a UI Designer design note is a real design
# contract, not an empty/placeholder file. This is the machine gate the shell-team
# [Design] phase uses (replacing a bare `test -s`) so an empty, whitespace-only,
# banner-only, or stale (wrong-task) note cannot pass for a real one.
#
# Validates the note given as <path>:
#   1. The file exists and has real content beyond whitespace.
#   2. The two required core sections are present *as headings* (line-anchored
#      bold markers — appearing only in prose does not satisfy the check):
#        **Aesthetic direction**
#        **Acceptance hooks**
#      (the committed direction + how to tell it was honored = the contract core).
#   3. "Banner-only" is rejected: after removing the degraded-mode banner lines
#      (`⚠️ Degraded design mode …`) and blank lines, the required sections must
#      still be present — so a degraded note that carries real sections passes,
#      but a note that is only the banner fails.
#   4. With `--task <T-NNN>`: the note must carry a `Task: <T-NNN>` line matching
#      that id. A note whose only task id differs (a stale note left from another
#      task) is rejected. Without `--task`, the id check is skipped.
#
# The required heading strings are a contract with agents/ui-designer.md — keep
# them in sync (the design note's "Output" section writes exactly these).
#
# Reads only. Pure bash + coreutils (awk/grep/sed) — no jq/yq/python. Prints
# `<file>: <reason>` per violation to stderr.
#
# Usage:  check-design-note.sh <path> [--task <T-NNN>]
# Exit:   0 = valid design note
#         1 = invalid (missing file / empty / whitespace-only / banner-only /
#             missing required section / --task mismatch) — a failed gate
#         2 = usage / argument error
#
# Note on exit codes: unlike check-acs / check-handoff (which exit 2 on an
# unreadable target), a missing/empty note here is exit 1, not 2 — for this gate
# "the expected note is absent or hollow" is a real validation failure (the gate
# did not pass), not a usage error. Only a malformed invocation is exit 2.

set -euo pipefail

PATH_ARG=""
TASK=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --task)
      [[ "$#" -ge 2 ]] || { printf 'usage: check-design-note.sh <path> [--task <T-NNN>]\n' >&2 || true; exit 2; }
      TASK="$2"; shift 2 ;;
    --task=*)
      TASK="${1#--task=}"; shift ;;
    -*)
      printf 'check-design-note.sh: unknown flag: %s\n' "$1" >&2 || true; exit 2 ;;
    *)
      if [[ -z "$PATH_ARG" ]]; then PATH_ARG="$1"; shift
      else printf 'check-design-note.sh: unexpected extra argument: %s\n' "$1" >&2 || true; exit 2; fi ;;
  esac
done

[[ -n "$PATH_ARG" ]] || { printf 'usage: check-design-note.sh <path> [--task <T-NNN>]\n' >&2 || true; exit 2; }

# Required core section headings — must match agents/ui-designer.md verbatim.
AESTHETIC='**Aesthetic direction**'
ACCEPTANCE='**Acceptance hooks**'

violations=0
emit() { printf '%s: %s\n' "$PATH_ARG" "$1" >&2 || true; violations=$((violations + 1)); }

# 1. Existence + non-whitespace content. A missing or hollow note fails the gate.
if [[ ! -f "$PATH_ARG" ]]; then
  emit "design note not found (the [Design] gate has no note to validate)"
  exit 1
fi
if [[ ! -r "$PATH_ARG" ]]; then
  emit "cannot read design note"
  exit 1
fi
if ! grep -q '[^[:space:]]' "$PATH_ARG"; then
  emit "design note is empty or whitespace-only"
  exit 1
fi

# 3 (applied to 2): drop the degraded-mode banner lines, then check the required
# sections against the remainder — so "banner only" fails but a degraded note
# carrying real sections passes. Blank lines are left in place (the line-anchored
# heading regex ignores them). A heading is line-anchored (leading whitespace
# allowed); the marker appearing mid-prose does not count.
body="$(grep -v '⚠️ Degraded design mode' "$PATH_ARG" || true)"

grep -qE "^[[:space:]]*\*\*Aesthetic direction\*\*" <<< "$body" \
  || emit "missing required section heading: ${AESTHETIC}"
grep -qE "^[[:space:]]*\*\*Acceptance hooks\*\*" <<< "$body" \
  || emit "missing required section heading: ${ACCEPTANCE}"

# 4. Task-id match (stale-note guard) when --task is given.
if [[ -n "$TASK" ]]; then
  if [[ ! "$TASK" =~ ^T-[0-9]+$ ]]; then
    printf 'check-design-note.sh: --task must look like T-NNN (got: %s)\n' "$TASK" >&2 || true
    exit 2
  fi
  # Take the FIRST line-anchored `Task:` line (optionally a list bullet) as the
  # note's declared id. Anchoring to line start + taking only the first match
  # means a prose mention ("this replaces Task: T-033") cannot spoof the guard,
  # and a note with multiple Task header lines is judged by its first one.
  first_task_id="$(grep -m1 -oE '^[[:space:]]*[-*]?[[:space:]]*Task:[[:space:]]*T-[0-9]+' "$PATH_ARG" \
                   | grep -oE 'T-[0-9]+' || true)"
  if [[ -z "$first_task_id" ]]; then
    emit "no 'Task: T-NNN' line in design note (cannot confirm it belongs to ${TASK})"
  elif [[ "$first_task_id" != "$TASK" ]]; then
    emit "design note task id [${first_task_id}] does not match --task ${TASK} (stale note?)"
  fi
fi

[[ "$violations" -gt 0 ]] && exit 1
exit 0
