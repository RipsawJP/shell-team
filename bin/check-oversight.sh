#!/usr/bin/env bash
# check-oversight.sh — selectable oversight-profile gate for a governance-
# controlled repository (T-1103; GitHub issue #343;
# .shell-team/specs/T-1103-oversight-profiles.md).
#
# Decision this implements: docs/loop-engineering/record-tamper-resistance.md
# — tamper-arm-rule-v1 sends this task's three duties to two different arms.
# Duty A (the approval-record gate: does a conformant record exist for a
# declared seam, and is its approver distinct from its producer) takes
# arm-A-tested-primitive: its verdict gates a freeze (specify-seam) and a
# close-out (pre-merge), and its judgment is a line match, a field
# extraction, a charset test and a string inequality over committed bytes.
# Duty B (profile resolution) RECLASSIFIES into arm A under that note's own
# reclassification clause: a silent `autonomous` answer for an unreadable or
# malformed declaration would let duty A's verdict pass vacuously at every
# declared seam at once, so the occupancy lattice below is fail-closed on
# every non-accepting member rather than falling back to the default. Duty C
# (the approval's substance, and the handle's ownership) fails conjunct 2
# outright and stays arm-B-enumerated-instrument: a disclosed, not closed,
# self-declared conflict check — the eleven-item enumeration lives in this
# task's spec Goal section, not here.
#
# This is the FOURTH obligation promoted into arm A (after #341, #344 and
# #301/T-1099), per that note's own count.
#
# The occupancy lattice at <base>/oversight.conf follows
# bin/resolve-executor.sh:297-326 member for member, never silently falling back to the shipped default on a broken occupant:
#   - absent                                    -> shipped default, `autonomous`
#   - regular file                              -> host declaration wins
#   - live symlink resolving to a regular file  -> host declaration wins,
#     deliberately the same as a regular file: `[ -f ]` follows symlinks by
#     design and a host is free to author the config at a symlinked path
#   - unreadable regular file                   -> refuses `declaration-unreadable`
#   - dangling symlink / a directory / a FIFO / anything else PRESENT (`-e`)
#     or itself a symlink (`-L`, so dangling/looping is caught even though
#     `-e` is false for both) but not a regular file -> refuses
#     `declaration-occupancy` BEFORE any parsing
#
# Enrollment is sticky: an `autonomous` answer reached from the ABSENT arm
# refuses (`enrollment-vanished`) once the resolved board carries a prior
# `- oversight-approval (` record anywhere in it (either section, any task,
# either seam) — the only silent path out of governance is a config that was
# never authored; the only AUTHORIZED path is an explicit `profile
# autonomous` declaration, a present, diffable file. See this task's spec
# Goal section ("Enrollment does not evaporate...") for the full reasoning.
#
# The config is never sourced, evaluated as code, or executed — every field
# is a bare token, following bin/check-binding.sh's own contract.
#
# Usage:
#   check-oversight.sh --print-profile [--base DIR | --config PATH]
#     Resolve the effective profile and print exactly one line,
#     `profile <autonomous|governance-controlled>`, on stdout. Exit 0 on
#     success; a non-zero exit refuses per the closed set below and prints
#     nothing to stdout.
#   check-oversight.sh --seam <specify-seam|pre-merge> --task T-NNN
#                       --board PATH [--base DIR | --config PATH]
#     Evaluate whether the named seam's requirement is satisfied for the
#     named task's own `## Active` board entry. Exit 0 = the seam imposes
#     nothing, or a conformant approval already covers it; non-zero = a
#     refusal token on stderr.
#   check-oversight.sh --help
#
# Base-directory precedence for the declaration path (never both --base and
# --config): `--base DIR` (a testing affordance) -> `$TEAM_OVERSIGHT_BASE`
# (the fixture-harness override, same precedence class as $TEAM_TODO and
# $TEAM_INTERVENTIONS_DIR) -> `bash <sibling>/team-paths.sh --get base`,
# with `die` (a usage refusal) on resolver failure and no guessing fallback.
# `--config PATH` names a specific file directly, bypassing the occupancy
# lattice's absent-arm fallback entirely: a --config path that is missing or
# unreadable refuses rather than resolving to the shipped default.
#
# Exit codes and the closed refusal set (one token per non-zero exit,
# printed to stderr, following bin/check-binding.sh's own contract):
#   0 = the seam imposes nothing (profile `autonomous` with no prior
#       approval record anywhere in the resolved board, an explicit host
#       `autonomous` declaration, or the seam not declared under
#       `governance-controlled`), or a conformant approval's anchor is
#       current.
#   1 = a content refusal: missing-schema, duplicate-schema,
#       schema-not-first, unsupported-schema, unparseable-line,
#       missing-profile, duplicate-profile, unknown-profile, unknown-seam,
#       duplicate-seam, seam-under-autonomous, no-seam-declared,
#       approval-missing, approval-malformed, approval-duplicate,
#       bad-handle, approver-equals-producer, approval-anchor-malformed,
#       approval-stale, approval-anchor-ahead, intent-hash-malformed (a
#       `- intent-hash (vN):` sub-bullet on the entry whose own grammar
#       does not match the bounded form this checker requires before
#       feeding N into arithmetic — T-1103 round-3 rework, see the MAXV
#       loop below).
#   2 = the input could not be evaluated at all: usage,
#       declaration-occupancy (a non-regular-file occupant),
#       declaration-unreadable (an unreadable regular file, a missing
#       --config path, or a missing shipped default), enrollment-vanished,
#       board-unresolvable, task-not-found, not-a-git-repo.
#
# No refusal ever echoes an approver/producer handle's bytes — copying
# bin/check-commit-identity.sh's own no-echo discipline, because a report
# that echoed a rejected identity value would turn a control into a leak in
# a public CI log.
#
# What this script does NOT close (arm-B, duty C's disclosed residuals —
# enumerated in full in this task's spec Goal section, not repeated here):
# no identity authentication of any kind; one party can write both the
# approver= and producer= fields; "the approver actually read this" is a
# reading judgment; nothing confirms this gate actually RAN; whether any of
# this satisfies a real segregation-of-duties control is undetermined.

