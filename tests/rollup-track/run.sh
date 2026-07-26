#!/usr/bin/env bash
# run.sh — drive bin/rollup-track.sh against fixtures and assert the documented
# behavior (T-042 AC6):
#   - writes a git-trackable, dated aggregated rollup summary to
#     <base>/rollups/<date>.md, wrapping bin/rollup-runs.sh's own output
#     verbatim (the wrapper never rewrites/reshapes the summary itself)
#   - never-overwrite numeric-suffix collision rule (mirrors
#     consolidate-proposals.sh's triage-rollup-<date>.md convention)
#   - "(no runs found)" -> no file written, still exit 0 (no empty artifacts)
#   - default-layout AND legacy-layout <base> resolution (via team-paths.sh
#     --get base, not a new team-paths.sh key) both land in the right place
#   - the new rollups/ dir is NOT swept in by any existing .gitignore rule
#     (raw runs/ dirs stay ignored) — locks Design decision 4(c)
#   - PII-safety: the tracked artifact never contains an @-email-like
#     substring or a /Users/ or /home/ absolute-path substring
#   - content guard (T-043 / #108): the write-time guard also refuses a
#     summary carrying a Windows-style home path (\Users\ / \home\) or a
#     common secret-shaped token (ghp_/gho_/ghs_/ghr_ / AKIA / sk-), each
#     proven independently by its own adversarial fixture (exit 2, no file)
#   - usage errors (no input files, bad --date, unknown flag) exit 2
#
# Uses mktemp under $TMPDIR (repo lesson, 2026-06-16 / T-038) — no process
# substitution, cmp -s instead of diff <(...).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin/rollup-track.sh"
ROLLUP_RUNS="$REPO_ROOT/bin/rollup-runs.sh"
FIX="$HERE/fixtures"
DATE="2026-07-07"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rollup-track.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

# run_ok <outvar> <args...> — run, require exit 0, capture stdout (the written
# file's path, or empty when there was nothing to summarize).
run_ok() {
  local __out="$1"; shift
  local p rc
  set +e
  p="$(bash "$BIN" "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "expected exit 0 for: $* (got $rc)"
  printf -v "$__out" '%s' "$p"
}

assert_rc() {  # <desc> <expected_rc> <args...>
  local desc="$1" exp="$2"; shift 2
  local rc
  set +e
  bash "$BIN" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq "$exp" ] || fail "$desc: expected exit $exp, got $rc"
  pass "$desc (exit $rc)"
}

# --- AC6: writes the tracked artifact at the resolved path, wrapping
#         rollup-runs.sh's own output verbatim ---------------------------
D1="$WORK/d1"; mkdir -p "$D1"
run_ok OUT_BASIC "$FIX/clean.jsonl" --out-dir "$D1" --date "$DATE"
[ "$OUT_BASIC" = "$D1/$DATE.md" ] || fail "AC6: unexpected output path: $OUT_BASIC"
[ -f "$OUT_BASIC" ] || fail "AC6: rollup file not written: $OUT_BASIC"
grep -qF "# Roll-up — $DATE" "$OUT_BASIC" || fail "AC6: header missing"

EXPECTED="$(mktemp "${TMPDIR:-/tmp}/rollup-track-expected.XXXXXX")"
bash "$ROLLUP_RUNS" "$FIX/clean.jsonl" > "$EXPECTED"
ACTUAL="$(mktemp "${TMPDIR:-/tmp}/rollup-track-actual.XXXXXX")"
# strip the ``` fences + markdown wrapper header/blurb to recover just the
# embedded rollup-runs.sh output, then byte-compare against a direct call.
awk '/^```$/{c++; next} c==1' "$OUT_BASIC" > "$ACTUAL"
cmp -s "$EXPECTED" "$ACTUAL" || fail "AC6: embedded summary is not byte-identical to a direct rollup-runs.sh call"
pass "AC6: tracked artifact wraps rollup-runs.sh's own output verbatim"

