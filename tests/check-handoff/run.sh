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
strand_top_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-top-out.XXXXXX")"
strand_top_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-top-err.XXXXXX")"
strand_bound_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-bound-out.XXXXXX")"
strand_bound_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-bound-err.XXXXXX")"
strand_tol_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-tol-out.XXXXXX")"
strand_tol_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-tol-err.XXXXXX")"
strand_crlf_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-crlf-out.XXXXXX")"
strand_crlf_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-crlf-err.XXXXXX")"
strand_crlf_fix="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-crlf-fix.XXXXXX")"
strand_clean_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-clean-out.XXXXXX")"
strand_clean_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-strand-clean-err.XXXXXX")"
decoy_bad_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-decoy-bad-out.XXXXXX")"
decoy_bad_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-decoy-bad-err.XXXXXX")"
decoy_good_out="$(mktemp "${TMPDIR:-/tmp}/check-handoff-decoy-good-out.XXXXXX")"
decoy_good_err="$(mktemp "${TMPDIR:-/tmp}/check-handoff-decoy-good-err.XXXXXX")"
trap 'rm -f "$valid_out" "$valid_err" "$bf_out" "$bf_err" "$flag_out" "$flag_err" "$crlf_out" "$crlf_err" "$ws_out" "$ws_err" "$tab_out" "$tab_err" "$strand_top_out" "$strand_top_err" "$strand_bound_out" "$strand_bound_err" "$strand_tol_out" "$strand_tol_err" "$strand_crlf_out" "$strand_crlf_err" "$strand_crlf_fix" "$strand_clean_out" "$strand_clean_err" "$decoy_bad_out" "$decoy_bad_err" "$decoy_good_out" "$decoy_good_err"' EXIT

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

# D4 / Codex round-1 Blocker regression lock: a malformed top-level line
# (checkbox shape, no space after the closing bracket) must still open an
# entry, so its own continuation lines — including one separated by a blank
# line, and one non-dash shape (a table row) — are never misreported as
# strands. Two variants, mirroring the Blocker's two measured cases:
# unchecked (`- [ ]...`, format-validated, reported once) and checked
# (`- [x]...`, never format-validated at all, so no message of its own).
# The spec's Body-to-AC correspondence table names this exact fixture as the
# guard against a strand-message cascade under a malformed line — until this
# lock, that guard was vacuous (no continuation lines existed to cascade).
nospace_unchecked_line="$(grep -nE 'INTENTIONAL_NOSPACE_UNCHECKED' "$FIX/bad-format.md" | cut -d: -f1)"
nospace_checked_line="$(grep -nE 'INTENTIONAL_NOSPACE_CHECKED' "$FIX/bad-format.md" | cut -d: -f1)"
[[ -n "$nospace_unchecked_line" ]] || fail "bad-format.md missing INTENTIONAL_NOSPACE_UNCHECKED marker"
[[ -n "$nospace_checked_line" ]] || fail "bad-format.md missing INTENTIONAL_NOSPACE_CHECKED marker"
grep -Eq ":${nospace_unchecked_line}: format mismatch" "$bf_err" \
  || fail "bad-format: the unchecked no-space-after-bracket line (${nospace_unchecked_line}) must be reported as format mismatch (got: $(cat "$bf_err"))"
if grep -Eq ":${nospace_checked_line}:" "$bf_err"; then
  fail "bad-format: the checked no-space-after-bracket line (${nospace_checked_line}) must produce NO message of its own (checked lines are never format-validated), got: $(cat "$bf_err")"
fi
if grep -q 'stranded continuation line' "$bf_err"; then
  fail "bad-format: a malformed top-level line must open an entry — its own continuation lines (including the one after a blank line, and the table-row shape) must never be misreported as strands, got: $(cat "$bf_err")"
fi
bf_violation_count="$(grep -c . "$bf_err")"
[[ "$bf_violation_count" -eq 2 ]] \
  || fail "bad-format: expected exactly 2 total violations (the two malformed top-level lines, one message each — one defect, one message, D4), got $bf_violation_count: $(cat "$bf_err")"
printf 'PASS: D4/Blocker regression lock — a malformed checkbox-shaped line with no space after the bracket still opens an entry (unchecked: exactly one format-mismatch message, zero strand cascade; checked: zero messages at all); exact violation set asserted (2 total)\n'

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

# ============================================================================
# T-1016: board-entry continuation canon + the strand check (D4).
# ============================================================================

# strand-top-of-section: a continuation line at the very top of ## Active,
# with no task entry above it, is a strand (exit 1, frozen reason string).
set +e
bash "$SCRIPT" "$FIX/strand-top.md" >"$strand_top_out" 2>"$strand_top_err"
strand_top_rc=$?
set -e
[[ "$strand_top_rc" -eq 1 ]] || fail "strand-top-of-section: expected exit 1, got $strand_top_rc (stderr: $(cat "$strand_top_err"))"
grep -qF -- ':5: stranded continuation line (no task entry above it in this section):' "$strand_top_err" \
  || fail "strand-top-of-section: stderr missing the frozen reason string at line 5 (got: $(cat "$strand_top_err"))"
