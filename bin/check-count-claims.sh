#!/usr/bin/env bash
# check-count-claims.sh — a relayed count carries its own derivation command
# (T-1113, issue #397; .shell-team/specs/T-1113-quantity-relay-checker.md).
#
# Grammar (byte-exact — the label and value sub-grammars are frozen
# separately from the field-level layout so each can be quoted on its own):
#   - count: <label> — <value> — command: <cmd>
# <label> is closed to ^[A-Za-z0-9][A-Za-z0-9_-]*$ (bin/derive-populations.sh's
# own valid_ident() grammar, reused verbatim). <value> is closed to
# ^[+-]?[0-9]+$ (signed, because a delta can be negative; a signed zero -0
# compares equal to an unsigned 0). `command:` is free-form and the LAST
# field on the line by construction, so a ` — ` inside a caller's own
# command text can never forge a field.
#
# Collect-wide, parse-strict (bin/check-entry-mode.sh's own discipline,
# applied here): a row is COLLECTED by a stem deliberately wider than the
# strict grammar above on exactly two axes — the field name's case and the
# colon's width (an ASCII `:` or a full-width `：`, U+FF1A, what an
# un-switched Japanese IME produces) — and, once collected, is REFUSED
# unless it also matches the strict grammar byte-for-byte. A near-miss row
# is therefore never silently read as the conformant zero-row case. The
# stem is exactly:
#   ^[[:space:]]*-[[:space:]]+[Cc][Oo][Uu][Nn][Tt][[:space:]]*(:|：)[[:space:]]*
# spelled as explicit ASCII case alternatives (never `grep -i`, which would
# also loosen every other pattern this file matches) and as an alternation
# between the ASCII and full-width colon (never a bracket expression, which
# would decompose the full-width colon's 3 UTF-8 bytes under LC_ALL=C and
# match a lone continuation byte instead of the whole character). Field
# names outside `count` in some case — a synonym or a misspelling — match
# neither the wide stem nor the strict grammar and are invisible to this
# checker by construction, exactly like a count left in free prose: this is
# a declared boundary, not a gap.
#
# Duplicate labels on one entry refuse; an entry carrying no `- count:`
# sub-bullet at all passes vacuously (validate-if-present at the family
# level, bin/check-entry-mode.sh's own rule for its own families).
#
# TRUST BOUNDARY: outside --no-exec, this checker runs the command each
# conformant row carries via `bash -c`, arbitrary code execution by design.
# This is safe only because: it is invoked explicitly by a human / QA,
# never a hook or auto-run; its subject is a task's own board hand-off
# entry, which any role edits at any point in a task's life, so — unlike
# bin/check-acs.sh's own frozen, review-gated spec subject — an operator
# invoking live mode may be running commands out of prose from before any review of the entry itself has occurred;
# and every command it runs must
# be read-only verification (the same convention check-acs.sh states for
# its own `check:` lines). Each command is echoed before it runs, so the
# operator sees what is about to execute. Live mode additionally warns —
# on stderr, and never changes the exit status — when the resolved board is
# a tracked path carrying uncommitted modifications against the index or
# HEAD, so the operator learns their board may carry unreviewed prose at
# the moment commands run from it; the warning stays silent (by design, not
# by omission) on an untracked or gitignored board and outside a git work
# tree altogether, both ordinary adopter environments this repository
# declines to coerce.
#
# Live re-derivation: a command's output is trimmed of surrounding
# whitespace, then must be a single token matching ^[+-]?[0-9]+$ — internal
# whitespace (two tokens, e.g. `6 7`) refuses rather than reading only the
# first token; multi-line and empty output both refuse (empty is never
# read as zero); a leading-zero measurement (`08`) compares as decimal 8,
# never octal. A non-zero command exit always refuses, even when its
# stdout would otherwise have matched — the named trap `grep -c` sets (it
# exits 1 on no match, printing `0`) — with a remedy naming the `| wc -l`
# idiom instead.
#
# `command -v timeout` guards an optional wrapper (GNU coreutils; absent on
# some hosts, notably macOS without it installed — commands then run
# unbounded, no timeout binary, disclosed rather than silently assumed).
# Override the default cap with CHECK_COUNT_CLAIMS_TIMEOUT (validated
# against a digits-plus-smhd grammar, exactly as bin/check-acs.sh validates
# CHECK_ACS_TIMEOUT, so a hostile CHECK_COUNT_CLAIMS_TIMEOUT cannot inject
# a flag into the `timeout` invocation).
#
# Usage:
#   check-count-claims.sh --board PATH --task T-NNN [--no-exec]
#   check-count-claims.sh --help
#
#   --board PATH  the board file to read (required)
#   --task T-NNN  the task whose ## Active entry is read (required)
#   --no-exec     structural mode: validate the grammar, never run a
#                 command — the safe default for CI and for a preview
#
# Exit codes: 0 = every `- count:` row is conformant (grammar-only under
# --no-exec; grammar AND live re-derivation otherwise), including the
# vacuous zero-row case; 1 = a refusal about the entry's own content (a
# malformed or duplicated row, or — outside --no-exec — a live
# re-derivation mismatch or an unusable measurement); 2 = a usage or
# environment error (bad invocation, an unreadable board, or the task not
# found as exactly one top-level ## Active entry).

