#!/usr/bin/env bash
# log-run.sh — the single canonical writer for Operating-Loop telemetry.
#
# Appends ONE row (one JSON object per line) to the resolved runs dir's
# <loop_id>.jsonl ($TEAM_RUNS_DIR or $RUNS_DIR if set, else team-paths.sh
# resolves it from cwd: .shell-team/runs by default, tasks/runs in a legacy
# layout). Two row shapes share the file (T-1011):
#
#   SPAN row (T-014/T-015, the original shape) — one call into a sub-agent.
#     21 keys, no `kind` key at all. Unchanged by this task, byte-for-byte.
#   EVENT row (T-1011) — a transition the loop made *between* spans: a
#     hand-off, a route-back, a gate verdict, a human stop/GO, a release.
#     9 keys, discriminated by `"kind":"event"`.
#
# `--event <id>` selects event mode; its absence is span mode, unchanged.
# Validates every field before writing — a malformed invocation writes
# NOTHING and exits 2, so the log never gains a corrupt line. Pure bash, no
# JSON library, so it runs anywhere the other bin/ scripts do.
#
# Usage (span mode, unchanged plus the three T-1058 binding flags, the
# T-1072 --instance discriminator, and T-1076's `--seq K|auto`):
#   log-run.sh <loop_id> --run-id R --seq K|auto --span S --phase P \
#              --iteration N --attempt A --status STATUS \
#              [--model M] [--tokens T] [--tool-uses U] [--duration-ms D] \
#              [--verdict V] [--usd X] [--error E] [--parent-span-id PS] \
#              [--provider P] [--effort E] [--adapter A] [--instance I]
#
# Usage (event mode, T-1011):
#   log-run.sh <loop_id> --run-id R --seq K|auto --event ID \
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
#   All 17 span-only flags (--span --phase --iteration --attempt --status
#   --model --tokens --tool-uses --duration-ms --verdict --usd --error
#   --parent-span-id --provider --effort --adapter --instance) are forbidden
#   in event mode (exit 2, nothing written); `--from`/`--to`/`--label` are
#   forbidden in span mode (same). `--event` together with `--span` is
#   rejected by name.
#
# Required (span mode): loop_id (positional), --run-id, --seq, --span,
#           --phase, --iteration, --attempt, --status.
# Nullable (span mode, omit => null in the row): --model --tokens
#           --tool-uses --duration-ms --verdict --usd --error
#           --parent-span-id --provider --effort --adapter --instance.
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
#   order and their offsets, and a row written without them keeps every key
#   AHEAD of them at the same name, order and byte offset as one written
#   before this task — frozen-PREFIX preservation, not whole-row byte
#   identity: the writer always emits every nullable key, so a row written
#   without --provider/--effort/--adapter still carries
#   "provider":null,"effort":null,"adapter":null where a pre-T-1058 row
#   carried no such keys at all.
#
# T-1072 — the per-instance discriminator, appended AFTER `adapter` so the
# T-1058 fields (and everything ahead of them) keep their order and offsets
# too:
#   --instance ∈ the SAME character class as --provider/--adapter
#     (BINDING_TOKEN_RE, ^[a-z][a-z0-9-]*$), reused rather than widened — one
#     identifier grammar, not two. Nullable: omitted or an explicit empty
#     value both record "instance":null. A bare numeric id (`--instance 2`)
#     is refused by that same character class (it requires a leading
#     lower-case letter): the field NAMES the instance a merged hand-off
#     record stays attributable to, and a name that is only a count carries
#     nothing to attribute by — spell instance ids role-qualified (`qa-1`,
#     `qa-2`, `engineer-a`), which is legal under the existing class. The
#     bare `-` is ALSO refused here (it fails the same leading-letter
#     requirement), unlike --effort: `-` is the binding grammar's own "no
#     value" spelling for `--effort` only, and --instance has no such
#     spelling of its own — admitting a second spelling of "no instance"
#     beside plain omission is exactly the ambiguity that exemption exists
#     to prevent. Declared, never observed, exactly like
#     provider/effort/adapter; validated by the writer only — bin/check-run.sh
#     does not charset-check it.
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
# T-1076 — the append lock, `--seq auto`, and the new refusal exit code:
#   Every append (both modes) is serialized behind a directory lock, created
#   with a plain `mkdir` (NEVER `mkdir -p`, whose success on an existing
#   directory would defeat the whole mechanism) at
#   <runs>/.<loop_id>.jsonl.lock — a directory rather than a file, so
#   `mkdir` alone gives atomic acquire-or-fail with no auxiliary
#   file-descriptor state, and its dot-prefixed, `.lock`-suffixed name is
#   invisible to the one `*.jsonl` glob enumeration of the runs dir in this
#   repository (bin/gen-loop-replay.sh) twice over rather than once.
#
#   The bounded wait defaults to 10 seconds, overridable via
#   `TEAM_LOG_LOCK_TIMEOUT` (a positive integer number of seconds). An
#   UNSET value substitutes the default before validation ever runs (the
#   same shape bin/check-acs.sh already uses for CHECK_ACS_TIMEOUT), so it
#   is silent; a PRESENT value that is non-integer, zero or negative also
#   falls back to the default, but additionally prints a warning on stderr
#   naming TEAM_LOG_LOCK_TIMEOUT. If the lock cannot be acquired inside the
#   bound, the writer writes NOTHING and exits 3 — a code distinct from
#   0/1/2 — and its stderr names the lock directory's full path and its
#   mtime. The lock is NEVER stolen: no age heuristic, no PID probe, no
#   silent steal. Release uses `rmdir` ONLY — a forced, recursive removal
#   is never spelled anywhere in this script — so release can never destroy contents
#   a sibling process left inside the lock directory; release is wired to
#   EXIT/INT/TERM and fires only for a lock THIS process itself acquired
#   (a guard flag set at acquisition — never at release time). The one
#   residual case is disclosed rather than engineered away: a writer killed
#   with SIGKILL while holding the lock leaves the directory behind, and
#   every later write to that file refuses (exit 3) until an operator
#   removes it by hand — `rmdir <the printed path>` is always safe, since
#   `rmdir` itself refuses to remove a non-empty directory.
#
#   `--seq auto` is a new, CASE-SENSITIVE accepted literal on the existing
#   `--seq` flag (`AUTO`/`Auto` stay validation errors, exit 2, nothing
#   written). A caller-supplied integer always wins and is written verbatim
#   exactly as before; the target file is consulted ONLY when the literal
#   `auto` is passed. The derived value is one more than the greatest `seq`
#   among the lines of the target file whose `run_id` equals this call's
#   run id — PER run_id, not per file (one file interleaves many run_ids,
#   and the file's last line is routinely a different run than the one
#   being written, so `tail -1` would be wrong) — and is 1 when no such
#   line exists, including when the file itself does not yet exist. Both
#   row shapes (span and event) share one counter. The scan is
#   boundary-anchored on `{` or `,`, the same way bin/check-run.sh's
#   key_present and bin/rollup-runs.sh's field_str already anchor a key, so
#   a key that is a substring of a longer key, or one that appears inside a
#   string value, can never match; a line carrying this run_id but no
#   parseable integer seq contributes nothing to the scan — a documented
#   limit over hand-corrupted input, not a silent behavior. The derived
#   value must itself satisfy the existing `^[0-9]{1,9}$` grammar: at the
#   nine-digit ceiling, `auto` is a VALIDATION ERROR (nothing written, exit
#   2) rather than a row carrying an out-of-grammar counter — this is the
#   validation code, not the lock-timeout code, because nothing about the
#   lock failed. The scan and the append happen under ONE acquisition of
#   the lock, so no second writer can take the same number in between.
#
# Exit: 0 = row appended (and, if checked, passed self-check), 1 = row
#       appended but failed the post-write self-check, 2 = validation error
#       (nothing written), 3 = the append lock could not be acquired within
#       the bounded wait (nothing written) — the writer never steals a lock
#       it did not create.

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
PROVIDER="" EFFORT="" ADAPTER="" INSTANCE=""
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
    --run-id|--seq|--span|--phase|--iteration|--attempt|--status|--model|--tokens|--tool-uses|--duration-ms|--verdict|--usd|--error|--parent-span-id|--provider|--effort|--adapter|--instance|--event|--from|--to|--label)
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
        --instance)       INSTANCE="$2" ;;
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
# T-1076: the literal `auto` (case-sensitive) defers the actual --seq value
# to a per-run_id scan of the target file, taken under the append lock
# below; a caller-supplied integer is validated here exactly as before and
# is never subject to that scan.
SEQ_AUTO=0
if [[ "$SEQ" == "auto" ]]; then
  SEQ_AUTO=1
