#!/usr/bin/env bash
# check-refreeze-grant.sh — the host-neutral home for a standing class-M
# (mechanics repair) re-freeze grant (T-1147; GitHub issue #515;
# .shell-team/specs/T-1147-class-m-grant-host-neutral-record.md).
#
# Problem this closes: docs/tuning-oversight.md records a standing class-M
# grant only in an adopter's own CLAUDE.local.md — a Claude Code instruction
# surface a Codex CLI host never loads. This script reads a sibling record,
# <base>/refreeze-grant.conf, that either host's orchestrator can run the
# same command against.
#
# The three-way behaviour, which is the whole safety property (spec D-3):
#   - absent                                     -> `grant none`
#   - conformant, declaring the grant             -> `grant <value>`
#   - malformed, out-of-vocabulary, unreadable,
#     or a non-regular occupant                   -> refuses (never granted)
# No input resolves to a grant except a conformant declaration of one. A
# `grant none` record is additive, never a revocation: it means exactly what
# an absent file means, and it never suspends, expires or overrides a grant
# an adopter recorded in CLAUDE.local.md (spec D-7) — that surface, on a
# Claude Code host, keeps working exactly as it does today.
#
# The occupancy lattice at <base>/refreeze-grant.conf follows
# bin/check-oversight.sh's own lattice (bin/check-oversight.sh:26-45,
# :237-264) member for member, never silently falling back to the shipped
# `grant none` default on a broken occupant:
#   - absent                                    -> shipped default, `none`
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
# The config is never sourced, evaluated as code, or executed — every field
# is a bare token, following bin/check-oversight.sh's own contract, which
# follows bin/check-binding.sh's.
#
# Usage:
#   check-refreeze-grant.sh --print-grant [--base DIR | --config PATH]
#     Resolve the effective grant and print exactly one line,
#     `grant <class-m|none>`, on stdout. Exit 0 on success; a non-zero exit
#     refuses per the closed set below and prints nothing to stdout.
#   check-refreeze-grant.sh --help
#
# Base-directory precedence for the declaration path (never both --base and
# --config): `--base DIR` (a testing affordance) -> `$TEAM_REFREEZE_GRANT_BASE`
# (the fixture-harness override, same precedence class as $TEAM_OVERSIGHT_BASE)
# -> `bash <sibling>/team-paths.sh --get base`, with `die` (a usage refusal)
# on resolver failure and no guessing fallback. `--config PATH` names a
# specific file directly, bypassing the occupancy lattice's absent-arm
# fallback entirely: a --config path that is missing or unreadable refuses
# rather than resolving to the shipped default.
#
# Exit codes and the closed refusal set (one token per non-zero exit,
# printed to stderr, following bin/check-oversight.sh's own contract):
#   0 = a conformant record (or the shipped default) resolved: `grant class-m`
#       or `grant none`.
#   1 = a content refusal: unparseable-line, missing-schema, duplicate-schema,
#       schema-not-first, unsupported-schema, missing-grant, duplicate-grant,
#       unknown-grant.
#   2 = the input could not be evaluated at all: usage,
#       declaration-occupancy (a non-regular-file occupant),
#       declaration-unreadable (an unreadable regular file, a missing
#       --config path, or a missing shipped default).
#
# What this script does NOT do (spec Non-goals): it never widens what a
# class-M re-freeze covers, never revokes a grant recorded elsewhere, never
# refuses a freeze or a phase on any input (the worst outcome is no grant,
# which is the per-instance human GO that is already the shipped default),
# and never asserts anything about what a Codex CLI orchestrator loads as
# instruction.

set -euo pipefail

# --- classified refusal helper -----------------------------------------------
# Errexit-safe by construction (repo convention, T-096): the stderr write is
# `|| true`-guarded so a closed-stderr caller cannot turn the intended exit
# code into a bare errexit 1 before the real `exit "$2"` statement runs.
refuse() {  # $1 = token (closed refusal-set member); $2 = exit code (1|2); $3 = message
  printf 'check-refreeze-grant: %s: %s\n' "$1" "$3" >&2 || true
  exit "$2"
}
fail_usage() { refuse usage 2 "$1"; }

# Resolve this script's own file, following symlinks (bootstrap shape ported
# from bin/check-oversight.sh / bin/check-binding.sh, 2026-06-15/2026-07-14
# lesson: reuse the proven symlink-safe resolver rather than hand-rolling
# one) — every `pwd` below is `pwd -P` (physical) so an ancestor directory
# that is itself a symlink still resolves to this script's own real
# installed directory.
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
# way as bin/check-oversight.sh's own TEMPLATES_ROOT (a fresh `cd && pwd -P`
# rather than assuming SCRIPT_DIR's one-level-up traversal introduces no new
# symlink) — NEVER the current working directory, so a decoy
# templates/refreeze-grant-default.conf in an adopter's own tree cannot
# substitute a grant.
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || fail_usage "cannot resolve the templates directory (one level above check-refreeze-grant.sh's own installed directory)"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

