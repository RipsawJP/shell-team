#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-binding.sh (T-1054's fail-closed
# binding-config validator and its run-scoped integrity primitives).
# .shell-team/specs/T-1054-binding-config.md's own `- check:` lines exercise
# every acceptance criterion against this checker; this suite is a second,
# independently-authored surface (T-1054 AC12) covering the same refusal
# matrix plus the "Coverage the suite must carry beyond the criteria" items
# a `- check:` line cannot spell (no backticks in a `- check:` line, per
# this repository's own convention).
#
# Every case runs through assert_case (exit code AND token together — this
# repository's fixture-synthesis discipline: a wrong-but-nonzero result must
# not look like success, the same convention tests/check-refreeze-class/
# run.sh and tests/check-intent/run.sh already follow) or a dedicated block
# for shapes assert_case cannot express (byte-identity, zero-stdout,
# CANARY side effects, read-only proof).
#
# Case ids:
#   cb-help-sane              — --help: schema+bind present, four forbidden
#                                words absent, non-empty, exit 0
#   cb-ci-wiring               — .github/workflows/check-handoff.yml names
#                                both deliverables + the dogfood specimen
#                                (this line is what T-1054 AC12 requires this
#                                suite itself to assert)
#   cb-valid                   — the shipped valid fixture validates (positive
#                                control every mutation case below diffs against)
#   cb-missing-config          — absent config path -> missing-config (2)
#   cb-missing-schema          — no schema line -> missing-schema (1)
#   cb-duplicate-schema        — two schema lines -> duplicate-schema (1)
#   cb-schema-not-first        — schema line after every bind row -> schema-not-first (1)
#   cb-unsupported-schema      — schema version 99 -> unsupported-schema (1)
#   cb-unparseable-extra-line  — an unrecognized directive line -> unparseable-line (1)
#   cb-unparseable-fivefield   — a five-field bind row -> unparseable-line (1)
#   cb-bad-token               — a malformed model token -> bad-token (1)
#   cb-unknown-role            — a role outside the six -> unknown-role (1)
#   cb-duplicate-role          — a role bound twice -> duplicate-role (1)
#   cb-missing-role            — a role's row removed -> missing-role (1)
#   cb-unknown-adapter         — an unregistered adapter -> unknown-adapter (1)
#   cb-unknown-provider        — an unregistered provider -> unknown-provider (1)
#   cb-provider-adapter-mismatch — a known adapter paired with the wrong known provider
#   cb-registry-unreadable     — --adapters points at nothing -> registry-unreadable (2)
#   cb-registry-malformed-row  — a three-token registry row -> registry-malformed (2)
#   cb-registry-malformed-dup — a duplicated adapter token -> registry-malformed (2)
#   cb-decoy-registry-ignored — a decoy templates/binding-adapters.txt in the
#                                cwd never legitimizes an adapter
#   cb-no-eval-source-static   — no eval/source/`.` invocation anywhere in the script
#   cb-canary-dollar-paren     — a $(...) payload field is refused, no CANARY written
#   cb-canary-semicolon        — a ;...; payload field is refused, no CANARY written
#   cb-canary-backtick         — a backtick payload field is refused, no CANARY written
#                                (beyond-the-criteria coverage: no backticks
#                                allowed in a spec `- check:` line)
#   cb-directive-fallback/alternate/retry/default — each refused unparseable-line
#   cb-comma-provider          — a comma-joined provider field is refused
#   cb-canonical-determinism   — comments/blanks/order/whitespace/CRLF do not
#                                move --print-binding's output or its hash
#   cb-lock-shape              — --print-lock's structural shape
#   cb-verify-ok / cb-verify-comment-tolerant — --verify succeeds unchanged
#                                and after a comment-only edit
#   cb-verify-binding-changed  — an effort-field edit -> binding-changed (1)
#   cb-verify-path-mismatch    — a different --config path -> path-mismatch (1)
#   cb-verify-lock-structural-* — truncated / bad version / missing hash -> lock-structural (2)
#   cb-verify-lock-missing    — an absent --lock path -> lock-missing (2)
#   cb-verify-readonly        — the lock's own git hash-object is unchanged
#                                across every --verify invocation above
#   cb-print-binding-zero-on-fail / cb-print-lock-zero-on-fail — AC11: exactly
#                                zero stdout bytes on an invalid config
#   cb-tab-separated           — a tab-delimited config still validates
#   cb-no-trailing-newline     — a config with no trailing newline still validates
#   cb-all-comments            — an entirely-comment config -> missing-schema
#   cb-lock-fields-reordered  — config-path/binding-hash swapped in a
#                                hand-built lock -> --verify still succeeds
#   cb-lock-duplicate-hash    — a lock with two binding-hash lines -> lock-structural

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-binding.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-binding-fixtures.XXXXXX")"
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

