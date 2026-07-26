#!/usr/bin/env bash
# run.sh — drive bin/consolidate-proposals.sh against fixtures and assert the
# documented behavior (T-021 acceptance criteria):
#   - merges discovery + telemetry into ONE proposal file at the resolved path  [AC1]
#   - never-overwrite numeric-suffix collision rule                             [AC1]
#   - cross-source / within-source de-dup by source key (emitted once)          [AC2]
#   - --max BUDGET cap with an explicit truncation note (no silent drop)        [AC3]
#   - propose-only: the repo's tasks/todo.md is byte-unchanged across a run      [AC6]
#   - graceful degrade: absent / note-only / empty inputs -> note + exit 0       [AC7]
#   - usage errors (bad --max / --date / unknown flag) exit 2
#
# Fixtures feed pre-captured discover-work.sh / rollup-runs.sh stdout, so no real
# gh / network / live telemetry is touched — this tests the consolidation logic.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin/consolidate-proposals.sh"
FIX="$HERE/fixtures"
DATE="2026-06-18"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/consolidate-proposals.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# run_ok <outvar> <args...> — run, require exit 0, capture the printed path.
run_ok() {
  local __out="$1"; shift
  local p rc
  set +e
  p="$(bash "$BIN" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "expected exit 0 for: $* (got $rc)"
  printf -v "$__out" '%s' "$p"
}

assert_rc() {  # <desc> <expected_rc> <args...>
  local desc="$1" exp="$2"; shift 2
  local rc
  set +e
  bash "$BIN" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc"
  pass "$desc (exit $rc)"
}

# count candidate (`- [ ]`) lines in a file
ncand() { grep -c '^- \[ \]' "$1" 2>/dev/null || true; }

# --- AC1: merge discovery + telemetry into one file at the resolved path ---
D1="$WORK/d1"; mkdir -p "$D1"
run_ok OUT --discovery "$FIX/discovery-basic.txt" --rollup "$FIX/rollup-basic.txt" --out-dir "$D1" --date "$DATE"
[ "$OUT" = "$D1/triage-rollup-$DATE.md" ] || fail "AC1: unexpected output path: $OUT"
[ -f "$OUT" ] || fail "AC1: proposal file not written: $OUT"
grep -qF '[ci:check-handoff#123]' "$OUT" || fail "AC1: discovery CI candidate missing"
grep -qF '[pr#41]'                "$OUT" || fail "AC1: discovery PR candidate missing"
grep -qF '[issue#37]'             "$OUT" || fail "AC1: discovery issue candidate missing"
grep -qF '[run:RUN-BAD]'          "$OUT" || fail "AC1: telemetry escalation missing"
if grep -qF '[run:RUN-OK]' "$OUT"; then fail "AC1: ✓ run must NOT escalate"; fi
grep -qF 'tasks/todo.md is NOT modified' "$OUT" || fail "AC1: propose-only banner missing"
pass "AC1: discovery + telemetry merged into one proposal file (✓ run excluded)"

# --- AC1: collision rule — second run same date never overwrites ---
run_ok OUT2 --discovery "$FIX/discovery-basic.txt" --out-dir "$D1" --date "$DATE"
[ "$OUT2" = "$D1/triage-rollup-$DATE-2.md" ] || fail "AC1: collision suffix not applied: $OUT2"
if [ ! -f "$D1/triage-rollup-$DATE.md" ] || [ ! -f "$OUT2" ]; then fail "AC1: both files should exist after collision"; fi
pass "AC1: collision -> numeric suffix, original preserved"

# --- T-061 AC4: a dangling symlink at the candidate output path is a
#     collision too — `[ -e ]` is false for a dangling symlink, so an
#     unguarded loop would follow it and write the proposal OUTSIDE the
#     out-dir. The loop must advance to the next numeric suffix, write inside
#     out-dir, and leave the pre-existing symlink untouched. ---
DSYM="$WORK/dsym"; mkdir -p "$DSYM" "$WORK/outside-check"
ln -s "../outside-check/escaped.md" "$DSYM/triage-rollup-$DATE.md"
run_ok OUT_SYM --discovery "$FIX/discovery-basic.txt" --out-dir "$DSYM" --date "$DATE"
[ "$OUT_SYM" = "$DSYM/triage-rollup-$DATE-2.md" ] \
  || fail "T-061 AC4: dangling symlink should be treated as a collision, advancing to the -2 suffix (got: $OUT_SYM)"
