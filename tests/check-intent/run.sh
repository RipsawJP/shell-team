#!/usr/bin/env bash
# run.sh — drive bin/check-intent.sh against synthetic spec/board fixtures and
# assert the state machine documented in docs/specs/T-071-frozen-intent.md
# (AC2): every case below is asserted on BOTH exit code AND the stderr
# classification token, per the "wrong-but-nonzero must not look like
# success" fixture-synthesis discipline.
#
#   (i)    正系 aligned                                            -> exit 0
#   (ii)   無批准で intent ブロックを改変                             -> exit 1, "drift-detected"
#   (iii)  批准つき再凍結（intent-ratified + board hash 更新）        -> exit 0
#   (iv)   マーカー不在 / 二重マーカー対 / END が BEGIN に先行         -> exit 2, "structural"
#   (v)    board の intent-hash 記録が無い / 2 行 / 非 40-hex         -> exit 2, "structural"
#   (vi)   版連鎖破れ: 欠落(v3 declared,v1→v2のみ)/重複(v1→v2×2)/逆行(v2→v1)/
#          範囲外(v5→v6)                                            -> exit 1, "drift-detected"
#   (vii)  CRLF 混在でも正系は aligned                                -> exit 0
#   (viii) self-referential board/spec prose を記録として誤カウントしない -> exit 0
#   (ix)   意味的 drift 非判定の境界（無関係ファイル/セクション変更）  -> exit 0
#   (x)    3 起動形（bash / ./ / PATH ベア名）で同一挙動               -> same rc
#   (xi)   Codex round1 rework 回帰ロック: board エントリのクロスリファ
#          レンス誤スコープ（Major 1）/ mktemp 失敗の fail-closed 分類
#          （Major 2）                                              -> exit 2/1 per case
#   (xii)  Codex round2 rework 回帰ロック（spec Notes for engineer 指示の
#          4 fixture）: 重複 top-level エントリ（Blocker）/ 非 TOP_RE 境界
#          のスコープ漏れ（Major）/ 書き込みパイプライン失敗（Major）/
#          ディレクトリ引数 ×2（Major）                              -> exit 2 per case
#   (xii-f) TASK_ID_RE 行末アンカー回帰ロック（round4 minor・判定1/structural
#          資産。旧 (xiv-d) — rework5 で tamper-evidence 一括削除に誤同梱され
#          消えたのを orchestrator 判断で訂正・(xii) 番台へ復活）: 不整形
#          `**Task ID**: T-NNNjunk-trailing-garbage` 行                -> exit 2, "structural"
#   (xiii-b) Codex round3 rework 回帰ロック（board-scope-boundary クラスの
#          通算4件目・反転境界の資産）: `* `/`+ ` bullet 直後の hash 漏入
#                                                    -> exit 2 per case
#
# 判定 4（ledger tamper-evidence / first-seen-wins・shallow/bootstrap degrade）
# は rework3/rework4 で実装されたが rework5（2026-07-18）で本タスクから
# 切り出し済み（ユーザー事前確約 Option B の執行・round3〜5 で当該サブシステム
# に独立欠陥が5件連続したため）。判定4専用だった fixture (xiii-a)/(xiii-c)/
# (xiii-d)/(xiv-a)〜(xiv-c) と、その専用の git 履歴つき使い捨てリポ scaffolding
# （fgit ラッパー等）は判定1〜3 のどの fixture からも使われなくなったため削除
# した。設計材料・PoC は tasks/reviews/T-071.md Rounds 3-5 が正典として保持する。
# 旧 (xiv-d)（TASK_ID_RE 行末アンカー・round4 minor）は tamper-evidence では
# なく判定1/structural の資産であり、rework5 一括削除リストへの誤同梱だった
# ため訂正: (xii-f) として復活済み（同一内容・番号のみ変更）。
#
# Fixtures use synthetic task id T-900 (not a real board task) built fresh in
# a temp dir per case — no static fixtures/ directory needed. Temp roots live
# under $TMPDIR when set (restricted sandboxes), falling back to
# $HERE/tmp-roots on plain CI runners (2026-07-06 lesson: prefer $TMPDIR).

set -euo pipefail

# Environment normalization (#233 item 4): an inherited BASH_ENV startup hook
# (a reachable real class — a set BASH_ENV is a standard bash startup file)
# must never leak output/behavior into a checker invocation captured below.
unset BASH_ENV

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-intent.sh"

# Collision-safe temp root (#233 item 3): `mktemp -d` gives EACH invocation
# its own unique directory (unlike a fixed, predictable name), so two
# concurrent runs of this suite cannot clobber each other's fixtures via a
# shared `rm -rf`.
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-intent-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# dump_cmp_diag <label> <file1> <file2> [<file3> ...] (#301 fast-follow):
# when a byte-precise `cmp` comparison across invocation styles FAILs below,
# `fail()` immediately triggers the EXIT-trap (`rm -rf "$TMP"`) that deletes
# the very temp files the failure message points to ("see $C/out-1.txt /
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

