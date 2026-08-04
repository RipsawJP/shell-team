#!/usr/bin/env bash
# run.sh — regression harness for T-096 (die() / inline exit path errexit-safe
# hardening; GitHub issue #296). See docs/specs/T-096-die-errexit-safe.md.
#
# Under `set -euo pipefail`, a die/fail/inline exit path shaped
#   printf '...' >&2; exit N
# is errexit-UNSAFE: if the caller has closed stderr (a fail-closed gate, CI
# wrapper, or `2>&-` composition), the `printf ... >&2` write itself fails,
# `set -e` fires on THAT failure, and the script exits 1 instead of reaching
# the intended `exit N` — silently breaking the exit-code contract every
# caller (including bin/close-out.sh's own fail-closed gate) depends on. The
# fix form is `printf ... >&2 || true; exit N` (DP-3): the write's own failure
# is swallowed, so the following, independent `exit N` statement always runs.
#
# This suite has FOUR parts, run in order:
#   (i)   counterfactual  — proves the unsafe/safe shapes are actually
#         distinguishable under 2>&- (non-vacuity of everything below).
#   (ii)  per-checker behavioral assertions — fires each apply-checker's
#         die/exit path with stderr closed and asserts the contract exit N.
#         Every site whose contract N != 1 gets a dedicated row. Sites whose
#         contract N == 1 get NO behavioral row here at all (Approach A,
#         T-096 rework2): they are indistinguishable from the errexit-
#         clobbered fallback by exit code alone, so a `2>&-` assertion on
#         them is vacuous by construction — see the note in part (ii). Their
#         regression protection comes entirely from the static layer: AC7's
#         one-liner grep, part (iii)'s completeness self-audit, and part
#         (iv)'s protected-content lock.
#   (iii) completeness self-audit — mechanically re-derives every
#         errexit-unsafe CANDIDATE site left in bin/ (by exact file:line:
#         CONTENT, not file:line alone — a content-blind audit would let a
#         mutation that rewrites an exempted line's TEXT to something unsafe,
#         while keeping its line number, slip through unnoticed), subtracts
#         the documented NOT_APPLY set, and loud-fails if anything new is
#         left unaccounted for. Includes an inline mutation self-check
#         proving the content-aware match actually catches such a rewrite
#         (non-vacuity of the audit itself, same spirit as part (i)).
#   (iv)  protected content locks — a small number of one-liner sites (an
#         `emit()`/`log_err()` helper whose `|| true`-guarded write is
#         followed, on the SAME line, by more code that is neither a literal
#         `exit N` nor end-of-line) are structurally invisible to every
#         static pattern in (iii) — stripping their guard would produce a
#         line matching NONE of P1/P2/P3. These sites are locked here by an
#         exact substring assertion instead, with their own mutation
#         self-check.
#
# Design notes (DP-2): every assertion here uses only `2>&-` redirection,
# in-suite-generated fixture files under a throwaway TMP dir, and early-
# failure invocations — no process substitution — so this suite runs
# unmodified in the sandbox (2026-07-06 lesson) and in CI.
#
# Exit: 0 = every assertion passed. 1 = at least one assertion failed (see
# stderr for which one; this script itself never has a closed-stderr problem
# because it is not being invoked with 2>&- by anything real).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin"

fails=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

# =============================================================================
# Fixture scratch dir — a single throwaway TMP directory for every fixture
# file/tree this suite needs (parts ii-iv), removed in full on exit.
# =============================================================================
if [ -n "${TMPDIR:-}" ]; then
  TMP="${TMPDIR%/}/errexit-safe-fixtures.$$"
else
  TMP="$HERE/tmp-fixtures.$$"
fi
rm -rf "$TMP"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# --- M1 fixture: a READABLE spec with zero AC headings, so check-acs.sh falls
# through past its `[ -r "$SPEC" ]` readability gate and actually reaches the
# ":no acceptance criteria found" multiline die (the site this row targets —
# an unreadable path would die at the readability gate first, one row
# earlier, and never exercise this site at all). ---
cat > "$TMP/check-acs-noac.md" <<'EOF'
# Fixture spec (no AC headings)

