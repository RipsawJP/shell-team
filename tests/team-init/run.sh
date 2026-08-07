#!/usr/bin/env bash
# run.sh — drive bin/team-init.sh against temp targets and assert the documented
# behavior (T-016 + T-025 acceptance criteria):
#   AC1: a fresh target gets all scaffold files/dirs UNDER THE BASE DIR
#        (.shell-team/ by default); the generated todo.md passes check-handoff and
#        the generated contract passes check-contract.
#   AC2: NO host-root file is mutated — team-init never creates/edits the
#        target's CLAUDE.md and never creates/appends the target's root
#        .gitignore. Telemetry is ignored via a self-contained <base>/.gitignore.
#   AC3: a second run skips existing files with no content drift.
#   AC4: a pre-existing CLAUDE.md and a pre-existing root .gitignore are left
#        byte-for-byte untouched.
#   AC5: nothing repo-specific (ripsawjp / loop-engineering / concrete T-NNN) is
#        baked into the generated files.
#   override: $TEAM_RUN_BASE relocates the whole scaffold under that base dir.
#
# Avoids mktemp (writes under $HERE/tmp-targets, cleaned via trap) so the suite
# runs in restricted sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
INIT="$REPO_ROOT/bin/team-init.sh"
CHECK_HANDOFF="$REPO_ROOT/bin/check-handoff.sh"
CHECK_CONTRACT="$REPO_ROOT/bin/check-contract.sh"
TMP="$HERE/tmp-targets"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# Run team-init with a clean env (no inherited TEAM_RUN_BASE) so default-layout
# assertions are not perturbed by the caller's environment.
init() { env -u TEAM_RUN_BASE bash "$INIT" "$@"; }

# --- T-1046 ignored-base verdict fixture helpers ----------------------------
# new_git_repo <dir> — a real work tree under GTMP with core.excludesFile
# persisted to /dev/null (D9: never a transient `-c` flag on the outer
# command, since the git calls under test are made INSIDE bin/team-init.sh).
new_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git init -q "$dir" >/dev/null 2>&1
  git -C "$dir" config core.excludesFile /dev/null
  git -C "$dir" config user.email "team-init-fixture@example.invalid"
  git -C "$dir" config user.name "team-init fixture"
}

# count_warn_lines <stderr-file> — number of `WARN: `-prefixed lines.
count_warn_lines() { grep -c '^WARN: ' "$1" || true; }

# assert_v1_fired <stderr-file> <base> — V1's anchor line, with <base>
# substituted, occurs at least once.
assert_v1_fired() {
  grep -qxF "WARN: shell-team: git reports the resolved base dir as ignored: $2" "$1"
}

# make_git_shim <dir> <intercepted-subcommand> — a `git` on PATH that answers
# a fatal 128 (non-English message, never compared by the code under test)
# for any invocation naming <intercepted-subcommand> among its arguments,
# and delegates every other invocation to the REAL git. The subcommand is
# matched by scanning "$@" (never "$1"), because bin/team-init.sh always
# calls `git -C "$TARGET" <subcommand> ...` — "$1" is "-C", not the
# subcommand name.
REAL_GIT="$(command -v git)" || fail "make_git_shim: no real git on PATH for this suite"
make_git_shim() {
  local dir="$1" sub="$2"
  mkdir -p "$dir"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'for a in "$@"; do\n'
    # shellcheck disable=SC2016  # deliberately literal: $a is a token in
    # the GENERATED shim script, not this suite's own shell variable.
    printf '  if [ "$a" = "%s" ]; then\n' "$sub"
    printf "    printf 'fatal: simulated non-English failure\\\\n' >&2\n"
    printf '    exit 128\n'
    printf '  fi\n'
    printf 'done\n'
    printf 'exec "%s" "$@"\n' "$REAL_GIT"
  } > "$dir/git"
  chmod +x "$dir/git"
}

# A second, $TMPDIR-backed fixture root reserved for git-needing fixtures
# (T-1046, D9): a real `git init`-ed tree built under $TMP (inside this
# repo's own work tree) fails with "Operation not permitted" copying
# `.git/`'s hook templates in a sandboxed run, even though plain file
# writes to $TMP succeed. Kept separate from $TMP for exactly that reason
# (T-1001/T-1042 test-recipe entries).
if [ -n "${TMPDIR:-}" ]; then
  GTMP="${TMPDIR%/}/team-init-git-fixtures.$$"
else
  GTMP="$HERE/tmp-git-fixtures.$$"
fi

rm -rf "$TMP" "$GTMP"
trap 'rm -rf "$TMP" "$GTMP"' EXIT
mkdir -p "$TMP" "$GTMP"

# --- AC1: fresh target -> scaffold under .shell-team/ -------------------------
T1="$TMP/fresh"
mkdir -p "$T1"
init "$T1" >/dev/null 2>&1 || fail "AC1: team-init exited non-zero on a fresh target"

for f in \
  .shell-team/todo.md \
  .shell-team/loops/shell-team.contract.yaml \
  .shell-team/runs/.gitkeep \
  .shell-team/retros/.gitkeep \
  .shell-team/reviews/.gitkeep \
  .shell-team/specs/.gitkeep \
  .shell-team/provenance/.gitkeep \
  .shell-team/interventions/.gitkeep \
  .shell-team/AGENTS.md \
  .shell-team/test-recipe.md \
  .shell-team/.gitignore
