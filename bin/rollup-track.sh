#!/usr/bin/env bash
# rollup-track.sh — track bin/rollup-runs.sh's per-run summary as a dated,
# git-trackable artifact (T-042 outer-loop wiring).
#
# rollup-runs.sh (T-020) only ever prints its summary to stdout — every host
# throws it away once the terminal scrolls. This is a THIN WRAPPER (same
# pattern as consolidate-proposals.sh wrapping discover-work.sh +
# rollup-runs.sh): it shells out to the unmodified rollup-runs.sh and captures
# its stdout into ONE dated file under `<base>/rollups/`, so the roll-up
# accumulates as tracked history instead of evaporating. rollup-runs.sh itself
# is left byte-unchanged — zero regression risk to its own already-tested
# behavior/consumers.
#
# `<base>` is resolved via the EXISTING `team-paths.sh --get base` (not a new
# team-paths.sh key — see docs/specs/T-042-outer-loop-wiring.md, Design
# decision 4). Same never-overwrite numeric-suffix collision rule as
# consolidate-proposals.sh's `triage-rollup-<date>.md`.
#
# rollup-runs.sh's output shape is fixed-field only (run_id / loop_id / span
# counts / phase names / status+verdict tallies / token+duration sums / an
# ISO-8601 window / a health flag) — no free-text/prose fields — so the
# tracked artifact is PII-free by construction. Because this artifact is
# git-tracked (not ephemeral stdout), a write-time content guard additionally
# refuses to persist if the summary somehow carries PII or a common
# secret-shaped token (via the unconstrained run_id/phase fields): an
# email-like token, a Unix- or Windows-style home-dir path, or a well-known
# secret prefix (GitHub/AWS/OpenAI-style). It fails loudly so the leak is
# fixed at source (see T-024) rather than committed forever (T-043 widened
# the original T-042 email+Unix-path guard to also cover Windows paths and
# secret shapes — #108).
#
# If there is nothing to summarize (rollup-runs.sh prints exactly
# `(no runs found)`), no file is written (no needless empty artifacts) and
# this still exits 0.
#
# External dependencies: bash + coreutils only, matching rollup-runs.sh /
# consolidate-proposals.sh.
#
# Usage:
#   rollup-track.sh <run.jsonl> [<run.jsonl>...] [--out-dir DIR] [--date YYYY-MM-DD]
#   rollup-track.sh --help
#
# When a file was written, its path is printed to stdout. When there was
# nothing to summarize, nothing is printed.
#
# Exit codes:
#   0  success (including the "nothing to summarize" no-op path)
#   2  argument / usage error, the underlying rollup-runs.sh call failed, or
#      the summary was refused for PII-like or secret-shaped content (no file
#      written)
set -euo pipefail

# Resolve this script's own dir (symlink-safe) so the sibling rollup-runs.sh /
# team-paths.sh are reachable regardless of cwd / how we were invoked.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
ROLLUP_RUNS="$SCRIPT_DIR/rollup-runs.sh"

die() { printf 'rollup-track: %s\n' "$*" >&2 || true; exit 2; }

print_help() {
  cat <<'EOF'
Usage: rollup-track.sh <run.jsonl> [<run.jsonl>...] [--out-dir DIR] [--date YYYY-MM-DD]

Capture bin/rollup-runs.sh's per-run summary as a dated, git-trackable file
under <base>/rollups/ (never-overwrite; numeric suffix on same-day collision).
rollup-runs.sh itself is invoked unmodified; this script only wraps it.

Options:
  --out-dir DIR     Directory for the rollup file (default: <base>/rollups,
                    <base> resolved from cwd by team-paths.sh --get base).
  --date YYYY-MM-DD Date stamp for the filename (default: today, local date).
  --help, -h        Show this help and exit.

If rollup-runs.sh has nothing to summarize ("(no runs found)"), no file is
written and this still exits 0.
EOF
}

OUT_DIR=""
DATE=""
FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --out-dir) [ "$#" -ge 2 ] || die "--out-dir requires a value"; shift; OUT_DIR="$1"; shift ;;
    --date)    [ "$#" -ge 2 ] || die "--date requires a value";    shift; DATE="$1";    shift ;;
    --*)       die "unknown flag: $1" ;;
    *)         FILES+=("$1"); shift ;;
  esac
done

[ "${#FILES[@]}" -ge 1 ] || die "at least one <run.jsonl> argument is required (see --help)"

