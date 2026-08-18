#!/usr/bin/env bash
# check-fanout-instances.sh — the reading half of the per-instance telemetry
# discriminator (T-1082; issue #277's adoption precondition 1;
# .shell-team/specs/T-1082-telemetry-discriminator.md).
#
# Ties one fan-out's own telemetry span rows to the merged fanout-verdict
# block bin/aggregate-verdicts.sh produced for it, and refuses — a classified
# exit code, empty stdout — unless four properties hold together over a
# caller-declared scope:
#
#   presence     every span row in the declared scope carries a non-null
#                instance discriminator.
#   grammar      every discriminator, read back, conforms to the writer's
#                own grammar (bin/log-run.sh's BINDING_TOKEN_RE,
#                ^[a-z][a-z0-9-]*$) — named verbatim here, never re-derived.
#   uniqueness   no single id is claimed by rows of two different roles
#                (--span values) inside the scope; the same id on two rows
#                of the SAME role stays legal (a declared label, not a
#                per-row unique key).
#   consistency  the scope's own instance set and the aggregation block's
#                declared `- part:` name set are equal in both directions.
#
# T-1072 settled that `instance` is validated by the WRITER only and that
# bin/check-run.sh stays structural; that decision is honoured, not
# reopened, by keeping presence/grammar validation here, in a checker that
# only ever runs against a scope a caller declares to be a fan-out.
# bin/log-run.sh, bin/check-run.sh and bin/aggregate-verdicts.sh are
# consumed as they are and are never edited by this script or by anything
# it does.
#
# The scope is declared, never guessed: --telemetry <file> --run-id <id>
# --phase <phase> --aggregation <file> --label <label>, with optional
# --iteration <n> / --attempt <n> narrowers. Selection is by the required
# span-only keys the scope already names (run_id, phase, and, when given,
# iteration/attempt) — boundary-anchored on `{`/`,`, the same discipline
# bin/check-run.sh's key_present and bin/rollup-runs.sh's field_str already
# use, so a key that is a substring of a longer key, or one appearing
# inside a string value, can never match. An event row carries no `phase`
# key at all, so it is never selected by construction; NO third
# `is_span_row()` copy is written here — the two deliberately-duplicated
# implementations `tests/is-span-row-parity/` already guards (T-1011
# hazard H4) stay exactly two. A row that DOES satisfy the selector while
# carrying `"kind":"event"` is refused as `malformed-row` rather than
# silently skipped — a defect in the file, not a shape this reader may
# quietly ignore.
#
# --aggregation and --label are REQUIRED, with no degraded telemetry-only
# mode: consistency is the entire reason this checker exists, and a mode
# that skipped it would let a caller obtain a pass without it. The block is
# read by its own markers, counting `<!-- BEGIN fanout-verdict: <label> -->`
# occurrences for the requested label first: zero is `block-not-found`
# (exit 2, an invocation defect — the caller named the wrong label), two or
# more is `duplicate-block` (exit 1 — which of the two is authoritative is
# not a question a reader may answer by picking one). The `- part:` lines
# read here sit in the outer block's metadata, ABOVE the nested
# `verdict-region`; nothing inside that nested region is ever read, since
# its byte-identity under repartitioning is the property that licenses the
# aggregation at all.
#
# Exit codes (never conflated — the same three-way split
# bin/aggregate-verdicts.sh already uses):
#   0  every property held; exactly one 'check-fanout-instances: ok: ' line
#      reaches stdout, stderr is empty
#   1  a refusal about the CONTENT of the rows or the block (stdout empty)
#   2  a usage error about the INVOCATION (stdout empty)
#   3  a refusal because the fan-out is INCOMPLETE — the remedy is to
#      re-run or re-emit the missing assignment, never to re-read the data
#      (stdout empty)
#
# On every non-zero exit, stdout is empty: nothing is printed until every
# check below has passed. Every refusal prints exactly one classified line
# on stderr, `check-fanout-instances: <class>: <detail>`, <class> drawn
# from the closed vocabulary below and from no other.
#
# Class vocabulary (closed; every token below is a real `die` call site's
# own class argument, re-derived and cross-checked against this table):
#   class: usage exit=2 a malformed invocation — missing/unknown flag, an unreadable or non-regular-file path, a bad --label grammar
#   class: block-not-found exit=2 the given --label names no fanout-verdict block in the aggregation file
#   class: duplicate-block exit=1 the aggregation file carries two or more blocks for the given --label
#   class: malformed-block exit=1 a '- part:' line in the block violates the part-name grammar, or the block's own metadata is unreadable
#   class: malformed-row exit=1 a row selected by the declared scope carries the event row shape
#   class: missing-instance exit=1 a row in the declared scope carries no non-null instance discriminator
#   class: invalid-instance exit=1 a row's instance value does not conform to the writer's own grammar
#   class: instance-role-collision exit=1 one instance id is claimed by rows of two different roles inside the declared scope
#   class: unattributed-instance exit=1 an instance id in the scope's rows is declared by no '- part:' line in the block
#   class: uncovered-part exit=3 a part declared in the block has no row in the declared scope
#   class: no-rows exit=3 the declared scope selected zero span rows
#
# Check order is FIXED so a fixture carrying two defects reports
# deterministically: block parse first (block-not-found / duplicate-block /
# malformed-block), then per-row shape (malformed-row), presence
# (missing-instance), grammar (invalid-instance), uniqueness
# (instance-role-collision), unattributed ids (unattributed-instance), and
# the exit-3 coverage check LAST (no-rows, then uncovered-part) — the same
# reason bin/aggregate-verdicts.sh puts its own exit-3 check last: the
# class whose remedy differs from every other refusal's is the one
# reserved for last.
#
# Zero-dependency floor (bash 3.2 — no mapfile/readarray/declare -A/coproc/
# case-modification parameter expansion) plus coreutils and POSIX awk only;
# no jq/perl/python/yq. LC_ALL=C is pinned for the whole run (this script's
# own export below), the same discipline bin/aggregate-verdicts.sh and
# bin/derive-populations.sh already apply, so a caller's ambient locale
# never reaches a comparison.
#
# `instance` stays a DECLARED label here, exactly as `provider`/`effort`/
# `adapter` are: no semantic validation is performed or attempted (whether
# an id names a role that exists, whether two rows claiming one id really
# came from one process). This script writes, repairs, migrates or
# truncates nothing — it is read-only over every input it is given.

