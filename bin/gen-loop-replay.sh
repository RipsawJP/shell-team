#!/usr/bin/env bash
# gen-loop-replay.sh — render one run's telemetry as a self-contained HTML
# replay page (T-1012, issue #77 Part 2).
#
# Reads the resolved runs directory (bin/team-paths.sh --get runs, unless
# overridden), selects every row of <run-id> across every *.jsonl file in that
# directory, validates each scanned file with the sibling bin/check-run.sh,
# and injects the selected rows — verbatim, as compact single-line JSON — into
# the ONE frozen placeholder line of templates/loop-replay.html. The bash side
# does no field-level transformation: it filters, orders, wraps and escapes;
# the template's own JavaScript adapts the rows into the ratified scene model
# (T-1012 D3). No network, no external asset, no build step: the output opens
# from file://.
#
# --- input resolution (D1) ---------------------------------------------------
# Runs DIRECTORY precedence: --runs-dir DIR > $TEAM_RUNS_DIR > $RUNS_DIR >
# `team-paths.sh --get runs`, mirroring bin/log-run.sh's own precedence
# (log-run.sh:294-297). One deliberate divergence, taken from bin/close-out.sh:
# there is NO guessed literal fallback if the resolver is unavailable — reading
# a guessed path here would silently replay the wrong repository, so a
# resolver failure is a hard exit 2, not a degrade-and-continue.
#
# Every *.jsonl file in the resolved directory is scanned (LC_ALL=C sorted
# filename order) — never just <runs>/shell-team.jsonl, which would hardcode
# this loop's own loop_id. Non-.jsonl neighbours (a triage note, a goal state
# file, a previously generated replay-*.html, ...) are ignored, not parsed.
# Row ordering is `seq` ascending, ties broken by (filename, line number),
# stable — T-1011 declines cross-line validation, so a duplicate `seq` must
# still replay deterministically.
#
# --- injection (D2) -----------------------------------------------------------
# The template carries exactly one injection site, frozen verbatim as:
#   <script type="application/json" id="loop-replay-data">__LOOP_REPLAY_DATA__</script>
# The token __LOOP_REPLAY_DATA__ is replaced and nothing else changes: a
# generated file, with that line normalized back to the placeholder, is
# byte-identical to the shipped template. The payload is a single line of
# compact JSON — exactly the four keys run_id/generated_at/source/rows, in
# that order — with every `<`, `>` and `&` in the assembled payload replaced by
# its JSON unicode escape (<, >, &) as a blanket substitution
# over the WHOLE payload string. This is the measured top risk: log-run.sh's
# jesc() escapes only backslash and double-quote, so a free-form `label`
# containing `</script>` is a reachable input, and raw injection would
# terminate the inline script block. `JSON.parse` on the page side decodes the
# escape back to the original character, so an operator's label displays
# exactly as written; the escaped form exists only in this file's bytes.
#
# Injection is done by locating the single placeholder line and splitting the
# template into a prefix/suffix around the token with plain string operations
# (head/tail + bash parameter expansion) — never `sed 's/…/…/'` with the
# payload in the replacement text, which would let sed reinterpret the
# payload's own `&`/`\` as replacement-string metacharacters.
#
# --- fail-closed (D5) ---------------------------------------------------------
# Exit 0 = page written. Exit 1 = a data condition: no row matched <run-id>,
# or a scanned file failed bin/check-run.sh (delegated, never re-implemented —
# an unknown `kind` or event id is rejected there and never reaches the
# template). Exit 2 = usage / resolution / I-O: a malformed argument, an
# unresolvable or unreadable runs directory, an unreadable template, a
# template whose placeholder count is not exactly 1, or an occupied
# non-regular output path. On every non-zero exit, no output file exists: the
# page is assembled into a temp file inside the destination directory and
# `mv`-ed into place as the very last action.
#
# Validation runs over every scanned file BEFORE selection, not after: a
# structurally broken line may carry no extractable run_id, so it belongs to
# no run and would be skipped unexamined by a filter-first approach — fail-
# open at exactly the spot this exists to close.
#
# --- output (D4) ---------------------------------------------------------------
# Default: <resolved runs dir>/replay-<run-id>.html (git-ignored already, via
# the existing `runs/` ignore pattern — no new ignore pattern is added).
# --out PATH overrides it. Overwriting an existing REGULAR file is allowed and
# expected (regeneration is idempotent); any other occupied target — a
# directory, a FIFO, or a symlink INCLUDING a dangling one — is refused
# (`[ -e ]` alone reports a dangling symlink as absent, so the guard is
# `[ -e ... ] || [ -L ... ]`). The run id is validated against
# ^[A-Za-z0-9._-]+$ (plus an explicit reject of the bare '.'/'..' path
# components) before it is ever used in a path.
#
# Usage:
#   gen-loop-replay.sh <run-id> [--runs-dir DIR] [--out PATH] [--template PATH]
#   gen-loop-replay.sh --help
#
# Pure bash, zero-dependency, bash-3.2-compatible (no associative arrays, no
# mapfile) — same bar as every other bin/ script in this repository.

