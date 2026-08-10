#!/usr/bin/env bash
# run.sh — drive bin/rollup-runs.sh against fixtures and assert the documented
# behavior (T-020 acceptance criteria):
#   - a clean multi-span run summarizes with the ✓ flag, correct counts/sums   [AC1]
#   - an error/FAIL run gets the ⚠ flag                                         [AC1]
#   - nullable tokens/duration mark the total "(partial)"                       [AC3]
#   - multiple run_ids in one file produce one block each                       [AC2]
#   - empty input prints "(no runs found)" and exits 0
#   - no args / unreadable file are usage errors (exit 2)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ROLLUP="$REPO_ROOT/bin/rollup-runs.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <file...>
assert_rc() {
  local desc="$1" exp="$2"; shift 2
  local rc
  set +e
  bash "$ROLLUP" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc"
  pass "$desc (exit $rc)"
}

# assert_out <desc> <pattern> <file...>  — guard exits 0 and stdout matches /pattern/
assert_out() {
  local desc="$1" pat="$2"; shift 2
  local out rc
  set +e
  out="$(bash "$ROLLUP" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "$desc: expected exit 0, got $rc"
  grep -qE "$pat" <<< "$out" || fail "$desc: stdout missing /$pat/ (got: $out)"
  pass "$desc"
}

# --- clean run (AC1): ✓ flag, counts, sums, window ---
assert_out "clean: ✓ flag"            'run RUN-CLEAN .*✓'           "$FIX/clean.jsonl"
assert_out "clean: 4 spans"           'spans: 4'                    "$FIX/clean.jsonl"
assert_out "clean: phases in order"   'phases: plan implement validate review' "$FIX/clean.jsonl"
assert_out "clean: status success=4" 'status: success=4'           "$FIX/clean.jsonl"
assert_out "clean: verdicts"          'verdict: PASS=1 APPROVE=1'   "$FIX/clean.jsonl"
assert_out "clean: token sum 1000"    'tokens: 1000   duration: 10000ms' "$FIX/clean.jsonl"
assert_out "clean: window"            'window: 2026-06-13T00:00:01Z → 2026-06-13T00:00:04Z' "$FIX/clean.jsonl"

# --- error/FAIL run (AC1): ⚠ flag ---
assert_out "mixed: ⚠ flag"            'run RUN-BAD .*⚠'             "$FIX/mixed.jsonl"
assert_out "mixed: status breakdown"  'status: success=1 error=1'   "$FIX/mixed.jsonl"
assert_out "mixed: FAIL verdict"      'verdict: FAIL=1'             "$FIX/mixed.jsonl"

# --- null fields (AC3): partial markers ---
assert_out "nulls: token partial"     'tokens: 200 \(partial\)'     "$FIX/nulls.jsonl"
assert_out "nulls: duration partial"  'duration: 2000ms \(partial\)' "$FIX/nulls.jsonl"

# --- multiple run_ids (AC2): one block each ---
multi_out="$(bash "$ROLLUP" "$FIX/multi-run.jsonl" 2>/dev/null)"
blocks="$(grep -c '^run ' <<< "$multi_out")"
[ "$blocks" -eq 2 ] || fail "multi-run: expected 2 run blocks, got $blocks"
pass "multi-run: 2 run blocks (RUN-A, RUN-B)"

# --- cross-file grouping (AC2): same run_id split across two files folds into one block ---
cross="$(bash "$ROLLUP" "$FIX/clean.jsonl" "$FIX/clean.jsonl" 2>/dev/null)"
cross_blocks="$(grep -c '^run ' <<< "$cross")"
[ "$cross_blocks" -eq 1 ] || fail "cross-file: same run_id across files should yield 1 block, got $cross_blocks"
grep -qE 'spans: 8' <<< "$cross" || fail "cross-file: expected 8 spans (4+4), got: $cross"
pass "cross-file: same run_id across two files folds to 1 block, spans summed"

# --- empty input -> "(no runs found)", exit 0 ---
assert_out "empty: no runs found"     '\(no runs found\)'           "$FIX/empty.jsonl"

