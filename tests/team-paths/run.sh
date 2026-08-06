#!/usr/bin/env bash
# run.sh — drive bin/team-paths.sh and assert the resolver's precedence chain
# (T-025):
#   - default mode      : empty root -> base=.shell-team, specs=.shell-team/specs
#   - legacy mode       : root with tasks/loops/shell-team.contract.yaml -> base=tasks, specs=docs/specs
#                         (split-root lock: specs MUST stay at docs/specs)
#   - explicit override : $TEAM_RUN_BASE wins even when a legacy layout exists
#   - --export is eval-safe, including roots / bases containing a space
#   - bad usage exits 2 (no mode, unknown --get key, unknown flag)
#
# Avoids mktemp (writes under $HERE/tmp-roots, cleaned via trap) so the suite
# runs in restricted sandboxes — mirrors tests/team-init/run.sh.
#
# The ignored-base notice cases (T-1042) below are the one exception: each
# needs a REAL `git init`-ed work tree (D12), and sandboxed runs deny writes
# to a nested .git/ inside this repo's own tree — the same constraint
# tests/retro-inputs/run.sh's header already documents and works around.
# Those fixtures therefore live under $TMPDIR (falling back to $HERE/git-tmp
# on plain CI runners) instead of $TMP, with their own trap.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PATHS="$REPO_ROOT/bin/team-paths.sh"
TMP="$HERE/tmp-roots"

if [ -n "${TMPDIR:-}" ]; then
  GTMP="${TMPDIR%/}/team-paths-ignore-fixtures"
else
  GTMP="$HERE/git-tmp"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

rm -rf "$TMP" "$GTMP"
trap 'rm -rf "$TMP" "$GTMP"' EXIT
mkdir -p "$TMP" "$GTMP"

# get <root> <key> [env-assignment...] -> prints the resolved path
get() {
  local root="$1" key="$2"; shift 2
  env -u TEAM_RUN_BASE "$@" bash "$PATHS" --root "$root" --get "$key"
}

# --- default mode: a fresh/empty root ---------------------------------------
D="$TMP/fresh"
mkdir -p "$D"
[ "$(get "$D" base)"    = ".shell-team" ]          || fail "default: base should be .shell-team"
[ "$(get "$D" todo)"    = ".shell-team/todo.md" ]  || fail "default: todo path wrong"
[ "$(get "$D" loops)"   = ".shell-team/loops" ]    || fail "default: loops path wrong"
[ "$(get "$D" runs)"    = ".shell-team/runs" ]     || fail "default: runs path wrong"
[ "$(get "$D" retros)"  = ".shell-team/retros" ]   || fail "default: retros path wrong"
[ "$(get "$D" reviews)" = ".shell-team/reviews" ]  || fail "default: reviews path wrong"
[ "$(get "$D" specs)"   = ".shell-team/specs" ]    || fail "default: specs path wrong"
[ "$(get "$D" provenance)" = ".shell-team/provenance" ] || fail "default: provenance path wrong"
[ "$(get "$D" interventions)" = ".shell-team/interventions" ] || fail "default: interventions path wrong"
[ "$(get "$D" lessons)" = ".shell-team/lessons.md" ] || fail "default: lessons path wrong"
pass "default mode resolves all paths under .shell-team/"

# --- legacy mode: the plugin-unique contract file is the marker -------------
L="$TMP/legacy"
mkdir -p "$L/tasks/loops"
: > "$L/tasks/loops/shell-team.contract.yaml"
[ "$(get "$L" base)"  = "tasks" ]          || fail "legacy: base should be tasks"
[ "$(get "$L" todo)"  = "tasks/todo.md" ]  || fail "legacy: todo path wrong"
[ "$(get "$L" runs)"  = "tasks/runs" ]     || fail "legacy: runs path wrong"
# split-root lock: specs MUST remain at docs/specs in legacy mode.
[ "$(get "$L" specs)" = "docs/specs" ]     || fail "legacy: split-root broken — specs must be docs/specs"
[ "$(get "$L" provenance)" = "tasks/provenance" ] || fail "legacy: provenance path wrong"
[ "$(get "$L" interventions)" = "tasks/interventions" ] || fail "legacy: interventions path wrong"
[ "$(get "$L" lessons)" = "tasks/lessons.md" ] || fail "legacy: lessons path wrong"
pass "legacy mode resolves tasks/ base with split-root specs=docs/specs"