This spec intentionally has no `- [ ] **ACn**` lines, to exercise
check-acs.sh's "no acceptance criteria found" die path.
EOF

# NOTE (T-096 rework2, Approach A): the M4 in-suite fixtures that used to
# live here (check-acs FAILED/--dry-run-FAILED, check-intent fail_drift,
# check-provenance fail_schema, check-prompt-sync violations, check-playbook
# violations, gen-playbook-blocks fail(), playbook-promote fail()) have been
# removed along with their now-dead exit-1 behavioral rows in part (ii) below
# — see that part's header comment for why exit-1 behavioral rows are vacuous
# by construction and are no longer carried here at all.

# =============================================================================
# (i) counterfactual — non-vacuity proof.
#
# Builds an UNSAFE shape (`printf x >&2; exit 3`) and the SAFE/fixed shape
# (`printf x >&2 || true; exit 3`) inline, in a throwaway function, run in a
# subshell with stderr closed. N=3 (not 1) is deliberate: it is what proves
# the two shapes are actually distinguishable — if this counterfactual used
# N=1 it could never fail to "look" safe. The unsafe shape must lose its
# `exit 3` to errexit (landing on 1, the closed-write's own failure code);
# the safe shape must reach `exit 3` untouched. If this counterfactual ever
# failed to tell the two apart, every assertion below would be vacuous — so
# this MUST run first and MUST itself be run under `bash` (not the caller's
# login shell; subshell errexit propagation is a bash semantic, not honored
# identically by every shell) for its result to be meaningful.
# =============================================================================
printf '\n--- (i) counterfactual (non-vacuity) ---\n'

# NOTE on `set +e`/`set -e` bracketing (not `||` / `if`): bash suppresses an
# inherited `-e` INSIDE a `(...)` subshell when that subshell is itself the
# tested command of a `||`/`if`/`while` (even though the subshell explicitly
# re-sets `-euo pipefail`) — this is a documented bash errexit quirk, and
# using `||`/`if` here would silently make the "unsafe" probe below come back
# 3 (not errexit-clobbered), defeating the entire counterfactual. Toggling
# `set +e` / `set -e` around a plain, unconditional invocation avoids the
# quirk because the subshell is no longer a *tested* command when it runs.
# (External-process invocations of the checkers themselves, in part (ii)
# below, are NOT subject to this: a forked/exec'd `bash script.sh` has fully
# independent shell state, so `||`-capturing its exit code is safe there.)
set +e
( set -euo pipefail; f() { printf x >&2; exit 3; }; f ) 2>&-
unsafe_rc=$?
set -e
if [ "$unsafe_rc" -eq 1 ]; then
  ok "counterfactual: unsafe shape loses its exit 3 to errexit under closed stderr (got 1)"
else
  bad "counterfactual: unsafe shape expected rc=1 (errexit-clobbered), got $unsafe_rc — the counterfactual itself is not discriminating; every assertion below is suspect"
fi

set +e
( set -euo pipefail; g() { printf x >&2 || true; exit 3; }; g ) 2>&-
safe_rc=$?
set -e
if [ "$safe_rc" -eq 3 ]; then
  ok "counterfactual: safe (|| true guarded) shape reaches its exit 3 under closed stderr (got 3)"
else
  bad "counterfactual: safe shape expected rc=3 (contract honored), got $safe_rc"
fi

if [ "$unsafe_rc" -ne "$safe_rc" ]; then
  ok "counterfactual: unsafe(rc=$unsafe_rc) != safe(rc=$safe_rc) — the assertion methodology can tell safe from unsafe"
else
  bad "counterfactual: unsafe and safe shapes produced the SAME rc ($unsafe_rc) — cannot distinguish; harness would be vacuous"
fi

