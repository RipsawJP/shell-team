#!/usr/bin/env bash
# run.sh — assert bin/check-prompt-sync.sh honors the T-039 behavior contract
# (docs/specs/T-039-prompt-sync.md):
#   AC1  canonical blocks exist in two modes (marker verbatim / core contain)
#   AC2  canonical changed + consumer unchanged => drift (exit 1)
#   AC3  real-repo dogfood is green (exit 0)
#   AC4  missing markers / missing consumer / unregistered variant => exit 1
#   AC5  this suite follows the tests/<name>/run.sh pattern
#   AC6  new scripts shellcheck clean (soft-skip when unavailable)
#   AC7  CI wiring (shellcheck list + fixture suite + dogfood step)
#   AC8  behavior-invariance: existing validator suites stay green and their
#        fixed tokens still appear in the operational files (no repo-wide
#        negative greps — the known false-positive lesson)
#
# Temp roots live under $TMPDIR when set (restricted sandboxes), falling back
# to $HERE/tmp-roots on plain CI runners. Cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-prompt-sync.sh"
FIX="$HERE/fixtures/root"
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-prompt-sync-test-roots.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$TMP"' EXIT

clone_fixture() {
  local dst="$1"
  rm -rf "$dst"
  cp -R "$FIX" "$dst"
}

run_checker() {  # $1 = root; returns checker's exit code
  local rc=0
  bash "$CHECKER" --root "$1" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}

# --- AC1/AC5: pristine fixture (both modes present) is green -------------------
C="$TMP/pristine"
clone_fixture "$C"
[ "$(run_checker "$C")" -eq 0 ] || fail "AC1: pristine fixture (marker + contain modes) should be green"
pass "AC1: canonical blocks in both modes verify green on a sync'd tree"

# --- AC2: canonical changed, consumer unchanged => drift -----------------------
C="$TMP/canonical-changed"
clone_fixture "$C"
printf '## Core\n\n- A NEW canonical sentence the consumers do not carry yet.\n' \
  > "$C/templates/prompt-blocks/core.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC2: canonical-only change must be detected as drift (exit 1)"
pass "AC2: canonical change without consumer follow-up => drift"

# --- AC4: marker missing / duplicated / reversed ------------------------------
C="$TMP/marker-missing"
clone_fixture "$C"
grep -v 'BEGIN prompt-block: core' "$C/consumer-marker.md" > "$C/consumer-marker.md.new"
mv "$C/consumer-marker.md.new" "$C/consumer-marker.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: missing BEGIN marker must exit 1"

C="$TMP/marker-dup"
clone_fixture "$C"
printf '<!-- BEGIN prompt-block: core -->\n' >> "$C/consumer-marker.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: duplicated BEGIN marker must exit 1"

C="$TMP/marker-reversed"
clone_fixture "$C"
awk '
  /BEGIN prompt-block: core/ { print "<!-- END prompt-block: core -->"; next }
  /END prompt-block: core/   { print "<!-- BEGIN prompt-block: core -->"; next }
  { print }
' "$C/consumer-marker.md" > "$C/consumer-marker.md.new"
mv "$C/consumer-marker.md.new" "$C/consumer-marker.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: reversed markers must exit 1"
pass "AC4: missing / duplicated / reversed markers are all rejected"

# --- AC4: contain-mode token dropped (unregistered variant) --------------------
C="$TMP/token-dropped"
clone_fixture "$C"
printf '# Consumer with a dropped second token\n\nOnly TOKEN_A remains.\n' > "$C/consumer-tokens.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: dropped invariant token must exit 1"
pass "AC4: contain-mode drops an invariant token => drift"

# --- AC4: registered consumer file missing ------------------------------------
C="$TMP/consumer-missing"
clone_fixture "$C"
rm "$C/consumer-tokens.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "AC4: registered-but-missing consumer must exit 1"
pass "AC4: registered consumer file missing => drift"

# --- marker region drift (content edited inside markers) -----------------------
C="$TMP/region-drift"
clone_fixture "$C"
sed 's/canonical core sentence/EDITED core sentence/' "$C/consumer-marker.md" > "$C/consumer-marker.md.new"
mv "$C/consumer-marker.md.new" "$C/consumer-marker.md"
[ "$(run_checker "$C")" -eq 1 ] || fail "edited marker region must exit 1"
pass "marker-region edit (consumer-side drift) is detected"

