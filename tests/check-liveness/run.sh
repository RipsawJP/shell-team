#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-liveness.sh (T-1056's fail-closed,
# out-of-band loop-liveness classifier; GitHub issue #227;
# .shell-team/specs/T-1056-loop-liveness.md).
#
# .shell-team/specs/T-1056-loop-liveness.md's own `- check:` lines exercise
# every acceptance criterion directly against this script; this suite is a
# second, independently-authored surface (the repository's standing
# convention: check-binding.sh, check-adapter.sh and others each carry one)
# covering every verdict, every one of the closed 19 refusal tokens, and
# adversarial fixtures beyond the frozen criteria's own coverage — boundary
# arithmetic, regex/character-set anchoring on the declaration grammar and
# the --task shape, and "did this really run" positive controls beside every
# mutation.
#
# No git init scratch repositories are built here (a deliberate departure
# from a suggestion in the spec's own Notes for engineer — recorded in this
# task's provenance file): every git-band case instead measures THIS
# checkout's own real HEAD committer epoch live, at run time, and derives
# $LIVENESS_NOW relative to it — which reaches every git band exactly as
# well as a scratch repository would, without the sandboxed nested-.git
# write restriction this repository's test-recipe already documents
# (T-1001's entry). The declaration/state-file scratch fixtures still live
# under a plain (non-git) $TMP.
#
# Case ids (grouped; searched by `check-acs.sh`'s AC15 for the five verdict
# tokens and by this file's own token-presence for all 19 refusal tokens —
# `unclassified` is the one token this suite documents rather than reaches
# behaviourally: it is the script's own internal fall-through backstop,
# unreachable through any CLI input, and AC19(a)'s producer-run mutation
# self-check is what actually proves it fires):
#
#   cl-help-sane, cl-ci-wiring                    — static/CI sanity
#   cl-no-eval-source-static, cl-emit-count-static,
#   cl-sibling-name-static                        — structural self-checks
#   cl-running*, cl-stalled*, cl-dead*             — ladder + boundaries
#   cl-waiting*                                    — categorical, non-git-safe
#   cl-superseded*                                 — falls through, not an error
#   cl-decl-*                                      — the closed declaration
#                                                     refusal vocabulary
#   cl-registry-*                                  — plugin-shipped, decoy-proof
#   cl-clock-*, cl-threshold-*, cl-usage-*,
#   cl-state-*, cl-git-unreadable, cl-out-*        — the rest of the 19 tokens
#   cl-readonly-inputs, cl-canary-*                 — read-only + no-eval proof
#   cl-task-*                                       — --task composition/shape

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-liveness.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/check-handoff.yml"

if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/check-liveness-fixtures.XXXXXX")"
else
  TMP="$(mktemp -d "$HERE/tmp-roots.XXXXXX")"
fi
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

OUT_FILE="$TMP/.stdout"
ERR_FILE="$TMP/.stderr"
CL_RC=0

# call_cl_in <cwd> <LIVENESS_NOW|''> <checker args...> — runs the real
# checker with cwd set to <cwd> (so its internal `git` calls resolve against
# THAT directory), captures stdout/stderr into the shared files, and leaves
# the exit code in $CL_RC. `set +e`/`set -e` bracket the call so a non-zero
# exit never aborts this suite (T-1024's guard idiom).
call_cl_in() {
  local cwd="$1" now="$2"
  shift 2
  set +e
  if [ -n "$now" ]; then
    ( cd "$cwd" && LIVENESS_NOW="$now" bash "$CHECKER" "$@" > "$OUT_FILE" 2> "$ERR_FILE" )
  else
    ( cd "$cwd" && bash "$CHECKER" "$@" > "$OUT_FILE" 2> "$ERR_FILE" )
  fi
  CL_RC=$?
  set -e
}

# call_cl <LIVENESS_NOW|''> <checker args...> — the common case: run from
# THIS repository's own root, so ladder cases resolve against its real HEAD.
call_cl() {
  local now="$1"
  shift
  call_cl_in "$REPO_ROOT" "$now" "$@"
}