# --- oracle: identical normalization + hash pipeline as bin/check-intent.sh -
# (duplicated deliberately: this is fixture-construction tooling, not the
# code under test — the actual behavior under test is the CHECKER's own
# extraction/normalization, exercised below via run_checker.)
compute_hash() {  # $1 = spec file
  local spec="$1" b e
  b="$(awk -v m="<!-- BEGIN intent-block: ${TASK_ID} -->" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$spec")"
  e="$(awk -v m="<!-- END intent-block: ${TASK_ID} -->"   '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$spec")"
  awk -v b="$b" -v e="$e" 'NR > b && NR < e' "$spec" \
    | sed -e 's/\r$//' -e 's/[[:space:]]*$//' \
    | awk '{ lines[NR] = $0; if ($0 != "") { if (first == 0) first = NR; last = NR } } END { for (i = first; i <= last && first > 0; i++) print lines[i] }' \
    | git hash-object --stdin
}

write_spec() {  # $1 = dest file, $2 = Goal sentence, $3 = extra content to append (or "")
  local dest="$1" goal="$2" extra="${3:-}"
  {
    printf '# Fixture spec\n\n'
    printf '**Status**: READY_FOR_ARCH\n**Owner**: pm-spec\n**Task ID**: %s\n\n' "$TASK_ID"
    printf '## Problem\nMutable prose that must not affect the hash.\n\n'
    printf '<!-- BEGIN intent-block: %s -->\n\n' "$TASK_ID"
    printf '## Goal\n%s\n\n' "$goal"
    printf '## Non-goals\n- Not this.\n\n'
    printf '## Acceptance criteria\n- [ ] AC1 something\n\n'
    printf '## Input space\n- Reachable: X\n- Out-of-scope: Y\n\n'
    printf '<!-- END intent-block: %s -->\n\n' "$TASK_ID"
    printf '## Assumptions\n- none\n'
    # if/then (not `A && B`, SC2015) so an empty $extra never yields a
    # non-zero exit for this function under `set -e`.
    if [ -n "$extra" ]; then printf '%s\n' "$extra"; fi
  } > "$dest"
}

write_board() {  # $1 = dest file, $2 = version, $3 = hash, $4... = extra sub-bullet lines
  local dest="$1" ver="$2" hash="$3"
  shift 3
  {
    printf '# Tasks\n\n## Active\n\n'
    # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
    # literal board flag token, not a command substitution.
    printf -- '- [ ] **%s** fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
    printf '  - intent-hash (v%s): %s\n' "$ver" "$hash"
    for extra in "$@"; do
      printf '%s\n' "$extra"
    done
  } > "$dest"
}

# run_checker <spec> <board> -- captures RC (exit code) and ERR (stderr text)
RC=0
ERR=""
run_checker() {
  local out
  set +e
  out="$(bash "$CHECKER" "$1" "$2" 2>&1 >/dev/null)"
  RC=$?
  set -e
  ERR="$out"
}

# ============================================================================
# (i) positive: aligned
# ============================================================================
C="$TMP/case-i"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "(i): expected exit 0 (aligned), got $RC: $ERR"
pass "(i): pristine spec+board is aligned (exit 0)"

# ============================================================================
# (ii) unratified drift: intent block edited, board hash untouched
# ============================================================================
C="$TMP/case-ii"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_spec "$C/spec.md" "Do a DIFFERENT thing (unratified edit)."
write_board "$C/board.md" 1 "$GOOD_HASH"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 1 ] || fail "(ii): expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "(ii): stderr must carry the 'drift-detected' classification token, got: $ERR"
pass "(ii): unratified intent-block edit is drift-detected (exit 1, token present)"

# ============================================================================
# (iii) ratified re-freeze: v1->v2 with intent-ratified + updated board hash
# ============================================================================
C="$TMP/case-iii"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_spec "$C/spec.md" "Do the REVISED thing (ratified rework)."
V2_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-07-18): v1→v2 — human GO recorded by orchestrator — rework to clarify wording'
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "(iii): ratified re-freeze should be aligned, got $RC: $ERR"
pass "(iii): ratified re-freeze (v1→v2 + updated hash) is aligned (exit 0)"

# ============================================================================
# (iv) structural: marker absent / duplicated / reversed
# ============================================================================
C="$TMP/case-iv"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"

grep -v 'BEGIN intent-block' "$C/spec.md" > "$C/spec-nobegin.md"
run_checker "$C/spec-nobegin.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "(iv-a) missing BEGIN marker: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(iv-a): stderr must carry 'structural' token, got: $ERR"

cp "$C/spec.md" "$C/spec-dup.md"
printf -- '<!-- BEGIN intent-block: %s -->\n' "$TASK_ID" >> "$C/spec-dup.md"
run_checker "$C/spec-dup.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "(iv-b) duplicated BEGIN marker: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(iv-b): stderr must carry 'structural' token, got: $ERR"

awk -v id="$TASK_ID" '
  $0 == "<!-- BEGIN intent-block: " id " -->" { print "<!-- END intent-block: " id " -->"; next }
  $0 == "<!-- END intent-block: "   id " -->" { print "<!-- BEGIN intent-block: " id " -->"; next }
  { print }
' "$C/spec.md" > "$C/spec-reversed.md"
run_checker "$C/spec-reversed.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "(iv-c) reversed markers: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(iv-c): stderr must carry 'structural' token, got: $ERR"
pass "(iv): missing / duplicated / reversed intent-block markers all exit 2 with 'structural' token"

# ============================================================================
# (v) structural: board intent-hash record missing / duplicated / non-40-hex
# ============================================================================
C="$TMP/case-v"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"

