#!/usr/bin/env bash
# check-binding.sh — fail-closed validator and run-scoped integrity
# primitives for the host-authored executor binding config (T-1054;
# GitHub issue #203; .shell-team/specs/T-1054-binding-config.md).
#
# The binding config assigns which executor (provider + model + effort +
# adapter) runs each of the six inner-loop roles. This script is the only
# thing that reads it: every refusal is one token from a closed set with a
# fixed exit code, and no input this script cannot fully evaluate is ever
# accepted. The config is never sourced, evaluated as code, or executed —
# every field is a bare token, never a shell command.
#
# Grammar: a required `schema <version>` line, followed by exactly one
# `bind <role> <provider> <model> <effort|-> <adapter>` row for each of
# the six inner-loop roles (tech-lead, pm-spec, engineer, qa-verifier,
# codex-reviewer, ui-designer) — no more, no fewer. `#` comment lines and
# blank lines are skipped; row order and extra whitespace do not matter.
#
# Usage:
#   check-binding.sh [--config PATH] [--adapters PATH]
#     Validate the binding config. With no --config, the file at
#     <base>/binding.conf is validated, where <base> comes from
#     bin/team-paths.sh --get base. Exit 0 = valid; non-zero = a refusal
#     token on stderr (see below).
#   check-binding.sh [--config PATH] [--adapters PATH] --print-binding
#     Validate, then print the canonical resolved binding on stdout: a
#     `schema` line followed by one `bound <role> <provider> <model>
#     <effort|-> <adapter>` row per role, sorted by role. Nothing is
#     printed on a refusal.
#   check-binding.sh [--config PATH] [--adapters PATH] --print-lock
#     Validate, then print a self-describing lock document (the canonical
#     binding plus its git hash-object hash) on stdout. Nothing is printed
#     on a refusal.
#   check-binding.sh --verify --lock PATH --config PATH [--adapters PATH]
#     Re-derive the named config's canonical binding and compare it to a
#     lock's recorded hash and path, without writing anything anywhere.
#     The lock's own embedded body is also cross-checked against its
#     recorded hash (a `lock-structural` refusal on disagreement), so a
#     lock whose printed rows have been hand-edited independently of the
#     hash they sit beside is caught, not just trusted as a human display.
#   check-binding.sh --adapters PATH   (a testing affordance; the adapter
#     allowlist otherwise resolves next to this script's own installation)
#   check-binding.sh --help
#
# Every value-taking flag (--config, --adapters, --lock) requires a
# non-empty value: an explicit empty string ('') is refused `usage`, the
# same as an omitted operand. That is distinct from leaving the flag off
# entirely — with no --config at all, <base>/binding.conf is still what
# gets validated (see above), and with no --adapters at all, the registry
# next to this script's own installation is still what gets loaded;
# neither of those omitted-flag paths is affected by this refusal.
#
# Exit codes: 0 = valid/verified. 1 = a content refusal (an unknown or
# duplicated role, a malformed row, a value that changed since a lock was
# taken, ...). 2 = the input could not be evaluated at all (a missing
# file, a bad flag, an explicit empty flag value, a malformed registry or
# lock). Every refusal prints exactly one token, from a closed set, to
# stderr.

set -euo pipefail

