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
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/team-init-test-targets.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-targets.XXXXXX")"
fi

# T-1097: a SECOND, $TMPDIR-backed root reserved for git-needing fixtures,
# kept separate from the plain $TMP root above, per .shell-team/test-recipe.md's
# T-1042 entry: a `git init` under the pre-existing plain root fails with
# `Operation not permitted` copying `.git/`'s hook templates in a sandboxed
# run, even though plain non-git file writes to the same directory succeed.
if [ -n "${TMPDIR:-}" ]; then
  GIT_TMP="$(mktemp -d "${TMPDIR%/}/team-init-test-git.XXXXXX")"
else
  GIT_TMP="$(mktemp -d "$HERE/tmp-git.XXXXXX")"
fi
# GIT_CEILING_DIRECTORIES stops git's upward search for an ANCESTOR
# repository at this root — this repository's own work tree, in particular
# — which matters regardless of which arm of the fallback above fired: it is
# what makes the no-work-tree case below non-vacuous rather than accidentally
# discovering a repository above GIT_TMP. `-C <known-repo-dir>` calls
# elsewhere in this suite are unaffected: git finds their .git immediately
# and never searches upward past the ceiling.
GIT_CEILING_DIRECTORIES="$GIT_TMP"
export GIT_CEILING_DIRECTORIES

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# Run team-init with a clean env (no inherited TEAM_RUN_BASE) so default-layout
# assertions are not perturbed by the caller's environment.
init() { env -u TEAM_RUN_BASE bash "$INIT" "$@"; }

trap 'rm -rf "$TMP" "$GIT_TMP"' EXIT

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

# --- T-1057 AC14: the executor-binding specimen is scaffolded INERT --------
BINDING_TEMPLATE="$REPO_ROOT/templates/binding-template.conf"
[ -f "$T1/.shell-team/binding.conf.example" ] \
  || fail "T-1057: binding.conf.example was not scaffolded under the base dir"
[ ! -e "$T1/.shell-team/binding.conf" ] \
  || fail "T-1057: team-init must never scaffold binding.conf itself (that would silently change the default executor assignment)"
[ ! -e "$T1/binding.conf" ] && [ ! -e "$T1/binding.conf.example" ] \
  || fail "T-1057: the binding specimen must not appear at the host root"
cmp -s "$BINDING_TEMPLATE" "$T1/.shell-team/binding.conf.example" \
  || fail "T-1057: scaffolded binding.conf.example is not byte-identical to templates/binding-template.conf"
bash "$INIT" --help 2>&1 | grep -qF 'binding.conf.example' \
  || fail "T-1057: team-init --help does not name the scaffolded binding.conf.example path"
h0="$(git -C "$REPO_ROOT" hash-object "$T1/.shell-team/binding.conf.example")"
init "$T1" >/dev/null 2>&1 || fail "T-1057: team-init exited non-zero on a binding.conf.example re-run"
h1="$(git -C "$REPO_ROOT" hash-object "$T1/.shell-team/binding.conf.example")"
[ "$h0" = "$h1" ] || fail "T-1057: re-running team-init changed binding.conf.example (not idempotent)"
pass "T-1057: binding.conf.example is scaffolded inert (byte-identical to the specimen, never binding.conf, --help names it, idempotent)"

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
# the todo Format block is intentionally allowed. binding.conf.example (T-1057)
# is byte-copied from templates/binding-template.conf, which this task must
# not edit (DP10) and which carries its own authorship citation (`T-1054`) in
# its header, exactly the same class of provenance-not-bake-in citation
# templates/liveness-reasons.txt carries for `T-1056` — so it is excluded from
# this sweep by name, never by a widened pattern, and its exclusion is proven
# non-vacuous by the positive control immediately below.
leaked="$(find "$T1/.shell-team" -type f ! -name 'binding.conf.example' -print0 \
  | xargs -0 grep -lEi 'ripsawjp|loop-engineering|T-[0-9]{3,}' 2>/dev/null || true)"
[ -z "$leaked" ] || fail "AC5: repo-specific token leaked into generated files: $leaked"
pass "AC5: generated files are generic (no ripsawjp / loop-engineering / concrete T-NNN)"