set -euo pipefail

# --- classified refusal helper -----------------------------------------------
# Errexit-safe by construction (repo convention, T-096): the stderr write is
# `|| true`-guarded so a closed-stderr caller cannot turn the intended exit
# code into a bare errexit 1 before the real `exit "$2"` statement runs.
refuse() {  # $1 = token (closed refusal-set member); $2 = exit code (1|2); $3 = message
  printf 'check-oversight: %s: %s\n' "$1" "$3" >&2 || true
  exit "$2"
}
fail_usage() { refuse usage 2 "$1"; }

# Resolve this script's own file, following symlinks (bootstrap shape ported
# from bin/check-durability.sh / bin/check-binding.sh, 2026-06-15/2026-07-14
# lesson: reuse the proven symlink-safe resolver rather than hand-rolling
# one) — every `pwd` below is `pwd -P` (physical) so an ancestor directory
# that is itself a symlink (an adopter's `bin/` vendored into the plugin's
# real `bin/`) still resolves to this script's own real installed directory.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || fail_usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || fail_usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || fail_usage "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

# One level above this script's own installed directory, computed the same
# way as bin/resolve-executor.sh:295-296's own TEMPLATES_ROOT (a fresh
# `cd && pwd -P` rather than assuming SCRIPT_DIR's one-level-up traversal
# introduces no new symlink) — NEVER the current working directory, so a
# decoy templates/oversight-default.conf in an adopter's own tree cannot
# substitute a profile (T-1103 round-2 rework, Major 1).
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || fail_usage "cannot resolve the templates directory (one level above check-oversight.sh's own installed directory)"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# The literal em dash (U+2014), embedded directly as a real character —
# matching the repo's own idiom for a board record's `— `-separated fields
# (bin/close-out.sh's dispatch-record parsing).
EM="—"

