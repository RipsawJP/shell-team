#!/usr/bin/env bash
# gen-playbook-blocks.sh — derive per-role ACE-style playbook digest blocks
# from tasks/lessons.md and splice them into their registered consumers
# (T-045, issue #116).
#
# For each IN role (engineer, qa-verifier, tech-lead, pm-spec):
#   1. Scan the lessons file for `Status: active`, `Scope: loop` entries whose
#      `Applies-to` includes that role (or `all`, which means all four IN
#      roles at once). Scope decides WHETHER an entry ships at all (T-1007);
#      Applies-to decides WHERE it ships. A `Scope: maintainer` entry never
#      reaches a generated block, whatever its Applies-to says.
#   2. Emit ONE line per qualifying entry, in file order: the entry's `Rule`
#      field verbatim, plus a date+heading pointer back into the lessons
#      file. `Why` / `How to apply` are NEVER transcribed (D2 in
#      docs/specs/T-045-ace-playbook.md) — the injected block is a digest,
#      not a substitute for reading the real entry.
#   3. Write the result to templates/prompt-blocks/playbook-<role>.md
#      (the canonical block — always overwritten, git-tracked).
#   4. Splice that same content into every consumer registered against
#      `playbook-<role>.md` in templates/prompt-blocks/registry.txt (mode
#      `marker`), rewriting ONLY the region between its
#      `<!-- BEGIN prompt-block: playbook-<role> -->` /
#      `<!-- END prompt-block: playbook-<role> -->` markers — same
#      marker-splice pattern as bin/gen-project-status.sh's generated block.
#
# bin/check-prompt-sync.sh (unchanged — T-039/T-040's check-only design) then
# verifies canonical block and consumer stay in sync; running THIS script
# again after a lessons-corpus edit is how you refresh that sync. CI's step
# named "Dogfood gen-playbook-blocks — regenerating into a scratch copy reproduces every shipped block and consumer" (T-1008)
# is exactly that freshness check, run for real: it regenerates into a
# scratch copy and diffs against the committed files, so this claim and the
# workflow cannot drift apart silently.
#
# Fail-closed re-validation (D3): before generating anything, this script
# runs bin/check-playbook.sh over the lessons file. A schema violation in ANY
# entry aborts the whole run non-zero WITHOUT touching any output file —
# never a silent per-entry skip (the "looks injected but silently isn't"
# failure mode this design refuses to allow).
#
# If a role's generated block grows past a line-count threshold, a
# non-fatal warning is printed to stderr (early warning against unbounded
# prompt growth — see D2). This never fails the run.
#
# Usage:
#   gen-playbook-blocks.sh [--root DIR] [--lessons PATH] [--blocks-dir DIR]
#
#   --root        repo root the registry's consumer paths resolve against
#                 (default: cwd)
#   --lessons     path to the lessons file (default: resolved against --root
#                 via `bin/team-paths.sh --get lessons`). The injected
#                 pointer text names whatever path is actually read here,
#                 never a hardcoded literal.
#   --blocks-dir  canonical blocks dir (default: <root>/templates/prompt-blocks)
#
# Exit: 0 = regenerated (possibly byte-identical to what was already there);
#       1 = the lessons file fails bin/check-playbook.sh (nothing written);
#       2 = usage / resolver / registry / marker-shape error.

set -euo pipefail

die()  { printf 'gen-playbook-blocks: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'gen-playbook-blocks: %s\n' "$1" >&2 || true; exit 1; }

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

ROOT="."
LESSONS=""
BLOCKS_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)       [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --lessons)    [ "$#" -ge 2 ] || die "--lessons requires a value"; shift; LESSONS="$1"; shift ;;
    --blocks-dir) [ "$#" -ge 2 ] || die "--blocks-dir requires a value"; shift; BLOCKS_DIR="$1"; shift ;;
    --help|-h)    sed -n '2,48p' "$script_path" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"
# The pointer text injected into every generated block (see pass 2 below)
# names the ACTUAL file read here, not a hardcoded literal — so a caller who
# passes a non-default --lessons PATH gets an accurate pointer instead of a
# misleading fixed-path reference.
if [ -n "$LESSONS" ]; then
  # --lessons short-circuits the resolver entirely (T-1006 DP-5): an
  # explicit path must keep working in a repository whose $TEAM_RUN_BASE is
  # invalid, so the resolver is never even invoked on this branch.
  POINTER_PATH="$LESSONS"
