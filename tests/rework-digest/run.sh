#!/usr/bin/env bash
# run.sh — drive bin/rework-digest.sh and assert the T-058 acceptance criteria:
#   - happy path prints the fixed digest skeleton verbatim (AC2)
#   - presentation-only: creates no files even when run in an empty dir (AC2)
#   - repetition judgment: >=2 occurrences of a slug -> same-class-repetition
#     + repeated-classes line; all-distinct -> new-classes-each-round (AC3)
#   - fail-closed input rejection: every malformed input exits 2 with usage on
#     stderr and NOTHING on stdout — no partial digest (AC4)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
RD="$REPO_ROOT/bin/rework-digest.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

GOLDEN="$HERE/expected-stdout.txt"

# --- T-104 (issue #330 Codex round1 Major): wire the golden diff in as a
# persistent, self-contained regression lock (DP-330-golden's "future edits
# must regenerate the golden" friction), not merely a one-time proof.
#
# Self-reference problem: this assertion's OWN pass/fail message would, if
# printed to stdout, become part of the very stream being compared against
# the frozen $GOLDEN (which predates this assertion and has a fixed line
# count) — a byte-diff against itself can never match. Fixed by re-executing
# this entire script as a child process (default invocation = parent; the
# REWORK_DIGEST_RUN_CHILD guard makes the child fall straight through past
# this block into the ORIGINAL suite body below, unchanged). The child's
# stdout is `tee`'d to both the real terminal (so the familiar live PASS
# trail is completely unaffected) and to a capture file, and ONLY THAT
# capture — the child's output, not this parent's own diagnostic — is
# diffed against $GOLDEN. This parent's own ok/FAIL line is written to
# stderr (never stdout), so it stays outside the compared stream and the
# spec's external AC4 check (`bash run.sh > "$t" && diff "$t" $GOLDEN`)
# keeps seeing exactly the child's byte-identical 47 lines on stdout.
if [ "${REWORK_DIGEST_RUN_CHILD:-0}" != "1" ]; then
  CAPTURE="$(mktemp "${TMPDIR:-/tmp}/rework-digest-golden-capture.XXXXXX")"
  trap 'rm -f "$CAPTURE"' EXIT
  set +e
  REWORK_DIGEST_RUN_CHILD=1 bash "$0" | tee "$CAPTURE"
  child_rc="${PIPESTATUS[0]}"
  set -e
  [ "$child_rc" -eq 0 ] || exit "$child_rc"
  if cmp -s "$CAPTURE" "$GOLDEN"; then
    printf 'ok: golden output diff — suite stdout byte-identical to the frozen pre-localization golden (%s, DP-330-golden persistent regression lock)\n' "$GOLDEN" >&2
  else
    printf 'FAIL: golden output diff — suite stdout differs from %s (regenerate ONLY on an intentional, reviewed output change)\n' "$GOLDEN" >&2
    exit 1
  fi
  exit 0
fi

# Always under $HERE (never $TMPDIR): the relative-symlink launch-path case
# below (linkdir/rework-digest-rel.sh -> ../../../../bin/rework-digest.sh)
# depends on $TMP sitting at a FIXED depth under the repo root
# (tests/rework-digest/<TMP>/linkdir, 4 levels up to REPO_ROOT) — an
# out-of-tree $TMPDIR root would break that fixed hop count.
TMP="$(mktemp -d "$HERE/tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- AC2: happy path — verbatim fixed skeleton (all-distinct classes) -------
expected_distinct="$TMP/expected-distinct"
cat > "$expected_distinct" <<'EOF'
=== REWORK-HISTORY DIGEST ===
stop-reason: max_iterations_reached
rounds:
  round 1 phase=validate class=missing-negative-ac
  round 2 phase=review class=contract-archaeology
judgment: new-classes-each-round
note: distinct root-cause class each round; extending may still converge.
=== END DIGEST ===
EOF
got="$TMP/got-distinct"
bash "$RD" \
  --round 1 --phase validate --class missing-negative-ac \
  --round 2 --phase review --class contract-archaeology \
  --stop-reason max_iterations_reached > "$got"
