#!/usr/bin/env bash
# check-liveness.sh — a fail-closed, out-of-band liveness classifier for a
# shell-team loop (T-1056; GitHub issue #227;
# .shell-team/specs/T-1056-loop-liveness.md).
#
# Every instrument that observes a loop today runs INSIDE it, so a loop that
# stops ticking emits nothing — and nothing is also exactly what a healthy
# loop emits while it waits at a human gate. This script is invoked
# OUT-OF-BAND, by a timer process this repository does not ship, and reads
# only already-persisted state: the /goal run state file, a human-gate
# declaration file (written and cleared by the loop's own choke points), and
# git. It writes nothing except an optional --out verdict document.
#
# Exactly one bare token is printed on stdout, and the SAME decision is also
# carried on the exit code, so a caller can branch without parsing:
#
#   stdout           exit
#   RUNNING          0     positive evidence the loop ticked recently
#   WAITING          3     a fresh human-gate declaration explains it
#   STALLED          4     past the stall threshold, not (yet) past the dead one
#   DEAD             5     past the dead threshold on both clocks
#   OBSERVE_ERROR    2     could not be fully evaluated; a reason token is on
#                          stderr, from a closed 19-token set
#
# Exit 1 is reserved for NOTHING: bash's own `errexit` failure fallback is
# exit 1, so a contract that assigned a verdict to it could never distinguish
# "decided this" from "crashed before deciding". See --help for the full
# vocabulary, the two default thresholds, and the invocation recipe an
# external timer should use.
#
# Nothing here reads the board, gates any phase transition, or forwards
# anything to any other checker in this repository — the only sibling script
# this file calls is the shared path resolver next to it.

set -euo pipefail

# --- classified refusal ------------------------------------------------------
# Every non-terminal-success path funnels through here: print the bare
# OBSERVE_ERROR token on stdout (nothing else), the classification token plus
# a plain-language message on stderr, and exit 2 — the same shape every
# refusal in the closed 19-token set uses.
refuse() {  # $1 = token (closed set); $2 = message
  printf 'OBSERVE_ERROR\n'
  printf 'check-liveness: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported (bootstrap shape) from this repository's other fail-closed
# classifiers — every `pwd` below is `pwd -P` (physical, every symlink
# resolved), a deliberate departure from the still-bare `pwd` an OLDER sibling
# in this family carries, so an ancestor directory being a symlink (an
# adopter's bin/ vendored into the plugin's real bin/) cannot silently
# resolve SCRIPT_DIR inside the adopter's own tree.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || refuse usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || refuse usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || refuse usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || refuse usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || refuse usage "cd/pwd failed to resolve this script's own directory for: $script_path"

print_help() {
  cat <<'EOF'
Usage: check-liveness.sh (--task T-NNN | --state PATH --declaration PATH)
                          [--stall-after N] [--dead-after N] [--out PATH]

Fail-closed, out-of-band classifier for whether a shell-team loop is still
ticking, waiting on a human, stalled, or dead. Reads only already-persisted
state and writes nothing unless --out is given. Invoke it from a timer
process outside this repository (cron, launchd, or any external scheduler
of the operator's choosing) — no such timer ships here; this text is the
whole of the invocation recipe.

Verdicts (stdout: exactly one bare token; also the exit code):
  RUNNING        0  positive evidence the loop ticked recently
  WAITING        3  a fresh human-gate declaration explains the silence
  STALLED        4  past the stall threshold, not (yet) past the dead one
  DEAD           5  past the dead threshold on both the tick clock and HEAD
  OBSERVE_ERROR  2  the input could not be fully evaluated; see stderr
  exit 1         reserved; assigned to no verdict at all (never printed)

Arguments:
  --task T-NNN          compose both paths under the shared runs directory
  --state PATH          the /goal run state file (mutually required with
                         --declaration; mutually exclusive with --task)
  --declaration PATH    the human-gate declaration file (see above)
  --stall-after N       seconds of state-file silence before RUNNING
                        becomes STALLED
  default stall-after: 900
  --dead-after N        seconds of state-file silence AND HEAD silence
                        before STALLED becomes DEAD
  default dead-after: 3600
  --out PATH            also write a self-describing verdict document
                        (replace semantics; a symlink target is refused,
                        dangling or not, without being followed)
  --help, -h            show this help and exit

Re-evaluation trigger for the two defaults above: re-derive both if a single
/goal tick in this repository is measured to exceed --stall-after, if the
completion gate gains a seventh layer, or if the cross-provider review
call's synchronous duration changes materially.
EOF
}

# --- argument parsing ---------------------------------------------------------
TASK="" STATE_PATH="" DECL_PATH="" OUT_PATH=""
STALL_AFTER="900" DEAD_AFTER="3600"
HAVE_TASK=0 HAVE_STATE=0 HAVE_DECL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)       print_help; exit 0 ;;
    --task)          [ "$#" -ge 2 ] || refuse usage "--task requires a value"; TASK="$2"; HAVE_TASK=1; shift 2 ;;
    --state)         [ "$#" -ge 2 ] || refuse usage "--state requires a value"; STATE_PATH="$2"; HAVE_STATE=1; shift 2 ;;
    --declaration)   [ "$#" -ge 2 ] || refuse usage "--declaration requires a value"; DECL_PATH="$2"; HAVE_DECL=1; shift 2 ;;
    --stall-after)   [ "$#" -ge 2 ] || refuse usage "--stall-after requires a value"; STALL_AFTER="$2"; shift 2 ;;
    --dead-after)    [ "$#" -ge 2 ] || refuse usage "--dead-after requires a value"; DEAD_AFTER="$2"; shift 2 ;;
    --out)           [ "$#" -ge 2 ] || refuse usage "--out requires a value"; OUT_PATH="$2"; shift 2 ;;
    --) shift; break ;;
    -*) refuse usage "unknown flag: $1" ;;
    *)  refuse usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || refuse usage "unexpected extra argument: $1"

