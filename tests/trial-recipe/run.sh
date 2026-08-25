#!/usr/bin/env bash
# run.sh — T-1098: execute the shipped trial-adoption recipe end to end, in
# throwaway git repositories, turning T-1094's three deferred AC10 findings
# (recorded verbatim at .shell-team/reviews/T-1094.md) into permanent
# regression locks:
#
#   1. (round 1, Major 6) "AC10 doesn't exercise the Input space it claims to cover" — exercised here
#      in both the default and legacy layouts, and against both a hostile and a hermetic global
#      excludes scope.
#   2. (round 2, Major 1) "AC10's scratch git operations don't pin away ambient global git configuration"
#      — this suite establishes its own scratch global-config scope before running any fixture, and
#      proves it with a hermetic control and an adverse-excludes control.
#   3. (round 2, Major 2) "AC10 verifies the board path is committed but never verifies the specs path"
#      — both resolved paths are asserted committed in both layouts, with a legacy-only negative
#      control that fails when the second `git add` argument is dropped.
#
# The recipe is EXTRACTED from docs/adopting.md (never docs/adopting.ja.md
# for execution — that mirror is used only for the byte-identity check
# below) via tests/trial-recipe/extract-recipe.sh, never retyped, so this
# suite verifies the shipped recipe rather than a transcribed fiction of it.
#
# Idioms reused verbatim from tests/team-init/run.sh: the $TMPDIR-backed
# git-fixture root with its own trap, GIT_CEILING_DIRECTORIES pinned at that
# root, the fail()/pass() helpers, the `set +e` non-zero-exit capture idiom,
# and reserved-domain throwaway identity (t@example.invalid / t) passed
# per-command or via a repo-local config, never global.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

EXTRACT="$REPO_ROOT/tests/trial-recipe/extract-recipe.sh"
TEAM_INIT_BIN="$REPO_ROOT/bin/team-init.sh"
TEAM_PATHS_BIN="$REPO_ROOT/bin/team-paths.sh"
ADOPTING_EN="$REPO_ROOT/docs/adopting.md"
ADOPTING_JA="$REPO_ROOT/docs/adopting.ja.md"
TEMPLATE_CONTRACT="$REPO_ROOT/templates/shell-team.contract.yaml"

# T-1044: a suite that builds throwaway `git init` repositories keeps its
# scratch root under ${TMPDIR:-/tmp} ONLY — no $HERE fallback — since a
# fallback would put a nested .git inside this checkout's own work tree,
# which a sandboxed run denies.
GIT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/trial-recipe-test-git.XXXXXX")"

# T-1097 / T-1042: GIT_CEILING_DIRECTORIES stops git's upward search for an
# ancestor repository at this root (this repository's own work tree, in
# particular), so every fixture below is non-vacuously its own repository.
GIT_CEILING_DIRECTORIES="$GIT_TMP"
export GIT_CEILING_DIRECTORIES

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$GIT_TMP"' EXIT

tp() { env -u TEAM_RUN_BASE bash "$TEAM_PATHS_BIN" "$@"; }
ti() { env -u TEAM_RUN_BASE bash "$TEAM_INIT_BIN" "$@"; }

set_identity() {
  # Persisted repo-local throwaway identity (T-1042's spelling): needed
  # because the shipped `git commit` line carries no `-c` flags of its own
  # and this suite must not rewrite the extracted text to add one.
  git -C "$1" config user.email t@example.invalid
  git -C "$1" config user.name t
}

# subst_recipe [integration-branch] — read extracted recipe text on stdin,
# apply the closed, three-member substitution list, print the result.
# `team-init.sh` / `team-paths.sh` are always substituted to absolute
# bin/ paths (an adopter reaches them via PATH from the loaded plugin; a
# fixture cannot); `<integration-branch>` is substituted only when a
# non-empty value is supplied (the setup fence never contains it).
subst_recipe() {
  local ibranch="${1:-}" text
  text="$(cat)"
  printf '%s\n' "$text" | sed \
    -e "s|<integration-branch>|$ibranch|g" \
    -e "s|team-init\.sh|$TEAM_INIT_BIN|g" \
    -e "s|team-paths\.sh|$TEAM_PATHS_BIN|g"
}

# run_lines_in_repo <dir> <text> — eval each non-empty line of <text> with
# cwd set to <dir>, stopping (return 1) at the first failure.
run_lines_in_repo() {
  local dir="$1" text="$2" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ( cd "$dir" && eval "$line" ) || return 1
  done <<EOF
$text
EOF
  return 0
}

