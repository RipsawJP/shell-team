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

# ---------------------------------------------------------------------------
# Ignored-base notice (T-1042): a resolved base dir that a git ignore rule
# matches and holds no tracked file voids the loop's "commit this
# immediately" disciplines (provenance, interventions, the board) while
# every other gate — seam checkers, the T-073 uncommitted-diff guard, `git
# status` itself — stays green, because staging an ignored path is a no-op.
# Advisory only (D2): this script is a scaffolder, not a checker, and the
# README / docs/adopting.md both declare ignoring the base dir a supported
# adopter choice — this notice only makes that choice visible. Emitted AFTER
# scaffolding (D9): a directory-form ignore rule (<base>/) cannot match a
# path that does not exist yet, so probing before the base dir is created
# would be silently vacuous in the common case. D8: this probe and its three
# message bodies are duplicated byte-for-byte in bin/team-paths.sh rather
# than shared, per this repo's zero-dependency, standalone-bin-script
# convention.
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
#        git repository anywhere" case is preserved as N2 by matching git's
#        own "not a git repository" fatal text — a bare exit code alone
#        cannot distinguish it from an ownership/permission failure, which
#        correctly stays N3. (`team-init.sh` never reaches this branch in
#        the symmetry table's own fixtures, since every call site here is
#        given a real, `git init`-ed target — but the classification stays
#        byte-identical to `bin/team-paths.sh`'s per D8.)
#   M3 — `check-ignore` queried the resolved base with no trailing slash,
#        so a directory-form rule (`<base>/` — the form docs/adopting.md
#        recommends) silently misses whenever the base dir does not yet
#        exist on disk. D9's after-scaffolding ordering already makes this
#        script immune in practice (the base dir always exists by the time
#        this runs), but the query is normalized here too (`"${base%/}/"`)
#        for the byte-identical-probe guarantee D8 requires between the two
#        scripts.
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
      # up from $root) — git's own diagnostic names this specific reason.
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
      log_warn "$msg"
      ;;
    outside)
      printf -v msg 'the resolved base dir %s is not inside a git work tree, so whether it can be committed could not be determined and nothing written there is under version control.' "$base"
      log_warn "$msg"
      ;;
    undeterminable)
      printf -v msg 'whether the resolved base dir %s is matched by a git ignore rule could not be determined (git did not answer), so treat the durability of anything written there as unknown rather than as fine.' "$base"
      log_warn "$msg"
      ;;
    *) : ;;
  esac
}

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

# Ignored-base notice (T-1042): run AFTER scaffolding above, once the base
# dir actually exists on disk (D9) — see warn_ignored_base()'s header note.
warn_ignored_base "$TARGET" "$TEAM_RUN_BASE"

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
