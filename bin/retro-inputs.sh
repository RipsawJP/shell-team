#!/usr/bin/env bash
# bin/retro-inputs.sh — acquire the scrum-master retro's material and emit a
# machine-checked ledger (T-1001; docs/specs/T-1001-retro-input-acquisition.md).
#
# Problem this replaces: the retro's declared inputs used to be a `gh pr list`
# query with a hardcoded release-branch flag pointed at `main` (wrong branch
# for this project) plus a `tasks/lessons.md` read (a file that does not exist
# here), and whether an input was actually consulted was a sentence a human
# might forget to write. This script derives the cycle window from `git`
# alone and resolves every directory-backed artefact path through
# `bin/team-paths.sh`, and reports each of the nine canonical inputs below as
# exactly one of three statuses. `gh` is demoted to optional pr-metadata
# enrichment. The lessons log is the one input this script does NOT resolve
# itself, by choice (T-1006 DP-1(b)): a resolver key exists
# (`bin/team-paths.sh --get lessons`), but wiring this script to it would drag
# in the DS-5/DS-6 promotion semantics this task's retro side owns — so the
# path is read only when a caller supplies it via `--lessons PATH`.
#
# v2 design (see spec's "What v1 of this task got wrong, and why v2 exists"):
# v1 defended each status with its own hand-written guard, and three
# independent guards were missing — CRLF-unaware section detection, a
# read-permission-only directory check that cannot see a non-traversable
# directory, and a shallow probe that answers wrong from a linked worktree.
# `unavailable` is now the DEFAULT for every ledger line. `read` and `empty`
# are produced ONLY by the two promotion functions below (`promote_read` /
# `promote_empty`), called from exactly eight sites, each requiring an
# AFFIRMATIVE determination that the input was actually enumerable. A probe
# that returns early, cannot answer, or hits an unhandled branch leaves the
# unavailable default standing — the missing guard stops being a defect.
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
#   - input: interventions
#   - status: read
#   - status: empty
#   - status: unavailable
#   empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.
#
# review-artifacts counts any regular file, not only names ending in .md:
# bin/codex-capture.sh publishes its own review capture as <stem>.txt and
# <stem>.jsonl inside the resolved reviews dir (T-1042), so a suffix check
# that only recognized .md would under-report a reviews dir holding exactly
# that first-party output as `empty` when it in fact holds material. An
# extensionless file and an unfamiliar extension both count too -- "any
# regular file" is the rule, not an enumerated suffix set. Dotfiles (the
# `.codex-capture.*` pre-publish temps) and subdirectories are still excluded
# by the existing nullglob-without-dotglob enumeration; the other five
# directory-backed inputs keep their own `.md` / `.jsonl` suffix rules.
#
# Decision-site inventory (AC4): one row per promotion call site, each naming
# the determination it makes, the precondition(s) it requires, and stating
# that `unavailable` stands when the determination cannot be made. Every row
# is exercised by a fixture in tests/retro-inputs/run.sh that makes that
# determination impossible.
#   DS-1 cycle-window/read: determination = the merge-commit count for the resolved ref is known, having confirmed the ref resolves, whether the repository is shallow (git rev-parse --is-shallow-repository answered), and that git log --merges succeeded. Precondition: git responds; the ref resolves; the shallow question is answerable; git log succeeds. If any precondition fails, unavailable stands -- no promotion is attempted.
#   DS-2 cycle-window/empty: determination = the merge-commit count is confirmed zero AND the repository is confirmed NOT shallow, so "zero" cannot mean "truncated before any merge". Precondition: same as DS-1, evaluated with shallow=false and total=0. A shallow repository with zero merges in the boundary fails this precondition and unavailable stands.
#   DS-3 directory-input/read (review-artifacts, provenance, specs, run-telemetry, previous-retro, interventions): determination = the directory's entries were fully enumerated -- every name a glob returned could also be stat'ed -- and at least one matches the expected suffix. Precondition: the directory exists, is readable, and every returned name is stat'able (search/traverse permission). A readable-but-not-traversable directory fails this precondition and unavailable stands, never empty.
#   DS-4 directory-input/empty: determination = the directory's entries were fully enumerated and confirmed to contain zero matches. Precondition: the same enumeration-completeness test as DS-3, evaluated to zero matches. An incomplete enumeration (readable, not traversable) fails this precondition and unavailable stands, never a false empty.
#   DS-5 lessons/read: determination = the supplied --lessons path is a readable regular file whose non-blank line count is known. Precondition: a path was supplied, it exists, is a regular file, and is readable. An unreadable path fails this precondition and unavailable stands.
#   DS-6 lessons/empty: determination = the supplied --lessons path's non-blank line count is confirmed to be zero. Precondition: same countable-regular-file precondition as DS-5, evaluated to a zero count. A path that is not a countable regular file (e.g. a directory) fails this precondition and unavailable stands.
#   DS-7 pr-metadata/read: determination = gh successfully listed one or more merged pull requests. Precondition: gh is present, authenticated, and the list command succeeds. An unauthenticated gh fails this precondition and unavailable stands.
#   DS-8 pr-metadata/empty: determination = gh successfully confirmed zero merged pull requests -- a successful call with empty output, never a failed one. Precondition: same as DS-7, with the list command itself succeeding. A failing list command fails this precondition and unavailable stands -- it is never read as "confirmed zero".
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
unavailable and a one-line reason. unavailable is the default for every
line; read and empty are promotions that require an affirmative
determination (see the decision-site inventory in this script's header).

The cycle window is derived from git merge commits on a resolved ref, never
from gh and never from a hardcoded branch:
  default: develop, falling back to HEAD

Options:
  --base REF      Ref to derive the cycle window from (default: develop,
                  falling back to HEAD when develop does not resolve locally).
  --last-n N      Cap the cycle window to the N most recent merge commits.
                  Also caps the pr-metadata enrichment when gh is available.
                  A cap is a declared, ordinary outcome, distinct from a
                  shallow-clone truncation -- both are stated when both apply.
  --lessons PATH  Path to the lessons log. OPTIONAL: a resolver key exists
                  (bin/team-paths.sh --get lessons), but this script asks for
                  the path explicitly, by choice (T-1006 DP-1(b)) -- it is
                  read only when this flag is given; without it, the lessons
                  line is unavailable.
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

# ---------------------------------------------------------------------------
# The inverted default (DP-2). IDS is the single canonical order (matches
# templates/prompt-blocks/retro-inputs.md). Every ST_/DE_ pair is initialised
# to "unavailable" / a generic placeholder BEFORE any probe runs; probing and
# emission are two separate passes (AC3): probes run first and may call
# note() (updates the detail only, leaving status at its current value — not
# a promotion site) or promote_read()/promote_empty() (the ONLY two functions
# that can move a status away from unavailable); emission happens once, at
# the very end, over the canonical id list.
# ---------------------------------------------------------------------------
IDS="cycle-window review-artifacts provenance specs run-telemetry previous-retro lessons pr-metadata interventions"

for id in $IDS; do
  var="ST_${id//-/_}"; printf -v "$var" '%s' "unavailable"
  var="DE_${id//-/_}"; printf -v "$var" '%s' "not determined"
done
CW_MATERIAL=""
PR_MATERIAL=""

# note <id> <detail> — updates ONLY the detail text for <id>; the status is
# left exactly as it already is (almost always still the unavailable
# default). Never a promotion site — not counted by AC2's call-site pattern.
note() {
  local var="DE_${1//-/_}"
  printf -v "$var" '%s' "$2"
}

# The chokepoint (DP-2): exactly one place in the script formats a ledger
# line (emit_all, far below), exactly two functions can move a status away
# from the unavailable default, and exactly eight call sites invoke them —
# one per canonical promotion listed in the decision-site inventory above.
promote_read() {
  local var; var="ST_${1//-/_}"; printf -v "$var" '%s' "read"
  var="DE_${1//-/_}"; printf -v "$var" '%s' "$2"
}

promote_empty() {
  local var; var="ST_${1//-/_}"; printf -v "$var" '%s' "empty"
  var="DE_${1//-/_}"; printf -v "$var" '%s' "$2"
}

# ---------------------------------------------------------------------------
# cycle-window (DS-1 read / DS-2 empty) — derived from git merge commits,
# first-parent, on a resolved ref. Never gh, never a hardcoded branch (DP-7).
# Every branch — read, empty, unavailable alike — names the ref actually
# resolved (or attempted) and states a develop->HEAD fallback whenever one
# occurred, not only on the branch that reaches promotion (AC11).
# ---------------------------------------------------------------------------
probe_cycle_window() {
  local ref="$1" given="$2" last_n="$3"
  local resolved="$ref" fallback=0 rc fb_note=""

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    note cycle-window "git did not answer (a failing git invocation) while resolving $resolved"
    return 0
  fi

  if [ "$given" -ne 1 ]; then
    # A bare `cmd; rc=$?` would trip errexit on a nonzero exit BEFORE rc is
    # ever assigned — the `if` form is what keeps a "ref absent" or "git
    # errored" result from aborting the whole script (bash treats a
    # condition's own exit status as exempt from set -e).
    if git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1; then
      rc=0
    else
      rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
      resolved="$ref"
    elif [ "$rc" -eq 1 ]; then
      # git answered (quiet exit 1 is real git's "not found" contract); the
      # ref is genuinely absent, distinct from git failing to answer at all.
      resolved="HEAD"
      fallback=1
    else
      note cycle-window "git could not answer whether $ref exists locally (exit $rc), so no fallback was attempted"
      return 0
    fi
  fi
  # A boolean-AND-chained assignment (a test, the AND operator, then a bare
  # name equals value) conditions the assignment on a preceding test — under
  # errexit, if a LATER statement in the same context also happens to run,
  # a false condition here is silently forgiven (the defect this task's own
  # round-2 review hid); the `if` form has no such order dependency.
  if [ "$fallback" -eq 1 ]; then
    fb_note="; develop not found locally, fell back to HEAD"
  fi

  if git rev-parse --verify --quiet "${resolved}^{commit}" >/dev/null 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 1 ]; then
      note cycle-window "base ref does not resolve locally: $resolved$fb_note"
    else
      note cycle-window "git could not answer whether $resolved resolves (exit $rc)$fb_note"
    fi
    return 0
  fi

  # Shallow determination: git rev-parse --is-shallow-repository (worktree-
  # correct — the AC5 defect was reading $(git rev-parse --git-dir)/shallow,
  # which is the WORKTREE-specific directory in a linked worktree while the
  # shallow marker lives in the common directory). Available since git 2.15;
  # on an older git the inverted default applies (unavailable), per the
  # spec's own Assumptions — a declared absence rather than a wrong `empty`.
  local shallow_out="" shallow_rc=0 shallow=0 shallow_known=1
  if shallow_out="$(git rev-parse --is-shallow-repository 2>/dev/null)"; then
    shallow_rc=0
  else
    shallow_rc=$?
  fi
  if [ "$shallow_rc" -ne 0 ]; then
    shallow_known=0
  elif [ "$shallow_out" = "true" ]; then
    shallow=1
  elif [ "$shallow_out" != "false" ]; then
    shallow_known=0
  fi

  if [ "$shallow_known" -ne 1 ]; then
    note cycle-window "could not determine whether $resolved is a shallow repository (git rev-parse --is-shallow-repository did not answer)$fb_note"
    return 0
  fi

  local log_out=""
  if ! log_out="$(git log --merges --first-parent --pretty=format:'%H%x09%s' "$resolved" 2>/dev/null)"; then
    note cycle-window "git invocation failed while listing merge commits on $resolved$fb_note"
    return 0
  fi

  local total=0
  if [ -n "$log_out" ]; then
    total=$(printf '%s\n' "$log_out" | grep -c '.')
  fi

  if [ "$total" -eq 0 ]; then
    if [ "$shallow" -eq 1 ]; then
      # DS-2's blocked precondition: shallow=true means "confirmed zero" is
      # unreachable — cannot distinguish no merges from merges beyond the
      # shallow boundary. unavailable stands; empty is never promoted.
      note cycle-window "shallow repository: 0 merge commits found within the boundary on $resolved (cannot distinguish no merges from merges beyond the shallow boundary)$fb_note"
    else
      promote_empty cycle-window "0 merge commits reachable from $resolved (first-parent), confirmed complete (not a truncation)$fb_note"
    fi
    return 0
  fi

  local shown="$log_out" total_used="$total" capped=0
  if [ -n "$last_n" ] && [ "$total" -gt "$last_n" ]; then
    # Never `| head` here: piping a merge log into a reader that can exit
    # before it has consumed all the writer's output gives the writer a
    # SIGPIPE once the data exceeds the pipe buffer (measured around 64 KB —
    # bytes, not merge count, so a repository with long branch names reaches
    # it with far fewer merges than a count-based estimate suggests); under
    # pipefail the assignment then fails and errexit aborts the whole script
    # before the ledger's emission pass. A here-string (`<<<`) has no live
    # writer process to signal, so awk can read and cap the line count with
    # no SIGPIPE exposure regardless of size. This also handles `--last-n 0`
    # correctly with no special case: `NR<=0` is never true, so `shown` is
    # naturally empty (BSD and GNU `head -n 0` disagree on whether that is
    # even a valid invocation; awk has no such ambiguity).
    shown="$(awk -v n="$last_n" 'NR <= n' <<< "$log_out")"
    total_used="$last_n"
    capped=1
  fi

  if [ -n "$shown" ]; then
    CW_MATERIAL="$(printf '%s\n' "$shown" | while IFS="$(printf '\t')" read -r hash subject; do
      [ -n "$hash" ] && printf '%s %s\n' "${hash:0:12}" "$subject"
    done)"
  fi

  # Every applicable qualifier is stated (not just the first) — a cap and a
  # shallow truncation are different facts and can be true at once (AC11).
  # `if`, not a boolean-AND-chained assignment (AC8) — see the fallback note above for why.
  local qualifiers=""
  if [ "$shallow" -eq 1 ]; then
    qualifiers="$qualifiers; shallow clone truncates history at the boundary"
  fi
  if [ "$capped" -eq 1 ]; then
    qualifiers="$qualifiers; capped at --last-n $last_n (a declared cap, not a truncation)"
  fi
  qualifiers="$qualifiers$fb_note"

  promote_read cycle-window "$total_used merge commits from $resolved (first-parent)$qualifiers"
}

