#!/usr/bin/env bash
# run.sh — drive bin/check-run.sh and bin/log-run.sh against fixtures and assert
# the documented behavior (T-015 acceptance criteria):
#   check-run: valid -> 0, bad-json -> 1, bad-verdict -> 1, missing key -> 1,
#              unreadable -> 2
#   log-run:   a valid invocation appends a row that check-run accepts; a
#              malformed invocation writes nothing and exits 2.
#
# T-042 (AC1) extends this suite with check-run.sh's `--line` single-line mode:
# same violation categories as file mode, reproduced against one line with
# zero file I/O (proven by feeding the exact same fixture lines through
# `--line` and asserting identical exit codes / stderr categories).
#
# Avoids mktemp (writes under $HERE/tmp-runs, cleaned via trap) so the suite
# runs in restricted sandboxes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="$REPO_ROOT/bin/check-run.sh"
LOG="$REPO_ROOT/bin/log-run.sh"
FIX="$HERE/fixtures"
TMP="$HERE/tmp-runs"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT

# assert_check <desc> <expected_rc> <file> [stderr_grep]
assert_check() {
  local desc="$1" exp="$2" file="$3" pat="${4:-}" err rc
  set +e
  err="$(bash "$CHECK" "$file" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [[ "$rc" -eq "$exp" ]] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [[ -z "$pat" ]] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  printf 'PASS: %s (exit %s)\n' "$desc" "$rc"
}

assert_check "valid.jsonl -> 0"            0 "$FIX/valid.jsonl"
assert_check "bad-json.jsonl -> 1"         1 "$FIX/bad-json.jsonl"            "not a JSON object line"
assert_check "bad-verdict.jsonl -> 1"      1 "$FIX/bad-verdict.jsonl"         "invalid verdict"
assert_check "missing-required.jsonl -> 1" 1 "$FIX/missing-required.jsonl"    "missing required key"
assert_check "unreadable -> 2"             2 "$FIX/does-not-exist.jsonl"
# Codex review regression guards:
assert_check "status:null -> 1 (not a quoted enum)" 1 "$FIX/status-null.jsonl" "status must be a quoted enum value"
assert_check "brace inside a string value -> 0"     0 "$FIX/brace-in-string.jsonl"
assert_check "truncated string -> 1 (unbalanced quotes)" 1 "$FIX/unbalanced.jsonl" "unbalanced double-quotes"

# --- AC1: `--line` single-line mode reproduces every file-mode violation
#         category, with zero file I/O (no file argument passed at all). ---

# assert_line <desc> <expected_rc> <line> [stderr_grep]
assert_line() {
  local desc="$1" exp="$2" line="$3" pat="${4:-}" err rc
  set +e
  err="$(bash "$CHECK" --line "$line" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [[ "$rc" -eq "$exp" ]] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [[ -z "$pat" ]] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  printf 'PASS: %s (exit %s)\n' "$desc" "$rc"
}

VALID_LINE="$(head -n1 "$FIX/valid.jsonl")"
BADJSON_LINE="$(head -n1 "$FIX/bad-json.jsonl")"
BADVERDICT_LINE="$(head -n1 "$FIX/bad-verdict.jsonl")"
MISSING_LINE="$(head -n1 "$FIX/missing-required.jsonl")"
STATUSNULL_LINE="$(head -n1 "$FIX/status-null.jsonl")"
BRACE_LINE="$(head -n1 "$FIX/brace-in-string.jsonl")"
UNBALANCED_LINE="$(head -n1 "$FIX/unbalanced.jsonl")"

assert_line "--line valid -> 0"                       0 "$VALID_LINE"
assert_line "--line bad-json -> 1"                    1 "$BADJSON_LINE"      "not a JSON object line"
assert_line "--line bad-verdict -> 1"                 1 "$BADVERDICT_LINE"   "invalid verdict"
assert_line "--line missing-required -> 1"            1 "$MISSING_LINE"      "missing required key"
assert_line "--line status:null -> 1"                 1 "$STATUSNULL_LINE"   "status must be a quoted enum value"
assert_line "--line brace-in-string -> 0"             0 "$BRACE_LINE"
assert_line "--line unbalanced (truncated) -> 1"      1 "$UNBALANCED_LINE"   "unbalanced double-quotes"
assert_line "--line an ad-hoc deliberately-malformed line -> 1" 1 \
  '{"loop_id":"x","run_id":"y"}' "missing required key"

# --line usage errors: missing value, and no mode arg at all is still file mode.
set +e
err="$(bash "$CHECK" --line 2>&1 >/dev/null)"
line_no_val_rc=$?
set -e
[[ "$line_no_val_rc" -eq 2 ]] || fail "--line with no value: expected exit 2, got $line_no_val_rc"
grep -qE "requires a value" <<< "$err" || fail "--line with no value: missing usage message (got: $err)"
printf 'PASS: --line with no value -> 2 (usage error)\n'

