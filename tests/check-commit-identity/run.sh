#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-commit-identity.sh (T-112, GitHub issue
# #6 Layer 1 item 1; docs/specs/T-112-commit-identity-and-ignore-lock.md).
#
# No mailbox-shaped literal enters this tree (spec AC15): every non-noreply
# (real-shaped) address used below is synthetic and assembled at runtime from
# fragments, built inside throwaway git repositories under mktemp — never
# written here as a completed literal. The conformant "+login" noreply form
# and the plain GitHub web-flow noreply identity are the one documented,
# non-PII, GitHub-recognized exception (same convention T-111's own suite
# uses): they carry no shape to fragment, since they are the very forms this
# checker is designed to allow.
#
# identities are assembled at runtime from fragments.
#
# Covers, in order:
#   - exit-code contract (0/1/2, including an unresolvable base ref, a
#     missing --base, an unknown flag, and a path that is not a git
#     repository)
#   - range: non-merge commits from the merge-base to HEAD (AC4) — a
#     pre-existing bad-identity commit AT the merge-base is never inspected
#   - POS/NEG pair: author-identity (AC5)
#   - POS/NEG pair: committer-identity (AC6)
#   - disposition: merge commits are excluded from the range (AC7)
#   - disposition: web-flow committer identity is allowed (AC8)
#   - disposition: web-flow identity is NOT allowed on the author side (AC9)
#   - anchor: lookalike noreply domain is a finding (AC10), both sides
#   - empty range is clean (AC11)
#   - mutation: identity pattern is load-bearing (AC12, vacuity guard /
#     detector side) — neutralising the allowed-identity rule in a throwaway
#     copy makes the already-established positive fixtures report nothing
#   - meta: neutralised positive fixture makes the assertion FAIL (AC13,
#     vacuity guard / fixture side)
#   - no-leak: finding output never echoes the identity value (AC14)
#
# Temp roots live under $TMPDIR (2026-07-06 lesson: bare macOS mktemp can
# ignore /tmp in a sandbox); no process substitution (2026-07-06 lesson).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin/check-commit-identity.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-commit-identity-suite.XXXXXX")"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# =============================================================================
# identity fragments — every non-noreply address is assembled from fragments.
# =============================================================================

# id_email <numeric-id> <login> -> the conformant "+login" noreply form.
id_email() { printf '%s+%s@users.noreply.github.com' "$1" "$2"; }

# The plain GitHub web-flow noreply identity — a documented, non-PII, public
# identifier by GitHub's own design (same convention T-111's suite uses); it
# carries no shape to fragment.
WEBFLOW_EMAIL="noreply@github.com"

# Fragments for a synthetic, non-conformant "personal mailbox at a personal
# domain" shape — never written here as a completed literal.
BAD_LOCAL_1="bo"; BAD_LOCAL_2="b"
BAD_DOMAIN_1="examp"; BAD_DOMAIN_2="le"
BAD_TLD="com"
# bad_email [suffix] -> a synthetic non-conformant mailbox address, optionally
# with a distinguishing suffix appended to the local part.
bad_email() {
  local suffix="${1:-}"
  printf '%s%s%s@%s%s.%s' "$BAD_LOCAL_1" "$BAD_LOCAL_2" "$suffix" "$BAD_DOMAIN_1" "$BAD_DOMAIN_2" "$BAD_TLD"
}

# Lookalike-domain fragments (AC10): the noreply domain with something
# appended, and with something prepended. Neither is a real allowed form —
# the allowed-form match is anchored at both ends of the address, never a
# substring test.
LOOKALIKE_SUFFIX_DOMAIN_1="users.noreply.github.com"
LOOKALIKE_SUFFIX_DOMAIN_2=".evil-appended.net"
LOOKALIKE_PREFIX_DOMAIN_1="evil-prefixed-"
LOOKALIKE_PREFIX_DOMAIN_2="users.noreply.github.com"
lookalike_suffix_email() { printf '1+alice@%s%s' "$LOOKALIKE_SUFFIX_DOMAIN_1" "$LOOKALIKE_SUFFIX_DOMAIN_2"; }
lookalike_prefix_email() { printf '1+alice@%s%s' "$LOOKALIKE_PREFIX_DOMAIN_1" "$LOOKALIKE_PREFIX_DOMAIN_2"; }

