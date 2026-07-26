#!/usr/bin/env bash
# run.sh — drive bin/check-board-headings.sh against the fixtures and assert
# the documented behavior (docs/specs/T-079-board-heading-integrity.md AC4-13):
#   deletion / replacement / duplicate  -> non-zero exit (stderr names the ids)
#   pure-add / close-out-move / identical / self-ref -> exit 0 (no false-positive)
#   Reserved-section checkbox-shaped lookalikes (outside Active/Done) -> exit 0
#     (section-boundary regression, Codex round-1 Major finding)
#   explicit --base unresolvable        -> exit 2 (fail-closed)
#   --base <ref> production path (git merge-base) -> exit 0 / exit 1 correctly
#   --base omitted + no default resolves (first commit) -> skip class-2, exit 0
#     (duplicate check still enforced even when the base is unresolved)
#
# Temp git roots live under $TMPDIR (sandboxed runs deny writes to a nested
# .git/ inside the repo tree and deny process substitution — see
# tests/close-out/run.sh and tests/check-handoff/run.sh for the same
# constraints), cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-board-headings.sh"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

TMP="${TMPDIR:-/tmp}/check-board-headings-test-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

out="$TMP/out"
err="$TMP/err"

run_check() {
  # $@ = args to the script; result exit code left in $rc, stdout/stderr in
  # $out/$err.
  set +e
  bash "$SCRIPT" "$@" >"$out" 2>"$err"
  rc=$?
  set -e
}

# --- AC4: deletion -------------------------------------------------------------
run_check "$FIX/deletion-head.md" --base-file "$FIX/base.md"
[[ "$rc" -ne 0 ]] || fail "deletion fixture expected non-zero exit, got 0"
grep -q 'T-102' "$err" || fail "deletion stderr should name T-102 (got: $(cat "$err"))"
pass "AC4 deletion — non-zero exit, stderr names the missing T-102"

# --- AC5: replacement -----------------------------------------------------------
run_check "$FIX/replacement-head.md" --base-file "$FIX/base.md"
[[ "$rc" -ne 0 ]] || fail "replacement fixture expected non-zero exit, got 0"
grep -q 'T-102' "$err" || fail "replacement stderr should name the overwritten T-102 (got: $(cat "$err"))"
pass "AC5 replacement — non-zero exit, stderr names the overwritten T-102"

# --- AC6: duplicate --------------------------------------------------------------
run_check "$FIX/duplicate-head.md" --base-file "$FIX/base.md"
[[ "$rc" -ne 0 ]] || fail "duplicate fixture expected non-zero exit, got 0"
grep -q 'duplicate' "$err" || fail "duplicate stderr missing 'duplicate' (got: $(cat "$err"))"
grep -q 'T-103' "$err" || fail "duplicate stderr should name T-103 (got: $(cat "$err"))"
pass "AC6 duplicate — non-zero exit, stderr names the duplicated T-103"

# --- AC7: pure-add ---------------------------------------------------------------
run_check "$FIX/pure-add-head.md" --base-file "$FIX/base.md"
[[ "$rc" -eq 0 ]] || fail "pure-add fixture expected exit 0, got $rc (stderr: $(cat "$err"))"
pass "AC7 pure-add — exit 0 (base headings preserved, new T-104 added)"

# --- AC8: close-out Active->Done move (DP-D core invariant) --------------------
run_check "$FIX/close-out-move-head.md" --base-file "$FIX/base.md"
[[ "$rc" -eq 0 ]] || fail "close-out-move fixture expected exit 0, got $rc (stderr: $(cat "$err"))"
pass "AC8 close-out-move — exit 0 (whole-board membership unchanged; Done reorder not gated)"

# --- AC9: identical ----------------------------------------------------------------
run_check "$FIX/identical-head.md" --base-file "$FIX/base.md"
[[ "$rc" -eq 0 ]] || fail "identical fixture expected exit 0, got $rc (stderr: $(cat "$err"))"
pass "AC9 identical — exit 0 (no change)"

# --- AC10: self-referential prose sub-bullet is not a heading -------------------
run_check "$FIX/self-ref-head.md" --base-file "$FIX/base.md"
[[ "$rc" -eq 0 ]] || fail "self-ref fixture expected exit 0, got $rc (stderr: $(cat "$err"))"
pass "AC10 self-ref — exit 0 (indented sub-bullet quoting a heading-shaped string is not counted)"

# --- T-095 (issue #300): section-boundary parser hardening — fence tracking
# (item1) + ATX-closing-notation tolerance (item2). Each fixed-lock assertion
# below is paired with a non-vacuous counterfactual: the SAME fixture fed to
# a frozen, self-contained, byte-verbatim copy of the pre-T-095
# extract_ids_to_file awk program (exact-match section regex, NO fence
# tracking — confirmed byte-identical to
# `git show <merge-base develop HEAD>:bin/check-board-headings.sh` at
# authoring time) must mis-extract (phantom-extract a fenced example id, or
# extract ZERO ids from an ATX-closing section), proving the lock actually
# exercises the fix rather than passing vacuously on both old and new code
# (T-091 round1 Blocker lesson — no moving git ref, self-contained inline
# snippet only).
# shellcheck disable=SC2016  # single-quoted on purpose: this is the frozen awk
# program source (a literal string handed to `awk`), not a shell expansion.
OLD_AWK_PROG='
  /^## Active[[:space:]]*$/ { in_section=1; next }
  /^## Done[[:space:]]*$/   { in_section=1; next }
  /^## / { in_section=0; next }
  !in_section { next }
  /^[[:space:]]+-/ { next }
  /^- \[[x ]\] (\*\*)?T-[0-9]+(\*\*)? / {
    if (match($0, /T-[0-9]+/)) print substr($0, RSTART, RLENGTH)
  }
'
old_extract() { awk "$OLD_AWK_PROG" "$1"; }

# AC1 (item1, fence, negative, non-vacuous lock): a fenced `## Format`
# code-block example containing a phantom `## Active` + T-102 checkbox must
# NOT resurrect in_section or phantom-extract T-102 in the FIXED checker, so
# a REAL deletion of T-102 from the genuine Active section is still detected.
run_check "$FIX/fence-lookalike-head.md" --base-file "$FIX/fence-lookalike-base.md"
[[ "$rc" -ne 0 ]] || fail "fence-lookalike fixture (fixed checker) expected non-zero exit (real T-102 deletion masked by fence phantom), got 0"
grep -q 'T-102' "$err" || fail "fence-lookalike stderr should name the deleted T-102 (got: $(cat "$err"))"
pass "AC1 fence-lookalike (fixed checker) — non-zero exit, fence suppressed, real T-102 deletion detected"

old_extract "$FIX/fence-lookalike-base.md" | sort -u > "$TMP/old-fence-lookalike-base-uniq"
old_extract "$FIX/fence-lookalike-head.md" | sort -u > "$TMP/old-fence-lookalike-head-uniq"
old_fence_lookalike_missing="$(comm -23 "$TMP/old-fence-lookalike-base-uniq" "$TMP/old-fence-lookalike-head-uniq")"
[[ -z "$old_fence_lookalike_missing" ]] || fail "AC1 counterfactual: expected the OLD (pre-T-095, no fence tracking) awk to phantom-extract the fenced T-102 example and mask the real deletion (empty id-set diff), but it detected: $old_fence_lookalike_missing"
grep -Fq 'T-102' "$TMP/old-fence-lookalike-head-uniq" || fail "AC1 counterfactual: expected the OLD awk's head id set to contain the phantom T-102 (got: $(cat "$TMP/old-fence-lookalike-head-uniq"))"
pass "AC1 non-vacuous counterfactual — OLD (pre-T-095, no fence tracking) awk phantom-extracts the fenced T-102 example and silently masks the real deletion (id-set diff empty); the fixed checker above correctly flags it"

