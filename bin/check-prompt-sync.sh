#!/usr/bin/env bash
# check-prompt-sync.sh — verify that agent/skill prompt files stay in sync with
# the canonical prompt blocks under templates/prompt-blocks/ (T-039, issue #96).
#
# Machine-parsed tokens and shared prompt discipline used to be hand-copied
# across many files and drifted silently (the repo's most frequent lesson
# pattern: a grammar's checkers/consumers not following a change). This
# checker makes the duplication VERIFIED instead of trusted:
#
#   templates/prompt-blocks/<block>.md   — the canonical text (one per block)
#   templates/prompt-blocks/registry.txt — which consumer file must carry which
#                                          block, and how (mode):
#     marker  — consumer holds exactly one
#               `<!-- BEGIN prompt-block: <name> -->` /
#               `<!-- END prompt-block: <name> -->` pair whose inner region
#               must equal the canonical file (CRLF / trailing-whitespace
#               normalized, leading/trailing blank lines ignored).
#     contain — every non-empty canonical line must appear verbatim as a
#               fixed-string substring in the consumer (tokens / core
#               sentences; role-specific tails live outside the core).
#
# check-only: this script NEVER rewrites a consumer (no generation — a
# deliberate T-039 design decision; see docs/specs/T-039-prompt-sync.md).
#
# Usage:
#   check-prompt-sync.sh [--root DIR] [--blocks-dir DIR]
#
#   --root        repo root the registry's consumer paths resolve against
#                 (default: cwd)
#   --blocks-dir  canonical blocks dir (default: <root>/templates/prompt-blocks)
#
# Exit: 0 = all consumers in sync; 1 = drift (mismatch, missing block/marker,
#       missing consumer file); 2 = usage / configuration error (bad args,
#       missing registry, unknown mode, missing canonical file).

set -euo pipefail

die() { printf 'check-prompt-sync: %s\n' "$1" >&2 || true; exit 2; }

ROOT="."
BLOCKS_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)       [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --blocks-dir) [ "$#" -ge 2 ] || die "--blocks-dir requires a value"; shift; BLOCKS_DIR="$1"; shift ;;
    --help|-h)    sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"
if [ -z "$BLOCKS_DIR" ]; then
  BLOCKS_DIR="$ROOT/templates/prompt-blocks"
fi
REGISTRY="$BLOCKS_DIR/registry.txt"
[ -r "$REGISTRY" ] || die "registry not found: $REGISTRY"

violations=0
emit() { printf 'check-prompt-sync: %s\n' "$1" >&2; violations=$((violations + 1)); }

# Normalize stdin for comparison: strip CR and trailing whitespace per line,
# then drop leading/trailing blank lines (the CRLF-trim lesson from the T-038
# review carried forward).
normalize_stdin() {
  sed -e 's/\r$//' -e 's/[[:space:]]*$//' | awk '
    { lines[NR] = $0; if ($0 != "") { if (first == 0) first = NR; last = NR } }
    END { for (i = first; i <= last && first > 0; i++) print lines[i] }
  '
}