# assert_verdict <id> <want-exit> <want-token> — checks $CL_RC and that
# $OUT_FILE is EXACTLY one line carrying the bare token (never a substring
# match — DP1's "byte equality, not a substring search").
assert_verdict() {
  local id="$1" want_rc="$2" want_token="$3"
  [ "$CL_RC" = "$want_rc" ] \
    || fail "$id: expected exit $want_rc, got $CL_RC (stdout=$(cat "$OUT_FILE" 2>/dev/null); stderr=$(cat "$ERR_FILE" 2>/dev/null))"
  grep -qxF -- "$want_token" "$OUT_FILE" \
    || fail "$id: expected stdout exactly '$want_token', got: $(cat "$OUT_FILE" 2>/dev/null)"
  [ "$(grep -c . "$OUT_FILE" 2>/dev/null || true)" = "1" ] \
    || fail "$id: stdout carried other than exactly one line"
  pass "$id"
}

assert_stderr_has() {  # <id> <substring>
  grep -q -- "$2" "$ERR_FILE" \
    || fail "$1: expected stderr to contain '$2', got: $(cat "$ERR_FILE" 2>/dev/null)"
}

# assert_refusal <id> <reason-token> — the OBSERVE_ERROR shape: exit 2, stdout
# exactly OBSERVE_ERROR, stderr names the reason token.
assert_refusal() {
  assert_verdict "$1" 2 OBSERVE_ERROR
  assert_stderr_has "$1" "$2"
}

# mk_state <path> <start_epoch> — a well-formed /goal state file.
mk_state() {
  printf 'start_epoch=%s\niteration=4\nprev_sig=\n' "$2" > "$1"
}

# state_mtime <path> — portable mtime read (GNU then BSD; this suite's own
# copy of the same fallback the checker itself carries).
state_mtime() {
  stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null
}

# mk_decl <path> <task> <reason> <run-epoch> <declared-epoch> — a well-formed
# human-gate declaration.
mk_decl() {
  printf '%s\n' 'gate-declaration 1' "task $2" "reason $3" "run-epoch $4" "declared-epoch $5" 'gate-declaration-end' > "$1"
}

# =============================================================================
# --help sanity (AC3 / AC8's own machine-readable requirements, independently
# re-derived here)
# =============================================================================
h="$TMP/help.txt"
bash "$CHECKER" --help > "$h" 2>&1 || fail "cl-help-sane: --help did not exit 0"
[ -s "$h" ] || fail "cl-help-sane: --help produced no output"
for t in RUNNING WAITING STALLED DEAD OBSERVE_ERROR; do
  grep -qF -- "$t" "$h" || fail "cl-help-sane: --help does not name $t"
done
grep -qF -- 'exit 1' "$h" || fail "cl-help-sane: --help does not carry the literal 'exit 1'"
grep -qF -- 'no verdict' "$h" || fail "cl-help-sane: --help does not carry the literal 'no verdict'"
grep -qxE '  default stall-after: [0-9]{1,9}' "$h" || fail "cl-help-sane: --help missing the exact 'default stall-after: <n>' line"
grep -qxE '  default dead-after: [0-9]{1,9}' "$h" || fail "cl-help-sane: --help missing the exact 'default dead-after: <n>' line"
pass "cl-help-sane"

# =============================================================================
# CI wiring self-assertion
# =============================================================================
[ -r "$WORKFLOW" ] || fail "cl-ci-wiring: cannot read $WORKFLOW"
grep -qF -- 'bin/check-liveness.sh' "$WORKFLOW" || fail "cl-ci-wiring: check-handoff.yml does not name bin/check-liveness.sh"
grep -qF -- 'tests/check-liveness/run.sh' "$WORKFLOW" || fail "cl-ci-wiring: check-handoff.yml does not name tests/check-liveness/run.sh"
grep -qF -- 'bash tests/check-liveness/run.sh' "$WORKFLOW" || fail "cl-ci-wiring: check-handoff.yml carries no suite-run step"
grep -qE 'bin/check-liveness\.sh --help' "$WORKFLOW" || fail "cl-ci-wiring: check-handoff.yml carries no --help dogfood step"
pass "cl-ci-wiring"

