#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-review-provider.sh (T-1177; issue #700).
#
# Self-contained relative to its own location: it reads only the bin/ and
# templates/ directories beside tests/, so a copy of those three trees can run
# beside a stubbed checker (the CI lock of the checker's table). Scratch is
# `mktemp -d "${TMPDIR:-/tmp}/..."` only; nothing is ever deleted recursively.

# shellcheck disable=SC2015  # pass/fail reporters never fail, so A && pass || fail acts as if-else
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/../.." && pwd -P)"
K="$ROOT/bin/check-review-provider.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

[ -s "$K" ] || { printf 'FAIL: checker missing: %s\n' "$K"; exit 1; }
T="$(mktemp -d "${TMPDIR:-/tmp}/check-review-provider-test.XXXXXX")" || { echo "FAIL: no scratch root"; exit 1; }
T="$(cd "$T" && pwd -P)"
export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset TEAM_RUN_BASE CODEX_THREAD_ID
mkdir -p "$HOME" "$T/stub"

# A stub codex first on PATH: any invocation leaves a marker.
printf '#!/usr/bin/env bash\n: > "%s/codex-called"\nexit 0\n' "$T" > "$T/stub/codex"
chmod +x "$T/stub/codex"
export PATH="$T/stub:$PATH"

Z=zqsntl7q   # sentinel planted in a model field and in a comment
rows() {
  printf '# %s\nschema 1\nbind tech-lead claude opus - claude-cli\nbind pm-spec claude opus - claude-cli\nbind engineer claude sonnet - claude-cli\nbind qa-verifier claude sonnet - claude-cli\nbind ui-designer claude sonnet - claude-cli\n' "$Z"
}
mk() {  # $1 = tree name, $2 = code-reviewer row text (empty: no binding.conf)
  mkdir -p "$T/$1/.ops"
  if [ -n "$2" ]; then { rows; printf '%s\n' "$2"; } > "$T/$1/.ops/binding.conf"; fi
}
mk def ''
mk cx "bind code-reviewer codex $Z - codex-cli"
mk cl "bind code-reviewer claude $Z - claude-cli"
mk ws "bind   code-reviewer   claude   opus   -   claude-cli"
mk al 'bind codex-reviewer claude opus - claude-cli'
mk up 'bind code-reviewer Claude opus - claude-cli'
mk two "$(printf 'bind code-reviewer codex provider-configured - codex-cli\nbind codex-reviewer codex provider-configured - codex-cli')"
mkdir -p "$T/mal/.ops"; printf '# %s\nschema 1\n' "$Z" > "$T/mal/.ops/binding.conf"
mkdir -p "$T/dir/.ops/binding.conf"

snap() { (cd "$T" && find def cx cl ws al up two mal dir -print | sort && cksum cx/.ops/binding.conf cl/.ops/binding.conf mal/.ops/binding.conf); }
snap > "$T/s0"

