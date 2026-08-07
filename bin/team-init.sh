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
log_warn() { printf 'WARN: %s\n' "$*" >&2 || true; }
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
  <base>/interventions/.gitkeep
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
# Ignored-base verdict (T-1046, GitHub issue #167): after scaffolding
# completes, report whether the resolved base dir is git-ignored — an
# adopter in that state gets a loop that reports success while committing
# nothing, because every record the loop writes lands in a directory git
# refuses to stage. This is advisory only (see docs/adopting.md: ignoring
# the base dir is the adopter's own call); team-init never fails because of
# a verdict, an undeterminable read, or a missing git.
#
# The classification below is a direct transcription of the nine-row
# decision table frozen in this task's spec
# (.shell-team/specs/T-1046-ignored-base-verdict.md, "The frozen decision
# table") — DT0 through DT8. Only two channels are read, both admissible
# under that spec's rule (a documented contract, read as a machine value):
#   - `git rev-parse --is-inside-work-tree`, read as rc + a stdout boolean.
#   - `git check-ignore -q -- "./<base>/"` (normalized: `./`-prefixed, one
#     trailing slash, no explicit pathspec-magic annotation), read as its
#     documented exit status 0/1/128.
# No git diagnostic text is ever read for any purpose. stdout and stderr are
# always sent to genuinely separate destinations, never merged onto one fd.
# ---------------------------------------------------------------------------

# git_probe <args...>
# Every git call this mechanism makes goes through here: LC_ALL=C pinned,
# and every GIT_* variable whose ambient value could redirect or pollute the
# read is unset for the duration of the call (belt-and-suspenders hygiene —
# stream separation below is what actually neutralizes GIT_TRACE; this closes
# the ambient-environment class on top of it). Always scoped to $TARGET via
# `-C`, since this script never `cd`s into it.
git_probe() {
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_LITERAL_PATHSPECS \
      -u GIT_GLOB_PATHSPECS -u GIT_ICASE_PATHSPECS -u GIT_NOGLOB_PATHSPECS \
      -u GIT_TRACE -u GIT_TRACE2 -u GIT_TRACE2_EVENT -u GIT_CONFIG_GLOBAL \
      -u GIT_CONFIG_SYSTEM LC_ALL=C git -C "$TARGET" "$@"
}

# emit_ignored_base_v1 — DT5. The resolved base dir is git-ignored.
emit_ignored_base_v1() {
  log_warn "shell-team: git reports the resolved base dir as ignored: $TEAM_RUN_BASE"
  log_warn "shell-team: everything the loop writes under it (the board, provenance,"
  log_warn "shell-team: interventions and review records among them) cannot be"
  log_warn "shell-team: committed while that rule matches, so the loop's commit steps"
  log_warn "shell-team: will report success having committed nothing."
  log_warn "shell-team: If that is deliberate this is not an error. If it is not,"
  log_warn "shell-team: re-include the base dir before the loop writes its first"
  log_warn "shell-team: record (see docs/adopting.md)."
}

# emit_ignored_base_v2 — DT7 / DT8. check-ignore did not return a documented
# ignored/not-ignored answer, so no verdict is reported.
emit_ignored_base_v2() {
  log_warn "shell-team: could not determine whether the resolved base dir is ignored:"
  log_warn "shell-team: $TEAM_RUN_BASE"
  log_warn "shell-team: this is a git work tree, but git check-ignore did not return"
  log_warn "shell-team: one of its documented ignored / not-ignored answers, so no"
  log_warn "shell-team: verdict is reported here. If the loop's records have to be"
  log_warn "shell-team: committable, check the dir against your ignore rules yourself."
}

# report_ignored_base_verdict — the whole nine-row classification, DT0-DT8.
# Rows are evaluated in id order; the first row whose measured input matches
# decides the outcome, and this function always returns 0 (D2: advisory, no
# fail-closed exit anywhere in this mechanism).
report_ignored_base_verdict() {
  # DT0: no git channel exists to read.
  command -v git >/dev/null 2>/dev/null || return 0

  # Read the work-tree channel with stdout and stderr captured to genuinely
  # separate destinations (stderr discarded — its diagnostic text is never
  # read, only its absence-of-content matters, and discarding satisfies
  # that trivially without merging streams). `if var=$(...)` is the guard
  # that keeps a nonzero git exit from tripping this script's own errexit.
  local wt_out wt_rc=0
  if wt_out="$(git_probe rev-parse --is-inside-work-tree 2>/dev/null)"; then
    wt_rc=0
  else
    wt_rc=$?
  fi

  if [ "$wt_rc" -eq 0 ] && [ "$wt_out" = "true" ]; then
    : # DT1 — inside a work tree; continue to the check-ignore probe below.
  elif [ "$wt_rc" -eq 0 ] && [ "$wt_out" = "false" ]; then
    return 0 # DT2 — a bare repository; no work-tree ignore answer exists.
  elif [ "$wt_rc" -eq 0 ]; then
    return 0 # DT3 — outside the documented print contract; unreachable in practice.
  else
    return 0 # DT4 — at least five fatal causes collapse to this exit alone.
  fi

  local ci_rc=0
  if git_probe check-ignore -q -- "./${TEAM_RUN_BASE%/}/" >/dev/null 2>/dev/null; then
    ci_rc=0
  else
    ci_rc=$?
  fi

  if [ "$ci_rc" -eq 0 ]; then
    emit_ignored_base_v1 # DT5
  elif [ "$ci_rc" -eq 1 ]; then
    : # DT6 — none of the provided paths are ignored; stay silent.
  elif [ "$ci_rc" -eq 128 ]; then
    emit_ignored_base_v2 # DT7
  else
    emit_ignored_base_v2 # DT8 — outside the documented exit-status set; unreachable in practice.
  fi
  return 0
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
ensure_gitkeep "$TEAM_INTERVENTIONS_DIR"
# Cross-tool pointer/mirror doc, under the base dir (never the host root). It is
# a portable pointer to the truth sources, not a source of truth or a changelog.
copy_template "$AGENTS_TPL"   "$TEAM_RUN_BASE/AGENTS.md"
# Per-repo test-run recipe (T-060). Append-only asset the engineer/QA read
# first and extend across tasks — protected: never overwritten, even by --force.
copy_template_protected "$RECIPE_TPL" "$TEAM_RUN_BASE/test-recipe.md"
copy_template "$GITIGNORE_TPL" "$TEAM_RUN_BASE/.gitignore"

# Scaffolding is complete (the base dir now exists on disk, whatever it
# contained before) — only now is it meaningful to ask git whether that dir
# is ignored. See the ignored-base verdict block above for the mechanism.
report_ignored_base_verdict

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
