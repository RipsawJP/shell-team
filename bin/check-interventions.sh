#!/usr/bin/env bash
# check-interventions.sh — verify a per-task intervention-capture file's
# structural schema (T-1002; .shell-team/specs/T-1002-intervention-capture-channel.md).
#
# Issue #37 names a gap the retro has no channel for: a human interrupts,
# corrects, or stops the work (trigger 1); a measurement contradicts a stated
# assumption (trigger 3); work is abandoned, deferred, or reverted (trigger 5).
# `<base>/interventions/<task-id>.md` (or `no-task.md` for work outside a
# board task) is the durable record of those moments, written by the
# orchestrator — the one participant that can see them. This checker is the
# structural half of that discipline: it verifies the FILE'S GRAMMAR only,
# never the truth of its content.
#
#   1. usage       — a malformed invocation (unknown flag, missing/extra
#                    argument, a `--task` value with no argument, an
#                    explicitly EMPTY `--task` value (`--task ""` / `--task=`),
#                    or a REPEATED `--task` flag), or a positional argument
#                    that is not an existing, readable REGULAR file (`-f` +
#                    `-r`; directory/FIFO/unreadable all classify here).
#                    Exit 2 (`usage`).
#   2. structural  — the file carries EXACTLY ONE task-id-scoped marker pair
#        <!-- BEGIN interventions: <id> --> ... <!-- END interventions: <id> -->
#      BEGIN and END are matched the SAME WAY — a generic any-id regex,
#      EXACTLY ONE occurrence of each required — never a substring search, and
#      never a literal string derived from the other marker's own capture (a
#      well-formed END marker for a DIFFERENT id trailing after the true END
#      line is invisible to a derived-literal compare, since it is simply a
#      different string; T-1002 rework1 fix). Only once BEGIN and END are each
#      confirmed unique is the END marker's own captured id compared against
#      the BEGIN marker's own captured id — a mismatch is `structural`, same as
#      an absent/duplicated/reversed pair. The id is DERIVED from each
#      marker's own capture and is either `T-<digits>` or the reserved literal
#      `no-task` (the id of the taskless file); anything else is not
#      recognized as a marker at all. Absent / duplicated / reversed /
#      BEGIN-END id mismatch => exit 2 (`structural`). When `--task <id>` is
#      given, a BEGIN id that differs from it is ALSO `structural` (exit 2) —
#      this closes the wrong-file hazard a flagless invocation cannot see (a
#      file copied from another task has a valid marker pair, just the wrong
#      one).
#   3. schema      — the region strictly BETWEEN the marker lines (marker
#      lines themselves excluded) must satisfy EXACTLY ONE of:
#        (a) the zero-entry sentinel line `no interventions occurred` is the
#            ONLY non-blank line in the region; or
#        (b) one or more well-formed entries — each a top-level
#            `- intervention: <class>` line (a **closed seven-member
#            enum** — see below) followed (before the next `- intervention:`
#            line / the sentinel / EOF-of-region) by EXACTLY ONE indented
#            `date:`, EXACTLY ONE indented `summary:` and EXACTLY ONE
#            indented `effect:` line, each with a non-empty value. Field
#            ORDER is not enforced. `date:` must additionally be a valid
#            date format — with NO sentinel line and no other non-blank
#            lines anywhere in the region. NOTE:
#            the date is validated for FORMAT only (YYYY-MM-DD); calendar validity is deliberately not checked
#      Any violation (an unrecognized class token, an incomplete/malformed
#      entry, a wrapped field value on a second unindented line, the
#      sentinel coexisting with an entry, a region with neither a sentinel
#      nor any entry, or any unrecognized non-blank line) => exit 1
#      (`schema`).
#   4. all pass => exit 0 (`conformant`).
#
# Recognized intervention classes
# (templates/prompt-blocks/interventions-classes.md — the single canonical
# source; kept in sync here by bin/check-prompt-sync.sh, never copied by hand):
#   - intervention: human-interrupt
#   - intervention: human-correction
#   - intervention: human-stop
#   - intervention: assumption-contradicted
#   - intervention: work-deferred
#   - intervention: work-abandoned
#   - intervention: unclassified
# A routine gate response — a plain GO, an approval, or an answer to a question you asked — is not an intervention and gets no entry.
#
# Entry template: `<!-- BEGIN interventions: <id> -->` opens the region and `<!-- END interventions: <id> -->` closes it with the same `<id>`; each entry is a `- intervention: <class>` line followed by indented `date: <YYYY-MM-DD>`, `summary: <one line>` and `effect: <one line>` fields.
# If the file currently holds the sentinel `no interventions occurred`, the first real entry REPLACES that line rather than being appended after it — the sentinel and an entry cannot coexist in either order (AC5).
#
# Every append to an interventions file is committed immediately, as its own commit, at the moment of recording — at every recording point, not only at the Implement-to-Validate seam.
#
# This checker judges STRUCTURE ONLY — it never judges whether an
# intervention really happened, whether a class token was the right choice,
# or whether the stated effect is the real effect. A file carrying the
# sentinel while ten interventions happened is CONFORMANT here (exit 0) by
# design: that is the same trust boundary bin/check-provenance.sh declares —
# a discipline aid for a trusted, committed, reviewed artifact, not a
# security boundary against an adversarial author.
#
# Normalization is a per-line CR strip only (CRLF tolerance) — no
# trailing-whitespace strip, no leading/trailing blank-line trim, since
# nothing here is hashed.
#
# Marker matching is an EXACT full-line compare (never a substring/grep -F
# search): a marker literal, another field's keyword, a class token, or the
# sentinel string quoted mid-sentence inside an entry's own `summary:`/
# `effect:` VALUE is never miscounted as a second structural occurrence.
# Field matching is likewise anchored at line-start (`^- intervention:` /
# `^[[:space:]]+date:` / `^[[:space:]]+summary:` / `^[[:space:]]+effect:`),
# so a field VALUE that happens to quote another field's keyword or the
# sentinel string is never miscounted as a second structural occurrence.
#
# Usage:
#   check-interventions.sh [--task <T-NNN|no-task>] [--] <interventions-file.md>
#
# `--task` follows bin/check-design-note.sh's precedent: without it the
# checker is self-contained (the id comes only from the file's own BEGIN
# marker, like bin/check-provenance.sh); with it, a BEGIN id that disagrees
# is rejected as `structural` rather than silently accepted. An explicitly
# EMPTY `--task` value (`--task ""` / `--task=`) and a REPEATED `--task` flag
# are each rejected as `usage` (exit 2) rather than silently defeating this
# wrong-file protection (T-1002 rework1 fix) — an empty value used to leave
# the flag indistinguishable from never having been given at all, and a
# repeated flag used to let the LAST value silently win with no
# duplicate-detection.
#
# Exit: 0 = conformant; 1 = schema violation (unrecognized class / malformed
#       or incomplete entry / malformed date / wrapped field value / a
#       sentinel-less empty region / a sentinel/entry coexistence); 2 =
#       usage / structural error (bad args, an empty or repeated `--task`,
#       unreadable file, missing/duplicated/reversed/mismatched markers, a
#       `--task` disagreement).

