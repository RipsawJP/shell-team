#!/usr/bin/env bash
# run.sh — drive bin/check-provenance.sh against synthetic provenance-file
# fixtures and assert the state machine documented in
# docs/specs/T-074-decision-provenance-core.md (AC2): every case below is
# asserted on BOTH exit code AND the stderr classification token, per the
# "wrong-but-nonzero must not look like success" fixture-synthesis
# discipline (same discipline tests/check-intent/run.sh follows).
#
#   (i)     正系 well-formed 三つ組（複数件）                       -> exit 0
#   (ii)    ゼロ件 sentinel（唯一の非空行）                          -> exit 0
#   (iii)   明示 grounding: none (ungrounded)                       -> exit 0
#   (iv)    malformed/不完全な三つ組: reason 欠落 / decision 空 /
#           grounding 空 / reason 空（round2 same-class audit で追加）  -> exit 1, "schema"
#   (v)     grounding 行の無い決定（ungrounded 無宣言）              -> exit 1, "schema"
#   (vi)    sentinel 無しのゼロ件                                    -> exit 1, "schema"
#   (vii)   sentinel と決定エントリの併存（両方向）                   -> exit 1, "schema"
#   (viii)  マーカー不在 / 二重マーカー対 / END が BEGIN に先行 /
#           BEGIN と END の task-id 不一致                          -> exit 2, "structural"
#   (ix)    usage: 引数不足 / 過剰 / ディレクトリ引数                 -> exit 2, "usage"
#           （ディレクトリ引数は perl alarm で非 hang も assert）
#   (x)     CRLF 混在でも正系は conformant                           -> exit 0
#   (xi)    self-referential prose（field/marker/sentinel の語彙を
#           値として引用）を誤カウントしない                          -> exit 0
#   (xii)   3 起動形（bash / ./ / PATH ベア名）で同一挙動・出力が
#           byte-identical（round2 rework2 で同クラス閉じ）            -> same rc + identical output
#   (xiii)  Codex round1 rework1 Major #2 回帰ロック: インデントされた
#           `- decision:`（round2 rework2 で reason/grounding 付与し
#           vacuous 修正） / zero-indent `reason:`・`grounding:`（行頭
#           アンカー違反）                                            -> exit 1, "schema"
#   (xiv)   Codex round1 rework1 Major #2 回帰ロック: malformed fixture を
#           3 起動形すべてで実行し rc 一致 + stderr が byte-identical
#           （round2 rework2 で相互比較を追加）                        -> exit 1, "schema" (全起動形)
#   (extra) 想定外の非空行 / reason・grounding の重複フィールド        -> exit 1, "schema"
#
# Fixtures use synthetic task id T-900 (not a real board task), built fresh
# in a temp dir per case — no static fixtures/ directory needed. Temp roots
# live under $TMPDIR when set (restricted sandboxes), falling back to
# $HERE/tmp-roots on plain CI runners (2026-07-06 lesson: prefer $TMPDIR;
# 2026-07-19 lesson: this machine's bare macOS `mktemp` ignores TMPDIR and
# fails in-sandbox, so every mktemp call below uses an explicit
# "${TMPDIR:-/tmp}/...XXXXXX" template).

set -euo pipefail

# Environment normalization (#233 item 4): an inherited BASH_ENV startup hook
# (a reachable real class — a set BASH_ENV is a standard bash startup file)
# must never leak output/behavior into a checker invocation captured below.
unset BASH_ENV

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-provenance.sh"

# Collision-safe temp root (#233 item 3): `mktemp -d` gives EACH invocation
# its own unique directory (unlike a fixed, predictable name), so two
# concurrent runs of this suite cannot clobber each other's fixtures via a
# shared `rm -rf`.
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-provenance-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# dump_cmp_diag <label> <file1> <file2> [<file3> ...] (#301 fast-follow):
# when a byte-precise `cmp` comparison across invocation styles FAILs below,
# `fail()` immediately triggers the EXIT-trap (`rm -rf "$TMP"`) that deletes
# the very temp files the failure message points to ("see $C/xii-out-1.txt /
# ..."), so a CI log cannot show WHAT differed post-hoc. Every cmp-comparison
# failure branch below calls this helper BEFORE fail() fires, so the
# differing bytes themselves survive in captured stderr. Called only on an
# ACTUAL mismatch (never unconditionally), so a normal passing run never
# gains output — or a stray temp file — from this mechanism.
dump_cmp_diag() {
  local label="$1"; shift
  local prev="" f
  for f in "$@"; do
    if [ -n "$prev" ] && ! cmp -s "$prev" "$f"; then
      printf 'DIAG %s: %s and %s differ —\n' "$label" "$prev" "$f" >&2
      diff -u "$prev" "$f" >&2 || true
    fi
    prev="$f"
  done
}

