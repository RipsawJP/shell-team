#!/usr/bin/env bash
# aggregate-verdicts.sh — reduce N per-instance fan-out part files into one
# authoritative verdict block, or refuse (T-1074; bin/derive-populations.sh's
# own sibling tool; .shell-team/specs/T-1074-fanout-orchestration.md).
#
# Problem this closes: docs/loop-engineering/phase-multiplexing.md measured a
# real 43.84% wall-clock saving from splitting one phase's own mechanically-
# enumerable, read-only verification work (e.g. one `bash bin/check-acs.sh
# <spec>` run per spec) across N instances of one role, and proved the
# aggregation safe (a byte-identical verdict multiset across every swept
# degree) — but declined to build the mechanism that would actually launch N
# instances and reduce their verdicts (its own `no-mechanism` verification
# class). This script is the reduction half of that mechanism: it never
# launches anything itself, it only combines N already-written part files
# into one authoritative verdict, or refuses outright rather than ever
# promoting a partial, incomplete or malformed result.
#
# Part-file grammar (byte-exact; ` — ` is a space, U+2014 EM DASH, space):
#   - unit: <unit-id>
#   - verdict: <unit-id> — <payload>
#   - sentinel: <unit-id> — exit=<n> no-verdict-lines
# Blank lines are ignored; every other line must match exactly one of the
# three shapes above. <unit-id> is a non-empty string free of control
# characters and free of the ` — ` separator; <payload> is free-form and, as
# the LAST field on its own line, can never forge a field — the same
# discipline bin/derive-populations.sh's own COMMAND field uses. A `- unit:`
# line is a CLAIM: it declares this instance was assigned that unit,
# independently of whether the unit produced any output, so coverage is
# decidable even when a unit legitimately produces nothing. A claimed unit
# with zero verdict lines carries exactly one `- sentinel:` line in the
# measured shape (phase-multiplexing.md:111 — the pilot's own real instance,
# `design-note-T-1012.md`, recorded `SENTINEL: exit=2 no-verdict-lines`
# identically across ten arm/rep runs); a sentinel and a verdict for the same
# unit is a refusal, because the sentinel asserts an absence the verdict
# contradicts.
#
# Reconciliation is by VALUE, as a multiset, ordered by one LC_ALL=C sort
# over whole lines — never by row position, because a spec quoting a
# duplicate-labelled AC inside a fenced illustrative example (a real,
# documented hazard in this corpus) would otherwise turn positional pairing
# into a spurious difference that is an artefact of ordering, not of
# concurrency. A duplicate verdict PAYLOAD is therefore legitimate input and
# is preserved verbatim; the only duplicate this tool refuses is a duplicate
# CLAIM (the same unit assigned twice, within one part or across parts),
# which is a partition defect rather than a datum.
#
# The population is fixed by the caller before any instance is launched and
# is never re-selected here after a verdict is seen; this script only
# verifies the population it is handed is well-formed (non-empty, no
# duplicate entries) and that every part's claims disjointly and exhaustively
# cover it. It does not choose or re-choose the population itself.
#
# The output is one delimited block: an outer `fanout-verdict` marker pair
# wrapping metadata (`- aggregated-by:`, `- locale:`, one `- part:` line per
# declared part) plus a nested `verdict-region` marker pair holding ONLY the
# `- summary:` line and the sorted verdict/sentinel multiset — with the
# `- attribution:` lines (one per unit, naming the instance that produced
# it) sitting OUTSIDE that inner region. Putting an instance id inside the
# region would silently break partition-independence, since the region must
# stay byte-identical under every disjoint, exhaustive partition of the same
# population and under any ordering of records within a part or of the parts
# themselves — that property is what licenses reducing N partial verdicts to
# one authoritative verdict at all.
#
# Exit codes (never conflated — 1 is a refusal about the PARTS' own CONTENT,
# 2 is a usage error about the INVOCATION, 3 is a refusal because the
# fan-out is INCOMPLETE, whose remedy is to re-run the missing assignments
# against the same fixed population rather than to re-read the data):
#   0  the aggregated fanout-verdict block was written to stdout
#   1  refusal about the parts' content — empty-population,
#      duplicate-population-entry, out-of-population, duplicate-claim,
#      unclaimed-record, malformed-record, control-character,
#      missing-sentinel, sentinel-with-verdicts (stdout is empty)
#   2  usage error about the invocation — usage (stdout is empty)
#   3  refusal because the fan-out is incomplete — missing-part, empty-part,
#      uncovered-unit (stdout is empty; a missing or empty part file is exit
#      3, not exit 1, because an instance that died and an instance that
#      wrote nothing are the same operational fact: the fan-out did not
#      finish)
#
# On every non-zero exit, stdout is empty: nothing is printed to stdout
# until every validation below has passed, so no partial, incomplete or
# malformed verdict is ever promoted to the authoritative one. Every refusal
# prints exactly one classified line on stderr, in the shape
# `aggregate-verdicts: <class>: <detail>`, with <class> drawn from the
# thirteen tokens named above and from no other.
#
# Zero-dependency floor (bin/team-paths.sh's own, inherited via
# bin/derive-populations.sh): bash 3.2 (no mapfile/declare -A/coproc/;;&/
# [[ -v ]]/case-modification parameter expansion) plus coreutils and POSIX
# awk only — no jq/perl/python/yq, no grep -P. The collation is pinned to
# LC_ALL=C for the whole run (this script's own export, below), exactly as
# bin/derive-populations.sh pins it at its own line 103, so a caller's
# ambient locale never reaches the comparison.

