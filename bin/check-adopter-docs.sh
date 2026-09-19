#!/usr/bin/env bash
# check-adopter-docs.sh — freeze-time gate for the "user-visible capability
# needs adopter docs, or an honest waiver" declaration a spec's frozen intent
# block must carry (T-1061; .shell-team/specs/T-1061-adopter-docs-gate.md;
# issue #244 requirement 4), rebuilt on an explicit three-variable state
# machine (T-1151; .shell-team/specs/T-1151-adopter-docs-checker.md) that
# also enforces issue #577's `- shipped-docs:` inventory duty.
#
# A spec for a user-visible capability could always reach `READY_FOR_ARCH`
# with no adopter-facing-documentation acceptance criterion, and nothing
# anywhere noticed. This script is the mechanical consumer: it reads one
# spec file and refuses, mechanically, when the declaration is absent,
# malformed, a `yes` declaration is undischarged, or (issue #577) a `yes`
# declaration's shipped-docs inventory is missing, malformed, misplaced or
# unmeasured. It never judges content — whether a named surface or shipped
# document is REALLY adopter-facing is a matter for the reviewing gates and
# the human, never for this checker.
#
# This is a stateless predicate over one spec file: it decides from an
# explicit three-variable state machine and exits 0 silently, 1 on a
# content refusal, or 2 when the input could not be evaluated at all,
# writing exactly one token from a closed set of fourteen alone on stderr
# and zero bytes on stdout.
#
# Declaration grammar (templates/prompt-blocks/adopter-docs-declaration.md —
# the single canonical source; kept in sync here by bin/check-prompt-sync.sh,
# never copied by hand):
#   - user-visible: yes — <rationale>
#   - user-visible: no — <rationale>
# A `yes` declaration is discharged by an indented
# `- adopter-surface: <where the adopter-facing documentation lands>` line
# under an acceptance criterion, or a top-level
# `- adopter-docs-waiver: <why this user-visible capability has no
# adopter-docs surface>` line — never both, never either beside a `no`. A
# `yes` declaration additionally carries one or more unindented
# `- shipped-docs: <repo-relative path> — this-task | issue #<N>` lines
# (issue #577): each `this-task` path must be named, as a literal
# substring, in one of this same spec's own `- check:` or
# `- adopter-surface:` lines — this script never opens, stats, resolves or
# globs that path against the filesystem.
#
# THE THREE-VARIABLE STATE MACHINE (F x R x S). Every line of the file
# produces a transition in each variable, identity transitions included —
# this is the design fix for the carved-out generation's R2 finding, where
# an unconditional `continue` on a fenced line skipped the line's own scope
# effect rather than running an explicit identity transition.
#
#   F — fence state. Tracks BOTH backtick and tilde fences (T-1151 adds
#   tilde; the carved-out generation tracked backtick only), a run of 3 or
#   more of the same character, 0-3 literal leading spaces, closing only on
#   a run of the SAME character at least as long as the opener. States:
#     OUT — not inside a fence.
#     IN  — inside a fence (fence_char, fence_len recorded).
#   Transition table (F):
#     OUT  + line opens a fence (backtick or tilde run >=3)      -> IN   (line is a delimiter: never content)
#     OUT  + any other line                                      -> OUT  (line is content)
#     IN   + line closes the open fence (same char, run>=fence_len,
#            0-3 leading spaces, nothing but trailing whitespace) -> OUT  (line is a delimiter: never content)
#     IN   + any other line                                      -> IN   (line is not content)
#   `content_active` is true only when the CURRENT (pre-transition) F is OUT
#   and the line is not itself a fence delimiter (i.e. not an opener).
#
#   R — the declaration region. Opens at the (unfenced) `BEGIN intent-block`
#   marker, closes at the FIRST unfenced `^## ` heading after it — ANY
#   heading, not specifically `## Non-goals` (this is a deliberate departure
#   from the carved-out generation, closing AC4's finding: a spec with no
#   `## Non-goals` heading at all must not let the region grow unbounded).
#   States: R0 (not yet open) -> R1 (open) -> R2 (closed, terminal).
#   Transition table (R), evaluated only on a content line:
#     R0 + BEGIN marker line       -> R1
#     R0 + any other content line  -> R0   (identity)
#     R1 + `^## ` heading line     -> R2
#     R1 + any other content line  -> R1   (identity)
#     R2 + any content line        -> R2   (identity; terminal)
#   On a non-content line: R stays exactly as it is (identity), regardless
#   of state — this is the explicit identity transition a fenced `^## `
#   heading takes, so a spec quoting its own grammar in a fenced block never
#   closes R by accident.
#   `- user-visible:` and `- shipped-docs:` are valid ("well-placed") only
#   when R == R1 AND the occurrence's own line sits strictly before the
#   intent block's END marker (`i < end_ln`) at the moment they are matched;
#   a well-formed occurrence at R0 or R2, OR one at R1 but at-or-after END,
#   is `declaration-misplaced` / `shipped-docs-misplaced`, never "missing"
#   (a different repair from "you forgot it"). The second clause exists
#   because R alone has no upper bound at END: an intent block that itself
#   carries no `^## ` heading before END leaves R open past END, all the way
#   to the file's next heading (wherever that falls) — exactly the same
#   `begin_ln < i < end_ln` bound WAIVER_RE/SURFACE_RE already apply, now
#   applied to this family too (round-3 review fix, class
#   `positional-boundary-unbounded-at-END`; R's OWN closing rule — first
#   `^## ` heading after BEGIN — is unchanged, this is a second, independent
#   positional clause on top of it, not a redefinition of R).
#
#   S — acceptance-criterion scope, tracked across the WHOLE file (not
#   bounded to the intent block) mirroring this repository's own board-entry
#   continuation canon. States: S0 (not in AC scope), S1 (in AC scope).
#   Transition table (S), evaluated only on a content line:
#     any + blank line                                  -> unchanged (identity; neutral)
#     any + indented, non-blank line                     -> unchanged (identity; an indented line
#                                                            never itself opens or closes scope)
#     any + unindented, non-blank, AC-bullet-shaped line
#           (`^- \[[ xX]\] \*\*AC`)                       -> S1
#     any + unindented, non-blank, NOT AC-bullet-shaped   -> S0
#   On a non-content line: S stays exactly as it is (identity) — a fenced
#   `## ` heading or a fenced blank line never closes or reopens AC scope;
#   this is the control-pair behaviour AC3 asserts.
#   `- adopter-surface:` is valid only when it is an indented continuation
#   line (`^[[:space:]]+- adopter-surface:`), S == S1 at the moment it is
#   matched, AND its line sits strictly inside the intent block (between the
#   BEGIN and END markers) — the wider window T-1061 froze for waiver/
#   surface, distinct from R's narrower declaration-region window.
#   `- adopter-docs-waiver:` has no AC-nesting requirement of its own (T-1061's
#   Goal: "the spec carries a top-level ... line") — it is valid whenever it
#   is unindented and sits strictly inside the intent block, independent of S.
#
#   VALUE RETENTION: both `- adopter-surface:` and `- adopter-docs-waiver:`
#   are legal to occur more than once in scope. Discharge is "at least one
#   in-scope occurrence carries a non-whitespace value", decided from the
#   full multiset of in-scope occurrences — never "the first occurrence's
#   value" — so the verdict never depends on file order (T-1061 round-1
#   rework, Major #2).
#
# THE REFUSAL DECISION. Every token match (declaration, shipped-docs, waiver,
# surface) is recorded together with the (R, S) pair and position in force
# at that moment while the single sweep runs. Once the sweep completes, a
# fixed SET of candidate refusal tokens is built from those recorded facts,
# and the verdict is the FIRST token, in this frozen precedence order, that
# is present in the candidate set — so the verdict never depends on the
# order occurrences happen to appear in the file:
#
#   usage, spec-unreadable, intent-block-missing,
#   declaration-missing, declaration-duplicate, declaration-malformed,
#   declaration-misplaced, marker-conflict, waiver-reason-empty,
#   obligation-undischarged, shipped-docs-misplaced, shipped-docs-malformed,
#   shipped-docs-missing, shipped-docs-unmeasured
#
# The `shipped-docs-*` family sits LAST deliberately: it preserves every one
# of the carved-out generation's 42 refusal verdicts unchanged.
#
# `shipped-docs-unmeasured` is decided as a STRING RELATION between lines of
# the same file: a `this-task` path is unmeasured when it is a literal
# substring of NO fence-aware line matching `^[[:space:]]*- check:` or
# `^[[:space:]]*- adopter-surface:` anywhere in the file. Unlike every other
# window this file tracks, `MEASURE_LINES` is DELIBERATELY whole-file, not
# bounded to the intent block: AC11's own Input space and the Goal's wording
# ("a literal substring of no fence-aware ... line in the file") both name
# the whole file as the reading side, so a `- check:` line living in
# `## Notes for engineer` legitimately discharges an in-block path — this
# was re-swept for the round-3 review's boundary-escape class and confirmed
# intentional, not a second instance of the same defect. This script
# performs NO filesystem access on that path — never `test -f`, never a
# glob, never a path resolution — T-1061's frozen Non-goal (no content
# judgment, no path allowlist) is the design invariant this task inherits
# rather than revisits.
#
# A `- shipped-docs:` line beside a `no` declaration reuses the existing
# `marker-conflict` token rather than minting a fifteenth.
#
# Usage:
#   check-adopter-docs.sh [--] <spec.md>
#     Read <spec.md>'s frozen intent block for the declaration above. Exit 0
#     on a clean pass (silently — zero bytes on stdout AND stderr). A refusal
#     writes exactly one token, alone, to stderr and zero bytes to stdout.
#   check-adopter-docs.sh --help
#     Print this header and exit 0 (at least one byte on stdout).
#
# Exit codes and the CLOSED FOURTEEN-token refusal set (every refusal is one
# token, alone, on stderr — never embedded in a longer message — with zero
# bytes on stdout; nothing outside this set is ever printed on a refusal):
#   usage (2)                   — a bad invocation: an unknown flag, a
#                                  missing or extra positional argument.
#   spec-unreadable (2)         — the given path does not exist, is not a
#                                  regular file, or is not readable (a
#                                  directory, a FIFO, a dangling symlink, or
#                                  an unreadable regular file all land here).
#   intent-block-missing (2)    — the unfenced marker pair
#                                  `<!-- BEGIN intent-block: ... -->` /
#                                  `<!-- END intent-block: ... -->` does not
#                                  resolve to exactly one region, BEGIN
#                                  strictly before END (zero, more than one,
#                                  reversed, or a marker pair whose only
#                                  occurrence sits inside a fenced code block
#                                  all land here — this script's contract
#                                  for anything it cannot resolve into
#                                  exactly one region is exit 2, never a
#                                  guess).
#   declaration-missing (1)     — zero unindented, unfenced occurrences of
#                                  `- user-visible:` anywhere in the file (an
#                                  indented or fenced-only occurrence counts
#                                  as zero, by design).
#   declaration-duplicate (1)   — two or more such occurrences, anywhere in
#                                  the file.
#   declaration-malformed (1)   — exactly one such occurrence, but its value
#                                  is not exactly `yes` or `no`, its
#                                  separator is absent, or its rationale is
#                                  absent or whitespace-only.
#   declaration-misplaced (1)   — exactly one well-formed occurrence, but it
#                                  sits outside the declaration region R
#                                  (before BEGIN, at/after the first `## `
#                                  heading after BEGIN, or at/after END —
#                                  the last of these reachable only when the
#                                  intent block itself carries no `^## `
#                                  heading before END, per the round-3 fix).
#   marker-conflict (1)         — a `yes` declaration carrying both waiver
#                                  and surface at once, or a `no` declaration
#                                  carrying a waiver, a surface, or a
#                                  `- shipped-docs:` line at all.
#   waiver-reason-empty (1)     — a `yes` declaration whose ONLY discharge
#                                  marker is an `- adopter-docs-waiver:` line
#                                  whose reason is absent or whitespace-only
#                                  (distinct from obligation-undischarged:
#                                  the marker exists, but says nothing).
#   obligation-undischarged (1) — a `yes` declaration with neither a
#                                  non-empty `- adopter-surface:` value nor a
#                                  non-empty `- adopter-docs-waiver:` reason
#                                  (an all-whitespace surface value counts as
#                                  undischarged, not as a separate refusal).
#   shipped-docs-misplaced (1)  — a `yes` declaration with at least one
#                                  `- shipped-docs:` occurrence outside R
#                                  (before BEGIN, at/after the first `## `
#                                  heading after BEGIN, or at/after END).
#   shipped-docs-malformed (1)  — a `yes` declaration with at least one
#                                  `- shipped-docs:` occurrence whose
#                                  separator is absent, whose path is empty,
#                                  or whose disposition is neither
#                                  `this-task` nor `issue #<digits>`.
#   shipped-docs-missing (1)    — a `yes` declaration with zero
#                                  `- shipped-docs:` occurrences anywhere.
#   shipped-docs-unmeasured (1) — a `yes` declaration with a `this-task`
#                                  `- shipped-docs:` path that is a literal
#                                  substring of no fence-aware `- check:` or
#                                  `- adopter-surface:` line in the file.
#
# This script writes nothing anywhere, under any environment: no
# output-file flag, no environment variable, and nothing it reads is ever
# written to.

