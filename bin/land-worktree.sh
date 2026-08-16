#!/usr/bin/env bash
# land-worktree.sh — a single serializing coordinator that lands one worker's
# committed work onto one task branch, behind a never-stealing lock, refusing
# on a machine-checked path-disjointness violation (T-1077;
# .shell-team/specs/T-1077-worktree-reconcile.md).
#
# Problem this closes: skills/run/SKILL.md's own T-055 isolation bullet used
# to declare that integrating 2+ concurrent worktrees into one branch is NOT
# covered — after the first --ff-only merge advances HEAD, a second worktree
# reset onto the same original base can no longer fast-forward. This script
# is the mechanism that closes it: it composes each worker's changed paths
# onto the coordinator branch's CURRENT tip rather than rebasing anyone, so
# N workers can land in sequence without any of them ever being reset.
#
# Design (D1-D7 of the frozen spec, summarized; the spec is the contract):
#   D1 — no rebase happens here at all (D5), so no agent-gate verdict is ever
#        invalidated by a rewrite; the orchestration step (not this script)
#        decides when the two agent gates re-run.
#   D2 — the guarantee this script verifies is PATH-LEVEL and TEXTUAL ONLY.
#        It does NOT guarantee semantic or interface independence: worker A
#        may change a signature worker B calls from a file A never touched,
#        and both land. This is a consequence of what does not exist (this
#        repository's spec-partition grammar), not a bound this script's own
#        design chooses to leave open.
#   D3 — mutual exclusion is a plain `mkdir` directory lock (NEVER
#        `mkdir -p`) under the absolutized shared git directory
#        (`git rev-parse --git-common-dir`), bounded wait default 10s
#        (TEAM_LAND_LOCK_TIMEOUT), never stolen, released with `rmdir` only.
#        No persistent queue state exists anywhere: the set of paths already
#        landed is derived fresh from git at the moment the lock is held.
#   D4 — a worker whose history does not descend from the declared base, or
#        whose worktree carries uncommitted/untracked-non-ignored work, is
#        refused (`diverged`) and NOTHING is auto-rebased, reset, or checked
#        out. `--worker-tree` is optional; its omission is disclosed on the
#        landing record as `- worker-tree: not-checked` rather than silently
#        skipped.
#   D5 — the landing COMPOSES a tree (coordinator tip's tree with exactly the
#        worker's claimed paths taking their state at the worker tip) and
#        writes a two-parent commit (coordinator tip first, worker tip
#        second) via plumbing only — no worktree is ever checked out, no
#        index but a private scratch one is ever written, no branch other
#        than the coordinator ref is ever touched. The ref advances by
#        compare-and-swap (`git update-ref <ref> <new> <old>`); a ref that
#        moved underneath the operation refuses (`ref-moved`) rather than
#        clobbering. `--onto` checked out in any worktree of this repository
#        is refused (`structural`).
#   D6 — seven exit classes, closed, one classified stderr line each, in the
#        shape `land-worktree: <class>: <detail>`; stdout is EMPTY on every
#        non-zero exit.
#          0  landed (or, with --check-only, authorized) — record on stdout
#          1  refusal about the landing's own content: overlap, diverged,
#             empty-landing, ref-moved
#          2  usage error about the invocation: usage, structural
#          3  the coordinator could not take its turn within the bounded
#             wait: lock
#   D7 — disjointness is a CLASS, not one case: two claim sets overlap when
#        (a) the same path appears in both (exact), (b) one path is a
#        directory-prefix of the other (`x` vs `x/y` — the dir/file
#        replacement case no string-equality test can see), or (c) two paths
#        are equal after ASCII case-fold but not byte-equal. Claim sets are
#        derived NUL-separated and rename-blind (`--no-renames`, so a rename
#        claims both its old and new path), and are unaffected by
#        core.quotepath. A path that cannot be represented on one line (one
#        carrying a newline) is emitted into the landing record C-escaped
#        (bash's own `printf '%q'`), so one claimed path is always exactly
#        one record line.
#
# Non-goals (frozen spec): no semantic/interface independence guarantee, no
# spec-partition grammar, no rebase/reset/checkout/cherry-pick/force-update/
# branch-deletion of a worker's committed work, no execution surface (this
# script runs no caller-supplied command and creates no scratch worktree),
# no cross-host/NFS locking claim, no crash-consistency/durability claim.
#
# Usage:
#   land-worktree.sh --base <ref> --onto <branch> --worker <ref>
#                     [--worker-tree <path>] [--check-only]
#   land-worktree.sh --help
#
# Zero-dependency floor (this repository's bin/ convention): bash 3.2 (no
# mapfile/declare -A/coproc/;;&/[[ -v ]]/case-modification parameter
# expansion), coreutils and git only — no jq/perl/python/yq, no grep -P.
# LC_ALL=C is pinned for the whole run so a caller's ambient locale never
# reaches a string comparison.