else
  [[ "$SEQ" =~ ^[0-9]{1,9}$ ]] || die "missing/invalid --seq (non-negative int, or 'auto'): '${SEQ}'"
fi

SPAN_ONLY_FLAGS=(--span --phase --iteration --attempt --status --model --tokens --tool-uses --duration-ms --verdict --usd --error --parent-span-id --provider --effort --adapter --instance)
EVENT_ONLY_FLAGS=(--from --to --label)

if [[ "$MODE" == "event" ]]; then
  # D5: --event and --span are named explicitly with a frozen message; the
  # other 16 span-only flags (T-1058 adds --provider/--effort/--adapter and
  # T-1072 adds --instance to the array above) are rejected the same way
  # (exit 2, nothing written) without a frozen message of their own — this
  # mirrors D2's shape-mixing rule 1:1 rather than deferring the rejection
  # to lint time.
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

  # --- T-1072: the per-instance discriminator (nullable) ---
  # Reuses BINDING_TOKEN_RE verbatim rather than declaring a second
  # constant — one identifier grammar for --provider/--adapter/--instance,
  # not two. Unlike --effort, --instance has no "no value" spelling of its
  # own: the bare '-' fails this same regex (its required leading character
  # is [a-z]), so it is refused here exactly like any other malformed value
  # — deliberately, per the header paragraph above.
  [[ -z "$INSTANCE" || "$INSTANCE" =~ $BINDING_TOKEN_RE ]] || die "invalid --instance '${INSTANCE}' (lower-case token: ^[a-z][a-z0-9-]*\$)"
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

