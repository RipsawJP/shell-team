#!/usr/bin/env bash
# resolve-executor.sh — fail-closed executor resolution for one inner-loop
# role at a time (T-1057; GitHub issue #203;
# .shell-team/specs/T-1057-loop-integration.md).
#
# This is the FIRST consumer the binding layer (T-1054) and the adapter
# contract (T-1055) have ever had. It answers exactly one question for
# exactly one named role — which executor runs this role, and may it be
# invoked at all — and it WRITES NOTHING ANYWHERE, under any environment: no
# output-file flag exists, no environment variable, debug flag or hook adds
# a write path, and nothing it observes is ever written to.
#
# It resolves the EFFECTIVE binding as the resolved base directory's own
# binding.conf when that file exists, and the plugin-shipped
# templates/binding-default.conf otherwise — the latter resolved from this
# script's own installed directory, never from an adopter's working tree.
# Every act of parsing is delegated: to bin/check-binding.sh
# --print-binding for the binding, and to bin/check-adapter.sh
# --print-contract for the per-role board-transition authority table. The
# delegated canonical form is re-asserted (field count and schema version,
# exactly six rows one per role, every field read) before it is trusted —
# never accepted on its first token alone. Each bound adapter's own
# definition file, named by its adapter token under templates/adapters/,
# is read directly for the two fields this script's rules need (its
# `capability effort` declaration and its `carries board-transition`
# channel); neither is a grammar this script re-implements, since
# check-adapter.sh's own validation is a stricter internal-consistency
# check this script's two narrow reads do not depend on.
#
# Two normative rules (stated in docs/loop-engineering/task-envelope.md,
# byte-frozen there) are enforced HERE, at the point of resolution, before
# anything is invoked:
#   - the EFFORT rule: a non-"-" effort value the bound adapter's own
#     definition does not declare (capability effort unsupported, or a
#     value absent from its effort-value rows) is refused
#     capability-unsupported;
#   - the AUTHORITY rule: a role whose role-board-authority is writes or
#     proposes, bound to an adapter declaring carries board-transition
#     not-carried, is refused contract-violation.
#
# Executor availability is fail-closed for all six bindable roles, from a
# COMPILED-IN probe table keyed by provider token, exhaustive over the
# shipped provider allowlist: an out-of-process provider (its executor is a
# separate process reached by a bare first token) is probed with a
# read-only version query; an in-process provider (its executor IS the
# harness running this caller) makes no availability claim this script
# cannot ground — it prints the probe kind so the caller applies the
# branch that is grounded: the harness's own sub-agent invocation failure.
# A provider token with NO table entry at all is executor-unavailable,
# never assumed available.
#
# Usage:
#   resolve-executor.sh --role <role>
#     Resolve ONE named inner-loop role (tech-lead | pm-spec | engineer |
#     qa-verifier | codex-reviewer | ui-designer): the effective binding,
#     the two normative rules, and — for this mode only — the compiled-in
#     availability probe. On success, stdout is exactly one line:
#       resolved <role> <provider> <model> <effort|-> <adapter> <probe-kind>
#     where <probe-kind> is in-process or out-of-process.
#   resolve-executor.sh --print-resolved
#     Resolve all six roles (the effective binding and both normative
#     rules only — no availability probe is ever run in this mode, and it
#     makes no availability claim at all). CI's probe-free dogfood mode.
#     On success, stdout is one `resolved ...` line per role (no trailing
#     probe-kind field, since none was probed).
#   resolve-executor.sh --help
#
# Exit codes and refusal tokens (a closed set of five; every refusal is one
# token on stderr, a fixed exit code, and ZERO bytes on stdout):
#   usage (2)                  — a bad invocation: no mode, both modes
#                                 together, an unknown flag, a bare
#                                 positional argument, or a --role value
#                                 outside the six bindable roles.
#   binding-unresolved (2)     — the effective binding, the delegated
#                                 contract, or a bound adapter's definition
#                                 did not resolve to a well-formed,
#                                 trustworthy form.
#   capability-unsupported (1) — the effort rule refused.
#   contract-violation (1)     — the authority rule refused.
#   executor-unavailable (1)   — the compiled-in probe found no table entry
#                                 for the bound provider, or an
#                                 out-of-process probe could not observe its
#                                 executor. (--role mode only.)
#
# Nothing here composes an argv for an executor, calls a provider, or
# writes an envelope instance — this script decides WHETHER an invocation
# may proceed, never performs one.