set -euo pipefail

die_usage() { printf 'gen-loop-replay: %s\n' "$1" >&2 || true; exit 2; }
die_data()  { printf 'gen-loop-replay: %s\n' "$1" >&2 || true; exit 1; }

print_help() {
  cat <<'EOF'
Usage: gen-loop-replay.sh <run-id> [--runs-dir DIR] [--out PATH] [--template PATH]

Reads a run's telemetry rows from the resolved runs directory (bin/team-paths.sh
--get runs, unless overridden) and writes a self-contained HTML replay page for
that run, built from templates/loop-replay.html.

  <run-id>          the run to replay (allowed chars: A-Za-z0-9._- ; the bare
                     '.' and '..' path components are rejected)
  --runs-dir DIR    scan DIR instead of the resolved runs directory
  --out PATH        write the page to PATH instead of
                     <runs-dir>/replay-<run-id>.html
  --template PATH   use PATH instead of the shipped templates/loop-replay.html
  --help, -h        show this help and exit

Exit: 0 = page written; 1 = no row matched <run-id>, or a scanned file failed
      bin/check-run.sh; 2 = usage / resolution / I-O error. On any non-zero
      exit, no output file is created or modified.
EOF
}

# Resolve this script's own directory (symlink-safe), same pattern as
# log-run.sh / close-out.sh, so sibling scripts and the shipped template
# resolve regardless of cwd / how this script was invoked. `cd DIR && pwd -P`
# (T-1057, issue #218), not a bare logical `pwd`: an ANCESTOR directory
# symlink (an adopter's `bin/` symlinked into the plugin's real `bin/`)
# would otherwise survive untouched and could misresolve
# templates/loop-replay.html to a decoy in the adopter's own tree.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd -P)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# --- temp-file bookkeeping (single trap, declared before anything is created) -
TMP_FILELIST=""
TMP_ROWS=""
TMP_ROWS_SORTED=""
TMP_ROWS_ONLY=""
TMP_OUT=""
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -f "$TMP_FILELIST" "$TMP_ROWS" "$TMP_ROWS_SORTED" "$TMP_ROWS_ONLY" "$TMP_OUT"; }
trap cleanup EXIT

# --- argument parsing ---------------------------------------------------------
RUN_ID=""
RUNS_DIR_OPT=""
OUT_OPT=""
TEMPLATE_OPT=""
POSITIONAL_SEEN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --runs-dir|--out|--template)
      [ "$#" -ge 2 ] || die_usage "missing value for $1"
      case "$1" in
        --runs-dir) RUNS_DIR_OPT="$2" ;;
        --out)      OUT_OPT="$2" ;;
        --template) TEMPLATE_OPT="$2" ;;
      esac
      shift 2
      ;;
    --*)
      die_usage "unknown argument: $1"
      ;;
    *)
      [ "$POSITIONAL_SEEN" -eq 0 ] || die_usage "unexpected extra argument: $1"
      RUN_ID="$1"
      POSITIONAL_SEEN=1
      shift
      ;;
  esac
done

[ "$POSITIONAL_SEEN" -eq 1 ] || die_usage "missing required <run-id> argument (see --help)"

# Reject the bare '.'/'..' path components explicitly: both are inside the
# general charset below, so the charset check alone would accept them, but a
# run id that IS a path-navigation component is reserved regardless (D4).
case "$RUN_ID" in
  .|..) die_usage "invalid run id '$RUN_ID' ('.' and '..' are reserved path components)" ;;
esac
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]] || die_usage "invalid run id '$RUN_ID' (allowed chars: A-Za-z0-9._-)"

# --- template resolution + placeholder arity (D2/D5) --------------------------
if [ -n "$TEMPLATE_OPT" ]; then
  TEMPLATE="$TEMPLATE_OPT"
else
  TEMPLATE="$REPO_ROOT/templates/loop-replay.html"
fi
[ -r "$TEMPLATE" ] || die_usage "cannot read template: $TEMPLATE"

PLACEHOLDER='__LOOP_REPLAY_DATA__'
PLACEHOLDER_COUNT="$(grep -o -- "$PLACEHOLDER" "$TEMPLATE" 2>/dev/null | grep -c . || true)"
[ "$PLACEHOLDER_COUNT" -eq 1 ] || die_usage "template placeholder count is ${PLACEHOLDER_COUNT}, expected exactly 1: $TEMPLATE"
PLACEHOLDER_LINE_NUM="$(grep -n -F -- "$PLACEHOLDER" "$TEMPLATE" | head -n1 | cut -d: -f1)"
[ -n "$PLACEHOLDER_LINE_NUM" ] || die_usage "internal: could not locate the placeholder line in $TEMPLATE"

