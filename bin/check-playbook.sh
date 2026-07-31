#!/usr/bin/env bash
# check-playbook.sh — schema validator for tasks/lessons.md's ACE-style
# structured playbook fields (T-045, issue #116).
#
# Each entry (a `## YYYY-MM-DD — <title>` section) must carry the required
# fields, in addition to the pre-existing Rule / Why / How to apply:
#
#   - **Category**:     <one token from a small closed taxonomy — see below>
#   - **Applies-to**:   <comma list from {engineer, qa-verifier, tech-lead,
#                        pm-spec, all}> ("all" means those four IN roles, at
#                        once — not a token for a role outside that set)
#   - **Scope**:        loop | maintainer (T-1007 — required, closed enum, no
#                        default). Only a `loop` entry is ever emitted into
#                        templates/prompt-blocks/ by bin/gen-playbook-blocks.sh;
#                        a `maintainer` entry never ships to an adopter.
#   - **Bound-in**:     <repository-relative path> (T-1007 — required when
#                        Scope is maintainer, tested on the trimmed VALUE;
#                        FORBIDDEN when Scope is loop, tested on field
#                        PRESENCE. Shape-only: non-empty after trim, not
#                        absolute, not `~`-prefixed. Never touches the
#                        filesystem — see docs/specs/T-1007-scope-typed-ledger.md
#                        DP-a/DP-d.)
#   - **Status**:       active | superseded
#   - **Source**:       <non-empty free text — task/issue/PR ref, external
#                        citation, or "n/a">
#   A lesson records the pattern and the reason it recurs, never the identifying details of the incident. Source points at an artifact in this repository, or is n/a.
#   - **Rule**:         <existing field>
#   - **Why**:          <existing field>
#   - **How to apply**: <existing field>
#
# Known Category taxonomy (small, closed): process, tooling-ci, security-pii,
# prompt-injection, path-resolution, sandbox-constraints, verification-discipline.
#
# Beyond required-field presence and known-enum membership, EVERY field value
# is checked structurally (this is what makes a value safe to splice into a
# generated prompt-block region — see bin/gen-playbook-blocks.sh):
#   (a) single line   — the value must not continue onto a following physical
#                        line before the next bullet/heading is reached.
#   (b) no control chars (tab excepted) — printable text only.
#   (c) no marker collision — the value must not contain the fixed strings
#       `<!-- BEGIN prompt-block:` / `<!-- END prompt-block:` that
#       bin/check-prompt-sync.sh uses to locate marker regions; a value
#       containing them could forge a fake marker boundary once injected.
#
# These structural checks are a safety net against accidental marker/format
# corruption, NOT a semantic or security review of entry content (see the
# "防衛の主従" design note in docs/specs/T-045-ace-playbook.md D5). The actual
# defense against malicious content is the human-approval gate in
# bin/playbook-promote.sh plus normal PR review — passing this validator is
# not a safety certification.
#
# Entries are recognized by their heading line matching the CANONICAL shape
# `^## [0-9]{4}-[0-9]{2}-[0-9]{2} — .+$` — the date, then a literal
# ` — ` (space, em-dash, space), then a non-empty title. Every line starting
# with `## ` (any level-2 heading) is classified into exactly one of three
# buckets — there is no fourth "ignore it" bucket:
#   (a) a canonical entry heading (above) — opens a new entry.
#   (b) an exact match against $ALLOWLISTED_HEADINGS (currently just
#       `## Format`, the schema-example section this file itself has) — a
#       legitimate non-entry section heading. Ends whatever entry was open
#       (if any) without opening a new one.
#   (c) anything else starting with `## ` — a FAIL-CLOSED violation. This is
#       deliberately strict: a prior looser design treated "not date-anchored"
#       as "ignore, must be body text", which let a typo'd heading (a missing
#       space before the date, a hyphen instead of the em-dash, ...) silently
#       fall through as ordinary prose and get absorbed into whatever entry
#       was still open — misattributing its field values (including `Rule`,
#       which gen-playbook-blocks.sh injects into an agent prompt) to the
#       PRIOR entry's tasks/lessons.md pointer. Hitting case (c) immediately
#       closes whatever entry was open (see `in_entry=0` below) so nothing
#       after it can be folded into an unrelated entry, even though the
#       malformed heading itself is flagged and the run still fails overall.
# Bucket (b) is why the fenced ```markdown example under `## Format` (whose
# fake `## YYYY-MM-DD — <short title>` line is neither case (a) — "YYYY" etc.
# are not digits — nor an exact `## Format` match) needs fence-awareness:
# lines inside a fenced code block are skipped entirely before this
# classification runs, exactly like a real Markdown renderer would treat them
# (illustrative text, not document structure).
#
# Fence recognition is a CONFIRMED GRAMMAR (T-045 rework4, replacing rework3's
# is_fence_marker() after round4 found two new Blockers + one Major in it —
# rounds 2/3/4 each introduced a new fence-tracking bug, so this round
# redesigns the grammar wholesale rather than patching another edge case).
# This is OUR OWN file format, so an ambiguous construct is rejected
# fail-closed rather than guessed at:
#
#   1. A "fence-run line" is: strip 0-3 leading indentation characters (an
#      ASCII space OR a tab count equally as one unit of indentation — T-047
#      fast-follow: a leading tab used to fall through fence_open_check()
#      unclassified as ordinary text, since only ASCII spaces were counted),
#      then a run of 3-or-more identical fence characters (backtick ` or
#      tilde ~) — the CommonMark shape, indent allowance included.
#   2. Encountered OUTSIDE a fence, a fence-run line OPENS one: its character
#      and run length are recorded. A backtick opener whose info string (the
#      text after the run) itself contains a backtick is invalid per
#      CommonMark (ambiguous with an inline code span) — that is a
#      fail-closed VIOLATION, and the fence does NOT open (fence_open_check()
#      returns invalid; see below). A tilde opener's info string is
#      unconstrained.
#   3. Encountered INSIDE a fence, a fence-run line only CLOSES it if ALL of:
#      same character, run length >= the opening's, AND nothing but
#      whitespace follows the run to end of line. Any one of these failing —
#      wrong character, too-short run, or (round4 Blocker) trailing non-
#      whitespace content after the run — means the line is just fence
#      CONTENT; the fence stays open (see fence_close_check() below).
#   4. A line that starts with 4-OR-MORE leading spaces but, after stripping
#      ALL of them, still looks like a fence-run: CommonMark would read this
#      as an INDENTED CODE BLOCK, not a fence — a genuinely different
#      construct this validator does not attempt to distinguish. Encountered
#      OUTSIDE a fence, that ambiguity is itself a fail-closed VIOLATION
#      (round4 Blocker: a 1-3-space-indented FENCE was previously not
#      recognized as a fence at all, so its column-0 content — including a
#      forged entry — validated as if it were real document structure;
#      rejecting the 4+-space ambiguous case outright, rather than silently
#      treating it as either an indented block or a fence, closes that
#      class of gap without guessing). Encountered INSIDE an already-open
#      fence, it is unremarkable fence CONTENT (case 3 above already covers
#      it: 4+ leading spaces alone fails "0-3 leading spaces", so it can't
#      close the fence either).
#   5. If the file ends while still inside a fence (unterminated fence), that
#      is itself a fail-closed violation — see the EOF check after the main
#      loop (T-045 round3). An unterminated fence would otherwise make every
#      line after it (however far into the file) silently vanish with no
#      warning.
#
# fence_open_check() and fence_close_check() are deliberately SEPARATE
# functions (not one is_fence_marker() call reused for both directions) —
# round4's Blockers were exactly the result of open and close sharing one
# under-specified check.
#
# The heading's title text (the part after the em-dash) is itself a
# field-like value: bin/gen-playbook-blocks.sh reads it back out (as
# `remainder`) to build the tasks/lessons.md pointer it injects, so it gets
# the SAME structural checks (b)/(c) below as every other field — a title is
# not exempt just because it lives in the heading line rather than a
# `- **Field**:` bullet.
#
# Before any line-based parsing, the WHOLE FILE is scanned for a literal NUL
# byte (0x00) and rejected fail-closed if one is found — bash's `read`
# cannot preserve a NUL within a line (behavior varies by version but never
# "keep it"), so a value containing one would silently reach
# gen-playbook-blocks.sh's field-splitting untruncated on disk but truncated
# in every in-memory check, which is exactly the kind of validator/reality gap
# a fail-closed schema check must not have. See `has_nul_byte()` below.
#
# Reads only. Pure bash + coreutils; no external interpreter is invoked.
# Prints `<file>: <entry heading>: <reason>` per violation to stderr.
#
# Usage:  check-playbook.sh <lessons.md> [<lessons.md>...]
# Exit:   0 = all entries valid, 1 = violation(s), 2 = usage / unreadable file.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  printf 'usage: check-playbook.sh <lessons.md> [<lessons.md>...]\n' >&2 || true
  exit 2
