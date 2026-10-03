#!/usr/bin/env bash
# run.sh — fixture suite for bin/team-commit.sh (T-1169, issue #662).
#
# Every case builds a throwaway git repository under a scratch root in
# ${TMPDIR:-/tmp} (never inside this checkout: a nested .git cannot be written
# there in a sandboxed run) and runs the real script against it. The
# workstation is isolated: HOME and XDG_CONFIG_HOME point into the scratch
# root, GIT_CONFIG_GLOBAL=/dev/null and GIT_CONFIG_NOSYSTEM=1 are exported, the
# git-redirecting variables the script refuses are unset, and user.name and
# user.email live in each fixture's own local config. Without that a global
# core.hooksPath would run inside every fixture commit.
#
# Case ids (one `PASS: <id> ...` line each): ok-*, ref-* (every refusal asserts
# exit 2, HEAD unchanged, the staged set unchanged, the work tree unchanged,
# nothing on stdout and the intended refusal class on stderr), post-*, help,
# plus the launch shapes. A removed file is made by moving it out of the work
# tree; nothing is ever deleted — scratch directories stay under the root.
#
# TEAM_COMMIT_SCRIPT overrides the script under test (a mutation self-check
# points it at a scratch copy; the default is the tracked bin/team-commit.sh).

set -euo pipefail

export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="${TEAM_COMMIT_SCRIPT:-$REPO_ROOT/bin/team-commit.sh}"

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; fails=$((fails + 1)); }

[ -s "$SCRIPT" ] || { printf 'FAIL: %s missing\n' "$SCRIPT" >&2; exit 1; }
g=0
grep -nE 'rm -[a-zA-Z]*[rR]|find .*-dele[t]e' "$SCRIPT" "${BASH_SOURCE[0]}" > /dev/null 2>&1 || g=$?
if [ "$g" -ne 1 ]; then
  printf 'FAIL: recursive-delete gate did not complete clean (grep exit %s)\n' "$g" >&2
  exit 1
fi
pass "gate no recursive delete in the script or this suite (grep exit 1, completed)"

T="$(mktemp -d "${TMPDIR:-/tmp}/t1169-suite.XXXXXX")"
T="$(cd "$T" && pwd -P)"
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
  GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS \
  GIT_ICASE_PATHSPECS GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
# GIT_CONFIG_KEY_<n> / GIT_CONFIG_VALUE_<n> only act together with
# GIT_CONFIG_COUNT, which is unset above; drop them too so nothing leaks in.
for n in 0 1 2 3 4 5 6 7 8 9; do
  unset "GIT_CONFIG_KEY_$n" "GIT_CONFIG_VALUE_$n"
done
mkdir -p "$HOME" "$T/msgs" "$T/nogit"

MSG="$T/msgs/msg"
printf 'Commit message\n' > "$MSG"

# --- fixtures ----------------------------------------------------------------

CASE=0
# new_repo: set R to the path of a fresh repository with one base commit holding
# README, b.txt, c.txt, sub/s.txt and a .gitignore naming ignored.txt.
new_repo() {
  local r
  CASE=$((CASE + 1))
  r="$T/r$CASE"
  mkdir -p "$r/sub"
  git -C "$r" init -q
  git -C "$r" symbolic-ref HEAD refs/heads/main
  git -C "$r" config user.email t@example.com
  git -C "$r" config user.name t
  git -C "$r" config core.fileMode true
  printf 'x\n' > "$r/README"
  printf 'b\n' > "$r/b.txt"
  printf 'c\n' > "$r/c.txt"
  printf 's\n' > "$r/sub/s.txt"
  printf 'ignored.txt\n' > "$r/.gitignore"
  git -C "$r" add README b.txt c.txt sub/s.txt .gitignore
  git -C "$r" commit -q -m base
  R="$r"
}

# State snapshot: HEAD, the staged set and the work-tree status.
snap() {
  local r="$1" h
  h="$(git -C "$r" rev-parse -q --verify HEAD 2> /dev/null || printf 'unborn')"
  printf 'HEAD=%s\nSTAGED=%s\nSTATUS=%s\n' "$h" \
    "$(git -C "$r" diff --cached --name-only)" \
    "$(git -C "$r" status --porcelain)"
}

