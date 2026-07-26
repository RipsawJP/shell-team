#!/usr/bin/env bash
# run.sh — behavioral suite for bin/codex-capture.sh (T-097, #303 / T-092b
# carve-out — docs/specs/T-097-codex-skeleton-hygiene.md AC4/AC5), plus
# Thread B forward-lock equivalence-completeness cases (grep-only, no
# production checker involved — T-077's checker/spec stay byte-invariant),
# plus two T-098 cases (docs/specs/T-098-codex-capture-validate-publish-depth.md
# AC3/AC4/AC5) hardening the DP-A JSONL validation depth and the DP-C
# #250-residual(b) trap-arming order, plus four T-106 live-file forward-lock
# cases (docs/specs/T-106-t077-lock-equivalence.md AC5/AC6, #240 item①)
# wiring T-097's frozen DP-7/DP-8 regexes to the live consumer files, plus
# seven T-107 cases (docs/specs/T-107-codex-capture-split.md AC4/AC5)
# covering the structural split of bin/codex-capture.sh into hygiene-only
# `--alloc`/`--publish` modes and the resulting present/absence/mutation
# teeth on the three live caller sites, plus two T-107 round4 cases (DP-l,
# the fence-structure redesign after the capture-split-wiring escalation)
# machine-checking the caller snippets' fence STRUCTURE, not just their
# prose.
#
# T-107 NOTE (structural split): bin/codex-capture.sh no longer invokes codex
# itself. Every case below that used to run the helper end-to-end (which
# internally substituted a captured temp path into the caller's own codex
# argv and executed it) now mirrors the REAL caller skeleton instead:
# `--alloc` first, then the mock `codex` binary invoked DIRECTLY by this
# suite (exactly like a live caller's bare `codex exec ...` line would), then
# `--publish` fed the resulting two raw paths explicitly. This is not a
# weaker test — the same happy/reject/cleanup properties are asserted against
# the actual two-call contract callers now use, not the retired single-call
# one.
#
# T-107 round4 NOTE (DP-c redesign, caller contract): the caller snippets no
# longer thread rc through bash variables (`codex_status`/`publish_status`/
# `raw=`/`"$raw_out"`/`"$raw_jsonl"`) — round1-round3 kept a "connected
# shell" premise embedded in the fenced blocks themselves even after the
# PROSE flipped to "standalone invocation," and that premise/prose mismatch
# went undetected for 4 rounds because no lock inspected fence STRUCTURE
# (only present/absence of prose substrings). Each caller site is now five
# separate fenced blocks (`alloc`/`codex`/`diagnose`/`cleanup`/`publish`),
# each opening with a bare marker comment `# T-107-step: <kind>` and
# containing exactly one logical command with no variable assignment and no
# `$( )`, and paths flow between blocks only as literal quoted placeholders
# (`"<RAW_OUT>"` / `"<RAW_JSONL>"`) substituted with the absolute paths the
# `alloc` block's tool output printed.
#
# Twenty-six labeled cases (AC4 grep-anchors every one of these tokens):
#   happy                  --alloc + mock codex (happy) + --publish publishes
#                          both canonical files non-empty, exit 0, no
#                          leftover raw.
#   empty-reject           mock codex writes an empty -o capture -> --publish
#                          exit 3, no canonical publish.
#   structure-reject       mock codex's JSONL stream has no JSON-object line
#                          -> --publish exit 3, no canonical publish.
#   mv-fail                the canonical .txt path pre-exists as a directory
#                          -> the pre-mv non-regular-file guard refuses
#                          before any `mv` is attempted -> exit 4 -> AND no
#                          `.codex-capture.*` raw is orphaned ANYWHERE under
#                          the reviews dir (incl. nested inside the
#                          pre-existing directory, the rework2 Major-2 fix).
#   stale-mv-fail           a STALE non-empty canonical .txt+.jsonl pair
#                          pre-exists; a PATH-shadowed `mv` shim simulates a
#                          genuine rename failure (permission/ACL/quota/
#                          concurrent-invocation are all real triggers this
#                          shim need not model precisely) while `mktemp`
#                          still succeeds -> exit 4 (NEVER 0), stale
#                          canonical content byte-for-byte unchanged, no
#                          leftover raw. Proves the helper never silently
#                          reports success while discarding a fresh capture
#                          against stale content it failed to overwrite.
#   trap-cleanup           (T-107 re-scoped: the helper no longer invokes
#                          codex, so there is no "codex non-zero" path left
#                          inside it — that check moved to the caller, see
#                          agentmd-* below) after `--publish` REJECTS an
#                          empty capture (exit 3), its own EXIT trap removes
#                          the per-invocation raw(s); none survive.
#   newcatch-abspath       the DP-7 extended regex matches an absolute-path
#                          interpreter form the T-077 literal regex misses.
#   newcatch-space-sentinel the DP-8 extended regex matches hyphen<->space
#                          symmetric forms the T-077 literal regex misses.
#   oldmiss                a frozen, self-contained, byte-verbatim copy of
#                          the T-077 literal AC3/AC15 regexes (confirmed
#                          against docs/specs/T-077-provenance-gate-design.md
#                          at authoring time) MISSES every newcatch example
#                          above — the non-vacuous counterfactual proving the
#                          extension actually adds coverage (T-095 pattern:
#                          frozen inline snippet, no moving git ref).
#   fp-zero                the extended DP-7/DP-8 regexes match ZERO lines in
#                          a clean fixture carrying the legitimate forms that
#                          must NOT match (bare `check-provenance.sh`, the
#                          passive `else \`bin/check-provenance.sh\`` fallback
#                          mention, a standalone loop-guard.sh mention, a
#                          provenance mention with no gate:AC<n> sentinel).
#   template-check-ignore  `git check-ignore` in a throwaway repo whose
#                          .gitignore is templates/shell-team.gitignore
#                          reports a probe `.codex-capture.` raw path under
#                          `reviews/` as ignored.
#   malformed-json-reject  (T-098, DP-A) mock codex's `malformed` mode emits
#                          a `{`-leading-but-invalid line -> --publish exit 3,
#                          no canonical publish; AND a frozen byte-copy of
#                          the OLD leading-`{` grep ACCEPTs that same line
#                          (non-vacuous counterfactual — the old check would
#                          have let the malformed capture through).
#   mktemp-second-fail-no-leak (T-098, DP-C) a PATH-shim `mktemp` fails the
#                          SECOND call inside `--alloc` -> exit 2 (die 2),
#                          and no `.codex-capture.<stem>.*` raw is orphaned
#                          under the reviews dir (the first raw is cleaned by
#                          the EXIT trap armed right after the first mktemp).
#   livefile-broken-invocation (T-106, item①) the DP-7 extended regex
#                          matches ZERO lines across the live consumer files
#                          (agents/qa-verifier.md, skills/run/SKILL.md,
#                          skills/goal/SKILL.md) — forward-locking their
#                          current clean state as a recurring CI guard.
#   livefile-stateful-trace (T-106, item①) the DP-8 extended regex matches
#                          ZERO lines in the live skills/run/SKILL.md —
#                          forward-locking its current clean state.
#   livefile-mutation-ac3  (T-106, item①, non-vacuous counterfactual) a
#                          mutated $TMP copy of a live consumer file with a
#                          broken invocation line injected IS caught by the
#                          DP-7 extended regex, proving the
#                          livefile-broken-invocation lock is not vacuous.
#   livefile-mutation-ac15 (T-106, item①, non-vacuous counterfactual) a
#                          mutated $TMP copy of skills/run/SKILL.md with a
#                          space-separated stateful sentinel injected IS
#                          caught by the DP-8 extended regex, proving the
#                          livefile-stateful-trace lock is not vacuous.
#   alloc-paths-in-reviews-dir (T-107, DP-a/DP-b) `--alloc` exits 0, prints
#                          EXACTLY two stdout lines, and both paths are
#                          regular files directly under the resolved reviews
#                          dir with the expected `.codex-capture.<stem>.
#                          {out,jsonl}.` basename prefixes.
#   publish-foreign-path-reject (T-107, DP-b — most important) `--publish`
#                          refuses (exit 2, no `mv` attempted, no canonical
#                          created) a raw whose parent directory is outside
#                          the reviews dir (the `$TMP`-raw cross-fs-degrade
#                          case), a raw that does not exist, and a raw whose
#                          basename's stem prefix does not match; a
#                          non-vacuity check publishes the SAME kind of
#                          content successfully (exit 0) when routed through
#                          a legitimate `--alloc` path.
#   wrapper-never-execs-codex (T-107, DP-e/DP-j — behavioral teeth) a
#                          sentinel-writing `codex` shim is placed first on
#                          PATH; running `--alloc` then `--publish` end to
#                          end never creates the sentinel — proving neither
#                          mode ever executes anything named `codex`.
#   agentmd-bare-codex-present (T-107, DP-g①) the live
#                          agents/codex-reviewer.md / agents/drift-evaluator.md
#                          carry exactly 2 / 1 bare `^codex exec ` lines and
#                          each of AC10's confirmed `--alloc`/`--publish`
#                          full-sentence forms. Grep rc discipline: rc=0
#                          (found) is the only PASS; rc>=2 (e.g. a live agent
#                          md file went missing) fails closed.
#   agentmd-wrapped-form-absent (T-107, DP-g②) the same 2 files carry NONE
#                          of the retired inline-hygiene literals
#                          (`@CODEX_OUT@` / `tmp_out=$(mktemp)` /
#                          `cp "$tmp_out"`). Grep rc discipline: rc=1 (clean)
#                          is the only PASS; rc=0 means the old form
#                          resurfaced, rc>=2 fails closed.
#   agentmd-mutation-present (T-107, DP-g③, non-vacuous counterfactual) a
#                          mutated $TMP copy of agents/codex-reviewer.md with
#                          one bare `codex exec ` line rewritten to a
#                          `cd <repo> && codex exec ...` wrapped form shows a
#                          REDUCED bare-line count — proving the present-lock
#                          above is not vacuous.
#   agentmd-mutation-absent (T-107, DP-g③, non-vacuous counterfactual) a
#                          mutated $TMP copy with each retired inline-hygiene
#                          literal injected (including the round4 rc-threading
#                          vocabulary, e.g. `codex_status`) IS detected (grep
#                          rc=0) — proving the absence-lock above is not
#                          vacuous.
#   agentmd-fence-structure (T-107, DP-l, round4) both live agent files' 5
#                          T-107-step blocks per site (alloc/codex/diagnose/
#                          cleanup/publish; codex-reviewer.md carries 2 sites)
#                          each contain EXACTLY one logical command (comments/
#                          blanks excluded, backslash continuations folded),
#                          whose first token matches the kind
#                          (alloc/publish->codex-capture.sh, codex->codex,
#                          diagnose->cat, cleanup->rm), with no variable
#                          assignment and no `$( )` anywhere in that command.
#   agentmd-fence-mutation (T-107, DP-l, round4/round5, non-vacuous — PER
#                          SITE) for EACH of the 3 sites (codex-reviewer.md
#                          primary, codex-reviewer.md adversarial,
#                          drift-evaluator.md) INDEPENDENTLY: (i) injecting
#                          an extra assignment line into that site's `codex`
#                          block, (ii) merging that site's `cleanup` command
#                          into its `diagnose` block, (iii) deleting that
#                          site's `alloc` marker line, (iv, round5) inserting
#                          an extra line BEFORE that site's `alloc` marker
#                          (closing round5 Major #1 — a marker preceded by
#                          one extra line used to be classified as
#                          "untracked" and silently skipped), and (v,
#                          round5) injecting an unquoted `&& touch ...`
#                          connector into that site's `codex` block's first
#                          physical line (closing round5 Major #2 — a real
#                          shell-level command-injection primitive the
#                          previous structural check never inspected for),
#                          EACH ALONE, is caught by the agentmd-fence-structure
#                          check applied to that mutated copy — 3 sites x 5
#                          mutations = 15 independent non-vacuity proofs (a
#                          single copy with all sites mutated together is NOT
#                          a substitute — QA round4's Blocker, and Codex
#                          round5's Major #2 "QA verified only the primary
#                          site" finding, were both exactly a lock whose
#                          per-site coverage went untested). A final
#                          unmodified control copy of each file must still
#                          PASS.
#
# Sandbox rules honored throughout (2026-07-06 lesson): no bare `mktemp`
# (every temp path is rooted under $TMP, itself under $TMPDIR), no nested
# .git under the repo tree (the throwaway git repos below live under $TMP,
# never inside this checkout), no process substitution (temp files + cmp/
# grep instead).
#
# Exit: 0 = every case passed. 1 = at least one FAIL (see stderr).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/codex-capture.sh"
MOCK_DIR="$HERE/mock"
FIX="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

