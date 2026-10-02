#!/usr/bin/env bash
# bin/team-setup.sh — the deterministic half of the "set up shell-team" /
# "update shell-team" prompt (skills/setup/SKILL.md), the same flow on both
# hosts (Claude Code and Codex CLI).
#
# What it does, from inside the current git work tree:
#   1. scaffolds the base dir through bin/team-init.sh (never --force, so an
#      existing board, recipe or any other scaffold file is never rewritten);
#   2. on the Codex CLI host only: appends one `.codex/agents` line to the git
#      common directory's info/exclude (only when that path is not already
#      ignored), then generates or refreshes `.codex/agents` with
#      bin/gen-codex-agents.sh (drift is judged by bin/check-codex-agents.sh);
#   3. lists scaffold files whose bytes differ from the installed plugin's
#      templates (never rewritten);
#   4. checks, by `command -v` only, that the other provider's CLI is present
#      (it is never run, installed or probed);
#   5. prints a three-part report: Done, Already in place, and what remains
#      the operator's decision.
#
# Write set (exhaustive): what team-init.sh writes for the repository root; on
# the Codex CLI host only, <repo>/.codex/agents and <git common dir>/info/
# exclude. Nothing else: no tracked file, nothing under $HOME or $CODEX_HOME,
# and none of the host's own configuration. Every host-side condition (trust,
# sandbox, commits, network, PATH, the review transfer) is reported as the
# operator's decision and never changed or proposed as a grant. When a write
# above is refused, the report carries one `- run yourself: <command>` line
# whose write set is that single artifact, for the host's own per-command
# approval or for the operator to run.
#
# Usage:
#   bin/team-setup.sh [--host claude-code|codex-cli]
#   bin/team-setup.sh --help | -h
#
# Host: --host decides when given; otherwise a non-empty CODEX_THREAD_ID means
# codex-cli and anything else means claude-code.
#
# Exit codes (precedence 2 > 3 > 1 > 0):
#   0  everything in place, nothing refused, nothing missing
#   1  a prerequisite CLI is missing (reported, never installed)
#   2  usage error, not in a git work tree, an unsafe path, a symlink where
#      setup would write, or a step that could not complete; refusals happen
#      before any write
#   3  a write was refused; its exact command is printed under the report's
#      last section
#
# External dependencies: bash 3.2+ and standard POSIX tools plus git.

set -euo pipefail

export LC_ALL=C

# Resolve this script's own directory (symlink-safe, physical) so the sibling
# scripts resolve regardless of cwd — the same pattern as bin/team-init.sh.
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
die() { err "team-setup: $*"; exit 2; }

print_help() {
  cat <<'EOF'
Usage: bin/team-setup.sh [--host claude-code|codex-cli]
       bin/team-setup.sh --help | -h

Set up or update shell-team in the current git repository. The same flow runs
on both hosts; re-running it after a plugin upgrade is the update, and a second
run changes nothing.

It scaffolds the base dir through team-init.sh (existing files are never
rewritten). On the Codex CLI host it also generates or refreshes
.codex/agents and ignores it through the git common directory's info/exclude.
It writes nothing else: no tracked file, nothing under $HOME or $CODEX_HOME,
and none of the host's own configuration.

Options:
  --host <host>   claude-code or codex-cli. Default: codex-cli when
                  CODEX_THREAD_ID is set and non-empty, claude-code otherwise.
  --help, -h      Show this help and exit.

Stdout: one header line, then "Done:", "Already in place:" and "Remains the
operator's decision:" (each item a "- " line). Diagnostics go to stderr.

Exit codes (precedence 2 > 3 > 1 > 0):
  0  everything in place
  1  the other provider's CLI is missing from PATH (reported only)
  2  usage error, not in a git work tree, an unsafe path (a single quote or a
     control character), a symlink where setup would write, or a step that
     could not complete
  3  a write was refused; the report prints one exact command per refused
     write, for the host's own per-command approval or for you to run
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
# 2. Repository root. An ambient git location override would silently point
#    every git call below at a different repository, so it is dropped.
# ---------------------------------------------------------------------------
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || die "not inside a git work tree (run it from inside the repository to set up)"
# The sentinel keeps a trailing newline of the path itself (command substitution
# would strip it and let the path slip past unsafe_path below).
top="$(git rev-parse --show-toplevel 2>/dev/null; printf x)"
top="${top%x}"
top="${top%$'\n'}"
if [ -z "$top" ]; then die "cannot resolve the repository root; nothing was written"; fi
case "$top" in
  *[[:cntrl:]]*) die "the repository root contains a single quote or a control character, so a command naming it cannot be quoted safely; nothing was written" ;;
