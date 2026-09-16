#!/usr/bin/env bash
# run.sh — assert bin/check-refreeze-grant.sh (T-1147, issue #515) against
# the real script: the absent-arm default, the accepting grammar across its
# tolerated shapes, every malformed/out-of-vocabulary refusal, the
# occupancy lattice, the shipped default, and the never-sourced contract.
#
# Exit: 0 = every assertion passed; non-zero = a FAIL line was printed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-refreeze-grant.sh"
DEFAULT_CONFIG="$REPO_ROOT/templates/refreeze-grant-default.conf"

if [ -n "${TMPDIR:-}" ]; then
  T="$(mktemp -d "${TMPDIR%/}/check-refreeze-grant-test.XXXXXX")"
else
  T="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

invoke() {  # remaining args passed straight to the script
  bash "$SCRIPT" "$@" >"$T/out" 2>"$T/err"
  printf '%s' "$?"
}

chk_rc() {  # desc expect_rc got_rc
  local desc="$1" expect="$2" got="$3"
  [ "$got" = "$expect" ] \
    || fail "$desc (expected exit $expect, got $got; stderr: $(cat "$T/err" 2>/dev/null))"
}

# =============================================================================
# 1. crg-absent-default: no record at all resolves to `grant none`, exit 0 —
#    across two distinct scratch base directories (one truly empty, one
#    with unrelated content), so the absent-arm result is shown to depend on
#    the record's own absence and not on the directory being empty.
# =============================================================================
mkdir -p "$T/absent1" "$T/absent2"
printf 'placeholder\n' > "$T/absent2/todo.md"
for b in "$T/absent1" "$T/absent2"; do
  rc=$(invoke --base "$b" --print-grant)
  chk_rc "crg-absent-default ($b)" 0 "$rc"
  [ "$(cat "$T/out")" = "grant none" ] || fail "crg-absent-default ($b): stdout must be exactly 'grant none'"
  [ ! -s "$T/err" ] || fail "crg-absent-default ($b): must write nothing to stderr"
done
pass "crg-absent-default"

# Positive control: writing a conformant class-m record into the same
# directory now resolves to it — proving the absent-arm result above was a
# resolved answer, not a universally broken invocation.
printf 'schema 1\ngrant class-m\n' > "$T/absent1/refreeze-grant.conf"
rc=$(invoke --base "$T/absent1" --print-grant)
chk_rc "crg-absent-default positive control" 0 "$rc"
[ "$(cat "$T/out")" = "grant class-m" ] || fail "crg-absent-default positive control: stdout must be 'grant class-m'"
pass "crg-absent-default: positive control (writing a record then resolves the grant)"
rm -f "$T/absent1/refreeze-grant.conf"

# =============================================================================
# 2. crg-grant-class-m: a conformant class-m record resolves to it, across
#    the grammar's accepted shapes (comments/blanks/leading whitespace,
#    CRLF, a live symlink, the shipped default reached via --config).
# =============================================================================
w() { mkdir -p "$T/$1"; printf '%b' "$2" > "$T/$1/refreeze-grant.conf"; test -s "$T/$1/refreeze-grant.conf" || fail "fixture $1 must be non-empty"; }
r() {  # dir expected_line
  rc=$(invoke --base "$T/$1" --print-grant)
  chk_rc "grammar shape: $1" 0 "$rc"
  [ "$(grep -c . "$T/out" || true)" = "1" ] || fail "grammar shape: $1: stdout must be exactly one line"
  [ "$(cat "$T/out")" = "$2" ] || fail "grammar shape: $1: expected stdout '$2', got '$(cat "$T/out")'"
}

w minimal 'schema 1\ngrant class-m\n'
r minimal 'grant class-m'
pass "crg-grant-class-m"

w commented '# a comment\n\n  schema 1\n\n# another\n  grant class-m\n'
r commented 'grant class-m'
pass "crg-grant-class-m: comments, blank lines and leading whitespace tolerated"

w crlf 'schema 1\r\ngrant class-m\r\n'
r crlf 'grant class-m'
pass "crg-grant-class-m: CRLF line endings tolerated"

w none-minimal 'schema 1\ngrant none\n'
r none-minimal 'grant none'
pass "explicit 'grant none' resolves to none, exit 0"

