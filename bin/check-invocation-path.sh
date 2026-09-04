#!/usr/bin/env bash
# check-invocation-path.sh — fail-closed admissibility gate for the
# alternate-executor invocation path (T-1118; GitHub issue #419;
# .shell-team/specs/T-1118-alternate-executor-invocation-path.md).
#
# This gate answers EXACTLY TWO questions for one named inner-loop role:
#   1. does a shipped recipe exist for this role's EFFECTIVE resolved
#      adapter token (invocation-recipe)?
#   2. is this role's role-board-authority admitted under that recipe's
#      sandbox mode (admits-authority)?
# It composes no argv, calls no provider, and writes nothing anywhere —
# the same header-contract shape bin/resolve-executor.sh already states
# for itself. Deciding WHETHER an invocation may proceed is this script's
# whole job; performing one is never this script's job.
#
# The recipe it reads is templates/prompt-blocks/alternate-executor-invocation.md
# (T-1118's shipped canonical prompt block), resolved from THIS script's
# own installed directory, one level up — never from an adopter's working
# tree. Argv composition for the one alternate path this repository ships
# (tech-lead under codex-cli, --sandbox read-only) stays shipped PROSE
# inside that block: a Claude Code sandbox matches its own exclusion
# patterns on a command line's first token, so a wrapper-embedded `codex
# exec` invocation can never run outside the sandbox
# (bin/codex-capture.sh:8-23) — this is why the recipe's ALLOWLIST is
# prose-carried and this gate is only the ADMISSIBILITY half.
#
# Usage:
#   check-invocation-path.sh --role <role>
#     Resolve ONE named inner-loop role's effective adapter token (via
#     `bin/resolve-executor.sh --print-resolved`, the PROBE-FREE mode —
#     never `--role`, whose compiled-in probe would make this gate's own
#     CI dogfood depend on a Codex install the runner does not have, and
#     which makes NO AVAILABILITY CLAIM at all in this mode) and this
#     role's role-board-authority (via `bin/check-adapter.sh
#     --print-contract`), then judge admissibility against the shipped
#     recipe. On success (exit 0), stdout is exactly one non-empty line:
#       admitted <role> <adapter> <invocation-kind>
#     or, for a role admitted by the wrapper-hosted derivation (DP-m) below:
#       admitted <role> <adapter> wrapper-hosted <agent-file-path>
#   check-invocation-path.sh --help
#
# Exit codes:
#   2 — usage, or a declaration this gate cannot evaluate at all: a bad
#       invocation (no --role, an unknown flag, a bare positional
#       argument, an empty --role value, a --role value this checkout
#       does not resolve), an unreadable recipe, or a declaration-integrity
#       defect in ANY of the three families the recipe carries
#       (invocation-recipe / wires-role / admits-authority) — a duplicated
#       conflicting row, a malformed row, or (admits-authority only) a
#       role's resolved adapter carrying no admits-authority set at all.
#       Every exit-2 case prints ZERO bytes on stdout and, for a
#       declaration-integrity defect, the name of the family it could not
#       evaluate on stderr.
#   1 — a content refusal from the closed three-token set, ZERO bytes on
#       stdout, the token itself on stderr:
#         no-recipe            — the resolved adapter has no shipped
#                                 invocation-recipe row at all. Reachable
#                                 only for a REGISTERED adapter with no
#                                 recipe; an unknown or unregistered
#                                 adapter token is refused UPSTREAM by
#                                 resolution and never reaches this gate's
#                                 recipe lookup.
#         role-not-wired       — the resolved adapter has a recipe, but no
#                                 wires-role row names this role.
#         authority-incompatible — the role is wired, but its
#                                 role-board-authority is not among the
#                                 recipe's admits-authority set for that
#                                 adapter. NEVER printed for a role this
#                                 gate could not evaluate at all — that is
#                                 always exit 2, never this token.
#   0 — admitted; either the recipe declares this (role, adapter,
#       sandbox-mode) triple admissible, or (for a sandbox-read-only
#       adapter only) the role's own agents/<role>.md hosts a bare,
#       first-token `codex exec ` line and is admitted `wrapper-hosted`
#       (DP-m) — that role's write authority stays with the Claude-hosted
#       wrapper and the read-only recipe never receives it. This derivation
#       is evaluated BEFORE wires-role/admits-authority and never widens
#       either declaration.
#
# An unavailable or unauthenticated executor is BLOCKED with the exact
# error at the INVOCATION site — this gate makes no availability claim
# and never guesses a recipe for an adapter token this file does not
# declare.
#
# This gate joins tests/check-binding/run.sh's live
# cb-adapters-not-forwarded-population set by naming check-binding.sh
# nowhere and carrying no adapters-override flag of any kind: it never
# forwards a registry override.
#
# #419 / T-1118.