# --- runs directory resolution (D1 precedence, no guessed fallback) -----------
if [ -n "$RUNS_DIR_OPT" ]; then
  RESOLVED_RUNS_DIR="$RUNS_DIR_OPT"
elif [ -n "${TEAM_RUNS_DIR:-}" ]; then
  RESOLVED_RUNS_DIR="$TEAM_RUNS_DIR"
elif [ -n "${RUNS_DIR:-}" ]; then
  RESOLVED_RUNS_DIR="$RUNS_DIR"
else
  RESOLVED_RUNS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get runs 2>/dev/null)" \
    || die_usage "cannot resolve the runs directory (team-paths.sh unavailable) — pass --runs-dir or set \$TEAM_RUNS_DIR"
  [ -n "$RESOLVED_RUNS_DIR" ] || die_usage "team-paths.sh returned an empty runs directory"
fi
[ -d "$RESOLVED_RUNS_DIR" ] || die_usage "cannot read runs directory (not a directory): $RESOLVED_RUNS_DIR"
[ -r "$RESOLVED_RUNS_DIR" ] || die_usage "cannot read runs directory (not readable): $RESOLVED_RUNS_DIR"

# --- output path resolution + target guard (D4) -------------------------------
if [ -n "$OUT_OPT" ]; then
  OUT="$OUT_OPT"
else
  OUT="$RESOLVED_RUNS_DIR/replay-${RUN_ID}.html"
fi
OUT_DIR="$(dirname -- "$OUT")"
[ -d "$OUT_DIR" ] || die_usage "output directory does not exist: $OUT_DIR"
if [ -e "$OUT" ] || [ -L "$OUT" ]; then
  if [ -f "$OUT" ] && [ ! -L "$OUT" ]; then
    : # overwriting an existing regular file is allowed and expected
  else
    die_usage "output path is occupied by something other than a regular file (refusing to overwrite a directory/FIFO/symlink, including a dangling one): $OUT"
  fi
fi

# --- sibling check-run.sh resolution (D5 — delegate validation, never re-implement) -
CHECK_RUN="$SCRIPT_DIR/check-run.sh"
[ -r "$CHECK_RUN" ] || die_usage "sibling bin/check-run.sh is missing or unreadable"

# --- scan every *.jsonl file, LC_ALL=C sorted filename order (D1) -------------
TMP_FILELIST="$(mktemp "${TMPDIR:-/tmp}/gen-loop-replay-files.XXXXXX")" \
  || die_usage "cannot create a temp file"
