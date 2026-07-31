#!/usr/bin/env bash
# run.sh — drive bin/check-retro.sh against fixtures and assert the documented
# behavior:
#   - a canonical retro passes (exit 0), in English, in the operator's own
#     language (Japanese headings), and with bare (un-parenthesized) headings
#     — the marker is the contract, the heading text is free (T-1010)
#   - missing H1 / missing section marker / duplicated or out-of-order
#     markers / a marker not anchoring a real heading / near-miss marker
#     spellings / a pre-migration retro with no markers at all / an
#     unlabelled lessons bullet each fail (exit 1) with a matching reason
#   - the repo's own retros and its shipped template pass the ledger contract
#   - multiple files in one call; an unreadable file is a usage error (exit 2)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RETRO="$REPO_ROOT/bin/check-retro.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_rc <desc> <expected_rc> <stderr_grep|""> <file...>
assert_rc() {
  local desc="$1" exp="$2" pat="$3"; shift 3
  local err rc
  set +e
  err="$(bash "$RETRO" "$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc (stderr: $err)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  pass "$desc (exit $rc)"
}

# --- T-1010: structure/surface separation ---------------------------------
assert_rc "pass-canonical (English, markers) -> 0" 0 "" "$FIX/pass-canonical.md"
assert_rc "pass-operator-language (Japanese headings, markers) -> 0" 0 "" "$FIX/pass-operator-language.md"
assert_rc "pass-bare-heading (no parenthetical, markers) -> 0" 0 "" "$FIX/pass-bare-heading.md"
assert_rc "pass-lessons-none (- (none) placeholder) -> 0" 0 "" "$FIX/pass-lessons-none.md"

# pass-canonical.md and pass-operator-language.md prove surface freedom in
# both directions: the canonical (English) fixture must carry no CJK, and the
# Japanese-headed fixture must actually carry CJK — "passes" is not "was
# never examined".
test "$(LC_ALL=C tr -cd '\343-\357' < "$FIX/pass-canonical.md" | wc -c | tr -d ' ')" = 0 \
  || fail "pass-canonical.md must be free of CJK bytes (positive control for surface freedom)"
pass "pass-canonical.md carries zero CJK bytes"
test "$(LC_ALL=C tr -cd '\343-\357' < "$FIX/pass-operator-language.md" | wc -c | tr -d ' ')" -gt 0 \
  || fail "pass-operator-language.md must actually carry CJK bytes (positive control)"
pass "pass-operator-language.md carries CJK bytes and still passes"
grep -qxF -- '## Keep' "$FIX/pass-bare-heading.md" \
  || fail "pass-bare-heading.md must carry the literal bare '## Keep' heading"
pass "pass-bare-heading.md carries a bare heading and still passes"

assert_rc "fail-no-h1 -> 1" 1 "not '# Retro" "$FIX/fail-no-h1.md"
assert_rc "fail-missing-section (no 'try' marker) -> 1" 1 "missing section marker <!-- retro-section: try -->" "$FIX/fail-missing-section.md"
# T-029/T-1010: the traps (loop-trap self-check) section is mandatory — a
# retro with all four other markers but no traps marker must fail.
assert_rc "fail-missing-traps -> 1" 1 "missing section marker <!-- retro-section: traps -->" "$FIX/fail-missing-traps.md"
assert_rc "fail-bare-lesson -> 1" 1 "unlabelled lesson bullet" "$FIX/fail-bare-lesson.md"
# A marker string appearing only in prose / a blockquote (not as a real
# marker line) must NOT satisfy rule 2 — the check is line-anchored.
assert_rc "fail-heading-in-prose (marker quoted in prose) -> 1" 1 "missing section marker <!-- retro-section: try -->" "$FIX/fail-heading-in-prose.md"
# AC8: no dual acceptance of the legacy (pre-migration, marker-less) shape.
grep -q 'retro-section' "$FIX/fail-legacy-no-markers.md" \
  && fail "fail-legacy-no-markers.md must itself carry no marker (positive control)"