# AC2 (item1, fence, positive, non-vacuous lock): the same fenced phantom
# `## Active` + T-102, but WITHOUT the real T-102 deletion (Active keeps both
# T-101 and T-102) — the FIXED checker must not raise a false-duplicate.
run_check "$FIX/fence-dup-head.md" --base-file "$FIX/fence-lookalike-base.md"
[[ "$rc" -eq 0 ]] || fail "fence-dup fixture (fixed checker) expected exit 0 (fence suppressed, no false-duplicate), got $rc (stderr: $(cat "$err"))"
pass "AC2 fence-dup (fixed checker) — exit 0, fence suppressed, no false-duplicate from the phantom T-102"

old_extract "$FIX/fence-dup-head.md" > "$TMP/old-fence-dup-head-raw"
old_fence_dup_dupes="$(sort "$TMP/old-fence-dup-head-raw" | uniq -d)"
[[ -n "$old_fence_dup_dupes" ]] || fail "AC2 counterfactual: expected the OLD awk to phantom-duplicate T-102 (got no duplicates: $(cat "$TMP/old-fence-dup-head-raw"))"
printf '%s' "$old_fence_dup_dupes" | grep -Fq 'T-102' || fail "AC2 counterfactual: expected old duplicate set to include T-102 (got: $old_fence_dup_dupes)"
pass "AC2 non-vacuous counterfactual — OLD (pre-T-095, no fence tracking) awk phantom-duplicates T-102 (a false-duplicate would fire); the fixed checker above correctly suppresses it"

# AC3 (item2, ATX, negative, non-vacuous lock): section headings written as
# `## Active ##` / `## Done ##` (CommonMark ATX-closing notation) with a
# REAL deletion of T-202 underneath — the FIXED checker must normalize-match
# the ATX-closing heading, enable in_section, and detect the deletion.
run_check "$FIX/atx-closing-head.md" --base-file "$FIX/atx-closing-base.md"
[[ "$rc" -ne 0 ]] || fail "atx-closing fixture (fixed checker) expected non-zero exit (T-202 deletion under ATX-closing headings), got 0"
grep -q 'T-202' "$err" || fail "atx-closing stderr should name the deleted T-202 (got: $(cat "$err"))"
pass "AC3 atx-closing (fixed checker) — non-zero exit, ATX-closing heading normalized, T-202 deletion detected"

old_extract "$FIX/atx-closing-base.md" > "$TMP/old-atx-closing-base-ids"
old_extract "$FIX/atx-closing-head.md" > "$TMP/old-atx-closing-head-ids"
[[ ! -s "$TMP/old-atx-closing-base-ids" ]] || fail "AC3 counterfactual: expected the OLD (exact-match section regex) awk to extract ZERO ids from atx-closing-base.md (ATX-closing heading not recognized), got: $(cat "$TMP/old-atx-closing-base-ids")"
[[ ! -s "$TMP/old-atx-closing-head-ids" ]] || fail "AC3 counterfactual: expected the OLD awk to extract ZERO ids from atx-closing-head.md (ATX-closing heading not recognized), got: $(cat "$TMP/old-atx-closing-head-ids")"
pass "AC3 non-vacuous counterfactual — OLD (pre-T-095, exact-match section regex) awk extracts ZERO ids from either side of the ATX-closing (## Active ##) board, silently masking the T-202 deletion; the fixed checker above correctly detects it"

# AC4 (item2, over-match, positive): `## Active Backlog` (a DIFFERENT heading
# that merely starts with "## Active") must NOT be enabled as the Active
# section by the normalized ATX-closing match — no false-duplicate on T-401.
run_check "$FIX/atx-overmatch-head.md" --base-file "$FIX/atx-overmatch-base.md"
[[ "$rc" -eq 0 ]] || fail "atx-overmatch fixture expected exit 0 (## Active Backlog must not enable the Active section — over-match guard), got $rc (stderr: $(cat "$err"))"
pass "AC4 atx-overmatch — exit 0 (## Active Backlog over-match guard: distinct heading not enabled as Active, no false-duplicate on T-401)"

# --- T-095 Codex round1 review (same-class-2: 2 fence-toggle Majors + 1 ATX
# Blocker found on the FIRST T-095 cut) — the fence tracker was redesigned as
# a small CommonMark-aligned state machine (fence_len-aware open/close) and
# the ATX-closing match now requires >=1 space before the closing hash run.
# Each lock below is paired with a non-vacuous counterfactual against a
# frozen, self-contained, byte-verbatim copy of the ROUND1 (not the original
# pre-T-095) extract_ids_to_file awk — the exact code Codex's round1 review
# exercised — proving each fixture reproduces a REAL round1 regression, not
# a synthetic strawman.
# shellcheck disable=SC2016  # single-quoted on purpose: this is the frozen
# awk program source (a literal string handed to `awk`), not a shell
# expansion.
ROUND1_AWK_PROG='
  /^[[:space:]]*```/ { in_fence = !in_fence; next }
  in_fence { next }
  /^## Active[[:space:]]*#*[[:space:]]*$/ { in_section=1; next }
  /^## Done[[:space:]]*#*[[:space:]]*$/   { in_section=1; next }
  /^## / { in_section=0; next }
  !in_section { next }
  /^[[:space:]]+-/ { next }
  /^- \[[x ]\] (\*\*)?T-[0-9]+(\*\*)? / {
    if (match($0, /T-[0-9]+/)) print substr($0, RSTART, RLENGTH)
  }
'
round1_extract() { awk "$ROUND1_AWK_PROG" "$1"; }

# AC-B (Blocker, ATX zero-whitespace, negative, non-vacuous lock): a
# lookalike heading `## Active###` (no space before the closing hash run)
# is, per CommonMark, a heading literally titled "Active###" — a DIFFERENT
# heading from "Active" — and must NOT be treated as the Active section.
# The fixed checker must therefore still detect the REAL T-302 deletion from
# the genuine `## Active` section (the phantom T-302 example parked under
# the lookalike heading must not compensate for it).
run_check "$FIX/atx-zerows-head.md" --base-file "$FIX/atx-zerows-base.md"
[[ "$rc" -ne 0 ]] || fail "atx-zerows fixture (fixed checker) expected non-zero exit (real T-302 deletion masked by the zero-whitespace ATX lookalike), got 0"
grep -q 'T-302' "$err" || fail "atx-zerows stderr should name the deleted T-302 (got: $(cat "$err"))"
pass "AC-B atx-zerows (fixed checker) — non-zero exit, zero-whitespace ATX-closing lookalike NOT enabled as Active, real T-302 deletion detected"

