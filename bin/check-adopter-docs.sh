#!/usr/bin/env bash
# check-adopter-docs.sh — freeze-time gate for the "user-visible capability
# needs adopter docs, or an honest waiver" declaration a spec's frozen intent
# block must carry (T-1061; .shell-team/specs/T-1061-adopter-docs-gate.md;
# issue #244 requirement 4).
#
# A spec for a user-visible capability could always reach `READY_FOR_ARCH`
# with no adopter-facing-documentation acceptance criterion, and nothing
# anywhere noticed — the deliverable that realizes the release's value got
# deferred to a fast-follow, and the only thing standing between that and a
# release was whether the spec's author happened to remember
# (`agents/pm-spec.md`'s own self-check bullet is exactly that memory, with
# no consumer that refuses on it). This script is the consumer: it reads one
# spec file and refuses, mechanically, when the declaration is absent,
# malformed, or a `yes` declaration is undischarged. It never judges content —
# whether a named surface is REALLY adopter-facing is a matter for the
# reviewing gates and the human, never for this checker.
#
# Declaration grammar (templates/prompt-blocks/adopter-docs-declaration.md —
# the single canonical source; kept in sync here by bin/check-prompt-sync.sh,
# never copied by hand):
#   - user-visible: yes — <rationale>
#   - user-visible: no — <rationale>
# A `yes` declaration is discharged by an indented `- adopter-surface: <where the adopter-facing documentation lands>` line under an acceptance criterion, or a top-level `- adopter-docs-waiver: <why this user-visible capability has no adopter-docs surface>` line — never both, and never either one beside a `no`.
#
# The declaration line is written between the intent block's `BEGIN` marker
# and the `## Non-goals` heading (the Goal region) — a well-formed occurrence
# anywhere else in the file is `declaration-misplaced`, not `declaration-missing`,
# because "you put it in the wrong place" is a different repair from "you
# forgot it". An indented occurrence is not a declaration at all (it is
# invisible, exactly as if absent). A fenced occurrence of ANY line this
# script reads — the three grammar tokens and the intent-block markers alike —
# is likewise inert: the region is located by the UNFENCED marker pair alone,
# with no task-id derivation of this script's own (`bin/check-intent.sh`
# already owns that scoping). The fence tracker is a small CommonMark-aligned
# state machine (ported from `bin/check-board-headings.sh`'s
# `extract_ids_to_file`): a fence OPENER is a line whose leading indentation is
# 0-3 literal spaces followed by a run of 3+ backticks (its info string, if
# any, is not validated); once opened, the run length is recorded and every
# line up to and including a matching-or-longer-run CLOSER (0-3-space-indented,
# nothing but trailing whitespace after the run) is inert.
#
# Discharge-marker SCOPE (T-1061 round-1 rework, Codex Major #1): both markers
# are read only from INSIDE the frozen intent block (strictly between the
# BEGIN and END markers) — a well-formed marker sitting in mutable prose after
# END (a `## Notes for engineer` example, an `## Assumptions` aside) is
# invisible, exactly as if absent, because it is not part of what the freeze
# actually hashes. `- adopter-surface:` is read only when it is an indented
# continuation line immediately nested under a real, unindented
# `- [ ] **ACn**`-shaped bullet — "an acceptance criterion carries an indented
# ... line", never a floating indented line anywhere else in the block. Scope
# tracking is a small state machine mirroring this repo's own board-entry
# continuation canon (`bin/check-intent.sh`'s extract_task_records): an
# indented, non-blank line keeps the current AC scope open (and is checked for
# a surface match while that scope is open); a blank line is neutral and
# changes nothing; any other non-indented, non-blank line closes the current
# scope first and opens a new one only if that same line is itself an
# AC-bullet. `- adopter-docs-waiver:` needs no such nesting (the Goal's own
# words are "the spec carries a top-level ... line") — only the intent-block
# window applies to it. A fenced line participates in neither scope tracking
# nor matching (skipped outright), the same universal inertness every other
# element in this file already gets.
#
# Discharge-marker VALUE RETENTION (T-1061 round-1 rework, Codex Major #2):
# both `- adopter-surface:` and `- adopter-docs-waiver:` are legal to occur
# more than once in scope (this spec ships no duplicate-marker refusal token
# for either — multiple criteria may each carry their own surface, and this
# script never judges which one is "the real" documentation). Discharge is
# therefore "at least one IN-SCOPE occurrence carries a non-whitespace value",
# never "the first occurrence's value" — a value is read and trimmed AT EACH
# occurrence as the scan proceeds, so the verdict does not depend on which
# occurrence happens to come first in the file.
#
# Usage:
#   check-adopter-docs.sh [--] <spec.md>
#     Read <spec.md>'s frozen intent block for the declaration above. Exit 0
#     on a clean pass (silently — zero bytes on stdout AND stderr). A refusal
#     writes exactly one token, alone, to stderr and zero bytes to stdout.
#   check-adopter-docs.sh --help
#     Print this header and exit 0 (at least one byte on stdout).
#
# Exit codes and the CLOSED ten-token refusal set (every refusal is one
# token, alone, on stderr — never embedded in a longer message — with zero
# bytes on stdout; nothing outside this set is ever printed on a refusal):
#   usage (2)                 — a bad invocation: an unknown flag, a missing
#                                or extra positional argument.
#   spec-unreadable (2)       — the given path does not exist, is not a
#                                regular file, or is not readable (a
#                                directory, a FIFO, a dangling symlink, or an
#                                unreadable regular file all land here).
#   intent-block-missing (2)  — the unfenced marker pair
#                                `<!-- BEGIN intent-block: ... -->` /
#                                `<!-- END intent-block: ... -->` does not
#                                resolve to exactly one region, BEGIN strictly
#                                before END (zero, more than one, reversed, or
#                                a marker pair whose only occurrence sits
#                                inside a fenced code block all land here —
#                                this script's contract for anything it
#                                cannot resolve into exactly one region is
#                                exit 2, never a guess).
#   declaration-missing (1)   — zero unindented, unfenced occurrences of
#                                `- user-visible:` anywhere in the file (an
#                                indented or fenced-only occurrence counts as
#                                zero, by design).
#   declaration-duplicate (1) — two or more such occurrences, anywhere in the
#                                file.
#   declaration-malformed (1) — exactly one such occurrence, but its value is
#                                not exactly `yes` or `no`, its separator is
#                                absent, or its rationale is absent or
#                                whitespace-only.
#   declaration-misplaced (1) — exactly one well-formed occurrence, but it
#                                sits outside the Goal region (before the
#                                BEGIN marker, at or after the `## Non-goals`
#                                heading, or after the END marker).
#   obligation-undischarged (1) — a `yes` declaration with neither a
#                                non-empty `- adopter-surface:` value nor a
#                                non-empty `- adopter-docs-waiver:` reason
#                                (an all-whitespace surface value counts as
#                                undischarged, not as a separate refusal).
#   waiver-reason-empty (1)   — a `yes` declaration whose ONLY discharge
#                                marker is an `- adopter-docs-waiver:` line
#                                whose reason is absent or whitespace-only
#                                (distinct from obligation-undischarged: the
#                                marker exists, but says nothing).
#   marker-conflict (1)       — a `yes` declaration carrying both markers at
#                                once, or a `no` declaration carrying either
#                                marker at all.
#
# This script writes nothing anywhere, under any environment: no output-file
# flag, no environment variable, and nothing it reads is ever written to.

