#!/usr/bin/env bash
# run.sh — drive the whole mechanical `local` record-mode path in a fixture
# repository (T-1183, issue #711 task C2a): the mechanical half of #711's AC2.
#
# The fixture clone declares `git config shell-team.mode local`, lists the base
# dir in its own .git/info/exclude and is scaffolded by bin/team-init.sh. Then
# the scripts the loop calls run against it, in the order of a task:
#   team-mode.sh, check-durability.sh (skips), team-commit.sh (refuses a
#   base-dir path, commits a code path), check-pii-shapes.sh --paths (reads the
#   ignored records), team-setup.sh (the info/exclude report), check-handoff.sh
#   and close-out.sh on the ignored board, and finally `git log --all` on the
#   base dir, which must be empty while the code commit exists.
#
# Every script runs under a process-group timeout with `ulimit -f` bounding what
# it can write (the captured output files take the same limit), in a throwaway
# repository under ${TMPDIR:-/tmp} (never inside this checkout: a nested .git is
# denied by some sandboxes), with a temp HOME / CODEX_HOME / XDG_CONFIG_HOME,
# a pinned global git config and stub `claude` and `codex` executables first on
# PATH. The planted shape is assembled from fragments, so no PII-shaped byte
# enters this tree. No recursive deletion runs here: the scratch root is left
# under ${TMPDIR:-/tmp}.

# The `A && pass || fail` assertion idiom is deliberate; every helper exits 0.
# shellcheck disable=SC2015,SC2016
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$REPO_ROOT/bin"
export LC_ALL=C
ulimit -f 200000 2> /dev/null || true

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }
die() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/t1183-local-mode.XXXXXX")" || die "cannot create the scratch root"
T="$(cd "$T" && pwd -P)" || die "cannot resolve the scratch root"

export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset TEAM_RUN_BASE CODEX_THREAD_ID CLAUDE_CONFIG_DIR PII_CHECK_TRACKER_KEY PII_CHECK_BASE GITHUB_BASE_REF
unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
mkdir -p "$HOME" "$CODEX_HOME" "$T/s" || die "cannot create the scratch directories"
for b in claude codex; do
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b" && chmod +x "$T/s/$b" || die "cannot create the stub $b"
done
export PATH="$T/s:$PATH"

# tmo <dir> <stdout-file> <stderr-file> <command...>: run in <dir> in its own
# process group; the group is killed after 120 s; output lands in the files,
# bounded by the same file-size limit. Returns the command's exit status.
tmo() {
  local d="$1" o="$2" e="$3" p w r
  shift 3
  set -m
  ( cd "$d" && ulimit -f 20000 && exec "$@" ) < /dev/null > "$o" 2> "$e" &
  p=$!
  ( sleep 120; kill -KILL -- -"$p" ) > /dev/null 2>&1 &
  w=$!
  wait "$p"
  r=$?
  kill -KILL -- -"$w" > /dev/null 2>&1
  wait "$w" > /dev/null 2>&1
  set +m
  return "$r"
}
O="$T/out"; E="$T/err"
RC=0
# run <dir> <command...>: sets RC; the streams land in $O and $E.
run() { local d="$1"; shift; tmo "$d" "$O" "$E" "$@"; RC=$?; }
nonempty() { [ -s "$1" ]; }
empty() { [ ! -s "$1" ]; }

# sec <heading> <file>: the lines of one setup report section.
RMH="Remains the operator's decision:"
sec() { awk -v h="$1" -v c="$RMH" '$0 == "Done:" || $0 == "Already in place:" || $0 == c || $0 == "Required:" || $0 == "Notice:" { f = ($0 == h); next } f' "$2"; }

mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" \
    && git -C "$1" add README \
    && git -C "$1" -c user.email=t -c user.name=t commit -q -m init \
    && git -C "$1" config user.email t && git -C "$1" config user.name t \
    && git -C "$1" config shell-team.mode local && mkdir -p "$1/.git/info" && : >> "$1/.git/info/exclude"
}

