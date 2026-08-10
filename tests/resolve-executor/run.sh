#!/usr/bin/env bash
# run.sh — fixture suite for bin/resolve-executor.sh (T-1057; issue #203;
# .shell-team/specs/T-1057-loop-integration.md).
#
# Its scratch root is built with `mktemp -d "${TMPDIR:-/tmp}/...XXXXXX"`
# ONLY — never a same-directory fallback arm (the two-arm idiom other
# suites use): this suite copies an installed tree (bin/ + templates/) out
# of the checkout to mutate a scratch copy, and a same-directory fallback
# would place that copy — and the ancestor symlinks a sibling suite builds
# for the same reason — inside this repository's own working tree, which
# sandboxed runs deny (T-1044's reserved arm for exactly this shape of
# suite).
#
# CI wiring this suite itself asserts (`.github/workflows/check-handoff.yml`):
# a shellcheck argument naming both this suite and bin/resolve-executor.sh,
# a step running `bash tests/resolve-executor/run.sh`, and a probe-free
# dogfood step (`--print-resolved`, never `--role`) against this repository.
#
# Covers: --help and the closed usage-refusal set (AC2 shape); the
# effective binding (host config first, plugin default second, decoy CWD
# templates/ ignored — AC4 shape); the fail-closed effort rule
# (capability-unsupported, AC6 shape); the fail-closed board-transition
# authority rule (contract-violation, AC7 shape); the delegated canonical
# form re-asserted by content rather than by its first token, via a stub
# sibling in a scratch-installed tree (binding-unresolved, AC8 shape); the
# compiled-in probe table's exhaustiveness and the fail-closed availability
# rule (executor-unavailable, AC9 shape); and that the resolver writes
# nothing, anywhere, statically and behaviorally (AC10 shape).

set -euo pipefail

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SUITE_DIR/../.." && pwd -P)"
RESOLVER="$REPO_ROOT/bin/resolve-executor.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/resolve-executor-test.XXXXXX")" || { echo "FAIL: could not create scratch root" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# build_installed_tree <dest> — a scratch copy of bin/ + templates/, the
# ONLY sanctioned way to exercise a mutated definition/registry/sibling:
# this resolver has no override flag of its own (DP9), and running the
# copied resolver additionally exercises the real $SCRIPT_DIR-relative
# resolution rather than a test-only path.
build_installed_tree() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$REPO_ROOT/bin" "$dest/bin"
  cp -R "$REPO_ROOT/templates" "$dest/templates"
  chmod +x "$dest/bin/resolve-executor.sh"
}

# a_valid_binding <path> — six roles, every effort "-", the shipped default's
# provider/adapter split.
a_valid_binding() {
  printf '%s\n' \
    'schema 1' \
    'bind tech-lead claude m1 - claude-cli' \
    'bind pm-spec claude m1 - claude-cli' \
    'bind engineer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' \
    'bind ui-designer claude m1 - claude-cli' \
    'bind codex-reviewer codex provider-configured - codex-cli' \
    > "$1"
}

# =============================================================================
# --help and the closed usage-refusal set (AC2 shape)
# =============================================================================
test -r "$RESOLVER" || fail "resolver missing: $RESOLVER"

out="$(bash "$RESOLVER" --help 2>/dev/null)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "help: expected exit 0, got $rc"
[ -n "$out" ] || fail "help: expected non-empty output"
printf '%s\n' "$out" | grep -qF -- '--role' || fail "help: expected --role to be named"
printf '%s\n' "$out" | grep -qF -- '--print-resolved' || fail "help: expected --print-resolved to be named"
pass "help — exits 0 and names both modes"

usage_case() {  # $1 = case name; remaining = args
  local name="$1"; shift
  local o e rc
  o="$TMP/u-$name.out"; e="$TMP/u-$name.err"
  bash "$RESOLVER" "$@" >"$o" 2>"$e" && rc=0 || rc=$?
  [ "$rc" -eq 2 ] || { fail "usage-$name: expected exit 2, got $rc"; return; }
  [ ! -s "$o" ] || { fail "usage-$name: expected zero bytes on stdout"; return; }
  grep -qF -- 'usage' "$e" || { fail "usage-$name: expected the usage token on stderr"; return; }
  pass "usage-$name — refused usage at exit 2 with zero stdout bytes"
}
usage_case no-args
usage_case both-modes --role engineer --print-resolved
usage_case unknown-role --role scrum-master
usage_case not-a-role --role not-a-role
usage_case role-no-value --role
usage_case unknown-flag --frobnicate
usage_case bare-positional engineer