assert_rc "fail-legacy-no-markers (pre-migration, no markers) -> 1" 1 "retro-section:" "$FIX/fail-legacy-no-markers.md"
# AC14: the empty-section placeholder is the English machine token
# `- (none)`; a translated placeholder is no longer recognized and is just
# an unlabelled bullet.
assert_rc "fail-legacy-placeholder (- (該当なし) is no longer a placeholder) -> 1" 1 "unlabelled lesson bullet" "$FIX/fail-legacy-placeholder.md"

assert_rc "unreadable file -> 2" 2 "cannot read" "$FIX/does-not-exist.md"
assert_rc "no args -> 2" 2 "usage"

# Multiple files: a clean one + a failing one => exit 1 (the failure wins).
assert_rc "multi: clean + failing -> 1" 1 "fail-no-h1" "$FIX/pass-canonical.md" "$FIX/fail-no-h1.md"

# T-087 AC4/AC7: fail-closed under temp-path unavailability. Rule 2/3's check
# reads the file directly into an awk array (no here-string / temp-file
# dependency), so pointing $TMPDIR at a non-existent, non-writable directory
# must NOT make the malformed-bullet fixture fall through to a false exit 0.
rc=0
err="$(TMPDIR=/nonexistent-tmp-t087 bash "$RETRO" "$FIX/fail-bare-lesson.md" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -ne 0 ] || fail "fail-closed under broken TMPDIR: expected non-zero exit, got 0 (fail-open regression)"
grep -qE "unlabelled lesson bullet" <<< "$err" \
  || fail "fail-closed under broken TMPDIR: malformed bullet must still be reported (got: $err)"
pass "fail-closed: broken TMPDIR still catches fail-bare-lesson.md (exit $rc)"

# --- T-1010 AC9: each of the five markers is individually load-bearing ----
MUT_TMP="$HERE/tmp-marker-mutation"
rm -rf "$MUT_TMP"
trap 'rm -rf "$MUT_TMP"' EXIT
mkdir -p "$MUT_TMP"
for id in keep problem try traps lessons; do
  d="$MUT_TMP/remove-$id"
  mkdir -p "$d"
  cp "$FIX/pass-canonical.md" "$d/f.md"
  sed -i.bak "/retro-section: $id /d" "$d/f.md"
  rm -f "$d/f.md.bak"
  grep -q "retro-section: $id " "$d/f.md" \
    && fail "AC9 ($id): mutation did not apply — marker still present"
  if out=$(bash "$RETRO" "$d/f.md" 2>&1 >/dev/null); then rc=0; else rc=$?; fi
  [ "$rc" -eq 1 ] || fail "AC9 ($id): expected exit 1 after removing the marker, got $rc"
  case "$out" in
    *"retro-section: $id"*) ;;
    *) fail "AC9 ($id): reason must name the missing marker (got: $out)" ;;
  esac
done
pass "AC9: each of the five section markers is individually load-bearing"

# --- T-1010 AC10: duplicated / out-of-order markers ------------------------
d="$MUT_TMP/dup"
mkdir -p "$d"
awk '{ print } /retro-section: try -->/ { print }' "$FIX/pass-canonical.md" > "$d/dup.md"
if bash "$RETRO" "$d/dup.md" >/dev/null 2>&1; then dup_rc=0; else dup_rc=$?; fi
d="$MUT_TMP/ord"
mkdir -p "$d"
sed -e 's|<!-- retro-section: keep -->|<!-- retro-section: ZZZ -->|' \
    -e 's|<!-- retro-section: problem -->|<!-- retro-section: keep -->|' \
    -e 's|<!-- retro-section: ZZZ -->|<!-- retro-section: problem -->|' \
    "$FIX/pass-canonical.md" > "$d/ord.md"
if out=$(bash "$RETRO" "$d/ord.md" 2>&1 >/dev/null); then ord_rc=0; else ord_rc=$?; fi
[ "$dup_rc" -eq 1 ] || fail "AC10: a duplicated marker must exit 1, got $dup_rc"
[ "$ord_rc" -eq 1 ] || fail "AC10: an out-of-order marker sequence must exit 1, got $ord_rc"
grep -qF -- 'out of order' <<< "$out" || fail "AC10: the ordering reason must say 'out of order' (got: $out)"
pass "AC10: a duplicated marker id and an out-of-order marker sequence are each violations"