# --- the fixture clone: local mode, base dir ignored, scaffolded -------------
F="$T/clone"
mkrepo "$F" || die "cannot build the fixture clone"
printf '/.shell-team/\n' >> "$F/.git/info/exclude" || die "cannot write the clone's exclude file"
run "$F" bash "$BIN/team-init.sh" .
[ "$RC" = 0 ] && [ -s "$F/.shell-team/todo.md" ] || die "team-init.sh did not scaffold the fixture clone (rc=$RC)"
git -C "$F" check-ignore -q .shell-team || die "the fixture base dir is not ignored (control)"
[ -z "$(git -C "$F" status --porcelain)" ] || die "the fixture clone is not clean after the scaffold (control)"
HEAD0="$(git -C "$F" rev-parse HEAD)" || die "cannot read the fixture HEAD"
N0="$(git -C "$F" rev-list --count HEAD)" || die "cannot count the fixture commits"

# 1. team-mode.sh
run "$F" bash "$BIN/team-mode.sh"
{ [ "$RC" = 0 ] && [ "$(cat "$O")" = local ] && empty "$E"; } \
  && pass "local-mode: team-mode.sh prints local for the fixture clone" \
  || fail "local-mode: team-mode.sh prints local for the fixture clone (rc=$RC)"

# 2. check-durability.sh skips in local mode
run "$F" bash "$BIN/check-durability.sh" --phase implement --task T-901 --ref HEAD
{ [ "$RC" = 0 ] && [ "$(wc -l < "$O" | tr -d ' ')" = 1 ] \
  && grep -qF 'check-durability: skipped: shell-team.mode is local' "$O" \
  && grep -qF 'no durability observation was made' "$O" && empty "$E"; } \
  && pass "local-mode: check-durability.sh prints one skipped line and exits 0" \
  || fail "local-mode: check-durability.sh prints one skipped line and exits 0 (rc=$RC)"

# Records the later steps read: a spec, an interventions record and the board
# entry, all under the ignored base dir.
mkdir -p "$F/.shell-team/specs" "$F/.shell-team/interventions" || die "cannot create the record directories"
printf '# fixture spec\n' > "$F/.shell-team/specs/T-901-demo.md" || die "cannot write the fixture spec"
printf '<!-- BEGIN interventions: T-901 -->\nno interventions occurred\n<!-- END interventions: T-901 -->\n' \
  > "$F/.shell-team/interventions/T-901.md" || die "cannot write the fixture interventions record"
printf 'fixture commit message\n' > "$T/msg.txt" || die "cannot write the commit message file"
mkdir -p "$F/src" && printf 'fixture code\n' > "$F/src/code.txt" || die "cannot write the fixture code file"

# 3. team-commit.sh refuses a base-dir path
run "$F" bash "$BIN/team-commit.sh" --message-file "$T/msg.txt" -- .shell-team/specs/T-901-demo.md
{ [ "$RC" = 2 ] && grep -qF 'refused (local-mode)' "$E" \
  && [ "$(git -C "$F" rev-parse HEAD)" = "$HEAD0" ] && [ -z "$(git -C "$F" diff --cached --name-only)" ]; } \
  && pass "local-mode: team-commit.sh refuses a base-dir path with exit 2 and class local-mode" \
  || fail "local-mode: team-commit.sh refuses a base-dir path with exit 2 and class local-mode (rc=$RC)"

# 4. team-commit.sh commits a path outside the base dir
run "$F" bash "$BIN/team-commit.sh" --message-file "$T/msg.txt" -- src/code.txt
SHA="$(cat "$O")"
{ [ "$RC" = 0 ] && [ "$SHA" = "$(git -C "$F" rev-parse HEAD)" ] && [ "$SHA" != "$HEAD0" ] \
  && [ "$(git -C "$F" show --name-only --format= HEAD)" = src/code.txt ] \
  && [ "$(git -C "$F" rev-list --count HEAD)" = $((N0 + 1)) ]; } \
  && pass "local-mode: team-commit.sh commits a path outside the base dir" \
  || fail "local-mode: team-commit.sh commits a path outside the base dir (rc=$RC)"