# =============================================================================
# structural self-checks (independent copies of AC1/AC4/AC7/AC10's static clauses)
# =============================================================================
[ "$(grep -cE '(^|[;&|(]|\$\()[[:space:]]*(jq|python3|python|perl|node|yq|curl|wget|gh|osascript|mail|sendmail)([[:space:]]|$)' "$CHECKER" || true)" = "0" ] \
  || fail "cl-no-interpreter-static: an interpreter/transport appears in command position"
pass "cl-no-interpreter-static"

[ "$(grep -cE '(^|[;&|(])[[:space:]]*eval([[:space:]]|$)' "$CHECKER" || true)" = "0" ] \
  || fail "cl-no-eval-source-static: eval appears in command position"
[ "$(grep -cE '(^|[;&|(])[[:space:]]*(source|\.)[[:space:]]' "$CHECKER" || true)" = "0" ] \
  || fail "cl-no-eval-source-static: source/. appears in command position"
pass "cl-no-eval-source-static"

[ "$(grep -cE '(emit|verdict|printf)[^#]*RUNNING' "$CHECKER" || true)" = "1" ] \
  || fail "cl-emit-count-static: RUNNING is not emitted from exactly one site"
pass "cl-emit-count-static"

sib_bad=0
for p in $(git -C "$REPO_ROOT" ls-tree -r --name-only HEAD bin/ | sed -n 's#^bin/##p'); do
  case "$p" in
    team-paths.sh) continue ;;
    *.sh) ;;
    *) continue ;;
  esac
  n="$(grep -cF -- "$p" "$CHECKER" || true)"
  [ "$n" = "0" ] || { sib_bad=1; printf 'cl-sibling-name-static: %s appears %s time(s) in %s\n' "$p" "$n" "$CHECKER" >&2; }
done
[ "$sib_bad" = "0" ] || fail "cl-sibling-name-static: a sibling bin/*.sh filename other than team-paths.sh is named"
grep -qF -- 'team-paths.sh' "$CHECKER" || fail "cl-sibling-name-static: team-paths.sh is never named (would make the sibling clause vacuous)"
pass "cl-sibling-name-static"

# =============================================================================
# RUNNING: the positive-evidence cell, plus boundary
# =============================================================================
n0="$(date +%s)"
S="$TMP/s"; mk_state "$S" "$((n0 - 600))"
MT="$(state_mtime "$S")"

call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-running 0 RUNNING

call_cl "$((MT + 899))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-running-boundary-under-stall 0 RUNNING

call_cl "$((MT + 901))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-stalled-boundary-over-stall 4 STALLED

call_cl "$((MT + 3600))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-stalled-boundary-at-dead 4 STALLED

# =============================================================================
# STALLED via S2xG0 and DEAD via S2xG1 — measured against THIS checkout's
# own real HEAD, live, rather than a scratch git repository (see this file's
# header note and the provenance file for why).
# =============================================================================
HC="$(git -C "$REPO_ROOT" log -1 --format=%ct HEAD)"
OLD="$TMP/old"
mk_state "$OLD" "946684800"
touch -t 200001010000 "$OLD"
OM="$(state_mtime "$OLD")"
[ "$((HC - OM))" -gt 31536000 ] || fail "cl-stalled-s2g0: fixture precondition failed (backdated file is not >1 year behind HEAD)"

call_cl "$((HC + 60))" --state "$OLD" --declaration "$TMP/none"
assert_verdict cl-stalled-s2g0 4 STALLED

call_cl "$((HC + 100000))" --state "$OLD" --declaration "$TMP/none"
assert_verdict cl-dead-s2g1 5 DEAD

# =============================================================================
# threshold overrides move both boundaries
# =============================================================================
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 5 --dead-after 100000
assert_verdict cl-threshold-override-stalled 4 STALLED

call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 100 --dead-after 200
assert_verdict cl-threshold-override-running 0 RUNNING

call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 0900 --dead-after 3600
assert_verdict cl-threshold-leading-zero-running 0 RUNNING

