#!/usr/bin/env bash
# bin/team-init.sh — scaffold an adopting repository for the shell-team loop.
#
# Creates the per-repo *instances* the shell-team pipeline needs (todo board, loop
# contract, runs/retros/reviews/specs dirs) under a SINGLE base directory so the
# plugin's footprint never scatters across the host's mainline tree. The base
# dir is resolved by bin/team-paths.sh (default `.shell-team/`; override with
# $TEAM_RUN_BASE; an existing legacy `tasks/` layout is detected and reused).
#
# It does NOT mutate any host-root file: it never edits the target's CLAUDE.md
# and never appends to the target's .gitignore. Telemetry is ignored via a
# self-contained `<base>/.gitignore`, so the host root stays pristine. Adoption
# guidance lives in docs/adopting.md (surfaced by the team-init skill).
#
# Idempotent by design (mirrors bin/install's skip-with-warning semantics):
#   - existing scaffold files are skipped (use --force to overwrite)
# Re-running is therefore safe and non-destructive.
#
# External dependencies: bash + standard POSIX tools (cp, mkdir, printf, grep).
# No JSON/YAML processors and no language runtimes (per the framework's
# external-dependency-zero rule).
#
# Usage:
#   bin/team-init.sh [--force] <target_path>
#   bin/team-init.sh --help
#
# Exit codes:
#   0  success
#   2  argument / usage error

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate the shell-team repository root (where this script lives), so the
# templates resolve regardless of cwd / symlinks.
# ---------------------------------------------------------------------------
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"

# ---------------------------------------------------------------------------
# I/O helpers.
# ---------------------------------------------------------------------------
log_err()  { printf '%s\n' "$*" >&2 || true; }
log_warn() { printf 'WARN: %s\n' "$*" >&2; }
die()      { log_err "ERROR: $*"; exit 2; }

print_help() {
  cat <<'EOF'
Usage: bin/team-init.sh [--force] <target_path>

Scaffold an adopting repository for the shell-team loop.

Creates in <target_path>, under the resolved base dir (default .shell-team/;
override with $TEAM_RUN_BASE; an existing tasks/ layout is detected and reused):
  <base>/todo.md                       (from templates/todo-template.md)
  <base>/loops/shell-team.contract.yaml  (from templates/shell-team.contract.yaml)
  <base>/runs/.gitkeep
  <base>/retros/.gitkeep
  <base>/reviews/.gitkeep
  <base>/specs/.gitkeep                 (docs/specs/ in a legacy layout)
  <base>/provenance/.gitkeep
  <base>/AGENTS.md                      (from templates/AGENTS.md; cross-tool pointer doc)
  <base>/test-recipe.md                 (from templates/test-recipe.md; per-repo test-run
                                         recipe — protected: never overwritten, even with --force)
  <base>/.gitignore                     (ignores runs/ telemetry; host root untouched)
Does NOT modify <target_path>/CLAUDE.md or <target_path>/.gitignore.

Options:
  --force         Overwrite existing scaffold files. Default: skip with warning.
  --help, -h      Show this help and exit.

Idempotent: re-running skips existing files and never modifies host-root files.
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------
FORCE=0
positionals=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        positionals+=("$1")
        shift
      done
      ;;
    --*)
      die "unknown flag: $1"
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

case "${#positionals[@]}" in
  0) die "missing required <target_path> (see --help)" ;;
  1) TARGET="${positionals[0]}" ;;
  *) die "expected exactly one <target_path>, got ${#positionals[@]}: ${positionals[*]}" ;;
esac

[ -e "$TARGET" ] || die "target path does not exist: $TARGET (mkdir is intentionally not done; create it first)"
[ -d "$TARGET" ] || die "target path is not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# Verify the templates we rely on are present (defensive against layout drift).
TODO_TPL="$TEMPLATES_DIR/todo-template.md"
CONTRACT_TPL="$TEMPLATES_DIR/shell-team.contract.yaml"
GITIGNORE_TPL="$TEMPLATES_DIR/shell-team.gitignore"
AGENTS_TPL="$TEMPLATES_DIR/AGENTS.md"
RECIPE_TPL="$TEMPLATES_DIR/test-recipe.md"
for tpl in "$TODO_TPL" "$CONTRACT_TPL" "$GITIGNORE_TPL" "$AGENTS_TPL" "$RECIPE_TPL"; do
  [ -f "$tpl" ] || die "template missing: $tpl (shell-team layout drift?)"
done

# Resolve the base dir + derived artifact paths for this target via the single
# source of truth (bin/team-paths.sh). All TEAM_* vars below are target-relative.
# Capture-then-eval so a resolver failure (e.g. an invalid $TEAM_RUN_BASE that
# would escape into the host root) surfaces as a clear error here instead of
# being swallowed by command substitution and leaving the TEAM_* vars unset.
if ! resolver_exports="$(bash "$SCRIPT_DIR/team-paths.sh" --root "$TARGET" --export)"; then
  die "could not resolve operating paths (see team-paths.sh error above) — check \$TEAM_RUN_BASE"
fi
eval "$resolver_exports"

# ---------------------------------------------------------------------------
# Counters for the closing summary.
# ---------------------------------------------------------------------------
created=0
skipped=0

