#!/usr/bin/env bash
# run.sh — fixture suite for bin/check-setup.sh (T-1164, issue #640), the
# read-only run-start check. Six cases on each host: complete,
# scaffold-missing, codex-agents-missing, role-file-missing, cli-absent,
# cannot-evaluate. On the Claude Code host the codex-agents-missing and
# role-file-missing cases assert that `.codex` is not required. The Codex-host
# check is presence only: a changed role file still passes, a missing one is
# reported. Plus: help/usage, read-only checksums, the starting-directory and
# read-only-root cases, the forbidden-token lock, the template note and the
# three launch shapes.
#
# Every fixture repository is prepared by the shipped bin/team-setup.sh with a
# temp HOME/CODEX_HOME, GIT_CONFIG_GLOBAL=/dev/null and stub CLIs. The scratch
# root stays under ${TMPDIR:-/tmp}; nothing is deleted recursively.
#
# Mutation self-check (run by whoever changes this file, in a scratch copy,
# never against the tracked tree): re-add a comparator call to the checker, or
# make it create a file under TMPDIR, and this suite must fail.

set -euo pipefail

export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
C="$REPO_ROOT/bin/check-setup.sh"
S="$REPO_ROOT/bin/team-setup.sh"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

[ -s "$C" ] || { printf 'FAIL: %s missing\n' "$C" >&2; exit 1; }
[ -s "$S" ] || { printf 'FAIL: %s missing\n' "$S" >&2; exit 1; }
g=0
grep -nE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$C" "${BASH_SOURCE[0]}" >/dev/null 2>&1 || g=$?
if [ "$g" -ne 1 ]; then
  printf 'FAIL: recursive-delete gate did not complete clean (grep exit %s)\n' "$g" >&2
  exit 1
fi
pass "no recursive delete in bin/check-setup.sh or this suite (gate grep exit 1, completed)"

T="$(mktemp -d "${TMPDIR:-/tmp}/t1164-suite.XXXXXX")"
T="$(cd "$T" && pwd -P)"
export HOME="$T/home" CODEX_HOME="$T/ch" XDG_CONFIG_HOME="$T/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset TEAM_RUN_BASE CODEX_THREAD_ID
mkdir -p "$HOME" "$CODEX_HOME" "$T/s" "$T/e0" "$T/ng" "$T/p" "$T/tmpd"
for b in claude codex; do
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$T/s/$b"
  chmod +x "$T/s/$b"
done
SP="$T/s:$PATH"
NP="$T/e0:/usr/bin:/bin"
if ! env PATH="$NP" /bin/sh -c 'command -v git' >/dev/null 2>&1; then fail "precondition: git must resolve on the CLI-less PATH"; fi
if env PATH="$NP" /bin/sh -c 'command -v claude || command -v codex' >/dev/null 2>&1; then
  fail "precondition: claude/codex must not resolve on the CLI-less PATH"
fi

mk() { mkdir -p "$1" && git -C "$1" init -q && printf 'x\n' > "$1/README" && git -C "$1" add README && git -C "$1" -c user.email=t@example.com -c user.name=t commit -q -m i; }
sr() { (cd "$1" && PATH="$SP" bash "$S" --host "$2" < /dev/null > "$T/so" 2> "$T/se"); }
# ck <path> <dir> [args...] -> prints exit status; stdout in $T/o, stderr in $T/e
# Every ck run has TMPDIR pointing at one fresh empty directory, asserted empty at the end.
ck() { local p="$1" d="$2"; shift 2; (cd "$d" && TMPDIR="$T/tmpd" PATH="$p" "$BASH" "$C" "$@" < /dev/null > "$T/o" 2> "$T/e") && printf '0' || printf '%s' "$?"; }
nlines() { grep -c '^- ' "$T/o" || true; }

check() { # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected $2, got $3)"; fi
}
lw() { local l="$1"; shift; if grep '^- ' "$T/o" | grep -F -- "$1" | grep -qF -- "$2"; then pass "$l"; else fail "$l"; fi; }
lw_note() { local l="$1"; shift; if grep '^- note:' "$T/o" | grep -F -- "$1" | grep -qF -- "$2"; then pass "$l"; else fail "$l"; fi; }
has() { # <label> <fixed-string> <file>
  if grep -qF -- "$2" "$3"; then pass "$1"; else fail "$1 (missing: $2)"; fi
}
hasnt() {
  local g=0
  grep -qE -- "$2" "$3" || g=$?
  if [ "$g" -eq 1 ]; then pass "$1"; else fail "$1 (grep exit $g)"; fi
}

