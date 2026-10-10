#!/usr/bin/env bash
# run.sh — fixture suite for bin/team-mode.sh and the local-mode branches of
# bin/check-durability.sh and bin/team-commit.sh (T-1180, issue #711).
#
# Every case builds a throwaway git repository under a scratch root in
# ${TMPDIR:-/tmp} (never inside this checkout) with the workstation isolated:
# HOME inside the scratch root, GIT_CONFIG_GLOBAL=/dev/null, GIT_CONFIG_NOSYSTEM=1,
# GIT_CEILING_DIRECTORIES at the root, and TEAM_RUN_BASE and the git-redirecting
# variables unset. shell-team.mode is set only in the fixtures' own repositories.
# Nothing is ever deleted: scratch directories stay under the root.
#
# One `PASS: <id> ...` line per case; a failed case prints `FAIL: ...` on stderr
# and the suite exits 1.

set -euo pipefail

export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd -P)"
MODE_SH="$REPO_ROOT/bin/team-mode.sh"
DUR_SH="$REPO_ROOT/bin/check-durability.sh"
COMMIT_SH="$REPO_ROOT/bin/team-commit.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

for f in "$MODE_SH" "$DUR_SH" "$COMMIT_SH"; do
  [ -s "$f" ] || { printf 'FAIL: %s missing\n' "$f" >&2; exit 1; }
done

T="$(mktemp -d "${TMPDIR:-/tmp}/team-mode-suite.XXXXXX")" || exit 1
T="$(cd "$T" && pwd -P)" || exit 1
export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$T"
unset TEAM_RUN_BASE GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
mkdir -p "$HOME" "$T/tpl"

RC=0
OUT=""
ERR=""
# run_in <dir> <cmd...>: run with stdout/stderr captured, rc in RC.
run_in() {
  local d="$1"
  shift
  RC=0
  ( cd "$d" && "$@" ) > "$T/out" 2> "$T/err" < /dev/null || RC=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}

n=0
new_repo() {  # new_repo <name>: a committed repository with a base dir
  n=$((n + 1))
  R="$T/r$n-$1"
  mkdir -p "$R/.shell-team/specs" "$R/.shell-team/provenance" "$R/.shell-team/interventions"
  git -C "$R" init -q --template="$T/tpl"
  git -C "$R" symbolic-ref HEAD refs/heads/main
  git -C "$R" config user.email t@example.invalid
  git -C "$R" config user.name t
  git -C "$R" config core.excludesFile /dev/null
  local x
  for x in todo.md specs/T-900-demo.md provenance/T-900.md interventions/T-900.md; do
    printf 'x\n' > "$R/.shell-team/$x"
  done
  printf 'x\n' > "$R/README"
  git -C "$R" add -A
  git -C "$R" commit -q -m base
}

# --- team-mode.sh: the resolver contract --------------------------------------
new_repo resolver
mkdir -p "$R/sub"
run_in "$R" bash "$MODE_SH"
if [ "$RC" -eq 0 ] && [ "$OUT" = "tracked" ] && [ -z "$ERR" ]; then pass "mode-absent key absent prints tracked, exit 0, empty stderr"; else fail "mode-absent: rc=$RC out=$OUT err=$ERR"; fi

for v in tracked Local LOCAL locally 'local ' ''; do
  git -C "$R" config shell-team.mode "$v"
  run_in "$R" bash "$MODE_SH"
  if [ "$RC" -eq 0 ] && [ "$OUT" = "tracked" ] && [ -z "$ERR" ]; then pass "mode-value-tracked [$v] is not the exact value local, so tracked"; else fail "mode-value [$v]: rc=$RC out=$OUT err=$ERR"; fi
done

git -C "$R" config shell-team.mode local
run_in "$R" bash "$MODE_SH"
if [ "$RC" -eq 0 ] && [ "$OUT" = "local" ] && [ -z "$ERR" ]; then pass "mode-local exact value local prints local"; else fail "mode-local: rc=$RC out=$OUT err=$ERR"; fi
run_in "$R/sub" bash "$MODE_SH"
if [ "$RC" -eq 0 ] && [ "$OUT" = "local" ]; then pass "mode-subdir run from a subdirectory reads the same clone"; else fail "mode-subdir: rc=$RC out=$OUT err=$ERR"; fi