[ -f "$OUT_SYM" ] || fail "T-061 AC4: the -2 suffix proposal file was not written"
[ ! -e "$WORK/outside-check/escaped.md" ] \
  || fail "T-061 AC4: proposal content escaped the out-dir through a dangling symlink"
[ -L "$DSYM/triage-rollup-$DATE.md" ] \
  || fail "T-061 AC4: the pre-existing dangling symlink should be preserved untouched"
pass "T-061 AC4: dangling symlink at the collision path advances to the next suffix, no out-dir escape, symlink preserved"

# --- AC2: within-discovery duplicate key emitted once ---
D2="$WORK/d2"; mkdir -p "$D2"
run_ok OUT --discovery "$FIX/discovery-dup.txt" --out-dir "$D2" --date "$DATE"
dups="$(grep -cF '[ci:check-handoff#123]' "$OUT")"
[ "$dups" -eq 1 ] || fail "AC2: duplicate [ci:..#123] key emitted $dups times (want 1)"
pass "AC2: within-source duplicate key collapsed to one"

# --- AC2: same run_id in two ⚠ blocks emitted once ---
D3="$WORK/d3"; mkdir -p "$D3"
run_ok OUT --rollup "$FIX/rollup-dup.txt" --out-dir "$D3" --date "$DATE"
rdups="$(grep -cF '[run:RUN-BAD]' "$OUT")"
[ "$rdups" -eq 1 ] || fail "AC2: duplicate [run:RUN-BAD] emitted $rdups times (want 1)"
pass "AC2: duplicate telemetry run_id collapsed to one"

# --- AC2: cross-source dedup — same [run:RUN-BAD] in BOTH discovery and the
#         rollup ⚠ escalation is emitted exactly once (the headline scenario) ---
D3b="$WORK/d3b"; mkdir -p "$D3b"
run_ok OUT --discovery "$FIX/discovery-run.txt" --rollup "$FIX/rollup-basic.txt" --out-dir "$D3b" --date "$DATE"
xdups="$(grep -cF '[run:RUN-BAD]' "$OUT")"
[ "$xdups" -eq 1 ] || fail "AC2: cross-source [run:RUN-BAD] emitted $xdups times (want 1)"
# discovery contributes [run:RUN-BAD] + [pr#99]; rollup's RUN-BAD is the dup, RUN-OK is ✓ -> 2 total
[ "$(ncand "$OUT")" -eq 2 ] || fail "AC2: cross-source merge should yield 2 candidates, got $(ncand "$OUT")"
pass "AC2: cross-source duplicate key (discovery + telemetry) collapsed to one"

# --- M-1: a bracket-bearing run_id is skipped with a note (never forging a
#         broken [run:..] key); ISO-8601 ids with colons are ACCEPTED ---
Dbad="$WORK/dbad"; mkdir -p "$Dbad"
printf 'run bad]id  [loop x]  ⚠\nrun ok.id_1  [loop x]  ⚠\nrun 2026-06-18T12:00:00Z  [loop x]  ⚠\n' > "$Dbad/rollup-malformed.txt"
run_ok OUT --rollup "$Dbad/rollup-malformed.txt" --out-dir "$Dbad" --date "$DATE"
if grep -qF '[run:bad]id]' "$OUT"; then fail "M-1: broken bracket key [run:bad]id] must not be emitted"; fi
grep -qF '[run:ok.id_1]' "$OUT" || fail "M-1: a valid run_id (ok.id_1) should still escalate"
grep -qF '[run:2026-06-18T12:00:00Z]' "$OUT" || fail "M-1 (regression): ISO-8601 run_id with colons must be accepted"
grep -qF 'skipped a telemetry escalation' "$OUT" || fail "M-1: bracket-bearing run_id should leave a gap note"
[ "$(ncand "$OUT")" -eq 2 ] || fail "M-1: 2 valid escalations should remain (ok.id_1, ISO ts), got $(ncand "$OUT")"
pass "M-1: bracket run_id skipped w/ note; valid + ISO-8601 (colon) ids preserved"