set -euo pipefail

# =============================================================================
# Design notes (not part of --help's output — print_help stops reading this
# file's header at the first non-comment line below, i.e. at `set -euo
# pipefail` above; everything from here on is free to use any word at all).
#
# Threat model (identical to bin/check-binding.sh's, bin/check-adapter.sh's
# and bin/check-durability.sh's, for the identical reason): the operator and
# the working directory are TRUSTED (this repository's CLAUDE.md security
# invariant). What this defends against is accidents — a stray edit to a
# shipped adapter definition, a vendored install resolving to the wrong
# tree, a host binding an effort value no executor can honour, an adopter
# upgrading with no config at all — never a hostile operator forging a
# shipped file inside the plugin's own installation.
#
# This script never forwards bin/check-binding.sh's own registry-override
# testing affordance, and it delegates every act of parsing rather than
# re-implementing either sibling's grammar (issue #221, issue #225's
# requirement 1 closed in THIS consumer): the delegated `schema` line is
# judged by field count and supported version, never by its first token
# alone, and the delegated binding must carry exactly six `bound` rows, one
# per inner-loop role, with every field of every row actually read before
# it is trusted.
#
# Resolution is physical (`cd DIR && pwd -P`) at every self-location site,
# from the first commit — ported (bootstrap shape) from
# bin/check-binding.sh / bin/check-adapter.sh, themselves ported from
# bin/check-durability.sh / bin/check-provenance.sh. An ANCESTOR directory
# symlink (an adopter's `bin/` symlinked into the plugin's real `bin/` —
# ordinary vendoring, no hostile action) survives a plain `cd && pwd`
# untouched; `cd DIR && pwd -P` reports the OS-canonical path regardless of
# how many symlinks — final-component or ancestor — were crossed getting
# there.
#
# The compiled-in provider probe table is literal, bare TEXT assigned to a
# single-quoted multi-line shell string below (PROBE_TABLE_TEXT) — never a
# constructed array — so each row reads, in the actual bytes of this file,
# as a bare line starting with the token `probe-provider`. This is what
# keeps the table statically extractable and exhaustive-by-construction
# against the shipped provider allowlist (templates/binding-adapters.txt):
# a provider with no row here is unavailable, never assumed available.
#
# This script has no write path of any kind: no output-file flag, no
# environment variable, debug flag or hook that writes, and nothing it
# reads is ever written to. A test needing a mutated input builds one in a
# scratch COPY of the installed tree (bin/ + templates/) and runs the
# copied script from there — which additionally exercises the real
# $SCRIPT_DIR-relative resolution rather than a test-only override path
# this script does not have.
# =============================================================================

# --- classified refusal helper -----------------------------------------------
# Errexit-safe by construction (repo convention, T-096): the stderr write is
# `|| true`-guarded so a closed-stderr caller cannot turn the intended exit
# code into a bare errexit 1 before the real `exit "$2"` statement runs.
refuse() {  # $1 = token (closed 5-token set); $2 = exit code (1|2); $3 = message
  printf 'resolve-executor: %s: %s\n' "$1" "$3" >&2 || true
  exit "$2"
}
fail_usage() { refuse usage 2 "$1"; }

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported (bootstrap shape) from bin/check-binding.sh / bin/check-adapter.sh —
# every `pwd` below is `pwd -P` (physical), never the bare logical `pwd`.
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

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- fixed vocabulary --------------------------------------------------------
SIX_ROLES=(tech-lead pm-spec engineer qa-verifier codex-reviewer ui-designer)
SUPPORTED_SCHEMA_VERSIONS=(1)