set -euo pipefail

# =============================================================================
# Design notes (not part of --help's output — print_help stops reading this
# file's header at the first non-comment line below, i.e. at `set -euo
# pipefail` above).
#
# Threat model: identical to bin/resolve-executor.sh's, bin/check-binding.sh's
# and bin/check-adapter.sh's — the operator and the working directory are
# TRUSTED. What this defends against is accidents: a stray edit to the
# shipped recipe, a host binding a write-authority role to a read-only-
# sandbox adapter, a vendored install resolving to the wrong tree.
#
# Every act of parsing this script's own inputs actually needs is
# delegated to a sibling rather than re-implemented: the effective
# binding's adapter token per role comes from
# `bin/resolve-executor.sh --print-resolved` (re-asserted by content
# before use, never trusted on its first token alone); a role's
# role-board-authority comes from `bin/check-adapter.sh --print-contract`
# (same discipline). Only the recipe block's own three declaration
# families are a grammar this script reads directly, because they are
# this task's own shipped artifact and no sibling already validates them.
#
# The admits-authority cross-check below (grounded in wires-role plus the
# delegated role-board-authority table) exists because a bare "how many
# rows does this adapter have" count cannot distinguish a legitimate
# multi-value admitted set (claude-cli's shipped three rows, one per
# distinct authority among its six wired roles) from a corrupted or
# maliciously widened one (an admits-authority value naming an authority
# no wires-role row for that adapter actually carries) — the latter is
# exactly the shape that would silently defeat authority-incompatible.
# =============================================================================

refuse2() {  # $1 = message (may name a family); exit 2, empty stdout
  printf 'check-invocation-path: %s\n' "$1" >&2 || true
  exit 2
}
refuse1() {  # $1 = token (closed 3-token set); $2 = message; exit 1, empty stdout
  printf 'check-invocation-path: %s: %s\n' "$1" "$2" >&2 || true
  exit 1
}

# --- self-location, symlink-safe (ported from resolve-executor.sh) ---------
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || refuse2 "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || refuse2 "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || refuse2 "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || refuse2 "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || refuse2 "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || refuse2 "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || refuse2 "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
ROLE_ARG="" MODE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --role)
      [ "$#" -ge 2 ] || refuse2 "--role requires a value"
      [ -z "$MODE" ] || refuse2 "specify --role exactly once"
      ROLE_ARG="$2"; MODE="role"; shift 2 ;;
    --) shift; break ;;
    -*) refuse2 "unknown flag: $1" ;;
    *)  refuse2 "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || refuse2 "unexpected extra argument: $1"
[ "$MODE" = "role" ] || refuse2 "specify --role <role> (see --help)"
[ -n "$ROLE_ARG" ] || refuse2 "--role requires a non-empty value"

# --- resolve the recipe, from THIS script's own installed directory --------
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || refuse2 "cannot resolve the templates directory (one level above check-invocation-path.sh's own installed directory)"
RECIPE="$TEMPLATES_ROOT/templates/prompt-blocks/alternate-executor-invocation.md"
[ -f "$RECIPE" ] && [ -r "$RECIPE" ] \
  || refuse2 "cannot read the shipped recipe: $RECIPE"

