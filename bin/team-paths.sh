#!/usr/bin/env bash
# bin/team-paths.sh — single source of truth for where the shell-team loop's
# per-repo operating files live (T-025).
#
# The plugin keeps all of a host repo's operating artifacts under ONE base
# directory so its footprint never scatters across the host's mainline tree.
# This script resolves that base dir and the derived artifact paths using a
# deterministic precedence chain, and emits them for the bin scripts, the
# skills, and (via prompt injection) the agents — so every consumer agrees on
# the same layout.
#
# Precedence (highest wins), evaluated against a repo ROOT (default: cwd):
#   1. $TEAM_RUN_BASE env  — explicit operator/CI/host override (repo-relative).
#   2. legacy layout       — if ROOT/tasks/loops/ exists, use the historical
#                            split layout (base=tasks, specs=docs/specs). The
#                            marker is `tasks/loops/` (plugin-unique), NOT a bare
#                            `tasks/todo.md`, so an unrelated host `tasks/` dir
#                            is never misdetected as a shell-team install.
#   3. default             — base=.shell-team (specs=.shell-team/specs).
#
# Derived paths (all ROOT-relative):
#   TEAM_RUN_BASE  TEAM_TODO  TEAM_LOOPS_DIR  TEAM_RUNS_DIR  TEAM_RETROS_DIR
#   TEAM_REVIEWS_DIR  TEAM_SPECS_DIR  TEAM_PROVENANCE_DIR
#
# `docs/specs` is the ONE path the legacy layout keeps OUTSIDE the base dir
# (historically specs lived under docs/, everything else under tasks/). That
# split-root quirk is encoded here and nowhere else.
#
# External dependencies: bash + standard POSIX tools only (per the framework's
# external-dependency-zero rule). No JSON/YAML processors, no language runtimes.
#
# Usage:
#   team-paths.sh [--root DIR] --export   # `export VAR=...` lines, safe for eval
#   team-paths.sh [--root DIR] --get KEY  # one path; KEY ∈ base|todo|loops|runs|
#                                         #   retros|reviews|specs|provenance
#   team-paths.sh [--root DIR] --print    # human-readable table + which rule fired
#   team-paths.sh --help
#
# Typical use:
#   eval "$(team-paths.sh --export)"      # in a skill / orchestrator turn
#   spec_dir="$(team-paths.sh --get specs)"
#
# Exit codes:
#   0  success
#   2  argument / usage error

set -euo pipefail

die() { printf 'team-paths: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: team-paths.sh [--root DIR] (--export | --get KEY | --print)

Resolve where the shell-team loop's per-repo operating files live.

Precedence (highest first), against ROOT (default: current directory):
  1. $TEAM_RUN_BASE env   explicit override (repo-relative)
  2. legacy layout        if ROOT/tasks/loops/ exists -> base=tasks, specs=docs/specs
  3. default              base=.shell-team, specs=.shell-team/specs

Modes:
  --export        Print `export VAR=...` lines (eval-safe) for all TEAM_* vars.
  --get KEY       Print one path. KEY ∈ base|todo|loops|runs|retros|reviews|specs|provenance.
  --print         Print a human-readable table and which rule fired.

Options:
  --root DIR      Repo root to resolve against (default: current directory).
  --help, -h      Show this help and exit.
EOF
}

ROOT="."
MODE=""
GET_KEY=""

# Reject only one mode flag at a time so a typo like `--export --get specs` is a
# clear error instead of silently honoring whichever came last.
set_mode() { [ -z "$MODE" ] || die "specify only one mode (--export | --get KEY | --print)"; MODE="$1"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --root)    [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --export)  set_mode export; shift ;;
    --print)   set_mode print;  shift ;;
    --get)     [ "$#" -ge 2 ] || die "--get requires a value"; set_mode get; shift; GET_KEY="$1"; shift ;;
    --*)       die "unknown flag: $1" ;;
    *)         die "unexpected argument: $1" ;;
  esac
done