set -euo pipefail

PROG="check-count-claims"

die()  { printf '%s: %s\n' "$PROG" "$1" >&2 || true; exit 2; }
fail() { printf '%s: %s\n' "$PROG" "$1" >&2 || true; exit 1; }

BOARD="" TASK="" NO_EXEC=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      [ "$#" -ge 2 ] || die "missing value for --board"
      BOARD="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || die "missing value for --task"
      TASK="$2"; shift 2 ;;
    --no-exec)
      NO_EXEC=1; shift ;;
    --help|-h)
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$BOARD" ] || die "missing required --board"
[ -n "$TASK" ]  || die "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || die "invalid --task '$TASK' (expected T-<digits>)"
[ -r "$BOARD" ] || die "cannot read board: $BOARD"

# --- locate the task's Active entry extent (bin/check-entry-mode.sh's own
# shape: interleaved level-three `### ` narrative blocks inside ## Active
# are not mistaken for the entry's own sub-bullets — capture stops at the
# first non-indented, non-blank line). -----------------------------------
scan="$(awk -v task="$TASK" '
  BEGIN { sec=""; a_start=0; a_end=0; a_count=0; capturing=0 }
  /^## /            { sec=$0; capturing=0 }
  sec ~ /^## Active/ {
    if ($0 ~ ("^- \\[ \\] \\*\\*" task "\\*\\* ")) {
      a_count++; a_start=NR; a_end=NR; capturing=1; next
    }
    if (capturing) {
      if ($0 ~ /^[[:space:]]*$/) { next }
      if ($0 ~ /^[[:space:]]+[^[:space:]]/) { a_end=NR; next }
      capturing=0
    }
  }
  END { print a_start, a_end, a_count }
' "$BOARD")"
read -r A_START A_END A_COUNT <<< "$scan"
[ "$A_COUNT" -eq 1 ] || die "$TASK is not exactly one top-level entry in ## Active of $BOARD"

# CRLF tolerance, same reason bin/check-entry-mode.sh strips it.
ENTRY="$(sed -n "${A_START},${A_END}p" "$BOARD" | sed 's/\r$//')"

# --- collect-wide / parse-strict scan ------------------------------------
COLLECT_RE='^[[:space:]]*-[[:space:]]+[Cc][Oo][Uu][Nn][Tt][[:space:]]*(:|：)[[:space:]]*'
STRICT_RE='^[[:space:]]*- count: ([A-Za-z0-9][A-Za-z0-9_-]*) — ([+-]?[0-9]+) — command: (.+)$'

ROW_LABELS=()
ROW_VALUES=()
ROW_CMDS=()

while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [[ "$line" =~ $COLLECT_RE ]]; then
    if [[ "$line" =~ $STRICT_RE ]]; then
      ROW_LABELS+=("${BASH_REMATCH[1]}")
      ROW_VALUES+=("${BASH_REMATCH[2]}")
      ROW_CMDS+=("${BASH_REMATCH[3]}")
    else
      fail "$TASK has a malformed \`- count:\` sub-bullet — collected by the wide stem but does not match the strict grammar \`- count: <label> — <value> — command: <cmd>\`: $line"
    fi
  fi
done <<< "$ENTRY"

ROW_COUNT="${#ROW_LABELS[@]}"

# --- duplicate labels refuse ----------------------------------------------
SEEN=" "
ridx=0
while [ "$ridx" -lt "$ROW_COUNT" ]; do
  lbl="${ROW_LABELS[$ridx]}"
  case "$SEEN" in
    *" $lbl "*) fail "$TASK has two \`- count:\` rows sharing the label '$lbl' — labels must be unique on one entry" ;;
  esac
  SEEN="${SEEN}${lbl} "
  ridx=$((ridx + 1))
done

# Zero rows: validate-if-present at the family level — pass vacuously.
[ "$ROW_COUNT" -gt 0 ] || exit 0

# --no-exec: structural mode only, nothing executed past this point.
[ "$NO_EXEC" -eq 0 ] || exit 0