mkdir -p "$T/sym"
printf 'schema 1\ngrant class-m\n' > "$T/elsewhere.conf"
ln -s "$T/elsewhere.conf" "$T/sym/refreeze-grant.conf"
[ -L "$T/sym/refreeze-grant.conf" ] || fail "symlink fixture must itself be a symlink"
[ -e "$T/sym/refreeze-grant.conf" ] || fail "symlink fixture must resolve to an existing target"
r sym 'grant class-m'
pass "crg-grant-class-m: a live symlink to a regular file is read exactly like a regular file"

rc=$(invoke --config "$DEFAULT_CONFIG" --print-grant)
chk_rc "shipped default via --config" 0 "$rc"
[ "$(cat "$T/out")" = "grant none" ] || fail "shipped default via --config: expected 'grant none'"
pass "the shipped templates/refreeze-grant-default.conf validates and prints 'grant none'"

# =============================================================================
# 3. crg-malformed-not-granted (and its eight siblings): every malformed or
#    out-of-vocabulary shape refuses at exit 1, prints nothing to stdout,
#    and never resolves to a grant.
# =============================================================================
: > "$T/allout"
bad_case() {  # desc content
  local desc="$1" content="$2"
  mkdir -p "$T/bad"
  printf '%b' "$content" > "$T/bad/refreeze-grant.conf"
  rc=$(invoke --base "$T/bad" --print-grant)
  [ "$rc" = "1" ] || fail "$desc (expected exit 1, got $rc; stderr: $(cat "$T/err" 2>/dev/null))"
  [ ! -s "$T/out" ] || fail "$desc: stdout must be empty on refusal"
  [ -s "$T/err" ] || fail "$desc: stderr must carry a refusal token"
  cat "$T/out" >> "$T/allout"
  pass "$desc"
}

bad_case "crg-malformed-not-granted: unknown first field" 'schema 1\ngrant class-m\nwibble yes\n'
pass "crg-malformed-not-granted"
bad_case "malformed: a field authored for a newer plugin version" 'schema 1\ngrant class-m\nexpires 2027-01-01\n'
bad_case "malformed: no schema line refuses missing-schema" 'grant class-m\n'
bad_case "malformed: a line preceding schema refuses schema-not-first" 'grant class-m\nschema 1\n'
bad_case "malformed: an unsupported schema version refuses unsupported-schema" 'schema 2\ngrant class-m\n'
bad_case "malformed: two schema lines refuse duplicate-schema" 'schema 1\nschema 1\ngrant class-m\n'
bad_case "malformed: no grant line refuses missing-grant" 'schema 1\n'
bad_case "malformed: two grant lines refuse duplicate-grant" 'schema 1\ngrant class-m\ngrant none\n'
bad_case "malformed: an out-of-vocabulary grant value refuses unknown-grant" 'schema 1\ngrant yes-please\n'

grep -qF -- 'grant class-m' "$T/allout" && fail "no malformed refusal's captured stdout may ever carry 'grant class-m'"
pass "malformed: across all nine shapes, captured stdout carries 'grant class-m' zero times"

# =============================================================================
# 4. crg-occupancy-not-granted (and its three siblings): a non-regular
#    occupant at the record path refuses at exit 2, never grants.
# =============================================================================
occ_case() {  # desc setup_fn
  local desc="$1"
  rc=$(invoke --base "$T/occfix" --print-grant)
  [ "$rc" = "2" ] || fail "$desc (expected exit 2, got $rc; stderr: $(cat "$T/err" 2>/dev/null))"
  [ ! -s "$T/out" ] || fail "$desc: stdout must be empty on refusal"
  [ -s "$T/err" ] || fail "$desc: stderr must carry a refusal token"
  pass "$desc"
}

rm -rf "$T/occfix"; mkdir -p "$T/occfix/refreeze-grant.conf"
occ_case "crg-occupancy-not-granted: a directory at the record path refuses declaration-occupancy"
grep -qF -- 'declaration-occupancy' "$T/err" || fail "directory occupant must name declaration-occupancy"
pass "crg-occupancy-not-granted"

