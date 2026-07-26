#!/usr/bin/env bash
# cluster-failures.sh — cross-run failure clustering for the Operating-Loop
# telemetry (T-044, #115).
#
# bin/rollup-runs.sh (T-020) tallies span-level telemetry per `run_id` and
# flags each run, but it never looks *across* runs. This sibling script reads
# the same tasks/runs/<loop_id>.jsonl span files, finds every FAILING span
# (per the same health-flag condition rollup-runs.sh uses, applied per-span),
# groups them by a normalized `<PHASE>:<REASON>` signature, and prints a
# ranked, deterministic summary: theme -> count -> representative run_id.
#
# bin/rollup-runs.sh itself is NOT touched or imported — this is a genuinely
# separate script (see docs/specs/T-044-failure-clustering.md, Design decision
# (a)), following the same sibling-script pattern as bin/consolidate-proposals.sh
# sitting alongside bin/discover-work.sh and bin/rollup-runs.sh.
#
# A span is FAILING iff (Design decision (b), rollup-runs.sh:140's condition,
# applied per-span instead of per-run):
#   status ∈ {error, timeout, stopped}  OR  verdict ∈ {FAIL, REQUEST_CHANGES}
#
# The normalized signature (Design decision (c)) is `<PHASE>:<REASON>`, both
# upper-cased:
#   PHASE  = the failing span's `phase` field (missing -> `?`)
#   REASON = the verdict label if verdict ∈ {FAIL, REQUEST_CHANGES} (verdict
#            wins as the more diagnostic signal); otherwise the status label
#            if status ∈ {error, timeout, stopped}. The free-text `--error`
#            field is deliberately excluded — it would fragment identical
#            failures into different clusters over volatile wording.
#
# Output (Design decision (d)): one line per distinct signature, in descending
# count order, ties broken by first-seen order (the order the signature's
# first failing span appears across the input file/line sequence). Each line
# carries the signature, its count (failing spans across all input runs
# sharing that signature — not deduplicated per run), and a representative
# `run_id` (the run_id of that signature's first-seen failing span), surfaced
# as a `run <id>` token on the line — the same extraction precedent
# bin/consolidate-proposals.sh already uses against rollup-runs.sh's
# `run <id>  [loop <id>]  ⚠` header line. No failing spans in the input prints
# an explicit `(no failure clusters found)` sentinel and exits 0 — mirroring
# rollup-runs.sh's `(no runs found)` sentinel, never a silent empty stdout.
#
# It assumes check-run-valid input (malformed lines are check-run's job); a
# line with no extractable `run_id` still counts toward its signature's
# cluster (shown as `run ?`), matching rollup-runs.sh's `${loop_id:-?}`
# missing-field convention. Pure bash + coreutils only (no external JSON/text
# tooling), and no bash-4-only constructs (no associative-array declarations,
# no lower-casing parameter expansion), so it runs under macOS bash 3.2 as
# well as GNU bash. PROPOSE-ONLY: stdout only, never writes tasks/todo.md,
# never invokes the GitHub CLI.
#
# Usage:  cluster-failures.sh <run.jsonl> [<run.jsonl>...]
# Exit:   0 = summary printed (incl. "no failure clusters found"),
#         2 = usage / unreadable file.

set -euo pipefail

# Byte-wise locale so uppercasing (tr) and comparisons below are deterministic
# regardless of the caller's locale collation. printf still emits raw bytes
# for the sentinel text.
export LC_ALL=C

if [[ "$#" -lt 1 ]]; then
  printf 'usage: cluster-failures.sh <run.jsonl> [<run.jsonl>...]\n' >&2 || true
  exit 2
fi

# --- buffer every span line from every input file (in file/line order) ---
LINES=()
for FILE in "$@"; do
  if [[ ! -r "$FILE" ]]; then
    printf '%s: cannot read file\n' "$FILE" >&2 || true
    exit 2
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && continue
    LINES+=("$line")
  done < "$FILE"
done

# Extract a quoted string field value (empty if absent or null). The key is
# anchored to a JSON-object boundary (`{` or `,` then `"key":`) so a future
# schema key that *ends with* an existing key can never be mis-read as that
# key. Keys are trusted literal constants. (Verbatim from bin/rollup-runs.sh —
# a copy, not a source-import, per the sibling-script pattern in Design
# decision (a): this script does not touch or depend on rollup-runs.sh.)
field_str() {
  local line="$1" key="$2"
  if [[ "$line" =~ [\{,]\"$key\":\"([^\"]*)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# --- pass 1: find every failing span (Design decision (b)) and its
#     normalized signature (Design decision (c)), in file/line order ---
SIG=()      # distinct signatures, in first-seen order
CNT=()      # parallel: failing-span count per signature
RUNID=()    # parallel: representative run_id (first-seen span's run_id)

if [[ "${#LINES[@]}" -gt 0 ]]; then
  for line in "${LINES[@]}"; do
    status="$(field_str "$line" status)"
    verdict="$(field_str "$line" verdict)"

    is_fail=0
    case "$status" in
      error|timeout|stopped) is_fail=1 ;;
    esac
    case "$verdict" in
      FAIL|REQUEST_CHANGES) is_fail=1 ;;
    esac
    [[ "$is_fail" -eq 1 ]] || continue

    reason=""
    case "$verdict" in
      FAIL|REQUEST_CHANGES) reason="$verdict" ;;
    esac
    if [[ -z "$reason" ]]; then
      case "$status" in
        error|timeout|stopped) reason="$(upper "$status")" ;;
      esac
    fi

    phase="$(field_str "$line" phase)"
    [[ -n "$phase" ]] || phase="?"
    sig="$(upper "$phase"):${reason}"

    rid="$(field_str "$line" run_id)"
    [[ -n "$rid" ]] || rid="?"

    # find sig's index among the distinct signatures seen so far
    idx=-1
    i=0
    if [[ "${#SIG[@]}" -gt 0 ]]; then
      for s in "${SIG[@]}"; do
        if [[ "$s" == "$sig" ]]; then idx="$i"; break; fi
        i=$((i + 1))
      done
    fi

    if [[ "$idx" -eq -1 ]]; then
      SIG+=("$sig")
      CNT+=(1)
      RUNID+=("$rid")
    else
      CNT[idx]=$((CNT[idx] + 1))
    fi
  done
fi

N="${#SIG[@]}"
if [[ "$N" -eq 0 ]]; then
  printf '(no failure clusters found)\n'
  exit 0
fi

# --- pass 2: stable rank — descending count, ties broken by first-seen order
#     (a repeated "pick the earliest unused max" selection, which is
#     manifestly stable for ties since it always prefers the lower index) ---
USED=()
i=0
while [[ "$i" -lt "$N" ]]; do
  USED[i]=0
  i=$((i + 1))
done

shown=0
while [[ "$shown" -lt "$N" ]]; do
  best=-1
  bestcnt=-1
  i=0
  while [[ "$i" -lt "$N" ]]; do
    if [[ "${USED[$i]}" -eq 0 ]] && [[ "${CNT[$i]}" -gt "$bestcnt" ]]; then
      bestcnt="${CNT[$i]}"
      best="$i"
    fi
    i=$((i + 1))
  done
  USED[best]=1
  printf 'cluster %s  count=%s  run %s\n' "${SIG[$best]}" "${CNT[$best]}" "${RUNID[$best]}"
  shown=$((shown + 1))
done
