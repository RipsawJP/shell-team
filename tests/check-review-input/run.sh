#!/usr/bin/env bash
# run.sh — assert bin/check-review-input.sh (T-1104, issue #335) against the
# real script: the review-input fidelity checker validating a record's
# per-pass grammar (executor-invocation / pass-role / briefing-fidelity /
# raw-capture), the two closed vocabularies, the pass-id charset, the
# cross-round raw-capture-stem collision refusal and the record's own
# task-id precedence for the stem-prefix check.
#
# This suite is a fixture-level companion to the spec's own inline
# `- check:` lines (.shell-team/specs/T-1104-review-input-fidelity.md,
# AC1-AC21) — it exercises the SAME script directly, in its own dedicated
# location, so the obligation this checker discharges has a named `bin/`
# script with its own `tests/<name>/run.sh` suite (tamper-arm-rule-v1's
# structural form for arm-A-tested-primitive).
#
# Exit: 0 = every assertion passed; non-zero = a FAIL line was printed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/check-review-input.sh"

if [ -n "${TMPDIR:-}" ]; then
  T="$(mktemp -d "${TMPDIR%/}/check-review-input-test.XXXXXX")"
else
  T="$(mktemp -d "${TMPDIR:-/tmp}/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# assert_exit NAME EXPECT_RC TOKEN_OR_EMPTY -- CMD...
# Runs CMD (capturing stdout+stderr combined), asserts its exit code equals
# EXPECT_RC, and — when TOKEN_OR_EMPTY is non-empty — asserts the combined
# output carries that token as a fixed-string substring.
assert_case() {
  local name="$1" expect_rc="$2" token="$3"
  shift 3
  [ "$1" = "--" ] || fail "assert_case $name: malformed call (expected -- before the command)"
  shift
  local out rc
  out="$("$@" 2>&1)" && rc=0 || rc=$?
  [ "$rc" -eq "$expect_rc" ] || fail "$name: expected exit $expect_rc, got $rc (output: $out)"
  if [ -n "$token" ]; then
    printf '%s' "$out" | grep -Fq -- "$token" || fail "$name: output must carry token '$token' (output: $out)"
  fi
  pass "$name"
}

# blk ID ROLE STEM — a complete four-field pass block for pass id ID.
blk() {
  printf '  - executor-invocation (%s): codex exec --sandbox read-only --cd . review --base develop\n  - pass-role (%s): %s\n  - briefing-fidelity (%s): carried - scope and calibration stated in the argv\n  - raw-capture (%s): %s\n' \
    "$1" "$1" "$2" "$1" "$1" "$3"
}

# ============================================================================
# Usage / environment refusals (exit 2)
# ============================================================================
assert_case "usage: unknown flag" 2 usage -- bash "$SCRIPT" --no-such-flag
assert_case "usage: no record and no task" 2 usage -- bash "$SCRIPT"
assert_case "usage: --record with no value" 2 usage -- bash "$SCRIPT" --record
assert_case "usage: --task with no value" 2 usage -- bash "$SCRIPT" --task
assert_case "usage: invalid task id shape" 2 usage -- bash "$SCRIPT" --task not-a-task-id --record "$T/none.md"

printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n' > "$T/T-000.md"
assert_case "explicit --record: absent path refuses record-unreadable" 2 record-unreadable -- \
  bash "$SCRIPT" --record "$T/absent.md" --task T-000
mkdir -p "$T/adir.md"
assert_case "explicit --record: directory occupant refuses record-unreadable" 2 record-unreadable -- \
  bash "$SCRIPT" --record "$T/adir.md" --task T-000
ln -s "$T/nowhere-at-all" "$T/dangle.md"
assert_case "explicit --record: dangling symlink refuses record-unreadable" 2 record-unreadable -- \
  bash "$SCRIPT" --record "$T/dangle.md" --task T-000

printf 'this path is a regular file, not a directory\n' > "$T/notadir"
assert_case "--task-only: reviews dir occupied by a regular file refuses reviews-dir-unresolvable" 2 reviews-dir-unresolvable -- \
  env TEAM_REVIEWS_DIR="$T/notadir" bash "$SCRIPT" --task T-000

# ============================================================================
# Dangling-symlink fail-open at the auto-resolved paths (Codex review
# Major): a broken occupant at either the --task-only-resolved reviews
# directory or the resolved per-task record path is NOT "does not exist" —
# it must fail closed (exit 2), never take the forward-only leniency an
# absent path gets.
# ============================================================================
ln -s "$T/nowhere-reviews-dir-at-all" "$T/dangle-reviews-dir"
assert_case "--task-only: dangling symlink AT the reviews dir refuses reviews-dir-unresolvable (not lenient)" 2 reviews-dir-unresolvable -- \
  env TEAM_REVIEWS_DIR="$T/dangle-reviews-dir" bash "$SCRIPT" --task T-000
mkdir -p "$T/rv-dangle"
ln -s "$T/nowhere-record-at-all" "$T/rv-dangle/T-999.md"
assert_case "--task-only: dangling symlink AT the resolved record path refuses record-unreadable (not lenient)" 2 record-unreadable -- \
  env TEAM_REVIEWS_DIR="$T/rv-dangle" bash "$SCRIPT" --task T-999

# ============================================================================
# --task-only leniency: an absent reviews directory, or an absent per-task
# record file at a resolvable directory, is read as "no record for this
# task yet" (exit 0) — never for an explicit --record (T-1104's Notes for
# engineer / close-out.sh backward-compatibility requirement: an
# unconditional gate must not break a task nobody has reviewed yet).
# ============================================================================
assert_case "--task-only: reviews dir does not exist at all is lenient (exit 0)" 0 "" -- \
  env TEAM_REVIEWS_DIR="$T/never-created-dir" bash "$SCRIPT" --task T-500
mkdir -p "$T/rv"
assert_case "--task-only: reviews dir exists but this task's record does not is lenient (exit 0)" 0 "" -- \
  env TEAM_REVIEWS_DIR="$T/rv" bash "$SCRIPT" --task T-501

# ============================================================================
# Forward-only: a record with zero input-fidelity fields exits 0
# ============================================================================
assert_case "zero-field record exits 0 (--record)" 0 "" -- bash "$SCRIPT" --record "$T/T-000.md" --task T-000
cp "$T/T-000.md" "$T/rv/T-000.md"
assert_case "zero-field record exits 0 (--task-only, resolved)" 0 "" -- \
  env TEAM_REVIEWS_DIR="$T/rv" bash "$SCRIPT" --task T-000

