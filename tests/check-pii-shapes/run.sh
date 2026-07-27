#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-pii-shapes.sh (T-111,
# docs/specs/T-111-pii-shape-checker.md).
#
# No PII-shaped byte ever enters this tree (spec DP-1 / AC12): every fixture
# below is assembled AT RUNTIME from short fragments concatenated into a
# variable, and is only ever written to a throwaway git repo under mktemp —
# never to a file this suite itself commits. A completed placeholder form
# (`/Users/<name>/`, `C:\Users\<name>\`, `<id>+<login>@users.noreply.github.com`,
# `noreply@github.com`) is the one exception, written here literally on
# purpose: it is documented, non-PII, non-matching-by-design content (that
# is exactly what AC9 proves), so it carries no shape to fragment. The same
# is true of the short "lookalike" labels (this repo's own `task-0NN`
# convention, a truncated `ghp_` prefix): they are deliberately too short to
# match any pattern, so they are not PII-shaped either.
#
# Covers, in order:
#   - exit-code contract (0/1/2, including the default-base-chain-exhausted
#     and not-a-git-repo forms of "unresolvable base ref" / unreadable input)
#   - POS/NEG fixture pairs for all five pattern ids, each asserting the
#     reported pattern id by name
#   - AC9: the four documented placeholder forms are clean, together
#   - AC10 (vacuity guard, detector side): neutralising one pattern's own
#     regex in a throwaway copy of the checker makes that pattern's positive
#     fixture stop being reported
#   - AC11 (vacuity guard, fixture side / meta-assertion): the same
#     positive-assertion helper, run against each pattern's own (already
#     proven-clean) near-miss fixture, must itself FAIL — proving the
#     assertion is not vacuously "always passes"
#   - AC13: no path allowlist, not even for the checker's own path or a path
#     under tests/check-pii-shapes/
#   - AC14: a finding never echoes the matched text
#
# Temp roots live under $TMPDIR (2026-07-06 lesson: bare macOS mktemp can
# ignore /tmp in a sandbox); no process substitution (2026-07-06 lesson).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin/check-pii-shapes.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes-suite.XXXXXX")"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

GIT_ID_EMAIL="t@example.invalid"
GIT_ID_NAME="t"

# new_repo — a fresh throwaway git repo, one empty base commit. Prints its path.
new_repo() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes-repo.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
    commit -q --allow-empty -m base
  printf '%s' "$d"
}

# add_fixture_line <repo> <relpath> <content> — writes <content> (one line)
# to <relpath> inside <repo> and commits it (repo's HEAD advances by one).
add_fixture_line() {
  local repo="$1" relpath="$2" content="$3"
  mkdir -p "$(dirname "$repo/$relpath")"
  printf '%s\n' "$content" > "$repo/$relpath"
  git -C "$repo" add -- "$relpath"
  git -C "$repo" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
    commit -q -m "fixture: $relpath"
}

# run_checker <repo> <base-ref> [extra args...] — sets OUT and RC.
OUT=""
RC=0
run_checker() {
  local repo="$1" base="$2"; shift 2
  set +e
  OUT="$(cd "$repo" && bash "$BIN" --base "$base" "$@" 2>&1)"
  RC=$?
  set -e
}

# assert_finding <label> <id> <repo> <base> — expects exit 1 and a finding
# line naming pattern=<id>.
assert_finding() {
  local label="$1" id="$2" repo="$3" base="$4"
  run_checker "$repo" "$base"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -qE "pattern=${id} path="; then
    pass "$label"
  else
    fail "$label (rc=$RC out=$OUT)"
  fi
}

# assert_clean <label> <repo> <base> — expects exit 0, no findings at all.
assert_clean() {
  local label="$1" repo="$2" base="$3"
  run_checker "$repo" "$base"
  if [ "$RC" -eq 0 ]; then
    pass "$label"
  else
    fail "$label (rc=$RC out=$OUT)"
  fi
}

# assert_positive_reports <id> <repo> <base> — returns 0 iff the REAL,
# unmutated checker reports a finding for pattern=<id> against <repo>/<base>.
# Used directly (AC4-AC8) and, against a neutralised fixture inside a
# subshell, as AC11's meta-assertion.
assert_positive_reports() {
  local id="$1" repo="$2" base="$3" out rc
  set +e
  out="$(cd "$repo" && bash "$BIN" --base "$base" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qE "pattern=${id} path="; then
    return 0
  fi
  return 1
}