# --- base valid fixture (six roles, schema 1) --------------------------------
mk_valid() {  # $1 = outfile
  printf '%s\n' \
    'schema 1' \
    'bind tech-lead claude m1 high claude-cli' \
    'bind pm-spec claude m1 - claude-cli' \
    'bind engineer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' \
    'bind ui-designer claude m1 - claude-cli' \
    'bind codex-reviewer codex m2 - codex-cli' \
    > "$1"
}

# =============================================================================
# --help sanity
# =============================================================================
h="$TMP/help.txt"
bash "$CHECKER" --help > "$h" 2>&1 || fail "cb-help-sane: --help did not exit 0"
[ -s "$h" ] || fail "cb-help-sane: --help produced no output"
grep -q 'schema' "$h" || fail "cb-help-sane: --help does not mention schema"
grep -q 'bind' "$h" || fail "cb-help-sane: --help does not mention bind"
n_forbidden="$(grep -cE 'fallback|alternate|retry|default' "$h" || true)"
[ "$n_forbidden" = "0" ] || fail "cb-help-sane: --help contains a forbidden word"
pass "cb-help-sane"

# =============================================================================
# CI wiring self-assertion (T-1054 AC12: this suite names the workflow file)
# =============================================================================
[ -r "$WORKFLOW" ] || fail "cb-ci-wiring: cannot read $WORKFLOW"
[ -s "$WORKFLOW" ] || fail "cb-ci-wiring: $WORKFLOW is empty"
grep -qF -- 'bin/check-binding.sh' "$WORKFLOW" || fail "cb-ci-wiring: check-handoff.yml does not name bin/check-binding.sh"
grep -qF -- 'tests/check-binding/run.sh' "$WORKFLOW" || fail "cb-ci-wiring: check-handoff.yml does not name tests/check-binding/run.sh"
grep -qF -- 'templates/binding-template.conf' "$WORKFLOW" || fail "cb-ci-wiring: check-handoff.yml does not dogfood templates/binding-template.conf"
pass "cb-ci-wiring"

# =============================================================================
# positive control
# =============================================================================
base="$TMP/base.conf"
mk_valid "$base"
assert_case cb-valid 0 'valid' --config "$base"

# =============================================================================
# grammar / schema refusals
# =============================================================================
assert_case cb-missing-config 2 'missing-config' --config "$TMP/does-not-exist"

c="$TMP/c1"; grep -v '^schema ' "$base" > "$c"
assert_case cb-missing-schema 1 'missing-schema' --config "$c"

c="$TMP/c2"; { printf '%s\n' 'schema 1'; cat "$base"; } > "$c"
assert_case cb-duplicate-schema 1 'duplicate-schema' --config "$c"

c="$TMP/c3"; { grep '^bind ' "$base"; printf '%s\n' 'schema 1'; } > "$c"
assert_case cb-schema-not-first 1 'schema-not-first' --config "$c"

c="$TMP/c4"; sed 's/^schema 1$/schema 99/' "$base" > "$c"
assert_case cb-unsupported-schema 1 'unsupported-schema' --config "$c"

c="$TMP/c5"; { cat "$base"; printf '%s\n' 'note tech-lead codex m2 - codex-cli'; } > "$c"
assert_case cb-unparseable-extra-line 1 'unparseable-line' --config "$c"