set -euo pipefail

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported (bootstrap shape) from bin/check-intent.sh / bin/check-interventions.sh
# (2026-07-14 lesson: reuse the proven symlink-safe resolver instead of
# hand-rolling one) — with one deliberate departure from that ported shape:
# every `pwd` below is `pwd -P` (physical, every symlink resolved), never the
# bare logical `pwd` the ported original used, matching the repo's own more
# recent convention (`bin/check-binding.sh`, `bin/resolve-executor.sh`): a
# plain `cd && pwd` only follows a symlink on the FINAL path component, so an
# ANCESTOR directory being a symlink (an adopter's `bin/` symlinked into the
# plugin's real `bin/`) survives untouched and this script's own directory
# could silently resolve inside the wrong tree. This script has no sibling
# script to call; SELF is used only to source --help's text from this file's
# own header comment.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || { printf 'usage\n' >&2 || true; exit 2; }
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || { printf 'usage\n' >&2 || true; exit 2; }
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || { printf 'usage\n' >&2 || true; exit 2; }
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || { printf 'usage\n' >&2 || true; exit 2; }
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || { printf 'usage\n' >&2 || true; exit 2; }
self_name="$(basename "$script_path")" \
  || { printf 'usage\n' >&2 || true; exit 2; }
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || { printf 'usage\n' >&2 || true; exit 2; }
}

