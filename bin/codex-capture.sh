#!/usr/bin/env bash
# bin/codex-capture.sh — shared temp-capture hygiene helper for the `codex
# exec` invocations used by agents/code-reviewer.md (primary + adversarial
# passes), agents/drift-evaluator.md (semantic pass), and the alternate-
# executor invocation path recipe at
# templates/prompt-blocks/alternate-executor-invocation.md (T-1118; #419)
# (T-097, #303 / T-092b carve-out; T-098 validate/publish depth hardening;
# T-107, #353 structural split — docs/specs/T-107-codex-capture-split.md).
#
# T-107 (#353): this helper no longer invokes codex at all. Its previous
# single-mode form substituted a placeholder output-path token into the
# caller's own codex argv and executed it in-process; that argv-substitution
# execution path has been removed entirely (not left dormant alongside the
# modes below). The reason is structural, not stylistic: a Claude Code
# sandbox's `sandbox.excludedCommands` / `permissions.allow` patterns used to
# match on a command line's leading token alone; Claude Code 2.1.278 changed
# this so a command is exempted only when EVERY part of it matches (T-1152;
# see below), which makes the same structural point even sharper: a
# wrapper-embedded codex invocation
# (`bash bin/codex-capture.sh …` / `codex-capture.sh …`) can never itself run
# outside the sandbox — nesting a second seatbelt inside the first dies with
# `sandbox_apply: Operation not permitted` (see docs/distribution.md's
# "Sandbox-enabled permission settings" and issue #324). Splitting the
# executable invocation out to the caller (a bare `codex exec …` line, whose
# first token IS `codex`) makes the sandbox-exclusion match structurally
# possible again, while this helper keeps doing everything it did before
# EXCEPT actually run codex: same-filesystem temp placement, EXIT-trap
# cleanup, structural JSONL validation beyond exit code, and atomic publish.
#
# Design decisions (verbatim from docs/specs/T-107-codex-capture-split.md's
# DP table — this script implements the DP table exactly, no engineer-time
# design choices):
#   DP-a  two explicit modes, mutually exclusive: `--alloc` allocates the two
#         per-invocation raw temps and prints their paths (stdout, one per
#         line); `--publish` validates and atomically publishes a pair of raw
#         paths the caller already wrote to. No more open-ended trailing argv.
#   DP-b  (most important) `--alloc` creates its two raws INSIDE the resolved
#         reviews dir — same filesystem as the canonical target, so
#         `--publish`'s `mv` is an atomic rename, never a cross-fs copy that
#         could silently degrade the DP-2 atomicity guarantee (e.g. a raw
#         living under $TMPDIR). `--publish` enforces this as a fail-closed
#         PRECONDITION rather than trusting the caller: it refuses (exit 2,
#         no `mv` ever attempted) unless both raws' parent directory resolves
#         to the SAME resolved reviews dir, both basenames carry the expected
#         per-stem `.codex-capture.<stem>.{out,jsonl}.` prefix, and both are
#         already existing regular files.
#   DP-c  exit codes 2 (usage) / 3 (validation) / 4 (publish) are unchanged
#         from the pre-split helper. The old exit 1 (a non-zero codex exit)
#         no longer applies here — codex is no longer invoked by this script
#         at all, so that responsibility (checking codex's own exit status,
#         printing its captured output, dropping that run's raws) moves to
#         the caller. This script's own die() never exits 1.
#   DP-d  `--alloc` arms a nounset-safe EXIT trap immediately after the FIRST
#         mktemp succeeds (T-098 DP-C; closes the #250(b) window where a
#         second-mktemp failure would otherwise orphan the first temp), and
#         disarms it (`trap - EXIT`) only once BOTH temps exist — an early
#         exit before that point still cleans up. `--publish` arms an
#         equivalent trap scoped to its OWN two inputs once the fail-closed
#         precondition checks above pass, so a validation reject (exit 3) or
#         a refused/failed publish (exit 4) still removes them. No automatic
#         sweep of stale `.codex-capture.*` temps is implemented anywhere
#         (a sweep is a DESTRUCTIVE, non-targeted operation that could delete
#         a concurrent invocation's still-in-flight raws) — an alloc'd raw
#         orphaned by e.g. a SIGKILL between --alloc and --publish is caught
#         by the both-layout `.gitignore` backstop (T-097 DP-5) instead.
#   DP-i  `--alloc` still creates exactly two separate `mktemp` files (not a
#         single `mktemp -d` directory) and keeps the nounset-safe trap line
#         byte-identical to the pre-split helper (T-098 DP-C).
#
# JSONL structural validation (T-098 DP-A, byte-equivalent to the pre-split
# helper): dependency-free single-pass awk (no jq, no degrade branch) — the
# capture is valid iff at least one non-blank line is a complete
# brace-delimited object carrying the expected Codex --json event key
# ("type"). Interleaved non-JSON noise does not reject as long as one real
# event line is present; a `{`-leading-but-malformed line and a non-`{` line
# both have zero valid event lines and are rejected.
#
# T-1152 (issue #586): Claude Code 2.1.278 changed sandbox.excludedCommands
# matching so a command is exempted only when EVERY part of it matches, not
# just its leading token. Every shipped `codex exec` block used to end in a
# shell redirection (`> "<RAW_JSONL>" 2>&1`); under 2.1.278+ that redirection
# is a second, non-matching part, so the whole call ran INSIDE the sandbox
# (measured on codex-cli 0.156.1: either a loud `workspace routing discovery
# failed` -> `turn.failed`, or exit 0 with an inability sentence and
# `sandbox_apply` errors in the stream). Every shipped block is now a single
# bare command writing only `-o "<RAW_OUT>"` — no redirection, no `< /dev/null`,
# no command substitution — so the `"codex *"` exclusion in
# sandbox.excludedCommands matches the whole call again. The `.jsonl` half of
# a captured pair is no longer produced by a shell redirect: `codex exec`
# writes its own event-stream record — a `rollout-<timestamp>-<thread_id>.jsonl`
# file — to its own state directory (`${CODEX_HOME:-$HOME/.codex}/sessions/
# <YYYY>/<MM>/<DD>/`) for every `exec` run, independently of anything this
# script does. `--publish` gained one optional flag, `--thread-id <id>`,
# which imports that thread's own rollout record into the jsonl raw
# byte-for-byte in place of the removed redirection, then refuses to publish
# ("review did not run") a rollout whose record does not show a completed
# run: no CommandExecution line with `"exit_code":0` (reported as
# `commands_succeeded`), no `task_complete` event, a null final message, or a
# non-null error. `--alloc` and every `--publish` call without `--thread-id`
# are unchanged, byte-for-byte, from the pre-T-1152 script.
#
# Usage:
#   codex-capture.sh --alloc   --stem <stem> [--reviews-dir <dir>]
#   codex-capture.sh --publish --stem <stem> --publish-out <raw-out> --publish-jsonl <raw-jsonl> [--thread-id <id>] [--reviews-dir <dir>]
#
# `--alloc` and `--publish` are mutually exclusive; exactly one is required.
# The caller runs its own `codex exec …` between the two calls (a single bare
# command, first token `codex`, no other part after its arguments — see
# agents/code-reviewer.md / agents/drift-evaluator.md for the full skeleton),
# writing `-o` to `--alloc`'s first stdout line. Without `--thread-id`, the
# caller is responsible for its own second (jsonl) raw exactly as before this
# task; with `--thread-id`, that raw must still be the empty file `--alloc`
# created — `--publish` fills it from the run's own rollout record.
#
# Reviews dir resolution: `--reviews-dir` if given, else `team-paths.sh --get
# reviews`, tried bare on PATH first (`command -v team-paths.sh`), then
# falling back to the cwd-relative `bin/team-paths.sh`, and dying with a
# clear error if neither resolves — PATH is never assumed to carry it, and
# there is no third, plugin-root-relative fallback in this resolver
# (2026-06-17 lesson: self-resolve from the CALLER's cwd — the adopted/target
# repo — never `cd` to this script's own repo root).
#
# Exit codes:
#   0  success — `--alloc`: both raws allocated, their paths printed.
#              — `--publish`: both canonical files published, non-empty.
#   2  usage error (bad/missing/conflicting flags, unresolvable reviews dir,
#      `--thread-id` combined with `--alloc`, a `--thread-id` value that does
#      not match the id shape, a non-empty jsonl raw given with `--thread-id`,
#      or — `--publish` only — a raw failing the fail-closed placement
#      precondition: wrong parent directory, wrong basename prefix, or not an
#      existing regular file; `mv` is never attempted in this case)
#   3  (`--publish` only) captured output failed validation (empty -o
#      capture, or the JSONL stream has no valid event line — no complete
#      `{…}` object line carrying the `"type"` key; T-098 DP-A) — or, with
#      `--thread-id`, the id's rollout was not found as exactly one non-empty
#      `rollout-*-<id>.jsonl` under `${CODEX_HOME:-$HOME/.codex}/sessions`
#      ("rollout import failed"), or its record does not show a completed
#      run — no CommandExecution with `"exit_code":0`, no `task_complete`
#      event, a null final message, or a non-null error ("review did not
#      run") — T-1152
#   4  (`--publish` only) publish failed (a canonical target pre-existing as
#      a non-regular file was refused before any `mv`, an `mv` onto the
#      canonical name itself reported failure, or the post-move
#      existence/non-empty check failed)

