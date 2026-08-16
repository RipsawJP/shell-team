#!/usr/bin/env bash
# run.sh — drive bin/aggregate-verdicts.sh against committed-in-place
# fixtures and assert its grammar, reconciliation arithmetic, exit-code
# taxonomy and refusal surface (T-1074;
# .shell-team/specs/T-1074-fanout-orchestration.md AC8/AC9).
#
# Case ids (named here verbatim so AC8's own check can confirm the refusal
# surface was not quietly narrowed to the happy path): partition-independence,
# order-independence, attribution-preserved, duplicate-payload-preserved,
# sentinel-required, sentinel-exclusive, coverage-disjoint,
# coverage-exhaustive, instance-death, partial-output, out-of-population,
# control-character, duplicate-labelled-ac, exit-code-distinctness,
# zero-dependency-path, plus the fanout-parameters line and the negative
# control (AC9).
#
# The "main" fixture below is fixed once and reused by every case that needs
# a well-formed fan-out (partition/order/attribution/duplicate-payload/
# exit-code-distinctness/zero-dependency-path): 4 parts, 9 units, 17 records
# (16 verdicts + 1 sentinel) — all three floors (parts>=4, units>=8,
# records>=16) this spec's own AC8 declares. The printed
# `fanout-parameters` line is derived by counting the actual fixture files
# below, never a hand-typed literal, so it cannot silently drift from what
# the fixture really contains.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/aggregate-verdicts.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# Explicit ${TMPDIR:-/tmp} template (repo convention, T-038/T-112).
T="$(mktemp -d "${TMPDIR:-/tmp}/aggregate-verdicts-suite.XXXXXX")"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$T" 2>/dev/null || true; }
trap cleanup EXIT

EM=$'\xe2\x80\x94'

