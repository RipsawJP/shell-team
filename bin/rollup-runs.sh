#!/usr/bin/env bash
# rollup-runs.sh — Operating-Loop roll-up: fold per-span telemetry into a
# per-run summary (the Observe -> Orient bridge).
#
# T-015's bin/log-run.sh emits one JSON span row per line to
# tasks/runs/<loop_id>.jsonl (schema finalized in T-014, validated by
# bin/check-run.sh). This script reads one or more of those .jsonl files,
# groups the span rows by `run_id`, and prints a human-readable summary per run:
# span count, phases covered, status / verdict breakdowns, token & duration
# totals, the wall-clock window, and a health flag.
#
# T-1011 adds a second row shape, EVENT rows (a hand-off, a route-back, a
# gate verdict, a human stop/GO, a release — discriminated by `"kind":
# "event"`), sharing the same file. This script skips them: they carry no
# span-shaped telemetry (no phase/status/tokens/etc.), so folding one in
# would corrupt every count below. The skip rule is fail-safe (D1): any
# `kind` value other than absent or `"span"` — including an unrecognized one
# — is skipped, not counted; reporting an unrecognized `kind` is
# bin/check-run.sh's job, not this reporter's. No new output is added for
# event rows (D1) — this script's stdout for a file is byte-identical to its
# stdout for the same file with every event row deleted.
#
# It assumes check-run-valid input (malformed lines are check-run's job); a line
# with no extractable `run_id` is skipped. Pure bash + coreutils — no
# jq/yq/python, and no bash-4 features (associative arrays, `${x,,}`), so it runs
# under macOS bash 3.2 as well as GNU bash.
#
# Health flag per run:
#   ⚠  any status in {error,timeout,stopped} OR any verdict in {FAIL,REQUEST_CHANGES}
#   ✓  all spans status=success AND verdicts ⊆ {PASS,APPROVE,none}
#   –  otherwise (e.g. a skipped span, no failures) — neither clean-green nor bad
#
# tokens/duration_ms are nullable: null values are summed as 0 and the total is
# marked "(partial)" so a missing-cost run is never silently reported as cheap.
#
# Usage:  rollup-runs.sh <run.jsonl> [<run.jsonl>...]
# Exit:   0 = summary printed (incl. "no runs found"), 2 = usage / unreadable file.

set -euo pipefail

# Byte-wise locale so the ISO-8601 UTC `ts` lexical min/max below is also the
# chronological order, regardless of the caller's locale collation. (Raw byte
# output of the multibyte flag glyphs is unaffected — printf emits bytes.)
export LC_ALL=C

if [[ "$#" -lt 1 ]]; then
  printf 'usage: rollup-runs.sh <run.jsonl> [<run.jsonl>...]\n' >&2 || true
  exit 2
fi