# --- CRLF tolerance: a CRLF consumer stays green ------------------------------
C="$TMP/crlf"
clone_fixture "$C"
sed 's/$/\r/' "$C/consumer-marker.md" > "$C/consumer-marker.md.new"
mv "$C/consumer-marker.md.new" "$C/consumer-marker.md"
rc="$(run_checker "$C")"
[ "$rc" -eq 0 ] || fail "CRLF line endings in a consumer should normalize to green, got $rc"
pass "CRLF consumer normalizes to green (T-038 review lesson carried forward)"

# --- usage / configuration errors => exit 2 ------------------------------------
C="$TMP/no-registry"
clone_fixture "$C"
rm "$C/templates/prompt-blocks/registry.txt"
[ "$(run_checker "$C")" -eq 2 ] || fail "missing registry must exit 2"

C="$TMP/bad-mode"
clone_fixture "$C"
printf 'transclude core.md consumer-marker.md\n' >> "$C/templates/prompt-blocks/registry.txt"
[ "$(run_checker "$C")" -eq 2 ] || fail "unknown registry mode must exit 2"

C="$TMP/no-canonical"
clone_fixture "$C"
rm "$C/templates/prompt-blocks/tokens.md"
[ "$(run_checker "$C")" -eq 2 ] || fail "missing canonical block file must exit 2"

rc=0
bash "$CHECKER" --root "$TMP/pristine" --bogus-flag >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "unknown flag must exit 2, got $rc"
pass "usage/config errors (registry / mode / canonical / args) all exit 2"

# --- T-087 AC9/AC12: mktemp failure => exit 2 (env error), NEVER exit 1 (drift) --
# check_marker()'s two mktemp calls must be fail-closed onto exit 2 via `die`,
# not degrade into a spurious drift verdict. Point $TMPDIR at a non-existent,
# non-writable directory so mktemp fails deterministically; the pristine
# fixture's first registry entry is marker-mode, so check_marker (the mktemp
# site) is reached before the run could otherwise complete green.
rc=0
err="$(TMPDIR=/nonexistent-tmp-t087 bash "$CHECKER" --root "$TMP/pristine" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 2 ] || fail "mktemp failure (broken TMPDIR) must exit 2, got $rc (output: $err)"
pass "mktemp failure under broken TMPDIR exits 2 (env error), not a spurious drift verdict"

# --- T-089 (#293): partial-mktemp failure (first mktemp succeeds, second -------
# fails) must exit 2 AND leave no leaked tmp_region temp file behind. A PATH
# shim `mktemp` delegates to the REAL mktemp (resolved BEFORE shadowing it on
# PATH) for the *region* temp but fails (exit 1) for the *canon* temp
# (distinguished by the template argument), so check_marker() exercises
# exactly the "first succeeds, second fails" path D-e's fix closes. The
# pristine fixture's first registry entry is marker-mode, so check_marker is
# reached.
REAL_MKTEMP="$(command -v mktemp)"
SHIM_DIR="$TMP/mktemp-shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/mktemp" <<SHIM
#!/usr/bin/env bash
case "\$*" in
  *canon*) exit 1 ;;
  *) exec "$REAL_MKTEMP" "\$@" ;;
esac
SHIM
chmod +x "$SHIM_DIR/mktemp"

SHIM_TMPDIR="$TMP/shim-tmpdir"
mkdir -p "$SHIM_TMPDIR"
rc=0
err="$(PATH="$SHIM_DIR:$PATH" TMPDIR="$SHIM_TMPDIR" bash "$CHECKER" --root "$TMP/pristine" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 2 ] || fail "T-089: partial-mktemp failure (second mktemp fails) must exit 2, got $rc (output: $err)"
leaked="$(find "$SHIM_TMPDIR" -name 'prompt-sync-region.*' 2>/dev/null)"
[ -z "$leaked" ] || fail "T-089: partial-mktemp failure leaked a temp file: $leaked"
pass "T-089: partial-mktemp failure (first mktemp succeeds, second fails) exits 2 with no leaked prompt-sync-region.* temp file"