# T-1057: the ONE excluded file is excluded for the stated reason, not because
# it happens to be free of the pattern — prove the pattern actually matches it.
grep -qE 'T-[0-9]{3,}' "$T1/.shell-team/binding.conf.example" \
  || fail "T-1057: fixture control failed — binding.conf.example does not carry the T-1054 provenance citation this exclusion exists for"
pass "T-1057: binding.conf.example's sole exclusion from the AC5 sweep is the byte-untouched specimen's own provenance citation, confirmed present"

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

# --- T-1057 ancestor-symlink (issue #218): scaffolding through an
# ANCESTOR-symlinked bin/ must still read the plugin's own shipped
# templates/, never a decoy planted in the adopter's own templates/ dir.
# adopter/bin -> the real, un-symlinked $REPO_ROOT/bin (ordinary vendoring,
# no hostile action) — the topology a plain `cd && pwd` bootstrap survives
# untouched, silently resolving TEMPLATES_DIR inside the ADOPTER's tree.
T_ANC="$TMP/ancestor-symlink"
mkdir -p "$T_ANC/decoyroot/adopter/templates" "$T_ANC/target"
ln -s "$REPO_ROOT/bin" "$T_ANC/decoyroot/adopter/bin"
[ -L "$T_ANC/decoyroot/adopter/bin" ] || fail "ancestor-symlink-team-init: adopter/bin was not created as a symlink"
for f in todo-template.md shell-team.contract.yaml shell-team.gitignore AGENTS.md test-recipe.md binding-template.conf; do
  cp "$REPO_ROOT/templates/$f" "$T_ANC/decoyroot/adopter/templates/$f"
done
printf '\n<!-- DECOY-MARKER-DO-NOT-SHIP -->\n' >> "$T_ANC/decoyroot/adopter/templates/todo-template.md"
cmp -s "$REPO_ROOT/templates/todo-template.md" "$T_ANC/decoyroot/adopter/templates/todo-template.md" \
  && fail "ancestor-symlink-team-init: fixture control failed — the decoy template is byte-identical to the real one"
env -u TEAM_RUN_BASE bash "$T_ANC/decoyroot/adopter/bin/team-init.sh" "$T_ANC/target" >/dev/null 2>&1 \
  || fail "ancestor-symlink-team-init: team-init exited non-zero through an ancestor-symlinked bin/"
if grep -qF 'DECOY-MARKER-DO-NOT-SHIP' "$T_ANC/target/.shell-team/todo.md"; then
  fail "ancestor-symlink-team-init: scaffold consumed the adopter's own decoy templates/ dir instead of the plugin's shipped templates/ (ancestor-directory-symlink escape)"
fi
cmp -s "$REPO_ROOT/templates/todo-template.md" "$T_ANC/target/.shell-team/todo.md" \
  || fail "ancestor-symlink-team-init: scaffolded todo.md is not byte-identical to the plugin's real shipped template"
pass "ancestor-symlink-team-init — an ancestor-symlinked bin/ (adopter/bin -> real bin/) still scaffolds from the plugin's own shipped templates/, never a decoy planted in the adopter's own templates/ dir"

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

# =============================================================================
# T-1097: --trial-branch <name>
#
# Git-needing fixtures below live under $GIT_TMP (see top of file), never
# under $TMP or $HERE/tmp-targets.*. Fixture identity uses reserved-domain
# throwaway values via `git -c user.email=... -c user.name=...` rather than
# touching any global config.
# =============================================================================

# --- T-1097 creation ---------------------------------------------------------
R1="$GIT_TMP/create-repo1"
R2="$GIT_TMP/create-repo2"
mkdir -p "$R1" "$R2"
git init -q "$R1" >/dev/null 2>&1 || fail "T-1097 creation: git init failed for repo1 (control)"
git -C "$R1" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 creation: initial commit failed for repo1 (control)"
git -C "$R1" rev-parse --verify HEAD >/dev/null 2>&1 || fail "T-1097 creation: repo1 has no HEAD (control)"
git init -q "$R2" >/dev/null 2>&1 || fail "T-1097 creation: git init failed for repo2 (control)"
git -C "$R2" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 creation: initial commit failed for repo2 (control)"
git -C "$R2" rev-parse --verify HEAD >/dev/null 2>&1 || fail "T-1097 creation: repo2 has no HEAD (control)"

init --trial-branch trial/one-ticket "$R1" >/dev/null 2>&1 \
  || fail "T-1097 creation: exited non-zero with the flag before the positional"