c="$TMP/c6"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude m1 claude-cli/' "$base" > "$c"
assert_case cb-unparseable-fivefield 1 'unparseable-line' --config "$c"

c="$TMP/c7"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude m1@!x - claude-cli/' "$base" > "$c"
assert_case cb-bad-token 1 'bad-token' --config "$c"

# =============================================================================
# role-set refusals (AC5)
# =============================================================================
for r in scrum-master triage-orchestrator drift-evaluator; do
  c="$TMP/role-$r"; sed "s/^bind ui-designer /bind $r /" "$base" > "$c"
  assert_case "cb-unknown-role-$r" 1 'unknown-role' --config "$c"
done

c="$TMP/dup-role"; { cat "$base"; printf '%s\n' 'bind pm-spec codex m2 - codex-cli'; } > "$c"
assert_case cb-duplicate-role 1 'duplicate-role' --config "$c"

c="$TMP/missing-role"; grep -v '^bind ui-designer ' "$base" > "$c"
assert_case cb-missing-role 1 'missing-role' --config "$c"

# =============================================================================
# adapter/provider registry refusals (AC6)
# =============================================================================
c="$TMP/unk-adapter"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude m1 - my-cli/' "$base" > "$c"
assert_case cb-unknown-adapter 1 'unknown-adapter' --config "$c"

c="$TMP/unk-provider"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec myprov m1 - claude-cli/' "$base" > "$c"
assert_case cb-unknown-provider 1 'unknown-provider' --config "$c"

c="$TMP/mismatch"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec codex m1 - claude-cli/' "$base" > "$c"
assert_case cb-provider-adapter-mismatch 1 'provider-adapter-mismatch' --config "$c"

assert_case cb-registry-unreadable 2 'registry-unreadable' --config "$base" --adapters "$TMP/nope"

r1="$TMP/r1.txt"; printf '%s\n' 'claude-cli claude extra' > "$r1"
assert_case cb-registry-malformed-row 2 'registry-malformed' --config "$base" --adapters "$r1"

r2="$TMP/r2.txt"; printf '%s\n' 'claude-cli claude' 'claude-cli codex' > "$r2"
assert_case cb-registry-malformed-dup 2 'registry-malformed' --config "$base" --adapters "$r2"

# decoy registry in the cwd must never be consulted
mkdir -p "$TMP/decoyroot/templates"
printf '%s\n' 'my-cli claude' > "$TMP/decoyroot/templates/binding-adapters.txt"
[ -r "$TMP/decoyroot/templates/binding-adapters.txt" ] || fail "cb-decoy-registry-ignored: decoy file was not written"
grep -q 'my-cli' "$TMP/decoyroot/templates/binding-adapters.txt" || fail "cb-decoy-registry-ignored: decoy file missing its own content"
sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude m1 - my-cli/' "$base" > "$TMP/decoyroot/decoy.conf"
set +e
out="$(cd "$TMP/decoyroot" && bash "$CHECKER" --config decoy.conf 2>&1)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "cb-decoy-registry-ignored: expected exit 1, got $rc — $out"
printf '%s\n' "$out" | grep -qF -- 'unknown-adapter' || fail "cb-decoy-registry-ignored: expected unknown-adapter, got: $out"
pass "cb-decoy-registry-ignored"

# =============================================================================
# never sourced/evaluated (AC7): static absence + behavioral CANARY proof
# =============================================================================
n_eval="$(grep -cE '(^|[;&|(])[[:space:]]*eval([[:space:]]|$)' "$CHECKER" || true)"
[ "$n_eval" = "0" ] || fail "cb-no-eval-source-static: found an 'eval' invocation in command position"
n_source="$(grep -cE '(^|[;&|(])[[:space:]]*(source|\.)[[:space:]]' "$CHECKER" || true)"
[ "$n_source" = "0" ] || fail "cb-no-eval-source-static: found a 'source'/'.' invocation in command position"
pass "cb-no-eval-source-static"