printf 'PASS: strand-top-of-section — a continuation line at the top of ## Active with no task entry above it is reported (exit 1)\n'

# strand-reports-line-number: same fixture, the reported line number is
# exactly the stranded line's own line number (5), not an off-by-one.
grep -qE '^[^:]+:5: stranded continuation line' "$strand_top_err" \
  || fail "strand-reports-line-number: expected the violation anchored at line 5 (got: $(cat "$strand_top_err"))"
printf 'PASS: strand-reports-line-number — the reported line number is the stranded lines own line, not an approximation\n'

# strand-after-placeholder / strand-after-prose / strand-after-subheading /
# strand-after-cm-bullet: a continuation line after each of the four
# boundary shapes that are NOT task lines is its own strand, at its own line.
set +e
bash "$SCRIPT" "$FIX/strand-boundaries.md" >"$strand_bound_out" 2>"$strand_bound_err"
strand_bound_rc=$?
set -e
[[ "$strand_bound_rc" -eq 1 ]] || fail "strand-boundaries: expected exit 1, got $strand_bound_rc (stderr: $(cat "$strand_bound_err"))"
strand_bound_n="$(grep -oF -- 'stranded continuation line' "$strand_bound_err" | grep -c .)"
[[ "$strand_bound_n" -eq 4 ]] || fail "strand-boundaries: expected exactly 4 strand violations, got $strand_bound_n (stderr: $(cat "$strand_bound_err"))"
grep -qF -- ':6: stranded continuation line' "$strand_bound_err" \
  || fail "strand-after-placeholder: expected a strand at line 6 (got: $(cat "$strand_bound_err"))"
# shellcheck disable=SC2016  # backticks are literal prose, not expansion
printf 'PASS: strand-after-placeholder — a continuation line after the `_(none)_` placeholder is a strand (placeholder opens no entry)\n'
grep -qF -- ':9: stranded continuation line' "$strand_bound_err" \
  || fail "strand-after-prose: expected a strand at line 9 (got: $(cat "$strand_bound_err"))"
printf 'PASS: strand-after-prose — a continuation line after bare prose is a strand\n'
grep -qF -- ':11: stranded continuation line' "$strand_bound_err" \
  || fail "strand-after-subheading: expected a strand at line 11 (got: $(cat "$strand_bound_err"))"
# shellcheck disable=SC2016  # backticks are literal prose, not expansion
printf 'PASS: strand-after-subheading — a continuation line after a `### ` sub-heading is a strand\n'
grep -qF -- ':13: stranded continuation line' "$strand_bound_err" \
  || fail "strand-after-cm-bullet: expected a strand at line 13 (got: $(cat "$strand_bound_err"))"
# shellcheck disable=SC2016  # backticks are literal prose, not expansion
printf 'PASS: strand-after-cm-bullet — a continuation line after a CommonMark `* [ ]` bullet is a strand (round3 defect class re-asserted at this sibling site)\n'

# strand-accepts-internal-blank / strand-accepts-table-row /
# strand-accepts-whitespace-only / strand-accepts-tab-indent: every shape the
# old dash-led predicate mishandled is accepted inside a real entry, exit 0,
# no stderr.
grep -qF -- '  | a | b |' "$FIX/strand-tolerant.md" \
  || fail "strand-accepts-table-row: fixture setup — the table row must actually be present in strand-tolerant.md"
set +e
bash "$SCRIPT" "$FIX/strand-tolerant.md" >"$strand_tol_out" 2>"$strand_tol_err"
strand_tol_rc=$?
set -e
[[ "$strand_tol_rc" -eq 0 ]] || fail "strand-accepts-*: expected exit 0, got $strand_tol_rc (stderr: $(cat "$strand_tol_err"))"
[[ ! -s "$strand_tol_err" ]] || fail "strand-accepts-*: expected empty stderr, got: $(cat "$strand_tol_err")"
printf 'PASS: strand-accepts-internal-blank — a blank line between two continuation lines does not end the entry\n'
printf 'PASS: strand-accepts-table-row — an indented table row (non-dash first character) continues the entry\n'
printf 'PASS: strand-accepts-whitespace-only — a whitespace-only line is blank (neutral), not a boundary\n'
printf 'PASS: strand-accepts-tab-indent — a tab-indented sub-bullet continues the entry\n'

