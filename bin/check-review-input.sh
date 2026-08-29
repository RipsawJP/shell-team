#!/usr/bin/env bash
# check-review-input.sh — review-input fidelity checker (T-1104, issue #335).
#
# Decision this implements: docs/loop-engineering/record-tamper-resistance.md
# — tamper-arm-rule-v1 sends duties A and B of this task to arm A
# (arm-A-tested-primitive): the verdict gates a close-out (one of the three
# loop transitions that note's own parenthetical names, reached through the
# sibling-checker wiring bin/close-out.sh establishes for every other
# arm-A obligation), and the judgment is a set of anchored line matches, a
# field extraction, a membership test over two closed token sets and a
# charset test — all mechanically executable from committed record bytes.
#
# This is the FIFTH obligation promoted into arm A. Duty A is the
# record-grammar gate this script implements (every field present exactly
# once, each closed-vocabulary value inside its vocabulary, each pass id
# inside its charset). Duty B is the cross-round raw-capture-stem collision
# refusal, satisfied inside this same script rather than a second one — the
# shape that note's own third promotion (T-1099) established. Duties C
# (does the raw file a record names actually exist on disk) and D (did a
# briefing actually reach the executor's context) both fail conjunct 2 of
# the rule and take arm-B-enumerated-instrument instead: this script never
# reads a raw capture file and never judges whether a briefing was carried,
# only whether the record SAYS it was.
#
# What this checker validates — presence and grammar only:
#   - a review record's four-field per-pass grammar: executor-invocation,
#     pass-role, briefing-fidelity, raw-capture, each present exactly once
#     per declared pass id;
#   - each closed-vocabulary field's value inside its vocabulary
#     (pass-role: generation/confirmation; briefing-fidelity: a first token
#     from carried/not-carried/not-applicable followed by a non-empty
#     explanation);
#   - each pass id inside the charset [a-z0-9-]+;
#   - a raw-capture stem prefixed by the record's own task id;
#   - no two passes anywhere in the record naming the same raw-capture stem
#     (the cross-round collision this task exists to close);
#   - every verdict-heading section carrying at least one complete pass
#     block, once the record carries any input-fidelity field at all.
#
# It never judges the content of the verbatim executor-invocation field
# beyond non-emptiness and single-line-ness (DP-6/DP-7; two records
# differing only in that field's free text both pass), it never verifies a
# pass-role label's truthfulness against its own verbatim field, and it
# never echoes that field's bytes — or any field's bytes — in a refusal
# message: only the record path, the pass id and the refusal token are
# named, the same discipline bin/check-commit-identity.sh's header fixes
# for a similarly PII-shaped field (a report that echoed a credential- or
# identity-bearing argv would turn a control into a leak in a public CI
# log). The field's own contract forbids four things: an environment dump
# or any variable's expanded value, a credential, token, key or
# authentication header, an absolute path outside the repository, and any
# operator or account identity. Where the real argv carries an absolute
# path under the invoker's home directory (the --cd argument in
# particular), the sanctioned alternative is to record that path as
# <repo-root>, relative to the repository root, with every flag, every
# other argument and their order kept verbatim — a recording convention
# this script never inspects for: it never judges the field's content
# beyond non-emptiness and single-line-ness, whether written with or
# without the substitution.
#
# A record carrying ZERO input-fidelity fields exits 0 (the requirement is
# forward-only over a corpus of already-committed records — DP-3).
#
# Per-section completeness (DP-4/AC4, v2): a verdict-heading section opts
# in the moment IT carries at least one of the four fields; once opted in
# it must carry at least one complete pass block ALL FOUR of whose field
# lines sit inside that same section — crediting a section from a pass
# id's earliest field line alone is exactly the defect this rewrite
# closes. A section carrying none of the four fields is conformant
# whatever the rest of the record carries (forward-only at section
# granularity, not only at record granularity). The field/vocabulary/
# shape rules run FIRST over the whole record, so `field-missing` and
# `section-incomplete` name disjoint shapes: a pass whose field is
# missing from the record entirely refuses field-missing, never
# section-incomplete.
#
# Usage:
#   check-review-input.sh --record PATH [--task T-NNN]
#   check-review-input.sh --task T-NNN
#
# Task-id precedence (DP-3's round-3 addendum): the --task argument, when
# given, is the SOLE authority; otherwise the record path's own basename
# with `.md` removed is used. A `- Task:` line inside the record is NEVER
# read for this purpose, at any position — a record whose internal
# declaration disagrees with the resolved id is conformant, and the
# disagreement is a reader's finding, never this checker's verdict.
#
# Record resolution when --record is not given: $TEAM_REVIEWS_DIR when
# non-empty, else the sibling team-paths.sh --get reviews (die, no
# guessing fallback), then <reviews>/<task>.md — bin/check-spec-review.sh's
# own shipped shape, copied rather than reinvented. Two deliberate
# leniencies exist ONLY in this --task-only auto-resolution path, and never
# for an explicit --record: a reviews directory that does not exist at all
# (as opposed to one occupied by a non-directory) is read as "no record for
# this task yet" and exits 0, and a per-task record file that does not
# exist at the resolved path is read the same way. Both keep the
# unconditional close-out.sh wiring cheap for every task whose review has
# not yet been instrumented with this grammar (or has no record file at
# all yet), without weakening the fail-closed refusal an explicit --record
# path still gets.
#
# Exit codes: 0 = pass, or a legacy/not-yet-instrumented record; 1 = a
# refusal about the record's content (a named token on stderr); 2 = a
# usage error or an unresolvable environment (bad invocation, an unreadable
# record named explicitly, a reviews directory occupied by a non-directory,
# team-paths.sh unavailable).

