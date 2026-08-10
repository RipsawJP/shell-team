#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-adapter.sh (T-1055's fail-closed
# task-envelope contract + adapter-definition validator, and its
# `--print-contract`/`--adapter`/`--definitions`/`--contract`/`--binding`
# modes). .shell-team/specs/T-1055-adapter-envelope.md's own `- check:`
# lines exercise every acceptance criterion against this checker; this
# suite is a second, independently-authored surface (matching
# tests/check-binding/run.sh's own precedent) covering the same 21-token
# refusal matrix plus the "Coverage the suite must carry beyond the
# criteria" items a `- check:` line cannot spell (no backticks in a
# `- check:` line, per this repository's own convention).
#
# Every case runs through assert_case (exit code AND token together — this
# repository's fixture-synthesis discipline) or a dedicated block for
# shapes assert_case cannot express (zero-stdout-on-refusal, byte
# equality, a static source-text absence).
#
# Case ids:
#   ca-help-sane                    — --help: non-empty, mentions --binding,
#                                      exit 0
#   ca-ci-wiring                     — check-handoff.yml names both
#                                      deliverables (T-1054 AC12's own
#                                      precedent, applied to this suite)
#   ca-valid-default                 — the shipped contract + definitions
#                                      validate under the shipped checker
#   ca-valid-print-contract          — --print-contract: exit 0, non-empty,
#                                      schema line present
#   ca-valid-adapter-claude/codex     — --adapter <token> on each shipped
#                                      definition
#   ca-valid-binding                 — --binding against the shipped
#                                      specimen
#   ca-mkdef-positive-control         — the mkdef() generator itself
#                                      produces a valid definition before
#                                      any mutation of its output is judged
#   ca-contract-unreadable            — a missing --contract path
#   ca-contract-malformed-*           — an unrecognized directive, a bad
#                                      schema line, a duplicate schema line,
#                                      a bad field direction/requiredness, a
#                                      duplicated field name, an
#                                      out-of-vocabulary or duplicated
#                                      role-board-authority row
#   ca-contract-incomplete-*          — no field rows, no channel rows, a
#                                      missing inner-loop role's
#                                      role-board-authority row
#   ca-definitions-unreadable-*       — a missing or empty definitions dir
#   ca-definition-missing             — --adapter names a token with no
#                                      definition file
#   ca-unparseable-line               — an unrecognized definition directive
#   ca-unparseable-wrongcount-carries — a carries row with the wrong field
#                                      count
#   ca-bad-token-adapter              — a malformed adapter token
#   ca-missing-field                  — a required directive absent
#   ca-duplicate-field-adapter        — a single-valued directive declared
#                                      twice
#   ca-duplicate-field-carries        — a carries row declared twice for one
#                                      field
#   ca-adapter-name-mismatch          — declared adapter != basename
#   ca-unknown-adapter                — an adapter token outside the
#                                      allowlist
#   ca-provider-adapter-mismatch      — a provider not paired with that
#                                      adapter
#   ca-unsupported-envelope-schema    — a schema one version ahead of the
#                                      contract's
#   ca-unknown-envelope-field         — a carries row naming an
#                                      undeclared field
#   ca-unknown-channel                — a carries row naming an
#                                      undeclared channel
#   ca-field-coverage-gap             — a contract field with no carries
#                                      row
#   ca-capability-inconsistent-*      — the four inconsistency shapes
#                                      (supported/no-values,
#                                      supported/none-mechanism,
#                                      unsupported/has-values,
#                                      unsupported/wrong-mechanism)
#   ca-unknown-effort-mechanism       — a mechanism outside the contract's
#                                      vocabulary
#   ca-binding-effort-allunset/
#   ca-binding-effort-supported-value — --binding accepts `-` and a
#                                      declared value
#   ca-effort-unsupported-*           — a bound value outside the adapter's
#                                      set, and a bound value on an
#                                      unsupported-capability adapter
#   ca-binding-invalid-*              — three configs check-binding.sh
#                                      itself refuses (bad role, no schema,
#                                      wrong bind-row field count) —>
#                                      binding-invalid, exit 2, zero stdout
#   ca-usage-*                        — unknown flag, a flag missing its
#                                      value, mutually exclusive modes, and
#                                      --envelope itself
#   ca-no-eval-source-static          — no eval/source/`.` invocation
#                                      anywhere in the script
#   ca-no-sibling-flag-name           — bin/check-adapter.sh never spells
#                                      the sibling validator's
#                                      registry-override flag name (DP9)
#   ca-decoy-cwd-ignored              — a decoy templates/ in the invoking
#                                      cwd never changes --print-contract's
#                                      output
#   ca-path-symlink-invocation         — a bare name reached through a
#                                      PATH symlink still resolves the real
#                                      contract (launch-shape coverage,
#                                      class 4 of the fixture-synthesis
#                                      checklist)
#   ca-contract-scrambled-order/
#   ca-contract-crlf/
#   ca-contract-no-trailing-newline    — row order, CRLF and a missing
#                                      final newline don't matter for the
#                                      contract registry
#   ca-definition-crlf/
#   ca-definition-no-trailing-newline/
#   ca-definition-all-comments/
#   ca-definition-scrambled-order      — the same four, for a definition
#                                      file (all-comments -> missing-field,
#                                      the rest -> still valid)
#   ca-definitions-dir-unknown-file    — a definitions dir entry whose name
#                                      does not match any known adapter
#                                      token -> unknown-adapter

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-adapter.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-adapter-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_case <case-id> <want-exit-code> <want-token> -- <checker args...>
assert_case() {
  local id="$1" want_rc="$2" want_token="$3" out rc
  shift 3
  set +e
  out="$(bash "$CHECKER" "$@" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne "$want_rc" ]; then
    fail "$id: expected exit $want_rc, got $rc — output: $out"
  fi
  if ! printf '%s\n' "$out" | grep -qF -- "$want_token"; then
    fail "$id: expected token '$want_token' in output, got: $out"
  fi
  pass "$id"
}