RC=0
OUT=""
ERR=""
# run_in <dir> <env assignment> <args...>: run the script with cwd <dir>.
run_in() {
  local d="$1" e="$2"
  shift 2
  RC=0
  (cd "$d" && env "$e" bash "$SCRIPT" "$@" < /dev/null > "$T/o" 2> "$T/e") || RC=$?
  OUT="$(cat "$T/o")"
  ERR="$(cat "$T/e")"
}
NOENV="TEAM_COMMIT_NOOP=1"

# assert_ref <id> <repo> <class> <args...>: a refusal. Exit 2, nothing on
# stdout, the state snapshot unchanged, and the refusal class named on stderr.
assert_ref() {
  local id="$1" r="$2" class="$3" before after
  shift 3
  before="$(snap "$r")"
  run_in "$r" "$NOENV" "$@"
  after="$(snap "$r")"
  ref_check "$id" "$before" "$after" "$class"
}
# assert_ref_env <id> <repo> <class> <env assignment> <args...>
assert_ref_env() {
  local id="$1" r="$2" class="$3" e="$4" before after
  shift 4
  before="$(snap "$r")"
  run_in "$r" "$e" "$@"
  after="$(snap "$r")"
  ref_check "$id" "$before" "$after" "$class"
}
ref_check() {
  local id="$1" before="$2" after="$3" class="${4%%|*}" detail=""
  case "$4" in *'|'*) detail="${4#*|}" ;; esac
  if [ "$RC" -ne 2 ]; then
    fail "$id: expected exit 2, got $RC (stderr: $ERR)"; return 1
  fi
  if [ -n "$OUT" ]; then fail "$id: stdout must be empty, got: $OUT"; return 1; fi
  if [ "$before" != "$after" ]; then fail "$id: state changed (before/after differ)"; return 1; fi
  case "$ERR" in
    *"refused ($class)"*) : ;;
    *) fail "$id: stderr does not carry 'refused ($class)': $ERR"; return 1 ;;
  esac
  if [ -n "$detail" ]; then
    case "$ERR" in
      *"$detail"*) : ;;
      *) fail "$id: stderr does not name '$detail': $ERR"; return 1 ;;
    esac
  fi
  return 0
}
# ok_commit <id> <repo> <expected name-status, sorted> <args...>: a success.
ok_commit() {
  local id="$1" r="$2" want="$3" base head ns
  shift 3
  base="$(git -C "$r" rev-parse HEAD)"
  run_in "$r" "$NOENV" "$@"
  head="$(git -C "$r" rev-parse HEAD)"
  [ "$RC" -eq 0 ] || { fail "$id: expected exit 0, got $RC (stderr: $ERR)"; return 1; }
  [ "$OUT" = "$head" ] || { fail "$id: stdout is not the new HEAD sha: $OUT"; return 1; }
  [ "$(git -C "$r" rev-parse HEAD~1)" = "$base" ] || { fail "$id: parent is not the base commit"; return 1; }
  ns="$(git -C "$r" diff-tree --no-commit-id --name-status -r --no-renames HEAD | sort)"
  [ "$ns" = "$want" ] || { fail "$id: commit holds [$ns], wanted [$want]"; return 1; }
  git -C "$r" diff --cached --quiet || { fail "$id: something is still staged"; return 1; }
  return 0
}

TAB="$(printf '\t')"

# --- ok-* -------------------------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
if ok_commit ok-modified "$r" "M${TAB}README" --message-file "$MSG" -- README; then
  pass "ok-modified a modified tracked file is committed; stdout is the new sha"
fi

new_repo; r="$R"; printf 'a\n' > "$r/a.txt"
if ok_commit ok-new-file "$r" "A${TAB}a.txt" --message-file "$MSG" -- a.txt; then
  pass "ok-new-file a new untracked file is committed"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"; printf 'a\n' > "$r/a.txt"; printf 'n\n' > "$r/sub/n.txt"; printf 'm\n' >> "$r/sub/s.txt"
want="$(printf 'A\ta.txt\nA\tsub/n.txt\nM\tREADME\nM\tsub/s.txt\n')"
if ok_commit ok-multi "$r" "$want" --message-file "$MSG" -- README a.txt sub/n.txt sub/s.txt; then
  pass "ok-multi four paths, nested and top-level, new and modified"