# =============================================================================
# repo/commit builders
# =============================================================================

# new_repo -> prints the path to a fresh throwaway repo with one base commit
# (conformant identity — irrelevant to any scenario, since the base commit
# itself is always outside the checked range).
new_repo() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/check-commit-identity-repo.XXXXXX")"
  git -C "$d" init -q
  GIT_AUTHOR_NAME="base" GIT_AUTHOR_EMAIL="$(id_email 1 base)" \
    GIT_COMMITTER_NAME="base" GIT_COMMITTER_EMAIL="$(id_email 1 base)" \
    git -C "$d" commit -q --allow-empty -m base
  printf '%s' "$d"
}

# commit_with_identity <repo> <author-email> <committer-email> <message> —
# an --allow-empty commit, so the author and committer sides can be set
# independently via GIT_AUTHOR_EMAIL / GIT_COMMITTER_EMAIL without touching
# any tracked file.
commit_with_identity() {
  local repo="$1" ae="$2" ce="$3" msg="$4"
  GIT_AUTHOR_NAME="x" GIT_AUTHOR_EMAIL="$ae" \
    GIT_COMMITTER_NAME="x" GIT_COMMITTER_EMAIL="$ce" \
    git -C "$repo" commit -q --allow-empty -m "$msg"
}

# run_checker <repo> <base-ref> — sets OUT and RC.
OUT=""
RC=0
run_checker() {
  local repo="$1" base="$2"
  set +e
  OUT="$(cd "$repo" && bash "$BIN" --base "$base" 2>&1)"
  RC=$?
  set -e
}

# assert_clean <label> <repo> <base> — expects exit 0.
assert_clean() {
  local label="$1" repo="$2" base="$3"
  run_checker "$repo" "$base"
  if [ "$RC" -eq 0 ]; then
    pass "$label"
  else
    fail "$label (rc=$RC out=$OUT)"
  fi
}

# assert_finding <label> <side> <repo> <base> — expects exit 1 and a finding
# line naming side=<side> (author-identity | committer-identity).
assert_finding() {
  local label="$1" side="$2" repo="$3" base="$4"
  run_checker "$repo" "$base"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE "side=${side}$"; then
    pass "$label"
  else
    fail "$label (rc=$RC out=$OUT)"
  fi
}

# assert_positive_reports <side> <repo> <base> — returns 0 iff the REAL,
# unmutated checker reports a finding for side=<side> against <repo>/<base>.
# Used directly, and against a neutralised (conformant) fixture inside a
# subshell as AC13's meta-assertion.
assert_positive_reports() {
  local side="$1" repo="$2" base="$3" out rc
  set +e
  out="$(cd "$repo" && bash "$BIN" --base "$base" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qE "side=${side}$"; then
    return 0
  fi
  return 1
}

# =============================================================================
# exit-code contract (AC2)
# =============================================================================
printf '\n--- exit-code contract ---\n'

CLEAN_REPO="$(new_repo)"
CLEAN_BASE="$(git -C "$CLEAN_REPO" rev-parse HEAD)"
commit_with_identity "$CLEAN_REPO" "$(id_email 2 carol)" "$(id_email 2 carol)" "clean commit"
assert_clean "exit-code contract: 0 = clean range" "$CLEAN_REPO" "$CLEAN_BASE"

# --- unresolvable base ref: an explicit bad ref ---
set +e
( cd "$CLEAN_REPO" && bash "$BIN" --base zzz-unresolvable-ref-does-not-exist >/dev/null 2>&1 )
rc_badref=$?
set -e
if [ "$rc_badref" -eq 2 ]; then
  pass "exit-code contract: 2 = unresolvable base ref (explicit --base)"
else
  fail "exit-code contract: expected 2 for an unresolvable --base ref, got $rc_badref"
fi

# --- missing --base ---
set +e
( cd "$CLEAN_REPO" && bash "$BIN" >/dev/null 2>&1 )
rc_missing=$?
set -e
if [ "$rc_missing" -eq 2 ]; then
  pass "exit-code contract: 2 = missing required --base"
else
  fail "exit-code contract: expected 2 when --base is omitted, got $rc_missing"
fi

# --- unknown flag ---
set +e
bash "$BIN" --bogus >/dev/null 2>&1
rc_unknown=$?
set -e
if [ "$rc_unknown" -eq 2 ]; then
  pass "exit-code contract: 2 = unknown flag"