# --- golden fixtures: copies of the real shipped contract + definitions ----
GOLD_CONTRACT="$TMP/contract.txt"
GOLD_DEFS="$TMP/defs"
cp "$REPO_ROOT/templates/task-envelope.txt" "$GOLD_CONTRACT"
mkdir -p "$GOLD_DEFS"
cp "$REPO_ROOT/templates/adapters/claude-cli.txt" "$GOLD_DEFS/claude-cli.txt"
cp "$REPO_ROOT/templates/adapters/codex-cli.txt" "$GOLD_DEFS/codex-cli.txt"

scratch_defs() {  # $1 = new scratch dir; copies GOLD_DEFS into it
  mkdir -p "$1"
  cp "$GOLD_DEFS/claude-cli.txt" "$1/claude-cli.txt"
  cp "$GOLD_DEFS/codex-cli.txt" "$1/codex-cli.txt"
}

without_field_row() { grep -v "^field $1 " "$GOLD_CONTRACT"; }
without_rba_row()   { grep -v "^role-board-authority $1 " "$GOLD_CONTRACT"; }

# mkdef <outfile> <adapter> <provider> <capability> <mechanism> <values...(space-separated, may be empty)>
# Builds a structurally complete, self-consistent definition: every
# contract-declared field gets a `carries <field> argv` row, so the only
# thing under test in a case using this generator is whatever the case's
# own arguments deliberately vary.
mkdef() {
  local out="$1" adapter="$2" provider="$3" cap="$4" mech="$5" values="$6" v
  {
    printf 'envelope-schema 1\n'
    printf 'adapter %s\n' "$adapter"
    printf 'provider %s\n' "$provider"
    printf 'adapter-version 1\n'
    printf 'capability effort %s\n' "$cap"
    printf 'effort-mechanism %s\n' "$mech"
    if [ -n "$values" ]; then
      for v in $values; do printf 'effort-value %s\n' "$v"; done
    fi
    grep '^field ' "$GOLD_CONTRACT" | awk '{print "carries " $2 " argv"}'
  } > "$out"
}

# =============================================================================
# --help sanity
# =============================================================================
h="$TMP/help.txt"
bash "$CHECKER" --help > "$h" 2>&1 || fail "ca-help-sane: --help did not exit 0"
[ -s "$h" ] || fail "ca-help-sane: --help produced no output"
grep -q -- '--binding' "$h" || fail "ca-help-sane: --help does not mention --binding"
n_envelope="$(grep -c -- '--envelope' "$h" || true)"
[ "$n_envelope" = "0" ] || fail "ca-help-sane: --help mentions --envelope"
pass "ca-help-sane"

# =============================================================================
# CI wiring self-assertion (matching T-1054 AC12's own precedent)
# =============================================================================
[ -r "$WORKFLOW" ] || fail "ca-ci-wiring: cannot read $WORKFLOW"
[ -s "$WORKFLOW" ] || fail "ca-ci-wiring: $WORKFLOW is empty"
grep -qF -- 'bin/check-adapter.sh' "$WORKFLOW" || fail "ca-ci-wiring: check-handoff.yml does not name bin/check-adapter.sh"
grep -qF -- 'tests/check-adapter/run.sh' "$WORKFLOW" || fail "ca-ci-wiring: check-handoff.yml does not name tests/check-adapter/run.sh"
pass "ca-ci-wiring"

# =============================================================================
# positive controls
# =============================================================================
assert_case ca-valid-default 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$GOLD_DEFS"

out="$(bash "$CHECKER" --contract "$GOLD_CONTRACT" --print-contract 2>&1)"
[ -n "$out" ] || fail "ca-valid-print-contract: no output"
printf '%s\n' "$out" | grep -qxF -- 'schema 1' || fail "ca-valid-print-contract: missing schema line"
pass "ca-valid-print-contract"

assert_case ca-valid-adapter-claude 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$GOLD_DEFS" --adapter claude-cli
assert_case ca-valid-adapter-codex 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$GOLD_DEFS" --adapter codex-cli
assert_case ca-valid-binding 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$GOLD_DEFS" --binding "$REPO_ROOT/templates/binding-template.conf"

d="$TMP/d-mkdefcheck"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude supported cli-flag high
cp "$GOLD_DEFS/codex-cli.txt" "$d/codex-cli.txt"
assert_case ca-mkdef-positive-control 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

# =============================================================================
# contract-level refusals (exit 2)
# =============================================================================
assert_case ca-contract-unreadable 2 'contract-unreadable' --contract "$TMP/does-not-exist.txt"

c="$TMP/cm1.txt"; { printf '%s\n' 'schema 1'; printf '%s\n' 'bogus-directive x y'; } > "$c"
assert_case ca-contract-malformed-unknown-directive 2 'contract-malformed' --contract "$c"

