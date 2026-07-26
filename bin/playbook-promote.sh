#!/usr/bin/env bash
# playbook-promote.sh — append ONE human-approved lesson candidate to
# tasks/lessons.md as a schema-valid structured entry (T-045, issue #116).
#
# This is step 3 of the playbook update path (see
# docs/loop-engineering/playbook-update-path.md):
#
#   1. scrum-master retro proposes candidates (existing, unchanged)
#   2. a HUMAN reads the retro and picks which candidate(s) to adopt
#   3. THIS SCRIPT, run by the human, appends the approved candidate    <- here
#   4. bin/gen-playbook-blocks.sh (run by the human) regenerates the
#      per-role digest blocks from the updated lessons file
#   5. the resulting diff (lessons.md + regenerated blocks + consumer
#      marker regions) goes through the normal PR flow
#
# This script is never invoked automatically by another script or agent —
# every step of the path above is a separate, explicit human action (D5 in
# docs/specs/T-045-ace-playbook.md). It only ever appends ONE entry per run.
#
# Fail-closed: the candidate is validated BEFORE any write. A temp copy of
# the lessons file with the candidate entry appended is built and checked
# with the sibling bin/check-playbook.sh; only if that temp copy is
# completely schema-valid does the real file get overwritten. On any
# rejection the real lessons file is byte-untouched.
#
# NOTE (safety-net vs. review — see D5 "防衛の主従" in the spec): passing
# this validation is a structural/schema check (single-line values, known
# enums, no marker-collision), not a semantic or security review of the
# candidate's content. The actual defense against a bad candidate is the
# human curating step 2 above and the normal PR review of the resulting
# diff — never treat this script's success as a content safety guarantee.
#
# NOTE (NUL bytes — T-045 round2, Codex Major finding on bin/check-playbook.sh
# and bin/gen-playbook-blocks.sh): this script does NOT add its own NUL-byte
# (0x00) scan. A CLI argument (--rule, --why, ...) cannot carry a literal NUL
# byte in the first place — POSIX argv strings are NUL-terminated, so the
# shell/exec layer would truncate at it before this script ever saw it — that
# attack surface is closed by construction, not by a check. A NUL byte
# lurking in the PRE-EXISTING $LESSONS file (the one attack surface still
# open — e.g. someone hand-edited it) IS still caught: the fail-closed
# re-validation step below runs bin/check-playbook.sh (which does scan for
# NUL bytes) over the candidate file, and that candidate file is built from
# the existing $LESSONS content plus the new entry, so an existing NUL byte
# anywhere in $LESSONS surfaces there.
#
# NOTE (exit-code asymmetry, --title vs. every other field — T-045 round2,
# Codex Minor finding): --title gets its OWN early control-char/marker-string
# check below (die, exit 2) because it is spliced directly into the
# constructed heading line by THIS script (`## $DATE — $TITLE`) before any
# temp file exists to re-validate — catching it immediately is the more
# useful failure for a human running this by hand. Every other field's same
# class of violation (bad --category enum, control chars in --why, ...) is
# caught later, by the bin/check-playbook.sh re-validation of the full
# candidate file (fail, exit 1). This is an intentional, not accidental,
# split of "malformed invocation" (2) vs. "schema-invalid candidate content"
# (1) — --title just happens to need its own early copy of the schema-invalid
# check because of how it's used before that point. Do not read exit 2 as
# "usage error" vs. exit 1 as "content error" in a stricter sense than this;
# a caller that needs to distinguish "argument parsing failed" from "the
# candidate's values are schema-invalid" should not rely on exit code alone
# and should inspect stderr instead.
#
# Usage:
#   playbook-promote.sh --title TEXT --category CAT --applies-to CSV \
#     --status active|superseded --source TEXT --rule TEXT --why TEXT \
#     --how-to-apply TEXT [--date YYYY-MM-DD] [--lessons PATH]
#
#   --title         short entry title (single line — the script writes the
#                   heading as `## <date> — <title>`; do not include the
#                   em-dash yourself)
#   --category      one token — see bin/check-playbook.sh's known taxonomy
#   --applies-to    comma list from {engineer, qa-verifier, tech-lead,
#                   pm-spec, all}
#   --status        active | superseded
#   --source        task/issue/PR reference, external citation, or n/a
#   --rule          the takeaway, in one sentence (this is what eventually
#                   gets injected by bin/gen-playbook-blocks.sh)
#   --why           the incident or reasoning (full prose, never injected)
#   --how-to-apply  where in the workflow this kicks in (full prose, never
#                   injected)
#   --date          entry date, default: today (pass explicitly in tests)
#   --lessons       path to the lessons file (default: tasks/lessons.md)
#
# Exit: 0 = entry appended; 1 = candidate fails schema validation (lessons
#       file left untouched); 2 = usage / argument / file error.