trim() {  # $1 = raw value; strips leading/trailing whitespace
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

lower_ascii() {  # $1 = value; ASCII-only lowercase under LC_ALL=C (T-1103
                  # DP-3: a POSIX [:upper:]/[:lower:] class is locale-
                  # dependent — e.g. the Turkish 'i' — so an explicit A-Z
                  # range is used instead, never ${var,,}).
  # shellcheck disable=SC2018,SC2019  # ASCII-only by design (DP-3), not POSIX classes
  printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'
}

HANDLE_RE='^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'

# --- argument parsing --------------------------------------------------------
MODE="" SEAM_ARG="" TASK_ARG="" BOARD_ARG="" BASE_ARG="" CONFIG_ARG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --print-profile)
      [ -z "$MODE" ] || fail_usage "specify only one of --print-profile or --seam"
      MODE="print-profile"; shift ;;
    --seam)
      [ "$#" -ge 2 ] || fail_usage "--seam requires a value"
      [ -z "$MODE" ] || fail_usage "specify only one of --print-profile or --seam"
      MODE="seam"; SEAM_ARG="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || fail_usage "--task requires a value"
      TASK_ARG="$2"; shift 2 ;;
    --board)
      [ "$#" -ge 2 ] || fail_usage "--board requires a value"
      BOARD_ARG="$2"; shift 2 ;;
    --base)
      [ "$#" -ge 2 ] || fail_usage "--base requires a value"
      [ -z "$CONFIG_ARG" ] || fail_usage "specify only one of --base or --config"
      BASE_ARG="$2"; shift 2 ;;
    --config)
      [ "$#" -ge 2 ] || fail_usage "--config requires a value"
      [ -z "$BASE_ARG" ] || fail_usage "specify only one of --base or --config"
      CONFIG_ARG="$2"; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"
[ -n "$MODE" ] || fail_usage "one of --print-profile or --seam is required (see --help)"

if [ "$MODE" = "seam" ]; then
  case "$SEAM_ARG" in
    specify-seam|pre-merge) : ;;
    *) fail_usage "--seam must be one of specify-seam|pre-merge: '$SEAM_ARG'" ;;
  esac
  [ -n "$TASK_ARG" ] || fail_usage "--seam requires --task"
  [[ "$TASK_ARG" =~ ^T-[0-9]+$ ]] || fail_usage "invalid --task '$TASK_ARG' (expected T-<digits>)"
  [ -n "$BOARD_ARG" ] || fail_usage "--seam requires --board"
fi

# --- resolve the sibling path resolver (only needed absent --base/--config) --
TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"

# --- resolve the declaration path -------------------------------------------
CONFIG_PATH="" PRESENT=0

if [ -n "$CONFIG_ARG" ]; then
  CONFIG_PATH="$CONFIG_ARG"
  if [ -f "$CONFIG_PATH" ]; then
    PRESENT=1
  else
    refuse declaration-unreadable 2 "cannot read the named oversight declaration: $CONFIG_PATH"
  fi
else
  if [ -n "$BASE_ARG" ]; then
    BASE_DIR="$BASE_ARG"
  elif [ -n "${TEAM_OVERSIGHT_BASE:-}" ]; then
    BASE_DIR="$TEAM_OVERSIGHT_BASE"
  else
    [ -f "$TEAM_PATHS" ] && [ -r "$TEAM_PATHS" ] \
      || fail_usage "cannot resolve operating paths (team-paths.sh missing or unreadable next to check-oversight.sh)"
    BASE_DIR="$(bash "$TEAM_PATHS" --get base 2>/dev/null)" \
      || fail_usage "team-paths.sh could not resolve the base directory"
  fi
  BASE_DIR="${BASE_DIR%/}"
  CONFIG_PATH="$BASE_DIR/oversight.conf"

  if [ -f "$CONFIG_PATH" ]; then
    PRESENT=1
  elif [ -e "$CONFIG_PATH" ] || [ -L "$CONFIG_PATH" ]; then
    refuse declaration-occupancy 2 "a non-regular-file occupant exists at $CONFIG_PATH (a directory, a FIFO, a dangling symlink, or some other non-regular type) — refusing rather than silently falling back to the shipped autonomous default"
  else
    PRESENT=0
  fi
fi

PROFILE="" SEAMS=()

