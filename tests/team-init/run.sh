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

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# Run team-init with a clean env (no inherited TEAM_RUN_BASE) so default-layout
# assertions are not perturbed by the caller's environment.
init() { env -u TEAM_RUN_BASE bash "$INIT" "$@"; }

trap 'rm -rf "$TMP"' EXIT

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

printf '\nAll team-init assertions passed.\n'
