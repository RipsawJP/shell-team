#!/usr/bin/env bash
# bin/check-commit-identity.sh — commit author/committer identity gate (T-112,
# GitHub issue #6 Layer 1 item 1; docs/specs/T-112-commit-identity-and-ignore-lock.md).
#
# Identity metadata is not file content, so a content scan (bin/check-pii-shapes.sh)
# misses it entirely, and rewriting history does not remove objects that already
# carry it. This script is a forward-looking gate on the identity a pull request's
# OWN commits carry — never on pre-existing published history.
#
# Range (DP-1): the non-merge commits from `git merge-base <base> HEAD` to
# `HEAD` — `git rev-list --no-merges <merge-base>..HEAD`. A commit outside
# that range is never inspected. Merge commits are excluded wholesale: a merge
# commit's identity is set by the merging party (GitHub's web flow, or a
# maintainer merging the base back in), not by the author of the change under
# review.
#
# Allowed identity forms:
#   author     ONLY the noreply "+login" form:
#              <numeric-id>+<login>@users.noreply.github.com
#   committer  the same "+login" form, OR the plain GitHub web-flow noreply
#              identity noreply@github.com — allowed on the COMMITTER side
#              only. A non-merge commit created through the GitHub web editor
#              or the REST API carries exactly that shape; excluding merges
#              alone would leave that class as a reachable false red.
# Both allowed-form matches are anchored at both ends of the address
# (`^...$`), never a substring test — a lookalike domain that merely CONTAINS
# the noreply domain, with anything prepended or appended, is a finding on
# both sides (DP-2).
#
# A finding never echoes the rejected identity value (DP-3): only the commit
# and the non-conformant side (`author-identity` / `committer-identity`) are
# reported — a report that echoed the address would turn a control into a
# leak in a public CI log.
#
# Scope (deliberately NOT covered, docs/pii-controls.md has the canonical
# lines): ownership of an identity (a syntactically conformant address
# belonging to someone else), signature verification, and the pre-existing
# author-side exposure already published in this repo's merged history — a
# forward-looking gate does not remove existing objects; that remediation is
# an operator-side account setting, not a repository change.
#
# Usage:
#   check-commit-identity.sh --base <ref>
#   check-commit-identity.sh --help
#
# Exit codes:
#   0  conformant — every commit in range has a conformant author AND
#      committer identity (an empty range is conformant too: a gate with
#      nothing to judge is clean, not an error).
#   1  one or more findings.
#   2  usage or structural error: a missing/unknown flag, a missing --base,
#      an unresolvable base ref, or a path that is not a git repository. A
#      run that cannot evaluate its input never reports clean.

set -euo pipefail

die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-commit-identity: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }

# Resolve this script's own file, following symlinks (a plugin install may
# expose bin/ scripts on PATH via a symlink). Ported from
# bin/check-provenance.sh's bootstrap (2026-07-14 lesson: reuse the proven
# resolver rather than hand-rolling one). Every external command here is
# guarded — a failure falls closed as a classified usage(2) error.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || fail_usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd)" \
        || fail_usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || fail_usage "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  sed -n '2,53p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
BASE_REF=""
HAVE_BASE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --base)
      [ "$#" -ge 2 ] || fail_usage "--base requires a value"
      BASE_REF="$2"; HAVE_BASE=1; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"
[ "$HAVE_BASE" -eq 1 ] || fail_usage "missing required --base <ref>"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail_structural "not inside a git working tree (check-commit-identity.sh must be run from inside a git repository)"

git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null 2>&1 \
  || fail_structural "unresolvable base ref: $BASE_REF"

MERGE_BASE="$(git merge-base "$BASE_REF" HEAD 2>/dev/null)" \
  || fail_structural "unresolvable base ref: no merge-base between $BASE_REF and HEAD"
[ -n "$MERGE_BASE" ] \
  || fail_structural "unresolvable base ref: empty merge-base result for $BASE_REF"

# --- allowed-identity patterns (each on its own line, so a fixture suite can
# neutralise exactly one — same convention as bin/check-pii-shapes.sh). Both
# are full-string anchored (^...$), never a substring test (DP-2).
# shellcheck disable=SC2016
NOREPLY_ID_RE='^[0-9]+\+[A-Za-z0-9_-]+@users\.noreply\.github\.com$'
# shellcheck disable=SC2016
NOREPLY_PLAIN_RE='^noreply@github\.com$'

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-commit-identity.XXXXXX")" \
  || fail_structural "failed to create a scratch directory under mktemp"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

RANGE_FILE="$WORKDIR/range"
git rev-list --no-merges "${MERGE_BASE}..HEAD" > "$RANGE_FILE" 2>/dev/null \
  || fail_structural "git rev-list failed to enumerate the range ${MERGE_BASE}..HEAD"

FINDINGS_FILE="$WORKDIR/findings"
: > "$FINDINGS_FILE"

while IFS= read -r sha || [ -n "$sha" ]; do
  [ -n "$sha" ] || continue
  author_email="$(git log -1 --format='%ae' "$sha" 2>/dev/null)" \
    || fail_structural "failed to read author identity for commit $sha"
  committer_email="$(git log -1 --format='%ce' "$sha" 2>/dev/null)" \
    || fail_structural "failed to read committer identity for commit $sha"

  if ! [[ "$author_email" =~ $NOREPLY_ID_RE ]]; then
    printf 'FINDING commit=%s side=author-identity\n' "$sha" >> "$FINDINGS_FILE"
  fi
  if ! [[ "$committer_email" =~ $NOREPLY_ID_RE ]] && ! [[ "$committer_email" =~ $NOREPLY_PLAIN_RE ]]; then
    printf 'FINDING commit=%s side=committer-identity\n' "$sha" >> "$FINDINGS_FILE"
  fi
done < "$RANGE_FILE"

if [ -s "$FINDINGS_FILE" ]; then
  cat "$FINDINGS_FILE"
  exit 1
fi

printf 'check-commit-identity: clean (no non-conformant commit identity found in range)\n'
exit 0