esac
ROOT="$(cd "$top" && pwd -P)" || die "cannot resolve the repository root: $top"

# ---------------------------------------------------------------------------
# 3. Refusals before any write: a path that a printed command could not quote
#    safely (a single quote or a control character) is refused outright.
# ---------------------------------------------------------------------------
unsafe_path() {
  case "$1" in
    *\'*) return 0 ;;
    *[[:cntrl:]]*) return 0 ;;
  esac
  return 1
}
if unsafe_path "$ROOT"; then
  die "the repository root contains a single quote or a control character, so a command naming it cannot be quoted safely; nothing was written"
fi
if unsafe_path "$PLUGIN_ROOT"; then
  die "the plugin root contains a single quote or a control character, so a command naming it cannot be quoted safely; nothing was written"
fi

# Operating paths come from the single resolver, one raw value per key
# (`--get`, never the `--export` form, whose shell escaping is not the path).
# Each call is checked, so a resolver refusal (an invalid $TEAM_RUN_BASE) stops
# here before any write.
getp() { bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --get "$1"; }
RESOLVE_MSG="could not resolve the operating paths (see the resolver's message above); nothing was written"
BASE="$(getp base)" || die "$RESOLVE_MSG"
LOOPS_DIR="$(getp loops)" || die "$RESOLVE_MSG"
RUNS_DIR="$(getp runs)" || die "$RESOLVE_MSG"
RETROS_DIR="$(getp retros)" || die "$RESOLVE_MSG"
REVIEWS_DIR="$(getp reviews)" || die "$RESOLVE_MSG"
SPECS_DIR="$(getp specs)" || die "$RESOLVE_MSG"
PROV_DIR="$(getp provenance)" || die "$RESOLVE_MSG"
INTERV_DIR="$(getp interventions)" || die "$RESOLVE_MSG"
TODO_FILE="$(getp todo)" || die "$RESOLVE_MSG"
LESSONS_FILE="$(getp lessons)" || die "$RESOLVE_MSG"
for v in "$BASE" "$LOOPS_DIR" "$RUNS_DIR" "$RETROS_DIR" "$REVIEWS_DIR" "$SPECS_DIR" \
  "$PROV_DIR" "$INTERV_DIR" "$TODO_FILE" "$LESSONS_FILE"; do
  [ -n "$v" ] || die "the path resolver printed an empty operating path; nothing was written"
done

