#!/usr/bin/env bash
# tests/check-count-claims/run.sh — fixture suite for bin/check-count-claims.sh
# (T-1113, the quantity-relay-checker spec under .shell-team/specs/).
# Hermetic: every board fixture lives under a fresh ${TMPDIR:-/tmp}
# mktemp -d root — this suite never reads this repository's own real task
# board and never resolves a path through the sibling paths resolver.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CHECKER="$REPO_ROOT/bin/check-count-claims.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

T="$(mktemp -d "${TMPDIR:-/tmp}/check-count-claims-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# mkboard PATH BODY — a one-entry T-901 board under ## Active, BODY expanded
# via printf %b (so \n inside a caller's string becomes a real newline).
mkboard() {
  printf -- '# Fixture\n\n## Active\n\n- [ ] **T-901** Fixture entry\n%b\n\n## Done\n' "$2" > "$1"
}

# ---------------------------------------------------------------------------
# AC2 — a conformant entry passes in both modes, across every reachable
# value shape, CRLF row included.
# ---------------------------------------------------------------------------
CONFORM="$T/conform.md"
{
  printf '%s\n' '# Fixture' '' '## Active' '' '- [ ] **T-901** Fixture entry' \
    '  - count: sites — 6 — command: printf 6' \
    '  - count: provenance-delta — +3 — command: printf 3' \
    '  - count: zero-case — 0 — command: printf 0' \
    '  - count: octal-trap — 8 — command: printf 08' \
    '  - count: negative-case — -2 — command: printf -- -2' \
    '  - count: negative-zero — -0 — command: printf 0'
  printf '  - count: crlf-case — 4 — command: printf 4\r\n'
} > "$CONFORM"
test -s "$CONFORM" || fail "conformant fixture is empty"
test "$(grep -c -- '^  - count: ' "$CONFORM" || true)" = "7" || fail "conformant fixture must carry exactly seven - count: rows"
bash "$CHECKER" --board "$CONFORM" --task T-901 >/dev/null 2>&1 || fail "conformant-live: expected exit 0"
bash "$CHECKER" --board "$CONFORM" --task T-901 --no-exec >/dev/null 2>&1 || fail "conformant-no-exec: expected exit 0"
pass "conformant-entry-both-modes — every reachable value shape (signed, zero, signed zero, leading zero, CRLF) passes live and --no-exec"

# ---------------------------------------------------------------------------
# AC3 — every near-miss row is collected and refused, never read as the
# conformant zero-row case. The collect stem is byte-pinned.
# ---------------------------------------------------------------------------
grep -qF -- '^[[:space:]]*-[[:space:]]+[Cc][Oo][Uu][Nn][Tt][[:space:]]*(:|：)[[:space:]]*' "$CHECKER" \
  || fail "the byte-pinned collect stem is not present verbatim in $CHECKER"

near_miss_case() {  # $1 = row text, $2 = case label
  local b="$T/nm-$2.md"
  mkboard "$b" "$1"
  test -s "$b" || fail "near-miss fixture ($2) is empty"
  local rc=0
  bash "$CHECKER" --board "$b" --task T-901 --no-exec >/dev/null 2>&1 || rc=$?
  [ "$rc" = "1" ] || fail "near-miss ($2): expected exit 1, got $rc — row: $1"
}

near_miss_case '  - Count: sites — 6 — command: printf 6' 'capitalized-field-name'
near_miss_case '  - count： sites — 6 — command: printf 6' 'fullwidth-colon'
near_miss_case '  -  count: sites — 6 — command: printf 6' 'doubled-space-after-dash'
near_miss_case '  - count : sites — 6 — command: printf 6' 'space-before-colon'
near_miss_case '  - count: sites —  6 — command: printf 6' 'doubled-space-in-separator'
near_miss_case '  - count: sites — 6' 'missing-command-field'
near_miss_case '  - count: si tes — 6 — command: printf 6' 'label-with-space'
near_miss_case '  - count: si+tes — 6 — command: printf 6' 'label-with-plus'
near_miss_case '  - count: _sites — 6 — command: printf 6' 'label-leading-underscore'
near_miss_case '  - count: sites — six — command: printf 6' 'non-numeric-value'
near_miss_case '  - count: sites — 3- — command: printf 3' 'trailing-signed-value'
near_miss_case '  - count: sites — 6 7 — command: printf 6' 'internal-whitespace-value'
near_miss_case '  - count: sites — 6 — command: ' 'empty-command'
pass "near-miss-rows-collected-and-refused — all 13 measured near-miss classes refuse under --no-exec, never exit 0 or 2"

CTRL="$T/nm-ctrl.md"
mkboard "$CTRL" '  - count: sites — 6 — command: printf 6'
bash "$CHECKER" --board "$CTRL" --task T-901 --no-exec >/dev/null 2>&1 \
  || fail "near-miss positive control: a genuinely conformant row must still pass"
