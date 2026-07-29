#!/usr/bin/env bash
# run.sh — drive bin/check-interventions.sh against synthetic intervention-file
# fixtures and assert the state machine documented in
# .shell-team/specs/T-1002-intervention-capture-channel.md (AC13): every case
# below is asserted on BOTH exit code AND the stderr classification token, per
# the "wrong-but-nonzero must not look like success" fixture-synthesis
# discipline tests/check-provenance/run.sh already follows.
#
# Sixteen case classes, counted via case_start() below and pinned against
# CASES_EXPECTED — a seventeenth case added without updating this file's own
# count fails the suite rather than passing silently. Each line below names
# bin/check-interventions.sh explicitly, since it is the sole subject under
# test in every one of the sixteen:
#
#   bin/check-interventions.sh — case: well-formed entries are conformant
#   bin/check-interventions.sh — case: the zero-entry sentinel alone is conformant
#   bin/check-interventions.sh — case: an unknown class token is a schema violation
#   bin/check-interventions.sh — case: a missing required field is a schema violation
#   bin/check-interventions.sh — case: a duplicated field within one entry is a schema violation
#   bin/check-interventions.sh — case: an empty field value is a schema violation
#   bin/check-interventions.sh — case: the sentinel and an entry cannot coexist, in either order
#   bin/check-interventions.sh — case: a region with neither the sentinel nor an entry is a schema violation
#   bin/check-interventions.sh — case: a malformed date is a schema violation and the check is format-only
#   bin/check-interventions.sh — case: a wrapped field value on a second unindented line is a schema violation
#   bin/check-interventions.sh — case: absent, duplicated, reversed and id-mismatched markers are structural errors
#   bin/check-interventions.sh — case: usage errors — no argument, an extra argument, a directory, an unreadable file
#   bin/check-interventions.sh — case: a MALFORMED file with CRLF line endings is still reported
#   bin/check-interventions.sh — case: field values quoting a marker, a class token or the sentinel are not miscounted
#   bin/check-interventions.sh — case: the three invocation forms agree on rc and produce byte-identical output
#   bin/check-interventions.sh — case: a --task disagreement is structural and the reserved no-task id is accepted
#
# Fixtures use synthetic task id T-900 (not a real board task), built fresh in
# a temp dir per case — no static fixtures/ directory needed. Temp roots live
# under $TMPDIR when set (restricted sandboxes); every mktemp call uses an
# explicit "${TMPDIR:-/tmp}/...XXXXXX" template (2026-07-19 lesson: a bare
# mktemp ignores TMPDIR and fails in-sandbox on this platform).

set -euo pipefail

# An inherited BASH_ENV startup hook must never leak output/behavior into a
# checker invocation captured below (same normalization tests/check-provenance
# /run.sh applies).
unset BASH_ENV

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-interventions.sh"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-interventions-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

CASES_EXPECTED=16
CASES_RUN=0
case_start() {  # $1 = case label (printed + counted toward CASES_RUN)
  CASES_RUN=$((CASES_RUN + 1))
  printf '\n--- %s ---\n' "$1"
}

TASK_ID="T-900"

# run_checker <args...> -- captures RC (exit code) and ERR (stderr text); the
# LAST argument is treated as the file under test only for readability of
# call sites below (no positional magic — this helper just forwards args).
RC=0
ERR=""
run_checker() {
  local out
  set +e
  out="$(bash "$CHECKER" "$@" 2>&1 >/dev/null)"
  RC=$?
  set -e
  ERR="$out"
}

# dump_cmp_diag <label> <file1> <file2> [<file3> ...]: when a byte-precise
# `cmp` comparison across invocation styles FAILs, surface the differing
# bytes to stderr before the EXIT trap deletes the temp files that a bare
# failure message would otherwise point to uselessly.
dump_cmp_diag() {
  local label="$1"; shift
  local prev="" f
  for f in "$@"; do
    if [ -n "$prev" ] && ! cmp -s "$prev" "$f"; then
      printf 'DIAG %s: %s and %s differ —\n' "$label" "$prev" "$f" >&2
      diff -u "$prev" "$f" >&2 || true
    fi
    prev="$f"
  done
}

