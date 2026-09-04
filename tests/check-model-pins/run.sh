#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-model-pins.sh (T-1117; GitHub issue
# #235; .shell-team/specs/T-1117-pin-default-equality-lock.md).
#
# Its scratch root is built with `mktemp -d "${TMPDIR:-/tmp}/...XXXXXX"`
# ONLY — never a same-directory fallback arm — because several cases copy
# an installed tree (bin/ + templates/ + agents/) out of the checkout to
# mutate a scratch copy, and a same-directory fallback would place that
# copy inside this repository's own working tree, which sandboxed runs
# deny (the same restriction tests/resolve-executor/run.sh documents for
# an identical reason).
#
# CI wiring this suite itself asserts (`.github/workflows/check-handoff.yml`):
# a shellcheck argument naming this suite, bin/check-model-pins.sh AND
# bin/check-binding.sh; a step running `bash tests/check-model-pins/run.sh`;
# and a dogfood step running `bash bin/check-model-pins.sh` against this
# repository.
#
# Case ids (the mechanical form of "every condition of the exit-code table
# has a fixture", required verbatim by the spec's AC5): cmp-help,
# cmp-ci-wiring, cmp-baseline-green, cmp-pin-mutated, cmp-conf-mutated,
# cmp-pin-absent, cmp-agent-missing, cmp-pin-duplicated, cmp-pin-empty,
# cmp-population-empty, cmp-non-claude-excluded, cmp-delegation-refused,
# cmp-canonical-reasserted.