# --- parse the declaration (two-pass shape, T-1103 grammar) ------------------
parse_config() {  # $1 = config path (already confirmed a readable regular file)
  local cfg="$1"
  local -a lines=()
  local raw line

  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    lines+=("$line")
  done < "$cfg"

  local schema_count=0 schema_idx=-1 schema_version=""
  local profile_count=0 profile_value=""
  local -a seam_values=()
  local i ln first
  local -a f

  for ((i = 0; i < ${#lines[@]}; i++)); do
    ln="${lines[$i]}"
    read -r -a f <<< "$ln"
    first="${f[0]:-}"
    case "$first" in
      schema)
        schema_count=$((schema_count + 1))
        if [ "$schema_count" -eq 1 ]; then schema_idx="$i"; fi
        [ "${#f[@]}" -eq 2 ] \
          || refuse unparseable-line 1 "malformed schema line (expected exactly 'schema <version>'): $ln"
        schema_version="${f[1]}"
        ;;
      profile)
        profile_count=$((profile_count + 1))
        [ "${#f[@]}" -eq 2 ] \
          || refuse unparseable-line 1 "malformed profile line (expected exactly 'profile <value>'): $ln"
        profile_value="${f[1]}"
        ;;
      seam)
        [ "${#f[@]}" -eq 2 ] \
          || refuse unparseable-line 1 "malformed seam line (expected exactly 'seam <value>'): $ln"
        seam_values+=("${f[1]}")
        ;;
      *)
        refuse unparseable-line 1 "a line's first field is neither 'schema', 'profile' nor 'seam': $ln"
        ;;
    esac
  done

  [ "$schema_count" -ge 1 ] || refuse missing-schema 1 "no schema line found in $cfg"
  [ "$schema_count" -le 1 ] || refuse duplicate-schema 1 "more than one schema line found in $cfg"
  [ "$schema_idx" -eq 0 ]   || refuse schema-not-first 1 "a line precedes the schema line in $cfg"
  [ "$schema_version" = "1" ] \
    || refuse unsupported-schema 1 "unsupported schema version '$schema_version' in $cfg"

  [ "$profile_count" -ge 1 ] || refuse missing-profile 1 "no profile line found in $cfg"
  [ "$profile_count" -le 1 ] || refuse duplicate-profile 1 "more than one profile line found in $cfg"
  case "$profile_value" in
    autonomous|governance-controlled) : ;;
    *) refuse unknown-profile 1 "profile value is outside the closed pair autonomous/governance-controlled: '$profile_value'" ;;
  esac

  local seen=" " sv
  if [ "${#seam_values[@]}" -gt 0 ]; then
    for sv in "${seam_values[@]}"; do
      case "$sv" in
        specify-seam|pre-merge) : ;;
        *) refuse unknown-seam 1 "seam value is outside the closed pair specify-seam/pre-merge: '$sv'" ;;
      esac
      case "$seen" in
        *" $sv "*) refuse duplicate-seam 1 "seam declared more than once: '$sv'" ;;
      esac
      seen="${seen}${sv} "
    done
  fi

  if [ "$profile_value" = "governance-controlled" ] && [ "${#seam_values[@]}" -eq 0 ]; then
    refuse no-seam-declared 1 "profile governance-controlled declares no seam row: $cfg"
  fi
  if [ "$profile_value" = "autonomous" ] && [ "${#seam_values[@]}" -gt 0 ]; then
    refuse seam-under-autonomous 1 "a seam row exists under profile autonomous: $cfg"
  fi

  PROFILE="$profile_value"
  SEAMS=()
  if [ "${#seam_values[@]}" -gt 0 ]; then
    SEAMS=("${seam_values[@]}")
  fi
}

if [ "$PRESENT" -eq 1 ]; then
  [ -r "$CONFIG_PATH" ] \
    || refuse declaration-unreadable 2 "cannot read the oversight declaration: $CONFIG_PATH"
  parse_config "$CONFIG_PATH"
else
  # T-1103 round-2 rework, Major 1: the absent arm now actually resolves and
  # validates the shipped templates/oversight-default.conf through the
  # SAME parse_config() sibling a host declaration goes through, member for
  # member with bin/resolve-executor.sh:319-326's own absent arm (which
  # resolves templates/binding-default.conf and delegates to
  # check-binding.sh rather than hardcoding the result). A missing or
  # unreadable shipped default refuses declaration-unreadable, exit 2 —
  # this task's own Input space: "An install whose bin/check-oversight.sh
  # or shipped templates/oversight-default.conf is missing or unreadable.
  # die, exit 2 ..." — never a silently hardcoded 'autonomous' literal.
  DEFAULT_CONFIG="$TEMPLATES_ROOT/templates/oversight-default.conf"
  if [ -f "$DEFAULT_CONFIG" ] && [ -r "$DEFAULT_CONFIG" ]; then
    parse_config "$DEFAULT_CONFIG"
  else
    refuse declaration-unreadable 2 "the shipped default oversight declaration is missing or unreadable: $DEFAULT_CONFIG"
  fi
