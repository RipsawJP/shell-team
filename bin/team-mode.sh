#!/usr/bin/env bash
# bin/team-mode.sh — the one reader of the clone's declared shell-team mode
# (T-1180, issue #711). Prints exactly one line, `tracked` or `local`.
#
# Usage:
#   bash "<plugin root>/bin/team-mode.sh"
#   bin/team-mode.sh --help | -h
#
# The declaration is the git key `shell-team.mode`, written once by the
# operator into the clone's OWN repository file (`.git/config`):
#
#   git config shell-team.mode local
#
#   local     the base dir is deliberately kept out of git in this clone;
#             check-durability.sh skips its observation and team-commit.sh
#             refuses to commit base-dir paths.
#   tracked   everything else, including an absent key: today's behaviour.
#
# Only the exact byte string `local` selects local mode (no case folding, no
# trimming). Only the clone's own repository file counts: a value at global or
# system scope, or one injected through `git -c`, GIT_CONFIG_PARAMETERS or
# GIT_CONFIG_COUNT, never selects local mode, because that would put every
# clone of every repository into local mode at once. Nothing is inferred from
# ignore rules.
#
# Outcomes:
#   0  one line on stdout: `tracked` or `local`; nothing on stderr
#   2  usage error, or git could not read the repository file (outside any
#      repository, a malformed .git/config, a repository git refuses to
#      read): nothing on stdout, a diagnostic on stderr. An unreadable
#      declaration is never read as `tracked`.
#
# External dependencies: bash 3.2+ and git.

set -euo pipefail

print_help() {
  cat <<'HELP'
Usage: bash "<plugin root>/bin/team-mode.sh"
       bin/team-mode.sh --help | -h

Print `tracked` or `local` for the current clone, read from the git key
shell-team.mode in the clone's own repository file (.git/config). Only the
exact value `local` selects local mode; an absent key, `tracked` or any other
value is `tracked`. Global or system git configuration, git -c,
GIT_CONFIG_PARAMETERS and GIT_CONFIG_COUNT never select local mode.

Declare local mode once, in the clone:   git config shell-team.mode local

Exit codes:
  0  printed `tracked` or `local`
  2  usage error, or git could not read the clone's repository file
     (nothing is printed on stdout)
HELP
}

case "$#" in
  0) ;;
  1)
    case "$1" in
      --help|-h) print_help; exit 0 ;;
      *) printf 'team-mode: usage: unexpected argument: %s (try --help)\n' "$1" >&2 || true; exit 2 ;;
    esac
    ;;
  *) printf 'team-mode: usage: too many arguments (try --help)\n' >&2 || true; exit 2 ;;
esac

command -v git > /dev/null 2>&1 || { printf 'team-mode: git is not on PATH\n' >&2 || true; exit 2; }

rc=0
val="$(git config --local --get shell-team.mode)" || rc=$?
case "$rc" in
  0) ;;
  1) val="" ;;
  *)
    printf 'team-mode: cannot read the repository configuration (git exit %s); not reading it as tracked\n' "$rc" >&2 || true
    exit 2
    ;;
esac

if [ "$rc" -eq 0 ] && [ "$val" = "local" ]; then
  printf 'local\n'
else
  printf 'tracked\n'
fi