# T-1076 — compute_auto_seq <file> <run_id>: one more than the greatest `seq`
# among <file>'s lines whose `run_id` equals <run_id>, or 1 if none exist
# (including when <file> does not exist yet). Boundary-anchored on `{`/`,`
# exactly like bin/check-run.sh's key_present and bin/rollup-runs.sh's
# field_str, so a key that is a substring of a longer key, or one that
# appears inside a string value, can never match. A line carrying this
# run_id but no parseable integer seq contributes nothing (documented limit,
# D4) — it neither raises the max nor aborts the scan. Read-only; never
# called outside the append lock (D4: the scan and the append happen under
# one acquisition, so no second writer can take the same number in between).
#
# T-1076 round 2 (Codex Major #1): the file stores `run_id` JESC-ESCAPED
# (backslash doubled, `"` escaped as `\"`), so the comparison must be
# against that SAME escaped form — comparing the file's escaped text
# against the caller's raw argument silently restarted the counter at 1 for
# any run_id containing a backslash or a double-quote. The extraction
# pattern is ALSO widened, from a plain `[^\"]*` (which stops at the `"`
# byte inside an escaped `\"`, truncating the captured value before its
# true end) to one that treats an escaped pair (`\\.` — a literal backslash
# followed by any one character) as a single atomic unit, so an embedded
# `\"` or `\\` in the stored value can never be mistaken for the field's
# closing quote.
compute_auto_seq() {
  local file="$1" want_run_id="$2" max=0 line rid seqval want_run_id_esc
  local run_id_field_re='[{,]"run_id":"((\\.|[^"\\])*)"'
  want_run_id_esc="$(jesc "$want_run_id")"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ -z "$line" ]] && continue
      [[ "$line" =~ $run_id_field_re ]] || continue
      rid="${BASH_REMATCH[1]}"
      [[ "$rid" == "$want_run_id_esc" ]] || continue
      [[ "$line" =~ [\{,]\"seq\":([0-9]+) ]] || continue
      seqval="${BASH_REMATCH[1]}"
      if [[ "$((10#$seqval))" -gt "$((10#$max))" ]]; then
        max="$seqval"
      fi
    done < "$file"
  fi
  printf '%s' "$((10#$max + 1))"
}

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ROW is assembled in two halves so the one value `--seq auto` cannot know
# until the append lock is held below — the `seq` field itself — can be
# filled in last, right before the write. ROW_PRE ends exactly where `seq`
# belongs; ROW_POST is everything after it, otherwise unchanged from
# before this task: escaping, the timestamp and both mode branches are all
# still computed here, outside the critical section.
if [[ "$MODE" == "event" ]]; then
  ROW_PRE="{"
  ROW_PRE+="$(jstr loop_id "$LOOP_ID"),"
  ROW_PRE+="$(jstr run_id "$RUN_ID"),"
  ROW_POST="$(jstr ts "$TS"),"
  ROW_POST+="$(jstr kind "event"),"
  ROW_POST+="$(jstr event "$EVENT"),"
  ROW_POST+="$(jstr from "$FROM"),"
  ROW_POST+="$(jstr to "$TO"),"
  ROW_POST+="$(jstr label "$LABEL")"
  ROW_POST+="}"
else
  ROW_PRE="{"
  ROW_PRE+="$(jstr loop_id "$LOOP_ID"),"
  ROW_PRE+="$(jstr run_id "$RUN_ID"),"
  ROW_POST="$(jstr ts "$TS"),"
  ROW_POST+="$(jstr span "$SPAN"),"
  ROW_POST+="$(jstr phase "$PHASE"),"
  ROW_POST+="$(jnum iteration "$ITERATION"),"
  ROW_POST+="$(jnum attempt "$ATTEMPT"),"
  ROW_POST+="$(jstr status "$STATUS"),"
  ROW_POST+="$(jstr model "$MODEL"),"
  ROW_POST+="$(jnum tokens "$TOKENS"),"
  ROW_POST+="$(jnum tool_uses "$TOOL_USES"),"
  ROW_POST+="$(jnum duration_ms "$DURATION_MS"),"
  ROW_POST+="$(jstr verdict "$VERDICT"),"
  ROW_POST+="$(jnum usd "$USD"),"
  ROW_POST+="$(jstr error "$ERROR"),"
  ROW_POST+="$(jstr parent_span_id "$PARENT"),"
  ROW_POST+="$(jstr provider "$PROVIDER"),"
  ROW_POST+="$(jstr effort "$EFFORT_OUT"),"
  ROW_POST+="$(jstr adapter "$ADAPTER"),"
  ROW_POST+="$(jstr instance "$INSTANCE")"
  ROW_POST+="}"
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

FILE="$RUNS_DIR/${LOOP_ID}.jsonl"
LOCK_DIR="$RUNS_DIR/.${LOOP_ID}.jsonl.lock"

# --- T-1076: bounded-wait, never-stealing append lock (D1/D2/D3) -----------
# Default 10s, overridable via TEAM_LOG_LOCK_TIMEOUT. An UNSET value takes
# the default silently before validation ever runs (the same shape
# bin/check-acs.sh already uses for CHECK_ACS_TIMEOUT); a PRESENT value that
# is non-integer, zero or negative also falls back to the default, but
# additionally warns on stderr naming the variable.
LOCK_TIMEOUT="${TEAM_LOG_LOCK_TIMEOUT:-10}"
case "$LOCK_TIMEOUT" in
  ''|*[!0-9]*)
    printf 'log-run: ignoring invalid TEAM_LOG_LOCK_TIMEOUT=%s, using default 10\n' "$LOCK_TIMEOUT" >&2 || true
    LOCK_TIMEOUT=10
    ;;
  *)
    if [ "$((10#$LOCK_TIMEOUT))" -le 0 ]; then
      printf 'log-run: ignoring invalid TEAM_LOG_LOCK_TIMEOUT=%s, using default 10\n' "$LOCK_TIMEOUT" >&2 || true
      LOCK_TIMEOUT=10
    fi
    ;;