# --- a bare tasks/todo.md (no contract) is NOT misdetected as legacy --------
B="$TMP/bare-tasks"
mkdir -p "$B/tasks"
: > "$B/tasks/todo.md"
[ "$(get "$B" base)" = ".shell-team" ] \
  || fail "false-positive: a bare tasks/todo.md must not trigger legacy mode"
pass "bare tasks/todo.md (no contract) stays in default mode"

# --- a tasks/loops/ dir WITHOUT the contract file is NOT legacy -------------
# Guards the stronger marker: an unrelated host repo that keeps a tasks/loops/
# directory for its own purposes must not be misdetected as a shell-team install.
LN="$TMP/loops-no-contract"
mkdir -p "$LN/tasks/loops"
[ "$(get "$LN" base)" = ".shell-team" ] \
  || fail "false-positive: tasks/loops/ without shell-team.contract.yaml must not trigger legacy mode"
pass "tasks/loops/ without shell-team.contract.yaml stays in default mode"

# --- explicit override wins even over a legacy layout -----------------------
[ "$(TEAM_RUN_BASE=.ops bash "$PATHS" --root "$L" --get base)"  = ".ops" ] \
  || fail "override: TEAM_RUN_BASE should win over legacy"
[ "$(TEAM_RUN_BASE=.ops bash "$PATHS" --root "$L" --get specs)" = ".ops/specs" ] \
  || fail "override: specs should be <base>/specs under explicit override"
[ "$(TEAM_RUN_BASE=.ops bash "$PATHS" --root "$L" --get lessons)" = ".ops/lessons.md" ] \
  || fail "override: lessons should be <base>/lessons.md under explicit override"
pass "explicit TEAM_RUN_BASE overrides legacy detection"

# --- --export is eval-safe and yields the resolved vars ---------------------
(
  eval "$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$D" --export)"
  [ "$TEAM_RUN_BASE" = ".shell-team" ]         || exit 11
  [ "$TEAM_TODO"     = ".shell-team/todo.md" ] || exit 12
  [ "$TEAM_SPECS_DIR" = ".shell-team/specs" ]  || exit 13
) || fail "--export did not eval to the expected vars (code $?)"
pass "--export evaluates to the resolved TEAM_* vars"

# --- a root path containing a space resolves cleanly (default layout) --------
# The base is whitespace-free (default .shell-team), so the spaced root never
# leaks into an emitted path; --export must still eval cleanly.
S="$TMP/with space"
mkdir -p "$S"
(
  eval "$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$S" --export)"
  [ "$TEAM_RUN_BASE" = ".shell-team" ]         || exit 21
  [ "$TEAM_TODO"     = ".shell-team/todo.md" ] || exit 22
) || fail "--export not eval-safe / wrong when the root path contains a space (code $?)"
pass "--export resolves cleanly when the repo root path contains a space"