set -euo pipefail

die()  { printf 'playbook-promote: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'playbook-promote: %s\n' "$1" >&2 || true; exit 1; }

# Resolve this script's own directory (symlink-safe) so the sibling
# check-playbook.sh can be invoked regardless of cwd — same pattern as
# close-out.sh / gen-project-status.sh.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

# Same trim as bin/check-playbook.sh's `trim()` — kept as a literal duplicate
# rather than a shared library (no cross-sourcing convention in this repo's
# bin/ scripts). Applied to every field value below BEFORE it is written, so
# this script never persists verbatim leading/trailing whitespace that would
# pass bin/check-playbook.sh's (trim-based) enum checks but then silently
# fail bin/gen-playbook-blocks.sh's raw-value comparison (T-045 rework:
# Codex round1 Major finding).
trim() {  # prints $1 with leading/trailing whitespace stripped
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Same is_valid_calendar_date() as bin/check-playbook.sh's — kept as a literal
# duplicate rather than a shared library (no cross-sourcing convention in
# this repo's bin/ scripts). T-047 fast-follow AC1: `--date` used to accept
# any [0-9]{4}-[0-9]{2}-[0-9]{2} shape with no check that it is a real
# Gregorian calendar date (`9999-99-99`, `2026-13-01`, `2023-02-29` on a
# non-leap year all used to pass). Pure bash arithmetic (no `date -d`, which
# is GNU-only — this repo's bin/ scripts stay GNU/BSD-agnostic).
is_valid_calendar_date() {  # $1 = year, $2 = month, $3 = day
  local y m d leap=0 days_in_month
  y=$((10#$1)); m=$((10#$2)); d=$((10#$3))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] || return 1
  if [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; then
    leap=1
  fi
  case "$m" in
    1|3|5|7|8|10|12) days_in_month=31 ;;
    4|6|9|11)        days_in_month=30 ;;
    2)               [ "$leap" -eq 1 ] && days_in_month=29 || days_in_month=28 ;;
  esac
  [ "$d" -ge 1 ] && [ "$d" -le "$days_in_month" ]
}

TITLE="" CATEGORY="" APPLIES="" STATUS="" SOURCE="" RULE="" WHY="" HOWTO="" DATE="" LESSONS=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --title|--category|--applies-to|--status|--source|--rule|--why|--how-to-apply|--date|--lessons)
      [ "$#" -ge 2 ] || die "missing value for $1"
      case "$1" in
        --title)        TITLE="$2" ;;
        --category)     CATEGORY="$2" ;;
        --applies-to)   APPLIES="$2" ;;
        --status)       STATUS="$2" ;;
        --source)       SOURCE="$2" ;;
        --rule)         RULE="$2" ;;
        --why)          WHY="$2" ;;
        --how-to-apply) HOWTO="$2" ;;
        --date)         DATE="$2" ;;
        --lessons)      LESSONS="$2" ;;
      esac
      shift 2
      ;;
    --help|-h)
      sed -n '2,45p' "$script_path" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Normalize every text field to its trimmed form BEFORE any validation or
# write — a candidate with trailing/leading whitespace on e.g. --status must
# neither slip past the required-field check below as "non-empty" (it would,
# on the raw value) nor ever reach tasks/lessons.md with the whitespace
# intact (see the trim() comment above).
TITLE="$(trim "$TITLE")"
CATEGORY="$(trim "$CATEGORY")"
APPLIES="$(trim "$APPLIES")"
STATUS="$(trim "$STATUS")"
SOURCE="$(trim "$SOURCE")"
RULE="$(trim "$RULE")"
WHY="$(trim "$WHY")"
HOWTO="$(trim "$HOWTO")"

# --- validation (fail-closed, before any write) ------------------------------
for pair in "title:$TITLE" "category:$CATEGORY" "applies-to:$APPLIES" \
            "status:$STATUS" "source:$SOURCE" "rule:$RULE" "why:$WHY" \
            "how-to-apply:$HOWTO"; do
  name="${pair%%:*}"
  [ -n "${pair#*:}" ] || die "missing required --$name"
done

# --title gets the same structural safety-net checks (control chars minus
# tab, marker-string collision) as every other field's value — it lives in
# the heading line rather than a `- **Field**:` bullet, but
# bin/gen-playbook-blocks.sh reads it back out (as `remainder`) exactly like
# a field value, so it needs the same guard here, not just in
# bin/check-playbook.sh's re-validation below (T-045 rework: Codex round1
# Major finding — a 0x1F byte in --title used to reach tasks/lessons.md
# unchecked and could desynchronize the generator's field-splitting).
title_no_tab="${TITLE//$'\t'/}"
if printf '%s' "$title_no_tab" | LC_ALL=C grep -q '[[:cntrl:]]'; then
  die "--title must not contain a control character (tab excepted)"
