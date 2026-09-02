#!/usr/bin/env bash
# check-model-pins.sh — a CI-wired equality lock between every claude-
# provider role's frontmatter model pin (agents/<role>.md's `model:` line)
# and the shipped default binding's model token for that role (GitHub issue
# #235; T-1117; .shell-team/specs/T-1117-pin-default-equality-lock.md).
# Makes T-1057's frozen AC5 equality clause continuous, running on every CI
# push and pull request instead of being evaluated once at spec-freeze time.
#
# The population is derived by delegation, never compiled in: every `bound`
# row printed by `check-binding.sh --config <default> --print-binding`
# whose provider field is `claude`. Only where the executor IS the harness
# does a frontmatter pin route anything, so selection is by provider alone
# — a role rebound to another provider, or a new role made bindable later,
# changes the population with no edit to this checker. Never
# `resolve-executor`'s --print-resolved mode: that resolves the EFFECTIVE
# binding, where a host-authored config wins over the shipped default, and
# this lock's object is the shipped default alone.
#
# Usage:
#   check-model-pins.sh [--default PATH] [--agents-dir PATH]
#     Validate the equality lock. With no --default, the plugin-shipped
#     binding default resolves from this script's own installed directory
#     (never the working directory). With no --agents-dir, the agents
#     directory next to it resolves the same way. Both flags are read-only
#     testing affordances — they open no write path anywhere — for
#     exercising a mutated pin or conf without touching the checkout.
#   check-model-pins.sh --help
#
# Exit codes:
#   0 — every population row's frontmatter pin equals the shipped conf's
#       model token for that role.
#   1 — the invariant is violated on a readable input: a pin/token
#       disagreement in either direction, or a population row whose agent
#       file carries zero `model:` lines at all (issue #236's pin-retirement
#       shape, which a continuous lock must redden rather than accept).
#   2 — the input could not be evaluated at all: a missing or unreadable
#       agent file, more than one `model:` line, a `model:` line present
#       with an empty value, a delegated refusal, a delegated output that
#       fails the canonical re-assertion below, or an empty population — a
#       conf from which every claude row has gone reads 2, never 0, because
#       a green result there would be maximally misleading.
#
# This complements T-1057's AC5 rather than superseding it: AC5 stays
# frozen and byte-unchanged, evaluated once at spec-freeze time. This
# script makes only its equality clause continuous; issue #236's own
# pin-retirement, when it lands, is what retires the zero-`model:`-lines
# rule above.

set -euo pipefail

# =============================================================================
# Design notes (not part of --help's output — print_help stops reading this
# file's header at the first non-comment line above, i.e. at `set -euo
# pipefail`; everything from here on is free to use any word at all).
#
# Threat model (identical to bin/check-binding.sh's and
# bin/resolve-executor.sh's, for the identical reason): the operator and the
# working directory are TRUSTED (this repository's CLAUDE.md security
# invariant). This defends against accidents — a pin bumped without the
# conf, a conf token bumped without the pin, a half-landed pin retirement —
# never a hostile operator forging a shipped file inside the plugin's own
# installation.
#
# The population is intentionally NOT compiled in: no role name and no
# population count is ever written into this file, only the provider
# selector 'claude'. This is what lets a role rebound to another provider,
# or a new role added to the six-role grammar later, change what this lock
# guards with no edit here. The residual this rule leaves — an inner-loop
# role present in agents/ but absent from the conf — is already closed
# upstream by check-binding.sh's own missing-role refusal and by
# resolve-executor.sh's exactly-six-rows re-assertion; this script does not
# duplicate either.
#
# The canonical form delegated by check-binding.sh --print-binding is
# re-asserted by content before it is trusted (schema line shape and
# version, every row's field count, role uniqueness) — but NOT the row
# count or role membership, which would compile a population size or a
# role list into this checker. Ported (shape only) from
# bin/resolve-executor.sh's own parse_canonical_binding(), with its
# exactly-six-rows and role-membership clauses deliberately dropped.
# =============================================================================

# --- fail-closed helper (errexit-safe by construction, repo convention) -----
die2() {  # $1 = message; exit 2 (the input could not be evaluated at all)
  printf 'check-model-pins: %s\n' "$1" >&2 || true
  exit 2
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported (bootstrap shape) from bin/check-binding.sh / bin/resolve-executor.sh
# — every `pwd` below is `pwd -P` (physical), never the bare logical `pwd`.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || die2 "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || die2 "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || die2 "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || die2 "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || die2 "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || die2 "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || die2 "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
DEFAULT_ARG="" AGENTS_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)    print_help; exit 0 ;;
    --default)    [ "$#" -ge 2 ] || die2 "--default requires a value"
                  [ -n "$2" ] || die2 "--default requires a non-empty value"
                  DEFAULT_ARG="$2"; shift 2 ;;
    --agents-dir) [ "$#" -ge 2 ] || die2 "--agents-dir requires a value"
                  [ -n "$2" ] || die2 "--agents-dir requires a non-empty value"
                  AGENTS_ARG="$2"; shift 2 ;;
    --) shift; break ;;
    -*) die2 "unknown flag: $1" ;;
    *)  die2 "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || die2 "unexpected extra argument: $1"