# --- delegate the effective binding (probe-free) and the contract ----------
if ! RESOLVED_OUT="$(bash "$SCRIPT_DIR/resolve-executor.sh" --print-resolved 2>/dev/null)"; then
  refuse2 "the effective binding did not resolve (bin/resolve-executor.sh --print-resolved)"
fi
[ -n "$RESOLVED_OUT" ] \
  || refuse2 "bin/resolve-executor.sh --print-resolved printed no output"

if ! CONTRACT_OUT="$(bash "$SCRIPT_DIR/check-adapter.sh" --print-contract 2>/dev/null)"; then
  refuse2 "the task-envelope contract registry did not resolve (bin/check-adapter.sh --print-contract)"
fi
[ -n "$CONTRACT_OUT" ] \
  || refuse2 "bin/check-adapter.sh --print-contract printed no output"

# resolved_adapter_for: $1 = role; stdout = adapter token; return 1 if absent
resolved_adapter_for() {
  local role="$1" line f
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    [ "${f[0]:-}" = "resolved" ] || continue
    if [ "${f[1]:-}" = "$role" ]; then
      [ "${#f[@]}" -ge 6 ] || return 1
      printf '%s\n' "${f[5]}"
      return 0
    fi
  done <<< "$RESOLVED_OUT"
  return 1
}
role_known() {  # $1 = candidate role; return 0 iff --print-resolved names it
  local role="$1" line f
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    read -r -a f <<< "$line"
    [ "${f[0]:-}" = "resolved" ] || continue
    [ "${f[1]:-}" = "$role" ] && return 0
  done <<< "$RESOLVED_OUT"
  return 1
}
role_authority_for() {  # $1 = role; stdout = writes|proposes|none; return 1 if malformed/absent
  local role="$1" n nf val
  n="$(printf '%s\n' "$CONTRACT_OUT" | awk -v r="$role" '$1=="role-board-authority" && $2==r { c++ } END { print c+0 }')" || return 1
  [ "$n" = "1" ] || return 1
  nf="$(printf '%s\n' "$CONTRACT_OUT" | awk -v r="$role" '$1=="role-board-authority" && $2==r { print NF }')" || return 1
  [ "$nf" = "3" ] || return 1
  val="$(printf '%s\n' "$CONTRACT_OUT" | awk -v r="$role" '$1=="role-board-authority" && $2==r { print $3 }')" || return 1
  case "$val" in
    writes|proposes|none) printf '%s\n' "$val" ;;
    *) return 1 ;;
  esac
}

role_in_six() {  # $1 = candidate role; return 0 iff --print-resolved names it
  role_known "$1"
}

[ -n "${ROLE_ARG}" ] || refuse2 "--role requires a non-empty value"
role_in_six "$ROLE_ARG" \
  || refuse2 "unknown role, or this checkout's effective binding does not resolve it: $ROLE_ARG"

# =============================================================================
# Phase 1 — declaration-integrity: the recipe is validated AS A WHOLE, over
# every adapter it mentions, BEFORE any per-role/per-adapter lookup. A
# duplicated or malformed row in ANY of the three families refuses exit 2
# regardless of which adapter the role under test resolves to.
# =============================================================================

INVREC_ADAPTER=() INVREC_KIND=()
WIRES_ADAPTER=() WIRES_ROLE=()
ADM_ADAPTER=() ADM_VALUE=()

BAD_FAMILY=""
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  read -r -a f <<< "$line"
  case "${f[0]:-}" in
    invocation-recipe)
      if [ "${#f[@]}" -ne 3 ]; then BAD_FAMILY="invocation-recipe"; break; fi
      case "${f[2]}" in
        in-process|sandbox-read-only) : ;;
        *) BAD_FAMILY="invocation-recipe"; break ;;
      esac
      INVREC_ADAPTER+=("${f[1]}"); INVREC_KIND+=("${f[2]}")
      ;;
    wires-role)
      if [ "${#f[@]}" -ne 3 ]; then BAD_FAMILY="wires-role"; break; fi
      role_known "${f[2]}" || { BAD_FAMILY="wires-role"; break; }
      WIRES_ADAPTER+=("${f[1]}"); WIRES_ROLE+=("${f[2]}")
      ;;
    admits-authority)
      if [ "${#f[@]}" -ne 3 ]; then BAD_FAMILY="admits-authority"; break; fi
      case "${f[2]}" in
        writes|proposes|none) : ;;
        *) BAD_FAMILY="admits-authority"; break ;;
      esac
      ADM_ADAPTER+=("${f[1]}"); ADM_VALUE+=("${f[2]}")
      ;;
    *) : ;;
  esac
