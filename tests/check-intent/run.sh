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

write_spec() {  # $1 = dest file, $2 = Goal sentence, $3 = extra content to append (or ""), $4 = Acceptance-criteria section body (or "" for the default single-line AC1 — T-1018 appended-only param, so every existing 3-arg call keeps its old 0-`check:`-line behavior)
  local dest="$1" goal="$2" extra="${3:-}" ac_body="${4:-}"
  {
    printf '# Fixture spec\n\n'
    printf '**Status**: READY_FOR_ARCH\n**Owner**: pm-spec\n**Task ID**: %s\n\n' "$TASK_ID"
    printf '## Problem\nMutable prose that must not affect the hash.\n\n'
    printf '<!-- BEGIN intent-block: %s -->\n\n' "$TASK_ID"
    printf '## Goal\n%s\n\n' "$goal"
    printf '## Non-goals\n- Not this.\n\n'
    if [ -n "$ac_body" ]; then
      printf '## Acceptance criteria\n%s\n\n' "$ac_body"
    else
      printf '## Acceptance criteria\n- [ ] AC1 something\n\n'
    fi
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

# (v-a) T-1018: the freeze moment (no intent-hash record at all) with no
# attestation is now the `attestation` classification, not `structural` — the
# one shipped-behaviour change T-1018's D2 names.
write_board "$C/board-missing.md" 1 "$GOOD_HASH"
grep -v 'intent-hash' "$C/board-missing.md" > "$C/board-missing2.md"
run_checker "$C/spec.md" "$C/board-missing2.md"
[ "$RC" -eq 2 ] || fail "(v-a) attestation-freeze-moment-unattested-refused: missing intent-hash record (freeze moment, unattested): expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "(v-a) attestation-freeze-moment-unattested-refused: stderr must carry the 'attestation' token (T-1018 gate), got: $ERR"

# (v-a2) T-1018 sibling: the SAME freeze-moment board, but WITH a conformant
# v1 freeze-attestation appended, reaches the pre-existing bootstrap
# `structural` token unchanged (D3 row 10) — documents the split from (v-a)
# rather than losing the old coverage.
printf '  - freeze-attestation (v1, 2026-08-03): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session\n' >> "$C/board-missing2.md"
run_checker "$C/spec.md" "$C/board-missing2.md"
[ "$RC" -eq 2 ] || fail "(v-a2) attestation-freeze-moment-attested-reaches-structural: expected exit 2, got $RC: $ERR"
grep -q 'structural' <<< "$ERR" || fail "(v-a2) attestation-freeze-moment-attested-reaches-structural: stderr must carry 'structural' token, got: $ERR"

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
# record of its own and must fail closed (never aligned(0)). T-1018: this
# scope-leak fixture mechanically produces exactly the "zero well-formed
# intent-hash records for this task" shape D2 names as the one shipped
# behaviour change (see the T-1018 Notes-from-engineer addendum below) — so
# the unattested freeze moment is now reported as `attestation`, not
# `structural`; the "no false aligned" property this case exists to lock is
# unaffected (still exit 2, never exit 0).
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
[ "$RC" -eq 2 ] || fail "(xii-b) non-TOP_RE malformed top-level-looking line leaking scope: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "(xii-b): stderr must carry 'attestation' token (T-1018: the leaked-away hash leaves this entry at the unattested freeze moment), got: $ERR"
pass "(xii-b): a malformed (non-TOP_RE) top-level-looking line still closes the preceding entry's scope — its own intent-hash never leaks in (exit 2, attestation — the unattested freeze moment T-1018 gates — no false aligned)"

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
# entry, which has no record of its own and must fail closed (never a false
# aligned(0)). T-1018: as with (xii-b) above, the leaked-away hash leaves
# the real entry with zero well-formed intent-hash records — the unattested
# freeze moment D2 names — so both sub-cases now report `attestation`, not
# `structural` (see the T-1018 Notes-from-engineer addendum below); the
# scope-leak property under test (exit 2, never aligned) is unaffected.
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
[ "$RC" -eq 2 ] || fail "(xiii-b-star) '* [ ]' bullet leaking scope: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "(xiii-b-star): stderr must carry 'attestation' token (T-1018: unattested freeze moment), got: $ERR"

{
  printf '# Tasks\n\n## Active\n\n'
  # shellcheck disable=SC2016  # same literal token as above.
  printf -- '- [ ] **%s** current fixture task — `READY_FOR_ARCH` — spec: spec.md\n' "$TASK_ID"
  printf -- '+ [ ] **t-900-plus** plus-bullet top-level-looking line (not "- ")\n'
  printf '  - intent-hash (v1): %s\n' "$GOOD_HASH"
} > "$C/board-plus-bullet.md"
run_checker "$C/spec.md" "$C/board-plus-bullet.md"
[ "$RC" -eq 2 ] || fail "(xiii-b-plus) '+ [ ]' bullet leaking scope: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "(xiii-b-plus): stderr must carry 'attestation' token (T-1018: unattested freeze moment), got: $ERR"
pass "(xiii-b): '* [ ]'/'+ [ ]' CommonMark-legal bullets (neither an enumerated '- ' line) still close the preceding entry's scope under the inverted board-scope definition — no hash leak, exit 2 both ways (attestation — the unattested freeze moment T-1018 gates)"

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

# ============================================================================
# T-1018 (docs/specs/T-1018-freeze-attestation-gate.md AC19): the 12
# remaining frozen assertion ids (2 of the 14 are (v-a)/(v-a2) above). Each
# id names exactly one behavior the freeze-attestation gate must exhibit;
# put in the text of the fail()/pass() calls so a reader of the suite
# output can map a failure straight back to the criterion.
# ============================================================================

# --- attestation-legacy-hash-without-record-still-aligned ------------------
C="$TMP/case-t1018-legacy"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "attestation-legacy-hash-without-record-still-aligned: expected exit 0 (aligned, the legacy carve-out), got $RC: $ERR"
pass "attestation-legacy-hash-without-record-still-aligned: a well-formed intent-hash record with zero attestation-shaped lines is still aligned (exit 0), never gated retroactively"

# --- attestation-grammar-near-miss-refused ---------------------------------
C="$TMP/case-t1018-nearmiss"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
printf '  - freeze-attestation (v1, 2026-08-03): lines=1/1 verdict=1P/0F owner=coordinating session\n' >> "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-grammar-near-miss-refused: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-grammar-near-miss-refused: stderr must carry 'attestation' token, got: $ERR"
pass "attestation-grammar-near-miss-refused: a freeze-attestation line missing the fixed sweep= literal is refused with the attestation classification (exit 2)"

# --- attestation-internal-arithmetic-refused --------------------------------
C="$TMP/case-t1018-arith"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
printf '  - freeze-attestation (v1, 2026-08-03): lines=1/2 sweep=mutual-satisfiability verdict=1P/0F owner=coordinating session\n' >> "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-internal-arithmetic-refused: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-internal-arithmetic-refused: stderr must carry 'attestation' token, got: $ERR"
pass "attestation-internal-arithmetic-refused: a freeze-attestation whose ran != total is refused with the attestation classification (exit 2) — internal arithmetic is checked for every well-formed record"

# --- attestation-count-disagrees-with-spec-refused --------------------------
C="$TMP/case-t1018-count"; mkdir -p "$C"
T1018_AC_BODY_2CHECK=$'- [ ] AC1 x\n  - check: true\n- [ ] AC2 y\n  - check: true'
write_spec "$C/spec.md" "Do the thing." "" "$T1018_AC_BODY_2CHECK"
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
printf '  - freeze-attestation (v1, 2026-08-03): lines=3/3 sweep=mutual-satisfiability verdict=3P/0F owner=coordinating session\n' >> "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-count-disagrees-with-spec-refused: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-count-disagrees-with-spec-refused: stderr must carry 'attestation' token, got: $ERR"
pass "attestation-count-disagrees-with-spec-refused: an internally-consistent freeze-attestation whose total overcounts the spec's own 2 '- check:' lines is refused with the attestation classification (exit 2), proving the checker counts rather than trusts"

# --- attestation-remedy-names-counted-total ---------------------------------
C="$TMP/case-t1018-remedy"; mkdir -p "$C"
T1018_AC_BODY_3CHECK=$'- [ ] AC1 x\n  - check: true\n- [ ] AC2 y\n  - check: true\n- [ ] AC3 z\n  - check: true'
write_spec "$C/spec.md" "Do the thing." "" "$T1018_AC_BODY_3CHECK"
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-remedy-names-counted-total: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-remedy-names-counted-total: stderr must carry 'attestation' token, got: $ERR"
grep -qF -- 'lines=3/3' <<< "$ERR" || fail "attestation-remedy-names-counted-total: refusal must name the counted total lines=3/3, got: $ERR"
grep -qF -- 'sweep=mutual-satisfiability' <<< "$ERR" || fail "attestation-remedy-names-counted-total: refusal must print the fixed sweep literal, got: $ERR"
grep -qF -- 'YYYY-MM-DD' <<< "$ERR" || fail "attestation-remedy-names-counted-total: refusal must print the YYYY-MM-DD placeholder, got: $ERR"
pass "attestation-remedy-names-counted-total: the missing-attestation refusal prints the exact counted total (lines=3/3), the fixed sweep literal, and the YYYY-MM-DD placeholder so the freeze-runner never has to guess"

# --- attestation-placeholder-paste-refused ----------------------------------
C="$TMP/case-t1018-paste"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
printf '  - freeze-attestation (v1, YYYY-MM-DD): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session\n' >> "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-placeholder-paste-refused: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-placeholder-paste-refused: stderr must carry 'attestation' token, got: $ERR"
pass "attestation-placeholder-paste-refused: pasting the printed remedy shape verbatim (the YYYY-MM-DD placeholder left in place) is refused again with the attestation classification, never silently accepted"

# --- attestation-prose-quote-not-miscounted ---------------------------------
C="$TMP/case-t1018-prose"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH" \
  '  - engineer hand-off: the freeze-attestation (v1, 2026-08-03) grammar is documented in the checker header'
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "attestation-prose-quote-not-miscounted: expected exit 0 (aligned), got $RC: $ERR"
pass "attestation-prose-quote-not-miscounted: a prose sub-bullet that quotes the freeze-attestation grammar mid-sentence is invisible to the loose anchor and never miscounted as a record (aligned, exit 0, legacy carve-out)"

# --- attestation-refreeze-missing-version-refused ---------------------------
C="$TMP/case-t1018-refreeze"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_spec "$C/spec.md" "Do the REVISED thing."
V2_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-08-03): v1→v2 — human GO recorded in conversation — a criterion was unsatisfiable' \
  '  - freeze-attestation (v1, 2026-08-02): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session'
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "attestation-refreeze-missing-version-refused: expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-refreeze-missing-version-refused: stderr must carry 'attestation' token, got: $ERR"
grep -q 'v2' <<< "$ERR" || fail "attestation-refreeze-missing-version-refused: refusal must name v2, got: $ERR"
pass "attestation-refreeze-missing-version-refused: a ratified v2 board carrying only a v1 attestation is refused with the attestation classification and names v2 — the pace rule gates a ratified re-freeze too"

# --- attestation-duplicate-and-out-of-range-refused --------------------------
C="$TMP/case-t1018-cardinality"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
T1018_A='  - freeze-attestation (v1, 2026-08-03): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session'
write_board "$C/board-dup.md" 1 "$GOOD_HASH" "$T1018_A" "$T1018_A"
run_checker "$C/spec.md" "$C/board-dup.md"
[ "$RC" -eq 2 ] || fail "attestation-duplicate-and-out-of-range-refused (duplicate): expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-duplicate-and-out-of-range-refused (duplicate): stderr must carry 'attestation' token, got: $ERR"

write_board "$C/board-oor.md" 1 "$GOOD_HASH" \
  '  - freeze-attestation (v3, 2026-08-03): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session'
run_checker "$C/spec.md" "$C/board-oor.md"
[ "$RC" -eq 2 ] || fail "attestation-duplicate-and-out-of-range-refused (out-of-range): expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-duplicate-and-out-of-range-refused (out-of-range): stderr must carry 'attestation' token, got: $ERR"
pass "attestation-duplicate-and-out-of-range-refused: two conformant v1 attestations, and a single conformant attestation for a version outside the required range, are both refused with the attestation classification (exit 2)"

# --- attestation-historical-version-not-cross-checked -----------------------
C="$TMP/case-t1018-historical"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_spec "$C/spec.md" "Do the REVISED thing."
V2_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board-histstale.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-08-03): v1→v2 — human GO recorded in conversation — a criterion was unsatisfiable' \
  '  - freeze-attestation (v1, 2026-08-02): lines=9/9 sweep=mutual-satisfiability verdict=9P/0F owner=coordinating session' \
  '  - freeze-attestation (v2, 2026-08-03): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session'
