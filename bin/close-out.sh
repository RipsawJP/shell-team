#!/usr/bin/env bash
# close-out.sh — one-command post-merge close-out for a board task (T-038).
#
# Does, in order:
#   1. Moves the task's top-level line (plus its contiguous sub-bullets) from
#      `## Active` to the TOP of `## Done` on the resolved board, rewriting the
#      status flag to `READY_FOR_MERGE`. The moved line keeps the hand-off
#      grammar of check-handoff.sh's LINE_RE (flag backticks directly followed
#      by ` — spec:`, NO parenthetical after the flag — the T-030 rework
#      lesson); the closure provenance (date / PR / issue) goes into a new
#      sub-bullet instead of the title line.
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
# Exit: 0 = board updated; 1 = task not in Active (missing or already Done) or
#       board shape error; 2 = usage / validation / resolver error. On any
#       non-zero exit the board file is byte-untouched.

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
      sed -n '2,40p' "$script_path" | sed 's/^# \{0,1\}//'
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
#   active_start/end — 1-based line range of the task's Active entry
#                      (top-level line + contiguous sub-bullets)
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
      if ($0 ~ /^[[:space:]]+-/) { a_end=NR; next }
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

# --- build the Done entry ------------------------------------------------------
MAIN_LINE="$(sed -n "${A_START}p" "$BOARD")"
# Rewrite `— \`<FLAG>\` — spec:` to READY_FOR_MERGE, keeping everything else.
# The greedy prefix group anchors on the LAST ` — \`…\` — spec: ` separator, so
# backticked tokens inside the title cannot be mistaken for the flag (same
# disambiguation as check-handoff.sh's FLAG_RE).
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
trap 'rm -f "$ENTRY_FILE" "$TMP_BOARD"' EXIT

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
if ! bash "$SCRIPT_DIR/check-handoff.sh" "$TMP_BOARD" >/dev/null 2>&1; then
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