set -euo pipefail

die() {  # $1 = exit code, $2 = message
  printf 'codex-capture: %s\n' "$2" >&2 || true
  exit "$1"
}

# --- argument parsing --------------------------------------------------------
mode=""
stem=""
reviews_dir=""
publish_out=""
publish_jsonl=""
thread_id=""
thread_id_given=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --alloc)
      [ -z "$mode" ] || die 2 "--alloc and --publish are mutually exclusive"
      mode="alloc"
      shift
      ;;
    --publish)
      [ -z "$mode" ] || die 2 "--alloc and --publish are mutually exclusive"
      mode="publish"
      shift
      ;;
    --stem)
      [ "$#" -ge 2 ] || die 2 "--stem requires a value"
      stem="$2"
      shift 2
      ;;
    --reviews-dir)
      [ "$#" -ge 2 ] || die 2 "--reviews-dir requires a value"
      reviews_dir="$2"
      shift 2
      ;;
    --publish-out)
      [ "$#" -ge 2 ] || die 2 "--publish-out requires a value"
      publish_out="$2"
      shift 2
      ;;
    --publish-jsonl)
      [ "$#" -ge 2 ] || die 2 "--publish-jsonl requires a value"
      publish_jsonl="$2"
      shift 2
      ;;
    --thread-id)
      [ "$#" -ge 2 ] || die 2 "--thread-id requires a value"
      thread_id="$2"
      thread_id_given=1
      shift 2
      ;;
    --)
      die 2 "'--' / trailing argv is no longer accepted -- the codex-argv-substitution mode was removed in T-107 (#353); the caller now runs codex itself"
      ;;
    -*) die 2 "unknown flag: $1" ;;
    *) die 2 "unexpected positional argument: $1 (usage: codex-capture.sh --alloc --stem <stem> [--reviews-dir <dir>] | codex-capture.sh --publish --stem <stem> --publish-out <raw-out> --publish-jsonl <raw-jsonl> [--thread-id <id>] [--reviews-dir <dir>])" ;;
  esac