set -euo pipefail

export LC_ALL=C

PROG="land-worktree"

# die <exit-code> <class> <detail> — the one closed stderr shape every
# refusal in this script uses (mirrors bin/aggregate-verdicts.sh's own
# die()). Best-effort write so a caller with a closed stderr can never steal
# this call's own exit code via errexit.
die() {
  printf '%s: %s: %s\n' "$PROG" "$2" "$3" >&2 || true
  exit "$1"
}

print_help() {
  cat <<'EOF'
Usage:
  land-worktree.sh --base <ref> --onto <branch> --worker <ref>
                    [--worker-tree <path>] [--check-only]
  land-worktree.sh --help

A single serializing coordinator: lands one worker's committed work onto one
task branch behind a never-stealing lock, refusing on a machine-checked
path-disjointness violation. Never rebases, resets or checks out anything —
it composes a tree and writes a two-parent commit via plumbing only.

Flags:
  --base <ref>          the base commit every worker branched from
  --onto <branch>       the coordinator branch this landing advances; its
                         CURRENT tip is read fresh, under the lock, every
                         call — never assumed from a prior invocation
  --worker <ref>        the worker's tip commit to land
  --worker-tree <path>  optional: a worktree of this repository to check for
                         uncommitted or untracked-non-ignored work before
                         landing; when omitted the landing record discloses
                         `- worker-tree: not-checked` rather than silently
                         skipping the check
  --check-only          verify disjointness and divergence and print the
                         authorized claim set without composing or
                         advancing anything
  --help, -h            show this help and exit 0

Exit codes:
  0  landed (or, with --check-only, authorized) — the record is on stdout
  1  refusal about the landing's own content (overlap, diverged,
     empty-landing, ref-moved)
  2  usage error about the invocation (usage, structural)
  3  the coordinator could not take its turn within the bounded wait (lock)

The seven refusal classes, closed:
  overlap        the worker's claimed paths intersect what is already landed
                 (exact, directory-prefix, or ASCII-case-fold — D7)
  diverged       the worker's history does not descend from the declared
                 base, or its worktree carries uncommitted/untracked work
  empty-landing  the worker tip carries nothing beyond the base
  ref-moved      the coordinator ref advanced outside this mechanism between
                 the read and the write; re-derive the claim sets and retry
  usage          a missing, unknown or malformed flag
  structural     a named input is not there or not usable (not a git
                 repository, a ref that does not resolve, an --onto that is
                 checked out, a --worker-tree that is not a worktree of
                 this repository)
  lock           the coordinator could not acquire its turn within the
                 bounded wait (TEAM_LAND_LOCK_TIMEOUT, default 10s)

On every non-zero exit, stdout is empty: nothing is printed until every
check has passed, so no partial or unauthorized landing record can ever be
read as an authorization.
EOF
}

# --- argument parsing --------------------------------------------------------
BASE_ARG=""
ONTO_ARG=""
WORKER_ARG=""
WORKER_TREE=""
CHECK_ONLY=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --base)
      [ "$#" -ge 2 ] || die 2 usage "--base requires a value"
      shift
      BASE_ARG="$1"
      shift
      ;;
    --onto)
      [ "$#" -ge 2 ] || die 2 usage "--onto requires a value"
      shift
      ONTO_ARG="$1"
      shift
      ;;
    --worker)
      [ "$#" -ge 2 ] || die 2 usage "--worker requires a value"
      shift
      WORKER_ARG="$1"
      shift
      ;;
    --worker-tree)
      [ "$#" -ge 2 ] || die 2 usage "--worker-tree requires a value"
      shift
      WORKER_TREE="$1"
      shift
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    --*)
      die 2 usage "unknown flag: $1"
      ;;
    *)
      die 2 usage "unexpected argument: $1"
      ;;
  esac