round1_extract "$FIX/atx-zerows-base.md" | sort -u > "$TMP/round1-atx-zerows-base-uniq"
round1_extract "$FIX/atx-zerows-head.md" | sort -u > "$TMP/round1-atx-zerows-head-uniq"
round1_atx_zerows_missing="$(comm -23 "$TMP/round1-atx-zerows-base-uniq" "$TMP/round1-atx-zerows-head-uniq")"
[[ -z "$round1_atx_zerows_missing" ]] || fail "AC-B counterfactual: expected the ROUND1 (zero-whitespace-permissive ATX) awk to phantom-extract T-302 under the lookalike heading and mask the real deletion (empty id-set diff), but it detected: $round1_atx_zerows_missing"
grep -Fq 'T-302' "$TMP/round1-atx-zerows-head-uniq" || fail "AC-B counterfactual: expected the ROUND1 awk's head id set to contain the phantom T-302 (got: $(cat "$TMP/round1-atx-zerows-head-uniq"))"
pass "AC-B non-vacuous counterfactual — ROUND1 (zero-whitespace-permissive ATX match) awk wrongly enables the '## Active###' lookalike as the Active section, phantom-extracts T-302, and silently masks the real deletion; the fixed checker above correctly flags it"

# AC-Ma (Major(a), trailing-content fence closer, negative, non-vacuous
# lock): a line with a backtick run FOLLOWED BY trailing content
# (```` ```payload-not-a-real-close ````) does NOT close a fence per
# CommonMark (only whitespace may follow the backtick run). The fixed
# checker must keep suppressing the fenced phantom T-502 example and still
# detect the REAL T-502 deletion from the genuine Active section.
run_check "$FIX/fence-trailing-close-head.md" --base-file "$FIX/fence-trailing-close-base.md"
[[ "$rc" -ne 0 ]] || fail "fence-trailing-close fixture (fixed checker) expected non-zero exit (real T-502 deletion masked by the trailing-content fake closer), got 0"
grep -q 'T-502' "$err" || fail "fence-trailing-close stderr should name the deleted T-502 (got: $(cat "$err"))"
pass "AC-Ma fence-trailing-close (fixed checker) — non-zero exit, trailing-content line does NOT close the fence, real T-502 deletion detected"

round1_extract "$FIX/fence-trailing-close-base.md" | sort -u > "$TMP/round1-fence-trailing-close-base-uniq"
round1_extract "$FIX/fence-trailing-close-head.md" | sort -u > "$TMP/round1-fence-trailing-close-head-uniq"
round1_fence_trailing_close_missing="$(comm -23 "$TMP/round1-fence-trailing-close-base-uniq" "$TMP/round1-fence-trailing-close-head-uniq")"
[[ -z "$round1_fence_trailing_close_missing" ]] || fail "AC-Ma counterfactual: expected the ROUND1 (any-backtick-line toggles) awk to wrongly close on the trailing-content line, phantom-extract T-502, and mask the real deletion (empty id-set diff), but it detected: $round1_fence_trailing_close_missing"
grep -Fq 'T-502' "$TMP/round1-fence-trailing-close-head-uniq" || fail "AC-Ma counterfactual: expected the ROUND1 awk's head id set to contain the phantom T-502 (got: $(cat "$TMP/round1-fence-trailing-close-head-uniq"))"
pass "AC-Ma non-vacuous counterfactual — ROUND1 (naive any-backtick-line toggle, no closer validation) awk wrongly treats the trailing-content line as a fence close, phantom-extracts T-502, and silently masks the real deletion; the fixed checker above correctly flags it"

# AC-Mb (Major(b), length-mismatch nested fence, negative, non-vacuous
# lock): a 3-backtick line INSIDE a 4-backtick-opened fence must NOT close
# it (CommonMark: a closer must be >= the opener's run length). The fixed
# checker must keep suppressing the nested phantom T-602 example (only the
# real 4-backtick closer ends the fence) and still detect the REAL T-602
# deletion from the genuine Active section.
run_check "$FIX/fence-length-mismatch-head.md" --base-file "$FIX/fence-length-mismatch-base.md"
[[ "$rc" -ne 0 ]] || fail "fence-length-mismatch fixture (fixed checker) expected non-zero exit (real T-602 deletion masked by the length-mismatched nested fence), got 0"
grep -q 'T-602' "$err" || fail "fence-length-mismatch stderr should name the deleted T-602 (got: $(cat "$err"))"
pass "AC-Mb fence-length-mismatch (fixed checker) — non-zero exit, 3-backtick line does NOT close the 4-backtick outer fence, real T-602 deletion detected"

round1_extract "$FIX/fence-length-mismatch-base.md" | sort -u > "$TMP/round1-fence-length-mismatch-base-uniq"
round1_extract "$FIX/fence-length-mismatch-head.md" | sort -u > "$TMP/round1-fence-length-mismatch-head-uniq"
round1_fence_length_mismatch_missing="$(comm -23 "$TMP/round1-fence-length-mismatch-base-uniq" "$TMP/round1-fence-length-mismatch-head-uniq")"
[[ -z "$round1_fence_length_mismatch_missing" ]] || fail "AC-Mb counterfactual: expected the ROUND1 (length-unaware any-backtick-line toggle) awk to wrongly close the outer fence on the inner 3-backtick line, phantom-extract T-602, and mask the real deletion (empty id-set diff), but it detected: $round1_fence_length_mismatch_missing"
grep -Fq 'T-602' "$TMP/round1-fence-length-mismatch-head-uniq" || fail "AC-Mb counterfactual: expected the ROUND1 awk's head id set to contain the phantom T-602 (got: $(cat "$TMP/round1-fence-length-mismatch-head-uniq"))"
pass "AC-Mb non-vacuous counterfactual — ROUND1 (length-unaware fence toggle) awk wrongly closes the 4-backtick outer fence on the shorter 3-backtick inner line, phantom-extracts T-602, and silently masks the real deletion; the fixed checker above correctly flags it"

# Bonus (Minor, optional per Codex round1 — 4-space-indent fence-lookalike,
# positive, non-vacuous): a fence opener requires <=3 leading whitespace
# columns per CommonMark (4+ is an indented code block, not a fence). A
# 4-space-indented backtick line with NO matching close must NOT be
# recognized as a fence opener, so it must not over-suppress the genuine
# Active/Done content that follows it (false-positive avoidance — this class
# was already carved out as Out-of-scope in the spec's DECISION 3, so this
# fixture is a bonus regression lock, not a required AC).
run_check "$FIX/fence-indent-lookalike-head.md" --base-file "$FIX/fence-indent-lookalike-base.md"
[[ "$rc" -eq 0 ]] || fail "fence-indent-lookalike fixture (fixed checker) expected exit 0 (4-space-indented backtick line is NOT a fence opener, must not over-suppress T-802/T-075), got $rc (stderr: $(cat "$err"))"
pass "Bonus fence-indent-lookalike (fixed checker) — exit 0, 4-space-indented backtick line not recognized as a fence opener, no over-suppression"

round1_extract "$FIX/fence-indent-lookalike-base.md" | sort -u > "$TMP/round1-fence-indent-base-uniq"
round1_extract "$FIX/fence-indent-lookalike-head.md" | sort -u > "$TMP/round1-fence-indent-head-uniq"
round1_fence_indent_missing="$(comm -23 "$TMP/round1-fence-indent-base-uniq" "$TMP/round1-fence-indent-head-uniq")"
[[ -n "$round1_fence_indent_missing" ]] || fail "Bonus counterfactual: expected the ROUND1 (unbounded-indent fence toggle) awk to over-suppress content after the indented lookalike (non-empty id-set diff), got none"
printf '%s' "$round1_fence_indent_missing" | grep -Fq 'T-802' || fail "Bonus counterfactual: expected the ROUND1 awk's false-missing set to include the over-suppressed T-802 (got: $round1_fence_indent_missing)"
pass "Bonus non-vacuous counterfactual — ROUND1 (unbounded leading-whitespace fence toggle) awk wrongly treats the 4-space-indented backtick line as a fence opener and over-suppresses the real T-802/T-075 entries that follow it (false-positive deletion report); the fixed checker above correctly avoids this"