diff -u "$expected_distinct" "$got" >/dev/null || fail "happy path (distinct): output differs from fixed skeleton"
pass "happy path prints the fixed skeleton verbatim (distinct classes)"

# --- AC2: presentation-only — no files created in an empty cwd --------------
emptydir="$TMP/emptydir"
mkdir -p "$emptydir"
( cd "$emptydir" && bash "$RD" \
    --round 1 --phase validate --class some-class \
    --stop-reason no_progress > /dev/null )
[ -z "$(ls -A "$emptydir")" ] || fail "presentation-only: helper created files in its cwd"
pass "presentation-only: no files created"

# --- AC3: repetition branch — same slug twice -------------------------------
expected_rep="$TMP/expected-rep"
cat > "$expected_rep" <<'EOF'
=== REWORK-HISTORY DIGEST ===
stop-reason: no_progress
rounds:
  round 1 phase=validate class=fence-tracking
  round 2 phase=review class=fence-tracking
  round 3 phase=review class=quoting-corruption
judgment: same-class-repetition
repeated-classes: fence-tracking (x2)
note: Same-class-2 rule should have fired; consider bulk redesign before extending.
recommended-action: reconsider-design-premise (first choice when a class repeats)
  (a) route back to pm-spec/ui-designer — reconsider placement and scope
  (b) revert the implementation from the repeated rounds (see rounds list above)
  (c) continue extending — not the first choice here
=== END DIGEST ===
EOF
got_rep="$TMP/got-rep"
bash "$RD" \
  --round 1 --phase validate --class fence-tracking \
  --round 2 --phase review --class fence-tracking \
  --round 3 --phase review --class quoting-corruption \
  --stop-reason no_progress > "$got_rep"
diff -u "$expected_rep" "$got_rep" >/dev/null || fail "repetition branch: output differs"
pass "repetition branch: same-class-repetition + repeated-classes + note"

# Multiple repeated slugs are all listed, first-seen order, with counts.
out_multi="$(bash "$RD" \
  --round 1 --phase validate --class alpha-class \
  --round 1 --phase validate --class beta-class \
  --round 2 --phase review --class alpha-class \
  --round 3 --phase review --class beta-class \
  --round 3 --phase review --class beta-class \
  --stop-reason max_iterations_reached)"
printf '%s\n' "$out_multi" | grep -Fxq 'repeated-classes: alpha-class (x2), beta-class (x3)' \
  || fail "repetition branch: multi-slug counts/order wrong"
pass "repetition branch: multiple repeated slugs listed first-seen with counts"

# Distinct branch must NOT carry a repeated-classes line.
out_distinct="$(bash "$RD" --round 1 --phase validate --class only-once --stop-reason guard_error)"
printf '%s\n' "$out_distinct" | grep -Fq 'repeated-classes:' && fail "distinct branch: repeated-classes must be omitted"
printf '%s\n' "$out_distinct" | grep -Fxq 'judgment: new-classes-each-round' || fail "distinct branch: judgment line missing"
pass "distinct branch: judgment without repeated-classes line"

# AC3: distinct branch must NOT carry the recommended-action block either
# (the reconsider-design-premise re-routing branch only fires on repetition).
printf '%s\n' "$out_distinct" | grep -Fq 'recommended-action:' && fail "distinct branch: recommended-action must be omitted"
printf '%s\n' "$out_distinct" | grep -Fq '(a) route back to pm-spec' && fail "distinct branch: (a) route back to pm-spec choice must be omitted"
pass "distinct branch: recommended-action block omitted"

# --- executable bit: direct execution must work (no `bash` prefix) ----------
# Every other assertion launches via `bash "$RD"`, which masks a missing
# executable bit — but both SKILLs instruct the orchestrator to run the bare
# name / path directly, so exercise that launch shape once.
out_direct="$("$RD" --round 1 --phase validate --class direct-exec-check --stop-reason guard_error)"
printf '%s\n' "$out_direct" | grep -Fxq 'judgment: new-classes-each-round' \
  || fail "direct execution (no bash prefix): digest missing — executable bit lost?"
pass "direct execution without bash prefix (executable bit intact)"