fi

# --- --print-profile mode: done, no board needed ----------------------------
if [ "$MODE" = "print-profile" ]; then
  printf 'profile %s\n' "$PROFILE"
  exit 0
fi

# --- seam mode from here -----------------------------------------------------
[ -r "$BOARD_ARG" ] || refuse board-unresolvable 2 "cannot read board: $BOARD_ARG"

# Sticky enrollment: occupancy/grammar refusals above already ran and none
# fired, so a profile of `autonomous` here either came from the ABSENT arm
# (PRESENT=0) or from an explicit host declaration (PRESENT=1, a present
# `profile autonomous` file — the authorized de-enrollment, which never
# reaches this scan). The scan reads the WHOLE resolved board — `## Active`
# and `## Done` alike, any task, either seam — because the profile it
# protects is a per-repository property, not a per-task one (T-1103 spec
# Goal, "Enrollment does not evaporate"). Zero-or-more leading whitespace,
# matching the shipped grammar the sticky scan and AC13's own zero-proof
# both use; this is the ONE place this script states that pattern.
if [ "$PRESENT" -eq 0 ]; then
  if grep -qE '^[[:space:]]*- oversight-approval \(' "$BOARD_ARG"; then
    refuse enrollment-vanished 2 "the oversight declaration is absent, but the board carries at least one prior oversight-approval record — this repository has operated under governance and cannot silently fall back to autonomous; author an explicit 'profile autonomous' declaration to de-enrol, or restore the governance declaration"
  fi
fi

# --- locate the task's own ## Active entry extent (shared shape with
# bin/check-entry-mode.sh, its close-out-side arm-A sibling, and
# bin/close-out.sh itself) ----------------------------------------------------
scan="$(awk -v task="$TASK_ARG" '
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
' "$BOARD_ARG")"
read -r A_START A_END A_COUNT <<< "$scan"
[ "$A_COUNT" -eq 1 ] \
  || refuse task-not-found 2 "$TASK_ARG is not exactly one top-level entry in ## Active of $BOARD_ARG"

# CRLF tolerance (T-1103 gotcha): strip a trailing CR per line before any
# grammar match, same discipline bin/check-entry-mode.sh already applies.
ENTRY="$(sed -n "${A_START},${A_END}p" "$BOARD_ARG" | sed 's/\r$//')"

# --- is this seam even in force? --------------------------------------------
if [ "$PROFILE" != "governance-controlled" ]; then
  exit 0
fi
seam_declared=0
if [ "${#SEAMS[@]}" -gt 0 ]; then
  for s in "${SEAMS[@]}"; do
    [ "$s" = "$SEAM_ARG" ] && seam_declared=1
  done
fi
if [ "$seam_declared" -eq 0 ]; then
  exit 0
fi

# --- locate this seam's own approval record ---------------------------------
RECORD_ANCHOR="^[[:space:]]*- oversight-approval \($SEAM_ARG\): "
MATCHES="$(printf '%s\n' "$ENTRY" | grep -E -- "$RECORD_ANCHOR" || true)"
MCOUNT="$(printf '%s\n' "$MATCHES" | grep -c . || true)"

[ "$MCOUNT" -ge 1 ] \
  || refuse approval-missing 1 "$TASK_ARG has no conformant '- oversight-approval ($SEAM_ARG):' record on its board entry"
[ "$MCOUNT" -le 1 ] \
  || refuse approval-duplicate 1 "$TASK_ARG carries more than one '- oversight-approval ($SEAM_ARG):' record for this seam on its board entry"

RLINE="$MATCHES"
REM="$(printf '%s\n' "$RLINE" | sed -E "s/^[[:space:]]*- oversight-approval \\($SEAM_ARG\\): //")"

