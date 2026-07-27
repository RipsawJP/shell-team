#!/usr/bin/env bash
# bin/check-pii-shapes.sh — diff-scoped PII shape checker (T-111, GitHub issue
# #6 Layer 2 items 4-5; .shell-team/specs/T-111-pii-shape-checker.md, v4).
#
# Development on this repository happens in the open, so a PII-shaped byte
# (an email-shaped string, a home-directory absolute path, a private-key
# header, a credential-token prefix) is a per-commit risk. This script gives
# that risk a mechanical gate: by default it looks at the full committed
# content of each path a change touches (change-scoped, never the whole
# tree), and it is fail-closed — a run that cannot evaluate its input never
# reports clean.
#
# Five shapes are matched, each identified by a stable pattern id used in
# every finding line:
#   home-path         a POSIX home-directory absolute path with a real name
#                     segment (e.g. the placeholder shape /Users/<name>/ —
#                     written here with angle brackets precisely so this
#                     file, this spec, and the docs pair can discuss the
#                     shape without becoming a finding themselves; see AC9).
#                     Matched only at a boundary that cannot continue a host
#                     name (see DP-5 below) — a URL authority is therefore
#                     never a match.
#   home-path-win     the Windows C: user-directory form (same placeholder
#                     convention, C:\Users\<name>\). Not boundary-guarded:
#                     a backslash-delimited path never appears as a URL
#                     authority, so the false-positive class DP-5 closes for
#                     home-path does not reach this form.
#   email-nonnoreply  a mailbox-shaped string at a real, deliverable domain.
#                     Every mailbox-shaped candidate on a line is judged
#                     (AC26), not just the first. Excluded, by domain
#                     (never by local-part shape — DP-9): the GitHub noreply
#                     identity domain (end-anchored) and the plain web-flow
#                     noreply@github.com address; and by domain (DP-7): the
#                     RFC 2606 / 6761 reserved documentation/testing names.
#   private-key       a PEM private-key header line (named by id only in
#                     this file's prose; never transcribed literally here,
#                     since a document that transcribed a real match would
#                     red its own gate — see the spec's DP-1).
#   token             a credential-token prefix (GitHub gh[oprs]_, AWS AKIA,
#                     an OpenAI-style sk- key) long enough to be a real key
#                     body, not a short lookalike such as this project's own
#                     `task-0NN` label convention.
#
# Mechanism (DP-4, v4's premise change): this script NEVER parses git's
# textual diff rendering. A rendering is a human-facing format whose framing
# is configuration-dependent (colour, external diff, textconv, a -diff
# gitattribute) and whose escape syntax collides with content (a line whose
# real content starts with "++ " renders as "+++ "). Two rounds of a
# hand-rolled diff-text parser landed real blockers here, so the mechanism
# changed instead of patching the parser a third time:
#   - Changed paths are enumerated from NUL-separated `git diff --name-status
#     -z --no-renames` output — never from a textual patch.
#   - Each surviving path's content is read through `git cat-file`, plumbing
#     that returns the raw committed blob (for a symlink, the target string
#     git itself stores — never a followed link) with no framing, no colour,
#     no escape grammar to get wrong.
#   - The scanned unit is the FULL committed content of each changed path
#     (DP-6), not "added lines" — there is no base-blob comparison. A
#     one-time measurement found every currently tracked path that carries a
#     shape carries a false positive or a deliberate fixture, never a real
#     value, so the noise a per-path diff would have suppressed is handled
#     at the pattern level (DP-5, DP-7) and by name (DP-8) instead.
#   - Text vs binary is decided by the presence of a NUL byte (git's own
#     convention), never a printable-character heuristic — see AC27.
# Every `git` invocation below still pins its rendering (--no-color); under
# this mechanism that can no longer change a verdict, so it is free
# insurance, not a defence this script depends on.
#
# DP-5 (home-path boundary): the home-path shape only matches at the start
# of a line or when preceded by a character that cannot continue a host
# name (a letter or digit) — a documentation URL whose path merely contains
# a home-directory-looking segment (https://example.com/home/products) is
# therefore not a finding. Declared consequence: a home path written inside
# a file://-style URL is likewise not reported (a narrower loss than the
# false positive this rule removes).
#
# DP-7 (reserved-domain exclusion): a mailbox shape at the RFC 2606 /
# RFC 6761 reserved documentation/testing names (example.com/.org/.net, and
# any domain ending in .example/.invalid/.test/.localhost) is not a finding
# — those domains cannot route to a real mailbox by construction.
#
# DP-9 (noreply exclusion, domain-anchored): a mailbox shape whose domain is
# EXACTLY (end-anchored) the GitHub noreply identity domain is not a
# finding, regardless of what the local part looks like — a login, a
# numeric id plus a login, or a printf format placeholder assembled at
# runtime. The exclusion never inspects the local part; a substring match on
# the domain is deliberately avoided so a suffix-confusable lookalike domain
# still fires. The plain web-flow noreply@github.com address is its own,
# separate, full-address exclusion.
#
# DP-8 (known-shapes list): a short, per-file (never a directory or glob)
# list of paths that deliberately carry a shape as a fixture FOR ANOTHER
# GUARD's own suite. It is not an exemption for this task's own files —
# this script's own path and any path under tests/check-pii-shapes/ are
# never listed and stay runtime-generated (DP-1); a shape in either is still
# reported (AC13).
#
# DP-1: no PII-shaped byte enters this tree. Every fixture the test suite
# uses is assembled at runtime, under mktemp, from fragments — never
# written here as a completed literal. There is no path allowlist beyond
# DP-8's narrow, test-locked, other-guard-only list, and no inline allow
# marker anywhere in this file.
#
# A finding never echoes the matched text — only the pattern id, the path,
# and a line number (when available) are reported — so a public CI log
# never carries the byte that tripped the gate (AC14).
#
# This is a discipline aid for a trusted, reviewed artifact, not a security
# boundary against an author editing this checker itself in the same commit
# (same trust boundary as bin/check-acs.sh's TRUST BOUNDARY note and
# bin/check-intent.sh's ledger note) — PR review is that layer.
#
# Usage:
#   check-pii-shapes.sh [--base <ref>]     change-scoped (default)
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
  sed -n '2,124p' "$SELF" | sed 's/^# \{0,1\}//' \
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