fi
case "$TITLE" in
  *'<!-- BEGIN prompt-block:'*) die "--title must not contain the reserved marker string '<!-- BEGIN prompt-block:'" ;;
esac
case "$TITLE" in
  *'<!-- END prompt-block:'*) die "--title must not contain the reserved marker string '<!-- END prompt-block:'" ;;
esac

# T-050 (#132) AC3: when --date is omitted, default to today.
#
# T-054 (#135) fast-follow: the fallback is exercised by a test using a
# fixed-output fake `date` on PATH (tests/playbook-promote/run.sh) — this is
# the sole coverage path for the omitted-`--date` default, so `date +%F` is
# called here exactly as a normal invocation would.
if [ -z "$DATE" ]; then DATE="$(date +%F)"; fi
[[ "$DATE" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]] || die "invalid --date '$DATE' (expected YYYY-MM-DD)"
# T-047 fast-follow AC1: the shape check above only confirms 4/2/2 digit
# groups — it does not confirm this is a REAL Gregorian calendar date (see
# is_valid_calendar_date()'s comment above).
is_valid_calendar_date "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" \
  || die "invalid --date '$DATE' is not a valid Gregorian calendar date"

if [ -z "$LESSONS" ]; then LESSONS="tasks/lessons.md"; fi
[ -r "$LESSONS" ] || die "cannot read lessons file: $LESSONS"

# Every free-text value must be a single line with no embedded newline —
# a multi-line value here would corrupt the one-heading-per-line /
# one-bullet-per-line grammar bin/check-playbook.sh depends on. (The rest of
# the AC1 structural checks — control chars, marker-string collision, known
# enums — are all re-verified below via bin/check-playbook.sh itself, so they
# are not duplicated here.)
for pair in "title:$TITLE" "rule:$RULE" "why:$WHY" "how-to-apply:$HOWTO" \
            "category:$CATEGORY" "applies-to:$APPLIES" "status:$STATUS" "source:$SOURCE"; do
  name="${pair%%:*}"
  val="${pair#*:}"
  if [[ "$val" == *$'\n'* ]]; then
    die "--$name must be a single line without embedded newlines"
  fi
done

# --- build the candidate entry ------------------------------------------------
ENTRY_FILE="$(mktemp "${TMPDIR:-/tmp}/playbook-promote-entry.XXXXXX")"
CANDIDATE_FILE="$(mktemp "${TMPDIR:-/tmp}/playbook-promote-candidate.XXXXXX")"
trap 'rm -f "$ENTRY_FILE" "$CANDIDATE_FILE"' EXIT

{
  printf '## %s — %s\n' "$DATE" "$TITLE"
  printf -- '- **Category**: %s\n' "$CATEGORY"
  printf -- '- **Applies-to**: %s\n' "$APPLIES"
  printf -- '- **Status**: %s\n' "$STATUS"
  printf -- '- **Source**: %s\n' "$SOURCE"
  printf -- '- **Rule**: %s\n' "$RULE"
  printf -- '- **Why**: %s\n' "$WHY"
  printf -- '- **How to apply**: %s\n' "$HOWTO"
} > "$ENTRY_FILE"

# The heading must actually be recognized as an entry by check-playbook.sh —
# the em-dash separator between date and title is part of that contract
# (see bin/check-playbook.sh's header comment); enforce it here too so a
# malformed --title cannot silently produce an unrecognized heading.
if ! grep -qE '^## [0-9]{4}-[0-9]{2}-[0-9]{2} — ' "$ENTRY_FILE"; then
  fail "constructed heading does not match the required '## YYYY-MM-DD — <title>' shape — check --title"
fi

# --- fail-closed re-validation: candidate appended to a TEMP copy only -------
cat "$LESSONS" > "$CANDIDATE_FILE"
{
  printf '\n'
  cat "$ENTRY_FILE"
} >> "$CANDIDATE_FILE"

if ! validate_out="$(bash "$SCRIPT_DIR/check-playbook.sh" "$CANDIDATE_FILE" 2>&1)"; then
  printf '%s\n' "$validate_out" >&2 || true
  fail "candidate fails schema validation — lessons file left untouched (see bin/check-playbook.sh output above)"
fi

# --- write for real (validated) ----------------------------------------------
{
  printf '\n'
  cat "$ENTRY_FILE"
} >> "$LESSONS"

printf 'playbook-promote: appended "%s — %s" to %s\n' "$DATE" "$TITLE" "$LESSONS"
printf 'playbook-promote: next step (human-run, not automatic): bin/gen-playbook-blocks.sh to refresh the generated digest blocks\n'
exit 0
