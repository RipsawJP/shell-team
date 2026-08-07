#!/usr/bin/env bash
# run.sh — lock suite proving no tracked file under tests/ builds a scratch
# root at a fixed, guessable path (T-1044; GitHub issue #160's retro
# fast-follow / 2026-08-06 retro lesson 6: a QA double-run of the same suite
# collided because two concurrent runs shared one fixed-name scratch root).
#
# Structure mirrors tests/bin-exec-bit/run.sh (a lock over a property that
# already holds, with its own inline non-vacuity controls) applied to
# scratch-root SOURCE SHAPE instead of git index mode.
#
# Rule (DP8): for every tracked file under tests/, no line that is not a
# full-line comment matches either frozen signature below without also
# containing `mktemp`. The two signatures are frozen in
# .shell-team/specs/T-1044-test-infra-bundle.md's FSR block — one
# definition, two consumers — reproduced here byte-identically as whole
# lines so this suite and that spec cannot drift apart (AC9).
#
# This is a SHAPE LINT, not a dataflow analysis (DP8's declared reach,
# `## Input space`): it catches the two written styles this corpus actually
# used ($HERE/tmp… and a literal ${TMPDIR}/<name>), never a fixed root
# assembled through a helper function, a printf, or an array element — a
# third style is a new finding, not a defect in this lock. FSR_TMPDIR
# requires a LITERAL first path component after `}/`, so a counterfactual
# that computes a fixed name from a shell variable purely to compare two
# strings (tests/check-intent/run.sh:821-822, tests/check-provenance/
# run.sh:665-666 — `"${TMPDIR:-/tmp}/${FIXED_NAME_STANDIN}"`) correctly does
# NOT match: neither site ever creates that path.
#
# Unlike tests/bin-exec-bit/run.sh's DP2 rule (index-read, because a
# core.fileMode=false working tree lies about MODE), this lock reads the
# WORKING TREE (DP8): its subject is file CONTENT a developer is about to
# commit, and no mechanism makes a working tree lie about content.
#
# Full-line comments are excluded (a converted suite may still describe the
# shape it used to have), and any line containing `mktemp` is excluded (the
# compliant two-arm idiom's own $HERE-fallback line still reads
# `$HERE/tmp…`, wrapped in `mktemp -d`). Empty/unavailable `git` output
# fails closed, never a clean zero-violation result.
#
# Four frozen non-vacuity controls (DP8), following tests/bin-exec-bit/
# run.sh's inline-mutation idiom rather than adding a CLI surface: the rule
# is applied to synthetic lines this suite builds itself. The two
# "rejected" controls are assembled at RUN TIME from separate pieces (never
# written as one contiguous matching line in this file's own source) so
# this suite's own source text never trips the rule it is proving —
# self-hosting, since this file is itself a tracked file under tests/.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# Frozen signatures (T-1044 DP8 / spec's FSR block) — one definition, two
# consumers. Byte-identical to the spec, checked whole-line by AC9.
# shellcheck disable=SC2016  # single-quoted on purpose: these are regex text, not expansions
FSR_HERE='"\$HERE/tmp'
FSR_TMPDIR='^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*="\$\{TMPDIR[^"]*\}/[A-Za-z0-9._-]'

# count_scratch_violations <listing> — <listing> is a text blob, one
# candidate source line per input line. Prints the count of lines that are
# NOT full-line comments, match either frozen signature above, and do NOT
# also contain the substring "mktemp" — or the literal string "EMPTY" if
# the listing itself has no content at all (empty/unavailable population,
# fail-closed — never read as a clean zero-violation result by any caller
# of this helper).
count_scratch_violations() {
  local listing="$1"
  if [ -z "$listing" ]; then
    printf 'EMPTY\n'
    return
  fi
  printf '%s\n' "$listing" \
    | grep -vE '^[[:space:]]*#' \
    | grep -E -- "$FSR_HERE|$FSR_TMPDIR" \
    | grep -vc 'mktemp' || true
}

