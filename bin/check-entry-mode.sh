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
# T-1109 (issue #365, Proposal 3) adds a THIRD, independent duty at this
# same seam: `- dispatch-reflection: <axis> — <predecessor> — <verdict> —
# <ground>`, one sub-bullet per dispatch axis the entry itself records
# (or the single `all — no-predecessor — no-predecessor-row — <ground>`
# line where the task has no predecessor at all), transcribed by the
# coordinating session BEFORE the `- dispatch:` rows in the same window.
# Duty A validates the record's own grammar and per-axis coverage; duty B
# validates that a stated verdict agrees with the predecessor entry's own
# recorded `- dispatch:` value for that axis, the predecessor resolved by
# a SECOND scan spanning BOTH `## Active` and `## Done` (never a widening
# of this entry's own `## Active`-only resolution above). Like the
# `- dispatch:` family itself, this is validate-if-present at the family
# level: an entry carrying no `- dispatch-reflection:` line at all still
# passes — presence is `templates/prompt-blocks/dispatch-record.md`'s own
# requirement, never this script's.
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
# Exit codes: 0 = both sources present and agreeing, every flagged gap is
# resolved (or none were flagged), and the dispatch-reflection family (if
# present) is well-formed, covers every axis and agrees with the
# predecessor's own recorded values; 1 = a refusal about the board entry's
# content (a source missing, duplicated, or outside its closed vocabulary;
# the two sources disagree; a malformed or unresolved flagged-gap marker;
# a malformed, incomplete, mixed, mismatched or unresolved
# `- dispatch-reflection:` row — T-1109); 2 = a usage error or an
# unresolvable environment (bad invocation, an unreadable board, or the
# task not found as exactly one top-level ## Active entry).

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

# Strip a trailing CR per line (T-1096 rework round 1, Major 3) — the same
# CRLF tolerance bin/check-handoff.sh already applies to a board line and
# the sibling bin/check-spec-review.sh already applies to a review record,
# for the identical reason: an otherwise-conformant value must not be
# refused merely because the board file itself is CRLF-terminated.
ENTRY="$(sed -n "${A_START},${A_END}p" "$BOARD" | sed 's/\r$//')"

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
  # T-1096 rework round 1, Major 2: a whitespace variant this spec's own
  # ## Input space names as reachable (a doubled space after the bullet
  # dash) fails the strict single-space anchor above and would otherwise be
  # misreported as "absent" — a genuinely different, misleading diagnostic
  # from "the sub-bullet is malformed." Distinguish the two with a wider,
  # detection-only stem (never used to extract a value, only to name what
  # was actually found) before choosing the message; either branch still
  # refuses (exit 1) — this is a diagnostic fix, not a behavior change.
  EM_LOOSE="$(printf '%s\n' "$ENTRY" | grep -E '^[[:space:]]*-[[:space:]]+entry-mode:' || true)"
  if [ -n "$EM_LOOSE" ]; then
    # shellcheck disable=SC2016  # backtick-quoted board grammar, not a substitution
    printf 'check-entry-mode: %s has a malformed `- entry-mode:` sub-bullet — found, but its spacing does not match the canonical single-space grammar: %s\n' "$TASK" "$EM_LOOSE" >&2 || true
  else
    # shellcheck disable=SC2016  # backtick-quoted board grammar, not a substitution
    printf 'check-entry-mode: %s has no `- entry-mode:` sub-bullet on its Active board entry (source 1 absent)\n' "$TASK" >&2 || true
  fi
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
  # T-1096 rework round 1, Major 2 (source 2's own half): a doubled space
  # after the bullet dash — the same reachable class handled for source 1
  # above — fails the strict anchor above; name it as malformed rather than
  # absent when a wider, detection-only stem still finds it.
  D_LOOSE="$(printf '%s\n' "$ENTRY" | grep -E '^[[:space:]]*-[[:space:]]+dispatch:[[:space:]]+specify[[:space:]]+—' || true)"
  if [ -n "$D_LOOSE" ]; then
    fail "$TASK has a malformed \`- dispatch: specify — ...\` sub-bullet — found, but its spacing does not match the canonical grammar: $D_LOOSE"
  fi
  fail "$TASK has no \`- dispatch: specify — ...\` sub-bullet on its Active board entry (source 2 absent)"
fi
if [ "$D_COUNT" -gt 1 ]; then
  fail "$TASK's \`- dispatch: specify — ...\` sub-bullet appears more than once ($D_COUNT times)"
