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

# A free-form field ending in a trailing backslash (jesc renders it as a
# valid `\\` escape) must not be misread as an escaped closing quote, on
# EITHER shape — the escaped-backslash-pairs-before-escaped-quotes parity
# fix (Codex round-1 Major #2, pre-existing bug this task's expanded
# free-form-field surface made worth fixing in this round).
set +e
bash "$LOG" shell-team --run-id r-test --seq 6 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status error --error $'ends in a backslash \\' >/dev/null 2>&1
tb_span_rc=$?
set -e
[[ "$tb_span_rc" -eq 0 ]] || fail "log-run span --error trailing-backslash invocation expected exit 0, got $tb_span_rc"
bash "$CHECK" "$TMP/shell-team.jsonl" >/dev/null 2>&1 \
  || fail "log-run span --error trailing-backslash row failed check-run lint (Major #2 regression)"
printf 'PASS: log-run span --error ending in a trailing backslash stays check-run-clean\n'

# --line direct forms: a trailing-backslash value passes on both shapes; a
# genuinely truncated/unbalanced line still fails (the fix must not weaken
# real truncation detection).
assert_line "--line span row, label-shaped field ending in a trailing backslash -> 0" 0 \
  '{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","span":"engineer","phase":"implement","iteration":1,"attempt":1,"status":"error","model":null,"tokens":null,"tool_uses":null,"duration_ms":null,"verdict":null,"usd":null,"error":"ends in \\","parent_span_id":null}'
assert_line "--line event row, label ending in a trailing backslash -> 0" 0 \
  '{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","kind":"event","event":"human","from":null,"to":null,"label":"ends in \\"}'
assert_line "--line genuinely truncated string (real unbalanced quotes) still -> 1" 1 \
  '{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","kind":"event","event":"human","from":null,"to":null,"label":"truncated}' \
  "unbalanced double-quotes"

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

# =====================================================================
# T-1011: event rows — writer (log-run.sh --event) and checker coverage.
# =====================================================================

EVENTS_DIR="$TMP/events"
mkdir -p "$EVENTS_DIR"

# --- writer: the frozen 9-key event row shape, check-run-clean ---
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 1 --event handoff --from specify --to implement >/dev/null 2>&1
ev_rc=$?
set -e
[[ "$ev_rc" -eq 0 ]] || fail "log-run --event handoff expected exit 0, got $ev_rc"
[[ -f "$EVENTS_DIR/evloop.jsonl" ]] || fail "log-run --event did not create evloop.jsonl"
[[ "$(wc -l < "$EVENTS_DIR/evloop.jsonl")" -eq 1 ]] || fail "log-run --event did not append exactly 1 line"
ev_keys="$(grep -oE '"[a-z_]+":' "$EVENTS_DIR/evloop.jsonl" | tr -d '":' | tr '\n' ' ')"
[[ "$ev_keys" == "loop_id run_id seq ts kind event from to label " ]] \
  || fail "log-run --event wrote unexpected key order: $ev_keys"
grep -qF -- '"kind":"event"' "$EVENTS_DIR/evloop.jsonl" || fail "log-run --event row missing kind:event"
bash "$CHECK" "$EVENTS_DIR/evloop.jsonl" >/dev/null 2>&1 || fail "log-run --event row failed check-run lint"
printf 'PASS: log-run --event handoff appends the frozen 9-key row, check-run-clean\n'

# --- writer: a zero-flag invocation (<loop_id> only, no flags at all) is the
# documented usage-error exit 2, not a bash-3.2 unbound-variable crash (exit
# 1) from expanding "${SEEN[@]}" on a genuinely empty array (Codex round-1
# Major #1) — verified under BOTH the PATH bash and /bin/bash explicitly. ---
set +e
zf_err_path="$(RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop 2>&1 >/dev/null)"
zf_rc_path=$?
zf_err_binbash="$(RUNS_DIR="$EVENTS_DIR" /bin/bash "$LOG" evloop 2>&1 >/dev/null)"
zf_rc_binbash=$?
set -e
[[ "$zf_rc_path" -eq 2 ]] || fail "log-run <loop_id> (no flags) under PATH bash expected exit 2, got $zf_rc_path (stderr: $zf_err_path)"
[[ "$zf_rc_binbash" -eq 2 ]] || fail "log-run <loop_id> (no flags) under /bin/bash expected exit 2, got $zf_rc_binbash (stderr: $zf_err_binbash)"
printf '%s' "$zf_err_path" | grep -qF -- 'unbound variable' && fail "log-run <loop_id> (no flags) leaked a bash-3.2 unbound-variable crash under PATH bash"
printf '%s' "$zf_err_binbash" | grep -qF -- 'unbound variable' && fail "log-run <loop_id> (no flags) leaked a bash-3.2 unbound-variable crash under /bin/bash"
printf 'PASS: log-run <loop_id> with zero flags exits 2 (usage error) under both PATH bash and /bin/bash, no unbound-variable crash\n'

# --- writer: --event and --span are mutually exclusive (frozen message) ---
set +e
mux_err="$(RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 2 --event handoff --from a --to b --span engineer 2>&1 >/dev/null)"
mux_rc=$?
set -e
[[ "$mux_rc" -eq 2 ]] || fail "log-run --event with --span expected exit 2, got $mux_rc"
grep -qF -- '--event and --span are mutually exclusive' <<< "$mux_err" \
  || fail "log-run --event+--span missing the frozen mutual-exclusion message"
printf 'PASS: log-run --event and --span are mutually exclusive (exit 2, frozen message)\n'