# =============================================================================
# exit-code contract (AC2)
# =============================================================================
printf '\n--- exit-code contract ---\n'

CLEAN_REPO="$(new_repo)"
CLEAN_BASE="$(git -C "$CLEAN_REPO" rev-parse HEAD)"
add_fixture_line "$CLEAN_REPO" "clean.txt" "nothing sensitive in this line at all"
assert_clean "exit-code contract: 0 = clean diff" "$CLEAN_REPO" "$CLEAN_BASE"

# --- unresolvable base ref: an explicit bad ref ---
set +e
( cd "$CLEAN_REPO" && bash "$BIN" --base zzz-unresolvable-ref-does-not-exist >/dev/null 2>&1 )
rc_badref=$?
set -e
if [ "$rc_badref" -eq 2 ]; then
  pass "exit-code contract: 2 = unresolvable base ref (explicit --base)"
else
  fail "exit-code contract: expected 2 for an unresolvable --base ref, got $rc_badref"
fi

# --- unresolvable base ref: the default chain exhausted (no --base, no env
# candidate, no develop branch in this throwaway repo) ---
NOBASE_REPO="$(new_repo)"
set +e
( cd "$NOBASE_REPO" && env -u PII_CHECK_BASE -u GITHUB_BASE_REF bash "$BIN" >/dev/null 2>&1 )
rc_nodefault=$?
set -e
if [ "$rc_nodefault" -eq 2 ]; then
  pass "exit-code contract: 2 = unresolvable base ref (default chain exhausted)"
else
  fail "exit-code contract: expected 2 when the default base chain cannot resolve, got $rc_nodefault"
fi

# --- unreadable input: not inside a git working tree at all ---
NONGIT="$(mktemp -d "${TMPDIR:-/tmp}/check-pii-shapes-nongit.XXXXXX")"
set +e
( cd "$NONGIT" && bash "$BIN" >/dev/null 2>&1 )
rc_nogit=$?
set -e
if [ "$rc_nogit" -eq 2 ]; then
  pass "exit-code contract: 2 = unreadable input (not inside a git working tree)"
else
  fail "exit-code contract: expected 2 outside a git working tree, got $rc_nogit"
fi

# --- unknown flag ---
set +e
bash "$BIN" --bogus >/dev/null 2>&1
rc_unknown=$?
set -e
if [ "$rc_unknown" -eq 2 ]; then
  pass "exit-code contract: 2 = unknown flag"
else
  fail "exit-code contract: expected 2 for an unknown flag, got $rc_unknown"
fi

# --- --all combined with --base ---
set +e
bash "$BIN" --all --base develop >/dev/null 2>&1
rc_mutex=$?
set -e
if [ "$rc_mutex" -eq 2 ]; then
  pass "exit-code contract: 2 = --all combined with --base"
else
  fail "exit-code contract: expected 2 for --all combined with --base, got $rc_mutex"
fi

# =============================================================================
# POS/NEG pair: home-path
# =============================================================================
printf '\n--- POS/NEG pair: home-path ---\n'

HP_N1="al"; HP_N2="ice"
HP_NAME="${HP_N1}${HP_N2}"
HP_POS_LINE="local backup at /Users/${HP_NAME}/Documents/secret-notes.txt for review"
HP_NEG_LINE="local backup at Users/${HP_NAME}/Documents/secret-notes.txt for review"

HP_POS_REPO="$(new_repo)"; HP_POS_BASE="$(git -C "$HP_POS_REPO" rev-parse HEAD)"
add_fixture_line "$HP_POS_REPO" "pos.txt" "$HP_POS_LINE"
assert_finding "POS/NEG pair: home-path (positive reported as pattern=home-path)" \
  "home-path" "$HP_POS_REPO" "$HP_POS_BASE"

HP_NEG_REPO="$(new_repo)"; HP_NEG_BASE="$(git -C "$HP_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$HP_NEG_REPO" "neg.txt" "$HP_NEG_LINE"
assert_clean "POS/NEG pair: home-path (near-miss negative NOT reported)" \
  "$HP_NEG_REPO" "$HP_NEG_BASE"

# =============================================================================
# POS/NEG pair: home-path-win
# =============================================================================
printf '\n--- POS/NEG pair: home-path-win ---\n'