set -euo pipefail

export LC_ALL=C

PROG="aggregate-verdicts"
# The em dash (U+2014, UTF-8 e2 80 94) the part-file grammar uses as its
# field separator — built once via ANSI-C quoting rather than typed as a
# literal multibyte character in this file's own source, the same technique
# bin/derive-populations.sh uses at its own line 110.
EM=$'\xe2\x80\x94'
SEP=" $EM "

# die <exit-code> <class> <detail> — the one closed stderr shape every
# refusal in this script uses. The write itself is best-effort (`|| true`)
# so a caller with a closed stderr can never steal this call's own exit code
# via errexit — the same guard bin/derive-populations.sh's die_usage/
# die_refuse apply for the identical reason.
die() {
  printf '%s: %s: %s\n' "$PROG" "$2" "$3" >&2 || true
  exit "$1"
}

print_help() {
  cat <<'EOF'
Usage:
  aggregate-verdicts.sh --label <label> --population <file> --part <name>=<file> [--part <name>=<file> ...]
  aggregate-verdicts.sh --help

Reduces N per-instance fan-out part files to one authoritative
fanout-verdict block on stdout, or refuses with a classified exit code and
empty stdout.

Flags:
  --label <label>        label carried by the BEGIN/END fanout-verdict and
                          verdict-region marker comments this block is
                          wrapped in; must match ^[A-Za-z0-9][A-Za-z0-9_-]*$
  --population <file>    the fixed unit population, one unit id per line
  --part <name>=<file>   one instance's own part file (at least one
                          required); <name> must match ^[a-z][a-z0-9-]*$
                          (the same grammar bin/log-run.sh's --instance
                          flag validates against)
  --help, -h              show this help and exit 0

Exit codes:
  0  the aggregated fanout-verdict block was written to stdout
  1  refusal about the parts' content (empty-population,
     duplicate-population-entry, out-of-population, duplicate-claim,
     unclaimed-record, malformed-record, control-character,
     missing-sentinel, sentinel-with-verdicts)
  2  usage error about the invocation (usage)
  3  refusal because the fan-out is incomplete (missing-part, empty-part,
     uncovered-unit) — the remedy is to re-run the missing assignments
     against the same fixed population, never to re-read the data
EOF
}

LABEL_RE='^[A-Za-z0-9][A-Za-z0-9_-]*$'
INSTANCE_RE='^[a-z][a-z0-9-]*$'
SENTINEL_SUFFIX_RE='^exit=[0-9]+ no-verdict-lines$'

LABEL=""
POP=""
PART_NAMES=()
PART_FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --label)
      [ "$#" -ge 2 ] || die 2 usage "--label requires a value"
      shift
      LABEL="$1"
      shift
      ;;
    --population)
      [ "$#" -ge 2 ] || die 2 usage "--population requires a value"
      shift
      POP="$1"
      shift
      ;;
    --part)
      [ "$#" -ge 2 ] || die 2 usage "--part requires a value"
      shift
      val="$1"
      case "$val" in
        *=*) ;;
        *) die 2 usage "--part value must be NAME=FILE: $val" ;;
      esac
      pname="${val%%=*}"
      pfile="${val#*=}"
      [[ "$pname" =~ $INSTANCE_RE ]] || die 2 usage "--part name must match ^[a-z][a-z0-9-]*\$ (bin/log-run.sh's own --instance grammar): $pname"
      PART_NAMES+=("$pname")
      PART_FILES+=("$pfile")
      shift
      ;;
    --*)
      die 2 usage "unknown flag: $1"
      ;;
    *)
      die 2 usage "unexpected argument: $1"
      ;;
  esac
