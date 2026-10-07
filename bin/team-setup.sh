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
#   5. prints a five-part report: Done, Already in place, what remains the
#      operator's decision, Required, and Notice.
#
# The report's sections (each item a `- ` line, an empty section `- none`):
#   Done:      what this run wrote.
#   Already in place:  what was already so, with what was read. On the Claude
#      Code host that includes a sandbox entry found in one of the three
#      settings files setup reads (see below), stated as read, with its effect
#      on the session left undetermined, and the base directory when git does
#      not ignore it and its anchor is committed.
#   Remains the operator's decision:  the host-side conditions setup cannot
#      read or must not choose (trust, commits, network, PATH on the Codex CLI
#      host; the sandbox when no entry was read, and commits, on the Claude
#      Code host), each saying that setup could not determine it and what it is
#      needed for.
#   Required:  the one action with a single correct answer: the base directory
#      (and, in the legacy layout, an outside specs directory) must not be
#      ignored by git and must be committed. The blocking rule is named as
#      <source>:<line> only (its pattern text comes from a possibly untrusted
#      repository and is never printed); the re-include line `!<dir>/` is
#      printed only for a rule from the global excludes file or info/exclude
#      whose pattern is exactly the directory's own path; the printed command
#      stages the directories (and the root .gitignore with a re-include line).
#   Notice:  the review pass sends repository content to the other provider
#      (information; nothing for setup to decide).
#
# Read set (exhaustive, read-only): on the Claude Code host the user scope
# $HOME/.claude/settings.json (skipped when CLAUDE_CONFIG_DIR is set and
# non-empty), the project scope <repo>/.claude/settings.json and the local scope
# <repo>/.claude/settings.local.json, each only to see whether sandbox.
# excludedCommands holds the exact element "codex *"; plus git (check-ignore,
# ls-tree, config, rev-parse), which setup only asks. A file it cannot read,
# parse or recognise is reported as not determined, never as not met.
#
# Write set (exhaustive): what team-init.sh writes for the repository root; on
# the Codex CLI host only, <repo>/.codex/agents and <git common dir>/info/
# exclude. Nothing else: no tracked file, nothing under $HOME or $CODEX_HOME,
# no host settings file, no root .gitignore, no index write. No host-side
# condition is chosen, composed, defaulted or proposed as a grant. When a write
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

Stdout: one header line, then five sections, each item a "- " line and an
empty section printed as "- none":
  Done:
  Already in place:
  Remains the operator's decision:
  Required:
  Notice:
Required holds the base directory when git ignores it or it is not committed;
Notice holds the review pass's repository-content notice. Diagnostics go to
stderr.

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
REQUIRED=""
NOTICE=""
EC2=0
EC3=0
EC1=0
nl=$'\n'
add_done()    { DONE="${DONE}- $1${nl}"; }
add_inplace() { INPLACE="${INPLACE}- $1${nl}"; }
add_remains() { REMAINS="${REMAINS}- $1${nl}"; }
add_required() { REQUIRED="${REQUIRED}- $1${nl}"; }
add_notice()  { NOTICE="${NOTICE}- $1${nl}"; }
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

  NEWSESS=0
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
          NEWSESS=1
        else
          err "team-setup: .codex/agents still differs after regeneration (check exit $r_rc)"
          EC2=1
        fi
      elif [ -d "$AG" ] && [ ! -w "$AG" ]; then
        refused "$regen_cmd"
        NEWSESS=1
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
        NEWSESS=1
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
      NEWSESS=1
    fi
  fi
  # Codex does not pick up project agents generated during a running session
  # (relayed evidence: docs/adopting.md). Printed once, only when this run
  # generated, regenerated or printed the generator command for .codex/agents.
  if [ "$NEWSESS" -eq 1 ]; then
    add_remains "new Codex session: the roles in .codex/agents take effect in a new Codex session started in this repository (Codex does not pick up agents generated during a running session); start the loop there"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Template drift (reported, never rewritten). The board and the test recipe
