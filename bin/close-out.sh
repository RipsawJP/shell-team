#!/usr/bin/env bash
# close-out.sh — one-command post-merge close-out for a board task (T-038).
#
# Does, in order:
#   1. Moves the task's top-level line plus its entry extent — per the
#      board-entry continuation canon (T-1016): blank/indented lines of
#      any shape belong to the entry, trailing blanks trimmed — from
#      `## Active` to the TOP of `## Done`, rewriting the flag to
#      `READY_FOR_MERGE`. Keeps the hand-off grammar of check-handoff.sh's
#      LINE_RE (flag backticks directly followed by ` — spec:`, NO
#      parenthetical — T-030 rework); closure provenance (date/PR/issue)
#      goes into a new sub-bullet instead of the title line.
#   2. Prints the manual issue-close procedure to stdout. This script NEVER
#      calls `gh` or the GitHub API (sandboxes can't; the human/orchestrator
#      runs the printed command).
#   3. Emits ONE best-effort telemetry span via the sibling log-run.sh — a
#      telemetry failure never fails the close-out and never rolls back the
#      board write.
#   4. Regenerates the project_status generated block via the sibling
#      gen-project-status.sh — also best-effort (skipped with a note when the
#      status file or its markers are absent, e.g. a host that never adopted
#      the generated block).
#
# Before any of the above runs, fail-closed gates must pass, in order: T-068's
# pending fast-follow disposition gate, then T-1084's situational dispatch
# record gate (validate-if-present — silent when no `- dispatch:` sub-bullet
# exists), then T-1017's interventions gate, then T-1096's close-out spec-
# review backstop (#344, validate-if-present — silent when the task did not
# elect `spec-review — cross-provider`), then T-1022's source-line gate —
#   a missing or non-conformant interventions record refuses the close-out before any board write.
#   an elected spec review whose record's last verdict is not an approval refuses the close-out before any board write.
#   a source line the hand-off lint would reject refuses the close-out before any board write.
#   a malformed `- dispatch:` sub-bullet refuses the close-out before any board write.
#
# T-1096's backstop is deliberately NOT a general-purpose reader: it invokes
# the sibling bin/check-spec-review.sh, which resolves its own reviews
# directory ($TEAM_REVIEWS_DIR at the same override precedence
# $TEAM_INTERVENTIONS_DIR already has below, else the sibling
# team-paths.sh) and refuses a task whose elected review's record has no
# last verdict line reading an approval. The OTHER pre-freeze gate this
# same task ships (#341's board-sub-bullet reader, a distinct sibling under
# bin/) is deliberately NOT invoked anywhere in this file — its own
# forward-only scoping depends on firing only at the pre-freeze seam for
# the one task being frozen, never here.
# The interventions record is resolved from $TEAM_INTERVENTIONS_DIR (same
# override precedence as $TEAM_TODO below) or else the sibling team-paths.sh,
# then verified with the sibling check-interventions.sh --task T-NNN. The
# gate reads ONE path for the task being closed — no other task's record, no
# ## Done history, no backfill or migration.
#
# T-1022's source-line gate (#98) judges the task's Active source line the
# same way check-handoff.sh would, by feeding it a synthesized single-entry
# board rather than keeping a second copy of the line grammar here —
#   the Active line's status flag must be in the allowed vocabulary — an invalid flag is no longer silently rewritten.
# A single sibling screen sits ahead of the FIRST check-handoff.sh
# invocation (this gate) and covers the pre-write interlock below too —
#   a missing or unreadable check-handoff.sh sibling is exit 2 (it was exit 1 before this change).
#
# The board path comes from $TEAM_TODO if set, else the sibling team-paths.sh
# resolves it from cwd (.shell-team/todo.md by default, tasks/todo.md in a
# legacy layout). Unlike telemetry there is NO guessed fallback: if the
# resolver is unavailable the script exits 2 without touching anything —
# writing the board to a guessed path would be worse than failing.
#
# Fail-closed: every input is validated before any write, the rewrite goes to
# a temp file first, and the temp board must pass the sibling check-handoff.sh
# lint before it replaces the real board.
#
# Usage:
#   close-out.sh --task T-NNN [--issue N] [--pr N] [--date YYYY-MM-DD] [--note TEXT]
#
#   --task   the board task ID to close out (required, shape ^T-[0-9]+$)
#   --issue  GitHub issue number the task closes (drives the printed procedure)
#   --pr     merged PR number (recorded in the closure sub-bullet)
#   --date   closure date, default: today (UTC not forced; pass explicitly in tests)
#   --note   free-text closure note (single line; control chars rejected)
#
# Exit: 0 = board updated; 1 = task not in Active (missing or already Done),
#       board shape error, an unresolved fast-follow disposition, a
#       missing/unreadable/non-conformant interventions record, or a source
#       line the hand-off lint would reject; 2 = usage / validation /
#       resolver error, or an unusable interventions checker,
#       interventions-directory resolver, or check-handoff.sh sibling. On any
#       non-zero exit the board file is byte-untouched. In one line:
#   a missing, unreadable or non-conformant interventions record is exit 1; an unusable checker or resolver is exit 2.