# --- launch-path inventory: symlink invocation (PATH-style) ------------------
# bin/ scripts are invoked through PATH symlinks in adopted repos (established
# pattern — see log-run.sh's resolver and docs/specs/T-036). Symlink ONLY the
# digest script into a bare dir (goal-state.sh stays behind in real bin/): the
# resolver must follow the link back to the real bin/ to find its sibling.
linkdir="$TMP/linkdir"
mkdir -p "$linkdir"
ln -s "$RD" "$linkdir/rework-digest.sh"
out_symlink="$("$linkdir/rework-digest.sh" --round 1 --phase validate --class symlink-launch-check --stop-reason guard_error)"
printf '%s\n' "$out_symlink" | grep -Fxq 'judgment: new-classes-each-round' \
  || fail "symlink invocation: sibling goal-state.sh not resolved through the link"
# Relative symlink too — exercises the resolver's relative-target branch
# (linkdir is 4 levels below the repo root: tests/rework-digest/tmp/linkdir).
ln -s "../../../../bin/rework-digest.sh" "$linkdir/rework-digest-rel.sh"
out_symlink_rel="$("$linkdir/rework-digest-rel.sh" --round 1 --phase validate --class symlink-rel-check --stop-reason guard_error)" \
  || fail "relative symlink invocation failed"
printf '%s\n' "$out_symlink_rel" | grep -Fxq 'judgment: new-classes-each-round' \
  || fail "relative symlink invocation: sibling not resolved"
pass "symlink invocation (absolute and relative) resolves the real sibling goal-state.sh"

# --- AC4: fail-closed input rejection ----------------------------------------
# Each case: exit 2, empty stdout (no partial digest), usage on stderr.
reject() {
  local label="$1"; shift
  local out_f="$TMP/reject-out" err_f="$TMP/reject-err" rc
  set +e
  bash "$RD" "$@" > "$out_f" 2> "$err_f"; rc=$?
  set -e
  [ "$rc" -eq 2 ] || fail "$label: expected exit 2, got $rc"
  [ ! -s "$out_f" ] || fail "$label: stdout must be empty (no partial digest)"
  grep -Fq 'usage: rework-digest.sh' "$err_f" || fail "$label: usage missing from stderr"
  pass "reject: $label"
}

reject "unknown flag" --bogus 1 --stop-reason no_progress
reject "missing value for --round" --stop-reason no_progress --round
reject "non-integer --round" --round one --phase validate --class a-class --stop-reason no_progress
reject "zero --round" --round 0 --phase validate --class a-class --stop-reason no_progress
reject "10-digit --round" --round 1234567890 --phase validate --class a-class --stop-reason no_progress
reject "out-of-enum --phase" --round 1 --phase deploy --class a-class --stop-reason no_progress
reject "uppercase --class" --round 1 --phase validate --class BadClass --stop-reason no_progress
reject "leading-hyphen --class" --round 1 --phase validate --class -bad --stop-reason no_progress
reject "out-of-enum --stop-reason" --round 1 --phase validate --class a-class --stop-reason because
reject "incomplete triple (no --class)" --round 1 --phase validate --stop-reason no_progress
reject "incomplete triple (no --phase)" --round 1 --class a-class --stop-reason no_progress
reject "orphan --phase before --round" --phase validate --round 1 --class a-class --stop-reason no_progress
reject "duplicate --phase in record" --round 1 --phase validate --phase review --class a-class --stop-reason no_progress
reject "zero records" --stop-reason no_progress
reject "missing --stop-reason" --round 1 --phase validate --class a-class
reject "duplicate --stop-reason" --round 1 --phase validate --class a-class --stop-reason no_progress --stop-reason guard_error
# Trailing flags with no value.
reject "missing value for --phase (trailing)" --round 1 --phase
reject "missing value for --class (trailing)" --round 1 --phase validate --class
reject "missing value for --stop-reason (trailing)" --round 1 --phase validate --class a-class --stop-reason
# Values that are themselves flag strings must be rejected as bad values.
reject "flag-valued --round" --round --phase
reject "flag-valued --class" --round 1 --phase validate --class --stop-reason
reject "flag-valued --stop-reason" --round 1 --phase validate --class a-class --stop-reason --round