bash "$RESOLVER" --role engineer >"$TMP/valid.out" 2>"$TMP/valid.err" || true
if grep -qF -- 'usage' "$TMP/valid.err"; then
  fail "usage-positive-control: a real --role invocation must not print the usage token"
else
  pass "usage-positive-control — a real --role <role> invocation reaches a non-usage outcome"
fi

# =============================================================================
# the effective binding (AC4 shape): host config first, plugin default
# second, and the default is never taken from the working directory.
# =============================================================================
mkdir -p "$TMP/noconf/.ops"
out="$(cd "$TMP/noconf" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "default-binding: expected exit 0 with no host config, got $rc"
printf '%s\n' "$out" | grep -qF -- 'codex-cli' || fail "default-binding: expected the shipped default's codex-cli token"
pass "default-binding — no host config resolves the plugin-shipped default"

mkdir -p "$TMP/hostconf/.ops"
printf '%s\n' 'schema 1' \
  'bind tech-lead claude m1 - claude-cli' 'bind pm-spec claude m1 - claude-cli' \
  'bind engineer claude m1 - claude-cli' 'bind qa-verifier claude m1 - claude-cli' \
  'bind ui-designer claude m1 - claude-cli' 'bind codex-reviewer claude m1 - claude-cli' \
  > "$TMP/hostconf/.ops/binding.conf"
bash "$REPO_ROOT/bin/check-binding.sh" --config "$TMP/hostconf/.ops/binding.conf" >/dev/null 2>&1 \
  || fail "host-config-wins: fixture control failed — the host config is not valid"
out="$(cd "$TMP/hostconf" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "host-config-wins: expected exit 0, got $rc"
if printf '%s\n' "$out" | grep -qF -- 'codex-cli'; then
  fail "host-config-wins: a host config binding every role to claude-cli must win over the default (no codex-cli expected)"
else
  pass "host-config-wins — a valid host-authored binding.conf wins over the plugin default"
fi

mkdir -p "$TMP/decoycwd/.ops" "$TMP/decoycwd/templates"
sed 's/codex-cli/claude-cli/g; s/ codex / claude /g' "$REPO_ROOT/templates/binding-default.conf" \
  > "$TMP/decoycwd/templates/binding-default.conf"
grep -qF -- 'claude-cli' "$TMP/decoycwd/templates/binding-default.conf" \
  || fail "decoy-cwd-ignored: fixture control failed — decoy template unreadable"
out="$(cd "$TMP/decoycwd" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "decoy-cwd-ignored: expected exit 0, got $rc"
printf '%s\n' "$out" | grep -qF -- 'codex-cli' \
  || fail "decoy-cwd-ignored: a decoy templates/binding-default.conf in the working directory must never substitute the plugin's own default"
pass "decoy-cwd-ignored — the plugin default resolves from the resolver's own installed directory, never the working directory"

# =============================================================================
# the fail-closed effort rule (AC6 shape), against a scratch-installed tree
# =============================================================================
EFF="$TMP/effort-tree"
build_installed_tree "$EFF"
mkdir -p "$EFF/r/.ops"
grep -qE '^capability[[:space:]]+effort[[:space:]]+supported$' "$EFF/templates/adapters/claude-cli.txt" \
  || fail "effort-rule: fixture control failed — claude-cli.txt does not declare capability effort supported at the base state"

effort_binding() {  # $1 = tech-lead's effort value
  printf '%s\n' 'schema 1' \
    "bind tech-lead claude m1 $1 claude-cli" \
    'bind pm-spec claude m1 - claude-cli' 'bind engineer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' 'bind ui-designer claude m1 - claude-cli' \
    'bind codex-reviewer codex provider-configured - codex-cli' \
    > "$EFF/r/.ops/binding.conf"
}
run_effort() { ( cd "$EFF/r" && TEAM_RUN_BASE=.ops bash "$EFF/bin/resolve-executor.sh" --print-resolved >"$TMP/eff.out" 2>"$TMP/eff.err" ); }