set -euo pipefail

die()  { printf 'close-out: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'close-out: %s\n' "$1" >&2 || true; exit 1; }

# Resolve this script's own directory (symlink-safe) so sibling helpers work
# regardless of cwd / how we were invoked — same pattern as log-run.sh.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

TASK="" ISSUE="" PR="" DATE="" NOTE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task|--issue|--pr|--date|--note)
      [ "$#" -ge 2 ] || die "missing value for $1"
      case "$1" in
        --task)  TASK="$2" ;;
        --issue) ISSUE="$2" ;;
        --pr)    PR="$2" ;;
        --date)  DATE="$2" ;;
        --note)  NOTE="$2" ;;
      esac
      shift 2
      ;;
    --help|-h)
      # T-1022 D7: the extent is derived at run time from the file's own
      # contiguous leading comment block starting at line 2 — never a
      # hardcoded range (a bare number bump is the vacuous fix this task
      # exists to avoid; T-1017 already had to bump this exact number once).
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "$script_path"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

# --- validation (fail-closed, before any write) ------------------------------
[ -n "$TASK" ] || die "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || die "invalid --task '$TASK' (expected T-<digits>)"
[[ -z "$ISSUE" || "$ISSUE" =~ ^[1-9][0-9]*$ ]] || die "--issue must be a positive integer: '$ISSUE'"
[[ -z "$PR"    || "$PR"    =~ ^[1-9][0-9]*$ ]] || die "--pr must be a positive integer: '$PR'"
if [ -z "$DATE" ]; then DATE="$(date +%F)"; fi
[[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "invalid --date '$DATE' (expected YYYY-MM-DD)"
# The note is injected verbatim into a board line: any control char (newline,
# tab, CR, …) could break the line-oriented hand-off grammar or smuggle in a
# second line — reject, same rigor as log-run.sh's loop_id charset guard.
# Multibyte text (e.g. Japanese) is fine: UTF-8 continuation bytes are not
# control chars under LC_ALL=C.
# grep is line-oriented and never sees the newline separator itself, so the
# newline check must be a bash pattern match; grep then catches the remaining
# in-line control chars (tab, CR, …).
if [ -n "$NOTE" ]; then
  if [[ "$NOTE" == *$'\n'* ]]; then
    die "--note must be a single line without control characters"
  fi
  if printf '%s' "$NOTE" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "--note must be a single line without control characters"
  fi
  # Board content is data, never executed — but per the spec's "same rigor as
  # log-run.sh's charset guard" (AC6) the shell metacharacters that could turn
  # a note into something else downstream are rejected outright. Multibyte
  # prose (Japanese punctuation etc.) stays allowed.
  if [[ "$NOTE" == *'`'* || "$NOTE" == *'$'* || "$NOTE" == *"\\"* || "$NOTE" == *'"'* ]]; then
    die "--note must not contain shell metacharacters (backtick, \$, backslash, double quote)"
  fi
fi

# --- board resolution ---------------------------------------------------------
if [ -n "${TEAM_TODO:-}" ]; then
  BOARD="$TEAM_TODO"
else
  BOARD="$(bash "$SCRIPT_DIR/team-paths.sh" --get todo 2>/dev/null)" \
    || die "cannot resolve board path (team-paths.sh unavailable) — set \$TEAM_TODO or fix the install"
fi
[ -r "$BOARD" ] || die "cannot read board: $BOARD"

# --- pass 1: locate the task (no writes) --------------------------------------
# Emits: "<active_start> <active_end> <active_count> <done_count>"
#   active_start/end — 1-based line range of the task's Active entry EXTENT
#                      (through its last continuation line, canon per header)
#   active_count     — top-level Active matches (must be exactly 1)
#   done_count       — matches in Done (drives the "already closed" message)
scan="$(awk -v task="$TASK" '
  BEGIN { sec=""; a_start=0; a_end=0; a_count=0; d_count=0; capturing=0 }
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
  sec ~ /^## Done/ {
    if ($0 ~ ("^- \\[[x ]\\] (\\*\\*)?" task "(\\*\\*)? ")) d_count++
  }
  END { print a_start, a_end, a_count, d_count }
' "$BOARD")"
read -r A_START A_END A_COUNT D_COUNT <<< "$scan"

if [ "$A_COUNT" -eq 0 ]; then
  if [ "$D_COUNT" -gt 0 ]; then
    fail "$TASK is already in ## Done — refusing to create a duplicate entry"
  fi
  fail "$TASK not found as a top-level entry in ## Active of $BOARD"
fi
[ "$A_COUNT" -eq 1 ] || fail "$TASK appears $A_COUNT times in ## Active — board needs manual repair"
grep -q '^## Done' "$BOARD" || fail "board has no ## Done section: $BOARD"

# --- fail-closed gate: no unresolved `pending` fast-follow disposition (T-068) -
# A `- fast-follow disposition (...)` sub-bullet carrying a time-bound
# `pending:` placeholder must be resolved to `filed as issue #N` or
# `waived: <reason>` BEFORE close-out — the invariant the fast-follow
# disposition rule states. close-out copies sub-bullets verbatim, so without
# this content gate the invariant would be declaration-only. Scan just this
# task's Active entry range (A_START..A_END). The first grep is ANCHORED to a
# disposition sub-bullet's line-start shape (^whitespace + "- fast-follow
# disposition (") so hand-off PROSE that merely quotes the anchor string and
# `pending:` on one line (e.g. a backticked mention in a rework note) is NOT
# mistaken for a real disposition line; the second grep then rejects only when
# that anchored line still carries the literal `pending:` token (the resolved
# forms `filed as issue #N` / `waived:` carry no `pending:`).
if sed -n "${A_START},${A_END}p" "$BOARD" \
     | grep -E -- '^[[:space:]]*- fast-follow disposition \(' \
     | grep -Fq 'pending:'; then
  fail "$TASK has an unresolved pending fast-follow disposition — resolve it to a filed issue number or a waived reason before close-out (a pending disposition must not survive close-out)"
fi

# --- fail-closed gate: the situational dispatch record grammar (T-1084) -------
# A validate-if-present content gate, in the exact shape of the `pending:`
# gate above: it says NOTHING when the task's Active entry carries no
# `- dispatch:` sub-bullet at all (adopter back-compat — presence is the
# shipped norm text's requirement, `templates/prompt-blocks/dispatch-record.md`,
# never this script's), and it refuses (exit 1) the first malformed record it
# finds. Scan just this task's Active entry range (A_START..A_END). The scan
# grep is ANCHORED to a `- dispatch:` sub-bullet's line-start shape
# (^whitespace + "- dispatch:") so hand-off PROSE that merely quotes the
# grammar mid-line (e.g. a backticked example inside a note) is NOT mistaken
# for a real record — same discipline as the `pending:` gate's anchored first
# match above.
#
# Round-1 rework (Codex review): the anchor deliberately carries NO
# trailing-space requirement after the colon. A candidate-scan anchor of
# `^[[:space:]]*- dispatch: ` (trailing space required) made a line opening
# `- dispatch:` with anything else there — a tab, two spaces, no space at
# all — INVISIBLE to the whole gate: never even inspected, not merely
# refused on a looser check (a full silent bypass, reproduced live against
# this script). Every one of those whitespace variants must be SEEN by the
# scan; the strict per-field `sed` extraction below (which still requires
# the canonical single-space " — "-separated shape) then fails closed on
# them via the existing empty-field check, exactly as it already does for a
# wrong internal separator. A line not opening with the literal bullet
# marker "- dispatch:" at all (a double-hyphen "-- dispatch:", a missing
# colon) stays outside this gate's scan, unchanged from before this round —
# that is the same scope boundary the pre-existing `pending:` gate above
# also has (its own anchor requires the single-hyphen "- " bullet marker
# literally), not a new gap this task's own diff introduces, and no
# reachable input class in this spec's `## Input space` names it.
#
# The axis -> closed-value-set table is the ONE place a later axis (issue
# #274's depth axis) is added; nothing below hardcodes a count of axes.
DISPATCH_AXIS_TABLE="implement:serial|tier2|tier3
verify:serial|tier1-fanout
specify:pm-authored|operator-authored
spec-review:none|cross-provider"

DISPATCH_LINES="$(sed -n "${A_START},${A_END}p" "$BOARD" \
     | grep -E -- '^[[:space:]]*- dispatch:' || true)"

# T-1096 (#344): the spec-review election, captured while this same loop
# already walks every dispatch line — never a second, independent parse of
# the board. Empty unless a well-formed `spec-review` row is seen below;
# used only to decide whether the backstop gate further down needs to
# resolve a reviews directory at all (validate-if-present: an entry that
# never elects `spec-review — cross-provider` must not pay for, or fail on,
# a reviews-directory resolution it has no use for).
SPEC_REVIEW_ELECTION=""

if [ -n "$DISPATCH_LINES" ]; then
  DISPATCH_SEEN_AXES=" "
  while IFS= read -r d_line; do
    [ -n "$d_line" ] || continue

    # Extract the four ` — `-separated fields (space, em dash, space). The
    # ground field is free text and may itself contain further ` — `
    # sequences (T-1084 Input space) — each extraction below anchors on the
    # FIRST three separators only and lets the ground's own pattern (.*)
    # swallow everything after the third, so an em dash inside the
    # explanatory prose never truncates it.
    d_axis="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: ([a-z0-9-]+) — .*$/\1/p')"
    d_value="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: [a-z0-9-]+ — ([a-z0-9-]+) — .*$/\1/p')"
    d_modality="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: [a-z0-9-]+ — [a-z0-9-]+ — ([a-z]+) — .*$/\1/p')"
    d_ground="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: [a-z0-9-]+ — [a-z0-9-]+ — [a-z]+ — (.*)$/\1/p')"

    if [ -z "$d_axis" ] || [ -z "$d_value" ] || [ -z "$d_modality" ] || [ -z "$d_ground" ]; then
      fail "$TASK has a malformed dispatch record (does not match the grammar '- dispatch: <axis> — <value> — <unconditional|conditional> — <ground>'): $d_line"
    fi

    d_row="$(printf '%s\n' "$DISPATCH_AXIS_TABLE" | grep -E -- "^${d_axis}:" || true)"
    if [ -z "$d_row" ]; then
      fail "$TASK has a malformed dispatch record (axis '$d_axis' is not one of the note's own dispatch-axis keys): $d_line"
    fi

    case "$DISPATCH_SEEN_AXES" in
      *" $d_axis "*)
        fail "$TASK has a malformed dispatch record (axis '$d_axis' appears more than once on this entry): $d_line"
        ;;
    esac
    DISPATCH_SEEN_AXES="${DISPATCH_SEEN_AXES}${d_axis} "

    d_valueset="${d_row#*:}"
    if ! printf '%s\n' "$d_value" | grep -qE -- "^(${d_valueset})\$"; then
      fail "$TASK has a malformed dispatch record (value '$d_value' is not in axis '$d_axis''s closed set '${d_valueset}'): $d_line"
    fi

    if ! printf '%s\n' "$d_modality" | grep -qE -- '^(unconditional|conditional)$'; then
      fail "$TASK has a malformed dispatch record (modality '$d_modality' is not unconditional or conditional): $d_line"
    fi

    # Round-1 rework (Codex review): the prefix-and-space were checked but
    # never the id itself, so `recommendation: ` (prefix, space, nothing) — a
    # realistic authoring slip (dropping the id while leaving the label) —
    # passed this check. Requires a non-empty `[a-z0-9-]+`-shaped token
    # immediately after the matched prefix, the same id shape AC9's own
    # extraction pattern already assumes.
    if ! printf '%s\n' "$d_ground" | grep -qE -- '^(saving|recommendation|break-even|cost-input): [a-z0-9-]+'; then
      fail "$TASK has a malformed dispatch record (ground does not open with a non-empty id after saving:/recommendation:/break-even:/cost-input:): $d_line"
    fi

    if [ "$d_axis" = "spec-review" ]; then
      SPEC_REVIEW_ELECTION="$d_value"
    fi
  done <<< "$DISPATCH_LINES"
