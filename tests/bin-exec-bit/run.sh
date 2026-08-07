#!/usr/bin/env bash
# run.sh — lock suite proving every tracked file under bin/ ships at git
# index mode 100755 (T-1034; GitHub issue #138's mechanisation half; the
# T-1028 round-1 Blocker whose invisibility mechanism was that every
# mechanical caller in this repository invokes bin/ scripts as `bash bin/…`
# while the documented bare-name/PATH loop caller does not — a cross-provider
# reviewer found the missing exec bit by hand, and no machine check noticed).
#
# Structure mirrors tests/gitignore-raw-dumps/run.sh (a lock over a property
# that already holds, with its own inline non-vacuity controls) applied to
# the git index mode instead of .gitignore behavior.
#
# Rule (DP2/DP3): judged by `git ls-files -s -- bin/` (index mode), NEVER a
# working-tree `test -x` probe — a checkout under `core.fileMode=false` would
# lie, and the index is what actually ships. Coverage is a rule over the
# MEASURED population (every tracked bin/ entry), never a `bin/*.sh` glob,
# which would silently miss the extension-less `bin/install` — named here as
# the required positive control (DP3). Any mode other than 100755 fails,
# including a symlink (120000) or a gitlink (160000) — introducing one is a
# design decision that needs a spec of its own, not something this lock
# accommodates. Empty or unavailable `git` output fails closed, never a
# clean zero-violation result.
#
# This lock has NO adopter-facing surface (DP1/DP4): it is this repository's
# own suite, reached by one CI step, never a new bin/ script or a
# close-out.sh gate — close-out runs inside adopter repositories, which have
# no bin/ of ours at all.
#
# Two frozen non-vacuity controls (DP5), following tests/errexit-safe/run.sh's
# inline-mutation idiom rather than adding a CLI surface: the rule is applied
# to two SYNTHETIC mode listings this suite builds itself (one carrying a
# 100644 member, one empty) so a rule that could never go red, and a
# zero-subject population that reads "clean", cannot ship as decoration.
#
# T-1044 (GitHub issue #160): a second, BIDIRECTIONAL rule extends this same
# suite to cover `tests/`, in place — never a rename, never a new suite
# (DP4), because a T-1037-class exec-bit drop under `tests/` is exactly as
# silent as one under `bin/` (overturned premise 1: zero committed fixtures
# direct-execute a `tests/*/run.sh`, and the PATH-shim fixtures self-heal
# with their own `chmod +x`). Judged by `git ls-files -s -- tests/` (index
# mode AND index blob content, via `git cat-file blob`, never a working-tree
# read — DP2): a tracked tests/ entry's committed blob begins `#!` IF AND
# ONLY IF its index mode is 100755. Coverage is the MEASURED population,
# never a `tests/*/run.sh` glob, which would silently miss
# `tests/retro-inputs/invariants.sh` and the extension-less PATH shim
# `tests/discover-work/fixtures/gh` — both named here as required positive
# controls (DP2). Any mode other than 100644/100755 is a violation. Empty or
# unavailable `git` output fails closed, the same as the bin/ rule above.
# Three more frozen non-vacuity controls (DP4) prove the rule can go red in
# EITHER direction and refuses a zero-subject population.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# count_non_100755 <listing> — <listing> is a git-ls-files-s-shaped text,
# one "<mode> <sha> <stage><TAB><path>" line per entry. Prints the count of
# lines whose mode field is NOT 100755, or the literal string "EMPTY" if the
# listing itself has no content at all (empty/unavailable population, DP2 —
# never read as a clean zero-violation result by any caller of this helper).
count_non_100755() {
  local listing="$1"
  if [ -z "$listing" ]; then
    printf 'EMPTY\n'
    return
  fi
  printf '%s\n' "$listing" | grep -vcE '^100755 ' || true
}

# count_tests_violations <listing> — <listing> is a git-ls-files-s-shaped
# text, one "<mode> <sha> <stage><TAB><path>" line per entry. Prints the
# count of lines that violate the BIDIRECTIONAL rule (a shebang-carrying
# blob at a mode other than 100755, a 100755-mode entry whose blob does not
# begin `#!`, or any mode other than 100644/100755), reading both the mode
# and the blob's own first two bytes from the index (`git cat-file blob`,
# never a working-tree read) — or the literal string "EMPTY" if the listing
# itself has no content at all (DP2 — never read as a clean zero-violation
# result by any caller of this helper).
count_tests_violations() {
  local listing="$1"
  if [ -z "$listing" ]; then
    printf 'EMPTY\n'
    return
  fi
  local bad=0 line mode rest sha two
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    mode="${line%% *}"
    rest="${line#* }"
    sha="${rest%%[[:space:]]*}"
    case "$mode" in
      100644 | 100755) ;;
      *)
        bad=$((bad + 1))
        continue
        ;;
    esac
    two="$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null | head -c 2)"
    if [ "$two" = '#!' ]; then
      [ "$mode" = "100755" ] || bad=$((bad + 1))
    else
      [ "$mode" = "100644" ] || bad=$((bad + 1))
    fi
  done <<<"$listing"
  printf '%s\n' "$bad"
}