set -euo pipefail

# --- classified failure helpers ---------------------------------------------
# Every rejection path prints a classification token to stderr so a caller
# (or this checker's own fixture suite) can distinguish usage/structural
# errors from a genuine schema violation without parsing prose. Defined
# FIRST, before anything else (including the symlink-resolution bootstrap
# directly below) — mirrors bin/check-provenance.sh's discipline.
die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-interventions: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
fail_schema() {  # $1 = message; exit 1
  printf 'check-interventions: schema: %s\n' "$1" >&2 || true
  exit 1
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported from bin/log-run.sh / bin/check-provenance.sh (2026-07-14 lesson:
# reuse the proven resolver instead of hand-rolling one). This checker has no
# sibling script to call and never reads git/board state; SELF is used only
# to source --help's text from this file's own header comment. Every
# external command in this bootstrap (readlink / cd / pwd / basename) is
# guarded — a failure here falls closed as a classified usage(2) error
# instead of a bare, untokened `set -e` exit.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || fail_usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd)" \
        || fail_usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || fail_usage "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  sed -n '2,95p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing (single positional + optional --task; -- ends options) -
TASK=""
TASK_GIVEN=0
FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --task)
      [ "$#" -ge 2 ] || fail_usage "--task requires a value"
      [ "$TASK_GIVEN" -eq 0 ] || fail_usage "--task given more than once"
      [ -n "$2" ] || fail_usage "--task requires a non-empty value"
      TASK="$2"; TASK_GIVEN=1; shift 2 ;;
    --task=*)
      [ "$TASK_GIVEN" -eq 0 ] || fail_usage "--task given more than once"
      TASK="${1#--task=}"
      [ -n "$TASK" ] || fail_usage "--task requires a non-empty value"
      TASK_GIVEN=1; shift ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  break ;;
  esac
done

if [ "$#" -ge 1 ]; then FILE="$1"; shift; fi
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$FILE" ] || fail_usage "missing required <interventions-file.md> (usage: check-interventions.sh [--task <id>] [--] <interventions-file.md>)"
# Type + readability validation happens HERE, before the file is ever read
# line-by-line below (`-f` checked before `-r` so a directory is classified
# by its TYPE, not its permissions).
[ -f "$FILE" ] || fail_usage "interventions file path is not a regular file (directories/FIFOs/etc. are rejected): $FILE"
[ -r "$FILE" ] || fail_usage "cannot read interventions file: $FILE"

