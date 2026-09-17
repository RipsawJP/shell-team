#!/usr/bin/env bash
# check-codex-agents.sh — verify that a Codex-agents out-dir stays in sync
# with a fresh run of its check-only sibling generator, gen-codex-agents.sh
# (T-1134; GitHub issue #484;
# .shell-team/specs/T-1134-codex-host-slice1.md). T-1135 (GitHub issue #493;
# .shell-team/specs/T-1135-codex-host-slice2.md) adds code-reviewer as a
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
#     shell-team-<role>.toml names) — this includes a SYMLINK occupant of
#     an unowned shell-team-*.toml name, dangling or not: the audit loop
#     below reaches it too (a symlink satisfies -L even when it fails -e),
#     so it is reported rather than silently skipped as though the glob
#     itself had not matched (T-1146, issue #546).
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
ROLES="tech-lead pm-spec engineer qa-verifier code-reviewer"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)     [ "$#" -ge 2 ] || die "--root requires a value"; shift; ROOT="$1"; shift ;;
    --out-dir)  [ "$#" -ge 2 ] || die "--out-dir requires a value"; shift; OUT_DIR="$1"; shift ;;
    --roles)    [ "$#" -ge 2 ] || die "--roles requires a value"; shift; ROLES="$1"; shift ;;
    --help|-h)  sed -n '2,52p' "$script_path" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
# T-1144 (issue #524): one named basename inside that "extra" set gets a
# specific hint rather than the generic message — shell-team-codex-reviewer
# .toml is the file gen-codex-agents.sh wrote under the review role's own
# superseded name before the rename. bin/gen-codex-agents.sh now removes it
# by name on every run (see its own header); its surviving here means this
# --out-dir has not been regenerated since the rename, and the generic
# "extra" wording ("this generator does not own") reads as though the file
# were unrelated cruft rather than a specific, named, one-time migration.
LEGACY_CODEX_REVIEWER_BASENAME="shell-team-codex-reviewer.toml"
if [ -d "$OUT_DIR" ]; then
  for f in "$OUT_DIR"/shell-team-*.toml; do
    [ -e "$f" ] || [ -L "$f" ] || continue   # unmatched glob (no shell-team-*.toml files at all); a dangling symlink satisfies -L, not -e, and must still reach the loop body below
    base="$(basename "$f")"
    owned=0
    for role in "${ROLES_ARR[@]}"; do
      if [ "$base" = "shell-team-$role.toml" ]; then
        owned=1
        break
      fi
    done
    if [ "$owned" -eq 0 ]; then
      if [ "$base" = "$LEGACY_CODEX_REVIEWER_BASENAME" ]; then
        # T-1144 round 4 (Codex round-3 Minor): the remedy must carry THIS
        # checker's own resolved --root/--out-dir, not a bare relative
        # command name — on a non-default install (either flag overridden),
        # a hint naming no flags at all regenerates the plugin's default
        # root and $PWD/.codex/agents instead of the directory this checker
        # actually flagged.
        # T-1146 (issue #546): the remedy also carries THIS invocation's own
        # resolved --roles unconditionally, default list included — one code
        # path, one printed shape, so the printed command is literally what
        # this checker itself resolved in every case rather than only when
        # the list happens to differ from the default.
        # T-1146 round 2 (cross-provider Major + Minor 1): the printed
        # command's own inputs can fail gen-codex-agents.sh's own removal
        # gate — either code-reviewer is excluded from THIS invocation's
        # --roles, or $f is an occupant type (a directory, FIFO, socket or
        # other non-symlink special file) the generator's `[ -f ] || [ -L ]`
        # gate never matches — and in either case the "(removes this file
        # by name)" claim would be false.
        # T-1146 round 3 (QA round 2 FAIL, cell 4 of the 2x2): round 2's
        # branch order checked "code-reviewer requested" first and, once
        # false, offered "add code-reviewer to --roles and re-run" as THE
        # remedy without ever re-checking occupant type — so a non-regular
        # occupant (a directory, in QA's live reproduction) excluded from
        # --roles got a remedy claim that is false for TWO independent
        # reasons at once, and only one of them was named. The branch below
        # is a true 2x2 on (code-reviewer requested) x ($f is -f or -L):
        # each of the four cells below fires on both conditions together
        # and gets its own message; "add code-reviewer to --roles and
        # re-run" is offered as a working remedy in exactly the one cell
        # where re-running with that widened list would actually remove
        # the file, and nowhere else.
        code_reviewer_requested=0
        for __legacy_hint_role in "${ROLES_ARR[@]}"; do
          if [ "$__legacy_hint_role" = "code-reviewer" ]; then
            code_reviewer_requested=1
            break
          fi
        done
        LEGACY_REMEDY_CMD="bash \"$GENERATOR\" --root \"$ROOT\" --out-dir \"$OUT_DIR\" --roles \"$ROLES\""
        if [ "$code_reviewer_requested" -eq 1 ] && { [ -f "$f" ] || [ -L "$f" ]; }; then
          # cell 1: requested AND removable — the printed command, run
          # verbatim, really does remove this file (AC6's anchors).
          emit "$f: superseded legacy agent file from the review role's pre-rename name 'codex-reviewer' (T-1144, issue #524) — re-run: $LEGACY_REMEDY_CMD (removes this file by name), or remove it by hand"
        elif [ "$code_reviewer_requested" -eq 1 ]; then
          # cell 2: requested but NOT removable — the occupant type alone
          # defeats the gate; no re-run of any --roles suggestion helps.
          emit "$f: superseded legacy agent file from the review role's pre-rename name 'codex-reviewer' (T-1144, issue #524) — re-run: $LEGACY_REMEDY_CMD, but this occupant is not a regular file or a symlink, so gen-codex-agents.sh will NOT remove it; remove it by hand"
        elif [ -f "$f" ] || [ -L "$f" ]; then
          # cell 3: excluded but removable — widening --roles to include
          # code-reviewer and re-running really would remove this file.
          emit "$f: superseded legacy agent file from the review role's pre-rename name 'codex-reviewer' (T-1144, issue #524) — re-run: $LEGACY_REMEDY_CMD, but this invocation's --roles \"$ROLES\" excludes code-reviewer, so that command will NOT remove this file; add code-reviewer to --roles and re-run, or remove it by hand"
        else
          # cell 4: excluded AND not removable — both facts hold at once,
          # so neither the printed command nor a --roles widening removes
          # this file; "remove it by hand" is the only working remedy.
          emit "$f: superseded legacy agent file from the review role's pre-rename name 'codex-reviewer' (T-1144, issue #524) — this invocation's --roles \"$ROLES\" excludes code-reviewer and this occupant is not a regular file or a symlink, so no re-run of $LEGACY_REMEDY_CMD — with or without code-reviewer added to --roles — will remove it; remove it by hand"
        fi
      else
        emit "$f: an extra shell-team-*.toml this generator does not own for the requested role list ($ROLES)"
      fi
    fi
  done
fi

if [ "$violations" -gt 0 ]; then
  printf 'check-codex-agents: %d violation(s)\n' "$violations" >&2 || true
  exit 1
fi
printf 'check-codex-agents: %s in sync with %s/agents\n' "$OUT_DIR" "$ROOT"
exit 0