# =============================================================================
# (ii) per-checker behavioral assertions.
#
# Each row is: script, args (space-separated; empty = none), expected exit N.
# Every invocation is an early-failure path (bad flag / missing required arg /
# unreadable path / a small in-suite fixture) that hits a die()/fail()/
# inline-exit BEFORE any board resolution or other side effect — run with
# stderr closed via 2>&-.
#
# IMPORTANT — why there are NO exit-1 rows below (T-096 rework2, Approach A):
# bash's own errexit fallback, when the `|| true` guard is ABSENT, lands on
# exit 1 (see the counterfactual above). So for any site whose CONTRACT exit
# code is also 1, an exit-code comparison cannot, by itself, tell "fix
# present" apart from "guard silently stripped" — both produce rc=1. A
# `2>&-` behavioral row on such a site would therefore pass whether or not
# the fix is present: it is vacuous by construction, not merely weak. Round1
# and round2 of this task's review both surfaced this same class (a
# strawman/dead exit-1 row that "looked" like coverage but proved nothing),
# so exit-1 sites carry NO behavioral row here by design — their regression
# protection comes entirely from the static layer: AC7's one-liner grep,
# part (iii)'s content-aware completeness self-audit, and part (iv)'s
# protected-content lock (all three inspect the source LINE, not the runtime
# exit code, so they are unaffected by this ambiguity). Every row below has
# contract N != 1 (2, 3, ...) and is therefore NOT subject to this ambiguity:
# errexit's fallback is always 1, so any N != 1 result IS non-vacuous proof
# the fix is present.
# =============================================================================
printf '\n--- (ii) per-checker behavioral assertions (2>&- contract exit) ---\n'

check() {
  # $1 = label, $2 = script (relative to bin/), $3 = expected exit, rest = args
  local name="$1" label="$2 [${*:4}]" script="$BIN/$2" want="$3" got=0
  shift 3
  bash "$script" "$@" 2>&- || got=$?
  if [ "$got" -eq "$want" ]; then
    ok "$name: exit $want honored under closed stderr ($label)"
  else
    bad "$name: expected exit $want, got $got ($label)"
  fi
}

# --- one-liner die() class (AC7's target shape; N=2, non-vacuous) -----------
check close-out-die            close-out.sh            2
check log-run-die              log-run.sh               2
check check-acs-die            check-acs.sh             2
check rollup-track-die         rollup-track.sh          2
check check-board-headings-die check-board-headings.sh  2 --nope
check discover-work-die        discover-work.sh         2 --unknown-flag
check gen-project-status-die   gen-project-status.sh    2 --nope
check check-prompt-sync-die    check-prompt-sync.sh     2 --nope
check review-gate-die          review-gate.sh           2
check consolidate-proposals-die consolidate-proposals.sh 2 --nope
check playbook-promote-die     playbook-promote.sh      2 --nope
check team-paths-die           team-paths.sh            2
check gen-playbook-blocks-die  gen-playbook-blocks.sh   2 --nope
check check-run-oneliner       check-run.sh             2 --line

# --- multiline (`>&2` then next-line `exit N`, or emit()-then-exit) class ----
check check-acs-noac           check-acs.sh             2 "$TMP/check-acs-noac.md"
check check-run-unreadable     check-run.sh             2 /nonexistent/xyz
check check-design-note-usage  check-design-note.sh     2
check goal-state-usage         goal-state.sh            2
check check-intent-usage       check-intent.sh          2
check check-provenance-usage   check-provenance.sh      2
check check-retro-unreadable   check-retro.sh           2 /nonexistent/xyz-errexit.md
check rollup-runs-usage        rollup-runs.sh           2
check rollup-runs-unreadable   rollup-runs.sh           2 /nonexistent/xyz.jsonl
check cluster-failures-usage   cluster-failures.sh      2
check cluster-failures-unreadable cluster-failures.sh    2 /nonexistent/xyz.jsonl
check check-readme-version-usage  check-readme-version.sh 2
check check-readme-version-unreadable check-readme-version.sh 2 /nonexistent/xyz-readme.md
check check-playbook-usage     check-playbook.sh        2
check check-playbook-unreadable check-playbook.sh        2 /nonexistent/xyz-lessons.md
check check-contract-unreadable check-contract.sh        2