run_checker "$C/spec.md" "$C/board-histstale.md"
[ "$RC" -eq 0 ] || fail "attestation-historical-version-not-cross-checked (v1 historical mismatch tolerated): expected exit 0 (aligned), got $RC: $ERR"

write_board "$C/board-currstale.md" 2 "$V2_HASH" \
  '  - intent-ratified (2026-08-03): v1→v2 — human GO recorded in conversation — a criterion was unsatisfiable' \
  '  - freeze-attestation (v1, 2026-08-02): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session' \
  '  - freeze-attestation (v2, 2026-08-03): lines=9/9 sweep=mutual-satisfiability verdict=9P/0F owner=coordinating session'
run_checker "$C/spec.md" "$C/board-currstale.md"
[ "$RC" -eq 2 ] || fail "attestation-historical-version-not-cross-checked (v2 miscount refused): expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-historical-version-not-cross-checked (v2 miscount refused): stderr must carry 'attestation' token, got: $ERR"
pass "attestation-historical-version-not-cross-checked: the spec-derived count cross-check applies only to the version-N record — a stale v1 count is tolerated, but the same mismatch on v2 (the declared version) is refused"

# --- attestation-precedes-drift-judgment ------------------------------------
C="$TMP/case-t1018-order"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_spec "$C/spec.md" "Do the REVISED thing."
V2_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board-both.md" 2 "$V2_HASH" \
  '  - freeze-attestation (v1, 2026-08-02): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session'
run_checker "$C/spec.md" "$C/board-both.md"
[ "$RC" -eq 2 ] || fail "attestation-precedes-drift-judgment (unattested v2, broken chain): expected exit 2, got $RC: $ERR"
grep -q 'attestation' <<< "$ERR" || fail "attestation-precedes-drift-judgment (unattested v2, broken chain): stderr must carry 'attestation' token, got: $ERR"