TASK_ID="T-900"

# run_checker <file> -- captures RC (exit code) and ERR (stderr text)
RC=0
ERR=""
run_checker() {
  local out
  set +e
  out="$(bash "$CHECKER" "$1" 2>&1 >/dev/null)"
  RC=$?
  set -e
  ERR="$out"
}

# ============================================================================
# (i) positive: well-formed triples (multiple decisions)
# ============================================================================
C="$TMP/case-i"; mkdir -p "$C"
{
  printf '# Fixture provenance — %s\n\n' "$TASK_ID"
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: Use per-task provenance files.\n'
  printf '  reason: Keeps the schema self-contained (no board/spec cross-reference).\n'
  printf '  grounding: docs/specs/fixture.md §DP1\n\n'
  printf -- '- decision: Reject sentinel-less zero as a schema violation.\n'
  printf '  reason: Distinguishes "recorded zero" from "forgot to record".\n'
  printf '  grounding: docs/specs/fixture.md §DP3\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 0 ] || fail "(i): expected exit 0 (conformant), got $RC: $ERR"
pass "(i): well-formed multi-decision provenance file is conformant (exit 0)"

# ============================================================================
# (ii) positive: zero-decision sentinel is the only non-blank line
# ============================================================================
C="$TMP/case-ii"; mkdir -p "$C"
{
  printf '# Fixture provenance — %s\n\n' "$TASK_ID"
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf 'no non-trivial decisions\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 0 ] || fail "(ii): expected exit 0 (conformant), got $RC: $ERR"
pass "(ii): zero-decision sentinel as the sole non-blank line is conformant (exit 0)"

# ============================================================================
# (iii) positive: explicit grounding: none (ungrounded) is conformant (S3
#       does not flag ungrounded decisions — that is S4's job)
# ============================================================================
C="$TMP/case-iii"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: Chose X over Y.\n'
  printf '  reason: X was simpler to implement.\n'
  printf '  grounding: none (ungrounded)\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 0 ] || fail "(iii): explicit ungrounded declaration should be conformant, got $RC: $ERR"
pass "(iii): explicit 'grounding: none (ungrounded)' is conformant (exit 0) — S3 never flags ungrounded"

# ============================================================================
# (iv) schema: malformed/incomplete triples — reason 欠落 / decision 空 /
#      grounding 空
# ============================================================================
C="$TMP/case-iv"; mkdir -p "$C"

# (iv-a) reason line entirely missing (decision + grounding only)
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-noreason.md"
run_checker "$C/prov-noreason.md"
[ "$RC" -eq 1 ] || fail "(iv-a) reason line missing: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(iv-a): stderr must carry 'schema' token, got: $ERR"

# (iv-b) decision line present but empty value
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision:\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-emptydecision.md"
run_checker "$C/prov-emptydecision.md"
[ "$RC" -eq 1 ] || fail "(iv-b) empty decision value: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(iv-b): stderr must carry 'schema' token, got: $ERR"

# (iv-c) grounding line present but empty value
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding:\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-emptygrounding.md"
run_checker "$C/prov-emptygrounding.md"
[ "$RC" -eq 1 ] || fail "(iv-c) empty grounding value: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(iv-c): stderr must carry 'schema' token, got: $ERR"

# (iv-d) reason line PRESENT but empty value — the symmetric counterpart to
# (iv-c) for the reason field (Same-class-2 audit: this exact code path,
# `-z "$text"` on a present-but-blank reason value, had no dedicated
# fixture — (iv-a) only exercises reason MISSING entirely, a different code
# path (finalize's `reason_count_cur -ne 1` at count==0, not the emptiness
# check at count==1)).
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason:\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-emptyreason.md"
run_checker "$C/prov-emptyreason.md"
[ "$RC" -eq 1 ] || fail "(iv-d) empty reason value: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(iv-d): stderr must carry 'schema' token, got: $ERR"

pass "(iv): malformed/incomplete triples (reason missing / decision empty / grounding empty / reason empty) all exit 1 with 'schema' token"

# ============================================================================
# (v) core discipline: grounding line ENTIRELY absent (decision + reason
#     only) — the ungrounded-without-declaration case must fail closed
# ============================================================================
C="$TMP/case-v"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 1 ] || fail "(v) grounding line entirely absent: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(v): stderr must carry 'schema' token, got: $ERR"
pass "(v): a decision with NO grounding line at all (ungrounded, undeclared) is a schema violation (exit 1, token present) — the grounding core discipline"

# ============================================================================
# (vi) schema: sentinel-less zero — no sentinel AND no decision entries
# ============================================================================
C="$TMP/case-vi"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 1 ] || fail "(vi) sentinel-less zero: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(vi): stderr must carry 'schema' token, got: $ERR"
pass "(vi): sentinel-less zero (no sentinel, no decision entry) is a schema violation (exit 1, token present) — recorded-zero vs forgot-to-record"

