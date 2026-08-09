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
#   2. attestation (T-1018) — a freeze is refused unless the board carries a conformant freeze-attestation record for the version being recorded.
#      At the freeze moment (no well-formed intent-hash record at all — the
#      declared version N=1) and at every later ratified version, the
#      task's own top-level board entry must carry exactly one well-formed
#      sub-bullet
#        - freeze-attestation (vN, YYYY-MM-DD): lines=<ran>/<total> sweep=mutual-satisfiability verdict=<P>P/<F>F owner=<value>
#      for each version 1..N and none outside that range — missing,
#      duplicated, out-of-range, malformed or arithmetically inconsistent is
#      a refusal. EXCEPTION (the legacy carve-out): a task whose entry
#      already carries a well-formed intent-hash record and NO
#      attestation-shaped line at all is judged exactly as it was before
#      this task and is never gated retroactively — the whole
#      backward-compatibility answer for every already-frozen record. A
#      refusal here prints the exact, ready-to-adapt sub-bullet shape with
#      the counted total already substituted (see the Exit section below).
#   3. version-chain — the ratification records must form an unbroken chain
#      v1->v2->...->vN (exactly N-1 records, no gaps/dupes/out-of-range/
#      reversal; v1 needs none). Broken chain => exit 1 (drift-detected).
#   4. hash-match — `git hash-object` of the marker region's NORMALIZED bytes
#      (CR stripped, trailing whitespace stripped per line, leading/trailing
#      blank lines dropped — identical to check-prompt-sync.sh's
#      normalize_stdin) must equal the board's recorded vN hash. Mismatch =>
#      exit 1 (drift-detected).
#   5. all pass => exit 0 (aligned).
#
# This checker judges BYTES + LEDGER BOOKKEEPING ONLY. Whether the delivered
# behavior still matches the intent's MEANING is never judged here — that is
# S4 (drift/alignment evaluator), explicitly out of scope (spec DP4). Nor
# does it verify that an attested run actually happened or that its sweep
# was substantive (T-1018): the freeze-attestation record is the executor's
# claim, and only its shape, its internal arithmetic, and its agreement with
# the spec's own counted `- check:` lines are checked — the same trust
# boundary bin/check-interventions.sh and bin/check-acs.sh already declare
# over a committed, reviewed artifact, inherited verbatim rather than
# pretended away.
#
# Marker matching is an EXACT full-line compare (never a substring/grep -F
# search): a marker literal quoted mid-sentence in prose (this repo's own
# T-071 spec quotes its real marker inside a Notes-for-engineer sentence) is
# never miscounted as a second marker pair. Board records are likewise
# recognized only when the FULL line (after leading whitespace) matches the
# structured `- intent-hash (vN): ...` / `- intent-ratified (...): ...` /
# `- freeze-attestation (...): ...` shape — a prose sub-bullet that merely
# quotes those words mid-sentence (e.g. this repo's own board `freeze
# (dogfood):` note, or a hand-off sentence that mentions a
# `freeze-attestation (v1, …)` record mid-sentence) is never miscounted as a
# record (2026-07-17 self-referential dogfooding lesson; re-grounded for
# T-1018).
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
# The attestation judgment (T-1018) inherits the same trust boundary and the
# same disposition: it never reintroduces a board-git-history walk, in any
# form, for any judgment in this file.
#
# Usage:
#   check-intent.sh [--] <spec.md> <board.md>
#   check-intent.sh --print-hash <spec.md>
#
# --print-hash (T-1041): prints the frozen intent block's 40-hex hash and one
# trailing LF on stdout, and NOTHING else — no board argument, no ledger
# judgment of any kind. It shares every judgment upstream of hashing with the
# two-argument mode (spec type/readability, Task ID derivation, marker
# structural checks, extraction, normalization, hashing) — the SAME pipeline,
# not a second implementation of the same normalization — so the value this
# prints is byte-identical to the value the two-argument mode itself computes
# and verifies. Every refusal in this mode writes zero bytes to stdout and
# reuses the SAME classified exit paths (die/fail_usage/fail_structural)
# documented below. Mode flags are mutually exclusive: a repeated or
# conflicting mode flag is a usage(2) error, following bin/team-paths.sh:81's
# `set_mode` precedent (a typo should be a clear error, not a silent
# honouring of whichever flag came last).
#
# Exit: 0 = aligned; 1 = drift-detected (hash mismatch or broken version
#       chain); 2 = usage / structural error (bad args, unreadable files,
#       missing/duplicated/reversed markers, missing/duplicated/malformed
#       board records) or an attestation error (T-1018, its own
#       classification token — see below).
#
# an unattested, malformed or miscounted freeze-attestation is exit 2 with the attestation classification, and the hash is never recorded.
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
# Every rejection path prints a classification token to stderr so a caller
# (or this checker's own fixture suite) can distinguish usage/structural
# errors from a genuine drift finding without parsing prose. Defined FIRST,
# before anything else (including the symlink-resolution bootstrap directly
# below) — every external-command / pipeline / redirect-write / read failure
# in this script, from the very first line onward, must have a classified
# exit path available (T-071 rework2 "fail-closed の全数 inventory 要求"; see
# the inventory table in the T-071 engineer hand-off).
die() {  # $1 = classification (usage|structural|attestation), $2 = message; exit 2
  printf 'check-intent: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
# fail_attestation (T-1018): a freeze-attestation is missing, malformed,
# duplicated, out-of-range or arithmetically inconsistent. Reuses die() —
# no new stderr write site is added, so tests/errexit-safe/run.sh's
# file:line:content pin registry needs no re-grounding (AC18).
fail_attestation() { die attestation "$1"; }
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

# shellcheck disable=SC2329  # invoked indirectly via the signal traps below
on_signal() {  # $1 = signal name, $2 = the conventional 128+N exit code
  printf '%s: interrupted by SIG%s (a signal, not a classification)\n' "$self_name" "$1" >&2 || true
  exit "$2"
}
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
# T-1051 #179(a) (measured, not guessed): SIGPIPE gets a DIFFERENT treatment
# than HUP/INT/TERM above — ignored outright, never routed through
# on_signal. Two builtin `printf` write sites in this file (the print-hash
# deliverable at line 395, and the courtesy `aligned:` line at line 864)
# are each already followed by their own `||` guard
# (`fail_usage` / `true` respectively) — but a `printf` builtin's write() to
# a pipe whose reader is gone, under SIGPIPE's REAL default disposition
# (terminate), kills this whole process synchronously, inside the write()
# syscall, before bash's interpreter ever reaches that trailing `||`: a
# signal-killed write that never reaches the classifier guarding it,
# confirmed live by forcing SIGPIPE to its true default disposition (a
# coding sandbox's inherited SIG_IGN masks this in casual testing) and
# observing the whole process die with the raw, unclassified exit 141 with
# neither `fail_usage` nor the courtesy `|| true` ever running. Ignoring
# SIGPIPE removes the kernel-level kill entirely: the interrupted write then
# surfaces as an ordinary non-zero return from the `printf` builtin instead
# (measured: "printf: write error: Broken pipe", rc=1) — precisely what the
# EXISTING `||` guards at each site were already written to classify (T-1041
# D3 for the print-hash site), so this closes the race without adding a new
# stderr write site or a new classified exit code. Mirrored byte-for-byte in
# bin/check-refreeze-class.sh (AC8 symmetry) even though that sibling's own
# sole printf is already `|| true`-guarded with no deliverable-value site of
# its own — defensive parity against the same class of future risk, at zero
# behavioural cost today.
trap '' PIPE

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing (positional; -- ends option parsing) ------------------
SPEC=""
BOARD=""
PRINT_HASH=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --print-hash)
      # T-1041 D1: mode flags are mutually exclusive, following
      # bin/team-paths.sh:81's `set_mode` precedent — a repeated or
      # conflicting mode flag is a usage(2) error rather than last-one-wins,
      # so a typo is a clear error instead of a silent honouring of
      # whichever flag came last.
      [ "$PRINT_HASH" -eq 0 ] || fail_usage "specify --print-hash at most once (mode flags are mutually exclusive)"
      PRINT_HASH=1
      shift
      ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  break ;;
  esac
