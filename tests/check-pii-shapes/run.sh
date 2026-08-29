#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-pii-shapes.sh (T-111,
# .shell-team/specs/T-111-pii-shape-checker.md, v4).
#
# No PII-shaped byte ever enters this tree (spec DP-1 / AC12): every fixture
# that carries a REAL shape below is assembled AT RUNTIME from short
# fragments concatenated into a variable, and is only ever written to a
# throwaway git repo under mktemp — never to a file this suite itself
# commits to this tree. Two classes of literal ARE written directly,
# because they carry no shape to fragment by design:
#   - the four documented placeholder forms (/Users/<name>/, C:\Users\<name>\,
#     <id>+<login>@users.noreply.github.com, noreply@github.com) — AC9's own
#     subject matter;
#   - GitHub noreply identity shapes used as NEGATIVE (excluded) fixtures —
#     a numeric-id-plus-login form, the older login-only form, and a printf
#     format placeholder local part — because the whole point of DP-9 is
#     that these are not PII regardless of shape (a real mailbox cannot
#     exist at that domain), and this project's own existing convention
#     (the pre-v4 suite) already treats the bracketed placeholder form this
#     way;
#   - RFC 2606 / RFC 6761 reserved-domain addresses (example.com/.org/.net,
#     .example/.invalid/.test/.localhost) — reserved precisely so nothing
#     real can live there;
#   - short "lookalike" labels: a truncated ghp_ prefix (too short to match
#     RE_TOKEN's minimum key-body length) and this repo's own kebab-case
#     label convention immediately after an identifier character (blocked
#     by the sk- alternative's left boundary guard, T-1051 #178 — not by
#     length alone; a long lookalike is exercised separately, below).
#
# Covers, in order (see "Canonical suite assertion labels" in the spec for
# the exact label strings this file must contain verbatim):
#   - exit-code contract (0/1/2)
#   - POS/NEG fixture pairs for all five pattern ids
#   - AC6: the domain-anchored noreply exclusion (DP-9), the reserved-domain
#     exclusion (DP-7), the anti-swallow positives, and the precondition
#     that every negative fixture actually reaches the email candidate
#     enumeration
#   - AC9: the four documented placeholder forms are clean, together
#   - AC10 (vacuity guard, detector side): nine independently load-bearing
#     rules — five patterns, four exclusions
#   - AC11 (vacuity guard, fixture side / meta-assertion)
#   - AC13: no path allowlist for this task's own files; the known-shapes
#     list's exact contents are asserted
#   - AC14: a finding never echoes the matched text
#   - AC26: every mailbox candidate on a line is judged, not just the first
#   - AC27: text/binary is decided by the NUL byte, not printability
#   - AC28: the home-path URL false positive stays closed
#   - AC29: --all never silently skips
#
# Temp roots live under $TMPDIR (2026-07-06 lesson: bare macOS mktemp can
# ignore /tmp in a sandbox); no process substitution (2026-07-06 lesson);
# every throwaway git repository lives inside $WORK, the one directory the
# EXIT trap removes (AC12 — a Codex-round finding against the prior
# implementation, whose repos were siblings of $WORK and were never
# cleaned up).

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

# Assembled from fragments (header note above): the completed git identity
# email is itself a generic mailbox-shaped string at a (reserved, RFC 2606)
# domain, which this checker cannot distinguish from a real one by shape
# alone — so it is fragmented here exactly like the other real-shape
# positive fixtures, rather than written as one contiguous string.
GIT_ID_LOCAL="t"
GIT_ID_DOMAIN="example"
GIT_ID_TLD="invalid"
GIT_ID_EMAIL="${GIT_ID_LOCAL}@${GIT_ID_DOMAIN}.${GIT_ID_TLD}"
GIT_ID_NAME="t"