role_in_six() {  # $1 = candidate role token
  local r="$1" x
  for x in "${SIX_ROLES[@]}"; do [ "$x" = "$r" ] && return 0; done
  return 1
}
schema_version_supported() {  # $1 = candidate version token
  local v="$1" x
  for x in "${SUPPORTED_SCHEMA_VERSIONS[@]}"; do [ "$x" = "$v" ] && return 0; done
  return 1
}

# --- compiled-in provider probe table (DP7) ----------------------------------
# One `probe-provider <provider> <kind>` row, optionally followed by a
# bare read-only probe command, per provider token the shipped allowlist
# declares — exhaustive by
# construction: a provider with no row here is executor-unavailable, never
# assumed available. `in-process` carries no probe command (the executor IS
# the harness running this caller; probing anything else would measure a
# different object). `out-of-process` carries a bare, read-only command
# this script never composes an argv around — it only checks the command
# names an observable binary and runs the fixed, literal probe as-is.
PROBE_TABLE_TEXT='
probe-provider claude in-process
probe-provider codex out-of-process codex --version
'

probe_kind_for_provider() {  # $1 = provider; stdout = kind; return 1 if no row
  local p="$1" line
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    [ "${f[0]:-}" = "probe-provider" ] || continue
    if [ "${f[1]:-}" = "$p" ]; then
      printf '%s\n' "${f[2]:-}"
      return 0
    fi
  done <<< "$PROBE_TABLE_TEXT"
  return 1
}
probe_check_cmd_for_provider() {  # $1 = provider; stdout = the declared probe command; return 1 if none
  local p="$1" line
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    [ "${f[0]:-}" = "probe-provider" ] || continue
    if [ "${f[1]:-}" = "$p" ]; then
      if [ "${#f[@]}" -gt 3 ]; then
        printf '%s\n' "${f[*]:3}"
        return 0
      fi
      return 1
    fi
  done <<< "$PROBE_TABLE_TEXT"
  return 1
}

# --- argument parsing --------------------------------------------------------
ROLE_ARG="" MODE=""
set_mode() {  # $1 = the new mode; refuses if a mode flag was already given
  [ -z "$MODE" ] || fail_usage "specify only one of --role or --print-resolved"
  MODE="$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)         print_help; exit 0 ;;
    --role)            [ "$#" -ge 2 ] || fail_usage "--role requires a value"; ROLE_ARG="$2"; set_mode role; shift 2 ;;
    --print-resolved)  set_mode print-resolved; shift ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"
[ -n "$MODE" ] || fail_usage "specify exactly one of --role <role> or --print-resolved (see --help)"
if [ "$MODE" = "role" ]; then
  role_in_six "$ROLE_ARG" \
    || fail_usage "unknown role: $ROLE_ARG (expected one of: ${SIX_ROLES[*]})"
fi

# --- resolve the sibling path resolver ---------------------------------------
TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"
[ -f "$TEAM_PATHS" ] && [ -r "$TEAM_PATHS" ] \
  || fail_usage "cannot resolve operating paths (team-paths.sh missing or unreadable next to resolve-executor.sh)"
BASE_DIR="$(bash "$TEAM_PATHS" --get base 2>/dev/null)" \
  || fail_usage "team-paths.sh could not resolve the base directory"
BASE_DIR="${BASE_DIR%/}"

# --- the effective binding: host config first, plugin default second (DP3) --
# TEMPLATES_ROOT is composed from SCRIPT_DIR (already physical, above) with
# `pwd -P` again here — SCRIPT_DIR is a plain string at this point, and
# `cd "$SCRIPT_DIR/.." && pwd -P` re-canonicalizes rather than assuming the
# one-level-up traversal itself introduces no new symlink to resolve. This
# NEVER reads from the current working directory, so a decoy
# templates/binding-default.conf in an adopter's own tree cannot substitute
# a binding.
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || fail_usage "cannot resolve the templates directory (one level above resolve-executor.sh's own installed directory)"
HOST_CONFIG="$BASE_DIR/binding.conf"
if [ -f "$HOST_CONFIG" ]; then
  CONFIG_PATH="$HOST_CONFIG"
else
  CONFIG_PATH="$TEMPLATES_ROOT/templates/binding-default.conf"
fi

