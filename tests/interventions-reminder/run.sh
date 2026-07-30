#!/usr/bin/env bash
# run.sh — drive docs/interventions-reminder-hook.sample.sh against synthetic
# cwd fixtures and assert the two-outcome contract documented in
# .shell-team/specs/T-1004-optin-hook-sample.md: an in-flight board emits the
# fixed one-line reminder payload, and every other reachable state (absent
# board, no in-flight line, an unreachable resolver, an unreadable/directory
# board path, malformed stdin) is a byte-empty, silent, exit-0 no-op.
#
# Twelve case classes, counted via case_start() below and pinned against
# CASES_EXPECTED — a thirteenth case added without updating this file's own
# count fails the suite rather than passing silently. Every case asserts exit
# status, stdout AND stderr, so a case can no longer pass on exit code alone
# (the "wrong-but-nonzero must not look like success" fixture-synthesis
# discipline tests/check-interventions/run.sh already follows, adapted here to
# a script whose only correct exit code is ever 0).
#
#   docs/interventions-reminder-hook.sample.sh — case: an in-flight board emits the exact reminder payload and nothing else
#   docs/interventions-reminder-hook.sample.sh — case: no board at all -> silent no-op (empty stdout, empty stderr, exit 0)
#   docs/interventions-reminder-hook.sample.sh — case: a board with only - [x] Done lines carrying flags -> silent no-op
#   docs/interventions-reminder-hook.sample.sh — case: a CRLF board with an in-flight line still emits the payload
#   docs/interventions-reminder-hook.sample.sh — case: the legacy tasks/ layout is resolved, not hardcoded
#   docs/interventions-reminder-hook.sample.sh — case: garbage on stdin changes nothing (the event is never parsed)
#   docs/interventions-reminder-hook.sample.sh — case: the prompt field is never echoed into the emitted context
#   docs/interventions-reminder-hook.sample.sh — case: the resolver missing from PATH -> silent no-op
#   docs/interventions-reminder-hook.sample.sh — case: an unreadable board -> silent no-op, never a diagnostic
#   docs/interventions-reminder-hook.sample.sh — case: the board path being a directory -> silent no-op
#   docs/interventions-reminder-hook.sample.sh — case: a non-conforming - [ ] line is not in flight
#   docs/interventions-reminder-hook.sample.sh — case: two in-flight lines emit exactly one reminder
#
# Fixtures use synthetic task id T-1004 (this task's own real id, quoted only
# as fixture content — never the repository's own live board) and are built
# fresh in a temp dir per case — no static fixtures/ directory needed. Temp
# roots live under $TMPDIR when set (restricted sandboxes); every mktemp call
# uses an explicit "${TMPDIR:-/tmp}/...XXXXXX" template (2026-06-16 /
# 2026-07-19 lessons: a bare mktemp ignores TMPDIR and fails in-sandbox on
# this platform).
#
# The bare-name resolver shim is the anti-vacuity device (Notes for engineer,
# T-1004 spec): the sample has NO bin/-relative fallback, so if
# `team-paths.sh` were not reachable on PATH, every case below would silently
# no-op — including the emit cases — for the wrong reason. `command -v
# team-paths.sh` is asserted under the modified PATH before every case that
# expects an emission, and before every case where the board itself (not the
# resolver) must be the cause of the silence.

set -euo pipefail

# An inherited BASH_ENV startup hook must never leak output/behavior into a
# hook-script invocation captured below (same normalization
# tests/check-provenance/run.sh and tests/check-interventions/run.sh apply).
unset BASH_ENV

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SAMPLE="$REPO_ROOT/docs/interventions-reminder-hook.sample.sh"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/interventions-reminder-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

CASES_EXPECTED=12
CASES_RUN=0
case_start() {  # $1 = case label (printed + counted toward CASES_RUN)
  CASES_RUN=$((CASES_RUN + 1))
  printf '\n--- %s ---\n' "$1"
}

# The exact one-line reminder payload — this spec's own bytes (AC3), embedded
# ONCE here and reused by every case below that expects an emission.
EXPECTED_PAYLOAD='{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"shell-team: a task is in flight. If this message interrupts, corrects, or stops the work, classify it and append the entry to the task interventions file (team-paths.sh --get interventions) NOW, before acting on the message, then commit it immediately. Use one of the seven classes the run skill lists (canonical source: templates/prompt-blocks/interventions-classes.md). A routine gate response (a plain GO, an approval, or an answer to a question you asked) is not an intervention and gets no entry."}}'