[ "$(git -C "$R1" symbolic-ref --short HEAD 2>/dev/null)" = "trial/one-ticket" ] \
  || fail "T-1097 creation: HEAD is not trial/one-ticket after the flag"
[ -f "$R1/.shell-team/todo.md" ] || fail "T-1097 creation: scaffold did not land (todo.md)"
[ -f "$R1/.shell-team/loops/shell-team.contract.yaml" ] || fail "T-1097 creation: scaffold did not land (contract)"

init "$R2" --force --trial-branch trial/other >/dev/null 2>&1 \
  || fail "T-1097 creation: exited non-zero with the flag after the positional, combined with --force"
[ "$(git -C "$R2" symbolic-ref --short HEAD 2>/dev/null)" = "trial/other" ] \
  || fail "T-1097 creation: HEAD is not trial/other after the flag+--force run"
[ -f "$R2/.shell-team/todo.md" ] || fail "T-1097 creation: repo2 scaffold did not land"
pass "T-1097 creation: --trial-branch creates and switches to the branch and still scaffolds, flag before or after the positional, alone or combined with --force"

# --- T-1097 args --------------------------------------------------------------
RA="$GIT_TMP/args-repo"
mkdir -p "$RA"
git init -q "$RA" >/dev/null 2>&1 || fail "T-1097 args: git init failed (control)"
git -C "$RA" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 args: initial commit failed (control)"
CUR_A="$(git -C "$RA" symbolic-ref --short HEAD 2>/dev/null)"
[ -n "$CUR_A" ] || fail "T-1097 args: fixture has no current branch (control)"

set +e
init --trial-branch >/dev/null 2>"$GIT_TMP/e1"; rc1=$?
init --trial-branch --force "$RA" >/dev/null 2>"$GIT_TMP/e2"; rc2=$?
init --trial-branch a/one --trial-branch b/two "$RA" >/dev/null 2>"$GIT_TMP/e3"; rc3=$?
init --trial-branch=a/one "$RA" >/dev/null 2>"$GIT_TMP/e4"; rc4=$?
init -- --trial-branch a/one "$RA" >/dev/null 2>"$GIT_TMP/e5"; rc5=$?
init --trial-branch bad..name "$RA" >/dev/null 2>"$GIT_TMP/e6"; rc6=$?
set -e

[ "$rc1" -eq 2 ] || fail "T-1097 args: missing value should exit 2, got $rc1"
[ "$rc2" -eq 2 ] || fail "T-1097 args: dash-leading value should exit 2, got $rc2"
[ "$rc3" -eq 2 ] || fail "T-1097 args: repeated flag should exit 2, got $rc3"
[ "$rc4" -eq 2 ] || fail "T-1097 args: --trial-branch=<name> spelling should exit 2, got $rc4"
[ "$rc5" -eq 2 ] || fail "T-1097 args: flag after a -- terminator should exit 2, got $rc5"
[ "$rc6" -eq 2 ] || fail "T-1097 args: invalid branch name should exit 2, got $rc6"

for f in e1 e2 e3 e4 e6; do
  [ -s "$GIT_TMP/$f" ] || fail "T-1097 args: $f stderr is empty"
  grep -qF -- '--trial-branch' "$GIT_TMP/$f" || fail "T-1097 args: $f does not name --trial-branch"
done
for f in e1 e2; do
  grep -qF -- 'requires a branch name' "$GIT_TMP/$f" || fail "T-1097 args: $f missing 'requires a branch name'"
done
grep -qF -- 'more than once' "$GIT_TMP/e3" || fail "T-1097 args: e3 missing 'more than once'"
grep -qF -- 'invalid' "$GIT_TMP/e6" || fail "T-1097 args: e6 missing 'invalid'"

[ ! -e "$RA/.shell-team" ] || fail "T-1097 args: a misuse run scaffolded something"
[ "$(git -C "$RA" symbolic-ref --short HEAD 2>/dev/null)" = "$CUR_A" ] \
  || fail "T-1097 args: HEAD moved during a misuse run"

init --trial-branch trial/ok "$RA" >/dev/null 2>&1 \
  || fail "T-1097 args: positive control (well-formed value) should exit 0"
pass "T-1097 args: every argument-level misuse of --trial-branch exits 2 and names the flag; a well-formed value still exits 0"