# Resolve the output dir AFTER arg-parse / --help so team-paths.sh isn't
# invoked on a help or error path. Precedence: explicit --out-dir > a locally
# computed "<base>/rollups", <base> from the EXISTING team-paths.sh --get base
# (never a new team-paths.sh key). Resolver-failure fallback mirrors the other
# bin/ wrappers: default layout, never a legacy path.
if [ -z "$OUT_DIR" ]; then
  team_base="$(bash "$SCRIPT_DIR/team-paths.sh" --get base 2>/dev/null || printf '.shell-team')"
  OUT_DIR="$team_base/rollups"
fi

# Date stamp. --date wins (test determinism); else today's local date.
# Validated so a bad value can't smuggle path separators into the filename.
[ -n "$DATE" ] || DATE="$(date +%F)"
case "$DATE" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
  *) die "--date must be YYYY-MM-DD (got: $DATE)" ;;
esac

SUMMARY="$(bash "$ROLLUP_RUNS" "${FILES[@]}")" || die "rollup-runs.sh failed"

# Nothing to track: rollup-runs.sh's exact no-input sentinel. No file, no
# empty artifact, still exit 0.
[ "$SUMMARY" != "(no runs found)" ] || exit 0

# PII + secret-shape content guard (T-042 codex round1 blocker; widened by
# T-043 / #108 per T-042 codex round2). Unlike rollup-runs.sh's ephemeral
# stdout, THIS output becomes a permanently git-tracked artifact, so
# "PII-free by construction" (fixed-field shape) is not enough on its own: the
# upstream run_id / phase fields are shape-checked by check-run.sh but NOT
# charset-constrained by log-run.sh, so a stray email, home path, or
# secret-shaped token could ride into the summary and get committed forever.
# Refuse to persist (write NO file) if the summary carries any of:
#   - an email-like token
#   - a Unix-style home-dir path (/Users/ or /home/)
#   - a Windows-style home-dir path (\Users\ or \home\)   [T-043]
#   - a common secret-shaped token: GitHub (ghp_/gho_/ghs_/ghr_), AWS access
#     key id (AKIA), OpenAI-style key (sk-)                [T-043]
# and fail loudly so the leak is fixed at the source (the run log's run_id /
# phase fields) rather than buried (T-024 PII-scrub discipline). This is a
# fixed, small set of well-known secret prefixes — deliberately NOT a general
# high-entropy scanner (see docs/specs/T-043-rollup-guard-hardening.md).
# Each secret prefix is anchored to a MINIMUM key-body length so a short,
# legitimate lookalike is not refused — e.g. this project's own `task-043`
# task-ID convention contains the literal substring `sk-`, so a bare `sk-`
# substring match would wrongly refuse it (T-043 codex round1 blocker: AC3
# "no new false positive"). Real tokens are far longer than any such label.
if printf '%s' "$SUMMARY" | grep -Eq '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+|/Users/|/home/|\\Users\\|\\home\\|gh[oprs]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{12,}|sk-[A-Za-z0-9_-]{16,}'; then
  die "refusing to write rollups artifact: summary contains PII-like or secret-shaped content (email address, home-dir path, or a common secret token in the run_id/phase fields). Scrub the source run log before tracking (see T-024)."
fi

# Never-overwrite numeric-suffix collision rule (mirrors
# consolidate-proposals.sh's triage-rollup-<date>.md convention).
mkdir -p "$OUT_DIR"
base_file="$OUT_DIR/${DATE}.md"
out="$base_file"
n=2
# -L as well as -e: a DANGLING symlink is invisible to -e, but `{ ... } > "$out"`
# would follow it and write outside OUT_DIR. Treat any occupant — file, dir, or
# symlink of either kind — as a collision and advance to the next suffix.
while [ -e "$out" ] || [ -L "$out" ]; do
  out="${OUT_DIR}/${DATE}-${n}.md"
  n=$((n + 1))
done

{
  printf '# Roll-up — %s\n\n' "$DATE"
  printf 'Tracked snapshot of the per-run summary produced by bin/rollup-runs.sh\n'
  printf '(T-020), captured by bin/rollup-track.sh (T-042). Fixed-field output\n'
  printf 'only (run_id / loop_id / span counts / phase names / status+verdict\n'
  printf 'tallies / token+duration sums / an ISO-8601 window / a health flag) —\n'
  printf 'no free-text/prose fields, so this artifact is PII-free by construction.\n\n'
  printf '```\n'
  printf '%s\n' "$SUMMARY"
  printf '```\n'
} > "$out"

printf '%s\n' "$out"
exit 0