# --- T-095 Codex round2 review (a single new Major, distinct root cause from
# round1): the rework1 fence indent bound counted CHARACTERS
# (`[[:space:]]{0,3}`), not CommonMark COLUMNS — a single leading TAB is
# column 4 in CommonMark (tabs expand to the next multiple of 4), so it must
# NOT qualify as fence-openable indentation, but a naive char-count `<=3`
# wrongly let a 1-character tab through (1 <= 3), over-suppressing genuine
# content. Fixed by restricting the indent-count regex to LITERAL SPACES
# ONLY (`[ ]{0,3}`, tabs excluded outright) for both the opener and the
# closer — the simplest construction that can never miscount a tab as
# "<=3", and consistent with the redesign's own declared "<=3 columns"
# contract. Non-vacuous counterfactual: the frozen ROUND1/rework1
# (char-count) awk, fed the SAME tab-indented fixture, must over-suppress.
# shellcheck disable=SC2016  # single-quoted on purpose: this is the frozen
# awk program source (a literal string handed to `awk`), not a shell
# expansion.
ROUND1_CHARCOUNT_AWK_PROG='
  !in_fence {
    if (match($0, /^[[:space:]]{0,3}`{3,}/)) {
      fence_run = substr($0, RSTART, RLENGTH)
      gsub(/^[[:space:]]+/, "", fence_run)
      fence_len = length(fence_run)
      in_fence = 1
      next
    }
  }
  in_fence {
    close_pat = "^[[:space:]]{0,3}`{" fence_len ",}[[:space:]]*$"
    if ($0 ~ close_pat) { in_fence = 0 }
    next
  }
  /^## Active([[:space:]]+#+)?[[:space:]]*$/ { in_section=1; next }
  /^## Done([[:space:]]+#+)?[[:space:]]*$/   { in_section=1; next }
  /^## / { in_section=0; next }
  !in_section { next }
  /^[[:space:]]+-/ { next }
  /^- \[[x ]\] (\*\*)?T-[0-9]+(\*\*)? / {
    if (match($0, /T-[0-9]+/)) print substr($0, RSTART, RLENGTH)
  }
'
round1_charcount_extract() { awk "$ROUND1_CHARCOUNT_AWK_PROG" "$1"; }

# AC-Tab (round2 Major, tab-indent fence-lookalike, positive, non-vacuous
# lock): a single leading TAB before a backtick run is column 4 in
# CommonMark and must NOT be recognized as a fence opener, so it must not
# over-suppress the genuine Active/Done content (T-902, T-076) that follows
# it.
run_check "$FIX/fence-tab-indent-lookalike-head.md" --base-file "$FIX/fence-tab-indent-lookalike-base.md"
[[ "$rc" -eq 0 ]] || fail "fence-tab-indent-lookalike fixture (fixed checker) expected exit 0 (a single leading TAB is column 4, NOT a fence opener, must not over-suppress T-902/T-076), got $rc (stderr: $(cat "$err"))"
pass "AC-Tab fence-tab-indent-lookalike (fixed checker) — exit 0, tab-indented backtick line not recognized as a fence opener (space-only indent count), no over-suppression"

round1_charcount_extract "$FIX/fence-tab-indent-lookalike-base.md" | sort -u > "$TMP/round1cc-fence-tab-base-uniq"
round1_charcount_extract "$FIX/fence-tab-indent-lookalike-head.md" | sort -u > "$TMP/round1cc-fence-tab-head-uniq"
round1cc_fence_tab_missing="$(comm -23 "$TMP/round1cc-fence-tab-base-uniq" "$TMP/round1cc-fence-tab-head-uniq")"
[[ -n "$round1cc_fence_tab_missing" ]] || fail "AC-Tab counterfactual: expected the ROUND1/rework1 (char-count indent) awk to over-suppress content after the tab-indented lookalike (non-empty id-set diff), got none"
printf '%s' "$round1cc_fence_tab_missing" | grep -Fq 'T-902' || fail "AC-Tab counterfactual: expected the ROUND1/rework1 awk's false-missing set to include the over-suppressed T-902 (got: $round1cc_fence_tab_missing)"
pass "AC-Tab non-vacuous counterfactual — ROUND1/rework1 (character-count '[[:space:]]{0,3}' indent bound) awk wrongly treats a single leading TAB (CommonMark column 4) as within the <=3 bound and recognizes it as a fence opener, over-suppressing the real T-902/T-076 entries that follow it (false-positive deletion report); the fixed (space-only '[ ]{0,3}') checker above correctly avoids this"

# --- section-boundary regression (Codex round-1 Major finding) -----------------
# extract_ids_to_file must track `## Active` / `## Done` section boundaries,
# not scan the whole file. A checkbox-shaped `T-NNN` line placed in ANY other
# `## ` section (Reserved/Planned/Format, or a future one) — a plausible
# real-world editing mistake, the exact class this task machine-verifies
# against — must be invisible to both the duplicate check and the
# deletion/replacement check. Without section tracking this fixture pair
# would (a) false-positive a duplicate on T-101 (it appears once in Active,
# once in the Reserved lookalike) and (b) false-positive a deletion on T-900
# (present in base's Reserved section, absent from head's).
run_check "$FIX/reserved-lookalike-head.md" --base-file "$FIX/reserved-lookalike-base.md"
[[ "$rc" -eq 0 ]] || fail "reserved-lookalike fixture expected exit 0 (section-scoped extraction), got $rc (stderr: $(cat "$err"))"
pass "section-boundary — Reserved-section checkbox-shaped lookalikes are ignored (no false duplicate, no false deletion)"

# --- AC11: explicit --base unresolvable => fail-closed exit 2 -------------------
run_check "$FIX/base.md" --base __no_such_ref_xyz__
[[ "$rc" -eq 2 ]] || fail "explicit unresolvable --base expected exit 2, got $rc"
pass "AC11 explicit unresolvable --base — fail-closed exit 2"

# --- git-ref production path: merge-base resolution in a temp git repo ---------
GITROOT="$TMP/git-repo"
mkdir -p "$GITROOT"
(
  cd "$GITROOT"
  git init -q -b main
  git config user.email t@example.invalid
  git config user.name t
  git config commit.gpgsign false
  cp "$FIX/base.md" todo.md
  git add todo.md
  git commit -qm "initial board"
)
BASE_SHA="$(cd "$GITROOT" && git rev-parse HEAD)"

# Positive: pure-add committed on top of the base commit; --base <base_sha>
# resolves via merge-base and finds no deletions.
(
  cd "$GITROOT"
  cp "$FIX/pure-add-head.md" todo.md
  git add todo.md
  git commit -qm "pure add"
)
set +e
(cd "$GITROOT" && bash "$SCRIPT" todo.md --base "$BASE_SHA") >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "git-ref pure-add expected exit 0, got $rc (stderr: $(cat "$err"))"
pass "git-ref production path (pure-add) — --base <sha> resolves via merge-base, exit 0"

# Negative: same repo, next commit deletes a heading; --base <base_sha> (still
# the ORIGINAL commit, several commits back) must still detect the deletion —
# proves merge-base based comparison is stable across multiple intervening
# commits (squash/rebase-shaped history), not just the immediate parent.
(
  cd "$GITROOT"
  cp "$FIX/deletion-head.md" todo.md
  git add todo.md
  git commit -qm "deletion via git"
)
set +e
(cd "$GITROOT" && bash "$SCRIPT" todo.md --base "$BASE_SHA") >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "git-ref deletion expected non-zero exit, got 0"
grep -q 'T-102' "$err" || fail "git-ref deletion stderr should name T-102 (got: $(cat "$err"))"
pass "git-ref production path (deletion) — --base <sha> resolves via merge-base across multiple commits, detects the deletion"

# --- AC2 (#247 item 3, non-vacuous lock): materialize_base_from_ref resolves
# against the BOARD FILE'S OWN repo, not the caller's cwd (DECISION 4) -------
# BOARDROOT (the board's own repo, holding the base/head commits) and
# FOREIGN_ROOT (the invocation's cwd — a DIFFERENT repo root). FOREIGN_ROOT
# is a `git clone` of BOARDROOT taken AT THE BASE COMMIT (before the deletion
# below): a different repo root, but one that still knows the base SHA — so
# the OLD (cwd-resolving) checker's bare ref-resolve/merge-base calls
# SUCCEED there too, and it is specifically the later `abs_board` vs.
# `repo_root` membership check that must (wrongly, pre-fix) report the board
# as outside the repo, exactly the DECISION-4 target class (Input space
# class 1: absolute board path + arbitrary/foreign cwd).
BOARDROOT="$TMP/board-owns-repo"
mkdir -p "$BOARDROOT"
(
  cd "$BOARDROOT"
  git init -q -b main
  git config user.email t@example.invalid
  git config user.name t
  git config commit.gpgsign false
  cp "$FIX/base.md" todo.md
  git add todo.md
  git commit -qm "base board (T-102 present)"
)
BOARD_BASE_SHA="$(cd "$BOARDROOT" && git rev-parse HEAD)"

FOREIGN_ROOT="$TMP/foreign-cwd-repo"
git clone -q "$BOARDROOT" "$FOREIGN_ROOT"

(
  cd "$BOARDROOT"
  cp "$FIX/deletion-head.md" todo.md
  git add todo.md
  git commit -qm "head board (T-102 deleted)"
)
ABS_BOARD="$BOARDROOT/todo.md"

set +e
(cd "$FOREIGN_ROOT" && bash "$SCRIPT" "$ABS_BOARD" --base "$BOARD_BASE_SHA") >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || fail "AC2 foreign-cwd absolute-board invocation: expected exit 1 (deletion detected), got $rc (stderr: $(cat "$err"))"
grep -q 'T-102' "$err" || fail "AC2: stderr should name the deleted T-102 (got: $(cat "$err"))"
pass "AC2 foreign-cwd + absolute board path — materialize_base_from_ref resolves against the board's OWN repo (deletion detected, exit 1)"

# Non-vacuous counterfactual: the SAME invocation (same foreign cwd, same
# absolute board path, same base sha) against the OLD (cwd-resolving)
# `materialize_base_from_ref` logic must report the WRONG "outside the git
# repository" error (exit 2) instead of correctly detecting the deletion —
# proving this lock actually exercises the fix rather than passing vacuously
# on both old and new code.
#
# SELF-CONTAINED by construction (Codex round1 Blocker): the OLD behavior is
# baked in as an inline fixture below — a minimal, standalone reproduction of
# the pre-#247-item-3 `materialize_base_from_ref` body (bare `git`, no `-C`),
# copied verbatim from the pre-fix function (confirmed byte-identical to
# `git show <merge-base>:bin/check-board-headings.sh` at authoring time) —
# rather than fetched at test-run time via a moving ref. This has ZERO
# dependency on a `develop` branch existing locally (broken in CI's detached-
# HEAD PR checkout) and ZERO dependency on `HEAD` not yet having merged the
# fix (which would otherwise make `merge-base develop HEAD == HEAD`, i.e. the
# NEW code, a permanent vacuous-pass after merge). The frozen snippet only
# needs to reach the SAME membership die() this exact scenario hits; it
# deliberately omits the rest of the real function (ref resolution beyond the
# commit check, base-content materialization) since those are irrelevant to
# proving the wrong-message exit 2 asserted here.
OLD_SCRIPT="$TMP/check-board-headings-OLD.sh"
cat > "$OLD_SCRIPT" <<'OLDEOF'
#!/usr/bin/env bash
set -euo pipefail
die() { printf '%s: %s\n' "check-board-headings.sh" "$1" >&2; exit 2; }
BOARD="$1"; shift
BASE_REF=""
if [ "${1:-}" = "--base" ]; then BASE_REF="$2"; fi
# OLD (pre-#247-item-3) materialize_base_from_ref body: bare `git`, resolved
# against the CALLER's cwd — never `-C`-scoped to the board file's own repo.
# This is the exact defect DECISION 4 fixes.
if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null 2>&1; then
  die "cannot resolve --base ref: $BASE_REF"
fi
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repository (required for --base)"
abs_board="$(cd "$(dirname "$BOARD")" && pwd -P)/$(basename "$BOARD")"
case "$abs_board" in
  "$repo_root"/*) : ;;
  *) die "board file is outside the git repository: $BOARD" ;;
esac
exit 0
OLDEOF
chmod +x "$OLD_SCRIPT"
set +e
(cd "$FOREIGN_ROOT" && bash "$OLD_SCRIPT" "$ABS_BOARD" --base "$BOARD_BASE_SHA") >"$out" 2>"$err"
old_rc=$?
set -e
[[ "$old_rc" -eq 2 ]] || fail "AC2 counterfactual: expected the OLD (pre-fix) logic to fail-closed exit 2 for this foreign-cwd invocation, got $old_rc (stderr: $(cat "$err"))"
grep -q 'outside the git repository' "$err" || fail "AC2 counterfactual: OLD logic stderr should report the wrong 'outside the git repository' message (got: $(cat "$err"))"
pass "AC2 non-vacuous counterfactual — the OLD (cwd-resolving) logic wrongly reports 'board file is outside the git repository' (exit 2) for the identical invocation the fixed checker now resolves correctly (exit 1); self-contained inline fixture, no git-history/branch-name dependency"

# --- Major fix regression fixture (Codex round1 Major finding): the sibling
# default-base candidate-selection preamble (--base/--base-file both
# omitted) must ALSO resolve against the board file's OWN repository, not
# the caller's cwd — the same cwd-dependence class materialize_base_from_ref
# was already fixed for. Foreign cwd is a DIFFERENT, single-commit (shallow,
# no HEAD~1) repo; the board's own repo has multiple commits including a
# heading deletion. Pre-fix, `HEAD~1` failed to resolve in the foreign cwd,
# so candidate stayed empty and the structural check was silently SKIPPED
# (exit 0, deletion missed) — exactly the declared reachable class (spec
# `## Input space` class 1: "absolute board path + arbitrary/foreign cwd,
# always with a resolvable --base/--base-file or the default env/HEAD~1
# chain").
MAJOR_BOARDROOT="$TMP/major-board-repo"
mkdir -p "$MAJOR_BOARDROOT"
(
  cd "$MAJOR_BOARDROOT"
  git init -q -b main
  git config user.email t@example.invalid
  git config user.name t
  git config commit.gpgsign false
  cp "$FIX/base.md" todo.md
  git add todo.md
  git commit -qm "base board (T-102 present)"
  cp "$FIX/deletion-head.md" todo.md
  git add todo.md
  git commit -qm "head board (T-102 deleted) — this repo HAS a HEAD~1"
)
MAJOR_ABS_BOARD="$MAJOR_BOARDROOT/todo.md"

MAJOR_FOREIGN="$TMP/major-foreign-repo"
mkdir -p "$MAJOR_FOREIGN"
(
  cd "$MAJOR_FOREIGN"
  git init -q -b main
  git config user.email t@example.invalid
  git config user.name t
  git config commit.gpgsign false
  printf 'unrelated\n' > unrelated.txt
  git add unrelated.txt
  git commit -qm "only commit — this repo has NO HEAD~1"
)

set +e
(cd "$MAJOR_FOREIGN" && env -u CHECK_BOARD_HEADINGS_BASE -u GITHUB_BASE_REF bash "$SCRIPT" "$MAJOR_ABS_BOARD") >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 1 ]] || fail "Major fixture: default (--base omitted) preamble from a foreign shallow cwd against a multi-commit board repo expected exit 1 (deletion detected via the board repo's OWN HEAD~1), got $rc (stderr: $(cat "$err"))"
grep -q 'T-102' "$err" || fail "Major fixture: stderr should name the deleted T-102 (got: $(cat "$err"))"
pass "Major fixture — default (--base omitted) candidate-selection preamble resolves HEAD~1 against the board's OWN repo, not the caller's shallow foreign cwd (deletion detected, exit 1)"

# Non-vacuous counterfactual: the SAME invocation against the OLD (bare
# `git`, caller-cwd-resolving) preamble logic must instead fail to resolve
# ANY candidate in the foreign (shallow) cwd and silently SKIP the structural
# check (exit 0, missing the deletion) — proving this fixture actually
# exercises the extended fix rather than passing vacuously on both old and
# new code. Self-contained inline fixture (same discipline as the AC2
# counterfactual above): the OLD preamble body is baked in verbatim (bare
# `git rev-parse`, no `-C`), not fetched via a moving git ref.
OLD_PREAMBLE_SCRIPT="$TMP/check-board-headings-preamble-OLD.sh"
cat > "$OLD_PREAMBLE_SCRIPT" <<'OLDEOF'
#!/usr/bin/env bash
set -euo pipefail
BOARD="$1"
# OLD (pre-Major-fix) default-base candidate-selection preamble: bare `git`,
# resolved against the CALLER's cwd — never `-C`-scoped to the board file's
# own repo. This is the exact defect the Major fix closes.
candidate=""
if [ -n "${CHECK_BOARD_HEADINGS_BASE:-}" ] \
   && git rev-parse --verify --quiet "${CHECK_BOARD_HEADINGS_BASE}^{commit}" >/dev/null 2>&1; then
  candidate="$CHECK_BOARD_HEADINGS_BASE"
elif [ -n "${GITHUB_BASE_REF:-}" ] \
   && git rev-parse --verify --quiet "origin/${GITHUB_BASE_REF}^{commit}" >/dev/null 2>&1; then
  candidate="origin/${GITHUB_BASE_REF}"
elif git rev-parse --verify --quiet 'HEAD~1^{commit}' >/dev/null 2>&1; then
  candidate="HEAD~1"
fi
if [ -n "$candidate" ]; then
  printf 'candidate resolved (unexpected in this counterfactual): %s\n' "$candidate" >&2
  exit 1
else
  printf '%s: note: no resolvable base (first commit and no --base/--base-file/env default) — skipping the deletion/replacement (structural) check; the duplicate check still runs\n' "$BOARD" >&2
  exit 0
fi
OLDEOF
chmod +x "$OLD_PREAMBLE_SCRIPT"
set +e
(cd "$MAJOR_FOREIGN" && env -u CHECK_BOARD_HEADINGS_BASE -u GITHUB_BASE_REF bash "$OLD_PREAMBLE_SCRIPT" "$MAJOR_ABS_BOARD") >"$out" 2>"$err"
old_rc=$?
set -e
[[ "$old_rc" -eq 0 ]] || fail "Major counterfactual: expected the OLD (cwd-resolving) preamble to silently skip (exit 0) for this foreign-shallow-cwd invocation, got $old_rc (stderr: $(cat "$err"))"
grep -qi 'no resolvable base' "$err" || fail "Major counterfactual: OLD preamble stderr should report the 'no resolvable base' skip note (got: $(cat "$err"))"
pass "Major non-vacuous counterfactual — the OLD (cwd-resolving) preamble silently skips the structural check (exit 0, deletion missed) for the identical invocation the fixed preamble now resolves correctly (exit 1); self-contained inline fixture, no git-history/branch-name dependency"

# --- no-base: first commit (HEAD~1 absent), --base omitted -> skip, exit 0 ------
FIRSTROOT="$TMP/first-commit-repo"
mkdir -p "$FIRSTROOT"
(
  cd "$FIRSTROOT"
  git init -q -b main
  git config user.email t@example.invalid
  git config user.name t
  git config commit.gpgsign false
  cp "$FIX/base.md" todo.md
  git add todo.md
  git commit -qm "only commit"
)
set +e
(cd "$FIRSTROOT" && env -u CHECK_BOARD_HEADINGS_BASE -u GITHUB_BASE_REF bash "$SCRIPT" todo.md) >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "no-base (first commit) expected exit 0, got $rc (stderr: $(cat "$err"))"
grep -qi 'no resolvable base' "$err" || fail "no-base note expected on stderr (got: $(cat "$err"))"
pass "no-base — first commit (HEAD~1 absent), --base omitted => skip class-2 structural check, exit 0"

# Regression lock on the design decision: even when the structural (base)
# check is skipped for lack of a resolvable base, the intra-file duplicate
# check is base-independent and must still fail on a real duplicate.
(cd "$FIRSTROOT" && cp "$FIX/duplicate-head.md" todo.md)
set +e
(cd "$FIRSTROOT" && env -u CHECK_BOARD_HEADINGS_BASE -u GITHUB_BASE_REF bash "$SCRIPT" todo.md) >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "no-base duplicate expected non-zero exit even with base skipped, got 0"
grep -q 'duplicate' "$err" || fail "no-base duplicate stderr missing 'duplicate' (got: $(cat "$err"))"
pass "no-base — duplicate check still enforced even when the structural (base) check is skipped"

# --- T-101: usage() dynamic header range (no truncation on header growth) ------
# usage() used to be a FIXED `sed -n '2,45p' "$0"` range; the header
# comment block grew past line 45 (now L2-74) and --help silently truncated
# mid-header, dropping the Exit-code contract and the trailing
# `Read-only. Prints ...` line. usage() now derives the range dynamically
# (L1 shebang skip, print `#`-prefixed lines with the prefix stripped, stop
# at the first non-`#` line) so it always reaches the header's real end,
# however far it grows. This is the dynamic header range regression lock
# (AC5 anchor).
#
# Codex round1 review (Blocker): the first cut of this lock re-implemented
# the production awk logic INLINE in the test and ran it against a
# header-only synthetic file — it never invoked usage()/--help on the real
# script at all. A mutation test (reverting the real usage() to the OLD
# sed form) left every assertion green, i.e. the lock had zero
# regression-detection power. Fixed by making BOTH the fixed and
# counterfactual sides FULL, directly-executable copies of the real
# script (the same discipline every other "(fixed checker)" assertion in
# this file already follows: invoke `bash "$SCRIPT" ...` rather than
# re-implementing its logic) — GROWN_SCRIPT is the real script with its
# header extended by N lines plus a unique marker, run via
# `bash "$GROWN_SCRIPT" --help`; GROWN_SCRIPT_OLD is the SAME grown copy
# with ONLY its usage() body line swapped (via a self-contained frozen
# text splice, no git-ref dependency) to the OLD
# `sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'` form.
# `|| true` on both lookups: under `set -o pipefail`, a `grep`/awk pipeline
# that finds nothing exits non-zero, which — inside a command substitution
# assigned to a plain variable — still trips `errexit` and would kill the
# script BEFORE reaching the explicit `fail` guards below, silently
# discarding their diagnostic messages. Neutralizing that lets the guards
# below report a clear reason instead of an unexplained bare exit.
HEADER_END_LINE="$(awk 'NR==1{next} /^#/{next} {print NR; exit}' "$SCRIPT" || true)"
[ -n "$HEADER_END_LINE" ] || fail "T-101 setup: could not locate the real script's header end line"

# --- T-104 (issue #333): usage() exec-line detection — uniqueness + range ----
# find_unique_usage_exec_line() replaces the old "grep -n ... | head -1"
# first-match heuristic: it asserts the literal match count is EXACTLY 1 and
# that the matching line sits INSIDE usage()'s own body (between `^usage() {`
# and its closing `}`), instead of silently trusting whichever line comes
# first (which would misfire the moment the same literal appears twice — a
# header comment collision, say — and `head -1` picked the wrong one). Both
# the real T-101 setup below AND the mutation lock further down call this
# SAME helper (T-101 round1 lesson: a lock must exercise the real detection
# logic, not a re-implemented copy of it) — see DP-333a/DP-333b.
find_unique_usage_exec_line() {
  local script="$1" matches count lineno usage_start usage_end
  matches="$(grep -n "awk 'NR==1{next}" "$script" || true)"
  count="$(printf '%s\n' "$matches" | grep -c . || true)"
  if [ "$count" -ne 1 ]; then
    printf 'find_unique_usage_exec_line: expected exactly 1 match for the usage() awk exec literal in %s, got %s (usage() exec line uniqueness check failed)\n' "$script" "$count" >&2
    return 1
  fi
  lineno="$(printf '%s\n' "$matches" | cut -d: -f1)"
  usage_start="$(grep -n '^usage() {' "$script" | head -1 | cut -d: -f1)"
  if [ -z "$usage_start" ]; then
    printf 'find_unique_usage_exec_line: no usage() { found in %s\n' "$script" >&2
    return 1
  fi
  usage_end="$(awk -v start="$usage_start" 'NR>start && /^}/{print NR; exit}' "$script")"
  if [ -z "$usage_end" ]; then
    printf 'find_unique_usage_exec_line: no closing } found for usage() in %s\n' "$script" >&2
    return 1
  fi
  if [ "$lineno" -le "$usage_start" ] || [ "$lineno" -ge "$usage_end" ]; then
    printf 'find_unique_usage_exec_line: match at line %s is outside usage() range (%s-%s) in %s\n' "$lineno" "$usage_start" "$usage_end" "$script" >&2
    return 1
  fi
  printf '%s\n' "$lineno"
}

USAGE_EXEC_LINE="$(find_unique_usage_exec_line "$SCRIPT")" \
  || fail "T-101 setup: could not locate the real script's dynamic usage() exec line (usage() exec line uniqueness check failed)"
pass "usage() exec line uniqueness + usage()-range check: located the real script's dynamic usage() awk exec line via the shared helper"

grow_header() {
  # $1 = source script, $2 = destination path. Inserts 40 `#` comment
  # lines plus a unique marker line right before the header's own
  # terminating (first non-`#`) line, leaving every other line (including
  # the shebang and the entire rest of the script) untouched, so the
  # result stays a full, directly-executable copy of the source.
  awk -v ins="$HEADER_END_LINE" -v n=40 '
    NR==ins-1 {
      print
      for (i = 1; i <= n; i++) print "# injected header line " i
      print "# T-101-DYNAMIC-HEADER-RANGE-MARKER"
      next
    }
    { print }
  ' "$1" > "$2"
}

# OLD_FORM_SCRIPT: a full copy of the real script with ONLY the usage()
# exec line spliced (frozen text, no git-ref dependency) to the OLD fixed
# `sed -n '2,45p'` form; every other line (including the rest of usage()'s
# own comment block, arg parsing, extraction core) is untouched.
OLD_FORM_SCRIPT="$TMP/check-board-headings-old-usage-form.sh"
{
  sed -n "1,$((USAGE_EXEC_LINE - 1))p" "$SCRIPT"
  cat <<'OLDUSAGEEOF'
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
OLDUSAGEEOF
  sed -n "$((USAGE_EXEC_LINE + 1)),\$p" "$SCRIPT"
} > "$OLD_FORM_SCRIPT"

GROWN_SCRIPT="$TMP/check-board-headings-grown.sh"
GROWN_SCRIPT_OLD="$TMP/check-board-headings-grown-old-usage.sh"
grow_header "$SCRIPT" "$GROWN_SCRIPT"
grow_header "$OLD_FORM_SCRIPT" "$GROWN_SCRIPT_OLD"

grown_help_out="$(bash "$GROWN_SCRIPT" --help)"
printf '%s' "$grown_help_out" | grep -Fq 'T-101-DYNAMIC-HEADER-RANGE-MARKER' \
  || fail "T-101 dynamic header range: the real script (grown header, run via bash --help) should print the injected marker beyond the old 45-line boundary (got: $grown_help_out)"
pass "T-101 dynamic header range — the real script, with its header grown and invoked via bash \"\$GROWN_SCRIPT\" --help, prints through the injected marker line, no truncation"

grown_old_help_out="$(bash "$GROWN_SCRIPT_OLD" --help)"
printf '%s' "$grown_old_help_out" | grep -Fq 'T-101-DYNAMIC-HEADER-RANGE-MARKER' \
  && fail "T-101 counterfactual: expected the SAME grown copy with usage() swapped to the OLD fixed 'sed -n 2,45p' form to truncate BEFORE the injected marker, but it printed the marker (non-vacuous check broken)"
pass "T-101 non-vacuous counterfactual — the same grown copy, with ONLY usage() swapped to the OLD fixed 'sed -n 2,45p' form and invoked via bash --help, truncates before the injected marker; the fixed dynamic usage() above (GROWN_SCRIPT) correctly reaches it"

# --- T-104 (issue #333): non-vacuous mutation lock for the uniqueness check ---
# A full copy of the real script with the SAME awk literal duplicated into a
# header comment (outside usage()) must make find_unique_usage_exec_line
# FAIL (count==2, not the happy-path 1), proving the uniqueness assert has
# real regression-detection teeth. The old "grep -n ... | head -1" form would
# have silently picked the first (decoy) match instead — a vacuous check.
DUP_USAGE_LITERAL_SCRIPT="$TMP/check-board-headings-dup-usage-literal.sh"
{
  sed -n '1p' "$SCRIPT"
  printf '%s\n' "# duplicate usage() awk literal injected for T-104 mutation lock: awk 'NR==1{next} decoy"
  sed -n '2,$p' "$SCRIPT"
} > "$DUP_USAGE_LITERAL_SCRIPT"

set +e
dup_usage_err="$TMP/dup-usage-line-err"
dup_usage_line="$(find_unique_usage_exec_line "$DUP_USAGE_LITERAL_SCRIPT" 2>"$dup_usage_err")"
dup_usage_rc=$?
set -e
[ "$dup_usage_rc" -ne 0 ] || fail "duplicate usage() awk literal mutation lock: expected find_unique_usage_exec_line to reject the header-duplicated literal (non-vacuous), but it returned 0 (line $dup_usage_line)"
grep -Fq 'usage() exec line uniqueness check failed' "$dup_usage_err" || fail "duplicate usage() awk literal mutation lock: expected a uniqueness-failure diagnostic on stderr (got: $(cat "$dup_usage_err"))"
pass "duplicate usage() awk literal mutation lock: find_unique_usage_exec_line correctly rejects a synthetic full copy with the literal duplicated in the header (non-vacuous uniqueness check)"

# --- T-103 (issue #314): general section-boundary fallback normalization ------
# extract_ids_to_file's general fallback used to require a LITERAL
# hash-hash-SPACE (`/^## /`) to reset in_section — a tab-separated heading
# (`##\t...`) or a bare `##` (no text at all) never matched it, so a
# tab/bare section heading placed AFTER Active/Done left in_section=1 and
# over-extracted its checkbox-shaped contents as Active/Done membership
# (a false-duplicate, noise-direction defect — pre-existing, NOT a T-095
# regression: the frozen PRE_T103_AWK_PROG below is byte-identical to the
# extraction awk at merge-base develop/HEAD authoring time). Fixed by
# normalizing the fallback to `/^##([[:space:]]|$)/` (space OR end-of-line),
# which also matches tab (a member of `[[:space:]]`) and bare `##` while
# still NOT matching `###` (H3, 3rd char is `#`, neither whitespace nor EOL)
# or `##foo` (3rd char `f`) — no over-reset, no behavior change for the
# reachable H2 `## ` case. Each lock below is paired with a non-vacuous
# counterfactual against a frozen, self-contained, byte-verbatim copy of the
# PRE-T-103 (T-095-final) extract_ids_to_file awk (fence state machine +
# ATX-closing tolerance + the OLD literal `/^## /` fallback) — proving each
# fixture reproduces the real pre-existing defect, not a synthetic strawman
# (T-091 round1 Blocker lesson — no moving git ref, self-contained inline
# snippet only).
# shellcheck disable=SC2016  # single-quoted on purpose: this is the frozen
# awk program source (a literal string handed to `awk`), not a shell
# expansion.
PRE_T103_AWK_PROG='
    !in_fence {
      if (match($0, /^[ ]{0,3}`{3,}/)) {
        fence_run = substr($0, RSTART, RLENGTH)
        gsub(/^[ ]+/, "", fence_run)
        fence_len = length(fence_run)
        in_fence = 1
        next
      }
    }
    in_fence {
      close_pat = "^[ ]{0,3}`{" fence_len ",}[[:space:]]*$"
      if ($0 ~ close_pat) { in_fence = 0 }
      next
    }
    /^## Active([[:space:]]+#+)?[[:space:]]*$/ { in_section=1; next }
    /^## Done([[:space:]]+#+)?[[:space:]]*$/   { in_section=1; next }
    /^## / { in_section=0; next }
    !in_section { next }
    /^[[:space:]]+-/ { next }
    /^- \[[x ]\] (\*\*)?T-[0-9]+(\*\*)? / {
      if (match($0, /T-[0-9]+/)) print substr($0, RSTART, RLENGTH)
    }
'
pre_t103_extract() { awk "$PRE_T103_AWK_PROG" "$1"; }

# AC1 (tab-separated section heading, positive, non-vacuous lock): Active
# keeps T-101/T-102 and Done keeps T-050 (unchanged from base), plus a
# `##\tReserved` (tab-separated) section is appended with a T-102 lookalike
# checkbox line. The FIXED checker must reset in_section on the tab heading
# and not extract the lookalike, so head's Active/Done membership equals
# base's (exit 0, no false-duplicate).
run_check "$FIX/section-tab-separated-head.md" --base-file "$FIX/section-tab-separated-base.md"
[[ "$rc" -eq 0 ]] || fail "section-tab-separated fixture (fixed checker) expected exit 0 (tab-separated section heading resets in_section, no over-extraction of the T-102 lookalike), got $rc (stderr: $(cat "$err"))"
pass "AC1 section-tab-separated (fixed checker) — exit 0, tab-separated '##\\tReserved' heading resets in_section, no over-extraction"

pre_t103_extract "$FIX/section-tab-separated-head.md" > "$TMP/pre-t103-tab-head-raw"
pre_t103_tab_dupes="$(sort "$TMP/pre-t103-tab-head-raw" | uniq -d)"
[[ -n "$pre_t103_tab_dupes" ]] || fail "AC1 counterfactual: expected the PRE-T103 (literal '/^## /' fallback) awk to phantom-duplicate T-102 via the unreset tab-separated section (got no duplicates: $(cat "$TMP/pre-t103-tab-head-raw"))"
printf '%s' "$pre_t103_tab_dupes" | grep -Fq 'T-102' || fail "AC1 counterfactual: expected PRE-T103 duplicate set to include T-102 (got: $pre_t103_tab_dupes)"
pass "AC1 non-vacuous counterfactual — PRE-T103 (literal '/^## /', no tab match) awk fails to reset in_section on '##\\tReserved' and phantom-duplicates T-102 (a false-duplicate would fire); the fixed checker above correctly suppresses it"

# AC2 (bare `##` section heading, positive, non-vacuous lock): Active keeps
# T-201/T-202 and Done keeps T-060 (unchanged from base), plus a bare `##`
# (no heading text) section is appended with a T-202 lookalike checkbox
# line. The FIXED checker must reset in_section on the bare heading and not
# extract the lookalike (exit 0, no false-duplicate).
run_check "$FIX/section-bare-empty-head.md" --base-file "$FIX/section-bare-empty-base.md"
[[ "$rc" -eq 0 ]] || fail "section-bare-empty fixture (fixed checker) expected exit 0 (bare '##' section heading resets in_section, no over-extraction of the T-202 lookalike), got $rc (stderr: $(cat "$err"))"
pass "AC2 section-bare-empty (fixed checker) — exit 0, bare '##' heading resets in_section, no over-extraction"

pre_t103_extract "$FIX/section-bare-empty-head.md" > "$TMP/pre-t103-bare-head-raw"
pre_t103_bare_dupes="$(sort "$TMP/pre-t103-bare-head-raw" | uniq -d)"
[[ -n "$pre_t103_bare_dupes" ]] || fail "AC2 counterfactual: expected the PRE-T103 (literal '/^## /' fallback) awk to phantom-duplicate T-202 via the unreset bare '##' section (got no duplicates: $(cat "$TMP/pre-t103-bare-head-raw"))"
printf '%s' "$pre_t103_bare_dupes" | grep -Fq 'T-202' || fail "AC2 counterfactual: expected PRE-T103 duplicate set to include T-202 (got: $pre_t103_bare_dupes)"
pass "AC2 non-vacuous counterfactual — PRE-T103 (literal '/^## /', no bare-hash match) awk fails to reset in_section on the bare '##' heading and phantom-duplicates T-202 (a false-duplicate would fire); the fixed checker above correctly suppresses it"

printf 'OK\n'
exit 0