fi

D_VALUE="$(printf '%s\n' "$D_LINES" | sed -nE 's/^[[:space:]]*- dispatch: specify — ([a-z0-9-]+) — .*$/\1/p')"
if [ -z "$D_VALUE" ]; then
  # T-1096 rework round 1, Major 2 (the separator-doubling case): the
  # coarse D_LINES anchor above has no trailing `$`, so a doubled space
  # INSIDE the ` — ` separator right before the value (a reachable class
  # this spec's own ## Input space names) still satisfies it, but the
  # strict extraction above then yields nothing — never misreport this as
  # "value outside the closed pair: ''" (a real vocabulary violation).
  fail "$TASK's \`- dispatch: specify — ...\` sub-bullet exists but its value field could not be parsed — check the spacing around each ' — ' separator: $D_LINES"
fi
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
#
# T-1096 rework round 1, Blocker 2: the stem net's own whitespace between
# the bullet dash and the field name was pinned to exactly one space
# (`- flagged-gap`), which is narrower than the collection-net-vs-remainder
# discipline §2 already uses for the verdict-line stem. A doubled space
# after the bullet — a class this spec's own ## Input space explicitly
# names as reachable — made the WHOLE marker invisible to both the gap and
# resolution stem tests (contributing to neither set), so a genuinely
# flagged, genuinely unresolved gap silently read as the conformant
# zero-gaps case: the exact "absence versus a failed read" shape defeat
# class 5 exists to close, reopened at this second location. The stem net
# is now `-[[:space:]]+` (one or more spaces, any count) so every such
# variant is COLLECTED; the full-grammar regexes below stay strict (exactly
# one space), so a variant that fails them is REFUSED as malformed rather
# than falling through the invisible gap this rework closes.
res_stem_re='^[[:space:]]*-[[:space:]]+flagged-gap-resolution'
res_full_re='^[[:space:]]*- flagged-gap-resolution \(([a-z0-9-]+)\): (.*)$'
gap_stem_re='^[[:space:]]*-[[:space:]]+flagged-gap'
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

# --- source 3: `- dispatch-reflection:` (T-1109, issue #365) -------------
# Validate-if-present at the family level, the same shape and the same
# reason `bin/close-out.sh`'s own `- dispatch:` gate already uses: an
# entry carrying none of these sub-bullets still passes — presence is
# `templates/prompt-blocks/dispatch-record.md`'s own requirement, not this
# script's. The stem net below widens only the whitespace between the
# bullet dash and the field name, never the colon, so a genuinely
# malformed spacing variant is COLLECTED (never rendered invisible, the
# T-1096 Blocker-2 class reopened at a third marker family — ## Notes for
# engineer trap 3) and then REFUSED against the strict full grammar below,
# rather than silently read as the conformant zero-rows case. `- dispatch-
# reflection:` matches none of the `- dispatch:`-anchored scans above (every
# one of them requires the literal colon immediately after the bare word
# `dispatch`, never after `-reflection` — AC7 byte-pins this), so this scan
# is additive and cannot collide with source 2's own reading.
#
# Codex review round 1, Major 4: the stem net above widened only the gap
# between the bullet dash and the field name, never the gap between the
# field name and its colon — `- dispatch-reflection : ...` (a space
# BEFORE the colon) matched neither this stem nor the full grammar below,
# so the whole line was invisible to the family scan and a genuinely
# malformed reflection line read as the conformant empty-family case. The
# stem now tolerates whitespace on BOTH sides of the colon too, the same
# collect-wide discipline already applied to the dash-to-fieldname gap;
# the full grammar below stays strict (colon immediately after the bare
# field name, exactly one space after it), so any such variant is
# COLLECTED here and REFUSED as malformed below, never silently dropped.
refl_stem_re='^[[:space:]]*-[[:space:]]+dispatch-reflection[[:space:]]*:[[:space:]]*'
refl_full_re='^[[:space:]]*- dispatch-reflection: ([a-z-]+) — ([A-Za-z0-9-]+) — ([a-z-]+) — (.*)$'

# This entry's own `- dispatch:` axis -> value map is computed further
# below, scoped inside the reflection-family-present gate — see the
# "Codex review round 2, Major (regression)" comment there for why it is
# NOT computed here unconditionally.