cp "$C/board-both.md" "$C/board-chain.md"
printf '  - freeze-attestation (v2, 2026-08-03): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=coordinating session\n' >> "$C/board-chain.md"
run_checker "$C/spec.md" "$C/board-chain.md"
[ "$RC" -eq 1 ] || fail "attestation-precedes-drift-judgment (attested but still broken chain): expected exit 1 (drift-detected), got $RC: $ERR"
grep -q 'drift-detected' <<< "$ERR" || fail "attestation-precedes-drift-judgment (attested but still broken chain): stderr must carry 'drift-detected' token, got: $ERR"
pass "attestation-precedes-drift-judgment: an unattested v2 board with a broken version chain refuses as attestation (exit 2), not drift-detected; attesting v2 makes the drift judgment reachable again (exit 1, still broken chain)"

# --- attestation-classification-channel-exclusive ---------------------------
C="$TMP/case-t1018-exclusive"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")"
grep -v 'intent-hash' "$C/board.md" > "$C/board-freeze.md"
run_checker "$C/spec.md" "$C/board-freeze.md"
[ "$RC" -eq 2 ] || fail "attestation-classification-channel-exclusive: expected exit 2, got $RC: $ERR"
T1018_ACOUNT=$(awk '/^check-intent: attestation: /{n++} END{print n+0}' <<< "$ERR")
[ "$T1018_ACOUNT" = "1" ] || fail "attestation-classification-channel-exclusive: expected exactly one 'check-intent: attestation: ' line, got $T1018_ACOUNT in: $ERR"
for p in structural usage drift-detected; do
  if grep -q "^check-intent: $p: " <<< "$ERR"; then
    fail "attestation-classification-channel-exclusive: unexpected '$p' classification line alongside attestation, got: $ERR"
  fi
done
pass "attestation-classification-channel-exclusive: the unattested refusal carries exactly one 'check-intent: attestation: ' line and zero lines of the other three prefixes"

# ============================================================================
# T-1018 rework round 1 (Codex REQUEST_CHANGES, Blocker): the freeze-attestation
# grammar leaves `lines=`/`verdict=` unrestricted `[0-9]+` (D4), so a
# conformant record may carry a leading-zero count. Both shapes below are
# INSIDE the frozen grammar (no re-freeze needed) — this locks the
# implementation defect the Blocker found, not a grammar change.
# ============================================================================

# --- attestation-leading-zero-inconsistent-refused --------------------------
# An internally INCONSISTENT leading-zero record (verdict=08P/00F against
# lines=1/1; 8+0 != 1) must be refused with the attestation classification.
# Before the rework1 fix, bash's $(()) arithmetic expansion parsed "08" as
# invalid octal, aborted only the ARITHMETIC EXPANSION (not the script —
# that failure sits inside an `if [ ... ]` condition, which `set -e` does
# not cover), and the cross-check was silently skipped: the board was
# wrongly accepted as aligned, exit 0.
C="$TMP/case-t1018-lz-inconsistent"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
GOOD_HASH="$(compute_hash "$C/spec.md")"
write_board "$C/board.md" 1 "$GOOD_HASH" \
  '  - freeze-attestation (v1, 2026-08-03): lines=1/1 sweep=mutual-satisfiability verdict=08P/00F owner=coordinating session'
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "attestation-leading-zero-inconsistent-refused: expected exit 2, got $RC: $ERR"
grep -q '^check-intent: attestation: ' <<< "$ERR" || fail "attestation-leading-zero-inconsistent-refused: stderr must carry the 'attestation' token (not a raw, un-namespaced arithmetic error, and not a silent aligned pass), got: $ERR"
pass "attestation-leading-zero-inconsistent-refused: a freeze-attestation with a leading-zero verdict that is internally inconsistent (verdict=08P/00F against lines=1/1) is refused with the attestation classification, exit 2 — the leading-zero shape does not bypass the P + F == ran cross-check"

# --- attestation-leading-zero-consistent-numeric-pass ------------------------
# An internally CONSISTENT leading-zero record (lines=01/01, verdict=01P/00F;
# 01 == 1 numerically) must be treated numerically and pass the attestation
# judgment, reaching whatever judgment follows (here: the bootstrap
# `structural`, since no hash record exists yet) — never refused merely for
# carrying a leading zero, and never miscounted as inconsistent.
C="$TMP/case-t1018-lz-consistent"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing." "" $'- [ ] AC1 x\n  - check: true'
printf -- '- [ ] **T-900** fixture task\n' > "$C/none.md"
printf '  - freeze-attestation (v1, 2026-08-03): lines=01/01 sweep=mutual-satisfiability verdict=01P/00F owner=coordinating session\n' >> "$C/none.md"
run_checker "$C/spec.md" "$C/none.md"
[ "$RC" -eq 2 ] || fail "attestation-leading-zero-consistent-numeric-pass: expected exit 2 (bootstrap structural, no hash record present), got $RC: $ERR"
grep -q '^check-intent: structural: ' <<< "$ERR" || fail "attestation-leading-zero-consistent-numeric-pass: expected the 'structural' token (bootstrap case — attestation judgment passed), got: $ERR"
if grep -q '^check-intent: attestation: ' <<< "$ERR"; then
  fail "attestation-leading-zero-consistent-numeric-pass: a leading-zero-but-numerically-consistent record (01==1) must not be refused as attestation, got: $ERR"
fi
pass "attestation-leading-zero-consistent-numeric-pass: a freeze-attestation whose leading-zero counts are internally consistent (lines=01/01 verdict=01P/00F, 01 treated as the numeral 1) passes the attestation judgment and reaches the bootstrap structural, not refused merely for the leading zero"

# ============================================================================
# T-1021 (Codex round1 Major): hash_version / av / ar / at / ap / af are fed
# into `10#` arithmetic with no width bound before this fix, so a
# grammar-conformant 20-digit digit string silently wrapped through bash's
# signed 64-bit range instead of being refused (measured:
# `bash -c 'echo $((10#18446744073709551626))'` -> 10). Each capture is now
# bounded to `{1,4}` (max 9999) directly in HASH_FULL_RE / ATTEST_FULL_RE,
# so an oversized value fails the grammar and is refused at check-intent's
# existing malformed-record path (hash_bad_count / attest_bad_count) — no
# new stderr write site, D6 fail-closed at the grammar side. Fixtures use a
# 20-digit value (width-fixture=20digit), matching AC12's own overflow
# probe shape rather than a merely-large-but-still-narrow number.
# ============================================================================

HUGE='99999999999999999999'

# --- T-1021-check-intent-hash-version-overflow ------------------------------
# A 20-digit hash_version must refuse structurally (HASH_FULL_RE's now-bounded
# version capture fails to match), never silently wrap and be treated as a
# huge-but-valid version.
C="$TMP/case-t1021-hashver-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" "$HUGE" "0000000000000000000000000000000000000000"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-hash-version-overflow: expected exit 2, got $RC: $ERR"
grep -q '^check-intent: structural: ' <<< "$ERR" \
  || fail "T-1021-check-intent-hash-version-overflow: expected the 'structural' token (malformed intent-hash, bounded grammar refuses the huge version), got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-hash-version-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-hash-version-overflow: a 20-digit intent-hash version (width-fixture=20digit) is refused structurally by the bounded HASH_FULL_RE, never wrapped through 64-bit arithmetic"

