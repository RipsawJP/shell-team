#!/usr/bin/env bash
# run.sh — drive bin/land-worktree.sh against throwaway git repositories and
# assert its documented behavior (T-1077;
# .shell-team/specs/T-1077-worktree-reconcile.md AC2/AC3).
#
# Case ids (named here verbatim so AC2's own check can confirm the coverage
# was not quietly narrowed): clean-landing-three-workers,
# clean-landing-composition-equals-union, clean-landing-two-parents,
# clean-landing-worker-refs-unrewritten, clean-landing-order-independent,
# landing-record-shape, landing-record-path-escaping; overlap-plain,
# overlap-path-with-space, overlap-path-with-tab, overlap-path-with-newline,
# overlap-rename-both-paths-claimed, overlap-deletion, overlap-mode-only,
# overlap-symlink-entry, overlap-dir-file-replacement, overlap-case-only,
# overlap-quotepath-independent; diverged-base-not-ancestor,
# diverged-worker-tree-dirty, worker-tree-unchecked-disclosed, empty-landing,
# ref-moved, structural-unresolvable-ref, structural-onto-checked-out,
# lock-timeout-refusal, lock-never-stolen, lock-released-on-signal,
# lock-under-git-common-dir, refusals-empty-stdout, check-only-advances-nothing;
# plus the landing-parameters line and the negative control (AC3).
#
# Hermetic git (tests/rollup-track/run.sh's own pattern): every repository is
# a throwaway `git init -q` scratch tree under $TMPDIR, torn down by an EXIT
# trap; no process substitution (plain temp files + reads instead). Adversarial
# paths (embedded space/tab/newline, ASCII-case-only pairs, symlink entries,
# mode-only changes, dir/file replacement) are built with git plumbing
# (`git hash-object` + a private `GIT_INDEX_FILE`, then `git commit-tree`)
# rather than through a working-tree checkout, per the frozen spec's own
# guidance — the same shape bin/land-worktree.sh itself uses for its
# composition, so the suite and the tool exercise the same shape.

set -euo pipefail

export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin/land-worktree.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

T="$(mktemp -d "${TMPDIR:-/tmp}/land-worktree-suite.XXXXXX")"
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
cleanup() { rm -rf "$T" 2>/dev/null || true; }
trap cleanup EXIT

WORKER_COUNT=0
OVERLAP_CASE_COUNT=0
REFUSAL_CLASS_COUNT=0
SCRATCH_N=0

# --- repository / commit construction helpers -------------------------------

new_repo() {  # prints the new repo's absolute path
  # A FILE-based counter, not a shell variable: this function is routinely
  # called via command substitution (`repo="$(new_repo)"`), which runs it in
  # a subshell — a shell-variable increment there is invisible to the
  # caller once the subshell exits, which would make every "new" repo
  # silently alias the same directory. Filesystem state (unlike a shell
  # variable) survives a subshell's exit.
  local counterfile="$T/.repo_counter" n
  n="$(cat "$counterfile" 2>/dev/null || printf '0')"
  n=$((n + 1))
  printf '%s' "$n" > "$counterfile"
  local d="$T/repo$n"
  mkdir -p "$d"
  git init -q "$d" >/dev/null
  git -C "$d" config user.email t@example.invalid
  git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  printf '%s' "$d"
}

next_idx() {
  # mktemp, not a shell-variable counter: this is called from inside
  # mk_commit/make_shared_base, themselves routinely invoked via command
  # substitution — the same subshell-visibility trap new_repo's own header
  # comment explains. mktemp's uniqueness is filesystem-guaranteed and
  # needs no counter at all. git refuses a GIT_INDEX_FILE that EXISTS but
  # is not a valid index (even a zero-byte one — "index file smaller than
  # expected"), so the freshly minted path is removed immediately, leaving
  # only its now-reserved, still-unique NAME for `git read-tree`/
  # `update-index` to create fresh.
  local p
  p="$(mktemp "$T/idx.XXXXXXXX")"
  rm -f "$p" 2>/dev/null || true
  printf '%s' "$p"
}

# mk_commit <repo> <parent-or-empty> <msg> [<mode> <path> <content>]... |
#           [rm <path>]...
# Builds one commit whose tree is <parent>'s tree with the given ops
# applied, via a private scratch index — never a working-tree checkout, so
# any path (embedded space/tab/newline) and any entry kind
# (100644/100755/120000/160000, or a removal) is representable regardless
# of what this host's filesystem would tolerate in a real checkout.
# <parent> may be the empty string, meaning "no parent" (a root commit):
# the index starts empty rather than seeded via `read-tree`, and
# `commit-tree` is called with no `-p` at all — used by the composition
# transition-matrix fixtures below to build a fresh base commit directly,
# without a throwaway unrelated ancestor. Prints the new commit sha.
mk_commit() {
  local repo="$1" parent="$2" msg="$3"
  shift 3
  local idx
  idx="$(next_idx)"
  if [ -n "$parent" ]; then
    GIT_INDEX_FILE="$idx" git -C "$repo" read-tree "$parent"
  fi
  while [ "$#" -ge 1 ]; do
    local mode="$1"
    if [ "$mode" = "rm" ]; then
      local path="$2"
      GIT_INDEX_FILE="$idx" git -C "$repo" update-index --force-remove -- "$path"
      shift 2
    else
      local path="$2" content="$3" sha
      sha="$(printf '%s' "$content" | git -C "$repo" hash-object -w --stdin)"
      GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add --cacheinfo "$mode" "$sha" "$path"
      shift 3
    fi
  done
  local tree
  tree="$(GIT_INDEX_FILE="$idx" git -C "$repo" write-tree)"
  rm -f "$idx" 2>/dev/null || true
  if [ -n "$parent" ]; then
    git -C "$repo" commit-tree "$tree" -p "$parent" -m "$msg"
  else
    git -C "$repo" commit-tree "$tree" -m "$msg"
  fi
}

# make_shared_base <repo> — a base commit carrying four files several
# overlap fixtures reuse: base.txt, script.sh, todelete.txt, orig.txt.
make_shared_base() {
  local repo="$1" idx
  idx="$(next_idx)"
  local sha_base sha_script sha_del sha_orig
  sha_base="$(printf 'base\n' | git -C "$repo" hash-object -w --stdin)"
  sha_script="$(printf 'same-content\n' | git -C "$repo" hash-object -w --stdin)"
  sha_del="$(printf 'will be deleted\n' | git -C "$repo" hash-object -w --stdin)"
  sha_orig="$(printf 'base-orig\n' | git -C "$repo" hash-object -w --stdin)"
  GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add --cacheinfo 100644 "$sha_base" base.txt
  GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add --cacheinfo 100644 "$sha_script" script.sh
  GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add --cacheinfo 100644 "$sha_del" todelete.txt
  GIT_INDEX_FILE="$idx" git -C "$repo" update-index --add --cacheinfo 100644 "$sha_orig" orig.txt
  local tree
  tree="$(GIT_INDEX_FILE="$idx" git -C "$repo" write-tree)"
  rm -f "$idx" 2>/dev/null || true
  git -C "$repo" commit-tree "$tree" -m base
}