# --- T-1097 no-work-tree -------------------------------------------------------
NWT="$GIT_TMP/no-work-tree"
mkdir -p "$NWT/plain"
git -C "$NWT/plain" rev-parse --show-toplevel >/dev/null 2>&1 \
  && fail "T-1097 no-work-tree: fixture control failed — an ancestor repository makes this target non-vacuously reachable"

set +e
init --trial-branch t/x "$NWT/plain" >/dev/null 2>"$NWT/err"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "T-1097 no-work-tree: expected exit 2, got $rc"
[ -s "$NWT/err" ] || fail "T-1097 no-work-tree: stderr is empty"
grep -qF -- '--trial-branch' "$NWT/err" || fail "T-1097 no-work-tree: stderr does not name --trial-branch"
grep -qF -- 'git init' "$NWT/err" || fail "T-1097 no-work-tree: stderr does not name git init as the remedy"
[ ! -e "$NWT/plain/.shell-team" ] || fail "T-1097 no-work-tree: refusal still scaffolded a base dir"

init "$NWT/plain" >/dev/null 2>&1 || fail "T-1097 no-work-tree: no-flag path should still scaffold the same target"
[ -f "$NWT/plain/.shell-team/todo.md" ] || fail "T-1097 no-work-tree: no-flag path did not scaffold"

# A bare repository (a work tree with no working tree) is refused the same way.
BARE="$GIT_TMP/bare-refusal.git"
git init -q --bare "$BARE" >/dev/null 2>&1 || fail "T-1097 no-work-tree: git init --bare failed (control)"
set +e
init --trial-branch t/x "$BARE" >/dev/null 2>"$GIT_TMP/bare-err"; rcb=$?
set -e
[ "$rcb" -eq 2 ] || fail "T-1097 no-work-tree: bare repository target should exit 2, got $rcb"
grep -qF -- '--trial-branch' "$GIT_TMP/bare-err" || fail "T-1097 no-work-tree: bare-repo refusal does not name --trial-branch"
grep -qF -- 'git init' "$GIT_TMP/bare-err" || fail "T-1097 no-work-tree: bare-repo refusal message missing git init"
pass "T-1097 no-work-tree: --trial-branch refuses a target with no git work tree, including a bare one (exit 2, names --trial-branch and git init); the no-flag path scaffolds the same target unchanged"

# --- T-1097 not-repo-root -------------------------------------------------------
NRR="$GIT_TMP/not-repo-root"
mkdir -p "$NRR/repo/sub"
git init -q "$NRR/repo" >/dev/null 2>&1 || fail "T-1097 not-repo-root: git init failed (control)"
git -C "$NRR/repo" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 not-repo-root: initial commit failed (control)"
CUR_NRR="$(git -C "$NRR/repo" symbolic-ref --short HEAD 2>/dev/null)"
[ -n "$CUR_NRR" ] || fail "T-1097 not-repo-root: fixture has no current branch (control)"

set +e
init --trial-branch t/x "$NRR/repo/sub" >/dev/null 2>"$NRR/err"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "T-1097 not-repo-root: expected exit 2, got $rc"
[ -s "$NRR/err" ] || fail "T-1097 not-repo-root: stderr is empty"
grep -qF -- '--trial-branch' "$NRR/err" || fail "T-1097 not-repo-root: stderr does not name --trial-branch"
grep -qF -- 'repository root' "$NRR/err" || fail "T-1097 not-repo-root: stderr does not name repository root"
[ ! -e "$NRR/repo/sub/.shell-team" ] || fail "T-1097 not-repo-root: refusal still scaffolded a base dir"
[ "$(git -C "$NRR/repo" symbolic-ref --short HEAD 2>/dev/null)" = "$CUR_NRR" ] \
  || fail "T-1097 not-repo-root: HEAD moved during the refusal"

init "$NRR/repo/sub" >/dev/null 2>&1 || fail "T-1097 not-repo-root: no-flag path should still scaffold the subdirectory target"
[ -f "$NRR/repo/sub/.shell-team/todo.md" ] || fail "T-1097 not-repo-root: no-flag path did not scaffold"

# A symlinked spelling of the repository root is ACCEPTED (issue #218's own
# `pwd -P` history — a vendored/symlinked path must not produce a false
# refusal, since the top-level comparison is between OS-canonical paths).
ln -s "$NRR/repo" "$NRR/link"
init --trial-branch trial/via-link "$NRR/link" >/dev/null 2>&1 \
  || fail "T-1097 not-repo-root: a symlinked spelling of the repository root should be accepted"
