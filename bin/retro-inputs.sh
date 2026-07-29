#!/usr/bin/env bash
# bin/retro-inputs.sh — acquire the scrum-master retro's material and emit a
# machine-checked ledger (T-1001; docs/specs/T-1001-retro-input-acquisition.md).
#
# Problem this replaces: the retro's declared inputs used to be a `gh pr list`
# query with a hardcoded release-branch flag pointed at `main` (wrong branch
# for this project) plus a `tasks/lessons.md` read (a file that does not exist
# here), and whether an
# input was actually consulted was a sentence a human might forget to write.
# This script derives the cycle window from `git` alone, resolves every
# artefact path through `bin/team-paths.sh`, and reports each of the eight
# canonical inputs below as exactly one of three statuses. `gh` is demoted to
# optional enrichment (the `pr-metadata` line only) — absent, it costs the
# retro one line, nothing else.
#
# Canonical ids and statuses (single source: templates/prompt-blocks/retro-inputs.md;
# kept in sync across consumers by bin/check-prompt-sync.sh):
#   - input: cycle-window
#   - input: review-artifacts
#   - input: provenance
#   - input: specs
#   - input: run-telemetry
#   - input: previous-retro
#   - input: lessons
#   - input: pr-metadata
#   - status: read
#   - status: empty
#   - status: unavailable
#   empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.
#
# The single most important behaviour here: this script never reports `empty`
# when the truth is `unavailable`. A base ref that does not resolve, a shallow
# clone's boundary, or a failing `git` invocation are all `unavailable` — never
# silently substituted with an empty-but-plausible-looking window.
#
# Ledger line grammar (exactly three ` — `-separated fields, so a script
# generated detail can never contain the separator and split the line into a
# fourth field):
#   - input: <id> — status: <read|empty|unavailable> — detail: <one non-empty line>
# with optional indented sub-bullets beneath carrying the material itself (a
# merge commit, a pull request). The same discipline bin/discover-work.sh's
# sanitize() already applies:
# untrusted text (a merge subject, a PR title, a branch name) is stripped of CR, LF, TAB and backticks and has U+2014 replaced before it is emitted, so it can never forge a ledger line
#
# gh contract: when used, the requested field set is exactly
# number,title,mergedAt,author,url,headRefName — the same six fields
# agents/scrum-master.md already trusts. The PR `body` field is never
# requested; PR bodies are attacker-controlled markdown and a prompt-injection
# surface.
#
# structure only: a retro whose ledger says 'read' is not thereby proven to have read anything.
#
# External dependencies: bash + git + standard POSIX tools. No jq/yq/python3/
# perl/node — gh's own built-in --jq does field extraction when gh is used, the
# same precedent bin/discover-work.sh already sets.
#
# Reads only. Never writes, creates, or removes any file (verified: no mktemp/
# tee/cp/mv/rm/touch in this script).
#
# Usage:
#   retro-inputs.sh [--base REF] [--last-n N] [--lessons PATH]
#   retro-inputs.sh --help
#
# Exit codes:
#   0  success (including every degenerate-history / gh-absent case — this
#      script fails soft on missing material and fails closed only on a
#      genuine usage error)
#   2  argument / usage error

set -euo pipefail

# Resolve this script's own dir (symlink-safe) so the sibling team-paths.sh
# resolver is found regardless of cwd / how this script was invoked (mirrors
# bin/discover-work.sh's bootstrap).
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