# --- writer: an unknown --event value is a usage error, nothing written ---
before_ev="$(wc -l < "$EVENTS_DIR/evloop.jsonl")"
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 3 --event bogus --from a --to b >/dev/null 2>&1
bogus_rc=$?
set -e
[[ "$bogus_rc" -eq 2 ]] || fail "log-run --event bogus expected exit 2, got $bogus_rc"
after_ev="$(wc -l < "$EVENTS_DIR/evloop.jsonl")"
[[ "$before_ev" -eq "$after_ev" ]] || fail "log-run --event bogus wrote a row despite invalid --event"
printf 'PASS: log-run --event bogus exits 2 and writes nothing\n'

# --- writer: a span-only flag is forbidden in event mode ---
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 4 --event handoff --from a --to b --phase implement >/dev/null 2>&1
spanonly_rc=$?
set -e
[[ "$spanonly_rc" -eq 2 ]] || fail "log-run --event with --phase expected exit 2, got $spanonly_rc"
printf 'PASS: log-run rejects a span-only flag (--phase) in event mode (exit 2)\n'

# --- writer: --from/--to/--label are forbidden in span mode ---
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 5 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success --from a >/dev/null 2>&1
fromspan_rc=$?
set -e
[[ "$fromspan_rc" -eq 2 ]] || fail "log-run --from in span mode expected exit 2, got $fromspan_rc"
printf 'PASS: log-run rejects --from in span mode (exit 2)\n'

# --- writer: per-type requiredness — rework with no --label writes nothing ---
before_ev2="$(wc -l < "$EVENTS_DIR/evloop.jsonl")"
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" evloop --run-id R1 --seq 6 --event rework --from a --to b >/dev/null 2>&1
rework_rc=$?
set -e
[[ "$rework_rc" -eq 2 ]] || fail "log-run --event rework with no --label expected exit 2, got $rework_rc"
after_ev2="$(wc -l < "$EVENTS_DIR/evloop.jsonl")"
[[ "$before_ev2" -eq "$after_ev2" ]] || fail "log-run --event rework wrote a row despite missing --label"
printf 'PASS: log-run --event rework requires --label (exit 2, nothing written)\n'

# --- writer: nullable event fields render as explicit null and lint clean ---
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" relloop --run-id R1 --seq 1 --event release >/dev/null 2>&1
rel_rc=$?
set -e
[[ "$rel_rc" -eq 0 ]] || fail "log-run --event release expected exit 0, got $rel_rc"
grep -qF -- '"from":null,"to":null,"label":null' "$EVENTS_DIR/relloop.jsonl" \
  || fail "log-run --event release did not render nullable fields as explicit null"
bash "$CHECK" "$EVENTS_DIR/relloop.jsonl" >/dev/null 2>&1 || fail "log-run --event release row failed check-run lint"
printf 'PASS: log-run --event release nullable fields render as JSON null, check-run-clean\n'

# --- writer: an event --label ending in a trailing backslash round-trips
# clean (Codex round-1 Major #2 — event rows have three free-form fields
# vs. the span side's one, so this shape's exposure is real). ---
set +e
RUNS_DIR="$EVENTS_DIR" bash "$LOG" tbloop --run-id R1 --seq 1 --event human --label $'ends in a backslash \\' >/dev/null 2>&1
tb_event_rc=$?
set -e
[[ "$tb_event_rc" -eq 0 ]] || fail "log-run event --label trailing-backslash invocation expected exit 0, got $tb_event_rc"
bash "$CHECK" "$EVENTS_DIR/tbloop.jsonl" >/dev/null 2>&1 \
  || fail "log-run event --label trailing-backslash row failed check-run lint (Major #2 regression)"
printf 'PASS: log-run event --label ending in a trailing backslash stays check-run-clean\n'

# --- checker: the committed mixed/unknown-id fixtures (AC11/AC12) ---
assert_check "valid-events.jsonl -> 0"          0 "$FIX/valid-events.jsonl"
assert_check "fail-event-unknown-id.jsonl -> 1" 1 "$FIX/fail-event-unknown-id.jsonl" "invalid event '"

# --- checker: `kind` discriminates shape; shape mixing fails closed both ways ---
VALID_SPAN_LINE="$(head -n1 "$FIX/valid.jsonl")"
assert_line "--line kind:span behaves like kind-less" 0 \
  "$(printf '%s' "$VALID_SPAN_LINE" | sed 's/^{/{"kind":"span",/')"
assert_line "--line kind:bogus -> 1" 1 \
  "$(printf '%s' "$VALID_SPAN_LINE" | sed 's/^{/{"kind":"bogus",/')" "invalid kind 'bogus'"
assert_line "--line kind:null -> 1" 1 \
  "$(printf '%s' "$VALID_SPAN_LINE" | sed 's/^{/{"kind":null,/')" "kind must be a quoted enum value"
assert_line "--line span row carrying an event key -> 1" 1 \
  "$(printf '%s' "$VALID_SPAN_LINE" | sed 's/}$/,"event":"handoff"}/')" "span row carries event-only key: event"

EVENT_HANDOFF_LINE='{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","kind":"event","event":"handoff","from":"specify","to":"implement","label":null}'
assert_line "--line a valid event row -> 0" 0 "$EVENT_HANDOFF_LINE"
assert_line "--line event row carrying a span-only key -> 1" 1 \
  "$(printf '%s' "$EVENT_HANDOFF_LINE" | sed 's/}$/,"phase":"implement"}/')" 'event row carries span-only key\(s\): phase'
assert_line "--line unknown event id -> 1" 1 \
  '{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","kind":"event","event":"bogus","from":"a","to":"b","label":null}' \
  "invalid event 'bogus'"
assert_line "--line event missing required from -> 1" 1 \
  '{"loop_id":"L","run_id":"R","seq":1,"ts":"2026-08-01T00:00:01Z","kind":"event","event":"handoff","from":null,"to":"implement","label":null}' \
  "requires non-null from"

printf 'OK\n'
exit 0