set -euo pipefail

# Resolve this script's own file, following symlinks (2026-07-14 lesson:
# reuse the repository's proven symlink-safe resolver rather than
# hand-rolling one) — ported verbatim from the carved-out generation, which
# itself ported the bootstrap shape from bin/check-intent.sh /
# bin/check-interventions.sh, with `pwd -P` throughout (physical, every
# symlink resolved) rather than a bare logical `pwd`.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || { printf 'usage\n' >&2 || true; exit 2; }
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || { printf 'usage\n' >&2 || true; exit 2; }
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || { printf 'usage\n' >&2 || true; exit 2; }
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || { printf 'usage\n' >&2 || true; exit 2; }
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || { printf 'usage\n' >&2 || true; exit 2; }
self_name="$(basename "$script_path")" \
  || { printf 'usage\n' >&2 || true; exit 2; }
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next}{exit}' "$SELF" \
    || { printf 'usage\n' >&2 || true; exit 2; }
}

# --- classified refusal helper -----------------------------------------------
# One bare token, alone, on stderr — never embedded in a longer message — so
# a caller (or this script's own fixture suite) can grep it with `grep -x`.
# `|| true` guards the write (T-096 convention): a closed-stderr caller must
# not turn the intended exit code into a bare errexit before `exit "$2"` runs.
refuse() {  # $1 = token (closed fourteen-token set); $2 = exit code (1|2)
  printf '%s\n' "$1" >&2 || true
  exit "$2"
}