dispatch_value_for_axis() {  # $1 = a `- dispatch:`-line block, $2 = axis key, $3 = who this block belongs to (for the refusal message)
  local block="$1" axis="$2" who="$3" matches n
  matches="$(printf '%s\n' "$block" | grep -E -- "^[[:space:]]*- dispatch: ${axis} — " || true)"
  n="$(printf '%s\n' "$matches" | grep -c . || true)"
  if [ "$n" -gt 1 ]; then
    # Codex review round 1, Major 3: a silent `head -1` first-match on
    # duplicate/conflicting `- dispatch:` rows for the same axis — on
    # EITHER the predecessor's entry or the current entry — masked a
    # genuinely inconsistent record instead of refusing it. Duty B now
    # requires exactly one matching row per axis before extracting a
    # value; more than one refuses (fail-closed), regardless of whether
    # the conflicting rows happen to agree.
    fail "$TASK's \`- dispatch-reflection:\` duty B cannot resolve a single value for axis '$axis' on $who — it carries $n \`- dispatch: $axis\` rows instead of exactly one"
  fi
  printf '%s\n' "$matches" | sed -nE "s/^[[:space:]]*- dispatch: ${axis} — ([a-z0-9-]+) — .*\$/\\1/p"
}

# Resolve a predecessor task id to exactly one top-level board entry,
# searching BOTH `## Active` (`- [ ] **T-NNN** `) and `## Done`
# (`- [x] **T-NNN** `) — a SECOND scan, distinct from and never a widening
# of the --task entry's own ## Active-only resolution above (## Assumptions
# row A-8: that resolution keeps its forward-only scoping and its own
# exit-2-on-failure contract unchanged). An unresolvable or ambiguous
# PREDECESSOR reference is a content refusal about the board's own record
# (exit 1 via the caller's `fail`), never a usage error. Prints the
# resolved entry's text (CR stripped, same tolerance as `$ENTRY` above) on
# stdout and returns 0 on exactly one match; returns 1 (prints nothing)
# otherwise.
resolve_predecessor_entry() {  # $1 = predecessor task id
  local pid="$1" scan p_start p_end p_count
  scan="$(awk -v pid="$pid" '
    BEGIN { sec=""; p_start=0; p_end=0; p_count=0; capturing=0 }
    /^## /  { sec=$0; capturing=0 }
    {
      if (sec ~ /^## Active/ && $0 ~ ("^- \\[ \\] \\*\\*" pid "\\*\\* ")) {
        p_count++; p_start=NR; p_end=NR; capturing=1; next
      }
      if (sec ~ /^## Done/ && $0 ~ ("^- \\[x\\] \\*\\*" pid "\\*\\* ")) {
        p_count++; p_start=NR; p_end=NR; capturing=1; next
      }
      if (capturing) {
        if ($0 ~ /^[[:space:]]*$/) { next }
        if ($0 ~ /^[[:space:]]+[^[:space:]]/) { p_end=NR; next }
        capturing=0
      }
    }
    END { print p_start, p_end, p_count }
  ' "$BOARD")"
  read -r p_start p_end p_count <<< "$scan"
  [ "$p_count" -eq 1 ] || return 1
  sed -n "${p_start},${p_end}p" "$BOARD" | sed 's/\r$//'
}

REFL_AXES=" "
REFL_HAS_ALL=0
REFL_ROW_COUNT=0
REFL_ROWS=""

while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [[ "$line" =~ $refl_stem_re ]]; then
    if [[ "$line" =~ $refl_full_re ]]; then
      r_axis="${BASH_REMATCH[1]}"
      r_pred="${BASH_REMATCH[2]}"
      r_verdict="${BASH_REMATCH[3]}"
      r_ground="${BASH_REMATCH[4]}"
      [ -n "$r_ground" ] || fail "$TASK has a \`- dispatch-reflection:\` sub-bullet with an empty ground field: $line"
      case "$r_axis" in
        all)
          REFL_HAS_ALL=1
          if [ "$r_pred" != "no-predecessor" ] || [ "$r_verdict" != "no-predecessor-row" ]; then
            fail "$TASK has a malformed \`- dispatch-reflection: all\` sub-bullet — the no-predecessor form requires exactly \`all — no-predecessor — no-predecessor-row — <ground>\`: $line"
          fi
          ;;
        implement|verify|verify-fixture|verify-mechanism|specify|spec-review) : ;;
        *)
          fail "$TASK has a malformed \`- dispatch-reflection:\` sub-bullet (axis '$r_axis' is not one of the closed dispatch-axis keys, and is not 'all'): $line"
          ;;
      esac
      case "$REFL_AXES" in
        *" $r_axis "*) fail "$TASK has a malformed \`- dispatch-reflection:\` sub-bullet (axis '$r_axis' appears more than once on this entry): $line" ;;
      esac
      REFL_AXES="${REFL_AXES}${r_axis} "
      REFL_ROW_COUNT=$((REFL_ROW_COUNT + 1))
      REFL_ROWS="${REFL_ROWS}${r_axis}|${r_pred}|${r_verdict}"$'\n'
    else
      fail "$TASK has a malformed \`- dispatch-reflection:\` sub-bullet (does not parse into '<axis> — <predecessor> — <verdict> — <ground>'): $line"
    fi
  fi