# --- mode exclusivity: --task, or both --state and --declaration, never both modes and never a partial pair
if [ "$HAVE_TASK" -eq 1 ]; then
  { [ "$HAVE_STATE" -eq 0 ] && [ "$HAVE_DECL" -eq 0 ]; } \
    || refuse usage "--task cannot be combined with --state or --declaration"
  [[ "$TASK" =~ ^T-[0-9]+$ ]] || refuse usage "invalid --task value: '$TASK' (expected T-<digits>)"
elif [ "$HAVE_STATE" -eq 1 ] && [ "$HAVE_DECL" -eq 1 ]; then
  :
else
  refuse usage "supply --task T-NNN, or both --state PATH and --declaration PATH"
fi

# --- thresholds: shape-then-order, width-bounded, 10#-normalized immediately after the bound proves a plain decimal
[[ "$STALL_AFTER" =~ ^[0-9]{1,9}$ ]] || refuse threshold-invalid "invalid --stall-after: '$STALL_AFTER'"
[[ "$DEAD_AFTER"  =~ ^[0-9]{1,9}$ ]] || refuse threshold-invalid "invalid --dead-after: '$DEAD_AFTER'"
STALL_AFTER=$((10#$STALL_AFTER))
DEAD_AFTER=$((10#$DEAD_AFTER))
[ "$DEAD_AFTER" -gt "$STALL_AFTER" ] || refuse threshold-order "--dead-after must be strictly greater than --stall-after"

# --- resolve the sibling path resolver (the only sibling script this file calls) ---
resolve_team_paths() {
  TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"
  [ -f "$TEAM_PATHS" ] && [ -r "$TEAM_PATHS" ] \
    || refuse usage "cannot resolve the loop's shared path resolver next to this script"
}
get_path() {  # $1 = --get key
  bash "$TEAM_PATHS" --get "$1" 2>/dev/null \
    || refuse usage "the shared path resolver could not resolve key: $1"
}

if [ "$HAVE_TASK" -eq 1 ]; then
  resolve_team_paths
  RUNS_DIR="$(get_path runs)"
  STATE_PATH="$RUNS_DIR/goal-$TASK.state"
  DECL_PATH="$RUNS_DIR/gate-$TASK.decl"
fi

# --- step 2: now, overridable for deterministic tests (mirrors $GOAL_NOW's shape) ---
NOW_RAW="${LIVENESS_NOW:-}"
if [ -z "$NOW_RAW" ]; then
  NOW_RAW="$(date +%s)" || refuse clock-unreadable "date +%s failed"
fi
[[ "$NOW_RAW" =~ ^[0-9]{1,11}$ ]] || refuse clock-unreadable "invalid clock value: '$NOW_RAW'"
NOW=$((10#$NOW_RAW))

# --- step 3: the state file — existence, readability, shape, mtime, non-negative age ---
if [ ! -e "$STATE_PATH" ] || [ ! -f "$STATE_PATH" ]; then
  refuse state-missing "no state file at: $STATE_PATH"
fi
[ -r "$STATE_PATH" ] || refuse state-unreadable "cannot read state file: $STATE_PATH"

# mtime: GNU form, then BSD form, then a fail-closed third arm — never a
# substituted zero (DP5's deliberate inversion of the cross-tick state
# helper's own floor for a negative elapsed value).
STATE_MTIME_RAW="$(stat -c %Y -- "$STATE_PATH" 2>/dev/null)" \
  || STATE_MTIME_RAW="$(stat -f %m -- "$STATE_PATH" 2>/dev/null)" \
  || true
[ -n "${STATE_MTIME_RAW:-}" ] || refuse state-unreadable "cannot determine mtime (both stat forms failed): $STATE_PATH"
[[ "$STATE_MTIME_RAW" =~ ^[0-9]{1,11}$ ]] || refuse state-unreadable "state file mtime not a bounded decimal: $STATE_MTIME_RAW"
STATE_MTIME=$((10#$STATE_MTIME_RAW))

# Single-pass awk key read, the same shape the cross-tick state helper's own
# key reader uses (no `| head`, so no SIGPIPE under pipefail).
read_state_key() {  # $1 = key
  awk -F= -v k="$1" '$1==k { sub(/^[^=]*=/, ""); print; exit }' "$STATE_PATH"
}
STATE_START_EPOCH_RAW="$(read_state_key start_epoch)"
STATE_ITERATION_RAW="$(read_state_key iteration)"
[[ "$STATE_START_EPOCH_RAW" =~ ^[0-9]{1,11}$ ]] || refuse state-malformed "start_epoch missing or out of range: '$STATE_START_EPOCH_RAW'"
[[ "$STATE_ITERATION_RAW"   =~ ^[0-9]{1,9}$  ]] || refuse state-malformed "iteration missing or out of range: '$STATE_ITERATION_RAW'"
STATE_START_EPOCH=$((10#$STATE_START_EPOCH_RAW))

A_STATE=$((NOW - STATE_MTIME))
[ "$A_STATE" -ge 0 ] || refuse clock-skew "now is earlier than the state file's mtime"

# --- reason registry: plugin-shipped, resolved from THIS script's own installed
# directory, never from the working tree (DP3/AC2's decoy case). ---
REASON_TOKENS=()
load_reason_registry() {
  local templates_root registry line
  templates_root="$(cd "$SCRIPT_DIR/.." && pwd -P 2>/dev/null)" \
    || refuse registry-unreadable "cannot resolve the templates directory above this script's installed location"
  registry="$templates_root/templates/liveness-reasons.txt"
  [ -f "$registry" ] && [ -r "$registry" ] || refuse registry-unreadable "cannot read the reason registry: $registry"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      ''|'#'*) continue ;;
    esac
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    local -a f
    read -r -a f <<< "$line"
    [ "${#f[@]}" -eq 2 ] || refuse registry-malformed "registry row is not exactly two tokens: $line"
    [[ "${f[0]}" =~ ^[a-z][a-z0-9-]*$ ]] || refuse registry-malformed "invalid reason token shape: ${f[0]}"
    case "${f[1]}" in
      approval|ratification|escalation) ;;
      *) refuse registry-malformed "unknown gate kind: ${f[1]}" ;;
    esac
    local existing dup=0
    for existing in "${REASON_TOKENS[@]:-}"; do
      [ "$existing" = "${f[0]}" ] && dup=1
    done
    [ "$dup" -eq 0 ] || refuse registry-malformed "duplicated reason token: ${f[0]}"
    REASON_TOKENS+=("${f[0]}")
  done < "$registry"
}
reason_known() {  # $1 = candidate token
  local want="$1" t
  for t in "${REASON_TOKENS[@]:-}"; do
    [ "$t" = "$want" ] && return 0
  done
  return 1
}

# --- step 4: the declaration, if the file exists — shape, terminator, reason
# membership, run identity, ordering; fresh emits WAITING here and goes no
# further; superseded falls through to the ladder as context, not an error.
DECL_STATE="absent"
DECL_TASK="" DECL_REASON="" DECL_RUN_EPOCH="" DECL_DECLARED_EPOCH=""

parse_declaration() {  # $1 = path
  local path="$1"
  [ -r "$path" ] || refuse declaration-unreadable "cannot read declaration: $path"
  local -a LINES=()
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    LINES+=("${line%$'\r'}")
  done < "$path"
  local n="${#LINES[@]}"
  [ "$n" -ge 1 ] || refuse declaration-malformed "empty declaration file: $path"

  local last="${LINES[$((n - 1))]}"
  [ "$last" = "gate-declaration-end" ] || refuse declaration-unterminated "missing gate-declaration-end terminator: $path"

  local first="${LINES[0]}"
  [[ "$first" =~ ^gate-declaration\ [0-9]{1,2}$ ]] || refuse declaration-malformed "missing or misplaced version line: $path"
  local ver="${first#gate-declaration }"

  local i vcount=0 tcount=0
  for ((i = 0; i < n; i++)); do
    [[ "${LINES[$i]}" =~ ^gate-declaration\ [0-9]{1,2}$ ]] && vcount=$((vcount + 1))
    [ "${LINES[$i]}" = "gate-declaration-end" ] && tcount=$((tcount + 1))
  done
  [ "$vcount" -eq 1 ] || refuse declaration-malformed "version line duplicated: $path"
  [ "$tcount" -eq 1 ] || refuse declaration-malformed "terminator duplicated: $path"
  [ "$((10#$ver))" -eq 1 ] || refuse declaration-malformed "unsupported gate-declaration version: $ver"

  local have_task=0 have_reason=0 have_run=0 have_declared=0 key val
  for ((i = 1; i < n - 1; i++)); do
    line="${LINES[$i]}"
    case "$line" in
      *' '*) key="${line%% *}"; val="${line#* }" ;;
      *) refuse declaration-malformed "unrecognized directive line: $line" ;;
    esac
    [ -n "$val" ] || refuse declaration-malformed "empty value for directive: $line"
    case "$key" in
      task)
        [ "$have_task" -eq 0 ] || refuse declaration-malformed "duplicate task line"
        have_task=1
        # shellcheck disable=SC2034  # structural presence is what's required
        # (DP3's "one each of task, ..."); the value itself is not
        # cross-checked against the invocation (see the provenance file).
        DECL_TASK="$val" ;;
      reason)
        [ "$have_reason" -eq 0 ] || refuse declaration-malformed "duplicate reason line"
        have_reason=1; DECL_REASON="$val" ;;
      run-epoch)
        [ "$have_run" -eq 0 ] || refuse declaration-malformed "duplicate run-epoch line"
        have_run=1; DECL_RUN_EPOCH="$val" ;;
      declared-epoch)
        [ "$have_declared" -eq 0 ] || refuse declaration-malformed "duplicate declared-epoch line"
        have_declared=1; DECL_DECLARED_EPOCH="$val" ;;
      *) refuse declaration-malformed "unrecognized directive line: $line" ;;
    esac
  done
  { [ "$have_task" -eq 1 ] && [ "$have_reason" -eq 1 ] && [ "$have_run" -eq 1 ] && [ "$have_declared" -eq 1 ]; } \
    || refuse declaration-malformed "missing required field(s) in: $path"

  [[ "$DECL_REASON"         =~ ^[a-z][a-z0-9-]*$ ]] || refuse declaration-malformed "malformed reason token shape: $DECL_REASON"
  [[ "$DECL_RUN_EPOCH"      =~ ^[0-9]{1,11}$     ]] || refuse declaration-malformed "malformed run-epoch: $DECL_RUN_EPOCH"
  [[ "$DECL_DECLARED_EPOCH" =~ ^[0-9]{1,11}$     ]] || refuse declaration-malformed "malformed declared-epoch: $DECL_DECLARED_EPOCH"

  load_reason_registry
  reason_known "$DECL_REASON" || refuse declaration-unknown-reason "reason not in the shipped registry: $DECL_REASON"

  DECL_RUN_EPOCH=$((10#$DECL_RUN_EPOCH))
  DECL_DECLARED_EPOCH=$((10#$DECL_DECLARED_EPOCH))

  [ "$DECL_RUN_EPOCH" -eq "$STATE_START_EPOCH" ] \
    || refuse declaration-foreign-run "declaration run-epoch $DECL_RUN_EPOCH differs from state start_epoch $STATE_START_EPOCH"
  [ "$DECL_DECLARED_EPOCH" -ge "$DECL_RUN_EPOCH" ] \
    || refuse declaration-precedes-run "declared-epoch $DECL_DECLARED_EPOCH precedes run-epoch $DECL_RUN_EPOCH"

  if [ "$DECL_DECLARED_EPOCH" -gt "$STATE_MTIME" ]; then
    DECL_STATE="fresh"
  else
    DECL_STATE="superseded"
  fi
}

if [ -e "$DECL_PATH" ]; then
  [ -f "$DECL_PATH" ] || refuse declaration-unreadable "declaration path is not a regular file: $DECL_PATH"
  parse_declaration "$DECL_PATH"
fi

# --- emission: the SOLE place a verdict is decided and written; step 7 (the
# --out write) happens before step 8 (stdout), so a failed write replaces the
# verdict with OBSERVE_ERROR rather than letting a timer read a stale file
# while stdout claims health.
write_out() {  # $1=token $2=reason $3=state-age $4=git-age
  local tok="$1" reason="$2" sage="$3" gage="$4" outdir tmp
  [ -L "$OUT_PATH" ] && return 1
  outdir="$(dirname -- "$OUT_PATH")" || return 1
  [ -d "$outdir" ] || return 1
  tmp="$(mktemp "$outdir/.liveness-verdict.XXXXXX" 2>/dev/null)" || return 1
  {
    printf 'liveness-verdict 1\n'
    printf 'verdict %s\n' "$tok"
    printf 'reason %s\n' "$reason"
    printf 'state-age %s\n' "$sage"
    printf 'git-age %s\n' "$gage"
    printf 'liveness-verdict-end\n'
  } > "$tmp" 2>/dev/null || { rm -f -- "$tmp" 2>/dev/null || true; return 1; }
  mv -f -- "$tmp" "$OUT_PATH" 2>/dev/null || { rm -f -- "$tmp" 2>/dev/null || true; return 1; }
  return 0
}

emit_final() {  # $1 = TOKEN (RUNNING|WAITING|STALLED|DEAD) $2 = reason context (may be empty)
  local tok="$1" reason="${2:-none}" code sage gage
  case "$tok" in
    RUNNING) code=0 ;;
    WAITING) code=3 ;;
    STALLED) code=4 ;;
    DEAD)    code=5 ;;
    *) refuse unclassified "emit_final called with an unrecognized token: $tok" ;;
  esac
  sage="${A_STATE:-n/a}"
  gage="${A_GIT:-n/a}"
  if [ -n "$OUT_PATH" ]; then
    write_out "$tok" "$reason" "$sage" "$gage" || refuse out-unwritable "failed to write --out document: $OUT_PATH"
  fi
  printf '%s\n' "$tok"
  exit "$code"
}