set -euo pipefail

export LC_ALL=C

PROG="check-fanout-instances"

# The em dash (U+2014, UTF-8 e2 80 94) both the part-file grammar and the
# aggregation block's own `- part:`/`- attribution:` lines use as their
# field separator — built once via ANSI-C quoting rather than typed as a
# literal multibyte character in this file's own source, the same
# technique bin/aggregate-verdicts.sh and bin/derive-populations.sh use.
EM=$'\xe2\x80\x94'
SEP=" $EM "

# The writer's own token grammar (bin/log-run.sh's BINDING_TOKEN_RE,
# unchanged and reused verbatim — never widened, narrowed or re-derived
# here), applied on the reading side to BOTH a row's instance value and a
# block's `- part:` name, since bin/aggregate-verdicts.sh's own --part
# grammar is declared, in its own help text, to be "the same grammar
# bin/log-run.sh's --instance flag validates against".
TOKEN_GRAMMAR_RE='^[a-z][a-z0-9-]*$'
LABEL_RE='^[A-Za-z0-9][A-Za-z0-9_-]*$'

# die <exit-code> <class> <detail> — the one closed stderr shape every
# refusal in this script uses. The write itself is best-effort (`|| true`)
# so a caller with a closed stderr can never steal this call's own exit
# code via errexit — the same guard bin/aggregate-verdicts.sh's die
# applies for the identical reason.
die() {
  printf '%s: %s: %s\n' "$PROG" "$2" "$3" >&2 || true
  exit "$1"
}