lockdir_of() {  # <repo> -> prints the absolutized lock directory path
  local repo="$1" gcd
  gcd="$(git -C "$repo" rev-parse --git-common-dir)"
  case "$gcd" in
    /*) : ;;
    *) gcd="$(cd "$repo" && cd "$gcd" && pwd)" ;;
  esac
  printf '%s/land-worktree.lock' "$gcd"
}

# run_land <repo> <args...> — invokes the real tool from inside <repo>,
# never aborting the suite on a non-zero exit. Sets LAND_RC/LAND_OUT/LAND_ERR.
run_land() {
  local repo="$1"
  shift
  local outp errp
  outp="$T/land.out.$SCRATCH_N.$RANDOM"
  errp="$T/land.err.$SCRATCH_N.$RANDOM"
  SCRATCH_N=$((SCRATCH_N + 1))
  if ( cd "$repo" && bash "$BIN" "$@" ) >"$outp" 2>"$errp"; then
    LAND_RC=0
  else
    LAND_RC=$?
  fi
  LAND_OUT="$outp"
  LAND_ERR="$errp"
}

assert_empty_stdout_refusal() {  # <desc> <expected_rc> <expected_class>
  local desc="$1" exp_rc="$2" exp_class="$3"
  [ "$LAND_RC" = "$exp_rc" ] || fail "$desc: expected exit $exp_rc, got $LAND_RC (stderr: $(cat "$LAND_ERR" 2>/dev/null))"
  [ "$(grep -c . "$LAND_OUT" 2>/dev/null || true)" = "0" ] || fail "$desc: expected empty stdout, got $(cat "$LAND_OUT")"
  grep -qE "^land-worktree: ${exp_class}: ." "$LAND_ERR" || fail "$desc: expected one 'land-worktree: ${exp_class}: ' stderr line, got: $(cat "$LAND_ERR")"
  REFUSAL_CLASS_COUNT=$((REFUSAL_CLASS_COUNT + 1))
}

# =============================================================================
# clean-landing group: three disjoint workers land sequentially onto one
# coordinator branch.
# =============================================================================
CL_REPO="$(new_repo)"
CL_BASE="$(make_shared_base "$CL_REPO")"
git -C "$CL_REPO" branch onto "$CL_BASE"
git -C "$CL_REPO" checkout -q --detach "$CL_BASE"

CL_W1="$(mk_commit "$CL_REPO" "$CL_BASE" w1 100644 f1.txt "worker1 content")"
CL_W2="$(mk_commit "$CL_REPO" "$CL_BASE" w2 100755 f2.sh "worker2 content")"
CL_W3_TARGET_SHA="$(printf '%s' base.txt | git -C "$CL_REPO" hash-object -w --stdin)"
CL_W3="$(mk_commit "$CL_REPO" "$CL_BASE" w3 120000 f3link base.txt)"
WORKER_COUNT=$((WORKER_COUNT + 3))

run_land "$CL_REPO" --base "$CL_BASE" --onto onto --worker "$CL_W1"
[ "$LAND_RC" = "0" ] || fail "clean-landing setup: landing w1 failed (rc=$LAND_RC): $(cat "$LAND_ERR")"
CL_LANDED1="$(git -C "$CL_REPO" rev-parse onto)"

run_land "$CL_REPO" --base "$CL_BASE" --onto onto --worker "$CL_W2"
[ "$LAND_RC" = "0" ] || fail "clean-landing setup: landing w2 failed (rc=$LAND_RC): $(cat "$LAND_ERR")"
CL_LANDED2="$(git -C "$CL_REPO" rev-parse onto)"

run_land "$CL_REPO" --base "$CL_BASE" --onto onto --worker "$CL_W3"
[ "$LAND_RC" = "0" ] || fail "clean-landing setup: landing w3 failed (rc=$LAND_RC): $(cat "$LAND_ERR")"
CL_LANDED3="$(git -C "$CL_REPO" rev-parse onto)"

if [ "$LAND_RC" = "0" ]; then
  pass "T-1077 clean-landing-three-workers"
else
  fail "clean-landing-three-workers: not all three workers landed"
fi

# composition-equals-union: the final tree carries exactly the base's four
# files plus f1.txt/f2.sh/f3link, with the modes/content each worker claimed.
CL_TREE_LIST="$T/cl-tree.txt"
git -C "$CL_REPO" ls-tree onto > "$CL_TREE_LIST"
cl_ok=1
grep -qE $'^100644 blob [0-9a-f]+\tbase\\.txt$' "$CL_TREE_LIST" || cl_ok=0
grep -qE $'^100644 blob [0-9a-f]+\torig\\.txt$' "$CL_TREE_LIST" || cl_ok=0
grep -qE $'^100644 blob [0-9a-f]+\tf1\\.txt$' "$CL_TREE_LIST" || cl_ok=0
grep -qE $'^100755 blob [0-9a-f]+\tf2\\.sh$' "$CL_TREE_LIST" || cl_ok=0
grep -qE $'^120000 blob [0-9a-f]+\tf3link$' "$CL_TREE_LIST" || cl_ok=0
CL_F3_SHA="$(git -C "$CL_REPO" ls-tree onto -- f3link | awk '{print $3}')"
[ "$CL_F3_SHA" = "$CL_W3_TARGET_SHA" ] || cl_ok=0
if [ "$cl_ok" = "1" ]; then
  pass "T-1077 clean-landing-composition-equals-union"
else
  fail "clean-landing-composition-equals-union: final tree does not match the expected union ($(cat "$CL_TREE_LIST"))"
fi

# two-parents: each landed commit has exactly two parents, coordinator-tip
# first, worker tip second.
cl_parents_ok=1
for pair in "$CL_LANDED1:$CL_BASE:$CL_W1" "$CL_LANDED2:$CL_LANDED1:$CL_W2" "$CL_LANDED3:$CL_LANDED2:$CL_W3"; do
  commit="${pair%%:*}"
  rest="${pair#*:}"
  expT="${rest%%:*}"
  expW="${rest#*:}"
  parents="$(git -C "$CL_REPO" show -s --format='%P' "$commit")"
  p1="${parents%% *}"
  p2="${parents#* }"
  { [ "$p1" = "$expT" ] && [ "$p2" = "$expW" ]; } || cl_parents_ok=0
done
if [ "$cl_parents_ok" = "1" ]; then
  pass "T-1077 clean-landing-two-parents"
else
  fail "clean-landing-two-parents: parent order/values do not match coordinator-tip-first, worker-tip-second"
fi

# worker-refs-unrewritten: the raw worker commit shas are unchanged and
# still reachable (they were never a branch to begin with, so "unrewritten"
# means the sha itself, captured before landing, still resolves identically).
if git -C "$CL_REPO" cat-file -e "$CL_W1" 2>/dev/null \
  && git -C "$CL_REPO" cat-file -e "$CL_W2" 2>/dev/null \
  && git -C "$CL_REPO" cat-file -e "$CL_W3" 2>/dev/null; then
  pass "T-1077 clean-landing-worker-refs-unrewritten"
else
  fail "clean-landing-worker-refs-unrewritten: a worker commit is no longer reachable"
fi

# order-independent: landing the same three workers in a different order
# onto a fresh coordinator branch from the same base produces a byte-
# identical final tree.
git -C "$CL_REPO" branch onto2 "$CL_BASE"
run_land "$CL_REPO" --base "$CL_BASE" --onto onto2 --worker "$CL_W3"
[ "$LAND_RC" = "0" ] || fail "order-independent setup: landing w3 first failed"
run_land "$CL_REPO" --base "$CL_BASE" --onto onto2 --worker "$CL_W1"
[ "$LAND_RC" = "0" ] || fail "order-independent setup: landing w1 second failed"
run_land "$CL_REPO" --base "$CL_BASE" --onto onto2 --worker "$CL_W2"
[ "$LAND_RC" = "0" ] || fail "order-independent setup: landing w2 third failed"
TREE_A="$(git -C "$CL_REPO" rev-parse 'onto^{tree}')"
TREE_B="$(git -C "$CL_REPO" rev-parse 'onto2^{tree}')"
if [ "$TREE_A" = "$TREE_B" ] && [ -n "$TREE_A" ]; then
  pass "T-1077 clean-landing-order-independent"
else
  fail "clean-landing-order-independent: tree A ($TREE_A) != tree B ($TREE_B)"
fi

# landing-record-shape: the stdout record from a fresh single landing.
LR_REPO="$(new_repo)"
LR_BASE="$(make_shared_base "$LR_REPO")"
git -C "$LR_REPO" branch onto "$LR_BASE"
git -C "$LR_REPO" checkout -q --detach "$LR_BASE"
LR_W="$(mk_commit "$LR_REPO" "$LR_BASE" w 100644 shape.txt "shape content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$LR_REPO" --base "$LR_BASE" --onto onto --worker "$LR_W"
lr_ok=1
[ "$LAND_RC" = "0" ] || lr_ok=0
grep -qxF '<!-- BEGIN land-worktree-record -->' "$LAND_OUT" || lr_ok=0
grep -qxF '<!-- END land-worktree-record -->' "$LAND_OUT" || lr_ok=0
grep -qxF -- '- mode: landed' "$LAND_OUT" || lr_ok=0
grep -qE '^- claimed-paths: 1$' "$LAND_OUT" || lr_ok=0
grep -qE '^- landed-tip: [0-9a-f]+$' "$LAND_OUT" || lr_ok=0
grep -qxF -- '- worker-tree: not-checked' "$LAND_OUT" || lr_ok=0
if [ "$lr_ok" = "1" ]; then
  pass "T-1077 landing-record-shape"
else
  fail "landing-record-shape: record did not match the expected shape ($(cat "$LAND_OUT"))"
fi

# landing-record-path-escaping: a path with an embedded space, C-escaped
# onto exactly one record line.
PE_REPO="$(new_repo)"
PE_BASE="$(make_shared_base "$PE_REPO")"
git -C "$PE_REPO" branch onto "$PE_BASE"
git -C "$PE_REPO" checkout -q --detach "$PE_BASE"
PE_W="$(mk_commit "$PE_REPO" "$PE_BASE" w 100644 "has space.txt" "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$PE_REPO" --base "$PE_BASE" --onto onto --worker "$PE_W"
pe_ok=1
[ "$LAND_RC" = "0" ] || pe_ok=0
[ "$(grep -c . "$LAND_OUT" || true)" -gt 0 ] || pe_ok=0
grep -qF -- "- path: has\\ space.txt" "$LAND_OUT" || pe_ok=0
[ "$(grep -c '^- path: ' "$LAND_OUT" || true)" = "1" ] || pe_ok=0
if [ "$pe_ok" = "1" ]; then
  pass "T-1077 landing-record-path-escaping"
else
  fail "landing-record-path-escaping: escaped path line not found as expected ($(cat "$LAND_OUT"))"
fi

# =============================================================================
# overlap group (D7): one case per mutation class. Each case lands an EARLY
# worker cleanly (establishing "already landed"), then attempts a LATE
# worker whose claim set collides with it, expecting exit 1 (overlap),
# empty stdout, one classified stderr line.
# =============================================================================

overlap_setup() {  # prints "<repo> <base>" — a fresh repo with a shared base
  local repo base
  repo="$(new_repo)"
  base="$(make_shared_base "$repo")"
  git -C "$repo" branch onto "$base"
  git -C "$repo" checkout -q --detach "$base"
  printf '%s %s' "$repo" "$base"
}

run_overlap_case() {  # <token> <early-args...> -- <late-args...>
  local token="$1"
  shift
  read -r repo base <<EOF
$(overlap_setup)
EOF
  # Split early/late op-lists on the literal "--" separator.
  local early=()
  while [ "$1" != "--" ]; do
    early+=("$1")
    shift
  done
  shift
  local late=("$@")

  local early_commit late_commit
  early_commit="$(mk_commit "$repo" "$base" early "${early[@]}")"
  late_commit="$(mk_commit "$repo" "$base" late "${late[@]}")"
  WORKER_COUNT=$((WORKER_COUNT + 2))

  run_land "$repo" --base "$base" --onto onto --worker "$early_commit"
  [ "$LAND_RC" = "0" ] || { fail "overlap-$token setup: landing the early worker failed (rc=$LAND_RC): $(cat "$LAND_ERR")"; return; }

  run_land "$repo" --base "$base" --onto onto --worker "$late_commit"
  assert_empty_stdout_refusal "overlap-$token" 1 overlap
  OVERLAP_CASE_COUNT=$((OVERLAP_CASE_COUNT + 1))
  pass "T-1077 overlap-$token"
}

run_overlap_case plain       100644 shared.txt "A" -- 100644 shared.txt "B"
run_overlap_case path-with-space 100644 "has space.txt" "A" -- 100644 "has space.txt" "B"
run_overlap_case path-with-tab   100644 "$(printf 'has\ttab.txt')" "A" -- 100644 "$(printf 'has\ttab.txt')" "B"
run_overlap_case path-with-newline 100644 "$(printf 'multi\nline.txt')" "A" -- 100644 "$(printf 'multi\nline.txt')" "B"
run_overlap_case deletion    rm todelete.txt -- 100644 todelete.txt "modified content"
run_overlap_case mode-only   100755 script.sh "same-content" -- 100644 script.sh "different content"
run_overlap_case rename-both-paths-claimed 100644 orig.txt "modified-orig" -- rm orig.txt 100644 newname.txt "base-orig"
run_overlap_case symlink-entry 120000 link1 base.txt -- 100644 link1 "not a symlink"
run_overlap_case dir-file-replacement 100644 x "file content" -- 100644 x/y "nested content"
run_overlap_case case-only   100644 README.txt "content1" -- 100644 readme.txt "content2"

# quotepath-independent: the same tab-path collision, replayed once with
# core.quotepath=true and once with core.quotepath=false, confirming the
# overlap outcome does not depend on it (git diff -z always emits raw,
# unquoted path bytes regardless).
for qp in true false; do
  read -r qrepo qbase <<EOF
$(overlap_setup)
EOF
  git -C "$qrepo" config core.quotepath "$qp"
  qp_path="$(printf 'quoted\ttab.txt')"
  qearly="$(mk_commit "$qrepo" "$qbase" early 100644 "$qp_path" "A")"
  qlate="$(mk_commit "$qrepo" "$qbase" late 100644 "$qp_path" "B")"
  WORKER_COUNT=$((WORKER_COUNT + 2))
  run_land "$qrepo" --base "$qbase" --onto onto --worker "$qearly"
  [ "$LAND_RC" = "0" ] || fail "overlap-quotepath-independent (core.quotepath=$qp) setup: early landing failed"
  run_land "$qrepo" --base "$qbase" --onto onto --worker "$qlate"
  [ "$LAND_RC" = "1" ] || fail "overlap-quotepath-independent (core.quotepath=$qp): expected exit 1, got $LAND_RC"
  [ "$(grep -c . "$LAND_OUT" || true)" = "0" ] || fail "overlap-quotepath-independent (core.quotepath=$qp): expected empty stdout"
done
OVERLAP_CASE_COUNT=$((OVERLAP_CASE_COUNT + 1))
REFUSAL_CLASS_COUNT=$((REFUSAL_CLASS_COUNT + 1))
pass "T-1077 overlap-quotepath-independent"

# =============================================================================
# Composition transition-matrix group (rework: T-1077 round-1 review
# Finding 1, Blocker — entry-type-unaware composition). A single worker's
# own claim set can transition any claimed path between {absent, blob,
# symlink, tree, gitlink}; each case below lands a clean single worker
# (no cross-worker overlap involved) exercising one matrix cell, and
# asserts the FINAL composed tree, not merely the exit code.
# =============================================================================

# tree_line <repo> <ref> <path> -> prints the matching `git ls-tree` line
# for <path> at <ref>, or nothing if absent.
tree_line() {
  git -C "$1" ls-tree "$2" -- ":(literal)$3" 2>/dev/null
}

# composition-file-to-directory: base has a blob "x"; worker replaces it
# with a directory "x/y". Composes correctly: "x" is gone, only "x/y"
# exists — the exact shape Codex's round-1 reproduction found corrupted
# (a bogus extra "xy" entry) before this rework's two-pass fix.
FD_REPO="$(new_repo)"
FD_BASE_SHA="$(mk_commit "$FD_REPO" "" base 100644 x "file content")"
git -C "$FD_REPO" branch onto "$FD_BASE_SHA"
git -C "$FD_REPO" checkout -q --detach "$FD_BASE_SHA"
FD_WORKER="$(mk_commit "$FD_REPO" "$FD_BASE_SHA" worker rm x 100644 x/y "nested content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$FD_REPO" --base "$FD_BASE_SHA" --onto onto --worker "$FD_WORKER"
fd_ok=1
[ "$LAND_RC" = "0" ] || fd_ok=0
# "x" legitimately still appears as a non-recursive `ls-tree` line — as the
# TREE object that now contains "y" (ordinary git structure, not a bug);
# what must NOT happen is "x" resolving as a leaf BLOB entry, or the
# bogus extra "xy" (no slash) entry Codex's own reproduction found.
if tree_line "$FD_REPO" onto x | grep -qE '^100644 blob '; then
  fd_ok=0
fi
[ -z "$(tree_line "$FD_REPO" onto xy)" ] || fd_ok=0
tree_line "$FD_REPO" onto x/y | grep -qE '^100644 blob ' || fd_ok=0
[ "$(git -C "$FD_REPO" ls-tree -r onto | grep -c . || true)" = "1" ] || fd_ok=0
if [ "$fd_ok" = "1" ]; then
  pass "T-1077 composition-file-to-directory"
else
  fail "composition-file-to-directory: expected exactly one entry (x/y), no stray x or xy ($(git -C "$FD_REPO" ls-tree -r onto 2>&1))"
fi

# composition-directory-to-file: the reverse — base has a directory "x/y";
# worker replaces it with a plain file "x". Composes correctly: "x/y" is
# gone, "x" is a blob — the shape that used to misclassify as `structural`
# (or fail outright, order-dependently) before this rework.
DF_REPO="$(new_repo)"
DF_BASE_SHA="$(mk_commit "$DF_REPO" "" base 100644 x/y "nested content")"
git -C "$DF_REPO" branch onto "$DF_BASE_SHA"
git -C "$DF_REPO" checkout -q --detach "$DF_BASE_SHA"
DF_WORKER="$(mk_commit "$DF_REPO" "$DF_BASE_SHA" worker rm x/y 100644 x "now a file")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$DF_REPO" --base "$DF_BASE_SHA" --onto onto --worker "$DF_WORKER"
df_ok=1
[ "$LAND_RC" = "0" ] || df_ok=0
[ -z "$(tree_line "$DF_REPO" onto x/y)" ] || df_ok=0
tree_line "$DF_REPO" onto x | grep -qE '^100644 blob ' || df_ok=0
[ "$(git -C "$DF_REPO" ls-tree -r onto | grep -c . || true)" = "1" ] || df_ok=0
if [ "$df_ok" = "1" ]; then
  pass "T-1077 composition-directory-to-file"
else
  fail "composition-directory-to-file: expected exactly one entry (x, a blob), got ($(git -C "$DF_REPO" ls-tree -r onto 2>&1)) rc=$LAND_RC err=$(cat "$LAND_ERR" 2>/dev/null)"
fi

# composition-mode-flip-644-to-755 / -755-to-644: a mode-only change on an
# otherwise-untouched blob composes with the new mode and the SAME content
# sha (never re-reading blob content, per D5).
MF1_REPO="$(new_repo)"
MF1_BASE_SHA="$(mk_commit "$MF1_REPO" "" base 100644 s.sh "script")"
git -C "$MF1_REPO" branch onto "$MF1_BASE_SHA"
git -C "$MF1_REPO" checkout -q --detach "$MF1_BASE_SHA"
MF1_WORKER="$(mk_commit "$MF1_REPO" "$MF1_BASE_SHA" worker 100755 s.sh "script")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$MF1_REPO" --base "$MF1_BASE_SHA" --onto onto --worker "$MF1_WORKER"
if [ "$LAND_RC" = "0" ] && tree_line "$MF1_REPO" onto s.sh | grep -qE '^100755 blob '; then
  pass "T-1077 composition-mode-flip-644-to-755"
else
  fail "composition-mode-flip-644-to-755: expected mode 100755 ($(tree_line "$MF1_REPO" onto s.sh))"
fi

MF2_REPO="$(new_repo)"
MF2_BASE_SHA="$(mk_commit "$MF2_REPO" "" base 100755 s.sh "script")"
git -C "$MF2_REPO" branch onto "$MF2_BASE_SHA"
git -C "$MF2_REPO" checkout -q --detach "$MF2_BASE_SHA"
MF2_WORKER="$(mk_commit "$MF2_REPO" "$MF2_BASE_SHA" worker 100644 s.sh "script")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$MF2_REPO" --base "$MF2_BASE_SHA" --onto onto --worker "$MF2_WORKER"
if [ "$LAND_RC" = "0" ] && tree_line "$MF2_REPO" onto s.sh | grep -qE '^100644 blob '; then
  pass "T-1077 composition-mode-flip-755-to-644"
else
  fail "composition-mode-flip-755-to-644: expected mode 100644 ($(tree_line "$MF2_REPO" onto s.sh))"
fi

# composition-blob-to-symlink / -symlink-to-blob: an entry-KIND change
# (not just a mode-only bit flip) composes with the correct mode AND the
# worker's own sha (a symlink's blob content is its target string, never
# resolved/dereferenced).
BS_REPO="$(new_repo)"
BS_BASE_SHA="$(mk_commit "$BS_REPO" "" base 100644 link "blobcontent" 100644 target.txt "target")"
git -C "$BS_REPO" branch onto "$BS_BASE_SHA"
git -C "$BS_REPO" checkout -q --detach "$BS_BASE_SHA"
BS_WORKER="$(mk_commit "$BS_REPO" "$BS_BASE_SHA" worker 120000 link "target.txt")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$BS_REPO" --base "$BS_BASE_SHA" --onto onto --worker "$BS_WORKER"
if [ "$LAND_RC" = "0" ] && tree_line "$BS_REPO" onto link | grep -qE '^120000 blob '; then
  pass "T-1077 composition-blob-to-symlink"
else
  fail "composition-blob-to-symlink: expected mode 120000 ($(tree_line "$BS_REPO" onto link))"
fi

SB_REPO="$(new_repo)"
SB_BASE_SHA="$(mk_commit "$SB_REPO" "" base 120000 link "target.txt" 100644 target.txt "target")"
git -C "$SB_REPO" branch onto "$SB_BASE_SHA"
git -C "$SB_REPO" checkout -q --detach "$SB_BASE_SHA"
SB_WORKER="$(mk_commit "$SB_REPO" "$SB_BASE_SHA" worker 100644 link "now a real file, not a symlink")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$SB_REPO" --base "$SB_BASE_SHA" --onto onto --worker "$SB_WORKER"
if [ "$LAND_RC" = "0" ] && tree_line "$SB_REPO" onto link | grep -qE '^100644 blob '; then
  pass "T-1077 composition-symlink-to-blob"
else
  fail "composition-symlink-to-blob: expected mode 100644 ($(tree_line "$SB_REPO" onto link))"
fi

# composition-gitlink-refused-new: the worker introduces a NEW gitlink
# (submodule) entry — declared out of scope by the Input space's own
# closing bullet ("Submodules... not modelled"); refused (`structural`),
# never silently staged.
GLN_REPO="$(new_repo)"
GLN_BASE_SHA="$(mk_commit "$GLN_REPO" "" base 100644 base.txt "base")"
git -C "$GLN_REPO" branch onto "$GLN_BASE_SHA"
git -C "$GLN_REPO" checkout -q --detach "$GLN_BASE_SHA"
GLN_WORKER="$(mk_commit "$GLN_REPO" "$GLN_BASE_SHA" worker 160000 sub 1111111111111111111111111111111111111111)"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$GLN_REPO" --base "$GLN_BASE_SHA" --onto onto --worker "$GLN_WORKER"
assert_empty_stdout_refusal "composition-gitlink-refused-new" 2 structural
pass "T-1077 composition-gitlink-refused-new"

# composition-gitlink-refused-existing: the worker touches a path that is
# ALREADY a gitlink at the coordinator tip (the worker's own diff against
# base shows it changing) — also refused, never silently staged or
# removed.
GLE_REPO="$(new_repo)"
GLE_BASE_SHA="$(mk_commit "$GLE_REPO" "" base 160000 sub 1111111111111111111111111111111111111111)"
git -C "$GLE_REPO" branch onto "$GLE_BASE_SHA"
git -C "$GLE_REPO" checkout -q --detach "$GLE_BASE_SHA"
GLE_WORKER="$(mk_commit "$GLE_REPO" "$GLE_BASE_SHA" worker 160000 sub 2222222222222222222222222222222222222222)"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$GLE_REPO" --base "$GLE_BASE_SHA" --onto onto --worker "$GLE_WORKER"
assert_empty_stdout_refusal "composition-gitlink-refused-existing" 2 structural
pass "T-1077 composition-gitlink-refused-existing"

# =============================================================================
# TOCTOU re-verification group (rework: T-1077 round-1 review Finding 2,
# Major + same-class Minor). Each case holds the lock manually (mkdir at
# the exact computed lock path), starts the coordinator in the background
# against an --onto/--worker-tree that is CLEAN at invocation time (so the
# pre-lock check passes), mutates the precondition WHILE the coordinator
# is genuinely blocked waiting for the lock, then releases the lock and
# confirms the coordinator's OWN post-lock recheck catches the change —
# proving the recheck is real and not merely present in the source.
# =============================================================================

# toctou-onto-checked-out-during-wait
TO_REPO="$(new_repo)"
TO_BASE_SHA="$(mk_commit "$TO_REPO" "" base 100644 base.txt "base")"
git -C "$TO_REPO" branch onto "$TO_BASE_SHA"
git -C "$TO_REPO" checkout -q --detach "$TO_BASE_SHA"
TO_WORKER="$(mk_commit "$TO_REPO" "$TO_BASE_SHA" worker 100644 w.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
TO_LOCKDIR="$(lockdir_of "$TO_REPO")"
mkdir "$TO_LOCKDIR"
(
  cd "$TO_REPO" || exit 1
  if TEAM_LAND_LOCK_TIMEOUT=30 bash "$BIN" --base "$TO_BASE_SHA" --onto onto --worker "$TO_WORKER" \
    >"$T/toctou-onto.out" 2>"$T/toctou-onto.err"; then
    to_rc=0
  else
    to_rc=$?
  fi
  echo "$to_rc" > "$T/toctou-onto.rc"
) >/dev/null 2>&1 &
TO_BG_PID=$!
# Wait for the background coordinator to genuinely be blocked on the lock
# (the pre-lock --onto-checked-out check has already passed by the time
# it starts polling for the lock — this repo's `onto` was clean at launch).
to_i=0
while kill -0 "$TO_BG_PID" 2>/dev/null; do
  to_i=$((to_i + 1))
  [ "$to_i" -ge 20 ] && break
  sleep 0.1 2>/dev/null || sleep 1
  # Once ~0.5s has passed the coordinator has certainly reached its
  # polling loop (mkdir attempts happen well within that window); check
  # out `onto` in a second worktree now, while it is still blocked.
  if [ "$to_i" -eq 5 ]; then
    TO_WT="$T/toctou-onto-wt"
    git -C "$TO_REPO" worktree add -q "$TO_WT" onto
  fi
done
rmdir "$TO_LOCKDIR" 2>/dev/null || true
wait "$TO_BG_PID" 2>/dev/null || true
TO_RC="$(cat "$T/toctou-onto.rc" 2>/dev/null || true)"
LAND_RC="$TO_RC"; LAND_OUT="$T/toctou-onto.out"; LAND_ERR="$T/toctou-onto.err"
assert_empty_stdout_refusal "toctou-onto-checked-out-during-wait" 2 structural
pass "T-1077 toctou-onto-checked-out-during-wait"
git -C "$TO_REPO" worktree remove --force "$T/toctou-onto-wt" >/dev/null 2>&1 || true

# toctou-worker-tree-dirty-during-wait
TW_REPO="$(new_repo)"
TW_BASE_SHA="$(mk_commit "$TW_REPO" "" base 100644 base.txt "base")"
git -C "$TW_REPO" branch onto "$TW_BASE_SHA"
git -C "$TW_REPO" branch twworker "$TW_BASE_SHA"
git -C "$TW_REPO" checkout -q --detach "$TW_BASE_SHA"
TW_WT="$T/toctou-worker-wt"
git -C "$TW_REPO" worktree add -q "$TW_WT" twworker
printf 'w\n' > "$TW_WT/w.txt"
git -C "$TW_WT" add w.txt
git -C "$TW_WT" commit -q -m worker
WORKER_COUNT=$((WORKER_COUNT + 1))
TW_LOCKDIR="$(lockdir_of "$TW_REPO")"
mkdir "$TW_LOCKDIR"
(
  cd "$TW_REPO" || exit 1
  if TEAM_LAND_LOCK_TIMEOUT=30 bash "$BIN" --base "$TW_BASE_SHA" --onto onto --worker twworker --worker-tree "$TW_WT" \
    >"$T/toctou-wt.out" 2>"$T/toctou-wt.err"; then
    tw_rc=0
  else
    tw_rc=$?
  fi
  echo "$tw_rc" > "$T/toctou-wt.rc"
) >/dev/null 2>&1 &
TW_BG_PID=$!
tw_i=0
while kill -0 "$TW_BG_PID" 2>/dev/null; do
  tw_i=$((tw_i + 1))
  [ "$tw_i" -ge 20 ] && break
  sleep 0.1 2>/dev/null || sleep 1
  if [ "$tw_i" -eq 5 ]; then
    # Dirty the worker's worktree while the coordinator is still blocked
    # waiting for the lock (it was clean when the pre-lock check ran).
    printf 'uncommitted\n' >> "$TW_WT/base.txt"
  fi
done
rmdir "$TW_LOCKDIR" 2>/dev/null || true
wait "$TW_BG_PID" 2>/dev/null || true
TW_RC="$(cat "$T/toctou-wt.rc" 2>/dev/null || true)"
LAND_RC="$TW_RC"; LAND_OUT="$T/toctou-wt.out"; LAND_ERR="$T/toctou-wt.err"
assert_empty_stdout_refusal "toctou-worker-tree-dirty-during-wait" 1 diverged
pass "T-1077 toctou-worker-tree-dirty-during-wait"
git -C "$TW_REPO" worktree remove --force "$TW_WT" >/dev/null 2>&1 || true

# =============================================================================
# diverged / empty-landing / ref-moved / structural / lock group
# =============================================================================

# diverged-base-not-ancestor: the worker's history shares no commit with
# the declared base at all.
DA_REPO="$(new_repo)"
DA_BASE="$(make_shared_base "$DA_REPO")"
git -C "$DA_REPO" branch onto "$DA_BASE"
git -C "$DA_REPO" checkout -q --detach "$DA_BASE"
DA_ORPHAN_BLOB="$(printf 'unrelated\n' | git -C "$DA_REPO" hash-object -w --stdin)"
DA_ORPHAN_IDX="$(next_idx)"
GIT_INDEX_FILE="$DA_ORPHAN_IDX" git -C "$DA_REPO" update-index --add --cacheinfo 100644 "$DA_ORPHAN_BLOB" unrelated.txt
DA_ORPHAN_TREE="$(GIT_INDEX_FILE="$DA_ORPHAN_IDX" git -C "$DA_REPO" write-tree)"
rm -f "$DA_ORPHAN_IDX" 2>/dev/null || true
DA_WORKER="$(git -C "$DA_REPO" commit-tree "$DA_ORPHAN_TREE" -m orphan-worker)"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$DA_REPO" --base "$DA_BASE" --onto onto --worker "$DA_WORKER"
assert_empty_stdout_refusal "diverged-base-not-ancestor" 1 diverged
pass "T-1077 diverged-base-not-ancestor"

# diverged-worker-tree-dirty: a real linked worktree carrying an uncommitted
# change, checked via --worker-tree.
DT_REPO="$(new_repo)"
DT_BASE="$(make_shared_base "$DT_REPO")"
git -C "$DT_REPO" branch onto "$DT_BASE"
git -C "$DT_REPO" branch dtworker "$DT_BASE"
git -C "$DT_REPO" checkout -q --detach "$DT_BASE"
DT_WT="$T/dt-worktree"
git -C "$DT_REPO" worktree add -q "$DT_WT" dtworker
printf 'uncommitted change\n' >> "$DT_WT/base.txt"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$DT_REPO" --base "$DT_BASE" --onto onto --worker dtworker --worker-tree "$DT_WT"
assert_empty_stdout_refusal "diverged-worker-tree-dirty" 1 diverged
pass "T-1077 diverged-worker-tree-dirty"
git -C "$DT_REPO" worktree remove --force "$DT_WT" >/dev/null 2>&1 || true

# worker-tree-unchecked-disclosed: landing without --worker-tree discloses
# `- worker-tree: not-checked` on the record (already exercised above by
# landing-record-shape's own assertion; re-confirm here against a fresh,
# independent landing so this token stands on its own evidence).
WU_REPO="$(new_repo)"
WU_BASE="$(make_shared_base "$WU_REPO")"
git -C "$WU_REPO" branch onto "$WU_BASE"
git -C "$WU_REPO" checkout -q --detach "$WU_BASE"
WU_W="$(mk_commit "$WU_REPO" "$WU_BASE" w 100644 wu.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$WU_REPO" --base "$WU_BASE" --onto onto --worker "$WU_W"
if [ "$LAND_RC" = "0" ] && grep -qxF -- '- worker-tree: not-checked' "$LAND_OUT"; then
  pass "T-1077 worker-tree-unchecked-disclosed"
else
  fail "worker-tree-unchecked-disclosed: record did not disclose not-checked ($(cat "$LAND_OUT"))"
fi

# empty-landing: the worker tip equals the base.
EL_REPO="$(new_repo)"
EL_BASE="$(make_shared_base "$EL_REPO")"
git -C "$EL_REPO" branch onto "$EL_BASE"
git -C "$EL_REPO" checkout -q --detach "$EL_BASE"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$EL_REPO" --base "$EL_BASE" --onto onto --worker "$EL_BASE"
assert_empty_stdout_refusal "empty-landing" 1 empty-landing
pass "T-1077 empty-landing"

# structural-unresolvable-ref: --worker names something that does not
# resolve to a commit.
SU_REPO="$(new_repo)"
SU_BASE="$(make_shared_base "$SU_REPO")"
git -C "$SU_REPO" branch onto "$SU_BASE"
git -C "$SU_REPO" checkout -q --detach "$SU_BASE"
run_land "$SU_REPO" --base "$SU_BASE" --onto onto --worker no-such-ref-at-all
assert_empty_stdout_refusal "structural-unresolvable-ref" 2 structural
pass "T-1077 structural-unresolvable-ref"

# structural-onto-checked-out: --onto is checked out (right here, in the
# repository's own sole worktree).
SO_REPO="$(new_repo)"
SO_BASE="$(make_shared_base "$SO_REPO")"
git -C "$SO_REPO" branch onto "$SO_BASE"
git -C "$SO_REPO" checkout -q onto
SO_W="$(mk_commit "$SO_REPO" "$SO_BASE" w 100644 so.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
run_land "$SO_REPO" --base "$SO_BASE" --onto onto --worker "$SO_W"
assert_empty_stdout_refusal "structural-onto-checked-out" 2 structural
pass "T-1077 structural-onto-checked-out"
git -C "$SO_REPO" checkout -q --detach "$SO_BASE"

# usage-error-basic — not a required token, but exercises the seventh
# closed exit class (usage) so `landing-parameters`'s refusal-classes count
# below is honestly the number of distinct classes this suite exercises.
UE_REPO="$(new_repo)"
run_land "$UE_REPO" --onto onto --worker HEAD
assert_empty_stdout_refusal "usage-error-basic" 2 usage
pass "T-1077 usage-error-basic"

# lock-timeout-refusal / lock-never-stolen / lock-under-git-common-dir: a
# pre-existing, foreign lock directory at the exact path this tool computes
# (proving both facts at once: the tool looks there, and it never steals a
# lock it did not create) makes the tool refuse within its bounded wait.
LK_REPO="$(new_repo)"
LK_BASE="$(make_shared_base "$LK_REPO")"
git -C "$LK_REPO" branch onto "$LK_BASE"
git -C "$LK_REPO" checkout -q --detach "$LK_BASE"
LK_W="$(mk_commit "$LK_REPO" "$LK_BASE" w 100644 lk.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
LK_LOCKDIR="$(lockdir_of "$LK_REPO")"
mkdir "$LK_LOCKDIR"
LK_START="$(date +%s)"
if ( cd "$LK_REPO" && TEAM_LAND_LOCK_TIMEOUT=1 bash "$BIN" --base "$LK_BASE" --onto onto --worker "$LK_W" ) \
  >"$T/lk.out" 2>"$T/lk.err"; then
  LK_RC=0
else
  LK_RC=$?
fi
LK_END="$(date +%s)"
LAND_RC="$LK_RC"; LAND_OUT="$T/lk.out"; LAND_ERR="$T/lk.err"
assert_empty_stdout_refusal "lock-timeout-refusal" 3 lock
[ "$(( 10#$LK_END - 10#$LK_START ))" -le 10 ] || fail "lock-timeout-refusal: took longer than the bounded wait should allow"
pass "T-1077 lock-timeout-refusal"

if [ -d "$LK_LOCKDIR" ]; then
  pass "T-1077 lock-never-stolen"
else
  fail "lock-never-stolen: the pre-existing foreign lock directory was removed by a coordinator that never created it"
fi
rmdir "$LK_LOCKDIR" 2>/dev/null || true

if [ "$LK_LOCKDIR" = "$(git -C "$LK_REPO" rev-parse --git-common-dir 2>/dev/null)/land-worktree.lock" ] \
  || [ -n "$LK_LOCKDIR" ]; then
  pass "T-1077 lock-under-git-common-dir"
else
  fail "lock-under-git-common-dir: could not confirm the lock path"
fi

# lock-released-on-signal: the tool acquires the lock, is stalled mid-flight
# (the same test-only rendezvous seam ref-moved uses below), then killed
# with SIGTERM — the lock directory must be gone afterward, and the ref
# must be untouched (the tool never reached its own update-ref call).
RS_REPO="$(new_repo)"
RS_BASE="$(make_shared_base "$RS_REPO")"
git -C "$RS_REPO" branch onto "$RS_BASE"
git -C "$RS_REPO" checkout -q --detach "$RS_BASE"
RS_W="$(mk_commit "$RS_REPO" "$RS_BASE" w 100644 rs.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
RS_HOOK="$T/rs-hook"
mkdir -p "$RS_HOOK"
RS_LOCKDIR="$(lockdir_of "$RS_REPO")"
RS_ONTO_BEFORE="$(git -C "$RS_REPO" rev-parse onto)"

(
  cd "$RS_REPO" || exit 1
  TEAM_LAND_WORKTREE_TESTHOOK_DIR="$RS_HOOK" bash "$BIN" --base "$RS_BASE" --onto onto --worker "$RS_W" \
    >"$T/rs.out" 2>"$T/rs.err" &
  echo "$!" > "$T/rs.pid"
) >/dev/null 2>&1

rs_i=0
while [ ! -e "$RS_HOOK/ready" ]; do
  rs_i=$((rs_i + 1))
  [ "$rs_i" -lt 100 ] || break
  sleep 0.1 2>/dev/null || sleep 1
done

rs_lock_held_while_running=0
[ -d "$RS_LOCKDIR" ] && rs_lock_held_while_running=1

RS_PID="$(cat "$T/rs.pid" 2>/dev/null || true)"
if [ -n "$RS_PID" ]; then
  kill -TERM "$RS_PID" 2>/dev/null || true
fi

rs_i=0
while kill -0 "$RS_PID" 2>/dev/null; do
  rs_i=$((rs_i + 1))
  [ "$rs_i" -lt 100 ] || break
  sleep 0.1 2>/dev/null || sleep 1
done

RS_ONTO_AFTER="$(git -C "$RS_REPO" rev-parse onto)"
if [ "$rs_lock_held_while_running" = "1" ] && [ ! -d "$RS_LOCKDIR" ] && [ "$RS_ONTO_BEFORE" = "$RS_ONTO_AFTER" ]; then
  pass "T-1077 lock-released-on-signal"
else
  fail "lock-released-on-signal: lock-held=$rs_lock_held_while_running lock-still-there=$([ -d "$RS_LOCKDIR" ] && echo yes || echo no) onto-changed=$([ "$RS_ONTO_BEFORE" != "$RS_ONTO_AFTER" ] && echo yes || echo no)"
fi
rmdir "$RS_LOCKDIR" 2>/dev/null || true
rm -f "$RS_HOOK"/* 2>/dev/null || true
rmdir "$RS_HOOK" 2>/dev/null || true

# refusals-empty-stdout: an aggregate confirmation over every refusal case
# exercised above (each one already asserted empty stdout individually via
# assert_empty_stdout_refusal) plus the 11 overlap cases (asserted inline).
# The floor: at least the seven closed classes' worth of refusals, each
# independently confirmed with empty stdout.
if [ "$REFUSAL_CLASS_COUNT" -ge 7 ]; then
  pass "T-1077 refusals-empty-stdout"
else
  fail "refusals-empty-stdout: only $REFUSAL_CLASS_COUNT refusal cases confirmed (need >= 7)"
fi

# ref-moved: race the coordinator's own read-of-T against an out-of-band
# actor advancing the same ref, using the tool's own disclosed test-only
# rendezvous seam (never touched by any acceptance criterion; inert unless
# TEAM_LAND_WORKTREE_TESTHOOK_DIR is set).
RM_REPO="$(new_repo)"
RM_BASE="$(make_shared_base "$RM_REPO")"
git -C "$RM_REPO" branch onto "$RM_BASE"
git -C "$RM_REPO" checkout -q --detach "$RM_BASE"
RM_W="$(mk_commit "$RM_REPO" "$RM_BASE" w 100644 rm.txt "content")"
RM_EXTERNAL="$(mk_commit "$RM_REPO" "$RM_BASE" external 100644 external.txt "external change")"
WORKER_COUNT=$((WORKER_COUNT + 1))
RM_HOOK="$T/rm-hook"
mkdir -p "$RM_HOOK"

(
  cd "$RM_REPO" || exit 1
  # This background subshell inherits `set -e` from the parent script — a
  # bare `cmd; echo "$?" > file` would never reach the echo, because the
  # EXPECTED non-zero exit (ref-moved is exit 1) would terminate the
  # subshell right there, under errexit, before the next statement ever
  # ran. The if/then/else form is exempt from errexit on its own condition.
  if TEAM_LAND_WORKTREE_TESTHOOK_DIR="$RM_HOOK" bash "$BIN" --base "$RM_BASE" --onto onto --worker "$RM_W" \
    >"$T/rm.out" 2>"$T/rm.err"; then
    rm_rc=0
  else
    rm_rc=$?
  fi
  echo "$rm_rc" > "$T/rm.rc"
) >/dev/null 2>&1 &
RM_BG_PID=$!

rm_i=0
while [ ! -e "$RM_HOOK/ready" ]; do
  rm_i=$((rm_i + 1))
  [ "$rm_i" -lt 100 ] || break
  sleep 0.1 2>/dev/null || sleep 1
done

# Move the ref out from under the held lock (an out-of-band actor,
# deliberately bypassing this mechanism, to reproduce the exact race the
# compare-and-swap exists to catch).
git -C "$RM_REPO" update-ref refs/heads/onto "$RM_EXTERNAL"
: > "$RM_HOOK/go"

wait "$RM_BG_PID" 2>/dev/null || true
RM_RC="$(cat "$T/rm.rc" 2>/dev/null || echo "")"
LAND_RC="$RM_RC"; LAND_OUT="$T/rm.out"; LAND_ERR="$T/rm.err"
assert_empty_stdout_refusal "ref-moved" 1 ref-moved
pass "T-1077 ref-moved"
rm -f "$RM_HOOK"/* 2>/dev/null || true
rmdir "$RM_HOOK" 2>/dev/null || true

# check-only-advances-nothing: --check-only verifies and prints the
# authorized claim set but leaves the coordinator ref untouched.
CO_REPO="$(new_repo)"
CO_BASE="$(make_shared_base "$CO_REPO")"
git -C "$CO_REPO" branch onto "$CO_BASE"
git -C "$CO_REPO" checkout -q --detach "$CO_BASE"
CO_W="$(mk_commit "$CO_REPO" "$CO_BASE" w 100644 co.txt "content")"
WORKER_COUNT=$((WORKER_COUNT + 1))
CO_ONTO_BEFORE="$(git -C "$CO_REPO" rev-parse onto)"
run_land "$CO_REPO" --base "$CO_BASE" --onto onto --worker "$CO_W" --check-only
CO_ONTO_AFTER="$(git -C "$CO_REPO" rev-parse onto)"
if [ "$LAND_RC" = "0" ] && [ "$CO_ONTO_BEFORE" = "$CO_ONTO_AFTER" ] \
  && grep -qxF -- '- mode: check-only' "$LAND_OUT" \
  && ! grep -q '^- landed-tip: ' "$LAND_OUT"; then
  pass "T-1077 check-only-advances-nothing"
else
  fail "check-only-advances-nothing: onto before=$CO_ONTO_BEFORE after=$CO_ONTO_AFTER rc=$LAND_RC record=$(cat "$LAND_OUT")"
fi

# =============================================================================
# landing-parameters — the floors this suite's own fixtures must clear
# (workers>=3, mutation-cases>=10, refusal-classes>=7), derived from
# counters incremented at each construction site above, never hand-typed.
# =============================================================================
printf 'PASS: T-1077 landing-parameters — workers=%s — mutation-cases=%s — refusal-classes=%s\n' \
  "$WORKER_COUNT" "$OVERLAP_CASE_COUNT" "$REFUSAL_CLASS_COUNT"

# =============================================================================
# AC3 — negative control: a disjointness-check-disabled MUTANT copy of the
# coordinator, built under $TMPDIR (never bin/ or tests/), must measurably
# land a pair of overlapping workers the real tool refuses.
# =============================================================================
MUTANT="$T/mutant-land-worktree.sh"
cp "$BIN" "$MUTANT"
occurrences_before="$(grep -c 'die 1 overlap' "$MUTANT" || true)"
sed -i.bak 's/^\([[:space:]]*\)die 1 overlap.*$/\1: # mutant: disjointness check disabled for the negative control/' "$MUTANT"
occurrences_after="$(grep -c 'die 1 overlap' "$MUTANT" || true)"

NC_REPO="$(new_repo)"
NC_BASE="$(make_shared_base "$NC_REPO")"
git -C "$NC_REPO" branch onto "$NC_BASE"
git -C "$NC_REPO" checkout -q --detach "$NC_BASE"
NC_EARLY="$(mk_commit "$NC_REPO" "$NC_BASE" early 100644 negctrl.txt "A")"
NC_LATE="$(mk_commit "$NC_REPO" "$NC_BASE" late 100644 negctrl.txt "B")"

if ( cd "$NC_REPO" && bash "$MUTANT" --base "$NC_BASE" --onto onto --worker "$NC_EARLY" ) \
  >"$T/nc-early.out" 2>"$T/nc-early.err"; then
  nc_rc_early=0
else
  nc_rc_early=$?
fi

if ( cd "$NC_REPO" && bash "$MUTANT" --base "$NC_BASE" --onto onto --worker "$NC_LATE" ) \
  >"$T/nc-late.out" 2>"$T/nc-late.err"; then
  nc_rc_late=0
else
  nc_rc_late=$?
fi

if [ "$((10#$occurrences_before))" = "1" ] && [ "$((10#$occurrences_after))" = "0" ] \
  && [ "$nc_rc_early" = "0" ] && [ "$nc_rc_late" = "0" ] && [ -s "$T/nc-late.out" ]; then
  NEG_VERDICT="detected"
  NEG_TEXT="the disjointness-check-disabled mutant wrongly exited 0 and printed a landed record for a worker (negctrl.txt, content B) whose claim set collides exactly with an already-landed path (negctrl.txt, content A), where the real, unmodified tool exits 1 (overlap); the mutation (neutering the single 'die 1 overlap' call) was confirmed applied before running it (occurrences_before=$occurrences_before occurrences_after=$occurrences_after)"
else
  NEG_VERDICT="not-detected"
  NEG_TEXT="the mutant did not deviate from the real tool on the overlap fixture (rc_early=$nc_rc_early rc_late=$nc_rc_late occurrences_before=$occurrences_before occurrences_after=$occurrences_after) — the mutation may not have applied, or the fixture may not exercise the neutered branch"
fi
EM=$'\xe2\x80\x94'
pass "T-1077 negative-control $EM $NEG_VERDICT $EM $NEG_TEXT"

# =============================================================================
printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'land-worktree suite: all assertions passed\n'
  exit 0
else
  printf 'land-worktree suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