# --- T-1010 AC11: near-miss marker spellings do not satisfy a section ------
d="$MUT_TMP/near-miss"
mkdir -p "$d"
sed 's|^<!-- retro-section: try -->|> <!-- retro-section: try -->|' "$FIX/pass-canonical.md" > "$d/q.md"
sed 's|^<!-- retro-section: try -->|  <!-- retro-section: try -->|' "$FIX/pass-canonical.md" > "$d/i.md"
sed 's|<!-- retro-section: try -->|<!--retro-section:try-->|' "$FIX/pass-canonical.md" > "$d/n.md"
near_rc=0
for f in q i n; do
  bash "$RETRO" "$d/$f.md" >/dev/null 2>&1 || near_rc=$((near_rc + 1))
done
[ "$near_rc" -eq 3 ] || fail "AC11: all three near-miss marker spellings (blockquoted / indented / space-less) must fail, got $near_rc/3"
pass "AC11: blockquoted, indented, and space-less near-miss markers each leave 'try' missing"

# --- T-1010 AC12: a marker not anchoring an H2 heading is a violation ------
d="$MUT_TMP/floating"
mkdir -p "$d"
awk '{ print } /retro-section: try -->/ { print "not a heading" }' "$FIX/pass-canonical.md" > "$d/f.md"
if out=$(bash "$RETRO" "$d/f.md" 2>&1 >/dev/null); then rc=0; else rc=$?; fi
[ "$rc" -eq 1 ] || fail "AC12: a marker floating in prose (no heading right after it) must exit 1, got $rc"
grep -qF -- 'retro-section: try' <<< "$out" || fail "AC12: reason must name the marker (got: $out)"
pass "AC12: a marker whose next non-blank line is not an H2 heading is a violation"

# --- T-1010 AC13: CRLF tolerance proved on a malformed input, never a -------
# well-formed one (the T-1001 v2 discipline).
d="$MUT_TMP/crlf-traps"
mkdir -p "$d"
sed '/retro-section: traps /d' "$FIX/pass-canonical.md" | sed 's/$/\r/' > "$d/f.md"
grep -q 'retro-section: traps ' "$d/f.md" && fail "AC13: mutation did not apply"
if bash "$RETRO" "$d/f.md" >/dev/null 2>&1; then rc=0; else rc=$?; fi
[ "$rc" -eq 1 ] || fail "AC13: a CRLF file missing the traps marker must still exit 1, got $rc"
pass "AC13: CRLF tolerance is proved against a broken (marker-missing) input"

rm -rf "$MUT_TMP"

# T-1001/T-1003: the "## Retro inputs" ledger — a closed enum, fail-closed on
# every recognised violation shape (AC18). Each ledger fixture below is
# asserted against its DECLARED number of violation lines, via assert_violations
# used at every one of the eleven fixture call sites — a fixture edited
# incompletely (e.g. an added `missing Retro inputs id: interventions` line
# left uncounted) now fails the count instead of passing on the first matching
# stderr pattern alone. "case:" labels below are asserted verbatim by the spec.
# All eleven fixtures also carry the five T-1010 section markers (H7), so
# each isolates the rule-4 ledger violation it names rather than failing for
# the wrong reason.
#
# case: each ledger fixture emits its declared number of violations (fail-inputs-duplicate-section legitimately emits two)
#
# assert_violations <desc> <expected_rc> <expected_violation_count> <stderr_grep|""> <file...>
assert_violations() {
  local desc="$1" exp_rc="$2" exp_count="$3" pat="$4"; shift 4
  local err rc n
  set +e
  err="$(bash "$RETRO" "$@" 2>&1 >/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$exp_rc" ] || fail "$desc: expected exit $exp_rc, got $rc (stderr: $err)"
  [ -z "$pat" ] || grep -qE "$pat" <<< "$err" || fail "$desc: stderr missing /$pat/ (got: $err)"
  n=0
  [ -z "$err" ] || n="$(printf '%s\n' "$err" | grep -c '.')"
  [ "$n" -eq "$exp_count" ] || fail "$desc: expected $exp_count violation line(s), got $n (stderr: $err)"
  pass "$desc (exit $rc, $exp_count violation(s))"
}

assert_violations "case: a well-formed Retro inputs ledger passes" \
  0 0 "" "$FIX/pass-canonical.md"
