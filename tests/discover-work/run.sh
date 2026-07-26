#!/usr/bin/env bash
# run.sh — drive bin/discover-work.sh against a mocked `gh` and assert the
# documented behavior (T-017 acceptance criteria):
#   AC2: candidate lines are check-handoff-clean when placed in ## Active.
#   AC4: gh absent OR unauthenticated => exit 0 with a note (fail-soft).
#   AC5: PR bodies are never requested (gh stub rejects any `body` arg).
#   AC6: candidates already tracked in ## Active (by #num or source key) are
#        de-duplicated out.
#   AC7: the --max cap is enforced and truncation is reported (no silent cap).
#
# Uses a committed env-driven gh stub (fixtures/gh). Writes under $HERE/tmp
# (no mktemp) so it runs in restricted sandboxes; cleaned via trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
DISCOVER="$REPO_ROOT/bin/discover-work.sh"
CHECK_HANDOFF="$REPO_ROOT/bin/check-handoff.sh"
STUB="$HERE/fixtures/gh"
TMP="$HERE/tmp"
ORIG_PATH="$PATH"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

chmod +x "$STUB"

# A PATH whose first entry holds only the gh stub (real tools come from ORIG_PATH).
GHBIN="$TMP/ghbin"
mkdir -p "$GHBIN"
ln -sf "$STUB" "$GHBIN/gh"

TAB="$(printf '\t')"

# run_discover <stdout-file> [args...]  — runs with the gh stub on PATH, GH_STUB_*
# already exported by the caller. Returns discover-work's exit code.
run_discover() {
  local out="$1"; shift
  local rc
  set +e
  PATH="$GHBIN:$ORIG_PATH" bash "$DISCOVER" "$@" >"$out" 2>&1
  rc=$?
  set -e
  return "$rc"
}

empty_todo="$TMP/empty-todo.md"
printf '# Tasks\n\n## Active\n\n_(none)_\n\n## Done\n' > "$empty_todo"

# --- AC2 + happy path: one of each source, all candidates well-formed --------
out="$TMP/ac2.out"
GH_STUB_AUTH=ok \
GH_STUB_CI="123${TAB}check-handoff" \
GH_STUB_PR="41${TAB}Add retry to fetch${TAB}feature/x" \
GH_STUB_ISSUE="37${TAB}Flaky test in suite" \
  run_discover "$out" --todo "$empty_todo" --max 10 || fail "AC2: discover-work exited non-zero"

n="$(grep -c '^- \[ \]' "$out" || true)"
[ "$n" -eq 3 ] || fail "AC2: expected 3 candidate lines, got $n (out: $(cat "$out"))"
grep -q '\[ci:check-handoff#123\]' "$out" || fail "AC2: CI candidate missing/mis-keyed"
grep -q '\[pr#41\]'    "$out" || fail "AC2: PR candidate missing/mis-keyed"
grep -q '\[issue#37\]' "$out" || fail "AC2: issue candidate missing/mis-keyed"
pass "AC2: one candidate per source, all source-keyed"

# Candidate lines must pass check-handoff when dropped into ## Active.
ac2_todo="$TMP/ac2-todo.md"
{ printf '# Tasks\n\n## Active\n\n'; grep '^- \[ \]' "$out"; printf '\n## Done\n'; } > "$ac2_todo"
bash "$CHECK_HANDOFF" "$ac2_todo" >/dev/null 2>&1 \
  || fail "AC2: emitted candidates do not pass check-handoff"
pass "AC2: emitted candidates pass check-handoff in ## Active"

# --- AC4a: gh absent => fail-soft -------------------------------------------
# Build a PATH with the real tools discover-work needs but NO gh.
NOGH="$TMP/nogh"
mkdir -p "$NOGH"
for t in bash awk grep sed tr; do
  src="$(command -v "$t")" && ln -sf "$src" "$NOGH/$t"
