#!/usr/bin/env bash
# check-durability.sh — a benign post-hoc durability barrier: at a named
# hand-off phase, does every record the loop's own registry requires for
# that phase actually exist as a blob in a fixed commit's tree, with the
# working file's content matching that blob (T-1048; GitHub issue #167;
# .shell-team/specs/T-1048-handoff-durability-barrier.md).
#
# Two prior designs tried to PREDICT persistence from gitignore rules at
# init time and did not converge: rule evaluation can be fooled, and it is
# blind to a partial rule such as `.shell-team/*.md`, which hides exactly
# one record (the board) while every deeper record commits normally. This
# checker replaces prediction with OBSERVATION: the record set comes from a
# plugin-shipped registry this checker owns (never from `git status` or
# `git ls-files`, both of which are blind to an ignored file), and each
# record is checked for actually being a blob in `--ref`'s tree, with the
# working file's `git hash-object --path=<path>` matching that blob.
#
# Threat model (load-bearing): the operator and the working directory are
# TRUSTED (repo CLAUDE.md security invariant). What this defends against is
# ACCIDENTS — a stray gitignore rule, a mis-resolved base dir — never a
# hostile operator. Environment-variable neutralization, shell-function
# override defense, GIT_* enumeration, and exotic git object stores (GIT_DIR
# redirection, replace refs, clean-filter/LFS) are explicitly out of scope
# and belong to a separate hardening issue; this script contains none of
# that hardening machinery.
#
# Verdicts (DP3/DP6):
#   1. `--ref` must resolve to a real commit at all; an unborn repository
#      (zero commits) is `no-recorded-commit`, checked BEFORE any record is
#      examined.
#   2. A `<base>/durability-mode` opt-out (DP7) may declare
#      `working-tree-only`, honored ONLY if the opt-out is ITSELF durable:
#      the mode file must resolve to a blob in `--ref`'s tree AND that
#      blob's content, compared via `git hash-object --path=`, must match
#      the working file's content (the same DP3-style content-durability
#      check every ordinary record gets, applied to the mode file itself) —
#      presence of SOME blob at the path is not enough, because a mode file
#      committed as `tracked` and then edited (uncommitted) in the working
#      tree to `working-tree-only` would otherwise silently honor a skip
#      that was never durably declared. Either a missing blob or a content
#      mismatch is `untracked-opt-out` (rework round 1, 2026-08-08): the
#      opt-out ITSELF is not tracked at `--ref`, whether or not a file
#      happens to live at that path. Malformed mode-file content is
#      `structural`, never a silent default. Absent file means the default
#      mode `tracked`, and the observation runs.
#   3. For every record the registry (templates/durability-records.txt)
#      requires for the named `--phase`, in three steps, each its own
#      verdict: the working file must exist and be readable
#      (`missing-working-file`); its recorded path must resolve to a blob in
#      `--ref`'s tree, read from `git ls-tree`'s OUTPUT (empty stdout means
#      absent — NEVER its exit status, which is 0 even for an absent path)
#      (`not-in-recorded-commit`); and `git hash-object --path=<path>` must
#      equal that blob (`uncommitted-change`). `--path=` is a benign
#      end-of-line-normalization correctness choice (it makes a Windows
#      checkout's CRLF working file compare equal to its LF-normalized
#      committed blob under a `text` gitattribute) — not a hardening
#      measure, and this script does not try to make that comparison robust
#      against an operator who wants it to lie.
#   4. All present and matching: `durable` (exit 0). Any failure above:
#      `not-durable` (exit 1), a reason token from the closed set above on
#      stderr, naming the record and the ref in plain language. Inability to
#      evaluate the input at all (bad arguments, an unusable sibling
#      resolver, a malformed or ambiguous registry) is `usage` / `structural`
#      (exit 2), following bin/check-provenance.sh's classification
#      convention exactly.
#
# The `specs` registry row's pattern carries a hyphen deliberately
# (`<task-id>-*.md`): a spec file is named `<task-id>-<slug>.md`, and this is
# what keeps a shorter id (e.g. T-104) from matching a longer one's spec
# (e.g. T-1048-*.md). Zero matches for a glob pattern is
# `missing-working-file`; two or more is `structural` (ambiguous — never a
# silent pick of whichever the glob returned first; this repository's own
# T-1020 owns two spec files today, so this is a reachable, not a
# hypothetical, state).
#
# Usage:
#   check-durability.sh --phase <implement|pre-merge|close-out> --task <T-NNN> --ref <REF> [--records FILE]
#
#   --phase    which of the registry's three phases to observe
#   --task     the board task id, shape ^T-[0-9]+$ (no-task runs are out of
#              scope: they have no spec/provenance/review record to be
#              durable by construction)
#   --ref      the fixed commit to observe against — a branch name, `HEAD`,
#              or `refs/heads/<name>`. Always explicit; this script never
#              infers it (no `git branch --show-current`, no
#              `git symbolic-ref` — a detached HEAD makes the former exit 0
#              with EMPTY stdout, a success-shaped wrong answer)
#   --records  override the registry file path. A TESTING AFFORDANCE ONLY
#              (used by this script's own fixture suite to exercise a
#              malformed-registry rejection) — not an adopter-facing knob;
#              the default resolves templates/durability-records.txt next to
#              this script's own installed location
#
# Exit: 0 = durable, or an honored working-tree-only skip (see stdout for
#       which); 1 = not-durable (a reason token on stderr from the closed
#       set: no-recorded-commit | missing-working-file |
#       not-in-recorded-commit | uncommitted-change | untracked-opt-out); 2 =
#       usage (bad invocation) or structural (an unusable sibling resolver,
#       a missing/malformed/ambiguous registry, malformed opt-out content).

