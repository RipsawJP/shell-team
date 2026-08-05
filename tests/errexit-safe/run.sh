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
#         errexit-unsafe CANDIDATE site left in bin/, keyed by exact
#         <file>:<content> WITH AN EXPLICIT DECLARED OCCURRENCE COUNT, never
#         by position — a count-blind (deduplicated) key would let a second
#         byte-identical unguarded line in an already-registered file
#         collapse into its existing key and slip through unnoticed;
#         subtracts the documented NOT_APPLY set by that counted key, and
#         loud-fails if any candidate's measured count is unaccounted for or
#         out of sync with its declaration. Includes an inline mutation
#         self-check proving the counted match actually catches both a
#         content rewrite and a duplicated line (non-vacuity of the audit
#         itself, same spirit as part (i)).
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
# (iii) completeness self-audit (position-free, multiplicity-aware content
# keys).
#
# Mechanically re-derives every remaining errexit-unsafe CANDIDATE site in
# bin/ using the three shapes this task fixes:
#   P1  one-liner:       `>&2; exit N` on one line
#   P2  bare-line-ending: a line ending in `>&2` with nothing after it (the
#       shape every multiline die()/fail()/usage()/emit()-then-exit fix in
#       this task removed by appending ` || true`)
#   P3  heredoc-opener:   `>&2 <<...` WITHOUT a trailing `|| true` guard
# then subtracts the documented NOT_APPLY set — keyed on <file>:<content>
# with an explicit DECLARED occurrence count, never a line number. The raw
# derivation (derive_candidates, below) keeps `grep -n`'s line numbers
# THROUGH its own `sort -u`; the line field is stripped only afterwards, by
# counted_keys, when the counted key is formed. Two byte-identical candidate
# lines in one file differ only in their line numbers, so dropping that
# field before sort -u would collapse them at the source with no way for any
# downstream count to recover them.
#
# One mechanism produces both judgments: `comm -23` (forward/completeness)
# surfaces a measured candidate key the registry does not account for at
# all, or whose measured count no longer equals its declared count; `comm
# -13` (reverse/staleness) surfaces a registered key whose measured count in
# bin/ no longer equals its declared count, including a fall to zero (fixed,
# removed, or reworded). A count that merely moves surfaces on BOTH sides at
# once — informative, not redundant — and that is exactly what lets a second
# byte-identical unguarded line added to an already-registered file fail
# loudly instead of being silently absorbed by a deduplicated set
# difference (the mutation self-check below reproduces this live). Position
# never enters the judgment: moving a registered line within its own file no
# longer, by itself, fires the reverse check — see "the two honest losses"
# in this task's spec for why that is the correct behaviour, not a
# regression.
# =============================================================================
printf '\n--- (iii) completeness self-audit (position-free, multiplicity-aware content keys) ---\n'

