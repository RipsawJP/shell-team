#!/usr/bin/env bash
# run.sh — assert bin/log-run.sh resolves its runs dir correctly (T-026):
#   - no env, default-layout cwd  -> .shell-team/runs/<loop>.jsonl  (NO tasks/ leak)
#   - no env, legacy-layout cwd   -> tasks/runs/<loop>.jsonl
#   - $TEAM_RUNS_DIR set          -> that dir (override; no .shell-team/ created)
#   - $RUNS_DIR set (back-compat) -> that dir
#
# Regression guard for the footprint leak where, in a .shell-team/ host, log-run
# fell back to a hardcoded tasks/runs because the orchestrator's exported
# TEAM_RUNS_DIR did not persist across Bash tool calls. Avoids mktemp (writes
# under $HERE/tmp-roots, cleaned via trap) so it runs in restricted sandboxes.
#
# T-042 (AC2) extends this suite with the post-write self-check auto-chain:
#   (a) a self-check failure on the just-written row surfaces as log-run's own
#       non-zero exit, and the row STAYS on disk (never rolled back).
#   (b) check-run.sh missing / unreadable / non-executable -> log-run still
#       exits 0 exactly as before (never hard-depends on it).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
LOGRUN="$REPO_ROOT/bin/log-run.sh"
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/log-run-test-roots.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

trap 'rm -rf "$TMP"' EXIT

SPAN_ARGS=(probe --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success)

# --- no env, default layout -> .shell-team/runs/ (no tasks/ leak) -------------
D="$TMP/default"
mkdir -p "$D"
( cd "$D" && env -u TEAM_RUNS_DIR -u RUNS_DIR bash "$LOGRUN" "${SPAN_ARGS[@]}" ) >/dev/null
[ -f "$D/.shell-team/runs/probe.jsonl" ] || fail "default: telemetry should land in .shell-team/runs/"
[ ! -e "$D/tasks" ]                    || fail "default: log-run must NOT create a tasks/ dir (leak)"
pass "no env + default layout -> .shell-team/runs/ (no tasks/ leak)"

# --- no env, legacy layout -> tasks/runs/ -----------------------------------
L="$TMP/legacy"
mkdir -p "$L/tasks/loops"
: > "$L/tasks/loops/shell-team.contract.yaml"
( cd "$L" && env -u TEAM_RUNS_DIR -u RUNS_DIR bash "$LOGRUN" "${SPAN_ARGS[@]}" ) >/dev/null
[ -f "$L/tasks/runs/probe.jsonl" ] || fail "legacy: telemetry should land in tasks/runs/"
pass "no env + legacy layout -> tasks/runs/"

# --- $TEAM_RUNS_DIR override ------------------------------------------------
O="$TMP/override"
mkdir -p "$O"
( cd "$O" && env -u RUNS_DIR TEAM_RUNS_DIR="custom-runs" bash "$LOGRUN" "${SPAN_ARGS[@]}" ) >/dev/null
[ -f "$O/custom-runs/probe.jsonl" ] || fail "TEAM_RUNS_DIR override not honored"
[ ! -d "$O/.shell-team" ]             || fail "override: should not also create .shell-team/"
pass "TEAM_RUNS_DIR overrides resolution"

# --- $RUNS_DIR back-compat alias --------------------------------------------
B="$TMP/runsdir"
mkdir -p "$B"
( cd "$B" && env -u TEAM_RUNS_DIR RUNS_DIR="legacy-alias" bash "$LOGRUN" "${SPAN_ARGS[@]}" ) >/dev/null
[ -f "$B/legacy-alias/probe.jsonl" ] || fail "RUNS_DIR back-compat alias not honored"
pass "RUNS_DIR back-compat alias honored"