# =============================================================================
# Requirement 2 (hermeticity half): establish a scratch global-config scope
# BEFORE any fixture below runs, so the operator's real global git
# configuration can never reach any of them. GIT_CONFIG_GLOBAL is tried
# first (feature detection via a live probe, never a version assertion); a
# redirected HOME + XDG_CONFIG_HOME is the fallback. Neither working is a
# hard stop — this suite never proceeds unisolated.
# =============================================================================
SCRATCH_CFG="$GIT_TMP/global-cfg"
mkdir -p "$SCRATCH_CFG"
EMPTY_EXCLUDES="$SCRATCH_CFG/empty-excludes"
: > "$EMPTY_EXCLUDES"
GLOBAL_MECH=""
GLOBAL_CFG_FILE=""

# write_global_excludes <path> — point the scratch global-config scope's
# core.excludesFile at <path>. Written directly into the scratch config FILE
# rather than through the `--global` git-config invocation (this suite's own
# hygiene lock forbids that exact command spelling from appearing here, since
# it writes real global state on a machine with no scratch redirection
# active) — a config file is
# plain text, and `[core]\n\texcludesFile = <path>\n` is exactly what that
# invocation would have produced, just written by hand into a path this
# suite already owns and cleans up.
write_global_excludes() {
  printf '[core]\n\texcludesFile = %s\n' "$1" > "$GLOBAL_CFG_FILE"
}

probe_repo_sees() {
  # probe_repo_sees <expected-value> — a fresh throwaway repo's own
  # `core.excludesFile`, read under the CURRENTLY EXPORTED scratch scope,
  # must equal <expected-value>.
  local expected="$1" probe seen
  probe="$GIT_TMP/probe-$$-$RANDOM"
  rm -rf "$probe"
  mkdir -p "$probe"
  git -C "$probe" init -q >/dev/null 2>&1 || return 1
  seen="$(git -C "$probe" config --get core.excludesFile 2>/dev/null || true)"
  rm -rf "$probe"
  [ "$seen" = "$expected" ]
}

try_git_config_global() {
  local gcfg="$SCRATCH_CFG/gitconfig"
  GLOBAL_CFG_FILE="$gcfg"
  write_global_excludes "$EMPTY_EXCLUDES"
  export GIT_CONFIG_GLOBAL="$gcfg"
  probe_repo_sees "$EMPTY_EXCLUDES" || { unset GIT_CONFIG_GLOBAL; GLOBAL_CFG_FILE=""; return 1; }
  return 0
}

try_home_redirect() {
  local h="$SCRATCH_CFG/home"
  mkdir -p "$h/.config/git"
  GLOBAL_CFG_FILE="$h/.gitconfig"
  export HOME="$h" XDG_CONFIG_HOME="$h/.config"
  write_global_excludes "$EMPTY_EXCLUDES"
  probe_repo_sees "$EMPTY_EXCLUDES" || { GLOBAL_CFG_FILE=""; return 1; }
  return 0
}

if try_git_config_global; then
  GLOBAL_MECH="GIT_CONFIG_GLOBAL"
elif try_home_redirect; then
  GLOBAL_MECH="HOME/XDG_CONFIG_HOME"
else
  fail "T-1098 hermetic-global: could not establish a scratch global-config scope via either GIT_CONFIG_GLOBAL or HOME/XDG_CONFIG_HOME redirection — refusing to run unisolated"
fi

# Positive control: with the scratch scope active and an EMPTY excludes
# file planted, an ordinary fixture's base dir must NOT be reported ignored
# — proving ordinary fixtures run unexcluded regardless of the operator's
# real configuration.
HERM_CTRL="$GIT_TMP/hermetic-control"
mkdir -p "$HERM_CTRL"
git -C "$HERM_CTRL" init -q >/dev/null 2>&1 || fail "T-1098 hermetic-global: control repo init failed"
HERM_BD="$(tp --root "$HERM_CTRL" --get base)"
[ -n "$HERM_BD" ] || fail "T-1098 hermetic-global: could not resolve the control fixture's base dir"
if git -C "$HERM_CTRL" check-ignore -q "$HERM_BD"; then
  fail "T-1098 hermetic-global: ordinary fixture's base dir is ignored despite an EMPTY scratch excludes file"
fi
pass "T-1098 hermetic-global: scratch global-config scope established via $GLOBAL_MECH; an ordinary fixture is unaffected"

# =============================================================================
# AC4 / T-1098 default-manual: the manual (two-command) path, default layout
# =============================================================================
D1="$GIT_TMP/default-manual"
mkdir -p "$D1"
git -C "$D1" init -q >/dev/null 2>&1 || fail "T-1098 default-manual: git init failed (control)"
set_identity "$D1"
git -C "$D1" commit -q --allow-empty -m init >/dev/null 2>&1 || fail "T-1098 default-manual: initial commit failed (control)"
D1_INIT_BRANCH="$(git -C "$D1" symbolic-ref --short HEAD 2>/dev/null)"
[ -n "$D1_INIT_BRANCH" ] || fail "T-1098 default-manual: fixture has no current branch (control)"
D1_INIT_TIP="$(git -C "$D1" rev-parse HEAD 2>/dev/null)"
[ -n "$D1_INIT_TIP" ] || fail "T-1098 default-manual: fixture has no HEAD commit (control)"
D1_COMMITS_BEFORE="$(git -C "$D1" rev-list --count HEAD 2>/dev/null)"
[ -n "$D1_COMMITS_BEFORE" ] || fail "T-1098 default-manual: could not count pre-run commits (control)"