# --- argument parsing (single positional; -- ends option parsing) -----------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --) shift; break ;;
    -*) refuse usage 2 ;;
    *)  break ;;
  esac
done

SPEC=""
if [ "$#" -ge 1 ]; then SPEC="$1"; shift; fi
[ "$#" -eq 0 ] || refuse usage 2
[ -n "$SPEC" ] || refuse usage 2

# `-f` (regular file) before `-r` (readable) — a directory/FIFO is classified
# by its TYPE, not by permissions; a dangling symlink is caught by `-f` alone
# (it follows symlinks and is false for a dangling target).
[ -f "$SPEC" ] && [ -r "$SPEC" ] || refuse spec-unreadable 2

# --- trim: strip leading/trailing whitespace ---------------------------------
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# =============================================================================
# PASS 1 — read the file into a 1-indexed array, CR-stripped, computing F
# (fence state) per line. Backtick AND tilde runs of length >=3, 0-3 literal
# leading spaces; closes only on a run of the SAME character, length >=
# the opener's.
# =============================================================================
FENCE_OPEN_RE='^[ ]{0,3}(`{3,}|~{3,})'

LINES=()
FENCED=()
in_fence=0
fence_len=0
fence_char=''
n=0
while IFS= read -r raw || [ -n "$raw" ]; do
  n=$((n + 1))
  line="${raw%$'\r'}"
  LINES[n]="$line"
  if [ "$in_fence" -eq 0 ]; then
    if [[ "$line" =~ $FENCE_OPEN_RE ]]; then
      fence_char="${BASH_REMATCH[1]:0:1}"
      fence_len="${#BASH_REMATCH[1]}"
      in_fence=1
      FENCED[n]=1
    else
      FENCED[n]=0
    fi
  else
    if [ "$fence_char" = '`' ]; then
      close_re='^[ ]{0,3}`{'"$fence_len"',}[[:space:]]*$'
    else
      close_re='^[ ]{0,3}~{'"$fence_len"',}[[:space:]]*$'
    fi
    if [[ "$line" =~ $close_re ]]; then
      in_fence=0
    fi
    FENCED[n]=1
  fi