done

if [ "$#" -ge 1 ]; then SPEC="$1"; shift; fi
# T-1041 D1: a board argument in print mode is a usage(2) error rather than
# optional-and-ignored — accepting one would invite a caller to believe the
# board was validated when nothing about it was ever read (D2 below).
if [ "$PRINT_HASH" -eq 0 ] && [ "$#" -ge 1 ]; then BOARD="$1"; shift; fi
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$SPEC" ] || fail_usage "missing required <spec.md> (usage: check-intent.sh [--print-hash] <spec.md> [<board.md>])"
if [ "$PRINT_HASH" -eq 0 ]; then
  [ -n "$BOARD" ] || fail_usage "missing required <board.md> (usage: check-intent.sh <spec.md> <board.md>)"
fi
# Type + readability validation happens HERE, before either read loop below
# is ever reached (T-071 rework2 "引数の型・健全性検証"). A directory or FIFO
# is rejected as usage(2) rather than being handed to a `while read` loop —
# which would otherwise either raw-exit on a directory (spec argument) or
# spin forever re-reading the same "Is a directory" error (board argument,
# a CI-hanging failure mode). `-f` (regular file) is checked before `-r`
# (readable) so a directory is classified by its TYPE, not its permissions.
[ -f "$SPEC" ]  || fail_usage "spec path is not a regular file (directories/FIFOs/etc. are rejected): $SPEC"
[ -r "$SPEC" ]  || fail_usage "cannot read spec file: $SPEC"
if [ "$PRINT_HASH" -eq 0 ]; then
  [ -f "$BOARD" ] || fail_usage "board path is not a regular file (directories/FIFOs/etc. are rejected): $BOARD"
  [ -r "$BOARD" ] || fail_usage "cannot read board file: $BOARD"