effort_binding high; run_effort && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "effort-rule-declared-value-resolves: expected exit 0, got $rc"
pass "effort-rule-declared-value-resolves — a value the bound adapter declares resolves"

effort_binding not-a-real-effort; run_effort && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "effort-rule-undeclared-value: expected exit 1, got $rc"
[ ! -s "$TMP/eff.out" ] || fail "effort-rule-undeclared-value: expected zero stdout bytes"
grep -qF -- 'capability-unsupported' "$TMP/eff.err" || fail "effort-rule-undeclared-value: expected capability-unsupported"
pass "effort-rule-undeclared-value — an effort value absent from the adapter's effort-value rows is refused capability-unsupported"

effort_binding -; run_effort && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "effort-rule-unset-resolves: expected exit 0, got $rc"
pass "effort-rule-unset-resolves — an unset ('-') effort always resolves"

cp "$EFF/templates/adapters/claude-cli.txt" "$TMP/claude-cli.orig"
sed 's/^capability effort supported$/capability effort unsupported/' "$TMP/claude-cli.orig" > "$EFF/templates/adapters/claude-cli.txt"
cmp -s "$TMP/claude-cli.orig" "$EFF/templates/adapters/claude-cli.txt" && fail "effort-rule-unsupported: fixture control failed — mutation had no effect"
effort_binding high; run_effort && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "effort-rule-unsupported: expected exit 1, got $rc"
[ ! -s "$TMP/eff.out" ] || fail "effort-rule-unsupported: expected zero stdout bytes"
grep -qF -- 'capability-unsupported' "$TMP/eff.err" || fail "effort-rule-unsupported: expected capability-unsupported"
pass "effort-rule-unsupported — capability effort unsupported refuses any non-'-' effort value"
cp "$TMP/claude-cli.orig" "$EFF/templates/adapters/claude-cli.txt"

# =============================================================================
# the fail-closed board-transition authority rule (AC7 shape)
# =============================================================================
AUTH="$TMP/authority-tree"
build_installed_tree "$AUTH"
mkdir -p "$AUTH/r/.ops"
# Every role bound to claude-cli (including codex-reviewer) — the mutation
# below targets claude-cli's own definition, so every role's adapter must
# actually BE claude-cli for the mutation to reach it.
printf '%s\n' 'schema 1' \
  'bind tech-lead claude m1 - claude-cli' 'bind pm-spec claude m1 - claude-cli' \
  'bind engineer claude m1 - claude-cli' 'bind qa-verifier claude m1 - claude-cli' \
  'bind ui-designer claude m1 - claude-cli' 'bind codex-reviewer claude m1 - claude-cli' \
  > "$AUTH/r/.ops/binding.conf"
run_auth_role() { ( cd "$AUTH/r" && TEAM_RUN_BASE=.ops bash "$AUTH/bin/resolve-executor.sh" --role "$1" >"$TMP/auth.out" 2>"$TMP/auth.err" ); }

for r in tech-lead engineer codex-reviewer; do
  run_auth_role "$r" && rc=0 || rc=$?
  [ "$rc" -eq 0 ] || fail "authority-rule-baseline-$r: expected exit 0, got $rc"
done
pass "authority-rule-baseline — engineer/codex-reviewer/tech-lead all resolve against the shipped (carrying) definitions"

cp "$AUTH/templates/adapters/claude-cli.txt" "$TMP/claude-cli.auth.orig"
sed 's/^carries board-transition .*$/carries board-transition not-carried/' "$TMP/claude-cli.auth.orig" > "$AUTH/templates/adapters/claude-cli.txt"
cmp -s "$TMP/claude-cli.auth.orig" "$AUTH/templates/adapters/claude-cli.txt" && fail "authority-rule: fixture control failed — mutation had no effect"