[ "$(git -C "$NRR/repo" symbolic-ref --short HEAD 2>/dev/null)" = "trial/via-link" ] \
  || fail "T-1097 not-repo-root: symlinked-root run did not switch HEAD"
pass "T-1097 not-repo-root: --trial-branch refuses a subdirectory target (exit 2, names --trial-branch and repository root, no-flag path unchanged), while a symlinked spelling of the root is accepted"

# --- T-1097 branch-exists -------------------------------------------------------
BE="$GIT_TMP/branch-exists"
mkdir -p "$BE/repo"
git init -q "$BE/repo" >/dev/null 2>&1 || fail "T-1097 branch-exists: git init failed (control)"
git -C "$BE/repo" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 branch-exists: initial commit failed (control)"
git -C "$BE/repo" branch trial/exists >/dev/null 2>&1 || fail "T-1097 branch-exists: failed to create the existing branch (control)"
git -C "$BE/repo" show-ref --verify --quiet refs/heads/trial/exists \
  || fail "T-1097 branch-exists: fixture branch does not exist (control)"
T0_BE="$(git -C "$BE/repo" rev-parse refs/heads/trial/exists 2>/dev/null)"
CUR_BE="$(git -C "$BE/repo" symbolic-ref --short HEAD 2>/dev/null)"
[ -n "$T0_BE" ] || fail "T-1097 branch-exists: fixture tip control failed"
[ -n "$CUR_BE" ] || fail "T-1097 branch-exists: fixture current-branch control failed"

set +e
init --trial-branch trial/exists "$BE/repo" >/dev/null 2>"$BE/err"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "T-1097 branch-exists: expected exit 2, got $rc"
[ -s "$BE/err" ] || fail "T-1097 branch-exists: stderr is empty"
grep -qF -- '--trial-branch' "$BE/err" || fail "T-1097 branch-exists: stderr does not name --trial-branch"
grep -qF -- 'already exists' "$BE/err" || fail "T-1097 branch-exists: stderr does not name already exists"
[ "$(git -C "$BE/repo" rev-parse refs/heads/trial/exists 2>/dev/null)" = "$T0_BE" ] \
  || fail "T-1097 branch-exists: the existing branch's tip moved"
[ "$(git -C "$BE/repo" symbolic-ref --short HEAD 2>/dev/null)" = "$CUR_BE" ] \
  || fail "T-1097 branch-exists: HEAD moved during the refusal"
[ ! -e "$BE/repo/.shell-team" ] || fail "T-1097 branch-exists: refusal still scaffolded a base dir"

# Non-vacuous: a fresh name sharing a prefix with the existing one is
# accepted — the existence test is about the branch namespace, not a
# substring match.
init --trial-branch trial/exists-2 "$BE/repo" >/dev/null 2>&1 \
  || fail "T-1097 branch-exists: a near-miss-but-fresh branch name should be accepted"
[ "$(git -C "$BE/repo" symbolic-ref --short HEAD 2>/dev/null)" = "trial/exists-2" ] \
  || fail "T-1097 branch-exists: HEAD is not trial/exists-2 after the fresh-name run"
pass "T-1097 branch-exists: --trial-branch refuses an existing branch name (exit 2, names --trial-branch and already exists, nothing moves), while a fresh name sharing its prefix is accepted"

# --- T-1097 dirty-preserved -------------------------------------------------------
DP="$GIT_TMP/dirty-preserved"
mkdir -p "$DP/repo"
git init -q "$DP/repo" >/dev/null 2>&1 || fail "T-1097 dirty-preserved: git init failed (control)"
printf 'orig\n' > "$DP/repo/keep.txt"
git -C "$DP/repo" add keep.txt >/dev/null 2>&1 || fail "T-1097 dirty-preserved: add failed (control)"
git -C "$DP/repo" -c user.email=t@example.invalid -c user.name=t commit -q -m init >/dev/null 2>&1 \
  || fail "T-1097 dirty-preserved: initial commit failed (control)"