done
out="$TMP/ac4a.out"
set +e
PATH="$NOGH" bash "$DISCOVER" --todo /nonexistent >"$out" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "AC4a: gh-absent should exit 0, got $rc (out: $(cat "$out"))"
grep -qi 'not found' "$out" || fail "AC4a: gh-absent note missing (out: $(cat "$out"))"
[ "$(grep -c '^- \[ \]' "$out" || true)" -eq 0 ] || fail "AC4a: gh-absent should emit no candidates"
pass "AC4a: gh absent => exit 0, note, no candidates"

# --- AC4b: gh unauthenticated => fail-soft ----------------------------------
out="$TMP/ac4b.out"
GH_STUB_AUTH=fail run_discover "$out" --todo "$empty_todo" \
  || fail "AC4b: gh-unauth should exit 0"
grep -qi 'not authenticated' "$out" || fail "AC4b: gh-unauth note missing (out: $(cat "$out"))"
[ "$(grep -c '^- \[ \]' "$out" || true)" -eq 0 ] || fail "AC4b: gh-unauth should emit no candidates"
pass "AC4b: gh unauthenticated => exit 0, note, no candidates"

# --- AC5: PR bodies are never requested -------------------------------------
out="$TMP/ac5.out"
log="$TMP/ac5.gh.log"
GH_STUB_LOG="$log" \
GH_STUB_PR="41${TAB}Add retry${TAB}feature/x" \
  run_discover "$out" --todo "$empty_todo" || fail "AC5: discover-work exited non-zero"
grep -q '\[pr#41\]' "$out" || fail "AC5: PR candidate missing (stub would have rejected a body request)"
grep -q 'body' "$log" && fail "AC5: discover-work requested a PR body (forbidden)"
pass "AC5: PR source called without requesting body"

# --- gh invocation contract: assert the --json fields + --jq actually passed -
# The stub returns canned TSV and ignores --jq, so this is what guards against a
# regression in the production query (fields removed, --jq dropped, body added).
clog="$TMP/contract.gh.log"
GH_STUB_LOG="$clog" \
GH_STUB_CI="1${TAB}wf" GH_STUB_PR="2${TAB}b${TAB}t" GH_STUB_ISSUE="3${TAB}t" \
  run_discover "$TMP/contract.out" --todo "$empty_todo" || fail "contract: discover-work exited non-zero"
grep -E '^run list .*--json databaseId,workflowName .*--jq' "$clog" >/dev/null \
  || fail "contract: CI query missing expected --json fields / --jq"
grep -E '^pr list .*--json number,headRefName,title .*--jq' "$clog" >/dev/null \
  || fail "contract: PR query missing expected --json fields / --jq"
grep -E '^issue list .*--json number,title .*--jq' "$clog" >/dev/null \
  || fail "contract: issue query missing expected --json fields / --jq"
pass "gh invocation contract: each source passes the documented --json fields and --jq"

# --- title containing a tab does not shift the branch field (MED-1) ---------
out="$TMP/tab.out"
GH_STUB_PR="41${TAB}feature/x${TAB}weird${TAB}title" \
  run_discover "$out" --todo "$empty_todo" || fail "tab-title: discover-work exited non-zero"
grep -q '(feature/x)' "$out" || fail "tab-title: branch field was corrupted by a tab in the title"
[ "$(grep -c '^- \[ \]' "$out" || true)" -eq 1 ] || fail "tab-title: expected exactly 1 candidate line"
tab_todo="$TMP/tab-todo.md"
{ printf '# T\n\n## Active\n\n'; grep '^- \[ \]' "$out"; printf '\n## Done\n'; } > "$tab_todo"
bash "$CHECK_HANDOFF" "$tab_todo" >/dev/null 2>&1 \
  || fail "tab-title: candidate with tabbed title does not pass check-handoff"
pass "title containing a tab keeps branch intact and stays check-handoff-clean"