# ============================================================================
case_start "case: well-formed entries are conformant"
# ============================================================================
C="$TMP/case-01"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-interrupt\n'
  printf '  date: 2026-07-30\n'
  printf '  summary: The maintainer interrupted mid-implementation to ask a clarifying question.\n'
  printf '  effect: The engineer paused and answered before continuing.\n\n'
  printf -- '- intervention: work-deferred\n'
  printf '  date: 2026-07-30\n'
  printf '  summary: A fast-follow was identified but not pursued this round.\n'
  printf '  effect: Filed as a separate issue instead.\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 0 ] || fail "well-formed: expected exit 0 (conformant), got $RC: $ERR"
pass "well-formed multi-entry interventions file is conformant (exit 0)"

# ============================================================================
case_start "case: the zero-entry sentinel alone is conformant"
# ============================================================================
C="$TMP/case-02"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf 'no interventions occurred\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 0 ] || fail "sentinel: expected exit 0 (conformant), got $RC: $ERR"
pass "zero-entry sentinel as the sole non-blank line is conformant (exit 0)"

# ============================================================================
case_start "case: an unknown class token is a schema violation"
# ============================================================================
C="$TMP/case-03"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-nudge\n'
  printf '  date: 2026-07-30\n  summary: s\n  effect: e\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 1 ] || fail "unknown class: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "unknown class: stderr must carry 'schema' token, got: $ERR"
pass "an unrecognized class token ('human-nudge') is a schema violation (exit 1, token present)"

# ============================================================================
case_start "case: a missing required field is a schema violation"
# ============================================================================
C="$TMP/case-04"; mkdir -p "$C"
mk4() { printf '<!-- BEGIN interventions: %s -->\n\n%b<!-- END interventions: %s -->\n' "$TASK_ID" "$1" "$TASK_ID" > "$C/f.md"; }
for body in \
  '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n\n' \
  '- intervention: human-stop\n  summary: s\n  effect: e\n\n' \
  '- intervention: human-stop\n  date: 2026-07-30\n  effect: e\n\n'; do
  mk4 "$body"
  run_checker "$C/f.md"
  [ "$RC" -eq 1 ] || fail "missing field: expected exit 1 (schema), got $RC: $ERR"
  grep -q 'schema' <<< "$ERR" || fail "missing field: stderr must carry 'schema' token, got: $ERR"
done
# Regression lock (self-chosen mutation, per this task's "Notes for engineer"
# final paragraph): a SECOND entry that carries none of its own date/summary/
# effect fields, immediately following a FULLY well-formed first entry, must
# still be caught — a per-entry counter that is not reset when a new
# `- intervention:` anchor begins would let the second entry's finalize()
# check spuriously pass on the FIRST entry's leftover counts. This is
# deliberately a MULTI-entry fixture (every case above is single-entry) —
# mutating away the three `..._count_cur=0` resets inside the entry-anchor
# branch reproduces this exact false-conformant outcome, confirmed by hand
# during this task's mutation self-check before this fixture was added.
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-stop\n  date: 2026-07-30\n  summary: first entry, complete\n  effect: e1\n\n'
  printf -- '- intervention: human-correction\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 1 ] || fail "second entry with none of its own fields (after a complete first entry): expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "second entry with none of its own fields: stderr must carry 'schema' token, got: $ERR"
pass "an entry missing date/summary/effect (each in turn, single-entry) is a schema violation (exit 1, token present); a second entry with NONE of its own fields, following a complete first entry, is likewise caught — not masked by leftover per-entry field counters"

# ============================================================================
case_start "case: a duplicated field within one entry is a schema violation"
# ============================================================================
C="$TMP/case-05"; mkdir -p "$C"
mk5() { printf '<!-- BEGIN interventions: %s -->\n\n%b<!-- END interventions: %s -->\n' "$TASK_ID" "$1" "$TASK_ID" > "$C/f.md"; }
for body in \
  '- intervention: human-stop\n  date: 2026-07-30\n  date: 2026-07-31\n  summary: s\n  effect: e\n\n' \
  '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  summary: s2\n  effect: e\n\n' \
  '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n  effect: e2\n\n'; do
  mk5 "$body"
  run_checker "$C/f.md"
  [ "$RC" -eq 1 ] || fail "duplicate field: expected exit 1 (schema), got $RC: $ERR"
  grep -q 'schema' <<< "$ERR" || fail "duplicate field: stderr must carry 'schema' token, got: $ERR"