TMP="${TMPDIR:-/tmp}/codex-skeleton-hygiene-test.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
# Canonicalize TMP to its PHYSICAL path (pwd -P) right away: `$TMPDIR` itself
# is a symlink on macOS (`/tmp` -> `/private/tmp`), and bin/codex-capture.sh
# now canonicalizes the reviews dir the same way (T-107 round1 Codex review
# Major #1 fix). If REVIEWS_DIR below stayed a logical/symlinked spelling
# while the script's own internal canonicalization returns the physical
# spelling, plain string-equality assertions against REVIEWS_DIR would fail
# spuriously — this keeps both sides of every such comparison in this suite
# on the same (physical) footing from the start.
TMP="$(cd "$TMP" && pwd -P)"

REVIEWS_DIR="$TMP/reviews"
mkdir -p "$REVIEWS_DIR"

out="$TMP/out"
err="$TMP/err"

# alloc_and_mock MODE STEM — runs `--alloc`, then runs the mock `codex`
# binary DIRECTLY (mirroring a live caller's bare `codex exec ...` line —
# the helper itself never invokes codex post-split), leaving the two raw
# paths in $raw_out / $raw_jsonl. Every case using this helper expects
# `--alloc` itself to succeed (a failing `--alloc` is exercised on its own,
# without this helper, by mktemp-second-fail-no-leak below).
raw_out=""
raw_jsonl=""
alloc_and_mock() {
  local mode="$1" stem="$2"
  local alloc_out alloc_rc
  set +e
  alloc_out="$(bash "$SCRIPT" --alloc --stem "$stem" --reviews-dir "$REVIEWS_DIR" 2>"$err")"
  alloc_rc=$?
  set -e
  [[ "$alloc_rc" -eq 0 ]] || fail "$stem: --alloc itself failed unexpectedly (rc=$alloc_rc): $(cat "$err")"
  raw_out="${alloc_out%%$'\n'*}"
  raw_jsonl="${alloc_out##*$'\n'}"
  MOCK_CODEX_MODE="$mode" "$MOCK_DIR/codex" -o "$raw_out" > "$raw_jsonl" 2>&1 || true
}

# run_publish STEM — calls `--publish` against the current $raw_out/
# $raw_jsonl, leaving the exit code in $rc and stdout/stderr in $out/$err.
run_publish() {
  local stem="$1"
  set +e
  bash "$SCRIPT" --publish --stem "$stem" --reviews-dir "$REVIEWS_DIR" \
    --publish-out "$raw_out" --publish-jsonl "$raw_jsonl" >"$out" 2>"$err"
  rc=$?
  set -e
}

leftover_temps() {
  # $1 = stem. Prints any .codex-capture.<stem>.* files still in REVIEWS_DIR.
  find "$REVIEWS_DIR" -maxdepth 1 -name ".codex-capture.$1.*" 2>/dev/null
}

# =============================================================================
# happy
# =============================================================================
printf -- '--- happy ---\n'
alloc_and_mock happy T-097-test-happy
run_publish T-097-test-happy
[[ "$rc" -eq 0 ]] || fail "happy: expected exit 0, got $rc (stderr: $(cat "$err"))"
[[ -f "$REVIEWS_DIR/T-097-test-happy.txt" && -s "$REVIEWS_DIR/T-097-test-happy.txt" ]] \
  || fail "happy: canonical .txt missing or empty"
[[ -f "$REVIEWS_DIR/T-097-test-happy.jsonl" && -s "$REVIEWS_DIR/T-097-test-happy.jsonl" ]] \
  || fail "happy: canonical .jsonl missing or empty"
leftover="$(leftover_temps T-097-test-happy)"
[[ -z "$leftover" ]] || fail "happy: leftover raw(s) after successful publish: $leftover"
pass "happy — --alloc + mock codex + --publish publishes both canonical files non-empty (exit 0), no leftover raw"

# =============================================================================
# empty-reject
# =============================================================================
printf -- '\n--- empty-reject ---\n'
alloc_and_mock empty T-097-test-empty
run_publish T-097-test-empty
[[ "$rc" -eq 3 ]] || fail "empty-reject: expected exit 3, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/T-097-test-empty.txt" ]] || fail "empty-reject: canonical .txt must not exist on reject"
[[ ! -e "$REVIEWS_DIR/T-097-test-empty.jsonl" ]] || fail "empty-reject: canonical .jsonl must not exist on reject"
pass "empty-reject — an empty -o capture is rejected with exit 3, no canonical publish"

# =============================================================================
# structure-reject
# =============================================================================
printf -- '\n--- structure-reject ---\n'
alloc_and_mock structure T-097-test-structure
run_publish T-097-test-structure
[[ "$rc" -eq 3 ]] || fail "structure-reject: expected exit 3, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/T-097-test-structure.txt" ]] || fail "structure-reject: canonical .txt must not exist on reject"
pass "structure-reject — a non-JSON JSONL stream (no line starting with '{') is rejected with exit 3"

# =============================================================================
# malformed-json-reject (T-098, DP-A — non-vacuous counterfactual: the OLD
# leading-`{` grep ACCEPTs a `{`-leading-but-malformed capture; the NEW
# structural awk pass REJECTs it)
# =============================================================================
printf -- '\n--- malformed-json-reject ---\n'
alloc_and_mock malformed T-097-test-malformed
run_publish T-097-test-malformed
[[ "$rc" -eq 3 ]] || fail "malformed-json-reject: expected exit 3, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/T-097-test-malformed.txt" ]] || fail "malformed-json-reject: canonical .txt must not exist on reject"
[[ ! -e "$REVIEWS_DIR/T-097-test-malformed.jsonl" ]] || fail "malformed-json-reject: canonical .jsonl must not exist on reject"

# Non-vacuity (T-095 frozen-inline pattern): a frozen, self-contained,
# byte-verbatim copy of the OLD leading-`{` check that bin/codex-capture.sh
# used BEFORE this task (confirmed against `develop`'s
# `bin/codex-capture.sh:168` at authoring time) -- inlined here rather than
# fetched via a moving git ref, so this suite has zero dependency on a
# `develop` branch existing locally. Proves the OLD check would have ACCEPTed
# this same malformed capture (the fail-open the new DP-A pass closes).
# shellcheck disable=SC2016
OLD_JSONL_RE='^[[:space:]]*{'
set +e
printf '%s\n' '{broken-jsonl' | grep -qE "$OLD_JSONL_RE"
old_jsonl_re_rc=$?
set -e
[[ "$old_jsonl_re_rc" -eq 0 ]] \
  || fail "malformed-json-reject: expected the FROZEN OLD leading-'{' check to ACCEPT '{broken-jsonl' (non-vacuity — the old check must have actually let this through), but it did not match"
pass "malformed-json-reject — a \`{\`-leading-but-malformed capture ('{broken-jsonl') is rejected with exit 3, no canonical publish; the frozen OLD leading-'{' check would have ACCEPTed it (non-vacuous counterfactual — the new DP-A structural pass genuinely closes a fail-open the old check left open)"

# =============================================================================
# mv-fail
# =============================================================================
printf -- '\n--- mv-fail ---\n'
mkdir -p "$REVIEWS_DIR/T-097-test-mvfail.txt"
# Pre-seed the pre-existing directory with a stale file, so a pre-fix `mv`
# that nests the raw INSIDE it (rather than refusing pre-mv) would leave a
# genuinely detectable orphan for the assertion below to catch.
printf 'pre-existing unrelated file\n' > "$REVIEWS_DIR/T-097-test-mvfail.txt/unrelated.txt"
alloc_and_mock happy T-097-test-mvfail
run_publish T-097-test-mvfail
[[ "$rc" -eq 4 ]] || fail "mv-fail: expected exit 4, got $rc (stderr: $(cat "$err"))"
mvfail_orphan="$(find "$REVIEWS_DIR" -name '.codex-capture.*' 2>/dev/null)"
[[ -z "$mvfail_orphan" ]] \
  || fail "mv-fail: .codex-capture.* raw orphaned somewhere under the reviews dir (incl. nested inside the pre-existing directory): $mvfail_orphan"
pass "mv-fail — the canonical .txt path pre-existing as a directory is refused BEFORE any mv (rework2 Major-2 guard), exit 4, no .codex-capture.* raw orphaned anywhere under the reviews dir (incl. nested)"

# =============================================================================
# stale-mv-fail (non-vacuous counterfactual for the rework2 Blocker fix — a
# failed mv publish against a STALE pre-existing non-empty canonical pair
# must never be silently reported as success)
# =============================================================================
printf -- '\n--- stale-mv-fail ---\n'
STALE_STEM="T-097-test-stalemvfail"
printf 'STALE OLD TXT CONTENT (pre-existing, must survive a failed publish)\n' > "$REVIEWS_DIR/$STALE_STEM.txt"
printf '{"stale":"pre-existing jsonl content, must survive a failed publish"}\n' > "$REVIEWS_DIR/$STALE_STEM.jsonl"
stale_txt_before="$(cat "$REVIEWS_DIR/$STALE_STEM.txt")"
stale_jsonl_before="$(cat "$REVIEWS_DIR/$STALE_STEM.jsonl")"

MVFAIL_SHIM_DIR="$TMP/mvfail-shim"
mkdir -p "$MVFAIL_SHIM_DIR"
cat > "$MVFAIL_SHIM_DIR/mv" <<'MVSHIM'
#!/usr/bin/env bash
# Shim `mv`: simulate a genuine rename failure onto the canonical target
# (permission/ACL/quota/concurrent-invocation are all real triggers this
# shim need not model precisely -- the helper's rc-check must treat ANY
# non-zero `mv` the same way: exit 4, never a silent stale-read) without
# touching either the source or destination path.
printf 'mv-fail-shim: simulated rename failure: %s\n' "$*" >&2
exit 1
MVSHIM
chmod +x "$MVFAIL_SHIM_DIR/mv"

alloc_and_mock happy "$STALE_STEM"
set +e
PATH="$MVFAIL_SHIM_DIR:$PATH" bash "$SCRIPT" --publish --stem "$STALE_STEM" --reviews-dir "$REVIEWS_DIR" \
  --publish-out "$raw_out" --publish-jsonl "$raw_jsonl" >"$out" 2>"$err"
rc=$?
set -e

[[ "$rc" -eq 4 ]] \
  || fail "stale-mv-fail: expected exit 4 (a failed mv publish must never report success), got $rc (stderr: $(cat "$err"))"
stale_txt_after="$(cat "$REVIEWS_DIR/$STALE_STEM.txt")"
stale_jsonl_after="$(cat "$REVIEWS_DIR/$STALE_STEM.jsonl")"
[[ "$stale_txt_after" == "$stale_txt_before" ]] \
  || fail "stale-mv-fail: stale canonical .txt content changed even though mv reported failure (silent stale-read regression)"
[[ "$stale_jsonl_after" == "$stale_jsonl_before" ]] \
  || fail "stale-mv-fail: stale canonical .jsonl content changed even though mv reported failure (silent stale-read regression)"