rm -rf "$T/occfix"; mkdir -p "$T/occfix"
ln -s "$T/occfix/absent-target" "$T/occfix/refreeze-grant.conf"
occ_case "occupancy: a dangling symlink at the record path refuses declaration-occupancy"

if command -v mkfifo >/dev/null 2>&1; then
  rm -rf "$T/occfix"; mkdir -p "$T/occfix"
  mkfifo "$T/occfix/refreeze-grant.conf"
  occ_case "occupancy: a FIFO at the record path refuses declaration-occupancy"
else
  fail "mkfifo is required for this suite and is not on PATH"
fi

if [ "$(id -u)" != "0" ]; then
  rm -rf "$T/occfix"; mkdir -p "$T/occfix"
  printf 'schema 1\ngrant class-m\n' > "$T/occfix/refreeze-grant.conf"
  chmod 000 "$T/occfix/refreeze-grant.conf"
  [ ! -r "$T/occfix/refreeze-grant.conf" ] || fail "unreadable fixture must really be unreadable before it is trusted"
  occ_case "occupancy: an unreadable regular file refuses declaration-unreadable"
  grep -qF -- 'declaration-unreadable' "$T/err" || fail "unreadable occupant must name declaration-unreadable"
  chmod 700 "$T/occfix/refreeze-grant.conf" 2>/dev/null || true
else
  pass "occupancy: unreadable-file case skipped (running as root defeats chmod 000)"
fi

# =============================================================================
# 5. The record is data, never code: three shell-construct grant values
#    exit 1, print nothing, and never actually run.
# =============================================================================
SENT="$T/sentinel"
: > "$SENT"; [ -f "$SENT" ] || fail "sentinel setup must create a file"; rm -f "$SENT"; [ ! -f "$SENT" ] || fail "sentinel setup must remove the file"

evil() {  # value
  mkdir -p "$T/evil"
  printf 'schema 1\ngrant %s\n' "$1" > "$T/evil/refreeze-grant.conf"
  rc=$(invoke --base "$T/evil" --print-grant)
  [ "$rc" = "1" ] || fail "never-sourced: value '$1' (expected exit 1, got $rc)"
  [ ! -s "$T/out" ] || fail "never-sourced: value '$1' must print nothing to stdout"
}
# shellcheck disable=SC2016  # intentional: these values must NOT expand — that is exactly what this fixture proves
evil '$(touch '"$SENT"')'
evil 'none; touch '"$SENT"
evil 'none > '"$SENT"
[ ! -f "$SENT" ] || fail "never-sourced: the sentinel file must never have been created"
pass "the record is never sourced, evaluated or executed (three shell-construct grant values)"

# =============================================================================
# 6. --help exits 0 and writes a non-empty stream.
# =============================================================================
bash "$SCRIPT" --help > "$T/help" 2>&1
[ -s "$T/help" ] || fail "--help must write a non-empty stream"
pass "--help exits 0 and writes a non-empty stream"

# =============================================================================
# 7. Usage errors refuse at exit 2 (both --base and --config, an unknown
#    flag, and no mode at all).
# =============================================================================
rc=$(invoke --base "$T/absent1" --config "$DEFAULT_CONFIG" --print-grant)
chk_rc "usage: --base and --config together refuses" 2 "$rc"

rc=$(invoke --base "$T/absent1")
chk_rc "usage: no --print-grant refuses" 2 "$rc"

rc=$(invoke --bogus-flag)
chk_rc "usage: an unknown flag refuses" 2 "$rc"
pass "usage errors (conflicting flags, missing mode, unknown flag) all refuse at exit 2"

# =============================================================================
# 8. Neither shipped caller passes --base or --config to
#    check-refreeze-grant.sh (mirrors tests/check-oversight/run.sh's own
#    equivalent assertion).
# =============================================================================
if grep -F -- 'check-refreeze-grant.sh' "$REPO_ROOT/skills/run/SKILL.md" | grep -qE -- '--base |--config '; then
  fail "skills/run/SKILL.md must never pass --base or --config to check-refreeze-grant.sh"
fi
pass "skills/run/SKILL.md does not pass --base or --config to check-refreeze-grant.sh"

echo "check-refreeze-grant suite: all assertions passed"