# ============================================================================
# (vii) schema: sentinel and decision entry coexist, both orders
# ============================================================================
C="$TMP/case-vii"; mkdir -p "$C"

# (vii-a) sentinel first, decision entry after
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf 'no non-trivial decisions\n\n'
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-sentinel-first.md"
run_checker "$C/prov-sentinel-first.md"
[ "$RC" -eq 1 ] || fail "(vii-a) sentinel then decision entry: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(vii-a): stderr must carry 'schema' token, got: $ERR"

# (vii-b) decision entry first, sentinel after
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf 'no non-trivial decisions\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-decision-first.md"
run_checker "$C/prov-decision-first.md"
[ "$RC" -eq 1 ] || fail "(vii-b) decision entry then sentinel: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(vii-b): stderr must carry 'schema' token, got: $ERR"

pass "(vii): sentinel and decision entry coexisting (either order) is a schema violation (exit 1, token present)"

# ============================================================================
# (viii) structural: marker absent / duplicated pair / reversed / task-id
#        mismatch
# ============================================================================
C="$TMP/case-viii"; mkdir -p "$C"

# (viii-a) marker absent (no BEGIN at all)
{
  printf '# Fixture provenance — %s\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n'
} > "$C/prov-nomarker.md"
run_checker "$C/prov-nomarker.md"
[ "$RC" -eq 2 ] || fail "(viii-a) marker absent: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(viii-a): stderr must carry 'structural' token, got: $ERR"

# (viii-b) duplicated marker pair (two full BEGIN/END pairs, same task-id)
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n\n' "$TASK_ID"
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: a\n'
  printf '  reason: b\n'
  printf '  grounding: c\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-dup.md"
run_checker "$C/prov-dup.md"
[ "$RC" -eq 2 ] || fail "(viii-b) duplicated marker pair: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(viii-b): stderr must carry 'structural' token, got: $ERR"

# (viii-c) reversed: END appears before BEGIN
{
  printf '<!-- END provenance: %s -->\n\n' "$TASK_ID"
  printf '<!-- BEGIN provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-reversed.md"
run_checker "$C/prov-reversed.md"
[ "$RC" -eq 2 ] || fail "(viii-c) reversed markers: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(viii-c): stderr must carry 'structural' token, got: $ERR"

# (viii-d) BEGIN and END task-id mismatch (no END matching the BEGIN id)
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: T-901 -->\n'
} > "$C/prov-mismatch.md"
run_checker "$C/prov-mismatch.md"
[ "$RC" -eq 2 ] || fail "(viii-d) task-id mismatch: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(viii-d): stderr must carry 'structural' token, got: $ERR"

pass "(viii): marker absent / duplicated pair / reversed / task-id mismatch all exit 2 with 'structural' token"

# ============================================================================
# (ix) usage: missing argument / extra argument / directory argument
#      (directory argument non-hang asserted via a perl alarm wrapper)
# ============================================================================
C="$TMP/case-ix"; mkdir -p "$C/a-directory"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf 'no non-trivial decisions\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"

set +e
IX_A_OUT="$(bash "$CHECKER" 2>&1 >/dev/null)"
IX_A_RC=$?
set -e
[ "$IX_A_RC" -eq 2 ] || fail "(ix-a) missing argument: expected exit 2 (usage), got $IX_A_RC: $IX_A_OUT"
grep -q 'usage' <<< "$IX_A_OUT" || fail "(ix-a): stderr must carry 'usage' token, got: $IX_A_OUT"