fi

new_repo; r="$R"; printf '#!/bin/sh\n' > "$r/tool.sh"; chmod +x "$r/tool.sh"
if ok_commit ok-new-exec "$r" "A${TAB}tool.sh" --message-file "$MSG" -- tool.sh \
  && [ "$(git -C "$r" ls-tree HEAD -- tool.sh | cut -c1-6)" = "100755" ]; then
  pass "ok-new-exec a new executable file is committed with mode 100755"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
printf '%s\n' '#!/bin/sh' "printf 'hook ran\\n' > \"$T/hook-marker\"" 'printf "hook stdout noise\\n"' > "$r/.git/hooks/pre-commit"
chmod +x "$r/.git/hooks/pre-commit"
if ok_commit ok-hook-runs "$r" "M${TAB}README" --message-file "$MSG" -- README \
  && [ "$(cat "$T/hook-marker")" = "hook ran" ]; then
  pass "ok-hook-runs the repository's own pre-commit hook ran; its stdout stayed off ours"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
printf 'Subject line\n\nBody line one\n  indented body line\nLast line\n' > "$T/msgs/multi"
if ok_commit ok-message-verbatim "$r" "M${TAB}README" --message-file "$T/msgs/multi" -- README; then
  git -C "$r" cat-file commit HEAD | sed '1,/^$/d' > "$T/got-msg"
  if cmp -s "$T/got-msg" "$T/msgs/multi"; then
    pass "ok-message-verbatim a multi-line message is committed byte for byte"
  else
    fail "ok-message-verbatim: commit message differs from the message file"
  fi
fi

# Launch shapes: direct execution and a bare name reached through a PATH symlink.
new_repo; r="$R"; printf 'y\n' >> "$r/README"
base="$(git -C "$r" rev-parse HEAD)"
RC=0
(cd "$r" && "$SCRIPT" --message-file "$MSG" -- README < /dev/null > "$T/o" 2> "$T/e") || RC=$?
if [ "$RC" -eq 0 ] && [ "$(cat "$T/o")" = "$(git -C "$r" rev-parse HEAD)" ] && [ "$(git -C "$r" rev-parse HEAD~1)" = "$base" ]; then
  pass "ok-launch-direct executed as ./script (exec bit honoured)"
else
  fail "ok-launch-direct: rc=$RC stderr=$(cat "$T/e")"
fi
mkdir -p "$T/pathdir"
ln -s "$SCRIPT" "$T/pathdir/team-commit.sh"
new_repo; r="$R"; printf 'y\n' >> "$r/README"
base="$(git -C "$r" rev-parse HEAD)"
RC=0
(cd "$r" && PATH="$T/pathdir:$PATH" team-commit.sh --message-file "$MSG" -- README < /dev/null > "$T/o" 2> "$T/e") || RC=$?
if [ "$RC" -eq 0 ] && [ "$(cat "$T/o")" = "$(git -C "$r" rev-parse HEAD)" ] && [ "$(git -C "$r" rev-parse HEAD~1)" = "$base" ]; then
  pass "ok-launch-symlink a bare name reached through a PATH symlink"
else
  fail "ok-launch-symlink: rc=$RC stderr=$(cat "$T/e")"
fi

# Config and identity variables are not refused (they select the operator's own
# configuration): a fixture without a local identity commits through them.
new_repo; r="$R"; printf 'y\n' >> "$r/README"
git -C "$r" config --unset user.name; git -C "$r" config --unset user.email
RC=0
(cd "$r" && env GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@example.com GIT_COMMITTER_NAME=c GIT_COMMITTER_EMAIL=c@example.com \
  bash "$SCRIPT" --message-file "$MSG" -- README < /dev/null > "$T/o" 2> "$T/e") || RC=$?
if [ "$RC" -eq 0 ] && [ "$(git -C "$r" log -1 --format=%an)" = "a" ]; then
  pass "ok-identity-env identity variables are accepted and used"
else
  fail "ok-identity-env: rc=$RC stderr=$(cat "$T/e")"
fi