done

[ -n "$BASE_ARG" ]   || die 2 usage "missing required --base"
[ -n "$ONTO_ARG" ]   || die 2 usage "missing required --onto"
[ -n "$WORKER_ARG" ] || die 2 usage "missing required --worker"

# --- structural preconditions ------------------------------------------------
git rev-parse --git-dir >/dev/null 2>&1 \
  || die 2 structural "not inside a git repository (or any of its parent directories)"

B="$(git rev-parse --verify --quiet "${BASE_ARG}^{commit}" 2>/dev/null)" \
  || die 2 structural "--base does not resolve to a commit: $BASE_ARG"
W="$(git rev-parse --verify --quiet "${WORKER_ARG}^{commit}" 2>/dev/null)" \
  || die 2 structural "--worker does not resolve to a commit: $WORKER_ARG"

case "$ONTO_ARG" in
  refs/*) ONTO_REF="$ONTO_ARG" ;;
  *)      ONTO_REF="refs/heads/$ONTO_ARG" ;;
esac
git rev-parse --verify --quiet "${ONTO_REF}^{commit}" >/dev/null 2>&1 \
  || die 2 structural "--onto does not resolve to a commit: $ONTO_ARG ($ONTO_REF)"

# Absolutize the shared git directory (D3): `git rev-parse --git-common-dir`
# can return a path relative to the CURRENT worktree, not the repository
# root — a coordinator invoked from a linked worktree must resolve to the
# SAME absolute lock path as one invoked from the main checkout, or the
# never-stealing lock silently stops serializing anything. `cd ... && pwd -P`
# (PHYSICAL, symlink-resolved) rather than plain `pwd`, and unconditionally
# — regardless of whether git-common-dir already reported an absolute path
# — because a caller's cwd can itself be reached through a symlinked
# ancestor (e.g. macOS's `/tmp` -> `/private/tmp`): `cd` tracks the LOGICAL
# path taken to get there, but `git worktree add` canonicalizes the path it
# records for a linked worktree's own git-common-dir. Comparing a logical
# path against git's own physical one — the exact mismatch this fixes —
# would make an identical directory read as two different strings and
# reject a perfectly ordinary --worker-tree.
GCD_RAW="$(git rev-parse --git-common-dir)" \
  || die 2 structural "cannot resolve the shared git directory"
GCD="$(cd "$GCD_RAW" && pwd -P)" \
  || die 2 structural "cannot resolve the shared git directory's physical path: $GCD_RAW"
LOCK_DIR="$GCD/land-worktree.lock"

# A private scratch directory for this invocation only: the composed
# per-call index file, and small captured-output files below. Flat (no
# subdirectories are ever created inside it), so cleanup never needs a
# recursive removal.
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/land-worktree.XXXXXX")" \
  || die 2 structural "cannot create a scratch directory under \${TMPDIR:-/tmp}"

# --onto must not be checked out in ANY worktree of this repository (D5):
# advancing a checked-out branch's ref by compare-and-swap would leave that
# worktree's own index and working tree silently disagreeing with it. Read
# into a file first, not piped straight into `grep -q` — under `pipefail`,
# `grep -q`'s early exit on the first match can SIGPIPE the upstream
# `git worktree list` and turn a genuine match into a spurious pipeline
# failure (repo lesson).
WT_LIST="$WORKDIR/worktrees.list"
git worktree list --porcelain > "$WT_LIST" 2>/dev/null \
  || die 2 structural "failed to enumerate this repository's worktrees"
if grep -qxF "branch $ONTO_REF" "$WT_LIST"; then
  die 2 structural "--onto ($ONTO_ARG -> $ONTO_REF) is checked out in a worktree of this repository"
fi

# --worker-tree, if given, must genuinely be a worktree of THIS repository
# (identity is the shared git directory, the authoritative test — two
# worktrees of the same repository always share the identical
# git-common-dir, by construction).
WORKER_TREE_LINE="not-checked"
if [ -n "$WORKER_TREE" ]; then
  [ -d "$WORKER_TREE" ] || die 2 structural "--worker-tree is not a directory: $WORKER_TREE"
  WT_GCD_RAW="$(git -C "$WORKER_TREE" rev-parse --git-common-dir 2>/dev/null)" \
    || die 2 structural "--worker-tree is not inside a git repository: $WORKER_TREE"
  # Unified relative/absolute handling, same physical-path reasoning as
  # GCD's own resolution above: `cd` into $WORKER_TREE first (so a
  # relative $WT_GCD_RAW resolves against the right directory), then into
  # $WT_GCD_RAW itself (works whether it is relative or already absolute —
  # `cd` accepts both), then `pwd -P` for the physical form.
  WT_GCD="$(cd "$WORKER_TREE" && cd "$WT_GCD_RAW" && pwd -P)" \
    || die 2 structural "cannot resolve --worker-tree's git common directory: $WORKER_TREE"
  [ "$WT_GCD" = "$GCD" ] \
    || die 2 structural "--worker-tree is not a worktree of this repository: $WORKER_TREE"
  WORKER_TREE_LINE="$WORKER_TREE"
fi

# --- content refusals independent of the coordinator ref (D4/D6, exit 1) ----
if git merge-base --is-ancestor "$B" "$W"; then
  rc_anc=0
else
  rc_anc=$?
fi
if [ "$rc_anc" -eq 1 ]; then
  die 1 diverged "the worker's history ($WORKER_ARG) does not descend from the declared base ($BASE_ARG)"
elif [ "$rc_anc" -ne 0 ]; then
  die 2 structural "git merge-base --is-ancestor failed unexpectedly (exit $rc_anc)"
fi

if [ -n "$WORKER_TREE" ]; then
  WT_DIRTY="$(git -C "$WORKER_TREE" status --porcelain --untracked-files=normal 2>&1)" \
    || die 2 structural "failed to read --worker-tree status: $WORKER_TREE"
  if [ -n "$WT_DIRTY" ]; then
    die 1 diverged "the worker's worktree ($WORKER_TREE) carries uncommitted or untracked-non-ignored changes"
  fi
fi

if git diff --quiet "$B" "$W"; then
  rc_diff=0
else
  rc_diff=$?
fi
if [ "$rc_diff" -eq 0 ]; then
  die 1 empty-landing "the worker tip ($WORKER_ARG) carries nothing beyond the base ($BASE_ARG)"
elif [ "$rc_diff" -gt 1 ]; then
  die 2 structural "git diff failed comparing base and worker tip (exit $rc_diff)"
fi

# --- the never-stealing lock (D3, mirrors bin/log-run.sh:590-647) -----------
LOCK_TIMEOUT="${TEAM_LAND_LOCK_TIMEOUT:-10}"
case "$LOCK_TIMEOUT" in
  ''|*[!0-9]*)
    printf '%s: ignoring invalid TEAM_LAND_LOCK_TIMEOUT=%s, using default 10\n' "$PROG" "$LOCK_TIMEOUT" >&2 || true
    LOCK_TIMEOUT=10
    ;;
  *)
    if [ "$((10#$LOCK_TIMEOUT))" -le 0 ]; then
      printf '%s: ignoring invalid TEAM_LAND_LOCK_TIMEOUT=%s, using default 10\n' "$PROG" "$LOCK_TIMEOUT" >&2 || true
      LOCK_TIMEOUT=10
    fi
    ;;
esac

LOCK_ACQUIRED=0

# release_lock_and_cleanup — released ONLY for a lock this process itself
# acquired (the guard flag), via `rmdir` only (never a forced/recursive
# removal, so this can never destroy a sibling's contents), and also removes
# this call's own private scratch directory (flat, so no recursive removal
# is ever needed for it either). Both the acquire-side flag-set and this
# release are bracketed with `trap '' INT TERM`: a signal delivered while a
# signal's disposition is SIG_IGN is discarded by the kernel outright, never
# queued for later delivery, closing the exact signal-race window
# bin/log-run.sh's own T-1076 round documented and fixed.
# shellcheck disable=SC2329 # invoked indirectly, via the EXIT trap below
release_lock_and_cleanup() {
  trap '' INT TERM
  if [ "$LOCK_ACQUIRED" = "1" ]; then
    LOCK_ACQUIRED=0
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
    rm -f "$WORKDIR"/* 2>/dev/null || true
    rmdir "$WORKDIR" 2>/dev/null || true
  fi
  trap 'on_lock_signal INT 130' INT
  trap 'on_lock_signal TERM 143' TERM
}
trap release_lock_and_cleanup EXIT
# shellcheck disable=SC2329  # invoked indirectly via the signal traps below
on_lock_signal() {  # $1 = signal name (unused), $2 = the conventional 128+N exit code
  release_lock_and_cleanup
  exit "$2"
}
trap 'on_lock_signal INT 130' INT
trap 'on_lock_signal TERM 143' TERM

lock_start="$(date +%s)"
while :; do
  # The mkdir-attempt-then-flag-set pair is masked start to finish, so a
  # signal landing anywhere between `mkdir` returning and `LOCK_ACQUIRED=1`
  # executing is simply dropped rather than observed with a half-updated
  # flag (mirrors bin/log-run.sh's own fix, this repo's T-1076 round).
  trap '' INT TERM
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=1
  fi
  trap 'on_lock_signal INT 130' INT
  trap 'on_lock_signal TERM 143' TERM
  [ "$LOCK_ACQUIRED" = "1" ] && break
  lock_now="$(date +%s)"
  if [ "$(( 10#$lock_now - 10#$lock_start ))" -ge "$((10#$LOCK_TIMEOUT))" ]; then
    die 3 lock "could not acquire $LOCK_DIR within ${LOCK_TIMEOUT}s — refusing to land. If the process that created it was killed, remove it by hand: rmdir $LOCK_DIR"
  fi
  # Whole-second retry granularity (measured on this host: fractional sleep
  # also works, but whole-second polling matches bin/log-run.sh's own
  # chosen portability bound toward an unknown adopter host — recorded in
  # .shell-team/test-recipe.md's T-1077 entry).
  sleep 1
done

# =============================================================================
# --- critical section: everything below runs with the lock held ------------
# =============================================================================

T="$(git rev-parse --verify --quiet "${ONTO_REF}^{commit}" 2>/dev/null)" \
  || die 2 structural "--onto no longer resolves to a commit: $ONTO_ARG ($ONTO_REF)"

# Claim sets (D3/D7): derived fresh from git, NUL-separated, rename-blind
# (--no-renames, so a rename claims both its old and new path), unaffected
# by core.quotepath (-z always emits raw, unquoted path bytes). "Already
# landed" is exactly the spec's own derivation: the diff between the
# declared base and the coordinator ref's CURRENT tip, read under this
# same lock acquisition.
WORKER_RAW="$WORKDIR/worker.raw0"
LANDED_RAW="$WORKDIR/landed.raw0"
git diff --name-only -z --no-renames "$B" "$W" > "$WORKER_RAW" \
  || die 2 structural "failed to derive the worker's claimed paths"
git diff --name-only -z --no-renames "$B"..."$T" > "$LANDED_RAW" \
  || die 2 structural "failed to derive the already-landed paths"

declare -a WPATHS=()
declare -a WFOLD=()
WCOUNT=0
while IFS= read -r -d '' p; do
  WPATHS[WCOUNT]="$p"
  # ASCII-only fold, deliberately (D7): [:upper:]/[:lower:] are LOCALE-
  # dependent, and LC_ALL=C is pinned above precisely so this fold never
  # drifts with an operator's ambient locale.
  # shellcheck disable=SC2018,SC2019
  WFOLD[WCOUNT]="$(printf '%s' "$p" | tr 'A-Z' 'a-z')"
  WCOUNT=$((WCOUNT + 1))
done < "$WORKER_RAW"

declare -a LPATHS=()
declare -a LFOLD=()
LCOUNT=0
while IFS= read -r -d '' p; do
  LPATHS[LCOUNT]="$p"
  # shellcheck disable=SC2018,SC2019
  LFOLD[LCOUNT]="$(printf '%s' "$p" | tr 'A-Z' 'a-z')"
  LCOUNT=$((LCOUNT + 1))
done < "$LANDED_RAW"

# is_prefix <maybe-dir> <candidate> — is <maybe-dir> a directory-prefix of
# <candidate> (i.e. <candidate> == <maybe-dir> + "/" + something)? Pure
# substring/length comparison, deliberately NOT bash glob/case matching:
# a case pattern built by interpolating a path into `"$a"/*` would
# misinterpret a literal glob metacharacter inside a real filename as a
# wildcard, which a length-bounded substring compare never does.
is_prefix() {
  local a="$1" b="$2" alen
  alen=${#a}
  [ "${b:0:alen}" = "$a" ] && [ "${b:alen:1}" = "/" ]
}

# D7 — overlap is a class, not one case: exact, directory-prefix (either
# direction), or ASCII case-fold. All three refuse identically (`overlap`).
oi=0
while [ "$oi" -lt "$WCOUNT" ]; do
  w="${WPATHS[$oi]}"
  wf="${WFOLD[$oi]}"
  oj=0
  while [ "$oj" -lt "$LCOUNT" ]; do
    l="${LPATHS[$oj]}"
    lf="${LFOLD[$oj]}"
    reason=""
    if [ "$w" = "$l" ]; then
      reason="exact"
    elif is_prefix "$w" "$l" || is_prefix "$l" "$w"; then
      reason="directory-prefix"
    elif [ "$wf" = "$lf" ]; then
      reason="ASCII-case-fold"
    fi
    if [ -n "$reason" ]; then
      wq="$(printf '%q' "$w")"
      lq="$(printf '%q' "$l")"
      die 1 overlap "worker path $wq collides ($reason) with already-landed path $lq"
    fi
    oj=$((oj + 1))
  done
  oi=$((oi + 1))
done

# --- build the landing record (buffered; NOTHING reaches stdout until here,
#     so no partial or unauthorized record can ever be read as one) ---------
RECORD="$WORKDIR/record"
{
  printf '<!-- BEGIN land-worktree-record -->\n'
  if [ "$CHECK_ONLY" = "1" ]; then
    printf -- '- mode: check-only\n'
  else
    printf -- '- mode: landed\n'
  fi
  printf -- '- onto: %s (%s)\n' "$(printf '%q' "$ONTO_ARG")" "$ONTO_REF"
  printf -- '- base: %s (%s)\n' "$(printf '%q' "$BASE_ARG")" "$B"
  printf -- '- coordinator-tip-before: %s\n' "$T"
  printf -- '- worker: %s (%s)\n' "$(printf '%q' "$WORKER_ARG")" "$W"
  if [ "$WORKER_TREE_LINE" = "not-checked" ]; then
    printf -- '- worker-tree: not-checked\n'
  else
    printf -- '- worker-tree: %s\n' "$(printf '%q' "$WORKER_TREE_LINE")"
  fi
  printf -- '- claimed-paths: %s\n' "$WCOUNT"
  wi=0
  while [ "$wi" -lt "$WCOUNT" ]; do
    printf -- '- path: %s\n' "$(printf '%q' "${WPATHS[$wi]}")"
    wi=$((wi + 1))
  done
} > "$RECORD"

if [ "$CHECK_ONLY" = "1" ]; then
  printf '<!-- END land-worktree-record -->\n' >> "$RECORD"
  cat "$RECORD" || true
  exit 0
fi

# --- compose the tree (D5): coordinator tip's tree, with exactly the
#     worker's claimed paths taking their state at the worker tip — via a
#     private scratch index only, never the real index, never a worktree. --
SCRATCH_IDX="$WORKDIR/index"
GIT_INDEX_FILE="$SCRATCH_IDX" git read-tree "$T" \
  || die 2 structural "failed to seed the scratch index from the coordinator tip"

ci=0
while [ "$ci" -lt "$WCOUNT" ]; do
  p="${WPATHS[$ci]}"
  entry="$(git ls-tree -z "$W" -- ":(literal)$p")"
  if [ -z "$entry" ]; then
    # Absent at the worker tip relative to the base: a deletion. Force-remove
    # works even when the path is not currently present in the scratch
    # index at all (measured live against this exact private-index shape),
    # so this is safe regardless of whether the coordinator tip already
    # lacked it.
    GIT_INDEX_FILE="$SCRATCH_IDX" git update-index --force-remove -- "$p" \
      || die 2 structural "failed to remove a deleted path from the scratch index: $(printf '%q' "$p")"
  else
    hdr="${entry%%$'\t'*}"
    mode="${hdr%% *}"
    rest="${hdr#* }"
    sha="${rest#* }"
    # Reusing the tree entry's own mode+sha directly (never reading blob
    # content) is what carries a symlink as a symlink entry rather than as
    # its target's contents, and an executable-bit-only change correctly,
    # with no special-casing needed for either.
    GIT_INDEX_FILE="$SCRATCH_IDX" git update-index --add --cacheinfo "$mode" "$sha" "$p" \
      || die 2 structural "failed to stage a changed path into the scratch index: $(printf '%q' "$p")"
  fi
  ci=$((ci + 1))
done

NEWTREE="$(GIT_INDEX_FILE="$SCRATCH_IDX" git write-tree)" \
  || die 2 structural "failed to write the composed tree"
NEWCOMMIT="$(git commit-tree "$NEWTREE" -p "$T" -p "$W" -m "land-worktree: land $WORKER_ARG onto $ONTO_ARG (base $BASE_ARG)")" \
  || die 2 structural "failed to create the composed commit"

# TEST-ONLY synchronization seam (inert unless a caller explicitly sets
# TEAM_LAND_WORKTREE_TESTHOOK_DIR — no shipped caller, no acceptance
# criterion and no normal operation ever sets it): the reconcile suite's
# `ref-moved` fixture needs a genuine race between this process's own read
# of $T (above) and its own update-ref call (below), the exact window an
# out-of-band actor bypassing this lock would have to land in. Wall-clock
# `sleep`-based racing against that window is inherently flaky (repo lesson
# — bin/log-run.sh's own T-1076 rework replaced fixed sleeps with marker-file
# rendezvous for the identical reason); this is that same marker-driven
# rendezvous, gated so it can never fire during a real landing. It runs no
# caller-supplied command and creates no scratch worktree — it only pauses
# on a fixed marker path this same invocation names, so it adds no new
# execution surface (Non-goals).
if [ -n "${TEAM_LAND_WORKTREE_TESTHOOK_DIR:-}" ]; then
  : > "${TEAM_LAND_WORKTREE_TESTHOOK_DIR}/ready"
  hook_i=0
  while [ ! -e "${TEAM_LAND_WORKTREE_TESTHOOK_DIR}/go" ]; do
    hook_i=$((hook_i + 1))
    [ "$hook_i" -lt 300 ] || break
    sleep 0.1 2>/dev/null || sleep 1
  done
fi

# Compare-and-swap (D5/D6): refuses (does not clobber) if the ref moved
# since T was read. Under a held lock this should never fire; if it ever
# does, something advanced the branch outside this mechanism, which is a
# `ref-moved` refusal whose remedy is to re-derive the claim sets, never to
# retry the same landing.
UPDATEREF_ERR="$WORKDIR/updateref.err"
if ! git update-ref "$ONTO_REF" "$NEWCOMMIT" "$T" 2>"$UPDATEREF_ERR"; then
  die 1 ref-moved "the coordinator ref $ONTO_REF advanced from $T to something else between the read and the write; re-derive the claim sets rather than retrying this same landing"
fi

{
  printf -- '- landed-tip: %s\n' "$NEWCOMMIT"
  printf '<!-- END land-worktree-record -->\n'
} >> "$RECORD"

cat "$RECORD" || true
exit 0