# --- delegate binding parsing to the sibling validator (DP2) -----------------
if ! BINDING_OUT="$(bash "$SCRIPT_DIR/check-binding.sh" --config "$CONFIG_PATH" --print-binding 2>/dev/null)"; then
  refuse binding-unresolved 2 "the effective binding at $CONFIG_PATH did not resolve"
fi
[ -n "$BINDING_OUT" ] \
  || refuse binding-unresolved 2 "the effective binding at $CONFIG_PATH printed no output"

# --- re-assert the delegated canonical form before trusting it (DP2/AC8) ----
# Judged by content — field count AND supported schema version — never by
# the schema line's first token alone (issue #225's requirement 1, closed
# HERE): exactly one schema line first, exactly six bound rows one per
# inner-loop role, no other non-blank line, every field of every row read.
BOUND_ROLE=() BOUND_PROVIDER=() BOUND_MODEL=() BOUND_EFFORT=() BOUND_ADAPTER=()
parse_canonical_binding() {  # $1 = the delegated canonical text
  local text="$1" lineno=0 line first role provider model effort adapter seen
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    first="${f[0]:-}"
    if [ "$lineno" -eq 1 ]; then
      [ "$first" = "schema" ] \
        || refuse binding-unresolved 2 "the delegated canonical binding does not open with a schema line"
      [ "${#f[@]}" -eq 2 ] \
        || refuse binding-unresolved 2 "the delegated canonical schema line is malformed (expected exactly 'schema <version>')"
      schema_version_supported "${f[1]}" \
        || refuse binding-unresolved 2 "the delegated canonical schema version is unsupported: ${f[1]}"
      continue
    fi
    [ "$first" = "bound" ] \
      || refuse binding-unresolved 2 "the delegated canonical binding carries a line that is neither the schema line nor a bound row: $line"
    [ "${#f[@]}" -eq 6 ] \
      || refuse binding-unresolved 2 "a delegated canonical bound row does not have exactly six fields: $line"
    role="${f[1]}" provider="${f[2]}" model="${f[3]}" effort="${f[4]}" adapter="${f[5]}"
    role_in_six "$role" \
      || refuse binding-unresolved 2 "a delegated canonical bound row names a role outside the six inner-loop roles: $role"
    if [ "${#BOUND_ROLE[@]}" -gt 0 ]; then
      for seen in "${BOUND_ROLE[@]}"; do
        [ "$seen" = "$role" ] \
          && refuse binding-unresolved 2 "the delegated canonical binding names role '$role' more than once"
      done
    fi
    BOUND_ROLE+=("$role"); BOUND_PROVIDER+=("$provider"); BOUND_MODEL+=("$model")
    BOUND_EFFORT+=("$effort"); BOUND_ADAPTER+=("$adapter")
  done <<< "$text"
  [ "${#BOUND_ROLE[@]}" -ge 1 ] \
    || refuse binding-unresolved 2 "the delegated canonical binding carries no schema line and no bound rows"
  [ "${#BOUND_ROLE[@]}" -eq 6 ] \
    || refuse binding-unresolved 2 "the delegated canonical binding does not carry exactly six bound rows (found ${#BOUND_ROLE[@]})"
  local r found
  for r in "${SIX_ROLES[@]}"; do
    found=0
    for seen in "${BOUND_ROLE[@]}"; do [ "$seen" = "$r" ] && { found=1; break; }; done
    [ "$found" -eq 1 ] \
      || refuse binding-unresolved 2 "the delegated canonical binding is missing a bound row for role: $r"
  done
}
parse_canonical_binding "$BINDING_OUT"

# --- delegate contract parsing to the sibling validator (DP2/DP4) -----------
if ! CONTRACT_OUT="$(bash "$SCRIPT_DIR/check-adapter.sh" --print-contract 2>/dev/null)"; then
  refuse binding-unresolved 2 "the task-envelope contract registry did not resolve"
fi
[ -n "$CONTRACT_OUT" ] \
  || refuse binding-unresolved 2 "the task-envelope contract registry printed no content"