c="$TMP/cm2.txt"; printf '%s\n' 'schema' > "$c"
assert_case ca-contract-malformed-bad-schema-fieldcount 2 'contract-malformed' --contract "$c"

c="$TMP/cm3.txt"; { printf '%s\n' 'schema 1'; printf '%s\n' 'schema 1'; } > "$c"
assert_case ca-contract-malformed-dup-schema 2 'contract-malformed' --contract "$c"

c="$TMP/cm4.txt"; { without_field_row task-id; printf '%s\n' 'field task-id sideways required'; } > "$c"
assert_case ca-contract-malformed-bad-field-direction 2 'contract-malformed' --contract "$c"

c="$TMP/cm5.txt"; { without_field_row task-id; printf '%s\n' 'field task-id in sometimes'; } > "$c"
assert_case ca-contract-malformed-bad-field-requiredness 2 'contract-malformed' --contract "$c"

c="$TMP/cm6.txt"; { cat "$GOLD_CONTRACT"; printf '%s\n' 'field task-id in required'; } > "$c"
assert_case ca-contract-malformed-dup-field-name 2 'contract-malformed' --contract "$c"

c="$TMP/cm7.txt"; { without_rba_row ui-designer; printf '%s\n' 'role-board-authority scrum-master none'; } > "$c"
assert_case ca-contract-malformed-bad-role-board-role 2 'contract-malformed' --contract "$c"

c="$TMP/cm8.txt"; { without_rba_row ui-designer; printf '%s\n' 'role-board-authority ui-designer sometimes'; } > "$c"
assert_case ca-contract-malformed-bad-role-board-value 2 'contract-malformed' --contract "$c"

c="$TMP/cm9.txt"; { cat "$GOLD_CONTRACT"; printf '%s\n' 'role-board-authority ui-designer none'; } > "$c"
assert_case ca-contract-malformed-dup-role-board 2 'contract-malformed' --contract "$c"

c="$TMP/ci1.txt"; grep -v '^field ' "$GOLD_CONTRACT" > "$c"
assert_case ca-contract-incomplete-no-fields 2 'contract-incomplete' --contract "$c"

c="$TMP/ci2.txt"; grep -v '^channel ' "$GOLD_CONTRACT" > "$c"
assert_case ca-contract-incomplete-no-channels 2 'contract-incomplete' --contract "$c"

c="$TMP/ci3.txt"; without_rba_row ui-designer > "$c"
assert_case ca-contract-incomplete-missing-role 2 'contract-incomplete' --contract "$c"

# =============================================================================
# definitions-dir / definition-missing (exit 2)
# =============================================================================
assert_case ca-definitions-unreadable-missing-dir 2 'definitions-unreadable' --contract "$GOLD_CONTRACT" --definitions "$TMP/no-such-dir"

emptydir="$TMP/emptydefs"; mkdir -p "$emptydir"
assert_case ca-definitions-unreadable-empty-dir 2 'definitions-unreadable' --contract "$GOLD_CONTRACT" --definitions "$emptydir"

assert_case ca-definition-missing 2 'definition-missing' --contract "$GOLD_CONTRACT" --definitions "$GOLD_DEFS" --adapter not-a-real-adapter

d="$TMP/d-setcompleteness"; mkdir -p "$d"
cp "$GOLD_DEFS/claude-cli.txt" "$d/"
assert_case ca-set-completeness-definition-missing 2 'definition-missing' --contract "$GOLD_CONTRACT" --definitions "$d"

# =============================================================================
# adapter allowlist parity (DP15/R1): a scratch TREE, not just --contract/
# --definitions overrides — the allowlist has no override flag by design
# (DP9), so bin/ and templates/ are copied together so both this checker
# and (where used) check-binding.sh resolve the SAME $SCRIPT_DIR-relative
# allowlist, matching AC18's own method.
# =============================================================================
scratch_tree() {  # $1 = new scratch tree root; copies real bin/ + templates/
  mkdir -p "$1"
  cp -R "$REPO_ROOT/bin" "$1/bin"
  cp -R "$REPO_ROOT/templates" "$1/templates"
}

# The adapter allowlist has no override flag (DP9/DP15), so it ONLY ever
# resolves from a checker's OWN installed directory — invoking the real
# $CHECKER with --contract/--definitions overrides never touches it. Every
# case in this block therefore invokes the SCRATCH TREE's own copy of the
# script ("$st/bin/check-adapter.sh"), never $CHECKER, so its own
# $SCRIPT_DIR-relative resolution actually reaches the mutated file.
st="$TMP/tree-registry"; scratch_tree "$st"
STCHECKER="$st/bin/check-adapter.sh"
RA="$st/templates/binding-adapters.txt"
cp "$RA" "$TMP/reg.bak"

bash "$STCHECKER" >/dev/null 2>&1 \
  || fail "ca-registry-parity-positive-control: pristine scratch tree does not validate before any corruption"

assert_registry_case() {  # <id> <want-rc> <want-token>
  local id="$1" want_rc="$2" want_token="$3" out rc
  set +e
  out="$(bash "$STCHECKER" 2>&1)"
  rc=$?
  set -e
  [ "$rc" -eq "$want_rc" ] || fail "$id: expected exit $want_rc, got $rc — output: $out"
  printf '%s\n' "$out" | grep -qF -- "$want_token" || fail "$id: expected token '$want_token', got: $out"
  pass "$id"
}

