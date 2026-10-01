#!/usr/bin/env bash
# bin/check-setup.sh — the read-only run-start check (T-1164, issue #640). The
# run skill's Step 0 runs it once, before the first dispatch, on both hosts
# (Claude Code and Codex CLI). It is the read-only counterpart of
# bin/team-setup.sh (the "set up shell-team" / "update shell-team" prompt):
# that script writes, this one never does, and no writer gains a check mode.
#
# What it checks, from inside the current git work tree:
#   1. both hosts: the board, the specs dir and the loop contract exist, each
#      resolved through bin/team-paths.sh --get (one raw value per key);
#   2. the Codex CLI host only: <repo>/.codex/agents exists and is in sync with
#      the installed plugin's agents (bin/check-codex-agents.sh, check-only);
#   3. by `command -v` only, that the other provider's CLI is on PATH (it is
#      never run, installed or probed); a missing one is reported as the
#      operator's decision and names neither setup prompt;
#   4. a scaffold file whose bytes differ from the installed plugin's template
#      gets a `- note:` line (never changes the exit status).
#
# Write set: none. Nothing in the repository (including .git), the plugin root,
# $HOME or $CODEX_HOME is written; the only scratch is under $TMPDIR: the
# unchanged check-codex-agents.sh regeneration, and this script's own scratch
# directory, which is the comparator chain's cwd (it holds one symlink to the
# resolved base and is removed by named file plus rmdir). The result does not
# depend on the directory the checker is started from. It never chooses, asks
# for or suggests a grant, a permission or a host setting.
#
# Usage:
#   bin/check-setup.sh [--host claude-code|codex-cli]
#   bin/check-setup.sh --help | -h
#
# Host: --host decides when given; otherwise a non-empty CODEX_THREAD_ID means
# codex-cli and anything else means claude-code (the selection bin/team-setup.sh
# makes).
#
# Exit codes (precedence 2 > 1 > 0):
#   0  nothing is unmet (only `- note:` lines may appear)
#   1  at least one item is unmet
#   2  the checker cannot evaluate: not in a git work tree, an unknown argument
#      or --host value, a resolver refusal, or check-codex-agents.sh exit 2
#
# External dependencies: bash 3.2+ and standard POSIX tools plus git.

set -euo pipefail

export LC_ALL=C

# Resolve this script's own directory (symlink-safe, physical) so the sibling
# scripts resolve regardless of cwd — the same pattern as bin/team-setup.sh.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd -P)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"

err() { printf '%s\n' "$*" >&2 || true; }
die() { err "check-setup: $*"; exit 2; }

print_help() {
  cat <<'EOF'
Usage: bin/check-setup.sh [--host claude-code|codex-cli]
       bin/check-setup.sh --help | -h

Read-only run-start check: is shell-team set up, and current, for this host?
It writes nothing anywhere and never runs the other provider's CLI.

Checks: the board, the specs dir and the loop contract (both hosts); on the
Codex CLI host also .codex/agents (present and in sync with the installed
plugin's agents); and, by `command -v` only, the other provider's CLI.

Options:
  --host <host>   claude-code or codex-cli. Default: codex-cli when
                  CODEX_THREAD_ID is set and non-empty, claude-code otherwise.
  --help, -h      Show this help and exit.

Stdout: one header line, then one "- " line per unmet item (and "- note:"
lines for scaffold files that differ from the plugin's templates). Diagnostics
and the relayed output of check-codex-agents.sh go to stderr.

Exit codes (precedence 2 > 1 > 0):
  0  nothing is unmet
  1  at least one item is unmet; the plugin's part is fixed by the prompts
     "set up shell-team" / "update shell-team", a host-side condition is the
     operator's decision
  2  cannot evaluate: not in a git work tree, an unknown argument or --host
     value, a resolver refusal, or check-codex-agents.sh could not evaluate
EOF
}

# ---------------------------------------------------------------------------
# 1. Arguments (before any git call).
# ---------------------------------------------------------------------------
HOST=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --host)
      [ "$#" -ge 2 ] || die "--host requires a value (claude-code or codex-cli)"
      HOST="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1 (see --help)"
      ;;
  esac
done
case "$HOST" in
  ''|claude-code|codex-cli) : ;;
  *) die "unknown --host value: $HOST (expected claude-code or codex-cli)" ;;