# --- NEW-M-2: a keyless discovery line is rejected (gap note), never consuming
#         the --max budget ahead of a valid keyed candidate ---
Dkl="$WORK/dkl"; mkdir -p "$Dkl"
run_ok OUT --discovery "$FIX/discovery-keyless.txt" --max 1 --out-dir "$Dkl" --date "$DATE"
[ "$(ncand "$OUT")" -eq 1 ] || fail "NEW-M-2: expected 1 candidate under --max 1, got $(ncand "$OUT")"
grep -qF '[pr#7]' "$OUT" || fail "NEW-M-2: the valid keyed candidate must survive (keyless must not crowd it out)"
grep -qF 'no recognizable source key' "$OUT" || fail "NEW-M-2: keyless line should leave a gap note"
pass "NEW-M-2: keyless line rejected w/ note, does not consume budget"

# --- minor: ⚠ inside a loop id on a ✓ run must NOT escalate (trailing-flag anchor) ---
Dwf="$WORK/dwf"; mkdir -p "$Dwf"
printf 'run RUN-OK  [loop loop-⚠-name]  ✓\n' > "$Dwf/rollup-glyph.txt"
run_ok OUT --rollup "$Dwf/rollup-glyph.txt" --out-dir "$Dwf" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "minor: a ✓ run with ⚠ in its loop id must not escalate, got $(ncand "$OUT")"
pass "minor: ⚠ in loop id on a ✓ run does not escalate (flag anchored to line end)"

# --- AC2: distinct keys across both sources all preserved (basic = 4) ---
[ "$(ncand "$D1/triage-rollup-$DATE.md")" -eq 4 ] \
  || fail "AC2: basic merge should yield 4 distinct candidates, got $(ncand "$D1/triage-rollup-$DATE.md")"
pass "AC2: distinct keys across sources preserved (3 discovery + 1 escalation)"

# --- AC3: --max cap + explicit truncation note ---
D4="$WORK/d4"; mkdir -p "$D4"
run_ok OUT --discovery "$FIX/discovery-many.txt" --max 10 --out-dir "$D4" --date "$DATE"
[ "$(ncand "$OUT")" -eq 10 ] || fail "AC3: expected 10 capped candidates, got $(ncand "$OUT")"
grep -qF 'truncated: showing 10 of 12 candidates' "$OUT" || fail "AC3: truncation note missing"
pass "AC3: --max cap honored with explicit truncation note (no silent drop)"

# --- AC6: propose-only — the resolved board is byte-unchanged ---
# Hermetic form: a temp base holding a copy of the shipped board template, with
# TEAM_RUN_BASE pointing at it, so a regression that writes the *resolved* board
# trips this guard instead of it depending on any one repo's own board file.
BOARD_BASE="$WORK/board-base"; mkdir -p "$BOARD_BASE"
cp "$REPO_ROOT/templates/todo-template.md" "$BOARD_BASE/todo.md"
before="$(cksum "$BOARD_BASE/todo.md")"
D5="$WORK/d5"; mkdir -p "$D5"
TEAM_RUN_BASE="$BOARD_BASE" run_ok OUT --discovery "$FIX/discovery-basic.txt" --rollup "$FIX/rollup-basic.txt" --out-dir "$D5" --date "$DATE"
after="$(cksum "$BOARD_BASE/todo.md")"
[ "$before" = "$after" ] || fail "AC6: the resolved board changed across a run"
pass "AC6: resolved board byte-unchanged (propose-only)"

# --- AC7: graceful degrade — no inputs at all ---
D6="$WORK/d6"; mkdir -p "$D6"
run_ok OUT --out-dir "$D6" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "AC7: no-input run should have 0 candidates"
grep -qF '# note:' "$OUT" || fail "AC7: no-input run should carry a # note: gap line"
grep -qF 'no candidate work after consolidation' "$OUT" || fail "AC7: missing no-candidate note"
pass "AC7: no inputs -> note + exit 0, no crash"