die() { printf 'retro-inputs: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: retro-inputs.sh [--base REF] [--last-n N] [--lessons PATH]

Acquire the scrum-master retro's material and print a "## Retro inputs"
ledger: one line per canonical input, each with a status of read / empty /
unavailable and a one-line reason.

The cycle window is derived from git merge commits on a resolved ref, never
from gh and never from a hardcoded branch:
  default: develop, falling back to HEAD

Options:
  --base REF      Ref to derive the cycle window from (default: develop,
                  falling back to HEAD when develop does not resolve locally).
  --last-n N      Cap the cycle window to the N most recent merge commits.
                  Also caps the pr-metadata enrichment when gh is available.
                  A cap is a declared, ordinary outcome, distinct from a
                  shallow-clone truncation.
  --lessons PATH  Path to the lessons log. OPTIONAL: there is no resolver key
                  for it (issues #23/#24), so it is read only when this flag
                  is given; without it, the lessons line is unavailable.
  --help, -h      Show this help and exit.
EOF
}

BASE_REF="develop"
BASE_GIVEN=0
LAST_N=""
LESSONS_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --base)    [ "$#" -ge 2 ] || die "--base requires a value"; shift; BASE_REF="$1"; BASE_GIVEN=1; shift ;;
    --last-n)  [ "$#" -ge 2 ] || die "--last-n requires a value"; shift; LAST_N="$1"; shift ;;
    --lessons) [ "$#" -ge 2 ] || die "--lessons requires a value"; shift; LESSONS_PATH="$1"; shift ;;
    --*)       die "unknown flag: $1" ;;
    *)         die "unexpected argument: $1" ;;
  esac
done

case "$LAST_N" in
  '') : ;;
  *[!0-9]*) die "--last-n must be a non-negative integer (got: $LAST_N)" ;;
esac

# ---------------------------------------------------------------------------
# Sanitize untrusted text (a merge subject, a PR title, a branch name) before
# it is ever emitted — the same discipline bin/discover-work.sh's sanitize()
# already applies, and load-bearing here: it is what keeps an adversarial
# merge subject from forging a second ledger line (AC13).
# ---------------------------------------------------------------------------
sanitize() {
  printf '%s' "$1" \
    | tr -d '\r\n\t`' \
    | sed 's/—/-/g'
}

# emit_ledger <id> <status> <detail> — a single top-level ledger line. detail
# is always sanitized: even our own composed text may end up quoting a ref
# name or other dynamic value.
emit_ledger() {
  local id="$1" status="$2" detail
  detail="$(sanitize "$3")"
  [ -n "$detail" ] || detail="(no detail)"
  printf -- '- input: %s — status: %s — detail: %s\n' "$id" "$status" "$detail"
}

# emit_material <line> — an indented sub-bullet carrying the raw material
# (a merge commit, a pull request). Indentation keeps it out of the parsed
# ledger surface: check-retro.sh only validates top-level `- input: ` lines.
emit_material() {
  printf '  - %s\n' "$(sanitize "$1")"
}

echo '## Retro inputs'