fi

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
# block_signals_for_registration / restore_signal_traps (T-1034 rework round
# 1, Codex round-1 Major 2): closes the mktemp-to-EXIT-trap-registration
# signal window, symmetrically with bin/check-refreeze-class.sh's
# TMP_FILES-registration fix. The HUP/INT/TERM traps are installed early
# (DP10), but tmp_region's EXIT-trap cleanup isn't registered until the
# `trap cleanup_tmp_region EXIT` line below — a signal delivered while
# `mktemp` itself is still running (bash defers a pending trap until the
# current foreground command, the command substitution, returns) fires
# on_signal's `exit "$2"` with no EXIT trap yet installed, leaking the temp
# file mktemp already created: a real, live-reproducible leak. HUP/INT/TERM
# are ignored for this narrow create+register window and restored
# immediately after the EXIT trap is installed — this never reorders the
# frozen SIG block above, nor moves the EXIT-trap installation from its
# position immediately after tmp_region is assigned (DP12).
block_signals_for_registration() { trap '' HUP INT TERM; }
restore_signal_traps() {
  trap 'on_signal HUP 129' HUP
  trap 'on_signal INT 130' INT
  trap 'on_signal TERM 143' TERM
}

block_signals_for_registration
tmp_region="$(mktemp "${TMPDIR:-/tmp}/check-intent-region.XXXXXX")" \
  || fail_usage "mktemp failed to create a temp file for extracting the intent block (check that TMPDIR=${TMPDIR:-/tmp} is writable)"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup_tmp_region() {
  _exit_rc=$?
  rm -f "$tmp_region" || true
  exit "$_exit_rc"
}
trap cleanup_tmp_region EXIT
restore_signal_traps
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