pass "near-miss-positive-control — a conformant row exits 0 under the identical --no-exec invocation"

# ---------------------------------------------------------------------------
# AC4 — zero rows pass vacuously; zero echo lines on stdout+stderr; a
# conformant row added afterwards produces at least one echo line.
# ---------------------------------------------------------------------------
ZERO="$T/zero-rows.md"
{ printf '%s\n' '# Fixture' '' '## Active' '' '- [ ] **T-901** Fixture entry' \
    '  - note: the count of sites is discussed here in prose' \
    '  - counted-by: someone'; } > "$ZERO"
test -s "$ZERO" || fail "zero-row fixture is empty"
bash "$CHECKER" --board "$ZERO" --task T-901 --no-exec >/dev/null 2>&1 || fail "zero-row --no-exec: expected exit 0"
bash "$CHECKER" --board "$ZERO" --task T-901 > "$T/zero-out" 2>&1 || fail "zero-row live: expected exit 0"
test "$(grep -c -- '^check-count-claims: count ' "$T/zero-out" || true)" = "0" \
  || fail "zero-row live must emit zero 'count' echo lines"
cp "$ZERO" "$T/zero-plus.md"
printf '%s\n' '  - count: sites — 6 — command: printf 6' >> "$T/zero-plus.md"
bash "$CHECKER" --board "$T/zero-plus.md" --task T-901 > "$T/zero-plus-out" 2>&1 || fail "zero-plus live: expected exit 0"
test "$(grep -c -- '^check-count-claims: count ' "$T/zero-plus-out" || true)" -ge 1 \
  || fail "zero-plus positive control must emit at least one echo line"
pass "zero-rows-pass-vacuously — an entry with no - count: row passes silently; adding one produces an echo"

# ---------------------------------------------------------------------------
# AC5 — a duplicate label refuses (named on stderr); distinct labels pass.
# ---------------------------------------------------------------------------
DUP="$T/dup.md"
mkboard "$DUP" '  - count: sites — 6 — command: printf 6\n  - count: sites — 7 — command: printf 7'
OKLBL="$T/ok-labels.md"
mkboard "$OKLBL" '  - count: sites — 6 — command: printf 6\n  - count: sites-2 — 7 — command: printf 7'
rc=0
bash "$CHECKER" --board "$DUP" --task T-901 --no-exec >/dev/null 2>"$T/dup-err" || rc=$?
[ "$rc" = "1" ] || fail "duplicate label: expected exit 1, got $rc"
grep -qF -- 'sites' "$T/dup-err" || fail "duplicate label refusal must name the label"
bash "$CHECKER" --board "$OKLBL" --task T-901 --no-exec >/dev/null 2>&1 || fail "distinct labels must pass"
pass "duplicate-label-refuses — two rows sharing a label refuse and name it; distinct labels pass"

# ---------------------------------------------------------------------------
# AC6 — live re-derivation: mismatch, non-numeric, multi-line, empty,
# non-zero exit (with the | wc -l remedy) and internal whitespace all
# refuse; match, zero and padded-whitespace all pass.
# ---------------------------------------------------------------------------
mismatch_case() {  # $1 = row, $2 = label, $3 = extra grep substrings to require (space-separated, may be empty)
  local b="$T/mm-$2.md"
  mkboard "$b" "$1"
  test -s "$b" || fail "mismatch fixture ($2) is empty"
  local rc=0
  bash "$CHECKER" --board "$b" --task T-901 > "$T/mm-$2.out" 2>&1 || rc=$?
  [ "$rc" = "1" ] || fail "mismatch ($2): expected exit 1, got $rc"
  local s
  for s in $3; do
    grep -qF -- "$s" "$T/mm-$2.out" || fail "mismatch ($2): expected stderr to carry '$s'"
  done
}

mismatch_case '  - count: sites — 6 — command: printf 7' 'value-mismatch' '6 7'
mismatch_case '  - count: sites — 6 — command: printf six' 'non-numeric' ''
mismatch_case '  - count: sites — 6 — command: echo 6; echo 7' 'multi-line' ''
mismatch_case '  - count: sites — 6 — command: printf %s ""' 'empty-output' ''
mismatch_case '  - count: sites — 0 — command: grep -c zzz /dev/null' 'nonzero-exit-remedy' '| wc -l'
mismatch_case '  - count: sites — 6 — command: printf "6 7"' 'internal-whitespace-measurement' ''
pass "live-refusal-classes — mismatch, non-numeric, multi-line, empty and internal-whitespace measurements all refuse; a non-zero command exit refuses with the | wc -l remedy"