# --- resolve the two read-only affordances, physically, from this script's --
# own installed directory (DP-10) — never from the working directory, and
# never through team-paths.sh (the lock's object is the plugin-shipped
# default, not a host-resolved base directory).
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || die2 "cannot resolve the directory one level above this script's own installed directory"
DEFAULT_CONF="$TEMPLATES_ROOT/templates/binding-default.conf"
DEFAULT_AGENTS_DIR="$TEMPLATES_ROOT/agents"
CONF="${DEFAULT_ARG:-$DEFAULT_CONF}"
AGENTS_DIR="${AGENTS_ARG:-$DEFAULT_AGENTS_DIR}"

# --- delegate binding parsing to the sibling validator (DP-1) ---------------
if ! BINDING_OUT="$(bash "$SCRIPT_DIR/check-binding.sh" --config "$CONF" --print-binding 2>/dev/null)"; then
  die2 "the delegated binding at $CONF did not resolve"
fi
[ -n "$BINDING_OUT" ] \
  || die2 "the delegated binding at $CONF printed no output"

# --- re-assert the delegated canonical form before trusting it (DP-3) ------
# Field count AND supported schema version, never the schema line's first
# token alone; every bound row's field count; role uniqueness. Deliberately
# NOT re-asserted: the row count and role membership (DP-3) — those are
# check-binding.sh's missing-role refusal and resolve-executor.sh's own
# exactly-six-rows clause to hold, never duplicated here.
SUPPORTED_SCHEMA_VERSIONS=(1)
schema_version_supported() {  # $1 = candidate version token
  local v="$1" x
  for x in "${SUPPORTED_SCHEMA_VERSIONS[@]}"; do [ "$x" = "$v" ] && return 0; done
  return 1
}

ROLE=() PROVIDER=() MODEL=()
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  [ -n "$line" ] || continue
  read -r -a f <<< "$line"
  first="${f[0]:-}"
  if [ "$lineno" -eq 1 ]; then
    [ "$first" = "schema" ] \
      || die2 "the delegated canonical binding does not open with a schema line"
    [ "${#f[@]}" -eq 2 ] \
      || die2 "the delegated canonical schema line is malformed (expected exactly 'schema <version>')"
    schema_version_supported "${f[1]}" \
      || die2 "the delegated canonical schema version is unsupported: ${f[1]}"
    continue
  fi
  [ "$first" = "bound" ] \
    || die2 "the delegated canonical binding carries a line that is neither the schema line nor a bound row: $line"
  [ "${#f[@]}" -eq 6 ] \
    || die2 "a delegated canonical bound row does not have exactly six fields: $line"
  role="${f[1]}"; provider="${f[2]}"; model="${f[3]}"
  if [ "${#ROLE[@]}" -gt 0 ]; then
    for seen in "${ROLE[@]}"; do
      [ "$seen" = "$role" ] \
        && die2 "the delegated canonical binding names role '$role' more than once"
    done
  fi
  ROLE+=("$role"); PROVIDER+=("$provider"); MODEL+=("$model")
done <<< "$BINDING_OUT"

# --- select the population: every row whose provider is claude -------------
POP_IDX=()
for ((i = 0; i < ${#ROLE[@]}; i++)); do
  if [ "${PROVIDER[$i]}" = "claude" ]; then
    POP_IDX+=("$i")
  fi
done
[ "${#POP_IDX[@]}" -ge 1 ] \
  || die2 "the claude-provider population derived from $CONF is empty (empty population) — refusing rather than reporting a vacuous 0"

# --- portable trim: leading + trailing whitespace, parameter expansion only
# (bash 3.2 safe, no external command) — ported from bin/check-provenance.sh.
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# --- the one comparison per population row that closes both directions -----
# (DP-2), plus the mandatory-presence rule (DP-4): a population row whose
# agent file carries zero `model:` lines is a violation, not a skip.
VIOLATION1=0
MSGS=()
for idx in "${POP_IDX[@]}"; do
  role="${ROLE[$idx]}"
  token="${MODEL[$idx]}"
  file="$AGENTS_DIR/$role.md"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    die2 "agent file missing or unreadable for role '$role': $file"
  fi
  n="$(grep -cE '^model:' "$file" || true)"
  if [ "$n" -gt 1 ]; then
    die2 "role '$role' agent file carries more than one model: line: $file"
  fi
  if [ "$n" -eq 0 ]; then
    VIOLATION1=1
    MSGS+=("mismatch: role '$role' carries no model: line at all (see #236 — the pin-retirement shape a continuous lock must redden, not accept): $file")
    continue
  fi
  raw="$(sed -nE 's/^model:[[:space:]]*(.*)$/\1/p' "$file")"
  val="$(trim "$raw")"
  if [ -z "$val" ]; then
    die2 "role '$role' model: line has an empty value: $file"
  fi
  if [ "$val" != "$token" ]; then
    VIOLATION1=1
    MSGS+=("mismatch: role '$role' pin '$val' disagrees with conf token '$token'")
  fi
done

if [ "$VIOLATION1" -eq 1 ]; then
  for m in "${MSGS[@]}"; do
    printf 'check-model-pins: %s\n' "$m" >&2 || true
  done
  exit 1
fi

printf 'check-model-pins: ok: %d claude-provider role(s) agree with the shipped conf (%s)\n' "${#POP_IDX[@]}" "$CONF" || true
exit 0
