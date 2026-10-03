#!/usr/bin/env bash
# bin/team-commit.sh — commit exactly the named paths and nothing else
# (T-1169, issue #662). On the Codex CLI host the sandbox refuses every write
# under .git/, so a role's own commit has to be one concrete command the
# operator can approve through the host's ordinary per-command prompt. This is
# that command: a closed, mechanically checked invocation instead of an
# open-ended class of git commands.
#
# Usage:
#   bash "<plugin root>/bin/team-commit.sh" --message-file '<file>' -- '<path>' ...
#   bin/team-commit.sh --help | -h
#
# What it runs, and only this: one `git add --` of the named paths, then one
# `git commit -F <message file>` with the repository's hooks running normally.
# It never resets, amends, cleans, stashes, checks out, restores, moves or
# pushes, never bypasses a hook, never stages by pattern (no all/update/dot
# staging form) and never removes anything. Every refusal happens before the
# first write; git runs with GIT_LITERAL_PATHSPECS=1 as defence in depth.
#
# Refused before any write (exit 2): any argument other than --message-file
# and the -- separator; none of the git-redirecting environment variables set;
# run from the top level of a work tree whose HEAD is a branch with a commit,
# with no merge, cherry-pick, revert or rebase in progress and an index that
# holds no staged change; a message file that is an existing, non-empty,
# regular, non-symlink file outside the work tree whose path uses only
# [A-Za-z0-9._/-]; paths that are relative to the top level, use only
# [A-Za-z0-9._/-], carry no empty, "." or ".." component, no .git component in
# any letter case and no duplicate, and that each name an existing regular
# file (no symlink, directory or nested repository on the way), not ignored,
# that is new or differs from HEAD in content with its mode unchanged.
#
# After `git add` and immediately before `git commit` it checks that the staged
# tree differs from HEAD only by the requested paths, each added (regular-file
# mode) or modified (mode unchanged); otherwise it stops with exit 4 without
# committing and leaves the index as it is. After the commit it verifies the same
# of the new commit; a mismatch is reported and the commit is kept (nothing is
# reset, undone or amended). Both comparisons are config-independent: no rename
# detection, submodules never ignored, no external diff driver or textconv.
# Accepted risks, stated in the adopting guides: a repository's own hook may
# change the commit after the invariant (exit 3 reports it); a concurrent
# writer in the work tree is not guarded against.
#
# Exit codes:
#   0  committed and verified; stdout is the new commit's full SHA
#   1  a git add or git commit this script ran failed; nothing is reset
#   2  refused before any write (usage, environment, repository, message file,
#      path)
#   3  committed, but verification found a mismatch; the commit is kept
#   4  the pre-commit invariant failed after git add: no commit was made, HEAD
#      is unchanged, the staged index is left as it is
#
# External dependencies: bash 3.2+ and standard POSIX tools plus git.

set -euo pipefail

export LC_ALL=C

# Resolve this script's own directory (symlink-safe, physical) so any sibling
# script would resolve regardless of cwd — the same pattern as
# bin/check-setup.sh. No sibling is invoked today; the directory only names the
# script in the usage hint.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd -P)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"

err() { printf '%s\n' "$*" >&2 || true; }
# refuse <class> <detail>: a refusal, exit 2, nothing written.
refuse() { err "team-commit: refused ($1): $2"; exit 2; }
usage_hint() { err "usage: bash \"$SCRIPT_DIR/team-commit.sh\" --message-file '<file>' -- '<path>' ..."; }