# =============================================================================
# Design notes (not part of --help's output — print_help stops reading this
# file's header at the first non-comment line below, i.e. at `set -euo
# pipefail` above; everything from here on is free to use any word at all).
#
# Refusal matrix (token: exit code — condition), the CLOSED set every
# non-zero exit comes from (spec `## Refusal matrix`):
#   missing-config (2), missing-schema (1), duplicate-schema (1),
#   schema-not-first (1), unsupported-schema (1), unparseable-line (1),
#   bad-token (1), unknown-role (1), duplicate-role (1), missing-role (1),
#   unknown-provider (1), unknown-adapter (1), provider-adapter-mismatch (1),
#   registry-unreadable (2), registry-malformed (2), lock-missing (2),
#   lock-structural (2), path-mismatch (1), binding-changed (1), usage (2).
#
# Validation order (DP-level, per-line refusals win over set completeness):
# a two-pass read of the config. Pass 1 establishes schema-level facts only
# (count, position relative to any `bind` row, field count, version) so
# missing/duplicate/not-first/unsupported can each be judged in isolation.
# Pass 2 walks every remaining substantive line in file order, validating
# grammar (unparseable-line), character class (bad-token), role membership
# (unknown-role) and role uniqueness (duplicate-role) as each line is
# reached — a line-level refusal exits immediately, before the aggregate
# six-role completeness check (missing-role) ever runs. This ordering is
# what makes an unknown replacement role win over the role it displaced
# being reported merely absent (spec AC5).
#
# The adapter registry (templates/binding-adapters.txt, or --adapters for
# testing) is loaded once, resolved from this script's own installed
# directory — never from the current working directory — so a decoy file
# in an adopter's tree can never legitimize an adapter or provider token.
#
# The canonical resolved binding (DP7) is what gets hashed, never the
# config's own bytes: a `schema` line plus one `bound <role> <provider>
# <model> <effort|-> <adapter>` row per role, single-space delimited,
# LC_ALL=C-sorted by role. A comment reflow, a blank-line change, a row
# reorder, extra intra-row whitespace or a CRLF conversion cannot move the
# hash; any bound value change does. print_canonical() is the single
# normalization pipeline both --print-binding and the hash computation
# read from (DP8/DP17) — there is no second implementation of it anywhere
# in this file that could silently drift from the first.
#
# The lock document is self-describing and read-only: --verify never
# writes to the lock or the config, and a `path-mismatch` refusal is a
# pure string comparison against the --config value given — the lock's
# recorded config-path is never opened as a file. The lock's config-path
# and binding-hash lines are located by matching, not by position, so a
# lock with those two lines in either order verifies identically.
#
# Threat model (identical to bin/check-durability.sh's, for the identical
# reason): the operator and the working directory are TRUSTED (this
# repository's CLAUDE.md security invariant). What this defends against is
# accidents — a stray edit, a mis-resolved base directory, a config edited
# mid-run — never a hostile operator forging a lock or overriding a shell
# builtin. That hardening belongs to a separate issue and ships none of it
# here.
# =============================================================================

# --- classified refusal helper -----------------------------------------------
# Errexit-safe by construction (repo convention, T-096): the stderr write is
# `|| true`-guarded so a closed-stderr caller cannot turn the intended exit
# code into a bare errexit 1 before the real `exit "$2"` statement runs.
refuse() {  # $1 = token (closed refusal-matrix set); $2 = exit code (1|2); $3 = message
  printf 'check-binding: %s: %s\n' "$1" "$3" >&2 || true
  exit "$2"
}
fail_usage() { refuse usage 2 "$1"; }

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported (bootstrap shape) from bin/check-durability.sh, itself ported from
# bin/check-provenance.sh (2026-06-15/2026-07-14 lesson: reuse the proven
# symlink-safe resolver instead of hand-rolling one) — with one deliberate
# departure from that ported shape: every `pwd` below is `pwd -P` (physical,
# every symlink resolved), never the bare logical `pwd` the ported original
# used. A T-1054 Codex review round reproduced that the loop above only
# follows a symlink on the FINAL path component (`BASH_SOURCE[0]` itself);
# an ANCESTOR directory being a symlink (an adopter's `bin/` symlinked into
# the plugin's real `bin/` — ordinary vendoring, no hostile action) survived
# a plain `cd && pwd` untouched, so `SCRIPT_DIR` silently resolved inside the
# ADOPTER's tree, and the adapter-registry resolution below it (composed
# from `SCRIPT_DIR`) then read the adopter's own `templates/binding-adapters.txt`
# instead of the plugin's shipped one — defeating DP6's registry-identity
# guarantee. `cd DIR && pwd -P` (no `-P` on `cd` itself needed) reports the
# OS-canonical path of wherever `cd` actually landed, regardless of how many
# symlinks — final-component or ancestor — were crossed getting there; this
# is the same fix shape `bin/check-board-headings.sh` and
# `bin/codex-capture.sh` already use for the identical reason.
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
ROLE_RE='^[a-z][a-z0-9-]*$'
MODEL_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
MAXLEN=64
SIX_ROLES=(tech-lead pm-spec engineer qa-verifier codex-reviewer ui-designer)
SUPPORTED_SCHEMA_VERSIONS=(1)
SUPPORTED_LOCK_VERSIONS=(1)

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
lock_version_supported() {  # $1 = candidate version token
  local v="$1" x
  for x in "${SUPPORTED_LOCK_VERSIONS[@]}"; do [ "$x" = "$v" ] && return 0; done
  return 1
}