print_help() {
  cat <<'EOF'
Usage:
  check-fanout-instances.sh --telemetry <file> --run-id <id> --phase <phase> --aggregation <file> --label <label> [--iteration <n>] [--attempt <n>]
  check-fanout-instances.sh --help

Reads one fan-out's own telemetry span rows and the merged fanout-verdict
block bin/aggregate-verdicts.sh produced for it, and refuses — a classified
exit code, empty stdout — unless four properties hold together over the
declared scope: presence (every selected span row carries a non-null
instance discriminator), grammar (every discriminator, read back, conforms
to the writer's own ^[a-z][a-z0-9-]*$ grammar), uniqueness (no id is
claimed by rows of two different roles) and consistency (the scope's
instance set and the block's declared part set are equal in both
directions).

Flags:
  --telemetry <file>    the run's own <loop_id>.jsonl telemetry file (required)
  --run-id <id>         the run id every selected row's run_id must equal (required)
  --phase <phase>       the phase every selected row's phase must equal (required)
  --aggregation <file>  the file holding the bin/aggregate-verdicts.sh
                        fanout-verdict block for this fan-out (required)
  --label <label>       which fanout-verdict block in --aggregation to
                        read; must match ^[A-Za-z0-9][A-Za-z0-9_-]*$ (required)
  --iteration <n>       narrow the scope to rows whose iteration equals <n>
                        (optional; non-negative integer)
  --attempt <n>         narrow the scope to rows whose attempt equals <n>
                        (optional; non-negative integer)
  --help, -h            show this help and exit 0

A scope naming a run_id/phase pair that mixes a serial round with a fanned
round of the same phase refuses missing-instance; narrow it with
--iteration/--attempt rather than treating that as a checker limitation.

Exit codes:
  0  every property held (the ok line above reaches stdout, stderr empty)
  1  a refusal about the CONTENT of the rows or the block
  2  a usage error about the invocation
  3  a refusal because the fan-out is INCOMPLETE (uncovered-part, no-rows)
     — re-run or re-emit the missing assignment, never re-read the data
EOF
}

TELEMETRY=""
RUN_ID=""
PHASE=""
AGGREGATION=""
LABEL=""
ITERATION=""
ATTEMPT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --telemetry)
      [ "$#" -ge 2 ] || die 2 usage "--telemetry requires a value"
      shift
      TELEMETRY="$1"
      shift
      ;;
    --run-id)
      [ "$#" -ge 2 ] || die 2 usage "--run-id requires a value"
      shift
      RUN_ID="$1"
      shift
      ;;
    --phase)
      [ "$#" -ge 2 ] || die 2 usage "--phase requires a value"
      shift
      PHASE="$1"
      shift
      ;;
    --aggregation)
      [ "$#" -ge 2 ] || die 2 usage "--aggregation requires a value"
      shift
      AGGREGATION="$1"
      shift
      ;;
    --label)
      [ "$#" -ge 2 ] || die 2 usage "--label requires a value"
      shift
      LABEL="$1"
      shift
      ;;
    --iteration)
      [ "$#" -ge 2 ] || die 2 usage "--iteration requires a value"
      shift
      ITERATION="$1"
      shift
      ;;
    --attempt)
      [ "$#" -ge 2 ] || die 2 usage "--attempt requires a value"
      shift
      ATTEMPT="$1"
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

[ -n "$TELEMETRY" ] || die 2 usage "missing required --telemetry"
[ -n "$RUN_ID" ] || die 2 usage "missing required --run-id"
[ -n "$PHASE" ] || die 2 usage "missing required --phase"
[ -n "$AGGREGATION" ] || die 2 usage "missing required --aggregation"
[ -n "$LABEL" ] || die 2 usage "missing required --label"

[[ "$LABEL" =~ $LABEL_RE ]] || die 2 usage "--label must match ^[A-Za-z0-9][A-Za-z0-9_-]*\$: $LABEL"

if [ -n "$ITERATION" ]; then
  [[ "$ITERATION" =~ ^[0-9]{1,9}$ ]] || die 2 usage "--iteration must be a non-negative integer: $ITERATION"
fi
if [ -n "$ATTEMPT" ]; then
  [[ "$ATTEMPT" =~ ^[0-9]{1,9}$ ]] || die 2 usage "--attempt must be a non-negative integer: $ATTEMPT"
