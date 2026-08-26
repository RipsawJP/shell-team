#!/usr/bin/env bash
# check-board-headings.sh — machine-verify board heading identity (T-079).
#
# Guards against the two real incidents where an Edit that inserted/appended
# a new board entry silently clobbered an EXISTING task's top-level heading
# line (T-054/PR #143 round1 replaced T-053's heading; the 2026-07-19
# v0.2.15 release insertion replaced/deleted T-073's heading — commit
# 0a3caa0, recovered in 059996f). `bin/check-handoff.sh` checks the SHAPE of
# each Active line but never compares against a base ref, so a wholesale
# heading replacement/deletion still lints clean. This script closes that
# gap: it diffs the whole-board (Active + Done) set of `T-NNN` heading ids
# between a base ref/file and the current board and fails on deletion,
# replacement (id-level: same as deletion), or duplication.
#
# Deliberately kept SEPARATE from check-handoff.sh / close-out.sh (DP-A):
# close-out.sh:229 gates its git-untracked temp board ($TMP_BOARD, no base
# ref exists for it) through check-handoff.sh as a fail-closed step. Adding
# base-ref comparison to check-handoff.sh would break that gate. Both files
# stay byte-unchanged (see docs/specs/T-079-board-heading-integrity.md).
#
# T-095 (issue #300): this script's section-boundary parser was hardened
# against fence re-activation (item1) and ATX-closing-notation silent-pass
# (item2). This is an INTENTIONAL ASYMMETRY, not an oversight: the same-shaped
# weakness is deliberately left in place at check-handoff.sh (its own
# `/^## Active[[:space:]]*$/ && !seen` section-boundary check, :48) and
# close-out.sh, both of which stay byte-unchanged (DP-A, above) — see
# docs/specs/T-095-board-headings-parser-hardening.md DECISION 2 for the
# multi-layer-defense rationale (check-handoff.sh's `&& !seen` single-entry
# guard is already structurally resistant to the fence class, and its ATX
# exposure requires rewriting the canonical static template heading itself).
#
# Usage:
#   check-board-headings.sh <board-file> [--base <ref> | --base-file <path>]
#
#   <board-file>     the board to check (current state — working tree file,
#                     or a temp copy; NOT necessarily tasks/todo.md).
#   --base <ref>      a git ref (production path). The comparison point is
#                     `git merge-base <ref> HEAD` when resolvable, else
#                     <ref> itself — stable across squash/rebase/multi-commit
#                     PRs. Requires <board-file> to live inside a git repo.
#   --base-file <path> a plain file holding the base board content (test
#                     path — no git required). Mutually exclusive with
#                     --base.
#
#   When BOTH are omitted, the default resolution order (DP-B) is:
#     (1) $CHECK_BOARD_HEADINGS_BASE (a ref)
#     (2) origin/$GITHUB_BASE_REF     (when $GITHUB_BASE_REF is set — CI PR context)
#     (3) HEAD~1                      (when it exists)
#     (4) none of the above resolves  => the structural (deletion/replacement)
#         check is SKIPPED with a note; the duplicate check still runs
#         (it is base-independent). Exit 0 unless duplicates are found.
#   Candidates (1)-(3) are tried in order and silently fall through to the
#   next one when unresolvable — none of them is a direct user request, so
#   this default chain is lenient by design. An EXPLICIT --base/--base-file
#   that fails to resolve is different: the user asked for a specific
#   comparison and it could not be honored, so that is fail-closed (exit 2).
#
# Heading extraction mirrors the existing, already-relied-upon parsing
# conventions (no new mini-parser — 2026-07-12 lesson on parser/consumer
# drift): the top-level line shape close-out.sh's pass-1 awk uses
# (`^- \[[x ]\] (\*\*)?T-NNN(\*\*)? `, bold optional, [ ]/[x] both allowed)
# and the canonical entry-continuation predicate (T-1016) check-handoff.sh's
# own strand check now enforces: a boundary is any non-indented non-blank
# line or EOF, a blank line is neutral, and every indented non-blank line
# (`-`, `|`, a tab, a digit, prose — any first character) continues an entry.
# Indented lines (sub-bullets and table rows alike, including ones that
# merely QUOTE a heading-shaped string — the self-referential-prose fixture,
# 2026-07-17 lesson) are never treated as headings — this alignment is
# purely a predicate-widening: the heading match below already requires a
# non-indented `- [ ]`/`- [x]` prefix, so an indented line was never a
# heading candidate under either predicate (behavior-preserving, T-1016 D5).
# Order of headings is never gated (close-out moves entries to the TOP of
# ## Done, which legitimately reorders Done — DP-C).
#
# T-1099 (issue #301): a second, structural assertion beside the id-level
# duplicate check above — base-independent, requiring no --base/--base-file
# at all, and always run (even when the id-diff structural check above is
# skipped per (4)). `## Active` and `## Done` must each occur exactly once,
# counted by the SAME section-opening predicate this script's extraction
# already relies on, never a looser normalization — a heading check-
# handoff.sh/close-out.sh cannot see must never satisfy this half. Every
# OTHER top-level (`##`) heading may occur at most once, with NO presence
# requirement, so an adopter's own sections (`## Reserved`, `## Planned`,
# anything) are never coerced. Identity for these "other" headings is the
# heading text with the leading `##` removed, an optional ATX-closing hash
# run PRECEDED BY AT LEAST ONE SPACE removed, and the remainder's
# surrounding whitespace trimmed (internal whitespace preserved literally)
# — so `## Format ##` collides with `## Format`, while `## Active Backlog`
# and `## Active###` (no space before the closing run) stay DISTINCT
# headings from `Active`. Level 1 (`#`) and level 3 (`###`) headings are out
# of scope: no consumer keys on either, and this repository's own board
# legitimately carries dozens of identical level-3 `### Local test result`
# headings inside entries, which would make an at-most-once rule (every
# other structural heading occurs at most once) false on the very board
# this script guards. Fenced and indented heading-shaped lines are never
# headings here either, per the same fence/ATX state machine
# `extract_ids_to_file` already runs (no second parser — this reuses that
# one pass rather than forking it).
#
# Exit: 0 = no violations (or the id-level structural check skipped for
#           lack of a base, per (4) above, and no duplicates — id-level or
#           structural-heading — found).
#       1 = deletion / replacement / duplicate found, OR a structural
#           heading (`## Active`/`## Done`) is missing/duplicated, OR any
#           other top-level heading occurs more than once.
#       2 = usage error, unreadable board/base-file, or an EXPLICITLY
#           requested --base/--base-file could not be resolved.
#
# Read-only. Prints `<board>: <reason>: <ids...>` to stderr per violation.