# Other scopes never select local: each variant is first shown visible to an
# all-scopes read (positive control), then the resolver must still say tracked.
git -C "$R" config --unset-all shell-team.mode
printf '[shell-team]\n\tmode = local\n' > "$T/g.conf"
seen="$(cd "$R" && GIT_CONFIG_GLOBAL="$T/g.conf" git config --get shell-team.mode || true)"
run_in "$R" env GIT_CONFIG_GLOBAL="$T/g.conf" bash "$MODE_SH"
if [ "$seen" = local ] && [ "$RC" -eq 0 ] && [ "$OUT" = "tracked" ]; then pass "mode-global-scope a global value is visible to git yet stays tracked"; else fail "mode-global: seen=$seen rc=$RC out=$OUT"; fi
seen="$(cd "$R" && env "GIT_CONFIG_PARAMETERS='shell-team.mode=local'" git config --get shell-team.mode || true)"
run_in "$R" env "GIT_CONFIG_PARAMETERS='shell-team.mode=local'" bash "$MODE_SH"
if [ "$seen" = local ] && [ "$RC" -eq 0 ] && [ "$OUT" = "tracked" ]; then pass "mode-config-parameters injected value is visible to git yet stays tracked"; else fail "mode-config-parameters: seen=$seen rc=$RC out=$OUT"; fi
seen="$(cd "$R" && env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=shell-team.mode GIT_CONFIG_VALUE_0=local git config --get shell-team.mode || true)"
run_in "$R" env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=shell-team.mode GIT_CONFIG_VALUE_0=local bash "$MODE_SH"
if [ "$seen" = local ] && [ "$RC" -eq 0 ] && [ "$OUT" = "tracked" ]; then pass "mode-config-count injected value is visible to git yet stays tracked"; else fail "mode-config-count: seen=$seen rc=$RC out=$OUT"; fi

# Unreadable declaration fails closed.
mkdir -p "$T/nogit"
run_in "$T/nogit" bash "$MODE_SH"
if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then pass "mode-no-repo outside any repository exits 2 with empty stdout"; else fail "mode-no-repo: rc=$RC out=$OUT err=$ERR"; fi
new_repo malformed
printf '[[[\n' >> "$R/.git/config"
run_in "$R" bash "$MODE_SH"
if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then pass "mode-malformed a malformed repository file exits 2 with empty stdout"; else fail "mode-malformed: rc=$RC out=$OUT err=$ERR"; fi

# Help and usage.
mkdir -p "$T/empty"
for f in --help -h; do
  run_in "$T/empty" bash "$MODE_SH" "$f"
  if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -qF shell-team.mode && [ -z "$(ls -A "$T/empty")" ]; then pass "mode-help [$f] exits 0 naming shell-team.mode, no repository, nothing written"; else fail "mode-help [$f]: rc=$RC"; fi
done
run_in "$T/empty" bash "$MODE_SH" --bogus
if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && [ -n "$ERR" ]; then pass "mode-usage an unknown argument exits 2 with empty stdout"; else fail "mode-usage: rc=$RC out=$OUT err=$ERR"; fi
run_in "$T/empty" bash "$MODE_SH" a b
if [ "$RC" -eq 2 ] && [ -z "$OUT" ]; then pass "mode-usage-two two arguments exit 2 with empty stdout"; else fail "mode-usage-two: rc=$RC out=$OUT"; fi

# Launch shapes: a direct execution and a bare name reached through a PATH symlink.
new_repo launch
git -C "$R" config shell-team.mode local
run_in "$R" "$MODE_SH"
if [ "$RC" -eq 0 ] && [ "$OUT" = local ]; then pass "mode-launch-direct executed directly prints local"; else fail "mode-launch-direct: rc=$RC out=$OUT err=$ERR"; fi
mkdir -p "$T/pathdir"
ln -s "$MODE_SH" "$T/pathdir/team-mode.sh"
run_in "$R" env PATH="$T/pathdir:$PATH" team-mode.sh
if [ "$RC" -eq 0 ] && [ "$OUT" = local ]; then pass "mode-launch-path a bare name reached through a PATH symlink prints local"; else fail "mode-launch-path: rc=$RC out=$OUT err=$ERR"; fi