for H in claude-code codex-cli; do
  # --- complete -------------------------------------------------------------
  R="$T/complete-$H"; mk "$R"; sr "$R" "$H"
  check "$H complete: exit 0" 0 "$(ck "$SP" "$R" --host "$H")"
  check "$H complete: no '- ' line" 0 "$(nlines)"
  has "$H complete: header names the host" "$H" "$T/o"

  # --- scaffold-missing -----------------------------------------------------
  R="$T/fresh-$H"; mk "$R"
  check "$H scaffold-missing: fresh repository exits 1" 1 "$(ck "$SP" "$R" --host "$H")"
  for w in todo.md specs shell-team.contract.yaml; do
    lw "$H scaffold-missing: line names $w and set up shell-team" 'set up shell-team' "$w"
  done
  if [ -e "$R/.shell-team" ]; then fail "$H scaffold-missing: .shell-team was created"; else pass "$H scaffold-missing: nothing created"; fi
  R="$T/partial-$H"; mk "$R"; sr "$R" "$H"; rm -f "$R/.shell-team/todo.md"
  check "$H scaffold-missing: board removed exits 1" 1 "$(ck "$SP" "$R" --host "$H")"
  check "$H scaffold-missing: board removed gives exactly one line" 1 "$(nlines)"

  # --- codex-agents-missing -------------------------------------------------
  R="$T/cc-only-$H"; mk "$R"; sr "$R" claude-code
  if [ "$H" = codex-cli ]; then
    check "$H codex-agents-missing: exits 1" 1 "$(ck "$SP" "$R" --host "$H")"
    check "$H codex-agents-missing: exactly one line" 1 "$(nlines)"
    lw "$H codex-agents-missing: names .codex/agents and set up shell-team" .codex/agents 'set up shell-team'
  else
    check "$H codex-agents-missing: .codex is not required (exit 0)" 0 "$(ck "$SP" "$R" --host "$H")"
    if [ -e "$R/.codex" ]; then fail "$H codex-agents-missing: .codex appeared"; else pass "$H codex-agents-missing: .codex untouched"; fi
  fi

  # --- role-file-missing ------------------------------------------------------
  R="$T/rfm-$H"; mk "$R"; sr "$R" codex-cli
  printf 'changed\n' >> "$R/.codex/agents/shell-team-engineer.toml"
  check "$H role-file-missing: an appended line in a role file still exits 0 (contents are not compared)" 0 "$(ck "$SP" "$R" --host "$H")"
  check "$H role-file-missing: an appended line gives no '- ' line" 0 "$(nlines)"
  for r in tech-lead pm-spec engineer qa-verifier code-reviewer; do
    F="$R/.codex/agents/shell-team-$r.toml"
    if [ -f "$F" ]; then pass "$H role-file-missing: $r role file exists before deletion"; else fail "$H role-file-missing: $r role file absent from fixture"; fi
    cp "$F" "$T/keep"; rm -f "$F"
    if [ "$H" = codex-cli ]; then
      check "$H role-file-missing: deleting $r exits 1" 1 "$(ck "$SP" "$R" --host "$H")"
      check "$H role-file-missing: deleting $r gives exactly one line" 1 "$(nlines)"
      lw "$H role-file-missing: line names shell-team-$r.toml and update shell-team" "shell-team-$r.toml" 'update shell-team'
    else
      check "$H role-file-missing: deleting $r is not inspected off the Codex host (exit 0)" 0 "$(ck "$SP" "$R" --host "$H")"
    fi
    cp "$T/keep" "$F"
    check "$H role-file-missing: with $r restored exits 0" 0 "$(ck "$SP" "$R" --host "$H")"
  done

  # --- cli-absent -----------------------------------------------------------
  R="$T/cli-$H"; mk "$R"; sr "$R" "$H"
  if [ "$H" = codex-cli ]; then o=claude; else o=codex; fi
  check "$H cli-absent: exits 1 without $o" 1 "$(ck "$NP" "$R" --host "$H")"
  check "$H cli-absent: exactly one line" 1 "$(nlines)"
  lw "$H cli-absent: names command -v $o and the operator's decision" "command -v $o" "operator's decision"
  hasnt "$H cli-absent: names neither setup prompt" '(set up|update) shell-team' "$T/o"
  rm -f "$T/called"
  for b in claude codex; do printf '%s\n' '#!/usr/bin/env bash' "touch \"$T/called\"" 'exit 0' > "$T/p/$b"; chmod +x "$T/p/$b"; done
  check "$H cli-absent: with recording stubs exits 0" 0 "$(ck "$T/p:$PATH" "$R" --host "$H")"
  if [ -e "$T/called" ]; then fail "$H cli-absent: a stub CLI was invoked"; else pass "$H cli-absent: no CLI was ever invoked"; fi