# --- AC7: gh-degrade note carried forward from a note-only discovery ---
D7="$WORK/d7"; mkdir -p "$D7"
run_ok OUT --discovery "$FIX/discovery-noteonly.txt" --out-dir "$D7" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "AC7: note-only discovery should yield 0 candidates"
grep -qF 'gh CLI not found' "$OUT" || fail "AC7: discovery gh-degrade note not carried forward"
pass "AC7: note-only discovery (gh missing) carried forward, exit 0"

# --- AC7: empty input files ---
D8="$WORK/d8"; mkdir -p "$D8"
run_ok OUT --discovery "$FIX/empty.txt" --rollup "$FIX/empty.txt" --out-dir "$D8" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "AC7: empty inputs should yield 0 candidates"
pass "AC7: empty input files -> note + exit 0"

# =============================================================================
# T-051 (#120): Source C — cross-run failure clusters (bin/cluster-failures.sh,
# T-044) wired in via --clusters. Issue #120's AC1/AC6/AC7 (kept in the spec's
# own numbering; distinct from the AC1-AC7 labels above, which are T-021's).
# =============================================================================

# --- T-051 AC1: cluster-failures output appears as [cluster:...]-keyed
#     proposal lines, de-duplicated and subject to the same --max cap,
#     alongside (not replacing) discovery + telemetry ---
D9="$WORK/d9"; mkdir -p "$D9"
run_ok OUT --discovery "$FIX/discovery-basic.txt" --rollup "$FIX/rollup-basic.txt" --clusters "$FIX/cluster-basic.txt" --out-dir "$D9" --date "$DATE"
grep -qF '[cluster:IMPLEMENT:ERROR]'        "$OUT" || fail "T-051 AC1: first cluster candidate missing"
grep -qF '[cluster:REVIEW:REQUEST_CHANGES]' "$OUT" || fail "T-051 AC1: second cluster candidate missing"
[ "$(ncand "$OUT")" -eq 6 ] || fail "T-051 AC1: expected 6 candidates (3 discovery + 1 telemetry + 2 cluster), got $(ncand "$OUT")"
pass "T-051 AC1: cluster candidates merged as a third source, alongside discovery + telemetry"

# --- T-051 AC1 (--max cap applies to cluster candidates too, no new cap) ---
D9b="$WORK/d9b"; mkdir -p "$D9b"
run_ok OUT --clusters "$FIX/cluster-basic.txt" --max 1 --out-dir "$D9b" --date "$DATE"
[ "$(ncand "$OUT")" -eq 1 ] || fail "T-051 AC1: --max 1 should cap cluster candidates to 1, got $(ncand "$OUT")"
grep -qF 'truncated: showing 1 of 2 candidates' "$OUT" || fail "T-051 AC1: truncation note missing for capped cluster candidates"
pass "T-051 AC1: cluster candidates share the single --max BUDGET (no separate cap)"

# --- T-051: within-cluster duplicate signature (same [cluster:...] key
#     appearing twice in the --clusters input) collapses to one, same as
#     Sources A/B's de-dup-by-source-key rule ---
D9c="$WORK/d9c"; mkdir -p "$D9c"
printf 'cluster IMPLEMENT:ERROR  count=3  run RUN-A\ncluster IMPLEMENT:ERROR  count=1  run RUN-B\n' > "$D9c/cluster-dup.txt"
run_ok OUT --clusters "$D9c/cluster-dup.txt" --out-dir "$D9c" --date "$DATE"
cdups="$(grep -cF '[cluster:IMPLEMENT:ERROR]' "$OUT")"
[ "$cdups" -eq 1 ] || fail "T-051: duplicate [cluster:IMPLEMENT:ERROR] key emitted $cdups times (want 1)"
pass "T-051: within-cluster duplicate signature collapsed to one (first occurrence wins)"

