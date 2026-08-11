#!/usr/bin/env bash
# check-adapter.sh — fail-closed validator for the task-envelope contract
# registry and the adapter definitions that implement it (T-1055; GitHub
# issue #203; .shell-team/specs/T-1055-adapter-envelope.md).
#
# This script validates TWO things. First, the shipped contract registry
# (templates/task-envelope.txt): the envelope's field set, the closed
# channel / error-class / effort-mechanism vocabularies, and the per-role
# board-transition authority table. Second, an adapter definition
# (templates/adapters/<token>.txt): its identity (adapter token, paired
# provider, its own version, the envelope schema it implements), its
# field-to-channel `carries` mapping, and its `effort` capability
# declaration. It reads no binding config at all: the cross-check that
# once did (a host-authored binding config, T-1054) was carved out when
# this spec's pre-commitment trigger fired a second time (DP18) — the
# fail-closed effort rule and the board-transition authority rule now
# ship as normative statements in the contract document instead, with
# their enforcement inherited by a successor issue and by T-1057.
#
# The task envelope itself is a CONTRACT, never an instance: nothing in
# this script (or anywhere else in this task) serializes, parses, or writes
# an envelope value. No flag exists here for constructing or reading an
# envelope instance, and none is ever added; a flag of that shape is
# refused as ordinary unknown-flag usage, the same as any other unknown
# flag.
#
# Everything here is a bare token, never sourced or evaluated as code: an
# adapter definition cannot spell a command string, an argv list, an
# environment assignment, or a path to an executable. How the envelope
# actually reaches an executor is declared, per adapter, as a `carries
# <field> <channel>` mapping onto the contract's own closed channel
# vocabulary — a claim about which part of the existing substrate (files,
# the board, an argv value, ...) carries a field, never an instruction to
# execute anything.
#
# Usage:
#   check-adapter.sh [--contract PATH] [--definitions PATH]
#     Validate the shipped contract registry, then validate every
#     definition file found in the definitions directory (one file per
#     shipped adapter; a file whose declared `adapter` token does not match
#     its own basename is refused). Exit 0 = every file valid; non-zero = a
#     refusal token on stderr (see below).
#   check-adapter.sh [--contract PATH] [--definitions PATH] --print-contract
#     Validate the contract registry, then print its canonical form on
#     stdout: a `schema` line, then every `field`, `channel`, `error-class`,
#     `effort-mechanism` and `role-board-authority` row, single-space
#     delimited, grouped by directive in that order and LC_ALL=C-sorted
#     within each group. Nothing is printed on a refusal. Comments, blank
#     lines, row order and intra-row whitespace in the source registry do
#     not change a byte of this output.
#   check-adapter.sh [--contract PATH] [--definitions PATH] --adapter TOKEN
#     Validate the contract registry, then validate exactly the one named
#     adapter's definition file (<definitions-dir>/TOKEN.txt).
#   check-adapter.sh --contract PATH    (a testing affordance; the
#     contract registry otherwise resolves next to this script's own
#     installation)
#   check-adapter.sh --definitions PATH (a testing affordance; the
#     definitions directory otherwise resolves next to this script's own
#     installation)
#   check-adapter.sh --help
#
# Exit codes: 0 = valid. 1 = a content refusal (a definition file is
# readable and structurally parseable but its declared content is wrong —
# a name mismatch, an unknown field, an inconsistent capability, ...).
# 2 = the input could not be evaluated at all (a missing or malformed
# contract registry, a missing or malformed adapter allowlist, a missing
# definition, or a bad flag). Every refusal prints exactly one token, from
# a closed set, to stderr.

set -euo pipefail