done < "$SPEC"
NLINES="$n"

# =============================================================================
# PASS 2 — locate the intent block: the UNFENCED marker pair alone, no
# task-id derivation of this script's own (bin/check-intent.sh owns that
# scoping). Must resolve to exactly one region, BEGIN strictly before END.
# =============================================================================
BEGIN_RE='^<!-- BEGIN intent-block: .+ -->$'
END_RE='^<!-- END intent-block: .+ -->$'

begin_count=0
begin_ln=0
end_count=0
end_ln=0
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${FENCED[i]}" -eq 0 ]; then
    if [[ "${LINES[i]}" =~ $BEGIN_RE ]]; then
      begin_count=$((begin_count + 1))
      begin_ln="$i"
    fi
    if [[ "${LINES[i]}" =~ $END_RE ]]; then
      end_count=$((end_count + 1))
      end_ln="$i"
    fi
  fi
  i=$((i + 1))
done

if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
  refuse intent-block-missing 2
fi
if [ "$begin_ln" -ge "$end_ln" ]; then
  refuse intent-block-missing 2
fi

# =============================================================================
# PASS 3 — the single per-line sweep computing R and S, matching tokens.
# Every line produces a transition in R and S, identity transitions
# included: on a non-content line (F says fenced-out or a delimiter), R and
# S are explicitly left unchanged rather than skipped past with a
# `continue` — the shape whose absence was the carved-out generation's open
# R2 finding.
# =============================================================================
HEADING_RE='^## '
DECL_RE='^- user-visible:(.*)$'
SHIPPED_RE='^- shipped-docs:(.*)$'
WAIVER_RE='^- adopter-docs-waiver:(.*)$'
# SURFACE_RE requires at least one leading whitespace char (indented) — an
# unindented occurrence is invisible, by design.
SURFACE_RE='^[[:space:]]+- adopter-surface:(.*)$'
# AC_BULLET_RE mirrors bin/check-acs.sh's own CANDIDATE_RE shape
# (`^- \[[ xX]\] \*\*AC`): a column-0 "is this AC-bullet-shaped at all"
# test, deliberately permissive — this script never re-validates the
# bullet's own grammar.
AC_BULLET_RE='^- \[[ xX]\] \*\*AC'
INDENT_NONBLANK_RE='^[[:space:]]+[^[:space:]]'
BLANK_RE='^[[:space:]]*$'

