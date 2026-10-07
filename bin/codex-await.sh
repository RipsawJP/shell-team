#!/usr/bin/env bash
# codex-await.sh — bounded wait on a launched Codex pass's `--json` event
# stream (T-1178; GitHub issue #695).
#
# `codex exec` appends piped stdin to its prompt and waits for EOF even when a
# prompt argument is given. In a sub-agent's Bash tool, stdin can be an open
# pipe that never closes, so the shipped bare `codex exec …` line prints only
# `Reading additional input from stdin...` and never emits `thread.started`.
# The reviewer roles launch that line with the Bash tool's run_in_background
# parameter and then call this script against the launch's output capture, so
# no wait in either role is left unbounded. This script reads one watched file
# and never writes anything, never reads stdin and never executes `codex`.
#
# Usage:
#   codex-await.sh --event start|end --watch <file> --timeout <seconds>
#   codex-await.sh --help | -h
#
# Closed table (the watched file is re-read about once per second):
#   --event start  a line of the file is a single-line JSON event whose type is
#                  `thread.started` and whose thread_id wholly matches
#                  [A-Za-z0-9_-]{1,128} (either key order), seen before the
#                  timeout                 exit 0, stdout exactly that id
#   --event end    a line is a JSON event whose type is `turn.completed` or
#                  `turn.failed`, seen before the timeout
#                                          exit 0, stdout exactly that type
#   no such line by --timeout seconds (file absent, empty, or carrying only
#   other bytes — the stdin notice, a bare mention of the word, a
#   thread.started with no or a malformed thread_id)
#                                          exit 1, stdout empty, stderr: a
#                  first line containing `no-thread-started` (start) or
#                  `no-terminal-event` (end), then at most the last 4096 bytes
#                  of the file (or a note that it is absent)
#   bad / missing / unknown / extra arguments, --event other than start/end,
#   --timeout not an integer in 1..570, no --watch
#                                          exit 2, stdout empty, stderr: one
#                  line containing `usage`
# --help / -h: exit 0, usage on stdout, nothing else touched.
# A timeout exit happens no earlier than about the timeout and no later than
# five seconds after it. Only a line that is wholly a JSON event of the right
# type counts: a message item that merely quotes the event name never does.
# Pure bash 3.2-compatible, zero-dependency beyond grep/tail/sleep.
#
# #695 / T-1178.

set -euo pipefail

refuse() {  # $1 = exit code, $2 = one fixed stderr line
  printf 'codex-await: %s\n' "$2" >&2 || true
  exit "$1"
}

# --- self-location, symlink-safe (ported from check-review-provider.sh) ------
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || refuse 2 "usage: cannot resolve this script's symlink"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || refuse 2 "usage: cannot resolve this script's directory"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || refuse 2 "usage: cannot resolve this script's directory"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || refuse 2 "usage: cannot resolve this script's directory"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || refuse 2 "usage: cannot resolve this script's directory"
self_name="$(basename "$script_path")" \
  || refuse 2 "usage: cannot resolve this script's name"
SELF="$SCRIPT_DIR/$self_name"

USAGE="usage: codex-await.sh --event start|end --watch <file> --timeout <1..570>"

# --- argument parsing --------------------------------------------------------
if [ "$#" -eq 1 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || refuse 2 "usage: cannot read this script's own help text"
  exit 0
fi

event="" watch="" timeout_s=""
have_event=0 have_watch=0 have_timeout=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --event)
      [ "$#" -ge 2 ] && [ "$have_event" -eq 0 ] || refuse 2 "$USAGE"
      event="$2"; have_event=1; shift 2 ;;
    --watch)
      [ "$#" -ge 2 ] && [ "$have_watch" -eq 0 ] || refuse 2 "$USAGE"
      watch="$2"; have_watch=1; shift 2 ;;
    --timeout)
      [ "$#" -ge 2 ] && [ "$have_timeout" -eq 0 ] || refuse 2 "$USAGE"
      timeout_s="$2"; have_timeout=1; shift 2 ;;
    *) refuse 2 "$USAGE" ;;
  esac
done
[ "$have_event" -eq 1 ] && [ "$have_watch" -eq 1 ] && [ "$have_timeout" -eq 1 ] \
  || refuse 2 "$USAGE"
case "$event" in start | end) ;; *) refuse 2 "$USAGE" ;; esac
[ -n "$watch" ] || refuse 2 "$USAGE"
case "$timeout_s" in
  "" | *[!0-9]* | 0*) refuse 2 "$USAGE" ;;
esac
[ "${#timeout_s}" -le 3 ] && [ "$timeout_s" -le 570 ] || refuse 2 "$USAGE"

# --- event recognition -------------------------------------------------------
# A line counts only when it is wholly one JSON object whose `type` is the
# event, in the first or the last key position. `thread_id` must wholly match
# the id charset. Regexes live in variables (bash 3.2 quoting rules).
WS='[[:space:]]*'
ID='([A-Za-z0-9_-]{1,128})'
RE_START_A="^${WS}\\{${WS}\"type\"${WS}:${WS}\"thread\\.started\"${WS},${WS}\"thread_id\"${WS}:${WS}\"${ID}\"${WS}(,[^{}]*)?\\}${WS}\$"
RE_START_B="^${WS}\\{${WS}\"thread_id\"${WS}:${WS}\"${ID}\"${WS},${WS}\"type\"${WS}:${WS}\"thread\\.started\"${WS}(,[^{}]*)?\\}${WS}\$"
RE_END_A="^${WS}\\{${WS}\"type\"${WS}:${WS}\"(turn\\.completed|turn\\.failed)\"${WS}(,.*)?\\}${WS}\$"
RE_END_B="^${WS}\\{.*,${WS}\"type\"${WS}:${WS}\"(turn\\.completed|turn\\.failed)\"${WS}\\}${WS}\$"

# scan: prints the id (start) or the type (end) and returns 0 on the first
# qualifying line; returns 1 when there is none. The file is pre-filtered with
# grep so a multi-megabyte stream is not walked line by line in bash.
scan() {
  local cands line rc=0
  [ -f "$watch" ] || return 1
  if [ "$event" = start ]; then
    cands="$(grep -F -- 'thread.started' "$watch" 2>/dev/null)" || rc=$?
  else
    cands="$(grep -E -- 'turn\.(completed|failed)' "$watch" 2>/dev/null)" || rc=$?
  fi
  [ "$rc" -eq 0 ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$event" = start ]; then
      if [[ $line =~ $RE_START_A ]] || [[ $line =~ $RE_START_B ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}" || exit 2
        return 0
      fi
    else
      if [[ $line =~ $RE_END_A ]] || [[ $line =~ $RE_END_B ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}" || exit 2
        return 0
      fi
    fi
  done <<< "$cands"
  return 1
}

# --- bounded wait ------------------------------------------------------------
started=$SECONDS
while :; do
  scan_rc=0
  scan && scan_rc=0 || scan_rc=$?
  if [ "$scan_rc" -eq 0 ]; then
    exit 0
  fi
  elapsed=$((SECONDS - started))
  [ "$elapsed" -lt "$timeout_s" ] || break
  sleep 1
done

# --- timeout: one token line, then a bounded tail of the watched file --------
if [ "$event" = start ]; then token="no-thread-started"; else token="no-terminal-event"; fi
printf 'codex-await: %s after %ss (watched: %s)\n' "$token" "$timeout_s" "$watch" >&2 || true
if [ -f "$watch" ]; then
  tail -c 4096 -- "$watch" >&2 2>/dev/null || true
else
  printf 'codex-await: watched file is absent\n' >&2 || true
fi
exit 1