# --- argument parsing --------------------------------------------------------
CONFIG_ARG="" ADAPTERS_ARG="" LOCK_ARG=""
MODE="validate"
set_mode() {  # $1 = the new mode; refuses if a mode flag was already given
  [ "$MODE" = "validate" ] || fail_usage "specify only one of --print-binding, --print-lock or --verify"
  MODE="$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)       print_help; exit 0 ;;
    --config)        [ "$#" -ge 2 ] || fail_usage "--config requires a value"
                     [ -n "$2" ] || fail_usage "--config requires a non-empty value"
                     CONFIG_ARG="$2"; shift 2 ;;
    --adapters)      [ "$#" -ge 2 ] || fail_usage "--adapters requires a value"
                     [ -n "$2" ] || fail_usage "--adapters requires a non-empty value"
                     ADAPTERS_ARG="$2"; shift 2 ;;
    --lock)          [ "$#" -ge 2 ] || fail_usage "--lock requires a value"
                     [ -n "$2" ] || fail_usage "--lock requires a non-empty value"
                     LOCK_ARG="$2"; shift 2 ;;
    --print-binding) set_mode print-binding; shift ;;
    --print-lock)    set_mode print-lock; shift ;;
    --verify)        set_mode verify; shift ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

if [ "$MODE" = "verify" ]; then
  [ -n "$LOCK_ARG" ]   || fail_usage "--verify requires --lock PATH"
  [ -n "$CONFIG_ARG" ] || fail_usage "--verify requires --config PATH"
else
  [ -z "$LOCK_ARG" ] || fail_usage "--lock is only valid together with --verify"
fi

# --- resolve the sibling path resolver ---------------------------------------
TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"
[ -f "$TEAM_PATHS" ] && [ -r "$TEAM_PATHS" ] \
  || fail_usage "cannot resolve operating paths (team-paths.sh missing or unreadable next to check-binding.sh)"
get_path() {  # $1 = team-paths.sh --get key
  bash "$TEAM_PATHS" --get "$1" 2>/dev/null || fail_usage "team-paths.sh could not resolve key: $1"
}

# --- resolve + load the adapter registry (every mode reaches this point) ----
# TEMPLATES_ROOT is composed from SCRIPT_DIR (already physical, above) with
# `pwd -P` again here — SCRIPT_DIR is a plain string at this point, and
# `cd "$SCRIPT_DIR/.." && pwd -P` re-canonicalizes rather than assuming the
# one-level-up traversal itself introduces no new symlink to resolve.
if [ -n "$ADAPTERS_ARG" ]; then
  REGISTRY="$ADAPTERS_ARG"
else
  TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
    || fail_usage "cannot resolve the templates directory (one level above check-binding.sh's own installed directory)"
  REGISTRY="$TEMPLATES_ROOT/templates/binding-adapters.txt"
fi
[ -f "$REGISTRY" ] && [ -r "$REGISTRY" ] \
  || refuse registry-unreadable 2 "cannot read the adapter registry: $REGISTRY"