write_board "$C/board-missing.md" 1 "$GOOD_HASH"
grep -v 'intent-hash' "$C/board-missing.md" > "$C/board-missing2.md"
run_checker "$C/spec.md" "$C/board-missing2.md"
[ "$RC" -eq 2 ] || fail "(v-a) missing intent-hash record: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(v-a): stderr must carry 'structural' token, got: $ERR"

write_board "$C/board-dup.md" 1 "$GOOD_HASH"
printf '  - intent-hash (v1): %s\n' "$GOOD_HASH" >> "$C/board-dup.md"
run_checker "$C/spec.md" "$C/board-dup.md"
[ "$RC" -eq 2 ] || fail "(v-b) duplicated intent-hash record: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(v-b): stderr must carry 'structural' token, got: $ERR"

write_board "$C/board-badhex.md" 1 "not-forty-hex-chars"
run_checker "$C/spec.md" "$C/board-badhex.md"
[ "$RC" -eq 2 ] || fail "(v-c) non-40-hex intent-hash value: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(v-c): stderr must carry 'structural' token, got: $ERR"
pass "(v): missing / duplicated / non-40-hex board intent-hash records all exit 2 with 'structural' token"

# ============================================================================
# (vi) drift: version-chain integrity failures — gap / duplicate / reversal /
#      out-of-range (Codex round1 rework fast-follow: a "gap" fixture alone
#      only ever exercises the "record COUNT mismatch" path; it never reaches
#      the per-transition "found != 1" branch of the version-chain loop below
#      it, which is what actually catches a duplicate whose count happens to
#      match, a transition pointing the wrong direction, or a ratification
#      number beyond the board-declared vN).
# ============================================================================
C="$TMP/case-vi"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_spec "$C/spec.md" "Do the REVISED thing."
V2_HASH="$(compute_hash "$C/spec.md")"

# (vi-a) gap: board declares v3, only v1→v2 ratified (record-count mismatch)
write_board "$C/board-gap.md" 3 "$V2_HASH" \
  '  - intent-ratified (2026-07-18): v1→v2 — human GO recorded by orchestrator — rework to clarify wording'
run_checker "$C/spec.md" "$C/board-gap.md"
[ "$RC" -eq 1 ] || fail "(vi-a) version-chain gap: expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "(vi-a): stderr must carry 'drift-detected' token, got: $ERR"

# (vi-b) duplicate: board declares v2 but carries TWO identical v1→v2 records
# (record count 2 != expected 1 — same "count mismatch" path as (vi-a), but
# from the too-many side rather than too-few).
write_board "$C/board-dup.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-07-18): v1→v2 — human GO recorded by orchestrator — rework to clarify wording' \
  '  - intent-ratified (2026-07-18): v1→v2 — human GO recorded by orchestrator — duplicate record'
run_checker "$C/spec.md" "$C/board-dup.md"
[ "$RC" -eq 1 ] || fail "(vi-b) duplicated ratified record: expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "(vi-b): stderr must carry 'drift-detected' token, got: $ERR"

# (vi-c) reversal: board declares v2, record COUNT matches (1) but the one
# record present points the wrong direction (v2→v1 instead of v1→v2) — this
# is the first fixture to actually exercise the per-transition "found != 1"
# branch, never reached by (vi-a) or (vi-b).
write_board "$C/board-reversed.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-07-18): v2→v1 — human GO recorded by orchestrator — reversed record'
run_checker "$C/spec.md" "$C/board-reversed.md"
[ "$RC" -eq 1 ] || fail "(vi-c) reversed v2→v1 record: expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "(vi-c): stderr must carry 'drift-detected' token, got: $ERR"

# (vi-d) out-of-range: board declares v2, record COUNT matches (1) but the
# one record present names a transition beyond the declared vN (v5→v6),
# also caught only by the per-transition "found != 1" branch.
write_board "$C/board-oor.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-07-18): v5→v6 — human GO recorded by orchestrator — out-of-range record'
run_checker "$C/spec.md" "$C/board-oor.md"
[ "$RC" -eq 1 ] || fail "(vi-d) out-of-range v5→v6 record: expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "(vi-d): stderr must carry 'drift-detected' token, got: $ERR"

pass "(vi): version-chain gap / duplicate / reversal / out-of-range ratified records are all drift-detected (exit 1, token present)"

# ============================================================================
# (vii) CRLF tolerance: spec/board with CRLF line endings still aligned
# ============================================================================
C="$TMP/case-vii"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"
sed 's/$/\r/' "$C/spec.md"  > "$C/spec-crlf.md"
sed 's/$/\r/' "$C/board.md" > "$C/board-crlf.md"
run_checker "$C/spec-crlf.md" "$C/board-crlf.md"
[ "$RC" -eq 0 ] || fail "(vii): CRLF spec/board should normalize to aligned (exit 0), got $RC: $ERR"
pass "(vii): CRLF line endings in spec/board normalize to aligned (exit 0)"