# T-1051 #179(c): computed_hash gets a shape gate BEFORE any of its three
# consumers reads it (the print-mode write just below, the hash-match
# comparison, and the courtesy `aligned:` print further down) — the same
# anchor bin/check-refreeze-class.sh's HEX40_RE already uses. This is
# defence-in-depth against a future edit to the extraction/hashing pipeline
# above, never against real `git` (Non-goals #5): no fixture manufactures a
# non-hex `git hash-object` output by patching or shimming git, so this
# gate's own refusal path is proven only by mutation (spec AC17a), never by
# faking its input. A refusal here fails closed as a classified usage(2)
# exit through the existing `die`, the same convention every other guard in
# this bootstrap already follows — adding no new stderr write site.
HEX40_RE='^[0-9a-f]{40}$'
[[ "$computed_hash" =~ $HEX40_RE ]] \
  || fail_usage "git hash-object produced a value that is not 40 lowercase hex characters, refusing before any consumer reads it: $computed_hash"

# --- print mode (T-1041 D2/D3): exit HERE, before the board is ever
# required. Everything above this point — spec type/readability, Task ID
# derivation, marker structural checks, extraction, normalization, hashing —
# is shared verbatim with the two-argument mode below; this sharing IS the
# one-pipeline property this mode exists to establish (AC2). The stdout
# write is deliberately NOT `|| true`-guarded (D3): unlike the courtesy
# `aligned:` line further down, the printed value here IS the deliverable, so
# swallowing a write failure would let a caller record an empty string as a
# hash — precisely the class of defect this task removes. A write failure is
# therefore a classified usage(2) exit through the existing `die`, adding no
# new stderr write site. The EXIT trap installed above (cleanup_tmp_region)
# still fires on this `exit 0`, so the temp file this mode created is never
# leaked.
if [ "$PRINT_HASH" -eq 1 ]; then
  printf '%s\n' "$computed_hash" || fail_usage "failed to write the computed hash to stdout"
  exit 0
fi

# T-1018 D4: "the counted total" — the number of physical lines matching
# `^[[:space:]]+- check:` inside the ALREADY-EXTRACTED, ALREADY-NORMALIZED
# region temp file the hash above is taken over (Notes for engineer gotcha
# #1) — never a fresh re-read of $SPEC, so both numbers provably describe
# the same bytes. Counted with awk, never `grep -c` (whose exit 1 for "no
# match" and exit 2 for "cannot read" would have to be told apart by hand,
# and a spec with zero `- check:` lines is a legitimate 0, not an error).
counted_total="$(awk '/^[[:space:]]+- check:/{n++} END{print n+0}' "$tmp_region")" \
  || fail_usage "awk failed while counting '- check:' lines in the intent block extracted from $SPEC"