DECL_POS=(); DECL_RVAL=()
SHIP_POS=(); SHIP_RVAL=()
waiver_count=0
waiver_has_value=0
surface_count=0
surface_has_value=0

R=0  # 0 = not yet open, 1 = open, 2 = closed (terminal)
S=0  # 0 = not in AC scope, 1 = in AC scope
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${FENCED[i]}" -eq 1 ]; then
    : # explicit identity transition: F says this line is not content, so
      # neither R nor S transitions at all — this is the fix for the R2
      # finding (never a `continue` that skips the scope effect silently).
  else
    line="${LINES[i]}"

    # --- R transition (identity when neither trigger applies) -------------
    if [ "$R" -eq 0 ]; then
      if [[ "$line" =~ $BEGIN_RE ]]; then
        R=1
      fi
      # else: identity, R stays 0
    elif [ "$R" -eq 1 ]; then
      if [[ "$line" =~ $HEADING_RE ]]; then
        R=2
      fi
      # else: identity, R stays 1
    fi
    # R -eq 2: terminal, identity always (no branch needed — no transition
    # out of R2 exists in this grammar).

    # --- S transition, nested trichotomy; token matching happens inside it,
    # exactly mirroring this repository's board-entry continuation canon ---
    if [[ "$line" =~ $BLANK_RE ]]; then
      : # identity: a blank line changes neither S nor anything else
    elif [[ "$line" =~ $INDENT_NONBLANK_RE ]]; then
      : # identity for S: an indented line never itself opens or closes
        # AC scope — it is only checked for a surface match while S is
        # already open.
      if [ "$S" -eq 1 ] && [[ "$line" =~ $SURFACE_RE ]]; then
        if [ "$i" -gt "$begin_ln" ] && [ "$i" -lt "$end_ln" ]; then
          surface_count=$((surface_count + 1))
          val="$(trim "${BASH_REMATCH[1]}")"
          [ -n "$val" ] && surface_has_value=1
        fi
      fi
    else
      # a non-indented, non-blank content line: closes any open AC scope
      # first, then opens a new one only if THIS SAME line is itself
      # AC-bullet-shaped.
      if [[ "$line" =~ $AC_BULLET_RE ]]; then
        S=1
      else
        S=0
      fi
      if [[ "$line" =~ $DECL_RE ]]; then
        DECL_POS+=("$i")
        DECL_RVAL+=("$R")
      fi
      if [[ "$line" =~ $SHIPPED_RE ]]; then
        SHIP_POS+=("$i")
        SHIP_RVAL+=("$R")
      fi
      if [[ "$line" =~ $WAIVER_RE ]]; then
        if [ "$i" -gt "$begin_ln" ] && [ "$i" -lt "$end_ln" ]; then
          waiver_count=$((waiver_count + 1))
          val="$(trim "${BASH_REMATCH[1]}")"
          [ -n "$val" ] && waiver_has_value=1
        fi
      fi
    fi
  fi
  i=$((i + 1))