done < "$RECIPE"
[ -n "$BAD_FAMILY" ] && refuse2 "declaration-integrity: $BAD_FAMILY: malformed row"

# duplicated-key detection: invocation-recipe keyed on adapter alone.
i=0
while [ "$i" -lt "${#INVREC_ADAPTER[@]}" ]; do
  j=0
  while [ "$j" -lt "${#INVREC_ADAPTER[@]}" ]; do
    if [ "$i" -ne "$j" ] && [ "${INVREC_ADAPTER[$i]}" = "${INVREC_ADAPTER[$j]}" ]; then
      refuse2 "declaration-integrity: invocation-recipe: duplicated adapter token: ${INVREC_ADAPTER[$i]}"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done

# duplicated-key detection: wires-role keyed on the (adapter, role) pair.
i=0
while [ "$i" -lt "${#WIRES_ADAPTER[@]}" ]; do
  j=0
  while [ "$j" -lt "${#WIRES_ADAPTER[@]}" ]; do
    if [ "$i" -ne "$j" ] && [ "${WIRES_ADAPTER[$i]}" = "${WIRES_ADAPTER[$j]}" ] && [ "${WIRES_ROLE[$i]}" = "${WIRES_ROLE[$j]}" ]; then
      refuse2 "declaration-integrity: wires-role: duplicated (adapter, role) pair: ${WIRES_ADAPTER[$i]} ${WIRES_ROLE[$i]}"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done

# duplicated-key detection: admits-authority keyed on the (adapter, value)
# pair — the same shape its two sibling families already carry above. This
# is independent of the cross-check below (which asks whether a value is
# GROUNDED by a wired role's own authority): two byte-identical, individually
# well-grounded rows for the same (adapter, value) pair are still a
# corrupted-looking repetition this gate should not interpret charitably.
i=0
while [ "$i" -lt "${#ADM_ADAPTER[@]}" ]; do
  j=0
  while [ "$j" -lt "${#ADM_ADAPTER[@]}" ]; do
    if [ "$i" -ne "$j" ] && [ "${ADM_ADAPTER[$i]}" = "${ADM_ADAPTER[$j]}" ] && [ "${ADM_VALUE[$i]}" = "${ADM_VALUE[$j]}" ]; then
      refuse2 "declaration-integrity: admits-authority: duplicated (adapter, value) pair: ${ADM_ADAPTER[$i]} ${ADM_VALUE[$i]}"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done

# admits-authority cross-check: for every adapter appearing in
# admits-authority rows, its declared VALUE SET must be a subset of the
# DISTINCT role-board-authority values among the roles wires-role wires
# to that SAME adapter. A value with no grounding wired role is
# extraneous/ungrounded rather than a legitimate widened admission — the
# shape that would otherwise let a stray edit silently defeat
# authority-incompatible. A wired role whose authority is NOT admitted is
# never flagged here: that is the ordinary, evaluated authority-incompatible
# outcome (AC13(ii)), not a declaration-integrity defect.
i=0
while [ "$i" -lt "${#ADM_ADAPTER[@]}" ]; do
  adapter="${ADM_ADAPTER[$i]}"; value="${ADM_VALUE[$i]}"
  grounded=0
  k=0
  while [ "$k" -lt "${#WIRES_ADAPTER[@]}" ]; do
    if [ "${WIRES_ADAPTER[$k]}" = "$adapter" ]; then
      wired_role="${WIRES_ROLE[$k]}"
      if wired_authority="$(role_authority_for "$wired_role")" && [ "$wired_authority" = "$value" ]; then
        grounded=1
        break
      fi
    fi
    k=$((k + 1))
  done
  [ "$grounded" -eq 1 ] \
    || refuse2 "declaration-integrity: admits-authority: value '$value' for adapter '$adapter' names no wired role's actual authority"
  i=$((i + 1))