# ---------------------------------------------------------------------------
# cycle-window — derived from git merge commits, first-parent, on a resolved
# ref. Never gh, never a hardcoded branch (DP-7). See AC12 for the full
# degenerate-history classification this function implements.
# ---------------------------------------------------------------------------
compute_cycle_window() {
  local ref="$1" given="$2" last_n="$3"
  local resolved fallback=0

  if [ "$given" -eq 1 ]; then
    resolved="$ref"
  elif git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1; then
    resolved="$ref"
  else
    resolved="HEAD"
    fallback=1
  fi

  if ! git rev-parse --verify --quiet "${resolved}^{commit}" >/dev/null 2>&1; then
    CW_STATUS="unavailable"
    CW_DETAIL="base ref does not resolve locally: $resolved"
    CW_MATERIAL=""
    return 0
  fi

  local gitdir=""
  gitdir="$(git rev-parse --git-dir 2>/dev/null)" || gitdir=""
  local shallow=0
  if [ -n "$gitdir" ] && [ -f "$gitdir/shallow" ]; then
    shallow=1
  fi

  local log_out=""
  if ! log_out="$(git log --merges --first-parent --pretty=format:'%H%x09%s' "$resolved" 2>/dev/null)"; then
    CW_STATUS="unavailable"
    CW_DETAIL="git invocation failed while listing merge commits on $resolved"
    CW_MATERIAL=""
    return 0
  fi

  local total=0
  if [ -n "$log_out" ]; then
    total=$(printf '%s\n' "$log_out" | grep -c '.')
  fi

  if [ "$total" -eq 0 ]; then
    CW_MATERIAL=""
    if [ "$shallow" -eq 1 ]; then
      CW_STATUS="unavailable"
      CW_DETAIL="shallow repository: 0 merge commits found within the boundary on $resolved (cannot distinguish no merges from merges beyond the shallow boundary)"
    else
      CW_STATUS="empty"
      CW_DETAIL="0 merge commits reachable from $resolved (first-parent), likely a squash-merge history, not a truncation"
    fi
    return 0
  fi

  local shown="$log_out" total_used="$total" capped=0
  if [ -n "$last_n" ] && [ "$total" -gt "$last_n" ]; then
    # `--last-n 0` is a valid (if degenerate) integer per the arg-parse
    # regex, and BSD/GNU `head -n 0` disagree on whether that is an error
    # (BSD: "illegal line count", exit 1). Handle 0 directly rather than
    # calling head with it, so a valid cap value can never crash this
    # function under errexit and leave the ledger incomplete.
    if [ "$last_n" -eq 0 ]; then
      shown=""
    else
      shown="$(printf '%s\n' "$log_out" | head -n "$last_n")"
    fi
    total_used="$last_n"
    capped=1
  fi
  CW_MATERIAL="$shown"

  local qualifier=""
  if [ "$shallow" -eq 1 ]; then
    qualifier="; shallow clone truncates history at the boundary"
  elif [ "$capped" -eq 1 ]; then
    qualifier="; capped at --last-n $last_n (a declared cap, not a truncation)"
  fi
  if [ "$fallback" -eq 1 ]; then
    qualifier="$qualifier; develop not found locally, fell back to HEAD"
  fi
  CW_STATUS="read"
  CW_DETAIL="$total_used merge commits from $resolved (first-parent)$qualifier"
}

CW_STATUS="" CW_DETAIL="" CW_MATERIAL=""
compute_cycle_window "$BASE_REF" "$BASE_GIVEN" "$LAST_N"
emit_ledger cycle-window "$CW_STATUS" "$CW_DETAIL"
if [ -n "$CW_MATERIAL" ]; then
  while IFS="$(printf '\t')" read -r hash subject; do
    [ -n "$hash" ] || continue
    emit_material "${hash:0:12} $subject"
  done <<< "$CW_MATERIAL"
fi

# ---------------------------------------------------------------------------
# review-artifacts / provenance / specs / run-telemetry / previous-retro —
# every artefact path resolved through bin/team-paths.sh (never hardcoded),
# per AC7. A resolver failure degrades these five, never cycle-window.
# ---------------------------------------------------------------------------
RESOLVER_OK=1
RESOLVER_EXPORTS=""
if ! RESOLVER_EXPORTS="$(bash "$SCRIPT_DIR/team-paths.sh" --export 2>/dev/null)"; then
  RESOLVER_OK=0
else
  eval "$RESOLVER_EXPORTS"
fi