EXCL=""
if [ "$HOST" = "codex-cli" ]; then
  common="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)" \
    || die "cannot resolve the git common directory; nothing was written"
  case "$common" in
    /*) : ;;
    *) common="$ROOT/$common" ;;
  esac
  common="$(cd "$common" 2>/dev/null && pwd -P)" \
    || die "the git common directory does not exist: $common; nothing was written"
  if unsafe_path "$common"; then
    die "the git common directory contains a single quote or a control character, so a command naming it cannot be quoted safely; nothing was written"
  fi
  EXCL="$common/info/exclude"
fi

# A directory this run writes into must not be a symlink at any component below
# the repository root: mkdir -p and the writers would follow it and write
# outside the repository. Refused before any write; the operator decides (no
# single artifact command exists for a repository that commits such a link).
no_symlink_below() { # <base-dir> <relative-path>
  local acc="$1" part rest="$2"
  while [ -n "$rest" ]; do
    part="${rest%%/*}"
    if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    [ -n "$part" ] || continue
    acc="$acc/$part"
    if [ -L "$acc" ]; then
      die "$acc is a symlink, and setup writes under it; refusing so nothing is written outside the repository (nothing was written). Whether to replace the symlink with a real directory is the operator's decision"
    fi
  done
  return 0
}
for rel in "$BASE" "$LOOPS_DIR" "$RUNS_DIR" "$RETROS_DIR" "$REVIEWS_DIR" \
  "$SPECS_DIR" "$PROV_DIR" "$INTERV_DIR"; do
  no_symlink_below "$ROOT" "$rel"
done
if [ "$HOST" = "codex-cli" ]; then
  no_symlink_below "$ROOT" ".codex/agents"
  if [ -L "${EXCL%/exclude}" ] || [ -L "$EXCL" ]; then
    die "${EXCL%/exclude} or $EXCL is a symlink, and setup appends to it; refusing so nothing is written outside the git directory (nothing was written). Whether to replace it is the operator's decision"
  fi
fi

# One containment check over every target this run (and the tools it calls)
# writes, before the first write. The check resolves the target physically: the
# deepest existing ancestor is resolved with `cd -P`, the not-yet-existing
# remainder is appended, and the result must be the allowed root or sit under
# it. The per-shape symlink refusals above stay as a fail-closed first layer;
# this check is the one that does not depend on how a link is spelled.
contained() { # <target-path (absolute)> <allowed-root (physical)>
  local t="$1" allow="$2" d rest="" phys parent
  d="$t"
  while [ ! -e "$d" ] && [ ! -L "$d" ]; do
    rest="/${d##*/}$rest"
    d="${d%/*}"
    [ -n "$d" ] || d="/"
    [ "$d" != "/" ] || break
  done
  if [ -L "$d" ]; then
    die "$d is a symlink, and setup writes at or under $t; refusing so nothing is written outside the repository (nothing was written). Whether to replace the symlink is the operator's decision"
  fi
  if [ -d "$d" ]; then
    phys="$(cd -P -- "$d" 2>/dev/null && pwd -P)" || die "cannot resolve $d physically; nothing was written"
  else
    parent="${d%/*}"
    [ -n "$parent" ] || parent="/"
    phys="$(cd -P -- "$parent" 2>/dev/null && pwd -P)" || die "cannot resolve $parent physically; nothing was written"
    phys="${phys%/}/${d##*/}"
  fi
  phys="${phys%/}$rest"
  if [ "$phys" = "$allow" ]; then return 0; fi
  case "$phys" in
    "$allow"/*) return 0 ;;
  esac
  die "$t resolves to $phys, outside $allow, and setup would write there; refusing (nothing was written)"
}
for rel in "$BASE" "$LOOPS_DIR" "$RUNS_DIR" "$RETROS_DIR" "$REVIEWS_DIR" \
  "$SPECS_DIR" "$PROV_DIR" "$INTERV_DIR" "$TODO_FILE" "$LESSONS_FILE" \
  "$LOOPS_DIR/shell-team.contract.yaml" "$BASE/AGENTS.md" "$BASE/test-recipe.md" \
  "$BASE/.gitignore" "$BASE/binding.conf.example"; do
  contained "$ROOT/$rel" "$ROOT"
done
if [ "$HOST" = "codex-cli" ]; then
  contained "$ROOT/.codex" "$ROOT"
  contained "$ROOT/.codex/agents" "$ROOT"
  contained "$(dirname "$EXCL")" "$common"
  contained "$EXCL" "$common"
fi

# ---------------------------------------------------------------------------
# Report state. Items are newline-joined "- " lines (a string, not an array:
# bash 3.2 under `set -u` rejects expanding an empty array).
# ---------------------------------------------------------------------------
DONE=""
INPLACE=""
REMAINS=""
EC2=0
EC3=0
EC1=0
nl=$'\n'
add_done()    { DONE="${DONE}- $1${nl}"; }
add_inplace() { INPLACE="${INPLACE}- $1${nl}"; }
add_remains() { REMAINS="${REMAINS}- $1${nl}"; }
q() { printf "'%s'" "$1"; }
# refused <command>: one exact single-artifact command for a refused write.
refused() {
  EC3=1
  add_remains "run yourself: $1"
}

# ---------------------------------------------------------------------------
# 4. Scaffold through team-init.sh (never --force: --force would overwrite the
#    board).
# ---------------------------------------------------------------------------
ti_rc=0
ti_out="$(bash "$SCRIPT_DIR/team-init.sh" "$ROOT" 2>&1)" || ti_rc=$?
n_created="$(printf '%s\n' "$ti_out" | grep -c '^created: ' || true)"
n_skipped="$(printf '%s\n' "$ti_out" | grep -c '^WARN: skipped existing file:' || true)"
if [ "$ti_rc" -eq 2 ]; then
  err "team-setup: team-init.sh refused (exit 2):"
  err "$ti_out"
  EC2=1
elif [ "$ti_rc" -ne 0 ]; then
  err "team-setup: team-init.sh could not write the scaffold (exit $ti_rc):"
  err "$ti_out"
  refused "bash $(q "$SCRIPT_DIR/team-init.sh") $(q "$ROOT")"
fi
if [ "$n_created" -gt 0 ]; then
  add_done "created $n_created scaffold file(s) under $BASE/ through team-init.sh"
fi
if [ "$n_skipped" -gt 0 ]; then
  add_inplace "$BASE/ scaffold: $n_skipped file(s) were already present and were left as they are"
elif [ "$n_created" -eq 0 ] && [ "$ti_rc" -eq 0 ]; then
  add_inplace "$BASE/ scaffold is already in place"
fi

# ---------------------------------------------------------------------------
# 5. Codex CLI host: the exclude line first (so generated files never show as
#    untracked), then .codex/agents.
# ---------------------------------------------------------------------------
if [ "$HOST" = "codex-cli" ]; then
  AG="$ROOT/.codex/agents"
  ign_rc=0
  git -C "$ROOT" check-ignore -q -- ".codex/agents/shell-team-setup-probe" 2>/dev/null || ign_rc=$?
  line_there=0
  if [ -f "$EXCL" ] && grep -qxF '.codex/agents' "$EXCL" 2>/dev/null; then
    line_there=1
  fi
  if [ "$ign_rc" -ne 0 ] && [ "$ign_rc" -ne 1 ]; then
    err "team-setup: git check-ignore could not evaluate .codex/agents (exit $ign_rc)"
    EC2=1
  elif [ "$ign_rc" -eq 0 ] || [ "$line_there" -eq 1 ]; then
    add_inplace ".codex/agents is already ignored by an existing rule"
  else
    lead=""
    if [ -s "$EXCL" ] && [ "$(tail -c 1 "$EXCL" 2>/dev/null | wc -l | tr -d ' ')" = "0" ]; then
      lead="$nl"
    fi
    exdir="$(dirname "$EXCL")"
    if { mkdir -p "$exdir" && printf '%s.codex/agents\n' "$lead" >> "$EXCL"; } 2>/dev/null; then
      add_done "appended .codex/agents to $EXCL"
    else
      pre=""
      if [ ! -d "$exdir" ]; then
        pre="mkdir -p $(q "$exdir") && "
      fi
      if [ -n "$lead" ]; then
        refused "${pre}printf '\\n.codex/agents\\n' >> $(q "$EXCL")"
      else
        refused "${pre}printf '.codex/agents\\n' >> $(q "$EXCL")"
      fi
    fi
  fi

  regen_cmd="bash $(q "$SCRIPT_DIR/gen-codex-agents.sh") --out-dir $(q "$AG")"
  if [ -e "$AG" ] || [ -L "$AG" ]; then
    c_rc=0
    c_err="$(bash "$SCRIPT_DIR/check-codex-agents.sh" --root "$PLUGIN_ROOT" --out-dir "$AG" 2>&1 >/dev/null)" || c_rc=$?
    if [ "$c_rc" -eq 0 ]; then
      add_inplace ".codex/agents is in sync with the installed plugin's agents"
    elif [ "$c_rc" -eq 1 ]; then
      g_rc=0
      g_err="$(bash "$SCRIPT_DIR/gen-codex-agents.sh" --root "$PLUGIN_ROOT" --out-dir "$AG" 2>&1 >/dev/null)" || g_rc=$?
      if [ "$g_rc" -eq 0 ]; then
        r_rc=0
        bash "$SCRIPT_DIR/check-codex-agents.sh" --root "$PLUGIN_ROOT" --out-dir "$AG" >/dev/null 2>&1 || r_rc=$?
        if [ "$r_rc" -eq 0 ]; then
          add_done "regenerated .codex/agents (it had drifted from the installed plugin's agents)"
        else
          err "team-setup: .codex/agents still differs after regeneration (check exit $r_rc)"
          EC2=1
        fi
      elif [ -d "$AG" ] && [ ! -w "$AG" ]; then
        refused "$regen_cmd"
      else
        err "team-setup: gen-codex-agents.sh failed (exit $g_rc): $g_err"
        EC2=1
      fi
    else
      err "team-setup: check-codex-agents.sh could not evaluate .codex/agents (exit $c_rc): $c_err"
      EC2=1
    fi
  else
    had_codex=0
    if [ -e "$ROOT/.codex" ] || [ -L "$ROOT/.codex" ]; then
      had_codex=1
    fi
    if mkdir -p "$AG" 2>/dev/null; then
      g_rc=0
      g_err="$(bash "$SCRIPT_DIR/gen-codex-agents.sh" --root "$PLUGIN_ROOT" --out-dir "$AG" 2>&1 >/dev/null)" || g_rc=$?
      if [ "$g_rc" -eq 0 ]; then
        add_done "generated .codex/agents from the installed plugin's agents"
      else
        # Nothing was written by the generator on a refusal: take back the
        # empty directories this run created, so no half-state is left.
        rmdir "$AG" 2>/dev/null || true
        if [ "$had_codex" -eq 0 ]; then
          rmdir "$ROOT/.codex" 2>/dev/null || true
        fi
        err "team-setup: gen-codex-agents.sh failed (exit $g_rc): $g_err"
        EC2=1
      fi
    else
      refused "$regen_cmd"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 6. Template drift (reported, never rewritten). The board and the test recipe
#    are never compared: they are edited by the adopter by design. This mapping
#    mirrors the template variables in bin/team-init.sh; tests/setup/run.sh
#    locks it by comparing a fresh scaffold against these templates.
# ---------------------------------------------------------------------------
tpl_drift() {
  local rel="$1" tpl="$2" f r
  f="$ROOT/$rel"
  [ -f "$f" ] || return 0
  r=0
  cmp -s "$f" "$tpl" || r=$?
  case "$r" in
    0) : ;;
    1) add_remains "$rel differs from the installed plugin's template; setup never rewrites an existing scaffold file, so keep or merge it as you decide" ;;
    *) err "team-setup: cannot compare $rel with $tpl"; EC2=1 ;;
  esac
}
tpl_drift "$LOOPS_DIR/shell-team.contract.yaml" "$TEMPLATES_DIR/shell-team.contract.yaml"
tpl_drift "$BASE/AGENTS.md"                     "$TEMPLATES_DIR/AGENTS.md"
tpl_drift "$BASE/.gitignore"                    "$TEMPLATES_DIR/shell-team.gitignore"
tpl_drift "$BASE/binding.conf.example"          "$TEMPLATES_DIR/binding-template.conf"

# ---------------------------------------------------------------------------
# 7. Prerequisites: presence only (`command -v`). The other provider's CLI is
#    never run, installed or probed: a model call is a network call, and inside
#    a sandbox it can print a misleading "Not logged in".
# ---------------------------------------------------------------------------
if [ "$HOST" = "codex-cli" ]; then
  other="claude"
  other_name="Claude Code CLI"
else
  other="codex"
  other_name="Codex CLI"
fi
if command -v "$other" >/dev/null 2>&1; then
  add_inplace "$other is on PATH (command -v $other); the review pass can call the $other_name"
  if [ "$HOST" = "codex-cli" ]; then
    add_remains "check yourself that the Claude Code CLI answers: claude -p \"reply with the single word ok\" (setup never runs it: it is a network and model call, and inside a sandbox it can print a misleading \"Not logged in\")"
  fi
else
  EC1=1
  add_remains "command -v $other found nothing on PATH: the review pass needs the $other_name; setup never installs anything"
fi

# ---------------------------------------------------------------------------
# 8. Host-side conditions: always listed, each saying what it is needed for.
#    They are the operator's decisions; they never change the exit status.
# ---------------------------------------------------------------------------
if [ "$HOST" = "codex-cli" ]; then
  add_remains "repository trust: project agents in .codex/agents are discovered only when the host trusts this repository; whether to trust it is your decision (in the codex-cli 0.159.3 runs relayed to this plugin, the host's own first-launch trust prompt sufficed)"
  add_remains "commits: the loop's roles commit inside this repository, which needs write access to the git common directory ${EXCL%/info/exclude}; what the session may write there is your decision"
  add_remains "network for the review pass: the review's claude -p call reaches the other provider over the network; in the codex-cli 0.159.3 runs relayed to this plugin it ran outside the sandbox under the host's own per-command approval, so no network change was needed for it; whether to allow it is your decision"
  add_remains "PATH: spawned roles call the plugin's scripts by bare name, which needs $PLUGIN_ROOT/bin on PATH; whether that is needed is unmeasured; it is your decision"
  review_to="Claude"
else
  add_remains "sandbox: the reviewer's codex exec call has to run outside the session's sandbox or under the host's own per-command approval; how your sandbox treats it is your decision"
  add_remains "commits: the loop's roles commit inside this repository, which needs write access to its git directory; what the session may write there is your decision"
  review_to="Codex"
fi
add_remains "base directory in git: whether to track $BASE/ in version control is your decision; setup stages and commits nothing"
add_remains "review transfer: the review pass sends repository content to $review_to, the other provider; approving that transfer is your decision, and setup does not authorize it"

# ---------------------------------------------------------------------------
# 9. Report.
# ---------------------------------------------------------------------------
ver=""
if [ -r "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  ver="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)" || ver=""
fi
case "$ver" in
  ''|*[!A-Za-z0-9._+-]*) ver="unknown" ;;
esac

print_section() {
  printf '%s\n' "$1"
  if [ -n "$2" ]; then
    printf '%s' "$2"
  else
    printf '%s\n' "- none"
  fi
}
printf 'shell-team setup (plugin version %s); host: %s (%s)\n' "$ver" "$HOST" "$GROUND"
print_section "Done:" "$DONE"
print_section "Already in place:" "$INPLACE"
print_section "Remains the operator's decision:" "$REMAINS"

if [ "$EC2" -eq 1 ]; then
  exit 2
elif [ "$EC3" -eq 1 ]; then
  exit 3
elif [ "$EC1" -eq 1 ]; then
  exit 1
fi
exit 0