# --- check-durability.sh under local ------------------------------------------
SKIP_LINE='check-durability: skipped: shell-team.mode is local — no durability observation was made'
new_repo dur
printf '.shell-team/*.md\n' > "$R/.gitignore"
git -C "$R" rm -q --cached .shell-team/todo.md
git -C "$R" add .gitignore
git -C "$R" commit -q -m ign
run_in "$R" bash "$DUR_SH" --phase implement --task T-900 --ref refs/heads/main
if [ "$RC" -eq 1 ]; then pass "dur-tracked-control an ignored board fails closed in tracked mode (exit 1)"; else fail "dur-tracked-control: rc=$RC err=$ERR"; fi
git -C "$R" config shell-team.mode local
for ph in implement pre-merge close-out; do
  run_in "$R" bash "$DUR_SH" --phase "$ph" --task T-900 --ref refs/heads/main
  if [ "$RC" -eq 0 ] && [ "$OUT" = "$SKIP_LINE" ] && [ -z "$ERR" ]; then pass "dur-local-$ph under local prints the one skipped line, exit 0, empty stderr"; else fail "dur-local-$ph: rc=$RC out=$OUT err=$ERR"; fi
done
run_in "$R" bash "$DUR_SH" --phase implement --task T-900 --ref refs/heads/nope
if [ "$RC" -eq 0 ] && [ "$OUT" = "$SKIP_LINE" ]; then pass "dur-local-badref a ref naming no commit still skips under local"; else fail "dur-local-badref: rc=$RC out=$OUT"; fi
run_in "$R" bash "$DUR_SH" --phase bogus --task T-900 --ref HEAD
if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && printf '%s' "$ERR" | grep -q '^check-durability: usage:'; then pass "dur-local-usage usage errors keep exit 2 under local"; else fail "dur-local-usage: rc=$RC err=$ERR"; fi

# Unborn repository and malformed durability-mode both skip under local.
n=$((n + 1)); U="$T/r$n-unborn"; mkdir -p "$U"
git -C "$U" init -q --template="$T/tpl"
git -C "$U" symbolic-ref HEAD refs/heads/main
run_in "$U" bash "$DUR_SH" --phase implement --task T-900 --ref HEAD
if [ "$RC" -eq 1 ]; then pass "dur-unborn-control an unborn repository is not-durable in tracked mode"; else fail "dur-unborn-control: rc=$RC"; fi
git -C "$U" config shell-team.mode local
run_in "$U" bash "$DUR_SH" --phase implement --task T-900 --ref HEAD
if [ "$RC" -eq 0 ] && [ "$OUT" = "$SKIP_LINE" ]; then pass "dur-local-unborn an unborn repository skips under local"; else fail "dur-local-unborn: rc=$RC out=$OUT"; fi
new_repo durbad
printf 'bogus\n' > "$R/.shell-team/durability-mode"
run_in "$R" bash "$DUR_SH" --phase implement --task T-900 --ref HEAD
if [ "$RC" -eq 2 ]; then pass "dur-malformed-control a malformed durability-mode is structural in tracked mode"; else fail "dur-malformed-control: rc=$RC"; fi
git -C "$R" config shell-team.mode local
run_in "$R" bash "$DUR_SH" --phase implement --task T-900 --ref HEAD
if [ "$RC" -eq 0 ] && [ "$OUT" = "$SKIP_LINE" ]; then pass "dur-local-malformed a malformed durability-mode is never read under local"; else fail "dur-local-malformed: rc=$RC out=$OUT"; fi

# Resolver failure is structural, never tracked.
mkdir -p "$T/inst-none/bin" "$T/inst-weird/bin" "$T/inst-ok/bin" "$T/inst-none/templates" "$T/inst-weird/templates" "$T/inst-ok/templates"
for d in inst-none inst-weird inst-ok; do
  cp "$DUR_SH" "$REPO_ROOT/bin/team-paths.sh" "$T/$d/bin/"
  cp "$REPO_ROOT/templates/durability-records.txt" "$T/$d/templates/"