# --- eval-safety with shell metacharacters in TEAM_RUN_BASE -----------------
# printf %q must neutralize these so a malicious-looking base cannot inject
# commands when the resolver output is eval'd. Each value is a legal (if odd)
# relative dir name — none contains a `..` or a leading `/`, so validation
# allows them; eval-safety is what's under test.
# shellcheck disable=SC2016  # single quotes are intentional — these are literal metachars under test, not expansions
# Whitespace-free on purpose: a base with whitespace is rejected upstream by
# validate_base, so eval-safety only needs to cover the non-space metachars that
# a base could actually contain.
for meta in 'a;b' 'a$(id)b' "a'b" 'a&b' 'a`id`b' 'a|b'; do
  out="$(TEAM_RUN_BASE="$meta" bash "$PATHS" --root "$D" --export)"
  (
    eval "$out"
    [ "$TEAM_RUN_BASE" = "$meta" ] || exit 31
    [ "$TEAM_TODO" = "$meta/todo.md" ] || exit 32
  ) || { printf 'FAIL: --export not eval-safe for TEAM_RUN_BASE=%q (code %s)\n' "$meta" "$?" >&2; exit 1; }
done
pass "--export is eval-safe with shell metacharacters in TEAM_RUN_BASE (no injection)"

# --- invalid TEAM_RUN_BASE values are rejected (host-root-escape guard) ------
set +e
# shellcheck disable=SC2088  # the literal ~/x is intentional — it must be rejected, not expanded
for bad in "." ".." "./." "./" ".//" "a//b" "a/./b" "/abs/path" "a/../b" "../escape" "~/x" "my ops"; do
  TEAM_RUN_BASE="$bad" bash "$PATHS" --root "$D" --get base >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] || { printf 'FAIL: invalid TEAM_RUN_BASE %q should exit 2, got %s\n' "$bad" "$rc" >&2; exit 1; }
done
set -e
pass "invalid TEAM_RUN_BASE (. / .. / absolute / ..-component / ~ / whitespace) is rejected with exit 2"

# --- --print reports the rule that fired ------------------------------------
# Capture the full output before grepping: `grep -q` would close the pipe on
# first match and SIGPIPE team-paths' remaining writes, which pipefail+set -e
# would then treat as a failure.
print_legacy="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$L" --print)"
grep -q "rule: legacy" <<< "$print_legacy" \
  || fail "--print should report the legacy rule for a legacy root"
print_default="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$D" --print)"
grep -q "rule: default" <<< "$print_default" \
  || fail "--print should report the default rule for a fresh root"
pass "--print reports which precedence rule fired"

# --- total-key set is exactly ten, in both directions (T-1002 AC15, T-1006 --
# AC2 raises it from nine) -- A tenth key added without updating this list
# fails it; a key silently dropped from --export/--print (which count
# independently) fails it too.
for k in base todo loops runs retros reviews specs provenance interventions lessons; do
  bash "$PATHS" --root "$D" --get "$k" >/dev/null \
    || fail "total-key set is exactly ten: key '$k' should resolve"
done
set +e
bash "$PATHS" --root "$D" --get not-a-key >/dev/null 2>&1
rc_unlisted=$?
set -e
[ "$rc_unlisted" -eq 2 ] || fail "total-key set is exactly ten: an unlisted key should exit 2, got $rc_unlisted"
export_count="$(bash "$PATHS" --root "$D" --export | grep -c -- '^export TEAM_')"
[ "$export_count" -eq 10 ] || fail "total-key set is exactly ten: --export should print exactly 10 lines, got $export_count"
print_count="$(bash "$PATHS" --root "$D" --print | grep -cE -- '^[[:space:]]+[a-z]+[[:space:]]+[^[:space:]]+$')"
[ "$print_count" -eq 10 ] || fail "total-key set is exactly ten: --print should show exactly 10 rows, got $print_count"
pass "total-key set is exactly ten: every key resolves, an unlisted key (not-a-key) exits 2, --export/--print each carry exactly ten entries, ending interventions lessons"