done

# --- the whole-file, fence-aware measurement-line corpus for
# shipped-docs-unmeasured (never a filesystem read; a pure string relation
# between lines of this same file) --------------------------------------------
CHECK_OR_SURFACE_RE='^[[:space:]]*- (check|adopter-surface):'
MEASURE_LINES=()
i=1
while [ "$i" -le "$NLINES" ]; do
  if [ "${FENCED[i]}" -eq 0 ] && [[ "${LINES[i]}" =~ $CHECK_OR_SURFACE_RE ]]; then
    MEASURE_LINES+=("${LINES[i]}")
  fi
  i=$((i + 1))
done
MEASURE_COUNT=${#MEASURE_LINES[@]}

# =============================================================================
# DECISION — build the candidate set, then refuse the first token the frozen
# precedence order finds present in it.
# =============================================================================
CANDS=()
decl_family_bad=0
DECL_VALUE=""

decl_count=${#DECL_POS[@]}
if [ "$decl_count" -eq 0 ]; then
  CANDS+=("declaration-missing")
  decl_family_bad=1
elif [ "$decl_count" -ge 2 ]; then
  CANDS+=("declaration-duplicate")
  decl_family_bad=1
else
  dpos="${DECL_POS[0]}"
  drval="${DECL_RVAL[0]}"
  dline="${LINES[$dpos]}"
  # The separator is the literal em dash (U+2014); split on the FIRST
  # occurrence, then trim both sides — tolerates a rationale that itself
  # later quotes an em dash.
  EMDASH='—'
  rest="${dline#"- user-visible:"}"
  decl_bad_grammar=0
  case "$rest" in
    *"$EMDASH"*) : ;;
    *) decl_bad_grammar=1 ;;
  esac
  if [ "$decl_bad_grammar" -eq 0 ]; then
    value_part="${rest%%"$EMDASH"*}"
    rationale_part="${rest#*"$EMDASH"}"
    DECL_VALUE="$(trim "$value_part")"
    rationale="$(trim "$rationale_part")"
    case "$DECL_VALUE" in
      yes|no) : ;;
      *) decl_bad_grammar=1 ;;
    esac
    [ -n "$rationale" ] || decl_bad_grammar=1
  fi
  if [ "$decl_bad_grammar" -eq 1 ]; then
    CANDS+=("declaration-malformed")
    decl_family_bad=1
  fi
  # R alone is not a sufficient bound: an intent block carrying no `^## `
  # heading before its own END marker leaves R open (1) past END, so a
  # SECOND positional clause — dpos < end_ln — is required in addition to
  # R == 1, exactly as WAIVER_RE/SURFACE_RE already require begin_ln < i <
  # end_ln. A well-formed occurrence at or after END is misplaced, on the
  # same footing as one before BEGIN (R0) or after the first heading (R2).
  if [ "$drval" -ne 1 ] || [ "$dpos" -ge "$end_ln" ]; then
    CANDS+=("declaration-misplaced")
    decl_family_bad=1
  fi
fi