done
cp "$MODE_SH" "$T/inst-ok/bin/"
printf '%s\n' '#!/usr/bin/env bash' 'printf "weird\n"' > "$T/inst-weird/bin/team-mode.sh"
mkdir -p "$T/inst-fail/bin" "$T/inst-fail/templates"
cp "$DUR_SH" "$REPO_ROOT/bin/team-paths.sh" "$T/inst-fail/bin/"
cp "$REPO_ROOT/templates/durability-records.txt" "$T/inst-fail/templates/"
# A resolver that prints a valid word and still exits non-zero must not be read as tracked.
printf '%s\n' '#!/usr/bin/env bash' 'printf "tracked\n"' 'exit 3' > "$T/inst-fail/bin/team-mode.sh"
new_repo durinst
run_in "$R" bash "$T/inst-ok/bin/check-durability.sh" --phase implement --task T-900 --ref refs/heads/main
if [ "$RC" -eq 0 ]; then pass "dur-install-control an install with its sibling resolver passes a durable fixture"; else fail "dur-install-control: rc=$RC err=$ERR"; fi
for v in unset local; do
  if [ "$v" = local ]; then git -C "$R" config shell-team.mode local; fi
  for d in inst-none inst-weird inst-fail; do
    run_in "$R" bash "$T/$d/bin/check-durability.sh" --phase implement --task T-900 --ref refs/heads/main
    if [ "$RC" -eq 2 ] && [ -z "$OUT" ] && [ "$(printf '%s\n' "$ERR" | sed -n 1p | grep -c '^check-durability: structural:')" = 1 ]; then pass "dur-install-$d-$v a missing or out-of-set resolver is structural (exit 2)"; else fail "dur-install-$d-$v: rc=$RC out=$OUT err=$ERR"; fi
  done
done

# --- team-commit.sh under local -----------------------------------------------
printf 'msg\n' > "$T/msg"
st() { git -C "$1" rev-parse HEAD; git -C "$1" ls-files -s; git -C "$1" diff --cached --name-only; }
dirty() { printf 'y\n' >> "$1/README"; printf 'y\n' >> "$1/.shell-team/todo.md"; }
refused() {  # refused <repo> <class> <cmd...>
  local r="$1" cls="$2"
  shift 2
  st "$r" > "$T/z0"
  run_in "$r" "$@"
  st "$r" > "$T/z1"
  [ "$RC" -eq 2 ] && [ -z "$OUT" ] && printf '%s' "$ERR" | grep -q "^team-commit: refused ($cls): " && cmp -s "$T/z0" "$T/z1"
}
committed() {  # committed <repo> <want paths (sorted, space-joined with trailing space)> <cmd...>
  local r="$1" want="$2" h0 h1
  shift 2
  h0="$(git -C "$r" rev-parse HEAD)"
  run_in "$r" "$@"
  [ "$RC" -eq 0 ] || return 1
  h1="$(git -C "$r" rev-parse HEAD)"
  [ "$h1" != "$h0" ] && [ "$OUT" = "$h1" ] && [ "$(git -C "$r" rev-parse HEAD^)" = "$h0" ] \
    && [ "$(git -C "$r" diff-tree --no-commit-id -r --name-only HEAD | sort | tr '\n' ' ')" = "$want" ]
}
M=(--message-file "$T/msg" --)

new_repo commit1; dirty "$R"; git -C "$R" config shell-team.mode local
if refused "$R" local-mode bash "$COMMIT_SH" "${M[@]}" .shell-team/todo.md && printf '%s' "$ERR" | grep -qF '.shell-team/todo.md' && printf '%s' "$ERR" | grep -qF shell-team.mode; then pass "commit-local-base a base-dir path is refused (local-mode), naming path and key, state unchanged"; else fail "commit-local-base: rc=$RC err=$ERR"; fi
if refused "$R" local-mode bash "$COMMIT_SH" "${M[@]}" README .shell-team/todo.md; then pass "commit-local-mixed a mixed request is refused and nothing is staged"; else fail "commit-local-mixed: rc=$RC err=$ERR"; fi
if committed "$R" 'README ' bash "$COMMIT_SH" "${M[@]}" README; then pass "commit-local-outside a path outside the base dir commits"; else fail "commit-local-outside: rc=$RC err=$ERR"; fi

new_repo commit2; git -C "$R" config shell-team.mode local
mkdir -p "$R/.shell-team-x"; printf 'x\n' > "$R/.shell-team-x/f.md"; printf 'x\n' > "$R/.shell-teamx"
if committed "$R" '.shell-team-x/f.md .shell-teamx ' bash "$COMMIT_SH" "${M[@]}" .shell-team-x/f.md .shell-teamx; then pass "commit-local-boundary siblings sharing the base prefix without the slash commit"; else fail "commit-local-boundary: rc=$RC err=$ERR"; fi