# ============================================================================
# (viii) self-referential prose must not be miscounted as a real record/marker
# ============================================================================
C="$TMP/case-viii"; mkdir -p "$C"
# shellcheck disable=SC2016  # the backtick-quoted marker text is literal
# prose to embed in the fixture, not a command substitution.
write_spec "$C/spec.md" "Do the thing." \
  "$(printf '\n## Notes for engineer\nSee the marker `<!-- BEGIN intent-block: %s -->` quoted mid-sentence for reference; it is NOT a second marker occurrence.\n' "$TASK_ID")"
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH" \
  "$(printf '  - freeze (dogfood): a real record looks like \xe3\x80\x8c- intent-hash (v9): 0000000000000000000000000000000000000000\xe3\x80\x8d — this sentence is prose only, not a structured sub-bullet.')"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "(viii): self-referential spec/board prose must not be miscounted, expected aligned (exit 0), got $RC: $ERR"
pass "(viii): self-referential marker/record quoting in prose is not miscounted (exit 0)"

# ============================================================================
# (ix) semantic-drift non-detection boundary: unrelated content changes only
# ============================================================================
C="$TMP/case-ix"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"
# Mutate ONLY the mutable Problem section (outside the marker region) and add
# an unrelated new file alongside the fixture — the checker must never look
# beyond <spec.md> <board.md>, so behavior/semantic drift elsewhere is a
# non-event by construction (DP4's boundary).
sed 's/Mutable prose that must not affect the hash\./COMPLETELY UNRELATED prose edit./' "$C/spec.md" > "$C/spec-unrelated.md"
printf 'unrelated file content\n' > "$C/unrelated-new-file.txt"
run_checker "$C/spec-unrelated.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "(ix): unrelated out-of-marker/file changes must stay aligned (exit 0), got $RC: $ERR"
pass "(ix): semantic/behavioral drift outside the intent block is never judged (exit 0)"

# ============================================================================
# (x) 3 invocation styles produce identical behavior
# ============================================================================
C="$TMP/case-x"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"

rc1=0; ( cd "$REPO_ROOT" && bash bin/check-intent.sh "$C/spec.md" "$C/board.md" ) >"$C/out-1.txt" 2>&1 || rc1=$?
rc2=0; ( cd "$REPO_ROOT" && ./bin/check-intent.sh "$C/spec.md" "$C/board.md" ) >"$C/out-2.txt" 2>&1 || rc2=$?

PATHBIN="$TMP/pathbin"
mkdir -p "$PATHBIN"
ln -sf "$CHECKER" "$PATHBIN/check-intent.sh"
# Deliberately scoped to this ( ) subshell only — each PATH-bare-name
# invocation below (here and in the AC8 case further down) re-exports PATH
# inside its OWN subshell/command-prefix so the parent shell's PATH is never
# touched; the occurrences of this pattern in this file are independent, not
# a forgotten propagation (same convention as tests/check-provenance/run.sh).
# (the disable directive must sit directly above the subshell STATEMENT, on
# its own line — shellcheck does not attach it correctly to the second half
# of a `var=0; ( ... ) || var=$?` compound line.)
rc3=0
# shellcheck disable=SC2030
( export PATH="$PATHBIN:$PATH"; cd "$REPO_ROOT" && check-intent.sh "$C/spec.md" "$C/board.md" ) >"$C/out-3.txt" 2>&1 || rc3=$?

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ] || [ "$rc3" -ne 0 ]; then
  fail "(x): invocation styles disagree or failed — bash=$rc1 dot-slash=$rc2 PATH-bare=$rc3"
fi
# Byte-level (newline-preserving) comparison via `cmp`, not a "$(...)" string
# capture — command substitution strips trailing newlines and would silently
# pass a trailing-newline-only regression (#233 item 2).
if ! cmp -s "$C/out-1.txt" "$C/out-2.txt"; then
  dump_cmp_diag "(x)" "$C/out-1.txt" "$C/out-2.txt"
  fail "(x): output differs across invocation styles (bash vs ./) — see $C/out-1.txt / $C/out-2.txt"
fi
if ! cmp -s "$C/out-2.txt" "$C/out-3.txt"; then
  dump_cmp_diag "(x)" "$C/out-2.txt" "$C/out-3.txt"
  fail "(x): output differs across invocation styles (./ vs PATH-bare) — see $C/out-2.txt / $C/out-3.txt"
fi
pass "(x): bash / ./ / PATH-bare-name invocations all produce identical behavior (exit 0) and byte-identical output"

# ============================================================================
# (#301 diagnostics) non-vacuous demonstration: dump_cmp_diag — the SAME
# diagnostic-emit path the real (x) cmp sites above use — surfaces the
# differing bytes to stderr on a forced mismatch (clause i), and is never
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
# (xi) Codex round1 rework regression locks: board scoping (Major 1) + mktemp
#      fail-closed (Major 2). Reproduces the exact PoCs recorded in
#      tasks/reviews/T-071.md so a future regression is caught mechanically
#      rather than only by manual re-review.
# ============================================================================
C="$TMP/case-xi"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
X_HASH="$(printf '0%.0s' {1..40})"

# (xi-a) PoC①: another task's TITLE cross-references this task-id in bold
# prose AND that other task carries its own (unrelated) intent-hash record.
# Pre-fix, a substring match on "**T-900**" anywhere in the line pulled the
# OTHER task's sub-bullet into this task's scope too, double-counting valid
# intent-hash records and misclassifying an aligned board as structural(2).
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **T-800** unrelated fixture task — see also **%s** for context — `READY_FOR_ARCH` — spec: other.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$X_HASH"
  # shellcheck disable=SC2016  # same literal token as above.
  printf -- '- [ ] **%s** target fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-crossref.md"