done

[ -n "$LABEL" ] || die 2 usage "missing required --label"
[[ "$LABEL" =~ $LABEL_RE ]] || die 2 usage "--label must match ^[A-Za-z0-9][A-Za-z0-9_-]*\$: $LABEL"
[ -n "$POP" ] || die 2 usage "missing required --population"

n=${#PART_NAMES[@]}
[ "$n" -ge 1 ] || die 2 usage "at least one --part is required"

# Duplicate --part name check (n is at least 1, so a duplicate needs n>=2).
i=0
while [ "$i" -lt "$n" ]; do
  j=$((i + 1))
  while [ "$j" -lt "$n" ]; do
    if [ "${PART_NAMES[$i]}" = "${PART_NAMES[$j]}" ]; then
      die 2 usage "duplicate --part name: ${PART_NAMES[$i]}"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done

[ -r "$POP" ] || die 2 usage "population file not readable: $POP"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/aggregate-verdicts.XXXXXX")" || die 2 usage "cannot create a scratch directory under \${TMPDIR:-/tmp}"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$WORKDIR" 2>/dev/null || true; }
trap cleanup EXIT

has_control_char() {
  grep -q '[[:cntrl:]]' "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Phase 0 — validate the fixed population: non-empty, free of control
# characters, free of a duplicate entry.
# ---------------------------------------------------------------------------
grep -v '^[[:space:]]*$' "$POP" > "$WORKDIR/pop.raw" 2>/dev/null || true
popcount="$(grep -c . "$WORKDIR/pop.raw" 2>/dev/null || true)"
[ -n "$popcount" ] || popcount=0
if [ "$((10#$popcount))" -eq 0 ]; then
  die 1 empty-population "population file has no entries: $POP"
fi
if has_control_char "$WORKDIR/pop.raw"; then
  die 1 control-character "population file $POP contains a control character"
fi
sort "$WORKDIR/pop.raw" > "$WORKDIR/pop.sorted"
uniq -d "$WORKDIR/pop.sorted" > "$WORKDIR/pop.dupes"
dupcount="$(grep -c . "$WORKDIR/pop.dupes" 2>/dev/null || true)"
[ -n "$dupcount" ] || dupcount=0
if [ "$((10#$dupcount))" -gt 0 ]; then
  die 1 duplicate-population-entry "population file $POP repeats an entry: $(head -n 1 "$WORKDIR/pop.dupes")"
fi
sort -u "$WORKDIR/pop.raw" > "$WORKDIR/pop.set"

# ---------------------------------------------------------------------------
# Phase 1 — per-part existence/emptiness, then per-line shape validation.
# Nothing here writes to stdout.
# ---------------------------------------------------------------------------
: > "$WORKDIR/records.all"
: > "$WORKDIR/verdictunits.all"
: > "$WORKDIR/sentinelunits.all"
V_TOTAL=0
S_TOTAL=0

i=0
while [ "$i" -lt "$n" ]; do
  pname="${PART_NAMES[$i]}"
  pfile="${PART_FILES[$i]}"

  if [ ! -e "$pfile" ]; then
    die 3 missing-part "part '$pname' file not found: $pfile"
  fi
  if [ ! -s "$pfile" ]; then
    die 3 empty-part "part '$pname' file is empty: $pfile"
  fi

  grep -v '^[[:space:]]*$' "$pfile" > "$WORKDIR/part.$i.raw" 2>/dev/null || true
  if has_control_char "$WORKDIR/part.$i.raw"; then
    die 1 control-character "part '$pname' ($pfile) contains a control character"
  fi

  : > "$WORKDIR/claims.$i"
  : > "$WORKDIR/recordunits.$i"

  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    case "$line" in
      "- unit: "*)
        id="${line#'- unit: '}"
        [ -n "$id" ] || die 1 malformed-record "part '$pname' ($pfile) has a '- unit:' line with an empty unit id"
        case "$id" in
          *"$SEP"*) die 1 malformed-record "part '$pname' ($pfile) has a unit id containing the ' — ' separator: $id" ;;
        esac
        printf '%s\n' "$id" >> "$WORKDIR/claims.$i"
        ;;
      "- verdict: "*)
        rest="${line#'- verdict: '}"
        case "$rest" in
          *"$SEP"*) : ;;
          *) die 1 malformed-record "part '$pname' ($pfile) has a '- verdict:' line missing the ' — ' separator: $line" ;;
        esac
        id="${rest%%"$SEP"*}"
        [ -n "$id" ] || die 1 malformed-record "part '$pname' ($pfile) has a '- verdict:' line with an empty unit id: $line"
        printf '%s\n' "$line" >> "$WORKDIR/records.all"
        printf '%s\n' "$id" >> "$WORKDIR/recordunits.$i"
        printf '%s\n' "$id" >> "$WORKDIR/verdictunits.all"
        V_TOTAL=$((V_TOTAL + 1))
        ;;
      "- sentinel: "*)
        rest="${line#'- sentinel: '}"
        case "$rest" in
          *"$SEP"*) : ;;
          *) die 1 malformed-record "part '$pname' ($pfile) has a '- sentinel:' line missing the ' — ' separator: $line" ;;
        esac
        id="${rest%%"$SEP"*}"
        suffix="${rest#*"$SEP"}"
        [ -n "$id" ] || die 1 malformed-record "part '$pname' ($pfile) has a '- sentinel:' line with an empty unit id: $line"
        [[ "$suffix" =~ $SENTINEL_SUFFIX_RE ]] || die 1 malformed-record "part '$pname' ($pfile) has a '- sentinel:' line whose suffix does not match 'exit=<n> no-verdict-lines': $line"
        printf '%s\n' "$line" >> "$WORKDIR/records.all"
        printf '%s\n' "$id" >> "$WORKDIR/recordunits.$i"
        printf '%s\n' "$id" >> "$WORKDIR/sentinelunits.all"
        S_TOTAL=$((S_TOTAL + 1))
        ;;
      *)
        die 1 malformed-record "part '$pname' ($pfile) has a line matching none of the three record shapes: $line"
        ;;
    esac
  done < "$WORKDIR/part.$i.raw"

  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Phase 2 — cross-part checks, in this order: duplicate claims (within a
# part, then across parts), out-of-population, unclaimed-record, sentinel
# exclusivity, then coverage completeness (uncovered-unit) last, since it is
# an exit-3 "incomplete" refusal rather than an exit-1 content defect.
# ---------------------------------------------------------------------------

# 2a — duplicate claim WITHIN one part.
i=0
while [ "$i" -lt "$n" ]; do
  sort "$WORKDIR/claims.$i" > "$WORKDIR/claims.$i.sorted"
  uniq -d "$WORKDIR/claims.$i.sorted" > "$WORKDIR/claims.$i.dup"
  dc="$(grep -c . "$WORKDIR/claims.$i.dup" 2>/dev/null || true)"
  [ -n "$dc" ] || dc=0
  if [ "$((10#$dc))" -gt 0 ]; then
    die 1 duplicate-claim "unit '$(head -n 1 "$WORKDIR/claims.$i.dup")' is claimed twice within part '${PART_NAMES[$i]}'"
  fi
  sort -u "$WORKDIR/claims.$i" > "$WORKDIR/claims.$i.uniq"
  i=$((i + 1))
done

# 2b — duplicate claim ACROSS parts.
: > "$WORKDIR/allclaims.raw"
i=0
while [ "$i" -lt "$n" ]; do
  cat "$WORKDIR/claims.$i.uniq" >> "$WORKDIR/allclaims.raw"
  i=$((i + 1))
done
sort "$WORKDIR/allclaims.raw" > "$WORKDIR/allclaims.sorted"
uniq -d "$WORKDIR/allclaims.sorted" > "$WORKDIR/allclaims.dup"
adc="$(grep -c . "$WORKDIR/allclaims.dup" 2>/dev/null || true)"
[ -n "$adc" ] || adc=0
if [ "$((10#$adc))" -gt 0 ]; then
  die 1 duplicate-claim "unit '$(head -n 1 "$WORKDIR/allclaims.dup")' is claimed by more than one part"
fi
sort -u "$WORKDIR/allclaims.raw" > "$WORKDIR/allclaims.set"

# 2c — out-of-population: every claim must name a population member.
comm -23 "$WORKDIR/allclaims.set" "$WORKDIR/pop.set" > "$WORKDIR/oop" 2>/dev/null || true
oopc="$(grep -c . "$WORKDIR/oop" 2>/dev/null || true)"
[ -n "$oopc" ] || oopc=0
if [ "$((10#$oopc))" -gt 0 ]; then
  die 1 out-of-population "claimed unit '$(head -n 1 "$WORKDIR/oop")' is not in the population"
fi

# 2d — unclaimed-record: every record's unit must be claimed WITHIN that
# same part.
i=0
while [ "$i" -lt "$n" ]; do
  if [ -s "$WORKDIR/recordunits.$i" ]; then
    sort -u "$WORKDIR/recordunits.$i" > "$WORKDIR/recordunits.$i.uniq"
    comm -23 "$WORKDIR/recordunits.$i.uniq" "$WORKDIR/claims.$i.uniq" > "$WORKDIR/unclaimed.$i" 2>/dev/null || true
    uc="$(grep -c . "$WORKDIR/unclaimed.$i" 2>/dev/null || true)"
    [ -n "$uc" ] || uc=0
    if [ "$((10#$uc))" -gt 0 ]; then
      die 1 unclaimed-record "part '${PART_NAMES[$i]}' has a record for unit '$(head -n 1 "$WORKDIR/unclaimed.$i")' that this part never claimed"
    fi
  fi
  i=$((i + 1))
done

# 2e — sentinel exclusivity: for every claimed unit, either it has one or
# more verdicts and no sentinel, or zero verdicts and exactly one sentinel —
# never both absent and never both present.
while IFS= read -r unit; do
  [ -n "$unit" ] || continue
  v="$(grep -Fxc -- "$unit" "$WORKDIR/verdictunits.all" 2>/dev/null || true)"
  [ -n "$v" ] || v=0
  s="$(grep -Fxc -- "$unit" "$WORKDIR/sentinelunits.all" 2>/dev/null || true)"
  [ -n "$s" ] || s=0
  if [ "$((10#$v))" -eq 0 ] && [ "$((10#$s))" -eq 0 ]; then
    die 1 missing-sentinel "unit '$unit' has no verdict and no sentinel"
  fi
  if [ "$((10#$v))" -gt 0 ] && [ "$((10#$s))" -gt 0 ]; then
    die 1 sentinel-with-verdicts "unit '$unit' has both a sentinel and at least one verdict"
  fi
done < "$WORKDIR/allclaims.set"

# 2f — uncovered-unit: a population unit no part claimed at all. This is
# checked LAST and refuses with exit 3, not exit 1: the fan-out simply did
# not finish, which is a different operational fact from a content defect.
comm -23 "$WORKDIR/pop.set" "$WORKDIR/allclaims.set" > "$WORKDIR/uncovered" 2>/dev/null || true
uncc="$(grep -c . "$WORKDIR/uncovered" 2>/dev/null || true)"
[ -n "$uncc" ] || uncc=0
if [ "$((10#$uncc))" -gt 0 ]; then
  die 3 uncovered-unit "population unit '$(head -n 1 "$WORKDIR/uncovered")' was not claimed by any part"
fi

# ---------------------------------------------------------------------------
# Phase 3 — build the attribution mapping (unit -> the one part that
# claimed it) and emit the aggregated block. Nothing above this point ever
# wrote to stdout, so every refusal above leaves stdout empty by
# construction.
# ---------------------------------------------------------------------------
: > "$WORKDIR/attribution.raw"
i=0
while [ "$i" -lt "$n" ]; do
  pname="${PART_NAMES[$i]}"
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    printf '%s\t%s\n' "$unit" "$pname" >> "$WORKDIR/attribution.raw"
  done < "$WORKDIR/claims.$i.uniq"
  i=$((i + 1))
done
sort "$WORKDIR/attribution.raw" > "$WORKDIR/attribution.sorted"
sort "$WORKDIR/records.all" > "$WORKDIR/records.sorted"

printf '<!-- BEGIN fanout-verdict: %s -->\n' "$LABEL"
printf -- '- aggregated-by: bin/aggregate-verdicts.sh\n'
printf -- '- locale: LC_ALL=C\n'

i=0
while [ "$i" -lt "$n" ]; do
  printf -- '- part: %s %s %s\n' "${PART_NAMES[$i]}" "$EM" "${PART_FILES[$i]}"
  i=$((i + 1))
done

printf '<!-- BEGIN verdict-region: %s -->\n' "$LABEL"
printf -- '- summary: units: %s %s verdicts: %s %s sentinels: %s\n' "$popcount" "$EM" "$V_TOTAL" "$EM" "$S_TOTAL"
cat "$WORKDIR/records.sorted"
printf '<!-- END verdict-region: %s -->\n' "$LABEL"

while IFS= read -r attrline; do
  [ -n "$attrline" ] || continue
  unit="${attrline%%$'\t'*}"
  part="${attrline#*$'\t'}"
  printf -- '- attribution: %s %s %s\n' "$unit" "$EM" "$part"
done < "$WORKDIR/attribution.sorted"

printf '<!-- END fanout-verdict: %s -->\n' "$LABEL"

exit 0