call_cl "$((MT + 901))" --state "$S" --declaration "$TMP/none" --stall-after 0900 --dead-after 3600
assert_verdict cl-threshold-leading-zero-stalled 4 STALLED

# =============================================================================
# WAITING — categorical, outranks every stillness band, needs no git
# =============================================================================
D_FRESH="$TMP/d-fresh"
mk_decl "$D_FRESH" "T-901" "merge-go" "$((n0 - 600))" "$((MT + 10))"

for now_off in 30 1200 100000; do
  call_cl "$((MT + now_off))" --state "$S" --declaration "$D_FRESH"
  assert_verdict "cl-waiting-band-$now_off" 3 WAITING
done

# positive control: same three clocks, declaration ABSENT — attributable to the declaration
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-waiting-control-running 0 RUNNING
call_cl "$((MT + 1200))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-waiting-control-stalled 4 STALLED
call_cl "$((MT + 100000))" --state "$S" --declaration "$TMP/none"
assert_verdict cl-waiting-control-dead 5 DEAD

mkdir -p "$TMP/nogit"
if git -C "$TMP/nogit" rev-parse --show-toplevel >/dev/null 2>&1; then
  fail "cl-waiting-nogit: fixture precondition failed ($TMP/nogit is inside a git repository)"
fi
call_cl_in "$TMP/nogit" "$((MT + 30))" --state "$S" --declaration "$D_FRESH"
assert_verdict cl-waiting-nogit 3 WAITING

call_cl_in "$TMP/nogit" "$((MT + 30))" --state "$S" --declaration "$TMP/none"
assert_refusal cl-git-unreadable git-unreadable

# =============================================================================
# superseded — falls through to the ladder, never WAITING, never an error
# =============================================================================
D_SUP="$TMP/d-sup"
mk_decl "$D_SUP" "T-901" "merge-go" "$((n0 - 600))" "$((MT - 100))"
call_cl "$((MT + 30))" --state "$S" --declaration "$D_SUP"
assert_verdict cl-superseded-running 0 RUNNING
assert_stderr_has cl-superseded-running-context declaration-superseded

call_cl "$((MT + 1200))" --state "$S" --declaration "$D_SUP"
assert_verdict cl-superseded-stalled 4 STALLED
assert_stderr_has cl-superseded-stalled-context declaration-superseded

# =============================================================================
# the declaration refusal vocabulary — each mutation proved to differ from
# the unmutated base before being judged (T-1001's tolerance-proof discipline)
# =============================================================================
D_BASE="$TMP/d-base"
mk_decl "$D_BASE" "T-901" "merge-go" "$((n0 - 600))" "$((MT + 10))"
call_cl "$((MT + 30))" --state "$S" --declaration "$D_BASE"
assert_verdict cl-decl-base-control 3 WAITING

mut() {  # <id> <reason-token> <mutated-file>
  cmp -s "$D_BASE" "$3" && fail "$1: mutated fixture is byte-identical to the base (mutation did not apply)"
  call_cl "$((MT + 30))" --state "$S" --declaration "$3"
  assert_refusal "$1" "$2"
}

C="$TMP/c1"; grep -v '^gate-declaration-end$' "$D_BASE" > "$C"
mut cl-decl-unterminated declaration-unterminated "$C"

C="$TMP/c2"; grep -v '^gate-declaration 1$' "$D_BASE" > "$C"
mut cl-decl-version-missing declaration-malformed "$C"

C="$TMP/c3"
{ grep -v '^gate-declaration 1$' "$D_BASE" | grep -v '^gate-declaration-end$'; printf '%s\n' 'gate-declaration 1' 'gate-declaration-end'; } > "$C"
mut cl-decl-version-moved declaration-malformed "$C"

C="$TMP/c4"; sed 's/^gate-declaration 1$/gate-declaration 9/' "$D_BASE" > "$C"
mut cl-decl-version-unsupported declaration-malformed "$C"

C="$TMP/c5"; grep -v '^task ' "$D_BASE" > "$C"
mut cl-decl-field-missing declaration-malformed "$C"

