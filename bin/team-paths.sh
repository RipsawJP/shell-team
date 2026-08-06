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
#   2. legacy layout       — if ROOT/tasks/loops/shell-team.contract.yaml
#                            exists, use the historical split layout
#                            (base=tasks, specs=docs/specs). The marker is
#                            the contract file itself (plugin-unique), NOT a
#                            bare `tasks/loops/` directory or a bare
#                            `tasks/todo.md`, so an unrelated host `tasks/`
#                            dir is never misdetected as a shell-team install.
#   3. default             — base=.shell-team (specs=.shell-team/specs).
#
# Derived paths (all ROOT-relative):
#   TEAM_RUN_BASE  TEAM_TODO  TEAM_LOOPS_DIR  TEAM_RUNS_DIR  TEAM_RETROS_DIR
#   TEAM_REVIEWS_DIR  TEAM_SPECS_DIR  TEAM_PROVENANCE_DIR  TEAM_INTERVENTIONS_DIR
#   TEAM_LESSONS
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
#                                         #   retros|reviews|specs|provenance|
#                                         #   interventions|lessons
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

# ---------------------------------------------------------------------------
# Ignored-base notice (T-1042): a resolved base dir that a git ignore rule
# matches and holds no tracked file voids the loop's "commit this
# immediately" disciplines (provenance, interventions, the board) while
# every other gate — seam checkers, the T-073 uncommitted-diff guard, `git
# status` itself — stays green, because staging an ignored path is a no-op.
# Advisory only (D2): this script is a resolver, not a checker, and the
# README / docs/adopting.md both declare ignoring the base dir a supported
# adopter choice — this notice only makes that choice visible. Fires on
# --print only (AC10: --export and --get never probe or warn). D8: this
# probe and its three message bodies are duplicated byte-for-byte in
# bin/team-init.sh rather than shared, per this repo's zero-dependency,
# standalone-bin-script convention.
#
# Codex round-1 review (M1-M3, .shell-team/reviews/T-1042.md), all fixed in
# the same round without touching frozen text:
#   M1 — `$base` can contain pathspec metacharacters (`validate_base` allows
#        e.g. `a*`, safe for shell word-splitting but not for git). `ls-files`
#        gets `:(literal)$base` (verified live: the config-based
#        core.literalPathspecs does NOT suppress `ls-files`'s own glob
#        expansion in this git version, but `:(literal)` magic does);
#        `check-ignore` gets `-c core.literalPathspecs=true` (the only
#        mechanism it accepts at all — it rejects `:(literal)` outright with
#        "pathspec magic not supported by this command").
#   M2 — `rev-parse --is-inside-work-tree`'s exit status ALONE is not a safe
#        N2/N3 discriminator: a bare repo exits 0 while printing "false" (was
#        falling through to a `check-ignore` failure -> wrongly N3), and a
#        dubious-ownership/permission/corruption failure is not the same
#        thing as "outside a work tree" (was always wrongly landing on N2).
#        Now: capture stdout+stderr together (they are mutually exclusive —
#        success prints only a boolean, failure prints only a message) and
#        classify by (rc, output) rather than rc alone. The "genuinely no
#        git repository anywhere" case (LA6, AC7) is preserved as N2 by
#        matching git's own "not a git repository" fatal text — a bare exit
#        code alone cannot distinguish it from an ownership/permission
#        failure, which correctly stays N3.
#   M3 — `check-ignore` queried the resolved base with no trailing slash,
#        so a directory-form rule (`<base>/` — the form docs/adopting.md
#        recommends) silently misses whenever the base dir does not yet
#        exist on disk (`--print` has no scaffolding step, unlike
#        `team-init.sh`'s D9 ordering). The query now always normalizes to
#        an explicit directory form (`"${base%/}/"`), independent of
#        on-disk existence; a bare-form rule still matches a directory-form
#        query (verified live), so `LA4`'s bare-form case is unaffected.
#   Minor #1 (ls-files error-swallowing) closed as a side effect of the M2
#   restructuring rather than deferred: `ls-files`'s own exit status is now
#   reflected into the undeterminable class instead of being discarded via
#   `|| true`, since the restructuring needed a single classify-then-emit
#   shape anyway and this was the same shape of check.
# ---------------------------------------------------------------------------
warn_ignored_base() {
  local root="$1" base="$2" msg class="" wt_out="" wt_rc=0 tracked="" tracked_rc=0 rc

  if ! command -v git >/dev/null 2>&1; then
    class="undeterminable"
  else
    # Capture stdout+stderr together: a successful rev-parse prints only the
    # boolean on stdout with nothing on stderr, and a failing one prints
    # only a fatal message on stderr with nothing on stdout — the two never
    # overlap, so merging them into one variable loses no information.
    if wt_out="$(git -C "$root" rev-parse --is-inside-work-tree 2>&1)"; then
      wt_rc=0
    else
      wt_rc=$?
    fi

    if [ "$wt_rc" -eq 0 ] && [ "$wt_out" = "true" ]; then
      # Inside a work tree: probe the tracked-file and ignore state below.
      if tracked="$(git -C "$root" ls-files -- ":(literal)$base" 2>/dev/null)"; then
        tracked_rc=0
      else
        tracked_rc=$?
      fi
      if [ "$tracked_rc" -ne 0 ]; then
        # ls-files itself failed (e.g. an unreadable/corrupt index) — its
        # own answer cannot be trusted either way, so this is undeterminable
        # rather than a silent (false) empty read.
        class="undeterminable"
      elif [ -n "$tracked" ]; then
        # Silent when at least one file under the base dir is already
        # tracked (D6): an adopter who has tracked part of the base dir has
        # decided to track it, and warning anyway would be a false positive.
        class=""
      else
        if git -C "$root" -c core.literalPathspecs=true check-ignore -q -- "${base%/}/"; then
          rc=0
        else
          rc=$?
        fi
        case "$rc" in
          0) class="ignored" ;;
          1) class="" ;;
          *) class="undeterminable" ;;
        esac
      fi
    elif [ "$wt_rc" -eq 0 ] && [ "$wt_out" = "false" ]; then
      # A bare repository (or cwd inside .git itself): a real work-tree
      # answer, just a negative one.
      class="outside"
    elif printf '%s' "$wt_out" | grep -qF -- 'not a git repository'; then
      # Genuinely outside any git repository at all (no .git found walking
      # up from $root) — git's own diagnostic names this specific reason,
      # which is what LA6 (no repo anywhere) exercises and needs kept as N2.
      class="outside"
    else
      # Any other rev-parse failure (dubious ownership, permission denied,
      # a corrupted repository, or any future message this does not
      # recognize) is NOT "outside a work tree" — it is undeterminable.
      class="undeterminable"
    fi
  fi

  case "$class" in
    ignored)
      printf -v msg 'the resolved base dir %s is matched by a git ignore rule and holds no tracked file, so everything the loop writes under it — the board, provenance, interventions and review records among them — cannot be committed and survives only in this working tree. Ignoring the base dir is a supported choice (see the README section on deciding whether the base dir belongs in git); if you meant these records to be versioned, remove or override the ignore rule that matches this path.' "$base"
      printf 'team-paths: %s\n' "$msg" >&2 || true
      ;;
    outside)
      printf -v msg 'the resolved base dir %s is not inside a git work tree, so whether it can be committed could not be determined and nothing written there is under version control.' "$base"
      printf 'team-paths: %s\n' "$msg" >&2 || true
      ;;
    undeterminable)
      printf -v msg 'whether the resolved base dir %s is matched by a git ignore rule could not be determined (git did not answer), so treat the durability of anything written there as unknown rather than as fine.' "$base"
      printf 'team-paths: %s\n' "$msg" >&2 || true
      ;;
    *) : ;;
  esac
}