new_repo commit3; dirty "$R"; git -C "$R" config shell-team.mode local
mkdir -p "$R/ops" "$R/opsx"; printf 'x\n' > "$R/ops/a.md"; printf 'x\n' > "$R/opsx/b.md"
got="$(cd "$R" && TEAM_RUN_BASE=ops/ bash "$REPO_ROOT/bin/team-paths.sh" --get base)"
if [ "$got" = "ops/" ]; then pass "commit-base-control team-paths prints the trailing-slash base the refusal must normalise"; else fail "commit-base-control: got=$got"; fi
if refused "$R" local-mode env TEAM_RUN_BASE=ops/ bash "$COMMIT_SH" "${M[@]}" ops/a.md; then pass "commit-local-override a path under an overridden base (trailing slash) is refused"; else fail "commit-local-override: rc=$RC err=$ERR"; fi
if committed "$R" '.shell-team/todo.md opsx/b.md ' env TEAM_RUN_BASE=ops/ bash "$COMMIT_SH" "${M[@]}" opsx/b.md .shell-team/todo.md; then pass "commit-local-override-outside paths outside the overridden base commit"; else fail "commit-local-override-outside: rc=$RC err=$ERR"; fi

new_repo commit4; dirty "$R"; git -C "$R" config shell-team.mode local
mkdir -p "$R/.Shell-Team"; printf 'x\n' > "$R/.Shell-Team/u.md"
if refused "$R" local-mode bash "$COMMIT_SH" "${M[@]}" .Shell-Team/u.md; then pass "commit-local-case the base-prefix test ignores ASCII letter case"; else fail "commit-local-case: rc=$RC err=$ERR"; fi

for v in unset Local tracked; do
  new_repo "commit5$v"; dirty "$R"
  if [ "$v" != unset ]; then git -C "$R" config shell-team.mode "$v"; fi
  if committed "$R" '.shell-team/todo.md ' bash "$COMMIT_SH" "${M[@]}" .shell-team/todo.md; then pass "commit-tracked-$v key $v still commits a base-dir path"; else fail "commit-tracked-$v: rc=$RC err=$ERR"; fi
done

# Resolver failure is a refusal (class mode) before any write.
mkdir -p "$T/ci-none" "$T/ci-weird" "$T/ci-nopaths" "$T/ci-fail"
cp "$COMMIT_SH" "$T/ci-fail/"
printf '%s\n' '#!/usr/bin/env bash' 'printf "tracked\n"' 'exit 3' > "$T/ci-fail/team-mode.sh"
cp "$COMMIT_SH" "$T/ci-none/"
cp "$COMMIT_SH" "$T/ci-weird/"
cp "$COMMIT_SH" "$MODE_SH" "$T/ci-nopaths/"
printf '%s\n' '#!/usr/bin/env bash' 'printf "weird\n"' > "$T/ci-weird/team-mode.sh"
cp "$REPO_ROOT/bin/team-paths.sh" "$T/ci-weird/"
for v in unset local; do
  for d in ci-none ci-weird ci-fail; do
    new_repo "ci$v$d"; dirty "$R"
    if [ "$v" = local ]; then git -C "$R" config shell-team.mode local; fi
    if refused "$R" mode bash "$T/$d/team-commit.sh" "${M[@]}" README; then pass "commit-mode-$d-$v a missing or out-of-set resolver is refused (class mode)"; else fail "commit-mode-$d-$v: rc=$RC err=$ERR"; fi
  done
done
new_repo cinopaths-local; dirty "$R"; git -C "$R" config shell-team.mode local
if refused "$R" mode bash "$T/ci-nopaths/team-commit.sh" "${M[@]}" README; then pass "commit-mode-nopaths-local local mode without team-paths.sh is refused (class mode)"; else fail "commit-mode-nopaths-local: rc=$RC err=$ERR"; fi
new_repo cinopaths-tracked; dirty "$R"
if committed "$R" 'README ' bash "$T/ci-nopaths/team-commit.sh" "${M[@]}" README; then pass "commit-nopaths-tracked tracked mode needs no team-paths.sh"; else fail "commit-nopaths-tracked: rc=$RC err=$ERR"; fi

if [ "$fails" -ne 0 ]; then
  printf 'team-mode suite: %s case(s) failed\n' "$fails" >&2
  exit 1
fi
printf 'team-mode suite: all cases passed\n'