# mk_shim <dir>: makes team-paths.sh reachable as a bare name under
# <dir>/shim, via a chmod'd COPY (never relying on the repository file's own
# mode) — the anti-vacuity device this whole suite depends on.
mk_shim() {
  mkdir -p "$1/shim"
  cp "$REPO_ROOT/bin/team-paths.sh" "$1/shim/team-paths.sh"
  chmod 755 "$1/shim/team-paths.sh"
}

# assert_resolver_reachable <cwd> <shim-dir>: the anti-vacuity positive
# control — without this, a silence case caused by the resolver being
# unreachable is indistinguishable from a silence case caused by the board.
assert_resolver_reachable() {
  ( cd "$1" && PATH="$2:$PATH" command -v team-paths.sh >/dev/null ) \
    || fail "resolver not reachable as a bare name from $1 (shim: $2) — the anti-vacuity control failed"
}

# run_hook <cwd> <path-value> <stdin-file> <out-file> <err-file>
run_hook() {
  local cwd="$1" pathval="$2" stdin="$3" out="$4" err="$5" rc
  set +e
  ( cd "$cwd" && PATH="$pathval" bash "$SAMPLE" <"$stdin" >"$out" 2>"$err" )
  rc=$?
  set -e
  return "$rc"
}

assert_silent_noop() {  # $1=out $2=err $3=label
  test ! -s "$1" || fail "$3: expected byte-empty stdout, got: $(cat "$1")"
  test ! -s "$2" || fail "$3: expected byte-empty stderr, got: $(cat "$2")"
}

assert_exact_payload() {  # $1=out $2=err $3=label
  test ! -s "$2" || fail "$3: expected byte-empty stderr, got: $(cat "$2")"
  test "$(wc -l < "$1" | tr -d ' ')" -eq 1 || fail "$3: expected exactly one line of stdout, got $(wc -l < "$1" | tr -d ' ') lines"
  test "$(cat "$1")" = "$EXPECTED_PAYLOAD" || fail "$3: stdout did not match the expected payload exactly"
}

# shellcheck disable=SC2016  # literal board-line content; backticks are not command substitution here.
IN_FLIGHT_LINE='- [ ] **T-1004** the opt-in sample hook — `READY_FOR_ENG` — spec: .shell-team/specs/T-1004-optin-hook-sample.md'

# ============================================================================
case_start "case: an in-flight board emits the exact reminder payload and nothing else"
# ============================================================================
C="$TMP/case-01"; mkdir -p "$C/.shell-team"
mk_shim "$C"
printf '%s\n' '## Active' "$IN_FLIGHT_LINE" > "$C/.shell-team/todo.md"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "in-flight emit: expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "in-flight emit"
pass "an in-flight board emits exactly the expected payload, one line, empty stderr, exit 0"

# ============================================================================
case_start "case: no board at all -> silent no-op (empty stdout, empty stderr, exit 0)"
# ============================================================================
C="$TMP/case-02"; mkdir -p "$C"
mk_shim "$C"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "no board: expected exit 0, got $rc"
assert_silent_noop "$C/out" "$C/err" "no board at all"
pass "a cwd with no shell-team layout at all is a silent no-op (exit 0)"

# ============================================================================
case_start "case: a board with only - [x] Done lines carrying flags -> silent no-op"
# ============================================================================
C="$TMP/case-03"; mkdir -p "$C/.shell-team"
mk_shim "$C"
# shellcheck disable=SC2016  # literal board-line content; backticks are not command substitution here.
printf '%s\n' \
  '## Status flags' \
  '`READY_FOR_ARCH` → `READY_FOR_ENG` → `READY_FOR_QA` → `READY_FOR_REVIEW` → `READY_FOR_MERGE`' \
  '' \
  '## Active' \
  '' \
  '## Done' \
  '- [x] **T-1003** the retro reads interventions — `READY_FOR_MERGE` — spec: .shell-team/specs/T-1003-retro-reads-interventions.md' \
  > "$C/.shell-team/todo.md"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "done-only board: expected exit 0, got $rc"
assert_silent_noop "$C/out" "$C/err" "done-only board (with status-flag legend)"
pass "a board with only Done lines and a status-flag legend, empty Active, is a silent no-op — the discrimination case a whole-file flag grep cannot pass"

