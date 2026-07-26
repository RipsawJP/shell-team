#!/usr/bin/env bash
# bin/codex-capture.sh — shared temp-capture hygiene helper for the `codex
# exec` invocations used by agents/codex-reviewer.md (primary + adversarial
# passes) and agents/drift-evaluator.md (semantic pass)
# (T-097, #303 / T-092b carve-out; T-098 validate/publish depth hardening;
# T-107, #353 structural split — docs/specs/T-107-codex-capture-split.md).
#
# T-107 (#353): this helper no longer invokes codex at all. Its previous
# single-mode form substituted a placeholder output-path token into the
# caller's own codex argv and executed it in-process; that argv-substitution
# execution path has been removed entirely (not left dormant alongside the
# modes below). The reason is structural, not stylistic: a Claude Code
# sandbox's `sandbox.excludedCommands` / `permissions.allow` patterns match
# on a command line's FIRST token, so a wrapper-embedded codex invocation
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
# Usage:
#   codex-capture.sh --alloc   --stem <stem> [--reviews-dir <dir>]
#   codex-capture.sh --publish --stem <stem> --publish-out <raw-out> --publish-jsonl <raw-jsonl> [--reviews-dir <dir>]
#
# `--alloc` and `--publish` are mutually exclusive; exactly one is required.
# The caller runs its own `codex exec …` between the two calls (a bare,
# first-token-`codex` invocation — see agents/codex-reviewer.md /
# agents/drift-evaluator.md for the full skeleton), redirecting `-o` to
# `--alloc`'s first stdout line and its own stdout+stderr to the second.
#
# Reviews dir resolution: `--reviews-dir` if given, else `team-paths.sh --get
# reviews` — bare on PATH when the plugin is loaded, else the cwd-relative
# `bin/team-paths.sh` (2026-06-17 lesson: self-resolve from the CALLER's cwd
# — the adopted/target repo — never `cd` to this script's own repo root).
#
# Exit codes:
#   0  success — `--alloc`: both raws allocated, their paths printed.
#              — `--publish`: both canonical files published, non-empty.
#   2  usage error (bad/missing/conflicting flags, unresolvable reviews dir,
#      or — `--publish` only — a raw failing the fail-closed placement
#      precondition: wrong parent directory, wrong basename prefix, or not an
#      existing regular file; `mv` is never attempted in this case)
#   3  (`--publish` only) captured output failed validation (empty -o
#      capture, or the JSONL stream has no valid event line — no complete
#      `{…}` object line carrying the `"type"` key; T-098 DP-A)
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
    --)
      die 2 "'--' / trailing argv is no longer accepted -- the codex-argv-substitution mode was removed in T-107 (#353); the caller now runs codex itself"
      ;;
    -*) die 2 "unknown flag: $1" ;;
    *) die 2 "unexpected positional argument: $1 (usage: codex-capture.sh --alloc --stem <stem> [--reviews-dir <dir>] | codex-capture.sh --publish --stem <stem> --publish-out <raw-out> --publish-jsonl <raw-jsonl> [--reviews-dir <dir>])" ;;
  esac
done

[ -n "$mode" ] || die 2 "exactly one of --alloc / --publish is required"
[ -n "$stem" ] || die 2 "missing required --stem <stem>"
if [ "$mode" = "alloc" ]; then
  [ -z "$publish_out" ] || die 2 "--publish-out is only valid with --publish"
  [ -z "$publish_jsonl" ] || die 2 "--publish-jsonl is only valid with --publish"
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

# Precondition satisfied -- arm a trap scoped to THESE two raws (DP-d), so a
# validation reject (exit 3) or a refused/failed publish (exit 4) below still
# removes them; a successful mv is a no-op for this trap (the path is gone).
trap 'rm -f "$raw_out" "$raw_jsonl"' EXIT

if ! [ -s "$raw_out" ]; then
  exit 3
fi

# --- validate the JSONL capture structurally (T-098 DP-A, byte-equivalent) --
if ! awk '
    /^[[:space:]]*[{].*[}][[:space:]]*$/ && /"type"[[:space:]]*:/ { ok = 1 }
    END { exit (ok ? 0 : 1) }
  ' "$raw_jsonl"; then
  exit 3
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
  exit 0
fi
exit 4