esac

if [ -n "$HOST" ]; then
  GROUND="given by --host"
elif [ -n "${CODEX_THREAD_ID:-}" ]; then
  HOST="codex-cli"
  GROUND="CODEX_THREAD_ID is set"
else
  HOST="claude-code"
  GROUND="CODEX_THREAD_ID is not set"
fi

# ---------------------------------------------------------------------------
# 2. Repository root (read-only git only). An ambient git location override
#    would silently point every git call at a different repository.
# ---------------------------------------------------------------------------
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || die "not inside a git work tree (run it from inside the repository)"
top="$(git rev-parse --show-toplevel 2>/dev/null; printf x)"
top="${top%x}"
top="${top%$'\n'}"
if [ -z "$top" ]; then die "cannot resolve the repository root"; fi
case "$top" in
  *[[:cntrl:]]*) die "the repository root contains a control character; it cannot be reported safely" ;;
esac
ROOT="$(cd "$top" && pwd -P)" || die "cannot resolve the repository root: $top"

# Operating paths come from the single resolver, one raw value per key
# (`--get`, never the `--export` form). Each call is checked: a resolver
# refusal is "cannot evaluate" (exit 2), never a pass.
getp() { bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get "$1"; }
RESOLVE_MSG="could not resolve the operating paths (see the resolver's message above)"
BASE="$(getp base)" || die "$RESOLVE_MSG"
LOOPS_DIR="$(getp loops)" || die "$RESOLVE_MSG"
SPECS_DIR="$(getp specs)" || die "$RESOLVE_MSG"
TODO_FILE="$(getp todo)" || die "$RESOLVE_MSG"
for v in "$BASE" "$LOOPS_DIR" "$SPECS_DIR" "$TODO_FILE"; do
  [ -n "$v" ] || die "the path resolver printed an empty operating path"
done

abs() { # <path as resolved> -> absolute path under the repository root
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s' "$ROOT/$1" ;;
  esac
}

UNMET=""
NOTES=""
EC1=0
EC2=0
add_unmet() { UNMET="${UNMET}- $1"$'\n'; EC1=1; }
add_note() { NOTES="${NOTES}- note: $1"$'\n'; }

# ---------------------------------------------------------------------------
# 3. Scaffold (both hosts).
# ---------------------------------------------------------------------------
CONTRACT_REL="$LOOPS_DIR/shell-team.contract.yaml"
[ -f "$(abs "$TODO_FILE")" ] \
  || add_unmet "$TODO_FILE (the board) is missing: the plugin's part; run the prompt \`set up shell-team\`"
[ -d "$(abs "$SPECS_DIR")" ] \
  || add_unmet "$SPECS_DIR (the specs dir) is missing: the plugin's part; run the prompt \`set up shell-team\`"
[ -f "$(abs "$CONTRACT_REL")" ] \
  || add_unmet "$CONTRACT_REL (the loop contract) is missing: the plugin's part; run the prompt \`set up shell-team\`"