#    are never compared: they are edited by the adopter by design. This mapping
#    mirrors the template variables in bin/team-init.sh; tests/setup/run.sh
#    locks it by comparing a fresh scaffold against these templates.
# ---------------------------------------------------------------------------
tpl_drift() { # <repo-relative scaffold path> <template path> [<previous release's template>]
  local rel="$1" tpl="$2" prior="${3:-}" f r
  f="$ROOT/$rel"
  [ -f "$f" ] || return 0
  r=0
  cmp -s "$f" "$tpl" || r=$?
  # T-1176: a copy byte-identical to the previous release's template is not
  # drift either (only the contract gets this allowance, and only that one
  # prior byte sequence: when the template changes again, the file named by
  # the caller is replaced by the then-previous release's bytes, never
  # accumulated).
  if [ "$r" -eq 1 ] && [ -n "$prior" ] && [ -f "$prior" ]; then
    r=0
    cmp -s "$f" "$prior" || r=$?
  fi
  case "$r" in
    0) : ;;
    1) add_remains "$rel differs from the installed plugin's template; setup never rewrites an existing scaffold file, so keep or merge it as you decide" ;;
    *) err "team-setup: cannot compare $rel with $tpl"; EC2=1 ;;
  esac
}
tpl_drift "$LOOPS_DIR/shell-team.contract.yaml" "$TEMPLATES_DIR/shell-team.contract.yaml" "$TEMPLATES_DIR/prior/shell-team.contract.v2.8.6.txt"
tpl_drift "$BASE/AGENTS.md"                     "$TEMPLATES_DIR/AGENTS.md"
tpl_drift "$BASE/.gitignore"                    "$TEMPLATES_DIR/shell-team.gitignore"
tpl_drift "$BASE/binding.conf.example"          "$TEMPLATES_DIR/binding-template.conf"

# T-1176 D2: in legacy row R4 (tasks/specs, plus a docs/specs holding nothing
# but .gitkeep) the specs dir resolves to tasks/specs; say once that the
# leftover docs/specs/ is not read. Fixed text only: nothing read from inside
# docs/specs is printed, and no command is proposed. The row comes from the
# resolver's own rule text, so this never fires in another row or layout.
_prt="$(bash "$SCRIPT_DIR/team-paths.sh" --root "$ROOT" --print)" || die "$RESOLVE_MSG"
case "$_prt" in
  *"(rule: legacy R4 "*) add_inplace "specs dir: specs are read from tasks/specs/; the docs/specs/ beside it holds only .gitkeep and is not read (setup leaves it as it is)" ;;
esac

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
# 8. Host-side conditions, the base directory and the notice. Nothing here
#    writes, and none of it changes the exit status except a git error (2).
# ---------------------------------------------------------------------------

