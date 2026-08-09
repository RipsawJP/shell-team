#!/usr/bin/env bash
# check-refreeze-class.sh — classify whether an intent-block delta between two
# spec files is confined to `- check:` lines (a machine-checkable "mechanics
# repair") or touches anything else (a "class-B" delta: Goal / Non-goals /
# criterion prose / Input space), for the delegable class-M re-freeze path
# (T-1028; GitHub issue #47; docs/tuning-oversight.md's "Who may re-freeze a
# frozen intent block" section; CONTRIBUTING.md's "Re-freezing a frozen
# intent block" section).
#
# This script is a SIBLING of bin/check-intent.sh's ledger, not a mode on it
# (T-1028 D1) — bin/check-intent.sh is not touched, not one byte. It shares
# check-intent.sh's normalization, its exact full-line marker matching, and
# its `- check:` counting regex `^[[:space:]]+- check:` (T-1028 AC5: one
# definition, checked in both scripts), because two independently-drifting
# definitions of "what counts as a check line" would silently break the
# guarantee this classifier exists to give.
#
# The old (pre-edit) intent-block region is supplied by the CALLER as a file
# path — this classifier never walks board or git history to find it (the
# rework5 tombstone in bin/check-intent.sh's own header comment: "never
# reintroduces a board-git-history walk, in any form, for any judgment" — the
# same reasoning binds this sibling checker). The ONLY git subcommand this
# script ever invokes is `git hash-object`; it never runs `git log` or
# `git show` to reconstruct history — reconstructing the old side from
# history is exactly what this design refuses (T-1028 D1, Non-goals).
#
# Mechanics rule (T-1028 D3), positional and strict: two NORMALIZED intent
# blocks classify as `mechanics` when (i) they have the SAME line count, (ii)
# at least one line differs, and (iii) at EVERY differing index BOTH lines
# match `^[[:space:]]+- check:`. Any insertion or deletion shifts positions
# and fails (i) (=> class-b). Any prose change at a differing index fails
# (iii) (=> class-b). Two blocks byte-identical after normalization are
# `structural`, never a pass — a re-freeze that changes nothing is a
# bookkeeping error, not a legitimate mechanics repair.
#
# Known, PINNED blind spot (test case `crc-blindspot-swapped-checks`,
# disclosed here and in docs/tuning-oversight.md / docs/tuning-oversight.ja.md
# per T-1028 D3/AC8): a pure SWAP of two `- check:` lines between two
# different criteria classifies as `mechanics` (exit 0), even though it
# changes which criterion each check line belongs to — a meaning change this
# classifier cannot see, because it never parses which criterion a check line
# is nested under. This is exactly the residual risk issue #47 assigns to a
# named human (the class-M path's mandatory cross-provider review item), not
# a defect to be fixed here: closing it would require a second,
# AC-structure-aware parser this script deliberately does not build.
#
# Usage:
#   check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] [--] <old-spec.md> <new-spec.md>
#
# Exit: 0 = mechanics (stdout: "check-refreeze-class: mechanics: ..."); 1 =
#       class-b (stderr: "check-refreeze-class: class-b: ..."); 2 = usage or
#       structural error (stderr: "check-refreeze-class: usage: ..." or
#       "check-refreeze-class: structural: ...") — bad args, a malformed
#       `--old-hash`/`--new-hash` value, unreadable/non-regular files, a
#       missing/duplicated/reversed marker pair, mismatched task ids across
#       the two specs, a supplied hash that does not match what this script
#       computed (naming which side), or two regions byte-identical after
#       normalization.
#
# This checker never judges whether a replacement `- check:` line still means
# what its criterion's prose says (T-1028 D6/Non-goals) — that reading
# judgment is `codex-reviewer`'s mandatory item and, at the loop level, S4's
# territory. It proves a delta is CONFINED to check lines; it never proves
# the replacement is semantically correct, and it never proves the loop
# actually consulted it before taking the class-M path (D6's honesty claim).
#
# Signal exits (T-1034 DP11): 129, 130 and 143 mean SIGHUP, SIGINT and
# SIGTERM terminated the run; they carry no classification and never
# collide with the 0/1/2 classification contract above.
#
# Signal-blocking window (issue #153, adjudicated — behaviour unchanged): the
# HUP/INT/TERM traps installed above are ignored for the few instructions
# between `mktemp` creating a temp file and this script registering that path
# for cleanup. POSIX carries an ignored disposition across exec, so `mktemp`
# itself is uninterruptible for that window too: if `mktemp` blocks rather
# than returns, only SIGKILL stops the run, and a SIGKILL there bypasses the
# EXIT trap and can leave the created file behind. A `mktemp` that hangs
# rather than fails is the same external-command liveness class this checker
# has never protected against, so the window is kept and its residue is
# documented here rather than traded away for a leak.