# --- T-051 AC6 (locks Design decision (c)): the SAME run_id as both a Source B
#     escalation and a Source C cluster's representative run -> BOTH lines
#     retained (distinct keys never collide); two distinct cluster signatures
#     sharing one representative run_id -> both also retained ---
D10="$WORK/d10"; mkdir -p "$D10"
run_ok OUT --rollup "$FIX/rollup-overlap.txt" --clusters "$FIX/cluster-run-overlap.txt" --out-dir "$D10" --date "$DATE"
[ "$(ncand "$OUT")" -eq 3 ] || fail "T-051 AC6: expected 3 candidates (1 run: + 2 cluster:), got $(ncand "$OUT")"
grep -qF '[run:RUN-X]'                "$OUT" || fail "T-051 AC6: Source B [run:RUN-X] escalation missing"
grep -qF '[cluster:IMPLEMENT:ERROR]'   "$OUT" || fail "T-051 AC6: first [cluster:...] candidate missing"
grep -qF '[cluster:REVIEW:FAIL]'       "$OUT" || fail "T-051 AC6: second [cluster:...] candidate missing"
pass "T-051 AC6: overlapping representative run_id never collapses [run:..] / [cluster:..] candidates (design decision (c) proven)"

# --- T-051 AC7 (locks Design decision (e)): cluster candidates preserve
#     cluster-failures.sh's own emit order — no re-sort by count or any other
#     criterion. Fixture is deliberately NOT in descending-count order. ---
D11="$WORK/d11"; mkdir -p "$D11"
run_ok OUT --clusters "$FIX/cluster-order.txt" --out-dir "$D11" --date "$DATE"
order_actual="$(grep -oE '\[cluster:[A-Z_]+:[A-Z_]+\]' "$OUT" | tr '\n' ' ')"
order_expect='[cluster:PLAN:TIMEOUT] [cluster:IMPLEMENT:ERROR] [cluster:REVIEW:FAIL] '
[ "$order_actual" = "$order_expect" ] || fail "T-051 AC7: cluster candidate order was reordered (got: $order_actual)"
pass "T-051 AC7: cluster candidates preserve the --clusters file's own line order (no re-sort)"

# --- T-051: no-cluster / degrade paths — sentinel line, empty file, unreadable
#     path, and absent flag all behave like Sources A/B's graceful degrade ---
D12="$WORK/d12"; mkdir -p "$D12"
run_ok OUT --clusters "$FIX/cluster-sentinel.txt" --out-dir "$D12" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "T-051: sentinel-only clusters input should yield 0 candidates"
grep -qF 'no cluster candidates' "$OUT" || fail "T-051: sentinel-only clusters input should leave a gap note"
pass "T-051: '(no failure clusters found)' sentinel -> 0 candidates + note, exit 0"

D13="$WORK/d13"; mkdir -p "$D13"
run_ok OUT --clusters "$FIX/empty.txt" --out-dir "$D13" --date "$DATE"
[ "$(ncand "$OUT")" -eq 0 ] || fail "T-051: empty --clusters file should yield 0 candidates"
pass "T-051: empty --clusters file -> note + exit 0"

D14="$WORK/d14"; mkdir -p "$D14"
run_ok OUT --out-dir "$D14" --date "$DATE"
grep -qF 'no cluster input given' "$OUT" || fail "T-051: absent --clusters should leave a gap note"
pass "T-051: absent --clusters -> note + exit 0 (source skipped, not an error)"

# --- T-051 AC3: propose-only invariant holds with --clusters included ---
before_c="$(cksum "$BOARD_BASE/todo.md")"
D15="$WORK/d15"; mkdir -p "$D15"
TEAM_RUN_BASE="$BOARD_BASE" run_ok OUT --discovery "$FIX/discovery-basic.txt" --rollup "$FIX/rollup-basic.txt" --clusters "$FIX/cluster-basic.txt" --out-dir "$D15" --date "$DATE"
after_c="$(cksum "$BOARD_BASE/todo.md")"
[ "$before_c" = "$after_c" ] || fail "T-051 AC3: the resolved board changed across a --clusters-inclusive run"
if grep -vE '^[[:space:]]*#' "$BIN" | grep -qE '\bgh\b'; then fail "T-051 AC3: consolidate-proposals.sh must never call gh"; fi
pass "T-051 AC3: propose-only holds with Source C added; no gh invocation"