# --- classified refusal helper -----------------------------------------------
# One bare token, alone, on stderr — never embedded in a longer message — so
# a caller (or this script's own fixture suite) can grep it with `grep -x`.
# `|| true` guards the write (T-096 convention): a closed-stderr caller must
# not turn the intended exit code into a bare errexit before `exit "$2"` runs.
refuse() {  # $1 = token (closed 10-token set); $2 = exit code (1|2)
  printf '%s\n' "$1" >&2 || true
  exit "$2"
}

# --- argument parsing (single positional; -- ends option parsing) -----------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --) shift; break ;;
    -*) refuse usage 2 ;;
    *)  break ;;
  esac
done

SPEC=""
if [ "$#" -ge 1 ]; then SPEC="$1"; shift; fi
[ "$#" -eq 0 ] || refuse usage 2
[ -n "$SPEC" ] || refuse usage 2

# `-f` (regular file) before `-r` (readable) — a directory/FIFO is classified
# by its TYPE, not by permissions; a dangling symlink is caught by `-f` alone
# (it follows symlinks and is false for a dangling target).
[ -f "$SPEC" ] && [ -r "$SPEC" ] || refuse spec-unreadable 2

# --- read the file into a 1-indexed array, CR-stripped, with fence state ----
# Fence state machine ported from bin/check-board-headings.sh's
# extract_ids_to_file (T-095's CommonMark-aligned tracker): a fence OPENER is
# a line whose leading indentation is 0-3 LITERAL SPACE characters followed
# by a run of 3+ backticks; its info string, if any, is not validated. Once
# opened, the opener's run length is recorded (fence_len) and FENCED[] is 1
# for every line up to and including a CLOSER — 0-3-space-indented, a
# backtick run >= fence_len, and nothing but trailing whitespace after the
# run (a shorter run, or trailing content, does not close it). Tilde (~~~)
# fences are not tracked (this script is an honest-error tool over specs this
# loop itself produces, never an adversarial-markdown parser — Input space's
# own out-of-scope declaration).
FENCE_OPEN_RE='^[ ]{0,3}(`{3,})'

LINES=()
FENCED=()
in_fence=0
fence_len=0
n=0
while IFS= read -r raw || [ -n "$raw" ]; do
  n=$((n + 1))
  line="${raw%$'\r'}"
  LINES[n]="$line"
  if [ "$in_fence" -eq 0 ]; then
    if [[ "$line" =~ $FENCE_OPEN_RE ]]; then
      fence_len="${#BASH_REMATCH[1]}"
      in_fence=1
      FENCED[n]=1
    else
      FENCED[n]=0
    fi
  else
    close_re='^[ ]{0,3}`{'"$fence_len"',}[[:space:]]*$'
    if [[ "$line" =~ $close_re ]]; then
      in_fence=0
    fi
    FENCED[n]=1
  fi