done
pass "a duplicated date/summary/effect field within one entry is a schema violation (exit 1, token present)"

# ============================================================================
case_start "case: an empty field value is a schema violation"
# ============================================================================
C="$TMP/case-06"; mkdir -p "$C"
mk6() { printf '<!-- BEGIN interventions: %s -->\n\n%b<!-- END interventions: %s -->\n' "$TASK_ID" "$1" "$TASK_ID" > "$C/f.md"; }
for body in \
  '- intervention: human-stop\n  date: 2026-07-30\n  summary:\n  effect: e\n\n' \
  '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect:   \n\n'; do
  mk6 "$body"
  run_checker "$C/f.md"
  [ "$RC" -eq 1 ] || fail "empty value: expected exit 1 (schema), got $RC: $ERR"
  grep -q 'schema' <<< "$ERR" || fail "empty value: stderr must carry 'schema' token, got: $ERR"
done
pass "an empty (or whitespace-only) summary/effect value is a schema violation (exit 1, token present)"

# ============================================================================
case_start "case: the sentinel and an entry cannot coexist, in either order"
# ============================================================================
C="$TMP/case-07"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf 'no interventions occurred\n\n'
  printf -- '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/sentinel-first.md"
run_checker "$C/sentinel-first.md"
[ "$RC" -eq 1 ] || fail "sentinel-then-entry: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "sentinel-then-entry: stderr must carry 'schema' token, got: $ERR"

{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n\n'
  printf 'no interventions occurred\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/entry-first.md"
run_checker "$C/entry-first.md"
[ "$RC" -eq 1 ] || fail "entry-then-sentinel: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "entry-then-sentinel: stderr must carry 'schema' token, got: $ERR"
pass "the sentinel and an entry coexisting (either order) is a schema violation (exit 1, token present)"

# ============================================================================
case_start "case: a region with neither the sentinel nor an entry is a schema violation"
# ============================================================================
C="$TMP/case-08"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 1 ] || fail "empty region: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "empty region: stderr must carry 'schema' token, got: $ERR"
pass "a region with neither the sentinel nor an entry is a schema violation (exit 1, token present)"

# ============================================================================
case_start "case: a malformed date is a schema violation and the check is format-only"
# ============================================================================
C="$TMP/case-09"; mkdir -p "$C"
mk9() { printf '<!-- BEGIN interventions: %s -->\n\n- intervention: human-stop\n  date: %s\n  summary: s\n  effect: e\n\n<!-- END interventions: %s -->\n' "$TASK_ID" "$1" "$TASK_ID" > "$C/f.md"; }
mk9 '2026-13-45'
run_checker "$C/f.md"
[ "$RC" -eq 0 ] || fail "calendar-invalid-but-format-valid date: expected exit 0 (conformant), got $RC: $ERR"
for d in '2026-7-30' '30-07-2026' 'yesterday' '2026-07-30 14:02' '20260730'; do
  mk9 "$d"
  run_checker "$C/f.md"
  [ "$RC" -eq 1 ] || fail "malformed date '$d': expected exit 1 (schema), got $RC: $ERR"
  grep -q 'schema' <<< "$ERR" || fail "malformed date '$d': stderr must carry 'schema' token, got: $ERR"
done
grep -qF -- 'the date is validated for FORMAT only (YYYY-MM-DD); calendar validity is deliberately not checked' "$CHECKER" \
  || fail "the checker's own header must state the format-only boundary verbatim"
pass "a format-invalid date is a schema violation; a calendar-invalid but format-valid date (2026-13-45) is conformant — the declared boundary"

# ============================================================================
case_start "case: a wrapped field value on a second unindented line is a schema violation"
# ============================================================================
C="$TMP/case-10"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-stop\n'
  printf '  date: 2026-07-30\n'
  printf '  summary: the first line of the summary\n'
  printf 'and its continuation on an unindented second line\n'
  printf '  effect: e\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 1 ] || fail "wrapped value: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "wrapped value: stderr must carry 'schema' token, got: $ERR"