done

# --- cannot-evaluate (both hosts) -------------------------------------------
# A plugin root with bin/ and templates/ but no agents/: the checker calls no
# comparator, so a Codex-set-up repository still passes.
mkdir -p "$T/pr" && cp -R "$REPO_ROOT/bin" "$REPO_ROOT/templates" "$T/pr/"
if [ -e "$T/pr/agents" ]; then fail "precondition: the copied plugin root has no agents/"; else pass "precondition: the copied plugin root has no agents/"; fi
R="$T/ce"; mk "$R"; sr "$R" codex-cli
x=0; (cd "$R" && TMPDIR="$T/tmpd" PATH="$SP" bash "$T/pr/bin/check-setup.sh" --host codex-cli < /dev/null > "$T/o" 2> "$T/e") || x=$?
check "codex-cli cannot-evaluate: a plugin root without agents/ still exits 0 (no comparator)" 0 "$x"
# a resolver refusal (absolute TEAM_RUN_BASE) is exit 2 on both hosts and wins over a missing board
rm -f "$R/.shell-team/todo.md"
check "codex-cli cannot-evaluate: missing board exits 1 before the refusal" 1 "$(ck "$SP" "$R" --host codex-cli)"
for H in codex-cli claude-code; do
  x=0; (cd "$R" && TMPDIR="$T/tmpd" TEAM_RUN_BASE="$T/abs" PATH="$SP" bash "$C" --host "$H" < /dev/null > "$T/o" 2> "$T/e") || x=$?
  check "$H cannot-evaluate: resolver refusal (absolute TEAM_RUN_BASE) exits 2" 2 "$x"
  has "$H cannot-evaluate: stderr relays the resolver's message (team-paths:)" 'team-paths:' "$T/e"
  has "$H cannot-evaluate: stderr names TEAM_RUN_BASE" TEAM_RUN_BASE "$T/e"
done
x=$(ck "$SP" "$T/ng" --host claude-code)
check "claude-code cannot-evaluate: outside a git work tree exits 2" 2 "$x"
x=$(ck "$SP" "$T/ng" --host codex-cli)
check "codex-cli cannot-evaluate: outside a git work tree exits 2" 2 "$x"
if [ -n "$(find "$T/ng" -mindepth 1 -print)" ]; then fail "cannot-evaluate: non-git directory was written"; else pass "cannot-evaluate: non-git directory stays empty"; fi
R="$T/arg"; mk "$R"; sr "$R" claude-code
for a in '--bogus' '--host bogus' '--host'; do
  # shellcheck disable=SC2086
  check "cannot-evaluate: '$a' exits 2" 2 "$(ck "$SP" "$R" $a)"
done

# --- help / host selection / subdirectory / launch shapes --------------------
for a in --help -h; do
  check "help: $a exits 0 outside a work tree" 0 "$(ck "$SP" "$T/ng" "$a")"
  has "help: $a prints Usage:" 'Usage:' "$T/o"
done
if [ "$(git -C "$REPO_ROOT" ls-files -s -- bin/check-setup.sh | cut -d' ' -f1)" = 100755 ]; then pass "bin/check-setup.sh tracked 100755"; else fail "bin/check-setup.sh not tracked 100755"; fi
R="$T/complete-codex-cli"
# shellcheck disable=SC2030,SC2031
x=$( (export CODEX_THREAD_ID=t; ck "$SP" "$R") )
check "host: CODEX_THREAD_ID selects codex-cli" 0 "$x"
has "host: header names codex-cli" codex-cli "$T/o"
has "host: header names CODEX_THREAD_ID" CODEX_THREAD_ID "$T/o"
R="$T/complete-claude-code"
# shellcheck disable=SC2030,SC2031
x=$( (export CODEX_THREAD_ID=t; ck "$SP" "$R") )
check "host: a Claude-only repository under CODEX_THREAD_ID exits 1" 1 "$x"
mkdir -p "$R/sub/dir"
check "subdirectory: nested work-tree directory exits 0" 0 "$(ck "$SP" "$R/sub/dir" --host claude-code)"
# launch shapes: bash script, direct, bare name through a PATH symlink
check "launch: ./script directly" 0 "$( (cd "$R" && PATH="$SP" "$C" --host claude-code < /dev/null > "$T/o" 2> "$T/e") && printf 0 || printf '%s' "$?")"
mkdir -p "$T/lnk" && ln -sf "$C" "$T/lnk/check-setup.sh"
check "launch: bare name through a PATH symlink" 0 "$( (cd "$R" && PATH="$T/lnk:$SP" check-setup.sh --host claude-code < /dev/null > "$T/o" 2> "$T/e") && printf 0 || printf '%s' "$?")"