set -euo pipefail
export LC_ALL=C

die()  { printf 'check-review-input: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'check-review-input: %s\n' "$1" >&2 || true; exit 1; }

# Resolve this script's own directory (symlink-safe) so the sibling
# team-paths.sh resolves regardless of cwd / how we were invoked — the same
# resolver bin/check-spec-review.sh and bin/close-out.sh already use.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

RECORD="" TASK="" EXPLICIT_RECORD=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --record)
      [ "$#" -ge 2 ] || die "usage: missing value for --record"
      RECORD="$2"; EXPLICIT_RECORD=1; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || die "usage: missing value for --task"
      TASK="$2"; shift 2 ;;
    --help|-h)
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "$script_path"
      exit 0 ;;
    *) die "usage: unknown argument: $1" ;;
  esac
done

if [ -n "$TASK" ]; then
  [[ "$TASK" =~ ^T-[0-9]+$ ]] || die "usage: invalid --task '$TASK' (expected T-<digits>)"
fi

[ -n "$RECORD" ] || [ -n "$TASK" ] || die "usage: --record PATH or --task T-NNN is required"

if [ "$EXPLICIT_RECORD" -eq 0 ]; then
  # --task-only auto-resolution.
  if [ -n "${TEAM_REVIEWS_DIR:-}" ]; then
    REVIEWS_DIR="$TEAM_REVIEWS_DIR"
  else
    REVIEWS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get reviews 2>/dev/null)" \
      || die "cannot resolve the reviews directory (team-paths.sh unavailable) — set \$TEAM_REVIEWS_DIR or fix the install"
  fi
  if [ ! -e "$REVIEWS_DIR" ] && [ ! -L "$REVIEWS_DIR" ]; then
    # No path component exists there AT ALL yet (not even a broken
    # symlink): nothing has ever been recorded for any task under this
    # resolution, so there is no record for THIS task either.
    # Forward-only leniency (see header) — never for --record. A dangling
    # symlink is NOT "does not exist" — it is "exists and is broken" —
    # and falls through to the -d test below, which fails closed on it.
    exit 0
  fi
  [ -d "$REVIEWS_DIR" ] || die "reviews-dir-unresolvable: reviews directory is not a directory: $REVIEWS_DIR"
  RECORD="$REVIEWS_DIR/$TASK.md"
  if [ ! -e "$RECORD" ] && [ ! -L "$RECORD" ]; then
    # No record file at all yet for this task (not even a broken symlink):
    # same forward-only leniency. A dangling symlink falls through to the
    # readability screen below, which fails closed on it.
    exit 0
  fi