# count_files <dir> <suffix> — number of top-level files under <dir> whose
# name ends with <suffix> (e.g. ".md", ".jsonl"). A plain glob + loop (no
# external pipe) so a permission error or an empty dir never trips
# `set -o pipefail` into a spurious abort.
count_files() {
  local dir="$1" suffix="$2" n=0 f
  shopt -s nullglob
  for f in "$dir"/*"$suffix"; do
    [ -f "$f" ] && n=$((n + 1))
  done
  shopt -u nullglob
  printf '%s' "$n"
}

# report_dir_input <id> <dir> <suffix> <noun> — the shared shape for the four
# directory-backed inputs: absent/unreadable -> unavailable, present-empty ->
# empty, present-with-files -> read (count named, so a `read` detail always
# carries a digit).
report_dir_input() {
  local id="$1" dir="$2" suffix="$3" noun="$4" n
  if [ "$RESOLVER_OK" -ne 1 ]; then
    emit_ledger "$id" unavailable "bin/team-paths.sh could not resolve this repository's operating paths"
    return 0
  fi
  if [ ! -d "$dir" ]; then
    emit_ledger "$id" unavailable "directory not found: $dir"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    emit_ledger "$id" unavailable "directory not readable: $dir"
    return 0
  fi
  n="$(count_files "$dir" "$suffix")"
  if [ "$n" -eq 0 ]; then
    emit_ledger "$id" empty "0 $noun in $dir"
  else
    emit_ledger "$id" read "$n $noun in $dir"
  fi
}

report_dir_input review-artifacts "${TEAM_REVIEWS_DIR:-}"    ".md"    "review artifacts"
report_dir_input provenance       "${TEAM_PROVENANCE_DIR:-}" ".md"    "provenance files"
report_dir_input specs            "${TEAM_SPECS_DIR:-}"      ".md"    "spec files"
report_dir_input run-telemetry    "${TEAM_RUNS_DIR:-}"       ".jsonl" "run telemetry files"
report_dir_input previous-retro   "${TEAM_RETROS_DIR:-}"     ".md"    "prior retro files"

# ---------------------------------------------------------------------------
# lessons — OPTIONAL: there is no resolver key for it (issues #23/#24), so it
# is read only when --lessons PATH is supplied (DP-4). Its absence is a
# recorded status, never a failure.
# ---------------------------------------------------------------------------
if [ -z "$LESSONS_PATH" ]; then
  emit_ledger lessons unavailable "no path supplied via --lessons (no resolver key exists yet; see issue #24)"
elif [ -r "$LESSONS_PATH" ]; then
  n_lines=0
  n_lines="$(grep -c '.' "$LESSONS_PATH" 2>/dev/null || true)"
  [ -n "$n_lines" ] || n_lines=0
  if [ "$n_lines" -eq 0 ]; then
    emit_ledger lessons empty "0 non-blank lines in $LESSONS_PATH"
  else
    emit_ledger lessons read "$n_lines non-blank lines in $LESSONS_PATH"
  fi
else
  emit_ledger lessons unavailable "path supplied but not readable: $LESSONS_PATH"
fi

# ---------------------------------------------------------------------------
# pr-metadata — OPTIONAL enrichment via gh, never the acquisition path for the
# cycle window (AC9/AC10). Absent/unauthenticated/failing -> unavailable, and
# this script still exits 0. Only the six structured fields
# number,title,mergedAt,author,url,headRefName are ever requested — never body.
# ---------------------------------------------------------------------------
PR_LIMIT="${LAST_N:-20}"

if ! command -v gh >/dev/null 2>&1; then
  emit_ledger pr-metadata unavailable "gh CLI not found (optional enrichment only)"
elif ! gh auth status >/dev/null 2>&1; then
  emit_ledger pr-metadata unavailable "gh is not authenticated (optional enrichment only)"
else
  pr_out=""
  if ! pr_out="$(gh pr list --state merged --limit "$PR_LIMIT" \
                  --json number,title,mergedAt,author,url,headRefName \
                  --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"' 2>/dev/null)"; then
    emit_ledger pr-metadata unavailable "gh pr list failed"
  elif [ -z "$pr_out" ]; then
    emit_ledger pr-metadata empty "0 merged pull requests returned by gh"
  else
    n_pr="$(printf '%s\n' "$pr_out" | grep -c '.')"
    emit_ledger pr-metadata read "$n_pr merged pull requests via gh (title/headRefName/number/mergedAt/author/url only, no body)"
    while IFS="$(printf '\t')" read -r num branch title; do
      [ -n "$num" ] || continue
      emit_material "#$num ($branch) $title"
    done <<< "$pr_out"
  fi
fi

exit 0