# ---------------------------------------------------------------------------
# directory-backed inputs (DS-3 read / DS-4 empty): review-artifacts,
# provenance, specs, run-telemetry, previous-retro. Every artefact path is
# resolved through bin/team-paths.sh (AC7) — never hardcoded.
# ---------------------------------------------------------------------------
RESOLVER_OK=1
RESOLVER_EXPORTS=""
if ! RESOLVER_EXPORTS="$(bash "$SCRIPT_DIR/team-paths.sh" --export 2>/dev/null)"; then
  RESOLVER_OK=0
else
  eval "$RESOLVER_EXPORTS"
fi

# count_dir_entries <dir> <suffix> — enumerate <dir>'s top-level entries and
# determine (never infer) whether the enumeration was COMPLETE: every name
# the glob returned could also be stat'ed. Writes DIR_N_NAMES, DIR_N_STATABLE,
# DIR_N_MATCH. A readable-but-not-traversable directory can return names via
# readdir (needs only read permission) that then fail to stat (needs
# search/execute permission on the directory) — the exact substitution the
# directory decision sites exist to prevent. A directory with zero names is legitimately complete
# (0 returned, 0 expected to stat — no disagreement), so a genuinely empty,
# non-traversable directory still confirms `empty` correctly.
count_dir_entries() {
  local dir="$1" suffix="$2" f names=()
  DIR_N_NAMES=0
  DIR_N_STATABLE=0
  DIR_N_MATCH=0
  shopt -s nullglob
  for f in "$dir"/*; do
    names+=("$f")
  done
  shopt -u nullglob
  DIR_N_NAMES=${#names[@]}
  # bash 3.2 (macOS's default /bin/bash) throws "unbound variable" under
  # `set -u` when expanding "${arr[@]}" on a genuinely EMPTY array (fixed in
  # bash 4.4) — guard with the length check rather than dropping set -u.
  if [ "$DIR_N_NAMES" -gt 0 ]; then
    for f in "${names[@]}"; do
      if [ -e "$f" ] || [ -L "$f" ]; then
        DIR_N_STATABLE=$((DIR_N_STATABLE + 1))
        # AC8: not `[ -f "$f" ]` boolean-AND-chained straight into an
        # assignment inside the case arm — a case arm's own exit status is
        # its LAST command's, so a name that matches the suffix but fails
        # the regular-file test (a directory called something ending in
        # .md, or a broken symlink) makes the whole case statement return
        # 1, and the bare call site in report_dir_input() below then dies
        # under errexit — exit 1, zero ledger lines, on the default
        # path. An `if` inside the `case` arm has no such propagation.
        case "$f" in
          *"$suffix")
            if [ -f "$f" ]; then
              DIR_N_MATCH=$((DIR_N_MATCH + 1))
            fi
            ;;
        esac
      fi
    done
  fi
  return 0
}

report_dir_input() {
  local id="$1" dir="$2" suffix="$3" noun="$4"
  if [ "$RESOLVER_OK" -ne 1 ]; then
    note "$id" "bin/team-paths.sh could not resolve this repository's operating paths"
    return 0
  fi
  if [ ! -d "$dir" ]; then
    note "$id" "directory not found: $dir"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    note "$id" "directory not readable: $dir"
    return 0
  fi
  count_dir_entries "$dir" "$suffix"
  if [ "$DIR_N_NAMES" -gt 0 ] && [ "$DIR_N_STATABLE" -lt "$DIR_N_NAMES" ]; then
    note "$id" "directory entries could not all be stat'ed ($DIR_N_STATABLE/$DIR_N_NAMES enumerated) -- not traversable: $dir"
    return 0
  fi
  if [ "$DIR_N_MATCH" -eq 0 ]; then
    promote_empty "$id" "0 $noun in $dir"
  else
    promote_read "$id" "$DIR_N_MATCH $noun in $dir"
  fi
}

report_dir_input review-artifacts "${TEAM_REVIEWS_DIR:-}"    ""       "review artifacts"
report_dir_input provenance       "${TEAM_PROVENANCE_DIR:-}" ".md"    "provenance files"
report_dir_input specs            "${TEAM_SPECS_DIR:-}"      ".md"    "spec files"
report_dir_input run-telemetry    "${TEAM_RUNS_DIR:-}"       ".jsonl" "run telemetry files"
report_dir_input previous-retro   "${TEAM_RETROS_DIR:-}"     ".md"    "prior retro files"
report_dir_input interventions    "${TEAM_INTERVENTIONS_DIR:-}" ".md" "intervention records"

# ---------------------------------------------------------------------------
# lessons (DS-5 read / DS-6 empty) — OPTIONAL: a resolver key exists
# (bin/team-paths.sh --get lessons; T-1006), but this script asks for the
# path explicitly, by choice (DP-1(b) in that task's spec) -- it is read
# only when --lessons PATH is supplied (DP-4). Its absence is a recorded
# status, never a failure.
# ---------------------------------------------------------------------------
probe_lessons() {
  local path="$1"
  if [ -z "$path" ]; then
    note lessons "no path supplied via --lessons (a resolver key exists -- team-paths.sh --get lessons -- but this script asks for the path explicitly, by choice)"
    return 0
  fi
  if [ ! -f "$path" ]; then
    # DS-6's blocked precondition: not a countable regular file (e.g. a
    # directory) — "confirmed zero" is unreachable, so unavailable stands.
    note lessons "path supplied but not a regular file: $path"
    return 0
  fi
  if [ ! -r "$path" ]; then
    # DS-5's blocked precondition: exists as a regular file, but unreadable.
    note lessons "path supplied but not readable: $path"
    return 0
  fi
  local n_lines=0
  n_lines="$(grep -c '.' "$path" 2>/dev/null || true)"
  [ -n "$n_lines" ] || n_lines=0
  if [ "$n_lines" -eq 0 ]; then
    promote_empty lessons "0 non-blank lines in $path"
  else
    promote_read lessons "$n_lines non-blank lines in $path"
  fi
}
probe_lessons "$LESSONS_PATH"

# ---------------------------------------------------------------------------
# pr-metadata (DS-7 read / DS-8 empty) — OPTIONAL enrichment via gh, never
# the acquisition path for the cycle window (AC9/AC10). Only the six
# structured fields number,title,mergedAt,author,url,headRefName are ever
# requested — never body.
# ---------------------------------------------------------------------------
probe_pr_metadata() {
  local limit="${LAST_N:-20}"
  if ! command -v gh >/dev/null 2>&1; then
    note pr-metadata "gh CLI not found (optional enrichment only)"
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    # DS-7's blocked precondition: gh is present but not authenticated, so
    # "successfully listed" is unreachable — unavailable stands.
    note pr-metadata "gh is not authenticated (optional enrichment only)"
    return 0
  fi
  local pr_out=""
  if ! pr_out="$(gh pr list --state merged --limit "$limit" \
                  --json number,title,mergedAt,author,url,headRefName \
                  --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"' 2>/dev/null)"; then
    # DS-8's blocked precondition: the list command itself failed, so
    # "confirmed zero" cannot be distinguished from "confirmed N" —
    # unavailable stands, never read as a successful empty result.
    note pr-metadata "gh pr list failed"
    return 0
  fi
  if [ -z "$pr_out" ]; then
    promote_empty pr-metadata "0 merged pull requests returned by gh"
    return 0
  fi
  local n_pr; n_pr="$(printf '%s\n' "$pr_out" | grep -c '.')"
  promote_read pr-metadata "$n_pr merged pull requests via gh (title/headRefName/number/mergedAt/author/url only, no body)"
  PR_MATERIAL="$(printf '%s\n' "$pr_out" | while IFS="$(printf '\t')" read -r num branch title; do
    [ -n "$num" ] && printf '#%s (%s) %s\n' "$num" "$branch" "$title"
  done)"
}
probe_pr_metadata

# Run cycle-window last among the probes so its material (merge commit list)
# is ready for emission; the order these probe calls run in has no effect on
# the ledger's emitted order, which is fixed by IDS alone (AC3 — probing and
# emission are separate passes).
probe_cycle_window "$BASE_REF" "$BASE_GIVEN" "$LAST_N"

# ---------------------------------------------------------------------------
# Emission: the ONE place in this script that formats a ledger line, run
# once, after every probe above has already run (AC3). Sub-bullet material
# (if any) for cycle-window and pr-metadata is interleaved right after their
# own top-level line — indentation keeps it out of the parsed ledger surface.
# ---------------------------------------------------------------------------
emit_material_block() {
  local block="$1" line
  [ -n "$block" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '  - %s\n' "$(sanitize "$line")"
  done <<< "$block"
}

emit_all() {
  local id st_var de_var detail
  echo '## Retro inputs'
  for id in $IDS; do
    st_var="ST_${id//-/_}"
    de_var="DE_${id//-/_}"
    detail="$(sanitize "${!de_var}")"
    [ -n "$detail" ] || detail="(no detail)"
    printf -- '- input: %s — status: %s — detail: %s\n' "$id" "${!st_var}" "$detail"
    case "$id" in
      cycle-window) emit_material_block "$CW_MATERIAL" ;;
      pr-metadata)  emit_material_block "$PR_MATERIAL" ;;
    esac
  done
}

emit_all

exit 0