# --- accumulator-with-N!=1-contract class (T-110 rework1, Codex round1
# Major; N=2, non-vacuous): check-acs.sh's two unrecognized-AC-label
# diagnostics are accumulator writes (the loop continues right after them,
# no `exit` on the same statement) but their DOWNSTREAM contract exit is 2,
# not 1 — an unguarded write failure here would abort the whole script via
# errexit before the "unrecognized>0 -> exit 2" check ever runs, landing on
# errexit's fallback of 1 instead (a real 2->1 contract break, unlike the
# NOT_APPLY (d) accumulators below whose contract is already 1). Reuses the
# real tests/check-acs/fixtures/ac-unrecognized-label.md fixture (also used
# by tests/check-acs/run.sh) so this is the exact input shape that triggers
# the diagnostics, not a synthetic stand-in.
check check-acs-unrecognized-label check-acs.sh 2 "$REPO_ROOT/tests/check-acs/fixtures/ac-unrecognized-label.md"

# --- indirect (`log_err`-via-`die`) class (N=2, non-vacuous) ----------------
check install-die              install                  2
check team-init-die            team-init.sh             2

# --- conditional-stderr-write + STOP-token contract (loop-guard.sh; N=2) ----
check loop-guard-guard-error    loop-guard.sh            2

# --- heredoc-opener (`cat >&2 <<'EOF'`) + fail()-via-usage() class (N=2) ----
check rework-digest-usage       rework-digest.sh         2

# =============================================================================
# (iii) completeness self-audit (content-aware).
#
# Mechanically re-derives every remaining errexit-unsafe CANDIDATE site in
# bin/ using the three shapes this task fixes:
#   P1  one-liner:       `>&2; exit N` on one line
#   P2  bare-line-ending: a line ending in `>&2` with nothing after it (the
#       shape every multiline die()/fail()/usage()/emit()-then-exit fix in
#       this task removed by appending ` || true`)
#   P3  heredoc-opener:   `>&2 <<...` WITHOUT a trailing `|| true` guard
# then subtracts the documented NOT_APPLY set by exact file:line:CONTENT —
# NOT by file:line alone. Matching on file:line alone would let a mutation
# that rewrites an EXEMPTED line's TEXT to an unsafe form, while leaving its
# line number unchanged, silently continue to "match" the old NOT_APPLY
# record and vanish from the audit — the mutation self-check right below
# proves this concretely. If a NEW file:line:CONTENT combination shows up in
# CANDIDATES but not in NOT_APPLY, this is either a regression (a `|| true`
# guard removed, or an exempted line rewritten to something unsafe) or a
# brand-new checker shipped with the same unsafe shape — either way,
# IN_SCOPE below is non-empty and this suite loud-fails.
# =============================================================================
printf '\n--- (iii) completeness self-audit (content-aware NOT_APPLY subtraction) ---\n'