# Absolute board line number of the record, so a malformed-grammar refusal
# can name WHERE the problem is without ever echoing WHAT it contains (round
# -2 rework, Major 2: approval-malformed used to interpolate the whole raw
# line, handle bytes included, into its stderr message, contradicting this
# file's own no-echo invariant, header lines 93-96).
REL_LINE="$(printf '%s\n' "$ENTRY" | grep -n -E -- "$RECORD_ANCHOR" | sed -n '1p' | cut -d: -f1)"
RLINE_NUM=$((REL_LINE + A_START - 1))

# --- single-pass field extraction (round-2 rework, Blocker 2) ---------------
# The previous shape ran three INDEPENDENT greedy `sed` passes, one per
# field, each anchored to the WHOLE line with its own `.*` before the next
# literal ` EM ` separator. Because record= is genuinely free-form and
# permitted to contain the separator itself (this file's own header, and the
# dispatch-record precedent it copies — bin/close-out.sh:288-291), an em-
# dash-delimited decoy sequence planted inside record='s own value gave every
# EARLIER field's greedy `.*` a second, later place in the line to anchor
# on — shifting approves_raw (or any other field) to the decoy's value
# instead of the record's real one. The fix reads the five fields left to
# right in ONE pass, consuming exactly one ` EM `-delimited key=value prefix
# per field before advancing past it, so record= — the last field — can
# never influence where an EARLIER field is read from: the decoy tail lands
# entirely inside record='s own (unread) value. This is the same left-to-
# right discipline bin/close-out.sh:288-291's dispatch-record parse already
# uses, adapted from restricted-charset fields to arbitrary-byte ones by
# consuming the separator itself rather than a charset boundary.
approver_raw="" producer_raw="" approves_raw="" date_raw=""
rest="$REM"
parse_ok=1
for key in approver producer approves date; do
  case "$rest" in
    "$key="*) : ;;
    *) parse_ok=0 ;;
  esac
  if [ "$parse_ok" -eq 1 ]; then
    case "$rest" in
      *" $EM "*)
        kv="${rest%% "$EM" *}"
        rest="${rest#*"$EM" }"
        ;;
      *) parse_ok=0 ;;
    esac
  fi
  [ "$parse_ok" -eq 1 ] || break
  val="${kv#"$key"=}"
  case "$key" in
    approver) approver_raw="$val" ;;
    producer) producer_raw="$val" ;;
    approves) approves_raw="$val" ;;
    date)     date_raw="$val" ;;
  esac
done
if [ "$parse_ok" -eq 1 ]; then
  case "$rest" in
    record=*) : ;;
    *) parse_ok=0 ;;
  esac
fi

[ "$parse_ok" -eq 1 ] \
  || refuse approval-malformed 1 "$TASK_ARG's '- oversight-approval ($SEAM_ARG):' record at board line $RLINE_NUM does not match the required grammar (approver=... — producer=... — approves=... — date=... — record=...)"

APPROVER="$(trim "$approver_raw")"
PRODUCER="$(trim "$producer_raw")"
DATE="$(trim "$date_raw")"

[[ "$APPROVER" =~ $HANDLE_RE ]] || refuse bad-handle 1 "$TASK_ARG's '- oversight-approval ($SEAM_ARG):' approver= value does not match the required handle grammar"
[[ "$PRODUCER" =~ $HANDLE_RE ]] || refuse bad-handle 1 "$TASK_ARG's '- oversight-approval ($SEAM_ARG):' producer= value does not match the required handle grammar"

if [ "$(lower_ascii "$APPROVER")" = "$(lower_ascii "$PRODUCER")" ]; then
  refuse approver-equals-producer 1 "$TASK_ARG's '- oversight-approval ($SEAM_ARG):' approver and producer are the same party after ASCII normalization"
fi

# T-1103 round-2 rework, Minor 2: date= grammar (YYYY-MM-DD), the shape this
# task's own record-grammar paragraph states. date= plays no role in the
# anchor/staleness logic (that is approves='s job, below), so this is
# audit-trail quality rather than a control gap — but it was unvalidated
# before this rework.
DATE_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
[[ "$DATE" =~ $DATE_RE ]] \
  || refuse approval-malformed 1 "$TASK_ARG's '- oversight-approval ($SEAM_ARG):' date= value does not match the required form YYYY-MM-DD"

APPROVES="$(trim "$approves_raw")"

