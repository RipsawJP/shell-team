#!/usr/bin/env bash
# run.sh — drive bin/check-fanout-instances.sh against fixtures built from
# the REAL producers (bin/aggregate-verdicts.sh, bin/log-run.sh) rather than
# hand-written telemetry/block text, and assert its four-property refusal
# surface by name (T-1082;
# .shell-team/specs/T-1082-telemetry-discriminator.md AC1-AC11/AC14).
#
# Case ids, named here verbatim so the eleven-class refusal surface can
# never be quietly narrowed to the happy path: ok-success, usage,
# block-not-found, duplicate-block, malformed-block, malformed-row,
# missing-instance, invalid-instance, instance-role-collision,
# unattributed-instance, uncovered-part, no-rows.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-fanout-instances.sh"
AGG="$REPO_ROOT/bin/aggregate-verdicts.sh"
LOGRUN="$REPO_ROOT/bin/log-run.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# Explicit ${TMPDIR:-/tmp} template (repo convention, T-038/T-112).
T="$(mktemp -d "${TMPDIR:-/tmp}/check-fanout-instances-suite.XXXXXX")"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$T" 2>/dev/null || true; }
trap cleanup EXIT

EM=$'\xe2\x80\x94'

run_check() {
  # run_check <outfile> <errfile> <args...> — invokes the real script, never
  # aborting the suite itself on a non-zero exit (that is the thing under
  # test).
  local out="$1" err="$2"
  shift 2
  if bash "$SCRIPT" "$@" >"$out" 2>"$err"; then
    printf '0'
  else
    printf '%s' "$?"
  fi
}

log_span() {
  # log_span <runs-dir> <run-id> <role> <phase> <iteration> <attempt> <instance-or-empty>
  local runs="$1" run="$2" role="$3" phase="$4" iter="$5" att="$6" inst="$7"
  if [ -n "$inst" ]; then
    TEAM_RUNS_DIR="$runs" bash "$LOGRUN" tl --run-id "$run" --seq auto --span "$role" --phase "$phase" --iteration "$iter" --attempt "$att" --status success --instance "$inst" >/dev/null 2>&1
  else
    TEAM_RUNS_DIR="$runs" bash "$LOGRUN" tl --run-id "$run" --seq auto --span "$role" --phase "$phase" --iteration "$iter" --attempt "$att" --status success >/dev/null 2>&1
  fi
}

build_two_part_agg() {
  # build_two_part_agg <outfile> — a two-unit, two-part fanout-verdict block
  # via the real aggregator, label t1082-suite, parts qa-1/qa-2.
  local out="$1" pop p1 p2
  pop="$T/pop.$$.$RANDOM"; p1="$T/p1.$$.$RANDOM"; p2="$T/p2.$$.$RANDOM"
  printf '%s\n' u1 u2 > "$pop"
  { printf -- '- unit: u1\n'; printf -- '- verdict: u1 %s PASS\n' "$EM"; } > "$p1"
  { printf -- '- unit: u2\n'; printf -- '- verdict: u2 %s PASS\n' "$EM"; } > "$p2"
  bash "$AGG" --label t1082-suite --population "$pop" --part qa-1="$p1" --part qa-2="$p2" > "$out" 2>/dev/null
}

# =============================================================================
# case: ok-success — a well-formed fan-out passes, exactly one stdout line
# matching the ok prefix, empty stderr.
# =============================================================================
AGGF="$T/agg-main"
build_two_part_agg "$AGGF"
RUNS_MAIN="$T/runs-main"
log_span "$RUNS_MAIN" R1 qa-verifier verify 1 1 qa-1
log_span "$RUNS_MAIN" R1 qa-verifier verify 1 1 qa-2
TEL_MAIN="$RUNS_MAIN/tl.jsonl"
if [ ! -s "$TEL_MAIN" ]; then
  fail "ok-success: fixture setup — telemetry file was not written"
else
  rc="$(run_check "$T/ok.out" "$T/ok.err" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
  if [ "$rc" = "0" ] && [ "$(grep -c . "$T/ok.out" || true)" = "1" ] && grep -q '^check-fanout-instances: ok: ' "$T/ok.out" && [ "$(grep -c . "$T/ok.err" || true)" = "0" ]; then
    pass "ok-success: a well-formed fan-out exits 0 with exactly one ok line, empty stderr"
  else
    fail "ok-success: rc=$rc out=$(cat "$T/ok.out" 2>/dev/null) err=$(cat "$T/ok.err" 2>/dev/null)"
  fi