# --- T-1021-check-intent-attest-version-overflow ----------------------------
# A 20-digit freeze-attestation version (av) must refuse as attestation
# (ATTEST_FULL_RE's now-bounded version capture fails to match).
C="$TMP/case-t1021-attestver-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v${HUGE}, 2026-08-03): lines=1/1 sweep=mutual-satisfiability verdict=1P/0F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-version-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-version-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' (not merely any 'attestation:'-prefixed message, which a downstream ran==total mismatch after a silent wrap could also produce) — bounded grammar must refuse the huge version at the match itself, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-version-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-version-overflow: a 20-digit freeze-attestation version (width-fixture=20digit) is refused as attestation by the bounded ATTEST_FULL_RE, never wrapped through 64-bit arithmetic"

# --- T-1021-check-intent-attest-counts-overflow ------------------------------
# All four count captures (lines=<ran>/<total>, verdict=<P>P/<F>F) oversized
# at once must also refuse as attestation — proving every captured counter
# in this judgment is bounded, not only the first one a reviewer might spot.
C="$TMP/case-t1021-attestcounts-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v1, 2026-08-03): lines=${HUGE}/${HUGE} sweep=mutual-satisfiability verdict=${HUGE}P/${HUGE}F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-counts-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-counts-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' (not merely any 'attestation:'-prefixed message) — bounded grammar must refuse all four huge counts at the match itself, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-counts-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-counts-overflow: all four freeze-attestation count captures (lines=/verdict=, width-fixture=20digit) are refused as attestation by the bounded ATTEST_FULL_RE, never wrapped through 64-bit arithmetic"

# --- T-1021-check-intent-attest-count-{ran,total,p,f}-overflow --------------
# Producer mutation self-check found a blind spot in the combined test above:
# because ATTEST_FULL_RE requires ALL four count captures to match, oversizing
# all four at once cannot distinguish "every capture is bounded" from "at
# least one still is" — reverting only one capture's width quantifier still
# passed the combined fixture (the other three still failed to match). Each
# of the four count fields is oversized ALONE below (the other three stay
# small and internally consistent, `1`), independently proving each one's
# own bound is load-bearing — not merely masked by a sibling's. Four explicit
# blocks (not a `for` loop over a variable id) so AC13's `grep -qF -- "$id"`
# finds each `T-1021-…` id as LITERAL text in this file — a loop-interpolated
# id (`T-1021-…-${FIELD}-…`) is invisible to a fixed-string grep against the
# suite's own source text (a second gap this same round found, before it
# ever reached the audit document's `lock:` fields).
#
# 'malformed freeze-attestation record' is the grammar-rejection message
# (attest_bad_count path) — NOT merely any 'attestation:'-prefixed message.
# A weaker check here would pass for the wrong reason: with the other three
# fields small and consistent (1/1, verdict=1P/0F), an unbounded sibling
# capture could still match, silently 10#-wrap the huge digit string, and
# get caught downstream by the UNRELATED "ran == total" (or "P + F == ran")
# arithmetic cross-check instead of by this field's own width bound.

C="$TMP/case-t1021-attestcount-ran-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v1, 2026-08-03): lines=${HUGE}/1 sweep=mutual-satisfiability verdict=1P/0F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-count-ran-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-count-ran-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' — the ran capture alone must be bounded at the grammar, not merely caught downstream by an unrelated consistency check after a silent wrap, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-count-ran-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-count-ran-overflow: the ran count capture alone (width-fixture=20digit, siblings small) is refused at the grammar, independently of the other three counts"

C="$TMP/case-t1021-attestcount-total-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v1, 2026-08-03): lines=1/${HUGE} sweep=mutual-satisfiability verdict=1P/0F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-count-total-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-count-total-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' — the total capture alone must be bounded at the grammar, not merely caught downstream by an unrelated consistency check after a silent wrap, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-count-total-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-count-total-overflow: the total count capture alone (width-fixture=20digit, siblings small) is refused at the grammar, independently of the other three counts"

C="$TMP/case-t1021-attestcount-p-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v1, 2026-08-03): lines=1/1 sweep=mutual-satisfiability verdict=${HUGE}P/0F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-count-p-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-count-p-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' — the p capture alone must be bounded at the grammar, not merely caught downstream by an unrelated consistency check after a silent wrap, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-count-p-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-count-p-overflow: the p count capture alone (width-fixture=20digit, siblings small) is refused at the grammar, independently of the other three counts"

C="$TMP/case-t1021-attestcount-f-overflow"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
write_board "$C/board.md" 1 "$(compute_hash "$C/spec.md")" \
  "  - freeze-attestation (v1, 2026-08-03): lines=1/1 sweep=mutual-satisfiability verdict=1P/${HUGE}F owner=coordinating session"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-count-f-overflow: expected exit 2, got $RC: $ERR"
grep -qF 'malformed freeze-attestation record' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-count-f-overflow: expected the grammar-rejection message 'malformed freeze-attestation record' — the f capture alone must be bounded at the grammar, not merely caught downstream by an unrelated consistency check after a silent wrap, got: $ERR"
grep -qi 'value too great for base' <<< "$ERR" \
  && fail "T-1021-check-intent-attest-count-f-overflow: leaked bash's raw arithmetic error instead of the grammar-side refusal"
pass "T-1021-check-intent-attest-count-f-overflow: the f count capture alone (width-fixture=20digit, siblings small) is refused at the grammar, independently of the other three counts"

# --- T-1021-check-intent-attest-counts-bounded-pass --------------------------
# Positive control: a record whose count fields are written at the new
# bound's own maximum WIDTH (4 characters: `0001`/`0000`, value 1/0 — same
# leading-zero-is-decimal discipline T-1018 already locks at 2 digits, now
# exercised at the bound's own edge) must still pass the attestation
# judgment numerically — the bound must not reject a legitimate value
# merely for having more digits than the common case.
C="$TMP/case-t1021-attestcounts-bounded"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing." "" $'- [ ] AC1 x\n  - check: true'
printf -- '- [ ] **%s** fixture task\n' "$TASK_ID" > "$C/none.md"
printf '  - freeze-attestation (v1, 2026-08-03): lines=0001/0001 sweep=mutual-satisfiability verdict=0001P/0000F owner=coordinating session\n' >> "$C/none.md"
run_checker "$C/spec.md" "$C/none.md"
[ "$RC" -eq 2 ] || fail "T-1021-check-intent-attest-counts-bounded-pass: expected exit 2 (bootstrap structural, no hash record present), got $RC: $ERR"
grep -q '^check-intent: structural: ' <<< "$ERR" \
  || fail "T-1021-check-intent-attest-counts-bounded-pass: expected the 'structural' token (attestation judgment passed, bootstrap has no hash record), got: $ERR"
if grep -q '^check-intent: attestation: ' <<< "$ERR"; then
  fail "T-1021-check-intent-attest-counts-bounded-pass: a 4-character-wide (0001/0000) count at the bound's own maximum width must not be refused as attestation, got: $ERR"
fi
pass "T-1021-check-intent-attest-counts-bounded-pass: 4-character-wide freeze-attestation counts (width-fixture=4char, at the bound's own edge) are not rejected by the new width bound"