# 8a. Settings reader (Claude Code host). A pure-awk strict JSON reader: it
#     answers YES only when the whole document is valid JSON (no trailing
#     comma, no duplicate or nested look-alike key), has exactly one "sandbox"
#     key (at top level, an object) holding exactly one "excludedCommands" key
#     (a direct member, an array) with the exact string element "codex *".
#     Anything it cannot classify with certainty is NO. The final conjuncts
#     topsb, sbobj, direx and exarr (and the top-level "{" test) are
#     defence-in-depth: each is implied by `found` together with the nsb and
#     nex counts, because `found` is only set on the role path top-level
#     sandbox object -> direct excludedCommands array. Their removal mutants
#     are equivalent, so no fixture can tell them apart.
# shellcheck disable=SC2016 # an awk program: nothing in it is meant to expand
SBX_AWK='
function skipws(   c) {
  while (pos <= n) {
    c = substr(s, pos, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++
    else break
  }
}
function pstring(   c, e, start) {
  if (substr(s, pos, 1) != "\"") { bad = 1; return "" }
  pos++
  start = pos
  while (pos <= n) {
    c = substr(s, pos, 1)
    if (c == "\"") { pos++; return substr(s, start, pos - 1 - start) }
    if (c == "\\") {
      e = substr(s, pos + 1, 1)
      if (e == "u") {
        if (substr(s, pos + 2, 4) !~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) { bad = 1; return "" }
        pos += 6
      } else if (e != "" && index("\"\\/bfnrt", e) > 0) {
        pos += 2
      } else { bad = 1; return "" }
      continue
    }
    if (c < " ") { bad = 1; return "" }
    pos++
  }
  bad = 1
  return ""
}
function pobject(depth, role,   k, c, crole) {
  pos++
  skipws()
  if (substr(s, pos, 1) == "}") { pos++; return }
  while (1) {
    skipws()
    k = pstring()
    if (bad) return
    skipws()
    if (substr(s, pos, 1) != ":") { bad = 1; return }
    pos++
    crole = 0
    if (k == "sandbox") { nsb++; if (depth == 0) { topsb++; crole = 1 } }
    if (k == "excludedCommands") { nex++; if (role == 1) { direx++; crole = 2 } }
    pvalue(depth + 1, crole)
    if (bad) return
    if (crole == 1) sbobj = (vt == "o")
    if (crole == 2) exarr = (vt == "a")
    skipws()
    c = substr(s, pos, 1)
    if (c == ",") { pos++; continue }
    if (c == "}") { pos++; return }
    bad = 1
    return
  }
}
function parray(depth, role,   c) {
  pos++
  skipws()
  if (substr(s, pos, 1) == "]") { pos++; return }
  while (1) {
    pvalue(depth + 1, 0)
    if (bad) return
    if (role == 2 && vt == "s" && lastraw == "codex *") found = 1
    skipws()
    c = substr(s, pos, 1)
    if (c == ",") { pos++; continue }
    if (c == "]") { pos++; return }
    bad = 1
    return
  }
}
function pvalue(depth, role,   c, t) {
  if (bad) return
  if (depth > 40) { bad = 1; return }
  skipws()
  if (pos > n) { bad = 1; return }
  c = substr(s, pos, 1)
  if (c == "{") { pobject(depth, role); vt = "o"; return }
  if (c == "[") { parray(depth, role); vt = "a"; return }
  if (c == "\"") { lastraw = pstring(); vt = "s"; return }
  if (substr(s, pos, 4) == "true") { pos += 4; vt = "l"; return }
  if (substr(s, pos, 5) == "false") { pos += 5; vt = "l"; return }
  if (substr(s, pos, 4) == "null") { pos += 4; vt = "l"; return }
  if (c == "-" || (c >= "0" && c <= "9")) {
    t = substr(s, pos, 64)
    if (match(t, /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/)) { pos += RLENGTH; vt = "n"; return }
  }
  bad = 1
}
{ s = s $0 "\n" }
END {
  n = length(s)
  pos = 1
  skipws()
  if (substr(s, pos, 1) != "{") bad = 1
  else pvalue(0, 3)
  if (!bad) { skipws(); if (pos <= n) bad = 1 }
  if (!bad && nsb == 1 && topsb == 1 && sbobj && nex == 1 && direx == 1 && exarr && found) print "YES"
  else print "NO"
}
'
# sandbox_entry_in <file>: 0 only when the file is the recognised shape.
sandbox_entry_in() {
  local f="$1" out n_all n_nonul
  if unsafe_path "$f"; then return 1; fi
  [ -f "$f" ] && [ -r "$f" ] || return 1
  n_all="$(wc -c < "$f" 2>/dev/null | tr -d ' ')" || return 1
  n_nonul="$(tr -d '\000' < "$f" 2>/dev/null | wc -c | tr -d ' ')" || return 1
  [ -n "$n_all" ] && [ "$n_all" = "$n_nonul" ] || return 1
  # A text encoding a real JSON parser would refuse is not read (checked when
  # iconv is available; the strict grammar below is the primary guard).
  if command -v iconv > /dev/null 2>&1; then
    iconv -f UTF-8 -t UTF-8 < "$f" > /dev/null 2>&1 || return 1
  fi
  out="$(awk "$SBX_AWK" < "$f" 2>/dev/null)" || return 1
  [ "$out" = "YES" ]
}

SBX_FILE=""
if [ "$HOST" = "claude-code" ]; then
  if [ -z "${CLAUDE_CONFIG_DIR:-}" ] && [ -n "${HOME:-}" ]; then
    if sandbox_entry_in "$HOME/.claude/settings.json"; then SBX_FILE="$HOME/.claude/settings.json"; fi
  fi
  if [ -z "$SBX_FILE" ] && sandbox_entry_in "$ROOT/.claude/settings.json"; then
    SBX_FILE="$ROOT/.claude/settings.json"
  fi
  if [ -z "$SBX_FILE" ] && sandbox_entry_in "$ROOT/.claude/settings.local.json"; then
    SBX_FILE="$ROOT/.claude/settings.local.json"
  fi
fi

if [ "$HOST" = "codex-cli" ]; then
  add_remains "repository trust: project agents in .codex/agents are discovered only when the host trusts this repository; whether to trust it is your decision (in the codex-cli 0.159.3 runs relayed to this plugin, the host's own first-launch trust prompt sufficed)"
  add_remains "commits: the loop's roles commit inside this repository through one invocation of bin/team-commit.sh, which needs write access to the git common directory ${EXCL%/info/exclude}; the run asks for the host's per-command approval of that identical invocation, and what the session may write there is your decision"
  add_remains "network for the review pass: the review's claude -p call reaches the other provider over the network; in the codex-cli 0.159.3 runs relayed to this plugin it ran outside the sandbox under the host's own per-command approval, so no network change was needed for it; whether to allow it is your decision"
  add_remains "PATH: spawned roles call the plugin's scripts by bare name, which needs $PLUGIN_ROOT/bin on PATH; whether that is needed is unmeasured; it is your decision"
  review_to="Claude (Anthropic)"
else
  if [ -n "$SBX_FILE" ]; then
    add_inplace "sandbox: $SBX_FILE has \"codex *\" in sandbox.excludedCommands; whether this session applies it was not determined"
  else
    add_remains "sandbox: setup could not determine whether the reviewer's codex exec call runs outside the session's sandbox (no readable settings entry showed it); the review pass needs that call to run outside the sandbox or under the host's own per-command approval, and how your sandbox treats it is your decision"
  fi
  add_remains "commits: setup could not determine whether this session may write this repository's git directory (a read-only check cannot establish it, and setup writes nothing to find out); the loop's roles commit inside this repository, which needs that write access; what the session may write there is your decision"
  review_to="Codex (OpenAI)"
fi
add_notice "the review pass sends repository content to $review_to, the other provider; this is information, there is nothing for setup to configure"

# 8b. The base directory (and an outside specs directory) in git. One required
#     action with a single correct answer: git must not ignore it and its
#     anchor must be committed. Read-only: check-ignore, ls-tree, config and
#     rev-parse only.
PROBE_MD="setup-probe.md"
# np <path>: collapse repeated slashes and drop a trailing one (the resolver
# echoes TEAM_RUN_BASE as given, so `.custom/` arrives as `.custom//todo.md`).
np() {
  local p="$1" sl="/" dsl="//"
  while [ "${p//$dsl/$sl}" != "$p" ]; do p="${p//$dsl/$sl}"; done
  printf '%s' "${p%/}"
}
N_BASE="$(np "$BASE")"
N_SPECS="$(np "$SPECS_DIR")"
REQ_DIRS=("$N_BASE")
REQ_ANCHOR=("$(np "$TODO_FILE")")
case "$N_SPECS" in
  "$N_BASE"|"$N_BASE"/*) : ;;
  *) REQ_DIRS[1]="$N_SPECS"; REQ_ANCHOR[1]="$N_SPECS/.gitkeep" ;;
esac
probes=()
# Every other directory the loop commits records into, when it sits under the
# base (specs, retros, reviews, provenance, interventions), is probed with the
# directory itself and a not-yet-existing .md path; so are the lessons file and
# the root .gitignore the printed command may stage. runs/ is ignored by design.
for rel in "$SPECS_DIR" "$RETROS_DIR" "$REVIEWS_DIR" "$PROV_DIR" "$INTERV_DIR"; do
  rel="$(np "$rel")"
  case "$rel" in
    "$N_BASE"/*) probes[${#probes[@]}]="$rel"; probes[${#probes[@]}]="$rel/$PROBE_MD" ;;
  esac
done
rel="$(np "$LESSONS_FILE")"
case "$rel" in
  "$N_BASE"/*) probes[${#probes[@]}]="$rel" ;;
esac
probes[${#probes[@]}]=".gitignore"
for ((ri = 0; ri < ${#REQ_DIRS[@]}; ri++)); do
  rd="${REQ_DIRS[$ri]}"
  probes[${#probes[@]}]="$rd"
  probes[${#probes[@]}]="${REQ_ANCHOR[$ri]}"
  probes[${#probes[@]}]="$rd/$PROBE_MD"
  if [ "$ri" -eq 0 ]; then
    probes[${#probes[@]}]="$(np "$LOOPS_DIR")/shell-team.contract.yaml"
  fi
  acc=""
  rest="$rd"
  while [ "${rest#*/}" != "$rest" ]; do
    part="${rest%%/*}"
    rest="${rest#*/}"
    acc="${acc:+$acc/}$part"
    probes[${#probes[@]}]="$acc"
  done
done

# The NUL-terminated fields come back as source, line, pattern, path (-z is
# accepted only with --stdin). The stream is rewritten NUL -> newline and
# newline -> \001 so a field never contains a newline; an untrusted pattern is
# only ever compared, never printed.
ci_rc=0
ci_out="$(printf '%s\0' "${probes[@]}" | git -C "$ROOT" check-ignore -v -z --stdin 2>/dev/null | tr '\0\n' '\n\001')" || ci_rc=$?
nrep=0
r_src=()
r_line=()
r_pat=()
r_path=()
if [ "$ci_rc" -eq 0 ]; then
  n_lines="$(printf '%s\n' "$ci_out" | wc -l | tr -d ' ')"
  while IFS= read -r a_src && IFS= read -r a_line && IFS= read -r a_pat && IFS= read -r a_path; do
    r_src[nrep]="$a_src"
    r_line[nrep]="$a_line"
    r_pat[nrep]="$a_pat"
    r_path[nrep]="$a_path"
    nrep=$((nrep + 1))
  done <<< "$ci_out"
  if [ "$n_lines" -ne $((nrep * 4)) ]; then
    err "team-setup: git check-ignore printed a report setup could not read"
    EC2=1
    ci_rc=2
  fi
elif [ "$ci_rc" -ne 1 ]; then
  err "team-setup: git check-ignore could not evaluate the base directory (exit $ci_rc)"
  EC2=1
fi

# Sources a re-include is proven for: the global excludes file git uses and
# the repository's (common) info/exclude.
GX_FILE="$(git -C "$ROOT" config --type=path --get core.excludesFile 2>/dev/null)" || GX_FILE=""
[ -n "$GX_FILE" ] || GX_FILE="${XDG_CONFIG_HOME:-${HOME:-}/.config}/git/ignore"
INFO_EXCL="$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null)" || INFO_EXCL=""

under() { # <path> <dir>: the path is the dir or sits under it
  [ "$1" = "$2" ] && return 0
  case "$1" in
    "$2"/*) return 0 ;;
  esac
  return 1
}
fmt_rule() { # <report index>: "<source>:<line>" (never the pattern)
  local s="${r_src[$1]}" l="${r_line[$1]}"
  case "$l" in
    ''|*[!0-9]*) l="?" ;;
  esac
  case "$s" in
    ''|*[![:print:]]*|*'`'*) s="<unprintable source>" ;;
  esac
  printf '%s:%s' "$s" "$l"
}
in_head() { # <path>: the path is in HEAD's tree (an unborn HEAD or a staged-only path is not)
  local o
  o="$(git -C "$ROOT" ls-tree HEAD -- "$1" 2>/dev/null)" || return 1
  case "$o" in
    [0-7][0-7][0-7][0-7][0-7][0-7]" blob "*) return 0 ;;
  esac
  return 1
}

# A report whose pattern starts with `!` is a re-include git matched, so that
# path is NOT ignored; such reports are skipped everywhere below.
RG_IDX=-1
i=0
while [ "$i" -lt "$nrep" ]; do
  case "${r_pat[$i]}" in
    '!'*) : ;;
    *) if [ "${r_path[$i]}" = ".gitignore" ]; then RG_IDX="$i"; fi ;;
  esac
  i=$((i + 1))
done
BASE_OK=1
BASE_SEGS=""
BASE_PATHS=""
BASE_REINC=""
BASE_NOREINC=0
BASE_BADPATH=0
if [ "$ci_rc" -ne 0 ] && [ "$ci_rc" -ne 1 ]; then
  BASE_OK=0
  BASE_NAMES=""
else
  BASE_NAMES=""
  for ((ri = 0; ri < ${#REQ_DIRS[@]}; ri++)); do
    rd="${REQ_DIRS[$ri]}"
    a_any=0
    a_dir=-1
    a_anc=-1
    a_closed=1
    a_exist=""
    a_new=""
    i=0
    while [ "$i" -lt "$nrep" ]; do
      rp="${r_path[$i]}"
      case "${r_pat[$i]}" in
        '!'*) i=$((i + 1)); continue ;;
      esac
      if under "$rp" "$rd"; then
        a_any=1
        if [ "$rp" = "$rd" ]; then
          a_dir="$i"
        elif [ "${rp##*/}" = "$PROBE_MD" ]; then
          a_new="${a_new:+$a_new, }${rp%/*}/ by $(fmt_rule "$i")"
        else
          a_exist="${a_exist:+$a_exist, }$rp by $(fmt_rule "$i")"
        fi
        okp=0
        if [ "${r_src[$i]}" = "$GX_FILE" ] || { [ -n "$INFO_EXCL" ] && [ "${r_src[$i]}" = "$INFO_EXCL" ]; }; then
          case "${r_pat[$i]}" in
            "$rd"|"$rd/"|"/$rd"|"/$rd/") okp=1 ;;
          esac
        fi
        [ "$okp" -eq 1 ] || a_closed=0
      else
        # Defence-in-depth: a reported ancestor also reports every probe under
        # the directory (a_any, with the ancestor's rule as pattern, so
        # a_closed is already 0); no reachable input reaches this branch with
        # a_any unset, so removing it is an equivalent mutant.
        case "$rd/" in
          "$rp"/*) a_anc="$i" ;;
        esac
      fi
      i=$((i + 1))
    done
    committed=1
    in_head "${REQ_ANCHOR[$ri]}" || committed=0
    if [ "$a_any" -eq 0 ] && [ "$a_anc" -lt 0 ] && [ "$committed" -eq 1 ]; then
      continue
    fi
    BASE_OK=0
    BASE_NAMES="${BASE_NAMES:+$BASE_NAMES and }$rd/"
    seg="$rd/"
    if [ "$a_dir" -ge 0 ]; then
      seg="$seg is ignored by $(fmt_rule "$a_dir")"
    elif [ -n "$a_exist" ]; then
      seg="$seg holds ignored files ($a_exist)"
    elif [ -n "$a_new" ]; then
      seg="$seg would ignore new .md files in $a_new"
    elif [ "$a_anc" -ge 0 ]; then
      seg="$seg sits under an ignored parent, ignored by $(fmt_rule "$a_anc")"
    else
      seg="$seg is not committed yet"
    fi
    if [ "$committed" -eq 0 ] && { [ "$a_any" -eq 1 ] || [ "$a_anc" -ge 0 ]; }; then
      seg="$seg and its anchor is not in HEAD"
    fi
    BASE_SEGS="${BASE_SEGS:+$BASE_SEGS; }$seg"
    # A path that cannot be single-quoted safely gets no printed command or line.
    case "$rd" in
      ''|*[!A-Za-z0-9._/-]*) BASE_BADPATH=1; a_closed=0 ;;
    esac
    if [ "$committed" -eq 0 ]; then
      BASE_PATHS="${BASE_PATHS:+$BASE_PATHS }'$rd'"
    fi
    if [ "$a_any" -eq 1 ] || [ "$a_anc" -ge 0 ]; then
      if [ "$a_closed" -eq 1 ] && [ "$a_any" -eq 1 ] && [ "$a_anc" -lt 0 ]; then
        BASE_REINC="${BASE_REINC:+$BASE_REINC and }\`!$rd/\`"
      else
        BASE_NOREINC=1
      fi
    fi
  done
  if [ "$BASE_OK" -eq 1 ]; then
    for ((ri = 0; ri < ${#REQ_DIRS[@]}; ri++)); do
      BASE_NAMES="${BASE_NAMES:+$BASE_NAMES and }${REQ_DIRS[$ri]}/"
    done
    add_inplace "base directory in git: $BASE_NAMES not ignored by git, and the anchor of each (the board; a specs directory's .gitkeep) is committed in HEAD"
  fi
fi
if [ "$ci_rc" -le 1 ] && [ "$BASE_OK" -eq 0 ]; then
  msg="base directory in git: $BASE_SEGS. The loop's records must be committed for the gates to pass, and the loop does not support never-committed operating files, so this has one correct answer."
  if [ "$BASE_BADPATH" -eq 1 ]; then
    msg="$msg A path above cannot be quoted safely, so setup prints no command for it."
  else
    if [ -n "$BASE_REINC" ] && [ "$RG_IDX" -ge 0 ]; then
      msg="$msg The repository's root .gitignore is itself ignored by $(fmt_rule "$RG_IDX"), so a re-include line could not be committed there and setup prints none; make that file trackable first."
      BASE_NOREINC=1
    elif [ -n "$BASE_REINC" ]; then
      msg="$msg Add $BASE_REINC to the repository's root .gitignore (setup never edits it)."
      BASE_PATHS="${BASE_PATHS:+$BASE_PATHS }'.gitignore'"
    fi
    if [ "$BASE_NOREINC" -eq 1 ]; then
      msg="$msg For an ignored directory with no re-include line above, change or remove the rule that hides it (setup cannot name a safe line for it)."
    fi
    if [ -n "$BASE_PATHS" ]; then
      msg="$msg Run \`git add -- $BASE_PATHS\` and commit; setup stages and commits nothing."
    else
      msg="$msg Setup stages and commits nothing."
    fi
  fi
  add_required "$msg"
fi

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
print_section "Required:" "$REQUIRED"
print_section "Notice:" "$NOTICE"

if [ "$EC2" -eq 1 ]; then
  exit 2
elif [ "$EC3" -eq 1 ]; then
  exit 3
elif [ "$EC1" -eq 1 ]; then
  exit 1
fi
exit 0
