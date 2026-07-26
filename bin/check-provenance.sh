#!/usr/bin/env bash
# check-provenance.sh — verify a per-task decision provenance file's structural
# schema (T-074, v0.3.0 Phase A Seam A; docs/specs/T-074-decision-provenance-core.md).
#
# Design note `v0.3.0-oversight-model-evolution.md` §6.1 point 3 establishes a
# decision provenance ledger: non-trivial decisions made while implementing a
# task are recorded as (decision / reason / grounding) triples, so a decision
# with no citation becomes a machine-detectable drift risk. This checker is
# the structural half of that discipline — it verifies the FILE'S GRAMMAR
# only, never the truth of its content:
#
#   1. usage       — exactly one positional argument, naming an existing
#                    REGULAR file (`-f`) that is readable (`-r`). Missing/
#                    extra argument, directory/FIFO/unreadable => exit 2
#                    (`usage`).
#   2. structural  — the file carries EXACTLY ONE task-id-scoped marker pair
#        <!-- BEGIN provenance: T-NNN --> ... <!-- END provenance: T-NNN -->
#      (BEGIN strictly before END, matched via EXACT full-line comparison —
#      never a substring search). The task-id is DERIVED from the BEGIN
#      marker's own capture (no external board/spec cross-reference — a
#      provenance file is self-contained). Absent / duplicated / reversed /
#      BEGIN-END task-id mismatch => exit 2 (`structural`).
#   3. schema      — the region strictly BETWEEN the marker lines (marker
#      lines themselves excluded) must satisfy EXACTLY ONE of:
#        (a) the zero-decision sentinel line `no non-trivial decisions` is
#            the ONLY non-blank line in the region; or
#        (b) one or more well-formed decision entries — each a top-level
#            `- decision: <non-empty text>` line followed (before the next
#            `- decision:` line / sentinel line / EOF-of-region) by EXACTLY
#            ONE indented `reason: <non-empty text>` line and EXACTLY ONE
#            indented `grounding: <non-empty text>` line — appear, with NO
#            sentinel line and no other non-blank lines anywhere in the
#            region.
#      Any violation (incomplete/malformed triple, a decision with no
#      grounding declaration at all, the sentinel coexisting with a decision
#      entry, a region with neither a sentinel nor any decision entry, or any
#      unrecognized non-blank line) => exit 1 (`schema`).
#   4. all pass => exit 0 (`conformant`).
#
# This checker judges STRUCTURE ONLY (field presence + grounding declaration
# presence) — it never judges whether a decision was truly non-trivial,
# whether a reason is a good reason, or whether a grounding citation is real
# or accurate. An explicit `grounding: none (ungrounded)` is CONFORMANT here
# (exit 0) by design: flagging an ungrounded decision as a concern is S4
# (drift/alignment evaluator)'s job, never this checker's (spec DP2 / "意味
#判定は一切しない" scope boundary, the same trust boundary as
# bin/check-intent.sh's DP4 and bin/check-acs.sh's TRUST BOUNDARY: this is a
# discipline aid for trusted, committed, reviewed artifacts, not a security
# boundary against an adversarial author).
#
# Normalization is intentionally SIMPLER than bin/check-intent.sh's: this
# checker never hashes anything (no frozen-basis comparison), so only a
# per-line CR strip is applied (CRLF tolerance) — no trailing-whitespace
# strip, no leading/trailing blank-line trim (spec DP2).
#
# Marker matching is an EXACT full-line compare (never a substring/grep -F
# search): a marker literal quoted mid-sentence inside a decision's own
# `reason:`/`grounding:` VALUE (this repo's own dogfood provenance file,
# tasks/provenance/T-074.md, does exactly this — it records the decision
# that fixed this very anchoring rule) is never miscounted as a real marker
# occurrence. Field matching is likewise anchored at line-start
# (`^- decision:` / `^[[:space:]]+reason:` / `^[[:space:]]+grounding:`), so a
# field VALUE that happens to quote another field's keyword or the sentinel
# string is never miscounted as a second structural occurrence (spec Input
# space class 8 — self-referential prose).
#
# Usage:
#   check-provenance.sh [--] <provenance-file.md>
#
# Exit: 0 = conformant; 1 = schema violation (malformed/incomplete triple, an
#       ungrounded-without-declaration decision, a sentinel-less empty
#       region, or a sentinel/decision-entry coexistence); 2 = usage /
#       structural error (bad args, unreadable file, missing/duplicated/
#       reversed/mismatched markers).

set -euo pipefail