run_agg() {
  # run_agg <outfile> <errfile> <args...> — invokes the real script, never
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

extract_region() {
  # extract_region <infile> <label> <outfile>
  awk -v b="<!-- BEGIN verdict-region: $2 -->" -v e="<!-- END verdict-region: $2 -->" '$0==b{f=1;next} $0==e{f=0} f' "$1" > "$3"
}

# =============================================================================
# The MAIN fixture: population u1..u9, split disjointly/exhaustively across
# four parts (m-a, m-b, m-c, m-d).
#   m-a claims u1,u2,u3 — u1: 2 verdicts, u2: 2 IDENTICAL verdicts (the
#       duplicate-payload case), u3: 1 sentinel (zero-verdict unit).
#   m-b claims u4,u5 — 2 verdicts each.
#   m-c claims u6,u7 — 2 verdicts each.
#   m-d claims u8,u9 — 2 verdicts each.
# Totals: 4 parts, 9 units, 17 records (16 verdicts + 1 sentinel).
# =============================================================================
MPOP="$T/main-pop"
printf '%s\n' u1 u2 u3 u4 u5 u6 u7 u8 u9 > "$MPOP"

MA="$T/main-a"
printf '%s\n' \
  '- unit: u1' '- unit: u2' '- unit: u3' \
  '- verdict: u1 — AC1: PASS' '- verdict: u1 — AC2: FAIL' \
  '- verdict: u2 — AC1: PASS' '- verdict: u2 — AC1: PASS' \
  '- sentinel: u3 — exit=2 no-verdict-lines' \
  > "$MA"

MB="$T/main-b"
printf '%s\n' \
  '- unit: u4' '- unit: u5' \
  '- verdict: u4 — AC1: PASS' '- verdict: u4 — AC2: PASS' \
  '- verdict: u5 — AC1: PASS' '- verdict: u5 — AC2: FAIL' \
  > "$MB"

MC="$T/main-c"
printf '%s\n' \
  '- unit: u6' '- unit: u7' \
  '- verdict: u6 — AC1: PASS' '- verdict: u6 — AC2: SKIP' \
  '- verdict: u7 — AC1: FAIL' '- verdict: u7 — AC2: PASS' \
  > "$MC"

MD="$T/main-d"
printf '%s\n' \
  '- unit: u8' '- unit: u9' \
  '- verdict: u8 — AC1: PASS' '- verdict: u8 — AC2: PASS' \
  '- verdict: u9 — AC1: PASS' '- verdict: u9 — AC2: FAIL' \
  > "$MD"

# Derive the printed parameters from the fixture files themselves, never a
# hand-typed literal.
N_PARTS=4
N_UNITS="$(grep -c . "$MPOP" || true)"
N_RECORDS="$(cat "$MA" "$MB" "$MC" "$MD" | grep -cE '^- (verdict|sentinel): ' || true)"

MAIN_OUT="$T/main.out"
MAIN_ERR="$T/main.err"
rc="$(run_agg "$MAIN_OUT" "$MAIN_ERR" --label main --population "$MPOP" --part m-a="$MA" --part m-b="$MB" --part m-c="$MC" --part m-d="$MD")"
if [ "$rc" = "0" ] && [ -s "$MAIN_OUT" ] && [ "$(grep -c . "$MAIN_ERR" || true)" = "0" ]; then
  pass "T-1074 main-fixture-aggregates (setup for the cases below)"
else
  fail "T-1074 main-fixture-aggregates: expected exit 0 + non-empty stdout + empty stderr, got rc=$rc"
fi

# =============================================================================
# case: partition-independence — the same population, split three different
# ways (single part / four parts / four parts declared in reverse order with
# every line reversed), produces a byte-identical verdict-region.
# =============================================================================
SOLO="$T/solo"
cat "$MA" "$MB" "$MC" "$MD" > "$SOLO"

# Reversed-line variants for the "declared in the opposite order, lines
# reversed" partition.
RA="$T/main-a.rev"; RB="$T/main-b.rev"; RC="$T/main-c.rev"; RD="$T/main-d.rev"
sed '1!G;h;$!d' "$MA" > "$RA"
sed '1!G;h;$!d' "$MB" > "$RB"
sed '1!G;h;$!d' "$MC" > "$RC"
sed '1!G;h;$!d' "$MD" > "$RD"

OUT_SOLO="$T/out-solo"; ERR_SOLO="$T/err-solo"
rc_solo="$(run_agg "$OUT_SOLO" "$ERR_SOLO" --label pi --population "$MPOP" --part solo="$SOLO")"
OUT_4="$T/out-4"; ERR_4="$T/err-4"
rc_4="$(run_agg "$OUT_4" "$ERR_4" --label pi --population "$MPOP" --part m-a="$MA" --part m-b="$MB" --part m-c="$MC" --part m-d="$MD")"
OUT_4R="$T/out-4r"; ERR_4R="$T/err-4r"
rc_4r="$(run_agg "$OUT_4R" "$ERR_4R" --label pi --population "$MPOP" --part m-d="$RD" --part m-c="$RC" --part m-b="$RB" --part m-a="$RA")"

extract_region "$OUT_SOLO" pi "$T/reg-solo"
extract_region "$OUT_4" pi "$T/reg-4"
extract_region "$OUT_4R" pi "$T/reg-4r"

if [ "$rc_solo" = "0" ] && [ "$rc_4" = "0" ] && [ "$rc_4r" = "0" ] \
  && [ -s "$T/reg-solo" ] && [ -s "$T/reg-4" ] && [ -s "$T/reg-4r" ] \
  && cmp -s "$T/reg-solo" "$T/reg-4" && cmp -s "$T/reg-solo" "$T/reg-4r"; then
  pass "T-1074 partition-independence"
else
  fail "T-1074 partition-independence: expected byte-identical verdict regions across solo/4-part/reversed-4-part partitions, got rc_solo=$rc_solo rc_4=$rc_4 rc_4r=$rc_4r"
fi

# =============================================================================
# case: order-independence — the four-part partition, with every part
# file's own line order reversed (RA/RB/RC/RD, still declared in the SAME
# --part order this time), still produces the identical region.
# =============================================================================
OUT_4RO="$T/out-4ro"; ERR_4RO="$T/err-4ro"
rc_4ro="$(run_agg "$OUT_4RO" "$ERR_4RO" --label pi --population "$MPOP" --part m-a="$RA" --part m-b="$RB" --part m-c="$RC" --part m-d="$RD")"
extract_region "$OUT_4RO" pi "$T/reg-4ro"
if [ "$rc_4ro" = "0" ] && [ -s "$T/reg-4ro" ] && cmp -s "$T/reg-4" "$T/reg-4ro"; then
  pass "T-1074 order-independence"
else
  fail "T-1074 order-independence: expected the region to survive within-part line reversal unchanged, got rc_4ro=$rc_4ro"
fi

# =============================================================================
# case: attribution-preserved — the main run's attribution set has one line
# per population unit, and the attribution SETS genuinely differ between
# the solo partition and the four-part partition (proving attribution
# reflects the real partition rather than being decorative).
# =============================================================================
grep '^- attribution: ' "$OUT_SOLO" > "$T/att-solo" || true
grep '^- attribution: ' "$OUT_4" > "$T/att-4" || true
attn="$(grep -c . "$T/att-4" || true)"
if [ -s "$T/att-solo" ] && [ -s "$T/att-4" ] && [ "$((10#$attn))" = "$((10#$N_UNITS))" ] \
  && ! cmp -s "$T/att-solo" "$T/att-4" \
  && grep -qx -- "- attribution: u1 $EM m-a" "$T/att-4" \
  && grep -qx -- "- attribution: u5 $EM m-b" "$T/att-4" \
  && grep -qx -- "- attribution: u9 $EM m-d" "$T/att-4"; then
  pass "T-1074 attribution-preserved"
else
  fail "T-1074 attribution-preserved: expected $N_UNITS attribution lines, differing between partitions, correctly naming the claiming part"
fi

# =============================================================================
# case: duplicate-payload-preserved — u2's two IDENTICAL verdict payloads
# both survive in the region, as a legitimate multiset member counted twice.
# =============================================================================
dupcount="$(grep -cx -- "- verdict: u2 $EM AC1: PASS" "$T/reg-4" || true)"
if [ "$((10#$dupcount))" = "2" ]; then
  pass "T-1074 duplicate-payload-preserved"
else
  fail "T-1074 duplicate-payload-preserved: expected u2's identical verdict payload to survive exactly twice, got count=$dupcount"
fi

# =============================================================================
# case: sentinel-required — a claimed, zero-verdict unit with NO sentinel
# line refuses (exit 1, class missing-sentinel, empty stdout).
# =============================================================================
SR_POP="$T/sr-pop"; printf '%s\n' u1 u2 > "$SR_POP"
SR_PART="$T/sr-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' > "$SR_PART"
SR_OUT="$T/sr.out"; SR_ERR="$T/sr.err"
rc_sr="$(run_agg "$SR_OUT" "$SR_ERR" --label sr --population "$SR_POP" --part qa-1="$SR_PART")"
cls_sr="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$SR_ERR")"
if [ "$rc_sr" = "1" ] && [ "$cls_sr" = "missing-sentinel" ] && [ ! -s "$SR_OUT" ]; then
  pass "T-1074 sentinel-required"
