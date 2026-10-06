#!/usr/bin/env bash
# run.sh — fixture suite for bin/team-setup.sh (T-1163, GitHub issue #640): the
# deterministic half of the "set up shell-team" / "update shell-team" prompt.
#
# Every case runs the real script in a throwaway git repository under
# ${TMPDIR:-/tmp} (never inside this checkout: a nested .git is denied by some
# sandboxes), with a temp HOME / CODEX_HOME / XDG_CONFIG_HOME, a pinned global
# git config, TEAM_RUN_BASE and CODEX_THREAD_ID unset, and stub `claude` and
# `codex` executables first on PATH. Cases map to the spec's AC1-AC10:
#   write-set bound, host selection and refusals before any write,
#   idempotency, the exclude file, drift, refused writes (skipped as root),
#   prerequisites (never run, never probed), the report's shape, the
#   template-drift list, and the forbidden-widening token lock.
# T-1174 (issue #689) adds the five-section report: the review-transfer notice,
# the settings reader's "already in place" and "could not determine" lines, and
# the base directory as a required action (ignore sources, re-include shape,
# legacy specs directory). AC8 and AC10 of T-1163 are narrowed accordingly.

# The `A && pass || fail` assertion idiom and the subshell-scoped CODEX_THREAD_ID
# fixtures are deliberate; every pass/fail helper here exits 0.
# shellcheck disable=SC2015,SC2016,SC2030,SC2031
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
S="$REPO_ROOT/bin/team-setup.sh"
export LC_ALL=C

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }
# ok <desc> <command...>: PASS when the command succeeds.
ok() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }

