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

# =============================================================================
# The real population, re-derived here (never inherited from a caller):
# `git ls-files -s -- bin/`. Empty/unavailable output fails closed (DP2).
# =============================================================================
printf '\n--- rule: every tracked bin/ entry is index mode 100755 (population source: git ls-files -s) ---\n'
POP="$(git -C "$REPO_ROOT" ls-files -s -- bin/ 2>/dev/null || true)"
if [ -z "$POP" ]; then
  fail "population source: git ls-files -s -- bin/ produced empty/unavailable output — fails closed, never read as a clean zero-violation result"
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

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'bin-exec-bit suite: all assertions passed\n'
  exit 0
else
  printf 'bin-exec-bit suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