WP_N1="bo"; WP_N2="bby"
WP_NAME="${WP_N1}${WP_N2}"
WP_POS_LINE="local backup at C:\\Users\\${WP_NAME}\\AppData\\Local\\config.ini for review"
WP_NEG_LINE="local backup at D:\\Program Files\\App\\config.ini for review"

WP_POS_REPO="$(new_repo)"; WP_POS_BASE="$(git -C "$WP_POS_REPO" rev-parse HEAD)"
add_fixture_line "$WP_POS_REPO" "pos.txt" "$WP_POS_LINE"
assert_finding "POS/NEG pair: home-path-win (positive reported as pattern=home-path-win)" \
  "home-path-win" "$WP_POS_REPO" "$WP_POS_BASE"

WP_NEG_REPO="$(new_repo)"; WP_NEG_BASE="$(git -C "$WP_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$WP_NEG_REPO" "neg.txt" "$WP_NEG_LINE"
assert_clean "POS/NEG pair: home-path-win (near-miss negative NOT reported)" \
  "$WP_NEG_REPO" "$WP_NEG_BASE"

# =============================================================================
# POS/NEG pair: email-nonnoreply
# negative: both noreply identity shapes
# =============================================================================
printf '\n--- POS/NEG pair: email-nonnoreply ---\n'
printf '\n--- negative: both noreply identity shapes ---\n'

EM_L1="ali"; EM_L2="ce"
EM_LOCAL="${EM_L1}${EM_L2}"
EM_D1="examp"; EM_D2="le"
EM_DOMAIN="${EM_D1}${EM_D2}"
EM_TLD="com"
EM_POS_LINE="contact ${EM_LOCAL}@${EM_DOMAIN}.${EM_TLD} for details"
# Both documented, non-PII, by-design-excluded GitHub noreply identity shapes
# — written here literally (they carry no shape to fragment; see header note).
EM_NEG_LINE_1="reviewer: <id>+<login>@users.noreply.github.com"
EM_NEG_LINE_2="reviewer: noreply@github.com"

EM_POS_REPO="$(new_repo)"; EM_POS_BASE="$(git -C "$EM_POS_REPO" rev-parse HEAD)"
add_fixture_line "$EM_POS_REPO" "pos.txt" "$EM_POS_LINE"
assert_finding "POS/NEG pair: email-nonnoreply (positive reported as pattern=email-nonnoreply)" \
  "email-nonnoreply" "$EM_POS_REPO" "$EM_POS_BASE"

EM_NEG_REPO="$(new_repo)"; EM_NEG_BASE="$(git -C "$EM_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$EM_NEG_REPO" "neg1.txt" "$EM_NEG_LINE_1"
add_fixture_line "$EM_NEG_REPO" "neg2.txt" "$EM_NEG_LINE_2"
assert_clean "negative: both noreply identity shapes (placeholder id+login and plain web-flow forms both clean)" \
  "$EM_NEG_REPO" "$EM_NEG_BASE"

# =============================================================================
# POS/NEG pair: private-key
# =============================================================================
printf '\n--- POS/NEG pair: private-key ---\n'

PK_B1="-----BEGIN "; PK_B2="RSA "; PK_B3="PRIVATE KEY"; PK_B4="-----"
PK_POS_LINE="${PK_B1}${PK_B2}${PK_B3}${PK_B4}"
PK_NEG_LINE="-----BEGIN CERTIFICATE-----"

PK_POS_REPO="$(new_repo)"; PK_POS_BASE="$(git -C "$PK_POS_REPO" rev-parse HEAD)"
add_fixture_line "$PK_POS_REPO" "pos.txt" "$PK_POS_LINE"
assert_finding "POS/NEG pair: private-key (positive reported as pattern=private-key)" \
  "private-key" "$PK_POS_REPO" "$PK_POS_BASE"

PK_NEG_REPO="$(new_repo)"; PK_NEG_BASE="$(git -C "$PK_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$PK_NEG_REPO" "neg.txt" "$PK_NEG_LINE"
assert_clean "POS/NEG pair: private-key (near-miss negative, a public-cert header, NOT reported)" \
  "$PK_NEG_REPO" "$PK_NEG_BASE"

# =============================================================================
# POS/NEG pair: token
# negative: short lookalike must not fire
# =============================================================================
printf '\n--- POS/NEG pair: token ---\n'
printf '\n--- negative: short lookalike must not fire ---\n'