role_board_authority_for() {  # $1 = role; stdout = writes|proposes|none; return 1 if malformed/absent
  local role="$1" n val
  n="$(printf '%s\n' "$CONTRACT_OUT" | awk -v r="$role" '$1=="role-board-authority" && $2==r { c++ } END { print c+0 }')" || return 1
  [ "$n" = "1" ] || return 1
  val="$(printf '%s\n' "$CONTRACT_OUT" | awk -v r="$role" '$1=="role-board-authority" && $2==r { print $3 }')" || return 1
  case "$val" in
    writes|proposes|none) printf '%s\n' "$val" ;;
    *) return 1 ;;
  esac
}

# --- read one bound adapter's definition directly (its two relevant fields) -
# Not a delegated grammar: check-adapter.sh's own definition validator
# enforces an internal consistency (effort-mechanism/effort-value rows must
# agree with the capability declaration) this script's two narrow reads do
# not depend on and must not inherit — a mutated definition that is
# "inconsistent" by that stricter rule is still a legal input for the two
# fields this script actually reads.
capability_effort_for() {  # $1 = definition path; stdout = supported|unsupported; return 1 if malformed/absent
  local path="$1" n val
  n="$(awk '$1=="capability" && $2=="effort" { c++ } END { print c+0 }' "$path")" || return 1
  [ "$n" = "1" ] || return 1
  val="$(awk '$1=="capability" && $2=="effort" { print $3 }' "$path")" || return 1
  case "$val" in
    supported|unsupported) printf '%s\n' "$val" ;;
    *) return 1 ;;
  esac
}
carries_board_transition_channel() {  # $1 = definition path; stdout = channel; return 1 if malformed/absent
  local path="$1" n val
  n="$(awk '$1=="carries" && $2=="board-transition" { c++ } END { print c+0 }' "$path")" || return 1
  [ "$n" = "1" ] || return 1
  val="$(awk '$1=="carries" && $2=="board-transition" { print $3 }' "$path")" || return 1
  [[ "$val" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
  printf '%s\n' "$val"
}
effort_value_declared() {  # $1 = definition path; $2 = effort value; return 0 if declared among effort-value rows
  local path="$1" val="$2"
  awk -v v="$val" '$1=="effort-value" && $2==v { found=1 } END { exit !found }' "$path"
}

# --- lookup + both normative rules for one role (DP4) ------------------------
# Sets RESOLVED_PROVIDER/RESOLVED_MODEL/RESOLVED_EFFORT/RESOLVED_ADAPTER on
# success. A plain function call (never inside a command substitution), so
# every refuse() below actually terminates this whole process.
lookup_and_validate_role() {  # $1 = role
  local role="$1" i idx=-1 authority def_path carries_bt cap
  for ((i = 0; i < ${#BOUND_ROLE[@]}; i++)); do
    if [ "${BOUND_ROLE[$i]}" = "$role" ]; then idx=$i; break; fi
  done
  [ "$idx" -ge 0 ] \
    || refuse binding-unresolved 2 "the delegated canonical binding carries no row for role: $role"
  RESOLVED_PROVIDER="${BOUND_PROVIDER[$idx]}"
  RESOLVED_MODEL="${BOUND_MODEL[$idx]}"
  RESOLVED_EFFORT="${BOUND_EFFORT[$idx]}"
  RESOLVED_ADAPTER="${BOUND_ADAPTER[$idx]}"

  if ! authority="$(role_board_authority_for "$role")"; then
    refuse binding-unresolved 2 "the delegated contract does not carry a well-formed role-board-authority row for role: $role"
  fi

  def_path="$TEMPLATES_ROOT/templates/adapters/$RESOLVED_ADAPTER.txt"
  [ -f "$def_path" ] && [ -r "$def_path" ] \
    || refuse binding-unresolved 2 "cannot read the bound adapter's definition: $def_path"

  if ! carries_bt="$(carries_board_transition_channel "$def_path")"; then
    refuse binding-unresolved 2 "the adapter definition does not carry a well-formed board-transition channel declaration: $def_path"
  fi
  # The AUTHORITY rule: a role that writes or proposes a board transition,
  # bound to an adapter with no return path for it, is a contradiction.
  if [ "$carries_bt" = "not-carried" ]; then
    case "$authority" in
      writes|proposes)
        refuse contract-violation 1 "role '$role' has role-board-authority '$authority' but its bound adapter '$RESOLVED_ADAPTER' declares carries board-transition not-carried"
        ;;
    esac
  fi

  # The EFFORT rule: an unset ("-") effort always resolves — it means the
  # provider or model default. Any other value must be one the bound
  # adapter's own definition actually declares.
  if [ "$RESOLVED_EFFORT" != "-" ]; then
    if ! cap="$(capability_effort_for "$def_path")"; then
      refuse binding-unresolved 2 "the adapter definition does not carry a well-formed capability effort declaration: $def_path"
    fi
    [ "$cap" = "supported" ] \
      || refuse capability-unsupported 1 "role '$role' requests effort '$RESOLVED_EFFORT' but its bound adapter '$RESOLVED_ADAPTER' declares capability effort unsupported"
    effort_value_declared "$def_path" "$RESOLVED_EFFORT" \
      || refuse capability-unsupported 1 "role '$role' requests effort '$RESOLVED_EFFORT', which its bound adapter '$RESOLVED_ADAPTER' does not declare among its effort-value rows"
  fi
}

# --- mode dispatch ------------------------------------------------------------
# Rows are only ever emitted AFTER every role this invocation touches has
# fully resolved — never streamed role-by-role — so a refusal partway
# through --print-resolved's six roles still produces ZERO bytes on stdout.
case "$MODE" in
  print-resolved)
    ROWS=()
    for role in "${SIX_ROLES[@]}"; do
      lookup_and_validate_role "$role"
      ROWS+=("resolved $role $RESOLVED_PROVIDER $RESOLVED_MODEL $RESOLVED_EFFORT $RESOLVED_ADAPTER")
    done
    printf '%s\n' "${ROWS[@]}"
    ;;
  role)
    lookup_and_validate_role "$ROLE_ARG"
    # --- executor availability (DP7), --role mode ONLY: --print-resolved
    # never probes and makes no availability claim at all (DP7a).
    if ! PROBE_KIND="$(probe_kind_for_provider "$RESOLVED_PROVIDER")"; then
      refuse executor-unavailable 1 "no compiled-in probe-table entry for provider: $RESOLVED_PROVIDER"
    fi
    case "$PROBE_KIND" in
      in-process)
        # The executor IS the harness running this caller. This script
        # makes no availability claim it cannot ground: it prints the
        # probe kind so the caller applies the branch that IS grounded —
        # the harness's own sub-agent invocation failure.
        : ;;
      out-of-process)
        if ! PROBE_CMD="$(probe_check_cmd_for_provider "$RESOLVED_PROVIDER")"; then
          refuse executor-unavailable 1 "no probe command declared for out-of-process provider: $RESOLVED_PROVIDER"
        fi
        PROBE_CMD_ARR=()
        read -r -a PROBE_CMD_ARR <<< "$PROBE_CMD"
        [ "${#PROBE_CMD_ARR[@]}" -ge 1 ] \
          || refuse executor-unavailable 1 "malformed probe command declared for provider: $RESOLVED_PROVIDER"
        command -v "${PROBE_CMD_ARR[0]}" >/dev/null 2>&1 \
          || refuse executor-unavailable 1 "the out-of-process executor for provider '$RESOLVED_PROVIDER' is not observable on PATH (probe: $PROBE_CMD)"
        "${PROBE_CMD_ARR[@]}" >/dev/null 2>&1 \
          || refuse executor-unavailable 1 "the out-of-process executor for provider '$RESOLVED_PROVIDER' failed its read-only probe ($PROBE_CMD)"
        ;;
      *)
        refuse executor-unavailable 1 "unrecognized probe kind '$PROBE_KIND' declared for provider: $RESOLVED_PROVIDER"
        ;;
    esac
    printf 'resolved %s %s %s %s %s %s\n' "$ROLE_ARG" "$RESOLVED_PROVIDER" "$RESOLVED_MODEL" "$RESOLVED_EFFORT" "$RESOLVED_ADAPTER" "$PROBE_KIND"
    ;;
esac
exit 0