# --- T-051: a bracket-bearing cluster run_id / signature is skipped w/ note,
#     never forging a broken [cluster:..] key ---
D16="$WORK/d16"; mkdir -p "$D16"
printf 'cluster IMPLEMENT:ERROR  count=1  run bad]id\ncluster REVIEW:FAIL  count=1  run RUN-OK\n' > "$D16/cluster-badid.txt"
run_ok OUT --clusters "$D16/cluster-badid.txt" --out-dir "$D16" --date "$DATE"
if grep -qF '[cluster:IMPLEMENT:ERROR]' "$OUT"; then fail "T-051: bracket-bearing run_id cluster must not be emitted"; fi
grep -qF '[cluster:REVIEW:FAIL]' "$OUT" || fail "T-051: the valid cluster candidate should still be emitted"
grep -qF 'skipped a cluster candidate' "$OUT" || fail "T-051: bracket-bearing cluster run_id should leave a gap note"
pass "T-051: bracket-bearing cluster run_id skipped w/ note; valid sibling cluster preserved"

# --- T-051 rework3 (Codex round1 + round2 + round3 Major, tasks/reviews/T-051.md):
#     a `cluster `-prefixed line that does not match the FULL anchored grammar
#     `cluster <PHASE>:<REASON>  count=<positive-int>  run <rid>` — REASON
#     anchored to the fixed enum, PHASE free text (round3 fix) — must be
#     REJECTED with a gap note (never emitted as a garbled candidate, never
#     silently consuming a BUDGET slot). Fixture covers round1 (markers
#     entirely missing / empty count / non-numeric count) + round2 (no colon
#     in signature / empty PHASE / empty REASON / non-enum REASON / count=0).
#     The well-formed sibling line in the same file must still be emitted. ---
D17="$WORK/d17"; mkdir -p "$D17"
run_ok OUT --clusters "$FIX/cluster-malformed.txt" --max 10 --out-dir "$D17" --date "$DATE"
[ "$(ncand "$OUT")" -eq 1 ] || fail "T-051 rework3: expected exactly 1 candidate (8 malformed rejected, 1 well-formed kept), got $(ncand "$OUT")"
grep -qF '[cluster:VALIDATE:ERROR]' "$OUT" || fail "T-051 rework3: the well-formed sibling cluster candidate must still be emitted"
if grep -qE '\[cluster:IMPLEMENT:ERROR no count' "$OUT"; then fail "T-051 rework3: a garbled candidate (missing count=/run markers) must never be emitted"; fi
if grep -qF '[cluster:REVIEW:FAIL]' "$OUT"; then fail "T-051 rework3: an empty-count cluster candidate must never be emitted"; fi
if grep -qF '[cluster:PLAN:TIMEOUT]' "$OUT"; then fail "T-051 rework3: a non-numeric-count cluster candidate must never be emitted"; fi
if grep -qF '[cluster:garbage]' "$OUT"; then fail "T-051 rework3: a no-colon signature must never be emitted"; fi
if grep -qF '[cluster::ERROR]' "$OUT"; then fail "T-051 rework3: an empty-PHASE signature must never be emitted"; fi
if grep -qF '[cluster:IMPLEMENT:]' "$OUT"; then fail "T-051 rework3: an empty-REASON signature must never be emitted"; fi
if grep -qF '[cluster:IMPLEMENT:NOTAREASON]' "$OUT"; then fail "T-051 rework3: a non-enum REASON must never be emitted"; fi
if grep -qE '\[cluster:IMPLEMENT:ERROR\]: recurring failure: IMPLEMENT:ERROR recurred 0x' "$OUT"; then fail "T-051 rework3: count=0 (producer-impossible) must never be emitted"; fi
[ "$(grep -c 'skipped a cluster candidate' "$OUT")" -eq 8 ] || fail "T-051 rework3: expected 8 gap notes (one per malformed line), got $(grep -c 'skipped a cluster candidate' "$OUT")"
grep -qF "line does not match 'cluster <PHASE>:<REASON>  count=<positive-int>  run <rid>'" "$OUT" || fail "T-051 rework3: malformed lines should note the anchored-grammar mismatch"
pass "T-051 rework3: all 8 malformed cluster shapes (round1 + round2 repros) rejected via the enum-anchored grammar, never garbled-emitted"

