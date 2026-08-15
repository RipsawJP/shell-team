#!/usr/bin/env bash
# derive-populations.sh — turn a hand-derived set delta / population total /
# bucket split into a tool's output a record embeds verbatim (T-1071; issue
# #268's helper half; .shell-team/specs/T-1071-record-set-derivation.md).
#
# Problem this replaces: five adverse gate rounds in T-1065 all landed on one
# root-cause class — set arithmetic (deltas, populations, bucket splits)
# performed by eye at the moment record prose was written, never in the
# deliverable itself. This script makes that arithmetic a command's own
# output: it runs two to eight named population-extraction commands under a
# pinned collation and emits one delimited derivation block — per-set status
# and counts, a union total, and a gap-free, overlap-free, verbatim,
# LC_ALL=C-ordered membership partition — that a record's `- reproduce:` line
# then makes re-derivable by anyone who runs the same command again.
#
# What the block makes impossible by construction, not by care:
#   - a stated total disagreeing with its own listing (the union count and
#     every bucket count are read back from the SAME partition that is
#     printed, never computed twice by two different code paths);
#   - a listing that silently drops a member (every union item is placed in
#     exactly one bucket by construction — the partition is built from one
#     pass over a per-item "which sets contain this" tag list, so there is no
#     code path that can both omit an item and also count it in the union);
#   - a failed command read as an empty set (a command's own exit status is
#     recorded on its own `- set:` line; an unaccepted status refuses the
#     WHOLE derivation with a non-zero exit before anything is printed, and
#     an accepted status with no output is reported as `lines: 0 — items: 0`,
#     never silently folded into "the command must have meant zero").
#
# Grammar (byte-exact; see the spec's AC2 for the authoritative check):
#   <!-- BEGIN derivation: <label> -->
#   - derived-by: bin/derive-populations.sh
#   - locale: LC_ALL=C
#   - set: <name> — status: <n> — lines: <n> — items: <n> — command: <cmd>   (one per --set, declaration order; command is the LAST field on
#                                                                              purpose — a separator inside a caller's own command text can never
#                                                                              forge a field, the same ` — `-separated-with-free-form-field-last
#                                                                              discipline bin/retro-inputs.sh's ledger already uses)
#   - union: items: <n>
#   - bucket: <sig> — items: <n>                                             (one per non-empty membership signature, LC_ALL=C order of <sig>;
#       - <item>                                                              <sig> is the +-joined set names, in DECLARATION order, of every set
#       - <item>                                                              containing that item — followed by its items, LC_ALL=C order)
#   <!-- END derivation: <label> -->
#
# `lines` is the raw count of everything the set's command emitted (including
# duplicates and blank lines, and counting a final line even when the
# command's output carries no trailing newline); `items` is the distinct
# NON-EMPTY subset of it, so a de-duplication is visible in the block rather
# than silent. A caller who needs to recompute the union/dedupe cost visible
# looks at the gap between `lines` and `items` on any one set's own line.
#
# Exit codes (never conflated — 1 is about the INPUT's content, 2 is about
# the INVOCATION):
#   0  the derivation block was written to stdout
#   1  refusal — a set command's own exit status was not accepted, or an
#      item contains a carriage return or any other control character
#      (never reported as an empty set, and stdout is empty in both cases)
#   2  usage error — a bad invocation: an unknown flag, a missing --label,
#      fewer than two or more than eight --set values, two --set values
#      sharing a name, or a --set command whose text contains a newline
#      (stdout is empty)
#
# Zero-dependency floor this task inherits from bin/team-paths.sh: bash 3.2
# (no mapfile/readarray/declare -A/coproc/;;&/[[ -v ]]/case-modification
# parameter expansion) plus coreutils and POSIX awk only — no gawk-only
# extension, no perl/python/jq/yq, no grep -P. The collation is pinned to
# LC_ALL=C for the WHOLE run (this script's own export, below) precisely so
# every --set command's own sort/comm/grep calls run under the same
# collation this script's own union/bucket arithmetic uses — a caller's
# ambient locale never reaches the comparison (AC6).
#
# The signature space is exponential in the set count, so at most eight
# --set values are accepted; a ninth is a usage error (exit 2) by design,
# not a limit this script works around.
#
# The markers exist for a second reason beyond delimiting the block: they
# are the schema anchor a carved-out fast-follow refusal-checker keys on
# (see the spec's Non-goals) — decoration now, load-bearing later.

