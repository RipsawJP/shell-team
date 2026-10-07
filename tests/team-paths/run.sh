#!/usr/bin/env bash
# run.sh — drive bin/team-paths.sh and assert the resolver's precedence chain
# (T-025):
#   - default mode      : empty root -> base=.shell-team, specs=.shell-team/specs
#   - legacy mode       : root with tasks/loops/shell-team.contract.yaml -> base=tasks; specs per a
#                         closed five-row table (T-1176): tasks/specs when that directory exists
#                         and docs/specs is absent or holds only .gitkeep, else docs/specs
#   - explicit override : $TEAM_RUN_BASE wins even when a legacy layout exists
#   - --export is eval-safe, including roots / bases containing a space
#   - bad usage exits 2 (no mode, unknown --get key, unknown flag)
#
# Avoids mktemp (writes under ${TMPDIR:-/tmp}/tmp-roots, left under TMPDIR) so the suite
# runs in restricted sandboxes — mirrors tests/team-init/run.sh.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PATHS="$REPO_ROOT/bin/team-paths.sh"
if [ -n "${TMPDIR:-}" ]; then
  TMP="$(mktemp -d "${TMPDIR%/}/team-paths-test-roots.XXXXXX")"
else
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/tmp-roots.XXXXXX")"
fi

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }


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
# split-root lock (row R1, neither specs directory exists): specs stay at docs/specs.
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

# --- legacy specs table, rows R1-R5 (T-1176) ---------------------------------
# Each fixture root carries the legacy marker. The answer is a function of two
# directory tests and one listing of docs/specs. Every row asserts: exit 0, the
# exact answer from --get, an empty stderr, --export with only TEAM_SPECS_DIR
# varying, --print's specs row, and a rule: text that begins "legacy".
lg() { mkdir -p "$TMP/$1/tasks/loops" && : > "$TMP/$1/tasks/loops/shell-team.contract.yaml"; }
lg lr1
lg lr2; mkdir -p "$TMP/lr2/docs/specs"; : > "$TMP/lr2/docs/specs/.gitkeep"
lg lr3; mkdir -p "$TMP/lr3/tasks/specs"
lg lr4; mkdir -p "$TMP/lr4/tasks/specs" "$TMP/lr4/docs/specs"; printf 's\n' > "$TMP/lr4/tasks/specs/T-1-a.md"; : > "$TMP/lr4/docs/specs/.gitkeep"
lg lr4e; mkdir -p "$TMP/lr4e/tasks/specs" "$TMP/lr4e/docs/specs"
lg lr5; mkdir -p "$TMP/lr5/tasks/specs" "$TMP/lr5/docs/specs"; : > "$TMP/lr5/docs/specs/.gitkeep"; printf 's\n' > "$TMP/lr5/docs/specs/T-1-a.md"
lg lr5h; mkdir -p "$TMP/lr5h/tasks/specs" "$TMP/lr5h/docs/specs"; : > "$TMP/lr5h/docs/specs/.keep"
lg lr5d; mkdir -p "$TMP/lr5d/tasks/specs" "$TMP/lr5d/docs/specs/sub"
lg lr7; : > "$TMP/lr7/tasks/specs"
rows="lr1:docs/specs lr2:docs/specs lr3:tasks/specs lr4:tasks/specs lr4e:tasks/specs lr5:docs/specs lr5h:docs/specs lr5d:docs/specs lr7:docs/specs"
# unreadable docs/specs listing counts as holding an entry (R5); a root user can
# read it regardless, so that row is skipped there rather than asserted falsely.
if [ "$(id -u)" != 0 ]; then
  lg lr6; mkdir -p "$TMP/lr6/tasks/specs" "$TMP/lr6/docs/specs"; : > "$TMP/lr6/docs/specs/.gitkeep"
  chmod 000 "$TMP/lr6/docs/specs"
  rows="$rows lr6:docs/specs"