derive_candidates() {
  # $1 = bin dir to scan. Prints file:line:content candidate lines, sorted.
  local dir="$1"
  {
    # P1: one-liner unsafe (same shape AC7 locks statically).
    grep -rnE '>&2; *exit [0-9]+' "$dir" || true
    # P2: bare-line-ending unsafe (multiline die/fail/usage/emit-then-exit,
    # before the next line's `exit N` — this is what every multiline fix in
    # this task removed by appending ` || true` to the printf/cat line).
    grep -rnE '>&2[[:space:]]*$' "$dir"/*.sh "$dir"/install || true
    # P3: heredoc-opener unsafe (`cat ... >&2 <<TOKEN` without a `|| true`
    # guard on the same line — rework-digest.sh's usage() shape).
    grep -rnE '>&2[[:space:]]*<<' "$dir"/*.sh "$dir"/install | grep -v -- '|| true' || true
  } | sed -E "s|^${dir}/||" | sort -u
}

CAND_FILE="$TMP/candidates.txt"
derive_candidates "$BIN" > "$CAND_FILE"

# NOT_APPLY — every candidate site this task INTENTIONALLY leaves unfixed,
# as the EXACT file:line:content triple a fresh derive_candidates() run
# produces today, with its not-apply reason letter (a)-(e) from the spec's
# "not-apply 判定基準" recorded in the surrounding comment (not in the line
# itself — the line must stay byte-identical to the real source line for the
# content-aware match to work). check-handoff.sh's two candidate lines
# (the "cannot read file" exit-2 path and the emit() write) are (a): each
# sits inside the checker's own frozen, byte-locked observable contract —
# its exit codes, classification strings and message format — which T-1031
# (.shell-team/specs/T-1031-check-handoff-flag-anchor.md, D7/AC11) restates
# and re-freezes rather than hardening. That is a narrower grounds than the
# T-110-era framing this comment used to carry — "check-handoff.sh is the
# single inviolable, byte-unchanged file" — which T-1031 makes false at the
# file level (T-1031 edits a different region of this same file, the
# flag-extraction block, on purpose); only these two specific lines, and the
# frozen contract they encode, stay untouched by any task working on this
# file, T-1031 included. Everything else here is (d): a stderr write that
# CONTINUES (no immediate `exit N` tied to that specific write — an
# accumulator `emit()`/warning/note, decided/exited elsewhere, decoupled
# from this write's own success/failure).
NOT_APPLY_FILE="$TMP/not-apply.txt"
cat > "$NOT_APPLY_FILE" <<'EOF'
check-handoff.sh:27:  printf '%s: cannot read file\n' "$FILE" >&2
check-handoff.sh:79:  printf '%s:%s: %s: %s\n' "$FILE" "$1" "$2" "$3" >&2
check-acs.sh:234:      printf 'check-acs: ignoring invalid CHECK_ACS_TIMEOUT=%s, using 120\n' "$acs_timeout" >&2
check-acs.sh:260:    printf 'AC%s: FAIL (check: sub-bullet is present but its value is empty or whitespace-only — write a real command, or remove the check: line entirely if this AC is runtime-only)\n' "$acnum" >&2
check-acs.sh:294:    printf 'AC%s: FAIL (check: value is wrapped in a single matching backtick pair, which bash would run as command substitution and misevaluate — write a raw command with no wrapping backticks, per the T-044/T-045 convention; see bin/check-acs.sh TRUST BOUNDARY note)\n' "$acnum" >&2
check-contract.sh:37:  printf '%s:%s: %s\n' "$FILE" "$1" "$2" >&2
check-board-headings.sh:319:    printf '%s: note: no resolvable base (first commit and no --base/--base-file/env default) — skipping the deletion/replacement (structural) check; the duplicate check still runs\n' "$BOARD" >&2
check-board-headings.sh:329:  printf '%s: %s: %s\n' "$BOARD" "$1" "$2" >&2
close-out.sh:444:  printf 'close-out: note: project_status generated block not refreshed (file or markers absent) — see gen-project-status.sh\n' >&2
gen-playbook-blocks.sh:468:        "$role" "$line_count" "$LINE_WARN_THRESHOLD" >&2
EOF
sort -u "$NOT_APPLY_FILE" -o "$NOT_APPLY_FILE"

# comm requires both inputs already sorted (which CAND_FILE and NOT_APPLY_FILE
# both are, above) — a real failure here (missing file, permission, a stray
# unsorted line) must FAIL CLOSED, not be swallowed by `|| true` into a
# silently-empty (and therefore falsely "clean") result. `set +e`/`set -e`
# bracketing (not `|| true`, which would overwrite comm's own exit status
# with 0 before `comm_rc=$?` ever sees it, and not a bare `cmd; comm_rc=$?`,
# which under this script's own `set -e` would abort the WHOLE harness on a
# non-zero comm before that assignment ever ran) — comm is a plain external
# command here, not a `(...)` subshell, so this bracketing is unaffected by
# the errexit-suppression quirk documented in part (i)'s NOTE (that quirk is
# specific to bash subshells, not external processes).
IN_SCOPE_FILE="$TMP/in-scope.txt"
COMM_ERR_FILE="$TMP/comm.err"
set +e
comm -23 "$CAND_FILE" "$NOT_APPLY_FILE" > "$IN_SCOPE_FILE" 2>"$COMM_ERR_FILE"
comm_rc=$?
set -e
if [ "$comm_rc" -ne 0 ]; then
  bad "completeness self-audit: \`comm -23\` itself failed (rc=$comm_rc) — the audit cannot be trusted to have run; stderr: $(cat "$COMM_ERR_FILE")"
else
  IN_SCOPE="$(cat "$IN_SCOPE_FILE")"
  if [ -z "$IN_SCOPE" ]; then
    ok "completeness self-audit: every remaining errexit-unsafe candidate is accounted for, by exact content, in NOT_APPLY (check-handoff.sh (a) + 9 (d) accumulator/warning sites; T-110's 2 check-acs.sh unrecognized-label diagnostics are now \`|| true\`-guarded and covered by a dedicated (ii) behavioral row instead of a NOT_APPLY entry — T-110 rework1); zero unfixed, undocumented apply sites"
  else
    bad "completeness self-audit: found errexit-unsafe candidate site(s) NOT in NOT_APPLY, by exact content (regression — a \`|| true\` guard removed, an exempted line rewritten to something unsafe, or a new checker shipped unfixed) — fix with \`|| true\` or add to NOT_APPLY with a (a)-(e) reason:
${IN_SCOPE}"
  fi
fi

# Reverse check: every NOT_APPLY entry must still actually exist, byte-for-
# byte, as a real candidate line (an entry whose line has since been fixed /
# removed / renumbered / reworded would silently stop matching and over-
# subtract nothing useful, but would also mean this list has gone stale and
# may no longer describe the real file — keep it honest).
STALE_ERR_FILE="$TMP/comm-stale.err"
STALE_FILE="$TMP/stale.txt"
set +e
comm -13 "$CAND_FILE" "$NOT_APPLY_FILE" > "$STALE_FILE" 2>"$STALE_ERR_FILE"
stale_comm_rc=$?
set -e
if [ "$stale_comm_rc" -ne 0 ]; then
  bad "completeness self-audit: \`comm -13\` (staleness check) itself failed (rc=$stale_comm_rc); stderr: $(cat "$STALE_ERR_FILE")"
else
  STALE_NOT_APPLY="$(cat "$STALE_FILE")"
  if [ -z "$STALE_NOT_APPLY" ]; then
    ok "completeness self-audit: every NOT_APPLY entry still matches a real candidate line byte-for-byte (no stale/over-subtracting entries)"
  else
    bad "completeness self-audit: NOT_APPLY entry no longer matches any real candidate line byte-for-byte (stale — update the file:line:content or drop the entry):
${STALE_NOT_APPLY}"
  fi
fi

# --- mutation self-check (non-vacuity of the CONTENT-aware match itself) ----
# Proves the fix for the file:line-only blind spot: take a real, currently-
# exempted NOT_APPLY line (close-out.sh:444) and simulate REWRITING its TEXT
# to an unsafe form while KEEPING THE SAME FILE:LINE — entirely in a private
# copy; bin/close-out.sh itself is never touched. A file:line-ONLY audit
# would still "match" this mutated candidate against the old NOT_APPLY record
# (same key) and miss it; the content-aware audit above must NOT.
MUTATED_CAND_FILE="$TMP/mutated-candidates.txt"
sed 's|^close-out\.sh:444:.*$|close-out.sh:444:  printf '"'"'MUTATED: this text simulates an exempted line rewritten unsafe'"'"' >&2; exit 42|' \
  "$CAND_FILE" > "$MUTATED_CAND_FILE"
MUTATION_IN_SCOPE_FILE="$TMP/mutation-in-scope.txt"
comm -23 "$MUTATED_CAND_FILE" "$NOT_APPLY_FILE" > "$MUTATION_IN_SCOPE_FILE" 2>/dev/null || true
if grep -qF 'close-out.sh:444:' "$MUTATION_IN_SCOPE_FILE"; then
  ok "mutation self-check: rewriting the close-out.sh:444 NOT_APPLY line's TEXT (same file:line) to an unsafe form IS caught by the content-aware audit (would NOT have been caught by a file:line-only match)"
else
  bad "mutation self-check: rewriting the close-out.sh:444 NOT_APPLY line's TEXT to an unsafe form was NOT caught — the content-aware audit is not actually content-aware; every completeness result above is suspect"
fi

# =============================================================================
# (iv) protected content locks (regex-invisible guards).
#
# Exactly two known sites have a `|| true`-guarded stderr write where MORE
# CODE follows on the SAME line after the guard, and that code is neither a
# literal `exit N` (P1) nor end-of-line (P2) nor a heredoc opener (P3): if
# stripped, the reverted line would match NONE of P1/P2/P3 and would be
# completely invisible to part (iii)'s static sweep — confirmed empirically
# (grep 'file:line' entries below is the full, exhaustive result of scanning
# every `|| true` site in bin/ for this shape; see the T-096 rework hand-off
# for the derivation):
#   - check-design-note.sh's emit() — followed by `; violations=$((...))`
#   - install / team-init.sh's log_err() — followed by `; }` (end of the
#     one-line function body, not an exit)
# Both are locked here by an exact substring assertion (independent of, and
# in addition to, part (ii)'s exit-code rows for their call sites, which are
# themselves vacuous-if-N=1 for exactly this reason).
# =============================================================================
printf '\n--- (iv) protected content locks (P1/P2/P3-invisible guards) ---\n'

protect() {
  # $1 = label, $2 = file (relative to bin/), $3 = exact guarded substring
  local name="$1" file="$BIN/$2" substr="$3"
  if grep -qF -- "$substr" "$file"; then
    ok "$name: guarded substring present in $2 (regex-invisible, so this content lock is its only static protection)"
  else
    bad "$name: guarded substring MISSING from $2 — the \`|| true\` guard was removed (or the line was rewritten) and no static pattern in part (iii) would have caught it: expected to find: ${substr}"
  fi
}

# shellcheck disable=SC2016  # deliberately literal: this must byte-match the
# real source line's $PATH_ARG / $1 / $* tokens verbatim, not expand them.
check_design_note_emit_guarded='printf '"'"'%s: %s\n'"'"' "$PATH_ARG" "$1" >&2 || true; violations=$((violations + 1))'
# shellcheck disable=SC2016  # same as above — literal $* token, not expanded.
log_err_guarded='printf '"'"'%s\n'"'"' "$*" >&2 || true; }'

protect check-design-note-emit-guard check-design-note.sh "$check_design_note_emit_guarded"
protect install-log-err-guard         install               "$log_err_guarded"
protect team-init-log-err-guard       team-init.sh           "$log_err_guarded"

# --- mutation self-check (non-vacuity of the protected content lock itself) -
# Proves the lock actually discriminates: build the GUARD-STRIPPED text (what
# check-design-note.sh's emit() would look like if `|| true` were removed —
# a synthetic in-memory string, never written to any real file) and confirm
# the SAME `grep -qF` mechanism used above does NOT find the guarded
# substring inside it. If it did, the protected-content-lock mechanism itself
# would be unable to tell guarded from unguarded text.
# shellcheck disable=SC2016  # deliberately literal, same reason as above.
mutated_emit_line='emit() { printf '"'"'%s: %s\n'"'"' "$PATH_ARG" "$1" >&2; violations=$((violations + 1)); }'
if printf '%s\n' "$mutated_emit_line" | grep -qF -- "$check_design_note_emit_guarded"; then
  bad "mutation self-check: the guard-stripped emit() text still matched the guarded substring — the protected content lock cannot discriminate; the check-design-note-emit-guard result above is suspect"
else
  ok "mutation self-check: the guard-stripped emit() text does NOT match the guarded substring — the protected content lock correctly discriminates guarded from unguarded text"
fi

# =============================================================================
# Summary.
# =============================================================================
printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'errexit-safe: all assertions passed\n'
  exit 0
else
  printf 'errexit-safe: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