# --- 4. board: locate the task's own top-level entry and its records -------
# shellcheck disable=SC2016
TOP_RE='^- \[[ xX]\] \*\*(T-[0-9]+)\*\*'
HASH_LINE_RE='^[[:space:]]+- intent-hash'
# T-1021 (D4, Codex round1 Major): hash_version is fed straight into a `10#`
# arithmetic expansion (`declared_n=$((10#$hash_version))`,
# `version_int=$((10#$hash_version))`) with no width bound on the capture
# itself before this change, so a grammar-conformant huge digit string
# silently wrapped through bash's signed 64-bit range instead of being
# refused. Bounded to `{1,4}` (max 9999) at the grammar side (D6): a spec's
# intent block is re-frozen at most a handful of times per rework round in
# this repository's own history (T-1018's own most-reworked spec reached
# v1), so 9999 is 100-1000x headroom over any real ceiling; stale-at is a
# single spec being re-frozen ten thousand times, which would break this
# repository's own board/PR conventions long before the digit width does.
# shellcheck disable=SC2016
HASH_FULL_RE='^[[:space:]]+- intent-hash \(v([0-9]{1,4})\): ([0-9a-f]{40})$'
RATIFIED_LINE_RE='^[[:space:]]+- intent-ratified'
# shellcheck disable=SC2016
RATIFIED_FULL_RE='^[[:space:]]+- intent-ratified \([0-9]{4}-[0-9]{2}-[0-9]{2}\): v([0-9]+)→v([0-9]+) — .+ — .+$'
# ATTEST_LINE_RE / ATTEST_FULL_RE (T-1018 D4): the same loose-anchor +
# full-grammar pair HASH_LINE_RE/HASH_FULL_RE and RATIFIED_LINE_RE/
# RATIFIED_FULL_RE already use, so a prose sub-bullet that merely quotes
# `freeze-attestation (v1, …)` mid-sentence is never miscounted as a record.
# Fixed field order, single spaces, `sweep=mutual-satisfiability` a literal
# — D4 rejects order-free key=value parsing. Version is `[1-9][0-9]*` (no
# `v0`, no leading zero) so an out-of-grammar version is malformed rather
# than a separate case. `owner=` requires a non-space first character
# (D5: shape only, no enum, no language rule) then anything to end of line.
#
# T-1021 (D4, Codex round1 Major): the version capture and the four count
# captures (`lines=<ran>/<total>`, `verdict=<P>P/<F>F`) all feed `10#`
# arithmetic (`av`/`ar`/`at`/`ap`/`af` at check-intent.sh:780-787, plus
# `$((ap + af))`) with no width bound, so an oversized value wrapped
# silently instead of refusing. Bounded to `{1,4}` (max 9999) at the
# grammar side (D6), same reasoning as HASH_FULL_RE above: `ran`/`total`
# count `- check:` lines inside one spec's intent block — measured at
# 7deb02a, the true maximum is 35 (T-1011), over 285x headroom against
# 9999 — T-1032 corrects this comment's prior false claim; `P`/`F` are a
# partition of that same `ran` count, so all four share the same real
# ceiling, nowhere near four digits. Stale-at: ten thousand acceptance
# criteria inside one spec's intent block, never approached by two orders
# of magnitude.
ATTEST_LINE_RE='^[[:space:]]+- freeze-attestation'
# shellcheck disable=SC2016
ATTEST_FULL_RE='^[[:space:]]+- freeze-attestation \(v([1-9][0-9]{0,3}), ([0-9]{4}-[0-9]{2}-[0-9]{2})\): lines=([0-9]{1,4})/([0-9]{1,4}) sweep=mutual-satisfiability verdict=([0-9]{1,4})P/([0-9]{1,4})F owner=([^[:space:]].*)$'

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
#   attest_bad_count                     — malformed freeze-attestation
#                                          sub-bullets in scope (T-1018)
#   attest_version[] / attest_ran[] /
#   attest_total[] / attest_p[] /
#   attest_f[]                           — parallel arrays, one entry per
#                                          well-formed freeze-attestation
#                                          sub-bullet, in the order
#                                          encountered (T-1018)
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
  attest_bad_count=0
  attest_version=()
  attest_ran=()
  attest_total=()
  attest_p=()
  attest_f=()

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

        # T-1018: same accumulate-inside-in_entry==1 shape as the two blocks
        # above — added inside the single shared parser's existing branch,
        # never a second parsing loop (Notes for engineer single-parser
        # mandate).
        if [[ "$line" =~ $ATTEST_LINE_RE ]]; then
          if [[ "$line" =~ $ATTEST_FULL_RE ]]; then
            attest_version+=("${BASH_REMATCH[1]}")
            attest_ran+=("${BASH_REMATCH[3]}")
            attest_total+=("${BASH_REMATCH[4]}")
            attest_p+=("${BASH_REMATCH[5]}")
            attest_f+=("${BASH_REMATCH[6]}")
          else
            attest_bad_count=$((attest_bad_count + 1))
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

# fail_hash_structural: the SAME message for both row (4) (>=2 well-formed
# or any malformed intent-hash record) and row (10) below (zero well-formed
# records — the bootstrap case) — T-1018 D3 requires row (10)'s message stay
# byte-unchanged from before this task, so both call sites share one string.
fail_hash_structural() {
  fail_structural "expected exactly one well-formed intent-hash record for $TASK_ID in $BOARD (found valid=$hash_valid_count malformed=$hash_bad_count; expected '- intent-hash (vN): <40-hex>')"
}

# --- row (4): too many, or any malformed, intent-hash records --------------
if [ "$hash_valid_count" -ge 2 ] || [ "$hash_bad_count" -ne 0 ]; then
  fail_hash_structural
fi
# hash_valid_count is now exactly 0 (the freeze moment) or 1 here.