rm -f "$RA"
assert_registry_case ca-registry-unreadable-missing 2 'registry-unreadable'
cp "$TMP/reg.bak" "$RA"

{ cat "$TMP/reg.bak"; printf '%s\n' 'claude-cli claude extra-junk'; } > "$RA"
cmp -s "$TMP/reg.bak" "$RA" && fail "ca-registry-malformed-extra-token: mutated registry is byte-identical to the pristine one"
assert_registry_case ca-registry-malformed-extra-token 2 'registry-malformed'
cp "$TMP/reg.bak" "$RA"

{ cat "$TMP/reg.bak"; printf '%s\n' 'ZZZCLI claude'; } > "$RA"
cmp -s "$TMP/reg.bak" "$RA" && fail "ca-registry-malformed-badtoken: mutated registry is byte-identical to the pristine one"
assert_registry_case ca-registry-malformed-badtoken 2 'registry-malformed'
cp "$TMP/reg.bak" "$RA"

{ cat "$TMP/reg.bak"; printf '%s\n' 'claude-cli codex'; } > "$RA"
cmp -s "$TMP/reg.bak" "$RA" && fail "ca-registry-malformed-duplicate: mutated registry is byte-identical to the pristine one"
assert_registry_case ca-registry-malformed-duplicate 2 'registry-malformed'
cp "$TMP/reg.bak" "$RA"

# positive control: the pristine scratch tree still validates 0 after every
# corruption above has been reverted — proves the reverts themselves applied
bash "$STCHECKER" >/dev/null 2>&1 \
  || fail "ca-registry-parity-positive-control: pristine scratch tree does not validate after reverts"
pass "ca-registry-parity-positive-control"