else
  fail "exit-code contract: expected 2 for an unknown flag, got $rc_unknown"
fi

# --- a path that is not a git repository ---
NONGIT="$(mktemp -d "${TMPDIR:-/tmp}/check-commit-identity-nongit.XXXXXX")"
set +e
( cd "$NONGIT" && bash "$BIN" --base HEAD >/dev/null 2>&1 )
rc_nogit=$?
set -e
if [ "$rc_nogit" -eq 2 ]; then
  pass "exit-code contract: 2 = a path that is not a git repository"
else
  fail "exit-code contract: expected 2 outside a git working tree, got $rc_nogit"
fi

# =============================================================================
# range: non-merge commits from the merge-base to HEAD (AC4)
# =============================================================================
printf '\n--- range: non-merge commits from the merge-base to HEAD ---\n'

RANGE_REPO="$(mktemp -d "${TMPDIR:-/tmp}/check-commit-identity-repo.XXXXXX")"
git -C "$RANGE_REPO" init -q
commit_with_identity "$RANGE_REPO" "$(bad_email pre)" "$(bad_email pre)" "pre-existing history (bad identity, at the merge-base)"
RANGE_BASE="$(git -C "$RANGE_REPO" rev-parse HEAD)"
commit_with_identity "$RANGE_REPO" "$(id_email 3 dave)" "$(id_email 3 dave)" "in-range (conformant)"
assert_clean "range: non-merge commits from the merge-base to HEAD (pre-existing bad-identity commit at the merge-base is never inspected)" \
  "$RANGE_REPO" "$RANGE_BASE"

# =============================================================================
# POS/NEG pair: author-identity (AC5)
# =============================================================================
printf '\n--- POS/NEG pair: author-identity ---\n'

AUTH_POS_REPO="$(new_repo)"; AUTH_POS_BASE="$(git -C "$AUTH_POS_REPO" rev-parse HEAD)"
commit_with_identity "$AUTH_POS_REPO" "$(bad_email a1)" "$(id_email 4 erin)" "author bad, committer conformant"
assert_finding "POS/NEG pair: author-identity (positive reported as side=author-identity)" \
  "author-identity" "$AUTH_POS_REPO" "$AUTH_POS_BASE"

AUTH_NEG_REPO="$(new_repo)"; AUTH_NEG_BASE="$(git -C "$AUTH_NEG_REPO" rev-parse HEAD)"
commit_with_identity "$AUTH_NEG_REPO" "$(id_email 4 erin)" "$(id_email 4 erin)" "conformant both sides"
assert_clean "POS/NEG pair: author-identity (conformant counterpart is clean)" \
  "$AUTH_NEG_REPO" "$AUTH_NEG_BASE"

# =============================================================================
# POS/NEG pair: committer-identity (AC6)
# =============================================================================
printf '\n--- POS/NEG pair: committer-identity ---\n'

COMM_POS_REPO="$(new_repo)"; COMM_POS_BASE="$(git -C "$COMM_POS_REPO" rev-parse HEAD)"
commit_with_identity "$COMM_POS_REPO" "$(id_email 5 finn)" "$(bad_email c1)" "committer bad, author conformant"
assert_finding "POS/NEG pair: committer-identity (positive reported as side=committer-identity)" \
  "committer-identity" "$COMM_POS_REPO" "$COMM_POS_BASE"

COMM_NEG_REPO="$(new_repo)"; COMM_NEG_BASE="$(git -C "$COMM_NEG_REPO" rev-parse HEAD)"
commit_with_identity "$COMM_NEG_REPO" "$(id_email 5 finn)" "$(id_email 5 finn)" "conformant both sides"
assert_clean "POS/NEG pair: committer-identity (conformant counterpart is clean)" \
  "$COMM_NEG_REPO" "$COMM_NEG_BASE"

# =============================================================================
# disposition: merge commits are excluded from the range (AC7)
# =============================================================================
printf '\n--- disposition: merge commits are excluded from the range ---\n'

