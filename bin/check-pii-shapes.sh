#!/usr/bin/env bash
# bin/check-pii-shapes.sh — diff-scoped PII shape checker (T-111, GitHub issue
# #6 Layer 2 items 4-5; docs/specs/T-111-pii-shape-checker.md).
#
# Development on this repository happens in the open, so a PII-shaped byte
# (an email-shaped string, a home-directory absolute path, a private-key
# header, a credential-token prefix) is a per-commit risk. This script gives
# that risk a mechanical gate: by default it looks only at what a change
# ADDS (diff-scoped, never the whole tree), and it is fail-closed — a run
# that cannot evaluate its input never reports clean.
#
# Five shapes are matched, each identified by a stable pattern id used in
# every finding line:
#   home-path         a POSIX home-directory absolute path with a real name
#                     segment (e.g. the placeholder shape /Users/<name>/ —
#                     written here with angle brackets precisely so this
#                     file, this spec, and the docs pair can discuss the
#                     shape without becoming a finding themselves; see AC9).
#   home-path-win     the Windows C: user-directory form (same placeholder
#                     convention, C:\Users\<name>\).
#   email-nonnoreply  a mailbox-shaped string at a real domain. Both GitHub
#                     noreply identity shapes — <id>+<login>@users.noreply.
#                     github.com and the plain web-flow noreply@github.com —
#                     are deliberately NOT findings: they are public
#                     identifiers by GitHub's own design, not PII.
#   private-key       a PEM private-key header line (named by id only in
#                     this file's prose; never transcribed literally here,
#                     since a document that transcribed a real match would
#                     red its own gate — see the spec's DP-1).
#   token             a credential-token prefix (GitHub gh[oprs]_, AWS AKIA,
#                     an OpenAI-style sk- key) long enough to be a real key
#                     body, not a short lookalike such as this project's own
#                     `task-0NN` label convention.
#
# Design decisions (full detail: docs/specs/T-111-pii-shape-checker.md):
#   DP-1  No PII-shaped byte enters the tree. Every fixture the test suite
#         uses is assembled at runtime, under mktemp, from fragments — never
#         written here as a completed literal. There is no path allowlist
#         and no inline allow marker: a finding is reported even when the
#         carrying path is this very script or a file under
#         tests/check-pii-shapes/ (AC13).
#   DP-2  Scanned unit (diff mode): the ADDED lines of `git diff <point>` —
#         lines starting with a single `+`, excluding the `+++` file header.
#         Comparison point: `git merge-base <base> HEAD` when that resolves,
#         else <base> itself. Default base chain when --base is omitted:
#         $PII_CHECK_BASE, then origin/$GITHUB_BASE_REF (only when
#         GITHUB_BASE_REF is set), then origin/develop, then develop —
#         first one that resolves. Unlike some of this repo's other
#         base-resolution checkers, this chain is FAIL-CLOSED at the end:
#         if nothing resolves, this script exits 2 rather than silently
#         skipping the scan. CI always passes --base explicitly anyway.
#         Known limitation: untracked files carry no diff and are therefore
#         not scanned in diff mode; --all is the mode that sees them.
#   DP-3  --all is a full-tree AUDIT flag, not a required CI check (it
#         necessarily reports the deliberately PII-shaped adversarial
#         fixtures that already live under tests/, by design). It walks
#         every file git already knows about (tracked + untracked-but-not-
#         ignored), skipping binary files (image content is a declared
#         non-goal — see docs/pii-controls.md).
#
# A finding never echoes the matched text — only the pattern id, the path,
# and a line number are reported — so a public CI log never carries the
# byte that tripped the gate.
#
# This is a discipline aid for a trusted, reviewed artifact, not a security
# boundary against an author editing the checker itself in the same commit
# (same trust boundary as bin/check-acs.sh's TRUST BOUNDARY note and
# bin/check-intent.sh's ledger note) — PR review is that layer.
#
# Usage:
#   check-pii-shapes.sh [--base <ref>]     diff-scoped (default)
#   check-pii-shapes.sh --all              full-tree audit (never in CI)
#   check-pii-shapes.sh --help
#
# Exit codes:
#   0  clean (no findings)
#   1  one or more findings
#   2  usage or structural error (unresolvable base ref, unreadable input,
#      unknown flag, --all combined with --base) — a check that cannot
#      evaluate its input never exits 0.