derive_candidates() {
  # $1 = bin dir to scan. Prints raw <file>:<line-number>:<content>
  # candidate lines, sorted. The line-number field passes THROUGH this
  # sort -u untouched (the load-bearing derivation constraint) — it is
  # stripped only by counted_keys, below, after this function has already
  # de-duplicated exact <file>:<line-number>:<content> repeats. Two byte-
  # identical CONTENT lines at two different line numbers survive this
  # function as two distinct rows.
  local dir="$1"
  {
    # P1: one-liner unsafe (same shape part (ii)'s die()/fail() rows exercise).
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

counted_keys() {
  # $1 = a <file>:<line-number>:<content> stream (derive_candidates' output
  # shape). Strips the line-number field NOW — after derive_candidates' own
  # sort -u, never before — counts occurrences per resulting <file>:<content>
  # key, and
  # prints `<count> <file>:<content>`, one per key, sorted. This is the ONLY
  # place the line field is dropped; the count it leaves behind is what
  # lets a byte-identical duplicate be told apart from a plain rename.
  sed -E 's|^([^:]+):[0-9]+:|\1:|' "$1" | sort | awk '{c[$0]++} END{for (k in c) printf "%d %s\n", c[k], k}' | sort
}

CAND_FILE="$TMP/candidates.txt"
derive_candidates "$BIN" > "$CAND_FILE"
MEASURED_FILE="$TMP/measured.txt"
counted_keys "$CAND_FILE" > "$MEASURED_FILE"

# NOT_APPLY — every candidate site this task INTENTIONALLY leaves unfixed,
# keyed as `<count> <file>:<content>`: an unpadded decimal DECLARED
# occurrence count, one space, the bin/-relative file, a colon, and the
# source line byte for byte (leading whitespace included) — never a line
# number. Every record below was produced by running derive_candidates() and
# counted_keys() against the real bin/ and pasting the output as-is; not one
# entry was hand-typed or hand-edited afterwards — a transcription is
# exactly what would silently mangle gen-playbook-blocks.sh's eight-space
# continuation record below. The not-apply reason letter (a)-(e) from the
# spec's "not-apply 判定基準" is recorded in the surrounding comment, not in
# the record itself — the record must stay byte-identical to the real
# source line for the declared count to mean what it says. check-handoff.sh's
# two candidate lines (the "cannot read file" exit-2 path and the emit()
# write) are (a): each sits inside the checker's own frozen, byte-locked
# observable contract — its exit codes, classification strings and message
# format — which T-1031 (.shell-team/specs/T-1031-check-handoff-flag-anchor.md,
# D7/AC11) restates and re-freezes rather than hardening. That is a narrower
# grounds than the T-110-era framing this comment used to carry — "check-
# handoff.sh is the single inviolable, byte-unchanged file" — which T-1031
# makes false at the file level (T-1031 edits a different region of this
# same file, the flag-extraction block, on purpose); only these two specific
# lines, and the frozen contract they encode, stay untouched by any task
# working on this file, T-1031 included. Everything else here is (d): a
# stderr write that CONTINUES (no immediate `exit N` tied to that specific
# write — an accumulator `emit()`/warning/note, decided/exited elsewhere,
# decoupled from this write's own success/failure).
NOT_APPLY_FILE="$TMP/not-apply.txt"
cat > "$NOT_APPLY_FILE" <<'EOF'
1 check-acs.sh:      printf 'check-acs: ignoring invalid CHECK_ACS_TIMEOUT=%s, using 120\n' "$acs_timeout" >&2
1 check-acs.sh:    printf 'AC%s: FAIL (check: sub-bullet is present but its value is empty or whitespace-only — write a real command, or remove the check: line entirely if this AC is runtime-only)\n' "$acnum" >&2
1 check-acs.sh:    printf 'AC%s: FAIL (check: value is wrapped in a single matching backtick pair, which bash would run as command substitution and misevaluate — write a raw command with no wrapping backticks, per the T-044/T-045 convention; see bin/check-acs.sh TRUST BOUNDARY note)\n' "$acnum" >&2
1 check-board-headings.sh:    printf '%s: note: no resolvable base (first commit and no --base/--base-file/env default) — skipping the deletion/replacement (structural) check; the duplicate check still runs\n' "$BOARD" >&2
1 check-board-headings.sh:  printf '%s: %s: %s\n' "$BOARD" "$1" "$2" >&2
1 check-contract.sh:  printf '%s:%s: %s\n' "$FILE" "$1" "$2" >&2
1 check-handoff.sh:  printf '%s: cannot read file\n' "$FILE" >&2
1 check-handoff.sh:  printf '%s:%s: %s: %s\n' "$FILE" "$1" "$2" "$3" >&2
1 close-out.sh:  printf 'close-out: note: project_status generated block not refreshed (file or markers absent) — see gen-project-status.sh\n' >&2
1 gen-playbook-blocks.sh:        "$role" "$line_count" "$LINE_WARN_THRESHOLD" >&2
EOF
sort -u "$NOT_APPLY_FILE" -o "$NOT_APPLY_FILE"

# A separate snapshot of the registry, used only as the STDIN source for
# the mutation-self-check loops below — a distinct path from $NOT_APPLY_FILE
# (which those loops also read via `comm`) purely so a static scanner cannot
# mistake the two independent reads of the same content for a read/write
# conflict; nothing here writes to either path.
NOT_APPLY_ITER_FILE="$TMP/not-apply-iter.txt"
cp "$NOT_APPLY_FILE" "$NOT_APPLY_ITER_FILE"

# Both comm inputs are sorted in the same process, under the same collation
# (MEASURED_FILE by counted_keys' own `sort`, NOT_APPLY_FILE by the `sort -u`
# immediately above) — comm's sortedness precondition holds by construction
# and no cross-host sort comparison ever occurs. A real failure here
# (missing file, permission, a stray unsorted line) must FAIL CLOSED, not be
# swallowed by `|| true` into a silently-empty (and therefore falsely
# "clean") result. `set +e`/`set -e` bracketing (not `|| true`, which would
# overwrite comm's own exit status with 0 before `comm_rc=$?` ever sees it,
# and not a bare `cmd; comm_rc=$?`, which under this script's own `set -e`
# would abort the WHOLE harness on a non-zero comm before that assignment
# ever ran) — comm is a plain external command here, not a `(...)` subshell,
# so this bracketing is unaffected by the errexit-suppression quirk
# documented in part (i)'s NOTE (that quirk is specific to bash subshells,
# not external processes).
IN_SCOPE_FILE="$TMP/in-scope.txt"
COMM_ERR_FILE="$TMP/comm.err"
set +e
comm -23 "$MEASURED_FILE" "$NOT_APPLY_FILE" > "$IN_SCOPE_FILE" 2>"$COMM_ERR_FILE"
comm_rc=$?
set -e
if [ "$comm_rc" -ne 0 ]; then
  bad "completeness self-audit: \`comm -23\` itself failed (rc=$comm_rc) — the audit cannot be trusted to have run; stderr: $(cat "$COMM_ERR_FILE")"
else
  IN_SCOPE="$(cat "$IN_SCOPE_FILE")"
  if [ -z "$IN_SCOPE" ]; then
    ok "completeness self-audit: every remaining errexit-unsafe candidate's measured occurrence count is accounted for in NOT_APPLY, by exact content key and declared count (check-handoff.sh (a) + 9 (d) accumulator/warning sites; T-110's 2 check-acs.sh unrecognized-label diagnostics are now \`|| true\`-guarded and covered by a dedicated (ii) behavioral row instead of a NOT_APPLY entry — T-110 rework1); zero unfixed, undocumented apply sites"
  else
    bad "completeness self-audit: found an unregistered content key, or a registered key whose measured occurrence count no longer equals its declared count (regression — a \`|| true\` guard removed, an exempted line rewritten to something unsafe, a second byte-identical unguarded line added, or a new checker shipped unfixed) — fix with \`|| true\` or add/update NOT_APPLY with a (a)-(e) reason:
${IN_SCOPE}"
  fi
fi

# Reverse check: every NOT_APPLY entry's DECLARED count must still equal its
# MEASURED count in bin/ today, including a fall to zero (an entry whose
# line has since been fixed, removed, or reworded would silently stop
# contributing to its old key's count — over-subtracting nothing useful —
# but would also mean this registry has gone stale and may no longer
# describe the real file; keep it honest). Renumbering ALONE no longer fires
# this check, by design (see "the two honest losses" in this task's spec):
# position was never the reviewed property, only the file and the text were.
STALE_ERR_FILE="$TMP/comm-stale.err"
STALE_FILE="$TMP/stale.txt"
set +e
comm -13 "$MEASURED_FILE" "$NOT_APPLY_FILE" > "$STALE_FILE" 2>"$STALE_ERR_FILE"
stale_comm_rc=$?
set -e
if [ "$stale_comm_rc" -ne 0 ]; then
  bad "completeness self-audit: \`comm -13\` (staleness check) itself failed (rc=$stale_comm_rc); stderr: $(cat "$STALE_ERR_FILE")"
else
  STALE_NOT_APPLY="$(cat "$STALE_FILE")"
  if [ -z "$STALE_NOT_APPLY" ]; then
    ok "completeness self-audit: every NOT_APPLY entry's declared occurrence count still matches its measured count in bin/ (no stale/moved/renumbered-away entries)"
  else
    bad "completeness self-audit: a registered content key's measured occurrence count in its file no longer equals its declared count (including 0) — update the declared count/content or drop the entry:
${STALE_NOT_APPLY}"
  fi
fi

# --- mutation self-check (D3): three directions, over every registered
# record, against private copies of bin/ only — there is no chosen probe
# target: every probe iterates the registry's own records at run time, which
# removes both the selection question and the last reason to name a site
# literally (AC7's one-canonical-definition lock is what makes a re-
# hardcoded site structurally impossible in the first place). ------------
BIN_TEMPLATE="$TMP/bin-template"
cp -R "$BIN" "$BIN_TEMPLATE"

# A pristine, pre-mutation derivation of the REAL bin/, taken before any
# probe runs, so the hygiene invariant below can prove the real bin/ never
# moved — a final-state cmp, never a restore that merely "reported success".
PRE_MUTATION_FILE="$TMP/pre-mutation.txt"
derive_candidates "$BIN" > "$PRE_MUTATION_FILE"

# (i) content rewrite: for every registered record, in its own private copy
# of bin/, locate its content line by EXACT WHOLE-LINE comparison in awk
# ($0 == old) — never a regex/sed substitution, since the contents carry
# '.', '*', '[', '$', '%' and quote characters a regex would misparse —
# assert the match count equals the RECORD'S OWN DECLARED count before
# rewriting (never a hard-coded 1: a declared count of 2 — two byte-
# identical, individually-reviewed exempt sites collapsed to one key — is a
# legitimate, spec-anticipated registry state, not a synthetic extreme; see
# this task's spec, "Loss 2" / Input-space "Reachable input classes"), rewrite
# every matching line to an unsafe P1-shaped form (the awk program below
# already rewrites ALL lines equal to the old text, not just the first),
# and assert the match count is exactly 0 after. The re-derived counted set
# must then differ from the registry in BOTH directions: forward, because
# the rewritten text is an unregistered key; reverse, because the
# registered key's measured count fell to zero.
content_rewrite_fails=0
content_rewrite_checked=0
while IFS= read -r rec; do
  [ -n "$rec" ] || continue
  n_decl=${rec%% *}
  key=${rec#* }
  rw_file=${key%%:*}
  rw_content=${key#*:}
  content_rewrite_checked=$((content_rewrite_checked + 1))
  probe_dir=$(mktemp -d "$TMP/rewrite.XXXXXX") || { content_rewrite_fails=$((content_rewrite_fails + 1)); continue; }
  cp -R "$BIN_TEMPLATE"/. "$probe_dir"/
  target="$probe_dir/$rw_file"
  if [ ! -f "$target" ]; then
    content_rewrite_fails=$((content_rewrite_fails + 1))
    rm -rf "$probe_dir"
    continue
  fi
  before_n=$(rw_old="$rw_content" awk 'BEGIN{o=ENVIRON["rw_old"]} $0==o{n++} END{print n+0}' "$target")
  if [ "$before_n" != "$n_decl" ]; then
    content_rewrite_fails=$((content_rewrite_fails + 1))
    rm -rf "$probe_dir"
    continue
  fi
  rw_old="$rw_content" awk 'BEGIN{o=ENVIRON["rw_old"]; p="  printf \"T1038 REWRITE PROBE\" >&2; exit 42"} $0==o{print p; next} {print}' "$target" > "$probe_dir/.rewritten.tmp" && mv "$probe_dir/.rewritten.tmp" "$target"
  after_n=$(rw_old="$rw_content" awk 'BEGIN{o=ENVIRON["rw_old"]} $0==o{n++} END{print n+0}' "$target")
  if [ "$after_n" != "0" ]; then
    content_rewrite_fails=$((content_rewrite_fails + 1))
    rm -rf "$probe_dir"
    continue
  fi
  derive_candidates "$probe_dir" > "$TMP/rewrite-cand.txt"
  counted_keys "$TMP/rewrite-cand.txt" > "$TMP/rewrite-measured.txt"
  fwd_n=$(comm -23 "$TMP/rewrite-measured.txt" "$NOT_APPLY_FILE" | grep -c . || true)
  rev_n=$(comm -13 "$TMP/rewrite-measured.txt" "$NOT_APPLY_FILE" | grep -c . || true)
  if [ "$fwd_n" -lt 1 ] || [ "$rev_n" -lt 1 ]; then
    content_rewrite_fails=$((content_rewrite_fails + 1))
  fi
  rm -rf "$probe_dir"
done < "$NOT_APPLY_ITER_FILE"
if [ "$content_rewrite_checked" -ge 1 ] && [ "$content_rewrite_fails" -eq 0 ]; then
  ok "content-rewrite self-check: rewriting a registered line's text to an unsafe form is caught in BOTH directions — forward as an unregistered key, reverse as a count mismatch"
else
  bad "content-rewrite self-check: $content_rewrite_fails of $content_rewrite_checked registered record(s) failed to be caught in BOTH directions when rewritten unsafe — the mechanism has collapsed to a one-way (or non-) check"
fi

# (ii) duplicate site: for every registered record, append a BYTE-IDENTICAL
# duplicate of its content line to the same file in a private copy of bin/,
# then re-run the WHOLE derivation from that copy — the mutation is applied
# to the candidate-derivation INPUT, not to an already-counted output, so
# this exercises the real derivation including its own sort -u. This is the
# non-vacuity proof for the rejected deduplicated-set-difference
# alternative: that design would show no difference at all here, and only
# here.
duplicate_fails=0
duplicate_checked=0
while IFS= read -r rec; do
  [ -n "$rec" ] || continue
  key=${rec#* }
  dup_file=${key%%:*}
  dup_content=${key#*:}
  duplicate_checked=$((duplicate_checked + 1))
  probe_dir=$(mktemp -d "$TMP/dup.XXXXXX") || { duplicate_fails=$((duplicate_fails + 1)); continue; }
  cp -R "$BIN_TEMPLATE"/. "$probe_dir"/
  target="$probe_dir/$dup_file"
  if [ ! -f "$target" ]; then
    duplicate_fails=$((duplicate_fails + 1))
    rm -rf "$probe_dir"
    continue
  fi
  printf '%s\n' "$dup_content" >> "$target"
  derive_candidates "$probe_dir" > "$TMP/dup-cand.txt"
  counted_keys "$TMP/dup-cand.txt" > "$TMP/dup-measured.txt"
  fwd_n=$(comm -23 "$TMP/dup-measured.txt" "$NOT_APPLY_FILE" | grep -c . || true)
  rev_n=$(comm -13 "$TMP/dup-measured.txt" "$NOT_APPLY_FILE" | grep -c . || true)
  if [ "$fwd_n" -lt 1 ] || [ "$rev_n" -lt 1 ]; then
    duplicate_fails=$((duplicate_fails + 1))
  fi
  rm -rf "$probe_dir"
done < "$NOT_APPLY_ITER_FILE"
if [ "$duplicate_checked" -ge 1 ] && [ "$duplicate_fails" -eq 0 ]; then
  ok "duplicate-site self-check: a second byte-identical unguarded line in the same file changes the measured occurrence count and IS caught — the dedup blind spot is closed"
else
  bad "duplicate-site self-check: $duplicate_fails of $duplicate_checked registered record(s) failed to change the measured occurrence count when duplicated — a deduplicating set difference would have absorbed this silently"
fi

# (iii) probe hygiene, as an invariant rather than a restore: every probe
# above wrote only inside private copies under $TMP; the real bin/ was
# never opened for writing. Proved by re-deriving from the REAL bin/ now
# and requiring it byte-identical to the derivation taken before any probe
# ran — final-state identity, not "the restore reported success".
POST_MUTATION_FILE="$TMP/post-mutation.txt"
derive_candidates "$BIN" > "$POST_MUTATION_FILE"
if cmp -s "$PRE_MUTATION_FILE" "$POST_MUTATION_FILE"; then
  ok "probe hygiene: every probe ran against a private copy of bin/, and a fresh derivation from the real bin/ is byte-identical to the one taken before the probes"
else
  bad "probe hygiene: the real bin/ derivation changed across the mutation self-check — a probe wrote outside its scratch copy"
fi

# =============================================================================
# (iv) protected content locks (regex-invisible guards).
#
# Exactly two known sites have a `|| true`-guarded stderr write where MORE
# CODE follows on the SAME line after the guard, and that code is neither a
# literal `exit N` (P1) nor end-of-line (P2) nor a heredoc opener (P3): if
# stripped, the reverted line would match NONE of P1/P2/P3 and would be
# completely invisible to part (iii)'s static sweep — confirmed empirically
# (the two protected sites named below are the full, exhaustive result of scanning
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