done

[ -n "$mode" ] || die 2 "exactly one of --alloc / --publish is required"
[ -n "$stem" ] || die 2 "missing required --stem <stem>"
if [ "$mode" = "alloc" ]; then
  [ -z "$publish_out" ] || die 2 "--publish-out is only valid with --publish"
  [ -z "$publish_jsonl" ] || die 2 "--publish-jsonl is only valid with --publish"
  [ "$thread_id_given" -eq 0 ] || die 2 "--thread-id is only valid with --publish"
else
  [ -n "$publish_out" ] || die 2 "--publish requires --publish-out <raw-out>"
  [ -n "$publish_jsonl" ] || die 2 "--publish requires --publish-jsonl <raw-jsonl>"
fi

# --- resolve the reviews dir -------------------------------------------------
# Self-resolve from cwd (2026-06-17 lesson) — never cd to this script's own
# repo root. `bin/team-paths.sh` below is deliberately cwd-relative, matching
# how the agents themselves already invoke it directly.
if [ -z "$reviews_dir" ]; then
  if command -v team-paths.sh >/dev/null 2>&1; then
    reviews_dir="$(team-paths.sh --get reviews)" || die 2 "team-paths.sh --get reviews failed"
  elif [ -f bin/team-paths.sh ]; then
    reviews_dir="$(bash bin/team-paths.sh --get reviews)" || die 2 "bin/team-paths.sh --get reviews failed"
  else
    die 2 "cannot resolve reviews dir: team-paths.sh not found on PATH and bin/team-paths.sh not found relative to cwd ($(pwd)); pass --reviews-dir explicitly"
  fi