# is_span_row <line> — fail-safe `kind` discriminator (T-1011, D1): a row is
# a span when its `kind` value is absent or "span"; anything else (an event
# row, or an unrecognized/malformed `kind`) is skipped by this reporter. Keys
# are boundary-anchored (`{` or `,` then `"kind":`), the same anchoring
# field_str below uses, so a `kind`-shaped substring inside another field's
# value can never be mistaken for the discriminator.
is_span_row() {
  local line="$1"
  if [[ "$line" =~ [\{,]\"kind\":\"([^\"]*)\" ]]; then
    [[ "${BASH_REMATCH[1]}" == "span" ]]
    return
  fi
  ! [[ "$line" =~ [\{,]\"kind\": ]]
}

# --- buffer every span line from every input file (in file/line order);
#     event rows are skipped here so no pass below ever sees one ---
LINES=()
for FILE in "$@"; do
  if [[ ! -r "$FILE" ]]; then
    printf '%s: cannot read file\n' "$FILE" >&2 || true
    exit 2
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && continue
    is_span_row "$line" || continue
    LINES+=("$line")
  done < "$FILE"
done

# Extract a quoted string field value (empty if absent or null). The key is
# anchored to a JSON-object boundary (`{` or `,` then `"key":`) so a future
# schema key that *ends with* an existing key (e.g. a hypothetical `sub_run_id`)
# can never be mis-read as that key. Keys are trusted literal constants.
field_str() {
  local line="$1" key="$2"
  if [[ "$line" =~ [\{,]\"$key\":\"([^\"]*)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}
# Extract a numeric field value (empty if absent or JSON null), same anchoring.
field_num() {
  local line="$1" key="$2"
  if [[ "$line" =~ [\{,]\"$key\":([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

# --- pass 1: collect unique run_ids in first-seen order ---
RUN_IDS=()
if [[ "${#LINES[@]}" -gt 0 ]]; then
  for line in "${LINES[@]}"; do
    rid="$(field_str "$line" run_id)"
    [[ -z "$rid" ]] && continue
    seen=0
    if [[ "${#RUN_IDS[@]}" -gt 0 ]]; then
      for r in "${RUN_IDS[@]}"; do [[ "$r" == "$rid" ]] && { seen=1; break; }; done
    fi
    [[ "$seen" -eq 0 ]] && RUN_IDS+=("$rid")
  done
fi

if [[ "${#RUN_IDS[@]}" -eq 0 ]]; then
  printf '(no runs found)\n'
  exit 0
fi

# --- pass 2: aggregate and print one block per run_id ---
for rid in "${RUN_IDS[@]}"; do
  loop_id=""
  n_spans=0
  phases=""                       # space-separated, deduped, in order
  s_success=0 s_error=0 s_timeout=0 s_skipped=0 s_stopped=0
  v_pass=0 v_fail=0 v_approve=0 v_reqchg=0
  tok_sum=0 tok_partial=0
  dur_sum=0 dur_partial=0
  ts_min="" ts_max=""

  for line in "${LINES[@]}"; do
    [[ "$(field_str "$line" run_id)" == "$rid" ]] || continue
    n_spans=$((n_spans + 1))
    [[ -z "$loop_id" ]] && loop_id="$(field_str "$line" loop_id)"

    ph="$(field_str "$line" phase)"
    if [[ -n "$ph" && " $phases " != *" $ph "* ]]; then
      phases="${phases:+$phases }$ph"
    fi

    case "$(field_str "$line" status)" in
      success) s_success=$((s_success + 1)) ;;
      error)   s_error=$((s_error + 1)) ;;
      timeout) s_timeout=$((s_timeout + 1)) ;;
      skipped) s_skipped=$((s_skipped + 1)) ;;
      stopped) s_stopped=$((s_stopped + 1)) ;;
    esac

    case "$(field_str "$line" verdict)" in
      PASS)            v_pass=$((v_pass + 1)) ;;
      FAIL)            v_fail=$((v_fail + 1)) ;;
      APPROVE)         v_approve=$((v_approve + 1)) ;;
      REQUEST_CHANGES) v_reqchg=$((v_reqchg + 1)) ;;
    esac

    tk="$(field_num "$line" tokens)"
    if [[ -n "$tk" ]]; then tok_sum=$((tok_sum + tk)); else tok_partial=1; fi
    dm="$(field_num "$line" duration_ms)"
    if [[ -n "$dm" ]]; then dur_sum=$((dur_sum + dm)); else dur_partial=1; fi

    ts="$(field_str "$line" ts)"
    if [[ -n "$ts" ]]; then
      [[ -z "$ts_min" || "$ts" < "$ts_min" ]] && ts_min="$ts"
      [[ -z "$ts_max" || "$ts" > "$ts_max" ]] && ts_max="$ts"
    fi
  done

  # health flag
  if [[ $((s_error + s_timeout + s_stopped + v_fail + v_reqchg)) -gt 0 ]]; then
    flag="⚠"
  elif [[ "$s_success" -eq "$n_spans" ]]; then
    flag="✓"
  else
    flag="–"
  fi

  # status / verdict breakdown strings (only non-zero parts)
  status_str=""
  [[ "$s_success" -gt 0 ]] && status_str="${status_str:+$status_str }success=$s_success"
  [[ "$s_error"   -gt 0 ]] && status_str="${status_str:+$status_str }error=$s_error"
  [[ "$s_timeout" -gt 0 ]] && status_str="${status_str:+$status_str }timeout=$s_timeout"
  [[ "$s_skipped" -gt 0 ]] && status_str="${status_str:+$status_str }skipped=$s_skipped"
  [[ "$s_stopped" -gt 0 ]] && status_str="${status_str:+$status_str }stopped=$s_stopped"

  verdict_str=""
  [[ "$v_pass"    -gt 0 ]] && verdict_str="${verdict_str:+$verdict_str }PASS=$v_pass"
  [[ "$v_fail"    -gt 0 ]] && verdict_str="${verdict_str:+$verdict_str }FAIL=$v_fail"
  [[ "$v_approve" -gt 0 ]] && verdict_str="${verdict_str:+$verdict_str }APPROVE=$v_approve"
  [[ "$v_reqchg"  -gt 0 ]] && verdict_str="${verdict_str:+$verdict_str }REQUEST_CHANGES=$v_reqchg"
  [[ -z "$verdict_str" ]] && verdict_str="(none)"

  tok_label="$tok_sum"; [[ "$tok_partial" -eq 1 ]] && tok_label="$tok_sum (partial)"
  dur_label="${dur_sum}ms"; [[ "$dur_partial" -eq 1 ]] && dur_label="${dur_sum}ms (partial)"

  printf 'run %s  [loop %s]  %s\n' "$rid" "${loop_id:-?}" "$flag"
  printf '  spans: %s   phases: %s\n' "$n_spans" "${phases:-(none)}"
  printf '  status: %s\n' "$status_str"
  printf '  verdict: %s\n' "$verdict_str"
  printf '  tokens: %s   duration: %s\n' "$tok_label" "$dur_label"
  printf '  window: %s → %s\n' "${ts_min:-?}" "${ts_max:-?}"
done