set +e
IX_B_OUT="$(bash "$CHECKER" "$C/prov.md" "extra-argument" 2>&1 >/dev/null)"
IX_B_RC=$?
set -e
[ "$IX_B_RC" -eq 2 ] || fail "(ix-b) extra argument: expected exit 2 (usage), got $IX_B_RC: $IX_B_OUT"
grep -q 'usage' <<< "$IX_B_OUT" || fail "(ix-b): stderr must carry 'usage' token, got: $IX_B_OUT"

run_checker "$C/a-directory"
[ "$RC" -eq 2 ] || fail "(ix-c) directory argument: expected exit 2 (usage), got $RC: $ERR"
grep -q 'usage' <<< "$ERR" || fail "(ix-c): stderr must carry 'usage' token, got: $ERR"

set +e
IX_D_OUT="$(perl -e 'alarm 8; exec @ARGV' bash "$CHECKER" "$C/a-directory" 2>&1 >/dev/null)"
IX_D_RC=$?
set -e
[ "$IX_D_RC" -eq 2 ] || fail "(ix-d) directory argument within an 8s alarm (no hang): expected exit 2 (usage), got $IX_D_RC: $IX_D_OUT"
grep -q 'usage' <<< "$IX_D_OUT" || fail "(ix-d): stderr must carry 'usage' token, got: $IX_D_OUT"

pass "(ix): missing / extra / directory arguments all exit 2 with 'usage' token; directory argument does not hang (8s perl alarm)"

# ============================================================================
# (x) CRLF tolerance: a well-formed provenance file with CRLF line endings
#     still normalizes to conformant
# ============================================================================
C="$TMP/case-x"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
sed 's/$/\r/' "$C/prov.md" > "$C/prov-crlf.md"
run_checker "$C/prov-crlf.md"
[ "$RC" -eq 0 ] || fail "(x): CRLF line endings should normalize to conformant (exit 0), got $RC: $ERR"
pass "(x): CRLF line endings normalize to conformant (exit 0)"

# ============================================================================
# (xi) self-referential prose: field/marker/sentinel vocabulary quoted as a
#      VALUE must never be miscounted as a real structural occurrence
#      (2026-07-17 self-referential dogfooding lesson; 2026-07-15 lesson —
#      vocabulary-collision legal inputs).
# ============================================================================
C="$TMP/case-xi"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  # shellcheck disable=SC2016  # backtick-quoted marker/field text is literal
  # prose to embed in the fixture VALUE, not a command substitution.
  printf -- '- decision: Anchor markers with `<!-- BEGIN provenance: %s -->` full-line compare, not substring.\n' "$TASK_ID"
  # shellcheck disable=SC2016  # same literal-prose reasoning as above.
  printf '  reason: A `reason:` or `grounding:` word quoted mid-value must not be miscounted as a second field.\n'
  # shellcheck disable=SC2016  # same literal-prose reasoning as above.
  printf '  grounding: The sentinel `no non-trivial decisions` is only recognized as a full line, never inside a value like this one — docs/specs/fixture.md §Input-space-8\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"
run_checker "$C/prov.md"
[ "$RC" -eq 0 ] || fail "(xi): self-referential prose in field VALUES must not be miscounted, expected conformant (exit 0), got $RC: $ERR"
pass "(xi): field/marker/sentinel vocabulary quoted as a value (self-referential prose) is not miscounted (exit 0)"

# ============================================================================
# (xii) 3 invocation styles produce identical behavior
# ============================================================================
C="$TMP/case-xii"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov.md"

set +e
( cd "$REPO_ROOT" && bash bin/check-provenance.sh "$C/prov.md" ) >"$C/xii-out-1.txt" 2>&1
rc1=$?
( cd "$REPO_ROOT" && ./bin/check-provenance.sh "$C/prov.md" ) >"$C/xii-out-2.txt" 2>&1
rc2=$?