# --- T-1018: "the declared version N" (Terms) — the version in the board's
# single well-formed intent-hash record; N=1 at the freeze moment, where
# there is none. Computed ONCE, before the attestation judgment (Notes for
# engineer gotcha #2), and reused by both the pace rule and the version-N
# count cross-check below.
if [ "$hash_valid_count" -eq 1 ]; then
  declared_n=$((10#$hash_version))
else
  declared_n=1
fi

# --- rows (5)-(9): the attestation judgment (T-1018 D2/D3) — a freeze is
# refused unless the board carries a conformant freeze-attestation record
# for the version being recorded. Skipped ENTIRELY under the legacy
# carve-out (D2 rule 2): a well-formed intent-hash record already exists
# AND there is no attestation-shaped line (well-formed or malformed) at
# all — the whole backward-compatibility answer for the 21 already-frozen
# records here and every adopter's; a well-formed hash plus even one
# malformed attestation line is NOT the carve-out (rule 1 still fires).
attest_shaped_count=$(( ${#attest_version[@]} + attest_bad_count ))
if [ "$hash_valid_count" -eq 1 ] && [ "$attest_shaped_count" -eq 0 ]; then
  : # D2 rule 2 — the legacy carve-out; judgment skipped, never gated
else
  # D2 rule 1 — malformed first: ANY attestation-shaped line that fails the
  # full grammar is a refusal, whatever else is true. A record this checker
  # cannot parse is never treated as absent, and never as present.
  # T-1041 D4b: this is the one refusal path measured to print an abstract
  # grammar and no spec-derived count — a record this checker cannot parse
  # is, by definition, not something it can name a per-field measured value
  # for. It additionally names the count IT measured against this spec's own
  # intent block, and the conformant shape that count implies, so a writer
  # is not left to guess what a well-formed record for THIS spec would say.
  [ "$attest_bad_count" -eq 0 ] \
    || fail_attestation "$attest_bad_count malformed freeze-attestation record(s) for $TASK_ID in $BOARD (expected '- freeze-attestation (vN, YYYY-MM-DD): lines=<ran>/<total> sweep=mutual-satisfiability verdict=<P>P/<F>F owner=<value>'; the intent block being checked carries $counted_total '- check:' line(s), so a conformant record for it reads lines=${counted_total}/${counted_total})"

  # D2 rule 3 — the pace rule: exactly one well-formed attestation for each
  # version 1..N, and none outside that range. A missing, duplicated or
  # out-of-range version is a refusal.
  n_attest="${#attest_version[@]}"
  v=1
  while [ "$v" -le "$declared_n" ]; do
    count_v=0
    idx=0
    while [ "$idx" -lt "$n_attest" ]; do
      if [ "${attest_version[$idx]}" -eq "$v" ]; then
        count_v=$((count_v + 1))
      fi
      idx=$((idx + 1))
    done
    if [ "$count_v" -ne 1 ]; then
      # D4: the refusal prints the exact, ready-to-adapt sub-bullet shape
      # with the counted total already substituted, so the freeze-runner
      # never has to guess (AC3). Deliberately NOT a valid record: the
      # YYYY-MM-DD / <P> / <F> / <who ran them> placeholders make a
      # verbatim paste refuse again rather than silently pass (D4).
      # T-1041 D4a: the measured substitution and the placeholders were
      # typographically indistinguishable on this one line — a measured
      # `lines=12/12` read exactly like an example. The trailing sentence
      # below says, in words, which of these fields is which.
      remedy="  - freeze-attestation (v${v}, YYYY-MM-DD): lines=${counted_total}/${counted_total} sweep=mutual-satisfiability verdict=<P>P/<F>F owner=<who ran them>"
      fail_attestation "expected exactly one freeze-attestation record for $TASK_ID v$v in $BOARD (found $count_v; a freeze is refused unless the board carries a conformant freeze-attestation record for the version being recorded — write:
$remedy
— the lines= counts above are measured, not an example: they already equal what this checker counted in $SPEC's intent block, so copy them as-is and replace only YYYY-MM-DD, <P>P/<F>F and <who ran them> with what you actually measured.)"
    fi
    v=$((v + 1))
  done

  # Out-of-range + arithmetic, over every well-formed attestation in scope.
  #
  # T-1018 rework1 Blocker fix: EVERY captured digit string this loop feeds
  # into an arithmetic context is normalized through the base-10 `10#`
  # prefix IMMEDIATELY after extraction, exactly once, mirroring this file's
  # own pre-existing `declared_n=$((10#$hash_version))` /
  # `version_int=$((10#$hash_version))` convention two call sites away. D4's
  # grammar leaves `lines=`/`verdict=` unrestricted `[0-9]+` (leading zeros
  # conformant, e.g. `verdict=08P/00F`), and bash's `$(())` arithmetic
  # expansion (unlike the `[ -eq/-ne/-lt/-gt ]` test operator, which parses
  # decimal only) treats a leading-zero digit string as octal — `08`/`09`
  # are invalid octal literals and abort the expansion with an unclassified,
  # un-namespaced stderr line. Because that failure occurs inside an `if [
  # ... ]` CONDITION, `set -e` does not apply to it (POSIX/bash exempt an
  # `if`/`while`/`until` condition from errexit), so the script does not
  # abort either — the cross-check is silently skipped and a
  # self-contradictory attestation (`lines=1/1 verdict=08P/00F`, 8+0≠1) is
  # accepted as `aligned`, exit 0. Normalizing HERE, once, before any
  # comparison or arithmetic touches these values, closes the hole at its
  # source rather than requiring every downstream `-eq`/`$(())` site to
  # remember the prefix independently. `attest_version[$idx]` (`av`) is
  # normalized too even though `ATTEST_FULL_RE`'s `[1-9][0-9]*` already
  # forbids a leading zero there — normalizing it costs nothing and keeps
  # every digit this loop touches under the same rule, not a special case.
  idx=0
  while [ "$idx" -lt "$n_attest" ]; do
    av=$((10#${attest_version[$idx]}))
    if [ "$av" -lt 1 ] || [ "$av" -gt "$declared_n" ]; then
      fail_attestation "freeze-attestation record for $TASK_ID names v$av in $BOARD, outside the required range v1..v$declared_n"
    fi
    ar=$((10#${attest_ran[$idx]}))
    at=$((10#${attest_total[$idx]}))
    ap=$((10#${attest_p[$idx]}))
    af=$((10#${attest_f[$idx]}))
    # D4: internal arithmetic ("ran == total", "P + F == ran") is checked
    # for EVERY well-formed record, regardless of version.
    if [ "$ar" -ne "$at" ]; then
      fail_attestation "freeze-attestation v$av for $TASK_ID in $BOARD has lines=$ar/$at (expected ran == total)"
    fi
    if [ "$((ap + af))" -ne "$ar" ]; then
      fail_attestation "freeze-attestation v$av for $TASK_ID in $BOARD has verdict=${ap}P/${af}F but lines ran=$ar (expected P + F == ran)"
    fi
    # D4: the spec-derived count cross-check applies to the VERSION-N
    # record ONLY — a record for an older version was measured against an
    # intent block that has since been ratified away, and this checker can
    # only measure the current one (AC9).
    if [ "$av" -eq "$declared_n" ] && [ "$at" -ne "$counted_total" ]; then
      fail_attestation "freeze-attestation v$av for $TASK_ID declares total=$at but $SPEC's intent block carries $counted_total '- check:' line(s) (an unattested, malformed or miscounted freeze-attestation is exit 2 with the attestation classification, and the hash is never recorded)"
    fi
    idx=$((idx + 1))
  done
fi

# --- row (10): zero well-formed intent-hash records AND the attestation
# judgment passed — the bootstrap case. Message deliberately UNCHANGED from
# before T-1018 (D3): this stays `structural`, not `attestation`, once the
# gate is satisfied — `skills/run/SKILL.md`'s bootstrap branch still
# recognizes it by this exact message.
if [ "$hash_valid_count" -eq 0 ]; then
  fail_hash_structural
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