fi

# --- fail-closed gate: the task's interventions record exists and conforms ----
# (T-1017). The interventions record is the only durable channel for a human
# interrupting, a measurement contradicting an assumption, or work deferred or
# abandoned (T-1002 / check-interventions.sh). This gate reads ONE path for
# the task being closed — no other task's record, no ## Done history, no
# backfill or migration. Resolution: $TEAM_INTERVENTIONS_DIR at the same
# override precedence $TEAM_TODO already has above, else the sibling
# team-paths.sh; a resolver failure is exit 2 with no guessing fallback (a
# guessed directory that happens to be empty would misattribute a refusal,
# and one that happens to hold a same-named file would verify the wrong
# task's record).
if [ -n "${TEAM_INTERVENTIONS_DIR:-}" ]; then
  INTERVENTIONS_DIR="$TEAM_INTERVENTIONS_DIR"
else
  INTERVENTIONS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get interventions 2>/dev/null)" \
    || die "cannot resolve the interventions directory (team-paths.sh unavailable) — set \$TEAM_INTERVENTIONS_DIR or fix the install"
fi
RECORD="$INTERVENTIONS_DIR/$TASK.md"

# Prints the one-step remedy (D7): the record path as resolved, the working
# directory, and the three literal lines of a conformant zero-entry record —
# content, never a runnable command (the two execution contexts this plugin
# ships into would otherwise need their own printed invocation). Exit-1
# refusals only (rows i-iii below); never printed on the exit-2 refusals,
# where the problem is the install/environment rather than the record.
print_interventions_remedy() {
  printf 'close-out: record path: %s\n' "$RECORD" >&2 || true
  printf 'close-out: working directory: %s\n' "$(pwd)" >&2 || true
  printf 'close-out: remedy — write a conformant record with exactly:\n' >&2 || true
  printf '<!-- BEGIN interventions: %s -->\n' "$TASK" >&2 || true
  printf 'no interventions occurred\n' >&2 || true
  printf '<!-- END interventions: %s -->\n' "$TASK" >&2 || true
}