RAW_SETUP="$(bash "$EXTRACT" "$ADOPTING_EN" setup)" || fail "T-1098 default-manual: extraction of the setup block failed"
RAW_TEARDOWN="$(bash "$EXTRACT" "$ADOPTING_EN" teardown)" || fail "T-1098 default-manual: extraction of the teardown block failed"
SUB_SETUP_D1="$(printf '%s\n' "$RAW_SETUP" | subst_recipe)"

run_lines_in_repo "$D1" "$SUB_SETUP_D1" || fail "T-1098 default-manual: the substituted setup lines did not all succeed"

[ "$(git -C "$D1" symbolic-ref --short HEAD 2>/dev/null)" = "trial/one-ticket" ] \
  || fail "T-1098 default-manual: HEAD is not trial/one-ticket after the setup block"
D1_BASE="$(tp --root "$D1" --get base)"
[ -n "$D1_BASE" ] || fail "T-1098 default-manual: could not resolve the fixture's base dir"
[ -d "$D1/$D1_BASE" ] || fail "T-1098 default-manual: the scaffold did not land at the resolved base dir"
D1_STATUS="$(git -C "$D1" status --porcelain 2>/dev/null)"
[ -z "$D1_STATUS" ] || fail "T-1098 default-manual: working tree is not clean after the setup block: $D1_STATUS"
D1_COMMITS_AFTER="$(git -C "$D1" rev-list --count HEAD 2>/dev/null)"
[ "$D1_COMMITS_AFTER" = "$((D1_COMMITS_BEFORE + 1))" ] \
  || fail "T-1098 default-manual: expected exactly one new commit (before=$D1_COMMITS_BEFORE after=$D1_COMMITS_AFTER)"
pass "T-1098 default-manual: the extracted setup fence runs end to end in a default-layout fixture"

# =============================================================================
# AC5 / T-1098 flag-path: the one-step flag form reaches the same end state
# =============================================================================
D2="$GIT_TMP/default-flag"
mkdir -p "$D2"
git -C "$D2" init -q >/dev/null 2>&1 || fail "T-1098 flag-path: git init failed (control)"
set_identity "$D2"
git -C "$D2" commit -q --allow-empty -m init >/dev/null 2>&1 || fail "T-1098 flag-path: initial commit failed (control)"

RAW_FLAG_LINE="$(bash "$EXTRACT" "$ADOPTING_EN" flag)" || fail "T-1098 flag-path: extraction of the flag prose failed"
# shellcheck disable=SC2016
FLAG_INVOCATION="$(printf '%s\n' "$RAW_FLAG_LINE" | grep -oE '`[^`]*`' | grep -F -- 'team-init.sh --trial-branch ' | sed -e 's/^`//' -e 's/`$//' | head -n1)"
[ -n "$FLAG_INVOCATION" ] || fail "T-1098 flag-path: could not isolate the one-step invocation from the extracted flag prose"
SUB_FLAG="$(printf '%s\n' "$FLAG_INVOCATION" | subst_recipe)"
SUB_SETUP_D2="$(printf '%s\n' "$RAW_SETUP" | subst_recipe)"
# The flag path replaces the first two setup lines (git switch -c, team-init.sh)
# with the one-step invocation, then reuses the same extracted git add / git
# commit lines (setup lines 3 and 4).
D2_ADD_COMMIT="$(printf '%s\n' "$SUB_SETUP_D2" | tail -n 2)"

run_lines_in_repo "$D2" "$SUB_FLAG" || fail "T-1098 flag-path: the one-step invocation did not succeed"
run_lines_in_repo "$D2" "$D2_ADD_COMMIT" || fail "T-1098 flag-path: the reused git add / git commit lines did not succeed"

D1_TRACKED="$(git -C "$D1" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | LC_ALL=C sort)"
D2_TRACKED="$(git -C "$D2" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | LC_ALL=C sort)"
[ -n "$D1_TRACKED" ] || fail "T-1098 flag-path: the manual fixture's tracked-path list is empty (control)"
[ -n "$D2_TRACKED" ] || fail "T-1098 flag-path: the flag fixture's tracked-path list is empty (control)"
[ "$(git -C "$D2" symbolic-ref --short HEAD 2>/dev/null)" = "$(git -C "$D1" symbolic-ref --short HEAD 2>/dev/null)" ] \
  || fail "T-1098 flag-path: the flag and manual fixtures disagree on the checked-out branch name"
