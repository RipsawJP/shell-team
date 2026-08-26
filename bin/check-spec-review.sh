#!/usr/bin/env bash
# check-spec-review.sh — close-out backstop refusing an elected spec review
# that never reached an approval verdict (T-1096, issue #344).
#
# Decision this implements: docs/loop-engineering/record-tamper-resistance.md
# — tamper-arm-rule-v1 sends this obligation to arm A
# (arm-A-tested-primitive): its verdict gates a close-out (a loop
# transition) and its judgment (is the record's LAST spec-review verdict
# line an approval?) is mechanically executable from committed bytes.
#
# The six #344 defeat classes this design refuses or is structurally immune
# to, verbatim from the spec's own requirement floor
# (.shell-team/specs/T-1096-selection-trust-gates.md §2):
#   1. Unanchored verdict match (a prefix-matching near-miss like
#      APPROVE_WITH_CAVEATS, or the unfilled template APPROVE | REQUEST_CHANGES).
#   2. Unscoped scan (an earlier APPROVE satisfying a whole-file grep when
#      the latest round said REQUEST_CHANGES).
#   3. Heading-match asymmetry (a trailing- or internal-whitespace heading
#      variant anchoring the scan to a stale round).
#   4. Boundary defeat in the dangerous direction (an unrelated heading with
#      leading whitespace leaking later content into "the latest round").
#   5. CRLF fallback bypass (a CRLF-terminated record defeating heading
#      detection and resurrecting a stale APPROVE via a whole-file fallback).
#   6. Missing/non-ASCII separator (a reductive whitespace normalization can
#      collapse existing whitespace but never supply a missing one).
#
# The design consults NO heading at all and has NO fallback: it strips a
# trailing CR per line, collects EVERY column-zero line matching the
# verdict-line STEM `^### Codex Spec-Review verdict:` alone — no assumption
# about the separator or the tail — refuses when none is collected, and
# otherwise takes the LAST such line and requires its remainder to be
# exactly one ASCII space followed by one of four closed forms (APPROVE,
# APPROVE (round <n>), REQUEST_CHANGES, REQUEST_CHANGES (round <n>)),
# refusing — never skipping — any other remainder. This closes classes 1
# and 2 (anchored-prefix match, last-line-wins, append-only ordering) and is
# structurally immune to 3, 4 and 5 (no heading is ever read).
#
# Widening the collection net to stem-PLUS-SEPARATOR (`^### Codex
# Spec-Review verdict: ` with the trailing space baked into the net) would
# relocate class 6 onto the verdict line's own separator rather than close
# it: a line whose separator is missing, a tab, or non-ASCII would be
# UNCOLLECTED rather than refused, and a stale earlier APPROVE would then be
# the last collected line — the gate would false-PASS. So the net is the
# stem alone, and the separator is validated as part of the remainder
# instead, putting every near-miss in the refusal branch.
#
# EOF-safety: the whole file is read with `grep`/`sed`, never a
# `while IFS= read -r line` loop, which drops a final line carrying no
# trailing newline (that read's own non-zero exit status is the loop's
# continuation test) and would silently resurrect a stale verdict.
#
# The producer contract this reads against is pinned in
# agents/codex-reviewer.md's "Verdict and record shape" paragraph.
#
# Election (validate-if-present): this gate fires only when the task's
# Active board entry carries `- dispatch: spec-review — cross-provider —
# ...`. `none`, or no `spec-review` dispatch record at all, is a silent
# pass-through — tests/close-out/run.sh's own locked forward-only property
# for every in-flight three-axis task. This gate cannot distinguish "the
# election was none" from "nobody transcribed the record" — disclosed, not
# closed.
#
# Usage:
#   check-spec-review.sh --board PATH --task T-NNN
#
# Exit codes: 0 = pass, or the election is not cross-provider; 1 = a
# refusal about the record's content (no readable record / no verdict line
# found at all / the last verdict line's remainder is an unrecognised tail
# or an in-grammar REQUEST_CHANGES refusal); 2 = a usage error or an
# unresolvable environment (bad invocation, an unreadable board, the task
# not found as exactly one top-level ## Active entry, or an
# unresolvable/non-directory reviews directory).

set -euo pipefail

die()  { printf 'check-spec-review: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'check-spec-review: %s\n' "$1" >&2 || true; exit 1; }

# Resolve this script's own directory (symlink-safe) so the sibling
# team-paths.sh resolves regardless of cwd / how we were invoked — same
# pattern close-out.sh and log-run.sh already use.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

BOARD="" TASK=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      [ "$#" -ge 2 ] || die "missing value for --board"
      BOARD="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || die "missing value for --task"
      TASK="$2"; shift 2 ;;
    --help|-h)
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "$script_path"
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$BOARD" ] || die "missing required --board"
[ -n "$TASK" ]  || die "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || die "invalid --task '$TASK' (expected T-<digits>)"
[ -r "$BOARD" ] || die "cannot read board: $BOARD"