[ -s "$S" ] || { fail "bin/team-setup.sh exists and is non-empty"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/t1163-setup.XXXXXX")"
T="$(cd "$T" && pwd -P)"
# The scratch root is left under ${TMPDIR:-/tmp}: no recursive delete runs here.
# Every read-only fixture below restores its own permissions right after use.

export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset TEAM_RUN_BASE CODEX_THREAD_ID
mkdir -p "$HOME" "$CODEX_HOME" "$T/s"
for b in claude codex; do
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b"
  chmod +x "$T/s/$b"
done
SP="$T/s:$PATH"

RM="Remains the operator's decision:"
mk() {
  mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" \
    && git -C "$1" add README \
    && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i
}
# st <dir> [args...]: run setup from <dir>; prints the exit status; the streams
# land in $T/o and $T/e.
st() { local d="$1" r=0; shift; (cd "$d" && PATH="$SP" bash "$S" "$@" < /dev/null > "$T/o" 2> "$T/e") || r=$?; printf '%s' "$r"; }
# rc_of <dir> [args...]: same as st, but never trips errexit on a non-zero exit.
sec() { awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" -v d='Required:' -v e='Notice:' '$0==a||$0==b||$0==c||$0==d||$0==e{f=($0==h);next} f' "$2"; }
ck() { local r=0; (cd "$1" && bash "$REPO_ROOT/bin/check-codex-agents.sh" --out-dir "$1/.codex/agents" > /dev/null 2>&1) || r=$?; printf '%s' "$r"; }
snap() {
  (cd "$1" && find . -path ./.git/objects -prune -o -print | sort | while IFS= read -r p; do
    if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi
  done)
}
chg() { { diff "$1" "$2" || true; } | sed -n 's/^[<>] //p' | cut -d' ' -f1 | sort -u; }
cnt() { grep -cxF -- "$1" "$2" || true; }
is_root=0
[ "$(id -u)" = 0 ] && is_root=1

# ---------------------------------------------------------------------------
# AC1 — the write set is bounded (both hosts); HOME and CODEX_HOME untouched.
# ---------------------------------------------------------------------------
write_set() { # <host> <allowed-case-pattern-file-tag>
  local host="$1" R="$T/repo-ws-$1" x
  mk "$R"
  snap "$R" > "$T/r0"; snap "$HOME" > "$T/h0"; snap "$CODEX_HOME" > "$T/c0"
  x="$(st "$R" --host "$host")"
  snap "$R" > "$T/r1"; snap "$HOME" > "$T/h1"; snap "$CODEX_HOME" > "$T/c1"
  [ "$x" = 0 ] && pass "AC1 $host: exits 0" || fail "AC1 $host: exit $x (stderr: $(cat "$T/e"))"
  cmp -s "$T/h0" "$T/h1" && cmp -s "$T/c0" "$T/c1" && pass "AC1 $host: HOME and CODEX_HOME byte-identical" || fail "AC1 $host: HOME or CODEX_HOME changed"
  chg "$T/r0" "$T/r1" > "$T/d"
  local bad=0 p
  while IFS= read -r p; do
    case "$host:$p" in
      *:./.shell-team|*:./.shell-team/*) ;;
      codex-cli:./.codex|codex-cli:./.codex/agents|codex-cli:./.codex/agents/*|codex-cli:./.git/info|codex-cli:./.git/info/exclude) ;;
      *) bad=1; printf 'unexpected change: %s\n' "$p" >&2 ;;
    esac
  done < "$T/d"
  [ "$bad" -eq 0 ] && grep -qxF ./.shell-team/todo.md "$T/d" && pass "AC1 $host: only artifact paths changed, the board landed" || fail "AC1 $host: write set not bounded"
  if [ "$host" = codex-cli ]; then
    grep -qxF ./.codex/agents "$T/d" && grep -qxF ./.git/info/exclude "$T/d" && [ "$(ck "$R")" = 0 ] && pass "AC1 codex-cli: agents and exclude landed, agents check clean" || fail "AC1 codex-cli: agents/exclude missing or drifting"
  else
    [ ! -e "$R/.codex" ] && pass "AC1 claude-code: no .codex created" || fail "AC1 claude-code: .codex created"
  fi
}
write_set codex-cli
write_set claude-code

# ---------------------------------------------------------------------------
# AC2 — host selection, arguments, refusals before any write.
# ---------------------------------------------------------------------------
R="$T/repo-h1"; mk "$R"
x="$(export CODEX_THREAD_ID=t; st "$R")"
[ "$x" = 0 ] && [ -d "$R/.codex/agents" ] && head -n 1 "$T/o" | grep -qF codex-cli && head -n 1 "$T/o" | grep -qF CODEX_THREAD_ID \
  && pass "AC2: CODEX_THREAD_ID set selects codex-cli and the header says so" || fail "AC2: CODEX_THREAD_ID selection (rc=$x)"
R="$T/repo-h2"; mk "$R"
x="$(st "$R")"
[ "$x" = 0 ] && [ ! -e "$R/.codex" ] && [ -s "$R/.shell-team/todo.md" ] && head -n 1 "$T/o" | grep -qF claude-code \
  && pass "AC2: unset CODEX_THREAD_ID selects claude-code" || fail "AC2: default host selection (rc=$x)"
R="$T/repo-h2e"; mk "$R"
x="$(export CODEX_THREAD_ID=''; st "$R")"
[ "$x" = 0 ] && [ ! -e "$R/.codex" ] && pass "AC2: an empty CODEX_THREAD_ID is claude-code" || fail "AC2: empty CODEX_THREAD_ID (rc=$x)"
R="$T/repo-h2f"; mk "$R"
x="$(export CODEX_THREAD_ID=t; st "$R" --host claude-code)"
[ "$x" = 0 ] && [ ! -e "$R/.codex" ] && pass "AC2: --host overrides CODEX_THREAD_ID" || fail "AC2: --host precedence (rc=$x)"
R="$T/repo-h3"; mk "$R"; mkdir -p "$R/sub/dir"
x="$(st "$R/sub/dir" --host claude-code)"
[ "$x" = 0 ] && [ -s "$R/.shell-team/todo.md" ] && [ ! -e "$R/sub/.shell-team" ] && [ ! -e "$R/sub/dir/.shell-team" ] \
  && pass "AC2: a run from a subdirectory scaffolds the repository root only" || fail "AC2: subdirectory run (rc=$x)"
R="$T/repo-h4"; mk "$R"
for a in '--host bogus' '--bogus' '--host' 'extra' '--host claude-code extra'; do
  # shellcheck disable=SC2086 # intentional word splitting of the fixture argument list
  x="$(st "$R" $a)"
  [ "$x" = 2 ] && pass "AC2: '$a' exits 2" || fail "AC2: '$a' exited $x"
done
[ ! -e "$R/.shell-team" ] && [ ! -e "$R/.codex" ] && pass "AC2: refused arguments wrote no .shell-team or .codex" || fail "AC2: a refused argument wrote something"
mkdir -p "$T/ng"
x="$(st "$T/ng" --host codex-cli)"
[ "$x" = 2 ] && [ -z "$(find "$T/ng" -mindepth 1 -print)" ] && pass "AC2: outside a git work tree exits 2 and writes nothing" || fail "AC2: non-git directory (rc=$x)"
R="$T/repo-q'x"; mk "$R"
x="$(st "$R" --host codex-cli)"
[ "$x" = 2 ] && [ ! -e "$R/.shell-team" ] && [ ! -e "$R/.codex" ] && pass "AC2: a repository path with a single quote exits 2, nothing written" || fail "AC2: single-quote repository path (rc=$x)"
R="$T/repo-q"$'\n'"nl"; mk "$R"
x="$(st "$R" --host codex-cli)"
[ "$x" = 2 ] && [ ! -e "$R/.shell-team" ] && [ ! -e "$R/.codex" ] && pass "AC2: a repository path with a control character exits 2, nothing written" || fail "AC2: control-character repository path (rc=$x)"
PQ="$T/p'q"; mkdir -p "$PQ"; cp -R "$REPO_ROOT/bin" "$REPO_ROOT/templates" "$REPO_ROOT/agents" "$PQ/"
R="$T/repo-h5"; mk "$R"
x="$( (cd "$R" && PATH="$SP" bash "$PQ/bin/team-setup.sh" --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 2 ] && [ ! -e "$R/.shell-team" ] && [ ! -e "$R/.codex" ] && pass "AC2: a plugin root with a single quote exits 2, nothing written" || fail "AC2: single-quote plugin root (rc=$x)"
R="$T/repo-h6"; mk "$R"
x="$( (cd "$R" && TEAM_RUN_BASE=../escape PATH="$SP" bash "$S" --host claude-code < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 2 ] && [ ! -e "$R/.shell-team" ] && [ ! -e "$T/escape" ] && pass "AC2: an invalid TEAM_RUN_BASE exits 2 before any write" || fail "AC2: invalid TEAM_RUN_BASE (rc=$x)"
R="$T/repo-h7"; mk "$R"
x="$( (cd "$R" && TEAM_RUN_BASE=.custom PATH="$SP" bash "$S" --host claude-code < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 0 ] && [ -s "$R/.custom/todo.md" ] && [ ! -e "$R/.shell-team" ] && pass "AC2: a TEAM_RUN_BASE override scaffolds that base dir" || fail "AC2: TEAM_RUN_BASE override (rc=$x)"
x="$( (cd "$T/ng" && bash "$S" --help < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 0 ] && [ -s "$T/o" ] && [ -z "$(find "$T/ng" -mindepth 1 -print)" ] && pass "AC2: --help outside a git work tree exits 0 with usage" || fail "AC2: --help (rc=$x)"

# Launch shapes: bash script, ./script, a bare name reached through a PATH symlink.
R="$T/repo-l1"; mk "$R"
x="$( (cd "$R" && PATH="$SP" "$S" --host claude-code < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 0 ] && [ -s "$R/.shell-team/todo.md" ] && pass "launch shape: direct execution" || fail "launch shape: direct execution (rc=$x)"
mkdir -p "$T/lk"; ln -s "$S" "$T/lk/team-setup.sh"
R="$T/repo-l2"; mk "$R"
x="$( (cd "$R" && PATH="$T/lk:$SP" team-setup.sh --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 0 ] && [ "$(ck "$R")" = 0 ] && pass "launch shape: bare name through a PATH symlink" || fail "launch shape: PATH symlink (rc=$x)"

# ---------------------------------------------------------------------------
# AC3 — idempotency.
# ---------------------------------------------------------------------------
R="$T/repo-i1"; mk "$R"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && [ "$(sec Done: "$T/o" | grep -c .)" -ge 1 ] && [ "$(sec Done: "$T/o")" != '- none' ] && pass "AC3: the first codex-cli run's Done is non-empty" || fail "AC3: first run Done (rc=$x)"
snap "$R" > "$T/r1"
x="$(st "$R" --host codex-cli)"
snap "$R" > "$T/r2"
[ "$x" = 0 ] && cmp -s "$T/r1" "$T/r2" && [ "$(sec Done: "$T/o")" = '- none' ] && pass "AC3: a second codex-cli run is byte-identical and Done is - none" || fail "AC3: second codex-cli run (rc=$x)"
sec 'Already in place:' "$T/o" > "$T/a"
grep -qF .codex/agents "$T/a" && grep -qF .shell-team "$T/a" && [ "$(cnt .codex/agents "$R/.git/info/exclude")" = 1 ] && pass "AC3: Already in place names .codex/agents and .shell-team, one exclude line" || fail "AC3: Already in place / exclude count"
R="$T/repo-i2"; mk "$R"
st "$R" --host claude-code > /dev/null; snap "$R" > "$T/r1"
x="$(st "$R" --host claude-code)"; snap "$R" > "$T/r2"
[ "$x" = 0 ] && cmp -s "$T/r1" "$T/r2" && [ "$(sec Done: "$T/o")" = '- none' ] && pass "AC3: a second claude-code run is byte-identical and Done is - none" || fail "AC3: second claude-code run (rc=$x)"

# ---------------------------------------------------------------------------
# AC4 — the exclude file.
# ---------------------------------------------------------------------------
R="$T/repo-x1"; mk "$R"; X="$R/.git/info/exclude"; mkdir -p "$R/.git/info"; printf '# keep\n*.log' > "$X"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && [ "$(head -n 1 "$X")" = '# keep' ] && [ "$(cnt '*.log' "$X")" = 1 ] && [ "$(cnt .codex/agents "$X")" = 1 ] \
  && [ -z "$(git -C "$R" status --short --untracked-files=all -- .codex)" ] && pass "AC4: no trailing newline — existing lines whole, one line appended, status clean" || fail "AC4: exclude without trailing newline (rc=$x)"
R="$T/repo-x2"; mk "$R"; X="$R/.git/info/exclude"; rm -f "$X"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && [ "$(cnt .codex/agents "$X")" = 1 ] && pass "AC4: an absent exclude file is created with the one line" || fail "AC4: absent exclude (rc=$x)"
R="$T/repo-x3"; mk "$R"; printf '.codex/agents\n' > "$R/.gitignore"
{ git -C "$R" add .gitignore && git -C "$R" -c user.email=t@example.com -c user.name=t commit -q -m g; }
mkdir -p "$R/.git/info"; touch "$R/.git/info/exclude"; cp "$R/.git/info/exclude" "$T/gx"
x="$(st "$R" --host codex-cli)"
cmp -s "$T/gx" "$R/.git/info/exclude" && [ "$x" = 0 ] && [ "$(ck "$R")" = 0 ] && [ -z "$(git -C "$R" status --short --untracked-files=all -- .codex)" ] && pass "AC4: a committed .gitignore rule leaves the exclude byte-identical" || fail "AC4: committed .gitignore rule (rc=$x)"
R="$T/repo-x4"; mk "$R"; mkdir -p "$R/.git/info"; printf '.codex/\n' > "$R/.git/info/exclude"; cp "$R/.git/info/exclude" "$T/bx"
x="$(st "$R" --host codex-cli)"
cmp -s "$T/bx" "$R/.git/info/exclude" && [ "$x" = 0 ] && [ -z "$(git -C "$R" status --short --untracked-files=all -- .codex)" ] && pass "AC4: a broader .codex/ rule leaves the exclude byte-identical" || fail "AC4: broader .codex/ rule (rc=$x)"
M="$T/xm"; W="$T/xw"; mk "$M"
git -C "$M" worktree add -q "$W" > /dev/null 2>&1
x="$(st "$W" --host codex-cli)"
[ -f "$W/.git" ] && [ "$x" = 0 ] && [ "$(cnt .codex/agents "$M/.git/info/exclude")" = 1 ] && [ -z "$(find "$M/.git/worktrees" -name exclude -print)" ] \
  && [ "$(ck "$W")" = 0 ] && [ -z "$(git -C "$W" status --short --untracked-files=all -- .codex)" ] && pass "AC4: a linked worktree writes the main repository's exclude only" || fail "AC4: linked worktree (rc=$x)"

# ---------------------------------------------------------------------------
# AC5 — drift is detected and fixed.
# ---------------------------------------------------------------------------
R="$T/repo-d1"; mk "$R"; st "$R" --host codex-cli > /dev/null
printf 'drift\n' >> "$R/.codex/agents/shell-team-engineer.toml"
[ "$(ck "$R")" = 1 ] && pass "AC5: an appended byte makes the checker exit 1 (precondition)" || fail "AC5: drift precondition"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && [ "$(ck "$R")" = 0 ] && sec Done: "$T/o" | grep -qF .codex/agents && pass "AC5: setup restores a drifted file and names .codex/agents under Done" || fail "AC5: drifted file (rc=$x)"
rm -f "$R/.codex/agents/shell-team-pm-spec.toml"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && [ "$(ck "$R")" = 0 ] && pass "AC5: a deleted file is restored" || fail "AC5: deleted file (rc=$x)"
printf 'mine\n' > "$R/.codex/agents/my-own.toml"; cp "$R/.codex/agents/my-own.toml" "$T/own"
printf 'drift\n' >> "$R/.codex/agents/shell-team-qa-verifier.toml"
st "$R" --host codex-cli > /dev/null
cmp -s "$T/own" "$R/.codex/agents/my-own.toml" && pass "AC5: an adopter's own agent file is left as found" || fail "AC5: adopter's own agent file changed"
PR2="$T/pr"; mkdir -p "$PR2"; cp -R "$REPO_ROOT/bin" "$REPO_ROOT/templates" "$PR2/"
x="$( (cd "$R" && bash "$PR2/bin/check-codex-agents.sh" --out-dir "$R/.codex/agents" > /dev/null 2>&1); printf '%s' "$?")"
[ ! -e "$PR2/agents" ] && [ "$x" = 2 ] && pass "AC5: a plugin root without agents/ makes the checker exit 2 (precondition)" || fail "AC5: exit-2 precondition (rc=$x)"
A0="$(mktemp -d "$T/a0.XXXXXX")"; cp -R "$R/.codex/agents/." "$A0/"
x="$( (cd "$R" && PATH="$SP" bash "$PR2/bin/team-setup.sh" --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" = 2 ] && diff -r "$A0" "$R/.codex/agents" > /dev/null && pass "AC5: checker exit 2 makes setup exit 2 with .codex/agents byte-identical" || fail "AC5: checker exit 2 (rc=$x)"
R="$T/repo-d2"; mk "$R"
x="$( (cd "$R" && PATH="$SP" bash "$PR2/bin/team-setup.sh" --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
[ "$x" != 0 ] && [ -z "$(find "$R/.codex" -name '*.toml' -print 2>/dev/null)" ] && pass "AC5: a first run against a source that cannot regenerate fails and writes no role file" || fail "AC5: first run, unusable source (rc=$x)"

# ---------------------------------------------------------------------------
# AC6 — a refused write becomes one exact single-artifact command.
# ---------------------------------------------------------------------------
if [ "$is_root" -eq 1 ]; then
  printf 'SKIP: AC6 permission cases (running as root: a permission fixture is meaningless)\n'
else
  R="$T/repo-r w"; mk "$R"; X="$R/.git/info/exclude"; mkdir -p "$R/.git/info"; printf '# keep\n' > "$X"; cp "$X" "$T/x0"
  chmod 444 "$X"; chmod 555 "$R/.git/info"
  x="$(st "$R" --host codex-cli)"
  chmod 755 "$R/.git/info"; chmod 644 "$X"
  [ "$x" = 3 ] && cmp -s "$T/x0" "$X" && [ -s "$R/.shell-team/todo.md" ] && [ "$(ck "$R")" = 0 ] && pass "AC6: a read-only exclude exits 3, stays byte-identical, the rest lands" || fail "AC6: read-only exclude (rc=$x)"
  sec "$RM" "$T/o" | grep '^- run yourself: ' > "$T/c" || true
  [ "$(grep -c . "$T/c")" = 1 ] && pass "AC6: exactly one run-yourself line for the exclude" || fail "AC6: run-yourself line count"
  C="$(sed 's/^- run yourself: //' "$T/c")"
  printf '%s\n' "$C" | grep -qF -- "$X" && pass "AC6: the command names the exclude path" || fail "AC6: command does not name the exclude path"
  (cd "$R" && bash -c "$C") > /dev/null 2>&1 && [ "$(cnt .codex/agents "$X")" = 1 ] && [ "$(head -n 1 "$X")" = '# keep' ] && pass "AC6: the printed command, run via bash -c, appends one line and keeps # keep first" || fail "AC6: printed exclude command"
  # The same, for an exclude that lacks a trailing newline.
  R="$T/repo-r n"; mk "$R"; X="$R/.git/info/exclude"; mkdir -p "$R/.git/info"; printf '# keep' > "$X"
  chmod 444 "$X"; chmod 555 "$R/.git/info"
  x="$(st "$R" --host codex-cli)"
  chmod 755 "$R/.git/info"; chmod 644 "$X"
  C="$(sec "$RM" "$T/o" | sed -n 's/^- run yourself: //p')"
  (cd "$R" && bash -c "$C") > /dev/null 2>&1 && [ "$(head -n 1 "$X")" = '# keep' ] && [ "$(cnt .codex/agents "$X")" = 1 ] && [ "$x" = 3 ] && pass "AC6: the printed command restores the line break before its own line" || fail "AC6: printed command, no trailing newline (rc=$x)"
  R="$T/repo-r2"; mk "$R"; mkdir -p "$R/.codex"; chmod 555 "$R/.codex"
  x="$(st "$R" --host codex-cli)"
  chmod 755 "$R/.codex"
  [ "$x" = 3 ] && [ "$(cnt .codex/agents "$R/.git/info/exclude")" = 1 ] && pass "AC6: a read-only .codex exits 3 and the exclude line still lands" || fail "AC6: read-only .codex (rc=$x)"
  sec "$RM" "$T/o" | grep '^- run yourself: ' > "$T/c" || true
  C="$(sed 's/^- run yourself: //' "$T/c")"
  [ "$(grep -c . "$T/c")" = 1 ] && printf '%s\n' "$C" | grep -qF gen-codex-agents.sh && printf '%s\n' "$C" | grep -qF -- "$R/.codex/agents" && pass "AC6: one line naming gen-codex-agents.sh and the agents dir" || fail "AC6: agents run-yourself line"
  (cd "$R" && bash -c "$C") > /dev/null 2>&1 && [ "$(ck "$R")" = 0 ] && pass "AC6: running the printed generator command makes the agents check clean" || fail "AC6: printed generator command"
  # Exit precedence: a refused write (3) outranks a missing CLI (1).
  R="$T/repo-r3"; mk "$R"; mkdir -p "$R/.codex"; chmod 555 "$R/.codex"; mkdir -p "$T/e0"
  x="$( (cd "$R" && PATH="$T/e0:/usr/bin:/bin" "$BASH" "$S" --host codex-cli < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
  chmod 755 "$R/.codex"
  [ "$x" = 3 ] && pass "exit precedence: a refused write (3) outranks a missing CLI (1)" || fail "exit precedence 3 over 1 (rc=$x)"
fi

# ---------------------------------------------------------------------------
# AC7 — prerequisites are reported and never met or probed.
# ---------------------------------------------------------------------------
mkdir -p "$T/e0" "$T/p"
NP="$T/e0:/usr/bin:/bin"
if ! (PATH="$NP"; command -v git > /dev/null 2>&1) || (PATH="$NP"; command -v claude > /dev/null 2>&1 || command -v codex > /dev/null 2>&1); then
  printf 'SKIP: AC7 (PATH %s does not resolve git without claude/codex on this machine)\n' "$NP"
else
  nr() { local d="$1" r=0; shift; (cd "$d" && PATH="$NP" "$BASH" "$S" "$@" < /dev/null > "$T/o" 2> "$T/e") || r=$?; printf '%s' "$r"; }
  R="$T/repo-c1"; mk "$R"
  x="$(nr "$R" --host codex-cli)"
  [ "$x" = 1 ] && sec "$RM" "$T/o" | grep -F 'command -v claude' | grep -qF review && [ "$(ck "$R")" = 0 ] && [ "$(cnt .codex/agents "$R/.git/info/exclude")" = 1 ] \
    && pass "AC7: codex-cli without claude exits 1, names command -v claude and review, still completes" || fail "AC7: codex-cli without claude (rc=$x)"
  R="$T/repo-c2"; mk "$R"
  x="$(nr "$R" --host claude-code)"
  [ "$x" = 1 ] && sec "$RM" "$T/o" | grep -F 'command -v codex' | grep -qF review && [ -s "$R/.shell-team/todo.md" ] \
    && pass "AC7: claude-code without codex exits 1, names command -v codex and review, board lands" || fail "AC7: claude-code without codex (rc=$x)"
  [ -z "$(find "$T/e0" -mindepth 1 -print)" ] && pass "AC7: nothing was created in the empty PATH directory" || fail "AC7: the empty PATH directory is not empty"
fi
export PROBE="$T/called"
for b in claude codex; do
  printf '%s\n' '#!/usr/bin/env bash' 'touch "$PROBE"' 'exit 0' > "$T/p/$b"
  chmod +x "$T/p/$b"
done
SP_SAVE="$SP"; SP="$T/p:$PATH"
R="$T/repo-c3"; mk "$R"
x="$(st "$R" --host codex-cli)"
[ "$x" = 0 ] && sec 'Already in place:' "$T/o" | grep -qF claude && sec "$RM" "$T/o" | grep -qF 'claude -p "reply with the single word ok"' \
  && pass "AC7: codex-cli with a stub claude exits 0, lists it, and prints the operator's own check" || fail "AC7: codex-cli with stub claude (rc=$x)"
R="$T/repo-c4"; mk "$R"
x="$(st "$R" --host claude-code)"
[ "$x" = 0 ] && sec 'Already in place:' "$T/o" | grep -qF codex && pass "AC7: claude-code with a stub codex exits 0 and lists it" || fail "AC7: claude-code with stub codex (rc=$x)"
[ ! -e "$PROBE" ] && pass "AC7: neither stub CLI was ever invoked" || fail "AC7: a stub CLI was invoked"
SP="$SP_SAVE"

# ---------------------------------------------------------------------------
# AC8 — the report's shape (T-1174: five sections) and the host-side conditions.
# ---------------------------------------------------------------------------
for h in codex-cli claude-code; do
  R="$T/repo-rp-$h"; mk "$R"
  x="$(st "$R" --host "$h")"
  good=1
  for k in 'Done:' 'Already in place:' "$RM" 'Required:' 'Notice:'; do
    [ "$(cnt "$k" "$T/o")" = 1 ] || good=0
  done
  prev=1
  for k in 'Done:' 'Already in place:' "$RM" 'Required:' 'Notice:'; do
    ln="$(grep -nxF -- "$k" "$T/o" | head -n 1 | cut -d: -f1)"
    if [ -z "$ln" ] || [ "$ln" -le "$prev" ]; then good=0; else prev="$ln"; fi
    s_="$(sec "$k" "$T/o")"
    [ -n "$s_" ] && [ -z "$(printf '%s\n' "$s_" | grep -v '^- ' || true)" ] || good=0
  done
  [ "$(sed -n 2p "$T/o")" = 'Done:' ] || good=0
  [ "$(grep -v '^- ' "$T/o" | grep -c .)" = 6 ] || good=0
  [ "$(sec Required: "$T/o")" != '- none' ] || good=0
  sec "$RM" "$T/o" > "$T/m-$h"
  sec 'Notice:' "$T/o" > "$T/n-$h"
  [ "$(wc -l < "$T/n-$h" | tr -d ' ')" = 1 ] && grep -qF 'sends repository content to' "$T/n-$h" || good=0
  g=0; grep -qiE 'decision|approv|authori' "$T/n-$h" || g=$?; [ "$g" -eq 1 ] || good=0
  awk '$0=="Notice:"{exit} {print}' "$T/o" > "$T/pre-$h"
  g=0; grep -qiE 'transfer|repository content' "$T/pre-$h" || g=$?; [ "$g" -eq 1 ] || good=0
  [ "$x" = 0 ] && [ "$good" -eq 1 ] && pass "AC8 $h: exit 0 (Required and Notice never change it), five sections once each in order, six non-item lines, Done on line 2, the notice is one information line" || fail "AC8 $h: report shape (rc=$x)"
done
grep -qF Codex "$T/n-claude-code" && grep -qF OpenAI "$T/n-claude-code" && grep -qF Claude "$T/n-codex-cli" && grep -qF Anthropic "$T/n-codex-cli" \
  && pass "AC8: the notice names the other provider on each host" || fail "AC8: notice provider names"
w_ok=1
for w in trust network PATH commit; do grep -qF -- "$w" "$T/m-codex-cli" || { w_ok=0; printf 'missing word %s (codex-cli)\n' "$w" >&2; }; done
for w in sandbox 'codex exec' commit 'could not determine'; do grep -qF -- "$w" "$T/m-claude-code" || { w_ok=0; printf 'missing word %s (claude-code)\n' "$w" >&2; }; done
[ "$w_ok" -eq 1 ] && pass "AC8: the host-side condition lines name their subjects" || fail "AC8: host-side condition words"
bash "$S" --help > "$T/help" 2> "$T/helpe"
hk=1
for k in 'Done:' 'Already in place:' "$RM" 'Required:' 'Notice:'; do
  awk -v k="$k" '{s=$0; sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); if(s==k) f=1} END{exit !f}' "$T/help" || hk=0
done
[ "$hk" -eq 1 ] && pass "AC8: --help names the five headings, one per line" || fail "AC8: --help headings"
# Codex CLI host: the four host lines keep their wording, no sandbox line, no transfer line outside Notice.
c_ok=1
for p in '- repository trust: project agents' '- commits: the loop'"'"'s roles commit inside this repository through one invocation of bin/team-commit.sh' '- network for the review pass: the review'"'"'s claude -p call' '- PATH: spawned roles call the plugin'"'"'s scripts by bare name'; do
  [ "$(grep -cF -- "$p" "$T/m-codex-cli")" = 1 ] || { c_ok=0; printf 'missing codex line: %s\n' "$p" >&2; }
done
R="$T/repo-cx"; mk "$R"; st "$R" --host codex-cli > /dev/null
grep -q '^- sandbox' "$T/o" && c_ok=0
[ "$(sec "$RM" "$T/o" | grep -c '^- base directory')" = 0 ] || c_ok=0
[ "$c_ok" -eq 1 ] && pass "AC8: on the Codex CLI host the trust, commits, network and PATH lines keep their wording and no sandbox line appears" || fail "AC8: codex-cli host lines"

# ---------------------------------------------------------------------------
# T-1174 — the base directory in git (Required / Already in place).
# ---------------------------------------------------------------------------
BQ="$(printf '\140')"
bl() { grep '^- base directory in git: ' || true; }
rl() { { grep -o "$BQ![^$BQ]*$BQ" || true; } | tr -d "$BQ"; }
ga() { { grep -o "${BQ}git add [^$BQ]*$BQ" || true; } | tr -d "$BQ"; }
gv() { printf '%s\n' "$1" | grep -qxE "git add -- '[^']+'( '[^']+')*"; }
cm() { git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m s; }
gcf() { printf '%s\n' "$2" > "$T/gx-$1"; printf '[core]\n\texcludesFile = %s\n' "$T/gx-$1" > "$T/gc-$1"; }
stg() { local gc="$1" d="$2"; shift 2; (export GIT_CONFIG_GLOBAL="$gc"; st "$d" "$@"); }
no() { local g=0; grep -qF -- "$1" "$2" || g=$?; [ "$g" -eq 1 ]; }
# one_line <exit> <source-line> : exactly one base line under Required, naming the rule as <source>:<line>
# with no pattern after it, saying must be committed, and no backticked ! line
req_line() { # <rc> <rule>
  [ "$1" = 0 ] || return 1
  [ "$(grep -c '^- base directory in git: ' "$T/o")" = 1 ] || return 1
  L="$(sec Required: "$T/o" | bl)"; [ -n "$L" ] || return 1
  printf '%s\n' "$L" | grep -qF 'must be committed' || return 1
  printf '%s\n' "$L" | grep -qF -- "$2" || return 1
  no "$2:" <(printf '%s\n' "$L")
}
for h in claude-code codex-cli; do
  R="$T/repo-bd-$h"; mk "$R"
  x="$(st "$R" --host "$h")"
  L="$(sec Required: "$T/o" | bl)"; C="$(printf '%s\n' "$L" | ga)"
  ok1=1
  [ "$x" = 0 ] && [ "$(grep -c '^- base directory in git: ' "$T/o")" = 1 ] && printf '%s\n' "$L" | grep -qF '.shell-team/' || ok1=0
  [ -z "$(printf '%s\n' "$L" | rl)" ] && gv "$C" && printf '%s\n' "$C" | grep -qF "'.shell-team" && ! printf '%s\n' "$C" | grep -qF .gitignore || ok1=0
  { sec "$RM" "$T/o"; sec Required: "$T/o"; sec Notice: "$T/o"; } > "$T/q3"
  no todo.md "$T/q3" && no test-recipe.md "$T/q3" || ok1=0
  [ "$ok1" -eq 1 ] && pass "T-1174 $h: a fresh uncommitted base dir is one Required line with the git add command, no re-include, no todo.md" || fail "T-1174 $h: fresh base line"
  (cd "$R" && bash -c "$C") > /dev/null 2>&1
  x="$(st "$R" --host "$h")"
  { [ "$x" = 0 ] && sec Required: "$T/o" | bl | grep -q .; } && pass "T-1174 $h: staged but not committed is still Required" || fail "T-1174 $h: staged-only (rc=$x)"
  cm "$R"
  x="$(st "$R" --host "$h")"
  { [ "$x" = 0 ] && git -C "$R" cat-file -e HEAD:.shell-team/todo.md && [ "$(sec Required: "$T/o")" = '- none' ] && sec 'Already in place:' "$T/o" | bl | grep -qF '.shell-team/'; } \
    && pass "T-1174 $h: once the board is in HEAD the line moves to Already in place and Required is - none" || fail "T-1174 $h: committed (rc=$x)"
done
R="$T/repo-bd-unborn"; mkdir -p "$R"; git -C "$R" init -q
x="$(st "$R" --host claude-code)"
{ [ "$x" = 0 ] && sec Required: "$T/o" | bl | grep -qF '.shell-team/'; } && pass "T-1174: an unborn HEAD counts as not committed" || fail "T-1174: unborn HEAD (rc=$x)"
# The adopter case: a global excludes file holding the directory, no re-include.
gcf a '.shell-team/'
R="$T/repo-bd-a"; mk "$R"
x="$(stg "$T/gc-a" "$R" --host claude-code)"
L="$(sec Required: "$T/o" | bl)"; C="$(printf '%s\n' "$L" | ga)"
{ req_line "$x" "$T/gx-a:1" && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ] && gv "$C" && printf '%s\n' "$C" | grep -qF "'.gitignore'"; } \
  && pass "T-1174: a global rule naming the directory prints !.shell-team/, the rule as <source>:<line> only, and a command staging .gitignore" || fail "T-1174: adopter-case line (rc=$x)"
g1=0; (export GIT_CONFIG_GLOBAL="$T/gc-a"; cd "$R" && git check-ignore -q -- .shell-team/todo.md) || g1=$?
printf '%s\n' '!.shell-team/' >> "$R/.gitignore"
g2=0; (export GIT_CONFIG_GLOBAL="$T/gc-a"; cd "$R" && git check-ignore -q -- .shell-team/todo.md) || g2=$?
(export GIT_CONFIG_GLOBAL="$T/gc-a"; cd "$R" && bash -c "$C") > /dev/null 2>&1
(export GIT_CONFIG_GLOBAL="$T/gc-a"; cm "$R")
x="$(stg "$T/gc-a" "$R" --host claude-code)"
{ [ "$g1" = 0 ] && [ "$g2" = 1 ] && git -C "$R" cat-file -e HEAD:.shell-team/todo.md && git -C "$R" show HEAD:.gitignore | grep -qxF '!.shell-team/' && [ "$x" = 0 ] && [ "$(sec Required: "$T/o")" = '- none' ]; } \
  && pass "T-1174: the printed re-include works (ignored before, not after), the command lands both files in HEAD, the re-run is - none" || fail "T-1174: re-include effect ($g1/$g2, rc=$x)"
# Every closed-set spelling, from each allowed source.
for f in '.shell-team' '.shell-team/' '/.shell-team' '/.shell-team/'; do
  gcf f "$f"
  R="$T/repo-bd-f$(printf '%s' "$f" | tr -c '[:alnum:]' '_')"; mk "$R"
  x="$(stg "$T/gc-f" "$R" --host claude-code)"
  L="$(sec Required: "$T/o" | bl)"
  { req_line "$x" "$T/gx-f:1" && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ]; } \
    && pass "T-1174: closed-set pattern '$f' from the global file prints the re-include" || fail "T-1174: closed-set pattern '$f' (rc=$x)"
done
R="$T/repo-bd-xdg"; mk "$R"; mkdir -p "$T/xdg/git"; printf '/.shell-team\n' > "$T/xdg/git/ignore"
x="$( (export XDG_CONFIG_HOME="$T/xdg"; st "$R" --host claude-code) )"
L="$(sec Required: "$T/o" | bl)"
{ req_line "$x" "$T/xdg/git/ignore:1" && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ]; } && pass "T-1174: the default-location global excludes file is an allowed source" || fail "T-1174: XDG source (rc=$x)"
R="$T/repo-bd-info"; mk "$R"; mkdir -p "$R/.git/info"; printf '.shell-team\n' > "$R/.git/info/exclude"
x="$(st "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"
{ req_line "$x" '.git/info/exclude:1' && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ]; } && pass "T-1174: info/exclude is an allowed source" || fail "T-1174: info/exclude (rc=$x)"
M="$T/bd-m"; W="$T/bd-w"; mk "$M"; git -C "$M" worktree add -q "$W" > /dev/null 2>&1
mkdir -p "$M/.git/info"; printf '/.shell-team/\n' > "$M/.git/info/exclude"
x="$(st "$W" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"
{ req_line "$x" "$M/.git/info/exclude:1" && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ]; } && pass "T-1174: a linked worktree reads the common info/exclude" || fail "T-1174: worktree source (rc=$x)"
# Outside the closed set: the rule is named, never its pattern, and no re-include is printed.
nore() { # <label> <rule-needle> <fixture setup done, rc>
  local x="$3"
  { req_line "$x" "$2" && [ -z "$(printf '%s\n' "$L" | rl)" ]; } && pass "T-1174: $1 — Required names the rule, no re-include" || fail "T-1174: $1 (rc=$x)"
}
gcf p 'work/'
R="$T/repo-bd-p"; mk "$R"; x="$( (export TEAM_RUN_BASE=work/st; stg "$T/gc-p" "$R" --host claude-code) )"
nore "a parent's rule (nested TEAM_RUN_BASE)" "$T/gx-p:1" "$x"; printf '%s\n' "$L" | grep -qF 'work/st' && pass "T-1174: the nested base directory is named" || fail "T-1174: nested base not named"
R="$T/repo-bd-rg"; mk "$R"; printf '.shell-team/\n' > "$R/.gitignore"; git -C "$R" add .gitignore; cm "$R"
x="$(st "$R" --host claude-code)"; nore "the repository's own .gitignore" '.gitignore:1' "$x"
gcf w '*'; R="$T/repo-bd-w"; mk "$R"; x="$(stg "$T/gc-w" "$R" --host claude-code)"; nore "a wildcard matching everything" "$T/gx-w:1" "$x"
R="$T/repo-bd-wt"; mk "$R"; st "$R" --host claude-code > /dev/null; git -C "$R" add -- .shell-team; cm "$R"
x="$(stg "$T/gc-w" "$R" --host claude-code)"; nore "a tracked board under a later wildcard" "$T/gx-w:1" "$x"
gcf s '.shell-*'; R="$T/repo-bd-s"; mk "$R"; x="$(stg "$T/gc-s" "$R" --host claude-code)"; nore "a name-prefix wildcard" "$T/gx-s:1" "$x"
no '.shell-*' <(printf '%s\n' "$L") && pass "T-1174: the wildcard pattern text is not printed" || fail "T-1174: wildcard pattern text printed"
E="$(printf '\033')"; R="$T/repo-bd-bx"; mk "$R"; printf '%s\n' ".shell-tea[mX INJECTED TEXT $E]" > "$R/.gitignore"; git -C "$R" add .gitignore; cm "$R"
x="$(st "$R" --host claude-code)"; nore "an untrusted bracket pattern" '.gitignore:1' "$x"
bx=1; for wd in "$E" 'INJECTED TEXT' 'tea['; do for f in "$T/o" "$T/e"; do no "$wd" "$f" || bx=0; done; done
[ "$bx" -eq 1 ] && pass "T-1174: neither the ESC byte nor the pattern text reaches stdout or stderr" || fail "T-1174: untrusted pattern text printed"
gcf m '*.md'; R="$T/repo-bd-m"; mk "$R"; x="$(stg "$T/gc-m" "$R" --host claude-code)"; nore "files ignored, directory not" "$T/gx-m:1" "$x"
C="$(printf '%s\n' "$L" | ga)"
{ printf '%s\n' "$L" | grep -qF '.shell-team/todo.md' && no '*.md' <(printf '%s\n' "$L") && gv "$C"; } && pass "T-1174: the ignored board path is named, not the pattern; the command is valid" || fail "T-1174: *.md line"
: > "$T/gx-m"; (export GIT_CONFIG_GLOBAL="$T/gc-m"; cd "$R" && bash -c "$C") > /dev/null 2>&1; (export GIT_CONFIG_GLOBAL="$T/gc-m"; cm "$R")
git -C "$R" cat-file -e HEAD:.shell-team/todo.md && pass "T-1174: after the operator drops the rule the command lands the board in HEAD" || fail "T-1174: board not in HEAD"
# Source spellings: a colon in the path, a ~ value, a non-ASCII path.
mkdir -p "$T/c:d"; printf '.shell-team/\n' > "$T/c:d/gx"; printf '[core]\n\texcludesFile = %s\n' "$T/c:d/gx" > "$T/gc-colon"
R="$T/repo-bd-colon"; mk "$R"; x="$(stg "$T/gc-colon" "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"
{ req_line "$x" "$T/c:d/gx:1" && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ]; } && pass "T-1174: a colon inside the source path does not shift the line number" || fail "T-1174: colon source (rc=$x)"
printf '.shell-team/\n' > "$HOME/gx-t"; printf '[core]\n\texcludesFile = ~/gx-t\n' > "$T/gc-tilde"
R="$T/repo-bd-tilde"; mk "$R"; x="$(stg "$T/gc-tilde" "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"
{ [ "$x" = 0 ] && [ "$(printf '%s\n' "$L" | rl)" = '!.shell-team/' ] && no 'gx-t:1:' <(printf '%s\n' "$L"); } && pass "T-1174: a ~ excludes-file value is an allowed source" || fail "T-1174: tilde source (rc=$x)"
U="$(printf 'n\303\251')"; mkdir -p "$T/$U"; printf '.shell-team/\n' > "$T/$U/gx"; printf '[core]\n\texcludesFile = %s\n' "$T/$U/gx" > "$T/gc-u"
R="$T/repo-bd-u"; mk "$R"; x="$(stg "$T/gc-u" "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"
{ [ "$x" = 0 ] && printf '%s\n' "$L" | grep -qF '<unprintable source>:1' && no '<unprintable source>:1:' <(printf '%s\n' "$L") && no "$U" "$T/o"; } && pass "T-1174: a non-ASCII source is printed as <unprintable source>:<line>" || fail "T-1174: non-ASCII source (rc=$x)"
# Legacy layout: an outside specs directory is its own required directory.
lg() { mk "$1" && mkdir -p "$1/tasks/loops" "$1/.git/info" && cp "$REPO_ROOT/templates/shell-team.contract.yaml" "$1/tasks/loops/"; }
R="$T/repo-bd-lg"; lg "$R"
BS="$(cd "$R" && bash "$REPO_ROOT/bin/team-paths.sh" --get base)"; SPD="$(cd "$R" && bash "$REPO_ROOT/bin/team-paths.sh" --get specs)"
: > "$R/.git/info/exclude"; printf '%s/\n' "$SPD" >> "$R/.git/info/exclude"
x="$(st "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"; C="$(printf '%s\n' "$L" | ga)"
{ [ "$x" = 0 ] && printf '%s\n' "$L" | grep -qF -- "$SPD/" && printf '%s\n' "$L" | grep -qF '.git/info/exclude:1' && no '.git/info/exclude:1:' <(printf '%s\n' "$L") \
  && [ "$(printf '%s\n' "$L" | rl)" = "!$SPD/" ] && gv "$C" && printf '%s\n' "$C" | grep -qF "'.gitignore'" && printf '%s\n' "$C" | grep -qF -- "'$BS" && printf '%s\n' "$C" | grep -qF -- "'$SPD"; } \
  && pass "T-1174: an ignored outside specs directory gets its own re-include and the command names both directories" || fail "T-1174: legacy specs ignored (rc=$x)"
printf '!%s/\n' "$SPD" >> "$R/.gitignore"; (cd "$R" && bash -c "$C") > /dev/null 2>&1; cm "$R"
x="$(st "$R" --host claude-code)"
{ [ "$x" = 0 ] && git -C "$R" cat-file -e "HEAD:$SPD/.gitkeep" && git -C "$R" cat-file -e "HEAD:$BS/todo.md" && [ "$(sec Required: "$T/o")" = '- none' ]; } && pass "T-1174: committing both directories empties Required" || fail "T-1174: legacy committed (rc=$x)"
R="$T/repo-bd-lm"; lg "$R"; st "$R" --host claude-code > /dev/null; git -C "$R" add -- "$BS"; cm "$R"
x="$(st "$R" --host claude-code)"; L="$(sec Required: "$T/o" | bl)"; C="$(printf '%s\n' "$L" | ga)"
{ [ "$x" = 0 ] && printf '%s\n' "$L" | grep -qF -- "$SPD/" && gv "$C" && printf '%s\n' "$C" | grep -qF -- "'$SPD" && ! printf '%s\n' "$C" | grep -qE -- "'$BS/?'"; } && pass "T-1174: base committed, specs untracked: the command names the specs directory only" || fail "T-1174: legacy specs untracked (rc=$x)"
git -C "$R" add -- "$SPD"; x="$(st "$R" --host claude-code)"
{ [ "$x" = 0 ] && sec Required: "$T/o" | bl | grep -qF -- "$SPD/"; } && pass "T-1174: a staged-only specs anchor is still Required" || fail "T-1174: legacy specs staged (rc=$x)"
# A git check-ignore failure is a setup error (exit 2), not a quiet pass: a bare stub git that fails check-ignore.
mkdir -p "$T/gs"; printf '%s\n' '#!/usr/bin/env bash' 'for a in "$@"; do if [ "$a" = check-ignore ]; then exit 128; fi; done' "exec $(command -v git) \"\$@\"" > "$T/gs/git"; chmod +x "$T/gs/git"
R="$T/repo-bd-err"; mk "$R"
x="$( (cd "$R" && PATH="$T/gs:$SP" bash "$S" --host claude-code < /dev/null > "$T/o" 2> "$T/e"); printf '%s' "$?")"
{ [ "$x" = 2 ] && grep -qF 'check-ignore' "$T/e" && ! grep -q '^- base directory in git: ' "$T/o"; } && pass "T-1174: a check-ignore exit above 1 exits 2 with a stderr diagnostic and prints no base line" || fail "T-1174: check-ignore error (rc=$x)"

# ---------------------------------------------------------------------------
# T-1174 — the settings reader (Claude Code host): report what was read, never more.
# ---------------------------------------------------------------------------
TP=' has "codex *" in sandbox.excludedCommands; whether this session applies it was not determined'
hm() { mkdir -p "$T/h-$1/.claude"; if [ "$#" -gt 1 ]; then printf '%s\n' "$2" > "$T/h-$1/.claude/settings.json"; fi; }
sx() { # <hometag> <repo>: run on the claude-code host with that home
  (export HOME="$T/h-$1"; st "$2" --host claude-code)
}
mkdir -p "$T/h-adopter/.claude"
printf '%s\n' '{' '  "permissions": {' '    "allow": ["Bash(codex *)"]' '  },' '  "sandbox": {' '    "enabled": true,' '    "network": { "allowLocalBinding": true },' '    "excludedCommands": [' '      "docker *",' '      "codex *"' '    ]' '  }' '}' > "$T/h-adopter/.claude/settings.json"
R="$T/repo-sb-a"; mk "$R"; x="$( (export GIT_CONFIG_GLOBAL="$T/gc-a"; sx adopter "$R") )"
sec 'Already in place:' "$T/o" | grep '^- sandbox: ' > "$T/al" || true
sec "$RM" "$T/o" > "$T/m"
{ [ "$x" = 0 ] && [ "$(grep -c . "$T/al")" = 1 ] && [ "$(cat "$T/al")" = "- sandbox: $T/h-adopter/.claude/settings.json$TP" ] && ! grep -q '^- sandbox' "$T/m" \
  && [ "$(grep -c '^- ' "$T/m")" = 1 ] && grep -q '^- commits: ' "$T/m" && [ "$(sec Required: "$T/o" | bl | rl)" = '!.shell-team/' ] && [ "$(sec Notice: "$T/o" | grep -c .)" = 1 ]; } \
  && pass "T-1174: the adopter case ends with one open item (commits), the fixed sandbox line in place, !.shell-team/ and one notice" || fail "T-1174: adopter case (rc=$x)"
R="$T/repo-sb-l"; mk "$R"; mkdir -p "$R/.claude"; printf '%s\n' '{"sandbox":{"excludedCommands":["codex *"]}}' > "$R/.claude/settings.local.json"; hm none
x="$(sx none "$R")"
{ [ "$x" = 0 ] && [ "$(sec 'Already in place:' "$T/o" | grep '^- sandbox: ')" = "- sandbox: $R/.claude/settings.local.json$TP" ]; } && pass "T-1174: the local scope (one-line JSON) is read, with the physical repository path" || fail "T-1174: local scope (rc=$x)"
R="$T/repo-sb-p"; mk "$R"; mkdir -p "$R/.claude"; printf '%s\n' '{' '  "model": "x",' '  "sandbox": {' '    "excludedCommands": ["codex *"]' '  }' '}' > "$R/.claude/settings.json"
x="$(sx none "$R")"
{ [ "$x" = 0 ] && [ "$(sec 'Already in place:' "$T/o" | grep '^- sandbox: ')" = "- sandbox: $R/.claude/settings.json$TP" ]; } && pass "T-1174: the project scope (pretty-printed, another key) is read" || fail "T-1174: project scope (rc=$x)"
ln -s "$T/h-adopter" "$T/h-link"; R="$T/repo-sb-h"; mk "$R"; x="$(sx link "$R")"
{ [ "$x" = 0 ] && [ "$(sec 'Already in place:' "$T/o" | grep '^- sandbox: ')" = "- sandbox: $T/h-link/.claude/settings.json$TP" ]; } && pass "T-1174: a symlinked HOME is named as given" || fail "T-1174: symlinked HOME (rc=$x)"
R="$T/repo-sb-x"; mk "$R"; x="$( (export HOME="$T/h-adopter"; st "$R" --host codex-cli) )"
{ [ "$x" = 0 ] && ! grep -q '^- sandbox' "$T/o"; } && pass "T-1174: the Codex CLI host prints no sandbox line even with user settings" || fail "T-1174: codex-cli sandbox line (rc=$x)"
# Honesty: anything unrecognised is "could not determine", never in place and never "not met".
und() { # <tag> <json> [env assignment...]
  local tag="$1" json="$2" ccd="${3:-}" x R="$T/repo-sb-u-$1"
  hm "$tag" "$json"; mk "$R"
  x="$( (export HOME="$T/h-$tag"; if [ -n "$ccd" ]; then export CLAUDE_CONFIG_DIR="$ccd"; fi; st "$R" --host claude-code) )"
  sec 'Already in place:' "$T/o" > "$T/ip"
  sec "$RM" "$T/o" | grep '^- sandbox: ' > "$T/sl" || true
  local g=0; grep -qi 'not met' "$T/o" || g=$?
  { [ "$x" = 0 ] && ! grep -q '^- sandbox' "$T/ip" && [ "$(grep -c . "$T/sl")" = 1 ] && grep -qF 'could not determine' "$T/sl" && grep -qF 'codex exec' "$T/sl" && [ "$g" -eq 1 ]; } \
    && pass "T-1174 honesty: $tag is undetermined, not in place, never 'not met'" || fail "T-1174 honesty: $tag (rc=$x)"
}
V='{"sandbox":{"excludedCommands":["codex *"]}}'
und trunc '{"sandbox":{"excludedCommands":["codex *"'
und comma '{"sandbox":{"excludedCommands":["codex *",]}}'
und objcomma '{"sandbox":{"excludedCommands":["codex *"],}}'
und dupsb '{"sandbox":{},"sandbox":{"excludedCommands":["codex *"]}}'
und perm '{"permissions":{"allow":["Bash(codex *)"]}}'
und nest '{"sandbox":{"network":{"excludedCommands":["codex *"]}}}'
und dupex '{"sandbox":{"excludedCommands":["git *"],"excludedCommands":["codex *"]}}'
und bothex '{"sandbox":{"excludedCommands":["codex *"],"network":{"excludedCommands":["git *"]}}}'
und spell '{"sandbox":{"excludedCommands":["codex"]}}'
und strty '{"sandbox":{"excludedCommands":"codex *"}}'
und valuekey '{"sandbox":{"excludedCommands":["x"],"note":"codex *"}}'
und nestedarr '{"sandbox":{"excludedCommands":[["codex *"]]}}'
und sbstr '{"sandbox":"excludedCommands codex *"}'
und notobj '["sandbox"]'
und empty ''
und bom "$(printf '\357\273\277')$V"
und trailing "$V x"
und badnum '{"a":01,"sandbox":{"excludedCommands":["codex *"]}}'
und badesc '{"sandbox":{"excludedCommands":["codex *","\q"]}}'
und ctrl "$(printf '{"sandbox":{"excludedCommands":["codex *","a\tb"]}}')"
und ccd "$V" "$T/ccd"
if [ "$is_root" -eq 0 ]; then
  hm unr "$V"; chmod 000 "$T/h-unr/.claude/settings.json"; R="$T/repo-sb-unr"; mk "$R"
  x="$(sx unr "$R")"; chmod 644 "$T/h-unr/.claude/settings.json"
  sec "$RM" "$T/o" | grep '^- sandbox: ' > "$T/sl" || true
  { [ "$x" = 0 ] && grep -qF 'could not determine' "$T/sl" && ! sec 'Already in place:' "$T/o" | grep -q '^- sandbox'; } && pass "T-1174 honesty: an unreadable settings file is undetermined" || fail "T-1174 honesty: unreadable (rc=$x)"
fi
printf 'a\0b' > "$T/nul.json"; hm nul; cp "$T/nul.json" "$T/h-nul/.claude/settings.json"
R="$T/repo-sb-nul"; mk "$R"; x="$(sx nul "$R")"
{ [ "$x" = 0 ] && ! sec 'Already in place:' "$T/o" | grep -q '^- sandbox'; } && pass "T-1174 honesty: a file with a NUL byte is undetermined" || fail "T-1174 honesty: NUL (rc=$x)"
# A true-positive positive control: the valid shape in one line, with an unrelated top-level key and a number first.
und_ok() { local R="$T/repo-sb-ok-$1"; hm "$1" "$2"; mk "$R"; local x; x="$(sx "$1" "$R")"
  { [ "$x" = 0 ] && sec 'Already in place:' "$T/o" | grep -q '^- sandbox: '; } && pass "T-1174 reader: $1 is recognised" || fail "T-1174 reader: $1 (rc=$x)"; }
und_ok numbers '{"n":[-1.5e+3,0,true,false,null],"sandbox":{"a":{"b":[]},"excludedCommands":["xA","codex *"]}}'
und_ok crlf "$(printf '{\r\n"sandbox":{\r\n"excludedCommands":["codex *"]\r\n}\r\n}')"

# ---------------------------------------------------------------------------
# T-1174 — the write set is unchanged by settings files and a hidden base dir.
# ---------------------------------------------------------------------------
R="$T/repo-ws2"; mk "$R"; mkdir -p "$R/.claude"; printf '%s\n' '{"permissions":{}}' > "$R/.claude/settings.json"
snap "$R" > "$T/r0"; snap "$HOME" > "$T/h0"; snap "$CODEX_HOME" > "$T/c0"
x="$( (export GIT_CONFIG_GLOBAL="$T/gc-a"; sx adopter "$R") )"
snap "$R" > "$T/r1"; snap "$HOME" > "$T/h1"; snap "$CODEX_HOME" > "$T/c1"
chg "$T/r0" "$T/r1" > "$T/d"; bad=0
while IFS= read -r p; do case "$p" in ./.shell-team|./.shell-team/*) ;; *) bad=1 ;; esac; done < "$T/d"
{ [ "$x" = 0 ] && cmp -s "$T/h0" "$T/h1" && cmp -s "$T/c0" "$T/c1" && [ "$bad" -eq 0 ] && grep -qxF ./.shell-team/todo.md "$T/d" && [ ! -e "$R/.gitignore" ]; } \
  && pass "T-1174: with settings files and a hidden base dir only .shell-team changes; no root .gitignore, HOME and CODEX_HOME untouched" || fail "T-1174: write set (rc=$x)"

# ---------------------------------------------------------------------------
# AC9 — the upgrade-report layer: version, and template drift as a report.
# ---------------------------------------------------------------------------
V="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO_ROOT/.claude-plugin/plugin.json" | head -n 1)"
R="$T/repo-u1"; mk "$R"
x="$(st "$R" --host claude-code)"
[ -n "$V" ] && head -n 1 "$T/o" | grep -qF -- "$V" && pass "AC9: the header names the plugin version" || fail "AC9: header version"
grep -q 'differs from' "$T/o" && fail "AC9: a fresh scaffold must not differ from its own templates (mapping drift)" || pass "AC9: a fresh scaffold equals its templates (the template mapping matches team-init)"
printf '# local edit\n' >> "$R/.shell-team/.gitignore"; printf '\nlocal note\n' >> "$R/.shell-team/todo.md"; printf '\nlocal note\n' >> "$R/.shell-team/test-recipe.md"
for f in .gitignore todo.md test-recipe.md; do cp "$R/.shell-team/$f" "$T/k-$f"; done
x="$(st "$R" --host claude-code)"
sec "$RM" "$T/o" > "$T/m"
{ [ "$x" = 0 ] && [ "$(sec Done: "$T/o")" = '- none' ] && grep -qF .shell-team/.gitignore "$T/m" && ! grep -qF todo.md "$T/m" && ! grep -qF test-recipe.md "$T/m"; } \
  && pass "AC9: an edited base .gitignore is reported; the board and the recipe never are" || fail "AC9: edited files (rc=$x)"
kept=1; for f in .gitignore todo.md test-recipe.md; do cmp -s "$T/k-$f" "$R/.shell-team/$f" || kept=0; done
[ "$kept" -eq 1 ] && pass "AC9: all three edited files stay byte-identical" || fail "AC9: an edited file was rewritten"
for f in AGENTS.md loops/shell-team.contract.yaml binding.conf.example; do
  printf '# local\n' >> "$R/.shell-team/$f"
done
x="$(st "$R" --host claude-code)"; sec "$RM" "$T/o" > "$T/m"
{ grep -qF .shell-team/AGENTS.md "$T/m" && grep -qF .shell-team/loops/shell-team.contract.yaml "$T/m" && grep -qF .shell-team/binding.conf.example "$T/m"; } \
  && pass "AC9: each of the other mapped scaffold files is reported when edited" || fail "AC9: mapped-file coverage"

# ---------------------------------------------------------------------------
# AC10 — the forbidden-widening token lock, narrowed by T-1174 to report lines:
# the three settings tokens may appear in the script and, in stdout, only on the
# fixed `- sandbox: ` line under Already in place; the other twelve and every
# token in the skill and in stderr stay absent.
# ---------------------------------------------------------------------------
SK="$REPO_ROOT/skills/setup/SKILL.md"
[ -s "$SK" ] && grep -qF 'one concrete command' "$SK" && grep -qF team-init.sh "$S" && pass "AC10: positive controls (skill phrase, script names team-init.sh)" || fail "AC10: positive controls"
A3='excludedCommands settings.json settings.local.json'
A12='trust_level writable_roots network_access sandbox_workspace_write danger-full-access dangerously bypassPermissions --full-auto --yolo approval_policy permissions.allow config.toml'
: > "$T/ao"; : > "$T/ae"; : > "$T/allow"
tk_run() { cat "$T/o" >> "$T/ao"; cat "$T/e" >> "$T/ae"; sec 'Already in place:' "$T/o" | grep '^- sandbox: ' >> "$T/allow" || true; }
for h in codex-cli claude-code; do
  R="$T/repo-tk-$h"; mk "$R"; st "$R" --host "$h" > /dev/null; tk_run
done
R="$T/repo-tka"; mk "$R"; ( export GIT_CONFIG_GLOBAL="$T/gc-a"; sx adopter "$R" > /dev/null ); tk_run
if [ "$is_root" -eq 0 ]; then
  R="$T/repo-tkq"; mk "$R"; mkdir -p "$R/.codex"; chmod 555 "$R/.codex"; st "$R" --host codex-cli > /dev/null; chmod 755 "$R/.codex"
  tk_run
  grep -qF 'run yourself' "$T/ao" && pass "AC10: positive control (the refused-write run names run yourself)" || fail "AC10: refused-write positive control"
fi
bash "$S" --help > "$T/o" 2> "$T/e"; tk_run
grep -qF 'settings.json' "$T/allow" && pass "AC10: positive control (the allowed line names settings.json)" || fail "AC10: allowed-line positive control"
tok_ok=1
for t in $A12 $A3; do
  g=0; grep -qF -- "$t" "$SK" || g=$?
  [ "$g" -eq 1 ] || { tok_ok=0; printf 'forbidden token %s: grep status %s in the skill\n' "$t" "$g" >&2; }
  g=0; grep -qF -- "$t" "$T/ae" || g=$?
  [ "$g" -eq 1 ] || { tok_ok=0; printf 'forbidden token %s: grep status %s in stderr\n' "$t" "$g" >&2; }
done
for t in $A12; do
  for f in "$S" "$T/ao"; do
    g=0; grep -qF -- "$t" "$f" || g=$?
    [ "$g" -eq 1 ] || { tok_ok=0; printf 'forbidden token %s: grep status %s in %s\n' "$t" "$g" "$f" >&2; }
  done
done
for t in $A3; do
  g=0; grep -F -- "$t" "$T/ao" > "$T/hit" || g=$?
  [ "$g" -le 1 ] || tok_ok=0
  g=0; grep -vxF -f "$T/allow" "$T/hit" > "$T/bad" || g=$?
  [ "$g" -le 1 ] && [ ! -s "$T/bad" ] || { tok_ok=0; printf 'token %s outside the allowed line\n' "$t" >&2; }
done
while IFS= read -r l; do
  case "$l" in
    '- sandbox: /'*' has "codex *" in sandbox.excludedCommands; whether this session applies it was not determined') ;;
    *) tok_ok=0; printf 'allowed-line shape: %s\n' "$l" >&2 ;;
  esac
done < "$T/allow"
[ "$tok_ok" -eq 1 ] && pass "AC10: the twelve tokens are absent from the script, skill and all output; the three only on the fixed sandbox line; all fifteen absent from the skill and stderr" || fail "AC10: a forbidden token occurs"

# ---------------------------------------------------------------------------
# Symlinked write targets (decision 4's bound): setup refuses with exit 2 and
# writes nothing, neither in the repository nor behind the link.
# ---------------------------------------------------------------------------
# Positive control: the same layout without a symlink writes the five agents.
R="$T/repo-sl-ctl"; mk "$R"; mkdir -p "$R/.codex"
x="$(st "$R" --host codex-cli)"
n="$(find "$R/.codex/agents" -name 'shell-team-*.toml' 2>/dev/null | wc -l | tr -d ' ')"
[ "$x" = 0 ] && [ "$n" = 5 ] && pass "symlink control: a real .codex dir writes five agent files (exit $x, $n files)" || fail "symlink control: exit $x, $n files"
sl_case() { # <label> <host>
  local label="$1" host="$2" R="$T/repo-sl-$1-$2" D="$T/sl-target-$1-$2"
  mk "$R"; mkdir -p "$D"
  case "$label" in
    codex)       ln -s "$D" "$R/.codex" ;;
    codex-agents) mkdir -p "$R/.codex"; ln -s "$D" "$R/.codex/agents" ;;
    base)        ln -s "$D" "$R/.shell-team" ;;
    base-sub)    mkdir -p "$R/.shell-team"; ln -s "$D" "$R/.shell-team/runs" ;;
    info)        mv "$R/.git/info" "$R/.git/info-real"; ln -s "$D" "$R/.git/info" ;;
  esac
  snap "$R" > "$T/sl0"
  x="$(st "$R" --host "$host")"
  snap "$R" > "$T/sl1"
  [ "$x" = 2 ] && pass "symlink $label: exits 2" || fail "symlink $label: exit $x"
  [ -z "$(ls -A "$D")" ] && pass "symlink $label: the link target is still empty" || fail "symlink $label: the link target gained $(ls -A "$D")"
  cmp -s "$T/sl0" "$T/sl1" && pass "symlink $label: nothing new appeared in the repository" || fail "symlink $label: the repository changed"
  grep -qF 'symlink' "$T/e" && pass "symlink $label: stderr names the symlink" || fail "symlink $label: stderr does not name a symlink"
}
sl_case codex codex-cli
sl_case codex-agents codex-cli
sl_case base codex-cli
sl_case base claude-code
sl_case base-sub claude-code
sl_case info codex-cli

# ---------------------------------------------------------------------------
# Containment (the path checked is the path written): operating paths are read
# raw, and every write target must resolve physically inside the repository.
# ---------------------------------------------------------------------------
eb() { # <dir> <TEAM_RUN_BASE value> <host>: run setup with an override base; prints the exit status
  local d="$1" b="$2" h="$3" r=0
  (cd "$d" && TEAM_RUN_BASE="$b" PATH="$SP" bash "$S" --host "$h" < /dev/null > "$T/o" 2> "$T/e") || r=$?
  printf '%s' "$r"
}
for h in claude-code codex-cli; do
  R="$T/repo-ct1-$h"; mk "$R"; D="$T/ct1-out-$h"; mkdir -p "$D"
  ln -s "$D" "$R"'/.a$b'
  snap "$R" > "$T/c0"
  x="$(eb "$R" '.a$b' "$h")"
  snap "$R" > "$T/c1"
  { [ "$x" = 2 ] && [ -z "$(ls -A "$D")" ] && cmp -s "$T/c0" "$T/c1"; } \
    && pass "containment $h: a metacharacter base that is an outward symlink exits 2, nothing written outside or inside" \
    || fail "containment $h: metacharacter base + outward symlink (rc=$x, outside: $(ls -A "$D"))"
done
R="$T/repo-ct2"; mk "$R"
x="$(eb "$R" '.a$b' claude-code)"
{ [ "$x" = 0 ] && [ -s "$R"'/.a$b/todo.md' ] && [ -d "$R"'/.a$b/specs' ] && [ ! -e "$R/.shell-team" ]; } \
  && pass "containment control: a metacharacter base without a symlink scaffolds inside the repository" || fail "containment control: metacharacter base (rc=$x)"
R="$T/repo-ct3"; mk "$R"; D="$T/ct3-out"; mkdir -p "$D"
for b in '../ct3-out' "$D" 'a/../../ct3-out'; do
  x="$(eb "$R" "$b" claude-code)"
  { [ "$x" != 0 ] && [ -z "$(ls -A "$D")" ] && [ ! -e "$R/.shell-team" ]; } \
    && pass "containment: TEAM_RUN_BASE '$b' is refused (rc=$x), nothing written outside or inside" || fail "containment: TEAM_RUN_BASE '$b' (rc=$x)"
done
# Outward symlink at an intermediate component of a metacharacter base.
R="$T/repo-ct4"; mk "$R"; D="$T/ct4-out"; mkdir -p "$D"
ln -s "$D" "$R"'/.p$q'
x="$(eb "$R" '.p$q/inner' claude-code)"
{ [ "$x" = 2 ] && [ -z "$(ls -A "$D")" ]; } && pass "containment: an outward symlink at a parent of the base exits 2, nothing written" || fail "containment: parent symlink (rc=$x)"

# ---------------------------------------------------------------------------
# T-1166 — the new-session note on the Codex CLI host (issue #654).
# ---------------------------------------------------------------------------
nn() { grep -c '^- new Codex session: ' "$1" || true; }
R="$T/repo-ns1"; mk "$R"
x="$(st "$R" --host codex-cli)"
sec "$RM" "$T/o" > "$T/m"
grep '^- new Codex session: ' "$T/m" > "$T/n" || true
{ [ "$x" = 0 ] && sec Done: "$T/o" | grep -qF 'generated .codex/agents' && [ "$(nn "$T/o")" = 1 ] && [ "$(nn "$T/m")" = 1 ] \
  && grep -qF .codex/agents "$T/n" && grep -qF 'this repository' "$T/n" && ! grep -qF decision "$T/n"; } \
  && pass "T-1166 generated: one note line under the operator section, naming .codex/agents and this repository, free of the word decision" || fail "T-1166 generated: note (rc=$x)"
snap "$R" > "$T/ns1"; cp "$T/o" "$T/o1"
x="$(st "$R" --host codex-cli)"; cp "$T/o" "$T/o2"; snap "$R" > "$T/ns2"
{ [ "$x" = 0 ] && cmp -s "$T/ns1" "$T/ns2" && [ "$(sec Done: "$T/o2")" = '- none' ] && sec 'Already in place:' "$T/o2" | grep -qF '.codex/agents is in sync' && ! grep -qF 'new Codex session' "$T/o2"; } \
  && pass "T-1166 in-sync: a second run prints no note, leaves the tree byte-identical and Done: none" || fail "T-1166 in-sync: second run (rc=$x)"
x="$(st "$R" --host codex-cli)"
{ [ "$x" = 0 ] && cmp -s "$T/o" "$T/o2"; } && pass "T-1166 in-sync: a third run's stdout is byte-identical to the second's" || fail "T-1166 in-sync: third run differs (rc=$x)"
R="$T/repo-ns2"; mk "$R"
x="$( (export CODEX_THREAD_ID=t; st "$R") )"
{ [ "$x" = 0 ] && [ "$(nn "$T/o")" = 1 ]; } && pass "T-1166 generated: CODEX_THREAD_ID with no --host also prints one note" || fail "T-1166 generated: CODEX_THREAD_ID (rc=$x)"
R="$T/repo-ns3"; mk "$R"; st "$R" --host codex-cli > /dev/null
printf 'drift\n' >> "$R/.codex/agents/shell-team-engineer.toml"
x="$(st "$R" --host codex-cli)"
{ [ "$x" = 0 ] && sec Done: "$T/o" | grep -qF 'regenerated .codex/agents' && [ "$(nn "$T/o")" = 1 ] && [ "$(sec "$RM" "$T/o" | grep -c '^- new Codex session: ')" = 1 ]; } \
  && pass "T-1166 regenerated: a drifted file prints one note under the operator section" || fail "T-1166 regenerated: appended drift (rc=$x)"
F="$R/.codex/agents/shell-team-pm-spec.toml"; rm -f "$F"
x="$(st "$R" --host codex-cli)"
{ [ "$x" = 0 ] && [ -f "$F" ] && [ "$(nn "$T/o")" = 1 ]; } && pass "T-1166 regenerated: a deleted role file is restored and prints one note" || fail "T-1166 regenerated: deleted file (rc=$x)"
R="$T/repo-ns4"; mk "$R"; : > "$T/all"
for i in 1 2; do
  x="$(st "$R" --host claude-code)"; cat "$T/o" "$T/e" >> "$T/all"
  [ "$x" = 0 ] || fail "T-1166 claude-code: run $i exit $x"
done
{ [ ! -e "$R/.codex" ] && grep -qxF "$RM" "$T/all" && ! grep -qF 'new Codex session' "$T/all"; } \
  && pass "T-1166 claude-code: two runs print no note and create no .codex" || fail "T-1166 claude-code: note or .codex present"
if [ "$is_root" -eq 1 ]; then
  printf 'SKIP: T-1166 refused cases (running as root: a permission fixture is meaningless)\n'
else
  R="$T/repo-ns5"; mk "$R"; mkdir -p "$R/.codex"; chmod 555 "$R/.codex"
  x="$(st "$R" --host codex-cli)"; chmod 755 "$R/.codex"
  sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c" || true
  { [ "$x" = 3 ] && [ "$(grep -c . "$T/c")" = 1 ] && grep -qF gen-codex-agents.sh "$T/c" && [ "$(nn "$T/m")" = 1 ] && [ "$(nn "$T/o")" = 1 ]; } \
    && pass "T-1166 refused: a refused generator write (fresh) prints one run-yourself line and one note" || fail "T-1166 refused: fresh read-only .codex (rc=$x)"
  C="$(sed 's/^- run yourself: //' "$T/c")"
  (cd "$R" && bash -c "$C") > /dev/null 2>&1
  x="$(st "$R" --host codex-cli)"
  { [ "$x" = 0 ] && grep -qF 'in sync' "$T/o" && [ "$(nn "$T/o")" = 0 ]; } \
    && pass "T-1166 refused: after the printed command ran, the re-run is in sync with no note" || fail "T-1166 refused: re-run (rc=$x)"
  R="$T/repo-ns6"; mk "$R"; st "$R" --host codex-cli > /dev/null
  rm -f "$R/.codex/agents/shell-team-pm-spec.toml"; chmod 555 "$R/.codex/agents"
  x="$(st "$R" --host codex-cli)"; chmod 755 "$R/.codex/agents"
  sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c" || true
  { [ "$x" = 3 ] && [ "$(grep -c . "$T/c")" = 1 ] && grep -qF gen-codex-agents.sh "$T/c" && [ "$(nn "$T/m")" = 1 ]; } \
    && pass "T-1166 refused: a drifted, non-writable agents dir prints one run-yourself line and one note" || fail "T-1166 refused: drifted read-only agents (rc=$x)"
  R="$T/repo-ns7"; mk "$R"; st "$R" --host codex-cli > /dev/null
  X="$R/.git/info/exclude"; printf '# keep\n' > "$X"; chmod 444 "$X"; chmod 555 "$R/.git/info"
  x="$(st "$R" --host codex-cli)"; chmod 755 "$R/.git/info"; chmod 644 "$X"
  sec "$RM" "$T/o" > "$T/m"; grep '^- run yourself: ' "$T/m" > "$T/c" || true
  { [ "$x" = 3 ] && [ "$(grep -c . "$T/c")" = 1 ] && grep -qF exclude "$T/c" && ! grep -qF gen-codex-agents.sh "$T/c" && [ "$(nn "$T/o")" = 0 ]; } \
    && pass "T-1166 refused: a refused exclude write alone prints no note" || fail "T-1166 refused: exclude only (rc=$x)"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'setup suite: all assertions passed\n'
else
  printf 'setup suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