# --- the two anchor comparisons ---------------------------------------------
if [ "$SEAM_ARG" = "specify-seam" ]; then
  # T-1103 round-2 rework, Blocker 1: bounded BEFORE any `$((10#...))`
  # arithmetic runs on this untrusted, party-authored field (duty C (ii)
  # discloses that one party can write approves= unsupervised). The
  # previous form (`^v[0-9]+$`, unbounded digit count) let
  # `approves=v18446744073709551617` wrap bash's fixed-width arithmetic
  # modulo 2^64 (`$((10#18446744073709551617))` == 1) and pass the equality
  # check silently as if it read `approves=v1` — the identical class of
  # defect (an anchor value that should be bounded but isn't) two prior
  # review rounds already fought to close via the comparison operator,
  # resurfacing here through integer overflow instead. Fifteen digits
  # (max ~10^15) is comfortably below bash's 64-bit signed ceiling
  # (~9.2*10^18, 19-20 digits) with no realistic board ever approaching it,
  # and a leading zero (other than the literal single digit '0') is refused
  # rather than silently accepted as an equivalent numeral, since this
  # anchor is compared for EQUALITY against a canonical `v<N>` form with no
  # leading zeros.
  [[ "$APPROVES" =~ ^v(0|[1-9][0-9]{0,14})$ ]] \
    || refuse approval-anchor-malformed 1 "$TASK_ARG's '- oversight-approval (specify-seam):' approves= value is not of the required form v<N> (at most 15 digits, no leading zero): '$APPROVES'"

  # The checker reads ONLY `- intent-hash (v<M>):` sub-bullets and the
  # approval record — nothing else on the entry (a `- refreeze-class:` or
  # `- intent-ratified:` sub-bullet included) participates in this
  # arithmetic, by design (T-1103 DP-13: the gate is version-based and
  # class-blind).
  #
  # T-1103 round-3 rework (Codex impl-review round 2, fresh Blocker): this
  # loop's own capture used to be `^[[:space:]]*-\ intent-hash\ \(v([0-9]+)\):`
  # — an UNBOUNDED digit count feeding `$((10#$v))` — the identical overflow
  # class Blocker 1 above already closed on the equality's OTHER operand
  # (APPROVES), left open here on MAXV. Live repro that motivated this fix: a
  # board entry carrying only `- intent-hash (v18446744073709551617):`
  # alongside `approves=v2` refused nothing (exit 0, silent), because
  # `$((10#18446744073709551617))` wraps to 1, making MAXV=1 and EXPECTED=2
  # — indistinguishable from a genuine `v1` entry.
  #
  # The bound is PORTED from bin/check-intent.sh's own HASH_FULL_RE
  # (`^[[:space:]]+- intent-hash \(v([0-9]{1,4})\): ([0-9a-f]{40})$`,
  # check-intent.sh:440), which bounds the identical field to {1,4} digits
  # with a comment citing T-1021 (D4, Codex round1 Major) as the reason the
  # bound exists there: "hash_version is fed straight into a `10#`
  # arithmetic expansion... with no width bound on the capture" — same
  # sibling file, same board grammar, same underlying class of defect.
  # {1,4} (max 9999) carries the same headroom this repo's own board history
  # already established sufficient at the sibling site.
  #
  # Refusal semantics for a line that LOOKS like an intent-hash sub-bullet
  # (matches the loose anchor) but fails the bounded full grammar: this is
  # board content the checker cannot evaluate, so it refuses fail-closed
  # (intent-hash-malformed, exit 1 — the same exit-1 "content refusal" class
  # every other malformed-grammar refusal in this file uses) rather than
  # skipping the line and silently continuing. Skip-and-continue was
  # rejected on purpose: it would let a fabricated oversized (or otherwise
  # malformed) intent-hash line hide the board's real maximum from this
  # equality instead of being counted against it. This mirrors
  # check-intent.sh's own disposition for the identical shape — a line that
  # matches HASH_LINE_RE but not HASH_FULL_RE increments hash_bad_count,
  # which unconditionally fails the check (fail_hash_structural) rather than
  # being dropped from the count. The refusal message never echoes the
  # offending digit string (or any other byte of the malformed line), only
  # naming which task's entry and which sub-bullet shape was rejected.
  HASH_LOOSE_RE='^[[:space:]]*-\ intent-hash\ \('
  HASH_STRICT_RE='^[[:space:]]*-\ intent-hash\ \(v([0-9]{1,4})\):\ [0-9a-f]{40}$'
  MAXV=0
  while IFS= read -r iln; do
    [ -n "$iln" ] || continue
    if [[ "$iln" =~ $HASH_LOOSE_RE ]]; then
      if [[ "$iln" =~ $HASH_STRICT_RE ]]; then
        v="${BASH_REMATCH[1]}"
        v="$((10#$v))"
        if [ "$v" -gt "$MAXV" ]; then MAXV="$v"; fi
      else
        refuse intent-hash-malformed 1 "$TASK_ARG's board entry carries a '- intent-hash (...):' sub-bullet whose grammar does not match the required bounded form (v<N>, at most 4 digits, followed by a 40-hex hash) — refusing rather than silently truncating or dropping an oversized or malformed version number from this equality's maximum"
      fi
    fi
  done <<< "$ENTRY"
  EXPECTED=$((MAXV + 1))

  N="${APPROVES#v}"
  N="$((10#$N))"

  if [ "$N" -lt "$EXPECTED" ]; then
    refuse approval-stale 1 "$TASK_ARG's '- oversight-approval (specify-seam):' approves=v$N is stale (expected v$EXPECTED, the board's recorded maximum plus one)"
  fi
  if [ "$N" -gt "$EXPECTED" ]; then
    refuse approval-anchor-ahead 1 "$TASK_ARG's '- oversight-approval (specify-seam):' approves=v$N is ahead of the freeze in progress (expected v$EXPECTED, the board's recorded maximum plus one)"
  fi
