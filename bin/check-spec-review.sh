#!/usr/bin/env bash
# check-spec-review.sh — close-out backstop refusing an elected spec review
# that never reached an approval verdict (T-1096, issue #344).
#
# Decision this implements: docs/loop-engineering/record-tamper-resistance.md
# — tamper-arm-rule-v1 sends this obligation to arm A
# (arm-A-tested-primitive): its verdict gates a close-out (a loop
# transition) and its judgment (is the record's LAST spec-review verdict
# line an approval?) is mechanically executable from committed bytes.
#
# The six #344 defeat classes this design refuses or is structurally immune
# to, verbatim from the spec's own requirement floor
# (.shell-team/specs/T-1096-selection-trust-gates.md §2):
#   1. Unanchored verdict match (a prefix-matching near-miss like
#      APPROVE_WITH_CAVEATS, or the unfilled template APPROVE | REQUEST_CHANGES).
#   2. Unscoped scan (an earlier APPROVE satisfying a whole-file grep when
#      the latest round said REQUEST_CHANGES).
#   3. Heading-match asymmetry (a trailing- or internal-whitespace heading
#      variant anchoring the scan to a stale round).
#   4. Boundary defeat in the dangerous direction (an unrelated heading with
#      leading whitespace leaking later content into "the latest round").
#   5. CRLF fallback bypass (a CRLF-terminated record defeating heading
#      detection and resurrecting a stale APPROVE via a whole-file fallback).
#   6. Missing/non-ASCII separator (a reductive whitespace normalization can
#      collapse existing whitespace but never supply a missing one).
#
# The design consults NO heading at all and has NO fallback: it strips a
# trailing CR per line, collects EVERY column-zero line matching the
# verdict-line STEM `^### Codex Spec-Review verdict:` alone — no assumption
# about the separator or the tail — refuses when none is collected, and
# otherwise takes the LAST such line and requires its remainder to be
# exactly one ASCII space followed by one of four closed forms (APPROVE,
# APPROVE (round <n>), REQUEST_CHANGES, REQUEST_CHANGES (round <n>)),
# refusing — never skipping — any other remainder. This closes classes 1
# and 2 (anchored-prefix match, last-line-wins, append-only ordering) and is
# structurally immune to 3, 4 and 5 (no heading is ever read).
#
# Widening the collection net to stem-PLUS-SEPARATOR (`^### Codex
# Spec-Review verdict: ` with the trailing space baked into the net) would
# relocate class 6 onto the verdict line's own separator rather than close
# it: a line whose separator is missing, a tab, or non-ASCII would be
# UNCOLLECTED rather than refused, and a stale earlier APPROVE would then be
# the last collected line — the gate would false-PASS. So the net is the
# stem alone, and the separator is validated as part of the remainder
# instead, putting every near-miss in the refusal branch.
#
# EOF-safety: the whole file is read with `grep`/`sed`, never a
# `while IFS= read -r line` loop, which drops a final line carrying no
# trailing newline (that read's own non-zero exit status is the loop's
# continuation test) and would silently resurrect a stale verdict.
#
# The producer contract this reads against is pinned in
# agents/code-reviewer.md's "Verdict and record shape" paragraph.
#
# Election (validate-if-present): this gate fires only when the task's
# Active board entry carries `- dispatch: spec-review — cross-provider —
# ...`. `none`, or no `spec-review` dispatch record at all, is a silent
# pass-through — tests/close-out/run.sh's own locked forward-only property
# for every in-flight three-axis task. This gate cannot distinguish "the
# election was none" from "nobody transcribed the record" — disclosed, not
# closed.
#
# Usage:
#   check-spec-review.sh --board PATH --task T-NNN
#   check-spec-review.sh --rounds --task T-NNN --contract PATH
#
# Round-guard mode (T-1160, issue #630): --rounds derives the spec-review
# round count from the committed review record's `### Codex Spec-Review
# verdict:` lines alone. It reads NO board (the election is transcribed after
# the intent hash; this guard runs before it) and prints, on stdout, exactly:
#   APPROVED                          the last verdict line is an approval
#   CONTINUE                          rounds remain (zero lines, or an absent
#                                     record, is CONTINUE)
#   STOP:spec_review_rounds_reached   the count reached the cap (exit 3)
# followed, on CONTINUE and STOP only, by one `SAME_CLASS_2:<key>` line for each
# criterion key that a `- gating-criterion: <ACn | AC-N | premise>` line
# (column zero) records as gating two distinct rounds. The cap is the optional
# contract key budget.max_spec_review_rounds (default 3; 0 disables it;
# digits only, at most nine, read decimal). Every collected verdict line is
# judged against the same closed grammar the close-out mode uses (a refusal,
# never a skip), a `(round N)` suffix must equal the line's position among
# the collected lines (a bare token is accepted anywhere), and the record is
# read by one awk pass, never a `while read` loop, so a CRLF record or a final
# line with no newline counts the same as any other. Exit 0 = APPROVED or
# CONTINUE, 3 = STOP, and any refusal (a line outside the grammar, an
# unreadable record, contract or reviews directory, a bad value) exits 1 or 2
# with nothing on stdout. Residual, disclosed: the count is only as honest as
# the record is append-only (no tamper resistance against rewriting earlier
# verdict lines).
#
# Exit codes (close-out mode): 0 = pass, or the election is not cross-provider; 1 = a
# refusal about the record's content (no readable record / no verdict line
# found at all / the last verdict line's remainder is an unrecognised tail
# or an in-grammar REQUEST_CHANGES refusal); 2 = a usage error or an
# unresolvable environment (bad invocation, an unreadable board, the task
# not found as exactly one top-level ## Active entry, or an
# unresolvable/non-directory reviews directory).