C="$TMP/c6"
{ head -n2 "$D_BASE"; sed -n '2p' "$D_BASE"; tail -n +3 "$D_BASE"; } > "$C"
mut cl-decl-field-duplicate declaration-malformed "$C"

C="$TMP/c7"
{ head -n5 "$D_BASE"; printf '%s\n' 'escalated yes'; tail -n1 "$D_BASE"; } > "$C"
mut cl-decl-unrecognized-directive declaration-malformed "$C"

C="$TMP/c8"; sed 's/^reason merge-go$/reason zz-not-a-reason/' "$D_BASE" > "$C"
mut cl-decl-unknown-reason declaration-unknown-reason "$C"

C="$TMP/c9"; sed 's/^reason merge-go$/reason MERGE-GO/' "$D_BASE" > "$C"
mut cl-decl-reason-shape-uppercase declaration-malformed "$C"

C="$TMP/c10"; sed "s/^run-epoch .*/run-epoch $((n0 - 599))/" "$D_BASE" > "$C"
mut cl-decl-foreign-run declaration-foreign-run "$C"

C="$TMP/c11"; sed "s/^declared-epoch .*/declared-epoch $((n0 - 601))/" "$D_BASE" > "$C"
mut cl-decl-precedes-run declaration-precedes-run "$C"

C="$TMP/c12"; cp "$D_BASE" "$C"; chmod 000 "$C"
call_cl "$((MT + 30))" --state "$S" --declaration "$C"
assert_refusal cl-decl-unreadable declaration-unreadable
chmod 644 "$C"

# =============================================================================
# the reason registry — plugin-shipped, resolved from the checker's own
# installed directory, decoy- and corruption-proof
# =============================================================================
grep -qF -- 'zz-decoy-reason' "$REPO_ROOT/templates/liveness-reasons.txt" && fail "cl-registry-decoy-ignored: fixture precondition failed (decoy token already in the real registry)"

DECOY_ROOT="$TMP/decoy"
mkdir -p "$DECOY_ROOT/templates"
printf '%s\n' 'zz-decoy-reason approval' > "$DECOY_ROOT/templates/liveness-reasons.txt"
[ -r "$DECOY_ROOT/templates/liveness-reasons.txt" ] || fail "cl-registry-decoy-ignored: decoy file not readable"
grep -q 'zz-decoy-reason' "$DECOY_ROOT/templates/liveness-reasons.txt" || fail "cl-registry-decoy-ignored: decoy file does not carry its own token"

D_DECOY="$TMP/d-decoy"
mk_decl "$D_DECOY" "T-901" "zz-decoy-reason" "$((n0 - 600))" "$((MT + 10))"
call_cl_in "$DECOY_ROOT" "$((MT + 30))" --state "$S" --declaration "$D_DECOY"
assert_refusal cl-registry-decoy-ignored declaration-unknown-reason

# a scratch "install" of the checker + its sibling resolver, so
# registry-unreadable/registry-malformed can be exercised against a
# corrupted registry without touching the real shipped one
SCRATCH="$TMP/scratch-install"
mkdir -p "$SCRATCH/bin" "$SCRATCH/templates"
cp "$CHECKER" "$SCRATCH/bin/check-liveness.sh"
cp "$REPO_ROOT/bin/team-paths.sh" "$SCRATCH/bin/team-paths.sh"
chmod 755 "$SCRATCH/bin/check-liveness.sh" "$SCRATCH/bin/team-paths.sh"

set +e
LIVENESS_NOW="$((MT + 30))" bash "$SCRATCH/bin/check-liveness.sh" --state "$S" --declaration "$D_BASE" > "$OUT_FILE" 2> "$ERR_FILE"
CL_RC=$?
set -e
assert_refusal cl-registry-unreadable registry-unreadable

printf '%s\n' 'onlyonetoken' > "$SCRATCH/templates/liveness-reasons.txt"
set +e
LIVENESS_NOW="$((MT + 30))" bash "$SCRATCH/bin/check-liveness.sh" --state "$S" --declaration "$D_BASE" > "$OUT_FILE" 2> "$ERR_FILE"
CL_RC=$?
set -e
assert_refusal cl-registry-malformed-wrong-field-count registry-malformed