set -euo pipefail

# --- classified failure helpers ---------------------------------------------
# D2's exit contract: 0 = mechanics, 1 = class-b, 2 = usage|structural.
# Defined FIRST, before anything else (including the symlink-resolution
# bootstrap directly below), so every external-command / pipeline /
# redirect-write / read failure from the very first line onward has a
# classified exit path available (ported convention, bin/check-intent.sh).
die() {  # $1 = classification (usage|class-b|structural), $2 = message
  printf 'check-refreeze-class: %s: %s\n' "$1" "$2" >&2 || true
  case "$1" in
    class-b) exit 1 ;;
    *)       exit 2 ;;
  esac
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
fail_classb()      { die class-b "$1"; }

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported from bin/check-intent.sh (itself ported from bin/log-run.sh L51-59,
# 2026-07-14 lesson: reuse the proven resolver instead of hand-rolling one).
# Every external command in this bootstrap is guarded — a failure here falls
# closed as a classified usage(2) error instead of a bare, untokened `set -e`
# exit.
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

# shellcheck disable=SC2329  # invoked indirectly via the signal traps below
on_signal() {  # $1 = signal name, $2 = the conventional 128+N exit code
  printf '%s: interrupted by SIG%s (a signal, not a classification)\n' "$self_name" "$1" >&2 || true
  exit "$2"
}
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
# T-1051 #179(a) (byte-parallel mirror, AC8 symmetry): SIGPIPE is ignored
# outright here too, never routed through on_signal — mirroring
# bin/check-intent.sh's own fix. That sibling's builtin `printf` deliverable
# write (its `--print-hash` mode) is genuinely at risk of a signal-killed
# write that never reaches its own `||` guard, measured live by forcing
# SIGPIPE to its true default (terminate) disposition. This script's own
# sole `printf` (the closing `mechanics:` line) is already `|| true`-guarded
# with no deliverable-value site of its own, so it carries no independent
# defect — this trap is defensive parity against the same class of future
# risk, at zero behavioural cost today, kept symmetric with the sibling
# rather than declaring an asymmetry that costs nothing to close.
trap '' PIPE

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- temp-file cleanup (guarded mktemp bootstrap) ---------------------------
TMP_FILES=()
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup_tmp_files() {
  _exit_rc=$?
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}" || true
  fi
  exit "$_exit_rc"
}
trap cleanup_tmp_files EXIT

# block_signals_for_registration / restore_signal_traps (T-1034 rework round
# 1, Codex round-1 Major 2): closes the mktemp-to-TMP_FILES-registration
# signal window. `mktemp`'s result is only appended to TMP_FILES on the line
# immediately after the call returns; a HUP/INT/TERM delivered while `mktemp`
# itself is still running (bash defers a pending trap until the current
# foreground command — here, the command substitution — returns) fires the
# already-installed on_signal handler right after the assignment completes
# but before TMP_FILES ever names the path, so cleanup_tmp_files's
# `rm -f "${TMP_FILES[@]}"` never reaches it: a real, live-reproducible leak.
# HUP/INT/TERM are ignored for this narrow create+register window and
# restored immediately after — this never reorders or edits the frozen SIG
# block above; it only wraps the two mktemp+register sites below with it.
block_signals_for_registration() { trap '' HUP INT TERM; }
restore_signal_traps() {
  trap 'on_signal HUP 129' HUP
  trap 'on_signal INT 130' INT
  trap 'on_signal TERM 143' TERM
}