# --- T-089 rework (Codex round1 Major): the cleanup `rm -f "$tmp_region"` -------
# itself failing (e.g. the same TMPDIR-lost-writability condition that just
# failed the second mktemp) must NOT let `set -euo pipefail`'s errexit escape
# before `die` runs — a failing command INSIDE a `{ ...; }` brace-group is NOT
# protected by the group's own outer `||`, only the group's overall exit
# status is, so the cleanup must be best-effort (`|| true`). A SEPARATE PATH
# shim dir is used (not the one above) so this rm-failure shim never affects
# the prior assertion: it intercepts `rm` ONLY for paths containing
# `prompt-sync-region` (the cleanup call's target) and fails those, while
# delegating every other `rm` invocation (real mktemp is untouched here) to
# the real binary.
REAL_RM="$(command -v rm)"
SHIM_DIR2="$TMP/mktemp-rm-shim"
mkdir -p "$SHIM_DIR2"
cat > "$SHIM_DIR2/mktemp" <<SHIM
#!/usr/bin/env bash
case "\$*" in
  *canon*) exit 1 ;;
  *) exec "$REAL_MKTEMP" "\$@" ;;
esac
SHIM
cat > "$SHIM_DIR2/rm" <<SHIM
#!/usr/bin/env bash
case "\$*" in
  *prompt-sync-region*) exit 1 ;;
  *) exec "$REAL_RM" "\$@" ;;
esac
SHIM
chmod +x "$SHIM_DIR2/mktemp" "$SHIM_DIR2/rm"

SHIM_TMPDIR2="$TMP/shim-tmpdir2"
mkdir -p "$SHIM_TMPDIR2"
rc=0
err="$(PATH="$SHIM_DIR2:$PATH" TMPDIR="$SHIM_TMPDIR2" bash "$CHECKER" --root "$TMP/pristine" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 2 ] || fail "T-089 rework: partial-mktemp failure with cleanup rm ALSO failing must still exit 2 (die), got $rc (output: $err)"
printf '%s' "$err" | grep -qF 'cannot create temp file' \
  || fail "T-089 rework: die's diagnostic message must still be printed even when the cleanup rm fails, got: $err"
pass "T-089 rework: cleanup rm failing on the partial-mktemp path does not escape errexit — die's exit 2 + diagnostic are still reached"

# --- AC3: real-repo dogfood -----------------------------------------------------
bash "$CHECKER" --root "$REPO_ROOT" >/dev/null \
  || fail "AC3: real repo must be in sync (bin/check-prompt-sync.sh green)"
pass "AC3: real-repo dogfood green (all registered blocks in sync)"

# --- T-040 AC1: careful-execution canonical block covers all 4 pillars ---------
CE_BLOCK="$REPO_ROOT/templates/prompt-blocks/careful-execution.md"
[ -r "$CE_BLOCK" ] || fail "T-040 AC1: templates/prompt-blocks/careful-execution.md must exist"
grep -qF 'verifiable seams'          "$CE_BLOCK" || fail "T-040 AC1: pillar 1 (decompose at verifiable seams) missing"
grep -qF 'observed evidence'         "$CE_BLOCK" || fail "T-040 AC1: pillar 2 (completion claims require observed evidence) missing"
grep -qF 'forward progress'          "$CE_BLOCK" || fail "T-040 AC1: pillar 3 (3-way result classification) missing"
grep -qF 'stalled'                   "$CE_BLOCK" || fail "T-040 AC1: pillar 3 (stalled classification) missing"
grep -qF 'regressed'                 "$CE_BLOCK" || fail "T-040 AC1: pillar 3 (regressed classification) missing"
grep -qF 'Two consecutive stalled-or-regressed results' "$CE_BLOCK" \
  || fail "T-040 AC1: pillar 3 (two-strike re-plan rule) missing"
grep -qF 'Make uncertainty explicit' "$CE_BLOCK" || fail "T-040 AC1: pillar 4 (uncertainty explicit) missing"
grep -qF 'escalate'                  "$CE_BLOCK" || fail "T-040 AC1: pillar 4 (escalate on weak evidence) missing"
pass "T-040 AC1: careful-execution.md covers all 4 pillars"

# --- T-040 AC2: careful-execution canonical block is self-contained ------------
# Scoped to the canonical block file itself (never a repo-wide negative grep —
# the T-039 false-positive lesson).
for forbidden in 'hard-task-protocol' 'tasks/lessons.md' 'check-prompt-sync' \
                 'templates/prompt-blocks' 'bin/check' 'agents/' 'skills/' '.claude'; do
  if grep -qF "$forbidden" "$CE_BLOCK"; then
    fail "T-040 AC2: careful-execution.md must be self-contained — found forbidden reference '$forbidden'"
  fi