# --- classified failure helpers ---------------------------------------------
# Every rejection path prints a classification token to stderr so a caller
# (or this checker's own fixture suite) can distinguish usage/structural
# errors from a genuine schema violation without parsing prose. Defined
# FIRST, before anything else (including the symlink-resolution bootstrap
# directly below) — every external-command / pipeline / read-loop failure in
# this script, from the very first line onward, must have a classified exit
# path available (ported discipline: T-071 rework2 "fail-closed の全数
# inventory 要求").
die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-provenance: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
fail_schema() {  # $1 = message; exit 1
  printf 'check-provenance: schema: %s\n' "$1" >&2 || true
  exit 1
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported from bin/log-run.sh L51-59 / bin/check-intent.sh (2026-07-14 lesson:
# reuse the proven resolver instead of hand-rolling one). This checker has no
# sibling script to call and never reads git/board state; SELF is used only
# to source --help's text from this file's own header comment. Every
# external command in this bootstrap (readlink / cd / pwd / basename) is
# guarded — a failure here (a broken symlink chain, or an inaccessible
# directory) falls closed as a classified usage(2) error instead of a bare,
# untokened `set -e` exit.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      # `dirname` and `cd ... && pwd` are guarded INDEPENDENTLY (Codex round1
      # rework1 Major #1, tasks/reviews/T-074.md): a single
      # `"$(cd "$(dirname "$script_path")" && pwd)" || fail_usage ...` only
      # observes the OUTER `cd && pwd` pipeline's exit status — if `dirname`
      # itself fails (e.g. a PATH with no `dirname` binary at all), bash's
      # command substitution yields an EMPTY string, and `cd ""` silently
      # succeeds as `cd .` (the current directory), so the `||` never fires
      # and SCRIPT_DIR/link_dir quietly become `$PWD` instead of failing
      # closed. Splitting the two substitutions gives `dirname`'s own
      # failure its own classified exit path. NOTE: bin/check-intent.sh
      # carries this exact same (unsplit) pattern — it is NOT touched here
      # (S2 frozen-intent mechanism is off-limits, spec AC13); a cross-cutting
      # hardening of that script is out of this task's scope.
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
  sed -n '2,80p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing (single positional; -- ends option parsing) ----------
FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  break ;;
  esac
done

if [ "$#" -ge 1 ]; then FILE="$1"; shift; fi
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$FILE" ] || fail_usage "missing required <provenance-file.md> (usage: check-provenance.sh [--] <provenance-file.md>)"
# Type + readability validation happens HERE, before the file is ever read
# line-by-line below (`-f` checked before `-r` so a directory is classified
# by its TYPE, not its permissions) — a directory/FIFO argument is rejected
# as usage(2) here, before any read loop could ever spin on it (T-071
# rework2 "引数の型・健全性検証" precedent; no read loop below can hang on a
# directory since it is never reached for one).
[ -f "$FILE" ] || fail_usage "provenance file path is not a regular file (directories/FIFOs/etc. are rejected): $FILE"
[ -r "$FILE" ] || fail_usage "cannot read provenance file: $FILE"

# --- load the file into a 1-indexed array, CR-stripped per line ------------
# (spec DP2: normalization for THIS checker is a per-line CR strip only — no
# trailing-whitespace strip, no blank-line trim, since nothing is hashed.)
# `-f`+`-r` were validated immediately above, before this loop is ever
# reached, so a directory-read failure here is structurally impossible for
# any real invocation; no dead "distinguish EOF from a read error" branch is
# added (mirrors bin/check-intent.sh rework4-C's removal of that same
# unreachable branch).
declare -a LINES
NLINES=0
while IFS= read -r raw || [ -n "$raw" ]; do
  NLINES=$((NLINES + 1))
  LINES[NLINES]="${raw%$'\r'}"
done < "$FILE"

# --- 1. marker structural checks: derive task-id from the BEGIN marker -----
# shellcheck disable=SC2016
BEGIN_ANY_RE='^<!-- BEGIN provenance: (T-[0-9]+) -->$'

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
  || fail_structural "expected exactly one '<!-- BEGIN provenance: T-NNN -->' marker (found $begin_count) in $FILE"

# END is matched by an EXACT full-line literal compare against the task-id
# captured from the (now unique) BEGIN marker — this simultaneously enforces
# "exactly one END" AND "same task-id as BEGIN": a mismatched or missing
# same-id END both surface as end_count!=1 below.
END_MARK="<!-- END provenance: ${begin_id} -->"
end_count=0
end_ln=0
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${LINES[$i]}" = "$END_MARK" ]; then
    end_count=$((end_count + 1))
    end_ln="$i"
  fi
  i=$((i + 1))
done
[ "$end_count" -eq 1 ] \
  || fail_structural "expected exactly one '$END_MARK' marker matching the BEGIN task-id (found $end_count) in $FILE"

[ "$begin_ln" -lt "$end_ln" ] \
  || fail_structural "BEGIN provenance marker (line $begin_ln) must precede its END marker (line $end_ln) in $FILE"

# --- 2. content schema: the region strictly between the marker lines -------
# shellcheck disable=SC2016
DECISION_RE='^- decision:(.*)$'
# shellcheck disable=SC2016
REASON_RE='^[[:space:]]+reason:(.*)$'
# shellcheck disable=SC2016
GROUNDING_RE='^[[:space:]]+grounding:(.*)$'
SENTINEL_LINE='no non-trivial decisions'

# trim: strip leading+trailing whitespace, portable bash (no external
# command — a pure parameter-expansion idiom, safe under bash 3.2).
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

entry_count=0
sentinel_count=0
violation=0
in_entry=0
reason_count_cur=0
grounding_count_cur=0

# finalize_entry: called whenever a decision entry's scope closes (a new
# `- decision:` line begins, a sentinel line is encountered, or the region
# ends) — validates the JUST-CLOSED entry carries exactly one reason and
# exactly one grounding field (spec's core grounding discipline: a decision
# with NO grounding declaration at all is a schema violation, never silently
# accepted).
finalize_entry() {
  if [ "$in_entry" -eq 1 ]; then
    if [ "$reason_count_cur" -ne 1 ] || [ "$grounding_count_cur" -ne 1 ]; then
      violation=1
    fi
    in_entry=0
  fi
}

idx=$((begin_ln + 1))
while [ "$idx" -lt "$end_ln" ]; do
  line="${LINES[$idx]}"
  idx=$((idx + 1))

  # Blank lines are ignored everywhere in the region (spec DP2: "空行は無視").
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    continue
  fi

  if [ "$line" = "$SENTINEL_LINE" ]; then
    finalize_entry
    # DP3: the sentinel and any decision entry are mutually exclusive within
    # one provenance file — whichever type appears SECOND (in either order,
    # or a repeated sentinel) is caught here.
    if [ "$entry_count" -gt 0 ] || [ "$sentinel_count" -gt 0 ]; then
      violation=1
    fi
    sentinel_count=$((sentinel_count + 1))
    continue
  fi

  if [[ "$line" =~ $DECISION_RE ]]; then
    finalize_entry
    if [ "$sentinel_count" -gt 0 ]; then
      violation=1
    fi
    text="$(trim "${BASH_REMATCH[1]}")"
    if [ -z "$text" ]; then
      violation=1
    fi
    entry_count=$((entry_count + 1))
    in_entry=1
    reason_count_cur=0
    grounding_count_cur=0
    continue
  fi

  if [[ "$line" =~ $REASON_RE ]]; then
    if [ "$in_entry" -ne 1 ]; then
      violation=1
    else
      text="$(trim "${BASH_REMATCH[1]}")"
      reason_count_cur=$((reason_count_cur + 1))
      if [ "$reason_count_cur" -gt 1 ] || [ -z "$text" ]; then
        violation=1
      fi
    fi
    continue
  fi

  if [[ "$line" =~ $GROUNDING_RE ]]; then
    if [ "$in_entry" -ne 1 ]; then
      violation=1
    else
      text="$(trim "${BASH_REMATCH[1]}")"
      grounding_count_cur=$((grounding_count_cur + 1))
      if [ "$grounding_count_cur" -gt 1 ] || [ -z "$text" ]; then
        violation=1
      fi
    fi
    continue
  fi

  # Any other non-blank line inside the marker region is unrecognized —
  # neither a sentinel, a top-level decision anchor, nor an indented
  # reason/grounding continuation — and fails closed.
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
  fail_schema "provenance file does not conform to schema (decision_count=$entry_count sentinel_count=$sentinel_count violation=$violation) in $FILE — expected either the sentinel 'no non-trivial decisions' as the ONLY non-blank line, or one or more well-formed (decision/reason/grounding) triples with no sentinel"
fi

# Guard the success-path print against SIGPIPE (e.g. piped through `| head`)
# so a closed downstream pipe can never turn an already-decided `conformant`
# outcome into an unclassified non-zero exit — the exit code below is
# unconditionally 0 regardless of this printf's result.
printf 'check-provenance: conformant: %s (%s decision entries, %s sentinel)\n' "$FILE" "$entry_count" "$sentinel_count" || true
exit 0