[ "$D1_TRACKED" = "$D2_TRACKED" ] \
  || fail "T-1098 flag-path: the flag and manual fixtures disagree on the scaffold commit's tracked-path list"
D2_BASE="$(tp --root "$D2" --get base)"
D2_SPECS="$(tp --root "$D2" --get specs)"
D1_SPECS="$(tp --root "$D1" --get specs)"
[ "$D2_BASE" = "$D1_BASE" ] || fail "T-1098 flag-path: the flag and manual fixtures disagree on the resolved base dir"
[ "$D2_SPECS" = "$D1_SPECS" ] || fail "T-1098 flag-path: the flag and manual fixtures disagree on the resolved specs dir"
pass "T-1098 flag-path: the one-step --trial-branch form reaches the same end state as the manual two-command form"

# =============================================================================
# AC6 / T-1098 legacy-marker + AC7 / T-1098 marker-vacuity-control
# =============================================================================
DEFREF="$GIT_TMP/defref"
mkdir -p "$DEFREF"
LEGACY="$GIT_TMP/legacy"
mkdir -p "$LEGACY/tasks/loops"
test -s "$TEMPLATE_CONTRACT" || fail "T-1098 legacy-marker: templates/shell-team.contract.yaml is missing or empty (control)"
cp "$TEMPLATE_CONTRACT" "$LEGACY/tasks/loops/shell-team.contract.yaml"
test -s "$LEGACY/tasks/loops/shell-team.contract.yaml" || fail "T-1098 legacy-marker: seeded contract file is missing or empty"
git -C "$LEGACY" init -q >/dev/null 2>&1 || fail "T-1098 legacy-marker: git init failed (control)"
set_identity "$LEGACY"
git -C "$LEGACY" commit -q --allow-empty -m init >/dev/null 2>&1 || fail "T-1098 legacy-marker: initial commit failed (control)"

SUB_SETUP_LEGACY="$(printf '%s\n' "$RAW_SETUP" | subst_recipe)"
run_lines_in_repo "$LEGACY" "$SUB_SETUP_LEGACY" || fail "T-1098 legacy-marker: the extracted setup fence did not succeed in the legacy fixture"

DEFREF_BASE="$(tp --root "$DEFREF" --get base)"
DEFREF_SPECS="$(tp --root "$DEFREF" --get specs)"
LEGACY_BASE="$(tp --root "$LEGACY" --get base)"
LEGACY_SPECS="$(tp --root "$LEGACY" --get specs)"
for v in "$DEFREF_BASE" "$DEFREF_SPECS" "$LEGACY_BASE" "$LEGACY_SPECS"; do
  [ -n "$v" ] || fail "T-1098 legacy-marker: a resolved path is empty (control)"