# --line mode never opens a file: prove it by cd-ing into an empty, unrelated
# read-only-looking dir with NO file named after the line's content and
# asserting the exact same result as running from the fixtures dir.
NOFILE_DIR="$TMP/no-file-here"
mkdir -p "$NOFILE_DIR"
( cd "$NOFILE_DIR" && bash "$CHECK" --line "$VALID_LINE" >/dev/null 2>&1 )
nofile_rc=$?
[[ "$nofile_rc" -eq 0 ]] || fail "--line mode should not depend on cwd/file presence, got $nofile_rc"
printf 'PASS: --line mode is file-I/O-free (cwd with no matching file still -> 0)\n'

# log-run round-trip: a valid append produces a check-run-clean file.
export RUNS_DIR="$TMP"
set +e
bash "$LOG" shell-team --run-id r-test --seq 1 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success --model opus --tokens 30308 \
  --tool-uses 1 --duration-ms 8363 >/dev/null 2>&1
lr_rc=$?
set -e
[[ "$lr_rc" -eq 0 ]] || fail "log-run valid invocation expected exit 0, got $lr_rc"
[[ -f "$TMP/shell-team.jsonl" ]] || fail "log-run did not create shell-team.jsonl"
[[ "$(wc -l < "$TMP/shell-team.jsonl")" -eq 1 ]] || fail "log-run did not append exactly 1 line"
bash "$CHECK" "$TMP/shell-team.jsonl" >/dev/null 2>&1 || fail "log-run output failed check-run lint"
printf 'PASS: log-run valid invocation appends a check-run-clean row\n'

# log-run with a null-bearing span (no tokens/verdict) still lints clean.
set +e
bash "$LOG" shell-team --run-id r-test --seq 2 --span codex-reviewer --phase review \
  --iteration 1 --attempt 1 --status stopped --error "codex unavailable" >/dev/null 2>&1
lr2_rc=$?
set -e
[[ "$lr2_rc" -eq 0 ]] || fail "log-run null-field invocation expected exit 0, got $lr2_rc"
bash "$CHECK" "$TMP/shell-team.jsonl" >/dev/null 2>&1 || fail "log-run null-field output failed check-run lint"
[[ "$(wc -l < "$TMP/shell-team.jsonl")" -eq 2 ]] || fail "second append did not produce 2 lines"
printf 'PASS: log-run null-field span appends a clean row (graceful nulls)\n'

# log-run fail-closed: bad status writes nothing and exits 2.
before="$(wc -l < "$TMP/shell-team.jsonl")"
set +e
bash "$LOG" shell-team --run-id r-test --seq 3 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status bogus >/dev/null 2>&1
bad_rc=$?
set -e
[[ "$bad_rc" -eq 2 ]] || fail "log-run bad --status expected exit 2, got $bad_rc"
after="$(wc -l < "$TMP/shell-team.jsonl")"
[[ "$before" -eq "$after" ]] || fail "log-run wrote a row despite invalid input (before=$before after=$after)"
printf 'PASS: log-run bad --status exits 2 and writes nothing\n'

# log-run escapes (does not drop) quotes/backslashes in free-form fields, and
# the resulting row still lints clean (Codex SB1 regression guard).
set +e
bash "$LOG" shell-team --run-id r-test --seq 4 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status error --error 'say "hi" and a \ slash' >/dev/null 2>&1
esc_rc=$?
set -e
[[ "$esc_rc" -eq 0 ]] || fail "log-run escaped-field invocation expected exit 0, got $esc_rc"
bash "$CHECK" "$TMP/shell-team.jsonl" >/dev/null 2>&1 || fail "log-run escaped-field output failed check-run lint"
grep -q '\\"hi\\"' "$TMP/shell-team.jsonl" || fail "log-run did not escape embedded quotes (content not preserved)"
printf 'PASS: log-run escapes embedded quotes/backslashes and stays check-run-clean\n'

# log-run fail-closed: non-numeric --tokens writes nothing and exits 2.
before2="$(wc -l < "$TMP/shell-team.jsonl")"
set +e
bash "$LOG" shell-team --run-id r-test --seq 5 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success --tokens abc >/dev/null 2>&1
tok_rc=$?
set -e
[[ "$tok_rc" -eq 2 ]] || fail "log-run non-numeric --tokens expected exit 2, got $tok_rc"
after2="$(wc -l < "$TMP/shell-team.jsonl")"
[[ "$before2" -eq "$after2" ]] || fail "log-run wrote a row despite non-numeric --tokens"
printf 'PASS: log-run non-numeric --tokens exits 2 and writes nothing\n'

printf 'OK\n'
exit 0