else
  # pre-merge
  [[ "$APPROVES" =~ ^[0-9a-f]{40}$ ]] \
    || refuse approval-anchor-malformed 1 "$TASK_ARG's '- oversight-approval (pre-merge):' approves= value is not a 40-hex commit id: '$APPROVES'"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || refuse not-a-git-repo 2 "the pre-merge seam requires a git repository to compare the approval anchor"

  git cat-file -e "${APPROVES}^{commit}" 2>/dev/null \
    || refuse approval-stale 1 "$TASK_ARG's '- oversight-approval (pre-merge):' approves= value does not name a commit that exists in this repository: $APPROVES"

  git merge-base --is-ancestor "$APPROVES" HEAD 2>/dev/null \
    || refuse approval-stale 1 "$TASK_ARG's '- oversight-approval (pre-merge):' approves= value is not an ancestor of HEAD: $APPROVES"

  SPEC_PATH="$(printf '%s\n' "$ENTRY" | sed -n '1p' | sed -nE 's/^- \[ \] \*\*T-[0-9]+\*\* .* spec: ([^[:space:]]+\.md)[[:space:]]*$/\1/p')"
  if [ -n "$SPEC_PATH" ]; then
    # T-1103 round-2 rework, Minor 1: a genuine `git log` FAILURE (an
    # anomalous spec: path git rejects, e.g. invalid pathspec magic) must
    # not read the same as "no commit has ever touched this path" (a
    # legitimate, reachable, explicitly-skipped class per this task's own
    # Input space) — the previous `|| true` collapsed both into an empty
    # LAST_TOUCH and silently skipped the freshness check either way. The
    # exit status is captured through the errexit-safe `cmd || rc=$?` shape
    # (repo convention) rather than swallowed, so a real failure refuses
    # instead of silently passing.
    GIT_LOG_RC=0
    LAST_TOUCH="$(git log -1 --format=%H -- "$SPEC_PATH" 2>/dev/null)" || GIT_LOG_RC=$?
    [ "$GIT_LOG_RC" -eq 0 ] \
      || refuse not-a-git-repo 2 "git log exited $GIT_LOG_RC while resolving the last commit that touched $SPEC_PATH"
    if [ -n "$LAST_TOUCH" ]; then
      git merge-base --is-ancestor "$LAST_TOUCH" "$APPROVES" 2>/dev/null \
        || refuse approval-stale 1 "$TASK_ARG's '- oversight-approval (pre-merge):' approves= value predates the last commit that touched $SPEC_PATH"
    fi
  fi
fi

exit 0