PATHBIN="$TMP/pathbin"
mkdir -p "$PATHBIN"
ln -sf "$CHECKER" "$PATHBIN/check-provenance.sh"
# Deliberately scoped to this ( ) subshell only — each PATH-bare-name
# invocation below (here and in case (xiv)) re-exports PATH inside its OWN
# subshell so the parent shell's PATH is never touched; the two occurrences
# of this pattern in this file are independent, not a forgotten propagation.
# (the disable directive must sit directly above the subshell STATEMENT, on
# its own line — shellcheck does not attach it correctly to the second half
# of a `var=0; ( ... ) || var=$?` compound line.)
# shellcheck disable=SC2030
( export PATH="$PATHBIN:$PATH"; cd "$REPO_ROOT" && check-provenance.sh "$C/prov.md" ) >"$C/xii-out-3.txt" 2>&1
rc3=$?
set -e

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ] || [ "$rc3" -ne 0 ]; then
  fail "(xii): invocation styles disagree or failed — bash=$rc1 dot-slash=$rc2 PATH-bare=$rc3"
fi
# Same-class closure as case (xiv)'s fix (Codex round2 rework2 finding #2,
# tasks/reviews/T-074.md Round 2): this case's own pass message claims
# "identical behavior" — checking only that all 3 rc are 0 does not verify
# that, since a regression that makes exactly one invocation style ALSO
# print extra (but harmless-looking) output on success would go undetected.
# Byte-level (newline-preserving) comparison via `cmp`, not a "$(...)" string
# capture — command substitution strips trailing newlines and would silently
# pass a trailing-newline-only regression (#233 item 2).
if ! cmp -s "$C/xii-out-1.txt" "$C/xii-out-2.txt" || ! cmp -s "$C/xii-out-2.txt" "$C/xii-out-3.txt"; then
  dump_cmp_diag "(xii)" "$C/xii-out-1.txt" "$C/xii-out-2.txt" "$C/xii-out-3.txt"
  fail "(xii): output differs across invocation styles — see $C/xii-out-1.txt / $C/xii-out-2.txt / $C/xii-out-3.txt"
fi
pass "(xii): bash / ./ / PATH-bare-name invocations all produce identical output and exit 0"

# ============================================================================
# (xiii) Codex round1 rework1 Major #2 regression locks: boundary / regex
#      anchor negatives (tasks/reviews/T-074.md Round 1, finding #2) — a
#      `- decision:` anchor requires ZERO leading whitespace (top-level), and
#      `reason:`/`grounding:` anchors require AT LEAST ONE leading whitespace
#      (indented continuation). None of these were previously locked by a
#      dedicated negative fixture — only case (xi)'s positive vocabulary-
#      collision case and case (xii)'s positive 3-invocation-style case
#      existed. Each fixture below would flip from exit 1 to exit 0 if a
#      future edit loosened the anchor (e.g. `^[[:space:]]*reason:` instead
#      of `^[[:space:]]+reason:`), so this locks the anchor discipline itself,
#      not just "this input happens to already be malformed for other
#      reasons".
# ============================================================================
C="$TMP/case-xiii"; mkdir -p "$C"

# (xiii-a) an INDENTED `  - decision:` line must NOT be recognized as a
# top-level decision anchor (spec: field matching is line-start-anchored,
# `^- decision:` requires zero leading whitespace). Codex round2 rework2
# finding #1 (tasks/reviews/T-074.md Round 2): the ORIGINAL version of this
# fixture had NO reason/grounding at all, so it was a VACUOUS lock — the
# fixture stayed exit 1 even after loosening DECISION_RE's anchor, because it
# ALSO failed for the unrelated reason "incomplete triple" (missing reason/
# grounding). This version supplies an otherwise-valid reason/grounding pair
# so the indentation is the ONLY thing wrong with the entry: if a future edit
# loosens `^- decision:` to also accept leading whitespace, this fixture
# would flip from schema(1) to conformant(0), and ONLY this fixture's design
# distinguishes that from "incomplete triple".
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '  - decision: this is indented, not a real top-level anchor\n'
  printf '    reason: otherwise valid reason\n'
  printf '    grounding: otherwise valid grounding\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-indented-decision.md"
run_checker "$C/prov-indented-decision.md"
[ "$RC" -eq 1 ] || fail "(xiii-a) indented '  - decision:' line: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(xiii-a): stderr must carry 'schema' token, got: $ERR"

# (xiii-b) a ZERO-INDENT `reason:` line (no leading whitespace at all) must
# NOT be recognized as a valid continuation field — `^[[:space:]]+reason:`
# requires at least one leading whitespace character. The entry is left
# without a well-formed reason, so it fails closed.
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf 'reason: this reason line has NO leading whitespace (invalid anchor)\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-zeroindent-reason.md"
run_checker "$C/prov-zeroindent-reason.md"
[ "$RC" -eq 1 ] || fail "(xiii-b) zero-indent 'reason:' line: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(xiii-b): stderr must carry 'schema' token, got: $ERR"