# --- argument parsing (positional; -- ends option parsing) ------------------
HEX40_RE='^[0-9a-f]{40}$'
OLD_HASH=""
NEW_HASH=""
OLD_SPEC=""
NEW_SPEC=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --old-hash)
      [ "$#" -ge 2 ] || fail_usage "--old-hash requires a value (usage: check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] [--] <old-spec.md> <new-spec.md>)"
      OLD_HASH="$2"
      [[ "$OLD_HASH" =~ $HEX40_RE ]] || fail_usage "--old-hash value is not 40 lowercase hex characters: $OLD_HASH"
      shift 2
      ;;
    --new-hash)
      [ "$#" -ge 2 ] || fail_usage "--new-hash requires a value (usage: check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] [--] <old-spec.md> <new-spec.md>)"
      NEW_HASH="$2"
      [[ "$NEW_HASH" =~ $HEX40_RE ]] || fail_usage "--new-hash value is not 40 lowercase hex characters: $NEW_HASH"
      shift 2
      ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  break ;;
  esac
done

if [ "$#" -ge 1 ]; then OLD_SPEC="$1"; shift; fi
if [ "$#" -ge 1 ]; then NEW_SPEC="$1"; shift; fi
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$OLD_SPEC" ] || fail_usage "missing required <old-spec.md> (usage: check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] [--] <old-spec.md> <new-spec.md>)"
[ -n "$NEW_SPEC" ] || fail_usage "missing required <new-spec.md> (usage: check-refreeze-class.sh [--old-hash <40-hex>] [--new-hash <40-hex>] [--] <old-spec.md> <new-spec.md>)"

# --- 2. validate both paths: `-f` before `-r` (type before permissions), so a
# directory is classified by its TYPE and never handed to a `while read` loop.
[ -f "$OLD_SPEC" ] || fail_usage "old-spec path is not a regular file (directories/FIFOs/etc. are rejected): $OLD_SPEC"
[ -r "$OLD_SPEC" ] || fail_usage "cannot read old-spec file: $OLD_SPEC"
[ -f "$NEW_SPEC" ] || fail_usage "new-spec path is not a regular file (directories/FIFOs/etc. are rejected): $NEW_SPEC"
[ -r "$NEW_SPEC" ] || fail_usage "cannot read new-spec file: $NEW_SPEC"

# --- normalization: identical to bin/check-intent.sh's normalize_stdin -----
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

# --- 3. derive the task id from each spec's own **Task ID**: T-NNN line ----
# Same end-anchored regex as bin/check-intent.sh (a malformed metadata line
# such as `**Task ID**: T-900junk-trailing-garbage` must fail closed rather
# than silently derive T-900).
# shellcheck disable=SC2016
TASK_ID_RE='^\*\*Task ID\*\*: *(T-[0-9]+)[[:space:]]*$'