stale_leftover="$(leftover_temps "$STALE_STEM")"
[[ -z "$stale_leftover" ]] \
  || fail "stale-mv-fail: leftover raw(s) after a failed publish: $stale_leftover"
pass "stale-mv-fail — a failed mv publish against a STALE pre-existing non-empty canonical pair exits 4 (never a silent stale-read success), stale content byte-for-byte unchanged, no leftover raw"

# =============================================================================
# trap-cleanup (T-107 re-scoped: the helper no longer invokes codex, so there
# is no "codex non-zero" path left inside it to exercise here — that
# responsibility moved to the caller, see agentmd-* below. This case now
# proves --publish's OWN EXIT trap cleans up the raws it rejects.)
# =============================================================================
printf -- '\n--- trap-cleanup ---\n'
alloc_and_mock empty T-097-test-trapcleanup
run_publish T-097-test-trapcleanup
[[ "$rc" -eq 3 ]] || fail "trap-cleanup: expected exit 3 (validation reject on an empty -o capture), got $rc"
leftover="$(leftover_temps T-097-test-trapcleanup)"
[[ -z "$leftover" ]] || fail "trap-cleanup: leftover raw(s) after a validation-rejected publish: $leftover"
pass "trap-cleanup — --publish's own EXIT trap removes the per-invocation raw(s) even after it rejects an invalid capture"

# =============================================================================
# mktemp-second-fail-no-leak (T-098, DP-C — #250 residual (b) regression: a
# second-mktemp failure must not orphan the first raw, since the EXIT trap
# is now armed right after the FIRST mktemp succeeds. T-107: this now
# exercises `--alloc` directly — there is no codex invocation in this path
# at all.)
# =============================================================================
printf -- '\n--- mktemp-second-fail-no-leak ---\n'
MKTEMP_SHIM_DIR="$TMP/mktemp-second-fail-shim"
mkdir -p "$MKTEMP_SHIM_DIR"
cat > "$MKTEMP_SHIM_DIR/mktemp" <<'MKSHIM'
#!/usr/bin/env bash
# Shim `mktemp`: count invocations via a counter file (path given by
# $MKTEMP_COUNTER_FILE). Call 1 delegates to the REAL mktemp (`command -p
# mktemp "$@"`, bypassing this shim -- POSIX `command -p` uses the
# implementation's default PATH, which does not include this shim's
# directory); call >=2 fails (exit 1), simulating a genuine second-mktemp
# failure (e.g. ENOSPC/EMFILE) so the DP-C early-armed-trap non-leak
# guarantee can be exercised.
set -euo pipefail
count_file="${MKTEMP_COUNTER_FILE:?MKTEMP_COUNTER_FILE must be set}"
n=0
if [ -f "$count_file" ]; then
  n="$(cat "$count_file")"
fi
n=$((n + 1))
printf '%s' "$n" > "$count_file"
if [ "$n" -eq 1 ]; then
  command -p mktemp "$@"
else
  printf 'mktemp-second-fail-shim: simulated failure on call #%s\n' "$n" >&2
  exit 1
fi
MKSHIM
chmod +x "$MKTEMP_SHIM_DIR/mktemp"

MKTEMP_COUNTER_FILE="$TMP/mktemp-second-fail-counter"
rm -f "$MKTEMP_COUNTER_FILE"

set +e
MKTEMP_COUNTER_FILE="$MKTEMP_COUNTER_FILE" PATH="$MKTEMP_SHIM_DIR:$PATH" \
  bash "$SCRIPT" --alloc --stem T-097-test-mktempsecondfail --reviews-dir "$REVIEWS_DIR" >"$out" 2>"$err"
rc=$?
set -e

[[ "$rc" -eq 2 ]] \
  || fail "mktemp-second-fail-no-leak: expected exit 2 (die 2 on second-mktemp failure), got $rc (stderr: $(cat "$err"))"
mktempfail_leftover="$(find "$REVIEWS_DIR" -maxdepth 1 -name '.codex-capture.T-097-test-mktempsecondfail.*' 2>/dev/null)"
[[ -z "$mktempfail_leftover" ]] \
  || fail "mktemp-second-fail-no-leak: .codex-capture.* raw orphaned after a second-mktemp failure (the DP-C early-armed EXIT trap should have cleaned the first raw): $mktempfail_leftover"
pass "mktemp-second-fail-no-leak — a second-mktemp failure inside --alloc exits 2 (die 2), and the first raw is cleaned by the EXIT trap armed right after the first mktemp succeeds (no .codex-capture.* orphan under the reviews dir)"

# =============================================================================
# alloc-paths-in-reviews-dir (T-107, DP-a/DP-b)
# =============================================================================
printf -- '\n--- alloc-paths-in-reviews-dir ---\n'
ALLOC_STEM="T-107-test-allocpaths"
set +e
alloc_stdout="$(bash "$SCRIPT" --alloc --stem "$ALLOC_STEM" --reviews-dir "$REVIEWS_DIR" 2>"$err")"
alloc_rc=$?
set -e
[[ "$alloc_rc" -eq 0 ]] || fail "alloc-paths-in-reviews-dir: expected --alloc exit 0, got $alloc_rc (stderr: $(cat "$err"))"
alloc_line_count="$(printf '%s\n' "$alloc_stdout" | wc -l | tr -d '[:space:]')"
[[ "$alloc_line_count" -eq 2 ]] \
  || fail "alloc-paths-in-reviews-dir: expected exactly 2 stdout lines from --alloc, got $alloc_line_count: $alloc_stdout"
alloc_p1="${alloc_stdout%%$'\n'*}"
alloc_p2="${alloc_stdout##*$'\n'}"
[[ -f "$alloc_p1" ]] || fail "alloc-paths-in-reviews-dir: line 1 path is not a regular file: $alloc_p1"
[[ -f "$alloc_p2" ]] || fail "alloc-paths-in-reviews-dir: line 2 path is not a regular file: $alloc_p2"
alloc_p1_dirname="$(cd "$(dirname -- "$alloc_p1")" && pwd)"
alloc_p2_dirname="$(cd "$(dirname -- "$alloc_p2")" && pwd)"
[[ "$alloc_p1_dirname" == "$REVIEWS_DIR" ]] \
  || fail "alloc-paths-in-reviews-dir: line 1 path's parent ($alloc_p1_dirname) is not the reviews dir ($REVIEWS_DIR): $alloc_p1"
[[ "$alloc_p2_dirname" == "$REVIEWS_DIR" ]] \
  || fail "alloc-paths-in-reviews-dir: line 2 path's parent ($alloc_p2_dirname) is not the reviews dir ($REVIEWS_DIR): $alloc_p2"
case "$(basename -- "$alloc_p1")" in
  ".codex-capture.$ALLOC_STEM.out."*) : ;;
  *) fail "alloc-paths-in-reviews-dir: line 1 basename does not carry the expected .codex-capture.$ALLOC_STEM.out.* prefix: $alloc_p1" ;;
esac
case "$(basename -- "$alloc_p2")" in
  ".codex-capture.$ALLOC_STEM.jsonl."*) : ;;
  *) fail "alloc-paths-in-reviews-dir: line 2 basename does not carry the expected .codex-capture.$ALLOC_STEM.jsonl.* prefix: $alloc_p2" ;;
esac
rm -f "$alloc_p1" "$alloc_p2"
pass "alloc-paths-in-reviews-dir — --alloc exits 0, prints exactly 2 stdout lines, both regular files directly under the resolved reviews dir with the expected .codex-capture.<stem>.{out,jsonl}. basename prefixes"

# =============================================================================
# publish-foreign-path-reject (T-107, DP-b — most important)
# =============================================================================
printf -- '\n--- publish-foreign-path-reject ---\n'
PFR_STEM="T-107-test-foreignpath"

# (a) raw's parent directory is OUTSIDE the reviews dir (the $TMPDIR-raw
# cross-fs-degrade case DP-b exists to close).
PFR_FOREIGN_DIR="$TMP/pfr-foreign"
mkdir -p "$PFR_FOREIGN_DIR"
pfr_foreign_out="$PFR_FOREIGN_DIR/.codex-capture.$PFR_STEM.out.deadbeef"
pfr_foreign_jsonl="$PFR_FOREIGN_DIR/.codex-capture.$PFR_STEM.jsonl.deadbeef"
printf 'foreign-dir content\n' > "$pfr_foreign_out"
printf '{"type":"item.completed"}\n' > "$pfr_foreign_jsonl"
set +e
bash "$SCRIPT" --publish --stem "$PFR_STEM" --reviews-dir "$REVIEWS_DIR" \
  --publish-out "$pfr_foreign_out" --publish-jsonl "$pfr_foreign_jsonl" >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "publish-foreign-path-reject (foreign dir): expected exit 2, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/$PFR_STEM.txt" ]] || fail "publish-foreign-path-reject (foreign dir): canonical .txt must not exist after a refused publish"
[[ -f "$pfr_foreign_out" ]] || fail "publish-foreign-path-reject (foreign dir): the foreign raw must not have been mv'd away"

# (b) raw does not exist at all (codex died before writing it).
pfr_missing_out="$REVIEWS_DIR/.codex-capture.$PFR_STEM.out.doesnotexist"
pfr_missing_jsonl="$REVIEWS_DIR/.codex-capture.$PFR_STEM.jsonl.doesnotexist"
set +e
bash "$SCRIPT" --publish --stem "$PFR_STEM" --reviews-dir "$REVIEWS_DIR" \
  --publish-out "$pfr_missing_out" --publish-jsonl "$pfr_missing_jsonl" >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "publish-foreign-path-reject (missing raw): expected exit 2, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/$PFR_STEM.txt" ]] || fail "publish-foreign-path-reject (missing raw): canonical .txt must not exist after a refused publish"

# (c) raw exists, correct directory, but basename's stem prefix mismatches.
alloc_and_mock happy "$PFR_STEM-other"
set +e
bash "$SCRIPT" --publish --stem "$PFR_STEM" --reviews-dir "$REVIEWS_DIR" \
  --publish-out "$raw_out" --publish-jsonl "$raw_jsonl" >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "publish-foreign-path-reject (stem mismatch): expected exit 2, got $rc (stderr: $(cat "$err"))"
[[ ! -e "$REVIEWS_DIR/$PFR_STEM.txt" ]] || fail "publish-foreign-path-reject (stem mismatch): canonical .txt must not exist after a refused publish"
rm -f "$raw_out" "$raw_jsonl"

# Non-vacuity: the SAME kind of content publishes successfully (exit 0) when
# routed through a legitimate --alloc path -- proving the rejects above are
# about PLACEMENT, not content.
alloc_and_mock happy "$PFR_STEM-legit"
run_publish "$PFR_STEM-legit"
[[ "$rc" -eq 0 ]] \
  || fail "publish-foreign-path-reject (non-vacuity): expected the SAME content routed through a legitimate --alloc path to publish with exit 0, got $rc (stderr: $(cat "$err"))"
[[ -f "$REVIEWS_DIR/$PFR_STEM-legit.txt" ]] \
  || fail "publish-foreign-path-reject (non-vacuity): canonical .txt missing after a legitimate publish"