# (xiii-c) a ZERO-INDENT `grounding:` line, same anchor requirement.
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf 'grounding: this grounding line has NO leading whitespace (invalid anchor)\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-zeroindent-grounding.md"
run_checker "$C/prov-zeroindent-grounding.md"
[ "$RC" -eq 1 ] || fail "(xiii-c) zero-indent 'grounding:' line: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(xiii-c): stderr must carry 'schema' token, got: $ERR"

pass "(xiii): indented '- decision:' / zero-indent 'reason:' / zero-indent 'grounding:' lines are all rejected as invalid anchors (exit 1, 'schema' token) — locks the line-start anchor discipline itself"

# ============================================================================
# (xiv) Codex round1 rework1 Major #2: a MALFORMED fixture run across all 3
#      invocation styles must produce IDENTICAL rc AND stderr classification
#      token across all three — case (xii) above only ever exercised a
#      well-formed (exit 0) fixture, never a negative one.
# ============================================================================
C="$TMP/case-xiv"; mkdir -p "$C"
{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-malformed.md"

set +e
( cd "$REPO_ROOT" && bash bin/check-provenance.sh "$C/prov-malformed.md" ) >/dev/null 2>"$C/xiv-out-1.txt"
XIV_RC_1=$?
( cd "$REPO_ROOT" && ./bin/check-provenance.sh "$C/prov-malformed.md" ) >/dev/null 2>"$C/xiv-out-2.txt"
XIV_RC_2=$?
# shellcheck disable=SC2031  # same deliberately-subshell-scoped PATH export
# as case (xii) above — this is a second, independent invocation, not a
# forgotten propagation of the earlier one.
( export PATH="$PATHBIN:$PATH"; cd "$REPO_ROOT" && check-provenance.sh "$C/prov-malformed.md" ) >/dev/null 2>"$C/xiv-out-3.txt"
XIV_RC_3=$?
set -e

if [ "$XIV_RC_1" -ne 1 ] || [ "$XIV_RC_2" -ne 1 ] || [ "$XIV_RC_3" -ne 1 ]; then
  fail "(xiv): malformed fixture should exit 1 (schema) under all 3 invocation styles — bash=$XIV_RC_1 dot-slash=$XIV_RC_2 PATH-bare=$XIV_RC_3"
fi
grep -q 'schema' "$C/xiv-out-1.txt" || fail "(xiv): bash invocation stderr must carry 'schema' token, got: $(cat "$C/xiv-out-1.txt")"
grep -q 'schema' "$C/xiv-out-2.txt" || fail "(xiv): ./ invocation stderr must carry 'schema' token, got: $(cat "$C/xiv-out-2.txt")"
grep -q 'schema' "$C/xiv-out-3.txt" || fail "(xiv): PATH-bare invocation stderr must carry 'schema' token, got: $(cat "$C/xiv-out-3.txt")"
# Codex round2 rework2 finding #2 (tasks/reviews/T-074.md Round 2): the
# 3 individual `grep -q 'schema'` checks above only ever verify EACH stderr
# independently carries the token — they do NOT compare the 3 outputs
# against EACH OTHER, so a regression that makes exactly ONE invocation
# style emit an EXTRA classification token alongside 'schema' (round2's own
# adversarial repro: injecting an extra 'usage' line into the PATH-bare
# invocation only) would go undetected. Byte-level (newline-preserving)
# comparison via `cmp`, not a "$(...)" string capture (#233 item 2), to
# close that gap — this is the actual "identical behavior" claim the case's
# own pass message makes.
if ! cmp -s "$C/xiv-out-1.txt" "$C/xiv-out-2.txt" || ! cmp -s "$C/xiv-out-2.txt" "$C/xiv-out-3.txt"; then
  dump_cmp_diag "(xiv)" "$C/xiv-out-1.txt" "$C/xiv-out-2.txt" "$C/xiv-out-3.txt"
  fail "(xiv): stderr differs across invocation styles — see $C/xiv-out-1.txt / $C/xiv-out-2.txt / $C/xiv-out-3.txt"
fi
pass "(xiv): a malformed (grounding-missing) fixture exits 1 with byte-identical stderr and the 'schema' token under all 3 invocation styles (bash / ./ / PATH-bare-name)"

# ============================================================================
# (#301 diagnostics) non-vacuous demonstration: dump_cmp_diag — the SAME
# diagnostic-emit path the real (xii)/(xiv) cmp sites above use — surfaces
# the differing bytes to stderr on a forced mismatch (clause i), and is never
# invoked (so leaves no additional stray temp behind) on a normal matching
# pass (clause ii) — proving the global EXIT-trap cleanup is never deferred
# or disabled on the success path.
# ============================================================================
C="$TMP/case-301demo"; mkdir -p "$C"

# (a) forced mismatch: the differing content must appear in dump_cmp_diag's
# own captured stderr, independent of fail()/the real EXIT trap.
printf 'alpha\nbravo\n'   > "$C/a.txt"
printf 'alpha\nCHARLIE\n' > "$C/b.txt"
DEMO_DIAG_OUT="$(dump_cmp_diag "(#301-demo)" "$C/a.txt" "$C/b.txt" 2>&1 >/dev/null)"
grep -Fq -- '-bravo' <<< "$DEMO_DIAG_OUT" || fail "#301 demo (a): dump_cmp_diag must surface the removed line ('-bravo') on a forced mismatch, got: $DEMO_DIAG_OUT"
grep -Fq -- '+CHARLIE' <<< "$DEMO_DIAG_OUT" || fail "#301 demo (a): dump_cmp_diag must surface the added line ('+CHARLIE') on a forced mismatch, got: $DEMO_DIAG_OUT"

# (b) a normal (matching) pass never invokes the diagnostic-emit path at all,
# and this demonstration's own temp files are fully removable afterward — no
# stray handle survives, mirroring the suite's global EXIT-trap discipline.
printf 'same\n' > "$C/c.txt"
printf 'same\n' > "$C/d.txt"
DEMO_MATCH_OUT=""
if ! cmp -s "$C/c.txt" "$C/d.txt"; then
  DEMO_MATCH_OUT="$(dump_cmp_diag "(#301-demo-match)" "$C/c.txt" "$C/d.txt" 2>&1 >/dev/null)"
fi
[ -z "$DEMO_MATCH_OUT" ] || fail "#301 demo (b): a matching pair must never invoke the diagnostic-emit path, got: $DEMO_MATCH_OUT"
rm -rf "$C"
[ ! -e "$C" ] || fail "#301 demo (b): expected the demonstration's own temp dir to be fully removable (no stray handle) after cleanup, found $C"

pass "#301 diagnostics: forced cmp mismatch surfaces the diff before EXIT-trap cleanup"

# ============================================================================
# (extra) additional adversarial fixtures beyond AC2's minimum list:
#   unrecognized non-blank line inside the region / duplicate reason field /
#   duplicate grounding field within the same entry.
# ============================================================================
C="$TMP/case-extra"; mkdir -p "$C"

{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n'
  printf '  extra: unexpected stray line\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-stray.md"
run_checker "$C/prov-stray.md"
[ "$RC" -eq 1 ] || fail "(extra-a) unrecognized non-blank line: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(extra-a): stderr must carry 'schema' token, got: $ERR"

{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  reason: duplicate reason line\n'
  printf '  grounding: z\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-dupreason.md"
run_checker "$C/prov-dupreason.md"
[ "$RC" -eq 1 ] || fail "(extra-b) duplicate reason field: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(extra-b): stderr must carry 'schema' token, got: $ERR"

{
  printf '<!-- BEGIN provenance: %s -->\n\n' "$TASK_ID"
  printf -- '- decision: x\n'
  printf '  reason: y\n'
  printf '  grounding: z\n'
  printf '  grounding: duplicate grounding line\n\n'
  printf '<!-- END provenance: %s -->\n' "$TASK_ID"
} > "$C/prov-dupgrounding.md"
run_checker "$C/prov-dupgrounding.md"
[ "$RC" -eq 1 ] || fail "(extra-c) duplicate grounding field: expected exit 1 (schema), got $RC: $ERR"
grep -q 'schema' <<< "$ERR" || fail "(extra-c): stderr must carry 'schema' token, got: $ERR"

pass "(extra): unrecognized stray line / duplicate reason / duplicate grounding fields all exit 1 with 'schema' token"

# ============================================================================
# AC6 (#233 item 3, non-vacuous lock): a fixed-name temp root computes the
# SAME path for two independent invocations, by construction (no actual
# concurrency needed to prove the collision SURFACE exists — the OLD literal
# is not derived from any per-run entropy) — a second run's
# `rm -rf "$TMP"; mkdir -p "$TMP"` reset would clobber the first run's
# in-flight fixtures. `mktemp -d` guarantees two independent invocations get
# DIFFERENT directories.
# ============================================================================
# (a generic fixed-name stand-in, not the OLD literal itself — AC6 forbids
# that exact literal from appearing anywhere in this file at all, including
# in this demonstration).
FIXED_NAME_STANDIN="check-provenance-fixture-root-fixed-name-standin"
OLD_TMP_A="${TMPDIR:-/tmp}/${FIXED_NAME_STANDIN}"
OLD_TMP_B="${TMPDIR:-/tmp}/${FIXED_NAME_STANDIN}"
[ "$OLD_TMP_A" = "$OLD_TMP_B" ] || fail "AC6 counterfactual sanity: expected the OLD fixed-name computation to be identical across two invocations"
NEW_TMP_A="$(mktemp -d "${TMPDIR:-/tmp}/check-provenance-fixtures.XXXXXX")"
NEW_TMP_B="$(mktemp -d "${TMPDIR:-/tmp}/check-provenance-fixtures.XXXXXX")"
[ "$NEW_TMP_A" != "$NEW_TMP_B" ] || fail "AC6: two independent mktemp -d temp roots should never collide"
rm -rf "$NEW_TMP_A" "$NEW_TMP_B"
pass "AC6: fixed-name temp roots collide by construction across independent invocations (OLD_TMP_A == OLD_TMP_B); mktemp -d roots never do (NEW_TMP_A != NEW_TMP_B) — non-vacuous counterfactual"

# ============================================================================
# AC7 (#233 item 4, non-vacuous lock): this runner unsets BASH_ENV before
# spawning any bash subprocess, so an externally-set BASH_ENV startup hook (a
# reachable real class — Input space class 3, "arbitrary inherited
# environment") cannot leak output into a captured checker invocation.
# ============================================================================
C="$TMP/case-ac7"; mkdir -p "$C"
MARKER_SCRIPT="$C/bash_env_marker.sh"
printf '#!/bin/sh\nprintf "BASH_ENV_LEAK_MARKER\\n"\n' > "$MARKER_SCRIPT"
chmod +x "$MARKER_SCRIPT"

# OLD-suite-like: BASH_ENV is still set when the bash subprocess is spawned
# (using the same `bash "$CHECKER" ...` invocation shape this suite uses
# elsewhere) — its startup file's marker leaks into the captured output.
# shellcheck disable=SC2030  # deliberately subshell-scoped, closed over by
# the command substitution below only — never touches the parent shell.
AC7_LEAK_OUT="$(export BASH_ENV="$MARKER_SCRIPT"; bash "$CHECKER" --help 2>&1 | head -1 || true)"
grep -q 'BASH_ENV_LEAK_MARKER' <<< "$AC7_LEAK_OUT" || fail "AC7 mechanism sanity: expected an inherited BASH_ENV startup file to leak its marker into a bash subprocess's output (got: $AC7_LEAK_OUT)"

# NEW-suite-like: BASH_ENV is unset (mirroring this runner's own top-of-file
# `unset BASH_ENV`) BEFORE the bash subprocess is spawned — no leak.
# shellcheck disable=SC2031  # same independent, subshell-scoped export as
# AC7_LEAK_OUT above — not a forgotten propagation.
AC7_NOLEAK_OUT="$(export BASH_ENV="$MARKER_SCRIPT"; unset BASH_ENV; bash "$CHECKER" --help 2>&1 | head -1 || true)"
if grep -q 'BASH_ENV_LEAK_MARKER' <<< "$AC7_NOLEAK_OUT"; then
  fail "AC7: unsetting BASH_ENV before spawning a bash subprocess should prevent the startup-file marker from leaking, got: $AC7_NOLEAK_OUT"
fi
pass "AC7: an inherited BASH_ENV startup file leaks its marker into a bash subprocess's output when left set (OLD-suite-like); unsetting it first (NEW-suite-like, matching this runner's own top-of-file guard) prevents the leak — non-vacuous counterfactual"

# --- self-check: this suite's own script is shellcheck clean (soft-skip) ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "shellcheck: check-provenance.sh / run.sh must be clean"
  pass "shellcheck clean (checker + test runner)"
else
  printf 'SKIP: shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll check-provenance assertions passed.\n'