# --- AC5: signature-token self-check — legal-charset slugs that would leak ---
# Hyphen is a word boundary for goal-state.sh's `grep -w`, so these slugs pass
# the charset regex yet would put a whole-word token into the signature. The
# script must fail closed (exit 2, empty stdout) instead of printing them.
reject "signature-leak slug (whole-word verdict token, validate)" --round 1 --phase validate --class test-pass-case --stop-reason no_progress
reject "signature-leak slug (whole-word verdict token, review)" --round 1 --phase review --class qa-fail-mode --stop-reason no_progress
reject "signature-leak slug (approval token)" --round 1 --phase validate --class release-approve-flow --stop-reason no_progress
reject "signature-leak slug (ac+digits token)" --round 1 --phase validate --class ac10-migration --stop-reason no_progress
# The rejection message must name the cause so the orchestrator can rename the slug.
set +e
bash "$RD" --round 1 --phase validate --class test-pass-case --stop-reason no_progress > "$TMP/leak-out" 2> "$TMP/leak-err"; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "leak rejection: expected exit 2, got $rc"
grep -Fq 'signature token' "$TMP/leak-err" || fail "leak rejection should name the signature-token cause on stderr"
pass "signature-leak rejection names the cause"

# --- T-100: early mode (--trigger same-class-2) ------------------------------
# --- AC1: happy path — verbatim fixed skeleton (early mode, repetition) -----
expected_early="$TMP/expected-early"
cat > "$expected_early" <<'EOF'
=== REWORK-HISTORY DIGEST ===
trigger: same-class-2
rounds:
  round 1 phase=validate class=fence-tracking
  round 2 phase=review class=fence-tracking
judgment: same-class-repetition
repeated-classes: fence-tracking (x2)
note: Same-class-2 threshold reached now — escalating before STOP; reconsider the design premise before extending further.
recommended-action: reconsider-design-premise (first choice when a class repeats)
  (a) route back to pm-spec/ui-designer — reconsider placement and scope
  (b) revert the implementation from the repeated rounds (see rounds list above)
  (c) continue extending — not the first choice here
=== END DIGEST ===
EOF
got_early="$TMP/got-early"
bash "$RD" \
  --round 1 --phase validate --class fence-tracking \
  --round 2 --phase review --class fence-tracking \
  --trigger same-class-2 > "$got_early"
diff -u "$expected_early" "$got_early" >/dev/null || fail "early mode happy path: output differs from fixed skeleton"
pass "early mode (T-100): happy path prints the fixed skeleton verbatim"

out_early="$(cat "$got_early")"
printf '%s\n' "$out_early" | grep -q 'stop-reason:' && fail "early mode: stop-reason: line must be absent"
pass "early mode: no stop-reason: line present"

# --- AC2: mutual exclusivity — both --stop-reason and --trigger present -----
reject "both --stop-reason and --trigger present" \
  --round 1 --phase validate --class a-class --stop-reason no_progress --trigger same-class-2

# --- AC3: neither mode present ------------------------------------------------
reject "neither --stop-reason nor --trigger present" \
  --round 1 --phase validate --class a-class

# --- AC4: --trigger enum — bad value ------------------------------------------
reject "--trigger bad value" \
  --round 1 --phase validate --class a-class --trigger some-other-thing

# --- other --trigger fail-closed shapes (mirrors --stop-reason coverage) ----
reject "missing value for --trigger (trailing)" \
  --round 1 --phase validate --class a-class --trigger
reject "duplicate --trigger" \
  --round 1 --phase validate --class a-class --trigger same-class-2 --trigger same-class-2
reject "flag-valued --trigger" \
  --round 1 --phase validate --class a-class --trigger --round

# --- AC5: early mode requires repetition (DP-3 contradiction fail-closed) ---
reject "early mode with all-distinct classes (DP-3 contradiction)" \
  --round 1 --phase validate --class only-once --trigger same-class-2

# --- AC6: signature self-check holds in early mode --------------------------
sig_early="$(printf '%s\n' "$out_early" | bash "$REPO_ROOT/bin/goal-state.sh" signature)"
[ "$sig_early" = "NO_VERDICT" ] || fail "early mode: signature self-check expected NO_VERDICT, got '$sig_early'"
pass "early mode: signature self-check yields NO_VERDICT"

printf '\nAll rework-digest assertions passed.\n'