fi

if [ ! -f "$RECORD" ] || [ ! -r "$RECORD" ]; then
  die "record-unreadable: cannot read record: $RECORD"
fi

# --- task-id precedence (DP-3's round-3 addendum): --task argument is the
# sole authority when given; otherwise the record path's own basename with
# .md removed. A `- Task:` line inside the record is NEVER read. ----------
if [ -n "$TASK" ]; then
  TASK_ID="$TASK"
else
  TASK_ID="$(basename "$RECORD")"
  TASK_ID="${TASK_ID%.md}"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-review-input.XXXXXX")" || die "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# --- verdict-heading line numbers FIRST, so field extraction below can
# stamp each field line with its owning section as it goes. The section
# anchor is the fixed literal stem, never the free-form `## ` heading text
# above it (the Gotcha this task's Notes for engineer records — `## `
# headings vary across the corpus; `### Codex Review verdict:` and
# `### Codex Spec-Review verdict:` are the two fixed stems
# agents/codex-reviewer.md pins). A real scan failure (grep exit > 1 —
# e.g. a read error mid-file) is distinguished from a clean "no heading
# found" (exit 1) rather than masked by a blanket `|| true`: an input
# this checker cannot actually evaluate must never read as a silent,
# heading-less pass. --------------------------------------------------
HEADING_RE='^### Codex (Review|Spec-Review) verdict:'
grep -nE -- "$HEADING_RE" "$RECORD" > "$WORK/headings" 2>"$WORK/headings.err" && hgx=0 || hgx=$?
[ "$hgx" -le 1 ] || die "record-unreadable: scanning $RECORD for verdict headings failed"
cut -d: -f1 "$WORK/headings" > "$WORK/heading_lines" 2>/dev/null || true

# section_of LINE_NO — prints the heading line number that owns LINE_NO
# (the greatest heading line <= LINE_NO), or 0 if none / no headings at
# all / the line precedes every heading.
section_of() {
  local ln="$1" best=0 h
  if [ -s "$WORK/heading_lines" ]; then
    while IFS= read -r h; do
      if [ "$h" -le "$ln" ] && [ "$h" -gt "$best" ]; then
        best="$h"
      fi
    done < "$WORK/heading_lines"
  fi
  printf '%s\n' "$best"
}

# --- extract every field line record-wide, with its line number. grep
# reads the whole file (EOF-safe for a final line with no trailing
# newline — never a `while read` loop directly over the record itself,
# the discipline bin/check-spec-review.sh's own header fixes); its own
# output always ends in a newline, so looping over IT is safe. A
# continuation line that carries no field anchor of its own (an indented
# line under a field, with no `- <name> (<id>): ` prefix) matches nothing
# here and is silently skipped — never glued onto the previous value
# (AC8's continuation-line case). A real scan failure is distinguished
# from a clean "no fields found" the same way the heading scan above
# is. ------------------------------------------------------------------
FIELD_RE='^[[:space:]]*-[[:space:]](executor-invocation|pass-role|briefing-fidelity|raw-capture)[[:space:]]\(([^)]*)\):[[:space:]]?(.*)$'
grep -nE -- "$FIELD_RE" "$RECORD" > "$WORK/matches" 2>"$WORK/matches.err" && fgx=0 || fgx=$?
[ "$fgx" -le 1 ] || die "record-unreadable: scanning $RECORD for input-fidelity fields failed"

if [ ! -s "$WORK/matches" ]; then
  # Zero input-fidelity fields anywhere: forward-only pass (DP-3). Every
  # already-committed record in this or any adopter repository is in this
  # class at upgrade time.
  exit 0
fi