MERGE_REPO="$(new_repo)"
MERGE_BASE_SHA="$(git -C "$MERGE_REPO" rev-parse HEAD)"
git -C "$MERGE_REPO" checkout -q -b branch-a
commit_with_identity "$MERGE_REPO" "$(id_email 6 gina)" "$(id_email 6 gina)" "on branch-a"
git -C "$MERGE_REPO" checkout -q -b branch-b "$MERGE_BASE_SHA"
commit_with_identity "$MERGE_REPO" "$(id_email 7 holly)" "$(id_email 7 holly)" "on branch-b"
# The merge commit itself carries the exact shape measured in this
# repository's own merged history: author = non-noreply personal mailbox,
# committer = the plain web-flow noreply identity. If merge commits were NOT
# excluded from the range, this would be a reachable author-identity finding.
GIT_AUTHOR_NAME="x" GIT_AUTHOR_EMAIL="$(bad_email merge)" \
  GIT_COMMITTER_NAME="x" GIT_COMMITTER_EMAIL="$WEBFLOW_EMAIL" \
  git -C "$MERGE_REPO" merge -q --no-ff -m "merge branch-a" branch-a

# fixture precondition: HEAD really is a 2-parent merge commit.
parent_count="$(git -C "$MERGE_REPO" cat-file -p HEAD | grep -c '^parent ')"
if [ "$parent_count" -ne 2 ]; then
  fail "disposition: merge commits are excluded from the range (fixture precondition failed: HEAD has $parent_count parent(s), expected 2)"
else
  assert_clean "disposition: merge commits are excluded from the range" \
    "$MERGE_REPO" "$MERGE_BASE_SHA"
fi

# =============================================================================
# disposition: web-flow committer identity is allowed (AC8)
# =============================================================================
printf '\n--- disposition: web-flow committer identity is allowed ---\n'

WFC_REPO="$(new_repo)"; WFC_BASE="$(git -C "$WFC_REPO" rev-parse HEAD)"
commit_with_identity "$WFC_REPO" "$(id_email 8 ivan)" "$WEBFLOW_EMAIL" "author conformant, committer web-flow (non-merge)"
assert_clean "disposition: web-flow committer identity is allowed" "$WFC_REPO" "$WFC_BASE"

# =============================================================================
# disposition: web-flow identity is NOT allowed on the author side (AC9)
# =============================================================================
printf '\n--- disposition: web-flow identity is NOT allowed on the author side ---\n'

WFA_REPO="$(new_repo)"; WFA_BASE="$(git -C "$WFA_REPO" rev-parse HEAD)"
commit_with_identity "$WFA_REPO" "$WEBFLOW_EMAIL" "$(id_email 9 jack)" "author web-flow (refused), committer conformant"
assert_finding "disposition: web-flow identity is NOT allowed on the author side" \
  "author-identity" "$WFA_REPO" "$WFA_BASE"

# =============================================================================
# anchor: lookalike noreply domain is a finding (AC10), both sides
# =============================================================================
printf '\n--- anchor: lookalike noreply domain is a finding ---\n'

LA_SUFFIX_REPO="$(new_repo)"; LA_SUFFIX_BASE="$(git -C "$LA_SUFFIX_REPO" rev-parse HEAD)"
commit_with_identity "$LA_SUFFIX_REPO" "$(lookalike_suffix_email)" "$(id_email 10 kate)" "author: noreply domain with an appended suffix (lookalike)"
assert_finding "anchor: lookalike noreply domain is a finding (author side, domain-suffix lookalike)" \
  "author-identity" "$LA_SUFFIX_REPO" "$LA_SUFFIX_BASE"

LA_PREFIX_REPO="$(new_repo)"; LA_PREFIX_BASE="$(git -C "$LA_PREFIX_REPO" rev-parse HEAD)"
commit_with_identity "$LA_PREFIX_REPO" "$(id_email 11 liam)" "$(lookalike_prefix_email)" "committer: noreply domain with a prepended label (lookalike)"
assert_finding "anchor: lookalike noreply domain is a finding (committer side, domain-prefix lookalike)" \
  "committer-identity" "$LA_PREFIX_REPO" "$LA_PREFIX_BASE"

# =============================================================================
# empty range is clean (AC11)
# =============================================================================
printf '\n--- empty range is clean ---\n'