run_checker "$C/spec.md" "$C/board-crossref.md"
[ "$RC" -eq 0 ] || fail "(xi-a) cross-referencing title must not merge into this task's scope: expected exit 0 (aligned), got $RC: $ERR"
pass "(xi-a): another task's bold cross-reference to this task-id in its TITLE does not merge its intent-hash into this task's own scope (aligned, exit 0)"

# (xi-b) PoC②: this task has NO real top-level entry at all — the ONLY line
# mentioning its task-id is another task's title cross-referencing it in
# prose, and that OTHER task happens to carry an intent-hash record whose
# value matches this spec's computed hash. Pre-fix this was miscounted as
# THIS task's own record and returned a false aligned(0); the entry's total
# absence must fail closed as structural(2) instead.
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **T-800** unrelated fixture task — see also **%s** for context — `READY_FOR_ARCH` — spec: other.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-noreal.md"
run_checker "$C/spec.md" "$C/board-noreal.md"
[ "$RC" -eq 2 ] || fail "(xi-b) missing real top-level entry (only a cross-reference in another task's title): expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xi-b): stderr must carry 'structural' token, got: $ERR"
pass "(xi-b): absence of this task's own top-level board entry fails closed as structural(2) even when another task's title cross-references it with a matching intent-hash (no false aligned)"

# (xi-c) mktemp failure under an unwritable TMPDIR must fail closed as a
# classified usage error (exit 2), never a bare 'set -e' exit 1 that would
# masquerade as an undertokened drift-detected.
write_board "$C/board.md" 1 "$GOOD_HASH"
NONEXISTENT_TMPDIR="$TMP/does-not-exist-mktemp-target"
set +e
XI_C_OUT="$(TMPDIR="$NONEXISTENT_TMPDIR" bash "$CHECKER" "$C/spec.md" "$C/board.md" 2>&1 >/dev/null)"
XI_C_RC=$?
set -e
[ "$XI_C_RC" -eq 2 ] || fail "(xi-c) mktemp failure under unwritable TMPDIR: expected exit 2 (usage), got $XI_C_RC: $XI_C_OUT"
grep -q 'usage' <<< "$XI_C_OUT" || fail "(xi-c): stderr must carry 'usage' token, got: $XI_C_OUT"
pass "(xi-c): mktemp failure (unwritable TMPDIR) fails closed as a classified usage error (exit 2, token present), not a bare drift exit 1"

# ============================================================================
# (xii) Codex round2 rework regression locks: the 4 fixtures the T-071 spec's
#      "board パース状態機械の正典" / "fail-closed の全数 inventory 要求" /
#      "引数の型・健全性検証" sections explicitly require (Notes for
#      engineer), reproducing each round2 Blocker/Major PoC recorded in
#      tasks/reviews/T-071.md Round 2.
# ============================================================================

# (xii-a) Blocker: a DUPLICATE top-level entry for this task-id (a stale
# leftover in one section alongside the real entry in another) must never
# let the stale entry's hash satisfy the real entry's missing record — the
# uniqueness requirement (entry_count) must fail this closed as
# structural(2), not silently merge the two entries' sub-bullets into one
# scope and return a false aligned(0).
C="$TMP/case-xii-a"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **%s** current fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf '\n## Done\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_MERGE` is a
  # literal board flag token, not a command substitution.
  printf -- '- [x] **%s** stale duplicate leftover entry — `READY_FOR_MERGE` — spec: spec.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-dup-entry.md"
run_checker "$C/spec.md" "$C/board-dup-entry.md"
[ "$RC" -eq 2 ] || fail "(xii-a) duplicate top-level entry (stale ## Done + real ## Active): expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xii-a): stderr must carry 'structural' token, got: $ERR"
pass "(xii-a): a duplicate top-level board entry for this task-id (stale leftover + real entry) fails closed as structural(2) instead of merging scopes into a false aligned"

# (xii-b) Major: a non-TOP_RE top-level-LOOKING line (malformed casing) must
# still act as a scope boundary — its own (matching) intent-hash sub-bullet
# must never leak into the PRECEDING real entry's scope, which itself has no
# record of its own and must fail closed as structural(2), not aligned(0).
C="$TMP/case-xii-b"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **%s** current fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf -- '- [ ] **t-900** malformed-casing top-level-looking line\n'
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-scope-leak.md"
run_checker "$C/spec.md" "$C/board-scope-leak.md"
[ "$RC" -eq 2 ] || fail "(xii-b) non-TOP_RE malformed top-level-looking line leaking scope: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xii-b): stderr must carry 'structural' token, got: $ERR"
pass "(xii-b): a malformed (non-TOP_RE) top-level-looking line still closes the preceding entry's scope — its own intent-hash never leaks in (structural(2), no false aligned)"

