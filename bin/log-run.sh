#!/usr/bin/env bash
# log-run.sh — the single canonical writer for Operating-Loop telemetry.
#
# Appends ONE span row (one JSON object per line) to the resolved runs dir's
# <loop_id>.jsonl ($TEAM_RUNS_DIR or $RUNS_DIR if set, else team-paths.sh
# resolves it from cwd: .shell-team/runs by default, tasks/runs in a legacy layout),
# following the schema finalized in
# T-014 (docs/specs/T-014-telemetry-spike.md). Validates every field before
# writing — a malformed invocation writes NOTHING and exits 2, so the log never
# gains a corrupt line. Pure bash, no JSON library, so it runs anywhere the
# other bin/ scripts do.
#
# Usage:
#   log-run.sh <loop_id> --run-id R --seq K --span S --phase P \
#              --iteration N --attempt A --status STATUS \
#              [--model M] [--tokens T] [--tool-uses U] [--duration-ms D] \
#              [--verdict V] [--usd X] [--error E] [--parent-span-id PS]
#
# Required: loop_id (positional), --run-id, --seq, --span, --phase,
#           --iteration, --attempt, --status.
# Nullable (omit => null in the row): --model --tokens --tool-uses
#           --duration-ms --verdict --usd --error --parent-span-id.
#
# status  ∈ success | error | timeout | skipped | stopped
# verdict ∈ PASS | FAIL | APPROVE | REQUEST_CHANGES   (or omit => null)
#
# Telemetry is observability-only: callers should treat a non-zero exit as
# "telemetry not recorded" and carry on — it must never break the loop.
#
# Post-write self-check (T-042): immediately after a successful append, the
# exact row just written is re-linted via the sibling check-run.sh's
# single-line mode (`check-run.sh --line`) — defense-in-depth against a bug in
# this script's OWN JSON-serialization producing a structurally malformed line
# despite well-formed CLI input. The row already on disk is NEVER rolled back
# on a self-check failure; it only surfaces as this script's own non-zero
# exit, which every existing caller already treats as advisory/best-effort.
# If check-run.sh is missing from the sibling bin/ dir, or not
# readable/executable, the self-check is skipped entirely and this script
# still exits 0 — it must never hard-depend on check-run.sh being present.
#
# Exit: 0 = row appended (and, if checked, passed self-check), 1 = row
#       appended but failed the post-write self-check, 2 = validation error
#       (nothing written).

set -euo pipefail

die() { printf 'log-run: %s\n' "$1" >&2 || true; exit 2; }

# Resolve this script's own directory (symlink-safe) so we can call the sibling
# team-paths.sh resolver regardless of cwd / how we were invoked.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

LOOP_ID="${1:-}"
[[ -z "$LOOP_ID" || "$LOOP_ID" == --* ]] && die "missing <loop_id> as first argument"
# LOOP_ID becomes a filename (<loop_id>.jsonl) under the runs dir, so constrain it
# to a safe charset — a '/' or other path char could write outside the runs dir.
[[ "$LOOP_ID" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid <loop_id> '$LOOP_ID' (allowed chars: A-Za-z0-9 . _ -)"
shift

RUN_ID="" SEQ="" SPAN="" PHASE="" ITERATION="" ATTEMPT="" STATUS=""
MODEL="" TOKENS="" TOOL_USES="" DURATION_MS="" VERDICT="" USD="" ERROR="" PARENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id|--seq|--span|--phase|--iteration|--attempt|--status|--model|--tokens|--tool-uses|--duration-ms|--verdict|--usd|--error|--parent-span-id)
      [[ $# -ge 2 ]] || die "missing value for $1"
      case "$1" in
        --run-id)         RUN_ID="$2" ;;
        --seq)            SEQ="$2" ;;
        --span)           SPAN="$2" ;;
        --phase)          PHASE="$2" ;;
        --iteration)      ITERATION="$2" ;;
        --attempt)        ATTEMPT="$2" ;;
        --status)         STATUS="$2" ;;
        --model)          MODEL="$2" ;;
        --tokens)         TOKENS="$2" ;;
        --tool-uses)      TOOL_USES="$2" ;;
        --duration-ms)    DURATION_MS="$2" ;;
        --verdict)        VERDICT="$2" ;;
        --usd)            USD="$2" ;;
        --error)          ERROR="$2" ;;
        --parent-span-id) PARENT="$2" ;;
      esac
      shift 2
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

# --- required fields ---
[[ -n "$RUN_ID"    ]] || die "missing required --run-id"
[[ -n "$SPAN"      ]] || die "missing required --span"
[[ -n "$PHASE"     ]] || die "missing required --phase"
[[ "$SEQ"       =~ ^[0-9]{1,9}$ ]] || die "missing/invalid --seq (non-negative int): '${SEQ}'"
[[ "$ITERATION" =~ ^[0-9]{1,9}$ ]] || die "missing/invalid --iteration (non-negative int): '${ITERATION}'"
[[ "$ATTEMPT"   =~ ^[0-9]{1,9}$ ]] || die "missing/invalid --attempt (non-negative int): '${ATTEMPT}'"

case "$STATUS" in
  success|error|timeout|skipped|stopped) : ;;
  *) die "invalid --status '${STATUS}' (success|error|timeout|skipped|stopped)" ;;
esac