# Row (i): screened before the checker ever runs — a missing path, a
# directory, a FIFO, an unreadable file or a dangling symlink are all "no
# readable record".
if [ ! -f "$RECORD" ] || [ ! -r "$RECORD" ]; then
  printf 'close-out: %s has no readable interventions record: %s\n' "$TASK" "$RECORD" >&2 || true
  print_interventions_remedy
  exit 1
fi

CHECKER="$SCRIPT_DIR/check-interventions.sh"
if [ ! -f "$CHECKER" ] || [ ! -r "$CHECKER" ]; then
  die "cannot verify the interventions record (check-interventions.sh missing or unreadable next to close-out.sh)"
fi

# Captured into a variable rather than a temp file: this gate sits ahead of
# the mktemp/trap block below, and `trap ... EXIT` is not additive, so a
# second temp file here would need a second trap (T-1017 Notes for
# engineer). Redirect order matters: `2>&1 >/dev/null` sends the checker's
# stderr into the capture and discards its stdout.
CK_ERR="$(bash "$CHECKER" --task "$TASK" -- "$RECORD" 2>&1 >/dev/null)" && CK_RC=0 || CK_RC=$?

if [ "$CK_RC" -ne 0 ]; then
  # D5 (T-1016's pattern): the checker's own stderr is surfaced BEFORE this
  # script's own reason string.
  if [ -n "$CK_ERR" ]; then
    printf '%s\n' "$CK_ERR" >&2 || true
  fi
  case "$CK_RC" in
    1)
      # Row (ii): checker exit 1 (schema violation).
      printf 'close-out: %s interventions record does not conform: %s\n' "$TASK" "$RECORD" >&2 || true
      print_interventions_remedy
      exit 1
      ;;
    2)
      # The checker conflates usage and structural under its own exit 2;
      # classification matches the documented `check-interventions: <token>: `
      # prefix, never message prose.
      case "$CK_ERR" in
        *'check-interventions: structural:'*)
          # Row (iii): normalized to exit 1, NOT passed through — a
          # structural defect (absent/duplicated/reversed markers, a
          # BEGIN/END id mismatch, a --task disagreement) is a defect in the
          # operator's record, remediable by editing it, same class as a
          # schema violation.
          printf 'close-out: %s interventions record does not conform: %s\n' "$TASK" "$RECORD" >&2 || true
          print_interventions_remedy
          exit 1
          ;;
        *'check-interventions: usage:'*)
          # Row (iv): the arguments close-out itself constructed were
          # rejected; no edit to the record can fix this, so it stays exit 2
          # with no remedy block.
          die "cannot verify the interventions record ($TASK: check-interventions.sh rejected its own invocation)"
          ;;
        *)
          # Row (vi), fail-closed floor: an exit-2 with no recognized token
          # is never guessed into row (iii).
          die "cannot verify the interventions record ($TASK: check-interventions.sh returned an unrecognized classification)"
          ;;
      esac
      ;;
    *)
      # Row (vi), fail-closed floor: any status other than 0/1/2 — keyed on
      # the status FIRST, a token is only consulted within status 2.
      die "cannot verify the interventions record ($TASK: check-interventions.sh exited $CK_RC)"
      ;;
  esac