# (xii-c) Major: the extraction pipeline's WRITE (not just mktemp's earlier
# file creation) must fail closed. Under `ulimit -f 0`, the pipeline write
# hits SIGXFSZ; this must surface as a classified usage(2) error, never the
# raw, untokened 128+SIGXFSZ (153) exit that `set -e`/`pipefail` alone would
# produce. Captured via command substitution (a pipe, not a regular file) —
# capturing this scenario's output through a REGULAR FILE would itself hit
# the same ulimit and mask the very failure under test.
C="$TMP/case-xii-c"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
set +e
XII_C_OUT="$( (ulimit -f 0; bash "$CHECKER" "$C/spec.md" "$C/board.md") 2>&1 >/dev/null )"
XII_C_RC=$?
set -e
[ "$XII_C_RC" -eq 2 ] || fail "(xii-c) extraction-pipeline write failure (ulimit -f 0): expected exit 2 (usage), got $XII_C_RC: $XII_C_OUT"
grep -q 'usage' <<< "$XII_C_OUT" || fail "(xii-c): stderr must carry 'usage' token, got: $XII_C_OUT"
pass "(xii-c): an extraction-pipeline WRITE failure (ulimit -f 0) fails closed as a classified usage error (exit 2, token present), not a bare 128+SIGXFSZ exit"

# (xii-d)/(xii-e) Major: both positional arguments must be validated as
# regular files (`-f`) BEFORE either read loop is ever reached — a directory
# argument must never reach a `while read` loop, which would otherwise either
# raw-exit (spec argument) or spin forever re-reading the same "Is a
# directory" error (board argument — a CI-hanging failure mode). The board
# side is asserted non-hanging via a perl `alarm`-based timeout wrapper (no
# `timeout`/`gtimeout` on this bash 3.2 / macOS baseline).
C="$TMP/case-xii-de"; mkdir -p "$C/a-directory"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"

run_checker "$C/a-directory" "$C/board.md"
[ "$RC" -eq 2 ] || fail "(xii-d) directory as the spec argument: expected exit 2 (usage), got $RC: $ERR"
grep -q 'usage' <<< "$ERR" || fail "(xii-d): stderr must carry 'usage' token, got: $ERR"
pass "(xii-d): a directory passed as the spec argument fails closed as a classified usage error (exit 2, token present), never an unclassified raw exit"

set +e
XII_E_OUT="$(perl -e 'alarm 8; exec @ARGV' bash "$CHECKER" "$C/spec.md" "$C/a-directory" 2>&1 >/dev/null)"
XII_E_RC=$?
set -e
[ "$XII_E_RC" -eq 2 ] || fail "(xii-e) directory as the board argument: expected exit 2 (usage) within an 8s alarm (no hang), got $XII_E_RC: $XII_E_OUT"
grep -q 'usage' <<< "$XII_E_OUT" || fail "(xii-e): stderr must carry 'usage' token, got: $XII_E_OUT"
pass "(xii-e): a directory passed as the board argument fails closed as a classified usage error (exit 2, token present) WITHOUT hanging (asserted via an 8s perl alarm wrapper — CI-hang regression lock)"

# (xii-f) TASK_ID_RE line-end anchor regression lock (Codex round4 minor — a
# judgment-1/structural asset, NOT tamper-evidence; this fixture was
# originally (xiv-d) under the now-removed rework4 tamper-evidence fixture
# batch, and was mistakenly swept up in that batch's wholesale deletion
# during rework5 — restored here, unchanged in content, under the (xii)
# round2-era numbering since TASK_ID_RE itself was never part of judgment 4):
# a malformed **Task ID**: line with trailing garbage after the id must fail
# closed as structural(2), not silently derive the id via a non-line-end-
# anchored match.
C="$TMP/case-xii-f"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"
sed "s/\\*\\*Task ID\\*\\*: ${TASK_ID}/**Task ID**: ${TASK_ID}junk-trailing-garbage/" "$C/spec.md" > "$C/spec-malformed-taskid.md"
run_checker "$C/spec-malformed-taskid.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "(xii-f) malformed Task ID line with trailing garbage: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xii-f): stderr must carry 'structural' token, got: $ERR"
pass "(xii-f): a malformed '**Task ID**: ${TASK_ID}junk...' line (trailing garbage after the id) fails closed as structural(2) instead of silently deriving ${TASK_ID} via a non-line-end-anchored match (TASK_ID_RE line-end anchor regression lock, restored after mistaken removal in rework5)"

# ============================================================================
# (xiii-b) board-scope-boundary regression lock (4th independent defect in
#      that class, round3 Blocker — the ONLY rework3 fixture that survives
#      T-071 rework5's tamper-evidence carve-out; it locks the board-scope
#      inversion in judgment 1, not judgment 4). rework3's OTHER 3 fixtures
#      ((xiii-a) same-version ledger overwrite, (xiii-c) shallow degrade,
#      (xiii-d) bootstrap vacuous pass) and rework4's judgment-4 fixtures
#      ((xiv-a)/(xiv-a-overwrite)/(xiv-b)/(xiv-b-overwrite)/(xiv-c))
#      were judgment-4 (ledger tamper-evidence) regression locks and were
#      removed together with that judgment in rework5 (rework4's (xiv-d) was
#      NOT a judgment-4 asset — it is judgment-1/structural and was restored
#      above as (xii-f), see header comment) — see this suite's header
#      comment and tasks/reviews/T-071.md Rounds 3-5 for the carried-forward
#      PoCs and design material.
# ============================================================================