# =============================================================================
# Design notes (not part of --help's output — print_help stops reading this
# file's header at the first non-comment line below, i.e. at `set -euo
# pipefail` above; everything from here on is free to use any word at all).
#
# Refusal matrix (token: exit code — condition), the CLOSED 22-entry set
# every non-zero exit comes from (spec `## Refusal matrix`, v4):
#   contract-unreadable (2), contract-malformed (2), contract-incomplete (2),
#   retired-channel-declared (2), registry-unreadable (2),
#   registry-malformed (2), definition-missing (2), definitions-unreadable (2),
#   unparseable-line (1), bad-token (1), missing-field (1),
#   duplicate-field (1), adapter-name-mismatch (1), unknown-adapter (1),
#   provider-adapter-mismatch (1), unsupported-envelope-schema (1),
#   unknown-envelope-field (1), unknown-channel (1), field-coverage-gap (1),
#   capability-inconsistent (1), unknown-effort-mechanism (1), usage (2).
#
# Contract-registry issues (contract-unreadable/-malformed/-incomplete) are
# ALWAYS exit 2 — the registry is plugin-shipped, not hand-authored, so any
# structural problem with it is something this checker cannot evaluate at
# all, never a mere content disagreement. Definition-file issues split the
# usual way: unparseable-line/bad-token/missing-field/duplicate-field are
# grammar-level (exit 1 — a definition is exactly the kind of file the
# Input space expects to be "hand-authored... wrong in exactly one way");
# every other definition-level token (adapter-name-mismatch, unknown-adapter,
# provider-adapter-mismatch, unsupported-envelope-schema,
# unknown-envelope-field, unknown-channel, field-coverage-gap,
# capability-inconsistent, unknown-effort-mechanism) is a semantic
# cross-check against the loaded contract or the adapter allowlist, also
# exit 1. definition-missing/definitions-unreadable (2) are input the
# checker cannot evaluate — the shape a file must exist in before its
# CONTENT can even be judged.
#
# This script also reads templates/binding-adapters.txt (T-1054's shipped
# adapter allowlist) read-only, to validate a definition's `adapter`/
# `provider` pair — the identical two-column grammar bin/check-binding.sh
# already parses, never edited or extended here (DP8/DP9). Since v2
# (DP15), that file is validated at FULL PARITY with how
# bin/check-binding.sh itself validates it — exactly two whitespace-
# delimited tokens per substantive row, each within the character class
# and length cap, no adapter token declared twice — refusing with that
# checker's OWN tokens, `registry-unreadable` (2) / `registry-malformed`
# (2), at the same exit codes, for the same conditions, on the same file.
# `contract-unreadable` now names the envelope contract registry
# (templates/task-envelope.txt) ALONE; this supersedes the v1 decision
# that folded an unreadable allowlist into `contract-unreadable` (recorded
# as a superseding entry in .shell-team/provenance/T-1055.md, never as two
# contradicting entries). Two checkers reading one file must not disagree
# about whether it is well-formed — that disagreement, reproduced against
# the real shipped file, was round 1's Blocker.
#
# `retired-channel-declared` (2) is new in v3 (DP17). Round 2 reproduced
# that v1/v2's retirement of the `board` channel was a fact about the
# shipped registry file rather than a property of this checker: a scratch
# contract supplied through `--contract` could re-declare `channel board`
# and validate cleanly. The fix is structural rather than file-scoped: this
# script carries its own compiled-in retired-channel set (`RETIRED_CHANNELS`
# below), and a `channel` row naming any member of it is refused
# `retired-channel-declared` REGARDLESS OF WHICH CONTRACT FILE IS LOADED —
# no `--contract` override can reintroduce a retired token. The registry
# additionally carries a `retired-channel <token>` row per retired token, so
# the retirement is visible to a reader of the contract and not only in
# this script's own source; that declared set must equal the compiled-in
# set exactly, and a divergence in either direction is `contract-incomplete`
# (2). A `carries` row naming a retired token needs no new refusal at all:
# once the token cannot be a `channel` member, `unknown-channel` (1) — the
# machinery that already exists — refuses it.
#
# The doc-sync mode this script once carried (validating the contract
# document against this registry), its two dedicated refusal tokens and
# its CI dogfood step were carved out of this branch at v3, when the
# spec's own pre-commitment fired after two consecutive rounds of new
# Blocker/Major findings against this script (DP16 v3). They are not a
# fast-follow to revisit here — the successor issue owns them. Two-form
# agreement between this registry and the contract document is still
# required; it is proved
# by the spec's own AC8, which performs the comparison independently at
# spec-check time rather than delegating it to a flag of this script.
#
# The host-authored binding-config cross-check mode this script once
# carried (delegating to bin/check-binding.sh's print-form output,
# re-asserting the delegated output's shape, then checking the
# fail-closed effort rule and the board-transition-authority join) was
# carved out of this branch at v4, when the spec's own pre-commitment
# fired a SECOND time (DP18) — a third consecutive round of new
# independent findings against this script (round 3: the delegated
# `schema` line was validated for presence but not content). This script
# now reads no binding config at all: not the effort agreement, not the
# authority join, not the shipped specimen's agreement with the shipped
# definitions. Both rules the mode once enforced survive as byte-frozen
# `- normative: ` statements in the contract document (pinned by AC6),
# with their enforcement inherited by a successor issue and by T-1057 —
# not a fast-follow to revisit here.
#
# Never spelled anywhere in this file, in code or in a comment: the name of
# bin/check-binding.sh's own registry-override flag (DP9; issue #221). That
# flag is a testing affordance with zero production consumers today
# (AC12). This script no longer calls check-binding.sh at all — the
# binding-config cross-check mode that once did was carved out (DP18); see
# below. Refer to the sibling's flag, when it must be named at all, as
# "the sibling validator's registry-override testing affordance."
#
# Resolution is physical (`cd DIR && pwd -P`) at every self-location site,
# from the first commit — never a hardening step bolted on after a review
# round. A T-1054 review round reproduced that an ANCESTOR directory
# symlink (an adopter's `bin/` symlinked into the plugin's real `bin/` —
# ordinary vendoring, no hostile action) survives a plain `cd && pwd`
# untouched, silently resolving this script's own directory inside the
# ADOPTER's tree and defeating the registry-identity guarantee the whole
# design rests on. Ported (bootstrap shape) from bin/check-binding.sh,
# itself ported from bin/check-durability.sh / bin/check-provenance.sh.
#
# Threat model (identical to bin/check-binding.sh's and
# bin/check-durability.sh's, for the identical reason): the operator and
# the working directory are TRUSTED (this repository's CLAUDE.md security
# invariant). What this defends against is accidents — a stray edit, a
# vendored install resolving to the wrong tree, a host binding an effort
# value the executor cannot honour — never a hostile operator replacing a
# shipped definition inside the plugin's own installation.
# =============================================================================