# --- pattern + exclusion definitions -----------------------------------------
# Each rule lives on its own assignment line so a fixture suite can
# neutralise exactly one at a time by rewriting that one line. There are
# nine independently load-bearing rules: five patterns, plus four
# exclusions (the domain-anchored noreply rule, the plain web-flow address,
# the reserved-domain rule, and the home-path boundary rule).
#
# shellcheck disable=SC2016  # single-quoted regex text, not a variable expansion
RE_HOME_PATH_BOUNDARY='(^|[^A-Za-z0-9])'
# shellcheck disable=SC2016
RE_HOME_PATH_RAW='/(Users|home)/[A-Za-z0-9_.-]+'
RE_HOME_PATH="${RE_HOME_PATH_BOUNDARY}${RE_HOME_PATH_RAW}"
# shellcheck disable=SC2016
RE_HOME_PATH_WIN='C:\\{1,2}Users\\{1,2}[A-Za-z0-9_.-]+'
# shellcheck disable=SC2016
RE_EMAIL_BASE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# shellcheck disable=SC2016
RE_NOREPLY_DOMAIN='(^|\.)users\.noreply\.github\.com$'
# shellcheck disable=SC2016
RE_NOREPLY_PLAIN='^noreply@github\.com$'
# shellcheck disable=SC2016
RE_RESERVED_DOMAIN='(^|\.)example\.(com|org|net)$|\.(example|invalid|test|localhost)$'
# shellcheck disable=SC2016
RE_PRIVATE_KEY='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
# shellcheck disable=SC2016
RE_TOKEN='gh[oprs]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{12,}|sk-[A-Za-z0-9_-]{16,}'