do
  [ -f "$T1/$f" ] || fail "AC1: expected scaffold file missing: $f"
done
pass "AC1: all scaffold files/dirs created under .shell-team/"

# AGENTS.md (T-030): a cross-tool pointer doc lands UNDER the base dir (never the
# host root) and points at the truth sources. The generic check and the
# host-root-untouched / idempotency assertions below (AC2/AC3/AC5) also cover it.
AGENTS_MD="$T1/.shell-team/AGENTS.md"
grep -q 'todo.md'        "$AGENTS_MD" || fail "T-030: AGENTS.md should point at the todo board"
grep -q 'READY_FOR_ARCH' "$AGENTS_MD" || fail "T-030: AGENTS.md should name the status-flag chain"
grep -q 'project_status' "$AGENTS_MD" || fail "T-030: AGENTS.md should point at project_status"
grep -qi 'MEMORY.md'     "$AGENTS_MD" || fail "T-030: AGENTS.md should mention the MEMORY.md index"
grep -qi 'Codex'         "$AGENTS_MD" || fail "T-030: AGENTS.md should note review is cross-provider (Codex)"
# It must NOT appear at the host root (placement guarantee: base dir only).
[ ! -e "$T1/AGENTS.md" ] || fail "T-030: AGENTS.md must not be created at the host root"
# Pointer-only invariant: the doc must not accrue dated changelog/history entries.
# A bare ISO date (YYYY-MM-DD) is the clearest drift signal and never appears in
# the pure-pointer template prose, so it stays generic over time.
if grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$AGENTS_MD"; then
  fail "T-030: AGENTS.md must stay a pointer (no dated changelog/history entries)"
fi
pass "T-030: AGENTS.md scaffolded under base dir, points at the truth sources, and carries no dated entries"

# test-recipe.md (T-060): the per-repo test-run recipe lands UNDER the base dir
# as a minimal skeleton (headings + placeholders). Placement + generic checks;
# the --force protection is asserted separately below.
RECIPE_MD="$T1/.shell-team/test-recipe.md"
grep -q 'How to run tests' "$RECIPE_MD" || fail "T-060: recipe should carry the 'How to run tests' section"
grep -qi 'quirks' "$RECIPE_MD" || fail "T-060: recipe should carry the environment-quirks section"
grep -q 'Appended by tasks' "$RECIPE_MD" || fail "T-060: recipe should carry the append-only section"
[ ! -e "$T1/test-recipe.md" ] || fail "T-060: test-recipe.md must not be created at the host root"
pass "T-060: test-recipe.md scaffolded under base dir with the skeleton sections"

bash "$CHECK_HANDOFF" "$T1/.shell-team/todo.md" >/dev/null 2>&1 \
  || fail "AC1: generated todo.md does not pass check-handoff"
pass "AC1: generated todo.md passes check-handoff"

# T-1006 AC15: adding a `lessons` resolver key must not turn into a scaffolded
# file — the corpus stays opt-in. Positive control: the board scaffolded at
# all (asserted above); this asserts no file named lessons.md anywhere in it.
[ "$(find "$T1" -name 'lessons.md' | wc -l | tr -d ' ')" -eq 0 ] \
  || fail "T-1006: team-init scaffolds no lessons file"
pass "T-1006: team-init scaffolds no lessons file"

bash "$CHECK_CONTRACT" "$T1/.shell-team/loops/shell-team.contract.yaml" >/dev/null 2>&1 \
  || fail "AC1: generated contract does not pass check-contract"
pass "AC1: generated shell-team.contract.yaml passes check-contract"

# --- AC2: host root is NOT mutated ------------------------------------------
[ ! -e "$T1/CLAUDE.md" ]  || fail "AC2: team-init must not create a host CLAUDE.md"
[ ! -e "$T1/.gitignore" ] || fail "AC2: team-init must not create a host-root .gitignore"
# The ONLY .gitignore is the self-contained one inside the base dir, ignoring runs/.
grep -qxF "runs/" "$T1/.shell-team/.gitignore" \
  || fail "AC2: base .gitignore should ignore runs/"
# The host tree, outside the base dir, must contain nothing else team-init made.
stray="$(cd "$T1" && find . -mindepth 1 -maxdepth 1 ! -name .shell-team)"
[ -z "$stray" ] || fail "AC2: team-init created files outside the base dir: $stray"
pass "AC2: host root untouched — no CLAUDE.md, no root .gitignore, footprint confined to .shell-team/"

# --- AC3: idempotent re-run (no drift) --------------------------------------
before="$TMP/snapshot-before"
after="$TMP/snapshot-after"
snapshot() {
  local root="$1" out="$2"
  ( cd "$root" && find . -type f | LC_ALL=C sort | while IFS= read -r p; do
      printf '=== %s ===\n' "$p"
      cat "$p"
    done ) > "$out"
}
snapshot "$T1" "$before"
init "$T1" >/dev/null 2>&1 || fail "AC3: team-init exited non-zero on re-run"
snapshot "$T1" "$after"
diff -u "$before" "$after" >/dev/null 2>&1 || fail "AC3: re-run changed target content (not idempotent)"
pass "AC3: re-run is idempotent (no content drift)"