# new_repo — a fresh throwaway git repo INSIDE $WORK, one empty base commit.
# Prints its path, and records it (one line per call, appended to a plain
# file rather than a shell array: most call sites use `$(new_repo)` command
# substitution, which forks a subshell — an array mutated there would never
# be visible back in this script) so the "temp hygiene" assertion below can
# prove every single one actually lives inside $WORK (AC12: never as a
# sibling of it — a Codex-round finding against the prior implementation,
# whose repos were created under $TMPDIR directly and were never cleaned
# up).
CREATED_REPOS_LOG="$WORK/.created-repos.log"
: > "$CREATED_REPOS_LOG"
new_repo() {
  local d
  d="$(mktemp -d "$WORK/repo.XXXXXX")"
  printf '%s\n' "$d" >> "$CREATED_REPOS_LOG"
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

# add_fixture_lines <repo> <relpath> <content...> — like add_fixture_line
# but writes one commit carrying several lines (used for reserved-domain
# forms, one line per form, in a single fixture).
add_fixture_lines() {
  local repo="$1" relpath="$2"; shift 2
  mkdir -p "$(dirname "$repo/$relpath")"
  : > "$repo/$relpath"
  local line
  for line in "$@"; do
    printf '%s\n' "$line" >> "$repo/$relpath"
  done
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
assert_clean "exit-code contract: 0 = clean change" "$CLEAN_REPO" "$CLEAN_BASE"

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
NONGIT="$(mktemp -d "$WORK/nongit.XXXXXX")"
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
# POS/NEG pair: home-encoded (T-1101)
# family: both separators, both roots
# =============================================================================
printf '\n--- POS/NEG pair: home-encoded ---\n'
printf '\n--- family: the encoded-home rule fires on both separators and both roots ---\n'

HE_N1="ma"; HE_N2="rco"
HE_NAME="${HE_N1}${HE_N2}"
HE_N3="le"; HE_N4="na"
HE_NAME2="${HE_N3}${HE_N4}"

# Positive: a hyphen-encoded Users segment, both separators closed.
HE_POS_LINE="backup at -Users-${HE_NAME}- lost"
# Near-miss negative: the ONE feature removed — the separator run never
# closes the name segment (T-1101 AC2).
HE_NEG_LINE="backup at -Users-${HE_NAME} lost"

HE_POS_REPO="$(new_repo)"; HE_POS_BASE="$(git -C "$HE_POS_REPO" rev-parse HEAD)"
add_fixture_line "$HE_POS_REPO" "pos.txt" "$HE_POS_LINE"
assert_finding "POS/NEG pair: home-encoded (positive reported as pattern=home-encoded)" \
  "home-encoded" "$HE_POS_REPO" "$HE_POS_BASE"

HE_NEG_REPO="$(new_repo)"; HE_NEG_BASE="$(git -C "$HE_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$HE_NEG_REPO" "neg.txt" "$HE_NEG_LINE"
assert_clean "POS/NEG pair: home-encoded (near-miss negative NOT reported)" \
  "$HE_NEG_REPO" "$HE_NEG_BASE"

# Family (AC16): underscore-encoded as well as hyphen-encoded; the home
# root as well as the Users root; PLUS the four spellings round-1 review
# found missed by the pre-widening name class (T-1101 rework 1): a
# 2-character name, a hyphen-split (multi-component) name, a digit-led
# name, and an underscore-led name (the real macOS system-account
# convention, e.g. _www) — one fixture, eight lines, eight findings. The
# label text is unchanged (AC16's check is a `grep -qF` on the fixed
# string below, which imposes no cardinality on the fixture set), so this
# is a pure additive extension, not a re-freeze.
HE_N5="a"; HE_N6="b"
HE_SHORT="${HE_N5}${HE_N6}"
HE_N7="a"; HE_N8="b"
HE_HYPHEN_SPLIT="${HE_N7}-${HE_N8}"
HE_N9="123"; HE_N10="4"
HE_DIGIT_LED="${HE_N9}${HE_N10}"
HE_N11="_"; HE_N12="www"
HE_UNDERSCORE_LED="${HE_N11}${HE_N12}"
HE_FAM_LINES=(
  "-Users-${HE_NAME}-"
  "_Users_${HE_NAME}_"
  "-home-${HE_NAME2}-"
  "_home_${HE_NAME2}_"
  "-Users-${HE_SHORT}-"
  "-Users-${HE_HYPHEN_SPLIT}-"
  "-Users-${HE_DIGIT_LED}-"
  "-Users-${HE_UNDERSCORE_LED}-"
)
HE_FAM_REPO="$(new_repo)"; HE_FAM_BASE="$(git -C "$HE_FAM_REPO" rev-parse HEAD)"
add_fixture_lines "$HE_FAM_REPO" "family.txt" "${HE_FAM_LINES[@]}"
set +e
HE_FAM_OUT="$(cd "$HE_FAM_REPO" && bash "$BIN" --base "$HE_FAM_BASE" 2>&1)"
HE_FAM_RC=$?
set -e
HE_FAM_HITS="$(printf '%s\n' "$HE_FAM_OUT" | grep -c '^FINDING pattern=home-encoded path=family\.txt' || true)"
if [ "$HE_FAM_RC" -eq 1 ] && [ "$HE_FAM_HITS" = "${#HE_FAM_LINES[@]}" ]; then
  pass "family: the encoded-home rule fires on both separators and both roots"
else
  fail "family: the encoded-home rule fires on both separators and both roots (rc=$HE_FAM_RC hits=$HE_FAM_HITS out=$HE_FAM_OUT)"
fi

# =============================================================================
# regression lock (T-1101 rework 1+2): the name-class widening must NOT
# make a captured span with NO alphanumeric-or-dot character at all start
# firing — a run composed only of -/_ characters, whatever their mix,
# can never satisfy the mandatory alphanumeric-or-dot requirement. Round 1
# locked the hyphen-only flavour (`-Users---`); round 2 review found `_`
# is a member of BOTH the separator alphabet and (pre-fix) the
# name-continuation class, so a BARE underscore positioned as "the name"
# was a false positive under three independent shapes — underscore
# separators around a lone `_` in both roots, and hyphen separators
# around a lone `_` (proving the gap is about a bare `_` acting as "the
# name", not only about underscore-flavoured separator runs). All four
# shapes are locked here.
# =============================================================================
printf '\n--- regression: a bare separator run (no real name) stays clean after the name-class widening ---\n'
printf '\n--- regression: a bare underscore as the name stays clean, both separator flavours, both roots ---\n'

HE_BARE_LINE="backup at -Users--- lost"
HE_BARE_REPO="$(new_repo)"; HE_BARE_BASE="$(git -C "$HE_BARE_REPO" rev-parse HEAD)"
add_fixture_line "$HE_BARE_REPO" "bare.txt" "$HE_BARE_LINE"
assert_clean "regression: a bare separator run (no real name) stays clean after the name-class widening" \
  "$HE_BARE_REPO" "$HE_BARE_BASE"

# T-1101 rework 2 (round-2 review Minor): a lone `_` as the captured name
# is not a real name — locked clean for both separator flavours and both
# roots, plus the cross-flavour shape (hyphen separators, underscore
# name) that shows the gap was about the character, not the flavour.
HE_LONE_U1="backup at _Users___ lost"
HE_LONE_U2="backup at _home___ lost"
HE_LONE_U3="backup at -Users-_- lost"

HE_LONEU1_REPO="$(new_repo)"; HE_LONEU1_BASE="$(git -C "$HE_LONEU1_REPO" rev-parse HEAD)"
add_fixture_line "$HE_LONEU1_REPO" "lone1.txt" "$HE_LONE_U1"
assert_clean "regression: a bare underscore as the name stays clean (underscore separators, Users root)" \
  "$HE_LONEU1_REPO" "$HE_LONEU1_BASE"

HE_LONEU2_REPO="$(new_repo)"; HE_LONEU2_BASE="$(git -C "$HE_LONEU2_REPO" rev-parse HEAD)"
add_fixture_line "$HE_LONEU2_REPO" "lone2.txt" "$HE_LONE_U2"
assert_clean "regression: a bare underscore as the name stays clean (underscore separators, home root)" \
  "$HE_LONEU2_REPO" "$HE_LONEU2_BASE"

HE_LONEU3_REPO="$(new_repo)"; HE_LONEU3_BASE="$(git -C "$HE_LONEU3_REPO" rev-parse HEAD)"
add_fixture_line "$HE_LONEU3_REPO" "lone3.txt" "$HE_LONE_U3"
assert_clean "regression: a bare underscore as the name stays clean (hyphen separators, Users root)" \
  "$HE_LONEU3_REPO" "$HE_LONEU3_BASE"

# Positive control alongside the three locks above: _www (underscore-LED,
# NOT underscore-ONLY) must still fire — already covered by HE_FAM_LINES'
# HE_UNDERSCORE_LED entry, re-asserted directly here as a standalone
# case so this specific regression section is self-contained proof that
# the fix distinguishes "underscore-led" from "underscore-only".
HE_UWWW_LINE="backup at -Users-${HE_UNDERSCORE_LED}- lost"
HE_UWWW_REPO="$(new_repo)"; HE_UWWW_BASE="$(git -C "$HE_UWWW_REPO" rev-parse HEAD)"
add_fixture_line "$HE_UWWW_REPO" "uwww.txt" "$HE_UWWW_LINE"
assert_finding "positive control: an underscore-LED (not underscore-ONLY) name still fires (_www)" \
  "home-encoded" "$HE_UWWW_REPO" "$HE_UWWW_BASE"

# =============================================================================
# POS/NEG pair: temp-session (T-1101)
# family: every documented temp root, every UUID case spelling
# negative controls: a .shell-team/runs/ citation, and a UUID-free
# machine-local temp citation, each proven to reach the root half of the
# rule (precondition) while the whole rule stays clean
# =============================================================================
printf '\n--- POS/NEG pair: temp-session ---\n'
printf '\n--- family: the temp-session rule fires on every documented temp root and every UUID case spelling ---\n'
printf '\n--- negative control: a committed .shell-team/runs/ citation stays clean ---\n'
printf '\n--- negative control: a UUID-free machine-local temp citation stays clean ---\n'
printf '\n--- precondition: each negative control reaches the temp-session root but not its UUID requirement ---\n'

# UUID fragments (lower, upper, mixed) — assembled so no contiguous
# dashed-hex run ever appears as a completed literal in this file (DP-1).
TS_L1="1b4e28ba"; TS_L2="2fa1"; TS_L3="11d2"; TS_L4="883f"; TS_L5="0016d3cca427"
TS_UUID_LOWER="${TS_L1}-${TS_L2}-${TS_L3}-${TS_L4}-${TS_L5}"
TS_U1="1B4E28BA"; TS_U2="2FA1"; TS_U3="11D2"; TS_U4="883F"; TS_U5="0016D3CCA427"
TS_UUID_UPPER="${TS_U1}-${TS_U2}-${TS_U3}-${TS_U4}-${TS_U5}"
TS_M1="1b4E28ba"; TS_M2="2FA1"; TS_M3="11d2"; TS_M4="883F"; TS_M5="0016d3CCA427"
TS_UUID_MIXED="${TS_M1}-${TS_M2}-${TS_M3}-${TS_M4}-${TS_M5}"

TS_WT1="wt"; TS_WT2="42"
TS_WORKTREE="${TS_WT1}${TS_WT2}"

# Positive: /private/tmp/ root, lowercase UUID.
TS_POS_LINE="scratch at /private/tmp/claude-502/${TS_WORKTREE}-scratch-worktree/${TS_UUID_LOWER}-scratch"
# Near-miss negative: the ONE feature removed — the same root and worktree
# name, no UUID-shaped segment at all (T-1101 AC2).
TS_NEG_LINE="scratch at /private/tmp/claude-502/${TS_WORKTREE}-scratch-worktree"

TS_POS_REPO="$(new_repo)"; TS_POS_BASE="$(git -C "$TS_POS_REPO" rev-parse HEAD)"
add_fixture_line "$TS_POS_REPO" "pos.txt" "$TS_POS_LINE"
assert_finding "POS/NEG pair: temp-session (positive reported as pattern=temp-session)" \
  "temp-session" "$TS_POS_REPO" "$TS_POS_BASE"

TS_NEG_REPO="$(new_repo)"; TS_NEG_BASE="$(git -C "$TS_NEG_REPO" rev-parse HEAD)"
add_fixture_line "$TS_NEG_REPO" "neg.txt" "$TS_NEG_LINE"
assert_clean "POS/NEG pair: temp-session (near-miss negative NOT reported)" \
  "$TS_NEG_REPO" "$TS_NEG_BASE"

# Family (AC16): every documented temp root, every UUID case spelling,
# PLUS the round-1-review-reproduced `=` prefix-character gap (T-1101
# rework 1: RE_TEMP_SESSION_ROOT's class was widened to include a literal
# `=` in the intermediate path segment) — one fixture, five lines, five
# findings. The label text is unchanged (a pure additive extension).
TS_FAM_LINES=(
  "/tmp/${TS_WORKTREE}-scratch/${TS_UUID_LOWER}-work"
  "/var/folders/xy/${TS_WORKTREE}-scratch/T/${TS_UUID_LOWER}-work"
  "/private/tmp/claude-502/${TS_WORKTREE}-scratch/${TS_UUID_UPPER}-work"
  "/private/tmp/claude-502/${TS_WORKTREE}-scratch/${TS_UUID_MIXED}-work"
  "/var/folders/xy=z/${TS_WORKTREE}-scratch/${TS_UUID_LOWER}-work"
)
TS_FAM_REPO="$(new_repo)"; TS_FAM_BASE="$(git -C "$TS_FAM_REPO" rev-parse HEAD)"
add_fixture_lines "$TS_FAM_REPO" "family.txt" "${TS_FAM_LINES[@]}"
set +e
TS_FAM_OUT="$(cd "$TS_FAM_REPO" && bash "$BIN" --base "$TS_FAM_BASE" 2>&1)"
TS_FAM_RC=$?
set -e
TS_FAM_HITS="$(printf '%s\n' "$TS_FAM_OUT" | grep -c '^FINDING pattern=temp-session path=family\.txt' || true)"
if [ "$TS_FAM_RC" -eq 1 ] && [ "$TS_FAM_HITS" = "${#TS_FAM_LINES[@]}" ]; then
  pass "family: the temp-session rule fires on every documented temp root and every UUID case spelling"
else
  fail "family: the temp-session rule fires on every documented temp root and every UUID case spelling (rc=$TS_FAM_RC hits=$TS_FAM_HITS out=$TS_FAM_OUT)"
fi

# Negative controls (AC5): a committed .shell-team/runs/ relative-path
# citation, and a machine-local temp citation carrying a worktree name but
# no UUID-shaped segment — both proven, not assumed, to genuinely reach the
# temp-root half of the rule (read out of the checker's own source, the
# same idiom assert_reaches_email_candidates already established), while
# the whole rule stays clean because the UUID requirement is load-bearing.
RE_TEMP_ROOT_FOR_TEST="$(grep '^RE_TEMP_SESSION_ROOT=' "$BIN" | sed -E "s/^RE_TEMP_SESSION_ROOT='(.*)'\$/\\1/")"
[ -n "$RE_TEMP_ROOT_FOR_TEST" ] || fail "precondition: could not read RE_TEMP_SESSION_ROOT out of $BIN"

assert_reaches_temp_root() {  # $1 = label suffix, $2 = line
  local label="precondition: each negative control reaches the temp-session root but not its UUID requirement ($1)" line="$2"
  printf '%s\n' "$line" > "$WORK/precond-temp-line.txt"
  if grep -qoE -- "$RE_TEMP_ROOT_FOR_TEST" "$WORK/precond-temp-line.txt"; then
    pass "$label"
  else
    fail "$label (line did not reach the temp-session root at all: $line)"
  fi
}

NC_RUNS_LINE="see .shell-team/runs/t1101-routing-map.md, captured under /private/tmp/claude-502/${TS_WORKTREE}-scratch-worktree"
NC_TEMP_LINE="scratch dir /var/folders/xy/${TS_WORKTREE}-scratch-worktree/T/tmp.ABC123"

NC_RUNS_REPO="$(new_repo)"; NC_RUNS_BASE="$(git -C "$NC_RUNS_REPO" rev-parse HEAD)"
add_fixture_line "$NC_RUNS_REPO" "citation.txt" "$NC_RUNS_LINE"
assert_clean "negative control: a committed .shell-team/runs/ citation stays clean" \
  "$NC_RUNS_REPO" "$NC_RUNS_BASE"

NC_TEMP_REPO="$(new_repo)"; NC_TEMP_BASE="$(git -C "$NC_TEMP_REPO" rev-parse HEAD)"
add_fixture_line "$NC_TEMP_REPO" "temp.txt" "$NC_TEMP_LINE"
assert_clean "negative control: a UUID-free machine-local temp citation stays clean" \
  "$NC_TEMP_REPO" "$NC_TEMP_BASE"

assert_reaches_temp_root "runs-citation" "$NC_RUNS_LINE"
assert_reaches_temp_root "worktree-name" "$NC_TEMP_LINE"

# =============================================================================
# POS/NEG pair: email-nonnoreply
#
# DP-9: the noreply exclusion is a domain match, end-anchored, never a
# local-part shape test — three negatives share the noreply domain and
# differ only in local part (a realistic numeric-id+login form, the older
# login-only form, and a printf format placeholder — the shape every suite
# that assembles an identity at runtime necessarily carries). DP-7: the
# reserved-domain exclusion, one negative per form. Two anti-swallow
# positives prove neither exclusion swallows the rule. A precondition
# proves every negative fixture actually reaches the email candidate
# enumeration rather than merely never matching the base shape at all.
# =============================================================================
printf '\n--- POS/NEG pair: email-nonnoreply ---\n'
printf '\n--- negative: the noreply domain, end-anchored, whatever the local part is ---\n'
printf '\n--- negative: a printf format placeholder local part at the noreply domain (runtime-assembly helpers carry one) ---\n'
printf '\n--- negative: one fixture per reserved-domain form ---\n'
printf '\n--- positive: an ordinary domain still fires (anti-swallow) ---\n'
printf '\n--- positive: a suffix-confusable domain at a non-reserved name still fires (anti-swallow) ---\n'
printf '\n--- precondition: each negative fixture reaches the email candidate enumeration ---\n'

EM_L1="ali"; EM_L2="ce"
EM_LOCAL="${EM_L1}${EM_L2}"
EM_ORD_D1="ord"; EM_ORD_D2="inary"
EM_ORD_DOMAIN="${EM_ORD_D1}${EM_ORD_D2}"
EM_POS_LINE="contact ${EM_LOCAL}@${EM_ORD_DOMAIN}.io for details"

# Domain-based noreply negatives (DP-9). Written literally, not fragmented:
# each is a GitHub noreply identity shape, non-PII by design regardless of
# local-part shape (see header note).
EM_NEG_NUMID_LINE="reviewer: 87654321+octocat@users.noreply.github.com"
EM_NEG_LOGINONLY_LINE="reviewer: octocat@users.noreply.github.com"
EM_NEG_FMT_LINE="reviewer: %s+%s@users.noreply.github.com"
EM_NEG_PLAIN_LINE="reviewer: noreply@github.com"

EM_POS_REPO="$(new_repo)"; EM_POS_BASE="$(git -C "$EM_POS_REPO" rev-parse HEAD)"
add_fixture_line "$EM_POS_REPO" "pos.txt" "$EM_POS_LINE"
assert_finding "POS/NEG pair: email-nonnoreply (positive reported as pattern=email-nonnoreply)" \
  "email-nonnoreply" "$EM_POS_REPO" "$EM_POS_BASE"
assert_finding "positive: an ordinary domain still fires (anti-swallow)" \
  "email-nonnoreply" "$EM_POS_REPO" "$EM_POS_BASE"

EM_NEGDOM_REPO="$(new_repo)"; EM_NEGDOM_BASE="$(git -C "$EM_NEGDOM_REPO" rev-parse HEAD)"
add_fixture_line "$EM_NEGDOM_REPO" "numid.txt" "$EM_NEG_NUMID_LINE"
add_fixture_line "$EM_NEGDOM_REPO" "loginonly.txt" "$EM_NEG_LOGINONLY_LINE"
add_fixture_line "$EM_NEGDOM_REPO" "fmt.txt" "$EM_NEG_FMT_LINE"
assert_clean "negative: the noreply domain, end-anchored, whatever the local part is" \
  "$EM_NEGDOM_REPO" "$EM_NEGDOM_BASE"
assert_clean "negative: a printf format placeholder local part at the noreply domain (runtime-assembly helpers carry one)" \
  "$EM_NEGDOM_REPO" "$EM_NEGDOM_BASE"

EM_NEGPLAIN_REPO="$(new_repo)"; EM_NEGPLAIN_BASE="$(git -C "$EM_NEGPLAIN_REPO" rev-parse HEAD)"
add_fixture_line "$EM_NEGPLAIN_REPO" "plain.txt" "$EM_NEG_PLAIN_LINE"
assert_clean "POS/NEG pair: email-nonnoreply (plain web-flow noreply@github.com clean)" \
  "$EM_NEGPLAIN_REPO" "$EM_NEGPLAIN_BASE"

# Reserved-domain negatives (DP-7): one line per form.
RD_L1="som"; RD_L2="ebody"
RD_LOCAL="${RD_L1}${RD_L2}"
EM_NEG_RESERVED_LINES=(
  "contact ${RD_LOCAL}@example.com for details"
  "contact ${RD_LOCAL}@example.org for details"
  "contact ${RD_LOCAL}@example.net for details"
  "contact ${RD_LOCAL}@mail.example for details"
  "contact ${RD_LOCAL}@mail.invalid for details"
  "contact ${RD_LOCAL}@mail.test for details"
  "contact ${RD_LOCAL}@mail.localhost for details"
)
EM_NEGRES_REPO="$(new_repo)"; EM_NEGRES_BASE="$(git -C "$EM_NEGRES_REPO" rev-parse HEAD)"
add_fixture_lines "$EM_NEGRES_REPO" "reserved.txt" "${EM_NEG_RESERVED_LINES[@]}"
assert_clean "negative: one fixture per reserved-domain form" \
  "$EM_NEGRES_REPO" "$EM_NEGRES_BASE"

# Anti-swallow positive #2: a suffix-confusable domain that merely ENDS WITH
# the noreply domain as a substring (no dot boundary) must still fire, and
# its own domain must not be reserved (or DP-7 would clean it for the wrong
# reason and the fixture would prove nothing about anchoring).
EM_SUF_L1="ali"; EM_SUF_L2="ce"
EM_SUF_LOCAL="${EM_SUF_L1}${EM_SUF_L2}"
EM_SUF_PREFIX="evil"
EM_SUF_DOMAIN="${EM_SUF_PREFIX}users.noreply.github.com"
EM_SUF_LINE="contact ${EM_SUF_LOCAL}@${EM_SUF_DOMAIN} for details"
EM_SUF_REPO="$(new_repo)"; EM_SUF_BASE="$(git -C "$EM_SUF_REPO" rev-parse HEAD)"
add_fixture_line "$EM_SUF_REPO" "suffix.txt" "$EM_SUF_LINE"
assert_finding "positive: a suffix-confusable domain at a non-reserved name still fires (anti-swallow)" \
  "email-nonnoreply" "$EM_SUF_REPO" "$EM_SUF_BASE"

# Round 3 blocker regression lock: a DOTTED subdomain of the noreply domain
# (e.g. some-label.users.noreply.github.com) must still fire. `RE_NOREPLY_
# DOMAIN` was originally `(^|\.)users\.noreply\.github\.com$`, which
# admitted any dotted prefix as a legitimate subdomain and silently excluded
# a mailbox-shaped string with a real-looking local part — a genuine bypass
# of a required check, reproduced by cross-provider review and never
# reached by any prior fixture (every existing negative used the bare
# domain, no prefix at all). Fixed to bare `^users\.noreply\.github\.com$`
# equality; this fixture proves the fix and locks the regression.
EM_DOTSUB_L1="ali"; EM_DOTSUB_L2="ce"
EM_DOTSUB_LOCAL="${EM_DOTSUB_L1}${EM_DOTSUB_L2}"
EM_DOTSUB_PREFIX="evil"
EM_DOTSUB_DOMAIN="${EM_DOTSUB_PREFIX}.users.noreply.github.com"
EM_DOTSUB_LINE="contact ${EM_DOTSUB_LOCAL}@${EM_DOTSUB_DOMAIN} for details"
EM_DOTSUB_REPO="$(new_repo)"; EM_DOTSUB_BASE="$(git -C "$EM_DOTSUB_REPO" rev-parse HEAD)"
add_fixture_line "$EM_DOTSUB_REPO" "dotsub.txt" "$EM_DOTSUB_LINE"
assert_finding "positive: a dotted subdomain of the noreply domain still fires (round 3 blocker regression lock)" \
  "email-nonnoreply" "$EM_DOTSUB_REPO" "$EM_DOTSUB_BASE"

# Precondition: every negative fixture line above provably reaches the
# email candidate enumeration (RE_EMAIL_BASE, read from the checker's own
# source) — never merely a line the base shape never matched at all. The
# bracketed AC9 placeholder form deliberately does NOT satisfy this (the
# brackets fall outside the local-part class), which is why it belongs to
# AC9 and can never stand in for one of these fixtures.
RE_EMAIL_BASE_FOR_TEST="$(grep '^RE_EMAIL_BASE=' "$BIN" | sed -E "s/^RE_EMAIL_BASE='(.*)'\$/\\1/")"
[ -n "$RE_EMAIL_BASE_FOR_TEST" ] || fail "precondition: could not read RE_EMAIL_BASE out of $BIN"

assert_reaches_email_candidates() {  # $1 = label suffix, $2 = line
  local label="precondition: each negative fixture reaches the email candidate enumeration ($1)" line="$2"
  printf '%s\n' "$line" > "$WORK/precond-line.txt"
  if grep -qoE -- "$RE_EMAIL_BASE_FOR_TEST" "$WORK/precond-line.txt"; then
    pass "$label"
  else
    fail "$label (line did not reach the email candidate enumeration at all: $line)"
  fi
}
assert_reaches_email_candidates "numeric-id+login" "$EM_NEG_NUMID_LINE"
assert_reaches_email_candidates "login-only" "$EM_NEG_LOGINONLY_LINE"
assert_reaches_email_candidates "printf-format-placeholder" "$EM_NEG_FMT_LINE"
assert_reaches_email_candidates "plain-web-flow" "$EM_NEG_PLAIN_LINE"
for _rd_line in "${EM_NEG_RESERVED_LINES[@]}"; do
  assert_reaches_email_candidates "reserved-domain" "$_rd_line"
done

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
# A truncated "ghp_" prefix is too short to match RE_TOKEN's minimum
# key-body length. "task-043" is additionally blocked by the sk-
# alternative's left boundary guard (T-1051 #178) — it is preceded by a
# letter, not by line start or a non-alphanumeric character — so this stays
# clean for a boundary reason now, not (only) a length reason; the boundary
# case with a LONG lookalike tail is exercised on its own below.
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
# boundary: an identifier-adjacent label lookalike does not fire (token)
# boundary: a non-identifier boundary still fires (start, dot, hyphen, slash)
# positive: an unguarded prefix still fires after a letter (gh form)
# T-1051 #178 (DP1/DP2): the sk- alternative gains a left boundary guard,
# class [^A-Za-z0-9] — deliberately narrower than RE_HOME_PATH_BOUNDARY's,
# since a token has no host-name-continuation problem. gh[oprs]_ and AKIA
# stay unanchored (no measured false-positive carrier in this tree; a false
# negative is the costlier error, DP-10).
# =============================================================================
printf '\n--- boundary: an identifier-adjacent label lookalike does not fire (token) ---\n'
printf '\n--- boundary: a non-identifier boundary still fires (start, dot, hyphen, slash) ---\n'
printf '\n--- positive: an unguarded prefix still fires after a letter (gh form) ---\n'

# A LONG kebab-case lookalike (16-char tail, well past RE_TOKEN's minimum key
# body) whose only overlap with the pattern is ending in the letters s+k
# before a hyphen — this repository's own label convention among them. The
# short negative above already proved a SHORT lookalike is clean; this
# proves a LONG one is clean too, for the boundary reason and not the
# length reason (the guard was the point of #178, not incidental brevity).
TKG_N1="ta"; TKG_N2="sk-"; TKG_N3="ABCDEFGHIJKLMNOP"
TKG_LOOKALIKE_LONG="${TKG_N1}${TKG_N2}${TKG_N3}"

TKG_LONG_REPO="$(new_repo)"; TKG_LONG_BASE="$(git -C "$TKG_LONG_REPO" rev-parse HEAD)"
add_fixture_line "$TKG_LONG_REPO" "longlookalike.txt" "see ${TKG_LOOKALIKE_LONG} here"
assert_clean "boundary: an identifier-adjacent label lookalike does not fire (token)" \
  "$TKG_LONG_REPO" "$TKG_LONG_BASE"

# A real key body at every boundary DP-10 requires to fire: line start,
# after a space, after a hyphen, after a dot, after a slash — the four
# boundary characters DP-5's class would have suppressed.
TKG_B1="ABCDEFGHIJ"; TKG_B2="KLMNOP12"
TKG_KEY="sk-${TKG_B1}${TKG_B2}"
TKG_BOUND_LINES=(
  "${TKG_KEY}"
  "value ${TKG_KEY}"
  "id-${TKG_KEY}"
  "v1.${TKG_KEY}"
  "/${TKG_KEY}"
)
TKG_BOUND_REPO="$(new_repo)"; TKG_BOUND_BASE="$(git -C "$TKG_BOUND_REPO" rev-parse HEAD)"
add_fixture_lines "$TKG_BOUND_REPO" "boundaries.txt" "${TKG_BOUND_LINES[@]}"
set +e
TKG_BOUND_OUT="$(cd "$TKG_BOUND_REPO" && bash "$BIN" --base "$TKG_BOUND_BASE" 2>&1)"
TKG_BOUND_RC=$?
set -e
TKG_BOUND_HITS="$(printf '%s\n' "$TKG_BOUND_OUT" | grep -c '^FINDING pattern=token path=boundaries\.txt' || true)"
if [ "$TKG_BOUND_RC" -eq 1 ] && [ "$TKG_BOUND_HITS" = "${#TKG_BOUND_LINES[@]}" ]; then
  pass "boundary: a non-identifier boundary still fires (start, dot, hyphen, slash)"
else
  fail "boundary: a non-identifier boundary still fires (start, dot, hyphen, slash) (rc=$TKG_BOUND_RC hits=$TKG_BOUND_HITS out=$TKG_BOUND_OUT)"
fi

# The gh form's own alternative stays unguarded: immediately preceded by a
# letter (never an '=' or a space, unlike the POS/NEG pair above), it must
# still fire — proving the guard was attached to the sk- alternative only,
# not to the whole group.
TKG_GH_REPO="$(new_repo)"; TKG_GH_BASE="$(git -C "$TKG_GH_REPO" rev-parse HEAD)"
add_fixture_line "$TKG_GH_REPO" "ghletter.txt" "x${TK_P1}${TK_P2}${TK_B1}${TK_B2}"
assert_finding "positive: an unguarded prefix still fires after a letter (gh form)" \
  "token" "$TKG_GH_REPO" "$TKG_GH_BASE"

# =============================================================================
# disclosed: alnum-adjacent zero-separator sk form is suppressed by design
# (#178 complement) — T-1051 v3 (DP2 *Class*, Goal): the accepted, disclosed
# exception. A real sk- key sitting immediately after a letter, and again
# immediately after a digit, with no separating character, is suppressed —
# the mathematical complement of the false-positive class #178 asks this
# guard to close, since one character of left context cannot tell a real
# unseparated key apart from the label-chain lookalike above. The
# space-separated form one character away already fires ("boundary: a
# non-identifier boundary still fires", above) — only the zero-separator,
# alnum-adjacent position is accepted as suppressed.
# =============================================================================
printf '\n--- disclosed: alnum-adjacent zero-separator sk form is suppressed by design (#178 complement) ---\n'

TKD_LETTER_LINE="x${TKG_KEY}"
TKD_DIGIT_LINE="9${TKG_KEY}"
TKD_REPO="$(new_repo)"; TKD_BASE="$(git -C "$TKD_REPO" rev-parse HEAD)"
add_fixture_lines "$TKD_REPO" "zeroseparator.txt" "$TKD_LETTER_LINE" "$TKD_DIGIT_LINE"
assert_clean "disclosed: alnum-adjacent zero-separator sk form is suppressed by design (#178 complement)" \
  "$TKD_REPO" "$TKD_BASE"

# =============================================================================
# mutation: the token boundary is load-bearing (pre-fix rule reports the
# lookalike) — T-1051 #178, DP3: the step-0 measurement found no live red
# carrier for this defect on this branch (both --base develop and --all were
# clean pre-fix), so the proof that the OLD, unguarded rule would have
# reported the new long-lookalike fixture is a mutation, not a CI red — the
# same neutralised-copy idiom the mutation blocks above already use.
# =============================================================================
printf '\n--- mutation: the token boundary is load-bearing (pre-fix rule reports the lookalike) ---\n'

TOKEN_PREFIX_MUT="$(mktemp "$WORK/mut.XXXXXX")"
sed "s/^RE_TOKEN=.*/RE_TOKEN='gh[oprs]_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{12,}|${TKG_N2}[A-Za-z0-9_-]{16,}'/" "$BIN" > "$TOKEN_PREFIX_MUT"
set +e
TOKEN_PREFIX_MUT_OUT="$(cd "$TKG_LONG_REPO" && bash "$TOKEN_PREFIX_MUT" --base "$TKG_LONG_BASE" 2>&1)"
TOKEN_PREFIX_MUT_RC=$?
set -e
if [ "$TOKEN_PREFIX_MUT_RC" -eq 1 ] && printf '%s\n' "$TOKEN_PREFIX_MUT_OUT" | grep -qE 'pattern=token path=longlookalike\.txt'; then
  pass "mutation: the token boundary is load-bearing (pre-fix rule reports the lookalike)"
else
  fail "mutation: the token boundary is load-bearing (pre-fix rule reports the lookalike) (rc=$TOKEN_PREFIX_MUT_RC out=$TOKEN_PREFIX_MUT_OUT)"
fi
rm -f "$TOKEN_PREFIX_MUT"

# =============================================================================
# placeholder forms are not findings (AC9, T-1101-extended) — a permanent
# false-positive regression case: the four documented placeholder forms
# T-111 already ships, together with the two this task introduces
# (-Users-<name>-, _home_<name>_) and a temp path whose session segment is
# written <session-uuid> — all six documented forms, one change, clean.
# =============================================================================
printf '\n--- placeholder forms are not findings ---\n'

PH_REPO="$(new_repo)"; PH_BASE="$(git -C "$PH_REPO" rev-parse HEAD)"
{
  printf '%s\n' 'example: /Users/<name>/Documents'
  printf '%s\n' 'example: /home/<name>/Documents'
  printf '%s\n' 'example: C:\Users\<name>\AppData'
  printf '%s\n' 'example: <id>+<login>@users.noreply.github.com'
  printf '%s\n' 'example: -Users-<name>-Documents'
  printf '%s\n' 'example: _home_<name>_Documents'
  printf '%s\n' 'example: /private/tmp/claude-502/<session-uuid>-scratch'
} > "$PH_REPO/placeholders.md"
git -C "$PH_REPO" add placeholders.md
git -C "$PH_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: placeholders.md"
assert_clean "placeholder forms are not findings (all six documented forms, one change, clean)" \
  "$PH_REPO" "$PH_BASE"

# =============================================================================
# boundary (AC28 / DP-5 final narrow form, DP-10 bias-toward-firing):
# suppression happens ONLY when the character immediately before the
# leading `/` can continue a host name (an ASCII letter, digit, dot, or
# hyphen). That is exactly what closes the one measured, in-tree false
# positive (a bare documentation URL) and nothing more. Round 3 widened the
# suppression to also exclude `/` and `]`, quieting a file://-style
# authority, a Markdown-wrapped one, and an IPv6 literal authority — round 4
# reverts that: it silenced two mechanically reachable true positives (a
# doubled-leading-slash path, a bracket-adjacent path), and a reviewer or
# QA finding that some input "looks like a false positive" is no longer
# grounds for widening this rule (DP-10) — it is grounds for the declared
# classes in the documents (AC18/AC19) or the placeholder discipline (AC9)
# at the authoring site instead. The three previously-suppressed classes
# are therefore expected to FIRE below, same as the two new positives.
# =============================================================================
printf '\n--- boundary: only a host-name character suppresses, so the bare documentation URL stays clean ---\n'

URL_LINE="See https://example.com/home/products for details"
URL_REPO="$(new_repo)"; URL_BASE="$(git -C "$URL_REPO" rev-parse HEAD)"
add_fixture_line "$URL_REPO" "url.txt" "$URL_LINE"
assert_clean "boundary: only a host-name character suppresses, so the bare documentation URL stays clean" \
  "$URL_REPO" "$URL_BASE"

printf '\n--- positive: a doubled-leading-slash home path fires (fail-noisy, bash diagnostics emit this) ---\n'

DBLSLASH_LINE="bash: //Users/${HP_NAME}/data: No such file or directory"
DBLSLASH_REPO="$(new_repo)"; DBLSLASH_BASE="$(git -C "$DBLSLASH_REPO" rev-parse HEAD)"
add_fixture_line "$DBLSLASH_REPO" "dblslash.txt" "$DBLSLASH_LINE"
assert_finding "positive: a doubled-leading-slash home path fires (fail-noisy, bash diagnostics emit this)" \
  "home-path" "$DBLSLASH_REPO" "$DBLSLASH_BASE"

printf '\n--- positive: a home path preceded by a bracket fires (fail-noisy, xtrace prefixes emit this) ---\n'

BRACKET_LINE="[worker-3]/Users/${HP_NAME}/data processed"
BRACKET_REPO="$(new_repo)"; BRACKET_BASE="$(git -C "$BRACKET_REPO" rev-parse HEAD)"
add_fixture_line "$BRACKET_REPO" "bracket.txt" "$BRACKET_LINE"
assert_finding "positive: a home path preceded by a bracket fires (fail-noisy, xtrace prefixes emit this)" \
  "home-path" "$BRACKET_REPO" "$BRACKET_BASE"

# DP-10: the three classes round 3 suppressed are accepted noise now,
# declared in the documents (AC18/AC19) rather than chased in the regex —
# these are positive fixtures (not silence locks) so a future round cannot
# quietly re-widen the boundary and have this suite stay silent about it.
FILEURL_LINE="backup at file:///Users/${HP_NAME}/secrets.txt for review"
FILEURL_REPO="$(new_repo)"; FILEURL_BASE="$(git -C "$FILEURL_REPO" rev-parse HEAD)"
add_fixture_line "$FILEURL_REPO" "fileurl.txt" "$FILEURL_LINE"
assert_finding "accepted noise: a file:// triple-slash authority fires (declared in docs, not suppressed — round 4)" \
  "home-path" "$FILEURL_REPO" "$FILEURL_BASE"

MDURL_LINE="[local notes](file:///home/${HP_NAME}/private.txt)"
MDURL_REPO="$(new_repo)"; MDURL_BASE="$(git -C "$MDURL_REPO" rev-parse HEAD)"
add_fixture_line "$MDURL_REPO" "mdurl.txt" "$MDURL_LINE"
assert_finding "accepted noise: a Markdown link wrapping a file:// URL fires (declared in docs, not suppressed — round 4)" \
  "home-path" "$MDURL_REPO" "$MDURL_BASE"

IPV6URL_LINE="see https://[2001:db8::1]/Users/${HP_NAME}/secrets.txt for details"
IPV6URL_REPO="$(new_repo)"; IPV6URL_BASE="$(git -C "$IPV6URL_REPO" rev-parse HEAD)"
add_fixture_line "$IPV6URL_REPO" "ipv6url.txt" "$IPV6URL_LINE"
assert_finding "accepted noise: an IPv6 literal authority fires (declared in docs, not suppressed — round 4)" \
  "home-path" "$IPV6URL_REPO" "$IPV6URL_BASE"

# =============================================================================
# all candidates per line: an excluded address on the same line never
# masks a real mailbox shape (AC26)
# =============================================================================
printf '\n--- all candidates per line: an excluded address on the same line never masks a real mailbox shape ---\n'

MIXED_LINE="reviewer: ${EM_NEG_PLAIN_LINE#reviewer: } and contact ${EM_LOCAL}@${EM_ORD_DOMAIN}.io for details"
EXCLUDED_ONLY_LINE="reviewer: ${EM_NEG_PLAIN_LINE#reviewer: } and 87654321+octocat@users.noreply.github.com"

MIXED_REPO="$(new_repo)"; MIXED_BASE="$(git -C "$MIXED_REPO" rev-parse HEAD)"
add_fixture_line "$MIXED_REPO" "mixed.txt" "$MIXED_LINE"
assert_finding "all candidates per line: an excluded address on the same line never masks a real mailbox shape (mixed line fires)" \
  "email-nonnoreply" "$MIXED_REPO" "$MIXED_BASE"

EXCLONLY_REPO="$(new_repo)"; EXCLONLY_BASE="$(git -C "$EXCLONLY_REPO" rev-parse HEAD)"
add_fixture_line "$EXCLONLY_REPO" "exclonly.txt" "$EXCLUDED_ONLY_LINE"
assert_clean "all candidates per line: a line carrying only excluded forms is clean" \
  "$EXCLONLY_REPO" "$EXCLONLY_BASE"

# =============================================================================
# text-vs-binary: NUL byte decides, Japanese prose is scanned, a skip is
# announced (AC27)
# =============================================================================
printf '\n--- text-vs-binary: NUL byte decides, Japanese prose is scanned, a skip is announced ---\n'

JP_N1="ke"; JP_N2="nji"
JP_NAME="${JP_N1}${JP_N2}"
# A UTF-8 Japanese sentence (full-width punctuation included) that also
# carries a home-path shape with an ASCII name segment.
JP_LINE="日本語の文章です。/Users/${JP_NAME}/secret.txt が含まれています。"

JP_REPO="$(new_repo)"; JP_BASE="$(git -C "$JP_REPO" rev-parse HEAD)"
add_fixture_line "$JP_REPO" "jp.txt" "$JP_LINE"
assert_finding "text-vs-binary: NUL byte decides, Japanese prose is scanned (diff mode)" \
  "home-path" "$JP_REPO" "$JP_BASE"

set +e
JP_ALL_OUT="$(cd "$JP_REPO" && bash "$BIN" --all 2>&1)"
JP_ALL_RC=$?
set -e
if [ "$JP_ALL_RC" -eq 1 ] && printf '%s\n' "$JP_ALL_OUT" | grep -qE 'pattern=home-path path=jp\.txt'; then
  pass "text-vs-binary: NUL byte decides, Japanese prose is scanned (--all mode)"
else
  fail "text-vs-binary: NUL byte decides, Japanese prose is scanned (--all mode) (rc=$JP_ALL_RC out=$JP_ALL_OUT)"
fi

# A blob containing a NUL byte is not scanned, and the skip is announced on
# stderr — never silent. This fixture's ONLY other content is a home-path
# shape sharing the same commit; if the binary blob were skipped SILENTLY
# there would be no stderr trace at all, and if it were scanned as text the
# run would still be rc=1 for an unrelated reason, so the assertion checks
# BOTH the exit code (clean — nothing else in this repo carries a shape)
# AND the presence of an explicit skip announcement.
NUL_REPO="$(new_repo)"; NUL_BASE="$(git -C "$NUL_REPO" rev-parse HEAD)"
printf 'binary\x00blob\x00with\x00nul\x00bytes\n' > "$NUL_REPO/bin.dat"
git -C "$NUL_REPO" add bin.dat
git -C "$NUL_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: bin.dat"
set +e
NUL_OUT="$(cd "$NUL_REPO" && bash "$BIN" --base "$NUL_BASE" 2>&1)"
NUL_RC=$?
set -e
if [ "$NUL_RC" -eq 0 ] && printf '%s\n' "$NUL_OUT" | grep -qE 'skip: binary blob \(NUL byte present\), not scanned: bin\.dat'; then
  pass "text-vs-binary: NUL byte decides, Japanese prose is scanned, a skip is announced (binary blob skipped, announced, not silent)"
else
  fail "text-vs-binary: NUL byte decides, a skip is announced (rc=$NUL_RC out=$NUL_OUT)"
fi

# =============================================================================
# mutation: pattern is load-bearing (AC10, vacuity guard / detector side,
# patterns half)
#
# For every pattern: rewrite JUST that pattern's own regex assignment line,
# in a throwaway copy of the real checker, to a placeholder that can never
# match real content, then re-run that pattern's OWN positive fixture
# (already proven, above, to be reported by the REAL checker) against the
# copy. The copy must now report NOTHING for that pattern — proving the
# pattern is individually load-bearing.
# =============================================================================
printf '\n--- mutation: pattern is load-bearing ---\n'

NEVER_MATCH="NEUTRALISED_NO_MATCH_PLACEHOLDER_ZZZ_T111"

neutralize_copy() {  # $1 = variable name, $2 = replacement (single-quoted
                      # bash literal, no embedded quotes); prints copy path
  local varname="$1" replacement="$2" copy
  copy="$(mktemp "$WORK/mut.XXXXXX")"
  sed "s/^${varname}=.*/${varname}='${replacement}'/" "$BIN" > "$copy"
  printf '%s' "$copy"
}

assert_neutralised_pattern_unreported() {  # $1=var $2=label $3=repo $4=base
  local varname="$1" label="$2" repo="$3" base="$4" copy out rc
  copy="$(neutralize_copy "$varname" "$NEVER_MATCH")"
  set +e
  out="$(cd "$repo" && bash "$copy" --base "$base" 2>&1)"
  rc=$?
  set -e
  rm -f "$copy"
  if [ "$rc" -eq 0 ] || ! printf '%s\n' "$out" | grep -q '^FINDING'; then
    if [ "$rc" -eq 0 ]; then
      pass "$label"
    else
      fail "$label (neutralised copy exited $rc with no FINDING line — unexpected shape of failure: $out)"
    fi
  else
    fail "$label (neutralised copy still reported something: rc=$rc out=$out)"
  fi
}

assert_neutralised_pattern_unreported RE_HOME_PATH_RAW \
  "mutation: pattern is load-bearing (home-path neutralised -> its own positive fixture reports nothing)" \
  "$HP_POS_REPO" "$HP_POS_BASE"
assert_neutralised_pattern_unreported RE_HOME_PATH_WIN \
  "mutation: pattern is load-bearing (home-path-win neutralised -> its own positive fixture reports nothing)" \
  "$WP_POS_REPO" "$WP_POS_BASE"
assert_neutralised_pattern_unreported RE_EMAIL_BASE \
  "mutation: pattern is load-bearing (email-nonnoreply neutralised -> its own positive fixture reports nothing)" \
  "$EM_POS_REPO" "$EM_POS_BASE"
assert_neutralised_pattern_unreported RE_PRIVATE_KEY \
  "mutation: pattern is load-bearing (private-key neutralised -> its own positive fixture reports nothing)" \
  "$PK_POS_REPO" "$PK_POS_BASE"
assert_neutralised_pattern_unreported RE_TOKEN \
  "mutation: pattern is load-bearing (token neutralised -> its own positive fixture reports nothing)" \
  "$TK_POS_REPO" "$TK_POS_BASE"
assert_neutralised_pattern_unreported RE_HOME_ENCODED \
  "mutation: pattern is load-bearing (home-encoded neutralised -> its own positive fixture reports nothing)" \
  "$HE_POS_REPO" "$HE_POS_BASE"
assert_neutralised_pattern_unreported RE_TEMP_SESSION_ROOT \
  "mutation: pattern is load-bearing (temp-session neutralised -> its own positive fixture reports nothing)" \
  "$TS_POS_REPO" "$TS_POS_BASE"

# =============================================================================
# mutation: each exclusion is load-bearing (AC10, vacuity guard / detector
# side, exclusions half)
#
# For every one of the four exclusions: neutralise JUST that exclusion's own
# rule in a throwaway copy, then re-run that exclusion's OWN negative
# fixture(s) (already proven, above, to be clean against the REAL checker)
# against the copy. Each must now become a FINDING — proving the exclusion
# is the reason the fixture was clean, not that it never reached the base
# pattern at all.
# =============================================================================
printf '\n--- mutation: each exclusion is load-bearing ---\n'

assert_neutralised_exclusion_fires() {  # $1=label $2=id $3=copy $4=repo $5=base
  local label="$1" id="$2" copy="$3" repo="$4" base="$5" out rc
  set +e
  out="$(cd "$repo" && bash "$copy" --base "$base" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qE "pattern=${id} path="; then
    pass "$label"
  else
    fail "$label (neutralised exclusion did not become a finding: rc=$rc out=$out)"
  fi
}

# Domain-anchored noreply rule (DP-9): neutralising it must flip ALL of its
# negatives, the format-placeholder fixture included.
NOREPLY_DOMAIN_MUT="$(neutralize_copy RE_NOREPLY_DOMAIN "$NEVER_MATCH")"
assert_neutralised_exclusion_fires \
  "mutation: each exclusion is load-bearing (domain-anchored noreply rule, numeric-id+login negative flips)" \
  "email-nonnoreply" "$NOREPLY_DOMAIN_MUT" "$EM_NEGDOM_REPO" "$EM_NEGDOM_BASE"
set +e
NOREPLY_DOMAIN_MUT_OUT="$(cd "$EM_NEGDOM_REPO" && bash "$NOREPLY_DOMAIN_MUT" --base "$EM_NEGDOM_BASE" 2>&1)"
set -e
if printf '%s\n' "$NOREPLY_DOMAIN_MUT_OUT" | grep -qE 'pattern=email-nonnoreply path=loginonly\.txt' \
   && printf '%s\n' "$NOREPLY_DOMAIN_MUT_OUT" | grep -qE 'pattern=email-nonnoreply path=fmt\.txt'; then
  pass "mutation: each exclusion is load-bearing (domain-anchored noreply rule flips the login-only AND the format-placeholder negatives too)"
else
  fail "mutation: each exclusion is load-bearing (domain-anchored noreply rule did not flip all its negatives: $NOREPLY_DOMAIN_MUT_OUT)"
fi
rm -f "$NOREPLY_DOMAIN_MUT"

# Plain web-flow address: its own, separate exclusion.
NOREPLY_PLAIN_MUT="$(neutralize_copy RE_NOREPLY_PLAIN "$NEVER_MATCH")"
assert_neutralised_exclusion_fires \
  "mutation: each exclusion is load-bearing (plain web-flow address)" \
  "email-nonnoreply" "$NOREPLY_PLAIN_MUT" "$EM_NEGPLAIN_REPO" "$EM_NEGPLAIN_BASE"
rm -f "$NOREPLY_PLAIN_MUT"

# Reserved-domain rule (DP-7): neutralising it must flip every reserved form.
RESERVED_MUT="$(neutralize_copy RE_RESERVED_DOMAIN "$NEVER_MATCH")"
set +e
RESERVED_MUT_OUT="$(cd "$EM_NEGRES_REPO" && bash "$RESERVED_MUT" --base "$EM_NEGRES_BASE" 2>&1)"
RESERVED_MUT_RC=$?
set -e
RESERVED_MUT_HITS="$(printf '%s\n' "$RESERVED_MUT_OUT" | grep -c '^FINDING pattern=email-nonnoreply path=reserved\.txt' || true)"
if [ "$RESERVED_MUT_RC" -eq 1 ] && [ "$RESERVED_MUT_HITS" = "${#EM_NEG_RESERVED_LINES[@]}" ]; then
  pass "mutation: each exclusion is load-bearing (reserved-domain rule flips every reserved form)"
else
  fail "mutation: each exclusion is load-bearing (reserved-domain rule) (rc=$RESERVED_MUT_RC hits=$RESERVED_MUT_HITS out=$RESERVED_MUT_OUT)"
fi
rm -f "$RESERVED_MUT"

# Home-path boundary rule (DP-5): neutralising it (stripping just the
# boundary alternation, not the shape) must flip the URL negative to a
# finding.
BOUNDARY_MUT="$(mktemp "$WORK/mut.XXXXXX")"
sed "s/^RE_HOME_PATH_BOUNDARY=.*/RE_HOME_PATH_BOUNDARY=''/" "$BIN" > "$BOUNDARY_MUT"
assert_neutralised_exclusion_fires \
  "mutation: each exclusion is load-bearing (home-path boundary rule flips the URL negative)" \
  "home-path" "$BOUNDARY_MUT" "$URL_REPO" "$URL_BASE"
rm -f "$BOUNDARY_MUT"

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
assert_meta_fails email-nonnoreply "$EM_NEGPLAIN_REPO" "$EM_NEGPLAIN_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (email-nonnoreply)"
assert_meta_fails private-key "$PK_NEG_REPO" "$PK_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (private-key)"
assert_meta_fails token "$TK_NEG_REPO" "$TK_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (token)"
assert_meta_fails home-encoded "$HE_NEG_REPO" "$HE_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (home-encoded)"
assert_meta_fails temp-session "$TS_NEG_REPO" "$TS_NEG_BASE" \
  "meta: neutralised positive fixture makes the assertion FAIL (temp-session)"

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
# known-shapes list: exact contents asserted, per-file only, no directory
# or glob entry (AC13, DP-8)
# =============================================================================
printf '\n--- known-shapes list: exact contents asserted, per-file only, no directory or glob entry ---\n'

KNOWN_ACTUAL_FILE="$WORK/known-actual.txt"
sed -n '/^KNOWN_SHAPE_PATHS=(/,/^)/p' "$BIN" | grep -oE '"[^"]*"' | tr -d '"' | sort > "$KNOWN_ACTUAL_FILE"

KNOWN_EXPECTED_FILE="$WORK/known-expected.txt"
{
  printf '%s\n' "tests/rollup-track/fixtures/secret-aws.jsonl"
  printf '%s\n' "tests/rollup-track/fixtures/secret-github.jsonl"
  printf '%s\n' "tests/rollup-track/fixtures/secret-openai.jsonl"
  printf '%s\n' "tests/rollup-track/fixtures/winpath.jsonl"
} | sort > "$KNOWN_EXPECTED_FILE"

if cmp -s "$KNOWN_ACTUAL_FILE" "$KNOWN_EXPECTED_FILE"; then
  pass "known-shapes list: exact contents asserted"
else
  fail "known-shapes list: exact contents asserted (actual: $(tr '\n' ' ' < "$KNOWN_ACTUAL_FILE"); expected: $(tr '\n' ' ' < "$KNOWN_EXPECTED_FILE"))"
fi

known_list_ok=1
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  case "$entry" in
    */) known_list_ok=0 ;;          # a directory entry
    *'*'*|*'?'*|*'['*) known_list_ok=0 ;;  # a glob entry
  esac
