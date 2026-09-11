#!/usr/bin/env bash
# check-codex-agents.sh — verify that a Codex-agents out-dir stays in sync
# with a fresh run of its check-only sibling generator, gen-codex-agents.sh
# (T-1134; GitHub issue #484;
# .shell-team/specs/T-1134-codex-host-slice1.md). T-1135 (GitHub issue #493;
# .shell-team/specs/T-1135-codex-host-slice2.md) adds codex-reviewer as a
# fifth default role, inside this script's own authority exactly like the
# other four — no special-casing.
#
# check-only: this script NEVER writes into --out-dir and NEVER writes into
# --root — the same D6 design bin/check-prompt-sync.sh already established
# for its own generator/checker pair (T-039/T-040), applied here: a
# checker with a "fix" mode is one flag away from writing during a check.
#
# Method: regenerate --root's five shipped roles into a scratch out-dir
# (mktemp -d under ${TMPDIR:-/tmp}) with bin/gen-codex-agents.sh, then
# compare (`cmp`) each of --out-dir's own shell-team-<role>.toml files
# against the freshly regenerated one:
#   - a drifted file (bytes differ)                        -> violation
#   - a missing expected file                               -> violation
#   - an extra shell-team-*.toml --out-dir does not own      -> violation
#     (i.e. its basename is not one of this run's own
#     shell-team-<role>.toml names)
#   - any OTHER *.toml file in --out-dir (an adopter's own
#     Codex agent, whose name does not begin shell-team-)     -> ignored,
#     not a violation and never inspected further — this checker's
#     authority stops at the files the generator owns.
#
# Usage:
#   check-codex-agents.sh [--root DIR] [--out-dir DIR] [--roles "r1 r2 ..."]
#
#   --root      forwarded to gen-codex-agents.sh unchanged. Default: this
#               script's OWN plugin root (parent of its own bin/ directory),
#               matching gen-codex-agents.sh's own default — never the
#               caller's cwd, for the same reason: an adopted repository
#               has no agents/ of its own.
#   --out-dir   the out-dir under test. Default: $PWD/.codex/agents — the
#               caller's own current directory, matching
#               gen-codex-agents.sh's own default, deliberately independent
#               of --root.
#   --roles     forwarded to gen-codex-agents.sh unchanged (default: the
#               five roles gen-codex-agents.sh itself defaults to)
#
# Exit: 0 = --out-dir is in sync with --root's current agents/*.md; 1 =
#       drift, a missing expected file, or an extra shell-team-*.toml file
#       found; 2 = usage / configuration error, including the source
#       itself failing to regenerate (gen-codex-agents.sh refused) — there
#       is then nothing well-formed to compare against.

set -euo pipefail

die() { printf 'check-codex-agents: %s\n' "$1" >&2 || true; exit 2; }

# Resolve this script's own directory (symlink-safe) so the sibling
# gen-codex-agents.sh can be invoked regardless of --root or cwd — same
# pattern as bin/check-prompt-sync.sh / bin/gen-codex-agents.sh.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)  script_path="$(cd "$(dirname "$script_path")" && pwd -P)/$link_target" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"

ROOT=""
OUT_DIR=""
ROLES="tech-lead pm-spec engineer qa-verifier codex-reviewer"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)     [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --out-dir)  [ "$#" -ge 2 ] || die "--out-dir requires a value"; shift; OUT_DIR="$1"; shift ;;
    --roles)    [ "$#" -ge 2 ] || die "--roles requires a value"; shift; ROLES="$1"; shift ;;
    --help|-h)  sed -n '2,48p' "$script_path" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

# --root default: this script's OWN plugin root, mirroring
# gen-codex-agents.sh's own default (see header comment above).
[ -n "$ROOT" ] || ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

[ -d "$ROOT" ] || die "root path is not a directory: $ROOT"
ROOT="${ROOT%/}"
[ -n "$ROOT" ] || ROOT="."
# --out-dir default: the caller's OWN current directory, deliberately
# independent of --root (see header comment above).
[ -n "$OUT_DIR" ] || OUT_DIR="$PWD/.codex/agents"

GENERATOR="$SCRIPT_DIR/gen-codex-agents.sh"
[ -x "$GENERATOR" ] || die "cannot find sibling gen-codex-agents.sh next to check-codex-agents.sh: $GENERATOR"

# shellcheck disable=SC2206  # ROLES is a fixed, simple space-separated word list
ROLES_ARR=($ROLES)
[ "${#ROLES_ARR[@]}" -ge 1 ] || die "--roles produced an empty role list"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/check-codex-agents.XXXXXX")" || die "cannot create a scratch directory (TMPDIR=${TMPDIR:-/tmp} not writable?)"
# shellcheck disable=SC2329  # invoked indirectly via the EXIT trap below
cleanup() { rm -rf "$SCRATCH" 2>/dev/null || true; }
trap cleanup EXIT

if ! gen_out="$(bash "$GENERATOR" --root "$ROOT" --out-dir "$SCRATCH/fresh" --roles "$ROLES" 2>&1)"; then
  printf '%s\n' "$gen_out" >&2 || true
  die "the source at $ROOT/agents cannot be regenerated by gen-codex-agents.sh (see its refusal above) — nothing to compare --out-dir against"
fi

violations=0
emit() { printf 'check-codex-agents: %s\n' "$1" >&2; violations=$((violations + 1)); }

# --- every requested role's expected file must exist in --out-dir and be
#     byte-identical to the freshly regenerated one. --out-dir is only
#     ever READ here (cmp), never written. -----------------------------
for role in "${ROLES_ARR[@]}"; do
  expected="$SCRATCH/fresh/shell-team-$role.toml"
  [ -s "$expected" ] || die "gen-codex-agents.sh did not produce the expected scratch file for role '$role': $expected (should be unreachable once generation reported success)"
  actual="$OUT_DIR/shell-team-$role.toml"
  if [ ! -f "$actual" ]; then
    emit "$actual: missing (expected a generated agent for role '$role')"
    continue
  fi
  if ! cmp -s "$expected" "$actual"; then
    emit "$actual: drift (does not match a fresh run of gen-codex-agents.sh for role '$role')"
  fi
done

# --- an extra shell-team-*.toml this run does not own is a violation; any
#     other *.toml (an adopter's own Codex agent) is ignored outright. --
if [ -d "$OUT_DIR" ]; then
  for f in "$OUT_DIR"/shell-team-*.toml; do
    [ -e "$f" ] || continue   # unmatched glob (no shell-team-*.toml files at all)
    base="$(basename "$f")"
    owned=0
    for role in "${ROLES_ARR[@]}"; do
      if [ "$base" = "shell-team-$role.toml" ]; then
        owned=1
        break
      fi
    done
    if [ "$owned" -eq 0 ]; then
      emit "$f: an extra shell-team-*.toml this generator does not own for the requested role list ($ROLES)"
    fi
  done
fi

if [ "$violations" -gt 0 ]; then
  printf 'check-codex-agents: %d violation(s)\n' "$violations" >&2 || true
  exit 1
fi
printf 'check-codex-agents: %s in sync with %s/agents\n' "$OUT_DIR" "$ROOT"
exit 0