# Positive control: blank lines inside the region are ignored everywhere —
# proves the region walk is not simply rejecting whitespace.
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-stop\n\n'
  printf '  date: 2026-07-30\n  summary: s\n  effect: e\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/blank-ok.md"
run_checker "$C/blank-ok.md"
[ "$RC" -eq 0 ] || fail "blank lines inside an entry: expected exit 0 (conformant), got $RC: $ERR"
pass "a wrapped field value on an unindented second line is a schema violation (exit 1, token present); blank lines inside the region are ignored (positive control, exit 0)"

# ============================================================================
case_start "case: absent, duplicated, reversed and id-mismatched markers are structural errors"
# ============================================================================
C="$TMP/case-11"; mkdir -p "$C"
BODY=$'no interventions occurred\n'
# mk_sentinel_file <id> <dest>: a well-formed sentinel-only fixture for <id>,
# reused by later cases (avoids re-embedding $BODY inside a printf FORMAT
# string, which shellcheck (SC2059) flags).
mk_sentinel_file() {
  printf '<!-- BEGIN interventions: %s -->\n' "$1" > "$2"
  printf '%s' "$BODY" >> "$2"
  printf '<!-- END interventions: %s -->\n' "$1" >> "$2"
}

# absent
printf '%s' "$BODY" > "$C/nomarker.md"
run_checker "$C/nomarker.md"
[ "$RC" -eq 2 ] || fail "absent markers: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "absent markers: stderr must carry 'structural' token, got: $ERR"