esac

# lock_mtime <dir> — best-effort human-legible mtime for the refusal
# message. BSD `stat` (macOS, this repo's own dev host) and GNU `stat` spell
# the flag differently and neither is guaranteed present, so every arm
# degrades to "unknown" rather than failing the refusal path itself.
#
# T-1076 rework round 3 (Codex round-2 Minor): the previous shape tried the
# BSD form (`stat -f '%Sm'`) first and fell through to the GNU form only on
# a non-zero exit. That fallthrough never triggers on GNU/Linux: GNU `stat`
# parses `-f '%Sm'` as a VALID format string (`%S` is "print the next
# directive literally if unsupported, else its safe/quoted form" — legal in
# `-f` mode; the trailing `m` is consumed as a literal character), so the
# command SUCCEEDS with a nonsensical value (e.g. `4096m`, the filesystem
# block size followed by a stray `m`) instead of failing over to the
# correct GNU-form `stat -c '%y'` line below it. Exit status alone cannot
# discriminate the two dialects here because the wrong-dialect call does
# not fail. Discriminate on the dialect itself instead, using the
# `--version` flag as the probe: GNU coreutils' `stat` supports it and
# exits 0; BSD/macOS `stat` treats it as an unrecognized option and exits
# non-zero (measured on this repo's own dev host, this session: `stat
# --version` exits 1 with "illegal option -- -"). Each branch then runs
# only the format string that dialect actually accepts, so a
# wrong-dialect call is never attempted and the old silent-garbage path
# cannot recur.
#
# Verified bound, stated honestly: this host is macOS (BSD `stat`), so only
# the BSD branch below is exercised by this session's own tests. The GNU
# branch is written from GNU `stat`'s documented `-c`/`--version` behaviour
# and is NOT independently verified against a live GNU/Linux host here.
lock_mtime() {
  local d="$1"
  if ! command -v stat >/dev/null 2>&1; then
    printf 'unknown'
    return 0
  fi
  if stat --version >/dev/null 2>&1; then
    # GNU coreutils stat: --version is recognized.
    stat -c '%y' "$d" 2>/dev/null && return 0
  else
    # BSD/macOS stat: --version is an unrecognized option, not a real probe
    # of the file, so this branch never mistakes it for a stat target.
    stat -f '%Sm' "$d" 2>/dev/null && return 0
  fi
  printf 'unknown'
}