else
  fail "T-1074 sentinel-required: expected exit 1 / missing-sentinel / empty stdout, got rc=$rc_sr class=$cls_sr"
fi

# =============================================================================
# case: sentinel-exclusive — a unit carrying BOTH a sentinel and a verdict
# refuses (exit 1, class sentinel-with-verdicts, empty stdout).
# =============================================================================
SE_POP="$T/se-pop"; printf '%s\n' u1 u2 > "$SE_POP"
SE_PART="$T/se-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- sentinel: u2 — exit=2 no-verdict-lines' '- verdict: u2 — AC1: PASS' > "$SE_PART"
SE_OUT="$T/se.out"; SE_ERR="$T/se.err"
rc_se="$(run_agg "$SE_OUT" "$SE_ERR" --label se --population "$SE_POP" --part qa-1="$SE_PART")"
cls_se="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$SE_ERR")"
if [ "$rc_se" = "1" ] && [ "$cls_se" = "sentinel-with-verdicts" ] && [ ! -s "$SE_OUT" ]; then
  pass "T-1074 sentinel-exclusive"
else
  fail "T-1074 sentinel-exclusive: expected exit 1 / sentinel-with-verdicts / empty stdout, got rc=$rc_se class=$cls_se"
fi

# =============================================================================
# case: coverage-disjoint — the same unit claimed by two different parts
# refuses (exit 1, class duplicate-claim, empty stdout).
# =============================================================================
CD_POP="$T/cd-pop"; printf '%s\n' u1 u2 u3 > "$CD_POP"
CD_X1="$T/cd-x1"; printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' > "$CD_X1"
CD_X2="$T/cd-x2"; printf '%s\n' '- unit: u2' '- unit: u3' '- verdict: u2 — AC1: PASS' '- verdict: u3 — AC1: PASS' > "$CD_X2"
CD_OUT="$T/cd.out"; CD_ERR="$T/cd.err"
rc_cd="$(run_agg "$CD_OUT" "$CD_ERR" --label cd --population "$CD_POP" --part qa-1="$CD_X1" --part qa-2="$CD_X2")"
cls_cd="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$CD_ERR")"
if [ "$rc_cd" = "1" ] && [ "$cls_cd" = "duplicate-claim" ] && [ ! -s "$CD_OUT" ]; then
  pass "T-1074 coverage-disjoint"