canary_case() {  # <id> <sed-replacement-target-value>
  local id="$1" payload="$2"
  local cfg="$TMP/canary-$id.conf" out rc
  sed "s/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude $payload - claude-cli/" "$base" > "$cfg"
  cmp -s "$base" "$cfg" && fail "$id: mutated fixture is byte-identical to the base fixture"
  set +e
  out="$(cd "$TMP" && bash "$CHECKER" --config "canary-$id.conf" 2>&1)"
  rc=$?
  set -e
  [ "$rc" -eq 1 ] || fail "$id: expected exit 1, got $rc — $out"
  printf '%s\n' "$out" | grep -qF -- 'bad-token' || fail "$id: expected bad-token, got: $out"
  [ ! -e "$TMP/CANARY" ] || fail "$id: a CANARY file was created — the config was evaluated"
  pass "$id"
}
# Single-quoted on purpose in every case below: these are literal
# shell-metacharacter payloads that must NOT be expanded by this test script
# itself before check-binding.sh ever sees them.
# shellcheck disable=SC2016
canary_case cb-canary-dollar-paren '$(>CANARY)'
# shellcheck disable=SC2016
canary_case cb-canary-semicolon    ';>CANARY;'
# shellcheck disable=SC2016
canary_case cb-canary-backtick     '`id`'

# =============================================================================
# no substitute/secondary chain is expressible (AC8)
# =============================================================================
for d in fallback alternate retry default; do
  c="$TMP/directive-$d"; { cat "$base"; printf '%s\n' "$d pm-spec codex m2 - codex-cli"; } > "$c"
  assert_case "cb-directive-$d" 1 'unparseable-line' --config "$c"
done

c="$TMP/comma-provider"; sed 's/^bind pm-spec claude m1 - claude-cli$/bind pm-spec claude,codex m1 - claude-cli/' "$base" > "$c"
set +e
out="$(bash "$CHECKER" --config "$c" 2>&1)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "cb-comma-provider: expected exit 1, got $rc — $out"
printf '%s\n' "$out" | grep -qE 'bad-token|unknown-provider|unparseable-line' || fail "cb-comma-provider: expected a closed-set token, got: $out"
pass "cb-comma-provider"

# =============================================================================
# canonical determinism (AC9)
# =============================================================================
alt="$TMP/alt.conf"
{
  printf '%s\n' '# a comment' '' 'schema 1' '' \
    'bind codex-reviewer   codex  m2 -   codex-cli' '# another' \
    'bind ui-designer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' \
    'bind engineer claude m1 - claude-cli' \
    'bind pm-spec claude m1 - claude-cli' \
    'bind tech-lead claude   m1 high claude-cli'
} | awk '{printf "%s\r\n", $0}' > "$alt"
[ -s "$alt" ] || fail "cb-canonical-determinism: alt fixture is empty"
cmp -s "$base" "$alt" && fail "cb-canonical-determinism: alt fixture is byte-identical to base"

p1="$TMP/p1.txt" p2="$TMP/p2.txt"
bash "$CHECKER" --config "$base" --print-binding > "$p1" || fail "cb-canonical-determinism: --print-binding failed on base"
bash "$CHECKER" --config "$alt" --print-binding > "$p2" || fail "cb-canonical-determinism: --print-binding failed on alt"
[ -s "$p1" ] && [ -s "$p2" ] || fail "cb-canonical-determinism: empty canonical output"
cmp -s "$p1" "$p2" || fail "cb-canonical-determinism: canonical output differs between base and alt"
[ "$(grep -c . "$p1" || true)" = "7" ] || fail "cb-canonical-determinism: expected exactly 7 lines"
[ "$(grep -c '^schema ' "$p1" || true)" = "1" ] || fail "cb-canonical-determinism: expected exactly one schema line"
[ "$(grep -c '^bound ' "$p1" || true)" = "6" ] || fail "cb-canonical-determinism: expected exactly six bound lines"
grep '^bound ' "$p1" > "$TMP/bound-only.txt"
LC_ALL=C sort -c -k2,2 "$TMP/bound-only.txt" || fail "cb-canonical-determinism: bound rows are not LC_ALL=C-sorted by role"
h="$(git hash-object --stdin < "$p1")"
printf '%s' "$h" | grep -qE '^[0-9a-f]{40}$' || fail "cb-canonical-determinism: not a 40-hex hash"
lock1="$TMP/lock1.txt"
bash "$CHECKER" --config "$base" --print-lock > "$lock1" || fail "cb-canonical-determinism: --print-lock failed"
grep -qxF -- "binding-hash $h" "$lock1" || fail "cb-canonical-determinism: lock hash does not equal git hash-object of --print-binding's own output"
pass "cb-canonical-determinism"