printf 'dirty\n' > "$DP/repo/keep.txt"
printf 'stray\n' > "$DP/repo/stray.txt"
cp "$DP/repo/keep.txt" "$DP/keep.save"
cp "$DP/repo/stray.txt" "$DP/stray.save"
[ -s "$DP/keep.save" ] || fail "T-1097 dirty-preserved: saved copy of keep.txt is empty (control)"
[ -s "$DP/stray.save" ] || fail "T-1097 dirty-preserved: saved copy of stray.txt is empty (control)"
C0_DP="$(git -C "$DP/repo" rev-list --count HEAD 2>/dev/null)"
[ -n "$C0_DP" ] || fail "T-1097 dirty-preserved: fixture has no commit count (control)"
git -C "$DP/repo" status --porcelain > "$DP/st0" 2>/dev/null
grep -qE '^ M keep\.txt$' "$DP/st0" || fail "T-1097 dirty-preserved: pre-run status does not show keep.txt modified (control)"
grep -qE '^\?\? stray\.txt$' "$DP/st0" || fail "T-1097 dirty-preserved: pre-run status does not show stray.txt untracked (control)"

init --trial-branch trial/dirty "$DP/repo" >/dev/null 2>&1 \
  || fail "T-1097 dirty-preserved: exited non-zero on a dirty worktree"
[ "$(git -C "$DP/repo" symbolic-ref --short HEAD 2>/dev/null)" = "trial/dirty" ] \
  || fail "T-1097 dirty-preserved: HEAD is not trial/dirty after the flag"
cmp -s "$DP/keep.save" "$DP/repo/keep.txt" || fail "T-1097 dirty-preserved: keep.txt content changed"
cmp -s "$DP/stray.save" "$DP/repo/stray.txt" || fail "T-1097 dirty-preserved: stray.txt content changed"
git -C "$DP/repo" status --porcelain > "$DP/st1" 2>/dev/null
grep -qE '^ M keep\.txt$' "$DP/st1" || fail "T-1097 dirty-preserved: post-run status lost the modified marker"
grep -qE '^\?\? stray\.txt$' "$DP/st1" || fail "T-1097 dirty-preserved: post-run status lost the untracked marker"
[ "$(git -C "$DP/repo" stash list 2>/dev/null | grep -c . || true)" = "0" ] \
  || fail "T-1097 dirty-preserved: something was stashed"
[ "$(git -C "$DP/repo" rev-list --count HEAD 2>/dev/null)" = "$C0_DP" ] \
  || fail "T-1097 dirty-preserved: a commit was created"
pass "T-1097 dirty-preserved: a dirty worktree is permitted; the flag switches HEAD without stashing, committing or reverting, and both files survive byte-for-byte"

# --- T-1097 git-free -------------------------------------------------------
GF="$GIT_TMP/git-free"
SHIM="$GF/shim"
mkdir -p "$SHIM" "$GF/plain" "$GF/plain2"
printf '#!/bin/sh\necho called >> "%s/marker"\nexit 1\n' "$GF" > "$SHIM/git"
chmod +x "$SHIM/git"

set +e
env -u TEAM_RUN_BASE PATH="$SHIM:$PATH" bash "$INIT" "$GF/plain" >/dev/null 2>&1; rc1=$?
set -e
[ "$rc1" -eq 0 ] || fail "T-1097 git-free: no-flag run exited non-zero with a failing git shim first on PATH"
[ ! -e "$GF/marker" ] || fail "T-1097 git-free: no-flag run invoked the git shim"
[ -f "$GF/plain/.shell-team/todo.md" ] || fail "T-1097 git-free: no-flag run did not scaffold"

set +e
env -u TEAM_RUN_BASE PATH="$SHIM:$PATH" bash "$INIT" --trial-branch t/x "$GF/plain2" >/dev/null 2>&1; rc2=$?
set -e
[ "$rc2" -ne 0 ] || fail "T-1097 git-free: --trial-branch run exited 0 despite a failing git shim (positive control failed)"
[ -s "$GF/marker" ] || fail "T-1097 git-free: --trial-branch run never reached the git shim (positive control failed)"
[ ! -e "$GF/plain2/.shell-team" ] || fail "T-1097 git-free: --trial-branch run scaffolded despite the shim failing"
pass "T-1097 git-free: the no-flag path invokes no git command (shim never reached, scaffold lands); --trial-branch genuinely reaches an executable git (shim reached, scaffold refused)"

# =============================================================================
# T-1097 rework (delivered-change review round 1: Major 1, Major 2, Major 3)
# =============================================================================