# --- AC4: pre-existing host files are left byte-for-byte untouched ----------
T2="$TMP/with-host-files"
mkdir -p "$T2"
ORIG_CLAUDE="# My Project

Existing project instructions that must survive untouched.

## Build
Run make."
printf '%s\n' "$ORIG_CLAUDE" > "$T2/CLAUDE.md"
printf 'node_modules/\n' > "$T2/.gitignore"
cp "$T2/CLAUDE.md" "$TMP/claude.orig"
cp "$T2/.gitignore" "$TMP/gitignore.orig"
init "$T2" >/dev/null 2>&1 || fail "AC4: team-init exited non-zero with pre-existing host files"
diff -u "$TMP/claude.orig" "$T2/CLAUDE.md" >/dev/null 2>&1 \
  || fail "AC4: pre-existing CLAUDE.md was modified"
diff -u "$TMP/gitignore.orig" "$T2/.gitignore" >/dev/null 2>&1 \
  || fail "AC4: pre-existing root .gitignore was modified"
grep -qF "shell-team:ref" "$T2/CLAUDE.md" \
  && fail "AC4: a reference block was injected into CLAUDE.md (should not happen)"
[ -f "$T2/.shell-team/todo.md" ] || fail "AC4: scaffold did not land under .shell-team/"
pass "AC4: pre-existing CLAUDE.md and root .gitignore left byte-for-byte untouched"

# --- AC5: generated files are generic (no repo-specific bake-in) -----------
# T-[0-9]{3,} catches any concrete task id; the literal placeholder `T-XXX` in
# the todo Format block is intentionally allowed.
if grep -rEi "ripsawjp|loop-engineering|T-[0-9]{3,}" "$T1/.shell-team" >/dev/null 2>&1; then
  fail "AC5: repo-specific token leaked into generated files"
fi
pass "AC5: generated files are generic (no ripsawjp / loop-engineering / concrete T-NNN)"

# --- override: $TEAM_RUN_BASE relocates the scaffold ------------------------
T_OV="$TMP/override"
mkdir -p "$T_OV"
TEAM_RUN_BASE=.ops bash "$INIT" "$T_OV" >/dev/null 2>&1 \
  || fail "override: team-init exited non-zero with TEAM_RUN_BASE=.ops"
[ -f "$T_OV/.ops/todo.md" ]   || fail "override: scaffold did not land under the .ops base dir"
[ -f "$T_OV/.ops/.gitignore" ] || fail "override: base .gitignore missing under .ops"
[ -f "$T_OV/.ops/AGENTS.md" ] || fail "override: AGENTS.md did not land under the .ops base dir"
[ -f "$T_OV/.ops/test-recipe.md" ] || fail "override: test-recipe.md did not land under the .ops base dir"
[ ! -e "$T_OV/AGENTS.md" ]    || fail "override: AGENTS.md must not be created at the host root"
[ ! -e "$T_OV/.shell-team" ]    || fail "override: default .shell-team dir should not exist when overridden"
pass "override: TEAM_RUN_BASE relocates the whole scaffold (incl. AGENTS.md) under the chosen base dir"

# --- legacy layout: AGENTS.md lands at tasks/AGENTS.md (T-030 regression) ----
# A repo that already carries the historical `tasks/loops/shell-team.contract.yaml`
# marker resolves base=tasks; AGENTS.md must follow the base there — never the
# host root and never a fresh .shell-team/. This guards the legacy placement that
# only the resolver (not the scaffold list) decides.
T_LEG="$TMP/legacy"
mkdir -p "$T_LEG/tasks/loops"
cp "$REPO_ROOT/templates/shell-team.contract.yaml" "$T_LEG/tasks/loops/shell-team.contract.yaml"
init "$T_LEG" >/dev/null 2>&1 || fail "legacy: team-init exited non-zero on a legacy-layout target"
[ -f "$T_LEG/tasks/AGENTS.md" ] || fail "legacy: AGENTS.md did not land at tasks/AGENTS.md"
[ ! -e "$T_LEG/AGENTS.md" ]     || fail "legacy: AGENTS.md must not be created at the host root"
[ ! -e "$T_LEG/.shell-team/AGENTS.md" ] || fail "legacy: a fresh .shell-team/AGENTS.md must not appear in legacy mode"
[ ! -e "$T_LEG/.shell-team" ]     || fail "legacy: default .shell-team dir should not exist in legacy mode"
[ -f "$T_LEG/tasks/test-recipe.md" ] || fail "legacy: test-recipe.md did not land at tasks/test-recipe.md"
[ ! -e "$T_LEG/test-recipe.md" ]     || fail "legacy: test-recipe.md must not be created at the host root"
pass "legacy: AGENTS.md follows the resolved base to tasks/AGENTS.md (no host-root / no .shell-team leak)"