# =============================================================================
# definition grammar refusals (exit 1)
# =============================================================================
d="$TMP/d-unparseable"; scratch_defs "$d"
{ cat "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'bogus-directive x'; } > "$d/claude-cli.txt"
assert_case ca-unparseable-line 1 'unparseable-line' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-fivefield"; scratch_defs "$d"
{ grep -v '^carries task-id ' "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'carries task-id prompt extra'; } > "$d/claude-cli.txt"
assert_case ca-unparseable-wrongcount-carries 1 'unparseable-line' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-badtoken"; scratch_defs "$d"
sed 's/^adapter claude-cli$/adapter Claude_CLI!/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-bad-token-adapter 1 'bad-token' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-missingfield"; scratch_defs "$d"
grep -v '^provider ' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-missing-field 1 'missing-field' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-dupfield"; scratch_defs "$d"
{ cat "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'adapter claude-cli'; } > "$d/claude-cli.txt"
assert_case ca-duplicate-field-adapter 1 'duplicate-field' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-dupcarries"; scratch_defs "$d"
{ cat "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'carries task-id argv'; } > "$d/claude-cli.txt"
assert_case ca-duplicate-field-carries 1 'duplicate-field' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

# =============================================================================
# definition cross-check refusals (exit 1)
# =============================================================================
d="$TMP/d-namemismatch"; scratch_defs "$d"
sed 's/^adapter claude-cli$/adapter codex-cli/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-adapter-name-mismatch 1 'adapter-name-mismatch' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-unknownadapter"; mkdir -p "$d"
sed 's/^adapter claude-cli$/adapter my-cli/' "$GOLD_DEFS/claude-cli.txt" > "$d/my-cli.txt"
assert_case ca-unknown-adapter 1 'unknown-adapter' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter my-cli

d="$TMP/d-providermismatch"; scratch_defs "$d"
sed 's/^provider claude$/provider codex/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-provider-adapter-mismatch 1 'provider-adapter-mismatch' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-schemaahead"; scratch_defs "$d"
sed 's/^envelope-schema 1$/envelope-schema 2/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-unsupported-envelope-schema 1 'unsupported-envelope-schema' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-unknownfield"; scratch_defs "$d"
{ cat "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'carries zzz-not-a-field argv'; } > "$d/claude-cli.txt"
assert_case ca-unknown-envelope-field 1 'unknown-envelope-field' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-unknownchannel"; scratch_defs "$d"
{ grep -v '^carries task-id ' "$GOLD_DEFS/claude-cli.txt"; printf '%s\n' 'carries task-id zzz-not-a-channel'; } > "$d/claude-cli.txt"
assert_case ca-unknown-channel 1 'unknown-channel' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-coveragegap"; scratch_defs "$d"
grep -v '^carries task-id ' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-field-coverage-gap 1 'field-coverage-gap' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

# =============================================================================
# capability-inconsistent / unknown-effort-mechanism (exit 1)
# =============================================================================
d="$TMP/d-capinc1"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude supported cli-flag ""
assert_case ca-capability-inconsistent-supported-no-values 1 'capability-inconsistent' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-capinc2"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude supported none high
assert_case ca-capability-inconsistent-supported-none-mechanism 1 'capability-inconsistent' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-capinc3"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude unsupported none high
assert_case ca-capability-inconsistent-unsupported-with-values 1 'capability-inconsistent' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-capinc4"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude unsupported cli-flag ""
assert_case ca-capability-inconsistent-unsupported-wrong-mechanism 1 'capability-inconsistent' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-unknownmech"; mkdir -p "$d"
mkdef "$d/claude-cli.txt" claude-cli claude supported zzz-not-a-mechanism high
assert_case ca-unknown-effort-mechanism 1 'unknown-effort-mechanism' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

# =============================================================================
# widened field-coverage-gap (DP14/R5): a required field on not-carried
# =============================================================================
d="$TMP/d-notcarried-required"; scratch_defs "$d"
sed -E 's/^carries task-id .*/carries task-id not-carried/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
cmp -s "$GOLD_DEFS/claude-cli.txt" "$d/claude-cli.txt" && fail "ca-field-coverage-gap-required-not-carried: mutated definition is byte-identical to the shipped one"
assert_case ca-field-coverage-gap-required-not-carried 1 'field-coverage-gap' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

# =============================================================================
# status-value directive (DP14/R8): contract-incomplete + contract-malformed
# =============================================================================
c="$TMP/status-no-rows.txt"; grep -v '^status-value ' "$GOLD_CONTRACT" > "$c"
assert_case ca-contract-incomplete-no-status-values 2 'contract-incomplete' --contract "$c"

c="$TMP/status-no-success.txt"; sed 's/^status-value ok success$/status-value ok failure/' "$GOLD_CONTRACT" > "$c"
cmp -s "$GOLD_CONTRACT" "$c" && fail "ca-contract-incomplete-no-success: mutated contract is byte-identical to the shipped one"
assert_case ca-contract-incomplete-no-success 2 'contract-incomplete' --contract "$c"

c="$TMP/status-two-success.txt"; { cat "$GOLD_CONTRACT"; printf '%s\n' 'status-value zzzsecond success'; } > "$c"
assert_case ca-contract-incomplete-two-success 2 'contract-incomplete' --contract "$c"

c="$TMP/status-bad-kind.txt"; sed 's/^status-value ok success$/status-value ok sideways/' "$GOLD_CONTRACT" > "$c"
cmp -s "$GOLD_CONTRACT" "$c" && fail "ca-contract-malformed-bad-status-kind: mutated contract is byte-identical to the shipped one"
assert_case ca-contract-malformed-bad-status-kind 2 'contract-malformed' --contract "$c"

c="$TMP/schema-unsupported.txt"; sed 's/^schema 1$/schema 99/' "$GOLD_CONTRACT" > "$c"
cmp -s "$GOLD_CONTRACT" "$c" && fail "ca-contract-malformed-schema-unsupported: mutated contract is byte-identical to the shipped one"
assert_case ca-contract-malformed-schema-unsupported 2 'contract-malformed' --contract "$c"

# board channel retired (DP13): the shipped contract's own printed form
# never declares it — a static, non-mutated assertion
out_pc="$(bash "$CHECKER" --contract "$GOLD_CONTRACT" --print-contract 2>/dev/null)"
n_board="$(printf '%s\n' "$out_pc" | grep -c '^channel board$' || true)"
[ "$n_board" = "0" ] || fail "ca-board-channel-retired: the shipped contract still declares a 'board' channel"
pass "ca-board-channel-retired"

# =============================================================================
# --binding mode: effort fail-closed (AC6) and delegation refusal (AC7)
# =============================================================================
mk_binding_cfg() {  # $1 outfile ; $2 tech-lead-effort ; $3 codex-reviewer-effort
  printf '%s\n' \
    'schema 1' \
    "bind tech-lead claude m1 $2 claude-cli" \
    'bind pm-spec claude m1 - claude-cli' \
    'bind engineer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' \
    'bind ui-designer claude m1 - claude-cli' \
    "bind codex-reviewer codex m2 $3 codex-cli" \
    > "$1"
}

bd="$TMP/binding-defs"; mkdir -p "$bd"
mkdef "$bd/claude-cli.txt" claude-cli claude supported cli-flag high
mkdef "$bd/codex-cli.txt" codex-cli codex unsupported none ""

cfg1="$TMP/cfg-allunset.conf"; mk_binding_cfg "$cfg1" - -
assert_case ca-binding-effort-allunset 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$bd" --binding "$cfg1"

cfg2="$TMP/cfg-supported.conf"; mk_binding_cfg "$cfg2" high -
assert_case ca-binding-effort-supported-value 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$bd" --binding "$cfg2"

cfg3="$TMP/cfg-unsupportedvalue.conf"; mk_binding_cfg "$cfg3" xhigh -
assert_case ca-effort-unsupported-unknown-value 1 'effort-unsupported' --contract "$GOLD_CONTRACT" --definitions "$bd" --binding "$cfg3"

cfg4="$TMP/cfg-unsupportedcap.conf"; mk_binding_cfg "$cfg4" - high
assert_case ca-effort-unsupported-capability-unsupported 1 'effort-unsupported' --contract "$GOLD_CONTRACT" --definitions "$bd" --binding "$cfg4"

okcfg="$TMP/ok.conf"; mk_binding_cfg "$okcfg" - -

binding_invalid_case() {  # <id> <mutated-config-path>
  local id="$1" cfgpath="$2" out rc
  cmp -s "$okcfg" "$cfgpath" && fail "$id: mutated config is byte-identical to the valid one"
  set +e
  out="$(bash "$CHECKER" --contract "$GOLD_CONTRACT" --definitions "$bd" --binding "$cfgpath" 2>"$TMP/e-$id")"
  rc=$?
  set -e
  [ "$rc" -eq 2 ] || fail "$id: expected exit 2, got $rc"
  grep -q -- 'binding-invalid' "$TMP/e-$id" || fail "$id: expected binding-invalid, got: $(cat "$TMP/e-$id")"
  [ -z "$out" ] || fail "$id: expected zero stdout bytes, got: $out"
  pass "$id"
}

b1="$TMP/b1.conf"; sed 's/^bind ui-designer /bind scrum-master /' "$okcfg" > "$b1"
binding_invalid_case ca-binding-invalid-bad-role "$b1"

b2="$TMP/b2.conf"; grep -v '^schema ' "$okcfg" > "$b2"
binding_invalid_case ca-binding-invalid-no-schema "$b2"

b3="$TMP/b3.conf"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude m1 claude-cli/' "$okcfg" > "$b3"
binding_invalid_case ca-binding-invalid-wrong-fieldcount "$b3"

# =============================================================================
# authority-channel-conflict (DP13/R9): the one role/adapter join --binding
# alone can see — a writes/proposes role bound to an adapter that declares
# no board-transition return path
# =============================================================================
bd2="$TMP/binding-defs-conflict"; mkdir -p "$bd2"
mkdef "$bd2/claude-cli.txt" claude-cli claude supported cli-flag high
mkdef "$bd2/codex-cli.txt" codex-cli codex unsupported none ""
sed -E 's/^carries board-transition .*/carries board-transition not-carried/' "$bd2/codex-cli.txt" > "$TMP/codex-nc.txt"
cmp -s "$bd2/codex-cli.txt" "$TMP/codex-nc.txt" && fail "ca-authority-channel-conflict: mutated definition is byte-identical to the generated one"
mv "$TMP/codex-nc.txt" "$bd2/codex-cli.txt"
cfg5="$TMP/cfg-authority-conflict.conf"; mk_binding_cfg "$cfg5" - -
assert_case ca-authority-channel-conflict 1 'authority-channel-conflict' --contract "$GOLD_CONTRACT" --definitions "$bd2" --binding "$cfg5"

# a role whose authority is `none` (tech-lead/ui-designer) is NOT in
# conflict with the same not-carried declaration — positive control
# proving this is a role-authority join, not a blanket ban on the value.
# Only the two `none`-authority roles are bound to the mutated (not-carried)
# claude-cli; every writes/proposes role is bound to the unmutated codex-cli
# instead, so a conflict here would prove the join fires on VALUE alone.
bd3="$TMP/binding-defs-none-authority"; mkdir -p "$bd3"
mkdef "$bd3/claude-cli.txt" claude-cli claude supported cli-flag high
sed -E 's/^carries board-transition .*/carries board-transition not-carried/' "$bd3/claude-cli.txt" > "$TMP/claude-nc.txt"
mv "$TMP/claude-nc.txt" "$bd3/claude-cli.txt"
mkdef "$bd3/codex-cli.txt" codex-cli codex unsupported none ""
cfg6="$TMP/cfg-none-authority.conf"
printf '%s\n' \
  'schema 1' \
  'bind tech-lead claude m1 - claude-cli' \
  'bind ui-designer claude m1 - claude-cli' \
  'bind pm-spec codex m2 - codex-cli' \
  'bind engineer codex m2 - codex-cli' \
  'bind qa-verifier codex m2 - codex-cli' \
  'bind codex-reviewer codex m2 - codex-cli' \
  > "$cfg6"
assert_case ca-authority-channel-conflict-none-authority-ok 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$bd3" --binding "$cfg6"

# =============================================================================
# --binding delegated-shape re-assertion (R6): a stub sibling whose
# canonical output has the wrong SHAPE (too few bound rows, or a blank line
# in the middle) — a scratch TREE, since the re-assertion targets the
# script's own SCRIPT_DIR-relative sibling resolution
# (bash "$SCRIPT_DIR/check-binding.sh"), not the --definitions override
# =============================================================================
st2="$TMP/tree-stub"; scratch_tree "$st2"
bash "$st2/bin/check-adapter.sh" --binding "$okcfg" >/dev/null 2>&1 \
  || fail "ca-binding-invalid-truncated-shape: pristine scratch tree with the REAL sibling does not validate first"

printf '%s\n' '#!/usr/bin/env bash' \
  'printf "%s\n" "schema 1" "bound tech-lead claude m1 - claude-cli" "bound pm-spec claude m1 - claude-cli"' \
  'exit 0' > "$st2/bin/check-binding.sh"
chmod 755 "$st2/bin/check-binding.sh"
set +e
out="$(bash "$st2/bin/check-adapter.sh" --binding "$okcfg" 2>"$TMP/e-truncated")"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "ca-binding-invalid-truncated-shape: expected exit 2, got $rc"
grep -q -- 'binding-invalid' "$TMP/e-truncated" || fail "ca-binding-invalid-truncated-shape: expected binding-invalid, got: $(cat "$TMP/e-truncated")"
[ -z "$out" ] || fail "ca-binding-invalid-truncated-shape: expected zero stdout bytes, got: $out"
pass "ca-binding-invalid-truncated-shape"

printf '%s\n' '#!/usr/bin/env bash' \
  'printf "%s\n" "schema 1" "bound tech-lead claude m1 - claude-cli" "" "bound pm-spec claude m1 - claude-cli" "bound engineer claude m1 - claude-cli" "bound qa-verifier claude m1 - claude-cli" "bound ui-designer claude m1 - claude-cli" "bound codex-reviewer codex m2 - codex-cli"' \
  'exit 0' > "$st2/bin/check-binding.sh"
chmod 755 "$st2/bin/check-binding.sh"
set +e
out="$(bash "$st2/bin/check-adapter.sh" --binding "$okcfg" 2>"$TMP/e-blank")"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "ca-binding-invalid-blank-line: expected exit 2, got $rc"
grep -q -- 'binding-invalid' "$TMP/e-blank" || fail "ca-binding-invalid-blank-line: expected binding-invalid, got: $(cat "$TMP/e-blank")"
[ -z "$out" ] || fail "ca-binding-invalid-blank-line: expected zero stdout bytes, got: $out"
pass "ca-binding-invalid-blank-line"

# =============================================================================
# usage refusals (exit 2)
# =============================================================================
set +e
out="$(bash "$CHECKER" --nope 2>&1)"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "ca-usage-unknown-flag: expected exit 2, got $rc"
printf '%s\n' "$out" | grep -qF -- 'usage' || fail "ca-usage-unknown-flag: expected usage token"
pass "ca-usage-unknown-flag"

set +e
out="$(bash "$CHECKER" --contract 2>&1)"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "ca-usage-missing-value: expected exit 2, got $rc"
printf '%s\n' "$out" | grep -qF -- 'usage' || fail "ca-usage-missing-value: expected usage token"
pass "ca-usage-missing-value"

set +e
out="$(bash "$CHECKER" --contract "$GOLD_CONTRACT" --print-contract --adapter claude-cli 2>&1)"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "ca-usage-mutually-exclusive: expected exit 2, got $rc"
printf '%s\n' "$out" | grep -qF -- 'usage' || fail "ca-usage-mutually-exclusive: expected usage token"
pass "ca-usage-mutually-exclusive"

assert_case ca-usage-envelope-flag 2 'usage' --envelope somevalue

# =============================================================================
# static self-checks (never sourced/evaluated; DP9's own flag never spelled)
# =============================================================================
n_eval="$(grep -cE '(^|[;&|(])[[:space:]]*eval([[:space:]]|$)' "$CHECKER" || true)"
[ "$n_eval" = "0" ] || fail "ca-no-eval-source-static: found an eval invocation in command position"
n_source="$(grep -cE '(^|[;&|(])[[:space:]]*(source|\.)[[:space:]]' "$CHECKER" || true)"
[ "$n_source" = "0" ] || fail "ca-no-eval-source-static: found a source/. invocation in command position"
pass "ca-no-eval-source-static"

n_flagname="$(grep -c -- '--adapters' "$CHECKER" || true)"
[ "$n_flagname" = "0" ] || fail "ca-no-sibling-flag-name: bin/check-adapter.sh spells the sibling validator's registry-override flag name"
pass "ca-no-sibling-flag-name"

# =============================================================================
# decoy cwd + PATH-symlink launch shape
# =============================================================================
mkdir -p "$TMP/decoyroot/templates/adapters"
printf '%s\n' 'schema 1' 'field zzzdecoy in required' > "$TMP/decoyroot/templates/task-envelope.txt"
printf '%s\n' 'adapter zzzdecoy-cli' > "$TMP/decoyroot/templates/adapters/claude-cli.txt"
ref="$(bash "$CHECKER" --print-contract 2>/dev/null)"
out="$(cd "$TMP/decoyroot" && bash "$CHECKER" --print-contract 2>/dev/null)"
[ "$out" = "$ref" ] || fail "ca-decoy-cwd-ignored: decoy cwd changed the printed contract"
n_decoy="$(printf '%s\n' "$out" | grep -c 'zzzdecoy' || true)"
[ "$n_decoy" = "0" ] || fail "ca-decoy-cwd-ignored: decoy token leaked into output"
pass "ca-decoy-cwd-ignored"

shimdir="$TMP/shim"; mkdir -p "$shimdir"
ln -s "$CHECKER" "$shimdir/check-adapter.sh"
out2="$(cd "$TMP" && PATH="$shimdir:$PATH" check-adapter.sh --print-contract 2>/dev/null)"
[ "$out2" = "$ref" ] || fail "ca-path-symlink-invocation: bare-name PATH-symlink invocation did not resolve the real contract"
pass "ca-path-symlink-invocation"

# =============================================================================
# beyond-the-criteria coverage: CRLF, no trailing newline, all-comments,
# scrambled directive order (contract, then definition), and a definitions
# dir entry whose name is not a known adapter token
# =============================================================================
c="$TMP/scrambled.txt"
{
  grep '^role-board-authority ' "$GOLD_CONTRACT"
  grep '^effort-mechanism ' "$GOLD_CONTRACT"
  grep '^error-class ' "$GOLD_CONTRACT"
  grep '^status-value ' "$GOLD_CONTRACT"
  grep '^channel ' "$GOLD_CONTRACT"
  grep '^field ' "$GOLD_CONTRACT"
  grep '^schema ' "$GOLD_CONTRACT"
} > "$c"
assert_case ca-contract-scrambled-order 0 'valid' --contract "$c" --definitions "$GOLD_DEFS"

c="$TMP/crlf.txt"; sed 's/$/\r/' "$GOLD_CONTRACT" > "$c"
assert_case ca-contract-crlf 0 'valid' --contract "$c" --definitions "$GOLD_DEFS"

c="$TMP/no-trailing-nl.txt"; printf '%s' "$(cat "$GOLD_CONTRACT")" > "$c"
assert_case ca-contract-no-trailing-newline 0 'valid' --contract "$c" --definitions "$GOLD_DEFS"

d="$TMP/d-crlf"; scratch_defs "$d"
sed 's/$/\r/' "$GOLD_DEFS/claude-cli.txt" > "$d/claude-cli.txt"
assert_case ca-definition-crlf 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-no-trailing-nl"; scratch_defs "$d"
printf '%s' "$(cat "$GOLD_DEFS/claude-cli.txt")" > "$d/claude-cli.txt"
assert_case ca-definition-no-trailing-newline 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-allcomments"; scratch_defs "$d"
printf '%s\n' '# just a comment' '# another' > "$d/claude-cli.txt"
assert_case ca-definition-all-comments 1 'missing-field' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-scrambled"; scratch_defs "$d"
{
  grep '^capability ' "$GOLD_DEFS/claude-cli.txt"
  grep '^effort-value ' "$GOLD_DEFS/claude-cli.txt"
  grep '^effort-mechanism ' "$GOLD_DEFS/claude-cli.txt"
  grep '^carries ' "$GOLD_DEFS/claude-cli.txt"
  grep '^adapter-version ' "$GOLD_DEFS/claude-cli.txt"
  grep '^provider ' "$GOLD_DEFS/claude-cli.txt"
  grep '^adapter ' "$GOLD_DEFS/claude-cli.txt"
  grep '^envelope-schema ' "$GOLD_DEFS/claude-cli.txt"
} > "$d/claude-cli.txt"
assert_case ca-definition-scrambled-order 0 'valid' --contract "$GOLD_CONTRACT" --definitions "$d" --adapter claude-cli

d="$TMP/d-rogue"; scratch_defs "$d"
sed 's/^adapter claude-cli$/adapter not-a-known-adapter/' "$GOLD_DEFS/claude-cli.txt" > "$d/not-a-known-adapter.txt"
set +e
out="$(bash "$CHECKER" --contract "$GOLD_CONTRACT" --definitions "$d" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "ca-definitions-dir-unknown-file: expected exit 1, got $rc"
printf '%s\n' "$out" | grep -qF -- 'unknown-adapter' || fail "ca-definitions-dir-unknown-file: expected unknown-adapter, got: $out"
pass "ca-definitions-dir-unknown-file"

# =============================================================================
# --doc mode (R7/DP16): the two contract forms held in agreement BY THE
# CHECKER, at table level (canon region) and tuple level (per-field
# direction/requiredness), proved non-vacuous by mutation
# =============================================================================
DOC="$REPO_ROOT/docs/loop-engineering/task-envelope.md"
assert_case ca-doc-valid 0 'valid' --doc "$DOC"

assert_case ca-doc-unreadable 2 'doc-unreadable' --doc "$TMP/no-such-doc.md"

doc_mut() {  # <id> <mutated-doc-path>
  local id="$1" docpath="$2"
  cmp -s "$DOC" "$docpath" && fail "$id: mutated document is byte-identical to the shipped one"
  assert_case "$id" 1 'doc-drift' --doc "$docpath"
}

# GOLD_CONTRACT rows are "field <name> <dir> <req>" — $2 is the field name
ffreq=$(grep '^field ' "$GOLD_CONTRACT" | awk '$3=="in" && $4=="required"{print $2; exit}')
[ -n "$ffreq" ] || fail "ca-doc-drift-direction: could not find an in/required field in the registry"
m="$TMP/doc-direction.md"
awk -v f="$ffreq" '{ if ($0 ~ "^- \\*\\*" f "\\*\\*") sub(/ in,/, " out,"); print }' "$DOC" > "$m"
doc_mut ca-doc-drift-direction "$m"

m="$TMP/doc-requiredness.md"
awk -v f="$ffreq" '{ if ($0 ~ "^- \\*\\*" f "\\*\\*") sub(/, required /, ", conditional "); print }' "$DOC" > "$m"
doc_mut ca-doc-drift-requiredness "$m"

cfreq=$(grep '^field ' "$GOLD_CONTRACT" | awk '$4=="conditional"{print $2; exit}')
[ -n "$cfreq" ] || fail "ca-doc-drift-required-when: could not find a conditional field in the registry"
m="$TMP/doc-requiredwhen.md"
awk -v f="$cfreq" '{ if ($0 ~ "^- \\*\\*" f "\\*\\*") sub(/required when/, "applies whenever"); print }' "$DOC" > "$m"
doc_mut ca-doc-drift-required-when "$m"

m="$TMP/doc-canon-line-deleted.md"
bash "$CHECKER" --print-contract > "$TMP/canon-ref.txt" 2>/dev/null
canon_first_channel="$(grep -m1 '^channel ' "$TMP/canon-ref.txt" || true)"
[ -n "$canon_first_channel" ] || fail "ca-doc-drift-canon-line: no channel row in the live printed contract"
grep -vxF -- "$canon_first_channel" "$DOC" > "$m"
doc_mut ca-doc-drift-canon-line "$m"

printf 'check-adapter suite: all cases passed\n'