done
[ "$DEFREF_BASE" != "$LEGACY_BASE" ] || fail "T-1098 legacy-marker: default and legacy base dirs did not differ"
[ "$DEFREF_SPECS" != "$LEGACY_SPECS" ] || fail "T-1098 legacy-marker: default and legacy specs dirs did not differ"
case "$DEFREF_SPECS" in
  "$DEFREF_BASE"/*) ;;
  *) fail "T-1098 legacy-marker: default layout's specs dir is not under its own base dir" ;;
esac
case "$LEGACY_SPECS" in
  "$LEGACY_BASE"/*) fail "T-1098 legacy-marker: legacy layout's specs dir is unexpectedly under its own base dir" ;;
  *) ;;
esac
pass "T-1098 legacy-marker: the legacy fixture (seeded with the contract FILE) resolves a genuinely different, split-root base/specs pair, and the setup fence runs there"

DIRONLY="$GIT_TMP/dironly"
mkdir -p "$DIRONLY/tasks/loops"
DIRONLY_BASE="$(tp --root "$DIRONLY" --get base)"
DIRONLY_SPECS="$(tp --root "$DIRONLY" --get specs)"
[ -n "$DIRONLY_BASE" ] && [ -n "$DIRONLY_SPECS" ] || fail "T-1098 marker-vacuity-control: a resolved path is empty (control)"
[ "$DIRONLY_BASE" = "$DEFREF_BASE" ] || fail "T-1098 marker-vacuity-control: a bare tasks/loops/ directory (no contract file) did not resolve to the default base dir"
[ "$DIRONLY_SPECS" = "$DEFREF_SPECS" ] || fail "T-1098 marker-vacuity-control: a bare tasks/loops/ directory (no contract file) did not resolve to the default specs dir"
[ "$DIRONLY_BASE" != "$LEGACY_BASE" ] || fail "T-1098 marker-vacuity-control: the vacuity control's base dir was not distinct from the legacy fixture's (positive control failed)"
pass "T-1098 marker-vacuity-control: a bare tasks/loops/ directory with no contract file resolves identically to the default layout, proving the legacy marker's teeth"

# =============================================================================
# AC8 / T-1098 both-paths-committed + T-1098 specs-arg-control
# =============================================================================
D1_LS="$(git -C "$D1" ls-tree -r --name-only HEAD 2>/dev/null)"
LEGACY_LS="$(git -C "$LEGACY" ls-tree -r --name-only HEAD 2>/dev/null)"
d1_under_base=0; d1_under_specs=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in "$D1_BASE"/*) d1_under_base=1 ;; esac
  case "$p" in "$D1_SPECS"/*) d1_under_specs=1 ;; esac
done <<EOF
$D1_LS
EOF
[ "$d1_under_base" -eq 1 ] || fail "T-1098 both-paths-committed: default fixture has no tracked path under its own base dir"
[ "$d1_under_specs" -eq 1 ] || fail "T-1098 both-paths-committed: default fixture has no tracked path under its own specs dir"

legacy_under_base=0; legacy_under_specs=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in "$LEGACY_BASE"/*) legacy_under_base=1 ;; esac
  case "$p" in "$LEGACY_SPECS"/*) legacy_under_specs=1 ;; esac
done <<EOF
$LEGACY_LS
EOF
[ "$legacy_under_base" -eq 1 ] || fail "T-1098 both-paths-committed: legacy fixture has no tracked path under its own base dir"
[ "$legacy_under_specs" -eq 1 ] || fail "T-1098 both-paths-committed: legacy fixture has no tracked path under its own specs dir (the regression this requirement guards)"
pass "T-1098 both-paths-committed: both resolved paths (base and specs) are committed in both the default and legacy layouts"

# Legacy-only negative control: dropping the git add's second argument.
LEGACY_ONEARG="$GIT_TMP/legacy-onearg"
mkdir -p "$LEGACY_ONEARG/tasks/loops"
cp "$TEMPLATE_CONTRACT" "$LEGACY_ONEARG/tasks/loops/shell-team.contract.yaml"
git -C "$LEGACY_ONEARG" init -q >/dev/null 2>&1 || fail "T-1098 specs-arg-control: git init failed (control)"
set_identity "$LEGACY_ONEARG"
git -C "$LEGACY_ONEARG" commit -q --allow-empty -m init >/dev/null 2>&1 || fail "T-1098 specs-arg-control: initial commit failed (control)"

# The setup lines with the git add's second argument dropped (the exact
# regression requirement 3 guards against). Matched generically on
# "--get specs)" rather than on the (already-substituted) team-paths.sh
# path, so the pattern still hits after subst_recipe has rewritten the
# bare command name to an absolute path.
ONEARG_SETUP="$(printf '%s\n' "$RAW_SETUP" | subst_recipe | sed -E 's/ "\$\([^)]*--get specs\)"$//')"
run_lines_in_repo "$LEGACY_ONEARG" "$ONEARG_SETUP" || fail "T-1098 specs-arg-control: the one-argument setup did not succeed"

ONEARG_BASE="$(tp --root "$LEGACY_ONEARG" --get base)"
ONEARG_SPECS="$(tp --root "$LEGACY_ONEARG" --get specs)"
[ -d "$LEGACY_ONEARG/$ONEARG_SPECS" ] || fail "T-1098 specs-arg-control: the resolved specs path was not even scaffolded (control)"
ONEARG_LS="$(git -C "$LEGACY_ONEARG" ls-tree -r --name-only HEAD 2>/dev/null)"
onearg_under_base=0; onearg_under_specs=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in "$ONEARG_BASE"/*) onearg_under_base=1 ;; esac
  case "$p" in "$ONEARG_SPECS"/*) onearg_under_specs=1 ;; esac
done <<EOF
$ONEARG_LS
EOF
[ "$onearg_under_base" -eq 1 ] || fail "T-1098 specs-arg-control: the one-argument regression fixture has NO tracked path under base either (control)"
[ "$onearg_under_specs" -eq 0 ] || fail "T-1098 specs-arg-control: dropping the second git add argument still left the specs path tracked (control failed to reproduce the regression)"
pass "T-1098 specs-arg-control: in the legacy layout, dropping the git add's second argument leaves the resolved specs path scaffolded but untracked"

# =============================================================================
# AC10 / T-1098 adverse-excludes: plant has teeth, plain add refuses, the
# shipped -f remedy succeeds — all under the SAME scratch global scope.
# =============================================================================
ADV="$GIT_TMP/adverse"
mkdir -p "$ADV"
git -C "$ADV" init -q >/dev/null 2>&1 || fail "T-1098 adverse-excludes: git init failed (control)"
set_identity "$ADV"
git -C "$ADV" commit -q --allow-empty -m init >/dev/null 2>&1 || fail "T-1098 adverse-excludes: initial commit failed (control)"

SUB_SETUP_ADV="$(printf '%s\n' "$RAW_SETUP" | subst_recipe)"
ADV_SWITCH_INIT="$(printf '%s\n' "$SUB_SETUP_ADV" | sed -n '1,2p')"
ADV_ADD_LINE="$(printf '%s\n' "$SUB_SETUP_ADV" | sed -n '3p')"
ADV_COMMIT_LINE="$(printf '%s\n' "$SUB_SETUP_ADV" | sed -n '4p')"

run_lines_in_repo "$ADV" "$ADV_SWITCH_INIT" || fail "T-1098 adverse-excludes: the switch+team-init lines did not succeed"

ADV_BASE="$(tp --root "$ADV" --get base)"
ADV_SPECS="$(tp --root "$ADV" --get specs)"
[ -n "$ADV_BASE" ] && [ -n "$ADV_SPECS" ] || fail "T-1098 adverse-excludes: could not resolve the fixture's paths (control)"

HOSTILE="$SCRATCH_CFG/hostile-excludes"
printf '%s/\n' "$ADV_BASE" > "$HOSTILE"
write_global_excludes "$HOSTILE"
probe_repo_sees "$HOSTILE" \
  || fail "T-1098 adverse-excludes: could not point the scratch global scope at the hostile excludes file"

git -C "$ADV" check-ignore -q "$ADV_BASE" \
  || fail "T-1098 adverse-excludes: the hostile plant does not actually ignore the resolved base dir (control)"

IDX_BEFORE="$(git -C "$ADV" diff --cached --name-only 2>/dev/null)"
set +e
( cd "$ADV" && eval "$ADV_ADD_LINE" ) >/dev/null 2>&1
ADD_RC=$?
set -e
[ "$ADD_RC" -ne 0 ] || fail "T-1098 adverse-excludes: the plain git add line did not refuse under the hostile excludes plant"
IDX_AFTER="$(git -C "$ADV" diff --cached --name-only 2>/dev/null)"
[ "$IDX_BEFORE" = "$IDX_AFTER" ] || fail "T-1098 adverse-excludes: the refused git add left the index changed"

ADV_ADD_F_LINE="git add -f \"$ADV_BASE\" \"$ADV_SPECS\""
( cd "$ADV" && eval "$ADV_ADD_F_LINE" ) >/dev/null 2>&1 \
  || fail "T-1098 adverse-excludes: the shipped git add -f remedy did not succeed"
IDX_REMEDY="$(git -C "$ADV" diff --cached --name-only 2>/dev/null)"
printf '%s\n' "$IDX_REMEDY" | grep -q "^$ADV_BASE/" || fail "T-1098 adverse-excludes: the remedy left no staged path under the base dir"
printf '%s\n' "$IDX_REMEDY" | grep -q "^$ADV_SPECS/" || fail "T-1098 adverse-excludes: the remedy left no staged path under the specs dir"

run_lines_in_repo "$ADV" "$ADV_COMMIT_LINE" || fail "T-1098 adverse-excludes: the extracted git commit line did not succeed after the remedy"

# Reset the scratch global scope back to harmless before any later fixture
# relies on an ordinary git add succeeding.
write_global_excludes "$EMPTY_EXCLUDES"
probe_repo_sees "$EMPTY_EXCLUDES" \
  || fail "T-1098 adverse-excludes: could not reset the scratch global scope after the adverse case"
pass "T-1098 adverse-excludes: a hostile global excludes file (planted only in the scratch scope) has teeth, the plain git add refuses with the index unchanged, and the shipped git add -f remedy succeeds"

# =============================================================================
# AC11 / T-1098 teardown: executed, not described
# =============================================================================
D1_TRIAL_TIP="$(git -C "$D1" rev-parse HEAD 2>/dev/null)"
[ -n "$D1_TRIAL_TIP" ] || fail "T-1098 teardown: could not capture the trial branch's tip commit (control)"
D1_INTEGRATION_TIP_BEFORE="$(git -C "$D1" rev-parse "$D1_INIT_BRANCH" 2>/dev/null)"
[ "$D1_INTEGRATION_TIP_BEFORE" = "$D1_INIT_TIP" ] || fail "T-1098 teardown: integration branch tip drifted before teardown even started (control)"

SUB_TEARDOWN_D1="$(printf '%s\n' "$RAW_TEARDOWN" | subst_recipe "$D1_INIT_BRANCH")"
TEARDOWN_SWITCH="$(printf '%s\n' "$SUB_TEARDOWN_D1" | sed -n '1p')"
TEARDOWN_DELETE_FORCE="$(printf '%s\n' "$SUB_TEARDOWN_D1" | sed -n '2p')"

run_lines_in_repo "$D1" "$TEARDOWN_SWITCH" || fail "T-1098 teardown: the switch back to the integration branch did not succeed"
[ "$(git -C "$D1" symbolic-ref --short HEAD 2>/dev/null)" = "$D1_INIT_BRANCH" ] \
  || fail "T-1098 teardown: HEAD is not on the integration branch after the switch"

set +e
git -C "$D1" branch -d trial/one-ticket >/dev/null 2>&1
DECLINE_RC=$?
set -e
[ "$DECLINE_RC" -ne 0 ] || fail "T-1098 teardown: git branch -d unexpectedly succeeded on an unmerged branch"
git -C "$D1" show-ref --verify --quiet refs/heads/trial/one-ticket \
  || fail "T-1098 teardown: the trial branch is gone after the declined -d (should still exist)"

run_lines_in_repo "$D1" "$TEARDOWN_DELETE_FORCE" || fail "T-1098 teardown: git branch -D did not succeed"
if git -C "$D1" show-ref --verify --quiet refs/heads/trial/one-ticket; then
  fail "T-1098 teardown: the trial branch ref still exists after -D"
fi
# "Gone from the working tree" is judged at the level the recipe actually
# guarantees: no TRACKED content remains under the resolved base dir once
# back on the integration branch (git's own view — the branch delete really
# did take every committed byte with it), and whatever the filesystem still
# physically holds is confined to the documented, deliberately-gitignored
# telemetry stub (templates/shell-team.gitignore ignores `runs/`, so a plain
# `git add <base>` never tracks `runs/.gitkeep` in the first place — a branch
# switch cannot remove a file it never tracked). A raw `[ ! -e ]` filesystem
# check is the wrong instrument here: it would fail on every run, not
# because teardown is broken, but because the shipped .gitignore behaves
# exactly as documented elsewhere in this repo. See "Notes from engineer".
D1_TRACKED_BASE_AFTER="$(git -C "$D1" ls-files -- "$D1_BASE" 2>/dev/null)"
[ -z "$D1_TRACKED_BASE_AFTER" ] \
  || fail "T-1098 teardown: tracked content still exists under the resolved base dir after teardown: $D1_TRACKED_BASE_AFTER"
if [ -e "$D1/$D1_BASE" ]; then
  # `.shell-team/.gitignore` itself was TRACKED and is correctly removed by
  # the branch switch along with it, so `git check-ignore` can no longer
  # attribute the leftover to that rule post-teardown (the rule is gone
  # too) — the surviving path is asserted by NAME instead: it must be
  # exactly the telemetry stub the shipped .gitignore protects (`runs/`),
  # never anything else.
  STRAY_FILES="$(find "$D1/$D1_BASE" -type f 2>/dev/null)"
  while IFS= read -r sf; do
    [ -n "$sf" ] || continue
    case "$sf" in
      "$D1/$D1_BASE"/runs/*) ;;
      *) fail "T-1098 teardown: an unexpected file survives under the resolved base dir after teardown (not the documented runs/ telemetry stub): $sf" ;;
    esac
  done <<EOF
$STRAY_FILES
EOF
fi

set +e
git -C "$D1" merge-base --is-ancestor "$D1_TRIAL_TIP" "$D1_INIT_BRANCH" >/dev/null 2>&1
ANCESTOR_RC=$?
set -e
[ "$ANCESTOR_RC" -ne 0 ] || fail "T-1098 teardown: the trial branch's tip commit is reachable from the integration branch (should not be)"

[ "$(git -C "$D1" rev-parse "$D1_INIT_BRANCH" 2>/dev/null)" = "$D1_INTEGRATION_TIP_BEFORE" ] \
  || fail "T-1098 teardown: the integration branch's tip commit moved during teardown"
pass "T-1098 teardown: switch back succeeds, -d declines, -D succeeds, the base dir is gone, and the trial tip is unreachable from the integration branch"

# =============================================================================
# AC12 / T-1098 ja-fence-parity
# =============================================================================
JA_SETUP="$(bash "$EXTRACT" "$ADOPTING_JA" setup)" || fail "T-1098 ja-fence-parity: extraction of the ja setup block failed"
JA_TEARDOWN="$(bash "$EXTRACT" "$ADOPTING_JA" teardown)" || fail "T-1098 ja-fence-parity: extraction of the ja teardown block failed"
[ -n "$JA_SETUP" ] && [ -n "$RAW_SETUP" ] || fail "T-1098 ja-fence-parity: an extraction was empty (control)"
[ -n "$JA_TEARDOWN" ] && [ -n "$RAW_TEARDOWN" ] || fail "T-1098 ja-fence-parity: an extraction was empty (control)"
[ "$JA_SETUP" = "$RAW_SETUP" ] || fail "T-1098 ja-fence-parity: the ja setup fence is not byte-identical to the English one"
[ "$JA_TEARDOWN" = "$RAW_TEARDOWN" ] || fail "T-1098 ja-fence-parity: the ja teardown fence is not byte-identical to the English one"
pass "T-1098 ja-fence-parity: docs/adopting.ja.md's setup and teardown fences are byte-identical to docs/adopting.md's"

# =============================================================================
# AC3 / T-1098 substitution-closed
# =============================================================================
DUMMY_BRANCH="subst-test-branch"
SUB_SETUP_TEST="$(printf '%s\n' "$RAW_SETUP" | subst_recipe "$DUMMY_BRANCH")"
SUB_TEARDOWN_TEST="$(printf '%s\n' "$RAW_TEARDOWN" | subst_recipe "$DUMMY_BRANCH")"
if [ "$SUB_SETUP_TEST" = "$RAW_SETUP" ] && [ "$SUB_TEARDOWN_TEST" = "$RAW_TEARDOWN" ]; then
  fail "T-1098 substitution-closed: substituted text is byte-identical to extracted text (no substitution occurred)"
fi
if printf '%s\n%s\n' "$SUB_SETUP_TEST" "$SUB_TEARDOWN_TEST" | grep -qE '<[A-Za-z-]+>'; then
  fail "T-1098 substitution-closed: an unsubstituted <...> placeholder survives in the executed text"
fi
REV_SETUP="$(printf '%s\n' "$SUB_SETUP_TEST" | sed \
  -e "s|$DUMMY_BRANCH|<integration-branch>|g" \
  -e "s|$TEAM_INIT_BIN|team-init.sh|g" \
  -e "s|$TEAM_PATHS_BIN|team-paths.sh|g")"
REV_TEARDOWN="$(printf '%s\n' "$SUB_TEARDOWN_TEST" | sed \
  -e "s|$DUMMY_BRANCH|<integration-branch>|g" \
  -e "s|$TEAM_INIT_BIN|team-init.sh|g" \
  -e "s|$TEAM_PATHS_BIN|team-paths.sh|g")"
[ "$REV_SETUP" = "$RAW_SETUP" ] || fail "T-1098 substitution-closed: reversing the setup substitutions does not reproduce the extracted text byte-for-byte"
[ "$REV_TEARDOWN" = "$RAW_TEARDOWN" ] || fail "T-1098 substitution-closed: reversing the teardown substitutions does not reproduce the extracted text byte-for-byte"
pass "T-1098 substitution-closed: the setup and teardown text differ from the extracted text in exactly the three declared substitutions, reversibly"

# =============================================================================
# T-1098 extract-fail-closed: a compact, in-suite demonstration of the
# extractor's fail-closed contract (the full four-mutant proof is AC2's own
# independent in-line reproduction, run separately by check-acs.sh).
# =============================================================================
EFC="$GIT_TMP/extract-fail-closed"
mkdir -p "$EFC"
sed 's/^## Trying the team on one ticket$/## Renamed anchor/' "$ADOPTING_EN" > "$EFC/renamed.md"
grep -v -F -- 'team-init.sh --trial-branch ' "$ADOPTING_EN" > "$EFC/no-flag-span.md"

set +e
bash "$EXTRACT" "$EFC/renamed.md" setup >"$EFC/o1" 2>"$EFC/e1"
RC1=$?
bash "$EXTRACT" "$EFC/no-flag-span.md" flag >"$EFC/o2" 2>"$EFC/e2"
RC2=$?
set -e
[ "$RC1" -ne 0 ] || fail "T-1098 extract-fail-closed: extraction succeeded against a renamed-heading doc"
[ -s "$EFC/e1" ] || fail "T-1098 extract-fail-closed: no stderr diagnosis for the renamed-heading doc"
[ "$(grep -c . "$EFC/o1" || true)" = "0" ] || fail "T-1098 extract-fail-closed: renamed-heading doc printed a command line"
[ "$RC2" -ne 0 ] || fail "T-1098 extract-fail-closed: extraction succeeded against a doc with no invocation-form span"
[ -s "$EFC/e2" ] || fail "T-1098 extract-fail-closed: no stderr diagnosis for the missing-flag-span doc"
[ "$(grep -c . "$EFC/o2" || true)" = "0" ] || fail "T-1098 extract-fail-closed: missing-flag-span doc printed a command line"
pass "T-1098 extract-fail-closed: extraction refuses (non-zero exit, stderr diagnosis, no stdout) against a renamed heading and against a missing invocation-form span"

printf '\nAll trial-recipe assertions passed.\n'