# --- T-060: --force protection of the append-only recipe ---------------------
# The recipe is an append-only asset (engineers accumulate procedures in it), so
# --force must NOT overwrite it — while other scaffold files keep the historical
# --force overwrite behavior. Boundary-crossing fixture: mutate both the recipe
# and the todo board with content the template cannot contain, then --force and
# assert the FINAL STATE (recipe keeps the appended content byte-for-byte; the
# board is reset back to the template).
RECIPE_MARK='## Appended by task T-NNN: build the test-only image with the dev extra first'
printf '%s\n' "$RECIPE_MARK" >> "$T1/.shell-team/test-recipe.md"
cp "$T1/.shell-team/test-recipe.md" "$TMP/recipe.appended"
printf '%s\n' '<!-- mutated line that --force must reset -->' >> "$T1/.shell-team/todo.md"
env -u TEAM_RUN_BASE bash "$INIT" --force "$T1" >/dev/null 2>&1 \
  || fail "T-060: team-init --force exited non-zero"
cmp -s "$TMP/recipe.appended" "$T1/.shell-team/test-recipe.md" \
  || fail "T-060: --force overwrote the appended recipe (protected asset destroyed)"
if grep -qF 'mutated line that --force must reset' "$T1/.shell-team/todo.md"; then
  fail "T-060: --force should still overwrite non-protected scaffold files (todo.md kept the mutation)"
fi
pass "T-060: --force never overwrites the recipe, while other scaffold files keep --force semantics"

# --- T-060: dangling symlink at the recipe path must not escape the base ----
# `[ -e ]` is false for a dangling symlink, so an unguarded copy would follow
# the link and write the recipe content OUTSIDE the base dir (host-root
# invariant violation). The protected helper must treat any symlink — dangling
# included — as "already claimed": skip, write nothing through it.
T_SYM="$TMP/symlink-escape"
mkdir -p "$T_SYM/.shell-team" "$TMP/outside-check"
ln -s "../../outside-check/escaped.md" "$T_SYM/.shell-team/test-recipe.md"
init "$T_SYM" >/dev/null 2>&1 || fail "T-060 symlink: team-init exited non-zero"
[ ! -e "$TMP/outside-check/escaped.md" ] \
  || fail "T-060 symlink: recipe content escaped the base dir through a dangling symlink"
[ -L "$T_SYM/.shell-team/test-recipe.md" ] \
  || fail "T-060 symlink: the pre-existing symlink should be preserved untouched"
pass "T-060: dangling symlink at the recipe path is skipped (no write-through, no base escape)"

# --- T-061 AC1: dangling symlink at a copy_template() destination (todo.md) --
# `[ -e ]` is false for a dangling symlink, so an unguarded copy_template()
# would follow the link and write todo.md content OUTSIDE the base dir. Two
# sub-cases: (a) non-force must skip, symlink preserved; (b) --force must
# replace the symlink with a real base-dir file, never follow it out.
T_SYM_TODO="$TMP/symlink-escape-todo"
mkdir -p "$T_SYM_TODO/.shell-team" "$TMP/outside-check-todo"
ln -s "../../outside-check-todo/escaped.md" "$T_SYM_TODO/.shell-team/todo.md"
init "$T_SYM_TODO" >/dev/null 2>&1 || fail "T-061 AC1: team-init exited non-zero (non-force, dangling symlink at todo.md)"
[ ! -e "$TMP/outside-check-todo/escaped.md" ] \
  || fail "T-061 AC1: todo.md content escaped the base dir through a dangling symlink (non-force)"
[ -L "$T_SYM_TODO/.shell-team/todo.md" ] \
  || fail "T-061 AC1: the pre-existing dangling symlink at todo.md should be preserved untouched (non-force skip)"
pass "T-061 AC1: non-force copy_template() skips a dangling symlink at the destination (no write-through, no base escape)"

T_SYM_TODO_FORCE="$TMP/symlink-escape-todo-force"
mkdir -p "$T_SYM_TODO_FORCE/.shell-team" "$TMP/outside-check-todo-force"
ln -s "../../outside-check-todo-force/escaped.md" "$T_SYM_TODO_FORCE/.shell-team/todo.md"
init --force "$T_SYM_TODO_FORCE" >/dev/null 2>&1 \
  || fail "T-061 AC1: team-init --force exited non-zero (dangling symlink at todo.md)"
[ ! -e "$TMP/outside-check-todo-force/escaped.md" ] \
  || fail "T-061 AC1: --force followed the dangling symlink and wrote outside the base dir"
if [ ! -f "$T_SYM_TODO_FORCE/.shell-team/todo.md" ] || [ -L "$T_SYM_TODO_FORCE/.shell-team/todo.md" ]; then
  fail "T-061 AC1: --force should replace the dangling symlink with a real file inside the base dir"
fi
pass "T-061 AC1: --force replaces a dangling symlink with a real base-dir file instead of following it"