# ============================================================================
# Per-section completeness (DP-4/AC4, v2): a section opts in the moment it
# carries ANY of the four fields, and once opted in it must carry a
# complete pass block ALL FOUR of whose field lines sit inside that same
# section. A section carrying none of the four fields is conformant
# whatever the rest of the record carries — the v1->v2 class-B re-freeze's
# repair for the frozen-region Blocker (a per-record trigger made this
# task's own review record, whose earlier spec-review sections predate the
# mechanism, jointly unsatisfiable with the anti-retrofit Non-goals).
# ============================================================================
{ printf '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n- Task: T-000\n'; blk sr1 generation T-000-codex-specreview; } > "$T/one.md"
assert_case "one section, one complete block: exit 0" 0 "" -- bash "$SCRIPT" --record "$T/one.md" --task T-000

# Mixed record (Input space class 12): a bare, uninstrumented section
# (ordinary prose, the shape every already-committed record in this
# corpus is made of) beside a fully instrumented one — the concrete shape
# of this task's own .shell-team/reviews/T-1104.md (AC21) — MUST exit 0
# with the bare section byte-untouched, never section-incomplete.
{ printf '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n- Task: T-000\n- Verification mode: static-only\n\nA verdict section written before the field grammar existed.\n\n## Codex review - round 1\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk im1 generation T-000-codex-primary; } > "$T/legacy-mixed.md"
assert_case "mixed record: a bare (uninstrumented) section beside an instrumented one exits 0" 0 "" -- bash "$SCRIPT" --record "$T/legacy-mixed.md" --task T-000

{ printf '## Spec review\n\n### Codex Spec-Review verdict: APPROVE\n- Task: T-000\n'; blk sr1 generation T-000-codex-specreview; printf '\n## Codex review - round 1\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk im1 confirmation T-000-codex-primary; } > "$T/both.md"
assert_case "two sections each with a complete block: exit 0" 0 "" -- bash "$SCRIPT" --record "$T/both.md" --task T-000

{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk pa generation T-000-codex-primary; blk pb confirmation T-000-codex-adversarial; } > "$T/two.md"
assert_case "one section with two complete blocks: exit 0" 0 "" -- bash "$SCRIPT" --record "$T/two.md" --task T-000

# Section-scoped ownership (Codex review Major 4's own reproduction): a
# pass split across two sections — one field under the first heading, its
# other three fields under a second heading that ALSO carries a complete
# block of its own (from a different id) — refuses section-incomplete on
# the FIRST section only. Crediting a section from a pass id's earliest
# field line alone (ignoring where its other three fields actually sit)
# is exactly the defect this reproduces.
{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (pa): codex exec --sandbox read-only --cd . review --base develop\n'; \
  printf '\n## Codex review - round 2\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - pass-role (pa): generation\n  - briefing-fidelity (pa): carried - scope and calibration stated in the argv\n  - raw-capture (pa): T-000-codex-primary\n'; blk pb generation T-000-codex-primary-r2; } > "$T/split-ownership.md"
assert_case "section-scoped ownership: a pass split across two sections refuses section-incomplete on the split-owning section" 1 section-incomplete -- bash "$SCRIPT" --record "$T/split-ownership.md" --task T-000

# ============================================================================
# Per-pass field completeness / non-duplication (AC5)
# ============================================================================
hdr() { printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; }
f1='  - executor-invocation (p1): codex exec --sandbox read-only review --base develop'
f2='  - pass-role (p1): generation'
f3='  - briefing-fidelity (p1): carried - scope stated in the argv'
f4='  - raw-capture (p1): T-000-codex-primary'
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; } > "$T/ok.md"
assert_case "complete four-field block: exit 0 (AC5 positive control)" 0 "" -- bash "$SCRIPT" --record "$T/ok.md" --task T-000

i=0
for drop in 1 2 3 4; do
  i=$((i + 1))
  { hdr; j=0; for v in "$f1" "$f2" "$f3" "$f4"; do j=$((j + 1)); [ "$j" = "$drop" ] || printf '%s\n' "$v"; done; } > "$T/m$i.md"
  assert_case "field-missing case $i (field $drop dropped)" 1 field-missing -- bash "$SCRIPT" --record "$T/m$i.md" --task T-000
done

k=0
for dupi in 1 2 3 4; do
  k=$((k + 1))
  { hdr; j=0; for v in "$f1" "$f2" "$f3" "$f4"; do j=$((j + 1)); printf '%s\n' "$v"; [ "$j" = "$dupi" ] && printf '%s\n' "$v"; done; } > "$T/d$k.md"
  assert_case "field-duplicate case $k (field $dupi duplicated verbatim)" 1 field-duplicate -- bash "$SCRIPT" --record "$T/d$k.md" --task T-000
done

{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; \
  printf '  - executor-invocation (p1): codex exec review --base main\n  - pass-role (p1): confirmation\n  - briefing-fidelity (p1): not-carried - no prompt channel on this pass\n  - raw-capture (p1): T-000-codex-adversarial\n'; } > "$T/db.md"
assert_case "field-duplicate case (same id, two complete blocks, all values distinct)" 1 field-duplicate -- bash "$SCRIPT" --record "$T/db.md" --task T-000

for bad in 'P1' 'p 1'; do
  { hdr; printf '  - executor-invocation (%s): codex exec review --base develop\n  - pass-role (%s): generation\n  - briefing-fidelity (%s): carried - x\n  - raw-capture (%s): T-000-codex-primary\n' "$bad" "$bad" "$bad" "$bad"; } > "$T/cs.md"
  assert_case "pass-id-charset case ('$bad')" 1 pass-id-charset -- bash "$SCRIPT" --record "$T/cs.md" --task T-000
done

# ============================================================================
# Closed vocabularies (AC6)
# ============================================================================
mkr() { printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): codex exec review --base develop\n  - pass-role (p1): %s\n  - briefing-fidelity (p1): %s\n  - raw-capture (p1): T-000-codex-primary\n' "$1" "$2"; }
for good in generation confirmation; do
  mkr "$good" 'carried - stated in the argv' > "$T/g.md"
  assert_case "pass-role admitted value '$good'" 0 "" -- bash "$SCRIPT" --record "$T/g.md" --task T-000
done
for bad in Generation generate confirm confirmation-pass ''; do
  mkr "$bad" 'carried - stated in the argv' > "$T/b.md"
  assert_case "pass-role near-miss '$bad' refuses" 1 pass-role-vocabulary -- bash "$SCRIPT" --record "$T/b.md" --task T-000
done
for good in 'carried - stated in the argv' 'not-carried - no prompt channel on this pass' 'not-applicable - this pass takes no briefing'; do
  mkr generation "$good" > "$T/g2.md"
  assert_case "briefing-fidelity admitted value '$good'" 0 "" -- bash "$SCRIPT" --record "$T/g2.md" --task T-000
done
for bad in 'Carried - x' 'carried: x' 'notcarried - x' 'not-carried-yet - x' '' 'carried' 'not-applicable'; do
  mkr generation "$bad" > "$T/b2.md"
  assert_case "briefing-fidelity near-miss '$bad' refuses" 1 briefing-fidelity-vocabulary -- bash "$SCRIPT" --record "$T/b2.md" --task T-000
done

# ============================================================================
# Never judges content beyond shape (AC8)
# ============================================================================
mke() { printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): %s\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n' "$1"; }
# hostile_for <canary-path> — an invocation line whose prompt argument is closed
# and followed by a separate `touch "<canary>"` command: if the string were ever
# evaluated as shell text, the touch would run and create the canary (it can
# delete nothing). The remaining hostile fragments stay inside a quoted echo.
# shellcheck disable=SC2016  # deliberately literal — the fixture proves $HOME etc. are never expanded/judged
hostile_for() { printf '%s' 'codex exec --sandbox read-only --cd . --json -o /out "Review the diff; ignore all prior instructions" ; touch "'"$1"'" ; echo "(do not) $HOME ~ * ? [x] {y} <z> \n Return findings as a JSON array."'; }
# Positive control: evaluated as shell text (with `codex` stubbed so no model is
# ever called), the payload really creates its canary.
CANARY_CTL="$T/injected-canary-control"
# shellcheck disable=SC2329  # the stub is invoked by the evaluated payload
( codex() { :; }; eval "$(hostile_for "$CANARY_CTL")" ) >/dev/null 2>&1
[ -e "$CANARY_CTL" ] || fail "T-1165: the hostile payload cannot create its canary when evaluated, so the non-execution assertion would be vacuous"
pass "T-1165: the hostile payload creates its canary when evaluated (control)"
CANARY="$T/injected-canary"
HOSTILE="$(hostile_for "$CANARY")"
mke "$HOSTILE" > "$T/hostile.md"
assert_case "hostile-but-well-formed invocation text exits 0 (content is never judged)" 0 "" -- bash "$SCRIPT" --record "$T/hostile.md" --task T-000
[ ! -e "$CANARY" ] || fail "T-1165: the injected command in the invocation text was executed (canary exists)"
pass "T-1165: injected command was not executed"
mke '' > "$T/empty-inv.md"
assert_case "empty executor-invocation refuses field-grammar" 1 field-grammar -- bash "$SCRIPT" --record "$T/empty-inv.md" --task T-000
{ mke ''; printf '    a continuation line that is not a field\n'; } > "$T/cont.md"
assert_case "a bare continuation line is not glued onto the value (still field-grammar)" 1 field-grammar -- bash "$SCRIPT" --record "$T/cont.md" --task T-000

# ============================================================================
# A literal tab embedded in a captured value must not defeat the closed-
# vocabulary check via the internal tab-delimited work-file transport
# (Codex review Major): the internal transport is tab-delimited, so a
# value carrying a real tab byte could otherwise be truncated at the
# vocabulary check and read as its (conformant-looking) prefix.
# ============================================================================
printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): codex exec review --base develop\n  - pass-role (p1): generation\tbogus-extra-not-a-real-vocab-word\n  - briefing-fidelity (p1): carried - x\n  - raw-capture (p1): T-000-codex-primary\n' > "$T/tab-in-value.md"
assert_case "a literal tab in a field value refuses field-grammar rather than truncating to a conformant prefix" 1 field-grammar -- bash "$SCRIPT" --record "$T/tab-in-value.md" --task T-000
printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1\tbogus): codex exec review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - x\n  - raw-capture (p1): T-000-codex-primary\n' > "$T/tab-in-id.md"
assert_case "a literal tab in a pass id refuses field-grammar" 1 field-grammar -- bash "$SCRIPT" --record "$T/tab-in-id.md" --task T-000

