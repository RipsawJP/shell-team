#!/usr/bin/env bash
# check-review-provider.sh — fail-closed gate: may the code-reviewer run Codex
# on repository content under the effective binding? (T-1177; GitHub issue #700)
#
# A `code-reviewer` binding whose provider is not `codex` is an operator's
# statement that repository content must not go to Codex. The reviewer's own
# instructions run `codex exec`, so every reviewer mode, review-response, the
# orchestrators' reviewer dispatch and drift-evaluator's optional pass run this
# gate first and stop BLOCKED when it refuses. This gate reads the effective
# binding ONLY through `resolve-executor.sh --print-resolved` (the probe-free
# mode: no availability probe, no codex invocation), calls no provider, and
# writes nothing anywhere.
#
# Usage:
#   check-review-provider.sh
#   check-review-provider.sh --help | -h
#
# Closed decision table (the operating base resolves from the working
# directory exactly as for every other resolver caller):
#   CODEX_THREAD_ID non-empty (the Codex CLI host)   exit 0, stdout `admit codex-cli-host`
#   code-reviewer provider is codex (or default)      exit 0, stdout `admit codex-binding`
#   code-reviewer provider is anything else           exit 1, stderr `reviewer-binding-not-codex`
#   binding unresolved or row of the wrong shape      exit 2, stderr `binding-unresolved`
#   any argument other than --help / -h               exit 2, stderr `usage`
# On exit 1 and 2 stdout is empty and stderr carries exactly one line. The only
# binding-derived byte a refusal may carry is the provider token of exit 1,
# which the binding validator has already restricted; no model, effort,
# adapter, comment or resolver stderr is ever forwarded.
#
# #700 / T-1177.

set -euo pipefail

refuse() {  # $1 = exit code, $2 = one fixed stderr line
  printf 'check-review-provider: %s\n' "$2" >&2 || true
  exit "$1"
}

# --- self-location, symlink-safe (ported from check-invocation-path.sh) ------
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || refuse 2 "binding-unresolved: cannot resolve this script's symlink"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || refuse 2 "binding-unresolved: cannot resolve this script's directory"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || refuse 2 "binding-unresolved: cannot resolve this script's directory"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || refuse 2 "binding-unresolved: cannot resolve this script's directory"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || refuse 2 "binding-unresolved: cannot resolve this script's directory"
self_name="$(basename "$script_path")" \
  || refuse 2 "binding-unresolved: cannot resolve this script's name"
SELF="$SCRIPT_DIR/$self_name"

# --- argument parsing (first: the usage row applies on every host) -----------
if [ "$#" -gt 0 ]; then
  if [ "$#" -eq 1 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
      || refuse 2 "binding-unresolved: cannot read this script's own help text"
    exit 0
  fi
  refuse 2 "usage: takes no argument other than --help or -h"
fi

# --- row H: the Codex CLI host (an empty value counts as unset) --------------
if [ -n "${CODEX_THREAD_ID:-}" ]; then
  printf 'admit codex-cli-host\n' || exit 2
  exit 0
fi

# --- rows C / N / U: the effective binding, through the resolver only --------
# The resolver's stderr is untrusted text and is never forwarded.
if ! RESOLVED_OUT="$(bash "$SCRIPT_DIR/resolve-executor.sh" --print-resolved 2>/dev/null < /dev/null)"; then
  refuse 2 "binding-unresolved: the effective binding did not resolve"
fi

rows=0 provider=""
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  read -r -a f <<< "$line"
  [ "${f[0]:-}" = "resolved" ] || continue
  [ "${f[1]:-}" = "code-reviewer" ] || continue
  rows=$((rows + 1))
  if [ "${#f[@]}" -ne 6 ]; then
    refuse 2 "binding-unresolved: a code-reviewer row of the wrong shape"
  fi
  provider="${f[2]}"
done <<< "$RESOLVED_OUT"

[ "$rows" -eq 1 ] \
  || refuse 2 "binding-unresolved: expected exactly one code-reviewer row"

case "$provider" in
  codex)
    printf 'admit codex-binding\n' || exit 2
    exit 0
    ;;
  *[!a-z0-9-]*|"")
    refuse 2 "binding-unresolved: a code-reviewer row of the wrong shape"
    ;;
  *)
    refuse 1 "reviewer-binding-not-codex: the code-reviewer binding's provider is $provider, not codex"
    ;;
esac
