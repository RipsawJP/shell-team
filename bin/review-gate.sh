#!/usr/bin/env bash
# bin/review-gate.sh — the DETERMINISTIC FLOOR of the review-response risk gate
# (T-037). Given one review finding's attributes (as evaluated by codex-reviewer),
# decide whether that finding MUST be escalated to a human, or is clear of the
# floor (in which case the SKILL's LLM judgment decides auto vs reject in the
# grey zone).
#
# Why a floor helper and not pure LLM judgment: the dangerous classes of finding
# (a cross-provider disagreement, a high-severity bug, a fix that touches a risk
# surface, or a low-confidence evaluation) must escalate *mechanically* — an
# un-removable safety net that a prompt regression cannot erode. It is also
# transparent: the printed rule name is exactly what a scrum-master retro can
# name when a mis-classification later causes a problem, so the floor can be
# tuned (see tasks/lessons.md), never silently trusted.
#
# The floor fires (=> escalate) when ANY of:
#   1. objection   = yes                 — Codex disputes the reviewer's finding;
#                                          two model families disagree => human tiebreak.
#   2. severity    ∈ {blocker, major}    — a high-severity finding is never auto-adopted.
#   3. risk-area   != none               — the fix touches one of the frozen risk
#                                          surfaces (see the enum below); mirrors the
#                                          xhigh "high cost of being wrong" categories.
#   4. confidence  = low                 — a low-confidence evaluation is not trustworthy
#                                          enough to auto-adopt.
# Otherwise it prints `clear` and the grey-zone (SKILL LLM) owns the auto/reject call.
#
# The risk-area categories are a FROZEN snapshot embedded here (and in
# skills/review-response/SKILL.md), NOT read from any host's private global
# config at run time — the plugin is a generic, host-independent distributable.
# To change the list, edit this enum and the SKILL doc together.
#
# External dependencies: bash + standard POSIX tools only (no jq/yq/python).
# bash 3.2 compatible (macOS), shellcheck clean.
#
# Usage:
#   review-gate.sh --objection <yes|no> --severity <blocker|major|minor|nit> \
#                  --risk-area <CATEGORY|none> --confidence <high|medium|low>
#   review-gate.sh --help
#
# Output (stdout):
#   escalate <rule>[,<rule>...]   — the floor fired; the comma list names each rule
#                                   (objection | high-severity | risk-area:<cat> | low-confidence)
#   clear                         — the floor did not fire; grey zone decides
#
# Exit codes:
#   0  a classification was printed (either `escalate ...` or `clear`)
#   2  argument / usage error

set -euo pipefail

die() { printf 'review-gate: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: review-gate.sh --objection <yes|no> --severity <blocker|major|minor|nit> \
                      --risk-area <CATEGORY|none> --confidence <high|medium|low>

Deterministic floor of the review-response risk gate. Classifies ONE finding.

Options (all required):
  --objection   yes|no                         Codex disputes the reviewer's finding.
  --severity    blocker|major|minor|nit         Finding severity (Codex grouping).
  --risk-area   CATEGORY|none                   Risk surface the fix touches (enum below).
  --confidence  high|medium|low                 Codex's confidence in its evaluation.
  --help, -h                                    Show this help and exit.

risk-area CATEGORY enum (any value other than `none` forces escalate):
  architecture       architecture / technical-selection decisions
  security           auth/authz, certs/CA, IAM policy, secrets, security-review
  prod               operations touching the production environment
  db-migration       DB schema design / migrations
  irreversible       irreversible / destructive operations
  numeric-accuracy   logic where numeric correctness matters (money, aggregation)
  external-docs      outward-facing docs / compliance
  rca                root-cause analysis of a complex bug

Output:  `escalate <rule>[,<rule>...]`  or  `clear`  (stdout)
Exit:    0 = classified, 2 = usage error.
EOF
}

OBJECTION=""
SEVERITY=""
RISK_AREA=""
CONFIDENCE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)    print_help; exit 0 ;;
    --objection)  [ "$#" -ge 2 ] || die "--objection requires a value"; shift; OBJECTION="$1"; shift ;;
    --severity)   [ "$#" -ge 2 ] || die "--severity requires a value"; shift; SEVERITY="$1"; shift ;;
    --risk-area)  [ "$#" -ge 2 ] || die "--risk-area requires a value"; shift; RISK_AREA="$1"; shift ;;
    --confidence) [ "$#" -ge 2 ] || die "--confidence requires a value"; shift; CONFIDENCE="$1"; shift ;;
    --*)          die "unknown flag: $1" ;;
    *)            die "unexpected argument: $1" ;;
  esac
done

# All four attributes are required — the caller (SKILL) always has them from the
# Codex evaluation, and defaulting a missing one would silently weaken the floor.
[ -n "$OBJECTION" ]  || die "missing --objection <yes|no> (see --help)"
[ -n "$SEVERITY" ]   || die "missing --severity <blocker|major|minor|nit> (see --help)"
[ -n "$RISK_AREA" ]  || die "missing --risk-area <CATEGORY|none> (see --help)"
[ -n "$CONFIDENCE" ] || die "missing --confidence <high|medium|low> (see --help)"

# Validate enums up front so a typo is a hard error, never a silent mis-classify.
case "$OBJECTION" in
  yes|no) ;;
  *) die "--objection must be yes|no, got: '$OBJECTION'" ;;
esac
case "$SEVERITY" in
  blocker|major|minor|nit) ;;
  *) die "--severity must be blocker|major|minor|nit, got: '$SEVERITY'" ;;
esac
case "$RISK_AREA" in
  none|architecture|security|prod|db-migration|irreversible|numeric-accuracy|external-docs|rca) ;;
  *) die "--risk-area must be a known category or none, got: '$RISK_AREA' (see --help)" ;;
esac
case "$CONFIDENCE" in
  high|medium|low) ;;
  *) die "--confidence must be high|medium|low, got: '$CONFIDENCE'" ;;
esac

# ---------------------------------------------------------------------------
# Apply the floor rules. Collect every rule that fires so the run record can
# name all of them (not just the first) — a finding can trip several at once.
# ---------------------------------------------------------------------------
rules=""
add_rule() { rules="${rules:+$rules,}$1"; }

[ "$OBJECTION" = "yes" ] && add_rule "objection"
case "$SEVERITY" in blocker|major) add_rule "high-severity" ;; esac
[ "$RISK_AREA" != "none" ] && add_rule "risk-area:$RISK_AREA"
[ "$CONFIDENCE" = "low" ] && add_rule "low-confidence"

if [ -n "$rules" ]; then
  printf 'escalate %s\n' "$rules"
else
  printf 'clear\n'
fi
exit 0