# =============================================================================
# The real population, re-derived here (never inherited from a caller):
# `git ls-files -s -- bin/`. Empty/unavailable output fails closed (DP2).
#
# T-1034 rework round 1 (Codex round-1 Major 1): the exit status is captured
# explicitly, the same idiom bin/check-refreeze-class.sh's DP9 `cmp_rc`
# capture already uses — a bare `|| true` here discarded git's own exit
# status and judged the population solely by whether stdout was non-empty,
# so a `git` that printed a plausible (even fully clean) listing and then
# exited non-zero read as a valid, passing population instead of failing
# closed.
# =============================================================================
printf '\n--- rule: every tracked bin/ entry is index mode 100755 (population source: git ls-files -s) ---\n'
git_rc=0
POP="$(git -C "$REPO_ROOT" ls-files -s -- bin/ 2>/dev/null)" || git_rc=$?
if [ "$git_rc" -ne 0 ] || [ -z "$POP" ]; then
  fail "population source: git ls-files -s -- bin/ produced empty/unavailable output or exited non-zero (rc=$git_rc) — fails closed, never read as a clean zero-violation result"
else
  n_total="$(printf '%s\n' "$POP" | grep -c . || true)"
  n_bad="$(count_non_100755 "$POP")"
  if [ "$n_bad" = "0" ]; then
    pass "rule: every one of $n_total tracked entries under bin/ (population source: git ls-files -s) reports mode 100755"
  else
    fail "rule: $n_bad of $n_total tracked entries under bin/ do NOT report mode 100755"
  fi

  if printf '%s\n' "$POP" | grep -qE '^100755 [0-9a-f]+ 0[[:space:]]+bin/install$'; then
    pass "positive control: bin/install (the one entry a bin/*.sh glob would miss) is present in the measured population, at 100755"
  else
    fail "positive control: bin/install is NOT present in the measured population at 100755"
  fi
fi

# =============================================================================
# The tests/ population (T-1044, DP2), re-derived here (never inherited from
# a caller): `git ls-files -s -- tests/`. The exit status is captured
# explicitly (the same idiom as the bin/ population above), and empty or
# unavailable output fails closed rather than reading as a clean
# zero-violation result. Both directions of the rule are judged together by
# count_tests_violations, which reads the index mode AND the index blob's
# own first two bytes — never a working-tree test -x or a working-tree read.
# =============================================================================
printf '\n--- rule: every tracked tests/ entry is index mode 100755 IFF its blob begins #! (population source: git ls-files -s -- tests/) ---\n'
tests_git_rc=0
TESTS_POP="$(git -C "$REPO_ROOT" ls-files -s -- tests/ 2>/dev/null)" || tests_git_rc=$?
if [ "$tests_git_rc" -ne 0 ] || [ -z "$TESTS_POP" ]; then
  fail "population source: git ls-files -s -- tests/ produced empty/unavailable output or exited non-zero (rc=$tests_git_rc) — fails closed, never read as a clean zero-violation result"
else
  tests_n_total="$(printf '%s\n' "$TESTS_POP" | grep -c . || true)"
  tests_n_bad="$(count_tests_violations "$TESTS_POP")"
  if [ "$tests_n_bad" = "0" ]; then
    pass "rule: every one of $tests_n_total tracked entries under tests/ (population source: git ls-files -s -- tests/) has mode 100755 iff its blob begins #!"
  else
    fail "rule: $tests_n_bad of $tests_n_total tracked entries under tests/ violate the bidirectional shebang/100755 rule"
  fi

  if printf '%s\n' "$TESTS_POP" | grep -qE '^100755 [0-9a-f]+ 0[[:space:]]+tests/retro-inputs/invariants\.sh$'; then
    pass "positive control: tests/retro-inputs/invariants.sh (an entry a tests/*/run.sh glob would miss) is present in the measured population, at 100755"
  else
    fail "positive control: tests/retro-inputs/invariants.sh is NOT present in the measured population at 100755"
  fi

  if printf '%s\n' "$TESTS_POP" | grep -qE '^100755 [0-9a-f]+ 0[[:space:]]+tests/discover-work/fixtures/gh$'; then
    pass "positive control: tests/discover-work/fixtures/gh (an extension-less PATH shim a tests/*/run.sh glob would miss) is present in the measured population, at 100755"
  else
    fail "positive control: tests/discover-work/fixtures/gh is NOT present in the measured population at 100755"
  fi