# (d) T-107 round1 Codex review Major #1 regression: a symlink ALIAS pointing
# at the SAME physical reviews dir must NOT be treated as a foreign path --
# `--alloc` via the alias spelling, then `--publish` via the real (or a
# different alias) spelling of the SAME physical directory, must succeed
# (exit 0). Before the `pwd -P` fix this was a false-positive exit 2 (the
# reviewer's own reproduction, run against a scratch dir outside this repo).
PFR_REAL_DIR="$TMP/pfr-symlink-real"
PFR_ALIAS_DIR="$TMP/pfr-symlink-alias"
mkdir -p "$PFR_REAL_DIR"
ln -s "$PFR_REAL_DIR" "$PFR_ALIAS_DIR"
PFR_SYM_STEM="T-107-test-symlinkalias"
alloc_out="$(bash "$SCRIPT" --alloc --stem "$PFR_SYM_STEM" --reviews-dir "$PFR_ALIAS_DIR")"
sym_raw_out="${alloc_out%%$'\n'*}"
sym_raw_jsonl="${alloc_out##*$'\n'}"
printf 'content published via symlink alias\n' > "$sym_raw_out"
printf '{"type":"item.completed"}\n' > "$sym_raw_jsonl"
set +e
bash "$SCRIPT" --publish --stem "$PFR_SYM_STEM" --reviews-dir "$PFR_REAL_DIR" \
  --publish-out "$sym_raw_out" --publish-jsonl "$sym_raw_jsonl" >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 0 ]] \
  || fail "publish-foreign-path-reject (symlink-alias same-dir, Major#1 regression): expected exit 0 (--alloc via a symlink alias then --publish via the real path of the SAME physical directory must succeed under pwd -P canonicalization), got $rc (stderr: $(cat "$err"))"
[[ -f "$PFR_REAL_DIR/$PFR_SYM_STEM.txt" ]] \
  || fail "publish-foreign-path-reject (symlink-alias same-dir, Major#1 regression): canonical .txt missing after what should be a successful publish"

# (e) mutation-before-submit for the (d) fix: a GENUINELY different physical
# directory, reached through an unrelated alias, must still be REJECTED
# (exit 2) -- proving the pwd -P canonicalization closed the false-positive
# in (d) WITHOUT loosening the fail-closed guarantee (a)-(c) rely on.
PFR_OTHER_REAL_DIR="$TMP/pfr-symlink-other-real"
mkdir -p "$PFR_OTHER_REAL_DIR"
PFR_OTHER_STEM="T-107-test-symlinkalias-otherdir"
alloc_out="$(bash "$SCRIPT" --alloc --stem "$PFR_OTHER_STEM" --reviews-dir "$PFR_OTHER_REAL_DIR")"
other_raw_out="${alloc_out%%$'\n'*}"
other_raw_jsonl="${alloc_out##*$'\n'}"
printf 'content from a genuinely different physical directory\n' > "$other_raw_out"
printf '{"type":"item.completed"}\n' > "$other_raw_jsonl"
set +e
bash "$SCRIPT" --publish --stem "$PFR_OTHER_STEM" --reviews-dir "$PFR_ALIAS_DIR" \
  --publish-out "$other_raw_out" --publish-jsonl "$other_raw_jsonl" >"$out" 2>"$err"
rc=$?
set -e
[[ "$rc" -eq 2 ]] \
  || fail "publish-foreign-path-reject (genuinely different physical dir via an unrelated alias, mutation-before-submit): expected exit 2 (the pwd -P fix must NOT loosen fail-closed rejection of a truly foreign directory), got $rc (stderr: $(cat "$err"))"
[[ ! -e "$PFR_ALIAS_DIR/$PFR_OTHER_STEM.txt" ]] \
  || fail "publish-foreign-path-reject (genuinely different physical dir via an unrelated alias): canonical .txt must not exist after what should be a refused publish"

pass "publish-foreign-path-reject — --publish refuses (exit 2, no mv attempted, no canonical created) a raw outside the reviews dir, a nonexistent raw, a raw whose basename stem mismatches, and (mutation-before-submit) a genuinely different physical directory reached via an unrelated symlink alias; the same content published via a legitimate --alloc path succeeds (exit 0, non-vacuous), and (T-107 round1 Major#1 regression) a symlink-alias reference to the SAME physical reviews dir now succeeds too (pwd -P canonicalization closes the false-positive without loosening fail-closed rejection)"

# =============================================================================
# wrapper-never-execs-codex (T-107, DP-e/DP-j — behavioral teeth)
# =============================================================================
printf -- '\n--- wrapper-never-execs-codex ---\n'
CODEX_SENTINEL_DIR="$TMP/codex-sentinel-shim"
mkdir -p "$CODEX_SENTINEL_DIR"
WNEC_SENTINEL="$TMP/wrapper-never-execs-codex.sentinel"
rm -f "$WNEC_SENTINEL"
cat > "$CODEX_SENTINEL_DIR/codex" <<'CODEXSHIM'
#!/usr/bin/env bash
# Sentinel shim: if ANYTHING ever execs a program named `codex` while this
# directory is first on PATH, this file writes a sentinel marker. Neither
# --alloc nor --publish should ever cause this to run post-T-107-split.
: > "${WNEC_SENTINEL:?WNEC_SENTINEL must be set}"
exit 0
CODEXSHIM
chmod +x "$CODEX_SENTINEL_DIR/codex"

WNEC_STEM="T-107-test-wrapperneverexec"
set +e
wnec_alloc_out="$(WNEC_SENTINEL="$WNEC_SENTINEL" PATH="$CODEX_SENTINEL_DIR:$PATH" \
  bash "$SCRIPT" --alloc --stem "$WNEC_STEM" --reviews-dir "$REVIEWS_DIR" 2>"$err")"
wnec_alloc_rc=$?
set -e
[[ "$wnec_alloc_rc" -eq 0 ]] || fail "wrapper-never-execs-codex: expected --alloc exit 0, got $wnec_alloc_rc (stderr: $(cat "$err"))"
wnec_raw_out="${wnec_alloc_out%%$'\n'*}"
wnec_raw_jsonl="${wnec_alloc_out##*$'\n'}"
printf 'wrapper-never-execs-codex content\n' > "$wnec_raw_out"
printf '{"type":"item.completed"}\n' > "$wnec_raw_jsonl"
set +e
WNEC_SENTINEL="$WNEC_SENTINEL" PATH="$CODEX_SENTINEL_DIR:$PATH" \
  bash "$SCRIPT" --publish --stem "$WNEC_STEM" --reviews-dir "$REVIEWS_DIR" \
  --publish-out "$wnec_raw_out" --publish-jsonl "$wnec_raw_jsonl" >"$out" 2>"$err"
wnec_publish_rc=$?
set -e
[[ "$wnec_publish_rc" -eq 0 ]] || fail "wrapper-never-execs-codex: expected --publish exit 0, got $wnec_publish_rc (stderr: $(cat "$err"))"
[[ ! -e "$WNEC_SENTINEL" ]] \
  || fail "wrapper-never-execs-codex: sentinel file was created -- something named 'codex' was executed during --alloc/--publish"
pass "wrapper-never-execs-codex — with a sentinel-writing 'codex' shim first on PATH, a full --alloc + --publish run never creates the sentinel (neither mode ever execs anything named codex)"

# =============================================================================
# agentmd-bare-codex-present (T-107, DP-g①)
# =============================================================================
printf -- '\n--- agentmd-bare-codex-present ---\n'
CODEX_REVIEWER_MD="$REPO_ROOT/agents/codex-reviewer.md"
DRIFT_EVALUATOR_MD="$REPO_ROOT/agents/drift-evaluator.md"
BARE_CODEX_RE='^[[:space:]]*codex exec '

set +e
reviewer_bare_count="$(grep -cE "$BARE_CODEX_RE" "$CODEX_REVIEWER_MD")"
reviewer_bare_rc=$?
set -e
[[ "$reviewer_bare_rc" -eq 0 ]] \
  || fail "agentmd-bare-codex-present: expected grep rc=0 (match found) for bare 'codex exec ' lines in agents/codex-reviewer.md, got rc=$reviewer_bare_rc (>=2 = grep execution error, e.g. the file went missing — must fail closed)"
[[ "$reviewer_bare_count" -eq 2 ]] \
  || fail "agentmd-bare-codex-present: expected exactly 2 bare 'codex exec ' lines in agents/codex-reviewer.md, got $reviewer_bare_count"

set +e
drift_bare_count="$(grep -cE "$BARE_CODEX_RE" "$DRIFT_EVALUATOR_MD")"
drift_bare_rc=$?
set -e
[[ "$drift_bare_rc" -eq 0 ]] \
  || fail "agentmd-bare-codex-present: expected grep rc=0 (match found) for bare 'codex exec ' lines in agents/drift-evaluator.md, got rc=$drift_bare_rc (>=2 = grep execution error — must fail closed)"
[[ "$drift_bare_count" -eq 1 ]] \
  || fail "agentmd-bare-codex-present: expected exactly 1 bare 'codex exec ' line in agents/drift-evaluator.md, got $drift_bare_count"

# AC10's confirmed full-sentence alloc/publish forms, same 2 files.
grep -Fq -- '--alloc --stem T-XXX-codex-primary' "$CODEX_REVIEWER_MD" \
  || fail "agentmd-bare-codex-present: missing '--alloc --stem T-XXX-codex-primary' in agents/codex-reviewer.md"
grep -Fq -- '--alloc --stem T-XXX-codex-adversarial' "$CODEX_REVIEWER_MD" \
  || fail "agentmd-bare-codex-present: missing '--alloc --stem T-XXX-codex-adversarial' in agents/codex-reviewer.md"
grep -Fq -- '--alloc --stem T-XXX-drift-codex' "$DRIFT_EVALUATOR_MD" \
  || fail "agentmd-bare-codex-present: missing '--alloc --stem T-XXX-drift-codex' in agents/drift-evaluator.md"
# shellcheck disable=SC2016  # deliberately literal -F pattern, not a shell expansion.
grep -Fq -- '--publish --stem T-XXX-codex-primary --publish-out "<RAW_OUT>" --publish-jsonl "<RAW_JSONL>"' "$CODEX_REVIEWER_MD" \
  || fail "agentmd-bare-codex-present: missing the primary --publish full-sentence form in agents/codex-reviewer.md"
# shellcheck disable=SC2016
grep -Fq -- '--publish --stem T-XXX-codex-adversarial --publish-out "<RAW_OUT>" --publish-jsonl "<RAW_JSONL>"' "$CODEX_REVIEWER_MD" \
  || fail "agentmd-bare-codex-present: missing the adversarial --publish full-sentence form in agents/codex-reviewer.md"
# shellcheck disable=SC2016
grep -Fq -- '--publish --stem T-XXX-drift-codex --publish-out "<RAW_OUT>" --publish-jsonl "<RAW_JSONL>"' "$DRIFT_EVALUATOR_MD" \
  || fail "agentmd-bare-codex-present: missing the drift --publish full-sentence form in agents/drift-evaluator.md"
pass "agentmd-bare-codex-present — agents/codex-reviewer.md / agents/drift-evaluator.md carry exactly 2 / 1 bare 'codex exec ' lines and every AC10 confirmed --alloc/--publish full-sentence form (grep rc=0 required)"

# =============================================================================
# agentmd-wrapped-form-absent (T-107, DP-g②; round4 extends with AC27's
# rc-threading vocabulary — DP-c①/④)
# =============================================================================
printf -- '\n--- agentmd-wrapped-form-absent ---\n'
# shellcheck disable=SC2016  # deliberately literal -F patterns, not shell expansions.
OLD_FORM_PATTERNS=('@CODEX_OUT@' 'tmp_out=$(mktemp)' 'cp "$tmp_out"')
# shellcheck disable=SC2016
RC_THREADING_PATTERNS=('codex_status' 'publish_status' 'raw="$(codex-capture.sh' '${raw%%' '"$raw_out"' '"$raw_jsonl"' 'Capture each command' 'happens to preserve shell state')
for pat in "${OLD_FORM_PATTERNS[@]}" "${RC_THREADING_PATTERNS[@]}"; do
  set +e
  grep -nF -- "$pat" "$CODEX_REVIEWER_MD" "$DRIFT_EVALUATOR_MD" > "$TMP/agentmd-wrapped-form-absent.out"
  wfa_rc=$?
  set -e
  [[ "$wfa_rc" -eq 1 ]] \
    || fail "agentmd-wrapped-form-absent: expected grep rc=1 (clean, zero matches) for retired literal '$pat' across agents/codex-reviewer.md + agents/drift-evaluator.md, got rc=$wfa_rc (0=old form resurfaced; >=2=grep execution error — must fail closed): $(cat "$TMP/agentmd-wrapped-form-absent.out" 2>/dev/null)"