[ -n "$MODE" ] || die "one of --export | --get KEY | --print is required (see --help)"
[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"

# Validate an explicit base dir before trusting it. TEAM_RUN_BASE is meant to be
# a repo-relative subdirectory; values that would escape into the host root or
# the filesystem (`.`, `..`, an absolute path, a `..` component, a `~` path) must
# be rejected — otherwise scaffolders would write straight into the host root and
# break the "host root left untouched" guarantee.
validate_base() {
  local b="$1"
  case "$b" in
    /*)   die "TEAM_RUN_BASE must be repo-relative, not an absolute path: '$1'" ;;
    [~]*) die "TEAM_RUN_BASE must be repo-relative, not a home path: '$1'" ;;
    # Whitespace is rejected so the resolver and the board linter agree: a spec
    # path under a base with a space (e.g. 'my ops/specs/T-1.md') would fail
    # check-handoff's whitespace-free spec-path grammar. A clean base dir name
    # never needs a space.
    *[[:space:]]*) die "TEAM_RUN_BASE must not contain whitespace: '$1'" ;;
  esac
  b="${b%/}"   # tolerate a single trailing slash (e.g. ".shell-team/")
  [ -n "$b" ] || die "TEAM_RUN_BASE must not resolve to the host root: '$1'"
  # Walk the path components and reject any '.', '..', or empty one. Parameter
  # expansion only (no word-splitting / globbing), so a base like 'a*' is safe.
  # This catches the whole dot family — '.', './.', './/', 'a/./b', 'a//b' — and
  # any '..' escape, i.e. every value that resolves to or above the host root.
  local rest="$b" comp
  while : ; do
    comp="${rest%%/*}"
    case "$comp" in
      .|..|"") die "TEAM_RUN_BASE must be a clean repo-relative subpath (no '.', '..', or empty path components): '$1'" ;;
    esac
    case "$rest" in
      */*) rest="${rest#*/}" ;;
      *)   break ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Resolve base + specs via the precedence chain. RULE records which branch
# fired, for --print transparency. An empty TEAM_RUN_BASE is treated as unset
# (falls through to legacy/default) — the dangerous values are validated above.
# Legacy mode is anchored on the plugin-unique contract file
# `tasks/loops/shell-team.contract.yaml`, NOT a bare `tasks/loops/` dir, so a host
# repo that happens to keep an unrelated `tasks/loops/` is never misdetected.
# ---------------------------------------------------------------------------
if [ -n "${TEAM_RUN_BASE:-}" ]; then
  validate_base "$TEAM_RUN_BASE"
  BASE="$TEAM_RUN_BASE"
  SPECS="$BASE/specs"
  RULE="env (TEAM_RUN_BASE)"
elif [ -f "$ROOT/tasks/loops/shell-team.contract.yaml" ]; then
  BASE="tasks"
  SPECS="docs/specs"
  RULE="legacy (tasks/loops/shell-team.contract.yaml present)"
else
  BASE=".shell-team"
  SPECS=".shell-team/specs"
  RULE="default"
fi

TODO="$BASE/todo.md"
LOOPS="$BASE/loops"
RUNS="$BASE/runs"
RETROS="$BASE/retros"
REVIEWS="$BASE/reviews"
PROVENANCE="$BASE/provenance"

case "$MODE" in
  export)
    # %q quoting keeps the output eval-safe even when a path contains spaces or
    # shell metacharacters (e.g. a host repo dir with a space).
    printf 'export TEAM_RUN_BASE=%q\n'    "$BASE"
    printf 'export TEAM_TODO=%q\n'        "$TODO"
    printf 'export TEAM_LOOPS_DIR=%q\n'   "$LOOPS"
    printf 'export TEAM_RUNS_DIR=%q\n'    "$RUNS"
    printf 'export TEAM_RETROS_DIR=%q\n'  "$RETROS"
    printf 'export TEAM_REVIEWS_DIR=%q\n' "$REVIEWS"
    printf 'export TEAM_SPECS_DIR=%q\n'   "$SPECS"
    printf 'export TEAM_PROVENANCE_DIR=%q\n' "$PROVENANCE"
    ;;
  get)
    case "$GET_KEY" in
      base)       printf '%s\n' "$BASE" ;;
      todo)       printf '%s\n' "$TODO" ;;
      loops)      printf '%s\n' "$LOOPS" ;;
      runs)       printf '%s\n' "$RUNS" ;;
      retros)     printf '%s\n' "$RETROS" ;;
      reviews)    printf '%s\n' "$REVIEWS" ;;
      specs)      printf '%s\n' "$SPECS" ;;
      provenance) printf '%s\n' "$PROVENANCE" ;;
      *) die "unknown key: $GET_KEY (base|todo|loops|runs|retros|reviews|specs|provenance)" ;;
    esac
    ;;
  print)
    printf 'shell-team paths (rule: %s, root: %s)\n' "$RULE" "$ROOT"
    printf '  base       %s\n' "$BASE"
    printf '  todo       %s\n' "$TODO"
    printf '  loops      %s\n' "$LOOPS"
    printf '  runs       %s\n' "$RUNS"
    printf '  retros     %s\n' "$RETROS"
    printf '  reviews    %s\n' "$REVIEWS"
    printf '  specs      %s\n' "$SPECS"
    printf '  provenance %s\n' "$PROVENANCE"
    ;;
esac
exit 0