fi

# =============================================================================
# case: usage — every invocation-surface defect exits 2 with empty stdout.
# =============================================================================
usage_case() {
  local desc="$1" expect_class="$2"; shift 2
  local rc
  rc="$(run_check "$T/u.out" "$T/u.err" "$@")"
  if [ "$rc" = "2" ] && [ "$(grep -c . "$T/u.out" || true)" = "0" ]; then
    if [ -z "$expect_class" ] || grep -q -- "$expect_class" "$T/u.err"; then
      pass "usage: $desc exits 2 with empty stdout"
    else
      fail "usage: $desc exited 2 but stderr did not name class '$expect_class': $(cat "$T/u.err" 2>/dev/null)"
    fi
  else
    fail "usage: $desc — expected exit 2 with empty stdout, got rc=$rc out=$(cat "$T/u.out" 2>/dev/null)"
  fi
}

usage_case "missing --telemetry" "" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite
usage_case "missing --run-id" "" --telemetry "$TEL_MAIN" --phase verify --aggregation "$AGGF" --label t1082-suite
usage_case "missing --phase" "" --telemetry "$TEL_MAIN" --run-id R1 --aggregation "$AGGF" --label t1082-suite
usage_case "missing --aggregation" "" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --label t1082-suite
usage_case "missing --label" "" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGF"
usage_case "unknown flag" "" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite --bogus 1
usage_case "nonexistent --telemetry path" "" --telemetry "$T/nope.jsonl" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite
usage_case "nonexistent --aggregation path" "" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$T/nope.txt" --label t1082-suite
usage_case "bad --label grammar" "" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGF" --label 'bad label'
usage_case "a label naming no block" "block-not-found" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGF" --label nosuchlabel

# =============================================================================
# case: duplicate-block — a file carrying two blocks for the requested label
# exits 1, never 2 — a content ambiguity, not an invocation defect.
# =============================================================================
AGG2="$T/agg-dup"
cat "$AGGF" "$AGGF" > "$AGG2"
rc="$(run_check "$T/dup.out" "$T/dup.err" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGG2" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'duplicate-block' "$T/dup.err" && [ "$(grep -c . "$T/dup.out" || true)" = "0" ]; then
  pass "duplicate-block: two blocks sharing the requested label exit 1 with empty stdout"
else
  fail "duplicate-block: rc=$rc err=$(cat "$T/dup.err" 2>/dev/null)"
fi

# =============================================================================
# case: malformed-block — a '- part:' name violating the writer's own
# grammar exits 1.
# =============================================================================
AGGBAD="$T/agg-badpart"
sed 's|^- part: qa-2 |- part: QA_2 |' "$AGGF" > "$AGGBAD"
rc="$(run_check "$T/bb.out" "$T/bb.err" --telemetry "$TEL_MAIN" --run-id R1 --phase verify --aggregation "$AGGBAD" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'malformed-block' "$T/bb.err" && [ "$(grep -c . "$T/bb.out" || true)" = "0" ]; then
  pass "malformed-block: a '- part:' name violating ^[a-z][a-z0-9-]*\$ exits 1 with empty stdout"
else
  fail "malformed-block: rc=$rc err=$(cat "$T/bb.err" 2>/dev/null)"
fi

# =============================================================================
# case: missing-instance — a scope mixing a serial round (no --instance) and
# a fanned round of the same phase refuses missing-instance unnarrowed;
# narrowing with --iteration passes. An absent instance key reads
# identically to "instance":null.
# =============================================================================
RUNS_MIX="$T/runs-mix"
log_span "$RUNS_MIX" R1 qa-verifier verify 1 1 ""
log_span "$RUNS_MIX" R1 qa-verifier verify 2 1 qa-1
log_span "$RUNS_MIX" R1 qa-verifier verify 2 1 qa-2
TEL_MIX="$RUNS_MIX/tl.jsonl"
rc="$(run_check "$T/mi.out" "$T/mi.err" --telemetry "$TEL_MIX" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'missing-instance' "$T/mi.err" && [ "$(grep -c . "$T/mi.out" || true)" = "0" ]; then
  pass "missing-instance: an unnarrowed mixed serial/fanned scope exits 1 with empty stdout"
else
  fail "missing-instance: rc=$rc err=$(cat "$T/mi.err" 2>/dev/null)"