done
pass "agentmd-wrapped-form-absent — none of the retired inline-hygiene literals (@CODEX_OUT@ / tmp_out=\$(mktemp) / cp \"\$tmp_out\") NOR the round4-retired rc-threading vocabulary (codex_status / publish_status / raw= capture / \${raw%%} / \"\$raw_out\" / \"\$raw_jsonl\" / the old same-invocation-\$? sentence / the shell-state-preserving fallback sentence) appear in agents/codex-reviewer.md or agents/drift-evaluator.md (grep rc=1 required for each)"

# =============================================================================
# agentmd-mutation-present (T-107, DP-g③, non-vacuous counterfactual)
# =============================================================================
printf -- '\n--- agentmd-mutation-present ---\n'
MUT_BARE_FILE="$TMP/mutated-bare-codex-reviewer.md"
awk '
  /^[[:space:]]*codex exec / && !done {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    rest = substr($0, RLENGTH + 1)
    print indent "cd <repo> && " rest
    done = 1
    next
  }
  { print }
' "$CODEX_REVIEWER_MD" > "$MUT_BARE_FILE"
mut_bare_count="$(grep -cE "$BARE_CODEX_RE" "$MUT_BARE_FILE" || true)"
[[ "$mut_bare_count" -eq $((reviewer_bare_count - 1)) ]] \
  || fail "agentmd-mutation-present: expected the mutated copy (one bare line rewritten to 'cd <repo> && codex exec ...') to show $((reviewer_bare_count - 1)) bare 'codex exec ' lines (one fewer than the live file's $reviewer_bare_count), got $mut_bare_count — the present-lock would be vacuous"
pass "agentmd-mutation-present — rewriting one bare 'codex exec ' line to a 'cd <repo> && codex exec ...' wrapped form in a mutated copy REDUCES the bare-line count from $reviewer_bare_count to $mut_bare_count (non-vacuous: proves the agentmd-bare-codex-present lock actually detects this regression)"

# =============================================================================
# agentmd-mutation-absent (T-107, DP-g③, non-vacuous counterfactual; round4
# extends the injected probes with the retired rc-threading vocabulary)
# =============================================================================
printf -- '\n--- agentmd-mutation-absent ---\n'
MUT_OLDFORM_FILE="$TMP/mutated-oldform-codex-reviewer.md"
cp "$CODEX_REVIEWER_MD" "$MUT_OLDFORM_FILE"
# shellcheck disable=SC2016  # deliberately literal probe lines, not shell expansions.
cat >> "$MUT_OLDFORM_FILE" <<'PROBES'
regression probe: codex-capture.sh --stem T-XXX-probe -- codex exec --sandbox read-only --cd <repo> --json -o @CODEX_OUT@
regression probe: tmp_out=$(mktemp)
regression probe: cp "$tmp_out" "$dest"
regression probe: codex_status=$?
regression probe: publish_status=$?
regression probe: raw="$(codex-capture.sh --alloc --stem T-XXX-probe)"
regression probe: raw_out="${raw%%$'\n'*}"
regression probe: -o "$raw_out"
regression probe: > "$raw_jsonl"
regression probe: Capture each command's $? in the same invocation
regression probe: happens to preserve shell state across all three steps
PROBES

n=0
for pat in "${OLD_FORM_PATTERNS[@]}" "${RC_THREADING_PATTERNS[@]}"; do
  n=$((n + 1))
  outfile="$TMP/agentmd-mutation-absent.$n.out"
  set +e
  grep -nF -- "$pat" "$MUT_OLDFORM_FILE" > "$outfile"
  mut_abs_rc=$?
  set -e
  [[ "$mut_abs_rc" -eq 0 ]] \
    || fail "agentmd-mutation-absent: expected the injected retired literal '$pat' to be DETECTED (grep rc=0) in the mutated copy, got rc=$mut_abs_rc — the agentmd-wrapped-form-absent lock would be vacuous"
done
pass "agentmd-mutation-absent — injecting each retired inline-hygiene literal (@CODEX_OUT@ / tmp_out=\$(mktemp) / cp \"\$tmp_out\") AND each round4-retired rc-threading literal into a mutated copy IS detected (grep rc=0) — proving the agentmd-wrapped-form-absent lock actually detects these regressions"

