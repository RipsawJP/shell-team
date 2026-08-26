#!/usr/bin/env bash
# extract-recipe.sh — T-1098: extract the trial-adoption recipe's command
# lines from a shipped doc (docs/adopting.md or docs/adopting.ja.md) rather
# than retyping them, so tests/trial-recipe/run.sh never verifies a
# transcribed fiction of the recipe instead of the recipe itself.
#
# Fail-closed contract: a heading that does not match, a fence count other
# than the shipped one, a block shorter than its documented floor, or a
# prose flag-span or remedy span that is not found exactly once is an error
# with a diagnosis on stderr and NOTHING on stdout — never a silent
# zero-command pass.
#
# Usage: extract-recipe.sh <doc-path> setup|teardown|flag|remedy

set -euo pipefail

PROG="extract-recipe"
die() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 1; }

[ "$#" -eq 2 ] || die "usage: extract-recipe.sh <doc-path> setup|teardown|flag|remedy"
DOC="$1"
MODE="$2"

case "$MODE" in
  setup|teardown|flag|remedy) ;;
  *) die "unknown mode: $MODE (expected setup|teardown|flag|remedy)" ;;
esac

[ -f "$DOC" ] || die "no such file: $DOC"
[ -s "$DOC" ] || die "empty file: $DOC"

# The two headings this extractor recognizes as the trial-adoption section's
# own anchor, one per shipped language mirror (docs/adopting.md,
# docs/adopting.ja.md). A doc whose heading text has drifted away from both
# fails closed rather than guessing which section is meant.
HEAD_EN='## Trying the team on one ticket'
HEAD_JA='## 1 チケットでチームを試す'

# Whole-document line-count FLOORS (never ceilings) for the two shipped
# mirrors, at the shape this extractor was built to trust. A document that
# has SHRUNK below its own shipped floor anywhere — not merely inside the
# trial-adoption section — is treated as "the shipped document has moved"
# (Input space class 7) and extraction refuses rather than guessing which
# part of it is still trustworthy; this is what actually catches a stray
# deletion earlier in the file that a section-scoped read alone would never
# see. Growth is never penalized: an unrelated addition elsewhere in either
# doc must not break this lock.
FLOOR_LINES_EN=641
FLOOR_LINES_JA=611

# Determine which mirror's heading is present BEFORE extracting the section
# body, so the floor check below can select the right language's constant.
lang=""
if grep -qxF -- "$HEAD_EN" "$DOC"; then
  lang="en"
  matched_heading="$HEAD_EN"
elif grep -qxF -- "$HEAD_JA" "$DOC"; then
  lang="ja"
  matched_heading="$HEAD_JA"
else
  die "no recognized trial-adoption section heading found in $DOC (expected '$HEAD_EN' or '$HEAD_JA')"
fi

section="$(awk -v h="$matched_heading" '
  $0 == h { s = 1; next }
  s && /^## / { exit }
  s { print }
' "$DOC")"

[ -n "$section" ] || die "trial-adoption section body is empty in $DOC"

case "$lang" in
  en) floor="$FLOOR_LINES_EN" ;;
  ja) floor="$FLOOR_LINES_JA" ;;
  *)  die "internal error: unrecognized language marker '$lang'" ;;
esac
doc_lines="$(wc -l < "$DOC" | tr -d ' ')"
[ "$doc_lines" -ge "$floor" ] || die "document shorter than its documented floor (whole-file lines >= $floor for '$lang', found $doc_lines) — the shipped document has moved"

# Three literal backtick characters — the fence delimiter this extractor
# scans for, built via printf rather than typed so no editor can silently
# collapse or re-encode it.
BT=$(printf '\140\140\140')

# Coarse completeness floor on the section itself: the shipped section
# carries well over ten non-blank lines. A doc gutted down to a bare heading
# still "matches" the awk scan above and must not pass as a zero-command
# extraction.
sec_lines="$(printf '%s\n' "$section" | grep -c . || true)"
[ "$sec_lines" -ge 10 ] || die "trial-adoption section shorter than its documented floor (>=10 non-blank lines, found $sec_lines)"

# Fence count within the section: the shipped section carries exactly two
# fenced blocks (setup, teardown) = four delimiter lines. Any other count —
# a deleted delimiter, an inserted one, an unterminated fence — is an error
# rather than a guess at which lines belong to which block.
fence_count="$(printf '%s\n' "$section" | awk -v f="$BT" 'index($0, f) == 1 { c++ } END { print c + 0 }')"
[ "$fence_count" -eq 4 ] || die "fence count in the trial-adoption section differs from the shipped shape (expected 4, found $fence_count)"

# extract_fence_pair N — print the body lines of the Nth fenced block
# (1-based) within $section. N=1 is the setup fence, N=2 is teardown.
extract_fence_pair() {
  local n="$1"
  printf '%s\n' "$section" | awk -v f="$BT" -v n="$n" '
    index($0, f) == 1 {
      c++
      if (c == 2*n - 1) { infence = 1; next }
      if (c == 2*n)     { exit }
      next
    }
    infence { print }
  '
}

case "$MODE" in
  setup)
    body="$(extract_fence_pair 1)"
    lines="$(printf '%s\n' "$body" | grep -c . || true)"
    [ "$lines" -ge 4 ] || die "setup block shorter than its documented floor (>=4 command lines, found $lines)"
    printf '%s\n' "$body"
    ;;
  teardown)
    body="$(extract_fence_pair 2)"
    lines="$(printf '%s\n' "$body" | grep -c . || true)"
    [ "$lines" -ge 2 ] || die "teardown block shorter than its documented floor (>=2 command lines, found $lines)"
    printf '%s\n' "$body"
    ;;
  flag)
    # The flag-span is the INVOCATION-FORM string, not the bare token: the
    # section's own intro paragraph mentions `--trial-branch` descriptively
    # before the one-step variant introduces the actual invocation, and that
    # descriptive mention must never be mistaken for an extraction target.
    span='team-init.sh --trial-branch '
    matches="$(printf '%s\n' "$section" | grep -cF -- "$span" || true)"
    [ "$matches" -eq 1 ] || die "invocation-form span '$span' not found exactly once in the section (found $matches)"
    printf '%s\n' "$section" | grep -F -- "$span"
    ;;
  remedy)
    # The global-excludes remedy — the section's own prose-embedded
    # `git add -f "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"`
    # sentence — is extracted the same way the flag invocation is: located
    # by a distinctive span, required exactly once, never retyped. The span
    # is the FULL two-argument invocation, not merely the `git add -f `
    # prefix, precisely so that dropping the second (specs) argument —
    # requirement 3's own named regression — makes this span vanish too;
    # a prefix-only span would keep matching a one-argument remedy and
    # silently re-extract a weakened form. Any regression that removes
    # `-f`, drops an argument, or rewords the sentence away must make this
    # mode refuse rather than silently keep returning the last-known-good
    # text.
    # shellcheck disable=SC2016
    span='git add -f "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"'
    matches="$(printf '%s\n' "$section" | grep -cF -- "$span" || true)"
    [ "$matches" -eq 1 ] || die "remedy span not found exactly once in the section (found $matches)"
    printf '%s\n' "$section" | grep -F -- "$span"
    ;;
esac