# --- load the file into a 1-indexed array, CR-stripped per line ------------
declare -a LINES
NLINES=0
while IFS= read -r raw || [ -n "$raw" ]; do
  NLINES=$((NLINES + 1))
  LINES[NLINES]="${raw%$'\r'}"
done < "$FILE"

# --- 1. marker structural checks: derive the id from the BEGIN marker ------
# The id slot accepts either T-<digits> or the reserved literal `no-task`
# (DP-2) — anything else is not recognized as a marker at all, so an
# unrecognized id falls straight through to "no BEGIN marker found" below.
# shellcheck disable=SC2016
BEGIN_ANY_RE='^<!-- BEGIN interventions: (T-[0-9]+|no-task) -->$'

begin_count=0
begin_ln=0
begin_id=""
i=1
while [ "$i" -le "$NLINES" ]; do
  line="${LINES[$i]}"
  if [[ "$line" =~ $BEGIN_ANY_RE ]]; then
    begin_count=$((begin_count + 1))
    begin_ln="$i"
    begin_id="${BASH_REMATCH[1]}"
  fi
  i=$((i + 1))
done
[ "$begin_count" -eq 1 ] \
  || fail_structural "expected exactly one '<!-- BEGIN interventions: <id> -->' marker (id = T-NNN or the reserved literal no-task; found $begin_count) in $FILE"

# END is matched the SAME WAY as BEGIN — a generic any-id regex, requiring
# EXACTLY ONE occurrence — and ONLY THEN is its own captured id compared
# against the id captured from the (now unique) BEGIN marker. This closes an
# asymmetry the previous literal-derived-from-begin_id compare left open: a
# well-formed END marker for a DIFFERENT id trailing after the true END line
# is simply a different string from a literal derived from begin_id, so it
# was never counted at all (T-1002 rework1, Codex round1 Major 2 fix —
# reproduced: BEGIN T-900 / END T-900 / a trailing extraneous
# "<!-- END interventions: T-901 -->" used to pass as conformant).
# shellcheck disable=SC2016
END_ANY_RE='^<!-- END interventions: (T-[0-9]+|no-task) -->$'
end_count=0
end_ln=0
end_id=""
i=1
while [ "$i" -le "$NLINES" ]; do
  line="${LINES[$i]}"
  if [[ "$line" =~ $END_ANY_RE ]]; then
    end_count=$((end_count + 1))
    end_ln="$i"
    end_id="${BASH_REMATCH[1]}"
  fi
  i=$((i + 1))
done
[ "$end_count" -eq 1 ] \
  || fail_structural "expected exactly one '<!-- END interventions: <id> -->' marker (id = T-NNN or the reserved literal no-task; found $end_count) in $FILE"
[ "$end_id" = "$begin_id" ] \
  || fail_structural "BEGIN marker id ($begin_id) does not match END marker id ($end_id) in $FILE"

[ "$begin_ln" -lt "$end_ln" ] \
  || fail_structural "BEGIN interventions marker (line $begin_ln) must precede its END marker (line $end_ln) in $FILE"

# --task closes the wrong-file hazard a flagless invocation cannot see: a
# file copied from another task has a VALID marker pair, just the wrong one.
if [ -n "$TASK" ]; then
  [ "$begin_id" = "$TASK" ] \
    || fail_structural "--task $TASK does not match the file's BEGIN marker id ($begin_id) in $FILE — wrong file for this task?"
fi

# --- 2. content schema: the region strictly between the marker lines -------
# shellcheck disable=SC2016
ENTRY_RE='^- intervention:(.*)$'
# shellcheck disable=SC2016
DATE_RE='^[[:space:]]+date:(.*)$'
# shellcheck disable=SC2016
SUMMARY_RE='^[[:space:]]+summary:(.*)$'
# shellcheck disable=SC2016
EFFECT_RE='^[[:space:]]+effect:(.*)$'
SENTINEL_LINE='no interventions occurred'
DATE_FORMAT_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

# trim: strip leading+trailing whitespace, portable bash (no external
# command — a pure parameter-expansion idiom, safe under bash 3.2).
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_recognized_class() {
  case "$1" in
    human-interrupt|human-correction|human-stop|assumption-contradicted|work-deferred|work-abandoned|unclassified) return 0 ;;
    *) return 1 ;;
  esac
}

entry_count=0
sentinel_count=0
violation=0
in_entry=0
date_count_cur=0
summary_count_cur=0
effect_count_cur=0