# --- template note (D1) -----------------------------------------------------
R="$T/note"; mk "$R"; sr "$R" claude-code
printf '# local edit\n' >> "$R/.shell-team/.gitignore"
check "note: edited .gitignore still exits 0" 0 "$(ck "$SP" "$R" --host claude-code)"
check "note: exactly one line" 1 "$(nlines)"
lw_note "note: names .gitignore and update shell-team" .gitignore 'update shell-team'
printf '\nlocal note\n' >> "$R/.shell-team/todo.md"
check "note: an edited board adds nothing" 1 "$(ck "$SP" "$R" --host claude-code >/dev/null; nlines)"

# --- read-only: checksum listings before/after -------------------------------
Q="$T/pr2"; mkdir -p "$Q" && cp -R "$REPO_ROOT/bin" "$REPO_ROOT/templates" "$REPO_ROOT/agents" "$REPO_ROOT/.claude-plugin" "$Q/"
QC="$Q/bin/check-setup.sh"
snap() { (cd "$1" && find . -path ./.git/objects -prune -o -print | sort | while IFS= read -r p; do if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi; done); }
R1="$T/ro1"; R2="$T/ro2"; R3="$T/ro3"
for r in "$R1" "$R2" "$R3"; do mk "$r"; done
sr "$R1" codex-cli; sr "$R2" claude-code
printf 'drift\n' >> "$R1/.codex/agents/shell-team-engineer.toml"
dirs=("$R1" "$R2" "$R3" "$T/ng" "$HOME" "$CODEX_HOME" "$Q")
i=0; for d in "${dirs[@]}"; do i=$((i+1)); snap "$d" > "$T/b$i"; [ -s "$T/b$i" ] || fail "read-only: empty baseline listing $i"; done
for d in "$R1" "$R2" "$R3" "$T/ng"; do
  for h in codex-cli claude-code; do
    for p in "$SP" "$NP"; do (cd "$d" && PATH="$p" "$BASH" "$QC" --host "$h" < /dev/null > /dev/null 2>&1) || true; done
  done
  (cd "$d" && PATH="$SP" "$BASH" "$QC" --bogus < /dev/null > /dev/null 2>&1) || true
done
i=0; for d in "${dirs[@]}"; do
  i=$((i+1)); snap "$d" > "$T/a$i"
  if cmp -s "$T/b$i" "$T/a$i"; then pass "read-only: listing $i byte-identical after every run"; else fail "read-only: listing $i changed"; fi
done

# --- starting directory and read-only root (T-1164 v3, AC18) ------------------
# The checker calls no comparator and creates nothing, so the result is the same
# from the repository root, a subdirectory or a read-only root, whatever TMPDIR.
for n in rw ro m; do
  R="$T/sd-$n"; mk "$R"; sr "$R" codex-cli; mkdir -p "$R/sub/d"
  if [ -d "$R/.codex/agents" ] && [ -d "$R/.shell-team" ]; then pass "start-dir $n: fixture is set up for the Codex CLI host"; else fail "start-dir $n: fixture setup failed"; fi
