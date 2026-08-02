#!/usr/bin/env bash
# check-intent.sh — verify a spec's FROZEN intent block against the board's
# recorded intent-hash / intent-ratified ledger (T-071, v0.3.0 Phase A Seam A;
# docs/specs/T-071-frozen-intent.md).
#
# Design note `v0.3.0-oversight-model-evolution.md` §6.1 fixed drift to be
# measured against a task's FROZEN intent, never against the current spec —
# a spec that has silently drifted with the code can no longer expose the
# drift it caused. This checker is the machine half of that discipline:
#
#   1. structural  — the spec carries EXACTLY ONE task-id-scoped marker pair
#        <!-- BEGIN intent-block: T-NNN --> ... <!-- END intent-block: T-NNN -->
#      (BEGIN strictly before END), and the board carries EXACTLY ONE
#      well-formed `- intent-hash (vN): <40-hex>` sub-bullet under that
#      task's own top-level entry, plus well-formed
#      `- intent-ratified (YYYY-MM-DD): vK→vK+1 — <human GO> — <reason>`
#      sub-bullets (grammar only). Any violation => exit 2 (usage/structural).
#   2. version-chain — the ratification records must form an unbroken chain
#      v1->v2->...->vN (exactly N-1 records, no gaps/dupes/out-of-range/
#      reversal; v1 needs none). Broken chain => exit 1 (drift-detected).
#   3. hash-match — `git hash-object` of the marker region's NORMALIZED bytes
#      (CR stripped, trailing whitespace stripped per line, leading/trailing
#      blank lines dropped — identical to check-prompt-sync.sh's
#      normalize_stdin) must equal the board's recorded vN hash. Mismatch =>
#      exit 1 (drift-detected).
#   4. all pass => exit 0 (aligned).
#
# This checker judges BYTES + LEDGER BOOKKEEPING ONLY. Whether the delivered
# behavior still matches the intent's MEANING is never judged here — that is
# S4 (drift/alignment evaluator), explicitly out of scope (spec DP4).
#
# Marker matching is an EXACT full-line compare (never a substring/grep -F
# search): a marker literal quoted mid-sentence in prose (this repo's own
# T-071 spec quotes its real marker inside a Notes-for-engineer sentence) is
# never miscounted as a second marker pair. Board records are likewise
# recognized only when the FULL line (after leading whitespace) matches the
# structured `- intent-hash (vN): ...` / `- intent-ratified (...): ...`
# shape — a prose sub-bullet that merely quotes those words mid-sentence
# (e.g. this repo's own board `freeze (dogfood):` note) is never miscounted
# as a record (2026-07-17 self-referential dogfooding lesson).
#
# Ledger tamper-evidence (first-seen-wins history-walk detection of a
# same-version, unratified board-hash overwrite) was implemented for T-071
# rework3/rework4 and carved back OUT in rework5 (2026-07-18) after 5
# independent defects across rounds 3-5 concentrated in that one subsystem,
# per the user's pre-committed Option B disposition (round2-round4's judgments
# 1-3 stayed defect-free across all 4 rounds). It ships instead as an
# independent fast-follow issue — see docs/specs/T-071-frozen-intent.md's
# "ledger tamper-evidence の正典（判定 4）— tombstone" section and
# tasks/reviews/T-071.md Rounds 3-5 for the carried-forward design material
# (first-seen-wins invariant, boundary conditions, trust boundary). This
# checker therefore does NOT detect a same-version board-hash overwrite that
# leaves version-chain and hash-match both satisfied — a documented, honest
# limitation (spec DP3 trust boundary), covered in Phase A by human GO + PR
# diff review, the same way bin/check-acs.sh's own TRUST BOUNDARY documents
# that a standalone checker cannot fully harden against a tampered history.
#
# Usage:
#   check-intent.sh [--] <spec.md> <board.md>
#
# Exit: 0 = aligned; 1 = drift-detected (hash mismatch or broken version
#       chain); 2 = usage / structural error (bad args, unreadable files,
#       missing/duplicated/reversed markers, missing/duplicated/malformed
#       board records).

set -euo pipefail