for r in engineer codex-reviewer; do
  run_auth_role "$r" && rc=0 || rc=$?
  [ "$rc" -eq 1 ] || { fail "authority-rule-not-carried-$r: expected exit 1, got $rc"; continue; }
  [ ! -s "$TMP/auth.out" ] || fail "authority-rule-not-carried-$r: expected zero stdout bytes"
  grep -qF -- 'contract-violation' "$TMP/auth.err" || fail "authority-rule-not-carried-$r: expected contract-violation"
done
pass "authority-rule-not-carried-writes-proposes — writes/proposes roles bound to a not-carried adapter are refused contract-violation"

run_auth_role tech-lead && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "authority-rule-none-role-unaffected: expected exit 0 (authority 'none'), got $rc"
pass "authority-rule-none-role-unaffected — a 'none'-authority role is unaffected by the same not-carried mutation (proves the rule keys on authority, not on the mutation's mere presence)"
cp "$TMP/claude-cli.auth.orig" "$AUTH/templates/adapters/claude-cli.txt"

# =============================================================================
# the delegated canonical form re-asserted by content (AC8 shape), via a
# stub check-binding.sh in a scratch-installed tree.
# =============================================================================
STUB="$TMP/stub-tree"
build_installed_tree "$STUB"
mkdir -p "$STUB/r/.ops"
a_valid_binding "$STUB/r/.ops/binding.conf"
printf '#!/usr/bin/env bash\ncat %s\nexit 0\n' "$TMP/canon.txt" > "$STUB/bin/check-binding.sh"
chmod +x "$STUB/bin/check-binding.sh"

good_canon() {
  printf '%s\n' 'schema 1' \
    'bound codex-reviewer codex stubmodel - codex-cli' \
    'bound engineer claude stubmodel - claude-cli' \
    'bound pm-spec claude stubmodel - claude-cli' \
    'bound qa-verifier claude stubmodel - claude-cli' \
    'bound tech-lead claude stubmodel - claude-cli' \
    'bound ui-designer claude stubmodel - claude-cli' \
    > "$TMP/canon.txt"
}
run_stub() { ( cd "$STUB/r" && TEAM_RUN_BASE=.ops bash "$STUB/bin/resolve-executor.sh" --print-resolved >"$TMP/stub.out" 2>"$TMP/stub.err" ); }

good_canon; run_stub && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "canon-reassert-good: expected exit 0, got $rc"
grep -qF -- 'stubmodel' "$TMP/stub.out" || fail "canon-reassert-good: expected the stub's distinctive model token in stdout (proves the stub sibling was actually reached)"
pass "canon-reassert-good — a well-formed stubbed canonical form resolves and its distinctive token reaches stdout"

canon_mutation() {
  good_canon
  case "$1" in
    nover)   sed -i.bak 's/^schema 1$/schema/' "$TMP/canon.txt" ;;
    badver)  sed -i.bak 's/^schema 1$/schema 999/' "$TMP/canon.txt" ;;
    extra)   sed -i.bak 's/^schema 1$/schema 1 extra/' "$TMP/canon.txt" ;;
    absent)  sed -i.bak '/^schema 1$/d' "$TMP/canon.txt" ;;
    five)    sed -i.bak '/^bound ui-designer /d' "$TMP/canon.txt" ;;
    dup)     printf '%s\n' 'bound engineer claude stubmodel - claude-cli' >> "$TMP/canon.txt" ;;
    fields)  sed -i.bak 's/^bound engineer claude stubmodel - claude-cli$/bound engineer claude stubmodel claude-cli/' "$TMP/canon.txt" ;;
    stray)   printf '%s\n' 'stray line here' >> "$TMP/canon.txt" ;;
  esac
  rm -f "$TMP/canon.txt.bak"
}
for case in nover badver extra absent five dup fields stray; do
  canon_mutation "$case"
  run_stub && rc=0 || rc=$?
  [ "$rc" -eq 2 ] || { fail "canon-reassert-$case: expected exit 2, got $rc"; continue; }
  [ ! -s "$TMP/stub.out" ] || { fail "canon-reassert-$case: expected zero stdout bytes"; continue; }
  [ -s "$TMP/stub.err" ] || { fail "canon-reassert-$case: expected a non-empty diagnostic on stderr"; continue; }
  grep -qF -- 'binding-unresolved' "$TMP/stub.err" || { fail "canon-reassert-$case: expected the binding-unresolved token"; continue; }
  pass "canon-reassert-$case — a delegated canonical form malformed in exactly one way ($case) is refused binding-unresolved at exit 2 with zero stdout bytes"
