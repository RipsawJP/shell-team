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

printf 'check-adapter suite: all cases passed\n'