# ============================================================================
# Raw-capture stem prefix / cross-round collision (AC7)
# ============================================================================
{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk a generation T-000-codex-primary; \
  printf '\n## Codex review - round 2\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk b generation T-000-codex-primary-r2; } > "$T/stemok.md"
assert_case "distinct per-round stems (a, a-r2): exit 0" 0 "" -- bash "$SCRIPT" --record "$T/stemok.md" --task T-000

{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk a generation T-000-codex-primary; \
  printf '\n## Codex review - round 2\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk b generation T-000-codex-primary; } > "$T/coll-cross-section.md"
assert_case "same stem across two sections refuses raw-capture-collision" 1 raw-capture-collision -- bash "$SCRIPT" --record "$T/coll-cross-section.md" --task T-000

{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk a generation T-000-codex-primary; blk b confirmation T-000-codex-primary; } > "$T/coll-same-section.md"
assert_case "same stem within one section also refuses raw-capture-collision" 1 raw-capture-collision -- bash "$SCRIPT" --record "$T/coll-same-section.md" --task T-000

{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; blk a generation T-999-codex-primary; } > "$T/stemmismatch.md"
assert_case "stem not prefixed by the resolved task id refuses raw-capture-stem-mismatch" 1 raw-capture-stem-mismatch -- bash "$SCRIPT" --record "$T/stemmismatch.md" --task T-000

# ============================================================================
# Task-id precedence (DP-3's round-3 addendum): --task argument sole
# authority when given, else the record path's basename; the internal
# `- Task:` line is never read.
# ============================================================================
mkdir -p "$T/prec1" "$T/prec2"
{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-999\n'; blk a generation T-000-codex-primary; } > "$T/prec1/T-000.md"
{ printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-999\n'; blk a generation T-999-codex-primary; } > "$T/prec2/T-000.md"
assert_case "precedence: --task argument wins, agrees with stem (internal Task: T-999 never read): exit 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/prec1/T-000.md" --task T-000
assert_case "precedence: basename-fallback (no --task) agrees with stem: exit 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/prec1/T-000.md"
assert_case "precedence: --task argument wins, stem disagreeing with argument refuses" 1 raw-capture-stem-mismatch -- \
  bash "$SCRIPT" --record "$T/prec2/T-000.md" --task T-000
assert_case "precedence: basename-fallback, stem disagreeing with basename refuses" 1 raw-capture-stem-mismatch -- \
  bash "$SCRIPT" --record "$T/prec2/T-000.md"

# ============================================================================
# No-echo discipline (AC9): a refusal never republishes the verbatim field's
# bytes, only the record/pass id/token.
# ============================================================================
MARKER=ZQX-marker-do-not-echo-9317
printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): codex exec review --base develop %s\n  - pass-role (p1): Generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n' "$MARKER" > "$T/echo1.md"
out1="$(bash "$SCRIPT" --record "$T/echo1.md" --task T-000 2>&1)" && rc1=0 || rc1=$?
[ "$rc1" -eq 1 ] || fail "no-echo case 1: expected exit 1, got $rc1"
if printf '%s' "$out1" | grep -Fq -- "$MARKER"; then
  fail "no-echo case 1: the marker leaked into output"
fi
pass "no-echo case 1: marker never echoed"

printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): codex exec review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - x\n  - raw-capture (p1): T-000-codex-primary-%s\n  - executor-invocation (p2): codex exec review --base develop\n  - pass-role (p2): generation\n  - briefing-fidelity (p2): carried - x\n  - raw-capture (p2): T-000-codex-primary-%s\n' "$MARKER" "$MARKER" > "$T/echo2.md"
out2="$(bash "$SCRIPT" --record "$T/echo2.md" --task T-000 2>&1)" && rc2=0 || rc2=$?
[ "$rc2" -eq 1 ] || fail "no-echo case 2: expected exit 1, got $rc2"
if printf '%s' "$out2" | grep -Fq -- "$MARKER"; then
  fail "no-echo case 2: the marker (embedded in the colliding raw-capture VALUE itself, the field this refusal path actually interpolates) leaked into output"
fi
pass "no-echo case 2: marker never echoed (collision path, marker in the raw-capture field)"

# ============================================================================
# self-detected-host — the optional fifth per-pass field (T-1138, issue #508)
# ============================================================================

# Legacy record: a conformant four-field pass with no self-detected-host
# line at all still exits 0 — the field is validate-if-present, never
# required, and every already-committed record today is in this class.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; } > "$T/sdh-legacy.md"
assert_case "self-detected-host: a legacy four-field record with no fifth field exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-legacy.md" --task T-000

# Per-pass optional: one pass carries the field, a sibling pass does not.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; \
  printf '  - self-detected-host (p1): claude-code — CODEX_THREAD_ID was not set in this shell\n'; \
  printf '  - executor-invocation (p2): codex exec review --base develop\n  - pass-role (p2): confirmation\n  - briefing-fidelity (p2): carried - x\n  - raw-capture (p2): T-000-codex-adversarial\n'; } > "$T/sdh-mixed.md"
assert_case "self-detected-host: per-pass optional (one pass carries it, a sibling does not) exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-mixed.md" --task T-000

# Accepting arm (a): codex-cli beside a claude -p invocation whose LATER
# text merely contains the literal string "codex exec" — a substring rule
# would wrongly refuse this; the token-anchored rule must not.
{ hdr; printf -- '  - executor-invocation (p1): claude -p --output-format stream-json --prompt-file p.txt describing what codex exec would have read\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): codex-cli — CODEX_THREAD_ID was set in this shell before any launch\n'; } > "$T/sdh-accept-a.md"
assert_case "self-detected-host: codex-cli beside a claude -p invocation whose prompt text mentions codex exec exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-accept-a.md" --task T-000

# Accepting arm (b): claude-code beside an invocation beginning codex exec
# — the shipped Claude-host behaviour, and not a contradiction (the b run
# #4 direction this mechanism deliberately cannot catch).
{ hdr; printf -- '  - executor-invocation (p1): codex exec --sandbox read-only --cd . review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): claude-code — CODEX_THREAD_ID was not set in this shell\n'; } > "$T/sdh-accept-b.md"
assert_case "self-detected-host: claude-code beside a codex-exec invocation exits 0 (shipped Claude-host shape, not a contradiction)" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-accept-b.md" --task T-000

# Accepting arm (c): codex-cli beside an invocation whose first token is
# codexify — whole-token comparison, never a prefix match.
{ hdr; printf -- '  - executor-invocation (p1): codexify exec --sandbox read-only --cd .\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): codex-cli — CODEX_THREAD_ID was set in this shell before any launch\n'; } > "$T/sdh-accept-c.md"
assert_case "self-detected-host: codex-cli beside a codexify-first-token invocation exits 0 (whole-token match, never a prefix)" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-accept-c.md" --task T-000

# Refusal: self-detected-host-vocabulary — three shapes, one token.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): claude-cli — ground stated here\n'; } > "$T/sdh-vocab-a.md"
assert_case "self-detected-host-vocabulary: near-miss first token 'claude-cli'" 1 self-detected-host-vocabulary -- \
  bash "$SCRIPT" --record "$T/sdh-vocab-a.md" --task T-000

{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): codex-cli\n'; } > "$T/sdh-vocab-b.md"
assert_case "self-detected-host-vocabulary: missing separator entirely" 1 self-detected-host-vocabulary -- \
  bash "$SCRIPT" --record "$T/sdh-vocab-b.md" --task T-000

{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): codex-cli — \n'; } > "$T/sdh-vocab-c.md"
assert_case "self-detected-host-vocabulary: separator present with an empty ground" 1 self-detected-host-vocabulary -- \
  bash "$SCRIPT" --record "$T/sdh-vocab-c.md" --task T-000

# Refusal: self-detected-host-duplicate — two lines under one pass id.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): codex-cli — ground one\n  - self-detected-host (p1): claude-code — ground two\n'; } > "$T/sdh-dup.md"
assert_case "self-detected-host-duplicate: two lines under one pass id" 1 self-detected-host-duplicate -- \
  bash "$SCRIPT" --record "$T/sdh-dup.md" --task T-000

# Refusal: self-detected-host-contradiction — codex-cli declared beside an
# executor-invocation beginning codex exec, with and without leading
# whitespace before the first token (D4's normalization requirement).
{ hdr; printf -- '  - executor-invocation (p1): codex exec --sandbox read-only --cd . review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): codex-cli — CODEX_THREAD_ID was set in this shell before any launch\n'; } > "$T/sdh-contra-a.md"
assert_case "self-detected-host-contradiction: codex-cli beside a codex-exec invocation" 1 self-detected-host-contradiction -- \
  bash "$SCRIPT" --record "$T/sdh-contra-a.md" --task T-000

{ hdr; printf -- '  - executor-invocation (p1):    codex exec --sandbox read-only --cd . review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): codex-cli — CODEX_THREAD_ID was set in this shell before any launch\n'; } > "$T/sdh-contra-b.md"
assert_case "self-detected-host-contradiction: same, with leading whitespace before the invocation's first token" 1 self-detected-host-contradiction -- \
  bash "$SCRIPT" --record "$T/sdh-contra-b.md" --task T-000

# ============================================================================
# self-detected-host — round-2 rework (review REQUEST_CHANGES, Blocker: the
# value's own leading whitespace was never normalized before the vocabulary
# comparison). Seven variants, each the whitespace shape named in the
# rework briefing, in the briefing's own order.
# ============================================================================

# Variant 1 (Blocker, live-reproduced by the reviewer): leading whitespace
# BEFORE the token, surviving because FIELD_RE consumes only one optional
# space after the colon. Two spaces after the colon here — one consumed by
# FIELD_RE, one landing at the front of the captured value. Must be
# ACCEPTED (this is the false-refusal direction the Pre-commitment prices
# above silence).
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1):  claude-code — CODEX_THREAD_ID was not set in this shell\n'; } > "$T/sdh-ws-1-leading-before-token.md"
assert_case "self-detected-host whitespace variant 1: leading whitespace before the token (two spaces after the colon) exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-ws-1-leading-before-token.md" --task T-000