done

# =============================================================================
# the compiled-in probe table + fail-closed availability rule (AC9 shape)
# =============================================================================
PROB="$TMP/probe-tree"
build_installed_tree "$PROB"
mkdir -p "$PROB/r/.ops" "$TMP/empty-path"
a_valid_binding "$PROB/r/.ops/binding.conf"

prov_registry="$(grep -vE '^[[:space:]]*(#|$)' "$REPO_ROOT/templates/binding-adapters.txt" | awk '{print $2}' | LC_ALL=C sort -u)"
prov_table="$(grep -oE '^[[:space:]]*probe-provider[[:space:]]+[a-z][a-z0-9-]*' "$REPO_ROOT/bin/resolve-executor.sh" | awk '{print $2}' | LC_ALL=C sort -u)"
[ -n "$prov_registry" ] || fail "probe-table-exhaustive: fixture control failed — the provider registry is empty"
[ -n "$prov_table" ] || fail "probe-table-exhaustive: fixture control failed — the compiled-in probe table is empty"
if [ "$prov_registry" = "$prov_table" ]; then
  pass "probe-table-exhaustive — the compiled-in probe table's provider set equals the shipped allowlist's provider set, in both directions"
else
  fail "probe-table-exhaustive: provider set mismatch (registry: $prov_registry / table: $prov_table)"
fi

run_probe_role() { ( cd "$PROB/r" && PATH="$TMP/empty-path:/usr/bin:/bin" TEAM_RUN_BASE=.ops bash "$PROB/bin/resolve-executor.sh" --role "$1" >"$TMP/probe.out" 2>"$TMP/probe.err" ); }
run_probe_role engineer && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "probe-in-process-available: expected exit 0 with an empty PATH (in-process makes no PATH-dependent claim), got $rc"
grep -qF -- 'in-process' "$TMP/probe.out" || fail "probe-in-process-available: expected the in-process probe kind in stdout"
pass "probe-in-process-available — an in-process provider resolves regardless of PATH and names the probe kind it performed"

run_probe_role codex-reviewer && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "probe-out-of-process-unavailable: expected exit 1 with an empty PATH, got $rc"
[ ! -s "$TMP/probe.out" ] || fail "probe-out-of-process-unavailable: expected zero stdout bytes"
grep -qF -- 'executor-unavailable' "$TMP/probe.err" || fail "probe-out-of-process-unavailable: expected executor-unavailable"
pass "probe-out-of-process-unavailable — an out-of-process provider unobservable on PATH is refused executor-unavailable"

grep -v -E '^[[:space:]]*probe-provider[[:space:]]+claude([[:space:]]|$)' "$PROB/bin/resolve-executor.sh" > "$TMP/re-no-claude.sh"
cmp -s "$PROB/bin/resolve-executor.sh" "$TMP/re-no-claude.sh" && fail "probe-table-entry-removed: fixture control failed — removal had no effect"
cp "$TMP/re-no-claude.sh" "$PROB/bin/resolve-executor.sh"
run_probe_role engineer && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "probe-table-entry-removed: expected exit 1 once claude's table row is removed, got $rc"
[ ! -s "$TMP/probe.out" ] || fail "probe-table-entry-removed: expected zero stdout bytes"
grep -qF -- 'executor-unavailable' "$TMP/probe.err" || fail "probe-table-entry-removed: expected executor-unavailable"
pass "probe-table-entry-removed — a provider with no compiled-in table entry at all is executor-unavailable, never assumed available"

