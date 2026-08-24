#!/usr/bin/env bash
# check-entry-mode.sh — pre-freeze conformance-read gate (T-1096, issue #341).
#
# Decision this implements: docs/loop-engineering/record-tamper-resistance.md
# — tamper-arm-rule-v1 sends this obligation to arm A
# (arm-A-tested-primitive): its verdict gates a freeze (a loop transition)
# and its judgment (do two committed board sub-bullets exist and agree, and
# does every gap id carry a resolution?) is mechanically executable from
# committed bytes.
#
# Two condition sources, both committed sub-bullets on the task's own Active
# board entry, written by two different parties:
#   Source 1: `- entry-mode: pm-authored|operator-authored` — transcribed
#             onto the board by `pm-spec`, who owns the entry.
#   Source 2: `- dispatch: specify — <value> — ...` — transcribed by the
#             coordinating session, from the decision `tech-lead` printed
#             at Plan.
#
# The verdict is "both present, and agreeing" — a MISSING source is a
# refusal, never a silently-false condition, which is what makes the
# verdict order-independent (the shipped condition does not read as false
# when a source is merely not transcribed yet — it reads as absent, and
# absent refuses). "Answered" (for a flagged gap) is id-paired set equality
# in BOTH directions between `- flagged-gap (<id>): ...` and
# `- flagged-gap-resolution (<id>): ...` sub-bullets, with non-empty
# resolution text — never a claim that the resolution is adequate, and the
# never-flagged case (zero gaps, zero resolutions) is undetectable by
# design and is the conformant nothing-to-answer case.
#
# The gap/resolution marker is recognised by its STEM, and a near-miss
# carrying the stem but not parsing is REFUSED rather than silently
# ignored — the same "absence versus a failed read" shape defeat class 5
# names for a CRLF record, applied here to the gap-marker grammar instead
# of to line endings. `- flagged-gap` is a PREFIX of
# `- flagged-gap-resolution`, so the resolution stem is tested FIRST on
# every line; a scan testing the shorter stem first would count a
# resolution line as an unresolved gap.
#
# What this gate does NOT close (residuals, disclosed rather than
# claimed closed): (i) neither source is authenticable — two parties write
# them, but both land on a file either party can write; (ii) partially
# closed — this gate verifies that a conformant record of the read exists
# and agrees with the Plan-time decision; it DOES NOT VERIFY THAT THE READ
# HAPPENED; (iii) "answered" stays a reading judgment — this gate makes
# id-level bookkeeping mechanical and nothing more.
#
# Forward-only scoping: this gate is invoked only at the pre-freeze seam
# for the ONE task being frozen, never from bin/close-out.sh and never as a
# whole-board sweep, so a task specced under an older version — the one
# window where source 1 may genuinely be absent through no fault of the
# current task — refuses with a one-line remedy on stderr, in the same
# shape bin/close-out.sh already prints for its interventions-record
# remedy, rather than a wall with no way forward.
#
# Usage:
#   check-entry-mode.sh --board PATH --task T-NNN
#
# Exit codes: 0 = both sources present and agreeing, and every flagged gap
# is resolved (or none were flagged); 1 = a refusal about the board entry's
# content (a source missing, duplicated, or outside its closed vocabulary;
# the two sources disagree; a malformed or unresolved flagged-gap marker);
# 2 = a usage error or an unresolvable environment (bad invocation, an
# unreadable board, or the task not found as exactly one top-level
# ## Active entry).

set -euo pipefail

die()  { printf 'check-entry-mode: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'check-entry-mode: %s\n' "$1" >&2 || true; exit 1; }

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
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$BOARD" ] || die "missing required --board"
[ -n "$TASK" ]  || die "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || die "invalid --task '$TASK' (expected T-<digits>)"
[ -r "$BOARD" ] || die "cannot read board: $BOARD"

# --- locate the task's Active entry extent (same shape close-out.sh and
# check-spec-review.sh already use) --------------------------------------
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

ENTRY="$(sed -n "${A_START},${A_END}p" "$BOARD")"

print_entry_mode_remedy() {
  # shellcheck disable=SC2016  # backtick-quoted board grammar, not a substitution
  printf 'check-entry-mode: remedy — add a conformant `- entry-mode:` sub-bullet to %s'"'"'s Active board entry, naming whichever mode actually ran:\n' "$TASK" >&2 || true
  printf '  - entry-mode: pm-authored\n' >&2 || true
  # shellcheck disable=SC2016  # backtick-quoted board grammar, not a substitution
  printf 'check-entry-mode: (or `operator-authored`, per pm-spec.md'"'"'s producer duty — see agents/pm-spec.md)\n' >&2 || true
}

# --- source 1: `- entry-mode:` ------------------------------------------
EM_LINES="$(printf '%s\n' "$ENTRY" | grep -E '^[[:space:]]*- entry-mode: ' || true)"
EM_COUNT="$(printf '%s\n' "$EM_LINES" | grep -c . || true)"

if [ "$EM_COUNT" -eq 0 ]; then
  # shellcheck disable=SC2016  # backtick-quoted board grammar, not a substitution
  printf 'check-entry-mode: %s has no `- entry-mode:` sub-bullet on its Active board entry (source 1 absent)\n' "$TASK" >&2 || true
  print_entry_mode_remedy
  exit 1
fi
if [ "$EM_COUNT" -gt 1 ]; then
  fail "$TASK's \`- entry-mode:\` sub-bullet appears more than once ($EM_COUNT times)"
fi

EM_VALUE="$(printf '%s\n' "$EM_LINES" | sed -nE 's/^[[:space:]]*- entry-mode: (.*)$/\1/p')"
case "$EM_VALUE" in
  pm-authored|operator-authored) : ;;
  *) fail "$TASK's \`- entry-mode:\` value is outside the closed pair pm-authored/operator-authored: '$EM_VALUE'" ;;
