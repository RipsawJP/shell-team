#!/usr/bin/env bash
# rework-digest.sh — format the rework-history digest for a loop-guard STOP
# escalation (T-058, #148), or for an early non-STOP same-class-2 escalation
# (T-100, #219).
#
# Presentation-only: reads no files, writes no files. The orchestrator already
# performs the Same-class-2 root-cause classification itself (shell-team SKILL
# steps 5/6), so this helper takes that STRUCTURED state as flags and prints a
# fixed-format digest — the extend/stop decision material for the human. It
# never parses board prose (the rework sub-bullets stay a human audit trail).
#
# Usage:
#   rework-digest.sh --round N --phase validate|review --class <slug> \
#                    [--round N --phase ... --class ...]... \
#                    (--stop-reason <reason> | --trigger same-class-2)
#
#   --round N        starts a record; N is a positive integer (<= 9 digits,
#                    same overflow bound as loop-guard.sh). Repeat the same
#                    round number to record several classes in one round.
#   --phase          validate | review (which gate produced the finding)
#   --class <slug>   root-cause class slug: lowercase alphanumerics + hyphens
#                    (^[a-z0-9][a-z0-9-]*$). NOTE: the charset alone does NOT
#                    keep the digest signature-clean — goal-state.sh greps with
#                    `-w` and a hyphen is a word boundary, so a legal slug like
#                    `test-pass-case` would leak a whole-word PASS. The script
#                    therefore self-checks the assembled digest through the
#                    sibling goal-state.sh `signature` and fails closed unless
#                    the result is NO_VERDICT (auto-tracks goal-state's
#                    vocabulary if it ever grows).
#   --stop-reason    STOP mode: exactly one of loop-guard.sh's STOP enum:
#                    max_iterations_reached | budget_exhausted |
#                    no_progress | guard_error
#   --trigger        early mode: exactly one enum value: same-class-2 — run
#                    this the moment same-class-2 is reached, before any
#                    loop-guard STOP. `--stop-reason` and `--trigger` are
#                    mutually exclusive and exactly one is required (both
#                    present, or neither present, fails closed).
#   --reflection     OPTIONAL (T-1095). Records the outcome of the
#                    means-ends reflection duty (`templates/prompt-blocks/
#                    means-ends-reflection.md`) as a closed five-value enum —
#                    never free text, because the assembled digest is piped
#                    through goal-state.sh `signature` below and a prose
#                    field could leak a verdict label or an AC<digits> token:
#                      disposition-executed        — the pre-priced drop for
#                                                     the earliest droppable
#                                                     component executed on
#                                                     the loop's own authority
#                      escalated-primary-not-green — an item of the
#                                                     never-dropped set was
#                                                     not green
#                      escalated-never-dropped     — a finding targeted the
#                                                     never-dropped set
#                      escalated-irreversible      — the pre-priced
#                                                     disposition was itself
#                                                     destructive/irreversible
#                      escalated-no-disposition    — no pre-priced disposition
#                                                     existed for a targeted
#                                                     component (this also
#                                                     covers an empty or
#                                                     unclassified finding set)
#                    Where more than one condition holds at once, the value
#                    to record is the EARLIEST in this fixed precedence order:
#                    escalated-primary-not-green, escalated-never-dropped,
#                    escalated-irreversible, escalated-no-disposition — this
#                    script only records the label the caller supplies, it
#                    never computes or arbitrates the precedence itself.
#                    Optional and mode-independent: usable with either
#                    --stop-reason or --trigger, and omitting it leaves the
#                    digest's printed shape byte-identical to before this
#                    flag existed.
#   --rounds-total   OPTIONAL (T-1145, #491). Requests the convergence block
#                    (see below). Positive integer, 1-999. Mandatory together
#                    with at least one --never-dropped when the block is
#                    requested; must be >= the highest --round in the
#                    records (a round with zero findings is real and
#                    represented by this count, never by a sentinel record).
#   --never-dropped  OPTIONAL (T-1145). Repeatable. `<name>=<state>`, name a
#                    lowercase slug (^[a-z0-9][a-z0-9-]*$), state one of
#                    green | hit-this-round | hit-earlier. At least one is
#                    required together with --rounds-total when the block is
#                    requested.
#   --instance       OPTIONAL (T-1145). Repeatable. `<class>=<value>`, value
#                    one of same | distinct. Exactly one is required per
#                    class slug repeating (>=2 occurrences) in the records
#                    when the block is requested; naming a class that does
#                    not repeat, or that is absent, is refused.
#
#                    CONVERGENCE BLOCK (T-1145, issue #491): supplying at
#                    least one of --rounds-total / --never-dropped /
#                    --instance requests a `convergence: converging |
#                    not-converging` line immediately after `stop-reason:`,
#                    with `trend:`, `never-dropped:`, `instances:` and
#                    `convergence-action:` ground lines. STOP mode only —
#                    any of these three paired with --trigger is refused.
#                    Supplying none of them leaves stdout byte-identical to
#                    before this feature existed; supplying some but not all
#                    of the mandatory-together set, or a class-vs-instance
#                    mismatch, exits 2 with nothing on stdout — never a
#                    partial verdict. The verdict states; it never decides.
#
# Judgment: any class slug appearing >= 2 times across the records =>
# `judgment: same-class-repetition` plus a `repeated-classes:` line; all
# distinct => `judgment: new-classes-each-round`. In `--trigger same-class-2`
# mode, the records MUST show a repeated class (>= 2 occurrences) — an
# all-distinct records set fails closed rather than emitting the
# `new-classes-each-round` branch (early mode never emits it).
#
# FAIL-CLOSED: any unknown flag, missing value, out-of-enum value, incomplete
# triple, zero records, missing/duplicate --stop-reason, missing/duplicate/
# bad-value --trigger, both --stop-reason and --trigger present, neither
# present, or (early mode only) an all-distinct records set exits 2 with
# usage on stderr and NOTHING on stdout (no partial digest). Exit 0 only with
# the full digest printed.

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  awk 'NR==1 { next } /^set -euo pipefail$/ { exit } { line = $0; sub(/^#[ \t]*/, "", line); print line }' "${BASH_SOURCE[0]}"
  exit 0