# --- ignored-base notice (T-1042) -------------------------------------------
# `git check-ignore` consults the operator's global core.excludesFile, so
# every fixture below pins that input explicitly (D12) rather than
# inheriting it, AND is its own independently `git init`-ed work tree —
# a fixture built as a plain subdirectory under this repo's own tree would
# have `git check-ignore` answer from THIS repository's own rules (including
# its `!.shell-team/` re-include), and every ignored-base case would
# silently invert. Pinning is done by setting the fixture repo's OWN
# core.excludesFile config (persists across every subsequent git invocation
# against that repo, including the ones team-paths.sh itself makes), rather
# than a transient `-c` flag on a single command.
IGN_NOTICE_BODY='is matched by a git ignore rule and holds no tracked file'
IGN_OUTSIDE_BODY='is not inside a git work tree'
IGN_UNDETERMINABLE_BODY='could not be determined (git did not answer)'

# LA1: fires on stderr for a base dir a repo-level ignore rule matches.
IGN1="$GTMP/ignored-base-repo"
mkdir -p "$IGN1/.shell-team"
git -C "$IGN1" init -q
git -C "$IGN1" config core.excludesFile /dev/null
printf '.shell-team/\n' > "$IGN1/.gitignore"
ign1_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign1_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: fires on stderr for a base dir a repo-level ignore rule matches"
pass "ignored-base notice: fires on stderr for a base dir a repo-level ignore rule matches"

# Codex round-1 M1 (non-frozen regression lock): a pathspec-metacharacter
# base name must not defeat either git predicate. `validate_base` permits
# glob-shaped names like `a*` (safe for shell word-splitting, not for a git
# pathspec) -- this repo's real target is a literal two-character directory
# NAMED `a*` (built with `mkdir --`, not a glob), ignored via an escaped
# `.gitignore` rule; an UNRELATED tracked file under a directory whose name
# also glob-matches the pattern `a*` (here: `abc/file.txt`) is the exact
# confounder the reviewer's live repro used to defeat the un-fixed
# `ls-files -- "$base"` (false silence) and `check-ignore -q -- "$base"`
# (false "not ignored") calls.
IGNM1="$GTMP/glob-base-repo"
mkdir -p "$IGNM1"
git -C "$IGNM1" init -q
git -C "$IGNM1" config core.excludesFile /dev/null
mkdir -- "$IGNM1/a*"
printf 'x' > "$IGNM1/a*/untracked.txt"
mkdir -p "$IGNM1/abc"
printf 'x' > "$IGNM1/abc/file.txt"
git -C "$IGNM1" add abc/file.txt
printf 'a\\*/\n' > "$IGNM1/.gitignore"
ignm1_err="$(env TEAM_RUN_BASE='a*' bash "$PATHS" --root "$IGNM1" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ignm1_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: a pathspec-metacharacter base name does not defeat the tracked-file or ignore predicates"
pass "ignored-base notice: a pathspec-metacharacter base name does not defeat the tracked-file or ignore predicates"

# LA2: silent for a base dir no ignore rule matches.
IGN2="$GTMP/not-ignored-repo"
mkdir -p "$IGN2/.shell-team"
git -C "$IGN2" init -q
git -C "$IGN2" config core.excludesFile /dev/null
ign2_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN2" --print 2>&1 1>/dev/null)"
[ -z "$ign2_err" ] || fail "ignored-base notice: silent for a base dir no ignore rule matches (got: $ign2_err)"
pass "ignored-base notice: silent for a base dir no ignore rule matches"

# LA3: silent when the base dir already holds a tracked file -- the ignore
# rule matches, but D6 treats a tracked file under the base dir as the
# adopter having decided to track it, so the notice would be a false
# positive. No commit needed: a file is tracked as soon as it is `git add`-ed.
IGN3="$GTMP/tracked-base-repo"
mkdir -p "$IGN3/.shell-team"
git -C "$IGN3" init -q
git -C "$IGN3" config core.excludesFile /dev/null
printf '.shell-team/\n' > "$IGN3/.gitignore"
printf 'x' > "$IGN3/.shell-team/todo.md"
git -C "$IGN3" add -f .shell-team/todo.md
ign3_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN3" --print 2>&1 1>/dev/null)"
[ -z "$ign3_err" ] || fail "ignored-base notice: silent when the base dir already holds a tracked file (got: $ign3_err)"
pass "ignored-base notice: silent when the base dir already holds a tracked file"