# --- T-051 rework3 (Codex round3 Major — rework2-specific regression, NOT a
#     round1/round2 malformed shape): PHASE is free text by producer contract
#     (docs/specs/T-043-rollup-guard-hardening.md Non-goals — log-run.sh
#     --phase / check-run.sh place no charset constraint on it beyond
#     non-empty). A legitimate space-containing or colon-containing `phase`
#     value must be ACCEPTED, not rejected as if malformed — reproduced with
#     the fixture built from the REAL end-to-end log-run.sh -> cluster-
#     failures.sh repro Codex traced (`--phase "pre deploy"`). A signature
#     whose free-text PHASE happens to contain "  count="/"  run "-like text
#     (round2's old "embedded marker" malformed case) is ALSO now correctly
#     accepted, since PHASE's charset is intentionally unconstrained — the
#     enum-anchored REASON is what makes this safe (no ambiguity: REASON only
#     ever matches at the true trailing enum-anchored `:`). ---
D23="$WORK/d23"; mkdir -p "$D23"
run_ok OUT --clusters "$FIX/cluster-phase-freetext.txt" --out-dir "$D23" --date "$DATE"
[ "$(ncand "$OUT")" -eq 3 ] || fail "T-051 rework3: expected all 3 free-text-PHASE lines accepted, got $(ncand "$OUT")"
grep -qF '[cluster:PRE DEPLOY:ERROR]' "$OUT" || fail "T-051 rework3: a space-containing PHASE (the real 'pre deploy' repro) must be accepted, not rejected"
grep -qF 'starting at run RUN-SPACEY' "$OUT" || fail "T-051 rework3: the space-containing-PHASE candidate's run_id must be preserved"
grep -qF '[cluster:LEAK-C:\\USERS\\FOO:TIMEOUT]' "$OUT" || fail "T-051 rework3: a colon-containing PHASE must resolve to the rightmost enum-anchored REASON match, not be rejected"
grep -qF '[cluster:IMPLEMENT  count=99:ERROR]' "$OUT" || fail "T-051 rework3: a PHASE containing embedded 'count='/'run '-like text must be accepted (free text, not malformed)"
if grep -qF 'skipped a cluster candidate' "$OUT"; then fail "T-051 rework3: no legitimate free-text-PHASE line should be rejected"; fi
pass "T-051 rework3: free-text PHASE (space / colon / embedded-marker-like text) is accepted, closing the round3 regression"

# --- T-051 rework3: the real log-run.sh -> cluster-failures.sh ->
#     consolidate-proposals.sh chain (not a hand-written --clusters file) must
#     surface a space-containing phase as a candidate — this is Codex round3's
#     own end-to-end verification method, reproduced here as a fixture-suite
#     assertion so it stays pinned. ---
D24="$WORK/d24"; mkdir -p "$D24/runs"
LOOP_ID="t051-round3-e2e"
TEAM_RUNS_DIR="$D24/runs" bash "$REPO_ROOT/bin/log-run.sh" "$LOOP_ID" --run-id RUN-E2E --seq 1 --span implement --phase "pre deploy" --iteration 0 --attempt 0 --status error >/dev/null
TEAM_RUNS_DIR="$D24/runs" bash "$REPO_ROOT/bin/log-run.sh" "$LOOP_ID" --run-id RUN-E2E --seq 2 --span implement --phase "pre deploy" --iteration 0 --attempt 0 --status error >/dev/null
bash "$REPO_ROOT/bin/cluster-failures.sh" "$D24/runs/$LOOP_ID.jsonl" > "$D24/clusters.txt"
grep -qF 'cluster PRE DEPLOY:ERROR' "$D24/clusters.txt" || fail "T-051 rework3: real cluster-failures.sh should emit the space-containing-phase cluster line"
run_ok OUT --clusters "$D24/clusters.txt" --out-dir "$D24/out" --date "$DATE"
grep -qF '[cluster:PRE DEPLOY:ERROR]' "$OUT" || fail "T-051 rework3: real end-to-end log-run.sh -> cluster-failures.sh -> consolidate-proposals.sh chain must surface the space-containing-phase candidate"
pass "T-051 rework3: real end-to-end log-run.sh -> cluster-failures.sh -> consolidate-proposals.sh chain accepts a space-containing phase"