# copy_template <src_abs> <dest_rel>
# Copy a template into the target, skipping (with a warning) when the
# destination already exists unless --force is set.
copy_template() {
  local src="$1" dest_rel="$2"
  local dest="$TARGET/$dest_rel"
  mkdir -p "$(dirname "$dest")"
  # -L as well as -e: a DANGLING symlink is invisible to -e, but `cp` would
  # follow it and write outside the base dir (violating the host-root-untouched
  # invariant). Any occupant — file, dir, or symlink of either kind — counts.
  if { [ -e "$dest" ] || [ -L "$dest" ]; } && [ "$FORCE" -eq 0 ]; then
    log_warn "skipped existing file: $dest_rel (use --force to overwrite)"
    skipped=$((skipped + 1))
    return 0
  fi
  # --force still must not follow a symlink (dangling or live) to write outside
  # the base dir: replace the link with a real file instead of writing through it.
  if [ -L "$dest" ]; then
    rm -f "$dest"
  fi
  cp "$src" "$dest"
  printf 'created: %s\n' "$dest_rel"
  created=$((created + 1))
}

# copy_template_protected <src_abs> <dest_rel>
# Like copy_template, but the destination is NEVER overwritten — not even with
# --force. Used for append-only assets (the test recipe) whose content is
# written by engineers across tasks: an unconditional --force overwrite would
# destroy that accumulated record, so existence always wins.
copy_template_protected() {
  local src="$1" dest_rel="$2"
  local dest="$TARGET/$dest_rel"
  mkdir -p "$(dirname "$dest")"
  # -L as well as -e: a DANGLING symlink is invisible to -e, but `cp` would
  # follow it and write the recipe content OUTSIDE the base dir (violating the
  # host-root-untouched invariant). Any occupant — file, dir, or symlink of
  # either kind — means "already claimed": skip, never write through it.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    log_warn "skipped existing file: $dest_rel (protected append-only asset; never overwritten, even with --force)"
    skipped=$((skipped + 1))
    return 0
  fi
  cp "$src" "$dest"
  printf 'created: %s\n' "$dest_rel"
  created=$((created + 1))
}

# ensure_gitkeep <dir_rel>
# Create an empty .gitkeep so an otherwise-empty directory is trackable.
ensure_gitkeep() {
  local dir_rel="$1"
  local keep="$TARGET/$dir_rel/.gitkeep"
  mkdir -p "$TARGET/$dir_rel"
  # -L as well as -e: a DANGLING symlink is invisible to -e, but `: >` would
  # follow it and write outside the base dir. Treat any occupant as claimed.
  if [ -e "$keep" ] || [ -L "$keep" ]; then
    log_warn "skipped existing file: $dir_rel/.gitkeep"
    skipped=$((skipped + 1))
    return 0
  fi
  : > "$keep"
  printf 'created: %s/.gitkeep\n' "$dir_rel"
  created=$((created + 1))
}

# ---------------------------------------------------------------------------
# Scaffold the instance files under the resolved base dir. No host-root file is
# ever touched — telemetry is ignored via a self-contained <base>/.gitignore.
# ---------------------------------------------------------------------------
copy_template "$TODO_TPL"     "$TEAM_TODO"
copy_template "$CONTRACT_TPL" "$TEAM_LOOPS_DIR/shell-team.contract.yaml"
ensure_gitkeep "$TEAM_RUNS_DIR"
ensure_gitkeep "$TEAM_RETROS_DIR"
ensure_gitkeep "$TEAM_REVIEWS_DIR"
ensure_gitkeep "$TEAM_SPECS_DIR"
ensure_gitkeep "$TEAM_PROVENANCE_DIR"
# Cross-tool pointer/mirror doc, under the base dir (never the host root). It is
# a portable pointer to the truth sources, not a source of truth or a changelog.
copy_template "$AGENTS_TPL"   "$TEAM_RUN_BASE/AGENTS.md"
# Per-repo test-run recipe (T-060). Append-only asset the engineer/QA read
# first and extend across tasks — protected: never overwritten, even by --force.
copy_template_protected "$RECIPE_TPL" "$TEAM_RUN_BASE/test-recipe.md"
copy_template "$GITIGNORE_TPL" "$TEAM_RUN_BASE/.gitignore"

# ---------------------------------------------------------------------------
# Summary + adoption nudge. The host's CLAUDE.md and root .gitignore are
# deliberately left untouched (see docs/adopting.md for the operating rules).
# ---------------------------------------------------------------------------
printf '\nteam-init: %d created/updated, %d skipped in %s\n' "$created" "$skipped" "$TARGET"
printf 'Operating files live under: %s/ (host root left untouched).\n' "$TEAM_RUN_BASE"
# In a legacy layout the specs dir sits outside the base dir (the historical
# split-root quirk: docs/specs/), so call it out rather than implying it is
# under the base.
if [ "$TEAM_SPECS_DIR" != "$TEAM_RUN_BASE/specs" ]; then
  printf 'Specs live under: %s/ (legacy split-root layout).\n' "$TEAM_SPECS_DIR"
fi
printf 'Telemetry (%s/) is ignored via %s/.gitignore — commit the rest if you want it tracked.\n' \
  "$TEAM_RUNS_DIR" "$TEAM_RUN_BASE"
printf 'Cross-tool pointer doc: %s/AGENTS.md (points other tools at the truth sources; not a root convention file).\n' \
  "$TEAM_RUN_BASE"
printf 'Test recipe: %s/test-recipe.md (engineer/QA read it first, append established procedures; never overwritten).\n' \
  "$TEAM_RUN_BASE"
# shellcheck disable=SC2016  # backticks here are literal text for the user, not a subshell.
printf 'Next: run `/shell-team:run <your request>` from the target repo. See docs/adopting.md.\n'
exit 0