# --- T-1097 no-track: --no-track suppresses branch.autoSetupMerge=always ----
NT="$GIT_TMP/no-track"
mkdir -p "$NT/repo"
git init -q "$NT/repo" >/dev/null 2>&1 || fail "T-1097 no-track: git init failed (control)"
git -C "$NT/repo" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 no-track: initial commit failed (control)"
git -C "$NT/repo" config branch.autoSetupMerge always \
  || fail "T-1097 no-track: could not set branch.autoSetupMerge=always (control)"
[ "$(git -C "$NT/repo" config --get branch.autoSetupMerge 2>/dev/null)" = "always" ] \
  || fail "T-1097 no-track: branch.autoSetupMerge is not 'always' (control)"

init --trial-branch trial/notrack "$NT/repo" >/dev/null 2>&1 \
  || fail "T-1097 no-track: exited non-zero under branch.autoSetupMerge=always"
[ "$(git -C "$NT/repo" symbolic-ref --short HEAD 2>/dev/null)" = "trial/notrack" ] \
  || fail "T-1097 no-track: HEAD is not trial/notrack after the flag"
if git -C "$NT/repo" config --get branch.trial/notrack.remote >/dev/null 2>&1; then
  fail "T-1097 no-track: upstream tracking was set despite branch.autoSetupMerge=always (Major 1 regressed)"
fi
if git -C "$NT/repo" config --get branch.trial/notrack.merge >/dev/null 2>&1; then
  fail "T-1097 no-track: an upstream merge ref was set despite branch.autoSetupMerge=always (Major 1 regressed)"
fi
pass "T-1097 no-track: --trial-branch never sets upstream tracking, even under branch.autoSetupMerge=always"

# --- T-1097 at-shorthand: '@', '@{-1}', 'HEAD' as values all refuse cleanly -
ATS="$GIT_TMP/at-shorthand"
mkdir -p "$ATS/repo"
git init -q "$ATS/repo" >/dev/null 2>&1 || fail "T-1097 at-shorthand: git init failed (control)"
git -C "$ATS/repo" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 at-shorthand: initial commit failed (control)"
# A real "previous branch" so `@{-1}` has something non-synthetic to expand
# to if the flag's own validation ever mis-resolved it against this repo.
git -C "$ATS/repo" branch other >/dev/null 2>&1 || fail "T-1097 at-shorthand: could not create 'other' (control)"
git -C "$ATS/repo" switch other >/dev/null 2>&1 || fail "T-1097 at-shorthand: could not switch to 'other' (control)"
git -C "$ATS/repo" switch - >/dev/null 2>&1 || fail "T-1097 at-shorthand: could not switch back (control)"
CUR_ATS="$(git -C "$ATS/repo" symbolic-ref --short HEAD 2>/dev/null)"
H0_ATS="$(git -C "$ATS/repo" rev-parse HEAD 2>/dev/null)"
[ -n "$CUR_ATS" ] || fail "T-1097 at-shorthand: fixture has no current branch (control)"

for name in '@' '@{-1}' 'HEAD'; do
  set +e
  init --trial-branch "$name" "$ATS/repo" >/dev/null 2>"$ATS/err"; rc=$?
  set -e
  [ "$rc" -eq 2 ] || fail "T-1097 at-shorthand: '$name' should exit 2, got $rc"
  grep -qF -- '--trial-branch' "$ATS/err" || fail "T-1097 at-shorthand: '$name' refusal does not name --trial-branch"
  # '@' and '@{-1}' must be caught by this script's OWN leading-"@" guard
  # (message names "revision shorthand") — never fall through to git's own
  # raw, uncontrolled switch-collision message. "HEAD" is refused by
  # check-ref-format itself (a different, still-valid path) and carries no
  # such wording, so it is deliberately excluded from this assertion.
  case "$name" in
    '@'|'@{-1}')
      grep -qF -- 'revision shorthand' "$ATS/err" \
        || fail "T-1097 at-shorthand: '$name' was not refused by this script's own leading-@ guard (message: $(cat "$ATS/err"))"
      ;;
  esac
  rm -f "$ATS/err"
done
[ ! -e "$ATS/repo/.shell-team" ] || fail "T-1097 at-shorthand: a refusal still scaffolded a base dir"
[ "$(git -C "$ATS/repo" symbolic-ref --short HEAD 2>/dev/null)" = "$CUR_ATS" ] \
  || fail "T-1097 at-shorthand: HEAD moved during a refusal"
