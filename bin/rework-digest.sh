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

usage() {
  cat >&2 <<'EOF' || true
usage: rework-digest.sh --round N --phase validate|review --class <slug> \
                        [--round N --phase ... --class ...]... \
                        (--stop-reason <reason> | --trigger same-class-2)

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

# --- assemble the full digest, then print once (no partial output) ----------
out="=== REWORK-HISTORY DIGEST ==="
if [[ -n "$TRIGGER" ]]; then
  out+=$'\n'"trigger: same-class-2"
else
  out+=$'\n'"stop-reason: ${STOP_REASON}"
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
  fail "digest would leak goal-state signature token(s) '${sig}' — rename the offending class slug"
fi

printf '%s\n' "$out"
exit 0