fi
[ -d "$reviews_dir" ] || die 2 "resolved reviews dir does not exist or is not a directory: $reviews_dir"
# Canonicalize so `--alloc` (this invocation or a prior one) and `--publish`
# (this invocation) agree on the same absolute path for the DP-b `dirname`
# comparison below, regardless of whether --reviews-dir / team-paths.sh
# handed back a relative path, a path with a trailing slash, etc. `pwd -P`
# (not plain `pwd`) resolves symlinks to the PHYSICAL path (T-107 round1
# Codex review Major #1): two legitimate spellings of the same physical
# directory that differ only by a symlink hop (e.g. a caller reaching the
# same reviews dir through an alias) must compare equal here, or a genuinely
# co-located raw is rejected as a false positive. This does not weaken the
# fail-closed intent — a raw whose parent really is a DIFFERENT physical
# directory still resolves to a different `pwd -P` value and is still
# refused.
reviews_dir="$(cd "$reviews_dir" && pwd -P)" || die 2 "failed to canonicalize resolved reviews dir: $reviews_dir"

# =============================================================================
# --alloc: create the two per-invocation raws BESIDE the canonical target
# (DP-b/DP-2), print their paths, one per line.
# =============================================================================
if [ "$mode" = "alloc" ]; then
  tmp_out="$(mktemp "$reviews_dir/.codex-capture.$stem.out.XXXXXX")" \
    || die 2 "mktemp failed to create the -o capture temp in reviews dir: $reviews_dir"
  tmp_jsonl=""
  trap 'rm -f "$tmp_out" ${tmp_jsonl:+"$tmp_jsonl"}' EXIT
  tmp_jsonl="$(mktemp "$reviews_dir/.codex-capture.$stem.jsonl.XXXXXX")" \
    || die 2 "mktemp failed to create the jsonl capture temp in reviews dir: $reviews_dir"
  trap - EXIT
  printf '%s\n%s\n' "$tmp_out" "$tmp_jsonl"
  exit 0
fi

# =============================================================================
# --publish: fail-closed placement precondition (DP-b), then validate beyond
# exit code (DP-4/T-098 DP-A), then atomic publish with rc checks (DP-4).
# =============================================================================
raw_out="$publish_out"
raw_jsonl="$publish_jsonl"

out_dirname_raw="$(dirname -- "$raw_out")" || die 2 "dirname failed to resolve the parent directory of: $raw_out"
jsonl_dirname_raw="$(dirname -- "$raw_jsonl")" || die 2 "dirname failed to resolve the parent directory of: $raw_jsonl"
# `pwd -P` (physical path), not plain `pwd`, matching reviews_dir's own
# canonicalization above -- both sides of the DP-b equality check below must
# resolve symlinks the same way, or a legitimately co-located raw reached
# through a different (symlinked) spelling of the same directory is
# rejected as a false positive (T-107 round1 Codex review Major #1).
out_dirname="$(cd "$out_dirname_raw" 2>/dev/null && pwd -P)" \
  || die 2 "publish refused: -o raw's parent directory does not exist or is not resolvable: $raw_out"
jsonl_dirname="$(cd "$jsonl_dirname_raw" 2>/dev/null && pwd -P)" \
  || die 2 "publish refused: jsonl raw's parent directory does not exist or is not resolvable: $raw_jsonl"