# ============================================================================
# T-1041: `--print-hash` and the two refusal-readability changes.
#
# 22 named assertion ids (AC8), across the fixture cases below: 16 for print
# mode (stdout contract; oracle parity against this suite's own compute_hash;
# end-to-end one-pipeline; marker absent/duplicated/reversed; malformed task
# id; directory argument; surplus argument; mode exclusivity; no positional;
# zero-argument parity; CRLF twin; three-invocation parity; empty-region
# parity; no temp-file leak) and 6 for the two refusal messages plus the two
# byte-invariance locks (pace-rule measured-count labelling + counterfactual;
# malformed-record counted total + counterfactual; the frozen-literal set;
# the row (10) byte invariant).
# ============================================================================

# run_print_hash <spec> [extra args...] -- captures PRC (exit code), POUT
# (stdout text, newline-stripped), PERR (stderr text) and the RAW byte counts
# POUT_BYTES/PERR_BYTES (via `wc -c` on the underlying temp files, since a
# command-substitution capture silently strips a trailing LF and would hide
# a missing/extra-trailing-newline regression in the byte contract itself).
PRC=0; POUT=""; PERR=""; POUT_BYTES=0; PERR_BYTES=0
run_print_hash() {
  local spec="$1"; shift
  local outfile="$TMP/.ph-out"; local errfile="$TMP/.ph-err"
  PRC=0
  bash "$CHECKER" --print-hash "$spec" "$@" > "$outfile" 2> "$errfile" || PRC=$?
  POUT="$(cat "$outfile")"
  PERR="$(cat "$errfile")"
  POUT_BYTES="$(wc -c < "$outfile" | tr -d ' ')"
  PERR_BYTES="$(wc -c < "$errfile" | tr -d ' ')"
  rm -f "$outfile" "$errfile"
}

# --- printhash-stdout-contract -----------------------------------------------
C="$TMP/case-printhash-stdout"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
run_print_hash "$C/spec.md"
[ "$PRC" -eq 0 ] || fail "printhash-stdout-contract: expected exit 0, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 41 ] || fail "printhash-stdout-contract: expected 41 stdout bytes, got $POUT_BYTES"
[ "$PERR_BYTES" -eq 0 ] || fail "printhash-stdout-contract: expected 0 stderr bytes, got $PERR_BYTES"
printf '%s' "$POUT" | grep -qE '^[0-9a-f]{40}$' || fail "printhash-stdout-contract: expected exactly 40 lowercase hex chars, got: $POUT"
pass "printhash-stdout-contract: --print-hash prints exactly 40 lowercase hex chars + one LF (41 bytes) on stdout, zero bytes on stderr, exit 0"

# --- printhash-oracle-parity --------------------------------------------------
C="$TMP/case-printhash-oracle"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
run_print_hash "$C/spec.md"
[ "$PRC" -eq 0 ] || fail "printhash-oracle-parity: --print-hash failed unexpectedly, rc=$PRC err=$PERR"
ORACLE_HASH="$(compute_hash "$C/spec.md")"
[ "$POUT" = "$ORACLE_HASH" ] || fail "printhash-oracle-parity: expected --print-hash's value ($POUT) to equal this suite's own oracle compute_hash ($ORACLE_HASH)"
pass "printhash-oracle-parity: --print-hash's value equals this suite's own compute_hash oracle for the same spec"

# --- printhash-one-pipeline-end-to-end ---------------------------------------
# The value --print-hash produces is recorded on a scratch board with a
# conformant v1 attestation, then verified `aligned` by the TWO-argument
# mode — proving one pipeline, not two, end to end.
C="$TMP/case-printhash-onepipe"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
run_print_hash "$C/spec.md"
[ "$PRC" -eq 0 ] || fail "printhash-one-pipeline-end-to-end: --print-hash itself failed unexpectedly, rc=$PRC err=$PERR"
write_board "$C/board.md" 1 "$POUT" \
  '  - freeze-attestation (v1, 2026-08-06): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=printhash-fixture'
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "printhash-one-pipeline-end-to-end: expected the two-argument mode to report aligned (exit 0) for the value --print-hash produced, got $RC: $ERR"
pass "printhash-one-pipeline-end-to-end: the value --print-hash prints, recorded on a scratch board with a conformant v1 attestation, is verified aligned by the two-argument mode — one pipeline, not two"

# --- printhash-marker-absent/duplicated/reversed-fails-closed, and the
# malformed-Task-ID-line case (id assigned to a variable and reused below,
# rather than respelled at each call site — its exact spelling embeds a
# `sk-` + 16-or-more-token-chars substring that this repo's check-pii-shapes.sh
# RE_TOKEN pattern false-positives on with no left boundary, a known checker
# gap tracked as issue #178 and declared out of scope by this task's own
# spec; the id text itself is frozen by AC8, so this only reduces the
# literal's occurrence count to one rather than five).
C="$TMP/case-printhash-structural"; mkdir -p "$C"
PH_TASKID_ID="printhash-task-id-malformed-fails-closed"
write_spec "$C/spec.md" "Do the thing."

grep -v 'BEGIN intent-block' "$C/spec.md" > "$C/spec-nobegin.md"
run_print_hash "$C/spec-nobegin.md"
[ "$PRC" -eq 2 ] || fail "printhash-marker-absent-fails-closed: expected exit 2, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 0 ] || fail "printhash-marker-absent-fails-closed: expected 0 stdout bytes, got $POUT_BYTES"
grep -q '^check-intent: structural: ' <<< "$PERR" || fail "printhash-marker-absent-fails-closed: stderr must carry 'structural' token, got: $PERR"
pass "printhash-marker-absent-fails-closed: a missing BEGIN marker fails closed in print mode (exit 2, structural, zero stdout bytes)"

cp "$C/spec.md" "$C/spec-dup.md"
printf -- '<!-- BEGIN intent-block: %s -->\n' "$TASK_ID" >> "$C/spec-dup.md"
run_print_hash "$C/spec-dup.md"
[ "$PRC" -eq 2 ] || fail "printhash-marker-duplicated-fails-closed: expected exit 2, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 0 ] || fail "printhash-marker-duplicated-fails-closed: expected 0 stdout bytes, got $POUT_BYTES"
grep -q '^check-intent: structural: ' <<< "$PERR" || fail "printhash-marker-duplicated-fails-closed: stderr must carry 'structural' token, got: $PERR"
pass "printhash-marker-duplicated-fails-closed: a duplicated BEGIN marker fails closed in print mode (exit 2, structural, zero stdout bytes)"

awk -v id="$TASK_ID" '
  $0 == "<!-- BEGIN intent-block: " id " -->" { print "<!-- END intent-block: " id " -->"; next }
  $0 == "<!-- END intent-block: "   id " -->" { print "<!-- BEGIN intent-block: " id " -->"; next }
  { print }
' "$C/spec.md" > "$C/spec-reversed.md"
run_print_hash "$C/spec-reversed.md"
[ "$PRC" -eq 2 ] || fail "printhash-marker-reversed-fails-closed: expected exit 2, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 0 ] || fail "printhash-marker-reversed-fails-closed: expected 0 stdout bytes, got $POUT_BYTES"
grep -q '^check-intent: structural: ' <<< "$PERR" || fail "printhash-marker-reversed-fails-closed: stderr must carry 'structural' token, got: $PERR"
pass "printhash-marker-reversed-fails-closed: reversed BEGIN/END markers fail closed in print mode (exit 2, structural, zero stdout bytes)"