print_help() {
  cat <<'EOF'
Usage: bash "<plugin root>/bin/team-commit.sh" --message-file '<file>' -- '<path>' ...
       bin/team-commit.sh --help | -h

Commit exactly the named paths with one `git add --` and one `git commit -F`,
refusing everything else before anything is written. Hooks run normally.

Arguments: --message-file <file>, then `--`, then one or more paths. Any other
argument is refused, including every option that would stage or rewrite more
than the named paths.

Refused before any write: a git-redirecting environment variable set
(GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY,
GIT_ALTERNATE_OBJECT_DIRECTORIES, GIT_COMMON_DIR, GIT_NAMESPACE,
GIT_LITERAL_PATHSPECS, GIT_GLOB_PATHSPECS, GIT_NOGLOB_PATHSPECS,
GIT_ICASE_PATHSPECS, GIT_CONFIG_PARAMETERS); GIT_CONFIG_COUNT unless every key
is safe.directory (then unset GIT_CONFIG_COUNT and its key/value pairs, or move
the setting into your own git config); not run from the top level of a work tree; a detached or unborn HEAD; a merge, cherry-pick,
revert or rebase in progress; anything already staged; a message file that is
missing, a symlink, empty, inside the work tree or spelled with characters
outside [A-Za-z0-9._/-]; a path that is absolute, climbs out, names .git,
uses characters outside [A-Za-z0-9._/-], repeats, is a symlink or directory,
sits under a leading directory that HEAD tracks as a file, symlink or gitlink,
is missing (a removal), is ignored, is unchanged, or changes only its mode.

After staging and before committing it checks that the staged tree differs from
HEAD only by the requested paths, each added or modified with an unchanged
mode; otherwise it stops without committing and leaves the index as it is.
After the commit it checks the same of the new commit. A mismatch there is
reported and the commit is kept. A repository's own hook may change the commit
after the first check, and a concurrent writer in the work tree is not guarded
against.

Stdout on success: the new commit's full SHA. Diagnostics go to stderr.

Exit codes:
  0  committed and verified
  1  a git add or git commit run by this script failed; nothing is reset
  2  refused before any write
  3  committed, but verification found a mismatch; the commit is kept
  4  the pre-commit invariant failed: no commit was made, the staged index is
     left as it is
EOF
}

# ---------------------------------------------------------------------------
# 1. Arguments (before any git call).
# ---------------------------------------------------------------------------
MSG=""
MSG_SET=0
SEP=0
PATHS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --message-file)
      [ "$MSG_SET" -eq 0 ] || refuse usage "--message-file given more than once"
      [ "$#" -ge 2 ] || { usage_hint; refuse usage "--message-file needs a value"; }
      MSG="$2"
      MSG_SET=1
      shift 2
      ;;
    --)
      SEP=1
      shift
      break
      ;;
    *)
      usage_hint
      refuse usage "argument not accepted: $1 (only --message-file and -- are accepted)"
      ;;
  esac
done
[ "$MSG_SET" -eq 1 ] || { usage_hint; refuse usage "--message-file is required"; }
[ "$SEP" -eq 1 ] || { usage_hint; refuse usage "paths must follow --"; }
[ "$#" -ge 1 ] || { usage_hint; refuse usage "at least one path is required"; }
for a in "$@"; do
  PATHS+=("$a")
done

# ---------------------------------------------------------------------------
# 2. Environment: refused, never unset.
# ---------------------------------------------------------------------------
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
  GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS \
  GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS; do
  if [ -n "${!v+x}" ]; then
    refuse environment "$v is set; it redirects the repository, index or pathspec semantics"
  fi
done
# GIT_CONFIG_COUNT is accepted only when it is a short non-negative decimal
# integer and every key below it (with its value) is safe.directory in any
# letter case — the shape a sandbox exports. Keys at or above the count are
# ignored, as git ignores them.
if [ -n "${GIT_CONFIG_COUNT+x}" ]; then
  COUNT_REMEDY="unset GIT_CONFIG_COUNT and its GIT_CONFIG_KEY_<n>/GIT_CONFIG_VALUE_<n> pairs (or move the setting into your own git config) and re-run"
  case "$GIT_CONFIG_COUNT" in
    ''|*[!0-9]*) refuse environment "GIT_CONFIG_COUNT is not a non-negative decimal integer; $COUNT_REMEDY" ;;
  esac
  [ "${#GIT_CONFIG_COUNT}" -le 4 ] || refuse environment "GIT_CONFIG_COUNT is too large; $COUNT_REMEDY"
  cfg_n=0
  cfg_total=$((10#$GIT_CONFIG_COUNT))
  while [ "$cfg_n" -lt "$cfg_total" ]; do
    cfg_k="GIT_CONFIG_KEY_$cfg_n"
    cfg_v="GIT_CONFIG_VALUE_$cfg_n"
    if [ -z "${!cfg_k+x}" ] || [ -z "${!cfg_v+x}" ]; then
      refuse environment "GIT_CONFIG_COUNT names pair $cfg_n but $cfg_k or $cfg_v is not set; $COUNT_REMEDY"
    fi
    case "${!cfg_k}" in
      [sS][aA][fF][eE].[dD][iI][rR][eE][cC][tT][oO][rR][yY]) : ;;
      *) refuse environment "GIT_CONFIG_COUNT carries a setting other than safe.directory ($cfg_k); $COUNT_REMEDY" ;;
    esac
    cfg_n=$((cfg_n + 1))
  done
