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
sec() { awk -v h="$1" -v a='Done:' -v b='Already in place:' -v c="$RM" '$0==a||$0==b||$0==c{f=($0==h);next} f' "$2"; }
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
# AC8 — the report's shape and the host-side conditions.
# ---------------------------------------------------------------------------
for h in codex-cli claude-code; do
  R="$T/repo-rp-$h"; mk "$R"
  x="$(st "$R" --host "$h")"
  good=1
  for k in 'Done:' 'Already in place:' "$RM"; do
    [ "$(cnt "$k" "$T/o")" = 1 ] || good=0
  done
  a="$(grep -nxF 'Done:' "$T/o" | cut -d: -f1)"; b="$(grep -nxF 'Already in place:' "$T/o" | cut -d: -f1)"; c="$(grep -nxF -- "$RM" "$T/o" | cut -d: -f1)"
  { [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ 1 -lt "$a" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ]; } || good=0
  [ "$(grep -v '^- ' "$T/o" | grep -c .)" = 4 ] || good=0
  sec "$RM" "$T/o" > "$T/m-$h"
  grep -qF 'sends repository content to' "$T/m-$h" || good=0
  [ "$x" = 0 ] && [ "$good" -eq 1 ] && pass "AC8 $h: exit 0, three sections once each in order, four non-item lines, review-transfer line" || fail "AC8 $h: report shape (rc=$x)"
done
w_ok=1
for w in trust network PATH commit; do grep -qF -- "$w" "$T/m-codex-cli" || { w_ok=0; printf 'missing word %s (codex-cli)\n' "$w" >&2; }; done
for w in sandbox 'codex exec' commit; do grep -qF -- "$w" "$T/m-claude-code" || { w_ok=0; printf 'missing word %s (claude-code)\n' "$w" >&2; }; done
[ "$w_ok" -eq 1 ] && pass "AC8: the host-side condition lines name their subjects" || fail "AC8: host-side condition words"

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
# AC10 — the forbidden-widening token lock (script, skill, and run output).
# ---------------------------------------------------------------------------
SK="$REPO_ROOT/skills/setup/SKILL.md"
[ -s "$SK" ] && grep -qF 'one concrete command' "$SK" && grep -qF team-init.sh "$S" && pass "AC10: positive controls (skill phrase, script names team-init.sh)" || fail "AC10: positive controls"
: > "$T/all"
for h in codex-cli claude-code; do
  R="$T/repo-tk-$h"; mk "$R"; st "$R" --host "$h" > /dev/null; cat "$T/o" "$T/e" >> "$T/all"
done
if [ "$is_root" -eq 0 ]; then
  R="$T/repo-tkq"; mk "$R"; mkdir -p "$R/.codex"; chmod 555 "$R/.codex"; st "$R" --host codex-cli > /dev/null; chmod 755 "$R/.codex"
  cat "$T/o" "$T/e" >> "$T/all"
  grep -qF 'run yourself' "$T/all" && pass "AC10: positive control (the refused-write run names run yourself)" || fail "AC10: refused-write positive control"
fi
tok_ok=1
for t in trust_level writable_roots network_access sandbox_workspace_write danger-full-access excludedCommands dangerously bypassPermissions --full-auto --yolo approval_policy permissions.allow config.toml settings.json settings.local.json; do
  for f in "$S" "$SK" "$T/all"; do
    g=0; grep -qF -- "$t" "$f" || g=$?
    [ "$g" -eq 1 ] || { tok_ok=0; printf 'forbidden token %s: grep status %s in %s\n' "$t" "$g" "$f" >&2; }
  done
done
[ "$tok_ok" -eq 1 ] && pass "AC10: none of the fifteen tokens occurs in the script, the skill or the run output" || fail "AC10: a forbidden token occurs"

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

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'setup suite: all assertions passed\n'
else
  printf 'setup suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