fi

[ -r "$TELEMETRY" ] || die 2 usage "--telemetry path not readable: $TELEMETRY"
[ -r "$AGGREGATION" ] || die 2 usage "--aggregation path not readable: $AGGREGATION"

# A path that passes -r (a directory, a FIFO, a device node such as
# /dev/null are all "readable" by that test) but is not a regular file is an
# invocation defect, not a content defect: reading a directory through the
# `read` builtin below (Phase 1) emits an uncontrolled bash engine message on
# stderr and this checker fell through to the wrong exit-3 class rather than
# refusing at the invocation-check stage (QA round 1, T-1082). Guarded
# uniformly for BOTH path arguments rather than only the one QA reproduced,
# since the underlying class — "caller-supplied path is not a regular
# file" — applies identically to --aggregation (whose current grep-based
# read only happens to degrade cleanly for a directory, not by design, and
# would not necessarily degrade as cleanly for every non-regular shape). A
# FIFO fails this test without ever being opened, so no blocking read is
# risked; a symlink is judged by what it resolves to, matching -r's own
# symlink-following behaviour.
[ -f "$TELEMETRY" ] || die 2 usage "--telemetry path is not a regular file: $TELEMETRY"
[ -f "$AGGREGATION" ] || die 2 usage "--aggregation path is not a regular file: $AGGREGATION"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-fanout-instances.XXXXXX")" || die 2 usage "cannot create a scratch directory under \${TMPDIR:-/tmp}"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$WORKDIR" 2>/dev/null || true; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Phase 0 — block parse. Find the ONE fanout-verdict block carrying --label,
# then read its `- part:` metadata lines (above the nested verdict-region,
# never inside it).
# ---------------------------------------------------------------------------
BEGIN_LINE="<!-- BEGIN fanout-verdict: ${LABEL} -->"
END_LINE="<!-- END fanout-verdict: ${LABEL} -->"
VBEGIN_LINE="<!-- BEGIN verdict-region: ${LABEL} -->"

begin_count="$(grep -Fxc -- "$BEGIN_LINE" "$AGGREGATION" 2>/dev/null || true)"
[ -n "$begin_count" ] || begin_count=0
if [ "$((10#$begin_count))" -eq 0 ]; then
  die 2 block-not-found "no '$BEGIN_LINE' block found in $AGGREGATION"
fi
if [ "$((10#$begin_count))" -gt 1 ]; then
  die 1 duplicate-block "more than one '$BEGIN_LINE' block found in $AGGREGATION — which is authoritative cannot be decided by a reader"
fi

awk -v b="$BEGIN_LINE" -v e="$END_LINE" '$0==b{f=1} f{print} f&&$0==e{exit}' "$AGGREGATION" > "$WORKDIR/block.raw"
awk -v b="$BEGIN_LINE" -v v="$VBEGIN_LINE" '$0==b{f=1;next} $0==v{exit} f{print}' "$WORKDIR/block.raw" > "$WORKDIR/block.meta"

: > "$WORKDIR/part_names.raw"
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  case "$line" in
    "- part: "*)
      rest="${line#'- part: '}"
      case "$rest" in
        *"$SEP"*) : ;;
        *) die 1 malformed-block "'- part:' line missing the ' — ' separator: $line" ;;
      esac
      pname="${rest%%"$SEP"*}"
      [ -n "$pname" ] || die 1 malformed-block "'- part:' line has an empty name: $line"
      [[ "$pname" =~ $TOKEN_GRAMMAR_RE ]] || die 1 malformed-block "'- part:' name '$pname' does not match ^[a-z][a-z0-9-]*\$"
      printf '%s\n' "$pname" >> "$WORKDIR/part_names.raw"
      ;;
    *)
      : # other metadata lines (- aggregated-by:, - locale:) are not this checker's concern
      ;;
  esac
done < "$WORKDIR/block.meta"

sort -u "$WORKDIR/part_names.raw" > "$WORKDIR/part_set"
part_count="$(grep -c . "$WORKDIR/part_set" 2>/dev/null || true)"
[ -n "$part_count" ] || part_count=0
if [ "$((10#$part_count))" -eq 0 ]; then
  die 1 malformed-block "no '- part:' lines found in the '${LABEL}' block's metadata"