set -euo pipefail

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SUITE_DIR/../.." && pwd -P)"
CHECKER="$REPO_ROOT/bin/check-model-pins.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"
DEFAULT_CONF="$REPO_ROOT/templates/binding-default.conf"
AGENTS_DIR="$REPO_ROOT/agents"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-model-pins-test.XXXXXX")" || { echo "FAIL: could not create scratch root" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# build_installed_tree <dest> — a scratch copy of bin/ + templates/ +
# agents/, the sanctioned way to exercise a mutated sibling/registry: this
# checker has no override flag for check-binding.sh itself, and running the
# copied checker additionally exercises the real $SCRIPT_DIR-relative
# resolution rather than a test-only path.
build_installed_tree() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$REPO_ROOT/bin" "$dest/bin"
  cp -R "$REPO_ROOT/templates" "$dest/templates"
  mkdir -p "$dest/agents"
  cp "$REPO_ROOT"/agents/*.md "$dest/agents/"
  chmod +x "$dest/bin/check-model-pins.sh"
}

# scratch_conf_and_agents <dest> — a scratch copy of the shipped conf plus
# the shipped agents/ directory, reached through the two read-only
# affordances (--default / --agents-dir) rather than a full installed tree
# — this is the shape every single-row mutation case below uses.
scratch_conf_and_agents() {
  local dest="$1"
  mkdir -p "$dest/a"
  cp "$DEFAULT_CONF" "$dest/c.conf"
  cp "$AGENTS_DIR"/*.md "$dest/a/"
}

# first_claude_role — the role of the first `claude`-provider row in the
# shipped default, read live (never typed here).
first_claude_role() {
  grep -E '^bind[[:space:]]+[a-z-]+[[:space:]]+claude[[:space:]]' "$DEFAULT_CONF" | head -n 1 | awk '{print $2}'
}
# conf_token_for <role> — that role's model token in the shipped default.
conf_token_for() {
  awk -v r="$1" '$1=="bind" && $2==r{print $4}' "$DEFAULT_CONF" | head -n 1
}

# =============================================================================
# cmp-help — the --help header is the adopter surface and states usage, the
# population rule, the exit table, the empty-population guard, and the
# T-1057 AC5 / #235 / #236 relationships.
# =============================================================================
test -r "$CHECKER" || fail "cmp-help: checker missing: $CHECKER"

out="$(bash "$CHECKER" --help 2>/dev/null)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-help: expected exit 0, got $rc"
[ -n "$out" ] || fail "cmp-help: expected non-empty output"
n_nonblank="$(printf '%s\n' "$out" | grep -c . || true)"
[ "$n_nonblank" -ge 15 ] || fail "cmp-help: expected at least 15 non-blank lines, got $n_nonblank"
for lit in 'Usage:' '--default' '--agents-dir' '--print-binding' 'provider' 'claude' 'Exit codes:' 'empty population' 'T-1057' 'AC5' '#235' '#236'; do
  printf '%s\n' "$out" | grep -qF -- "$lit" || fail "cmp-help: expected literal missing from --help output: $lit"
done
pass "cmp-help — exits 0, >=15 non-blank lines, carries every required literal"

# =============================================================================
# cmp-ci-wiring — the workflow names both new paths beside bin/check-binding.sh
# on the single shellcheck line, runs this suite, and dogfoods the checker.
# =============================================================================
test -r "$WORKFLOW" || fail "cmp-ci-wiring: workflow file unreadable: $WORKFLOW"
test -s "$WORKFLOW" || fail "cmp-ci-wiring: workflow file empty: $WORKFLOW"
scline="$(grep -E '^[[:space:]]*run: shellcheck ' "$WORKFLOW" || true)"
[ -n "$scline" ] || fail "cmp-ci-wiring: no shellcheck argument line found"
printf '%s\n' "$scline" | grep -qF -- 'bin/check-binding.sh' || fail "cmp-ci-wiring: expected bin/check-binding.sh named on the shellcheck line (positive control)"
printf '%s\n' "$scline" | grep -qF -- 'bin/check-model-pins.sh' || fail "cmp-ci-wiring: expected bin/check-model-pins.sh named on the shellcheck line"
printf '%s\n' "$scline" | grep -qF -- 'tests/check-model-pins/run.sh' || fail "cmp-ci-wiring: expected tests/check-model-pins/run.sh named on the shellcheck line"
grep -qE '^[[:space:]]*run: bash tests/check-model-pins/run\.sh[[:space:]]*$' "$WORKFLOW" || fail "cmp-ci-wiring: expected a step running this suite"
grep -qE '^[[:space:]]*run: bash bin/check-model-pins\.sh([[:space:]].*)?$' "$WORKFLOW" || fail "cmp-ci-wiring: expected a dogfood step running the checker"
pass "cmp-ci-wiring — .github/workflows/check-handoff.yml names both new paths, runs this suite, and dogfoods the checker"

# =============================================================================
# cmp-baseline-green — the unmutated real shipped tree exits 0 with no args.
# =============================================================================
(cd "$REPO_ROOT" && bash "$CHECKER" >"$TMP/base.out" 2>"$TMP/base.err") && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-baseline-green: expected exit 0 against the real shipped tree, got $rc"
[ -s "$TMP/base.out" ] || fail "cmp-baseline-green: expected non-empty stdout"
pass "cmp-baseline-green — the real shipped tree resolves clean with no arguments"

ROLE="$(first_claude_role)"
[ -n "$ROLE" ] || fail "fixture control: could not read a claude-provider role from the shipped default"
TOKEN="$(conf_token_for "$ROLE")"
[ -n "$TOKEN" ] || fail "fixture control: could not read $ROLE's shipped conf token"
test -r "$AGENTS_DIR/$ROLE.md" || fail "fixture control: agents/$ROLE.md is not readable"

# =============================================================================
# cmp-pin-mutated — the pin-moved direction: the role's own frontmatter pin
# is rewritten to a value that is not its conf token; exit 1, message names
# the role, the mutated pin value, and the conf token.
# =============================================================================
PM="$TMP/pin-mutated"
scratch_conf_and_agents "$PM"
sed -E 's/^model:.*/model: zzz-not-the-pin/' "$PM/a/$ROLE.md" > "$PM/x" && mv "$PM/x" "$PM/a/$ROLE.md"
grep -qxF -- 'model: zzz-not-the-pin' "$PM/a/$ROLE.md" || fail "cmp-pin-mutated: fixture control failed — mutation did not apply"
bash "$CHECKER" --default "$PM/c.conf" --agents-dir "$PM/a" >"$PM/o" 2>"$PM/e" && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "cmp-pin-mutated: expected exit 1, got $rc"
cat "$PM/o" "$PM/e" > "$PM/m"
grep -qF -- "$ROLE" "$PM/m" || fail "cmp-pin-mutated: expected the role name in the message"
grep -qF -- 'zzz-not-the-pin' "$PM/m" || fail "cmp-pin-mutated: expected the mutated pin value in the message"
grep -qF -- "$TOKEN" "$PM/m" || fail "cmp-pin-mutated: expected the conf token in the message"
pass "cmp-pin-mutated — the pin-moved direction reddens at exit 1 and names the role, the mutated pin, and the conf token"

# =============================================================================
# cmp-conf-mutated — the conf-moved direction: the shipped conf's model
# token for the role is rewritten while the pins stay pristine; exit 1,
# message names the role.
# =============================================================================
CM_="$TMP/conf-mutated"
scratch_conf_and_agents "$CM_"
sed -E "s/^(bind[[:space:]]+${ROLE}[[:space:]]+claude[[:space:]]+)[^[:space:]]+/\1zzz-other-token/" "$CM_/c.conf" > "$CM_/c2.conf"
grep -qF -- 'zzz-other-token' "$CM_/c2.conf" || fail "cmp-conf-mutated: fixture control failed — mutation did not apply"
bash "$CHECKER" --default "$CM_/c2.conf" --agents-dir "$CM_/a" >"$CM_/o" 2>"$CM_/e" && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "cmp-conf-mutated: expected exit 1, got $rc"
cat "$CM_/o" "$CM_/e" > "$CM_/m"
grep -qF -- "$ROLE" "$CM_/m" || fail "cmp-conf-mutated: expected the role name in the message"
pass "cmp-conf-mutated — the conf-moved direction reddens at exit 1 and names the role (one comparison closes both directions)"

# =============================================================================
# cmp-pin-absent — zero `model:` lines in the agent file (the Branch A /
# #236 shape); exit 1, message names #236 — never a skip, never a 0.
# =============================================================================
PA="$TMP/pin-absent"
scratch_conf_and_agents "$PA"
grep -v '^model:' "$PA/a/$ROLE.md" > "$PA/x" && mv "$PA/x" "$PA/a/$ROLE.md"
[ "$(grep -c '^model:' "$PA/a/$ROLE.md" || true)" = "0" ] || fail "cmp-pin-absent: fixture control failed — the mutated file still carries a model: line"
bash "$CHECKER" --default "$PA/c.conf" --agents-dir "$PA/a" >"$PA/o" 2>"$PA/e" && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "cmp-pin-absent: expected exit 1, got $rc"
cat "$PA/o" "$PA/e" > "$PA/m"
grep -qF -- '#236' "$PA/m" || fail "cmp-pin-absent: expected #236 named in the message"
pass "cmp-pin-absent — zero model: lines is a violation (exit 1), not a skip, and names #236"

# =============================================================================
# cmp-agent-missing — the population row's agent file is removed; exit 2.
# =============================================================================
AM="$TMP/agent-missing"
scratch_conf_and_agents "$AM"
rm -f "$AM/a/$ROLE.md"
bash "$CHECKER" --default "$AM/c.conf" --agents-dir "$AM/a" >"$AM/o" 2>"$AM/e" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-agent-missing: expected exit 2, got $rc"
pass "cmp-agent-missing — a missing population agent file cannot be evaluated (exit 2)"

# =============================================================================
# cmp-pin-duplicated — two `model:` lines in the agent file; exit 2.
# =============================================================================
PD="$TMP/pin-duplicated"
scratch_conf_and_agents "$PD"
{ cat "$PD/a/$ROLE.md"; printf 'model: zzz-second-pin\n'; } > "$PD/x" && mv "$PD/x" "$PD/a/$ROLE.md"
[ "$(grep -c '^model:' "$PD/a/$ROLE.md" || true)" = "2" ] || fail "cmp-pin-duplicated: fixture control failed — expected exactly two model: lines"
bash "$CHECKER" --default "$PD/c.conf" --agents-dir "$PD/a" >"$PD/o" 2>"$PD/e" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-pin-duplicated: expected exit 2, got $rc"
pass "cmp-pin-duplicated — more than one model: line cannot be evaluated (exit 2)"

# =============================================================================
# cmp-pin-empty — a `model:` line present with an empty value; exit 2, and
# distinct from the absent case above (never folded into it).
# =============================================================================
PE="$TMP/pin-empty"
scratch_conf_and_agents "$PE"
sed -E 's/^model:.*/model:/' "$PE/a/$ROLE.md" > "$PE/x" && mv "$PE/x" "$PE/a/$ROLE.md"
grep -qxF -- 'model:' "$PE/a/$ROLE.md" || fail "cmp-pin-empty: fixture control failed — expected the bare 'model:' line"
bash "$CHECKER" --default "$PE/c.conf" --agents-dir "$PE/a" >"$PE/o" 2>"$PE/e" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-pin-empty: expected exit 2, got $rc"
pass "cmp-pin-empty — a model: line present with an empty value cannot be evaluated (exit 2), distinct from the absent case"

# =============================================================================
# cmp-population-empty — a conf binding all six inner-loop roles to
# codex/codex-cli validates under the shipped grammar, so the claude
# population is empty; exit 2, never 0. Positive control: the conf is
# asserted to validate under the delegated validator first.
# =============================================================================
POP="$TMP/population-empty"
mkdir -p "$POP/a"
cp "$AGENTS_DIR"/*.md "$POP/a/"
printf '%s\n' \
  'schema 1' \
  'bind tech-lead codex provider-configured - codex-cli' \
  'bind pm-spec codex provider-configured - codex-cli' \
  'bind engineer codex provider-configured - codex-cli' \
  'bind qa-verifier codex provider-configured - codex-cli' \
  'bind ui-designer codex provider-configured - codex-cli' \
  'bind codex-reviewer codex provider-configured - codex-cli' \
  > "$POP/c.conf"
bash "$REPO_ROOT/bin/check-binding.sh" --config "$POP/c.conf" >/dev/null 2>&1 \
  || fail "cmp-population-empty: fixture control failed — the all-codex conf does not validate under the shipped grammar"
n_claude="$(grep -cE '^bind[[:space:]]+[a-z-]+[[:space:]]+claude[[:space:]]' "$POP/c.conf" || true)"
[ "$n_claude" = "0" ] || fail "cmp-population-empty: fixture control failed — expected zero claude rows in the mutated conf"
bash "$CHECKER" --default "$POP/c.conf" --agents-dir "$POP/a" >"$POP/o" 2>"$POP/e" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-population-empty: expected exit 2 (never 0) for an empty claude population, got $rc"
pass "cmp-population-empty — a conf validating with zero claude rows is exit 2, never a vacuous 0 (the guard is reachable, not theoretical)"

# =============================================================================
# cmp-non-claude-excluded — selection is by provider, and no population
# size or role list is compiled in. (i) The real shipped tree exits 0 even
# though the non-claude row's own pin disagrees with its conf token. (ii)
# An agents/*.md file with a pin but no bind row is out of population too,
# proven by the same green run. (iii) A scratch conf with one further
# claude row rebound to codex still exits 0 (population one smaller).
# =============================================================================
NC_ROLE="$(awk '$1=="bind" && $3!="claude"{print $2}' "$DEFAULT_CONF" | head -n 1)"
[ -n "$NC_ROLE" ] || fail "cmp-non-claude-excluded: fixture control failed — no non-claude bind row found"
NC_TOKEN="$(awk -v r="$NC_ROLE" '$1=="bind" && $2==r{print $4}' "$DEFAULT_CONF" | head -n 1)"
[ -n "$NC_TOKEN" ] || fail "cmp-non-claude-excluded: fixture control failed — could not read $NC_ROLE's conf token"
test -r "$AGENTS_DIR/$NC_ROLE.md" || fail "cmp-non-claude-excluded: fixture control failed — agents/$NC_ROLE.md unreadable"
NC_PIN="$(sed -nE 's/^model:[[:space:]]*(.+)$/\1/p' "$AGENTS_DIR/$NC_ROLE.md" | head -n 1)"
[ -n "$NC_PIN" ] || fail "cmp-non-claude-excluded: fixture control failed — could not read $NC_ROLE's pin"
[ "$NC_PIN" != "$NC_TOKEN" ] || fail "cmp-non-claude-excluded: fixture control failed — expected the non-claude row's own pin to disagree with its conf token"
(cd "$REPO_ROOT" && bash "$CHECKER" >/dev/null 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-non-claude-excluded: expected exit 0 against the real tree despite the non-claude disagreement, got $rc"

BOUND_ROLES="$TMP/bound-roles.txt"
awk '$1=="bind"{print $2}' "$DEFAULT_CONF" | LC_ALL=C sort > "$BOUND_ROLES"
UNBOUND="$TMP/unbound-with-pin.txt"
: > "$UNBOUND"
for af in "$AGENTS_DIR"/*.md; do
  an="$(basename "$af" .md)"
  if ! grep -qxF -- "$an" "$BOUND_ROLES"; then
    if grep -qE '^model:' "$af"; then
      printf '%s\n' "$an" >> "$UNBOUND"
    fi
  fi
done
[ "$(grep -c . "$UNBOUND" || true)" -ge 1 ] || fail "cmp-non-claude-excluded: fixture control failed — expected at least one agents/*.md pin with no bind row at all"

REBIND="$TMP/rebind.conf"
sed -E "s/^bind([[:space:]]+)$ROLE([[:space:]]+)claude([[:space:]]+)[^[:space:]]+([[:space:]]+)-([[:space:]]+)claude-cli/bind\1$ROLE\2codex\3provider-configured\4-\5codex-cli/" "$DEFAULT_CONF" > "$REBIND"
n_before="$(grep -cE '^bind[[:space:]]+[a-z-]+[[:space:]]+claude[[:space:]]' "$DEFAULT_CONF" || true)"
n_after="$(grep -cE '^bind[[:space:]]+[a-z-]+[[:space:]]+claude[[:space:]]' "$REBIND" || true)"
[ "$n_after" = "$((n_before - 1))" ] || fail "cmp-non-claude-excluded: fixture control failed — expected the rebound conf to carry one fewer claude row"
bash "$REPO_ROOT/bin/check-binding.sh" --config "$REBIND" >/dev/null 2>&1 \
  || fail "cmp-non-claude-excluded: fixture control failed — the rebound conf does not validate"
REB="$TMP/rebind-agents"
mkdir -p "$REB"
cp "$AGENTS_DIR"/*.md "$REB/"
bash "$CHECKER" --default "$REBIND" --agents-dir "$REB" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-non-claude-excluded: expected exit 0 with a smaller-than-shipped claude population, got $rc"
pass "cmp-non-claude-excluded — selection is by provider: the non-claude row's own disagreement, an unbound agent pin, and a smaller-than-shipped population are all out of scope for the invariant"

# =============================================================================
# cmp-delegation-refused — a --default naming a path that does not exist,
# and a conf whose schema line the delegated validator refuses; both exit 2.
# =============================================================================
DR="$TMP/delegation-refused"
mkdir -p "$DR/a"
cp "$AGENTS_DIR"/*.md "$DR/a/"
bash "$CHECKER" --default "$DR/nope.conf" --agents-dir "$DR/a" >"$DR/o1" 2>"$DR/e1" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-delegation-refused: expected exit 2 for a nonexistent --default path, got $rc"
sed -E 's/^schema 1$/schema 9/' "$DEFAULT_CONF" > "$DR/c3.conf"
grep -qxF -- 'schema 9' "$DR/c3.conf" || fail "cmp-delegation-refused: fixture control failed — mutation did not apply"
bash "$CHECKER" --default "$DR/c3.conf" --agents-dir "$DR/a" >"$DR/o2" 2>"$DR/e2" && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-delegation-refused: expected exit 2 for an unsupported schema version, got $rc"
pass "cmp-delegation-refused — a nonexistent --default path and a delegated schema refusal both exit 2"

# =============================================================================
# cmp-canonical-reasserted — the delegated canonical form is re-asserted by
# content before it is trusted, via a stubbed check-binding.sh in a scratch
# installed tree. Row count and role membership are deliberately NOT
# re-asserted (DP-3) — only shape: schema-line field count/version, each
# bound row's field count, and role uniqueness.
# =============================================================================
STUB="$TMP/stub-tree"
build_installed_tree "$STUB"
STUB_CM="$STUB/bin/check-model-pins.sh"
(cd "$STUB" && bash "$STUB_CM" >/dev/null 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-canonical-reasserted: fixture control failed — the unmutated installed-tree copy did not resolve clean (got $rc)"

cp "$STUB/bin/check-binding.sh" "$TMP/cb.orig"

printf '%s\n' '#!/usr/bin/env bash' 'printf "not-a-schema 1\n"' 'printf "bound aa claude m1 - claude-cli\n"' 'exit 0' > "$STUB/bin/check-binding.sh"
(cd "$STUB" && bash "$STUB_CM" >"$TMP/s1.out" 2>"$TMP/s1.err") && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-canonical-reasserted: expected exit 2 for a non-schema first line, got $rc"

printf '%s\n' '#!/usr/bin/env bash' 'printf "schema 1\n"' 'printf "bound aa claude m1\n"' 'exit 0' > "$STUB/bin/check-binding.sh"
(cd "$STUB" && bash "$STUB_CM" >"$TMP/s2.out" 2>"$TMP/s2.err") && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-canonical-reasserted: expected exit 2 for a bound row with the wrong field count, got $rc"

printf '%s\n' '#!/usr/bin/env bash' 'printf "schema 1\n"' 'printf "bound aa claude m1 - claude-cli\n"' 'printf "bound aa claude m1 - claude-cli\n"' 'exit 0' > "$STUB/bin/check-binding.sh"
(cd "$STUB" && bash "$STUB_CM" >"$TMP/s3.out" 2>"$TMP/s3.err") && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-canonical-reasserted: expected exit 2 for a role bound on two rows, got $rc"

printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$STUB/bin/check-binding.sh"
(cd "$STUB" && bash "$STUB_CM" >"$TMP/s4.out" 2>"$TMP/s4.err") && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "cmp-canonical-reasserted: expected exit 2 for no output at all beside a non-zero exit, got $rc"

cp "$TMP/cb.orig" "$STUB/bin/check-binding.sh"
(cd "$STUB" && bash "$STUB_CM" >/dev/null 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "cmp-canonical-reasserted: expected exit 0 once the real sibling is restored (positive control), got $rc"
pass "cmp-canonical-reasserted — a delegated canonical form broken in any of four ways (non-schema first line, wrong field count, duplicated role, no output) is exit 2; restoring the real sibling returns exit 0"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-model-pins suite: all assertions passed\n'
  exit 0
else
  printf 'check-model-pins suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