done < "$KNOWN_ACTUAL_FILE"
if [ "$known_list_ok" -eq 1 ]; then
  pass "known-shapes list: exact contents asserted, per-file only, no directory or glob entry"
else
  fail "known-shapes list: exact contents asserted, per-file only, no directory or glob entry (a directory or glob entry was found)"
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
# --all no-silent-skip: repo-root scope, symlink target, = in a filename,
# unreadable is exit 2 (AC29)
# =============================================================================
printf '\n--- --all no-silent-skip: repo-root scope, symlink target, = in a filename, unreadable is exit 2 ---\n'

ALL_REPO="$(new_repo)"
mkdir -p "$ALL_REPO/deepsub"
printf 'nothing sensitive here\n' > "$ALL_REPO/deepsub/placeholder.txt"
git -C "$ALL_REPO" add deepsub/placeholder.txt
git -C "$ALL_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: deepsub/placeholder.txt"

# repo-root scope: a shape at the repo root must still be found when
# invoked from a subdirectory.
printf '%s\n' "$HP_POS_LINE" > "$ALL_REPO/root-shape.txt"
git -C "$ALL_REPO" add root-shape.txt
git -C "$ALL_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: root-shape.txt"

# symlink target: git stores the target STRING as the blob content — must
# be scanned as that string, never by following the link.
SYM_TARGET="/Users/${HP_NAME}/data"
( cd "$ALL_REPO" && ln -s "$SYM_TARGET" symlink-fixture )
git -C "$ALL_REPO" add symlink-fixture
git -C "$ALL_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: symlink-fixture"