printf '%s\n' 'merge-go approval' 'merge-go escalation' > "$SCRATCH/templates/liveness-reasons.txt"
set +e
LIVENESS_NOW="$((MT + 30))" bash "$SCRATCH/bin/check-liveness.sh" --state "$S" --declaration "$D_BASE" > "$OUT_FILE" 2> "$ERR_FILE"
CL_RC=$?
set -e
assert_refusal cl-registry-malformed-duplicate-token registry-malformed

# =============================================================================
# clock handling: $LIVENESS_NOW shape, and clock-skew in both directions
# =============================================================================
call_cl "zzz" --state "$S" --declaration "$TMP/none"
assert_refusal cl-clock-unreadable-nonnumeric clock-unreadable
call_cl "-1" --state "$S" --declaration "$TMP/none"
assert_refusal cl-clock-unreadable-negative clock-unreadable
call_cl "123456789012" --state "$S" --declaration "$TMP/none"
assert_refusal cl-clock-unreadable-overwide clock-unreadable

call_cl "$((MT - 5))" --state "$S" --declaration "$TMP/none"
assert_refusal cl-clock-skew-state clock-skew

call_cl "$((OM + 5))" --state "$OLD" --declaration "$TMP/none"
assert_refusal cl-clock-skew-git clock-skew

# =============================================================================
# thresholds: shape, order, boundary width
# =============================================================================
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 900 --dead-after 900
assert_refusal cl-threshold-order-equal threshold-order
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 900 --dead-after 100
assert_refusal cl-threshold-order-less threshold-order
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after abc --dead-after 3600
assert_refusal cl-threshold-invalid-nonnumeric threshold-invalid
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after -5 --dead-after 3600
assert_refusal cl-threshold-invalid-negative threshold-invalid
call_cl "$((MT + 30))" --state "$S" --declaration "$TMP/none" --stall-after 1234567890123 --dead-after 9999999999999
assert_refusal cl-threshold-invalid-overwide threshold-invalid

# =============================================================================
# usage: every rejected invocation shape
# =============================================================================
call_cl "" ; assert_refusal cl-usage-no-args usage
call_cl "" --state "$S" ; assert_refusal cl-usage-state-only usage
call_cl "" --declaration "$TMP/none" ; assert_refusal cl-usage-decl-only usage
call_cl "" --task T-901 --state "$S" ; assert_refusal cl-usage-task-plus-state usage
call_cl "" --task T-901 --declaration "$TMP/none" ; assert_refusal cl-usage-task-plus-decl usage
call_cl "" --task nope ; assert_refusal cl-usage-bad-task-shape usage
call_cl "" --task "T-" ; assert_refusal cl-usage-task-no-digits usage
call_cl "" --task "t-1" ; assert_refusal cl-usage-task-lowercase usage
call_cl "" --frobnicate ; assert_refusal cl-usage-unknown-flag usage
call_cl "" "$S" ; assert_refusal cl-usage-bare-positional usage

# --task with a valid, unusual (but shape-legal) digit run is ACCEPTED at the
# argument-shape layer — it fails later, on state-missing, never on usage.
TASK_ROOT="$TMP/task-root"
mkdir -p "$TASK_ROOT/.ops"
[ ! -d "$TASK_ROOT/.ops/runs" ] || fail "cl-task-id-leading-zero: fixture precondition failed (runs dir already exists)"
set +e
( cd "$TASK_ROOT" && TEAM_RUN_BASE=.ops LIVENESS_NOW=1000000000 bash "$CHECKER" --task T-0901 > "$OUT_FILE" 2> "$ERR_FILE" )
CL_RC=$?
set -e
assert_refusal cl-task-id-leading-zero state-missing
assert_stderr_has cl-task-id-leading-zero-composed-path '.ops/runs/goal-T-0901.state'