# The internal transport is TAB-delimited, so a captured id or value that
# itself contains a literal TAB byte is rejected outright here, before it
# is ever written to the work file — closing the class of defect where an
# embedded TAB forges a column boundary and truncates a value the
# vocabulary/charset checks below then see only a prefix of (e.g. a
# pass-role value of "generation<TAB>garbage" reading as bare
# "generation"). This is a shape rule, not a content judgment (AC8): the
# field contract already forbids control-character content in spirit, and
# neither an id nor a value may legitimately need a TAB byte.
: > "$WORK/fields"
while IFS= read -r rec; do
  n="${rec%%:*}"
  content="${rec#*:}"
  if [[ "$content" =~ $FIELD_RE ]]; then
    fid="${BASH_REMATCH[2]}"
    fval="${BASH_REMATCH[3]}"
    case "$fid" in
      *$'\t'*) fail "field-grammar: a pass id at line $n contains an embedded tab, which is not representable" ;;
    esac
    case "$fval" in
      *$'\t'*) fail "field-grammar: a field value at line $n contains an embedded tab, which is not representable" ;;
    esac
    owner_ln="$(section_of "$n")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$n" "${BASH_REMATCH[1]}" "$fid" "$fval" "$owner_ln" >> "$WORK/fields"
  fi
done < "$WORK/matches"

# --- distinct pass ids, in order of first appearance -----------------------
cut -f3 "$WORK/fields" | awk '!seen[$0]++' > "$WORK/ids"

: > "$WORK/complete_ids"
: > "$WORK/rawcap"
: > "$WORK/section_owner"

while IFS= read -r id; do
  ei_n=$(awk -F'\t' -v id="$id" '$2=="executor-invocation" && $3==id' "$WORK/fields" | grep -c . || true)
  pr_n=$(awk -F'\t' -v id="$id" '$2=="pass-role" && $3==id' "$WORK/fields" | grep -c . || true)
  bf_n=$(awk -F'\t' -v id="$id" '$2=="briefing-fidelity" && $3==id' "$WORK/fields" | grep -c . || true)
  rc_n=$(awk -F'\t' -v id="$id" '$2=="raw-capture" && $3==id' "$WORK/fields" | grep -c . || true)

  if [ "$ei_n" -eq 0 ] || [ "$pr_n" -eq 0 ] || [ "$bf_n" -eq 0 ] || [ "$rc_n" -eq 0 ]; then
    fail "field-missing: pass id '$id' is missing at least one of the four required fields (executor-invocation/pass-role/briefing-fidelity/raw-capture)"
  fi
  if [ "$ei_n" -gt 1 ] || [ "$pr_n" -gt 1 ] || [ "$bf_n" -gt 1 ] || [ "$rc_n" -gt 1 ]; then
    fail "field-duplicate: pass id '$id' carries at least one of the four fields more than once"
  fi

  if [[ ! "$id" =~ ^[a-z0-9-]+$ ]]; then
    fail "pass-id-charset: pass id '$id' is outside the closed charset [a-z0-9-]+"
  fi

  ei_val=$(awk -F'\t' -v id="$id" '$2=="executor-invocation" && $3==id {print $4; exit}' "$WORK/fields")
  pr_val=$(awk -F'\t' -v id="$id" '$2=="pass-role" && $3==id {print $4; exit}' "$WORK/fields")
  bf_val=$(awk -F'\t' -v id="$id" '$2=="briefing-fidelity" && $3==id {print $4; exit}' "$WORK/fields")
  rc_val=$(awk -F'\t' -v id="$id" '$2=="raw-capture" && $3==id {print $4; exit}' "$WORK/fields")

  if [ -z "$ei_val" ]; then
    fail "field-grammar: pass id '$id' has an empty executor-invocation value"
  fi

  case "$pr_val" in
    generation|confirmation) : ;;
    *) fail "pass-role-vocabulary: pass id '$id' has a pass-role value outside the closed set generation/confirmation" ;;
  esac

  bf_first="${bf_val%% *}"
  bf_rest="${bf_val#"$bf_first"}"
  bf_rest="${bf_rest# }"
  case "$bf_first" in
    carried|not-carried|not-applicable)
      [ -n "$bf_rest" ] || fail "briefing-fidelity-vocabulary: pass id '$id' has no explanation after its briefing-fidelity token"
      ;;
    *) fail "briefing-fidelity-vocabulary: pass id '$id' has a briefing-fidelity first token outside the closed set carried/not-carried/not-applicable" ;;
  esac

  case "$rc_val" in
    "$TASK_ID"-*) : ;;
    *) fail "raw-capture-stem-mismatch: pass id '$id' has a raw-capture stem not prefixed by the record's own task id '$TASK_ID'" ;;
  esac

  printf '%s\n' "$id" >> "$WORK/complete_ids"
  printf '%s\t%s\n' "$id" "$rc_val" >> "$WORK/rawcap"

  # Section ownership (DP-4/AC4, the section-scoped-ownership fix): this
  # id's block is credited to a section ONLY when all four of its field
  # lines resolve to the SAME owning section. A pass split across two
  # sections (one field here, three elsewhere) is credited to no section
  # at all, which is exactly what makes the section it is split across
  # refuse rather than being satisfied from the pass's earliest field line
  # alone (the review's Major 4 reproduction).
  owners="$(awk -F'\t' -v id="$id" '$3==id{print $5}' "$WORK/fields" | sort -u)"
  n_owners="$(printf '%s\n' "$owners" | grep -c . || true)"
  if [ "$n_owners" -eq 1 ]; then
    printf '%s\t%s\n' "$id" "$owners" >> "$WORK/section_owner"
  fi