# duplicated pair
{
  printf '<!-- BEGIN interventions: %s -->\n' "$TASK_ID"; printf '%s' "$BODY"
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
  printf '<!-- BEGIN interventions: %s -->\n' "$TASK_ID"; printf '%s' "$BODY"
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/dup.md"
run_checker "$C/dup.md"
[ "$RC" -eq 2 ] || fail "duplicated markers: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "duplicated markers: stderr must carry 'structural' token, got: $ERR"

# reversed (END before BEGIN)
{
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"; printf '%s' "$BODY"
  printf '<!-- BEGIN interventions: %s -->\n' "$TASK_ID"
} > "$C/reversed.md"
run_checker "$C/reversed.md"
[ "$RC" -eq 2 ] || fail "reversed markers: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "reversed markers: stderr must carry 'structural' token, got: $ERR"

# BEGIN/END id mismatch
{
  printf '<!-- BEGIN interventions: %s -->\n' "$TASK_ID"; printf '%s' "$BODY"
  printf '<!-- END interventions: T-901 -->\n'
} > "$C/mismatch.md"
run_checker "$C/mismatch.md"
[ "$RC" -eq 2 ] || fail "id-mismatched markers: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "id-mismatched markers: stderr must carry 'structural' token, got: $ERR"

# an unrecognized id (neither T-NNN nor no-task) is invisible to the BEGIN
# regex, so it also surfaces as "no BEGIN marker found" (structural).
{
  printf '<!-- BEGIN interventions: nope -->\n'; printf '%s' "$BODY"
  printf '<!-- END interventions: nope -->\n'
} > "$C/badid.md"
run_checker "$C/badid.md"
[ "$RC" -eq 2 ] || fail "unrecognized id: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "unrecognized id: stderr must carry 'structural' token, got: $ERR"

pass "absent / duplicated / reversed / id-mismatched / unrecognized-id markers all exit 2 with 'structural' token"

# ============================================================================
case_start "case: usage errors — no argument, an extra argument, a directory, an unreadable file"
# ============================================================================
C="$TMP/case-12"; mkdir -p "$C/a-directory"
mk_sentinel_file "$TASK_ID" "$C/f.md"

set +e
NOARG_OUT="$(bash "$CHECKER" 2>&1 >/dev/null)"
NOARG_RC=$?
set -e
[ "$NOARG_RC" -eq 2 ] || fail "missing argument: expected exit 2 (usage), got $NOARG_RC: $NOARG_OUT"
grep -q 'usage' <<< "$NOARG_OUT" || fail "missing argument: stderr must carry 'usage' token, got: $NOARG_OUT"

set +e
EXTRA_OUT="$(bash "$CHECKER" "$C/f.md" "extra-argument" 2>&1 >/dev/null)"
EXTRA_RC=$?
set -e
[ "$EXTRA_RC" -eq 2 ] || fail "extra argument: expected exit 2 (usage), got $EXTRA_RC: $EXTRA_OUT"
grep -q 'usage' <<< "$EXTRA_OUT" || fail "extra argument: stderr must carry 'usage' token, got: $EXTRA_OUT"

run_checker "$C/a-directory"
[ "$RC" -eq 2 ] || fail "directory argument: expected exit 2 (usage), got $RC: $ERR"
grep -q 'usage' <<< "$ERR" || fail "directory argument: stderr must carry 'usage' token, got: $ERR"

UNREADABLE="$C/unreadable.md"
mk_sentinel_file "$TASK_ID" "$UNREADABLE"
chmod 000 "$UNREADABLE"
if [ -r "$UNREADABLE" ]; then
  printf 'SKIP: running as a user that can read a 000-mode file (root?); unreadable-file case not exercised\n'
else
  run_checker "$UNREADABLE"
  [ "$RC" -eq 2 ] || fail "unreadable file: expected exit 2 (usage), got $RC: $ERR"
  grep -q 'usage' <<< "$ERR" || fail "unreadable file: stderr must carry 'usage' token, got: $ERR"
fi
chmod 644 "$UNREADABLE"

set +e
UNKNOWNFLAG_OUT="$(bash "$CHECKER" --no-such-flag "$C/f.md" 2>&1 >/dev/null)"
UNKNOWNFLAG_RC=$?
set -e
[ "$UNKNOWNFLAG_RC" -eq 2 ] || fail "unknown flag: expected exit 2 (usage), got $UNKNOWNFLAG_RC: $UNKNOWNFLAG_OUT"
grep -q 'usage' <<< "$UNKNOWNFLAG_OUT" || fail "unknown flag: stderr must carry 'usage' token, got: $UNKNOWNFLAG_OUT"

pass "missing / extra / unknown-flag / directory / unreadable-file arguments all exit 2 with 'usage' token"

# ============================================================================
case_start "case: a MALFORMED file with CRLF line endings is still reported"
# ============================================================================
C="$TMP/case-13"; mkdir -p "$C"
printf '<!-- BEGIN interventions: %s -->\r\n- intervention: human-nudge\r\n  date: 2026-07-30\r\n  summary: s\r\n  effect: e\r\n<!-- END interventions: %s -->\r\n' \
  "$TASK_ID" "$TASK_ID" > "$C/bad-crlf.md"
run_checker "$C/bad-crlf.md"
[ "$RC" -eq 1 ] || fail "malformed CRLF: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "malformed CRLF: stderr must carry 'schema' token, got: $ERR"
# Positive control: a WELL-FORMED CRLF file is still conformant — a checker
# that never examines the file would otherwise pass both cases identically.
printf '<!-- BEGIN interventions: %s -->\r\n- intervention: human-stop\r\n  date: 2026-07-30\r\n  summary: s\r\n  effect: e\r\n<!-- END interventions: %s -->\r\n' \
  "$TASK_ID" "$TASK_ID" > "$C/ok-crlf.md"
run_checker "$C/ok-crlf.md"
[ "$RC" -eq 0 ] || fail "well-formed CRLF: expected exit 0 (conformant), got $RC: $ERR"
pass "a MALFORMED CRLF file is still reported (exit 1, 'schema' token); a well-formed CRLF file remains conformant (exit 0)"

# ============================================================================
case_start "case: field values quoting a marker, a class token or the sentinel are not miscounted"
# ============================================================================
C="$TMP/case-14"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: unclassified\n'
  printf '  date: 2026-07-30\n'
  # shellcheck disable=SC2016  # literal prose to embed as a fixture VALUE.
  printf '  summary: the file quotes `<!-- BEGIN interventions: T-901 -->` and `no interventions occurred` and `effect:` inside this value\n'
  # shellcheck disable=SC2016
  printf '  effect: the value also names `- intervention: human-stop` and `<!-- END interventions: T-901 -->` without adding a second entry\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"
run_checker "$C/f.md"
[ "$RC" -eq 0 ] || fail "self-referential prose: expected exit 0 (conformant), got $RC: $ERR"
pass "a marker literal / class token / sentinel string / field keyword quoted inside a summary or effect VALUE is not miscounted as a second structural occurrence (exit 0)"

# ============================================================================
case_start "case: the three invocation forms agree on rc and produce byte-identical output"
# ============================================================================
C="$TMP/case-15"; mkdir -p "$C"
{
  printf '<!-- BEGIN interventions: %s -->\n\n' "$TASK_ID"
  printf -- '- intervention: human-stop\n  date: 2026-07-30\n  summary: s\n  effect: e\n\n'
  printf '<!-- END interventions: %s -->\n' "$TASK_ID"
} > "$C/f.md"

set +e
( cd "$REPO_ROOT" && bash bin/check-interventions.sh "$C/f.md" ) >"$C/out-1.txt" 2>&1
rc1=$?
( cd "$REPO_ROOT" && ./bin/check-interventions.sh "$C/f.md" ) >"$C/out-2.txt" 2>&1
rc2=$?

PATHBIN="$TMP/pathbin"
mkdir -p "$PATHBIN"
ln -sf "$CHECKER" "$PATHBIN/check-interventions.sh"
# shellcheck disable=SC2030  # deliberately subshell-scoped PATH export — this
# never touches the parent shell's PATH (same idiom tests/check-provenance
# /run.sh uses for its own 3-invocation-form case).
( export PATH="$PATHBIN:$PATH"; cd "$REPO_ROOT" && check-interventions.sh "$C/f.md" ) >"$C/out-3.txt" 2>&1
rc3=$?
set -e

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ] || [ "$rc3" -ne 0 ]; then
  fail "3-invocation-forms: invocation styles disagree or failed — bash=$rc1 dot-slash=$rc2 PATH-bare=$rc3"