# =============================================================================
# The real population, re-derived here (never inherited from a caller):
# every tracked file under tests/, read from the WORKING TREE (DP8 — never
# `git show <ref>:<path>`, since the subject is content a developer is about
# to commit). Empty/unavailable `git` output fails closed.
# =============================================================================
printf '\n--- rule: no tracked tests/ file has a fixed scratch root without mktemp (population source: git ls-files -- tests/, working tree read) ---\n'
git_rc=0
POP_FILES="$(git -C "$REPO_ROOT" ls-files -- tests/ 2>/dev/null)" || git_rc=$?
if [ "$git_rc" -ne 0 ] || [ -z "$POP_FILES" ]; then
  fail "population source: git ls-files -- tests/ produced empty/unavailable output or exited non-zero (rc=$git_rc) — fails closed, never read as a clean zero-violation result"
else
  n_total=0
  n_bad=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    n_total=$((n_total + 1))
    f="$REPO_ROOT/$rel"
    [ -r "$f" ] || continue
    content="$(cat "$f" 2>/dev/null)" || true
    c="$(count_scratch_violations "$content")"
    [ "$c" = "EMPTY" ] && c=0
    n_bad=$((n_bad + c))
  done <<<"$POP_FILES"

  if [ "$n_bad" -eq 0 ]; then
    pass "rule: none of $n_total tracked files under tests/ (population source: git ls-files -- tests/, working tree read) has a fixed scratch root without mktemp"
  else
    fail "rule: $n_bad line(s) across the $n_total tracked files under tests/ violate the fixed-scratch-root shape lint"
  fi
fi

# =============================================================================
# Four frozen non-vacuity controls (DP8). The two "rejected" synthetic lines
# are assembled at run time from separated pieces (a literal '$' supplied as
# a SEPARATE printf argument) so this file's OWN source never contains the
# contiguous matching text it is proving the rule catches.
# =============================================================================
printf '\n--- non-vacuity controls (DP8) ---\n'

SYN_HERE_LINE="$(printf 'TMP="%sHERE/tmp-fixed-example"' '$')"
n_bad="$(count_scratch_violations "$SYN_HERE_LINE")"
if [ "$n_bad" != "EMPTY" ] && [ "$n_bad" -ge 1 ]; then
  pass "control: a fixed \$HERE scratch root is rejected (the rule applied to a synthetic \$HERE/tmp… line reports $n_bad violation(s), not zero)"
else
  fail "control: a fixed \$HERE scratch root is rejected — the rule did NOT flag a synthetic \$HERE/tmp… line (n_bad=$n_bad); this lock could pass while measuring nothing"
fi

SYN_TMPDIR_LINE="$(printf 'TMP="%s{TMPDIR%%/}/fixed-example-roots"' '$')"
n_bad="$(count_scratch_violations "$SYN_TMPDIR_LINE")"
if [ "$n_bad" != "EMPTY" ] && [ "$n_bad" -ge 1 ]; then
  pass "control: a fixed \${TMPDIR} scratch root is rejected (the rule applied to a synthetic \${TMPDIR}-literal line reports $n_bad violation(s), not zero)"
else
  fail "control: a fixed \${TMPDIR} scratch root is rejected — the rule did NOT flag a synthetic \${TMPDIR}-literal line (n_bad=$n_bad)"
fi

# This one legitimately contains "mktemp" in its own source, so it is
# excluded from the population sweep above by the same rule it exercises —
# no obfuscation needed.
# shellcheck disable=SC2016  # single-quoted on purpose: literal example source text, not an expansion
SYN_MKTEMP_LINE='TMP="$(mktemp -d "${TMPDIR%/}/fixed-example-roots.XXXXXX")"'
n_bad="$(count_scratch_violations "$SYN_MKTEMP_LINE")"
if [ "$n_bad" = "0" ]; then
  pass "control: an mktemp XXXXXX assignment is accepted (the rule applied to a synthetic mktemp-wrapped line reports zero violations)"
else
  fail "control: an mktemp XXXXXX assignment is accepted — the rule incorrectly flagged a synthetic mktemp-wrapped line (n_bad=$n_bad)"
fi

n_bad="$(count_scratch_violations "")"
if [ "$n_bad" = "EMPTY" ]; then
  pass "control: an empty tests/ population is rejected (a zero-subject synthetic listing is treated as fail-closed, never a clean zero-violation result)"
else
  fail "control: an empty tests/ population is rejected — an empty synthetic listing was NOT treated as fail-closed (got: $n_bad)"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'scratch-root-hygiene suite: all assertions passed\n'
  exit 0
else
  printf 'scratch-root-hygiene suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