# =============================================================================
# agentmd-fence-structure (T-107, DP-l, round4) + agentmd-fence-mutation
# (T-107, DP-l, round4, non-vacuous — PER SITE)
#
# check_fence_structure FILE: buffers every fenced ```bash block IN FULL
# (round5 redesign — see below), then, for each block that contains a bare
# `# T-107-step: <kind>` marker line (kind in
# alloc/codex/diagnose/cleanup/publish) ANYWHERE in the block, prints one
# "VIOLATION:..." line per structural problem found:
#   - the marker is present but is NOT the block's first non-blank line
#     (round5 Major #1 fix — see below)
#   - the block's first physical content line (the line immediately after
#     the marker, before any backslash-continuation folding) contains an
#     unquoted shell connector token `&&`, `||`, or `;` (round5 Major #2
#     fix — see below)
#   - the block does not fold (comments/blanks excluded, backslash
#     continuations joined) to EXACTLY one logical command
#   - that logical command's first token does not match the kind
#     (alloc/publish -> codex-capture.sh, codex -> codex, diagnose -> cat,
#     cleanup -> rm)
#   - that logical command contains a variable assignment (`name=...` at the
#     start) or a `$( )` command substitution
# A fence with NO T-107-step marker anywhere in it is genuinely untracked
# (e.g. this file's own `git rev-parse`/`git log`/`git diff` diagnostic
# block, or drift-evaluator.md's check-intent/check-provenance grounding
# block) and is silently skipped — marker PRESENCE/COUNT for the tracked
# kinds is asserted separately (AC26, and per-kind counts below).
#
# round5 Major #1 (QA/reviewer, lock-teeth): the PREVIOUS version of this
# function decided "is this fence tracked?" by looking ONLY at the fence's
# first content line — a fence with one extra line inserted BEFORE a
# legitimate `# T-107-step: <kind>` marker was therefore classified as
# untracked and silently skipped (zero violations printed), even though its
# marker (and the rest of its content) were otherwise intact. Buffering the
# whole block and searching every line for the marker (rather than only the
# first) closes this: the marker is still found, the block is still
# recognized as tracked, and "marker present but not first" is now itself a
# violation instead of an unexamined non-finding.
#
# round5 Major #2 (Codex round5, lock-teeth): this function never inspected
# a block's first physical content line for UNQUOTED shell connector tokens
# (`&&`/`||`/`;`) — for the two-line `alloc`/`publish`/`diagnose`/`cleanup`
# blocks (single physical line, no free-form text) and for every site's
# `codex` block's own first physical line (which is command-line flags only
# — `codex exec ... -o "<RAW_OUT>"` — never free-form prose, even for the
# multi-line adversarial/drift `codex` blocks whose SUBSEQUENT lines carry a
# quoted prompt), none of these first physical lines can legitimately
# contain `&&`/`||`/`;` today, so checking that exact line for these tokens
# cannot false-positive on real content and closes an actual shell-level
# command-injection primitive (`&&`/`;`/`||` appended in the unquoted
# region before the prompt's opening quote is a real, literal shell
# operator, not merely a string that "looks like" one).
# =============================================================================
check_fence_structure() {
  local file="$1"
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function process_block(   i, tt, marker_idx, marker_kind, first_content_idx,
                               first_cmd_idx, logical_count, pending, first_token,
                               bad_token_seen, ends_bs, seg, toks) {
      marker_idx = 0; marker_kind = ""
      for (i = 1; i <= nlines; i++) {
        tt = trim(lines[i])
        if (match(tt, /^# T-107-step: (alloc|codex|diagnose|cleanup|publish)$/)) {
          marker_idx = i
          marker_kind = tt
          sub(/^# T-107-step: /, "", marker_kind)
          break
        }
      }
      if (marker_kind == "") { return }  # genuinely untracked fence

      first_content_idx = 0
      for (i = 1; i <= nlines; i++) {
        if (trim(lines[i]) != "") { first_content_idx = i; break }
      }
      if (marker_idx != first_content_idx) {
        printf "VIOLATION:%s:marker-not-first:kind=%s:marker_line=%d:first_content_line=%d\n", FILENAME, marker_kind, marker_idx, first_content_idx
        violations++
        return
      }

      # first physical content line after the marker (pre-fold) -- the
      # round5 Major #2 connector check targets ONLY this raw line.
      first_cmd_idx = 0
      for (i = marker_idx + 1; i <= nlines; i++) {
        tt = trim(lines[i])
        if (tt == "") { continue }
        if (substr(tt,1,1) == "#") { continue }
        first_cmd_idx = i
        break
      }
      if (first_cmd_idx > 0) {
        tt = trim(lines[first_cmd_idx])
        if (index(tt, "&&") > 0 || index(tt, "||") > 0 || tt ~ /;/) {
          printf "VIOLATION:%s:shell-connector-in-first-line:kind=%s:line=%d\n", FILENAME, marker_kind, first_cmd_idx
          violations++
          return
        }
      }

      logical_count = 0; pending = ""; first_token = ""; bad_token_seen = 0
      for (i = marker_idx + 1; i <= nlines; i++) {
        tt = trim(lines[i])
        if (tt == "") { continue }
        if (substr(tt,1,1) == "#") { continue }
        ends_bs = (substr(tt, length(tt), 1) == "\\")
        seg = tt
        if (ends_bs == 1) { sub(/\\$/, "", seg) }
        if (pending != "") { pending = pending " " seg } else { pending = seg }
        if (ends_bs == 1) { continue }
        logical_count++
        split(pending, toks, /[ \t]+/)
        if (logical_count == 1) { first_token = toks[1] }
        if (pending ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { bad_token_seen = 1 }
        if (index(pending, "$(") > 0) { bad_token_seen = 1 }
        pending = ""
      }
      if (logical_count != 1) {
        printf "VIOLATION:%s:not-exactly-one-logical-command:kind=%s:count=%d\n", FILENAME, marker_kind, logical_count
        violations++
      } else if (first_token != expect_tok[marker_kind]) {
        printf "VIOLATION:%s:wrong-first-token:kind=%s:got=%s:want=%s\n", FILENAME, marker_kind, first_token, expect_tok[marker_kind]
        violations++
      } else if (bad_token_seen == 1) {
        printf "VIOLATION:%s:variable-or-subshell-present:kind=%s\n", FILENAME, marker_kind
        violations++
      }
    }
    BEGIN {
      expect_tok["alloc"]="codex-capture.sh"; expect_tok["publish"]="codex-capture.sh"
      expect_tok["codex"]="codex"; expect_tok["diagnose"]="cat"; expect_tok["cleanup"]="rm"
      in_fence=0; violations=0; nlines=0
    }
    {
      t = trim($0)
      is_fence = (substr(t,1,3) == "```")
      if (is_fence && in_fence == 0) {
        in_fence = 1; nlines = 0
        next
      }
      if (is_fence && in_fence == 1) {
        process_block()
        in_fence = 0
        next
      }
      if (in_fence == 1) {
        nlines++
        lines[nlines] = $0
      }
    }
    END { exit (violations > 0) ? 1 : 0 }
  ' "$file"
}

printf -- '\n--- agentmd-fence-structure ---\n'
set +e
reviewer_struct_out="$(check_fence_structure "$CODEX_REVIEWER_MD")"
reviewer_struct_rc=$?
set -e
[[ "$reviewer_struct_rc" -eq 0 ]] \
  || fail "agentmd-fence-structure: agents/codex-reviewer.md has structural violations: $reviewer_struct_out"
set +e
drift_struct_out="$(check_fence_structure "$DRIFT_EVALUATOR_MD")"
drift_struct_rc=$?
set -e
[[ "$drift_struct_rc" -eq 0 ]] \
  || fail "agentmd-fence-structure: agents/drift-evaluator.md has structural violations: $drift_struct_out"
for kind in alloc codex diagnose cleanup publish; do
  kc_reviewer="$(grep -cE "^[[:space:]]*# T-107-step: ${kind}\$" "$CODEX_REVIEWER_MD")"
  [[ "$kc_reviewer" -eq 2 ]] \
    || fail "agentmd-fence-structure: expected exactly 2 '# T-107-step: $kind' markers in agents/codex-reviewer.md (one per site), got $kc_reviewer"
  kc_drift="$(grep -cE "^[[:space:]]*# T-107-step: ${kind}\$" "$DRIFT_EVALUATOR_MD")"
  [[ "$kc_drift" -eq 1 ]] \
    || fail "agentmd-fence-structure: expected exactly 1 '# T-107-step: $kind' marker in agents/drift-evaluator.md, got $kc_drift"
done
pass "agentmd-fence-structure — every T-107-step block in both live agent files folds to exactly one logical command with the kind-matching first token and no variable assignment / \$( ), and each of the 5 kinds appears exactly once per site (2 sites in codex-reviewer.md, 1 in drift-evaluator.md)"

printf -- '\n--- agentmd-fence-mutation ---\n'
# mutate_fence_site FILE SITE_N MODE OUTFILE — SITE_N is the 1-based
# occurrence index of the marker of the given kind within FILE (site 1 =
# first site in file order, i.e. primary for codex-reviewer.md / the only
# site for drift-evaluator.md; site 2 = adversarial, codex-reviewer.md only).
# MODE is one of: assign | merge | delmarker | preline | connector (preline
# and connector are the round5 additions closing Major #1/#2 -- see the
# docstring above check_fence_structure()). Never touches the real repo
# files -- always reads FILE and writes a NEW copy to OUTFILE.
mutate_fence_site() {
  local file="$1" site_n="$2" mode="$3" outfile="$4"
  python3 - "$file" "$site_n" "$mode" "$outfile" <<'PYEOF'
import re
import sys

src, site_n, mode, dst = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
with open(src, encoding="utf-8") as f:
    lines = f.readlines()


def nth_marker_index(kind, n):
    pat = re.compile(r"^#\s*T-107-step:\s*" + kind + r"\s*$")
    count = 0
    for i, line in enumerate(lines):
        if pat.match(line.strip()):
            count += 1
            if count == n:
                return i
    raise SystemExit(f"marker for kind={kind} occurrence {n} not found in {src}")


if mode == "assign":
    idx = nth_marker_index("codex", site_n)
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    lines.insert(idx + 1, indent + "codex_status=0\n")
elif mode == "merge":
    d_idx = nth_marker_index("diagnose", site_n)
    c_idx = nth_marker_index("cleanup", site_n)
    # the cleanup block's command line is the line right after its marker
    cleanup_cmd_line = lines[c_idx + 1]
    del lines[c_idx + 1]
    lines.insert(d_idx + 2, cleanup_cmd_line)
elif mode == "delmarker":
    idx = nth_marker_index("alloc", site_n)
    del lines[idx]
elif mode == "preline":
    # round5 Major #1 repro: insert an extra line BEFORE a legitimate
    # marker (the marker itself, and everything after it, is untouched) --
    # the marker is no longer the block's first content line.
    idx = nth_marker_index("alloc", site_n)
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    lines.insert(idx, indent + "true\n")
elif mode == "connector":
    # round5 Major #2 repro: inject an UNQUOTED "&& touch ..." connector
    # into the codex block's first physical line, right after the closing
    # quote of the -o "<RAW_OUT>" flag (still outside any quoted region for
    # every site, including the multi-line adversarial/drift prompts, whose
    # quoted text starts on the NEXT physical line).
    idx = nth_marker_index("codex", site_n)
    cmd_line = lines[idx + 1]
    marker = '-o "<RAW_OUT>"'
    if marker not in cmd_line:
        raise SystemExit(f"connector mutation anchor {marker!r} not found in: {cmd_line!r}")
    lines[idx + 1] = cmd_line.replace(marker, marker + " && touch /tmp/pwned-test", 1)
elif mode == "tailconnector":
    # T-111 form 2 (T-107 round6-A repro): append an UNQUOTED connector AFTER
    # the block's LAST content line -- i.e. after the trailing `> "<RAW_JSONL>"
    # 2>&1` redirection, which is outside every quoted region. The round4/5
    # connector check only ever inspected the block's FIRST physical line, so
    # this injection position is invisible to it by construction.
    idx = nth_marker_index("codex", site_n)
    end = idx + 1
    while end < len(lines) and lines[end].strip() != "```":
        end += 1
    if end >= len(lines):
        raise SystemExit(f"tailconnector: closing fence not found after marker line {idx + 1}")
    last = end - 1
    while last > idx and lines[last].strip() == "":
        last -= 1
    if last <= idx:
        raise SystemExit(f"tailconnector: block after marker line {idx + 1} has no content line")
    lines[last] = lines[last].rstrip("\n") + " && touch /tmp/pwned-test\n"
elif mode == "midbacktick":
    # T-111 form 3 (T-107 round6-B repro): insert a BACKTICK command
    # substitution into a line strictly INSIDE the double-quoted prompt.
    # Backticks -- unlike `&&` / `;` -- are NOT neutralized inside double
    # quotes, so a line the round4/5 checker treats as "quoted prose, safe by
    # construction" still carries a live execution primitive.
    idx = nth_marker_index("codex", site_n)
    end = idx + 1
    while end < len(lines) and lines[end].strip() != "```":
        end += 1
    if end >= len(lines):
        raise SystemExit(f"midbacktick: closing fence not found after marker line {idx + 1}")
    # Block layout for both free-text sites: marker / codex-exec flag line /
    # opening-quote prompt line / <- this one, strictly inside the quotes.
    target = idx + 3
    if target >= end:
        raise SystemExit(f"midbacktick: block after marker line {idx + 1} has no in-prompt line to target")
    indent = lines[target][: len(lines[target]) - len(lines[target].lstrip())]
    lines[target] = indent + "`touch /tmp/pwned-test` " + lines[target].lstrip()
else:
    raise SystemExit(f"unknown mode: {mode}")

with open(dst, "w", encoding="utf-8") as f:
    f.writelines(lines)
PYEOF
}

# --- site 1 = codex-reviewer.md primary --------------------------------------
for mode in assign merge delmarker preline connector; do
  MUT="$TMP/fence-mutation-reviewer-site1-$mode.md"
  mutate_fence_site "$CODEX_REVIEWER_MD" 1 "$mode" "$MUT"
  if [ "$mode" = "delmarker" ]; then
    kc="$(grep -cE '^[[:space:]]*# T-107-step: alloc$' "$MUT")"
    [[ "$kc" -eq 1 ]] \
      || fail "agentmd-fence-mutation: site1(primary)/delmarker: expected the total 'alloc' marker count in the mutated copy to drop from 2 to 1, got $kc"
  else
    set +e
    check_fence_structure "$MUT" >/dev/null
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] \
      || fail "agentmd-fence-mutation: site1(primary)/$mode mutation was NOT caught by agentmd-fence-structure (rc=0) — the per-site lock would be vacuous"
  fi
done
pass "agentmd-fence-mutation — site1 (codex-reviewer.md primary): each of the 5 mutations (assign/merge/delmarker/preline/connector), applied ALONE, is independently caught"

# --- site 2 = codex-reviewer.md adversarial ----------------------------------
for mode in assign merge delmarker preline connector; do
  MUT="$TMP/fence-mutation-reviewer-site2-$mode.md"
  mutate_fence_site "$CODEX_REVIEWER_MD" 2 "$mode" "$MUT"
  if [ "$mode" = "delmarker" ]; then
    kc="$(grep -cE '^[[:space:]]*# T-107-step: alloc$' "$MUT")"
    [[ "$kc" -eq 1 ]] \
      || fail "agentmd-fence-mutation: site2(adversarial)/delmarker: expected the total 'alloc' marker count in the mutated copy to drop from 2 to 1, got $kc"
  else
    set +e
    check_fence_structure "$MUT" >/dev/null
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] \
      || fail "agentmd-fence-mutation: site2(adversarial)/$mode mutation was NOT caught by agentmd-fence-structure (rc=0) — the per-site lock would be vacuous"
  fi
done
pass "agentmd-fence-mutation — site2 (codex-reviewer.md adversarial): each of the 5 mutations (assign/merge/delmarker/preline/connector), applied ALONE, is independently caught"

# --- site 3 = drift-evaluator.md (only site in that file) -------------------
for mode in assign merge delmarker preline connector; do
  MUT="$TMP/fence-mutation-drift-site1-$mode.md"
  mutate_fence_site "$DRIFT_EVALUATOR_MD" 1 "$mode" "$MUT"
  if [ "$mode" = "delmarker" ]; then
    kc="$(grep -cE '^[[:space:]]*# T-107-step: alloc$' "$MUT" || true)"
    [[ "$kc" -eq 0 ]] \
      || fail "agentmd-fence-mutation: site3(drift)/delmarker: expected the 'alloc' marker to be gone in the mutated copy, still found $kc"
  else
    set +e
    check_fence_structure "$MUT" >/dev/null
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] \
      || fail "agentmd-fence-mutation: site3(drift)/$mode mutation was NOT caught by agentmd-fence-structure (rc=0) — the per-site lock would be vacuous"
  fi
done
pass "agentmd-fence-mutation — site3 (drift-evaluator.md): each of the 5 mutations (assign/merge/delmarker/preline/connector), applied ALONE, is independently caught"

# --- controls: unmodified copies of both files must still PASS --------------
CTRL_REVIEWER="$TMP/fence-mutation-control-reviewer.md"
CTRL_DRIFT="$TMP/fence-mutation-control-drift.md"
cp "$CODEX_REVIEWER_MD" "$CTRL_REVIEWER"
cp "$DRIFT_EVALUATOR_MD" "$CTRL_DRIFT"
set +e
check_fence_structure "$CTRL_REVIEWER" >/dev/null
ctrl_reviewer_rc=$?
check_fence_structure "$CTRL_DRIFT" >/dev/null
ctrl_drift_rc=$?
set -e
[[ "$ctrl_reviewer_rc" -eq 0 ]] || fail "agentmd-fence-mutation: control copy of agents/codex-reviewer.md unexpectedly FAILs agentmd-fence-structure"
[[ "$ctrl_drift_rc" -eq 0 ]] || fail "agentmd-fence-mutation: control copy of agents/drift-evaluator.md unexpectedly FAILs agentmd-fence-structure"
pass "agentmd-fence-mutation — unmodified control copies of both agent files still PASS agentmd-fence-structure (3 sites x 5 mutations = 15 independent non-vacuity proofs, plus 2 controls)"