# --- T-1011 AC30: an event-row-bearing input rolls up byte-identical to the
# SAME file with the event rows removed — the invariance property, defended
# here by this repo's own CI, not only by T-1011's spec `check:` lines.
# Derived from with-events.jsonl ITSELF (grep out the event rows) rather than
# compared against the separately fixtured clean.jsonl: T-1058's `review:`
# line prints each span's own `seq`, and with-events.jsonl's spans (seq
# 1,3,5,7, interleaved with events) and clean.jsonl's spans (seq 1,2,3,4,
# no events at all) are drawn from different seq sequences — comparing
# across the two fixtures would no longer test what AC30 actually requires
# (this script's stdout for a file == its stdout for the SAME file with
# every event row deleted), only a coincidence that held while seq was
# never printed. ---
events_out="$(bash "$ROLLUP" "$FIX/with-events.jsonl" 2>/dev/null)"
WITHOUT_EVENTS="$(mktemp "${TMPDIR:-/tmp}/rollup-runs-without-events.XXXXXX")" || fail "mktemp failed"
grep -v -- '"kind":"event"' "$FIX/with-events.jsonl" > "$WITHOUT_EVENTS"
without_events_out="$(bash "$ROLLUP" "$WITHOUT_EVENTS" 2>/dev/null)"
rm -f "$WITHOUT_EVENTS"
[ "$events_out" = "$without_events_out" ] || fail "with-events: rollup output changed by event rows (T-1011 regression)"
pass "with-events: event rows (T-1011) are skipped, output identical to the same file with event rows removed"

# --- T-1021: a leading-zero numeric field must not silently re-base -------
# Scratch rows are written under a temp dir (never checked in as new
# fixture files under tests/rollup-runs/fixtures/, which T-1021's diff
# allow-list does not cover — only tests/rollup-runs/run.sh itself is in
# scope) and cleaned up via trap.
T1021_TMP="$(mktemp -d "${TMPDIR:-/tmp}/t1021-rollup.XXXXXX")"
trap 'rm -rf "$T1021_TMP"' EXIT

# `"tokens":010` (valid octal 8, decimal 10 — the two values genuinely
# differ) must sum as 10, never as the octal-re-based 8.
ZERO010="$T1021_TMP/zero-padded-010.jsonl"
printf '{"loop_id":"shell-team","run_id":"RUN-ZERO-010","seq":1,"ts":"2026-06-13T00:00:01Z","span":"tech-lead","phase":"plan","iteration":0,"attempt":0,"status":"success","model":null,"tokens":010,"tool_uses":1,"duration_ms":1000,"verdict":null,"usd":null,"error":null,"parent_span_id":null}\n' > "$ZERO010"
assert_out "T-1021-rollup-runs-tokens (zero-fixture=010) sums as 10" 'tokens: 10( |$)' "$ZERO010"

# `"tokens":08` is invalid as an octal literal — this must neither leak
# bash's raw arithmetic error nor abort mid-output with no diagnostic; the
# 10# fix means it just succeeds, summing as decimal 8.
ZERO08="$T1021_TMP/zero-padded-08.jsonl"
printf '{"loop_id":"shell-team","run_id":"RUN-ZERO-08","seq":1,"ts":"2026-06-13T00:00:01Z","span":"tech-lead","phase":"plan","iteration":0,"attempt":0,"status":"success","model":null,"tokens":08,"tool_uses":1,"duration_ms":1000,"verdict":null,"usd":null,"error":null,"parent_span_id":null}\n' > "$ZERO08"
ERRTMP="$T1021_TMP/zero-padded-08.err"
out_08="$(bash "$ROLLUP" "$ZERO08" 2>"$ERRTMP")"
grep -qE 'tokens: 8( |$)' <<< "$out_08" \
  || fail "T-1021-rollup-runs-tokens (zero-fixture=08): expected 'tokens: 8', got: $out_08"
grep -q 'value too great for base' "$ERRTMP" \
  && fail "T-1021-rollup-runs-tokens (zero-fixture=08): leaked bash's raw arithmetic error"
pass "T-1021-rollup-runs-tokens (zero-fixture=08): sums as 8 with no raw arithmetic error"

# =====================================================================
# T-1058: the resolved binding — "providers:" and "review:" are ALWAYS
# printed (never omitted), derived per reviewer span (never a per-run
# boolean), over the closed three-member outcome set. Scratch rows only
# (never checked in as new fixture files, matching the T-1021 idiom above).
# =====================================================================
T1058_TMP="$(mktemp -d "${TMPDIR:-/tmp}/t1058-rollup.XXXXXX")"
# Re-declares the EXIT trap to cover BOTH scratch dirs (a second `trap ... EXIT`
# replaces, never adds to, the first) — both variables are already set by the
# time this trap actually fires.
trap 'rm -rf "$T1021_TMP" "$T1058_TMP"' EXIT