fi

KNOWN_CATEGORIES="process tooling-ci security-pii prompt-injection path-resolution sandbox-constraints verification-discipline"
KNOWN_ROLES="engineer qa-verifier tech-lead pm-spec all"
KNOWN_STATUS="active superseded"
# T-1007 DP-c: exactly two tokens, no default. #23's routing table has four
# outcomes; the other two (operator-global, drop) never enter this repository
# and so never need a token here.
KNOWN_SCOPES="loop maintainer"

# T-108: the full allow-list of `- **<Name>**:` field bullets an entry may
# carry. Category..How-to-apply are the pre-existing T-045 fields;
# Superseded-by (retirement pointer) and Extended by (name-only, no value
# validation — see DP-5) are new. A bullet whose bold name is not in this
# list is a fail-closed violation (AC8) — the OLD if/elif chain (with no
# trailing `else`) used to silently DROP anything it didn't recognize (e.g. a
# case-different `- **Superseded-By**:`), which is exactly the DP-4 bug this
# allow-list closes. Membership is enforced implicitly by the if/elif chain
# order in the main loop below (every known field has its own elif tested
# FIRST; only an unrecognized bullet ever reaches the catch-all `else`) —
# this array's only remaining job is to name the full allow-list in that
# catch-all's violation message. Kept as an array (not a space list, unlike
# the KNOWN_* above) because two of these names ("How to apply",
# "Extended by") contain a space themselves. T-1007 adds Scope and Bound-in
# (see the header comment and DP-a/DP-c/DP-d in
# docs/specs/T-1007-scope-typed-ledger.md).
KNOWN_FIELD_NAMES=(Category Applies-to Scope Bound-in Status Source Rule Why "How to apply" Superseded-by "Extended by")