done <<< "$ENTRY"

if [ "$REFL_ROW_COUNT" -gt 0 ]; then
  # T-1109 Goal: the no-predecessor form and a per-axis row are mutually
  # exclusive on one entry — never mixed.
  if [ "$REFL_HAS_ALL" -eq 1 ] && [ "$REFL_ROW_COUNT" -gt 1 ]; then
    fail "$TASK mixes the \`- dispatch-reflection: all — no-predecessor\` form with a per-axis \`- dispatch-reflection:\` row — record either the single no-predecessor line or one row per axis, never both"
  fi

  if [ "$REFL_HAS_ALL" -eq 0 ]; then
    # This entry's own `- dispatch:` axis -> value map, read the same
    # anchored way `bin/close-out.sh`'s `DISPATCH_LINES` loop already does
    # (T-1084/T-1100's grammar), used for two purposes below: coverage
    # (every axis this entry itself records must carry a reflection row,
    # ## Assumptions A-8's subject) and duty B (this entry's own recorded
    # value for an axis, compared against the predecessor's).
    #
    # Codex review round 1, Minor: a malformed (e.g. doubled-space-after-
    # dash) `- dispatch:` row on the CURRENT entry was silently invisible
    # to this axis set, letting that axis escape the "no cherry-picking"
    # coverage requirement entirely. Collect wide (tolerating extra space
    # after the bullet dash) and refuse if that widens the count beyond
    # the strict single-space read below — the same collect-wide/parse-
    # strict discipline already applied to the reflection stem, now
    # applied here too, since a fail-closed coverage judgment depends on
    # reading this line correctly.
    #
    # Codex review round 2, Major (regression): this whole block used to
    # sit ABOVE the `$REFL_ROW_COUNT` gate and ran unconditionally, so an
    # entry with ZERO `- dispatch-reflection:` rows whose pre-existing
    # `- dispatch:` lines merely carried a spacing quirk was refused with
    # no reflection family to judge at all — breaking AC6's validate-if-
    # present guarantee for every non-adopting task. There is no coverage
    # or duty-B judgment to protect unless a reflection family actually
    # exists, so this whole read now lives inside the same
    # `$REFL_HAS_ALL -eq 0` gate the coverage/duty-B logic below already
    # runs under, never above it.
    ENTRY_DISPATCH_WIDE="$(printf '%s\n' "$ENTRY" | grep -E -- '^[[:space:]]*-[[:space:]]+dispatch: ' || true)"
    ENTRY_DISPATCH_LINES="$(printf '%s\n' "$ENTRY" | grep -E -- '^[[:space:]]*- dispatch: ' || true)"
    if [ "$(printf '%s\n' "$ENTRY_DISPATCH_WIDE" | grep -c . || true)" != "$(printf '%s\n' "$ENTRY_DISPATCH_LINES" | grep -c . || true)" ]; then
      fail "$TASK has a malformed \`- dispatch:\` sub-bullet — its spacing does not match the canonical single-space grammar, so this entry's dispatch-reflection coverage cannot be judged against it cleanly"
    fi
    ENTRY_DISPATCH_AXES="$(printf '%s\n' "$ENTRY_DISPATCH_LINES" | sed -nE 's/^[[:space:]]*- dispatch: ([a-z0-9-]+) — .*$/\1/p')"

    # Coverage, BOTH directions (Codex review round 1, Major 1: the check
    # was one-directional — dispatch-axes subset-of reflection-axes was
    # enforced, but reflection-axes subset-of dispatch-axes never was, so
    # a spurious reflection row for an axis this entry never elected slips
    # through — duty B's own comparison alone cannot catch it, since an
    # empty own_value makes "differs" a trivially-satisfiable "expected"
    # verdict against any non-empty predecessor value). ENTRY_DISPATCH_AXES
    # and REFL_AXES must name the SAME axis set, checked as two membership
    # tests rather than one.
    ENTRY_DISPATCH_AXES_PADDED=" "
    while IFS= read -r d_axis; do
      [ -n "$d_axis" ] || continue
      ENTRY_DISPATCH_AXES_PADDED="${ENTRY_DISPATCH_AXES_PADDED}${d_axis} "
      case "$REFL_AXES" in
        *" $d_axis "*) : ;;
        *) fail "$TASK's \`- dispatch-reflection:\` family does not cover axis '$d_axis', which this entry's own \`- dispatch:\` rows record" ;;
      esac
    done <<< "$ENTRY_DISPATCH_AXES"

    while IFS= read -r r_axis; do
      [ -n "$r_axis" ] || continue
      case "$ENTRY_DISPATCH_AXES_PADDED" in
        *" $r_axis "*) : ;;
        *) fail "$TASK's \`- dispatch-reflection:\` family names axis '$r_axis', which this entry's own \`- dispatch:\` rows do not record" ;;
      esac
    done <<< "$(printf '%s' "$REFL_AXES" | tr ' ' '\n')"

    # Single-predecessor + no-self-reference invariant (Codex review
    # round 1, Major 2): nothing enforced that every reflection row on one
    # entry names the SAME predecessor id, and nothing rejected the
    # current task naming itself — either gap lets an entry trivially
    # satisfy duty B (an entry's own value always equals itself) while
    # providing zero real cross-checking. Collect every row's predecessor
    # id first; require exactly one distinct value across the whole
    # family, and refuse a self-reference outright, before any per-row
    # resolution below ever runs.
    REFL_PRED=""
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      r_axis="${row%%|*}"; rest="${row#*|}"
      r_pred="${rest%%|*}"
      if [ "$r_pred" = "$TASK" ]; then
        fail "$TASK's \`- dispatch-reflection: $r_axis\` sub-bullet names itself ('$r_pred') as its own predecessor — a task can never be its own predecessor"
      fi
      if [ -z "$REFL_PRED" ]; then
        REFL_PRED="$r_pred"
      elif [ "$r_pred" != "$REFL_PRED" ]; then
        fail "$TASK's \`- dispatch-reflection:\` family names more than one predecessor ('$REFL_PRED' and '$r_pred') — every row must name the same immediately preceding task"
      fi
    done <<< "$REFL_ROWS"

    # Duty B: the stated verdict must agree with the predecessor's own
    # recorded value for that axis.
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      r_axis="${row%%|*}"; rest="${row#*|}"
      r_pred="${rest%%|*}"; r_verdict="${rest#*|}"

      pred_entry_text="$(resolve_predecessor_entry "$r_pred")" \
        || fail "$TASK's \`- dispatch-reflection: $r_axis\` sub-bullet names predecessor '$r_pred', which does not resolve to exactly one top-level board entry in ## Active or ## Done"

      own_value="$(dispatch_value_for_axis "$ENTRY_DISPATCH_LINES" "$r_axis" "$TASK's own entry")"
      pred_value="$(dispatch_value_for_axis "$pred_entry_text" "$r_axis" "predecessor '$r_pred'")"

      if [ -z "$pred_value" ]; then
        if [ "$r_verdict" != "no-predecessor-row" ]; then
          fail "$TASK's \`- dispatch-reflection: $r_axis\` sub-bullet states verdict '$r_verdict', but predecessor '$r_pred' records no \`- dispatch: $r_axis\` row of its own — the only conformant verdict here is 'no-predecessor-row'"
        fi
      else
        expected_verdict="differs"
        [ "$own_value" = "$pred_value" ] && expected_verdict="repeat"
        if [ "$r_verdict" != "$expected_verdict" ]; then
          fail "$TASK's \`- dispatch-reflection: $r_axis\` sub-bullet states verdict '$r_verdict', but predecessor '$r_pred''s own recorded value ('$pred_value') and this entry's own recorded value ('$own_value') disagree with it — the correct verdict here is '$expected_verdict'"
        fi
      fi
    done <<< "$REFL_ROWS"
  fi
fi

exit 0