set -euo pipefail

# Force the pinned collation for this process and every child it spawns
# (including a caller's own --set command) — never the invoking shell's
# ambient locale. This one export is what makes AC6's LC_ALL=C-vs-UTF-8
# byte-identity hold: both runs converge here regardless of what the
# invoking shell had set.
export LC_ALL=C

PROG="derive-populations"
# The em dash (U+2014, UTF-8 e2 80 94) the block's grammar uses as its field
# separator — built once via ANSI-C quoting rather than typed as a literal
# multibyte character inside this file's own source, so the separator's
# exact bytes are visibly pinned at the point of use.
EM=$'\xe2\x80\x94'

die_usage() {
  printf '%s: %s\n' "$PROG" "$1" >&2
  exit 2
}

die_refuse() {
  printf '%s: %s\n' "$PROG" "$1" >&2
  exit 1
}

print_help() {
  cat <<'EOF'
Usage:
  derive-populations.sh --label <label> --set <name>=<command> --set <name>=<command> [--set <name>=<command> ...] [--accept-status <name>=<csv>] [--accept-status ...]
  derive-populations.sh --help

Runs two to eight named population-extraction commands, each captured under
a pinned LC_ALL=C collation, and emits one delimited derivation block to
stdout: a line per set (its own accepted exit status, raw line count,
distinct non-empty item count and the command itself), a union total, and a
gap-free, overlap-free membership partition — every distinct item placed in
exactly one bucket section, sections ordered by membership signature, items
within a section listed verbatim and sorted, both under LC_ALL=C order.

Flags:
  --label <label>              label carried by the BEGIN/END derivation
                                marker comments this block is wrapped in
  --set <name>=<command>       one named population-extraction command
                                (two to eight required; declaration order is
                                preserved on the --set lines and inside every
                                bucket signature)
  --accept-status <name>=<csv> declare additional exit statuses accepted for
                                one named set, beyond the default of 0 (a
                                comma-separated list — the "git grep exits 1
                                for no match" case this flag exists for)
  --help, -h                   show this help and exit 0

Exit codes:
  0  the derivation block was written to stdout
  1  refusal about the input's CONTENT — an unaccepted set exit status, or
     an item containing a carriage return or any other control character
     (stdout is empty; nothing is ever printed as a false empty set)
  2  usage error about the INVOCATION — an unknown flag, a missing --label,
     fewer than two or more than eight --set values, two --set values
     sharing a name, or a --set command whose text contains a newline
     (stdout is empty)

The collation is pinned to LC_ALL=C for this whole run, overriding whatever
locale the caller's own shell had set, and the emitted block records this
itself on its own `- locale: LC_ALL=C` line.
EOF
}

LABEL=""
SET_NAMES=()
SET_CMDS=()
ACCEPT_NAMES=()
ACCEPT_CSVS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --label)
      [ "$#" -ge 2 ] || die_usage "--label requires a value"
      shift
      LABEL="$1"
      shift
      ;;
    --set)
      [ "$#" -ge 2 ] || die_usage "--set requires a value"
      shift
      val="$1"
      case "$val" in
        *$'\n'*)
          die_usage "a --set command must not contain a newline (the emitted block is line-oriented): $val"
          ;;
      esac
      case "$val" in
        *=*) ;;
        *) die_usage "--set value must be NAME=COMMAND: $val" ;;
      esac
      name="${val%%=*}"
      cmd="${val#*=}"
      [ -n "$name" ] || die_usage "--set name must not be empty: $val"
      SET_NAMES+=("$name")
      SET_CMDS+=("$cmd")
      shift
      ;;
    --accept-status)
      [ "$#" -ge 2 ] || die_usage "--accept-status requires a value"
      shift
      aval="$1"
      case "$aval" in
        *=*) ;;
        *) die_usage "--accept-status value must be NAME=CSV: $aval" ;;
      esac
      ACCEPT_NAMES+=("${aval%%=*}")
      ACCEPT_CSVS+=("${aval#*=}")
      shift
      ;;
    --*)
      die_usage "unknown flag: $1"
      ;;
    *)
      die_usage "unexpected argument: $1"
      ;;
  esac