# =============================================================================
# --task composition: state-missing names the resolver-composed path, never
# a hardcoded literal (measured from a scratch root under TEAM_RUN_BASE)
# =============================================================================
set +e
( cd "$TASK_ROOT" && TEAM_RUN_BASE=.ops LIVENESS_NOW=1000000000 bash "$CHECKER" --task T-901 > "$OUT_FILE" 2> "$ERR_FILE" )
CL_RC=$?
set -e
assert_refusal cl-task-compose-state-missing state-missing
assert_stderr_has cl-task-compose-state-missing-path '.ops/runs/goal-T-901.state'

# =============================================================================
# state file refusals
# =============================================================================
call_cl "$((MT + 30))" --state "$TMP/does-not-exist" --declaration "$TMP/none"
assert_refusal cl-state-missing state-missing
assert_stderr_has cl-state-missing-names-path "$TMP/does-not-exist"

C="$TMP/s-unreadable"; cp "$S" "$C"; chmod 000 "$C"
call_cl "$((MT + 30))" --state "$C" --declaration "$TMP/none"
assert_refusal cl-state-unreadable state-unreadable
chmod 644 "$C"

C="$TMP/s-noepoch"; grep -v '^start_epoch=' "$S" > "$C"
call_cl "$((MT + 30))" --state "$C" --declaration "$TMP/none"
assert_refusal cl-state-malformed-no-start-epoch state-malformed

C="$TMP/s-badepoch"; sed 's/^start_epoch=.*/start_epoch=x9/' "$S" > "$C"
call_cl "$((MT + 30))" --state "$C" --declaration "$TMP/none"
assert_refusal cl-state-malformed-bad-start-epoch state-malformed

C="$TMP/s-baditer"; sed 's/^iteration=.*/iteration=y/' "$S" > "$C"
call_cl "$((MT + 30))" --state "$C" --declaration "$TMP/none"
assert_refusal cl-state-malformed-bad-iteration state-malformed

# =============================================================================
# --out: atomic, self-describing, replace semantics, symlink refusal, and
# leaves nothing behind when omitted
# =============================================================================
EMPTY="$TMP/out-empty"
mkdir -p "$EMPTY"
[ "$(find "$EMPTY" -mindepth 1 | grep -c . || true)" = "0" ] || fail "cl-out-none-no-sideeffect: fixture precondition failed (scratch dir not empty)"
call_cl_in "$EMPTY" "$((MT + 30))" --state "$S" --declaration "$TMP/none"
[ "$(find "$EMPTY" -mindepth 1 | grep -c . || true)" = "0" ] || fail "cl-out-none-no-sideeffect: a file appeared with no --out"
pass "cl-out-none-no-sideeffect"

V="$TMP/verdict.doc"
[ ! -e "$V" ] || fail "cl-out-shape: fixture precondition failed ($V already exists)"
call_cl "$((MT + 30))" --state "$S" --declaration "$D_BASE" --out "$V"
assert_verdict cl-out-shape-verdict 3 WAITING
[ -s "$V" ] || fail "cl-out-shape: --out document was not created"
head -n1 "$V" | grep -qxF 'liveness-verdict 1' || fail "cl-out-shape: missing version line"
grep -qxF 'verdict WAITING' "$V" || fail "cl-out-shape: missing verdict line"
for k in reason state-age git-age; do
  grep -qE "^$k " "$V" || fail "cl-out-shape: missing $k line"
done
tail -n1 "$V" | grep -qxF 'liveness-verdict-end' || fail "cl-out-shape: missing terminator"
pass "cl-out-shape"

call_cl "$((MT + 1200))" --state "$S" --declaration "$TMP/none" --out "$V"
assert_verdict cl-out-replace-verdict 4 STALLED
grep -qxF 'verdict STALLED' "$V" || fail "cl-out-replace: verdict not updated"
[ "$(grep -c '^verdict ' "$V" || true)" = "1" ] || fail "cl-out-replace: more than one verdict line after replace"
pass "cl-out-replace"

LINK="$TMP/out-link"; NOWHERE="$TMP/out-nowhere"
ln -s "$NOWHERE" "$LINK"
[ ! -e "$NOWHERE" ] || fail "cl-out-symlink-refused: fixture precondition failed (target unexpectedly exists)"
call_cl "$((MT + 30))" --state "$S" --declaration "$D_BASE" --out "$LINK"
assert_refusal cl-out-symlink-refused out-unwritable
[ ! -e "$NOWHERE" ] || fail "cl-out-symlink-refused: the symlink target was created (it must never be followed)"