MATCH="$T/match.md"
mkboard "$MATCH" '  - count: sites — 6 — command: printf 6'
bash "$CHECKER" --board "$MATCH" --task T-901 >/dev/null 2>&1 || fail "match control: expected exit 0"
ZEROMATCH="$T/zero-match.md"
mkboard "$ZEROMATCH" '  - count: sites — 0 — command: printf 0'
bash "$CHECKER" --board "$ZEROMATCH" --task T-901 >/dev/null 2>&1 || fail "zero control: expected exit 0"
PADDED="$T/padded.md"
mkboard "$PADDED" '  - count: sites — 6 — command: printf "  6  "'
bash "$CHECKER" --board "$PADDED" --task T-901 >/dev/null 2>&1 || fail "padded control: expected exit 0"
pass "live-positive-controls — an exact match, a real zero and a whitespace-padded measurement all pass"

# ---------------------------------------------------------------------------
# AC7 — --no-exec executes nothing, proven by an observable side effect.
# ---------------------------------------------------------------------------
SE="$T/side-effect.md"
mkboard "$SE" "$(printf -- '  - count: sideeffect — 1 — command: touch %s/fired; printf 1' "$T")"
test ! -e "$T/fired" || fail "marker must not pre-exist"
bash "$CHECKER" --board "$SE" --task T-901 --no-exec >/dev/null 2>&1 || fail "--no-exec: expected exit 0"
test ! -e "$T/fired" || fail "--no-exec must not have created the marker file"
bash "$CHECKER" --board "$SE" --task T-901 >/dev/null 2>&1 || fail "live: expected exit 0"
test -e "$T/fired" || fail "live mode must have created the marker file (non-vacuity control)"
pass "no-exec-executes-nothing — --no-exec never creates the marker; live mode does"

# ---------------------------------------------------------------------------
# AC8 — exit-code contract: 0/1/2 never conflated.
# ---------------------------------------------------------------------------
ZEROENTRY="$T/zero-entry.md"
{ printf '%s\n' '# Fixture' '' '## Active' '' '- [ ] **T-902** Other entry' '  - count: sites — 6 — command: printf 6'; } > "$ZEROENTRY"
TWOENTRY="$T/two-entry.md"
{ printf '%s\n' '# Fixture' '' '## Active' '' '- [ ] **T-901** First' '  - count: a — 1 — command: printf 1' '' '- [ ] **T-901** Second' '  - count: b — 2 — command: printf 2'; } > "$TWOENTRY"
BADROW="$T/bad-row.md"
mkboard "$BADROW" '  - count: sites — six — command: printf 6'
MISVAL="$T/mis-val.md"
mkboard "$MISVAL" '  - count: sites — 6 — command: printf 7'
for f in "$ZEROENTRY" "$TWOENTRY"; do
  test -s "$f" || fail "exit-code fixture is empty: $f"
  grep -q -- '^## Active' "$f" || fail "exit-code fixture missing ## Active: $f"
done

exit2_case() {  # $@ = full argv (without $CHECKER)
  local rc=0
  bash "$CHECKER" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "2" ] || fail "exit-2 case '$*': expected exit 2, got $rc"
}
exit2_case --task T-901
exit2_case --board "$ZEROENTRY"
exit2_case --board "$ZEROENTRY" --task NOPE
exit2_case --board "$ZEROENTRY" --task T-901 --bogus
exit2_case --board "$T/absent.md" --task T-901
exit2_case --board "$ZEROENTRY" --task T-901
exit2_case --board "$TWOENTRY" --task T-901

exit1_case() {
  local rc=0
  bash "$CHECKER" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "1" ] || fail "exit-1 case '$*': expected exit 1, got $rc"
}
exit1_case --board "$BADROW" --task T-901 --no-exec
exit1_case --board "$MISVAL" --task T-901

bash "$CHECKER" --help >/dev/null 2>&1 || fail "--help: expected exit 0"
pass "exit-code-contract — usage/environment errors are exit 2, content refusals are exit 1, --help is exit 0, never conflated"

# ---------------------------------------------------------------------------
# AC9 — trust boundary header literals; echo-before-run ordering.
# ---------------------------------------------------------------------------
for s in 'TRUST BOUNDARY' 'never a hook' 'read-only' 'echoed before' 'before any review of the entry itself' 'uncommitted' 'command -v timeout' 'no timeout binary'; do
  grep -qF -- "$s" "$CHECKER" || fail "header missing literal: $s"
done
test "$(grep -cF -- 'CHECK_COUNT_CLAIMS_TIMEOUT' "$CHECKER" || true)" -ge 2 || fail "CHECK_COUNT_CLAIMS_TIMEOUT must appear on at least two lines"

FALSECMD="$T/false-cmd.md"
mkboard "$FALSECMD" '  - count: sites — 6 — command: false'
frc=0
bash "$CHECKER" --board "$FALSECMD" --task T-901 > "$T/false-out" 2>&1 || frc=$?
[ "$frc" = "1" ] || fail "false-command: expected exit 1, got $frc"
grep -q -- '^check-count-claims: count sites' "$T/false-out" || fail "false-command: echo must still appear even though the command fails"