# --- T-061 AC3: dangling symlink at an ensure_gitkeep() destination ----------
# `[ -e ]` is false for a dangling symlink, so an unguarded ensure_gitkeep()
# would follow the link and write an empty file OUTSIDE the base dir. No
# --force path exists here (skip-if-exists only): the symlink must be
# preserved untouched.
T_SYM_KEEP="$TMP/symlink-escape-gitkeep"
mkdir -p "$T_SYM_KEEP/.shell-team/runs" "$TMP/outside-check-gitkeep"
ln -s "../../../outside-check-gitkeep/escaped.gitkeep" "$T_SYM_KEEP/.shell-team/runs/.gitkeep"
init "$T_SYM_KEEP" >/dev/null 2>&1 || fail "T-061 AC3: team-init exited non-zero (dangling symlink at runs/.gitkeep)"
[ ! -e "$TMP/outside-check-gitkeep/escaped.gitkeep" ] \
  || fail "T-061 AC3: .gitkeep content escaped the base dir through a dangling symlink"
[ -L "$T_SYM_KEEP/.shell-team/runs/.gitkeep" ] \
  || fail "T-061 AC3: the pre-existing dangling symlink at runs/.gitkeep should be preserved untouched"
pass "T-061 AC3: ensure_gitkeep() skips a dangling symlink at the destination (no write-through, no base escape)"

# =============================================================================
# T-1046 v2: the ignored-base notice, transcribed from the five-row decision
# table DT0, DT5-DT8 (.shell-team/specs/T-1046-ignored-base-verdict.md). DT0
# (no git on PATH) is statically guarded (`command -v git`) rather than
# exercised behaviourally here — removing git from PATH would also remove the
# POSIX tools this suite itself needs, and AC4 locks the guard's presence in
# bin/team-init.sh instead. DT8 (check-ignore rc outside {0,1,128}) is
# unreachable through any documented git behaviour; it exists only so the
# classification has no fall-through (spec D1) and no fixture exercises it —
# this comment is its only occurrence in this suite (AC19). The retired rows
# DT1-DT4 (the deleted rev-parse channel) no longer exist; every state they
# once classified now reaches DT7 with the identical silent outcome.
# =============================================================================

# --- LX01: DT5 M1 -- a glob-shaped base beside a tracked glob-colliding path
D_LX01="$GTMP/lx01"
new_git_repo "$D_LX01"
mkdir -p "$D_LX01/abc"
printf 'x\n' > "$D_LX01/abc/file.txt"
git -C "$D_LX01" add abc/file.txt >/dev/null 2>&1
printf '%s\n' 'a\*/' > "$D_LX01/.gitignore"
TEAM_RUN_BASE='a*' bash "$INIT" "$D_LX01" >"$GTMP/lx01.out" 2>"$GTMP/lx01.err" \
  || fail "LX01: team-init exited non-zero"
assert_v1_fired "$GTMP/lx01.err" 'a*' \
  || fail "LX01: expected the ignored-base notice for a glob-shaped base beside a tracked glob-colliding path"
[ -f "$D_LX01/a*/todo.md" ] || fail "LX01: scaffold did not complete"
pass "case: DT5 M1 — a glob-shaped base beside a tracked glob-colliding path is still reported ignored"

# --- LX02: DT7 M2 -- a bare repository and a stubbed git fatal -------------
D_LX02_BARE="$GTMP/lx02-bare"
mkdir -p "$D_LX02_BARE"
git init --bare -q "$D_LX02_BARE" >/dev/null 2>&1
init "$D_LX02_BARE" >"$GTMP/lx02-bare.out" 2>"$GTMP/lx02-bare.err" \
  || fail "LX02: team-init exited non-zero (bare repository)"
[ "$(count_warn_lines "$GTMP/lx02-bare.err")" = "0" ] \
  || fail "LX02: expected silence inside a bare repository (DT7)"

SHIM_LX02="$GTMP/lx02-shim"
make_git_shim "$SHIM_LX02" check-ignore
D_LX02_STUB="$GTMP/lx02-stub"
new_git_repo "$D_LX02_STUB"
printf '%s\n' '.shell-team/' > "$D_LX02_STUB/.gitignore"
PATH="$SHIM_LX02:$PATH" init "$D_LX02_STUB" >"$GTMP/lx02-stub.out" 2>"$GTMP/lx02-stub.err" \
  || fail "LX02: team-init exited non-zero (stubbed git fatal)"
[ "$(count_warn_lines "$GTMP/lx02-stub.err")" = "0" ] \
  || fail "LX02: expected silence under a stubbed check-ignore fatal (DT7), even with an otherwise-ignored base dir"
[ -f "$D_LX02_STUB/.shell-team/todo.md" ] || fail "LX02: scaffold did not complete under a stubbed git"
pass "case: DT7 M2 — a bare repository and a stubbed git fatal both stay silent"

# --- LX03: DT5 M3 -- a directory-form rule written before scaffolding ------
D_LX03="$GTMP/lx03"
new_git_repo "$D_LX03"
printf '%s\n' '.shell-team/' > "$D_LX03/.gitignore"
# Demonstrate the historical hazard directly: BEFORE the base dir exists, a
# bare-form check-ignore query against this directory-only rule answers
# "not ignored" (rc=1) -- the defect team-init's normalized `./<base>/`
# query defeats. If this ever stops reproducing, the fixture's own premise
# is stale and this must fail loudly rather than silently prove nothing.
if git -C "$D_LX03" check-ignore -q -- '.shell-team' >/dev/null 2>/dev/null; then
  hazard_rc=0