fi
if ! cmp -s "$C/out-1.txt" "$C/out-2.txt" || ! cmp -s "$C/out-2.txt" "$C/out-3.txt"; then
  dump_cmp_diag "3-invocation-forms" "$C/out-1.txt" "$C/out-2.txt" "$C/out-3.txt"
  fail "3-invocation-forms: output differs across invocation styles — see $C/out-1.txt / $C/out-2.txt / $C/out-3.txt"
fi
pass "bash / ./ / PATH-bare-name (via a symlink named check-interventions.sh) invocations all produce identical output and exit 0"

# ============================================================================
case_start "case: a --task disagreement is structural and the reserved no-task id is accepted"
# ============================================================================
C="$TMP/case-16"; mkdir -p "$C"
mk_sentinel_file "$TASK_ID" "$C/f.md"
run_checker --task "$TASK_ID" "$C/f.md"
[ "$RC" -eq 0 ] || fail "--task matching: expected exit 0 (conformant), got $RC: $ERR"
run_checker --task "T-901" "$C/f.md"
[ "$RC" -eq 2 ] || fail "--task disagreement: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "--task disagreement: stderr must carry 'structural' token, got: $ERR"

mk_sentinel_file "no-task" "$C/notask.md"
run_checker --task "no-task" "$C/notask.md"
[ "$RC" -eq 0 ] || fail "reserved no-task id with matching --task: expected exit 0 (conformant), got $RC: $ERR"
run_checker "$C/notask.md"
[ "$RC" -eq 0 ] || fail "reserved no-task id without --task: expected exit 0 (conformant), got $RC: $ERR"
pass "a --task value that disagrees with the BEGIN marker id is structural (exit 2); the reserved no-task id is accepted with and without --task"

# ============================================================================
# Case-class count pin (both directions): a seventeenth case added without
# updating CASES_EXPECTED fails here rather than passing silently, and a case
# removed without updating CASES_EXPECTED fails just the same.
# ============================================================================
[ "$CASES_RUN" -eq "$CASES_EXPECTED" ] \
  || fail "expected exactly $CASES_EXPECTED case classes to run, counted $CASES_RUN — update CASES_EXPECTED if a case was deliberately added/removed"
pass "exactly $CASES_EXPECTED case classes were run (pinned in both directions)"

# --- self-check: this suite's own script is shellcheck clean (soft-skip) ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "shellcheck: check-interventions.sh / run.sh must be clean"
  pass "shellcheck clean (checker + test runner)"
else
  printf 'SKIP: shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll check-interventions assertions passed.\n'