fi

# ---------------------------------------------------------------------------
# Phase 1 — select the scope's own rows. Boundary-anchored on `{`/`,`
# (bin/check-run.sh's key_present, bin/rollup-runs.sh's field_str): run_id
# and phase always required; iteration/attempt narrow only when given.
# An event row carries no `phase` key at all and is never selected here.
# ---------------------------------------------------------------------------
RUN_ID_RE='[{,]"run_id":"((\\.|[^"\\])*)"'
PHASE_KEY_RE='[{,]"phase":"((\\.|[^"\\])*)"'
ITER_KEY_RE='[{,]"iteration":([0-9]+)'
ATTEMPT_KEY_RE='[{,]"attempt":([0-9]+)'

# json_esc <value> — the same escaping bin/log-run.sh's own jesc applies to
# a string field before writing it (backslash first, then double-quote),
# so a caller-supplied --run-id/--phase compares against the SAME escaped
# form the writer stored, exactly as bin/log-run.sh's own
# compute_auto_seq does for --run-id.
json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

RUN_ID_ESC="$(json_esc "$RUN_ID")"
PHASE_ESC="$(json_esc "$PHASE")"

: > "$WORKDIR/rows.raw"
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  [[ "$line" =~ $RUN_ID_RE ]] || continue
  [ "${BASH_REMATCH[1]}" = "$RUN_ID_ESC" ] || continue
  [[ "$line" =~ $PHASE_KEY_RE ]] || continue
  [ "${BASH_REMATCH[1]}" = "$PHASE_ESC" ] || continue
  if [ -n "$ITERATION" ]; then
    [[ "$line" =~ $ITER_KEY_RE ]] || continue
    [ "$((10#${BASH_REMATCH[1]}))" -eq "$((10#$ITERATION))" ] || continue
  fi
  if [ -n "$ATTEMPT" ]; then
    [[ "$line" =~ $ATTEMPT_KEY_RE ]] || continue
    [ "$((10#${BASH_REMATCH[1]}))" -eq "$((10#$ATTEMPT))" ] || continue
  fi
  printf '%s\n' "$line" >> "$WORKDIR/rows.raw"
done < "$TELEMETRY"

row_count="$(grep -c . "$WORKDIR/rows.raw" 2>/dev/null || true)"
[ -n "$row_count" ] || row_count=0

# ---------------------------------------------------------------------------
# Phase 2 — per-row shape: a row that satisfies the scope selector while
# carrying the event row shape is a defect in the file, never silently
# skipped.
# ---------------------------------------------------------------------------
KIND_EVENT_RE='[{,]"kind":"event"'
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [[ "$line" =~ $KIND_EVENT_RE ]]; then
    die 1 malformed-row "a row selected by the declared scope (run_id=$RUN_ID phase=$PHASE) carries \"kind\":\"event\" — event rows are out of scope by construction"
  fi
done < "$WORKDIR/rows.raw"

# ---------------------------------------------------------------------------
# Phase 3 — presence: every selected row carries a non-null, non-empty
# instance discriminator. Absent key, "instance":null, and an explicit
# empty string all read as "not provided", identically.
# ---------------------------------------------------------------------------
INSTANCE_STR_RE='[{,]"instance":"((\\.|[^"\\])*)"'
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [[ "$line" =~ $INSTANCE_STR_RE ]] && [ -n "${BASH_REMATCH[1]}" ]; then
    :
  else
    die 1 missing-instance "a row in the declared scope (run_id=$RUN_ID phase=$PHASE) carries no non-null instance discriminator"
  fi
done < "$WORKDIR/rows.raw"

# ---------------------------------------------------------------------------
# Phase 4 — grammar: every discriminator, read back, conforms to the
# writer's own ^[a-z][a-z0-9-]*$ grammar.
# ---------------------------------------------------------------------------
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  [[ "$line" =~ $INSTANCE_STR_RE ]] || continue
  val="${BASH_REMATCH[1]}"
  [[ "$val" =~ $TOKEN_GRAMMAR_RE ]] || die 1 invalid-instance "instance id '$val' does not match the writer's own grammar ^[a-z][a-z0-9-]*\$"