REG_ADAPTER=()
REG_PROVIDER=()
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  read -r -a f <<< "$line"
  if [ "${#f[@]}" -ne 2 ]; then
    refuse registry-malformed 2 "adapter registry row is not exactly two whitespace-delimited tokens: $line"
  fi
  reg_a="${f[0]}" reg_p="${f[1]}"
  if ! [[ "$reg_a" =~ $ROLE_RE ]] || [ "${#reg_a}" -gt "$MAXLEN" ]; then
    refuse registry-malformed 2 "adapter registry adapter token is malformed: $reg_a"
  fi
  if ! [[ "$reg_p" =~ $ROLE_RE ]] || [ "${#reg_p}" -gt "$MAXLEN" ]; then
    refuse registry-malformed 2 "adapter registry provider token is malformed: $reg_p"
  fi
  if [ "${#REG_ADAPTER[@]}" -gt 0 ]; then
    for existing in "${REG_ADAPTER[@]}"; do
      if [ "$existing" = "$reg_a" ]; then
        refuse registry-malformed 2 "adapter token registered more than once: $reg_a"
      fi
    done
  fi
  REG_ADAPTER+=("$reg_a")
  REG_PROVIDER+=("$reg_p")
done < "$REGISTRY"

adapter_known() {  # $1 = adapter token
  local x="$1" e
  if [ "${#REG_ADAPTER[@]}" -gt 0 ]; then
    for e in "${REG_ADAPTER[@]}"; do [ "$e" = "$x" ] && return 0; done
  fi
  return 1
}
provider_known() {  # $1 = provider token
  local x="$1" e
  if [ "${#REG_PROVIDER[@]}" -gt 0 ]; then
    for e in "${REG_PROVIDER[@]}"; do [ "$e" = "$x" ] && return 0; done
  fi
  return 1
}
adapter_registered_provider() {  # $1 = adapter token; prints its registered provider
  local x="$1" i
  if [ "${#REG_ADAPTER[@]}" -gt 0 ]; then
    for ((i = 0; i < ${#REG_ADAPTER[@]}; i++)); do
      if [ "${REG_ADAPTER[$i]}" = "$x" ]; then
        printf '%s\n' "${REG_PROVIDER[$i]}"
        return 0
      fi
    done
  fi
  return 1
}

# --- validate_config: the whole per-file validation, two passes -------------
# Sets BIND_ROLE/BIND_PROVIDER/BIND_MODEL/BIND_EFFORT/BIND_ADAPTER (indexed,
# file order) and CANON_LINES (the 7-line canonical form, schema line first)
# on success. Every failure exits the whole process via refuse() — this is
# never called inside a subshell/command-substitution, so that exit always
# propagates.
validate_config() {  # $1 = config path (already confirmed readable by the caller)
  local cfg="$1"

  # Pass 1: schema-level facts only.
  local schema_count=0 schema_lineno=0 schema_fieldcount=0 schema_version=""
  local bind_before_schema=0 lineno=0 line first
  while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    read -r -a f <<< "$line"
    first="${f[0]:-}"
    if [ "$first" = "schema" ]; then
      schema_count=$((schema_count + 1))
      schema_lineno="$lineno"
      schema_fieldcount="${#f[@]}"
      if [ "${#f[@]}" -ge 2 ]; then schema_version="${f[1]}"; else schema_version=""; fi
    elif [ "$first" = "bind" ] && [ "$schema_count" -eq 0 ]; then
      bind_before_schema=1
    fi
  done < "$cfg"

  [ "$schema_count" -ge 1 ] || refuse missing-schema 1 "no schema line found in $cfg"
  [ "$schema_count" -le 1 ] || refuse duplicate-schema 1 "more than one schema line found in $cfg"
  [ "$schema_fieldcount" -eq 2 ] || refuse unparseable-line 1 "malformed schema line (expected exactly 'schema <version>') in $cfg"
  [ "$bind_before_schema" -eq 0 ] || refuse schema-not-first 1 "a bind row precedes the schema line in $cfg"
  schema_version_supported "$schema_version" \
    || refuse unsupported-schema 1 "unsupported schema version '$schema_version' in $cfg"

  # Pass 2: every remaining substantive line, in file order.
  BIND_ROLE=() BIND_PROVIDER=() BIND_MODEL=() BIND_EFFORT=() BIND_ADAPTER=()
  BOUND_LINES=()
  local role provider model effort adapter seen reg_provider
  lineno=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [ "$lineno" -eq "$schema_lineno" ] && continue
    read -r -a f <<< "$line"
    first="${f[0]:-}"
    if [ "$first" != "bind" ]; then
      refuse unparseable-line 1 "a line's first field is neither 'schema' nor 'bind': $line"
    fi
    if [ "${#f[@]}" -ne 6 ]; then
      refuse unparseable-line 1 "a bind row must have exactly six fields (bind role provider model effort adapter): $line"
    fi
    role="${f[1]}" provider="${f[2]}" model="${f[3]}" effort="${f[4]}" adapter="${f[5]}"

    if ! [[ "$role" =~ $ROLE_RE ]] || [ "${#role}" -gt "$MAXLEN" ]; then
      refuse bad-token 1 "malformed role token: $role"
    fi
    if ! [[ "$provider" =~ $ROLE_RE ]] || [ "${#provider}" -gt "$MAXLEN" ]; then
      refuse bad-token 1 "malformed provider token: $provider"
    fi
    if ! [[ "$model" =~ $MODEL_RE ]] || [ "${#model}" -gt "$MAXLEN" ]; then
      refuse bad-token 1 "malformed model token: $model"
    fi
    if [ "$effort" != "-" ]; then
      if ! [[ "$effort" =~ $ROLE_RE ]] || [ "${#effort}" -gt "$MAXLEN" ]; then
        refuse bad-token 1 "malformed effort token: $effort"
      fi
    fi
    if ! [[ "$adapter" =~ $ROLE_RE ]] || [ "${#adapter}" -gt "$MAXLEN" ]; then
      refuse bad-token 1 "malformed adapter token: $adapter"
    fi

    role_in_six "$role" || refuse unknown-role 1 "role is not one of the six inner-loop roles: $role"

    if [ "${#BIND_ROLE[@]}" -gt 0 ]; then
      for seen in "${BIND_ROLE[@]}"; do
        if [ "$seen" = "$role" ]; then
          refuse duplicate-role 1 "role bound more than once: $role"
        fi
      done
    fi

    adapter_known "$adapter"   || refuse unknown-adapter 1 "adapter is not in the adapter registry: $adapter"
    provider_known "$provider" || refuse unknown-provider 1 "provider is not in the adapter registry: $provider"
    reg_provider="$(adapter_registered_provider "$adapter")" \
      || refuse unknown-adapter 1 "adapter is not in the adapter registry: $adapter"
    if [ "$reg_provider" != "$provider" ]; then
      refuse provider-adapter-mismatch 1 "adapter '$adapter' is registered with provider '$reg_provider', not '$provider'"
    fi

    BIND_ROLE+=("$role")
    BIND_PROVIDER+=("$provider")
    BIND_MODEL+=("$model")
    BIND_EFFORT+=("$effort")
    BIND_ADAPTER+=("$adapter")
    BOUND_LINES+=("bound $role $provider $model $effort $adapter")
  done < "$cfg"

  local r found
  for r in "${SIX_ROLES[@]}"; do
    found=0
    if [ "${#BIND_ROLE[@]}" -gt 0 ]; then
      for seen in "${BIND_ROLE[@]}"; do
        if [ "$seen" = "$r" ]; then found=1; break; fi
      done
    fi
    [ "$found" -eq 1 ] || refuse missing-role 1 "role is not bound: $r"
  done

  CANON_LINES=("schema $schema_version")
  if [ "${#BOUND_LINES[@]}" -gt 0 ]; then
    local sorted_text sorted
    sorted_text="$(printf '%s\n' "${BOUND_LINES[@]}" | LC_ALL=C sort)"
    while IFS= read -r sorted || [ -n "$sorted" ]; do
      [ -n "$sorted" ] && CANON_LINES+=("$sorted")
    done <<< "$sorted_text"
  fi
}

print_canonical() {  # the ONE normalization pipeline --print-binding and the hash both read
  printf '%s\n' "${CANON_LINES[@]}"
}
canonical_hash() {
  print_canonical | git hash-object --stdin
}

# --- lock parsing (structural only; field lookup by pattern, not position) --
read_lock() {  # $1 = lock path (already confirmed readable by the caller)
  local lockpath="$1"
  local -a lock_lines=()
  local raw
  while IFS= read -r raw || [ -n "$raw" ]; do
    lock_lines+=("${raw%$'\r'}")
  done < "$lockpath"
  local n="${#lock_lines[@]}"
  [ "$n" -ge 1 ] || refuse lock-structural 2 "lock file is empty: $lockpath"
  local first="${lock_lines[0]}"
  local last="${lock_lines[$((n - 1))]}"
  if [[ "$first" =~ ^binding-lock\ ([0-9]+)$ ]]; then
    lock_version_supported "${BASH_REMATCH[1]}" \
      || refuse lock-structural 2 "unsupported lock version: ${BASH_REMATCH[1]}"
  else
    refuse lock-structural 2 "lock file does not open with a recognized 'binding-lock <version>' line: $lockpath"
  fi
  [ "$last" = "binding-lock-end" ] \
    || refuse lock-structural 2 "lock file does not terminate with 'binding-lock-end': $lockpath"

  local cp_count=0 bh_count=0 l cp_index=-1 bh_index=-1 idx=0
  LOCK_CONFIG_PATH="" LOCK_HASH=""
  for l in "${lock_lines[@]}"; do
    case "$l" in
      config-path\ *)
        cp_count=$((cp_count + 1))
        cp_index="$idx"
        LOCK_CONFIG_PATH="${l#config-path }"
        ;;
    esac
    if [[ "$l" =~ ^binding-hash\ ([0-9a-f]{40})$ ]]; then
      bh_count=$((bh_count + 1))
      bh_index="$idx"
      LOCK_HASH="${BASH_REMATCH[1]}"
    fi
    idx=$((idx + 1))
  done
  [ "$cp_count" -eq 1 ] \
    || refuse lock-structural 2 "lock file must carry exactly one config-path line (found $cp_count): $lockpath"
  [ "$bh_count" -eq 1 ] \
    || refuse lock-structural 2 "lock file must carry exactly one well-formed binding-hash line (found $bh_count): $lockpath"

  # --- embedded-body cross-check (T-1106, issue #219) ------------------------
  # The body is defined BY EXCLUSION — every lock line minus the first line,
  # minus the located config-path line, minus the located binding-hash line
  # and minus the terminator, order preserved — never positionally (e.g.
  # "everything after binding-hash"), because the two header fields can
  # appear in either order (cb-lock-fields-reordered) and a positional
  # definition would swallow config-path into the body when it follows
  # binding-hash. Placed here, after the cp_count/bh_count assertions above
  # and before this function returns to the mode dispatch's own
  # path-mismatch/binding-changed comparisons, so token precedence is
  # untouched (Non-goals; spec AC3).
  local -a body_lines=()
  local i
  for ((i = 0; i < n; i++)); do
    if [ "$i" -eq 0 ] || [ "$i" -eq "$((n - 1))" ] || [ "$i" -eq "$cp_index" ] || [ "$i" -eq "$bh_index" ]; then
      continue
    fi
    body_lines+=("${lock_lines[$i]}")
  done
  local body_hash
  if [ "${#body_lines[@]}" -gt 0 ]; then
    body_hash="$(printf '%s\n' "${body_lines[@]}" | git hash-object --stdin)" \
      || fail_usage "git hash-object failed while hashing the lock's embedded body: $lockpath"
  else
    body_hash="$(git hash-object --stdin < /dev/null)" \
      || fail_usage "git hash-object failed while hashing the lock's embedded body: $lockpath"
  fi
  # Gate the computed body hash to 40 lowercase hex characters BEFORE it is
  # compared, mirroring bin/check-intent.sh:392-394's own HEX40_RE gate —
  # defence-in-depth against a future edit to this reconstruction pipeline,
  # never against git itself (Non-goals); this gate's own refusal path is
  # provable only by mutation, exactly as that file's comment records for
  # the same gate.
  HEX40_RE='^[0-9a-f]{40}$'
  [[ "$body_hash" =~ $HEX40_RE ]] \
    || fail_usage "git hash-object produced a value that is not 40 lowercase hex characters while hashing the lock's embedded body, refusing before comparison: $body_hash"
  [ "$body_hash" = "$LOCK_HASH" ] \
    || refuse lock-structural 2 "lock file's embedded body does not match its own recorded binding-hash (the dump was edited independently of the hash beside it): $lockpath"
}

# --- mode dispatch ------------------------------------------------------------
if [ "$MODE" = "verify" ]; then
  [ -f "$LOCK_ARG" ] && [ -r "$LOCK_ARG" ] \
    || refuse lock-missing 2 "lock file is missing, not a regular file, or unreadable: $LOCK_ARG"
  read_lock "$LOCK_ARG"

  CONFIG="$CONFIG_ARG"
  CONFIG_DISPLAY="$CONFIG_ARG"
  if [ "$CONFIG_DISPLAY" != "$LOCK_CONFIG_PATH" ]; then
    refuse path-mismatch 1 "the --config path given ('$CONFIG_DISPLAY') differs from the one recorded in the lock ('$LOCK_CONFIG_PATH') — not followed"
  fi

  [ -f "$CONFIG" ] && [ -r "$CONFIG" ] \
    || refuse missing-config 2 "binding config is missing, not a regular file, or unreadable: $CONFIG"
  validate_config "$CONFIG"

  computed_hash="$(canonical_hash)" || fail_usage "git hash-object failed while hashing the canonical binding for: $CONFIG"
  if [ "$computed_hash" != "$LOCK_HASH" ]; then
    refuse binding-changed 1 "the binding has changed since the lock was taken (config: $CONFIG_DISPLAY)"
  fi
  printf 'check-binding: verified: binding matches the lock (config: %s)\n' "$CONFIG_DISPLAY"
  exit 0
fi

if [ -n "$CONFIG_ARG" ]; then
  CONFIG="$CONFIG_ARG"
  CONFIG_DISPLAY="$CONFIG_ARG"
else
  BASE_DIR="$(get_path base)"
  BASE_DIR="${BASE_DIR%/}"
  CONFIG="$BASE_DIR/binding.conf"
  CONFIG_DISPLAY="$CONFIG"
fi
[ -f "$CONFIG" ] && [ -r "$CONFIG" ] \
  || refuse missing-config 2 "binding config is missing, not a regular file, or unreadable: $CONFIG"
validate_config "$CONFIG"

case "$MODE" in
  validate)
    printf 'check-binding: valid: schema %s, %d role(s) bound (config: %s)\n' \
      "${CANON_LINES[0]#schema }" "${#BIND_ROLE[@]}" "$CONFIG_DISPLAY"
    exit 0
    ;;
  print-binding)
    print_canonical
    exit 0
    ;;
  print-lock)
    computed_hash="$(canonical_hash)" || fail_usage "git hash-object failed while hashing the canonical binding for: $CONFIG"
    {
      printf 'binding-lock 1\n'
      printf 'config-path %s\n' "$CONFIG_DISPLAY"
      printf 'binding-hash %s\n' "$computed_hash"
      print_canonical
      printf 'binding-lock-end\n'
    }
    exit 0
    ;;
esac