fi
for c in $rows; do
  n="${c%%:*}"; want="${c#*:}"
  got="$(env -u TEAM_RUN_BASE bash "$PATHS" --root "$TMP/$n" --get specs 2> "$TMP/stderr-$n")" \
    || { chmod 755 "$TMP/lr6/docs/specs" 2>/dev/null || true; fail "legacy table: $n --get specs exited non-zero"; }
  [ "$got" = "$want" ] || { chmod 755 "$TMP/lr6/docs/specs" 2>/dev/null || true; fail "legacy table: $n --get specs answered '$got', want '$want'"; }
  [ ! -s "$TMP/stderr-$n" ] || { chmod 755 "$TMP/lr6/docs/specs" 2>/dev/null || true; fail "legacy table: $n wrote to stderr"; }
  env -u TEAM_RUN_BASE bash "$PATHS" --root "$TMP/$n" --export > "$TMP/export-$n" 2> "$TMP/stderr-$n" \
    || fail "legacy table: $n --export exited non-zero"
  [ ! -s "$TMP/stderr-$n" ] || fail "legacy table: $n --export wrote to stderr"
  printf 'export TEAM_RUN_BASE=tasks\nexport TEAM_TODO=tasks/todo.md\nexport TEAM_LOOPS_DIR=tasks/loops\nexport TEAM_RUNS_DIR=tasks/runs\nexport TEAM_RETROS_DIR=tasks/retros\nexport TEAM_REVIEWS_DIR=tasks/reviews\nexport TEAM_SPECS_DIR=%s\nexport TEAM_PROVENANCE_DIR=tasks/provenance\nexport TEAM_INTERVENTIONS_DIR=tasks/interventions\nexport TEAM_LESSONS=tasks/lessons.md\n' "$want" > "$TMP/export-want-$n"
  cmp -s "$TMP/export-$n" "$TMP/export-want-$n" || fail "legacy table: $n --export differs from the ten legacy lines with TEAM_SPECS_DIR=$want"
  env -u TEAM_RUN_BASE bash "$PATHS" --root "$TMP/$n" --print > "$TMP/print-$n" 2> "$TMP/stderr-$n" \
    || fail "legacy table: $n --print exited non-zero"
  [ ! -s "$TMP/stderr-$n" ] || fail "legacy table: $n --print wrote to stderr"
  [ "$(awk '$1=="specs"{print $2}' "$TMP/print-$n")" = "$want" ] || fail "legacy table: $n --print specs row is not $want"
  sed -n '1s/^shell-team paths (rule: \(.*\), root: .*$/\1/p' "$TMP/print-$n" > "$TMP/rule-$n"
  grep -q '^legacy' "$TMP/rule-$n" || fail "legacy table: $n rule: text does not begin 'legacy'"
done
[ ! -e "$TMP/lr6/docs/specs" ] || chmod 755 "$TMP/lr6/docs/specs" 2>/dev/null || true
distinct="$(cat "$TMP/rule-lr1" "$TMP/rule-lr2" "$TMP/rule-lr3" "$TMP/rule-lr4" "$TMP/rule-lr5" | sort -u | grep -c .)"
[ "$distinct" -eq 5 ] || fail "legacy table: rows R1-R5 must carry five distinct rule: texts, got $distinct"
pass "legacy specs table: R1/R2/R5(+hidden file, subdirectory, unreadable)/regular-file -> docs/specs; R3/R4(+empty docs/specs) -> tasks/specs; stderr empty; five distinct rule texts"

# A root holding both directories but no legacy marker stays default; the env
# override still wins over the table.
mkdir -p "$TMP/nomarker/tasks/specs" "$TMP/nomarker/docs/specs"
[ "$(get "$TMP/nomarker" specs)" = ".shell-team/specs" ] || fail "no marker: specs must stay under the default base"
[ "$(get "$TMP/lr3" specs TEAM_RUN_BASE=.ops)" = ".ops/specs" ] || fail "env override must win over the legacy table"
env TEAM_RUN_BASE=.ops bash "$PATHS" --root "$TMP/lr3" --print > "$TMP/print-env"
sed -n '1s/^shell-team paths (rule: \(.*\), root: .*$/\1/p' "$TMP/print-env" > "$TMP/rule-env"
[ "$(cat "$TMP/rule-env")" = "env (TEAM_RUN_BASE)" ] || fail "env override: --print rule changed"
sed -n '1s/^shell-team paths (rule: \(.*\), root: .*$/\1/p' <<< "$print_default" > "$TMP/rule-def"
[ "$(cat "$TMP/rule-def")" = "default" ] || fail "default: --print rule changed"
pass "default and env branches unchanged by the legacy table"

# --help describes the rule and no longer calls docs/specs the one path outside the base.
help_out="$(bash "$PATHS" --help)"
for w in tasks/specs docs/specs .gitkeep; do
  grep -qF -- "$w" <<< "$help_out" || fail "--help must name $w"
done
pass "--help names tasks/specs, docs/specs and .gitkeep"

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