# --- locate the task's Active entry extent (same shape as close-out.sh's
# own scan: a top-level `- [ ] **T-NNN**` line plus its indented/blank
# continuation lines) ---------------------------------------------------
scan="$(awk -v task="$TASK" '
  BEGIN { sec=""; a_start=0; a_end=0; a_count=0; capturing=0 }
  /^## /            { sec=$0; capturing=0 }
  sec ~ /^## Active/ {
    if ($0 ~ ("^- \\[ \\] \\*\\*" task "\\*\\* ")) {
      a_count++; a_start=NR; a_end=NR; capturing=1; next
    }
    if (capturing) {
      if ($0 ~ /^[[:space:]]*$/) { next }
      if ($0 ~ /^[[:space:]]+[^[:space:]]/) { a_end=NR; next }
      capturing=0
    }
  }
  END { print a_start, a_end, a_count }
' "$BOARD")"
read -r A_START A_END A_COUNT <<< "$scan"
[ "$A_COUNT" -eq 1 ] || die "$TASK is not exactly one top-level entry in ## Active of $BOARD"

# --- extract the spec-review election, if any ---------------------------
d_line="$(sed -n "${A_START},${A_END}p" "$BOARD" \
  | grep -E -- '^[[:space:]]*- dispatch: spec-review — ' | tail -1 || true)"
d_value=""
if [ -n "$d_line" ]; then
  d_value="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: spec-review — ([a-z0-9-]+) — .*$/\1/p')"
fi

# Validate-if-present: `none`, an unrecognised value, or no record at all
# is a silent pass-through. Only `cross-provider` continues below.
if [ "$d_value" != "cross-provider" ]; then
  exit 0
fi

# --- resolve the reviews directory (interventions-resolver shape: env
# override at the same precedence $TEAM_TODO/$TEAM_INTERVENTIONS_DIR have,
# else the sibling team-paths.sh, no guessing fallback) — with one
# deliberate difference from that resolver: a directory check is required
# here, and its failure is its OWN exit-2 failure class, distinct from a
# content refusal about the record itself -------------------------------
if [ -n "${TEAM_REVIEWS_DIR:-}" ]; then
  REVIEWS_DIR="$TEAM_REVIEWS_DIR"
else
  REVIEWS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get reviews 2>/dev/null)" \
    || die "cannot resolve the reviews directory (team-paths.sh unavailable) — set \$TEAM_REVIEWS_DIR or fix the install"
fi
[ -d "$REVIEWS_DIR" ] || die "reviews directory is not a directory: $REVIEWS_DIR"

RECORD="$REVIEWS_DIR/$TASK.md"

# Row (i): a missing path, a directory, a FIFO, an unreadable file or a
# dangling symlink are all "no readable record" — same screen close-out.sh
# already uses for the interventions record.
if [ ! -f "$RECORD" ] || [ ! -r "$RECORD" ]; then
  fail "$TASK elected spec-review — cross-provider but has no readable review record: $RECORD"
fi

WORK="$(mktemp "${TMPDIR:-/tmp}/check-spec-review.XXXXXX")" || die "mktemp failed"
trap 'rm -f "$WORK"' EXIT

# Strip a trailing CR per line (defeat class 5) without ever using a
# `while read` loop over the record itself (EOF safety for a final line
# with no trailing newline — defeat class 7 in AC5's own numbering).
sed 's/\r$//' "$RECORD" > "$WORK"

# Collect every column-zero line matching the verdict-line STEM alone (the
# third correction to the candidate design: a stem-PLUS-SEPARATOR net would
# leave a missing/non-ASCII separator UNCOLLECTED rather than refused,
# relocating class 6 instead of closing it). `grep` reads the whole file,
# so a final line with no trailing newline is still matched.
LAST="$(grep -E '^### Codex Spec-Review verdict:' "$WORK" | tail -1 || true)"
if [ -z "$LAST" ]; then
  fail "$TASK's review record carries no Codex Spec-Review verdict line at all: $RECORD"
fi

REMAINDER="${LAST#'### Codex Spec-Review verdict:'}"

# The closed grammar: exactly one ASCII space, then one of the four forms,
# and nothing else — anchored on the full remainder so an unrecognised tail
# is refused rather than skipped past (the correction that closes classes 1
# and 2), and so a missing/tab/non-ASCII separator on THIS line refuses
# rather than silently falling through to an earlier stale approval (the
# separator-axis correction that closes class 6 at its second location).
re_grammar='^ (APPROVE|REQUEST_CHANGES)( \(round [0-9]+\))?$'
re_approve='^ APPROVE( \(round [0-9]+\))?$'

if [[ ! "$REMAINDER" =~ $re_grammar ]]; then
  fail "$TASK's last Codex Spec-Review verdict line has an unrecognised remainder (not one of the four closed forms APPROVE / APPROVE (round N) / REQUEST_CHANGES / REQUEST_CHANGES (round N)): $LAST"
fi

if [[ "$REMAINDER" =~ $re_approve ]]; then
  exit 0
fi

fail "$TASK's last Codex Spec-Review verdict is not an approval: $LAST"