else
  hazard_rc=$?
fi
[ "$hazard_rc" -eq 1 ] \
  || fail "LX03: the bare-form pre-existence hazard did not reproduce as expected (got rc=$hazard_rc) -- fixture assumption stale"
bash "$INIT" "$D_LX03" >"$GTMP/lx03.out" 2>"$GTMP/lx03.err" \
  || fail "LX03: team-init exited non-zero"
assert_v1_fired "$GTMP/lx03.err" '.shell-team' \
  || fail "LX03: expected the ignored-base notice despite the directory-form rule being written before the dir existed"
pass "case: DT5 M3 — a directory-form ignore rule written before scaffolding is reported ignored"

# --- LX04: DT5 M4 -- legacy split-root layout, no layout-dependent noun ----
D_LX04="$GTMP/lx04"
new_git_repo "$D_LX04"
mkdir -p "$D_LX04/tasks/loops"
cp "$REPO_ROOT/templates/shell-team.contract.yaml" "$D_LX04/tasks/loops/shell-team.contract.yaml"
printf '%s\n' 'tasks/' > "$D_LX04/.gitignore"
init "$D_LX04" >"$GTMP/lx04.out" 2>"$GTMP/lx04.err" \
  || fail "LX04: team-init exited non-zero (legacy split-root layout)"
assert_v1_fired "$GTMP/lx04.err" 'tasks' \
  || fail "LX04: expected the ignored-base notice under the legacy split-root layout"
grep -qF 'specs' "$GTMP/lx04.err" \
  && fail "LX04: the notice must name no layout-dependent noun (specs sits outside the base dir in legacy mode)"
[ -f "$D_LX04/tasks/todo.md" ] || fail "LX04: legacy scaffold did not complete"
[ -f "$D_LX04/docs/specs/.gitkeep" ] || fail "LX04: legacy specs dir (outside the base) did not scaffold"
pass "case: DT5 M4 — a legacy split-root layout emits the frozen body and names no layout-dependent noun"

# --- LX05: NM1 -- no git diagnostic text is read; a foreign locale changes nothing
grep -qF 'not a git repository' "$INIT" \
  && fail "LX05: bin/team-init.sh must never read this git diagnostic text"
D_LX05="$GTMP/lx05"
new_git_repo "$D_LX05"
printf '%s\n' '.shell-team/' > "$D_LX05/.gitignore"
if locale -a 2>/dev/null | grep -qi '^fr_FR'; then
  LANGUAGE=fr LC_ALL=fr_FR.UTF-8 bash "$INIT" "$D_LX05" >"$GTMP/lx05.out" 2>"$GTMP/lx05.err" \
    || fail "LX05: team-init exited non-zero under a foreign locale"
else
  bash "$INIT" "$D_LX05" >"$GTMP/lx05.out" 2>"$GTMP/lx05.err" \
    || fail "LX05: team-init exited non-zero"
fi
assert_v1_fired "$GTMP/lx05.err" '.shell-team' \
  || fail "LX05: expected the ignored-base notice regardless of locale"
pass "case: NM1 — no git diagnostic text is read, and a foreign locale changes no outcome"

# --- LX06: DT5 NM2 -- a colon-leading base dir is still reported ignored ---
D_LX06="$GTMP/lx06"
new_git_repo "$D_LX06"
printf '%s\n' ':foo/' > "$D_LX06/.gitignore"
TEAM_RUN_BASE=':foo' bash "$INIT" "$D_LX06" >"$GTMP/lx06.out" 2>"$GTMP/lx06.err" \
  || fail "LX06: team-init exited non-zero"
assert_v1_fired "$GTMP/lx06.err" ':foo' \
  || fail "LX06: expected the ignored-base notice for a colon-leading base dir"
[ -f "$D_LX06/:foo/todo.md" ] || fail "LX06: scaffold under a colon-leading base did not complete"
pass "case: DT5 NM2 — a colon-leading base dir is still reported ignored"

# --- LX07: NM3 -- ambient GIT_TRACE / GIT_* variables change no outcome ----
D_LX07="$GTMP/lx07"
new_git_repo "$D_LX07"
printf '%s\n' '.shell-team/' > "$D_LX07/.gitignore"
GIT_TRACE=1 GIT_DIR=/nonexistent-gitdir GIT_LITERAL_PATHSPECS=1 GIT_GLOB_PATHSPECS=1 \
  bash "$INIT" "$D_LX07" >"$GTMP/lx07.out" 2>"$GTMP/lx07.err" \
  || fail "LX07: team-init exited non-zero under ambient GIT_* variables"
assert_v1_fired "$GTMP/lx07.err" '.shell-team' \
  || fail "LX07: ambient GIT_TRACE / GIT_DIR / pathspec variables changed the outcome"
pass "case: NM3 — ambient GIT_TRACE and other GIT_ variables change no outcome"