# =============================================================================
# writes nothing, anywhere (AC10 shape): static absence + behavioral
# inventory/hash invariance across both modes.
# =============================================================================
grep -q 'resolve-executor' "$RESOLVER" || fail "writes-nothing-static: positive control failed — the resolver text search matched nothing"
n="$(grep -cE '(^|[;&|(]|\$\()[[:space:]]*(tee|touch|mkdir|cp|mv|ln|install|rm|mktemp)([[:space:]]|$)' "$RESOLVER" || true)"
[ "$n" = "0" ] || fail "writes-nothing-static: found a write-shaped command in command position ($n)"
n="$(grep -E '>>?[[:space:]]*("?\$|/|\.|~)' "$RESOLVER" | grep -v '/dev/null' | grep -c . || true)"
[ "$n" = "0" ] || fail "writes-nothing-static: found a redirection into a path ($n)"
n="$(grep -cF -- '--out' "$RESOLVER" || true)"
[ "$n" = "0" ] || fail "writes-nothing-static: found an --out-shaped flag name"
pass "writes-nothing-static — no write-shaped command, no redirection into a path, no --out flag anywhere in the resolver"

WR="$TMP/write-tree"
build_installed_tree "$WR"
mkdir -p "$WR/r/.ops"
a_valid_binding "$WR/r/.ops/binding.conf"
inventory() { ( cd "$WR" && find . -print | LC_ALL=C sort ); }
hashes() {
  for rel in r/.ops/binding.conf templates/binding-default.conf templates/task-envelope.txt templates/adapters/claude-cli.txt templates/adapters/codex-cli.txt; do
    git hash-object "$WR/$rel"
  done
}
inventory > "$TMP/inv0"
hashes > "$TMP/h0"
[ -s "$TMP/inv0" ] || fail "writes-nothing-behavioral: fixture control failed — empty inventory"
grep -qF -- 'r/.ops/binding.conf' "$TMP/inv0" || fail "writes-nothing-behavioral: fixture control failed — config missing from inventory"
( cd "$WR/r" && TEAM_RUN_BASE=.ops bash "$WR/bin/resolve-executor.sh" --print-resolved >"$TMP/wr1.out" 2>"$TMP/wr1.err" )
( cd "$WR/r" && TEAM_RUN_BASE=.ops bash "$WR/bin/resolve-executor.sh" --role engineer >"$TMP/wr2.out" 2>"$TMP/wr2.err" )
if [ ! -s "$TMP/wr1.out" ] && [ ! -s "$TMP/wr1.err" ] && [ ! -s "$TMP/wr2.out" ] && [ ! -s "$TMP/wr2.err" ]; then
  fail "writes-nothing-behavioral: fixture control failed — neither invocation produced any output at all"
fi
inventory > "$TMP/inv1"
hashes > "$TMP/h1"
cmp -s "$TMP/inv0" "$TMP/inv1" || fail "writes-nothing-behavioral: the scratch tree's file inventory changed across two invocations"
cmp -s "$TMP/h0" "$TMP/h1" || fail "writes-nothing-behavioral: an observed input's content changed across two invocations"
pass "writes-nothing-behavioral — the scratch tree's file inventory and every observed input's hash are identical before and after both modes run"

# =============================================================================
# CI wiring this suite asserts (AC15 shape)
# =============================================================================
test -r "$WORKFLOW" || fail "ci-wiring: workflow file unreadable: $WORKFLOW"
test -s "$WORKFLOW" || fail "ci-wiring: workflow file empty: $WORKFLOW"
grep -q -- 'bin/resolve-executor.sh' "$WORKFLOW" || fail "ci-wiring: expected bin/resolve-executor.sh named in the workflow"
grep -q -- 'tests/resolve-executor/run.sh' "$WORKFLOW" || fail "ci-wiring: expected tests/resolve-executor/run.sh named in the workflow"
grep -q -- 'bash tests/resolve-executor/run.sh' "$WORKFLOW" || fail "ci-wiring: expected a step running this suite"
grep -qE 'bin/resolve-executor\.sh --print-resolved' "$WORKFLOW" || fail "ci-wiring: expected a probe-free dogfood step"
n="$(grep -cE 'bin/resolve-executor\.sh --role' "$WORKFLOW" || true)"
[ "$n" = "0" ] || fail "ci-wiring: CI must never exercise the probing --role path (runner carries neither executor CLI)"
pass "ci-wiring — .github/workflows/check-handoff.yml names both files, runs this suite, and dogfoods only the probe-free mode"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'resolve-executor suite: all assertions passed\n'
  exit 0
else
  printf 'resolve-executor suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
