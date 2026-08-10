#!/usr/bin/env bash
# log-run.sh — the single canonical writer for Operating-Loop telemetry.
#
# Appends ONE row (one JSON object per line) to the resolved runs dir's
# <loop_id>.jsonl ($TEAM_RUNS_DIR or $RUNS_DIR if set, else team-paths.sh
# resolves it from cwd: .shell-team/runs by default, tasks/runs in a legacy
# layout). Two row shapes share the file (T-1011):
#
#   SPAN row (T-014/T-015, the original shape) — one call into a sub-agent.
#     17 keys, no `kind` key at all. Unchanged by this task, byte-for-byte.
#   EVENT row (T-1011) — a transition the loop made *between* spans: a
#     hand-off, a route-back, a gate verdict, a human stop/GO, a release.
#     9 keys, discriminated by `"kind":"event"`.
#
# `--event <id>` selects event mode; its absence is span mode, unchanged.
# Validates every field before writing — a malformed invocation writes
# NOTHING and exits 2, so the log never gains a corrupt line. Pure bash, no
# JSON library, so it runs anywhere the other bin/ scripts do.
#
# Usage (span mode, unchanged plus the three T-1058 binding flags):
#   log-run.sh <loop_id> --run-id R --seq K --span S --phase P \
#              --iteration N --attempt A --status STATUS \
#              [--model M] [--tokens T] [--tool-uses U] [--duration-ms D] \
#              [--verdict V] [--usd X] [--error E] [--parent-span-id PS] \
#              [--provider P] [--effort E] [--adapter A]
#
# Usage (event mode, T-1011):
#   log-run.sh <loop_id> --run-id R --seq K --event ID \
#              [--from X] [--to Y] [--label L]
#
#   ID ∈ handoff | rework | gate | human | release. `seq` is ONE monotonic
#   counter per run, shared across spans and events, so the rows of a run
#   form a total order. Per-event-id requiredness (absent, null, or an
#   empty-string value all count as "not provided" — an empty string is
#   treated exactly as absent, since jstr below renders both as JSON null):
#     handoff  --from required, --to required
#     rework   --from required, --to required, --label required
#     gate     --from required, --label required
#     human    --label required
#     release  none required
#   All 16 span-only flags (--span --phase --iteration --attempt --status
#   --model --tokens --tool-uses --duration-ms --verdict --usd --error
#   --parent-span-id --provider --effort --adapter) are forbidden in event
#   mode (exit 2, nothing written); `--from`/`--to`/`--label` are forbidden
#   in span mode (same). `--event` together with `--span` is rejected by name.
#
# Required (span mode): loop_id (positional), --run-id, --seq, --span,
#           --phase, --iteration, --attempt, --status.
# Nullable (span mode, omit => null in the row): --model --tokens
#           --tool-uses --duration-ms --verdict --usd --error
#           --parent-span-id --provider --effort --adapter.
#
# status  ∈ success | error | timeout | skipped | stopped
# verdict ∈ PASS | FAIL | APPROVE | REQUEST_CHANGES   (or omit => null)
#
# T-1058 — the resolved binding, recorded on the span rather than discarded:
#   --provider, --adapter ∈ a bare lower-case token, the same character class
#     bin/check-binding.sh's ROLE_RE governs role/provider/adapter with
#     (^[a-z][a-z0-9-]*$); a malformed value is a validation error (exit 2,
#     nothing written) — `model` stays unvalidated and opaque, deliberately.
#   --effort ∈ the same character class, EXCEPT the binding grammar's own and
#     only "no value" spelling, the literal `-`: `--effort -` records
#     `"effort":null`, never the two-character string `"-"`, because that is
#     the row grammar's own spelling of the same fact. Any other malformed
#     --effort value is a validation error exactly like --provider/--adapter.
#   All three are nullable (omitted => null) and are appended AFTER
#   `parent_span_id` in the emitted row, so the frozen seventeen keep their
#   order and their offsets and a row written without them is byte-identical
#   to one written before this task.
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
# Version skew (T-1011, D5 — confirmed, not redesigned): if this script
# writes an event row and the SIBLING check-run.sh predates event-row
# support, the post-write self-check above reports the row invalid, so this
# script exits 1 with the row already on disk — never rolled back. That is
# exactly the behavior this header already documents for every other
# self-check failure: every in-repo caller wraps this call in `|| true`, and
# telemetry is best-effort by contract, so no new mechanism is needed here.
# The reverse skew (an old writer, a new checker) is inert: span rows written
# by an old log-run.sh are still valid under the new checker.
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
PROVIDER="" EFFORT="" ADAPTER=""
EVENT="" FROM="" TO="" LABEL=""

# Every flag actually passed on the command line, verbatim, in encounter
# order — used below to reject a forbidden flag by PRESENCE, independent of
# its value (an explicit-but-empty --from must still be rejected in span
# mode, for example; presence, not value, is what D5 forbids).
SEEN=()
seen() {
  local want="$1" f
  # Guard the empty-array case before expanding "${SEEN[@]}" (the repo's
  # existing idiom, e.g. bin/rollup-runs.sh's "${#LINES[@]} -gt 0" check):
  # under macOS default /bin/bash 3.2, expanding "${arr[@]}" on a genuinely
  # empty array raises "unbound variable" under `set -u`, even though the
  # array itself was declared — a zero-flag invocation (`log-run.sh
  # <loop_id>` alone) would otherwise crash exit 1 instead of the documented
  # usage exit 2 (Codex round-1 Major #1).
  [[ "${#SEEN[@]}" -gt 0 ]] || return 1
  for f in "${SEEN[@]}"; do [[ "$f" == "$want" ]] && return 0; done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id|--seq|--span|--phase|--iteration|--attempt|--status|--model|--tokens|--tool-uses|--duration-ms|--verdict|--usd|--error|--parent-span-id|--provider|--effort|--adapter|--event|--from|--to|--label)
      [[ $# -ge 2 ]] || die "missing value for $1"
      SEEN+=("$1")
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
        --provider)       PROVIDER="$2" ;;
        --effort)         EFFORT="$2" ;;
        --adapter)        ADAPTER="$2" ;;
        --event)          EVENT="$2" ;;
        --from)           FROM="$2" ;;
        --to)             TO="$2" ;;
        --label)          LABEL="$2" ;;
      esac
      shift 2
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