else
  # T-1006: the default is derived from bin/team-paths.sh rather than
  # hardcoded to the legacy layout. Capture-then-check (bin/team-init.sh's
  # precedent) — a nonzero exit is fail-closed, and so is an EMPTY resolved
  # path: unchecked, "$ROOT/" is a directory, for which `[ -r ]` below would
  # be true, letting generation proceed against nothing.
  resolved_lessons=""
  if ! resolved_lessons="$(bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get lessons 2>/dev/null)"; then
    die "could not resolve the lessons path"
  fi
  [ -n "$resolved_lessons" ] || die "could not resolve the lessons path"
  LESSONS="$ROOT/$resolved_lessons"
  POINTER_PATH="$resolved_lessons"
fi
# T-047 fast-follow AC3: POINTER_PATH (the --lessons PATH value) is spliced
# verbatim into every generated block's pointer text (see pass 2 below) —
# structurally check it BEFORE anything is written, same as every other
# value that reaches a generated block (control chars aside, this is the
# same marker-collision / embedded-newline class of check
# bin/check-playbook.sh's check_structural() already applies to field
# values). Threat model is narrow (a human-operator CLI argument, not
# tasks/lessons.md content), but an embedded newline or a reserved marker
# string here would corrupt the generated block's structure just the same.
case "$POINTER_PATH" in
  *$'\n'*) die "--lessons PATH must not contain an embedded newline (it is spliced into every generated block's pointer text)" ;;
esac
case "$POINTER_PATH" in
  *'<!-- BEGIN prompt-block:'*) die "--lessons PATH must not contain the reserved marker string '<!-- BEGIN prompt-block:'" ;;
esac
case "$POINTER_PATH" in
  *'<!-- END prompt-block:'*) die "--lessons PATH must not contain the reserved marker string '<!-- END prompt-block:'" ;;
esac
[ -n "$BLOCKS_DIR" ] || BLOCKS_DIR="$ROOT/templates/prompt-blocks"
REGISTRY="$BLOCKS_DIR/registry.txt"
[ -r "$LESSONS" ]  || die "lessons file not found: $LESSONS"
[ -d "$BLOCKS_DIR" ] || die "blocks dir not found: $BLOCKS_DIR"
[ -r "$REGISTRY" ]  || die "registry not found: $REGISTRY"

# Whole-file NUL-byte (0x00) scan — same check and same rationale as
# bin/check-playbook.sh's has_nul_byte(), duplicated here as defense-in-depth
# rather than trusted solely via the preflight call below (T-045 round2:
# Codex Major finding — bash `read` cannot preserve a NUL, so line-based
# parsing must never be reached at all once one is present).
has_nul_byte() {  # $1 = file; returns 0 (true) if it contains a NUL byte
  local orig stripped
  orig="$(wc -c < "$1")"
  stripped="$(tr -d '\000' < "$1" | wc -c)"
  [ "$orig" -ne "$stripped" ]
}

# Same fence grammar as bin/check-playbook.sh's fence_open_check() /
# fence_close_check() — kept in sync by hand (no shared library convention in
# this repo's bin/ scripts). See that script's header comment for the full
# confirmed grammar (T-045 rework4, replacing rework3's is_fence_marker()
# after round4 found two new Blockers + one Major in it).
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

if has_nul_byte "$LESSONS"; then
  fail "$LESSONS contains a NUL byte (0x00) — refusing to parse (fail-closed; see bin/check-playbook.sh's has_nul_byte comment)"
fi

# --- fail-closed preflight: the WHOLE lessons file must be schema-valid ------
if ! preflight_out="$(bash "$SCRIPT_DIR/check-playbook.sh" "$LESSONS" 2>&1)"; then
  printf '%s\n' "$preflight_out" >&2 || true
  fail "$LESSONS fails schema validation — refusing to generate (nothing written, see bin/check-playbook.sh above)"
fi

ROLES="engineer qa-verifier tech-lead pm-spec"
LINE_WARN_THRESHOLD=40