# =============================================================================
# read-only proof: the state file's and the declaration's git-hash-object
# values are identical before and after every invocation above that read them
# =============================================================================
H_S_AFTER="$(git hash-object "$S")"
H_D_AFTER="$(git hash-object "$D_BASE")"
# recompute the ORIGINAL hashes independently (never trusted from memory) —
# the base fixtures were never rewritten above, so a fresh write with the
# same content must hash identically.
mk_state "$TMP/s-hash-check" "$((n0 - 600))"
H_S_EXPECT="$(git hash-object "$TMP/s-hash-check")"
mk_decl "$TMP/d-hash-check" "T-901" "merge-go" "$((n0 - 600))" "$((MT + 10))"
H_D_EXPECT="$(git hash-object "$TMP/d-hash-check")"
[ "$H_S_AFTER" = "$H_S_EXPECT" ] || fail "cl-readonly-inputs: the state file's content changed across this suite's invocations"
[ "$H_D_AFTER" = "$H_D_EXPECT" ] || fail "cl-readonly-inputs: the declaration file's content changed across this suite's invocations"
pass "cl-readonly-inputs"

# =============================================================================
# no-eval CANARY: a shell-metacharacter payload in a declaration or state
# field is refused, never executed
# =============================================================================
mkdir -p "$TMP/canary-cwd"
# The literal text $(>CANARY) below is the payload under test — it must NOT
# expand here; expanding it in THIS script would create the canary itself
# and invalidate the test.
C="$TMP/p1"
# shellcheck disable=SC2016
sed 's/^reason merge-go$/reason $(>CANARY)/' "$D_BASE" > "$C"
cmp -s "$D_BASE" "$C" && fail "cl-canary-dollar-paren: mutated fixture is byte-identical to the base"
set +e
( cd "$TMP/canary-cwd" && LIVENESS_NOW="$((MT + 30))" bash "$CHECKER" --state "$S" --declaration "$C" > "$OUT_FILE" 2> "$ERR_FILE" )
CL_RC=$?
set -e
assert_verdict cl-canary-dollar-paren 2 OBSERVE_ERROR
grep -qE 'declaration-(malformed|unknown-reason)' "$ERR_FILE" || fail "cl-canary-dollar-paren: unexpected refusal token"

C="$TMP/p2"; sed 's/^reason merge-go$/reason ;>CANARY;/' "$D_BASE" > "$C"
cmp -s "$D_BASE" "$C" && fail "cl-canary-semicolon: mutated fixture is byte-identical to the base"
set +e
( cd "$TMP/canary-cwd" && LIVENESS_NOW="$((MT + 30))" bash "$CHECKER" --state "$S" --declaration "$C" > "$OUT_FILE" 2> "$ERR_FILE" )
CL_RC=$?
set -e
assert_verdict cl-canary-semicolon 2 OBSERVE_ERROR
grep -qE 'declaration-(malformed|unknown-reason)' "$ERR_FILE" || fail "cl-canary-semicolon: unexpected refusal token"

C="$TMP/p3"
# shellcheck disable=SC2016
sed 's/^start_epoch=.*/start_epoch=$(>CANARY)/' "$S" > "$C"
cmp -s "$S" "$C" && fail "cl-canary-state: mutated fixture is byte-identical to the base"
set +e
( cd "$TMP/canary-cwd" && LIVENESS_NOW="$((MT + 30))" bash "$CHECKER" --state "$C" --declaration "$D_BASE" > "$OUT_FILE" 2> "$ERR_FILE" )
CL_RC=$?
set -e
assert_refusal cl-canary-state state-malformed

[ "$(find "$TMP" -name CANARY | grep -c . || true)" = "0" ] || fail "cl-canary: a CANARY file was created — a payload was evaluated"
pass "cl-canary-no-side-effect"

printf '\ncheck-liveness suite: all assertions passed\n'
exit 0