# run <tree> <expected rc> <expected stdout (or empty)> <stderr token (or empty)> [VAR=val ...]
runcase() {
  local name="$1" d="$2" want="$3" out="$4" tok="$5"; shift 5
  local rc=0 e_lines o_lines
  (cd "$T/$d" && env TEAM_RUN_BASE=.ops "$@" bash "$K" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  e_lines="$(grep -c '' "$T/e" || true)"; o_lines="$(grep -c '' "$T/o" || true)"
  if grep -qF -- "$Z" "$T/o" "$T/e"; then fail "$name: sentinel leaked onto a stream"; return; fi
  [ "$rc" -eq "$want" ] || { fail "$name: expected rc $want, got $rc"; return; }
  if [ -n "$out" ]; then
    [ "$(cat "$T/o")" = "$out" ] && [ "$o_lines" -eq 1 ] && [ ! -s "$T/e" ] \
      || { fail "$name: expected stdout exactly '$out' and empty stderr"; return; }
  else
    [ ! -s "$T/o" ] && [ "$e_lines" -eq 1 ] && grep -qF -- "$tok" "$T/e" \
      || { fail "$name: expected empty stdout and one stderr line with '$tok'"; return; }
  fi
  pass "$name"
}

runcase 'row C: no binding.conf (shipped default)' def 0 'admit codex-binding' ''
runcase 'row C: code-reviewer on codex, sentinel model' cx 0 'admit codex-binding' ''
runcase 'row N: code-reviewer on claude, sentinel model and comment' cl 1 '' reviewer-binding-not-codex
runcase 'row N: row aligned by runs of spaces' ws 1 '' reviewer-binding-not-codex
runcase 'row N: superseded codex-reviewer spelling on claude (alias line not forwarded)' al 1 '' reviewer-binding-not-codex
runcase 'row H: claude binding on the Codex CLI host' cl 0 'admit codex-cli-host' '' CODEX_THREAD_ID=t1
runcase 'row N: empty CODEX_THREAD_ID counts as unset' cl 1 '' reviewer-binding-not-codex CODEX_THREAD_ID=
runcase 'row U: uppercase provider' up 2 '' binding-unresolved
runcase 'row U: both spellings at once' two 2 '' binding-unresolved
runcase 'row U: schema-only file' mal 2 '' binding-unresolved
runcase 'row U: directory at binding.conf' dir 2 '' binding-unresolved
runcase 'row H: schema-only file on the Codex CLI host' mal 0 'admit codex-cli-host' '' CODEX_THREAD_ID=t1

for a in --bogus extra; do
  rc=0; (cd "$T/def" && env TEAM_RUN_BASE=.ops bash "$K" "$a" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$T/o" ] && [ "$(grep -c '' "$T/e")" -eq 1 ] && grep -qF usage "$T/e"; then
    pass "row X: argument '$a' refused with usage"
  else fail "row X: argument '$a': rc=$rc"; fi
done
rc=0; (cd "$T/cl" && env TEAM_RUN_BASE=.ops CODEX_THREAD_ID=t1 bash "$K" extra < /dev/null > "$T/o" 2> "$T/e") || rc=$?
{ [ "$rc" -eq 2 ] && [ ! -s "$T/o" ] && grep -qF usage "$T/e"; } \
  && pass "row X: usage also applies on the Codex CLI host" || fail "row X on the host: rc=$rc"
rc=0; (cd "$T/def" && bash "$K" --help extra < /dev/null > "$T/o" 2> "$T/e") || rc=$?
{ [ "$rc" -eq 2 ] && [ ! -s "$T/o" ]; } && pass "row X: --help with an extra argument is usage" || fail "--help extra: rc=$rc"
for a in --help -h; do
  rc=0; (cd "$T/def" && bash "$K" "$a" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  { [ "$rc" -eq 0 ] && [ -s "$T/o" ] && grep -qF reviewer-binding-not-codex "$T/o"; } \
    && pass "$a exits 0 with the table" || fail "$a: rc=$rc"
done

# stderr closed: the refusal exit codes survive (exit 1 is also the errexit
# fallback, so rc 1 here is not distinguishing; rc 2 is).
rc=0; (cd "$T/up" && env TEAM_RUN_BASE=.ops bash "$K" < /dev/null > "$T/o" 2>&-) || rc=$?
[ "$rc" -eq 2 ] && pass "closed stderr: row U still exits 2" || fail "closed stderr row U: rc=$rc"

# launch shapes: bash script, ./script, bare name through a PATH symlink
mkdir -p "$T/ln"; ln -s "$K" "$T/ln/check-review-provider.sh"
for shape in direct symlink; do
  rc=0
  if [ "$shape" = direct ]; then
    (cd "$T/cl" && env TEAM_RUN_BASE=.ops "$K" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  else
    (cd "$T/cl" && env TEAM_RUN_BASE=.ops PATH="$T/ln:$PATH" check-review-provider.sh < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  fi
  { [ "$rc" -eq 1 ] && grep -qF reviewer-binding-not-codex "$T/e"; } \
    && pass "launch shape $shape refuses row N" || fail "launch shape $shape: rc=$rc"
done

# Stubbed resolver beside a copy of the checker: shapes the real resolver never
# emits, so the checker's own row-count, field-count and token guards are the
# only thing standing between them and an admit.
mkdir -p "$T/sb/bin"
cp "$K" "$T/sb/bin/check-review-provider.sh"
stub_case() {  # <name> <resolver-stdout (printf format)> <resolver rc> <want rc> <token>
  local name="$1" out="$2" rrc="$3" want="$4" tok="$5" rc=0
  { printf '#!/usr/bin/env bash\n'; printf 'printf %q' "$out"; printf '\nprintf "noise %s\\n" %q >&2\nexit %s\n' "$Z" "$Z" "$rrc"; } > "$T/sb/bin/resolve-executor.sh"
  (cd "$T/def" && bash "$T/sb/bin/check-review-provider.sh" < /dev/null > "$T/o" 2> "$T/e") || rc=$?
  if grep -qF -- "$Z" "$T/o" "$T/e"; then fail "stub $name: resolver text leaked onto a stream"; return; fi
  if [ "$rc" -eq "$want" ] && [ ! -s "$T/o" ] && [ "$(grep -c '' "$T/e")" -eq 1 ] && grep -qF -- "$tok" "$T/e"; then
    pass "stub resolver: $name"
  else fail "stub resolver $name: rc=$rc want=$want"; fi
}
stub_case 'resolver refuses (exit non-zero)' 'resolved code-reviewer codex m - codex-cli\n' 3 2 binding-unresolved
stub_case 'zero code-reviewer rows' 'resolved tech-lead claude opus - claude-cli\n' 0 2 binding-unresolved
stub_case 'two code-reviewer rows' 'resolved code-reviewer codex m - codex-cli\nresolved code-reviewer codex m - codex-cli\n' 0 2 binding-unresolved
stub_case 'row with five fields' 'resolved code-reviewer claude m -\n' 0 2 binding-unresolved
stub_case 'row with seven fields' 'resolved code-reviewer claude m - claude-cli extra\n' 0 2 binding-unresolved
# shellcheck disable=SC2016  # a literal dollar sign in the provider token is the point
stub_case 'provider token outside the allowed charset' 'resolved code-reviewer Cl$aude m - claude-cli\n' 0 2 binding-unresolved
stub_case 'empty resolver output' '' 0 2 binding-unresolved
stub_case 'non-codex row carries a sentinel model' "resolved code-reviewer claude $Z - claude-cli\n" 0 1 reviewer-binding-not-codex

snap > "$T/s1"
cmp -s "$T/s0" "$T/s1" && pass "fixture trees byte-identical before and after" || fail "fixture trees changed"
[ ! -e "$T/codex-called" ] && pass "the stub codex was never invoked" || fail "codex was invoked"
[ -x "$K" ] && pass "checker is executable" || fail "checker not executable"

# Wiring: the three modes' gates and CI lines exist (static, repository-side).
if [ -s "$ROOT/.github/workflows/check-handoff.yml" ]; then
  grep -qE '^[[:space:]]*run: bash tests/check-review-provider/run.sh$' "$ROOT/.github/workflows/check-handoff.yml" \
    && pass "CI runs this suite" || fail "CI does not run this suite"
fi

[ "$fails" -eq 0 ] || exit 1