fi

# --- build the Done entry ------------------------------------------------------
MAIN_LINE="$(sed -n "${A_START}p" "$BOARD")"
# Rewrite `— \`<FLAG>\` — spec:` to READY_FOR_MERGE, keeping everything else.
# The greedy prefix group anchors on the LAST ` — \`…\` — spec: ` separator, so
# backticked tokens inside the title cannot be mistaken for the flag — the
# same rightmost slot check-handoff.sh's line grammar resolves too (T-1031).
if [[ "$MAIN_LINE" =~ ^(.+)\ —\ \`[^\`]+\`\ —\ spec:\ ([^[:space:]]+\.md)[[:space:]]*$ ]]; then
  DONE_MAIN="${BASH_REMATCH[1]} — \`READY_FOR_MERGE\` — spec: ${BASH_REMATCH[2]}"
  DONE_MAIN="- [x] ${DONE_MAIN#- \[ \] }"
else
  fail "Active line for $TASK does not match the hand-off grammar: $MAIN_LINE"
fi

CLOSURE="  - closed: ${DATE}"
if [ -n "$PR" ];    then CLOSURE="${CLOSURE}, PR #${PR} → develop"; fi
if [ -n "$ISSUE" ]; then CLOSURE="${CLOSURE}, closes #${ISSUE}"; fi
if [ -n "$NOTE" ];  then CLOSURE="${CLOSURE} — ${NOTE}"; fi

ENTRY_FILE="$(mktemp "${TMPDIR:-/tmp}/close-out-entry.XXXXXX")"
TMP_BOARD="$(mktemp "${TMPDIR:-/tmp}/close-out-board.XXXXXX")"
GATE_ERR="$(mktemp "${TMPDIR:-/tmp}/close-out-gate-err.XXXXXX")"
SYN_BOARD="$(mktemp "${TMPDIR:-/tmp}/close-out-synboard.XXXXXX")"
trap 'rm -f "$ENTRY_FILE" "$TMP_BOARD" "$GATE_ERR" "$SYN_BOARD"' EXIT

# --- fail-closed gate: an elected spec review must have reached an ---------
# approval verdict (T-1096, #344). Validate-if-present, matching the
# dispatch grammar gate's own back-compat shape above: an entry that never
# elects `spec-review — cross-provider` — `none`, or no `spec-review` row at
# all — must not pay for, or fail on, a reviews-directory resolution it has
# no use for, so this whole gate is SKIPPED (not merely a silent pass
# inside the checker) unless SPEC_REVIEW_ELECTION was captured above as
# exactly `cross-provider`. Resolution then mirrors the interventions-
# directory resolution above: an env override at the same precedence
# $TEAM_TODO/$TEAM_INTERVENTIONS_DIR already have, else the sibling
# team-paths.sh — this task's own reader (bin/check-spec-review.sh) then
# additionally validates the resolved value is a directory, refusing with
# its own exit 2 when it is not, rather than a guessing fallback.
if [ "$SPEC_REVIEW_ELECTION" = "cross-provider" ]; then
  if [ -n "${TEAM_REVIEWS_DIR:-}" ]; then
    REVIEWS_DIR="$TEAM_REVIEWS_DIR"
  else
    REVIEWS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get reviews 2>/dev/null)" \
      || die "cannot resolve the reviews directory (team-paths.sh unavailable) — set \$TEAM_REVIEWS_DIR or fix the install"
  fi
  export TEAM_REVIEWS_DIR="$REVIEWS_DIR"

  SPEC_REVIEW_CHECKER="$SCRIPT_DIR/check-spec-review.sh"
  if [ ! -f "$SPEC_REVIEW_CHECKER" ] || [ ! -r "$SPEC_REVIEW_CHECKER" ]; then
    die "cannot verify the elected spec review (check-spec-review.sh missing or unreadable next to close-out.sh)"
  fi

  SR_ERR="$(bash "$SPEC_REVIEW_CHECKER" --board "$BOARD" --task "$TASK" 2>&1 >/dev/null)" && SR_RC=0 || SR_RC=$?
  if [ "$SR_RC" -ne 0 ]; then
    if [ -n "$SR_ERR" ]; then
      printf '%s\n' "$SR_ERR" >&2 || true
    fi
    case "$SR_RC" in
      1)
        fail "$TASK's elected spec review has no APPROVE verdict"
        ;;
      *)
        die "cannot verify the elected spec review ($TASK: check-spec-review.sh exited $SR_RC)"
        ;;
    esac
  fi
fi

# --- sibling screen (T-1022 D5/#101): ahead of the FIRST check-handoff.sh
# invocation below (the source-line gate) — covers the pre-write interlock
# further down too, so there is exactly one of it. A missing or unreadable
# sibling is an install problem, not a board defect, and must not surface as
# a lint failure at exit 1. Modelled on the check-interventions.sh screen
# above: an -f/-r test, die (exit 2), a named reason, no remedy block.
HANDOFF_LINT="$SCRIPT_DIR/check-handoff.sh"
if [ ! -f "$HANDOFF_LINT" ] || [ ! -r "$HANDOFF_LINT" ]; then
  die "cannot run the hand-off lint (check-handoff.sh missing or unreadable next to close-out.sh)"
fi

# --- fail-closed gate: the Active source line must pass the hand-off lint
# (T-1022 #98/D1/D3). Judged by feeding a synthesized single-entry board to
# the sibling check-handoff.sh itself — no local copy of LINE_RE or the flag
# vocabulary — so a flag outside ALLOWED_FLAGS is refused instead of being
# silently rewritten to READY_FOR_MERGE (D1's declared additional refusal
# class). The synthesized board carries one `## Active` heading, one blank
# line, and MAIN_LINE verbatim (trailing CR included, per the Terms table) —
# no other `- [ ]` line anywhere in that section.
printf '## Active\n\n%s\n' "$MAIN_LINE" > "$SYN_BOARD"
SL_ERR="$(bash "$HANDOFF_LINT" "$SYN_BOARD" 2>&1 >/dev/null)" && SL_RC=0 || SL_RC=$?
case "$SL_RC" in
  0)
    : # the synthesized board is clean — nothing to refuse
    ;;
  1)
    # Row (i): a violation on the synthesized board (format mismatch, or an
    # unknown status flag). D4's three-part frozen order: the
    # synthesized-board note, then the checker's own stderr verbatim (never
    # rewritten or filtered), then reason F carrying the REAL board path and
    # the real source-line number — never the temp file's.
    printf 'close-out: the file:line below refers to a synthesized single-entry board, not the real board\n' >&2 || true
    printf '%s\n' "$SL_ERR" >&2 || true
    printf '%s:%s: would be rejected by the hand-off lint — refusing to move a malformed line into ## Done\n' "$BOARD" "$A_START" >&2 || true
    exit 1
    ;;
  *)
    # Rows (ii)/(iii): the fail-closed floor. An unusable checker — it was
    # just handed a file this script created, so "cannot read it" is an
    # environment failure, not a board defect — is NEVER guessed into row
    # (i)'s board-defect message, whatever its exit status turned out to be.
    die "cannot verify the Active line (check-handoff.sh exited $SL_RC)"
    ;;