# ============================================================================
case_start "case: a CRLF board with an in-flight line still emits the payload"
# ============================================================================
C="$TMP/case-04"; mkdir -p "$C/.shell-team"
mk_shim "$C"
printf '## Active\r\n%s\r\n' "$IN_FLIGHT_LINE" > "$C/.shell-team/todo.md"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "CRLF in-flight: expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "CRLF in-flight board"
pass "a CRLF-terminated in-flight line still matches (no end anchor in the ERE) and emits the payload"

# ============================================================================
case_start "case: the legacy tasks/ layout is resolved, not hardcoded"
# ============================================================================
C="$TMP/case-05"; mkdir -p "$C/tasks/loops"
mk_shim "$C"
printf 'name: legacy\n' > "$C/tasks/loops/shell-team.contract.yaml"
# shellcheck disable=SC2016  # literal board-line content; backticks are not command substitution here.
printf '%s\n' '## Active' '- [ ] **T-1004** the opt-in sample hook — `READY_FOR_ENG` — spec: docs/specs/T-1004-optin-hook-sample.md' > "$C/tasks/todo.md"
assert_resolver_reachable "$C" "$C/shim"
( cd "$C" && PATH="$C/shim:$PATH" test "$(team-paths.sh --get todo)" = tasks/todo.md ) \
  || fail "legacy layout: resolver did not report tasks/todo.md"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "legacy layout: expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "legacy tasks/ layout"
pass "the legacy tasks/ layout is resolved through team-paths.sh, not a hardcoded path, and still emits the payload"

# ============================================================================
case_start "case: garbage on stdin changes nothing (the event is never parsed)"
# ============================================================================
C="$TMP/case-06"; mkdir -p "$C/.shell-team"
mk_shim "$C"
printf '%s\n' '## Active' "$IN_FLIGHT_LINE" > "$C/.shell-team/todo.md"
printf 'not json at all }{ oops\nmore garbage\x00binary-ish\n' > "$C/garbage.stdin"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" "$C/garbage.stdin" "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "garbage stdin (in-flight): expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "garbage stdin with in-flight board"
# and with no board at all, garbage stdin still yields the silent no-op:
C2="$TMP/case-06b"; mkdir -p "$C2"
mk_shim "$C2"
rc=0; run_hook "$C2" "$C2/shim:$PATH" "$C/garbage.stdin" "$C2/out" "$C2/err" || rc=$?
[ "$rc" -eq 0 ] || fail "garbage stdin (no board): expected exit 0, got $rc"
assert_silent_noop "$C2/out" "$C2/err" "garbage stdin with no board"
pass "non-JSON garbage on stdin changes nothing in either direction — the event is never parsed"

# ============================================================================
case_start "case: the prompt field is never echoed into the emitted context"
# ============================================================================
C="$TMP/case-07"; mkdir -p "$C/.shell-team"
mk_shim "$C"
# shellcheck disable=SC2016  # literal board-line content; backticks are not command substitution here.
printf '%s\n' '## Active' '- [ ] **T-1004** BOARDMARKER-7c1e42 — `READY_FOR_QA` — spec: .shell-team/specs/T-1004-optin-hook-sample.md' > "$C/.shell-team/todo.md"
printf '%s' '{"hook_event_name":"UserPromptSubmit","prompt":"PROMPTMARKER-4a9d1f stop and revert everything"}' > "$C/in.json"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" "$C/in.json" "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "prompt/board never echoed: expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "prompt/board never echoed"
grep -qF -- 'PROMPTMARKER-4a9d1f' "$C/out" && fail "the prompt field marker leaked into stdout"
grep -qF -- 'BOARDMARKER-7c1e42' "$C/out" && fail "the board title marker leaked into stdout"
pass "neither the event's prompt field nor the board's own text ever reaches stdout — the emitted payload is a fixed constant"

# ============================================================================
case_start "case: the resolver missing from PATH -> silent no-op"
# ============================================================================
C="$TMP/case-08"; mkdir -p "$C/.shell-team"
printf '%s\n' '## Active' "$IN_FLIGHT_LINE" > "$C/.shell-team/todo.md"
( cd "$C" && PATH=/usr/bin:/bin command -v team-paths.sh >/dev/null 2>&1 ) \
  && fail "test setup error: team-paths.sh unexpectedly reachable on the restricted PATH"