esac

# --- source 2: `- dispatch: specify — ...` -------------------------------
D_LINES="$(printf '%s\n' "$ENTRY" | grep -E '^[[:space:]]*- dispatch: specify — ' || true)"
D_COUNT="$(printf '%s\n' "$D_LINES" | grep -c . || true)"

if [ "$D_COUNT" -eq 0 ]; then
  fail "$TASK has no \`- dispatch: specify — ...\` sub-bullet on its Active board entry (source 2 absent)"
fi
if [ "$D_COUNT" -gt 1 ]; then
  fail "$TASK's \`- dispatch: specify — ...\` sub-bullet appears more than once ($D_COUNT times)"
fi

D_VALUE="$(printf '%s\n' "$D_LINES" | sed -nE 's/^[[:space:]]*- dispatch: specify — ([a-z0-9-]+) — .*$/\1/p')"
case "$D_VALUE" in
  pm-authored|operator-authored) : ;;
  *) fail "$TASK's \`- dispatch: specify — ...\` value is outside the closed pair pm-authored/operator-authored: '$D_VALUE'" ;;
esac

# --- both directions of a mismatch refuse --------------------------------
if [ "$EM_VALUE" != "$D_VALUE" ]; then
  fail "$TASK's \`- entry-mode:\` ('$EM_VALUE') and \`- dispatch: specify\` ('$D_VALUE') disagree"
fi

# --- flagged-gap / flagged-gap-resolution id pairing ---------------------
# Recognised by STEM, resolution tested first (it is the longer stem, and
# `- flagged-gap` is its own prefix). A line carrying either stem but not
# parsing cleanly into `(<id>): <non-empty text>` is refused immediately,
# distinct from a merely-absent or orphaned id.
res_stem_re='^[[:space:]]*- flagged-gap-resolution'
res_full_re='^[[:space:]]*- flagged-gap-resolution \(([a-z0-9-]+)\): (.*)$'
gap_stem_re='^[[:space:]]*- flagged-gap'
gap_full_re='^[[:space:]]*- flagged-gap \(([a-z0-9-]+)\): (.*)$'

GAP_IDS=" "
RES_IDS=" "

while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [[ "$line" =~ $res_stem_re ]]; then
    if [[ "$line" =~ $res_full_re ]]; then
      rid="${BASH_REMATCH[1]}"
      rtext="${BASH_REMATCH[2]}"
      trimmed="$(printf '%s' "$rtext" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$trimmed" ] || fail "$TASK has a \`- flagged-gap-resolution ($rid):\` sub-bullet with empty resolution text: $line"
      case "$RES_IDS" in
        *" $rid "*) fail "$TASK has a duplicated \`- flagged-gap-resolution\` id '$rid'" ;;
      esac
      RES_IDS="${RES_IDS}${rid} "
    else
      fail "$TASK has a malformed \`- flagged-gap-resolution\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  elif [[ "$line" =~ $gap_stem_re ]]; then
    if [[ "$line" =~ $gap_full_re ]]; then
      gid="${BASH_REMATCH[1]}"
      case "$GAP_IDS" in
        *" $gid "*) fail "$TASK has a duplicated \`- flagged-gap\` id '$gid'" ;;
      esac
      GAP_IDS="${GAP_IDS}${gid} "
    else
      fail "$TASK has a malformed \`- flagged-gap\` marker (does not parse into '(<id>): <text>'): $line"
    fi
  fi
done <<< "$ENTRY"

G_SORTED="$(printf '%s' "$GAP_IDS" | tr ' ' '\n' | sed '/^$/d' | sort)"
R_SORTED="$(printf '%s' "$RES_IDS" | tr ' ' '\n' | sed '/^$/d' | sort)"

if [ "$G_SORTED" != "$R_SORTED" ]; then
  fail "$TASK's \`- flagged-gap\` and \`- flagged-gap-resolution\` id sets disagree (gaps: [$(printf '%s' "$G_SORTED" | tr '\n' ' ')] resolutions: [$(printf '%s' "$R_SORTED" | tr '\n' ' ')]) — never that the resolution is adequate, only that every flagged id was answered; the never-flagged case is undetectable and is the conformant nothing-to-answer shape"
fi

exit 0