set -euo pipefail

die()  { printf 'check-spec-review: %s\n' "$1" >&2 || true; exit 2; }
fail() { printf 'check-spec-review: %s\n' "$1" >&2 || true; exit 1; }

# The closed grammar of a verdict line's remainder, shared by both modes:
# exactly one ASCII space, then one of the four forms, and nothing else.
re_grammar='^ (APPROVE|REQUEST_CHANGES)( \(round [0-9]+\))?$'

# Resolve this script's own directory (symlink-safe) so the sibling
# team-paths.sh resolves regardless of cwd / how we were invoked — same
# pattern close-out.sh and log-run.sh already use.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"

BOARD="" TASK="" CONTRACT="" ROUNDS=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      [ "$#" -ge 2 ] || die "missing value for --board"
      BOARD="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || die "missing value for --task"
      TASK="$2"; shift 2 ;;
    --rounds)
      ROUNDS=1; shift ;;
    --contract)
      [ "$#" -ge 2 ] || die "missing value for --contract"
      CONTRACT="$2"; shift 2 ;;
    --help|-h)
      awk 'NR==1{next} /^#/{l=$0; sub(/^# ?/,"",l); print l; next} {exit}' "$script_path"
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$TASK" ]  || die "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || die "invalid --task '$TASK' (expected T-<digits>)"

# --- resolve the reviews directory (interventions-resolver shape: env
# override at the same precedence $TEAM_TODO/$TEAM_INTERVENTIONS_DIR have,
# else the sibling team-paths.sh, no guessing fallback) — with one
# deliberate difference from that resolver: a directory check is required
# here, and its failure is its OWN exit-2 failure class, distinct from a
# content refusal about the record itself -------------------------------
resolve_reviews_dir() {
  if [ -n "${TEAM_REVIEWS_DIR:-}" ]; then
    REVIEWS_DIR="$TEAM_REVIEWS_DIR"
  else
    REVIEWS_DIR="$(bash "$SCRIPT_DIR/team-paths.sh" --get reviews 2>/dev/null)" \
      || die "cannot resolve the reviews directory (team-paths.sh unavailable) — set \$TEAM_REVIEWS_DIR or fix the install"
  fi
  [ -d "$REVIEWS_DIR" ] || die "reviews directory is not a directory: $REVIEWS_DIR"
}