fi
command -v git > /dev/null 2>&1 || refuse environment "git is not on PATH"

# ---------------------------------------------------------------------------
# 3. Repository state.
# ---------------------------------------------------------------------------
TOP="$(git rev-parse --show-toplevel 2> /dev/null)" || refuse repository "not inside a git work tree"
CWD="$(pwd -P)"
[ "$TOP" = "$CWD" ] || refuse repository "not run from the top level of the work tree"
GITDIR="$(git rev-parse --absolute-git-dir 2> /dev/null)" || refuse repository "cannot resolve the git directory"
git symbolic-ref -q HEAD > /dev/null 2>&1 || refuse repository "HEAD is detached; a branch is required"
BASE="$(git rev-parse --verify -q 'HEAD^{commit}' 2> /dev/null)" || refuse repository "the branch has no commit yet"
for m in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD rebase-merge rebase-apply sequencer; do
  if [ -e "$GITDIR/$m" ]; then
    refuse repository "an operation is in progress ($m)"
  fi
done

export GIT_LITERAL_PATHSPECS=1

# Every comparison of the index or of a commit with HEAD is config-independent:
# submodules never ignored (a staged gitlink is always seen, whatever
# diff.ignoreSubmodules or a .gitmodules ignore setting says), no rename
# detection, no external diff driver, no textconv.
NEUTRAL=(-c diff.ignoreSubmodules=none -c core.quotepath=false)
DIFFOPTS=(--no-renames --ignore-submodules=none --no-ext-diff --no-textconv --no-abbrev)

IDX="$(git "${NEUTRAL[@]}" diff-index --cached --raw "${DIFFOPTS[@]}" HEAD 2> /dev/null)" || refuse index "cannot read the index state (git diff-index failed)"
[ -z "$IDX" ] || refuse index "the index already holds a staged change"

# ---------------------------------------------------------------------------
# 4. Message file.
# ---------------------------------------------------------------------------
case "$MSG" in
  '') refuse message-file "empty path" ;;
  *[!A-Za-z0-9._/-]*) refuse message-file "$MSG: characters outside [A-Za-z0-9._/-]" ;;