# 5-7. check-pii-shapes.sh --paths reads the ignored records. The planted shape
# is assembled at run time from fragments (a token-shaped string).
P_CLEAN='check-pii-shapes: clean (no PII-shaped bytes found)'
P_TOKEN="$(printf 'gh%s_%s' p "$(printf '%024d' 5)")"
printf 'note %s\n' "$P_TOKEN" > "$F/.shell-team/planted.md" || die "cannot plant the shape"
run "$F" bash "$BIN/check-pii-shapes.sh" --all
ctl_rc=$RC; ctl_clean=0; grep -qxF "$P_CLEAN" "$O" && ctl_clean=1
run "$F" bash "$BIN/check-pii-shapes.sh" --paths .shell-team
{ [ "$ctl_rc" = 0 ] && [ "$ctl_clean" = 1 ] && [ "$RC" = 1 ] \
  && grep -qxF 'FINDING pattern=token path=.shell-team/planted.md line=1' "$O" \
  && ! grep -qF "$P_TOKEN" "$O" "$E" && ! grep -qF "$P_CLEAN" "$O" "$E"; } \
  && pass "local-mode: check-pii-shapes.sh --paths reports a planted shape in the ignored base dir" \
  || fail "local-mode: check-pii-shapes.sh --paths reports a planted shape in the ignored base dir (all_rc=$ctl_rc rc=$RC)"

printf 'clean\n' > "$F/.shell-team/planted.md" || die "cannot overwrite the planted file"
run "$F" bash "$BIN/check-pii-shapes.sh" --paths .shell-team
{ [ "$RC" = 0 ] && [ "$(cat "$O")" = "$P_CLEAN" ]; } \
  && pass "local-mode: check-pii-shapes.sh --paths is clean on the same tree without it" \
  || fail "local-mode: check-pii-shapes.sh --paths is clean on the same tree without it (rc=$RC)"

mkdir -p "$F/emptydir" || die "cannot create the empty directory"
run "$F" bash "$BIN/check-pii-shapes.sh" --paths emptydir
r1=$RC; c1=0; grep -qF "$P_CLEAN" "$O" "$E" && c1=1
run "$F" bash "$BIN/check-pii-shapes.sh" --paths no-such-path
r2=$RC; c2=0; grep -qF "$P_CLEAN" "$O" "$E" && c2=1
{ [ "$r1" = 2 ] && [ "$r2" = 2 ] && [ "$c1" = 0 ] && [ "$c2" = 0 ]; } \
  && pass "local-mode: check-pii-shapes.sh --paths exits 2 on an empty directory and on a missing path" \
  || fail "local-mode: check-pii-shapes.sh --paths exits 2 on an empty directory and on a missing path (rc=$r1/$r2)"

# 8. team-setup.sh with the base dir ignored
c0="$(cksum < "$F/.git/info/exclude")"; g0="$(cksum < "$F/.git/config")"
run "$F" bash "$BIN/team-setup.sh" --host claude-code
{ [ "$RC" = 0 ] && [ "$(sec 'Required:' "$O")" = '- none' ] \
  && [ "$(sec 'Already in place:' "$O" | grep -cF -- '- base directory in local mode: ')" = 1 ] \
  && ! grep -qF 'git add' "$O" "$E" && ! grep -q '^- base directory in git: ' "$O" \
  && [ "$(cksum < "$F/.git/info/exclude")" = "$c0" ] && [ "$(cksum < "$F/.git/config")" = "$g0" ] \
  && [ ! -e "$F/.gitignore" ]; } \
  && pass "local-mode: team-setup.sh with the base dir ignored requires nothing for it and prints no git add" \
  || fail "local-mode: team-setup.sh with the base dir ignored requires nothing for it and prints no git add (rc=$RC)"