assert_violations "fail-inputs-missing-section -> 1"     1 1 "missing section heading: ## Retro inputs"          "$FIX/fail-inputs-missing-section.md"
assert_violations "fail-inputs-unknown-status -> 1"      1 1 "unknown Retro inputs status"                        "$FIX/fail-inputs-unknown-status.md"
assert_violations "fail-inputs-unknown-id -> 1"          1 1 "unknown Retro inputs id"                             "$FIX/fail-inputs-unknown-id.md"
assert_violations "fail-inputs-missing-id -> 1"          1 1 "missing Retro inputs id: lessons"                    "$FIX/fail-inputs-missing-id.md"
assert_violations "fail-inputs-duplicate-id -> 1"        1 1 "duplicated Retro inputs id"                          "$FIX/fail-inputs-duplicate-id.md"
assert_violations "fail-inputs-empty-detail -> 1"        1 1 "empty Retro inputs detail"                           "$FIX/fail-inputs-empty-detail.md"
assert_violations "case: a whitespace-only detail is reported" \
  1 1 "whitespace-only Retro inputs detail" "$FIX/fail-inputs-blank-detail.md"
assert_violations "fail-inputs-stray-line -> 1"          1 1 "unrecognised line inside ## Retro inputs"            "$FIX/fail-inputs-stray-line.md"
assert_violations "fail-inputs-duplicate-section -> 2"   1 2 "duplicated ## Retro inputs section heading"          "$FIX/fail-inputs-duplicate-section.md"
assert_violations "fail-inputs-line-outside-section -> 1" 1 1 "ledger-shaped line outside the ## Retro inputs section" "$FIX/fail-inputs-line-outside-section.md"

# case: removing the interventions line from a COPY of pass-canonical.md adds exactly one violation
COPY_TMP="$HERE/tmp-mutation-copy"
rm -rf "$COPY_TMP"
trap 'rm -rf "$COPY_TMP"' EXIT
mkdir -p "$COPY_TMP"
no_interventions="$COPY_TMP/pass-canonical-no-interventions.md"
cp "$FIX/pass-canonical.md" "$no_interventions"
sed -i.bak '/^- input: interventions /d' "$no_interventions"
rm -f "$no_interventions.bak"
grep -qF -- '- input: interventions ' "$no_interventions" \
  && fail "case: removing the interventions line from a COPY of pass-canonical.md adds exactly one violation (mutation did not apply)"
assert_violations "case: removing the interventions line from a COPY of pass-canonical.md adds exactly one violation" \
  1 1 "missing Retro inputs id: interventions" "$no_interventions"
rm -rf "$COPY_TMP"

# T-1001 v2 (AC17): "a tolerance claim is proved by a malformed input, never a
# well-formed one." v1's CRLF criterion asked for a VALID CRLF file to pass,
# which a CR-unaware region walk satisfied by never examining the file at all
# — "accepted" and "unexamined" produced the same result. So this case starts
# from a BROKEN ledger (one id present with no status at all, the other eight ids missing entirely)
# and asserts it is STILL REPORTED after conversion to CRLF — a checker that
# silently skipped the file would pass this file clean, which is exactly the
# defect v1 shipped. T-1010: the five section markers are included and
# well-formed (with labelled lesson bullets) so this case isolates rule 4's
# CR handling exactly, rather than also failing for a marker reason.
TMP="$HERE/tmp"
rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

malformed="$TMP/malformed.md"
# shellcheck disable=SC2016  # backticks below are literal markdown code-span syntax, not a subshell.
{
  printf '# Retro 2026-01-01\n\n'
  printf '## Retro inputs\n\n'
  printf -- '- input: cycle-window\n'
  printf '\n## サマリ\n\n`<summary>`\n\n'
  printf '<!-- retro-section: keep -->\n## Keep（続けたい良い動き）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: problem -->\n## Problem（直面した課題 / 痛み）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: try -->\n## Try（次サイクルで試すこと）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: traps -->\n## 罠の点検（Comprehension Debt / Cognitive Surrender）\n\n- `<x>`\n\n'
  printf '<!-- retro-section: lessons -->\n## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）\n\n- `[common]` ok\n'
} > "$malformed"
bash "$RETRO" "$malformed" >/dev/null 2>&1 \
  && fail "sanity: the malformed (LF) ledger fixture must itself fail before CRLF conversion is meaningful"