fi
rc="$(run_check "$T/mi2.out" "$T/mi2.err" --telemetry "$TEL_MIX" --run-id R1 --phase verify --iteration 2 --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "0" ]; then
  pass "missing-instance: the same corpus narrowed with --iteration 2 exits 0"
else
  fail "missing-instance: narrowed arm expected exit 0, got rc=$rc"
fi
# absent instance key (pre-T-1072 row shape) is treated identically.
TEL_NOKEY="$T/tel-nokey.jsonl"
sed 's|,"instance":"qa-1"||' "$TEL_MIX" > "$TEL_NOKEY"
if grep -q '"instance":"qa-1"' "$TEL_NOKEY"; then
  fail "missing-instance: fixture mutation did not remove the instance key"
else
  rc="$(run_check "$T/mi3.out" "$T/mi3.err" --telemetry "$TEL_NOKEY" --run-id R1 --phase verify --iteration 2 --aggregation "$AGGF" --label t1082-suite)"
  if [ "$rc" = "1" ] && grep -q 'missing-instance' "$T/mi3.err"; then
    pass "missing-instance: a row with the instance key entirely absent refuses identically to a null one"
  else
    fail "missing-instance: absent-key row — rc=$rc err=$(cat "$T/mi3.err" 2>/dev/null)"
  fi
fi

# =============================================================================
# case: invalid-instance — a value the writer itself would refuse (bad
# charset) exits 1 with class invalid-instance, for each of four shapes.
# =============================================================================
i=0
for bad in QA 2 a_b 'x/y'; do
  i=$((i + 1))
  BADF="$T/inv-$i.jsonl"
  sed "s|\"instance\":\"qa-2\"|\"instance\":\"$bad\"|" "$TEL_MAIN" > "$BADF"
  rc="$(run_check "$T/inv-$i.out" "$T/inv-$i.err" --telemetry "$BADF" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
  if [ "$rc" = "1" ] && grep -q 'invalid-instance' "$T/inv-$i.err" && [ "$(grep -c . "$T/inv-$i.out" || true)" = "0" ]; then
    pass "invalid-instance: bad shape '$bad' exits 1 with empty stdout"
  else
    fail "invalid-instance: bad shape '$bad' — rc=$rc err=$(cat "$T/inv-$i.err" 2>/dev/null)"
  fi
done

# =============================================================================
# case: malformed-row — an event row that satisfies the scope selector (a
# hand-added "phase" key) is refused rather than silently skipped; an
# ordinary event row with no phase key at all stays out of scope and the
# corpus still passes.
# =============================================================================
RUNS_EV="$T/runs-event"
log_span "$RUNS_EV" R1 qa-verifier verify 1 1 qa-1
log_span "$RUNS_EV" R1 qa-verifier verify 1 1 qa-2
TEAM_RUNS_DIR="$RUNS_EV" bash "$LOGRUN" tl --run-id R1 --seq auto --event gate --from verify --label PASS >/dev/null 2>&1
TEL_EV="$RUNS_EV/tl.jsonl"
if ! grep -qF -- '"kind":"event"' "$TEL_EV"; then
  fail "malformed-row: fixture setup — no event row present in the corpus"
else
  rc="$(run_check "$T/mr0.out" "$T/mr0.err" --telemetry "$TEL_EV" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
  if [ "$rc" = "0" ]; then
    pass "malformed-row: an ordinary event row (no phase key) stays out of scope by construction; the corpus still passes"
  else
    fail "malformed-row: baseline arm expected exit 0, got rc=$rc"
  fi
fi
TEL_EV2="$T/tel-ev2.jsonl"
cp "$TEL_EV" "$TEL_EV2"
printf '%s\n' '{"loop_id":"tl","run_id":"R1","seq":9,"ts":"2026-08-18T00:00:09Z","kind":"event","event":"gate","from":"verify","to":null,"label":"PASS","phase":"verify"}' >> "$TEL_EV2"
rc="$(run_check "$T/mr.out" "$T/mr.err" --telemetry "$TEL_EV2" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'malformed-row' "$T/mr.err" && [ "$(grep -c . "$T/mr.out" || true)" = "0" ]; then
  pass "malformed-row: an event row hand-edited to carry the scope's own phase key is refused rather than silently skipped"
else
  fail "malformed-row: rc=$rc err=$(cat "$T/mr.err" 2>/dev/null)"
fi

