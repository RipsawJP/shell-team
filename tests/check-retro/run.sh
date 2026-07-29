#!/usr/bin/env bash
# run.sh — drive bin/check-retro.sh against fixtures and assert the documented
# behavior (T-010 acceptance criteria):
#   - a canonical retro passes (exit 0)
#   - missing H1 / bare (un-decorated) heading / missing section / unlabelled
#     Lesson bullet each fail (exit 1) with a matching reason
#   - the repo's own tasks/retros/2026-04-30.md passes (dogfood, AC2)
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

assert_rc "pass-canonical -> 0"        0 "" "$FIX/pass-canonical.md"
assert_rc "fail-no-h1 -> 1"            1 "not '# Retro"           "$FIX/fail-no-h1.md"
assert_rc "fail-bare-heading -> 1"     1 "missing decorated section heading" "$FIX/fail-bare-heading.md"
assert_rc "fail-missing-section -> 1"  1 "missing decorated section heading: ## Try" "$FIX/fail-missing-section.md"
# T-029: the 罠の点検 (loop-trap self-check) section is mandatory — a retro with
# all four KPT+Lesson sections but no 罠の点検 must fail.
assert_rc "fail-missing-traps -> 1"    1 "missing decorated section heading: ## 罠の点検（Comprehension Debt / Cognitive Surrender）" "$FIX/fail-missing-traps.md"
assert_rc "fail-bare-lesson -> 1"      1 "unlabelled Lesson 候補 bullet"    "$FIX/fail-bare-lesson.md"
# A decorated heading string appearing only in prose / a blockquote (not as a
# real `## ` heading) must NOT satisfy rule 2 — the check is line-anchored.
assert_rc "fail-heading-in-prose -> 1" 1 "missing decorated section heading: ## Try" "$FIX/fail-heading-in-prose.md"
assert_rc "unreadable file -> 2"       2 "cannot read"           "$FIX/does-not-exist.md"
assert_rc "no args -> 2"               2 "usage"

# Multiple files: a clean one + a failing one => exit 1 (the failure wins).
assert_rc "multi: clean + failing -> 1" 1 "fail-no-h1" "$FIX/pass-canonical.md" "$FIX/fail-no-h1.md"

# T-087 AC4/AC7: fail-closed under temp-path unavailability. Rule 3's check is
# now folded into the awk pass that reads the file directly (no here-string /
# temp-file dependency), so pointing $TMPDIR at a non-existent, non-writable
# directory must NOT make the malformed-bullet fixture fall through to a false
# exit 0 — the unlabelled bullet must still be caught.
rc=0
err="$(TMPDIR=/nonexistent-tmp-t087 bash "$RETRO" "$FIX/fail-bare-lesson.md" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -ne 0 ] || fail "fail-closed under broken TMPDIR: expected non-zero exit, got 0 (fail-open regression)"
grep -qE "unlabelled Lesson 候補 bullet" <<< "$err" \
  || fail "fail-closed under broken TMPDIR: malformed bullet must still be reported (got: $err)"
pass "fail-closed: broken TMPDIR still catches fail-bare-lesson.md (exit $rc)"

# T-1001: the "## Retro inputs" ledger — a closed enum, fail-closed on every
# recognised violation shape (AC18). Each of the ten fixtures below isolates
# exactly one violation; "case:" labels below are asserted verbatim by the spec.
assert_rc "case: a well-formed Retro inputs ledger passes" \
  0 "" "$FIX/pass-canonical.md"
assert_rc "fail-inputs-missing-section -> 1"     1 "missing decorated section heading: ## Retro inputs" "$FIX/fail-inputs-missing-section.md"
assert_rc "fail-inputs-unknown-status -> 1"      1 "unknown Retro inputs status"                        "$FIX/fail-inputs-unknown-status.md"
assert_rc "fail-inputs-unknown-id -> 1"          1 "unknown Retro inputs id"                             "$FIX/fail-inputs-unknown-id.md"
assert_rc "fail-inputs-missing-id -> 1"          1 "missing Retro inputs id: lessons"                    "$FIX/fail-inputs-missing-id.md"
assert_rc "fail-inputs-duplicate-id -> 1"        1 "duplicated Retro inputs id"                          "$FIX/fail-inputs-duplicate-id.md"
assert_rc "fail-inputs-empty-detail -> 1"        1 "empty Retro inputs detail"                           "$FIX/fail-inputs-empty-detail.md"
assert_rc "case: a whitespace-only detail is reported" \
  1 "whitespace-only Retro inputs detail" "$FIX/fail-inputs-blank-detail.md"
assert_rc "fail-inputs-stray-line -> 1"          1 "unrecognised line inside ## Retro inputs"            "$FIX/fail-inputs-stray-line.md"
assert_rc "fail-inputs-duplicate-section -> 1"   1 "duplicated ## Retro inputs section heading"          "$FIX/fail-inputs-duplicate-section.md"
assert_rc "fail-inputs-line-outside-section -> 1" 1 "ledger-shaped line outside the ## Retro inputs section" "$FIX/fail-inputs-line-outside-section.md"

# T-1001 v2 (AC17): "a tolerance claim is proved by a malformed input, never a
# well-formed one." v1's CRLF criterion asked for a VALID CRLF file to pass,
# which a CR-unaware region walk satisfied by never examining the file at all
# — "accepted" and "unexamined" produced the same result. So this case starts
# from a BROKEN ledger (one id present with no status at all, the other seven
# ids missing entirely) and asserts it is STILL REPORTED after conversion to
# CRLF — a checker that silently skipped the file would pass this file
# clean, which is exactly the defect v1 shipped.
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
  printf '## Keep（続けたい良い動き）\n\n- `<x>`\n\n'
  printf '## Problem（直面した課題 / 痛み）\n\n- `<x>`\n\n'
  printf '## Try（次サイクルで試すこと）\n\n- `<x>`\n\n'
  printf '## 罠の点検（Comprehension Debt / Cognitive Surrender）\n\n- `<x>`\n\n'
  printf '## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）\n\n- `[common]` ok\n'
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
# never modified. `has_exact_line` (rule 2, the independent determination)
# and rule 3's own CR strip are left untouched by this edit — only the
# `sub(/\r$/, "", line)` that appears AFTER the "# Rule 4:" marker comment
# is neutralized, isolating the mutation to the region walk exactly as the
# spec names it.
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

# T-1001 v2 (AC19): rule 3's region walk matches its Lesson-候補 heading by
# PREFIX (grep -E, no end anchor), so it is CR-tolerant by construction and
# was never the source of the CRLF blocker — confirmed by fixture rather than
# assumed. A CRLF file with an otherwise-clean retro but an unlabelled Lesson
# bullet must still be caught.
rule3_crlf="$TMP/rule3-crlf.md"
sed 's/$/\r/' "$FIX/fail-bare-lesson.md" > "$rule3_crlf"
rc=0
err="$(bash "$RETRO" "$rule3_crlf" 2>&1 >/dev/null)" || rc=$?
[ "$rc" -eq 1 ] || fail "case: rule 3 still catches an unlabelled Lesson bullet in a CRLF file (expected exit 1, got $rc)"
grep -qE "unlabelled Lesson 候補 bullet" <<< "$err" \
  || fail "case: rule 3 still catches an unlabelled Lesson bullet in a CRLF file (wrong reason: $err)"
pass "case: rule 3 still catches an unlabelled Lesson bullet in a CRLF file"

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