esac

{
  printf '%s\n' "$DONE_MAIN"
  printf '%s\n' "$CLOSURE"
  if [ "$A_END" -gt "$A_START" ]; then
    sed -n "$((A_START + 1)),${A_END}p" "$BOARD"
  fi
} > "$ENTRY_FILE"

# --- pass 2: rewrite (Active entry removed, Done entry inserted at top) --------
awk -v a_start="$A_START" -v a_end="$A_END" -v entry_file="$ENTRY_FILE" '
  function emit_entry(   l) {
    while ((getline l < entry_file) > 0) print l
    close(entry_file)
  }
  NR >= a_start && NR <= a_end { next }        # drop the Active entry
  pending && !inserted {
    # First line after the ## Done heading: keep the conventional blank line
    # between the heading and the first entry, then place the new entry on top.
    if ($0 ~ /^[[:space:]]*$/) { print ""; emit_entry(); print ""; inserted=1; pending=0; next }
    print ""; emit_entry(); print ""; inserted=1; pending=0
    # fall through: current line still needs printing
  }
  /^## Done/ && !inserted { print; pending=1; next }
  { print }
  END { if (pending && !inserted) { print ""; emit_entry() } }
' "$BOARD" > "$TMP_BOARD"

# --- fail-closed gate: the rewritten board must still pass the hand-off lint ---
# D6 (T-1016): capture+print the checker's stderr before refusing (exit 1 and
# the no-write guarantee are unchanged). $HANDOFF_LINT and its screen sit
# above, ahead of the FIRST check-handoff.sh invocation (the source-line
# gate) — this is the second invocation and is covered by that same screen.
if ! bash "$HANDOFF_LINT" "$TMP_BOARD" >/dev/null 2>"$GATE_ERR"; then
  cat "$GATE_ERR" >&2 || true
  fail "rewritten board would fail check-handoff.sh — board left untouched"