TK_P1="gh"; TK_P2="p_"
TK_B1="ABCDEFGHIJ"; TK_B2="KLMNOPQRST12"
TK_POS_LINE="token=${TK_P1}${TK_P2}${TK_B1}${TK_B2}"
# This project's own task-0NN convention (literal substring "sk-") and a
# truncated "ghp_" prefix are deliberately too short to match RE_TOKEN's
# minimum key-body length — the same false-positive class
# tests/rollup-track/run.sh already guards for its own write-time guard.
TK_NEG_LINE="see task-043 and ghp_short — neither is a real secret"

TK_POS_REPO="$(new_repo)"; TK_POS_BASE="$(git -C "$TK_POS_REPO" rev-parse HEAD)"
add_fixture_line "$TK_POS_REPO" "pos.txt" "$TK_POS_LINE"
assert_finding "POS/NEG pair: token (positive reported as pattern=token)" \
  "token" "$TK_POS_REPO" "$TK_POS_BASE"

TK_NEG_REPO="$(new_repo)"; TK_NEG_BASE="$(git -C "$TK_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$TK_NEG_REPO" "neg.txt" "$TK_NEG_LINE"
assert_clean "negative: short lookalike must not fire (task-043 / ghp_short both clean)" \
  "$TK_NEG_REPO" "$TK_NEG_BASE"

# =============================================================================
# placeholder forms are not findings (AC9) — a permanent false-positive
# regression case: all four documented placeholder forms in one diff, clean.
# =============================================================================
printf '\n--- placeholder forms are not findings ---\n'

PH_REPO="$(new_repo)"; PH_BASE="$(git -C "$PH_REPO" rev-parse HEAD)"
{
  printf '%s\n' 'example: /Users/<name>/Documents'
  printf '%s\n' 'example: /home/<name>/Documents'
  printf '%s\n' 'example: C:\Users\<name>\AppData'
  printf '%s\n' 'example: <id>+<login>@users.noreply.github.com'
} > "$PH_REPO/placeholders.md"
git -C "$PH_REPO" add placeholders.md
git -C "$PH_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: placeholders.md"
assert_clean "placeholder forms are not findings (all four documented forms, one diff, clean)" \
  "$PH_REPO" "$PH_BASE"

# =============================================================================
# mutation: pattern is load-bearing (AC10, vacuity guard / detector side)
#
# For every pattern: rewrite JUST that pattern's RE_* assignment line, in a
# throwaway copy of the real checker, to a placeholder that can never match
# real content, then re-run that pattern's OWN positive fixture (already
# proven, above, to be reported by the REAL checker) against the copy. The
# copy must now report NOTHING — proving the pattern is individually
# load-bearing, and that the fixture was not being caught by some OTHER,
# still-active pattern.
# =============================================================================
printf '\n--- mutation: pattern is load-bearing ---\n'

neutralize_copy() {  # $1 = RE_ variable name; prints path to a mutated copy
  local varname="$1" copy
  copy="$(mktemp "${TMPDIR:-/tmp}/check-pii-shapes-mut.XXXXXX")"
  sed "s/^${varname}=.*/${varname}='NEUTRALISED_NO_MATCH_PLACEHOLDER_ZZZ_T111'/" "$BIN" > "$copy"
  printf '%s' "$copy"
}