# Variant 2: trailing whitespace AFTER the token, BEFORE the separator —
# "claude-code   — ground" (three extra spaces before the em dash). The
# grammar is "first token inside the closed pair, then ' — '"; extra
# whitespace between them must not defeat the exact-match comparison.
# Must be ACCEPTED.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): claude-code   — ground stated here\n'; } > "$T/sdh-ws-2-trailing-before-sep.md"
assert_case "self-detected-host whitespace variant 2: trailing whitespace between the token and the separator exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-ws-2-trailing-before-sep.md" --task T-000

# Variant 3: leading whitespace IN THE GROUND — "claude-code —   ground
# text" (three spaces after the separator, before the ground text). The
# ground itself is non-blank, so this must be ACCEPTED; the ground's own
# leading whitespace is legitimate content and is never trimmed from the
# value.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): claude-code —   ground text with leading spaces\n'; } > "$T/sdh-ws-3-leading-in-ground.md"
assert_case "self-detected-host whitespace variant 3: leading whitespace in a non-blank ground exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-ws-3-leading-in-ground.md" --task T-000

# Variant 4 (Minor): a whitespace-ONLY ground — "claude-code —    " (the
# separator followed only by spaces, no ground text at all). [ -n ] tests
# byte length, not content; must REFUSE self-detected-host-vocabulary
# because there is no non-whitespace byte after the separator.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): claude-code —    \n'; } > "$T/sdh-ws-4-whitespace-only-ground.md"
assert_case "self-detected-host whitespace variant 4: a whitespace-only ground refuses self-detected-host-vocabulary" 1 self-detected-host-vocabulary -- \
  bash "$SCRIPT" --record "$T/sdh-ws-4-whitespace-only-ground.md" --task T-000