esac
[ -e "$MSG" ] || refuse message-file "$MSG: does not exist"
[ ! -L "$MSG" ] || refuse message-file "$MSG: is a symlink"
[ -f "$MSG" ] || refuse message-file "$MSG: is not a regular file"
[ -s "$MSG" ] || refuse message-file "$MSG: is empty"
MSG_DIR="$(cd -- "$(dirname -- "$MSG")" && pwd -P)" || refuse message-file "$MSG: directory cannot be resolved"
MSG_ABS="$MSG_DIR/$(basename -- "$MSG")"
case "$MSG_ABS/" in
  "$TOP"/*) refuse message-file "$MSG: lies inside the work tree" ;;
esac

# ---------------------------------------------------------------------------
# 5. Paths.
# ---------------------------------------------------------------------------
check_path() {
  local p="$1" dir rest comp lead ls_out head_mode raw meta om nm st rc
  [ -n "$p" ] || refuse path "empty path"
  case "$p" in
    *[!A-Za-z0-9._/-]*) refuse path "$p: characters outside [A-Za-z0-9._/-]" ;;
    -*) refuse path "$p: starts with '-'" ;;
    /*) refuse path "$p: absolute path" ;;
    */) refuse path "$p: trailing slash" ;;
  esac
  case "/$p/" in
    *//*) refuse path "$p: empty component" ;;
    */./*|*/../*) refuse path "$p: '.' or '..' component" ;;
    */[.][gG][iI][tT]/*) refuse path "$p: .git component" ;;
  esac

  # Every directory on the way: not a symlink, not a nested repository.
  dir=""
  rest="$p"
  while :; do
    case "$rest" in
      */*) ;;
      *) break ;;
    esac
    comp="${rest%%/*}"
    rest="${rest#*/}"
    dir="${dir:+$dir/}$comp"
    [ ! -L "$dir" ] || refuse path "$p: $dir is a symlink"
    [ ! -e "$dir/.git" ] || refuse path "$p: $dir is a nested repository"
    lead="$(git ls-tree HEAD -- "$dir")" || refuse path "$p: cannot read HEAD (git ls-tree failed)"
    case "${lead%% *}" in 040000|'') : ;; *) refuse path "$p: leading directory $dir is tracked in HEAD as a non-tree entry (mode ${lead%% *})" ;; esac # leading-dir-refusal
  done

  [ ! -L "$p" ] || refuse path "$p: is a symlink"
  if [ ! -e "$p" ]; then
    refuse path "$p: does not exist in the work tree (a removal is not committed through this script)"
  fi
  [ -f "$p" ] || refuse path "$p: is not a regular file"

  rc=0
  # check-ignore does not accept literal pathspec magic; the path grammar above
  # already excludes every glob character, so it runs without the variable.
  (unset GIT_LITERAL_PATHSPECS; git check-ignore -q -- "$p") > /dev/null 2>&1 || rc=$?
  case "$rc" in
    1) : ;;
    0) refuse path "$p: is ignored" ;;
    *) refuse path "$p: cannot evaluate ignore rules (git check-ignore exit $rc)" ;;
  esac

  ls_out="$(git ls-tree HEAD -- "$p")" || refuse path "$p: cannot read HEAD (git ls-tree failed)"
  raw="$(git "${NEUTRAL[@]}" diff --raw "${DIFFOPTS[@]}" -- "$p")" || refuse path "$p: cannot compare with the index (git diff failed)"
  if [ -n "$ls_out" ]; then
    head_mode="${ls_out%% *}"
    case "$head_mode" in
      100644|100755) : ;;
      *) refuse path "$p: tracked in HEAD as mode $head_mode, not a regular file" ;;
    esac
    if [ -z "$raw" ]; then
      refuse path "$p: unchanged from HEAD" # unchanged-refusal
    else
      meta="${raw%%$'\t'*}"
      om="${meta%% *}"
      om="${om#:}"
      nm="${meta#* }"
      nm="${nm%% *}"
      st="${meta##* }"
      [ "$st" = "M" ] || refuse path "$p: change kind $st is not a modification"
      [ "$om" = "$nm" ] || refuse path "$p: mode change ($om to $nm); a mode change is not committed through this script" # mode-change-refusal
      [ "$om" = "$head_mode" ] || refuse path "$p: mode differs from HEAD"
    fi
  else
    [ -z "$raw" ] || refuse path "$p: unexpected tracked state"
  fi
}

i=0
for p in "${PATHS[@]}"; do
  j=0
  for q in "${PATHS[@]}"; do
    if [ "$j" -lt "$i" ] && [ "$p" = "$q" ]; then
      refuse path "$p: given more than once"
    fi
    j=$((j + 1))
  done
  i=$((i + 1))
done
for p in "${PATHS[@]}"; do
  check_path "$p"
done

# ---------------------------------------------------------------------------
# 6. Entry scanning shared by the pre-commit invariant and the post-commit
#    verification.
# ---------------------------------------------------------------------------
REQ="$(printf '%s\n' "${PATHS[@]}" | sort)"

# scan_raw <raw diff output>: sets ACT (changed paths, one per line), ENTRIES
# (one printable "<status> <old mode> <new mode> <path>" line per entry) and BAD
# (what is not a plain addition with a regular-file mode, or a modification
# whose old and new modes are equal regular-file modes).
scan_raw() {
  local raw="$1" line meta fpath om nm rest st save_ifs
  ACT=""
  BAD=""
  ENTRIES=""
  save_ifs="$IFS"
  IFS=$'\n'
  set -f
  for line in $raw; do
    case "$line" in
      *$'\t'*) : ;;
      *) BAD="$BAD unparseable-entry"; continue ;;
    esac
    meta="${line%%$'\t'*}"
    fpath="${line#*$'\t'}"
    om="${meta%% *}"
    om="${om#:}"
    rest="${meta#* }"
    nm="${rest%% *}"
    rest="${rest#* }"
    rest="${rest#* }"
    rest="${rest#* }"
    st="$rest"
    case "$st" in
      A)
        case "$nm" in
          100644|100755) : ;;
          *) BAD="$BAD A-mode-$nm:$fpath" ;;
        esac
        ;;
      M)
        case "$nm" in
          100644|100755) : ;;
          *) BAD="$BAD M-mode-$nm:$fpath" ;;
        esac
        [ "$om" = "$nm" ] || BAD="$BAD M-mode-change-$om-to-$nm:$fpath"
        ;;
      *) BAD="$BAD $st:$fpath" ;;
    esac
    ENTRIES="$ENTRIES$st $om $nm $fpath"$'\n'
    ACT="$ACT$fpath"$'\n'
  done
  set +f
  IFS="$save_ifs"
}