# --- ref-usage / ref-flag ---------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
if assert_ref ref-usage-noargs "$r" usage; then pass "ref-usage-noargs no arguments is refused"; fi
if assert_ref ref-usage-no-message "$r" usage -- README; then pass "ref-usage-no-message paths without --message-file"; fi
if assert_ref ref-usage-no-paths "$r" usage --message-file "$MSG" --; then
  if assert_ref ref-usage-no-paths "$r" usage --message-file "$MSG"; then
    pass "ref-usage-no-paths a message file with no paths, with and without the separator"
  fi
fi
assert_ref ref-usage-message-no-value "$r" usage --message-file \
  && pass "ref-usage-message-no-value --message-file as the last argument"
assert_ref ref-usage-dup-message "$r" usage --message-file "$MSG" --message-file "$MSG" -- README \
  && pass "ref-usage-dup-message --message-file twice"
assert_ref ref-usage-no-separator "$r" usage --message-file "$MSG" README \
  && pass "ref-usage-no-separator paths without the -- separator"

flag_case() {
  local id="$1" f="$2" ok=1
  # Before the separator, between the message file and the separator, and as a
  # would-be path after the separator.
  assert_ref "$id" "$r" usage "$f" --message-file "$MSG" -- README || ok=0
  assert_ref "$id" "$r" usage --message-file "$MSG" "$f" -- README || ok=0
  assert_ref "$id" "$r" path --message-file "$MSG" -- README "$f" || ok=0
  [ "$ok" -eq 1 ] && pass "$id $f is refused before the separator, after the message file and as a path"
  return 0
}
flag_case ref-flag-a -a
flag_case ref-flag-A -A
flag_case ref-flag-all --all
flag_case ref-flag-amend --amend
flag_case ref-flag-no-verify --no-verify
ok=1
for f in -n --force -u . --bogus -z -m -F "--message-file=$MSG" "--message-fil" -p; do
  assert_ref ref-flag-unknown "$r" usage "$f" --message-file "$MSG" -- README || ok=0
done
[ "$ok" -eq 1 ] && pass "ref-flag-unknown every other option or spelling is refused"

# --- ref-msg ----------------------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
if assert_ref ref-msg-missing "$r" "message-file|does not exist" --message-file "$T/msgs/nope" -- README; then pass "ref-msg-missing a message file that does not exist"; fi
ln -s "$MSG" "$T/msgs/link"
if assert_ref ref-msg-symlink "$r" "message-file|is a symlink" --message-file "$T/msgs/link" -- README; then pass "ref-msg-symlink a symlink message file"; fi
mkdir -p "$T/msgs/dir"
if assert_ref ref-msg-directory "$r" "message-file|is not a regular file" --message-file "$T/msgs/dir" -- README; then pass "ref-msg-directory a directory is not a message file"; fi
: > "$T/msgs/empty"
if assert_ref ref-msg-empty "$r" "message-file|is empty" --message-file "$T/msgs/empty" -- README; then pass "ref-msg-empty an empty message file"; fi
printf 'm\n' > "$r/inmsg"
if assert_ref ref-msg-in-worktree "$r" "message-file|inside the work tree" --message-file "$r/inmsg" -- README \
  && assert_ref ref-msg-in-worktree "$r" "message-file|inside the work tree" --message-file inmsg -- README \
  && assert_ref ref-msg-in-worktree "$r" "message-file|inside the work tree" --message-file "$r/sub/../inmsg" -- README; then
  pass "ref-msg-in-worktree a message file inside the work tree (absolute, relative, dotted)"
fi
ok=1
for m in "$T/msgs/m;x" "$T/msgs/m x" "$T/msgs/m\$x" "$T/msgs/m\`x" "$T/msgs/mé"; do
  printf 'm\n' > "$m"
  assert_ref ref-msg-metachar "$r" "message-file|characters outside" --message-file "$m" -- README || ok=0
done
[ "$ok" -eq 1 ] && pass "ref-msg-metachar a message file path outside [A-Za-z0-9._/-] (existing file with ; or space or \$)"