# --- classified refusal helper -----------------------------------------------
# Errexit-safe by construction (repo convention, T-096): the stderr write is
# `|| true`-guarded so a closed-stderr caller cannot turn the intended exit
# code into a bare errexit 1 before the real `exit "$2"` statement runs.
refuse() {  # $1 = token (closed refusal-matrix set); $2 = exit code (1|2); $3 = message
  printf 'check-adapter: %s: %s\n' "$1" "$3" >&2 || true
  exit "$2"
}
fail_usage() { refuse usage 2 "$1"; }

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Every `pwd` below is `pwd -P` (physical), never the bare logical `pwd` —
# see the design notes above for why an ancestor-directory symlink makes
# that distinction load-bearing rather than cosmetic.
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
TOKEN_RE='^[a-z][a-z0-9-]*$'
VERSION_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
MAXLEN=64
SIX_ROLES=(tech-lead pm-spec engineer qa-verifier codex-reviewer ui-designer)
BOARD_AUTHORITY_VALUES=(writes proposes none)
STATUS_KIND_VALUES=(success failure)
SUPPORTED_SCHEMA_VERSIONS=(1)
CONTRACT_DIRECTIVES=(schema field channel status-value error-class effort-mechanism role-board-authority retired-channel)
DEFINITION_DIRECTIVES=(envelope-schema adapter provider adapter-version carries capability effort-mechanism effort-value)
REQUIRED_ERRORCLASSES=(executor-unavailable capability-unsupported invocation-failed contract-violation)
# The compiled-in retired-channel set (DP17): a `channel` row naming any of
# these is refused `retired-channel-declared` REGARDLESS of which contract
# file is loaded, so no `--contract` override can reintroduce a retired
# token. The registry's own `retired-channel` rows must equal this set
# exactly (checked at the end of load_contract).
RETIRED_CHANNELS=(board)

in_list() {  # $1 = candidate; $2.. = list
  local x="$1" c; shift
  for c in "$@"; do [ "$c" = "$x" ] && return 0; done
  return 1
}
schema_version_supported() {  # $1 = candidate schema version token
  in_list "$1" "${SUPPORTED_SCHEMA_VERSIONS[@]}"
}

# --- argument parsing --------------------------------------------------------
CONTRACT_ARG="" DEFINITIONS_ARG="" ADAPTER_ARG=""
MODE="validate"
set_mode() {  # $1 = the new mode; refuses if a mode flag was already given
  [ "$MODE" = "validate" ] || fail_usage "specify only one of --print-contract or --adapter"
  MODE="$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)         print_help; exit 0 ;;
    --contract)        [ "$#" -ge 2 ] || fail_usage "--contract requires a value"; CONTRACT_ARG="$2"; shift 2 ;;
    --definitions)     [ "$#" -ge 2 ] || fail_usage "--definitions requires a value"; DEFINITIONS_ARG="$2"; shift 2 ;;
    --print-contract)  set_mode print-contract; shift ;;
    --adapter)         [ "$#" -ge 2 ] || fail_usage "--adapter requires a value"; ADAPTER_ARG="$2"; set_mode adapter; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

# --- resolve the contract registry + definitions dir + adapter allowlist ----
# TEMPLATES_ROOT is composed from SCRIPT_DIR (already physical, above) with
# `pwd -P` again here — SCRIPT_DIR is a plain string at this point, and
# `cd "$SCRIPT_DIR/.." && pwd -P` re-canonicalizes rather than assuming the
# one-level-up traversal itself introduces no new symlink to resolve.
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
  || fail_usage "cannot resolve the templates directory (one level above check-adapter.sh's own installed directory)"

if [ -n "$CONTRACT_ARG" ]; then
  CONTRACT="$CONTRACT_ARG"
else
  CONTRACT="$TEMPLATES_ROOT/templates/task-envelope.txt"
fi
if [ -n "$DEFINITIONS_ARG" ]; then
  DEFINITIONS_DIR="$DEFINITIONS_ARG"
else
  DEFINITIONS_DIR="$TEMPLATES_ROOT/templates/adapters"