# Variant 5: trailing whitespace AFTER a non-blank ground — "claude-code —
# ground text   " (trailing spaces at end of line). Must be ACCEPTED; the
# ground carries real content regardless of trailing whitespace.
{ hdr; printf '%s\n%s\n%s\n%s\n' "$f1" "$f2" "$f3" "$f4"; printf -- '  - self-detected-host (p1): claude-code — ground text   \n'; } > "$T/sdh-ws-5-trailing-after-ground.md"
assert_case "self-detected-host whitespace variant 5: trailing whitespace after a non-blank ground exits 0" 0 "" -- \
  bash "$SCRIPT" --record "$T/sdh-ws-5-trailing-after-ground.md" --task T-000

# Variant 6: leading whitespace before the token on a codex-cli
# declaration, beside an executor-invocation beginning codex exec — the
# normalization must not let the contradiction rule miss its token. Must
# still REFUSE self-detected-host-contradiction (leading whitespace on the
# self-detected-host side, as opposed to sdh-contra-b's leading whitespace
# on the executor-invocation side above).
{ hdr; printf -- '  - executor-invocation (p1): codex exec --sandbox read-only --cd . review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1):  codex-cli — CODEX_THREAD_ID was set in this shell before any launch\n'; } > "$T/sdh-ws-6-leading-before-token-contradiction.md"
assert_case "self-detected-host whitespace variant 6: leading whitespace before a codex-cli token still refuses self-detected-host-contradiction" 1 self-detected-host-contradiction -- \
  bash "$SCRIPT" --record "$T/sdh-ws-6-leading-before-token-contradiction.md" --task T-000

# Variant 7 (ordering lock): a literal TAB embedded in the self-detected-host
# value must refuse field-grammar — the generic embedded-TAB shape rule
# (bin/check-review-input.sh:~289-294) fires before any self-detected-host-
# specific check runs, exactly as it already does for the other four
# fields (the "a literal tab in a field value" case above).
printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n  - executor-invocation (p1): codex exec review --base develop\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - x\n  - raw-capture (p1): T-000-codex-primary\n  - self-detected-host (p1): codex-cli — ground\twith an embedded tab byte\n' > "$T/sdh-ws-7-embedded-tab.md"
assert_case "self-detected-host whitespace variant 7: an embedded tab in the value refuses field-grammar before any self-detected-host-specific check runs" 1 field-grammar -- \
  bash "$SCRIPT" --record "$T/sdh-ws-7-embedded-tab.md" --task T-000

# =============================================================================
# T-1165: check-review-input.sh cleans up its scratch directory by name and rmdir, never
# a recursive delete. Two runs of one command against fresh TMPDIRs: a plain
# run, and a run with a PATH shim whose rmdir exits 1 without touching
# anything. The exit status must be identical, the plain run must leave no
# check-review-input.* directory, and the shimmed run must leave exactly one (proving the
# cleanup really reached rmdir and that its failure did not move the status).
# =============================================================================
t1165_rmdir_case() {  # $1 = tool (no .sh); $2.. = command; optional T1165_CWD
  local tool="$1" d e a=0 b=0 nn=0 ns=0
  shift
  d="$(mktemp -d "${TMPDIR:-/tmp}/t1165-${tool}.XXXXXX")" \
    || { fail "T-1165: ${tool}.sh: cannot create the case directory"; }
  mkdir "$d/n" "$d/s" "$d/shim"
  printf '#!/bin/sh\nexit 1\n' > "$d/shim/rmdir"
  chmod +x "$d/shim/rmdir"
  (cd "${T1165_CWD:-.}" && TMPDIR="$d/n" "$@" >/dev/null 2>&1) || a=$?
  (cd "${T1165_CWD:-.}" && PATH="$d/shim:$PATH" TMPDIR="$d/s" "$@" >/dev/null 2>&1) || b=$?
  for e in "$d/n/${tool}".*; do
    if [ -e "$e" ]; then nn=$((nn + 1)); fi
  done
  for e in "$d/s/${tool}".*; do
    if [ -e "$e" ]; then ns=$((ns + 1)); fi
  done
  if [ "$a" = "$b" ] && [ "$ns" -eq 1 ]; then
    pass "T-1165: ${tool}.sh exit status survives a failed rmdir"
  else
    fail "T-1165: ${tool}.sh exit status survives a failed rmdir (plain rc=$a, shimmed rc=$b, shimmed leftovers=$ns)"
  fi
  if [ "$nn" -eq 0 ]; then
    pass "T-1165: ${tool}.sh leaves no scratch directory"
  else
    fail "T-1165: ${tool}.sh leaves no scratch directory (plain run left $nn)"
  fi
}
t1165_rmdir_case check-review-input bash "$SCRIPT" --record "$T/hostile.md" --task T-000