done < "$WORK/ids"

# --- cross-round / cross-section raw-capture collision: the whole record,
# never scoped to one section (AC7's second case). No echo of the
# colliding stem's own bytes — only the refusal token and the two
# colliding pass ids are named, the no-echo discipline
# bin/check-commit-identity.sh's header fixes, applied here because a
# stem can carry a marker or fragment worth not re-publishing. --------------
cut -f2 "$WORK/rawcap" > "$WORK/stems" || die "record-unreadable: extracting raw-capture stems failed"
sort "$WORK/stems" > "$WORK/stems.sorted" || die "record-unreadable: sorting raw-capture stems failed"
uniq -d "$WORK/stems.sorted" > "$WORK/dupstems" || die "record-unreadable: detecting raw-capture stem duplicates failed"
DUP_STEM="$(head -1 "$WORK/dupstems")"
if [ -n "$DUP_STEM" ]; then
  DUP_ID1="$(awk -F'\t' -v s="$DUP_STEM" '$2==s {print $1; exit}' "$WORK/rawcap")"
  DUP_ID2="$(awk -F'\t' -v s="$DUP_STEM" -v skip="$DUP_ID1" '$2==s && $1!=skip {print $1; exit}' "$WORK/rawcap")"
  fail "raw-capture-collision: two pass ids name the same raw-capture stem (first: '$DUP_ID1', second: '$DUP_ID2')"
fi

# --- per-section completeness (DP-4/AC4, v2): once a verdict-heading
# section opts in — carries at least one of the four fields, from any
# pass id, complete or not — it must carry at least one pass id whose
# section-owner (computed above) is that SAME heading line. A section
# carrying none of the four fields is conformant whatever the rest of the
# record carries. --------------------------------------------------------
if [ -s "$WORK/heading_lines" ]; then
  cut -f5 "$WORK/fields" | sort -u > "$WORK/armed_sections"
  cut -f2 "$WORK/section_owner" | sort -u > "$WORK/owned_sections"
  while IFS= read -r h; do
    if grep -Fqx -- "$h" "$WORK/armed_sections" 2>/dev/null; then
      if ! grep -Fqx -- "$h" "$WORK/owned_sections" 2>/dev/null; then
        fail "section-incomplete: the verdict-heading section at line $h carries no complete pass block"
      fi
    fi
  done < "$WORK/heading_lines"
fi

exit 0