# --- optional CHECK_COUNT_CLAIMS_TIMEOUT-guarded wrapper ------------------
TIMEOUT_PREFIX=""
if command -v timeout >/dev/null 2>&1; then
  cc_timeout="${CHECK_COUNT_CLAIMS_TIMEOUT:-120}"
  case "$cc_timeout" in
    ''|[!0-9]*|*[!0-9smhd]*)
      printf '%s: ignoring invalid CHECK_COUNT_CLAIMS_TIMEOUT=%s, using 120\n' "$PROG" "$cc_timeout" >&2 || true
      cc_timeout=120
      ;;
  esac
  TIMEOUT_PREFIX="timeout $cc_timeout"
fi

# --- advisory uncommitted-board warning (T-1113 AC18; never touches the ---
# exit status). Guarded exactly like the timeout wrapper: command -v git,
# then an explicit is-this-a-work-tree test resolved from the BOARD file's
# own directory (never the process cwd) — every negative answer (no git, no
# work tree, untracked/gitignored path) is "no warning, proceed", never a
# refusal. Keyed on a TRACKED path's modification against the index or
# HEAD — a `git diff`-shaped read — deliberately never on a `git status
# --porcelain` `??` entry, which is what an untracked board produces and
# which this checker must stay silent on (an ordinary adopter environment).
board_uncommitted=0
if command -v git >/dev/null 2>&1; then
  board_dir="$(cd "$(dirname "$BOARD")" 2>/dev/null && pwd)" || board_dir=""
  board_base="$(basename "$BOARD")"
  if [ -n "$board_dir" ] && git -C "$board_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$board_dir" ls-files --error-unmatch -- "$board_base" >/dev/null 2>&1; then
      if ! git -C "$board_dir" diff --quiet -- "$board_base" 2>/dev/null \
        || ! git -C "$board_dir" diff --quiet --cached -- "$board_base" 2>/dev/null; then
        board_uncommitted=1
      fi
    fi
  fi
fi
if [ "$board_uncommitted" -eq 1 ]; then
  printf '%s: warning: %s carries uncommitted modifications — the commands about to run may have come from prose no gate has reviewed yet\n' "$PROG" "$BOARD" >&2 || true
fi

# --- trim helper: leading/trailing whitespace only (never internal) ------
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# --- canonical decimal form: sign-stripped, leading zeros dropped, never
# read through bash arithmetic (which would treat a leading zero as octal).
canon_num() {
  local v="$1" sign=""
  case "$v" in
    -*) sign="-"; v="${v#-}" ;;
    +*) v="${v#+}" ;;
  esac
  while [ "${#v}" -gt 1 ] && [ "${v:0:1}" = "0" ]; do
    v="${v:1}"
  done
  if [ "$sign" = "-" ] && [ "$v" != "0" ]; then
    printf -- '-%s' "$v"
  else
    printf '%s' "$v"
  fi
}

# --- live re-derivation, one row at a time (each command echoed BEFORE it
# runs, so the echo is proven never to depend on a success path). ---------
ridx=0
while [ "$ridx" -lt "$ROW_COUNT" ]; do
  label="${ROW_LABELS[$ridx]}"
  value="${ROW_VALUES[$ridx]}"
  cmd="${ROW_CMDS[$ridx]}"

  printf '%s: count %s — declared %s — command: %s\n' "$PROG" "$label" "$value" "$cmd"

  set +e
  # shellcheck disable=SC2086  # TIMEOUT_PREFIX is "timeout N" or empty — intentional split.
  out="$( $TIMEOUT_PREFIX bash -c "$cmd" )"
  rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    fail "$TASK's \`- count: $label\` command exited $rc — a non-zero exit (e.g. \`grep -c\` finding zero matches, exit 1) is refused rather than read as zero; pipe through \`| wc -l\` instead: $cmd"
  fi

  measured="$(trim "$out")"
  if [ -z "$measured" ]; then
    fail "$TASK's \`- count: $label\` command produced no usable output — empty output is refused, never read as zero: $cmd"
  fi
  if ! [[ "$measured" =~ ^[+-]?[0-9]+$ ]]; then
    fail "$TASK's \`- count: $label\` command output '$out' is not a single numeric token: $cmd"
  fi

  declared_canon="$(canon_num "$value")"
  measured_canon="$(canon_num "$measured")"
  if [ "$declared_canon" != "$measured_canon" ]; then
    fail "$TASK's \`- count: $label\` declares $value but the command measured $measured (canonical $measured_canon vs $declared_canon): $cmd"
  fi

  ridx=$((ridx + 1))
done

exit 0