# 9. team-setup.sh with the base dir not ignored (a second local clone with no rule)
F2="$T/clone-noign"
mkrepo "$F2" || die "cannot build the second fixture clone"
EP2="$(git -C "$F2" rev-parse --git-path info/exclude)" || die "cannot read the exclude path"
run "$F2" bash "$BIN/team-setup.sh" --host claude-code
sec 'Required:' "$O" > "$T/req"
{ [ "$RC" = 0 ] && [ "$(wc -l < "$T/req" | tr -d ' ')" = 1 ] && grep -qF -- '`/.shell-team/`' "$T/req" \
  && grep -qF -- "$EP2" "$T/req" && ! grep -qF 'git add' "$O" "$E" \
  && [ ! -e "$F2/.gitignore" ] && [ -z "$(git -C "$F2" diff --cached --name-only)" ]; } \
  && pass "local-mode: team-setup.sh with the base dir not ignored prints the info/exclude line and no git add" \
  || fail "local-mode: team-setup.sh with the base dir not ignored prints the info/exclude line and no git add (rc=$RC)"

# 10-11. The board entry at READY_FOR_MERGE, then check-handoff.sh and close-out.sh.
# The conformant entry is built the way tests/close-out/run.sh builds one: an
# Active line whose flag is directly followed by its spec path, plus the
# interventions record written above; the unconditional oversight gate passes
# through its shipped default.
BOARD="$F/.shell-team/todo.md"
awk '
  /^## Active$/ { print; print ""; print "- [ ] **T-901** local-mode fixture task — `READY_FOR_MERGE` — spec: .shell-team/specs/T-901-demo.md"; skip = 1; next }
  /^## / { skip = 0 }
  skip && /^_\(none\)_$/ { next }
  { print }
' "$BOARD" > "$T/board.new" && [ -s "$T/board.new" ] && cp "$T/board.new" "$BOARD" || die "cannot write the fixture board"
grep -qF '**T-901**' "$BOARD" || die "the fixture entry is not on the board (control)"
run "$F" bash "$BIN/check-handoff.sh" "$BOARD"
{ [ "$RC" = 0 ] && git -C "$F" check-ignore -q .shell-team/todo.md; } \
  && pass "local-mode: check-handoff.sh passes on the ignored board" \
  || fail "local-mode: check-handoff.sh passes on the ignored board (rc=$RC)"

H1="$(git -C "$F" rev-parse HEAD)"
run "$F" bash "$BIN/close-out.sh" --task T-901 --date 2026-01-01
if [ "$RC" != 0 ]; then cat "$E" >&2; fi
{ [ "$RC" = 0 ] && [ "$(git -C "$F" rev-parse HEAD)" = "$H1" ] \
  && awk '/^## Done$/ { d = 1; next } /^## / { d = 0 } d && /^- \[x\] \*\*T-901\*\*/ { f = 1 } END { exit !f }' "$BOARD" \
  && awk '/^## Active$/ { a = 1; next } /^## / { a = 0 } a && /\*\*T-901\*\*/ { f = 1 } END { exit (f ? 1 : 0) }' "$BOARD" \
  && [ -z "$(git -C "$F" status --porcelain)" ]; } \
  && pass "local-mode: close-out.sh moves the entry to Done and HEAD does not move" \
  || fail "local-mode: close-out.sh moves the entry to Done and HEAD does not move (rc=$RC)"

# 12. Nothing under the base dir ever reached git, and the code commit exists.
{ [ -z "$(git -C "$F" log --all --format=%H -- .shell-team)" ] \
  && [ -z "$(git -C "$F" ls-files -- .shell-team)" ] \
  && [ -n "$(git -C "$F" log --all --format=%H -- src/code.txt)" ] \
  && [ "$(git -C "$F" rev-list --count HEAD)" = $((N0 + 1)) ]; } \
  && pass "local-mode: git log --all on the base dir is empty and the code commit exists" \
  || fail "local-mode: git log --all on the base dir is empty and the code commit exists"

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'local-mode suite: all assertions passed\n'
else
  printf 'local-mode suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