# --- AC6: never-overwrite — a second run, same out-dir + date, gets a
#         numeric suffix; the original file is untouched -----------------
run_ok OUT_COLLIDE "$FIX/clean.jsonl" --out-dir "$D1" --date "$DATE"
[ "$OUT_COLLIDE" = "$D1/$DATE-2.md" ] || fail "AC6: collision suffix not applied: $OUT_COLLIDE"
[ -f "$D1/$DATE.md" ] || fail "AC6: original file should still exist after collision"
[ -f "$OUT_COLLIDE" ] || fail "AC6: suffixed file should exist after collision"
pass "AC6: collision -> numeric suffix, original preserved"

# --- T-061 AC5: a dangling symlink at the candidate output path is a
#     collision too — `[ -e ]` is false for a dangling symlink, so an
#     unguarded loop would follow it and write the rollup OUTSIDE the
#     out-dir. The loop must advance to the next numeric suffix, write inside
#     out-dir, and leave the pre-existing symlink untouched. ---
DSYM="$WORK/dsym"; mkdir -p "$DSYM" "$WORK/outside-check"
ln -s "../outside-check/escaped.md" "$DSYM/$DATE.md"
run_ok OUT_SYM "$FIX/clean.jsonl" --out-dir "$DSYM" --date "$DATE"
[ "$OUT_SYM" = "$DSYM/$DATE-2.md" ] \
  || fail "T-061 AC5: dangling symlink should be treated as a collision, advancing to the -2 suffix (got: $OUT_SYM)"
[ -f "$OUT_SYM" ] || fail "T-061 AC5: the -2 suffix rollup file was not written"
[ ! -e "$WORK/outside-check/escaped.md" ] \
  || fail "T-061 AC5: rollup content escaped the out-dir through a dangling symlink"
[ -L "$DSYM/$DATE.md" ] \
  || fail "T-061 AC5: the pre-existing dangling symlink should be preserved untouched"
pass "T-061 AC5: dangling symlink at the collision path advances to the next suffix, no out-dir escape, symlink preserved"

# --- AC6: "(no runs found)" -> no file written, still exit 0 -------------
D2="$WORK/d2"; mkdir -p "$D2"
run_ok OUT_EMPTY "$FIX/empty.jsonl" --out-dir "$D2" --date "$DATE"
[ -z "$OUT_EMPTY" ] || fail "AC6: expected no output path for an empty input, got: $OUT_EMPTY"
[ -z "$(ls -A "$D2" 2>/dev/null)" ] || fail "AC6: no file should be written when there is nothing to summarize"
pass "AC6: nothing to summarize -> no file written, exit 0"

# --- AC6: rollup-runs.sh itself is byte-unchanged (also asserted at the AC
#         level via git diff; re-assert here that the wrapper never edits it
#         at runtime by cksum-ing before/after invoking the wrapper). ------
before_cksum="$(cksum "$ROLLUP_RUNS")"
D3="$WORK/d3"; mkdir -p "$D3"
run_ok OUT_CKSUM "$FIX/clean.jsonl" --out-dir "$D3" --date "$DATE"
after_cksum="$(cksum "$ROLLUP_RUNS")"
[ "$before_cksum" = "$after_cksum" ] || fail "AC6: rollup-runs.sh was modified by invoking the wrapper"
pass "AC6: rollup-runs.sh untouched by the wrapper at runtime"

# --- AC6: default-layout resolution -> <base>/rollups, <base> from
#         team-paths.sh --get base (no --out-dir given) ------------------
DEF="$WORK/default-layout"; mkdir -p "$DEF"
( cd "$DEF" && bash "$BIN" "$FIX/clean.jsonl" --date "$DATE" >/dev/null )
[ -f "$DEF/.shell-team/rollups/$DATE.md" ] || fail "default layout: expected .shell-team/rollups/$DATE.md"
pass "default layout (no marker) -> .shell-team/rollups/<date>.md"