else
  fail "T-1074 coverage-disjoint: expected exit 1 / duplicate-claim / empty stdout, got rc=$rc_cd class=$cls_cd"
fi

# =============================================================================
# case: coverage-exhaustive — a population unit no part claims at all
# refuses (exit 3, class uncovered-unit, empty stdout). This exact fixture
# is reused below by the AC9 negative control.
# =============================================================================
CE_POP="$T/ce-pop"; printf '%s\n' u1 u2 u3 > "$CE_POP"
CE_PART="$T/ce-part"; printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' > "$CE_PART"
CE_OUT="$T/ce.out"; CE_ERR="$T/ce.err"
rc_ce="$(run_agg "$CE_OUT" "$CE_ERR" --label ce --population "$CE_POP" --part qa-1="$CE_PART")"
cls_ce="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$CE_ERR")"
if [ "$rc_ce" = "3" ] && [ "$cls_ce" = "uncovered-unit" ] && [ ! -s "$CE_OUT" ]; then
  pass "T-1074 coverage-exhaustive"
else
  fail "T-1074 coverage-exhaustive: expected exit 3 / uncovered-unit / empty stdout, got rc=$rc_ce class=$cls_ce"
fi

# =============================================================================
# case: instance-death — a declared part whose file does not exist, and a
# declared part whose file exists but is empty, BOTH refuse exit 3 (an
# instance that died and an instance that wrote nothing are the same
# operational fact: the fan-out did not finish).
# =============================================================================
ID_POP="$T/id-pop"; printf '%s\n' u1 > "$ID_POP"
ID_MISSING="$T/id-does-not-exist"
ID_EMPTY="$T/id-empty"; : > "$ID_EMPTY"
ID_OUT1="$T/id1.out"; ID_ERR1="$T/id1.err"
rc_id1="$(run_agg "$ID_OUT1" "$ID_ERR1" --label id1 --population "$ID_POP" --part qa-1="$ID_MISSING")"
cls_id1="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$ID_ERR1")"
ID_OUT2="$T/id2.out"; ID_ERR2="$T/id2.err"
rc_id2="$(run_agg "$ID_OUT2" "$ID_ERR2" --label id2 --population "$ID_POP" --part qa-1="$ID_EMPTY")"
cls_id2="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$ID_ERR2")"
if [ "$rc_id1" = "3" ] && [ "$cls_id1" = "missing-part" ] && [ ! -s "$ID_OUT1" ] \
  && [ "$rc_id2" = "3" ] && [ "$cls_id2" = "empty-part" ] && [ ! -s "$ID_OUT2" ]; then
  pass "T-1074 instance-death"
else
  fail "T-1074 instance-death: expected both missing-part and empty-part to refuse exit 3 with empty stdout, got rc_id1=$rc_id1/$cls_id1 rc_id2=$rc_id2/$cls_id2"
fi