sed "s/\\*\\*Task ID\\*\\*: ${TASK_ID}/**Task ID**: ${TASK_ID}junk-trailing-garbage/" "$C/spec.md" > "$C/spec-malformed-taskid.md"
run_print_hash "$C/spec-malformed-taskid.md"
[ "$PRC" -eq 2 ] || fail "$PH_TASKID_ID: expected exit 2, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 0 ] || fail "$PH_TASKID_ID: expected 0 stdout bytes, got $POUT_BYTES"
grep -q '^check-intent: structural: ' <<< "$PERR" || fail "$PH_TASKID_ID: stderr must carry 'structural' token, got: $PERR"
pass "$PH_TASKID_ID: a malformed '**Task ID**: ${TASK_ID}junk...' line fails closed in print mode (exit 2, structural, zero stdout bytes)"

# --- printhash-directory-arg-fails-closed; printhash-extra-arg-usage;
#     printhash-mode-exclusivity-usage; printhash-no-positional-usage
C="$TMP/case-printhash-usage"; mkdir -p "$C/adir"
write_spec "$C/spec.md" "Do the thing."

run_print_hash "$C/adir"
[ "$PRC" -eq 2 ] || fail "printhash-directory-arg-fails-closed: expected exit 2, got $PRC: $PERR"
[ "$POUT_BYTES" -eq 0 ] || fail "printhash-directory-arg-fails-closed: expected 0 stdout bytes, got $POUT_BYTES"
grep -q '^check-intent: usage: ' <<< "$PERR" || fail "printhash-directory-arg-fails-closed: stderr must carry 'usage' token, got: $PERR"
pass "printhash-directory-arg-fails-closed: a directory passed as the spec argument fails closed in print mode (exit 2, usage, zero stdout bytes)"

EXTRA_RC=0
bash "$CHECKER" --print-hash "$C/spec.md" extra.md > "$C/extra.out" 2> "$C/extra.err" || EXTRA_RC=$?
EXTRA_OUT_BYTES="$(wc -c < "$C/extra.out" | tr -d ' ')"
[ "$EXTRA_RC" -eq 2 ] || fail "printhash-extra-arg-usage: expected exit 2, got $EXTRA_RC"
[ "$EXTRA_OUT_BYTES" -eq 0 ] || fail "printhash-extra-arg-usage: expected 0 stdout bytes, got $EXTRA_OUT_BYTES"
grep -q '^check-intent: usage: ' "$C/extra.err" || fail "printhash-extra-arg-usage: stderr must carry 'usage' token, got: $(cat "$C/extra.err")"
pass "printhash-extra-arg-usage: a surplus positional argument after --print-hash <spec> fails closed (exit 2, usage, zero stdout bytes)"

EXCL_RC=0
bash "$CHECKER" --print-hash --print-hash "$C/spec.md" > "$C/excl.out" 2> "$C/excl.err" || EXCL_RC=$?
EXCL_OUT_BYTES="$(wc -c < "$C/excl.out" | tr -d ' ')"
[ "$EXCL_RC" -eq 2 ] || fail "printhash-mode-exclusivity-usage: expected exit 2, got $EXCL_RC"
[ "$EXCL_OUT_BYTES" -eq 0 ] || fail "printhash-mode-exclusivity-usage: expected 0 stdout bytes, got $EXCL_OUT_BYTES"
grep -q '^check-intent: usage: ' "$C/excl.err" || fail "printhash-mode-exclusivity-usage: stderr must carry 'usage' token, got: $(cat "$C/excl.err")"
pass "printhash-mode-exclusivity-usage: a repeated --print-hash flag is a usage(2) error (mode exclusivity, following bin/team-paths.sh's set_mode precedent), zero stdout bytes"

NOPOS_RC=0
bash "$CHECKER" --print-hash > "$C/nopos.out" 2> "$C/nopos.err" || NOPOS_RC=$?
NOPOS_OUT_BYTES="$(wc -c < "$C/nopos.out" | tr -d ' ')"
[ "$NOPOS_RC" -eq 2 ] || fail "printhash-no-positional-usage: expected exit 2, got $NOPOS_RC"
[ "$NOPOS_OUT_BYTES" -eq 0 ] || fail "printhash-no-positional-usage: expected 0 stdout bytes, got $NOPOS_OUT_BYTES"
grep -q '^check-intent: usage: ' "$C/nopos.err" || fail "printhash-no-positional-usage: stderr must carry 'usage' token, got: $(cat "$C/nopos.err")"
pass "printhash-no-positional-usage: --print-hash with no positional argument at all fails closed (exit 2, usage, zero stdout bytes)"

# --- printhash-zero-arg-contract-unchanged -----------------------------------
# The TWO-argument mode's own bare zero-argument invocation (no flags, no
# positional args at all — the exact shape tests/errexit-safe/run.sh:217
# pins under closed stderr) is unaffected by the new mode existing.
C="$TMP/case-printhash-zeroarg"; mkdir -p "$C"
ZERO_RC=0
bash "$CHECKER" > "$C/zero.out" 2> "$C/zero.err" || ZERO_RC=$?
ZERO_OUT_BYTES="$(wc -c < "$C/zero.out" | tr -d ' ')"
[ "$ZERO_RC" -eq 2 ] || fail "printhash-zero-arg-contract-unchanged: expected exit 2, got $ZERO_RC"
[ "$ZERO_OUT_BYTES" -eq 0 ] || fail "printhash-zero-arg-contract-unchanged: expected 0 stdout bytes, got $ZERO_OUT_BYTES"
grep -q '^check-intent: usage: ' "$C/zero.err" || fail "printhash-zero-arg-contract-unchanged: stderr must carry 'usage' token, got: $(cat "$C/zero.err")"
pass "printhash-zero-arg-contract-unchanged: a bare zero-argument invocation (no --print-hash, no positional args) is still a usage(2) error, unaffected by the new mode (tests/errexit-safe/run.sh:217 pins this same contract under closed stderr)"

# --- printhash-crlf-twin-same-hash -------------------------------------------
C="$TMP/case-printhash-crlf"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
sed 's/$/\r/' "$C/spec.md" > "$C/spec-crlf.md"
run_print_hash "$C/spec.md"
[ "$PRC" -eq 0 ] || fail "printhash-crlf-twin-same-hash: LF spec failed unexpectedly, rc=$PRC err=$PERR"
LF_VAL="$POUT"
run_print_hash "$C/spec-crlf.md"
[ "$PRC" -eq 0 ] || fail "printhash-crlf-twin-same-hash: CRLF spec failed unexpectedly, rc=$PRC err=$PERR"
CRLF_VAL="$POUT"
[ "$LF_VAL" = "$CRLF_VAL" ] || fail "printhash-crlf-twin-same-hash: expected LF ($LF_VAL) and CRLF ($CRLF_VAL) specs to print the same hash"
pass "printhash-crlf-twin-same-hash: --print-hash prints byte-identical values for an LF spec and its CRLF twin"

# --- printhash-invocation-style-parity ---------------------------------------
C="$TMP/case-printhash-invocation"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."

BASH_RC=0
( cd "$REPO_ROOT" && bash bin/check-intent.sh --print-hash "$C/spec.md" ) > "$C/out-bash.txt" 2>&1 || BASH_RC=$?
DOT_RC=0
( cd "$REPO_ROOT" && ./bin/check-intent.sh --print-hash "$C/spec.md" ) > "$C/out-dot.txt" 2>&1 || DOT_RC=$?