fi

usage() {
  cat >&2 <<'EOF' || true
usage: rework-digest.sh --round N --phase validate|review --class <slug> \
                        [--round N --phase ... --class ...]... \
                        (--stop-reason <reason> | --trigger same-class-2) \
                        [--reflection <value>]

  Records are --round/--phase/--class triples (repeatable; a new --round
  closes the previous record, which must be complete). Exactly one of
  --stop-reason or --trigger is required (mutually exclusive):
    --stop-reason  one of loop-guard.sh's STOP reasons:
                   max_iterations_reached | budget_exhausted | no_progress |
                   guard_error
    --trigger      exactly the enum value same-class-2 (early, non-STOP
                   escalation) — requires the records to show a repeated
                   class (>= 2 occurrences).
  Class slugs are lowercase alphanumerics + hyphens (^[a-z0-9][a-z0-9-]*$).

  --reflection <value>  OPTIONAL, closed enum, works with either mode above:
    disposition-executed | escalated-primary-not-green |
    escalated-never-dropped | escalated-irreversible |
    escalated-no-disposition
  Precedence when more than one escalation condition holds at once (the
  caller decides and supplies the single earliest value; this script never
  computes it): escalated-primary-not-green, escalated-never-dropped,
  escalated-irreversible, escalated-no-disposition.

  Convergence block (T-1145, #491) — STOP mode only, requested by supplying
  at least one of:
    --rounds-total N        total rounds run, 1-999, >= the highest --round
                            in the records. Mandatory together with
                            --never-dropped once the block is requested.
    --never-dropped <name>=<green|hit-this-round|hit-earlier>
                            repeatable; at least one required once the
                            block is requested.
    --instance <class>=<same|distinct>
                            repeatable; exactly one required per class
                            repeating (>=2 occurrences) in the records.
  Supplying some but not all of the mandatory-together set, or an --instance
  whose class does not repeat (or is absent), or any of these three paired
  with --trigger, is refused: exit 2, nothing on stdout.
EOF
  exit 2
}

fail() {
  printf 'rework-digest: %s\n' "$1" >&2 || true
  usage
}

ROUNDS=()
PHASES=()
CLASSES=()
STOP_REASON=""
TRIGGER=""
REFLECTION=""
ROUNDS_TOTAL=""
ND_NAMES=()
ND_STATES=()
INST_CLASSES=()
INST_VALUES=()
cur_round=""
cur_phase=""
cur_class=""
in_record=0

# Close the currently open record; an open record missing --phase or --class
# is an incomplete triple (fail-closed).
flush_record() {
  local missing=""
  if [[ "$in_record" -eq 1 ]]; then
    if [[ -z "$cur_phase" ]]; then missing="--phase"; fi
    if [[ -z "$cur_class" ]]; then missing="${missing:+${missing} and }--class"; fi
    if [[ -n "$missing" ]]; then
      fail "incomplete record for --round ${cur_round}: missing ${missing}"
    fi
    ROUNDS+=("$cur_round")
    PHASES+=("$cur_phase")
    CLASSES+=("$cur_class")
    cur_round=""
    cur_phase=""
    cur_class=""
    in_record=0
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --round)
      if [[ $# -lt 2 ]]; then fail "missing value for --round"; fi
      flush_record
      # Positive integer, width-bounded like loop-guard.sh; 10# blocks octal.
      if [[ ! "$2" =~ ^[0-9]{1,9}$ ]] || (( 10#$2 < 1 )); then
        fail "--round must be a positive integer (<= 9 digits): '$2'"
      fi
      cur_round="$2"
      in_record=1
      shift 2
      ;;
    --phase)
      if [[ $# -lt 2 ]]; then fail "missing value for --phase"; fi
      if [[ "$in_record" -ne 1 ]]; then fail "--phase must follow a --round"; fi
      if [[ -n "$cur_phase" ]]; then fail "duplicate --phase in record for round ${cur_round}"; fi
      case "$2" in
        validate|review) cur_phase="$2" ;;
        *) fail "--phase must be validate|review: '$2'" ;;
      esac
      shift 2
      ;;
    --class)
      if [[ $# -lt 2 ]]; then fail "missing value for --class"; fi
      if [[ "$in_record" -ne 1 ]]; then fail "--class must follow a --round"; fi
      if [[ -n "$cur_class" ]]; then fail "duplicate --class in record for round ${cur_round}"; fi
      if [[ ! "$2" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        fail "--class must be a lowercase slug (^[a-z0-9][a-z0-9-]*\$): '$2'"
      fi
      cur_class="$2"
      shift 2
      ;;
    --stop-reason)
      if [[ $# -lt 2 ]]; then fail "missing value for --stop-reason"; fi
      if [[ -n "$STOP_REASON" ]]; then fail "duplicate --stop-reason"; fi
      case "$2" in
        max_iterations_reached|budget_exhausted|no_progress|guard_error) STOP_REASON="$2" ;;
        *) fail "--stop-reason must be a loop-guard STOP reason: '$2'" ;;
      esac
      shift 2
      ;;
    --trigger)
      if [[ $# -lt 2 ]]; then fail "missing value for --trigger"; fi
      if [[ -n "$TRIGGER" ]]; then fail "duplicate --trigger"; fi
      case "$2" in
        same-class-2) TRIGGER="$2" ;;
        *) fail "--trigger must be same-class-2: '$2'" ;;
      esac
      shift 2
      ;;
    --reflection)
      if [[ $# -lt 2 ]]; then fail "missing value for --reflection"; fi
      if [[ -n "$REFLECTION" ]]; then fail "duplicate --reflection"; fi
      case "$2" in
        disposition-executed|escalated-no-disposition|escalated-never-dropped|escalated-irreversible|escalated-primary-not-green) REFLECTION="$2" ;;
        *) fail "--reflection must be one of the five enum values: '$2'" ;;
      esac
      shift 2
      ;;
    --rounds-total)
      if [[ $# -lt 2 ]]; then fail "missing value for --rounds-total"; fi
      if [[ -n "$ROUNDS_TOTAL" ]]; then fail "duplicate --rounds-total"; fi
      if [[ ! "$2" =~ ^[0-9]{1,3}$ ]] || (( 10#$2 < 1 )); then
        fail "--rounds-total must be a positive integer (<= 3 digits): '$2'"
      fi
      ROUNDS_TOTAL="$2"
      shift 2
      ;;
    --never-dropped)
      if [[ $# -lt 2 ]]; then fail "missing value for --never-dropped"; fi
      if [[ "$2" != *=* ]]; then
        fail "--never-dropped must be name=state: '$2'"
      fi
      nd_name="${2%%=*}"
      nd_state="${2#*=}"
      if [[ -z "$nd_name" || ! "$nd_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        fail "--never-dropped name must be a lowercase slug (^[a-z0-9][a-z0-9-]*\$): '$nd_name'"
      fi
      case "$nd_state" in
        green|hit-this-round|hit-earlier) : ;;
        *) fail "--never-dropped state must be green|hit-this-round|hit-earlier: '$nd_state'" ;;
      esac
      for nd_i in "${!ND_NAMES[@]}"; do
        if [[ "${ND_NAMES[$nd_i]}" == "$nd_name" ]]; then fail "duplicate --never-dropped for '$nd_name'"; fi
      done
      ND_NAMES+=("$nd_name")
      ND_STATES+=("$nd_state")
      shift 2
      ;;
    --instance)
      if [[ $# -lt 2 ]]; then fail "missing value for --instance"; fi
      if [[ "$2" != *=* ]]; then
        fail "--instance must be class=value: '$2'"
      fi
      inst_class="${2%%=*}"
      inst_value="${2#*=}"
      if [[ -z "$inst_class" || ! "$inst_class" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        fail "--instance class must be a lowercase slug (^[a-z0-9][a-z0-9-]*\$): '$inst_class'"
      fi
      case "$inst_value" in
        same|distinct) : ;;
        *) fail "--instance value must be same|distinct: '$inst_value'" ;;
      esac
      for inst_i in "${!INST_CLASSES[@]}"; do
        if [[ "${INST_CLASSES[$inst_i]}" == "$inst_class" ]]; then fail "duplicate --instance for '$inst_class'"; fi
      done
      INST_CLASSES+=("$inst_class")
      INST_VALUES+=("$inst_value")
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done
flush_record

if [[ ${#ROUNDS[@]} -eq 0 ]]; then fail "at least one --round/--phase/--class record is required"; fi
if [[ -n "$STOP_REASON" && -n "$TRIGGER" ]]; then fail "--stop-reason and --trigger are mutually exclusive"; fi
if [[ -z "$STOP_REASON" && -z "$TRIGGER" ]]; then fail "exactly one of --stop-reason / --trigger is required"; fi

# --- repetition judgment (first-seen order, deterministic) ------------------
uniq_classes=()
uniq_counts=()
for c in "${CLASSES[@]}"; do
  found=0
  for i in "${!uniq_classes[@]}"; do
    if [[ "${uniq_classes[$i]}" == "$c" ]]; then
      uniq_counts[i]=$(( uniq_counts[i] + 1 ))
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    uniq_classes+=("$c")
    uniq_counts+=(1)
  fi
done

repeated=""
for i in "${!uniq_classes[@]}"; do
  if (( uniq_counts[i] >= 2 )); then
    if [[ -n "$repeated" ]]; then repeated+=", "; fi
    repeated+="${uniq_classes[$i]} (x${uniq_counts[$i]})"
  fi
done

# Early mode (--trigger same-class-2) asserts a precondition — a class
# reached 2 occurrences. Fail closed on the contradiction (all-distinct
# records) rather than emit a self-contradictory digest: this keeps the
# `new-classes-each-round` branch reachable only in STOP mode.
if [[ -n "$TRIGGER" && -z "$repeated" ]]; then
  fail "--trigger same-class-2 requires a repeated class (>=2 occurrences); records show none"
fi

# --- convergence block validation and derivation (T-1145, #491) -------------
# Opt-in seam: the block is REQUESTED only when at least one of the three
# flags below was supplied. Requested-but-partial is a hard refusal (a
# convergence verdict with an incomplete ground is worse than none), and the
# block is STOP-mode only (any of the three with --trigger is refused).
CONV_REQUESTED=0
if [[ -n "$ROUNDS_TOTAL" || ${#ND_NAMES[@]} -gt 0 || ${#INST_CLASSES[@]} -gt 0 ]]; then
  CONV_REQUESTED=1
fi

if [[ "$CONV_REQUESTED" -eq 1 ]]; then
  if [[ -n "$TRIGGER" ]]; then
    fail "convergence inputs (--rounds-total/--never-dropped/--instance) are refused with --trigger same-class-2"
  fi
  if [[ -z "$ROUNDS_TOTAL" ]]; then
    fail "--rounds-total is required when --never-dropped or --instance is supplied"
  fi
  if [[ ${#ND_NAMES[@]} -eq 0 ]]; then
    fail "at least one --never-dropped is required when the convergence block is requested"
  fi

  # --rounds-total must be at least the highest --round in the records.
  max_round=0
  for r in "${ROUNDS[@]}"; do
    if (( 10#$r > max_round )); then max_round=$((10#$r)); fi
  done
  if (( 10#$ROUNDS_TOTAL < max_round )); then
    fail "--rounds-total (${ROUNDS_TOTAL}) must be >= the highest --round in the records (${max_round})"
  fi

  # Every class repeating (>=2 occurrences) must have exactly one --instance;
  # every supplied --instance must name a class that actually repeats.
  for i in "${!uniq_classes[@]}"; do
    if (( uniq_counts[i] >= 2 )); then
      inst_found=0
      for j in "${!INST_CLASSES[@]}"; do
        if [[ "${INST_CLASSES[$j]}" == "${uniq_classes[$i]}" ]]; then inst_found=1; fi
      done
      if [[ "$inst_found" -eq 0 ]]; then
        fail "--instance is required for the repeated class '${uniq_classes[$i]}'"
      fi
    fi
  done
  for j in "${!INST_CLASSES[@]}"; do
    inst_matched=0
    for i in "${!uniq_classes[@]}"; do
      if [[ "${uniq_classes[$i]}" == "${INST_CLASSES[$j]}" && "${uniq_counts[$i]}" -ge 2 ]]; then
        inst_matched=1
      fi
    done
    if [[ "$inst_matched" -eq 0 ]]; then
      fail "--instance names class '${INST_CLASSES[$j]}' which does not repeat in the records"
    fi
  done

  # --- series s[1..N] and trend (DP5) ---
  conv_n="$((10#$ROUNDS_TOTAL))"
  series=()
  for (( conv_r=1; conv_r<=conv_n; conv_r++ )); do
    conv_cnt=0
    for r in "${ROUNDS[@]}"; do
      if (( 10#$r == conv_r )); then conv_cnt=$((conv_cnt + 1)); fi
    done
    series+=("$conv_cnt")
  done
  s_first="${series[0]}"
  s_last="${series[$((conv_n - 1))]}"
  if [[ "$conv_n" -ge 2 ]]; then
    s_prev="${series[$((conv_n - 2))]}"
  else
    s_prev="$s_first"
  fi
  falling_flag=0
  if [[ "$conv_n" -ge 2 ]] && (( s_last < s_first )) && (( s_last <= s_prev )); then
    falling_flag=1
  fi
  rising_flag=0
  if [[ "$conv_n" -ge 2 ]]; then
    if (( s_last > s_first )) || (( s_last > s_prev )); then
      rising_flag=1
    fi
  fi
  trend="flat"
  if [[ "$falling_flag" -eq 1 ]]; then
    trend="falling"
  elif [[ "$rising_flag" -eq 1 ]]; then
    trend="rising"
  fi
  series_str="${series[*]}"

  # --- never-dropped aggregate (DP6/DP8) ---
  has_hit_this=0
  has_hit_earlier=0
  for st in "${ND_STATES[@]}"; do
    case "$st" in
      hit-this-round) has_hit_this=1 ;;
      hit-earlier) has_hit_earlier=1 ;;
    esac
  done
  nd_agg="all-green"
  if [[ "$has_hit_this" -eq 1 ]]; then
    nd_agg="hit-this-round"
  elif [[ "$has_hit_earlier" -eq 1 ]]; then
    nd_agg="cleared-earlier"
  fi
  nd_tail=""
  for j in "${!ND_NAMES[@]}"; do
    nd_tail+=" ${ND_NAMES[$j]}=${ND_STATES[$j]}"
  done

  # --- instances aggregate (DP7), first-seen order matching repeated-classes ---
  repeated_classes_ordered=()
  for i in "${!uniq_classes[@]}"; do
    if (( uniq_counts[i] >= 2 )); then
      repeated_classes_ordered+=("${uniq_classes[$i]}")
    fi
  done
  has_same=0
  inst_agg="none-repeated"
  inst_tail=""
  if [[ ${#repeated_classes_ordered[@]} -gt 0 ]]; then
    inst_agg="all-distinct"
    for cls in "${repeated_classes_ordered[@]}"; do
      for j in "${!INST_CLASSES[@]}"; do
        if [[ "${INST_CLASSES[$j]}" == "$cls" ]]; then
          inst_tail+=" ${cls}=${INST_VALUES[$j]}"
          if [[ "${INST_VALUES[$j]}" == "same" ]]; then has_same=1; fi
        fi
      done
    done
    if [[ "$has_same" -eq 1 ]]; then
      inst_agg="repeated-same"
    fi
  fi

  # --- derivation rule (DP6/DP7) ---
  convergence="not-converging"
  if [[ "$trend" == "falling" && "$has_hit_this" -eq 0 && "$has_same" -eq 0 ]]; then
    convergence="converging"
  fi
  if [[ "$convergence" == "converging" ]]; then
    conv_action="extend — first choice while the trend is falling and every ground is green"
  else
    conv_action="reconsider-design-premise — first choice while the loop is not converging"
  fi
fi

# --- assemble the full digest, then print once (no partial output) ----------
out="=== REWORK-HISTORY DIGEST ==="
if [[ -n "$TRIGGER" ]]; then
  out+=$'\n'"trigger: same-class-2"
else
  out+=$'\n'"stop-reason: ${STOP_REASON}"
  if [[ "$CONV_REQUESTED" -eq 1 ]]; then
    out+=$'\n'"convergence: ${convergence}"
    out+=$'\n'"  trend: ${trend} — findings per round: ${series_str}"
    out+=$'\n'"  never-dropped: ${nd_agg} —${nd_tail}"
    if [[ "$inst_agg" == "none-repeated" ]]; then
      out+=$'\n'"  instances: ${inst_agg}"
    else
      out+=$'\n'"  instances: ${inst_agg} —${inst_tail}"
    fi
    out+=$'\n'"  convergence-action: ${conv_action}"
  fi
fi
out+=$'\n'"rounds:"
for i in "${!ROUNDS[@]}"; do
  out+=$'\n'"  round ${ROUNDS[$i]} phase=${PHASES[$i]} class=${CLASSES[$i]}"
done
if [[ -n "$repeated" ]]; then
  out+=$'\n'"judgment: same-class-repetition"
  out+=$'\n'"repeated-classes: ${repeated}"
  if [[ -n "$TRIGGER" ]]; then
    out+=$'\n'"note: Same-class-2 threshold reached now — escalating before STOP; reconsider the design premise before extending further."
  else
    out+=$'\n'"note: Same-class-2 rule should have fired; consider bulk redesign before extending."
  fi
  out+=$'\n'"recommended-action: reconsider-design-premise (first choice when a class repeats)"
  out+=$'\n'"  (a) route back to pm-spec/ui-designer — reconsider placement and scope"
  out+=$'\n'"  (b) revert the implementation from the repeated rounds (see rounds list above)"
  out+=$'\n'"  (c) continue extending — not the first choice here"
else
  out+=$'\n'"judgment: new-classes-each-round"
  out+=$'\n'"note: distinct root-cause class each round; extending may still converge."
fi
if [[ -n "$REFLECTION" ]]; then
  out+=$'\n'"reflection: ${REFLECTION}"
fi
out+=$'\n'"=== END DIGEST ==="

# --- signature-token self-check (fail-closed, BEFORE any stdout) -------------
# Constructive guarantee of the AC5 invariant: the printed digest, piped into
# goal-state.sh `signature`, must yield NO_VERDICT. The slug charset alone
# cannot guarantee this (hyphen = word boundary for `grep -w`), so re-check
# the fully assembled text with the real consumer and refuse to print a
# digest that would leak verdict-label / AC<digits> tokens.
# Symlink-safe sibling resolution (same pattern as bin/log-run.sh): when this
# script is invoked through a PATH symlink, BASH_SOURCE[0] is the symlink, so
# follow links first or the sibling lookup would miss the real bin/ dir.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
GS="$(cd "$(dirname "$script_path")" && pwd)/goal-state.sh"
if [[ ! -f "$GS" || ! -r "$GS" ]]; then
  fail "sibling goal-state.sh not found — cannot run the signature-token self-check"
fi
sig="$(printf '%s\n' "$out" | bash "$GS" signature)"
if [[ "$sig" != "NO_VERDICT" ]]; then
  fail "digest would leak goal-state signature token(s) '${sig}' — rename the offending class slug or never-dropped component name"
fi

printf '%s\n' "$out"
exit 0