# =============================================================================
# lock shape (AC10 structural half)
# =============================================================================
head -n1 "$lock1" | grep -qxF 'binding-lock 1' || fail "cb-lock-shape: first line is not 'binding-lock 1'"
grep -qE '^config-path ' "$lock1" || fail "cb-lock-shape: no config-path line"
grep -qE '^binding-hash [0-9a-f]{40}$' "$lock1" || fail "cb-lock-shape: no well-formed binding-hash line"
tail -n1 "$lock1" | grep -qxF 'binding-lock-end' || fail "cb-lock-shape: last line is not 'binding-lock-end'"
pass "cb-lock-shape"

# =============================================================================
# verify: success, tolerance, refusals, read-only (AC10 behavioral half)
# =============================================================================
before_hash="$(git hash-object "$lock1")"

assert_case cb-verify-ok 0 'verified' --verify --lock "$lock1" --config "$base"

# Comment-only tolerance must be proved at the SAME path the lock recorded
# (path-mismatch would otherwise fire first and mask the very property this
# case exists to prove) — edit $base in place, verify, then restore it byte
# for byte before any later case that depends on its original content.
base_original="$TMP/base-original.bak"
cp "$base" "$base_original"
{ cat "$base"; printf '%s\n' '# a late comment'; } > "$TMP/base-commented.tmp"
mv "$TMP/base-commented.tmp" "$base"
assert_case cb-verify-comment-tolerant 0 'verified' --verify --lock "$lock1" --config "$base"
cp "$base_original" "$base"
cmp -s "$base" "$base_original" || fail "cb-verify-comment-tolerant: failed to restore \$base to its original content"

# binding-changed must likewise be proved at the SAME path (a different path
# would report path-mismatch instead, since that check runs first) — edit
# $base's bound value in place, verify, then restore.
sed 's/ high / low /' "$base_original" > "$TMP/base-changed.tmp"
cmp -s "$base_original" "$TMP/base-changed.tmp" && fail "cb-verify-binding-changed: mutated config is byte-identical to base"
mv "$TMP/base-changed.tmp" "$base"
assert_case cb-verify-binding-changed 1 'binding-changed' --verify --lock "$lock1" --config "$base"
cp "$base_original" "$base"
cmp -s "$base" "$base_original" || fail "cb-verify-binding-changed: failed to restore \$base to its original content"

other="$TMP/other.conf"
cp "$base" "$other"
assert_case cb-verify-path-mismatch 1 'path-mismatch' --verify --lock "$lock1" --config "$other"

l_trunc="$TMP/l-trunc.txt"; grep -v '^binding-lock-end$' "$lock1" > "$l_trunc"
assert_case cb-verify-lock-structural-truncated 2 'lock-structural' --verify --lock "$l_trunc" --config "$base"

l_ver="$TMP/l-ver.txt"; sed 's/^binding-lock 1$/binding-lock 9/' "$lock1" > "$l_ver"
assert_case cb-verify-lock-structural-version 2 'lock-structural' --verify --lock "$l_ver" --config "$base"

l_nohash="$TMP/l-nohash.txt"; grep -v '^binding-hash ' "$lock1" > "$l_nohash"
assert_case cb-verify-lock-structural-nohash 2 'lock-structural' --verify --lock "$l_nohash" --config "$base"

assert_case cb-verify-lock-missing 2 'lock-missing' --verify --lock "$TMP/no-such-lock" --config "$base"