# D3: release fires ONLY for a lock this process itself created — guarded by
# LOCK_ACQUIRED, set at acquisition (never inferred at release time) — and
# uses `rmdir` ONLY, never a forced recursive removal, so it can never
# destroy contents a sibling process left inside the lock directory.
# Installed before the acquisition loop so a signal during the bounded wait
# is still handled (harmlessly: LOCK_ACQUIRED is still 0 at that point).
#
# T-1076 round 2 (Codex Blocker): the mkdir-then-flag-set transition below
# and the flag-reset-then-rmdir transition inside release_lock are each ONE
# atomic unit as far as signal delivery is concerned. Bash defers a caught
# INT/TERM until the currently-running command returns, then runs the trap
# BEFORE the next statement executes — so a signal landing in the
# single-statement gap between `mkdir` succeeding and `LOCK_ACQUIRED=1`
# used to see the flag still 0 and skip the `rmdir`, orphaning the lock on
# an ordinary INT/TERM (not just SIGKILL, D3's only disclosed residual
# case); a signal landing between release_lock's own flag reset and its
# `rmdir` used to re-enter release_lock with the flag already fooled into
# looking "not held" or (in the pre-fix ordering) still "held", and could
# `rmdir` whatever a SUCCESSOR process has since created at the same path —
# a direct violation of the never-steal guarantee. Both transitions are now
# bracketed with `trap '' INT TERM`: a signal delivered while a signal's
# disposition is SIG_IGN is discarded by the kernel outright, never queued
# for later delivery, so nothing can fire mid-transition. Traps are
# re-armed immediately after each bracket, so the bounded wait below and
# the rest of the script remain interruptible exactly as before — only the
# few bracketed statements themselves are ever momentarily signal-deaf.
# release_lock ALSO flips LOCK_ACQUIRED to 0 BEFORE calling `rmdir` (not
# after, as a first pass at this fix had it): with the trap already masked
# for the whole bracket this ordering isn't needed for correctness by
# itself, but it means a stray re-entry from anywhere outside that bracket
# (there should be none) fails safe (skips the rmdir) rather than fails
# open (attempts a second rmdir).
LOCK_ACQUIRED=0
release_lock() {
  trap '' INT TERM
  if [ "$LOCK_ACQUIRED" = "1" ]; then
    LOCK_ACQUIRED=0
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  trap 'on_lock_signal INT 130' INT
  trap 'on_lock_signal TERM 143' TERM
}
trap release_lock EXIT
# INT/TERM need their OWN handler that calls `exit` explicitly — trapping a
# signal without an explicit exit only runs the handler and then RESUMES the
# script (bash's own documented trap semantics for a caught signal), so a
# bare `trap release_lock ... INT TERM` would release the lock early and
# then keep running to completion regardless of the signal, writing a row
# despite having been asked to stop. Matches this repo's existing
# on_signal shape (bin/check-intent.sh, bin/check-refreeze-class.sh).
# shellcheck disable=SC2329  # invoked indirectly via the signal traps below
on_lock_signal() {  # $1 = signal name, $2 = the conventional 128+N exit code
  release_lock
  exit "$2"
}
trap 'on_lock_signal INT 130' INT
trap 'on_lock_signal TERM 143' TERM