token_known() {  # $1 = space-separated known set, $2 = candidate token
  local known="$1" tok="$2" t
  for t in $known; do
    [ "$t" = "$tok" ] && return 0
  done
  return 1
}

trim() {  # prints $1 with leading/trailing whitespace stripped
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# is_valid_calendar_date() — $1/$2/$3 = year/month/day, each already known to
# be a fixed-width digit group (the caller's regex already anchored the shape
# to [0-9]{4}/[0-9]{2}/[0-9]{2}). Returns 0 only if this is a REAL Gregorian
# calendar date — rejects an out-of-range month, an out-of-range day for that
# month, and Feb 29 on a non-leap year. Pure bash arithmetic (no `date -d`,
# which is GNU-only — this repo's bin/ scripts stay GNU/BSD-agnostic).
# `10#$x` forces base-10 interpretation so a zero-padded value like "08" is
# never misread as an invalid octal literal.
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

# Exact-match allow-list of non-entry `## ` section headings this file is
# permitted to carry. Anything starting with `## ` that is neither this nor
# a canonical entry heading is a fail-closed violation (see header comment).
ALLOWLISTED_HEADINGS=("## Format")

is_allowlisted_heading() {  # $1 = full heading line; returns 0 if allow-listed
  local line="$1" h
  for h in "${ALLOWLISTED_HEADINGS[@]}"; do
    [ "$line" = "$h" ] && return 0
  done
  return 1
}

# Whole-file NUL-byte (0x00) scan, run before any line-based `read` parsing
# (see header comment). `tr -d '\000'` deletes every NUL byte; if the
# stripped byte count differs from the original, at least one was present.
# Pure coreutils (tr/wc), works identically under GNU and BSD tr.
has_nul_byte() {  # $1 = file; returns 0 (true) if it contains a NUL byte
  local orig stripped
  orig="$(wc -c < "$1")"
  stripped="$(tr -d '\000' < "$1" | wc -c)"
  [ "$orig" -ne "$stripped" ]
}

# fence_open_check() — $1 = line. Called only while NOT already in a fence.
# Classifies $line per grammar items 1/2/4 above. Exit status:
#   0 = a fence-run line at 0-3 leading spaces (a genuine open candidate).
#       Sets FENCE_CHAR / FENCE_LEN (the run's character/length) and
#       FENCE_OPEN_INVALID (1 = well-formed fence-run but CommonMark forbids
#       it as an opener — a backtick info string containing a backtick; the
#       caller must still reject this fail-closed without opening a fence).
#   1 = not a fence-run line under any leading-space interpretation —
#       ordinary text.
#   2 = "ambiguous": 4-or-more leading spaces, but the line still looks like
#       a fence-run once ALL of them are stripped (grammar item 4) — the
#       caller rejects this fail-closed rather than guessing indented-code-
#       block vs. fence.
fence_open_check() {
  local line="$1" all_spaces rest info
  # [[:blank:]] (space OR tab) — round5 Minor: a run of leading tabs used to
  # fall through unclassified as "ordinary text" because this used to only
  # match ASCII spaces (\ *); a tab is now counted as indentation too, on
  # equal footing with a space, for the 0-3/4-or-more threshold below.
  [[ "$line" =~ ^([[:blank:]]*)(.*)$ ]] || return 1
  all_spaces="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
  if [[ "$rest" =~ ^(\`{3,})(.*)$ ]]; then
    FENCE_CHAR='`'
  elif [[ "$rest" =~ ^(~{3,})(.*)$ ]]; then
    FENCE_CHAR='~'
  else
    return 1
  fi
  FENCE_LEN=${#BASH_REMATCH[1]}
  info="${BASH_REMATCH[2]}"
  [ "${#all_spaces}" -lt 4 ] || return 2
  if [ "$FENCE_CHAR" = '`' ]; then
    case "$info" in
      *'`'*) FENCE_OPEN_INVALID=1 ;;
      *)     FENCE_OPEN_INVALID=0 ;;
    esac
  else
    FENCE_OPEN_INVALID=0
  fi
  return 0
}

# fence_close_check() — $1 = line, $2 = the OPEN fence's character, $3 = the
# OPEN fence's run length. Called only while already inside a fence.
# Classifies $line per grammar item 3 above. Returns 0 if $line legitimately
# CLOSES the fence (0-3 leading spaces, same character, run length >= $3,
# and nothing but whitespace after the run to end of line); returns 1
# otherwise (wrong character, too-short run, trailing non-whitespace
# content, 4+ leading spaces, or plain non-fence-run content — all of these
# mean "just fence content", not "close").
fence_close_check() {
  local line="$1" want_char="$2" want_len="$3" all_spaces rest info got_len
  # [[:blank:]] (space OR tab) — see fence_open_check()'s comment above.
  [[ "$line" =~ ^([[:blank:]]*)(.*)$ ]] || return 1
  all_spaces="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
  [ "${#all_spaces}" -le 3 ] || return 1
  if [[ "$rest" =~ ^(\`{3,})(.*)$ ]]; then
    [ "$want_char" = '`' ] || return 1
  elif [[ "$rest" =~ ^(~{3,})(.*)$ ]]; then
    [ "$want_char" = '~' ] || return 1
  else
    return 1
  fi
  got_len=${#BASH_REMATCH[1]}
  info="${BASH_REMATCH[2]}"
  [ "$got_len" -ge "$want_len" ] || return 1
  [[ "$info" =~ ^[[:space:]]*$ ]] || return 1
  return 0
}

FILE=""
violations=0
emit() { printf '%s: %s: %s\n' "$FILE" "$1" "$2" >&2; violations=$((violations + 1)); }

# Structural safety-net checks (b)/(c) from the header comment. (a) — single
# line — is enforced separately by the continuation-line scan in the main
# loop below, since it depends on the FOLLOWING physical line.
check_structural() {  # $1 = entry label, $2 = field name, $3 = value
  local entry="$1" field="$2" val="$3" val_no_tab
  val_no_tab="${val//$'\t'/}"
  if printf '%s' "$val_no_tab" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    emit "$entry" "field '$field' contains a control character (tab excepted)"
  fi
  case "$val" in
    *'<!-- BEGIN prompt-block:'*)
      emit "$entry" "field '$field' contains the reserved marker string '<!-- BEGIN prompt-block:'" ;;
  esac
  case "$val" in
    *'<!-- END prompt-block:'*)
      emit "$entry" "field '$field' contains the reserved marker string '<!-- END prompt-block:'" ;;
  esac
}

for FILE in "$@"; do
  if [ ! -r "$FILE" ]; then
    printf 'check-playbook: cannot read file: %s\n' "$FILE" >&2 || true
    exit 2
  fi

  if has_nul_byte "$FILE"; then
    emit "(whole file)" "contains a NUL byte (0x00) — refusing to parse line-by-line (fail-closed; a NUL cannot survive bash's read reliably, so line-based checks cannot see what would actually be committed)"
    continue
  fi

  in_entry=0
  in_fence=0
  fence_char=""
  fence_len=0
  entry_label=""
  seen_category=0; seen_applies=0; seen_status=0; seen_source=0
  seen_rule=0; seen_why=0; seen_howto=0; seen_superseded_by=0
  seen_scope=0; seen_bound_in=0
  val_category=""; val_applies=""; val_status=""; val_source=""
  val_rule=""; val_why=""; val_howto=""; val_title=""
  val_key=""; val_superseded_by=""
  val_scope=""; val_bound_in=""
  prev_field=""

  # T-108 DP-1: per-entry records accumulated here by finalize_entry() (pass
  # 1, unmodified otherwise) and consumed by the Superseded-by
  # reference-resolution pass 2 below, AFTER `done < "$FILE"`. Reset per
  # $FILE (DP-7: reference resolution is scoped to a single file, never
  # cross-file). Deliberately NOT a single-pass check: resolving a pointer
  # while scanning forward would make a FORWARD reference (AC7) spuriously
  # fail depending on file order — the full key table must exist first.
  # ENTRY_SUPERSEDED_SEEN tracks FIELD PRESENCE (was a `- **Superseded-by**:`
  # bullet written at all?), kept deliberately SEPARATE from ENTRY_SUPERSEDED
  # (the trimmed VALUE) — round1 rework (Codex Major): AC2 used to test
  # `[ -n "$e_sup" ]` (the trimmed value) as a presence proxy, which made a
  # whitespace-only value on an `active` entry (bullet present, value blank)
  # indistinguishable from the bullet being absent entirely, so AC2 silently
  # missed it. AC1 was accidentally correct already (it tests `-z`, so
  # "absent" and "present-but-blank" both already read as "no real pointer"
  # for a superseded entry, which is exactly the union AC1 wants) — but AC2
  # wants the OPPOSITE union ("must be absent"), and only true absence, not
  # value emptiness, can decide that. Presence is tracked independently of
  # the trimmed value for exactly this reason.
  # T-1007: ENTRY_SCOPES is a sixth parallel array (trimmed Scope value,
  # index-aligned with the five above via the same unconditional push in
  # finalize_entry()) — DP-b's pass-2 directional-supersession check reads it
  # the same way pass 2 already reads ENTRY_STATUSES.
  ENTRY_KEYS=(); ENTRY_STATUSES=(); ENTRY_SUPERSEDED=(); ENTRY_SUPERSEDED_SEEN=(); ENTRY_LABELS=(); ENTRY_SCOPES=()

  finalize_entry() {
    [ "$in_entry" -eq 1 ] || return 0

    [ "$seen_category" -eq 1 ] || emit "$entry_label" "missing required field: Category"
    [ "$seen_applies"  -eq 1 ] || emit "$entry_label" "missing required field: Applies-to"
    [ "$seen_scope"    -eq 1 ] || emit "$entry_label" "missing required field: Scope"
    [ "$seen_status"   -eq 1 ] || emit "$entry_label" "missing required field: Status"
    [ "$seen_source"   -eq 1 ] || emit "$entry_label" "missing required field: Source"
    [ "$seen_rule"     -eq 1 ] || emit "$entry_label" "missing required field: Rule"
    [ "$seen_why"      -eq 1 ] || emit "$entry_label" "missing required field: Why"
    [ "$seen_howto"    -eq 1 ] || emit "$entry_label" "missing required field: How to apply"

    if [ "$seen_category" -eq 1 ]; then
      local c; c="$(trim "$val_category")"
      token_known "$KNOWN_CATEGORIES" "$c" \
        || emit "$entry_label" "unknown Category value: '$val_category'"
    fi

    # T-1007 DP-c: Scope's enum is closed at exactly loop|maintainer, no
    # default. An empty/whitespace-only value trims to a token that matches
    # neither, so it falls into the same "unknown Scope value" branch as a
    # genuinely out-of-enum token (e.g. "all") — same pattern Category/Status
    # already use above for their own blank-value case.
    local entry_scope=""
    if [ "$seen_scope" -eq 1 ]; then
      entry_scope="$(trim "$val_scope")"
      token_known "$KNOWN_SCOPES" "$entry_scope" \
        || emit "$entry_label" "unknown Scope value: '$val_scope'"

      # T-1007 DP-a: Bound-in is mandatory on maintainer (value-tested — an
      # absent bullet and a blank one are the SAME violation) and forbidden
      # on loop (presence-tested — a blank bullet is still a bullet). This
      # mirrors the existing active x Superseded-by asymmetry above/below:
      # the T-108 round-1 Major that established value-vs-presence as two
      # deliberately different tests for two deliberately different rules.
      if [ "$entry_scope" = "maintainer" ]; then
        local bv; bv="$(trim "$val_bound_in")"
        [ -n "$bv" ] || emit "$entry_label" "Scope is 'maintainer' but Bound-in is missing"
      elif [ "$entry_scope" = "loop" ]; then
        [ "$seen_bound_in" -eq 0 ] || emit "$entry_label" "Scope is 'loop' but Bound-in is present"
      fi
    fi

    # T-1007 DP-d: Bound-in is validated by shape only — non-empty after
    # trim (the maintainer-mandatory check above already covers that half),
    # not absolute, not `~`-prefixed — and never against the filesystem, so
    # the verdict never depends on the working directory the checker was
    # invoked from. Runs whenever the bullet is present, independent of
    # Scope's own validity, so a shape violation is never masked by an
    # unrelated Scope problem.
    if [ "$seen_bound_in" -eq 1 ]; then
      local biv; biv="$(trim "$val_bound_in")"
      case "$biv" in
        /*|'~'*)
          emit "$entry_label" "Bound-in must be a repository-relative path: '$val_bound_in'" ;;
      esac
    fi

    if [ "$seen_status" -eq 1 ]; then
      local s; s="$(trim "$val_status")"
      token_known "$KNOWN_STATUS" "$s" \
        || emit "$entry_label" "unknown Status value: '$val_status' (expected active|superseded)"
    fi

    if [ "$seen_applies" -eq 1 ]; then
      local tok trimmed had_token=0
      IFS=',' read -ra applies_tokens <<< "$val_applies"
      for tok in "${applies_tokens[@]}"; do
        trimmed="$(trim "$tok")"
        [ -n "$trimmed" ] || continue
        had_token=1
        token_known "$KNOWN_ROLES" "$trimmed" \
          || emit "$entry_label" "unknown Applies-to role token: '$trimmed'"
      done
      [ "$had_token" -eq 1 ] || emit "$entry_label" "Applies-to has no role tokens: '$val_applies'"
    fi

    if [ "$seen_source" -eq 1 ]; then
      local src; src="$(trim "$val_source")"
      [ -n "$src" ] || emit "$entry_label" "Source must be non-empty"
    fi

    # Rule / Why / How to apply get the same trim-then-non-empty check as
    # Source — a whitespace-only value technically satisfies "the field is
    # present" but would inject a blank line (Rule) or document a hollow
    # incident/how-to-apply, which is never a useful entry.
    if [ "$seen_rule" -eq 1 ]; then
      local rv; rv="$(trim "$val_rule")"
      [ -n "$rv" ] || emit "$entry_label" "Rule must be non-empty"
    fi
    if [ "$seen_why" -eq 1 ]; then
      local wv; wv="$(trim "$val_why")"
      [ -n "$wv" ] || emit "$entry_label" "Why must be non-empty"
    fi
    if [ "$seen_howto" -eq 1 ]; then
      local hv; hv="$(trim "$val_howto")"
      [ -n "$hv" ] || emit "$entry_label" "How to apply must be non-empty"
    fi

    # T-108 DP-1 (pass 1 addition, not a modification of anything above):
    # record this entry for the pass-2 Superseded-by reference-resolution
    # loop that runs after `done < "$FILE"`. Trimmed here (once, at the
    # source) so pass 2 never has to re-derive trim-vs-raw semantics itself —
    # AC3's "trim then equality" applies uniformly to both the key side and
    # the Superseded-by value side this way.
    ENTRY_KEYS+=("$(trim "$val_key")")
    ENTRY_STATUSES+=("$(trim "$val_status")")
    ENTRY_SUPERSEDED+=("$(trim "$val_superseded_by")")
    ENTRY_SUPERSEDED_SEEN+=("$seen_superseded_by")
    # T-1007: pushed unconditionally, same as the five arrays above — every
    # entry gets a slot regardless of whether its own Scope is present/valid,
    # so a later entry's scope can never be misread off an earlier entry's.
    ENTRY_SCOPES+=("$entry_scope")
    ENTRY_LABELS+=("$entry_label")
  }

  while IFS= read -r rawline || [ -n "$rawline" ]; do
    line="${rawline%$'\r'}"

    # Fenced code blocks hold illustrative example text (this file's own
    # `## Format` section fences a synthetic entry) — never real document
    # structure, so the heading classification below must not see inside one.
    # See the confirmed fence grammar in the header comment.
    if [ "$in_fence" -eq 0 ]; then
      open_rc=0
      fence_open_check "$line" || open_rc=$?
      if [ "$open_rc" -eq 0 ]; then
        if [ "$FENCE_OPEN_INVALID" -eq 1 ]; then
          emit "$line" "invalid fence opener — a backtick fence's info string must not itself contain a backtick (CommonMark); this line does not open a fence"
        else
          in_fence=1
          fence_char="$FENCE_CHAR"
          fence_len="$FENCE_LEN"
        fi
        continue
      elif [ "$open_rc" -eq 2 ]; then
        emit "$line" "ambiguous fence-like line (a run of 3+ '\`' or '~' after 4-or-more leading spaces) outside any fence — rejected fail-closed rather than guessed as an indented code block vs. a fence"
        continue
      fi
      # open_rc == 1: not a fence-run line at all — fall through to normal
      # heading/field parsing below.
    else
      if fence_close_check "$line" "$fence_char" "$fence_len"; then
        in_fence=0
        fence_char=""
        fence_len=0
      fi
      # Whether or not it closed, this line itself is never document
      # structure: if it closed, the LINE is the closing fence marker
      # itself; if it didn't, it's ordinary fence content (grammar item 3).
      continue
    fi

    if [[ "$line" =~ ^\#\#\  ]]; then
      # Every level-2 heading is classified into exactly one of three
      # buckets — see the header comment for why there is deliberately no
      # implicit fourth "doesn't match, so treat as body text" bucket.
      if [[ "$line" =~ ^\#\#\ ([0-9]{4}-[0-9]{2}-[0-9]{2})\ —\ (.+)$ ]]; then
        # (a) canonical entry heading: `## YYYY-MM-DD — <title>`.
        finalize_entry
        in_entry=1
        entry_label="$line"
        seen_category=0; seen_applies=0; seen_status=0; seen_source=0
        seen_rule=0; seen_why=0; seen_howto=0; seen_superseded_by=0
        seen_scope=0; seen_bound_in=0
        val_category=""; val_applies=""; val_status=""; val_source=""
        val_rule=""; val_why=""; val_howto=""; val_superseded_by=""
        val_scope=""; val_bound_in=""
        # T-108: the entry KEY as bin/gen-playbook-blocks.sh's own pointer
        # text would spell it — "YYYY-MM-DD — <title>" — is what a
        # Superseded-by value must equal (trim-then-equality, DP-3/AC3), and
        # what pass 2 below records this entry as for OTHER entries' pointers
        # to resolve against.
        val_key="${BASH_REMATCH[1]} — ${BASH_REMATCH[2]}"
        # The title text after the em-dash — e.g. "Bootstrap" — is what
        # bin/gen-playbook-blocks.sh re-reads as `remainder` to build its
        # tasks/lessons.md pointer; give it the same (b)/(c) structural
        # checks every other field value gets (control chars, marker-string
        # collision — see the header comment). Its "single line" property
        # (a) is guaranteed for free: it can only ever be the tail of one
        # heading line.
        val_title="${BASH_REMATCH[2]}"
        check_structural "$entry_label" "Title" "$val_title"
        # T-047 fast-follow AC4: Title gets the same trim-then-non-empty
        # check every other field already has (Rule/Why/How to apply/
        # Source) — a whitespace-only title technically satisfies "the
        # heading matched the canonical shape" but would inject a hollow,
        # unreadable pointer once gen-playbook-blocks.sh reads it back out.
        [ -n "$(trim "$val_title")" ] || emit "$entry_label" "Title must be non-empty"
        # T-047 fast-follow AC1: the heading date must be a REAL Gregorian
        # calendar date, not merely 4/2/2-digit shapes — `9999-99-99`,
        # `2026-13-01`, `2023-02-29` (non-leap) all used to pass unchecked.
        IFS='-' read -r heading_y heading_m heading_d <<< "${BASH_REMATCH[1]}"
        is_valid_calendar_date "$heading_y" "$heading_m" "$heading_d" \
          || emit "$entry_label" "heading date '${BASH_REMATCH[1]}' is not a valid Gregorian calendar date"
        prev_field=""
      elif is_allowlisted_heading "$line"; then
        # (b) a legitimate non-entry section heading (e.g. `## Format`) —
        # closes whatever entry was open, without opening a new one.
        finalize_entry
        in_entry=0
        prev_field=""
      else
        # (c) fail-closed violation — neither a canonical entry heading nor
        # allow-listed. Close whatever entry was open FIRST: this is the fix
        # for the silent-merge bug (a prior design left `in_entry`/the
        # current field state pointing at the LAST recognized heading, so
        # field bullets after a malformed one were misattributed to it).
        # Nothing after this line is attributed to any entry until the next
        # canonical heading appears — the malformed heading itself is
        # reported as a violation and the whole run still fails.
        finalize_entry
        in_entry=0
        prev_field=""
        emit "$line" "not a canonical entry heading ('## YYYY-MM-DD — <title>', em-dash separator required) and not an allow-listed section heading"
      fi
      continue
    fi

    [ "$in_entry" -eq 1 ] || continue

    # (a) single-line check: the PREVIOUS line opened a field bullet, so this
    # line must be either blank, a new bullet (`- ...`), or absent — anything
    # else means the previous field's value spilled onto a second physical
    # line.
    if [ -n "$prev_field" ]; then
      if [ -n "$line" ] && [[ "$line" != -\ * ]]; then
        emit "$entry_label" "field '$prev_field' value spans multiple lines (must be single-line)"
      fi
      prev_field=""
    fi

    fieldval=""
    if [[ "$line" =~ ^-\ \*\*Category\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_category="$fieldval"; seen_category=1; prev_field="Category"
      check_structural "$entry_label" "Category" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Applies-to\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_applies="$fieldval"; seen_applies=1; prev_field="Applies-to"
      check_structural "$entry_label" "Applies-to" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Scope\*\*:\ (.*)$ ]]; then
      # T-1007: enum + Scope x Bound-in combination rules are resolved once
      # per entry in finalize_entry() (the full value must be captured
      # first); this arm only records field presence and runs the same
      # structural safety-net every other field value gets.
      fieldval="${BASH_REMATCH[1]}"; val_scope="$fieldval"; seen_scope=1; prev_field="Scope"
      check_structural "$entry_label" "Scope" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Bound-in\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_bound_in="$fieldval"; seen_bound_in=1; prev_field="Bound-in"
      check_structural "$entry_label" "Bound-in" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Status\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_status="$fieldval"; seen_status=1; prev_field="Status"
      check_structural "$entry_label" "Status" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Source\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_source="$fieldval"; seen_source=1; prev_field="Source"
      check_structural "$entry_label" "Source" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Rule\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_rule="$fieldval"; seen_rule=1; prev_field="Rule"
      check_structural "$entry_label" "Rule" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Why\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_why="$fieldval"; seen_why=1; prev_field="Why"
      check_structural "$entry_label" "Why" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*How\ to\ apply\*\*:\ (.*)$ ]]; then
      fieldval="${BASH_REMATCH[1]}"; val_howto="$fieldval"; seen_howto=1; prev_field="How to apply"
      check_structural "$entry_label" "How to apply" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Superseded-by\*\*:\ (.*)$ ]]; then
      # T-108: the retirement pointer — its VALUE is resolved against every
      # OTHER entry's key in the pass-2 reference-resolution loop below (not
      # here — the full key table doesn't exist yet mid-scan). This field
      # gets the same structural (b)/(c) checks as every other field value
      # (single-line/no-control-char/no-marker-collision) — it is spliced
      # nowhere by bin/gen-playbook-blocks.sh, but a corrupted value here
      # would still corrupt THIS file's own grammar for the next reader/tool.
      fieldval="${BASH_REMATCH[1]}"; val_superseded_by="$fieldval"; seen_superseded_by=1; prev_field="Superseded-by"
      check_structural "$entry_label" "Superseded-by" "$fieldval"
    elif [[ "$line" =~ ^-\ \*\*Extended\ by\*\*:\ (.*)$ ]]; then
      # T-108 DP-5 (Non-goals): name-only allow-list registration — the
      # VALUE is intentionally never validated (no check_structural call),
      # so this only needs to be recognized here to keep it out of the AC8
      # unknown-field catch-all below (the two pre-existing "Extended by"
      # bullets in the real tasks/lessons.md predate this recognition and
      # must keep validating green — AC9 self-host).
      prev_field="Extended by"
    elif [[ "$line" =~ ^-\ \*\*([^*]+)\*\*: ]]; then
      # T-108 AC8 (DP-4): anything ELSE shaped like a bold-name field bullet
      # is a fail-closed violation, not a silent drop — the bug this closes:
      # the OLD chain (no trailing `else`) let a case-different
      # `- **Superseded-By**:` (or any other typo'd/unregistered bullet name)
      # fall through completely unclassified. Anchored on the colon only (no
      # trailing `$`/space requirement) so a malformed known-field bullet
      # missing its post-colon space (e.g. `- **Rule**:foo`) is ALSO caught
      # here rather than silently matching nothing at all — every known
      # field's own elif above already requires ": " and comes first in the
      # chain, so a well-formed known field never reaches this branch.
      bullet_name="${BASH_REMATCH[1]}"
      emit "$entry_label" "unknown field bullet: '- **${bullet_name}**:' (not in the known field allow-list: ${KNOWN_FIELD_NAMES[*]})"
      prev_field="$bullet_name"
    fi
  done < "$FILE"

  # EOF reached while still inside a fence: everything from the opening
  # marker onward (including any otherwise-valid entries) was silently
  # skipped above. That must never pass silently — report it explicitly
  # rather than let the file "just happen" to look valid.
  if [ "$in_fence" -eq 1 ]; then
    emit "(whole file)" "a fenced code block (opened with a run of ${fence_len} '${fence_char}' characters) is never closed before EOF — every line after it was ignored; close the fence"
  fi

  finalize_entry

  # ===========================================================================
  # T-108 pass 2 — Superseded-by reference resolution (DP-1: added as a
  # STRICTLY SEPARATE pass after `done < "$FILE"`, never folded into the
  # single forward scan above). ENTRY_KEYS/ENTRY_STATUSES/ENTRY_SUPERSEDED/
  # ENTRY_LABELS were populated by finalize_entry() (one push per entry, in
  # file order) — see the arrays' declaration/reset near the top of this
  # $FILE iteration. Scope is per-file (DP-7): these arrays are reset at the
  # start of each $FILE iteration, so a Superseded-by value never resolves
  # against a DIFFERENT file's entries even under `check-playbook.sh a.md
  # b.md`.
  # ===========================================================================
  n_entries=${#ENTRY_KEYS[@]}
  i=0
  while [ "$i" -lt "$n_entries" ]; do
    e_key="${ENTRY_KEYS[$i]}"
    e_status="${ENTRY_STATUSES[$i]}"
    e_sup="${ENTRY_SUPERSEDED[$i]}"
    e_sup_seen="${ENTRY_SUPERSEDED_SEEN[$i]}"
    e_label="${ENTRY_LABELS[$i]}"
    e_scope="${ENTRY_SCOPES[$i]}"

    # AC1: a superseded entry with no (or whitespace-only) Superseded-by.
    # Testing the trimmed VALUE (not presence) is deliberate here: "the
    # bullet is absent" and "the bullet is present but blank" are the SAME
    # violation from AC1's point of view (superseded entries need a real,
    # non-empty pointer either way), so collapsing them via `-z "$e_sup"` is
    # correct and was never the bug (see AC2 immediately below for the
    # asymmetric half that WAS).
    if [ "$e_status" = "superseded" ] && [ -z "$e_sup" ]; then
      emit "$e_label" "Status is 'superseded' but Superseded-by is missing (or empty) — a retired entry must name its replacement"
    fi
    # AC2: an active entry must never carry a Superseded-by bullet AT ALL —
    # tested via FIELD PRESENCE (e_sup_seen), not the trimmed value's
    # emptiness. rework1 (Codex round1 Major): the old `[ -n "$e_sup" ]` test
    # used the trimmed VALUE as a presence proxy, so a whitespace-only value
    # (bullet present, value blank after trim) was indistinguishable from the
    # bullet being absent entirely and silently passed. AC1 above needed the
    # opposite union (blank-or-absent are both violations) and so was
    # unaffected by the same value-vs-presence conflation; AC2 needed
    # "bullet exists at all" and so was not.
    if [ "$e_status" = "active" ] && [ "$e_sup_seen" -eq 1 ]; then
      emit "$e_label" "Status is 'active' but Superseded-by is present: '$e_sup' (only a superseded entry may point elsewhere)"
    fi

    if [ -n "$e_sup" ]; then
      if [ "$e_sup" = "$e_key" ]; then
        # AC5: self-reference.
        emit "$e_label" "Superseded-by points to itself (self-reference not allowed): '$e_sup'"
      else
        # AC3 (equality, never containment — DP-3) / AC4 (target must be
        # active) / AC7 (a target defined LATER in the file must still
        # resolve — this loop scans the WHOLE table, not just entries seen
        # so far, so file order never matters here).
        found=0
        target_status=""
        target_scope=""
        j=0
        while [ "$j" -lt "$n_entries" ]; do
          if [ "${ENTRY_KEYS[$j]}" = "$e_sup" ]; then
            found=1
            target_status="${ENTRY_STATUSES[$j]}"
            target_scope="${ENTRY_SCOPES[$j]}"
            break
          fi
          j=$((j + 1))
        done
        if [ "$found" -eq 0 ]; then
          emit "$e_label" "Superseded-by points to a key that does not exist in this file (equality match, not containment): '$e_sup'"
        elif [ "$target_status" != "active" ]; then
          emit "$e_label" "Superseded-by points to an entry whose Status is not 'active' (chained/duplicate supersession is not allowed): '$e_sup'"
        elif [ "$e_scope" = "loop" ] && [ "$target_scope" = "maintainer" ]; then
          # T-1007 DP-b: directional, not symmetric. A shipped ('loop') rule
          # may only be retired in favour of another shipped rule — the
          # reference graph stays healthy while a rule silently disappears
          # from every adopter's prompt with nothing replacing it in the
          # shipped set. The other three combinations (loop->loop,
          # maintainer->maintainer, maintainer->loop) are legal; only this
          # one direction is a violation.
          emit "$e_label" "Superseded-by crosses Scope: a 'loop' entry may not be superseded by a 'maintainer' entry ('$e_sup')"
        fi
      fi
    fi

    i=$((i + 1))
  done

  # AC6: entry-key (date, title) uniqueness — every unordered pair, so a
  # THIRD or later duplicate is still individually reported, not just the
  # first repeat.
  i=0
  while [ "$i" -lt "$n_entries" ]; do
    j=$((i + 1))
    while [ "$j" -lt "$n_entries" ]; do
      if [ "${ENTRY_KEYS[$i]}" = "${ENTRY_KEYS[$j]}" ]; then
        emit "${ENTRY_LABELS[$j]}" "duplicate entry key (date, title) also used by an earlier entry in this file: '${ENTRY_KEYS[$i]}'"
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
done

if [ "$violations" -gt 0 ]; then
  printf 'check-playbook: %d violation(s)\n' "$violations" >&2 || true
  exit 1
fi
printf 'check-playbook: all entries valid\n'
exit 0