# bindrow <seq> <span> <provider-or-empty> — a minimal span row; an empty
# provider omits the key entirely ("this row does not say", same as a
# legacy pre-T-1058 row or an explicit JSON null under field_str's reading).
bindrow() {
  local seq="$1" span="$2" prov="$3" extra=""
  [ -n "$prov" ] && extra=",\"provider\":\"$prov\",\"effort\":null,\"adapter\":\"a1\""
  printf '{"loop_id":"shell-team","run_id":"RUN-BIND","seq":%s,"ts":"2026-08-01T00:00:0%sZ","span":"%s","phase":"p","iteration":1,"attempt":1,"status":"success","model":null,"tokens":null,"tool_uses":null,"duration_ms":null,"verdict":null,"usd":null,"error":null,"parent_span_id":null%s}\n' \
    "$seq" "$seq" "$span" "$extra"
}

CROSS="$T1058_TMP/cross.jsonl"
{ bindrow 1 engineer claude; bindrow 2 codex-reviewer codex; } > "$CROSS"
assert_out "T-1058-provider-relation: cross-provider"    'review: codex-reviewer#2=cross-provider' "$CROSS"
assert_out "T-1058-provider-relation: providers counted" 'providers: claude=1 codex=1'              "$CROSS"

SAME="$T1058_TMP/same.jsonl"
{ bindrow 1 engineer claude; bindrow 2 codex-reviewer claude; } > "$SAME"
assert_out "T-1058-provider-relation: same-provider is a legitimate outcome" \
  'review: codex-reviewer#2=same-provider' "$SAME"

LEGACY="$T1058_TMP/legacy.jsonl"
{ bindrow 1 engineer ''; bindrow 2 codex-reviewer ''; } > "$LEGACY"
legacy_out="$(bash "$ROLLUP" "$LEGACY" 2>/dev/null)"
grep -qF -- 'review: codex-reviewer#2=undetermined' <<< "$legacy_out" \
  || fail "T-1058-provider-relation: legacy rows (no binding fields) should be undetermined"
grep -qF -- 'providers: (none)' <<< "$legacy_out" \
  || fail "T-1058-provider-relation: legacy rows should print providers: (none)"
[ "$(grep -c 'same-provider\|cross-provider' <<< "$legacy_out" || true)" -eq 0 ] \
  || fail "T-1058-provider-relation: legacy-only rows must never claim same-provider/cross-provider"
pass "T-1058-provider-relation: legacy (no binding fields) rows are undetermined, never same/cross-provider"

NOREV="$T1058_TMP/noreviewer.jsonl"
bindrow 1 engineer claude > "$NOREV"
assert_out "T-1058-provider-relation: no reviewer span -> review: (none)" 'review: \(none\)' "$NOREV"

MIXED_PARTIAL="$T1058_TMP/mixed-partial.jsonl"
{ bindrow 1 engineer claude; bindrow 2 codex-reviewer ''; } > "$MIXED_PARTIAL"
assert_out "T-1058-provider-relation: one side unrecorded -> providers (partial)" \
  'providers: claude=1 \(partial\)' "$MIXED_PARTIAL"

# Three review rounds interleaved with three implementation rounds — the
# per-reviewer-span shape (never a per-run boolean): exactly 3 tokens, at
# least 2 distinct outcomes.
THREE="$T1058_TMP/three-rounds.jsonl"
{
  bindrow 1 engineer claude; bindrow 2 codex-reviewer codex
  bindrow 3 engineer claude; bindrow 4 codex-reviewer claude
  bindrow 5 engineer '';     bindrow 6 codex-reviewer codex
} > "$THREE"
three_out="$(bash "$ROLLUP" "$THREE" 2>/dev/null)"
review_line="$(sed -n 's/^ *review: //p' <<< "$three_out")"
n_tokens="$(tr ' ' '\n' <<< "$review_line" | grep -c '=' || true)"
[ "$n_tokens" -eq 3 ] || fail "T-1058-provider-relation: three-round run expected 3 review tokens, got $n_tokens ($review_line)"
n_distinct="$(tr ' ' '\n' <<< "$review_line" | sed 's/^.*=//' | grep . | LC_ALL=C sort -u | grep -c . || true)"
[ "$n_distinct" -ge 2 ] || fail "T-1058-provider-relation: three-round run expected >=2 distinct outcomes, got $n_distinct ($review_line)"
pass "T-1058-provider-relation: three review rounds -> 3 per-span tokens, >=2 distinct outcomes"

# --- usage errors ---
assert_rc "no args -> 2"          2
assert_rc "unreadable file -> 2"  2 "$FIX/does-not-exist.jsonl"

printf '\nAll rollup-runs assertions passed.\n'