# --- T-051 rework3: a malformed cluster line must not consume a BUDGET slot
#     ahead of a valid candidate (same "reject, don't crowd out" contract as
#     Source A's keyless-line rejection, NEW-M-2 above) ---
D18="$WORK/d18"; mkdir -p "$D18"
printf 'cluster IMPLEMENT:ERROR no count no run marker at all\ncluster VALIDATE:ERROR  count=2  run RUN-OK\n' > "$D18/cluster-malformed-budget.txt"
run_ok OUT --clusters "$D18/cluster-malformed-budget.txt" --max 1 --out-dir "$D18" --date "$DATE"
[ "$(ncand "$OUT")" -eq 1 ] || fail "T-051 rework3: --max 1 should still yield the 1 valid candidate, got $(ncand "$OUT")"
grep -qF '[cluster:VALIDATE:ERROR]' "$OUT" || fail "T-051 rework3: the valid candidate must survive (malformed line must not crowd it out of budget)"
if grep -qF 'truncated:' "$OUT"; then fail "T-051 rework3: a rejected malformed line must not count toward --max truncation"; fi
pass "T-051 rework3: a malformed cluster line does not consume --max BUDGET ahead of a valid candidate"

# --- Regression guard: existing well-formed fixtures (AC1/AC6/AC7) are
#     unaffected by the anchored grammar ---
run_ok OUT --clusters "$FIX/cluster-basic.txt" --out-dir "$WORK/d19" --date "$DATE"
[ "$(ncand "$OUT")" -eq 2 ] || fail "T-051 rework3 regression: cluster-basic.txt should still yield 2 candidates, got $(ncand "$OUT")"
run_ok OUT --rollup "$FIX/rollup-overlap.txt" --clusters "$FIX/cluster-run-overlap.txt" --out-dir "$WORK/d20" --date "$DATE"
[ "$(ncand "$OUT")" -eq 3 ] || fail "T-051 rework3 regression: AC6 run-overlap fixture should still yield 3 candidates, got $(ncand "$OUT")"
run_ok OUT --clusters "$FIX/cluster-order.txt" --out-dir "$WORK/d21" --date "$DATE"
order_actual2="$(grep -oE '\[cluster:[A-Z_]+:[A-Z_]+\]' "$OUT" | tr '\n' ' ')"
[ "$order_actual2" = '[cluster:PLAN:TIMEOUT] [cluster:IMPLEMENT:ERROR] [cluster:REVIEW:FAIL] ' ] || fail "T-051 rework3 regression: AC7 order fixture was reordered (got: $order_actual2)"
pass "T-051 rework3: well-formed fixtures (AC1/AC6/AC7) unaffected by the anchored grammar"

# --- T-051 rework3 regression: an ISO-8601 run_id (legitimately containing
#     colons) must still be ACCEPTED by the anchored grammar's run_id capture
#     (run_id is free text, like PHASE, never constrained) — same acceptance
#     M-1 already pins for Source B. ---
D22="$WORK/d22"; mkdir -p "$D22"
printf 'cluster IMPLEMENT:ERROR  count=1  run 2026-06-18T12:00:00Z\n' > "$D22/cluster-iso.txt"
run_ok OUT --clusters "$D22/cluster-iso.txt" --out-dir "$D22" --date "$DATE"
grep -qF '[cluster:IMPLEMENT:ERROR]' "$OUT" || fail "T-051 rework3: an ISO-8601 (colon-bearing) run_id must not cause the whole line to be rejected"
grep -qF 'starting at run 2026-06-18T12:00:00Z' "$OUT" || fail "T-051 rework3: the ISO-8601 run_id itself should be preserved verbatim"
pass "T-051 rework3: ISO-8601 (colon-bearing) run_id still accepted by the anchored grammar"

# --- usage errors ---
assert_rc "bad --max -> 2"      2 --max abc --out-dir "$WORK" --date "$DATE"
assert_rc "bad --date -> 2"     2 --date 2026/06/18 --out-dir "$WORK"
assert_rc "unknown flag -> 2"   2 --bogus
assert_rc "--max missing val -> 2" 2 --max
assert_rc "--clusters missing val -> 2" 2 --clusters

printf '\nAll consolidate-proposals assertions passed.\n'