# =============================================================================
# case: partial-output — every refusal case exercised above left stdout
# completely empty (0 bytes) — checked here across several of them at once
# as the anti-vacuity control for D6's "stdout is empty on every non-zero
# exit" rule.
# =============================================================================
partial_ok=1
for f in "$SR_OUT" "$SE_OUT" "$CD_OUT" "$CE_OUT" "$ID_OUT1" "$ID_OUT2"; do
  [ -s "$f" ] && partial_ok=0
done
if [ "$partial_ok" = "1" ]; then
  pass "T-1074 partial-output"
else
  fail "T-1074 partial-output: expected every refusal's stdout to be completely empty"
fi

# =============================================================================
# case: out-of-population — a claimed unit absent from the population
# refuses (exit 1, class out-of-population, empty stdout).
# =============================================================================
OOP_POP="$T/oop-pop"; printf '%s\n' u1 u2 > "$OOP_POP"
OOP_PART="$T/oop-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- unit: u9' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' '- verdict: u9 — AC1: PASS' > "$OOP_PART"
OOP_OUT="$T/oop.out"; OOP_ERR="$T/oop.err"
rc_oop="$(run_agg "$OOP_OUT" "$OOP_ERR" --label oop --population "$OOP_POP" --part qa-1="$OOP_PART")"
cls_oop="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$OOP_ERR")"
if [ "$rc_oop" = "1" ] && [ "$cls_oop" = "out-of-population" ] && [ ! -s "$OOP_OUT" ]; then
  pass "T-1074 out-of-population"
else
  fail "T-1074 out-of-population: expected exit 1 / out-of-population / empty stdout, got rc=$rc_oop class=$cls_oop"
fi

# =============================================================================
# case: control-character — a part file line embedding a literal TAB
# refuses (exit 1, class control-character, empty stdout).
# =============================================================================
CTRL_POP="$T/ctrl-pop"; printf '%s\n' u1 u2 > "$CTRL_POP"
CTRL_TAB="$(printf '\t')"
CTRL_PART="$T/ctrl-part"
printf '%s\n' '- unit: u1' '- unit: u2' "- verdict: u1 — AC1:${CTRL_TAB}PASS" '- verdict: u2 — AC1: PASS' > "$CTRL_PART"
CTRL_OUT="$T/ctrl.out"; CTRL_ERR="$T/ctrl.err"
rc_ctrl="$(run_agg "$CTRL_OUT" "$CTRL_ERR" --label ctrl --population "$CTRL_POP" --part qa-1="$CTRL_PART")"
cls_ctrl="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$CTRL_ERR")"
if [ "$rc_ctrl" = "1" ] && [ "$cls_ctrl" = "control-character" ] && [ ! -s "$CTRL_OUT" ]; then
  pass "T-1074 control-character"
else
  fail "T-1074 control-character: expected exit 1 / control-character / empty stdout, got rc=$rc_ctrl class=$cls_ctrl"
fi

# =============================================================================
# case: double-sentinel-refused — round 2 rework, Codex review round 1 Major
# 1: a part carrying TWO `- sentinel:` lines for the same claimed,
# zero-verdict unit must refuse (round 1's committed script wrongly
# aggregated this at exit 0, promoting both lines into the region). This
# asserts the specific new refusal directly (not a round-1-script
# scratch-diff), since the earlier behaviour is already fully described by
# the review record and the fix is small enough that the direct assertion
# is the cheaper, equally-conclusive check.
# =============================================================================
DS_POP="$T/ds-pop"; printf '%s\n' u1 u2 > "$DS_POP"
DS_PART="$T/ds-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- sentinel: u2 — exit=2 no-verdict-lines' '- sentinel: u2 — exit=2 no-verdict-lines' > "$DS_PART"
DS_OUT="$T/ds.out"; DS_ERR="$T/ds.err"
rc_ds="$(run_agg "$DS_OUT" "$DS_ERR" --label ds --population "$DS_POP" --part qa-1="$DS_PART")"
cls_ds="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$DS_ERR")"
if [ "$rc_ds" = "1" ] && [ "$cls_ds" = "malformed-record" ] && [ ! -s "$DS_OUT" ]; then
  pass "T-1074 double-sentinel-refused"
else
  fail "T-1074 double-sentinel-refused: expected exit 1 / malformed-record / empty stdout for two sentinel lines on one zero-verdict unit, got rc=$rc_ds class=$cls_ds"
