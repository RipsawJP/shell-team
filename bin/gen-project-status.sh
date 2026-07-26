#!/usr/bin/env bash
# gen-project-status.sh — regenerate ONLY the marked block of project_status.md
# from the board + git state (T-038).
#
# project_status.md stays a mostly HAND-WRITTEN document (next actions, design
# decisions — the session-memory regeneration source). This script owns exactly
# one region of it, delimited by two exact marker lines:
#
#   <!-- BEGIN generated -->
#   <!-- END generated -->
#
# Everything between the markers is replaced with a deterministic summary of
# the resolved board (Active/Done counts + Active flags) and the git state
# (branch / HEAD / latest tag). Everything OUTSIDE the markers is byte-
# untouched — the generator never rewrites the hand-written narrative.
#
# Deterministic by construction: the block contains NO wall-clock timestamps
# (dates come from git commit data), so running it twice against the same
# board/git state produces byte-identical output (idempotent).
#
# Usage:
#   gen-project-status.sh [--root DIR] [--file PATH]
#
#   --root  repo root to resolve board/git against (default: cwd)
#   --file  status file to rewrite (default: <team-paths base>/project_status.md
#           under --root)
#
# Exit: 0 = block regenerated (file rewritten, possibly byte-identical);
#       1 = status file missing or its markers are absent/malformed (file
#           untouched); 2 = usage / resolver error.

set -euo pipefail

die()  { printf 'gen-project-status: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'gen-project-status: %s\n' "$1" >&2 || true; exit 1; }

script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

ROOT="."
FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --file) [ "$#" -ge 2 ] || die "--file requires a value"; shift; FILE="$1"; shift ;;
    --help|-h) sed -n '2,30p' "$script_path" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"

BASE="$(bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get base 2>/dev/null)" \
  || die "cannot resolve base dir (team-paths.sh unavailable)"
BOARD="$ROOT/$(bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get todo)"
if [ -z "$FILE" ]; then
  FILE="$ROOT/$BASE/project_status.md"
fi

[ -r "$FILE" ] || fail "status file not found (create it by hand first, markers included): $FILE"

BEGIN_MARK='<!-- BEGIN generated -->'
END_MARK='<!-- END generated -->'
begin_count="$(grep -c -x -F "$BEGIN_MARK" "$FILE" || true)"
end_count="$(grep -c -x -F "$END_MARK" "$FILE" || true)"
if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
  fail "expected exactly one BEGIN/END generated marker in $FILE (got $begin_count/$end_count) — file untouched"
fi
begin_ln="$(grep -n -x -F "$BEGIN_MARK" "$FILE" | cut -d: -f1)"
end_ln="$(grep -n -x -F "$END_MARK" "$FILE" | cut -d: -f1)"
[ "$begin_ln" -lt "$end_ln" ] || fail "BEGIN marker must precede END marker in $FILE — file untouched"

# --- build the generated block -------------------------------------------------
GEN_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-status-block.XXXXXX")"
TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-status-out.XXXXXX")"
trap 'rm -f "$GEN_FILE" "$TMP_FILE"' EXIT

# Backticks below are literal Markdown code spans, not command substitutions.
# shellcheck disable=SC2016
{
  printf '_この間は `bin/gen-project-status.sh` が board + git から再生成する（手で編集しない・マーカ外は不可侵）_\n'
  printf '\n'

  if [ -r "$BOARD" ]; then
    printf '**Board**（`%s`）\n' "$(bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get todo)"
    printf '\n'
    awk '
      BEGIN { sec=""; n_active=0; n_done=0; latest="" }
      /^## / { sec=$0 }
      sec ~ /^## Active/ && /^- \[ \] / {
        n_active++
        id=""; flag=""
        if (match($0, /\*\*T-[0-9]+\*\*/)) id=substr($0, RSTART+2, RLENGTH-4)
        if (match($0, /— `[^`]+` — spec:/)) {
          flag=substr($0, RSTART, RLENGTH)
          sub(/^— `/, "", flag); sub(/` — spec:$/, "", flag)
        }
        actives[n_active] = "  - " id " — `" flag "`"
      }
      sec ~ /^## Done/ && /^- \[x\] / {
        n_done++
        if (n_done == 1 && match($0, /T-[0-9]+/)) latest=substr($0, RSTART, RLENGTH)
      }
      END {
        printf "- Active: %d 件\n", n_active
        for (i = 1; i <= n_active; i++) print actives[i]
        if (latest != "") printf "- Done: %d 件（最新: %s）\n", n_done, latest
        else               printf "- Done: %d 件\n", n_done
      }
    ' "$BOARD"
  else
    printf '**Board**: （board が見つからない: `%s`）\n' "$BOARD"
  fi

  printf '\n'
  printf '**Git**\n'
  printf '\n'
  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$ROOT" symbolic-ref --short -q HEAD || printf '(detached)')"
    printf -- '- branch: `%s`\n' "$branch"
    printf -- '- HEAD: %s\n' "$(git -C "$ROOT" log -1 --format='`%h` %s（%cs）')"
    # Newest tag repo-wide by creation date — NOT `git describe`, which only
    # sees tags reachable from HEAD and returns ancient tags on a develop
    # lineage (release tags live on main's merge commits here).
    tag="$(git -C "$ROOT" tag --sort=-creatordate 2>/dev/null | head -n 1)"
    [ -n "$tag" ] || tag='(none)'
    printf -- '- latest tag: %s\n' "$tag"
  else
    printf -- '- git: (not a git repository)\n'
  fi
} > "$GEN_FILE"

# --- splice: keep everything outside the markers byte-identical -----------------
awk -v begin_ln="$begin_ln" -v end_ln="$end_ln" -v gen_file="$GEN_FILE" '
  NR == begin_ln {
    print
    while ((getline l < gen_file) > 0) print l
    close(gen_file)
    next
  }
  NR > begin_ln && NR < end_ln { next }
  { print }
' "$FILE" > "$TMP_FILE"

# Keep the status file's own permissions (mktemp files are 0600).
cat "$TMP_FILE" > "$FILE"
printf 'gen-project-status: regenerated block in %s\n' "$FILE"
exit 0