# --- resolver-failure fallback: team-paths.sh absent -> .shell-team/runs (NOT tasks/) ---
# Copy log-run.sh into an isolated dir WITHOUT a sibling team-paths.sh, forcing
# the resolver call to fail. The fallback must be the default-layout .shell-team/runs,
# never tasks/runs — a broken install must not leak a tasks/ dir into the host.
ISO="$TMP/isolated-bin"
mkdir -p "$ISO"
cp "$LOGRUN" "$ISO/log-run.sh"
F="$TMP/resolver-fail"
mkdir -p "$F"
( cd "$F" && env -u TEAM_RUNS_DIR -u RUNS_DIR bash "$ISO/log-run.sh" "${SPAN_ARGS[@]}" ) >/dev/null
[ -f "$F/.shell-team/runs/probe.jsonl" ] || fail "resolver-fail: fallback should be .shell-team/runs/"
[ ! -e "$F/tasks" ]                    || fail "resolver-fail: must NOT fall back to a tasks/ dir (leak)"
pass "resolver failure (team-paths.sh absent) falls back to .shell-team/runs (no tasks/ leak)"

# --- LOOP_ID is constrained to a safe filename charset ----------------------
set +e
( cd "$D" && bash "$LOGRUN" "a/b" --run-id r --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
rc_slash=$?
( cd "$D" && bash "$LOGRUN" "../escape" --run-id r --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
rc_dotdot=$?
set -e
[ "$rc_slash"  -eq 2 ] || fail "loop_id with '/' should exit 2, got $rc_slash"
[ "$rc_dotdot" -eq 2 ] || fail "loop_id '../escape' should exit 2, got $rc_dotdot"
pass "invalid loop_id (path chars) is rejected with exit 2"

# --- AC2(b): check-run.sh MISSING entirely -> log-run still exits 0 --------
# (ISO above already copies log-run.sh alone into a dir with no sibling
# check-run.sh at all; the earlier resolver-fail assertion already implies
# exit 0 under `set -e`, but assert it explicitly here so the AC is provable
# in isolation from the resolver-fallback concern it's piggybacking on.)
MISS="$TMP/checkrun-missing"
mkdir -p "$MISS/bin"
cp "$LOGRUN" "$MISS/bin/log-run.sh"
set +e
( cd "$D" && bash "$MISS/bin/log-run.sh" checkrun-miss --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
miss_rc=$?
set -e
[ "$miss_rc" -eq 0 ] || fail "check-run.sh missing entirely: expected exit 0, got $miss_rc"
pass "check-run.sh missing entirely -> log-run still exits 0 (no hard dependency)"

# --- AC2(b): check-run.sh present but NOT EXECUTABLE -> log-run exits 0 ----
NOEXEC="$TMP/checkrun-noexec"
mkdir -p "$NOEXEC/bin"
cp "$LOGRUN" "$NOEXEC/bin/log-run.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$NOEXEC/bin/check-run.sh"
chmod -x "$NOEXEC/bin/check-run.sh"
set +e
( cd "$D" && bash "$NOEXEC/bin/log-run.sh" checkrun-noexec --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
noexec_rc=$?
set -e
[ "$noexec_rc" -eq 0 ] || fail "check-run.sh non-executable: expected exit 0, got $noexec_rc"
pass "check-run.sh present but non-executable -> log-run still exits 0"

# --- AC2(b): check-run.sh present but UNREADABLE -> log-run exits 0 -------
NOREAD="$TMP/checkrun-noread"
mkdir -p "$NOREAD/bin"
cp "$LOGRUN" "$NOREAD/bin/log-run.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$NOREAD/bin/check-run.sh"
chmod +x "$NOREAD/bin/check-run.sh"
chmod a-r "$NOREAD/bin/check-run.sh"
set +e
( cd "$D" && bash "$NOREAD/bin/log-run.sh" checkrun-noread --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
noread_rc=$?
set -e
chmod a+r "$NOREAD/bin/check-run.sh"   # restore so the EXIT trap's rm -rf can remove it
[ "$noread_rc" -eq 0 ] || fail "check-run.sh unreadable: expected exit 0, got $noread_rc"
pass "check-run.sh present but unreadable -> log-run still exits 0"

# --- AC2(a): a self-check FAILURE surfaces as log-run's own non-zero exit,
#         and the row it just wrote STAYS on disk (never rolled back). -------
FAILCHK="$TMP/checkrun-fails"
mkdir -p "$FAILCHK/bin"
cp "$LOGRUN" "$FAILCHK/bin/log-run.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAILCHK/bin/check-run.sh"
chmod +x "$FAILCHK/bin/check-run.sh"
FC="$TMP/failcheck-runs"
mkdir -p "$FC"
set +e
( cd "$FC" && env TEAM_RUNS_DIR="$FC" bash "$FAILCHK/bin/log-run.sh" selfcheck-fail --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>/dev/null
fc_rc=$?
set -e
[ "$fc_rc" -ne 0 ] && [ "$fc_rc" -ne 2 ] || fail "self-check failure: expected a non-zero, non-2 exit, got $fc_rc"
[ -f "$FC/selfcheck-fail.jsonl" ] || fail "self-check failure: the row must still be appended (not rolled back)"
[ "$(wc -l < "$FC/selfcheck-fail.jsonl")" -eq 1 ] || fail "self-check failure: exactly one row expected on disk"
pass "self-check failure -> log-run exits non-zero (not 2) AND the row stays on disk (no rollback)"

# --- AC2(a)/AC2(b) sanity: with the REAL sibling check-run.sh, a normal
#         valid append still exits 0 (the auto-chain never breaks the
#         best-effort contract for well-formed rows). ---------------------
REAL="$TMP/real-checkrun"
mkdir -p "$REAL"
set +e
( cd "$REAL" && env TEAM_RUNS_DIR="$REAL/runs" bash "$LOGRUN" real-check --run-id r1 --seq 0 --span s --phase p --iteration 0 --attempt 0 --status success ) >/dev/null 2>&1
real_rc=$?
set -e
[ "$real_rc" -eq 0 ] || fail "real check-run.sh present: expected exit 0, got $real_rc"
[ -f "$REAL/runs/real-check.jsonl" ] || fail "real check-run.sh present: row should still be appended"
pass "real sibling check-run.sh present -> valid row still appends cleanly (exit 0)"

# =====================================================================
# T-1058: the resolved binding (--provider / --effort / --adapter) —
# span-only, nullable, validated, and refused in event mode by presence.
# =====================================================================

BIND_DIR="$TMP/binding"
mkdir -p "$BIND_DIR"

# --- writer: all three flags record the expected values ---
set +e
RUNS_DIR="$BIND_DIR" bash "$LOGRUN" bindloop --run-id R1 --seq 1 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success --provider claude --effort high --adapter claude-cli >/dev/null 2>&1
bind_rc=$?
set -e
[ "$bind_rc" -eq 0 ] || fail "log-run --provider/--effort/--adapter expected exit 0, got $bind_rc"
grep -qF -- '"provider":"claude"' "$BIND_DIR/bindloop.jsonl" || fail "log-run did not record --provider claude"
grep -qF -- '"effort":"high"' "$BIND_DIR/bindloop.jsonl" || fail "log-run did not record --effort high"
grep -qF -- '"adapter":"claude-cli"' "$BIND_DIR/bindloop.jsonl" || fail "log-run did not record --adapter claude-cli"
pass "log-run --provider/--effort/--adapter records all three values"

# --- writer: appended AFTER parent_span_id, frozen 17 keys unmoved (T-1072
#     extends this exact lock string rather than rewriting it — the string
#     ends in a TRAILING SPACE, so an appended key must land before that
#     space is re-added, not after it) ---
bind_keys="$(grep -oE '"[a-z_]+":' "$BIND_DIR/bindloop.jsonl" | tr -d '":' | tr '\n' ' ')"
[ "$bind_keys" == "loop_id run_id seq ts span phase iteration attempt status model tokens tool_uses duration_ms verdict usd error parent_span_id provider effort adapter instance " ] \
  || fail "log-run binding row key order unexpected: $bind_keys"
pass "log-run appends provider/effort/adapter/instance after parent_span_id, frozen key order unmoved"

# --- writer: --effort - records null, never the two-character string "-" ---
set +e
RUNS_DIR="$BIND_DIR" bash "$LOGRUN" bindloop --run-id R1 --seq 2 --span codex-reviewer --phase review \
  --iteration 1 --attempt 1 --status success --provider codex --effort - --adapter codex-cli >/dev/null 2>&1
dash_rc=$?
set -e
[ "$dash_rc" -eq 0 ] || fail "log-run --effort - expected exit 0, got $dash_rc"
grep -qF -- '"effort":null' "$BIND_DIR/bindloop.jsonl" || fail "log-run --effort - did not record null"
[ "$(grep -cF -- '"effort":"-"' "$BIND_DIR/bindloop.jsonl" || true)" -eq 0 ] || fail "log-run --effort - leaked the two-character string"
pass "log-run --effort - records null, never the two-character string"

# --- writer: omitted binding flags render as null (never required) ---
set +e
RUNS_DIR="$BIND_DIR" bash "$LOGRUN" bindloop --run-id R1 --seq 3 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success >/dev/null 2>&1
omit_rc=$?
set -e
[ "$omit_rc" -eq 0 ] || fail "log-run with binding flags omitted expected exit 0, got $omit_rc"
for k in provider effort adapter; do
  grep -qF -- "\"$k\":null" "$BIND_DIR/bindloop.jsonl" || fail "log-run omitted --$k did not render null"
done
pass "log-run omitted --provider/--effort/--adapter all render as null"

# --- writer: malformed binding values are validation errors, nothing written ---
before_bind="$(wc -l < "$BIND_DIR/bindloop.jsonl")"
i=0
for bad in '--provider Claude' '--provider -' '--provider a_b' '--adapter x/y' '--effort High'; do
  i=$((i + 1))
  set +e
  # shellcheck disable=SC2086  # intentional word-splitting: $bad is a
  # "--flag value" pair that must reach log-run.sh as two argv words.
  RUNS_DIR="$BIND_DIR/x$i" bash "$LOGRUN" bindloop --run-id R1 --seq 9 --span engineer --phase implement \
    --iteration 1 --attempt 1 --status success $bad >/dev/null 2>&1
  bad_rc=$?
  set -e
  [ "$bad_rc" -eq 2 ] || fail "log-run '$bad' expected exit 2, got $bad_rc"
  [ ! -e "$BIND_DIR/x$i" ] || fail "log-run '$bad' created a runs dir despite validation failure"
done
after_bind="$(wc -l < "$BIND_DIR/bindloop.jsonl")"
[ "$before_bind" -eq "$after_bind" ] || fail "log-run wrote a row despite a malformed binding value"
pass "log-run rejects malformed --provider/--effort/--adapter values (exit 2, nothing written)"

# --- writer: all three binding flags are forbidden in event mode (exit 2) ---
for fl in --provider --effort --adapter; do
  set +e
  RUNS_DIR="$BIND_DIR/ev" bash "$LOGRUN" bindloop --run-id R1 --seq 9 --event handoff --from a --to b "$fl" x >/dev/null 2>&1
  ev_bind_rc=$?
  set -e
  [ "$ev_bind_rc" -eq 2 ] || fail "log-run $fl in event mode expected exit 2, got $ev_bind_rc"
done
[ ! -e "$BIND_DIR/ev" ] || fail "log-run binding flag in event mode created a runs dir"
pass "log-run rejects --provider/--effort/--adapter in event mode (exit 2, nothing written)"

# --- writer's own header documents all three T-1058 flags plus --instance ---
HDR_TMP="$TMP/log-run-header.txt"
awk 'NR>1 && /^#/{print} NR>1 && !/^#/{exit}' "$LOGRUN" > "$HDR_TMP"
for f in provider effort adapter instance; do
  grep -qF -- "--$f" "$HDR_TMP" || fail "log-run header does not document --$f"
done
pass "log-run's own header comment documents --provider/--effort/--adapter/--instance"

# =====================================================================
# T-1072: the per-instance discriminator (--instance) — span-only,
# nullable, appended AFTER --adapter, validated by the writer only, and
# refused in event mode by presence (same SPAN_ONLY_FLAGS mechanism as the
# T-1058 binding flags above).
# =====================================================================

INST_DIR="$TMP/instance"
mkdir -p "$INST_DIR"

# --- writer: --instance records the value verbatim, appended after adapter ---
set +e
RUNS_DIR="$INST_DIR" bash "$LOGRUN" instloop --run-id R1 --seq 1 --span qa-verifier --phase verify \
  --iteration 1 --attempt 1 --status success --adapter claude-cli --instance qa-2 >/dev/null 2>&1
inst_rc=$?
set -e
[ "$inst_rc" -eq 0 ] || fail "log-run --instance qa-2 expected exit 0, got $inst_rc"
grep -qF -- '"adapter":"claude-cli","instance":"qa-2"}' "$INST_DIR/instloop.jsonl" \
  || fail "log-run did not record --instance immediately after --adapter"
pass "log-run --instance records the value verbatim, appended after adapter"

# --- writer: omitted --instance renders null; explicitly empty also renders null ---
set +e
RUNS_DIR="$INST_DIR" bash "$LOGRUN" instloop --run-id R1 --seq 2 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success >/dev/null 2>&1
inst_omit_rc=$?
RUNS_DIR="$INST_DIR" bash "$LOGRUN" instloop --run-id R1 --seq 3 --span engineer --phase implement \
  --iteration 1 --attempt 1 --status success --instance "" >/dev/null 2>&1
inst_empty_rc=$?
set -e
[ "$inst_omit_rc" -eq 0 ] || fail "log-run with --instance omitted expected exit 0, got $inst_omit_rc"
[ "$inst_empty_rc" -eq 0 ] || fail "log-run --instance '' expected exit 0, got $inst_empty_rc"
[ "$(grep -cF -- '"instance":null}' "$INST_DIR/instloop.jsonl" || true)" -eq 2 ] \
  || fail "log-run omitted/empty --instance did not both render null"
pass "log-run omitted or explicitly-empty --instance both render null"

# --- writer: malformed --instance values are validation errors, nothing written
#     (a bare numeric id and the bare '-' are both deliberately refused: see
#     the T-1072 header paragraph) ---
before_inst="$(wc -l < "$INST_DIR/instloop.jsonl")"
i=0
for bad in QA 2 a_b x/y -inst -; do
  i=$((i + 1))
  set +e
  RUNS_DIR="$INST_DIR/bad$i" bash "$LOGRUN" instloop --run-id R1 --seq 9 --span engineer --phase implement \
    --iteration 1 --attempt 1 --status success --instance "$bad" >/dev/null 2>&1
  bad_inst_rc=$?
  set -e
  [ "$bad_inst_rc" -eq 2 ] || fail "log-run --instance '$bad' expected exit 2, got $bad_inst_rc"
  [ ! -e "$INST_DIR/bad$i" ] || fail "log-run --instance '$bad' created a runs dir despite validation failure"
done
after_inst="$(wc -l < "$INST_DIR/instloop.jsonl")"
[ "$before_inst" -eq "$after_inst" ] || fail "log-run wrote a row despite a malformed --instance value"
pass "log-run rejects malformed --instance values, including a bare numeric id and the bare '-' (exit 2, nothing written)"

# --- writer: --instance is forbidden in event mode (exit 2, nothing written) ---
set +e
RUNS_DIR="$INST_DIR/ev" bash "$LOGRUN" instloop --run-id R1 --seq 9 --event handoff --from a --to b --instance qa-1 >/dev/null 2>&1
inst_ev_rc=$?
set -e
[ "$inst_ev_rc" -eq 2 ] || fail "log-run --instance in event mode expected exit 2, got $inst_ev_rc"
[ ! -e "$INST_DIR/ev" ] || fail "log-run --instance in event mode created a runs dir"
pass "log-run rejects --instance in event mode (exit 2, nothing written)"

printf '\nAll log-run resolution assertions passed.\n'