fi

# =============================================================================
# control: a 100644 member is rejected (DP5) — a synthetic listing this
# suite builds itself, carrying one violating (100644) entry, proves the
# rule can actually go red rather than always reading clean.
# =============================================================================
printf '\n--- non-vacuity controls (DP5) ---\n'
SYN_VIOLATION=$'100755 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 0\tbin/a-clean.sh\n100644 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 0\tbin/b-violating.sh'
n_bad="$(count_non_100755 "$SYN_VIOLATION")"
if [ "$n_bad" != "EMPTY" ] && [ "$n_bad" -ge 1 ]; then
  pass "control: a 100644 member is rejected (the rule applied to a synthetic listing carrying one 100644 entry reports $n_bad violation(s), not zero)"
else
  fail "control: a 100644 member is rejected — the rule did NOT flag a synthetic listing's 100644 entry (n_bad=$n_bad); this lock could pass while measuring nothing"
fi

# =============================================================================
# control: an empty population is rejected (DP5) — a zero-subject listing
# must not read as "clean"; it must fail closed the same way an unavailable
# `git` output does.
# =============================================================================
n_bad="$(count_non_100755 "")"
if [ "$n_bad" = "EMPTY" ]; then
  pass "control: an empty population is rejected (a zero-subject synthetic listing is treated as fail-closed, never a clean zero-violation result)"
else
  fail "control: an empty population is rejected — an empty synthetic listing was NOT treated as fail-closed (got: $n_bad)"
fi

# =============================================================================
# Three frozen non-vacuity controls for the tests/ rule (T-1044, DP4). Real,
# already-tracked blob shas are read live (never hardcoded literals) so a
# future content edit to either reference file cannot silently make a
# control vacuous: SHEBANG_SHA names a blob that begins `#!`,
# NO_SHEBANG_SHA names one that does not.
# =============================================================================
printf '\n--- non-vacuity controls (DP4) ---\n'
SHEBANG_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD:tests/bin-exec-bit/run.sh)"
NO_SHEBANG_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD:.shell-team/test-recipe.md)"

SYN_TESTS_SHEBANG_100644=$'100644 '"$SHEBANG_SHA"$' 0\ttests/synthetic-shebang-at-100644.sh'
tests_n_bad="$(count_tests_violations "$SYN_TESTS_SHEBANG_100644")"
if [ "$tests_n_bad" != "EMPTY" ] && [ "$tests_n_bad" -ge 1 ]; then
  pass "control: a shebang-carrying 100644 member is rejected (the rule applied to a synthetic listing carrying one shebang-blob-at-100644 entry reports $tests_n_bad violation(s), not zero)"
else
  fail "control: a shebang-carrying 100644 member is rejected — the rule did NOT flag a synthetic listing's shebang-at-100644 entry (n_bad=$tests_n_bad); this lock could pass while measuring nothing"
fi

SYN_TESTS_NOSHEBANG_100755=$'100755 '"$NO_SHEBANG_SHA"$' 0\ttests/synthetic-no-shebang-at-100755.md'
tests_n_bad="$(count_tests_violations "$SYN_TESTS_NOSHEBANG_100755")"
if [ "$tests_n_bad" != "EMPTY" ] && [ "$tests_n_bad" -ge 1 ]; then
  pass "control: an executable member with no shebang is rejected (the rule applied to a synthetic listing carrying one no-shebang-blob-at-100755 entry reports $tests_n_bad violation(s), not zero)"
else
  fail "control: an executable member with no shebang is rejected — the rule did NOT flag a synthetic listing's no-shebang-at-100755 entry (n_bad=$tests_n_bad); this lock could pass while measuring nothing"
fi

tests_n_bad="$(count_tests_violations "")"
if [ "$tests_n_bad" = "EMPTY" ]; then
  pass "control: an empty tests/ population is rejected (a zero-subject synthetic listing is treated as fail-closed, never a clean zero-violation result)"
else
  fail "control: an empty tests/ population is rejected — an empty synthetic listing was NOT treated as fail-closed (got: $tests_n_bad)"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'bin-exec-bit suite: all assertions passed\n'
  exit 0
else
  printf 'bin-exec-bit suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