find_task_id() {  # $1 = spec path; prints the task id on stdout; else return 1
  local path="$1" raw l
  [ -r "$path" ] || return 1
  while IFS= read -r raw || [ -n "$raw" ]; do
    l="${raw%$'\r'}"
    if [[ "$l" =~ $TASK_ID_RE ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$path"
  return 1
}

OLD_TASK_ID="$(find_task_id "$OLD_SPEC")" || fail_structural "no '**Task ID**: T-NNN' line found in old-spec: $OLD_SPEC"
NEW_TASK_ID="$(find_task_id "$NEW_SPEC")" || fail_structural "no '**Task ID**: T-NNN' line found in new-spec: $NEW_SPEC"
[ "$OLD_TASK_ID" = "$NEW_TASK_ID" ] \
  || fail_structural "old-spec and new-spec derive different task ids (old=$OLD_TASK_ID new=$NEW_TASK_ID) — a refreeze classification only makes sense within one task"
TASK_ID="$NEW_TASK_ID"

# --- 4. each spec carries exactly one marker pair, BEGIN strictly before END
check_markers() {  # $1 = path, $2 = task id; sets BEGIN_LN / END_LN globals
  local path="$1" tid="$2" begin_mark end_mark bcount ecount
  begin_mark="<!-- BEGIN intent-block: ${tid} -->"
  end_mark="<!-- END intent-block: ${tid} -->"
  bcount="$(marker_count "$begin_mark" "$path")" \
    || fail_usage "awk failed while counting BEGIN intent-block markers in $path"
  ecount="$(marker_count "$end_mark" "$path")" \
    || fail_usage "awk failed while counting END intent-block markers in $path"
  if [ "$bcount" -ne 1 ] || [ "$ecount" -ne 1 ]; then
    fail_structural "expected exactly one intent-block marker pair for $tid in $path (got BEGIN=$bcount END=$ecount)"
  fi
  BEGIN_LN="$(marker_line "$begin_mark" "$path")" \
    || fail_usage "awk failed while locating the BEGIN intent-block marker line in $path"
  END_LN="$(marker_line "$end_mark" "$path")" \
    || fail_usage "awk failed while locating the END intent-block marker line in $path"
  if [ "$BEGIN_LN" -ge "$END_LN" ]; then
    fail_structural "BEGIN intent-block marker (line $BEGIN_LN) must precede END marker (line $END_LN) in $path"
  fi
}

check_markers "$OLD_SPEC" "$TASK_ID"
OLD_BEGIN_LN="$BEGIN_LN"
OLD_END_LN="$END_LN"
check_markers "$NEW_SPEC" "$TASK_ID"
NEW_BEGIN_LN="$BEGIN_LN"
NEW_END_LN="$END_LN"

# --- 5. extract + normalize each region into a guarded mktemp file ----------
extract_region() {  # $1 = path, $2 = begin_ln, $3 = end_ln, $4 = dest tmp file path
  # T-1034 DP8: the dest tmp file is created with `mktemp` and registered
  # into TMP_FILES by the PARENT shell, BEFORE this function is ever called
  # — the caller passes the path in as an argument. This function only
  # writes into that path and prints nothing; it is called as a plain
  # command (never via `$( )`), so it runs in the PARENT shell, not a
  # subshell. The prior design invoked this via command substitution, which
  # ran it in a subshell where a `TMP_FILES+=()` done inside the function
  # only mutated that subshell's own copy of the array and was discarded on
  # return — so a write failure after `mktemp` already succeeded (disk full,
  # a file-size quota such as `ulimit -f 0`) left an unregistered, unreaped
  # temp file behind. Registering the path before the write, in the parent
  # shell, closes that leak structurally rather than by moving the
  # registration a third time.
  local path="$1" b="$2" e="$3" dest="$4"
  awk -v b="$b" -v e="$e" 'NR > b && NR < e' "$path" | normalize_stdin > "$dest" \
    || fail_usage "failed to extract+normalize the intent block from $path into a temp file (possible causes: disk full, a file-size quota such as ulimit -f, or an awk/sed failure in the extraction pipeline)"
}

block_signals_for_registration
OLD_REGION="$(mktemp "${TMPDIR:-/tmp}/check-refreeze-class-region.XXXXXX")" \
  || fail_usage "mktemp failed to create a temp file for extracting the intent block (check that TMPDIR=${TMPDIR:-/tmp} is writable)"
TMP_FILES+=("$OLD_REGION")
restore_signal_traps
extract_region "$OLD_SPEC" "$OLD_BEGIN_LN" "$OLD_END_LN" "$OLD_REGION"

block_signals_for_registration
NEW_REGION="$(mktemp "${TMPDIR:-/tmp}/check-refreeze-class-region.XXXXXX")" \
  || fail_usage "mktemp failed to create a temp file for extracting the intent block (check that TMPDIR=${TMPDIR:-/tmp} is writable)"
TMP_FILES+=("$NEW_REGION")
restore_signal_traps
extract_region "$NEW_SPEC" "$NEW_BEGIN_LN" "$NEW_END_LN" "$NEW_REGION"

# --- 6. hash each region; validate any supplied --old-hash/--new-hash ------
OLD_HASH_COMPUTED="$(git hash-object --stdin < "$OLD_REGION")" \
  || fail_usage "git hash-object failed while hashing the intent block extracted from $OLD_SPEC"
NEW_HASH_COMPUTED="$(git hash-object --stdin < "$NEW_REGION")" \
  || fail_usage "git hash-object failed while hashing the intent block extracted from $NEW_SPEC"

if [ -n "$OLD_HASH" ] && [ "$OLD_HASH" != "$OLD_HASH_COMPUTED" ]; then
  fail_structural "supplied --old-hash ($OLD_HASH) does not match the OLD side's computed intent-block hash ($OLD_HASH_COMPUTED) for old-spec: $OLD_SPEC"
fi
if [ -n "$NEW_HASH" ] && [ "$NEW_HASH" != "$NEW_HASH_COMPUTED" ]; then
  fail_structural "supplied --new-hash ($NEW_HASH) does not match the NEW side's computed intent-block hash ($NEW_HASH_COMPUTED) for new-spec: $NEW_SPEC"
fi

# --- 7. classify: identical -> structural; different line counts -> class-b;
# otherwise walk the lines and require every differing index to be a
# `- check:` line on both sides.
cmp_rc=0
cmp -s "$OLD_REGION" "$NEW_REGION" || cmp_rc=$?
if [ "$cmp_rc" -eq 0 ]; then
  fail_structural "old-spec and new-spec intent blocks are byte-identical after normalization (no delta) for $TASK_ID — a re-freeze with no change is a bookkeeping error, never a pass"
elif [ "$cmp_rc" -gt 1 ]; then
  fail_usage "cmp failed while comparing the two extracted intent blocks ($OLD_REGION, $NEW_REGION) — an I/O error is not a comparison result and is never read as 'the blocks differ'"
fi

OLD_LINES="$(awk 'END{print NR}' "$OLD_REGION")" \
  || fail_usage "awk failed while counting lines in the old-spec's extracted intent block"
NEW_LINES="$(awk 'END{print NR}' "$NEW_REGION")" \
  || fail_usage "awk failed while counting lines in the new-spec's extracted intent block"

if [ "$OLD_LINES" -ne "$NEW_LINES" ]; then
  fail_classb "old-spec and new-spec intent blocks have different line counts for $TASK_ID (old=$OLD_LINES new=$NEW_LINES) — a class-M delta is confined to '- check:' lines only, which cannot change the line count"
fi

# Same bar bin/check-intent.sh counts `- check:` lines with (T-1028 AC5: one
# definition, not two). Bash 3.2 compatible (indexed arrays only — no
# associative arrays, no mapfile, same bar as every other bin/ script here).
# shellcheck disable=SC2016
CHECK_LINE_RE='^[[:space:]]+- check:'

old_arr=()
while IFS= read -r line || [ -n "$line" ]; do
  old_arr+=("$line")
done < "$OLD_REGION"

new_arr=()
while IFS= read -r line || [ -n "$line" ]; do
  new_arr+=("$line")
done < "$NEW_REGION"

[ "${#old_arr[@]}" -eq "$OLD_LINES" ] || fail_usage "read ${#old_arr[@]} of $OLD_LINES lines from the old-spec's extracted intent block ($OLD_REGION) — refusing to classify a partially-read block"
[ "${#new_arr[@]}" -eq "$NEW_LINES" ] || fail_usage "read ${#new_arr[@]} of $NEW_LINES lines from the new-spec's extracted intent block ($NEW_REGION) — refusing to classify a partially-read block"

diff_count=0
first_bad_index=""
i=0
while [ "$i" -lt "$OLD_LINES" ]; do
  ol="${old_arr[$i]}"
  nl="${new_arr[$i]}"
  if [ "$ol" != "$nl" ]; then
    diff_count=$((diff_count + 1))
    old_is_check=0
    new_is_check=0
    if [[ "$ol" =~ $CHECK_LINE_RE ]]; then old_is_check=1; fi
    if [[ "$nl" =~ $CHECK_LINE_RE ]]; then new_is_check=1; fi
    if [ "$old_is_check" -ne 1 ] || [ "$new_is_check" -ne 1 ]; then
      if [ -z "$first_bad_index" ]; then
        first_bad_index=$((i + 1))
      fi
    fi
  fi
  i=$((i + 1))
done

if [ -n "$first_bad_index" ]; then
  fail_classb "differing line at intent-block index $first_bad_index for $TASK_ID is not a '- check:' line on both sides (a class-M delta requires every differing line, on both the old and the new side, to match '^[[:space:]]+- check:'; a Goal/Non-goals/criterion-prose/Input-space change, an added/deleted line, or a check-line-to-prose replacement all land here)"
fi

# --- 8. mechanics: print task id, both hashes, and the differing-line count.
# This shape is load-bearing, not cosmetic (T-1028 F3/F4/CONTRIBUTING.md): the
# documented recording procedure reads <n> off `differing=<n>` to fill the
# board record's `lines=<n>` field and to know how many `old[i]:`/`new[i]:`
# pairs to write, rather than counting by hand.
printf 'check-refreeze-class: mechanics: %s %s -> %s differing=%s\n' \
  "$TASK_ID" "$OLD_HASH_COMPUTED" "$NEW_HASH_COMPUTED" "$diff_count" || true
exit 0