trim() {  # $1 = raw value; strips leading/trailing whitespace
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# --- argument parsing --------------------------------------------------------
MODE="" BASE_ARG="" CONFIG_ARG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --print-grant)
      [ -z "$MODE" ] || fail_usage "specify --print-grant only once"
      MODE="print-grant"; shift ;;
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
[ -n "$MODE" ] || fail_usage "--print-grant is required (see --help)"

# --- resolve the sibling path resolver (only needed absent --base/--config) --
TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"

# --- resolve the declaration path -------------------------------------------
CONFIG_PATH="" PRESENT=0

if [ -n "$CONFIG_ARG" ]; then
  CONFIG_PATH="$CONFIG_ARG"
  if [ -f "$CONFIG_PATH" ]; then
    PRESENT=1
  else
    refuse declaration-unreadable 2 "cannot read the named refreeze-grant declaration: $CONFIG_PATH"
  fi
else
  if [ -n "$BASE_ARG" ]; then
    BASE_DIR="$BASE_ARG"
  elif [ -n "${TEAM_REFREEZE_GRANT_BASE:-}" ]; then
    BASE_DIR="$TEAM_REFREEZE_GRANT_BASE"
  else
    [ -f "$TEAM_PATHS" ] && [ -r "$TEAM_PATHS" ] \
      || fail_usage "cannot resolve operating paths (team-paths.sh missing or unreadable next to check-refreeze-grant.sh)"
    BASE_DIR="$(bash "$TEAM_PATHS" --get base 2>/dev/null)" \
      || fail_usage "team-paths.sh could not resolve the base directory"
  fi
  BASE_DIR="${BASE_DIR%/}"
  CONFIG_PATH="$BASE_DIR/refreeze-grant.conf"

  if [ -f "$CONFIG_PATH" ]; then
    PRESENT=1
  elif [ -e "$CONFIG_PATH" ] || [ -L "$CONFIG_PATH" ]; then
    refuse declaration-occupancy 2 "a non-regular-file occupant exists at $CONFIG_PATH (a directory, a FIFO, a dangling symlink, or some other non-regular type) — refusing rather than silently falling back to the shipped no-grant default"
  else
    PRESENT=0
  fi
fi

GRANT=""

# --- parse the declaration (two-pass shape, ported from
#     bin/check-oversight.sh's own T-1103 grammar) ---------------------------
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
  local grant_count=0 grant_value=""
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
      grant)
        grant_count=$((grant_count + 1))
        [ "${#f[@]}" -eq 2 ] \
          || refuse unparseable-line 1 "malformed grant line (expected exactly 'grant <value>'): $ln"
        grant_value="${f[1]}"
        ;;
      *)
        refuse unparseable-line 1 "a line's first field is neither 'schema' nor 'grant': $ln"
        ;;
    esac
  done

  [ "$schema_count" -ge 1 ] || refuse missing-schema 1 "no schema line found in $cfg"
  [ "$schema_count" -le 1 ] || refuse duplicate-schema 1 "more than one schema line found in $cfg"
  [ "$schema_idx" -eq 0 ]   || refuse schema-not-first 1 "a line precedes the schema line in $cfg"
  [ "$schema_version" = "1" ] \
    || refuse unsupported-schema 1 "unsupported schema version '$schema_version' in $cfg"

  [ "$grant_count" -ge 1 ] || refuse missing-grant 1 "no grant line found in $cfg"
  [ "$grant_count" -le 1 ] || refuse duplicate-grant 1 "more than one grant line found in $cfg"
  case "$grant_value" in
    class-m|none) : ;;
    *) refuse unknown-grant 1 "grant value is outside the closed pair class-m/none: '$grant_value'" ;;
  esac

  GRANT="$(trim "$grant_value")"
}

if [ "$PRESENT" -eq 1 ]; then
  [ -r "$CONFIG_PATH" ] \
    || refuse declaration-unreadable 2 "cannot read the refreeze-grant declaration: $CONFIG_PATH"
  parse_config "$CONFIG_PATH"
else
  # The absent arm resolves and validates the shipped
  # templates/refreeze-grant-default.conf through the SAME parse_config()
  # sibling a host declaration goes through, member for member with
  # bin/check-oversight.sh's own absent arm — a missing or unreadable shipped
  # default refuses declaration-unreadable, exit 2, never a hardcoded
  # 'none' literal.
  DEFAULT_CONFIG="$TEMPLATES_ROOT/templates/refreeze-grant-default.conf"
  if [ -f "$DEFAULT_CONFIG" ] && [ -r "$DEFAULT_CONFIG" ]; then
    parse_config "$DEFAULT_CONFIG"
  else
    refuse declaration-unreadable 2 "the shipped default refreeze-grant declaration is missing or unreadable: $DEFAULT_CONFIG"
  fi
fi

if [ "$MODE" = "print-grant" ]; then
  printf 'grant %s\n' "$GRANT"
  exit 0
fi

fail_usage "no recognized mode selected"