set -euo pipefail

die() { printf '%s: %s\n' "${0##*/}" "$1" >&2 || true; exit 2; }

# All temp files live inside a single tracked WORKDIR, created directly in
# THIS shell (not inside a function invoked via command substitution — a
# `t="$(new_tmp)"` call runs the entire function body in a subshell, so any
# `TMP_FILES+=(...)` done there is invisible to the parent's array; that
# earlier design left the EXIT trap always walking an empty array and never
# deleting anything, round-1 Minor finding). A single `rm -rf "$WORKDIR"`
# needs no cross-subshell bookkeeping at all.
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/check-board-headings.XXXXXX")"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() {
  # `if` form (not `rm ... && ...` / bare `rm`) so a cleanup failure can never
  # flip the script's real exit status under `set -e` — the earlier EXIT-trap
  # bug this task fixed (`[ -n "$f" ] && rm -f "$f"` clobbering exit 0 into
  # exit 1 when $f was empty). Do not regress that fix.
  if [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

new_tmp() {
  mktemp "$WORKDIR/tmp.XXXXXX"
}

usage() {
  # Dynamic header-range derivation (T-101): skip L1 (shebang, also `#`-led)
  # and print every subsequent `#`-prefixed line with its `# `/`#` prefix
  # stripped, stopping at the first non-`#` line (the header's own end,
  # currently the blank line before `set -euo pipefail`). Replaces the prior
  # fixed `sed -n '2,45p'` range, which silently truncated mid-header (e.g.
  # the Exit-code contract and the trailing `Read-only. Prints ...` line)
  # whenever the header grew past line 45 — see docs/specs/T-101.
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$0"
}

BOARD=""
BASE_REF=""
BASE_FILE=""
HAVE_BASE=0
HAVE_BASE_FILE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      [ "$#" -ge 2 ] || die "missing value for --base"
      BASE_REF="$2"; HAVE_BASE=1; shift 2 ;;
    --base-file)
      [ "$#" -ge 2 ] || die "missing value for --base-file"
      BASE_FILE="$2"; HAVE_BASE_FILE=1; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        if [ -z "$BOARD" ]; then BOARD="$1"; else die "unexpected extra argument: $1"; fi
        shift
      done
      ;;
    -*)
      die "unknown argument: $1" ;;
    *)
      if [ -z "$BOARD" ]; then BOARD="$1"; else die "unexpected extra argument: $1"; fi
      shift ;;
  esac