fi
ADAPTERS_REGISTRY="$TEMPLATES_ROOT/templates/binding-adapters.txt"

# --- load the adapter allowlist (read-only; T-1054's own shipped file) -----
# Validated at FULL PARITY with bin/check-binding.sh's own reading of this
# same file (DP15) — exactly two whitespace-delimited tokens per
# substantive row, each within the character class and length cap, no
# adapter token declared twice — refusing with that checker's own tokens,
# `registry-unreadable` (2) / `registry-malformed` (2), at the same exit
# codes for the same conditions. This supersedes v1's decision to fold an
# unreadable allowlist into `contract-unreadable`; that token now names the
# envelope contract registry alone (see .shell-team/provenance/T-1055.md).
REG_ADAPTER=() REG_PROVIDER=()
load_adapters_registry() {
  [ -f "$ADAPTERS_REGISTRY" ] && [ -r "$ADAPTERS_REGISTRY" ] \
    || refuse registry-unreadable 2 "cannot read the adapter allowlist this contract depends on: $ADAPTERS_REGISTRY"
  local raw line f reg_a reg_p existing
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    read -r -a f <<< "$line"
    [ "${#f[@]}" -eq 2 ] \
      || refuse registry-malformed 2 "adapter registry row is not exactly two whitespace-delimited tokens: $line"
    reg_a="${f[0]}" reg_p="${f[1]}"
    [[ "$reg_a" =~ $TOKEN_RE ]] && [ "${#reg_a}" -le "$MAXLEN" ] \
      || refuse registry-malformed 2 "adapter registry adapter token is malformed: $reg_a"
    [[ "$reg_p" =~ $TOKEN_RE ]] && [ "${#reg_p}" -le "$MAXLEN" ] \
      || refuse registry-malformed 2 "adapter registry provider token is malformed: $reg_p"
    if [ "${#REG_ADAPTER[@]}" -gt 0 ]; then
      for existing in "${REG_ADAPTER[@]}"; do
        [ "$existing" = "$reg_a" ] \
          && refuse registry-malformed 2 "adapter token registered more than once: $reg_a"
      done
    fi
    REG_ADAPTER+=("$reg_a")
    REG_PROVIDER+=("$reg_p")
  done < "$ADAPTERS_REGISTRY"
}
adapter_registered_provider() {  # $1 = adapter token; prints its registered provider, or fails
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

# --- load_contract: parse templates/task-envelope.txt into arrays ----------
CONTRACT_SCHEMA=""
FIELD_NAME=() FIELD_DIR=() FIELD_REQ=()
CHANNEL_SET=()
STATUS_TOKEN=() STATUS_KIND=()
ERRORCLASS_SET=()
EFFORTMECH_SET=()
RBA_ROLE=() RBA_VALUE=()
RETIRED_CHANNEL_SET=()

field_index() {  # $1 = field name; prints its index in FIELD_NAME, or fails
  local x="$1" i
  for ((i = 0; i < ${#FIELD_NAME[@]}; i++)); do
    [ "${FIELD_NAME[$i]}" = "$x" ] && { printf '%s\n' "$i"; return 0; }
  done
  return 1
}
in_channel_set() { in_list "$1" "${CHANNEL_SET[@]:-}"; }
in_effortmech_set() { in_list "$1" "${EFFORTMECH_SET[@]:-}"; }

load_contract() {
  [ -f "$CONTRACT" ] && [ -r "$CONTRACT" ] \
    || refuse contract-unreadable 2 "cannot read the contract registry: $CONTRACT"

  local schema_count=0 raw line f first
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    read -r -a f <<< "$line"
    first="${f[0]:-}"
    in_list "$first" "${CONTRACT_DIRECTIVES[@]}" \
      || refuse contract-malformed 2 "unrecognized directive in the contract registry: $line"

    case "$first" in
      schema)
        [ "${#f[@]}" -eq 2 ] || refuse contract-malformed 2 "malformed schema line (expected 'schema <version>'): $line"
        schema_count=$((schema_count + 1))
        [ "$schema_count" -le 1 ] || refuse contract-malformed 2 "more than one schema line in the contract registry"
        [[ "${f[1]}" =~ $VERSION_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed schema version token: ${f[1]}"
        CONTRACT_SCHEMA="${f[1]}"
        ;;
      field)
        [ "${#f[@]}" -eq 4 ] || refuse contract-malformed 2 "malformed field row (expected 'field <name> <in|out> <required|conditional>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed field name token: ${f[1]}"
        field_index "${f[1]}" >/dev/null 2>&1 \
          && refuse contract-malformed 2 "field declared more than once: ${f[1]}"
        in_list "${f[2]}" in out \
          || refuse contract-malformed 2 "field direction must be 'in' or 'out': $line"
        in_list "${f[3]}" required conditional \
          || refuse contract-malformed 2 "field requiredness must be 'required' or 'conditional': $line"
        FIELD_NAME+=("${f[1]}"); FIELD_DIR+=("${f[2]}"); FIELD_REQ+=("${f[3]}")
        ;;
      channel)
        [ "${#f[@]}" -eq 2 ] || refuse contract-malformed 2 "malformed channel row (expected 'channel <token>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed channel token: ${f[1]}"
        # DP17: a retired channel token is refused from the set COMPILED
        # INTO this script, whichever contract file is loaded — this is
        # what makes the retirement structural rather than a fact about the
        # shipped registry file that a --contract override could evade.
        in_list "${f[1]}" "${RETIRED_CHANNELS[@]}" \
          && refuse retired-channel-declared 2 "channel row declares a retired channel token: ${f[1]}"
        in_channel_set "${f[1]}" || CHANNEL_SET+=("${f[1]}")
        ;;
      retired-channel)
        [ "${#f[@]}" -eq 2 ] || refuse contract-malformed 2 "malformed retired-channel row (expected 'retired-channel <token>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed retired-channel token: ${f[1]}"
        in_list "${f[1]}" "${RETIRED_CHANNEL_SET[@]:-}" || RETIRED_CHANNEL_SET+=("${f[1]}")
        ;;
      status-value)
        [ "${#f[@]}" -eq 3 ] || refuse contract-malformed 2 "malformed status-value row (expected 'status-value <token> <success|failure>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed status-value token: ${f[1]}"
        in_list "${f[2]}" "${STATUS_KIND_VALUES[@]}" \
          || refuse contract-malformed 2 "status-value second column must be 'success' or 'failure': $line"
        # A status-value token may not be declared twice at all, including
        # once as 'success' and once as 'failure' (V2/round 2): a token
        # already seen (in either kind) makes a second declaration of it
        # contract-malformed rather than a silent second row.
        in_list "${f[1]}" "${STATUS_TOKEN[@]:-}" \
          && refuse contract-malformed 2 "status-value token declared more than once: ${f[1]}"
        STATUS_TOKEN+=("${f[1]}"); STATUS_KIND+=("${f[2]}")
        ;;
      error-class)
        [ "${#f[@]}" -eq 2 ] || refuse contract-malformed 2 "malformed error-class row (expected 'error-class <token>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed error-class token: ${f[1]}"
        in_list "${f[1]}" "${ERRORCLASS_SET[@]:-}" || ERRORCLASS_SET+=("${f[1]}")
        ;;
      effort-mechanism)
        [ "${#f[@]}" -eq 2 ] || refuse contract-malformed 2 "malformed effort-mechanism row (expected 'effort-mechanism <token>'): $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse contract-malformed 2 "malformed effort-mechanism token: ${f[1]}"
        in_effortmech_set "${f[1]}" || EFFORTMECH_SET+=("${f[1]}")
        ;;
      role-board-authority)
        [ "${#f[@]}" -eq 3 ] || refuse contract-malformed 2 "malformed role-board-authority row (expected 'role-board-authority <role> <writes|proposes|none>'): $line"
        in_list "${f[1]}" "${SIX_ROLES[@]}" \
          || refuse contract-malformed 2 "role-board-authority names a role outside the six inner-loop roles: ${f[1]}"
        in_list "${f[1]}" "${RBA_ROLE[@]:-}" \
          && refuse contract-malformed 2 "role-board-authority declared more than once for role: ${f[1]}"
        in_list "${f[2]}" "${BOARD_AUTHORITY_VALUES[@]}" \
          || refuse contract-malformed 2 "role-board-authority value must be one of writes|proposes|none: $line"
        RBA_ROLE+=("${f[1]}"); RBA_VALUE+=("${f[2]}")
        ;;
    esac
  done < "$CONTRACT"

  [ -n "$CONTRACT_SCHEMA" ] || refuse contract-malformed 2 "no schema line found in the contract registry: $CONTRACT"
  schema_version_supported "$CONTRACT_SCHEMA" \
    || refuse contract-malformed 2 "unsupported schema version in the contract registry: $CONTRACT_SCHEMA"
  [ "${#FIELD_NAME[@]}" -gt 0 ] || refuse contract-incomplete 2 "the contract registry declares no field rows"
  [ "${#CHANNEL_SET[@]}" -gt 0 ] || refuse contract-incomplete 2 "the contract registry declares no channel rows"

  # Every declared minimum is ENFORCED here rather than merely observed on
  # a shipped file that happens to be correct (round 1's Major findings).
  # The floor is the four REQUIRED tokens themselves (V3/round 2), not mere
  # non-emptiness: round 2 reproduced a single arbitrary error-class row
  # passing this check under v2's non-emptiness-only form.
  local ec
  for ec in "${REQUIRED_ERRORCLASSES[@]}"; do
    in_list "$ec" "${ERRORCLASS_SET[@]:-}" \
      || refuse contract-incomplete 2 "the contract registry is missing required error-class row: $ec"
  done
  in_effortmech_set none \
    || refuse contract-incomplete 2 "the contract registry declares no effort-mechanism 'none' row"
  local has_nonnone=0 m
  for m in "${EFFORTMECH_SET[@]:-}"; do [ "$m" != "none" ] && has_nonnone=1; done
  [ "$has_nonnone" -eq 1 ] || refuse contract-incomplete 2 "the contract registry declares no non-'none' effort-mechanism row"
  [ "${#STATUS_TOKEN[@]}" -gt 0 ] || refuse contract-incomplete 2 "the contract registry declares no status-value rows"
  local success_count=0 failure_count=0 k
  for k in "${STATUS_KIND[@]:-}"; do
    case "$k" in
      success) success_count=$((success_count + 1)) ;;
      failure) failure_count=$((failure_count + 1)) ;;
    esac
  done
  [ "$success_count" -eq 1 ] || refuse contract-incomplete 2 "the contract registry does not mark exactly one status-value row 'success' (found $success_count)"
  [ "$failure_count" -ge 1 ] || refuse contract-incomplete 2 "the contract registry marks no status-value row 'failure'"

  local r
  for r in "${SIX_ROLES[@]}"; do
    in_list "$r" "${RBA_ROLE[@]:-}" \
      || refuse contract-incomplete 2 "the contract registry has no role-board-authority row for: $r"
  done

  # DP17: the registry's declared retired-channel set must equal this
  # script's own compiled-in set EXACTLY. A divergence in either direction
  # means the registry's declaration of what's retired doesn't match what
  # is actually enforced, which is the visibility half of DP17's two-halves
  # fix going stale relative to the authority half.
  local rc1 rc2
  for rc1 in "${RETIRED_CHANNELS[@]}"; do
    in_list "$rc1" "${RETIRED_CHANNEL_SET[@]:-}" \
      || refuse contract-incomplete 2 "the contract registry does not declare a retired-channel row for: $rc1"
  done
  for rc2 in "${RETIRED_CHANNEL_SET[@]:-}"; do
    in_list "$rc2" "${RETIRED_CHANNELS[@]}" \
      || refuse contract-incomplete 2 "the contract registry declares a retired-channel not in this checker's compiled-in set: $rc2"
  done
}