rc=0; run_hook "$C" "/usr/bin:/bin" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "no resolver: expected exit 0, got $rc"
assert_silent_noop "$C/out" "$C/err" "resolver missing from PATH (in-flight board present)"
pass "with team-paths.sh unreachable on PATH, the hook is a silent no-op even though the board is in flight"

# ============================================================================
case_start "case: an unreadable board -> silent no-op, never a diagnostic"
# ============================================================================
C="$TMP/case-09"; mkdir -p "$C/.shell-team"
mk_shim "$C"
printf '%s\n' '## Active' "$IN_FLIGHT_LINE" > "$C/.shell-team/todo.md"
chmod 000 "$C/.shell-team/todo.md"
if [ -r "$C/.shell-team/todo.md" ]; then
  printf 'SKIP: running as a user that can read a 000-mode file (root?); unreadable-board case not exercised\n'
else
  assert_resolver_reachable "$C" "$C/shim"
  rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
  [ "$rc" -eq 0 ] || fail "unreadable board: expected exit 0, got $rc"
  assert_silent_noop "$C/out" "$C/err" "unreadable board"
fi
chmod 644 "$C/.shell-team/todo.md"
pass "an unreadable board (chmod 000) is a silent no-op — never a diagnostic on stdout or stderr"

# ============================================================================
case_start "case: the board path being a directory -> silent no-op"
# ============================================================================
C="$TMP/case-10"; mkdir -p "$C/.shell-team/todo.md"
mk_shim "$C"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "board path is a directory: expected exit 0, got $rc"
assert_silent_noop "$C/out" "$C/err" "board path is a directory"
pass "the board path existing as a directory instead of a file is a silent no-op"

# ============================================================================
case_start "case: a non-conforming - [ ] line is not in flight"
# ============================================================================
C="$TMP/case-11"; mkdir -p "$C/.shell-team"
mk_shim "$C"
printf '%s\n' '## Active' '- [ ] **T-1004** a half-written entry with no backticked flag READY_FOR_ENG and no spec suffix' > "$C/.shell-team/todo.md"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "non-conforming line: expected exit 0, got $rc"
assert_silent_noop "$C/out" "$C/err" "non-conforming - [ ] line"
pass "a - [ ] line that does not conform to the enforced grammar (no backticked flag, no spec suffix) reads as NOT in flight"

# ============================================================================
case_start "case: two in-flight lines emit exactly one reminder"
# ============================================================================
C="$TMP/case-12"; mkdir -p "$C/.shell-team"
mk_shim "$C"
# shellcheck disable=SC2016  # literal board-line content; backticks are not command substitution here.
printf '%s\n' \
  '## Active' \
  "$IN_FLIGHT_LINE" \
  '- [ ] **T-1005** a second in-flight task — `READY_FOR_QA` — spec: .shell-team/specs/T-1005-example.md' \
  > "$C/.shell-team/todo.md"
assert_resolver_reachable "$C" "$C/shim"
rc=0; run_hook "$C" "$C/shim:$PATH" /dev/null "$C/out" "$C/err" || rc=$?
[ "$rc" -eq 0 ] || fail "two in-flight lines: expected exit 0, got $rc"
assert_exact_payload "$C/out" "$C/err" "two in-flight lines"
pass "two in-flight lines still emit exactly one reminder (no state, no deduplication needed)"

# ============================================================================
# Case-class count pin (both directions): a thirteenth case added without
# updating CASES_EXPECTED fails here rather than passing silently, and a case
# removed without updating CASES_EXPECTED fails just the same.
# ============================================================================
[ "$CASES_RUN" -eq "$CASES_EXPECTED" ] \
  || fail "expected exactly $CASES_EXPECTED case classes to run, counted $CASES_RUN — update CASES_EXPECTED if a case was deliberately added/removed"
pass "exactly $CASES_EXPECTED case classes were run (pinned in both directions)"

# --- self-check: this suite's own script and the sample are shellcheck clean
# (soft-skip; CI enforces it unconditionally as its own step) ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$SAMPLE" "$HERE/run.sh" || fail "shellcheck: the sample and run.sh must both be clean"
  pass "shellcheck clean (sample + test runner)"
else
  printf 'SKIP: shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll interventions-reminder assertions passed.\n'