fi
# mktemp creates 0600 files; keep the board's own permissions by copying the
# content instead of mv-ing the temp file over it.
cat "$TMP_BOARD" > "$BOARD"

printf 'close-out: %s moved to ## Done in %s\n' "$TASK" "$BOARD"

# Confidence-wording reminder (retro 2026-07-19, Lesson candidate 4): the --note
# summary must not upgrade the certainty of the primary hand-offs it summarizes.
printf 'close-out: reminder: keep the --note wording at the confidence level of the primary QA/Codex hand-offs (e.g. keep "environmentally-unverified" as is); if you claim stronger certainty, cite the extra evidence and record it on the board entry.\n'

# --- issue-close procedure (stdout only — this script never calls gh) ----------
if [ -n "$ISSUE" ]; then
  printf '\nNext step — close the GitHub issue (develop merges do NOT auto-close):\n'
  printf '  gh issue close %s --comment "Closed via close-out %s' "$ISSUE" "$TASK"
  if [ -n "$PR" ]; then printf ' (PR #%s merged to develop)' "$PR"; fi
  printf '"\n'
  printf '  (or via GitHub MCP: issue_write method=update issue_number=%s state=closed state_reason=completed)\n' "$ISSUE"
fi

# --- best-effort telemetry (never fails the close-out) -------------------------
bash "$SCRIPT_DIR/log-run.sh" close-out \
  --run-id "co-${DATE}-${TASK}" --seq 1 --span close-out --phase close-out \
  --iteration 0 --attempt 1 --status success >/dev/null 2>&1 || true

# --- best-effort project_status regeneration -----------------------------------
if ! bash "$SCRIPT_DIR/gen-project-status.sh" >/dev/null 2>&1; then
  printf 'close-out: note: project_status generated block not refreshed (file or markers absent) — see gen-project-status.sh\n' >&2
fi

exit 0