done
pass "T-040 AC2: careful-execution.md is self-contained (no external skill/path/mechanism refs)"

# --- T-040 AC5: canonical drift on careful-execution is detected ----------------
# Snapshot just the files this block's registry line(s) touch, prove pristine is
# green, then mutate the canonical file only and prove it flips to drift (exit 1).
C="$TMP/careful-execution-drift"
rm -rf "$C"
mkdir -p "$C/templates/prompt-blocks" "$C/agents"
cp "$CE_BLOCK" "$C/templates/prompt-blocks/careful-execution.md"
grep 'careful-execution\.md' "$REPO_ROOT/templates/prompt-blocks/registry.txt" \
  > "$C/templates/prompt-blocks/registry.txt"
[ -s "$C/templates/prompt-blocks/registry.txt" ] \
  || fail "T-040 AC5: registry.txt must register careful-execution.md consumers"
for consumer in agents/engineer.md agents/qa-verifier.md agents/tech-lead.md; do
  cp "$REPO_ROOT/$consumer" "$C/$consumer"
done
[ "$(run_checker "$C")" -eq 0 ] \
  || fail "T-040 AC5: pristine careful-execution snapshot should be in sync"
printf '\n- An extra sentence the consumers do not carry yet.\n' \
  >> "$C/templates/prompt-blocks/careful-execution.md"
[ "$(run_checker "$C")" -eq 1 ] \
  || fail "T-040 AC5: editing careful-execution.md without updating consumers must drift (exit 1)"
pass "T-040 AC5: careful-execution canonical drift without consumer follow-up is detected"

# --- AC6: shellcheck (soft-skip when unavailable) -------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "AC6: scripts must be shellcheck clean"
  pass "AC6: shellcheck clean (checker + test runner)"
else
  printf 'SKIP: AC6 shellcheck not installed locally (CI enforces it)\n'
fi

# --- AC7: CI wiring --------------------------------------------------------------
CI_YML="$REPO_ROOT/.github/workflows/check-handoff.yml"
grep -q 'bin/check-prompt-sync.sh' "$CI_YML"      || fail "AC7: CI shellcheck list must include bin/check-prompt-sync.sh"
grep -q 'tests/check-prompt-sync/run.sh' "$CI_YML" || fail "AC7: CI must run the check-prompt-sync fixture suite"
grep -q 'bash bin/check-prompt-sync.sh' "$CI_YML"  || fail "AC7: CI must dogfood the checker against this repo"
pass "AC7: CI wires shellcheck + fixture suite + dogfood"

# --- AC8: behavior-invariance ----------------------------------------------------
# (a) existing validator suites stay green. In restricted sandboxes some legacy
# suites use bare mktemp and die on 'Operation not permitted' — that is an
# environment limitation, not a regression; CI runs them unrestricted.
for suite in check-handoff check-design-note check-retro goal-state; do
  out=""
  rc=0
  out="$(bash "$REPO_ROOT/tests/$suite/run.sh" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    if printf '%s' "$out" | grep -q 'Operation not permitted'; then
      printf 'SKIP: AC8 %s suite blocked by sandbox (CI enforces it)\n' "$suite"
    else
      fail "AC8: existing suite tests/$suite/run.sh regressed (exit $rc)"
    fi
  fi
done
# (b) the fixed tokens those validators depend on still appear in the
# operational files (targeted greps — never repo-wide negatives).
for t in READY_FOR_ARCH READY_FOR_ENG READY_FOR_QA READY_FOR_REVIEW READY_FOR_MERGE BLOCKED REWORK; do
  grep -qF "$t" "$REPO_ROOT/bin/check-handoff.sh" || fail "AC8: flag token $t vanished from check-handoff.sh"
done
for t in PASS FAIL APPROVE REQUEST_CHANGES; do
  grep -qF "$t" "$REPO_ROOT/bin/goal-state.sh" || fail "AC8: verdict token $t vanished from goal-state.sh"
done
grep -qF '**Aesthetic direction**' "$REPO_ROOT/bin/check-design-note.sh" \
  || fail "AC8: design-note heading token vanished from check-design-note.sh"
grep -qF '# Retro' "$REPO_ROOT/bin/check-retro.sh" \
  || fail "AC8: retro H1 token vanished from check-retro.sh"
pass "AC8: existing validators green (or sandbox-skipped) and fixed tokens intact"

printf '\nAll check-prompt-sync assertions passed.\n'
