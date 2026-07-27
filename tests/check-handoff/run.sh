#!/usr/bin/env bash
# run.sh — drive bin/check-handoff.sh against the fixtures and assert the
# documented behavior (AC2, AC3, AC4 / AC6) plus regression guards for the
# Codex review findings (M1: unanchored flag extraction; M2: lowercase flag
# misclassification; CRLF line endings).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-handoff.sh"
FIX="$HERE/fixtures"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Explicit ${TMPDIR:-/tmp} template (repo lesson, 2026-06-16 / T-038, per
# tests/rollup-track/run.sh's precedent): a bare `mktemp` with no template
# resolves against the OS default temp dir regardless of $TMPDIR on some
# platforms (observed on macOS), which fails closed in a sandbox whose
# writable allowlist does not include that OS default. An explicit template
# under $TMPDIR avoids that mismatch. A failing mktemp here still fails
# closed on its own: each assignment below is a plain top-level command
# substitution under `set -euo pipefail`, so a failure aborts the script
# immediately (verified: `set -e` triggers on a failing `x="$(false)"`
# assignment even with no surrounding `||`/`if`) rather than continuing with
# an empty path.
valid_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-valid-out.XXXXXX")"
valid_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-valid-err.XXXXXX")"
bf_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-bf-out.XXXXXX")"
bf_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-bf-err.XXXXXX")"
flag_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-flag-out.XXXXXX")"
flag_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-flag-err.XXXXXX")"
crlf_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-crlf-out.XXXXXX")"
crlf_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-crlf-err.XXXXXX")"
ws_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-ws-out.XXXXXX")"
ws_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-ws-err.XXXXXX")"
tab_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-tab-out.XXXXXX")"
tab_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-tab-err.XXXXXX")"
trap 'rm -f "$valid_out" "$valid_err" "$bf_out" "$bf_err" "$flag_out" "$flag_err" "$crlf_out" "$crlf_err" "$ws_out" "$ws_err" "$tab_out" "$tab_err"' EXIT

# AC4: valid fixture exits 0. The fixture also includes T-103 with a
# backtick-wrapped uppercase token in the title (`API`/`URL`) — that line
# linting clean is the M1 regression guard.
set +e
bash "$SCRIPT" "$FIX/valid.md" >"$valid_out" 2>"$valid_err"
valid_rc=$?
set -e
[[ "$valid_rc" -eq 0 ]] || fail "valid fixture expected exit 0, got $valid_rc (stderr: $(cat "$valid_err"))"
# shellcheck disable=SC2016
grep -q '`API`' "$FIX/valid.md" || fail "valid.md no longer contains the M1 regression guard line (backtick-uppercase title)"
printf 'PASS: AC4 valid.md exits 0 (M1 regression: backtick-uppercase title in T-103 lints clean)\n'

# AC2: bad-format exits non-zero, stderr names the offending line number.
# Derive the expected line number from the fixture's INTENTIONAL_BAD_LINE
# marker so re-ordering the fixture does not silently break the test.
bad_line="$(grep -nE 'INTENTIONAL_BAD_LINE' "$FIX/bad-format.md" | cut -d: -f1)"
[[ -n "$bad_line" ]] || fail "bad-format.md missing INTENTIONAL_BAD_LINE marker"
set +e
bash "$SCRIPT" "$FIX/bad-format.md" >"$bf_out" 2>"$bf_err"
bf_rc=$?
set -e
[[ "$bf_rc" -ne 0 ]] || fail "bad-format expected non-zero exit, got 0"
grep -q 'format mismatch' "$bf_err" || fail "bad-format stderr missing 'format mismatch' (got: $(cat "$bf_err"))"
grep -Eq ":${bad_line}:" "$bf_err" || fail "bad-format stderr missing line number ${bad_line} (got: $(cat "$bf_err"))"
printf 'PASS: AC2 bad-format.md exits %s, stderr names line %s\n' "$bf_rc" "$bad_line"

# AC3: bad-flag exits non-zero, stderr names the offending flag string.
# The fixture also includes T-303 with a lowercase `ready_for_eng` flag —
# that being reported as "unknown status flag 'ready_for_eng'" (and NOT
# "format mismatch") is the M2 regression guard.
set +e
bash "$SCRIPT" "$FIX/bad-flag.md" >"$flag_out" 2>"$flag_err"
flag_rc=$?
set -e
[[ "$flag_rc" -ne 0 ]] || fail "bad-flag expected non-zero exit, got 0"
grep -q 'unknown status flag' "$flag_err" || fail "bad-flag stderr missing 'unknown status flag' (got: $(cat "$flag_err"))"
grep -q 'READY_FOR_DEPLOY' "$flag_err" || fail "bad-flag stderr missing 'READY_FOR_DEPLOY' (got: $(cat "$flag_err"))"
printf 'PASS: AC3 bad-flag.md exits %s, stderr names READY_FOR_DEPLOY\n' "$flag_rc"

# M2 regression guard: the lowercase-flag line must be classified as
# "unknown status flag 'ready_for_eng'", NOT "format mismatch".
grep -q "unknown status flag 'ready_for_eng'" "$flag_err" \
  || fail "M2 regression: lowercase flag line not classified as 'unknown status flag' (got: $(cat "$flag_err"))"
# And explicitly: the lowercase line must NOT be reported as a format mismatch.
if grep -E ':[0-9]+: format mismatch.*ready_for_eng' "$flag_err" >/dev/null; then
  fail "M2 regression: lowercase flag line was misclassified as 'format mismatch' (got: $(cat "$flag_err"))"
fi
printf "PASS: M2 regression — lowercase 'ready_for_eng' classified as 'unknown status flag', not 'format mismatch'\n"

# CRLF tolerance: a Windows-EOL fixture must lint clean.
set +e
bash "$SCRIPT" "$FIX/valid-crlf.md" >"$crlf_out" 2>"$crlf_err"
crlf_rc=$?
set -e
[[ "$crlf_rc" -eq 0 ]] || fail "valid-crlf expected exit 0, got $crlf_rc (stderr: $(cat "$crlf_err"))"
printf 'PASS: CRLF tolerance — valid-crlf.md (CRLF line endings) lints clean\n'

# T-002 AC2: whitespace-only title is rejected as 'format mismatch'.
# The fixture's INTENTIONAL_BAD_LINE marker sits on the line *above* the bad
# line (the bad line itself must remain syntactically minimal — only the
# whitespace-only title distinguishes it from a valid entry), so derive the
# expected line number as marker-line + 1.
ws_marker_line="$(grep -nE 'INTENTIONAL_BAD_LINE' "$FIX/whitespace-title.md" | cut -d: -f1)"
[[ -n "$ws_marker_line" ]] || fail "whitespace-title.md missing INTENTIONAL_BAD_LINE marker"
ws_bad_line=$((ws_marker_line + 1))
set +e
bash "$SCRIPT" "$FIX/whitespace-title.md" >"$ws_out" 2>"$ws_err"
ws_rc=$?
set -e
[[ "$ws_rc" -ne 0 ]] || fail "whitespace-title expected non-zero exit, got 0"
grep -q 'format mismatch' "$ws_err" || fail "whitespace-title stderr missing 'format mismatch' (got: $(cat "$ws_err"))"
grep -Eq ":${ws_bad_line}:" "$ws_err" || fail "whitespace-title stderr missing line number ${ws_bad_line} (got: $(cat "$ws_err"))"
printf 'PASS - whitespace title rejected (exit %s, line %s reported as format mismatch)\n' "$ws_rc" "$ws_bad_line"

# T-002 AC3: a tab-indented sub-bullet under a valid Active entry is treated
# as a sub-bullet (skipped), not re-evaluated as a malformed top-level line.
# Regression guard for the IFS-coalesce bug in the parse loop.
set +e
bash "$SCRIPT" "$FIX/tab-subbullet.md" >"$tab_out" 2>"$tab_err"
tab_rc=$?
set -e
[[ "$tab_rc" -eq 0 ]] || fail "tab-subbullet expected exit 0, got $tab_rc (stderr: $(cat "$tab_err"))"
[[ ! -s "$tab_err" ]] || fail "tab-subbullet expected empty stderr, got: $(cat "$tab_err")"
printf 'PASS - tab sub-bullet accepted (exit 0, no stderr)\n'

printf 'OK\n'
exit 0