# --- AC6: legacy-layout resolution -> tasks/rollups -----------------------
LEG="$WORK/legacy-layout"; mkdir -p "$LEG/tasks/loops"
: > "$LEG/tasks/loops/shell-team.contract.yaml"
( cd "$LEG" && bash "$BIN" "$FIX/clean.jsonl" --date "$DATE" >/dev/null )
[ -f "$LEG/tasks/rollups/$DATE.md" ] || fail "legacy layout: expected tasks/rollups/$DATE.md"
pass "legacy layout (tasks/loops/shell-team.contract.yaml present) -> tasks/rollups/<date>.md"

# --- AC6: the new rollups/ dir is not swept in by any existing .gitignore
#         rule (raw runs/ dirs stay ignored) — locks Design decision 4(c).
#         Uses THIS repo's own git history (legacy layout, root .gitignore)
#         plus a throwaway git repo seeded with the default-layout
#         team-init template (.shell-team/.gitignore). --------------------
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$REPO_ROOT" check-ignore -q tasks/rollups/dummy.md; then
    fail "legacy .gitignore: tasks/rollups/dummy.md must NOT be ignored"
  fi
  git -C "$REPO_ROOT" check-ignore -q tasks/runs/dummy.jsonl \
    || fail "legacy .gitignore: tasks/runs/dummy.jsonl should still be ignored (regression)"
  pass "legacy .gitignore: rollups/ not swept in, runs/ stays ignored"
else
  printf 'SKIP: legacy .gitignore check (no .git dir found at %s)\n' "$REPO_ROOT"
fi

GITCHK="$WORK/gitignore-default"; mkdir -p "$GITCHK/.shell-team"
( cd "$GITCHK" && git init -q )
cp "$REPO_ROOT/templates/shell-team.gitignore" "$GITCHK/.shell-team/.gitignore"
if git -C "$GITCHK" check-ignore -q .shell-team/rollups/dummy.md; then
  fail "default .gitignore template: .shell-team/rollups/dummy.md must NOT be ignored"
fi
git -C "$GITCHK" check-ignore -q .shell-team/runs/dummy.jsonl \
  || fail "default .gitignore template: .shell-team/runs/dummy.jsonl should still be ignored (regression)"
pass "default .gitignore template: rollups/ not swept in, runs/ stays ignored"

# --- PII-safety: the tracked artifact never contains an @-email-like
#         substring or a /Users/ or /home/ absolute-path substring --------
D4="$WORK/d4"; mkdir -p "$D4"
run_ok OUT_PII "$FIX/clean.jsonl" --out-dir "$D4" --date "$DATE"
if grep -qE '[[:alnum:]._%+-]+@[[:alnum:].-]+' "$OUT_PII"; then
  fail "PII-safety: output contains an @-email-like substring"
fi
if grep -qE '/Users/|/home/' "$OUT_PII"; then
  fail "PII-safety: output contains a /Users/ or /home/ absolute-path substring"
fi
pass "PII-safety: no @-email-like or /Users//home/ substring in the tracked artifact"

# --- PII-safety (adversarial): a run log whose unconstrained run_id/phase
#         fields DO carry PII (email + /Users/ path) must be REFUSED at write
#         time (exit 2) with NO file written — this is the runtime guard, not
#         just the clean-fixture check above (T-042 codex round1 blocker). ----
D5="$WORK/d5"; mkdir -p "$D5"
assert_rc "adversarial PII input -> refused (exit 2)" 2 "$FIX/pii.jsonl" --out-dir "$D5" --date "$DATE"
[ -z "$(ls -A "$D5" 2>/dev/null)" ] || fail "PII-safety: NO file must be written when the summary carries PII (found artifact in $D5)"
# and prove the guard is what fired (not some unrelated arg error): the summary
# genuinely contains the PII, so a direct rollup-runs.sh call would surface it.
# (Capture to a temp file first — piping into `grep -q` under `set -o pipefail`
# would SIGPIPE rollup-runs.sh and report the pipeline as failed even on a
# match.)
PII_SUMMARY="$(mktemp "${TMPDIR:-/tmp}/rollup-track-pii.XXXXXX")"
bash "$ROLLUP_RUNS" "$FIX/pii.jsonl" > "$PII_SUMMARY"
grep -qE '@|/Users/' "$PII_SUMMARY" \
  || fail "PII-safety: fixture precondition — rollup-runs.sh summary should contain the PII the guard must catch"
