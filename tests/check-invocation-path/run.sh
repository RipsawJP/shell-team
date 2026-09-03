#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-invocation-path.sh (T-1118; GitHub
# issue #419; .shell-team/specs/T-1118-alternate-executor-invocation-path.md).
#
# Its scratch root is built with `mktemp -d "${TMPDIR:-/tmp}/...XXXXXX"`
# ONLY — never a same-directory fallback: every mutation-driven case below
# copies an installed tree (bin/ + templates/) out of the checkout and
# mutates the scratch copy, the idiom tests/resolve-executor/run.sh:44-55
# establishes, so the copied gate's real $SCRIPT_DIR-relative resolution
# is what actually runs.
#
# CI wiring this suite itself asserts: a shellcheck argument naming both
# this suite and bin/check-invocation-path.sh, a step running
# `bash tests/check-invocation-path/run.sh`, and a dogfood step running
# `bash bin/check-invocation-path.sh --role tech-lead` against this
# repository.

set -euo pipefail

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SUITE_DIR/../.." && pwd -P)"
GATE="$REPO_ROOT/bin/check-invocation-path.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"
DEFAULT_CONF="$REPO_ROOT/templates/binding-default.conf"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-invocation-path-test.XXXXXX")" || { echo "FAIL: could not create scratch root" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# build_installed_tree <dest> — a scratch copy of bin/ + templates/ +
# agents/, the ONLY sanctioned way to exercise a mutated recipe/conf/
# sibling/agent-definition: this gate has no override flag of its own, and
# running the copied gate additionally exercises the real
# $SCRIPT_DIR-relative resolution rather than a test-only path. agents/
# joins the copy because the wrapper-hosted derivation (DP-m) reads a
# role's own agents/<role>.md from the gate's own installed directory.
build_installed_tree() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$REPO_ROOT/bin" "$dest/bin"
  cp -R "$REPO_ROOT/templates" "$dest/templates"
  mkdir -p "$dest/agents"
  cp "$REPO_ROOT"/agents/*.md "$dest/agents/"
  chmod +x "$dest/bin/check-invocation-path.sh"
}

test -r "$GATE" || { echo "FAIL: gate missing: $GATE" >&2; exit 1; }

# =============================================================================
# cip-help
# =============================================================================
out="$(bash "$GATE" --help 2>/dev/null)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cip-help: expected exit 0, got $rc"
[ -n "$out" ] || fail "cip-help: expected non-empty output"
nlines="$(printf '%s\n' "$out" | grep -c . || true)"
[ "$nlines" -ge 15 ] || fail "cip-help: expected >=15 non-blank lines, got $nlines"
for lit in 'Usage:' '--role' '--print-resolved' 'no availability claim' '--print-contract' \
  'invocation-recipe' 'wires-role' 'admits-authority' 'no-recipe' 'role-not-wired' \
  'authority-incompatible' 'Exit codes:' 'composes no argv' 'read-only' '#419' 'T-1118'; do
  printf '%s\n' "$out" | grep -qF -- "$lit" || fail "cip-help: expected literal missing: $lit"
done
pass "cip-help — exits 0, >=15 non-blank lines, carries every required literal"

# =============================================================================
# cip-ci-wiring
# =============================================================================
test -r "$WORKFLOW" || fail "cip-ci-wiring: workflow file unreadable: $WORKFLOW"
grep -qF -- 'bin/check-invocation-path.sh' "$WORKFLOW" || fail "cip-ci-wiring: expected bin/check-invocation-path.sh named"
grep -qF -- 'tests/check-invocation-path/run.sh' "$WORKFLOW" || fail "cip-ci-wiring: expected this suite named"
grep -qF -- 'bash tests/check-invocation-path/run.sh' "$WORKFLOW" || fail "cip-ci-wiring: expected a step running this suite"
grep -qE 'bash bin/check-invocation-path\.sh --role tech-lead' "$WORKFLOW" || fail "cip-ci-wiring: expected a dogfood step (--role tech-lead)"
pass "cip-ci-wiring — workflow names both files, runs this suite, and dogfoods --role tech-lead"

# =============================================================================
# cip-narrowing-declarations (AC2 shape, re-derived live)
# =============================================================================
RECIPE="$REPO_ROOT/templates/prompt-blocks/alternate-executor-invocation.md"
test -r "$RECIPE" || fail "cip-narrowing-declarations: recipe missing: $RECIPE"
n="$(grep -c '^invocation-recipe ' "$RECIPE" || true)"
[ "$n" = "2" ] || fail "cip-narrowing-declarations: expected exactly 2 invocation-recipe lines, got $n"
n="$(grep -c '^wires-role codex-cli ' "$RECIPE" || true)"
[ "$n" = "1" ] || fail "cip-narrowing-declarations: expected exactly 1 wires-role codex-cli line, got $n"
n="$(grep -c '^admits-authority codex-cli ' "$RECIPE" || true)"
[ "$n" = "1" ] || fail "cip-narrowing-declarations: expected exactly 1 admits-authority codex-cli line, got $n"
n="$(grep -cF -- '--adapters' "$RECIPE" || true)"
[ "$n" = "0" ] || fail "cip-narrowing-declarations: expected zero --adapters occurrences, got $n"
pass "cip-narrowing-declarations — the recipe's declaration counts match the one-role/one-adapter/one-sandbox-mode narrowing"

# =============================================================================
# cip-default-all-six-admit (AC12, first part)
# =============================================================================
DEF_TREE="$TMP/default"
build_installed_tree "$DEF_TREE"
test -r "$DEFAULT_CONF" || fail "cip-default-all-six-admit: default binding missing: $DEFAULT_CONF"
mapfile_roles="$TMP/roles.txt"
awk '$1=="bind"{print $2}' "$DEFAULT_CONF" | LC_ALL=C sort -u > "$mapfile_roles"
role_count="$(grep -c . "$mapfile_roles" || true)"
[ "$role_count" = "6" ] || fail "cip-default-all-six-admit: expected exactly 6 live roles, got $role_count"
while IFS= read -r r; do
  [ -n "$r" ] || continue
  o="$TMP/def-$r.out"; e="$TMP/def-$r.err"
  if bash "$DEF_TREE/bin/check-invocation-path.sh" --role "$r" >"$o" 2>"$e"; then
    [ -s "$o" ] || fail "cip-default-all-six-admit: role '$r' admitted but printed empty stdout"
  else
    fail "cip-default-all-six-admit: role '$r' expected exit 0 under the shipped default, got refused ($(cat "$e" 2>/dev/null))"
  fi
done < "$mapfile_roles"
pass "cip-default-all-six-admit — every live role from templates/binding-default.conf admitted under the shipped default"

# =============================================================================
# cip-probe-free (AC12, second part)
# =============================================================================
PF_TREE="$TMP/probefree"
build_installed_tree "$PF_TREE"
cp "$PF_TREE/bin/resolve-executor.sh" "$TMP/re.orig"
bash "$PF_TREE/bin/resolve-executor.sh" --print-resolved > "$TMP/resolved.real" 2>/dev/null \
  || fail "cip-probe-free: could not capture the real --print-resolved output"
[ -s "$TMP/resolved.real" ] || fail "cip-probe-free: expected non-empty --print-resolved output"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' "if [ \"\${1:-}\" = \"--print-resolved\" ]; then cat '$TMP/resolved.real'; exit 0; fi"
  printf '%s\n' 'exit 2'
} > "$PF_TREE/bin/resolve-executor.sh"
chmod +x "$PF_TREE/bin/resolve-executor.sh"
if bash "$PF_TREE/bin/resolve-executor.sh" --role tech-lead >/dev/null 2>&1; then
  fail "cip-probe-free: expected the stub to fail on --role tech-lead"
fi
bash "$PF_TREE/bin/resolve-executor.sh" --print-resolved >/dev/null 2>&1 \
  || fail "cip-probe-free: expected the stub to succeed on --print-resolved"
if bash "$PF_TREE/bin/check-invocation-path.sh" --role tech-lead >/dev/null 2>&1; then
  pass "cip-probe-free — the gate still admits tech-lead after --role is stubbed to fail, proving it reads --print-resolved only"
else
  fail "cip-probe-free: expected the gate to still exit 0 for tech-lead with the --role probe stubbed to fail"
fi
cp "$TMP/re.orig" "$PF_TREE/bin/resolve-executor.sh"
chmod +x "$PF_TREE/bin/resolve-executor.sh"
bash "$PF_TREE/bin/check-invocation-path.sh" --role tech-lead >/dev/null 2>&1 \
  || fail "cip-probe-free: expected the gate to still exit 0 for tech-lead after the real sibling is restored"

# =============================================================================
# cip-reviewer-rebound-admitted (AC12, third part)
# =============================================================================
RB_TREE="$TMP/rebound"
build_installed_tree "$RB_TREE"
RB_CONF="$RB_TREE/templates/binding-default.conf"
sed -E 's/^bind([[:space:]]+)codex-reviewer([[:space:]]+)codex([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)codex-cli/bind\1codex-reviewer\2claude\3sonnet\4-\5claude-cli/' \
  "$DEFAULT_CONF" > "$RB_CONF"
grep -qE '^bind[[:space:]]+codex-reviewer[[:space:]]+claude[[:space:]]' "$RB_CONF" \
  || fail "cip-reviewer-rebound-admitted: rebind did not apply"
bash "$RB_TREE/bin/check-binding.sh" --config "$RB_CONF" >/dev/null 2>&1 \
  || fail "cip-reviewer-rebound-admitted: rebound conf failed to validate"
if bash "$RB_TREE/bin/check-invocation-path.sh" --role codex-reviewer >/dev/null 2>&1; then
  pass "cip-reviewer-rebound-admitted — codex-reviewer rebound to claude-cli is admitted, a documented shipped capability"
else
  fail "cip-reviewer-rebound-admitted: expected codex-reviewer rebound to claude-cli to be admitted"
fi

# =============================================================================
# cip-wrapper-hosted-admitted (AC12/DP-m — the wrapper-hosted derivation)
# =============================================================================
WH_TREE="$TMP/wrapperhosted"
build_installed_tree "$WH_TREE"
grep -qE '^[[:space:]]*codex exec ' "$WH_TREE/agents/codex-reviewer.md" \
  || fail "cip-wrapper-hosted-admitted: agents/codex-reviewer.md carries no anchored bare 'codex exec ' line"
o="$TMP/wh.out"; e="$TMP/wh.err"
rc=0
bash "$WH_TREE/bin/check-invocation-path.sh" --role codex-reviewer > "$o" 2> "$e" || rc=$?
[ "$rc" -eq 0 ] || fail "cip-wrapper-hosted-admitted: expected exit 0, got $rc"
[ -s "$o" ] || fail "cip-wrapper-hosted-admitted: expected non-empty stdout"
grep -qF -- 'wrapper-hosted' "$o" || fail "cip-wrapper-hosted-admitted: expected the wrapper-hosted token on stdout"
grep -qF -- 'agents/codex-reviewer.md' "$o" || fail "cip-wrapper-hosted-admitted: expected the agent file named on stdout"
pass "cip-wrapper-hosted-admitted — codex-reviewer, unwired and unadmitted by the recipe, is admitted wrapper-hosted by its own agent definition"

# =============================================================================
# cip-wrapper-line-removed-refused (AC13(vi) — the derivation is derived,
# not hardcoded: removing the anchored line flips the admission)
# =============================================================================
WL_TREE="$TMP/wrapperline"
build_installed_tree "$WL_TREE"
bash "$WL_TREE/bin/check-invocation-path.sh" --role codex-reviewer >/dev/null 2>&1 \
  || fail "cip-wrapper-line-removed-refused: expected the pristine tree to admit codex-reviewer first"
grep -vE '^[[:space:]]*codex exec ' "$REPO_ROOT/agents/codex-reviewer.md" > "$WL_TREE/agents/codex-reviewer.md"
n="$(grep -cE '^[[:space:]]*codex exec ' "$WL_TREE/agents/codex-reviewer.md" || true)"
[ "$n" = "0" ] || fail "cip-wrapper-line-removed-refused: mutation did not remove the anchored line"
o="$TMP/wl.out"; e="$TMP/wl.err"
rc=0
bash "$WL_TREE/bin/check-invocation-path.sh" --role codex-reviewer > "$o" 2> "$e" || rc=$?
[ "$rc" -eq 1 ] || fail "cip-wrapper-line-removed-refused: expected exit 1, got $rc"
[ ! -s "$o" ] || fail "cip-wrapper-line-removed-refused: expected zero bytes on stdout"
grep -qF -- 'role-not-wired' "$e" || fail "cip-wrapper-line-removed-refused: expected the role-not-wired token on stderr"
pass "cip-wrapper-line-removed-refused — removing codex-reviewer's own anchored codex exec line flips its admission to role-not-wired"

# =============================================================================
# cip-nonwrapper-authority-incompatible (AC13(v) — the derivation's
# negative side: a non-wrapper role wired onto the path still refuses)
# =============================================================================
NW_TREE="$TMP/nonwrapper"
build_installed_tree "$NW_TREE"
NW_CONF="$NW_TREE/templates/binding-default.conf"
NW_RECIPE="$NW_TREE/templates/prompt-blocks/alternate-executor-invocation.md"
sed -E 's/^bind([[:space:]]+)pm-spec([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1pm-spec\2codex\3provider-configured\4-\5codex-cli/' \
  "$DEFAULT_CONF" > "$NW_CONF"
bash "$NW_TREE/bin/check-binding.sh" --config "$NW_CONF" >/dev/null 2>&1 \
  || fail "cip-nonwrapper-authority-incompatible: rebound conf failed to validate"
printf '%s\n' 'wires-role codex-cli pm-spec' >> "$NW_RECIPE"
grep -qxF -- 'wires-role codex-cli pm-spec' "$NW_RECIPE" || fail "cip-nonwrapper-authority-incompatible: appended wires-role row missing"
n="$(grep -cE '^[[:space:]]*codex exec ' "$NW_TREE/agents/pm-spec.md" || true)"
[ "$n" = "0" ] || fail "cip-nonwrapper-authority-incompatible: agents/pm-spec.md unexpectedly carries an anchored codex exec line"
o="$TMP/nw.out"; e="$TMP/nw.err"
rc=0
bash "$NW_TREE/bin/check-invocation-path.sh" --role pm-spec > "$o" 2> "$e" || rc=$?
[ "$rc" -eq 1 ] || fail "cip-nonwrapper-authority-incompatible: expected exit 1, got $rc"
[ ! -s "$o" ] || fail "cip-nonwrapper-authority-incompatible: expected zero bytes on stdout"
grep -qF -- 'authority-incompatible' "$e" || fail "cip-nonwrapper-authority-incompatible: expected the authority-incompatible token on stderr"
pass "cip-nonwrapper-authority-incompatible — pm-spec (not a wrapper) wired onto the read-only path still refuses authority-incompatible"

# =============================================================================
# cip-no-recipe (AC13(iii))
# =============================================================================
NR_TREE="$TMP/norecipe"
build_installed_tree "$NR_TREE"
NR_RECIPE="$NR_TREE/templates/prompt-blocks/alternate-executor-invocation.md"
bash "$NR_TREE/bin/check-invocation-path.sh" --role pm-spec >/dev/null 2>&1 \
  || fail "cip-no-recipe: expected pristine tree to admit pm-spec first"
grep -v '^invocation-recipe claude-cli in-process$' "$NR_RECIPE" > "$TMP/nr.tmp" && mv "$TMP/nr.tmp" "$NR_RECIPE"
n="$(grep -cxF -- 'invocation-recipe claude-cli in-process' "$NR_RECIPE" || true)"
[ "$n" = "0" ] || fail "cip-no-recipe: mutation did not remove the claude-cli invocation-recipe row"
o="$TMP/nr.out"; e="$TMP/nr.err"
rc=0
bash "$NR_TREE/bin/check-invocation-path.sh" --role pm-spec >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 1 ] || fail "cip-no-recipe: expected exit 1, got $rc"
[ ! -s "$o" ] || fail "cip-no-recipe: expected zero bytes on stdout"
grep -qF -- 'no-recipe' "$e" || fail "cip-no-recipe: expected the no-recipe token on stderr"
pass "cip-no-recipe — a registered adapter with no shipped recipe refuses no-recipe"

# =============================================================================
# cip-role-not-wired (AC13(i))
# =============================================================================
RW_TREE="$TMP/rolenotwired"
build_installed_tree "$RW_TREE"
RW_CONF="$RW_TREE/templates/binding-default.conf"
sed -E 's/^bind([[:space:]]+)pm-spec([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1pm-spec\2codex\3provider-configured\4-\5codex-cli/' \
  "$DEFAULT_CONF" > "$RW_CONF"
grep -qE '^bind[[:space:]]+pm-spec[[:space:]]+codex[[:space:]]' "$RW_CONF" || fail "cip-role-not-wired: rebind did not apply"
bash "$RW_TREE/bin/check-binding.sh" --config "$RW_CONF" >/dev/null 2>&1 \
  || fail "cip-role-not-wired: rebound conf failed to validate"
o="$TMP/rw.out"; e="$TMP/rw.err"
rc=0
bash "$RW_TREE/bin/check-invocation-path.sh" --role pm-spec >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 1 ] || fail "cip-role-not-wired: expected exit 1, got $rc"
[ ! -s "$o" ] || fail "cip-role-not-wired: expected zero bytes on stdout"
grep -qF -- 'role-not-wired' "$e" || fail "cip-role-not-wired: expected the role-not-wired token on stderr"
pass "cip-role-not-wired — pm-spec rebound to codex-cli, with no wires-role row for it, refuses role-not-wired"

# =============================================================================
# cip-authority-incompatible (AC13(ii))
# =============================================================================
AI_TREE="$TMP/authorityincompatible"
build_installed_tree "$AI_TREE"
AI_CONF="$AI_TREE/templates/binding-default.conf"
AI_RECIPE="$AI_TREE/templates/prompt-blocks/alternate-executor-invocation.md"
sed -E 's/^bind([[:space:]]+)engineer([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1engineer\2codex\3provider-configured\4-\5codex-cli/' \
  "$DEFAULT_CONF" > "$AI_CONF"
bash "$AI_TREE/bin/check-binding.sh" --config "$AI_CONF" >/dev/null 2>&1 \
  || fail "cip-authority-incompatible: rebound conf failed to validate"
printf '%s\n' 'wires-role codex-cli engineer' >> "$AI_RECIPE"
grep -qxF -- 'wires-role codex-cli engineer' "$AI_RECIPE" || fail "cip-authority-incompatible: appended wires-role row missing"
o="$TMP/ai.out"; e="$TMP/ai.err"
rc=0
bash "$AI_TREE/bin/check-invocation-path.sh" --role engineer >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 1 ] || fail "cip-authority-incompatible: expected exit 1, got $rc"
[ ! -s "$o" ] || fail "cip-authority-incompatible: expected zero bytes on stdout"
grep -qF -- 'authority-incompatible' "$e" || fail "cip-authority-incompatible: expected the authority-incompatible token on stderr"
pass "cip-authority-incompatible — engineer (writes) wired to codex-cli but not admitted refuses authority-incompatible"

# =============================================================================
# cip-unknown-adapter-upstream
# =============================================================================
UA_TREE="$TMP/unknownadapter"
build_installed_tree "$UA_TREE"
UA_CONF="$UA_TREE/templates/binding-default.conf"
sed -E 's/^bind([[:space:]]+)tech-lead([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1tech-lead\2claude\3sonnet\4-\5nonexistent-cli/' \
  "$DEFAULT_CONF" > "$UA_CONF"
grep -qE '^bind[[:space:]]+tech-lead[[:space:]]+claude[[:space:]]+sonnet[[:space:]]+-[[:space:]]+nonexistent-cli' "$UA_CONF" \
  || fail "cip-unknown-adapter-upstream: mutation did not apply"
o="$TMP/ua.out"; e="$TMP/ua.err"
rc=0
bash "$UA_TREE/bin/check-invocation-path.sh" --role tech-lead >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-unknown-adapter-upstream: expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-unknown-adapter-upstream: expected zero bytes on stdout"
n="$(grep -cF -- 'no-recipe' "$e" || true)"
[ "$n" = "0" ] || fail "cip-unknown-adapter-upstream: an unknown adapter must never reach the recipe lookup as no-recipe"
pass "cip-unknown-adapter-upstream — an unknown adapter token is refused upstream by resolution, never as no-recipe"

# =============================================================================
# cip-recipe-missing
# =============================================================================
RM_TREE="$TMP/recipemissing"
build_installed_tree "$RM_TREE"
rm -f "$RM_TREE/templates/prompt-blocks/alternate-executor-invocation.md"
o="$TMP/rm.out"; e="$TMP/rm.err"
rc=0
bash "$RM_TREE/bin/check-invocation-path.sh" --role tech-lead >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-recipe-missing: expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-recipe-missing: expected zero bytes on stdout"
pass "cip-recipe-missing — a deleted recipe refuses exit 2"

# --- shared scratch tree + helpers for the declaration-integrity family ----
DI_TREE="$TMP/di"
build_installed_tree "$DI_TREE"
DI_RECIPE="$DI_TREE/templates/prompt-blocks/alternate-executor-invocation.md"
cp "$DI_RECIPE" "$TMP/di.recipe.orig"
di_reset() { cp "$TMP/di.recipe.orig" "$DI_RECIPE"; }
di_base_ok() {  # $1 = role; asserts the pristine tree admits it (exit 0, non-empty stdout)
  di_reset
  local rc=0
  bash "$DI_TREE/bin/check-invocation-path.sh" --role "$1" > "$TMP/di.base.out" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ -s "$TMP/di.base.out" ] || return 1
  return 0
}
di_arm2() {  # $1 = role; $2 = required family substring on stderr
  local o="$TMP/di.arm.out" e="$TMP/di.arm.err" rc=0
  bash "$DI_TREE/bin/check-invocation-path.sh" --role "$1" > "$o" 2> "$e" || rc=$?
  [ "$rc" -eq 2 ] || return 1
  [ ! -s "$o" ] || return 1
  grep -qF -- "$2" "$e" || return 1
  return 0
}

# =============================================================================
# cip-recipe-malformed / cip-recipe-duplicated (invocation-recipe family)
# =============================================================================
di_base_ok tech-lead || fail "cip-recipe-malformed: pristine tree did not admit tech-lead"
printf '%s\n' 'invocation-recipe codex-cli' >> "$DI_RECIPE"
grep -qxF -- 'invocation-recipe codex-cli' "$DI_RECIPE" || fail "cip-recipe-malformed: mutation missing"
if di_arm2 tech-lead invocation-recipe; then
  pass "cip-recipe-malformed — a third-field-missing invocation-recipe row refuses exit 2, family named"
else
  fail "cip-recipe-malformed: expected exit 2 with invocation-recipe named on stderr"
fi

di_base_ok tech-lead || fail "cip-recipe-duplicated: pristine tree did not admit tech-lead"
printf '%s\n' 'invocation-recipe codex-cli in-process' >> "$DI_RECIPE"
n="$(grep -c '^invocation-recipe codex-cli ' "$DI_RECIPE" || true)"
[ "$n" = "2" ] || fail "cip-recipe-duplicated: mutation did not produce two codex-cli rows"
if di_arm2 tech-lead invocation-recipe; then
  pass "cip-recipe-duplicated — a duplicated conflicting invocation-recipe row refuses exit 2, family named"
else
  fail "cip-recipe-duplicated: expected exit 2 with invocation-recipe named on stderr"
fi

# =============================================================================
# cip-wires-malformed / cip-wires-duplicated (wires-role family)
# =============================================================================
di_base_ok tech-lead || fail "cip-wires-malformed: pristine tree did not admit tech-lead"
printf '%s\n' 'wires-role codex-cli zzz-not-a-role' >> "$DI_RECIPE"
grep -qxF -- 'wires-role codex-cli zzz-not-a-role' "$DI_RECIPE" || fail "cip-wires-malformed: mutation missing"
if di_arm2 tech-lead wires-role; then
  pass "cip-wires-malformed — an out-of-vocabulary role value refuses exit 2, family named"
else
  fail "cip-wires-malformed: expected exit 2 with wires-role named on stderr"
fi

di_base_ok tech-lead || fail "cip-wires-duplicated: pristine tree did not admit tech-lead"
printf '%s\n' 'wires-role codex-cli tech-lead' >> "$DI_RECIPE"
n="$(grep -cxF -- 'wires-role codex-cli tech-lead' "$DI_RECIPE" || true)"
[ "$n" = "2" ] || fail "cip-wires-duplicated: mutation did not duplicate the row"
if di_arm2 tech-lead wires-role; then
  pass "cip-wires-duplicated — a duplicated (adapter, role) wires-role pair refuses exit 2, family named"
else
  fail "cip-wires-duplicated: expected exit 2 with wires-role named on stderr"
fi

# =============================================================================
# cip-authority-malformed / cip-authority-duplicated / cip-authority-missing
# (admits-authority family)
# =============================================================================
di_base_ok tech-lead || fail "cip-authority-malformed: pristine tree did not admit tech-lead"
printf '%s\n' 'admits-authority codex-cli zzz-not-an-authority' >> "$DI_RECIPE"
grep -qxF -- 'admits-authority codex-cli zzz-not-an-authority' "$DI_RECIPE" || fail "cip-authority-malformed: mutation missing"
if di_arm2 tech-lead admits-authority; then
  pass "cip-authority-malformed — an out-of-vocabulary authority value refuses exit 2, family named"
else
  fail "cip-authority-malformed: expected exit 2 with admits-authority named on stderr"
fi

di_base_ok tech-lead || fail "cip-authority-duplicated: pristine tree did not admit tech-lead"
printf '%s\n' 'admits-authority codex-cli writes' >> "$DI_RECIPE"
n="$(grep -c '^admits-authority codex-cli ' "$DI_RECIPE" || true)"
[ "$n" = "2" ] || fail "cip-authority-duplicated: mutation did not produce two codex-cli rows"
if di_arm2 tech-lead admits-authority; then
  pass "cip-authority-duplicated — an admits-authority value ungrounded by any wired role's own authority refuses exit 2, family named"
else
  fail "cip-authority-duplicated: expected exit 2 with admits-authority named on stderr"
fi

# cip-authority-missing: the missing SET is adapter-scoped, so it is
# exercised with tech-lead REBOUND to codex-cli in a scratch conf, per
# AC13/AC14's own discipline.
di_reset
AM_CONF="$DI_TREE/templates/binding-default.conf"
cp "$DEFAULT_CONF" "$TMP/am.conf.orig"
sed -E 's/^bind([[:space:]]+)tech-lead([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1tech-lead\2codex\3provider-configured\4-\5codex-cli/' \
  "$DEFAULT_CONF" > "$AM_CONF"
grep -qE '^bind[[:space:]]+tech-lead[[:space:]]+codex[[:space:]]' "$AM_CONF" || fail "cip-authority-missing: rebind did not apply"
bash "$DI_TREE/bin/check-binding.sh" --config "$AM_CONF" >/dev/null 2>&1 \
  || fail "cip-authority-missing: rebound conf failed to validate"
bash "$DI_TREE/bin/check-invocation-path.sh" --role tech-lead >/dev/null 2>&1 \
  || fail "cip-authority-missing: expected the rebound tree to still admit tech-lead before the mutation"
grep -v '^admits-authority codex-cli ' "$DI_RECIPE" > "$TMP/am.recipe.tmp" && mv "$TMP/am.recipe.tmp" "$DI_RECIPE"
n="$(grep -c '^admits-authority codex-cli ' "$DI_RECIPE" || true)"
[ "$n" = "0" ] || fail "cip-authority-missing: mutation did not remove the admits-authority set"
o="$TMP/am.out"; e="$TMP/am.err"
rc=0
bash "$DI_TREE/bin/check-invocation-path.sh" --role tech-lead > "$o" 2> "$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-authority-missing: expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-authority-missing: expected zero bytes on stdout"
grep -qF -- 'admits-authority' "$e" || fail "cip-authority-missing: expected admits-authority named on stderr"
pass "cip-authority-missing — a resolved adapter with no admits-authority set at all refuses exit 2, family named"
cp "$TMP/am.conf.orig" "$AM_CONF"
di_reset

# =============================================================================
# cip-authority-token-not-leaked (AC13(iv))
# =============================================================================
di_base_ok tech-lead || fail "cip-authority-token-not-leaked: pristine tree did not admit tech-lead"
di_noai() {
  bash "$DI_TREE/bin/check-invocation-path.sh" --role tech-lead > "$TMP/di.noai.out" 2> "$TMP/di.noai.err" || true
  local n
  n="$(grep -cF -- 'authority-incompatible' "$TMP/di.noai.err" || true)"
  [ "$n" = "0" ]
}
grep -v '^admits-authority codex-cli ' "$DI_RECIPE" > "$TMP/na.tmp" && mv "$TMP/na.tmp" "$DI_RECIPE"
di_noai || fail "cip-authority-token-not-leaked: missing-set mutation leaked authority-incompatible"
di_reset
printf '%s\n' 'admits-authority codex-cli writes' >> "$DI_RECIPE"
di_noai || fail "cip-authority-token-not-leaked: duplicated mutation leaked authority-incompatible"
di_reset
printf '%s\n' 'admits-authority codex-cli zzz-not-an-authority' >> "$DI_RECIPE"
di_noai || fail "cip-authority-token-not-leaked: malformed mutation leaked authority-incompatible"
di_reset
pass "cip-authority-token-not-leaked — none of the three admits-authority integrity mutations print authority-incompatible"

# =============================================================================
# cip-bad-role
# =============================================================================
BR_TREE="$TMP/badrole"
build_installed_tree "$BR_TREE"
o="$TMP/br1.out"; e="$TMP/br1.err"
rc=0
bash "$BR_TREE/bin/check-invocation-path.sh" --role nope >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-bad-role: --role nope expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-bad-role: --role nope expected zero bytes on stdout"
o="$TMP/br2.out"; e="$TMP/br2.err"
rc=0
bash "$BR_TREE/bin/check-invocation-path.sh" --role '' >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-bad-role: --role '' expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-bad-role: --role '' expected zero bytes on stdout"
pass "cip-bad-role — an out-of-vocabulary or empty --role value refuses exit 2"

# =============================================================================
# cip-usage
# =============================================================================
US_TREE="$TMP/usage"
build_installed_tree "$US_TREE"
o="$TMP/us1.out"; e="$TMP/us1.err"
rc=0
bash "$US_TREE/bin/check-invocation-path.sh" tech-lead >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-usage: bare positional expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-usage: bare positional expected zero bytes on stdout"
o="$TMP/us2.out"; e="$TMP/us2.err"
rc=0
bash "$US_TREE/bin/check-invocation-path.sh" --bogus >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-usage: unknown flag expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-usage: unknown flag expected zero bytes on stdout"
o="$TMP/us3.out"; e="$TMP/us3.err"
rc=0
bash "$US_TREE/bin/check-invocation-path.sh" >"$o" 2>"$e" || rc=$?
[ "$rc" -eq 2 ] || fail "cip-usage: no mode expected exit 2, got $rc"
[ ! -s "$o" ] || fail "cip-usage: no mode expected zero bytes on stdout"
pass "cip-usage — a bare positional argument, an unknown flag, or no mode at all refuses exit 2"

# =============================================================================
# cip-stdout-empty-on-refusal (a cross-cutting re-assertion over every
# refusal class this suite already exercised)
# =============================================================================
for f in "$TMP"/*.out; do
  base="$(basename "$f")"
  case "$base" in
    def-*|di.base.out) continue ;;
  esac
  [ -s "$f" ] && case "$base" in
    br1.out|br2.out|us1.out|us2.out|us3.out|rm.out|nr.out|rw.out|ai.out|ua.out|am.out|di.arm.out|di.noai.out|wl.out|nw.out)
      fail "cip-stdout-empty-on-refusal: $base unexpectedly carries bytes on stdout" ;;
  esac
done
pass "cip-stdout-empty-on-refusal — every refusal captured above produced zero bytes on stdout"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-invocation-path suite: all assertions passed\n'
  exit 0
else
  printf 'check-invocation-path suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