# LA4: fires for the bare and the trailing-slash ignore-rule forms alike --
# docs/adopting.md recommends the directory form, so both must fire.
IGN4_BARE="$GTMP/ignore-bare-form"
mkdir -p "$IGN4_BARE/.shell-team"
git -C "$IGN4_BARE" init -q
git -C "$IGN4_BARE" config core.excludesFile /dev/null
printf '.shell-team\n' > "$IGN4_BARE/.gitignore"
ign4_bare_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN4_BARE" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign4_bare_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike (bare form)"

IGN4_DIR="$GTMP/ignore-dir-form"
mkdir -p "$IGN4_DIR/.shell-team"
git -C "$IGN4_DIR" init -q
git -C "$IGN4_DIR" config core.excludesFile /dev/null
printf '.shell-team/\n' > "$IGN4_DIR/.gitignore"
ign4_dir_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN4_DIR" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign4_dir_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike (directory form)"

# Codex round-1 M3: the directory-form rule must still fire when the base
# dir does not exist on disk yet -- `--print` has no scaffolding step (D9's
# after-scaffolding ordering only protects team-init.sh), so an operator
# inspecting a fresh clone can genuinely invoke --print before the base dir
# is ever created. Deliberately NO `mkdir -p ".../.shell-team"` here, unlike
# every other case in this suite.
IGN4_DIR_ABSENT="$GTMP/ignore-dir-form-absent"
mkdir -p "$IGN4_DIR_ABSENT"
git -C "$IGN4_DIR_ABSENT" init -q
git -C "$IGN4_DIR_ABSENT" config core.excludesFile /dev/null
printf '.shell-team/\n' > "$IGN4_DIR_ABSENT/.gitignore"
[ ! -e "$IGN4_DIR_ABSENT/.shell-team" ] \
  || fail "ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike (absent-dir fixture is invalid: .shell-team already exists)"
ign4_dir_absent_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN4_DIR_ABSENT" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign4_dir_absent_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike (directory form, base dir absent on disk)"
pass "ignored-base notice: fires for the bare and the trailing-slash ignore-rule forms alike"

# LA5: fires when only a global excludes file ignores the base dir -- proves
# the production probe really does honour the operator's global excludes
# (AC12), not only the repo's own .gitignore. A HOSTILE excludes file (one
# that ignores the base dir) is pinned as this fixture's own
# core.excludesFile, standing in for the operator's real global file.
printf '.shell-team/\n' > "$GTMP/hostile-excludes"
IGN5="$GTMP/global-only-ignore"
mkdir -p "$IGN5/.shell-team"
git -C "$IGN5" init -q
git -C "$IGN5" config core.excludesFile "$GTMP/hostile-excludes"
ign5_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN5" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign5_err" | grep -qF -- "$IGN_NOTICE_BODY" \
  || fail "ignored-base notice: fires when only a global excludes file ignores the base dir"
pass "ignored-base notice: fires when only a global excludes file ignores the base dir"

# LA6: reports an undeterminable ignore status outside a git work tree. Must
# be built OUTSIDE this repository's own tree (a plain subdirectory under
# $TMP would still be inside THIS repo's work tree, walking up to its .git),
# so this one fixture uses a guarded mktemp under $TMPDIR instead.
IGN6="$(mktemp -d "${TMPDIR:-/tmp}/team-paths-outside-worktree.XXXXXX")"
mkdir -p "$IGN6/.shell-team"
ign6_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN6" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign6_err" | grep -qF -- "$IGN_OUTSIDE_BODY" \
  || fail "ignored-base notice: reports an undeterminable ignore status outside a git work tree"
pass "ignored-base notice: reports an undeterminable ignore status outside a git work tree"
rm -rf "$IGN6"