done < "$WORKDIR/rows.raw"

# ---------------------------------------------------------------------------
# Phase 5 — uniqueness: within the scope, one id maps to exactly one role
# (--span value). The same id on two rows of the SAME role stays legal.
# ---------------------------------------------------------------------------
SPAN_RE='[{,]"span":"((\\.|[^"\\])*)"'
: > "$WORKDIR/idrole.raw"
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  [[ "$line" =~ $INSTANCE_STR_RE ]] || continue
  inst="${BASH_REMATCH[1]}"
  role=""
  if [[ "$line" =~ $SPAN_RE ]]; then
    role="${BASH_REMATCH[1]}"
  fi
  printf '%s\t%s\n' "$inst" "$role" >> "$WORKDIR/idrole.raw"
done < "$WORKDIR/rows.raw"
sort -u "$WORKDIR/idrole.raw" > "$WORKDIR/idrole.uniq"

cut -f1 "$WORKDIR/idrole.uniq" | sort > "$WORKDIR/ids.sorted"
uniq -d "$WORKDIR/ids.sorted" > "$WORKDIR/collide_ids"
collide_count="$(grep -c . "$WORKDIR/collide_ids" 2>/dev/null || true)"
[ -n "$collide_count" ] || collide_count=0
if [ "$((10#$collide_count))" -gt 0 ]; then
  die 1 instance-role-collision "instance id '$(head -n 1 "$WORKDIR/collide_ids")' is claimed by rows of more than one role within this scope"
fi

cut -f1 "$WORKDIR/idrole.uniq" | sort -u > "$WORKDIR/instance_set"

# ---------------------------------------------------------------------------
# Phase 6 — unattributed-instance: an id present in the scope's rows but
# declared by no `- part:` line in the block is a CONTENT defect (re-running
# the same assignments would reproduce it).
# ---------------------------------------------------------------------------
comm -23 "$WORKDIR/instance_set" "$WORKDIR/part_set" > "$WORKDIR/unattributed" 2>/dev/null || true
unattributed_count="$(grep -c . "$WORKDIR/unattributed" 2>/dev/null || true)"
[ -n "$unattributed_count" ] || unattributed_count=0
if [ "$((10#$unattributed_count))" -gt 0 ]; then
  die 1 unattributed-instance "instance id '$(head -n 1 "$WORKDIR/unattributed")' appears in the scope's rows but is declared by no '- part:' line in the aggregation block"
fi

# ---------------------------------------------------------------------------
# Phase 7 — exit-3 coverage, checked LAST: a scope selecting zero rows is
# `no-rows`; a part declared in the block with no row in the scope is
# `uncovered-part`. Both are INCOMPLETE-fan-out refusals whose remedy is to
# re-run or re-emit the missing assignment, never to re-read the data.
# ---------------------------------------------------------------------------
if [ "$((10#$row_count))" -eq 0 ]; then
  die 3 no-rows "the declared scope (run_id=$RUN_ID phase=$PHASE${ITERATION:+ iteration=$ITERATION}${ATTEMPT:+ attempt=$ATTEMPT}) selected zero span rows"
fi

comm -23 "$WORKDIR/part_set" "$WORKDIR/instance_set" > "$WORKDIR/uncovered" 2>/dev/null || true
uncovered_count="$(grep -c . "$WORKDIR/uncovered" 2>/dev/null || true)"
[ -n "$uncovered_count" ] || uncovered_count=0
if [ "$((10#$uncovered_count))" -gt 0 ]; then
  die 3 uncovered-part "part '$(head -n 1 "$WORKDIR/uncovered")' is declared in the aggregation block but no row in the declared scope carries that instance id"
fi

printf '%s: ok: run-id=%s phase=%s label=%s rows=%s parts=%s\n' "$PROG" "$RUN_ID" "$PHASE" "$LABEL" "$row_count" "$part_count"

exit 0