set -euo pipefail

# --- classified failure helpers ---------------------------------------------
die() {  # $1 = classification (usage|structural); $2 = message; exit 2
  printf 'check-durability: %s: %s\n' "$1" "$2" >&2 || true
  exit 2
}
fail_usage()      { die usage "$1"; }
fail_structural() { die structural "$1"; }
fail_not_durable() {  # $1 = reason token (closed set); $2 = plain-language body naming the record and the ref
  printf 'check-durability: not-durable: %s: %s — this hand-off is not durable.\n' "$1" "$2" >&2 || true
  exit 1
}

# Resolve this script's own file, following symlinks — a plugin install may
# expose bin/ scripts on PATH via a symlink, so `dirname "$0"` alone would
# resolve to the symlink's directory rather than this file's real location.
# Ported verbatim (bootstrap shape) from bin/check-provenance.sh L98-143
# (2026-06-15/2026-07-14 lesson: reuse the proven symlink-safe resolver
# instead of hand-rolling one) — every external command in this bootstrap
# (readlink / dirname / cd / pwd / basename) is independently guarded,
# including the split-substitution fix that keeps a failing `dirname` from
# silently becoming `$PWD`. Every `cd DIR && pwd` below is `cd DIR &&
# pwd -P` (T-1057, issue #218): a bare logical `pwd` preserves an ANCESTOR
# directory symlink in the reported path (an adopter's `bin/` symlinked
# into the plugin's real `bin/` — ordinary vendoring, no hostile action),
# which silently resolves TEMPLATES_ROOT below inside the ADOPTER's own
# tree and lets a decoy `templates/durability-records.txt` there stand in
# for the plugin's shipped registry. `pwd -P` reports the OS-canonical path
# regardless of how many symlinks — final-component or ancestor — were
# crossed getting there, the same fix shape `bin/check-binding.sh` and
# `bin/check-adapter.sh` already carry for the identical reason.
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  link_target="$(readlink "$script_path")" \
    || fail_usage "readlink failed to resolve the symlink target of: $script_path"
  case "$link_target" in
    /*) script_path="$link_target" ;;
    *)
      link_dir_raw="$(dirname "$script_path")" \
        || fail_usage "dirname failed to resolve the directory of relative symlink target for: $script_path"
      link_dir="$(cd "$link_dir_raw" && pwd -P)" \
        || fail_usage "cd/pwd failed to resolve the directory of relative symlink target for: $script_path"
      script_path="$link_dir/$link_target"
      ;;
  esac
done
script_dir_raw="$(dirname "$script_path")" \
  || fail_usage "dirname failed to resolve this script's own directory for: $script_path"
SCRIPT_DIR="$(cd "$script_dir_raw" && pwd -P)" \
  || fail_usage "cd/pwd failed to resolve this script's own directory for: $script_path"
self_name="$(basename "$script_path")" \
  || fail_usage "basename failed to resolve this script's own file name for: $script_path"
SELF="$SCRIPT_DIR/$self_name"

print_help() {
  sed -n '2,88p' "$SELF" | sed 's/^# \{0,1\}//' \
    || fail_usage "failed to read this script's own header comment (--help) from: $SELF"
}

# --- argument parsing --------------------------------------------------------
PHASE="" TASK="" REF="" RECORDS_OVERRIDE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) print_help; exit 0 ;;
    --phase)   [ "$#" -ge 2 ] || fail_usage "--phase requires a value"; PHASE="$2"; shift 2 ;;
    --task)    [ "$#" -ge 2 ] || fail_usage "--task requires a value"; TASK="$2"; shift 2 ;;
    --ref)     [ "$#" -ge 2 ] || fail_usage "--ref requires a value"; REF="$2"; shift 2 ;;
    --records) [ "$#" -ge 2 ] || fail_usage "--records requires a value"; RECORDS_OVERRIDE="$2"; shift 2 ;;
    --) shift; break ;;
    -*) fail_usage "unknown flag: $1" ;;
    *)  fail_usage "unexpected positional argument: $1" ;;
  esac
done
[ "$#" -eq 0 ] || fail_usage "unexpected extra argument: $1"

[ -n "$PHASE" ] || fail_usage "missing required --phase (implement|pre-merge|close-out)"
case "$PHASE" in
  implement|pre-merge|close-out) ;;
  *) fail_usage "invalid --phase '$PHASE' (expected implement|pre-merge|close-out)" ;;
esac
[ -n "$TASK" ] || fail_usage "missing required --task"
[[ "$TASK" =~ ^T-[0-9]+$ ]] || fail_usage "invalid --task '$TASK' (expected T-<digits>; no-task runs are out of scope)"
[ -n "$REF" ] || fail_usage "missing required --ref (explicit; no branch/HEAD inference is ever performed)"

# --- resolve the sibling path resolver ---------------------------------------
TEAM_PATHS="$SCRIPT_DIR/team-paths.sh"
if [ ! -f "$TEAM_PATHS" ] || [ ! -r "$TEAM_PATHS" ]; then
  fail_structural "cannot resolve operating paths (team-paths.sh missing or unreadable next to check-durability.sh)"
fi

get_path() {  # $1 = team-paths.sh --get key
  bash "$TEAM_PATHS" --get "$1" 2>/dev/null || fail_structural "team-paths.sh could not resolve key: $1"
}

BASE_DIR="$(get_path base)"

# --- resolve the registry -----------------------------------------------------
if [ -n "$RECORDS_OVERRIDE" ]; then
  REGISTRY="$RECORDS_OVERRIDE"
else
  TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)" \
    || fail_structural "cannot resolve the templates directory (one level above check-durability.sh's own installed directory)"
  REGISTRY="$TEMPLATES_ROOT/templates/durability-records.txt"
fi
if [ ! -f "$REGISTRY" ] || [ ! -r "$REGISTRY" ]; then
  fail_structural "cannot read the durability records registry: $REGISTRY"
fi

# --- B1: `--ref` must resolve to a real commit before anything else is examined
if ! git rev-parse --verify "${REF}^{commit}" >/dev/null 2>&1; then
  fail_not_durable no-recorded-commit "ref '$REF' does not resolve to any commit yet"
fi

# --- DP7: the opt-out mode file --------------------------------------------
MODE_FILE="$BASE_DIR/durability-mode"
MODE="tracked"
if [ -f "$MODE_FILE" ]; then
  [ -r "$MODE_FILE" ] || fail_structural "cannot read the durability mode file: $MODE_FILE"
  mode_content=""
  while IFS= read -r raw || [ -n "$raw" ]; do
    ln="${raw%$'\r'}"
    case "$ln" in
      ''|'#'*) continue ;;
      *) mode_content="$ln"; break ;;
    esac
  done < "$MODE_FILE"
  case "$mode_content" in
    tracked)           MODE="tracked" ;;
    working-tree-only) MODE="working-tree-only" ;;
    *) fail_structural "malformed durability mode file (expected the first non-blank/non-comment line to be exactly 'tracked' or 'working-tree-only'): $MODE_FILE" ;;
  esac
fi

if [ "$MODE" = "working-tree-only" ]; then
  # DP7 rework round 1 (2026-08-08 codex review Blocker 1): "the opt-out
  # must itself be durable" means the SAME DP3-style blob-presence AND
  # content-match check ordinary records get below, applied here to the
  # mode file. Confirming that SOME blob exists at $MODE_FILE's path in
  # $REF's tree is not enough — MODE is parsed from the WORKING-TREE copy,
  # so a mode file committed as `tracked` and then edited (uncommitted) to
  # `working-tree-only` would otherwise honor a skip that never durably
  # persisted. Both failure shapes below (no blob at all; a blob whose
  # content differs) are reported as `untracked-opt-out`: the DECLARATION
  # of the opt-out is not tracked at $REF, whether or not a file happens to
  # live at that path with different content.
  mode_ls="$(git ls-tree "$REF" -- "$MODE_FILE" 2>/dev/null || true)"
  mode_blob_sha=""
  if [ -n "$mode_ls" ]; then
    mode_blob_type="$(printf '%s\n' "$mode_ls" | awk '{print $2}')"
    if [ "$mode_blob_type" = "blob" ]; then
      mode_blob_sha="$(printf '%s\n' "$mode_ls" | awk '{print $3}')"
    fi
  fi
  if [ -z "$mode_blob_sha" ]; then
    fail_not_durable untracked-opt-out "$MODE_FILE declares working-tree-only but is not tracked in $REF"
  fi
  mode_working_sha="$(git hash-object --path="$MODE_FILE" "$MODE_FILE" 2>/dev/null || true)"
  [ -n "$mode_working_sha" ] || fail_structural "git hash-object failed while hashing: $MODE_FILE"
  if [ "$mode_working_sha" != "$mode_blob_sha" ]; then
    fail_not_durable untracked-opt-out "$MODE_FILE declares working-tree-only in the working tree, but its committed content in $REF is not working-tree-only — the opt-out itself is not durable"
  fi
  printf 'check-durability: skipped: working-tree-only declared in %s — no durability observation was made\n' "$MODE_FILE"
  exit 0
fi

# --- DP2/DP3: walk the registry for the named phase --------------------------
n_checked=0
found_phase_row=0
while IFS= read -r row || [ -n "$row" ]; do
  case "$row" in
    ''|'#'*) continue ;;
  esac
  # shellcheck disable=SC2086  # intentional word-splitting of a whitespace-delimited registry row
  set -- $row
  [ "$#" -eq 3 ] || fail_structural "malformed registry row (expected exactly 3 whitespace-delimited fields): $row"
  row_phase="$1" row_key="$2" row_pattern="$3"
  [ "$row_phase" = "$PHASE" ] || continue
  found_phase_row=1

  key_value="$(get_path "$row_key")"

  if [ "$row_pattern" = "-" ]; then
    record_path="$key_value"
  else
    case "$row_pattern" in
      *'<task-id>'*) ;;
      *) fail_structural "malformed registry row (pattern is neither '-' nor a <task-id>-bearing filename): $row" ;;
    esac
    filename="${row_pattern//<task-id>/$TASK}"
    is_glob=0
    case "$filename" in
      *'*'*|*'?'*|*'['*) is_glob=1 ;;
    esac
    if [ "$is_glob" -eq 1 ]; then
      matches=""
      if [ -d "$key_value" ]; then
        matches="$(find "$key_value" -mindepth 1 -maxdepth 1 -name "$filename" 2>/dev/null || true)"
      fi
      n_match=0
      if [ -n "$matches" ]; then
        n_match="$(printf '%s\n' "$matches" | grep -c . || true)"
      fi
      if [ "$n_match" -eq 0 ]; then
        fail_not_durable missing-working-file "no file matching $filename under $key_value for task $TASK"
      elif [ "$n_match" -gt 1 ]; then
        fail_structural "ambiguous match for $row_key pattern $row_pattern (task $TASK): $n_match files matched under $key_value, expected exactly one"
      fi
      record_path="$matches"
    else
      record_path="$key_value/$filename"
    fi
  fi

  # --- DP3 predicate, three steps, each its own verdict ----------------------
  if [ ! -f "$record_path" ] || [ ! -r "$record_path" ]; then
    fail_not_durable missing-working-file "$record_path is not present in the working tree"
  fi

  ls_line="$(git ls-tree "$REF" -- "$record_path" 2>/dev/null || true)"
  if [ -z "$ls_line" ]; then
    fail_not_durable not-in-recorded-commit "$record_path is not present in $REF"
  fi
  blob_type="$(printf '%s\n' "$ls_line" | awk '{print $2}')"
  blob_sha="$(printf '%s\n' "$ls_line" | awk '{print $3}')"
  if [ "$blob_type" != "blob" ] || [ -z "$blob_sha" ]; then
    fail_not_durable not-in-recorded-commit "$record_path is not present in $REF"
  fi

  working_sha="$(git hash-object --path="$record_path" "$record_path" 2>/dev/null || true)"
  [ -n "$working_sha" ] || fail_structural "git hash-object failed while hashing: $record_path"
  if [ "$working_sha" != "$blob_sha" ]; then
    fail_not_durable uncommitted-change "$record_path differs from its committed blob in $REF"
  fi

  n_checked=$((n_checked + 1))
done < "$REGISTRY"

[ "$found_phase_row" -eq 1 ] || fail_structural "no registry rows found for phase '$PHASE' in $REGISTRY"

printf 'check-durability: durable: %s record(s) for phase %s, task %s, observed in %s\n' "$n_checked" "$PHASE" "$TASK" "$REF"
exit 0