# = in a filename: must be read via redirection, never passed as a bare
# argument to a tool that could parse "name=value" as an assignment.
printf '%s\n' "$HP_POS_LINE" > "$ALL_REPO/notes=with-equals.txt"
git -C "$ALL_REPO" add "notes=with-equals.txt"
git -C "$ALL_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: notes=with-equals.txt"

set +e
ALL_OUT="$(cd "$ALL_REPO/deepsub" && bash "$BIN" --all 2>&1)"
ALL_RC=$?
set -e
if [ "$ALL_RC" -eq 1 ] \
   && printf '%s\n' "$ALL_OUT" | grep -qE 'pattern=home-path path=root-shape\.txt' \
   && printf '%s\n' "$ALL_OUT" | grep -qE 'pattern=home-path path=symlink-fixture' \
   && printf '%s\n' "$ALL_OUT" | grep -qE 'pattern=home-path path=notes=with-equals\.txt'; then
  pass "--all no-silent-skip: repo-root scope, symlink target, = in a filename"
else
  fail "--all no-silent-skip: repo-root scope, symlink target, = in a filename (rc=$ALL_RC out=$ALL_OUT)"
fi

# unreadable is exit 2, never a skip.
UNREAD_REPO="$(new_repo)"
printf 'irrelevant content\n' > "$UNREAD_REPO/unreadable.txt"
git -C "$UNREAD_REPO" add unreadable.txt
git -C "$UNREAD_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: unreadable.txt"
chmod 000 "$UNREAD_REPO/unreadable.txt"
set +e
( cd "$UNREAD_REPO" && bash "$BIN" --all >/dev/null 2>&1 )
UNREAD_RC=$?
set -e
chmod 644 "$UNREAD_REPO/unreadable.txt"
if [ "$UNREAD_RC" -eq 2 ]; then
  pass "--all no-silent-skip: unreadable is exit 2"