after_hash="$(git hash-object "$lock1")"
[ "$before_hash" = "$after_hash" ] || fail "cb-verify-readonly: the lock's own blob hash changed across --verify invocations"
pass "cb-verify-readonly"

# =============================================================================
# AC11: zero stdout bytes on a refusal, for both integrity primitives
# =============================================================================
badrole="$TMP/badrole.conf"
sed 's/^bind ui-designer /bind scrum-master /' "$base" > "$badrole"
for m in --print-binding --print-lock; do
  ok="$TMP/ok-out.txt"
  bash "$CHECKER" --config "$base" "$m" > "$ok" || fail "cb-print-$m-zero-on-fail: valid-config emission failed"
  [ -s "$ok" ] || fail "cb-print-$m-zero-on-fail: valid config produced no stdout"
  no="$TMP/no-out.txt"
  set +e
  bash "$CHECKER" --config "$badrole" "$m" > "$no" 2>/dev/null
  rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "cb-print-$m-zero-on-fail: invalid config unexpectedly exited 0"
  [ ! -s "$no" ] || fail "cb-print-$m-zero-on-fail: invalid config wrote non-empty stdout for $m"
done
pass "cb-print-binding-zero-on-fail"
pass "cb-print-lock-zero-on-fail"

# =============================================================================
# coverage beyond the criteria (Notes for engineer)
# =============================================================================
tabcfg="$TMP/tab.conf"
{
  printf 'schema\t1\n'
  printf 'bind\ttech-lead\tclaude\tm1\thigh\tclaude-cli\n'
  printf 'bind\tpm-spec\tclaude\tm1\t-\tclaude-cli\n'
  printf 'bind\tengineer\tclaude\tm1\t-\tclaude-cli\n'
  printf 'bind\tqa-verifier\tclaude\tm1\t-\tclaude-cli\n'
  printf 'bind\tui-designer\tclaude\tm1\t-\tclaude-cli\n'
  printf 'bind\tcodex-reviewer\tcodex\tm2\t-\tcodex-cli\n'
} > "$tabcfg"
assert_case cb-tab-separated 0 'valid' --config "$tabcfg"

notrail="$TMP/notrail.conf"
{
  printf '%s\n' 'schema 1' \
    'bind tech-lead claude m1 high claude-cli' \
    'bind pm-spec claude m1 - claude-cli' \
    'bind engineer claude m1 - claude-cli' \
    'bind qa-verifier claude m1 - claude-cli' \
    'bind ui-designer claude m1 - claude-cli'
  printf 'bind codex-reviewer codex m2 - codex-cli'
} > "$notrail"
assert_case cb-no-trailing-newline 0 'valid' --config "$notrail"

allcomments="$TMP/allcomments.conf"
printf '%s\n' '# nothing but comments' '' '# and blanks' > "$allcomments"
assert_case cb-all-comments 1 'missing-schema' --config "$allcomments"

# a hand-built lock with config-path AFTER binding-hash must still verify —
# proves the two header fields are located by pattern, not by position.
reordered="$TMP/reordered-lock.txt"
canon="$TMP/canon-for-reorder.txt"
bash "$CHECKER" --config "$base" --print-binding > "$canon"
rhash="$(git hash-object --stdin < "$canon")"
{
  printf 'binding-lock 1\n'
  printf 'binding-hash %s\n' "$rhash"
  printf 'config-path %s\n' "$base"
  cat "$canon"
  printf 'binding-lock-end\n'
} > "$reordered"
assert_case cb-lock-fields-reordered 0 'verified' --verify --lock "$reordered" --config "$base"

dupehash="$TMP/dupehash-lock.txt"
{
  printf 'binding-lock 1\n'
  printf 'config-path %s\n' "$base"
  printf 'binding-hash %s\n' "$rhash"
  printf 'binding-hash %s\n' "$rhash"
  cat "$canon"
  printf 'binding-lock-end\n'
} > "$dupehash"
assert_case cb-lock-duplicate-hash 2 'lock-structural' --verify --lock "$dupehash" --config "$base"

printf 'check-binding suite: all cases passed\n'