# --- ref-path (grammar) ------------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
path_case() {
  local id="$1" p="$2" class="${3:-path}"
  assert_ref "$id" "$r" "$class" --message-file "$MSG" -- "$p"
}
if path_case ref-path-absolute /etc/hosts "path|absolute path"; then pass "ref-path-absolute an absolute path"; fi
ok=1
for p in ../x sub/../README ./README sub/./s.txt ..; do path_case ref-path-dotdot "$p" "path|'.' or '..' component" || ok=0; done
[ "$ok" -eq 1 ] && pass "ref-path-dotdot '..' and '.' components (leading, inner, bare)"
ok=1
for p in .git/config sub/.git/x .git; do path_case ref-path-dotgit "$p" "path|.git component" || ok=0; done
[ "$ok" -eq 1 ] && pass "ref-path-dotgit .git as a leading, inner or bare component"
ok=1
for p in .GIT/config .Git/config sub/.gIt/x .gIT; do path_case ref-path-dotgit-case "$p" "path|.git component" || ok=0; done
[ "$ok" -eq 1 ] && pass "ref-path-dotgit-case .git in any letter case"
if path_case ref-path-leading-dash -x "path|starts with"; then pass "ref-path-leading-dash a path that looks like an option"; fi
ok=1
# shellcheck disable=SC2016  # the metacharacters are literal on purpose
for p in 'a;b' 'a$b' 'a`b' 'a|b' 'a&b' 'a"b' "a'b" 'a\b' 'a<b' 'a>b' 'a(b' 'a!b' 'a#b' 'a~b' 'a=b' 'a:b' 'a,b' 'a@b' 'é'; do
  path_case ref-path-metachar "$p" "path|characters outside" || ok=0
done
path_case ref-path-metachar "$(printf 'a\nb')" "path|characters outside" || ok=0
path_case ref-path-metachar "" "path|empty path" || ok=0
[ "$ok" -eq 1 ] && pass "ref-path-metachar shell metacharacters, a newline, a non-ASCII byte and the empty path"
if path_case ref-path-space 'a b' "path|characters outside"; then pass "ref-path-space a path with a space"; fi
ok=1
for p in '*.txt' 'READM?' '[R]EADME' 'sub/*'; do path_case ref-path-glob "$p" "path|characters outside" || ok=0; done
[ "$ok" -eq 1 ] && pass "ref-path-glob glob characters"
if assert_ref ref-path-duplicate "$r" "path|more than once" --message-file "$MSG" -- README README \
  && assert_ref ref-path-duplicate "$r" "path|more than once" --message-file "$MSG" -- README sub/s.txt README; then
  pass "ref-path-duplicate a repeated path, adjacent or not"
fi
ok=1
for p in sub/ README/; do path_case ref-path-trailing-slash "$p" "path|trailing slash" || ok=0; done
path_case ref-path-trailing-slash sub//s.txt "path|empty component" || ok=0
[ "$ok" -eq 1 ] && pass "ref-path-trailing-slash a trailing slash (and a doubled one)"

# --- ref-path (kinds and changes) --------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
mkdir -p "$T/moved1"; mv "$r/b.txt" "$T/moved1/b.txt"
if path_case ref-path-removed b.txt "path|a removal" \
  && assert_ref ref-path-removed "$r" "path|a removal" --message-file "$MSG" -- README b.txt; then
  pass "ref-path-removed a tracked file moved out of the work tree (the removal form), alone or with a valid path"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
if path_case ref-path-never-existed nope.txt "path|does not exist"; then pass "ref-path-never-existed a path that never existed"; fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
ln -s README "$r/link"
ln -s sub "$r/lnk"
if path_case ref-path-symlink link "path|is a symlink" && path_case ref-path-symlink lnk/s.txt "path|is a symlink" \
  && assert_ref ref-path-symlink "$r" "path|is a symlink" --message-file "$MSG" -- README link; then
  pass "ref-path-symlink a symlink, a path through a symlinked directory, a symlink beside a valid path"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
mkdir -p "$r/dir"; printf 'd\n' > "$r/dir/d.txt"
if path_case ref-path-directory dir "path|not a regular file" && path_case ref-path-directory sub "path|not a regular file"; then
  pass "ref-path-directory an untracked and a tracked directory"
fi

new_repo; r="$R"
printf 'y\n' >> "$r/README"
git -C "$r" update-index --add --cacheinfo "160000,$(git -C "$r" rev-parse HEAD),gl"
git -C "$r" commit -q -m gitlink
mkdir -p "$r/gl"; printf 'y\n' >> "$r/README"
mkdir -p "$r/nested"; git -C "$r/nested" init -q; printf 'n\n' > "$r/nested/f.txt"
if path_case ref-path-gitlink gl "path|not a regular file" && path_case ref-path-gitlink gl/inside.txt "path|does not exist" && path_case ref-path-gitlink nested/f.txt "path|nested repository"; then
  pass "ref-path-gitlink a gitlink path, a path beneath it and a path inside a nested repository"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"; printf 'i\n' > "$r/ignored.txt"