print_help() {
  cat <<'EOF'
Usage: team-paths.sh [--root DIR] (--export | --get KEY | --print)

Resolve where the shell-team loop's per-repo operating files live.

Precedence (highest first), against ROOT (default: current directory):
  1. $TEAM_RUN_BASE env   explicit override (repo-relative)
  2. legacy layout        if ROOT/tasks/loops/shell-team.contract.yaml exists -> base=tasks, specs=docs/specs
  3. default              base=.shell-team, specs=.shell-team/specs

Modes:
  --export        Print `export VAR=...` lines (eval-safe) for all TEAM_* vars.
  --get KEY       Print one path. KEY ∈ base|todo|loops|runs|retros|reviews|specs|provenance|interventions|lessons.
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
INTERVENTIONS="$BASE/interventions"
LESSONS="$BASE/lessons.md"

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
    printf 'export TEAM_INTERVENTIONS_DIR=%q\n' "$INTERVENTIONS"
    printf 'export TEAM_LESSONS=%q\n'       "$LESSONS"
    ;;
  get)
    case "$GET_KEY" in
      base)          printf '%s\n' "$BASE" ;;
      todo)          printf '%s\n' "$TODO" ;;
      loops)         printf '%s\n' "$LOOPS" ;;
      runs)          printf '%s\n' "$RUNS" ;;
      retros)        printf '%s\n' "$RETROS" ;;
      reviews)       printf '%s\n' "$REVIEWS" ;;
      specs)         printf '%s\n' "$SPECS" ;;
      provenance)    printf '%s\n' "$PROVENANCE" ;;
      interventions) printf '%s\n' "$INTERVENTIONS" ;;
      lessons)       printf '%s\n' "$LESSONS" ;;
      *) die "unknown key: $GET_KEY (base|todo|loops|runs|retros|reviews|specs|provenance|interventions|lessons)" ;;
    esac
    ;;
  print)
    printf 'shell-team paths (rule: %s, root: %s)\n' "$RULE" "$ROOT"
    printf '  %-13s %s\n' "base"          "$BASE"
    printf '  %-13s %s\n' "todo"          "$TODO"
    printf '  %-13s %s\n' "loops"         "$LOOPS"
    printf '  %-13s %s\n' "runs"          "$RUNS"
    printf '  %-13s %s\n' "retros"        "$RETROS"
    printf '  %-13s %s\n' "reviews"       "$REVIEWS"
    printf '  %-13s %s\n' "specs"         "$SPECS"
    printf '  %-13s %s\n' "provenance"    "$PROVENANCE"
    printf '  %-13s %s\n' "interventions" "$INTERVENTIONS"
    printf '  %-13s %s\n' "lessons"       "$LESSONS"
    warn_ignored_base "$ROOT" "$BASE"
    ;;
esac
exit 0