print_contract() {
  printf 'schema %s\n' "$CONTRACT_SCHEMA"
  local i lines=()
  for ((i = 0; i < ${#FIELD_NAME[@]}; i++)); do
    lines+=("field ${FIELD_NAME[$i]} ${FIELD_DIR[$i]} ${FIELD_REQ[$i]}")
  done
  printf '%s\n' "${lines[@]}" | LC_ALL=C sort
  printf '%s\n' "${CHANNEL_SET[@]}" | sed 's/^/channel /' | LC_ALL=C sort
  if [ "${#RETIRED_CHANNEL_SET[@]}" -gt 0 ]; then
    printf '%s\n' "${RETIRED_CHANNEL_SET[@]}" | sed 's/^/retired-channel /' | LC_ALL=C sort
  fi
  lines=()
  for ((i = 0; i < ${#STATUS_TOKEN[@]}; i++)); do
    lines+=("status-value ${STATUS_TOKEN[$i]} ${STATUS_KIND[$i]}")
  done
  if [ "${#lines[@]}" -gt 0 ]; then
    printf '%s\n' "${lines[@]}" | LC_ALL=C sort
  fi
  if [ "${#ERRORCLASS_SET[@]}" -gt 0 ]; then
    printf '%s\n' "${ERRORCLASS_SET[@]}" | sed 's/^/error-class /' | LC_ALL=C sort
  fi
  if [ "${#EFFORTMECH_SET[@]}" -gt 0 ]; then
    printf '%s\n' "${EFFORTMECH_SET[@]}" | sed 's/^/effort-mechanism /' | LC_ALL=C sort
  fi
  lines=()
  for ((i = 0; i < ${#RBA_ROLE[@]}; i++)); do
    lines+=("role-board-authority ${RBA_ROLE[$i]} ${RBA_VALUE[$i]}")
  done
  printf '%s\n' "${lines[@]}" | LC_ALL=C sort
}

# --- validate_definition: the whole per-file definition validation --------
# Sets DEF_ADAPTER/DEF_PROVIDER/DEF_VERSION/DEF_SCHEMA/DEF_CAP/DEF_MECH/
# DEF_VALUES (indexed) on success. Every failure exits the whole process
# via refuse() — never called inside a subshell/command-substitution.
validate_definition() {  # $1 = definition file path; $2 = expected adapter token (basename)
  local path="$1" expect="$2"
  [ -f "$path" ] && [ -r "$path" ] \
    || refuse definition-missing 2 "adapter definition file is missing, not a regular file, or unreadable: $path"

  DEF_ADAPTER="" DEF_PROVIDER="" DEF_VERSION="" DEF_SCHEMA="" DEF_CAP="" DEF_MECH=""
  DEF_VALUES=()
  local -a carries_field=() carries_channel=()
  local raw line f first lineno=0

  while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    line="${raw%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    read -r -a f <<< "$line"
    first="${f[0]:-}"
    in_list "$first" "${DEFINITION_DIRECTIVES[@]}" \
      || refuse unparseable-line 1 "unrecognized directive in definition ($path): $line"

    case "$first" in
      envelope-schema)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed envelope-schema row in $path: $line"
        [[ "${f[1]}" =~ $VERSION_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed envelope-schema token in $path: ${f[1]}"
        [ -z "$DEF_SCHEMA" ] || refuse duplicate-field 1 "envelope-schema declared more than once in $path"
        DEF_SCHEMA="${f[1]}"
        ;;
      adapter)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed adapter row in $path: $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed adapter token in $path: ${f[1]}"
        [ -z "$DEF_ADAPTER" ] || refuse duplicate-field 1 "adapter declared more than once in $path"
        DEF_ADAPTER="${f[1]}"
        ;;
      provider)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed provider row in $path: $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed provider token in $path: ${f[1]}"
        [ -z "$DEF_PROVIDER" ] || refuse duplicate-field 1 "provider declared more than once in $path"
        DEF_PROVIDER="${f[1]}"
        ;;
      adapter-version)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed adapter-version row in $path: $line"
        [[ "${f[1]}" =~ $VERSION_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed adapter-version token in $path: ${f[1]}"
        [ -z "$DEF_VERSION" ] || refuse duplicate-field 1 "adapter-version declared more than once in $path"
        DEF_VERSION="${f[1]}"
        ;;
      carries)
        [ "${#f[@]}" -eq 3 ] || refuse unparseable-line 1 "malformed carries row (expected 'carries <field> <channel>') in $path: $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed carries field token in $path: ${f[1]}"
        [[ "${f[2]}" =~ $TOKEN_RE ]] && [ "${#f[2]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed carries channel token in $path: ${f[2]}"
        field_index "${f[1]}" >/dev/null 2>&1 \
          || refuse unknown-envelope-field 1 "carries row names a field the contract does not declare ($path): ${f[1]}"
        in_channel_set "${f[2]}" \
          || refuse unknown-channel 1 "carries row names a channel the contract does not declare ($path): ${f[2]}"
        in_list "${f[1]}" "${carries_field[@]:-}" \
          && refuse duplicate-field 1 "carries row declared more than once for field ($path): ${f[1]}"
        carries_field+=("${f[1]}"); carries_channel+=("${f[2]}")
        ;;
      capability)
        [ "${#f[@]}" -eq 3 ] && [ "${f[1]}" = "effort" ] \
          || refuse unparseable-line 1 "malformed capability row (expected 'capability effort <supported|unsupported>') in $path: $line"
        in_list "${f[2]}" supported unsupported \
          || refuse bad-token 1 "capability effort value must be supported|unsupported in $path: ${f[2]}"
        [ -z "$DEF_CAP" ] || refuse duplicate-field 1 "capability effort declared more than once in $path"
        DEF_CAP="${f[2]}"
        ;;
      effort-mechanism)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed effort-mechanism row in $path: $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed effort-mechanism token in $path: ${f[1]}"
        [ -z "$DEF_MECH" ] || refuse duplicate-field 1 "effort-mechanism declared more than once in $path"
        DEF_MECH="${f[1]}"
        ;;
      effort-value)
        [ "${#f[@]}" -eq 2 ] || refuse unparseable-line 1 "malformed effort-value row in $path: $line"
        [[ "${f[1]}" =~ $TOKEN_RE ]] && [ "${#f[1]}" -le "$MAXLEN" ] \
          || refuse bad-token 1 "malformed effort-value token in $path: ${f[1]}"
        in_list "${f[1]}" "${DEF_VALUES[@]:-}" || DEF_VALUES+=("${f[1]}")
        ;;
    esac
  done < "$path"

  [ -n "$DEF_SCHEMA" ]   || refuse missing-field 1 "envelope-schema is required and absent in $path"
  [ -n "$DEF_ADAPTER" ]  || refuse missing-field 1 "adapter is required and absent in $path"
  [ -n "$DEF_PROVIDER" ] || refuse missing-field 1 "provider is required and absent in $path"
  [ -n "$DEF_VERSION" ]  || refuse missing-field 1 "adapter-version is required and absent in $path"
  [ -n "$DEF_CAP" ]      || refuse missing-field 1 "capability effort is required and absent in $path"
  [ -n "$DEF_MECH" ]     || refuse missing-field 1 "effort-mechanism is required and absent in $path"

  [ "$DEF_ADAPTER" = "$expect" ] \
    || refuse adapter-name-mismatch 1 "declared adapter '$DEF_ADAPTER' does not match this definition's own file name ($path, expected '$expect')"

  local reg_provider
  reg_provider="$(adapter_registered_provider "$DEF_ADAPTER")" \
    || refuse unknown-adapter 1 "adapter is not in the adapter allowlist ($ADAPTERS_REGISTRY): $DEF_ADAPTER"
  [ "$reg_provider" = "$DEF_PROVIDER" ] \
    || refuse provider-adapter-mismatch 1 "adapter '$DEF_ADAPTER' is registered with provider '$reg_provider', not '$DEF_PROVIDER' ($path)"

  [ "$DEF_SCHEMA" = "$CONTRACT_SCHEMA" ] \
    || refuse unsupported-envelope-schema 1 "definition's envelope-schema '$DEF_SCHEMA' does not match the contract's schema '$CONTRACT_SCHEMA' ($path)"

  # Field coverage, widened (DP14): a field with no carries row at all is a
  # gap, and so is a field the contract marks `required` whose carries row
  # names the `not-carried` channel — a required field cannot be declared
  # uncarried and still validate.
  local fn chan_for_field j
  for ((i = 0; i < ${#FIELD_NAME[@]}; i++)); do
    fn="${FIELD_NAME[$i]}"
    chan_for_field=""
    for ((j = 0; j < ${#carries_field[@]}; j++)); do
      if [ "${carries_field[$j]}" = "$fn" ]; then
        chan_for_field="${carries_channel[$j]}"
        break
      fi
    done
    [ -n "$chan_for_field" ] \
      || refuse field-coverage-gap 1 "no carries row for contract field '$fn' in $path"
    if [ "${FIELD_REQ[$i]}" = "required" ] && [ "$chan_for_field" = "not-carried" ]; then
      refuse field-coverage-gap 1 "required field '$fn' is declared not-carried in $path"
    fi
  done

  if [ "$DEF_CAP" = "supported" ]; then
    [ "$DEF_MECH" != "none" ] \
      || refuse capability-inconsistent 1 "capability effort supported but effort-mechanism is 'none' in $path"
    [ "${#DEF_VALUES[@]}" -gt 0 ] \
      || refuse capability-inconsistent 1 "capability effort supported but no effort-value rows declared in $path"
  else
    [ "$DEF_MECH" = "none" ] \
      || refuse capability-inconsistent 1 "capability effort unsupported but effort-mechanism is not 'none' in $path"
    [ "${#DEF_VALUES[@]}" -eq 0 ] \
      || refuse capability-inconsistent 1 "capability effort unsupported but effort-value rows are declared in $path"
  fi

  in_effortmech_set "$DEF_MECH" \
    || refuse unknown-effort-mechanism 1 "effort-mechanism '$DEF_MECH' is not in the contract's effort-mechanism vocabulary ($path)"
}

definition_path() {  # $1 = adapter token; prints the definition file path for it
  printf '%s/%s.txt\n' "$DEFINITIONS_DIR" "$1"
}

validate_all_definitions() {
  [ -d "$DEFINITIONS_DIR" ] && [ -r "$DEFINITIONS_DIR" ] \
    || refuse definitions-unreadable 2 "cannot read the definitions directory: $DEFINITIONS_DIR"
  local found=0 f base token
  for f in "$DEFINITIONS_DIR"/*.txt; do
    [ -e "$f" ] || continue
    found=1
    base="$(basename "$f")"
    token="${base%.txt}"
    validate_definition "$f" "$token"
  done
  [ "$found" -eq 1 ] || refuse definitions-unreadable 2 "no definition files found in: $DEFINITIONS_DIR"

  # Set completeness (round 1's Major): the whole-directory mode validates
  # the file SET against the allowlist, never merely whatever files happen
  # to be present — an accidental deletion must fail closed here too, not
  # only in --adapter, which looks up a specific file by name.
  local a dp
  for a in "${REG_ADAPTER[@]:-}"; do
    [ -n "$a" ] || continue
    dp="$(definition_path "$a")"
    [ -f "$dp" ] && [ -r "$dp" ] \
      || refuse definition-missing 2 "no definition file for allowlisted adapter '$a': $dp"
  done
}

# =============================================================================
# mode dispatch
# =============================================================================
load_contract

case "$MODE" in
  print-contract)
    print_contract
    exit 0
    ;;
  adapter)
    load_adapters_registry
    validate_definition "$(definition_path "$ADAPTER_ARG")" "$ADAPTER_ARG"
    printf 'check-adapter: valid: adapter definition %s (config: %s)\n' "$ADAPTER_ARG" "$(definition_path "$ADAPTER_ARG")"
    exit 0
    ;;
  validate)
    load_adapters_registry
    validate_all_definitions
    printf 'check-adapter: valid: contract registry (%s) and every definition in %s\n' "$CONTRACT" "$DEFINITIONS_DIR"
    exit 0
    ;;
esac