if path_case ref-path-ignored ignored.txt "path|is ignored"; then pass "ref-path-ignored an ignored untracked file"; fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
if path_case ref-path-unchanged c.txt "path|unchanged from HEAD" \
  && assert_ref ref-path-unchanged "$r" "path|unchanged from HEAD" --message-file "$MSG" -- README c.txt; then
  pass "ref-path-unchanged a tracked file identical to HEAD, alone or beside a valid path"
fi

new_repo; r="$R"; chmod +x "$r/c.txt"
if path_case ref-mode-only c.txt "path|mode change"; then pass "ref-mode-only a mode-only change"; fi

new_repo; r="$R"; chmod +x "$r/c.txt"; printf 'more\n' >> "$r/c.txt"; printf 'y\n' >> "$r/README"
if path_case ref-mode-change c.txt "path|mode change" \
  && assert_ref ref-mode-change "$r" "path|mode change" --message-file "$MSG" -- README c.txt; then
  pass "ref-mode-change a mode change with content, alone or beside a valid path"
fi

# A tracked symlink replaced by a regular file is a type change, not a modification.
new_repo; r="$R"
ln -s README "$r/tl"; git -C "$r" add tl; git -C "$r" commit -q -m symlink
mkdir -p "$T/moved-tl"; mv "$r/tl" "$T/moved-tl/tl"; printf 'now a file\n' > "$r/tl"
if path_case ref-path-type-change tl "path|tracked in HEAD as mode 120000"; then pass "ref-path-type-change a tracked symlink replaced by a regular file"; fi

# --- ref-index ---------------------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"; printf 'm\n' >> "$r/b.txt"
git -C "$r" add -- b.txt
if assert_ref ref-index-staged "$r" "index|staged change" --message-file "$MSG" -- README; then pass "ref-index-staged something already staged"; fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
mkdir -p "$T/moved2"; mv "$r/b.txt" "$T/moved2/b.txt"
git -C "$r" add -- b.txt
if assert_ref ref-index-staged-removal "$r" "index|staged change" --message-file "$MSG" -- README; then
  pass "ref-index-staged-removal a staged removal (the state an all-staging form would carry)"
fi

# --- ref-env -----------------------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
ok=1
assert_ref_env ref-env-git-dir "$r" "environment|GIT_DIR is set" "GIT_DIR=$r/.git" --message-file "$MSG" -- README || ok=0
assert_ref_env ref-env-git-dir "$r" "environment|GIT_DIR is set" "GIT_DIR=" --message-file "$MSG" -- README || ok=0
[ "$ok" -eq 1 ] && pass "ref-env-git-dir GIT_DIR set, and set but empty"
if assert_ref_env ref-env-work-tree "$r" "environment|GIT_WORK_TREE is set" "GIT_WORK_TREE=$r" --message-file "$MSG" -- README; then pass "ref-env-work-tree GIT_WORK_TREE set"; fi
if assert_ref_env ref-env-index-file "$r" "environment|GIT_INDEX_FILE is set" "GIT_INDEX_FILE=$r/.git/index" --message-file "$MSG" -- README; then pass "ref-env-index-file GIT_INDEX_FILE set"; fi
if assert_ref_env ref-env-literal-pathspecs "$r" "environment|GIT_LITERAL_PATHSPECS is set" "GIT_LITERAL_PATHSPECS=1" --message-file "$MSG" -- README; then pass "ref-env-literal-pathspecs GIT_LITERAL_PATHSPECS set"; fi
if assert_ref_env ref-env-glob-pathspecs "$r" "environment|GIT_GLOB_PATHSPECS is set" "GIT_GLOB_PATHSPECS=1" --message-file "$MSG" -- README; then pass "ref-env-glob-pathspecs GIT_GLOB_PATHSPECS set"; fi
if assert_ref_env ref-env-config-parameters "$r" "environment|GIT_CONFIG_PARAMETERS is set" "GIT_CONFIG_PARAMETERS='core.x'='y'" --message-file "$MSG" -- README; then pass "ref-env-config-parameters GIT_CONFIG_PARAMETERS set"; fi
if assert_ref_env ref-env-config-count "$r" "environment|GIT_CONFIG_COUNT is set" "GIT_CONFIG_COUNT=0" --message-file "$MSG" -- README; then pass "ref-env-config-count GIT_CONFIG_COUNT set"; fi
ok=1
for v in GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS; do
  assert_ref_env ref-env-others "$r" "environment|$v is set" "$v=$r/.git" --message-file "$MSG" -- README || ok=0