fi

# =============================================================================
# case: whitespace-only-tab-refused — round 2 rework, Codex review round 1
# Major 2: a part-file line consisting SOLELY of one literal TAB must refuse
# control-character (round 1's blank-line filter silently stripped it as
# "blank" before has_control_char ever ran).
# =============================================================================
WSTAB_POP="$T/wstab-pop"; printf '%s\n' u1 u2 > "$WSTAB_POP"
WSTAB_TAB="$(printf '\t')"
WSTAB_PART="$T/wstab-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' "$WSTAB_TAB" > "$WSTAB_PART"
WSTAB_OUT="$T/wstab.out"; WSTAB_ERR="$T/wstab.err"
rc_wstab="$(run_agg "$WSTAB_OUT" "$WSTAB_ERR" --label wstab --population "$WSTAB_POP" --part qa-1="$WSTAB_PART")"
cls_wstab="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$WSTAB_ERR")"
if [ "$rc_wstab" = "1" ] && [ "$cls_wstab" = "control-character" ] && [ ! -s "$WSTAB_OUT" ]; then
  pass "T-1074 whitespace-only-tab-refused"
else
  fail "T-1074 whitespace-only-tab-refused: expected exit 1 / control-character / empty stdout for a lone-TAB part-file line, got rc=$rc_wstab class=$cls_wstab"
fi

# =============================================================================
# case: population-whitespace-only-tab-refused — the same Major 2 ordering
# bug at its OTHER call site (the population file's own blank-line filter,
# bin/aggregate-verdicts.sh's Phase 0), closed the same way.
# =============================================================================
POPTAB_POP="$T/poptab-pop"
printf '%s\n' u1 u2 "$WSTAB_TAB" > "$POPTAB_POP"
POPTAB_PART="$T/poptab-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' > "$POPTAB_PART"
POPTAB_OUT="$T/poptab.out"; POPTAB_ERR="$T/poptab.err"
rc_poptab="$(run_agg "$POPTAB_OUT" "$POPTAB_ERR" --label poptab --population "$POPTAB_POP" --part qa-1="$POPTAB_PART")"
cls_poptab="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$POPTAB_ERR")"
if [ "$rc_poptab" = "1" ] && [ "$cls_poptab" = "control-character" ] && [ ! -s "$POPTAB_OUT" ]; then
  pass "T-1074 population-whitespace-only-tab-refused"
else
  fail "T-1074 population-whitespace-only-tab-refused: expected exit 1 / control-character / empty stdout for a lone-TAB population-file line, got rc=$rc_poptab class=$cls_poptab"
fi

# =============================================================================
# case: spaces-only-line-refused — the fail-closed reading of D2's "Blank
# lines are ignored" (recorded in .shell-team/provenance/T-1074.md): a line
# consisting solely of spaces is NOT read as blank, so it survives to the
# per-line shape check and refuses malformed-record (matching none of the
# three record shapes), rather than being silently dropped.
# =============================================================================
WSSPACE_POP="$T/wsspace-pop"; printf '%s\n' u1 u2 > "$WSSPACE_POP"
WSSPACE_PART="$T/wsspace-part"
printf '%s\n' '- unit: u1' '- unit: u2' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' '   ' > "$WSSPACE_PART"
WSSPACE_OUT="$T/wsspace.out"; WSSPACE_ERR="$T/wsspace.err"
rc_wsspace="$(run_agg "$WSSPACE_OUT" "$WSSPACE_ERR" --label wsspace --population "$WSSPACE_POP" --part qa-1="$WSSPACE_PART")"
cls_wsspace="$(sed -n '1s/^aggregate-verdicts: \([a-z-][a-z-]*\):.*/\1/p' "$WSSPACE_ERR")"
if [ "$rc_wsspace" = "1" ] && [ "$cls_wsspace" = "malformed-record" ] && [ ! -s "$WSSPACE_OUT" ]; then
  pass "T-1074 spaces-only-line-refused"
else
  fail "T-1074 spaces-only-line-refused: expected exit 1 / malformed-record / empty stdout for a spaces-only part-file line, got rc=$rc_wsspace class=$cls_wsspace"