# --- LX08: D9 -- a hostile global excludes file, and its documented remedy -
D_LX08="$GTMP/lx08"
new_git_repo "$D_LX08"
HOSTILE_EXCLUDES="$GTMP/lx08-hostile-excludes"
printf '%s\n' '.shell-team/' > "$HOSTILE_EXCLUDES"
git -C "$D_LX08" config core.excludesFile "$HOSTILE_EXCLUDES"
bash "$INIT" "$D_LX08" >"$GTMP/lx08a.out" 2>"$GTMP/lx08a.err" \
  || fail "LX08: team-init exited non-zero under a hostile global excludes file"
assert_v1_fired "$GTMP/lx08a.err" '.shell-team' \
  || fail "LX08: the hostile global excludes file was not honoured"
D_LX08_REINCLUDE="$GTMP/lx08-reinclude"
new_git_repo "$D_LX08_REINCLUDE"
git -C "$D_LX08_REINCLUDE" config core.excludesFile "$HOSTILE_EXCLUDES"
printf '%s\n' '!.shell-team/' > "$D_LX08_REINCLUDE/.gitignore"
bash "$INIT" "$D_LX08_REINCLUDE" >"$GTMP/lx08b.out" 2>"$GTMP/lx08b.err" \
  || fail "LX08: team-init exited non-zero with a repo-level re-include"
[ "$(count_warn_lines "$GTMP/lx08b.err")" = "0" ] \
  || fail "LX08: a repo-level re-include should silence the hostile global excludes rule (the documented remedy, D4)"
pass "case: D9 — a hostile global excludes file is honoured, and a repo-level re-include silences it"

# --- LX09: DT5 DT6 DT7 -- the check-ignore exit contract itself ------------
D_LX09_IGNORED="$GTMP/lx09-ignored"
new_git_repo "$D_LX09_IGNORED"
printf '%s\n' '.shell-team/' > "$D_LX09_IGNORED/.gitignore"
bash "$INIT" "$D_LX09_IGNORED" >"$GTMP/lx09i.out" 2>"$GTMP/lx09i.err" \
  || fail "LX09: team-init exited non-zero (DT5 case)"
assert_v1_fired "$GTMP/lx09i.err" '.shell-team' \
  || fail "LX09: DT5 (check-ignore rc=0) contract not honoured"

D_LX09_NOTIGNORED="$GTMP/lx09-notignored"
new_git_repo "$D_LX09_NOTIGNORED"
printf '%s\n' 'build/' > "$D_LX09_NOTIGNORED/.gitignore"
bash "$INIT" "$D_LX09_NOTIGNORED" >"$GTMP/lx09n.out" 2>"$GTMP/lx09n.err" \
  || fail "LX09: team-init exited non-zero (DT6 case)"
[ "$(count_warn_lines "$GTMP/lx09n.err")" = "0" ] \
  || fail "LX09: DT6 (check-ignore rc=1) contract not honoured"

# DT7's underlying documented contract, checked directly against git itself
# (independently of team-init): `git check-ignore -q` with no pathname is
# a fatal error per git-check-ignore(1)'s EXIT STATUS section.
if git check-ignore -q 2>/dev/null; then
  dt7_rc=0
else
  dt7_rc=$?
fi
[ "$dt7_rc" -eq 128 ] \
  || fail "LX09: DT7's underlying git-check-ignore(1) 128 contract did not reproduce (got rc=$dt7_rc) -- environment assumption stale"
pass "case: DT5 DT6 DT7 — the check-ignore exit contract still holds: 0 ignored, 1 not ignored, 128 fatal"

# --- LX11: D2 -- exit 0 in both outcome classes, including 2>&- ------------
D_LX11_IGNORED="$GTMP/lx11-ignored"
new_git_repo "$D_LX11_IGNORED"
printf '%s\n' '.shell-team/' > "$D_LX11_IGNORED/.gitignore"
lx11i_rc=0
bash "$INIT" "$D_LX11_IGNORED" >"$GTMP/lx11i.out" 2>&- || lx11i_rc=$?
[ "$lx11i_rc" -eq 0 ] || fail "LX11: the IGNORED class must exit 0 with stderr closed (got $lx11i_rc)"
[ -f "$D_LX11_IGNORED/.shell-team/todo.md" ] || fail "LX11: IGNORED-class scaffold incomplete with stderr closed"

D_LX11_SILENT="$GTMP/lx11-silent"
new_git_repo "$D_LX11_SILENT"
printf '%s\n' 'build/' > "$D_LX11_SILENT/.gitignore"
lx11s_rc=0
bash "$INIT" "$D_LX11_SILENT" >"$GTMP/lx11s.out" 2>&- || lx11s_rc=$?
[ "$lx11s_rc" -eq 0 ] || fail "LX11: the SILENCE class must exit 0 with stderr closed (got $lx11s_rc)"
pass "case: D2 — team-init exits 0 in both outcome classes, including with stderr closed"

# --- LX12: D8 -- GIT_CONFIG_COUNT/KEY_0/VALUE_0 cannot inject an excludes --
D_LX12="$GTMP/lx12"
new_git_repo "$D_LX12"
printf '%s\n' 'build/' > "$D_LX12/.gitignore"
HOSTILE_LX12="$GTMP/lx12-hostile-excludes"
printf '%s\n' '.shell-team/' > "$HOSTILE_LX12"
if env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0="$HOSTILE_LX12" \
    git -C "$D_LX12" check-ignore -q -- './.shell-team/' >/dev/null 2>/dev/null; then
  :
