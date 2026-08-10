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
# occupancy-type discrimination at <base>/binding.conf (round-1 review
# Blocker 1): one case per member of the occupancy lattice, each with the
# outcome that member's own class demands. Absent and "present but broken"
# must never collapse onto the same silent-default outcome.
# =============================================================================
mkdir -p "$TMP/occ/.ops"

# absent (control: already covered by default-binding above, re-asserted
# here beside its siblings so the whole lattice reads as one table)
rm -f "$TMP/occ/.ops/binding.conf"
( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "occupancy-absent: expected exit 0 (plugin default), got $rc"
pass "occupancy-absent — nothing at the path resolves the plugin default"

# dangling symlink
ln -sfn "$TMP/occ/does-not-exist-target" "$TMP/occ/.ops/binding.conf"
( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "occupancy-dangling-symlink: expected exit 2, got $rc"
[ ! -s "$TMP/occ.out" ] || fail "occupancy-dangling-symlink: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/occ.err" || fail "occupancy-dangling-symlink: expected binding-unresolved"
pass "occupancy-dangling-symlink — a dangling symlink at the config path refuses rather than silently defaulting"
rm -f "$TMP/occ/.ops/binding.conf"

# directory
mkdir -p "$TMP/occ/.ops/binding.conf"
( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "occupancy-directory: expected exit 2, got $rc"
[ ! -s "$TMP/occ.out" ] || fail "occupancy-directory: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/occ.err" || fail "occupancy-directory: expected binding-unresolved"
pass "occupancy-directory — a directory at the config path refuses rather than silently defaulting"
rmdir "$TMP/occ/.ops/binding.conf"

# fifo (gracefully skipped when mkfifo is unavailable on this host, per the
# T-1056 precedent — tests/check-liveness/run.sh's cl-out-fifo-refused)
if command -v mkfifo >/dev/null 2>&1; then
  mkfifo -- "$TMP/occ/.ops/binding.conf"
  ( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
  [ "$rc" -eq 2 ] || fail "occupancy-fifo: expected exit 2, got $rc"
  [ ! -s "$TMP/occ.out" ] || fail "occupancy-fifo: expected zero stdout bytes"
  grep -qF -- 'binding-unresolved' "$TMP/occ.err" || fail "occupancy-fifo: expected binding-unresolved"
  [ -p "$TMP/occ/.ops/binding.conf" ] || fail "occupancy-fifo: the target is no longer a fifo"
  pass "occupancy-fifo — a fifo at the config path refuses rather than silently defaulting"
  rm -f "$TMP/occ/.ops/binding.conf"
else
  pass "occupancy-fifo (skipped: mkfifo unavailable on this host)"
fi

# unreadable regular file (the discriminating positive control: readability,
# not type, is what this case tests — must still refuse, exactly as before
# this round's fix)
printf 'schema 1\n' > "$TMP/occ/.ops/binding.conf"
chmod 000 "$TMP/occ/.ops/binding.conf"
( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
chmod 644 "$TMP/occ/.ops/binding.conf"
[ "$rc" -eq 2 ] || fail "occupancy-unreadable-regular-file: expected exit 2, got $rc"
[ ! -s "$TMP/occ.out" ] || fail "occupancy-unreadable-regular-file: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/occ.err" || fail "occupancy-unreadable-regular-file: expected binding-unresolved"
pass "occupancy-unreadable-regular-file — present but unreadable refuses (readability, not type, is what fails here)"
rm -f "$TMP/occ/.ops/binding.conf"

# live symlink resolving to a regular, valid config: `[ -f ]` follows
# symlinks by design, so this is deliberately treated the same as a regular
# file — a host authoring the config at a symlinked path is not broken.
a_valid_binding "$TMP/occ-target.conf"
ln -sfn "$TMP/occ-target.conf" "$TMP/occ/.ops/binding.conf"
( cd "$TMP/occ" && TEAM_RUN_BASE=.ops bash "$RESOLVER" --print-resolved >"$TMP/occ.out" 2>"$TMP/occ.err" ) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "occupancy-live-symlink-to-regular: expected exit 0, got $rc"
[ -s "$TMP/occ.out" ] || fail "occupancy-live-symlink-to-regular: expected non-empty stdout"
pass "occupancy-live-symlink-to-regular — a live symlink to a regular, valid config resolves exactly like a regular file (deliberate: [ -f ] follows symlinks)"
rm -f "$TMP/occ/.ops/binding.conf" "$TMP/occ-target.conf"

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

# =============================================================================
# channel-token CLOSED-VOCABULARY membership (round-1 review Blocker 2): an
# unrecognized board-transition channel value must refuse, never default to
# "carrying and safe" — the class the reviewer's one-character typo
# (`not-caried`) instance is drawn from. Several distinct malformed shapes
# exercise the same class, not just the reported reproduction.
# =============================================================================
channel_mutation() {  # $1 = the mutated channel value to install
  sed "s/^carries board-transition .*\$/carries board-transition $1/" "$TMP/claude-cli.auth.orig" > "$AUTH/templates/adapters/claude-cli.txt"
}
for variant in not-caried zzz-unknown-token Stdout board; do
  channel_mutation "$variant"
  cmp -s "$TMP/claude-cli.auth.orig" "$AUTH/templates/adapters/claude-cli.txt" && fail "channel-membership-$variant: fixture control failed — mutation had no effect"
  run_auth_role engineer && rc=0 || rc=$?
  [ "$rc" -eq 2 ] || { fail "channel-membership-$variant: expected exit 2 (binding-unresolved), got $rc"; continue; }
  [ ! -s "$TMP/auth.out" ] || fail "channel-membership-$variant: expected zero stdout bytes"
  grep -qF -- 'binding-unresolved' "$TMP/auth.err" || fail "channel-membership-$variant: expected binding-unresolved"
done
pass "channel-membership-unrecognized-value — an unrecognized board-transition channel value (a one-character typo, an unrelated token, a case variant, and the RETIRED 'board' token) is refused binding-unresolved in every case, never treated as carrying-and-safe"
cp "$TMP/claude-cli.auth.orig" "$AUTH/templates/adapters/claude-cli.txt"
run_auth_role engineer && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "channel-membership-positive-control: expected exit 0 once the mutation is reverted, got $rc"
pass "channel-membership-positive-control — reverting the mutation restores the baseline resolve (proves the refusals above measured the mutation, not a stuck fixture)"

# =============================================================================
# field-count validation on non-binding reads (round-1 review Major 3): the
# contract's role-board-authority rows and an adapter definition's own
# capability-effort / carries-board-transition / effort-value rows must be
# refused on an extra field, exactly the rigor AC8 already gives the
# BINDING's own canonical form.
# =============================================================================
FC="$TMP/fieldcount-tree"
build_installed_tree "$FC"
mkdir -p "$FC/r/.ops"
printf '%s\n' 'schema 1' \
  'bind tech-lead claude m1 - claude-cli' 'bind pm-spec claude m1 - claude-cli' \
  'bind engineer claude m1 high claude-cli' 'bind qa-verifier claude m1 - claude-cli' \
  'bind ui-designer claude m1 - claude-cli' 'bind codex-reviewer claude m1 - claude-cli' \
  > "$FC/r/.ops/binding.conf"
run_fc_role() { ( cd "$FC/r" && TEAM_RUN_BASE=.ops bash "$FC/bin/resolve-executor.sh" --role "$1" >"$TMP/fc.out" 2>"$TMP/fc.err" ); }

run_fc_role engineer && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "field-count-baseline: expected exit 0 (unmutated), got $rc"
pass "field-count-baseline — the unmutated fixture resolves before any field-count mutation is applied"

cp "$FC/templates/adapters/claude-cli.txt" "$TMP/claude-cli.fc.orig"
sed 's/^capability effort supported$/capability effort supported extra-token/' "$TMP/claude-cli.fc.orig" > "$FC/templates/adapters/claude-cli.txt"
cmp -s "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt" && fail "field-count-capability-effort: fixture control failed — mutation had no effect"
run_fc_role engineer && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "field-count-capability-effort: expected exit 2, got $rc"
[ ! -s "$TMP/fc.out" ] || fail "field-count-capability-effort: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/fc.err" || fail "field-count-capability-effort: expected binding-unresolved"
pass "field-count-capability-effort — an extra trailing field on the capability effort row is refused, not silently ignored"
cp "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt"

sed 's/^carries board-transition stdout$/carries board-transition stdout extra-token/' "$TMP/claude-cli.fc.orig" > "$FC/templates/adapters/claude-cli.txt"
cmp -s "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt" && fail "field-count-carries-board-transition: fixture control failed — mutation had no effect"
run_fc_role engineer && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "field-count-carries-board-transition: expected exit 2, got $rc"
[ ! -s "$TMP/fc.out" ] || fail "field-count-carries-board-transition: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/fc.err" || fail "field-count-carries-board-transition: expected binding-unresolved"
pass "field-count-carries-board-transition — an extra trailing field on the carries board-transition row is refused, not silently ignored"
cp "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt"

sed 's/^effort-value high$/effort-value high extra-token/' "$TMP/claude-cli.fc.orig" > "$FC/templates/adapters/claude-cli.txt"
cmp -s "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt" && fail "field-count-effort-value: fixture control failed — mutation had no effect"
run_fc_role engineer && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "field-count-effort-value: expected exit 1 (the malformed row no longer counts as declaring 'high'), got $rc"
[ ! -s "$TMP/fc.out" ] || fail "field-count-effort-value: expected zero stdout bytes"
grep -qF -- 'capability-unsupported' "$TMP/fc.err" || fail "field-count-effort-value: expected capability-unsupported"
pass "field-count-effort-value — an extra trailing field on an effort-value row disqualifies it from declaring that value, rather than being silently accepted"
cp "$TMP/claude-cli.fc.orig" "$FC/templates/adapters/claude-cli.txt"

STUB_CONTRACT_FC="$TMP/fc-stub-contract.txt"
printf '%s\n' \
  'schema 1' \
  'field task-id in required' \
  'channel argv' 'channel prompt' 'channel stdin' 'channel stdout' 'channel stderr' 'channel file' 'channel exit-status' 'channel not-carried' \
  'status-value ok success' 'status-value error failure' \
  'error-class executor-unavailable' 'error-class capability-unsupported' 'error-class invocation-failed' 'error-class contract-violation' \
  'effort-mechanism none' 'effort-mechanism cli-flag' \
  'role-board-authority tech-lead none' 'role-board-authority pm-spec writes' \
  'role-board-authority engineer writes extra-field-here' \
  'role-board-authority qa-verifier writes' 'role-board-authority codex-reviewer proposes' 'role-board-authority ui-designer none' \
  > "$STUB_CONTRACT_FC"
printf '#!/usr/bin/env bash\ncat %s\nexit 0\n' "$STUB_CONTRACT_FC" > "$FC/bin/check-adapter.sh"
chmod +x "$FC/bin/check-adapter.sh"
run_fc_role engineer && rc=0 || rc=$?
[ "$rc" -eq 2 ] || fail "field-count-role-board-authority: expected exit 2, got $rc"
[ ! -s "$TMP/fc.out" ] || fail "field-count-role-board-authority: expected zero stdout bytes"
grep -qF -- 'binding-unresolved' "$TMP/fc.err" || fail "field-count-role-board-authority: expected binding-unresolved"
pass "field-count-role-board-authority — an extra trailing field on a delegated role-board-authority row is refused, not silently ignored"

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