# --- classified failure helpers ---------------------------------------------
# Every rejection path prints a classification token to stderr so a caller
# (or this checker's own fixture suite) can distinguish usage/structural
# errors from a genuine drift finding without parsing prose. Defined FIRST,
# before anything else (including the symlink-resolution bootstrap directly
# below) — every external-command / pipeline / redirect-write / read failure
# in this script, from the very first line onward, must have a classified
# exit path available (T-071 rework2 "fail-closed の全数 inventory 要求"; see
# the inventory table in the T-071 engineer hand-off).
die() {  # $1 = classification (usage|structural), $2 = message; exit 2
  printf 'check-intent: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
fail_drift() {  # $1 = message; exit 1
  printf 'check-intent: drift-detected: %s\n' "$1" >&2 || true
  exit 1
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported from bin/log-run.sh L51-59 (2026-07-14 lesson: reuse the proven
# resolver instead of hand-rolling one). This checker has no sibling script
# to call; SELF is used only to source --help's text from this file's own
# header comment. Every external command in this bootstrap (readlink / cd /
# pwd / basename) is guarded — a failure here (e.g. a broken symlink chain or
# an inaccessible directory) falls closed as a classified usage(2) error
# instead of a bare, untokened `set -e` exit.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      # `dirname` and `cd ... && pwd` are guarded INDEPENDENTLY (ported from
      # bin/check-provenance.sh's T-074 rework1 fix, #233 item 5): a single
      # combined `cd`+`dirname`+`pwd` command substitution, guarded with one
      # trailing `|| fail_usage`, only observes the OUTER `cd && pwd`
      # pipeline's exit status — if `dirname` itself fails (e.g. a PATH with
      # no `dirname` binary at all), bash's command substitution yields an
      # EMPTY string, and `cd ""` silently succeeds as `cd .` (the current
      # directory), so the `||` never fires and link_dir quietly becomes
      # `$PWD` instead of failing closed. Splitting the two substitutions
      # gives `dirname`'s own failure its own classified exit path.
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
  sed -n '2,64p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing (positional; -- ends option parsing) ------------------
SPEC=""
BOARD=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  break ;;
  esac
done

if [ "$#" -ge 1 ]; then SPEC="$1"; shift; fi
if [ "$#" -ge 1 ]; then BOARD="$1"; shift; fi
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$SPEC" ]  || fail_usage "missing required <spec.md> (usage: check-intent.sh <spec.md> <board.md>)"
[ -n "$BOARD" ] || fail_usage "missing required <board.md> (usage: check-intent.sh <spec.md> <board.md>)"
# Type + readability validation happens HERE, before either read loop below
# is ever reached (T-071 rework2 "引数の型・健全性検証"). A directory or FIFO
# is rejected as usage(2) rather than being handed to a `while read` loop —
# which would otherwise either raw-exit on a directory (spec argument) or
# spin forever re-reading the same "Is a directory" error (board argument,
# a CI-hanging failure mode). `-f` (regular file) is checked before `-r`
# (readable) so a directory is classified by its TYPE, not its permissions.
[ -f "$SPEC" ]  || fail_usage "spec path is not a regular file (directories/FIFOs/etc. are rejected): $SPEC"
[ -r "$SPEC" ]  || fail_usage "cannot read spec file: $SPEC"
[ -f "$BOARD" ] || fail_usage "board path is not a regular file (directories/FIFOs/etc. are rejected): $BOARD"
[ -r "$BOARD" ] || fail_usage "cannot read board file: $BOARD"

# --- normalization: identical to check-prompt-sync.sh's normalize_stdin ----
normalize_stdin() {
  sed -e 's/\r$//' -e 's/[[:space:]]*$//' | awk '
    { lines[NR] = $0; if ($0 != "") { if (first == 0) first = NR; last = NR } }
    END { for (i = first; i <= last && first > 0; i++) print lines[i] }
  '
}

# Marker lines: EXACT full-line compare (after stripping a trailing CR) via
# awk, not grep -F — a substring search would miscount a marker literal
# quoted mid-sentence in prose as a real marker occurrence.
marker_count() { awk -v m="$1" '{ sub(/\r$/, "") } $0 == m { n++ } END { print n + 0 }' "$2"; }
marker_line()  { awk -v m="$1" '{ sub(/\r$/, "") } $0 == m { print NR; exit }' "$2"; }

# --- 1. derive the task-id from the spec's own **Task ID**: T-NNN line -----
# Anchored at the line's END (T-071 rework4-C minor, Codex round4): without
# `[[:space:]]*$`, a malformed metadata line such as
# `**Task ID**: T-900junk-trailing-garbage` would silently derive T-900
# instead of failing closed as a structural error.
# shellcheck disable=SC2016
TASK_ID_RE='^\*\*Task ID\*\*: *(T-[0-9]+)[[:space:]]*$'
TASK_ID=""
while IFS= read -r raw || [ -n "$raw" ]; do
  l="${raw%$'\r'}"
  if [[ "$l" =~ $TASK_ID_RE ]]; then
    TASK_ID="${BASH_REMATCH[1]}"
    break
  fi
done < "$SPEC"
[ -n "$TASK_ID" ] || fail_structural "no '**Task ID**: T-NNN' line found in spec: $SPEC"

# --- 2. marker structural checks --------------------------------------------
BEGIN_MARK="<!-- BEGIN intent-block: ${TASK_ID} -->"
END_MARK="<!-- END intent-block: ${TASK_ID} -->"

begin_count="$(marker_count "$BEGIN_MARK" "$SPEC")" \
  || fail_usage "awk failed while counting BEGIN intent-block markers in $SPEC"
end_count="$(marker_count "$END_MARK" "$SPEC")" \
  || fail_usage "awk failed while counting END intent-block markers in $SPEC"
if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
  fail_structural "expected exactly one intent-block marker pair for $TASK_ID in $SPEC (got BEGIN=$begin_count END=$end_count)"
fi

begin_ln="$(marker_line "$BEGIN_MARK" "$SPEC")" \
  || fail_usage "awk failed while locating the BEGIN intent-block marker line in $SPEC"
end_ln="$(marker_line "$END_MARK" "$SPEC")" \
  || fail_usage "awk failed while locating the END intent-block marker line in $SPEC"
if [ "$begin_ln" -ge "$end_ln" ]; then
  fail_structural "BEGIN intent-block marker (line $begin_ln) must precede END marker (line $end_ln) in $SPEC"
fi

# --- 3. extract + normalize + hash the intent block (marker lines excluded) -
tmp_region="$(mktemp "${TMPDIR:-/tmp}/check-intent-region.XXXXXX")" \
  || fail_usage "mktemp failed to create a temp file for extracting the intent block (check that TMPDIR=${TMPDIR:-/tmp} is writable)"
trap 'rm -f "$tmp_region"' EXIT
# The extraction pipeline's WRITE (not just mktemp's earlier file creation)
# must be fail-closed too: a write failure here (disk full, `ulimit -f`
# quota, or a failure inside normalize_stdin's own sed/awk) would otherwise
# surface as a bare, untokened `set -e`/`pipefail` exit (e.g. 128+SIGXFSZ)
# instead of a classified one (T-071 rework2 Major, Codex round2 — round1
# only guarded mktemp's file CREATION and missed this sibling write path).
# `pipefail` (set at the top of this script) makes the pipeline's own exit
# status reflect ANY failing stage, so a single trailing `||` here suffices.
awk -v b="$begin_ln" -v e="$end_ln" 'NR > b && NR < e' "$SPEC" | normalize_stdin > "$tmp_region" \
  || fail_usage "failed to extract+normalize the intent block from $SPEC into a temp file (possible causes: disk full, a file-size quota such as ulimit -f, or an awk/sed failure in the extraction pipeline)"
computed_hash="$(git hash-object --stdin < "$tmp_region")" \
  || fail_usage "git hash-object failed while hashing the intent block extracted from $SPEC"

# --- 4. board: locate the task's own top-level entry and its records -------
# shellcheck disable=SC2016
TOP_RE='^- \[[ xX]\] \*\*(T-[0-9]+)\*\*'
HASH_LINE_RE='^[[:space:]]+- intent-hash'
# shellcheck disable=SC2016
HASH_FULL_RE='^[[:space:]]+- intent-hash \(v([0-9]+)\): ([0-9a-f]{40})$'
RATIFIED_LINE_RE='^[[:space:]]+- intent-ratified'
# shellcheck disable=SC2016
RATIFIED_FULL_RE='^[[:space:]]+- intent-ratified \([0-9]{4}-[0-9]{2}-[0-9]{2}\): v([0-9]+)→v([0-9]+) — .+ — .+$'

# Board parser state machine (T-071 rework3 canonical, re-grounded for T-1016
# D2 — spec "## 形式文法 / 状態機械" § "board パース状態機械の正典（rework3
# — 反転定義）"; T-1016's "## Settled decisions" D2 for the blank-line
# change below). Round1 Major, round2 Blocker/Major, and round3 Blocker were
# FOUR independent defects in a row from *enumerating* which line shapes
# close a scope (round2's canonical only listed `## ` headings and
# non-indented "- " lines as boundaries, so a CommonMark-legal `* [ ]`/
# `+ [ ]` bullet — or any other non-"- " non-indented line — fell through as
# a no-op and let a neighboring task's real hash leak into an empty scope).
# Rework3 INVERTS the definition instead of patching another shape onto the
# enumeration; T-1016 D2 additionally makes a blank line NEUTRAL rather than
# a scope terminator, so this checker's ledger and bin/close-out.sh's mover
# agree about what belongs to an entry — board-entry continuation canon (T-1016):
#   Rule 1 — an INDENTED, non-blank line (`^[[:space:]]+[^[:space:]]`, i.e.
#     leading whitespace followed by a non-whitespace character) is the
#     ONLY thing that ever keeps a scope open: in_entry is left untouched.
#     While inside this task's own open scope (in_entry==1), such a line is
#     matched as a structured sub-bullet (HASH_LINE_RE / RATIFIED_LINE_RE,
#     themselves anchored on leading whitespace); otherwise it is a no-op.
#   Rule 1b (T-1016 D2) — a BLANK line (only whitespace, or truly empty) is
#     NEUTRAL: it is neither a continuation nor a boundary, and leaves
#     in_entry untouched, exactly like a non-matching indented line under
#     rule 1. This is the one behavioral change from rework3: previously a
#     blank line fell through to rule 2/3 and unconditionally closed the
#     scope; that is no longer true, so a task's `- intent-hash` /
#     `- intent-ratified` sub-bullets remain in scope even when separated by
#     a blank line from the task line or from each other.
#   Rule 2/3 — EVERY remaining line, with NO exceptions: any non-indented,
#     non-blank line, regardless of bullet form ("- "/"* "/"+ "/numbered/
#     anything else) or heading level (`^#`, any level), and any bare prose
#     — unconditionally closes any open scope FIRST (in_entry=0). Only THEN,
#     if the SAME line also matches TOP_RE with this task's own bold
#     task-id captured (an EXACT capture-group compare against $TASK_ID,
#     never a substring search against the whole line — a substring search
#     would wrongly pull in another task's entry whose TITLE merely
#     cross-references this task-id in bold prose, e.g. "- [ ] **T-800**
#     ... see also **T-900** ..."; Codex round1 MAJOR), is a NEW scope
#     opened for this entry (in_entry=1) and entry_count incremented.
# Scope END (rule 2/3 + EOF): once opened, a scope closes at the FIRST of
# (a) ANY non-indented, non-blank line at all (TOP_RE match or not, any
# bullet shape or none), or (b) EOF — a blank line no longer closes it
# (rule 1b) — so neither a duplicate/stale top-level entry, nor a malformed
# non-TOP_RE top-level-looking line, nor a `* `/`+ ` CommonMark-legal bullet
# (round3 Blocker, the same class's fourth independent defect) can ever let
# scope leak past it.
#
# shellcheck disable=SC2016
INDENT_NONBLANK_RE='^[[:space:]]+[^[:space:]]'
# shellcheck disable=SC2016
BLANK_LINE_RE='^[[:space:]]*$'

# extract_task_records TASK_ID < board-content  (T-071 rework4 "共有抽出関数
# の義務" — the single shared implementation of the state machine above).
# This board-parsing while loop exists EXACTLY ONCE in this entire script.
# Round1 Major, round2 Blocker/Major, and round3 Blocker were four
# independent "board scope boundary" defects fixed by refining THIS parser.
# Rework4 additionally factored a second, ad hoc mini-parser (the
# now-removed ledger-tamper-evidence history walk's own board-content
# scanner, which applied no task-id scoping at all) into calling this SAME
# function instead of duplicating parsing logic — that consumer was carved
# out again in rework5 (see the tombstone note in this file's header
# comment), so this function now has exactly ONE call site (the live board,
# judgment 2/3, immediately below). It is kept as a named function rather
# than inlined so a future consumer (e.g. the tamper-evidence fast-follow)
# can reuse it instead of writing a second parser — the single-parser
# structure itself, not merely its former multi-consumer use, is the
# rounds1-4 asset being preserved here.
#
# Sets the following as GLOBALS (bash functions have no true multi-value
# return, and every call site reads these immediately, before the next call
# overwrites them — see the T-071 rework4 hand-off for why this is safe):
#   entry_count                          — this task's own top-level entries
#   hash_valid_count / hash_bad_count    — well-formed / malformed
#                                          intent-hash sub-bullets in scope
#   hash_version / hash_value            — from the last well-formed
#                                          intent-hash sub-bullet seen
#                                          (only trust these once
#                                          hash_valid_count == 1)
#   ratified_bad_count                   — malformed intent-ratified
#                                          sub-bullets in scope
#   ratified_from[] / ratified_to[]      — vK / vK+1 pairs from well-formed
#                                          intent-ratified sub-bullets, in
#                                          the order encountered
extract_task_records() {
  local task_id="$1"
  in_entry=0
  entry_count=0
  hash_valid_count=0
  hash_bad_count=0
  hash_version=""
  hash_value=""
  ratified_bad_count=0
  ratified_from=()
  ratified_to=()

  while true; do
    if IFS= read -r raw; then
      read_rc=0
    else
      read_rc=$?
      # bash's `read` cannot distinguish true EOF from a genuine non-EOF read
      # failure (e.g. reading a directory) by exit code alone — both return
      # 1 (confirmed: `bash -c 'read -r x < /some-directory'` also returns
      # rc=1). A prior branch here (T-071 rework3-C) tried to treat
      # `read_rc > 1` as a distinct non-EOF failure, but that branch was
      # unreachable dead code: `-f` (regular-file) validation on every real
      # file this function is ever called against (upstream, before either
      # call site below) already makes a directory-read failure structurally
      # impossible here, and the exit code can't tell the two apart even if
      # it weren't. Removed rather than left in place as unreachable
      # (T-071 rework4-C minor, Codex round4).
      if [ -z "$raw" ]; then
        break
      fi
      # Fall through: EOF was reached but a trailing line without a newline
      # was still captured in $raw — process it once more, then stop below.
    fi

    line="${raw%$'\r'}"

    # Rule 1 (rework3-A canonical inversion): an INDENTED, non-blank line is
    # the ONLY thing that keeps a scope open; in_entry is left untouched.
    if [[ "$line" =~ $INDENT_NONBLANK_RE ]]; then
      if [ "$in_entry" -eq 1 ]; then
        if [[ "$line" =~ $HASH_LINE_RE ]]; then
          if [[ "$line" =~ $HASH_FULL_RE ]]; then
            hash_valid_count=$((hash_valid_count + 1))
            hash_version="${BASH_REMATCH[1]}"
            hash_value="${BASH_REMATCH[2]}"
          else
            hash_bad_count=$((hash_bad_count + 1))
          fi
        fi

        if [[ "$line" =~ $RATIFIED_LINE_RE ]]; then
          if [[ "$line" =~ $RATIFIED_FULL_RE ]]; then
            ratified_from+=("${BASH_REMATCH[1]}")
            ratified_to+=("${BASH_REMATCH[2]}")
          else
            ratified_bad_count=$((ratified_bad_count + 1))
          fi
        fi
      fi
    elif [[ "$line" =~ $BLANK_LINE_RE ]]; then
      # Rule 1b (T-1016 D2): a blank line is NEUTRAL — it leaves in_entry
      # untouched, exactly like a non-matching indented line under rule 1.
      # This is the only behavioral change from rework3: a blank line no
      # longer closes an open scope.
      :
    else
      # Rule 2/3 (rework3-A canonical inversion): EVERY remaining line — any
      # non-indented, non-blank line regardless of bullet form ("- "/"* "/
      # "+ "/numbered/other), any heading, any bare prose — unconditionally
      # closes any open scope first. Only THEN, if the SAME line also
      # matches TOP_RE with this task's own bold task-id captured (an exact
      # capture-group compare, never a substring search against the whole
      # line), is a NEW scope opened.
      in_entry=0
      if [[ "$line" =~ $TOP_RE ]] && [[ "${BASH_REMATCH[1]}" == "$task_id" ]]; then
        in_entry=1
        entry_count=$((entry_count + 1))
      fi
    fi

    if [ "$read_rc" -ne 0 ]; then
      break
    fi
  done
}

extract_task_records "$TASK_ID" < "$BOARD"

# Uniqueness requirement (T-071 rework2 — the structural root-cause fix for
# Codex round2's Blocker): entry_count must be EXACTLY 1. Zero means the task
# has no record at all; two-or-more means a duplicate top-level entry (e.g. a
# stale leftover in `## Done` alongside the real entry in `## Active`) would
# otherwise merge both entries' sub-bullets into one scope and let a stale
# entry's hash produce a false aligned(0) for a real entry with no record of
# its own. Both directions fail closed as structural(2), never drift(1).
if [ "$entry_count" -eq 0 ]; then
  fail_structural "no top-level board entry for $TASK_ID found in $BOARD"
elif [ "$entry_count" -ge 2 ]; then
  fail_structural "found $entry_count top-level board entries for $TASK_ID in $BOARD (expected exactly one; remove the stale/duplicate entry — e.g. a leftover in ## Done alongside the real entry in ## Active)"
fi
[ "$ratified_bad_count" -eq 0 ] \
  || fail_structural "$ratified_bad_count malformed intent-ratified record(s) for $TASK_ID in $BOARD (expected '- intent-ratified (YYYY-MM-DD): vK→vK+1 — <human GO> — <reason>')"
if [ "$hash_valid_count" -ne 1 ] || [ "$hash_bad_count" -ne 0 ]; then
  fail_structural "expected exactly one well-formed intent-hash record for $TASK_ID in $BOARD (found valid=$hash_valid_count malformed=$hash_bad_count; expected '- intent-hash (vN): <40-hex>')"
fi

# --- 5. version-chain integrity (a broken ledger is drift, not structural) --
version_int=$((10#$hash_version))
[ "$version_int" -ge 1 ] \
  || fail_structural "invalid intent-hash version v$hash_version for $TASK_ID in $BOARD (versions start at v1)"

expected_ratified=$((version_int - 1))
actual_ratified="${#ratified_from[@]}"
if [ "$actual_ratified" -ne "$expected_ratified" ]; then
  fail_drift "version-chain count mismatch for $TASK_ID: board declares v$hash_version but $BOARD carries $actual_ratified intent-ratified record(s) (expected $expected_ratified)"
fi

k=1
while [ "$k" -le "$expected_ratified" ]; do
  target_to=$((k + 1))
  found=0
  idx=0
  while [ "$idx" -lt "$actual_ratified" ]; do
    if [ "${ratified_from[$idx]}" -eq "$k" ] && [ "${ratified_to[$idx]}" -eq "$target_to" ]; then
      found=$((found + 1))
    fi
    idx=$((idx + 1))
  done
  if [ "$found" -ne 1 ]; then
    fail_drift "version-chain broken for $TASK_ID: expected exactly one intent-ratified record v${k}→v${target_to}, found $found in $BOARD"
  fi
  k=$((k + 1))
done

# --- 6. hash-match ------------------------------------------------------------
if [ "$hash_value" != "$computed_hash" ]; then
  fail_drift "intent-hash mismatch for $TASK_ID: board records v$hash_version=$hash_value but the current intent block in $SPEC normalizes+hashes to $computed_hash"
fi

# Ledger tamper-evidence (judgment 4 — first-seen-wins history walk over the
# board file's own git log, detecting a same-version unratified overwrite of
# the recorded hash) was implemented here for T-071 rework3/rework4 and
# carved back OUT again in rework5 (2026-07-18) after 5 independent defects
# across rounds 3-5, all confined to that one subsystem, per the user's
# pre-committed Option B disposition (see this file's header comment and
# docs/specs/T-071-frozen-intent.md's "ledger tamper-evidence の正典（判定
# 4）— tombstone" section). Judgments 1-3 above are unaffected and stayed
# defect-free across all 4 review rounds; the checker now stops at
# hash-match (judgment 3) and reports aligned.

# T-071 rework3-C minor: guard the success-path final print against SIGPIPE
# (e.g. piped through `| head`) so a closed downstream pipe can never turn
# an already-decided `aligned` outcome into an unclassified exit 141 — the
# exit code below is unconditionally 0 regardless of this printf's result.
printf 'check-intent: aligned: %s v%s (%s) matches %s\n' "$TASK_ID" "$hash_version" "$computed_hash" "$SPEC" || true
exit 0