done

# =============================================================================
# Phase 2 — resolve this role's effective adapter, then the two questions.
# =============================================================================

ADAPTER="$(resolved_adapter_for "$ROLE_ARG")" \
  || refuse2 "unknown role, or this checkout's effective binding does not resolve it: $ROLE_ARG"

# Question 1: does a shipped recipe exist for this adapter?
INVOCATION_KIND=""
i=0
while [ "$i" -lt "${#INVREC_ADAPTER[@]}" ]; do
  if [ "${INVREC_ADAPTER[$i]}" = "$ADAPTER" ]; then
    INVOCATION_KIND="${INVREC_KIND[$i]}"
    break
  fi
  i=$((i + 1))
done
[ -n "$INVOCATION_KIND" ] \
  || refuse1 no-recipe "no invocation-recipe row for adapter: $ADAPTER"

# --- wrapper-hosted derivation (DP-m) --------------------------------------
# The codex-cli token conflates two shapes: a role hosting its own bare,
# first-token `codex exec ` call (a Claude-hosted wrapper, whose write stays
# with the wrapper and never reaches the read-only sandbox) and the
# alternate path this recipe actually wires. Admissibility for the former is
# DERIVED from the role's own agents/<role>.md, never from widening
# wires-role/admits-authority, and only ever considered for a
# sandbox-read-only adapter — an in-process adapter has no such conflation
# to resolve. This runs BEFORE the wires-role question, so a role need not
# be named in wires-role at all to be admitted this way.
if [ "$INVOCATION_KIND" = "sandbox-read-only" ]; then
  AGENT_FILE="$TEMPLATES_ROOT/agents/$ROLE_ARG.md"
  if [ -r "$AGENT_FILE" ] && grep -qE '^[[:space:]]*codex exec ' "$AGENT_FILE"; then
    printf 'admitted %s %s wrapper-hosted %s\n' "$ROLE_ARG" "$ADAPTER" "$AGENT_FILE"
    exit 0
  fi
fi

# Is this role wired to that adapter?
WIRED=0
i=0
while [ "$i" -lt "${#WIRES_ADAPTER[@]}" ]; do
  if [ "${WIRES_ADAPTER[$i]}" = "$ADAPTER" ] && [ "${WIRES_ROLE[$i]}" = "$ROLE_ARG" ]; then
    WIRED=1
    break
  fi
  i=$((i + 1))
done
[ "$WIRED" -eq 1 ] \
  || refuse1 role-not-wired "no wires-role row names role '$ROLE_ARG' under adapter: $ADAPTER"

# Question 2: is this role's role-board-authority admitted under this adapter?
ROLE_AUTHORITY="$(role_authority_for "$ROLE_ARG")" \
  || refuse2 "the delegated contract does not carry a well-formed role-board-authority row for role: $ROLE_ARG"

ADM_COUNT=0
ADMITTED=0
i=0
while [ "$i" -lt "${#ADM_ADAPTER[@]}" ]; do
  if [ "${ADM_ADAPTER[$i]}" = "$ADAPTER" ]; then
    ADM_COUNT=$((ADM_COUNT + 1))
    [ "${ADM_VALUE[$i]}" = "$ROLE_AUTHORITY" ] && ADMITTED=1
  fi
  i=$((i + 1))
done
[ "$ADM_COUNT" -gt 0 ] \
  || refuse2 "declaration-integrity: admits-authority: no admits-authority set at all for adapter: $ADAPTER"
[ "$ADMITTED" -eq 1 ] \
  || refuse1 authority-incompatible "role '$ROLE_ARG' has role-board-authority '$ROLE_AUTHORITY' but adapter '$ADAPTER' does not admit it"

printf 'admitted %s %s %s\n' "$ROLE_ARG" "$ADAPTER" "$INVOCATION_KIND"