done

[ -n "$BOARD" ] || die "missing required <board-file> argument"
[ -r "$BOARD" ] || die "cannot read board file: $BOARD"
if [ "$HAVE_BASE" -eq 1 ] && [ "$HAVE_BASE_FILE" -eq 1 ]; then
  die "--base and --base-file are mutually exclusive"
fi

# --- heading extraction (shared, existing-convention parser) -----------------
# Writes one `T-NNN` id per top-level heading line found in $1 to $2, in
# encounter order, WITH duplicates preserved (duplicate detection needs the
# raw multiplicity; the base/head set diff dedupes separately).
#
# whole-board scope (spec terminology table): the `## Active` and `## Done`
# sections ONLY. This mirrors check-handoff.sh's `in_active`-flag section
# tracking (bin/check-handoff.sh:65-69) rather than scanning the whole file:
# without it, a checkbox-shaped `T-NNN` line that lands in ANY other `## `
# section (Reserved / Planned / Format, or a future section) would be picked
# up too. Today's tasks/todo.md happens not to trigger this (Reserved/Planned
# are plain bullets, Format is a `T-XXX` placeholder) but that is incidental,
# not structural — round-1 Major finding. Entering a NEW `## ` heading always
# turns extraction off again, so only lines strictly inside an Active or Done
# block are ever considered.
extract_ids_to_file() {
  # $1 = input file, $2 = ids output file (as always), $3 = OPTIONAL
  # heading-occurrences log (T-1099). When $3 is non-empty, this SAME awk
  # pass (one fence/ATX implementation, never a second one — Notes for
  # engineer) additionally writes one line per top-level (`##`) heading
  # line it sees, in encounter order: `ACTIVE` / `DONE` for a line matching
  # the exact section-opening predicate already used for id extraction
  # below, or `OTHER<TAB><normalized-identity>` for every other `##`
  # heading line. Fenced and indented heading-shaped lines never reach this
  # log either, since the fence/indent suppression above already applies
  # before any heading pattern is tested. Left empty ("") on the BASE-side
  # call (line ~371), since the T-1099 structural-heading assertion is
  # base-independent and reads only the board under check.
  local headfile="${3:-}"
  # T-095 (item1/item2 — issue #300, board-headings-parser-hardening) +
  # round1 Codex hardening (same-class-2: 2 fence-toggle Majors + 1 ATX
  # Blocker on the FIRST T-095 cut, fixed by moving fence tracking to a
  # small CommonMark-aligned state machine rather than another point-fix) +
  # round2 Codex fix (a single Major: the indent bound counted CHARACTERS,
  # not CommonMark COLUMNS — a single leading tab is column 4 in CommonMark,
  # so it must NOT qualify as fence-openable indentation, but a naive
  # char-count `<=3` wrongly let a 1-character tab through):
  #
  #  - fence state machine: a fence OPENER is a line whose leading
  #    indentation is 0-3 LITERAL SPACE characters (`[ ]{0,3}` — tabs are
  #    deliberately EXCLUDED from the indent-count regex, not merely
  #    tab-expanded, since CommonMark counts a leading tab as column 4 and
  #    a space-only regex is the simplest construction that can never
  #    under-count a tab as "<=3"; round2 fix) followed by a run of >=3
  #    backtick characters; its info string, if any, is not validated.
  #    Once opened, the RUN LENGTH of that opener is recorded (fence_len)
  #    and in_fence is set. While in_fence, EVERY line is suppressed from
  #    section-boundary switching and id extraction — a line only closes
  #    the fence if it is likewise 0-3-space-indented, backtick run length
  #    >= fence_len, and has NOTHING but trailing whitespace after the run
  #    (CommonMark: trailing content on a closer line does NOT close a
  #    fence, round1 Major(a); and a shorter/different-length run does NOT
  #    close a longer opener, round1 Major(b) — 4-backtick-outer /
  #    3-backtick-inner no longer mis-closes). Tilde (~~~) fences are
  #    intentionally NOT tracked (DECISION 3, out of scope — this checker
  #    is an honest-error tool, not an adversarial-input parser).
  #  - ATX-closing tolerance: the section-heading match accepts
  #    CommonMark's trailing-hash closing form (`## Active ##`) but
  #    requires AT LEAST ONE SPACE between the heading text and the
  #    closing hash run (CommonMark: `## Active###`, no space, is a
  #    heading literally titled "Active###", NOT a closed "Active"
  #    heading — round1 Blocker: zero-whitespace ATX-closing silently
  #    failed to enable in_section and masked a real deletion). A
  #    different heading that merely STARTS WITH "## Active" (e.g.
  #    `## Active Backlog`) still falls through to the general `/^##([[:space:]]|$)/`
  #    rule and does NOT enable in_section (over-match guard preserved).
  awk -v headfile="$headfile" '
    # T-1099 review round 1 (Blocker + Major): an OTHER record is
    # length-prefixed — `OTHER<TAB><byte-length-of-ident><TAB><ident>` —
    # rather than a bare `OTHER` (empty ident) or a single `OTHER<TAB>ident`
    # (ident may itself contain a tab). The length field, computed here at
    # write time, makes an empty identity a real, non-blank, countable
    # token (the record is never just whitespace), and every consumer
    # locates the identity by BYTE OFFSET past the tag+length fields
    # (never by re-splitting the record on tab), so an internal tab inside
    # the identity itself can never be mistaken for a field boundary.
    function log_heading(tag, ident) {
      if (headfile == "") return
      if (tag == "OTHER") { print tag "\t" length(ident) "\t" ident >> headfile }
      else { print tag >> headfile }
    }
    !in_fence {
      if (match($0, /^[ ]{0,3}`{3,}/)) {
        fence_run = substr($0, RSTART, RLENGTH)
        gsub(/^[ ]+/, "", fence_run)
        fence_len = length(fence_run)
        in_fence = 1
        next
      }
    }
    in_fence {
      close_pat = "^[ ]{0,3}`{" fence_len ",}[[:space:]]*$"
      if ($0 ~ close_pat) { in_fence = 0 }
      next
    }
    /^## Active([[:space:]]+#+)?[[:space:]]*$/ { in_section=1; log_heading("ACTIVE", ""); next }
    /^## Done([[:space:]]+#+)?[[:space:]]*$/   { in_section=1; log_heading("DONE", ""); next }
    /^##([[:space:]]|$)/ {
      # T-1099: every OTHER top-level heading (decision (b)) — identity is
      # the text with the leading "##" removed, an optional ATX-closing
      # hash run PRECEDED BY AT LEAST ONE SPACE removed, and the remainder
      # trimmed of surrounding whitespace only (internal whitespace
      # preserved literally), so "## Format ##" collides with "## Format"
      # while "## Active Backlog" / "## Active###" stay distinct from
      # "Active".
      ident = $0
      sub(/^##/, "", ident)
      sub(/[[:space:]]+#+[[:space:]]*$/, "", ident)
      gsub(/^[[:space:]]+/, "", ident)
      gsub(/[[:space:]]+$/, "", ident)
      log_heading("OTHER", ident)
      in_section=0
      next
    }
    !in_section { next }
    # board-entry continuation canon (T-1016): skip every indented,
    # non-blank line (the canonical continuation predicate), not merely a
    # dash-led one — behavior-preserving here, since the heading match below
    # already requires a non-indented `- [ ]`/`- [x]` prefix (T-1016 D5).
    /^[[:space:]]+[^[:space:]]/ { next }
    /^- \[[x ]\] (\*\*)?T-[0-9]+(\*\*)? / {
      if (match($0, /T-[0-9]+/)) print substr($0, RSTART, RLENGTH)
    }
  ' "$1" > "$2"
}

# --- base materialization ------------------------------------------------------
# On success sets the global BASE_BOARD_FILE to a file holding the base
# board's markdown content ("" content is valid — it means the board file
# did not exist yet at that point, i.e. it was added since). On failure for
# an EXPLICITLY requested ref, dies with exit 2 (fail-closed, DP-B).
BASE_BOARD_FILE=""

materialize_base_from_ref() {
  local ref="$1"
  # Every repo-context invocation below is scoped via `-C "$repo_dir"` to the
  # BOARD FILE'S OWN repository, never the caller's cwd (#247 item 3 /
  # DECISION 4). T-079 confirmed the pre-fix cwd-resolving form already
  # fails closed (exit 2) when cwd is a different repo, but with a WRONG
  # error message ("outside the repository tracked by git") — this is an
  # error-message-correctness fix, not a behavior/judgment change; the
  # extraction/duplicate/set-diff judgment core below the
  # `# --- extraction ---` marker is untouched (byte-locked, AC3).
  local repo_dir
  repo_dir="$(dirname "$BOARD")"
  if ! git -C "$repo_dir" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1; then
    die "cannot resolve --base ref: $ref"
  fi
  local point
  point="$(git -C "$repo_dir" merge-base "$ref" HEAD 2>/dev/null || true)"
  [ -n "$point" ] || point="$ref"
  local repo_root abs_board rel_path
  repo_root="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a repository tracked by git (required for --base)"
  # `pwd -P` (physical, symlinks resolved) — NOT the default logical `pwd` —
  # so this matches the `-C`-scoped rev-parse --show-toplevel call's
  # physical path on hosts where a tmp root is itself a symlink (e.g. macOS
  # /tmp -> /private/tmp); otherwise a same-repo board path is wrongly
  # reported as outside the repo.
  abs_board="$(cd "$repo_dir" && pwd -P)/$(basename "$BOARD")"
  case "$abs_board" in
    "$repo_root"/*) rel_path="${abs_board#"$repo_root"/}" ;;
    *) die "board file is outside the repository tracked by git: $BOARD" ;;
  esac
  local tmp
  tmp="$(new_tmp)"
  if ! git -C "$repo_dir" show "${point}:${rel_path}" > "$tmp" 2>/dev/null; then
    # The board did not exist at the comparison point (e.g. added since) —
    # treat as an empty base rather than a usage error.
    : > "$tmp"
  fi
  BASE_BOARD_FILE="$tmp"
}

SKIP_STRUCTURAL=0

if [ "$HAVE_BASE_FILE" -eq 1 ]; then
  [ -r "$BASE_FILE" ] || die "cannot read --base-file: $BASE_FILE"
  BASE_BOARD_FILE="$BASE_FILE"
elif [ "$HAVE_BASE" -eq 1 ]; then
  materialize_base_from_ref "$BASE_REF"
else
  candidate=""
  # Same cwd-independence requirement as materialize_base_from_ref (#247 item
  # 3 / DECISION 4, extended per Codex round1 Major finding): every candidate
  # resolution check here is ALSO scoped via `-C "$base_repo_dir"` to the
  # BOARD FILE'S OWN repository, never the caller's cwd — the sibling
  # default-base candidate-selection preamble is the same cwd-dependence
  # class as materialize_base_from_ref, just one level up the call chain.
  base_repo_dir="$(dirname "$BOARD")"
  if [ -n "${CHECK_BOARD_HEADINGS_BASE:-}" ] \
     && git -C "$base_repo_dir" rev-parse --verify --quiet "${CHECK_BOARD_HEADINGS_BASE}^{commit}" >/dev/null 2>&1; then
    candidate="$CHECK_BOARD_HEADINGS_BASE"
  elif [ -n "${GITHUB_BASE_REF:-}" ] \
     && git -C "$base_repo_dir" rev-parse --verify --quiet "origin/${GITHUB_BASE_REF}^{commit}" >/dev/null 2>&1; then
    candidate="origin/${GITHUB_BASE_REF}"
  elif git -C "$base_repo_dir" rev-parse --verify --quiet 'HEAD~1^{commit}' >/dev/null 2>&1; then
    candidate="HEAD~1"
  fi
  if [ -n "$candidate" ]; then
    materialize_base_from_ref "$candidate"
  else
    SKIP_STRUCTURAL=1
    printf '%s: note: no resolvable base (first commit and no --base/--base-file/env default) — skipping the deletion/replacement (structural) check; the duplicate check still runs\n' "$BOARD" >&2
  fi
fi

# --- extraction ---------------------------------------------------------------
HEAD_RAW="$(new_tmp)"
HEADINGS_LOG="$(new_tmp)"
extract_ids_to_file "$BOARD" "$HEAD_RAW" "$HEADINGS_LOG"

violations=0
emit() {
  printf '%s: %s: %s\n' "$BOARD" "$1" "$2" >&2
  violations=$((violations + 1))
}

# Duplicate check is base-independent (intra-file) — it always runs, even
# when the structural (base-diff) check above was skipped for lack of a
# resolvable base.
dupes="$(sort "$HEAD_RAW" | uniq -d)"
if [ -n "$dupes" ]; then
  emit "duplicate heading(s)" "$(printf '%s' "$dupes" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
fi

# --- structural top-level heading check (T-1099, issue #301) ------------------
# Base-independent (reads only $HEADINGS_LOG, which was built from $BOARD
# alone) — always runs, even when the id-diff structural check below is
# skipped for lack of a resolvable base, exactly like the duplicate check
# above. `## Active` and `## Done` must occur exactly once each (decision
# (b)); every other top-level heading at most once, by its normalized
# identity, with no presence requirement.
active_n="$(grep -c '^ACTIVE$' "$HEADINGS_LOG" || true)"
done_n="$(grep -c '^DONE$' "$HEADINGS_LOG" || true)"

if [ "$active_n" -eq 0 ]; then
  emit "missing structural heading" "Active"
elif [ "$active_n" -gt 1 ]; then
  emit "duplicate structural heading" "Active"
fi

if [ "$done_n" -eq 0 ]; then
  emit "missing structural heading" "Done"
elif [ "$done_n" -gt 1 ]; then
  emit "duplicate structural heading" "Done"
fi

# T-1099 review round 1 fix (Blocker + Major, same root cause: an unsafe
# read-side extraction of the OTHER identity). This ONE awk pass does the
# entire duplicate JUDGMENT internally, over an in-awk associative array —
# never returning a bare, possibly-empty identity string to bash for a
# `[ -n ... ]` truthiness test (that is exactly how the Blocker's empty-
# identity case was silently swallowed: a lone blank line surviving
# `uniq -d` is stripped to nothing by command substitution's trailing-
# newline trimming). The identity is located by BYTE OFFSET past the
# `OTHER<TAB><len><TAB>` prefix — via `length($1)`/`length($2)`, both
# guaranteed tab-free by construction (the tag is a literal, the length is
# decimal digits) — and reconstructed with `substr($0, ...)` on the RAW
# line, never by re-splitting the record on tab, so an identity carrying
# its own internal tab byte is read back whole (the Major's root cause).
# Only a guaranteed-non-blank report line (`DUP<TAB><display>`, with an
# explicit placeholder for a duplicated empty identity) crosses back into
# bash, and presence is decided by a LINE COUNT (`grep -c`), never by
# testing a substituted string's own emptiness.
other_report="$(awk -F'\t' '
  $1 == "OTHER" {
    prefix_len = length($1) + 1 + length($2) + 1
    ident = substr($0, prefix_len + 1)
    cnt[ident]++
  }
  END {
    for (id in cnt) {
      if (cnt[id] > 1) {
        display = (id == "" ? "(blank heading)" : id)
        print "DUP\t" display
      }
    }
  }
' "$HEADINGS_LOG")"
other_dup_n="$(printf '%s\n' "$other_report" | grep -c '^DUP' || true)"
if [ "$other_dup_n" -gt 0 ]; then
  other_names="$(printf '%s\n' "$other_report" | sed 's/^DUP\t//' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  emit "duplicate structural heading" "$other_names"
fi

if [ "$SKIP_STRUCTURAL" -eq 0 ]; then
  BASE_RAW="$(new_tmp)"
  extract_ids_to_file "$BASE_BOARD_FILE" "$BASE_RAW"
  BASE_UNIQ="$(new_tmp)"
  HEAD_UNIQ="$(new_tmp)"
  sort -u "$BASE_RAW" > "$BASE_UNIQ"
  sort -u "$HEAD_RAW" > "$HEAD_UNIQ"
  # Lines of BASE_UNIQ that do NOT exactly match any line of HEAD_UNIQ =
  # base ids no longer present in head = deleted/replaced (id-level: a
  # replacement is indistinguishable from a deletion at the id-set level —
  # DP-C).
  missing="$(grep -Fxvf "$HEAD_UNIQ" "$BASE_UNIQ" || true)"
  if [ -n "$missing" ]; then
    emit "deleted/replaced heading(s)" "$(printf '%s' "$missing" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  fi
fi

[ "$violations" -eq 0 ] || exit 1
exit 0