[ "$out_dirname" = "$reviews_dir" ] \
  || die 2 "publish refused: -o raw's parent directory ($out_dirname) is not the resolved reviews dir ($reviews_dir), mv never attempted: $raw_out"
[ "$jsonl_dirname" = "$reviews_dir" ] \
  || die 2 "publish refused: jsonl raw's parent directory ($jsonl_dirname) is not the resolved reviews dir ($reviews_dir), mv never attempted: $raw_jsonl"

out_base="$(basename -- "$raw_out")"
jsonl_base="$(basename -- "$raw_jsonl")"
case "$out_base" in
  ".codex-capture.$stem.out."*) : ;;
  *) die 2 "publish refused: -o raw's basename does not carry the expected .codex-capture.$stem.out.* prefix, mv never attempted: $out_base" ;;
esac
case "$jsonl_base" in
  ".codex-capture.$stem.jsonl."*) : ;;
  *) die 2 "publish refused: jsonl raw's basename does not carry the expected .codex-capture.$stem.jsonl.* prefix, mv never attempted: $jsonl_base" ;;
esac

[ -f "$raw_out" ] || die 2 "publish refused: -o raw is not an existing regular file, mv never attempted: $raw_out"
[ -f "$raw_jsonl" ] || die 2 "publish refused: jsonl raw is not an existing regular file, mv never attempted: $raw_jsonl"

# --- T-1152: --thread-id preconditions, still before the EXIT trap is armed
# below, so a refusal here (exit 2) leaves both raws untouched exactly like
# every other precondition refusal above -- id shape (8-4-4-4-12 lower-case
# hex, R3 step 1) and a not-yet-empty jsonl raw (R3 step 2: with --thread-id
# the jsonl raw must still be the empty file --alloc created, since the
# rollout import fills it, not the caller).
THREAD_ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if [ "$thread_id_given" -eq 1 ]; then
  [[ "$thread_id" =~ $THREAD_ID_RE ]] \
    || die 2 "publish refused: --thread-id value does not match the expected 8-4-4-4-12 lower-case hex id shape: $thread_id"
  [ ! -s "$raw_jsonl" ] \
    || die 2 "publish refused: --thread-id requires an empty jsonl raw (the rollout import fills it), mv never attempted: $raw_jsonl"
fi

# Precondition satisfied -- arm a trap scoped to THESE two raws (DP-d), so a
# validation reject (exit 3) or a refused/failed publish (exit 4) below still
# removes them; a successful mv is a no-op for this trap (the path is gone).
trap 'rm -f "$raw_out" "$raw_jsonl"' EXIT

if ! [ -s "$raw_out" ]; then
  exit 3
fi

# --- T-1152: with --thread-id, import the thread's own rollout record into
# the (still-empty) jsonl raw byte-for-byte, in place of the removed shell
# redirection (R3 step 3). $sessions_dir is printed EXPANDED, not
# canonicalized (Notes for engineer) -- it is a diagnostic value, never
# compared against anything. find's own stderr (a missing $sessions_dir) is
# never let through, so a bare-store refusal still prints exactly one line.
if [ "$thread_id_given" -eq 1 ]; then
  sessions_dir="${CODEX_HOME:-$HOME/.codex}/sessions"
  rollout_matches="$(find "$sessions_dir" -type f -name "rollout-*-$thread_id.jsonl" 2>/dev/null || true)"
  rollout_match_count=0
  rollout_match=""
  if [ -n "$rollout_matches" ]; then
    rollout_match_count="$(printf '%s\n' "$rollout_matches" | wc -l | tr -d ' ')"
    rollout_match="$(printf '%s\n' "$rollout_matches" | head -n 1)"
  fi
  if [ "$rollout_match_count" -ne 1 ] || [ ! -s "$rollout_match" ]; then
    die 3 "publish: rollout import failed (dir=$sessions_dir thread=$thread_id matches=$rollout_match_count)"
  fi
  cp -- "$rollout_match" "$raw_jsonl" || die 3 "publish: rollout import failed to copy $rollout_match into the jsonl raw"
fi