GREPC="$T/grepc.md"
mkboard "$GREPC" '  - count: sites — 0 — command: grep -c zzz /dev/null'
grc=0
bash "$CHECKER" --board "$GREPC" --task T-901 > "$T/grepc-out" 2>&1 || grc=$?
[ "$grc" = "1" ] || fail "grep-c: expected exit 1, got $grc"
el=$(grep -n -- '^check-count-claims: count sites' "$T/grepc-out" | head -1 | cut -d: -f1)
wl=$(grep -nF -- '| wc -l' "$T/grepc-out" | head -1 | cut -d: -f1)
case "${el:-}" in ''|*[!0-9]*) fail "echo line not found" ;; esac
case "${wl:-}" in ''|*[!0-9]*) fail "remedy line not found" ;; esac
[ "$el" -lt "$wl" ] || fail "echo must precede the remedy line ($el vs $wl)"
pass "echo-before-run-ordering — the echo appears even on a failing command, and strictly precedes the | wc -l remedy line"

# ---------------------------------------------------------------------------
# AC18 — the advisory uncommitted-board warning, four git-state arms.
# ---------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  G="$T/git-arms"
  mkdir -p "$G/repo" "$G/plain" "$G/untracked" "$G/tpl"
  { printf '%s\n' '# Fixture' '' '## Active' '' '- [ ] **T-901** Fixture entry' '  - count: sites — 6 — command: printf 6'; } > "$G/repo/b.md"
  cp "$G/repo/b.md" "$G/plain/b.md"
  cp "$G/repo/b.md" "$G/untracked/b.md"
  git -C "$G/repo" init -q -b main --template="$G/tpl" >/dev/null 2>&1
  git -C "$G/repo" -c user.email=t@example.invalid -c user.name=t add b.md >/dev/null 2>&1
  git -C "$G/repo" -c user.email=t@example.invalid -c user.name=t commit -qm fixture >/dev/null 2>&1
  git -C "$G/untracked" init -q -b main --template="$G/tpl" >/dev/null 2>&1
  : > "$G/untracked/.keep"
  git -C "$G/untracked" -c user.email=t@example.invalid -c user.name=t add .keep >/dev/null 2>&1
  git -C "$G/untracked" -c user.email=t@example.invalid -c user.name=t commit -qm base >/dev/null 2>&1
  git -C "$G/untracked" status --porcelain -- b.md 2>/dev/null | grep -q '^??' \
    || fail "arm(3) setup: b.md must read as untracked ('??') from inside its own work tree"
  if git -C "$G/plain" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "arm(4) setup: the plain directory must NOT be inside a git work tree"
  fi

  ( cd "$G/repo" && bash "$CHECKER" --board b.md --task T-901 ) > "$G/o-unmodified" 2>&1 \
    || fail "arm(2) committed-and-unmodified: expected exit 0"
  test "$(grep -cF -- 'uncommitted' "$G/o-unmodified" || true)" = "0" \
    || fail "arm(2) committed-and-unmodified: must NOT warn"

  printf '%s\n' '  - count: sites-2 — 7 — command: printf 7' >> "$G/repo/b.md"
  ( cd "$G/repo" && bash "$CHECKER" --board b.md --task T-901 ) > "$G/o-modified" 2>&1 \
    || fail "arm(1) tracked-and-modified: expected exit 0"
  test "$(grep -cF -- 'uncommitted' "$G/o-modified" || true)" -ge 1 \
    || fail "arm(1) tracked-and-modified: must warn"

  ( cd "$G/untracked" && bash "$CHECKER" --board b.md --task T-901 ) > "$G/o-untracked" 2>&1 \
    || fail "arm(3) untracked-in-work-tree: expected exit 0"
  test "$(grep -cF -- 'uncommitted' "$G/o-untracked" || true)" = "0" \
    || fail "arm(3) untracked-in-work-tree: must NOT warn"

  ( cd "$G/plain" && bash "$CHECKER" --board b.md --task T-901 ) > "$G/o-plain" 2>&1 \
    || fail "arm(4) outside-a-work-tree: expected exit 0"
  test "$(grep -cF -- 'uncommitted' "$G/o-plain" || true)" = "0" \
    || fail "arm(4) outside-a-work-tree: must NOT warn"

  pass "uncommitted-board-warning-four-arms — tracked+modified warns; committed+unmodified, untracked-in-work-tree, and outside-a-work-tree all stay silent; every arm exits 0"
else
  pass "uncommitted-board-warning-four-arms — SKIPPED (no git on PATH; the checker's own guard treats this as no-warning-proceed, matching Trap 11)"
fi

printf '\nAll check-count-claims assertions passed.\n'