done
R="$T/sd-rw"
ls -A "$R" > "$T/sd-b1"; ls -A "$R/sub/d" > "$T/sd-b2"
check "start-dir writable: root exits 0" 0 "$(ck "$SP" "$R" --host codex-cli)"
check "start-dir writable: sub/d exits 0" 0 "$(ck "$SP" "$R/sub/d" --host codex-cli)"
x=0; (cd "$R" && TMPDIR=reltmp PATH="$SP" "$BASH" "$C" --host codex-cli < /dev/null > "$T/o" 2> "$T/e") || x=$?
check "start-dir writable: a relative TMPDIR (reltmp) still exits 0" 0 "$x"
if [ -e "$R/reltmp" ]; then fail "start-dir writable: reltmp was created"; else pass "start-dir writable: no reltmp was created"; fi
ls -A "$R" > "$T/sd-a1"; ls -A "$R/sub/d" > "$T/sd-a2"
if [ -s "$T/sd-b1" ] && cmp -s "$T/sd-b1" "$T/sd-a1" && cmp -s "$T/sd-b2" "$T/sd-a2"; then pass "start-dir writable: entry lists of root and sub/d unchanged"; else fail "start-dir writable: an entry appeared where the checker started"; fi
R="$T/sd-ro"
chmod 555 "$R/sub/d" "$R"
if (: > "$R/probe") 2> /dev/null; then fail "start-dir read-only: precondition (the root refuses a new file) does not hold"; else pass "start-dir read-only: precondition, the root refuses a new file"; fi
r1=$(ck "$SP" "$R" --host codex-cli); r2=$(ck "$SP" "$R/sub/d" --host codex-cli); r3=$(ck "$SP" "$R" --host claude-code)
chmod 755 "$R" "$R/sub/d"
check "start-dir read-only: root, codex-cli exits 0" 0 "$r1"
check "start-dir read-only: sub/d, codex-cli exits 0" 0 "$r2"
check "start-dir read-only: root, claude-code exits 0" 0 "$r3"
if [ -e "$R/probe" ]; then fail "start-dir read-only: a probe file appeared"; else pass "start-dir read-only: no file appeared"; fi
# a role file missing: same exit and same '- ' lines from root and sub/d, writable and mode 555
R="$T/sd-m"
if [ -f "$R/.codex/agents/shell-team-qa-verifier.toml" ]; then pass "start-dir missing: qa-verifier role file exists before deletion"; else fail "start-dir missing: qa-verifier role file absent from fixture"; fi
rm -f "$R/.codex/agents/shell-team-qa-verifier.toml"
i=0
for d in "$R" "$R/sub/d"; do i=$((i+1)); check "start-dir missing writable $i: exits 1" 1 "$(ck "$SP" "$d" --host codex-cli)"; grep '^- ' "$T/o" > "$T/ml$i"; done
chmod 555 "$R/sub/d" "$R"
for d in "$R" "$R/sub/d"; do i=$((i+1)); check "start-dir missing read-only $i: exits 1" 1 "$(ck "$SP" "$d" --host codex-cli)"; grep '^- ' "$T/o" > "$T/ml$i"; done
chmod 755 "$R" "$R/sub/d"
if [ -s "$T/ml1" ]; then pass "start-dir missing: the '- ' lines are non-empty"; else fail "start-dir missing: no '- ' line"; fi
for j in 2 3 4; do
  if cmp -s "$T/ml1" "$T/ml$j"; then pass "start-dir missing: '- ' lines of run $j are byte-identical to run 1"; else fail "start-dir missing: '- ' lines of run $j differ from run 1"; fi
done
# the fresh TMPDIR used by every ck run is still empty: the checker created no scratch
if [ -z "$(find "$T/tmpd" -mindepth 1 -print)" ]; then pass "scratch: the TMPDIR given to every checker run is still empty"; else fail "scratch: the checker created an entry under TMPDIR"; fi

# --- forbidden-token lock ------------------------------------------------------
: > "$T/all"
for h in codex-cli claude-code; do
  for r in "$T/fresh-$h" "$T/complete-$h"; do ck "$SP" "$r" --host "$h" >/dev/null; cat "$T/o" "$T/e" >> "$T/all"; done
done
ck "$SP" "$T/rfm-codex-cli" --host codex-cli >/dev/null; cat "$T/o" "$T/e" >> "$T/all"
has "tokens: positive control (output names set up shell-team)" 'set up shell-team' "$T/all"
has "tokens: positive control (script names team-paths.sh)" team-paths.sh "$C"
for t in check-codex-agents gen-codex-agents resolve-executor; do
  g=0; grep -qF -- "$t" "$C" || g=$?
  if [ "$g" -eq 1 ]; then pass "no comparator: '$t' is not named in bin/check-setup.sh"; else fail "no comparator: '$t' present or unreadable in bin/check-setup.sh (grep exit $g)"; fi
done
for t in trust_level writable_roots network_access sandbox_workspace_write danger-full-access excludedCommands dangerously bypassPermissions --full-auto --yolo approval_policy permissions.allow config.toml settings.json settings.local.json; do
  for f in "$C" "$T/all"; do
    g=0; grep -qF -- "$t" "$f" || g=$?
    if [ "$g" -eq 1 ]; then pass "tokens: '$t' absent from $(basename "$f")"; else fail "tokens: '$t' present or unreadable in $(basename "$f") (grep exit $g)"; fi
  done
done

if [ "$fails" -gt 0 ]; then
  printf '\ncheck-setup suite: %d assertion(s) FAILED\n' "$fails" >&2
  exit 1
fi
printf '\ncheck-setup suite: all assertions passed\n'