[ "$(git -C "$ATS/repo" rev-parse HEAD 2>/dev/null)" = "$H0_ATS" ] \
  || fail "T-1097 at-shorthand: HEAD's commit moved during a refusal"
pass "T-1097 at-shorthand: '@', '@{-1}' and 'HEAD' as --trial-branch values all refuse cleanly (exit 2, names --trial-branch), with no scaffold and no HEAD movement"

# --- T-1097 env-leak: GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE never reach the --
# --- flag's own git calls; an ambient leak must never move a DIFFERENT, ----
# --- unrelated repository's HEAD. ------------------------------------------
EL="$GIT_TMP/env-leak"
mkdir -p "$EL/decoy" "$EL/target"
git init -q "$EL/decoy" >/dev/null 2>&1 || fail "T-1097 env-leak: git init failed for the decoy (control)"
git -C "$EL/decoy" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 env-leak: initial commit failed for the decoy (control)"
DECOY_HEAD0="$(git -C "$EL/decoy" rev-parse HEAD 2>/dev/null)"
DECOY_BRANCH0="$(git -C "$EL/decoy" symbolic-ref --short HEAD 2>/dev/null)"
[ -n "$DECOY_HEAD0" ] || fail "T-1097 env-leak: decoy has no HEAD (control)"
[ -n "$DECOY_BRANCH0" ] || fail "T-1097 env-leak: decoy has no current branch (control)"
# $EL/target is deliberately NOT a git repository at all.

set +e
GIT_DIR="$EL/decoy/.git" GIT_WORK_TREE="$EL/target" \
  env -u TEAM_RUN_BASE bash "$INIT" --trial-branch trial/leak "$EL/target" >/dev/null 2>"$EL/err"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "T-1097 env-leak: a leaked GIT_DIR/GIT_WORK_TREE should still exit 2, got $rc"
[ -s "$EL/err" ] || fail "T-1097 env-leak: stderr is empty"
grep -qF -- '--trial-branch' "$EL/err" || fail "T-1097 env-leak: stderr does not name --trial-branch"
[ "$(git -C "$EL/decoy" rev-parse HEAD 2>/dev/null)" = "$DECOY_HEAD0" ] \
  || fail "T-1097 env-leak: the DECOY repository's HEAD commit moved (Major 3 regressed)"
[ "$(git -C "$EL/decoy" symbolic-ref --short HEAD 2>/dev/null)" = "$DECOY_BRANCH0" ] \
  || fail "T-1097 env-leak: the DECOY repository's current branch changed (Major 3 regressed)"
[ ! -e "$EL/target/.shell-team" ] || fail "T-1097 env-leak: the (non-repository) target got scaffolded"

# GIT_INDEX_FILE alone, against a genuinely valid target, must not derail a
# legitimate run (the neutralization must not merely refuse everything).
IL="$GIT_TMP/env-leak-index"
mkdir -p "$IL/repo"
git init -q "$IL/repo" >/dev/null 2>&1 || fail "T-1097 env-leak: git init failed for the index-leak repo (control)"
git -C "$IL/repo" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1 \
  || fail "T-1097 env-leak: initial commit failed for the index-leak repo (control)"
GIT_INDEX_FILE="$IL/decoy-index" \
  env -u TEAM_RUN_BASE bash "$INIT" --trial-branch trial/idx "$IL/repo" >/dev/null 2>&1 \
  || fail "T-1097 env-leak: a leaked GIT_INDEX_FILE broke an otherwise-legitimate run"
[ "$(git -C "$IL/repo" symbolic-ref --short HEAD 2>/dev/null)" = "trial/idx" ] \
  || fail "T-1097 env-leak: HEAD is not trial/idx after the legitimate GIT_INDEX_FILE-leak run"
[ -f "$IL/repo/.shell-team/todo.md" ] || fail "T-1097 env-leak: the legitimate run did not scaffold"
pass "T-1097 env-leak: GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE never reach the flag's own git calls — a leaked GIT_DIR/GIT_WORK_TREE refuses cleanly without moving an unrelated decoy repository's HEAD, and a leaked GIT_INDEX_FILE alone does not break an otherwise-legitimate run"

printf '\nAll team-init assertions passed.\n'