PATHBIN2="$TMP/pathbin-printhash"
mkdir -p "$PATHBIN2"
ln -sf "$CHECKER" "$PATHBIN2/check-intent.sh"
BARE_RC=0
# shellcheck disable=SC2030,SC2031
( export PATH="$PATHBIN2:$PATH"; cd "$REPO_ROOT" && check-intent.sh --print-hash "$C/spec.md" ) > "$C/out-bare.txt" 2>&1 || BARE_RC=$?

if [ "$BASH_RC" -ne 0 ] || [ "$DOT_RC" -ne 0 ] || [ "$BARE_RC" -ne 0 ]; then
  fail "printhash-invocation-style-parity: invocation styles disagree or failed — bash=$BASH_RC dot-slash=$DOT_RC PATH-bare=$BARE_RC"
fi
if ! cmp -s "$C/out-bash.txt" "$C/out-dot.txt"; then
  dump_cmp_diag "printhash-invocation-style-parity" "$C/out-bash.txt" "$C/out-dot.txt"
  fail "printhash-invocation-style-parity: output differs across invocation styles (bash vs ./)"
fi
if ! cmp -s "$C/out-dot.txt" "$C/out-bare.txt"; then
  dump_cmp_diag "printhash-invocation-style-parity" "$C/out-dot.txt" "$C/out-bare.txt"
  fail "printhash-invocation-style-parity: output differs across invocation styles (./ vs PATH-bare)"
fi
pass "printhash-invocation-style-parity: bash / ./ / PATH-bare-name invocations of --print-hash all produce identical behavior (exit 0) and byte-identical output"

# --- printhash-empty-region-parity -------------------------------------------
# A degenerate spec whose intent block normalizes to zero bytes (adjacent
# markers) hashes to git's empty-blob value — print mode reports it exactly
# as the two-argument mode computes it; refusing it in one mode only would
# break the single-pipeline property this task exists to establish.
C="$TMP/case-printhash-empty-region"; mkdir -p "$C"
{
  printf '# Fixture spec\n\n**Status**: READY_FOR_ARCH\n**Owner**: pm-spec\n**Task ID**: %s\n\n' "$TASK_ID"
  printf '<!-- BEGIN intent-block: %s -->\n<!-- END intent-block: %s -->\n' "$TASK_ID" "$TASK_ID"
} > "$C/spec-empty.md"
EMPTY_BLOB="$(git hash-object --stdin < /dev/null)"
run_print_hash "$C/spec-empty.md"
[ "$PRC" -eq 0 ] || fail "printhash-empty-region-parity: expected exit 0 for a degenerate zero-byte intent block, got $PRC: $PERR"
[ "$POUT" = "$EMPTY_BLOB" ] || fail "printhash-empty-region-parity: expected the printed value to equal git's empty-blob hash ($EMPTY_BLOB), got $POUT"
write_board "$C/board.md" 1 "$POUT" \
  '  - freeze-attestation (v1, 2026-08-06): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=printhash-fixture'
run_checker "$C/spec-empty.md" "$C/board.md"
[ "$RC" -eq 0 ] || fail "printhash-empty-region-parity: expected the two-argument mode to also report aligned for the same degenerate spec/hash, got $RC: $ERR"
pass "printhash-empty-region-parity: a degenerate spec whose intent block normalizes to zero bytes (adjacent markers) hashes to git's empty-blob value in BOTH modes — parity, not a one-mode-only refusal"

# --- printhash-no-temp-file-leak ----------------------------------------------
# The EXIT trap (cleanup_tmp_region) installed before print mode's early
# return must still fire on that early `exit 0` — proved by pointing TMPDIR
# at an isolated, otherwise-empty scratch directory and confirming it is
# still empty afterward.
C="$TMP/case-printhash-notempleak"; mkdir -p "$C/isolated-tmpdir"
write_spec "$C/spec.md" "Do the thing."
NOTMP_RC=0
TMPDIR="$C/isolated-tmpdir" bash "$CHECKER" --print-hash "$C/spec.md" > "$C/leak.out" 2> "$C/leak.err" || NOTMP_RC=$?
[ "$NOTMP_RC" -eq 0 ] || fail "printhash-no-temp-file-leak: --print-hash itself failed unexpectedly, rc=$NOTMP_RC: $(cat "$C/leak.err")"
LEAK_COUNT=$(find "$C/isolated-tmpdir" -mindepth 1 | wc -l | tr -d ' ')
[ "$LEAK_COUNT" -eq 0 ] || fail "printhash-no-temp-file-leak: expected the isolated TMPDIR to be empty after a successful --print-hash run (the EXIT trap must remove the extraction temp file), found $LEAK_COUNT leftover entry/ies"
pass "printhash-no-temp-file-leak: a successful --print-hash run leaves no temp file behind in TMPDIR — the EXIT trap (cleanup_tmp_region) still fires on the mode's early exit 0"

# --- refusal-pace-rule-names-measured-counts; refusal-pace-rule-counterfactual
C="$TMP/case-refusal-pacerule"; mkdir -p "$C"
T1041_AC_BODY_2CHECK=$'- [ ] AC1 a\n  - check: true\n- [ ] AC2 b\n  - check: true'
write_spec "$C/spec.md" "Do the thing." "" "$T1041_AC_BODY_2CHECK"
printf -- '- [ ] **%s** fixture task\n' "$TASK_ID" > "$C/board.md"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "refusal-pace-rule-names-measured-counts: expected exit 2, got $RC: $ERR"
grep -q '^check-intent: attestation: ' <<< "$ERR" || fail "refusal-pace-rule-names-measured-counts: stderr must carry the 'attestation' token, got: $ERR"
for lit in 'lines=2/2' 'sweep=mutual-satisfiability' 'YYYY-MM-DD' '<P>P/<F>F' '<who ran them>' 'the lines= counts above are measured, not an example'; do
  grep -qF -- "$lit" <<< "$ERR" || fail "refusal-pace-rule-names-measured-counts: expected literal '$lit' in stderr, got: $ERR"
done
pass "refusal-pace-rule-names-measured-counts: the pace-rule refusal names which of its printed numbers were measured (lines=2/2, sweep=mutual-satisfiability, the three unreplaced placeholders, and the new anchor sentence), for a scratch spec carrying two check: lines and an unattested board"

grep -qF -- 'the lines= counts above are measured, not an example' "$CHECKER" \
  || fail "refusal-pace-rule-counterfactual: expected the anchor sentence to be present in the live checker before mutating a scratch copy"
sed 's/the lines= counts above are measured, not an example/REDACTED-FOR-COUNTERFACTUAL/' "$CHECKER" > "$C/old-checker-pacerule.sh"
if grep -qF -- 'the lines= counts above are measured, not an example' "$C/old-checker-pacerule.sh"; then
  fail "refusal-pace-rule-counterfactual: the sed mutation did not actually remove the anchor sentence from the scratch copy"
fi
OLD_RC=0
OLD_ERR="$(bash "$C/old-checker-pacerule.sh" "$C/spec.md" "$C/board.md" 2>&1 >/dev/null)" || OLD_RC=$?
[ "$OLD_RC" -eq 2 ] || fail "refusal-pace-rule-counterfactual: expected the mutated checker to still refuse (exit 2), got $OLD_RC: $OLD_ERR"
if grep -qF -- 'the lines= counts above are measured, not an example' <<< "$OLD_ERR"; then
  fail "refusal-pace-rule-counterfactual: expected the mutated refusal to have LOST the anchor sentence, got: $OLD_ERR"