# =============================================================================
# agentmd-block-verbatim (T-111, #356) + agentmd-block-verbatim-mutation
# (T-111, non-vacuous — PER SITE, PER INJECTION FORM)
#
# Two labeled cases beyond the twenty-six enumerated at the top of this file.
#
# WHAT THIS CLOSES. T-107 round5/round6 demonstrated a structural ceiling in
# check_fence_structure() above: it enumerates FORBIDDEN token patterns, so
# every pattern added closes one face and leaves the adjacent one open. Three
# injection positions were demonstrated and left open when T-107 was cut short
# (DP-n, threat model narrowed to accidental regression):
#   1. an unquoted connector on the block's FIRST physical line
#      (closed by the round5 `connector` check above),
#   2. an unquoted connector appended AFTER the block's LAST line — past the
#      trailing redirection, outside every quoted region (still open: the
#      round5 check only ever inspects the first line),
#   3. a BACKTICK command substitution inside the double-quoted prompt —
#      backticks, unlike `&&` / `;`, are NOT neutralized by double quotes, so
#      lines the checker treats as inert prose still carry a live primitive
#      (still open: command-substitution detection looks for `$(` only).
#
# WHY EQUALITY RATHER THAN A WIDER LEXER (T-111 design decision, #356).
# Measured on the live files: of the 15 marked blocks, 13 are single command
# lines already pinned byte-for-byte by AC10/AC11/AC12's `^...$` anchors — all
# three injection forms are already impossible there. The entire remaining
# surface is exactly TWO multi-line free-text blocks (codex-reviewer.md's
# adversarial `codex` block and drift-evaluator.md's `codex` block). So the
# proportionate move is not to introduce a new mechanism class (a shell
# quoting lexer, with its own open-ended blind-spot surface) for two blocks;
# it is to extend the byte-pinning this repo ALREADY relies on for the other
# thirteen. That changes the detection property from an OPEN set ("is this
# token on the forbidden list?") to a CLOSED one ("is this the frozen text?"),
# which is closed under all three demonstrated forms and under forms nobody
# has thought of yet. It also adds no dependency: no shellcheck (whose absence
# on a contributor machine would force a skip — the fail-open class this repo
# closed in T-087 and T-110), and no new parser to get the quoting rules
# right (drift-evaluator.md's prompt already contains six apostrophes INSIDE
# its double-quoted region — the exact input that breaks a hand-rolled quote
# state machine).
#
# HONEST LIMITS (do not read this lock as more than it is):
#   - A PR that edits the agent file AND this fixture in the same commit
#     passes. That is the same exposure a weakened lexer would have, and it is
#     the already-declared out-of-scope case "an attacker who rewrites the
#     checker itself". What the lock buys is that such a PR can no longer be a
#     one-file diff: touching an agent prompt now forces a visible second file
#     into the diff, which is what a human reviewer is being asked to notice.
#   - This lock is one layer. Merges require a human GO, and on the public
#     repo fork PRs require Actions approval before they run at all.
#   - Indentation is deliberately NOT part of the frozen contract (each line
#     is compared trimmed): the markdown nesting the block sits at may change,
#     while every token inside it may not.
#   - A NEW ```bash fence added without a `# T-107-step:` marker is still
#     silently untracked (unchanged from T-107). Not addressed here.
# =============================================================================

# extract_marked_block FILE KIND SITE_N — print the fenced block opened by the
# SITE_N-th `# T-107-step: <KIND>` marker in FILE, from the marker line through
# the last line before the block's closing fence, each line trimmed of leading
# and trailing horizontal whitespace. Exits 1 when the marker occurrence or its
# closing fence is absent. Callers MUST treat a non-zero exit as a failure and
# never as "unchanged" — that is the fail-closed half of this lock.
extract_marked_block() {
  local file="$1" kind="$2" site_n="$3"
  awk -v kind="$kind" -v want="$site_n" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    {
      t = trim($0)
      if (state == 0) {
        if (t == "# T-107-step: " kind) {
          seen++
          if (seen == want) { state = 1; print t }
        }
        next
      }
      if (t == "```") { state = 2; exit }
      print t
    }
    END { exit (state == 2) ? 0 : 1 }
  ' "$file"
}

# verify_block_verbatim LABEL FILE KIND SITE_N FIXTURE — fail unless the live
# block extracts cleanly AND is byte-identical to its frozen copy.
verify_block_verbatim() {
  local label="$1" file="$2" kind="$3" site_n="$4" fixture="$5"
  local out="$TMP/blockverbatim.$label.out"
  local rc=0
  set +e
  extract_marked_block "$file" "$kind" "$site_n" > "$out"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    fail "agentmd-block-verbatim: $label: extraction FAILED (rc=$rc) — marker occurrence $site_n of '# T-107-step: $kind', or its closing fence, was not found in $file. Fail-closed by contract: a block that cannot be extracted is never reported as unchanged."
  fi
  if [ ! -s "$out" ]; then
    fail "agentmd-block-verbatim: $label: extraction produced an EMPTY block from $file — the equality comparison would be vacuous."
  fi
  if [ ! -s "$fixture" ]; then
    fail "agentmd-block-verbatim: $label: frozen fixture $fixture is missing or empty — the equality comparison would be vacuous."
  fi
  if ! diff -u "$fixture" "$out" > "$TMP/blockverbatim.$label.diff" 2>&1; then
    fail "agentmd-block-verbatim: $label: the live block in $file no longer matches its frozen copy $fixture. If the change is intentional, update the fixture in the SAME commit so the edit shows up as a two-file diff a human reads on both sides. Diff:
$(cat "$TMP/blockverbatim.$label.diff")"
  fi
}

# expect_block_mismatch LABEL MUTATED_FILE KIND SITE_N FIXTURE — the inverse
# assertion: an injected block MUST extract cleanly (marker and fences are
# intact in these mutations, so a failed extraction means the harness or the
# extractor is broken, not that the injection was caught) and MUST differ.
expect_block_mismatch() {
  local label="$1" file="$2" kind="$3" site_n="$4" fixture="$5"
  local out="$TMP/blockmut.$label.out"
  local rc=0
  set +e
  extract_marked_block "$file" "$kind" "$site_n" > "$out"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    fail "agentmd-block-verbatim-mutation: $label: extraction unexpectedly FAILED (rc=$rc) on a copy whose marker and fences are intact — the mutation harness or the extractor is broken, so this case proves nothing."
  fi
  if diff -q "$fixture" "$out" >/dev/null 2>&1; then
    fail "agentmd-block-verbatim-mutation: $label: the injected block STILL matches its frozen copy — the verbatim lock is vacuous for this injection form."
  fi
}

printf -- '\n--- agentmd-block-verbatim ---\n'
FIX_BLOCK_REVIEWER="$FIX/agentmd-block-codex-reviewer-adversarial.txt"
FIX_BLOCK_DRIFT="$FIX/agentmd-block-drift-evaluator.txt"
verify_block_verbatim "reviewer-adversarial" "$CODEX_REVIEWER_MD" codex 2 "$FIX_BLOCK_REVIEWER"
verify_block_verbatim "drift" "$DRIFT_EVALUATOR_MD" codex 1 "$FIX_BLOCK_DRIFT"
pass "agentmd-block-verbatim — both multi-line free-text codex blocks (codex-reviewer.md adversarial site, drift-evaluator.md) are byte-identical to their frozen copies, and an un-extractable block is a failure rather than a silent pass"

printf -- '\n--- agentmd-block-verbatim-mutation ---\n'
for mode in connector tailconnector midbacktick; do
  MUT="$TMP/blockmut-reviewer-site2-$mode.md"
  mutate_fence_site "$CODEX_REVIEWER_MD" 2 "$mode" "$MUT"
  expect_block_mismatch "reviewer-site2-$mode" "$MUT" codex 2 "$FIX_BLOCK_REVIEWER"
done
for mode in connector tailconnector midbacktick; do
  MUT="$TMP/blockmut-drift-site1-$mode.md"
  mutate_fence_site "$DRIFT_EVALUATOR_MD" 1 "$mode" "$MUT"
  expect_block_mismatch "drift-site1-$mode" "$MUT" codex 1 "$FIX_BLOCK_DRIFT"
done

# controls: unmodified copies of both files must still match their fixtures
CTRL_BLOCK_REVIEWER="$TMP/blockmut-control-reviewer.md"
CTRL_BLOCK_DRIFT="$TMP/blockmut-control-drift.md"
cp "$CODEX_REVIEWER_MD" "$CTRL_BLOCK_REVIEWER"
cp "$DRIFT_EVALUATOR_MD" "$CTRL_BLOCK_DRIFT"
verify_block_verbatim "control-reviewer" "$CTRL_BLOCK_REVIEWER" codex 2 "$FIX_BLOCK_REVIEWER"
verify_block_verbatim "control-drift" "$CTRL_BLOCK_DRIFT" codex 1 "$FIX_BLOCK_DRIFT"

# fail-closed probe 1: renaming the marker must make extraction REFUSE, not
# silently find nothing and report the block as unchanged.
VAC_MARKER="$TMP/blockmut-vacuity-renamed-marker.md"
sed 's/# T-107-step: codex$/# T-107-step: codexx/' "$CODEX_REVIEWER_MD" > "$VAC_MARKER"
vac_marker_rc=0
set +e
extract_marked_block "$VAC_MARKER" codex 2 > "$TMP/blockmut-vacuity-marker.out"
vac_marker_rc=$?
set -e
[[ "$vac_marker_rc" -ne 0 ]] \
  || fail "agentmd-block-verbatim-mutation: renaming the codex marker did NOT make extraction refuse (rc=0) — the lock could be disarmed by renaming a marker instead of editing the block"

# fail-closed probe 2: an emptied fixture must be a failure, not a vacuous
# match. Run in a subshell so the helper's fail() exits only that subshell.
: > "$TMP/blockmut-empty-fixture.txt"
vac_fixture_rc=0
set +e
( verify_block_verbatim "vacuity-empty-fixture" "$CODEX_REVIEWER_MD" codex 2 "$TMP/blockmut-empty-fixture.txt" ) >/dev/null 2>&1
vac_fixture_rc=$?
set -e
[[ "$vac_fixture_rc" -ne 0 ]] \
  || fail "agentmd-block-verbatim-mutation: an EMPTY frozen fixture was accepted — emptying the fixture would silently disarm the lock"

pass "agentmd-block-verbatim-mutation — 2 free-text sites x 3 demonstrated injection forms (first-line connector / trailing-connector past the redirection / backtick inside the double-quoted prompt) = 6 independent non-vacuity proofs, plus 2 unmodified controls and 2 fail-closed probes (renamed marker, emptied fixture)"

# =============================================================================
# Thread B (grep-only, no production checker) — frozen regex definitions.
#
# NEW_* are DP-7/DP-8 verbatim (must byte-match AC10/AC11's check: lines).
# OLD_* are a frozen, self-contained, byte-verbatim copy of the T-077 literal
# AC3/AC15 regexes (confirmed against
# docs/specs/T-077-provenance-gate-design.md at authoring time) — inlined
# here rather than fetched via a moving git ref, so this suite has zero
# dependency on a `develop` branch existing locally and zero dependency on
# T-077's frozen AC text ever changing underneath it (T-095 frozen-inline-old
# pattern).
# =============================================================================
# shellcheck disable=SC2016  # deliberately literal ERE source, not a shell expansion.
NEW_AC3='(^|[[:space:]])([^[:space:]]*/)?(bash|sh|source|\.)[[:space:]]+bin/check-provenance\.sh'
# shellcheck disable=SC2016
OLD_AC3='(^|[[:space:]])(bash|sh|source|\.) +bin/check-provenance\.sh'
# shellcheck disable=SC2016
NEW_AC15='provenance[-[:space:]]+gate:AC[0-9]|route[-[:space:]]+back[-[:space:]]+through[-[:space:]]+loop[-[:space:]]+guard'
# shellcheck disable=SC2016
OLD_AC15='provenance-gate:AC[0-9]|route-back through loop-guard\.sh'

NEWCATCH_FIX="$FIX/threadb-newcatch.md"
CLEAN_FIX="$FIX/threadb-clean.md"

# =============================================================================
# newcatch-abspath
# =============================================================================
printf -- '\n--- newcatch-abspath ---\n'
set +e
grep -nE "$NEW_AC3" "$NEWCATCH_FIX" > "$TMP/newcatch-abspath.out"
newcatch_abspath_rc=$?
set -e
[[ "$newcatch_abspath_rc" -eq 0 ]] \
  || fail "newcatch-abspath: expected the DP-7 extended regex to match the absolute-path-interpreter example, got no match (rc=$newcatch_abspath_rc)"
grep -qF '/bin/bash bin/check-provenance.sh' "$TMP/newcatch-abspath.out" \
  || fail "newcatch-abspath: matched line does not contain the expected '/bin/bash bin/check-provenance.sh' example: $(cat "$TMP/newcatch-abspath.out")"