set -euo pipefail

die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-pii-shapes: %s: %s\n' "$1" "$2" >&2 || true
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
  sed -n '2,70p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
MODE="diff"
BASE_REF=""
HAVE_BASE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --all) MODE="all"; shift ;;
    --base)
      [ "$#" -ge 2 ] || fail_usage "--base requires a value"
      BASE_REF="$2"; HAVE_BASE=1; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

if [ "$MODE" = "all" ] && [ "$HAVE_BASE" -eq 1 ]; then
  fail_usage "--all and --base are mutually exclusive"
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail_structural "not inside a git working tree (check-pii-shapes.sh must be run from inside a git repository)"

# --- pattern definitions (each on its own line, so a fixture suite can
# neutralise exactly one at a time by rewriting its whole line) -------------
# shellcheck disable=SC2016  # single-quoted regex text, not a variable expansion
RE_HOME_PATH='/(Users|home)/[A-Za-z0-9_.-]+'
# shellcheck disable=SC2016
RE_HOME_PATH_WIN='C:\\{1,2}Users\\{1,2}[A-Za-z0-9_.-]+'
# shellcheck disable=SC2016
RE_EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# shellcheck disable=SC2016
RE_NOREPLY_ID='^[0-9]+\+[A-Za-z0-9_-]+@users\.noreply\.github\.com$'
# shellcheck disable=SC2016
RE_NOREPLY_PLAIN='^noreply@github\.com$'
# shellcheck disable=SC2016
RE_PRIVATE_KEY='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
# shellcheck disable=SC2016
RE_TOKEN='gh[oprs]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{12,}|sk-[A-Za-z0-9_-]{16,}'

SEP=$'\x1f'  # ASCII unit separator: delimits file/line/content triples