done

[ -n "$LABEL" ] || die_usage "missing required --label"

n=${#SET_NAMES[@]}
[ "$n" -ge 2 ] || die_usage "at least two --set values are required (got $n)"
[ "$n" -le 8 ] || die_usage "at most eight --set values are accepted (got $n) — the membership-signature space is exponential in the set count"

# Duplicate --set name check (n is at least 2, so this loop body always runs
# at least once with real work to do).
i=0
while [ "$i" -lt "$n" ]; do
  j=$((i + 1))
  while [ "$j" -lt "$n" ]; do
    if [ "${SET_NAMES[$i]}" = "${SET_NAMES[$j]}" ]; then
      die_usage "duplicate --set name: ${SET_NAMES[$i]}"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/derive-populations.XXXXXX")" || die_usage "cannot create a scratch directory under \${TMPDIR:-/tmp}"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$WORKDIR" 2>/dev/null || true; }
trap cleanup EXIT

# accepted_statuses <name> — prints the accept-list for <name>: "0" plus
# every csv this name was declared against via --accept-status, comma-joined.
accepted_statuses() {
  local nm="$1" out="0" k=0
  while [ "$k" -lt "${#ACCEPT_NAMES[@]}" ]; do
    if [ "${ACCEPT_NAMES[$k]}" = "$nm" ]; then
      out="$out,${ACCEPT_CSVS[$k]}"
    fi
    k=$((k + 1))
  done
  printf '%s' "$out"
}

# status_ok <status> <csv> — true iff <status> appears in the comma-separated
# <csv> list.
status_ok() {
  local want="$1" csv="$2" tok
  local IFS=','
  # shellcheck disable=SC2086 # intentional IFS-driven word split of a csv list
  for tok in $csv; do
    [ "$tok" = "$want" ] && return 0
  done
  return 1
}

STATUSES=()
LINES_COUNTS=()
ITEMS_COUNTS=()

idx=0
while [ "$idx" -lt "$n" ]; do
  name="${SET_NAMES[$idx]}"
  cmd="${SET_CMDS[$idx]}"
  rawfile="$WORKDIR/raw.$idx"

  if bash -c "$cmd" >"$rawfile" 2>"$WORKDIR/stderr.$idx"; then
    status=0
  else
    status=$?
  fi

  accept_csv="$(accepted_statuses "$name")"
  if ! status_ok "$status" "$accept_csv"; then
    die_refuse "set '$name' exited with unaccepted status $status (declare it with --accept-status $name=$status if this is a legitimate outcome, e.g. git grep's exit 1 for no match): $cmd"
  fi

  lines="$(awk 'END { print NR + 0 }' "$rawfile")"

  nonblank="$WORKDIR/nonblank.$idx"
  grep -v '^$' "$rawfile" >"$nonblank" 2>/dev/null || true
  itemsfile="$WORKDIR/items.$idx"
  sort -u "$nonblank" >"$itemsfile"

  if grep -q '[[:cntrl:]]' "$itemsfile" 2>/dev/null; then
    die_refuse "set '$name' produced an item containing a control character (a carriage return or similar) — this helper never mangles or silently drops such an item, so the whole derivation is refused instead"
  fi

  items="$(grep -c . "$itemsfile" 2>/dev/null || true)"
  [ -n "$items" ] || items=0

  STATUSES+=("$status")
  LINES_COUNTS+=("$lines")
  ITEMS_COUNTS+=("$items")

  idx=$((idx + 1))
done

# Tag every item with the index of every set it belongs to: one row per
# (item, set) membership, built by iterating the per-set item files in
# declaration order — an empty set's file contributes zero rows, which is
# exactly right (it belongs to nothing).
: >"$WORKDIR/tags"
idx=0
while [ "$idx" -lt "$n" ]; do
  awk -v tag="$idx" '{ print $0 "\t" tag }' "$WORKDIR/items.$idx" >>"$WORKDIR/tags"
  idx=$((idx + 1))
done

# Collapse the per-(item, set) rows above into one row per DISTINCT item,
# carrying every set index it was tagged with (comma-joined, in ascending —
# i.e. declaration — order, since the tags file above was built in that same
# order). This is the ONE place membership is computed; the union count and
# every bucket both read back from its output rather than being derived a
# second, independent way.
awk -F'\t' '
  {
    item = $1; tagidx = $2
    if (!(item in seen)) { seen[item] = 1; order[++cnt] = item }
    memb[item] = memb[item] tagidx ","
  }
  END {
    for (i = 1; i <= cnt; i++) print order[i] "\t" memb[order[i]]
  }
' "$WORKDIR/tags" >"$WORKDIR/membership"

# Turn each (item, idx-list) row into (signature, item), where signature is
# the +-joined set NAMES (declaration order) the idx-list names.
: >"$WORKDIR/sig-item"
while IFS=$'\t' read -r item idxlist; do
  [ -n "$item" ] || continue
  sig=""
  old_ifs="$IFS"
  IFS=','
  for tok in $idxlist; do
    [ -n "$tok" ] || continue
    nm="${SET_NAMES[$tok]}"
    if [ -z "$sig" ]; then
      sig="$nm"
    else
      sig="$sig+$nm"
    fi
  done
  IFS="$old_ifs"
  printf '%s\t%s\n' "$sig" "$item" >>"$WORKDIR/sig-item"
done <"$WORKDIR/membership"

# One full-line sort orders BOTH axes at once: tab (0x09) sorts below every
# ordinary set-name / '+' byte, so lines with the same signature sort
# contiguously (grouping buckets), and within a tied signature the tie is
# broken by the item field itself (ordering items inside a bucket) — all
# under the same LC_ALL=C collation this whole run is pinned to.
sort "$WORKDIR/sig-item" >"$WORKDIR/sig-item.sorted"

union_count="$(grep -c . "$WORKDIR/sig-item.sorted" 2>/dev/null || true)"
[ -n "$union_count" ] || union_count=0

# ---------------------------------------------------------------------------
# Emit the block. Nothing above this point ever wrote to stdout, so every
# refusal above (exit 1 or exit 2) leaves stdout empty by construction.
# ---------------------------------------------------------------------------
printf '<!-- BEGIN derivation: %s -->\n' "$LABEL"
printf -- '- derived-by: bin/derive-populations.sh\n'
printf -- '- locale: LC_ALL=C\n'

idx=0
while [ "$idx" -lt "$n" ]; do
  printf -- '- set: %s %s status: %s %s lines: %s %s items: %s %s command: %s\n' \
    "${SET_NAMES[$idx]}" "$EM" "${STATUSES[$idx]}" "$EM" "${LINES_COUNTS[$idx]}" "$EM" "${ITEMS_COUNTS[$idx]}" "$EM" "${SET_CMDS[$idx]}"
  idx=$((idx + 1))
done

printf -- '- union: items: %s\n' "$union_count"

cut -f1 "$WORKDIR/sig-item.sorted" | uniq >"$WORKDIR/distinct-sigs"
while IFS= read -r sig; do
  [ -n "$sig" ] || continue
  bucket_items="$WORKDIR/bucket-items"
  SIG="$sig" awk -F'\t' '$1 == ENVIRON["SIG"] { print $2 }' "$WORKDIR/sig-item.sorted" >"$bucket_items"
  cnt="$(grep -c . "$bucket_items" 2>/dev/null || true)"
  [ -n "$cnt" ] || cnt=0
  printf -- '- bucket: %s %s items: %s\n' "$sig" "$EM" "$cnt"
  sed 's/^/  - /' "$bucket_items"
done <"$WORKDIR/distinct-sigs"

printf '<!-- END derivation: %s -->\n' "$LABEL"

exit 0