pass "PII-safety (adversarial): PII-carrying summary refused, no artifact written"

# --- content guard (adversarial, T-043 / #108): the write-time guard also
#     refuses a Windows-style home path and common secret-shaped tokens carried
#     by the unconstrained run_id/phase fields. Each shape is proven
#     independently by its own fixture: exit 2, NO file written, plus a
#     precondition that rollup-runs.sh's summary genuinely contains the token
#     (so we know the guard fired, not an unrelated arg error). --------------
assert_guard_refused() {  # <desc> <fixture> <precond_grep_ere>
  local desc="$1" fixture="$2" precond="$3"
  local d s
  d="$(mktemp -d "${TMPDIR:-/tmp}/rollup-track-guard.XXXXXX")"
  assert_rc "$desc -> refused (exit 2)" 2 "$fixture" --out-dir "$d" --date "$DATE"
  [ -z "$(ls -A "$d" 2>/dev/null)" ] || fail "$desc: NO file must be written when the summary carries guarded content (found artifact in $d)"
  s="$(mktemp "${TMPDIR:-/tmp}/rollup-track-guard-sum.XXXXXX")"
  bash "$ROLLUP_RUNS" "$fixture" > "$s"
  grep -qE "$precond" "$s" \
    || fail "$desc: fixture precondition — rollup-runs.sh summary should contain the guarded token the guard must catch"
  pass "$desc: guarded summary refused, no artifact written"
}

assert_guard_refused "adversarial Windows home path"    "$FIX/winpath.jsonl"       '[\]Users'
assert_guard_refused "adversarial GitHub-token shape"   "$FIX/secret-github.jsonl" 'ghp_'
assert_guard_refused "adversarial AWS-access-key shape" "$FIX/secret-aws.jsonl"    'AKIA'
assert_guard_refused "adversarial OpenAI-key shape"     "$FIX/secret-openai.jsonl" 'sk-'

# --- content guard (regression, T-043 codex round1 blocker): a legitimate
#     label that merely RESEMBLES a guarded token but is too short to be a real
#     secret must still write at exit 0. Each secret prefix is anchored to a
#     minimum key-body length precisely so this repo's own `task-043` task-ID
#     convention (literal substring `sk-`) and a short `ghp_short` are NOT
#     refused (AC3 "no new false positive"). --------------------------------
D6="$WORK/d6"; mkdir -p "$D6"
run_ok OUT_LOOKALIKE "$FIX/label-lookalike.jsonl" --out-dir "$D6" --date "$DATE"
[ -n "$OUT_LOOKALIKE" ] || fail "AC3: a short secret-lookalike label (task-043 / ghp_short) must still write, got no output path"
[ -f "$OUT_LOOKALIKE" ] || fail "AC3: lookalike rollup file not written: $OUT_LOOKALIKE"
# prove the summary genuinely carries the lookalike substrings the guard must NOT over-match
grep -qF 'sk-043' "$OUT_LOOKALIKE" || fail "AC3: fixture precondition — summary should carry the 'sk-' lookalike (task-043)"
pass "AC3: short secret-lookalike label (task-043 / ghp_short) still writes, no false positive"

# --- usage errors -----------------------------------------------------------
assert_rc "no input files -> 2"  2 --out-dir "$WORK" --date "$DATE"
assert_rc "bad --date -> 2"      2 "$FIX/clean.jsonl" --date 2026/07/07 --out-dir "$WORK"
assert_rc "unknown flag -> 2"    2 --bogus
assert_rc "--out-dir missing val -> 2" 2 --out-dir

printf '\nAll rollup-track assertions passed.\n'