# =============================================================================
# T-1192 (issues #755/#756): the OPTIONAL sixth per-pass field codex-model.
#   codex-model (<pass>): requested=<token> — observed=<token>
# Validated if present, forward-only (a record without it is unchanged).
# Refusal order: duplicate, vocabulary, mismatch, contradiction. Nothing a
# refusal prints carries a field's bytes.
# =============================================================================
cm_hdr() { printf '## Codex review\n\n### Codex Review verdict: APPROVE\n- Task: T-000\n'; }
# cm_rec FILE INVOCATION [EXTRA LINE...] — one pass p1 whose four fields use
# INVOCATION as the executor-invocation value, then the extra lines verbatim.
cm_rec() {
  local f="$1" e="$2" l
  shift 2
  {
    cm_hdr
    printf '  - executor-invocation (p1): %s\n  - pass-role (p1): generation\n  - briefing-fidelity (p1): carried - scope stated in the argv\n  - raw-capture (p1): T-000-codex-primary\n' "$e"
    for l in "$@"; do printf '%s\n' "$l"; done
  } > "$f"
}
cm_line() { printf '  - codex-model (p1): requested=%s — observed=%s' "$1" "$2"; }
CM_BARE='codex exec --sandbox read-only review --base develop'
CM_PIN='codex exec -m zq-model-1 --sandbox read-only review --base develop'
CM_BT='`'

cm_rec "$T/cm-0.md" "$CM_BARE"
assert_case "codex-model: no line at all stays conformant (forward-only)" 0 "" -- bash "$SCRIPT" --record "$T/cm-0.md" --task T-000
cm_rec "$T/cm-1.md" "$CM_BARE" "$(cm_line provider-configured zq-model-1)"
assert_case "codex-model: provider-configured with an observed model is report-only" 0 "" -- bash "$SCRIPT" --record "$T/cm-1.md" --task T-000
cm_rec "$T/cm-2.md" "$CM_BARE" "$(cm_line provider-configured unavailable)"
assert_case "codex-model: provider-configured with observed unavailable" 0 "" -- bash "$SCRIPT" --record "$T/cm-2.md" --task T-000
cm_rec "$T/cm-3.md" "$CM_PIN" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: named model observed equal, invocation carries -m" 0 "" -- bash "$SCRIPT" --record "$T/cm-3.md" --task T-000
cm_rec "$T/cm-3b.md" "  $CM_PIN" '  - codex-model (p1):    requested=zq-model-1 — observed=zq-model-1'
assert_case "codex-model: leading whitespace on both values is tolerated" 0 "" -- bash "$SCRIPT" --record "$T/cm-3b.md" --task T-000
cm_rec "$T/cm-3c.md" "$CM_BT$CM_PIN$CM_BT" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a backtick-wrapped invocation with matching -m is conformant" 0 "" -- bash "$SCRIPT" --record "$T/cm-3c.md" --task T-000
cm_rec "$T/cm-3d.md" "${CM_BT}codex exec -m zq-model-1${CM_BT}" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: -m <requested> as the last token inside the backticks is conformant" 0 "" -- bash "$SCRIPT" --record "$T/cm-3d.md" --task T-000
cm_rec "$T/cm-3e.md" "claude -p --prompt-file p.txt" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a claude -p invocation is never refused by the contradiction rule" 0 "" -- bash "$SCRIPT" --record "$T/cm-3e.md" --task T-000
cm_rec "$T/cm-3f.md" "claude -p codex exec --prompt-file p.txt" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a prompt that merely mentions codex exec is not a codex exec invocation" 0 "" -- bash "$SCRIPT" --record "$T/cm-3f.md" --task T-000

for v in zq-model-2 unavailable zq-model-1x; do
  cm_rec "$T/cm-m-$v.md" "$CM_PIN" "$(cm_line zq-model-1 "$v")"
  assert_case "codex-model: requested zq-model-1 observed $v refuses codex-model-mismatch" 1 codex-model-mismatch -- bash "$SCRIPT" --record "$T/cm-m-$v.md" --task T-000
  out="$(bash "$SCRIPT" --record "$T/cm-m-$v.md" --task T-000 2>&1 || true)"
  [ -n "$out" ] || fail "codex-model: the mismatch refusal printed nothing (the no-echo probe would be vacuous)"
  if printf '%s' "$out" | grep -qF -- "$v"; then fail "codex-model: the mismatch refusal echoed the observed value ($v)"; fi
  pass "codex-model: the mismatch refusal never echoes the observed value ($v)"
done
cm_rec "$T/cm-m-prefix.md" "codex exec -m zq-model-1x --sandbox read-only review" "$(cm_line zq-model-1x zq-model-1)"
assert_case "codex-model: a prefix near-miss in the other direction also refuses codex-model-mismatch" 1 codex-model-mismatch -- bash "$SCRIPT" --record "$T/cm-m-prefix.md" --task T-000

cm_rec "$T/cm-v1.md" "$CM_PIN" '  - codex-model (p1): requested=zq-model-1 observed=zq-model-1'
assert_case "codex-model: no separator refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v1.md" --task T-000
cm_rec "$T/cm-v2.md" "$CM_PIN" "$(cm_line 'zq model' zq-model-1)"
assert_case "codex-model: a requested token with a space refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v2.md" --task T-000
cm_rec "$T/cm-v3.md" "$CM_PIN" "$(cm_line zq-model-1 '')"
assert_case "codex-model: an empty observed value refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v3.md" --task T-000
cm_rec "$T/cm-v4.md" "$CM_PIN" "$(cm_line zq-model-1 'zq-model-1;x')"
assert_case "codex-model: an observed token outside the token shape refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v4.md" --task T-000
cm_rec "$T/cm-v5.md" "$CM_PIN" '  - codex-model (p1): zq-model-1 — zq-model-1'
assert_case "codex-model: missing requested=/observed= labels refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v5.md" --task T-000
cm_rec "$T/cm-v6.md" "$CM_PIN" "$(cm_line zq-model-1 zq-model-1) "
assert_case "codex-model: trailing whitespace after observed refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v6.md" --task T-000
cm_rec "$T/cm-v7.md" "$CM_PIN" "$(cm_line zq-model-1 zq-model-1) — observed=zq-model-1"
assert_case "codex-model: a second separator inside the observed value refuses codex-model-vocabulary" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v7.md" --task T-000
cm_rec "$T/cm-v8.md" "$CM_PIN" "$(cm_line provider-configured-x zq-model-1)"
assert_case "codex-model: a token that merely begins with provider-configured is a named model" 1 codex-model-mismatch -- bash "$SCRIPT" --record "$T/cm-v8.md" --task T-000
cm_rec "$T/cm-v10.md" "$CM_PIN" '  - codex-model (p1): requested=zq-model-1 observed=zq-model-2'
assert_case "codex-model: a malformed line whose tokens would mismatch refuses vocabulary, not mismatch" 1 codex-model-vocabulary -- bash "$SCRIPT" --record "$T/cm-v10.md" --task T-000