# ---------------------------------------------------------------------------
# 7. The two writes, with the pre-commit invariant between them.
# ---------------------------------------------------------------------------
staged_now() {
  local s
  s="$(git "${NEUTRAL[@]}" diff-index --cached --name-only "${DIFFOPTS[@]}" HEAD 2> /dev/null || true)"
  if [ -n "$s" ]; then
    printf '%s\n' "$s"
  else
    printf '(none)\n'
  fi
}

# invariant_fail <why>: exit 4, no commit, the index left as it is.
invariant_fail() {
  local why="$1" extra="" l
  err "team-commit: pre-commit invariant failed ($why); no commit was made, HEAD is unchanged and the staged index is left as it is (nothing is reset)."
  err "requested paths:"
  printf '%s\n' "$REQ" >&2 || true
  err "staged entries (status, old mode, new mode, path):"
  printf '%s' "$ENTRIES" >&2 || true
  local save_ifs="$IFS"
  IFS=$'\n'
  set -f
  for l in $ACT; do
    if ! printf '%s\n' "$REQ" | grep -qxF -- "$l"; then
      extra="$extra $l"
    fi
  done
  set +f
  IFS="$save_ifs"
  err "staged beyond the requested set:${extra:- (none; a requested path is missing or an entry has the wrong kind)}"
  exit 4
}

if ! git add -- "${PATHS[@]}" 1>&2; then
  err "team-commit: failed step: git add; nothing was reset. Staged paths now:"
  staged_now >&2 || true
  exit 1
fi

PRE_RAW="$(git "${NEUTRAL[@]}" diff-index --cached --raw "${DIFFOPTS[@]}" HEAD 2> /dev/null)" || { ACT=""; ENTRIES=""; invariant_fail "the staged tree cannot be listed"; }
scan_raw "$PRE_RAW"
PRE_SORTED="$(printf '%s' "$ACT" | sort)"
[ -z "$BAD" ] || invariant_fail "an entry is not a plain addition or modification:$BAD"
[ "$PRE_SORTED" = "$REQ" ] || invariant_fail "the staged paths differ from the requested paths"

if ! git commit -q -F "$MSG_ABS" 1>&2; then
  err "team-commit: failed step: git commit; nothing was reset. Staged paths now:"
  staged_now >&2 || true
  exit 1
fi

# ---------------------------------------------------------------------------
# 8. Post-commit verification; a mismatch keeps the commit.
# ---------------------------------------------------------------------------
mismatch() {
  local requested="$1" actual="$2" why="$3"
  err "team-commit: verification mismatch ($why); the commit is kept, nothing is reset or amended."
  err "requested paths:"
  printf '%s\n' "$requested" >&2 || true
  err "actual paths in the new commit:"
  printf '%s\n' "$actual" >&2 || true
  exit 3
}

NEW="$(git rev-parse --verify 'HEAD^{commit}' 2> /dev/null)" || mismatch "$REQ" "(unreadable)" "HEAD cannot be read after the commit"
PARENT="$(git rev-parse --verify -q 'HEAD^' 2> /dev/null || true)"
[ "$PARENT" = "$BASE" ] || mismatch "$REQ" "(unknown)" "the new commit's parent is not the commit HEAD was at before"
RAW="$(git "${NEUTRAL[@]}" diff-tree --no-commit-id -r --raw "${DIFFOPTS[@]}" HEAD 2> /dev/null)" || mismatch "$REQ" "(unreadable)" "the new commit cannot be listed"

scan_raw "$RAW"
ACT_SORTED="$(printf '%s' "$ACT" | sort)"
[ -z "$BAD" ] || mismatch "$REQ" "$ACT_SORTED" "an entry is not a plain addition or modification with an unchanged mode:$BAD"
[ "$ACT_SORTED" = "$REQ" ] || mismatch "$REQ" "$ACT_SORTED" "the commit's paths differ from the requested paths"

printf '%s\n' "$NEW"