# --- branch name is sanitized too (it is concatenated into the title arg) ---
# add_candidate sanitizes its whole title argument, which already includes the
# branch, so a hostile branch (backtick / em-dash) cannot corrupt the line.
out="$TMP/branch.out"
GH_STUB_PR="41${TAB}feat\`x—y${TAB}Some title" \
  run_discover "$out" --todo "$empty_todo" || fail "branch-sanitize: discover-work exited non-zero"
line="$(grep '^- \[ \]' "$out")"
# Backtick `x and em-dash —y must be neutralized: backtick stripped, em-dash -> '-',
# so the branch renders as (featx-y). Exactly the 2 structural backticks remain.
printf '%s' "$line" | grep -q '(featx-y)' \
  || fail "branch-sanitize: branch was not neutralized (expected (featx-y), got: $line)"
[ "$(printf '%s' "$line" | tr -cd '\`' | wc -c | tr -d ' ')" -eq 2 ] \
  || fail "branch-sanitize: candidate line has stray backticks (expected exactly the 2 around the flag)"
branch_todo="$TMP/branch-todo.md"
{ printf '# T\n\n## Active\n\n%s\n\n## Done\n' "$line"; } > "$branch_todo"
bash "$CHECK_HANDOFF" "$branch_todo" >/dev/null 2>&1 \
  || fail "branch-sanitize: candidate with hostile branch does not pass check-handoff"
pass "hostile branch (backtick / em-dash) is neutralized via the shared sanitize"

# --- AC6: dedup against existing ## Active ----------------------------------
dedup_todo="$TMP/dedup-todo.md"
cat > "$dedup_todo" <<EOF
# Tasks

## Active

- [ ] **T-005** existing work touching PR — \`READY_FOR_QA\` — spec: docs/specs/T-005.md
  - tracked via triage [pr#41]
- [ ] **T-006** another (closes #37) — \`READY_FOR_ENG\` — spec: docs/specs/T-006.md

## Done
EOF
out="$TMP/ac6.out"
GH_STUB_PR="41${TAB}Add retry${TAB}feature/x
42${TAB}New work${TAB}feature/y" \
GH_STUB_ISSUE="37${TAB}Flaky test
38${TAB}Fresh issue" \
  run_discover "$out" --todo "$dedup_todo" || fail "AC6: discover-work exited non-zero"
grep -q '\[pr#41\]'    "$out" && fail "AC6: PR #41 should be de-duped (source key in Active)"
grep -q '\[issue#37\]' "$out" && fail "AC6: issue #37 should be de-duped (#37 referenced in Active)"
grep -q '\[pr#42\]'    "$out" || fail "AC6: fresh PR #42 should be present"
grep -q '\[issue#38\]' "$out" || fail "AC6: fresh issue #38 should be present"
pass "AC6: candidates already tracked in ## Active are de-duped, fresh ones kept"

# --- AC7: --max cap + truncation note ---------------------------------------
out="$TMP/ac7.out"
GH_STUB_PR="41${TAB}One${TAB}b1
42${TAB}Two${TAB}b2
43${TAB}Three${TAB}b3
44${TAB}Four${TAB}b4
45${TAB}Five${TAB}b5" \
  run_discover "$out" --todo "$empty_todo" --max 2 || fail "AC7: discover-work exited non-zero"
n="$(grep -c '^- \[ \]' "$out" || true)"
[ "$n" -eq 2 ] || fail "AC7: expected 2 candidates under --max 2, got $n"
grep -qi 'truncated' "$out" || fail "AC7: truncation note missing (silent cap)"
pass "AC7: --max cap enforced with explicit truncation note"

# --- arg handling -----------------------------------------------------------
set +e
PATH="$GHBIN:$ORIG_PATH" bash "$DISCOVER" --bogus >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "unknown flag should exit 2, got $rc"
set +e
PATH="$GHBIN:$ORIG_PATH" bash "$DISCOVER" --max abc >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "non-integer --max should exit 2, got $rc"
pass "arg errors exit 2"

printf '\nAll discover-work assertions passed.\n'