# =====================================================================
# Round-guard mode (--rounds). Reads no board.
# =====================================================================
if [ "$ROUNDS" -eq 1 ]; then
  [ -z "$BOARD" ] || die "--rounds reads no board; do not combine it with --board"
  [ -n "$CONTRACT" ] || die "missing required --contract"
  # Contract first: an unreadable contract is refused even when the record is
  # absent (an absent record is CONTINUE, never a licence to skip the cap).
  { [ -f "$CONTRACT" ] && [ -r "$CONTRACT" ]; } || die "cannot read contract: $CONTRACT"

  # Section-scoped read of budget.max_spec_review_rounds, same semantics as
  # loop-guard.sh's contract_value (first `budget:` section only, inline
  # `# comment` stripped, no quote stripping). Not sourced from loop-guard.sh.
  if ! cap_raw="$(awk '
      $0 ~ "^budget:" && !seen { seen=1; in_sec=1; next }
      in_sec && /^[^[:space:]#]/ { in_sec=0 }
      in_sec && !found && match($0, "^[[:space:]]*max_spec_review_rounds:[[:space:]]*") {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        print v
        found = 1
      }
    ' "$CONTRACT")"; then
    die "failed to parse contract: $CONTRACT"
  fi
  # An absent key and an empty value are indistinguishable here and both take
  # the default; neither can ever disable the cap (only a literal 0 does).
  if [ -z "$cap_raw" ]; then
    cap_raw=3
  fi
  [[ "$cap_raw" =~ ^[0-9]{1,9}$ ]] \
    || die "budget.max_spec_review_rounds is not 1-9 ASCII digits: '$cap_raw'"
  CAP=$((10#$cap_raw))

  resolve_reviews_dir
  { [ -x "$REVIEWS_DIR" ] && [ -r "$REVIEWS_DIR" ]; } || die "reviews directory is not searchable: $REVIEWS_DIR"
  RECORD="$REVIEWS_DIR/$TASK.md"

  # Absent (neither a path nor a symlink) = zero verdict lines = CONTINUE.
  # Anything else that is not a readable regular file (a directory, a FIFO, a
  # dangling symlink, an unreadable file) is refused, never treated as absent.
  if [ ! -e "$RECORD" ] && [ ! -L "$RECORD" ]; then
    printf 'CONTINUE\n'
    exit 0
  fi
  { [ -f "$RECORD" ] && [ -r "$RECORD" ]; } || fail "$TASK's review record is not a readable regular file: $RECORD"

  # One awk pass over the whole record (a final line with no newline is still
  # read). Output on success: line 1 = "<count> <approved 0|1>", then one
  # SAME_CLASS_2:<key> line per key gating two distinct rounds. A refusal
  # prints its reason on stderr and exits non-zero (bad=1 keeps END from
  # printing anything after an `exit` inside a rule).
  if ! scan_out="$(RE_GRAMMAR="$re_grammar" LC_ALL=C awk '
    BEGIN { re = ENVIRON["RE_GRAMMAR"]; stem = "### Codex Spec-Review verdict:"; gstem = "- gating-criterion:"
            n = 0; app = 0; bad = 0; nk = 0 }
    { sub(/\r$/, "") }
    index($0, stem) == 1 {
      rem = substr($0, length(stem) + 1)
      n++
      if (rem !~ re) {
        printf "check-spec-review: verdict line %d has an unrecognised remainder (not one of the four closed forms): %s\n", n, $0 > "/dev/stderr"
        bad = 1; exit 1
      }
      if (match(rem, /\(round [0-9]+\)$/)) {
        d = substr(rem, RSTART + 7, RLENGTH - 8)
        sub(/^0+/, "", d)
        if (d != n "") {
          printf "check-spec-review: verdict line %d carries a round suffix that disagrees with its position: %s\n", n, $0 > "/dev/stderr"
          bad = 1; exit 1
        }
      }
      app = (rem ~ /^ APPROVE/) ? 1 : 0
      next
    }
    index($0, gstem) == 1 {
      if (n == 0) {
        printf "check-spec-review: gating-criterion line before any verdict line: %s\n", $0 > "/dev/stderr"
        bad = 1; exit 1
      }
      v = substr($0, length(gstem) + 1)
      if (v ~ /^ premise$/) { key = "criterion-premise" }
      else if (v ~ /^ AC-?[0-9]+$/) {
        d = v; sub(/^ AC-?/, "", d); sub(/^0+/, "", d)
        if (d == "") { d = "0" }
        key = "criterion-n" d
      } else {
        printf "check-spec-review: gating-criterion line outside the closed grammar (ACn | AC-N | premise): %s\n", $0 > "/dev/stderr"
        bad = 1; exit 1
      }
      if (!(key in cnt)) { order[++nk] = key; cnt[key] = 0; lastr[key] = 0 }
      if (lastr[key] != n) { cnt[key]++; lastr[key] = n }
      next
    }
    END {
      if (bad) { exit 1 }
      print n " " app
      if (!app) { for (i = 1; i <= nk; i++) { if (cnt[order[i]] >= 2) { print "SAME_CLASS_2:" order[i] } } }
    }
  ' "$RECORD")"; then
    fail "$TASK's review record is refused: $RECORD"
  fi

  head_line="${scan_out%%$'\n'*}"
  rest=""
  case "$scan_out" in *$'\n'*) rest="${scan_out#*$'\n'}" ;; esac
  n_rounds="${head_line% *}"
  approved="${head_line#* }"
  [[ "$n_rounds" =~ ^[0-9]+$ && "$approved" =~ ^[01]$ ]] || fail "internal: unparseable scan result '$head_line'"

  if [ "$approved" -eq 1 ]; then
    printf 'APPROVED\n'
    exit 0
  fi
  if [ "$CAP" -gt 0 ] && [ "$n_rounds" -ge "$CAP" ]; then
    printf 'STOP:spec_review_rounds_reached\n'
    if [ -n "$rest" ]; then printf '%s\n' "$rest"; fi
    exit 3
  fi
  printf 'CONTINUE\n'
  if [ -n "$rest" ]; then printf '%s\n' "$rest"; fi
  exit 0
fi

[ -z "$CONTRACT" ] || die "--contract requires --rounds"
[ -n "$BOARD" ] || die "missing required --board"
[ -r "$BOARD" ] || die "cannot read board: $BOARD"

# --- locate the task's Active entry extent (same shape as close-out.sh's
# own scan: a top-level `- [ ] **T-NNN**` line plus its indented/blank
# continuation lines) ---------------------------------------------------
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

# --- extract the spec-review election, if any ---------------------------
d_line="$(sed -n "${A_START},${A_END}p" "$BOARD" \
  | grep -E -- '^[[:space:]]*- dispatch: spec-review — ' | tail -1 || true)"
d_value=""
if [ -n "$d_line" ]; then
  d_value="$(printf '%s\n' "$d_line" | sed -nE 's/^[[:space:]]*- dispatch: spec-review — ([a-z0-9-]+) — .*$/\1/p')"
fi

# Validate-if-present: `none`, an unrecognised value, or no record at all
# is a silent pass-through. Only `cross-provider` continues below.
if [ "$d_value" != "cross-provider" ]; then
  exit 0
fi

resolve_reviews_dir

RECORD="$REVIEWS_DIR/$TASK.md"

# Row (i): a missing path, a directory, a FIFO, an unreadable file or a
# dangling symlink are all "no readable record" — same screen close-out.sh
# already uses for the interventions record.
if [ ! -f "$RECORD" ] || [ ! -r "$RECORD" ]; then
  fail "$TASK elected spec-review — cross-provider but has no readable review record: $RECORD"
fi

WORK="$(mktemp "${TMPDIR:-/tmp}/check-spec-review.XXXXXX")" || die "mktemp failed"
trap 'rm -f "$WORK"' EXIT

# Strip a trailing CR per line (defeat class 5) without ever using a
# `while read` loop over the record itself (EOF safety for a final line
# with no trailing newline — defeat class 7 in AC5's own numbering).
sed 's/\r$//' "$RECORD" > "$WORK"

# Collect every column-zero line matching the verdict-line STEM alone (the
# third correction to the candidate design: a stem-PLUS-SEPARATOR net would
# leave a missing/non-ASCII separator UNCOLLECTED rather than refused,
# relocating class 6 instead of closing it). `grep` reads the whole file,
# so a final line with no trailing newline is still matched.
LAST="$(grep -E '^### Codex Spec-Review verdict:' "$WORK" | tail -1 || true)"
if [ -z "$LAST" ]; then
  fail "$TASK's review record carries no Codex Spec-Review verdict line at all: $RECORD"
fi

REMAINDER="${LAST#'### Codex Spec-Review verdict:'}"

# The closed grammar: exactly one ASCII space, then one of the four forms,
# and nothing else — anchored on the full remainder so an unrecognised tail
# is refused rather than skipped past (the correction that closes classes 1
# and 2), and so a missing/tab/non-ASCII separator on THIS line refuses
# rather than silently falling through to an earlier stale approval (the
# separator-axis correction that closes class 6 at its second location).
re_approve='^ APPROVE( \(round [0-9]+\))?$'

if [[ ! "$REMAINDER" =~ $re_grammar ]]; then
  fail "$TASK's last Codex Spec-Review verdict line has an unrecognised remainder (not one of the four closed forms APPROVE / APPROVE (round N) / REQUEST_CHANGES / REQUEST_CHANGES (round N)): $LAST"
fi

if [[ "$REMAINDER" =~ $re_approve ]]; then
  exit 0
fi

fail "$TASK's last Codex Spec-Review verdict is not an approval: $LAST"