: > "$TMP_FILELIST"
for f in "$RESOLVED_RUNS_DIR"/*.jsonl; do
  [ -e "$f" ] || continue
  printf '%s\n' "$f" >> "$TMP_FILELIST"
done
LC_ALL=C sort -o "$TMP_FILELIST" "$TMP_FILELIST"

SORTED_FILES=()
while IFS= read -r f; do
  [ -n "$f" ] && SORTED_FILES+=("$f")
done < "$TMP_FILELIST"

# --- validate EVERY scanned file before any selection (D5) --------------------
if [ "${#SORTED_FILES[@]}" -gt 0 ]; then
  for f in "${SORTED_FILES[@]}"; do
    if ! bash "$CHECK_RUN" "$f" >&2; then
      die_data "validation failed: $f does not pass bin/check-run.sh (a scanned file is malformed)"
    fi
  done
fi

# json_escape_str <s> — the same escaping bin/log-run.sh's jesc() applies
# (backslash first, then double-quote), so a basename the filesystem allowed
# to contain a literal '"' or '\' cannot break the `source` array's JSON
# structure. Filenames are operator/system-controlled, not telemetry content,
# so this is a defensive fail-safe fix rather than an escaping gap that
# reaches an XSS-shaped sink (T-1012 rework round 1, Minor #2).
json_escape_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# --- build the `source` list (basenames only — never absolute paths) ---------
SOURCE_ITEMS=()
if [ "${#SORTED_FILES[@]}" -gt 0 ]; then
  for f in "${SORTED_FILES[@]}"; do
    SOURCE_ITEMS+=("\"$(json_escape_str "$(basename -- "$f")")\"")
  done
fi
SOURCE_JSON=""
if [ "${#SOURCE_ITEMS[@]}" -gt 0 ]; then
  SOURCE_JSON="$(IFS=,; printf '%s' "${SOURCE_ITEMS[*]}")"
fi

# --- select rows matching <run-id>, tagging (seq, filename, lineno) for the
#     D1 ordering rule: seq ascending, ties broken by (filename, lineno),
#     stable ------------------------------------------------------------------
TMP_ROWS="$(mktemp "${TMPDIR:-/tmp}/gen-loop-replay-rows.XXXXXX")" \
  || die_usage "cannot create a temp file"
: > "$TMP_ROWS"

if [ "${#SORTED_FILES[@]}" -gt 0 ]; then
  for f in "${SORTED_FILES[@]}"; do
    base="$(basename -- "$f")"
    lineno=0
    while IFS= read -r line || [ -n "$line" ]; do
      lineno=$((lineno + 1))
      line="${line%$'\r'}"                          # tolerate CRLF (T-1011 D4)
      [ -z "${line//[[:space:]]/}" ] && continue     # skip blank lines
      if [[ "$line" =~ [\{,]\"run_id\":\"([^\"]*)\" ]]; then
        [ "${BASH_REMATCH[1]}" = "$RUN_ID" ] || continue
      else
        continue   # no extractable run_id -> belongs to no run, already lint-caught above
      fi
      seq_val=""
      if [[ "$line" =~ [\{,]\"seq\":([0-9]+) ]]; then
        seq_val="${BASH_REMATCH[1]}"
      fi
      [ -n "$seq_val" ] || seq_val=0
      printf '%s\t%s\t%s\t%s\n' "$seq_val" "$base" "$lineno" "$line" >> "$TMP_ROWS"
    done < "$f"
  done
fi

TMP_ROWS_SORTED="$(mktemp "${TMPDIR:-/tmp}/gen-loop-replay-rows-sorted.XXXXXX")" \
  || die_usage "cannot create a temp file"
LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k2,2 -k3,3n "$TMP_ROWS" > "$TMP_ROWS_SORTED"

ROW_COUNT="$(wc -l < "$TMP_ROWS_SORTED" | tr -d ' ')"
[ "$ROW_COUNT" -gt 0 ] || die_data "no rows matched run id '$RUN_ID' across ${#SORTED_FILES[@]} scanned file(s) in $RESOLVED_RUNS_DIR"

TMP_ROWS_ONLY="$(mktemp "${TMPDIR:-/tmp}/gen-loop-replay-rows-only.XXXXXX")" \
  || die_usage "cannot create a temp file"
cut -f4- "$TMP_ROWS_SORTED" > "$TMP_ROWS_ONLY"
ROWS_JSON="$(paste -sd, "$TMP_ROWS_ONLY")"

# --- assemble the payload (D2): exactly four keys, in this order --------------
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PAYLOAD="{\"run_id\":\"${RUN_ID}\",\"generated_at\":\"${TS}\",\"source\":[${SOURCE_JSON}],\"rows\":[${ROWS_JSON}]}"

# Blanket escape of <, > and & to their JSON unicode escapes, over the WHOLE
# assembled payload string — the measured top risk (D2). None of the three can
# occur in JSON outside a string literal, so this needs no parser; JSON.parse
# on the page side decodes them back to the original characters.
escape_payload() {
  local s="$1"
  s="${s//</\\u003c}"
  s="${s//>/\\u003e}"
  s="${s//&/\\u0026}"
  printf '%s' "$s"
}
ESCAPED_PAYLOAD="$(escape_payload "$PAYLOAD")"

# --- inject: split the template around the placeholder TOKEN (not the whole
#     line, though the frozen line contains nothing else) with plain string
#     operations. Never `sed 's/.../.../'` with the payload in the replacement
#     text — sed reinterprets `&` and `\` there, and the payload is full of
#     both (D2 note / H5). ------------------------------------------------------
LINE_CONTENT="$(sed -n "${PLACEHOLDER_LINE_NUM}p" "$TEMPLATE")"
PREFIX="${LINE_CONTENT%%__LOOP_REPLAY_DATA__*}"
SUFFIX="${LINE_CONTENT#*__LOOP_REPLAY_DATA__}"
NEW_LINE="${PREFIX}${ESCAPED_PAYLOAD}${SUFFIX}"

TMP_OUT="$(mktemp "${OUT_DIR}/.gen-loop-replay.XXXXXX" 2>/dev/null)" \
  || die_usage "cannot create a temp file in the output directory: $OUT_DIR"
{
  if [ "$PLACEHOLDER_LINE_NUM" -gt 1 ]; then
    head -n "$((PLACEHOLDER_LINE_NUM - 1))" "$TEMPLATE"
  fi
  printf '%s\n' "$NEW_LINE"
  tail -n "+$((PLACEHOLDER_LINE_NUM + 1))" "$TEMPLATE"
} > "$TMP_OUT"
chmod 644 "$TMP_OUT" 2>/dev/null || true

# Last action: move into place. Everything above only ever touched a temp file
# under $OUT_DIR (or read-only inputs), so any failure before this line leaves
# no output file at all (D5).
mv -- "$TMP_OUT" "$OUT"
TMP_OUT=""   # moved away — nothing left there for the EXIT trap to remove

exit 0