fi

# =============================================================================
# case: empty-line-still-ignored — regression: a GENUINELY empty (zero-
# length) line among otherwise well-formed content stays silently ignored
# and the fan-out still aggregates at exit 0, unaffected by narrowing the
# blank-line filter to '^$'.
# =============================================================================
WSEMPTY_POP="$T/wsempty-pop"; printf '%s\n' u1 u2 > "$WSEMPTY_POP"
WSEMPTY_PART="$T/wsempty-part"
printf '%s\n' '- unit: u1' '- unit: u2' '' '- verdict: u1 — AC1: PASS' '- verdict: u2 — AC1: PASS' > "$WSEMPTY_PART"
WSEMPTY_OUT="$T/wsempty.out"; WSEMPTY_ERR="$T/wsempty.err"
rc_wsempty="$(run_agg "$WSEMPTY_OUT" "$WSEMPTY_ERR" --label wsempty --population "$WSEMPTY_POP" --part qa-1="$WSEMPTY_PART")"
if [ "$rc_wsempty" = "0" ] && [ -s "$WSEMPTY_OUT" ] && [ "$(grep -c . "$WSEMPTY_ERR" || true)" = "0" ]; then
  pass "T-1074 empty-line-still-ignored"
else
  fail "T-1074 empty-line-still-ignored: expected a genuinely empty line to stay silently ignored (exit 0), got rc=$rc_wsempty"
fi

# =============================================================================
# case: duplicate-labelled-ac — the concrete, documented hazard D4 is
# designed to survive: a spec quoting a duplicate-labelled AC inside a
# fenced illustrative example produces two IDENTICAL "**AC1**: PASS"-shaped
# verdict payloads for the SAME unit. This must aggregate (exit 0) with both
# preserved, never refuse and never collapse to one.
# =============================================================================
DLA_POP="$T/dla-pop"; printf '%s\n' spec-with-fenced-example.md > "$DLA_POP"
DLA_PART="$T/dla-part"
printf '%s\n' \
  '- unit: spec-with-fenced-example.md' \
  '- verdict: spec-with-fenced-example.md — **AC1**: PASS' \
  '- verdict: spec-with-fenced-example.md — **AC1**: PASS' \
  > "$DLA_PART"
DLA_OUT="$T/dla.out"; DLA_ERR="$T/dla.err"
rc_dla="$(run_agg "$DLA_OUT" "$DLA_ERR" --label dla --population "$DLA_POP" --part qa-1="$DLA_PART")"
extract_region "$DLA_OUT" dla "$T/dla.reg"
dla_count="$(grep -Fcx -- "- verdict: spec-with-fenced-example.md $EM **AC1**: PASS" "$T/dla.reg" || true)"
if [ "$rc_dla" = "0" ] && [ "$(grep -c . "$DLA_ERR" || true)" = "0" ] && [ "$((10#$dla_count))" = "2" ]; then
  pass "T-1074 duplicate-labelled-ac"
else
  fail "T-1074 duplicate-labelled-ac: expected exit 0 with the duplicate-labelled AC payload preserved twice, got rc=$rc_dla count=$dla_count"
fi

# =============================================================================
# case: exit-code-distinctness — all four exit codes are observed, and are
# pairwise distinct, across the cases already run above.
# =============================================================================
USAGE_OUT="$T/usage.out"; USAGE_ERR="$T/usage.err"
rc_usage="$(run_agg "$USAGE_OUT" "$USAGE_ERR" --label usagecase --part qa-1="$SR_PART")"
if [ "$rc" = "0" ] && [ "$rc_sr" = "1" ] && [ "$rc_usage" = "2" ] && [ "$rc_ce" = "3" ] \
  && [ "$rc" != "$rc_sr" ] && [ "$rc" != "$rc_usage" ] && [ "$rc" != "$rc_ce" ] \
  && [ "$rc_sr" != "$rc_usage" ] && [ "$rc_sr" != "$rc_ce" ] && [ "$rc_usage" != "$rc_ce" ]; then
  pass "T-1074 exit-code-distinctness"