else
  fail "--all no-silent-skip: unreadable is exit 2 (got rc=$UNREAD_RC)"
fi

# =============================================================================
# gitlink: a submodule reference is skipped, announced, never scanned as
# content, and never a raw unclassified exit (round 3 major regression lock)
#
# `git submodule add` (or, equivalently, `git update-index --add --cacheinfo
# 160000,<sha>,<path>`, used here to avoid a network dependency) creates a
# gitlink entry (mode 160000) with no blob of its own. `git cat-file -p
# HEAD:<path>` fails on it (`fatal: Not a valid object name`, rc=128).
# Before this fix that failure sat on a bare (non-`||`) line under `set -e`,
# so errexit fired before the classified `rc=$?; if ...` check ever ran —
# the script exited 128 with NO `check-pii-shapes:` token at all, breaking
# the documented 0/1/2 exit-code contract (AC2) even though it never
# reported a false "clean". Fixed by detecting the gitlink's mode during
# enumeration (from `git diff --raw`'s new-mode field, and from `git
# ls-files -s`'s mode field for --all) and skipping it explicitly, and
# separately by moving the `cat-file` failure onto a same-line `||` so any
# OTHER cat-file failure also lands on the classified path.
# =============================================================================
printf '\n--- gitlink: a submodule reference is skipped, never scanned, never a raw unclassified exit ---\n'