# ---------------------------------------------------------------------------
# 4. Codex agents (Codex CLI host only; .codex is not inspected otherwise).
# ---------------------------------------------------------------------------
if [ "$HOST" = "codex-cli" ]; then
  AG="$ROOT/.codex/agents"
  if [ -d "$AG" ]; then
    # The comparator chain (check-codex-agents.sh and what it calls) runs with
    # its cwd in a scratch directory under $TMPDIR, never in the repository: a
    # bash 3.2 here-string or here-document creates its temp file in the cwd, so
    # a repository cwd would be written to (or fail on a read-only root). The
    # chain's resolver (resolve-executor.sh) looks the host binding up as
    # <base>/binding.conf relative to that cwd, and team-paths.sh refuses an
    # absolute TEAM_RUN_BASE; so the scratch directory holds a relative-named
    # symlink to the repository's resolved base, and TEAM_RUN_BASE names it. The
    # chain then reads the same binding.conf (absent, a file, or a refusing
    # occupant) that a run started at the repository root reads.
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/check-setup.XXXXXX" 2>&1)" \
      || die "cannot create the scratch directory for the comparator under ${TMPDIR:-/tmp}: $scratch"
    ln -s "$(abs "$BASE")" "$scratch/base-link" \
      || die "cannot create the base link in the scratch directory $scratch"
    c_rc=0
    c_out="$(cd "$scratch" && TEAM_RUN_BASE=base-link bash "$SCRIPT_DIR/check-codex-agents.sh" --root "$PLUGIN_ROOT" --out-dir "$AG" 2>&1)" || c_rc=$?
    rm -f "$scratch/base-link"
    rmdir "$scratch" 2>/dev/null || true
    case "$c_rc" in
      0) : ;;
      1)
        add_unmet ".codex/agents has drifted from the installed plugin's agents (or is missing a role file): the plugin's part; run the prompt \`update shell-team\`"
        err "check-setup: check-codex-agents.sh reported drift in .codex/agents (exit 1):"
        err "$c_out"
        ;;
      *)
        err "check-setup: check-codex-agents.sh could not evaluate .codex/agents (exit $c_rc):"
        err "$c_out"
        EC2=1
        ;;
    esac
  else
    add_unmet ".codex/agents is missing: the plugin's part; run the prompt \`set up shell-team\`"
  fi
fi

# ---------------------------------------------------------------------------
# 5. The other provider's CLI: presence only (`command -v`), never run.
# ---------------------------------------------------------------------------
if [ "$HOST" = "codex-cli" ]; then
  other="claude"
  other_name="Claude Code CLI"
else
  other="codex"
  other_name="Codex CLI"
fi
if ! command -v "$other" >/dev/null 2>&1; then
  add_unmet "command -v $other found nothing on PATH: the review pass needs the $other_name; installing it is the operator's decision"
fi

# ---------------------------------------------------------------------------
# 6. Template drift (note only, never changes the exit status). The board and
#    the test recipe are never compared. The set mirrors bin/team-setup.sh.
# ---------------------------------------------------------------------------
tpl_note() { # <repo-relative scaffold path> <template path>
  local rel="$1" tpl="$2" f r
  f="$(abs "$rel")"
  [ -f "$f" ] || return 0
  r=0
  cmp -s "$f" "$tpl" || r=$?
  case "$r" in
    0) : ;;
    1) add_note "$rel differs from the installed plugin's template; the prompt \`update shell-team\` lists it (a scaffold file is never rewritten)" ;;
    *) err "check-setup: cannot compare $rel with $tpl"; EC2=1 ;;
  esac
}
tpl_note "$CONTRACT_REL"              "$TEMPLATES_DIR/shell-team.contract.yaml"
tpl_note "$BASE/AGENTS.md"            "$TEMPLATES_DIR/AGENTS.md"
tpl_note "$BASE/.gitignore"           "$TEMPLATES_DIR/shell-team.gitignore"
tpl_note "$BASE/binding.conf.example" "$TEMPLATES_DIR/binding-template.conf"

# ---------------------------------------------------------------------------
# 7. Report.
# ---------------------------------------------------------------------------
printf 'shell-team setup check: host: %s (%s)\n' "$HOST" "$GROUND"
printf '%s' "$UNMET"
printf '%s' "$NOTES"

if [ "$EC2" -eq 1 ]; then
  exit 2
elif [ "$EC1" -eq 1 ]; then
  exit 1
fi
exit 0