EMPTY_REPO="$(new_repo)"
EMPTY_BASE="$(git -C "$EMPTY_REPO" rev-parse HEAD)"
run_checker "$EMPTY_REPO" "$EMPTY_BASE"
if [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FINDING'; then
  pass "empty range is clean (no commits between the merge-base and HEAD: exit 0, no findings)"
else
  fail "empty range is clean (rc=$RC out=$OUT)"
fi

# =============================================================================
# mutation: identity pattern is load-bearing (AC12, vacuity guard / detector
# side)
#
# Neutralise BOTH allowed-identity regexes in a throwaway copy of the real
# checker (rewritten to match ANY string), then re-run the already-proven
# author-identity and committer-identity POSITIVE fixtures (above) against the
# copy. The copy must now report NOTHING for either — proving the
# allowed-identity rule is what produces those findings, not something else.
# =============================================================================
printf '\n--- mutation: identity pattern is load-bearing ---\n'

neutralize_copy() {
  local copy
  copy="$(mktemp "${TMPDIR:-/tmp}/check-commit-identity-mut.XXXXXX")"
  sed -e "s/^NOREPLY_ID_RE=.*/NOREPLY_ID_RE='.*'/" \
      -e "s/^NOREPLY_PLAIN_RE=.*/NOREPLY_PLAIN_RE='.*'/" \
      "$BIN" > "$copy"
  printf '%s' "$copy"
}

assert_neutralised_reports_nothing() {  # <label> <repo> <base>
  local label="$1" repo="$2" base="$3" copy out rc
  copy="$(neutralize_copy)"
  set +e
  out="$(cd "$repo" && bash "$copy" --base "$base" 2>&1)"
  rc=$?
  set -e
  rm -f "$copy"
  if [ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q '^FINDING'; then
    pass "$label"
  else
    fail "$label (neutralised copy still reported something: rc=$rc out=$out)"
  fi
}

assert_neutralised_reports_nothing \
  "mutation: identity pattern is load-bearing (author-identity fixture reports nothing once the allowed-identity rule is neutralised)" \
  "$AUTH_POS_REPO" "$AUTH_POS_BASE"
assert_neutralised_reports_nothing \
  "mutation: identity pattern is load-bearing (committer-identity fixture reports nothing once the allowed-identity rule is neutralised)" \
  "$COMM_POS_REPO" "$COMM_POS_BASE"

# =============================================================================
# meta: neutralised positive fixture makes the assertion FAIL (AC13, vacuity
# guard / fixture side)
#
# For each side: call the REAL positive-assertion helper (assert_positive_reports,
# the same helper used above) against that side's own NEG fixture — i.e. its
# positive fixture with the non-conformant identity replaced by a conformant
# one — in a subshell, and require the call itself to FAIL. A fixture that
# silently stopped carrying its non-conformant shape would make this
# meta-assertion incorrectly PASS, so this proves it does not.
# =============================================================================
printf '\n--- meta: neutralised positive fixture makes the assertion FAIL ---\n'

assert_meta_fails() {  # <side> <repo> <base> <label>
  local side="$1" repo="$2" base="$3" label="$4" rc
  set +e
  ( assert_positive_reports "$side" "$repo" "$base" )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    pass "$label"
  else
    fail "$label (the positive-assertion helper incorrectly SUCCEEDED against a neutralised fixture)"
  fi
}

assert_meta_fails author-identity "$AUTH_NEG_REPO" "$AUTH_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (author-identity)"
assert_meta_fails committer-identity "$COMM_NEG_REPO" "$COMM_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (committer-identity)"

# =============================================================================
# no-leak: finding output never echoes the identity value (AC14)
# =============================================================================
printf '\n--- no-leak: finding output never echoes the identity value ---\n'

LEAK_MARKER="zzzqqqNoLeakMarkerT112xyz"
LEAK_REPO="$(new_repo)"; LEAK_BASE="$(git -C "$LEAK_REPO" rev-parse HEAD)"
commit_with_identity "$LEAK_REPO" "$(bad_email "$LEAK_MARKER")" "$(id_email 12 mona)" "leak check"
run_checker "$LEAK_REPO" "$LEAK_BASE"
if [ "$RC" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qE 'side=author-identity$' \
   && ! printf '%s\n' "$OUT" | grep -qF "$LEAK_MARKER"; then
  pass "no-leak: finding output never echoes the identity value"
else
  fail "no-leak: finding output never echoes the identity value (rc=$RC out=$OUT)"
fi

# =============================================================================
printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-commit-identity suite: all assertions passed\n'
  exit 0
else
  printf 'check-commit-identity suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