done
[ "$ok" -eq 1 ] && pass "ref-env-others the remaining refused variables, one by one"

# --- ref-repository state ----------------------------------------------------

new_repo; r="$R"; printf 'y\n' >> "$r/README"
before="$(snap "$r")"
run_in "$r/sub" "$NOENV" --message-file "$MSG" -- README
after="$(snap "$r")"
if ref_check ref-not-toplevel "$before" "$after" "repository|top level"; then pass "ref-not-toplevel run from a subdirectory of the work tree"; fi

mkdir -p "$T/nogit/d"
RC=0
(cd "$T/nogit/d" && env "GIT_CEILING_DIRECTORIES=$T" bash "$SCRIPT" --message-file "$MSG" -- README < /dev/null > "$T/o" 2> "$T/e") || RC=$?
if [ "$RC" -eq 2 ] && grep -qF 'refused (repository): not inside a git work tree' "$T/e" && [ ! -s "$T/o" ]; then
  pass "ref-not-git run outside any repository"
else
  fail "ref-not-git: rc=$RC stderr=$(cat "$T/e")"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"; git -C "$r" checkout -q --detach HEAD
if assert_ref ref-detached "$r" "repository|detached" --message-file "$MSG" -- README; then pass "ref-detached a detached HEAD"; fi

r="$T/unborn"; mkdir -p "$r"; git -C "$r" init -q; git -C "$r" symbolic-ref HEAD refs/heads/main
git -C "$r" config user.email t@example.com; git -C "$r" config user.name t
printf 'x\n' > "$r/README"
if assert_ref ref-unborn "$r" "repository|no commit yet" --message-file "$MSG" -- README; then pass "ref-unborn a branch with no commit yet"; fi

state_case() {
  local id="$1" kind="$2" gd
  new_repo; r="$R"; printf 'y\n' >> "$r/README"
  gd="$r/.git"
  case "$kind" in
    file) git -C "$r" rev-parse HEAD > "$gd/$3" ;;
    dir) mkdir -p "$gd/$3" ;;
  esac
  if assert_ref "$id" "$r" "repository|$3" --message-file "$MSG" -- README; then pass "$id $4"; fi
}
state_case ref-merge file MERGE_HEAD "a merge in progress (MERGE_HEAD)"
state_case ref-cherry-pick file CHERRY_PICK_HEAD "a cherry-pick in progress (CHERRY_PICK_HEAD)"
state_case ref-revert file REVERT_HEAD "a revert in progress (REVERT_HEAD)"
state_case ref-rebase dir rebase-merge "a rebase in progress (rebase-merge)"
state_case ref-rebase-apply dir rebase-apply "a rebase in progress (rebase-apply)"

# --- post-* ------------------------------------------------------------------

mk_hook() { printf '%s\n' '#!/bin/sh' "$2" > "$1/.git/hooks/$3"; chmod +x "$1/.git/hooks/$3"; }

new_repo; r="$R"; printf 'y\n' >> "$r/README"; printf 'e\n' > "$r/extra.txt"
mk_hook "$r" 'git add -- extra.txt' pre-commit
base="$(git -C "$r" rev-parse HEAD)"
run_in "$r" "$NOENV" --message-file "$MSG" -- README
new="$(git -C "$r" rev-parse HEAD)"
if [ "$RC" -eq 3 ] && [ "$new" != "$base" ] && [ "$(git -C "$r" rev-parse HEAD~1)" = "$base" ] \
  && git -C "$r" diff-tree --no-commit-id --name-only -r --no-renames HEAD | grep -qxF extra.txt \
  && [ -z "$OUT" ] && printf '%s' "$ERR" | grep -qF 'extra.txt'; then
  pass "post-mismatch-extra a hook staged an extra file: exit 3, the commit is kept and named"