# Same trim as bin/check-playbook.sh's `trim()` — kept as a literal duplicate
# rather than a shared library (no cross-sourcing convention in this repo's
# bin/ scripts). bin/check-playbook.sh already TRIMS Status/Category before
# comparing them against their known-enum sets, so a value like
# `- **Status**: active ` (trailing space) passes validation as `active`.
# Every comparison against a field value in THIS script must use the same
# trimmed form, or a schema-valid entry could silently vanish from a
# generated block (T-045 rework: Codex round1 Major finding).
trim() {  # prints $1 with leading/trailing whitespace stripped
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

role_in_applies() {  # $1 = Applies-to value, $2 = role
  local applies="$1" role="$2" tok trimmed
  IFS=',' read -ra __tokens <<< "$applies"
  for tok in "${__tokens[@]}"; do
    trimmed="$(trim "$tok")"
    if [ "$trimmed" = "all" ] || [ "$trimmed" = "$role" ]; then
      return 0
    fi
  done
  return 1
}

# Same allow-list as bin/check-playbook.sh's ALLOWLISTED_HEADINGS — kept in
# sync by hand (no shared library convention in this repo's bin/ scripts).
ALLOWLISTED_HEADINGS=("## Format")
is_allowlisted_heading() {  # $1 = full heading line; returns 0 if allow-listed
  local line="$1" h
  for h in "${ALLOWLISTED_HEADINGS[@]}"; do
    [ "$line" = "$h" ] && return 0
  done
  return 1
}

# --- pass 1: parse the lessons file into one record per entry ---------------
# Records are delimited by ASCII Unit Separator (0x1F), NOT tab: the schema
# (bin/check-playbook.sh) explicitly allows a literal tab inside a field
# value (only non-tab control characters are rejected), so tab is not a safe
# field delimiter here. 0x1F is a non-tab control character that
# bin/check-playbook.sh's `check_structural` rejects in every field value AND
# in the heading's title/remainder text (T-045 rework: Codex round1 Major
# finding closed this gap — title used to be unchecked) — the preflight
# check-playbook.sh call above therefore guarantees no valid entry (fields OR
# heading) can contain one, so it is safe to split on unconditionally.
#
# Heading recognition mirrors bin/check-playbook.sh's 3-way classification
# (canonical entry / allow-listed section / fail-closed violation) — kept in
# sync by hand, not a shared library. The preflight above already guarantees
# every `## ` line in $LESSONS is either canonical or allow-listed, so this
# loop's own violation branch is an unreachable defensive backstop in normal
# operation — it exists so a future divergence between the two scripts'
# regexes fails LOUDLY here instead of silently misattributing content again
# (T-045 round2: Codex Major finding — a prior looser regex here let a
# malformed heading's fields merge into whatever entry was still open,
# injecting one entry's Rule under ANOTHER entry's tasks/lessons.md pointer).
FS=$'\x1f'
ENTRIES_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-playbook-entries.XXXXXX")"
# (cleanup trap for this file is set below, once CONTENT_FILES also exists)

{
  date=""; remainder=""; applies=""; scope=""; status=""; rule=""; have_entry=0
  in_fence=0
  fence_char=""
  fence_len=0
  # T-1007 hazard 1: emit_record()'s printf and the pass-2 `read -r` below
  # are two halves of one \x1f-delimited record contract — a field added to
  # one and not the other shifts every field after it, silently, into a
  # generated prompt. `scope` is inserted at a fixed position (after
  # `applies`, before `status`, mirroring the real file's field order) in
  # BOTH halves.
  emit_record() {
    [ "$have_entry" -eq 1 ] || return 0
    printf '%s%s%s%s%s%s%s%s%s%s%s\n' "$date" "$FS" "$remainder" "$FS" "$applies" "$FS" "$scope" "$FS" "$status" "$FS" "$rule"
  }
  while IFS= read -r rawline || [ -n "$rawline" ]; do
    line="${rawline%$'\r'}"

    # Confirmed fence grammar — see bin/check-playbook.sh's header comment
    # for the full rationale (T-045 rework4).
    if [ "$in_fence" -eq 0 ]; then
      open_rc=0
      fence_open_check "$line" || open_rc=$?
      if [ "$open_rc" -eq 0 ]; then
        if [ "$FENCE_OPEN_INVALID" -eq 1 ]; then
          fail "unexpected invalid fence opener survived the bin/check-playbook.sh preflight: '$line' — this should be impossible; the two scripts' fence logic have diverged"
        fi
        in_fence=1
        fence_char="$FENCE_CHAR"
        fence_len="$FENCE_LEN"
        continue
      elif [ "$open_rc" -eq 2 ]; then
        fail "unexpected ambiguous fence-like line survived the bin/check-playbook.sh preflight: '$line' — this should be impossible; the two scripts' fence logic have diverged"
      fi
      # open_rc == 1: not a fence-run line at all — fall through.
    else
      if fence_close_check "$line" "$fence_char" "$fence_len"; then
        in_fence=0
        fence_char=""
        fence_len=0
      fi
      continue
    fi

    if [[ "$line" =~ ^\#\#\  ]]; then
      if [[ "$line" =~ ^\#\#\ ([0-9]{4}-[0-9]{2}-[0-9]{2})\ —\ (.+)$ ]]; then
        emit_record
        date="${BASH_REMATCH[1]}"; remainder="${BASH_REMATCH[2]}"
        applies=""; scope=""; status=""; rule=""; have_entry=1
      elif is_allowlisted_heading "$line"; then
        emit_record
        have_entry=0
      else
        emit_record
        have_entry=0
        fail "unexpected non-canonical heading survived the bin/check-playbook.sh preflight: '$line' — this should be impossible; the two scripts' heading regexes have diverged"
      fi
      continue
    fi

    [ "$have_entry" -eq 1 ] || continue
    if [[ "$line" =~ ^-\ \*\*Applies-to\*\*:\ (.*)$ ]]; then
      applies="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-\ \*\*Scope\*\*:\ (.*)$ ]]; then
      scope="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-\ \*\*Status\*\*:\ (.*)$ ]]; then
      status="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^-\ \*\*Rule\*\*:\ (.*)$ ]]; then
      rule="${BASH_REMATCH[1]}"
    fi
  done < "$LESSONS"

  # EOF reached while still inside a fence — same defensive backstop as
  # bin/check-playbook.sh's EOF check (the preflight above should already
  # have refused this file for the same reason; reaching here anyway means
  # the two scripts' fence logic has diverged, which must fail loudly rather
  # than silently drop the rest of the file).
  if [ "$in_fence" -eq 1 ]; then
    fail "unexpected unterminated fence (opened with a run of ${fence_len} '${fence_char}' characters) survived the bin/check-playbook.sh preflight — this should be impossible; the two scripts' fence logic have diverged"
  fi

  emit_record
} > "$ENTRIES_FILE"

# --- marker-region helpers ---------------------------------------------------
# Two separate steps (validate, then write) so that a marker-shape problem in
# ANY registered consumer is caught before ANY file is written — a config
# error must not leave some roles regenerated and others not (same
# fail-closed spirit as the schema preflight above, applied to the
# marker-splice side of the job).
consumers_of() {  # $1 = block name (no .md); prints one consumer path per line
  awk -v bf="$1.md" '
    $1 == "marker" && $2 == bf { for (i = 3; i <= NF; i++) print $i }
  ' "$REGISTRY"
}

validate_marker_shape() {  # $1 = consumer path, $2 = block name (no .md)
  local consumer="$1" name="$2"
  local begin_mark="<!-- BEGIN prompt-block: $name -->"
  local end_mark="<!-- END prompt-block: $name -->"
  [ -r "$consumer" ] || die "registered consumer not found: $consumer"

  local begin_count end_count
  begin_count="$(awk -v m="$begin_mark" '{ sub(/\r$/, "") } $0 == m { n++ } END { print n + 0 }' "$consumer")"
  end_count="$(awk -v m="$end_mark" '{ sub(/\r$/, "") } $0 == m { n++ } END { print n + 0 }' "$consumer")"
  if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
    die "$consumer: expected exactly one $name marker pair (got BEGIN=$begin_count END=$end_count)"
  fi
  local begin_ln end_ln
  begin_ln="$(awk -v m="$begin_mark" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$consumer")"
  end_ln="$(awk -v m="$end_mark" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$consumer")"
  [ "$begin_ln" -lt "$end_ln" ] || die "$consumer: $name BEGIN marker must precede END marker"
}

# Splices content_file between an already-validated marker pair. Mirrors
# bin/gen-project-status.sh's marker splice (keeps everything outside the two
# marker lines byte-untouched).
#
# T-047 fast-follow AC2: this used to pipe the WHOLE consumer file through
# awk's `print`, which re-serializes every line with awk's own `ORS` (a bare
# "\n") regardless of the source file's own line-ending shape and regardless
# of whether the file's LAST line originally had a trailing newline at all —
# silently rewriting bytes OUTSIDE the marker pair for a CRLF-terminated
# consumer or one missing a final trailing newline, in violation of D3's
# "marker外はbyte-untouched" contract (docs/specs/T-045-ace-playbook.md).
# `head -n`/`tail -n` instead copy bytes verbatim up to/from a given line
# number — they never reformat a line ending or add a terminator that wasn't
# already there, so the prefix (through the BEGIN marker line, inclusive) and
# the suffix (from the END marker line onward) are reproduced byte-for-byte,
# whatever their original shape. Only the marker-INTERNAL region (between
# them) is replaced by content_file, which is expected to always be
# regenerated in this generator's own canonical LF form — that is the part
# of the contract this script is responsible for keeping fresh.
write_marker() {  # $1 = consumer path, $2 = block name (no .md), $3 = content file
  local consumer="$1" name="$2" content_file="$3"
  local begin_mark="<!-- BEGIN prompt-block: $name -->"
  local end_mark="<!-- END prompt-block: $name -->"
  local begin_ln end_ln
  begin_ln="$(awk -v m="$begin_mark" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$consumer")"
  end_ln="$(awk -v m="$end_mark" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$consumer")"

  local tmp_out
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/gen-playbook-splice.XXXXXX")"
  head -n "$begin_ln" "$consumer" > "$tmp_out"
  cat "$content_file" >> "$tmp_out"
  tail -n "+$end_ln" "$consumer" >> "$tmp_out"
  cat "$tmp_out" > "$consumer"
  rm -f "$tmp_out"
}

# --- pass 2: build each role's content into a temp file ----------------------
# shellcheck disable=SC2206  # ROLES is a fixed, simple space-separated word list
ROLES_ARR=($ROLES)
CONTENT_FILES=()
trap 'rm -f "${CONTENT_FILES[@]}" "$ENTRIES_FILE" 2>/dev/null || true' EXIT

for role in "${ROLES_ARR[@]}"; do
  CONTENT_FILE="$(mktemp "${TMPDIR:-/tmp}/gen-playbook-content.XXXXXX")"
  CONTENT_FILES+=("$CONTENT_FILE")

  {
    printf '## Lessons playbook\n'
    printf '\n'
    line_count=2
    any=0
    while IFS="$FS" read -r e_date e_remainder e_applies e_scope e_status e_rule; do
      [ "$(trim "$e_status")" = "active" ] || continue
      # T-1007: Scope decides WHETHER an entry ships; Applies-to decides
      # WHERE. Only a Scope: loop entry ever reaches a generated block — a
      # maintainer entry never does, whatever its Applies-to says (the
      # preflight bin/check-playbook.sh call above already guarantees Scope
      # is present and one of the two known tokens).
      [ "$(trim "$e_scope")" = "loop" ] || continue
      role_in_applies "$e_applies" "$role" || continue
      # $e_remainder no longer carries the "— " separator itself (the
      # canonical heading regex above now consumes the em-dash as a literal
      # part of the match, not as part of the captured title group) — put it
      # back explicitly so the pointer text is unchanged: "DATE — TITLE".
      printf -- '- %s (%s, %s — %s)\n' "$e_rule" "$POINTER_PATH" "$e_date" "$e_remainder"
      any=1
      line_count=$((line_count + 1))
    done < "$ENTRIES_FILE"
    if [ "$any" -eq 0 ]; then
      printf -- '- (no active entries currently apply to this role)\n'
      line_count=$((line_count + 1))
    fi
    if [ "$line_count" -gt "$LINE_WARN_THRESHOLD" ]; then
      printf 'gen-playbook-blocks: warning: playbook-%s.md is %d lines (threshold %d) — do not launch a supersede sweep on this signal alone; the judgment inputs are recorded in the shell-team repository at docs/loop-engineering/playbook-block-size-deferral.md\n' \
        "$role" "$line_count" "$LINE_WARN_THRESHOLD" >&2
    fi
  } > "$CONTENT_FILE"
done

# --- pass 3: validate EVERY registered consumer's marker shape up front ------
# Nothing is written until every consumer of every playbook-<role>.md block
# has been confirmed to have a well-formed marker pair. (Plain temp-file-free
# capture + here-string, NOT process substitution: /dev/fd is blocked in some
# sandboxed environments where this generator must still run.)
for role in "${ROLES_ARR[@]}"; do
  consumers="$(consumers_of "playbook-$role")"
  if [ -n "$consumers" ]; then
    while IFS= read -r consumer; do
      [ -n "$consumer" ] || continue
      validate_marker_shape "$ROOT/$consumer" "playbook-$role"
    done <<< "$consumers"
  fi
done

# --- pass 4: everything validated — write the canonical blocks + splice -----
idx=0
for role in "${ROLES_ARR[@]}"; do
  block_file="$BLOCKS_DIR/playbook-$role.md"
  CONTENT_FILE="${CONTENT_FILES[$idx]}"
  cat "$CONTENT_FILE" > "$block_file"

  consumers="$(consumers_of "playbook-$role")"
  if [ -n "$consumers" ]; then
    while IFS= read -r consumer; do
      [ -n "$consumer" ] || continue
      write_marker "$ROOT/$consumer" "playbook-$role" "$CONTENT_FILE"
    done <<< "$consumers"
  fi

  printf 'gen-playbook-blocks: regenerated %s\n' "$block_file"
  idx=$((idx + 1))
done

exit 0