# --- validate the JSONL capture structurally (T-098 DP-A, byte-equivalent) --
if ! awk '
    /^[[:space:]]*[{].*[}][[:space:]]*$/ && /"type"[[:space:]]*:/ { ok = 1 }
    END { exit (ok ? 0 : 1) }
  ' "$raw_jsonl"; then
  exit 3
fi

# --- T-1152: with --thread-id, refuse a rollout that does not show a
# completed run ("review did not run", R1/R3 step 5/R3'). Never gates on a
# failure_markers token -- that field is reported only (Non-goals).
if [ "$thread_id_given" -eq 1 ]; then
  gate_fields="$(awk '
      $0 ~ /"type"[[:space:]]*:[[:space:]]*"item_completed"/ && $0 ~ /"type"[[:space:]]*:[[:space:]]*"CommandExecution"/ {
        executed++
        if ($0 ~ /"exit_code"[[:space:]]*:[[:space:]]*0[^0-9.]/) succeeded++
      }
      $0 ~ /"type"[[:space:]]*:[[:space:]]*"task_complete"/ {
        tc_present = 1
        msg_null = ($0 ~ /"last_agent_message"[[:space:]]*:[[:space:]]*null/) ? 1 : 0
        err_present = ($0 ~ /"error"[[:space:]]*:/ && $0 !~ /"error"[[:space:]]*:[[:space:]]*null/) ? 1 : 0
      }
      END { printf "%d %d %d %d %d\n", executed+0, succeeded+0, tc_present+0, msg_null+0, err_present+0 }
    ' "$raw_jsonl")"
  # shellcheck disable=SC2086  # intentional word-splitting of the 5 awk-printed integers
  set -- $gate_fields
  commands_executed="$1"; commands_succeeded="$2"; tc_present="$3"; msg_null="$4"; err_present="$5"
  failure_markers="$(grep -cE 'turn_aborted|workspace routing discovery failed|sandbox_apply|turn\.failed' "$raw_jsonl" || true)"
  tc_state="absent"; [ "$tc_present" -eq 1 ] && tc_state="present"
  err_state="absent"; [ "$tc_present" -eq 1 ] && [ "$err_present" -eq 1 ] && err_state="present"
  if [ "$commands_succeeded" -eq 0 ] || [ "$tc_present" -eq 0 ] \
     || { [ "$tc_present" -eq 1 ] && [ "$msg_null" -eq 1 ]; } \
     || { [ "$tc_present" -eq 1 ] && [ "$err_present" -eq 1 ]; }; then
    die 3 "publish: review did not run (thread=$thread_id commands_executed=$commands_executed commands_succeeded=$commands_succeeded failure_markers=$failure_markers task_complete=$tc_state error=$err_state)"
  fi
fi

# --- publish: refuse a non-regular-file canonical target, then atomic mv
# with rc check (DP-4) --------------------------------------------------------
for canon in "$reviews_dir/$stem.txt" "$reviews_dir/$stem.jsonl"; do
  if [ -e "$canon" ] && [ ! -f "$canon" ]; then
    # target exists but is not a regular file (e.g. a directory) — refuse:
    # do NOT mv (would nest the raw and orphan it); the raws stay at their
    # paths so the EXIT trap above cleans them. No stale-read, no orphan.
    exit 4
  fi
done
if ! mv "$raw_out" "$reviews_dir/$stem.txt"; then exit 4; fi
if ! mv "$raw_jsonl" "$reviews_dir/$stem.jsonl"; then exit 4; fi

# post-verify the published pair is a non-empty regular file each
if [ -f "$reviews_dir/$stem.txt" ] && [ -s "$reviews_dir/$stem.txt" ] \
   && [ -f "$reviews_dir/$stem.jsonl" ] && [ -s "$reviews_dir/$stem.jsonl" ]; then
  if [ "$thread_id_given" -eq 1 ]; then
    printf 'codex-capture: publish: rollout thread=%s commands_executed=%s commands_succeeded=%s failure_markers=%s\n' \
      "$thread_id" "$commands_executed" "$commands_succeeded" "$failure_markers" >&2 || true
  fi
  exit 0
fi
exit 4