assert_neutralised_reports_nothing() {  # $1=RE var, $2=label, $3=repo, $4=base
  local varname="$1" label="$2" repo="$3" base="$4" copy out rc
  copy="$(neutralize_copy "$varname")"
  set +e
  out="$(cd "$repo" && bash "$copy" --base "$base" 2>&1)"
  rc=$?
  set -e
  rm -f "$copy"
  if [ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q '^FINDING'; then
    pass "$label"
  else
    fail "$label (neutralised copy still reported something: rc=$rc out=$out)"
  fi
}

assert_neutralised_reports_nothing RE_HOME_PATH \
  "mutation: pattern is load-bearing (home-path neutralised -> its own positive fixture reports nothing)" \
  "$HP_POS_REPO" "$HP_POS_BASE"
assert_neutralised_reports_nothing RE_HOME_PATH_WIN \
  "mutation: pattern is load-bearing (home-path-win neutralised -> its own positive fixture reports nothing)" \
  "$WP_POS_REPO" "$WP_POS_BASE"
assert_neutralised_reports_nothing RE_EMAIL \
  "mutation: pattern is load-bearing (email-nonnoreply neutralised -> its own positive fixture reports nothing)" \
  "$EM_POS_REPO" "$EM_POS_BASE"
assert_neutralised_reports_nothing RE_PRIVATE_KEY \
  "mutation: pattern is load-bearing (private-key neutralised -> its own positive fixture reports nothing)" \
  "$PK_POS_REPO" "$PK_POS_BASE"
assert_neutralised_reports_nothing RE_TOKEN \
  "mutation: pattern is load-bearing (token neutralised -> its own positive fixture reports nothing)" \
  "$TK_POS_REPO" "$TK_POS_BASE"

# =============================================================================
# meta: neutralised positive fixture makes the assertion FAIL (AC11, vacuity
# guard / fixture side)
#
# For every pattern: call the REAL positive-assertion helper
# (assert_positive_reports, the same helper AC4-AC8 use above) against that
# pattern's own NEAR-MISS fixture — i.e. its positive fixture with the one
# feature that makes it a real shape removed — in a subshell, and require
# the call itself to FAIL. This is the "control: ... has teeth" idiom
# (tests/rollup-track/run.sh) applied to a fixture instead of a config file:
# a fixture that silently stopped carrying its shape would make this
# meta-assertion incorrectly PASS, so this proves it does not.
# =============================================================================
printf '\n--- meta: neutralised positive fixture makes the assertion FAIL ---\n'

assert_meta_fails() {  # $1=id $2=neutralised-repo $3=neutralised-base $4=label
  local id="$1" repo="$2" base="$3" label="$4" rc
  set +e
  ( assert_positive_reports "$id" "$repo" "$base" )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    pass "$label"
  else
    fail "$label (the positive-assertion helper incorrectly SUCCEEDED against a neutralised fixture)"
  fi
}

assert_meta_fails home-path "$HP_NEG_REPO" "$HP_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (home-path)"
assert_meta_fails home-path-win "$WP_NEG_REPO" "$WP_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (home-path-win)"
assert_meta_fails email-nonnoreply "$EM_NEG_REPO" "$EM_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (email-nonnoreply)"
assert_meta_fails private-key "$PK_NEG_REPO" "$PK_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (private-key)"
assert_meta_fails token "$TK_NEG_REPO" "$TK_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (token)"

# =============================================================================
# no-allowlist: finding reported even for the checker own path (AC13)
# =============================================================================
printf '\n--- no-allowlist: finding reported even for the checker own path ---\n'

NOALLOW_REPO="$(new_repo)"; NOALLOW_BASE="$(git -C "$NOALLOW_REPO" rev-parse HEAD)"
add_fixture_line "$NOALLOW_REPO" "bin/check-pii-shapes.sh" "$HP_POS_LINE"
add_fixture_line "$NOALLOW_REPO" "tests/check-pii-shapes/dummy.md" "$HP_POS_LINE"
run_checker "$NOALLOW_REPO" "$NOALLOW_BASE"
if [ "$RC" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qE 'pattern=home-path path=bin/check-pii-shapes\.sh' \
   && printf '%s\n' "$OUT" | grep -qE 'pattern=home-path path=tests/check-pii-shapes/dummy\.md'; then
  pass "no-allowlist: finding reported even for the checker own path"
else
  fail "no-allowlist: finding reported even for the checker own path (rc=$RC out=$OUT)"
fi

# =============================================================================
# no-leak: finding output never echoes the matched text (AC14)
# =============================================================================
printf '\n--- no-leak: finding output never echoes the matched text ---\n'

LEAK_MARKER="zzzqqqNoLeakMarkerT111xyz"
LEAK_LINE="secret path /Users/${LEAK_MARKER}/data.txt"
LEAK_REPO="$(new_repo)"; LEAK_BASE="$(git -C "$LEAK_REPO" rev-parse HEAD)"
add_fixture_line "$LEAK_REPO" "leak.txt" "$LEAK_LINE"
run_checker "$LEAK_REPO" "$LEAK_BASE"
if [ "$RC" -eq 1 ] \
   && printf '%s\n' "$OUT" | grep -qE 'pattern=home-path path=' \
   && ! printf '%s\n' "$OUT" | grep -qF "$LEAK_MARKER"; then
  pass "no-leak: finding output never echoes the matched text"
else
  fail "no-leak: finding output never echoes the matched text (rc=$RC out=$OUT)"
fi

# =============================================================================
printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'check-pii-shapes suite: all assertions passed\n'
  exit 0
else
  printf 'check-pii-shapes suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