cm_rec "$T/cm-d1.md" "$CM_PIN" "$(cm_line zq-model-1 zq-model-1)" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: two lines for one pass refuse codex-model-duplicate" 1 codex-model-duplicate -- bash "$SCRIPT" --record "$T/cm-d1.md" --task T-000
cm_rec "$T/cm-d2.md" "$CM_BARE" "$(cm_line zq-model-1 zq-model-2)" '  - codex-model (p1): requested=zq-model-1 observed=zq-model-1'
assert_case "codex-model: duplicate wins over mismatch, vocabulary and contradiction" 1 codex-model-duplicate -- bash "$SCRIPT" --record "$T/cm-d2.md" --task T-000

cm_rec "$T/cm-c1.md" "$CM_BARE" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a named model beside an invocation with no -m refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c1.md" --task T-000
cm_rec "$T/cm-c2.md" "$CM_PIN" "$(cm_line provider-configured zq-model-1)"
assert_case "codex-model: provider-configured beside an invocation carrying -m refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c2.md" --task T-000
cm_rec "$T/cm-c3.md" "${CM_BT}codex exec -m zq-model-2 --sandbox read-only review --base develop${CM_BT}" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a backtick-wrapped -m naming another model refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c3.md" --task T-000
cm_rec "$T/cm-c4.md" "codex exec --sandbox read-only -m zq-model-1 review --base develop" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: -m not immediately after codex exec refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c4.md" --task T-000
cm_rec "$T/cm-c5.md" "codex exec -m zq-model-1x --sandbox read-only review" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: -m naming a prefix near-miss of the requested model refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c5.md" --task T-000
cm_rec "$T/cm-c6.md" "codex exec" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-model: a bare codex exec invocation beside a named model refuses codex-model-contradiction" 1 codex-model-contradiction -- bash "$SCRIPT" --record "$T/cm-c6.md" --task T-000

# A pass declared ONLY by a codex-model line is still field-missing (the field
# joins FIELD_RE like self-detected-host did; the four-field test is unchanged).
{ cm_hdr; cm_line zq-model-1 zq-model-1; printf '\n'; } > "$T/cm-only.md"
assert_case "codex-model: a pass declared only by codex-model refuses field-missing" 1 field-missing -- bash "$SCRIPT" --record "$T/cm-only.md" --task T-000

# =============================================================================
# T-1195 (issue #757): the SEVENTH per-pass field codex-effort.
#   codex-effort (<pass>): requested=<token> — observed=<token>
# Optional for an invocation without the effort clause; REQUIRED when a
# `codex exec` invocation carries `-c model_reasoning_effort=<e>`. Refusal order:
# duplicate, vocabulary, mismatch, contradiction. Nothing a refusal prints
# carries a field's bytes.
# =============================================================================
ce_line() { printf '  - codex-effort (p1): requested=%s — observed=%s' "$1" "$2"; }
CE_CLAUSE='codex exec -c model_reasoning_effort=zq-eff-a --sandbox read-only review --base develop'
CE_CLAUSE_B='codex exec -c model_reasoning_effort=zq-eff-b --sandbox read-only review --base develop'
CE_CLAUSE_M='codex exec -m zq-model-1 -c model_reasoning_effort=zq-eff-a --sandbox read-only review --base develop'

cm_rec "$T/ce-0.md" "$CM_BARE"
assert_case "codex-effort: no line beside a clause-free invocation stays conformant (forward-only)" 0 "" -- bash "$SCRIPT" --record "$T/ce-0.md" --task T-000
cm_rec "$T/ce-1.md" "$CM_BARE" "$(ce_line - zq-eff-a)"
assert_case "codex-effort: requested - with an observed effort is report-only" 0 "" -- bash "$SCRIPT" --record "$T/ce-1.md" --task T-000
cm_rec "$T/ce-2.md" "$CM_BARE" "$(ce_line - unavailable)"
assert_case "codex-effort: requested - with observed unavailable" 0 "" -- bash "$SCRIPT" --record "$T/ce-2.md" --task T-000
cm_rec "$T/ce-3.md" "$CE_CLAUSE" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a named effort observed equal, invocation carries the clause after codex exec" 0 "" -- bash "$SCRIPT" --record "$T/ce-3.md" --task T-000
cm_rec "$T/ce-3b.md" "$CE_CLAUSE_M" "$(cm_line zq-model-1 zq-model-1)" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: the clause right after -m <model> is conformant beside a conformant codex-model line" 0 "" -- bash "$SCRIPT" --record "$T/ce-3b.md" --task T-000
cm_rec "$T/ce-3c.md" "${CM_BT}${CE_CLAUSE_M}${CM_BT}" "$(cm_line zq-model-1 zq-model-1)" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a backtick-wrapped invocation with the clause is conformant" 0 "" -- bash "$SCRIPT" --record "$T/ce-3c.md" --task T-000
cm_rec "$T/ce-3e.md" "${CM_BT}codex exec --sandbox read-only review --base develop -c model_reasoning_effort=zq-eff-a${CM_BT}" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a backtick-wrapped invocation carrying the clause at the end (not right after codex exec) refuses by the position rule" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-3e.md" --task T-000
cm_rec "$T/ce-3f.md" "${CM_BT}codex exec -c model_reasoning_effort=zq-eff-a${CM_BT}" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a backtick-wrapped invocation ending exactly at the clause value is conformant (the trailing backtick is stripped from the last token)" 0 "" -- bash "$SCRIPT" --record "$T/ce-3f.md" --task T-000
cm_rec "$T/ce-3d.md" "claude -p --prompt-file p.txt" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a claude -p invocation beside a named effort is never refused by the contradiction rule" 0 "" -- bash "$SCRIPT" --record "$T/ce-3d.md" --task T-000

for v in zq-eff-b unavailable zq-eff-ax; do
  cm_rec "$T/ce-m-$v.md" "$CE_CLAUSE" "$(ce_line zq-eff-a "$v")"
  assert_case "codex-effort: requested zq-eff-a observed $v refuses codex-effort-mismatch" 1 codex-effort-mismatch -- bash "$SCRIPT" --record "$T/ce-m-$v.md" --task T-000
  out="$(bash "$SCRIPT" --record "$T/ce-m-$v.md" --task T-000 2>&1 || true)"
  [ -n "$out" ] || fail "codex-effort: the mismatch refusal printed nothing (the no-echo probe would be vacuous)"
  if printf '%s' "$out" | grep -qF -- "$v"; then fail "codex-effort: the mismatch refusal echoed the observed value ($v)"; fi
  pass "codex-effort: the mismatch refusal never echoes the observed value ($v)"