# strand-accepts-crlf: the same tolerant board, CRLF line endings (produced
# with awk, not a sed `\r` replacement — that replacement is not portable).
awk '{ printf "%s\r\n", $0 }' "$FIX/strand-tolerant.md" > "$strand_crlf_fix"
set +e
bash "$SCRIPT" "$strand_crlf_fix" >"$strand_crlf_out" 2>"$strand_crlf_err"
strand_crlf_rc=$?
set -e
[[ "$strand_crlf_rc" -eq 0 ]] || fail "strand-accepts-crlf: expected exit 0, got $strand_crlf_rc (stderr: $(cat "$strand_crlf_err"))"
[[ ! -s "$strand_crlf_err" ]] || fail "strand-accepts-crlf: expected empty stderr, got: $(cat "$strand_crlf_err")"
printf 'PASS: strand-accepts-crlf — the same tolerant board, CRLF-terminated, still lints clean\n'

# strand-clean-board-positive-control: the shipped board template still
# lints clean under the strengthened linter, so the strand check cannot be
# passing by rejecting everything.
set +e
bash "$SCRIPT" "$REPO_ROOT/templates/todo-template.md" >"$strand_clean_out" 2>"$strand_clean_err"
strand_clean_rc=$?
set -e
[[ "$strand_clean_rc" -eq 0 ]] || fail "strand-clean-board-positive-control: expected the shipped template to lint clean, got $strand_clean_rc (stderr: $(cat "$strand_clean_err"))"
printf 'PASS: strand-clean-board-positive-control — the shipped board template still lints clean under the strengthened linter\n'

# ============================================================================
# T-1031 (GitHub #122): decoy-separator resolution (D1) — a title carrying a
# full decoy `` — `<token>` — spec: <path>.md `` sequence is judged, for BOTH
# shape and flag, against the LAST such slot on the line — the same slot
# bin/close-out.sh's rewrite regex already resolves.
# ============================================================================

# decoy-real-flag-invalid: false-PASS direction closed. The title's decoy
# slot holds a valid-looking flag token; the REAL (last) slot holds an
# unknown one. That unknown flag is what gets reported — not the decoy, and
# not a format mismatch — with exactly one violation on the whole fixture.
decoy_bad_line="$(grep -nF -- 'T1031_DECOY_BAD' "$FIX/decoy-real-flag-invalid.md" | cut -d: -f1)"
[[ -n "$decoy_bad_line" ]] || fail "decoy-real-flag-invalid.md missing the T1031_DECOY_BAD marker"
set +e
bash "$SCRIPT" "$FIX/decoy-real-flag-invalid.md" >"$decoy_bad_out" 2>"$decoy_bad_err"
decoy_bad_rc=$?
set -e
[[ "$decoy_bad_rc" -eq 1 ]] || fail "decoy-real-flag-invalid: expected exit 1, got $decoy_bad_rc (stderr: $(cat "$decoy_bad_err"))"
grep -qF -- "unknown status flag 'T1031_DECOY_BAD'" "$decoy_bad_err" \
  || fail "decoy-real-flag-invalid: stderr missing \"unknown status flag 'T1031_DECOY_BAD'\" (got: $(cat "$decoy_bad_err"))"
grep -Eq ":${decoy_bad_line}:" "$decoy_bad_err" \
  || fail "decoy-real-flag-invalid: stderr missing line number ${decoy_bad_line} (got: $(cat "$decoy_bad_err"))"
if grep -q 'format mismatch' "$decoy_bad_err"; then
  fail "decoy-real-flag-invalid: the false-PASS direction must not also report a format mismatch, got: $(cat "$decoy_bad_err")"
fi
decoy_bad_count="$(grep -c . "$decoy_bad_err")"
[[ "$decoy_bad_count" -eq 1 ]] \
  || fail "decoy-real-flag-invalid: expected exactly 1 violation total, got $decoy_bad_count: $(cat "$decoy_bad_err")"
printf 'PASS: T-1031 decoy-real-flag-invalid — false-PASS direction closed (the decoy title token lints clean; the real last slot'"'"'s unknown flag is reported; exactly one violation total)\n'

# decoy-real-flag-valid: false-FAIL direction closed. The title's decoy slot
# holds an invalid-looking flag token; the REAL (last) slot holds an allowed
# one. The line lints clean — the decoy is not mistaken for the flag.
grep -qF -- 'T1031_DECOY_BAD' "$FIX/decoy-real-flag-valid.md" \
  || fail "decoy-real-flag-valid.md missing the T1031_DECOY_BAD decoy token"
set +e
bash "$SCRIPT" "$FIX/decoy-real-flag-valid.md" >"$decoy_good_out" 2>"$decoy_good_err"
decoy_good_rc=$?
set -e
[[ "$decoy_good_rc" -eq 0 ]] || fail "decoy-real-flag-valid: expected exit 0, got $decoy_good_rc (stderr: $(cat "$decoy_good_err"))"
[[ ! -s "$decoy_good_err" ]] || fail "decoy-real-flag-valid: expected empty stderr, got: $(cat "$decoy_good_err")"
printf 'PASS: T-1031 decoy-real-flag-valid — false-FAIL direction closed (a decoy title token does not block a well-formed real slot; lints clean)\n'

printf 'OK\n'
exit 0