done < "$SPEC"
NLINES="$n"

# --- 1. locate the intent block: the UNFENCED marker pair alone, no task-id
# derivation of this script's own (bin/check-intent.sh owns that scoping) ---
BEGIN_RE='^<!-- BEGIN intent-block: .+ -->$'
END_RE='^<!-- END intent-block: .+ -->$'

begin_count=0
begin_ln=0
end_count=0
end_ln=0
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${FENCED[i]}" -eq 0 ]; then
    if [[ "${LINES[i]}" =~ $BEGIN_RE ]]; then
      begin_count=$((begin_count + 1))
      begin_ln="$i"
    fi
    if [[ "${LINES[i]}" =~ $END_RE ]]; then
      end_count=$((end_count + 1))
      end_ln="$i"
    fi
  fi
  i=$((i + 1))
done

if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
  refuse intent-block-missing 2
fi
if [ "$begin_ln" -ge "$end_ln" ]; then
  refuse intent-block-missing 2
fi

# --- 2. the valid placement window: strictly between BEGIN and the first
# unfenced `## Non-goals` heading after it (falling back to END when no such
# heading is found inside the block, which should not happen for a
# well-formed spec but must not crash this script either) -------------------
NG_RE='^## Non-goals$'
ng_ln=0
i=$((begin_ln + 1))
while [ "$i" -lt "$end_ln" ]; do
  if [ "${FENCED[i]}" -eq 0 ] && [[ "${LINES[i]}" =~ $NG_RE ]]; then
    ng_ln="$i"
    break
  fi
  i=$((i + 1))
done
if [ "$ng_ln" -gt 0 ]; then
  window_end="$ng_ln"
else
  window_end="$end_ln"
fi

# --- 3. find every unindented, unfenced `- user-visible:` occurrence in the
# WHOLE FILE (not just inside the intent block) — a well-formed declaration
# placed entirely outside the block is `declaration-misplaced`, not
# `declaration-missing`, and can only be found by searching the whole file --
DECL_RE='^- user-visible:(.*)$'
decl_positions=()
decl_lines=()
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${FENCED[i]}" -eq 0 ] && [[ "${LINES[i]}" =~ $DECL_RE ]]; then
    decl_positions+=("$i")
    decl_lines+=("${LINES[i]}")
  fi
  i=$((i + 1))
done

decl_count="${#decl_positions[@]}"
if [ "$decl_count" -eq 0 ]; then
  refuse declaration-missing 1
fi
if [ "$decl_count" -ge 2 ]; then
  refuse declaration-duplicate 1
fi

dpos="${decl_positions[0]}"
dline="${decl_lines[0]}"

if [ "$dpos" -le "$begin_ln" ] || [ "$dpos" -ge "$window_end" ]; then
  refuse declaration-misplaced 1
fi

# --- 4. grammar: `- user-visible: <value> — <rationale>` --------------------
# The separator is the literal em dash (U+2014), surrounded by spaces in a
# well-formed line; split on the FIRST occurrence of the em dash character
# alone (bash's %%/# operators already find the first occurrence), then trim
# both sides — this tolerates a rationale that itself later quotes an em
# dash, and correctly rejects a line with no em dash at all (missing
# separator) or a value/rationale that is empty after trimming.
EMDASH='—'

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

rest="${dline#"- user-visible:"}"
case "$rest" in
  *"$EMDASH"*) : ;;
  *) refuse declaration-malformed 1 ;;
esac
value_part="${rest%%"$EMDASH"*}"
rationale_part="${rest#*"$EMDASH"}"
DECL_VALUE="$(trim "$value_part")"
rationale="$(trim "$rationale_part")"

case "$DECL_VALUE" in
  yes|no) : ;;
  *) refuse declaration-malformed 1 ;;