# =============================================================================
# case: instance-role-collision — one id claimed by rows of two DIFFERENT
# roles refuses; the same id on two rows of the SAME role stays legal.
# =============================================================================
POP1="$T/pop1"; PP1="$T/pp1"
printf '%s\n' u1 > "$POP1"
{ printf -- '- unit: u1\n'; printf -- '- verdict: u1 %s PASS\n' "$EM"; } > "$PP1"
AGG1="$T/agg-single"
bash "$AGG" --label t1082-suite --population "$POP1" --part qa-1="$PP1" > "$AGG1" 2>/dev/null

RUNS_SAME="$T/runs-samerole"
log_span "$RUNS_SAME" R2 qa-verifier verify 1 1 qa-1
log_span "$RUNS_SAME" R2 qa-verifier verify 1 1 qa-1
TEL_SAME="$RUNS_SAME/tl.jsonl"
rc="$(run_check "$T/sr.out" "$T/sr.err" --telemetry "$TEL_SAME" --run-id R2 --phase verify --aggregation "$AGG1" --label t1082-suite)"
if [ "$rc" = "0" ]; then
  pass "instance-role-collision: the same id on two rows of the SAME role stays legal (exit 0)"
else
  fail "instance-role-collision: same-role reuse arm expected exit 0, got rc=$rc"
fi

RUNS_DIFF="$T/runs-diffrole"
log_span "$RUNS_DIFF" R2 qa-verifier verify 1 1 qa-1
log_span "$RUNS_DIFF" R2 engineer verify 1 1 qa-1
TEL_DIFF="$RUNS_DIFF/tl.jsonl"
rc="$(run_check "$T/dr.out" "$T/dr.err" --telemetry "$TEL_DIFF" --run-id R2 --phase verify --aggregation "$AGG1" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'instance-role-collision' "$T/dr.err" && [ "$(grep -c . "$T/dr.out" || true)" = "0" ]; then
  pass "instance-role-collision: the same id claimed by two DIFFERENT roles exits 1 with empty stdout"
else
  fail "instance-role-collision: rc=$rc err=$(cat "$T/dr.err" 2>/dev/null)"
fi

# =============================================================================
# case: unattributed-instance — an id in the scope's rows declared by no
# '- part:' line in the block is a CONTENT defect (exit 1).
# =============================================================================
TEL_UNATTR="$T/tel-unattr.jsonl"
sed 's|"instance":"qa-2"|"instance":"qa-9"|' "$TEL_MAIN" > "$TEL_UNATTR"
rc="$(run_check "$T/ua.out" "$T/ua.err" --telemetry "$TEL_UNATTR" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "1" ] && grep -q 'unattributed-instance' "$T/ua.err" && [ "$(grep -c . "$T/ua.out" || true)" = "0" ]; then
  pass "unattributed-instance: an id declared by no '- part:' line exits 1 with empty stdout"
else
  fail "unattributed-instance: rc=$rc err=$(cat "$T/ua.err" 2>/dev/null)"
fi

# =============================================================================
# case: uncovered-part — a part declared in the block with no row in scope
# is INCOMPLETE (exit 3), never exit 1.
# =============================================================================
TEL_UNCOV="$T/tel-uncov.jsonl"
grep -v '"instance":"qa-2"' "$TEL_MAIN" > "$TEL_UNCOV"
rc="$(run_check "$T/uc.out" "$T/uc.err" --telemetry "$TEL_UNCOV" --run-id R1 --phase verify --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "3" ] && grep -q 'uncovered-part' "$T/uc.err" && [ "$(grep -c . "$T/uc.out" || true)" = "0" ]; then
  pass "uncovered-part: a declared part with no covering row exits 3 with empty stdout"
else
  fail "uncovered-part: rc=$rc err=$(cat "$T/uc.err" 2>/dev/null)"
fi

# =============================================================================
# case: no-rows — a scope selecting zero span rows is INCOMPLETE (exit 3),
# distinct from uncovered-part.
# =============================================================================
rc="$(run_check "$T/nr.out" "$T/nr.err" --telemetry "$TEL_MAIN" --run-id RZ --phase verify --aggregation "$AGGF" --label t1082-suite)"
if [ "$rc" = "3" ] && grep -q 'no-rows' "$T/nr.err" && [ "$(grep -c . "$T/nr.out" || true)" = "0" ]; then
  pass "no-rows: a scope selecting zero span rows exits 3 with empty stdout"
else
  fail "no-rows: rc=$rc err=$(cat "$T/nr.err" 2>/dev/null)"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-fanout-instances suite: all assertions passed\n'
  exit 0
else
  printf 'check-fanout-instances suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