if [ "$DECL_STATE" = "fresh" ]; then
  emit_final WAITING "$DECL_REASON"
fi

DECL_CTX="none"
if [ "$DECL_STATE" = "superseded" ]; then
  DECL_CTX="superseded"
  printf 'check-liveness: declaration-superseded: declared-epoch is not later than the state file mtime; the wait has ended\n' >&2 || true
fi

# --- step 5: HEAD's committer epoch and its non-negative age — only reached
# when the declaration is absent or superseded (a fresh one already exited
# above, per DP8, which is why WAITING never requires HEAD to resolve).
if ! HEAD_EPOCH_RAW="$(git log -1 --format=%ct HEAD 2>/dev/null)"; then
  refuse git-unreadable "HEAD does not resolve"
fi
[ -n "$HEAD_EPOCH_RAW" ] || refuse git-unreadable "HEAD does not resolve"
[[ "$HEAD_EPOCH_RAW" =~ ^[0-9]{1,11}$ ]] || refuse git-unreadable "HEAD committer epoch not a bounded decimal: $HEAD_EPOCH_RAW"
HEAD_EPOCH=$((10#$HEAD_EPOCH_RAW))
A_GIT=$((NOW - HEAD_EPOCH))
[ "$A_GIT" -ge 0 ] || refuse clock-skew "now is earlier than HEAD's committer epoch"

# --- step 6: the ladder. RUNNING is reachable from exactly this one emit
# site, on positive evidence only (A_STATE within the stall band, a
# resolvable HEAD, and no unresolved declaration) — never a fallthrough.
if [ "$A_STATE" -le "$STALL_AFTER" ]; then
  emit_final RUNNING "$DECL_CTX"
elif [ "$A_STATE" -le "$DEAD_AFTER" ]; then
  emit_final STALLED "$DECL_CTX"
else
  if [ "$A_GIT" -le "$DEAD_AFTER" ]; then
    emit_final STALLED "$DECL_CTX"
  else
    emit_final DEAD "$DECL_CTX"
  fi
fi

# --- step 8: every branch above exits explicitly; this is reached only if a
# future edit adds a path that falls through — the last statement, so falling
# off the end of the file can never be read as a healthy exit 0.
# shellcheck disable=SC2317  # deliberately unreachable under correct control
# flow (AC3's own static requirement); it is the fail-closed backstop.
refuse unclassified "internal defect: fell through the classification ladder with no verdict emitted"