# --- nullable numeric fields ---
for pair in "tokens:$TOKENS" "tool-uses:$TOOL_USES" "duration-ms:$DURATION_MS"; do
  name="${pair%%:*}"; val="${pair#*:}"
  [[ -z "$val" || "$val" =~ ^[0-9]{1,12}$ ]] || die "--${name} must be a non-negative integer: '${val}'"
done
[[ -z "$USD" || "$USD" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--usd must be a non-negative number: '${USD}'"

# --- verdict enum (nullable) ---
if [[ -n "$VERDICT" ]]; then
  case "$VERDICT" in
    PASS|FAIL|APPROVE|REQUEST_CHANGES) : ;;
    *) die "invalid --verdict '${VERDICT}' (PASS|FAIL|APPROVE|REQUEST_CHANGES)" ;;
  esac
fi

# Escape a string for embedding in a JSON value, PRESERVING content: backslash
# and double-quote are escaped (backslash first so we don't double-escape), and
# any control chars (tabs/CR/newlines included) collapse to spaces. This always
# yields valid JSON without a full encoder, and avoids tr octal-range quirks.
jesc() {
  local s="$1"
  s="${s//\\/\\\\}"   # \  -> \\   (must run first)
  s="${s//\"/\\\"}"   # "  -> \"
  printf '%s' "$s" | tr '\t\r\n' '   ' | tr -d '[:cntrl:]'
}

# JSON helpers: emit `"key":"value"` (string) or `"key":null`, and number-or-null.
jstr() { if [[ -z "$2" ]]; then printf '"%s":null' "$1"; else printf '"%s":"%s"' "$1" "$(jesc "$2")"; fi; }
jnum() { if [[ -z "$2" ]]; then printf '"%s":null' "$1"; else printf '"%s":%s' "$1" "$2"; fi; }

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

ROW="{"
ROW+="$(jstr loop_id "$LOOP_ID"),"
ROW+="$(jstr run_id "$RUN_ID"),"
ROW+="$(jnum seq "$SEQ"),"
ROW+="$(jstr ts "$TS"),"
ROW+="$(jstr span "$SPAN"),"
ROW+="$(jstr phase "$PHASE"),"
ROW+="$(jnum iteration "$ITERATION"),"
ROW+="$(jnum attempt "$ATTEMPT"),"
ROW+="$(jstr status "$STATUS"),"
ROW+="$(jstr model "$MODEL"),"
ROW+="$(jnum tokens "$TOKENS"),"
ROW+="$(jnum tool_uses "$TOOL_USES"),"
ROW+="$(jnum duration_ms "$DURATION_MS"),"
ROW+="$(jstr verdict "$VERDICT"),"
ROW+="$(jnum usd "$USD"),"
ROW+="$(jstr error "$ERROR"),"
ROW+="$(jstr parent_span_id "$PARENT")"
ROW+="}"

# Runs dir resolution (precedence):
#   1. $TEAM_RUNS_DIR  — explicit, exported by an orchestrator
#   2. $RUNS_DIR       — back-compat alias / test fixtures
#   3. self-resolve from cwd via the sibling team-paths.sh (default
#      .shell-team/runs, or tasks/runs in a legacy layout)
# Self-resolving (3) is the safe default: env vars do NOT persist across separate
# Bash tool calls, so an orchestrator's earlier `export TEAM_RUNS_DIR` may not be
# in scope here. Relying on it previously made log-run fall back to the hardcoded
# tasks/runs and leak a tasks/ dir into a .shell-team/ host (T-026). The
# resolver-failure fallback is `.shell-team/runs` (the default layout), NOT
# tasks/runs: if team-paths.sh is missing/erroring (broken install, malformed
# TEAM_RUN_BASE), telemetry must never create a tasks/ dir in a default-layout
# host. Telemetry is best-effort, so we degrade to .shell-team/runs rather than abort.
if [[ -n "${TEAM_RUNS_DIR:-}" ]]; then
  RUNS_DIR="$TEAM_RUNS_DIR"
elif [[ -z "${RUNS_DIR:-}" ]]; then
  RUNS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get runs 2>/dev/null || printf '.shell-team/runs')"
fi
mkdir -p "$RUNS_DIR" || die "cannot create runs dir: $RUNS_DIR"
printf '%s\n' "$ROW" >> "$RUNS_DIR/${LOOP_ID}.jsonl" || die "cannot append to $RUNS_DIR/${LOOP_ID}.jsonl"

# Post-write self-check (T-042, best-effort — see header comment). The row
# above is already on disk and is NEVER rolled back by anything below: a
# self-check failure only changes this script's own exit code. check-run.sh
# must be both readable and executable for the check to run at all; if it is
# missing/unreadable/non-executable, skip silently and exit 0 (never
# hard-depend on it).
CHECK_RUN="$SCRIPT_DIR/check-run.sh"
if [[ -r "$CHECK_RUN" && -x "$CHECK_RUN" ]]; then
  # Any non-zero from check-run --line surfaces as exit 1 here — whether it is
  # a genuine lint failure (check-run exit 1) or check-run's own error/version
  # skew (exit 2). We intentionally do not distinguish: the row is already
  # persisted, and every caller treats log-run's exit as advisory (all in-repo
  # callers wrap it with `|| true`), so conflating the two cannot break a
  # caller. Finer discrimination is future hardening, not correctness.
  if ! "$CHECK_RUN" --line "$ROW" >&2; then
    exit 1
  fi
fi

exit 0
