#!/usr/bin/env bash
# run.sh — tests/gen-loop-replay/run.sh (T-1012 D6/D7).
#
# Hosts the CI-only inline-JS syntax-coverage gate for templates/loop-replay.html
# (D6): the artifact under test is the REAL generator's REAL output for a
# committed fixture — the suite extracts the main <script> block (the
# ratified-design script, not the single-line JSON-data script tag D2
# injects) and runs `node --check` on it. No production logic is
# re-implemented; the extraction is a few lines of awk.
#
# Blast radius (measured, D6): invoked with --runs-dir <committed fixture>
# and --out <temp path>, the generator reads two files and writes one file
# under $TMPDIR. It never writes into the repository, never touches git,
# never networks.
#
# Fail-closed rule: the interpreter is resolved as ${NODE_BIN:-node}. If it is
# unavailable and $CI is non-empty, this suite FAILS (the runner is supposed
# to have node; its absence means the assumption broke). If it is unavailable
# and $CI is empty, this suite prints a SKIP: line and continues — never a
# silent pass either way.
#
# Usage: run.sh
# Exit: 0 = every check passed (or the node gate was skipped outside CI);
#       1 = a check failed, including a real JS syntax error or a missing
#       node under $CI.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GEN="$REPO_ROOT/bin/gen-loop-replay.sh"
FIXTURES="$HERE/fixtures"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gen-loop-replay-suite.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- smoke: the real generator, a committed fixture, exits 0 and produces a
#     real page --------------------------------------------------------------
OUT="$TMP/replay.html"
bash "$GEN" 20260801T000000Z-mixed --runs-dir "$FIXTURES/mixed" --out "$OUT" >/dev/null \
  || fail "generator exited non-zero against the mixed fixture"
[ -s "$OUT" ] || fail "generator produced no output"
grep -qF -- 'id="loop-replay-data"' "$OUT" || fail "generated page is missing the injected data script tag"
pass "generator produces a page from the mixed fixture"

# --- extract the main <script> block (D6) — a few lines of awk, no
#     production logic reimplemented. The frozen single-line JSON-data script
#     tag (`<script type="application/json" id="loop-replay-data">…`) never
#     matches the bare `<script>` anchor, so it can never be mistaken for the
#     ratified-design script this gate actually checks. -----------------------
SCRIPT_BLOCK="$TMP/script-block.js"
awk '
  /^<script>$/   { flag=1; next }
  /^<\/script>$/ { flag=0 }
  flag { print }
' "$OUT" > "$SCRIPT_BLOCK"
[ -s "$SCRIPT_BLOCK" ] || fail "could not extract the main <script> block from the generated page"
pass "extracted the main <script> block"

# --- D6: CI-only node --check, fail-closed under $CI, SKIP outside it --------
NODE_BIN="${NODE_BIN:-node}"
if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
  if [ -n "${CI:-}" ]; then
    fail "node (\$NODE_BIN=$NODE_BIN) is unavailable under \$CI — the inline-JS syntax gate cannot run"
  fi
  printf 'SKIP: node (%s) unavailable outside CI — inline-JS syntax gate not run\n' "$NODE_BIN"
else
  "$NODE_BIN" --check "$SCRIPT_BLOCK" || fail "node --check found a syntax error in the extracted script block"
  pass "node --check: the extracted script block is syntactically valid"
fi

printf 'gen-loop-replay: all checks passed\n'
exit 0