GITLINK_REPO="$(new_repo)"; GITLINK_BASE="$(git -C "$GITLINK_REPO" rev-parse HEAD)"
FAKE_SUBMODULE_SHA="1111111111111111111111111111111111111111"
git -C "$GITLINK_REPO" update-index --add --cacheinfo 160000,"$FAKE_SUBMODULE_SHA",sub
git -C "$GITLINK_REPO" -c user.email="$GIT_ID_EMAIL" -c user.name="$GIT_ID_NAME" \
  commit -q -m "fixture: add gitlink sub"

run_checker "$GITLINK_REPO" "$GITLINK_BASE"
if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF 'check-pii-shapes: skip: gitlink' \
   && printf '%s\n' "$OUT" | grep -qE 'gitlink.*: sub$'; then
  pass "gitlink: diff-scoped mode skips a gitlink, announces it, and exits 0 clean (not a raw 128)"
else
  fail "gitlink: diff-scoped mode (round 3 regression lock) (rc=$RC out=$OUT)"
fi

set +e
GITLINK_ALL_OUT="$(cd "$GITLINK_REPO" && bash "$BIN" --all 2>&1)"
GITLINK_ALL_RC=$?
set -e
if [ "$GITLINK_ALL_RC" -eq 0 ] && printf '%s\n' "$GITLINK_ALL_OUT" | grep -qF 'check-pii-shapes: skip: gitlink' \
   && printf '%s\n' "$GITLINK_ALL_OUT" | grep -qE 'gitlink.*: sub$'; then
  pass "gitlink: --all mode skips a gitlink, announces it, and exits 0 clean (not a raw cp failure)"
else
  fail "gitlink: --all mode (round 3 regression lock) (rc=$GITLINK_ALL_RC out=$GITLINK_ALL_OUT)"
fi

# =============================================================================
# temp hygiene: every throwaway repo is created inside the trap-cleaned
# work dir (AC12)
# =============================================================================
printf '\n--- temp hygiene: every throwaway repo is created inside the trap-cleaned work dir ---\n'

stray_repos=0
total_repos=0
while IFS= read -r _created; do
  [ -n "$_created" ] || continue
  total_repos=$((total_repos + 1))
  case "$_created" in
    "$WORK"/*) ;;
    *) stray_repos=$((stray_repos + 1)) ;;
  esac
done < "$CREATED_REPOS_LOG"
if [ "$total_repos" -gt 0 ] && [ "$stray_repos" -eq 0 ]; then
  pass "temp hygiene: every throwaway repo is created inside the trap-cleaned work dir ($total_repos repos, all under \$WORK)"
else
  fail "temp hygiene: every throwaway repo is created inside the trap-cleaned work dir ($stray_repos of $total_repos repo(s) found outside \$WORK)"
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