if seen --event; then MODE="event"; else MODE="span"; fi

# --- required fields shared by both modes ---
[[ -n "$RUN_ID" ]] || die "missing required --run-id"
[[ "$SEQ" =~ ^[0-9]{1,9}$ ]] || die "missing/invalid --seq (non-negative int): '${SEQ}'"

SPAN_ONLY_FLAGS=(--span --phase --iteration --attempt --status --model --tokens --tool-uses --duration-ms --verdict --usd --error --parent-span-id --provider --effort --adapter)
EVENT_ONLY_FLAGS=(--from --to --label)

if [[ "$MODE" == "event" ]]; then
  # D5: --event and --span are named explicitly with a frozen message; the
  # other 15 span-only flags (T-1058 adds --provider/--effort/--adapter to
  # the array above) are rejected the same way (exit 2, nothing written)
  # without a frozen message of their own — this mirrors D2's shape-mixing
  # rule 1:1 rather than deferring the rejection to lint time.
  seen --span && die "--event and --span are mutually exclusive"
  for f in "${SPAN_ONLY_FLAGS[@]}"; do
    [[ "$f" == "--span" ]] && continue
    seen "$f" && die "$f is not allowed with --event"
  done

  case "$EVENT" in
    handoff|rework|gate|human|release) : ;;
    *) die "invalid --event '${EVENT}' (handoff|rework|gate|human|release)" ;;
  esac

  # Per-event-id requiredness (D3's table). "Required" = present and
  # non-empty; an omitted or empty-string value is a usage error here.
  req_from=0 req_to=0 req_label=0
  case "$EVENT" in
    handoff) req_from=1; req_to=1 ;;
    rework)  req_from=1; req_to=1; req_label=1 ;;
    gate)    req_from=1; req_label=1 ;;
    human)   req_label=1 ;;
    release) : ;;
  esac
  [[ "$req_from"  -eq 1 && -z "$FROM"  ]] && die "event '${EVENT}' requires non-empty --from"
  [[ "$req_to"    -eq 1 && -z "$TO"    ]] && die "event '${EVENT}' requires non-empty --to"
  [[ "$req_label" -eq 1 && -z "$LABEL" ]] && die "event '${EVENT}' requires non-empty --label"
else
  for f in "${EVENT_ONLY_FLAGS[@]}"; do
    seen "$f" && die "$f is not allowed in span mode"
  done

  [[ -n "$SPAN"  ]] || die "missing required --span"
  [[ -n "$PHASE" ]] || die "missing required --phase"
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

  # --- T-1058: the resolved binding (nullable) ---
  # --provider/--adapter are bare lower-case tokens, the same character class
  # bin/check-binding.sh's ROLE_RE governs role/provider/adapter with
  # ('^[a-z][a-z0-9-]*$'); model stays unvalidated and opaque, deliberately
  # (DP1). --effort shares that class EXCEPT the binding grammar's own and
  # only "no value" spelling, the literal '-' (bin/check-binding.sh L364,
  # where effort is the one field exempted from the token class): '--effort
  # -' is mapped to JSON null below rather than admitting a second spelling
  # of the same fact.
  BINDING_TOKEN_RE='^[a-z][a-z0-9-]*$'
  [[ -z "$PROVIDER" || "$PROVIDER" =~ $BINDING_TOKEN_RE ]] || die "invalid --provider '${PROVIDER}' (lower-case token: ^[a-z][a-z0-9-]*\$)"
  [[ -z "$ADAPTER"  || "$ADAPTER"  =~ $BINDING_TOKEN_RE ]] || die "invalid --adapter '${ADAPTER}' (lower-case token: ^[a-z][a-z0-9-]*\$)"
  EFFORT_OUT="$EFFORT"
  if [[ -n "$EFFORT" && "$EFFORT" != "-" ]]; then
    [[ "$EFFORT" =~ $BINDING_TOKEN_RE ]] || die "invalid --effort '${EFFORT}' (lower-case token, or '-' for none)"
  elif [[ "$EFFORT" == "-" ]]; then
    EFFORT_OUT=""   # the binding grammar's "-" spelling maps to JSON null
  fi
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

if [[ "$MODE" == "event" ]]; then
  ROW="{"
  ROW+="$(jstr loop_id "$LOOP_ID"),"
  ROW+="$(jstr run_id "$RUN_ID"),"
  ROW+="$(jnum seq "$SEQ"),"
  ROW+="$(jstr ts "$TS"),"
  ROW+="$(jstr kind "event"),"
  ROW+="$(jstr event "$EVENT"),"
  ROW+="$(jstr from "$FROM"),"
  ROW+="$(jstr to "$TO"),"
  ROW+="$(jstr label "$LABEL")"
  ROW+="}"
else
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
  ROW+="$(jstr parent_span_id "$PARENT"),"
  ROW+="$(jstr provider "$PROVIDER"),"
  ROW+="$(jstr effort "$EFFORT_OUT"),"
  ROW+="$(jstr adapter "$ADAPTER")"
  ROW+="}"
fi

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