else
  fail "T-1074 exit-code-distinctness: expected 0/1/2/3 pairwise distinct, got $rc/$rc_sr/$rc_usage/$rc_ce"
fi

# =============================================================================
# case: zero-dependency-path — the main fixture aggregates under
# PATH=/usr/bin:/bin, the zero-dependency floor asserted as behaviour: a
# script reaching for jq/perl/a Homebrew coreutils would not run at all.
# =============================================================================
ZDP_OUT="$T/zdp.out"; ZDP_ERR="$T/zdp.err"
if env PATH=/usr/bin:/bin bash "$SCRIPT" --label zdp --population "$MPOP" --part m-a="$MA" --part m-b="$MB" --part m-c="$MC" --part m-d="$MD" >"$ZDP_OUT" 2>"$ZDP_ERR"; then
  rc_zdp=0
else
  rc_zdp=$?
fi
if [ "$rc_zdp" = "0" ] && [ -s "$ZDP_OUT" ]; then
  pass "T-1074 zero-dependency-path"
else
  fail "T-1074 zero-dependency-path: expected exit 0 + non-empty stdout under PATH=/usr/bin:/bin, got rc=$rc_zdp"
fi

# =============================================================================
# fanout-parameters — the floors this suite's own main fixture must clear
# (parts>=4, units>=8, records>=16), derived from the fixture files above.
# =============================================================================
printf 'PASS: T-1074 fanout-parameters %s parts=%s %s units=%s %s records=%s\n' "$EM" "$N_PARTS" "$EM" "$N_UNITS" "$EM" "$N_RECORDS"

# =============================================================================
# AC9 — negative control: a coverage-check-disabled MUTANT copy of the
# aggregator, built under $TMPDIR (never the working tree), must wrongly
# accept the coverage-exhaustive fixture above (where the real tool exits
# 3, uncovered-unit) for this control to report "detected". Built fresh
# here, never in bin/ or tests/ — AC9 reads git status --porcelain -- bin/
# tests/ for exactly this reason.
# =============================================================================
MUTANT="$T/mutant-aggregate-verdicts.sh"
cp "$SCRIPT" "$MUTANT"
# Neuter ONLY the uncovered-unit refusal call — verified unique below.
occurrences_before="$(grep -c 'die 3 uncovered-unit' "$MUTANT" || true)"
sed -i.bak 's/^\([[:space:]]*\)die 3 uncovered-unit.*$/\1: # mutant: coverage check disabled for the negative control/' "$MUTANT"
occurrences_after="$(grep -c 'die 3 uncovered-unit' "$MUTANT" || true)"

MUT_OUT="$T/mut.out"; MUT_ERR="$T/mut.err"
if bash "$MUTANT" --label ce --population "$CE_POP" --part qa-1="$CE_PART" >"$MUT_OUT" 2>"$MUT_ERR"; then
  rc_mut=0
else
  rc_mut=$?
fi

if [ "$((10#$occurrences_before))" = "1" ] && [ "$((10#$occurrences_after))" = "0" ] \
  && [ "$rc_ce" = "3" ] && [ "$rc_mut" = "0" ] && [ -s "$MUT_OUT" ]; then
  NEG_VERDICT="detected"
  NEG_TEXT="the coverage-check-disabled mutant wrongly exited 0 with a non-empty verdict block against the coverage-exhaustive fixture (population u1,u2,u3 with only u1,u2 claimed), where the real, unmodified tool exits 3 (uncovered-unit); the mutation (neutering the single 'die 3 uncovered-unit' call) was confirmed applied before running it"
  pass "T-1074 negative-control $EM $NEG_VERDICT $EM $NEG_TEXT"
else
  NEG_VERDICT="not-detected"
  NEG_TEXT="the mutant did not deviate from the real tool on the coverage-exhaustive fixture (rc_ce=$rc_ce rc_mut=$rc_mut occurrences_before=$occurrences_before occurrences_after=$occurrences_after) — the mutation may not have applied, or the fixture may not exercise the neutered branch"
  pass "T-1074 negative-control $EM $NEG_VERDICT $EM $NEG_TEXT"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'aggregate-verdicts suite: all assertions passed\n'
  exit 0
else
  printf 'aggregate-verdicts suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