# Marker lines are located with an awk EXACT string compare after stripping a
# trailing CR — grep -x -F would miss markers in CRLF files (same normalization
# the region comparison already applies).
marker_count() { awk -v m="$1" '{ sub(/\r$/, "") } $0 == m { n++ } END { print n + 0 }' "$2"; }
marker_line()  { awk -v m="$1" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$2"; }

check_marker() {
  local block_file="$1" consumer="$2" name begin_mark end_mark
  local begin_count end_count begin_ln end_ln
  name="$(basename "$block_file" .md)"
  begin_mark="<!-- BEGIN prompt-block: $name -->"
  end_mark="<!-- END prompt-block: $name -->"

  begin_count="$(marker_count "$begin_mark" "$consumer")"
  end_count="$(marker_count "$end_mark" "$consumer")"
  if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
    emit "$consumer: expected exactly one $name marker pair (got BEGIN=$begin_count END=$end_count)"
    return 0
  fi
  begin_ln="$(marker_line "$begin_mark" "$consumer")"
  end_ln="$(marker_line "$end_mark" "$consumer")"
  if [ "$begin_ln" -ge "$end_ln" ]; then
    emit "$consumer: $name BEGIN marker must precede END marker"
    return 0
  fi

  # Plain temp files + cmp, NOT process substitution: /dev/fd is blocked in
  # some sandboxed environments where this checker must still run.
  local tmp_region tmp_canon
  tmp_region="$(mktemp "${TMPDIR:-/tmp}/prompt-sync-region.XXXXXX")" || die "cannot create temp file (TMPDIR=${TMPDIR:-/tmp} not writable?)"
  # T-089 (#293): if the SECOND mktemp fails after the first already succeeded,
  # remove the already-created tmp_region before dying — otherwise `die`'s
  # `exit 2` leaves it behind (a leaked temp file). A `trap ... RETURN` would
  # NOT fix this: RETURN fires only on a function `return`, never on `exit`,
  # so it would not run on exactly this failure path.
  # T-089 Codex round1 Major (rework): the cleanup `rm -f` must be BEST-EFFORT
  # (`|| true`) — under `set -euo pipefail`, only the brace-group's OVERALL
  # status is protected by the outer `||`; a command INSIDE the group is still
  # subject to errexit. If the same condition that just failed mktemp (TMPDIR
  # lost writability — a condition the spec's own Input space declares
  # reachable) also makes `rm -f "$tmp_region"` itself fail, errexit would
  # terminate the script on THAT failure before `die` ever runs — losing the
  # exit-2 contract, the diagnostic message, AND still leaking tmp_region (the
  # exact two things this fix exists to prevent). `|| true` guarantees `die`
  # is always reached regardless of whether the best-effort cleanup succeeds.
  tmp_canon="$(mktemp "${TMPDIR:-/tmp}/prompt-sync-canon.XXXXXX")" || { rm -f -- "$tmp_region" || true; die "cannot create temp file (TMPDIR=${TMPDIR:-/tmp} not writable?)"; }
  awk -v b="$begin_ln" -v e="$end_ln" 'NR > b && NR < e' "$consumer" | normalize_stdin > "$tmp_region"
  normalize_stdin < "$BLOCKS_DIR/$block_file" > "$tmp_canon"
  if ! cmp -s "$tmp_region" "$tmp_canon"; then
    emit "$consumer: drift in prompt-block '$name' (region between markers != $block_file)"
  fi
  rm -f "$tmp_region" "$tmp_canon"
}

check_contain() {
  local block_file="$1" consumer="$2" line
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [ -n "$line" ] || continue
    if ! grep -qF -- "$line" "$consumer"; then
      emit "$consumer: missing required phrase from '$block_file': $line"
    fi
  done < "$BLOCKS_DIR/$block_file"
}

# --- walk the registry ---------------------------------------------------------
lineno=0
while IFS= read -r raw; do
  lineno=$((lineno + 1))
  raw="${raw%$'\r'}"
  case "$raw" in
    ''|\#*) continue ;;
  esac

  # shellcheck disable=SC2086  # intentional word-splitting of the registry row
  set -- $raw
  [ "$#" -ge 3 ] || die "registry line $lineno: need <mode> <block-file> <consumer>..."
  mode="$1"; block_file="$2"; shift 2

  case "$mode" in
    marker|contain) : ;;
    *) die "registry line $lineno: unknown mode '$mode' (marker|contain)" ;;
  esac
  [ -r "$BLOCKS_DIR/$block_file" ] || die "registry line $lineno: canonical block not found: $BLOCKS_DIR/$block_file"

  for consumer in "$@"; do
    path="$ROOT/$consumer"
    if [ ! -r "$path" ]; then
      emit "$consumer: consumer file not found (registered for '$block_file')"
      continue
    fi
    if [ "$mode" = "marker" ]; then
      check_marker "$block_file" "$path"
    else
      check_contain "$block_file" "$path"
    fi
  done
done < "$REGISTRY"

if [ "$violations" -gt 0 ]; then
  printf 'check-prompt-sync: %d violation(s)\n' "$violations" >&2 || true
  exit 1
fi
printf 'check-prompt-sync: all registered prompt blocks in sync\n'
exit 0