else
  fail "post-mismatch-extra: rc=$RC out=$OUT err=$ERR"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
mk_hook "$r" 'git update-index --force-remove -- b.txt' pre-commit
base="$(git -C "$r" rev-parse HEAD)"
run_in "$r" "$NOENV" --message-file "$MSG" -- README
new="$(git -C "$r" rev-parse HEAD)"
if [ "$RC" -eq 3 ] && [ "$new" != "$base" ] \
  && git -C "$r" diff-tree --no-commit-id --name-status -r --no-renames HEAD | grep -qx "D${TAB}b.txt" \
  && [ -z "$OUT" ]; then
  pass "post-mismatch-removal a hook staged a removal: exit 3, the commit is kept"
else
  fail "post-mismatch-removal: rc=$RC out=$OUT err=$ERR"
fi

new_repo; r="$R"; printf 'y\n' >> "$r/README"
mk_hook "$r" 'exit 1' pre-commit
base="$(git -C "$r" rev-parse HEAD)"
run_in "$r" "$NOENV" --message-file "$MSG" -- README
if [ "$RC" -eq 1 ] && [ "$(git -C "$r" rev-parse HEAD)" = "$base" ] \
  && [ "$(git -C "$r" diff --cached --name-only)" = "README" ] && [ -z "$OUT" ] \
  && printf '%s' "$ERR" | grep -qF 'git commit' && printf '%s' "$ERR" | grep -qF 'README'; then
  pass "post-commit-hook-fails a rejecting hook: exit 1, HEAD unchanged, README still staged, step and path named"
else
  fail "post-commit-hook-fails: rc=$RC out=$OUT err=$ERR"
fi

# A failing git add (the index is locked): exit 1, nothing reset, nothing committed.
new_repo; r="$R"; printf 'y\n' >> "$r/README"
: > "$r/.git/index.lock"
base="$(git -C "$r" rev-parse HEAD)"
run_in "$r" "$NOENV" --message-file "$MSG" -- README
if [ "$RC" -eq 1 ] && [ "$(git -C "$r" rev-parse HEAD)" = "$base" ] && [ -z "$OUT" ] \
  && printf '%s' "$ERR" | grep -qF 'git add'; then
  pass "post-add-fails a locked index makes git add fail: exit 1, step named, HEAD unchanged"
else
  fail "post-add-fails: rc=$RC out=$OUT err=$ERR"
fi

# A post-commit hook that moves HEAD to a new commit: the new commit's parent is
# no longer the commit HEAD was at, so it is a mismatch (exit 3), kept.
new_repo; r="$R"; printf 'y\n' >> "$r/README"
mk_hook "$r" "[ -e \"$T/once\" ] && exit 0; : > \"$T/once\"; git commit -q --allow-empty -m moved" post-commit
base="$(git -C "$r" rev-parse HEAD)"
run_in "$r" "$NOENV" --message-file "$MSG" -- README
if [ "$RC" -eq 3 ] && [ "$(git -C "$r" rev-parse HEAD~2)" = "$base" ] && [ -z "$OUT" ]; then
  pass "post-parent-moved a post-commit hook that adds a commit: exit 3, nothing reset"
else
  fail "post-parent-moved: rc=$RC out=$OUT err=$ERR"
fi

# --- help --------------------------------------------------------------------

ok=1
for f in --help -h; do
  mkdir -p "$T/helpcwd$f"
  RC=0
  (cd "$T/helpcwd$f" && bash "$SCRIPT" "$f" < /dev/null > "$T/o" 2> "$T/e") || RC=$?
  [ "$RC" -eq 0 ] || ok=0
  [ -s "$T/o" ] || ok=0
  [ -z "$(ls -A "$T/helpcwd$f")" ] || ok=0
  [ ! -s "$T/e" ] || ok=0
  grep -qF 'team-commit.sh' "$T/o" || ok=0
done
if [ "$ok" -eq 1 ]; then
  pass "help --help and -h exit 0 with usage on stdout and no write into an empty cwd"
else
  fail "help: --help or -h misbehaved"
fi

printf 'cases done; failures: %s\n' "$fails"
[ "$fails" -eq 0 ]