lock_start="$(date +%s)"
while :; do
  # The mkdir-attempt-then-flag-set pair below is the acquire-side half of
  # the signal-safety fix described above: masked start to finish, so a
  # signal landing anywhere between `mkdir` returning and `LOCK_ACQUIRED=1`
  # executing is simply dropped rather than observed with a half-updated
  # flag.
  trap '' INT TERM
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=1
  fi
  trap 'on_lock_signal INT 130' INT
  trap 'on_lock_signal TERM 143' TERM
  [ "$LOCK_ACQUIRED" = "1" ] && break
  lock_now="$(date +%s)"
  if [ "$(( 10#$lock_now - 10#$lock_start ))" -ge "$((10#$LOCK_TIMEOUT))" ]; then
    printf 'log-run: could not acquire append lock %s within %ss (existing lock mtime: %s) — refusing to write, exiting 3. If the process that created it was killed, remove it by hand: rmdir %s\n' \
      "$LOCK_DIR" "$LOCK_TIMEOUT" "$(lock_mtime "$LOCK_DIR")" "$LOCK_DIR" >&2 || true
    exit 3
  fi
  # Whole-second retry granularity (measured, not assumed — see
  # .shell-team/test-recipe.md's T-1076 entry): fractional `sleep` is a GNU
  # extension this repository has not verified on every host's /bin/sh.
  sleep 1
done

# --- critical section: --seq auto derivation (D4) + the append itself ------
if [ "$SEQ_AUTO" = "1" ]; then
  FINAL_SEQ="$(compute_auto_seq "$FILE" "$RUN_ID")"
  [[ "$FINAL_SEQ" =~ ^[0-9]{1,9}$ ]] || die "computed --seq auto value out of range for run_id '${RUN_ID}' (max 9 digits): '${FINAL_SEQ}'"
else
  FINAL_SEQ="$SEQ"
fi

ROW="${ROW_PRE}$(jnum seq "$FINAL_SEQ"),${ROW_POST}"
printf '%s\n' "$ROW" >> "$FILE" || die "cannot append to $FILE"

# Release now, deliberately BEFORE the post-write self-check below: that
# check forks a process and opens no file of its own, and is the last thing
# that should sit inside a lock (Notes for engineer). The EXIT/INT/TERM trap
# above still fires afterward, harmlessly, since LOCK_ACQUIRED is now 0.
release_lock

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