esac
[ -n "$rationale" ] || refuse declaration-malformed 1

# --- 5. discharge markers: scoped to INSIDE the intent block only (strictly
# between BEGIN and END), fence-aware throughout. `- adopter-docs-waiver:` is
# top-level (unindented); `- adopter-surface:` is read only when nested,
# as an indented continuation line, directly under a real AC-bullet-shaped
# line — never a bare whole-file scan (T-1061 round-1 rework, Major #1).
# Value retention is "any in-scope occurrence has a non-whitespace value",
# never "the first occurrence's value" (Major #2) — applied identically to
# both markers, since both are legal to occur more than once.
WAIVER_RE='^- adopter-docs-waiver:(.*)$'
SURFACE_RE='^[[:space:]]+- adopter-surface:(.*)$'
# AC_BULLET_RE mirrors bin/check-acs.sh's own CANDIDATE_RE shape
# (`^- \[[ xX]\] \*\*AC`) — a column-0 "is this AC-bullet-shaped at all" test,
# deliberately permissive (this script never re-validates the bullet's own
# grammar; it only needs to know a surface line sits under something that at
# least LOOKS like an acceptance criterion, per the Goal's own wording).
AC_BULLET_RE='^- \[[ xX]\] \*\*AC'
INDENT_NONBLANK_RE='^[[:space:]]+[^[:space:]]'
BLANK_RE='^[[:space:]]*$'

waiver_count=0
waiver_has_value=0
surface_count=0
surface_has_value=0
in_ac=0
i=$((begin_ln + 1))
while [ "$i" -lt "$end_ln" ]; do
  if [ "${FENCED[i]}" -eq 1 ]; then
    i=$((i + 1))
    continue
  fi
  line="${LINES[i]}"
  if [[ "$line" =~ $BLANK_RE ]]; then
    : # neutral: a blank line changes neither in_ac nor anything else
  elif [[ "$line" =~ $INDENT_NONBLANK_RE ]]; then
    # An indented, non-blank line is the ONLY thing that keeps an AC scope
    # open — mirroring bin/check-intent.sh's own board-entry continuation
    # canon. Only checked for a surface match while that scope is open.
    if [ "$in_ac" -eq 1 ] && [[ "$line" =~ $SURFACE_RE ]]; then
      surface_count=$((surface_count + 1))
      val="$(trim "${BASH_REMATCH[1]}")"
      [ -n "$val" ] && surface_has_value=1
    fi
  else
    # Any other non-indented, non-blank line closes any open AC scope first,
    # then opens a new one only if the SAME line is itself AC-bullet-shaped.
    in_ac=0
    if [[ "$line" =~ $AC_BULLET_RE ]]; then
      in_ac=1
    fi
    if [[ "$line" =~ $WAIVER_RE ]]; then
      waiver_count=$((waiver_count + 1))
      val="$(trim "${BASH_REMATCH[1]}")"
      [ -n "$val" ] && waiver_has_value=1
    fi
  fi
  i=$((i + 1))
done

# --- 6. the discharge decision (DP6: waiver and surface are mutually
# exclusive, and both are refused beside a `no`) -----------------------------
if [ "$DECL_VALUE" = "no" ]; then
  if [ "$waiver_count" -ge 1 ] || [ "$surface_count" -ge 1 ]; then
    refuse marker-conflict 1
  fi
  exit 0
fi

# DECL_VALUE = yes
if [ "$waiver_count" -ge 1 ] && [ "$surface_count" -ge 1 ]; then
  refuse marker-conflict 1
fi

if [ "$waiver_count" -ge 1 ]; then
  [ "$waiver_has_value" -eq 1 ] || refuse waiver-reason-empty 1
  exit 0
fi

if [ "$surface_count" -ge 1 ]; then
  [ "$surface_has_value" -eq 1 ] || refuse obligation-undischarged 1
  exit 0
fi

refuse obligation-undischarged 1