fi
grep -qF -- 'sweep=mutual-satisfiability' <<< "$OLD_ERR" || fail "refusal-pace-rule-counterfactual: expected 'sweep=mutual-satisfiability' to still appear in the mutated refusal, got: $OLD_ERR"
pass "refusal-pace-rule-counterfactual: removing the anchor sentence from a scratch copy of the checker produces a refusal that no longer carries it, while sweep=mutual-satisfiability still appears — the assertion tracks the real change, not an unrelated string"

# --- refusal-malformed-names-counted-total; refusal-malformed-counterfactual
C="$TMP/case-refusal-malformed"; mkdir -p "$C"
T1041_AC_BODY_2CHECK_B=$'- [ ] AC1 a\n  - check: true\n- [ ] AC2 b\n  - check: true'
write_spec "$C/spec.md" "Do the thing." "" "$T1041_AC_BODY_2CHECK_B"
printf -- '- [ ] **%s** fixture task\n' "$TASK_ID" > "$C/board.md"
printf '  - freeze-attestation (v1, 2026-08-06): lines=2/2 verdict=2P/0F owner=scratch\n' >> "$C/board.md"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "refusal-malformed-names-counted-total: expected exit 2, got $RC: $ERR"
grep -q '^check-intent: attestation: ' <<< "$ERR" || fail "refusal-malformed-names-counted-total: stderr must carry the 'attestation' token, got: $ERR"
for lit in 'malformed freeze-attestation record' 'lines=<ran>/<total>' 'the intent block being checked carries' 'lines=2/2'; do
  grep -qF -- "$lit" <<< "$ERR" || fail "refusal-malformed-names-counted-total: expected literal '$lit' in stderr, got: $ERR"
done
pass "refusal-malformed-names-counted-total: the malformed-freeze-attestation refusal additionally names the count it measured (lines=2/2), anchored on 'the intent block being checked carries', while keeping the grammar string and the existing 'malformed freeze-attestation record' phrase"

grep -qF -- 'the intent block being checked carries' "$CHECKER" \
  || fail "refusal-malformed-counterfactual: expected the anchor phrase to be present in the live checker before mutating a scratch copy"
sed 's/the intent block being checked carries/REDACTED-FOR-COUNTERFACTUAL/' "$CHECKER" > "$C/old-checker-malformed.sh"
OLD_RC=0
OLD_ERR="$(bash "$C/old-checker-malformed.sh" "$C/spec.md" "$C/board.md" 2>&1 >/dev/null)" || OLD_RC=$?
[ "$OLD_RC" -eq 2 ] || fail "refusal-malformed-counterfactual: expected the mutated checker to still refuse (exit 2), got $OLD_RC: $OLD_ERR"
if grep -qF -- 'the intent block being checked carries' <<< "$OLD_ERR"; then
  fail "refusal-malformed-counterfactual: expected the mutated refusal to have LOST the anchor phrase, got: $OLD_ERR"
fi
grep -qF -- 'malformed freeze-attestation record' <<< "$OLD_ERR" || fail "refusal-malformed-counterfactual: expected 'malformed freeze-attestation record' to still appear in the mutated refusal, got: $OLD_ERR"
pass "refusal-malformed-counterfactual: removing the anchor phrase from a scratch copy of the checker produces a malformed-record refusal that no longer carries it, while 'malformed freeze-attestation record' still appears"

# --- refusal-frozen-literals-intact -------------------------------------------
# Every frozen element AC9 requires must survive TOGETHER in one refusal —
# the die() attestation prefix (trailing space included), sweep=, the
# measured lines=<N>/<N> substitution, and the three unreplaced placeholders.
C="$TMP/case-refusal-frozenliterals"; mkdir -p "$C"
T1041_AC_BODY_1CHECK=$'- [ ] AC1 a\n  - check: true'
write_spec "$C/spec.md" "Do the thing." "" "$T1041_AC_BODY_1CHECK"
printf -- '- [ ] **%s** fixture task\n' "$TASK_ID" > "$C/board.md"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "refusal-frozen-literals-intact: expected exit 2, got $RC: $ERR"
FROZEN_OK=1
for lit in 'check-intent: attestation: ' 'sweep=mutual-satisfiability' 'lines=1/1' 'YYYY-MM-DD' '<P>P/<F>F' '<who ran them>'; do
  grep -qF -- "$lit" <<< "$ERR" || FROZEN_OK=0
done
[ "$FROZEN_OK" -eq 1 ] || fail "refusal-frozen-literals-intact: one or more of AC9's frozen elements are missing from the refusal, got: $ERR"
pass "refusal-frozen-literals-intact: every frozen element AC9 requires (the die() attestation prefix with its trailing space, sweep=mutual-satisfiability, the measured lines=<N>/<N> substitution, and the three unreplaced placeholders) survives together in one refusal"

# --- refusal-row10-message-byte-invariant -------------------------------------
# The attested-bootstrap case (row 10 — a conformant v1 attestation on a
# board with no hash record yet) must still reach the SAME shared
# row(4)/row(10) message and the 'structural' classification, unchanged from
# before T-1018/T-1041 (D3) — and fail_hash_structural keeps exactly two
# call sites.
C="$TMP/case-refusal-row10"; mkdir -p "$C"
write_spec "$C/spec.md" "Do the thing."
printf -- '- [ ] **%s** fixture task\n' "$TASK_ID" > "$C/board.md"
printf '  - freeze-attestation (v1, 2026-08-06): lines=0/0 sweep=mutual-satisfiability verdict=0P/0F owner=printhash-fixture\n' >> "$C/board.md"
run_checker "$C/spec.md" "$C/board.md"
[ "$RC" -eq 2 ] || fail "refusal-row10-message-byte-invariant: expected exit 2 (row 10 — attested bootstrap, still no hash record), got $RC: $ERR"
grep -qF -- 'expected exactly one well-formed intent-hash record for' <<< "$ERR" || fail "refusal-row10-message-byte-invariant: expected the shared row(4)/row(10) message, got: $ERR"
grep -q '^check-intent: structural: ' <<< "$ERR" || fail "refusal-row10-message-byte-invariant: row 10 must stay 'structural' (D3), not 'attestation', once the gate is satisfied, got: $ERR"
MSG_OCCURRENCES=$(grep -cF -- 'expected exactly one well-formed intent-hash record for' <<< "$ERR")
[ "$MSG_OCCURRENCES" -eq 1 ] || fail "refusal-row10-message-byte-invariant: expected the shared message to occur exactly once, got $MSG_OCCURRENCES"
SITE_COUNT=$(grep -cE '^[[:space:]]+fail_hash_structural$' "$CHECKER")
[ "$SITE_COUNT" -eq 2 ] || fail "refusal-row10-message-byte-invariant: expected fail_hash_structural to have exactly two call sites (row 4 and row 10), got $SITE_COUNT"
pass "refusal-row10-message-byte-invariant: the attested-bootstrap case (row 10) still reaches the shared row(4)/row(10) 'structural' message (D3 — unchanged from before T-1018/T-1041), and fail_hash_structural keeps exactly two call sites"

# --- self-check: this suite's own script is shellcheck clean (soft-skip) ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$CHECKER" "$HERE/run.sh" || fail "shellcheck: check-intent.sh / run.sh must be clean"
  pass "shellcheck clean (checker + test runner)"
else
  printf 'SKIP: shellcheck not installed locally (CI enforces it)\n'
fi

printf '\nAll check-intent assertions passed.\n'