# (xiii-b) Blocker B regression lock (board-scope-boundary class, 4th
# independent defect): a CommonMark-legal `* [ ]` / `+ [ ]` bullet directly
# after this task's own (record-less) entry must still close its scope — its
# own (matching) intent-hash sub-bullet must never leak into the PRECEDING
# entry, which has no record of its own and must fail closed as
# structural(2), never a false aligned(0).
C="$TMP/case-xiii-b"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **%s** current fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf -- '* [ ] **t-900-star** asterisk-bullet top-level-looking line (not "- ")\n'
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-star-bullet.md"
run_checker "$C/spec.md" "$C/board-star-bullet.md"
[ "$RC" -eq 2 ] || fail "(xiii-b-star) '* [ ]' bullet leaking scope: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xiii-b-star): stderr must carry 'structural' token, got: $ERR"

{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # same literal token as above.
  printf -- '- [ ] **%s** current fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf -- '+ [ ] **t-900-plus** plus-bullet top-level-looking line (not "- ")\n'
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-plus-bullet.md"
run_checker "$C/spec.md" "$C/board-plus-bullet.md"
[ "$RC" -eq 2 ] || fail "(xiii-b-plus) '+ [ ]' bullet leaking scope: expected exit 2 (structural), got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(xiii-b-plus): stderr must carry 'structural' token, got: $ERR"
pass "(xiii-b): '* [ ]'/'+ [ ]' CommonMark-legal bullets (neither an enumerated '- ' line) still close the preceding entry's scope under the inverted board-scope definition — no hash leak, structural(2) both ways"

# ============================================================================
# (xiv) T-1016 D2: a blank line between two `- intent-hash` sub-bullets no
# longer closes the ledger's scope — proved as an invariance property, not a
# message string. Two boards differ only by one blank line between the
# task's two intent-hash sub-bullets; the checker must return the SAME exit
# code for both, and that code must be 2 (a structural duplicate) — before
# T-1016 the blank-line board hid the second record from the entry's scope
# and returned a different (wrong) verdict. A third board carrying exactly
# one (mismatched) hash returns 1, the positive control proving 2 is not
# returned unconditionally.
# ============================================================================
C="$TMP/case-xiv"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
DUMMY_HASH_0="$(printf '0%.0s' {1..40})"
DUMMY_HASH_1="$(printf '1%.0s' {1..40})"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # the backtick-quoted `READY_FOR_ARCH` is a
  # literal board flag token, not a command substitution.
  printf -- '- [ ] **%s** fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$DUMMY_HASH_0"
  printf '\n'
  printf '  - intent-hash (v1): %s\n' "$DUMMY_HASH_1"
  printf '\n## Done\n'
} > "$C/board-blank.md"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # same literal token as above.
  printf -- '- [ ] **%s** fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$DUMMY_HASH_0"
  printf '  - intent-hash (v1): %s\n' "$DUMMY_HASH_1"
  printf '\n## Done\n'
} > "$C/board-noblank.md"
{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # same literal token as above.
  printf -- '- [ ] **%s** fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf '  - intent-hash (v1): %s\n' "$DUMMY_HASH_0"
  printf '\n## Done\n'
} > "$C/board-single.md"

run_checker "$C/spec.md" "$C/board-blank.md"
XIV_BLANK_RC="$RC"
run_checker "$C/spec.md" "$C/board-noblank.md"
XIV_NOBLANK_RC="$RC"
run_checker "$C/spec.md" "$C/board-single.md"
XIV_SINGLE_RC="$RC"

[ "$XIV_BLANK_RC" -eq "$XIV_NOBLANK_RC" ] \
  || fail "blank-line-verdict-invariance: expected the blank-line and no-blank-line boards to return the SAME exit code, got blank=$XIV_BLANK_RC noblank=$XIV_NOBLANK_RC"
[ "$XIV_BLANK_RC" -eq 2 ] \
  || fail "blank-line-verdict-invariance: expected exit 2 (structural duplicate) for the blank-line board, got $XIV_BLANK_RC"
[ "$XIV_SINGLE_RC" -eq 1 ] \
  || fail "blank-line-verdict-invariance: positive control (single hash) expected exit 1 (drift), got $XIV_SINGLE_RC — proves exit 2 is not returned unconditionally"
pass "blank-line-verdict-invariance — a blank line between the task's two intent-hash sub-bullets does not change the verdict (both exit 2); a single-hash positive control returns 1, proving 2 is not unconditional"
pass "blank-line-inside-entry-keeps-scope — the blank-line board's SECOND intent-hash sub-bullet is still counted as belonging to the SAME entry (both records seen => structural duplicate, never a hidden second record producing a false aligned board)"

# ============================================================================
# AC8 (#233 item 5, non-vacuous lock): a `dirname` failure during the
# symlink-resolution bootstrap must fail CLOSED as a classified usage error
# (exit 2), never fail OPEN into $PWD (the T-074-rework1-ported independent
# dirname guard). A fake `dirname` that always fails is prepended to PATH so
# every OTHER command the checker needs (readlink/cd/pwd/basename/git/awk/
# sed/grep) still resolves normally — only `dirname` itself is broken.
# ============================================================================
C="$TMP/case-ac8"; mkdir -p "$C/fakebin"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
cat > "$C/fakebin/dirname" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$C/fakebin/dirname"