pass "newcatch-abspath — DP-7 extended regex matches the absolute-path interpreter form '/bin/bash bin/check-provenance.sh'"

# =============================================================================
# newcatch-space-sentinel
# =============================================================================
printf -- '\n--- newcatch-space-sentinel ---\n'
set +e
grep -nE "$NEW_AC15" "$NEWCATCH_FIX" > "$TMP/newcatch-sentinel.out"
newcatch_sentinel_rc=$?
set -e
[[ "$newcatch_sentinel_rc" -eq 0 ]] \
  || fail "newcatch-space-sentinel: expected the DP-8 extended regex to match, got no match (rc=$newcatch_sentinel_rc)"
grep -qF 'provenance gate:AC3' "$TMP/newcatch-sentinel.out" \
  || fail "newcatch-space-sentinel: expected a match on the space-separated 'provenance gate:AC3' form: $(cat "$TMP/newcatch-sentinel.out")"
grep -qF 'route back through loop guard' "$TMP/newcatch-sentinel.out" \
  || fail "newcatch-space-sentinel: expected a match on the space-separated 'route back through loop guard' form: $(cat "$TMP/newcatch-sentinel.out")"
pass "newcatch-space-sentinel — DP-8 extended regex matches both hyphen<->space symmetric forms ('provenance gate:AC3', 'route back through loop guard')"

# =============================================================================
# oldmiss (non-vacuous counterfactual)
# =============================================================================
printf -- '\n--- oldmiss ---\n'
set +e
grep -nE "$OLD_AC3" "$NEWCATCH_FIX" > "$TMP/oldmiss-ac3.out"
oldmiss_ac3_rc=$?
set -e
[[ "$oldmiss_ac3_rc" -ne 0 ]] \
  || fail "oldmiss: expected the FROZEN OLD (T-077 literal) AC3 regex to MISS the absolute-path-interpreter example, but it matched: $(cat "$TMP/oldmiss-ac3.out")"
pass "oldmiss (AC3) — the frozen OLD (T-077 literal) broken-invocation regex misses the absolute-path-interpreter example the fixed DP-7 regex catches"

set +e
grep -nE "$OLD_AC15" "$NEWCATCH_FIX" > "$TMP/oldmiss-ac15.out"
oldmiss_ac15_rc=$?
set -e
[[ "$oldmiss_ac15_rc" -ne 0 ]] \
  || fail "oldmiss: expected the FROZEN OLD (T-077 literal) AC15 regex to MISS both space-separated sentinel examples, but it matched: $(cat "$TMP/oldmiss-ac15.out")"
pass "oldmiss (AC15) — the frozen OLD (T-077 literal) stateful-trace regex misses both hyphen<->space symmetric examples the fixed DP-8 regex catches; the extension genuinely adds coverage (non-vacuous)"

# =============================================================================
# fp-zero
# =============================================================================
printf -- '\n--- fp-zero ---\n'
set +e
grep -nE "$NEW_AC3" "$CLEAN_FIX" > "$TMP/fp-zero-ac3.out"
fp_zero_ac3_rc=$?
set -e
[[ "$fp_zero_ac3_rc" -ne 0 ]] \
  || fail "fp-zero: expected ZERO matches from the DP-7 extended regex against the clean fixture (bare check-provenance.sh / passive fallback mention), got: $(cat "$TMP/fp-zero-ac3.out")"
pass "fp-zero (AC3) — DP-7 extended regex matches ZERO lines in the clean fixture (bare + passive-fallback check-provenance.sh mentions are not broken-invocation forms)"

set +e
grep -nE "$NEW_AC15" "$CLEAN_FIX" > "$TMP/fp-zero-ac15.out"
fp_zero_ac15_rc=$?
set -e
[[ "$fp_zero_ac15_rc" -ne 0 ]] \
  || fail "fp-zero: expected ZERO matches from the DP-8 extended regex against the clean fixture (standalone loop-guard.sh mention / bare provenance mention), got: $(cat "$TMP/fp-zero-ac15.out")"
pass "fp-zero (AC15) — DP-8 extended regex matches ZERO lines in the clean fixture (standalone loop-guard.sh mention and gate:AC-less provenance mention are not stateful-trace sentinels)"

# =============================================================================
# livefile-broken-invocation (T-106, item①) — the DP-7 extended regex
# (NEW_AC3, byte-identical to T-097's frozen definition above) matches ZERO
# lines across the live consumer files (agents/qa-verifier.md,
# skills/run/SKILL.md, skills/goal/SKILL.md) — forward-locking their current
# clean state as a recurring CI guard (T-104 unwired-lock lesson: this was
# previously only checked against frozen fixtures, never the live files).
# =============================================================================
printf -- '\n--- livefile-broken-invocation ---\n'
set +e
grep -nE "$NEW_AC3" \
  "$REPO_ROOT/agents/qa-verifier.md" \
  "$REPO_ROOT/skills/run/SKILL.md" \
  "$REPO_ROOT/skills/goal/SKILL.md" > "$TMP/livefile-broken-invocation.out"
livefile_broken_invocation_rc=$?
set -e
# rc=1 (grep's own "no match, clean run" code) is the ONLY acceptable outcome
# here. rc=0 means a broken invocation was found (the regression this lock
# exists to catch); rc>=2 means grep itself failed to execute (e.g. one of
# the three live consumer files was renamed/deleted/became unreadable — this
# repo has a real precedent for exactly this, skills/team-run/SKILL.md ->
# skills/run/SKILL.md) and MUST NOT be silently treated as "0 matches, lock
# holds" (Codex T-106 round1 Major — a bare `-ne 0` check conflated rc=1 and
# rc=2, which would let this forward-lock go silently unenforced the moment
# a live consumer file moved).
[[ "$livefile_broken_invocation_rc" -eq 1 ]] \
  || fail "livefile-broken-invocation: expected grep rc=1 (clean, zero matches) across the live consumer files, got rc=$livefile_broken_invocation_rc (0=broken invocation found; >=2=grep execution error, e.g. a live consumer file went missing/unreadable — the lock must fail closed, not silently pass): $(cat "$TMP/livefile-broken-invocation.out" 2>/dev/null)"
pass "livefile-broken-invocation — DP-7 extended regex matches ZERO lines in the live consumer files (agents/qa-verifier.md, skills/run/SKILL.md, skills/goal/SKILL.md)"

# =============================================================================
# livefile-stateful-trace (T-106, item①) — the DP-8 extended regex (NEW_AC15,
# byte-identical to T-097's frozen definition above) matches ZERO lines in the
# live skills/run/SKILL.md — forward-locking its current clean state.
# =============================================================================
printf -- '\n--- livefile-stateful-trace ---\n'
set +e
grep -nE "$NEW_AC15" "$REPO_ROOT/skills/run/SKILL.md" > "$TMP/livefile-stateful-trace.out"
livefile_stateful_trace_rc=$?
set -e
# Same rc discipline as livefile-broken-invocation above (Codex T-106 round1
# Major): rc=1 (clean, zero matches) is the only PASS outcome. rc=0 means a
# stateful-trace sentinel was found; rc>=2 means grep failed to execute
# (skills/run/SKILL.md missing/unreadable/renamed) and must fail closed.
[[ "$livefile_stateful_trace_rc" -eq 1 ]] \
  || fail "livefile-stateful-trace: expected grep rc=1 (clean, zero matches) in skills/run/SKILL.md, got rc=$livefile_stateful_trace_rc (0=stateful sentinel found; >=2=grep execution error, e.g. the file went missing/unreadable — the lock must fail closed, not silently pass): $(cat "$TMP/livefile-stateful-trace.out" 2>/dev/null)"
pass "livefile-stateful-trace — DP-8 extended regex matches ZERO lines in the live skills/run/SKILL.md"

# =============================================================================
# livefile-mutation-ac3 (T-106, item①, non-vacuous counterfactual) — a
# mutated $TMP copy of a live consumer file, with a broken invocation line
# injected, MUST be caught by the DP-7 extended regex (proving the
# livefile-broken-invocation lock above is not vacuously green).
# =============================================================================
printf -- '\n--- livefile-mutation-ac3 ---\n'
MUT_AC3_FILE="$TMP/mutated-qa-verifier.md"
cp "$REPO_ROOT/agents/qa-verifier.md" "$MUT_AC3_FILE"
printf 'regression probe: bash bin/check-provenance.sh\n' >> "$MUT_AC3_FILE"
set +e
grep -nE "$NEW_AC3" "$MUT_AC3_FILE" > "$TMP/livefile-mutation-ac3.out"
livefile_mutation_ac3_rc=$?
set -e
[[ "$livefile_mutation_ac3_rc" -eq 0 ]] \
  || fail "livefile-mutation-ac3: expected the DP-7 extended regex to MATCH the injected 'bash bin/check-provenance.sh' broken-invocation line, got no match (rc=$livefile_mutation_ac3_rc) — the live-file lock would be vacuous"
grep -qF 'bash bin/check-provenance.sh' "$TMP/livefile-mutation-ac3.out" \
  || fail "livefile-mutation-ac3: matched line does not contain the injected probe: $(cat "$TMP/livefile-mutation-ac3.out")"
pass "livefile-mutation-ac3 — DP-7 extended regex catches a broken invocation injected into a mutated copy of a live consumer file (non-vacuous: proves the livefile-broken-invocation lock actually detects regressions)"

# =============================================================================
# livefile-mutation-ac15 (T-106, item①, non-vacuous counterfactual) — a
# mutated $TMP copy of skills/run/SKILL.md, with a space-separated stateful
# sentinel injected, MUST be caught by the DP-8 extended regex.
# =============================================================================
printf -- '\n--- livefile-mutation-ac15 ---\n'
MUT_AC15_FILE="$TMP/mutated-run-SKILL.md"
cp "$REPO_ROOT/skills/run/SKILL.md" "$MUT_AC15_FILE"
printf 'regression probe: provenance gate:AC3\n' >> "$MUT_AC15_FILE"
set +e
grep -nE "$NEW_AC15" "$MUT_AC15_FILE" > "$TMP/livefile-mutation-ac15.out"
livefile_mutation_ac15_rc=$?
set -e
[[ "$livefile_mutation_ac15_rc" -eq 0 ]] \
  || fail "livefile-mutation-ac15: expected the DP-8 extended regex to MATCH the injected 'provenance gate:AC3' stateful sentinel, got no match (rc=$livefile_mutation_ac15_rc) — the live-file lock would be vacuous"
grep -qF 'provenance gate:AC3' "$TMP/livefile-mutation-ac15.out" \
  || fail "livefile-mutation-ac15: matched line does not contain the injected probe: $(cat "$TMP/livefile-mutation-ac15.out")"
pass "livefile-mutation-ac15 — DP-8 extended regex catches a stateful sentinel injected into a mutated copy of skills/run/SKILL.md (non-vacuous: proves the livefile-stateful-trace lock actually detects regressions)"

# =============================================================================
# template-check-ignore
# =============================================================================
printf -- '\n--- template-check-ignore ---\n'
GITROOT="$TMP/template-gitignore-repo"
mkdir -p "$GITROOT"
(cd "$GITROOT" && git init -q -b main)
cp "$REPO_ROOT/templates/shell-team.gitignore" "$GITROOT/.gitignore"
set +e
(cd "$GITROOT" && git check-ignore -q "reviews/.codex-capture.T-097-probe.out.XYZ123")
tci_rc=$?
set -e
[[ "$tci_rc" -eq 0 ]] \
  || fail "template-check-ignore: expected git check-ignore to report the probe capture-temp path as ignored (exit 0), got $tci_rc"
pass "template-check-ignore — templates/shell-team.gitignore's 'reviews/.codex-capture.*' pattern ignores a probe capture-temp path under reviews/"

# =============================================================================
# Summary
# =============================================================================
printf '\nOK\n'
exit 0