# --- known-shapes list (DP-8) ------------------------------------------------
# Per-file only — no directory entry, no glob, no pattern. Fixtures that
# deliberately carry a PII shape FOR ANOTHER GUARD's own suite
# (tests/rollup-track/run.sh). Never this script's own path, never a path
# under tests/check-pii-shapes/ — those stay runtime-generated (DP-1) and a
# shape in them is always reported (AC13).
KNOWN_SHAPE_PATHS=(
  "tests/rollup-track/fixtures/pii.jsonl"
  "tests/rollup-track/fixtures/winpath.jsonl"
  "tests/rollup-track/fixtures/secret-aws.jsonl"
  "tests/rollup-track/fixtures/secret-github.jsonl"
  "tests/rollup-track/fixtures/secret-openai.jsonl"
)

is_known_shape() {  # $1 = path (repo-root-relative)
  local p="$1" k
  for k in "${KNOWN_SHAPE_PATHS[@]}"; do
    [ "$p" = "$k" ] && return 0
  done
  return 1
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes.XXXXXX")" \
  || fail_structural "failed to create a scratch directory under mktemp"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

FINDINGS_FILE="$WORKDIR/findings"
CONTENT_FILE="$WORKDIR/content"
: > "$FINDINGS_FILE"

# is_binary_file <file> — true (0) iff <file> contains a NUL byte (git's own
# text/binary convention — never a printable-character heuristic, AC27).
is_binary_file() {
  LC_ALL=C tr -d '\000' < "$1" > "$WORKDIR/stripped" 2>/dev/null || return 1
  ! cmp -s "$WORKDIR/stripped" "$1"
}

# report_pattern_lines <id> <path> <contentfile> <regex> — one FINDING line
# per matching line number. grep's own "N:content" output is read but only
# the N field is ever used; the content half is discarded before it can be
# written anywhere (AC14: a finding never echoes the matched text).
report_pattern_lines() {
  local id="$1" path="$2" file="$3" re="$4" ln rest
  # `--` guards against a regex that itself begins with a literal `-`
  # (RE_PRIVATE_KEY does) being parsed as a grep option instead of a
  # pattern argument.
  grep -nE -- "$re" "$file" > "$WORKDIR/matches" 2>/dev/null || true
  while IFS=: read -r ln rest; do
    [ -n "${ln:-}" ] || continue
    printf 'FINDING pattern=%s path=%s line=%s\n' "$id" "$path" "$ln" >> "$FINDINGS_FILE"
  done < "$WORKDIR/matches"
}

# scan_email_candidates <path> <contentfile> — every mailbox-shaped
# candidate on every line is judged individually (AC26), never only the
# leftmost: an excluded noreply/reserved-domain address earlier on a line
# never masks a real mailbox shape later on the same line. At most one
# FINDING line is emitted per (path, line) pair even if several candidates
# on that line survive exclusion.
scan_email_candidates() {
  local path="$1" file="$2" ln cand domain excluded last_ln=""
  grep -noE -- "$RE_EMAIL_BASE" "$file" > "$WORKDIR/emails" 2>/dev/null || true
  while IFS=: read -r ln cand; do
    [ -n "${ln:-}" ] || continue
    domain="${cand#*@}"
    excluded=0
    if [[ "$cand" =~ $RE_NOREPLY_PLAIN ]]; then
      excluded=1
    elif [[ "$domain" =~ $RE_NOREPLY_DOMAIN ]]; then
      excluded=1
    elif [[ "$domain" =~ $RE_RESERVED_DOMAIN ]]; then
      excluded=1
    fi
    if [ "$excluded" -eq 0 ] && [ "$ln" != "$last_ln" ]; then
      printf 'FINDING pattern=email-nonnoreply path=%s line=%s\n' "$path" "$ln" >> "$FINDINGS_FILE"
      last_ln="$ln"
    fi
  done < "$WORKDIR/emails"
}

# scan_content_file <path> <contentfile> — runs all five pattern checks
# against already-materialized, already-confirmed-non-binary content.
scan_content_file() {
  local path="$1" file="$2"
  report_pattern_lines home-path "$path" "$file" "$RE_HOME_PATH"
  report_pattern_lines home-path-win "$path" "$file" "$RE_HOME_PATH_WIN"
  report_pattern_lines private-key "$path" "$file" "$RE_PRIVATE_KEY"
  report_pattern_lines token "$path" "$file" "$RE_TOKEN"
  scan_email_candidates "$path" "$file"
}

announce_skip() {  # $1 = path, $2 = mode label (blob|file)
  printf 'check-pii-shapes: skip: binary %s (NUL byte present), not scanned: %s\n' "$2" "$1" >&2 || true
}

if [ "$MODE" = "all" ]; then
  # --- full-tree audit: repo-root scope regardless of invoking directory,
  # tracked + untracked-but-not-ignored files, symlinks scanned by their
  # stored target string rather than followed, never a silent skip (AC29).
  TOPLEVEL="$(git rev-parse --show-toplevel)" \
    || fail_structural "git rev-parse --show-toplevel failed — cannot resolve the repository root for --all"
  cd "$TOPLEVEL" || fail_structural "failed to change into the repository root ($TOPLEVEL) for --all"

  FILELIST_Z="$WORKDIR/filelist-z"
  git ls-files -z --cached --others --exclude-standard > "$FILELIST_Z" \
    || fail_structural "git ls-files failed — cannot enumerate the tree for --all"

  FILELIST="$WORKDIR/filelist"
  : > "$FILELIST"
  while IFS= read -r -d '' p; do
    printf '%s\n' "$p" >> "$FILELIST"
  done < "$FILELIST_Z"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    is_known_shape "$path" && continue

    if [ -L "$path" ]; then
      # A tracked/untracked symbolic link: scan the target string git
      # itself stores, never the file the link points at (which need not
      # even exist on this machine) — the classic --all blind spot.
      target="$(readlink "$path")" \
        || fail_structural "cannot read symlink target for: $path"
      printf '%s' "$target" > "$CONTENT_FILE"
      scan_content_file "$path" "$CONTENT_FILE"
      continue
    fi

    [ -e "$path" ] || fail_structural "path listed by git ls-files no longer exists on disk: $path"
    [ -r "$path" ] || fail_structural "cannot read file listed by git ls-files: $path"
    if is_binary_file "$path"; then
      announce_skip "$path" file
      continue
    fi
    cp "$path" "$CONTENT_FILE" 2>/dev/null \
      || fail_structural "failed to read file listed by git ls-files: $path"
    scan_content_file "$path" "$CONTENT_FILE"
  done < "$FILELIST"
else
  # --- change-scoped: resolve the comparison point, then read the FULL
  # committed content of each changed path (DP-4/DP-6) — never a diff
  # rendering, never a base-blob comparison.
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

  NAMESTATUS_Z="$WORKDIR/namestatus-z"
  # --no-color pins the rendering (free insurance under DP-4, since
  # --name-status is never colourised regardless); --no-renames disables
  # rename detection so every entry below is exactly two NUL-separated
  # tokens (status, path) — never the three-token rename/copy form.
  git diff --no-color --no-renames --name-status -z "$POINT" HEAD > "$NAMESTATUS_Z" 2>/dev/null \
    || fail_structural "git diff --name-status failed against resolved point ($POINT)"

  CHANGED_PATHS="$WORKDIR/changed-paths"
  : > "$CHANGED_PATHS"
  {
    while IFS= read -r -d '' status && IFS= read -r -d '' path; do
      [ "$status" = "D" ] && continue
      printf '%s\n' "$path" >> "$CHANGED_PATHS"
    done
  } < "$NAMESTATUS_Z"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    is_known_shape "$path" && continue

    git cat-file -p "HEAD:$path" > "$CONTENT_FILE" 2>/dev/null
    rc=$?
    if [ "$rc" -ne 0 ]; then
      fail_structural "failed to read committed content via git cat-file for: $path"
    fi
    if is_binary_file "$CONTENT_FILE"; then
      announce_skip "$path" blob
      continue
    fi
    scan_content_file "$path" "$CONTENT_FILE"
  done < "$CHANGED_PATHS"
fi

if [ -s "$FINDINGS_FILE" ]; then
  cat "$FINDINGS_FILE"
  exit 1
fi

printf 'check-pii-shapes: clean (no PII-shaped bytes found)\n' || true
exit 0