# scan_triples <triples-file> <out-file>
# Reads SEP-delimited (file, line, content) triples and appends one
# "FINDING pattern=<id> path=<file> line=<n>" line per match to <out-file>.
# The matched TEXT itself is never written anywhere (AC14).
scan_triples() {
  local triples="$1" out="$2" f ln content m
  while IFS="$SEP" read -r f ln content || [ -n "${f:-}" ]; do
    [ -n "${f:-}" ] || continue
    content="${content%$'\r'}"
    if [[ "$content" =~ $RE_HOME_PATH ]]; then
      printf 'FINDING pattern=home-path path=%s line=%s\n' "$f" "$ln" >> "$out"
    fi
    if [[ "$content" =~ $RE_HOME_PATH_WIN ]]; then
      printf 'FINDING pattern=home-path-win path=%s line=%s\n' "$f" "$ln" >> "$out"
    fi
    if [[ "$content" =~ $RE_EMAIL ]]; then
      m="${BASH_REMATCH[0]}"
      if [[ "$m" =~ $RE_NOREPLY_ID ]] || [[ "$m" =~ $RE_NOREPLY_PLAIN ]]; then
        :  # a public GitHub noreply identity — not a finding, by design
      else
        printf 'FINDING pattern=email-nonnoreply path=%s line=%s\n' "$f" "$ln" >> "$out"
      fi
    fi
    if [[ "$content" =~ $RE_PRIVATE_KEY ]]; then
      printf 'FINDING pattern=private-key path=%s line=%s\n' "$f" "$ln" >> "$out"
    fi
    if [[ "$content" =~ $RE_TOKEN ]]; then
      printf 'FINDING pattern=token path=%s line=%s\n' "$f" "$ln" >> "$out"
    fi
  done < "$triples"
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes.XXXXXX")" \
  || fail_structural "failed to create a scratch directory under mktemp"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

FINDINGS_FILE="$WORKDIR/findings"
: > "$FINDINGS_FILE"

if [ "$MODE" = "all" ]; then
  # --- full-tree audit: every file git knows about (tracked + untracked
  # but not ignored), binary files skipped (image content is a non-goal). --
  is_binary() {
    head -c 8000 "$1" 2>/dev/null | LC_ALL=C tr -d '[:print:][:space:]' | LC_ALL=C grep -q . 2>/dev/null
  }
  TRIPLES_FILE="$WORKDIR/triples-all"
  : > "$TRIPLES_FILE"
  FILELIST="$WORKDIR/filelist"
  git ls-files -z --cached --others --exclude-standard > "$FILELIST" \
    || fail_structural "git ls-files failed — cannot enumerate the tree for --all"
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    [ -r "$f" ] || fail_structural "cannot read file listed by git ls-files: $f"
    if is_binary "$f"; then
      continue
    fi
    awk -v SEP="$SEP" -v F="$f" '{ print F SEP FNR SEP $0 }' "$f" >> "$TRIPLES_FILE" \
      || fail_structural "failed to read lines from: $f"
  done < "$FILELIST"
  scan_triples "$TRIPLES_FILE" "$FINDINGS_FILE"
else
  # --- diff-scoped: resolve the comparison point, then scan added lines. ---
  resolve_ref() {
    git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1
  }

  CHOSEN=""
  if [ "$HAVE_BASE" -eq 1 ]; then
    resolve_ref "$BASE_REF" || fail_structural "unresolvable base ref: $BASE_REF"
    CHOSEN="$BASE_REF"
  else
    CANDIDATES=()
    if [ -n "${PII_CHECK_BASE:-}" ]; then CANDIDATES+=("$PII_CHECK_BASE"); fi
    if [ -n "${GITHUB_BASE_REF:-}" ]; then CANDIDATES+=("origin/$GITHUB_BASE_REF"); fi
    CANDIDATES+=("origin/develop" "develop")
    for c in "${CANDIDATES[@]}"; do
      if resolve_ref "$c"; then CHOSEN="$c"; break; fi
    done
    [ -n "$CHOSEN" ] || fail_structural "unresolvable base ref: no candidate in the default chain resolved (tried \$PII_CHECK_BASE, origin/\$GITHUB_BASE_REF, origin/develop, develop) — pass --base explicitly"
  fi

  POINT="$(git merge-base "$CHOSEN" HEAD 2>/dev/null || true)"
  [ -n "$POINT" ] || POINT="$CHOSEN"

  DIFF_FILE="$WORKDIR/diff"
  git diff "$POINT" > "$DIFF_FILE" 2>/dev/null \
    || fail_structural "git diff against resolved point ($POINT) failed"

  TRIPLES_FILE="$WORKDIR/triples-diff"
  awk -v SEP="$SEP" '
    /^diff --git / { file = ""; next }
    /^\+\+\+ / {
      f = $0
      sub(/^\+\+\+ /, "", f)
      sub(/\t.*$/, "", f)
      if (f == "/dev/null") { file = "" }
      else { sub(/^b\//, "", f); file = f }
      next
    }
    /^--- / { next }
    /^@@/ {
      if (match($0, /\+[0-9]+/)) { newline = substr($0, RSTART + 1, RLENGTH - 1) + 0 }
      next
    }
    /^Binary files / { next }
    /^\\ / { next }
    {
      first = substr($0, 1, 1)
      if (first == "+") {
        content = substr($0, 2)
        sub(/\r$/, "", content)
        if (file != "") { printf "%s%s%s%s%s\n", file, SEP, newline, SEP, content }
        newline++
      } else if (first == " ") {
        newline++
      }
    }
  ' "$DIFF_FILE" > "$TRIPLES_FILE" \
    || fail_structural "failed to parse the diff against resolved point ($POINT)"

  scan_triples "$TRIPLES_FILE" "$FINDINGS_FILE"
fi

if [ -s "$FINDINGS_FILE" ]; then
  cat "$FINDINGS_FILE"
  exit 1
fi

printf 'check-pii-shapes: clean (no PII-shaped bytes found)\n' || true
exit 0