# LA7: reports an undeterminable ignore status when git is unavailable -- a
# PATH holding only a bash symlink (no git at all); the resolved base dir's
# own ignore state is irrelevant here since the probe must fall to
# undeterminable before it ever asks git to check-ignore anything.
NOGIT_BIN="$TMP/nogit-bin"
mkdir -p "$NOGIT_BIN"
ln -sf "$(command -v bash)" "$NOGIT_BIN/bash"
IGN7="$TMP/git-unavailable-target"
mkdir -p "$IGN7/.shell-team"
ign7_err="$(env -u TEAM_RUN_BASE PATH="$NOGIT_BIN" bash "$PATHS" --root "$IGN7" --print 2>&1 1>/dev/null)"
printf '%s\n' "$ign7_err" | grep -qF -- "$IGN_UNDETERMINABLE_BODY" \
  || fail "ignored-base notice: reports an undeterminable ignore status when git is unavailable"
pass "ignored-base notice: reports an undeterminable ignore status when git is unavailable"

# LA8: --export, --get and --print stdout stay byte-identical and exit 0
# while the notice fires. Reuses IGN1 (already proven ignored above).
set +e
ign8_get_out="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --get base 2>/dev/null)"; ign8_rc_get=$?
ign8_export_out="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --export 2>/dev/null)"; ign8_rc_export=$?
ign8_print_out="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --print 2>/dev/null)"; ign8_rc_print=$?
set -e
ign8_get_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --get base 2>&1 1>/dev/null)"
ign8_export_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --export 2>&1 1>/dev/null)"
ign8_print_err="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$IGN1" --print 2>&1 1>/dev/null)"
[ "$ign8_rc_get" -eq 0 ] && [ "$ign8_rc_export" -eq 0 ] && [ "$ign8_rc_print" -eq 0 ] \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (nonzero exit while notice fires)"
[ "$ign8_get_out" = ".shell-team" ] \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (--get stdout perturbed)"
[ -z "$ign8_get_err" ] \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (--get warned)"
printf '%s\n' "$ign8_export_out" | grep -qxF -- 'export TEAM_RUN_BASE=.shell-team' \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (--export stdout perturbed)"
[ -z "$ign8_export_err" ] \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (--export warned)"
printf '%s\n' "$ign8_print_out" | grep -qF -- 'base          .shell-team' \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (--print stdout perturbed)"
[ -n "$ign8_print_err" ] \
  || fail "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0 (fixture never actually fired the notice -- vacuous test)"
pass "ignored-base notice: --export, --get and --print stdout stay byte-identical and exit 0"

# --- bad usage exits 2 ------------------------------------------------------
set +e
bash "$PATHS" --root "$D" >/dev/null 2>&1;            rc_nomode=$?
bash "$PATHS" --root "$D" --get bogus >/dev/null 2>&1; rc_badkey=$?
bash "$PATHS" --frobnicate >/dev/null 2>&1;            rc_badflag=$?
bash "$PATHS" --root "$TMP/nope" --get base >/dev/null 2>&1; rc_badroot=$?
bash "$PATHS" --root "$D" --export --get specs >/dev/null 2>&1; rc_twomode=$?
set -e
[ "$rc_nomode"  -eq 2 ] || fail "no mode should exit 2, got $rc_nomode"
[ "$rc_badkey"  -eq 2 ] || fail "unknown --get key should exit 2, got $rc_badkey"
[ "$rc_badflag" -eq 2 ] || fail "unknown flag should exit 2, got $rc_badflag"
[ "$rc_badroot" -eq 2 ] || fail "nonexistent root should exit 2, got $rc_badroot"
[ "$rc_twomode" -eq 2 ] || fail "two modes (--export --get) should exit 2, got $rc_twomode"
pass "bad usage (no mode / bad key / bad flag / bad root / two modes) exits 2"

printf '\nAll team-paths assertions passed.\n'