else
  fail "LX12: the injection channel itself did not flip a bare check-ignore in this environment -- fixture assumption stale"
fi
env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0="$HOSTILE_LX12" \
  bash "$INIT" "$D_LX12" >"$GTMP/lx12.out" 2>"$GTMP/lx12.err" \
  || fail "LX12: team-init exited non-zero under a GIT_CONFIG_COUNT injection"
[ "$(count_warn_lines "$GTMP/lx12.err")" = "0" ] \
  || fail "LX12: GIT_CONFIG_COUNT/KEY_0/VALUE_0 injected an excludes file and flipped the verdict"
pass "case: D8 — GIT_CONFIG_COUNT and its KEY/VALUE pairs cannot inject an excludes file or flip the verdict"

# --- LX13: D8 -- GIT_CONFIG_PARAMETERS cannot inject an excludes file ------
D_LX13="$GTMP/lx13"
new_git_repo "$D_LX13"
printf '%s\n' 'build/' > "$D_LX13/.gitignore"
HOSTILE_LX13="$GTMP/lx13-hostile-excludes"
printf '%s\n' '.shell-team/' > "$HOSTILE_LX13"
if env GIT_CONFIG_PARAMETERS="'core.excludesFile=$HOSTILE_LX13'" \
    git -C "$D_LX13" check-ignore -q -- './.shell-team/' >/dev/null 2>/dev/null; then
  :
else
  fail "LX13: the injection channel itself did not flip a bare check-ignore in this environment -- fixture assumption stale"
fi
env GIT_CONFIG_PARAMETERS="'core.excludesFile=$HOSTILE_LX13'" \
  bash "$INIT" "$D_LX13" >"$GTMP/lx13.out" 2>"$GTMP/lx13.err" \
  || fail "LX13: team-init exited non-zero under a GIT_CONFIG_PARAMETERS injection"
[ "$(count_warn_lines "$GTMP/lx13.err")" = "0" ] \
  || fail "LX13: GIT_CONFIG_PARAMETERS injected an excludes file and flipped the verdict"
pass "case: D8 — GIT_CONFIG_PARAMETERS cannot inject an excludes file or flip the verdict"

# --- LX14: D9 -- a legitimate global core.excludesFile reached through HOME
# No repo-local core.excludesFile is pinned for either fixture below, on
# purpose (D9): that is the only shape in which the allow-list's HOME
# membership is actually exercised.
D_LX14="$GTMP/lx14"
mkdir -p "$D_LX14"
git init -q "$D_LX14" >/dev/null 2>&1
LX14_HOME="$GTMP/lx14-home"
LX14_EMPTYHOME="$GTMP/lx14-emptyhome"
mkdir -p "$LX14_HOME" "$LX14_EMPTYHOME"
LX14_GEXCL="$GTMP/lx14-global-excludes"
printf '%s\n' '.shell-team/' > "$LX14_GEXCL"
printf '[core]\n\texcludesFile = %s\n' "$LX14_GEXCL" > "$LX14_HOME/.gitconfig"
env HOME="$LX14_HOME" bash "$INIT" "$D_LX14" >"$GTMP/lx14.out" 2>"$GTMP/lx14.err" \
  || fail "LX14: team-init exited non-zero under a legitimate global excludes file reached through HOME"
assert_v1_fired "$GTMP/lx14.err" '.shell-team' \
  || fail "LX14: a legitimate global core.excludesFile reached through HOME was not honoured"

D_LX14_EMPTY="$GTMP/lx14-empty"
mkdir -p "$D_LX14_EMPTY"
git init -q "$D_LX14_EMPTY" >/dev/null 2>&1
env HOME="$LX14_EMPTYHOME" bash "$INIT" "$D_LX14_EMPTY" >"$GTMP/lx14e.out" 2>"$GTMP/lx14e.err" \
  || fail "LX14: team-init exited non-zero under an empty scratch HOME"
[ "$(count_warn_lines "$GTMP/lx14e.err")" = "0" ] \
  || fail "LX14: expected silence under an empty scratch HOME (negative control)"
pass "case: D9 — a legitimate global core.excludesFile reached through HOME is still honoured"

# --- argument handling -----------------------------------------------------
set +e
init >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "missing target should exit 2, got $rc"
pass "missing <target_path> exits 2"

set +e
init "$TMP/does-not-exist" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "nonexistent target should exit 2, got $rc"
pass "nonexistent <target_path> exits 2"

# --- target path containing a space ----------------------------------------
T3="$TMP/with space"
mkdir -p "$T3"
init "$T3" >/dev/null 2>&1 || fail "space-in-path: team-init exited non-zero"
[ -f "$T3/.shell-team/todo.md" ] || fail "space-in-path: scaffold did not land in the target"
[ -f "$T3/.shell-team/reviews/.gitkeep" ] || fail "space-in-path: nested dir not created"
pass "target path with a space is handled"

printf '\nAll team-init assertions passed.\n'