ship_count=${#SHIP_POS[@]}

if [ "$decl_family_bad" -eq 0 ]; then
  if [ "$DECL_VALUE" = "no" ]; then
    if [ "$waiver_count" -ge 1 ] || [ "$surface_count" -ge 1 ] || [ "$ship_count" -ge 1 ]; then
      CANDS+=("marker-conflict")
    fi
  else
    # DECL_VALUE = yes
    if [ "$waiver_count" -ge 1 ] && [ "$surface_count" -ge 1 ]; then
      CANDS+=("marker-conflict")
    fi
    if [ "$waiver_count" -ge 1 ] && [ "$surface_count" -eq 0 ] && [ "$waiver_has_value" -eq 0 ]; then
      CANDS+=("waiver-reason-empty")
    fi
    if [ "$surface_count" -ge 1 ] && [ "$waiver_count" -eq 0 ] && [ "$surface_has_value" -eq 0 ]; then
      CANDS+=("obligation-undischarged")
    fi
    if [ "$waiver_count" -eq 0 ] && [ "$surface_count" -eq 0 ]; then
      CANDS+=("obligation-undischarged")
    fi

    # --- shipped-docs family (issue #577), only meaningful for a `yes` ----
    if [ "$ship_count" -eq 0 ]; then
      CANDS+=("shipped-docs-missing")
    else
      ship_bad_place=0
      ship_bad_grammar=0
      ship_unmeasured=0
      k=0
      while [ "$k" -lt "$ship_count" ]; do
        spos="${SHIP_POS[$k]}"
        srval="${SHIP_RVAL[$k]}"
        sline="${LINES[$spos]}"
        # Same second positional clause as the declaration check above: R
        # alone does not bound this family either, so a `- shipped-docs:`
        # line at or after END (R still open, no heading seen yet) is
        # misplaced too, not accepted.
        if [ "$srval" -ne 1 ] || [ "$spos" -ge "$end_ln" ]; then
          ship_bad_place=1
        fi
        srest="${sline#"- shipped-docs:"}"
        this_bad=0
        case "$srest" in
          *"$EMDASH"*) : ;;
          *) this_bad=1 ;;
        esac
        spath=""
        sdisp=""
        if [ "$this_bad" -eq 0 ]; then
          spath_part="${srest%%"$EMDASH"*}"
          sdisp_part="${srest#*"$EMDASH"}"
          spath="$(trim "$spath_part")"
          sdisp="$(trim "$sdisp_part")"
          [ -n "$spath" ] || this_bad=1
          case "$sdisp" in
            this-task) : ;;
            "issue #"*)
              digits="${sdisp#issue #}"
              case "$digits" in
                ''|*[!0-9]*) this_bad=1 ;;
              esac
              ;;
            *) this_bad=1 ;;
          esac
        fi
        if [ "$this_bad" -eq 1 ]; then
          ship_bad_grammar=1
        fi
        if [ "$this_bad" -eq 0 ] && [ "$sdisp" = "this-task" ]; then
          found=0
          mi=0
          while [ "$mi" -lt "$MEASURE_COUNT" ]; do
            ml="${MEASURE_LINES[$mi]}"
            if [[ "$ml" == *"$spath"* ]]; then
              found=1
              break
            fi
            mi=$((mi + 1))
          done
          [ "$found" -eq 1 ] || ship_unmeasured=1
        fi
        k=$((k + 1))
      done
      [ "$ship_bad_place" -eq 1 ] && CANDS+=("shipped-docs-misplaced")
      [ "$ship_bad_grammar" -eq 1 ] && CANDS+=("shipped-docs-malformed")
      [ "$ship_unmeasured" -eq 1 ] && CANDS+=("shipped-docs-unmeasured")
    fi
  fi
fi

# The frozen refusal precedence — the verdict is the FIRST of these present
# in CANDS, so it never depends on the order occurrences appear in the file.
PRECEDENCE=(
  declaration-missing declaration-duplicate declaration-malformed
  declaration-misplaced marker-conflict waiver-reason-empty
  obligation-undischarged shipped-docs-misplaced shipped-docs-malformed
  shipped-docs-missing shipped-docs-unmeasured
)

found_token=""
cand_count=${#CANDS[@]}
p_count=${#PRECEDENCE[@]}
pi=0
while [ "$pi" -lt "$p_count" ]; do
  tok="${PRECEDENCE[$pi]}"
  cj=0
  while [ "$cj" -lt "$cand_count" ]; do
    if [ "${CANDS[$cj]}" = "$tok" ]; then
      found_token="$tok"
      break 2
    fi
    cj=$((cj + 1))
  done
  pi=$((pi + 1))
done

if [ -n "$found_token" ]; then
  refuse "$found_token" 1
fi

exit 0