crlf_malformed="$TMP/crlf-malformed.md"
sed 's/$/\r/' "$malformed" > "$crlf_malformed"
bash "$RETRO" "$crlf_malformed" >/dev/null 2>&1 \
  && fail "case: a MALFORMED ledger in a CRLF file is still reported (not silently accepted)"
pass "case: a MALFORMED ledger in a CRLF file is still reported (not silently accepted)"

# T-1001 v2 (AC17): the agreement backstop of AC16 is proved to bite by a
# mutation self-check — a COPY of the checker in a temporary directory, with
# ONLY the region walk's (rule 4's) CR handling removed, must still report
# the malformed CRLF ledger above. The real script (bin/check-retro.sh) is
# never modified. `has_exact_line` (used by rule 4's own heading detection)
# and rule 2/3's own CR strip (a differently-named awk variable) are left
# untouched by this edit — only the `sub(/\r$/, "", line)` that appears AFTER
# the "# Rule 4:" marker comment is neutralized, isolating the mutation to
# the region walk exactly as the spec names it. Because this fixture's five
# markers are well-formed, the mutated script's exit is driven ENTIRELY by
# rule 4's backstop, not by an incidental rule-2 marker violation.
mutated="$TMP/check-retro-mutated.sh"
cp "$REPO_ROOT/bin/check-retro.sh" "$mutated"
sed -i.bak '/# Rule 4:/,$ s/sub(\/\\r\$\/, "", line)/# CR handling removed for mutation test/' "$mutated"
rm -f "$mutated.bak"
chmod +x "$mutated"
# Sanity: the mutation must have actually landed (positive control — a no-op
# sed that silently matched nothing would make this whole case vacuous).
grep -qF -- 'CR handling removed for mutation test' "$mutated" \
  || fail "case: with the region walk CR handling removed, a malformed CRLF ledger is STILL reported (agreement backstop) — mutation did not apply"
bash "$mutated" "$crlf_malformed" >/dev/null 2>&1 \
  && fail "case: with the region walk CR handling removed, a malformed CRLF ledger is STILL reported (agreement backstop)"
pass "case: with the region walk CR handling removed, a malformed CRLF ledger is STILL reported (agreement backstop)"

# T-1001 v2 (AC19)/T-1010: rule 3's region walk starts at the heading right
# after the `lessons` marker and is CR-tolerant by construction (the whole
# file is read with `\r` stripped up front), so it was never the source of
# the CRLF blocker — confirmed by fixture rather than assumed. A CRLF file
# with an otherwise-clean, marker-complete retro but an unlabelled lessons
# bullet must still be caught.
rule3_crlf="$TMP/rule3-crlf.md"
sed 's/$/\r/' "$FIX/fail-bare-lesson.md" > "$rule3_crlf"
rc=0
err="$(bash "$RETRO" "$rule3_crlf" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 1 ] || fail "case: rule 3 still catches an unlabelled lessons bullet in a CRLF file (expected exit 1, got $rc)"
grep -qE "unlabelled lesson bullet" <<< "$err" \
  || fail "case: rule 3 still catches an unlabelled lessons bullet in a CRLF file (wrong reason: $err)"
pass "case: rule 3 still catches an unlabelled lessons bullet in a CRLF file"

# case: a detail that quotes the ledger grammar is not a second ledger line —
# the detail text itself contains " — status: " / " — detail: " substrings
# (quoting an older ledger line for illustration); leftmost match() must still
# resolve the REAL separators first, so this remains one well-formed line.
quoting="$TMP/quoting.md"
cp "$FIX/pass-canonical.md" "$quoting"
sed -i.bak 's/^- input: previous-retro .*$/- input: previous-retro — status: read — detail: 1 prior retro; an older note quoted "- input: cycle-window — status: empty — detail: none" for illustration/' "$quoting"
rm -f "$quoting.bak"
bash "$RETRO" "$quoting" >/dev/null 2>&1 \
  || fail "case: a detail that quotes the ledger grammar is not a second ledger line"
pass "case: a detail that quotes the ledger grammar is not a second ledger line"

printf '\nAll check-retro assertions passed.\n'