# finalize_entry: called whenever an entry's scope closes (a new
# `- intervention:` line begins, a sentinel line is encountered, or the
# region ends) — validates the JUST-CLOSED entry carries exactly one date,
# exactly one summary and exactly one effect field.
finalize_entry() {
  if [ "$in_entry" -eq 1 ]; then
    if [ "$date_count_cur" -ne 1 ] || [ "$summary_count_cur" -ne 1 ] || [ "$effect_count_cur" -ne 1 ]; then
      violation=1
    fi
    in_entry=0
  fi
}

idx=$((begin_ln + 1))
while [ "$idx" -lt "$end_ln" ]; do
  line="${LINES[$idx]}"
  idx=$((idx + 1))

  # Blank lines are ignored everywhere in the region.
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    continue
  fi

  if [ "$line" = "$SENTINEL_LINE" ]; then
    finalize_entry
    # The sentinel and any entry are mutually exclusive within one
    # interventions file — whichever type appears SECOND (in either order,
    # or a repeated sentinel) is caught here.
    if [ "$entry_count" -gt 0 ] || [ "$sentinel_count" -gt 0 ]; then
      violation=1
    fi
    sentinel_count=$((sentinel_count + 1))
    continue
  fi

  if [[ "$line" =~ $ENTRY_RE ]]; then
    finalize_entry
    if [ "$sentinel_count" -gt 0 ]; then
      violation=1
    fi
    class="$(trim "${BASH_REMATCH[1]}")"
    if ! is_recognized_class "$class"; then
      violation=1
    fi
    entry_count=$((entry_count + 1))
    in_entry=1
    date_count_cur=0
    summary_count_cur=0
    effect_count_cur=0
    continue
  fi

  if [[ "$line" =~ $DATE_RE ]]; then
    if [ "$in_entry" -ne 1 ]; then
      violation=1
    else
      text="$(trim "${BASH_REMATCH[1]}")"
      date_count_cur=$((date_count_cur + 1))
      if [ "$date_count_cur" -gt 1 ] || [ -z "$text" ]; then
        violation=1
      elif ! [[ "$text" =~ $DATE_FORMAT_RE ]]; then
        violation=1
      fi
    fi
    continue
  fi

  if [[ "$line" =~ $SUMMARY_RE ]]; then
    if [ "$in_entry" -ne 1 ]; then
      violation=1
    else
      text="$(trim "${BASH_REMATCH[1]}")"
      summary_count_cur=$((summary_count_cur + 1))
      if [ "$summary_count_cur" -gt 1 ] || [ -z "$text" ]; then
        violation=1
      fi
    fi
    continue
  fi

  if [[ "$line" =~ $EFFECT_RE ]]; then
    if [ "$in_entry" -ne 1 ]; then
      violation=1
    else
      text="$(trim "${BASH_REMATCH[1]}")"
      effect_count_cur=$((effect_count_cur + 1))
      if [ "$effect_count_cur" -gt 1 ] || [ -z "$text" ]; then
        violation=1
      fi
    fi
    continue
  fi

  # Any other non-blank line inside the marker region is unrecognized —
  # neither a sentinel, a top-level entry anchor, nor an indented
  # date/summary/effect continuation — and fails closed. This also catches
  # an indented `- intervention:` (not a top-level anchor) and a
  # zero-indent `date:`/`summary:`/`effect:` (not a valid field anchor).
  violation=1
done
finalize_entry

# --- 3. final verdict: EXACTLY ONE of "sentinel-only" or "entries-only" ----
conformant=0
if [ "$violation" -eq 0 ] && [ "$sentinel_count" -eq 1 ] && [ "$entry_count" -eq 0 ]; then
  conformant=1
elif [ "$violation" -eq 0 ] && [ "$sentinel_count" -eq 0 ] && [ "$entry_count" -ge 1 ]; then
  conformant=1
fi

if [ "$conformant" -eq 0 ]; then
  fail_schema "interventions file does not conform to schema (entry_count=$entry_count sentinel_count=$sentinel_count violation=$violation) in $FILE — expected either the sentinel 'no interventions occurred' as the ONLY non-blank line, or one or more well-formed (intervention/date/summary/effect) entries with no sentinel"
fi

# Guard the success-path print against SIGPIPE (e.g. piped through `| head`)
# so a closed downstream pipe can never turn an already-decided `conformant`
# outcome into an unclassified non-zero exit — the exit code below is
# unconditionally 0 regardless of this printf's result.
printf 'check-interventions: conformant: %s (%s entries, %s sentinel)\n' "$FILE" "$entry_count" "$sentinel_count" || true
exit 0