done

cm_rec "$T/ce-v1.md" "$CE_CLAUSE" '  - codex-effort (p1): requested=zq-eff-a observed=zq-eff-a'
assert_case "codex-effort: no separator refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v1.md" --task T-000
cm_rec "$T/ce-v2.md" "$CE_CLAUSE" "$(ce_line Zq-Eff zq-eff-a)"
assert_case "codex-effort: an uppercase requested token refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v2.md" --task T-000
cm_rec "$T/ce-v2b.md" "$CE_CLAUSE" "$(ce_line zq-Eff zq-eff-a)"
assert_case "codex-effort: an uppercase byte after a lowercase first byte in requested refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v2b.md" --task T-000
cm_rec "$T/ce-v2c.md" "$CE_CLAUSE" "$(ce_line zq-eff-a zq-Eff)"
assert_case "codex-effort: an uppercase byte after a lowercase first byte in observed refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v2c.md" --task T-000
cm_rec "$T/ce-v2d.md" "$CE_CLAUSE" "$(ce_line zq-eff-a 'zq;eff')"
assert_case "codex-effort: a punctuation byte inside observed refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v2d.md" --task T-000
cm_rec "$T/ce-v3.md" "$CE_CLAUSE" "$(ce_line zq-eff-a '')"
assert_case "codex-effort: an empty observed value refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v3.md" --task T-000
cm_rec "$T/ce-v4.md" "$CM_BARE" "$(ce_line - -)"
assert_case "codex-effort: observed - refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v4.md" --task T-000
cm_rec "$T/ce-v5.md" "$CM_BARE" "$(ce_line 1zq zq-eff-a)"
assert_case "codex-effort: a requested token starting with a digit refuses codex-effort-vocabulary" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v5.md" --task T-000
cm_rec "$T/ce-v6.md" "$CE_CLAUSE" '  - codex-effort (p1): requested=zq-eff-a observed=zq-eff-b'
assert_case "codex-effort: a malformed line whose tokens would mismatch refuses vocabulary, not mismatch" 1 codex-effort-vocabulary -- bash "$SCRIPT" --record "$T/ce-v6.md" --task T-000

cm_rec "$T/ce-d1.md" "$CE_CLAUSE" "$(ce_line zq-eff-a zq-eff-a)" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: two lines for one pass refuse codex-effort-duplicate" 1 codex-effort-duplicate -- bash "$SCRIPT" --record "$T/ce-d1.md" --task T-000

cm_rec "$T/ce-s1.md" "$CE_CLAUSE"
assert_case "codex-effort: the clause with no codex-effort line refuses codex-effort-missing" 1 codex-effort-missing -- bash "$SCRIPT" --record "$T/ce-s1.md" --task T-000
cm_rec "$T/ce-s2.md" "$CE_CLAUSE_M" "$(cm_line zq-model-1 zq-model-1)"
assert_case "codex-effort: the clause after -m with no codex-effort line refuses codex-effort-missing" 1 codex-effort-missing -- bash "$SCRIPT" --record "$T/ce-s2.md" --task T-000
cm_rec "$T/ce-s3.md" "${CM_BT}${CE_CLAUSE}${CM_BT}"
assert_case "codex-effort: a backtick-wrapped invocation with the clause and no line refuses codex-effort-missing" 1 codex-effort-missing -- bash "$SCRIPT" --record "$T/ce-s3.md" --task T-000
cm_rec "$T/ce-s4.md" "codex exec --sandbox read-only -c model_reasoning_effort=zq-eff-a review --base develop"
assert_case "codex-effort: the clause anywhere in the invocation (not only at the required position) with no line refuses codex-effort-missing" 1 codex-effort-missing -- bash "$SCRIPT" --record "$T/ce-s4.md" --task T-000
cm_rec "$T/ce-s5.md" "claude -p --prompt-file p.txt -c model_reasoning_effort=zq-eff-a"
assert_case "codex-effort: a non-codex-exec invocation that merely mentions the clause is not required to carry a line" 0 "" -- bash "$SCRIPT" --record "$T/ce-s5.md" --task T-000

cm_rec "$T/ce-c1.md" "$CM_BARE" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a named effort beside an invocation without -c refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c1.md" --task T-000
cm_rec "$T/ce-c2.md" "$CE_CLAUSE" "$(ce_line - zq-eff-a)"
assert_case "codex-effort: requested - beside an invocation carrying the clause refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c2.md" --task T-000
cm_rec "$T/ce-c3.md" "$CE_CLAUSE_B" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: the clause naming another effort refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c3.md" --task T-000
cm_rec "$T/ce-c4.md" "${CM_BT}codex exec -m zq-model-1 -c model_reasoning_effort=zq-eff-b --sandbox read-only review --base develop${CM_BT}" "$(cm_line zq-model-1 zq-model-1)" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a backtick-wrapped invocation naming another effort after -m refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c4.md" --task T-000
cm_rec "$T/ce-c5.md" "codex exec -m zq-model-1 --sandbox read-only -c model_reasoning_effort=zq-eff-a review --base develop" "$(cm_line zq-model-1 zq-model-1)" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: another option between -m <model> and the clause refuses codex-effort-contradiction (position rule alone)" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c5.md" --task T-000
cm_rec "$T/ce-c6.md" "codex exec -m zq-model-1 --sandbox read-only -c model_reasoning_effort=zq-eff-a review --base develop" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: the position rule alone, with no codex-model line" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c6.md" --task T-000
cm_rec "$T/ce-c7.md" "codex exec -c model_reasoning_effort=zq-eff-ax --sandbox read-only review --base develop" "$(ce_line zq-eff-a zq-eff-a)"
assert_case "codex-effort: a clause naming a prefix near-miss of the requested effort refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c7.md" --task T-000
cm_rec "$T/ce-c8.md" "codex exec -m zq-model-1 -c model_reasoning_effort=zq-eff-a --sandbox read-only review --base develop" "$(cm_line zq-model-1 zq-model-1)" "$(ce_line - unavailable)"
assert_case "codex-effort: under - a clause after -m refuses codex-effort-contradiction" 1 codex-effort-contradiction -- bash "$SCRIPT" --record "$T/ce-c8.md" --task T-000

# A pass declared ONLY by a codex-effort line is still field-missing.
{ cm_hdr; ce_line zq-eff-a zq-eff-a; printf '\n'; } > "$T/ce-only.md"
assert_case "codex-effort: a pass declared only by codex-effort refuses field-missing" 1 field-missing -- bash "$SCRIPT" --record "$T/ce-only.md" --task T-000

printf '\nAll check-review-input assertions passed.\n'