set +e
# shellcheck disable=SC2031  # PATH is prefixed on this single command only —
# independent of case (x)'s own subshell-scoped PATH export above.
AC8_OUT="$(PATH="$C/fakebin:$PATH" bash "$CHECKER" "$C/spec.md" "$C/board.md" 2>&1 >/dev/null)"
AC8_RC=$?
set -e
[ "$AC8_RC" -eq 2 ] || fail "AC8: a failing 'dirname' during self-resolution should fail closed as usage(2), got $AC8_RC: $AC8_OUT"
grep -q 'usage' <<< "$AC8_OUT" || fail "AC8: stderr must carry the 'usage' token, got: $AC8_OUT"
pass "AC8: a failing 'dirname' in the resolver bootstrap fails closed as a classified usage error (exit 2, token present), never a fail-open \$PWD substitution"

# Non-vacuous counterfactual: the OLD (unsplit, single `cd`+`dirname`+`pwd`
# substitution) bootstrap fails OPEN for this exact scenario — dirname's
# failure yields an empty string, `cd ""` silently succeeds as `cd .`
# (confirmed: `cd "" && pwd` returns rc=0 on this bash), and SCRIPT_DIR/SELF
# are never actually consulted again outside --help, so the OLD checker
# simply proceeds to the real judgment and reports its normal (here: aligned,
# exit 0) result instead of failing closed — the "fail-open exit 0" the spec
# Notes for engineer warns against.
#
# SELF-CONTAINED by construction (Codex round1 Blocker): rather than fetching
# the pre-#233-item-5 bootstrap at test-run time via `git show
# $(git merge-base develop HEAD)`, the OLD (unsplit) bootstrap LINE is baked
# in below as a minimal, standalone inline fixture — copied verbatim from the
# pre-fix `SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)" || fail_usage
# ...` form (confirmed byte-identical to the merge-base at authoring time).
# This has ZERO dependency on a `develop` branch existing locally (broken in
# CI's detached-HEAD PR checkout, where bare `develop` never resolves) and
# ZERO dependency on `HEAD` not yet having merged the fix (which would
# otherwise make `merge-base develop HEAD == HEAD`, i.e. the NEW split-guard
# code, a permanent vacuous-pass after merge). The fragment only needs to
# reach the fail-OPEN `exit 0` this exact scenario hits; it stands in for the
# rest of the real checker's judgment (irrelevant to proving THIS defect)
# with the same `exit 0` a real "aligned" verdict would produce.
OLD_CHECKER="$TMP/check-intent-OLD.sh"
cat > "$OLD_CHECKER" <<'OLDEOF'
#!/usr/bin/env bash
set -euo pipefail
die() { printf 'check-intent: %s: %s\n' "$1" "$2" >&2; exit 2; }
fail_usage() { die usage "$1"; }
script_path="${BASH_SOURCE[0]}"
# OLD (pre-#233-item-5, unsplit) final SCRIPT_DIR resolution: a single
# combined `cd`+`dirname`+`pwd` substitution guarded by ONE trailing
# `|| fail_usage` only observes the OUTER `cd && pwd` pipeline's exit status
# — if `dirname` itself fails, the substitution yields an empty string,
# `cd ""` silently succeeds as `cd .`, and the `||` never fires. This is the
# exact defect #233 item 5 fixes.
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
# Bootstrap "succeeded" (silently) despite the failing dirname — the OLD
# checker proceeds past this point to its normal judgment; standing in with
# the same exit 0 a real aligned verdict would produce, since only the
# fail-open/fail-closed distinction at THIS site is under test here.
exit 0
OLDEOF
chmod +x "$OLD_CHECKER"
set +e
# shellcheck disable=SC2031  # same independent, command-scoped PATH prefix
# as the AC8_OUT invocation above.
AC8_OLD_OUT="$(PATH="$C/fakebin:$PATH" bash "$OLD_CHECKER" "$C/spec.md" "$C/board.md" 2>&1 >/dev/null)"
AC8_OLD_RC=$?
set -e
[ "$AC8_OLD_RC" -eq 0 ] || fail "AC8 counterfactual: expected the OLD (unsplit) bootstrap to fail OPEN (proceed to a normal exit 0) under a failing 'dirname', got $AC8_OLD_RC: $AC8_OLD_OUT"
pass "AC8 non-vacuous counterfactual — the OLD (unsplit) bootstrap silently proceeds (exit 0) under a failing 'dirname' instead of failing closed, the exact fail-open the NEW split-guard closes; self-contained inline fixture, no git-history/branch-name dependency"

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
FIXED_NAME_STANDIN="check-intent-fixture-root-fixed-name-standin"
OLD_TMP_A="${TMPDIR:-/tmp}/${FIXED_NAME_STANDIN}"
OLD_TMP_B="${TMPDIR:-/tmp}/${FIXED_NAME_STANDIN}"
[ "$OLD_TMP_A" = "$OLD_TMP_B" ] || fail "AC6 counterfactual sanity: expected the OLD fixed-name computation to be identical across two invocations"
NEW_TMP_A="$(mktemp -d "${TMPDIR:-/tmp}/check-intent-fixtures.XXXXXX")"
NEW_TMP_B="$(mktemp -d "${TMPDIR:-/tmp}/check-intent-fixtures.XXXXXX")"
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
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "shellcheck: check-intent.sh / run.sh must be clean"
  pass "shellcheck clean (checker + test runner)"
else
  printf 'SKIP: shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll check-intent assertions passed.\n'
